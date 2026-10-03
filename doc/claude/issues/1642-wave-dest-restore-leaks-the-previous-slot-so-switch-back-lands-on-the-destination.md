# 1642 — `calc::wave_dest_restore` leaks the previous slot, so `switch_back` lands on the DESTINATION

**STAMP:** `v1 claim=open tree=a81ca259 stamped=2026-10-03 fix=none open=2`

Status: **OPEN**, found 2026-10-03 by the Calculator batch's stage J recon critic while
re-measuring a claim two earlier receipts disagreed about. Pre-existing: it is a defect in the
wave destination that shipped at `50d13438`, not in the wiring stage that found it.

Area: `calc::wave_dest_restore`, `calc::wave_dest`, `calc::wave_dest_drop` in
`src/calculator.tcl`; the engine's `extra_idx` / `extra_prev_idx` pair, reached through
`xschem raw switch` and `xschem raw switch_back`.
Found: parked the cursor on a known non-zero slot, ran the producer, and read the pair back out
of `xschem raw info` rather than inferring it from the proc.

## The defect

`calc::wave_dest` restores the user's **current** slot and says nothing about their **previous**
one. Measured, three databases registered and the cursor parked at `cur=0 prev=1`:

| after | `cur` | `prev` | `switch_back` lands on |
|---|---|---|---|
| (parked) | 0 | 1 | slot 1 — the user's own previous analysis |
| `calc::wave_dest` succeeded | 0 | **3** | **slot 3 — the destination** |
| `calc::wave_dest_drop` | 0 | **0** | slot 0 — itself |

So the *current* slot is honoured in both cases and the *previous* slot is destroyed in both.
A user who measures a duty cycle and then asks to go back to the analysis they were looking at
before lands on a scratch two-column table they never named; after the destination is dropped they
land on the slot they are already on, which is a silent no-op where a navigation was asked for.

`xschem raw switch_back` is a **one-deep toggle**, so there is exactly one previous slot and
anything that moves the cursor spends it. `calc::wave_dest` moves the cursor at least twice — `raw
new` makes the destination current, and the mid-life restore moves back — so by the time the
producer returns, the pair has been rewritten and the user's own history is gone.

## Why it was not caught

Two reasons, and the second is the more interesting:

1. **Nothing asserts the pair.** The destination's own suite
   (`tests/headless/test_calc_wave_dest.tcl`, bands `WD0`–`WD10`) fences the *current* slot
   thoroughly — `wd_curslot` appears across the band — and never reads `prev`.
2. ⚠ **A read-only getter already clobbers it.** `DESTINATION_CONTRACT.md` §10 records that a
   read-only graph getter moves `extra_prev_idx`, which is why `switch_back` was rejected as the
   restore mechanism in the first place. That decision was right about the *restore* and was then
   read as covering the whole pair. It does not: declining to **use** `switch_back` does not stop
   the producer from **spending** it.

## Two things to decide, and they are separable

1. **Should the producer preserve `prev`?** It can: the pair is readable before anything moves and
   both halves are settable with two `raw switch <name> <type>` calls in the right order (prev
   first, then cur). That is roughly four lines in `calc::wave_dest_restore`, which already takes
   a name and a type and already runs on every exit path.
2. **Should `calc::wave_dest_drop` restore the pair the ANSWER captured, rather than whatever is
   current at drop time?** The answer dict already carries `prev` and `prevtype`, captured before
   anything moved — so the information needed is already in hand and is currently used only for
   the current slot.

⚠ **A fence for either must use THREE registered databases with the user on a non-zero slot.**
A bare `raw switch <name>` is **round-robin** (rc 1; `0→1`, `1→2`, `2→0`), so on a two-slot
fixture a wrong restore lands on the right slot **by accident**. That is this batch's own named
vacuity trap, and it has already been paid for once — `DESTINATION_CONTRACT.md` §11(b) records
the same two-slots-is-not-enough finding against a different row.

## Not a blocker for stage J

Stage J's wiring units answer the destination and do not touch the restore, so a row asserting
`switch_back` behaviour would be **red on correct stage-J code**. That is why this is filed rather
than folded in: letting it into the stage's red would make the stage's own evidence ambiguous.
