# 0246 — `::sympin_place` is a write-only owner latch: it names the last form that *called* `arm`, never gets cleared, and makes Add-Pin and Add-Wire-Label swap identities at the shared drop witness

Status: **FIXED** 2026-08-11 (item D9) — the latch is **deleted** at all four sites and the drop
witness is split per owner in C. Resolution, decisions, sabotage matrix and what is **still open**
are at the bottom of this file. **Major**.
Area: `src/xschem.tcl` — 2 writers (`addpin::arm`, `addlabel::arm`), 2 readers (both `after_drop`),
**0 clear sites**, no C reference anywhere; the witness they guard is `sympin_drops`
(`src/callback.c`, `end_move_copy_logged`).
Tests (before): `test_sympin_drop_log.tcl` (self-skips without Tk) — and **nothing else**: the
`scratchpad/verify_pinlabel_forms.tcl` "36/36 harness" cited below **does not exist in the tree**
(there is no `scratchpad/` directory), and no test in `tests/` mentioned `sympin_place` or
`sympin_drops`, so both `arm()`/`after_drop()` pairs started with **zero** regression cover.
Tests (after): `test_add_wire_label.tcl` section W (11 rows), `test_sch_add_pin.tcl` section Q
(9 rows), `test_add_pin_lib_symbol_view.tcl` S13 (2 residue rows).

Found: 2026-08-06, verifying issue **0240**'s out-of-scope list (its item 4)
Related: **0122** E1/E2 + F1/F2 (the drop witness and the `.drw` slot handoff this mirrors),
`doc/claude/specs/add_wire_label.md` **#8** ("cross-form drop cross-talk" — the latch was that
item's mitigation, now replaced), **0240**, **0245** (the sibling `.drw <Key-Escape>` handoff, same
failure shape), and the residues split out of the fix: **0401**, **0402**, **0403**.

> **Line numbers in the body below are as-found on 2026-08-06 and are stale.** Corrected map
> (measured at 9e51b4c8): writes `10985`→`11103`, `11350`→`11506`; reads `10930`→`11048`,
> `11294`→`11450`; the witness bump `callback.c:2657`→`:3344`; `scheduler.c` `1836`→`2023`,
> `1865`→`2065`, `1730`→`1875`, `1783`→`1958`, `1878`→`1997`; getter `4509`→`4891`.

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
- **Do not "reset ownership" by calling `abort_operation()` from `arm()`** — 0240 fix (B) documents
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

---

# RESOLUTION — 2026-08-11, item D9 (branch `open_pdk`)

**What shipped:** `::sympin_place` is **deleted** (all four sites). The single committed-drop
witness is split by owner in C — `xctx->sympin_drops_pin` / `xctx->sympin_drops_label`, bumped in
the *same* funnel under the *same* gate as the existing total, discriminated by `wirelabel_preview`
— exposed as `xschem get sympin_drops_pin|_label`, and each Tcl form snapshots and compares **only
its own part** (`addpin::drops`, `addlabel::drops`). `sympin_drops` and its getter are untouched;
`sympin_drops == sympin_drops_pin + sympin_drops_label` is asserted.

## BEFORE — measured at HEAD 9e51b4c8, quoted verbatim

Census (`rg -n 'sympin_place' src/ tests/` → 4 hits, 0 in C, 0 in tests):

```
src/xschem.tcl:11048:  if {[info exists ::sympin_place] && $::sympin_place ne {pin}} return
src/xschem.tcl:11103:  set ::sympin_place pin             ;# owner latch: this preview is a PIN (add_wire_label.md #8)
src/xschem.tcl:11450:  if {[info exists ::sympin_place] && $::sympin_place ne {label}} return
src/xschem.tcl:11506:  set ::sympin_place label        ;# owner latch: this preview is a LABEL (add_wire_label.md #8)
```

Primary repro, **no state injection** (label arms → pin arms on top → the label form's
redundant-rearm shortcut returns before the latch write → pin form escapes → one stray release):

```
BUG  latch=pin lab.armed=1 queue={A B} status={}
CTRL latch=<unset> lab.armed=0 queue={A B} status={placement paused (another action took over) -- edit the name or reopen to resume}
```

Generator 1 — a `-place` that armed nothing still writes the latch and `armed=1`:

```
loaded=/home/analog/dev/xschem-claude/xschem_library/devices/lab_pin.sym sym_view=1
G1  add_wire_label -place  rc=0 res={} ui=16424 wlp=0
G1  after addlabel::start_pass  latch=label lab.armed=1 status={placing 'A' (+1 queued) -- click ON a wire or pin to drop; Esc finishes} sympin_preview=1
```

Generator 2 — the latch outlives the form's own destruction (zero clear sites):

```
S0-1 armed         latch=label ui=16424 sympin_preview=1 lab.armed=1
S0-4 on_destroy    latch=label ui=0 sympin_preview=0 lab.armed=0
```

