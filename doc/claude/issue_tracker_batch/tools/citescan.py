#!/usr/bin/env python3
"""Scan every issue file for file:line citations and ask whether they can possibly be right.

This is a LOWER BOUND on rotted citations. It catches only two things:
  - the cited path does not exist at all
  - the cited line number is past the end of the file
It CANNOT catch the dangerous case (the citation resolves, but the line now holds
different text) -- that is the +15 shift that cost the last batch its worst error.
"""
import os, re, sys, collections

REPO = "/home/analog/dev/xschem-claude"
ISSUES = os.path.join(REPO, "doc/claude/issues")

CITE = re.compile(r'([A-Za-z0-9_][A-Za-z0-9_./+-]*\.(?:c|h|tcl|sh|js|md|y|l|awk|py|conf|in))'
                  r':(\d+)(?:-(\d+))?')

# index every file in the repo by basename, skipping .git
by_base = collections.defaultdict(list)
for root, dirs, files in os.walk(REPO):
    dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules')]
    for fn in files:
        by_base[fn].append(os.path.join(root, fn))

linecache = {}
def nlines(p):
    if p not in linecache:
        try:
            with open(p, 'rb') as fh:
                linecache[p] = sum(1 for _ in fh)
        except Exception:
            linecache[p] = -1
    return linecache[p]

def resolve(path):
    """Return (abspath, how) or (None, why)."""
    cand = os.path.join(REPO, path)
    if os.path.isfile(cand):
        return cand, 'exact'
    base = os.path.basename(path)
    hits = by_base.get(base, [])
    # prefer a hit whose tail matches the cited path
    tailed = [h for h in hits if h.endswith('/' + path.lstrip('./'))]
    if len(tailed) == 1:
        return tailed[0], 'tail'
    if len(hits) == 1:
        return hits[0], 'basename'
    if len(hits) > 1:
        return None, 'ambiguous'
    return None, 'missing'

tot_cites = 0
tot_files_with_cites = 0
stat = collections.Counter()
past_eof = []
missing = []
per_issue_bad = collections.Counter()

issues = sorted(f for f in os.listdir(ISSUES)
                if re.match(r'^\d{4}-.*\.md$', f))

for fn in issues:
    p = os.path.join(ISSUES, fn)
    try:
        text = open(p, encoding='utf-8', errors='replace').read()
    except Exception:
        continue
    seen = set()
    for m in CITE.finditer(text):
        path, a, b = m.group(1), int(m.group(2)), m.group(3)
        key = (path, a, b)
        if key in seen:
            continue
        seen.add(key)
        # skip self-referential issue-file citations to other issue docs? no -- count them
        tot_cites += 1
        target, how = resolve(path)
        if target is None:
            stat['unresolved-' + how] += 1
            if how == 'missing':
                missing.append((fn, path, a))
                per_issue_bad[fn] += 1
            continue
        n = nlines(target)
        hi = int(b) if b else a
        if n < 0:
            stat['unreadable'] += 1
        elif hi > n:
            stat['PAST-EOF'] += 1
            past_eof.append((fn, path, hi, n))
            per_issue_bad[fn] += 1
        else:
            stat['in-range'] += 1
    if seen:
        tot_files_with_cites += 1

print("=== corpus ===")
print("issue files scanned          :", len(issues))
print("issue files carrying a cite  :", tot_files_with_cites)
print("distinct file:line citations :", tot_cites)
print()
print("=== verdicts ===")
for k, v in stat.most_common():
    print(f"{k:24s}: {v}")
print()
bad = stat['PAST-EOF'] + stat['unresolved-missing']
print(f"DEMONSTRABLY WRONG (lower bound): {bad}  "
      f"({100.0*bad/max(tot_cites,1):.1f}% of citations)")
print(f"issue files carrying >=1 such   : {len(per_issue_bad)}  "
      f"({100.0*len(per_issue_bad)/max(tot_files_with_cites,1):.1f}% of citing files)")
print()
print("=== worst 15 issue files by broken-citation count ===")
for fn, c in per_issue_bad.most_common(15):
    print(f"{c:4d}  {fn}")
print()
print("=== 12 sample PAST-EOF (cited line beyond end of file) ===")
for fn, path, hi, n in past_eof[:12]:
    print(f"  {fn[:44]:44s} cites {path}:{hi} but that file has {n} lines")
print()
print("=== 12 sample MISSING (no such file anywhere in repo) ===")
for fn, path, a in missing[:12]:
    print(f"  {fn[:44]:44s} cites {path}:{a}")
