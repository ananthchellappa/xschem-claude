# Next session — implement the apply-scope highlight (white outline on edit targets)

**Branch:** `slick-property-forms` (continue here).
**Spec (source of truth):** `doc/claude/specs/apply_scope_highlight.md` — read it first.
This prompt is the *build brief*; the spec is the requirement.

This is the last backlogged piece of the multi-instance property-editing feature
(P1/P2/P3 are done and shipped). It builds on the slick property form
([[slick-property-forms]]) and the stable object handles
([[stable-object-handles]]).

---

## The job in one paragraph

While the **Edit Properties** form is open, draw a **white outline** around
exactly the objects an **OK / Apply** would write to — the *apply-scope set*.
It's a **second, distinct** on-canvas cue (the existing selection highlight
recolors; this one outlines), and it tracks the scope **live**: change the "Apply
to" dropdown or step Next/Prev and the outline follows. **Only Current** → the
displayed instance; **All Selected** → every selected object; **All (same
symbol)** → every same-master instance on the sheet (including unselected ones).
Each object is outlined **in its natural shape** — a **wire is outlined as its
line segment**, not a box. Clears when the form closes.

---

## ⚠️ This is DESIGN-FIRST — do NOT jump to code

The earlier phases each began with a short **decision doc** that the user
ratified before any code. Do the same here. The spec §6 lists the open decisions
(the white GC; where it's drawn + persistence across redraws; the C↔Tcl command
shape; thickness/halo; draw order vs the selection overlay; erase correctness;
"All" cost). These have real trade-offs and at least one (D1 white-on-light-theme,
D2 persistence across `draw()`) needs a human call.

