# 0223 — `place_net_label()` commits a net label off copper; the Add-Wire-Label form refuses

Status: **OPEN** — inconsistency measured on both paths; whether to close it is a policy call (see Risks).
**Policy decided 2026-08-05 by `doc/claude/specs/wire_label_ride.md` S1 (§14.6), and it does NOT
close this issue.** The invariant that spec enforces is **conservation** — no gesture may take a
label OFF copper that was ON copper — not **prohibition**: R9 there already tolerates 91 labels
across 21 shipped files that sit off copper by design (`verilog_type=` blocks parked off-sheet,
`type=label` symbols used as pure graphics, wireless flyline fixtures), and S1's leash gives no
rider at all to a label that was already off copper (`tests/headless/test_label_ride.tcl` L1–L3).
A label `place_net_label()` creates off copper was never on copper, so it breaks nothing the leash
defends. This issue therefore stands on its own merits — a UX inconsistency between the two
placement paths — and the fix below (gate types 0/1 through `wirelabel_preview` under
`cadence_compat`) is unchanged and still the right shape.
Area: `src/actions.c` `place_net_label()` (`:2429-2447`); the drop funnel `end_place_move_copy_zoom()` (`src/callback.c:2856-2867`); `wire_label_try_commit()` (`src/callback.c:2769`)
Tests: `tests/headless/test_add_wire_label.tcl` covers the **gated** path only; nothing covers `place_net_label` commits
Found: 2026-08-05, while grounding `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md`
Related: **0122** (Add-Pin/Add-Label form UX: drain / blank / Esc — lists `place_net_label` as one of four non-form paths on the same machinery), **0121** (add_pin_stubs spurious undo on all-skip, OPEN), **0140** (Add-Pin dead in library-manager symbol view). Spec: `doc/claude/specs/add_wire_label.md`, `doc/claude/specs/wire_stub_netlabel.md`.

## The defect

Two label-placement paths exist. The modern one refuses a drop that would not land on
copper; the legacy one commits it silently, producing an instance that looks exactly like
a placed net label while naming nothing.

**Gated path.** Plain `l` is bound to the registry action `edit.add_wire_label`
(`src/callback.c:5021`), whose command is the bare `xschem add_wire_label`, which only
runs `addlabel::open` (`src/scheduler.c:1881`). The *form* then arms placement with
`xschem add_wire_label -place` (`src/xschem.tcl:11349`) → `place_wire_label(nm)`
(`src/scheduler.c:1855`), which sets `xctx->wirelabel_preview = 1`. Commit goes through:

```c
src/callback.c:2769-2778
int wire_label_try_commit(void)
{
  if(!xctx) return 0;
  if(!(xctx->ui_state & START_SYMPIN) || !xctx->wirelabel_preview) return 0;
  if(!point_on_wire_or_pin(xctx->mousex_snap, xctx->mousey_snap)) {
    tcleval("if {[info procs addlabel::on_reject] ne {}} {addlabel::on_reject}");
    return 0;  /* off copper: keep the preview live so the user can reposition */
  }
```

**Ungated path.** `place_net_label()` sets `START_SYMPIN` and nothing else:

```c
src/actions.c:2429-2447
void place_net_label(int type)
{
  if(type == 1)      { … find_file_first lab_pin.sym  … place_symbol(…, 0, 0, NULL, 4, 1, 1); }
  else if(type == 0) { … find_file_first lab_wire.sym … place_symbol(…, 0, 0, NULL, 4, 1, 1); }
  else if(type == 2) { … find_file_first ipin.sym     … place_symbol(…, 0, 0, NULL, 4, 1, 1); }
  else if(type == 3) { … find_file_first opin.sym     … place_symbol(…, 0, 0, NULL, 4, 1, 1); }
  move_objects(START,0,0,0);
  xctx->ui_state |= START_SYMPIN;
}
```

and the shared drop funnel consults **only** `wirelabel_preview`, which that path never
sets:

```c
src/callback.c:2856-2861
    if(xctx->wirelabel_preview) {
      wire_label_try_commit();
      return 1;
    }
    end_move_copy_logged(0);
    xctx->ui_state &=~START_SYMPIN;
```

**Actual entry points** into the ungated path — broader than "Alt+Shift+L":

| entry | call |
|---|---|
| Alt+Shift+L | `place_net_label(0)` — `lab_wire` (`src/callback.c:6411`) |
| Ctrl+P | `place_net_label(2)` — `ipin` (`src/callback.c:6657`) |
| Ctrl+Shift+P | `place_net_label(3)` — `opin` (`src/callback.c:6666`) |
| Symbol → "Place net wire label" | `xschem net_label 0` (`src/xschem.tcl:14905-14906`) |
| Symbol → "Place schematic input/output port" | `xschem net_label 2` / `3` (`src/xschem.tcl:14899-14902`) |
| any script | `xschem net_label N` → `place_net_label(atoi(argv[2]))` (`src/scheduler.c:7993`) |

Types 2/3 are hierarchy **ports**, not pure net names — see the scoping note below.
Type 1 (`lab_pin`) is no longer on any key or menu; it is reachable only as
`xschem net_label 1`.

## Measured

