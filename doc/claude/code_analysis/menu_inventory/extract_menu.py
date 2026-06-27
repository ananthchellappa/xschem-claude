#!/usr/bin/env python3
"""
Extract every Tk menu item from xschem.tcl into a draft action table.

Menu items are multi-line Tcl statements:
    $topwin.menubar.file add command -label "Clear Schematic" -accelerator Ctrl+N \
        -command { xschem clear schematic }
so a brace/bracket/quote-aware scanner is needed, not grep. For each item we
capture: menu path, item type, label, accelerator, -variable (toggles), and the
-command body (flattened). Output: menu_items.csv and menu_items.md.
"""
import re, sys, csv, os

SRC = sys.argv[1] if len(sys.argv) > 1 else "xschem.tcl"
OUT = sys.argv[2] if len(sys.argv) > 2 else "."
text = open(SRC, encoding='utf-8', errors='replace').read()

START = re.compile(r'(\$?[\w.]*\.menubar[\w.]*)\s+add\s+'
                   r'(command|checkbutton|radiobutton|cascade)\b')

def scan_statement(s, i):
    """From index i (just after the 'add <type>' keyword), return (stmt_text,
    end_index). A statement ends at a newline at depth 0 not continued by '\\'."""
    depth_b = depth_k = 0      # {}  []
    in_dq = False
    j = i
    n = len(s)
    while j < n:
        c = s[j]
        if in_dq:
            if c == '\\': j += 2; continue
            if c == '"': in_dq = False
            j += 1; continue
        if c == '\\' and j+1 < n and s[j+1] == '\n':
            j += 2; continue            # line continuation
        if c == '"': in_dq = True; j += 1; continue
        if c == '{': depth_b += 1; j += 1; continue
        if c == '}': depth_b -= 1; j += 1; continue
        if c == '[': depth_k += 1; j += 1; continue
        if c == ']': depth_k -= 1; j += 1; continue
        if c == '\n' and depth_b <= 0 and depth_k <= 0:
            return s[i:j], j
        j += 1
    return s[i:j], j

def get_opt(stmt, opt):
    """Return the value of -opt: a {brace}, "quoted", or bareword token."""
    m = re.search(r'-'+opt+r'\s+', stmt)
    if not m:
        return ''
    k = m.end()
    if k >= len(stmt):
        return ''
    c = stmt[k]
    if c == '{':
        d = 0; e = k
        while e < len(stmt):
            if stmt[e] == '{': d += 1
            elif stmt[e] == '}':
                d -= 1
                if d == 0: break
            e += 1
        return stmt[k+1:e]
    if c == '"':
        e = k+1
        while e < len(stmt):
            if stmt[e] == '\\': e += 2; continue
            if stmt[e] == '"': break
            e += 1
        return stmt[k+1:e]
    m2 = re.match(r'(\S+)', stmt[k:])
    return m2.group(1).rstrip('\\') if m2 else ''   # drop trailing line-continuation

def flatten(s):
    return re.sub(r'\s+', ' ', s.replace('\\\n', ' ')).strip()

items = []
for m in START.finditer(text):
    path, typ = m.group(1), m.group(2)
    stmt, _ = scan_statement(text, m.end())
    line = text.count('\n', 0, m.start()) + 1
    menu = path.split('.menubar')[-1].lstrip('.') or '(top)'
    label = flatten(get_opt(stmt, 'label'))
    accel = flatten(get_opt(stmt, 'accelerator'))
    var   = flatten(get_opt(stmt, 'variable'))
    cmd   = flatten(get_opt(stmt, 'command'))
    items.append(dict(line=line, menu=menu, type=typ, label=label,
                      accel=accel, var=var, command=cmd))

# stable order: by menu, then by source line
items.sort(key=lambda r: (r['menu'], r['line']))

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, 'menu_items.csv'), 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=['menu','type','label','accel','var','command','line'])
    w.writeheader()
    for r in items:
        w.writerow({k: r[k] for k in w.fieldnames})

# markdown grouped by menu
from collections import Counter, defaultdict
bymenu = defaultdict(list)
for r in items: bymenu[r['menu']].append(r)
with open(os.path.join(OUT, 'menu_items.md'), 'w') as fh:
    fh.write("# xschem menu inventory (draft action table)\n\n")
    fh.write("Auto-extracted from `src/xschem.tcl` by `extract_menu.py`. "
             "%d items across %d menus.\n\n" % (len(items), len(bymenu)))
    counts = Counter(r['type'] for r in items)
    fh.write("Types: " + ", ".join(f"{k}={v}" for k,v in counts.most_common()) + "\n\n")
    n_accel = sum(1 for r in items if r['accel'])
    n_toggle = sum(1 for r in items if r['type'] in ('checkbutton','radiobutton'))
    fh.write(f"Items with an accelerator label: {n_accel}/{len(items)}. "
             f"Toggle items (check/radio, -variable bound): {n_toggle}.\n\n")
    for menu in sorted(bymenu):
        rows = bymenu[menu]
        fh.write(f"## `{menu}`  ({len(rows)} items)\n\n")
        fh.write("| label | type | accel | variable | command | line |\n")
        fh.write("|---|---|---|---|---|---|\n")
        for r in rows:
            cmd = r['command']
            if len(cmd) > 70: cmd = cmd[:67] + '...'
            cmd = cmd.replace('|', '\\|')
            lbl = (r['label'] or ('— '+r['type'])).replace('|','\\|')
            fh.write(f"| {lbl} | {r['type']} | {r['accel']} | {r['var']} | "
                     f"`{cmd}` | {r['line']} |\n")
        fh.write("\n")

print("items:", len(items))
print("by type:", dict(Counter(r['type'] for r in items)))
print("menus:", len(bymenu))
print("with accelerator:", n_accel, "| toggles:", n_toggle)
