# Add Wire Label (Cadence-style net-label form)

Status: implemented (fluid-editing), adversarial-review-hardened. Author: session 2026-07-12.

Review pass (workflow, 4 dimensions × adversarial verify): 10 confirmed / 2 refuted, all 8 distinct
fixed — leading-zero octal bus parse (`scan %d`), `wirelabel_preview` invariant leaks
(clear_drawing + add_sch_pin/add_symbol_pin arm both now zero it), `editing_symbol_view()` guard on
`add_wire_label`, bus-range width cap (4096), cross-form drop cross-talk (`::sympin_place` owner
latch), two stale binding-assertion tests (test_key_graph_context / test_phase3_mints), menu
accelerator. Refuted: exact-double pin compare (pins are on-grid), `place_wire_label` name lifetime.
Related: [schematic_add_pin.md](schematic_add_pin.md) (the sibling Add-Pin form this mirrors),
`cadence_pin_name_text.md`, `wire_stub_netlabel.md`.

## Goal

A Cadence-style **Add Wire Label** modeless form, very close to the Add-Pin form, that places
**net labels** (`lab_pin.sym` instances carrying `lab=<name>`) whose names the user types up
front — instead of the old "drop an `XXX` label, then edit it" flow (Symbol ▸ Place net pin
label / Alt+L, `xschem net_label 1`). That old place-anywhere flow is **removed** (its key/menu
are repointed to this form).

Two behaviours ship now; two checkboxes are reserved (inert) for later work.

### The form

```
Add Wire Label
  Label Name: [ A B C[2:0]        ]
  [ ] Split bus                         (unchecked by default)
  [ ] Place multiple labels at once     (inert — deferred)
  [ ] Vertically justified              (inert — deferred)
  ------------------------------------------------
  <status line>                         [ Close ]
```

- **Label Name** — one or more names. They form a placement **queue**, exactly like Add-Pin: a
  cursor preview of the current name follows the mouse; a left-click drops it (if legal, see
  *Placement constraint*) and the next queued name auto-arms. Each placed name is **consumed from
  the Name field** as it commits, so the field always shows what is still queued (`A B[2:0]` →
  `B[2:0]` after dropping `A`, → empty once all are placed). When the queue drains, placement
  stops but the form stays open (type more, or Esc/Close). Modeless. **Esc** dismisses the form
  from either the form or the canvas (focus lands on the canvas after a drop) — in any state, not
  only while a preview is attached.
- **Split bus** (functional now, **unchecked by default**) — see *Name parsing* below.
- **Place multiple labels at once** — reserved, disabled. (Semantics TBD by the user.)
- **Vertically justified** — reserved, disabled. (Will later rotate/vcenter the label text.)

### Name parsing (`addlabel::expand_names names split_bus`)

Pure Tcl, headless-testable (mirrors `addpin::names_from`). Steps:

1. Split the entry on any run of **whitespace and/or commas** (`[,\s]+`), trimming ends.
   So `"A B C"`, `"A,B,C"`, and `"A, B  C"` all yield three tokens.
2. **Normalise** each token's bus brackets: `<` → `[`, `>` → `]`. So `B<2:0>` → `B[2:0]`,
   `B<3>` → `B[3]`. (Always — even with Split bus OFF; user intent for angle brackets is
   unambiguous.)
3. If **Split bus is ON** and a token matches `^(.+)\[\s*(\d+)\s*:\s*(\d+)\s*\]$` (a bit RANGE),
   expand it to one name per bit, walking hi→lo (or lo→hi when the range ascends):
   `B[2:0]` → `B[2] B[1] B[0]`; `B[0:2]` → `B[0] B[1] B[2]`.
   Non-range tokens (`A`, `A[3]`) and the OFF case pass through **verbatim** (normalised):
   Split bus OFF + `B[2:0]` → a single vector label named `B[2:0]`.

Editing the Name field OR toggling Split bus rebuilds the queue.

### Name validity — enforced at placement, not at entry (`addlabel::name_ok name`)

The entry field stays **permissive** — any text may be typed or **pasted** (from a netlist, a
spreadsheet, etc.) without being fought character-by-character. A name is validated only when it is
about to be placed (as it is *armed* to the cursor). A name is **valid** iff, after `<>`→`[]`
normalisation, it is a non-empty base of non-bracket characters optionally followed by ONE bus
suffix `[i]` or `[hi:lo]` (digits, single colon):

- valid: `A`, `a/b.c`, `B[2:0]`, `B<2:0>`, `B[3]`
- invalid: `B{2:0]` (curly), `C[2;0]` (`;` for `:`), `B[2:0` (unclosed), `B]`, bare `[2:0]`

When the head of the queue is invalid, **no preview is armed** (nothing can be dropped) and the form
status line turns **red** (`AddLabelErr.TLabel`): *"'…' has a syntax error — fix it to place"*. The
user corrects that name in the field; editing re-runs the queue and the corrected name arms
normally, clearing the red. Because names are consumed as they place, in `A B C[2;0]` the first two
drop fine and the form only flags `C[2;0]` when its turn comes.

