# Calculator — build reference and test contract

**Status:** SPEC / PLAN. No code yet.
**Owner branch:** fluid-editing
**Audience:** Claude Code, in a future session, asked to *build* the xschem Calculator —
a work-alike of Cadence's "Virtuoso Visualization & Analysis L Calculator".

**Read first:** `doc/claude/code_analysis/viva_calculator_explained.md` — the human
explainer. It carries the mental model (this is an *expression builder*, not a pocket
calculator) that the requirements below assume without restating.

**Read also, before writing any code:**
- `doc/claude/code_analysis/waveform_subsystem_reference.md` — the graph/`Raw`/`node=`
  map. The Calculator is a *client* of that subsystem, and every landmine in it applies.
- `doc/claude/specs/ase_l.md` — the simulation cockpit whose outputs list is the
  Calculator's real destination.
- `doc/claude/code_analysis/signal_browser_reference.md` — the sibling panel; the
  Calculator's `data` button and the browser select from the same inventory.

**Line numbers below are as of 2026-08-13 and will drift. Grep the symbol.**

---

## 0. The single most important fact

**Most of the engine already exists.** Do not write an expression evaluator.

| What you need | Where it already is |
|---|---|
| RPN expression evaluator over waveform data, ~54 ops | `plot_raw_custom_data()`, `src/save.c:2381` |
| Expression → new named vector in the loaded raw | `raw_add_vector()`, `src/save.c:1186`; verb `xschem raw add <name> <expr> [sweep_idx]`, `src/scheduler.c` ~`9983` |
| Plotting an RPN expression as a trace | `wviewer::add_trace {token gi rpn ...}`, `src/wave_viewer.tcl:3750` — the parameter is *literally named* `rpn` |
| Append / Replace plot destination | `wviewer::plot_dest` / `set_plot_dest`, `src/wave_viewer.tcl:3962/3977` |
| Per-trace database + dataset syntax | `node_token_split()`, `src/draw.c` ~`3320` |
| Vector inventory, values, index, datasets, points | `xschem raw index|values|datasets|points|info` |

What does **not** exist: the window, the stack, the signal-pick grid, the function browser,
the memories, and the measurement layer (`bandwidth`, `riseTime`, `delay`, …).

---

## 1. Scope

### 1.1 In scope (v1)

- A Tk toplevel reproducing the ViVA L Calculator layout (§4).
- Buffer + stack, RPN and algebraic modes.
- Signal picking from the schematic and from the waveform viewer.
- Function browser over a catalogue (§7).
- Plot / evaluate / print-to-table actions targeting the existing viewer.
- Memories and four user buttons, persisted.
- Export of the buffer into an ASE-L output row.

### 1.2 Out of scope (v1) — state this in the UI, don't hide it

- **RF analyses.** `sp` `zp` `yp` `hp` `vswr` `zm` `gd` describe S-parameter/HB analyses
  ngspice does not run. **Render the buttons, disable them, tooltip "no S-parameter
  analysis in ngspice".** Removing them changes the tool's identity; disabling them is
  information.
- `mp` (model parameter) — needs a model-database reader. Disabled, same treatment.
- Matrix category.
- Families across corners/Monte Carlo — v1 handles the *single-raw multi-dataset* family
  only (`raw->datasets > 1`), not a set of separate raw files.

### 1.3 Non-goals, permanently

- Not a data store. The buffer holds a formula; the numbers stay in `xctx->raw`.
- No second expression evaluator. Anything not expressible in the existing RPN gets
  implemented as a **new opcode in `plot_raw_custom_data()`** or as a **Tcl measurement
  proc that consumes evaluated samples** (§7.3) — never as a parallel parser.

---

## 2. Placement and naming

| Thing | Decision |
|---|---|
| Implementation language | **Pure Tcl**, `src/calculator.tcl`, namespace `calc`. C only if a new RPN opcode is genuinely required (§7.3). |
| Toplevel path | `.calc` (single instance; see R101) |
| Launch | `Tools > Calculator` in the CIW and in the waveform viewer; verb `calculator` in Tcl; action-registry entry `calculator_open` so it is remappable |
| Verb surface | Tcl procs `calc::*` only. **No new C `xschem` subcommand in v1** — everything routes through existing `xschem raw ...`. |
| State file | `~/.xschem/calculator.state` (Tcl dict, one `key value` per line), same shape as ASE-L's state file |

Follow `src/library_manager.tcl` / `src/ase.tcl` for megawidget and namespace idiom. Do
**not** invent a new widget framework.

---

## 3. The existing RPN language — the exact contract

Source of truth: `plot_raw_custom_data()`, `src/save.c:2381`. Reproduced here because the
catalogue in §7 must be expressed in it.

### 3.1 Lexing

- Tokens are separated by **space, tab or newline** (`my_strtok_r(ntok_ptr, " \t\n", ...)`).
- Function tokens carry **literal trailing parentheses**: `abs()`, not `abs`.
- A token that parses as a number via `strtod` becomes a constant, converted with
  `atof_spice()` — **SPICE engineering suffixes work**: `1u`, `2k`, `3meg`.
- Any other token is looked up with `get_raw_index()` as a **vector name**.
- **Unknown vector ⇒ the whole evaluation returns `-1` and the scratch column is not
  touched.** Callers must treat `-1` as "no data", never as "plot whatever is there".

### 3.2 Operators (complete)

| Class | Tokens |
|---|---|
| Arithmetic | `+` `-` `*` `/` `**` |
| Comparison (yield 1.0/0.0) | `==` `!=` `>` `<` `>=` `<=` |
| Conditional | `?` — stack `X cond Y ?` ⇒ `X` if `cond` non-zero else `Y` |
| Trig | `sin()` `cos()` `tan()` `asin()` `acos()` `atan()` |
| Hyperbolic | `sinh()` `cosh()` `tanh()` `asinh()` `acosh()` `atanh()` |
| Exp/log | `exp()` `ln()` `log10()` `db20()` |
| Basic | `abs()` `sgn()` `sqrt()` |
| Complex | `re()` `im()` `cph()` (continuous phase — unwrapped by removing ±360° wraps, so consecutive points never jump by more than 180°) |
| Calculus | `integ()` `deriv()` `deriv0()` `deriv2()` `deriv20()` |
| Statistics | `avg()` `ravg()` (running average) |
| Clipping | `max()` (clips from BELOW: a floor at the arg) `min()` (clips from ABOVE: a ceiling at the arg) |
| Sequence | `prev()` (previous point) `del()` (delay by X-axis distance, **≥ 0 only**) `idx()` (point index) |
| Stack | `dup()` `exch()` |
| Constants | `pi()` `k()` (Boltzmann) `e()` `q()` (electron charge) |

`deriv0()`/`deriv20()` differentiate against the **first** sweep variable regardless of the
graph's `sweep_idx`; `deriv2()`/`deriv20()` are 3-point. `integ()`, `deriv*()`, `prev()`
and `del()` each **widen the evaluation window backwards** (they decrement `first`), so a
clipped range silently reads one or two points before its start. Any measurement built on
them must not assume the window is exactly what it asked for.

**`del()` takes a non-negative delay and nothing else** (issue **0325**, fixed 2026-08-15 by
batch item 12). Its search is a forward walk from the previous match, so it can only ever
delay — there is no negative-argument left shift, and asking for one used to walk the search
index one element past both the sweep column and `ravg_store()`'s scratch array, from a
`stack1[i].prevp` that had never been initialised. A negative (or NaN) delay is now **rejected
exactly like an unresolvable vector name in §3.1**: `plot_raw_custom_data()` returns `-1` for
the whole expression, and because a constant argument is seen at the first evaluated point the
destination column is not written at all. Emit `lshift` as a T route (§7.2), never as a
`del()` with a negative argument. Test: `tests/headless/test_del_negative_arg.tcl`.

