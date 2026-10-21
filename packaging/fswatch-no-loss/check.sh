#!/bin/sh
# check.sh - checks a built fswatch-no-loss binary (D-109, T-098). Builds nothing.
#
#   packaging/fswatch-no-loss/check.sh [FSWATCH]
#
# FSWATCH defaults to ~/opt/fswatch-no-loss/bin/fswatch on macOS and
# /opt/fswatch-no-loss/bin/fswatch elsewhere. Runs it in a temporary tree under
# $TMPDIR (deleted afterwards) and checks what the patches promise:
#   1. 10000 files created while the reader pauses all arrive (patch 0001);
#   2. a file created and removed again ends as Removed, without Created (0003 on
#      macOS; inotify reports the two events apart anyway);
#   3. past --queue-limit one Overflow record per watched path takes the place of
#      the waiting records and memory stays bounded; without --allow-overflow
#      fswatch stops with "Event queue overflow." (0001);
#   4. -l 0.1 is accepted under a locale with a decimal comma (0004), when such a
#      locale is installed (else said and skipped);
#   5. a change of an existing file is not reported Created, whether the file was
#      created before fswatch started or reported Created since; a file created
#      again after its removal is (0005 on macOS; inotify reports what happened).
# Patch 0002 (FSEvents drops as overflow) needs a drop, which 0001 prevents; it
# was checked by hand (RESEARCH_platform_differences.md 3.13).
# Needs python3. Exit status 0 when every check passes; each failure is printed.
set -eu

