# Receipt Cv — independent sabotage of Stage C

**Crew:** `sabotage:C` (independent; disbelieved `receipts/C-implement.md` and re-derived every
fence from scratch).
**Tree:** `34913077` + Stage C's working-tree edits, untouched at the end (§5).
**Suite under audit:** `tests/headless/test_ev_precision_bound_1606.tcl`, 43 checks.
**Method:** one guard removed at a time → `make -C src` → suite → restore with `cp` (never
`cp -a`, and the restore also `touch`es so `make` cannot skip the file) → `make -C src` →
**require 43/43 green again before the next sabotage**. 45 cycles, every one of them ending
green. The driver refuses to patch unless the target text occurs exactly once, so no sabotage
silently hit the wrong site.

Scratch driver: `$SCRATCH/sab.py`, verbose runner `$SCRATCH/run1606.sh` (arms the throwaway
HOME through `tests/headless/test_home.sh`, then runs the same
`--pipe -q --nolog --nogui --script` spelling `run_suites.sh` uses, but prints every row so a
verbatim `FAIL:` line is visible; its verdict was cross-checked against `run_suites.sh` on both
arms). Raw per-cycle JSON: `$SCRATCH/matrix.jsonl`; verbatim lines: `$SCRATCH/verbatim.txt`.

---

## 0. The headline

**Every one of the 20 product guards Stage C landed reddens at least one named row, with two
exceptions, and the suite has three defeatable static-row shapes.** Specifically:

1. **One landed guard is unfenced**: `clamp_prec_g`'s `if(avail <= 9) return 1;` — removing it
   leaves 43/43 green. The crew flagged this itself as its own addition, so it is an honest
   gap, not a hidden one.
2. **One comment the crew corrected on its own initiative is unfenced**: the
   `Xschem_ctx.ev_precision` field comment in `src/xschem.h`. Also self-declared.
3. **THREE decoy shapes defeat every `cstrip`-based static row** — `#ifdef <undefined>`,
   a `//` line comment, and `#if 0 && 1`. `cstrip` strips only `/* … */` and a line that is
   *exactly* `#if 0`. Demonstrated to full greenness on a tree where **C4's load-bearing
   `dtoa_eng` clamp is absent from the compiled binary** (`V3`/`V4`/`V5`), and again on a tree
   where **`draw_hcursor`'s `- 2` is really gone**, i.e. the clamp permits 91 digits into a
   buffer that can hold 89 (`V6`). This is the same class as issue 1607 row `V27` and issue
   1603 rows `S1`–`S4`, in two new shapes.
4. **Two shipped comments are false or unsupported** (§4): the suite's own D1 reachability
   sentence, and `graph_marker_fmt`'s `(measured on such a build: …)` Win64 attribution — the
   latter at the very site adjudication **C7** exists to keep honest.
5. **`W4`, `X1` and `X2` over-claim their scope** in their own row names: all three say
   "hand-written source(s)" but scan seven files out of ~40. A fifth writer or a new indirect
   site in `actions.c` is invisible to all three (`C1`, `C2`). Empirically no live site is
   missed today (§3.4), so this is a future blind spot, not a present hole.

Everything the crew reported about its own rows that I could re-derive, I re-derived and it
held — including the two "cannot be fenced behaviourally" deviations (`B6` vs `graph_marker_fmt`,
`B6` vs 17→18) and the `D1` fixture defect it caught and fixed.

---

## 1. The matrix — guard removed → row(s) that reddened, verbatim

Every row below is a separate `apply → build → run → restore → build → run-green` cycle. `rc`
is the suite's exit code under the sabotage. Rows marked **‡** reddened *in addition* to the
row the guard's own author named, which is information the receipt did not have.

### 1.1 The helper `clamp_prec_g` (`src/editprop.c`) and the macro (`src/xschem.h`)

| id | guard removed | rows reddened | rc |
|---|---|---|---|
| S01 | `if(prec <= 0) return prec;` | `H2` | 1 |
| S02 | the derived cap → literal (`cap = avail - 9;` → `cap = 71;`) | `H3` | 1 |
| S03 | `if((size_t)prec > cap) return (int)cap;` (clamp becomes a no-op) | `H4` + `B1 B2 B3 B4 B5 B7 D1 D1b D2` | 1 |
| **S04** | **`if(avail <= 9) return 1;`** | **NOTHING — 43/43 ALL PASS** | **0** |
| S05 | `#define DTOA_ENG_BUFSIZE 80` → `100` | `H5` + `B1 B2 B3 B4 B5 B7 D2` | 1 |
| S06 | `static char s[DTOA_ENG_BUFSIZE];` → `s[80]` | `H6` | 1 |
| L4 | `clamp_prec_g`'s definition line indented off column 0 | `H1` + `H2 H3 H4` | 1 |

```
S01  FAIL: H2 clamp_prec_g returns a prec <= 0 UNCHANGED -> {0} (exp {1}) : FAIL
S02  FAIL: H3 clamp_prec_g's cap is DERIVED as avail - 9, not written as a number -> {0} (exp {1}) : FAIL
S03  FAIL: H4 clamp_prec_g actually applies the cap -> {0} (exp {1}) : FAIL
S03  FAIL: B1 the issue's own reproducer SURVIVES at ev_precision 200 and prints exactly 71
     significant digits (DTOA_ENG_BUFSIZE - 9); this was *** buffer overflow detected ***,
     SIGABRT, rc 134 (rc=1 death=0 digits=0 r=<<absent>>) : FAIL
S05  FAIL: H5 src/xschem.h defines DTOA_ENG_BUFSIZE as 80 -> {0} (exp {1}) : FAIL
S05  FAIL: B1 ... (rc=0 death=0 digits=91 r=1.000000000000000007630473539575035660514778
     335511710750780086664439969510636494954611131549e+288T) : FAIL
S06  FAIL: H6 dtoa_eng's static buffer is sized by the macro, not by a literal 80 -> {0} (exp {1}) : FAIL
L4   FAIL: H1 int clamp_prec_g(int prec, size_t avail) is DEFINED in src/editprop.c (comments
     and #if 0 stripped, so its own doc comment does not count) (body={ZZNOFUNC}) : FAIL
```