**"Not written" is a safety property only because the column is guaranteed to be defined.**
A rejected expression written to a vector name that does not exist yet still creates the
vector — `raw_add_vector()` has registered it before the evaluator ever runs, and the column
it hands over is the previous scratch column, which nothing had zeroed. Since issue 0325 that
column is zeroed *before* the expression is evaluated into it, so a rejected expression yields
a defined all-zero trace rather than a plottable, Tcl-readable window onto uninitialised heap.
This matters to any generated expression, because the Calculator's plot/eval routes name a
**new** destination vector (`wviewer::add_trace` → `xschem raw add <auto name> <rpn>`), which
is precisely the case. A caller that wants to distinguish "rejected" from "all zero" must read
the `-1` return, not the column.

**Two rows of that table were corrected against the C on 2026-08-15** (phase 1d, from
`recon/catalogue_defects.md` D4/D5), because §3.2 is the stated source for the function
catalogue's help text and a wrong gloss propagates into 108 rows:

- `max()`/`min()` were glossed the wrong way round. `MAX` returns the **greater** operand
  (`src/save.c` `case MAX`, ~`:2629`) and `MIN` the lesser, so `max()` raises a wave to a
  **floor** and `min()` caps it at a **ceiling**. The old text said the opposite.
- `cph()` unwraps by **360**: `result = ph - 360*floor((ph - prev_ph)/360 + 0.5)`
  (`case CPH`, ~`:2799`). "No ±180 jumps" was the same fact seen from the output side and
  read as a claim about ±180 wraps; both halves are now stated.

`/` is worth knowing too, and its catalogue help says so: with a zero divisor `case DIVIS`
(~`:2577`) yields **0** when the dividend is also zero and otherwise `y[p-1]` — the
previous point of the *destination* column, which at `p == first` is whatever the last
evaluation left there (L2).

### 3.3 Limits and landmines — every one of these has bitten the graph code

| # | Landmine |
|---|---|
| L1 | `STACKMAX` is 200; overflow is caught at `STACKMAX-2` and returns `-1`. Guard your generated expressions. |
| L2 | **The result lands in a single shared scratch column**, `raw->values[raw->nvars]`. It is overwritten by the *next* evaluation. `get_raw_value()` on an expression trace returns whatever was evaluated last (`src/draw.c:5875`, `:8235`). **Re-evaluate immediately before reading.** |
| L3 | Callers detect "this token is an expression" with `if(strpbrk(express, " \n\t"))` — i.e. **a token counts as an expression only if it contains whitespace**. A single-token formula (`2`, or a bare vector name) is not treated as one. Emit expressions with spaces; never rely on a lone token. |
| L4 | `raw_add_vector()` **reallocs `raw->values`, `raw->names`, `raw->cursor_b_val`**. Any cached pointer into those arrays dangles afterwards (see the note at `src/save.c:1335`). Never hold a `SPICE_DATA *` across an add. |
| L5 | A `node=` entry is `[alias;]<vec-or-RPN> [ '%' [<dataset-digits>] [<rawfile> [<sim_type>]] ]` and there is **exactly one parser**, `node_token_split()`. Issue 0305 exists because six functions hand-rolled it. If the Calculator ever walks `node=`, it becomes caller number nine — **never parser number two**. |
| L6 | `?` and the comparison ops make it easy to write expressions whose value jumps discontinuously; `deriv()` over them produces garbage spikes. Not a bug to fix — a documentation duty for the function help text. |

---

## 4. Window layout — the widget inventory

The layout mirrors the reference screenshot. **This table is a test fixture**: R1xx assert
existence, class, and initial state of each row.

Widget paths are normative — tests address widgets by path.

⚠ **Several of these are children of `.calc` that are *drawn* inside a pane.** `.calc.res`,
`.calc.sel`, `.calc.mode`, `.calc.buf`, `.calc.btb` and `.calc.stk` are all children of the
toplevel (this table says so, and it is normative), and they are managed by
`pack -in .calc.pw.<pane>`, which pack allows for any descendant of the widget's parent.
The consequence to know before editing: such a widget maps **behind** its siblings unless it
is created after them and raised, and `winfo ismapped` returns 1 for a widget that is mapped
and wholly obscured — so the guard has to be stacking order or `winfo containing`, never
`ismapped` alone.

