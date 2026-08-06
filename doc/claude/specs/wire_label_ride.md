# Wire-label ride-along: a net label names copper, it does not cut it

Status: **S0 LANDED** 2026-08-05 (instrumentation, no behaviour change).
**S1 LANDED** 2026-08-05 (R1 + LEASH). **S2 LANDED** 2026-08-06 (R2, behind
`label_splits_wires`, default 0). S3–S7 not implemented.
Designed 2026-08-05.

> ⚠ **S2 removes a mask that was protecting issue 0227 for the `cadence_compat` user, and §9
> did not list it.** The split put a mid-span label on a wire ENDPOINT, and two separate rescues
> key on endpoint coincidence; without the split neither fires, so the user's original complaint
> gets strictly worse until **S3** lands. Measured, bounded, and switchable — see **§15.3**.
> Mitigation until S3: `set label_splits_wires 1`.
Area: `src/check.c`, `src/actions.c`, `src/move.c`, `src/select.c` (comment only), `src/xschem.tcl`
Related analysis: `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md`
Related issues: **0220** (prerequisite), **0223** (policy overlap), **0227** (superseded by this),
**0228** (label half superseded; device-pin half stays)
Bible: `doc/claude/WIRING.md` — read §7 landmines and §10 before implementing.
Sibling specs: `wire_segment_splitting.md` (amended by this), `wire_stub_netlabel.md`,
`add_wire_label.md`, `cadence_modifier_drag.md`

---

## 1. What this changes, in one paragraph

A `type=label` instance keeps its `PINLAYER` rect, keeps sitting geometrically on the wire,
and keeps naming the net exactly as it does today. What changes is that its pin stops being
treated as **copper geometry**: it no longer splits a wire into segments, no longer blocks a
collinear merge, and no longer mints a connecting stub during a drag. In exchange, a new
per-gesture in-memory *rider set* carries the label onto its owner wire's new geometry when
the wire moves. Nothing changes on disk, in any `.sym`, in `netlist.c`, in `xWire` or in
`xInstance`. `XSCHEM_FILE_VERSION` stays `1.3`.

---

## 2. Requirements

| id | requirement |
|---|---|
| **R1** | Repositioning a wire-label must not extrude a **new** wire segment. Moving an existing wire's *endpoint* is permitted — see R6. |
| **R2** | A wire from A to B with a label in the middle stays **one** wire, not two. |
| **R3** | Moving, rotating or flipping the wire carries the label along, **including the label's own orientation** — the text rotates and flips with the wire, as in Cadence. |
| **R4** | Lose nothing: selection, highlight, plot-by-clicking-a-label, custom label symbols, `global=`, `value=`, `sig_type`, `text_size_0`, the `*_ignore` family, undo, clipboard, property dialog, bbox, spatial hash, the unified label-vs-port netlist loop, `.sch` format stability. |
| **R5** | The label's pin carries no current; it is a naming anchor. Its copper-geometry side effects are unjustified and must go. |
| **R6** | Dragging a label **along** its wire's direction is permitted, and past an endpoint it **extends the wire**. This is deliberate: it gives the user more to grab when lengthening a stub. A resulting short is the user's concern — no refusal, no warning. |
| **R7** | Dragging a label **perpendicular** to its wire always snaps back. A label can never sit off copper, and never re-attaches to a different wire. |
| **R8** | Deleting a wire deletes the labels attached to it. Copying a wire copies its labels — so a labelled `ENABLE` stub can be pasted wherever that signal is needed. |
| **R9** | Existing schematics are **not** migrated. A label already sitting off copper produces a log-window warning plus a dismissible popup when the schematic is opened. |

**Design consequence of R6 + R7:** because the label is always in contact, there is no
detached state, so there is **no leader line** — no dashed attachment indicator, no new
layer, nothing new drawn. Cadence needs its dashed yellow leader precisely because it lets
the name detach; this design does not.

---

## 3. The target environment

The user runs `src/cadence_style_rc`. Two lines in it decide everything here:

```tcl
src/cadence_style_rc:40   set cadence_compat 1
src/cadence_style_rc:50   set fluid_editing 1
```

Consequences that must be understood before touching anything:

- **`autotrim_wires` is forced on.** `cadence_style_rc` never sets it, but
  `cadence_compat_sync` does:

  ```tcl
  src/xschem.tcl:16260-16264
  proc cadence_compat_sync {args} {
    global cadence_compat autotrim_wires
    if {$cadence_compat == 1} { set autotrim_wires 1 }
  }
  trace add variable cadence_compat write cadence_compat_sync
  ```

  The trace is **one-directional** — turning `cadence_compat` off later leaves
  `autotrim_wires` on. So in this environment the wire **does** split at a label, and R2 is a
  live complaint, not a hypothetical.

- **Connected drag is `cadence_compat`-gated, not `fluid_editing`-gated.** The
  attached-move / Ctrl-detached / Shift-copy triad and the `connect_by_kissing` arm live
  inside `if(cadence_compat)`:

  ```c
  src/callback.c:7984-8005
         if(cadence_compat) {
           …
           } else {
             xctx->connect_by_kissing = 2; /* armed BEFORE select_attached_nets … */
             select_attached_nets(); /* nets that land on selected instance pins follow */
             move_objects(START,0,0,0);
  ```

  `fluid_editing` separately gates the first-click tip/edge grab
  (`src/callback.c:7816`).

  **Therefore "just set `autotrim_wires 0`" is not an option.** It is not what gives the
  connected drag, and turning it off would disable auto join/trim everywhere — every
  `maintain_wire_segments()` call site (`check.c:675`, `select.c:779`, `actions.c:4449`,
  `move.c:1098`, `:9046`, `save.c:3890`, `scheduler.c:243`, `:6097`, `:12979`) is gated on
  it. The fix must be **targeted at labels**, leaving device-pin splitting intact.

---

## 4. Diagnosis

Three predicates ask *"does an instance pin sit here?"* and none asks *"is this a terminal or
a name?"*. Plus one mechanism that does not exist.

### 4.1 R1 — the extruded segment

`connect_by_kissing()`'s ELEMENT arm walks every pin of every moving instance with no type
filter, and stores a zero-length wire where a moving pin meets stationary copper:

```c
src/actions.c:2063     npin = symbol->rects[PINLAYER];      /* no symbol-type filter */
src/actions.c:2101     storeobject(-1, pinx0, piny0,  pinx0, piny0, WIRE, 0, SELECTED1, NULL);
```

The drag then rubber-bands that degenerate wire into real copper. Fires in **both**
`autotrim_wires` modes. Two distinct sub-cases:

- sliding the label **along** its wire leaks a duplicate collinear `N` record — visible only
  with `autotrim_wires = 0`, because autotrim's `check_includes` cull
  (`src/check.c:312-321`) silently eats it;
- dragging the label **off** the wire leaves a permanent perpendicular stub, in both modes.

This is also what breaks `.sch` byte-stability: once a stub exists it is a genuine third
endpoint, so `merge_collinear_wires` refuses to weld across it and a one-`N`-record file
becomes three.

### 4.2 R2 — the split

Exactly one splitter exists:

```c
src/check.c:693   int break_wires_at_attach_points(void)
src/check.c:708     rects = (xctx->inst[k].ptr + xctx->sym)->rects[PINLAYER];   /* no type filter */
src/check.c:719     wire_store_split(i, x0, y0, xctx->wire[i].sel);
```

Sole caller `maintain_wire_segments()` (`src/check.c:748`); all 8 call sites gated on
`autotrim_wires`.

Two facts that bound the scope:

- **With stock defaults (`autotrim_wires = 0`) the wire never splits at a label** — measured;
  `select_at` on either side of the label returns the same object. This spec's R2 work
  therefore matters *only* to `cadence_compat` users. It matters to **this** user.
- **The split is in-memory only.** `save_wire()` coalesces it back
  (`src/save.c:2687-2690`) and writes a byte-identical single `N` record. R2 is a
  *selection-identity* complaint, not a data-model or file-format one.

Caveat when reproducing: part of what looks like "two segments" in default mode is §4.1's
extruded duplicate, not a split. Different file, different fix.

### 4.3 R3 — nothing carries the label

`select_attached_nets()` (`src/select.c:1723-1853`) has an ELEMENT arm (`:1799-1804`) and a
WIRE arm, both of which grab **wires**. There is no wire→instance arm anywhere in the tree.

What happens instead: `connect_by_kissing()`'s WIRE-endpoint arm (`src/actions.c:2131`) finds
the stationary label in `instpin_spatial_table` and mints a **tether stub** (`:2158`).
Measured result of dragging a labelled wire: **3 wires**, label still at its old coordinates,
and in default mode the net silently reverts to `#net1`.

### 4.4 R5 — is the pin electrical?

**Right on the default path.** `name_attached_nets()` uses `touch()` (`src/netlist.c:1114`),
which is interior-inclusive (`src/clip.c:234-245`), so a mid-span label names the whole
unsplit wire. Load-bearing measurement: **split and unsplit produce byte-identical SPICE.**

**Wrong under `autotrim_wires`, and that is a bug.** Splitting *both* wires at a shared
crossing point creates endpoint coincidence, which **is** real connectivity. Measured: a
label with `lab=` **empty** at a crossing collapses four resistors onto one net; remove the
label and there are two nets. In the user's mode, a nameless label silently shorts things.
That is not a feature to preserve — it is the strongest argument for this spec.

---

## 5. Design

### 5.1 There is no invisible layer and no connecting line

This is the question that decides whether R4 survives, so it is stated first and explicitly.

**The label keeps its real `PINLAYER` rect and keeps sitting geometrically on the wire.**
The label-to-net association remains exactly what it is today: *the label's pin coordinate
lies on the wire's span*, tested by `touch()`. No layer is added. No connector object exists.
Nothing is drawn that is not drawn today.

What is **removed** is the *spurious* zero-length wire that `connect_by_kissing()` mints
during a drag (`actions.c:2101`, `:2158`). That stub is a bug artifact, not a mechanism —
it is created at gesture time and rubber-banded into copper. It is not what connects the
label to the net, and nothing reads it as such.

What is **added** is a per-gesture in-memory array that exists only between the START and
END of one move gesture, is freed on commit and on abort, is never in `sel_array`, never in
`inst[].sel`, and never on disk. Its sole content is "which wire was this label sitting on
when the drag started, and where was its anchor" — enough to reposition the label at commit.

**Why this preserves selection, highlight and plot-picking:** every one of those paths reads
`xctx->inst[i].node`, which `reset_node_data_and_rehash()` allocates only when
`rects[PINLAYER] + rects[GENERICLAYER] > 0` (`src/netlist.c:1666-1671`). The label keeps its
pin, so `node` keeps being allocated, so all of the following are untouched:

