# RECEIPT A — issue 1623, "Vertically justified": a comma-separated wire label renders stacked

**Stage:** A · **Issue:** 1623 (minted by the driver) · **Date:** 2026-09-29/30
**Tree at start:** `1f42914d`; the driver committed `31115645` (the batch dir + issue 1624 +
`NUMBERING.md`) while this stage was running, so the work sits on top of `31115645`.
**State left:** uncommitted, both test arms green. No commit, no push, no gate, no stash.

---

## 1. What changed, file by file, by symbol

### C — the display transform

* **`src/draw.c`** — new **`sym_text_vstack(int inst, const char *txt_ptr, const char *s)`**, placed
  immediately after its two siblings `get_sym_text_layer()` and `get_sym_text_size()` and written to
  the same shape as `get_sym_text_layer()`, including its mandatory `xctx->tok_size = 0;` else arm.
  Returns `s` itself when there is nothing to do, else a pointer into its own `static char *result`
  (the contract `translate()` already has, which four of the six call sites already hold live across
  their bodies). `sym_text_vstack(-1, NULL, NULL)` frees the buffer.
  Gates, in order: no `xctx` / `inst` out of range → unchanged; empty string → unchanged; the text
  record is not the label's own **`@lab`** record → unchanged; the value holds **no comma** →
  unchanged (that is the user's single-token diagnostic, implemented literally); the instance carries
  no truthy **`vjust`** → unchanged. Otherwise each maximal run of commas becomes one `\n`, with
  leading and trailing runs dropped, so no empty token can consume a line.
* Calls added at the **six** sites that render or measure a symbol text, each as the **last**
  transform at that site (the two draw sites run `translate3()` after `translate()`, the bbox sites
  do not — inserting at a uniform position in the diff would be wrong):
  * `draw_symbol()` — `src/draw.c`, after `translate3()`, guarded `if(vstacked != txtptr)` because
    `my_strdup2()` emits a `dbg(0)` warning on `src == *dest`.
  * `draw_temp_symbol()` — `src/draw.c`, same shape.
  * `inst_text_bbox()` — `src/draw.c`.
  * `svg_draw_symbol()` — `src/svgdraw.c`.
  * `ps_draw_symbol()` — `src/psprint.c`.
  * `symbol_bbox()` — `src/select.c`.
* **`src/xschem.h`** — prototype for `sym_text_vstack()` next to the other two readers;
  `place_wire_label()` signature gains `int vjust`.
* **`src/xinit.c`** — `sym_text_vstack(-1, NULL, NULL);` added to `xwin_exit()`'s
  "clear static data in function" list, beside `translate(-1, NULL)`.

### C — the writer

* **`src/actions.c`** — `place_wire_label(const char *name, int vjust)` appends `" vjust=1"` to the
  prop it hands `place_symbol()`. Written here, in C, and **not** with `xschem setprop` after
  placement: the modeless form re-issues `-place` on every keystroke and this function rebuilds the
  whole prop each time, so a post-hoc token would be wiped on the next re-arm — the same hole that
  loses a preview's hand-set orientation. Row **V20b** fences it.
* **`src/scheduler.c`** — the `add_wire_label -place` arm reads `::label_new_vjust` with
  `tclgetvar()` beside the existing `::label_new_name` and passes
  `vj && !strboolcmp(vj, "true")`. An absent variable is NULL → flag off, which is the right default
  for a bare scripted call (and is how `::label_new_name` already behaves).

### Tcl — the form

* **`src/xschem.tcl`**
  * new **`addlabel::split_display_tokens {s}`** — the DISPLAY tokeniser. Commas **and** whitespace
    separate; `<>`→`[]` per token; runs collapse and empty tokens are dropped. A **sibling** of
    `addlabel::expand_names`, whose contract is untouched.
  * **`addlabel::name_ok`** split into a comma-aware wrapper plus **`addlabel::name_ok1`** (the old
    body verbatim). A comma list is valid iff every token is, and an entry of separators only is
    invalid. One definition of a valid name, applied per token.
  * **`addlabel::start_pass`** branches on `vjust`: flag on → `pending` is a single element, the
    whole `[hi:lo]`-normalised comma list; flag off → today's queue, untouched. "Split bus" is
    ignored on the vjust path.
  * **`addlabel::arm`** publishes `::label_new_vjust` on **every** arm, beside `::label_new_name`.
  * new **`addlabel::on_vjust_change`** → `start_pass`.
  * `addlabel::open` — the `$w.f.vjust` checkbutton loses `-state disabled` and gains
    `-command addlabel::on_vjust_change` (mirror of `on_split_change`).
  * the `addlabel` namespace header comment and the `variable vjust` comment, both of which said
    the box was "reserved (inert)".

### Docs and fence

* **`doc/claude/specs/add_wire_label.md`** — new **"Vertical justification"** section (semantics, the
  tokenisation change, the binding constraint with its measurement, the per-instance gate, brackets,
  and which rows fence what). The line that said *"reserved, disabled. (Will later rotate/vcenter the
  label text.)"* is corrected **and the old sentence is quoted in place**, because that is the exact
  reading the user withdrew and the spec was where the next reader would have re-derived it.
