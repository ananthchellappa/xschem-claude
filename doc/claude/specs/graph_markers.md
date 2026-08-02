# Cadence-style waveform markers

Status: SHIPPED, 2026-07-28.
Origin request: `references/cadence_style_waveform_markers.md`.
Related: `doc/claude/specs/waveform_viewer_modes.md` (the viewer's other LMB
gestures — strip reorder §12, trace drag §13, undo §14),
`doc/claude/specs/waveform_viewer.md` (the viewer's shipped UX contracts),
`doc/claude/code_analysis/waveform_subsystem_reference.md` (subsystem map;
landmines 1, 6, 11, 18, 19, 20, 31–40 all bear on this),
`src/draw.c`, `src/callback.c`, `src/scheduler.c`, `src/move.c`, `src/paste.c`,
`src/actions.c`, `src/wave_viewer.tcl`.

## 1. What this adds

A **marker** is a durable annotation on a graph: an **anchor** pinned to one
*sample* of one *trace*, a **leader line**, and a **text callout** reading out
that sample. A second flavour carries a **delta block** — Δx, Δy and the slope
against a partner marker, which may live in a different strip.

Markers live in a new `markers` token on the graph `xRect`'s `prop_ptr`, so they
ride save/reload, copy/paste, undo and SVG/PNG export for free — no file-format
change, exactly like every other graph attribute. They are rendered inside
`draw_graph()` under **flags bit 8 (content)**, never bit 16 (UI chrome), because
a printed or exported schematic *must* carry the user's annotations even though
it must not carry the target-strip bar or the reorder grip.

They work identically on an **on-canvas schematic graph** and in the **ASE
waveform viewer**. Creation, hit-testing and dragging are all in C — only C holds
the plot transform and the raw arrays — and the viewer learns about every change
through a **push hook from C into Tcl** (§8).

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| D1 | Where markers live | The graph rect's `markers` prop token. Not a side table, not a new object type. |
| D2 | What the anchor identifies | A **sample**: `(node index, real dataset, absolute point)` plus the **cached** `x`/`y`. Both are stored; §5 says why. |
| D3 | Create keys | `m` = plain marker, `d` = marker + delta block against the most recently created marker. The measurement tooltip **moves from `m` to `M`**. |
| D4 | Delete | Click a marker to **select** it, then `Delete` while the pointer is over that strip. Plus `xschem graph_marker delete`. |
| D5 | Label offset space | A **fraction of the plot box** (§4). Not screen pixels, not world units, not data units. |
| D6 | Read-only buffers | A marker is durable **content**, so every mutating path refuses one — but the gate is **`graph_marker_ro_refuse()` inside the mutating primitives** (`draw.c`), *not* `readonly_block()` in the key arms, and the refusal is a **non-modal `ciw_echo`**, not a modal. The verb surface keeps its own, separate `scheduler_readonly_reject()` on every `xschem graph_marker` sub-verb except `select`, `list` and `text`. The ASE viewer — readonly for its whole life by construction — gets through the one way every other viewer mutation does: `key_filter` forwards `m`/`d`, and `strip_drag_release` forwards the marker-drag **release**, inside `wviewer::with_edit`. §6.6. (⚠ `Delete` was a third forwarded key until issue 0176; it is now handled entirely Tcl-side and needs no bracket.) |
| D7 | Dirty / undo | Create, delete and drag-**commit** each do `push_undo()` + `set_modify(1)`. Mid-drag motion does neither. This deliberately **diverges** from every other graph write (landmine 19). |
| D8 | Rendering source | The **cached** `x`/`y` only — the renderer never touches `xctx->raw`. The **label** is built from the *record* the renderer is about to draw, not re-derived from its number, so a live drag reads out the sliding sample (§6.5). |
| D9 | Selection | A **SET of marker numbers**, held in `xctx` (transient, **never in the token**), each member identified by its **number alone**. `xctx->graph_marker_sel` is the **HEAD** of that set and keeps its exact old meaning, so `xschem get graph_marker_sel`, every `graph_marker select` return value and `wviewer::marker_selected` are byte-for-byte unchanged; the whole set is `xctx->graph_marker_sel_set[]` / `graph_marker_n_sel`, read with `xschem get graph_marker_sel_set`. Numbers are window-wide unique, so a number already names exactly one marker; `graph_marker_selgraph` is a **hint** for repainting, never a correctness input (§3.5). Issue 0189 widened this from one marker to a set; up to 0189 it was one. |
| D13 | Double-click on a marker | Selects it **and**, when it is a *difference* marker whose `prev` partner still resolves, the one marker its deltas are derived from. **The immediate pair only** — never the chain, and never the reverse direction (`prev` is a back-pointer and N deltas may share one reference). It **SETS** the selection: it never toggles and never accumulates. A plain marker, or one whose reference is gone, selects alone and silently. Both parts accept it (anchor and callout). Issue 0189. |
| D10 | Copy / paste | Renumber; clear all `prev` links. **Two** duplication doors, not one: `merge_box` (`paste.c`, the paste/clipboard path) and `copy_objects` (`move.c`, the `c`-key copy). |
| D12 | What gates `m`/`d` | The strip's **PLOT BOX** (`graph_plotbox_at()`), not a distance to a trace — and the sample is then the nearest one on the nearest trace *however far*, `graph_point_at(..., 1e30, -1, -1, ...)`. That is **byte-for-byte the pair of calls `draw_graph_snap_cursor()` makes**, so the marker cannot land anywhere but under the item-9 diamond: the glyph that shows *which* sample would be marked and the key that marks it are one gate, by construction. Outside the box — the legend band, either axis-number margin, the reorder grip column — no diamond is drawn (`waveform_viewer_modes.md` §15.7) and the key refuses. Trace **selection** keeps its 10-px `GRAPH_TRACE_PICK_TOL` proximity: picking a trace with a mouse is an aim, pressing `m` is a declaration. Issue 0188; until it, creation gated on a 20-px `GRAPH_MARKER_PICK_TOL` that no longer exists. |
| D11 | What a TEXT drag does | It **depends on the selection**, latched at PRESS. Unselected → move the callout (unchanged). Selected → **rigid translation**: the anchor re-snaps to a real sample on its own trace and the label offset is frozen, so the whole marker moves. `graph_marker_drag` keeps its 0/1/2 "what was grabbed" contract; a **separate** `graph_marker_dragmode` says what the gesture does. §6.2.1. |

---

## 3. The token grammar

One token, `markers`, on the graph rect's `prop_ptr`. Records separated by `\n`,
fields by a single space:

```
markers="<rec>[\n<rec>]*"

<rec>  ::= <num> <wave> <dset> <point> <x> <y> <prev> <ldx> <ldy>
<num>  ::= int  >= 1     window-wide marker number (the N in "M<N>")
<wave> ::= int  >= 0     NODE index in this graph's `node` token
<dset> ::= int  >= 0     REAL raw dataset index, never find_closest_wave's sweepvar_wrap
<point>::= int  >= 0     ABSOLUTE index into raw->values[*][]   (i.e. ofs + p)
<x>    ::= %.17g         the sample's x, UNSCALED (never mylog10'ed), FINITE
<y>    ::= %.17g         the sample's y, UNSCALED, FINITE
<prev> ::= int  >= 0     partner marker NUMBER for a delta block, 0 = none
<ldx>  ::= %.10g         label offset, FRACTION of the plot box width,  FINITE
<ldy>  ::= %.10g         label offset, FRACTION of the plot box height, FINITE
```

Example (two markers, the second a delta against the first):

```
markers="1 0 0 143 1.43e-05 0.83124999999999993 0 0.06 -0.09
2 0 0 210 2.0999999999999999e-05 1.7562500000000001 1 0.06 -0.09"
```

### 3.1 Why every field is numeric

This is a safety property, not a style choice.

* `get_tok_value`'s `SPACE()` macro treats `\n`, ` `, `\t`, `\0` and `;` as value
  terminators, so a multi-field multi-line value **must** be quoted.
  `subst_token` auto-quotes any value matching `strpbrk(new_val, ";\n \t")`, so
  the quoting is free — but `subst_token` does **not** escape an embedded `"` or
  `\`, and one stray `"` silently destroys every token after it in the prop
  string.
* `tcl_hook2` **executes** any token value beginning with `tcleval(`.

A numeric-only alphabet makes both classes structurally impossible. The Tcl-side
predicates enforce the same alphabet with one regexp,
`^[-+]?[0-9.][0-9.eE+-]*$` — which also rejects the *letters* of `nan` and `inf`.

**Non-finite values are excluded at the source**, not just filtered on read.
`SPICE_DATA` is `double`, so a sample can be `nan`/`inf` and `%.17g` would print
those letters — outside the alphabet, and a whole-token validator would then
silently wipe every marker on the strip. So `graph_marker_add_record`,
`graph_marker_anchor_at` and `graph_marker_label_offset` all refuse a non-finite
value up front, using the C89-portable `GRAPH_MARKER_FINITE(v)`
(`(v) > -1e308 && (v) < 1e308`, false for `nan` and both infinities).

### 3.2 Why records are newline-separated

This is the `node`-token precedent exactly: one `my_strtok_r(ptr, "\n", ...)`
loop and one `sscanf` per record. A truncated or hand-edited record loses **one
line**, not the field alignment of everything after it. The parser accepts
`sscanf(...) >= 9` and **drops a short or non-finite record with `dbg(0, ...)`
while keeping the rest**.

**`GRAPH_MARKERS_MAX` (512) bounds CREATION only — the parser must never
truncate.** `graph_markers_parse()` reads every record a token carries, however
many that is. Capping on the *read* side is not a guard, it is data destruction:
every mutating op rewrites the whole token from the parsed array, so on a
hand-edited or foreign file carrying 520 records the first keystroke would
silently and irreversibly drop eight of them, with no message and nothing to
undo to. Memory stays proportional to the file, exactly like every other object
array. The cap is enforced where a *new* record is appended
(`graph_marker_add_record`, §6.3).

### 3.3 Why `x`/`y` are `%.17g` and not `dtoa()`

Every other graph token goes through `dtoa()`, which is `%.8g`. A marker's `x`/`y`
must identify the *exact* sample it was created from: 8 significant digits do not
round-trip an IEEE-754 double, so an anchor re-read after a save/load would land
on a neighbouring sample and the delta readout would disagree with the screen.
17 significant digits always round-trip a double, which is what `%.17g` requests.

Three consequences worth knowing:

* **`%g` strips trailing zeros**, so `%.17g` is *not* a fixed-width 17-digit
  spelling. The double nearest `1.43e-05` prints as `1.43e-05`; the one nearest
  `2.1e-05` prints as `2.0999999999999999e-05`. Both round-trip exactly. Assert
  on *value* round-trip, or on byte equality of a string the formatter itself
  produced — never on a hand-typed literal surviving a parse/format cycle.
* The read side is plain `sscanf("%lf")`, **never** `atof_eng`/`atof_spice`,
  which apply the SI-suffix table and would reinterpret a `%.17g` string.
* `ldx`/`ldy` use `%.10g`: they are display offsets, exactness is meaningless,
  and a shorter token stays readable.

**The Tcl side never re-formats a double.** `wviewer::markers_decode` keeps
`x`/`y`/`ldx`/`ldy` as the *strings* it read and `wviewer::markers_encode`
re-emits **those strings verbatim** — no `format`, no `expr`. Tcl's default `%g`
is 6 significant digits and would silently truncate the cached sample the first
time a trace was dragged between strips.

### 3.4 Forward tolerance

The C parser reads the first nine fields and ignores the rest of the line.
`wviewer::markers_decode` carries any 10th+ field in an `extra` key and
`markers_encode` re-emits it, so `encode(decode(s))` is byte-identical even for a
record a future version widened.

### 3.5 What is *not* in the token

**Selection.** It is UI state, not content: saving it would mean a reloaded
schematic opens with a marker mysteriously highlighted. It lives in
`xctx->graph_marker_sel` (the **HEAD** of the selection, a marker **number**,
`-1` = none), `xctx->graph_marker_sel_set[GRAPH_MARKER_MAX_SEL]` +
`xctx->graph_marker_n_sel` (the **whole set**, head first, in selection order —
issue 0189) and `xctx->graph_marker_selgraph` (the rect index that owned the
head *at selection time*).

⚠ **This is deliberately NOT the issue-0175 trace model, and "mirror 0175" is
the wrong instinct here.** Trace bold *is* per-rect render state carried in the
`hilight_wave` token, which `sel_waves` extends. Markers have no such head
token to extend: the marker analogue of `hilight_wave` is a **session field**.
So the set stays in `xctx` at every size, `clear_drawing()` resets it, and **no
prop_ptr byte changes under any selection**, one member or two.

The invariants, enforced in the ONE writer `graph_marker_select_set()`:
`n_sel == 0` ⟺ `sel == -1`; `n_sel >= 1` ⟹ `sel == sel_set[0]`; no duplicates,
no entries `<= 0`, capped at `GRAPH_MARKER_MAX_SEL` (8, C-only, nothing to
mirror in Tcl — Tcl reads the list from the getter). Order is **selection
order**, not ascending: the head is the marker the user acted on, and it drives
`selgraph`, the `Delete` scope gate and the unchanged getter.

**The number alone identifies each member.** Numbering is window-wide and
unique, so a number already names exactly one marker; `selgraph` is a **rect
index**, and a rect index goes stale the moment a strip is reordered or a
multi-plot batch prepends one. So the renderer tests **set membership by number**
(`graph_marker_is_selected(m.num)`) and nothing else — which is also what lets a
cross-strip pair render selected on two different bands — and the `Delete` gate
**re-resolves** the owning strip of the **head** with `graph_marker_find()`
before comparing it to `graph_master`. Reading `selgraph` as truth put the ring
on one strip and fired the delete from another. It survives only as the repaint
hint `graph_marker_release()` uses to decide whether a redraw has to cover more
than the master strip (§7.4).

**Every "is this marker selected" test goes through
`graph_marker_is_selected()`** — never a bare `== xctx->graph_marker_sel`. There
are four such sites (the renderer, the rigid-drag latch, the click toggle, and
the delete's drop-from-the-set), and a missed one renders a selected partner in
the unselected style with no leg that selects a single marker able to see it.
The only sanctioned bare readers of the HEAD are the getter
(`scheduler.c`), the `Delete` strip-scope gate and the repaint-scope hint
(`callback.c`), plus the writer's own body. Asserted at SOURCE level by `MS13`
in `tests/headless/test_wave_markers.tcl`.

**And it dies with the document.** `clear_drawing()` (`actions.c`) resets `sel`,
`selgraph` and all four drag fields, because the *same* `xctx` is reused by
`xschem clear`, File>Open in the tab, `xschem load` and the disk-undo reload: a
surviving selection latched onto whatever marker in the **new** document
happened to carry that number — M1, i.e. the common one — drawing a ring nobody
asked for and letting `Delete` destroy it. The cost is that an ASE `regenerate`
(which is `xschem clear_drawing` + re-place, §8) also drops the selection. That
is the right trade: a regenerate rebuilds every rect from the model, so "the
selection survives it" was never more than an accident of storage.

The full transient set is `graph_marker_sel`, **`sel_set`**, **`n_sel`**,
`selgraph`, `drag`, **`dragmode`**
(§6.2.1), `dragnum`, `draggraph`, `moved`, `press_x`/`press_y`, `ldx0`/`ldy0`,
**`x0`/`y0`** and `scratch`. Note it has **two** reset classes, which predates
this work: the gesture-state half (`n_sel` — issue 0189 — plus `drag`,
`dragmode`, `dragnum`, `draggraph`,
`moved`) is reset at all three sites — `graph_marker_drag_clear()`,
`clear_drawing()`, `alloc_xschem_data()` — while the press-time *payload*
(`ldx0`/`ldy0`, `x0`/`y0`, `scratch`) is reset at none of them, and is safe only
because every read of it is gated on the gesture state the press writes last.
A new field belongs in whichever class it is; do not assume one rule.

**The live drag.** A drag writes into `xctx->graph_marker_scratch` and the
renderer substitutes that record for the stored one until the release commits.
The alternative — `subst_token` per motion event, which is what the cursor drags
do — would mean either an undo point per motion event or no undo at all, plus an
allocation per event, plus a saved original for ESC. The scratch gives one undo
point per gesture, zero allocations per motion, and ESC-cancel as a single flag
clear.

---

## 4. Why the label offset is a fraction of the plot box

`ldx`/`ldy` are dimensionless fractions:

```c
lx = ax + ldx * gr->w;   /* gr->w = plot-box width,  positive world units       */
ly = ay + ldy * gr->h;   /* gr->h = plot-box height, positive; world y grows DOWN,
                          * so a NEGATIVE ldy puts the callout ABOVE the anchor  */
```

| space | canvas zoom | canvas pan | viewer window resize (`regenerate` → new band geometry) | autozoom of the data range |
|---|---|---|---|---|
| screen pixels | stable | stable | **breaks** — the label keeps its absolute pixel offset while the strip halves, so the callout escapes the strip | stable |
| xschem world units | stable-in-px | stable | **breaks** — does not scale with the strip | stable |
| data units | stable | stable | stable | **breaks every time** — `regenerate` re-runs `fullxzoom`/`fullyzoom` for any `{}` range, `move_trace_in_graphs` blanks an empty destination's ranges, `fit` rewrites all four |
| **fraction of the plot box** | stable | stable | **stable** — `gr->w`/`gr->h` scale exactly with the container | **stable** — they are the *plot box*, not the data range |

The fraction form also keeps the callout consistent with the graph's own text
sizes, which are themselves derived from `gr->marginy`/`gr->h`. The drag clamps
at `|ldx|, |ldy| <= 2.0`. Default at create: `ldx = 0.06`, `ldy = -0.09` (up and
to the right).

### 4.1 The box is clamped to the PLOT box, not the container

`graph_marker_label_box()` tries four placements — `(+ldx,+ldy)`, `(+ldx,-ldy)`,
`(-ldx,+ldy)`, `(-ldx,-ldy)` — and takes the first that fits entirely inside
`gr->x1..gr->x2` / `gr->y1..gr->y2`. If none fits it takes the primary placement
and shoves it back inside by the axis overflow. An anchor outside the plot box
draws nothing at all.

Clamping to the **plot box** rather than the container is not cosmetic; it closes
two independent interaction defects:

1. **Top-margin press.** `waves_callback` sets `xctx->graph_top = 1` whenever the
   snapped pointer is above the plot box, and the `GRAPHPAN` **routing latch** is
   gated on `!xctx->graph_top`. A callout in the top margin — which `ldy = -0.09`
   produces for any anchor near the top of a strip — would arm a drag that never
   latches, and `waves_selected` would then stop routing the gesture the moment
   the pointer left the strip. (Reference landmine 36; §7.3 is the second half of
   the fix.)
2. **Reorder grip collision.** `wviewer::strip_handle_at_pixel` claims the right
   `GRAPH_REORDER_HANDLE_W` (14) screen pixels of the **container** over the full
   band height. A callout clamped to the container right edge would sit exactly
   there and kill the ASE strip-reorder grip.

Because `gr->x2 = gr->rx2 - gr->marginx * 0.35` with `marginx = rw * 0.14`, the
plot box's right edge is inset ~4.9 % of the strip width — comfortably more than
14 px for any strip wider than ~285 px. Narrower strips are covered by an
explicit second guard (§7.2). The callout **padding** (§6.4) eats into that
inset, so the crossover width moves up by twice the pad; the C-side guard is
what actually holds the line.

**The clamp is now belt over braces, and it is worth knowing which is which.**
Applying the pad *after* the shove instead of before it puts the padded box back
outside the plot box — but neither defect above actually reappears, because both
are independently defended in C: the `GRAPHPAN` latch at §7.2 rung 9 already ORs
in `graph_marker_drag`, so a marker press latches even in the top margin *by
design*, and `graph_marker_press()` declines the grip column outright before it
ever hit-tests. Getting the pad order wrong is therefore a **visual** defect —
the callout overhangs into the axis-number margin, and in the grip column it is
drawn where it cannot be clicked. Stated because it is also the reason **no test
leg goes red for it**: the suite asserts the token and the hit-test seam, and
this is neither.

---

## 5. Anchor identity vs cached value

Each record carries **both** the identity `(wave, dataset, point)` and the cached
`(x, y)`, and they are used for different things.

**The renderer uses the cached `x`/`y` only.** It never touches `xctx->raw`. All
three consequences are deliberate:

* No `plot_raw_custom_data()` re-run per redraw. The expression scratch column
  `raw->values[raw->nvars]` is **global and volatile**, so re-deriving `y` at
  draw time would read whatever another trace's expression last left there.
* Rendering is a pure function of the token — a marker never silently jumps
  because a re-simulation changed the sample grid.
* A marker still draws when the raw is unloaded. It is durable annotation, not a
  live probe.

**The identity drives the drag and the remaps.** `graph_point_at(...,
restrict_wave, restrict_dataset, ...)` re-snaps along the *same* trace and the
*same* dataset; the ASE node-index remaps (§9) rewrite `wave` when the model
moves traces around.

Because the value is cached, `graph_marker_at()` deliberately **drops**
`graph_wave_at()`'s `if(!xctx->raw || sch_waves_loaded() == -1)` prologue. If it
inherited it, a schematic opened without its raw would carry permanently stuck
annotations: unselectable, undraggable, undeletable. A *label* drag needs no raw
at all; an *anchor* drag calls `graph_point_at`, which has its own raw gate and
simply declines — the marker stays put, which is correct.

**Trade-off, stated:** a marker does **not** follow a re-simulation. If "markers
track the latest run" is ever wanted, add an explicit `xschem graph_marker
resnap` verb (§11) rather than making every redraw re-derive.

### 5.1 Both paths must switch to the graph's OWN raw

There are two ways into the data, and they have to agree:

* the **pixel** path — `graph_point_at()`, which previews an anchor drag;
* the **data** path — `graph_marker_sample()`, which resolves
  `(wave, dataset, point)` to an `(x, y)`.

`rawfile=` / `sim_type=` are **graph-level** tokens, so a window can hold strips
reading different raws while `xctx->raw` points at only one of them.
`graph_point_at()` has always hoisted the `extra_rawfile()` switch above its
node loop; `graph_marker_sample()` did not, and read whatever raw happened to be
current. On a multi-raw graph that is not a cosmetic mismatch: the drag
**previewed** samples from the graph's own raw and then **committed** values
read out of a different one — measured as `add_at` storing raw B's value where
the graph's raw A held a different one (the committed reproduction is
`test_wave_markers.tcl` MF4: A `v_x = vsweep*10`, B `v_x = vsweep+1`, so point 5
is 5 in A and 1.5 in B, and the pre-fix code stored 1.5) — or silently failed
when the node name is absent from the
current raw. `graph_marker_release()` commits **every** anchor drag through
`graph_marker_sample()`, so this was on the main path, not an edge case.

`graph_marker_sample()` now performs the same switch (same `autoload` decode,
same `sim_type` fallback) and unwinds it with a single — and **conditional**,
§5.2 — `extra_rawfile(5, ...)` on the way out: one level, once, because the
switch is hoisted out of any loop. That is bug 3 of §11's pre-existing list,
applied to the marker path.

**And it BAILS when the switch fails.** `extra_rawfile()` returning 0 means the
graph's `rawfile=` did not resolve; `graph_marker_sample()` then `goto done`s
with `ok = 0` instead of falling through and reading the sample out of whatever
raw is current. The pixel path already behaved that way — `graph_point_at()`
sets `valid_rawfile = 0` and skips every node — and the two must agree, or a
marker on an unresolvable graph would preview nothing while the data path
happily committed a value from a different dataset.

### 5.2 The restore is conditional — `extra_rawfile(5)` is a SWAP, not a pop

Both paths guard the unwind with a local `switched` flag and call
`extra_rawfile(5, ...)` **only if the switch actually took**.

Mode 5 is not a stack pop. `save.c` implements it as
`tmp = extra_idx; extra_idx = extra_prev_idx; extra_prev_idx = tmp;` — a plain
**swap** of the current and previous slots. So an *unpaired* mode-5 call does not
"return to where we were", it silently repoints `xctx->raw` at the previous raw
and leaves it there. Measured: a pure hover query (`graph_point_at`) on a graph
whose `rawfile=` does not resolve flipped `xctx->raw` on **every single call** —
so moving the mouse across such a strip toggled the session's current raw once
per motion event.

`graph_point_at()` is the one that made this reachable: it synthesises a
`custom_rawfile` from `xctx->raw->rawfile` when the graph carries no `rawfile=`
token, so it *attempts* a switch on essentially every call and the unwind cannot
be unconditional. Reference doc landmine 40.

---

## 6. UX contract

### 6.1 Keys (pointer over a graph)

| key | before | now |
|---|---|---|
| `m` | measurement tooltip (`graph_flags ^= 64`) | **create a marker** — **anywhere inside the strip's PLOT BOX**, at the sample the item-9 diamond snap cursor has snapped to (D12, issue 0188) |
| `d` | fell through to the canvas `deselect_mode` (there was no `ACTX_OVER_GRAPH` row) | **create a marker with a delta block** against the most recently created marker — same plot-box gate, same snapped sample |
| `M` (Shift+m) | broken — no waves guard, ran `readonly_block()` + the cadence schematic move | **the measurement tooltip**, relocated |
| `Delete` | deletes the schematic selection | **deletes the WHOLE marker selection** when the HEAD is selected *in the strip under the pointer* — one gesture, **ONE undo point**, however many members and however many strips they live on (issue 0189: `graph_marker_delete_selected()` pushes once and then calls a no-push `graph_marker_delete_1()` per member, each of which still self-logs its own `xschem graph_marker delete <n>` line). Otherwise unchanged. ⚠ In the **ASE viewer** this is now only ONE of two arms — see below |
| `d` **off** a graph | deselect-one mode | unchanged — this is a context split, not a key change |

`m`/`M` need no binding row: the inline `waves_selected` guards in
`handle_key_press`'s `case 'm'` / `case 'M'` route them, and adding a row would
make those guards dead code. `d` **does** get a row —
`set_input_binding(DEV_KEY, 'd', 0, ACTX_OVER_GRAPH, "graph.forward")` in
`init_input_bindings`, mirrored as `key,100,0,graph,graph.forward,` in
`src/keybindings.csv`. Off a graph `current_input_ctx` still resolves
`ACTX_CANVAS`, so deselect-one mode is byte-for-byte unchanged.

`Delete` is deliberately **not** a binding row: an `ACTX_OVER_GRAPH →
graph.forward` row would consume the key over a graph unconditionally and
silently break "select a graph rect, hover it, press Delete → the graph is
deleted". It is an inline guard at the top of `case XK_Delete:` that falls
through when `graph_marker_delete_selected()` returns 0.

#### ⚠ In the ASE viewer, Delete has TWO arms since issue 0176

`doc/claude/issues/0176-del-deletes-selection.md`. On an **on-canvas schematic
graph** everything above is unchanged, byte for byte. In the **viewer**, Delete
deletes *whatever is selected* — the selected marker, the selected TRACES
(issue 0175's selection), or **both**, as one gesture, one undo point and one
replayable log line. Deleting a trace takes its markers with it.

Two things about the marker arm that this section must not be read as
contradicting:

- **Its behaviour is unchanged, including the strip-scope test.** What changed is
  the path. `wviewer::key_filter` no longer forwards Delete to C at all; the
  viewer's own `wviewer::delete_selection_at` reproduces the
  `graph_marker_find(sel) == graph_master` scope test in Tcl
  (`wviewer::marker_graph_at` vs `wviewer::strip_at_pixel`) and the deletion is a
  MODEL edit through `markers_drop_number` — the same primitive every other Tcl
  deletion path in `wave_viewer.tcl` already uses, and the one that zeroes
  dangling `prev` links window-wide. 0176 D8 lists the four measured reasons the
  C verb is not used there (readonly rejection, a self-logged line that aborts a
  replay, a C undo push on a scratch buffer, and the `has_x`-gated notify hook).
- **The C fall-through is now unreachable from the viewer.** Because nothing is
  forwarded, `if(xctx->ui_state & SELECTION) { readonly_block(); ... }` can no
  longer be reached by a Delete in that window. Before 0176 it *was* reachable:
  the old Tcl gate tested `marker_selected >= 0` window-wide with no strip test,
  so a marker selected on a different strip forwarded, C refused on scope, and a
  modal dialog appeared over the read-only viewer.

All three mutating arms (`m`, `d`, `Delete`) are read-only gated — but **not in
the arm**. The arms call the ops unguarded; the refusal happens further down, in
`graph_marker_ro_refuse()` inside the mutating primitives, and it is a
non-blocking `ciw_echo`, never `readonly_block()`'s modal. §6.6 has both reasons.
Over a graph, `M` and `t` are not gated at all: they write session view state,
not content. (`case 'M'` still has a `readonly_block()`, but it is *below* the
`waves_selected` guard and belongs to the schematic move it falls through to.)
The `graph.forward` action row carries no `mutates` flag, so
`dispatch_input_action` does not test readonly either — on the marker path there
is exactly **one** read-only gate, and it is not in `callback.c`.

**Why the tooltip moved to `M` and not `Ctrl+m`.** `Ctrl+m` already reaches the
same arm today, but when `graph_use_ctrl_key` is 1 the arm's `access_cond`
*requires* Ctrl — plain `m` is then refused entirely and `Ctrl+m` would have to
be both the marker and the tooltip. `M` has no such collision in either mode.
`graph_flags` bit 64 and both of its teardown paths (`waves_selected`'s
leave-the-graph stop, the `<Leave>` bind) stay wired; losing the only key that
can *set* bit 64 would make the whole tooltip render block dead code.

### 6.1.1 `Ctrl-E` — Delete All Markers (ASE viewer only)

Viewer plan item 4. In an ASE waveform viewer window `Ctrl-E` removes **every**
marker from **every** strip. The graphs, the traces, the ranges and the attached
raw data are all untouched — this deletes *annotation*, which is exactly what
separates it from `Ctrl-D` (Clear All, issue 0171), the entry it sits next to in
the Graph menu (`Delete All Markers`, accelerator `Ctrl+E`).

It is **not** a graph key and **not** a binding row. It lives on the shared
`WaveViewer` bindtag, installed by `wviewer::install_default_binds`:

```tcl
bind WaveViewer <Control-Key-e> {wviewer::delete_all_markers_at %W; break}
```

Same rules as `Ctrl-D`: an rc file that binds the sequence first **wins**
(defaults are only installed for a sequence nothing has bound yet), `{break}`
disables it, `{}` does not (an empty script *deletes* the binding, which reads
as "never bound" and would be re-defaulted). `%W`, not the current context: a
key can arrive on a viewer Tk has focused before the C side switched to it.

**Three collisions, all already resolved, and all now regression-guarded**
(`tests/headless/test_wave_markers.tcl`, group `MD`):

* `cadence_style_rc:189` binds `<Control-Key-e>` on `.drw`
  (`cadence::return_one_level`) and `clone_canvas_bindings` copies it onto every
  new canvas — including the viewer's. `wviewer::strip_bindings` sweeps every
  widget-level sequence that is not in `keepseqs`, so the clone is gone before
  the tag is ever consulted. Leg MD9 asserts `bind $vdrw <Control-Key-e>` is
  empty *on a live viewer canvas*: a future `keepseqs` addition would otherwise
  silently steal the key back, and a widget-level bind is more specific than a
  tag one.
* `callback.c` `case 'e'` + `ControlMask` → `go_back(1)` is a hardcoded legacy
  switch arm, not a row. It is unreachable here because `key_filter` forwards
  only the `graphkeys` allowlist and `e` (101) is not a member (leg MD9), and
  because the tag binding `break`s.
* `key_filter` runs on the widget, i.e. *before* the tag, but it never `break`s,
  so the tag binding still fires for the keys it swallows.

**What the wrapper does, and — more importantly — what it must not do.**
`wviewer::delete_all_markers ?token?` returns the number deleted, `0` when there
was nothing to delete, `{}` + a CIW line when no viewer resolves.

* The **model** rewrite and the **undo point** both come from the push hook
  (§8): the C verb notifies **once** for the whole sweep, `marker_changed` takes
  its `dict remove $G markers` branch on every emptied strip, sets `changed` and
  pushes exactly one point. A `push_undo`/`set_graphs` in the wrapper would give
  a phantom second point and `u` would need two presses.
* The **repaint** is the wrapper's job, and only the wrapper's.
  `graph_marker_delete_all()` rewrites the props and notifies, nothing else (its
  keyboard caller, `callback.c` `case XK_Delete`, calls `draw()` itself), and the
  hook's `set_graphs` is a pure model write. Probe-measured with `-d 1` (which
  makes `draw()` log itself): **0** `draw()` calls across the whole delete
  without the wrapper's `xschem redraw`, **1** with it. Not a `regenerate` — the
  rects are already correct and a regenerate would throw away a live pan/zoom.
* The **no-op** returns `0` without repainting and **without logging**, the
  `move_strip` `from == to` rule: a drop that changed nothing must not enter a
  replay.

**The log line is rewritten, not merely mirrored.** The core self-logs
`xschem graph_marker delete -all -1`, and that line is *not replayable into a
viewer*: `scheduler.c` readonly-rejects every `graph_marker` sub-verb except
`select`/`list`/`text`, so a sourced log would hit a `TCL_ERROR` and **abort**
rather than warn. So the wrapper brackets the verb in
`xschem log_action -suppress push` / `pop` and emits one
`wviewer::delete_all_markers <token>` instead — the `clear_all` pattern. The
`pop` is **unconditional**: `with_edit` throws on a refused context switch, and
a leaked push leaves the *global* depth counter raised, silently killing the
action log for the rest of the session. Leg MD3 stages both halves in a child
process launched with `--logdir` (the suite itself runs `--nolog`, where
`util.c:493` returns before writing anything), with `xschem copy` after a
deliberately refused call as the leak canary.

### 6.2 Mouse

| gesture | result |
|---|---|
| LMB **click** on the anchor or the callout (travel ≤ `GRAPH_CLICK_TOL`, 3 px) | **select** that marker; a second click on the already-selected one deselects — *but only when it is the whole selection*. With a **pair** selected the click is disambiguating, so it **COLLAPSES** to the one clicked (the issue-0174 D3 rule for traces), and a second click then still deselects (issue 0189) |
| LMB **double-click** on the anchor or the callout | **select that marker and, for a difference marker, the reference its deltas are derived from** — the immediate pair only. It **SETS**: a repeat double-click leaves the same pair selected, and the first click's ordinary single-select still happens and is then widened. The `-3` arm poisons `graph_press_x/y` first, so the trailing release cannot also wave-bold (issue 0189, D13) |
| LMB **click** on empty graph space | **deselect** (see below) |
| LMB **press-drag-release on the ANCHOR** | slide the anchor **along its own trace, within its own dataset**, snapping to real samples |
| LMB **press-drag-release on the TEXT**, marker **not selected** | move the callout; the anchor does not move |
| LMB **press-drag-release on the TEXT**, marker **selected** | **the whole marker translates** — the anchor re-snaps along its own trace and the label keeps its offset (§6.2.1) |
| **ESC** mid-drag | cancel — the scratch is dropped, nothing is committed, nothing is logged |
| non-Button1 release while a drag is armed | abort the arm (see §7.2, RELEASE rung 1) |

The press only **arms**; the **release** decides, using the same travel test as
the issue-0152 wave-bold. Below the threshold `graph_marker_drag_to()` does
nothing at all, so a 1-px jitter never visibly re-snaps the anchor only to be
discarded as a click.

Deselecting on a miss is load-bearing, not tidiness: the selection is
window-wide, so a stale one would let a later `Delete` over any strip eat
the marker instead of the schematic selection. The full lifetime is: **set**
by a no-travel release on a marker, by a double-click (which sets the *pair*)
and by `xschem graph_marker select -pair|-set`; **cleared** by a press over a
graph that hits no marker, by a second click on the sole selected marker, by
`graph_marker_delete` of that number (which drops just that member), by `graph_marker_delete_all` when it removed anything, by
`xschem graph_marker select -none`, by `clear_drawing()` — i.e. by any document
swap and by every ASE `regenerate` (§3.5) — and (viewer-side) by `clear_all` and
`forget`.

A press that only **deselected** is reported separately from a press that armed
a drag, because the erased ring may be on a *different* strip than the one under
the pointer: `graph_marker_press()` returns `-1` for it and `waves_callback`
turns that into `need_all_redraw` (§7.4).

### 6.2.1 The selected TEXT drag — a rigid translation

Selecting a marker turns its callout into a handle for the **whole** marker.
Dragging the text of a *selected* marker moves the anchor too; dragging the text
of an *unselected* one is unchanged. One click is the entire difference, and it
is reversible in one click.

**The projection rule, stated explicitly**, because the pointer is over the
*label*, not near the trace, so the anchor cannot chase it directly:

> The anchor **target** is the pointer position **minus the constant
> press-to-anchor vector latched at press** — i.e. where the anchor would be if
> the whole marker translated with the hand. That target is then snapped by
> `graph_point_at(gi, …, 1e30, restrict_wave, restrict_dataset, &hit)`, the
> **same** point-to-segment nearest-sample rule a direct anchor drag uses,
> restricted to this marker's own wave and dataset. `ldx`/`ldy` are **frozen**
> at their press values, so the callout keeps its offset and follows.

This is deliberately **not** a strict x-projection of the pointer onto the
trace, and the reason is not taste:

* with `ldx`/`ldy` frozen, x-projection would make a purely **vertical** text
  drag move nothing at all — the marker would sit dead under the pointer;
* it would introduce a **second** snapping rule, different from the one the
  direct anchor drag already ships, in the same feature.

On a locally shallow trace — most of a waveform — translate-then-snap *is* the
x-projection. The two differ only on a steep segment, and there following 2D
proximity is exactly what a direct anchor drag does too.

**The mode is LATCHED AT PRESS, never re-read at release.** Two independent
reasons: the renderer previews the mode on every motion event through the
scratch, so it must be knowable during the drag; and a release that re-read the
selection would change the meaning of a gesture the user had already
half-performed (`graph_marker_select` is pure UI state, so a script or a second
window can legitimately move the selection mid-drag). Tests `MX7g`/`MX7h` do
exactly that, in both directions, and are the legs that fail if the latch is
replaced by a release-time read.

**`part` is no longer sufficient at the commit**, so there are now two fields:

| field | meaning | who reads it |
|---|---|---|
| `xctx->graph_marker_drag` | what was **grabbed** — 0 none, 1 anchor, 2 label | `xschem get graph_marker_drag`, `wviewer::marker_grabbed`, `wviewer::strip_drag_release`'s `with_edit` bracket, and ~27 test assertions. **Contract unchanged.** |
| `xctx->graph_marker_dragmode` | what the gesture **does** — `GRAPH_MARKER_MODE_NONE`/`_ANCHOR`/`_LABEL`/`_RIGID` | C only: `graph_marker_drag_to()` and `graph_marker_release()` |

A selected text drag is `drag == 2`, `dragmode == RIGID`. Keeping the two apart
is what leaves every Tcl seam byte-for-byte unchanged — neither production
reader distinguishes 1 from 2 (`marker_grabbed` collapses to a boolean,
`strip_drag_release` tests `> 0`), but `scheduler.c`'s
`part == 1 ? "anchor" : "label"` and the test assertions on the literal `2` both
read the grabbed part and would have been wrong had the mode been encoded there.

`graph_marker_release()` commits on the **mode**: `ANCHOR` and `RIGID` →
`graph_marker_anchor_at()`, `LABEL` → `graph_marker_label_offset()`. A rigid
drag commits the **anchor only** — the offset never changed — so it is one token
write, one undo point, one notify, and the action log gets the data-addressed
`xschem graph_marker anchor <num> <dset> <point>` line for free, because the log
line belongs to whichever primitive ran.

**Stated consequence.** With no raw loaded, `graph_point_at` declines, so a
*selected* marker's text drag moves nothing. Click elsewhere to deselect, then
drag the callout. That is consistent with the shipped rule in §5 — "an anchor
drag calls `graph_point_at`, which has its own raw gate and simply declines —
the marker stays put, which is correct" — and the alternative (silently falling
back to a label move) would make the gesture's meaning depend on whether a file
happened to be loaded.

`graph_marker_dragmode` resets wherever `graph_marker_drag` does — the three
sites `graph_marker_drag_clear()`, `clear_drawing()` and `alloc_xschem_data()`.
`graph_marker_x0`/`_y0` (the anchor sample at press, which a rigid drag
translates from and which cannot be read back off the scratch because
`graph_marker_drag_to()` rewrites it on the first motion event) are press-time
*payload* rather than gesture state, and follow `ldx0`/`ldy0`: written by the
press, read only while the mode is set.

### 6.3 Refusals, all with a CIW message

* `m`/`d` with the pointer **outside the strip's plot box** — the legend band,
  either axis-number margin, the reorder grip column: *"the pointer is not
  inside the plot area of a strip"*. This is the D12 gate, and it is the only
  geometric one: inside the box there is no distance test at all.
* `m`/`d` in a strip with **nothing markable in it** — no `node` token, a
  bus-only `node` list, or a `rawfile=` that does not resolve: *"no trace to
  mark in this strip"*.
* `m`/`d` on a **digital strip**: *"markers are not supported on digital strips"*
  — a specific message so the key does not read as broken.
* At `GRAPH_MARKERS_MAX`: *"too many markers on this graph"* — the **creation**
  cap, the only place it applies (§3.2).
* A non-finite sample: *"cannot mark a non-finite sample"*.
* In a read-only buffer: *"read-only, markers cannot be edited (Edit > Make
  Editable to enable editing)"* — through the **same** `graph_marker_refuse()`
  channel as the four above, not `readonly_block()`'s modal (§6.6).

**Ordering, because it is not what you would guess.** The read-only gate sits in
the *primitives*, so on an `m`/`d` keystroke it runs **after**
`graph_marker_create()`'s digital-strip, plot-box and no-trace-to-mark tests and
**before** the cap and non-finite tests. A read-only buffer therefore answers
"markers are not supported on digital strips", "the pointer is not inside the
plot area of a strip" or "no trace to mark in this strip" when those apply, and
only says "read-only" once a real sample has been picked. That is a deliberate
consequence of gating the mutation rather than the key: the message always
describes the *first* reason the edit cannot happen, and "there is nothing here
to mark" is a truer answer than "this buffer is locked".

The **digital** test stays first for the same reason: `graph_plotbox_at()`
refuses a digital strip too, and would swallow the specific message.

Bus traces answer "no hit" for the same reason `graph_near_wave` does (their
rendering is a band, not a polyline), so they contribute no candidate to
`graph_point_at`'s ranking and `m` over a bus-only strip reports "no trace to
mark in this strip" — the second refusal above, reached from *inside* the plot
box.

### 6.4 What is drawn

Per marker, in this order: the **leader line** from the anchor to the nearest
edge of the callout; an opaque `BACKLAYER` **fill** behind the callout; the
callout **outline** (always stroked, because `filledrect` returns early both when
the global fill pattern is off — Ctrl+= — and when the box is under 3 screen
pixels on both axes); the **text**; and a ~3-px **anchor dot**. A selected
marker adds a hollow ring and doubles the stroke weight.

#### Callout padding

The callout box is the text box **inflated by a padding ring**, so the glyphs do
not touch the border. The pad is a fraction of **one text line** — not of the
whole block, or a 3-line delta callout would be padded three times as much as a
plain one — with a floor in **screen pixels** so a callout on a short stacked
strip still gets breathing room (`GRAPH_MARKER_PADX`/`PADY` and their `_MIN`
companions, `draw.c`).

It is applied **inside `graph_marker_label_box()`, immediately after every
`text_bbox()` call**, and that placement is the whole point:

* the **four-candidate fit test** must judge the padded box, or the drawn border
  overhangs the plot box;
* the **shove-back-inside** must clamp the padded box, for the same reason
  (below);
* the **hit test** gets the padded box for free, which is intended —
  `graph_marker_at()`'s label pass is an exact `POINTINSIDE` with no tolerance
  term of its own, so the pad is the *only* lever on the callout's clickable
  area, and it must be the same lever as the drawn one. Padding in the renderer
  alone is exactly the desync the shared function exists to prevent.

`lx`/`ly` are **not** touched. `text_bbox()`'s `(x,y)` names the **top-left** of
the text block (`rot=0 flip=0 hcenter=0 vcenter=0`, and `cairo_vert_correct`
defaults to 0, so `tx1 == lx` exactly), and `draw_string()` re-derives its own
box from that same `(x,y)` and never sees this one. So a **symmetric** inflation
leaves the glyphs exactly where they were and visually centres them. An
asymmetric pad would glue the text to the original corner instead.

The anchor pass of `graph_marker_at()` reads only `ax`/`ay` and runs **first**,
so a bigger callout can never steal a pixel that used to answer `anchor`.

#### Stroke weight: both states are now an explicit pixel count

`lw = selected ? 2.0 * zoom : 0.0` was wrong in a way that only showed up on the
on-canvas graph. `0.0` is **not** a zero width: `drawrect`/`drawline` take their
`else` branch and inherit the GC's *resting* width, `XLINEWIDTH(xctx->lw)`, and
`xctx->lw` is `1.125 * mooz` — which is 1 px only while `zoom >= 0.5625`.
Measured on the default config:

| zoom (wheel clicks in from fit) | unselected outline | selected outline |
|---|---|---|
| 1.0 (0) — the ASE viewer's fixed zoom | 1 px | 2 px |
| 0.482 (4) | **2 px** | 2 px |
| 0.335 (6) | **3 px** | 2 px — *inverted* |
| 0.112 (12) | **10 px** | 2 px |

So zoomed into a schematic graph the unselected outline ballooned and at
`zoom <= 0.375` it was **heavier than the selected one**, destroying the cue.
Both states now pass an explicit fixed-pixel `bus`, matching the dot and ring,
which were always fixed pixel sizes: unselected **1 px**, selected **2 px**, at
every zoom.

**1 px is the floor of this path** and a literal halving of the *selected*
stroke is not representable: `XLINEWIDTH` clamps `(int)0` to 1 whenever
`change_lw` is set, `DRAW_ALL_CAIRO` is 0 so there is no sub-pixel stroking, and
an X11 line width of 0 is the "thin line" special case (1 px, fast algorithm),
not invisible — the engine relies on that for grid dots. "Halve the weight" is
therefore delivered where the weight was actually heavy.

`GRAPH_MARKER_PX(n)` carries a **`+0.25` rounding guard**, and it is not
cosmetic. `drawrect` computes `XLINEWIDTH(bus * xctx->mooz)`, which truncates,
and `mooz` is a stored `fl(1/zoom)` rather than a symbolic reciprocal — so
`2.0 * zoom * mooz` evaluates to `1.9999999999999998` and truncates to **1 px**
for 13.9 % of zoom values (measured over a 3M-point log-uniform sweep), silently
erasing the selection cue at those zooms.

A side benefit: because both states now take the `bus > 0.0` branch, both issue
their own `XSetLineAttributes` instead of inheriting whatever the GC happened to
hold — which `set_thick_waves()` (`draw.c`) also writes, through `XChangeGC` on
`gc[wave_col]`, and `wave_col` can be layer 7, the marker colour.

#### Label font size

The callout font is `gr->txtsizey * graph_marker_textmag`, and **both** the
renderer's `draw_string()` and the hit-tester's `text_bbox()` take it from the
one helper `graph_marker_txtsize()` — they used to name `gr->txtsizex`
independently, which is a latent desync between the drawn text and the clickable
box.

The base changed from `txtsizex` to `txtsizey`, and the reason is *which clamp
binds*, not which coefficient is larger. Both sizes are clamped —
`txtsizex` by `marginy * 0.0065`, `txtsizey` by `marginx * 0.004` — and the
`txtsizex` clamp binds for every strip wider than 1.25× its height, i.e. every
realistic one. So the callout font was governed by the **bottom margin**: the
band of container below the plot box where the X-axis numbers are drawn, which
has nothing to do with a callout drawn *inside* the plot box. Measured on a
default 800×500 canvas:

| strips | `txtsizex` | `txtsizey` |
|---|---|---|
| 1 | 23.7 px | 23.3 px |
| 4 | 5.9 px | 8.9 px |
| 8 | **2.96 px — below `draw_string`'s own 3-px "too small" floor** | 4.45 px |

At eight strips the old callout was *invisible but still clickable*. The
`txtsizey` clamp stops binding at aspect ≥ 2.44, so in any stack it is exactly
1.5033× larger and saturates there; on a single tall strip the two agree to
within 1.6 %, so nothing visibly changes in the common single-strip case.

**Premise check, recorded because it was the ask**: "use the same font as the
axis numbering" was *already true* — `gr->txtsizex` is exactly what the X-axis
numbering draws with (`draw.c`, the x-label block). The callout now matches the
**Y**-axis numbering instead. `txtsizelegend` was the third candidate and is
0.75× `txtsizex` — smaller, so not a fix for this.

`graph_marker_textmag` (`set_ne graph_marker_textmag 1.0` in `xschem.tcl`, beside
`graph_marker_color`) is read with `tclgetdoublevar` and **clamped to 0.1 … 10**
in C for the same reason `graph_marker_color()` clamps: the value feeds
`text_bbox` and therefore the **hit** box, so a wild rc value would enlarge the
clickable area, not merely the glyphs. The `>=`/`<=` form of the clamp also
rejects `nan`, which fails every comparison.

"Selected" is **stroke weight, not a different layer**. It deliberately does not
use `gc[SELLAYER]`: `SELLAYER == GRIDLAYER == 2`, so a selected marker would come
out grid-coloured, and `drawgrid()` mutates that shared GC's dash style with a
reset that only runs on the grid-ON path (issue 0082). It also does not create a
new GC: `set_clip_mask` only clips `gc[i]`, `gcstipple[i]`, `gctiled` and
`gc_hilight`, so a private GC would be unclipped inside a `bbox` scope.

The colour is the Tcl var `graph_marker_color` (`set_ne graph_marker_color 7` in
`src/xschem.tcl`, next to `graph_active_strip_width`), **clamped** by
`graph_marker_color()` before use — every drawing primitive indexes `xctx->gc[c]`
unchecked, so an out-of-range rc value would be an out-of-bounds read.

### 6.5 Label text

**The label is built from the RECORD, never re-derived from the number.**
`graph_marker_text_rec(rec, gi, pool, npool, dest, size)` is the core;
`graph_marker_text(num, dest, size)` is a thin by-number wrapper over it, kept
for the `xschem graph_marker text` verb and the tests.

The split is not tidiness. The renderer substitutes
`xctx->graph_marker_scratch` for the stored record while a drag is in flight
(§3.5), and the stored token is deliberately **not written until the release**.
A number-keyed formatter re-reads that stored token — so an **anchor drag** slid
the dot across the trace while the callout stayed frozen at the pre-drag `x`,
`y`, `Δx`, `Δy` and slope for the whole gesture. The readout is the entire
reason a marker exists; a marker whose readout does not follow its anchor is
worse than no live preview at all. Passing the record makes the drag preview and
the committed value the same code path by construction.

The rendered form is:

```
M<N>:<x>,<y>
```
plus, when `prev >= 1` and the partner resolves:
```
Δx:<dx>,Δy:<dy>
slope:<dy/dx>
```

`dx = m.x - partner.x`, `dy = m.y - partner.y` (older marker → newer).
`dx == 0.0` (exact compare — both operands are exact doubles read from the raw)
gives `slope:undef`. If the partner cannot be found the delta block is omitted
and the marker renders as a plain callout, which is exactly what makes the
dangling-`prev` sweep of §9 necessary: the degradation is silent.

The partner is resolved out of the caller's **pool** when one is supplied
(§10.1, "One parse per operation") and by a `graph_marker_find()` full-window
scan only when it is not — the by-number wrapper's one-off case.

Values are engineering-formatted with **`ev_precision`, matching the measurement
tooltip, not `draw_cursor`.** `draw_cursor`/`draw_hcursor` hardcode
`dtoa_eng(v, 5)` on their plain branch and only consult `ev_precision` on the
`unit != 1.0` branch; the tooltip uses `ev_precision` on both. A marker is a
readout of a value the user explicitly asked for, so it follows the tooltip.
**This is a documented, deliberate divergence from the cursor label.**

Two implementation constraints worth not rediscovering:

* `dtoa_eng` returns a shared `static char[80]`, so every value is staged into
  its own local *before* assembly. `sprintf(out, "M%d:%s,%s", n, dtoa_eng(x,p),
  dtoa_eng(y,p))` prints the same number twice and which one is unspecified in
  C89. The delta block needs **five** staged copies.
* `graph_marker_text_rec()` is a **query** and must not write
  `xctx->ev_precision` (which `draw_graph` owns). It takes a local
  `prec = tclgetintvar("ev_precision")`, defaults to 5, and clamps to 17 so
  `graph_marker_fmt`'s 80-byte buffer cannot overflow. For the same reason it
  reads `logx`/`unitx`/`unity` **off the rect** rather than through a scratch
  `setup_graph_data` (landmine 37).

The Greek delta is `GRAPH_DELTA_STR`, `"\316\224"` (UTF-8 U+0394) under
`HAS_CAIRO==1` and `"D"` otherwise, keeping the source pure ASCII. The
vector-font path is definitively broken for this: `draw.c`'s non-cairo string
path replaces every byte `> 127` with `'?'` *independently*, so `Δ` renders as
`??`, and `text_bbox_nocairo` counts bytes as character cells so the box comes
out one cell too wide. This tree builds with `HAS_CAIRO 1`; the `#else` arm
exists so a cairo-less build degrades to ASCII instead of garbage.

### 6.6 Read-only: a marker is CONTENT, so it is refused

A marker must be refused in a read-only buffer. This is the opposite of the
neighbouring graph writes — `hilight_wave`, cursor positions, pan/zoom ranges —
and deliberately so: those are view state, a marker is durable annotation that
ends up in the file.

Letting it through was not a lenient choice, it was an **untakeable-back** one.
`set_modify(1)` is `ro_suppress`ed in a read-only buffer and `push_undo()` is
skipped outright, so the edit landed, carried **no undo point**, and `xschem
undo` is *itself* readonly-rejected. The user got a permanent change to a buffer
they had explicitly opened read-only, with no way back short of reloading.

#### The gate is in the PRIMITIVES, and it is NON-MODAL

`graph_marker_ro_refuse()` (`draw.c`, static, immediately above
`graph_marker_add_record`) is **the** read-only gate for markers and the only
one on the interactive path:

```c
static int graph_marker_ro_refuse(void)      /* 1 = refuse */
{
  if(!xctx || !xctx->readonly) return 0;
  graph_marker_refuse("xschem: read-only, markers cannot be edited "
                      "(Edit > Make Editable to enable editing)");
  return 1;
}
```

An earlier round put `readonly_block()` at the top of the `m` / `d` / `Delete`
key arms instead. Both halves of that were wrong, for independent reasons:

1. **`readonly_block()` pops a MODAL.** A modal raised from a *keystroke*
   deadlocks any script that drives the refusal path — the marker test suite
   under a real `$DISPLAY` hung forever on the first read-only leg, waiting for
   a button nobody was there to press. Every other marker refusal ("no trace
   near the pointer", "digital strips", the cap, non-finite) already used the
   feature's own non-blocking channel, `graph_marker_refuse()` → `ciw_echo`;
   the read-only refusal now uses it too, so the whole family is consistent
   *and* scriptable.
2. **The key arms do not cover the DRAG-COMMIT path.** A label or anchor drag
   commits through `graph_marker_release()` → `graph_marker_anchor_at()` /
   `graph_marker_label_offset()` → `graph_marker_update()`, which reaches **no
   key arm at all**. With the gate in the arms, a *mouse* gesture could still
   permanently edit a read-only buffer — with no undo point, for exactly the
   reason above. Moving the test into the primitives closes the mouse door and
   the keyboard door with one branch, and closes any future door by
   construction.

**The four call sites**, all in `draw.c`:

| primitive | what it gates |
|---|---|
| `graph_marker_add_record()` | every create — both `graph_marker_create()` (pixel, the `m`/`d` keys) and `graph_marker_create_at()` (data-addressed, the verb and the action log) |
| `graph_marker_update()` | every record rewrite — `graph_marker_move()`, `graph_marker_anchor_at()`, `graph_marker_label_offset()`, i.e. **the whole drag-commit path** |
| `graph_marker_delete_1()` | the single delete engine, hence the public `graph_marker_delete()` (`push` 1) and every member of `graph_marker_delete_selected()` (`push` 0), i.e. the `Delete` key. `graph_marker_delete_selected()` **also** refuses once up front, so a read-only multi-delete gets ONE CIW line, not one per member (issue 0189) |
| `graph_marker_delete_all()` | `delete -all`, whole-window or per-strip |

**Three mutating helpers are deliberately NOT gated**, and the reason is in each
case that a gate there would be either unreachable or wrong:

* `graph_marker_clear_prev_n()` (and its `graph_marker_clear_prev()` wrapper) —
  reachable **only** from `graph_marker_delete()` / `graph_marker_delete_all()`,
  both of which already refused above it. A second test would be dead code, and
  a *reachable* one would be a bug: the sweep must always complete once the
  delete it belongs to has been allowed, or the window is left with dangling
  `prev` links.
* `graph_marker_renumber_rect()` — called from `merge_box()` (`paste.c`) and
  `copy_objects()` (`move.c`), i.e. during a paste or a copy, which are
  **gated higher up** by the ordinary editor read-only enforcement. By the time
  it runs, a rect has already been cloned into the document; refusing to
  renumber it there would leave duplicate marker numbers, which is strictly
  worse than the paste that should never have happened.
* `graph_marker_select()` / `graph_marker_select_set()` /
  `graph_marker_select_pair()` — pure UI state (§3.5): no token write, no
  `push_undo`, no `set_modify`, and no `log_action` either (trace selection does
  not log, `waveform_viewer_modes.md` §15; the replay-critical marker operations
  already name explicit numbers). Selecting and deselecting a marker in a
  read-only buffer is correct and must keep working, or `Delete` could not even
  report *why* it refuses — and it is what lets the read-only ASE viewer
  pair-select on a double-click with no `with_edit` bracket at all.

#### The ASE viewer still works

It is readonly for its whole life by construction and has always mutated through
one bracket, `wviewer::with_edit` — readonly 0, run, `set_modify 0`, readonly 1.
Two seams open it for markers:

* **`wviewer::key_filter`** forwards exactly two keysyms (`109` `m`, `100` `d`),
  **KeyPress only**, inside `with_edit`. Everything else
  it forwards (`a b s M t A B`, cursors, the tooltip) writes only view state and
  goes raw, as before. KeyRelease is excluded because it is a no-op in the C
  dispatcher and a second `with_edit` cycle per keystroke is pure waste.
  ⚠ `65535` `Delete` was the third until issue 0176. It is no longer forwarded
  on any path and therefore needs no bracket: it reaches no C mutation verb — it
  deletes through the viewer's own model edit (`waveform_viewer_modes.md` §16).
* **`wviewer::strip_drag_release`** forwards the `<ButtonRelease-1>` inside
  `with_edit` **when — and only when — `xschem get graph_marker_drag` > 0**,
  because that is the release the drag commits on (§7.3).

`with_edit` **errors loudly** on a refused context switch, which inside a Tk
binding must not propagate, so both calls are `catch`ed and reported through
`ciw_echo`.

This is why D6 no longer needs the "no flag distinguishes a readonly viewer from
a readonly descend" escape hatch: the viewer identifies itself by *being the
thing that opens the bracket*, not by a flag the C side has to read.

#### The verb surface is a SEPARATE, and stricter, gate

`xschem graph_marker <sub>` is rejected in `scheduler.c` by
`scheduler_readonly_reject()` before it ever reaches a primitive, for every
sub-verb except `select`, `list` and `text`. That one **fails LOUD**
(`TCL_ERROR`), matching the rest of the verb surface, where a caller can see and
handle an error. The two gates are independent and both are wanted: a script
should get an exception, a keystroke should get a status line. The viewer
defeats both through the same `with_edit`.

---

## 7. Interaction — the full Button1 precedence

### 7.1 The routing gate (unchanged)

`waves_selected()` (`callback.c`) decides whether an event reaches the graph at
all. It **skips** on a pending schematic gesture
(`STARTZOOM|STARTRECT|STARTLINE|STARTWIRE|STARTPAN|STARTSELECT|STARTMOVE|STARTCOPY`),
on `graph_use_ctrl_key && !Ctrl && !GRAPHPAN`, on Alt, and on Shift+Button1. It
is **side-effectful**: it sets/clears `graph_master`, sets the `tcross` cursor,
and stops the measure tooltip.

`GRAPHPAN` is **not a pan** here — it is the *routing latch*. Two things depend on
it for a marker drag: `waves_selected`'s
`check = (ui_state & GRAPHPAN) || POINTINSIDE(...)` keeps the drag routed after
the pointer leaves the strip, and `if(!(ui_state & GRAPHPAN)) graph_master = i;`
**freezes `graph_master`**.

### 7.2 On-canvas schematic graph

**PRESS (Button1)** — `waves_callback`:

| rung | what | after the change |
|---|---|---|
| 0 | `waves_selected` | routes or skips; unchanged |
| 1 | seeds `graph_press_x/y` | **+ `graph_marker_drag_abort()`** — the stale-arm teardown, §7.4 |
| 2 | measurement tooltip render (bit 64) | unchanged |
| 3 | `if(ui_state & GRAPHPAN) goto finish` | not taken on a fresh press |
| 4 | latch `graph_top`/`graph_left`/`graph_bottom` | unchanged |
| **5** | **`graph_marker_press(i, gr, r)`** | declines the grip column, else arms an anchor/label drag and nukes `graph_press_x/y`; **consumes rungs 6–8**. Three-valued: `1` armed · `-1` only **deselected** (falls through, but forces `need_all_redraw`) · `0` not ours |
| 6 | cursor / hcursor grab (four independent tests, 10-unit tolerance) | now the `else` of rung 5 |
| 7 | Button3 numeric cursor set | not Button1 |
| 8 | `a` / `b` / `s` / `M` / `m` / `d` / `t` keys | now in the same `else` chain |
| 9 | `GRAPHPAN` latch | now `(!graph_top \|\| graph_marker_drag)` — **runs after a marker press even in the top margin, by design** |

**DOUBLE-CLICK (`event == -3`, Button1)** — a separate rung in the same
`else` chain, reached only when rung 5 did not arm (a `-3` is never a
`ButtonPress`, so `mkpress` is 0 by construction):

| rung | what | after issue 0189 |
|---|---|---|
| 1 | poison `graph_press_x/y` with `-1e30` (issue 0152) | unchanged — and it is what stops the trailing release wave-bolding under the double-click |
| **2** | **`graph_marker_at(i, mx, my, GRAPH_MARKER_TOL, &part)`** | **NEW.** A hit on either part → `graph_marker_select_pair()` + `need_all_redraw` (the partner may live on another strip) |
| 3 | `edit_wave_attributes(1, i, gr)` — legend → the wave dialog | now the `else` of rung 2 |
| 4 | `graph_edit_properties` | now the `else` of rung 3 |

**Marker before the dialogs is mandatory, not a preference.** A marker anchor
sits *on a trace* by construction and a callout is clamped inside the plot box
(§4.1), so without rung 2 a double-click aimed at a marker reaches
`graph_edit_properties`. Rung 2 deliberately does **not** decline the
reorder-grip column the way `graph_marker_press()` does (§7.2 press rung 5): the
grip owns no double-click gesture, and the overlap only exists on a very narrow
strip, where selecting the marker under the pointer is the right answer anyway.

`graph_marker_press()` **declines outright** any pixel with
`X_TO_SCREEN(mousex) >= gr->sx2 - GRAPH_REORDER_HANDLE_W` when
`gr->reorder_handle` is set: the ASE strip-reorder grip keeps unconditional first
refusal, in C and in Tcl alike.

It deliberately does **not** use the `event = 0; button = 0;` idiom the numeric
cursor set uses — that would also suppress the `GRAPHPAN` latch at rung 9, which
every drag needs.

**MOTION (Button1Mask):**

| rung | what | after the change |
|---|---|---|
| 1 | tooltip (bit 64) | unchanged |
| **2** | **`graph_marker_drag_to()` into the scratch** | → `need_redraw_master` |
| 3 | hcursor1 → hcursor2 → cursor1 → cursor2 move | now the `else` chain of rung 2 |
| 4 | `if(ui_state & GRAPHPAN) goto finish` | **taken** (GRAPHPAN is set) — which is why rung 2 must be **before** it |
| 5 | graph pan | `Button2Mask` **and** `!graph_marker_drag` |
| 6 | RMB rubber rect (box zoom) | `Button3Mask` **and** `!graph_marker_drag` |

Rungs 5 and 6 need the extra term because the marker drag deliberately sets **no
`graph_flags` bit** (landmine 6), so the existing
`!(graph_flags & (16|32|512|1024))` guard — which exists for exactly this reason
with cursors — cannot see it. Without them a B1(marker held)+B2 chord would move
the marker *and* pan, and B1+B3 would move the marker *and* paint the box-zoom
rubber.

The motion arm never sets `save_mouse_at_end` and never touches
`mx_double_save`/`my_double_save` (landmine 20): those are shared by three
gestures and the pan **re-seeds them every motion step**. It uses
`need_redraw_master` (master-only), never `need_all_redraw`/`need_fullredraw`.

**RELEASE (Button1):**

| rung | what | after the change |
|---|---|---|
| **1** | **`graph_marker_release()`** on Button1, **`graph_marker_drag_abort()`** on any other button | **consumes rung 2**. Always `need_redraw_master`; **`need_all_redraw`** when the release returns 1, i.e. the selection came off *another* graph |
| 2 | issue-0152 wave-bold click | now the `else` of rung 1 |
| 3 | tooltip | unchanged |
| 4 | `goto finish` | taken |
| 5 | `ui_state &= ~GRAPHPAN; graph_flags &= ~(16\|32\|512\|1024)` | the marker arm must **fall through** to reach it |

Rung 1 must come first because the wave-bold arm is a release-only travel test
with **no knowledge of what the press hit** — a no-travel marker SELECT would
otherwise also toggle `hilight_wave` and rewrite the token. And it must not
`return`: falling through is what lets the per-graph teardown clear `GRAPHPAN`;
a `return` there strands the latch and `waves_selected` then swallows every
subsequent canvas event.

The `else graph_marker_drag_abort()` closes a real hole: the teardown at rung 5
only runs for `button != Button3`, so a Button3 release during an armed marker
drag would otherwise leave a stale arm that commits an anchor move on the *next*
Button1 release.

`graph_marker_release()` takes **no** `i`/`gr`/`r` and resolves everything from
`xctx->graph_marker_draggraph`, so a drag that ends over a different strip still
commits to the rect it started on. `graph_marker_drag_to()` builds its **own**
local `Graph_ctx` for the same index, so the drag can never be re-keyed onto
whatever strip `graph_master` happens to be under the pointer.

`graph_marker_drag_abort()` is also called by `abort_operation()` (ESC),
defensively by `waves_selected`'s leave-every-graph reset, and — the case that
actually matters — at **every fresh Button1 press** (§7.4).

### 7.3 ASE viewer

The viewer's Tcl filters get first refusal — `strip_bindings` sweeps every
widget-level sequence. `<ButtonPress-1>` runs `wviewer::strip_drag_press`:

| rung | what | after the change |
|---|---|---|
| 1 | `$state & 13` (Shift/Ctrl/Alt) → refuse | unchanged |
| 2 | `strip_at_pixel` → refuse if not over a strip | unchanged |
| 3 | reset stale arms, focus, `set_target_strip` (this **logs**) | unchanged |
| 4 | **`xschem callback $W 4 …` — the C forward. This is where the marker press arms.** | unchanged |
| 5 | `strip_handle_at_pixel != $gi` — the reorder **grip** keeps first refusal | unchanged |
| **6** | **`if {[wviewer::marker_grabbed $W]} { return 1 }`** — first statement *inside* rung 5's block | C owns the whole gesture; arms **neither** Tcl gesture |
| 7 | `trace_at` (`graph_trace_at`, 10 px) → trace drag | unchanged |
| 8 | `cursor_grabbed` (`graph_flags & (16\|32\|512\|1024)`) → C cursor grab | unchanged |
| 9 | strip reorder | unchanged |

`<Double-Button-1>` is **more specific** than `<ButtonPress-1>`, so the second
press of a double-click never reaches `strip_drag_press` or C at all; the second
*release* still does. That binding used to be a bare `{break}` (*"D9: no graph
props dlg"*). Since issue 0189 it is
`{wviewer::marker_dblclick_at %W %x %y; break}`:

* the `break` is **unconditional** — D9 (no graph-properties dialog over a
  read-only viewer) must survive for every non-marker double-click, and
  forwarding `-3` to C from here would let a Tcl/C hit-test disagreement open
  `.graphdialog` over the viewer, the exact fall-through class issue 0176 closed
  for `Delete`;
* `marker_dblclick_at` resolves the token from `%W` (never the current ctx — the
  `clear_all_at` rule), asks `xschem get graph_marker_at`, and on a hit runs
  `xschem graph_marker select -pair` + `xschem redraw`;
* it is **not** wrapped in `with_edit`, unlike every neighbouring marker seam:
  `select` writes no token, pushes no undo point, sets no modify flag and is one
  of the three sub-verbs the scheduler exempts from its readonly reject. The
  bracket would cost a context switch plus four state writes on a click and hide
  the fact that this path is not a mutation.

**Rung 6 is not optional.** Without it, both failure modes are *silent*:

* a marker **anchor** sits *on a trace* by construction, so `trace_at` returns
  `>= 0` and `trace_drag_arm` steals the gesture — a >3 px drag moves the *trace
  to another strip* instead of sliding the marker;
* a marker **label** sits in empty waveform space, where `trace_at` misses and
  `cursor_grabbed` is 0 — so the **strip reorder** arms and a >3 px vertical drag
  reorders the whole stack.

**It sits after rung 5, not before it.** `strip_handle_at_pixel` claims the right
14 px over the *full band height* — outside the plot box for any strip wider than
~285 px and therefore outside every clamped callout, but for a narrow strip the
two would overlap and the grip must win. Putting the marker question *inside* the
`!= $gi` block gives the grip unconditional priority in Tcl, and
`graph_marker_press`'s own grip-column decline keeps C in agreement, so
`marker_grabbed` can never be 1 for a press the grip owns.

**Marker before cursor** (rung 6 before rung 8) is a judgement call, stated
deliberately: a marker anchor is a smaller, more intentional target than a
full-height cursor line, and a cursor parked on a marker is recoverable by
grabbing the cursor elsewhere along its line.

`<B1-Motion>` needed no change — `trace_drag_motion` and the strip reorder both
return 0 when unarmed, so the motion is forwarded to C exactly once and the
marker drag previews for free (a motion writes only `graph_marker_scratch`, which
is not a document write and needs no bracket).

**`<ButtonRelease-1>` DID need a change, and it is conditional.**
`strip_drag_release` still always forwards the release to C before
`trace_drag_drop` — but it forwards it **inside `wviewer::with_edit` when
`xschem get graph_marker_drag` > 0**, and raw otherwise:

```tcl
set mk 0
catch {set mk [xschem get graph_marker_drag]}
if {[string is integer -strict $mk] && $mk > 0} {
  if {[catch {wviewer::with_edit $token {xschem callback $W 5 $px $py 0 1 0 $state}} emk]} { ... }
} else {
  xschem callback $W 5 $px $py 0 1 0 $state
}
```

The **reason it is needed**: the marker drag *commits* on this release
(`graph_marker_release` → `anchor_at`/`label_offset` → `graph_marker_update`),
and `graph_marker_update` calls `graph_marker_ro_refuse()` — which the viewer
buffer, read-only for its whole life, would otherwise trip. Without the bracket
every anchor and label drag in the viewer would preview correctly and then
silently drop on release, with a "read-only" line in the CIW.

The **reason it is conditional**: `with_edit` is a context switch plus four
state writes (`autosave_backup`, `readonly` off, `set_modify 0`, `readonly` on),
far too heavy to pay on *every* mouse release. And it is not needed on any
other: everything else this release does — dropping a cursor, the issue-0152
wave-bold, the box-zoom, the end of a pan — writes **view** state, which the
graph engine has always been allowed to put into a read-only rect (landmine 19).
A plain marker **click** (select) does not mutate either, but it arrives through
the same `graph_marker_drag` flag and the bracket is harmless there, so it is
not special-cased.

Double-click is `{break}` in the viewer, so `-3` never reaches C there. ESC goes
through `key_filter` → `strip_drag_cancel` → the forward → C's
`abort_operation` → `graph_marker_drag_abort()`.

**Key forwarding.** `wviewer::graphkeys` gains `100` (`d`) and `77` (`M`); `109`
(`m`) was already there. Two gates matter:

* `graphkeys` membership forwards **unconditionally on modifiers**, and there is
  no `ctx=graph` row for `Ctrl+d` — so a bare forward would fall through to the
  schematic `case 'd'`, whose `ControlMask` branch is `delete_files()`, a **modal
  file dialog** over a readonly viewer. The arm therefore reads
  `set fwd [expr {!($N == 100 && ($s & 4))}]`, leaving Ctrl-D to the
  `WaveViewer` bindtag's Clear All. `M` needs no such gate: `case 'M'` is
  `rstate == 0`-only.
* `Delete` (65535) is deliberately **not** a `graphkeys` member, and **since
  issue 0176 it is not forwarded to C from this window at all.** It gets its own
  arm, gated on `over_graph`, which hands the whole gesture to
  `wviewer::delete_selection_at` — the marker, the selected traces, or both
  (§6.1's "TWO arms" box, and `waveform_viewer_modes.md` §16). Membership or an
  unguarded forward would land a Delete on the canvas delete verb, whose own
  `readonly_block()` *is* a modal in a readonly viewer; not forwarding at all
  makes that unreachable rather than merely unlikely.
  ⚠ **Superseded text, kept because the reasoning still applies to any NEW key:**
  the arm used to be *doubly* gated — `over_graph` **and**
  `marker_selected >= 0` — and forwarded, relying on C's own strip-scope test to
  refuse a marker selected on another strip. That refusal fell **through** to the
  canvas delete verb, so the modal was reachable after all. The scope test now
  lives in Tcl (`marker_graph_at` vs `strip_at_pixel`, 0176 D9) and nothing is
  forwarded.

Neither `m` nor `d` belongs on the `WaveViewer` bindtag: `key_filter` never
`break`s, so a tag binding would fire *in addition* to the forward (two actions
per press), and the tag has no way to test "the pointer is over a graph".

**Both remaining keysyms — `m` and `d` — are forwarded inside
`wviewer::with_edit`** (and KeyPress only), because the mutating primitives they
reach call `graph_marker_ro_refuse()` and the viewer buffer is read-only for its
whole life. Every other forwarded key still goes raw. §6.6 has the full rule and
the failure it prevents. (`Delete` was the third until 0176 and needs no bracket
now: it calls no C mutation verb.)

### 7.4 Stale arms, and repainting the strip you are NOT on

**The teardown at PRESS is the one that closes the hole.** A fresh Button1 press
can never be the continuation of an armed drag, so rung 1 calls
`graph_marker_drag_abort()` unconditionally, right where `graph_press_x/y` is
seeded — **before** the `if(ui_state & GRAPHPAN) goto finish` and **outside**
`graph_marker_press()`.

The release-side teardown is *not* sufficient, and the reason is in Tcl, not C:
the ASE viewer binds `<Shift-ButtonRelease-1>` and `<Alt-ButtonRelease-1>` to a
bare `{break}`, so a modifier-held release **never reaches C at all**. The
release arm cannot run for a gesture whose release is swallowed. What survived
was an armed drag with no owner, and it was not inert:

* `wviewer::marker_grabbed` reads `xschem get graph_marker_drag`, so it answered
  `1` for every later press — killing the trace-drag and strip-reorder seams
  outright (§7.3 rung 6 gives C the whole gesture on that answer);
* the next unrelated Button1 release found `graph_marker_drag` set and
  **committed the old move**, writing an anchor the user had abandoned.

`graph_marker_drag_abort()` is a no-op when nothing is armed, so the press-side
call costs one predictable branch per press.

**The other half is repainting.** The selection ring is window-wide state drawn
per strip, so both transitions that can move it *off a strip the pointer is not
over* have to say so:

| event | signal | why |
|---|---|---|
| press hit no marker but cleared a selection | `graph_marker_press()` → `-1` | the erased ring may be on another strip |
| no-travel release selected a marker while another graph held the old one | `graph_marker_release()` → `1` (`oldsel >= 0 && oldgraph != gi`) | two rings would otherwise be visible until the next full redraw |

`waves_callback` turns both into `need_all_redraw`. Everything else on the
marker path stays `need_redraw_master`: a drag repaints one strip.

---

## 8. The ASE model mirror — why it is a PUSH and not a PULL

The viewer's Tcl model (`wviewer::layouts`) is the single source of truth for its
rects: `wviewer::regenerate` does `xschem clear_drawing` and re-places every rect
from `wviewer::graph_props`. Markers are written into the rect by **C**, so
without a mirror the next `regenerate` would erase them.

`regenerate` is called from **22 sites** in `wave_viewer.tcl` (plus two in
`ase_window.tcl`), and when this hook was designed only **three**
(`move_strip`, `move_trace`, `history_step`) first called
`capture_live_graph_state`. The unguarded ones included `configure_apply` — a
plain **window resize**. So a pull-only design means: create M1, drag the window
edge, M1 is gone, with no user action that reads as destructive.

⚠ **Updated 2026-08-01 (issue 0194), and the hook is still required.** 19 of the
22 sites now fold before regenerating, `configure_apply` among them, so the
sentence above no longer describes the tree. The push hook is NOT redundant: the
fold at those sites is a *pull*, and a pull only runs when a Tcl command runs.
A marker created or dragged with the mouse, followed by nothing but another
mouse gesture, still reaches no capture — and the three sites that legitimately
never fold (`restore`, `state_apply`, `clear_all`) would still lose it. Pushing
on change keeps the model current at all times, which is the property this
section actually needs.

Therefore **C notifies Tcl the moment a marker changes**:

```
draw.c graph_marker_notify()
   -> tcleval "graph_marker_changed"     (global proc; C has no namespace context)
   -> wviewer::marker_changed            (the real work)
```

`graph_marker_notify()` is called on **commit only** — create, delete,
drag-release — **never per motion event**, and it returns early when `!has_x`.
It reads the Tcl result and `dbg(0, ...)`s anything that is neither `1` nor `2`,
because a silent bail would resurface much later as "my markers vanished on
resize" with no diagnostic anywhere.

Return codes: `1` model updated · `2` not a viewer window (legitimately nothing
to do) · `0` the viewer proc bailed · `-1` a Tcl error was caught.

`wviewer::marker_changed` does four things that are each load-bearing:

1. **Resolves the window from `xschem get current_win_path` → `token_for_canvas`**
   and returns `2` for a non-viewer canvas. It is **read-only** on the schematic
   side (`getprop` only), so it needs no `with_edit`.
2. **Guards the index space with `xschem get graph_rects`, not `xschem get rects
   2`.** The latter counts *every* layer-2 rect, so one stray non-graph
   `GRIDLAYER` rect would permanently disable the hook. On a mismatch it bails
   rather than attach strip 0's markers to a different model graph.
3. **Short-circuits when nothing changed**, so a no-op notify pushes **no phantom
   undo point**.
4. **Calls `wviewer::push_undo` BEFORE `wviewer::set_graphs`.** `push_undo`
   records the *current* state as the restore point ("called by a mutating
   command before it changes anything") and `history_step` pops that snapshot and
   applies it. Snapshotting *after* `set_graphs` would store the post-marker
   model, so `u` would restore the very marker it was meant to remove. This is
   the shipped order in `move_strip` and `move_trace` too.
5. **Calls `capture_live_graph_state $token 1` before *that*.** Same three-step
   ordering every other viewer edit uses — *capture, snapshot, mutate*. Without
   the capture, the snapshot holds a model that predates whatever the user did
   with the mouse since the last regenerate, so one `u` after creating a marker
   also reverted an unrelated MMB pan, RMB box-zoom or wave-bold. It is
   `set_graphs`-based like everything else in the model layer, so it is cheap.

   **`skip_markers` = 1 is not optional there.** `capture_live_graph_state`
   folds *live rect state* into the model, and by the time the hook runs the new
   marker is already in the rect — capturing it would put the change **inside
   its own restore point**, and `u` would then restore the marker it was meant
   to remove. Same defect the step-4 ordering closes, arriving by the other
   door. So the arm captures the ranges and the bold and deliberately leaves the
   `markers` key alone; the loop below it is what folds the markers in, after
   the snapshot.

`capture_live_graph_state` also carries the **same rect/model 1:1 guard** as
`marker_changed` (`xschem get graph_rects` vs `llength $gs`, bail on a
mismatch), and it needs it *more*: that path also **deletes** — an absent token
takes the `dict remove` branch — so a count desync would both attach one strip's
state to another model graph and wipe the keys of every model graph past the
last rect.

`wviewer::graph_props` emits `markers="…"` **only** when the model key is
non-empty *and* `markers_valid`. The `ne {}` test is not redundant with
`markers_valid`: see §10's `{}`-returns-0 contract.

`wviewer::marker_grabbed` and `wviewer::marker_selected` both do
`xschem new_schematic switch $wp` **first** — `xschem get graph_marker_drag` /
`graph_marker_sel` answer for the *current* xctx, so with two windows open an
unswitched read answers for the wrong one. Both fail closed (`0` / `-1`), the
`cursor_grabbed` precedent.

---

## 9. Node-index remap rules

`GraphMarker.wave` is a **NODE** index — the space `hilight_wave`,
`find_closest_wave`'s `node_number` and `graph_trace_at` all speak, and *not* the
model trace index (reference landmine 34: `graph_props` skips a trace with an
empty `vec` when it builds the `node` token, so such a trace occupies a model slot
and no node slot). Every model mutation that shifts node indices needs a rule:

| mutation | node indices shift? | marker rule |
|---|---|---|
| `move_trace` / `move_trace_in_graphs` | **yes, in two graphs** | `remap_markers_after_trace_move {src_mk dst_mk moved_ni dst_ni}` → `{new_src new_dst}`. On the **source**: `wave == moved_ni` **MIGRATES** to the destination with `wave = dst_ni` (the marker follows its trace — the same rule `hilight_wave` obeys); `wave > moved_ni` decrements; below unchanged. On the **destination**: existing markers untouched, because the trace is *appended*. `dset`/`point`/`x`/`y` stay valid — the trace kept its raw column, only the index moved. `prev` may now cross strips, which is already legal. |
| `move_strip` / `reorder_graphs` | no (whole dicts move) | **nothing.** Markers ride inside the graph dict exactly like `auto` and `hilight_wave`. This is precisely why markers must **never** live in a strip-index-keyed side table. |
| `delete_in_graphs` — the ONE trace/strip deleter, reached from the Delete dialog **and** the DEL key (issue 0176) | **yes** | `remap_markers_after_trace_delete {mk doomed_nis}`: drop every marker whose `wave` is doomed, decrement each survivor by the number of doomed nodes strictly below it. Doomed **node** indices are taken via `node_index_of_trace` **before any trace leaves the list**. Then sweep the dropped numbers window-wide (below). A whole strip contributes all of its numbers to the sweep and nothing else. ⚠ Was `delete_ok`'s inline loop until 0176. |
| `delete_items`' MARKER argument (DEL with a marker selected) | no | the number simply joins the same `gone` list, so `markers_sweep_numbers` deletes the record **and** zeroes every `prev` that pointed at it in one pass. The C `graph_marker_delete` verb is deliberately not used — 0176 D8. |
| `clear_graph_traces` (the auto-plot rebuild) | wipes all traces | `dict remove $G markers` (and `hilight_wave`), then a window-wide sweep for each removed number. |
| `clear_all` | replaces with `empty_graph` | **nothing** — `empty_graph` has no `markers` key, so it is all gone by construction; but reset `xschem graph_marker select -none`. |
| `plot_signals`, `add_trace`, `add_graph`, `display_raw` | append-only | **nothing.** Multi-plot `plot_signals` *prepends* strips, which renumbers strip indices — dict-held markers are safe by construction. |
| `snapshot` / `restore` | whole dicts | **nothing.** `ase::state_serialize` writes `"$k [list $value]"`, so a multi-line braced value spans lines harmlessly and `state_load` reads it back. |
| `regenerate` sharedx, `fit` | `dict replace` on named keys | **nothing.** |

**The dangling-`prev` sweep must live in the model layer, not only in C.**
`graph_marker_delete` clears dangling `prev` links window-wide, but **none** of
the Tcl deletion paths go through it — they rewrite the token directly.
`wviewer::markers_drop_number {s num}` is the shared primitive and
`wviewer::markers_sweep_numbers {gs nums}` applies it across **every** strip
whenever a number disappears. Without it a delta block degrades to a plain
callout with no indication at all, because `graph_marker_text` simply omits the
block when the partner does not resolve.

**Two pre-existing latent bugs were fixed alongside**, in the same shape: neither
`delete_ok` nor `clear_graph_traces` had ever remapped `hilight_wave`, so
deleting a trace below the bold one left the bold marker pointing one node too
high. `wviewer::remap_node_after_trace_delete` is the shared index math.

`wviewer::empty_graph` is **not** given a `markers` key. The house rule for
optional per-graph keys is that they are added ad hoc (`auto` via
`ensure_auto_graph`, `hilight_wave` via capture), never in `empty_graph`, because
`graph_props` reads only known keys and open dicts round-trip the rest.

---

## 10. Surface

### 10.1 C — the exported inventory (`src/draw.c`, declared in `src/xschem.h`)

| function | one-line contract |
|---|---|
| `graph_point_at(i, px, py, tol, restrict_wave, restrict_dataset, hit)` | **The shared sample picker.** 1 when a trace of graph `i` passes within `tol` **screen** pixels of canvas pixel `(px,py)`; fills `*hit` with the nearest sample *on that trace*. Ranking is point-to-**segment** distance, strictly-nearer wins. `restrict_*` >= 0 confine the search. `hit->x/y` are **raw**, never `mylog10`'ed. Saves/restores `graph_flags` 128\|256 (landmine 37) and unwinds `extra_rawfile` **only if the switch took** (§5.2, landmine 40). |
| `graph_wave_at` / `graph_near_wave` | now thin wrappers over it — the identity form and the boolean form. Unchanged signatures and semantics. |
| `graph_markers_parse(prop_ptr, &arr, &n)` | token → array. Copies `get_tok_value`'s shared buffer first. Drops a short or non-finite record, keeps the rest. **Never caps** — `GRAPH_MARKERS_MAX` bounds creation only (§3.2). Caller `my_free`s. |
| `graph_markers_format(&dest, arr, n)` | array → token value (`%.17g` / `%.10g`, `\n`-joined). `*dest = NULL` for `n == 0`. |
| `graph_markers_store(r, arr, n)` | format + `subst_token` + `set_rect_flags`. An empty array **deletes** the token, so "never marked" and "all removed" are one representation. Does **not** notify. |
| `graph_marker_next_number()` / `graph_marker_max_number()` | window-wide scan of every graph rect. **No counter is kept anywhere**, so a rect deleted, undone, pasted or regenerated can never desync the numbering. |
| `graph_marker_find(num, &gi, &out)` | locate a marker anywhere in the window — a delta's partner may live in another strip. |
| `graph_marker_text(num, dest, size)` | by-**number** wrapper over `graph_marker_text_rec` — the `xschem graph_marker text` verb and the tests. Never used by the renderer or the hit-tester: it reads the *stored* record, which is stale for the duration of a drag (§6.5). |
| `graph_marker_at(i, px, py, tol, &part)` | marker **number** under a canvas pixel (0 = none), `*part` 1 = anchor, 2 = label. Anchors first at a tight tolerance (nearest wins); labels second, last-drawn-on-top. No raw gate. Returns 0 under `--nogui`. Saves and restores `graph_flags` bits 128\|256 across its `setup_graph_data` call — it is a query, reachable from a Tcl verb, and must not leave the session describing a strip nobody is hovering (landmine 37b). |
| `graph_marker_create(i, px, py, delta)` | pick + create at the pointer. Gates on **`graph_plotbox_at(i, px, py)`** and then picks with `graph_point_at(i, px, py, 1e30, -1, -1, ·)` — the same pair `draw_graph_snap_cursor()` makes (D12). Refuses digital strips, then the plot box, then "no trace to mark", all **before** the read-only gate (§6.3 has the ordering). Saves/restores `graph_flags` 128\|256 around its own `setup_graph_data` (landmine 37). ⚠ That local `Graph_ctx` is built with `skip = 1`, so `gx1/gx2/gw` are 0 and every derived coefficient is **infinity** — `gr->digital` is the only field of it that may be read, and the box must come from `graph_plotbox_at()` (landmine 45). |
| `graph_marker_create_at(i, wave, dset, point, delta)` | data-addressed create — the headless-testable creator **and** the form `log_action` writes. |
| `graph_marker_delete(num)` | **read-only gated.** Remove it **and** `graph_marker_clear_prev(num)` window-wide. Resets the selection if it pointed there. |
| `graph_marker_delete_all(gi)` | **read-only gated.** `gi < 0` = every graph rect; returns the count; one undo point for the lot. Collects the numbers it removed and sweeps them with **one** `graph_marker_clear_prev_n()` pass — a *partial* `delete -all` (`gi >= 0`) otherwise left dangling `prev` links on the strips it did not touch, silently degrading a delta callout to a plain one (§6.5). |
| `graph_marker_delete_selected()` | returns **0 without touching anything** when nothing is selected — that is what lets `Delete` fall through. |
| `graph_marker_move(num, px, py)` | pixel anchor re-snap: `graph_point_at(..., 1e30, m.wave, m.dataset, ...)`. The huge tolerance means a drag can never "lose" the marker; the restrictions keep it on its own trace and sweep. |
| `graph_marker_anchor_at(num, dset, point)` | data-addressed anchor set — the logged form of an anchor drag. |
| `graph_marker_label_offset(num, ldx, ldy)` | label offset only, clamped to ±2, non-finite refused. |
| `graph_marker_select(num, gi)` | pure UI state: no token write, no undo, no modify — and therefore **not** read-only gated (§6.6). `num < 0` clears. `gi` is stored as a repaint **hint** only (§3.5). |
| `graph_marker_renumber_rect(r)` | for **both** rect-duplication doors — `merge_box` (`paste.c`) and `copy_objects` (`move.c`). Computes `base` **once**, assigns `base + k`, clears every `prev`. **Not** read-only gated: paste and copy are refused higher up, and a renumber refused *after* the clone would leave duplicate numbers (§6.6). |
| `graph_marker_notify()` | the ASE push hook (§8). **Extern**, because `callback.c` and the ops call it. |

Every exported mutator reaches the read-only gate exactly once, through one of
the four gated primitives: create via `graph_marker_add_record`, `move` /
`anchor_at` / `label_offset` via `graph_marker_update`, and the two deletes
directly. `select`, `renumber_rect`, `find`, `text`, `at`, `next_number`,
`max_number`, `parse`/`format`/`store` and `notify` are not gated — §6.6 says
which of those are queries and which are deliberate exemptions.

`graph_marker_label_box` takes the font size as a parameter, computed **once per
call** by each of its two callers via `graph_marker_txtsize()` — it reads a Tcl
var, and both the redraw and the hit test loop every record.

Static to `draw.c`: `graph_marker_fmt`, `graph_markers_collect` (+ the
`GraphMarkerRef` it builds — the parse-once pool, below), `graph_marker_text_rec`
(**the label core**, §6.5), `graph_marker_label_box` (**the single
source of truth for callout geometry, used by both the renderer and the
hit-tester so the drawn box and the clickable box can never disagree**),
`graph_marker_color`, **`graph_marker_txtsize`** (the one font size, shared by
the renderer and the hit-tester), **`graph_marker_pad_box`** (the callout
padding, §6.4), `graph_marker_font_install`/`_restore`,
`draw_graph_markers`, `graph_wave_resolve`, `graph_marker_sample`,
`graph_marker_refuse`, **`graph_marker_ro_refuse`** (**the** read-only gate,
§6.6), `graph_marker_add_record`, `graph_marker_update`,
**`graph_marker_clear_prev_n`** (the one-pass window-wide `prev` sweep) and its
single-number wrapper `graph_marker_clear_prev`.
Static to `callback.c`: `graph_marker_press`, `graph_marker_drag_to`,
`graph_marker_drag_clear`, `graph_marker_drag_abort`, `graph_marker_release`.

Constants live in `xschem.h`, beside `GRAPH_REORDER_HANDLE_W`, because
`callback.c` consumes them: `GRAPH_MARKERS_MAX 512` and `GRAPH_MARKER_TOL 8.0`
(the anchor/label grab radius, **screen pixels**, fixed regardless of canvas
zoom). `GRAPH_DELTA_STR` and `GRAPH_MARKER_FINITE` stay file-local to `draw.c`.

⚠ **There is no CREATION tolerance, deliberately** (issue 0188). What gates
`m`/`d` is the strip's plot box — `graph_plotbox_at()`, the same gate the item-9
diamond uses — and the sample is picked with an unreachable `1e30`. A
`GRAPH_MARKER_PICK_TOL` did exist (20.0) and had exactly one use; it was deleted
with the gate it implemented, because a constant documenting a rule that no
longer holds is the trap the next reader falls into (D12; the
`test_wave_snap.tcl` SQ3 precedent).

**One parse per operation — the pool.** `graph_markers_collect()` walks every
graph rect in the window **once** and returns a flat array of `GraphMarkerRef`
(`{GraphMarker m; int graph;}`). The renderer and the hit-tester each build one
at the top of a call and pass it down to `graph_marker_text_rec`, which resolves
a delta partner by scanning that array instead of calling `graph_marker_find`.

The naive shape — a `graph_marker_find()` per record — re-parses **every rect in
the window** for **every marker**, which is O(N²) in the marker count, and it
runs on the two hottest paths there are: the redraw (`draw_graph_all` loops every
graph rect on *every* pan, zoom, cursor move and repaint) and the hit-test (every
single LMB press). Measured: **139 ms per redraw at 400 markers, ~220 ms at the
512 cap** — a visibly unusable editor, reached by nothing more exotic than a
busy plot.

Two details keep it honest. The pool is built **only when at least one record on
this rect has `prev >= 1`** (`need_pool`), so the common no-delta case pays
nothing; and `graph_marker_text_rec` still falls back to `graph_marker_find`
when `pool` is `NULL`, which is what makes the by-number wrapper work
standalone.

**One pass per DELETE, for the same reason.** The dangling-`prev` sweep is
`graph_marker_clear_prev_n(const int *nums, int nnums)` — a single walk over
every graph rect in the window, testing each surviving record's `prev` against
the whole doomed set. `graph_marker_clear_prev(num)` is a one-element wrapper
over it, kept for the single delete.

It has to be that shape, not a loop of per-number sweeps. The sweep must be
window-wide (a `delete -all <gi>` on one strip leaves partners on the others),
so the per-number form is O(deleted × surviving records) — the *same*
full-window-rescan-per-record shape the parse-once pool was introduced to
remove, arriving through the delete door instead of the redraw door. Measured:
`delete -all` on a window holding **4000 markers took 10 s**; the one-pass form
does it in **41 ms**.

**Two font notes.** `text_bbox` measures with whatever cairo face is installed
and sets the font size as a side effect, so measure and draw happen back to back.
`graph_marker_font_install()` installs the same toy face `draw_graph_all` uses,
in **both** the renderer and the hit-tester — otherwise `xschem draw_graph`
(which installs no face) and `xschem get graph_marker_at` would measure the same
callout differently. It is guarded on `has_x && xctx->cairo_ctx`, which is NULL
under `--nogui`.

**One rendering note.** The call site in `draw_graph` opens **exactly one**
`bbox` scope around `draw_graph_markers`, over the **container** rect
(`gr->rx1..gr->ry2`) so a partial repaint covers the whole strip, and
`draw_graph_markers` calls no helper that opens another. A re-entrant
`bbox(START)` prints an error **and pops a modal Tcl `alert_` dialog**
(`select.c` ~812) — on *every redraw* — which is why the block sits strictly
after the cursor block's `bbox(END)` rather than being appended inside it. It
also **cheap-gates on `get_tok_value(r->prop_ptr, "markers", 0)[0]` before
opening anything**: `bbox(SET_INSIDE)` reprograms the X clip mask across the
whole GC set, and `draw_graph_all` loops every graph rect on every redraw.

### 10.2 Tcl verbs

**Read-only getters — fail SOFT** (a sentinel + `TCL_OK` on a short or bad query,
never an error; the viewer wraps them in `catch` + `string is integer -strict`
and must be able to treat a missing verb as "nothing there", never as "locked
out"):

| verb | result |
|---|---|
| `xschem get graph_marker_at <gi> <px> <py> [tol]` | `""` · `"<num> anchor"` · `"<num> label"` (default `tol` = `GRAPH_MARKER_TOL`) |
| `xschem get graph_marker_drag` | `0` none · `1` anchor drag armed · `2` label drag armed |
| `xschem get graph_marker_sel` | the selected marker number, `-1` = none — the **HEAD** of the set, unchanged by issue 0189 |
| `xschem get graph_marker_sel_set` | the WHOLE selection as marker numbers, **head first**, space separated (`"2 1"`); `""` when nothing is selected (issue 0189) |
| `xschem get graph_rects` | count of layer-2 rects with `flags & 1` — **not** `xschem get rects 2` |

**Mutations — fail LOUD** (`xschem graph_marker <sub>`, top-level in
`xschem_cmds_g`; unknown sub-verb → usage string + `TCL_ERROR`). Every sub-verb
except `select`, `list` and `text` is **readonly-rejected** by
`scheduler_readonly_reject()`, before the primitive is even called. That is a
**second, independent** gate from the one the keys and the mouse hit
(`graph_marker_ro_refuse()`, §6.6), and the difference in loudness is
deliberate: a script gets a `TCL_ERROR` it can catch, a gesture gets a CIW line
it cannot deadlock on. Both refuse the same set of operations, and the viewer
defeats both the same way, through `wviewer::with_edit`.

| sub-verb | args | result |
|---|---|---|
| `add` | `<gi> <px> <py> [-delta]` | new number, or `{}` |
| `add_at` | `<gi> <wave> <dset> <point> [-delta]` | new number, or `{}` |
| `anchor` | `<num> <dset> <point>` | `1`/`0` |
| `move` | `<num> <px> <py>` | `1`/`0` |
| `label` | `<num> <ldx> <ldy>` | `1`/`0` |
| `delete` | `<num>` \| `-all [<gi>]` \| `-selected` | `1`/`0` \| count \| count — `-selected` removes the whole set under **ONE** undo point (issue 0189) and is readonly-**rejected** like every other `delete` form |
| `select` | `<num> [<gi>]` \| `-none` \| `-pair <num> [<gi>]` \| `-set <n1> [<n2> …]` | **always the new HEAD**, for every form (`-none` still answers `-1`). Read the whole set with `xschem get graph_marker_sel_set`. `-pair` applies the double-click policy (D13); `-set` is permissive and dedupes, keeping the order given. All four forms ride the `select` readonly **exemption**, which is what lets the read-only viewer pair-select without a `with_edit` bracket |
| `list` | `[<gi>]` | Tcl list of 10-element sublists `{num graph wave dset point x y prev ldx ldy}`, `x`/`y` at `%.17g` — **the exactness seam** |
| `text` | `<num>` | the rendered label, embedded `\n` |

Persistence needs **no** verb: `xschem getprop rect 2 <gi> markers` /
`xschem setprop [-fast] rect 2 <gi> markers <val>` already round-trip a
multi-line value byte-for-byte. Note the option-order trap: `-fast` comes
**before** the object type (`xschem setprop -fast rect 2 …`);
`xschem setprop rect -fast 2 5 markers …` silently edits `rect[0][2]` instead of
erroring.

**Action logging.** Markers are logged at gesture **end** only, and always in the
**data-addressed** form, so a replay does not depend on pixels:
`xschem graph_marker add_at <gi> <wave> <dset> <point> [-delta]`,
`... anchor <num> <dset> <point>`, `... label <num> <ldx> <ldy>`,
`... delete <num>`, `... delete -all <gi>`.

### 10.3 Tcl model helpers (`src/wave_viewer.tcl`, all PURE unless noted)

| proc | contract |
|---|---|
| `markers_num_ok {v}` | one legal field. The character class **is** the safety property (§3.1). Deliberately not `string is double` — Tcl accepts `Inf`/`NaN` there. |
| `markers_line_fields {line}` | the fields of one record, `{}` when it is not a record. **The single splitter**, shared by `markers_valid` and `markers_decode` so they cannot disagree about the alphabet. Extra spaces tolerated, tabs not (`SPACE()` would truncate the token). |
| `markers_valid {s}` | **`{}` → 0** (load-bearing: vacuous truth would stamp `markers=""` on every unmarked strip, *and* create two inequivalent spellings of "no markers", since `xschem rect … $props` stores verbatim while `subst_token` deletes on empty). Else 1 iff *every* line is a record. Whole-token because it guards **emission**. |
| `markers_decode {s}` | token → record dicts. **Bad lines dropped, rest kept** — matching the C parser. `x`/`y`/`ldx`/`ldy` kept as **strings**; the five integer fields normalised via `scan %d` so later `expr` cannot hit Tcl's leading-zero-octal rule; `extra` carries the 10th+ field. |
| `markers_encode {recs}` | the inverse; re-emits the doubles **verbatim**. Empty list → `{}`. |
| `markers_numbers {s}` | the numbers a token carries — the seam the deletion paths use. |
| `markers_drop_number {s num}` | remove record `num` **and** zero every `prev == num`. |
| `markers_sweep_numbers {gs nums}` | the window-wide `prev` sweep across a graph list. Never *adds* a `markers` key; drops one that empties out. |
| `remap_node_after_trace_delete {ni doomed}` | `{}` when `ni` is doomed, else `ni` minus the count of doomed strictly below. Shared with the `hilight_wave` fix. |
| `remap_markers_after_trace_move {src_mk dst_mk moved_ni dst_ni}` | → `{new_src new_dst}` (§9). |
| `remap_markers_after_trace_delete {mk doomed_nis}` | §9. Cannot sweep `prev` — it sees one graph; callers must. |
| `marker_grabbed {wp}` | *not pure* — the `cursor_grabbed` twin over `xschem get graph_marker_drag`. Switches ctx first, fails closed → 0. Only trustworthy because C tears a stale arm down at press (§7.4); a surviving arm made this answer `1` forever. |
| `marker_selected {wp}` | *not pure* — selected number, **-1** on none or any error. Same rules. |
| `capture_live_graph_state {token {skip_markers 0}}` | *not pure* — folds live rect state (ranges, `hilight_wave`, `markers`) back into the model. `skip_markers 1` leaves the `markers` key alone: `marker_changed` needs the ranges but must **not** capture the change it is about to record (§8). Carries `marker_changed`'s rect/model 1:1 guard, and needs it more, because this path also **deletes** keys. |
| `::graph_marker_changed` | *not pure* — the **global** C entry point. Delegates; `-1` on a caught error. |
| `marker_changed` | *not pure* — **the load-bearing piece** (§8). Order is *capture (skip_markers) → push_undo → set_graphs*. |
| `delete_all_markers {{token {}}}` | *not pure* — §6.1.1. `with_edit` + `xschem graph_marker delete -all`, inside a `log_action -suppress push`/`pop` bracket whose `pop` is unconditional. Returns the count · `0` no-op (no repaint, **no log line**) · `{}` no viewer. Repaints (`xschem redraw`); does **not** touch the model, push undo, or regenerate — the push hook does all three. Propagates `with_edit`'s "context busy" error. |
| `delete_all_markers_at {W}` | *not pure* — the `WaveViewer` `Ctrl-E` body, the `clear_all_at` pattern. Resolves the token from `%W`, `{}` on a foreign canvas. **Catches**, unlike `clear_all_at`: an error escaping a Tk binding pops a `bgerror` box over a read-only viewer. |
| `key_filter` (the m/d arms) | *not pure* — forwards those two keysyms, KeyPress only, inside `with_edit`, because the primitives they reach are readonly-gated (§6.6). ⚠ `Delete` was the third until issue 0176 and is **not forwarded at all** any more. |
| `marker_graph_at {wp num}` | *not pure* — the graph rect whose `markers` token carries `num`, or **-1**. The Tcl mirror of C's `graph_marker_find`, read off the RECTS for the same reason C re-resolves it, and the half of the Delete key's strip-scope test that 0176 had to bring into Tcl. Fails closed. |
| `delete_selection_at {W px py}` | *not pure* — THE DEL body (0176). Collects the selected traces (`selected_waves` → `trace_index_of_node`) and the selected marker when `marker_graph_at == strip_at_pixel`, then calls `delete_items` once. `0` when nothing is selected — and that `0` is load-bearing: it is why nothing reaches C. |
| `delete_items {graphs pairs ?markers? ?token?}` | *not pure* — THE authoritative delete, shared by the Delete dialog and the DEL key. capture → `push_undo` → `delete_in_graphs` → window-wide `markers_sweep_numbers` (which also performs the marker arm) → target remap → ONE `regenerate` → ONE log line. Returns the count · `0` no-op · `{}` refused. |
| `delete_in_graphs {gs delg delt}` | **PURE** — → `{newgraphs gone}`. §9's whole trace-delete rule, lifted out of `delete_ok` by 0176 so the key and the dialog share it. |
| `strip_drag_release` (the marker arm) | *not pure* — forwards `<ButtonRelease-1>` inside `with_edit` **only when `xschem get graph_marker_drag` > 0**, because that is the release a marker drag commits on. Every other release still goes raw: `with_edit` is too heavy to pay per release, and nothing else the release does writes durable content (§7.3). |

---

## 11. As shipped / deferred

### Shipped

* The `markers` prop token, its C parser/formatter/store, and full round-trip
  through save/load, copy/paste, C undo/redo and SVG/PNG export.
* `m` / `d` create, `M` tooltip relocation, `Delete` deletes a selected marker.
* **`m` / `d` create ANYWHERE inside the strip's plot box** (issue 0188), at the
  sample the item-9 diamond snap cursor has snapped to. The creation gate is
  `graph_plotbox_at()` and the pick is `graph_point_at(..., 1e30, -1, -1, ...)` —
  the same pair `draw_graph_snap_cursor()` makes, so glyph and key cannot
  disagree in either direction. `GRAPH_MARKER_PICK_TOL` is gone; trace SELECTION
  keeps its 10-px `GRAPH_TRACE_PICK_TOL`, untouched and regression-witnessed.
  No new verb, no Tcl mirror: all three creation doors (both key arms and
  `xschem graph_marker add`) already went through the one primitive.
* LMB click to select, LMB drag on the anchor (snap along the trace) and on the
  callout (move the leader), ESC cancel.
* Delta blocks with Δx / Δy / slope, cross-strip partners, `slope:undef`.
* The `xschem get graph_marker_*` / `graph_rects` getters and the
  `xschem graph_marker` verb family, with data-addressed action logging.
* Renumbering at **both** rect-duplication doors — `merge_box` (paste) and
  `copy_objects` (the `c`-key copy).
* The ASE push hook, the model mirror, the node-index remaps, the window-wide
  `prev` sweep, and viewer `u`/`U` undo of a marker change.
* **Delete All Markers** — `Ctrl-E` on the `WaveViewer` bindtag plus the Graph
  menu entry, `wviewer::delete_all_markers ?token?` /
  `wviewer::delete_all_markers_at %W`, one rewritten log line, one undo point
  (the hook's), one repaint (§6.1.1). No C change was needed.
* **Delete deletes whatever is selected, in the viewer** (issue 0176) — the
  marker arm above, the 0175 trace selection, or both, as one gesture. The
  cascade (a marker on a deleted trace is dropped), the survivor remap and the
  window-wide number sweep all come from §9, unchanged. Delete is no longer
  forwarded to C from that window at all. Again no C change was needed.

**Callout polish** (a later pass; the first three are appearance, the fourth is
behaviour):

| # | change | what it was |
|---|---|---|
| 1 | callout **padding**, inside `graph_marker_label_box` after every `text_bbox` | the box was the raw text extents, so the glyphs touched the border. Applied at the shared function so the drawn box and the *clickable* box grow together (§6.4). |
| 2 | both stroke weights are an explicit **fixed pixel count** (1 unselected, 2 selected) with a `+0.25` truncation guard | `lw = 0.0` inherited the GC's resting width, which scales with zoom: the unselected outline reached 10 px zoomed in and **inverted the selection cue** below zoom 0.375. And `2.0*zoom*mooz` truncated to 1 px on 13.9 % of zooms (§6.4). |
| 3 | font is `gr->txtsizey * graph_marker_textmag`, from **one** helper used by the renderer and the hit-tester | `gr->txtsizex` is clamped by the *bottom margin*, so the callout collapsed with strip height — 2.96 px in an 8-stack, below `draw_string`'s own 3-px floor, i.e. invisible but still clickable. The renderer and the hit-tester also named the size independently (§6.4). |
| 4 | a text drag on a **selected** marker moves the anchor too, via a new `graph_marker_dragmode` latched at press | `part` alone decided the commit, so the two gestures could not be distinguished; `graph_marker_drag`'s 0/1/2 contract had to stay intact for the Tcl seams (§6.2.1). Legs `MX7e`/`MX7f` (the A/B) and `MX7g`/`MX7h` (the latch, both directions). |

**Post-review hardening** (a second pass over the shipped feature; each is a
defect that was reachable from the UI, not a tidy-up):

| # | fix | what it was |
|---|---|---|
| 1 | sweep token resolved **above** the `restrict_wave` skip in `graph_point_at` | a `sweep` list shorter than `node` carries its last entry forward, so skipping first made every RESTRICTED walk — i.e. **every anchor drag** — fall back to raw column 0 and find nothing. `graph_marker move` returned 0 and the record never changed. Reference landmine 38. |
| 2 | the label is built from the **record** (`graph_marker_text_rec`) | an anchor drag slid the dot while the readout stayed frozen at the pre-drag values (§6.5). |
| 3 | parse-once pool (`graph_markers_collect` / `GraphMarkerRef`) | the per-record full-window scan made redraw **and** hit-test O(N²): 139 ms per redraw at 400 markers, ~220 ms at the cap (§10.1). |
| 4 | `graph_marker_sample()` switches to the graph's own raw, **and bails when the switch fails** | the pixel path previewed one raw and the commit path read another; and on an unresolvable `rawfile=` the data path used to read the sample out of whatever raw was current, while the pixel path already refused (§5.1). |
| 5 | `graph_marker_clear_prev_n()`: **one** window-wide pass for the whole doomed set, also called from `delete -all` | a *partial* `delete -all` left dangling `prev` links elsewhere in the window — and the obvious per-number fix was O(deleted × surviving), 10 s at 4000 markers vs 41 ms now (§10.1). |
| 6 | `graph_markers_parse()` no longer caps | truncating on the read side destroyed records on a >512 file (§3.2). |
| 7 | `graph_flags` 128\|256 saved/restored around `setup_graph_data` in **all four** callers that need the transform — `graph_point_at`, `graph_marker_at`, `graph_marker_create` (`draw.c`) and `graph_marker_drag_to` (`callback.c`) | a query left the session describing a strip nobody was hovering (landmine 37). It began as a fix to `graph_marker_at` alone; the other three are reachable the same way — `graph_point_at` backs the `graph_trace_at`/`graph_near_wave` verbs and runs once per motion event during a drag. |
| 8 | selection is the **number**; the `Delete` gate re-resolves the strip | `selgraph` is a rect index and goes stale on a reorder or a multi-plot prepend (§3.5). |
| 9 | `graph_marker_drag_abort()` at every fresh Button1 press | the viewer's `{break}` on modifier-held releases means the release-side teardown can never run (§7.4). |
| 10 | `graph_marker_press()` → `-1`, `graph_marker_release()` → `1` | a stale selection ring on *another* strip was never erased (§7.4). |
| 11 | `graph_marker_ro_refuse()` in the four mutating **primitives** (`draw.c`), a **non-modal** `ciw_echo` | content landed in a read-only buffer with no undo point and no way back. Started life as `readonly_block()` in the `m`/`d`/`Delete` key arms; **that was wrong twice over** — a modal on a keystroke deadlocks any script driving the refusal (it hung the marker suite under a real `$DISPLAY`), and the key arms miss the **drag-commit** path entirely, so a mouse gesture could still edit a read-only buffer permanently (§6.6). |
| 12 | `clear_drawing()` resets the selection + the drag fields | the same `xctx` is reused by load/open/clear/disk-undo, so the selection latched onto the new document's M1 (§3.5). |
| 13 | `copy_objects()` renumbers a copied graph rect | the `c`-key copy produced two M1s and two M2s (D10). |
| 14 | `capture_live_graph_state $token 1` before `push_undo` in `marker_changed` | one `u` after creating a marker also reverted an unrelated pan/zoom/bold (§8). |
| 15 | `key_filter` forwards `m`/`d` inside `with_edit` (`Delete` too, until issue 0176 stopped forwarding it), **and `strip_drag_release` forwards the release inside it when a marker drag is armed** | the companion to 11: without the key half the readonly viewer would lose marker *creates*, without the release half it would lose every anchor and label **drag** — which reaches no key arm at all (§6.6, §7.3). |
| 16 | `graph_point_at()` / `graph_marker_sample()` unwind `extra_rawfile` **only if the switch took** (`switched` flag) | mode 5 is a **swap**, not a stack pop, so an unpaired call repoints the session's raw: a pure hover query on a graph whose `rawfile=` does not resolve flipped `xctx->raw` on every call (§5.2, landmine 40). |

* **Six** pre-existing bugs fixed as prerequisites. Four live in the trace
  pickers, which `graph_point_at` is a refactor of, so the marker code would
  have inherited them verbatim:
  1. an **infinite loop** when a graph's first `node` entry is a bus — the
     `continue` fired before `nptr = NULL`, and `my_strtok_r` re-seeds from the
     head whenever `str != NULL`. Fixed in **both** pickers;
  2. a bus entry **not consuming its `sweep` token**, shifting every following
     trace onto the wrong sweep variable. Fixed in **both**;
  3. `extra_rawfile()` switched **per node** but restored **once**. Fixed in
     `graph_point_at` only (the switch is now hoisted above the node loop);
     **still open in `find_closest_wave`** — see the §12 DONE callout in the
     reference doc;
  4. `find_closest_wave` reading an **uninitialised `ofs_end`** when it skips
     dataset 0 (`done: ofs = ofs_end;` after a `goto` that jumped the
     assignment).

  The last two are unrelated to the pickers and were simply found while testing
  markers:

  5. **`xschem draw_graph <i>` crashed under `--nogui`** (straight to Xlib with
     no window, no pixmap and no GCs) and dereferenced `rect[GRIDLAYER][i]`
     **unchecked**. It now has a `has_x` + range guard and is a no-op instead of
     a SIGSEGV; reference doc §9.
  6. **`raw_deletevar()` corrupted the heap** (`save.c`). The shrinking realloc
     read `sizeof(SPICE_DATA *) * raw->nvars + 1` — an operator-precedence bug
     for `sizeof(SPICE_DATA *) * (raw->nvars + 1)`. `values` carries `nvars+1`
     columns, the last being the scratch column expressions are evaluated into
     (reference landmine 1); the buggy form asked for `8*nvars + 1` **bytes**
     and truncated that slot away, so the next `raw add` grew the array back and
     wrote into what had been uninitialised memory (valgrind: "Invalid write of
     size 8" in `plot_raw_custom_data` ← `raw_add_vector`, then SIGSEGV). It
     survived under plain glibc only because the shrinking realloc happened to
     stay in place. Upstream since 7a45497b, and it had sat as **backlog item 3**
     in the reference doc; it surfaced now because
     `tests/headless/test_wave_markers.tcl` is the tree's **first and only
     caller of `xschem raw del`**.

**Multi-marker selection — the PAIR case (issue 0189, 2026-08-01).** The
selection became a **SET** (`xctx->graph_marker_sel_set[GRAPH_MARKER_MAX_SEL]` +
`graph_marker_n_sel`) with `graph_marker_sel` kept as its head, and a
**double-click on a difference marker selects it and the reference its deltas
are derived from** (D13). `Delete` then removes the whole set as one gesture
with **one** undo point, on the C key path and on the viewer's `delete_items`
path alike.

Scope, stated honestly: **pair only**. There is still no rubber band, no
Ctrl+click accumulation, no chained or reverse delta selection. `GRAPH_MARKER_MAX_SEL`
is 8 purely so a future Ctrl+click needs no header edit.

The thing the old Deferred entry flagged as "decide it first" — *it changes verb
result shapes* — was deliberately decided as **no change**: every
`graph_marker select` form still returns the HEAD, `-none` still answers `-1`,
`xschem get graph_marker_sel` and `wviewer::marker_selected` are byte-for-byte
what they were, and the set is read through a **new** getter
(`xschem get graph_marker_sel_set`). ~27 shipped assertions rest on that.

### Deferred — explicitly, not oversights

* **An explicit `xschem graph_marker resnap` verb.** Markers render from the
  cached `x`/`y` (§5) and therefore do **not** follow a re-simulation. Re-deriving
  on every redraw is the wrong fix; a deliberate `resnap` is the right one.
* **Digital-strip and bus markers.** `graph_point_at` refuses `gr->digital` and
  skips bus entries, inheriting `graph_wave_at`'s documented limits verbatim
  (reference landmine 33). A band/ribbon rendering has no polyline to snap to.
  The refusal is at least now *visible* — a CIW message rather than silence.
* **Preserving delta links across a copy or a paste.** Both duplication doors are
  per-rect (`merge_box` is a per-rect merge callback; `copy_objects` renumbers the
  one rect `storeobject` just registered) and neither can see a cross-rect number
  map, so `graph_marker_renumber_rect` clears every `prev`. Delta blocks silently
  degrade to plain callouts on copy and on paste.
* **The graph-level `dataset=` token is still ignored by the picker**, so a
  marker can anchor to a sample of a *hidden* dataset on a multi-dataset graph.
  Fixing it properly means reproducing `draw_graph`'s DC-wrap `sweepvar_wrap`
  logic in the picker; fixing it naively would newly exclude DC-wrap traces that
  `graph_trace_at` picks today, regressing the shipped trace drag.
* **A read-only *browse* window cannot carry markers at all.** This is the
  accepted cost of D6/§6.6: the refusal is `xctx->readonly`, and nothing in C
  distinguishes "readonly viewer scratch" from "readonly descend". The ASE viewer
  is exempt only because it *asks* — it opens `with_edit` around the forward. A
  read-only descend has no such wrapper and gets the plain refusal, which is the
  honest answer, since a marker created there could never be saved. If a third
  state (a "scratch readonly" flag) is ever introduced, the exemption belongs in
  the **one** place the test now lives — `graph_marker_ro_refuse()` — and
  nowhere else. Do **not** reintroduce a gate in the key arms: that shape was
  tried and reverted (hardening item 11), because it deadlocks scripts on a
  modal and leaves the drag-commit path ungated.
* **The two duplication doors are found by inspection, not by construction.**
  `merge_box` and `copy_objects` both clone a rect's `prop_ptr` verbatim, and
  nothing forces a third such path to renumber. Anything that ever adds a second
  unique id to a rect token inherits the same trap — reference landmine 39.
