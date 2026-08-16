# 0379 — `xschem get_sym_type <path>` returns empty while an instance is selected

Status: **OPEN — headline claim UNREPRODUCED on re-measurement (2026-08-15, twice, independently).
See "Re-measurement" at the end of this file before building anything on it.** Pre-existing C
behaviour (not introduced by any 2026-08-10 work); filed because it silently killed the D5
attempt at
[0252](0252-non-subcircuit-symbols-refused-silently-after-the-chooser-offered-the-view.md).
Area: the `get_sym_type` branch of `scheduler()` in `src/scheduler.c`; consumed from Tcl by
`hi_descend_no_view_msg()` (`src/xschem.tcl`) and by any future chooser filter.
Tests: none. No suite calls `get_sym_type` with a selection live — which is exactly why the D5
chooser filter scored green while being broken.
Found: 2026-08-10, by the D5 write-up agent, while checking the adversary's CE-2 finding.
Related: [0252](0252-non-subcircuit-symbols-refused-silently-after-the-chooser-offered-the-view.md)
(the filter that depends on it), [0378](0378-hi-descend-tcl-level-bails-leave-descend-error-unreadable.md).
Analysis: `doc/claude/code_analysis/descend_silent_refusal_census.md` (section "D5 attempt — reverted").

## The defect

`xschem get_sym_type <abs-path>` takes an explicit symbol path and reports that symbol's `type=`
token. It answers correctly on a freshly loaded sheet, and answers **empty** for the *same literal
path* once an instance is selected. The trigger is the selection, not the path and not any
intervening descend:

```
1 fresh           type='resistor'
2 after unselect  type='resistor'
3 after selectall type='resistor'
4 after unselect  type='resistor'
5 after select_inst type=''        <- xschem select instance 0
6 after refused descend type=''
7 reload          type='resistor'
```

Reproduced with a `type=resistor` symbol at an absolute path, passed literally:

```
POST abs='/.../rr.sym' exists=1
POST type=''
POST type(literal)=''              <- same string that returned 'resistor' before the select
```

The path argument is therefore not what the command is really keying off in that state.

## Why it matters

**It makes any type-based decision unsafe in the one state the user is actually in.** The normal
gesture is *select an instance, then descend* — the precise state where the lookup returns empty.

D5 built `hi_descend_row_offerable {defsch symabs}` on top of it:

```tcl
set ty {}
catch { set ty [xschem get_sym_type $symabs] }
if {$ty in {subcircuit primitive}} { return 1 }
return [file exists $defsch]
```

With a selection live, `$ty` is `""`, so the filter collapses to a pure file-exists test. For a
`type=subcircuit` whose child `.sch` does not exist yet, that drops the schematic row entirely and
**removes the create-the-child-by-descending workflow from the chooser**:

```
ns.sch exists = 0 (create-the-child flow)
BY NAME  rows = {schematic .../ns.sch} {symbol .../ns.sym}
SELECTED rows = {symbol .../ns.sym}          <- schematic view GONE
```

That was the reason the D5 fix was reverted in full.

It also degrades D5's 0252 message: `hi_descend_no_view_msg` uses the same lookup, so with a
selection live the token/message fell back from `not-descendable:resistor` to `no-view:` — the
wrong class, on 0252's own headline case.

## Repro

```tcl
# rr.sym carries G {type=resistor}; top.sch instantiates it as R1
xschem load $W/top.sch
puts "[xschem get_sym_type $W/rr.sym]"   ;# resistor
xschem unselect_all
xschem select instance 0
puts "[xschem get_sym_type $W/rr.sym]"   ;# {}   <-- same literal path
```

`./src/xschem --nogui --pipe -q --nolog --script <above>`

## Landmines for the fix

- **Do not "fix" this by clearing the selection around the lookup.** The selection is the user's,
  and 0244/0267/0270 already ratified that an operation must not quietly disturb gesture state.
- **Check whether the command is documented as selection-relative.** If some caller relies on the
  "type of the selected thing" behaviour, the honest fix is two commands (or an explicit
  `-path` form), not a change of meaning under the existing name.
- **A Tcl-side workaround exists** — read the `type=` token from the symbol's `G {}` record
  directly, or add a selection-independent accessor — but the underlying command should still stop
  disagreeing with itself.
- **Any test must set a selection.** A suite that addresses instances by name (`inst=XN`) cannot
  see this defect at all; that is how it survived a 67-check suite, an 8-variant sabotage matrix
  and an adversary pass.

## Re-measurement, 2026-08-15 (crew item D11) — the headline claim did NOT reproduce

Two D11 agents independently re-ran this issue against the current tree (post-`dd5ca7b8`,
freshly rebuilt binary) and could not reproduce the selection-dependence:

- The **scout** ran five probe shapes: (a) a `type=subcircuit` symbol in a flat dir; (b) a
  `type=resistor` symbol in a flat dir, the exact 7-step sequence above including
  `xschem select instance 0`; (c) the same with the schematic referencing the symbol by
  **absolute** path so `get_sym_type` takes its loaded-symbol-cache branch (`src/save.c:4294`)
  rather than its file branch; (d) the OA lib/cell/view `hi_descend` fixture; (e) the real
  `xschem_library/devices/res.sym` with a live selection and after a refused descend.
- The **measure** agent re-ran the 7-step sequence in this file verbatim.

In **every** case `xschem get_sym_type <abs path>` returned the correct type (`resistor` /
`subcircuit`) at **every** step — fresh, after unselect, after select_all, with the instance
selected (step 5, `lastsel=1`), and after the refused descend (step 6).

A **different**, selection-independent failure did reproduce: `get_sym_type` answers `""` for a
name it cannot resolve through the library path — `get_sym_type leaf.sym` → `''` while
`get_sym_type hidlib/leaf` → `'subcircuit'` for the identical symbol — and `""` is also what an
untyped symbol returns, so *unresolvable* and *no type token* are indistinguishable from the
caller. That is a plausible alternative explanation for the D5 collapse (the filter was fed a
row-shaped path), with the selection as a confound.

This does **not** close the issue. D5 measured the emptiness live in a different session, and two
failures to reproduce are not a refutation. What it means is:

1. A third, deliberate re-measurement is its own work item — with the D5 call site reconstructed
   exactly as it was, not a hand-written probe.
2. **Nobody may cite this issue as an established blocker without re-measuring it first.**
   [0411](0411-cadence-e-should-offer-descending-into-the-symbol-of-the-selected-instance.md)
   names this issue as its blocker and carries the same caveat.
3. Whatever the answer, `get_sym_type` should stop returning the same `""` for "cannot resolve
   that name" and "that symbol has no type token".

Blocking: [0411](0411-cadence-e-should-offer-descending-into-the-symbol-of-the-selected-instance.md)
(cadence `e` should offer the symbol view — filed, not built, blocked on this).
