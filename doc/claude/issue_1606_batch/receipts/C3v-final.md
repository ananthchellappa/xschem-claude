# Receipt C3v — final adversary on the issue-1606 tree

Role: last adversary before the driver gates. I changed **nothing** in the product, the suite or
git; every sabotage was applied, measured and restored by content-copy (`shutil.copyfile` +
`os.utime(..., None)`, never `cp -a`), with a rebuild on both sides of every cycle.

**45 build/suite cycles**, all foreground, each with `timeout` on every binary run.
`restored_green` = `RESULT: ALL PASS (58 checks)` and `md5ok` = true in **45 of 45**;
`build_rc`/`restore_build_rc` 0 in 45 of 45 except one deliberate compile error I caused and
re-ran (Q1, first attempt: my `if(0)` broke an `if/else` chain — `draw.c:4975: error: expected
'}' before 'else'`; nothing was measured on that run and the file was restored).

---

## 0. THE HEADLINE, IN ORDER OF WHAT THE DRIVER NEEDS

1. **The product fix is intact and fully fenced.** All **24** product guards redden on their own
   single removal (§3). Nothing three rounds of fence-rebuilding did weakened it.
2. **Q6 verified independently** (§5): the landed tree's warning set is **byte-identical** to
   34913077's — same six pre-existing `-Wdiscarded-qualifiers`, **zero `-Wformat*`** on either
   side — and the MEG clamp changes **no output**: 192 strings, 8 values × both signs × 12
   precisions (4…4000), **`diff` identical** between a cap-71 binary and the landed cap-69 one.
3. **Every decoy from every earlier round is dead** (§2), including the three that mattered most
   (N4, N1, N12). N1 is caught by **Y1a only**, exactly as claimed, and Y1a survived two
   attempts to fool it.
4. ⚠ **THREE NEW SHAPES LEAVE THE SUITE AT `ALL PASS (58 checks)` AND NONE OF THEM IS NAMED**
   (§2.2). They are not new *classes*: they are the **W4 and X1 needles being single literal
   spellings** of the shape their row names claim to cover in general. A fifth unclamped writer
   spelled `xctx->ev_precision=tclgetintvar("ev_precision");` (no spaces) and one assembled in
   two statements both pass W4; a new unclamped `sprintf (zb, "%.*g", xctx->ev_precision, zv);`
   (one space before the paren) passes X1 and X2.
5. ⚠ **Six false or overreaching sentences remain** (§4), two of them in row NAMES — the exact
   defect class the brief says three rounds keep re-committing. The most serious: **W4's and
   X1's names are measurably false on their own terms** (see 4), and the named-limits paragraph's
   claim that the `if(0)` shape is "caught by NOTHING" at twelve call sites is false at eleven of
   them (§4.5) — measured both ways.
6. **Y1a/Y1b have no anti-vacuity row** and take their flags from a generated file (§5.4): a `-w`
   anywhere in `Makefile.conf`'s `CFLAGS` silences both and the N1 fence — the only fence for
   N1 — passes green with the clamp gone. **Measured.**

**Would I gate this tree?** Yes for the product; see §7 for the one-line caveat and what I would
ask the driver to correct in comments before committing. No defect I found is in the shipped
code; all six are in test-suite prose or in the reach of two negative rows.

---

## 1. Method and arms

Binary rebuilt before every quoted figure (`make -C src`). Suite driven two ways, and they agree:

* `tests/headless/run_suites.sh [--nogui] test_ev_precision_bound_1606` (armed; the verdict)
* my own `run1606.sh`, which is `run_suites.sh`'s **nogui arm verbatim**
  (`env -u DISPLAY … --pipe -q --nolog --nogui --script …`) with `test_home_arm` and every row
  printed, so a cycle names the rows that reddened. Baseline: 58 `ok:` lines, `RESULT: ALL PASS
  (58 checks)`, `OVERALL: ok`, rc 0.

