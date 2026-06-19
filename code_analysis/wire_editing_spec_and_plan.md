# Wire editing on move — issue spec, feature requirements, atomic tests, RED-first plan

**Status:** specification + work plan. **No code changed.** This document decomposes
the "grab a component, move it, wires should follow like Cadence" problem into the
smallest testable pieces. It supersedes the *priority-order* sketch in
`wire_follow_stretch_move.md` §6 by making each item RED-first and atomic.

**Companion docs**
- `wire_follow_stretch_move.md` — the deep dive on *how* `select_attached_nets()` /
  `place_moved_wire()` / `recompute_orthogonal_manhattanline()` work today, with code
  line references. Read it for the mechanism; read this for the work breakdown.
- `FAQ.md` Q14 — verb-noun vs noun-verb (a separate interaction-grammar gap).

> **Scope note.** "Wire-follow on move" is governed by two TCL switches, **both off
> by default**: `enable_stretch` (does an attached wire follow at all?) and
> `orthogonal_wiring` (does it stay Manhattan?). `src/cadence_style_rc` turns both
> on. Everything below assumes both on unless a test says otherwise — the remaining
> gaps are *code*, not configuration.

---

## Part I — Issues encountered (problem spec)

Each issue: **symptom** (what the user sees) · **repro** · **root cause** · **status**.
All were observed/confirmed during the 2026-06-17/18 investigation, several with
headless reproductions and with user-supplied before/after schematics
(`mos_power_ampli_{bad1,bad2,desired0,desired1,desired2}.sch`).

### A — Wire-follow is off by default and the two switches are non-obvious
- **Symptom:** out of the box, dragging a component leaves all wires behind. Users
  don't discover `enable_stretch` / `orthogonal_wiring` (two buried Option-menu
  checkbuttons).
- **Root cause:** `set_ne enable_stretch 0`, `set_ne orthogonal_wiring 0`
  (`xschem.tcl`). Two independent switches that *both* must be on; "wire didn't
  follow" vs "wire followed but looks ugly" are different switches.
- **Status:** configuration/discoverability. Changing defaults is a behavior change
  → needs user sign-off (Part IV Phase 8).

### B — Dropped wire: sub-grid endpoint mismatch
- **Symptom:** with stretch on, a wire that *looks* connected to a pin is left behind
  on a move.
- **Repro (headless, confirmed):** wire endpoint at `(0,31)`, pin at `(0,30)`; move
  the device — the wire does not follow.
- **Root cause:** `select_attached_nets()` (`select.c:1317`) matches pin↔endpoint with
  **exact floating-point `==`**. An endpoint snapped *near* a pin (sub-grid jitter,
  fractional pin coordinate) fails the test.
- **Status:** real latent bug. Narrow in clean grid-aligned designs (endpoints sit
  exactly on pins there), so not the cause of the R18 report — but worth fixing.

### C — Dropped wire: T-junction / mid-span connection
- **Symptom:** a wire that runs *through* a pin (the pin taps a rail mid-span) is left
  behind on a move.
- **Repro (headless, confirmed):** horizontal wire `(-60,30)-(60,30)`, device pin at
  `(0,30)` (mid-span); move the device — the wire does not follow.
- **Root cause:** same `==` test; neither endpoint equals the pin, so no match.
  `connect_by_kissing()` (`actions.c:1163`) *does* handle this via point-on-segment
  (`touch()`), but on the intuitive drag path it only runs on **Shift+drag**
  (`callback.c:5251`); plain drag uses `select_attached_nets()`.
- **Status:** real bug; the more likely real-world "left behind" cause than B.

### D — Bad orthogonal routing when wires *do* follow (the main complaint)
The R18 wires actually *do* follow (exact endpoints); they route badly. Four sub-issues:

