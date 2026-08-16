# 0414 — `test_descend_symbol` hangs forever under X: it belongs in `nogui_tests`

Status: **OPEN** — root-caused and measured, one-word fix identified, not applied.
Pre-existing; predates merge 5 (`7af2da9e`) and is not caused by it.
Area: `tests/headless/full_audit.sh` (`nogui_tests`), `tests/headless/test_descend_symbol.tcl`
(SNW6), `src/actions.c:2927` (`symbol_in_new_window`), `src/save.c:4410` (`load_schematic`'s
`fd==NULL` branch), `src/xschem.tcl:11907` (`alert_`).
Tests: `tests/headless/test_descend_symbol.tcl`.
Related: [0258](0258-descend-symbol-has-no-new-window-arm.md) (added the SNW rows).

## The defect

`test_descend_symbol` is the audit's one TIMEOUT. It does not fail — it **hangs**, is killed at
`AUDIT_TIMEOUT`, and takes its 300 s with it on every full run.

SNW6 calls `xschem symbol_in_new_window` with **nothing selected**. That arm composes the
current schematic's *own* `.sym` path and hands it to `new_schematic("create")`:

```
/tmp/<work>/descend_parent.sym
```

which has never existed in any commit — `git log --all -- tests/headless/fixtures/descend/descend_parent.sym`
is empty; the fixture dir holds `descend_child.sch`, `descend_child.sym` and
`descend_parent.sch` only. `load_schematic()` therefore takes its `fd==NULL` branch, which under
`has_x` does

```tcl
tcleval("update; alert_ {Unable to open file: %s}")
```

and `alert_` is a **modal toplevel**. The script waits on it forever.

The dialog is really there, not inferred — 25 s into a rerun on a private Xvfb:

```
0x200316 "Alert": ("alert" "Dialog")  580x84+200+300
```

## The one-word fix

The same binary, same test, no display:

```sh
env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_symbol.tcl
RESULT: ALL PASS
```

38 checks, exit 0, measured twice. The file's own header (line 4-5) already says to run it that
way. `full_audit.sh` never has: `test_descend_symbol` is in neither merge parent's `nogui_tests`
and so is not in their union either.

Fix: add `test_descend_symbol` to `nogui_tests` in `tests/headless/full_audit.sh`. Section 4.2 of
`doc/claude/suggestions/plan_merge5_fluid_into_open_pdk.md` governs edits to that list — this is
the same class as `test_placement_wire_gate`, which is `--nogui` by prescription for exactly this
reason (a modal that no headless run can dismiss).

The deeper repair, if anyone wants it, is to re-aim SNW6 at a `.sym` that exists, or to make the
`fd==NULL` branch non-modal under a test harness. Neither is needed to stop the hang.

## Why it is not merge 5

* `git log --oneline 1a45bc06..HEAD -- tests/headless/test_descend_symbol.tcl` is **empty**; the
  SNW rows came from `b1326180` and `5c5671b5`, both already in parent A.
* `nogui_tests` at HEAD is exactly the union of both parents' lists — nothing was dropped in the
  merge. (This is the both-branches-edited-one-table signature, and here it came out clean.)
* Every source file on the SNW6 path is unchanged since parent A: the only `src/actions.c` and
  `src/xinit.c` deltas are the issue-0323 `get_unused_untitled_name()` call, and the single
  `src/save.c` hunk touching `load_schematic` is the 0323 reorder in the *empty-filename* branch,
  not the `fd==NULL` one.