| Id | Path (under `.calc`) | Class | Contents / initial state |
|---|---|---|---|
| W01 | `.calc` | toplevel | title `xschem Calculator` |
| W02 | `.calc.mbar` | menu | cascades: File, Tools, View, Options, Constants, Help |
| W03 | `.calc.res` | frame | collapsible; collapse toggle `.calc.res.tog` |
| W04 | `.calc.res.lab` | label | `Results Dir:` — **plus the provenance, when the raw is not this window's own**: `Results Dir (waveform viewer):` / `Results Dir (ASE-L session):`. See W05. |
| W05 | `.calc.res.path` | entry | full path of the loaded raw; readonly unless edited via Browse. **⚠ Resolved from the raw the USER is looking at, not only from this window's context. Ruled by the crew 2026-08-15 (item 13).** The report: the Calculator was opened from the schematic editor while an ASE-L session had a state loaded and waveforms on screen, and the row read `(no raw file loaded)` — true of `xschem raw rawfile` in the editor's context and useless, because there *was* a raw and the user was looking at it. The order is `calc::results_source`: **self** (`xschem raw rawfile` in the current context) → **viewer** (a waveform viewer's context, the active token first then registry order) → **ase** (`ase::last_rawfile` of a live session, which already answers `{}` unless the file exists) → **none** (the phase-1a wording, unchanged). **A borrowed path MUST say whose it is** — a path with no provenance is worse than no path, because it reads as the current context's and is silently somebody else's; the short form is on W04's label, the long form (which viewer token / which session key) is the `balloon` tooltip on the entry. Two mechanics are load-bearing: the viewer read goes through `wviewer::enter_ctx`/`leave_ctx` with `borrow 1` — a bare `new_schematic switch` clobbers the viewer's title (issue 0173) and an unborrowed switch is refused 100% of the time from a menu callback, which holds `callback()`'s semaphore (issue 0314) — and a **refused** ticket is *skipped*, never read as "that viewer has no raw" (issues 0313/0314). **R705 binds**: this is a live query, never a cached or persisted value, and it has **three** callers — `calc::build_res`, at the end of building the row, which is the only one that runs on a **first** open and is therefore the one that delivers the reported fix; `calc::open`'s raise arm, for a later open onto a world that has moved; and the row's own **expand**, whose whole meaning is "show me that path again". Do not delete the build-time call as an unlisted extra: the raise arm does not run when there is nothing to raise. |
| W06 | `.calc.sel` | frame | the 22-button radio grid |
| W07 | `.calc.sel.<id>` | radiobutton | one per §5 row; variable `calc::selmode`, **empty = nothing armed**. ⚠ Each carries a `-tristatevalue` that no legitimate `calc::selmode` value can hold: Tk's default tristate value is the EMPTY STRING, which is exactly the "nothing armed" value, so without it all 22 render in Tk's mixed look (a panel-grey disc with a grey dot) at first open — the window ships looking as though every selector were half-armed. Ruled by the crew, 2026-08-15 (phase 1b fix round): `{}` stays the normative unarmed value, the sentinel moves. |
| W08 | `.calc.mode` | frame | mode strip |
| W09 | `.calc.mode.off/.family/.wave` | radiobutton | variable `calc::pickscope`, initial `off` |
| W10 | `.calc.mode.clip` | checkbutton | variable `calc::clip`, **initial 1** |
| W11 | `.calc.mode.plot` | button | plot buffer; label **`Plot`** |
| W12 | `.calc.mode.eval` | button | evaluate buffer; label **`Eval`** |
| W13 | `.calc.mode.dest` | combobox | values `Append Replace {New Strip}`, initial `Append` |
| W14 | `.calc.mode.table` | button | show as table; label **`Table`** |
| W15 | `.calc.buf` | text | **the buffer**; height 4, editable, `-undo 1`. ⚠ "height 4" is a **rendered** requirement, not just a `-height` option: the pane that holds it must give it at least its requested height at first open (§4.2). Phase 1b shipped `-height 4` in a pane that allotted 29 px of the 72 requested, so the tool's primary work surface drew one and a half lines with `cget -height` reporting 4. |
| W16 | `.calc.btb` | frame | buffer toolbar |
| W17 | `.calc.btb.enter` | button | push buffer → stack |
| W18 | `.calc.btb.pop` | button | text `Pop` |
| W19 | `.calc.btb.swap` `.roll` `.clrbuf` `.clrstk` | button | stack/buffer edits |
| W20 | `.calc.btb.mplus` | button | text `M+` |
| W21 | `.calc.btb.me` | button | text `ME` |
| W22 | `.calc.btb.undo` `.redo` | button | initial state `disabled` |
| W23 | `.calc.stk` | labelframe | text `Stack`. **The pane that holds it, `.calc.pw.stk`, carries NO title of its own** — phase 0 had titled that pane `Stack` too, and the two nested boxes drew the word twice. Ruled by the crew, 2026-08-15 (phase 1b): the spec's widget keeps the caption, the pane keeps only its frame. |
| W24 | `.calc.stk.list` | listbox | top of stack = index 0; scrolled by `.calc.stk.sb`, which takes the palette like every other widget here (R113) |
| W25 | `.calc.stk.push/.pop/.del/.recall` | button | the four side buttons |
| W26 | `.calc.fn` | frame | function browser |
| W27 | `.calc.fn.cat` | combobox | §7 categories; initial `Special Functions` |
| W28 | `.calc.fn.list` | multi-column list | horizontally scrollable. **Fixed by phase 1d as a `canvas`**, one text item per entry, laid out column-major in `calc::fn_cols` (6) columns of per-column width, with `.calc.fn.hsb` under it and `.calc.fn.vsb` beside it. The alternatives were *rejected*, not skipped, and against this tree: `ttk::treeview` has no cell selection in Tk 8.6 and its tags are per **row**, so a disabled `dft` could not be greyed without greying the five names beside it (RULING-3 needs exactly that); side-by-side listboxes each own their own selection **and their own `xview`**, so the one horizontal scrollbar this row requires could not scroll the grid; a `text` widget yields character-range selection. This is the same enumeration, from the same constraints, that the signal browser records at `src/wave_viewer.tcl:9429-9436`. The vertical scrollbar is not decoration: 56 entries in 6 columns are 10 rows deep and the pane is ~8 rows tall at first open — R112 says the browser is what *scrolls*, not what disappears. |
| W29 | `.calc.pad` | frame | keypad |
| W30 | `.calc.pad.k<n>` | button | **operators only — no digit keys.** Digits are typed into the buffer. **Amended 2026-08-15 by RULING-2** (`doc/claude/calculator_batch/LEDGER.md`), which supersedes both the old `7 8 9 / 4 5 6 * 1 2 3 - 0 ± . +` reading of this row and the 4×4 digit pad in the reference screenshot. **RULING-2 fixed the principle and left the SET to the crew; ruled by the crew 2026-08-15 (phase 1d), the set is the twelve operator tokens `+ - * / ** ? == != > < >= <=` — eleven binary tokens plus the ternary `?`, which R510 does not describe** — `calc::pad_keys`, laid out four to a row, `k1`..`k12` in reading order. Rationale, in the order it decides things: (1) every key emits a token `plot_raw_custom_data()` really lexes (`src/save.c:2414-2425`); a key emitting anything else is not a shortcut but a trap, since §3.1 makes one unknown token return `-1` for the *whole* expression, surfacing phases later as an unexplained failure. (2) A key is not the same as typing the character — which is why keys survive RULING-2 and digits do not: R510/R511 give a binary-operator **button** stack semantics (consume the top two stack entries, push `<second> <top> <op>` as one entry) and no keystroke does that, while a digit has no second meaning and a digit key would only be a slower keyboard. **⚠ That rule covers eleven of the twelve. `?` is NOT binary** — it is the engine's `COND` (`#define COND 49`, `src/save.c:2361`), dispatched at `src/save.c:2531-2536` inside `if(stackptr2 > 2) { /* 3 argument operators */ }` as `stack2[p-3] = stack2[p-2] ? stack2[p-3] : stack2[p-1]; stackptr2 -= 2;`, consuming **three** stack entries (§3.2 classes it as the conditional, and the phase-1d catalogue row says the same). **Phase 4 (ledger item 10) therefore owes `?` its own three-operand rule** and must not read R510 as its contract for this key: a `?` button consumes the top **three** stack entries and pushes `<third> <second> <top> ?`. Emitting `<second> <top> ?` leaves `stackptr2 == 2` at the token, the `stackptr2 > 2` guard is false, `COND` never fires, and the expression silently yields an operand instead of a conditional. That `?` falls outside R510 is a reason to write the rule, not a reason to drop the key: it is a token the engine lexes and it has a button semantics no keystroke supplies. (3) **`±` and `.` are dropped.** Neither is in §3.2; both belong to typing a numeric literal, the job RULING-2 hands to the keyboard. `.` is not even lexable alone — `strtod(".")` fails, so §3.1 looks it up as a *vector name* and the expression returns `-1`. A negative literal is typed `-3`; a negated expression is `-1 *`, which the pad's own `*` composes. (4) The unary functions stay in the function browser, one catalogue entry each (§7.1); duplicating twenty of them here would be the second table R413 forbids, in widget form. |
| W31 | `.calc.pad.u1..u4` | button | `user 1`..`user 4`, a 2×2 block under the keys |
| W32 | `.calc.status` | frame | status line + history dropdown |
| W33 | `.calc.status.msg` | entry/label | readonly, initial empty |
| W34 | `.calc.status.hist` | combobox button | reveals the last 50 messages |

### 4.1 Appearance rules

- **R110** Panels W03, W06, W08, W23, W26 are individually collapsible from the **View**
  menu; collapse state persists across sessions.
- **R111** The window is resizable. Only the buffer (W15) and the stack (W24) take the
  extra vertical space; the selector grid, mode strip, keypad and status keep natural
  height.
- **R112** Minimum size must keep every control reachable — if the layout cannot honour
  that, the function browser is what scrolls, not what disappears.
  **R112 is about pixels, and it is enforced by derivation, not by a constant** (§4.2).
- **R112a** **Every scrollable region scrolls under the pointer, not only over its
  scrollbar.** Ruled by the crew 2026-08-15 (item 13) from the user's phase-1 eyeball
  pass: *"should not require mouse pointer to be over the scrollbar to scroll. Must get
  vertical scroll with mouse scrollwheel if pointer is over the area that needs scrolling
  to make content visible."* The three regions are the function browser (`.calc.fn`), the
  Stack (`.calc.stk`) and the buffer (`.calc.buf` + its toolbar `.calc.btb`).
  - The mechanism is the house one, `nhse_bind_wheel_tree` (`src/xschem.tcl:1589`),
    written from the same feedback about the same defect: **walk the region's widget tree
    and bind every widget**, because Tk delivers a wheel event to the widget under the
    pointer and runs only *that* widget's bindtags — it does not walk up the tree, so a
    bare `bind` on the scrolled canvas misses every sibling and child. `calc::wheel_areas`
    is the table; `calc::wheel_bind_all` runs once, after everything is packed.
  - **The pane holder is a root of its region too** (added by the item-13 review). The
    three content frames are children of `.calc` and are packed *into* their labelframes
    with `-in`, because §4's widget paths are normative — so `winfo children .calc.pw.buf`
    is **empty** and a walk rooted at the content frame can never reach the holder. What
    the holder draws is the pane's title strip and the padding around the scrolling
    content: measured on `:99` at the default 656x680, **25.2%** of the Buffer pane's
    visible area, **16.0%** of the Functions pane's, **10.8%** of the Stack's. That is
    the user's own complaint in miniature, and it was inconsistent as well — `.calc.stk`
    is a Labelframe and *was* bound, only because it happened to be a walk root. Roots:
    `.calc.pw.bot.fn` + `.calc.fn`; `.calc.pw.stk` + `.calc.stk`;
    `.calc.pw.buf` + `.calc.buf` + `.calc.btb`.
  - **ttk comboboxes are excluded** from the walk and it does not descend into one: a
    combobox owns the wheel (`ttk::combobox::Scroll` steps the value) and its popdown is
    a *child* widget, so binding it would break both gestures. Same exclusion, same
    reason, as the house walk's.
  - Steps and direction are **Tk's own class values**, so no region's feel changes:
    5 units for a listbox, 50 pixels for a text; `Button-4`/`%D > 0` scroll toward the start of the
    content; **Shift is the horizontal axis** (`wave_viewer.tcl:16586`), which W28's
    horizontally scrolling function list needs. X11's `Button-4`/`Button-5` and
    Windows/macOS's `<MouseWheel>` are both bound.
  - **The canvas step is 3 units, not `property_form.tcl`'s 1** (ruled by the item-13
    review, and a measured number rather than a taste). The canvas leaves
    `-yscrollincrement` at 0, so a unit is one tenth of the visible height. At 1 unit
    the function browser would have been the slowest region in the window by a factor
    of four — 10% of a viewport per notch against the Stack's ~38% and the buffer's
    ~50% — in a dialog where the wheel is now meant to feel the same wherever the
    pointer is; and, because the walk binds the scrollbars too and every binding
    `break`s, it **replaced** `Scrollbar`'s own class binding and made the one place the
    wheel already worked **3x slower**. Measured on `:99`, one notch over `.calc.fn.vsb`:
    Tk's class binding `0.2205882…`, ours at 1 unit `0.0735294…`, ours at 3 units
    `0.2205882…`. 3 units is the number that leaves the scrollbar exactly as it was
    before the item, to the last digit. Do not "restore the house 1 unit" without also
    excluding `Scrollbar` widgets from the walk — and that is the wrong trade, because
    Tk's Scrollbar binding is `v`-only, so a plain wheel over a **horizontal** scrollbar
    does nothing at all and a wheel-dead strip comes back under the function list.
  - Every binding **`break`s**. `Listbox`, `Text` and `Scrollbar` already carry wheel
    class bindings, and without the break one notch would scroll twice.