```
src/hilight.c:148    IS_LABEL_SH_OR_PIN(...)                     label click -> net hilight
src/hilight.c:1221   !strcmp(tok,"lab") && inst[i].node && IS_LABEL_SH_OR_PIN(type)
src/hilight.c:1480   hilight_connected_inst || IS_LABEL_SH_OR_PIN(symbol->type)
src/hilight.c:1807   IS_LABEL_SH_OR_PIN(type)
src/hilight.c:2347   inst[n].node && IS_LABEL_SH_OR_PIN(type)   /* "instance must have a pin!" */
src/hilight.c:2417   "                                          "
src/hilight.c:2491   "                                          "
src/hilight.c:2561   "                                          "
src/draw.c:703       IS_LABEL_SH_OR_PIN(type) && inst[n].node && inst[n].node[0]
src/draw.c:9467      IS_LABEL_SH_OR_PIN(symtype) && inst_text_bbox(...)
src/flyline.c:45     symtype && inst[n].node && IS_LABEL_SH_OR_PIN(symtype)
src/select.c:49      IS_LABEL_SH_OR_PIN(type) || probe
src/select.c:2234    "                                 "
```

This is precisely why the "anchor demotion" alternative — giving labels zero `PINLAYER`
rects at symbol-load time — was rejected. It is the more elegant mechanism, but it empties
`inst[].node` and takes every line above with it. See §10.

### 5.2 Part 1 — demote the pin from copper operator to naming anchor

One predicate, consulted at three places.

```c
/* src/check.c, near :173 */
int inst_is_netlabel(int i)
{
  const char *type;
  if(i < 0 || i >= xctx->instances) return 0;
  if(xctx->inst[i].ptr < 0) return 0;
  type = (xctx->inst[i].ptr + xctx->sym)->type;
  return type && !strcmp(type, "label");
}
```

Deliberately **`strcmp(type,"label")`, not `IS_LABEL_OR_PIN`.** `ipin` / `opin` / `iopin` are
real hierarchy terminals; every current behaviour of theirs is preserved. Deliberately not
`IS_LABEL_SH_OR_PIN` either — `scope`, `show_label` and `bus_tap` are out of scope here
(`bus_tap` in particular is a genuine two-pin copper object).

Three consumers:

- `break_wires_at_attach_points()` (`src/check.c:708`) — skip labels → **R2**.
- `any_inst_pin_at()` (`src/check.c:173-180`) — gains a skip-labels argument, used
  label-blind at the trim collinear-rejoin refusal (`:405`) and at
  `merge_collinear_wires`' pin-aware arm (`:795`). **Mandatory with the splitter change** —
  splitting without relaxing the merge yields a wire that can never re-weld.
- `connect_by_kissing()` (`src/actions.c:2061-2063` and `:2131`) — skip labels → **R1** and
  the removal of the tether.

`point_on_wire_or_pin()` (`src/check.c:186-201`) **stays label-aware**: it is the
Add-Wire-Label drop gate, and a label landing on another label's pin is a legitimate drop
target.

### 5.3 Part 2 — the rider set

```c
/* src/xschem.h, beside fluid_startsel_id */
typedef struct {
  int    lid;      /* label instance id (stable id, not array index)          */
  int    wid;      /* owner wire id at capture                                 */
  double ax, ay;   /* label pin anchor, START coordinates                      */
  double ox, oy;   /* label instance origin, START coordinates                 */
  double t;        /* parametric position on the owner span (fallback only)    */
  int    wsel;     /* owner wire's sel state at capture                        */
  int    mode;     /* LEASH | RIDE                                             */
} Label_ride;

Label_ride *label_ride;
int         label_ride_n;
int         fluid_last_move_label_strands;   /* Tcl-mirrored oracle */
```

No change to `xWire`, `xInstance` or `xSymbol`.

**Capture** — `label_ride_capture()`, called at `src/move.c:8189`: after
`xctx->kissing = connect_by_kissing()` (`:8180`) and the `movelastsel` refresh (`:8181`),
before `fluid_gesture_arm()` (`:8190`). Guard `rects[PINLAYER] > 0` before every anchor read
— follow the `src/flyline.c:80-83` pattern; never trust `get_inst_pin_coord()`'s silent
`(0,0)` return.

**Apply** — `label_ride_apply()`, called **END-only**, as the first statement after
`xctx->ui_state &= ~STARTMERGE;` at **`src/move.c:9372`**. See §11 hazard (A): the earlier
draft put it at `:9377` beside `pin_views_reconcile_after_move()`, which is four lines *after*
the gesture state is zeroed and would make the ride a silent no-op. `pin_views_reconcile_after_move()`
is still the right conceptual precedent — a post-commit pass that moves a non-wire object because
its anchor moved, carrying the two-way rule at `src/actions.c:1730-1741` — but not the right
neighbour.

```
wi = wire_index_from_id(r.wid);                      /* src/store.c:445 */
if(wi < 0 || !touch(wire[wi].x1, wire[wi].y1, wire[wi].x2, wire[wi].y2, r.ax, r.ay))
   → geometric re-find: the collinear wire through the anchor   /* MANDATORY, see §11 (B) */
   → else DECLINE

ROTATION(move_rot, move_flip, pivot, r.ax, r.ay, nx, ny);   /* pivot = xctx->x1/y1,
                                                             * or inst origin if rotatelocal */
nx += deltax;  ny += deltay;

sanity gate: |anchor displacement| > gesture delta, or owner span length changed by
             more than <factor>  → DECLINE

inst[li].x0 = r.ox + (nx - r.ax);                    /* ABSOLUTE, never += */
inst[li].y0 = r.oy + (ny - r.ay);
symbol_bbox(li, …);
xctx->prep_hash_inst = 0;
xctx->prep_net_structs = 0;
xctx->prep_hi_structs = 0;
xctx->need_reb_sel_arr = 1;
```

**Free** — `label_ride_free()` in the `if(!commit_now)` block beside
`my_free(&xctx->fluid_startsel_id)`, and on ABORT.

Three properties of this that are not negotiable:

1. **Absolute writes, never `+=`.** The pristine snapshot at `src/move.c:8195` is taken
   *"Only for a fluid stretch"*, so on any non-fluid multi-step path an incremental write
   accumulates.
2. **The rotation closed form is the primary rule, not a fallback.** `ORDER()` plus the
   `SELECTED1↔SELECTED2` swap at `src/move.c:812-821` and `order_wire_points()` at
   `:1115-1128` canonicalize wire endpoints on commit, so any parametric-`t`-from-endpoint-1
   scheme mirrors the label to the wrong end on a rotate or an endpoint-crossing stretch. The
   rotation form is endpoint-order-independent, closed-form in START state plus total delta,
   and therefore idempotent. Parametric `t` survives only as the clamp-projection fallback
   when an anchor falls off a *shortened* span.
3. **Write `rot` / `flip` too** (R3). The label's text rotates and flips with the wire — the
   Cadence behaviour. There is **no helper**; copy the inline ELEMENT bake at
   `src/move.c:8976-8993` verbatim, including the `xctx->rotatelocal` branch around
   `ROTATION(...)`:

   ```c
   xctx->inst[n].rot = (xctx->inst[n].rot +
     ( (xctx->move_flip && (xctx->inst[n].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3;
   xctx->inst[n].flip = xctx->move_flip ^ xctx->inst[n].flip;
   symbol_bbox(n, &xctx->inst[n].x1, …);
   ```

   **The `+2` term is not optional** — a naive `(rot + move_rot) & 3` gets flipped
   odd-rotation labels wrong. The same formula is duplicated at the move-copy site
   `move.c:1063-1065`. `update_symbol_bboxes()` (`move.c:206-227`) is **not** a commit helper —
   it applies then restores rot/flip.

   The symbol's `T {@lab}` record needs **no separate handling**: `draw.c:847` positions it and
   `draw.c:896-898` orients it with the identical rot/flip pair, `select.c:524`/`:530-533`
   mirror it so the bbox follows, and `hcenter`/`vcenter` pass through unchanged. The text code
   at `move.c:8921-8948` is for standalone `xctx->text[]` objects and is irrelevant here.

   Placement order is constrained by hazard **(D)** in §11 — target pin coordinate first, then
   rot/flip, then solve for the origin. Not translate-then-rotate.

No `push_undo()` — the gesture already pushed at `src/move.c:8391`. The wire extension of §5.5
shares that same undo push, so one Ctrl-Z reverts label and wire together.

Invalidation, per the real ELEMENT commit: `prep_hash_inst = 0` (`move.c:8977`) plus
`prep_net_structs = 0; prep_hi_structs = 0;` (`:8996-8998`). Omitting the latter two leaves
stale instpin-hash entries and stale wire node names until an unrelated edit clears the flag.

### 5.4 Label-initiated drag: decompose along / perpendicular

When the **label** is the thing being dragged (as opposed to riding a moving wire), the raw
delta is decomposed against the owner wire's direction:

- **Parallel component — applied.** The label slides along the wire.
- **Perpendicular component — discarded.** The anchor is projected back onto the owner wire's
  infinite line. This is the snap-back (R7).
- **Owner never changes.** If the projected anchor happens to land on a different wire, that
  is irrelevant — the label stays bound to the wire it started on. No re-attachment, ever.

Projection handles any wire orientation, including diagonals. Note that the projection of a
snapped point onto a diagonal wire is generally **off** the snap grid; that is accepted, since
the alternative (re-snapping after projection) can push the anchor back off the wire.

**This clamp must be applied live, during the drag, not only at release.** With clamping as the
permanent model the user would otherwise watch the label track the cursor perpendicular for the
whole drag and then jump back at release. Cadence constrains under the cursor.

Note this is a **different code path from the ride**, and the two have different timing:

| gesture | what happens | when |
|---|---|---|
| **label** is dragged (§5.4/§5.5) | clamp to the owner wire's line; extend past the end | **live**, under the cursor |
| **wire** is dragged/rotated/flipped (§5.6 RIDE) | label follows, orientation included | **END-only** |

The ride's corrected apply site (§11 hazard A) sits inside `if(!commit_now)` at
`src/move.c:9359`, so it is structurally END-only: the saved result is correct — each fluid
RUBBER step restores to pristine and END re-derives from the total delta — but **the label will
not visibly move during a live fluid wire drag**. It snaps into place at release. Whether that
is acceptable is open question 1; making it live is a separate piece of work, not a flag flip.

### 5.5 Sliding past the end extends the wire (R6)

If the parallel component carries the anchor beyond an endpoint, the **nearer endpoint of the
owner wire moves to the anchor**. The wire grows; no new wire is created, so R1 holds.

Deliberately **no guard rails**, per the user's decision: the extended wire may newly touch
unrelated copper and merge nets, and that is the user's concern. No refusal, no warning, no
preference. The rationale is that this makes a labelled stub easier to lengthen — the label is
a bigger grab target than the wire's endpoint.

Two consequences that must be handled, not prevented:

- The extension is a wire mutation, so it participates in the gesture's existing undo push.
- Under `autotrim_wires` the extension can weld with a collinear neighbour on the next
  `maintain_wire_segments()`. That is the same outcome the user would get by dragging the
  endpoint directly, so it is consistent, but the ride's owner-id bookkeeping must survive it
  (§5.6).

### 5.6 Modes

**LEASH** — the label-initiated drag of §5.4/§5.5: parallel applied, perpendicular projected
back, past-the-end extends. Gated on `xctx->connect_by_kissing`.

**RIDE** — the wire moves, rotates or flips and the label follows, orientation included.
Supersedes the tether stub.

### 5.7 Delete and copy propagation (R8)

- **Delete a wire → delete its labels.** A label whose pin touches only that wire goes with
  it. A label whose pin also touches surviving copper stays.
- **Copy a wire → copy its labels.** Selecting and copying a labelled stub reproduces the
  label, so an `ENABLE` stub can be pasted at every point that needs the signal.

