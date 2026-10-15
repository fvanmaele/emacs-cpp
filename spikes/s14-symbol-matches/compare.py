"""S14: compare the baseline's and the spike clangd's replies against RUN.md's criteria.

Spike code, never promoted.
  python3 -I compare.py BASELINE.jsonl SPIKE.jsonl
Prints one line per criterion with PASS or FAIL and the numbers behind it, then the
mid-word and scoped replies' first names for reading.
"""
import json
import statistics
import sys


def load(path):
    rows = {}
    with open(path) as f:
        for line in f:
            r = json.loads(line)
            rows[(r["set"], r["query"], r["limit"])] = r
    return rows


base, spike = load(sys.argv[1]), load(sys.argv[2])
# What an abbreviated scope should reach in deal.II (any reply name containing it).
EXPECT = {"geom::vert": "GeometryInfo", "gi::vert": "GeometryInfo",
          "tria::n_act": "Triangulation", "dof::n_dofs": "DoFHandler",
          "vt::interp": "VectorTools", "mt::create": "MatrixTools",
          "dealii::vt::interp": "VectorTools"}
verdicts = []


def verdict(ok, text):
    verdicts.append(ok)
    print(("PASS " if ok else "FAIL ") + text)


# 1. Mid-word: new matches, each containing the query, all after the old ones.
for limit in (10000,):
    gained, misplaced = 0, 0
    for (s, q, lim), r in spike.items():
        if s != "middle" or lim != limit:
            continue
        old = base[(s, q, lim)]["names"]
        new = [n for n in r["names"] if n not in old]
        if new and all(q.lower() in n.split("::")[-1].lower() for n in new):
            gained += 1
        first_new = min((r["names"].index(n) for n in new), default=len(r["names"]))
        if any(r["names"].index(n) > first_new for n in old if n in r["names"]):
            misplaced += 1
    n = sum(1 for k in spike if k[0] == "middle" and k[2] == limit)
    verdict(gained == n, "1. mid-word: %d of %d queries gain matches containing the query"
            % (gained, n))
    verdict(misplaced == 0, "1b. mid-word: matches rank after every fuzzy one in %d of %d"
            % (n - misplaced, n))

# 2. Abbreviated scopes reach the expected class or namespace; the baseline does not.
reached, before = 0, 0
for q, want in EXPECT.items():
    if any(want in n for n in spike[("scoped", q, 10000)]["names"]):
        reached += 1
    if any(want in n for n in base[("scoped", q, 10000)]["names"]):
        before += 1
verdict(reached == len(EXPECT) and before < len(EXPECT),
        "2. scoped: %d of %d reach their scope (baseline %d)" % (reached, len(EXPECT), before))

# 3. Fuzzy queries: the baseline's reply is the head of the spike's, same order.
same = 0
keys = [k for k in base if k[0] == "fuzzy"]
for k in keys:
    old, new = base[k]["names"], spike[k]["names"]
    if new[:len(old)] == old:
        same += 1
verdict(same == len(keys), "3. fuzzy: baseline reply is the spike's head in %d of %d"
        % (same, len(keys)))

# 4. Time: medians at most 1.5 times the baseline's, every reply under 100 ms.
for s in ("fuzzy", "middle", "scoped"):
    b = [r["ms"] for k, r in base.items() if k[0] == s]
    p = [r["ms"] for k, r in spike.items() if k[0] == s]
    ok = statistics.median(p) <= 1.5 * statistics.median(b) + 1 and max(p) < 100
    verdict(ok, "4. time, %s: median %.1f ms (baseline %.1f), max %.1f ms (baseline %.1f)"
            % (s, statistics.median(p), statistics.median(b), max(p), max(b)))

print("\nFirst names, limit 10000 (spike; baseline count):")
for (s, q, lim), r in sorted(spike.items()):
    if s in ("middle", "scoped") and lim == 10000:
        print("  %-20s %5d (%5d)  %s" % (q, len(r["names"]), len(base[(s, q, lim)]["names"]),
                                       ", ".join(r["names"][:3])))
print("\nS14: %s" % ("all criteria pass" if all(verdicts) else "%d criteria fail"
                     % verdicts.count(False)))
