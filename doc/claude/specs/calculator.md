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
| Complex | `re()` `im()` `cph()` (continuous phase — unwrapped, no ±180 jumps) |
| Calculus | `integ()` `deriv()` `deriv0()` `deriv2()` `deriv20()` |
| Statistics | `avg()` `ravg()` (running average) |
| Clipping | `max()` (clip above arg) `min()` (clip below arg) |
| Sequence | `prev()` (previous point) `del()` (delay by X-axis distance) `idx()` (point index) |
| Stack | `dup()` `exch()` |
| Constants | `pi()` `k()` (Boltzmann) `e()` `q()` (electron charge) |

`deriv0()`/`deriv20()` differentiate against the **first** sweep variable regardless of the
graph's `sweep_idx`; `deriv2()`/`deriv20()` are 3-point. `integ()`, `deriv*()`, `prev()`
and `del()` each **widen the evaluation window backwards** (they decrement `first`), so a
clipped range silently reads one or two points before its start. Any measurement built on
them must not assume the window is exactly what it asked for.

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

| Id | Path (under `.calc`) | Class | Contents / initial state |
|---|---|---|---|
| W01 | `.calc` | toplevel | title `xschem Calculator` |
| W02 | `.calc.mbar` | menu | cascades: File, Tools, View, Options, Constants, Help |
| W03 | `.calc.res` | frame | collapsible; collapse toggle `.calc.res.tog` |
| W04 | `.calc.res.lab` | label | `Results Dir:` |
| W05 | `.calc.res.path` | entry | full path of the loaded raw; readonly unless edited via Browse |
| W06 | `.calc.sel` | frame | the 22-button radio grid |
| W07 | `.calc.sel.<id>` | radiobutton | one per §5 row; variable `calc::selmode` |
| W08 | `.calc.mode` | frame | mode strip |
| W09 | `.calc.mode.off/.family/.wave` | radiobutton | variable `calc::pickscope`, initial `off` |
| W10 | `.calc.mode.clip` | checkbutton | variable `calc::clip`, **initial 1** |
| W11 | `.calc.mode.plot` | button | plot buffer |
| W12 | `.calc.mode.eval` | button | evaluate buffer |
| W13 | `.calc.mode.dest` | combobox | values `Append Replace {New Strip}`, initial `Append` |
| W14 | `.calc.mode.table` | button | show as table |
| W15 | `.calc.buf` | text | **the buffer**; height 4, editable, `-undo 1` |
| W16 | `.calc.btb` | frame | buffer toolbar |
| W17 | `.calc.btb.enter` | button | push buffer → stack |
| W18 | `.calc.btb.pop` | button | text `Pop` |
| W19 | `.calc.btb.swap` `.roll` `.clrbuf` `.clrstk` | button | stack/buffer edits |
| W20 | `.calc.btb.mplus` | button | text `M+` |
| W21 | `.calc.btb.me` | button | text `ME` |
| W22 | `.calc.btb.undo` `.redo` | button | initial state `disabled` |
| W23 | `.calc.stk` | labelframe | text `Stack` |
| W24 | `.calc.stk.list` | listbox | top of stack = index 0 |
| W25 | `.calc.stk.push/.pop/.del/.recall` | button | the four side buttons |
| W26 | `.calc.fn` | frame | function browser |
| W27 | `.calc.fn.cat` | combobox | §7 categories; initial `Special Functions` |
| W28 | `.calc.fn.list` | multi-column list | horizontally scrollable |
| W29 | `.calc.pad` | frame | keypad |
| W30 | `.calc.pad.k<n>` | button | `7 8 9 / 4 5 6 * 1 2 3 - 0 ± . +` |
| W31 | `.calc.pad.u1..u4` | button | `user 1`..`user 4` |
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
- **R113** Follow existing xschem dialog theming (`src/resources.tcl`). Do **not**
  hand-set colors; a Cadence-red accent is not required and must not be hardcoded.

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
| `lshift` | wave | shift along X | C (`del()` with negative arg) or T |
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
| `groupDelay` | wave | −dφ/dω | C (`cph() deriv()`, negated) |
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
   different costs. Spec above assumes **toplevel**. Confirm.
2. **Does v1 ship any N-route function** (`dft`, `psd`, `convolve`)? Each is real C work in
   `save.c`. Spec above assumes **no** — `dft` and everything above it deferred to v2. If
   `dft` is wanted, it is the single highest-value N addition and unlocks `thd`,
   `harmonic`, `spectrum`.
3. **Algebraic mode in v1, or RPN only?** RPN alone is far cheaper (the engine already
   speaks it) but is the unfamiliar half for a new user. `alg2rpn` is ~150 lines of Tcl and
   the most testable unit in the feature. Spec above assumes **both**.
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
