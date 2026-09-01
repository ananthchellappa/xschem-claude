# 0698 — `test_ase_final` passes `--nogui` and ABORTS under X — **and it was THREE suites, not one**

Status: **FIXED 2026-08-25** by the 0689+0690+0698 crew, on the **suite** side.
⚠ **SCOPE WIDENED**: as filed this issue named one suite. Measured, it is three —
`test_ase_final`, `test_ase_final_gf180` and `test_ase_core` all pass headless and
die under X on the identical refusal. A fix repairing only `test_ase_final` would
have left two-thirds of the family as folklore.
Original stub claimed 2026-08-25 by the 0695+0696 crew; measured, NOT fixed there.
Area: `tests/headless/test_ase_final.tcl` and/or `ase::netlist`'s design-window guard
Related: 0683, 0684 (annotation reachable with no bound design window — OPEN, awaiting
the user's ruling; **do not touch them from here**), 0695+0696 (the item that found this)

## What was measured

The suite is green headless and dies on the tenth check under a real X display:

```
$ ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_final.tcl
RESULT: ALL PASS (78 checks)

$ GUI_GATE=0 DISPLAY=:99 ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_final.tcl
UNEXPECTED ERROR: ase: design sky130_tests/test_nfet_final is not the current schematic;
                  open its design window first (Session > Design Window)
RESULT: 1 FAILED (9 passed)
```

`:99` is Xvfb 1920x1080x24 with openbox 3.6.1 live (`devdisplay.sh status`:
`wm: openbox (Openbox)`), which is the environment every other suite in this batch
was measured on.

## It is PRE-EXISTING, and that was proved rather than assumed

Two agents of the 0695+0696 crew confirmed it independently by restoring
`git show HEAD:src/ase_window.tcl` over the working tree, re-running on `:99`, and
getting the **identical** `RESULT: 1 FAILED (9 passed)` and the identical error
line, then restoring with `cp` + `touch` and re-verifying the checksum and
`git diff --stat`. None of `save_all_*` is on the failing path.

## Why nobody had seen it

The measured baseline of record for this branch only ever ran `test_ase_final`
under `--nogui`, where it reports `ALL PASS (78 checks)`. The `--nogui` arm
self-skips whatever leg needs a bound design window, so the abort has no headless
symptom at all. **A suite that passes headless and aborts under X is a suite whose
green is a partial measurement** — the same "a report that lies" family this branch
keeps meeting.

## Shape of the defect (not yet decided which half is wrong)

Either the suite fails to open/bind a design window before the leg that netlists,
or `ase::netlist`'s "is not the current schematic" guard is over-strict under X
where headless leaves it unreachable. That guard is adjacent to the OPEN 0683/0684
family (annotation reachable with no bound ASE-L session / `annot_ensure_loaded`
guarding on the wrong predicate), which is why this is filed and not fixed: those
two are awaiting the user's ruling and a fix here could pre-empt it.

## Acceptance (when it is taken)

1. `test_ase_final` gives the SAME check count and verdict under `--nogui` and on
   `:99`, or the X-only legs are explicitly gated and counted as skips.
2. Whichever side is wrong is named: the suite's missing bind, or the guard's
   predicate.
3. Whatever lands does not contradict the 0683/0684 ruling once the user gives it.

---

# THE FIX (2026-08-25)

## It is three suites. Measured, not assumed

| suite | `--nogui` (before) | `:99` (before) | design in the message |
|---|---|---|---|
| `test_ase_final` | ALL PASS (78) | **1 FAILED (9 passed)** exit 1 | `sky130_tests/test_nfet_final` |
| `test_ase_final_gf180` | ALL PASS (33) | **1 FAILED (10 passed)** exit 1 | `gf180mcu_tests/test_nfet_final` |
| `test_ase_core` | ALL PASS (172) | **1 FAILED (103 passed)** exit 1 | `aselib/nfet_clean` |

Same refusal each time, only the design name differs.

**Why CI never saw any of it**, confirmed at the source: `full_audit.sh:163`'s
`nogui_tests` string pins **all three** together, and `.github/workflows/ci.yaml` runs
`full_audit.sh` and `tests/headless/run.sh` — never `run_regression.tcl`. CI has only
ever run the green headless arm. That is the mechanism by which this became tribal
knowledge instead of a red line.

## Which half is wrong: the SUITE's missing bind, not the guard's predicate

`src/ase.tcl:866-874` refuses precisely because a display exists and the design is not
current:

```tcl
if {[file normalize [xschem get schname]] ne $path} {
  if {![info exists ::has_x]} { xschem load $path } else { return -code error "ase: design ... open its design window first" }
}
```

That refusal is **correct and deliberate** — never clobber an open GUI window;
reloading would destroy unsaved edits. The suites simply never open the design window
that the guard's own GUI arm documents. `src/xinit.c:3135-3138` sets `::has_x` only
inside `if(has_x)` and nothing unsets it, so `[info exists ::has_x]` is exactly "a
display is available" (doctrine restated at `src/ase.tcl:100-102`).

**Not one byte of `src/` moved**, which is what keeps this clear of the OPEN
**0683/0684** ruling on that very guard.

## What landed

New procs-only helper `tests/headless/ase_design_window.tcl` →
`ase_bind_design_window {state}`: a **no-op unless `[info exists ::has_x]`** (the same
predicate the guard itself uses), otherwise it resolves the path through
`xschem cellview_path` — the **same accessor `ase::netlist` compares against** — and
`xschem load`s it. Each of the three suites sources it and calls it on the line
immediately before its **first** `ase::netlist`, plus one new row asserting the design
is bound before that call.

**ORDERING IS LOAD-BEARING.** The bind must be inside each suite's big `catch` and
**after** its scratch `library.defs` block. Placed earlier, the symbol resolves against
the ambient registry and the guard's GUI arm then netlists the mis-resolved buffer:
measured `FAIL: F6 netlist contains XM1 -> {0}`, 77 passed / 1 failed — a failure that
looks nothing like the bug and would be easy to misdiagnose.

Each file's header claim "True headless (no X)" — **the folklore made textual** — now
names both arms and both run commands.

## AFTER

| suite | `--nogui` | `:99` |
|---|---|---|
| `test_ase_final` | **ALL PASS (79)** | **ALL PASS (79)** exit 0 |
| `test_ase_final_gf180` | **ALL PASS (34)** | **ALL PASS (34)** exit 0 |
| `test_ase_core` | **ALL PASS (173)** | **ALL PASS (172)** exit 0 — the one difference is an *announced* skip, see 0804 |

`tests/headless/run_suites.sh` (the display-arm command that bit the lead) reports
6/6 runs passed. Acceptance row 1 is satisfied **without** its escape clause for two of
the three, and by an announced, single, named skip for the third.

## Two overruns, both forced by the fix, both filed

Fixing the bind let `test_ase_core` execute ~70 checks it had never reached under X:

* **0803 — `execute` pops a MODAL dialog on a failed launch, and the suite HANGS.**
  `src/xschem.tcl:352` reports a failed launch with `puts stderr` always and, only
  `if {[info exists has_x]}`, a modal `tk_messageBox`. `test_ase_core`'s missing-binary
  leg then waits for a click that never comes: killed at 120 s and again at **600 s**,
  against 3.5 s headless. **A hang is worse for an unattended crew than a red** — it
  burns the whole budget and reports nothing. Fixed test-side with `ase_no_modal`
  around ONE call; `execute` itself untouched, because the dialog is right for a user.
* **0804 — NT14 asserts headless-only behaviour in both arms.** With the hang cleared,
  `NT14 0650 headless: no sink raises...` failed `{0 1 0}` vs `{0 0 0}` under X — its
  own name says *headless*, and with a display the statusbar sink is legitimately
  claimed. Arm-gated to a **printed** SKIP, deliberately **not** widened: accepting
  `{0 1 0}` would assert something unmeasured about the notify channel, which is
  mid-ruling (0674/0675/0677/0699/0800) and off-limits.

## Decisions (ladder rung → rejected alternative)

| # | rung | decision | rejected |
|---|---|---|---|
| D8 | L2 | fix on the **suite** side, in all three suites | the `test_placement_wire_gate.tcl:31-34` **self-skip** idiom — honest but strictly weaker: zero checks under X, satisfying acceptance row 1 only through its escape clause, and it makes permanent the folklore this issue was filed to retire |
| — | L2 | gate the bind on `[info exists ::has_x]` | an **unconditional** `xschem load` — it would silently stop exercising the guard's headless self-load arm |
| D9 | **L1 (I1)** | resolve the path through `xschem cellview_path` | each suite's own `$schfile` literal — it works in `test_ase_final` but is a second builder of one path, and does not exist uniformly in the other two |
| D10 | L2 | leave `full_audit.sh:163`'s `nogui_tests` pinning **alone** — a deliberate NON-goal | unpinning in the same commit: it changes what CI runs, is unmeasured on the CI box, and exposes the gate to the 0801-class load-sensitive X flake. The X arm is covered instead by `run_suites.sh`, which is how the lead hit this |

## Sabotage

**SAB-8** `ase_bind_design_window` → empty body: predicted three X-arm reds and three
green headless arms; observed exactly that, at `2 FAILED (9 / 10 / 103 passed)` on
`:99` (**two** reds rather than the predicted one — the new bind row plus the
downstream refusal, strictly better than predicted) and **ALL PASS 79 / 34 / 173**
headless. One command now makes the arm asymmetry visible instead of tribal.

## Still open

* The bind rows are **vacuously true headless** (`![info exists ::has_x]`
  short-circuits to "bound"), and `full_audit.sh:163` still pins all three suites
  `--nogui` (D10). So **no automated gate can fail those rows**; the repaired X arm is
  guarded only by a human typing `run_suites.sh`. Unpinning is the follow-up.
* `src/ase.tcl:866-874` is untouched pending the **0683/0684** ruling. If that ruling
  changes the guard's predicate, the `has_x` gate in `ase_bind_design_window` and all
  three call sites must be revisited **together**.
* **0803** and **0804** are fixed test-side only; their product-side questions are in
  those files.