Identity swap — a real LABEL commit drains the PIN queue and re-arms a port preview:

```
SWAP commit is a LABEL: rc=0 res={1} inst0=lab_pin.sym lab=A
SWAP pin  queue={OUT} armed=1 status={placing 'OUT' (inout) -- click to place; Ctrl+MMB cycles type; Esc finishes}
SWAP lab  queue={A B} armed=1 status={}
```

Witness getters before:

```
GET sympin_drops -> rc=0 res={0}; GET sympin_drops_pin -> rc=0 res={}; GET sympin_drops_label -> rc=0 res={}; GET sympin_place -> rc=0 res={}
```

(the three empties are issue **0392**'s fail-soft unknown key — which is what made the new rows
RED-first assertable.)

## AFTER — same binary, same scripts, rows quoted from the suites

```
0246 W1 pin drop witness is an integer -> ok            (was FAIL {0} exp {1})
0246 W4 label drop bumps the label witness -> ok        (was FAIL {-1} exp {0})
0246 W5 label drop bumps ONLY the label side -> ok      (was FAIL {-1 -1})
0246 W6 the parts add up to the whole -> ok             (was FAIL {1 0} exp {1 1})
0246 W8 owner latch no longer exists -> ok              (was FAIL {1} exp {0})
0246 W9 non-owner form disarms on a foreign release -> ok   (was FAIL {1} exp {0})
0246 W10 the 0122-E1 pause line is reachable again -> ok    (was FAIL {})
0246 Q3 non-owner pin form disarms -> ok / Q4 pause line reachable for the pin form -> ok (both were FAIL)
0246 Q2/Q5 GUARDs (a label drop must not drain the pin queue; no port preview re-armed) -> ok, still green
0246 Q6 GUARD the owning form still drains and re-arms -> ok {B 2}; Q7 parts add up, pin witness unmoved -> ok {1 1 0}
```

Adversary pass, under a **real** GUI (`GUI_GATE=0 xvfb-run -a`, genuine ButtonPress/ButtonRelease
into `.drw`) — this is the pin-COMMIT direction decision D9 says has no headless seam:

```
add_sch_pin -place + click        -> pin=1 lab=0 tot=1 inst=1
add_wire_label -place + click     -> pin=1 lab=1 tot=2 inst=2
```

and the full end-to-end identity swap with real Tk toplevels: a real **pin** drop drains the pin
queue and re-arms, while the label form keeps `A B`, disarms, and posts the E1 pause line. The old
behaviour does not reproduce.

Tier counts: `test_add_wire_label` 182 → **196**, `test_sch_add_pin` 25 → **34**,
`test_add_pin_lib_symbol_view` PASS=12 → **14**; every other tier byte-identical
(shape_draw 421, paste_modify 376, placement_wire_gate 187, label_ride 157, preview_doors 206,
strand_oracle 32, create_instance 72, instance_update 95, inert_class 177, descend_symbol 38,
refusal_channel 45, hi_descend 24, cadence_descend_newwin_ro 11, log_absorb 23, WIREEDIT ALL PASS,
run.sh 6 goldens PASS, `run_regression.tcl` exactly the 3 known-red sg13g2 lines).

## Decisions (ladder rung + the alternative that was rejected)

- **D1 — structural, not hygiene: delete the latch, split the witness in C.** Rung **R1**
  (0243 F2: the fact belongs at the one commit funnel that already knows it; 0241: a teardown must
  name what it tears down). *Rejected:* this issue's own Tcl-only fallback (write the latch only on
  a successful arm, clear it at every disarm) — it keeps a second source of truth, does nothing
  about generator 1, and adds four clear sites inside `<Destroy>` handlers, the 0122-E2
  ownership-steal trap.