Both are new propagation rules and need their own passes; neither is implied by the rider set,
which is per-gesture and move-scoped. Sizing is pending — the delete side interacts with
`select_dangling_nets()` semantics (issue **0229**), and the copy side must not double-copy a
label the user had also selected explicitly.

### 5.8 Legacy off-wire labels (R9)

No migration. Nothing in an existing `.sch` is rewritten. When a schematic containing a label
whose pin touches no copper is opened, xschem writes a warning naming the offending instances to
the log window and shows a dismissible popup.

**Measured scope: 21 files of 589; 91 labels of 5,366 (1.7 %).** Dedupes to **5 distinct library
designs** — `binto7seg/top` (12), `xschem_simulator/logic_test` (9),
`xschem_simulator/simulate_ff` (7), `rulz-r8c33` (4), `examples/greycnt` (2), each mirrored in
`xschem_libs_newsym/` — plus **11 test fixtures** (8 under `tests/headless/flylines/`,
`tests/hilight_xwin_sync/parent.sch` + `child.sch`, one `greycnt` copy). `gf180mcuD/` is
completely clean.

**The predicate must be pin-aware, not wire-only.** 1,919 labels (36 %) touch no wire but sit
exactly on a *device* pin — the standard gnd/vdd-on-a-pin idiom. A wire-only test fires ~1,900
popups on the shipped libraries. Rule: off copper **iff** the pin coordinate satisfies neither
`touch()` (`clip.c:234`) against any wire **nor** `touches_inst_pin()` (`check.c:440`) against
any **other** instance.

**`point_on_wire_or_pin()` (`check.c:188`) cannot be reused** — it skips SELECTED objects, and
at load nothing is selected, so a label always self-matches. Write a self-excluding sibling.

**Hook: `src/save.c:3900`**, inside `load_schematic()`'s
`if(reset_undo) { set_netlist_dir(2, NULL); drc_check(-1); }` block, right after `drc_check(-1)`
— the same gate as `eval_load_file_postprocess` at `:3903`, and after
`check_collapsing_objects()` / `maintain_wire_segments()` (`:3882-3890`) so geometry is final.
Every netlist-traversal reload passes `reset_undo=0`, so it cannot fire mid-netlist. **Not** the
ERC pass — `netlist.c:1427`'s `print_erc` gate requires `for_netlist`, so a plain open would
never warn.

**Helpers, all verified present:**

| purpose | call |
|---|---|
| popup | `alert_` (`src/xschem.tcl:11729`); C form `if(has_x) tclvareval("alert_ {", msg, "} {} 1", NULL);` (`actions.c:2592`) |
| log window | `ciw_echo` (`src/ciw.tcl:113`) via the metachar-safe form at `src/util.c:425-428`: `tclsetvar("ciw_line", str); tcleval("if {[info procs ciw_echo] ne {}} {ciw_echo $ciw_line}");` |
| detail list | `statusmsg(msg, 2)` → infowindow_text |
| canvas flag | `inst[i].color = -PINLAYER; xctx->hilight_nets = 1;` (`netlist.c:1435` form) |

The `alert_` message is substituted into the eval, so build it from integers and a sanitized
cell name only — **never** raw `lab=` text, which routinely contains `[` and `]`.

**No suppress preference exists generically.** Two layers to add: `set_ne
warn_labels_off_copper 1` in the block at `src/xschem.tcl:15811` plus the tctx save/restore list
at `:13790-13825` (shape precedent: `show_infowindow_after_netlist`), and a persisted breadcrumb
modelled on `write_net_hilight_editor_seen` / `load_net_hilight_conf` (`xschem.tcl:698-711`,
`:737`, `:16178`, default `:16044`). `alert_` has **no checkbox slot** — its args are
`{txtlabel position nowait yesno}` — so a small dedicated dialog proc is needed for
"don't show again". Set `warn_labels_off_copper 0` in `tests/headless/minrc`.

**Wording matters: an off-copper label is a supported idiom, not rot.** Three classes were found:
`verilog_type=` declaration blocks parked off-sheet (`xschem_library/binto7seg/top.sch:50-61`, 12
labels), `type=label` symbols used as pure graphics (`giant_label2.sym`, `segment.sym` in
`xschem_simulator`, 16), and deliberately wireless flyline fixtures (15 `gnd` and others). Do not
say "invalid" or "broken". A `verilog_type=` carve-out kills 12 of 91 outright and is worth
having.

---

## 6. Change list, in dependency order

| # | File:line | Change | Size |
|---|---|---|---|
| 1 | `src/check.c` (new, near `:173`) | `int inst_is_netlabel(int i)`. Exported. **DONE (S1).** | small |
| 2 | `src/xschem.h` | `extern int inst_is_netlabel(int);` near `point_on_wire_or_pin`. `Label_ride` typedef + `label_ride`, `label_ride_n`, `fluid_last_move_label_strands` in `xctx`, beside `fluid_startsel_id`. **DONE (S1)** — `t` and `wsel` dropped, `ox/oy` deferred to S3; see §14.4. | small |
| 3 | `src/move.c:7997-8020` | `fluid_count_label_shorts()` — add the missing arm. Today the `for(w…)` loop `break`s on the first touching wire and counts nothing when **no** wire touches. Add: label had `node[0]` at START, touches no copper at END → `++fluid_last_move_label_strands`. **This is the RED oracle; it fails today.** **DONE**, as a separate `fluid_count_label_strands()` + a START baseline — the `node[0]` half of the rule does not work, see §13.1. | small |
| 4 | `src/actions.c:2061-2063` | R1. `if(inst_is_netlabel(inst)) continue;` right after `symbol = xctx->sym + xctx->inst[inst].ptr;`. Kills the `:2101` stub. **DONE (S1).** | small |
| 5 | `src/move.c` (new statics) | `label_ride_capture()` at `:8189`, `label_ride_apply()` immediately after `:9372` (**not** `:9377` — §11 A), `label_ride_free()` in the `!commit_now` block and on ABORT. **DONE (S1)** — the free must run **after** the apply, not beside `my_free(&fluid_startsel_id)` which precedes it; also called from `clear_schematic`. | large |
| 6 | `src/check.c:708` | R2. `if(inst_is_netlabel(k)) continue;` after `if(xctx->inst[k].ptr < 0) continue;`. **DONE (S2)** — as `if(!label_splits && inst_is_netlabel(k))`, `label_splits` read once per sweep. | small |
| 7 | `src/check.c:173-180` | R2 matched pair. `any_inst_pin_at()` gains a skip-labels arg; label-blind at `:405` and `:795`. **Mandatory with #6.** `point_on_wire_or_pin()` unchanged. **DONE (S2)** — `:405` is the only LIVE consumer; the `:795` edit is consistency only (§15.7), and the pair's asymmetry is §15.1. | small |
| 8 | `src/actions.c:2131` | R3. `&& !inst_is_netlabel(ii)` on the instpin test, killing the tether at `:2158`. **Must ship with RIDE, never before.** | small |
| 9 | `src/move.c:6255` | `fluid_ml_hazards()` block 3b: `if(xctx->inst[i].sel \|\| label_is_rider(i)) continue;`. A label registered to ride is not a stationary merge hazard. | small |
| 10 | `src/xschem.tcl:15733`, `:16260` | `set_ne label_splits_wires 0` (one-release escape hatch), `set_ne label_ride 1` under `cadence_compat_sync`. ~~Tcl mirror of `fluid_last_move_label_strands`~~ — **dropped**, §13.4: none of the sibling counters is declared in Tcl and their non-existence is an asserted contract. **`label_splits_wires` DONE (S2)** — `set_ne` beside `autotrim_wires`, plus `tctx::global_list` so it survives a tab switch like `autotrim_wires` does. No menu entry: it is an escape hatch, not a feature toggle. `label_ride` is S3's. | small |
| 11 | `src/select.c:1705`, `:1797` | **Comment only.** `wire_through_tap_arm()` goes moot for labels — a mid-span label pin no longer coincides with any endpoint, so `endpoint_near` never fires. Stays live for device pins. `select_attached_nets()` itself is **not edited**. | small |
| 12 | `tests/headless/test_wire_split.tcl` | 21 `lab_wire`/`lab_pin` references and **zero** `res.sym` taps — the entire suite uses a label as the split source. Re-author the tap fixtures onto a device pin; add mirror cases (label does NOT split; two stubs under a label DO re-weld; `.sch` stays one `N`). **PARTLY DONE (S1, forced):** the W7 block and its wireedit twin `wireedit/test_wireedit_20_F1_netlabel_tap.tcl` both assert the *label rescue stub* and went red on change #4 — re-authored to the S1 result (no stub, label leashed back, halves weld). **DONE (S2):** every fixture moved to a `devices/res` P-pin tap, each phase gained a label mirror and a `label_splits_wires 1` legacy leg, and a new Phase S2 holds the claims that are new rather than amended (S2a merge, S2b splitter, S2c disk, S2d the §4.4 netlist fix, S2e the D2 gate). 66 → **115 checks**; §15.6. | large |
| 13 | `tests/headless/test_label_ride.tcl` (new) | R1 in both modes (the along-wire repro **must** use `autotrim_wires = 0`), R2, R3, rotate, leash, strand counter. **DONE for S1** (82 checks); R2/R3 legs land with S2/S3. | medium |
| 14 | `doc/claude/specs/wire_segment_splitting.md`, `doc/claude/WIRING.md` | Amend: a `type=label` pin is a naming anchor, not a segment boundary — which the save path already argues at `src/check.c:771-772`. New WIRING § for the rider. Answers WIRING open risk 5 (`:477-480`). | small |

---

## 7. Staging

**S0 — instrumentation. No behaviour change. — LANDED 2026-08-05.**
Change #3 (the strand oracle) plus **issue 0220** (`signal_short()` inert on flat top-level
netlists). Without both, every later stage is blind: measured, a stranded label loses its net
name with `fluid_last_move_violations = 0` and empty stderr. Also worth doing standalone:
make `get_inst_pin_coord()`'s out-of-range `(0,0)` return loud under `dbg`
(`src/netlist.c:766-772`).

*As built* — see §13 for the four design points the implementation had to settle:

| what | where |
|---|---|
| `fluid_label_on_copper(i)` — the pin-aware on-copper predicate | `src/move.c`, above `fluid_snapshot_partition` |
| `Fluid_gesture.strand_id / .strand_nid` — the START baseline, keyed by `inst[].id` | `src/move.c` (struct), captured at the tail of `fluid_snapshot_partition()`, freed in `fluid_discard_snapshot()` |
| `fluid_count_label_strands()` + `fluid_last_move_label_strands` | `src/move.c`, beside `fluid_count_label_shorts()`; published in `fluid_check_move_invariants()` **before** `fluid_gesture_free()` |
| issue 0220: `print_erc` hoisted to file scope, `signal_short()` gated on it, `incr_hilight` cached per run | `src/netlist.c` |
| `get_inst_pin_coord()` out-of-range now `dbg(1, ...)` | `src/netlist.c` |
| tests | `tests/headless/test_label_strand_oracle.tcl` (14 checks), `tests/headless/test_signal_short_nohier_0220.tcl` (11 checks) |

