# 1303 — a Tcl canvas pick reads SNAPPED mouse coordinates and can answer for a device the user did not click

🟡 **THE ACCESSOR LANDED 2026-09-04; THE TWO CALLERS ARE NOT FIXED YET.**


## Investigation note, 2026-09-28 — what `test_rdw_keys_1245` is actually doing

`rdw::pick_click` **has been converted** to the unsnapped accessor: it reads
`xschem get mousex`/`mousey` and falls back to a CIW refusal only if either comes back
empty. So the caller half of this issue looks done for that proc. But its suite,
`tests/headless/test_rdw_keys_1245`, fails **six rows deterministically** — F1, C2, V2,
V3, V7, D1 — identically across four unmodified runs on the dev display. Recorded here
rather than fixed, because the investigation did not converge and the remaining clue
needs somebody with a screen.

**What is established (all driven):**

* The fixture and pick points are correct. Row `V0`, the control, passes:
  `xschem instance_at` at the computed device centres returns `M1`, `M2`, `R1`.
* The binding seizure is correct. Row `V1` passes: `<ButtonPress-1>` holds
  `rdw::pick_click; break`, and the release and Escape bindings are taken.
* **Synthesised motion DOES reach the C side.** Measured standalone on `:99` with a
  `cmos_inv.sch` fixture: `.drw` carries `<Motion>` bound to
  `xschem callback %W %T %x %y 0 0 0 %s`, and `event generate .drw <Motion> -x .. -y ..`
  moved `xschem get mousex` to `136.28,-350.84` for a device centre of `137,-350`,
  with `instance_at` on those coordinates answering `M2`. So the harness is not
  fundamentally unable to drive this.
* **In the failing path the pick reads the drawing area's CORNER.** `pick_click` saw
  `mousex=813.80876 mousey=-467.43196` with `xorigin=-139.891237113402`,
  `yorigin=467.4319573697409`, `zoom=0.6071329061019783`. Back-calculated through
  `user = px*zoom - origin` that is pixel **(1110, 0)** exactly — and `.drw` measured
  **1110x693**. `mousey` is `-yorigin` to every digit, i.e. `py` is exactly 0. A
  specific corner, not drift.
* The CIW line it then emits is its own *"no device under the click"* arm, so the
  refusal is correct behaviour for the coordinates it was given. **The defect is
  upstream of the pick, in what set the mouse position.**

**⚠ Two instrumentation traps, both hit, both worth knowing before re-opening this:**
adding `puts` diagnostics between the Motion and the ButtonPress made the click
**succeed** (`nblocks` went to 1) — so the failure is sensitive to what runs between
the events even though it is otherwise deterministic. And wrapping `rdw::pick_click`
with a rename to log its arguments to a file produced an **empty log**, while an
earlier run in the same session captured that proc's own CIW message — so the wrapper
either did not install or was displaced. Neither probe is trustworthy as written.

**Not attempted, deliberately:** no change was made to `rdw::pick_click` or to the
suite. Changing product code to satisfy a test whose timing can be perturbed by a
`puts` risks fixing the wrong half, and this project's own rule is never to conclude a
gesture works on the strength of synthesised events. The next step wants either a real
pointer (`event generate -warp 1`, which actually moves the cursor) or somebody
watching the screen.`xschem get mousex` / `mousey` now answer the **unsnapped** schematic
coordinates, beside the snapped pair that was previously the only thing Tcl
could ask for. That is the piece that made the defect unfixable rather than the
fix itself:

* **`src/ase_window.tcl` still snaps** — this is a **shipped** defect, older
  than this batch, and it is now repairable in one line. Not repaired here
  because it is nobody's item yet; whoever takes it should carry this issue's
  lattice numbers as the red-first evidence.
* **item B4's re-do** is the other caller, and it is the reason the accessor
  exists.

⚠ **THE SNAPPED PAIR IS NOT DEPRECATED AND MUST NOT BE.** It is correct for
everything that *places or moves* geometry — that is what snapping is for, and
`new_arc` / `new_rect` / `new_polygon` and the move/copy arms all read it.
"What is under the pointer" is a different question, and now both are askable
with neither as a silent default. Fenced by rows **P1** and **P2** of
`tests/headless/test_rdw_window_1245.tcl`.

Driver re-measurement, independent of B4's, on the shipped example after
`update_all_sym_bboxes`:

```
EXACT   175.175 -199.612 -> 'M1'
SNAPPED 180 -200         -> 'R1'
```

---

*Original filing follows.*

**Status: ~~FILED, NOT FIXED.~~** Found by item **B4**'s adversary, reproduced
first-hand by B4's write-up agent, and **it is why item B4 was reverted**.
Live in the tree at `735ea26e` in `src/ase_window.tcl`; it was live in B4's
reverted patch too.

## What was measured

`scheduler.c` exposes exactly one mouse-coordinate pair to Tcl —
`mousex_snap` / `mousey_snap` (`:5018`, `:5022`). **There is no unsnapped
accessor.** Measured on this tree:

```
unsnapped accessor exists? [catch {xschem get mousex} m] -> 0 -> ''
```

