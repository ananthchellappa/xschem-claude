# Spec — ALT+SHIFT+ScrollWheel: transpose selected bus index (up / down)

Status: v2 IMPLEMENTED + tested 2026-06-29 (test `tests/bus_transpose.tcl` all PASS —
pure transform incl. ranges + integration; GUI end-to-end Alt+Shift+wheel chord verified;
drift-guard / launch-context / engine all green). Original feature committed `1c8bfb0a`;
this revision
(a) renames the direction argument from **grow/shrink → up/down** (the index moves up or
down — "grow/shrink" was busresize's width vocabulary and read wrong here), and
(b) extends the transform to **ranges `[N:M]`** (previously left unchanged). Sibling of
the ALT+wheel grow/shrink feature (`doc/claude/specs/bus_thickness_scroll.md`); reuses
its single-undo machinery and the input action/bind registry. Distinct gesture, distinct
transform.

## Motivation

A mouse-only way to **shift the bus index** on the name of selected pins / net labels /
instances — e.g. step `dat` → `dat[0]` → `dat[1]` to retarget which bit/leaf a label or
iterated instance refers to, or step a whole slice `dat[3:0]` → `dat[4:1]`. "Transpose"
because it *moves* the index/range by one; it does **not** widen the bus (that is
busresize's job).

- **ALT+SHIFT+ScrollWheel-Up = "transpose up"**, on every selected object:
  - **wire** → no effect (a selected wire is tolerated, not an error).
  - **text** → no effect (tolerated).
  - **pin / net label** → bump the index up on its **`lab`** net/pin name (not the
    instance name).
  - **instance** → bump the index up on its instance **`name`**.
- **ALT+SHIFT+ScrollWheel-Down = "transpose down"** — the opposite, floored at 0 (no
  negative indices).

(The user described it with `<N>`; xschem's native notation is `[]`, so the stored /
displayed form is `something[N]` / `something[N:M]`. Delimiters are configurable, default
`[ ]` with `:` separator.)

## Index transform (normative; pure; configurable `[ ] :` delimiters)

**up(name):**

| input | output |
|---|---|
| `dat` (bare scalar) | `dat[0]` |
| `dat[0]` | `dat[1]` |
| `dat[N]` | `dat[N+1]` |
| `dat[N:M]` | `dat[N+1:M+1]` |
| `dat[1:0]` | `dat[2:1]` |

**down(name):**

| input | output |
|---|---|
| `dat` (bare scalar) | `dat` (unchanged — scalar is the floor) |
| `dat[0]` | `dat` (index 0 collapses back to the bare name) |
| `dat[1]` | `dat[0]` |
| `dat[N]`, N≥1 | `dat[N-1]` |
| `dat[N:M]`, both ≥1 | `dat[N-1:M-1]` |
| `dat[1:0]` (or any `[N:0]`) | **unchanged** (would create a negative endpoint) |
| `dat[2:1]` | `dat[1:0]` |

Rules, precisely:
- A **range** `[a:b]` shifts *both* endpoints by ±1, preserving the span. On **down**, if
  **either** resulting endpoint would be `< 0`, the name is left **unchanged** (a range
  never collapses; it only blocks). On **up** a range is never blocked.
- A **single** `[i]` on **down**: `i==0` collapses to the bare name; `i>0` → `[i-1]`.
- A **bare scalar** on **up** gains `[0]`; on **down** it is unchanged.
- A name ending in some *other* bracket form (neither `[int]` nor `[int:int]`) is left
  unchanged on both directions (never create a double bracket).

## Relationship to bus_thickness_scroll (ALT+wheel)

The two gestures act on the same `lab` / `name` / wire targets but differ in the
transform — **busresize WIDENS the span, bustranspose SHIFTS it**:

| | ALT+wheel (busresize) | ALT+SHIFT+wheel (bustranspose) |
|---|---|---|
| wire | thickness ±10% | no effect (tolerated) |
| text | ignored | no effect (tolerated) |
| pin/netlabel | `lab` span `[N:M]` **widened/narrowed** | `lab` index/range **shifted** ±1 |
| instance | `name` span `[N:M]` widened/narrowed | `name` index/range shifted ±1 |
| e.g. on `[1:0]` up/grow | `[2:0]` (now 3 bits) | `[2:1]` (still 2 bits) |

Both collapse a whole multi-object notch to **one undo step** via the same shared applier
(`busresize::apply_changes`: one `push_undo` → `setprop -fast` per change →
`recompute_inst_bbox` per instance → one `redraw`). An all-no-op gesture pushes no undo
step.

## Selection handling

Iterate `xschem objects -selected`; only `instance` objects are acted on (label/pin →
`lab`, else → `name`); `wire`, `text` and any other type are skipped (tolerated).

## Extensibility / C changes (already in place; ids renamed in v2)

- Two registered actions **`edit.transpose_up_selection`** /
  **`edit.transpose_down_selection`** (Tcl-backed `bustranspose_apply up|down`), listed in
  `action_id_mutates`. (v1 ids were `…_grow_selection` / `…_shrink_selection`.) Like the
  busresize sibling they ship **UNBOUND** and have **no `actions.csv` row** — the C
  `action_registry[]` help string is their only metadata; `cadence_style_rc` is what binds
  them.
- **Wheel dispatch (`handle_mouse_wheel`)** already routes any multi-modifier combo
  (Alt+Shift, …) to the canvas bind table via exact lone-modifier matching — unchanged.
- `cadence_style_rc` binds `alt+shift` wheel up/down to the two transpose actions; a user
  re-homes with one `xschem bind` line.

## Files

- `utils/bus_transpose.tcl`: `bustranspose::up_name` / `down_name` (now handle ranges,
  reusing `busresize::_split` for `[a:b]`) + the `bustranspose_apply up|down` entry point
  (reuses `busresize::is_label_type` / `apply_changes`).
- `src/callback.c`: two `action_registry[]` rows + `action_id_mutates` (ids + commands).
- `src/cadence_style_rc`: the alt+shift binds (no `actions.csv` row — ship unbound).
- `tests/bus_transpose.tcl`: the pure transform across all cases above (incl. ranges) +
  integration through `bustranspose_apply up|down`.

## Test

`tests/bus_transpose.tcl` (headless): the pure transform for every row of both tables
above (bare, `[0]`, `[N]`, `[N:M]`, the `[N:0]` down floor, the `[1:0]` no-negative
block); plus integration — up/down a net-label `lab` and an instance `name` (including a
range) through `bustranspose_apply` over a real selection; a selection that also contains
a wire and text is tolerated (those unchanged); a multi-object notch is one undo step. The
ALT+SHIFT-wheel chord + live redraw are GUI-verified via synthesized wheel events.
