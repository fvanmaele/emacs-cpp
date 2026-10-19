"""S15: compare the baseline's and the spike clangd's replies against RUN.md's criteria.

Spike code, never promoted.
  python3 -I compare.py BASELINE.jsonl SPIKE.jsonl [BASELINE2.jsonl]
Prints one line per criterion with PASS or FAIL and the numbers behind it, then the
first names of each mid-word query for reading.  A match is High when its query
appears contiguously from a word start of the identifier (the name before template
arguments, without `~`), word starts as clangd's calculateRoles (FuzzyMatch.cpp)
finds them; every other match is Low (scattered fuzzy or mid-word).
"""
import json
import re
import statistics
import sys

# clangd 23.1.1 FuzzyMatch.cpp CharTypes / CharRoles, packed 2 bits each.
CHAR_TYPES = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff,
              0x55, 0x55, 0xf5, 0xff, 0xab, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xea, 0xff,
              0x57, 0x55, 0x55, 0x55, 0x55, 0x55, 0xd5, 0x3f] + [0x55] * 32
CHAR_ROLES = [0x00, 0xaa, 0xaa, 0xff, 0x00, 0x55, 0xaa, 0xff,
              0x00, 0x55, 0x59, 0xff, 0x00, 0xaa, 0xaa, 0xff]
TAIL, HEAD = 1, 2


def packed(table, i):
    return (table[i >> 2] >> ((i & 3) * 2)) & 3


def roles(text):
    data = text.encode()
    if not data:
        return []
    types = packed(CHAR_TYPES, data[0])
    out = []
    for i in range(len(data)):
        nxt = packed(CHAR_TYPES, data[i + 1]) if i + 1 < len(data) else 0
        types = ((types << 2) | nxt) & 0x3f
        out.append(packed(CHAR_ROLES, types))
    return out


def high(query, name):
    ident = name.split("<", 1)[0]
    if ident.startswith("~"):
        ident = ident[1:]
    low, q, r = ident.lower().encode(), query.lower().encode(), roles(ident)
    pos = low.find(q)
    while pos >= 0:
        if r[pos] == HEAD:
            return True
        pos = low.find(q, pos + 1)
    return False


def contains(query, name):
    return query.lower() in name.split("<", 1)[0].lower()


def load(path):
    rows = {}
    with open(path) as f:
        for line in f:
            r = json.loads(line)
            rows[(r["set"], r["query"], r["limit"])] = r
    return rows


base, spike = load(sys.argv[1]), load(sys.argv[2])
base2 = load(sys.argv[3]) if len(sys.argv) > 3 else None
FULL = 100000
queries = sorted({(s, q) for s, q, _ in spike})
verdicts = []


def verdict(ok, text):
    verdicts.append(ok)
    print(("PASS " if ok else "FAIL ") + text)


def ids(row):
    # clang's builtin headers lie next to each binary (the spike's build tree, the
    # installed package): the same symbol, another directory (dry run 1).
    # Several symbols share a position (a template and its specializations): the
    # name and container belong to the key (dry run 1).
    return ["%s %s::%s" % (re.sub(r"^.*/lib/clang/[0-9]+/include/", "<builtin>/", s["id"]),
                           s["container"], s["name"]) for s in row["symbols"]]


# 1. Mid-word queries: the cut at 100 keeps the best matches: every match that
#    ranks, by the spike's own key (High before Low, then its ranking score), at or
#    above the complete reply's 10th, ties counting as equal.  The rest of the 100
#    is not judged: Dex keeps its 100 by its own score before clangd re-ranks them,
#    and many symbols tie; the baseline misses the first 10 of `typ`, `ope`, `fin`
#    at limit 100 as well (dry runs 1 - 3).  Fuzzy queries reported.
def key(q, sym):
    return (high(q, sym["name"]), round(sym["score"], 6))


bad, notes = [], []
for s, q in queries:
    full, cut = spike[(s, q, FULL)]["symbols"], spike[(s, q, 100)]["symbols"]
    if not full:
        continue
    want = min(10, len(full))
    bar = key(q, full[want - 1])
    good = min(want, sum(1 for sym in cut if key(q, sym) >= bar))
    notes.append("%s %d/%d" % (q, good, want))
    if s == "middle" and good < want:
        bad.append(q)
