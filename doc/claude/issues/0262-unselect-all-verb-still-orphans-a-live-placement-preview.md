# 0262 — the bare `xschem unselect_all` verb still orphans a live placement preview, and it is the last terminal door

Status: **OPEN** — measured, deliberately left out of issue 0242's fix, and the only row that still
trips 0242's tripwire. **Major**: script-reachable only, but the end state is the terminal
issue-0123 desync (canvas dead until the flag is cleared) plus a committed net-renaming label.
Area: `src/scheduler.c` (the `unselect_all` verb) vs `abort_placement_preview()` / the
`leave_placement_for()` door in `src/callback.c`
Tests: reported, not asserted — `tests/headless/test_placement_preview_doors.tcl` section F prints
it as a `note:` line, and the C tripwire `check_placement_preview_invariant()` emits exactly one
stderr line for it on an otherwise-clean 115-check run.
Found: 2026-08-08, closing issue **0242**
Related: **0242** (parent — the other nine doors are fixed), **0123** (the desync root), **0241**,
**0243** F2, **0263** (the other 0242 residue), `WIRING.md` §8 class **D**.

## Symptom

```tcl
set ::label_new_name FOO
xschem clear force ; xschem wire 0 0 100 0 ; xschem unselect_all
xschem add_wire_label -place      ;# preview on the cursor: ui=16424 sp=1
xschem unselect_all               ;# <-- the door
xschem abort_operation ; xschem abort_operation ; xschem abort_operation
```

```
after unselect_all : sympin_preview=1  START_SYMPIN=0  orphans=1
after 3x ESC       : sympin_preview=1  orphans=1   -> instance_net l1 p = FOO
```

Identical to 0242's headline repro: `unselect_all()` (`select.c`) zeroes `ui_state` wholesale
because the preview is selected, dropping `START_SYMPIN|STARTMOVE` without running the placement
teardown. `sympin_preview` / `wirelabel_preview` are not `ui_state` bits, so they survive, and the
preview instance was never `delete()`d — it is now a committed, connected, netlist-visible
`lab_pin` silently renaming the net. With `sympin_preview` stuck at 1, `callback.c`'s Button-1
select/grab block (guarded `!sympin_preview`) refuses every press and `wire_label_try_commit()`
refuses every drop, and ESC cannot repair it because `abort_placement_preview()` is gated on the
bit that is gone.

## Why 0242 did not fix it

0242 gated the nine doors that **arm a second gesture**, under the ratified rule "whatever you just
pressed is what you meant" (0240 / 0243 F2). `unselect_all` arms nothing — there is no second
gesture, so that rule has no subject and "abandon the preview" is not obviously what the caller
meant.

And the obvious placement is barred: the teardown must not go inside `unselect_all()` itself. That
is issue **0123**'s stated reason — 87 C call sites and 817 scripted ones, several inside netlisting
and live fluid passes, and it would make a *deselect* silently `delete()` objects. Gating the
scheduler **verb** is a smaller version of the same hazard: `xschem unselect_all` is called from
`src/xschem.tcl`, `property_form.tcl`, the test corpus and any user rc, almost always as a
housekeeping step and never as "cancel my pending gesture".

So the residue was left standing, reported rather than papered over. It is not reachable from the
GUI: no key, menu item or toolbar button issues the bare verb while a preview is live.

## Options (undecided — needs the same ratification 0243 F2 got)

1. **Gate the verb** with `leave_placement_for("Deselect")`. One line, consistent with the other
   nine doors. Cost: a scripted deselect silently deletes the preview instance, and 817 call sites
   inherit that. Worst case is a helper proc that deselects mid-form and destroys a preview the
   user is still typing a name for.
2. **Self-heal at the tripwire.** `check_placement_preview_invariant()` already detects the state
   exactly and with no false positives; on detection it could clear `sympin_preview` /
   `wirelabel_preview` (no `delete()`, no undo, no object touched) and log loudly, exactly as
   `fluid_gesture_arm()` already does for a leaked snapshot. That converts every *remaining and
   every future* door from **terminal** to **orphan-only** — the canvas is never dead again — while
   still leaving the orphan visible and the log honest. It does not delete anything, so it carries
   none of option 1's risk.
3. **Do nothing**, keep the report. Correct only if the verb is genuinely unreachable while armed
   in practice.

**Recommendation: 2, then reconsider 1.** Option 2 removes the terminal half of the whole *class*
rather than this one instance, which is the property 0242 kept failing to get one door at a time.
It was deliberately not implemented in 0242 because the issue asked for a log-only tripwire and a
self-healing one is a behaviour change.

## Landmine

Option 2 must not fire during an arm. It does not today: the three `-place` arms were made atomic
in 0242 (`sympin_preview` is raised WITH `START_SYMPIN`, on the success path), which is what took
the tripwire from 11 false positives on a healthy 6-keystroke arm to zero. Any new placement arm
must keep that ordering, or a self-healing tripwire would clear a live preview's flag mid-arm.