- **D2 — keep `sympin_drops` and its getter; only ADD the parts, and assert total == pin+label.**
  Rung **R1** (the total is named load-bearing by this issue's own landmines). *Rejected:*
  replacing the total, which would silently break any out-of-tree/GUI reader.
- **D3 — the one behaviour delta: the non-owner form now disarms and posts the existing 0122-E1
  line instead of returning silently with `armed=1`.** Rung **R1** (0122 E1/F2 already ratified
  "did not commit ⇒ pause and say so"; 0244/0267/0270: an aborted gesture must not lie — the
  sibling's `-place` had already torn this form's preview down, so `armed=1` plus a stale
  "placing …" was false). No new string, no new state. *Rejected:* pausing only when the **total**
  also failed to move, which preserves the zombie `armed=1` and the stale status line.
  *Question if a human later disagrees:* should the non-owner stay silent when the other form
  legitimately committed, and pause only when nothing at all committed?
- **D4 — read the discriminator INSIDE the existing `(ui & START_SYMPIN) && sympin_preview` gate,
  as one extra call in the one funnel.** Rung **R1** (0122 F1 requires the bump to stay gated or
  `place_net_label`/`add_graph`/`add_image` start counting; landmine 2 forbids gating the
  pure-commit coordinate forms). *Rejected:* bumping from the two commit routes separately — two
  sites drift from the total and move counting outside the funnel.
- **D5 — do NOT make `placing()` owner-aware here; filed as 0401.** Rung **R2** (least surprising /
  smallest blast radius: `placing()` also drives `abort_if_placing`, the Ctrl+MMB type cycle and the
  0245 canvas-Escape rows, and `wirelabel_preview` can be left stale by a door, 0262/0399 — an
  owner-aware `placing()` could make a Close button stop aborting a real preview). *Rejected:*
  adding the owner conjunct now.
- **D6 — do NOT gate the `armed`/status write on "the C actually armed"; filed as 0402.** Rung
  **R2** explicitly avoiding **R3** — it changes what a user sees in a `.sym` view (a refusal line
  instead of "placing 'A' …"), which is user-visible and unratified and would force this item to
  status E. The *harm* generator 1 caused is already gone under D1: a label form in a symbol view
  can never move `sympin_drops_label`. *Rejected:* folding fallback (a) in here.
- **D7 — the C addition is two tiny statics (`sympin_owner_is_label`, `sympin_count_owner`), not an
  inline if/else.** Rung **R2** — it is the only shape the crew's sabotage protocol can neutralize
  by macro rename, and it costs six lines. *Rejected:* inline if/else at the bump.
- **D8 — extend the two existing tier suites plus one residue row; no new test file.** Rung **R1**
  (the run's explicit instruction to prefer extending). *Rejected:* a new
  `tests/headless/test_sympin_owner.tcl`.
- **D9 — the pin-COMMIT direction gets no positive headless row; the gap is recorded here.** Rung
  **R2** — there is no headless seam (`xschem move_objects end 0 0 0` never reaches
  `end_move_copy_logged`; `xschem callback .drw 5 …` SIGSEGVs under `--nogui`). Covered
  adversarially by sabotage S2/S3 and, once, by the xvfb run quoted above. *Rejected:* inventing an
  `add_sch_pin -drop` verb (a new user-facing seam) or hiding an X-only section inside a headless
  tier suite.
- **D10 — doc closure is part of the item.** Rung **R1** (0241's naming rule applied to docs; a
  decision is ratified only once written). `add_wire_label.md` gains a real **#8** body naming the
  owner split (it previously named the latch as the mitigation, with no body section at all); 0122's
  E1 prose gains a one-clause "that latch is gone"; this file goes to FIXED. *Rejected:* leaving
  the spec line stale as a doc-only nit.

## Sabotage matrix (Verify-B; every variant restored + rebuilt + re-asserted green afterwards)

| variant | how | predicted red | observed |
| --- | --- | --- | --- |
| **S1** owner split never runs | `#define sympin_count_owner() ((void)0)` above `end_move_copy_logged`, rebuild | W4 W5 W6 Q6 Q7 | **exactly those 5** (W5 `{0 0}` vs `{0 1}`, W6 `{1 0}`, Q6 `{{A B} 1}` vs `{B 2}`, Q7 `{1 0 0}`) |
| **S2** pin form reads the shared total again (the 0246 identity swap) | append `proc addpin::drops {} { return [xschem get sympin_drops] }` to `xschem.tcl`, no rebuild | Q2 Q3 Q4 Q5 | all 4, **plus an unpredicted Q6** (`{{A B} 2}`): the pin form re-armed, so the owner's own `after_drop` hit the owner-blind `placing` guard. Extra red, not a hole |
| **S3** discriminator inverted to always-pin | `#define sympin_owner_is_label() 0`, rebuild | W4 W5 Q2 Q3 Q4 Q5 Q6 Q7 | **all 8**. W6 correctly stayed **green** (total still equals the parts, merely miscredited) — it was not predicted red |
| **S4** getters renamed out from under Tcl | `sympin_drops_pin`→`_pn`, `_label`→`_lbl` in `scheduler.c`, rebuild | W1 W2 W3 W4 W5 W6 Q1 Q6 Q7 | **exactly those 9**; confirms 0392's fail-soft turns a renamed key into a permanent silent pause, and that the rows catch it |
| **S5** Tcl half reverted, latch restored | `git checkout HEAD -- src/xschem.tcl` only (C half left in), no rebuild | W8 W9 W10 Q3 Q4 | **exactly those 5**. W3–W6 stayed green here because the C witness is still split and, with no pin drop in that suite, the old total-based `drop_snap` happened to equal the label part |

**Predicted red that did not appear: none.** One **recipe correction**: S3's macro must sit
immediately above `sympin_count_owner`, not above `end_move_copy_logged` — the latter is *below* the
only call site, so as written the macro would never apply and S3 would have come back all-green,
falsely reading as "the discriminator is uncovered".

## STILL OPEN (adversary residual risks — 0246 does **not** close these)

1. **The LABEL half of the split has no committed regression row.** A one-line regression
   (`proc addlabel::drops {} {xschem get sympin_drops}`) leaves `test_add_wire_label` at 196 ALL
   PASS and `test_sch_add_pin` at 34 ALL PASS — and yet, demonstrated under xvfb, a real GUI **pin**
   drop then drains the label queue `A B`→`B` and arms a `lab_pin` on the cursor of a user placing
   pins: the exact 0246 identity swap. The cause is D9's gap — headlessly a pin commit is
   impossible, so the total is identically equal to the label count in those suites, and W3–W6 are
   named for a distinction they cannot detect. This half rests on the **sabotage protocol alone**.
   Closing it needs an xvfb-driven row (dummy `.addpin`/`.addlabel` toplevels + real
   `xschem callback .drw 4/5` events) in a suite that is allowed to need X.
2. **The pin-COMMIT direction has only X-dependent evidence** (the xvfb transcript above). No
   committed row exercises it, so a future break of the `else` branch is invisible to every
   headless tier.
3. **Cross-context false drain survives** — arm a form, `xschem new_schematic create`, one stray
   release: the form consumes an un-placed queued name and arms a preview in the wrong schematic.
   Pre-existing (byte-identical with the pre-0246 total witness) and inherited from the 0122-F3
   scope note, but the fix's framing ("a counter only its own commits can move") reads as if it were
   closed. **Filed as issue 0403.**
4. **Decision D3 is hook-order dependent.** The non-owner form pauses only when its
   `<ButtonRelease>` hook runs *before* the owner re-arms; in the other order the owner's re-arm
   re-raises `START_SYMPIN` and the non-owner's owner-blind `if {[placing]} return` leaves it
   `armed=1` with an empty status (measured: `pin.queue={IN OUT} pin.armed=1 pin.status={}`). It
   never *drains*, and it behaved the same way before 0246, so it is residue, not regression. Q4/W10
   pin only the favourable order. **Recorded in issue 0401** (its second face).
5. **The teardown is still silent at the door.** When a sibling's `-place` deletes this form's
   preview, nothing is said *at that moment*; the E1 pause arrives only on a later stray release,
   and only in the favourable hook order. 0241's naming rule is satisfied late and conditionally.
6. **Version skew has no guard.** A new `xschem.tcl` against an older binary makes both getters fail
   soft to `""` (issue 0392), so `drop_snap` is `""`, every compare is `"" == ""`, and both forms
   pause forever without ever draining. Degraded rather than destructive, but silent.
7. **The counters are monotonic and never reset** — not by undo, `clear force` or `xschem load`
   (verified; a same-context load keeping the witness is the safe direction). Nothing in C checks
   `sympin_drops == sympin_drops_pin + sympin_drops_label`, so a future reset of one part alone
   would break the invariant silently.
8. **`addpin::drops` / `addlabel::drops` propagate a Tcl error out of a bind script when `xctx` is
   NULL** (the getters return `TCL_ERROR`). Pre-existing shape — the old code called
   `xschem get sympin_drops` in exactly the same places — but the fix doubled the number of such
   call sites.
9. **Residues split out and filed, not fixed:** **0401** (owner-blind `placing()`, both faces),
   **0402** (an arm that armed nothing still claims `armed`/"placing"), **0403** (cross-context
   drain). The `ciform` third form on the same `.drw <ButtonRelease>` still has neither a witness
   nor an owner (`create_instance.tcl`) — a known asymmetry this issue's landmines already record,
   untouched here.

## Where it landed

- `src/xschem.h` — `sympin_drops_pin`, `sympin_drops_label` beside `sympin_drops` (per
  `Xschem_ctx`; the struct is `my_calloc`'d, so no init needed).
- `src/callback.c` — `sympin_owner_is_label()` / `sympin_count_owner()` above
  `end_move_copy_logged`, called inside the existing gate right after `xctx->sympin_drops++`.
- `src/scheduler.c` — two exact-`strcmp` getter branches beside the `sympin_drops` one.
- `src/xschem.tcl` — `::sympin_place` deleted (4 sites); `addpin::drops` / `addlabel::drops`; both
  `arm`s snapshot their own witness; both `after_drop`s compare it.
- `tests/headless/test_add_wire_label.tcl` (section W), `tests/headless/test_sch_add_pin.tcl`
  (section Q), `tests/headless/test_add_pin_lib_symbol_view.tcl` (S13).
- `doc/claude/specs/add_wire_label.md` (#8 body + implementation map), `doc/claude/issues/0122…md`.
