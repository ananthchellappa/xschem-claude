# Wire segment splitting: independent click regions between attachment points

Status: **SPEC drafted 2026-07-05; W0-W6 ALL DONE — feature complete.** Branch
`fluid-editing` (sibling of `doc/claude/specs/fluid_editing.md`; the natural next
Cadence-UX increment). Design grounded by a 7-reader + 3-critique understanding workflow
(2 adversarial critiques survived; findings folded into §7 Hazards). `select_at` replay
fidelity for split wires (Hazard H8) is deferred as **issue 0078**.

> **AMENDED 2026-08-06 by `doc/claude/specs/wire_label_ride.md` S2 (R2): a `type=label` pin is a
> NAMING ANCHOR, not an attachment point.** This feature's "attachment" is now a **device** pin
> only. A net label neither splits a wire (§6.1) nor blocks the §5 pin-aware merge, behind
> `label_splits_wires` (default 0; set it to 1 to restore everything written below verbatim).
> Read §5 and §6.1 with that substitution in mind, and note two consequences:
>
> - **The §5 linchpin argument survives intact but changes owner.** "Net-labels need no special
>   case: a label is just an instance whose pin is at `get_inst_pin_coord`" is exactly the
>   assumption S2 reverses — the label *was* the special case all along, and `any_inst_pin_at()`
>   now takes a `skip_labels` argument to say so. The **auto-rejoin-on-delete** behaviour §5 sells
>   as the second half of the guard is unchanged for device pins, and for a label it is now
>   permanent rather than earned: there is no boundary to remove.
> - **What is given up is per-segment click granularity at a net label**, `autotrim_wires` only.
>   The `test_wire_splits.sch` fixture that motivated this whole feature (wire tapped by a label at
>   −80 and a resistor at 0) now loads as **2** clickable segments, not 3. The resistor's boundary —
>   the case the feature exists for — is untouched. `tests/headless/test_wire_split.tcl` was
>   re-authored onto `devices/res` taps for that reason (`wire_label_ride.md` §15.6); every fixture
>   here that used a `lab_wire` as its split source was measuring the wrong thing.
>
> Not amended: **D1** (coalesce-on-save keeps the `.sch` byte-stable — the coalescer was always
> pin-blind, so the label split never reached disk anyway), **D2** (default mode byte-for-byte
> unchanged — `label_splits_wires` carries its own gate precisely so D2 stays load-bearing), and
> every hazard H1–H11.

## Built

- **W6 — end-to-end integration through the real cadence path. Test-only** (`test_wire_split.tcl`).
  Exercises the whole feature the way a user actually gets it: `set cadence_compat 1` (which
  auto-enables `autotrim_wires` via the `cadence_compat_sync` write-trace — verified, NOT set
  directly as W1-W5 do). On the exact `test_wire_splits.sch` geometry (wire `-100..110` tapped by
  a net-label at −80 and a resistor pin at 0): asserts **3 clickable segments** (per-region
  `select_at` → 3 distinct `wire_id`s), the split is real (default 1 wire vs cadence 3), the R7
  **node map is identical** to default mode (INV-1 end-to-end), `saveas` **coalesces to a single
  `N` record byte-identical** to the default-mode canonical file (D1), and a reload **re-splits to
  3** (round-trip). Self-contained (embeds the fixture, so it runs on a clean checkout) plus an
  extra skip-if-absent pass on the actual untracked SANDBOX artifact (present here: 3 segments,
  netlist invariant, coalesces to 1 `N`). `test_wire_split.tcl` now **66 checks**. No `src/`
  change. **This closes the feature — W0-W6 all done.**

- **W5 — hazard guards (H2 near-miss, H3 X-crossing). Test-only** (`test_wire_split.tcl`).
  `break_wires_at_attach_points` already satisfies both by construction (pin-only sweep at the
  exact `get_inst_pin_coord`, gated on true `touch()` + strict-interior — never a projected
  point, never a bare wire crossing), so like W2 this phase LOCKS the invariant rather than
  adding code (zero `src/` change). **T3 (H3):** two wires that merely cross (no endpoint/pin at
  the cross) stay **2** wires on **2 distinct nets** — a split there would make four stubs share
  the cross and short the nets. Confirmed xschem does not connect a bare crossing. **T3b positive
  control:** a net-label pin placed AT the crossing is interior to both wires → splits them 2→**4**
  and connects all four to **one** net — i.e. the exact short-on-split signature T3 guards against,
  so T3's assertion is not vacuous. **T8 (H2):** an instance pin 5 units OFF the wire does **not**
  split it (`get wires==1`) and does **not** connect (wire net ≠ the label net); **T8b control:**
  the SAME label EXACTLY on the wire splits (→2) and connects (wire net == label net). A probe that
  force-projected the near pin onto the wire found **defense in depth** — `break` split at the
  projected point but `trim_wires`' pin-aware merge re-welded it (no real pin at the joint) and the
  off-wire pin stayed unconnected, so the observable stayed correct. `test_wire_split.tcl` now 54
  checks. Not yet committed.