* **`tests/headless/test_add_wire_label.tcl`** — new **section V**, 28 checks. The suite was already
  registered in `hcases` and its epilogue already satisfies `banner_complete`.

**T1 movement: NONE.** The suite is already `"headless/test_add_wire_label"` in `hcases` alone, so
cases and blocks do not move: **112 / 111**. `skips=` stays **8** — the one new guard prints
uppercase `SKIP:`, matching section W's, and `summarize_all` counts only `^skip:`. What moves is the
case's published check count, **196 → 224**.

---

## 2. The mechanism, and how the constraint was PROVED

**Chosen: Angle 2** — a per-instance token read by one new helper in `src/draw.c`, called at the six
render/measure sites. **Rejected: Angle 1** (a derived token resolved inside `translate()`).

Why. Angle 1's appeal is invariant **I1**: one edit covering all six sites. But `translate()` is the
wrong chokepoint *for this particular value*, because the thing being transformed is `@lab` — the
one instance token the netlisters, the bus expander and `save.c` all care about. Angle 1 can only be
made netlist-safe by inventing a *different* token (`@lab_vstack`) and then editing every label
symbol's `T {@lab}` record to use it — which changes five shipped `.sym` files, breaks
`xschem inst_name_text`'s `strcmp(txt_ptr, "@lab")` index resolver, and leaves any site-local label
symbol unstacked. Angle 2 keeps I1's *substance* (one builder, six call sites — exactly what
`get_sym_text_layer()` already is, called from `draw.c`, `svgdraw.c` and `psprint.c`) while making
the netlist safety **structural**: the helper is declared in `xschem.h` and called from
`draw.c`/`svgdraw.c`/`psprint.c`/`select.c` and nowhere else, so no netlist path can reach it.

Also rejected: the recon's Angle 3 option (a) — a second symbol `lab_pin_vjust.sym` whose text
record is a `tcleval(...)` expression. It is genuinely cheaper (no C at all), but a schematic saved
with a non-stock symbol will not open on a stock xschem, and every other label symbol
(`lab_wire`, `ipin`, `opin`, `iopin`) would need a twin.

### The proof, by measurement

The brief asked for measurement rather than call-graph reasoning, and **my first attempt at the
proof was call-graph reasoning wearing a behavioural row's clothes** — see §6, item (e). What
actually holds it shut:

* **Row V15b** — `xschem translate 1 {@lab}` on the **flagged** instance must return the canonical
  comma list with **zero** newlines. This is `translate()`'s own answer, asserted directly.
  **Sabotage S1 put the transform inside `translate()` exactly as Angle 1 would, and V15b caught
  it** (`RESULT: 1 FAILED (223 passed)`). V22 did **not** — see below.
* **Row V22** — the SPICE deck from a real `xschem netlist` (a resistor across two wires, one wire
  labelled with the bus list, netlist_dir in scratch) is **byte-identical** with the flag on and off,
  and contains `R1 bg_trim[3] GND 1k`. Shape-asserting, not symptom-absence.
