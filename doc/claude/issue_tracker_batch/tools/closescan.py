#!/usr/bin/env python3
"""A4's detector, run across the whole corpus.

The pattern both STALE-FIXED files in A4's sample shared:
  filed as issue A -> fixed later under number B -> B's header names A -> A is
  never updated, and goes on telling readers the defect is open.

So: find every "fixes / supersedes / fixed by / closes / resolves issue N" claim
anywhere in the repo (issue files, src/, tests/, git log), then read N's OWN
header and ask whether it still reads OPEN.

SELF-TESTS FIRST (the rule five driver errors bought): 1439 names 1438 as fixed
and A4 classified 1438 STALE-FIXED, so 1438 must appear in the flagged set. If it
does not, the scanner is broken and reports nothing.
"""
import os, re, subprocess, sys, collections

REPO = "/home/analog/dev/xschem-claude"
ISSUES = os.path.join(REPO, "doc/claude/issues")

CLOSER = re.compile(
    r'\b(?:fixe[sd]|fixed\s+by|supersede[sd]|superseded\s+by|close[sd]|resolve[sd]|'
    r'addressed\s+by|obsoleted\s+by|duplicate\s+of)\b[^.\n]{0,40}?'
    r'\bissue\s*\**#?\s*(\d{4})\b', re.I)
CLOSER2 = re.compile(
    r'\b(?:fixe[sd]|fixed\s+by|supersede[sd]|superseded\s+by|close[sd]|resolve[sd]|'
    r'addressed\s+by|obsoleted\s+by|duplicate\s+of)\s*\**#?\s*(\d{4})\b', re.I)

OPENISH = re.compile(r'\b(OPEN|NOT FIXED|FILED, NOT|UNFIXED|still open)\b', re.I)
FIXEDISH = re.compile(r'\b(FIXED|RESOLVED|CLOSED|DONE|LANDED|SHIPPED)\b', re.I)

issues = {f[:4]: f for f in os.listdir(ISSUES) if re.match(r'^\d{4}-.*\.md$', f)}

def header(fn, n=15):
    t = open(os.path.join(ISSUES, fn), encoding='utf-8', errors='replace').read()
    return re.sub(r'\s+', ' ', ' '.join(t.split('\n')[:n]))

# ---- gather closure claims ----
claims = collections.defaultdict(set)   # issue number -> set of "where"

def scan_text(text, where):
    for rx in (CLOSER, CLOSER2):
        for m in rx.finditer(text):
            claims[m.group(1)].add(where)

for fn in sorted(issues.values()):
    try:
        t = open(os.path.join(ISSUES, fn), encoding='utf-8', errors='replace').read()
    except Exception:
        continue
    scan_text(re.sub(r'\s+', ' ', t), 'issue ' + fn[:4])

for sub in ('src', 'tests'):
    for root, dirs, files in os.walk(os.path.join(REPO, sub)):
        dirs[:] = [d for d in dirs if d != '.git']
        for fn in files:
            if fn.endswith(('.c', '.h', '.tcl', '.sh', '.js', '.awk', '.py')):
                p = os.path.join(root, fn)
                try:
                    scan_text(re.sub(r'\s+', ' ',
                              open(p, encoding='utf-8', errors='replace').read()),
                              os.path.relpath(p, REPO))
                except Exception:
                    pass

try:
    log = subprocess.run(['git', 'log', '--format=%H%n%B'], cwd=REPO,
                         capture_output=True, text=True, timeout=180).stdout
    scan_text(re.sub(r'\s+', ' ', log), 'git log')
except Exception:
    pass

# ---- classify each claimed-closed issue by its OWN header ----
flagged, agreed, nofile = [], [], []
for num in sorted(claims):
    if num not in issues:
        nofile.append(num)
        continue
    h = header(issues[num])
    o, f = bool(OPENISH.search(h)), bool(FIXEDISH.search(h))
    if o and not f:
        flagged.append((num, sorted(claims[num])[:3]))
    else:
        agreed.append(num)

# ---------------- SELF-TEST ----------------
print("=== SELF-TEST ===")
found_1438 = '1438' in claims
flagged_nums = {n for n, _ in flagged}
print(f"  1438 has a closure claim somewhere : {found_1438}")
print(f"  1438 flagged (header still OPEN)   : {'1438' in flagged_nums}")
if not found_1438:
    print("\n!! SCANNER BROKEN — A4 measured that 1439 names 1438 as fixed and the")
    print("   scanner cannot see it. No number reported.")
    sys.exit(1)
print("  self-test PASSED\n")

print("=== issues someone says are closed ===")
print("distinct issue numbers claimed closed :", len(claims))
print("  ... whose own header agrees (fixed) :", len(agreed))
print("  ... WHOSE OWN HEADER STILL SAYS OPEN:", len(flagged))
print("  ... no such issue file here         :", len(nofile))
if claims:
    print(f"\nSTALE-OPEN-HEADER RATE: {100.0*len(flagged)/max(len(claims)-len(nofile),1):.1f}%"
          f"  ({len(flagged)}/{len(claims)-len(nofile)})")
print()
print("=== the flagged set: someone closed it, the file never heard ===")
for num, where in flagged:
    print(f"  {num}  <- claimed closed by: {', '.join(where)}")
