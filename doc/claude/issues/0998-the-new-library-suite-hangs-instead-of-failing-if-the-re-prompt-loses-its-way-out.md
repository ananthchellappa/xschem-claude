# 0998 — the New-library suite hangs instead of failing if the re-prompt loses its way out

**Filed by the S5 sabotage pass, 2026-08-30.** Subject:
`tests/headless/test_lib_new_path_guards_0799.tcl` rows R11/R12/R13 against
`libmgr::ctx_new_library`.

0799 requirement 3 turned "New library…" into a loop that re-opens the window on a
refusal. Its two ways out are `if {$r eq {}} return` (Cancel/Escape) and an empty
name. R12a is the row that says *"Cancel still gets you out of New library for
good"*.

## Measured

Mutation **S14** (mine, not in the plan): delete the `if {$r eq {}} return` line —
the loop's only way out — leaving everything else intact. Real tree, rebuilt, dev
display arm:

```
DISPLAY rc=124   (timeout, killed at 90 s)
ok=33  FAIL=0  banner=''      <- no RESULT line, no OVERALL line
last R11/R12/R13 rows seen: none
```

The suite does **not** fail. It hangs at R11 and never reaches R12 at all, so the
row written to catch this never runs. `r12_poll`'s cap sets
`libmgr::dlg_done 0`, which the broken loop simply treats as another Cancel and
re-opens the window, so the cap cannot break the cycle either.

Under the harness rule (exit 0 **and** a whole-line completion banner) this scores
as a failure — but only for a reader who is watching. This suite is registered in
`tests/run_regression.tcl`'s **`dcases`**, and a hanging case there hangs the whole
T1 run, which is the `test_placement_wire_gate` shape CLAUDE.md already warns
about.

## The fix

Bound the dialog itself, not just the poller: give `libmgr::newlib_dialog`'s
`vwait` a watchdog `after` that sets `dlg_done`, or have R11/R12 arm a
`after <n> {set ::libmgr::dlg_done 0 ; set ::giveup 1}` and assert on `::giveup`.
Either turns a hang into a red row, and gives R12a something it can actually see.

---

## FIXED, 2026-08-31 (S5 repair pass), in both halves

**Product half.** `libmgr::newlib_dialog` now has the way out it never had:

```tcl
  wm protocol $d WM_DELETE_WINDOW [list set libmgr::dlg_done 0]
  bind $d <Destroy> [list libmgr::newlib_vanished %W $d]
```

Pressing the title-bar X, or closing the Library Manager out from under the
prompt, now means what Cancel means. `libmgr::newlib_vanished` checks `%W` against
the toplevel so a child widget being torn down is not read as a cancel. The
dialog was NOT given a timeout — a window that closes itself while a user is
typing is a worse defect than the one being fixed. The Library Manager's four
other prompts have the same missing handler and do not loop; filed as `[[0999]]`
rather than changed untested in a repair pass.

**Test half.** A hang is now a red. Every poller that drives
`libmgr::ctx_new_library` hands over to a watchdog the moment it stops watching;
the next window the loop tries to open raises an error instead of opening, which
unwinds `ctx_new_library`. Setting the dialog's done flag cannot do this job — a
broken loop reads that as one more Cancel. R15 adds a row that reports whether the
watchdog ever had to fire.

Re-measured with the loop's `if {$r eq {}} return` deleted, dev display:

```
exit 1   (was: exit 124, no banner, R12/R13 never ran)
FAIL: R11d  FAIL: R11e  FAIL: R12a  FAIL: R12c  FAIL: R15b  FAIL: R15d
RESULT: 6 FAILED (49 passed)
OVERALL: notok
```

R12a — *"Cancel still gets you out of New library for good"* — now runs and now
fails, which is what it was written to do. And with the two product lines above
removed instead:

```
FAIL: R15a the New-library window's close button is wired to a way out (handler='')
FAIL: R15b ... does not leave New library waiting (outcome=gone had-to-poke-it=1)
```