`S05` is worth reading twice: raising `DTOA_ENG_BUFSIZE` produces a **self-consistent** tree
that does not abort — it just silently publishes a different ceiling (91 digits). `H5` plus the
"exactly 71 significant digits" assertions in `B1`–`B7`/`D2` are what catch it. That is the
single-source-of-the-number claim (C3) actually working.

`L4` shows `H1`/`K1` are not dead weight: `cfunc` returns `ZZNOFUNC` and `H1` says so, so
`H2`–`H4` cannot pass by finding nothing. No *product* sabotage reddens `H1` or `K1` (deleting
the definition is a link error), which is correct for an anti-vacuity guard.

### 1.2 `dtoa_eng`'s own clamp — adjudication C4

| id | guard removed | rows reddened | rc |
|---|---|---|---|
| S07 | `precision = clamp_prec_g(precision, sizeof(s));` | `K2` **only** | 1 |
| S08 | the same line **moved below** the suffix branch | `K3` | 1 |
| S09 | one of the three conversions (`"%.*g"` → `"%.17g"`) | `K3` `X1b` ‡`D3` | 1 |

```
S07  FAIL: K2 dtoa_eng clamps its own `precision` parameter against its own buffer -> {0} (exp {1}) : FAIL
S08  FAIL: K3 the three conversions the clamp protects are all still there, and the clamp
     precedes the suffix branch -> {0} (exp {1}) : FAIL
S09  FAIL: X1b the exemption list is used by exactly dtoa_eng's three arms, all three present
     -> {{sprintf(s, "%.*g%c", precision, i, suffix);} {sprintf(s, "%.*gMEG", precision, i);}}
     (exp {{sprintf(s, "%.*g", precision, i);} {sprintf(s, "%.*g%c", precision, i, suffix);}
     {sprintf(s, "%.*gMEG", precision, i);}}) : FAIL
```