- **D1 — Frozen corner + spurious stub.** Dragging a pin perpendicular to its
  attached wire freezes the existing bend and inserts a **new** corner at the *old*
  pin position, leaving a dangling stub. (User's `bad2`.)
- **D2 — Per-wire, context-blind jog.** `place_moved_wire()` →
  `recompute_orthogonal_manhattanline()` is the *entire* routing intelligence:
  "longer leg first," one wire at a time. It never slides a connected corner, has no
  awareness of the symbol body / other wires, and can jog straight across the device.
- **D3 — No release-time cleanup.** Repeated drags accumulate cruft: literal
  **duplicate** wires (seen in `bad2`), **overlapping** colinear segments, **dangling**
  stubs, redundant vertices. `trim_wires()` exists but (a) is gated by `autotrim_wires`
  (default off), and (b) empirically removes only duplicates/overlaps — it cannot
  relocate a mis-placed corner (verified by running it on `bad1`/`bad2`).
- **D4 — Doesn't preserve route intent / angle.** The user wants the wire to "jut out
  at the correct angle and keep that angle as much as possible" — i.e. slide the
  existing shape rather than re-route from scratch.
- **Status:** the core of the complaint. D1/D2/D4 ⇒ "corner-slide" rubber-banding;
  D3 ⇒ cleanup. Confirmed: a corner-slide pass reproduces `desired2` exactly; cleanup
  alone reproduces nothing (it's a no-op on these inputs).

### E — The "dream": preserve a short stub out of every pin
- **Symptom/desire:** `desired1` keeps a one-minor-grid stub jutting straight out of
  each pin in its natural exit direction, *then* routes orthogonally. The most uniform,
  predictable rule.
- **Status:** new behavior; biggest change; effectively a tiny rubber-band router.

### F — Routing aesthetics are context-dependent
- **Observation:** the user's own goldens use *different* corner strategies for the
  two moves — `desired0` (horizontal move) relocates the riser to the rail's end and
  merges rails; `desired2` (vertical move) just slides the corner. So "good routing"
  is partly a judgement call, not one rule. A corner-slide nails `desired2`; `desired0`
  needs corner-slide **+** cleanup **+** a relocation heuristic.
- **Status:** informs why E is "the dream" (uniform) and why `desired0` is harder.

### Cross-cutting correctness risks (must never regress)
- **G1 — No accidental shorts.** Rubber-banding must never merge two electrically
  distinct nets.
- **G2 — Undo fidelity.** A stretch-move + undo must restore the *exact* prior geometry
  (including rubber-banded wires).
- **G3 — Connections to *fixed* parts preserved.** Sliding a corner must not drag a
  wire off a non-moving instance pin (must jog/stretch to keep both ends connected).
- **G4 — Scripted == interactive.** `xschem move_objects … stretch` must produce the
  same result as the interactive drag's release (confirmed true today: the END routing
  is shared).

---

## Part II — What a high-quality schematic editor SHOULD do (requirements)

Requirements for the move/wire-edit domain, phrased as testable behaviors. Each maps
to atomic tests in Part III. Priority: **M** must-have, **S** should-have, **C** could-have.

**Connectivity-preserving move (rubber-band)**
- R1 (M) Moving a component keeps every attached wire electrically connected.
- R2 (M) A wire whose endpoint sits **exactly** on a moved pin follows.
- R3 (S) A wire whose endpoint sits **near** a moved pin (sub-grid) follows. *(Issue B)*
- R4 (S) A wire passing **through** a moved pin (T-junction) follows. *(Issue C)*
- R5 (M) Moving **multiple** selected components rubber-bands all attached nets; a wire
  with **both** ends on moving pins translates rigidly (no jog).

**Orthogonal rubber-band quality**
- R6 (M) Followed wires stay Manhattan (axis-aligned), never diagonal.
- R7 (S) A connected **corner slides** with the pin; the route shape is preserved
  rather than re-jogged. *(Issues D1/D2/D4)*
- R8 (S) No **spurious stub** left at the old pin position. *(Issue D1)*
- R9 (C) Routing avoids laying a segment across the symbol body / other nets. *(D2)*

**Release-time cleanup**
- R10 (S) Colinear degree-2 segments are **merged**. *(Issue D3)*
- R11 (S) **Zero-length** and **exact-duplicate/overlapping** segments are removed. *(D3)*
- R12 (S) Stubs **orphaned by the move** (dangling, on no pin) are removed. *(D3)*
- R13 (C) A one-grid **exit stub** is preserved at each pin. *(Issue E)*

**Switches & discoverability**
- R14 (M) The stretch toggle actually gates following (off ⇒ wires don't follow).
- R15 (C) Stretch+orthogonal are discoverable / sensibly defaulted. *(Issue A; sign-off)*

**Correctness invariants (never violate)**
- R16 (M) Never merge two distinct nets (no accidental short). *(G1)*
- R17 (M) Undo restores exact prior geometry. *(G2)*
- R18 (M) Never drag a wire off a fixed (non-moving) pin. *(G3)*
- R19 (M) Bus wires rubber-band identically to plain wires; labels survive. 
- R20 (M) Scripted move == interactive move. *(G4)*

*(Broader editor UX — drag-to-connect, autoroute, gravity/snap, hover highlight,
selection filters — is out of scope here; this doc is the wire-on-move slice.)*

---

## Part III — Atomic test-case schematics

**Principles.** One behavior per fixture. Build **in memory** (no committed 132 KB
`.sch`) using `xschem instance` / `xschem wire`, move, save to a temp file, parse the
`N x1 y1 x2 y2` records, assert as an **endpoint-order-independent set**. Building
block: `res.sym` (a 2-pin device) placed at `(X,Y)`: pin **P** = `(X, Y−30)`, pin
**M** = `(X, Y+30)` (centred pins; `flip` doesn't move them in x). Snap grid = 10.

Each test is a self-contained smoke (`DISPLAY=:0 src/xschem --pipe -q --nolog
--script test_wireedit_<id>.tcl`) printing `RESULT: ALL PASS` / `RESULT: n FAILED`
and exiting nonzero on failure (matches the existing `tests/headless` convention).
Set `enable_stretch`/`orthogonal_wiring` per test at the top of the script.

Legend for diagrams: `o` pin, `●` wire endpoint, `─ │` wire, `→` move direction.

| ID | Name | Pins requirement | Issue |
|----|------|------|-------|
| TC1 | stretch toggle OFF | R14 | A |
| TC2 | parallel stretch (control) | R2,R6 | — |
| TC3 | perpendicular lone wire | R1,R6 | D |
| TC4 | sub-grid endpoint follows | R3 | B |
| TC5 | T-junction follows | R4 | C |
| TC6 | corner-slide | R7,R8 | D1/D2 |
| TC7 | colinear merge | R10 | D3 |
| TC8 | duplicate/overlap removal | R11 | D3 |
| TC9 | move-orphaned stub removal | R12 | D3 |
| TC10 | exit-stub preserved | R13 | E |
| TC11 | two nets, no short | R16 | G1 |
| TC12 | bus rubber-band | R19 | — |
| TC13 | multi-component rigid move | R5 | — |
| TC14 | undo restores geometry | R17 | G2 |
| TC15 | far end on fixed pin | R18 | G3 |

### TC1 — stretch toggle OFF
`enable_stretch 0`. Device at `(0,0)`, wire `(0,30)-(0,130)` on pin M. Move device by
`(40,0)`. **Expect:** wire **unchanged** (does not follow); device moved.

### TC2 — parallel stretch (control, must already pass)
`enable_stretch 1, orthogonal_wiring 1`. Wire `(0,30)-(0,130)` on pin M (vertical).
Move `(0,40)` (along the wire). **Expect:** wire `(0,70)-(0,130)` (stretched, 1 wire,
no new segment).
```
o(0,30)●          o(0,70)
 │        →(0,+40)   │
 ●(0,130)            ●(0,130)
```

### TC3 — perpendicular lone wire
Wire `(0,30)-(0,130)` on pin M; far end `(0,130)` free. Move `(40,0)` (⊥ to wire).
**Expect (define):** connection kept via an L — far end fixed, a jog appears; exactly
2 segments, both Manhattan, one touching the new pin `(40,30)`, one touching `(0,130)`.

### TC4 — sub-grid endpoint follows *(Issue B — RED today)*
Wire `(0,31)-(0,131)` (endpoint 1 unit off pin M `(0,30)`). Move `(0,40)`. **Expect:**
the near endpoint follows to `(0,71)` (wire `(0,71)-(0,131)`); nothing left at `(0,31)`.

### TC5 — T-junction follows *(Issue C — RED today)*
Horizontal wire `(-60,30)-(60,30)` through pin M `(0,30)`. Move `(0,40)`. **Expect:**
connection preserved — simplest acceptable: a new vertical stub `(0,30)-(0,70)` is
added joining the old tap point to the new pin (kissing-style), OR the wire bends to
follow. Pin its exact expected geometry when the approach is chosen (Phase 3).

### TC6 — corner-slide *(Issues D1/D2 — RED today; proven reachable)*
Distilled from `desired0→desired2`. Device at `(1360,-930)` (pin M `(1360,-900)`).
Wires: stub `(1270,-900)-(1360,-900)`, riser `(1270,-900)-(1270,-680)`, rail
`(1110,-680)-(1270,-680)`. Move `(0,30)` (⊥ to stub).
**Expect:** stub `(1270,-870)-(1360,-870)`, riser `(1270,-870)-(1270,-680)`, rail
unchanged. No segment at old y=−900; **same wire count** (no spurious stub).
```
   ●─────o (stub)          ●─────o    ← stub + corner slide UP
   │ corner                │
   │ (riser)        →(0,30)│
   ●──── rail              ●──── rail (unchanged)
```

### TC7 — colinear merge *(R10)*
Two colinear free wires `(0,0)-(100,0)` and `(100,0)-(200,0)` meeting at a **degree-2**
free point `(100,0)` (nothing else there). After an operation that should tidy:
**Expect:** one wire `(0,0)-(200,0)`.

### TC8 — duplicate/overlap removal *(R11)*
Wires `(0,0)-(100,0)` and `(0,0)-(60,0)` (the second included in the first). **Expect:**
the included/duplicate is removed; `(0,0)-(100,0)` remains (one copy).

### TC9 — move-orphaned stub removal *(R12)*
Construct the exact `bad2`-style residue: after a corner-slide-less move, a stub
`(1360,-900)-(1360,-870)` hangs with `(1360,-900)` connected to nothing. **Expect:**
removed (degree-1, on no pin, produced by the move).

### TC10 — exit-stub preserved *(Issue E)*
TC6 geometry. Move `(0,30)`. **Expect (`desired1` rule):** a one-grid stub straight out
of pin M `(1360,-870)-(1360,-850)` (or the chosen stub length), then the orthogonal
route; assert the stub exists and is collinear with the pin's exit direction.

### TC11 — two nets, no short *(R16 — guard)*
Net A: device1 pin M `(0,30)`, wire `(0,30)-(0,130)`. Net B: a separate wire
`(20,30)-(20,130)` (20 units away, distinct net). Move device1 by `(20,0)` so its pin
lands at `(20,30)`. **Expect:** A follows; A and B remain **distinct** (assert via
`prepare_netlist_structs(0)` + node query that the two nets did not merge). Tightens
the sub-grid tolerance (B) against over-grabbing.

### TC12 — bus rubber-band *(R19)*
Wire `(0,30)-(0,130) {lab=A[3:0]}` on pin M (bus). Move `(0,40)`. **Expect:** same as
TC2 with `lab=A[3:0]` preserved.

### TC13 — multi-component rigid move *(R5)*
device1 at `(0,0)` (M `(0,30)`), device2 at `(0,200)` (P `(0,170)`), wire
`(0,30)-(0,170)` joining them. Select **both** + the wire; move `(40,0)`. **Expect:**
wire translates rigidly to `(40,30)-(40,170)` (both ends moved, no jog, 1 segment).

### TC14 — undo restores geometry *(R17 — guard)*
TC6 geometry. Record all wire records. Stretch-move `(0,30)`. `xschem undo`. **Expect:**
wire set **identical** to the recorded original (set-equality).

### TC15 — far end on fixed pin *(R18 — guard)*
device1 (moving) pin M `(0,30)`, device2 (**fixed**) pin at `(0,130)`, wire
`(0,30)-(0,130)` between them (⊥ to an x-move). Move device1 by `(40,0)`. **Expect:**
the wire keeps **both** connections — it must NOT translate off device2's pin; a jog
appears so `(0,130)` stays on device2 and the moved end reaches `(40,30)`.

---

## Part IV — RED-first work plan (atomic steps)

**Method.** Every step: (1) write/extend the RED test asserting the *desired* behavior
and run it → confirm it FAILS for the right reason; (2) make the smallest change to go
GREEN; (3) run the **regression guard set** (below) + golden harness; (4) commit. No
step bundles two behaviors. Stash-verify each "already-green" claim (a green test that
never executed the new code is hollow).

**Regression guard set** (must stay GREEN after every step): TC1, TC2, TC11, TC13,
TC14, the existing `tests/headless/run.sh` golden netlist harness, and the
`tests/stable_handles` suites (they exercise `move_objects`). Default behavior
(`orthogonal_wiring`/`enable_stretch` off) must be untouched — assert by keeping the
golden harness (which sets neither) green.

### Phase 0 — Test scaffold *(no product code)* — ✅ DONE
- **0.1** ✅ `tests/headless/wireedit/fixtures.tcl`: `we_reset`/`we_device`/`we_wire`/
  `we_label`, `segset`+`we_norm`+`has_seg` (endpoint-order-independent), `we_net`/
  `nets_distinct`/`netcount`, `we_move`/`we_move_stretch`. Self-test
  `test_wireedit_00_selftest.tcl` (11 checks) GREEN.
- **0.2** ✅ `run_wireedit.sh` aggregates every `test_wireedit_*.tcl` `RESULT:` line,
  exits nonzero on any FAIL / no-result; finds + runs the self-test.
- **Established facts (so they aren't re-derived):**
  - **`xschem wire_coord <n>` had an off-by-one** (`n > 0` → index 0 unqueryable);
    fixed to `n >= 0` (scheduler.c). Real bug; `wire_id` already used `>= 0`. The
    stable_handles suite documented it as a "pad wire at index 0" workaround — still
    GREEN (58 checks) after the fix; nothing asserted index 0 was empty.
  - **Net identity:** `we_net` = `xschem resolved_net` (to run
    `prepare_netlist_structs(0)` and refresh the cache) **then** `getprop wire <n>
    lab` for the bare token. Do **not** use `resolved_net`'s return for identity — it
    adds an inconsistent hierarchy prefix (`0NETA` vs `NETA`) and has the
    stale-sel_array defect. Use explicit `lab_pin` labels for unambiguous nets.
  - **Run from REPO ROOT** under X: `DISPLAY=:0 src/xschem --pipe -q --nolog --script
    tests/headless/wireedit/<t>.tcl` (fixture paths are CWD-relative).

### Phase 1 — Baseline characterization *(tests only; no product code)*
Write TC1–TC15 asserting **desired** behavior; run against current binary; record the
RED/GREEN map. Expected today: TC2, TC13, TC14 GREEN (or close); TC4, TC5, TC6, TC10
RED; TC1/TC11/TC15 establish guards. One atomic commit per test file. *Output: the
authoritative work-list — only proceed on confirmed-RED items.*

### Phase 2 — Sub-grid tolerant match *(Issue B → R3; TC4)*  — smallest, contained
- **2.1** RED: TC4 fails (exact `==` drops `(0,31)`).
- **2.2** Implement: in `select_attached_nets()` replace the four `==` endpoint tests
  with a tolerant compare (`|Δ|≤ tol`, `tol = cadsnap/2`, floor to near-exact if snap
  ≤0). Contained to `select.c`.
- **2.3** GREEN: TC4. **Guard:** TC11 (tolerance must not merge the 20-apart net) +
  golden harness (clean designs unaffected: exact endpoints ⇒ tolerant ≡ `==`).

### Phase 3 — T-junction follow *(Issue C → R4; TC5)*
- **3.1** RED: TC5 fails (mid-span wire not selected).
- **3.2** Decide approach (open the choice in the test's expected geometry first):
  (a) add a point-on-segment (`touch()`) branch to `select_attached_nets()` that adds
  a kissing-style stub at the pin; or (b) route the plain-drag path through the
  existing `connect_by_kissing()`. Prefer reusing (b) if it yields the desired
  geometry.
- **3.3** GREEN: TC5. **Guard:** TC2/TC11 + golden harness.

### Phase 4 — Corner-slide rubber-band *(Issues D1/D2/D4 → R7/R8; TC6, guard TC15)*
- **4.1** RED: TC6 fails (frozen corner + spurious stub; wire count grows).
- **4.2** RED: TC15 fails *(or* is at-risk*)* — assert the fixed-pin connection is kept.
- **4.3** Implement `compute_wire_slide(dx,dy)` at `move_objects(END)`, **guarded** to
  orthogonal + axis-aligned (`(dx!=0) xor (dy!=0)`) + non-rotating moves only. Fixpoint
  of R1 (perpendicular wire translates unless its far end is a **fixed pin** → then
  jog) and R2 (a moving endpoint drags coincident endpoints). Resolved wires
  translate/stretch directly (no jog, no new segment); select propagated neighbours so
  the move loop visits them. Diagonal/rotating moves keep the legacy jog path.
- **4.4** GREEN: TC6 (reproduces `desired2`) **and** TC15 (fixed pin kept).
  **Guard:** TC1/TC2/TC11/TC13/TC14 + golden + stable_handles. *Known residue:*
  horizontal moves may leave one overlapping rail segment — handed to Phase 5.

### Phase 5 — Release-time cleanup *(Issue D3 → R10/R11/R12; TC7, TC8, TC9)*
- **5.1** RED+GREEN: TC8 (duplicate/overlap) — ensure `trim_wires()`'s include-removal
  runs on the stretch path (call it post-move for stretch moves regardless of
  `autotrim_wires`, **or** add a dedicated post-slide dedup). Smallest first.
- **5.2** RED+GREEN: TC7 (colinear degree-2 merge) — via the same `trim_wires()` merge.
- **5.3** RED+GREEN: TC9 (move-orphaned dangling stub) — add a **move-scoped** removal:
  only delete a degree-1 wire that (i) was selected/created by this move and (ii) has
  an end on no pin and no other wire. Carefully scoped so intentional dangling wires
  elsewhere are untouched. **Guard:** TC11/TC14 (undo must still restore) + golden.
- **5.4** Re-run TC6's horizontal sibling: confirm the Phase-4 overlap is now merged.

### Phase 6 — Exit-stub preservation *(Issue E → R13; TC10)*
- **6.1** RED: TC10 fails (no stub out of pin).
- **6.2** Implement: after slide/route, ensure a one-minor-grid segment leaves each
  moved pin along its exit direction before the first bend. Choose stub length =
  symbol pin spacing / minor grid (document the constant).
- **6.3** GREEN: TC10. **Guard:** TC6 still GREEN (stub is additive, route otherwise
  unchanged) + full guard set. *This is the biggest behavior change — keep behind a
  switch (e.g. `wire_exit_stub`) if it alters too many goldens.*

### Phase 7 — `desired0` aesthetic *(Issue F → R9; optional)*
Corner-slide + cleanup get `desired2`; `desired0` additionally relocates the riser to
the rail's end. Only attempt with a dedicated golden test and after Phases 4–5. Treat
as a heuristic refinement, not a correctness fix.

### Phase 8 — Defaults / discoverability *(Issue A/G → R15; needs sign-off)*
Not code-first. Options to present: default `enable_stretch`/`orthogonal_wiring` on for
instance drag; or surface them more prominently; or a one-key toggle with on-canvas
feedback. **User decision** — changes long-standing behavior; do not flip silently.

### Dependency / ordering summary
```
Phase 0 (scaffold) ─► Phase 1 (baseline) ─► Phase 2 (sub-grid, isolated)
                                          ├► Phase 3 (T-junction, isolated)
                                          └► Phase 4 (corner-slide) ─► Phase 5 (cleanup) ─► Phase 6 (exit stub)
                                                                                          └► Phase 7 (desired0 aesthetic)
Phase 8 (defaults) — independent, gated on user sign-off.
```
Phases 2 and 3 are independent and contained to `select.c`/the selection path. Phase 4
is the high-value core (`move.c`). Phase 5 depends on 4 (cleans its residue). Phase 6
depends on 4/5. Each phase is shippable on its own.

---

## Appendix — facts established this investigation (so they aren't re-derived)
- `move_objects … stretch` (scripted) reproduces the interactive drag's release output
  **byte-identical** (e.g. `bad1`) — so headless tests faithfully cover the GUI gesture.
- Corner-slide reproduces `desired2` **exactly** (8/8 OUTI segments).
- `trim_wires()` run on `bad1` = **no change**; on `bad2` = removes one duplicate only.
  ⇒ cleanup alone cannot fix the routing; corner-slide is required.
- R18's attached wires use **exact** endpoints ⇒ Issue B (sub-grid) is *not* the R18
  cause; Issue D (routing) is.
- `connect_by_kissing()` already does tolerant + mid-span follow, but only on
  **Shift+drag** — relevant to Phase 3.
- Default `orthogonal_wiring`/`enable_stretch` = 0; the golden harness sets neither, so
  it is a faithful "default behavior unchanged" guard for every phase.
