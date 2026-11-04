"""S19 (T-132, D-171 .. D-173): compare client.py replies and bench lists.

Spike code, never promoted.
  python3 -I compare.py same A.jsonl B.jsonl
      Criterion 2 (and a baseline against itself): every request's items equal up to
      ties: the same scores in order, the same items within each run of equal
      scores, except the last run when the limit cut the list (its members may
      differ, its length not); a list shorter than its limit is compared whole. Two runs of one clangd differ in exactly that (vec, vector at
      limit 100: equal scores across the cut). Prints each difference; exit 1 if any.
  python3 -I compare.py prefix BASE.jsonl GAP.jsonl
      Criterion 1 at the server: for each workspace/symbol request, GAP's items
      start with BASE's items in order (tiers 1 - 2 keep their places and order),
      the rest are added after; prints how many were added and whether `eto` at
      limit 10000 added a `dealii::...::Vector`. Exit 1 if a prefix breaks.
  python3 -I compare.py lists LISTS.tsv
      Criterion 1 in the index (bench.cpp's lists): in each gap-* configuration,
      no `fuzzy` or `sub` result after a `gap` one; each gap-N list starts with
      middle-N's list of the same file. Exit 1 otherwise.
"""
import collections
import json
import sys


def load(path, with_scores=False):
    out = collections.OrderedDict()
    with open(path) as f:
        for line in f:
            d = json.loads(line)
            key = (d["kind"], d["query"], d["limit"])
            out[key] = (d["items"], d.get("scores")) if with_scores else d["items"]
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


def prefix(base, gap):
    rb, rg = load(base), load(gap)
    bad = 0
    for key, items in rb.items():
        if key[0] != "symbol":
            continue
        g = rg.get(key)
        if g is None:
            print("missing in GAP:", key)
            bad += 1
            continue
        if g[:len(items)] != items:
            first = next((i for i, (x, y) in enumerate(zip(items, g)) if x != y), len(items))
            print("prefix broken: %s limit %s at %d" % (key[1], key[2], first))
            bad += 1
            continue
        added = g[len(items):]
        note = ""
        if key[1] == "eto" and key[2] == 10000:
            vectors = [x for x in added if x.endswith("::Vector") and "dealii::" in x]
            note = "; dealii Vectors added: %d (e.g. %s)" % (
                len(vectors), vectors[0].split(" ", 1)[1] if vectors else "-")
        print("%-7s limit %5s: base %5d, added %5d%s" % (key[1], key[2], len(items),
                                                          len(added), note))
    print("prefix: %d broken" % bad)
    return 1 if bad else 0


def lists(path):
    rows = collections.defaultdict(list)
    with open(path) as f:
        for line in f:
            config, query, rank, name, cls = line.rstrip("\n").split("\t")
            rows[(config, query)].append((name, cls))
    bad = 0
    for (config, query), items in rows.items():
        if not config.startswith("gap-"):
            continue
        seen_gap = False
        for name, cls in items:
            if cls == "gap":
                seen_gap = True
            elif seen_gap:
                print("%s %s: %s (%s) after a gap match" % (config, query, name, cls))
                bad += 1
                break
        base = rows.get(("middle-" + config[4:], query), [])
        if [n for n, _ in items[:len(base)]] != [n for n, _ in base]:
            print("%s %s: does not start with middle-%s's list" % (config, query, config[4:]))
            bad += 1
        gaps = sum(1 for _, c in items if c == "gap")
        vec = any(c == "gap" and n.endswith("::Vector") and n.startswith("dealii::")
                  for n, c in items)
        print("%-10s %-7s %5d results, %5d gap%s" % (
            config, query, len(items), gaps,
            ", dealii Vector among them" if query == "eto" and vec else ""))
    print("lists: %d broken" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    mode = sys.argv[1]
    sys.exit({"same": same, "prefix": prefix}[mode](*sys.argv[2:4]) if mode != "lists"
             else lists(sys.argv[2]))
