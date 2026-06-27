# Phase 3d — bulk key migration: tutorial notes

Companion to `design_phase3d1_tcl_backed_actions.md` (the full design) and
`tutorial_action_registry_phase3c_key_routing.md` (the 3c key-routing machinery).
This file collects the *transferable lessons* per 3d step.

## d1 — Tcl-command-backed actions (commit `11744529`)

3c migrated keys whose behavior was C (each got an `act_*` function). But most of
the switch's command keys are a single `tcleval("…")` — wrapping each in a throwaway
C function would be ~60 lines of boilerplate. d1 lets an action id resolve to a Tcl
command instead.

### The model change is tiny; the gotcha was in the *validator*

The action gains a `tcl` field — "exactly one of `fn`/`tcl` is non-NULL" — and the
dispatch becomes three lines:

```c
if(d->fn)  return d->fn(e);
if(d->tcl) { tcleval(d->tcl); return 1; }
```

The non-obvious part: `xschem bind` validated an action id with
`if(!lookup_action_fn(id)) reject;`. That conflated **two different questions** —
"does this id exist?" and "does it have a C function?" — which were the same thing
until Tcl-backed ids appeared. A Tcl-backed id has *no* C function, so the old check
would have rejected a perfectly valid binding. Fix: introduce `find_action_def`
(returns the def, or NULL only when the id is truly unknown) and validate existence,
not fn-presence.

> **Lesson:** when you add a second backing kind, audit everywhere the *old* kind was
> used as a stand-in for a more general property. "Has a C fn" silently meant "is a
> real action"; splitting the model splits that meaning.

### `B` — the first case to vanish entirely

`B` was the ideal proof key because 3c had already moved its *routing* to the table,
leaving only `tcleval("update_schematic_header")` in the switch — a pure global
command, no semaphore guard, exact chord. Finishing it (register
`sch.edit_header → "update_schematic_header"`, add the canvas row) let the **entire
`case 'B'` be deleted**. That is the template d2 repeats: a key leaves the switch
once *every* chord it handled is a table row.

### Testing a Tcl-backed action without its dialog

`update_schematic_header` opens a dialog — useless in a headless test and a hang
risk. Stub it: `proc update_schematic_header {} { incr ::hdr_calls }`, then assert
the counter moves on a canvas `B` and *doesn't* on an over-graph `B` (forwarded).
Same trick will test most d2 command keys: replace the real proc with an observable
counter.

### What d1 deliberately did NOT solve (so d2 doesn't over-reach)

- **Context-dependent commands** — a Tcl action ignores the `ActionEvent`, so it
  can't pass mouse x/y. Place-at-cursor commands need a substitution mechanism or a
  C wrapper; defer.
- **Semaphore-gated commands** (`n`, `Ctrl+n`, and the 6 chords deferred from 3c) —
  need **d1b** (`idle_only`, checked before `current_input_ctx`) first.
- **`actions.csv` unification** — the default Tcl rows live in C for now; sourcing
  them from CSV is **d4**.

So d2's eligible-now set is exactly: **pure-global `tcleval` branches with no
semaphore guard.** Start there — but mind the canvas-only subtlety below.

## d2 — canvas-only command keys (commits `525bc94f` refinement, `dd0e5909` batch 1)

`B` was *graph-routed* (it had an `over_graph` row), so the dispatch's
`current_input_ctx()` call matched its original `waves_selected` guard. The next
clean keys (`H`, Alt-`h`) are **canvas-only** — they never forwarded to a graph — and
that exposes a gap.

### The canvas-only bug, and the one-line-idea fix

The DEV_KEY dispatch computed `ae.ctx = current_input_ctx(...)` for *every* bound
chord. `current_input_ctx` calls `waves_selected`, which (a) has side effects and (b)
returns `ACTX_OVER_GRAPH` when the pointer is over a graph. For a canvas-only key
whose case you just deleted, that means: pointer over a graph → ctx `OVER_GRAPH` → no
`over_graph` row → fall through → no case → **the key silently does nothing**.

Fix: consult the graph context **only when the chord actually has an `over_graph`
row**.