Both suites were verified RED against the pre-change tree — the strand assertions on `<unset>`,
0220's on defect A (`A1`) and defect B (`D0`/`D1`/`D2`) — with every control green on both sides.
`tests/headless/wireedit/` (58 tests) and `tests/headless/run.sh` (6 netlist goldens) stay green,
which is the no-behaviour-change claim.

*Skeptical note:* the `src/findnet.c:292-296` deref that other candidate designs list as a
must-fix is **not a blocker here** — it only bites if a label becomes pinless, which this
design never does. Fix it as hygiene, not as a gate.

**S1 — R1 + LEASH, shipped together. — LANDED 2026-08-05.**
Changes #1, #2, #4, #5 (capture/apply skeleton, LEASH mode only). Result: dragging a label
creates no copper, and a label whose new anchor lands off copper is projected back onto its
owner wire's span. Restores `.sch` byte-stability in the exact gesture complained about —
measured directly: after the perpendicular mid-span label drag the save writes **one** `N`
record, where the pre-S1 tree wrote three.

> **Do not ship the kissing guard (#4) without the leash.** Alone it converts today's
> ugly-but-connected stub into a silent orphan.

*As built* — see §14 for the eight points the implementation had to settle:

| what | where |
|---|---|
| `inst_is_netlabel(i)` — exported, `strcmp(type,"label")` | `src/check.c`, above `any_inst_pin_at` |
| `Label_ride` typedef + `LABEL_RIDE_LEASH`/`_RIDE`; `xctx->label_ride`, `label_ride_n` | `src/xschem.h`, beside `Zoom_info` / `fluid_startsel_id` |
| R1: `if(inst_is_netlabel(inst)) continue;` in the ELEMENT arm | `src/actions.c` `connect_by_kissing()` |
| `fluid_point_on_copper(px,py,skip)` — S0's predicate split out to a point, and **label-aware**: another naming anchor is not copper (§14.1). `fluid_label_on_copper()` delegates. | `src/move.c` |
| `label_ride_capture()` / `label_ride_apply()` / `label_ride_free()` + `label_ride_owner()` (two-step resolution) + `label_ride_run()` (collinear run, §14.4) + `label_ride_project()` | `src/move.c`, above `fluid_check_move_invariants` |
| call sites: capture before `fluid_gesture_arm()`; apply+free immediately after `xctx->ui_state &= ~STARTMERGE;`; free on ABORT, on the zero-delta early return, in `clear_schematic` and in `free_xschem_data` | `src/move.c`, `src/actions.c`, `src/xinit.c` |
| action log records the ARMED kissing flag, not the outcome flag (§14.11) | `src/callback.c` `end_move_copy_logged()` |
| tests | `tests/headless/test_label_ride.tcl` (82 checks); `test_label_strand_oracle.tcl` +2 (B4b/B4c); `test_wire_split.tcl` W7 and `wireedit/test_wireedit_20_F1_netlabel_tap.tcl` re-authored |

Verified RED first — 21 of the 46 checks then written were red on the S0 tree and every control was
green — then green, then re-reviewed adversarially (9 confirmed findings, all fixed; see §14.1,
§14.4, §14.11). Four sabotage variants are pinned: an **id-only** owner resolution loses the label
under `autotrim_wires` (D2/D4/D5/D6 red); a **single-wire** owner instead of the collinear run
reverts a slide by wire record order (S2left red); dropping the **label filter** in
`fluid_point_on_copper()` leashes a label to another label's anchor and blinds the S0 oracle
(P11 + strand-oracle B4b red); and stubbing `label_ride_apply()` reddens 27 checks.
`tests/headless/wireedit/` 58/58, `tests/headless/run.sh` 6/6, `run_regression.tcl` unchanged at the
3 pre-existing `test_ihp_sg13g2_libmgr` FAILs.

**S2 — R2. — LANDED 2026-08-06.**
Changes #6, #7, #12, behind `label_splits_wires` (default 0) so the existing suite can be run
both ways during the rewrite and any netlist diff has a switch rather than a bisect. Also
fixes the measured nameless-label-shorts-a-crossing bug (§4.4).

*As built* — see §15 for the eight points the implementation had to settle, one of which
(§15.3, the 0227 mask) is a **behaviour regression for the target user** and is the reason the
S2/S3 sequencing deserves a second look:

| what | where |
|---|---|
| `label_splits_wires`, default 0, `set_ne` + `tctx::global_list` | `src/xschem.tcl` beside `autotrim_wires` |
| #6: `if(!label_splits && inst_is_netlabel(k)) continue;` | `src/check.c` `break_wires_at_attach_points()` |
| #7: `any_inst_pin_at(x, y, skip_labels)`; its own `label_splits` gate in `trim_wires`, NOT a reuse of `split_active` (§15.2) | `src/check.c` |
| #7 consistency-only twin (the arm is unreachable, §15.7) | `src/check.c` `merge_collinear_wires()` |
| tests | `test_wire_split.tcl` 66 → 115 checks (Phase S2 = S2a–S2e); `test_label_ride.tcl` +7 (D re-authored, DL legacy leg); `test_label_strand_oracle.tcl` +3 (D unmask, DM escape hatch); `wireedit/test_wireedit_20` re-authored |

RED-first: a 12-check probe of the S2 claims was verified red on the S1 tree with every control
green, and the §4.4 short reproduced as `#net1 == #net1` before / `#net1` vs `#net2` after. Four
sabotage variants are pinned and their red sets are **disjoint**: reverting #7 alone reddens only
the two label-weld checks; reverting #6 alone reddens only the CROSSING cases (§15.1 — a plain
mid-span label is silently repaired by the now-label-blind merge, so the crossing is the only
witness); folding the label rule into `split_active` reddens only the 10 legacy-leg checks
(§15.2); and dropping the `!split_active ||` short-circuit reddens only the default-mode checks.
`tests/headless/wireedit/` 58/58, `tests/headless/run.sh` 6/6 (no golden regeneration owed, §12.3
re-asserted by S2c), `run_regression.tcl` unchanged at the 3 pre-existing
`test_ihp_sg13g2_libmgr` FAILs.

**S3 — R3 RIDE, with live clamping.**
Changes #8, #9 plus RIDE mode in #5, with the rotation closed form from the start so translate,
rotate and flip are one code path, and writing `rot`/`flip` per R3. Behind `label_ride`.

Live clamping (§5.4) is **in this stage, not deferred** — with clamping as the permanent model,
release-only apply means the label tracks the cursor perpendicular for the whole drag and then
jumps back. That is a worse experience than today's stub. Open question 1 gates it.

**S5 — R6 wire extension** (§5.5). Small on its own, but it is a wire mutation driven by a label
gesture, so it lands after the ride is stable and after the trim-ordering hazard (B) is closed.

**S6 — R8 delete and copy propagation** (§5.7). Independent of everything above; can be
scheduled whenever. Interacts with issue **0229**.

**S7 — R9 legacy warning** (§5.8). Pure diagnostic, no behaviour change, ships any time after S0.

---

## 8. Issue disposition

| issue | disposition |
|---|---|
| **0220** `signal_short` silent on `-nohier` | **S0 prerequisite.** The only diagnostic for contested-name regressions. |
| **0221** first-writer-wins by record order | Not on the critical path — nothing here moves an anchor at netlist time — but it is *why* a naming regression would be silent. Keep open; reference from this spec. |
| **0223** `place_net_label` commits off copper | **Policy DECIDED in S1 (§14.6), and it does NOT close 0223.** The invariant is *conservation* — no gesture takes a label off copper that was on copper — not *prohibition*: R9 already tolerates 91 shipped labels that sit off copper by design. A newly placed label was never on copper, so it breaks no rule the leash enforces. 0223 stays a UX inconsistency between the two placement paths, to be closed on its own merits under its `cadence_compat` gate. |
| **0225** wire `lab=` back-annotation invisible to modify flag | Independent, though it touches the same `netlist.c:1117` writer. Fix separately; do not fold in. |
| **0227** mid-span label stranded by wire translation | **Close as superseded. Do not implement as filed** — it proposes extending kissing to *rescue* a stranded label with a stub; S1/S3 delete the stub and replace it with the ride. |
| **0228** keyboard stretch paths do not arm kissing | **Split.** The label half is subsumed by S3 (the rider does not need kissing armed). The **device-pin** half remains a real, independent bug — keep it open. |
| **0229** `select_dangling_nets` doc vs code | Unaffected. Its note that the label exclusion is deliberate is consistent with this design. |
| **0222 / 0224 / 0226** | Untouched. |

---

## 9. What is given up, and migration

**Given up:**

1. **Per-segment click granularity at a net label**, in `cadence_compat` only. Clicking either
   side of a mid-span label selects the whole run. This is literally what R2 asks for, but it
   was a deliberate, spec'd feature of `wire_segment_splitting.md`. **Device pins keep it** —
   the res-tap case that motivated the feature is untouched.
2. **The accidental crossing-merge under autotrim.** A label sitting on a wire *crossing*
   stops merging the two nets. Netlist-output change for any existing `cadence_compat`
   schematic that unknowingly depended on it. Scope: a mid-span label on a *single* wire
   produces byte-identical netlists either way (measured); only crossing geometry is
   affected.
3. **`wire_through_tap_arm()` becomes moot for labels** — dead code to annotate, not delete;
   device pins still need it.
4. **`test_wire_split.tcl` must be re-authored, not re-run.** 21 label references and zero
   `res.sym` taps: the suite has no device-pin tap fixture to swap to. **Done in S2** (§15.6).
5. **The issue-0227 mask, and this one is a REGRESSION for the target user.** Added
   2026-08-06 after measuring S2; it was missing from this list and it is the most important
   entry in it. The split put a mid-span label on a wire ENDPOINT, and *two* separate rescues key
   on endpoint coincidence — `connect_by_kissing()`'s wire-endpoint tether (change #8, alive
   until S3) and `select_attached_nets()`' `endpoint_near` ELEMENT arm. Removing the split
   removes both, so a `cadence_compat` user's mid-span label now strands when the wire moves,
   where before it silently survived. It becomes identical to stock-default behaviour rather than
   a new failure mode, and it is exactly what **S3/RIDE** exists to fix — but it is the *filer of
   0227*'s own complaint getting worse in the interim. Full measurement, both endpoint-keyed
   rescues, and the mitigation (`label_splits_wires 1`) in **§15.3**.

**Migration: none. Zero files change on disk.**

No new token, no new record, no field, no version bump. Every existing
`C {devices/lab_*.sym} …` instance is untouched, all 64 `type=label` `.sym` files are
untouched, an older xschem reads new files identically. The in-memory split never reached
disk anyway (`src/save.c:2687-2690`), so no golden file can change on a load/save round-trip.

The only file-content difference is an improvement: today a label drag leaves a redundant
overlapping `N` record (autotrim off) or defeats the coalescer and turns one `N` into three
(autotrim on). After S1 neither happens. Existing residue survives until the next edit;
`xschem trim_wires` clears it.

### The corpus check is done — the split change is connectivity-neutral

Run 2026-08-05. **0 of 5,393 `type=label` instances across 578 tracked `.sch` files** sit in the
only geometry that could change connectivity: a label pin strictly interior to two or more
non-collinear wires.

