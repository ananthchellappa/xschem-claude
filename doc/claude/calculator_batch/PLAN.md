# Calculator — work breakdown

**Spec:** `doc/claude/specs/calculator.md` (requirements R1xx–R7xx, referenced below by number)
**Explainer:** `doc/claude/code_analysis/viva_calculator_explained.md`
**Branch:** fluid-editing · **Status:** PLAN, no code

---

## Ordering principle

**Progressive rendering.** Like a 1998 browser painting the page: layout boxes first, then
the content in them, then the behaviour. At the end of every phase the window opens, looks
like the target, and does strictly more than it did before. No phase leaves a half-drawn
window.

Concretely:

1. **Phase 0** — the *partitions* and the *draggable dividers*. Nothing works. The window
   is a set of labelled, resizable boxes in the right proportions.
2. **Phase 1** — every real control exists in its box, correct class and initial state,
   completely inert.
3. **Phase 2–3** — the vertical slice: type an expression, press Plot, see a curve. This is
   the first moment the tool has value.
4. **Phase 4+** — fill in, one functional area at a time, cheapest-and-most-visible first.

The rule that keeps this honest: **no step may make the window worse-looking than the step
before it.** A control that exists but is inert is fine. A control that is missing because
"it's coming in phase 6" is not — stub it disabled.

---

## Pane tree — decided up front, because everything hangs off it

```
.calc
 ├── .calc.mbar                        menu
 ├── .calc.pw                          panedwindow -orient vertical    ← 3 sashes
 │    ├── .calc.pw.sel                 selectors + Results Dir + mode strip   minsize 120, -stretch never
 │    ├── .calc.pw.buf                 buffer + buffer toolbar                minsize  70, -stretch always
 │    ├── .calc.pw.stk                 Stack                                  minsize  80, -stretch always
 │    └── .calc.pw.bot                 panedwindow -orient horizontal   ← 1 sash   minsize 140
 │         ├── .calc.pw.bot.fn         function browser                       minsize 250, -stretch always
 │         └── .calc.pw.bot.pad        keypad + user buttons                  minsize 140, -stretch never
 └── .calc.status                      status line + history        (packed, outside the panes)
```

**Four sashes total.** Every functional area the user named — signal-select buttons, buffer,
stack, function area, keypad — is a pane and is resizable against its neighbours.

### House idiom (already in this repo — copy it, don't invent)

`src/xschem.tcl:7082` (`load_file_dialog`) is the working reference: nested classic
`panedwindow`, sash positions persisted in globals, restored on build.

- **Classic `panedwindow`, not `ttk::panedwindow`.** The repo uses `ttk::` for combobox and
  friends (9 files) but classic panedwindow everywhere it panes. Classic gives `-minsize`,
  `-stretch`, `-showhandle` and nesting; `ttk::panedwindow` has no `-minsize`.
- **`-stretch` is guarded**, because Tk 8.4 lacks it (`xschem.tcl:7115`):
  ```tcl
  if { ![catch {.calc.pw panecget .calc.pw.sel -stretch}] } {
    set optnever {-stretch never} ; set optalways {-stretch always}
  } else { set optnever {} ; set optalways {} }
  eval .calc.pw paneconfigure .calc.pw.sel $optnever
  ```
- **Restore = `sash mark` then `sash dragto`** (`xschem.tcl:7332-7347`), not `sash place`.
  Both idioms exist in the repo (`.ins.center` uses `sash place`, `xschem.tcl:8332`) —
  **pick `mark`/`dragto` and never mix them in one file.**
- **Save = `bind <toplevel> <Configure>`** reading `sash coord` into globals, alongside
  `wm geometry` (`xschem.tcl:7351-7363`).

### Divider landmines

