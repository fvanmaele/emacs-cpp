"""S19 (T-132, D-171 .. D-173): compare client.py replies and bench lists.

Spike code, never promoted.
  python3 -I compare.py same A.jsonl B.jsonl
      Criterion 2 (and a baseline against itself): every request's items equal up to
      ties: the same scores in order, the same items within each run of equal
      scores, except the last run when the limit cut the list (its members may
      differ, its length not); a list shorter than its limit is compared whole. Two runs of one clangd differ in exactly that (vec, vector at
      limit 100: equal scores across the cut). Prints each difference; exit 1 if any.
  python3 -I compare.py tiers BASE.jsonl GAP.jsonl CLASSIFY
      Criterion 1 at the server: CLASSIFY (classify.cpp) classes each item of each
      workspace/symbol reply in GAP on its full name and on its identifier; an
      item `gap` on the full name is certainly tier 3, one `fuzzy` or `sub` on the
      identifier certainly tier 1 - 2 (clangd matches the symbol's name, between
      the two), and no certain tier 1 - 2 item may follow a certain tier 3 one. Counts tier 1 - 2
      items lost and added against BASE (the reply without the field) and where
      `eto` at limit 10000 places deal.II's Vectors. (The exposed score is not the
      one replies rank by, so order is checked by class, not score.)
  python3 -I compare.py lists LISTS.tsv
      Criterion 1 in the index (bench.cpp's lists, with Dex's final scores): in
      each gap-* configuration no `fuzzy` or `sub` result after a `gap` one; in
      every list the scores never rise (so lists order results of different
      scores alike, only equal ones may swap); tier 1 - 2 results lost and added
      against middle-N are counted (the
      gap pass also admits fuzzy matches today's trigrams never offer). Exit 1 on
      a broken rule.
"""
import collections
import json
import re
import subprocess
import sys


RESOURCE = re.compile(r"file://\S*/lib/clang/[0-9]+/include/")


def load(path, with_scores=False):
    """Items with clangd's resource directory as `<resource>/`: the build tree's
    clangd finds its compiler headers under build/lib/clang, the installed one
    under /usr/lib/clang, the same files."""
    out = collections.OrderedDict()
    with open(path) as f:
        for line in f:
            d = json.loads(line)
            key = (d["kind"], d["query"], d["limit"])
            items = [RESOURCE.sub("<resource>/", x) for x in d["items"]]
            out[key] = (items, d.get("scores")) if with_scores else items
    return out


def groups(items, scores):
    """Runs of equal scores: [(score, set of items)] in order."""
    out = []
    for item, score in zip(items, scores):
        if out and out[-1][0] == score:
            out[-1][1].add(item)
        else:
            out.append((score, {item}))
    return out


def equal_up_to_ties(a, b, limit):
    (ia, sa), (ib, sb) = a, b
    if sa is None or sb is None:
        return ia == ib
    if sa != sb:
        return False
    ga, gb = groups(ia, sa), groups(ib, sb)
    cut = limit is not None and len(ia) >= limit
    return ga == gb if not cut else all(x == y for x, y in zip(ga[:-1], gb[:-1]))


def same(a, b):
    ra, rb = load(a, True), load(b, True)
    bad = 0
    for key in ra:
        if key not in rb:
            print("missing in B:", key)
            bad += 1
        elif not equal_up_to_ties(ra[key], rb[key], key[2]):
            ra[key], rb[key] = ra[key][0], rb[key][0]
            first = next((i for i, (x, y) in enumerate(zip(ra[key], rb[key])) if x != y),
                         min(len(ra[key]), len(rb[key])))
            print("differs: %s %s %s: %d vs %d items, first at %d" % (
                key[0], key[1], key[2], len(ra[key]), len(rb[key]), first))
            bad += 1
    print("same: %d requests, %d differ" % (len(ra), bad))
    return 1 if bad else 0


def unqualified(qualified):
    """The symbol's name in "scope::Name<args>": after the last `::` outside
    angle brackets (containers carry template arguments too)."""
    depth, cut = 0, 0
    for i, c in enumerate(qualified):
        if c == "<":
            depth += 1
        elif c == ">":
            depth -= 1
        elif c == ":" and depth == 0 and qualified[i + 1:i + 2] == ":":
            cut = i + 2
    return qualified[cut:]


