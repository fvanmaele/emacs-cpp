/* S23: cost of checking a translation unit's include closure for staleness.
 *
 * Usage: closurecost MODE LISTFILE ITERATIONS
 *   MODE hash : open + read + XXH3_64bits every file (clangd's digest(),
 *               SourceCode.cpp, uses llvm::xxh3_64bits on the whole content)
 *   MODE stat : stat() every file (mtime + size, a cheaper staleness proxy)
 *   MODE open : open() + close() every file, no read (isolates per-open cost,
 *               e.g. an on-access virus scanner)
 *   MODE mem  : XXH3_64bits over contents preloaded into memory once (pure
 *               hashing cost, no file system)
 * LISTFILE: one absolute path per line.
 * Prints: files, bytes, then per-iteration milliseconds summary
 * (median, min, max) over ITERATIONS runs, after one untimed warm-up run.
 */
#define XXH_INLINE_ALL
#include "xxhash.h"

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

static double now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec * 1e3 + (double)ts.tv_nsec / 1e6;
}

static int cmp_double(const void *a, const void *b) {
  double x = *(const double *)a, y = *(const double *)b;
  return (x > y) - (x < y);
}

static char **paths;
static size_t npaths;
static char *buf;
static size_t bufcap;
static volatile unsigned long long sink;

static void die(const char *what, const char *path) {
  fprintf(stderr, "closurecost: %s: %s\n", what, path);
  exit(1);
}

static unsigned long long run_hash(void) {
  unsigned long long total = 0;
  for (size_t i = 0; i < npaths; i++) {
    int fd = open(paths[i], O_RDONLY);
    if (fd < 0) die("open failed", paths[i]);
    struct stat st;
    if (fstat(fd, &st) != 0) die("fstat failed", paths[i]);
    size_t size = (size_t)st.st_size;
    if (size > bufcap) {
      bufcap = size * 2;
      buf = realloc(buf, bufcap);
      if (!buf) die("out of memory", paths[i]);
    }
    size_t got = 0;
    while (got < size) {
      ssize_t n = read(fd, buf + got, size - got);
      if (n <= 0) die("read failed", paths[i]);
      got += (size_t)n;
    }
    close(fd);
    sink ^= XXH3_64bits(buf, size);
    total += size;
  }
  return total;
}

static unsigned long long run_stat(void) {
  unsigned long long total = 0;
  for (size_t i = 0; i < npaths; i++) {
    struct stat st;
    if (stat(paths[i], &st) != 0) die("stat failed", paths[i]);
    sink ^= (unsigned long long)st.st_mtimespec.tv_nsec ^
            (unsigned long long)st.st_size;
    total += (unsigned long long)st.st_size;
  }
  return total;
}

static unsigned long long run_open(void) {
  for (size_t i = 0; i < npaths; i++) {
    int fd = open(paths[i], O_RDONLY);
    if (fd < 0) die("open failed", paths[i]);
    close(fd);
  }
  return 0;
}

static char **contents;
static size_t *sizes;

static unsigned long long load_mem(void) {
  unsigned long long total = 0;
  contents = calloc(npaths, sizeof *contents);
  sizes = calloc(npaths, sizeof *sizes);
  for (size_t i = 0; i < npaths; i++) {
    int fd = open(paths[i], O_RDONLY);
    if (fd < 0) die("open failed", paths[i]);
    struct stat st;
    if (fstat(fd, &st) != 0) die("fstat failed", paths[i]);
    sizes[i] = (size_t)st.st_size;
    contents[i] = malloc(sizes[i] + 1);
    size_t got = 0;
    while (got < sizes[i]) {
      ssize_t n = read(fd, contents[i] + got, sizes[i] - got);
      if (n <= 0) die("read failed", paths[i]);
      got += (size_t)n;
    }
    close(fd);
    total += sizes[i];
  }
  return total;
}

static unsigned long long run_mem(void) {
  unsigned long long total = 0;
  for (size_t i = 0; i < npaths; i++) {
    sink ^= XXH3_64bits(contents[i], sizes[i]);
    total += sizes[i];
  }
  return total;
}

int main(int argc, char **argv) {
  if (argc != 4) {
    fprintf(stderr, "usage: closurecost hash|stat|open|mem LISTFILE ITERATIONS\n");
    return 2;
  }
  unsigned long long (*run)(void);
  if (strcmp(argv[1], "hash") == 0) run = run_hash;
  else if (strcmp(argv[1], "stat") == 0) run = run_stat;
  else if (strcmp(argv[1], "open") == 0) run = run_open;
  else if (strcmp(argv[1], "mem") == 0) run = run_mem;
  else die("bad mode", argv[1]);
  int iters = atoi(argv[3]);
  if (iters < 1) die("bad iteration count", argv[3]);

  FILE *f = fopen(argv[2], "r");
  if (!f) die("cannot open list", argv[2]);
  char line[4096];
  size_t cap = 0;
  while (fgets(line, sizeof line, f)) {
    size_t len = strlen(line);
    while (len && (line[len - 1] == '\n' || line[len - 1] == '\r'))
      line[--len] = 0;
    if (!len) continue;
    if (npaths == cap) {
      cap = cap ? cap * 2 : 1024;
      paths = realloc(paths, cap * sizeof *paths);
      if (!paths) die("out of memory", argv[2]);
    }
    paths[npaths++] = strdup(line);
  }
  fclose(f);

  unsigned long long bytes;
  if (run == run_mem) load_mem();
  bytes = run(); /* warm-up */
  if (run == run_open) bytes = run_stat();
  double *t = malloc((size_t)iters * sizeof *t);
  for (int i = 0; i < iters; i++) {
    double t0 = now_ms();
    run();
    t[i] = now_ms() - t0;
  }
  qsort(t, (size_t)iters, sizeof *t, cmp_double);
  printf("mode=%s files=%zu bytes=%llu iters=%d median_ms=%.3f min_ms=%.3f "
         "max_ms=%.3f\n",
         argv[1], npaths, bytes, iters, t[iters / 2], t[0], t[iters - 1]);
  return 0;
}