| # | Trap |
|---|---|
| D1 | `sash coord` before the pane is mapped returns garbage. Restore after the window has real geometry — the reference dialog does it at the end of the build proc, after the widgets are packed. If it misbehaves, `update idletasks` before restoring, **not** `update` (which reenters the event loop). |
| D2 | `<Configure>` on a toplevel with nested panes fires per drag *and* per resize. Reading four sash coords each time is the house pattern and is cheap enough — but do not put anything expensive in that binding. |
| D3 | A pane with `-stretch always` and no `-minsize` collapses to zero on window shrink and cannot be dragged back. Every pane gets a `-minsize`. |
| D4 | Restoring a saved sash position into a *smaller* window silently clamps. Persisted positions must be re-validated against the current window size, or a laptop session poisons the desktop session's layout. |

---

## Phase 0 — Skeleton and dividers

*Goal: the window opens, shows five labelled boxes in the right proportions, and every
divider drags. Nothing else.*

| # | Step | Done when | Size |
|---|---|---|---|
| 0.1 | Create `src/calculator.tcl`, namespace `calc`, add to the Tcl file list the way `wave_viewer.tcl` is added. Proc `calc::open`. | `source`s clean; `calc::open` is callable and does nothing | S |
| 0.2 | Toplevel `.calc` — title, `wm protocol WM_DELETE_WINDOW`, single-instance guard (re-open raises the existing window, R101). | Calling `calc::open` twice yields one window, raised | S |
| 0.3 | Menubar `.calc.mbar` with the six cascades (File, Tools, View, Options, Constants, Help). Every entry present but `-state disabled`. | All six cascades post; no entry does anything | S |
| 0.4 | **The pane tree.** Build `.calc.pw` + `.calc.pw.bot` exactly as above, with `-minsize` on every pane and the guarded `-stretch`. | Four sashes exist and drag; no pane can be dragged below its minsize | **M** |
| 0.5 | Placeholder content: each pane gets a `labelframe` naming it (`Selectors`, `Buffer`, `Stack`, `Functions`, `Keypad`) and nothing else. | The window is visibly five boxes; proportions match the reference screenshot at default size | S |
| 0.6 | Status bar `.calc.status` packed **outside** the panes, at the bottom, full width. | Status bar spans the window and does not move when sashes drag | S |
| 0.7 | Sash + geometry persistence: save on `<Configure>`, restore at end of build, with the D4 clamp check. | Drag sashes → close → reopen → same layout. Reopen at a smaller screen size → no pane at zero width | **M** |
| 0.8 | Launch wiring: `Tools > Calculator` in the CIW and in the waveform viewer; action-registry entry `calculator_open`. | Both menu paths open it; the action is remappable | S |
| 0.9 | Headless test `test_calc_skeleton.tcl`: every pane path exists, is the right class, has the right `-minsize`. | Test green; sabotage — delete one `-minsize`, test goes red | S |
| 0.10 | **EYEBALL.** Under a real display, drag every sash to both extremes, resize the window, reopen. | Receipt written | S |

**Commit at 0.10.** This is the first reviewable unit.

---

## Phase 1 — Real controls, all inert

*Goal: the window is visually indistinguishable from the finished tool. Nothing responds.*

Each step replaces one placeholder labelframe with the real widgets from the spec's
W-table. All commands are `-command {}` or a stub that writes "not implemented" to the
status area.