Ungated, stock defaults:

```
xschem clear force
xschem wire 0 0 100 0
xschem net_label 0            ;# == menu "Place net wire label" / Alt+Shift+L
xschem move_objects step 500 500
xschem move_objects end
->  after commit: insts=1
    inst 0: p1 cell=lab_wire.sym
    net_at 500 500 = 0
```

A `lab_wire` label committed at a point the copper predicate itself calls off-copper. No
refusal, no warning, undo baseline spent.

Gated, same fixture:

```
set ::label_new_name VDD
xschem add_wire_label -place
xschem add_wire_label -drop 500 500   -> 0   (refused, preview stays live)
xschem add_wire_label -drop 50 0      -> 1   (committed on the wire)
```

GUI equivalent: draw one wire; press `l`, type `VDD`, click empty canvas → nothing drops
and `addlabel::on_reject` fires. Press Alt+Shift+L, click the same empty spot → a
`lab_wire` instance is committed there.

## Two secondary corrections

**Orientation.** Both paths pass `rot=0, flip=0`, but that is not "labels can only be
placed unrotated" — both are live move gestures, and a mid-gesture rotate/flip key sets
`xctx->move_rot` / `move_flip`, which `end_move_copy_logged` bakes in
(`src/callback.c:2561`, `src/move.c:288-299`). The real ergonomic gap is that nothing
*auto*-orients: `lab_orient()` (`src/actions.c:1387`) exists but is `static` and called
only from `add_pin_stubs` (`:1442`).

**Off-grid wires.** Do **not** write "an off-grid wire cannot be hit by a snapped drop" —
a later reader will try to fix a non-bug. `touch()` is exact **double** collinearity
(`src/clip.c:234-245`), so an oblique off-grid wire can still be hit at exact lattice
crossings: `xschem wire 5 5 105 105` then `xschem net_at 10 10` returns 1. The accurate
statement is: **axis-aligned wires off the snap lattice are unreachable from a snapped
drop** (`xschem wire 0 5 100 5` → `net_at 50 5` = 1, `net_at 50 0` = 0, and no snapped
drop can produce y=5). Separately, `xschem add_wire_label -drop x y` writes `mousex_snap`
verbatim (`src/scheduler.c:1873`), so scripted drops bypass the grid entirely.

## Fix, if it is to be closed

Route the two pure-label types through the existing gate rather than duplicating it — one
flag is all the drop funnel consults. In `src/actions.c:2429-2447`, after
`xctx->ui_state |= START_SYMPIN;`:

```c
    /* net-name labels (lab_wire/lab_pin) must land on copper, like the Add-Wire-Label
     * form (doc/claude/specs/add_wire_label.md). ipin/opin (types 2/3) are hierarchy
     * PORTS and keep the legacy free placement. */
    if((type == 0 || type == 1) && tclgetboolvar("cadence_compat"))
      xctx->wirelabel_preview = 1;
```

Two required riders:

1. `xctx->wirelabel_preview` must be cleared on abort/Escape for this path too — verify
   the teardown at `src/callback.c:378` covers a `place_net_label` gesture, or the flag
   leaks into the next drop.
2. Leave `sympin_preview` at 0. Per the comment at `src/callback.c:2584`, a non-form
   `START_SYMPIN` placement must not bump `sympin_drops` and drain an open form queue.
   Set only `wirelabel_preview`; do not set both.

Gating on the existing `cadence_compat` preference (menu checkbutton,
`src/xschem.tcl:14572`) keeps stock XSCHEM behaviour byte-identical.

Adjacent ergonomics worth doing in the same pass, both small:

- **Auto-orient on drop** — un-`static` `lab_orient()` (`src/actions.c:1387`) and call it
  from `wire_label_try_commit()` (`src/callback.c:2769`), where the wire under the cursor
  is already known to have been found.
- **Snap tolerance** — a tolerant variant beside `point_on_wire_or_pin()`
  (`src/check.c:188`) that searches a small radius and moves the label's pin onto the
  nearest wire, turning "drop failed, no idea why" into "it snapped".

## Risks

- **Behaviour break.** Upstream XSCHEM's normal flow is to drop a `lab_wire`/`lab_pin` in
  free space and *then* draw a wire to it. Gating Alt+Shift+L unconditionally makes that
  flow impossible and breaks any script driving `xschem net_label 0` + a move commit.
  Hence the preference gate.
- **Do not gate types 2/3.** `ipin`/`opin` are hierarchy ports, routinely placed first and
  wired afterwards; gating them is a far larger regression than the label case.
- **Scripted silence trade.** `xschem net_label N` returns nothing, so a script placing a
  label off copper would start silently no-op'ing — a new silent failure traded for the
  old one. Consider making the scheduler arm return a status.
- **Shared drop funnel.** `end_place_move_copy_zoom`'s `STARTMOVE` arm
  (`src/callback.c:2856`) also serves add_graph, add_image and image paste, none of which
  set the preview flags. A leaked `wirelabel_preview` would make an image paste refuse to
  drop. Flag lifetime is the whole risk surface.
- **No coverage.** `tests/headless/test_add_wire_label.tcl` exercises the modern path only;
  a change here is currently unguarded.
