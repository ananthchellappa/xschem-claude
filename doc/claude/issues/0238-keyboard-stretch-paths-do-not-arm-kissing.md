# 0238 — the keyboard stretch paths call `select_attached_nets()` without arming kissing, so even an endpoint net label is stranded

Status: **OPEN, and narrowed twice** — measured repro, one-line fix per site, not implemented.
User-visible behaviour change: needs a release note.
**Split** per `doc/claude/specs/wire_label_ride.md` §8: the *label* half is subsumed by that
spec's S3 (the rider does not need kissing armed); the **device-pin** half below stays a real,
independent bug and this issue tracks it.

> ### ✅ PARTLY CLOSED 2026-08-06 by `wire_label_ride.md` S3 — and the "label half" turns out to have TWO directions
>
> S3's RIDE is deliberately **not** gated on `connect_by_kissing`, so it fires on these very paths.
> That closes the direction this issue's own repro exercises. Measured, same fixture as "Measured"
> below, `move_objects 0 100 stretch` with no `kissing`:
>
> | direction | gesture | before S3 | after S3 |
> |---|---|---|---|
> | the **WIRE** moves, the label stays (this issue's repro) | `select wire; move_objects … stretch` | `#net1`, strands 1 | **`VOUT`, strands 0** |
> | the **LABEL** moves, the wire stays (the S2 widening below) | `select instance; move_objects … stretch` | `#net1` | `#net1` — **unchanged** |
>
> The second row is not something RIDE can reach: nothing the gesture moves is under the label's
> anchor, so there is no rider, and S1's LEASH is gated on `connect_by_kissing` — which
> `wire_label_ride.md` §14.6 pins as *policy* (it is what makes the rigid move and the Ctrl+LMB
> detach a deliberate detach, `test_label_ride.tcl` K1/K2). Widening that gate was considered and
> rejected. **The second row closes with THIS issue's own one-line fix below**: arm kissing before
> the follow-grab, and the leash fires there for free. So the fix is unchanged, its label
> justification is now only the second row, and the device-pin justification is untouched.
>
> Witnesses: `tests/headless/test_label_strand_oracle.tcl` **D3/D4** (flipped to `0`/`VOUT`) with
> **D3L/D4L** keeping the pre-S3 measurement under `label_ride 0`; `tests/headless/test_wire_split.tcl`
> **W7b** (unchanged, re-authored in comment only) and the new **W7b2** for the closed direction.
> Spec `wire_label_ride.md` **§16.7**.
**S1 (2026-08-05) does NOT cover these paths, by design.** The leash that replaces the kissing stub
for a moving label is gated on `xctx->connect_by_kissing` (spec §5.6, §14.5) — precisely so that S1
is a *replacement* on the connected drag and a no-op everywhere else. The two keyboard entry points
below never arm kissing, so they get neither the old stub nor the new leash and behave exactly as
they do today. That is another reason to fix them here rather than widen the leash's gate.
**WIDENED 2026-08-06 by S2 (`wire_label_ride.md` R2).** This issue's shape was "the *keyboard*
stretch paths never arm kissing". The label half now also reaches **any** `stretch` without
`kissing` on a MID-SPAN label, because S2 removed the split that used to rescue it by a second
route: with the wire split at the label pin, `select_attached_nets()`' ELEMENT arm — which fires
only on `endpoint_near` (`select.c`) — grabbed both halves and stretched them to follow the label,
so the net survived even with kissing withheld. Interior to one unsplit wire that arm never fires
(spec §6 change #11 predicted exactly this, filed there as comment-only), so the label commits off
copper and the net reverts to `#netN`. Measured 2026-08-06: same fixture, `label_splits_wires 1` →
net `GB`, `label_splits_wires 0` → `#net1`; a stock-config user (autotrim off, never split) has had
the `#net1` result all along. Witness: `tests/headless/test_wire_split.tcl` **W7b/S2** plus its
legacy leg. This does not change the fix below — widening the leash's gate is still the wrong
answer (§14.6 pins that as policy) — but it does raise the priority, and it is the same mask
removal that escalated issue **0237**. Spec §15.3.

**Instrumented 2026-08-05 (spec S0):** the label half now has an oracle —
`tests/headless/test_label_strand_oracle.tcl` case D3 drives a stretch with kissing withheld
under `autotrim_wires 1` and scores `fluid_last_move_label_strands` = 1, which is this issue's
claim that autotrim does *not* mask the loss on these paths.
Area: `src/callback.c:6445` and `src/callback.c:6466` (the `m` / Ctrl+m stretch entry points)
Tests: none yet — proposed leg in `tests/headless/wireedit/test_wireedit_NN_midspan_label_0237.tcl`
Found: 2026-08-05, alongside **0237**
Related: **0237** — the sibling hole in `connect_by_kissing()` itself. Do both; neither subsumes the other.

> Fluid-engine adjacent. Per `MEMORY.md` another agent owns that area — read
> `doc/claude/WIRING.md` §7 landmines before implementing, and keep the edit merge-friendly.

## The defect

Every *mouse* stretch entry point arms `connect_by_kissing` before grabbing the follow set:

```c
src/callback.c:8014-8020
           int stretch = (state & ControlMask ? 1 : 0) ^ enable_stretch;
           /* select attached nets depending on ControlMask and enable_stretch */
           if(stretch && !(state & ShiftMask)) {
             …
             xctx->connect_by_kissing = 2; /* 2 will be used to reset var to 0 at end of move */
             select_attached_nets(); /* stretch nets that land on selected instance pins */
```

The two **keyboard** entry points do not:

```c
src/callback.c:6466
        if(!enable_stretch) select_attached_nets(); /* stretch nets that land on selected instance pins */
```

(and the mirrored site at `src/callback.c:6445`).

`select_attached_nets()` (`src/select.c:1738-1853`) only ever adds **wires** — the
invariant is documented and load-bearing at `src/callback.c:5827`. Connectivity to a
stationary instance pin is rescued entirely by `connect_by_kissing()`
(`src/actions.c:2042`), which drops a zero-length `SELECTED1` stub at a coincident pin. If
kissing is never armed, that rescue never runs, and **even an endpoint net label is left
behind** — a strictly worse case than 0237, which needs the label to be mid-span.

## Measured

```
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 0 0 0 0 {name=l1 lab=VOUT}    ;# ENDPOINT label
xschem unselect_all; xschem select wire 0
xschem move_objects 0 100 stretch          ;# no "kissing" == the Ctrl+m path
xschem getprop wire 0 lab                  ;# -> #net1   (was VOUT)
```

Same fixture with `kissing` added (the mouse path) keeps `lab=VOUT` and produces the
rescue stub. The only difference is the missing arm.

GUI equivalent: select a wire whose endpoint carries a net label, press Ctrl+m (or `m`
with "Enable stretch" on), move it. The net loses its name.

## Fix

Arm kissing before the follow-grab, matching every other stretch entry point
(`src/callback.c:8018`, `src/callback.c:3555`, `src/scheduler.c:7499`):

```c
src/callback.c:6445:  if(enable_stretch)  { xctx->connect_by_kissing = 2; select_attached_nets(); }
src/callback.c:6466:  if(!enable_stretch) { xctx->connect_by_kissing = 2; select_attached_nets(); }
```

**Order matters** — kissing must be set *before* `select_attached_nets()`, so
`wire_through_tap_arm()` (`src/select.c:1797`) skips a through-run tap arm. That is why
every other site does it in that order.

## Risks

- **User-visible behaviour change** beyond the label case: with kissing armed, Ctrl+m and
  `m`-with-`enable_stretch` will now also gain stubs at abutting pins and T-junctions.
  Defensible — it makes the keyboard path match the mouse path — but it belongs in a
  release note, and it moves wireedit goldens.
- **Flag lifetime.** `xctx->connect_by_kissing = 2` must be cleared on every exit path.
  `move.c` already resets it at END/ABORT (`:717`, `:752`, `:8243`, `:8361`), but the
  6445/6466 branches can set `MENUSTART` and never reach a move if the user presses Esc.
  Confirm the `MENUSTART` cancel path clears it, or a stale `2` leaks into the next gesture
  — exactly the class of bug the comment at `move.c:716` warns about.
- Re-baseline `tests/headless/wireedit/` by hand per `WIRING.md` §10 (CI cannot catch a
  fluid regression). Press **Allow 30m** on the GUI-gate panel once.
