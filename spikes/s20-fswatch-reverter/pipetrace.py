"""S20, D-160: summarize pipetrace.c's trace per checkout.  Spike code, never promoted.

    python3 -I pipetrace.py TRACE OUT

TRACE is pipetrace.c's event file, OUT the spike's output with its "pipetrace
window" lines (eglot-share.el).  For each checkout: the writes to clangd's pipe
(the fd above 2 with the most bytes), the blocked sends (a write that got EAGAIN
until the write that took all it was given), and for each blocked send its waits
in pselect and how long the pipe was full (no room for 512 bytes), had room, or
was empty meanwhile; then how long the pipe took to drain after each write.
"""
import bisect
import re
import sys
import time

EAGAIN = 35
CAPACITY = 65536
PIPE_BUF = 512


def clock(ns):
    seconds = ns / 1e9
    return time.strftime("%H:%M:%S", time.localtime(seconds)) + ".%03d" % (ns // 1000000 % 1000)


def ms(ns):
    return "%.1f" % (ns / 1e6)


def percentile(values, fraction):
    values = sorted(values)
    return values[min(len(values) - 1, int(fraction * len(values)))]


def load(path):
    events = []
    header = ""
    with open(path) as f:
        for line in f:
            if line.startswith("#"):
                header = line[1:].strip()
                continue
            kind, t0, t1, fd, a, b, c, d = line.split()
            events.append((kind, int(t0), int(t1), int(fd), int(a), int(b), int(c), int(d)))
    return header, events


def windows(path):
    found = []
    label = None
    with open(path) as f:
        for line in f:
            m = re.match(r"(.*checkout [^:]+): git ", line)
            if m:
                label = m.group(1)
            m = re.match(r"\s+pipetrace window \(D-160\): git ([0-9.]+), settled ([0-9.]+)", line)
            if m:
                found.append((label, int(float(m.group(1)) * 1e9), int(float(m.group(2)) * 1e9)))
    return found


def timeline(events, fd):
    """(TIME, FILL) of the pipe: the monitor's samples and each write's fill after."""
    points = [(e[1], e[4]) for e in events if e[0] == "F" and e[3] == fd]
    points += [(e[2], e[6]) for e in events if e[0] == "W" and e[3] == fd]
    points.sort()
    return points


def shares(points, start, end):
    """Nanoseconds the pipe was full, had room, was empty between START and END,
    and the longest gap between two samples there while it held data (an empty
    pipe stays empty until Emacs writes, and each write is a sample)."""
    full = room = empty = gap = 0
    i = max(0, bisect.bisect_right(points, (start, 1 << 62)) - 1)
    t, fill = start, points[i][1] if points else 0
    for t_next, fill_next in points[i + 1:]:
        if t_next <= start:
            fill = fill_next
            continue
        if t_next > end:
            break
        span = t_next - t
        if fill > 0:
            gap = max(gap, span)
        if fill >= CAPACITY - PIPE_BUF:
            full += span
        else:
            room += span
            if fill == 0:
                empty += span
        t, fill = t_next, fill_next
    span = end - t
    if fill >= CAPACITY - PIPE_BUF:
        full += span
    else:
        room += span
        if fill == 0:
            empty += span
    return full, room, empty, gap


def blocked_sends(writes):
    """Lists of writes, each from a message's first write to the one that finished it."""
    sends = []
    i = 0
    while i < len(writes):
        if writes[i][5] == -EAGAIN:
            # Back along the partial writes, each asking for what the last one left.
            first = i
            while (first > 0 and 0 < writes[first - 1][5] < writes[first - 1][4]
                   and writes[first - 1][4] - writes[first - 1][5] == writes[first][4]):
                first -= 1
            j = i
            while j < len(writes) and writes[j][5] != writes[j][4]:
                j += 1
            sends.append(writes[first:j + 1])
            i = j + 1
        else:
            i += 1
    return sends


def main(trace_path, out_path):
    header, events = load(trace_path)
    bytes_by_fd = {}
    for e in events:
        if e[0] == "W" and e[3] > 2 and e[5] > 0:
            bytes_by_fd[e[3]] = bytes_by_fd.get(e[3], 0) + e[5]
    if not bytes_by_fd:
        print("pipetrace (D-160): no writes to a pipe in %s" % trace_path)
        return
    fd = max(bytes_by_fd, key=bytes_by_fd.get)
    points = timeline(events, fd)
    times = [p[0] for p in points]
    print("pipetrace (D-160): %s (%s); clangd's pipe fd %d" % (trace_path, header, fd))
    for label, g0, g1 in windows(out_path):
        writes = [e for e in events if e[0] == "W" and e[3] == fd and g0 <= e[1] <= g1]
        waits = [e for e in events if e[0] == "S" and e[3] == fd and g0 <= e[1] <= g1]
        drains = []
        for w in writes:
            if w[5] <= 0:
                continue
            k = bisect.bisect_left(times, w[2])
            while k < len(points) and points[k][1] != 0:
                k += 1
            if k < len(points):
                drains.append(points[k][0] - w[2])
        sends = blocked_sends(writes)
        print("  %s: writes %d (%d KB), EAGAIN %d, blocked sends %d, pselect while blocked %d (%s ms)"
              % (label, len(writes), sum(w[5] for w in writes if w[5] > 0) // 1024,
                 sum(1 for w in writes if w[5] == -EAGAIN), len(sends), len(waits),
                 ms(sum(s[2] - s[1] for s in waits))))
        if drains:
            print("    pipe empty again after a write: median %s ms, 90%% %s ms, max %s ms (%d writes)"
                  % (ms(percentile(drains, 0.5)), ms(percentile(drains, 0.9)), ms(max(drains)),
                     len(drains)))
        for send in sends:
            start, end = send[0][1], send[-1][2]
            inside = [s for s in waits if start <= s[1] <= end]
            full, room, empty, gap = shares(points, start, end)
            print("    blocked send %s +%s ms, %d bytes, pipe held %d before it; %d writes (%d EAGAIN); pselect %d times, %s ms (%d timed out); pipe full %s ms, with room %s ms (empty %s ms); longest gap between fill samples %s ms"
                  % (clock(start), ms(end - start), send[0][4], send[0][7], len(send),
                     sum(1 for w in send if w[5] == -EAGAIN), len(inside),
                     ms(sum(s[2] - s[1] for s in inside)), sum(1 for s in inside if s[5] == 0),
                     ms(full), ms(room), ms(empty), ms(gap)))
            for n, w in enumerate(send):
                if w[5] != -EAGAIN:
                    continue
                k = bisect.bisect_right(times, w[2])
                took = next((p[0] - w[2] for p in points[k:] if p[1] < w[6]), None)
                following = send[n + 1][1] if n + 1 < len(send) else end
                slept = [s for s in inside if w[2] <= s[1] < following]
                print("      EAGAIN %s: fill %d; clangd took bytes %s ms later; next write %s ms later%s"
                      % (clock(w[1]), w[6], "never" if took is None else ms(took),
                         ms(following - w[2]),
                         "" if not slept else
                         "; pselect %d times, %s ms (%d timed out, first timeout %s ms), fill %d -> %d"
                         % (len(slept), ms(sum(s[2] - s[1] for s in slept)),
                            sum(1 for s in slept if s[5] == 0), ms(slept[0][4]),
                            slept[0][6], slept[-1][7])))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