### Placement constraint — "no stray net-labels"

Unlike the old `net_label` (drop anywhere), a label may only be **committed** where its pin
(the `lab_pin` `B` box at the instance origin) actually connects:

- **ON a wire** — the snap point lies on any wire segment (`touch()`), OR
- **exactly ON an instance pin** — the snap point coincides with a non-selected instance's
  PINLAYER pin (`touches_inst_pin()`).

The label preview itself is SELECTED during placement, so selected wires/instances are skipped
in the test (a label never satisfies the rule against itself). A click on empty canvas is
**refused**: the preview stays attached to the cursor (nothing committed, queue not advanced),
and the status line explains why. Predicate: `point_on_wire_or_pin(x, y)` (check.c).

## Invocation / key bindings (user-ratified)

- Default **`l`** opens the form (`edit.add_wire_label` → `xschem add_wire_label`), a rebindable
  registry action (idle-gated, canvas). This **shadows** the old plain-`l` graphic-line default.
- Graphic-line moves to default **Shift+L** (`tools.insert_line` → `xschem line gui`), also a
  new rebindable registry action.
- The former Shift+L action **`edit.toggle_orthogonal_wiring` ships UNBOUND** (rebind via
  `keybindings.csv` / `xschem bind`), same pattern as `view.center_at_cursor`/`view.pan`.
- The old **Alt+L** menu item (Place net pin label) and its C key branch are **repointed** to
  open this form. `xschem net_label 1` still exists as a command but is no longer bound.
- `net_label 0/2/3` (lab_wire / ipin / opin, Alt+Shift+L / Ctrl+P / Ctrl+Shift+P) are untouched.

All defaults are reconfigurable from a user's loadable rc/script via `bind`/`keybindings.csv`.

### Entering the form CANCELS an in-progress wire/line draw (issue 0240, user-ratified 2026-08-06)

`l` pressed **without** first leaving wire-draw mode used to arm two modal gestures at once, and
that is not a usable state at any flag setting: `end_place_move_copy_zoom()` tests `STARTWIRE`
(`callback.c:2872`) **before** the placement arm (`:2927`), so every click fed the wire and the
label could never reach its drop gate. Add-Wire-Label therefore **abandons the in-progress
wire/line first** — `abort_wire_line_command()` (`callback.c:494`), called from the scheduler
branch (`scheduler.c:1846`) so the key, the menu accelerator, the form's per-keystroke `-place`
re-arm and a scripted `xschem add_wire_label` all pass through it. Nothing is committed
(`new_wire()` stores and pushes undo only at `PLACE`, so an abandoned draw leaves no copper and no
stranded baseline), a menu-armed-but-unclicked wire/line is dropped too, `last_command` is cleared
so no press restarts a wire under the fresh preview, and the statusbar says what happened.

**"Wire-draw mode" is three states, not one**, and the gate must catch all three: a LIVE draw
(`ui_state & STARTWIRE`, rubber band up); a MENU-armed draw whose first click has not landed
(`MENUSTART` + `MENUSTARTWIRE`); and the **RESTING** command mode after a double-click ends a
segment — `ui_state` has no `STARTWIRE` at all, only `last_command`, and the diamond snap cursor
is the only tell. The resting state is the dangerous one: under `persistent_command`
(`cadence_style_rc:60`) `callback.c:7843` tests `last_command` alone and calls `start_wire()`
*before* any placement is offered the click, so a label armed there can never be dropped. Gating
on `ui_state` alone shipped that bug (issue 0240 follow-up, 2026-08-06).