```c
ae.ctx = find_binding(DEV_KEY, (int)key, kmods, ACTX_OVER_GRAPH)
         ? current_input_ctx(event, key, state, button)   /* graph-routed, as before */
         : ACTX_CANVAS;                                    /* canvas-only: no waves_selected */
```

This is behavior-equivalent for every key that existed before it (they all had
`over_graph` rows), and it's the prerequisite that makes canvas-only migration both
correct and side-effect-free. **Lesson: a uniform "always compute context" is wrong
once some actions have no graph context — compute it only where it can matter.**

### Batch 1: one whole case + one branch, both backing kinds

- `case 'H'` → deleted whole. Two **C-backed** acts (`attach_labels_to_inst(1)`,
  `make_schematic_symbol_from_sel()`) — call the exact C functions the switch did, not
  the Tcl menu equivalents, so behavior is identical.
- Alt-`h` (`schpins_to_sympins`) → **Tcl-backed**; the branch is deleted but `case 'h'`
  stays (it still owns the modal constrained-drag and Ctrl-h launcher). `EQUAL_MODMASK`
  is `Alt|Super`, so it becomes **two** rows (`Mod1Mask`, `Mod4Mask`) — the family
  lesson from §9 again: one source condition can map to several exact rows.

### Testing canvas-only keys

You can't stub a C action, but you can stub the Tcl one: `proc schpins_to_sympins {}
{ incr ::n }`. The decisive check is pressing Alt-`h` **over a graph** and asserting it
*still runs* — that's the bug the refinement prevents, and a plain canvas press
wouldn't catch it.

### Batch 2 — five C-backed command keys (commit `9a8e517a`)

`y` (toggle stretch), `G`/`g` (snap double/half), `T` (`toggle_ignore`), `O` (toggle
colorscheme). Two reusable lessons:

- **A migrated action must not depend on `handle_key_press` parameters.** `G`/`g`
  used the `c_snap` param and `y` toggled the `enable_stretch` param. An `act_*` fn
  doesn't receive those. The fix is to read the *source of truth* the parameters were
  derived from: `c_snap = tclgetdoublevar("cadsnap")` and `enable_stretch =
  tclgetboolvar("enable_stretch")` (both set at the top of `callback()`). Bonus
  catch: `y`'s local `enable_stretch = !enable_stretch` was **dead code** — the
  function returns right after, so only the `tclsetboolvar` mattered. Always check
  whether a local mutation actually escapes before faithfully "preserving" it.
- **Test C-backed actions through the state they change.** No stub needed: `y`→
  `enable_stretch` flips, `O`→`dark_colorscheme` flips, `G`×2 then `g`÷2 round-trips
  `cadsnap`. Only `toggle_ignore` (operates on selection) lacks a clean observable —
  assert the row exists and that it dispatches without error.

Cases `y` and `G` deleted whole; `g`/`T`/`O` kept their `case` (the Ctrl/Alt branches
do semaphore-manipulating loads or dialogs — deferred to d1b/later).

### Batch 3 — four command keys, the first id-reuse, and a graph-routed whole-delete (commit `9687d033`)

`A` (toggle show-netlist), `L` (toggle orthogonal wiring), `=` (Tcl console), `$`
(toggle pixmap drawing). Three new lessons:

- **A graph-routed key can still be whole-deleted.** Earlier whole-deletes (`B`, `H`,
  `y`, `G`) were canvas-only or already-data. `A` was **Group-B graph-routed** — it
  kept an `over_graph -> graph.forward` row while its canvas behavior stayed in the C
  switch. Adding the *canvas* row (`view.toggle_show_netlist`) makes the key fully
  data, so `case 'A'` deletes — **but the over_graph row stays**, so the dispatch keeps
  computing `current_input_ctx()` for `A` (over a graph it still forwards). The only
  reason the case could vanish cleanly: its `rstate==ControlMask` branch was already a
  **canvas no-op** (comment-only; the Ctrl graph cursor is the over_graph row's job).
  Lesson: "whole-delete" needs *every* chord the case handled to be data **or** a
  no-op — graph-routing doesn't block it, a live second canvas branch does.
- **First reuse of an existing `actions.csv` id.** `=` maps to the csv's
  `tools.execute_tcl_command` (tcl `tclcmd`). Batches 1–2 coined new C-only ids; here
  the id already existed in the csv, so the registry row just references it Tcl-backed.
  The d1 validator fix (existence, not fn-presence) is what lets a csv/Tcl id bind.
- **Don't reuse an id whose semantics differ — even if the name fits.** `Z` (Shift+Z
  zoom-in) was the obvious 5th key, but the csv maps `view.zoom_in` → Shift+Z →
  `view_zoom(0.0)` while the C registry **already** binds `view.zoom_in` =
  `view_zoom(CADZOOMSTEP)` to the mouse **wheel**. Same id, two behaviors. That's a d4
  csv/C *reconciliation*, not a migration — picking it would force a colliding or
  duplicate id. Deferred. (Also deferred: `%`/`_`, which are *unconditional* — no mod
  guard — so a whole-case-delete would silently drop their modified-press behavior.)

Test note: `A`/`L` round-trip their tcl vars (`netlist_show`, `orthogonal_wiring`);
`=` stubs `proc tclcmd` as a counter; `$` toggles a C-only flag (`draw_pixmap`, no tcl
var) so it only asserts dispatch-without-error (the `toggle_ignore` pattern). The
existing Group-B `A` checks had to be **narrowed**: the old "Group B has no canvas
rows" assertion explicitly excluded `key 65` once `A` gained its canvas row.

## d1b — semaphore `idle_only`, the gate that unblocks the sem-gated set (commit `c806149d`)

After batch 3 the *clean* canvas command keys were exhausted; ~75 switch branches were
still gated by `if(xctx->semaphore >= 2) break;` and couldn't migrate because the top
DEV_KEY dispatch runs **before** any per-branch sem check. d1b makes
semaphore-sensitivity a data property.

### The one structural insight: a flag checked at the *right place in the order*

The dispatch already had a gate (`key_chord_has_binding`). d1b adds one term:
```c
if(key_chord_has_binding(key, kmods) &&
   !(xctx->semaphore >= 2 && key_chord_is_idle_only(key, kmods))) { ...dispatch... }
