# 0379 — `xschem get_sym_type <path>` returns empty while an instance is selected

Status: **OPEN** — measured headless. Pre-existing C behaviour (not introduced by any 2026-08-10
work); filed because it silently killed the D5 attempt at
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
