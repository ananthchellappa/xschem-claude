# 0382 — `cadence::selkind` classifies the selection from the sticky `first_sel` memo

Status: **OPEN** — STUB, number claimed by the D6 planner (2026-08-10). Measured during the
D6 census pass; filed, not fixed (out of the item's scope: the five call sites are not descend).
Area: `utils/cadence_nav.tcl` `cadence::selkind()` (`:49-57`); the memo is `set_first_sel()`
(`src/select.c:1142`, stores only into an empty slot) read raw by `xschem get first_sel`
(`src/scheduler.c:4105`, no rebuild, no liveness check).
Call sites (five, none of them descend): `utils/cadence_nav.tcl:199`, `utils/cadence_nav.tcl:378`,
`utils/select_same_cell.tcl:103`, `utils/cadence_clip.tcl:32`, `utils/lib_mgr_helpers.tcl:18`.
Tests: `tests/cadence_note_nav.tcl:57-64` covers `selkind` with FRESH selections only, so the
stale-memo case is invisible to it; `tests/select_same_cell.tcl:106` stubs the proc out entirely.
Found: 2026-08-10, D6 scout + measure (the sibling of the gate defect fixed under
[0259](0259-cadence-nav-descend-procs-bail-with-no-echo.md)).
Related: [0259](0259-cadence-nav-descend-procs-bail-with-no-echo.md) (same memo, the descend
gate — fixed there by counting `xschem selected_set` live),
[0203](0203-stale-sel_array-descends-a-deselected-instance.md) (the other stale-selection
bookkeeping family).

## The defect (measured)

`selkind` answers `none | {inst <n>} | {text <n> <string>} | multi | other` from
`xschem get first_sel`, which returns `xctx->first_sel` verbatim — a memo written only when the
slot is empty and cleared only by `unselect_all()` / the delete paths. Deselecting one object of
several never revisits it.

Measured on `tests/headless/fixtures/hi_descend/hidlib/top/schematic/top.sch` (select wire 0,
then instance `x1`, then `xschem select wire 0 fast clear`):

```
lastsel=1  selected_set={{x1}}  selection={{instance 0 1 23}}
xschem get first_sel = {1 0 0}      <- type 1 = WIRE, the object that is no longer selected
cadence::selkind     = other        <- should be {inst 0}
```

and with instance + wire both selected `selkind` answers `multi`, which is defensible, but by
`lastsel` rather than by what is actually selected — an instance plus its own selected pin also
reads `lastsel 2`.

## Fix, if it is to be closed

The 0259 shape applies: ask the live enumerators instead of the memo. `xschem selection` already
returns `{type index col id}` per selected object (`src/scheduler.c` `selection` branch) and is
rebuilt on demand, so `selkind` can classify without `first_sel` at all. Do **not** change
`xschem get first_sel`'s own semantics: its output is pinned string-exact by
`tests/stable_handles/test_body.tcl:200-201` and `inst_body.tcl:235`.

Check each of the five call sites before changing the return contract — `select_same_cell.tcl`
and `cadence_clip.tcl` branch on the `text` arm's third element.
