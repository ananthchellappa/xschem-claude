# Receipt C — `impl`: the fix landed, every site fenced, every row sabotaged

Measured on `34913077` + this crew's edits, in the main tree
(`/home/analog/dev/xschem-claude`, 31 characters), dev display `:99` alive
(`openbox`, `1920x1080x24`, xvfb pid 3979908) throughout.

**Headline: all fourteen adjudications implemented as written. Two of them needed a
correction I am reporting rather than silently accepting — `C11`'s `- 2` is right but
`C12`'s prescribed behavioural fence for `graph_marker_fmt` cannot redden on that
clamp's removal alone (measured, and the reason is arithmetic, not a fixture defect),
and `C14`'s change is MORE than "a NUL becomes a suffix" and therefore needs a ruling.
Both are written up in full below.** Plus one defect of my own making that I caught by
sabotage and that would otherwise have shipped a row measuring nothing.

---

## 1. What landed

| file | what |
|---|---|
| `src/xschem.h` | `#define DTOA_ENG_BUFSIZE 80` + `extern int clamp_prec_g(int, size_t)` with the full contract comment, beside the `dtoa_eng` declaration; the `Xschem_ctx.ev_precision` field comment rewritten to name all three writers |
| `src/editprop.c` | `clamp_prec_g` DEFINED; `dtoa_eng`'s buffer is `static char s[DTOA_ENG_BUFSIZE]`; `dtoa_eng` clamps its own `precision` ONE statement above the suffix branch |
| `src/draw.c` | four cursor-readout clamps (two with `- 2`), `show_node_measures`, `graph_marker_fmt` (now honours `destsize` and refuses a NULL/≤0 dest), the `if(prec > 17)` comment retitled, and the two `xctx->ev_precision` writer clamps in `draw_graph()` and `draw()` |
| `src/callback.c` | the two tooltip clamps **and the C14 wrong-unit fix** (`sy`'s guard now tests `gr->unity`) |
| `src/save.c` | `nd_view_set`'s clamp; the false half of its comment deleted (C6) |
| `src/eval_expr.y` | `kklex()`'s writer clamp (**the `.y`, never the generated `.c`**) |
| `src/xinit.c` | the initial-4 comment now names `kklex()` |
| `tests/headless/test_ev_precision_bound_1606.tcl` | NEW, 43 checks |
| `tests/run_regression.tcl` | registered in `hcases` only, with a 24-line rationale |

`git diff --stat`: 198 insertions, 28 deletions across 8 tracked files, plus the new
untracked suite. `git status` shows exactly those plus the three pre-existing untracked
entries (`.xschem/`, the batch dir, the sky130A debug dir). Nothing else.

### The helper, verbatim as shipped (`src/editprop.c`, above `dtoa_eng`)

```c
int clamp_prec_g(int prec, size_t avail)
{
  size_t cap;
  if(prec <= 0) return prec;      /* 0 = eval_expr's "engineering off"; <0 = printf default */
  if(avail <= 9) return 1;        /* no room for a conversion at all; 1 is the floor 1602 allows */
  cap = avail - 9;
  if((size_t)prec > cap) return (int)cap;
  return prec;
}
```

The contract comment C2 dictated lives on the **declaration** in `src/xschem.h`
(where a reader looks first); the definition carries the 1606 mechanism, the abort's
rc, and the reason neither the return nor `prec` is a `size_t`. `clamp_prec_e` was
never created (C2). `if(avail <= 9) return 1;` is mine and not in C2's text: without it
`avail - 9` underflows a `size_t` and the clamp becomes a no-op; no caller passes a
buffer that small today, so it is unreachable and is stated as such in its own comment.

> ⚠ **The code block above is this stage's text and is left as the dated record.**
> Stage C2 (`receipts/C2-repair.md`, repair R4a) **rewrote that one-line comment and
> added row `H2b`**, because the shipped comment ("1 is the floor 1602 allows") claimed
> more than the line buys: the floor of 1 is **not** safe — `clamp_prec_g(200, 8)`
> returns 1 and `"%.*g%c"` at precision 1 on a three-digit-exponent value is `1e+287T`,
> 8 bytes with the NUL and 9 with a sign — so for an `avail` of 2..9 an overflow is
> still possible. All the line prevents is the `size_t` underflow. Unreachable today:
> the smallest `avail` anywhere in the tree is **80**, as the table below shows.

### The eleven clamped sites, with the exact `avail`

| # | symbol | file | `avail` argument | ceiling |
|---|---|---|---|---|
| 1 | `dtoa_eng` (one clamp, above the branch — covers all 24 callers) | `editprop.c` | `sizeof(s)` (= `DTOA_ENG_BUFSIZE`) | 71 |
| 2 | `draw_cursor` | `draw.c` | `S(tmpstr)` | 91 |
| 3 | `draw_cursor_difference` | `draw.c` | `S(tmpstr)` | 91 |
| 4 | `draw_hcursor` | `draw.c` | `S(tmpstr) - 2` | 89 |
| 5 | `draw_hcursor_difference` | `draw.c` | `S(tmpstr) - 2` | 89 |
| 6 | `show_node_measures` | `draw.c` | `S(tmpstr)` | 1015 |
| 7 | `graph_marker_fmt` | `draw.c` | `(size_t)destsize` | 71 at the shipped 80 |
| 8 | `waves_callback` (`sx`) | `callback.c` | `S(sx)` | 91 |
| 9 | `waves_callback` (`sy`) | `callback.c` | `S(sy)` | 91 |
| 10 | `nd_view_set` | `save.c` | `S(s)` | 91 |
| 11 | `draw_graph` / `draw` / `kklex` (the three writers) | `draw.c` ×2, `eval_expr.y` | `DTOA_ENG_BUFSIZE` | 71 |

**Nothing was deliberately left alone.** The four `input_line {Pos:}` `dtoa_eng`
callers in `callback.c` (`:2631 :2661 :2686 :2701`), the seven `token.c` `dtoa_eng`
callers, `eval_expr.y`'s `engineering` caller and `graph_marker_text_rec`'s two
`dtoa_eng` calls need no clamp of their own precisely because of site 1 — that is
what C4 buys. `show_node_measures`'s `%e` arm is clamped only for uniformity (C10);
its safety comes from `prec = 2` three lines above it, which row `G5b` fences.

**No literal 71 exists in C *code*.** `/usr/bin/grep -n '\b71\b' src/*.c src/*.h
src/*.y` finds it only in *comments* and in generated files.

> ⚠ **CORRECTED 2026-09-25 by Stage C2** (`receipts/C2-repair.md`, repair R7). The
> original sentence here said "only in two draw.c *comments* and in the generated
> `parselabel.c` tables", which **undercounts this stage's own new comments by
> five** and omits a generated file. Re-measured on the same tree:
> **7 hand-written hits, all inside comments** — `src/draw.c:9071`, `:10658`,
> `src/xschem.h:3865`, `:3866`, `:3868`, `:3875`, `src/eval_expr.y:262` — plus the
> **generated** `src/eval_expr.c:1711` (the mirror of the `eval_expr.y` comment) and
> the **generated** `src/parselabel.c` flex tables (lines 477, 665, 670, 750, 768,
> 783, 1261-1263). The substantive claim — no literal 71 in C code, the number is
> `DTOA_ENG_BUFSIZE - 9` everywhere — **holds**; only the enumeration was wrong.

---

## 2. The suite: `tests/headless/test_ev_precision_bound_1606.tcl`, 51 checks

> ⚠ **43 checks as this stage left it; 51 after Stage C2's repairs**
> (`receipts/C2-repair.md`). The eight rows added there are marked **added by
> Stage C2** in the table below, and `K3`, `W4`, `X1`, `X2` and `child` were
> repaired in place. 46 checks on a box with no dev display (was 38).

Registered in `hcases` **only**. `hcases` goes 79 → **80** entries, so T1 goes
98 → **99 cases / 98 blocks**, `skips=8` unchanged **on a box with the dev display
up**, `skips=9` on one without it.

### The `run_regression.tcl` diff, verbatim

```diff
                  "headless/test_ps_valid_1350" \
-                 "headless/test_typeless_symbol_1603"]
+                 "headless/test_typeless_symbol_1603" \
+                 "headless/test_ev_precision_bound_1606"]
+# ⚠ `test_ev_precision_bound_1606` IS IN `hcases` ONLY, AND ITS DISPLAY ROWS STILL
+# RUN. Issue 1606: thirteen sprintf() statements took their precision indirectly
+# ("%.*g") and none bounded it, so a precision of 73 or more overran an 80-byte
+# buffer and the fortified sprintf killed the process -- `*** buffer overflow
+# detected ***`, SIGABRT, rc 134, and main.c's sig_handler does not trap SIGABRT,
+# so there is no emergency save. It is FILE-BORNE: a .sch with a `floater=true` T
+# record carrying `tcleval([set ::ev_precision 200]...)`, or a .sym with a
+# `format="tcleval(...)"`, sets it while the file is merely opened or netlisted.
+# Most of the suite is STATIC by necessity and this is not laziness: the clamps
+# are deliberately redundant (each writer caps at DTOA_ENG_BUFSIZE - 9 == 71, and
+# each use site caps again against its own buffer), and it was MEASURED in this
+# batch that with either the kklex() clamp or the dtoa_eng clamp alone present the
+# other's removal leaves the behavioural reproducer GREEN, because the survivor
+# prints the same 71-digit string. So each clamp is fenced by a named static row
+# with comments and `#if 0` regions stripped, and the behavioural rows are
+# end-to-end with their own limit stated in their own comment.
+# WHY NOT `dcases` TOO: the four draw.c cursor readouts and the callback.c
+# measurement tooltip need a real draw on a real display, but section D spawns its
+# own child through `devdisplay.sh exec` (:99, GUI_GATE=0) -- the same pattern as
+# `test_typeless_symbol_1603`'s N2 and `test_ps_valid_1350`'s V26 -- so a `dcases`
+# entry would cost gate time for zero extra rows. Nothing in the file creates a
+# widget. MEASURED 2026-09-25 with the dev display up: `RESULT: ALL PASS (43
+# checks)` with `--nogui` and without it, same count either way. On a box with NO
+# dev display the D rows self-skip as ONE lowercase `skip:` line (38 checks), so
+# this suite adds one skip there and none here.
+#
 # ⚠ THE TWO HIERARCHICAL-PDF SUITES ARE IN `hcases` ONLY, AND THAT IS MEASURED.
```

Count re-measured the way `CLAUDE.md` prescribes (find `set hcases [list`, pipe
through `/usr/bin/grep -o '"[^"]*"' | wc -l`): **80**.

### The rows

**Static rows strip block comments and depth-counted `#if 0` regions and collapse
whitespace**, then extract the named C function's body (definition line at column 0
to the first column-0 `}`, prototypes skipped) and match the exact statement. This
was not optional: the fix's own comments quote `clamp_prec_g`, `DTOA_ENG_BUFSIZE` and
the guard expressions repeatedly, and at least one shipped clamp spans two physical
lines.

| row | asserts | kind | arm |
|---|---|---|---|
| `H1` | `clamp_prec_g` is DEFINED in `editprop.c` (body found, not `ZZNOFUNC`) | static | both |
| `H2` | it returns a `prec <= 0` UNCHANGED | static | both |
| `H2b` | **added by Stage C2** — it refuses an `avail <= 9`, so `cap = avail - 9` cannot underflow `size_t` and silently turn the clamp into a no-op | static | both |
| `H3` | its cap is DERIVED as `avail - 9`, not written as a number | static | both |
| `H4` | it actually applies the cap | static | both |
| `H5` | `src/xschem.h` defines `DTOA_ENG_BUFSIZE` as 80 | static | both |
| `H6` | `dtoa_eng`'s buffer is `s[DTOA_ENG_BUFSIZE]`, no literal 80 | static | both |
| `K1` | `dtoa_eng` still exists (vacuity guard for K2/K3) | static | both |
| `K2` | `dtoa_eng` clamps its own `precision` against `sizeof(s)` | static | both |
| `K3` | its three conversions are all present AND the clamp precedes the suffix branch | static | both |
| `W1` | `draw_graph()`'s writer clamp | static | both |
| `W2` | `draw()`'s writer clamp | static | both |
| `W3` | `kklex()`'s writer clamp, **in `src/eval_expr.y`** | static | both |
| `W4` | NO hand-written source assigns `xctx->ev_precision` straight from `tclgetintvar` (catches a fifth writer) | static | both |
| `W4b` | **added by Stage C2** — the file list `W4`/`X1`/`X2` scan really is every `src/*.c *.h *.y *.l` minus exactly the four GENERATED files, with the exclusion list written out a second time so narrowing it reddens this row | static | both |
| `W5` | `xinit.c`'s comment now names `kklex()` — reads the RAW file, because the comment IS the artefact | static | both |
| `W5b` | **added by Stage C2** — the `Xschem_ctx.ev_precision` FIELD comment in `src/xschem.h` names `kklex()` too; reads the RAW file, and anchors on the comment IMMEDIATELY preceding `int ev_precision;` | static | both |
| `W6` | a generated `src/eval_expr.c`, IF present, carries the clamp (a stale one = a stale binary); passes when absent, as in a fresh clone | static | both |
| `G1` | `draw_cursor`'s clamp, `S(tmpstr)` | static | both |
| `G2` | `draw_cursor_difference`'s clamp, `S(tmpstr)` | static | both |
| `G3` | `draw_hcursor`'s clamp, `S(tmpstr) - 2` | static | both |
| `G4` | `draw_hcursor_difference`'s clamp, `S(tmpstr) - 2` | static | both |
| `G5` | `show_node_measures`'s clamped local `prec` | static | both |
| `G5b` | its `fmt1`/`fmt2` VARIABLE assignments and `prec = 2` (C9's trap) | static | both |
| `G6` | `graph_marker_fmt` clamps against `(size_t)destsize` | static | both |
| `G6b` | `graph_marker_fmt` refuses a NULL dest / `destsize <= 0` | static | both |
| `G7` | `graph_marker_text_rec` still caps at 17 (now a display choice) | static | both |
| `G8` | the tooltip's `sx` clamp | static | both |
| `G9` | the tooltip's `sy` clamp | static | both |
| `G10` | **C14**: the `sy` branch tests `gr->unity`, and no `gr->unitx` guard sits over a `gr->unity` body | static | both |
| `G11` | `nd_view_set`'s clamp | static | both |
| `X1` | EVERY indirect-precision `sprintf` statement in the hand-written sources carries a `clamp_prec_g`, except `dtoa_eng`'s three arms, exempted BY EXACT TEXT | static | both |
| `X1b` | the exemption is used by exactly those three and all three are present | static | both |
| `X2` | the files carrying one are exactly `callback.c draw.c editprop.c save.c` | static | both |
| `Z0` | **added by Stage C2** — `cstrip` itself, on a synthetic snippet: block comments, `//` to end of line WITHOUT touching a `//` inside a string or char literal, every `#if 0`-equivalent depth-counted with a live `#else` branch kept, and an `#ifdef <undefined>` left alone | static | both |
| `Z1` | **added by Stage C2** — none of the TEN function bodies the static rows read carries ANY conditional-compilation directive, which is the only fence possible against the `#ifdef <undefined>` decoy | static | both |
| `Z2` | **added by Stage C2** — and in the FOUR functions `Z1` excludes by name (`draw_graph`, `draw`, `show_node_measures`, `waves_callback`, all of which really carry `#if HAS_CAIRO`/`__unix__`), every condition is one this tree actually uses | static | both |
| `B0` | **added by Stage C2** — `child_rc` decodes the four `errorCode` shapes a spawned child can produce (`CHILDKILLED SIGABRT` → 134, `CHILDSTATUS` → its code, `POSIX` → -1) instead of collapsing them all to 1 | static | both |
| `B0b` | **added by Stage C2** — and `child` really returns it: a spawned child that exits 134 is reported as 134 | behavioural | both |
| `B1` | the issue's reproducer at `ev_precision 200`: rc 0, no column-0 `FATAL: signal`, **exactly 71 significant digits** | behavioural | both |
| `B2` | the NEGATIVE worst case is 79 bytes — the 80-byte buffer exactly full | behavioural | both |
| `B3` | precisions 4 71 72 73 200 **4000** all survive and agree at 78 bytes | behavioural | both |
| `B4` | `token.c`'s `@spice_get_node`: rc 0, 71 digits | behavioural | both |
| `B5` | `save.c`'s `nd_view_set` via `::ngspice::ngspice_data(v_big)`: rc 0, 71 digits | behavioural | both |
| `B6` | the graph-marker callout: rc 0, **17** digits (the display cap) | behavioural | both |
| `B7` | the **file-borne** `.sch` floater door: 4 → 200 on open+export, then ordinary work survives with 71 digits | behavioural | both |
| `D1` | a real draw with both cursors AND both hcursors at 200 survives (all four `draw.c` readouts) | behavioural | display child on `:99` |
| `D1b` | the fixture really armed `graph_flags` 2\|4\|128\|256 (anti-vacuity for D1) | behavioural | display child |
| `D2` | the `callback.c` tooltip at 200: rc 0, y readout 71 digits | behavioural | display child |
| `D3` | **C14 after**: `unity=T`, no `unitx` → `y=5.011e-12T` | behavioural | display child |
| `D4` | **C14 after**: `unitx=T`, no `unity` → `y=5.011u` | behavioural | display child |

Every behavioural row asserts **both** the child's exit code **and** the absence of a
column-0 `FATAL: signal` marker, and every child is **spawned** (a SIGABRT in-process
would kill the suite's own interpreter and leave no verdict). The `D` rows spawn
through `devdisplay.sh exec` (`:99`, `GUI_GATE=0`) with `timeout 90` **inside** the
wrapper, and self-skip as **one** lowercase `skip:` line when `devdisplay.sh status`
does not report the display alive.

---

## 3. Sabotage: every one of the 43 rows reddened, with the verbatim line

Protocol per sabotage: `cp` the file aside, patch, `make -C src`, run
`run_suites.sh --nogui test_ev_precision_bound_1606`, restore with **`cp` (never
`cp -a`)**, `make -C src`, confirm green. Every restore was md5-verified against the
pre-sabotage copy.

### Single-guard sabotages

```
##### SABOTAGE h2  (editprop.c: `if(prec <= 0)` -> `if(prec < 0)`)
  FAIL: H2 clamp_prec_g returns a prec <= 0 UNCHANGED -> {0} (exp {1}) : FAIL
  RESULT: 1 FAILED (42 passed)

##### SABOTAGE h3  (editprop.c: `cap = avail - 9;` -> `- 8`)
  FAIL: H3 clamp_prec_g's cap is DERIVED as avail - 9, not written as a number -> {0} (exp {1}) : FAIL
  FAIL: B1 ... (rc=0 death=0 digits=72 r=1.00000000000000000763047353957503566051477833551171075078008666443996951e+288T) : FAIL
  FAIL: B2 the NEGATIVE worst case ... (rc=1 death=0 len=10 digits=0) : FAIL
  FAIL: B3 ... (rc=0 death=0 p4=7 p71=78 p73=79 p4000=79) : FAIL
  FAIL: B4 ... (rc=0 death=0 digits=72 ...) : FAIL
  FAIL: B5 ... (rc=0 death=0 digits=72 ...) : FAIL
  FAIL: B7 ... (rc=0 death=0 before=4 after=200 digits=72) : FAIL
  FAIL: D2 ... (rc=0 death=0 digits=72 ...) : FAIL
  RESULT: 8 FAILED (35 passed)

##### SABOTAGE h4  (editprop.c: `if((size_t)prec > cap)` -> `if(0)`)
  FAIL: H4 clamp_prec_g actually applies the cap -> {0} (exp {1}) : FAIL
  + B1 B2 B3 B4 B5 B7 D1 D1b D2 all rc=1 (the abort is back)
  RESULT: 10 FAILED (33 passed)

##### SABOTAGE h5  (xschem.h: `#define DTOA_ENG_BUFSIZE 80` -> 100)
  FAIL: H5 src/xschem.h defines DTOA_ENG_BUFSIZE as 80 -> {0} (exp {1}) : FAIL
  + B1 B2 B3 B4 B5 B7 D2 all at 91 digits instead of 71
  RESULT: 8 FAILED (35 passed)

##### SABOTAGE h6  (editprop.c: `s[DTOA_ENG_BUFSIZE]` -> `s[80]`)
  FAIL: H6 dtoa_eng's static buffer is sized by the macro, not by a literal 80 -> {0} (exp {1}) : FAIL
  RESULT: 1 FAILED (42 passed)

##### SABOTAGE k1  (rename dtoa_eng -> dtoa_engz in 6 files; links and runs)
  FAIL: H6 ... : FAIL
  FAIL: K1 char *dtoa_eng(double, int) is still in src/editprop.c  : FAIL
  FAIL: K2 ... : FAIL
  FAIL: K3 ... : FAIL
  RESULT: 4 FAILED (39 passed)

##### SABOTAGE k2  (editprop.c: delete `precision = clamp_prec_g(precision, sizeof(s));`)
  FAIL: K2 dtoa_eng clamps its own `precision` parameter against its own buffer -> {0} (exp {1}) : FAIL
  RESULT: 1 FAILED (42 passed)        <- EVERY behavioural row stayed GREEN. This is C12's
                                         measured redundancy, reproduced.

##### SABOTAGE k3  (editprop.c: move the clamp BELOW the suffix branch)
  FAIL: K3 the three conversions the clamp protects are all still there, and the clamp precedes the suffix branch -> {0} (exp {1}) : FAIL
  RESULT: 1 FAILED (42 passed)

##### SABOTAGE x1meg  (editprop.c: `"%.*gMEG"` -> `"%.*g" "MEG"`, same bytes at runtime)
  FAIL: K3 ... : FAIL
  FAIL: X1 ... -> {1 {{editprop.c: sprintf(s, "%.*g" "MEG", precision, i);}}} (exp {0 {}}) : FAIL
  FAIL: X1b the exemption list is used by exactly dtoa_eng's three arms, all three present -> {...2 of 3...} : FAIL
  RESULT: 3 FAILED (40 passed)

##### SABOTAGE w1  (draw.c: draw_graph's writer clamp -> bare tclgetintvar)
  FAIL: W1 draw_graph() clamps the ev_precision it copies out of Tcl -> {0} (exp {1}) : FAIL
  FAIL: W4 no hand-written source assigns xctx->ev_precision straight from tclgetintvar ... -> {1 {{draw.c x1}}} (exp {0 {}}) : FAIL
  FAIL: D2 ... (rc=0 death=0 digits=91 ...) : FAIL
  RESULT: 3 FAILED (40 passed)

##### SABOTAGE w2  (draw.c: draw()'s writer clamp -> bare)
  FAIL: W2 draw() clamps the ev_precision it copies out of Tcl -> {0} (exp {1}) : FAIL
  FAIL: W4 ... -> {1 {{draw.c x1}}} (exp {0 {}}) : FAIL
  FAIL: B5 ... (rc=0 death=0 digits=91 ...) : FAIL
  RESULT: 3 FAILED (40 passed)

##### SABOTAGE w3  (eval_expr.y: kklex's writer clamp -> bare)
  FAIL: W3 kklex() in src/eval_expr.y clamps the ev_precision it copies out of Tcl -> {0} (exp {1}) : FAIL
  FAIL: W4 ... -> {1 {{eval_expr.y x1}}} (exp {0 {}}) : FAIL
  FAIL: W6 a GENERATED src/eval_expr.c ... -> {0} (exp {1}) : FAIL
  RESULT: 3 FAILED (40 passed)

##### SABOTAGE w5  (xinit.c: revert the comment to the pre-1606 wording)
  FAIL: W5 xinit.c's comment on the initial 4 now names kklex() too, so the writer list a reader trusts is complete -> {0} (exp {1}) : FAIL
  RESULT: 1 FAILED (42 passed)

##### SABOTAGE w6only  (sabotage the .y, BUILD so bison regenerates a clamp-less
#####                  eval_expr.c, restore the .y with cp and do NOT rebuild)
  y has clamp: 1 ; generated .c has clamp: 0
  FAIL: W6 a GENERATED src/eval_expr.c, if one exists, carries kklex()'s clamp (a stale one would mean the binary under test predates the fix) -> {0} (exp {1}) : FAIL
  RESULT: 1 FAILED (42 passed)        <- W3 GREEN, W6 RED: the exact stale-generated-parser
                                         hazard, isolated.

##### SABOTAGE g1  (draw.c: draw_cursor's clamp -> bare)
  FAIL: G1 draw_cursor's "%.*g%c" readout clamps against its whole 100-byte buffer -> {0} (exp {1}) : FAIL
  FAIL: X1 ... -> {1 {{draw.c: sprintf(tmpstr, "%.*g%c", xctx->ev_precision, gr->unitx * active_cursorx , gr->unitx_suffix);}}} (exp {0 {}}) : FAIL
  RESULT: 2 FAILED (41 passed)

##### SABOTAGE g2
  FAIL: G2 draw_cursor_difference's "%.*g%c" readout clamps against its whole 100-byte buffer -> {0} (exp {1}) : FAIL
  FAIL: X1 ... {{draw.c: sprintf(tmpstr, "%.*g%c", xctx->ev_precision, gr->unitx * diffw , gr->unitx_suffix);}} : FAIL
  RESULT: 2 FAILED (41 passed)

##### SABOTAGE g3
  FAIL: G3 draw_hcursor's " %.*g%c " readout clamps against S(tmpstr) - 2, paying for the two literal spaces -> {0} (exp {1}) : FAIL
  FAIL: X1 ... {{draw.c: sprintf(tmpstr, " %.*g%c ", xctx->ev_precision, gr->unity * active_cursory , gr->unity_suffix);}} : FAIL
  RESULT: 2 FAILED (41 passed)

##### SABOTAGE g4
  FAIL: G4 draw_hcursor_difference's " %.*g%c " readout clamps against S(tmpstr) - 2, paying for the two literal spaces -> {0} (exp {1}) : FAIL
  FAIL: X1 ... {{draw.c: sprintf(tmpstr, " %.*g%c ", xctx->ev_precision, gr->unity * diffh , gr->unity_suffix);}} : FAIL
  RESULT: 2 FAILED (41 passed)

##### SABOTAGE g5  (draw.c: `int prec = clamp_prec_g(...)` -> `int prec = xctx->ev_precision;`)
  FAIL: G5 show_node_measures (NOT draw_graph_variables) clamps the local `prec` it prints its 1024-byte tmpstr with -> {0} (exp {1}) : FAIL
  RESULT: 1 FAILED (42 passed)

##### SABOTAGE g5b  (draw.c: `prec = 2;` -> `prec = 3;`)
  FAIL: G5b show_node_measures still formats through the fmt1/fmt2 VARIABLES, and its %e arm is still pinned at prec = 2 -> {0} (exp {1}) : FAIL
  RESULT: 1 FAILED (42 passed)

##### SABOTAGE g6  (draw.c: graph_marker_fmt's clamp -> bare prec)
  FAIL: G6 graph_marker_fmt clamps against its own destsize parameter -> {0} (exp {1}) : FAIL
  FAIL: X1 ... {{draw.c: sprintf(dest, "%.*g%c", prec, unit * v, suffix);}} : FAIL
  RESULT: 2 FAILED (41 passed)

##### SABOTAGE g6b  (draw.c: delete `if(!dest || destsize <= 0) return;`)
  FAIL: G6b graph_marker_fmt refuses a NULL dest or a destsize <= 0 instead of casting it to a huge size_t -> {0} (exp {1}) : FAIL
  RESULT: 1 FAILED (42 passed)

##### SABOTAGE g7  (draw.c: `if(prec > 17) prec = 17;` -> 18)
  FAIL: G7 graph_marker_text_rec still caps its marker readout at 17 significant digits ... -> {0} (exp {1}) : FAIL
  RESULT: 1 FAILED (42 passed)        <- B6 stayed GREEN; see §5.2.

##### SABOTAGE g7b  (draw.c: the same cap -> 200)
  FAIL: G7 ... : FAIL
  FAIL: B6 the graph-marker callout SURVIVES at ev_precision 200 and shows 17 significant digits ... (rc=0 death=0 n=1 digits=71 mx=9.9999999999999997988664762925561536725284350612952266601496376097202301e-13T ...) : FAIL
  RESULT: 2 FAILED (41 passed)

##### SABOTAGE g7c  (draw.c: the cap -> 200 AND graph_marker_fmt's clamp removed)
  FAIL: G6 ... : FAIL
  FAIL: G7 ... : FAIL
  FAIL: X1 ... : FAIL
  FAIL: B6 ... (rc=0 death=0 n=1 digits=279 mx=9.99999999999999979886647629255615367252843506129522666014963760972023010253906
                21.00000000000000000763047353957503566051477833551171075078008666443996951063649495461113154913583918651398345555539522089568786054480958499982972526059487327108739962648660614644255098884001691739
                46264e+288T ...) : FAIL
  RESULT: 4 FAILED (39 passed)

##### SABOTAGE g8  (callback.c: sx's clamp -> bare)
  FAIL: G8 the callback.c measurement tooltip's x readout clamps against its own 100-byte sx -> {0} (exp {1}) : FAIL
  FAIL: X1 ... {{callback.c: sprintf(sx, "%.*g%c", xctx->ev_precision, gr->unitx * xval, gr->unitx_suffix);}} : FAIL
  RESULT: 2 FAILED (41 passed)

##### SABOTAGE g9  (callback.c: sy's clamp -> bare)
  FAIL: G9 the callback.c measurement tooltip's y readout clamps against its own 100-byte sy -> {0} (exp {1}) : FAIL
  FAIL: X1 ... {{callback.c: sprintf(sy, "%.*g%c", xctx->ev_precision, gr->unity * yval, gr->unity_suffix);}} : FAIL
  RESULT: 2 FAILED (41 passed)

##### SABOTAGE g10  (callback.c: revert the C14 fix -- sy's guard back to gr->unitx)
  FAIL: G10 (second defect) the tooltip's y branch tests gr->unity, and the gr->unitx guard over a gr->unity body is gone -> {0} (exp {1}) : FAIL
  FAIL: D3 (second defect) with `unity=T` and no `unitx` ... (rc=0 death=0 mt=y=5.011 | x=0.4439) : FAIL
  FAIL: D4 (second defect) with `unitx=T` and no `unity` ... (rc=0 death=0 mt=y=5.011e-06 | x=4.439e-13T) : FAIL
  RESULT: 3 FAILED (40 passed)

##### SABOTAGE g11  (save.c: nd_view_set's clamp -> bare)
  FAIL: G11 save.c's nd_view_set clamps the publisher precision it prints with -> {0} (exp {1}) : FAIL
  FAIL: X1 ... {{save.c: sprintf(s, "%.*g", nd_view.prec, nd_view.raw->cursor_b_val[idx]);}} : FAIL
  RESULT: 2 FAILED (41 passed)

##### SABOTAGE x2  (token.c: append a NEW unclamped `sprintf(d, "%.*g", prec, v);`)
  FAIL: X1 ... -> {1 {{token.c: sprintf(d, "%.*g", prec, v);}}} (exp {0 {}}) : FAIL
  FAIL: X2 and the files carrying one are exactly the four this suite fences by name (a new file here is an unfenced site) -> {callback.c draw.c editprop.c save.c token.c} (exp {callback.c draw.c editprop.c save.c}) : FAIL
  RESULT: 2 FAILED (41 passed)

##### SABOTAGE h1  (rename clamp_prec_g -> clamp_prec_gz in 6 files; behaviour-preserving)
  FAIL: H1 int clamp_prec_g(int prec, size_t avail) is DEFINED in src/editprop.c
        (comments and #if 0 stripped, so its own doc comment does not count) (body={ZZNOFUNC}) : FAIL
  + H2 H3 H4 K2 W1 W2 W3 W6 G1 G2 G3 G4 G5 G6 G8 G9 G11
  RESULT: 18 FAILED (25 passed)       <- 18 static rows catch a pure rename; NO behavioural
                                         row does, which is the correct answer.

##### SABOTAGE d1b  (the SUITE's own D1 fixture loses `hcursor2_y`; product untouched)
  FAIL: D1b ... and the fixture really did arm both cursors AND both hcursors (graph_flags 2|4|128|256), so D1 exercises all four readouts -> {134} (exp {390}) : FAIL
  RESULT: 1 FAILED (42 passed)
```

### Combination sabotages — for the rows whose clamps are redundant

```
##### SABOTAGE b1  (editprop.c: dtoa_eng's clamp AND eval_expr.y: kklex's clamp)
  FAIL: K2 ... : FAIL
  FAIL: W3 ... : FAIL
  FAIL: W4 ... -> {1 {{eval_expr.y x1}}} : FAIL
  FAIL: W6 ... : FAIL
  FAIL: B1 the issue's own reproducer SURVIVES at ev_precision 200 and prints exactly 71 significant digits (DTOA_ENG_BUFSIZE - 9); this was *** buffer overflow detected ***, SIGABRT, rc 134 (rc=1 death=0 digits=0 r=<<absent>>) : FAIL
  FAIL: B2 ... (rc=1 death=0 len=10 digits=0) : FAIL
  FAIL: B3 ... (rc=1 death=0 p4=7 p71=78 p73=<<absent>> p4000=<<absent>>) : FAIL
  FAIL: B7 ... (rc=1 death=0 before=4 after=200 digits=0) : FAIL
  RESULT: 8 FAILED (35 passed)

##### SABOTAGE b4  (editprop.c: dtoa_eng's clamp AND draw.c: draw()'s writer clamp)
  FAIL: K2 ... : FAIL
  FAIL: W2 ... : FAIL
  FAIL: W4 ... : FAIL
  FAIL: B4 token.c's @spice_get_node translation SURVIVES at ev_precision 200 and prints exactly 71 significant digits; this was rc 134 at 73 (rc=1 death=0 digits=0 t=<<absent>>) : FAIL
  FAIL: B5 ... (rc=0 death=0 digits=91 ...) : FAIL
  RESULT: 5 FAILED (38 passed)

##### SABOTAGE b5  (draw.c: draw()'s writer clamp AND save.c: nd_view_set's clamp)
  FAIL: W2 ... : FAIL
  FAIL: W4 ... : FAIL
  FAIL: G11 ... : FAIL
  FAIL: X1 ... : FAIL
  FAIL: B5 reading the cursor-B annotation (save.c nd_view_set) SURVIVES at ev_precision 200 and prints exactly 71 significant digits (rc=1 death=0 digits=0 v=<<absent>>) : FAIL
  RESULT: 5 FAILED (38 passed)

##### SABOTAGE d1  (draw.c: draw_graph's writer clamp AND draw_cursor's site clamp)
  FAIL: W1 ... : FAIL
  FAIL: W4 ... : FAIL
  FAIL: G1 ... : FAIL
  FAIL: X1 ... : FAIL
  FAIL: D1 a real graph draw with both cursors and both axis units SURVIVES at ev_precision 200 on the dev display -- the four draw.c cursor readouts (draw_cursor, draw_cursor_difference, draw_hcursor, draw_hcursor_difference), none of which is reached headless (rc=1 death=0 hasx=<<absent>> done=0 flags=<<absent>>) : FAIL
  FAIL: D1b ... -> {<<absent>>} (exp {390}) : FAIL
  FAIL: D2 ... (rc=0 death=0 digits=91 ...) : FAIL
  RESULT: 7 FAILED (36 passed)

##### SABOTAGE d2  (draw.c: draw_graph's writer clamp AND callback.c: sy's clamp)
  FAIL: W1 ... : FAIL
  FAIL: W4 ... : FAIL
  FAIL: G9 ... : FAIL
  FAIL: X1 ... : FAIL
  FAIL: D2 the callback.c measurement tooltip SURVIVES at ev_precision 200 on the dev display and its y readout carries exactly 71 significant digits; before the fix this aborted at 93 (and at 73 with only one axis unit set) (rc=1 death=0 digits=-1 mt=<<absent>>) : FAIL
  RESULT: 5 FAILED (38 passed)
```

**No row is unreddenable. No row was shipped that I could not redden.**

---

## 4. The suite runs, verbatim

Both taken last, after the final rebuild (`make -C src` → `Nothing to be done for
'all'`), so they are the figures for the tree as it stands.

`tests/headless/run_suites.sh --nogui test_ev_precision_bound_1606`:

```
test home: throwaway /tmp/xschem-test-home.1967696.LP6voU (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (43 checks)
RESULT: 1/1 runs passed
```

`tests/headless/run_suites.sh test_ev_precision_bound_1606` (display arm):

```
test home: throwaway /tmp/xschem-test-home.1968043.0usZZl (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (43 checks)
RESULT: 1/1 runs passed
```

⚠ Both arms report 43 — the `--nogui` arm does **not** suppress `D1`–`D4`, because they
spawn their own `:99` child. Where there is no dev display they become one `skip:` line
and the count is 38. The `display arm: ATTACHED …` banner appears on both because
`run_suites.sh` prints it whenever `:99` is up.

### Neighbours spot-checked, because these edits sit under them

```
PASS     | test_wave_markers            run 1/3  RESULT: ALL PASS (437 checks)
PASS     | test_op_annot                run 2/3  RESULT: ALL PASS (485 checks)
PASS     | test_annot_hier_0911         run 3/3  RESULT: ALL PASS (15 checks)
RESULT: 3/3 runs passed
PASS     | test_home_isolation          run 1/1  RESULT: ALL PASS (116 checks)
ISSUE-STAMP: ok (0 problems)
```

`test_home_isolation` matters specifically: its row `G2` reddens on any new launcher
that is not HOME-armed, and the new suite spawns xschem. It is green because the spawn
happens **inside** xschem, which G2 permits. `test_wave_markers` did NOT time out on
this run even with `:99` attached (issue 1488 is a known flake there, unrelated).

---

## 5. C14, measured: the before/after readout, and my verdict

Measured on `:99` at `ev_precision 4` (the point is *which unit is applied*, not
buffer sizes), one graph, `x1=0 x2=1`, the mouse at the plot-box centre. "Before" is
the shipped guard (`gr->unitx != 1.0` over a `gr->unity` body), rebuilt; "after" is the
fix. `y=5.011` cases use `v_a = vsweep * 5`; `y=5.011e-06` cases use `vsweep * 5e-06`.

| configuration | BEFORE | AFTER |
|---|---|---|
| `unity=T`, no `unitx`, y ≈ 5 | `y=5.011 \| x=0.4439` | `y=5.011e-12T \| x=0.4439` |
| `unity=T`, no `unitx`, y ≈ 5e-06 | `y=5.011u \| x=0.4439` | `y=5.011e-18T \| x=0.4439` |
| `unitx=T`, no `unity`, y ≈ 5 | `y=5.011 \| x=4.439e-13T` | `y=5.011 \| x=4.439e-13T` |
| `unitx=T`, no `unity`, y ≈ 5e-06 | `y=5.011e-06 \| x=4.439e-13T` | `y=5.011u \| x=4.439e-13T` |
| both `T` | `y=5.011e-12T \| x=4.439e-13T` | unchanged |
| neither | `y=5.011 \| x=0.4439` | unchanged |

The NUL is real but invisible through Tcl: hexdump of the before-fix `unitx=T`-only
readout is `793d352e3031310a783d342e343339652d313354` — `y=5.011\nx=4.439e-13T`, the
suffix simply **absent**, because `sprintf(..., "%c", 0)` writes the NUL and the string
ends there. So consequence (2) presents to the user as a **missing** suffix, not as a
visible control character. The magnitude has to be one `dtoa_eng` would suffix for the
difference to show at all, which is why the `y ≈ 5e-06` row is the one that moves.

**My verdict: this is MORE than "the suffix is now correct instead of a NUL byte", and
it needs a ruling.** Row 1 of the table is the reason. With a y-axis unit set and no
x-axis unit — an ordinary configuration, and the one the `Av` crew named — the y
readout changes from `5.011` to `5.011e-12T`: a different number in a different unit.
That is the *correct* reading (the user set `unity=T`, and the x readout has always
honoured `unitx` the same way), and it is also a visible change to a measurement people
read off the screen. Two of the six configurations are untouched, one gains the suffix
it was always meant to have, and **two show a re-scaled y value**. The driver should
file it; I have implemented the shape STAGE_C prescribed and `D3`/`D4` pin both halves,
so a ruling either way is a one-line change to `G10`'s guard plus those two rows.

There is also a second-order effect worth stating: the before-fix `unity=T`-only path
went through `dtoa_eng`'s **80-byte** static, and the after-fix path goes through
`sy`'s **100-byte** buffer. With the 1606 clamps in place both are safe, so this is no
longer a safety difference — but it is why that readout's pre-fix abort threshold was
73 rather than 93, and `D2`'s comment says so.

---

## 6. Deviations, corrections and one defect of my own

### 6.1 C12's `graph_marker_fmt` behavioural fence cannot do what C12 asks — measured

C12: *"Where a site **is** singly responsible, use a behavioural row:
`graph_marker_fmt` … the row needs the caller's `if(prec > 17)` raised, so add a static
row on the 17 as well."*

The static row on the 17 exists (`G7`) and the behavioural row exists (`B6`), but
**`B6` cannot redden when `graph_marker_fmt`'s clamp alone is removed**, and no fixture
can make it. With the 17 in place the widest output is 17 + 8 + 1 = 26 bytes, and both
of `graph_marker_fmt`'s callers pass an 80-byte dest (`sx`/`sy`/`sdx`/`sdy`/`ssl`, all
`char [80]`). Measured: sabotage `g6` (clamp removed, 17 intact) → `RESULT: 2 FAILED`,
and `B6` is green in both. So `graph_marker_fmt` is **not** singly responsible in the
sense C12 assumed; `G6` is its only fence and `B6` fences the 17. Both rows say so in
their own comments.

What `B6` *does* fence behaviourally: the 17 against a substantial raise (`g7b`, cap →
200, gives 71 digits), and the two guards together (`g7c` → the corrupted 279-digit
readout above).

**And `g7c` turned up something worth recording: `graph_marker_fmt`'s overflow does not
abort.** With both guards gone the `sprintf` ran off `sx[80]` into the adjacent `sy[80]`
in the same stack frame and produced a spliced string — no SIGABRT, rc 0. `dest` is a
pointer **parameter**, so `_FORTIFY_SOURCE` cannot size it and no check is emitted.
That is a *silent* memory corruption where every other 1606 site is a loud abort, which
is an argument for `G6` rather than against it, and it is why `graph_marker_fmt` is the
one site where I also added a `!dest || destsize <= 0` guard (row `G6b`).

### 6.2 `G7`'s exact value cannot be fenced behaviourally either — the reason is `%g`

Sabotaging 17 → **18** leaves `B6` green. `%g` strips trailing zeros, and the 18th
significant digit of this marker's x value (`1e-12`) is a zero, so `%.18g` and `%.17g`
print the same string. `G7` fences the literal 17; `B6` fences it against a
substantial raise. Both rows' comments now state this.

### 6.3 A defect of my own, caught by sabotage: `%g` strips trailing zeros, so `D1`'s
### first fixture measured nothing

`D1` was **green** under the `d1` sabotage (draw_graph's writer clamp *and*
draw_cursor's site clamp both removed, `ev_precision` 200 reaching a `char[100]`). The
cause was my fixture, not the guard: it swept x over `0..1`, so `draw_cursor` formatted
`1e-12 * 1.0`, whose exact expansion is ~52 digits — short at **any** precision. I
proved the site was reachable by shrinking only `draw_cursor`'s `tmpstr` to 16 bytes
(`*** buffer overflow detected ***: terminated`), then gave `D1` its own fixture
sweeping `0..1e300` with the cursors at `9e299`/`1e299` and the hcursors at `±1e299`.
`D1` now reddens (`rc=1`). The trap is written into `D1FIX`'s comment in full, because
it is the same trap receipt A named for the *value* and it bit again for the *cursor
position*.

### 6.4 Two things STAGE_C did not ask for, both stated in the code

* **`src/xschem.h`'s `Xschem_ctx.ev_precision` field comment carried the same
  incomplete writer list as `xinit.c`** (*"copied from TCL ev_precision var in draw()
  and draw_graph()"*). STAGE_C names only `xinit.c`; I corrected both, because the
  struct comment is the one a reader hits first. `W5` fences the `xinit.c` half only —
  the struct half is prose with no distinctive token worth a row.
* **`graph_marker_fmt` gained `if(!dest || destsize <= 0) return;`** (row `G6b`).
  Honouring `destsize` means casting it to `size_t`, and a non-positive `destsize`
  would become an enormous `avail` and silently disable the clamp. No caller does that
  today; the guard makes the cast safe rather than documenting a hazard.

### 6.5 Adjudications implemented exactly as written, for the record

`C1` (no "69 vs 71 conflict" anywhere — not in a comment, not in the suite),
`C2` (one helper; `clamp_prec_e` never created), `C3` (`DTOA_ENG_BUFSIZE`, no literal
71 in C), `C4` (one clamp above the branch), `C5`/`C6`/`C7`/`C8`/`C10` (§7 below),
`C9` (`G5`/`G5b` fence by variable name), `C11` (the `- 2` at exactly the two hcursor
sites, its comment naming which two bytes; the cursor-difference sites' true 92/90
ceilings named in their comments and clamped to the uniform 91/89), `C13` (only the
measured doors used: `eval_expr`, `token.c`, `nd_view_set`, the file-borne `.sch`
**with** the `xschem print svg` that headless needs, `-1.0*v` for the negative case,
and no `xschemrc` row at all), `C14` (§5).

---

## 7. The comment corrections, and what each one now says

**C5 — the out-of-bounds READ, in `dtoa_eng`'s new comment, written as derived and
named, never as measured:**

> *(On a build WITHOUT `_FORTIFY_SOURCE` — e.g. `./configure --debug`, which appends
> `-O0` — the same write instead runs off the end of `s` and the oversized `n` below
> lands in `xctx->tok_size`, which five `token.c` sites use as a `memcpy` length.
> Derived from the code and the build flags, not driven: this build fortifies and aborts
> at the write, so `tok_size` is never reached.)*

Both halves re-verified here: `gcc -pipe -O2 -dM -E -x c /dev/null` gives
`#define _FORTIFY_SOURCE 3`, and the five sites are `len = xctx->tok_size;` followed by
`memcpy(result+result_pos, valstr, len+1);` at `token.c` `:6672 :6776 :6880 :6949
:7085`. **Five**, not seven. I did not build `--debug`, and the comment says so.

**C6 — `save.c`'s `nd_view_set`.** The prescribed rewrite (*"this shape aborts inside
my_snprintf"*) was NOT written: its format is bare `"%.*g"`, no `%c`. Deleted: *"100
bytes is ample for one %g"* and the quoted `1.111000061035156` (which is
`double((float)1.111)` and cannot come from this path). The mechanism sentence is kept
verbatim and now ends:

> *The price of bare sprintf is that the 100 bytes are NOT ample: `prec` is the
> publisher's, and for the cursor-B publisher that is `xctx->ev_precision`, which a
> .sch/.sym `tcleval(...)`, an rc file or any script can set. Bounded with
> `clamp_prec_g` (issue 1606); no literal bytes in the format, so the whole buffer is
> the conversion's and the ceiling is 91.*

**C7 — `graph_marker_fmt`, both ABIs named:**

> *WHAT THAT DOES IS ABI-DEPENDENT, and an earlier revision of this comment stated only
> one of the two answers. On x86-64 SysV the integer and SSE argument areas are
> separate, so the double arrives INTACT and it is the SUFFIX that is eaten (measured:
> 'm' came out as `\004`). On Win64 — and `XSchemWin/` exists — there is ONE argument
> area, and there the int `prec` really is consumed as the double (measured on such a
> build: "700.0000000000001136868377216160297393798828125" and a swallowed suffix).*

**C8 — the citation, in `show_node_measures`'s new comment:**

> *THIS is the 1024-byte indirect-precision site, not `draw_graph_variables()`
> immediately above — that function exists and owns its own `char tmpstr[1024]`, but it
> has no indirect-precision conversion at all. Issue 1606's plan cited it and sent a
> reviewer looking in the wrong function; `nm` cannot settle it either way, because
> `-O2` inlines both statics.*

The false statement (*"the symbol does not exist"*) appears nowhere.

**C10 — the 774, in the same comment:**

> *Bounded for UNIFORMITY, not because this site can overflow (issue 1606). Both
> `sprintf()`s below go into the 1024-byte tmpstr, and `"%.*g"` can never emit more than
> 774 characters at ANY precision, because a double's exact decimal expansion holds at
> most 767 significant digits — so the %g arms are already safe. The %e arm is the one
> that CAN grow without limit (%e zero-pads the fraction), and it is safe only because
> `prec = 2` is assigned three lines below, inside the very branch that selects it. Read
> that before "hardening" the %g arm: it is the wrong arm. Note `fmt1`/`fmt2` are
> `char *` VARIABLES, not literals — grepping this site for a literal `"%.*g"` finds
> nothing.*

**`xinit.c` — the now-complete writer list:**

> *copied from the TCL ev_precision var in `draw()` and `draw_graph()` (draw.c) and in
> `kklex()` (eval_expr.y — unconditional, once per lexer token, and the writer issue
> 1606's reproducer goes through). Those are ALL the writers; each one passes the value
> through `clamp_prec_g(.., DTOA_ENG_BUFSIZE)` first.*

**`src/xschem.h`'s struct field** carries the same three-writer list (§6.4), and the
`if(prec > 17)` comment in `graph_marker_text_rec` is retitled:

> *A DISPLAY CHOICE, no longer the safety bound … The safety bound moved INTO
> `graph_marker_fmt()`, which clamps against its own destsize (issue 1606) — so
> lowering or raising this 17 cannot reintroduce the overflow.*

---

## 8. Carried forward — named, NOT fixed

1. **`my_snprintf`'s own `g`/`e`/`f` arm** (`src/util.c`) does
   `nlen = sprintf(nstr, nfmt, i)` into `char nstr[50]` with the bound test **after**
   the write. Same class as 1606, in the house formatter the whole tree uses. Latent:
   every live float caller is ≤ 24 chars. Untouched.
2. **Option 4 (`#define HAS_SNPRINTF`) would introduce a 1606-class defect at more
   sites than it fixes** — the hand-rolled arm returns bytes *written*, `vsnprintf`
   returns bytes that *would have been*; five sites consume the return as a length and
   three as an accumulator where `off` can exceed `sz`. Not attempted.
3. **A `.sch`/`.sym` gives arbitrary Tcl at global level** (`tcl_hook2` →
   `tclpropeval2` → `uplevel #0 "subst \{$s\}"`, and `subst` does command
   substitution), and a generator name gives arbitrary **shell** via `popen`.
   **Fixing 1606 does not make opening a stranger's schematic safe.** Said in exactly
   those words in the suite's own header and in row `B7`'s comment, so nobody reads
   this as a security fix.
4. **Tcl↔C ceiling drift.** `DTOA_ENG_BUFSIZE` closes the C side; `src/xschem.tcl`'s
   `1 to 71` is still a literal in `set_ev_precision` and in the `input_line` prompt.
   An `xschem get ev_precision_max` getter would close it. Belongs to whoever owns
   1602's dialog; `DTOA_ENG_BUFSIZE`'s comment names the open half.
5. **No read-back seam for `xctx->ev_precision`** — `xschem globals` does not print it,
   so no row asserts what the C mirror holds. Every behavioural row here infers it from
   the significant-digit count of a string instead, which is why `sigdigits` exists.
6. **`graph_marker_fmt`'s overflow is silent, not an abort** (§6.1). Now guarded, but
   the general point — a `sprintf` into a pointer parameter gets no `_FORTIFY_SOURCE`
   check — applies wherever else this tree does it, and I did not survey for that.

---

## 9. What I could NOT measure

* **The `--debug` (`-O0`, no FORTIFY) build**, hence the out-of-bounds READ into
  `xctx->tok_size`. Derived and named as such in the code (§7, C5); not driven.
* **The Win64 ABI half of C7.** Taken from STAGE_C's adjudication; no Windows build
  exists here.
* **What the four `draw.c` cursor readouts actually FORMATTED.** There is no read-back
  seam — no Tcl verb returns those strings — so `D1` can only assert survival. Its
  comment says so. `D2` has a seam (`::measure_text`) and therefore asserts the digit
  count.
* **The six other `token.c` `dtoa_eng` sites** (`@spice_get_voltage`,
  `@spice_get_current`, `@spice_get_diff_voltage`): same callee, same argument
  expression, each needing its own instance/net fixture. `B4` drives one and `K2`/`K3`
  fence the callee they all share.
* **The `.sym` `format="tcleval(...)"` netlist door.** Receipt A drove it; I used the
  `.sch` floater door for `B7` instead (one fixture, no symbol library, and it shows
  the "armed a bomb, ordinary work aborts later" shape, which is the more alarming
  half). The `.sym` door is named in the suite header but not driven here.
* **A full T1 gate.** Stage D's job. Spot-checked the four neighbours most exposed
  (§4); all green.