`:99` never started, stopped or viewed — `xvfb: 3979908` before and after all 45 cycles, and
`~/.claude/xschem_dev_display/` still has its 2026-09-20 mtimes. The owed ledger was not opened;
`~/dev/xschem-op-wcard` was not opened; no `/tmp/xschem_emergencysave_*` removed; every scratch
file under the session scratchpad; no stray `.o` in `src/` (40 `.o`, the build's own `OBJ` set).

---

## 2. Decoys

### 2.1 Every decoy from every round: DEAD (one full cycle each, on the FINAL tree)

| decoy | shape | reddens | verbatim (trimmed) |
|---|---|---|---|
| **N1** | `if(0) precision = clamp_prec_g(precision, sizeof(s));` | **Y1a** only | `FAIL: Y1a src/editprop.c compiles with ZERO -Wformat-overflow/-Wformat-truncation diagnostics at level 2 …` |
| **N2** | `#define ZZ_CLAMP_IT <the statement>` | **Z1**, Y1a | `FAIL: Z1 … -> {10 1 {{editprop.c dtoa_eng rows {H6 K…` |
| **N3** | the statement inside a string literal | **K2, K3**, Y1a | `FAIL: K2 dtoa_eng clamps its own `precision` parameter against its own buffer -> {0} (exp {1})` |
| **N4** | `#ifndef __unix__` (DEAD here) in `show_node_measures` | **G5** | `FAIL: G5 show_node_measures (NOT draw_graph_variables) clamps the local `prec` … -> {0} (exp {1})` |
| **N6** | the DEAD `#else` of a `#if 1`, live clamp weakened to `S(sy) + 900` | **G9** | `FAIL: G9 the callback.c measurement tooltip's y readout clamps against its own 100-byte sy -> {0} (exp {1})` |
| **N7** | comma operator: clamp computed and discarded | **X1** | `FAIL: X1 … `%.*` ARGUMENT IS NOT A clamp_prec_g() CALL …` |
| **N8** | clamped against `1024` into `char zb[24]` | **X1** | `FAIL: X1 … the clamp's avail (1024) does not NAME the destination (zb)` |
| **N10** | new unclamped site behind `dbg(1, "/*\n");` | **X1** | `FAIL: X1 … `%.*` ARGUMENT IS NOT A clamp_prec_g() CALL (xctx->ev_precision)` |
| **N12** | a FIFTH unclamped writer behind the same `"/*"` | **W4** | `FAIL: W4 … -> {1 {{draw.c x1}}} (exp {0 {}})` |
| **V1** | a block comment holding G1's statement, real one deleted | **G1, X1** | `FAIL: G1 draw_cursor's "%.*g%c" readout clamps against its whole 100-byte buffer -> {0} (exp {1})` |
| **V3** | `#ifdef XSCHEM_NEVER` in `show_node_measures` | **Z2** | `FAIL: Z2 … UNDECIDABLE …` |
| **H5 limit** | decoy `#define DTOA_ENG_BUFSIZE 80` under `#ifdef ZZ_NEVER_DEFINED`, real one raised to 100 | **B1 B2 B3 B4 B5 B7 D2** (H5 stays green, as the comment says) | `FAIL: B1 … digits=91 …` |

Two more of my own that I expected to be caught, and were:

* **M4** — a format assembled by literal concatenation, `sprintf(zb, "%.*" "g", xctx->ev_precision, zv);`
  → `FAIL: X1 … ARGUMENT IS NOT A clamp_prec_g() CALL`. `star_arg_index` reads through the
  concatenation correctly.
* **L2b** — the probe the `D1FIX` paragraph quotes (`draw_cursor`'s `tmpstr[100]`→`[16]` **and**
  its clamp removed). **Re-driven: exactly the four rows the comment now quotes**, with the same
  details, byte for byte:
  ```
  FAIL: G1 draw_cursor's "%.*g%c" readout clamps against its whole 100-byte buffer -> {0} (exp {1}) : FAIL
  FAIL: X1 … (xctx->ev_precision): sprintf(tmpstr, "%.*g%c", xctx->ev_precision, gr->unitx * active_cursorx , gr->unitx_suffix);
  FAIL: D1 … (rc=134/SIGABRT-the-1606-overflow death=0 hasx=<<absent>> done=0 flags=<<absent>>) : FAIL
  FAIL: D1b … -> {<<absent>>} (exp {390}) : FAIL
  ```
  That paragraph is now **true and current**. It is the one comment in this file that was wrong
  twice and is right now.

### 2.2 ⚠ THREE SHAPES THAT STILL LEAVE THE SUITE GREEN, AND ARE NOT NAMED

All three were applied to `src/draw.c`, built, and run: `RESULT: ALL PASS (58 checks)`, rc 0,
`restored_green` true.

| id | what I planted | what the tree then contains | suite |
|---|---|---|---|
| **M1** | `xctx->ev_precision=tclgetintvar("ev_precision");` (no spaces around `=`) | a **FIFTH UNCLAMPED WRITER** | **ALL PASS (58)** |
| **M6** | `int t = tclgetintvar("ev_precision"); xctx->ev_precision = t;` | a fifth unclamped writer, two statements | **ALL PASS (58)** |
| **M2** | `sprintf (zb, "%.*g", xctx->ev_precision, zv);` (one space before the paren) | a **NEW UNCLAMPED indirect-precision site** | **ALL PASS (58)** |

Mechanism, in one sentence each, because the point is that these are **not** a fourth class:

* `W4`'s needle is the literal string `xctx->ev_precision = tclgetintvar(`, matched after
  `collapse` — which folds *runs* of whitespace but never *inserts* any, so `=` without spaces is
  a different string. M1 is that same shape in legal C.
* `sprintf_stmts` finds the literal `sprintf(`; `sprintf (` is a different string. (The same
  blindness covers `#define SP sprintf` — not driven, identical mechanism.)
* M6 is the only one of the three that is arguably outside `W4`'s stated definition
  ("straight from tclgetintvar"); M1 and M2 are **inside** what their row names claim.

The class-level repair, for whoever takes the fourth round if the driver wants one, is to stop
matching a character string and match a **token sequence** (or to have `collapse` normalise
around `= ( ) ,` so that one spelling is canonical). I did not make it: I was told not to fix,
and an honest named limit is the deliverable.

### 2.3 The `if(0)` limit, measured at both ends

Named limit #1 says the shape is caught by Y1a in `editprop.c` and by **nothing** at the other
twelve `clamp_prec_g` call sites. I drove three of those twelve:

| site | decoy | result |
|---|---|---|
| `show_node_measures` (G5) | `int prec = xctx->ev_precision;` live, the asserted statement inside `if(0) { … }` | **ALL PASS (58)** — the limit is real, at this site |
| `draw_cursor` (G1) | `if(0) <the clamped sprintf>` then the unclamped one | **`FAIL: X1`** — caught |
| `draw_graph` (W1) | `if(0) <the clamped writer>` then the unclamped one | **`FAIL: W4`** (+ D2) — caught |

So the limit is **one site wide, not twelve**: `show_node_measures`, which is precisely the site
where N4 already established that `G5` is the only fence. See §4.5 — the paragraph is wrong in
the cautious direction, and it hides which single site is actually exposed.

---

## 3. Every product guard reddens on its own single removal — 24 of 24

One cycle per guard, one edit per cycle, rebuild, armed nogui run, restore, rebuild, re-run.

| # | guard, as a single removal | rows that reddened |
|---|---|---|
| P01 | `clamp_prec_g`: `if(prec <= 0) return prec;` | **H2** |
| P02 | `clamp_prec_g`: `if(avail <= 9) return 1;` | **H2b** |
| P03 | `cap = avail - 9;` → `cap = 71;` | **H3**, Y1a, Y1b |
| P04 | `if((size_t)prec > cap) return (int)cap;` | **H4**, B1 B2 B3 B4 B5 B7 D1 D1b D2, Y1a |
| P05 | `#define DTOA_ENG_BUFSIZE 80` → `100` | **H5**, B1 B2 B3 B4 B5 B7 D2 |
| P06 | `static char s[DTOA_ENG_BUFSIZE];` → `s[80]` | **H6** |
| P07 | `dtoa_eng`'s clamp above the branch | **K2 K3**, Y1a |
| P08 | the MEG arm's `clamp_prec_g(precision, sizeof(s) - 2)` | **K3**, X1, **Y1a Y1b** |
| P09 | `draw_graph()`'s writer clamp | **W1**, W4, D2 |
| P10 | `draw()`'s writer clamp | **W2**, W4, B5 |
| P11 | `kklex()`'s writer clamp (`eval_expr.y`) | **W3**, W4, W6 |
| P12 | `draw_cursor`'s clamp | **G1**, X1 |
| P13 | `draw_cursor_difference`'s clamp | **G2**, X1 |
| P14 | `draw_hcursor`'s `- 2` | **G3** |
| P15 | `draw_hcursor_difference`'s `- 2` | **G4** |
| P16 | `show_node_measures`' clamp | **G5** |
| P17 | `show_node_measures`' `prec = 2;` pin | **G5b** |
| P18 | `graph_marker_fmt`'s clamp | **G6**, X1, **X1c** |
| P19 | `graph_marker_fmt`'s `if(!dest \|\| destsize <= 0) return;` | **G6b** |
| P20 | `graph_marker_text_rec`'s `if(prec > 17) prec = 17;` | **G7**, B6 |
| P21 | the tooltip's `sx` clamp | **G8**, X1 |
| P22 | the tooltip's `sy` clamp | **G9**, X1 |
| P23 | the C14 second-defect fix (`gr->unity` → `gr->unitx` over the `sy` body) | **G10**, D3 D4 |
| P24 | `nd_view_set`'s clamp | **G11**, X1 |

Nothing was made vacuous by the tokeniser/preprocessor rewrite: X1 reddened at seven sites, Y1a
at four guards, Y1b at two, and the exemption row **X1c** reddened on P18, which is what proves
an exemption is itself a fence.

---

## 4. Comments and row names, audited for over-claim

### 4.1 ⚠ `W4`'s row name is measurably false

> `W4 no hand-written source assigns xctx->ev_precision straight from tclgetintvar`
> **`(i.e. there is no UNCLAMPED writer left)`**

The parenthetical is the claim, and **M1 refutes it on its own terms**: a source that assigns
`xctx->ev_precision` straight from `tclgetintvar`, spelled without spaces around `=`, leaves the
whole suite at `ALL PASS (58 checks)`. M6 refutes the general reading. Either the needle grows
into a token match or the parenthetical goes.

### 4.2 ⚠ `X1`'s row name is measurably false

> `X1 in every indirect-precision sprintf statement in the hand-written sources, …`

**M2 refutes it**: `sprintf (zb, "%.*g", xctx->ev_precision, zv);` is an indirect-precision
sprintf statement in a hand-written source, and X1 does not see it. This is the same over-claim
the file's own §"BY GLOB, NOT BY A HAND-KEPT LIST" comment says was fixed by widening the scope —
the scope is now right and the *statement finder* is what narrows it.

### 4.3 ⚠ "three times" is twice

Both the named-limits block and the section-Y header say gcc reports `'%.*g' directive writing
between 1 and 310 bytes into a region of size 80` **three times** under N1/N2/N3. Measured on the
landed tree, verbatim, and it is **two** — because the MEG arm now carries its own clamp and is
bounded, so only two of the three conversions are unbounded:

```
ep_n1.c:260:11: warning: ‘%.*g’ directive writing between 1 and 310 bytes into a region of size 80 [-Wformat-overflow=]
ep_n1.c:262:9:  warning: ‘%.*g’ directive writing between 1 and 310 bytes into a region of size 80 [-Wformat-overflow=]
count of -Wformat-overflow warning lines: 2
```
`C3-close.md`'s own Y1a proof line shows `{2 {…}}`, so the comment contradicts the receipt that
shipped with it. (It would have been three before the MEG clamp landed in the same round.)

### 4.4 ⚠ "H6 … reddens on that tree anyway" — H6 does not

Section-Z header:

> `H6 and every "exactly 71 significant digits" assertion in B1, B2, B3, B5, B7 and D2 redden on`
> `that tree anyway (measured as cycle S05, where raising the macro to 100 …)`

Measured **twice** — P05 (macro raised to 100) and the H5-under-an-undecidable-`#ifdef` decoy —
and **H6 stays green in both**, because H6 asserts `static char s[DTOA_ENG_BUFSIZE];`, which the
sabotage does not touch. The conclusion survives (B1 B2 B3 **B4** B5 B7 D2 all redden, one more
than the list names), but the sentence names the wrong row.

### 4.5 ⚠ "caught by NOTHING" at twelve call sites — false at eleven

Named limit #1:

> `At the other TWELVE call sites (two of the fourteen are dtoa_eng's own) gcc cannot see the`
> `clamp's return range across TUs, so the same shape there is caught by NOTHING in this file.`

Measured (§2.3): at the nine sprintf-argument sites the shape is caught by **X1**, at the three
writer sites by **W4**, and at exactly **one** — `show_node_measures` — by nothing. The first
half of the sentence (gcc cannot see across TUs) is true; the conclusion is not. The correction
makes the limit smaller and more useful, because it names the single exposed site.

### 4.6 `Y1a`'s row name over-claims exclusivity; one stale row reference

* `Y1a … so a clamp whose result never reaches the conversion (N1, N2, N3) is caught here and`
  `nowhere else in this file` — measured: **N2** also reddens `Z1`, **N3** also reddens `K2` and
  `K3`. Only **N1** is caught here and nowhere else, which is what the header's limit #1 says
  correctly.
* `src/editprop.c`, the MEG-arm comment: *"Fenced by rows K3 and **Y1** of
  tests/headless/test_ev_precision_bound_1606.tcl"* — there is no row `Y1`; they are `Y1a` and
  `Y1b`. Two mentions, one comment (`src/editprop.c` lines 255–256 at this tree: *"Fenced by rows
  K3 and Y1 of … -- Y1 asserts the compiler itself reports no …"*), and it is the only product
  comment in the batch that names a row by number — `src/xschem.h`'s new text names none.
* `tests/run_regression.tcl`: *"**One shape** is still out of reach of any static row"* — three
  more are (§2.2), and the one it names is one site wide, not twelve.
* `X1`'s comment: *"The thirteen existing sites are already fenced by their exact-text **G**
  rows"* — three of the thirteen are fenced by `K2`/`K3` (dtoa_eng's) and two by `G5b`, not by a
  `G<n>` per-site row. Loose rather than false.

### 4.7 Claims I re-measured and found TRUE

Independently, with my own C tokeniser (not the suite's — a separate state machine, asserted to
return a string of the same length as its input, over the same 43-file glob):

| claim | measured |
|---|---|
| the scanned set is `glob src/*.c *.h *.y *.l` minus 4 generated | **43 files** ✓ |
| **54** lines contain `//` over those 43 files | **54** ✓ |
| there is **no `//` line comment in code** anywhere in this tree | **0** at a code position ✓ |
| `'/'` char literal in **ELEVEN** files | 11 — actions.c callback.c eval_expr.y move.c paste.c psprint.c save.c scheduler.c token.c util.c xinit.c ✓ |
| `"// sch_path: %s\n"` in **TWO** netlisters | spectre_netlist.c, verilog_netlist.c ✓ |
| `/*` inside a literal in this tree | 0 in the 43 (parselabel.l is generated-input and self-closing) ✓ |
| **thirteen** indirect-precision sprintf statements, none bounded, at 34913077 | 11 with a literal `%.*` + show_node_measures' 2 through `fmt1`/`fmt2` = **13** ✓, and all 11 verified unclamped in `git show 34913077:` ✓ |
| `dtoa_eng` has **24** call sites: 13 `xctx->ev_precision`, 8 hardcoded `5`, 2 `prec`, 1 `engineering` | **24 / 13 / 8 / 2 / 1** ✓ exactly |
| **fourteen** `clamp_prec_g` call sites, smallest `avail` **78** | 14 ✓; avails 78, 80×5, 98×2, 100×5, 1024 ✓; `sx[80] sy[80] sdx[80] sdy[80]` and exactly **four** `graph_marker_fmt` callers, all `S(...)` of a char[80] ✓; `sx[100] sy[100]` in waves_callback ✓; `tmpstr[1024]` in show_node_measures ✓ |
| `hcases` 80 entries, `run_regression.tcl` parses, stamps clean | 80 ✓, `info complete` → 1 ✓, `ISSUE-STAMP: ok (0 problems)` ✓ |
| FLOOR 58 with the dev display, 53 without, one lowercase `skip:` | ✓ §6 |

---

## 5. Q6, verified independently

### 5.1 Warnings: landed vs 34913077, every file, both trees compiled from scratch

`git archive 34913077 src | tar -x` into scratch, its own `config.h` copy, its **own** generated
parsers regenerated there with `bison`/`flex`; the landed `src` copied beside it. Every `.c` in
both compiled with the build's own flags out of `Makefile.conf`
(`-pipe -O2 -I/usr/include/cairo … -I/usr/include/tcl8.6`). Nothing in the repo was touched.

```
--- base: 6 warnings, 0 errors
--- land: 6 warnings, 0 errors
base: actions.c:557 save.c:7082 token.c:954 token.c:955 token.c:956 util.c:222   (all -Wdiscarded-qualifiers)
land: actions.c:557 save.c:7087 token.c:954 token.c:955 token.c:956 util.c:222   (all -Wdiscarded-qualifiers)
=== normalised diff (line numbers stripped) ===
IDENTICAL WARNING SETS
=== -Wformat anywhere ===  base: 0   land: 0
```

So: **zero new warnings**, and the only difference is `save.c`'s pre-existing one moving five
lines with this batch's insertions. `C3-close.md`'s deviation 6 is confirmed exactly, including
that this tree was never warning-free.

### 5.2 The MEG clamp changes no output — driven, both signs

`xschem eval_expr {expr_eng(v*s)}` over 8 values chosen to land in the `'M'` arm
(1.2345678901234567e7, 1.0000000000000002e6, 999998999.9999999, 3.141592653589793e8,
2.220446049250313e7, 7.006492321624085e8, 1.7976931348623157e6, 6.283185307179586e8) × both
signs × 12 precisions (4 17 55 56 60 69 70 71 72 200 1000 4000) = **192 strings**. All 192 end in
`MEG` (the arm really was reached). Landed binary (cap 69) vs a rebuilt cap-71 binary:

```
$ diff meg_cap71.txt meg_landed.txt && echo IDENTICAL
IDENTICAL: all 192 strings byte-identical
max LEN over the 192: 58
```

And an independent arithmetic sweep (`megrange.c`, 1.6M `sprintf("%.*gMEG", p, v)` calls over
v ∈ (0.999999, 999.999] at p = 69, 71, 767, 4000, both signs, plus the eight boundary values):

```
MAX strlen = 59 bytes (60 with NUL) at precision 69, value -0.99999899999999997
```

which confirms the source comment's "pins the output near 59 characters at ANY precision" and
that the fix is arithmetic (69+11 = 80 = `sizeof(s)`; 71+11 = 82 > 80 was the violated bound),
not behaviour.

### 5.3 Trying to fool the diagnostics rows — Y1a holds

| attempt | tree then contains | result |
|---|---|---|
| **F1** clamp kept, then `precision = *(volatile int *)&precision;` — an opaque launder gcc cannot range-analyse, with K2/K3's text untouched | an unbounded precision reaching all three conversions | **`FAIL: Y1a`** |
| **F2** clamp kept, then `if(precision > 0) precision += 200;` | ditto, and it really aborts | **`FAIL: Y1a`, `FAIL: Y1b`** + B1 B2 B3 B4 B7 D1 D1b D2 D3 D4 (`rc=134/SIGABRT-the-1606-overflow`) |

Also verified: a failed compile cannot read as "clean" — `ycompile` asserts the `.o` appeared
(`missing`), and P03/P04/P07/P08 show both rows firing on the current tree, so neither is vacuous
today.

### 5.4 ⚠ BUT Y1a/Y1b HAVE NO ANTI-VACUITY ROW, AND THEIR FLAGS COME FROM A GENERATED FILE

`X1` has `X2`; `cs_pp` has `Z4`; `Y1a`/`Y1b` have nothing. They read `CFLAGS` out of
`Makefile.conf` — generated by `./configure`, gitignored, and accepting user flags. Measured on a
scratch copy of the N1-sabotaged `editprop.c` (the repo untouched):

```
level 2, NO -w  (what Y1a does today) : 2   -Wformat-overflow warnings
level 2 WITH -w prepended to CFLAGS   : 0
level 2 with -w appended after -Wformat-overflow=2 : 0
```

So a `-w` anywhere in that line silences **both** rows, and Y1a is the **only** fence for N1. Not
a defect in the tree; an unnamed vacuity path on the one row the named-limits block leans on.
Named here, not fixed. (`gcc` accepts `-Wformat-overflow=2` after `-w` and still says nothing —
so "the explicit flag wins" is not a defence.)

---

## 6. Gate-ready verdict

```
$ git status --porcelain
 M src/callback.c
 M src/draw.c
 M src/editprop.c
 M src/eval_expr.y
 M src/save.c
 M src/xinit.c
 M src/xschem.h
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/issue_1606_batch/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_ev_precision_bound_1606.tcl

$ git diff --stat
 src/callback.c           | 20 +++++++++--
 src/draw.c               | 94 ++++++++++++++++++++++++++++++++++++++++--------
 src/editprop.c           | 80 +++++++++++++++++++++++++++++++++++++++--
 src/eval_expr.y          | 10 +++++-
 src/save.c               | 15 +++++---
 src/xinit.c              |  6 +++-
 src/xschem.h             | 32 ++++++++++++++++-
 tests/run_regression.tcl | 51 +++++++++++++++++++++++++-
 8 files changed, 279 insertions(+), 29 deletions(-)

$ make -C src
make: Entering directory '/home/analog/dev/xschem-claude/src'
make: Nothing to be done for 'all'.
make: Leaving directory '/home/analog/dev/xschem-claude/src'
```

All nine tracked/untracked entries are exactly what the brief describes, and every source md5
matches the copies I took before the first cycle (`md5sum -c` clean).

**ARM 1 — headless, armed** (`tests/headless/run_suites.sh --nogui test_ev_precision_bound_1606`):
```
test home: throwaway /tmp/xschem-test-home.2162363.YExdhf (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (58 checks)
RESULT: 1/1 runs passed
```

**ARM 2 — display, armed** (`tests/headless/run_suites.sh test_ev_precision_bound_1606`):
```
test home: throwaway /tmp/xschem-test-home.2162749.lAAgRZ (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (58 checks)
RESULT: 1/1 runs passed
```

**ARM 3 — no dev display visible** (`XSCHEM_DEVDISPLAY_DIR` pointed READ-ONLY at an empty scratch
dir so `devdisplay.sh status` exits 1; `AUDIT_DISPLAY=none`; `:99` never started/stopped/viewed,
`xvfb: 3979908` before and after):
```
test home: throwaway /tmp/xschem-test-home.2163206.tLS2Tk (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: none (DISPLAY unset; GUI legs will self-skip)
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (53 checks)
         | skip: D1 D2 D3 D4 -- tests/headless/devdisplay.sh status does not report the persistent dev display alive, so the four draw.c cursor readouts and the callback.c measurement tooltip did not run; bring it up with tests/headless/devdisplay.sh start. G1-G4 and G8-G10 fence the same clamps statically on either arm
RESULT: 1/1 runs passed
```
One `skip:` line, lowercase, reason ends `…on either arm` — not a counted shape, does not start
`FATAL`.

**For the driver's T1 gate**: `hcases` goes 79 → **80** with this entry, so expect
**99 cases / 98 blocks** (not CLAUDE.md's current 98/97), `counted_failures=0`. `skips=` stays
**8** when `:99` is up — the arm exports `XSCHEM_DEVDISPLAY_DIR` to the real HOME
(`tests/headless/test_home.sh`, `test_home_arm`), so the D rows run under a throwaway HOME — and
becomes **9** on a box with no dev display, **10** with no `gcc`/`CFLAGS`. Gate in a clone at a
**short** path (the `test_op_annot` rule), and that gate is the driver's; I did not run T1.

**Would I gate this tree? Yes.** The shipped change is three files of arithmetic plus comments,
every one of its 24 guards has a row that reddens on its single removal, it is warning-identical
to 34913077, and the one behavioural risk in it (the MEG clamp) is proven to change no output
over 192 driven strings and 1.6M format calls. The six defects I found are all in test prose or
in the reach of two negative rows; none of them can hurt a user, and none of them is a reason to
hold the commit. What I would ask the driver to do **in this commit** is correct the four
sentences that are measurably false (§4.1–§4.5) — two of them are row NAMES, and shipping a row
whose name is refuted by an eleven-second cycle is the thing this batch has now done three times.

---

## 7. What I could NOT measure, and what I am carrying forward

Could not measure:

* **A full T1 gate** and the neighbour suites — the driver's, plus the short-path clone rule.
* **`-flto`**, so whether gcc could bound the precision across TUs is still unmeasured, exactly
  as the limits block says.
* **Win64 / `./configure --debug` (`-O0`, no `_FORTIFY_SOURCE`)** — no toolchain, and the
  `\004` byte in `graph_marker_fmt`'s provenance comment: inherited from `C2v-reprove.md` §8
  unchanged, not re-driven here.
* **`#define SP sprintf`** as a decoy: not driven; identical mechanism to M2.
* Whether `M1`/`M2`/`M6` would be caught by a suite that matched tokens — I did not write one.

Carried forward, named, not fixed:

1. **W4 and X1 are single-spelling matchers behind general row names** (M1, M2, M6). §2.2, §4.1,
   §4.2. Direction of failure: **false PASS on a sabotaged tree**, which is the dangerous one.
2. **The `if(0)` limit is one site wide** (`show_node_measures`), not twelve. §2.3, §4.5.
3. **Y1a/Y1b can be made vacuous by a `-w` in `Makefile.conf`'s CFLAGS**, and Y1a is N1's only
   fence. §5.4. No anti-vacuity row.
4. **Four false sentences and two loose ones**: "three times" (×2 places), "H6 … reddens",
   "caught by NOTHING", Y1a's "nowhere else" for N2/N3, `src/editprop.c`'s "row Y1", and
   `run_regression.tcl`'s "One shape". §4.
5. **Outside this issue's scope, not fixed**: the tree's six pre-existing
   `-Wdiscarded-qualifiers` warnings (`actions.c:557`, `util.c:222`, `save.c:7087`,
   `token.c:954/955/956`) — present at 34913077, not this batch's.