| # | Step | Done when | Size |
|---|---|---|---|
| 1.1 | Results Dir row (W03–W05) inside `.calc.pw.sel`. | Path entry present, readonly, shows the loaded raw's path if one is loaded | S |
| 1.2 | **The 22-button selector grid** (W06–W07), two rows, laid out in the reference's four visual groups. RF block and `mp` created `-state disabled` (§1.2). | All 22 exist; the 7 disabled ones cannot be selected; `calc::selmode` is a radio variable | **M** |
| 1.3 | Mode strip (W08–W14): Off/Family/Wave radios, Clip checkbutton **defaulting on**, plot/eval/table buttons, `Append` combobox. | All present; Clip is checked at first open; combobox lists `Append Replace {New Strip}` | S |
| 1.4 | Buffer (W15) + buffer toolbar (W16–W22). Undo/redo created `disabled`. | Text widget accepts typing; toolbar buttons all present and inert | S |
| 1.5 | Stack (W23–W25): listbox + the four side buttons. | Present, empty | S |
| 1.6 | **Function browser** (W26–W28): category combobox + scrollable multi-column list, **populated from the spec §7.2 catalogue table** held as one Tcl data structure. | Switching category repopulates; `Special Functions` shows the full list with a working horizontal scrollbar | **M** |
| 1.7 | Keypad + user buttons (W29–W31). | 16 keys + 4 user buttons, correct labels | S |
| 1.8 | Status area (W32–W34) with the 50-entry history dropdown. | `calc::status "text"` writes the line and appends to history | S |
| 1.9 | Headless widget-inventory test `test_calc_widgets.tcl` covering R101–R113 — every W-row: exists, class, initial state. | Green; sabotage — flip Clip's default to 0, test goes red | **M** |
| 1.10 | **EYEBALL** against the reference screenshot. | Receipt with a side-by-side note | S |

**Commit at 1.10.** After this the tool *looks* done, which is the point — the remaining
phases are all invisible-to-visible, never layout churn.

---

## Phase 2 — The buffer comes alive

| # | Step | Done when | Size |
|---|---|---|---|
| 2.1 | Test fixture: generate `tests/headless/data/calc_fixture.raw` per spec §11.2 (tran square wave + ramp, ac single pole, >1 dataset, one op-param vector). Commit it **with its generating deck**. | Fixture loads via `xschem raw read`; `xschem raw info` shows the expected vectors | **M** |
| 2.2 | Keypad buttons insert into the buffer at the caret. | `7` then `.` then `5` gives `7.5` | S |
| 2.3 | Clear-buffer, and undo/redo enablement driven by the text widget's own `-undo` stack (R505). | Buttons enable/disable exactly when history is non-empty | S |
| 2.4 | `calc::status` fires on every buffer mutation (R506). | No silent mutation path remains | S |

---

## Phase 3 — Vertical slice: evaluate and plot

*The first moment the tool is worth opening. Everything before this was scaffolding.*

| # | Step | Done when | Size |
|---|---|---|---|
| 3.1 | `calc::rpn_of_buffer` — identity in RPN mode, the hook algebraic mode later replaces. | Returns the buffer verbatim | S |
| 3.2 | **Evaluate** (R603–R605): call the engine, then read the scratch column **in the same command**, per landmine L2. Report the value and say whether it came from the cursor or the last point. | `v(out)` on the fixture evaluates to the hand-computed number | **M** |
| 3.3 | **Plot** (R601–R602): `wviewer::add_trace <token> <gi> <rpn>`, destination from the combobox via `wviewer::set_plot_dest`. Open a viewer if none. | Typing `v(out) v(in) / db20()` and pressing Plot draws the gain curve | **M** |
| 3.4 | **Error reporting** (R607): on engine `-1`, re-test each vector-looking token with `xschem raw index` and name the one that failed. | `v(nosuch) v(in) /` reports `v(nosuch)`, not "expression error" | **M** |
| 3.5 | Headless `test_calc_engine.tcl` + `test_calc_scratch_reuse.tcl` (§11.1). | Green; sabotage — remove the re-evaluate in 3.2, `scratch_reuse` goes red | **M** |

**Commit at 3.5. Review gate.** Demo-able: open, type, plot.

---

## Phase 4 — Stack