Corroborated end to end by a netlist A/B: **244 schematics** (`xschem_library/` + `gf180mcuD/`),
SPICE, `autotrim_wires` 0 vs 1 — a deliberate *superset* proxy, since it also disables device-pin
splitting — produced **zero netlist byte differences**, while changing the top-level wire count in
**144 of 244**. Geometry moves; connectivity does not.

The zero is structural, not lucky, and this is what makes it durable:

- `name_attached_inst_to_net()` (`netlist.c:1034`) binds a pin to any wire it `touch()`es,
  interior included — a mid-wire label was never connected *by* the split;
- `wirecheck()` (`netlist.c:1085-1089`) joins two wires when either one's endpoint touches the
  other — T-junctions connect unsplit;
- `trim_wires()` (`check.c:230`) already splits at other wires' endpoints, pin-blind.

**No file needs human review.** Closest case, listed for completeness only:
`xschem_library/gschem_import/TwoStageAmp.sch`, `lab=Vbase1` at (3100, −4970) — a plain
T-junction already joined by `wirecheck`.

Not covered by the sweep: `sky130A/`, `ihp-sg13g2/`, `xschem_libraries_oa/`, `XSchemWin/` were
never scanned; 25 of the 244 netlisted only partially (missing symbol libraries — the xTAG,
`gschem_import`, `viewdraw_import`, `rulz-r8c33` sets) and carry near-zero evidence; only SPICE
was swept, not spectre/verilog/vhdl/tEDAx.

`label_splits_wires` remains as the one-release escape hatch, but it is now insurance rather than
a gate.

---

## 10. Rejected alternatives

**Anchor demotion** — give `type=label` symbols zero `rects[PINLAYER]` at symbol-load time.
The most elegant mechanism: the split and its mirror merge-guard agree by construction,
because there is no pin to split at. **Killed** by `inst[].node`:
`name_attached_inst_to_net()` (`src/netlist.c:1032-1033`) and `name_attached_inst()`
(`:1136`) both filter `if(p >= rects) continue`, so a demoted label is filtered out of both,
silently killing blank-label back-annotation — and the obvious repair walks into an
unguarded `rect[j].prop_ptr` deref in `set_inst_node()` (`:1006`), the issue-0181 crash
family. It also empties every hilight/plot/select path listed in §5.1.

**Wire-owned `netname=`** — put the name on the `N` record and make the label a transient
view. See `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md` §5 for the
full accounting. Summary: abandons the unified label-vs-port loop
(`src/netlist.c:1427-1565`) for a duplicated naming pass across five backends; "for free"
disappears (undo, clipboard, property dialog, delete, paste all become explicit hooks); disk
undo re-stamps wire ids (`src/store.c:369`) so every owner reference goes stale; the payload
lands in `wire.prop_ptr`, where `wire_store_split()` blind-copies it into both halves
(`src/store.c:400`) and trim's merge keeps `wire[i]`'s prop with **no comparison**
(`src/check.c:406-410`); an `nl_*` token family silently closes the currently-open
per-instance token space (`text_size_0` at `src/draw.c:607-608`, the `*_ignore` family); and
it delivers nothing to existing schematics until each file passes an irreversible conversion,
after which an older xschem opens it and renames every net to `#netN`.

**Label-transparent copper** — near-identical to this design, but additionally skips labels
in `select_attached_nets()`' ELEMENT arm (`src/select.c:1783`). **Do not make that edit.**
That arm fires only on `endpoint_near` — i.e. the *end-of-stub* label, the dominant topology
the wire-stub+netlabel feature produces — where the grab stretches the wire to follow,
creating no new wire and preserving the connection. Removing it converts a benign stretch
into a silent orphan.

---

## 11. END-path hazards — resolved

Four hazards. All re-verified against source 2026-08-05.

### (A) The spec's original apply site was dead code — **CONFIRMED**

`src/move.c:9373-9374` zeroes everything the ride needs, four lines before the originally
proposed `:9377`:

```c
xctx->move_rot=xctx->move_flip=0;
xctx->x1=xctx->y1=xctx->x2=xctx->y2=xctx->deltax=xctx->deltay=0.;
```

**Correct site: immediately before `src/move.c:9373`** — the first statement after
`xctx->ui_state &= ~STARTMERGE;` at `:9372`. **Nothing needs stashing there:** wire geometry is
final (last mutation ends `:9351`), `deltax`/`deltay` still hold the gesture totals on every
path (`:9207`, `:9277`, and the `break` at `:9202`), `x1`/`y1` still hold the gesture anchor,
`xctx->rotatelocal` is still live (cleared only at `:9421`), and it precedes the
ROLLBACK-OR-REFUSE block at `:9385`.

Drop the "beside `pin_views_reconcile_after_move()`" wording from §5.3 — that adjacency was the
source of the error. Carry this as a source comment and a spec invariant:

> `label_ride_apply()` must follow the last geometry mutation at `move.c:9351`, and must precede
> the state zeroing at `:9373-9374` and the refuse block at `:9385`.

This is the most dangerous of the four for an implementer: **a no-op ride still looks correct on
an unrotated pure-translate move**, so the bug can ship unnoticed.

### (B) Owner-wire id — worse than assumed; the geometric fallback ships **enabled**

Two distinct failure modes, not one:

- **id destroyed** — the trim merge (`check.c:406-411` + `wire_delete_compact` at `:423`) and
  the whole-inclusion drop (`check.c:314-326`) free the wire; `wire_index_from_id()` returns −1.
- **id survives but is re-spanned off the label** — `wire_store_split` (`store.c:404`) gives the
  *new* HEAD segment a fresh id and the source keeps its id, then `check.c:719-721` rewrites the
  source into the **TAIL**. The captured id still resolves — to a wire that may no longer contain
  the label. **Silent wrong owner.**

Confirmed headless at `autotrim_wires=1`: two abutting wires (ids 1, 2) merge to id 1 (id 2
destroyed); placing `lab_pin.sym` mid-span yields ids 1 and 3, and id 1 is the **tail** — a label
at the original start now sits on the fresh id.

**Contract, two steps, both mandatory:**

```
i = wire_index_from_id(owner);
if(i < 0 || !touch(wire[i].x1, wire[i].y1, wire[i].x2, wire[i].y2, ax, ay))
    → geometric re-find: the collinear wire through the label's anchor point
    → else DECLINE
```

The `touch()` verification is not optional. An id-only implementation binds to the wrong half.

`merge_collinear_wires` (`check.c:779`) destroys no live id — it works on a private copy, and its
sole live caller is `save.c:2690`.

### (C) Refuse/rollback covers instances — **no bespoke rollback needed**

`mem_serialize_slot` copies instances whole-struct (`in_memory_undo.c:390-405`,
`s->iptr[i] = xctx->inst[i];` — carrying `x0`/`y0`/**`rot`**/**`flip`**/bbox/flags/id) plus deep
copies of `lab`/`instname`/`prop_ptr`/`name`; `mem_restore_slot` rebuilds them at `:530-546`. A
refused gesture restores a ridden — moved *and* rotated — label exactly.

Three riders the spec must still state:

1. **The snapshot is conditional.** `move.c:8396-8402` gates it on
   `fluid_editing && fluid_enforce_invariants && stretch_select`, inside a block skipped for
   kissing / `START_SYMPIN` / `STARTMERGE` / `PLACE_SYMBOL` / `PLACE_TEXT`. On a plain non-fluid
   move there is **no refusal path at all** — ride correctness cannot lean on rollback.
2. `mem_restore_slot` does not restore `x1`/`y1`/`deltax`/`deltay`/`move_rot`/`move_flip` or
   `ui_state`/`lastsel` — hence the explicit ritual at `move.c:9396-9402`.
3. Instance ids ride the struct; `inst_id_counter` is restored separately at `:9398`.

### (D) The label pin is not always at the instance origin — **new, and it breaks the invariant**

`lab_pin` / `lab_wire` / `vdd` / `gnd` are origin-centred, but
`xschem_library/devices/bus_connect.sym` has `B 5 9.375 -10.625 10.625 -9.375` → pin centre
(10, −10). Rotating that instance moves its pin ~28 units. **Translate-then-rotate slides such a
label off copper**, which R7 forbids.

Required order of operations:

```
1. pick the TARGET PIN COORDINATE on the (already final) wire
2. apply rot/flip to get the new orientation
3. solve  inst.x0/y0 = target_pin − ROTATION(new_rot, new_flip, 0, 0, pin_offset)
```

`get_inst_pin_coord()` is the forward authority — assert with it, do not reimplement it.

### (E) Double-move when the label is itself selected

The shared ELEMENT commit at `move.c:8974-8995` already moves a user-selected label. The ride
must **skip labels already in the selection**, or they move twice.

---

## 12. Open questions

Answered by the user 2026-08-05 and folded into §2 and §5: rotate/flip carries the label's own
orientation; perpendicular always snaps back to the original owner; no leader line; past-the-end
extends the wire with no guard rails; delete propagates; copy propagates; no migration of
existing schematics.

Settled by the preflight: corpus impact of the split change (§9 — zero), the apply site
(§11 A), owner-id survival (§11 B), refuse/rollback coverage (§11 C), the rot/flip code path
(§5.3), and off-wire warning sizing and helpers (§5.8).

Settled while building S0 (see **§13**): question 3 below; that `node[0]` cannot discriminate a
stranded label so the oracle is geometric and pin-aware; that the strand count is a delta,
published-only, keyed by instance id; and that change #10's Tcl mirror is dropped.

Settled while building S1 (see **§14**): the LEASH half of questions 1 and 2; that the leash's
trigger is "the anchor landed off copper", not an unconditional clamp; that a bare **pin anchor**
must be an owner too, or change #4 orphans the 36 % gnd/vdd-on-a-pin idiom; and issue **0223**'s
policy (conservation, not prohibition).

Still open:

1. **Does the label ride visibly during a live fluid wire drag, or only snap at release?** The
   corrected apply site is inside `if(!commit_now)`, so today the answer is "snap at release".
   The comment at `src/move.c:9327-9333` justifies live firing for wire shoves because *"every
   RUBBER step and the real END each `fluid_reroute_restore()` to pristine and re-derive from the
   TOTAL delta"*, but the pristine snapshot at `:8195` is taken *"Only for a fluid stretch"* and
   it is **not** established whether the restore path returns instance coordinates to pristine on
   every step. → Multi-step RUBBER drag (5 steps) vs single-step END with the same total delta;
   save both; diff. Byte-identical, or live riding needs its own restore.
   **LEASH half SETTLED 2026-08-05 (S1): byte-identical.** A 3-step RUBBER drag and the one-shot
   drag with the same total delta produce the same label position, wire count and span set
   (`test_label_ride.tcl` N8). So live riding is a pure UX addition for the leash, not a
   correctness prerequisite. RIDE (S3), which moves an *unselected* label, is still unmeasured.
2. **Does the corrected placement order handle an off-origin label under rotation?** Hazard
   (D) specifies target-pin-then-rotate-then-solve; it is designed, not measured. → Fixture using
   `xschem_library/devices/bus_connect.sym` (pin at (10, −10)) and
   `xschem_library/xschem_simulator/segment.sym` (pin at (0, 40)); rotate the host wire 90°;
   assert `get_inst_pin_coord(l, 0)` lands on the rotated span.
   **LEASH half SETTLED 2026-08-05 (S1), and the ordering turns out not to be needed there.**
   See §14.3: LEASH corrects the origin the ELEMENT commit already wrote, by the *anchor* delta, so
   it is exact for any pin offset under any rot/flip without ever solving for an origin. Measured
   with `bus_connect.sym` (pin at (10, −10)) translated and rotated 90° (`test_label_ride.tcl`
   N0–N5). RIDE still owes the ordering — it has no committed origin to correct.