if [ $# -ge 1 ]; then
    fswatch=$1
elif [ "$(uname -s)" = Darwin ]; then
    fswatch=$HOME/opt/fswatch-no-loss/bin/fswatch
else
    fswatch=/opt/fswatch-no-loss/bin/fswatch
fi
[ -x "$fswatch" ] || { echo "check: no executable fswatch at $fswatch" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "check: python3 not found" >&2; exit 1; }
"$fswatch" --help | grep -q -- '--queue-limit' \
    || { echo "check: $fswatch has no --queue-limit; not the patched build" >&2; exit 1; }

# A locale with a decimal comma, if one is installed.
comma_locale=$(locale -a 2>/dev/null | grep -i -m1 -E '^de_DE\.utf-?8$' || true)

exec python3 -I - "$fswatch" "$comma_locale" <<'EOF'
import os, select, shutil, subprocess, sys, tempfile, time

fswatch, comma_locale = sys.argv[1], sys.argv[2]
env = dict(os.environ, LC_ALL='C')
failures = []

def check(ok, what):
    print(('PASS ' if ok else 'FAIL ') + what)
    if not ok:
        failures.append(what)

def start(root, *args):
    return subprocess.Popen([fswatch, '-0', '-r', '-x', '--event-flag-separator=,',
                             '-l', '0.1', *args, root],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)

def read_all(proc, quiet=2.0, limit=30.0):
    """Read records until none came for QUIET seconds."""
    fd, data, last, t0 = proc.stdout.fileno(), b'', time.time(), time.time()
    while time.time() - last < quiet and time.time() - t0 < limit:
        ready, _, _ = select.select([fd], [], [], 0.2)
        if ready:
            chunk = os.read(fd, 1 << 20)
            if not chunk:
                break
            data, last = data + chunk, time.time()
    return [r.decode(errors='replace') for r in data.split(b'\0') if r]

def rss_kb(proc):
    out = subprocess.run(['ps', '-o', 'rss=', '-p', str(proc.pid)],
                         capture_output=True, text=True).stdout.strip()
    return int(out or 0)

def create(root, n, prefix):
    for i in range(n):
        d = os.path.join(root, 'd%d' % (i % 200))
        with open(os.path.join(d, '%s%d.py' % (prefix, i)), 'w') as f:
            f.write('x')

def remove(root, n, prefix):
    for i in range(n):
        os.remove(os.path.join(root, 'd%d' % (i % 200), '%s%d.py' % (prefix, i)))

root = os.path.realpath(tempfile.mkdtemp(prefix='fswatch-no-loss-check.'))
try:
    for i in range(200):
        os.mkdir(os.path.join(root, 'd%d' % i))

    # 1. A paused reader loses nothing.
    proc = start(root)
    time.sleep(1)
    create(root, 10000, 'a')
    time.sleep(3)
    names = {r.split(' ')[0] for r in read_all(proc) if '/a' in r}
    proc.kill()
    check(len(names) == 10000,
          'paused reader: %d of 10000 created files reported' % len(names))
    remove(root, 10000, 'a')

    # 2. Created, then removed: the last record says Removed, not Created.
    proc = start(root)
    time.sleep(1)
    gone = os.path.join(root, 'd0', 'gone.py')
    with open(gone, 'w') as f:
        f.write('x')
    os.remove(gone)
    records = [r for r in read_all(proc) if r.startswith(gone + ' ')]
    proc.kill()
    flags = records[-1].split(' ', 1)[1].split(',') if records else []
    check('Removed' in flags and 'Created' not in flags,
          'created then removed: last record %r' % (records[-1] if records else None))

    # 3. The queue limit: one Overflow, bounded memory; an error without
    #    --allow-overflow.
    proc = start(root, '--allow-overflow', '--queue-limit=1000')
    time.sleep(1)
    before = rss_kb(proc)
    create(root, 25000, 'b')
    remove(root, 25000, 'b')
    time.sleep(3)
    grown = rss_kb(proc) - before
    records = read_all(proc)
    proc.kill()
    overflows = [r for r in records if r.endswith(' Overflow')]
    check(len(overflows) >= 1 and all(r == root + ' Overflow' for r in overflows),
          'queue limit 1000, 50000 events unread: %d Overflow record(s) for the root'
          % len(overflows))
    check(len(records) <= 2000,
          'queue limit 1000: %d records waited, not 50000' % len(records))
    check(grown < 3000,
          'queue limit 1000: memory grew by %d KB (unbounded: about 9000)' % grown)

    proc = start(root, '--queue-limit=1000')
    time.sleep(1)
    create(root, 3000, 'c')
    try:
        status = proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
        status = None
    err = proc.stderr.read().decode(errors='replace')
    check(status not in (None, 0) and 'Event queue overflow.' in err,
          'without --allow-overflow: exit status %s, stderr %r' % (status, err.strip()))
    remove(root, 3000, 'c')

    # 4. -l 0.1 under a locale with a decimal comma.
    if comma_locale:
        proc = subprocess.Popen([fswatch, '-l', '0.1', '-1', root],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                env=dict(os.environ, LC_ALL=comma_locale))
        time.sleep(1)
        with open(os.path.join(root, 'locale.py'), 'w') as f:
            f.write('x')
        try:
            status = proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
            status = None
        err = proc.stderr.read().decode(errors='replace')
        check(status == 0 and 'Invalid value' not in err,
              '-l 0.1 under %s: exit status %s, stderr %r' % (comma_locale, status, err.strip()))
    else:
        print('SKIP -l 0.1 under a decimal-comma locale: de_DE.UTF-8 is not installed')

    # 5. Created only when the file was: FSEvents keeps it on a recent file.
    old = os.path.join(root, 'd1', 'old.py')
    new = os.path.join(root, 'd1', 'new.py')
    with open(old, 'w') as f:
        f.write('x')
    proc = start(root)
    time.sleep(1)
    def last_flags(path):
        # The flags of all of the path's records in this read, as the config's
        # backend joins them (D-127): inotify writes one record per event (Created,
        # Updated, CloseWrite), FSEvents one record with them all.
        records = [r for r in read_all(proc) if r.startswith(path + ' ')]
        return sorted({f for r in records for f in r.split(' ', 1)[1].split(',')})
    with open(old, 'a') as f:
        f.write('y')
    flags = last_flags(old)
    check(flags and 'Created' not in flags,
          'created before the start, changed: flags %r' % flags)
    with open(new, 'w') as f:
        f.write('x')
    flags = last_flags(new)
    check('Created' in flags, 'created: flags %r' % flags)
    with open(new, 'a') as f:
        f.write('y')
    flags = last_flags(new)
    check(flags and 'Created' not in flags, 'created, then changed: flags %r' % flags)
    os.remove(new)
    last_flags(new)
    with open(new, 'w') as f:
        f.write('x')
    flags = last_flags(new)
    check('Created' in flags, 'removed, created again: flags %r' % flags)
    proc.kill()
finally:
    shutil.rmtree(root, ignore_errors=True)

print('check: %s' % ('all passed' if not failures else '%d failed' % len(failures)))
sys.exit(1 if failures else 0)
EOF
