#!/usr/bin/env python3
"""
One-shot, behavior-preserving extraction of the utility layer out of
src/editprop.c into src/util.c. Pure move: function bodies copied verbatim,
no logic or signature changes. my_snprintf is special-cased because its two
variants sit inside one #ifdef HAS_SNPRINTF/#else/#endif block that must move
as a unit.

Outputs to OUT/: util.c and editprop.c.new  (reviewed, then copied into src/).
Reports which names moved so the set can be sanity-checked before building.
"""
import re, sys

SRC = sys.argv[1]
OUT = sys.argv[2]

UTIL = {
 "dbg","dtoa","my_atod","my_atof","my_calloc","my_expand","my_fgets",
 "my_fgets_skip","my_fopen","my_free","my_itoa","my_malloc","my_mstrcat",
 "my_realloc","my_snprintf","my_strcasecmp","my_strcasestr","my_strcat",
 "my_strcat2","my_strdup","my_strdup2","my_strncasecmp","my_strncat",
 "my_strncpy","my_strndup","my_strtok_r","str_replace","strboolcmp",
 "strtolower","strtoupper",
}
KEYWORDS = {"if","for","while","switch","do","return","sizeof","else"}

text = open(SRC, encoding="utf-8", errors="replace").read()
lines = text.splitlines(keepends=True)
n = len(text)

HEADER = re.compile(r'(?m)^([A-Za-z_]\w[\w \t\*]*?)\b([A-Za-z_]\w*)[ \t]*\(')

def match_brace(s, i):
    d = 0
    while i < len(s):
        if s[i] == '{': d += 1
        elif s[i] == '}':
            d -= 1
            if d == 0: return i
        i += 1
    return -1

# locate every top-level function definition (name, char span of body)
funcs = []
for m in HEADER.finditer(text):
    name = m.group(2)
    if name in KEYWORDS: continue
    p = text.find('(', m.end()-1)
    if p < 0: continue
    # match the param paren
    d=0; q=p
    while q < n:
        if text[q]=='(':d+=1
        elif text[q]==')':
            d-=1
            if d==0: break
        q+=1
    j = q+1
    # skip whitespace AND comments between ')' and the body '{'
    while j < n:
        if text[j] in ' \t\r\n': j += 1
        elif text[j:j+2] == '/*':
            e = text.find('*/', j+2); j = (e+2) if e>=0 else n
        elif text[j:j+2] == '//':
            e = text.find('\n', j+2); j = (e+1) if e>=0 else n
        else: break
    if j>=n or text[j] != '{': continue
    end = match_brace(text, j)
    if end < 0: continue
    funcs.append([name, m.start(), end])

# turn char offsets into line numbers (0-based)
def lineno(off): return text.count('\n', 0, off)

# build the set of (start_line, end_line) ranges to MOVE
move_ranges = []   # (start_line, end_line_inclusive, label)
moved_names = []
seen_snprintf = False
for name, sstart, bend in funcs:
    if name not in UTIL: continue
    sline = lineno(sstart)
    eline = lineno(bend)
    if name == "my_snprintf":
        if seen_snprintf:
            continue  # second variant already covered by the #ifdef block
        seen_snprintf = True
        # extend up to the enclosing #ifdef and down to its #endif
        u = sline
        while u > 0 and not re.match(r'\s*#\s*if', lines[u]):
            u -= 1
        d = eline
        while d < len(lines) and not re.match(r'\s*#\s*endif', lines[d]):
            d += 1
        sline, eline = u, d
    # attach an immediately-preceding comment block (no blank gap)
    u = sline - 1
    if u >= 0 and lines[u].strip().endswith('*/'):
        while u > 0 and not lines[u].lstrip().startswith('/*'):
            u -= 1
        sline = u
    move_ranges.append((sline, eline, name))
    moved_names.append(name)

move_ranges.sort()
# sanity: no overlaps
for a,b in zip(move_ranges, move_ranges[1:]):
    assert a[1] < b[0], f"overlap {a} {b}"

move_lineset = set()
for s,e,_ in move_ranges:
    move_lineset.update(range(s, e+1))

# header comment block (lines 0..21) + includes stay in editprop.c; util.c gets
# its own header.
moved_text = []
for s,e,_ in move_ranges:
    moved_text.append(''.join(lines[s:e+1]))

UTIL_HEADER = '''/* File: util.c
 *
 * This file is part of XSCHEM,
 * a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
 * simulation.
 * Copyright (C) 1998-2024 Stefan Frederik Schippers
 *
 * General-purpose memory / string / file / debug utilities, extracted
 * verbatim from editprop.c (behavior-preserving move; no logic changes).
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include <stdarg.h>
#include "xschem.h"

'''

with open(OUT + "/util.c", "w") as fh:
    fh.write(UTIL_HEADER)
    fh.write('\n'.join(t.rstrip('\n') for t in moved_text))
    fh.write('\n')

# new editprop.c = all lines NOT moved
with open(OUT + "/editprop.c.new", "w") as fh:
    out = [ln for i, ln in enumerate(lines) if i not in move_lineset]
    fh.write(''.join(out))

print("moved", len(moved_names), "definitions:")
print(" ", " ".join(sorted(moved_names)))
print("missing from file:", sorted(UTIL - set(moved_names)))
print("util.c lines:", UTIL_HEADER.count(chr(10)) + sum(t.count(chr(10)) for t in moved_text))
