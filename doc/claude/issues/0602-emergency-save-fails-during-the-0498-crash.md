# 0602 - the emergency-save path itself fails during the 0498 crash

STATUS: OPEN - FILED, NOT FIXED (observed during X0498)

When the 0498 SIGSEGV fires, the crash handler's emergency save does not save anything. The
transcript is:

    EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_wbare_fdgbbfggge
    rename dir (null) to /tmp/xschem_emergencysave_... failed
    FATAL: signal 11

i.e. the handler announces a save directory, then fails to move anything into it because the
source directory is NULL - so a user who hits any crash in that state loses the work the handler
exists to preserve.

Reproducible after X0498's fix by sabotage variant SV3 (make `undo_shield_push()` a no-op AND
disarm the `INST_UNBOUND(i)` guard in `draw_hilight_net()`), then running the X0498 fixture; see
`tests/headless/test_undo_link_symbols.tcl` rows X0/X1.

Scope note: the crash that exposed this is fixed; the emergency-save defect is independent of it
and applies to every other crash path.

## Reproduction note, corrected

Two X0498 agents disagreed about whether sabotage variant **SV3** (shield no-op + disarmed
`INST_UNBOUND` guard) brings the crash back: the Implement agent measured X1 green 3/3 under
it, the sabotage agent measured it red 5/5 with the original crash verbatim. The reconciling
reading is that under *partial* sabotage the crash is heap-layout sensitive, because SV3
retains the `stored_flags` clamp and the clamp alone can suppress the over-read that
manufactures the bad colours.

**The unambiguous reproduction is a pristine pre-fix binary**, built out-of-tree from
`git show <pre-X0498-commit>:src/<f>` for the eleven changed sources, run against the X0498
fixture. That reproduces both the SIGSEGV and this failed emergency save, deterministically.

## Still open

The defect is in the crash handler and is **independent of 0498** — it applies to every other
crash path in the program. Nothing about the X0498 fix touches it; the only reason it was
observed here is that 0498 was the crash available to observe it with.
