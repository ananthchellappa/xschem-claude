#!/usr/bin/env python3
"""How many issue files state the TREE STATE their claims were measured against?

⚠ THIS SCANNER SELF-TESTS BEFORE IT REPORTS. Four driver measurements tonight
returned plausible numbers from commands that were not doing what was meant:
  - grep -lieE swallowed its pattern as -e "E" and matched all 1050 files
  - a repo-only resolver scored ngspice and glibc citations as rot
  - a "nearest filename" heuristic scored SPICE decks as rotted quotes
  - a LINE-oriented grep missed "measured in\\nthe tree at" because markdown
    HARD-WRAPS the phrase, and \\` inside single quotes became backslash-backtick
So: known-positive cases are asserted first. If 1477/1478/1479/1473 are not all
detected as stamped, this script aborts instead of printing a number.
"""
import os, re, subprocess, sys, collections

REPO = "/home/analog/dev/xschem-claude"
ISSUES = os.path.join(REPO, "doc/claude/issues")

# a SHA-ish token: 7-40 hex chars that contain at least one a-f letter.
# the letter requirement is what keeps 16091816 (MemTotal kB) and 141592654 (pi) out.
SHAISH = re.compile(r'\b(?=[0-9a-f]*[a-f])([0-9a-f]{7,40})\b')
BACKTICKED_SHA = re.compile(r'`(?=[0-9a-f]*[a-f])([0-9a-f]{7,40})`')

STAMP = re.compile(
    r'(measured|filed|found|confirmed|read|taken|verified|recorded|as of)'
    r'[^.]{0,60}?\b(?:in|at|against|on)\s+(?:the\s+)?(?:tree\s+)?(?:at\s+)?'
    r'`?(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}`?', re.I)

def header_of(text, nlines=15):
    """First nlines of real content, whitespace-normalised so a hard-wrapped
    phrase reads as one string."""
    out = []
    for ln in text.split('\n'):
        out.append(ln)
        if len(out) >= nlines:
            break
    return re.sub(r'\s+', ' ', ' '.join(out))

issues = sorted(f for f in os.listdir(ISSUES) if re.match(r'^\d{4}-.*\.md$', f))
byname = {f[:4]: f for f in issues}

stamped_hdr, stamped_any, sha_in_hdr = set(), set(), set()
all_shas = collections.Counter()

for f in issues:
    try:
        text = open(os.path.join(ISSUES, f), encoding='utf-8', errors='replace').read()
    except Exception:
        continue
    flat_hdr = header_of(text)
    flat_all = re.sub(r'\s+', ' ', text)
    if STAMP.search(flat_hdr):
        stamped_hdr.add(f[:4])
    if STAMP.search(flat_all):
        stamped_any.add(f[:4])
    if BACKTICKED_SHA.search(flat_hdr):
        sha_in_hdr.add(f[:4])
    for s in BACKTICKED_SHA.findall(flat_all):
        all_shas[s] += 1

# ---------------- SELF-TEST ----------------
KNOWN_POSITIVE = ['1477', '1478', '1479', '1473']
missed = [k for k in KNOWN_POSITIVE if k not in stamped_hdr]
print("=== SELF-TEST ===")
for k in KNOWN_POSITIVE:
    print(f"  {k}: header-stamp detected = {k in stamped_hdr}")
if missed:
    print(f"\n!! SCANNER BROKEN — missed known-positive {missed}. No number reported.")
    sys.exit(1)
print("  self-test PASSED\n")

print("=== tree-state stamps ===")
print("issue files                                :", len(issues))
print("state a tree/commit in their HEADER (15 ln):", len(stamped_hdr),
      f"({100.0*len(stamped_hdr)/len(issues):.1f}%)")
print("state one ANYWHERE in the file             :", len(stamped_any),
      f"({100.0*len(stamped_any)/len(issues):.1f}%)")
print("carry any backticked SHA in the header     :", len(sha_in_hdr))
print()
print("the header-stamped set:", ' '.join(sorted(stamped_hdr)))
print()

# ---------------- SHA resolution ----------------
print("=== do backticked SHAs cited in issues resolve to a commit? ===")
print("distinct backticked SHA-ish tokens:", len(all_shas))
ok, bad = [], []
for s in all_shas:
    r = subprocess.run(['git', 'cat-file', '-e', s + '^{commit}'],
                       cwd=REPO, capture_output=True)
    (ok if r.returncode == 0 else bad).append(s)
print("resolve to a commit in this repo  :", len(ok))
print("do NOT resolve                    :", len(bad),
      f"({100.0*len(bad)/max(len(all_shas),1):.1f}%)")
print()
print("sample non-resolving, with how often cited:")
for s in sorted(bad, key=lambda x: -all_shas[x])[:20]:
    print(f"  {s}  cited {all_shas[s]}x")