3. ~~**Does the on-disk `.sch` actually change today when labels split?**~~ **SETTLED 2026-08-05
   (S0). `save.c:3886-3889` is right; no golden regeneration is owed.** Measured two ways.

   *Controlled fixture* — one wire `(0,0)-(200,0)` with `lab_pin.sym` at `(100,0)`, loaded and
   saved at `autotrim_wires` 0 and 1. At 1 the buffer really does split (`xschem get wires` = **2**
   vs 1); both saves write **one** `N` record. The save-time coalescer runs `merge_collinear_wires`
   **pin-blind** (`ignore_pins = 1`, `save.c:2688-2690`), so the label pin is not a weld barrier.

   *Corpus* — 120 label-carrying `xschem_library/*.sch`, load+save at 0 vs 1, diffing wire-endpoint
   sets. **1 of 120** files keeps a label-pin split on disk:
   `xschem_library/pcb/pcb_test1.sch`, `lab_wire.sym lab=A` at `(700, -460)`. The mechanism is not
   the splitter: `merge_collinear_wires` requires **byte-equal `prop_ptr`** (`check.c:809`,
   `wire_prop_eq`), while `trim_wires`' in-place merge keeps `wire[i]`'s prop with **no comparison**
   (`check.c:406-410`), so one half ends up `{}` and the other `{lab=A}` and the weld is refused.
   That is issue **0225**'s back-annotation churn surfacing through the coalescer, not a
   consequence of the split, and S2 removing the label split makes it strictly rarer.

   Also measured, because it is the fact a "regenerate goldens" instruction would really rest on:
   **105 of those 120 files already differ from their committed form after a plain load+save at
   `autotrim_wires = 0`** — and the diff is the `file_version 1.2 → 1.3` header plus empty `K {}` /
   `F {}` records, nothing to do with wires. Load+save is not byte-stable in this tree for
   independent reasons; do not attribute that to this work.
4. **Delete/copy propagation sizing** (§5.7) — not established by any scan. The delete side
   touches `select.c:780`, the copy side `paste.c`, and it interacts with
   `select_dangling_nets()` semantics (issue **0229**).
5. **Popup storm during a hierarchy descend chain.** `actions.c:3693` passes `reset_undo=1`, so
   the §5.8 hook fires on every descend. Also unknown whether `nowait` alerts stack when a
   `--script` batch opens many schematics under a GUI.

### Not established by any measurement so far

The kissing-stub suppression at `actions.c:2061` / `:2111` — note the second loop is
*wire-endpoint*-driven, so suppressing labels there means testing the **static** instance reached
via `iptr`, not the selected object. Also unmeasured: the along-wire drag extending a wire and
whether the resulting shorts surface in a netlist; the perpendicular snap-back; the new rot/flip
write-out against any golden. All empirical work used the pre-existing `src/xschem` binary
(2026-08-05 13:40), which may not match uncommitted C changes.

### One reframing worth remembering

`autotrim_wires` defaults to **0** (`src/xschem.tcl:15733`) and *every* `maintain_wire_segments()`
caller is gated on it (`actions.c:4449`, `scheduler.c:243`/`:6097`/`:12979`, `save.c:3890`,
`move.c:1098`/`:9046`, `select.c:779`). The label split therefore only fires for users who enable
Auto Join/Trim or `cadence_compat` — which is you, but not the default user. The split guard is a
no-op for a stock-config user, and the test matrix must cover both settings rather than assuming
the default path exercises it.

### Claims deliberately not asserted

- **Corpus size.** Earlier surveys counted 2153 label instances and ~8228 `C {devices/lab_*}`
  lines with different scopes and never reconciled. The number to use is the preflight's:
  **5,393 `type=label` instances over 578 tracked `.sch` files** (a second pass over a slightly
  wider file set counted 5,366 over 589 — same order, same conclusions). Nothing is migrated
  either way.
- **That a wrong `rects[PINLAYER]` stride trips `fluid_count_pins()`'s bailout and silently
  disables all fluid safety** (cited to `src/move.c:2767`). Plausible, unverified; it bears
  only on the rejected anchor-demotion design.
- ~~Ship the geometric fallback disabled.~~ **Superseded by §11 (B):** the fallback ships
  **enabled**, and it must be entered not only when the owner id is destroyed but also when the
  id still resolves to a wire that no longer touches the anchor. An id-only implementation binds
  to the wrong half of a split. This is the single most dangerous finding in the preflight.

---

## 13. Settled while building S0

Four things §6 change #3 stated in one line, that the implementation had to decide. All measured.

### 13.1 `node[0]` is not a strand discriminator — the oracle is purely geometric

§7 S0 says *"label had `node[0]` at START, touches no copper at END"*. The first half does not
work: for a `type=label` instance `inst[].node[0]` is a straight copy of `inst[].lab`
(`src/netlist.c:1491`), assigned before and independently of any wire contact, so a stranded
label still has it. Nothing already captured at START answers "was this label on copper" either —
`fluid_g.snap_pinnet` stores that same `lab`-derived name, and `fluid_g.geo_snap_id` canonicalizes
a floating pin into a singleton indistinguishable from "sole pin on its own net".

So S0 adds a START capture: `Fluid_gesture.strand_id[]`, the instance **ids** of the labels that
were on copper, taken at the tail of `fluid_snapshot_partition()` (which already ran
`prepare_netlist_structs(0)` on pristine geometry) and freed in `fluid_discard_snapshot()`.

**Keyed by `inst[].id`, deliberately NOT by the instance×pin walk index.** It is therefore not a
member of the `snap_id` / `snap_pinnet` / `geo_snap_id` positional family and the landmine at
WIRING.md §7.5 does not apply to it: a gesture that adds or removes an instance leaves it valid.

### 13.2 The predicate is pin-aware, and the two silent traps are closed

"On copper" is **any non-degenerate wire the pin `touch()`es, OR another instance's `PINLAYER` pin
at the exact same coordinate**. The second arm is not optional — §5.8 already measured that
**1,919 labels (36 %)** touch no wire and sit on a device pin, and a wire-only test calls every
one of them stranded. `fluid_label_on_copper()` also closes two traps the sibling
`fluid_count_label_shorts()` still carries:

- `get_inst_pin_coord()` answers `(0, 0)` with no error for an out-of-range pin index
  (`netlist.c:782-785`), so a label symbol with zero `PINLAYER` rects would be probed at the world
  origin and read as connected on any schematic with a wire through `(0,0)`. Gated on
  `rects[PINLAYER] > 0`, and the silent return is now `dbg(1, ...)`-loud.
- `touch()` mishandles a **degenerate** segment (`clip.c:234-245`): the collinear test is trivially
  `0==0` and the axis branch ignores the off-axis coordinate, so a zero-length wire on row *y*
  matches every query on that row. `connect_by_kissing()` mints exactly such point-stubs during a
  gesture, so skipping them is load-bearing, not defensive. Same guard as `fluid_start_deg_at`
  (`move.c:3415`).

Also fixed in passing: `fluid_count_label_shorts()` indexed `xctx->sym[xctx->inst[i].ptr]` before
any `ptr < 0` check, unlike every other fluid instance walk.

### 13.3 The count is a DELTA, published only, and never part of the refuse signal

Absolute would be wrong for the same reason `enf_short_base` exists (issue 0123): 91 labels across
21 shipped files sit off copper *by design*, and an absolute count blames every unrelated gesture
for them. S0 is instrumentation — `fluid_last_move_label_strands` is published beside the other
three counters and is **not** added to `fluid_check_move_invariants()`'s return, so no gesture
changes outcome. It is computed **before** `fluid_gesture_free()`, which destroys the baseline.

Gating inherited from the publisher: `fluid_check_move_invariants()` returns early when
`fluid_editing` is off, so nothing is published then — the contract
`tests/headless/wireedit/test_wireedit_26` already asserts for the sibling vars, and
`test_label_strand_oracle.tcl` case B5 asserts for this one.

### 13.4 No Tcl mirror — change #10's "Tcl mirror of `fluid_last_move_label_strands`" is dropped

None of `fluid_last_move_violations` / `_disconnects` / `_dev_merges` / `_failsafes` is declared,
`set_ne`'d or listed in `tctx::global_list` anywhere in `src/*.tcl`; all four are created on the
fly by `tclsetvar`. That non-existence is itself an asserted contract
(`test_wireedit_26_phase1_runtime_guard.tcl`: "guard skipped when fluid_editing off (var not
published)"). A `set_ne` would break the same property for the new counter. It follows the siblings.

### 13.5 What `autotrim_wires` does to the strand, measured

The split is not a second bug here — it is what **masks** issue 0227 for the `cadence_compat` user,
and the oracle agrees:

| config | kissing | result | strands |
|---|---|---|---|
| `autotrim_wires 0`, mid-span label | armed | wire moves, label left behind, net → `#net1` | **1** |
| `autotrim_wires 1`, mid-span label | armed | split puts the label on an endpoint; kissing tethers it; net stays `VOUT` | **0** |
| `autotrim_wires 1`, mid-span label | **not** armed (issue 0228 keyboard stretch) | net → `#net1` | **1** |

The middle row is the sabotage variant WIRING.md §10 asks for: it goes red the moment the strand
test degrades into an absolute count of off-copper labels.

---

## 14. Settled while building S1

Ten things §5/§6/§11 stated in one line, that the implementation had to decide, plus two an
adversarial review pass caught after the first green build (§14.1's trigger, §14.4's owner run).
All measured.

### 14.1 The trigger is "the anchor left ITS OWNER", not "the anchor is off all copper"

§5.4 reads as an unconditional decomposition ("parallel applied, perpendicular discarded"), and
implemented that way it is **wrong**, because `select_attached_nets()`' ELEMENT arm
(`select.c:1798-1803`) legitimately stretches a wire to follow an end-of-stub label. Measured: the
`m` drag of a label at (0,0) on a wire (0,0)–(200,0) by (0,−100) stretches the wire to
(0,−100)–(200,0) and the label stays connected. An unconditional projection would drag the label
back onto a span that is chasing it.

**First attempt, and why it was wrong too.** The obvious repair — "if the anchor is still on
*copper*, do nothing" — is not equivalent to R7 and an adversarial review caught the difference:
a perpendicular drag that happens to land on a **neighbouring wire**, or on a **parked off-copper
label's pin**, is then judged harmless, so the label deserts its net and renames the copper it
landed on. That is a *regression* against the pre-S1 tree, where the kissing stub kept the label
bound to its own net, and it is silent twice over: the S0 strand oracle shares the predicate and
scores 0. §5.4 is explicit — *"the label stays bound to the wire it started on. No re-attachment,
ever."*

**Shipped rule.** Resolve the owner first; then:

- owner unresolvable (the START anchor no longer lies on it) → **DECLINE**, leave the ELEMENT
  commit's result. This is the load-bearing case: it is what makes the leash yield to a stretch
  that pulled the wire along with the label (`test_label_ride.tcl` I1–I3) and to a rigid move of
  label+wire together (J1–J3);
