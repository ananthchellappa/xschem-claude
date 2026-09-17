#!/usr/bin/env python3
"""Does the tracker name code that no longer exists?

A SOUND check, unlike quotescan.py's heuristic. An issue that writes `foo()` in
backticks is naming a function. If that identifier appears NOWHERE in any source
file in the repo, the issue is describing code the tree does not have -- either it
was renamed, removed, or never existed. Near-zero false positives, because the test
is existence anywhere, not position.

This is the Stage C prototype: it is the strongest rot signal that can be computed
WITHOUT trusting a line number, which quotescan.py proved is not computable
retrospectively from free prose.
"""
import os, re, collections

REPO = "/home/analog/dev/xschem-claude"
ISSUES = os.path.join(REPO, "doc/claude/issues")
SRC_EXT = ('.c', '.h', '.tcl', '.sh', '.js', '.y', '.l', '.awk', '.py', '.in')

# ---- build the identifier universe from every source file in the tree ----
TOKEN = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
universe = set()
nsrc = 0
for root, dirs, files in os.walk(REPO):
    dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules')]
    for fn in files:
        if fn.endswith(SRC_EXT):
            nsrc += 1
            try:
                with open(os.path.join(root, fn), encoding='utf-8', errors='replace') as fh:
                    universe.update(TOKEN.findall(fh.read()))
            except Exception:
                pass

# ---- collect backticked function-call identifiers from each issue ----
CALL = re.compile(r'`([A-Za-z_][A-Za-z0-9_]{3,})\(\)`')

issues = sorted(f for f in os.listdir(ISSUES) if re.match(r'^\d{4}-.*\.md$', f))
tot = 0
absent = []
per_issue = collections.Counter()
seen_absent = collections.Counter()
files_with_syms = 0

for fn in issues:
    try:
        text = open(os.path.join(ISSUES, fn), encoding='utf-8', errors='replace').read()
    except Exception:
        continue
    syms = set(CALL.findall(text))
    if syms:
        files_with_syms += 1
    for s in syms:
        tot += 1
        if s not in universe:
            absent.append((fn, s))
            per_issue[fn] += 1
            seen_absent[s] += 1

print("=== symbol-existence check ===")
print("source files tokenised          :", nsrc)
print("distinct identifiers in the tree:", len(universe))
print("issue files scanned             :", len(issues))
print("issue files naming a `foo()`    :", files_with_syms)
print("distinct (issue, symbol) pairs  :", tot)
print("... naming a symbol ABSENT from the whole tree :", len(absent))
if tot:
    print(f"\nABSENT-SYMBOL RATE: {100.0*len(absent)/tot:.1f}%  ({len(absent)}/{tot})")
print("issue files carrying >=1 absent symbol :", len(per_issue))
print()
print("=== most-cited absent symbols (top 25) ===")
for s, c in seen_absent.most_common(25):
    print(f"{c:4d}  {s}()")
print()
print("=== worst 15 issue files ===")
for fn, c in per_issue.most_common(15):
    print(f"{c:4d}  {fn}")