| # | Step | Done when | Size |
|---|---|---|---|
| 4.1 | Enter / Pop / clear (R502–R504), 200-entry cap. | Push, pop, cap-drop all messaged | S |
| 4.2 | Swap / roll. | Order verified in a test | S |
| 4.3 | **RPN operator composition** (R510–R512) — the `+` button consuming two stack entries. | R511's exact case traced in a test: stack `[b, a]`, buffer empty, `+` → `[a b +]` | **M** |
| 4.4 | Undo/redo spanning buffer *and* stack as one history (R505). | Push, edit buffer, undo twice → both reversed in order | **M** |
| 4.5 | `test_calc_stack.tcl` + `test_calc_rpn_emit.tcl`. | Green; sabotage — reverse operand order, `rpn_emit` goes red | S |

---

## Phase 5 — Functions, and names without a mouse

| # | Step | Done when | Size |
|---|---|---|---|
| 5.1 | **P-route insertion** (R410): clicking a catalogue entry appends its token. | `abs()` appends with a leading space | S |
| 5.2 | Hover help from the same catalogue table (R413). | Every entry has one line; no second table exists | S |
| 5.3 | **C-route functions** — `rms`, `rmsNoise`, `dBm`, `groupDelay` as compositions of existing opcodes. | Each produces a valid RPN string; values checked against hand computation on the fixture | **M** |
| 5.4 | Argument dialog for functions needing extra args (R412), cancel leaves the buffer byte-identical. | Cancel test asserts byte equality | **M** |
| 5.5 | **`data` selector** — pick a vector *by name* from the signal-browser inventory. No canvas involvement. | Selecting `data`, choosing a name, inserts it; name verified with `xschem raw index` (R204) | **M** |

**Why `data` lands here and not in Phase 6:** it is the cheap half of "get a signal name
into the buffer" and it needs no canvas arming, no modal gesture, no pick-mode teardown.
It makes the tool fully usable one phase before the risky integration starts.

---

## Phase 6 — Picking from the schematic

*The riskiest integration. Deliberately after the tool already works.*

| # | Step | Done when | Size |
|---|---|---|---|
| 6.1 | Arm/disarm a selector (R201–R202); re-click disarms. | Radio state and status message correct | S |
| 6.2 | Voltage pick: arm `vt`, click a net, insert the resolved name (R203–R204, R207). | Name comes from the raw inventory, not from `sch_path` | **L** |
| 6.3 | Current pick: terminal hit test, refuse a net click with a message (R203). | Both refusal directions tested | **M** |
| 6.4 | Escape cancels, leaving buffer untouched (R306); register as a modal gesture so the open_pdk exclusion covers it (R307). | Pick does not survive window close | **M** |
| 6.5 | `wave` scope (R301–R302): pick a trace in the viewer, pull its stored expression **through `node_token_split()`** including any `%<dataset> <rawfile>` (landmine L5). | Cross-database trace round-trips | **M** |
| 6.6 | `family` scope + `Clip` semantics (R303–R305). Clip must never rewrite the buffer. | Two evaluations, Clip toggled: different numbers, identical buffer | **M** |
| 6.7 | Gated GUI test `test_calc_pick.tcl` replaying the **full** Tk event sequence (press/motion/release) — a synthesised click alone does not reach the handler. | Green under `run_suites.sh` | **M** |
| 6.8 | `vn2` as an expression (R205), `var` substituting its value with the substitution stated (R206). | Both messaged | S |

---

## Phase 7 — The measurement layer

*One primitive unlocks seven verbs. Build it once, carefully.*

| # | Step | Done when | Size |
|---|---|---|---|
| 7.1 | T-route plumbing (R401–R404): temp vector naming, deletion **on every exit path including error**, re-fetch after realloc (landmine L4). | `test_calc_tmpvec_leak.tcl` green including a forced-error path | **M** |
| 7.2 | **`cross`** — X at the Nth threshold crossing, with interpolation. | Hand-computed crossings on the fixture square wave, exact | **L** |
| 7.3 | On `cross`: `riseTime`, `slewRate`, `delay`, `dutyCycle`, `frequency`, `settlingTime`, `overshoot`. | Golden values for all seven | **L** |
| 7.4 | `average`, `rms`, `stddev`, `integ`, `iinteg`, `peak`. | Golden values | **M** |
| 7.5 | `bandwidth`, `gainBwProd`, `gainMargin`, `phaseMargin` against the fixture's single-pole AC dataset. | Exact −3 dB point | **M** |
| 7.6 | `clip`, `flip`, `sample`, `root`, `intersect`, `compare`. | Golden values | **M** |
| 7.7 | `test_calc_measure.tcl` covering all of the above. | Green; sabotage — off-by-one in `cross` interpolation, ≥3 verbs go red | **M** |