def tiers(base, gap, classifier):
    rb, rg = load(base), load(gap)
    bad = 0
    for key, items in rg.items():
        if key[0] != "symbol":
            continue
        query = key[1]
        names = [unqualified(x.split(" ", 1)[1]) for x in items]
        pairs = subprocess.run([classifier], input="".join(
            "%s\t%s\n" % (query, n) for n in names), capture_output=True, text=True,
            check=True).stdout.splitlines()
        full = [p.split()[0] for p in pairs]
        ident = [p.split()[1] for p in pairs]
        out = ["gap" if f == "gap" else "tier12" for f in full]
        first_gap = next((i for i, c in enumerate(full) if c == "gap"), len(full))
        late = [i for i in range(first_gap, len(full)) if ident[i] != "gap"]
        if late:
            print("%s limit %s: %s (%s) at %d after the first gap match at %d" % (
                query, key[2], names[late[0]], ident[late[0]], late[0] + 1,
                first_gap + 1))
            bad += 1
        nongap = collections.Counter(x for x, c in zip(items, out) if c != "gap")
        before = collections.Counter(rb.get(key, []))
        lost = sum((before - nongap).values())
        added = sum((nongap - before).values())
        note = ""
        if query == "eto" and key[2] == 10000:
            ranks = [i + 1 for i, (x, c) in enumerate(zip(items, out))
                     if c == "gap" and x.endswith("::Vector") and "dealii::" in x]
            note = "; dealii Vectors in tier 3: %d, first at rank %s" % (
                len(ranks), ranks[0] if ranks else "-")
        print("%-7s limit %5s: %5d items, %5d gap; tier 1 - 2 lost %d, added %d%s" % (
            query, key[2], len(items), out.count("gap"), lost, added, note))
    print("tiers: %d broken" % bad)
    return 1 if bad else 0


def lists(path):
    rows = collections.defaultdict(list)
    with open(path) as f:
        for line in f:
            config, query, rank, name, cls, score = line.rstrip("\n").split("\t")
            rows[(config, query)].append((name, cls, float(score)))
    bad = 0
    for (config, query), items in rows.items():
        # Scores never rise in any list, so two results of different scores
        # keep their order between lists; only equal scores may swap.
        rising = [i for i in range(len(items) - 1) if items[i + 1][2] > items[i][2]]
        if rising:
            print("%s %s: score rises at rank %d" % (config, query, rising[0] + 2))
            bad += 1
        if not config.startswith("gap-"):
            continue
        # Tiers: no tier 1 - 2 result after a gap one, scores never rising.
        seen_gap = False
        for name, cls, _ in items:
            if cls == "gap":
                seen_gap = True
            elif seen_gap:
                print("%s %s: %s (%s) after a gap match" % (config, query, name, cls))
                bad += 1
                break
        # Against the list without the field: lost and added tier 1 - 2 results.
        base = rows.get(("middle-" + config[4:], query), [])
        non = [(n, s) for n, c, s in items if c != "gap"]
        count = collections.Counter(n for n, _ in non)
        lost = sum((collections.Counter(n for n, _, _ in base) - count).values())
        added = sum((count - collections.Counter(n for n, _, _ in base)).values())
        gaps = sum(1 for _, c, _ in items if c == "gap")
        vec = [i + 1 for i, (n, c, _) in enumerate(items)
               if c == "gap" and n.endswith("::Vector") and n.startswith("dealii::")]
        print("%-10s %-7s %5d results, %5d gap; tier 1 - 2 lost %d, added %d%s" % (
            config, query, len(items), gaps, lost, added,
            "; dealii Vector at rank %d" % vec[0] if query == "eto" and vec else ""))
    print("lists: %d broken" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "same":
        sys.exit(same(*sys.argv[2:4]))
    if mode == "tiers":
        sys.exit(tiers(*sys.argv[2:5]))
    sys.exit(lists(sys.argv[2]))
