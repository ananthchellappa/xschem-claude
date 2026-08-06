# 0236 — `::sympin_place` is a write-only owner latch: it names the last form that *called* `arm`, never gets cleared, and makes Add-Pin and Add-Wire-Label swap identities at the shared drop witness

Status: **OPEN** — measured A/B with the real form procs, two generators that need no injection, fix
drafted (preferred fix deletes the latch), not implemented. **Major**.
Area: `src/xschem.tcl:10985`, `:11350` (writes), `:10930`, `:11294` (reads) — 2 writers, 2 readers,
**0 clear sites**, no C reference anywhere; the witness they guard is
`src/callback.c:2657` (`sympin_drops`)
Tests: `test_sympin_drop_log.tcl` (self-skips without Tk),
`scratchpad/verify_pinlabel_forms.tcl` (36/36, the 0122 F1/E1 harness)
Found: 2026-08-06, verifying issue **0230**'s out-of-scope list (its item 4)
Related: **0122** E1/E2 + F1/F2 (the drop witness and the `.drw` slot handoff this mirrors),
`doc/claude/specs/add_wire_label.md` **#8** ("cross-form drop cross-talk" — the latch is that item's
mitigation), **0230**, **0235** (the sibling `.drw <Key-Escape>` handoff, same failure shape).

## What breaks

`sympin_drops` (`callback.c:2657`) is **one** counter for **both** placement forms — 0122 F1 narrowed
it to *form* drops, never to *which* form. Each form snapshots it at arm and compares in
`after_drop` (`xschem.tcl:10935`, `:11298`) to decide "did my label/pin actually land?". The only
thing separating the two is `::sympin_place`, and it is checked **before** the witness
(`:10930` / `:11294`), so a stale latch both mis-attributes real commits and hides the 0122-E1 pause.

## Measured — same inputs, only the latch differs

```
=== CONTROL: latch names the true owner ===
  pre-drop : latch=label drops=0  pin.armed=1 lab.armed=1  ui=16424
  commit   : rc=1 drops=1 ui=8 inst=1 sym0=lab_pin.sym lab0=A
  POST pin : name={IN OUT} armed=1        <-- correct: did not drain
  POST lab : name={B}      armed=1        <-- correct: drained A, re-armed B

=== BUG: latch stale (names the pin form) ===
  pre-drop : latch=pin   drops=1  pin.armed=1 lab.armed=1  ui=16424
  commit   : rc=1 drops=2 ui=8 inst=1 sym0=lab_pin.sym lab0=A     <-- a LABEL committed
  POST pin : name={OUT}  armed=1  status={placing 'OUT' (inout) -- click to place}
  POST lab : name={A B}  armed=1  status={placing 'A' (+1 queued) -- click ON a wire...}
  BUG residue: inst1 sym=iopin.sym lab=OUT selected=1
```

On a real `lab_pin lab=A` commit the stale latch:

1. made **Add-Pin** eat the queued name `IN` although no pin was placed;
2. made it **re-arm an `iopin.sym lab=OUT` port preview on the cursor** of a user who is placing net
   labels — their next click drops a **port**, not a label;
3. left **Add-Wire-Label**'s queue at `A B` although `A` was committed, so its next drop places a
   **second** `lab_pin lab=A` on the same net.

Both status lines then lie.

## How the latch goes stale — two generators, neither needs injection

**Generator 1 — a `-place` that armed nothing still writes the latch.** `addlabel::arm` runs
`xschem add_wire_label -place` (`:11349`) and then `set ::sympin_place label` / `set armed 1`
(`:11350-11351`) with **no check that anything armed**. Over a `.sym` view the C body returns
immediately (`scheduler.c:1836`, `editing_symbol_view()`), so:

```
  loaded .sym                          ui=0      preview=0 drops=0 latch=<unset>
  addpin::start_pass (add_symbol_pin)  ui=16424  preview=1 drops=0 latch=pin
  addlabel::start_pass (.sym NO-OP)    ui=16424  preview=1 drops=0 latch=label   addlabel.armed=1
  at the pin's real commit: addpin::after_drop bails=1;  addlabel::after_drop bails=0 -> it DRAINS
```

The label form flipped the latch and set `armed 1` while `ui_state`/`sympin_preview` still describe
the **pin's** preview. Every subsequent pin drop in that symbol silently eats a queued label name.
(A failed `place_wire_label()`/`place_sch_pin()` — `scheduler.c:1878` — is a second, rarer route.)

**Generator 2 — nothing ever clears it, and that suppresses the 0122-E1 recovery.**

```
  addlabel armed                 ui=16424 preview=1 latch=label
  after xschem abort_operation   ui=0     preview=0 latch=label
  after addlabel::escape (Close) ui=0     preview=0 latch=label
  after addlabel::on_destroy     ui=0     preview=0 latch=label   (.addlabel destroyed)

 stray click, nothing armed, no commit (the 0122-E1 condition):
  BUG   latch=label     -> armed=1 name={IN OUT} status={placing 'IN' (inout) (+1 queued) …}
  CTRL  latch=<cleared> -> armed=0 name={IN OUT} status={placement paused (another action took over)
                                                         -- edit the name or reopen to resume}
```

The latch outlives `escape`, `on_destroy`, both `abort_if_placing` disarm branches of `arm`
(`:11334`, `:11342`) and C's `abort_operation()` — so it keeps naming a form that owns nothing, often
a **destroyed** one. Because the latch guard sits *above* the E1 witness, the survivor becomes a
silent zombie: no drain, no pause, no status change — exactly the "reads as a hang" symptom
0122 F2 was written to remove.