It is **not** `abort_operation()`: on a `-place` re-arm a preview is already live, and tearing that
down would clear `sympin_preview` and make the next `-place` push a **second** undo baseline for
one gesture (see #8 and the one-baseline rule below). `-drop` is not gated — by then the wire is
long gone.

### The reverse door: a wire/line verb during a live label preview (issue 0243 F2, ratified 2026-08-07)

The exclusion holds in **both** directions. Pressing `w` (or Shift+L, `W`/`s` snap wire, the
context-menu inserts, the Wire/Line menu or toolbar entries, or a scripted `xschem wire|line gui` /
`xschem snap_wire`) while a label preview rides the cursor **abandons the preview** and starts
drawing — `leave_placement_for()` (`callback.c`), the mirror of `leave_wire_draw_for()`, wrapping
the shared `abort_placement_preview()`. Same ratified rule as `l`: whatever you just pressed is what
you meant. The preview is torn down undo-free, so the gesture still owns exactly one baseline.

One carve-out: while a **multiple selection** is live (e.g. `Ctrl+A` under the preview — the forms
are modeless) the gate DECLINES instead, says so in the statusbar, and the draw does not arm. The
teardown is a `delete()`, which removes the selection rather than the preview (issue **0241**,
open), so abandoning there would wipe the drawing. That carve-out goes away when 0241 lands.

The gate sits at each **verb**, not inside `start_wire()`/`start_line()` (which the sketch in 0243
originally proposed): those primitives are also the per-*click* continuation of a running draw —
under `persistent_command` every press calls `start_wire()` before `end_place_move_copy_zoom()` sees
the click — so a teardown there would drop a pending placement on an ordinary click. The scripted
coordinate forms (`xschem wire x1 y1 x2 y2`) are excluded, same rule as `-drop`.

Note `p` (Add Pin) and the symbol-placement dialogs were gated by issue **0243** F1 on 2026-08-07;
`add_graph`, `add_image`, `net_label 0/2/3`, `Ctrl+V` merge, `r`/`P`/`t` and the context-menu text
insert still permit the double-arm and are tracked by issue **0247** (ESC does clean up after them
since 0243 F3 — what remains is the jam while both are armed).
Beware when testing this class: `xschem add_wire_label -drop` calls `wire_label_try_commit()`
directly and bypasses `end_place_move_copy_zoom()`, so headlessly a label DOES drop while
`STARTWIRE` is live, where the GUI click cannot. Assert on the flags, not on `-drop`'s return.

## Implementation map

C:
- `point_on_wire_or_pin(x,y)` — **check.c** (public; reuses static `touches_inst_pin`). Skips
  SELECTED wires/instances. Declared in xschem.h.
- `place_wire_label(name)` — **actions.c** (twin of `place_sch_pin`): `find_file_first
  lab_pin.sym`, prop `name=l1 lab=<name>`, `place_symbol(...,4/*select*/,1,0/*undo owned by
  driver*/)`.
- `xctx->wirelabel_preview` — **xschem.h** flag: the current START_SYMPIN preview is a
  constrained wire-label (triggers the drop gate). Set with `sympin_preview` at arm; cleared
  wherever `sympin_preview` is (abort at callback.c ~242, commit at ~1731, and the gate).
- `xschem add_wire_label` — **scheduler.c** ('a' letter-dispatch, beside `add_sch_pin`): bare →
  `addlabel::open`; `-place` → reuse the sympin undo-clean re-arm dance, set both preview flags,
  `place_wire_label(::label_new_name)`; `-drop [x y]` → reposition preview then
  `wire_label_try_commit()` (headless seam + shared gate). On `place_wire_label` failure clear
  both preview flags (mirrors the add_sch_pin guard).
- `wire_label_try_commit()` — **callback.c** (public): the shared drop gate. Commits (move END +
  clear flags) iff `point_on_wire_or_pin(snap)`, else refuses (keeps preview). Used by BOTH the
  GUI button path (`end_place_move_copy_zoom` STARTMOVE branch: commit→return 1, refuse→**swallow**
  the click, return 1) and `add_wire_label -drop`.
- Registry + default binds — **callback.c**: add `edit.add_wire_label`, `tools.insert_line`;
  `set_input_binding_idle('l', …add_wire_label)`, `('L', …insert_line)`; drop the `'L'`
  toggle_orthogonal default. Repoint Alt+L branch (~4846) to `addlabel::open`.

Tcl:
- `addlabel::` namespace — **xschem.tcl** (modeled on `addpin::`): `expand_names`,
  `open`/`start_pass`/`arm`/`after_drop`/`escape`/`on_destroy`, status. Arms via `xschem
  add_wire_label -place` (`::label_new_name`). `on_reject` updates the status on a refused drop.
- Menu — **xschem.tcl**: repoint the Place-net-pin-label item to `addlabel::open`, relabel
  "Add Wire Label", accelerator `l`.

Data files:
- **actions.csv** — add `edit.add_wire_label` row; `tools.insert_line` row already exists.
- **keybindings.csv** — regenerated from the live table (`save_input_bindings_file … {key}`) so
  the drift guard (test_bindings_file) stays green by construction.

## Tests

`tests/headless/test_add_wire_label.tcl` (RED-first, run_regression hcases):
- **Parsing**: every `expand_names` case above (both Split-bus states, `<>`/`[]`, ascending
  ranges, mixed separators, single-bit, empty).
- **Predicate**: fixture wire + instance-pin → `point_on_wire_or_pin`/`xschem net_at` true on
  the wire and on the pin, false off-copper, false on the selected preview.
- **Constrained drop**: `add_wire_label -place` then `-drop` ON copper commits a `lab_pin`
  instance with `lab=<name>` (placing→0); `-drop` OFF copper refuses (placing→1, not committed).
- **Binding**: `edit.add_wire_label` is a real bindable id, default-bound to `l`;
  `tools.insert_line` bound to Shift+L.
- Add `add_wire_label` to `test_readonly_guard.tcl`.

Sabotage checks (green-but-hollow guard): breaking the range-expansion regex fails the bus
cases; making the gate always-true fails the OFF-copper refuse case.