- the anchor is still on the owner **run** → do nothing, byte-identical (the R6 slide, A1–A7);
- otherwise → project onto the run, clamped (B, C, D, E, F, M, P, S, N).

So "landing on other copper" is a re-attachment and is refused: a neighbouring wire (P1–P4), a
device pin (P5–P7), another label's anchor (P8–P10). To move a label to different copper the user
takes the **disconnected** move (Shift-M / Ctrl+LMB), which is not leashed — §14.5, case K1.

Sabotage-verified: stubbing `label_ride_apply()` turns 27 checks red across B/C/D/E/F/G/M/N/P/R/S.

### 14.2 A bare PIN ANCHOR must be an owner, or change #4 orphans 36 % of shipped labels

§5.3's owner is "the wire the label was sitting on". 1,919 shipped labels (§5.8) sit on a **device
pin with no wire at all**, and what keeps them attached during a drag today is precisely the
`connect_by_kissing()` stub that change #4 removes. Measured pre-S1: dragging a `lab_pin` off a
resistor pin created a rescue wire; with #4 and a wire-only owner it would just detach.

So a rider whose anchor has no wire under it but does have another instance's pin there records
`wid = 0` and a **degenerate owner span equal to the anchor point** — the projection then returns
the anchor and the label springs back (`test_label_ride.tcl` G1–G3). A label with *nothing* under
its anchor gets no rider at all and moves freely (L1–L3): R9 tolerance, see 14.6.

### 14.3 Hazard (D) does not arise for LEASH — correct the committed origin by the ANCHOR delta

§11 (D) prescribes target-pin → rot/flip → solve-for-origin, because rotating an instance whose pin
is off-origin (`bus_connect.sym`, pin at (10, −10)) moves the pin ~28 units. LEASH never solves for
an origin: the ELEMENT commit (`move.c`, the `case ELEMENT` walk) has **already** written
`ROTATION(pivot, START origin) + delta` and composed `rot`/`flip`, so the apply reads the resulting
pin with `get_inst_pin_coord()` — the forward authority — and translates the origin by
`target − current_pin`. A translation moves origin and pin by the same vector, so it is exact for
any pin offset, any rotation and any flip, with no formula to get wrong.

That also settles the `+2` term worry for S1: LEASH writes no `rot`/`flip` at all. S3's RIDE, which
must place an *unselected* label from scratch, still owes both the ordering and the verbatim bake.

Measured with `bus_connect.sym` under a plain translate and under translate+rotate-90
(`test_label_ride.tcl` N0–N5).

### 14.4 The owner is a collinear RUN, not a wire record

`label_ride_capture()` binds to the first wire in `xctx->wire[]` whose span contains the anchor.
That is not enough, and the failure is loud in exactly the target environment: `autotrim_wires`
splits a wire at every attachment point, so a mid-span label normally sits at the **shared
endpoint of two collinear halves** and both `touch()` its anchor. Clamping to whichever comes
first in the array makes the leash's output a function of **wire record order** — a legitimate R6
slide toward the other half is reverted to the junction and the label does not move at all,
silently. §14.7's transient weld hides this only when the halves can re-weld; a device pin at the
junction blocks the merge (`any_inst_pin_at`, `check.c:405`) and makes the wrong owner permanent.
Measured: the same geometry built in the two wire orders gives results 400 units apart.

`label_ride_run()` therefore grows the resolved owner across every collinear wire it abuts,
working in the parametric coordinate along the captured owner direction so that "abuts or
overlaps" is a closed-interval test and the growth iterates to a fixed point. Membership is exact
(cross products against 0, never against a length tolerance — the `wire_through_tap_arm()` rule),
degenerate wires are skipped throughout, and a perpendicular branch or a collinear wire across a
gap is never absorbed. Split points become invisible to the leash — which is what S2 will make
true of the data model itself. Sabotage-verified: disabling the growth loop turns `S2left` red.

### 14.5 The struct lost `t` and `wsel`, and gained the captured owner SPAN

`t` (parametric position) and `wsel` are unread in S1: the projection runs from the END anchor onto
the END span, and the trigger is "off copper", which needs neither. Carrying unread per-gesture
scratch is the landmine WIRING §7.9 names, so they are gone until S3/S5 needs them.

What was added instead is the **owner span at capture** (`sx1..sy2`). It is load-bearing twice: it
is the collinearity key for §11 (B)'s geometric re-find, and for `wid == 0` it *is* the owner. And
`ox/oy` are deferred to S3 for the same reason — LEASH corrects a committed origin (14.3), so it
never needs the START one.

The "ABSOLUTE, never `+=`" rule of §5.3 is honoured in substance: the correction is applied once,
at the real END, to geometry that is itself a pure function of START-state + total delta (a
non-fluid gesture commits once; a fluid one `fluid_reroute_restore()`s to pristine first). It is
also idempotent by construction — projecting an already-projected point onto the same span moves
nothing. Confirmed by the stepwise-vs-one-shot measurement (§12 question 1).

### 14.6 The gate is `connect_by_kissing`, and that makes the rigid move a *deliberate* detach

§5.6 gates LEASH on `xctx->connect_by_kissing`. That is the right gate and it is worth stating why:
kissing is armed by exactly the CONNECTED drag (`m` under `cadence_style_rc`, every mouse stretch
entry point), which is the gesture whose stub change #4 removes. Gating them identically makes S1 a
**replacement**, not an addition: off the kissing path — Shift-M, the Ctrl+LMB detach, the issue
**0228** keyboard stretch paths — nothing changes at all, and a label dragged rigidly off its wire
still detaches and still scores `fluid_last_move_label_strands = 1`.

`test_label_ride.tcl` K1/K2 pin that as policy so a later stage cannot flip it by accident.

### 14.7 Issue 0223: the invariant is CONSERVATION, not prohibition

§8 says 0223 "becomes a policy decision inside S1", and the two must not contradict. The rule S1
adopts:

> **No gesture may take a label OFF copper that was ON copper.** Being off copper is not itself
> illegal.

R9 already requires the second half — 91 labels across 21 shipped files sit off copper by design
(`verilog_type=` blocks parked off-sheet, `type=label` symbols used as pure graphics, wireless
flyline fixtures) and §5.8 explicitly refuses to call them broken. So the leash conserves an
existing attachment and says nothing about creating a label with no attachment.

**Therefore S1 does not close 0223 and does not argue for closing it.** A label placed off copper by
`place_net_label()` was never on copper, so it violates no conservation rule; 0223 remains a UX
inconsistency between the two placement paths (the modern Add-Wire-Label form refuses, the legacy
path commits) and should be closed on its own merits under the `cadence_compat` gate it drafts —
not as a corollary of the leash. `test_label_ride.tcl` L1–L3 pins the boundary: an already-off-copper
label is free to move.

### 14.8 Under `autotrim_wires` the split halves WELD during the gesture, transiently

New, not predicted. The apply site is mandatorily after the last geometry mutation (§11 A), which
puts it after `maintain_wire_segments()`. So the cleanup pass runs while the dragged label is
transiently off the split point, `any_inst_pin_at()` (`check.c:405`) sees nothing there, and the two
collinear halves **merge**; the leash then puts the label back mid-span. Measured: 2 wires → 1.

Consequences, all benign, none silent:

- Connectivity is unchanged (`touch()` is interior-inclusive; corpus-verified in §9), and the
  measured node map of the tapped device is identical before and after.
- The weld **destroys the captured owner id**, which is why §11 (B)'s two-step resolution is not
  optional. Sabotage-verified: an id-only `label_ride_owner()` loses the label, the net reverts to
  `#net1` and the S0 strand oracle scores 1 (`test_label_ride.tcl` D2/D4/D5/D6 red).
- The weld is **transient** — the next edit's `maintain_wire_segments()` splits again (D6). S2
  removes the label split for good and makes the welded form the resting state.
- Residual risk, bounded and pre-existing: `trim_wires`' in-place merge keeps `wire[i]`'s `prop_ptr`
  with **no comparison** (`check.c:406-410`), so if a user had diverged the two halves' `lab=`, one
  is dropped. That is issue **0225**'s class, it is newly *reachable* here only because the stub
  that used to block the degree-2 merge is gone, and S2 retires it.

### 14.9 The COPY path gets change #4 but not the leash — deliberately

`copy_objects()` (`move.c:674`) is a separate entry point: it calls `connect_by_kissing()` itself
and never goes through `move_objects()`, so `label_ride_capture()` never runs for a copy.
Measured consequence: Shift-drag-copying a net label off its wire used to mint a connecting stub
and now simply places the copy off copper. That is upstream XSCHEM's own flow — *drop a
`lab_wire` in free space, then draw a wire to it* — and it is the shape R8/S6 (copy propagation)
will formalise; inventing copper for a copied name is exactly the artifact §5.1 set out to delete.
A DEVICE-pin copy still kisses. Pinned by `test_label_ride.tcl` Q1–Q3.

Note this is also why the flag lifetime of `xctx->connect_by_kissing` matters to S1: the leash
reads it at move START. It is armed only by the mouse/keyboard stretch entry points and the
scheduler's `move_objects`/`copy_objects` verbs, and reset at move END/ABORT — issue **0228**'s
"flag lifetime" risk note applies unchanged, and a leaked `2` would arm the leash rather than
break it (the capture still requires the label to be on copper at START).

### 14.10 Two existing suites assert the label rescue stub and had to be re-authored in S1

§6 change #12 schedules the `test_wire_split.tcl` rewrite for S2. Two blocks could not wait,
because change #4 deletes the stub they assert:

- `tests/headless/test_wire_split.tcl` **W7** — "run intact + single stub"; and
- `tests/headless/wireedit/test_wireedit_20_F1_netlabel_tap.tcl` **F1**, its wireedit twin and a
  declared *ground-truth green anchor*.

Both fixtures tap a run with a **net label**, so both now see: no stub, the label leashed back onto
the run, and the two halves welded at the label's old tap (14.7). Both keep their real claim — the
through-run is not jogged into a U-detour — and both keep P1 connectivity and the device node map
green. The resistor tap in each fixture is untouched, which is the point: this is a label rule, not
a pin rule.

### 14.11 Three lifecycle holes the review found, all closed

Small, but each is the kind that only shows up in a leak report or a replay diff:

- **`end_move_copy_logged()` logged the OUTCOME flag, not the ARMED one** (`callback.c`). The
  action log recorded ` kissing` from `xctx->kissing` — connect_by_kissing()'s "I stored at least
  one stub" return — which used to be a safe stand-in for "this was a connected drag". S1 breaks
  that equivalence exactly: a connected drag of a lone net label now deliberately stores no stub,
  so the logged line lost its ` kissing` keyword and **replaying the log produced a rigid move** —
  a different schematic and a different netlist from the gesture that was recorded. Now logs
  `xctx->connect_by_kissing || xctx->kissing`.
- **The `drag_elements && delta==0` early return** (`move.c`) clears `stretch_select`,
  `stretch_grabbed_xy` and `fluid_startsel_id` but skipped the rider set, so a press-and-release
  inside one snap cell left it allocated past its gesture. Not exploitable — the next START frees
  it — but it broke the documented "`fluid_startsel_id` lifecycle exactly". Now freed there too.