Every C click path reads the **unsnapped** `xctx->mousex` / `mousey`
(`callback.c:520`, `:530`, `:4305`, `:4471`, and `:4664` — C's own read-only
`find_closest_instance`). So a Tcl pick that defaults to the snapped pair
resolves a **different point** from the one the user's own click resolved.

Reproduced headlessly on the shipped `xschem_library/examples/cmos_inv.sch`,
with `xschem update_all_sym_bboxes` called first:

```
exact  175.175 -199.612 -> 'M1'
snapped 180 -200        -> 'R1'
```

Two different devices, from one pixel. The window names `R1`; the user clicked
`M1`; nothing on screen says which happened.

B4's adversary quantified it by lattice sweep over every instance bbox on that
sheet at the default snap: **23725 points, 1513 (6.4%) miss the device
entirely, 129 (0.5%) resolve to a DIFFERENT device.** Instance bodies are the
bad case precisely because their bbox edges are not on grid, so snapping moves
the point up to half a grid step in each axis — which is exactly the distance
that crosses a boundary.

## Why this is a ruling-shaped defect and not a typo

Invariant **I3** and the `save.c` **D5-1** precedent it cites: *a plausible
wrong number on a schematic is worse than none*. A results window headed
`R1:/` for a click on `M1` is that failure exactly, one object further out —
the number is right for the device named, and the device is the wrong one.

## The shared idiom, live in the tree today

`ase::ui::sod_click` (`src/ase_window.tcl`) has the identical default:

```tcl
if {$x eq {}} { set x [xschem get mousex_snap] }
if {$y eq {}} { set y [xschem get mousey_snap] }
```

**The harm there is not the same and is NOT measured.** ASE Direct Plot picks
nets, wires and source bodies; wires are drawn on grid, so snapping tends to
land *on* the target rather than off it. The mechanism is shared; the measured
consequence above is for **instance-body** picks. Do not quote this issue as
evidence that ASE Direct Plot mis-picks — that has not been driven.

## Options, none taken

* **(a) add an unsnapped accessor** — `xschem get mousex` / `mousey` beside the
  existing pair, two lines in `scheduler.c`. Smallest thing that makes a Tcl
  pick able to agree with C. Costs a C change, which item B4 was not allowed.
* **(b) pass `%x %y` from the binding and convert** — the binding already has
  the pixel; the conversion verb would have to be found or added.
* **(c) wrap the pick in `xschem set no_snap 1` and restore** — the shape
  `ase_window` already uses elsewhere; a mode-global with a restore obligation
  on every error path.

**Recommended: (a).** It is the only one that leaves the caller honest with no
state to restore, and it fixes every future Tcl pick rather than one call site.

## Acceptance, when someone takes it

1. A pick at a pixel resolves the **same** object an ordinary left-click at
   that pixel selects — driven at a point measured to straddle a bbox edge,
   not at a bbox centre. **A fixture that computes click points from
   `xschem instance_bbox` centres cannot see this defect**; that is why B4's
   21-check suite was green while the defect was live.
2. The 175.175/180 pair above, as a regression row.

---

## UPDATE, 2026-09-04 — half the ground moved, and the issue is still open

**The C is in.** Commit `0ce85dda` landed option **(a)**: `xschem get mousex`
and `xschem get mousey` now answer the unsnapped schematic coordinates
(`src/scheduler.c:5047`, `:5051`), beside the snapped pair at `:5055`/`:5059`.
Rows **P1**/**P2** of `tests/headless/test_rdw_window_1245.tcl` fence both
pairs. **So the first paragraph of the Options section above is out of date: a
Tcl pick can now agree with C, and the fix costs no further C.**

**The Tcl consumer is NOT in.** Item **B4-2** wrote it — `rdw::pick_click`
defaulting from the unsnapped pair, with *no* fallback to the grid pair, because
that fallback is this defect — and B4-2 was reverted for three *other*
refutations (issues **1305**, **1306**, **1307**). The work is preserved,
unmodified and re-appliable in both directions, in
`doc/claude/op_param_batch/B4-2_working_tree_REVERTED.patch`. **Do not retype
it.**

**The measurement re-ran unchanged** on the reverted tree at `0ce85dda`:

```
exact   175.175 -199.612  ->  'M1'
snapped 180     -200      ->  'R1'
```

**`src/ase_window.tcl` is untouched and still resolves its pick from the snapped
pair.** That half was outside B4-2's Files cell and is outside item B4-3's too.
**This issue may not be closed on the rdw fix alone.**

⚠ **One constraint the next crew must not rediscover the hard way.** A synthetic
`<Motion>` cannot carry the filed pair: `sx(175.175) = 158`, `sy(-199.612) =
551` at zoom 1.2165, and the event lands at `mousex = 173.95876`,
`mousey = -200.82845` / `mousex_snap = 170`, `mousey_snap = -200` — where
**both** pairs answer `M1`. A synthetic-event-only row is therefore **vacuous**
for this issue: it passes against the broken code. Carry the filed pair through
an explicit-coordinate call, and drive the *default* path at a straddling pixel
found at run time, with "a discriminating pixel exists" as its own leg.
