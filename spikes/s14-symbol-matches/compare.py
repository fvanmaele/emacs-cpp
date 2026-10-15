"""S14: compare the baseline's and the spike clangd's replies against RUN.md's criteria.

Spike code, never promoted.
  python3 -I compare.py BASELINE.jsonl SPIKE.jsonl [BASELINE2.jsonl]
Prints one line per criterion with PASS or FAIL and the numbers behind it, then the
mid-word and scoped replies' first names for reading.  BASELINE2, a second run of
the baseline, shows how much the order of equally scored symbols varies by itself.
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
          "vt::interp": "VectorTools", "spm::vmult": "SparseMatrix",
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
        bare = dict(zip(r["names"], r["bare"]))
        new = [n for n in r["names"] if n not in old]
        # The name without template arguments must contain the query.
        if new and all(q.lower() in bare[n].split("<")[0].lower() for n in new):
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

# 3. Fuzzy queries, complete replies (limit 10000, the same in two baseline runs):
#    the spike's reply begins with the baseline's, in the same order.  With limit
#    100 many symbols tie at the cut, and which make it varies by itself between
#    runs: reported against a second baseline run, not judged.
#    Within a run of equal scores the order is the top-N heap's tie order, which
#    more candidates change; so the order is compared run by run.
def same_up_to_ties(old, new, scores):
    if len(new) < len(old):
        return False
    i = 0
    while i < len(old):
        j = i
        while j + 1 < len(old) and scores[j + 1] == scores[i]:
            j += 1
        if sorted(old[i:j + 1]) != sorted(new[i:j + 1]):
            return False
        i = j + 1
    return True


keys = [k for k in base if k[0] == "fuzzy" and k[2] == 10000]
exact = sum(spike[k]["names"][:len(base[k]["names"])] == base[k]["names"] for k in keys)
ties = sum(same_up_to_ties(base[k]["names"], spike[k]["names"], base[k]["scores"])
           for k in keys)
verdict(ties == len(keys), "3. fuzzy, limit 10000: the spike's reply begins with the "
        "baseline's, same order up to ties, in %d of %d (exactly: %d)"
        % (ties, len(keys), exact))
cut = [k for k in base if k[0] == "fuzzy" and k[2] == 100]
cut_same = sum(sorted(spike[k]["names"]) == sorted(base[k]["names"]) for k in cut)
if len(sys.argv) > 3:
    base2 = load(sys.argv[3])
    full2 = sum(base2[k]["names"] == base[k]["names"] for k in keys)
    cut2 = sum(sorted(base2[k]["names"]) == sorted(base[k]["names"]) for k in cut)
    print("     limit 100, same names as the baseline: spike %d of %d, a second baseline "
          "run %d; limit 10000 equal between baseline runs: %d of %d"
          % (cut_same, len(cut), cut2, full2, len(keys)))
else:
    print("     limit 100, same names as the baseline: spike %d of %d" % (cut_same, len(cut)))

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
