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
| TC16 | pin-to-pin abutment generates wire | R20 | H |

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

### TC16 — pin-to-pin abutment generates a wire *(Issue H → R20; RED on the drag path)*
device1 pin M `(0,30)`, device2 pin P `(0,30)` — the two pins are **directly
coincident** (abutted), connected with **no wire between them**. Select device1 only,
move it by `(40,0)`. **Expect:** a wire is **generated** to keep the pins connected —
`(0,30)-(40,30)` (device2's pin stays at `(0,30)`, the moved pin reaches `(40,30)`).
**Status:** the mechanism exists — `connect_by_kissing()` produces exactly this wire,
*verified* via the `kissing` move (`xschem move_objects 40 0 kissing` ⇒ one wire
`{0 30 40 30}`). But the **drag / stretch path does not call it**
(`xschem move_objects 40 0 stretch` ⇒ 0 wires, connection lost), and in
`cadence_compat` mode no click-drag gesture sets the kissing flag (the legacy
Shift+drag that did is now `copy`). So TC16 is RED on the drag path today, GREEN only
via the explicit `M` command / scripted `kissing`. Fix is Phase 3 (route the
plain/stretch drag through `connect_by_kissing()`).

> **Issue H (new) — pin-to-pin abutment dropped on drag.** Two abutted device pins
> (no wire) are a legitimate connection; `connect_by_kissing()` already regenerates a
> wire on move, but only the `M`-command/`kissing` path triggers it. The intuitive
> drag (and the new `cadence_compat` drag) use `select_attached_nets()`, which stretches
> existing wires only — so dragging an abutted instance silently disconnects it.

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

### Phase 1 — Baseline characterization *(tests only; no product code)* — ✅ DONE
TC1–TC15 written as `tests/headless/wireedit/test_wireedit_<NN>_*.tcl`, asserting
**desired** behavior, run against the current binary. **Authoritative RED/GREEN map
(2026-06-19):**

| TC | Behavior | Issue | Status | Phase to fix |
|----|----------|-------|--------|------|
| TC1 | stretch OFF → no follow | A | 🟢 GREEN (guard) | — |
| TC2 | parallel stretch | — | 🟢 GREEN (control) | — |
| TC3 | perpendicular lone wire L-jog | D | 🟢 **GREEN** | — (ortho already handles it) |
| TC4 | sub-grid endpoint follows | B | 🟢 **GREEN** (Phase 2 done) | 2 |
| TC5 | T-junction follows | C | 🟢 **GREEN** (Phase 3 done) | 3 |
| TC6 | corner-slide | D1/D2 | 🟢 **GREEN** (Phase 4 done) | 4 |
| TC7 | colinear merge | R10 | 🟢 **GREEN** (Phase 5 done) | 5 |
| TC8 | duplicate/overlap removal | R11 | 🟢 **GREEN** (Phase 5 done) | 5 |
| TC9 | move-orphaned stub removal | R12 | 🟢 **GREEN** (Phase 5 done) | 5 |
| TC10 | exit-stub preserved | E | 🟢 **GREEN** (Phase 6 done, switch ON) | 6 |
| TC11 | two nets, no over-grab | R16 | 🟢 GREEN (guard) | — |
| TC12 | bus rubber-band, lab kept | R19 | 🔴 **RED** | (new gap, see below) |
| TC13 | multi-component rigid move | R5 | 🟢 GREEN (guard) | — |
| TC14 | undo restores geometry | R17 | 🟢 GREEN (guard) | — |
| TC15 | far end on fixed pin | R18 | 🟢 GREEN (guard) | — |
| TC16 | pin-to-pin abutment generates wire | H/R20 | 🟢 **GREEN** (Phase 3 done) | 3 |

**Findings beyond the predicted map:**
- **TC3 is already GREEN** — with `orthogonal_wiring` on, a perpendicular move of a
  *lone* wire already produces a clean 2-segment Manhattan L-jog (far end fixed). The
  Issue-D defect is specifically the **corner-slide** (TC6, a *pre-existing* corner
  freezes), not the lone-wire case. Narrows Phase 4's scope.
- **TC15 (R18) is GREEN** at the guard level — the stretch move keeps *both* endpoints
  (far end stays on the fixed pin). The assertion is intentionally weak (endpoints
  present, not full 2-segment Manhattan); Phase 4 should tighten it.
- **TC12 RED is a real, newly-confirmed gap:** the stretch move **drops the wire's
  property** — a bus wire labeled `lab=A[3:0]` stretches geometrically to
  `(0,70)-(0,130)` but its prop becomes `{}` (verified via `saveas`:
  `N 0 70 0 130 {}`). This is prop-preservation on the move path, not wire-follow
  geometry; schedule as its own small fix (likely `move.c`), not in Phases 2–6.

*The 8 RED items are the work-list; `run_wireedit.sh` stays non-zero until they land.*

### Phase 2 — Sub-grid tolerant match *(Issue B → R3; TC4)* — ✅ DONE
- **2.1** ✅ RED confirmed at the Phase-1 baseline (exact `==` dropped `(0,31)`).
- **2.2** ✅ `select.c`: new `endpoint_near(ax,ay,bx,by,tol)` (|Δx|≤tol && |Δy|≤tol);
  `select_attached_nets()` computes `tol = cadsnap/2` (floored to `1e-6` when snap
  ≤0) and the four `==` endpoint tests now call `endpoint_near`. Contained to
  `select.c`.
- **2.3** ✅ GREEN: TC4. **Guards GREEN:** TC11 (20-apart net not grabbed; tol=5 at
  cadsnap=10), golden harness PASS (clean designs unaffected — exact endpoints ⇒
  tolerant ≡ `==`), stable_handles 58 PASS. Sabotage-verified (tol→0 reddens TC4).
  Test fixtures pin `cadsnap 10` in `we_reset` for a deterministic tolerance.

### Phase 3 — T-junction follow + pin abutment ✅ DONE *(Issues C & H → R4/R20; TC5, TC16)*
**Status: COMPLETE.** Approach (b) taken — the plain (cadence + intuitive-stretch) drag
now sets `connect_by_kissing = 2` alongside `select_attached_nets()` in
`handle_button_press` (callback.c, both the cadence plain arm and the non-cadence
plain-stretch arm). `connect_by_kissing()` already handles abutment (TC16) and mid-span
T-junction (TC5) in one mechanism. TC5 geometry confirmed from the test = horizontal
wire kept `(-60,30)-(60,30)` + new vertical stub `(0,30)-(0,70)`. The headless helper
`we_move_stretch` now mirrors the drag faithfully via `move_objects … stretch kissing`.
Gesture-level proof added as test_cadence_drag Phase 6 (plain drag of abutted pins
generates a wire). Sabotage-verified both ways (drop callback trigger → cadence Phase 6
reddens; drop helper kissing → TC5/TC16 redden). Guards green: wireedit
TC1/2/3/4/11/13/14/15, golden harness, stable_handles 58, test_cadence_drag 12.
- **3.1** RED: TC5 fails (mid-span wire not selected); TC16 fails on the drag/stretch
  path (abutted pins disconnect — no wire generated).
- **3.2** Decide approach (open the choice in the tests' expected geometry first):
  (a) add a point-on-segment (`touch()`) branch to `select_attached_nets()` that adds
  a kissing-style stub at the pin; or (b) route the plain-drag/stretch path through the
  existing `connect_by_kissing()`. **Prefer (b)** — `connect_by_kissing()` already
  handles **both** the mid-span/T-junction (TC5) *and* the pin-to-pin abutment (TC16)
  in one mechanism (its first loop is the pin-pin case, its second the wire-touch
  case). Verified: `kissing` move regenerates the abutment wire; `stretch` does not.
- **3.3** GREEN: TC5 **and** TC16. **Wire it into the gesture:** the intuitive
  plain-drag and the `cadence_compat` plain-drag should set the kissing flag (or call
  `connect_by_kissing()`) alongside `select_attached_nets()`, so abutment/T-junction
  follow on a normal drag — this also restores what `cadence_compat` lost when
  Shift+drag became `copy` (see [[cadence-modifier-drag]]). **Guard:** TC2/TC11/TC13
  (rigid multi-move must not spuriously kiss its own selected pins — `connect_by_kissing`
  already skips selected instances) + golden harness.

### Phase 4 — Corner-slide rubber-band ✅ DONE *(Issues D1/D2/D4 → R7/R8; TC6, guard TC15)*
**Status: COMPLETE (`compute_wire_slide()`, move.c).** At move END — guarded to
`orthogonal_wiring` + axis-aligned (`(dx!=0) != (dy!=0)`) + non-rotating — a fixpoint
promotes each partially-selected wire that (a) runs **perpendicular** to the move and
(b) whose **far** endpoint meets another wire (a corner) and is **not** on a fixed pin,
to a **full** selection so it *translates* (slides) instead of jogging at the moved
end; neighbour endpoints at the corner are selected so they stretch to follow (R2).
Far end on a fixed pin → left partial → jogs (R18/TC15); free dangling far end → jogs
(TC3). TC6 RED→GREEN (5/5, reproduces `desired2`); the horizontal sibling slides clean
too (stub translates, rail stretches, 2 wires Manhattan). Sabotage-verified (disable
the call → TC6 reddens 4/5). Guards green: wireedit TC1–5/11/13–16, golden harness,
stable_handles 58, test_cadence_drag 16. *Residue:* complex multi-rail horizontal
moves may leave an overlapping segment → Phase 5 cleanup.
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

### Phase 5 — Release-time cleanup ✅ DONE *(Issue D3 → R10/R11/R12; TC7, TC8, TC9)*
**Status: COMPLETE (commit `02975fd4`).** On a STRETCH move the release-time cleanup
runs at move END regardless of `autotrim_wires` (new `xctx->stretch_select`, set in
`select_attached_nets()`, cleared at END/ABORT). Order: `trim_wires()` (TC7 colinear
merge + TC8 include/overlap dedup, reusing check.c) → `remove_move_orphan_wires()`
(move.c, TC9: drops a redundant dangling stub off the moved pin — one free end, kept
end on a MOVING pin another wire already serves). TC9 is scoped by a *coordinate
snapshot* of the grabbed wires captured in `select_attached_nets` (the kissing/commit
pipeline re-mints wire ids and clears `sel` before move END, so neither survives), so a
pre-existing distinct-net wire the moved pin merely landed on is never deleted (TC11
guard). TC7/8/9 RED→GREEN, sabotage-verified; guards green (wireedit TC1-9/11/13-17,
golden, stable58, cadence16, regression). 5.4 horizontal sibling: clean (residue
collapses). NOTE: the TC7/8/9 fixtures use a no-op stretch move to fire the cleanup on
hand-built residue (option A).
- **5.1** RED+GREEN: TC8 (duplicate/overlap) — ensure `trim_wires()`'s include-removal
  runs on the stretch path (call it post-move for stretch moves regardless of
  `autotrim_wires`, **or** add a dedicated post-slide dedup). Smallest first.
- **5.2** RED+GREEN: TC7 (colinear degree-2 merge) — via the same `trim_wires()` merge.
- **5.3** RED+GREEN: TC9 (move-orphaned dangling stub) — add a **move-scoped** removal:
  only delete a degree-1 wire that (i) was selected/created by this move and (ii) has
  an end on no pin and no other wire. Carefully scoped so intentional dangling wires
  elsewhere are untouched. **Guard:** TC11/TC14 (undo must still restore) + golden.
- **5.4** Re-run TC6's horizontal sibling: confirm the Phase-4 overlap is now merged.

### Phase 6 — Exit-stub preservation ✅ DONE *(Issue E → R13; TC10)*
**Status: COMPLETE.** Gated behind a new `wire_exit_stub` switch (default OFF, mirrored
C↔Tcl: Tcl default + `tctx::global_list` + Options-menu checkbutton; read in C via
`tclgetboolvar`). New `insert_exit_stubs()` (move.c) runs at move END **after**
`trim_wires()`/`remove_move_orphan_wires()` (so the inserted stub is never merged back),
guarded `wire_exit_stub && stretch_select && orthogonal_wiring && non-rotating`.
- **6.1** ✅ RED: TC10's Phase-1 assertion was a wrong GUESS (asserted a *horizontal*
  stub). **Corrected:** res.sym pin M sits at the top of a `+y` lead, so its outward
  normal is **vertical** (`+y`) — confirmed headlessly (`instance_pin_coord` + bbox) and
  against the user golden `desired1` (`N 1360 -900 1360 -880`, vertical). TC10 rewritten
  to assert the vertical stub `(1360,-870)-(1360,-860)`, RED against the new geometry.
- **6.2** ✅ Algorithm: for each moving pin carrying exactly one attached first-leg wire,
  the exit normal = dominant axis of (pin − symbol-bbox-center). A leg **colinear** with
  the normal (straight exit) is left alone (a colinear stub would just be re-merged, and
  a straight exit can't cross the body). A leg **perpendicular** to the normal is **slid**
  one minor grid out along the normal (its far endpoint and every neighbour at that
  corner dragged the same grid, keeping it Manhattan + connected), and the gap at the pin
  is filled with the short exit stub. **Stub length = one minor grid (`cadsnap`)** — the
  grid the route snaps to. Guards mirror `compute_wire_slide`: never pull a far end off a
  fixed pin; only at a real corner (far end meets another wire).
- **6.3** ✅ GREEN: TC10 (switch ON). TC10 also embeds the **switch-OFF guard** (same
  fixture, OFF ⇒ no stub, plain corner-slide route = `desired2`) so the gate is proven in
  one file. **Sabotage-verified** (drop the call ⇒ TC10's 4 stub checks redden, switch-OFF
  + Manhattan + connectivity stay green). **Guards GREEN, switch OFF (unchanged geometry):**
  wireedit TC1-9/11/13-17 (TC12 still its own RED, separate), golden harness `== HARNESS:
  PASS ==`, stable_handles 58, test_cadence_drag 16, regression create_save/open_close/
  netlisting. Undo fidelity (G2/R17) verified with the switch ON (one undo restores exact
  prior geometry — the stub is in the move's undo unit).

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
