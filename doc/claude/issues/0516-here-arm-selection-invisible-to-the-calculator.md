# 0516 — a result selected through `Results ▸ Select…`'s `here` arm is invisible to the Calculator

**Status:** OPEN — filed 2026-08-20 by the results batch item-10 fixer round.
**Branch:** `fluid-editing`. **Filed at the next free number ≥ 0500.**
**Specs:** `doc/claude/specs/results_selection.md` R407a (§6.1), R503f (§7.1a),
§17 decisions 6 and 7 (U6, U7).
**Ruling required from:** the driver, and ultimately the user — **U6 is a user
ruling and a crew agent may not overturn it.**

## What happens

Two items of the same batch, both correct on their own terms, collide.

* **Item 7 / R407a** gives the ASE-L `Results ▸ Select…` dialog **three arms**:
  it borrows the session's waveform viewer when the session has one, it reads
  **the current context** when it has not (the `here` arm), and it reports a
  refused ticket as a refusal. The `here` arm was ruled in deliberately, and the
  recorded justification is verbatim: *"Refusing to work at all in the `here`
  arm was rejected: 'evaluate against last night's raw' happens BEFORE a run,
  which is exactly when no viewer exists."* That sentence names the Calculator's
  Evaluate.
* **Item 10 / U6** removes the Calculator's `self` arm **entirely, not
  demoted**: the Calculator reads the ASE-L session's result and nothing else,
  and must never evaluate against a raw a legacy path dropped into a schematic
  window's context.

So a selection made through the batch's **own door**, in the `here` arm, lands
in the host window's context — which the Calculator does not read. The row says
there is no result, and Evaluate refuses.

## Reproducer

Measured by a reviewer on the working tree with **no repo edit**, run as
`tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --script drive_here.tcl`,
with `::update_recent_files` forced 0 and `rawhist_write` / `write_recent_file` /
`update_recent_file` shimmed:

```tcl
xschem load <tmp>/cellA.sch
results::select <tmp>/an.raw tran [dict create host ase]   ;# R303's ONE gesture, the `here` branch
calc::open
```

Observed:

```
results::select how  = read ; msg = "Selected an.raw (tran)."
results::current     = idx 0 path <tmp>/an.raw type tran cur 1 label {an.raw (tran)}
calc::viewer_tokens  = {}
calc::results_source = none {} {}
.calc.res.path get   = "(no raw file loaded)"        <-- FALSE: one IS loaded and selected
calc::require_result = ok 0 origin none path {} msg {No simulation results are loaded.
                       Run a simulation, or pick an existing one with ASE-L ▸ Results ▸ Select.}
```

A/B: with `git show HEAD:src/calculator.tcl` sourced over the new file at
runtime the identical drive gives `calc::results_source = self <tmp>/an.raw {}`
and the row shows the full path — so the state is introduced by item 10's U6
removal, not pre-existing.

## Why it is not fixed here

Three candidate resolutions were on the table (reviewer's ranking):

1. **file it and have the driver/user rule** — taken;
2. `calc::session_result` gains a LAST arm that asks `results::current` in the
   current context **only** when `calc::viewer_tokens` is empty — R407a's `here`
   arm mirrored. **This is what U6's words forbid** (*"removed entirely, not
   demoted"*), and the reviewer who proposed it said outright that it needs the
   user's word;
3. **at an absolute minimum, U7's sentence must not be emitted in a state where
   the gesture it names has already been performed and cannot help** — **DONE**,
   see below.

## What the item-10 fixer round DID do — crew ruling R503f

`src/calculator.tcl` gains `calc::sessions_without_viewer`,
`calc::no_viewer_msg` and `calc::no_result_advice`. The test is **structural**:
is there a live ASE-L session with no waveform viewer window
(`wviewer::window_for` — exactly R407a's `here` precondition)? It reads **no
database**, opens **no context**, and hands Evaluate **nothing**; Evaluate still
refuses. What changes is only the sentence, which now names the obstacle
instead of asking for a gesture that cannot help:

> The ASE-L session has no waveform viewer, and the Calculator reads the
> session's viewer — a result selected while the session has no viewer is not
> visible here. Run a simulation, or open the session's waveforms and then pick
> a result with ASE-L ▸ Results ▸ Select.

Both steps of that door are real: with a viewer open `ase::ui::rsel_borrow`
takes its `viewer` arm and `rsel_commit` passes `token $key`, selecting inside
the borrowed context — which is where `calc::session_result` looks.

Pinned by `tests/headless/test_calc_skeleton.tcl` S27 (five legs, including the
discriminating positive control: the same session **with** a viewer gets U7's
ruled sentence back), sabotaged in both directions.

## What is still owed

**A ruling on whether R407a's `here` arm survives at all**, and if it does,
whether the Calculator may read the current context when — and only when — a
live ASE-L session has no viewer. Until then a user who selects a result with no
viewer open cannot evaluate against it from the Calculator; they are told why,
and they are told a route that works.
