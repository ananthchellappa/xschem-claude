# Next session — spec the typed signal accessors (`v(out)` → `VT(out)`)

Paste everything below the line as the opening prompt of a new session.

---

Write **one spec** — `doc/claude/specs/typed_signal_accessors.md`. Spec only: no
code, no test files, no PLAN.md. Branch `fluid-editing`. Commit when done; **do
not push**.

## What this is

xschem plots signals as `v(out)`. That is ngspice's own vector name and it says
nothing about which analysis produced it. One simulation run can leave a DC sweep
and a transient loaded at the same time, and `v(out)` resolves in both with
different numbers. Cadence removes the ambiguity by putting the analysis into the
expression: `VT("/out")` for transient, `VS(...)` for DC sweep, `VDC(...)` for the
operating point. We are moving to that, in xschem spelling.

This is not only a Calculator change. It touches schematic graph boxes, Ctrl-4,
`Results ▸ Direct Plot`, the signal browser and the Calculator.

## Read first, in this order

1. `doc/claude/specs/results_selection.md` — **§19 is your brief.** It carries the
   nine rulings already taken and the two measured facts below. §17.1 rules the
   result model this sits on top of ("one run produces one result; analyses are
   dimensions inside it"). Read §1.2's F-facts too.
2. `doc/claude/specs/calculator.md` — §7 (the function catalogue), §9 (R606,
   Table), R204, R601–R607. The Calculator is the biggest consumer.
3. `doc/claude/code_analysis/waveform_subsystem_reference.md` — the house
   explainer for the whole waveform stack. Do not re-derive what it states.
4. `doc/claude/specs/hierarchy_editor.md` — copy its **structure**: §0
   one-paragraph version → §1.1 a `Cadence capability | xschem today | Evidence`
   table closed by a prose **Score:** sentence → §1.2 the architectural facts the
   design must respect → … → a `Design decisions that can change` table with an
   "if reversed, redo" column → a verification-invariant table → non-goals.
5. `doc/claude/specs/simulator_profiles.md` §8 and §14.7 — the four-status resolver
   shape and the "name the bypassing call sites with file:line" idiom.

Conventions: banded R-numbers, `L#` landmines, `D#` decisions, `T-<letter>`
verification invariants. **Nothing is ever renumbered.** Every claim carries a
`file:line`. Add the standing disclaimer that line numbers drift and the symbol
should be grepped.

## The rulings — already taken, do not re-ask

From the user, 2026-08-18, recorded in `results_selection.md` §19:

| # | ruling |
|---|---|
| A1 | Its own spec and batch, **after** Results Selection. Calculator item 8 ships speaking `v(out)`. |
| A2 | **Spelling: xschem paths, no quotes** — `VT(out)`, `VT(x1.x2.net5)`. Cadence's quoted `VT("/x1/x2/net5")` is **not** copied: nothing else in xschem quotes a node name, and the expression engine splits on whitespace. |
| A3 | **Full set in v1:** voltage and current, all four analyses — `VT`/`VS`/`VF`/`VDC` and `IT`/`IS`/`IF`/`IDC`. |
| A4 | **`v(out)` keeps working**, meaning "the current analysis", so saved schematics keep rendering. But **nothing the tool emits uses it any more** — every generated expression is typed. |
| A5 | **`VF(out)` alone is the magnitude.** |
| A6 | **Add the Cadence wrapper names** `mag` / `phase` / `real` / `imag`. The existing `ph()` / `re()` / `im()` spellings keep working. |
| A7 | **Rewrite the 24 tracked schematics** carrying `v(...)` inside a `node=`. Each graph box already records its own `sim_type=`, so the right accessor is known without guessing. |
| A8 | **Direct Plot** detects which analyses the run produced and offers the choice; with only one it plots straight away — but **always emits the typed accessor**, never `v()`. ASE-L knows the analysis. |
| A9 | **Ctrl-4 is not Direct Plot.** It is the transient bindkey. If cheap, let Ctrl-4 also work when a run contains exactly one analysis, whatever that analysis is. Cadence restricts it to transient; xschem need not. |

## Measured facts to start from — verify, do not re-derive

Each was measured on `58b2c24d`. Re-check anything you lean on hard.

1. **The token shape already exists.** The RPN engine has ~40 ops spelled
   `name()` — `sin()`, `db20()`, `del()`, `re()`, `im()`, `cph()` … dispatched
   around `src/save.c:3560-3612`. A bare token that is not an op is looked up as a
   **vector name** via `get_raw_index()` (`src/save.c:3406`). So `VT()` fits the
   existing grammar. **This is a resolver layer, not a parser rewrite** — say so in
   §0, because it is the fact that makes the work affordable.
2. **AC is already split into four real vectors at read time.** Measured on
   `tests/headless/.scratch/0211/work/run_new/cmos_ac_sweep/cmos_ac_sweep_ase.raw`:
   the names are `frequency`, `ph(frequency)`, `re(frequency)`, `im(frequency)`,
   `i(@ibias[current])`, `ph(i(@ibias[current]))`, … So for AC, **`v(out)` is
   already the magnitude**, and phase/real/imag already exist as named vectors.
   `mag`/`phase`/`real`/`imag` each compile to a name already in the file — there
   is no complex object to carry.
3. **⚠ `re()` and `im()` are two different things with one spelling.** As *vector
   names* they are the real/imaginary parts the reader produced. As *RPN operators*
   (`src/save.c:3819-3826`) they pop **magnitude and phase-in-degrees** and convert
   to rectangular. The spec must state which one an expression means and how the
   resolver tells them apart. This is landmine number one.
4. **One run = one result, and analyses are separate registry slots.** Measured on
   a file holding both a DC sweep and a transient:
   ```
   0  /…/multi.raw  dc
   1  /…/multi.raw  tran      <- current
   ```
   Both load at once; the identity key is `(rawfile, sim_type)`. `VT()`/`VS()`
   therefore pick a slot **that already exists** — likely compiling to the existing
   `%<dataset> <rawfile> <sim_type>` node-token suffix parsed by
   `node_token_split()`. Check whether that is the right compilation target before
   inventing a new one.
5. **The analysis type is already recorded, just elsewhere.** Graph rects carry
   `sim_type=` — across tracked schematics: 100 `tran`, 35 `ac`, 26 `dc`, 6
   `distrib`, 3 `op`, 1 `foo`. The accessors move that fact into the expression.
   Decide what happens when a graph's `sim_type=` and its expression's accessor
   **disagree**; that case is new and nothing handles it today.
6. **Migration surface:** 24 tracked `.sch` carry `v(...)` inside a `node=`; 420
   `v(...)` occurrences across all tracked `.sch`.

## What the spec must answer

- **The grammar.** Exact token form, what is legal inside the parentheses
  (hierarchical paths, buses, `@`-device currents like `i(@m.xm1…[id])`), and what
  a malformed accessor reports. Name which existing token the resolver compiles to.
- **The resolution ladder**, in the shape of `get_raw_index()`'s existing ladder:
  accessor → analysis → registry slot → vector name → the case-folding rungs the
  casemode work added. Where does it refuse, and what does the message say?
- **The wrapper set** (A5, A6): what `mag`/`phase`/`real`/`imag`/`db20` mean when
  applied to each accessor, and what they mean applied to a *non*-AC accessor —
  `phase(VT(out))` has to do something, even if that something is a refusal.
- **Current accessors** (A3): `IT`/`IS`/`IF`/`IDC`. ngspice spells currents several
  ways (`i(vmeas)`, `i(@m.xm1.…[id])`); state which spellings the accessor accepts
  and whether it normalises them.
- **The emit side** (A4, A8, A9): every place that *generates* an expression today
  — Direct Plot, Ctrl-4, the signal browser's send-to-graph, the Calculator's
  insert paths, `wviewer::add_trace` — and what each emits after the change. This
  is the half that makes the transition real; enumerate the sites with `file:line`
  the way `simulator_profiles.md` §14.7 does.
- **The migration** (A7): how the 24 schematics are rewritten, whether it is
  scripted or hand-checked, and what proves the rewrite did not change what they
  plot. Golden-output regeneration is in scope for the plan.
- **Backward compatibility** (A4): where exactly `v()` is still accepted, what
  "the current analysis" resolves to when two slots are loaded, and how a reader
  of a saved file can tell which spelling they are looking at.
- **Verification invariants** (`T-A`…), each with the sabotage that reddens it.
  A grep test that no emit site produces `v(` is worth having.

## Ask the user before finalising

Put these in an "Open decisions" section and **ask them with worked examples** —
the last round showed the user answers precisely when the question is concrete and
pushes back hard when a premise is wrong:

1. What does a wrapper mean on the wrong analysis — `phase(VT(out))`? Refuse, or
   compute from the data that exists?
2. When a graph rect's `sim_type=` disagrees with its expression's accessor, which
   wins? (New case, no precedent.)
3. Are `VT`/`VS`/`VF`/`VDC` case-sensitive as typed? Cadence is. xschem's node
   lookups have a whole case-mode subsystem behind them
   (`doc/claude/specs/raw_case_mode.md`) — do not collide with it by accident.
4. Buses and hierarchy: does `VT(x1.dbus[3])` work, and does the accessor descend
   the same way `node_token_split()` does?
5. Is `A9`'s "Ctrl-4 on a single non-transient analysis" wanted, given it makes one
   key mean different things in different runs?

## Discipline

- **Every claim gets a `file:line`, and you open the line before citing it.**
  Cross-file citations *inside source comments* in `wave_viewer.tcl`,
  `calculator.tcl` and `ase.tcl` were measured to be systematically stale — never
  copy one without re-grepping.
- **Run an adversarial verification pass over your own draft before committing.**
  The `results_selection.md` draft came back with **55 confirmed errors**, four of
  them material — including a shipped verb the first draft claimed did not exist.
  Budget for that pass; it is not optional.
- Prefer measuring to reasoning. `./src/xschem --nogui --pipe -q --script <file>`
  answers most questions in seconds. For GUI legs use the dev display
  (`tests/headless/devdisplay.sh start`), never a bare `:0` run.
- Do not write code. Do not write a PLAN.md unless the user asks. Do not push.
