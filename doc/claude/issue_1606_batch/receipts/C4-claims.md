# Receipt C4 — make every claim true

Stage C4. I changed **nothing in the product except one comment** (`src/editprop.c`'s "rows K3
and Y1", finding (h), which the task authorises as a comment-only edit). Everything else is the
suite file `tests/headless/test_ev_precision_bound_1606.tcl`, the `hcases` rationale comment in
`tests/run_regression.tcl`, and this receipt. I did **not** commit, did **not** touch
`~/.claude/xschem_owed/`, did **not** open `~/dev/xschem-op-wcard`, and never ran
`devdisplay.sh start|stop|view` — `xvfb: 3979908` before and after every cycle.

**75 build/suite cycles**, every one: apply ONE edit, `make -C src`, armed nogui run, restore by
content copy (`shutil.copyfile` + `os.utime(..., None)` so the mtime is FRESH and `make` cannot
skip the file — never `cp -a`), rebuild, re-run. `restored_green` was true in **75 of 75**.
Two cycles had a **build error I caused** (`Q_cur`, `Q_snm`, §5) and nothing was measured on those;
one batch aborted before applying an edit, on a stale anchor, and changed nothing. Every quoted
figure comes from a run whose binary was built from the tree that produced it.

---

## 0. HEADLINE

1. **M1, M2 and M6 are closed at the CLASS level, by normalisation, not by new spellings.**
   `cs_norm` removes whitespace adjacent to `= ( ) ,` and `->` from the haystack **and** the
   needle, so those spellings collapse to one canonical form; and `W4` no longer asks whether one
   string appears — it asks, of every WRITE to `xctx->ev_precision`, whether the value written is a
   `clamp_prec_g` call. All three decoys now redden, verbatim in §2.
2. **`Y1a`/`Y1b` have an anti-vacuity row, `Y1c`**, and it reddens with `-w` prepended to CFLAGS
   **and** with `-w` appended after an explicit `-Wformat-overflow=2` (§3).
3. **All eight false or loose statements are corrected** (§4), including the two ROW NAMES. X1's
   name had to be NARROWED as well as widened: after normalisation it is still blind to
   `show_node_measures`, whose format is a `char *` variable, so the name is now scoped to
   statements whose own format LITERAL carries the `%.*`.
4. **The `if(0)` limit is one site wide and the site is named**: re-driven at one site per class,
   `show_node_measures` is the only one that stays green (§5).
5. **All 24 product guards still redden on their own single removal** on the new suite (§6), and
   every decoy from all four rounds is dead (§7). No existing row was made vacuous.
6. ⚠ **Two things the task did not anticipate, both of which I did and both of which are
   measurements, not opinions** (§9): `sprintf_stmts` and `w4_verdict`/`w4c_wrapped` are rules
   feeding NEGATIVE rows, so weakening them cannot be caught by sabotaging the tree — measured, the
   suite stayed at `ALL PASS`. They therefore get unit rows (`X1e`, `W4d`) on the X1d precedent.
   With `Z0c` and `Y1c` that is **five** new rows, not the one the task scoped, and the FLOOR moves
   **58/53 → 63/58**.

---
## 1. T1 — what the normalisation actually is, and why it is safe

**The mechanism.** `cs_ws` is the old whitespace-run collapse. `cs_norm` then deletes every space
that is adjacent to `=`, `(`, `)`, `,` or to the two-character token `->`. `cs_collapse` is the two
in sequence and is what every haystack in the file goes through; `nrm` puts every NEEDLE through
the identical mill, and `cfind`/`ccount` call it, so each row stays written in ordinary C spelling
while matching a shape. Tcl's regexp here has **no lookbehind** (`(?<=…)` is a compile error on
8.6.17 in this tree — measured), so the pattern is

    ((?:[=(),]|->)) +| +(?=[=(),]|->)

and the capture group tells the two cases apart: when it participated the punctuator was consumed
and only the spaces after it are deleted; when it did not, the match is the space run itself,
sitting in front of a punctuator.

**Why it is safe, and it is the reason the decision is taken on the BLANKED half.** The two halves
of a `ctok` pair differ only at literal-interior positions, where the code half holds `\x01` and
whitespace is left alone. Driving the deletion off the code half therefore makes a `,` or a `(`
*inside* a format string invisible: `t("%s, %s", u, v);` loses the spaces outside the literal and
keeps the one inside it. Driving it off the intact half would cut the two halves at **different**
indices, and `cs_half`, `K3`'s two-index comparison and every `call_args` split depend on their
staying the same length. Measured over the whole tree (47 files, including the four generated ones
this suite excludes): **zero length divergences**, `ctok` 190 ms, `cs_norm` **207 ms**.

One pass is idempotent because `cs_ws` has already folded every run, so no two spaces are adjacent
and no deletion can create a new candidate — asserted on eight shapes before the design was
adopted, and fenced in the tree by `Z0c`.

**What it costs, stated in the file rather than discovered later**: `#define X (1)` and
`#define X(1)` become the same string, so the object-like/function-like macro distinction is erased,
and `a == b` becomes `a==b`. Erasing whitespace can never paste two identifiers together, so any
text matching a normalised needle is a genuine token-for-token equivalent of it; but two texts that
differ *only* in such a space are now one string here. `Z0c`'s last clause asserts that no two of
this file's four verbatim exemption entries have merged.

**W4, rebuilt from the other end.** The old row counted the string
`xctx->ev_precision = tclgetintvar(`. It now walks every occurrence of the FIELD, accepts it as a
write on `=` (not `==`), a compound assignment or `++`/`--`, takes the text from the field to the
`;`, and requires it to be either the canonical clamped writer or one verbatim exemption
(`xctx->ev_precision = 4;`, which the tree really spells **`xctx->ev_precision= 4;`** with no space
before the `=` — the very shape M1 used). That closes M1 by normalisation and **M6 by shape**: M6's
second statement is `xctx->ev_precision = t;`, whose right-hand side names no clamp at all. The
compound forms come free.

