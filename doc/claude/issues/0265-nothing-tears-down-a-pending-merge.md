# 0265 — nothing tears down a pending paste/merge: a second `Ctrl+V` (or any placement arm) silently COMMITS the first one

Status: **FIXED 2026-08-08** on `open_pdk` — `abort_pending_merge()` + `leave_merge_for()`
(`src/callback.c`), called from the merge funnel and all twenty-three arms; **247 new checks** in
`tests/headless/test_paste_modify_flag_0244.tcl` section **E** (129 → 376), five sabotage runs with
disjoint red sets (27 / 56 / 9 / 2 / 1) and a sixth that produced no red at all, reported as such.
Issue **0267** closed with it. See **THE FIX** at the bottom.
Found by the code census run for issue **0244** part B, then **measured** on both
doors (below). **Major**: the residue is a committed, netlist-visible set of objects the user never
dropped — the issue-**0242** orphan class, in the dimension `leave_placement_for()` does not cover.
Area: `src/paste.c` (`merge_file()`'s own `unselect_all(1)`), `src/select.c` (`unselect_all()`'s
wholesale `ui_state = 0`), vs `leave_placement_for()` / `abort_placement_preview()` in
`src/callback.c`
Tests: **section E of `tests/headless/test_paste_modify_flag_0244.tcl`** (247 checks). Was: none —
that file covered the ESC and commit doors of a *single* pending merge; the second-arm door was
untested.
Found: 2026-08-08, closing issue **0244**.
Related: **0242** (the same class for placements — nine doors gated by `leave_placement_for()`),
**0244** (part B's stamp lives on the gesture this issue can drop), **0241**, **0123**,
`WIRING.md` §8 class **D**.

## The claim

`STARTMERGE` has exactly one setter (`merge_file()`, `src/paste.c`) and three teardown-bearing
clears: the commit tail (`move.c`), and `abort_operation()`'s two arms (`src/callback.c`). Every
**other** way the bit goes away is `unselect_all()`'s wholesale `xctx->ui_state = 0`, which fires
whenever anything is selected — and a pending merge is *always* selected, because that selection is
what the drag is carrying.

So:

- **`Ctrl+V` twice.** `merge_file()` itself calls `unselect_all(1)` before loading. If a merge is
  already pending in that window, that call drops `STARTMERGE` with **no** `delete()`, leaving the
  first paste's objects committed and deselected, and then arms `STARTMERGE` again for the second.
  `leave_placement_for()` — which `merge_file()` does call — only covers
  `START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT`; it never inspects `STARTMERGE`.
- **`Ctrl+V` then any placement arm that unselects** (the three form `-place` arms, `add_graph`,
  `add_image`, the `place_text` verb, both `place_symbol` routes): same wholesale drop, same
  committed residue.

The ratified rule since 0243 F2 / 0240 is *"whatever you just pressed is what you meant"* — the new
gesture cancels the pending one. For merges the second half of that ("cancels") is missing: the
pending paste is not cancelled, it is silently **accepted**.

## Measured, 2026-08-08, on the post-0244 binary

Both doors reproduce. `doc` = one wire, dirty; `src.sch` = one wire.

```
A  merge twice, then ESC
   before        wires=1 ui=0
   merge #1      wires=2 ui=296  (STARTMERGE|STARTMOVE|SELECTION)
   merge #2      wires=3 ui=296  <-- paste #1 still in the drawing, no longer pending
   after ESC     wires=2         <-- only paste #2 removed; paste #1 is COMMITTED

B  merge, then a placement arm, then ESC
   merge armed   wires=2 inst=0 ui=296
   place_symbol  wires=2 inst=1 ui=8232  <-- STARTMERGE gone, merged wire committed
   after ESC     wires=2 inst=0          <-- only the placement torn down; the paste stays
```

Both runs also print, from the fluid layer:

```
fluid_editing: fluid_gesture_arm() re-armed while a prior gesture was still armed -- it leaked its
snapshot (WIRING risk #11.10 mid-STARTMOVE abandon); recovering
```

i.e. the fluid machinery already *detects* this abandon and merely recovers from it. That message is
the cheapest available tripwire for a fix to silence.

## Why it is not 0244 part B's problem

Part B stamps the merged objects at the arm and narrows the cancel's `delete()` to that stamp. When
this issue's path fires, `STARTMERGE` is gone, so no arm reads the stamp and the next arm overwrites
it — the stamp is inert, not stale. Part B neither worsens nor fixes this.

## Sketch

A `leave_merge_for(const char *what)` sibling of `leave_placement_for()` — or extend the existing
one to `STARTMERGE` — called from the same funnel (`merge_file()`, before its `unselect_all`) and
from the placement arms. Its teardown is the merge arms' body: `select_placement_preview()` +
`delete(1)` + the `pre_merge_modified` restore + `clear_placement_preview()`, which is now a
three-line block worth factoring out of `abort_operation()` before a third caller copies it (the
duplication between the two arms is exactly how 0244 was born — see its root-cause section).

**Measure first**: build the two-paste sequence headlessly (`xschem merge f` twice, then count
objects and read `ui_state`) and confirm the residue before writing any gate.

---

# THE FIX (2026-08-08)

Landed on `open_pdk`. Anchors below were derived at `50fca19e` + this change; the line numbers in
the sections above are the pre-fix ones.

## The shape: two functions, not one

The session prompt asked for a single `leave_merge_for()` carrying the teardown inline. It is
**two**, mirroring the placement pair exactly, and the reason is behavioural rather than aesthetic:

- **`abort_pending_merge(void)`** — the teardown. Gated on `STARTMERGE`, drops the pending move,
  re-selects the 0244/0241 stamp, `delete(1)`, clears the stamp, clears the bit, restores the flag.
  This is the body `abort_operation()`'s two arms carried inline, once each, and **both arms are now
  one call to it**. That is the whole "do not copy it a third time" requirement: one body, five
  kinds of caller.
- **`leave_merge_for(const char *what)`** — the gate. `gate_bypass` seam, `STARTMERGE` test,
  `readonly` refusal, then `abort_pending_merge()` and a `statusmsg_hold("<what>: pending paste
  abandoned")`.

Had `abort_operation()` called the gate, **ESC would have started raising a statusbar hold** —
"Cancel: pending paste abandoned" for 5 s, suppressing the coordinate readout and (per issue 0248)
any ordinary `statusmsg()` behind it. ESC is not a competing gesture; there is no `what` to name.
`abort_operation()` calls `abort_placement_preview()` rather than `leave_placement_for()` one line
above for exactly this reason, and the merge side now matches.

## Where it is called: enumerated from the state, not from the verbs

0242's coverage lesson, applied: the arms were enumerated from **the state the teardown owns**, and
that state is "a modal gesture is being armed", whose ground truth is the set of arms that stamp a
preview or arm a draw — not the verbs this bug report happened to name.

**24 call sites**, in three groups:

| group | how enumerated | sites |
|---|---|---|
| the merge funnel | the ONE function that sets `STARTMERGE` | `merge_file()` (`paste.c`) — 1 |
| the placement arms | the twelve `stamp_placement_preview()` call sites (`grep -c 'stamp_placement_preview();'`: actions.c 1, callback.c 3, draw.c 1, scheduler.c 7 — the thirteenth is `merge_file()`'s own) | 12 |
| the draw arms | every site `leave_placement_for()` is called from that is **not** a placement arm: callback.c 6, scheduler.c 5 | 11 |

Cross-check: `leave_placement_for()` has 23 sites, `leave_merge_for()` 24. The difference is
**+3 −2**:

- **+3** the three modeless form `-place` arms (`add_symbol_pin`, `add_sch_pin`, `add_wire_label`)
  carry **no** `leave_placement_for()` — they handle a previous *placement* themselves with the
  undo-clean per-keystroke re-arm dance. That dance is scoped to `sympin_preview` and knows nothing
  about `STARTMERGE`, and all three then run `unselect_all(1)`. They were doors. A merge is a
  *different* gesture with its own undo baseline, not a re-issue of this one, so it must be torn
  down with its own `delete(1)`+`push_undo` rather than folded into the arm's single baseline —
  which is why the gate is the right tool here and the re-arm dance is not.
- **−2** the **undo/redo** verbs are deliberately **not** gated, unlike the placement side. A
  pending merge is fully covered by the undo stack (`merge_file()` pushes its baseline *before*
  loading), so `undo` already removes the paste correctly — measured, and pinned by test **E6b**.
  A `delete(1)`+`push_undo` run in front of the pop would make `undo` **restore** the paste instead.
  A placement preview has no such coverage, which is why 0242 needed the gate there.

Pure-commit forms remain ungated (plan landmine 2): `xschem wire x1 y1 x2 y2`, `xschem text …`,
`add_wire_label -drop`, the coordinate `xschem paste dx dy` replay form. Test **E6a** pins it.

## Ordering, and the shared `preview_sel` slot

Every arm that gates both runs `leave_placement_for()` **first**, then `leave_merge_for()` — the
same order `abort_operation()` has always used, and it is load-bearing for the same reason 0244
documented: the four placement arms that keep the user's selection stamp a **superset** of a
co-armed merge, so the placement teardown removes the paste along with the placement and the merge
teardown then correctly resolves 0. Running the merge teardown first would delete the merge subset
and orphan the placement's own objects.

With every arm now gated, co-arming is no longer reachable through a gated door — only through
`xschem test_gate_bypass 1`. Sabotage **S11** swapped the two calls in `merge_file()` and produced
**zero reds**, which is the honest measurement of that: the ordering is now a property nothing can
observe, kept because it is the reason the shared slot is safe at all.

## `paste_from`, a latent 0242 bug this fix would have widened

Both teardowns run `move_objects(ABORT)`, which zeroes `xctx->paste_from` — a field `merge_file()`
has *already* set for the merge it is about to arm. On the 0242 path this only bit a merge armed
over a live placement; 0265 would have made it fire on the common merge-over-merge path. Fixed here
rather than noted: `merge_file()` latches `paste_from` into a local and restores it after the
teardowns. `paste_from == 1` is read by callback.c's `SelectionClear` handler to abort a
cross-window selection-transfer receive whose sender dropped its selection.

There was **no** `xschem get paste_from` seam, so this was unassertable. One was added (`scheduler.c`,
beside `polygons`) — the alternative was a fix with no oracle, which is the 0246 residue class.
Test **E6d**; sabotage **S10** reddens it.

## Issue 0267 did NOT fall out on its own — and here is the honest reason

The prompt predicted 0267 would close as a byproduct, on the reasoning that a bounded merge lifetime
means the ESC that consumes `pre_merge_modified` always immediately follows its own arm. **That is
false for the surface 0267 actually measured.** 0267's repro edits with `xschem wire 2000 2000 2100
2000` and `xschem text …` — **pure-commit forms, which are ratified as never gated** (they are the
replay/test seams, plan landmine 2). Gating every *arming* gesture leaves them untouched, so a
pending paste can still outlive arbitrary real editing, and the latch is still stale at the ESC.
Re-measured after Part A landed and before anything else: `wires=3 texts=1 modified=0` — unchanged.

So 0267 needed its own mechanism, and it is the one its own "fix direction" section rejected as
fragile, in a form that is not: **`xctx->modify_seq`** (`xschem.h`), bumped by `set_modify()` on
every *declaration* of dirtiness (`mod` 1/3, not readonly-suppressed). `merge_file()` latches it
into `xctx->merge_modify_seq` after its own trailing `set_modify(1)`; `abort_pending_merge()` reads
the sequence before its own `delete()` dirties it and restores the flag only while the two still
match. It is strictly better than the undo-pointer belt the issue sketched, because it tracks
exactly the thing the flag tracks, and it needs no second latch of the flag itself.

Bumped on every declaration rather than on the 0→1 transition **on purpose**: after a paste the flag
is already 1, so a transition counter would see nothing — the exact case 0267 is about.

Measured after: both `abort_operation()` arms now answer `modified == 1` with the new wire and the
new text still present. Tests **E4 bare** / **E4 nested**; sabotage **S9** is the two-row detector.
**E4 control** is the guard against the obvious over-correction: the gesture's own machinery
(a `move_objects step`, a `select_all`) must not count as an edit, so a clean paste + ESC still comes
back clean.

## Measured, before → after

```
                                       pre-fix                    post-fix
A  merge, merge, ESC       wires 1 -> 2 -> 3 -> 2            1 -> 2 -> 2 -> 1
   (paste #1 COMMITTED by the second merge)                  (paste #1 ABANDONED)
B  merge, place_symbol     ui 296 -> 8232, merged wire kept  merged wire GONE at the arm
   then ESC                only the symbol torn down         fixture intact, inst=0
C  merge, `wire gui`       ui 297 = STARTWIRE|STARTMERGE|    ui 1: paste gone, draw armed
                           STARTMOVE|SELECTION (co-armed)
D  clean, merge, move_     wires 2 texts 1 modified=0        modified=1  (issue 0267)
   objects abort, +wire
   +text, ESC
```

The fluid layer's second oracle is silent where it should be. Pre-fix, sequences A and B each
printed `fluid_gesture_arm() re-armed while a prior gesture was still armed`; post-fix neither does.
Across the whole 376-check suite exactly **three** warnings remain, all explained: two from 0244's
**D8** rows, which deliberately arm a fluid stretch and then merge on top of it (a bare `STARTMOVE`
stretch is not a gesture any gate owns), and one from **E6e**, the row that turns the gate off.

## Tests

`tests/headless/test_paste_modify_flag_0244.tcl` **extended**, not duplicated — its fixture
(2 wires + 1 instance + 1 text + 1 line; a merged file with one of each; `primed_doc` / `rec0244` /
`labcount` / `textcount`) is exactly what these rows need. **129 → 376 checks**, still true-headless.

| row | what it pins |
|---|---|
| **E1** | a second merge abandons the first — both doors (`xschem merge <file>`, clipboard `xschem paste`); the load-bearing number is `wires == 3` after merge #2, not 4. Plus the clean-document flag row, which proves the teardown's restore feeds the *next* merge's latch. |
| **E1b** | three merges: the teardown is re-entrant, not a one-shot. |
| **E2** | every placement arm × 7 drivable verbs (`place_symbol`, `add_wire_label -place`, `add_sch_pin -place`, `add_symbol_pin -place`, `net_label 0`, `add_graph`, `place_text`) — paste gone, placement live, one ESC leaves the fixture whole. `place_text` is in the list although its dialog cannot open headlessly: the gate must fire on the ARM, so the paste is gone even when the placement that displaced it never materializes. |
| **E3** | the reverse (0242's direction), as a control — a fix that merely swapped which gesture wins cannot pass. |
| **E4** | issue 0267, on both `abort_operation()` arms, plus the "the guard is not a blanket refuse" control. |
| **E5** | part B / plan phase 4: `wire gui`, `line gui`, `snap_wire` each cancel a live merge. `snap_wire` arms `MENUSTART` (65536), not `STARTWIRE` — this run has `infix_interface 0`, and covering both interface branches is 0247's lesson. |
| **E6** | five controls: **a** a pure-commit form is NOT gated; **b** `undo` is NOT gated and still removes the paste; **c** a read-only window arms nothing; **d** `paste_from` survives the teardowns; **e** `test_gate_bypass` really disables the gate (without which a green section E could mean "the gate never runs"). |

Not hollow, by the same construction as sections A–D: `fixture0265` asserts both halves of every
row — the previous paste really went (`labcount MERGED`, `textcount MERGEDTEXT`, `wires`) **and** the
fixture really survived (`SURVIVOR` / `SURVIVORTEXT` / the saved-record count, which is the only
headless proof for the line). A gate that deleted everything and a gate that deleted nothing both
redden.

### Sabotage table

| # | sabotage | predicted | **measured** |
|---|---|---|---|
| S6 | `leave_merge_for()` removed from `merge_file()` | E1 red | **27 red**: E1 merge ×10, E1 paste ×10, E1b ×7. Nothing else moved. Fluid warnings 3 → **11**. |
| S7 | `leave_merge_for()` removed from all twelve placement arms | E2 red | **56 red**: 8 rows × the 7 drivable arms, exactly. Fluid warnings 3 → **9**. |
| S8 | `leave_merge_for()` removed from all eleven draw arms | E5 red | **9 red**: 3 rows × 3 arms. Fluid warnings **unchanged at 3** — a wire/line arm does not arm a fluid gesture, so the second oracle does not see this door at all. |
| S9 | `seq == merge_modify_seq` conjunct dropped (0244's exact pre-0267 condition) | E4 red | **2 red**, both `MODIFIED` rows — bare arm and nested arm. Every other row, including E4's clean control, stayed green. |
| S10 | the `paste_from` restore removed | E6d red | **1 red**: `paste over paste` (2 → 0). The `merge over paste` row stays green because a named-file merge's `paste_from` is 0 either way — stated because it is the row that shows *why* the clipboard row is the detector. |
| S11 | `leave_merge_for()` hoisted **above** `leave_placement_for()` in `merge_file()` | E3 red? | **no red at all.** Reported rather than papered over: with all 24 arms gated, a co-armed placement+merge is unreachable except through `test_gate_bypass`, so the ordering has no observable consequence today. It is kept because it is the property the shared `preview_sel` slot rests on, and a thirteenth arm added without a gate would make it observable again. |

The red sets are **disjoint from each other** (E1 / E2 / E5 / E4-flag / E6d — no check appears in two
of them) **and disjoint from 0244's** S1 (15 flag rows) / S2 (23 geometry rows) / S5 (5 D8 rows):
every red in S6–S10 names a `0265 E…` check and **zero** name a `0244 …` check, verified by grep on
each run's output.

**Harness note, because it produced a wrong number once.** The first S8 run reported 17 reds
including six `E2 net_label` rows. That was contamination, not signal: the sabotage driver backed up
and restored only `paste.c`/`callback.c`/`scheduler.c`, so S7's patch to `actions.c` and `draw.c`
survived into S8's tree. The driver now covers all five files and asserts `grep -rn SABOTAGE src/`
is empty after every restore; the clean baseline was re-verified (376/376) before S8 was re-run,
and the corrected number is 9. This is WIRING §10's "sabotage runs lie if `make` did not rebuild",
one step over: they also lie if the *restore* was partial.

## User-visible behaviour change

Pressing `Ctrl+V` twice, or starting any other placement or draw while a paste is riding the cursor,
now **abandons** the pending paste instead of silently dropping it into the schematic. Anyone who
relied on "paste, then click a menu, and it lands" will see a change. It is the ratified rule —
*whatever you just pressed is what you meant* — the same one 0240 / 0242 / 0243 applied everywhere
else, and the status bar says so (`<verb>: pending paste abandoned`, held for 5 s per issue 0248).
The paste is still recoverable: the teardown's `delete(1)` pushes undo.
