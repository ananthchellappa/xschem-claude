# 0803 — `execute` pops a modal dialog on a failed launch, hanging any suite under X

Status: **FIXED on the test side** (`ase_no_modal`), product side left ALONE deliberately.
Filed by: the 0689+0690+0698 crew, 2026-08-25, from its Implement leg.
Class: a **test-environment** defect with a product cause that is not itself a bug —
the dialog is right for a user and fatal for an unattended suite.

## The measurement

`src/xschem.tcl:352` `proc execute`:

```tcl
if { [catch {open "|$args" $mode} err] } {
  puts stderr "Proc execute error: $err"
  if { [info exists has_x]} {
      tk_messageBox -message "Can not execute '$args': ..." -icon error \
        -parent [xschem get topwindow] -type ok
  }
  return -1
}
```

`tk_messageBox` is MODAL. Under `--nogui` the `has_x` guard skips it and the leg
takes 3.5 s; under X nobody clicks OK and the suite **hangs forever** — it does
not fail, it does not time out, it sits.

Measured on `:99` (Xvfb 1920x1080x24, openbox 3.6.1), 2026-08-25:

| arm | `tests/headless/test_ase_core.tcl` |
|---|---|
| `--nogui` | `RESULT: ALL PASS (173 checks)`, 3.5 s |
| `DISPLAY=:99`, before this fix | 121 checks pass, last line `Proc execute error:`, **hang** — killed at 120 s and again at 600 s |

The leg is E2 (`ase_definitely_missing_binary_xyz`), whose entire purpose is
"the simulator binary is missing → clean `ase:` error". A negative-path leg is
exactly the shape that trips this.

### Why nobody had seen it

Only reachable once issue 0698's design-window bind let `test_ase_core` get past
its N1 `ase::netlist` under X at all. Before that the suite aborted at check 104,
72 checks short of E2, and `full_audit.sh:163` pins the suite `--nogui` besides,
so CI has never run this code path either.

## The fix taken (test side)

`tests/headless/ase_design_window.tcl` gains `ase_no_modal {script}`: under X it
renames `::tk_messageBox` aside, installs a stub returning `ok`, runs the script,
and restores on every exit path including the error path, passing the script's own
result or error through untouched. Headless it is a bare `uplevel`. `test_ase_core`
wraps ONE call in it — the E2 launch — so the leg keeps asserting exactly what it
always did, in both arms, with the same check count.

Deliberately **one leg, not the suite**: a blanket suppression would silently
swallow a dialog some other leg is entitled to raise.

## What was NOT done, and why

`execute` itself is untouched. Suppressing or downgrading its dialog would change
what a real user sees when a simulator is missing — the single case where that
dialog earns its keep — to make a test convenient. If the product side is ever
revisited, the shape to consider is a `::xschem::batch` flag consulted *alongside*
`has_x`, never instead of it.

## Acceptance

1. `test_ase_core` completes under X without a hang. **Met**: `RESULT: ALL PASS
   (172 checks)`, exit 0 (172 not 173 — one arm-gated skip, issue 0804).
2. The headless arm is unchanged. **Met**: `RESULT: ALL PASS (173 checks)`.
3. `tk_messageBox` is restored after the leg (a later dialog still appears).