- **W3 — edit-time re-split / rejoin via `maintain_wire_segments()` (§6.2).** The
  autotrim-gated edit-time `trim_wires()` sites now call `maintain_wire_segments()` so an edit
  that creates an attachment SPLITS the wire and one that removes an attachment REJOINS the
  stubs (free, via the W0 pin-aware merge): draw wire (`actions.c` interactive + `scheduler.c`
  `xschem wire`), move/copy END (`move.c:1049`), stretch/move END (`move.c:2030`, re-gated so an
  autotrim-off stretch still gets plain `trim_wires` and NOT a pin-split — D2), align
  (`scheduler.c` align + `callback.c` Alt-U), and instance place (`scheduler.c` `xschem
  instance`, a new hook — `place_symbol` had none). **The real fix: `delete()` (`select.c`)
  previously ran `trim_wires()` only when a WIRE was deleted, so deleting a lone net-label
  never rejoined its two collinear stubs; now any deletion re-runs maintenance (autotrim-gated).**
  All sites are undo-safe (the enclosing edit already `push_undo`s; maintenance rides the same
  transaction) and strictly gated on `autotrim_wires`, so default mode is byte-for-byte
  unchanged. Left as pure `trim_wires` (the low-level primitive, not an attachment-changing
  edit): `&` Join/Trim key, `xschem trim_wires`, `select.c:98` stop-at-junction, and
  `break_wires_at_pins`' internal trim.
  **W4↔undo interaction fixed:** disk `push_undo` serialises via the same `write_xschem_file`
  as a real save, so W4's coalesce was collapsing the segmented array *inside undo snapshots* —
  an undo then restored the coalesced single wire, losing the user's clickable segments (caught
  by the T4 undo check). Coalesce is now **opt-in** (`coalesce_wires_on_save`, set only by
  `save_schematic` around the persistent `.sch` write); undo snapshots and autosave `~` backups
  preserve the EXACT in-memory segmented array. Tests (T4/T4b/T4c, +6): delete-label→rejoin
  (3→2) with node-map invariance (INV-1) and undo restoring the 3-segment state; place-label→
  split (1→2) + undo; draw-wire-under-label→split (1→2) + undo. `test_wire_split.tcl` now 47
  checks. RED→GREEN + sabotage-verified (neutering the delete-path maintenance flips only the
  T4 rejoin/count checks; place/draw stay green). Not yet committed. *Deferred:* GUI
  interactive place/paste split (only the scripted `xschem instance` path is hooked; paste of N
  instances would want a single post-batch sweep, not per-`place_symbol`); localised
  attachment sweep for perf on large sheets (review finding #6).

- **W0 — pin-aware `trim_wires` merge (`check.c`)** — the linchpin (§5). Added
  `any_inst_pin_at(x,y)` (static, before `trim_wires`) and extended the merge guard
  (`check.c`, the `end2==0 && end1==0` condition) with `&& !any_inst_pin_at(x0,y0)`, so a
  collinear joint carrying a net-label / instance pin is no longer welded (and auto-rejoins
  for free once the pin is removed). Test `tests/headless/test_wire_split.tcl` (6 checks:
  positive control that merge still fires with no pin, RED anchor that it does NOT merge
  across a label pin, distinct-`wire_id` check), registered in `run_regression.tcl` hcases.
  RED→GREEN + sabotage-verified (neutering `any_inst_pin_at` to `return 0` flips the RED
  check back to FAIL). `test_fluid_editing` (drives `trim_wires` via the stretch-select
  path) and all other headless cases stay green. Committed @ `b5d4bc13`.

- **W1 — read-time split at attachment points (`check.c`, `save.c`).** New
  `break_wires_at_attach_points()` sweeps every instance's PINLAYER pins (covers
  net-labels/pins/bus_taps) and `wire_store_split`s each wire at the **exact** interior pin
  coord (no projection — Hazard H2; interior guard excludes endpoints and X-crossings —
  H3); no `push_undo` (caller owns undo). New `maintain_wire_segments()` =
  `break_wires_at_attach_points()` then `trim_wires()` (T-splits + W0 pin-aware merge +
  degenerate cull). Load hook: the `save.c` normalize block now calls
  `maintain_wire_segments()` instead of the bare `trim_wires()`, inside the
  `mod_before_norm` revert + `no_autosave` (H6 — freshly-opened file not dirtied).
  Prototypes in `xschem.h`. Test T1 (load 1 wire + 2 mid-span labels → 3 segments; each of
  3 region `select_at`s hits one distinct `wire_id`; endpoints `{-100 -50 50 100}` exact).
  RED→GREEN + sabotage-verified. Integration: the real `test_wire_splits.sch` loads as
  **3** segments under autotrim. All headless cases green. Committed @ `1cbd05bb`.