**W4c, the same question from the source end**, and it is what makes W4's name safe rather than
merely true today: every read of `tclgetintvar("ev_precision")` must be the argument of
`clamp_prec_g(..., DTOA_ENG_BUFSIZE)` at the read itself, with one verbatim exemption
(`graph_marker_text_rec`'s getter, fenced instead by G7/K2/G6/G6b). A value parked in a local is
caught wherever it later goes, so M6 is closed twice over. `#define SP sprintf` is closed by
`sprintf_aliases`, driven as decoy **M7**.

**Named residue, in the file's NAMED LIMITS block as limit 6**: a write through a POINTER or an
aliased struct copy (`p = xctx; p->ev_precision = 200;`). W4 reads the field by name and W4c reads
the Tcl variable by name; neither follows an alias and no textual row can. W4c is what keeps this
narrow: a value that never came from `tclgetintvar("ev_precision")` is not the file-borne 1606 input
at all.

---
## 2. M1, M2 and M6 — the verbatim failing lines, on the final tree

Each of these is one full cycle on the tree as it now stands.

**M1** — `xctx->ev_precision=tclgetintvar("ev_precision");` planted in `draw_cursor`, no spaces round
the `=`. `RESULT: 2 FAILED (61 passed)`:

```
FAIL: W4 every WRITE to xctx->ev_precision in the hand-written sources passes the value through clamp_prec_g -- whatever the spacing, and whether it is one statement or two -- so there is no UNCLAMPED writer left; the one exemption (xinit.c's initial 4) is still used, and the writes are at exactly the four sites this suite fences by name -> {1 {{draw.c: UNCLAMPED WRITE TO xctx->ev_precision: xctx->ev_precision=tclgetintvar("ev_precision");}} {{xctx->ev_precision=4;}} {{draw.c x3} {eval_expr.y x1} {xinit.c x1}}} (exp {0 {} {{xctx->ev_precision=4;}} {{draw.c x2} {eval_expr.y x1} {xinit.c x1}}}) : FAIL

FAIL: W4c ... and every READ of the Tcl ev_precision var in the hand-written sources is wrapped in clamp_prec_g(.., DTOA_ENG_BUFSIZE) at the read itself, so a value that reaches a formatter through a LOCAL rather than through the field is caught too -- with exactly one exemption (graph_marker_text_rec's getter), and the reads are in exactly the two files this suite fences by name -> {1 {{draw.c: UNCLAMPED READ of the Tcl ev_precision var: xctx->ev_precision=tclgetintvar("ev_precision");}} {{prec=tclgetintvar("ev_precision");}} {draw.c eval_expr.y}} (exp {0 {} {{prec=tclgetintvar("ev_precision");}} {draw.c eval_expr.y}}) : FAIL
```

**M6** — `{ int zt = tclgetintvar("ev_precision"); xctx->ev_precision = zt; }`, the write split over
two statements. `RESULT: 2 FAILED (61 passed)`:

```
FAIL: W4 every WRITE to xctx->ev_precision in the hand-written sources passes the value through clamp_prec_g -- whatever the spacing, and whether it is one statement or two -- so there is no UNCLAMPED writer left; the one exemption (xinit.c's initial 4) is still used, and the writes are at exactly the four sites this suite fences by name -> {1 {{draw.c: UNCLAMPED WRITE TO xctx->ev_precision: xctx->ev_precision=zt;}} {{xctx->ev_precision=4;}} {{draw.c x3} {eval_expr.y x1} {xinit.c x1}}} (exp {0 {} {{xctx->ev_precision=4;}} {{draw.c x2} {eval_expr.y x1} {xinit.c x1}}}) : FAIL

FAIL: W4c ... and every READ of the Tcl ev_precision var in the hand-written sources is wrapped in clamp_prec_g(.., DTOA_ENG_BUFSIZE) at the read itself, so a value that reaches a formatter through a LOCAL rather than through the field is caught too -- with exactly one exemption (graph_marker_text_rec's getter), and the reads are in exactly the two files this suite fences by name -> {1 {{draw.c: UNCLAMPED READ of the Tcl ev_precision var: int zt=tclgetintvar("ev_precision");}} {{prec=tclgetintvar("ev_precision");}} {draw.c eval_expr.y}} (exp {0 {} {{prec=tclgetintvar("ev_precision");}} {draw.c eval_expr.y}}) : FAIL
```

**M2** — `sprintf (zb, "%.*g", xctx->ev_precision, zv);`, one space before the paren.
`RESULT: 1 FAILED (62 passed)`:

```
FAIL: X1 in every sprintf statement whose own format LITERAL carries a `%.*`, anywhere in the hand-written sources -- including one spelled `sprintf (` or through an object-like `#define` alias -- the argument in the `%.*` position IS a clamp_prec_g() call and that clamp's avail NAMES the destination buffer, not merely a clamp_prec_g token somewhere in the statement (a format held in a `char *` VARIABLE is out of reach here: NAMED LIMIT 2) -> {1 {{draw.c: `%.*` ARGUMENT IS NOT A clamp_prec_g() CALL (xctx->ev_precision): sprintf(zb,"%.*g",xctx->ev_precision,zv);}}} (exp {0 {}}) : FAIL
```

Note in M1's and M6's W4 detail that the **anti-vacuity clause fires too** (`{draw.c x3}` where the
tree has `x2`), so a fifth writer is caught twice by the same row — once as an unclamped write and
once as a write site the suite does not fence by name.

---

## 3. T2 — Y1c, the anti-vacuity row for Y1a/Y1b

The row compiles a synthetic snippet that MUST warn, at **both** flag sets Y1a and Y1b use, and
requires a diagnostic from each:

```c
#include <stdio.h>
void zz_must_warn(void);
void zz_must_warn(void)
{
  char b[4];
  sprintf(b, "%s", "0123456789");
}
```

`%s` and not `%.*g`, so nothing about the precision clamps can satisfy or break it; ten bytes into a
four-byte buffer is a static overflow gcc reports at `-Wformat-overflow=1`, which the build's own
flags already give through the fortified `__builtin___sprintf_chk` — measured, because this tree's
`CFLAGS` carry **no `-Wall` and no `-Wformat`**:

```
$ gcc -pipe -O2 -I/usr/include/cairo … -I/usr/include/tcl8.6 -c zz.c
zz.c:6:15: warning: '%s' directive writing 10 bytes into a region of size 4 [-Wformat-overflow=]
  …/bits/stdio2.h:30:10: note: '__builtin___sprintf_chk' output 11 bytes into a destination of size 4
```

`ycompile` grew one parameter for it — a source DIRECTORY instead of the repo root — so the synthetic
can live in the suite's own scratch dir. That is the only change to it.

**It reddens with `-w` in EITHER position. Verbatim.**

`-w` **PREPENDED** to `Makefile.conf`'s CFLAGS line:

```
FAIL: Y1c the compile Y1a and Y1b take their opinion from can actually EMIT a -Wformat-overflow diagnostic, at BOTH flag sets -- a synthetic sprintf of 10 bytes into a 4-byte buffer is reported -- so a `-w` anywhere in the generated Makefile.conf's CFLAGS reddens this row instead of making Y1a and Y1b pass on a tree with no clamp (level2=0 diagnostics build-flags=0 missing2={} missing1={} cflags={-w -pipe -O2 -I/usr/include/cairo -I/usr/include/freetype2 -I/usr/include/libpng16 -I/usr/include/pixman-1 -I/usr/include/tcl8.6 } l2={} bld={}) : FAIL
```

`-w` **APPENDED**, i.e. after the explicit `-Wformat-overflow=2` that Y1a itself adds — the case
where "the explicit flag wins" would have been a defence, and is not:

```
FAIL: Y1c the compile Y1a and Y1b take their opinion from can actually EMIT a -Wformat-overflow diagnostic, at BOTH flag sets -- a synthetic sprintf of 10 bytes into a 4-byte buffer is reported -- so a `-w` anywhere in the generated Makefile.conf's CFLAGS reddens this row instead of making Y1a and Y1b pass on a tree with no clamp (level2=0 diagnostics build-flags=0 missing2={} missing1={} cflags={-pipe -O2 -I/usr/include/cairo -I/usr/include/freetype2 -I/usr/include/libpng16 -I/usr/include/pixman-1 -I/usr/include/tcl8.6 -w } l2={} bld={}) : FAIL
```

`level2=0` and `build-flags=0` are the two diagnostic counts; `missing2={}`/`missing1={}` show the
`.o` really appeared, so a failed compile cannot read as "no warnings". And the row skips cleanly
with no compiler: the existing lowercase `skip:` line now names three rows, measured as cycle
`NOCFLAGS` (no `CFLAGS=` line in `Makefile.conf`) — `RESULT: ALL PASS (60 checks)`, one `skip:` line,
`skip: Y1a Y1b Y1c -- no gcc on PATH (12 chars) or no CFLAGS line in Makefile.conf …`.

⚠ **The residue, named in the file as limit 7**: Y1c proves the compile can emit a
`-Wformat-OVERFLOW` diagnostic. A CFLAGS carrying only `-Wno-format-truncation` would leave Y1c green
while silencing the truncation half of Y1a/Y1b. `-w` and `-Wno-format-overflow` are both caught.

---

## 4. T3 — the eight statements, old text and new text

Every one of these is in the tree now. `(h)` is the only product-file change in this stage.

### (a) the two ROW NAMES

**W4** — the parenthetical was refuted by M1 and M6. The row was rebuilt (§1), so the claim is now
delivered rather than asserted, and the name says which question is being asked:

* **old** `W4 no hand-written source assigns xctx->ev_precision straight from tclgetintvar (i.e.
  there is no UNCLAMPED writer left)`
* **new** `W4 every WRITE to xctx->ev_precision in the hand-written sources passes the value through
  clamp_prec_g -- whatever the spacing, and whether it is one statement or two -- so there is no
  UNCLAMPED writer left; the one exemption (xinit.c's initial 4) is still used, and the writes are
  at exactly the four sites this suite fences by name`

**X1** — M2 is closed by normalisation, but the old name was false for a **second** reason nobody
had named: `show_node_measures`' two sites are indirect-precision sprintf statements in a
hand-written source that X1 still cannot see, because their `%.*` lives in a `char *` variable
(NAMED LIMIT 2). So the name is **narrowed to the set the row decides**, and the residue is named
in the name itself:

* **old** `X1 in every indirect-precision sprintf statement in the hand-written sources, the
  argument in the `%.*` position IS a clamp_prec_g() call and that clamp's avail NAMES the
  destination buffer -- not merely a clamp_prec_g token somewhere in the statement`
* **new** `X1 in every sprintf statement whose own format LITERAL carries a `%.*`, anywhere in the
  hand-written sources -- including one spelled `sprintf (` or through an object-like `#define`
  alias -- the argument in the `%.*` position IS a clamp_prec_g() call and that clamp's avail NAMES
  the destination buffer, not merely a clamp_prec_g token somewhere in the statement (a format held
  in a `char *` VARIABLE is out of reach here: NAMED LIMIT 2)`

### (b) + (c) NAMED LIMIT 1 — "caught by NOTHING" at twelve sites, and "three times"

* **old** `⚠ THE FENCE THAT DOES CATCH IT IS ROW Y1a, and only there: … gcc at
  -Wformat-overflow=2 reports `'%.*g' directive writing between 1 and 310 bytes into a region of
  size 80` three times in editprop.c. … At the other TWELVE call sites (two of the fourteen are
  dtoa_eng's own) gcc cannot see the clamp's return range across TUs, so the same shape there is
  caught by NOTHING in this file.`
* **new** the count is `TWICE`, with the reason (the MEG arm carries its own clamp now, so only two
  of the three conversions are unbounded) and the note that the old figure contradicted the `{2
  {...}}` proof line in `C3-close.md`; and the twelve-site claim is replaced by the measured
  decomposition — `of the fourteen clamp_prec_g call sites, TWO are dtoa_eng's own and Y1a sees
  them; at the THREE WRITER sites an `if(0)` in front of the clamped write leaves the unclamped one
  for W4 (and W4c); at EIGHT sprintf sites it leaves an unclamped `%.*` argument for X1. EXACTLY ONE
  SITE IS EXPOSED: `show_node_measures` … G5 is its only fence … 2 + 3 + 8 + 1 = 14.`

### (c) the section-Y header

* **old** `gcc then says `'%.*g' directive writing between 1 and 310 bytes into a region of size 80`
  three times. No static row can see N1 at all`
* **new** `TWICE -- not three times: the "%.*gMEG" arm carries its own clamp now, so two of the
  three conversions are unbounded, and the Y1a proof line in receipts/C3-close.md prints `{2 {...}}`.`

### (d) Y1a's exclusivity

* **old** `so a clamp whose result never reaches the conversion (N1, N2, N3) is caught here and
  nowhere else in this file`
* **new** `so a clamp whose result never reaches the conversion is caught here (N1 here and NOWHERE
  else in this file; N2 also reddens Z1, N3 also reddens K2 and K3)` — and the section-Y header says
  the same, citing C3v-final.md §4.6. Re-measured this round: **N2 → Y1a, Z1**; **N3 → K2, K3, Y1a**;
  **N1 → Y1a alone**.

### (e) the section-Z header

* **old** `H6 and every "exactly 71 significant digits" assertion in B1, B2, B3, B5, B7 and D2
  redden on that tree anyway (measured as cycle S05 …)`
* **new** `Every "exactly 71 significant digits" assertion in B1, B2, B3, **B4**, B5, B7 and D2
  reddens on that tree anyway … ⚠ H6 DOES NOT. An earlier revision of this sentence named it first
  and omitted B4. H6 asserts `static char s[DTOA_ENG_BUFSIZE];`, which neither raising the macro nor
  parking a decoy `#define` touches, so it stays GREEN under both -- measured twice.`
  Confirmed here as cycle **P05**: `rows=B1,B2,B3,B4,B5,B7,D2,H5`, no H6.

### (f) `tests/run_regression.tcl`

* **old** `One shape is still out of reach of any static row -- `if(0) <the guard>`, which uses no
  preprocessor at all -- and it is named as such in the suite's own header, together with the
  compiler-diagnostics rows Y1a/Y1b that do catch it in editprop.c.`
* **new** a paragraph that first records the fourth round (three legal-C spellings that left the
  suite at ALL PASS, and what closed each), then: `ONE shape is still out of reach of any static row
  -- `if(0) <the guard>`, which uses no preprocessor at all -- and it is exposed at exactly ONE of
  the fourteen clamp sites (show_node_measures, whose formats are char * variables); at the other
  thirteen it leaves an unclamped statement for X1, W4 or the compiler-diagnostics rows Y1a/Y1b.`

### (g) X1's comment on who fences the thirteen sites

* **old** `The thirteen existing sites are already fenced by their exact-text G rows (a
  swapped-argument sabotage reddens G6, measured), so this is about a NEW site.`
* **new** counted: `EIGHT have a per-site `G` row (G1 G2 G3 G4 G6 G8 G9 G11 …), THREE are dtoa_eng's
  own and are fenced by K2/K3 …, and TWO are show_node_measures', which X1 cannot see at all … G5
  and G5b fence those by the variable names. So this row is about a NEW site, and the map of who
  fences the old ones is 8 + 3 + 2.`

### (h) `src/editprop.c` — the one product edit, comment only

* **old** `Fenced by rows K3 and Y1 of tests/headless/test_ev_precision_bound_1606.tcl -- Y1 asserts
  the compiler itself reports no -Wformat-overflow/-Wformat-truncation here.`
* **new** `Fenced by rows K3, Y1a and Y1b of tests/headless/test_ev_precision_bound_1606.tcl --
  there is no row "Y1"; Y1a and Y1b assert the compiler itself reports no
  -Wformat-overflow/-Wformat-truncation here, and Y1c asserts that compile can still emit one.`

Nothing else in `src/editprop.c` changed; `git diff --stat` for it is `1 file changed, 5
insertions(+), 3 deletions(-)` on top of the landed fix, all inside one block comment.

---

## 5. The `if(0)` limit, re-driven at one site per class

| site | class | decoy | rows that redden |
|---|---|---|---|
| `dtoa_eng` (editprop.c, same TU) | in-TU | **N1** | `Y1a` |
| `draw_graph` | WRITER | **Q_wgraph** — `if(0)` before the clamped write, unclamped write after | `W4`, `W4c`, `D2` |
| `draw_cursor` | sprintf argument | **Q_cur2** — `{ if(0) <clamped>; <unclamped>; }` | `X1` |
| `show_node_measures` | the exposed one | **Q_snm2** — the live `int prec = xctx->ev_precision;`, the asserted statement in an `if(0) { … }` | **NONE — `RESULT: ALL PASS (62 checks)`** |

Two of these did not compile on the first attempt and that is worth recording, because it is the
same mistake the third adversary made at its Q1: `if(0) <stmt>; <stmt>;` inside an `if/else` chain
**detaches the `else`** (`draw.c:4975: error: expected '}' before 'else'` there, `expected
expression before 'int'` here), and `if(0) int prec = …;` is not C at all — a declaration cannot be
the body of an `if`. Both need braces. Nothing was measured on those two runs.

The other seven sprintf sites were **not** individually driven: they are the same X1 rule over the
same statement set, so that is an argument and not a measurement, and it is stated as one.

---
## 6. All 24 product guards still redden on their own single removal — on the NEW suite

One cycle per guard, one edit per cycle, rebuild, armed nogui run, restore, rebuild, re-run.
`restored_green` true in 24 of 24. The last column is what `C3v-final.md` recorded on the old suite,
for comparison.

| # | guard, as a single removal | rows that reddened HERE | C3v-final.md |
|---|---|---|---|
| P01 | `clamp_prec_g`: `if(prec <= 0) return prec;` | H2 | H2 |
| P02 | `clamp_prec_g`: `if(avail <= 9) return 1;` | H2b | H2b |
| P03 | `cap = avail - 9;` -> `cap = 71;` | H3, Y1a, Y1b | H3, Y1a, Y1b |
| P04 | `if((size_t)prec > cap) return (int)cap;` | B1, B2, B3, B4, B5, B7, D1, D1b, D2, H4, Y1a | H4, B1 B2 B3 B4 B5 B7 D1 D1b D2, Y1a |
| P05 | `#define DTOA_ENG_BUFSIZE 80` -> `100` | B1, B2, B3, B4, B5, B7, D2, H5 | H5, B1 B2 B3 B4 B5 B7 D2 |
| P06 | `static char s[DTOA_ENG_BUFSIZE];` -> `s[80]` | H6 | H6 |
| P07 | `dtoa_eng`'s clamp above the branch | K2, K3, Y1a | K2 K3, Y1a |
| P08 | the MEG arm's `clamp_prec_g(precision, sizeof(s) - 2)` | K3, X1, Y1a, Y1b | K3, X1, Y1a Y1b |
| P09 | `draw_graph()`'s writer clamp | D2, W1, W4, W4c | W1, W4, D2 |
| P10 | `draw()`'s writer clamp | B5, W2, W4, W4c | W2, W4, B5 |
| P11 | `kklex()`'s writer clamp (`eval_expr.y`) | W3, W4, W4c, W6 | W3, W4, W6 |
| P12 | `draw_cursor`'s clamp | G1, X1 | G1, X1 |
| P13 | `draw_cursor_difference`'s clamp | G2, X1 | G2, X1 |
| P14 | `draw_hcursor`'s `- 2` | G3 | G3 |
| P15 | `draw_hcursor_difference`'s `- 2` | G4 | G4 |
| P16 | `show_node_measures`' clamp | G5 | G5 |
| P17 | `show_node_measures`' `prec = 2;` pin | G5b | G5b |
| P18 | `graph_marker_fmt`'s clamp | G6, X1, X1c | G6, X1, X1c |
| P19 | `graph_marker_fmt`'s `if(!dest || destsize <= 0) return;` | G6b | G6b |
| P20 | `graph_marker_text_rec`'s `if(prec > 17) prec = 17;` | B6, G7 | G7, B6 |
| P21 | the tooltip's `sx` clamp | G8, X1 | G8, X1 |
| P22 | the tooltip's `sy` clamp | G9, X1 | G9, X1 |
| P23 | the C14 second-defect fix (`gr->unity` -> `gr->unitx` over the `sy` body) | D3, D4, G10, G9 | G10, D3 D4 |
| P24 | `nd_view_set`'s clamp | G11, X1 | G11, X1 |

**The three differences, all explained:**

* `P09`/`P10`/`P11` now also redden **W4c** — the new row. The unclamped writer's
  `tclgetintvar("ev_precision")` is no longer wrapped, which is exactly what W4c is for.
* `P04`'s `D1` and `P10`'s `B5` etc. match C3v exactly.
* `P23` also reddens **G9** here, because my single edit changed both the `if(gr->unity != 1.0)`
  guard **and** the `sprintf(sy, …)` line's unit tokens, so G9's exact-text needle moved too.
  C3v's narrower edit reddened `G10 D3 D4` only. `G10` — the row that is the actual fence — reddened
  in both. My decoy is broader than C3v's; the guard is fenced either way.

⚠ **Nothing was made vacuous by the normalisation.** Every row that reddened for C3v still reddens,
none reddened for a *different* guard, and the four rows with no product guard at all (`Z0`, `Z0b`,
`Z3`, `Z4`) plus the exemption rows (`X1b`, `X1c`, `W4b`) stayed green on the correct tree through
all 75 cycles. The rows that fence the MATCHING MACHINERY rather than the product are `Z0`, `Z0b`,
**`Z0c`**, `Z3`, `Z4`, `X1d`, **`X1e`**, **`W4d`** and `B0`/`B0b`; §8 sabotages the new three.

---
## 7. T4 — every decoy from all four rounds, against the final tree

One full cycle each (apply, build, armed nogui run, restore, rebuild, re-run). `restored_green` true
in every one. `M3` and `M5` **appear in no receipt in this batch** — `C3v-final.md` documents M1, M2,
M4 and M6 only — so they are not in the table and nothing is claimed about them.

| decoy | shape | rows that redden | verdict |
|---|---|---|---|
| **V1** | dtoa_eng's clamp inside a BLOCK COMMENT, real one gone | `K2`, `K3`, `Y1a` | RESULT: 3 FAILED (59 passed) |
| **V1_G1** | G1's statement in a BLOCK COMMENT, real sprintf replaced by `tmpstr[0] = 0;` | `G1` | RESULT: 1 FAILED (61 passed) |
| **V3** | `#ifdef XSCHEM_NEVER` round G5's statement in `show_node_measures`, live `int prec = xctx->ev_precision;` | `Z2` | RESULT: 1 FAILED (61 passed) |
| **V5** | `#if 0 && 1` round dtoa_eng's clamp | `K2`, `K3`, `Y1a`, `Z1` | RESULT: 4 FAILED (58 passed) |
| **V6** | `draw_hcursor`'s `- 2` REALLY removed, G3's statement in a `//` comment below | `G3` | RESULT: 1 FAILED (61 passed) |
| **N1** | `if(0) precision = clamp_prec_g(precision, sizeof(s));` | `Y1a` | RESULT: 1 FAILED (61 passed) |
| **N2** | `#define ZZ_CLAMP_IT <the statement>`, never invoked | `Y1a`, `Z1` | RESULT: 2 FAILED (60 passed) |
| **N3** | the statement inside a `static const char *zz = "..."` | `K2`, `K3`, `Y1a` | RESULT: 3 FAILED (59 passed) |
| **N4** | `#ifndef __unix__` (DEAD here) round G5's statement, live unclamped | `G5` | RESULT: 1 FAILED (61 passed) |
| **N5** | `#if HAS_CAIRO!=1` (DEAD) round G9's statement, live clamp weakened to `S(sy) + 900` | `G9` | RESULT: 1 FAILED (61 passed) |
| **N6** | the DEAD `#else` of a `#if 1`, same live weakening | `G9` | RESULT: 1 FAILED (61 passed) |
| **N7** | new site, comma operator: `(clamp_prec_g(...), xctx->ev_precision)` | `X1` | RESULT: 1 FAILED (61 passed) |
| **N8** | new site clamped against the literal `1024` into `char zb[24]` | `X1` | RESULT: 1 FAILED (61 passed) |
| **N9** | new unclamped site behind a `//` opening on a multi-line literal's CONTINUATION line | `X1` | RESULT: 1 FAILED (61 passed) |
| **N10** | new unclamped site behind `dbg(1, "/*\n");` | `X1` | RESULT: 1 FAILED (61 passed) |
| **N11** | `#if (0)` / `#endif` planted in `dtoa_eng`'s body | `Z1` | RESULT: 1 FAILED (61 passed) |
| **N12** | a FIFTH unclamped writer behind the same `"/*"` | `W4`, `W4c` | RESULT: 2 FAILED (60 passed) |
| **M1** | `xctx->ev_precision=tclgetintvar("ev_precision");` — no spaces round the `=` | `W4`, `W4c` | RESULT: 2 FAILED (61 passed) |
| **M2** | `sprintf (zb, "%.*g", xctx->ev_precision, zv);` — one space before the paren | `X1` | RESULT: 1 FAILED (62 passed) |
| **M4** | format by literal concatenation: `sprintf(zb, "%.*" "g", ...)` | `X1` | RESULT: 1 FAILED (61 passed) |
| **M6** | `{ int zt = tclgetintvar("ev_precision"); xctx->ev_precision = zt; }` — TWO statements | `W4`, `W4c` | RESULT: 2 FAILED (61 passed) |
| **M7** | `#define ZZSP sprintf` then `ZZSP(zb, "%.*g", xctx->ev_precision, zv);` — NEW, the shape C3v named and did not drive | `X1`, `Z1` | RESULT: 2 FAILED (61 passed) |
| **F1** | clamp kept, then `precision = *(volatile int *)&precision;` | `Y1a` | RESULT: 1 FAILED (61 passed) |
| **F2** | clamp kept, then `if(precision > 0) precision += 200;` | `B1`, `B2`, `B3`, `B4`, `B7`, `D1`, `D1b`, `D2`, `D3`, `D4`, `Y1a`, `Y1b` | RESULT: 12 FAILED (50 passed) |
| **Q_cur2** | `if(0)` before draw_cursor's clamped sprintf, unclamped one after (braced) | `X1` | RESULT: 1 FAILED (61 passed) |
| **Q_snm2** | `if(0) { <G5's statement> }`, live `int prec = xctx->ev_precision;` | **NONE** | RESULT: ALL PASS (62 checks) |
| **Q_wgraph** | `if(0)` before draw_graph's clamped write, unclamped write after | `D2`, `W4`, `W4c` | RESULT: 3 FAILED (59 passed) |
| **Y1w_pre** | `-w` PREPENDED to Makefile.conf's CFLAGS | `Y1c` | RESULT: 1 FAILED (61 passed) |
| **Y1w_post** | `-w` APPENDED after `-I/usr/include/tcl8.6`, i.e. after the explicit `-Wformat-overflow=2` Y1a adds | `Y1c` | RESULT: 1 FAILED (61 passed) |
| **NOCFLAGS** | no `CFLAGS=` line in Makefile.conf (the FLOOR's no-compiler leg) | **NONE** | RESULT: ALL PASS (59 checks) |

**The one OPEN-AND-NAMED entry is `Q_snm2`**, and the naming sentence now in the file is:

> `EXACTLY ONE SITE IS EXPOSED: `show_node_measures`, because its formats are `char *` variables so
> X1 is blind there (limit 2 below) and its clamp is a separate `int prec = ...` statement that an
> `if(0)` satisfies textually -- G5 is its only fence, which is the same single point decoy N4
> established. 2 + 3 + 8 + 1 = 14.`

**Two decoys of mine differ from the round that first used them, and I say which:**

* `V1` here parks **dtoa_eng's** clamp in a block comment (`K2 K3 Y1a`); `C3v-final.md`'s V1 parked
  **G1's** statement. `V1_G1` is that one, and it reddens `G1`. C3v recorded `G1, X1` — mine reddens
  `G1` alone because I replaced the real sprintf with `tmpstr[0] = 0;` rather than with an unclamped
  sprintf, so X1 has nothing to object to. Same class, same fence.
* `M7` is **new to this round**: the `#define SP sprintf` shape C3v named in its §7 and did not
  drive. It reddens `X1` (the alias is now a statement) **and** `Z1` (a `#define` inside
  `draw_cursor`, a body Z1 covers) — two independent fences.

---
## 8. Every row this round adds or changes, sabotaged

Five new rows (`W4c`, `W4d`, `X1e`, `Z0c`, `Y1c`) and two rebuilt ones (`W4`, `X1`). The product
guards `W4`/`W4c`/`X1` fence are sabotaged in §6 (`P09`–`P11`, `P12`–`P24`) and §7 (every decoy). The
rows that fence the MATCHING MACHINERY cannot be sabotaged that way — that is the whole point of
`X1d`'s existence — so each gets its own cycle here.

| sabotage | what was weakened | rows that redden |
|---|---|---|
| `SAB_norm` | `cs_collapse` stops normalising (`return [cs_ws $cs]`) | `Z0c`, `X1e`, `W4d`, **`W4`** |
| `SAB_half` | `cs_norm` decides on the INTACT half instead of the blanked one | `Z0c` |
| `SAB_alias` | the `#define SP sprintf` alias loop dropped from `sprintf_stmts` | `X1e` |
| `SAB_w4lit` | `w4_verdict`'s exact shape test replaced by the old token-presence test | `W4d` |
| `SAB_w4clit` | `w4c_wrapped`'s positional test replaced by "a `clamp_prec_g` within 40 characters" | `W4d` |
| `SAB_w4cex` | W4c's one exempted read deleted (`prec = 5;`) | `W4c`, `B6` |
| `Y1w_pre` / `Y1w_post` | `-w` in the generated `Makefile.conf`'s CFLAGS | `Y1c` |

**`SAB_norm` reddening `W4` is the finding inside the finding**, and it is worth quoting because it
shows the normaliser is load-bearing on a line this tree really contains rather than only on a decoy:

```
FAIL: W4 every WRITE to xctx->ev_precision in the hand-written sources passes the value through clamp_prec_g -- whatever the spacing, and whether it is one statement or two -- so there is no UNCLAMPED writer left; the one exemption (xinit.c's initial 4) is still used, and the writes are at exactly the four sites this suite fences by name -> {1 {{xinit.c: UNCLAMPED WRITE TO xctx->ev_precision: xctx->ev_precision= 4;}} {} {{xinit.c x1}}} (exp {0 {} {{xctx->ev_precision = 4;}} {{draw.c x2} {eval_expr.y x1} {xinit.c x1}}}) : FAIL
```

`xinit.c` writes `xctx->ev_precision= 4;` with **no space before the `=`**, so without normalisation
the exemption entry (written `xctx->ev_precision = 4;`, the way a reader would write it) does not
match it and the initial value reads as an unclamped writer. M1's spelling is this tree's own.

**`SAB_half` is the safety clause's fence.** With the decision taken on the intact half, the comma
INSIDE the format string moves: `t("%s, %s",u,v);` instead of `t("%s, %s",u,v);` with its space —

```
FAIL: Z0c the punctuation normaliser makes whitespace around `= ( ) ,` and `->` unable to change a match (decoys M1 and M2), leaves whitespace INSIDE a string literal alone because it decides on the blanked half, keeps the two halves the same length, and has not merged any two of this file's verbatim exemption entries -> {{xctx->ev_precision=tclgetintvar("ev_precision");} {xctx->ev_precision=tclgetintvar("ev_precision");} {xctx->ev_precision=tclgetintvar("ev_precision");} {sprintf(zb,"%.*g",p,zv);} {sprintf(zb,"%.*g",p,zv);} {t("%s,%s",u,v);} {int a; int b;} 1 1} (exp {{xctx->ev_precision=tclgetintvar("ev_precision");} {xctx->ev_precision=tclgetintvar("ev_precision");} {xctx->ev_precision=tclgetintvar("ev_precision");} {sprintf(zb,"%.*g",p,zv);} {sprintf(zb,"%.*g",p,zv);} {t("%s, %s",u,v);} {int a; int b;} 1 1}) : FAIL
```

— and note the two halves would then be different lengths, which is what `Z0c`'s length clause and
`K3`'s two-index comparison depend on.

**`SAB_w4lit` and `SAB_w4clit` are the measurement that justified `W4d` existing at all.** Before
`W4d`, `SAB_w4lit` left the suite at `RESULT: ALL PASS (62 checks)` — a weakened negative rule has
nothing to miss on a correct tree. With `W4d`:

```
FAIL: W4d and the rules themselves, on synthetic text: the clamped writer in both spellings, xinit.c's exempt 4 in both, a bare unclamped writer, M6's second statement, a writer clamped against a LITERAL instead of DTOA_ENG_BUFSIZE, a compound assignment, an increment, a COMPARISON that is not a write, a write inside a larger statement, and the read-side wrap test on the accepted form, the wrong ceiling and a bare read -> {clamped clamped exempt exempt bad bad clamped bad bad 1 {xctx->ev_precision=zt;} 1 0 0} (exp {clamped clamped exempt exempt bad bad bad bad bad 1 {xctx->ev_precision=zt;} 1 0 0}) : FAIL
```

(case 7, `clamp_prec_g(tclgetintvar("ev_precision"), 1024)` at a writer, flips from `bad` to
`clamped`), and for the read side, case 13 flips from `0` to `1`:

```
FAIL: W4d and the rules themselves, on synthetic text: the clamped writer in both spellings, xinit.c's exempt 4 in both, a bare unclamped writer, M6's second statement, a writer clamped against a LITERAL instead of DTOA_ENG_BUFSIZE, a compound assignment, an increment, a COMPARISON that is not a write, a write inside a larger statement, and the read-side wrap test on the accepted form, the wrong ceiling and a bare read -> {clamped clamped exempt exempt bad bad bad bad bad 1 {xctx->ev_precision=zt;} 1 1 0} (exp {clamped clamped exempt exempt bad bad bad bad bad 1 {xctx->ev_precision=zt;} 1 0 0}) : FAIL
```

---

## 9. Deviations from the task, and why

1. ⚠ **FIVE new rows, not one.** The task scoped this round to "(a) the two needle spellings, (b) one
   new anti-vacuity row, (c) test prose and row names". `W4c`, `W4d`, `X1e` and `Z0c` are beyond that,
   and each is there because a MEASUREMENT said the round's own work would otherwise be unfenced:
   * `Z0c` — the normaliser is new machinery; `SAB_norm`/`SAB_half` redden nothing without it.
   * `X1e` — `sprintf_stmts` grew the `sprintf (` and `#define SP` cases; `SAB_alias` reddens nothing
     without it.
   * `W4d` — **measured**: weakening `w4_verdict` left the suite green (§8).
   * `W4c` — the task itself said either close M6's "value reaches the field through a local" class
     or name it as a limit. Closing it from the READ end was cheaper and stronger than either, so it
     is closed.
   All four follow the rule the brief states ("every guard needs a row that reddens when the guard is
   removed") and the precedent the file already sets with `X1d`. The FLOOR moves **58/53 → 63/58**,
   which the FLOOR comment says is allowed in that direction only.
2. **`W4`'s and `X1`'s row names were REPLACED, not trimmed.** The task said to keep them if T1 made
   them true and otherwise narrow them. W4's became deliverable rather than true-by-luck, so it is
   rewritten around the question actually asked. X1's is **narrowed**, because normalisation closed
   M2 but `show_node_measures` remains out of reach for a different reason the task did not mention.
3. **`M3` and `M5` do not exist in this batch's receipts.** `C3v-final.md` documents M1, M2, M4 and
   M6. I drove those four plus `M7` (the `#define SP sprintf` shape C3v named and did not drive) and
   said so rather than inventing two decoys and calling them M3/M5.
4. **`V1` at two sites.** My `V1` parks dtoa_eng's clamp in a block comment; `V1_G1` is C3v's
   draw_cursor version. `V1_G1` reddens `G1` and not `G1, X1`, because my edit removes the sprintf
   rather than replacing it with an unclamped one (§7).
5. **`P23`'s decoy is broader than C3v's**, so it reddens `G9` as well as `G10 D3 D4` (§6).
6. **`Q_cur`/`Q_snm` had to be re-cut** — the first spelling of each did not compile (§5). Nothing was
   measured on those two runs.
7. **Seven of the eight `if(0)`-at-a-sprintf-site cases were not individually driven.** One was
   (`Q_cur2`); the rest are the same X1 rule over the same statement set. Stated as an argument, not
   as a measurement.
8. **`receipts/C3-close.md` is corrected by APPENDING a correction section, not by rewriting it.** Its
   §"NAMED LIMITS" block is a **quotation** of the suite comment as it then stood; editing the quote
   would misreport the artefact. CLAUDE.md's rule about dated records carrying a fossil figure points
   the same way.
9. **Not measured, carried forward unchanged**: `-flto`; Win64 and a `./configure --debug` (`-O0`, no
   `_FORTIFY_SOURCE`) build; the `\004` byte in `graph_marker_fmt`'s provenance comment; a full T1
   gate (the driver's, in a clone at a SHORT path — `test_op_annot`'s rule). `hcases` is still **80**
   entries, so the T1 figure C3v computed stands: **99 cases / 98 blocks**, `counted_failures=0`,
   `skips=8` with `:99` up.
10. **The six pre-existing `-Wdiscarded-qualifiers` warnings** (`actions.c:557`, `util.c:222`,
    `save.c`, `token.c:954/955/956`) are still there, still not this batch's, still not touched.

---
## 10. The three arms, verbatim

**ARM 1 — headless, armed** (`tests/headless/run_suites.sh --nogui test_ev_precision_bound_1606`):
```
test home: throwaway /tmp/xschem-test-home.2222102.xUXkPf (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (63 checks)
RESULT: 1/1 runs passed
```

**ARM 2 — display, armed** (`tests/headless/run_suites.sh test_ev_precision_bound_1606`):
```
test home: throwaway /tmp/xschem-test-home.2222545.jWSkq5 (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (63 checks)
RESULT: 1/1 runs passed
```

**ARM 3 — no dev display visible** (`XSCHEM_DEVDISPLAY_DIR` pointed at a **read-only, empty** scratch
dir so `devdisplay.sh status` exits 1; `AUDIT_DISPLAY=none`; `:99` never started, stopped or viewed —
`xvfb: 3979908` before and after, state dir mtimes untouched):
```
test home: throwaway /tmp/xschem-test-home.2222990.HhJR0m (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: none (DISPLAY unset; GUI legs will self-skip)
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (58 checks)
         | skip: D1 D2 D3 D4 -- tests/headless/devdisplay.sh status does not report the persistent dev display alive, so the four draw.c cursor readouts and the callback.c measurement tooltip did not run; bring it up with tests/headless/devdisplay.sh start. G1-G4 and G8-G10 fence the same clamps statically on either arm
RESULT: 1/1 runs passed
```
One `skip:` line, lowercase, reason ends `… on either arm` — not a counted shape, does not start
`FATAL`. And a fourth measurement for the FLOOR's other leg: with no `CFLAGS=` line in
`Makefile.conf`, `RESULT: ALL PASS (60 checks)` and a SECOND lowercase `skip:` naming `Y1a Y1b Y1c`.

### The `hcases` rationale comment

`hcases` is unchanged at **80** entries (counted with
`awk`/`grep -o '"[^"]*"' | wc -l` over the `set hcases [list` block, not a line number), so **no case
or block count moves**: the T1 figure stays **99 cases / 98 blocks**, `counted_failures=0`,
`skips=8` with `:99` up, as `C3v-final.md` computed. What moved inside the comment is the check count
(`58/53` → `63/58`, plus the new row names) and the paragraph about what is still out of reach, which
now records the fourth round and says the `if(0)` limit is one site wide. `tests/run_regression.tcl`
still parses: `info complete` → 1, and `tclsh tests/headless/issue_stamp.tcl` → `ISSUE-STAMP: ok (0
problems)`.

---

## 11. Hygiene

* `git status --porcelain` is the nine entries the brief describes and nothing else. `git diff --stat`
  moved only in `src/editprop.c` (80 → **82**: the 3-line comment became 5) and
  `tests/run_regression.tcl` (51 → **63**). Every other product file is byte-identical to the tree the
  final adversary gated.
* The `src/editprop.c` edit is provably inside ONE block comment: the inserted text spans characters
  9822–10119 and the enclosing `/* … */` runs 8584–10119.
* `make -C src` → `Nothing to be done for 'all'`. No stray `.o` in `src/`.
* `:99`: `state: alive`, `xvfb: 3979908`, `state dir /home/analog/.claude/xschem_dev_display` —
  the same pid throughout, never started/stopped/viewed.
* `~/.claude/xschem_owed/` not opened. `~/dev/xschem-op-wcard` not opened. No
  `/tmp/xschem_emergencysave_*` removed. All scratch, all 75 cycles' JSON and every sabotage script
  under the session scratchpad. Restores by `shutil.copyfile` + `os.utime(..., None)` — never `cp -a`.
* `Makefile.conf` was edited for three cycles (`Y1w_pre`, `Y1w_post`, `NOCFLAGS`) and restored by
  content copy each time; those three ran with `do_build=False`, because `src/Makefile` only
  `include`s `Makefile.conf` and no `.o` depends on it, so no rebuild was due and none was skipped.

---

## 12. What I could NOT measure

* **A full T1 gate** — the driver's, in a clone at a short path.
* **`-flto`**, so whether gcc could bound the precision across TUs is still unmeasured.
* **Win64, and `./configure --debug`** (`-O0`, no `_FORTIFY_SOURCE`) — no toolchain. Inherited.
* **A genuinely compiler-less box.** `NOCFLAGS` exercises the same `skip:` branch by removing the
  `CFLAGS=` line; an attempt to do it by emptying `PATH` instead broke `env`/`timeout` for the B rows'
  child spawns (eight rows reddened with `rc=-1/exec-never-started-the-child`), so that spelling
  measures a broken PATH and not a missing gcc. Recorded because the failure mode is instructive.
* **Whether the other seven `if(0)`-at-a-sprintf-site cases redden X1** — argued, not driven (§5).
* **A write through a pointer alias** — out of reach of any textual row, named as limit 6 rather than
  driven.