**`K2` is the sole fence on C4's load-bearing edit** — confirmed, not assumed: under `S07`
`X1`, `X1b` and `K3` all stayed green (`X1` exempts the three arms by exact text, which is
unchanged, and `K3`'s position clause is vacuous on absence — §3.2). That is exactly why the
three decoy shapes in §3.1 matter so much at this site.

### 1.3 The three writers of `xctx->ev_precision`

| id | guard removed | rows reddened | rc |
|---|---|---|---|
| S10 | `draw_graph()`'s writer clamp | `W1` `W4` ‡`D2` | 1 |
| S11 | `draw()`'s writer clamp | `W2` `W4` ‡`B5` | 1 |
| S12 | `kklex()`'s writer clamp in **`src/eval_expr.y`** | `W3` `W4` `W6` | 1 |
| S13 | `xinit.c`'s corrected comment (reverted to the pre-fix text) | `W5` | 1 |

```
S10  FAIL: W1 draw_graph() clamps the ev_precision it copies out of Tcl -> {0} (exp {1}) : FAIL
S10  FAIL: W4 no hand-written source assigns xctx->ev_precision straight from tclgetintvar
     (i.e. there is no UNCLAMPED writer left) -> {1 {{draw.c x1}}} (exp {0 {}}) : FAIL
S10  FAIL: D2 the callback.c measurement tooltip SURVIVES at ev_precision 200 on the dev
     display and its y readout carries exactly 71 significant digits; before the fix this
     aborted at 93 (and at 73 with only one axis unit set) (rc=0 death=0 digits=91 mt=y=5.011
     093567794598300648118032773251320800427090181663341216700173217598816023347921379433076
     e+287T | x=4.4389642416769425327900325238196751792725536223116478140582330524921417236
     328125e-13T) : FAIL
S11  FAIL: W2 draw() clamps the ev_precision it copies out of Tcl -> {0} (exp {1}) : FAIL
S11  FAIL: B5 reading the cursor-B annotation (save.c nd_view_set) SURVIVES at ev_precision 200
     and prints exactly 71 significant digits (rc=0 death=0 digits=91 v=1.0000000000000000525
     04760255204420248704468581108159154915854115511802457988908195786371375e+299) : FAIL
S12  FAIL: W3 kklex() in src/eval_expr.y clamps the ev_precision it copies out of Tcl -> {0} (exp {1}) : FAIL
S12  FAIL: W6 a GENERATED src/eval_expr.c, if one exists, carries kklex()'s clamp (a stale one
     would mean the binary under test predates the fix) -> {0} (exp {1}) : FAIL
S13  FAIL: W5 xinit.c's comment on the initial 4 now names kklex() too, so the writer list a
     reader trusts is complete -> {0} (exp {1}) : FAIL
```

Each writer clamp is doubly fenced (its own row **and** `W4`), which is better than the receipt
claimed. And the two "defence in depth is unfenceable behaviourally" worries are narrower than
stated: `D2` and `B5` *do* redden on a single writer-clamp removal, because the writer cap (71)
is tighter than the use-site cap (91) and those two rows assert the digit **count**, not merely
survival.

### 1.4 The eleven per-site clamps, the `- 2`, and the second defect

| id | guard removed | rows reddened | rc |
|---|---|---|---|
| S15 | `draw_cursor`'s clamp | `G1` `X1` | 1 |
| S16 | `draw_cursor_difference`'s clamp | `G2` `X1` | 1 |
| S17 | `draw_hcursor`'s clamp (whole) | `G3` `X1` | 1 |
| **S18** | **only the `- 2`** in `draw_hcursor` | `G3` | 1 |
| S19 | `draw_hcursor_difference`'s clamp (whole) | `G4` `X1` | 1 |
| **S20** | **only the `- 2`** in `draw_hcursor_difference` | `G4` | 1 |
| S21 | `show_node_measures`'s clamped local `prec` | `G5` **only** | 1 |
| S22 | `prec = 2;` (the only bound on the unbounded `%.*e` arm) | `G5b` | 1 |
| S23 | `graph_marker_fmt`'s `(size_t)destsize` clamp | `G6` `X1` | 1 |
| S24 | `graph_marker_fmt`'s `if(!dest \|\| destsize <= 0) return;` | `G6b` | 1 |
| S25 | `graph_marker_text_rec`'s `if(prec > 17) prec = 17;` | `G7` ‡`B6` | 1 |
| S26 | the tooltip's `sx` clamp | `G8` `X1` | 1 |
| S27 | the tooltip's `sy` clamp | `G9` `X1` | 1 |
| S28 | **the C14 wrong-unit fix** (`gr->unity` → `gr->unitx` over the `sy` body) | `G10` `D3` `D4` | 1 |
| S29 | `nd_view_set`'s clamp | `G11` `X1` | 1 |

```
S18  FAIL: G3 draw_hcursor's " %.*g%c " readout clamps against S(tmpstr) - 2, paying for the
     two literal spaces -> {0} (exp {1}) : FAIL
S20  FAIL: G4 draw_hcursor_difference's " %.*g%c " readout clamps against S(tmpstr) - 2, paying
     for the two literal spaces -> {0} (exp {1}) : FAIL
S21  FAIL: G5 show_node_measures (NOT draw_graph_variables) clamps the local `prec` it prints
     its 1024-byte tmpstr with -> {0} (exp {1}) : FAIL
S22  FAIL: G5b show_node_measures still formats through the fmt1/fmt2 VARIABLES, and its %e arm
     is still pinned at prec = 2 -> {0} (exp {1}) : FAIL
S23  FAIL: G6 graph_marker_fmt clamps against its own destsize parameter -> {0} (exp {1}) : FAIL
S23  FAIL: X1 ... -> {1 {{draw.c: sprintf(dest, "%.*g%c", prec, unit * v, suffix);}}} (exp {0 {}}) : FAIL
S24  FAIL: G6b graph_marker_fmt refuses a NULL dest or a destsize <= 0 instead of casting it to
     a huge size_t -> {0} (exp {1}) : FAIL
S25  FAIL: B6 the graph-marker callout SURVIVES at ev_precision 200 and shows 17 significant
     digits -- the DISPLAY cap in graph_marker_text_rec, which is the only thing between
     ev_precision and graph_marker_fmt's 80-byte buffers (rc=0 death=0 n=1 digits=71
     mx=9.9999999999999997988664762925561536725284350612952266601496376097202301e-13T ...) : FAIL
S28  FAIL: G10 (second defect) the tooltip's y branch tests gr->unity, and the gr->unitx guard
     over a gr->unity body is gone -> {0} (exp {1}) : FAIL
S28  FAIL: D3 (second defect) ... (rc=0 death=0 mt=y=5.011 | x=0.4439) : FAIL
S28  FAIL: D4 (second defect) ... (rc=0 death=0 mt=y=5.011e-06 | x=4.439e-13T) : FAIL
```

Three independent confirmations of the crew's own reported figures fall out of this:

* **`S21` confirms C9's trap is real.** `X1` stayed **green** when `show_node_measures`'s clamp
  was deleted, because its formats are the `char *` variables `fmt1`/`fmt2` and the statement
  text carries no `%.*`. `G5` is that site's **only** fence, exactly as the crew said.
* **`S23` confirms deviation 1.** Removing `graph_marker_fmt`'s clamp leaves `B6` green;
  `G6` + `X1` are its fences. The crew was right to refuse to let `B6` claim that guard.
* **`S28` reproduces the C14 before/after byte for byte**: `y=5.011` (was) vs `y=5.011e-12T`
  (is) with `unity=T` only, and `y=5.011e-06` vs `y=5.011u` with `unitx=T` only — the same
  strings the receipt's table reports. The user-visible half of the wrong-unit fix is real and
  is fenced twice (statically by `G10`, behaviourally by `D3`/`D4`).

### 1.5 The sweep rows, and the premise the whole fencing plan rests on

| id | change | rows reddened | rc |
|---|---|---|---|
| S30 | a **new** unclamped `sprintf(b, "%.*g", p, v);` added to `save.c` | `X1` | 1 |
| S31 | the same new site in `token.c` (outside the four) | `X1` `X2` | 1 |
| P1 | **two guards on purpose**: `kklex`'s writer clamp **and** `dtoa_eng`'s clamp | `K2 W3 W4 W6 B1 B2 B3 B7` | 1 |
| L3 | **two guards on purpose**: `draw_graph`'s writer clamp **and** `draw_cursor`'s clamp | `W1 W4 G1 X1 D1 D1b D2` | 1 |
| L1 | `if(prec > 17)` → `if(prec > 18)` | `G7` only (`B6` green) | 1 |
| L2b | `draw_cursor`'s `tmpstr` → 16 bytes **and** its clamp removed | `G1 X1 D1 D1b` | 1 |

```
S31  FAIL: X2 and the files carrying one are exactly the four this suite fences by name (a new
     file here is an unfenced site) -> {callback.c draw.c editprop.c save.c token.c}
     (exp {callback.c draw.c editprop.c save.c}) : FAIL
L3   FAIL: D1 a real graph draw with both cursors and both axis units SURVIVES at ev_precision
     200 on the dev display -- the four draw.c cursor readouts (draw_cursor,
     draw_cursor_difference, draw_hcursor, draw_hcursor_difference), none of which is reached
     headless (rc=1 death=0 hasx=<<absent>> done=0 flags=<<absent>>) : FAIL
```

**`P1` settles the premise STAGE_C's C12 is built on, independently.** With both clamps on the
`eval_expr` path gone, the behavioural reproducer really does come back, and each clamp alone
really does keep it green (`S07` and `S12` above). I also drove the abort directly on that
doubly-sabotaged binary rather than inferring it:

```
*** buffer overflow detected ***: terminated
/bin/bash: line 18: 1994219 Aborted   timeout 60 env -u DISPLAY HOME=… src/xschem --nogui --pipe -q --script repro.tcl
RC=134
```

**`L1` confirms the receipt's second deviation**: raising the display cap 17→18 does not redden
`B6` (`%g` strips the trailing zero), so `G7` is the fence on the exact value. The crew did not
overstate that row.

**`L3` and `L2b` confirm `D1` is no longer vacuous** — which is the crew's own self-caught
defect, and the thing I most expected to still be broken. It reddens on the very pair it claims
to fence, and on a forced-abort probe.

**`D1b` is non-vacuous too**, reddened the only way it can be (a fixture change — dropping the
`hcursor2_y` line from `D1FIX`), giving the crew's reported figure exactly:

```
FAIL: D1b ... and the fixture really did arm both cursors AND both hcursors (graph_flags
2|4|128|256), so D1 exercises all four readouts -> {134} (exp {390}) : FAIL
```

### 1.6 `W6` and the generated parser — the two cases the brief asked for

Neither needs a rebuild (the binary does not change), so both were run against the current
binary and then the generated file was regenerated from the `.y`.

* **`src/eval_expr.c` deleted** (the fresh-clone case): `RESULT: ALL PASS (43 checks)`,
  `W6` green **and `W3` green** — so `W3` really greps `src/eval_expr.y`, not the generated
  `.c`. This is the case that would have read "clean for the wrong reason".
* **`src/eval_expr.c` stale** (clamp stripped, mtime newer than the `.y`, binary untouched):
  ```
  FAIL: W6 a GENERATED src/eval_expr.c, if one exists, carries kklex()'s clamp (a stale one
  would mean the binary under test predates the fix) -> {0} (exp {1}) : FAIL
  ```
  Regenerated afterwards and byte-identical to the original (`30d10f17954bc1e21d9af72946dcdb5c`).

### 1.7 The no-dev-display arm

Driven read-only with `XSCHEM_DEVDISPLAY_DIR` pointed at an empty scratch dir, so
`devdisplay.sh status` reports `state: foreign` and exits 1. **`:99` was never touched** (no
`start`/`stop`/`view`).

```
skip: D1 D2 D3 D4 -- tests/headless/devdisplay.sh status does not report the persistent dev
display alive, so the four draw.c cursor readouts and the callback.c measurement tooltip did
not run; bring it up with tests/headless/devdisplay.sh start. G1-G4 and G8-G10 fence the same
clamps statically on either arm
RESULT: ALL PASS (38 checks)
EXITCODE=0
```

`/usr/bin/grep -c '^skip: '` = **1**. Exactly one lowercase `skip:` line, 38 checks, exit 0, the
reason text ends in `…on either arm` (not `FAIL`/`GOLD?`/`RESULT?`) and does not start with
`FATAL`. The registration comment's "38 checks / one skip" claim is **true**, and
`cmd_status`'s trailing `[ "$state" = alive ]` is what makes the self-skip sound.

---

## 2. Every guard whose removal reddened NOTHING

This is the section the stage exists for. Two, both of them declared by the crew, and neither
of them a safety guard on a live path.

### 2.1 `clamp_prec_g`'s `if(avail <= 9) return 1;` — **UNFENCED**

```
S04  RESULT: ALL PASS (43 checks)     EXITCODE=0
```

Deleted, rebuilt, 43/43. No row asserts it. The crew named it explicitly ("The
`if(avail <= 9) return 1;` line is MINE and not in C2's text"), and its own comment says no
caller passes a buffer that small today — which §3.4's survey confirms (the smallest `avail` in
the tree is 80). So the honest description is: **a guard against a future caller, with no row,
in a helper whose other three lines each have one.**

⚠ And one thing neither the brief nor the receipt says about it: **the floor of `1` is not
itself safe.** `clamp_prec_g(200, 8)` returns `1`, and `"%.*g%c"` at precision 1 on a
three-digit-exponent value is `1e+287T` — 7 chars + NUL = 8 bytes, i.e. **exactly** an 8-byte
buffer, and 9 bytes with a sign. So for `avail` in 2..9 the clamp can still permit an overflow;
it merely stops the `size_t` underflow that would disable the clamp entirely. Unreachable
today. Named, not fixed.

### 2.2 The `Xschem_ctx.ev_precision` field comment in `src/xschem.h` — **UNFENCED**

```
S32  RESULT: ALL PASS (43 checks)     EXITCODE=0
```

Reverted to the pre-fix incomplete writer list (`draw() and draw_graph()` only) and nothing
reddened. The crew stated this ("W5 fences the xinit.c half only — the struct half is prose
with no distinctive token worth a row"). I disagree with the reasoning rather than the
disclosure: `W5` fences `xinit.c` with a regexp over the **raw** file precisely because "the
comment IS the artefact", and the same argument applies verbatim to the struct comment, which is
the one a reader hits first — the crew says so itself. A second `regexp` over the raw
`xschem.h` for `kklex` near `int ev_precision;` costs one row. **Not fixed** (no fixes this
stage).

### 2.3 Everything else reddened

For completeness: 41 of the 43 rows were reddened by at least one cycle above. The two that
were not — `H1` and `K1` — are `cfunc`-found-nothing guards for the rows beneath them, and
`L4` shows they work (`body={ZZNOFUNC}`). No product sabotage can redden them because deleting
either function is a link error.

---

## 3. Vacuous rows — rows that pass on a tree where the thing they assert is absent

### 3.1 THREE decoy shapes defeat `cstrip`, and the third is safety-relevant

`cstrip` = `strip_if0 [strip_block_comments …]`. `strip_block_comments` handles only `/* … */`;
`strip_if0` matches only `^[ \t]*#[ \t]*if[ \t]+0[ \t]*$`. So anything else that the compiler
throws away, the stripper keeps. Target: **`K2`**, chosen because `S07` proved it is the *only*
fence on adjudication C4's load-bearing clamp. In each case the real
`precision = clamp_prec_g(precision, sizeof(s));` was **deleted from `dtoa_eng`** and the binary
rebuilt without it.

| id | decoy holding `K2`'s asserted text | verdict |
|---|---|---|
| V1 | `/* precision = clamp_prec_g(precision, sizeof(s)); */` | `FAIL: K2 … -> {0} (exp {1}) : FAIL` — **stripper works** |
| V2 | `#if 0` / line / `#endif` | `FAIL: K2 … -> {0} (exp {1}) : FAIL` — **stripper works** |
| **V3** | `#ifdef XSCHEM_NEVER` / line / `#endif` | **`RESULT: ALL PASS (43 checks)` — DEFEATED** |
| **V4** | `  // precision = clamp_prec_g(precision, sizeof(s));` | **`RESULT: ALL PASS (43 checks)` — DEFEATED** |
| **V5** | `#if 0 && 1` / line / `#endif` | **`RESULT: ALL PASS (43 checks)` — DEFEATED** |

All three defeats compile, link and produce a binary with **no clamp inside `dtoa_eng`**, and
the suite reports 43/43. (`C89` is the house style but nothing on the command line rejects
`//`: the build is plain `gcc -pipe -O2 …`, no `-ansi`, no `-pedantic`, no `-Wall`.)

**And it is not only a hygiene point.** `V6` does the same trick where the missing bytes matter:

```
V6   draw_hcursor's clamp left in place but its `- 2` REALLY REMOVED, and G3's asserted
     statement parked in a `//` comment one line below
     RESULT: ALL PASS (43 checks)     EXITCODE=0
```

On that tree `draw_hcursor` permits a 91-significant-digit conversion plus two literal spaces
into a 100-byte buffer — the exact two bytes adjudication **C11** exists to pay for — and the
suite is green. `X1` cannot help here, because the live statement still contains a
`clamp_prec_g`; `G3` is the only fence and `G3` was satisfied by a comment.

**Which rows share the blind spot?** Every row that asserts a *positive* text match inside
`cstrip`ped source: `H2 H3 H4 H5 H6 K2 K3 W1 W2 W3 G1 G2 G3 G4 G5 G5b G6 G6b G7 G8 G9 G10 G11`
and `X1b` — 24 of the 43. The rows that are **immune** are the negative/enumerating ones
(`W4`, `X1`, `X2` — they hunt for a *bad* statement, which a decoy cannot suppress), the raw-file
one (`W5`), and the behavioural ones. Fixing this is three lines in `cstrip` (strip `//` to
end-of-line outside string literals; treat any `#if`/`#ifdef`/`#ifndef` whose expression is not
satisfiable-by-inspection as dead, or at least depth-strip `#if 0`-equivalents and
`#ifdef <name never defined in the tree>`), or one line per row (require the match to appear
**exactly once** and at a statement position). **Not fixed.**

### 3.2 `K3`'s position clause is vacuous whenever the clamp is absent

```tcl
&& [string first {clamp_prec_g(precision, sizeof(s));} $F_DTOA]
   < [string first {if (absi == 0.0)} $F_DTOA]
```

`string first` returns `-1` when the needle is missing, and `-1 < N` is true. Measured: under
`S07` (clamp deleted outright) **`K3` passed** — only `K2` reddened. So `K3` asserts "the clamp
precedes the branch" only on trees where the clamp exists, and it depends entirely on `K2` to
establish that. Combined with §3.1 that is a chain: defeat `K2` with a `//` comment and `K3`
silently stops asserting anything at all. One `>= 0 &&` in front of the comparison closes it.
**Not fixed.**

### 3.3 The `death` half of every behavioural row never fires for this defect class

Each behavioural row asserts `rc == 0 && !death`, where `death` is a column-0
`FATAL: signal` marker. The 1606 defect is a glibc `_FORTIFY_SOURCE` `SIGABRT`, and — as the
batch already settled — `main.c`'s `sig_handler` does not trap `SIGABRT`, so **no `FATAL:` line
is ever printed**. Every reddened behavioural row above reports `death=0`, including the ones
where the child really did abort with rc 134. The `death` clause is therefore correct but
permanently inert for this issue; it is insurance against a *different* death, not a second
check on this one. Worth stating so nobody reads `death=0` as "the child was fine".

Related, and smaller: the suite's `child` proc collapses any failure to `set rc 1`, so a row
cannot distinguish rc 134 (the defect) from rc 1 (a Tcl error in the fixture) or rc 124 (the
`timeout 90`). All three would print the same `(rc=1 …)` detail. Naming it, not fixing it —
the digit-count assertions carry the real signal.

### 3.4 `W4`, `X1` and `X2` claim the tree and scan seven files

All three iterate the same list: `callback.c draw.c editprop.c save.c token.c xinit.c
eval_expr.y`. `src/` has ~40 hand-written `.c` files.

```
C1   a FIFTH unclamped writer  `xctx->ev_precision = tclgetintvar("ev_precision");`  added to
     src/actions.c            ->  RESULT: ALL PASS (43 checks)   W4 GREEN
C2   a NEW unclamped indirect site  `sprintf(b, "%.*g%c", p, v, 84);`  added to src/actions.c
                              ->  RESULT: ALL PASS (43 checks)   X1 AND X2 GREEN
```

`W4`'s name says *"no hand-written source assigns…"*; `X1`'s says *"every indirect-precision
sprintf statement in the hand-written C sources"*; `X2`'s says *"the files carrying one are
exactly the four"*. On the evidence those three sentences are over-claims of a seven-file scan.

**But no live site is missed today.** I swept every hand-written source myself:

```
$ for f in src/*.c src/*.h src/*.y src/*.l ; do … /usr/bin/grep -c '%[-0-9]*\.\*' ; done
callback.c: 3   draw.c: 13   editprop.c: 5   save.c: 4   xschem.h: 2   (xschem.h = comments only)
```

and the `sprintf` statements carrying `%.*` are exactly the 11 explicit ones plus
`show_node_measures`'s two variable-format ones = **13**, in **four** files — which is what the
batch settled and what `X2` expects. So this is a future blind spot (a new site in one of the
other ~33 files), not a present hole. A `glob`-driven file list would close it at the cost of
scanning `parselabel.c`/`expandlabel.c`/`eval_expr.c`, which is presumably why it was not done.
**Not fixed.**

---

## 4. Comments checked for truth — two are wrong

### 4.1 ⚠ FALSE, in the suite file: `D1FIX`'s reachability sentence

`tests/headless/test_ev_precision_bound_1606.tcl`, in `D1FIX`'s comment:

> `## exact expansion is ~289 digits. VERIFIED by reachability probe: shrinking ONLY`
> `## draw_cursor's tmpstr to 16 bytes aborts this fixture, so the site is live.`

**Measured false on the shipped tree.** `L2` did exactly that — `char tmpstr[100]` →
`char tmpstr[16]` in `draw_cursor`, every guard left in place, rebuilt:

```
L2   RESULT: ALL PASS (43 checks)     EXITCODE=0
```

It cannot abort, and the reason is the fix itself: the clamp's `avail` is `S(tmpstr)`, so
shrinking the buffer shrinks the cap with it (16 → cap 7), and precision 7 fits. The probe only
aborts on a tree that has **also** lost `draw_cursor`'s clamp:

```
L2b  tmpstr[16] AND draw_cursor's clamp removed
     FAIL: D1 … (rc=1 death=0 hasx=<<absent>> done=0 flags=<<absent>>) : FAIL
```

The *conclusion* ("the site is live") is correct — `L2b` and `L3` both prove it — so this is a
false **evidence** sentence, not a false claim about the product. The receipt's own version
(§6.3, "I proved the site was reachable by shrinking only `draw_cursor`'s `tmpstr` to 16 bytes")
is defensible in context, because that paragraph is describing work done *inside* the `d1`
sabotage where the clamp was already gone; the suite comment drops that context and a reader who
tries it on the committed tree reproduces nothing. **This is the third batch in a row where a
shipped comment quoted a probe that does not reproduce as written.** Not fixed; recommend the
sentence become "shrinking `draw_cursor`'s `tmpstr` to 16 bytes **with its clamp removed**".

### 4.2 ⚠ UNSUPPORTED, in `graph_marker_fmt`: a Win64 measurement nobody made

`src/draw.c`, `graph_marker_fmt`:

> `* XSchemWin/ exists -- there is ONE argument area, and there the int prec`
> `* really is consumed as the double (measured on such a build:`
> `* "700.0000000000001136868377216160297393798828125" and a swallowed suffix).`

The crew's own receipt, §9 "What I could NOT measure": *"**The Win64 ABI half of C7.** Taken
from STAGE_C's adjudication; no Windows build exists here."* And the pre-fix comment at
`34913077` said only *"(measured: "700.0000…" and a swallowed suffix)"* — **no platform at
all**. So the edit takes an unattributed legacy figure and upgrades it into a claimed Win64
measurement, which is precisely the move adjudications C5/C7 exist to forbid, at the very site
C7 is about. The mechanism sentence is fine and I verified it in `src/util.c`
(`i = va_arg(args, double)` after `strncpy(nfmt, fmt, l)` copies `"%.*g"` verbatim, so libc then
looks for a precision argument that was never passed — which on SysV leaves the double intact
and eats the suffix, and on Win64's single argument area would consume `prec` as the double).
Only the attribution is unsupported. The fix is one word: *"and there the int `prec` would be
consumed as the double — derived from the ABI, not driven; the figure
`700.0000000000001136868377216160297393798828125` comes from this comment's earlier revision,
which did not name its platform."* **Not fixed.**

### 4.3 Verified TRUE

| claim | how checked | result |
|---|---|---|
| **C5** `_FORTIFY_SOURCE 3` by default on this build | `gcc -pipe -O2 -dM -E -x c /dev/null` | `#define _FORTIFY_SOURCE 3` ✓ |
| **C5** `./configure --debug` appends `-O0` (so no FORTIFY) | `scconfig/hooks.c:58` | `" --debug   build full debug version (-g -O0)\n"` ✓ |
| **C5** the read lands in `xctx->tok_size`, used as a `memcpy` length at **five** `token.c` sites | `/usr/bin/grep -n 'len = xctx->tok_size;'` + the next 5 lines of each | `:6672 :6776 :6880 :6949 :7085`, each followed by `memcpy(result+result_pos, valstr, len+1);` — five, exactly as written ✓ |
| **C5** is labelled derived, not measured | the comment says *"Derived from the code and the build flags, not driven"* | ✓ honest |
| **C6** `1.111000061035156` gone | `/usr/bin/grep -rn '1.111000061035156' src/` | no hits anywhere ✓ |
| **C6** *"100 bytes is ample for one %g"* gone | reading the new `nd_view_set` comment | gone; replaced by *"the 100 bytes are NOT ample"* ✓ |
| **C7** the ABI is named | reading the comment | *"On x86-64 SysV the integer and SSE argument areas are separate"* ✓ (only the Win64 parenthetical is the problem, §4.2) |
| **C8** nothing says `draw_graph_variables` does not exist | `/usr/bin/grep -rn 'does not exist' src/draw.c` | four hits, none about that symbol ✓ |
| **C8** `draw_graph_variables` exists, owns `char tmpstr[1024]`, has **no** indirect conversion | `src/draw.c:5100`, called from `:9238`; body grep for `%.*` = 0 | ✓ all three |
| **C10** `%.*g` can never exceed 774 chars | a standalone C sweep over 10 extreme doubles × 10 precisions up to 4000 | max **773**; `%.*e` at 4000 = **4006** chars ✓ (the bound holds and the "wrong arm" warning is right) |
| **C11** `get_unit()` never returns ≤ 0, so the two `_difference` sites cannot carry a sign | `static double get_unit()`, `src/draw.c:2886` | returns only `1.0` or `1e±3…15` ✓ |
| **C3** no literal 71 in C **code** | `/usr/bin/grep -n '\b71\b' src/*.c src/*.h src/*.y` | 7 hits, **all inside comments** (2 `draw.c`, 4 `xschem.h`, 1 `eval_expr.y`) ✓ for the substantive claim — but the receipt's parenthetical *"only two draw.c comments and the generated parselabel.c tables"* undercounts its own new comments by five. Receipt inaccuracy, not a code defect. |
| carried-forward 1 | `src/util.c` `char nfmt[50], nstr[50];` at `:686 :708 :731`, `nlen = sprintf(nstr, nfmt, i);` at `:697 :720 :746`, bound test after the write | ✓ three arms, exactly as described |
| carried-forward 4 | `src/xschem.tcl` `if {$n < 1 \|\| $n > 71}`, the `alert_` text *"from 1 to 71"*, and `input_line "Enter precision (int 1-71):"` | ✓ all three literals still there |
| registration: `hcases` 79 → 80 | `awk '/set hcases \[list/,/\]$/' … \| /usr/bin/grep -o '"[^"]*"' \| wc -l` | **80** ✓ |
| `run_regression.tcl` still parses | `info complete` on the whole file | `1` ✓ |

I did **not** re-derive the settled Stage A/B measurements (the 13 sites, the 24 `dtoa_eng`
callers, the 56–59-character `MEG` pin, the `'m'` → `\004` SysV measurement, the file-borne
`.sch`/`.sym` doors beyond what `B7` drives). I did not build `--debug`, and I did not build for
Win64 — nothing here can.

---

## 5. Rebuild discipline, and the tree at the end

**Every figure in this receipt came from a binary rebuilt for the exact tree that produced it.**
The driver's per-cycle record (`$SCRATCH/matrix.jsonl`) carries, for all 45 cycles:

* `build_rc: 0` after the patch — no figure was taken from a tree that failed to compile, and
  every patch was refused unless its target text occurred **exactly once**;
* `restore_md5_mismatch: []` — after each restore, the file's md5 equals the pristine copy's;
* `restore_build_rc: 0` and `restored_green: true` — the tree was rebuilt after the restore and
  the suite was re-run to 43/43 **before the next sabotage began**. The driver aborts the whole
  run on the first non-green restore. It never aborted.

Restores use `shutil.copyfile` (= `cp`, content only) **plus an explicit `utime(…, None)`**, so
the restored file's mtime is *newer* than the sabotaged object file and `make` can never skip
it. That is the `cp -a` trap the brief names, closed twice over. The two experiments that needed
no rebuild (`W6` absent / `W6` stale, §1.6) are the only figures taken without a build, and
neither changes the binary — the generated `src/eval_expr.c` was regenerated afterwards and is
byte-identical (`30d10f17954bc1e21d9af72946dcdb5c`).

Final state:

```
$ make -C src
make: Nothing to be done for 'all'.
$ ls -l --time-style=+%H:%M:%S src/xschem src/draw.c src/editprop.c
-rw-r--r-- 465949 02:21:19 src/draw.c
-rw-r--r--  75283 02:16:16 src/editprop.c
-rwxr-xr-x 1697408 02:21:21 src/xschem      <- newer than every source
```

md5 of every file I touched, against the values recorded **before the first sabotage**:

```
61a134eb5db1cd22d4a6926f135e4373  src/callback.c
568615ed48f98affcb8561489f197c9a  src/draw.c
b501bab4ff920c973ab656b70210e51c  src/editprop.c
061fb6d7cb99d7a61a580b1193101049  src/eval_expr.y
496af5d1093e465bdf66b615fec44779  src/save.c
e3352c38d3767b0282841d12d83d2b34  src/xinit.c
92f8526e87041409bf35c56323662f54  src/xschem.h
2d5d638b7f8a57d854cd151afac30716  tests/run_regression.tcl
8750d70f461ed8e4704f1d20ce4c9da4  tests/headless/test_ev_precision_bound_1606.tcl
```

All nine match. `src/token.c`, `src/actions.c` and `src/util.c` (touched only by the coverage
probes) `cmp` identical to their pristine copies and are absent from `git status`.

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
 src/draw.c               | 88 +++++++++++++++++++++++++++++++++++++++---------
 src/editprop.c           | 37 +++++++++++++++++++-
 src/eval_expr.y          | 10 +++++-
 src/save.c               | 15 ++++++---
 src/xinit.c              |  6 +++-
 src/xschem.h             | 27 ++++++++++++++-
 tests/run_regression.tcl | 29 +++++++++++++++-
 8 files changed, 204 insertions(+), 28 deletions(-)
```

Byte-for-byte the state the implementation crew left, plus this receipt. Nothing committed; the
owed ledger untouched; `~/dev/xschem-op-wcard` never opened; `:99` never started, stopped or
viewed; no `/tmp/xschem_emergencysave_*` removed; all scratch under the session scratchpad.

Both armed arms, on that final binary:

```
$ tests/headless/run_suites.sh --nogui test_ev_precision_bound_1606
test home: throwaway /tmp/xschem-test-home.1999201.FZYtMv (your HOME is untouched; …)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (43 checks)
RESULT: 1/1 runs passed

$ tests/headless/run_suites.sh test_ev_precision_bound_1606
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (43 checks)
RESULT: 1/1 runs passed
```

`devdisplay.sh status`: `:99`, `alive`, `1920x1080x24`, `openbox (Openbox)`, `xvfb 3979908`.

---

## 6. What I could not measure

* **The `--debug` (`-O0`, no FORTIFY) build** and therefore the out-of-bounds *read* into
  `xctx->tok_size`. I verified the three checkable halves of C5 (FORTIFY is on here, `--debug`
  is `-g -O0`, five `memcpy` sites at the named lines) but did not build it, which is what the
  comment itself says.
* **The Win64 ABI.** No Windows toolchain here; that is the whole point of §4.2.
* **The neighbour suites** (`test_wave_markers`, `test_op_annot`, `test_annot_hier_0911`,
  `test_home_isolation`) and a **full T1 gate**. Those are Stage D's, and re-running them would
  not have been independent evidence of anything I was asked to check. ⚠ For the driver: the
  receipt reports `test_wave_markers` as `PASS … (437 checks)` on the dev-display arm, which is
  the opposite of `CLAUDE.md`'s standing note that it `TIMEOUT`s when `run_suites.sh` attaches
  to `:99` (issue 1488). I did not adjudicate that; it wants one look at the gate.
* **What the four `draw.c` cursor readouts actually formatted.** Still no read-back seam, so
  `D1` asserts survival and `D1b` asserts the fixture armed the paths. I confirmed both are
  non-vacuous (`L3`, `L2b`, and the `D1FIX` fixture edit) but cannot assert the strings either.
* **The six other `token.c` `dtoa_eng` sites.** `B4` drives one; `K2` fences the shared callee.

## 7. Carried forward — named, not fixed

1. **`cstrip`'s three blind spots** (`//`, `#ifdef <undefined>`, `#if 0 && 1`) and the 24 rows
   that rely on it. §3.1. This is the one I would fix first: it is a one-proc change that
   restores the guarantee the brief asks for, and two earlier batches were saved by exactly this
   class of finding.
2. **`K3`'s position clause is vacuous on absence** (`string first` → `-1`). §3.2.
3. **`clamp_prec_g`'s `avail <= 9` floor of `1` can still overflow** a buffer of 2..9 bytes;
   unreachable today. §2.1.
4. **`W4`/`X1`/`X2` scan 7 files while their names claim the tree.** §3.4. No live site missed.
5. **The struct-field comment in `xschem.h` has no row** although `W5` shows how to write one.
   §2.2.
6. **`child`'s `set rc 1` erases rc 134 / 124 / 1**, so no row can distinguish the defect's
   abort from a fixture error or a timeout. §3.3.
7. **The receipt's `\b71\b` enumeration is wrong** (7 comment hits, not 2 + generated tables).
   The claim it supports — no literal 71 in C *code* — is true. §4.3.
8. Stage C's own carried-forward list (`my_snprintf`'s `nstr[50]` arm, option 4, arbitrary Tcl
   from a `.sch`/`.sym`, the Tcl-side `1..71` literals, no read-back seam for
   `xctx->ev_precision`, `graph_marker_fmt`'s silent pointer-parameter overflow) — I re-checked
   items 1, 3 and 4 in the source and they are accurately described. Nothing added, nothing
   fixed.