```
The whole trick is **where** the check sits: *before* `current_input_ctx`
(=`waves_selected`, side-effectful). The old branch order was `if(sem>=2)break;` *then*
`if(waves_selected){...}`. So at `sem>=2` the old code did nothing **and** never touched
`waves_selected`. The gate must reproduce *both*: skip the action **and** skip the
side-effectful context probe. A flag checked *inside* `dispatch_input_action` (after
`current_input_ctx` already ran) would be too late. **Lesson: when a guard's value comes
from its position relative to a side effect, the migrated check must occupy the same
position — not just compute the same boolean.**

### Make the property first-class (settable + dumpable), not just internal

`idle_only` lives on `InputBinding`, but it's also exposed: `bindings dump` appends
` idle`; `xschem bind … [idle]` sets it. Two payoffs: (1) d3's cheat-sheet and d4's CSV
loader will need to read/round-trip it, and (2) it makes the gate **testable without the
real chords** — their canvas ops (make-symbol dialog, save) are destructive. The test
binds an *unused* key idle_only to a Tcl-backed counter and drives `xschem set semaphore`:
fires at 0, skipped at 2. A non-idle rebind of the same key still fires at 2 (proves the
gate doesn't over-reach). Exposing the flag turned an untestable behavior into a clean one.

> Bug caught by making it settable: the `set_input_binding` *replace* path only updates
> the action id, so re-binding a row left `idle_only` stale. Fixed `xschem bind` to set
> `idle_only` to the requested value explicitly (flips both ways), not only when `idle`
> is present.

### Migrate only what the data model can express

The deferred set was "6 sem-first chords"; only **4** were actually migratable. plain `s`
and `Ctrl+r` are *also* `cadence_compat`-gated — their `waves_selected` forward lives
*inside* a mode-conditioned branch (simulate-vs-snapped_wire / simulate-only-in-cadence).
An unconditional over_graph row would forward in the *wrong* mode. The binding table has
no `cadence_compat` axis, so they stay in C. **Lesson: re-derive the migration set from
the code, not from the earlier plan's count — a chord guarded by a condition the table
can't represent isn't migratable just because it's sem-gated.** (This is the same family
as the Z/`view.zoom_in` deferral: the table can't yet express the distinguishing axis.)

## d2 sem-gated batch 1 — the idle_only gate's first real use (commit `ac558252`)

`n` (netlist + clear), `U` (redo), `u` (undo) — the first **fully-migrated** sem-gated
command keys. Each branch was `if(sem>=2)break; <behavior>`; migrating it is now
mechanical: add an `idle_only` **canvas** row → the action, delete the case/branch. At
`sem>=2` the dispatch skips (→ no case, or the case's own surviving `if(sem>=2)break`).

### Two reusable lessons

- **Reuse a csv id only after verifying the Tcl command equals the C branch — but here
  it provably did, for a satisfying reason.** All four reuse existing `actions.csv` ids
  (`toolbar.netlist`, `file.clear_schematic`, `edit.redo`, `edit.undo`). `n` is the
  cleanest case: the switch *already* did `tcleval("xschem netlist -erc")`, so a
  Tcl-backed action running the same string is byte-identical by construction — no
  divergence risk at all. `U`/`u` needed a real check against `scheduler.c`: `xschem
  redo|undo` = `pop_undo(1|0, 1)`, `xschem redraw` = `draw()` — matches `pop_undo(1,1);
  draw()`. Contrast `e`, which looked equally reusable but **wasn't**: `xschem descend`
  = `descend_schematic(0,0,0,1)` while the key calls `(0,1,1,1)`, and `xschem go_back`
  adds an internal `semaphore==0` check the C `go_back(1)` lacks. **Lesson: "there's a
  menu command that looks like this key" is a hypothesis, not a fact — read the
  scheduler branch. Some match exactly (reuse Tcl), some don't (write a C act or defer).**

- **A sem-gated test needs a reversible, observable mutation — undo/redo is the natural
  one.** The d1b probe proved the *mechanism*; this batch proves the gate on *real keys*
  by mutating then driving them: `select_all; delete` (instances 10→0, pushes undo),
  then `u` at `semaphore=2` leaves it at 0 (skipped), `u` at `0` restores 10 (fires),
  `U` redoes back to 0. Observable via `xschem get instances`; fixture restored at the
  end; semaphore reset to 0 (leaving it high wedges later checks). The destructive
  siblings (`clear schematic` dialogs; `netlist -erc` writes files) are asserted by
  their *data rows* only — not key-pressed.

### What's still in the switch after this

The remaining sem-gated keys split into: (a) explicit-guarded clean ones (more of these
batches — `j`/`k` hilight, `Q` edit-attrs, etc., each needing its observable or a stub);
(b) *unconditional* symbol keys (`&`,`>`,`<`,`?`,`/`,`*`) — additive-only, can't
whole-delete (modified-press caveat); (c) semaphore-manipulating ones (`q` quit, `o`
load, the `e`/`I` *-in-new-window branches) that need more than a skip-when-busy flag.

## d2 sem-gated batch 2 — the hilight cluster `k`/`K`, idle + non-idle on one key (commit `107c1524`)

Two whole-case deletes (`k`, `K`), all five chords reusing existing `actions.csv` ids
(`xschem hilight`/`unhilight`/`unhilight_all`/`hilight drill`/`select_hilight_net`) —
each verified byte-identical to the switch branch *including* the `redraw_hilights(0)`/
`draw()` tail (read the scheduler branch; the redraw matters).

- **A key can mix idle and non-idle chords.** `k` plain/Ctrl are sem-gated (idle_only),
  but `k` Alt (`select_hilight_net`) has **no** `if(sem>=2)break;` → a **non-idle** row.
  The gate is per-chord (`key_chord_is_idle_only(code,mods)`), so at `sem>=2` the idle
  chords are skipped while Alt-`k` still fires — matching the old switch exactly. Use
  `set_input_binding` vs `set_input_binding_idle` per chord, not per key.
- **`EQUAL_MODMASK` → two rows, and `select`-driven ops aren't mouse-driven.** Alt =
  `EQUAL_MODMASK` = `==Mod1 || ==Mod4` → seed both `Mod1Mask` and `Mod4Mask`. And
  `hilight_net` reads the **selection** (`rebuild_selected_array`), not the pointer — so
  it's table-migratable (an action gets no mouse coords). Always check *what a command
  reads* before assuming it's mouse-bound.
- **Test a hilight via `bbox_hilighted`.** It's `-100 -100 100 100` when nothing is
  hilighted and a real bbox otherwise — a clean observable: `select instance 0`, then
  `k` skipped at `sem=2` / fires at `sem=0`, `K` clears. (Like batch 1's undo/redo via
  instance count: sem-gated tests want a reversible, gettable state.)

> Cosmetic gap surfaced (not fixed here): `mods_name` in `bindings dump` doesn't render
> `Mod4Mask` (Super) — those rows print mods `0`. The binding *works* (find_binding uses
> the stored mods); only the dump string is wrong. Pre-existing since Alt-`h`. Fix when
> d3 builds the cheat-sheet from the dump (and teach `parse_mods` "super"/"mod4" too).

## d3 — the cheat-sheet becomes a view of the live table (commits `d8cf32bd`, `2c8d9e16`)

(Chronicled fully in the refactor plan / lessons; the short version.) `generate_
keybindings_text` stopped reading the decorative `accel` column and now renders
`xschem bindings dump` — the truth the C dispatch actually uses — joining `actions.csv`
only for human labels. Building the view forced the `mods_name` Mod4/Super fix (d3a)
and surfaced the full list of bound-but-unlabeled C ids: the d4a work-list, for free.

## d4 — actions.csv labels every bound id; bindings load from files (commits `7cb366f1`, `99564587`)

The closing move of the "single source of truth" thread, in two halves.

**d4a (`7cb366f1`)** folded the cheat-sheet's bare ids into `actions.csv`:

- **15 label-only rows** (`view.scroll_*`, `view.pan_*`, `view.snap_*`,
  `view.zoom_rect`, the toggle ids). Their `command` cell is deliberately EMPTY —
  the behavior is C-backed and only the binding table can run it; inventing a
  near-equivalent Tcl command per id would be the `e` trap at scale. The palette
  skips empty-command rows; the csv header documents the convention.
- **A new `idle` column** — the *action-level* mirror ("needs an idle engine") of the
  binding table's per-chord `idle_only`. Informational: nothing dispatches off it.
- **Two id reconciles, both by READING, not refactoring.** `sch.edit_header` was a
  second name for the csv's `prop.edit_header_license_text` (identical command) →
  renamed, one id one behavior. The long-deferred `Z`/`view.zoom_in` "collision"
  *dissolved*: `view_zoom(0.0)` defaults its factor to `CADZOOMSTEP` (actions.c), so
  the csv command and the wheel act were identical all along. A deferral is a
  hypothesis; re-derive it from the code before building mechanism around it.
- **The gap-finder became a gap-guard:** the smoke check "C-only ids fall back to a
  bare id" inverted into "NO bound id may lack a csv label" — future drift fails CI.

**d4b (`99564587`)** made the binding table file-loadable — the user-facing payoff:

- `keybindings.csv` / `mousebindings.csv` rows are exactly the `xschem bind` token
  vocabulary (`device,code,mods,ctx,action,idle`; action `-` = un-bind), replayed
  once at startup from xschem.tcl: share-dir defaults first, then `USER_CONF_DIR`
  copies (later wins). Malformed rows warn and are skipped — a typo can't brick
  startup.
- The shipped defaults are **generated from the builtin C table**
  (`save_input_bindings_file` over `bindings dump`), so they load as a no-op; the
  smoke test diffs the committed files against a fresh save every run, so changing
  the builtins without regenerating fails the suite. Generated artifacts need a
  freshness check or they're just a second source of truth waiting to drift.
- Ordering found while wiring the call: **xschemrc is sourced before the `xschem`
  command exists**, so `xschem bind` never worked from xschemrc — the csv files are
  *the* supported file-remap path, and they can't be clobbered by anything earlier.
- Proof of the loop closing: `test_bindings_file.tcl` writes a fixture that remaps
  backtick to `edit.toggle_stretch` and un-binds `y`, loads it, and drives real
  KeyPress events — the var flips on backtick and stops flipping on `y`. Edit a
  file, the keys obey. That was the Phase-3 starting question, answered.

## d5a — retiring the Phase-2 Tk intercept: one mechanism per key (commit `07c1d4d9`)

The transitional layer finally came out. Phase 2 had Tk-bound four chords above C
(`u`, `Shift+U`, `Shift+Z`, `Ctrl+z`); the Phase-3 pivot left that in place "for now."
d5a found the *now* had a cost: a Tk key-detail binding pre-empts the generic
`<KeyPress>`, so those chords never reached the C dispatch in the real GUI —

- the C rows `u`/`U` gained in sem-gated batch 1 were **shadowed**, and
- the Tk path had **no idle gate**: pressing `u` while the engine was busy ran
  `xschem undo` where the original switch (and the C row) did nothing. A real,
  user-visible divergence — invisible to `xschem callback`-driven tests, because
  callback bypasses Tk bindings entirely.

The retirement was cheap because d4a had already done the hard part: proving
`view_zoom(0.0) == view_zoom(CADZOOMSTEP)` meant `Shift+Z`/`Ctrl+z` could reuse
`view.zoom_in`/`view.zoom_out` as-is. Two new canvas rows; `case 'Z'` deleted whole
(single exact branch); only the exact `Ctrl` branch of `case 'z'` deleted (plain `z`
is ui_state-conditioned modal zoom-rect start, Alt-`z` is cadence_compat-gated — both
stay, per the exact-vs-family rule). `migrated_action_ids` is now an empty list (the
machinery procs stay: tested, inert, available for a future genuinely-Tcl-only accel).
`keybindings.csv` regenerated — the d4b drift guard failed until it was, exactly as
designed.

The test pair flipped its invariant. `test_accelerators` now asserts the four
sequences have **no** Tk binding, that `event generate` on the same physical chords
produces the same effects *through the C table*, and — the payoff — that `u` at
`semaphore=2` does nothing and undoes again at 0. `test_remap` proves runtime remap
at the Tk-event level via `xschem bind` (file persistence is test_bindings_file's
job). Lesson recorded: two mechanisms serving one chord WILL diverge; retire the
transitional one deliberately, and test at the layer where the mechanisms meet.

## d5b — the audit that closes the plan (commit `c36437c2`)

Four remnants, four different verdicts — the point of an audit is that "leftover" and
"dead" are not synonyms:

- **Deleted:** the Phase-2 accel machinery (151 lines). Inert since d5a, and the
  escape-hatch argument for keeping it dissolved on inspection: a "genuinely Tcl-only
  accelerator" is served strictly better by a Tcl-backed action id + `xschem bind`
  row (idle gate, dump, cheat-sheet, file persistence — the Tk path had none of
  those). The `accel` CSV *column* survives: menus and the palette display it.
- **Kept + documented:** the Button2 skips in `waves_selected`. They looked like the
  3b-era wart that blocked rebinding zoom-rect to the middle button, but they're
  load-bearing: Button2 is the canvas pan gesture, and panning must keep working
  with the pointer over a waveform graph. The comment now says so, and notes the
  skips leave with the pan gesture if it's ever table-migrated.
- **Kept + cross-referenced:** keys.help. It documents *all* defaults, including the
  many keys still dispatched by the C switch, which the generated sheet (by design)
  doesn't list. Its new header points at the live sheet and the remap files.
- **Swept:** the comments that still described the pre-Phase-3 world (the
  action_registry.tcl header claiming the C keysym dispatcher was "untouched").

With that, every checkbox in the Phase-3 plan is closed: wheel (3a), gestures (3b),
contexts (3c), Tcl-backed actions + idle gate + batches + cheat-sheet + csv
unification + file remap + single-mechanism cleanup (3d). What remains in the switch
is there because the data model can't honestly express it yet — and the next move
(more generated menus, palette-runnable C actions, accels derived from the live
table, or nothing) is a product decision, not a refactoring one.
