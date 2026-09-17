#!/usr/bin/env python3
"""Closure-claim detector, v2 -- with the three filters D0 measured, and a
self-test that asserts BOTH directions.

WHY v2 EXISTS. v1 (closescan.py) reported "165 claimed closed, 7 with an OPEN
header, 4.3%". D0 verified those 7 against the tree: FOUR WERE FALSE POSITIVES,
and acting on the table would have marked two genuinely open defects closed, one
of them carrying a live user ruling. Three blind spots, all found by printing the
MATCHED TEXT instead of the location:

  NEGATION      "FILED, not closed: issue 0516"  -- v1 allows a 40-char gap
                between verb and number, and the negation sits inside it.
  ATTRIBUTION   "**Status:** CLOSED (issue 0071 atom 6)" closes 0003; 0071 is
                being CREDITED as the fixer, not closed.
  PRESCRIPTION  "...and fixes 0947 at the same time" is an UNIMPLEMENTED option.
                A proposal is not an event.

AND THE METHOD LESSON, which is why this file exists rather than a patch:
v1's self-test asserted only a TRUE POSITIVE (1438 is flagged). A test that only
proves a check FIRES can never prove it does not OVER-fire. This one asserts a
known positive AND four known negatives, from D0's verified verdicts.
"""
import os, re, subprocess, sys, collections

REPO = "/home/analog/dev/xschem-claude"
ISSUES = os.path.join(REPO, "doc/claude/issues")

VERB = r'(?:fixe[sd]|fixed\s+by|supersede[sd]|superseded\s+by|close[sd]|resolve[sd]|addressed\s+by|obsoleted\s+by)'
CLAIM = re.compile(VERB + r'\b[^.\n]{0,40}?\b(?:issue\s*)?\*{0,2}#?(\d{4})\b', re.I)

# --- the three filters, applied to a window around each match ---
NEG = re.compile(r'\b(?:not|never|un)\s*(?:yet\s+)?(?=\w*(?:fix|clos|resolv|land|impl))|'
                 r'\bNOT\s+(?:FIXED|CLOSED|RESOLVED|LANDED|DONE)\b|'
                 r'\bFILED,\s*not\b|\bfiled,\s*not\b', re.I)
ATTRIB = re.compile(r'\(\s*(?:issue\s*)?\d{4}\b[^)]{0,40}\)')        # "(issue 0071 atom 6)"
PRESCRIBE = re.compile(r'\b(?:would|should|could|plan|planned|propos\w+|option|plan\s+to|'
                       r'plans?\s+to|plan:|candidate|if\s+taken|when\s+taken|at\s+the\s+same\s+time|'
                       r'plan\s+is|intend\w*|plan\b)\b', re.I)

# --- BLEED, the shape neither v1 nor the first v2 anticipated ---
# The verb belongs to a DIFFERENT issue number, and the 40-char gap merely scooped
# up the next number along. Two real examples, both of which kept a false positive
# alive after the other three filters were in place:
#   "issue 0055 (locate arg, FIXED); umbrella 0071"      -- the verb is 0055's
#   "docs(issues): 0244 FIXED write-up, and file 0264"   -- the verb is 0244's
# BLEED_SEP: a claim cannot survive a ';' or ')' between its verb and its number.
# BLEED_OWNER: a 4-digit number immediately BEFORE the verb owns that verb.
BLEED_SEP = re.compile(r'[;)→]')
BLEED_OWNER = re.compile(r'\b\d{4}\b[^0-9]{0,15}$')

OPENISH = re.compile(r'\b(OPEN|NOT FIXED|FILED, NOT|UNFIXED|still open)\b', re.I)
FIXEDISH = re.compile(r'\b(FIXED|RESOLVED|CLOSED|DONE|LANDED|SHIPPED)\b', re.I)

issues = {f[:4]: f for f in os.listdir(ISSUES) if re.match(r'^\d{4}-.*\.md$', f)}

def header(fn, n=15):
    t = open(os.path.join(ISSUES, fn), encoding='utf-8', errors='replace').read()
    return re.sub(r'\s+', ' ', ' '.join(t.split('\n')[:n]))

