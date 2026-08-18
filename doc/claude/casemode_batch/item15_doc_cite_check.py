#!/usr/bin/env python3
"""Derive the citations FROM the doc and check them against the tree.

Every `src/<file>:<line>` in the item-15 site map -- including the slash-chained
forms (`src/f.tcl:10/20/30`) and the bare `` `:<line>` `` continuations that
follow a file in the same table cell -- must (a) exist, and (b) have, within
+/-WINDOW lines of the cited line, one of the backticked identifiers named in
the same table ROW (or, failing that, one of the row's backticked literals
verbatim on the cited line itself).  Corrupt a line number in the doc and this
goes red -- which is the point: the explicit table in cite_check.py asserts the
TREE, this one asserts the DOC.

WINDOW is 4, the value the docstring has always advertised, and the failure
message prints the same number.  Identifiers are scoped to the ROW because this
table puts the `file:line` in column 2 and the prose naming the symbol in
column 3; scoping them per-CELL is what made +/-4 unreachable and invited a
loose window instead.

A COUNTING ASSERTION guards the parser itself: the citation regexes are
re-derived independently over the raw table text and the two totals must agree,
so a citation this parser cannot see becomes a FAIL rather than a silent skip.
That is the defect the fix round found -- `.search` took only the FIRST
`src/f:N` per cell, and the closing-backtick anchor threw away every
slash-chained cell whole, so 29 of the table's 42 citations were checked and the
other 13 were skipped in silence behind a green `ALL PASS`."""
import io,re,sys,os
ROOT="/home/qflow/dev/xschem/claude_1/xschem"
WINDOW=4
DOC=os.path.join(ROOT,"doc/claude/code_analysis/ngspice_case_sensitivity.md")
txt=io.open(DOC,encoding='utf-8').read()
start=txt.index("### 3.3 The shipped site map")
end=txt.index("### 3.4 ")
table=txt[start:end]

# a citation: src/<path>:<line>, optionally slash-chained with more line numbers
cite_re=re.compile(r"(src/[A-Za-z0-9_./]+):(\d+)((?:/\d+)*)")
# a continuation: `:<line>` -- backtick then colon, so it can never be the tail
# of a src/f:N (that has the path between the backtick and the colon)
cont_re=re.compile(r"`:(\d+)`")
# an identifier the cell names, Tcl `ns::proc` included
ident_re=re.compile(r"`([A-Za-z_][A-Za-z0-9_]*(?:(?:::|\.)[A-Za-z0-9_]+)*)\(?\)?`")
# every backticked literal, matched VERBATIM against the cited line only.
# The citation itself (`src/f.c:12`, `:12`) is not a literal about the code.
lit_re=re.compile(r"`([^`]+)`")
notlit_re=re.compile(r"^(?:src/[A-Za-z0-9_./]+)?:\d+(?:/\d+)*$")

# ---- independent count of what the table contains, for the parser guard ----
want=0
for m in cite_re.finditer(table):
    want+=1+len(re.findall(r"\d+",m.group(3)))
want+=len(cont_re.findall(table))

cache={}
def lines_of(f):
    if f not in cache:
        cache[f]=io.open(os.path.join(ROOT,f),encoding='utf-8',
                         errors='replace').read().split("\n")
    return cache[f]

bad=n=0
for row in table.split("\n"):
    if not row.startswith("|"): continue
    # identifiers are scoped to the ROW, not the cell: this table puts the
    # `file:line` in column 2 and the prose that names the symbol in column 3
    # >=4 chars: a one-letter `v` from a `v()` in the prose anchors nothing,
    # and matched a 10-line drift during the fix round's S4 sabotage
    idents=[i for i in ident_re.findall(row) if len(i)>=4]
    lits=[t.strip() for t in lit_re.findall(row)
          if len(t.strip())>=6 and not notlit_re.match(t.strip())]
    for cell in row.split("|"):
        refs=[]            # (file, line)
        last=None
        # walk the cell left to right so a `:N` continuation binds to the file
        # that most recently preceded it
        for tok in re.finditer(r"(src/[A-Za-z0-9_./]+):(\d+)((?:/\d+)*)|`:(\d+)`",cell):
            if tok.group(1):
                last=tok.group(1)
                refs.append((last,int(tok.group(2))))
                for extra in re.findall(r"\d+",tok.group(3) or ""):
                    refs.append((last,int(extra)))
            elif last:
                refs.append((last,int(tok.group(4))))
            else:
                bad+=1
                print("FAIL: continuation `:%s` with no file before it in the cell"
                      %tok.group(4))
        for f,ln in refs:
            n+=1
            L=lines_of(f)
            if ln<1 or ln>len(L):
                bad+=1; print("FAIL: %s:%d past EOF"%(f,ln)); continue
            window="\n".join(L[max(0,ln-1-WINDOW):ln+WINDOW])
            probes=[]
            for i in idents:
                probes.append(i)
                tail=re.split(r"::|\.",i)[-1]
                if len(tail)>=6: probes.append(tail)
            hit=[i for i in probes if i in window]
            if not hit:
                hit=[t for t in lits if t in L[ln-1]]
            if hit:
                print("ok:   %s:%d  <- %s"%(f,ln,hit[0]))
            elif not idents and not lits:
                if L[ln-1].strip()=="":
                    bad+=1
                    print("FAIL: %s:%d is a blank line and the cell names nothing"%(f,ln))
                else:
                    print("ok:   %s:%d non-blank (no identifier to match)"%(f,ln))
            else:
                bad+=1
                print("FAIL: %s:%d  none of %s within +/-%d lines, and no cell "
                      "literal on the line itself\n        line: %s"
                      %(f,ln,idents,WINDOW,L[ln-1].strip()[:90]))

if n!=want:
    bad+=1
    print("FAIL: parser saw %d citations but the table text contains %d -- "
          "%d were silently skipped"%(n,want,want-n))
else:
    print("ok:   parser guard: %d citations parsed, %d present in the table"%(n,want))
print("RESULT: %s (%d doc-derived citations)"
      %("ALL PASS" if not bad else "%d FAILED"%bad,n))
sys.exit(1 if bad else 0)
