# Wire-stubs + auto net-labels on instance pins

Status: **SPEC / PLAN — not started.** Written 2026-06-29 on branch `fluid-editing`.
Author handoff doc: a future Claude Code session can pick up this thread from here.

Related specs/notes:
- `doc/claude/specs/pin_selection.md` — individual pin selection (the input layer this
  feature consumes). Pin selection explicitly names "create a wire-stub for a specific
  pin" as its planned next step. See also the `[[pin-selection]]` memory.
- `doc/claude/specs/*` action-registry / cadence-modifier-drag for the house style of
  wiring up a new user-facing edit op.

---

## 1. Goal (the original request)

Add an edit operation that draws **wire stubs** out of instance pins and attaches an
**auto net-label** (a `lab_pin` "flag") at the far end of each stub.

Requirements as stated by the user:

1. **Stub length.** The stub wire is long enough that its length is **greater than 2×
   the height of the net-label text** placed at its end.
2. **Label text size = the pin's text size.** The net-label text is rendered at the
   same text size as the pin's name-text on the symbol of the instance being processed.
3. **Whole-instance selected → label every unconnected pin.** When only an instance is
   selected, every pin that is **NOT already connected to a wire** gets a stub + label.
4. **Label orientation = "flag in the wind."** The label's attachment point sits next
   to the instance (at the stub's far end), and the rest of the text extends *away* from
   the instance body — as if a wind blowing out of the pin pushes the text outward.
5. **Multiple pins → median sizing.** When several pins are processed, the text size
   (and therefore the stub length) is derived from the **median** of the pins' text
   sizes on the symbol.
6. **Pins selected → only those.** When individual pins are selected, only those pins
   get stubs + labels (not the whole instance).

---

## 2. The blocker we hit, and the decision

### 2.1 Why "the pin's text size" is currently ill-defined

In xschem a pin is **not** a thing that owns its name text. A pin is:

- an `xRect` on `PINLAYER` inside the `xSymbol` (`sym->rect[PINLAYER][j]`,
  count `sym->rects[PINLAYER]`), whose `prop_ptr` carries `name=...` and `dir=...`
  (`get_tok_value(rect->prop_ptr, "name", 0)`).

The **visible** pin-name text, when present, is a *separate, hand-authored* `T {}` text
record in the symbol with no structural link to the pin. Evidence from
`xschem_library/devices/nmos4.sym`:

```
B 5 17.5 -32.5 22.5 -27.5 {name=d dir=inout}      <- pin rect, name=d
B 5 -22.5 -2.5 -17.5 2.5  {name=g dir=in}         <- pin rect, name=g
...
T {D} 25 -27.5 0 0 0.15 0.15 {}                    <- a "D" label, size 0.15, near the drain
T {@#1:net_name} -25 -12.5 0 1 0.15 0.15 {layer=15 hide=instance}   <- per-pin NET name, hidden
```

Note: only the drain shows a visible "D"; g/s/b have **no visible name text**. The
string "D" doesn't even equal the pin's `name=d`. The only per-pin-bound text records
are the `@#<idx>:net_name` ones, which are on hidden `layer=15`.

**Conclusion:** there is no reliable 1:1 mapping pin → "its" name-text, so
"the text size of the pin" has no clean definition in today's data model.

### 2.2 Decision: do the Cadence-style pin-name prerequisite FIRST

The user's chosen path: **change symbol pins to be like Cadence first** — a pin should
*own* its default name text, and that text is the pin's name. Once pins own their name
text, "the pin's text size" is well-defined and the wire-stub feature can read it
directly. This splits the work into two threads, done in order:

- **Thread A (prerequisite, do first):** pin-owned name text — see §3.
- **Thread B (the original request):** wire-stub + net-label — see §4. Built on top of A.

---

## 3. Thread A — Cadence-style pin-owned name text (PREREQUISITE)

> **Now has its own detailed plan: `doc/claude/specs/cadence_pin_name_text.md`.** That
> doc supersedes this section — it found that xschem ALREADY represents a pin-name label
> as a real `T` text (created by `add_symbol_pin`, weakly synced in `editprop.c`), and
> plans to formalize that into true ownership (Model B: real bound text + `pinlabel=true`
> marker + `show_pinname` flag + cascade-delete + two-way name sync + a Python migration
> script). The summary below is kept for context.

### 3.1 Intent

A pin's name (`name=` on the PINLAYER rect) is automatically drawn as text that
"belongs to the pin": positioned relative to the pin, at a text size that is a property
of the pin. The symbol author no longer hand-places a `T {}` per pin (though legacy
symbols that do must keep working — see backward-compat below).

### 3.2 Key code locations (verified)

- **Pin storage:** `xSymbol.rect[PINLAYER][j]`, count `sym->rects[PINLAYER]`
  (`src/xschem.h` ~610-648). Pin name/dir from `rect->prop_ptr` via `get_tok_value`.
- **Symbol drawing:** `draw_symbol()` in `src/draw.c:622`. PINLAYER rects are drawn in
  the rect loop at `src/draw.c:780-821`. Symbol texts are drawn in the `draw_texts:`
  block at `src/draw.c:823-890+`. **Thread A hooks in here**: after/in the PINLAYER
  rect loop (or in a parallel pass), render each pin rect's `name=` as text.
- **Text sizing precedent:** `get_sym_text_size()` `src/draw.c:588-615` resolves a
  symbol text's `xscale/yscale`, honoring a per-instance `text_size_<n>` override in the
  instance `prop_ptr`, else falling back to the symbol's `xText.xscale/yscale`.
- **Text rendering:** `draw_string(layer, what, txt, rot, flip, hcenter, vcenter, x, y,
  xscale, yscale)` `src/draw.c:477-536`. Text extent via `text_bbox(...)` (see §4.4).

### 3.3 Open design questions for Thread A (decide at implementation)

1. **Where does the pin's text size live?** Candidates:
   - a new per-pin attribute on the rect `prop_ptr`, e.g. `name_size=0.2` (clean,
     self-describing, persists in `.sym`); default if absent.
   - a symbol-level / global default pin-name size (Tcl var, e.g. `sym_pin_name_size`).
   - Recommendation: **per-pin `name_size=` attribute, with a global default fallback.**
     This is exactly the value Thread B will read as "the pin's text size."
2. **Position / anchor of the auto name text.** Cadence draws the pin name just inside
   (or just outside) the pin, oriented along the pin. Need a rule from the pin rect
   geometry + the pin's facing direction (see §4.3 outward-direction logic — reuse it).
   Likely: anchor at the pin center, offset slightly toward the symbol body, with
   `hcenter/vcenter` chosen by facing side.
3. **Opt-in flag + backward compatibility.** Legacy symbols already carry hand-placed
   pin-name `T {}` records; auto-drawing would double them. Options:
   - global toggle (Tcl var, e.g. `show_pin_names`, default OFF) so existing symbols are
     byte-for-byte unchanged unless enabled;
   - or a per-symbol/per-pin opt-in attribute.
   - Recommendation: a global toggle defaulting OFF for safety, mirrored C↔Tcl
     (`MIRRORED IN TCL`, see `src/xschem.h`), plus the per-pin `name_size=`.
4. **Color/layer.** Pin name text should likely use the PINLAYER text color
   (`TEXTWIRELAYER` / `PINLAYER`, see the `PIN_OR_LABEL` handling at `draw.c:827`,
   `draw.c:841`).

### 3.4 Thread A deliverable

After Thread A, there is a function to read **the pin's own text size** for pin `j` of
the symbol (e.g. `get_pin_name_size(sym_or_inst, j) -> double yscale`). That is the
single source of truth §4 consumes. Implement and unit-test this getter first; the
wire-stub feature depends only on it, not on the drawing.

> **DONE (P9, 2026-07-01).** `double get_pin_name_size(xSymbol *sym, int pin)` in
> `src/actions.c` (declared `src/xschem.h`): returns the pin rect's `name_size` token,
> else **`0.2` — the SAME fallback `get_pin_name_layout()` uses to RENDER the name**, so the
> size reported here always matches what `draw_symbol` draws. (It deliberately does NOT track
> the create-time `sym_pin_name_size` Tcl var: that var is the initial size stamped on a NEW
> pin, but the read-fallback must equal the render fallback or the stub/label would be sized
> differently from the on-screen pin text — code-review fix, 2026-07-01.) A NULL symbol or
> out-of-range/negative pin also returns `0.2` rather than erroring, so §4.2 can `median` a
> mixed pin set without special-casing missing pins. Exposed headless as
> **`xschem get pin_name_size <inst> <pin> ?<win>?`** (`src/scheduler.c`, resolves
> `xctx->sym + xctx->inst[inst].ptr`, guarded on `inst.ptr>=0` for a symbol-less instance) —
> that command is Thread B's read path AND the unit hook. The optional `<win>` is a
> window-path (`xschem get current_win_path`, e.g. `.drw` / `.x1.drw`): every `xschem` command
> binds to the *current* window's `xctx`, so with a symbol/other window front
> `[xschem get instances]-1` and the query read the wrong context ("instance index out of
> range"); `<win>` borrows the addressed window's context for the one command
> (`net_hilight_borrow_ctx`, no focus change, balanced restore). A `borrow -> NULL` for a
> NON-current `<win>` (unknown path, or a known-but-unallocated slot) errors rather than
> silently reading the front window — same idiom as `get net_hilight_animated` (this catches
> the known-but-unallocated case a bare `net_hilight_win_known` guard would miss). Coverage:
> `tests/pin_name_text.tcl` §17 + the two-window GUI test
> `tests/headless/test_pin_name_size_win.tcl` (9 checks, reproduces the wrong-window bug then
> fixes it via `<win>`). Sabotage-verified. **This unblocks Thread B (§4): start at B1.**

---

## 4. Thread B — wire-stub + net-label feature

### 4.1 Selection model — what to process

Use the existing pin-selection plumbing (`doc/claude/specs/pin_selection.md`):

- Call `rebuild_selected_array()` then scan `xctx->sel_array[0..lastsel)`.
- **If any `INST_PIN` entries exist** (`type==INST_PIN(=128)`, `.n`=instance index,
  `.col`=pin index): process exactly those (pin, instance) pairs. (Req. 6)
- **Else if a whole instance is selected** (`type==ELEMENT`): process every pin of that
  instance that is **not already connected** (Req. 3). Enumerate pins
  `0..sym->rects[PINLAYER)`.
- A pin is **"connected"** if a wire endpoint, a wire passing through, or another
  instance pin coincides with the pin's absolute coordinate — query via the spatial
  hash (see §4.5). (This is the proposed default rule; confirm.)

Selected pins live in `xInstance.pin_sel[]` (+ `pin_sel_size`); `rebuild_selected_array`
(in `src/move.c`) emits one `INST_PIN` Selected per set bit. Pin enumeration helper:
`get_inst_pin_coord(i, j, &x, &y)` `src/netlist.c:753-773` gives a pin's absolute coords
(applies instance rot/flip/origin via the `ROTATION` macro).

### 4.2 Sizing — text size and stub length

1. For each pin to be processed, read **the pin's text size** = `get_pin_name_size(...)`
   from Thread A (§3.4). (Req. 2)
2. Compute the **median** of those per-pin sizes → `S` (the single size used for all
   labels and all stubs in this invocation). (Req. 5) For one pin, median = that size.
   No median helper exists in the codebase (`qsort` is used in `src/save.c`); implement
   a tiny `median_double(double *a, int n)` (copy, `qsort`, middle / mean-of-two).
3. Compute the **label text height** `H` at size `S` via `text_bbox()` (§4.4). Height
   is per-line and roughly content-independent, so a single representative string (e.g.
   the actual label or even "Mg") suffices.
4. **Stub length** `L = ceil((2*H + margin) / grid) * grid` so that `L > 2*H` AND lands
   on grid. `grid = tclgetdoublevar("cadgrid")`. (Req. 1) Snap with `my_round`
   (`src/actions.c:3936`): `v = my_round(v/grid)*grid`.

### 4.3 Geometry — stub direction and label "flag" orientation

**Outward direction of a pin** (the way the stub extends, Req. 4): in symbol-local
coords, compare the pin-rect center to the symbol body. Use the symbol bbox fields
`xSymbol.minx/maxx/miny/maxy` (`src/xschem.h:615-618`) — prefer the **no-text** bbox if
available — to get the body center, then take `dir = pin_center - body_center` and
**snap to the dominant axis** (Manhattan: pick ±x or ±y, whichever |component| is
larger) so the stub is orthogonal. Then transform that local outward direction through
the instance's `rot/flip` (the `ROTATION` macro, `src/xschem.h:368-375`) to get the
absolute stub direction. (For a pin exactly centered or ambiguous, default to a fixed
axis and log.)

- Stub start = pin abs coords (`get_inst_pin_coord`).
- Stub end = start + outward_unit * L, then grid-snap.

**Label flag orientation** (Req. 4): place a `lab_pin` instance at the **stub end** with
`rot/flip` chosen so the text reads *outward* (away from the instance). The label's
attach point is the lab_pin origin (the `B` pin box at `0,0`); its default text extends
to the LEFT of origin (`lab_pin.sym`: `T {@lab} -7.5 -8.125 0 1 0.33 0.33 {}`). So:

| stub points… | want text to extend… | pick lab_pin rot/flip so text goes that way |
|---|---|---|
| +x (right) | further +x | flip/rotate the default (which is text-left) to text-right |
| -x (left)  | further -x | default lab_pin orientation |
| +y / -y    | up / down  | rot=1 / rot=3 accordingly |

Exact `rot/flip` values must be confirmed empirically against `lab_pin.sym`'s anchor at
implementation time (xschem y grows downward; verify with a quick GUI/print test). The
4 cardinal cases are the only ones needed because the stub is Manhattan.

**Label symbol = `lab_pin.sym`** (the flag), NOT `lab_wire.sym` (inline wire label).
`xschem_library/devices/lab_pin.sym` — type=label, template `name=p1 sig_type=std_logic
lab=xxx`, text index 0 = `@lab`, text index 1 = `@spice_get_voltage` (hidden, layer 15).

### 4.4 Computing text height — `text_bbox()`

`src/actions.c:3791`:
```c
int text_bbox(const char *str, double xscale, double yscale,
    short rot, short flip, int hcenter, int vcenter,
    double x1, double y1, double *rx1, double *ry1, double *rx2, double *ry2,
    int *cairo_lines, double *longest_line);
```
Returns the bbox in schematic units; **text height = `ry2 - ry1`**. There is a Cairo path
and a no-Cairo path (`text_bbox_nocairo`, `src/actions.c:3877`, uses font constants
`FONTHEIGHT=40, FONTDESCENT=15, FONTWHITESPACE=10`, `src/xschem.h:334-338`).

### 4.5 "Is this pin already connected?" — spatial hash

`src/xschem.h:1115-1116`: `wire_spatial_table[NBOXES][NBOXES]`,
`inst_spatial_table[...]`. Build with `hash_wires()` / `hash_instances()`
(`src/netlist.c:555`, `:123`). Query with the iterator API
(`src/hash_iterator.c`): `init_wire_iterator(&ctx, x-eps, y-eps, x+eps, y+eps)` then
`wire_iterator_next(&ctx)`, checking each `xWire`'s endpoints (and segment) against the
pin coord within `CADWIREMINDIST` (`=12.0`, `src/xschem.h:185`). See
`find_closest_net_or_symbol_pin()` `src/findnet.c:201-271` for a working pattern that
already mixes wire + pin queries.

### 4.6 Creating the stub wire + the label

**Wire** (`src/store.c:226` `storeobject`, `:339` `wire_store`):
```c
xctx->push_undo();                 /* ONCE per invocation, before all edits */
storeobject(-1, x1,y1, x2,y2, WIRE, 0, /*sel*/0, /*prop*/NULL);
xctx->prep_hash_wires = 0; xctx->prep_net_structs = 0; xctx->prep_hi_structs = 0;
/* draw later via a single bbox/draw at the end, not per-object */
set_modify(1);
```
(See the `xschem wire` dispatcher path `src/scheduler.c:~8714-8739` for the full
bookkeeping list.) Optionally honor `autotrim_wires`.

**Label** (`src/actions.c:1597` `place_symbol`, used by `place_net_label`
`src/actions.c:1571`):
```c
const char *lab = tcleval("find_file_first lab_pin.sym");
place_symbol(-1, lab, end_x, end_y, rot, flip,
   "name=<unique> lab=<netname> text_size_0=<S>", /*draw*/0, first_call, /*push_undo*/0);
```
- `text_size_0=<S>` overrides the lab_pin text scale (index 0 = `@lab`) to the median
  size `S` (Req. 2/5) — read by `get_sym_text_size` (`draw.c:588`).
- After placement you can also `subst_token` the `prop_ptr` then `new_prop_string(n,...)`
  to (re)set `lab`. (`src/token.c:1234` `subst_token`; `src/editprop.c` `new_prop_string`.)
- Pass `to_push_undo=0` because we pushed one undo for the whole operation.

**Batch the redraw/bbox once at the end**, not per object (place_symbol/storeobject can
defer drawing); then `bbox`/`draw()` + `set_modify(1)`.

### 4.7 Label net-name content — OPEN QUESTION (was about to ask the user)

Identical label names on different instances **short** those nets. Options (pick one):
1. `<instance>_<pin>` e.g. `M1_g` (unique, readable) — *recommended default*.
2. pin name only e.g. `g` (concise; intentional/​accidental shorting risk).
3. auto net number `net1, net2, …` (unique, opaque).
4. placeholder `lab=xxx` (template default; user renames).

The user redirected to Thread A before answering — revisit when starting Thread B.

### 4.8 Invocation — OPEN QUESTION (proposed default)

Follow the action-registry house style (`[[action-registry]]`, cadence-modifier-drag):
register an action (e.g. `edit.add_pin_stubs`) with a rebindable key + an Edit-menu item
+ a scriptable `xschem add_pin_stubs [...]` subcommand in `scheduler.c` (so it is
headless-testable). Confirm the exact default key (user does heavy Cadence-key work).

---

## 5. Implementation plan (phased)

**Thread A (prerequisite):**
- A1. Decide storage for pin text size (`name_size=` on pin rect, + global default) and
  the opt-in toggle (`show_pin_names`, default OFF, mirrored C↔Tcl). §3.3.
- A2. Implement `get_pin_name_size(...)` getter (the §3.4 single source of truth) +
  headless unit coverage. **Thread B depends only on this. DONE — P9, see §3.4.**
- A3. Auto-draw pin name text in `draw_symbol()` (hook by `draw.c:780-821`), gated on the
  toggle, sized by A2, positioned/oriented by pin facing (reuse §4.3 outward logic),
  colored on PINLAYER. Ensure legacy hand-placed pin-name `T {}` symbols don't double.
- A4. GUI verify on a few stock symbols (nmos4, an opamp, a generic block).

**Thread B (feature):**
- B1. `median_double()` helper (qsort middle). **DONE 2026-07-01.** `double
  median_double(const double *a, int n)` in `src/actions.c` (decl `src/xschem.h`): copies the
  input (caller's array not reordered), `qsort`s the copy via `cmp_double`, returns the middle
  for odd n / mean of the two middle for even n; n==1→a[0], n<=0→0.0. Test seam `xschem get
  median <v...>` (`scheduler.c` `case 'm'`). Coverage: `tests/wire_stub_netlabel.tcl` (Thread
  B's test file, 10 checks incl. skewed inputs where median≠mean and unsorted inputs whose
  positional-middle≠median). Sabotage-verified: mean-of-all flips the skewed checks, skipping
  the sort flips the unsorted checks.
- B2. Selection scan → list of (inst, pin) to process (§4.1), incl. the connected-pin
  filter for whole-instance selection (§4.5). **DONE 2026-07-01.** `int
  collect_pin_stub_targets(Pin_stub_target **out)` in `src/actions.c` (struct + decl
  `src/xschem.h`): `rebuild_selected_array()`, then if any `INST_PIN` is selected → exactly
  those (inst, pin) pairs (individually-selected pins WIN, honored even if already connected);
  else each selected `ELEMENT` → its pins where `!pin_is_connected(i,j)`. `pin_is_connected`
  counts a pin connected if (1) a wire touches it — `touch()`, the netlister's on-segment
  primitive: an endpoint AT **or** a wire passing THROUGH the pin coord (over the wire spatial
  hash) — **or** (2) a pin of ANOTHER instance is coincident with it (abutment / pin-to-pin
  placement; exact coord match over the instance spatial hash — the user's rule: treat a
  coincident instance pin the same as a wired one). Schematic-mode only; skips `ptr<0` / stale
  pin indices. Test seam **`xschem pin_stub_targets`** (`scheduler.c` `xschem_cmds_p`) returns a
  Tcl list of `{inst pin}` pairs (read-only dry-run). Coverage: `tests/wire_stub_netlabel.tcl`
  B2 (11 checks, incl. abutment). Sabotage-verified: neutering the wire filter flips the two
  wire-exclusion checks, neutering the coincident-pin scan flips the two abutment checks, and
  neutering pins-win flips the three pin-select checks. **OPEN for the user (B5/B6): does
  individual-pin mode intentionally stub an already-connected selected pin? Current behavior =
  yes (honor the explicit selection).**
- B3. Sizing: per-pin size via A2 → median `S` → text height `H` (§4.4) → stub length `L`
  (§4.2). **DONE 2026-07-01.** `int compute_pin_stub_sizing(const Pin_stub_target *t, int n,
  Pin_stub_sizing *out)` in `src/actions.c` (struct `{double size, text_h, stub_len}` + decl
  `src/xschem.h`): `size` = `median_double` of the targets' `get_pin_name_size` (defensive
  ptr<0 → 0.2); `text_h` = a label line's height at that size via `text_bbox("Mg", S, S, …)`
  (per-line height is ~content-independent, so a representative string stands in for the
  not-yet-known net name; `text_bbox` uses its nocairo path headless); `stub_len` = the smallest
  `cadgrid` multiple STRICTLY greater than `2*text_h` (`(floor(2H/grid)+1)*grid`), so every stub
  clears 2× its label height and lands on grid (Req 1). Test seam **`xschem pin_stub_sizing`**
  (`scheduler.c` `xschem_cmds_p`) returns `"S H L"` for the current selection's targets (empty
  when none). Coverage: `tests/wire_stub_netlabel.tcl` B3 (8 checks, relational so they're robust
  to font metrics: `S`=median-not-min/max/mean, `H>0`, `L>2H`, `L` on grid, `L` the smallest such
  multiple, single-pin size, bigger-size→longer-stub, empty). Sabotage-verified: median→first
  flips the median check; `L=2H` flips the `>2H` and on-grid checks.
- B4. Geometry: outward direction (§4.3), stub endpoints. **STUB GEOMETRY DONE 2026-07-01;
  label rot/flip MOVED to B5** (it is intrinsically tied to placing the actual lab_pin symbol
  and verifying the text reads outward, so it belongs with the mutation). `int
  compute_pin_stub_geom(int inst, int pin, double stub_len, Pin_stub_geom *out)` in
  `src/actions.c` (struct `{double x1,y1,x2,y2,dx,dy}` + decl `src/xschem.h`): outward = (pin
  center − body center) snapped to the dominant axis (Manhattan → orthogonal stub), transformed
  through the instance rot/flip via the `ROTATION` macro; body center uses `sym->minx/maxx/
  miny/maxy`, which already EXCLUDE symbol text (`save.c` omits text from the symbol bbox = the
  no-text body box §4.3 wants). start = `get_inst_pin_coord`; end = start + outward·`stub_len`
  (no separate grid-snap: real pins are on-grid so end is on-grid, and snapping could erode the
  L>2H guarantee for an off-grid pin). Test seam **`xschem pin_stub_geom <inst> <pin> <L>`**
  (`scheduler.c` `xschem_cmds_p`) → `"x1 y1 x2 y2 dx dy"`. Coverage:
  `tests/wire_stub_netlabel.tcl` B4 (11 checks, exact values): the 4 sides → ±x/±y, rot=1 and
  flip transform outward + position, an OFFSET-body symbol (both pins at +x, inner one points −x)
  that discriminates the body-center subtraction, bad inst/pin, arg error. Sabotage-verified:
  body-center→0 flips the offset check, skipping ROTATION flips the rot/flip checks, forcing the
  x-axis flips the top/bot checks.
- B5. Mutate. **DONE 2026-07-01.** `int add_pin_stubs(const char *prefix, const char *suffix,
  int inst_prefix)` in `src/actions.c` (decl `src/xschem.h`), exposed as **`xschem add_pin_stubs
  [-prefix <s>] [-suffix <s>] [-inst-prefix]`** (`scheduler.c` `xschem_cmds_a`). Runs
  `collect_pin_stub_targets` → `compute_pin_stub_sizing` (one S + L), then ONE `push_undo()` and,
  per target, `storeobject(…WIRE…)` for the stub (`compute_pin_stub_geom` start→end) + a
  `place_symbol(lab_pin.sym, end, lrot, lflip, "name=l0 lab=<net> text_size_0=<S>", …,
  to_push_undo=0)` at the far end (`place_symbol` auto-uniquifies the l0/l1/… names). The net
  name = `[instname_ if inst_prefix][prefix]<pinname>[suffix]` (default = pin name). Label
  orientation via `lab_orient(dx,dy)`: **rot=0 horizontal (flip picks −x/+x), rot=1 vertical
  (flip picks −y/+y)** — determined empirically against `lab_pin.sym`'s `@lab` anchor via the
  text-bbox-centre offset. One batch `set_modify(1)` + `draw()`; a single undo removes every
  wire + label. Coverage: `tests/wire_stub_netlabel.tcl` B5 (18 checks): counts, default + all
  naming-option combos, **every label reads outward** (dot of the placed lab_pin's
  `bbox_selected` centre with the B4 outward dir > 0), one-undo-removes-all, already-connected
  pins skipped, selected-pins mode, nothing/symbol-mode → 0. Sabotage-verified: fixing the
  lab_pin orientation flips the reads-outward check. SVG render eyeballed: the 4 labels sit at
  the 4 extremes reading outward (verticals rotated).
- B6. Wire up invocation (§4.8): action registry + key + menu (the `xschem add_pin_stubs`
  subcommand is DONE at B5). **USER (2026-07-01) wants all three: subcommand ✓, registered
  action + keybinding, menu item.** Default key still to choose.
- B7. Tests: headless `tests/*.tcl` (build a tiny sch with one instance; run the
  subcommand; assert N new wires + N lab_pin instances at expected coords/sizes; assert
  connected pins are skipped; assert pins-selected path processes only selected). GUI
  smoke for the "flag in the wind" orientation across the 4 facings + median sizing.

---

## 6. Open questions to resolve (carried over)

1. **Thread A:** where the pin text size is stored; the opt-in toggle; auto-text position
   rule; double-draw avoidance for legacy symbols. (§3.3)
2. **Thread B label net name** content (§4.7) — recommended `<instance>_<pin>`.
3. **Thread B invocation** + default key (§4.8) — recommended registered action + key +
   menu + subcommand.
4. **"Connected" definition** (§4.1/§4.5) — recommended: wire endpoint / wire through /
   coincident pin within `CADWIREMINDIST`.

---

## 7. Quick reference — verified file:line index

| What | Where |
|---|---|
| Pin rects of a symbol | `sym->rect[PINLAYER][j]`, count `sym->rects[PINLAYER]` (`xschem.h:610-648`) |
| Pin name/dir | `get_tok_value(rect->prop_ptr,"name"/"dir",0)` (e.g. `editprop.c:1398`) |
| Pin abs coords on instance | `get_inst_pin_coord(i,j,&x,&y)` `netlist.c:753` |
| Rotation/flip transform | `ROTATION(rot,flip,x0,y0,x,y,rx,ry)` macro `xschem.h:368-375` |
| Symbol bbox (for outward dir) | `xSymbol.minx/maxx/miny/maxy` `xschem.h:615-618` |
| Symbol drawing | `draw_symbol()` `draw.c:622`; PINLAYER rects `draw.c:780-821`; texts `draw.c:823+` |
| Symbol text size (w/ instance override) | `get_sym_text_size()` `draw.c:588-615`; override token `text_size_<n>` |
| Draw text | `draw_string()` `draw.c:477-536` |
| Text bbox / height | `text_bbox()` `actions.c:3791` (height = `ry2-ry1`); nocairo `actions.c:3877`; font consts `xschem.h:334-338` |
| Pin selection state | `xInstance.pin_sel[]`, `pin_sel_size` `xschem.h:667-675`; `INST_PIN`=128 |
| Selected-array build | `rebuild_selected_array()` (`move.c`); scan `xctx->sel_array[0..lastsel)` |
| Find pin near cursor | `find_closest_pin()` `findnet.c:532-562` |
| Select/deselect a pin | `select_pin(i,j,mode,fast)` `select.c:1088-1122`; script `xschem select pin ...` |
| Create wire | `storeobject(-1,x1,y1,x2,y2,WIRE,0,sel,prop)` `store.c:226`; `wire_store` `store.c:339`; dispatcher `scheduler.c:~8714` |
| Place symbol/label | `place_symbol(...)` `actions.c:1597`; `place_net_label(type)` `actions.c:1571` |
| Label symbols | `xschem_library/devices/lab_pin.sym` (flag), `lab_wire.sym` (inline) |
| Edit a token in prop | `subst_token()` `token.c:1234`; finalize `new_prop_string()` (`editprop.c`) |
| Connectivity hash | `wire_spatial_table` `xschem.h:1115`; `hash_wires()` `netlist.c:555`; iterators `hash_iterator.c`; pattern `findnet.c:201-271` |
| Grid snap | `my_round()` `actions.c:3936`; `grid=tclgetdoublevar("cadgrid")`; `CADWIREMINDIST=12.0` `xschem.h:185` |
| Median helper | `median_double(a,n)` `actions.c` (B1 DONE); test seam `xschem get median` |