* **Row V23** — every non-comment line of that deck is a **whole card**: exactly two of them, the
  device card carrying its four fields on **one physical line**, and its node is a real bus bit of
  the label (compared against `xschem expandlabel`'s own answer, not a hardcoded name).
* **Row V21** — both halves of the measurement that makes this display-only, held still:
  `expandlabel {bg_trim[3:0],en_fast,iref_trim[2:0]}` → the right **8** bits in order, and
  `expandlabel {bg_trim[3:0]\nen_fast}` → `bg_trim[3]en_fast,…` **4** wrong names. If anyone ever
  "fixes" the form to store what the user typed, or to store newlines, this row says so.
* **Row V20** — the placed instance's `lab=` is the comma list and `regexp -all "\n"` over it is 0.

⚠ **V22 alone was NOT a fence over the mechanism choice, and that is the most important thing in
this receipt.** A plain `lab_pin` top emits no deck line that routes `@lab` through `translate()`
(`net_name()` reads `get_tok_value(prop,"lab")` directly and calls `expandlabel`; `lab_pin.sym`'s
`format="*.alias @lab"` produced no line in this fixture), so with the transform moved into
`translate()` the deck came back byte-identical and V22 stayed green while the door stood open. The
netlist row is still worth having — it is the only row that exercises a real deck — but **V15b is
what actually holds the boundary**, and it took a sabotage to discover that.

---

## 3. The red, verbatim

Run: `env -u DISPLAY ./src/xschem --nogui -q --pipe --nolog --script
tests/headless/test_add_wire_label.tcl`, section V present, no implementation.

```
RESULT: 17 FAILED (204 passed)
OVERALL: notok
```

Reddened: `V1 V2 V3 V4 V5 V6 V7 V9 V10 V12 V14 V15 V16 V17 V19 V20 V20b`. Verbatim, trimmed:

```
FAIL: V1 split_display_tokens gives one token per typed name and normalises angle brackets to
  square (the netlist-correct spelling) -> {threw (invalid command name
  "addlabel::split_display_tokens")} (exp {{bg_trim[3:0]} en_fast {iref_trim[2:0]}}) : FAIL
FAIL: V6 name_ok accepts a comma list of individually valid names (before this it rejected it, so
  the vjust entry could never arm a preview) -> {0} (exp {1}) : FAIL
FAIL: V9 name_ok still rejects a comma list holding a # engine auto-name token -> {1} (exp {0}) : FAIL
FAIL: V12 the flag makes a 3-token label exactly THREE lines tall and a 2-token one exactly TWO ...
  -> {0 1 1} (exp {1 1 1}) : FAIL
FAIL: V14 the flag makes the 3-token label NARROWER than its one-line form ... -> {0 1} (exp {1 1}) : FAIL
FAIL: V15 a point two lines below the anchor CLICKS the stacked label and MISSES the unstacked one
  -- the click target follows the drawn stack -> {{} {}} (exp {{} {instance 1}}) : FAIL
FAIL: V16 the exported drawing carries one <text> element per token ... -> {aa,,bb
  {bg_trim[3:0],en_fast,iref_trim[2:0]} {bg_trim[3:0],en_fast,iref_trim[2:0]} {busname[3:0]}
  {busname[3:0]}} (exp {aa bb {bg_trim[3:0]} {bg_trim[3:0],en_fast,iref_trim[2:0]} {busname[3:0]}
  {busname[3:0]} en_fast {iref_trim[2:0]}}) : FAIL
FAIL: V17 the stacked lines are SINGLE-spaced ... -> {0 no-stack no-stack} (exp {3 1 1}) : FAIL
FAIL: V19 with the flag ON the same entry becomes ONE label whose name is the whole comma list,
  square-bracketed -> {{bg_trim[3:0]} en_fast {iref_trim[2:0]}} (exp
  {{bg_trim[3:0],en_fast,iref_trim[2:0]}}) : FAIL
FAIL: V20 the armed preview stores the canonical comma list and carries the per-instance flag -- and
  the stored value holds ZERO newlines -> {{bg_trim[3:0]} 0 {}} (exp
  {{bg_trim[3:0],en_fast,iref_trim[2:0]} 0 1}) : FAIL
FAIL: V20b the flag and the name both survive a re-arm (the hole that loses a preview's hand-set
  orientation) -> {{} {bg_trim[3:0]}} (exp {1 {bg_trim[3:0],en_fast,iref_trim[2:0]}}) : FAIL
```

`V8 V11 V13 V18 V20c V21 V22 V23` were green before and after — they are GUARD rows (the existing
queue behaviour, the single-token diagnostic, the `expandlabel` premise, the deck). V15b/V15c were
added later, after sabotage S1 exposed the gap in §2, so they have no red of their own; S1 is their
red.

---

## 4. The green

| | headless (`run_suites.sh --nogui`) | display arm (`run_suites.sh`) |
|---|---|---|
| before (HEAD) | `RESULT: ALL PASS (196 checks)` | `RESULT: ALL PASS (184 checks)` |
| after | `RESULT: ALL PASS (224 checks)` | `RESULT: ALL PASS (207 checks)` |

`OVERALL: ok` on both. The display arm runs 17 fewer checks than headless: 12 pre-existing
(section W's `SKIP: 0246 W3-W11`) plus 5 of mine (`SKIP: V18-V20c`), both for the same reason — the
`addlabel::` form procs need a `winfo` stub, and under a real `$DISPLAY` `proc winfo` replaces Tk's
builtin while `rename winfo {}` destroys it.

C89: `gcc -fsyntax-only -std=c89 -pedantic -Wall -Wdeclaration-after-statement` over all seven
touched `.c` files produces **no diagnostic on any touched line** (the 5–12 per file are
pre-existing `-Wcomment` / `-Wmisleading-indentation` noise in unrelated code). Allocation uses
`_ALLOC_ID_` throughout.

---

## 5. Sabotages

Each applied to the final tree, rebuilt, suite run headless, then reverted.

| # | the plausible wrong implementation | reddened |
|---|---|---|
| **S1** | the **rejected mechanism**: do the transform inside `translate()` (Angle 1), gated on `token == "@lab"` | **V15b** |
| **S2** | **the per-instance gate omitted** (`if(0) return s;`) — every label in the design stacks | **V12 V13 V14 V15 V16 V17** |
| **S3** | the `@lab` record gate omitted — every text record of a flagged instance stacks | **NOTHING — gap, see below** |
| **S4** | naive one-for-one `,`→`\n`, runs **not** collapsed — an empty token draws the BLANK line the feature forbids | **V12b** |
| **S5** | **one of the six sites left out** (`symbol_bbox()`, `src/select.c`) | **V12 V14 V15 V12b** |
| **S6** | the mandatory `xctx->tok_size = 0;` else arm omitted | **`FATAL: signal 11`** — the suite segfaults at the first flagged placement, 213 lines in, with an emergency-save dir. `FATAL` is a counted shape, so T1 would score it. |
| **S7** | Tcl: `::label_new_vjust` published only when set, so a stale `1` leaks into the next pass | **V20c** |
| **S8** | **the newline STORED in `lab=`** — `place_wire_label()` rewrites the commas it writes | **V20 V20b** |

**S3 is a reported gap.** Omitting the `@lab` record restriction changes nothing measurable, because
the only other text record on a label symbol is `@spice_get_voltage`, whose value never contains a
comma. The restriction is still right — it is what keeps the feature scoped to the label's name —
but **no row holds it**, and a future label symbol with a comma-bearing second record would find
that out the hard way. Left unfenced deliberately rather than fenced with a row asserting the
absence of a symptom (the `⚠` in CLAUDE.md about symptom-keyed fences).

**S8 is worth reading twice.** Storing the newline does **not** redden V21/V22/V23 — it reddens
V20/V20b, because `my_mstrcat` writes the value **unquoted** and `SPACE(c)` in `src/token.c` then
truncates `lab=` at the newline, so the label loses its other tokens before the netlister ever sees
it. The deck stays single-line and byte-identical; it is simply a deck for a *different, shorter*
label. So the netlist rows are not the ones that catch this particular wrong turn — the stored-value
row is. The netlist rows catch the *quoted* variant, which round-trips and is the one the recon
called "worse, not safer".

Not sabotaged: the `place_wire_label()` signature change itself (a compile error, not a silent
defect) and the spec text.

---

## 6. What I got wrong

**(a) The brief's check count for the fence was wrong, and so was the recon's.** The brief says
`test_add_wire_label.tcl` has "156 checks"; Angle 1 of the recon says 156 in one place and Angle 3
measured **196**. 196 is the truth at `1f42914d`. Exactly the class CLAUDE.md fences as limit L9 —
I took the number from the suite itself before using it.

**(b) My first red row THREW instead of failing, and aborted the suite.** V17 computed
`[lindex $V_TY 1] - [lindex $V_TY 0]`; on the unfixed tree `$V_TY` is empty, so the subtraction
raised `can't use empty string as operand of "-"` and the suite died at **V16 of 23**, hiding seven
rows. The brief warns about this in its own section, with the 1616 measurement, and I walked into it
on the first attempt anyway. Corrected with an `llength != 3` sentinel that yields
`{0 no-stack no-stack}`.

**(c) I wrote absolute bbox numbers into rows, measured in a standalone probe.** A probe measured the
one-line label's box at **308×20**; the same label in the suite, at the same commit, measured
**302×20** — `text_bbox()`'s box carries a zoom-dependent margin and the earlier sections leave a
different zoom. Corrected by asserting **relations between boxes measured in the same fixture**
(heights in arithmetic progression, widths ordered) and by recording the 308/302 discrepancy in the
section's own header comment so the next reader does not re-derive it.

**(d) I broke the display arm twice, and the suite's own code already showed me how not to.**
First with a pathological `lab=aa,,bb` fixture: `xschem select_at` resolves nets, `expandlabel`
yyerrors on the empty element, and under a real `$DISPLAY` that error is a **modal `tk_messageBox`**
— the suite **TIMED OUT at 200 s**. I confirmed it was mine by running the HEAD version of the suite
under a temporary name on the display arm (`ALL PASS (184 checks)`). Second, after fixing that, with
`proc winfo` + `rename winfo {}`: under `--nogui` that is symmetric, under a real display it
**destroys Tk's builtin `winfo`**, and 25 pages of `invalid command name "winfo"` later
`xschem netlist` wrote nothing at all, so V22/V23 read an empty directory. Section W of the same
file has guarded this since it was written (`if {[info commands winfo] ne {}} { puts "SKIP: …" }`).
I had read that guard and did not copy it.

**(e) The netlist fence I was told to build could not see the mistake it existed for.** The brief
said: *"prove the constraint by measurement, not by reasoning about call graphs."* V22 ("the deck is
byte-identical with the flag on and off") looks like measurement and is really the call-graph
argument in disguise — it can only fail if some deck line routes `@lab` through the transformed
path, and for a plain `lab_pin` top none does. Sabotage S1 — the rejected Angle 1, implemented — left
V22 **green**. Only sabotaging it revealed that; reading the rows would not have. Fixed by adding
V15b/V15c, which assert `translate()`'s own answer directly. **The general lesson: a fence over "X
must not reach Y" needs a row that observes X at the boundary, not only a row that observes Y's
output — Y's output may not depend on X in the fixture you happened to build.**

**(f) My own sabotage driver produced two false results.** S7 was marked "no rebuild needed" (it is
a Tcl-only sabotage) but ran immediately after the C sabotage S6, so it inherited S6's binary and
reported S6's segfault. Both were re-run with a forced rebuild. A harness that decides for itself
when a build is unnecessary is the same defect class as "no test harness builds".

**(g) A recon recommendation I did not take, stated out loud.** Angle 3 recommended splitting on
commas **only** and leaving whitespace inside a token, routing the question as a ruling. I split on
whitespace **as well**, because the joined result becomes the stored `lab=` and `SPACE(c)` counts
`' '` and `'\t'` — a space that reached `lab=` would truncate the label. That is not a preference
call, it is a correctness one, so I made it and recorded it rather than queueing it. The residual
user-visible edge (does `A B` with the flag on mean one stacked label or two?) is noted in §9.

**(h) One thing the recon got right that I nearly got wrong.** `unused_attr_stoplist` in
`src/token.c` looked like it wanted `vjust` added. It does not need it (`ua_instance_eligible_ex()`
returns 0 for anything but `type=subcircuit`, and labels are `type=label`) — **and adding it would
have reddened another registered suite**: row `UF14` of `tests/headless/test_unused_attr_0970.tcl`
pins that list *name for name and in order*. Checked, not assumed, and left alone.

---

## 7. What I did NOT do, and what is unverified

* **No commit, no push, no gate, no full T1.** The driver's.
* **No `look` or `rule` debt filed** — the driver keeps ruling/debt filing. Two items want routing;
  see §9.
* **"Split bus" + "Vertically justified" together**: `split_bus` is silently **ignored** on the vjust
  path. That is the only defensible reading (expanding `B[3:0]` to four bits would stack four lines
  and break the user's single-token diagnostic), but it is a ticked box that does nothing, and
  nothing tells the user. I added **no new status-bar copy** for it, so as not to pre-empt a ruling
  on wording. Unfenced beyond the `start_pass` branch itself.
* **The `@lab` record restriction is unfenced** — sabotage S3, §5.
* **No eyes on anything.** Everything here is a test row or a compiler diagnostic. The two things a
  human would still want to look at, both already measured and neither a defect I introduced:
  the stack is **left-aligned with a ragged right edge** (`cairo_draw_string_line()` subtracts the
  whole block's `longest_line` for every line when `rot==0 && flip==1`, which `lab_pin.sym`'s `@lab`
  record is), and it grows **downward across the wire** from an anchor that sits just above the pin.
  Both are recon findings T7/T8, both are consequences of the existing renderer, and both are
  visible only on a screen.
* **`cairo_font_line_spacing`**: a user who has tuned that knob gets a different on-screen pitch from
  the exported one (recon T9, pre-existing). My rows measure the SVG pitch, which is pinned at
  1.147, and the box pitch, which is the nocairo 65-unit one. Neither measures the screen path's
  cairo pitch, because headless has no cairo context. **Unverified: the on-screen pitch.**
* **Other netlist back ends.** V22/V23 measure SPICE. Spectre, tEDAx, Verilog and VHDL are covered
  only structurally (the helper is not called from any of them), not behaviourally.

---

## 8. Do the bbox and the hit-test agree with what is drawn?

**Yes, and it is measured three independent ways in one fixture**, because the three come from three
different functions that had to be edited separately.

1. **Drawn** — `xschem print svg` after `xschem zoom_full` (`svg_draw_symbol()` → `svg_draw_string()`).
   Row **V16** asserts the exact set of `<text>` element contents: the unflagged 3-token label
   contributes **one** element holding the whole comma string, the flagged one contributes **three**
   (`bg_trim[3:0]`, `en_fast`, `iref_trim[2:0]`), the single-token pair contributes one each, and the
   flagged 2-token label contributes `aa` and `bb`. Row **V17** asserts the three stacked elements'
   `y` values have **equal consecutive deltas, both positive** — single-spaced, growing downward, no
   blank line. Measured pitch: 13.538 and 13.539.
2. **Measured (bbox)** — `xschem instance_bbox` reads `inst[i].x1..y2`, which `symbol_bbox()`
   (`src/select.c`) writes by folding each text's `text_bbox()` into it. Row **V12** asserts the
   heights are in arithmetic progression — 1-line, 2-line and 3-line labels — off the same one-line
   height, and row **V14** that the flagged 3-token label is **narrower** than its one-line form
   (its longest drawn line is one token, not the whole list). Absolute numbers from the probe:
   one line 308×20, three lines 125×60, single token 132×20.
3. **Clickable** — `xschem select_at`, which reaches `find_closest_element()` (`src/findnet.c`), and
   that function tests `POINTINSIDE` against **exactly** the box `symbol_bbox()` wrote. Row **V15**
   asserts that a point two lines below the anchor **selects the stacked label** and **selects
   nothing** at the same offset from the unflagged one: `{{} {instance 1}}`.

The strongest evidence that these are three separate measurements and not one: **sabotage S5**, which
omitted only the `symbol_bbox()` call site, reddened **V12 V14 V15 V12b** — the box and the click
target — while **V16 and V17 stayed green**, because SVG export goes through `svg_draw_symbol()`. That
is precisely the invariant-I1 divergence the codebase records, caught by the fence.

The click target therefore **moves with the stack**, which is correct and user-visible: a 3-token
stacked label is clickable over three lines' worth of area below its connection point. The same
consequence is recorded for `text_hidden_inst` as rule debt `1244_A3_click_target`.

---

## 9. What the next stage must know

1. **`tests/headless/test_add_wire_label.tcl` runs on BOTH arms and you can break the display one
   without noticing.** The suite is in `hcases` alone, so T1 never runs its display arm and a green
   T1 will not tell you. Two specific traps, both now commented in section V: an illegal net name in
   a fixture makes `expandlabel` yyerror, which is a **modal dialog** under `$DISPLAY` (200 s
   timeout, not a failure); and `rename winfo {}` **destroys Tk's builtin**. Run
   `tests/headless/run_suites.sh test_add_wire_label` (no `--nogui`) before you hand anything over.
2. **The fence that holds the binding constraint is V15b, not V22.** If you touch `translate()`,
   `net_name()`, `expandlabel()` or `place_wire_label()`, V15b is the row to watch. V22 measures a
   real deck and is worth keeping, but §2 explains why it cannot see the mechanism mistake.
3. **Two items want routing to the user**, neither blocking:
   * **"Split bus" is silently ignored when "Vertically justified" is ticked.** Defensible, but a
     ticked box that does nothing. Options: leave it, disable the Split-bus checkbox while vjust is
     on, or say so in the status line. No new copy was written.
   * **Whitespace separates on the vjust path**, so `bg_trim<3:0> en_fast` (spaces, no comma) with
     the flag on is **one** stacked label, not two. Forced by `SPACE(c)`, but the user may expect
     commas only to mean "one label".
   * And the two **pixel** items in §7 (ragged right edge, downward growth) are `look` material when
     the user is back at a screen.
4. **`addlabel::name_ok` now has two procs.** `name_ok1` is the old body verbatim; `name_ok` is the
   comma-aware wrapper. `tests/headless/test_hash_label_crash_0156.tcl` calls `name_ok` with
   comma-free names only, so its rows are unaffected — checked, and that suite is **not** registered
   in `run_regression.tcl` (one of the 334).
5. **`::label_new_vjust` is absent until the form arms once.** `tclgetvar()` returns NULL and the
   flag defaults off, which is right for a scripted `xschem add_wire_label -place`. Registered
   suites that drive that verb (`test_placement_wire_gate`, `test_paste_modify_flag_0244`,
   `test_op_annot`) set only `::label_new_name` and were re-run green.
6. **Action-log replay**: `xschem add_wire_label -place` now depends on a second Tcl global. If
   `-place` is (or becomes) a logged action, a replayed log will need `::label_new_vjust` set the way
   `::label_new_name` is. Not investigated — issue 1619's replay door is one batch old.
7. **Issue 1624** (the `<3:0>` silent-netlist hazard for labels created outside the form) is filed
   and untouched. This stage keeps the form's `<>`→`[]` normalisation, so the form is not a route
   into it.

---

## `git status --short` on finishing

```
 M doc/claude/specs/add_wire_label.md
 M src/actions.c
 M src/draw.c
 M src/psprint.c
 M src/scheduler.c
 M src/select.c
 M src/svgdraw.c
 M src/xinit.c
 M src/xschem.h
 M src/xschem.tcl
 M tests/headless/test_add_wire_label.tcl
?? .xschem/
?? doc/claude/wire_label_vjust_batch/receipts/A-vjust.md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
```

Files I meant to change: `src/draw.c`, `src/svgdraw.c`, `src/psprint.c`, `src/select.c`,
`src/actions.c`, `src/scheduler.c`, `src/xinit.c`, `src/xschem.h`, `src/xschem.tcl`,
`doc/claude/specs/add_wire_label.md`, `tests/headless/test_add_wire_label.tcl`, and this receipt.
`.xschem/` and `sky130A/.../debug_st1/` pre-date the session (both in the session-start snapshot).

No `xschem save` or `saveas` was called by hand at any point, and I added **no** `saveas` to the
suite — the two in it are pre-existing (section H, into its own `test_scratch` dir). Every probe
wrote only under
`/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/stageA/`;
the suite's own SVG and netlist scratch goes to `tests/headless/.scratch/_vjust1623_<pid>/`, which is
gitignored and swept by `test_scratch`. One temporary file,
`tests/headless/test_awl_dispbase_tmp.tcl` (a HEAD copy of the suite, to establish the display-arm
baseline), was created and deleted in the same command pair.