middle_n = sum(1 for s, q in queries if s == "middle")
verdict(not bad, "1. mid-word: limit 100 holds the complete reply's first 10 in %d of %d%s"
        % (middle_n - len(bad), middle_n, "; short: " + ", ".join(bad) if bad else ""))
print("   " + "; ".join(notes))

# 2. Every High match before every Low one, in the complete replies.
bad = []
for s, q in queries:
    seen_low = False
    for sym in spike[(s, q, FULL)]["symbols"]:
        if high(q, sym["name"]):
            if seen_low:
                bad.append(q)
                break
        else:
            seen_low = True
verdict(not bad, "2. High before Low in %d of %d queries%s"
        % (len(queries) - len(bad), len(queries), "; not: " + ", ".join(bad) if bad else ""))


# 3. High matches keep the baseline's order up to ties: the spike reports its
#    ranking score (`score`, spike only), and the baseline's High matches, taken in
#    the baseline's order, never rise in it.  Equal scores may come in either order
#    (Dex's own order changed); a rise means a good match moved (dry run 1).
bad = []
for s, q in queries:
    score = {i: x["score"] for i, x in zip(ids(spike[(s, q, FULL)]),
                                           spike[(s, q, FULL)]["symbols"])}
    seq = [score[i] for i, x in zip(ids(base[(s, q, FULL)]), base[(s, q, FULL)]["symbols"])
           if high(q, x["name"]) and i in score]
    rises = sum(1 for a, b in zip(seq, seq[1:]) if b > a * (1 + 1e-5) + 1e-9)
    if rises:
        bad.append("%s %d" % (q, rises))
verdict(not bad, "3. High matches in the baseline's order up to ties in %d of %d queries%s"
        % (len(queries) - len(bad), len(queries), "; rises: " + ", ".join(bad) if bad else ""))

# 4. The same matches, only ranked differently.
bad = [q for s, q in queries
       if set(ids(spike[(s, q, FULL)])) != set(ids(base[(s, q, FULL)]))]
verdict(not bad, "4. same complete set of matches in %d of %d queries%s"
        % (len(queries) - len(bad), len(queries), "; differ: " + ", ".join(bad) if bad else ""))

# 5. Mid-word queries: the first result at limit 100 holds the query contiguously.
middle = [q for s, q in queries if s == "middle"]
bad = [q for q in middle
       if not spike[("middle", q, 100)]["symbols"]
       or not contains(q, spike[("middle", q, 100)]["symbols"][0]["name"])]
verdict(not bad, "5. mid-word: first result contains the query in %d of %d%s"
        % (len(middle) - len(bad), len(middle), "; not: " + ", ".join(bad) if bad else ""))

# 6. Time at limit 100: median per set at most 1.5x the baseline's + 1 ms, every
#    reply under 100 ms.  Complete replies reported.
for name in ("middle", "fuzzy"):
    b = [base[(name, q, 100)]["ms"][1] for s, q in queries if s == name]
    t = [spike[(name, q, 100)]["ms"][1] for s, q in queries if s == name]
    full = [spike[(name, q, FULL)]["ms"][1] for s, q in queries if s == name]
    verdict(statistics.median(t) <= 1.5 * statistics.median(b) + 1 and max(t) < 100,
            "6. %s: median %.1f ms (baseline %.1f), slowest %.1f ms; complete replies "
            "median %.1f, slowest %.1f ms" % (name, statistics.median(t), statistics.median(b),
                                              max(t), statistics.median(full), max(full)))

print("\nReported, not judged: fuzzy top 100 shared with the baseline (limit 100)")
print("   " + "; ".join("%s %d" % (q, len(set(ids(spike[(s, q, 100)]))
                                       & set(ids(base[(s, q, 100)]))))
                        for s, q in queries if s == "fuzzy"))
print("\nMid-word queries, first five at limit 100 (spike | baseline):")
for q in middle:
    def first(rows):
        return ", ".join((x["container"] + "::" if x["container"] else "") + x["name"][:30]
                         for x in rows[("middle", q, 100)]["symbols"][:5])
    print("   %s: %s\n      | %s" % (q, first(spike), first(base)))
print("\ncheck: %d of %d criteria pass (criterion 7, completion, is read in the patch)"
      % (sum(verdicts), len(verdicts)))
sys.exit(0 if all(verdicts) else 1)