**Recipe (follow in order):**
1. **Characterize** the drawing path: read `draw_selection` (`move.c:210`) end to
   end, the temp primitives, and *exactly when/where* `draw()` (`draw.c:5328`)
   would wipe a transient overlay. Confirm how the selection overlay survives (or
   doesn't) a redraw. Write down what you find.
2. **Write a short decision doc** (`doc/claude/code_analysis/apply_scope_highlight_decision.md`)
   answering spec §6 D1–D6 with a recommendation for each.
3. **STOP and present it for ratification.** Do not implement until the user
   picks the answers (especially D1 color and D2 persistence).
4. Then implement **RED-first**, per phase (H1 → H2 → H3 in the spec).

---

## Verified code map (read before deciding)

| What | Where |
| --- | --- |
| The per-type shape template (loop + dispatch) | `draw_selection(GC g,int)` `move.c:210` |
| Draw vs erase GC | draw: `xctx->gc[SELLAYER]` (`SELLAYER`=`xschem.h:153`); erase: `xctx->gctiled` |
| Selection draw callers (where redraw re-strokes selection) | `move.c:997`, `move.c:1581`, `draw.c:5571`, `callback.c:1412` |
| Temp primitives | `drawtemprect`, `drawtempline`, `drawtemp_manhattanline` `draw.c:1540`, `drawtemppolygon` `draw.c:2176`, `drawtemparc` `draw.c:1572` |
| Main redraw | `draw(void)` `draw.c:5328` |
| GC array | `xctx->gc` is `GC *gc` (`xschem.h:1043`), indexed by layer |
| Scope→targets (C, the apply) | `apply_symbol_prop()` `targets[]` build, `editprop.c` |
| Scope→targets (Tcl, the warning) | `slickprop::scope_instances` `property_form.tcl` |
| Apply already takes a stable id | `xschem apply_properties <scope> <displayed_id> …` → `apply_instance_properties` `editprop.c`; scheduler branch `xschem_cmds_a` |
| Object geometry + stable ids | `xWire` (`x1..y2`+id), `xInstance` (`x1..y2`, `xx1..yy2`, `id`) `xschem.h:624-669` |
| Live-update triggers to reuse | `::slickprop_apply_scope` write trace (`apply_scope_greying`/`update_warning`); `slickprop::load_pos` (`property_form.tcl`) |
| Form scope state | sticky global `::slickprop_apply_scope` (current/selected/all); nav set in `slickprop::nav(ids/pos/disp_id)` |

---

## The single most important invariant

**The outlined set == the applied set.** If the user sees N white outlines, OK
must write exactly those N objects. Achieve this by **one source of truth**:
prefer a C command like `xschem highlight_scope <scope> <displayed_id>` that
resolves the set *the same way `apply_symbol_prop` does* (ideally share a small
target-list helper between the apply and the highlight), rather than computing the
set twice. (D3 in the spec.)

---

## Likely shape of the change (a hypothesis, not a mandate — confirm in design)

- **C:** a transient "scope highlight" overlay holding a list of `{type,id}` (or
  resolved indices), rendered by a function that mirrors `draw_selection`'s
  per-type dispatch but strokes with a white GC. A redraw hook (end of `draw()`)
  re-strokes it while a form is open (D2). Commands `xschem highlight_scope …` and
  `… clear` (D3).
- **Tcl (`property_form.tcl`):** `slickprop::update_highlight` that calls the
  command with the current scope + `nav(disp_id)`, hung off the same three
  triggers as P3's warning (scope write-trace, `load_pos`, open) and cleared on
  every close path (`ok`, `cancel`).

Reuse, don't reinvent: the geometry per type already exists in `draw_selection`.

---

## Testing (RED-first, the reliable harness)

Add tests to `tests/property_form/` (`body.tcl`, run via `wrap.tcl`) — the
in-harness suite is the gate; standalone GUI scripts hit the WSLg hang. The
suite is at **91 checks**, all green; keep it green.

What's testable headlessly (assert state, not pixels):
- The **target-set** the highlight uses is correct per scope (if the C command
  exposes/returns the resolved id list, assert it == the apply's set: current=1,
  selected=N, all=same-master count, capa untouched). This is the high-value test
  and is pixel-free.
- The overlay is **active while open** and **cleared on close** (a queryable
  flag/count, e.g. `xschem highlight_scope` with no args returns the current
  count, 0 after close).
- **Live update**: after `slickprop::nav 1` under Only Current, the highlighted id
  follows the displayed instance; after switching scope, the count changes.

Mirror the P3 modal driver: `pf_form_run <scope> { … }` opens the real modal
(polls until built), runs the body synchronously, captures into `::globals`,
closes. Pixel correctness (does it *look* white, halo thickness) is an eyeball
item, not a suite assertion — note it for manual verification.

**Sabotage after green:** e.g. freeze the highlight set to the selection only →
the All-scope target-set test reddens; make the command ignore `clear` → the
"cleared on close" test reddens. Revert.

---

## Hard-won rules (follow exactly — these bit us in P1–P3)

- **Run from `src/`:** `cd src && make -j8` after C changes, then
  `timeout -s KILL 180 ./xschem -q --script ../tests/property_form/wrap.tcl`
  → `/tmp/sh_pf_test.log`. **Always `cd src` first**, and **check the exit code**
  (0 = ran; **127** = binary not found because the shell `cd`'d elsewhere — and
  the `/tmp` log will be STALE from the previous run, which *will* mislead you).
- **WSLg flakiness:** drive modals by **polling** for the built dialog (see
  `pf_tick`/`pf_form_run` in `body.tcl`), never a fixed `after` delay, and
  **cancel every `after` timer** you schedule (an orphaned safety timer fires
  during a *later* test and cancels its dialog → wandering failures).
- **`build_fields` clears its parent's children** on rebuild; if you add widgets
  to the form, expect repeated rebuilds (Next/Prev, Apply) and avoid fixed widget
  names that collide.
- **RED-first + sabotage:** every new test fails first for the right reason;
  after green, sabotage the new path and confirm the right tests redden; assert
  exact values, not "non-empty."
- **Stable ids, not indices**, for anything held across an apply/redraw.
- **Tcl is the GUI, C is the engine:** keep the contract thin; the form feeds C a
  scope + displayed id (a few vars / one command), C owns the drawing.
- **Commit per phase** in the established style: `feat(forms): … H1/H2/H3`,
  `test(forms): … RED` / `… GREEN`; keep the 91-check suite green throughout;
  update `doc/claude/specs/apply_scope_highlight.md` status, the user guide
  (`doc/multi_instance_property_editing.md`), and the tutorial
  (`doc/claude/code_analysis/multi_instance_editing_tutorial.md`) as you go.

---

## Acceptance criteria (from the spec §8)

- White outline marks **exactly** the OK/Apply target set, all three scopes,
  updating live on dropdown change and Next/Prev.
- A wire in scope is outlined **as its line**, every type in its natural shape.
- Outline is **visually distinct** from the selection highlight (both can show).
- Closing the form **removes** the outline; canvas returns to its prior state.
- Outlined set **==** applied set (one source of truth).
- All references by **stable id**; suite green incl. new tests; sabotage-verified.

---

## Decision menu for *after* this lands (present, don't pick)

- The optional P3 per-field `<*>` "varies" marker (still unbuilt).
- v2 of the slick form: multi-line widgets for `value`/`format`/…; the other
  property dialogs (`text_line` for rect/line/poly/arc/wire, `enter_text` for
  text); per-attribute validators.
- Highlight polish beyond H3 (animation, scope-color coding).

---

*Spec: `doc/claude/specs/apply_scope_highlight.md`. Parent feature spec:
`doc/claude/specs/multi_instance_property_editing.md`. Tutorial:
`doc/claude/code_analysis/multi_instance_editing_tutorial.md`. User guide:
`doc/multi_instance_property_editing.md`.*