claims = collections.defaultdict(set)
rejected = collections.Counter()

def scan(text, where):
    for m in CLAIM.finditer(text):
        num = m.group(1)
        a, b = max(0, m.start() - 90), min(len(text), m.end() + 50)
        win = text[a:b]
        if NEG.search(win):
            rejected['negation'] += 1;      continue
        if ATTRIB.search(text[m.start():min(len(text), m.end() + 30)]):
            rejected['attribution'] += 1;   continue
        if PRESCRIBE.search(win):
            rejected['prescription'] += 1;  continue
        # the text between the end of the verb and the start of the number
        vm = re.match(VERB, m.group(0), re.I)
        gap = m.group(0)[vm.end():] if vm else ''
        if BLEED_SEP.search(gap):
            rejected['bleed-separator'] += 1;  continue
        if BLEED_OWNER.search(text[max(0, m.start() - 20):m.start()]):
            rejected['bleed-owner'] += 1;      continue
        claims[num].add(where)

for fn in sorted(issues.values()):
    try:
        t = open(os.path.join(ISSUES, fn), encoding='utf-8', errors='replace').read()
    except Exception:
        continue
    scan(re.sub(r'\s+', ' ', t), 'issue ' + fn[:4])

for sub in ('src', 'tests'):
    for root, dirs, files in os.walk(os.path.join(REPO, sub)):
        dirs[:] = [d for d in dirs if d != '.git']
        for fn in files:
            if fn.endswith(('.c', '.h', '.tcl', '.sh', '.js', '.awk', '.py')):
                p = os.path.join(root, fn)
                try:
                    scan(re.sub(r'\s+', ' ', open(p, encoding='utf-8', errors='replace').read()),
                         os.path.relpath(p, REPO))
                except Exception:
                    pass
try:
    log = subprocess.run(['git', 'log', '--format=%H%n%B'], cwd=REPO,
                         capture_output=True, text=True, timeout=180).stdout
    scan(re.sub(r'\s+', ' ', log), 'git log')
except Exception:
    pass

flagged, agreed, nofile = [], [], []
for num in sorted(claims):
    if num not in issues:
        nofile.append(num);  continue
    h = header(issues[num])
    if OPENISH.search(h) and not FIXEDISH.search(h):
        flagged.append((num, sorted(claims[num])[:3]))
    else:
        agreed.append(num)

flagged_nums = {n for n, _ in flagged}

# ---------------- SELF-TEST, BOTH DIRECTIONS (D0's verified verdicts) ----------
POSITIVE = ['0249']                                  # genuinely closed, header stale
NEGATIVE = ['0071', '0264', '0516', '0947']          # genuinely OPEN -- must NOT flag
print("=== SELF-TEST (both directions) ===")
ok = True
for n in POSITIVE:
    hit = n in flagged_nums
    print(f"  must flag     {n}: {hit}")
    ok &= hit
for n in NEGATIVE:
    hit = n in flagged_nums
    print(f"  must NOT flag {n}: {not hit}")
    ok &= not hit
if not ok:
    print("\n!! SELF-TEST FAILED -- no number reported.")
    print("   v1 failed exactly here and reported 4.3% anyway, because it only")
    print("   ever asserted a true positive.")
    sys.exit(1)
print("  self-test PASSED (positive AND negative)\n")

print("=== closure claims, filtered ===")
print("rejected by filter:", dict(rejected))
print("distinct issue numbers genuinely claimed closed :", len(claims))
print("  ... header agrees                             :", len(agreed))
print("  ... HEADER STILL SAYS OPEN                    :", len(flagged))
print("  ... no issue file                             :", len(nofile))
den = len(claims) - len(nofile)
if den > 0:
    print(f"\nSTALE-OPEN-HEADER RATE: {100.0*len(flagged)/den:.1f}%  ({len(flagged)}/{den})")
print()
for num, where in flagged:
    print(f"  {num}  <- {', '.join(where)}")