- **Review (xhigh, workflow-backed) + fixes** — a 24-agent adversarial review of W0-W2
  produced 10 ranked findings; the actionable ones fixed in follow-ups (`0992065a`,
  `1e22d97b`):
  0. **Stale spatial table (HIGH, #1):** `break_wires_at_attach_points` called a bare
     `hash_wires()`, which no-ops when `prep_hash_wires==1`; a load-path
     `prepare_netlist_structs` (via an `@`-param net-name) + a `check_collapsing_objects`
     wire deletion can leave the table stale, so the sweep would index reindexed/OOB wire
     slots. → Set `prep_hash_wires=0` before `hash_wires()` (as `trim_wires` does). Fixed
     `1e22d97b`.
  1. **D2 leak (MED):** the W0 pin-aware merge guard ran inside `trim_wires`
     *unconditionally*, so non-autotrim callers (`&` Join/Trim key, `xschem trim_wires`,
     stretch-move) changed default behaviour (contradicting D2). → Gated the guard on a
     `split_active = tclgetboolvar("autotrim_wires")` flag computed once at `trim_wires`
     top; added regression `W0/D2` (autotrim off still merges across a pin → 1; on → 2),
     sabotage-verified. This also short-circuits the `any_inst_pin_at` cost off the default
     path (addresses the O(inst·pins) perf finding).
  2. **Test depended on an untracked fixture (HIGH):** T2 loaded the SANDBOX
     `test_wire_splits.sch` (not in the commit range) and `bail`ed if absent → the
     regression fails on a clean checkout. → T2 now builds a **self-contained** res+label
     fixture; the real file is an optional skip-if-absent integration check.
  3. **Stale derived caches (latent):** `break_wires_at_attach_points` cleared only
     `prep_hash_wires`; now also clears `prep_net_structs`/`prep_hi_structs` (matching
     `break_wires_at_pins`) so edit-time callers (W3) rebuild correctly.
  4. **Duplication:** `any_inst_pin_at` reused the exact-match rule from `touches_inst_pin`
     via a forward decl instead of a copied loop body.
  5. **Over-promising comment (F2):** the load-hook / sweep comments claimed
     "re-joined by coalesce-on-save" as if built. Corrected to state W4 is **pending** and
     that, until then, an autotrim/cadence save persists the split as multiple `N` records
     (D1 not yet honoured) — see the ⚠ below.
  Deferred (documented, not bugs in the current call graph): edit-time paths still call bare
  `trim_wires` (that is W3); `break_wires_at_attach_points` duplicates the split core of
  `break_wires_at_pins` (larger refactor); off-grid ULP pin match is theoretical
  (xschem's connectivity is exact-equality too, so a near-but-off pin is not connected).

- **W4 — coalesce-on-save (§6.3, D1).** New `merge_collinear_wires(list, n, ignore_pins)`
  (`check.c`) coalesces a wire array in place: re-joins every maximal run of collinear,
  same-`prop_ptr`, abutting segments whose shared joint carries **no other (non-collinear)
  wire endpoint** (a real T-junction stays split — spec §6.3). `save_wire()` (`save.c`), on a
  full save with `autotrim_wires` on, runs it **pin-blind** (`ignore_pins=1`) on a *private
  scratch copy* (shallow `memcpy`; `prop_ptr`/`node` borrowed, only read/geometry-rewritten)
  so the on-disk `.sch` is the minimal coalesced form while `xctx->wire[]` — the user's live
  clickable segments — is never disturbed. Strictly gated on `autotrim_wires`: default-mode
  saves stay byte-for-byte verbatim (`select_only`/clipboard also verbatim). Prop-equality is
  **always** required before welding (unlike `trim_wires`' pin-blind merge) so a user who
  diverges one segment's attributes keeps that boundary on disk (H7). Tests (T6/T6b/T6c/T7):
  split-on load→saveas is **byte-identical** to the split-off canonical file and re-splits on
  reload (round-trip); INV-1 node map invariant across the round-trip; divergent-prop segments
  persist as 2 records (+ non-vacuous control); a T-junction stays 3 records (no weld across a
  3rd-wire endpoint); default-mode save verbatim + deliberately-abutting wires not merged.
  RED→GREEN + sabotage-verified twice (no-coalesce flips the D1 checks; prop-blind flips only
  the divergence check). `test_wire_split.tcl` now 34 checks. Not yet committed.

- **W2 — connectivity / netlist invariance (INV-1). Test-only** (`test_wire_split.tcl`).
  W1's code already satisfies it; T2 locks it: load the real `test_wire_splits.sch` split
  OFF vs ON and assert `xschem instance_nodemap R7` is byte-identical (`R7 P GB M #net1` —
  same node names, same pin membership, same auto `#netN` numbering, so Hazard H4 is not
  triggered here) while proving the split really happened (1 wire vs 3 segments, so the
  invariance is not vacuous). Sabotage-verified with real teeth: perturbing the split point
  off the wire line orphans `R7.P` (GB → `#net1`) and flips all three T2 checks RED. Not
  yet committed.

## 1. Problem

Repro fixture: `xschem_libs_newsym/SANDBOX/test_wire_splits/schematic/test_wire_splits.sch`

```
N -100 -60 110 -60 {lab=GB}                 # ONE wire object, x=-100..110 at y=-60
C {devices/lab_wire} -80 -60 0 0 {name=l8 lab=GB}   # net-label taps the wire at x=-80
C {devices/res} 0 -30 0 1 {name=R7 ...}             # resistor pin taps the wire mid-span
```

To any user this is **three** segments — `[-100..-80]` (end → label), `[-80..resistor]`
(label → resistor), `[resistor..110]` (resistor → end) — that ought to be three
independent click regions. xschem stores it as **one** `xWire` record, so a click
anywhere near `y=-60` selects the whole wire.

**Why one click selects everything:** `find_closest_wire()` (`findnet.c:28-52`) scores the
mouse against each wire's full `[x1,y1]-[x2,y2]` segment and selects the nearest whole
`xWire`. There is no sub-segment concept: `select_object()` (`select.c:1353-1429`) WIRE
case always selects both endpoints. The `.sel` bits `SELECTED1/SELECTED2` (`xschem.h:258-261`)
exist only for stretch/tip-grab, never for a plain click.

**Consequence of the fix:** if the wire is instead **three `xWire` records** in the
in-memory array, the *existing* hit-test resolves a click to whichever short segment is
nearest — **zero changes to `find_closest_wire`/`select_object`**. Splitting the array is
the entire mechanism; everything else is bookkeeping to keep it correct and clean.

## 2. Desired behaviour (user's words)

> at read time, do the splitting up as necessary. Then, upon any edit, see if the wire
> splitting up (or rejoining) to update segments is necessary, to provide the desired UX.

So: **split at load**, and **maintain (re-split / rejoin) on every edit**.

## 3. Decisions locked (user, 2026-07-05)

- **D1 — Persistence: coalesce on save (in-memory only).** The split lives in the
  in-memory `wire[]` array (that is what makes segments clickable), but on save the
  collinear same-attribute pin-free runs are **re-joined** so the on-disk `.sch` stays
  byte-identical to today (`N -100 -60 110 -60 {lab=GB}`, one record). Rationale: the
  split buys *only* click/selection granularity — connectivity never needs it (§4) — so
  persisting it would be pure cost (1→N record git diffs, prop triplication, version
  oscillation, golden regeneration) for zero connectivity benefit.

- **D2 — Gating: ride `cadence_compat` / `autotrim_wires`.** No new Tcl var. Auto-split
  and coalesce-on-save are **active iff `autotrim_wires` is set** (which `cadence_compat`
  already force-enables, `xschem.tcl:15132-15133`; default is `0`, `xschem.tcl:14684`).
  With the toggle off — the default — **nothing changes**: no split, no coalesce, verbatim
  save, today's behaviour exactly. The toggle is literally labelled *"Auto Join/Trim
  Wires"* (`xschem.tcl:13541`), so "join collinear runs / split at attachments" is squarely
  its remit.

  **Consequence — the pin-aware-merge prerequisite (§5) is now mandatory, not optional.**
  `autotrim_wires` force-runs `trim_wires()` at load (`save.c:3843`) and after edits, and
  its merge pass is *pin-blind*. Without the §5 fix, load would split at the label and
  `trim_wires` would re-weld it in the same load — the feature would be inert in the exact
  mode that requests it.

## 4. Connectivity is already correct without splitting (invariant to preserve)

xschem nets connect on **coordinate touch**, not on shared `xWire` identity.
`prepare_netlist_structs` → `wirecheck`/`name_attached_nets` (`netlist.c:1007-1082`)
propagates a node to any wire whose endpoint or a pin lands on another wire's span,
using `touch()` (`clip.c:234`, endpoint/interior-inclusive). That is *why* default xschem
splits nothing at load yet netlists a mid-span tap correctly.

Therefore the hard invariant for this feature:

> **INV-1 — connectivity/netlist invariance.** Splitting a wire into collinear touching
> segments (all endpoints coincident at the split points) MUST NOT change which nodes
> exist, which pins are on which node, or the emitted netlist. A split is a pure
> in-memory selection affordance.

`wire_store_split` (`store.c:383-408`) already copies `prop_ptr`, `bus`, and `node` onto
the new segment, so both halves keep the same net — INV-1 holds *provided* the split point
is the **exact** attachment coordinate (see Hazard H2).

## 5. The linchpin: make `trim_wires` merge pin-aware

`trim_wires()` (`check.c:161-386`) is xschem's only rejoin machinery. Its merge pass
(`check.c:335-362`) welds two collinear touching segments when:

```c
touch(...) && parallel && wire[j].x1==x0 && wire[j].y1==y0 &&
xctx->wire[i].end2 == 0 && xctx->wire[j].end1 == 0      /* check.c:352-353 */
```

`end1`/`end2` are computed **only from other wire endpoints** (`check.c:294-332`; collinear
continuations are explicitly *excluded* from the count, lines 318-329). They are **never**
incremented by an instance pin or net-label — those live in `instpin_spatial_table`, not
`wire_spatial_table`. **So two segments meeting exactly at a label pin have `end==0` and
get merged — deleting the very boundary the split created.** Both adversarial critiques
independently flagged this as the #1 high-severity risk.

**Fix (surgical, `check.c`):** extend the merge guard to also refuse a join whose shared
point carries an instance pin:

```c
... && wire[i].end2 == 0 && wire[j].end1 == 0 && !any_inst_pin_at(x0, y0)
```

`any_inst_pin_at(x,y)` = "does any instance's any PINLAYER pin coincide with (x,y)?",
modelled on the existing `touches_inst_pin()` (`check.c:388-406`) but iterating all
instances (or querying `instpin_spatial_table` when `prep_net_structs` is current). This
single guard delivers **two** behaviours:

- **keeps** a split alive across the pin that caused it (idempotent under `trim_wires`);
- **auto-rejoins for free** when the user deletes the label between two segments — the pin
  vanishes, `any_inst_pin_at` returns false, `end==0` ⇒ the next `trim_wires` merges the
  two stubs back into one. This is exactly the user's "rejoining to update segments."

Net-labels need no special case: a label is just an instance whose pin is at
`get_inst_pin_coord(inst,0)` (`netlist.c:753`); `any_inst_pin_at` covers it. T-junctions
(a 3rd wire's endpoint mid-span) already block the merge via `end1/end2` and already split
via `check_breaks` — unchanged.

> **SUPERSEDED for net labels, 2026-08-06 (`wire_label_ride.md` S2).** "Net-labels need no special
> case" is the assumption that turned out to be wrong: a `type=label` pin carries no current and is
> a *name*, not a terminal, so treating it as copper geometry also made it split a wire, block this
> merge, and — measured — short two independent nets when it sat with an empty `lab=` on a wire
> **crossing** (four coincident split endpoints ARE connectivity). `any_inst_pin_at(x, y,
> skip_labels)` now takes the distinction as a parameter, and `trim_wires` passes
> `!label_splits_wires`. **T-junctions and device pins are unchanged**, and so is the
> auto-rejoin-on-delete property this section sells.

## 6. Architecture — reuse the existing engine, do not hand-roll

| Concern | Existing machinery to reuse | Location |
|---|---|---|
| Split one wire at a point | `wire_store_split(src,x0,y0,sel)` — appends head w/ fresh id, copies prop/bus/node/flags, `hash_wire(XINSERT)`; caller truncates `src` | `store.c:383` |
| Split at instance pins (exact `touch`, self-pushes undo) | inner pin-loop of `break_wires_at_pins()` — but it only walks **selected** instances | `check.c:496-566` |
| Strict-interior on-segment test | `check_breaks()` (static) / the idiom `(x0!=x1&&x0!=x2)||(y0!=y1&&y0!=y2)` | `check.c:38`, `:519` |
| Rejoin / T-split / degenerate cull | `trim_wires()` (+ §5 pin-aware guard) | `check.c:161` |
| Instance pin coords (rot/flip applied) | `get_inst_pin_coord(i,r,&x,&y)` — bound `r < sym->rects[PINLAYER]` | `netlist.c:753` |
| Junction dots | `update_conn_cues(WIRELAYER,0,0)` — derived from `end1/end2`, dot when counter>1 | `check.c:55` |
| Load hook + clean-modified guard | `load_schematic` normalize block | `save.c:3834-3845` |

### 6.1 New: `break_wires_at_attach_points()` (`check.c`)
Generalise `break_wires_at_pins` to sweep **all** instances (not just selected): for every
instance, every PINLAYER pin coord `P = get_inst_pin_coord(...)`, find wires with
`touch(wire,P)` **and** `P` strictly interior, and `wire_store_split` at the **exact** `P`
(never a projected/snapped point — Hazard H2). Excludes bare X-crossings by construction
(only endpoints/pins split, never a crossing). Sets `prep_hash_wires=0`, `need_reb_sel_arr=1`.

**Amended 2026-08-06 (`wire_label_ride.md` S2, change #6):** the sweep skips `type=label`
instances (`if(!label_splits && inst_is_netlabel(k)) continue;`, `label_splits` read once per
sweep). It is a **matched pair** with §5's `skip_labels` and the two must land together — but note
the asymmetry: relaxing the splitter alone is *invisible* in a wire count, because `trim_wires`'
now-label-blind merge welds the split back inside the same `maintain_wire_segments()` call. The
witness is a label at a wire crossing, where the merge is refused on `end1/end2` and the split is
permanent (`wire_label_ride.md` §15.1).

### 6.2 New: `maintain_wire_segments()` (`check.c`), gated on `autotrim_wires`
The canonical read/edit-time maintenance routine:
```
break_wires_at_attach_points();   /* split at pins/labels (new) */
trim_wires();                     /* T-splits + PIN-AWARE merge (§5) + degenerate cull */
```
Order matters: split first, then the pin-aware merge coalesces only genuine no-boundary
runs and cannot undo the pin-splits.

- **Load:** call inside the `save.c:3834-3845` guard, replacing the bare
  `if(reset_undo && autotrim_wires) trim_wires();` at `save.c:3843` — inside the
  `mod_before_norm`/`set_modify(0)` revert and under `no_autosave`, so a freshly-opened
  file is never flagged modified and writes no spurious `~` backup. **No `push_undo`** at
  load (undo stack already cleared, `save.c:3691`).
- **Edit:** the existing edit-time `trim_wires` call sites — `break_wires_at_pins:623`,
  `actions.c:4255` (draw new wire), `move.c:1049` (move end) and `move.c:2030` (stretch
  end), plus the delete path — become `maintain_wire_segments()`.
  Edit-time paths **must `push_undo` before the first mutation** (the `break_wires_at_*`
  self-push idiom `if(!changed){push_undo();changed=1;}`) and legitimately `set_modify(1)`.

### 6.3 New: coalesce-on-save (`save.c`), gated on `autotrim_wires`
On save, the disk form must be the minimal coalesced form (D1) **without disturbing the
live segmented array** (users keep their clickable segments after a save).

Recommended mechanism: a `coalesce_wires_for_save()` that runs the merge on a **scratch
copy** of the wire list — a *pin-blind* variant of the `trim_wires` merge (collinear +
same `prop_ptr` + abutting + no 3rd-wire endpoint at the joint), emitting the coalesced
records; `xctx->wire[]` is never mutated. Factor the merge core into
`merge_collinear_wires(list, n, ignore_pins)` shared by `trim_wires` (ignore_pins=0) and
the save path (ignore_pins=1). Coalesce only merges segments whose `prop_ptr` are
identical — a user who diverges one segment's `bus=`/`lab=` keeps that segment on disk
(correct: it is a real difference). **Gate strictly on `autotrim_wires`** so default-mode
saves stay verbatim (a default user's deliberately-abutting collinear wires must not be
silently merged).

## 7. Hazards (from adversarial critiques) and mitigations

- **H1 — pin-blind merge re-welds the split (HIGH).** → §5 pin-aware guard. *Mandatory
  first step given D2.*
- **H2 — inexact/off-grid split point silently disconnects (HIGH).** `touch()` and the
  interior idiom use **exact `==`**, no epsilon. Splitting at a projected/snapped point
  (the `closest_point_calculation align=0` path, `check.c:436-443`) can land 1 ULP off the
  pin ⇒ the pin fails `touch()` against *both* halves ⇒ net splits into two nodes with no
  error. → Auto-split MUST use the **exact stored** `get_inst_pin_coord` / wire-endpoint
  coordinate and require true `touch()`; a pin that is merely *near* the wire (not exactly
  on it) is **not split and not connected** — same as today. Forbid the projected-point
  path for auto-split.
- **H3 — X-crossing short (HIGH).** Splitting where two wires merely *cross* (no
  endpoint/pin there) would make 4 segments share the crossing as an endpoint ⇒ `wirecheck`
  merges them ⇒ two independent nets shorted. → Split **only** at pin coords and 3rd-wire
  *endpoints*, never at bare crossings (reusing `check_breaks`/pin coincidence enforces
  this by construction). Guarded by a RED test (§9 T3).
- **H4 — `#netN` renumbering (MED, bounded).** `name_unlabeled_nets` (`netlist.c:1506`)
  numbers unnamed nets in wire-array order, so reindexing could shift `net1/net2`. →
  Bounded away by D2: netlisting regressions run in **default mode** (autotrim off ⇒ no
  split ⇒ goldens untouched). In autotrim mode, `trim_wires` already splits at T-junctions
  today, so segmented-array netlisting is the *existing* behaviour there — no new golden
  breakage. Still covered by an explicit before/after netlist-invariance test (§9 T2).
- **H5 — save churn / version oscillation (resolved by D1).** Coalesce-on-save keeps the
  `.sch` byte-stable; open→save with no edits reproduces the original record. Guarded by
  §9 T6 (idempotency) and T7 (default-mode verbatim).
- **H6 — freshly-opened file flagged modified (MED).** A split outside the
  `save.c:3841-3844` revert leaves `modified=1` ⇒ spurious "save?" on first descend/close.
  → Load-time split lives strictly inside that guard (§6.2).
- **H7 — bus/prop divergence on split & loss on rejoin (MED).** `wire_store_split` copies
  `prop_ptr` to each segment; the merge keeps `wire[i]`'s and drops `wire[j]`'s
  (`check.c:355-357`). → Coalesce/merge only across **identical** `prop_ptr`; divergent
  segments never merge (so nothing is silently lost). Bus wires split like any wire
  (segments share `bus=`); a bus_tap is just a pin.
- **H8 — segment identity / `select_at` replay fidelity (MED, documented gap).** Split
  segments get fresh ids with no recorded parentage; `select_at` replay is
  coordinate-based (issue 0005), so a recorded mid-wire click resolves to whichever short
  segment is now nearest. → **Out of scope**; documented as a known limitation. Tests
  assert on **`wire_id`** (stable session handle), not array index. A logical-wire handle
  for wires is a possible follow-up, not part of this feature — tracked as **issue 0078**
  (`doc/claude/issues/0078-select_at-replay-fidelity-for-split-wires.md`).
- **H9 — two `N` readers (LOW).** `read_xschem_file→load_wire` makes `xWire`s; the
  embedded-symbol reader (`save.c:~5088`) stores `N` as *lines* on WIRELAYER. → The split
  hooks at post-`link_symbols_to_instances` normalization, never at the `N` parse level, so
  symbol line-art is untouched.
- **H10 — fluid tip-grab can tear the net from its label (MED).** A `fluid_editing`
  tip-grab on the new junction endpoint drags only that segment; `move.c` does not
  rubber-band the label along. → Pre-existing to fluid editing, not introduced here; note
  in docs. (Wire-follow-on-move is tracked separately.)
- **H11 — connection dots stale (MED).** Dots derive from `end1/end2` via
  `update_conn_cues`. → `maintain_wire_segments` sets `prep_hash_wires=0` and the tail of
  `trim_wires` already re-runs `update_conn_cues` (`check.c:385`).

## 8. Non-goals

- No change to default (`autotrim_wires=0`) behaviour whatsoever. *(Still holds after S2:
  `label_splits_wires` is inert with autotrim off — nothing splits at any pin there. Asserted by
  `test_wire_split.tcl` `S2e`, both settings.)*
- No persisted split (D1): the `.sch` stays coalesced/canonical.
- No stable logical-wire handle / `select_at` replay fix for wires (H8) — separate,
  tracked as issue 0078.
- No splitting at bare X-crossings (H3) — preserves the existing xschem rule.
- No new Tcl toggle (D2).

## 9. RED-first implementation plan

Test-first throughout: write the failing check, watch it go RED, implement the smallest
change to GREEN, sabotage-verify (revert the change → RED again). One headless test file
`tests/headless/test_wire_split.tcl`, registered in `run_regression.tcl` `hcases`,
following the `test_fluid_editing.tcl`/`test_select_at.tcl` pattern: `check name got exp`,
`bail`, print `OVERALL: ok`, `exit 0`. Each check sets `autotrim_wires 1` (or
`cadence_compat 1`) unless it is a default-mode check. Assert on **`xschem get wires`** and
**`xschem wire_id <n>`** (stable), never array index. Author self-contained fixtures with
known coordinates (do not depend on symbol-library pin math for the assertions).

Phases:

- **W0 — pin-aware merge (§5). ✅ BUILT.** *RED (was):* T5 (do-not-rejoin-across-surviving-
  pin) — two collinear segments meeting at a label pin merged to 1; now asserts stays 2.
  *Built:* `any_inst_pin_at` + the `&& !any_inst_pin_at(...)` guard in the `trim_wires`
  merge condition. RED→GREEN + sabotage-verified. Foundation for W1-W4.

- **W1 — `break_wires_at_attach_points` + `maintain_wire_segments` at load (§6.1-6.2).
  ✅ BUILT.** *RED anchor (was):* T1 — load a fixture (one wire + 2 mid-span labels) with
  `autotrim_wires 1`; asserted `xschem get wires == 3` (was 1). *Built:* the new sweep +
  `maintain_wire_segments`, called from the `save.c` normalize guard. T1 GREEN: 3 distinct
  `wire_id`s, per-region `select_at` selects exactly one, endpoints exact. Sabotage-verified;
  real `test_wire_splits.sch` → 3 segments.

- **W2 — connectivity invariance (INV-1, §4). ✅ DONE (test-only).** T2 — `instance_nodemap
  R7` on the real fixture byte-identical split-off vs split-on (`R7 P GB M #net1`), plus a
  not-vacuous guard (1 wire vs 3). Passes after W1 (H2/H3 respected); sabotage-verified that
  a connectivity break flips it RED.

- **W3 — edit-time maintenance (§6.2). ✅ BUILT.** *RED (was):* T4 — deleting a mid-span
  `lab_wire` left the two collinear stubs split (3 wires, no rejoin) because `delete()` only
  trimmed on wire-deletion; T4b/T4c — placing/drawing a mid-span attachment did not split
  (1 wire). *Built:* the autotrim-gated edit-time `trim_wires()` sites route through
  `maintain_wire_segments()` (draw/move/copy/stretch/align/place), and `delete()` re-runs
  maintenance after ANY deletion so a removed label rejoins its stubs. Undo rides the enclosing
  edit's `push_undo`; T4 asserts undo restores the 3-segment state. **Undo fix:** coalesce made
  opt-in (`coalesce_wires_on_save`, persistent `.sch` only) so disk-undo snapshots keep the
  exact segmented array. RED→GREEN + sabotage-verified.

- **W4 — coalesce-on-save (§6.3, D1). ✅ BUILT.** *RED (was):* T6 — split-on load→saveas
  wrote 3 `N` records (byte-differs from the split-off canonical file); T6b control —
  no-divergence fixture wrote 2 records. *Built:* `merge_collinear_wires(list,n,ignore_pins)`
  (`check.c`) + pin-blind scratch-copy coalesce in `save_wire` (`save.c`), gated on
  `autotrim_wires`. T6 now byte-identical + round-trips; T6b divergent-prop persists 2 records
  (prop-equality gate, H7); T6c T-junction stays 3 (no weld across a 3rd-wire endpoint); T7/T7b
  default-mode verbatim. RED→GREEN + sabotage-verified twice (no-coalesce; prop-blind). The
  live `xctx->wire[]` is untouched by save (scratch copy), so segments survive a save.

- **W5 — hazard guards. ✅ BUILT (test-only).** T3 — X-crossing (two wires cross, no
  pin/endpoint at the cross): `get wires`==2 **and** 2 distinct nets (no short) — guards H3;
  T3b control (pin AT the cross → 4 segments, 1 net) makes it non-vacuous. T8 — a pin 5 units
  *off* the wire: **no** split (`get wires`==1) and **no** connect; T8b control (same label
  exactly on the wire → split + connect). Held by construction (exact `touch()`, pin-only
  sweep); a forced-projection probe confirmed defense-in-depth (break splits at the projected
  point but the pin-aware merge re-welds it). No `src/` change.

- **W6 — integration. ✅ BUILT (test-only).** Real cadence path (`cadence_compat 1` →
  autotrim via write-trace) on the `test_wire_splits.sch` geometry: 3 clickable distinct
  `wire_id`s; R7 node map identical to default (INV-1); saveas → 1 `N` byte-identical to the
  canonical file (D1); reload re-splits to 3. Self-contained + skip-if-absent pass on the real
  SANDBOX file. No `src/` change.

### Test matrix

| # | Fixture | Assert | Guards |
|---|---|---|---|
| T1 | wire + mid-span label + mid-span pin | `get wires == 3`, 3 distinct `wire_id`, per-region `select_at` hits 1 | W1 anchor |
| T2 | T1 fixture | netlist nodes identical split-off vs split-on | INV-1 / H4 |
| T3 | two crossing wires, no pin at cross | `get wires == 2`, netlist 2 nets (no short) | H3 |
| T4 | T1 fixture, then delete label | segments rejoin → `get wires` drops by 1; net intact | W0/W3 rejoin |
| T5 | two collinear segments meeting at a label pin | `trim_wires` keeps 2 (no merge across pin) | W0 |
| T6 | T1 fixture, saveas + reload | disk = 1 `N` record == original; reload re-splits to 3 | D1 / H5 |
| T7 | T1 fixture, `autotrim_wires 0` | `get wires == 1`; saveas byte-identical to input | default-mode / H5 |
| T8 | rotated sym, pin near-but-off wire | `get wires == 1`, no micro-stub | H2 |

## 10. One-line summary

Split each wire into its inter-attachment segments **in memory** (so the existing
`find_closest_wire` gives per-segment clicking), gated on `autotrim_wires`; make
`trim_wires`' merge **pin-aware** (the linchpin that both keeps splits alive and
auto-rejoins on label delete); and **coalesce on save** so the `.sch` stays byte-identical.
Connectivity/netlist stay invariant because xschem already connects on coordinate `touch`,
not on wire identity.
