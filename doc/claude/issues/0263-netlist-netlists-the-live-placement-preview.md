# 0263 — `netlist` emits the live placement preview as a real device, so a netlist taken mid-gesture silently renames a net

Status: **FIXED 2026-08-09** (item D2 of the unattended backlog run) — gated at the netlist
**verbs**, not filtered in the traversal. **Major**: the netlist was wrong, silently, and the
hierarchical arm additionally COMMITTED the preview irreversibly. See "Resolution" below.
Area: `src/scheduler.c` (`netlist` verb) and `src/callback.c` (Shift-N), vs the placement-preview
objects in `xctx->inst[]` read by `src/netlist.c`'s shared naming pass.
Tests: `tests/headless/test_placement_preview_doors.tcl` — rows **B14**, **B15** and the whole of
new section **G** (115 → 177 checks). Was a `note:` line in section F; that note is gone.
Found: 2026-08-08, closing issue **0242**
Related: **0242** (parent census, row `netlist`), **0262** (the other 0242 residue, still open and
still reachable through this verb — see "Still open"), **0241**, **0265** (the merge twin of the
ratified rule), **0358** (`save`, the same blindness in another verb, open), **0359**/**0360**/
**0361** (filed by this fix's verification), `doc/claude/specs/add_wire_label.md`.

> **CORRECTION (measured 2026-08-09).** Everything below the header down to "Landmine" is the
> ORIGINAL filing and is kept as the record of what was believed. Its central claim — "it is not a
> door: it clears no gesture bits and leaves no terminal state … the canvas stays alive, and ESC
> still works" — is **FALSE on the hierarchical arm**. `netlist` destroys the gesture and commits
> the preview as an ordinary instance that ESC can never take back. Its recommended fix (option 1,
> a `preview_sel`-keyed traversal filter) is therefore **rejected**: `preview_sel` is destroyed by
> the netlist driver's own `clear_drawing()` before the pass that would need it. Read "Resolution".

## Symptom

```tcl
set ::label_new_name FOO
xschem clear force ; xschem wire 0 0 100 0 ; xschem unselect_all
xschem add_wire_label -place      ;# preview rides the cursor, not dropped
xschem netlist
```

The preview `lab_pin` is a fully-formed instance in `xctx->inst[]` — it is what makes the
0242 orphan netlist-visible in the first place (`xschem instance_net l1 p` → `FOO`). So the netlist
is generated with the label applied: the wire the preview happens to be sitting on comes out named
`FOO` instead of its real name, from a label the user has not dropped and may still be typing.

Measured after the netlist and three ESCs: `sympin_preview=0`, `orphans=1`.

## Why this is NOT issue 0242's defect

0242's doors all **arm a second gesture** and clear `START_SYMPIN`/`STARTMOVE` without running the
teardown, leaving `sympin_preview` set — the terminal desync. `netlist` does neither: both
`sympin_preview` and `START_SYMPIN` end at 0, the canvas stays alive, and ESC still works. It was
listed in 0242's census as "orphan is netlisted" and excluded from that fix on purpose — the
teardown is the wrong tool here. A netlist is a **read** operation; it must not delete the user's
in-flight preview as a side effect, which is exactly what calling `leave_placement_for()` would do.

The bug is that a preview is indistinguishable from a committed instance to everything downstream.

## Options

1. **Exclude preview objects from the netlist traversal.** The identity already exists:
   `xctx->preview_sel` / `preview_sel_n`, stamped at every arm by `stamp_placement_preview()`
   (`select.c`, issue 0241). The traversal would skip ids in that set while a placement is live.
   Cheap and targeted; the risk is that the netlisters walk instances in several places and each
   would need the filter.
2. **Refuse the netlist while a placement is live**, with a statusbar line ("drop or ESC the
   pending placement first"). Honest and one-line, but netlisting is scriptable and often runs from
   automation that would now fail on a state the user cannot see.
3. **Commit nothing, warn only** — netlist as today, plus a loud `dbg(0)` line naming the preview
   instance. Cheapest; leaves the wrong netlist on disk.

**Recommendation: 1.** The preview identity is already tracked for exactly this reason ("what the
live cursor placement is, as durable ids", `xschem.h`), and it is the only option that keeps both a
correct netlist and a live gesture.

## Landmine

The same blindness plausibly affects every other whole-document consumer that walks `xctx->inst[]`
while a gesture is live — `save`, `check`, ERC, the hierarchy traversal, symbol generation. This
issue covers the netlist because that is where it was measured; the sweep is the real work, and
option 1's filter should be written as a shared predicate, not inlined per backend.

*(The landmine was confirmed for `save` on 2026-08-09 and filed as issue **0358** — same blindness,
worse outcome, because `save` persists the orphan to disk. Still open.)*

---

# Resolution (2026-08-09, `open_pdk`, item D2 of the unattended backlog run)

## 1. What was measured BEFORE, verbatim

Fixture: one unnamed net carrying **two** resistors and two grounds — two devices, because what an
undropped label renames is the **NET**, and a one-device fixture cannot show that.

```
$ ./src/xschem --nogui --pipe -q --nolog --script …/scratch_D2/measure_0263.tcl
CTL | R1 net1 GND 1k
CTL | R2 net1 GND 2k
DUT  | before netlist: instances=5 sympin_preview=1 ui_state=16424 modified=0
DUT  | after  netlist: instances=5 sympin_preview=0 ui_state=0 modified=0
DUT  | R1 FOO GND 1k
DUT  | R2 FOO GND 2k
ESC  | surviving instance 4: lab_pin.sym {l1 FOO}
ESC  | after 3x abort_operation: instances=5 lab_pin_count=1 modified=0
CTLX | conn net1 R1 1
TDX  | conn FOO R1 1
```

```
$ ./src/xschem --nogui --pipe -q --nolog --script …/scratch_D2/repro_0263.tcl
--- B. the same with -nohier (no push/pop_undo round trip in the driver)
    netlist: sp=1 START_SYMPIN=1 (gesture survives here)
    R1 line: R1 FOO GND 1k
    N 0 0 300 0 {lab=FOO}
    C {lab_pin.sym} 0 0 0 0 {name=l1 lab=FOO}
RESULT: 0263 REPRODUCED (4 symptom(s))
```

and, from a matched-control leak check (control = arm/ESC/load/arm prints **nothing**):

```
$ …--script …/scratch_D2/leakcheck.tcl      # DUT arm/NETLIST/ESC/load/arm:
fluid_editing: fluid_gesture_arm() re-armed while a prior gesture was still armed --
it leaked its snapshot (WIRING risk #11.10 mid-STARTMOVE abandon); recovering
```

Five distinct symptoms from one `xschem netlist`:

1. **READ defect** — the whole net is renamed. `R1 net1 GND 1k` / `R2 net1 GND 2k` becomes
   `R1 FOO GND 1k` / `R2 FOO GND 2k`. A plausible-looking wrong netlist, no diagnostic.
2. **Backend-independent** — tedax shows the same substitution (`conn net1 R1 1` → `conn FOO R1 1`),
   which is what proves the defect sits in the shared `name_nodes_of_pins_labels_and_propagate()`
   (`netlist.c`, the `my_strdup(&inst[i].node[0], inst[i].lab)` line) plus `name_attached_nets()`,
   and not in `spice_netlist.c`.
3. **COMMIT defect** — `ui_state` 16424 → 0 and `sympin_preview` 1 → 0 across the netlist, done by
   the driver, not by the user.
4. **IRREVERSIBLE** — three `abort_operation`s later `lab_pin.sym {l1 FOO}` is still standing and
   `modified` reads 0 throughout, so the user is never warned and a later save writes it out.
5. **NEW, not in the original filing** — the abandoned gesture leaks a fluid snapshot that
   **outlives a file load**, so the next gesture in the next cell starts in a recovered-from-corrupt
   state.

Mechanism of 3/4: `global_spice_netlist()` `push_undo()`s the document **with** the preview,
`unselect_all(1)` then zeroes `ui_state` wholesale (`select.c` — a live preview is always selected),
`pop_undo(2,0)`'s `clear_drawing()` clears `sympin_preview` / `wirelabel_preview` / `preview_sel`
(`actions.c`), and `pop_undo(4,0)` restores the snapshot with the preview baked in. Four sibling
drivers (spectre, verilog, vhdl, tedax) have the identical round trip.

`xschem netlist -nohier` takes `global=0` and skips the whole push/pop block: pre-fix it was the
**pure READ half** — deck still wrong, gesture intact, ESC still worked. That split is why a filter
alone could never have been the whole fix.

## 2. What changed

Two gate calls, at the two **verbs**, using the teardown machinery already ratified by
0242/0243 F2/0265/0269:

```c
leave_placement_for("Netlist");
leave_merge_for("Netlist");
```

* `src/scheduler.c`, inside the `netlist` branch's `if(set_netlist_dir(0, NULL))` block,
  immediately after `done_netlist = 1;` and **before** the backend dispatch.
* `src/callback.c`, `case 'N'` (the Shift-N current-level netlist key), immediately **before** its
  own `unselect_all(1)`. That siting is load-bearing: `unselect_all(1)` is what destroys the bits
  both gates test, so after it there is no gesture left to abandon — only a committed object.

Placement first, merge second: they share `xctx->preview_sel` and the placement stamp is a superset.

`abort_placement_preview()` resolves the stamped preview identity, runs `move_objects(ABORT, …)`
(which reaches `fluid_gesture_free()` — symptom 5), `delete()`s only the preview, and restores the
modify flag. So by the time any driver runs there is no undropped object in the document: the deck
is correct in every backend, there is nothing for the push/pop round trip to commit, ESC has nothing
left to fail at, and `modified` is untouched.

## 3. What was measured AFTER, verbatim

```
$ ./src/xschem --nogui --pipe -q --nolog --script …/scratch_D2/repro_0263.tcl
--- control: netlist with nothing armed
    R1 line: R1 net1 GND 1k
--- A. hierarchical netlist with a live add_wire_label -place preview
    armed  : sp=1 START_SYMPIN=1 STARTMOVE=1 inst=5 mod=0
    netlist: sp=0 START_SYMPIN=0 STARTMOVE=0 inst=4 mod=0
    esc3   : sp=0 orphan lab_pins=0 inst=4 mod=0
    R1 line: R1 net1 GND 1k
--- B. the same with -nohier (no push/pop_undo round trip in the driver)
    netlist: sp=0 START_SYMPIN=0 (gesture survives here)
    R1 line: R1 net1 GND 1k
--- C. the document the user is left holding after A
    N 0 0 300 0 {lab=#net1}
RESULT: 0263 FIXED
```

(The `(gesture survives here)` text on the `-nohier` line is the repro script's own pre-fix
annotation, now stale: the numbers next to it — `sp=0 START_SYMPIN=0` — are the gate firing on that
arm too, and `inst` returns to the fixture's own 4.)

`leakcheck.tcl` DUT arm/netlist/ESC/load/arm no longer prints the `fluid_gesture_arm()` warning:
symptom 5 is gone.

## 4. Decisions, with ladder rung and rejected alternative

| # | rung | decision | rejected |
|---|---|---|---|
| **D1** | R1 (what) + R2 (how) | Gate at the **verb** with `leave_placement_for()`. R1 supplies 0265's rule — a competing action must ABANDON a pending gesture, never silently accept it — and 0243 F2's "gates live at the VERBS, never at the shared per-click primitive". | This issue's own **option 1** (a `preview_sel`-keyed filter in the emit loops): it fixes only the deck, and `preview_sel` is destroyed by the driver's own `clear_drawing()` before the pass that needs it. **Option 2** (refuse the netlist): netlisting is scripted, and a refusal path must not self-log or replay diverges. **Preserving the gesture across the round trip**: save/restore of `ui_state`, `sympin_preview`, `wirelabel_preview`, `preview_sel` and `sel_array` through a full document reload, in five backend drivers. |
| **D2** | **R3 — user-visible, no prior ratification** | `netlist` now ABANDONS a live placement/paste and **says so** (`Netlist: pending placement abandoned`). Implemented as ABANDON because "survive" is not the status quo being defended: today the hierarchical arm already destroys the gesture and commits the object. | Leaving the deck wrong until a "preserve the gesture" design lands. **THE OPEN QUESTION FOR THE HUMAN:** *should a READ verb (`netlist`, and by extension `save`) end a live placement/paste gesture at all, or should the gesture survive the read?* |
| **D3** | R2 | Only the two gestures that park real objects in `inst[]`/`wire[]` are torn down. `leave_wire_draw_for()` / `leave_shape_draw_for()` are **not** called. | The canonical four-call block. A rubber-band draw owns no object the netlister can see. **But the justification shipped in the code comment is partly false — see issue 0359.** |
| **D4** | R2 | Sited **inside** `if(set_netlist_dir(0, NULL))`, after `done_netlist = 1;`. | Branch entry: on the dir-unwritable path the netlist never runs, and a verb that did nothing must not consume the user's gesture. |
| **D5** | R2 | The `-keep_symbols` axis is **not** excluded from the gate. | Mirroring the self-log gate's `if(done_netlist && !keep_symbols)`: that axis exists for action-log replay fidelity, not gesture ownership. A wrong deck is wrong whoever asked for it. |
| **D6** | R2 | The CLI `-n` batch (`xinit.c`) is left **ungated**. | Gating all three entry points: `--script` is sourced *after* the batch netlist, so no gesture can exist there. An unreachable gate is a lie in the census. |
| **D7** | R1 | The Shift-N key IS gated, above its own `unselect_all(1)`. Code-proved only, no headless check — the path needs `xschem callback` and a window. | Asserting it under xvfb (a real event loop for one line); leaving it ungated (it is the third measured door into the same drivers). Verified working under `GUI_GATE=0 xvfb-run` by the adversary pass. |
| **D8** | R1 | The original "not a door" framing is corrected everywhere it was copied: this file, `WIRING.md` §8 class D, `plan_modal_gesture_exclusion.md`, the 0242 census row. | Fixing the code and leaving four documents asserting the opposite. |
| **D9** | R2 | `save` (issue **0358**) is **not** fixed here. | Applying the same verb gate to `save`/`saveas`/`write_backup`: `write_backup()` has no verb to gate, so 0358's answer is a different shape and a different ratification question. |
| **D10** | R2 | Two residues recorded, not fixed: `leave_placement_for()` early-returns on `xctx->readonly` and on the already-stripped 0262 orphan state. | Dropping the readonly guard (the teardown IS a `delete()`); adding a belt-and-braces `preview_sel` filter for the 0262 state (that is 0262's fix, and `preview_sel` is already gone by then). |

One test-side decision was taken during implementation and is recorded here because it changed an
assertion rather than the code: **G9's original premise was unreachable.** It asserted that a
co-armed merge + placement returns to the fixture's own 4 instances. Neither order ever holds two
*live* gestures — both `add_wire_label -place` and `merge_file()` run their own `unselect_all(1)`,
so the second arm always strips the first's bit while leaving its object in the drawing (measured:
merge→placement gives `ui=16424` with `STARTMERGE` already gone; placement→merge gives `ui=296`
with `START_SYMPIN` already gone). The stranded object is the 0262 orphan and both gates
early-return on it by design (D10). G9 was split into **G9a** (merge then placement — only
`leave_placement_for()` can clear the live one) and **G9b** (placement then merge — only
`leave_merge_for()` can), which is strictly stronger: the sabotage matrix below shows each variant
reddens exactly one of them.

## 5. Tests

`tests/headless/test_placement_preview_doors.tcl`, 115 → **177** checks, no row removed:

* **B14** `netlist` and **B15** `netlist -nohier` through the existing `door_case` helper.
* **Section G**, new — the emitted **deck** is the oracle, because a state-only suite cannot see
  0263's headline damage: G0 control deck, G1/G1b armed hierarchical, G2/G2b armed `-nohier`,
  G3 tedax (backend independence), G4 state after netlist before any ESC, G5 state after ESC,
  G6 the teardown names itself (`Netlist: pending placement abandoned`, held), G7/G7b the modify
  contract on a clean and on a dirty buffer, G8/G8b the merge twin, G9a/G9b the two co-armed
  orders, G10 total silence when idle.
* Section F's `netlist` residue bullet and its `note:` line are **deleted** — 0263 is no longer
  residue. The `unselect_all` bullet stays: 0262 is still open.
* No new file, and **no edit** to `tests/headless/run.sh`, `cases.txt` or `gold/*.spice` — those
  staying byte-identical is itself the regression check for the idle path.

Tier table after (baseline → after): shape_draw_gate 421→421, paste_modify_flag_0244 376→376,
add_wire_label 178→178, placement_wire_gate 171→171, label_ride 157→157,
placement_preview_doors **115→177**, label_strand_oracle 32→32, sch_add_pin 21→21,
wire_split / crossview_paste / instance_update OVERALL: ok, wireedit ALL PASS,
`tests/headless/run.sh` 6 goldens PASS, `run_regression.tcl` exactly the 3 documented known-red
FAIL lines. No regression.

## 6. Sabotage matrix

Each variant is a scoped neutralisation, rebuilt, suite re-run, then the tree restored and the
suite re-run green.

| variant | how | predicted | observed |
|---|---|---|---|
| **S1** placement gate off | `#define leave_placement_for(w) 1` scoped to the `netlist` branch only | 11 rows | **19 checks red** — B14 ×2, G1 ×2, G1b, G2 ×2, G2b, G3 ×2, G4 ×2, G5 ×2, G6 ×2, G9a ×3. Deck reverts to `R1 FOO GND 1k` / `R2 FOO GND 2k`. G9b stays green. |
| **S2** merge gate off | `#define leave_merge_for(w) 1`, same bounds | G8/G8b/G9 | **7 checks red** — G8 ×2, G8b ×2 (`R1 BAR GND 1k`), G9b ×3. G9a fully green ⇒ the merge rows are independent of the placement teardown. |
| **S3** hier-only gate | both calls wrapped in `if(hier_netlist){…}` | B15 ×5 + G2 + G2b | **3 checks red** — G2 ×2, G2b. The `-nohier` arm is carried by exactly those three. |
| **S4** teardown deletes nothing | `#define select_placement_preview() 0` scoped to `abort_placement_preview()` | G1…G5, G9, B14 ×2, B15 ×2 | all of them **plus** wide collateral: 48/177 in doors, 9/171 in placement_wire_gate, 27/178 in add_wire_label. The only variant that reddens B15. |
| **S5** gate after emit | both calls moved below the backend dispatch | G1…G6, B14 ×5 | **26 checks red** — every predicted one except B14's 3 state rows, **plus** unpredicted G8 ×2, G8b ×2, G9a ×3, G9b ×3. |

### Predicted reds that did NOT appear — and what that says

* **B14 "sympin_preview cleared"** and **B14 "invariant holds"** stayed green under S1 and S5.
  The driver's own `unselect_all(1)` + `pop_undo`/`clear_drawing()` zeroes `sympin_preview`
  whether or not the gate ran, so **those rows are satisfied BY the bug** and cannot detect an
  absent netlist gate. They are state pins, not 0263 detectors.
* **B14 "the real edit survived"** stayed green: neither arm ever touches the wire.
* **B15, all five checks**, stayed green under both S1 and S3. The `-nohier` arm never destroyed
  the gesture pre-fix, so ESC still reclaimed the preview and every state row passed with the gate
  entirely absent. **B15 has zero discriminating power for gate presence**; only G2/G2b cover that
  arm. The prediction was wrong, not the test — B15 is a pure no-regression pin and its in-file
  comment says so.
* **G9a "deck: no FOO"** (under S1) and **G9b "deck: no BAR"** (under S2) stayed green, and both are
  **hollow**: the 0262-stranded *other* object wins the net-naming race, so the deck reads
  `R1 BAR GND 1k` (resp. `R1 FOO GND 1k`) identically with and without the gate. Only G9's
  instance/lab_pin counts discriminate. Recorded rather than deleted, because the `note:` lines
  beside them are the 0262 residue's only in-suite record.

## 7. Still open

Residues of this fix, and everything the adversary pass could not close. Nothing here was fixed.

1. **THE RATIFICATION QUESTION (D2).** Should a READ verb end a live gesture at all? The item is
   status **E** on this alone.
2. **The 0262 orphan path still produces exactly this issue's damage.** Measured post-fix:
   arm, then a bare `xschem unselect_all` (which strips the bit without tearing down — the C
   tripwire fires), then `xschem netlist` → `R1 line = R1 FOO GND 1k`, `inst=3`. The object is by
   then an ordinary committed instance with no gesture bit and no stamp, so both gates early-return
   on it by design. Reachable from ordinary GUI flows (`property_form.tcl`'s post-edit
   `unselect_all`, the "Compare schematics" menu item, the Ctrl+MMB pin-type fallback). The suite
   records it only as a `note:` line. **Fixing this is issue 0262's job.**
3. **`readonly` toggled ON mid-gesture leaves the complete original defect.** Measured post-fix:
   `armed: ui=16424 inst=3` → `xschem set readonly 1` → `xschem netlist` →
   `R1 line = R1 FOO GND 1k  ui=0 inst=3`. `leave_placement_for()` early-returns on
   `xctx->readonly` because the teardown IS a `delete()`. Mitigated only because a placement
   **cannot be armed** while readonly (measured: `xschem add_wire_label: schematic is read-only …`,
   `inst` unchanged), so it needs a mid-gesture toggle. Untested and untripwired.
4. **The shipped comment's justification for omitting the draw gates is false as written** — with a
   selection alive, `xschem netlist` silently kills a live `STARTWIRE`/`STARTRECT`. Filed as issue
   **0359**. No object or deck damage, so D3's *conclusion* stands; its *reason* does not.
5. **`xschem undo` after a netlist-abandoned placement resurrects the preview as a committed
   instance.** Shared with the ESC path (control measured identical), so pre-existing — but a READ
   verb now plants that undo slot. Filed as issue **0361**.
6. **The Shift-N gate (D7) has no automated check** even though it demonstrably works under
   `GUI_GATE=0 xvfb-run`. Its correctness depends entirely on staying **above** `unselect_all(1)`;
   a reorder silently reopens the door. It also consumes the gesture even when `set_netlist_dir()`
   later fails, which contradicts D4's own siting rule at the scheduler verb.
7. **`save` / `saveas` / `write_backup` retain the identical blindness** — issue **0358**.
8. **The `-keep_symbols` cellview call sites** (`xschem.tcl`) are inside the gate by D5, so opening
   the cellview browser with a placement live now abandons it. Intended, user-visible, untested
   from the Tcl side.
9. **The CLI `-n` batch is ungated on an ordering argument alone** (D6). The ordering was
   confirmed by reading `xinit.c`, but nothing tests it, so a future reorder reopens a third door
   invisibly.
10. **The suite's `orphans` helper is blind to merged lab_pins** (they report the path form
    `devices/lab_pin`). Only G9 uses the new `labpins` glob helper. Filed as issue **0360**.
11. **Evidence hazard, for the record.** A concurrent agent rebuilt `src/xschem` at least four
    times during this item, twice with sabotage applied. Every number in this write-up was
    re-measured against one pinned artifact, `md5 e2261cb0b9f1ba90552ca1b09e554ef5`, with the
    checksum asserted before and after each run.
