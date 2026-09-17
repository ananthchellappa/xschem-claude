#!/usr/bin/env python3
"""Check QUOTED source lines in issue files against the tree.

CREW_BRIEF rule 10: "a citation needs a tree state, not just a line", and quoting
the line is necessary-not-sufficient. This scanner tests the necessary half at
scale: when an issue file quotes a numbered source line -- the `grep -n` / `sed -n`
style `841:    puts "Start ..."` -- does that file actually say that at that line?

This is the rot class citescan.py CANNOT see: the path resolves, the line exists,
and the text is somebody else's now. It is what a +15-line edit above the citation
does to every number below it.
"""
import os, re, sys, collections

REPO = "/home/analog/dev/xschem-claude"
ISSUES = os.path.join(REPO, "doc/claude/issues")

FILEMENT = re.compile(r'([A-Za-z0-9_][A-Za-z0-9_./+-]*\.(?:c|h|tcl|sh|js|y|l|awk|py))')
# a numbered source line, as emitted by grep -n / sed -n: "841:    puts ..."
NUMLINE = re.compile(r'^\s{0,8}(\d{1,5}):(?:\t| )?(\S.*)$')

by_base = collections.defaultdict(list)
for root, dirs, files in os.walk(REPO):
    dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules')]
    for fn in files:
        by_base[fn].append(os.path.join(root, fn))

cache = {}
def lines_of(p):
    if p not in cache:
        try:
            cache[p] = open(p, encoding='utf-8', errors='replace').read().split('\n')
        except Exception:
            cache[p] = None
    return cache[p]

def resolve(path):
    cand = os.path.join(REPO, path)
    if os.path.isfile(cand):
        return cand
    base = os.path.basename(path)
    hits = by_base.get(base, [])
    tailed = [h for h in hits if h.endswith('/' + path.lstrip('./'))]
    if len(tailed) == 1:
        return tailed[0]
    if len(hits) == 1:
        return hits[0]
    return None

def norm(s):
    return re.sub(r'\s+', ' ', s).strip()

checked = 0
match = 0
mismatch = []
nofile = 0
per_issue_bad = collections.Counter()

issues = sorted(f for f in os.listdir(ISSUES) if re.match(r'^\d{4}-.*\.md$', f))

for fn in issues:
    p = os.path.join(ISSUES, fn)
    try:
        text = open(p, encoding='utf-8', errors='replace').read()
    except Exception:
        continue
    raw = text.split('\n')
    in_fence = False
    current_file = None
    for ln in raw:
        if ln.lstrip().startswith('```'):
            in_fence = not in_fence
            continue
        # track the most recent plausible source-file mention (prose or fence)
        fm = FILEMENT.findall(ln)
        if fm:
            # last mention on the line wins
            current_file = fm[-1]
        if not in_fence:
            continue
        m = NUMLINE.match(ln)
        if not m or current_file is None:
            continue
        num, quoted = int(m.group(1)), m.group(2)
        if len(norm(quoted)) < 12:      # too short to be distinctive
            continue
        tgt = resolve(current_file)
        if tgt is None:
            nofile += 1
            continue
        L = lines_of(tgt)
        if L is None or num < 1 or num > len(L):
            continue
        checked += 1
        actual = norm(L[num-1])
        want = norm(quoted)
        # the quote may be a prefix, or carry a trailing ";# comment" marker
        if want in actual or actual in want or actual.startswith(want[:40]):
            match += 1
        else:
            mismatch.append((fn, current_file, num, want[:70], actual[:70]))
            per_issue_bad[fn] += 1

print("=== quoted-source-line verification ===")
print("issue files scanned                    :", len(issues))
print("quoted numbered lines checkable        :", checked)
print("  ... where file+line resolved and MATCHED :", match)
print("  ... where the line says something ELSE   :", len(mismatch))
print("skipped, file not resolvable           :", nofile)
if checked:
    print(f"\nROTTED QUOTE RATE: {100.0*len(mismatch)/checked:.1f}%  "
          f"({len(mismatch)}/{checked})")
print("issue files carrying >=1 rotted quote  :", len(per_issue_bad))
print()
print("=== worst 12 issue files ===")
for fn, c in per_issue_bad.most_common(12):
    print(f"{c:4d}  {fn}")
print()
print("=== 20 sample rotted quotes ===")
for fn, f, n, want, actual in mismatch[:20]:
    print(f"\n  {fn[:60]}")
    print(f"    says {f}:{n} is |{want}|")
    print(f"    tree says              |{actual}|")
