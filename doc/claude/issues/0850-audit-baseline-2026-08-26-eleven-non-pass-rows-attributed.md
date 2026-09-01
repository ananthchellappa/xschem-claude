# 0850 — full-audit baseline 2026-08-26: every non-PASS row attributed

Status: **INVENTORY, not a defect of its own.** Written so the next reader does not
re-derive it, and so no count is ever carried forward as "known".

CLAUDE.md: *"A standing red is a defect, not furniture — it is the one place a real
regression hides in plain sight… never carry a count forward as a known quantity."* This
file is that rule applied to one audit: **331 PASS, 10 FAIL, 1 TIMEOUT, 1 SKIP, 0 CRASH**,
`:99` Xvfb 1920x1080x24 with openbox 3.6.1 live, run against commit `8dfdb7b2`.

## Method

Every non-PASS row was baselined by restoring `xinit.c`, `callback.c` and
`wave_viewer.tcl` from `HEAD~1` (`192fc6d0`, i.e. before the 0848 window-switch fix),
rebuilding, and re-running. Same failure at `HEAD~1` ⇒ pre-existing. Files restored after.

## The rows

| suite | verdict | where it belongs |
|---|---|---|
| `test_altf5_ciw` | pre-existing | filed **0846** — un-bound Alt-F5 still raises the CIW |
| `test_ase_core` | **environmental** | C11, an `untitled~.sch` dropped in the repo root by a concurrent suite. Passes standalone: 173 checks. Root is clean. |
| `test_cadence_drag` | pre-existing (2 FAILED at HEAD~1) | fluid-editing area, another branch's |
| `test_lib_manager_gui` | pre-existing (2 FAILED at HEAD~1) | GUI8/GUI9 tab counting |
| `test_lib_sweep` | pre-existing (5 FAILED at HEAD~1) | P1–P4 library migration |
| `test_reopen_readonly` | **MINE — fixed** | see below |
| `test_rotate_stretch_short_0104` | pre-existing | wiring / rotate-in-place dangling endpoint |
| `test_selflog_output` | pre-existing | Shift/Alt F, R, V key self-logging |
| `test_wave_sigbrowser_0312` | pre-existing | filed **0842** |
| `test_wave_sigbrowser_i12` | **arrived with 0848, root-caused** | filed **0849** — a declared contract that was only ever satisfied by the defect 0848 fixed |
| `test_wave_sigbrowser_keys` | pre-existing | filed **0841** — goldens six bindings behind |

## The TIMEOUT was mine, and the mechanism is worth keeping

`test_reopen_readonly` hung the audit. Cause: several rows do `xschem load -gui <file>`
on a file that is **already loaded**. Under a real display the C side raises a modal
*"Warning: <file> already open."* and waits forever.

It is **invisible headless** — that arm is `if(has_x)`, so under `--nogui` it only calls
`dbg()` — which is why the suite passed every standalone run made the documented way in
its own header, and hung the first time the audit ran it under Xvfb.

Fixed by parking the buffer on a scratch file before each `-gui` load, so the load is
always of something not currently open. Green both ways now: under `:99`, and headless.

**The general trap:** a suite whose header says `--nogui` can carry a GUI-only hang that
no amount of running it as documented will ever show. The audit runs everything under a
display; that difference is a feature, not noise.

## What this audit does NOT say

Five of the pre-existing rows (`test_cadence_drag`, `test_lib_manager_gui`,
`test_lib_sweep`, `test_rotate_stretch_short_0104`, `test_selflog_output`) are named here
and **not** filed as individual issues, because they sit in areas this branch does not
own. Naming them is the minimum the rule demands; fixing them is someone's call, not an
assumption. They are not "known good".