---

## Phase 8 — Algebraic mode

| # | Step | Done when | Size |
|---|---|---|---|
| 8.1 | `calc::alg2rpn` — pure function, precedence per R523, right-assoc `**`. | Table-driven test, ~60 pairs | **L** |
| 8.2 | Failure path (R524): name token and column, abort the action, never fall through to the engine. | 15 malformed inputs each fail with a named token | **M** |
| 8.3 | Wire it into 3.1; Options menu toggle; mode switch does **not** rewrite buffer or stack (R525). | Toggle test asserts byte equality | S |
| 8.4 | Algebraic function insertion wraps the buffer (R411). | `abs(<buffer>)`; empty buffer gives caret between parens | S |
| 8.5 | `test_calc_alg2rpn.tcl`. | Green; sabotage — swap `*` and `+` precedence, ~12 cases go red | S |

---

## Phase 9 — Memories, user buttons, persistence

| # | Step | Done when | Size |
|---|---|---|---|
| 9.1 | `M+` / `ME` (R701–R702). | Store, recall, rename, delete | **M** |
| 9.2 | `user 1..4` bind dialog (R703). | Label and expression both persist | S |
| 9.3 | `~/.xschem/calculator.state`: atomic write, defensive read, defaults on corruption (R704). | Corrupt-file test yields defaults + message, no stack trace | **M** |
| 9.4 | Confirm nothing raw-specific persists (R705). | Reopen against a different sim: no stale names presented as valid | S |

---

## Phase 10 — Finish

| # | Step | Done when | Size |
|---|---|---|---|
| 10.1 | Collapse toggles for every pane, from the View menu, state persisted (R110). | Collapse survives reopen | **M** |
| 10.2 | Table view (R606), honouring Clip. | X/Y pairs, scrollable | **M** |
| 10.3 | Constants menu → `pi() k() e() q()` insertion. | Four entries | S |
| 10.4 | **Export to ASE-L outputs** (R608), round-trippable. | Row appears in the session; sending it back restores the buffer | **L** |
| 10.5 | File menu: save/load a set of expressions. | Round-trip | **M** |
| 10.6 | Full sabotage sweep (spec §11.5, all five). | Each break turns a test red | **M** |
| 10.7 | Final eyeball + receipt; update the spec with anything the build proved wrong. | Receipt written | S |

---

## Cross-cutting rules

- **Commit at the end of every phase**, build green and suites green first. Never push
  unless told.
- **A review gate between phases** — the panel pops in the background.
- **Never `make` while suites are running** (they flake under CPU load).
- **GUI tests go through `run_suites.sh` / `gated_xschem.sh`**, never a bare loop. Press
  `Allow 30m` once before a batch rather than clicking Proceed forty times.
- **Every phase that touches pixels owes an eyeball**, not just green tests.
- The spec's §12 open decisions stay open until the driver rules. This plan assumes:
  toplevel (not an in-viewer panel), no N-route functions in v1 (`dft` deferred), both
  notations, ASE-L rows as the export target, per-user `user 1..4`.

---

## Critical path to "useful"

**0.1 → 0.10 → 1.1 → 1.10 → 2.1 → 3.5.** That is the whole of Phases 0–3: a window that
looks right, resizes right, and can type an expression and plot it. Everything after is
addition, not correction.
