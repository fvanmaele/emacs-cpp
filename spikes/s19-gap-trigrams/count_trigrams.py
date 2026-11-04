"""S19 (D-171, D-172): posting entries per trigram rule over an index's symbols.

Spike code, never promoted.  Reads `dexp ... export --format=yaml` output (one YAML
document per symbol, its `Name:`), ports clangd 23's `calculateRoles` and
`identifierTrigrams` (index/dex/Trigram.cpp), and counts, per rule, the distinct
trigrams of each symbol summed over all symbols (= posting list entries):
  ordinary   clangd today, 3-letter trigrams plus its short ones
  seg-next   gap kind as RESEARCH_go_to_anything 20 (c): from any letter, the next
             letter any later one of the same segment or the next segment's head
  head-next  as seg-next, the first letter a segment head only (RUN.md's wording)
  alnum      D-120 / D-141's tier 3: any in-order triple inside one run of letters
             and digits (gaps cross camel-case boundaries, never separators)
Usage: python3 -I count_trigrams.py EXPORT.yaml
"""
import sys

CHAR_TYPES = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff,
              0x55, 0x55, 0xf5, 0xff, 0xab, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xea, 0xff,
              0x57, 0x55, 0x55, 0x55, 0x55, 0x55, 0xd5, 0x3f] + [0x55] * 32
CHAR_ROLES = [0x00, 0xaa, 0xaa, 0xff, 0x00, 0x55, 0xaa, 0xff,
              0x00, 0x55, 0x59, 0xff, 0x00, 0xaa, 0xaa, 0xff]
UNKNOWN, TAIL, HEAD, SEPARATOR = 0, 1, 2, 3
EMPTY, LOWER, UPPER, PUNCT = 0, 1, 2, 3


def lookup(table, i):
    return (table[i >> 2] >> ((i & 3) * 2)) & 3


def roles(text):
    b = text.encode('utf-8', 'surrogateescape')
    if not b:
        return []
    types = lookup(CHAR_TYPES, b[0])
    out = []
    for i in range(len(b) - 1):
        t = lookup(CHAR_TYPES, b[i + 1])
        types = ((types << 2) | t) & 0x3f
        out.append(lookup(CHAR_ROLES, types))
    # The last character: rotate in Empty.
    types = ((types << 2) | EMPTY) & 0x3f
    out.append(lookup(CHAR_ROLES, types))
    return out, b.lower()


def next_tables(r):
    n = len(r)
    nxt = [None] * n
    next_tail = next_head = 0
    for i in range(n - 1, -1, -1):
        nxt[i] = (next_tail, next_head)
        next_tail = i if r[i] == TAIL else 0
        if r[i] == HEAD:
            next_head = i
    return nxt


def ordinary(r, low):
    nxt = next_tables(r)
    out = set()
    for i in range(len(low)):
        if r[i] not in (HEAD, TAIL):
            continue
        for j in nxt[i]:
            if j == 0:
                continue
            for k in nxt[j]:
                if k == 0:
                    continue
                out.add(bytes((low[i], low[j], low[k])))
    pos, heads = 0, 0
    while heads < 2:
        if r[pos] == HEAD:
            heads += 1
        out.add(bytes((low[pos],)))
        for i in nxt[pos]:
            if i != 0:
                out.add(bytes((low[pos], low[i])))
        pos = nxt[pos][1]
        if pos == 0:
            break
    return out


def segments(r):
    """Segment id per position (None for separators)."""
    seg, cur = [], -1
    for x in r:
        if x == HEAD:
            cur += 1
        seg.append(cur if x in (HEAD, TAIL) else None)
    return seg


def seg_next(r, low, head_first):
    seg = segments(r)
    n = len(low)
    heads = [i for i in range(n) if r[i] == HEAD]

    def jumps(i):
        js = [j for j in range(i + 1, n) if seg[j] is not None and seg[j] == seg[i]]
        later = [h for h in heads if h > i]
        if later:
            js.append(later[0])
        return js
    out = set()
    for i in range(n):
        if r[i] not in (HEAD, TAIL) or (head_first and r[i] != HEAD):
            continue
        for j in jumps(i):
            for k in jumps(j):
                out.add(bytes((low[i], low[j], low[k])))
    return out


def alnum(low):
    out = set()
    run = []
    for c in low + b'\0':
        if chr(c).isalnum() or c > 127:
            run.append(c)
            continue
        m = len(run)
        for i in range(m):
            for j in range(i + 1, m):
                for k in range(j + 1, m):
                    out.add(bytes((run[i], run[j], run[k])))
        run = []
    return out


def names(path):
    with open(path, encoding='utf-8', errors='surrogateescape') as f:
        for line in f:
            if line.startswith('Name:'):
                v = line[5:].strip()
                if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
                    v = v[1:-1]
                yield v


def main():
    totals = {'ordinary': 0, 'seg-next': 0, 'head-next': 0, 'alnum': 0}
    distinct = {k: set() for k in totals}
    longest = {k: 0 for k in totals}
    count = 0
    for name in names(sys.argv[1]):
        if not name:
            continue
        r, low = roles(name)
        sets = {'ordinary': ordinary(r, low), 'seg-next': seg_next(r, low, False),
                'head-next': seg_next(r, low, True), 'alnum': alnum(low)}
        count += 1
        for k, s in sets.items():
            totals[k] += len(s)
            distinct[k] |= s
            longest[k] = max(longest[k], len(s))
    print(f"symbols {count}")
    for k in totals:
        print(f"{k:10s} posting entries {totals[k]:>10d}  x{totals[k] / totals['ordinary']:.2f}"
              f"  distinct {len(distinct[k]):>6d}  longest name {longest[k]}")


if __name__ == '__main__':
    main()
