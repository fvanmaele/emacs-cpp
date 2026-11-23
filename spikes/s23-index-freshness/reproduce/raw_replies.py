"""Print the raw JSON reply of the last stale index answer per key query (run in logs/)."""
import json, re, sys
for js, sess, query in [("header_disk-nav.json","s3","def w.run() typedef"),
                        ("header_disk-nav.json","s2","def f(1) overload"),
                        ("header_live-nav.json","s2","def w.run() typedef"),
                        ("header_first_define-nav.json","s3","def f(1) in header opened first"),
                        ("target_moved-nav.json","s2","def g() moved in g.cpp"),
                        ("target_moved_slow-nav-rerun1.json","s3","def g() moved in g.cpp")]:
    r = json.load(open(js))
    recs = [x for x in r["sessions"][sess]["records"] if x["query"] == query and x["verdict"] == "stale" and x["path"] == "index"]
    if not recs: print(js, "none"); continue
    rid = recs[-1]["rid"]; t = recs[-1]["t_reply"]
    log = js.replace(".json", "-%s.log" % sess)
    for line in open(log):
        if line.startswith("V") and '>>> {"id":%d,' % rid in line:
            print("%s %s %s id=%d t=%.3f n=%d" % (js, sess, query, rid, t, len(recs)))
            print("  " + re.sub(r'file:///\S*?/work/[^/]+/', '', line.split(">>> ")[1].strip()))