- **R113** **Colours come from the signal browser's palette, through one accessor.**
  The browser's palette is `ase::palette <role>` (`src/ase_window.tcl:151`) — the
  USER-LOCKED values `panel #f2f2f2`, `table #ffffff`, `header #e8e8e8`,
  `accent #8b0000`, `fieldfg #000000`, `selectbg #4a6984`, `selectfg #ffffff`,
  `disabledbg #d9d9d9`, `disabledfg #a3a3a3` — which `ase::theme`
  (`src/ase_window.tcl:190`) applies to the shared `Ase.*` ttk styles and
  `ase::ui::apply_theme` (`:236`) walks a browser window with, from
  `wviewer::browser_build` (`src/wave_viewer.tcl:8224`) and ~30 other browser sites.
  The Calculator surfaces the same values as `calc::color <role>`
  (`src/calculator.tcl`), which **reads that same dict** for eight of its nine
  roles — `window`/`panel`/`header`/`field`/`accent`/`fieldfg`/`selectbg`/`selectfg`.
  The ninth, `disabledfg`, is deliberately **not** a browser colour: greyed-out
  text follows xschem's own tree-wide convention, the startup option database's
  `*disabledForeground` (`src/xschem.tcl:15546`, `grey50`, set for both colour
  schemes). `calc::color_sources` is the one place the mapping lives.
  No literal colour is written in `src/calculator.tcl`, **and there are no fallback
  defaults**: a role whose source does not resolve throws, because a colour that
  silently defaults renders plausibly, cannot be told from a deliberate one by any
  `cget` check, and then never tracks the palette again.
  ⚠ `calc::color` reads `ase::palette`, **never `ase::theme`**. `ase::theme` is not
  a reader: it creates ASE's three named fonts and does a process-global
  `option add *TCombobox*Listbox.font AseEntryFont`, which changes the dropdown
  font of every `ttk::combobox` in the application — including ones that already
  exist, since a popdown listbox is built lazily. Opening this window must not
  restyle the Graph dialog, Preferences or the Library Manager. For the same
  reason the status history combobox uses a Calculator-local `Calc.TCombobox`
  style rather than the browser's `Ase.TCombobox`.
  ⚠ And **not `ttk::style lookup Ase.Treeview ...`** either. `lookup` walks the
  style name chain and falls through to ttk's root style when the named style
  does not set the option, so `ttk::style lookup NoSuchStyle.Treeview -foreground`
  returns the same value as the real one and no value comparison can tell the two
  apart. `fieldfg`/`selectbg`/`selectfg` were read that way in the first cut of
  phase 1a and were therefore coming from the ambient ttk theme, not from the
  browser; `ase::theme` now declares them on `Ase.Treeview` so the browser's own
  widgets and this window are painted from one definition.
  Still binding: **do not invent a second palette, and do not hardcode a Cadence
  red** — the dark-red accent on panel headers is `[calc::color accent]`, i.e. the
  value the signal browser already uses, never the literal `#8b0000`.
  Every widget that takes a palette **background** takes a palette **foreground**
  with it, hover states included. A background from the palette over a foreground
  from the startup option database is a legibility bug, not a half-fix: under
  `dark_gui_colorscheme` the option database says `*foreground white`
  (`src/xschem.tcl:15560`), which is invisible on this window's light panels.
  Fonts stay stock: nothing in the tree themes fonts for a new dialog
  (`doc/claude/calculator_batch/recon/theming.md` §3), and ASE's named fonts are
  ASE's.
  **Amended 2026-08-15 by RULING-1** (`doc/claude/calculator_batch/LEDGER.md`). The
  original text ("follow existing xschem dialog theming (`src/resources.tcl`); do
  not hand-set colors") was wrong twice: `resources.tcl` contains no theming at all,
  only base64 icons (recon/theming.md §1), and "do not hand-set colors" was read as
  "leave everything default grey" — which is what phase 0 shipped and what the user
  rejected. The prohibition survives as *one palette, not two*; it is no longer a
  prohibition on colouring.
- **R113a — a readonly ttk::combobox is painted by the style's STATE MAP, not by
  `ttk::style configure`.** Both comboboxes here are `-state readonly` (that is what a
  chooser is), and in this tree's ttk theme `configure ... -fieldbackground` does not
  reach that state: the widgets rendered the stock `#d9d9d9` while the style option
  cheerfully reported `#ffffff`, and the checks that read the style option were green
  about a colour that was not on screen. Every Calc.* combobox style therefore carries
  `ttk::style map <style> -fieldbackground {readonly <field>} -foreground {readonly
  <fieldfg>}`, and the check that covers it reads the **map**, not the option.
  Ruled by the crew, 2026-08-15 (phase 1b fix round).

### 4.2 First-open size, and the toplevel minimum

**Ruled by the crew, 2026-08-15 (phase 1b fix round).** Phase 0 chose
`wm minsize .calc 560 620` and the first-open sash fractions `{0.21 0.36 0.64}` against
**empty placeholder panes**, where any split looks plausible. Phase 1b then put real
controls in, and two defects followed that no `cget`-level check could see and that 299
green checks did not:

- the selector grid needs **614 px**, but at the declared minimum the window gave it
  **548**, so `zm` and `data` — and `data` is an ENABLED selector — were entirely off
  screen while `winfo ismapped` still returned 1. Because `save_layout` persists the
  geometry, a window a user had once shrunk stayed unusable across close/reopen.
- the buffer (W15) asks for **72 px** and was allotted **29**, i.e. one and a half of
  its four lines; `bbox 3.0` and `bbox 4.0` were both empty.

The rules that replace those constants:

1. **The minimum width is DERIVED, every time the window is built:**
   `wm minsize` width = `max(floor, [winfo reqwidth .calc.pw.sel])`, applied *after*
   `restore_layout` so a geometry saved while clipped is corrected upward rather than
   replayed. A grid that grows — a longer id, a bigger font, a later item's row —
   carries the minimum with it. This is R112 made mechanical.
2. **The first-open fractions must give every pane at least its requested height.**
   `{0.21 0.42 0.645}` with a height floor of **680** does that, with ≥ 9 px of margin
   on each of the four panes; the surplus goes to `.calc.pw.bot`, the pane item 4 still
   has to fill. The arithmetic is written out at `calc::pw_list`.
3. **The checks that hold these are pixel checks, not option checks** — `winfo height`
   against `winfo reqheight`, `.calc.buf bbox 4.0`, and `winfo containing` at each
   selector's own centre at the declared minimum (`test_calc_skeleton` S21). A
   `cget -height` check cannot see any of it.

Any later item that adds a widget to a pane re-measures. The phase-0 freeze on the
layout means *do not redecorate*; it never meant *ship a control off the window*.

---

## 5. The signal-selection grid

`calc::selmode` holds one of these ids. Selecting one arms a pick (§6).

| id | row | Label | ngspice / xschem source | Emits into buffer | v1 |
|---|---|---|---|---|---|
| `vt` | 1 | vt | tran raw, node voltage | `v(<net>)` | ✔ |
| `it` | 2 | it | tran raw, device terminal current | `i(<dev>)` or `@<dev>[<term>]` | ✔ |
| `vf` | 1 | vf | ac raw, node voltage (complex) | `v(<net>)` | ✔ |
| `if` | 2 | if | ac raw, terminal current | as `it` | ✔ |
| `vdc` | 1 | vdc | op raw / `.op` values | `v(<net>)` | ✔ |
| `idc` | 2 | idc | op raw, terminal current | as `it` | ✔ |
| `vs` | 1 | vs | dc-sweep raw, node voltage | `v(<net>)` | ✔ |
| `is` | 2 | is | dc-sweep raw, terminal current | as `it` | ✔ |
| `op` | 1 | op | device op parameter, one value | `@<dev>[<param>]` | ✔ |
| `opt` | 2 | opt | device op parameter vs time | `@<dev>[<param>]` from tran raw | ✔ |
| `var` | 1 | var | ASE-L design variable | the variable's **numeric value** | ✔ |
| `mp` | 2 | mp | model parameter | — | ✘ disabled |
| `vn` | 1 | vn | noise raw, V/√Hz | `onoise_spectrum` / per-device contribution | ✔ |
| `vn2` | 2 | vn2 | noise power density, V²/Hz | `<vn-expr> dup() *` | ✔ |
| `sp` `zp` `yp` `hp` `vswr` `gd` `zm` | both | RF block | S/Z/Y/H params, VSWR, group delay, port impedance | — | ✘ disabled |
| `data` | 2 | data | **pick by name** from the signal-browser inventory | the chosen vector name | ✔ |

### 5.1 Rules

- **R201** Exactly one selector is active at a time (radio semantics). Re-clicking the
  active one **disarms** it and returns `calc::selmode` to empty.
- **R202** A disabled selector (§1.2) cannot be armed; clicking it writes an explanatory
  line to the status area and leaves `calc::selmode` unchanged.
  ⚠ That line cannot come from the widget's `-command`: Tk's `invoke` and the `Button`
  class bindings both return early on a `-state disabled` widget, so a disabled control's
  `-command` never fires at all. It is delivered by an explicit `<Button-1>` binding
  (`calc::sel_refuse`, phase 1b) — X still delivers events to a disabled widget — which
  also cannot arm anything, because it never touches `calc::selmode`. The tooltip §1.2
  asks for carries the same sentence, through `balloon` (`src/xschem.tcl:12551`), the
  tree's one tooltip mechanism.
- **R203** Voltage selectors pick a **net**; current selectors pick an **instance
  terminal**. The two use different pick modes and different hit tests. A voltage selector
  must refuse a terminal-only click and vice versa, with a status message — not silently.
- **R204** The emitted name is exactly what `xschem raw index <name>` resolves. **Before
  inserting, the Calculator verifies the name resolves in the current raw**; if it does
  not, it inserts nothing and reports which name failed. (This is the guard against L3/§3.1
  producing a whole-expression `-1` three steps later, where it is undebuggable.)
- **R205** `vn2` is emitted as an expression (`<expr> dup() *`), not as a distinct vector.
  It therefore always contains whitespace, satisfying L3.
- **R206** `var` inserts the variable's **value**, not its name — the RPN evaluator has no
  variable namespace. The status area states the substitution that was made.
- **R207** Hierarchical names use the current `.raw`'s own convention. Do not construct
  them from `xctx->sch_path`; read them back from the raw inventory. (Case handling in
  particular: ngspice lower-cases device-card strings silently — see the mixed-signal
  cosim notes.)

---

## 6. Pick scope: Off / Family / Wave, and Clip

| `calc::pickscope` | Behaviour |
|---|---|
| `off` | pick from the **schematic** canvas |
| `family` | pick from the schematic, but the result covers **all datasets** of the raw, not the current one |
| `wave` | pick an **existing trace** in the waveform viewer; its `rpn` string is pulled into the buffer verbatim |

- **R301** In `wave` scope, the schematic canvas is not armed at all, and the pick uses the
  viewer's existing trace hit-test (`graph_trace_at` / `find_closest_wave`). Do not add a
  second hit-test.
- **R302** In `wave` scope the inserted text is the trace's stored expression, **including
  any `%<dataset> <rawfile>` suffix**, obtained through `node_token_split()` (L5).
- **R303** `family` scope emits the expression **without** a `%<dataset>` restriction;
  `off` scope emits it **with** the current dataset when `raw->datasets > 1`.
- **R304** `Clip` on ⇒ evaluation and measurement are restricted to the X range currently
  displayed by the target graph. `Clip` off ⇒ the full X range of the raw.
- **R305** `Clip` affects **evaluation only**. It never rewrites the buffer text. Two
  evaluations of the same buffer with `Clip` toggled must produce different numbers and an
  identical buffer.
- **R306** Arming a pick must be cancellable with `Escape`, leaving the buffer untouched
  and `calc::selmode` empty.
- **R307** A pick is a **modal gesture**. Register it so the open_pdk modal-gesture
  exclusion covers it; do not let a pick survive a window close.

---

## 7. The function catalogue

### 7.1 Categories (`.calc.fn.cat` values)

`Special Functions` (default) · `Arithmetic` · `Trigonometric` · `Exponential` ·
`Complex` · `Sequence` · `Constants` · `All`

Everything in §3.2 is exposed through the non-Special categories, one entry per token,
inserting the token verbatim.

**Ruled by the crew, 2026-08-15 (phase 1d), building the catalogue:**

- **The category string in the table is the combobox value, verbatim.** The special rows
  were authored as `Special`, which is not one of the eight above, so the *default*
  category would have rendered an empty list. Fixed in the data (`recon/catalogue_defects.md`
  D1); a filter that trims or prefix-matches a category name is a filter that will one day
  match two.
- **`All` is synthetic.** No row carries it; it means every row of every category.
  `calc::fn_entries` is the one place that knows.
- **Entries render alphabetically** (`lsort -dictionary`, i.e. case-insensitively), not in
  table order. The table's order is §7.2's — grouped by kin, which is the right order to
  *read the spec* in and the wrong one to *look a name up* in, and looking a name up is the
  whole job of a 56-entry browser. The reference tool sorts the same way
  (`ref/viva_xl_calculator.png`: `aaSP`, `abs_jitter`, `analog2Digital`, `average`, … down
  the first column, with `dBm` between `d2a` and `delay`).
- **The row schema is six fields** — `{name category route returns insert help}` — and it is
  the single source R413 demands, for the list contents, for the greyed entries, and for the
  hover help. `returns` was added because without it `integ` (scalar, the area) and `iinteg`
  (wave, the running integral) were byte-identical rows (D3).

### 7.2 Special Functions — the catalogue

The reference tool shows these 54 with more off-screen. Column `Route` says how it is
built: **P** = already a primitive in §3.2, **C** = composed of primitives by the
Calculator, **T** = a Tcl measurement proc over evaluated samples, **N** = needs a new C
opcode, **✘** = out of scope v1.

| Function | Returns | Meaning | Route |
|---|---|---|---|
| `average` | scalar | mean over X range | P (`avg()`) |
| `rms` | scalar | root-mean-square | C (`dup() * avg() sqrt()`) |
| `stddev` | scalar | standard deviation | T |
| `integ` | scalar | area under curve | P |
| `iinteg` | wave | running integral | P (`integ()` as a wave read) |
| `deriv` | wave | slope | P |
| `clip` | wave | restrict X range | T (window arg, not an opcode) |
| `flip` | wave | mirror along X | T |
| `lshift` | wave | shift along X | **T** (was "C (`del()` with negative arg) or T"; that recipe is now a *rejected* expression — issue 0325, see below) |
| `sample` | wave | values at chosen X | T |
| `root` | scalar | X where curve = 0 | T (`cross` at level 0) |
| `cross` | scalar | X at Nth threshold crossing | T — **the primitive most timing verbs use** |
| `intersect` | scalar/wave | where two curves meet | T |
| `compare` | bool | curves agree within tol | T |
| `dBm` | wave | power in dBm | C |
| `peak` | wave | peak locations/values | T |
| `histo` | wave | histogram | T |
| `riseTime` | scalar | low%→high% transition time | T (on `cross`) |
| `slewRate` | scalar | dV/dt of a transition | T (on `cross`) |
| `delay` | scalar | edge-to-edge between two signals | T (on `cross`) |
| `settlingTime` | scalar | time to stay inside a band | T |
| `overshoot` | scalar | % past final value | T |
| `dutyCycle` | scalar | high fraction of a period | T (on `cross`) |
| `frequency` / `freq` | scalar/wave | frequency from crossings | T (on `cross`) |
| `period_jitter` / `freq_jitter` | scalar | period/frequency spread | T |
| `eyeDiagram` | wave | fold over a bit period | T |
| `bandwidth` | scalar | X where response drops N dB | T |
| `gainBwProd` | scalar | gain × bandwidth | T |
| `gainMargin` / `phaseMargin` | scalar | loop stability margins | T |
| `groupDelay` | wave | −dφ/dω | C — **`cph() deriv() -360 /`** (was "`cph() deriv()`, negated" — see below) |
| `dft` | wave | discrete Fourier transform | **N** |
| `psd` | wave | power spectral density | **N** |
| `spectrum` / `spectralPower` | wave/scalar | spectrum, power in it | N (on `dft`) |
| `harmonic` / `harmonicFreq` | scalar | Nth harmonic and its frequency | T (on `dft`) |
| `fourEval` | wave | evaluate a Fourier series | T |
| `rmsNoise` | scalar | integrated noise over band | C (`dup() * integ() sqrt()`) |
| `phaseNoise` | wave | noise as phase | T |
| `convolve` | wave | convolution | N |
| `dnl` | wave | differential nonlinearity | T |
| `compression` / `compressionVRI` | scalar | 1 dB compression point | T |
| `ipn` / `ipnVRI` | scalar | intercept point | T |
| `thd` | scalar | total harmonic distortion | T (on `dft`) |
| `dftbb` / `psdbb` | wave | baseband (I/Q) variants | ✘ |
| `evmQAM` / `evmQpsk` | scalar | error vector magnitude | ✘ |
| `pzbode` / `pzfilter` | wave | pole/zero handling | ✘ (ngspice `pz` output not modelled) |
| `getAsciiWave` | wave | load a curve from a text file | T (via `xschem raw table_read`) |

**Implementation order is exactly: P, then C, then T-on-`cross`, then the rest.** `cross`
alone unlocks `riseTime` `slewRate` `delay` `dutyCycle` `frequency` `settlingTime`
`overshoot` — seven of the most-used verbs from one well-tested primitive.

### 7.2a Three corrections this table needed before it could build a catalogue

Ruled by the crew, 2026-08-15 (phase 1d), from `recon/catalogue_defects.md`. The catalogue
in `calc::catalogue` (`src/calculator.tcl`) is the shipped form of this table, so a wrong
`Route` here becomes a wrong RPN string in the buffer three phases later, where §3.1 turns
it into a silent `-1` for the whole expression.

- **`lshift` is a T route, and the recipe this table used to prescribe is unimplementable.**
  "`del()` with a negative arg" cannot work: the `DEL` arm (`src/save.c:2586`) compares
  `fabs(x[p] - x[...]) <= tmp`, so a negative `tmp` never matches and the forward search runs
  past `last`. **Confirmed under valgrind and fixed by batch item 12 — issue 0325**, and it
  was worse than the finding claimed: the walk read `x[last+1]` *and* `arr[i][last+1]`, one
  element past both the sweep column and the `my_calloc(_ALLOC_ID_, last + 1, sizeof(double))`
  at `src/save.c:2297`, starting from a `stack1[i].prevp` that no arm had ever initialised.
  Nothing was written out of bounds. It was an **out-of-bounds read in shipped C**, reachable
  from any `node=` expression a user types, and not a Calculator bug.
  **What a negative `del()` does now:** the whole evaluation is rejected the way §3.1 rejects
  an unresolvable vector name — `plot_raw_custom_data()` returns `-1`, and with a constant
  argument the destination column is not touched (and, when the destination is a vector the
  call has just created, it holds the zeros `raw_add_vector()` put there — see §3.2). So the
  old recipe is not merely a wrong answer, it is *no* answer: a `lshift` built on it would
  plot a flat zero trace, not a shifted one. The catalogue
  emits nothing for `lshift` until a T-route proc exists. (The authored row also emitted a
  bare `del()`, which is a *right* shift — the opposite of its own help.)
  A positive `del()` is untouched by the fix, pinned by `DN2`/`DN7`/`DN10` of
  `tests/headless/test_del_negative_arg.tcl`.
- **`groupDelay` needed the units conversion the old recipe left out.** `cph()` is in
  **degrees** and `deriv()` differentiates against the sweep variable, which for an AC raw
  is **Hz, not ω**, so `cph() deriv()` negated is degrees per hertz — short of −dφ/dω by
  π/90. With φ in radians and ω = 2πf, −dφ/dω = −(dφ_deg/df)/360, which is exactly
  `cph() deriv() -360 /` in this evaluator's operand order (`X Y /` is X/Y).
- **The five T-route verbs that stand on `dft` carry route `N` in the catalogue.** §7.2
  marks `harmonic`, `harmonicFreq`, `thd` as "T (on `dft`)" and `spectrum`/`spectralPower`
  as "N (on `dft`)"; with `dft` absent (§12.2 / RULING-3) there is no T to write, so the
  route the *Calculator* would have to build is the N one. Encoding it in the route keeps
  the table the single source for the disabled state, which is what RULING-3 asks for; each
  row's help says which missing opcode it stands on, so the information is not lost.
  The greyed set is therefore exactly: `dft` `psd` `convolve` `spectrum` `spectralPower`
  `harmonic` `harmonicFreq` `thd` (route N) and `dftbb` `psdbb` `evmQAM` `evmQpsk` `pzbode`
  `pzfilter` (route `X`, this table's `✘`).

### 7.3 The T route — how a Tcl measurement is allowed to work

- **R401** A T-route function **must not** parse the expression. It calls
  `xschem raw add __calc_tmp <rpn>` (or evaluates into the scratch column) and then reads
  samples with `xschem raw values`. It operates on numbers, never on text.
- **R402** Any temporary vector it creates is named `__calc_tmp<N>` and is **deleted with
  `xschem raw del` before the proc returns**, on every exit path including error. See
  `doc/claude/code_analysis/scratch-dir-leak-discipline` for why this is a rule and not a
  preference.
- **R403** Because of L4, a T-route proc must re-fetch anything derived from the raw after
  any `raw add`/`raw del`.
- **R404** A T-route function that returns a scalar puts the scalar in the buffer as a
  **literal number with a comment of provenance in the status area**, not as an opaque
  handle. The buffer must stay a string that the existing evaluator can eat.
- **R405** New C opcodes (N route) are added **only** to `plot_raw_custom_data()`, with a
  `#define` in the existing block, a token string, and an entry in this table. Adding one
  obliges you to update §3.2 here and the graph docs.

### 7.4 Function insertion semantics

- **R410** Clicking a function in RPN mode **appends** its token to the buffer, preceded by
  a space.
- **R411** Clicking a function in algebraic mode **wraps** the current buffer:
  `abs(<buffer>)`. If the buffer is empty it inserts `abs()` with the caret between the
  parens.
- **R412** A function needing extra arguments (`riseTime`, `cross`, `bandwidth`, `clip`, …)
  opens a small argument dialog **before** touching the buffer. Cancel leaves the buffer
  byte-identical.
- **R413** Every catalogue entry has one-line help shown in the status area on hover,
  sourced from the same table that builds the list — one table, not two.

---

## 8. Buffer and stack semantics

### 8.1 Common

- **R501** The buffer is free text. Anything a user types is legal until evaluated; the
  Calculator never rejects keystrokes.
- **R502** `Enter` (W17) pushes the buffer to the top of the stack and clears the buffer.
  Pushing an empty buffer is a no-op with a status message.
- **R503** `Pop` (W18) removes the top stack item and puts it in the buffer, **replacing**
  the buffer contents. If the buffer was non-empty, the discarded text goes to the undo
  history.
- **R504** The stack is unbounded in the model but capped at 200 entries in the UI,
  matching `STACKMAX`; pushing at the cap drops the oldest and says so.
- **R505** Undo/redo (W22) cover buffer edits **and** stack operations, as one history.
  They are disabled exactly when their history is empty.
- **R506** Every operation that changes the buffer or the stack updates the status area
  with what happened. Silence is a bug.

#### `calc::status` — the contract every later phase calls (W32–W34)

Ruled by the crew, 2026-08-15, phase 1a. R506 obliges every operation to speak, so
this proc is on the path of nearly every action in the tool; the three questions
below are the ones a caller cannot answer for itself and so must not have to.

- **R507** `calc::status ?msg? ?record?` writes `msg` into `.calc.status.msg` and
  **prepends** it to the history behind `.calc.status.hist`. The **empty string clears the
  message field and records nothing** — a blank history row is not information, and clearing
  is how a transient message is retired. `calc::status` returns the message it wrote.
  **`record` defaults to 1 and exists for exactly one caller** (ruled by the crew,
  2026-08-15, phase 1d): R413's hover help passes 0, so the line is shown and **not**
  recorded. Help text is a legend, not an event — dragging the pointer across the function
  list crosses fifty entries in a second, and recording them would spend R509's whole
  50-entry cap on tooltips for functions the user never clicked, evicting the messages the
  history exists to let them re-read. Everything that actually *happens* still records,
  which is what R506 asks for.
- **R508** With no window — `.calc` not built, already closed, or `--nogui` where
  `winfo` does not exist — it is a **silent no-op that returns cleanly**, and records
  nothing. Rationale: it is called from stubs, from teardown paths and from headless
  tests, and a status line that throws would take its caller down with it (the
  `ciw_echo` precedent, `src/ciw.tcl:120-127`). The history is a property of the
  window: a closed-and-reopened Calculator starts with an empty one, matching R705's
  "nothing stale is resurrected".
- **R509** The history holds **50 entries, newest first**. At the cap the **oldest
  (last) entry drops**. Consecutive duplicates are **kept** — unlike `::ciw_history`
  (`src/ciw.tcl:161-174`), which dedupes because it recalls *commands*; two identical
  status lines mean the operation genuinely happened twice, and hiding the second
  would be the silence R506 forbids. Selecting an entry from `.calc.status.hist`
  re-displays it in `.calc.status.msg` and does **not** re-record it.
- **R510** W34 says the dropdown **reveals** the messages, and that is a rendering
  requirement, not a data one. ttk sizes a combobox popdown to the combobox's own
  pixel width, and W34 is deliberately a two-character *button* rather than a field,
  so with no correction the list is ~35 px wide and shows `Buf`, `Plo`, `Eva`. The
  Calculator-local `Calc.TCombobox` style therefore carries a `-postoffset` that
  shifts the popdown left and widens it (`calc::popdown_extra`), leaving the button
  small and the list readable. A check that only asserts `cget -values` tests the
  widget's data, not what the user sees; the suite posts the dropdown and measures
  the listbox against the longest message.

### 8.2 RPN mode (`calc::notation` = `rpn`, the default)

- **R510** A binary operator button (`+ - * /`) consumes **the top two stack entries** and
  pushes `<second> <top> <op>` as one entry. If fewer than two are available, it consumes
  the buffer as the second operand.
- **R511** With stack `[b, a]` (top first) and the buffer empty, pressing `+` yields stack
  `[a b +]`. Trace this exact case in a test — the operand order is the classic bug.
- **R512** A unary function applies to the buffer if non-empty, else to the top of stack.
- **R513** The emitted string is **directly evaluable** by `plot_raw_custom_data()` with no
  transformation. This is the whole reason RPN is the default.

### 8.3 Algebraic mode (`calc::notation` = `alg`)

- **R520** The buffer holds infix text: `db20(v(out) / v(in))`.
- **R521** On evaluate/plot, the buffer is **translated to RPN** by `calc::alg2rpn`, and the
  RPN string is what reaches the engine. The user-visible buffer is not rewritten.
- **R522** `calc::alg2rpn` is a pure function: same input, same output, no globals. It is
  the single most testable unit in the feature — see §11.
- **R523** Precedence: `**` > unary `-` > `* /` > `+ -` > comparisons > `?`. Parentheses
  override. Right-associative `**`, left-associative everything else.
- **R524** A translation failure names the offending token and column, and **aborts the
  action**. It never falls back to sending the infix string to the engine.
- **R525** Switching notation mode does **not** rewrite the buffer or the stack. It changes
  how new button presses compose. State this in the Options menu entry.

---

## 9. Actions: plot, evaluate, table, export

- **R601** **Plot** sends the buffer to `wviewer::add_trace <token> <gi> <rpn>`; the
  destination strip comes from W13 (`Append` / `Replace` / `New Strip`), which must reuse
  `wviewer::set_plot_dest` rather than reimplementing the choice.
- **R602** Plot with no viewer open opens one (the ASE-L viewer), then plots.
- **R603** **Evaluate** produces a scalar, written to the status area **and** left
  selectable/copyable. It does not modify the buffer.
- **R604** Evaluate on a wave-valued expression reports the value at the **current cursor**
  if one exists, else at the last point, and **says which** in the message.
- **R605** Evaluate must call the engine **immediately before reading** the scratch column
  (L2), in the same Tcl command, with nothing in between that could evaluate anything else.
- **R606** **Table** shows X/Y pairs of the evaluated expression in a scrollable dialog,
  honouring `Clip`.
- **R607** Any action whose expression fails to evaluate (`-1` from the engine) reports
  **which token failed to resolve**, by re-testing each vector-looking token with
  `xschem raw index`. A bare "expression error" is not acceptable — this is the single
  worst failure mode of the Cadence original.
- **R608** **Export to ASE-L** adds the buffer as a row in the current ASE-L session's
  outputs list, with a user-supplied name. Round-trip: the row can be sent back to the
  buffer.

---

## 10. Memories, user buttons, persistence

- **R701** `M+` stores the buffer into the next free memory slot; `ME` opens the memory
  list for recall, rename and delete.
- **R702** Memories are named. An unnamed store gets `mem<N>`.
- **R703** `user 1`..`user 4` each hold one expression and one label. Right-click (or a
  modifier-click, matching existing xschem idiom) opens the bind dialog.
- **R704** Memories, user buttons, notation mode, `Clip`, plot destination and panel
  collapse states persist in `~/.xschem/calculator.state`, written atomically (temp +
  rename) and read defensively — a corrupt or missing file yields defaults and a status
  message, never a stack trace.
- **R705** Nothing about the *current raw* is persisted. Reopening the Calculator against a
  different simulation must not resurrect stale vector names as if valid.

---

## 11. Test plan

Tests live in `tests/headless/` and follow the existing conventions
(`tests/test_utility.tcl` resolves the binary; `gold/` baselines exist there, unlike
`create_save`/`open_close`/`netlisting`).

### 11.1 Headless — no DISPLAY needed

These are the bulk, and they are where the value is. Run as
`./src/xschem --nogui --pipe -q --script tests/headless/<t>.tcl`.

| Test file | Covers | Notes |
|---|---|---|
| `test_calc_alg2rpn.tcl` | R521–R524 | **Table-driven.** ~60 infix→RPN pairs incl. precedence, associativity of `**`, unary minus, nested calls, and 15 malformed inputs that must fail with a named token. Pure function, no raw file needed. |
| `test_calc_rpn_emit.tcl` | R510–R513 | Stack/buffer state machine. Assert operand order (R511) explicitly. |
| `test_calc_stack.tcl` | R501–R506 | push/pop/swap/roll/clear/undo, incl. the 200-entry cap. |
| `test_calc_engine.tcl` | §3, L1–L4 | Evaluate known expressions against a **committed tiny `.raw`** fixture with hand-computed answers. Include: unknown vector ⇒ error path; >200 tokens ⇒ error; SPICE suffix `1u`; `X cond Y ?` truth table. |
| `test_calc_scratch_reuse.tcl` | L2 / R605 | Evaluate A, evaluate B, read — assert you get B. Then interleave a plot between evaluate and read and assert the guard catches it. **This test exists because the bug is invisible without it.** |
| `test_calc_tmpvec_leak.tcl` | R402 | Run every T-route function, then assert `xschem raw info` shows no `__calc_tmp*`. Include a forced-error path. |
| `test_calc_measure.tcl` | §7.2 T route | Golden values for `cross` `riseTime` `delay` `dutyCycle` `bandwidth` `rms` `average` on the fixture raw. |
| `test_calc_selector_names.tcl` | R204, R207 | Every enabled selector against the fixture: emitted name must resolve via `xschem raw index`. |
| `test_calc_state_io.tcl` | R704 | Write, read back, assert identity; then corrupt the file and assert defaults + message, no error. |

### 11.2 Fixture

Commit a small deterministic `.raw` under `tests/headless/data/calc_fixture.raw` with:
- a tran dataset with a clean square wave and a ramp (exact crossing times computable),
- an ac dataset with a known single-pole response (exact −3 dB point),
- **more than one dataset**, so `family` and `%<n>` paths are exercised,
- at least one op-parameter vector (`@m1[gm]`-style name) to test R203/R207 naming.

Generate it once with ngspice, commit it, and **document the generating deck next to it**.
Do not regenerate it in the test — a fixture that regenerates is a fixture that drifts.

### 11.3 GUI — needs the gate

Under a real `$DISPLAY` these must run via `tests/headless/run_suites.sh` or
`gated_xschem.sh`, **never a bare loop** (see `doc/claude/specs/gui_test_gate.md`).
Press `Allow 30m` once before the batch.

| Test | Covers |
|---|---|
| `test_calc_widgets.tcl` | R101–R113: every W-row exists, has the right class and initial state |
| `test_calc_pick.tcl` | R201–R206, R301–R307: full Tk event sequence for arm → click canvas → buffer text. **Replay the whole sequence** (press/motion/release), per the gesture-test lesson — a synthesised click alone does not reach the handler |
| `test_calc_plot.tcl` | R601–R606 against a live viewer |

### 11.4 What cannot be tested and must be eyeballed

Per `doc/claude/code_analysis/pixel-deliverables-need-eyeball`: layout proportions,
collapse behaviour, the disabled-RF-button appearance, and whether the function list is
actually readable at default size. Budget one eyeball pass and write the receipt.

### 11.5 Sabotage checks

For each of the following, break it deliberately and confirm a test goes red. A green
suite over untouched code proves nothing.

1. Reverse the operand order in R511.
2. Remove the re-evaluate in R605.
3. Delete one `raw del` in a T-route error path (R402).
4. Make R607 report a generic error instead of the failing token.
5. Let `Clip` rewrite the buffer (violating R305).

---

## 12. Open decisions for the driver

Do not guess these; they change the shape of the work.

1. **Toplevel or panel?** Cadence uses a separate toplevel. The signal browser learned the
   hard way that "frame inside the viewer" and "toplevel" are different features with
   different costs. Spec above assumes **toplevel**.
   **RULED 2026-08-13 by the build: toplevel.** Phase 0 shipped `.calc` as a toplevel
   (commit `99a2edfd`).
2. **Does v1 ship any N-route function** (`dft`, `psd`, `convolve`)? Each is real C work in
   `save.c`. Spec above assumes **no** — `dft` and everything above it deferred to v2. If
   `dft` is wanted, it is the single highest-value N addition and unlocks `thd`,
   `harmonic`, `spectrum`.
   **RULED 2026-08-15: no.** v1 is pure Tcl. Every N-route entry (`dft`, `psd`,
   `spectrum`, `spectralPower`, `convolve`, and the T-route verbs that stand on `dft` —
   `harmonic`, `harmonicFreq`, `thd`) is **rendered in the function browser and disabled**,
   with the same treatment as the RF selectors (§1.2): the entry is information, its
   absence would not be.
3. **Algebraic mode in v1, or RPN only?** RPN alone is far cheaper (the engine already
   speaks it) but is the unfamiliar half for a new user. `alg2rpn` is ~150 lines of Tcl and
   the most testable unit in the feature. Spec above assumes **both**.
   **RULED 2026-08-15: both.** RPN stays the default and the only thing that reaches the
   engine; `calc::alg2rpn` translates on the way in (phase 8, R521–R525).
4. **Where do measurements land long-term** — ASE-L outputs rows, or new named vectors via
   `xschem raw add`? R608 assumes ASE-L rows. The two are not exclusive.
5. **`user 1..4` scope** — per-user (`~/.xschem`) or per-project? Spec assumes per-user.

---

## 13. Deliberate deviations from Cadence

Record these so a future session does not "fix" them back.

| Cadence | Here | Why |
|---|---|---|
| Results Dir = a PSF directory | a `.raw` **file** path | ngspice writes one file, not a directory |
| Emits OCEAN (`VT("/out")`) | emits xschem RPN (`v(out)`) | the evaluator already exists and speaks RPN; two syntaxes would mean two parsers |
| RF selectors live | RF selectors disabled | ngspice has no S-parameter analysis; the layout is kept because the grid's shape is the tool's identity |
| Errors say "expression error" | errors name the failing token (R607) | the original's worst failure mode |
| Stack is central in RPN mode only | same | inherited deliberately, not by accident |