- **`free_xschem_data()`** (`xinit.c`) never released it, so closing a tab or the window
  mid-gesture leaked it with the ctx (valgrind: 64 bytes/rider). Fixed; the pre-existing siblings
  (`stretch_grabbed_xy`, `fluid_startsel_id`, the fluid reroute snapshot) have the same gap and are
  flagged in a comment there for a shared teardown helper.

Two test claims the same pass found **hollow**, both now fixed: N3/N4 rotated about the default
pivot, which left the pin on the wire's own endpoint so the leash never fired and the raw ELEMENT
commit satisfied them (now `-anchor 100 0` + a delta that clears the span); and N8's stepwise leg
omitted `stretch`, so no `fluid_reroute` snapshot was taken and no RUBBER step could live-commit —
the equality held for any implementation, including none. Both are sabotage-verified against a
stubbed `label_ride_apply()`.

---

## 15. Settled while building S2

Eight things §5.2/§6/§7 stated in one line, that the implementation had to decide. All measured
2026-08-06 against the S1 tree at `8fee6129` and then against the S2 build. **§15.3 is the one
that changes a decision, not just a detail.**

### 15.1 Changes #6 and #7 must ship together, but their symptoms are NOT symmetric — the witness is a CROSSING

§6 marks #7 "**Mandatory with #6**" and §5.2 gives the reason: splitting without relaxing the
merge yields a wire that can never re-weld. That half is directly observable — two abutting
collinear wires with a label at the joint simply never weld, and sabotage-verified it reddens
exactly two checks (`W0/S2`, `S2a`).

The other half is not, and that was worth learning before writing the test. **Reverting #6 alone —
splitter still cuts at labels, merge now label-blind — leaves a plain mid-span label at ONE wire
anyway.** `maintain_wire_segments()` is `break_wires_at_attach_points()` then `trim_wires()`, so
the split is created and welded back inside the same call and `xschem get wires` looks correct. It
is not correct: the sheet is being cut and re-welded on every edit, with `trim_wires`' `changed`
arm firing `set_modify(1)` for nothing.

The case that cannot be repaired that way is a label at a wire **CROSSING**: four wire endpoints
meet at the joint, so `end1`/`end2` are non-zero, the merge is refused on the cheap test before
`any_inst_pin_at()` is ever consulted, and the split is **permanent** — 4 segments and the §4.4
short. So the test that enforces "must ship together" in the #6 direction is the crossing case
(`S2b`, `S2d`, `W5 T3c`), not the mid-span one. Sabotage-verified: reverting #6 alone reddens
exactly those four checks and nothing else.

### 15.2 `label_splits_wires` needs its own gate; folding it into `split_active` breaks the ESCAPE HATCH, not the default

`trim_wires()` caches `autotrim_wires` once per call as `split_active`, and the merge refusal is
gated on it so the default (autotrim-off) trim/join stays byte-for-byte unchanged and the
`O(inst·pins)` probe is short-circuited off that path — `wire_segment_splitting.md` **D2**, and it
is load-bearing. The obvious economy is to pass `split_active` as the new skip-labels argument.

It is wrong, and it is wrong in the direction that testing the *default* cannot catch: the S2
default behaviour is still correct and every S2 check stays green. What breaks is
`label_splits_wires 1` — labels are skipped there too, so the switch no longer restores pre-S2
behaviour. A one-release escape hatch that does not switch is worse than no hatch, because the
next netlist difference gets bisected instead of toggled. Sabotage-verified: folding the gate
reddens **10 legacy-leg checks across three files** (`W0/S2 legacy`, `W1/S2 legacy`,
`W2 T2 legacy`, `W3 T4 legacy`, `W7b legacy`, `DL0`, `DL6`, `DM0`, `DM1`, `DM2`) and nothing else.
So the two gates are independent: `split_active` decides *whether pins are boundaries at all*,
`label_splits` decides *which pins count*. Device-pin behaviour is unchanged in either autotrim
mode, asserted by `S2e`.

### 15.3 S2 removes the mask that was protecting issue 0227 for the `cadence_compat` user

**This is a regression for the person who filed 0227, it was not in §9, and it is the strongest
argument for landing S3 alongside S2 rather than after it.**

§13.5 row 2 already recorded the mechanism without naming it a dependency: under
`autotrim_wires`, "the split puts the label on an endpoint; kissing tethers it; net stays `VOUT`;
strands **0**". That is not a property of the label — it is a property of the **split**, and S2
deletes the split. Two *separate* rescues key on endpoint coincidence and both stop firing for a
mid-span label:

- `connect_by_kissing()`'s **wire-endpoint arm** (`actions.c`, change #8, deliberately alive until
  S3) minted the tether stub only because the stationary label's pin coincided with the moving
  halves' shared endpoint. Interior to a single wire, the arm finds nothing.
- `select_attached_nets()`' **ELEMENT arm** fires only on `endpoint_near` (`select.c`) — which §6
  change #11 already predicted "goes moot for labels", filed there as a *comment-only* change.
  That arm is what used to make a `stretch`-without-`kissing` drag of a mid-span label carry its
  wire along.

Measured 2026-08-06, one gesture — **issue 0227's own repro: label stationary, wire translates,
kissing armed** — across three configurations:

| config | wires | `fluid_last_move_label_strands` | resolved net |
|---|---|---|---|
| `autotrim_wires 0` (stock default) | 1 | **1** | `#net1` |
| `autotrim_wires 1`, `label_splits_wires 1` (pre-S2) | 3 | **0** | `VOUT` |
| `autotrim_wires 1`, `label_splits_wires 0` (**S2**) | 1 | **1** | `#net1` |

And the same three rows for a label-moving `stretch` without `kissing` (the `W7b` fixture, issue
**0228**'s cell): pre-S2 `GB`, S2 `#net1`, stock default `#net1`.

What that does and does not mean:

- **Not a new defect class.** S2 makes the `cadence_compat` user behave *exactly* like a
  stock-config user, who has stranded on this gesture since forever. No new failure mode is
  invented and nothing that was correct becomes incorrect.
- **But it is strictly worse than yesterday for the target user**, whose whole environment is
  `cadence_compat`, and whose original complaint is 0227.
- **The LEASH is untouched**, which was the prediction and is now measured: the label-*dragged*
  direction scores 0 strands in all three configs, because `label_ride_run()` already grew the
  owner across collinear split points on purpose (§14.4). S2 is a no-op for S1, confirmed by
  running `test_label_ride.tcl` with `label_splits_wires` both ways.
- **Mitigation, and it is now load-bearing rather than insurance:** `set label_splits_wires 1`
  restores the mask exactly. §9's closing line ("insurance rather than a gate") was written
  before this was known and is superseded for as long as S3 is outstanding.

Recommended sequencing consequence: either ship S2 and S3 together, or default
`label_splits_wires` to **1** until S3 is in and flip it with S3. Recorded as ground truth, not
prose: `test_label_strand_oracle.tcl` D0–D2 (the unmask) and DM0–DM2 (the hatch restoring it),
`test_wire_split.tcl` `W7b/S2` + `W7b legacy`.

### 15.4 The label still NAMES what it no longer cuts, and that is asserted rather than assumed

The whole design rests on `touch()` being interior-inclusive in `name_attached_inst_to_net()`
(`netlist.c`), so removing the split must not remove the name. Cheap to assert and easy to lose,
so it is asserted at four independent places: the welded run keeps `lab=GB` (`W0/S2`), two
mid-span labels still name an unsplit run (`W1/S2`), a label placed mid-span names it without
splitting (`W3 T4b/S2`), and the exact-vs-near distinction still governs naming with no split in
either case (`W5 T8/S2`, `T8b/S2`). `W2 T2 legacy` closes the loop by asserting the resistor's
node map is byte-identical across the `label_splits_wires` switch — which is what "§9,
connectivity-neutral" means operationally.

### 15.5 `point_on_wire_or_pin()` was not touched, and the two point predicates still disagree on purpose

§5.2 keeps it label-aware (a label landing on another label's pin is a legitimate Add-Wire-Label
drop target) while S1's `fluid_point_on_copper(px, py, skip)` is label-**blind** (a naming anchor
is not copper, §14.1). S2 adds a third, unrelated axis — whether a pin is a *segment boundary* —
and it belongs to neither: `any_inst_pin_at()` owns it. All three now carry a comment naming which
question they answer, because the failure mode of picking the wrong one is silent in every
direction.

### 15.6 Change #12 was a re-author of the whole suite, and the legacy legs are how "run it both ways" is actually realised

§6 sized it right: 21 `lab_wire`/`lab_pin` references, **zero** `res.sym` taps, so there was no
device-pin fixture to swap to and each had to be authored. `devices/res` at `(X, T+30)` rot 0
flip 0 taps `(X, T)` with pin `P` and dangles `M` at `(X, T+60)`; every fixture keeps that `M`
coordinate clear of other copper on purpose, and `S2d` asserts two of the tap coordinates so a
future `res.sym` geometry change cannot make the case vacuous instead of red.

Each phase now carries up to three legs — the device-pin leg (the machinery, unchanged), the label
mirror (the S2 claim), and a `label_splits_wires 1` legacy leg. The legacy legs are not
redundancy: they are the only remaining coverage for two things. (a) The escape hatch really
switching (§15.2). (b) **Hazard (B)'s geometric re-find.** §14.8's transient weld was what
destroyed the captured owner id, and it only happened *because* the wire was split at the label;
under the S2 default no split exists, the owner id survives, and `test_label_ride.tcl` D2 stopped
exercising the re-find at all. `DL2` (and `DM1` in the strand oracle) carry it now. 66 → **115
checks** in `test_wire_split.tcl`; `test_label_ride.tcl` 82 → 89; `test_label_strand_oracle.tcl`
16 → 19.

### 15.7 `merge_collinear_wires()`' pin-aware arm is still dead code; its edit is consistency only

`any_inst_pin_at()` has exactly two call sites. `check.c`'s `trim_wires` merge refusal is the
**only live one**; `merge_collinear_wires()`' arm is unreachable on the current call graph because
its sole caller (`save_wire()`, `save.c`) passes `ignore_pins = 1` — that pin-blindness is what
makes the save coalesce collapse the split, i.e. §12.3's "nothing reaches disk". The skip-labels
argument is threaded through it so a future unification of the two merge sites cannot silently
inherit the pre-S2 rule, and the `tclgetboolvar()` read is skipped when `ignore_pins` is set so the
save path costs nothing. **No behaviour change is claimed for it and no test pretends to exercise
it.**

### 15.8 Nothing new reaches disk, re-asserted by test rather than re-measured

§12.3 settled this and S2 does not reopen it: the save-time coalescer is pin-blind, so the label
split never persisted, and removing it cannot change a golden. Rather than re-run the 120-file
corpus, `S2c` asserts the invariant directly — the same source file saved under
`label_splits_wires` 0 and 1 produces one `N` record and **byte-identical output** — and
`tests/headless/run.sh`'s 6 netlist goldens are green unchanged. The one file §12.3 found keeping a
label-pin split on disk (`xschem_library/pcb/pcb_test1.sch`, via issue **0225**'s divergent
`prop_ptr`) is now strictly unreachable through a label, which is the "S2 retires it" of §14.8.