## Root cause

Three independent faults in one shape:

1. **Written unconditionally after a `-place` that can be a total no-op** (generator 1).
2. **Never cleared** (generator 2).
3. **It is the sole cross-form discriminator for a witness that is deliberately owner-blind.**
   `callback.c:2657` — `if((ui & START_SYMPIN) && xctx->sympin_preview) xctx->sympin_drops++;`

`placing()` (`:10880`, `:11227` — `ui_state & 16384`) is owner-blind too, which is why the
redundant-rearm shortcut `if {$current eq $last && [addlabel::placing]} return` (`:11346`) can skip
the latch write while the **sibling's** preview is attached.

## Fix sketch

**Preferred (structural — delete the latch).** The owner discriminator already exists in C at the
exact funnel: `xctx->wirelabel_preview` is 1 for a label preview (`scheduler.c:1865`), forced to 0 by
both pin arms (`:1730`, `:1783`), and `wire_label_try_commit()` calls `end_move_copy_logged(0)`
*before* zeroing it — so at `callback.c:2657` it is 1 for a label drop and 0 for a pin drop:

```c
if((ui & START_SYMPIN) && xctx->sympin_preview) {
  xctx->sympin_drops++;                    /* keep: existing getter/tests depend on the total */
  if(xctx->wirelabel_preview) xctx->sympin_drops_label++; else xctx->sympin_drops_pin++;
}
```

Expose both beside `scheduler.c:4509` (`xschem get sympin_drops_pin|_label`), have each form
snapshot and compare its **own** counter, then delete `::sympin_place` outright — all four sites.
Cross-form cross-talk (what `add_wire_label.md` #8 was papering over) becomes structurally
impossible, and the 0122-E1 pause becomes exact for both forms.

**Minimal Tcl-only fallback**, if C is off-limits:
(a) write the latch only when the C actually armed — replace the unconditional
`set ::sympin_place <tok>; set armed 1` (`:10985-10986`, `:11350-11351`) with a
`[xschem get sympin_preview] && [<ns>::placing]` check; on the false branch `set armed 0; set last
{}` plus a status ("net labels cannot be placed in a symbol view").
(b) clear the latch at every disarm, **only when it is mine** —
`if {[info exists ::sympin_place] && $::sympin_place eq {label}} {unset ::sympin_place}` in `escape`,
`on_destroy` and the two `abort_if_placing` branches. Clearing unconditionally would let a closing
form steal the survivor's ownership and re-open #8 — the same trap 0122-E2 hit with the shared
`.drw <Key-Escape>` slot, where `release_esc` hands the slot to the sibling rather than clearing it.

## Landmines

- **`xschem get sympin_drops` is load-bearing in the GUI harness.**
  `scratchpad/verify_pinlabel_forms.tcl` (36/36) asserts 0122 F1 (a foreign `net_label` drop must not
  bump it, a real form drop must) and E1. Keep the existing total and only *add* per-owner counters.
- **`test_sympin_drop_log.tcl` self-skips without Tk**, so a green `--nogui` run does **not** clear a
  change to `end_move_copy_logged`. Run it under a display with `--logdir`.
- **Gating the latch/`armed` write on "the C actually armed" changes form state over a `.sym` view.**
  `test_add_pin_lib_symbol_view.tcl` asserts `[placing] 1` for the **pin** form in a library symbol
  view — the pin path must keep arming (`place_verb` → `add_symbol_pin`); only the label path may go
  quiet there.
- **Do not "reset ownership" by calling `abort_operation()` from `arm()`** — 0230 fix (B) documents
  why (`callback.c:502-505`): on a `-place` re-arm a preview is already live, and tearing it down
  clears `sympin_preview`, so the next `-place` pushes a **second undo baseline for one gesture**.
- **`ciform::after_drop`** (`create_instance.tcl:64-71`) is a **third** form on the same
  `.drw <ButtonRelease>` hook with neither the latch nor any drop witness — only `placing()`. Any
  redesign of the ownership witness must decide whether it joins or stays a known asymmetry.
- Re-run: `test_add_wire_label.tcl` (82), `test_sch_add_pin.tcl` (21),
  `test_add_pin_lib_symbol_view.tcl`, `test_sympin_drop_log.tcl`, `test_readonly_guard.tcl`.

## Adjacent defect, same two procs (record, do not merge)

`placing()` and therefore `abort_if_placing` are **owner-blind**: closing *either* form tears down
the *sibling's* live preview (`:10881`, `:11228` test only `ui_state & 16384`). Milder — in that
direction the latch stays correct and the 0122-E1 recovery does fire — but it is the same
cross-form-ownership hole from the other side.

## Headless limits

Tk is entirely absent under `--nogui` (`info commands winfo` is empty), so `winfo` and the two
`status` sinks were stubbed; **everything else ran for real** — both `arm()`s, both `after_drop()`s,
`start_pass`, `escape`, `on_destroy`, `place_verb`, and every C seam they call.

Not shown headlessly: the real Tk `<ButtonRelease>` hook order between the two `+`-bound
`after_drop` handlers, the visible status text, and a genuine mouse-driven **pin** drop — note
`xschem move_objects end 0 0 0` (used as "the RELEASE-equivalent" by `test_sch_add_pin.tcl:59`)
leaves `ui=16392`, `sympin_preview=1`, **`sympin_drops=0`**: it never reaches
`end_move_copy_logged`. `xschem add_wire_label -drop` is the only headless path that bumps the
witness, so there is **no headless seam for a pin drop at all** — worth fixing while here.
