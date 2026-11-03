/* pipetrace.c - S20, D-160: Emacs's side of clangd's input pipe.  Spike code,
   never promoted.  Built and loaded by eglot-share.sh (S20_PIPETRACE) into the
   spike's batch Emacs only, with DYLD_INSERT_LIBRARIES (the Mac).

   Records, in memory, written to $PIPETRACE_OUT when Emacs exits, one line each
   (KIND T0 T1 FD A B C D, times in ns of CLOCK_REALTIME, as `float-time'):
   W  each write to a pipe: A bytes asked, B bytes written or -errno, C the
      pipe's fill after it, D its fill before (fstat's st_size on the write end);
   S  each pselect while a write to a pipe waits (from a write that gets EAGAIN
      until a write to that pipe takes all it was given): A the timeout, B the
      result or -errno, C the fill before, D the fill after;
   F  the fill of the pipe last written, polled about every 0.1 ms by a thread
      of its own until the pipe is empty and 5 ms passed without a write: A the
      fill, recorded when it changes and at least every millisecond.
   Only writes of 16 bytes or more to fds above 2 count as messages (stall and
   fill); Emacs's 1-byte wakeup writes to its own pipes are recorded only.  */
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define MAX_EVENTS 1000000
#define MIN_MESSAGE 16
#define QUIET_NS 5000000

struct event
{
  uint64_t t0, t1;
  int64_t a, b, c, d;
  int fd;
  char kind;
};

static struct event events[MAX_EVENTS];
static atomic_long nevents;
static atomic_long dropped;
static atomic_int stall_fd = -1;
static atomic_int watch_fd = -1;
static atomic_ullong last_write;
static pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t cv = PTHREAD_COND_INITIALIZER;

static uint64_t
now (void)
{
  return clock_gettime_nsec_np (CLOCK_REALTIME);
}

static void
record (char kind, int fd, uint64_t t0, uint64_t t1,
        int64_t a, int64_t b, int64_t c, int64_t d)
{
  long i = atomic_fetch_add (&nevents, 1);
  if (i >= MAX_EVENTS)
    {
      atomic_fetch_add (&dropped, 1);
      return;
    }
  events[i] = (struct event) { t0, t1, a, b, c, d, fd, kind };
}

/* Bytes waiting in the pipe FD (either end), or -1 if FD is no pipe.  */
static int64_t
fill (int fd)
{
  struct stat st;
  return fstat (fd, &st) == 0 && S_ISFIFO (st.st_mode) ? st.st_size : -1;
}

static void
watch (int fd)
{
  atomic_store (&last_write, now ());
  if (atomic_load (&watch_fd) != fd)
    {
      pthread_mutex_lock (&mu);
      atomic_store (&watch_fd, fd);
      pthread_cond_signal (&cv);
      pthread_mutex_unlock (&mu);
    }
}

static ssize_t
trace_write (int fd, const void *buf, size_t n)
{
  int64_t before = fill (fd);
  if (before < 0)
    return write (fd, buf, n);
  uint64_t t0 = now ();
  ssize_t r = write (fd, buf, n);
  int e = errno;
  uint64_t t1 = now ();
  record ('W', fd, t0, t1, (int64_t) n, r < 0 ? -e : r, fill (fd), before);
  if (fd > 2 && n >= MIN_MESSAGE)
    {
      if (r < 0 && e == EAGAIN)
        atomic_store (&stall_fd, fd);
      else if (r == (ssize_t) n && atomic_load (&stall_fd) == fd)
        atomic_store (&stall_fd, -1);
      watch (fd);
    }
  errno = e;
  return r;
}

extern int pselect_ext (int, fd_set *restrict, fd_set *restrict,
                        fd_set *restrict, const struct timespec *restrict,
                        const sigset_t *restrict)
  __asm ("_pselect$DARWIN_EXTSN");

static int
trace_pselect (int n, fd_set *restrict r, fd_set *restrict w,
               fd_set *restrict x, const struct timespec *restrict timeout,
               const sigset_t *restrict mask)
{
  int fd = atomic_load (&stall_fd);
  if (fd < 0)
    return pselect_ext (n, r, w, x, timeout, mask);
  int64_t before = fill (fd);
  uint64_t t0 = now ();
  int result = pselect_ext (n, r, w, x, timeout, mask);
  int e = errno;
  uint64_t t1 = now ();
  record ('S', fd, t0, t1,
          timeout ? (int64_t) timeout->tv_sec * 1000000000 + timeout->tv_nsec : -1,
          result < 0 ? -e : result, before, fill (fd));
  errno = e;
  return result;
}

static void *
monitor (void *unused)
{
  (void) unused;
  for (;;)
    {
      pthread_mutex_lock (&mu);
      while (atomic_load (&watch_fd) < 0)
        pthread_cond_wait (&cv, &mu);
      pthread_mutex_unlock (&mu);
      int fd = atomic_load (&watch_fd);
      int64_t last = -2;
      uint64_t last_t = 0;
      for (;;)
        {
          int64_t f = fill (fd);
          uint64_t t = now ();
          if (f != last || t - last_t >= 1000000)
            {
              record ('F', fd, t, t, f, 0, 0, 0);
              last = f;
              last_t = t;
            }
          if (f <= 0 && t - atomic_load (&last_write) >= QUIET_NS)
            break;
          if (atomic_load (&watch_fd) != fd)
            break;
          usleep (100);
        }
      int expected = fd;
      if (atomic_compare_exchange_strong (&watch_fd, &expected, -1)
          && now () - atomic_load (&last_write) < QUIET_NS)
        atomic_store (&watch_fd, fd); /* A write slipped in: keep watching.  */
    }
  return NULL;
}

__attribute__ ((constructor)) static void
start (void)
{
  sigset_t all, old;
  pthread_t thread;
  sigfillset (&all);
  /* No signal of Emacs's is ever delivered to the monitor thread.  */
  pthread_sigmask (SIG_BLOCK, &all, &old);
  pthread_create (&thread, NULL, monitor, NULL);
  pthread_sigmask (SIG_SETMASK, &old, NULL);
}

__attribute__ ((destructor)) static void
dump (void)
{
  const char *path = getenv ("PIPETRACE_OUT");
  FILE *out = path ? fopen (path, "w") : NULL;
  if (!out)
    return;
  long n = atomic_load (&nevents);
  if (n > MAX_EVENTS)
    n = MAX_EVENTS;
  fprintf (out, "# pipetrace pid %d events %ld dropped %ld\n", getpid (), n,
           atomic_load (&dropped));
  for (long i = 0; i < n; i++)
    fprintf (out, "%c %llu %llu %d %lld %lld %lld %lld\n", events[i].kind,
             (unsigned long long) events[i].t0,
             (unsigned long long) events[i].t1, events[i].fd,
             (long long) events[i].a, (long long) events[i].b,
             (long long) events[i].c, (long long) events[i].d);
  fclose (out);
}

#define INTERPOSE(replacement, replacee)                                  \
  __attribute__ ((used)) static const struct                              \
  {                                                                       \
    const void *replacement_, *replacee_;                                 \
  } interpose_##replacee __attribute__ ((section ("__DATA,__interpose"))) \
    = { (const void *) &replacement, (const void *) &replacee }

INTERPOSE (trace_write, write);
INTERPOSE (trace_pselect, pselect_ext);
