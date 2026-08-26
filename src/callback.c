/* File: callback.c
 *
 * This file is part of XSCHEM,
 * a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
 * simulation.
 * Copyright (C) 1998-2024 Stefan Frederik Schippers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include "xschem.h"

/* allow to use the Windows keys as alternate for Alt */
#define SET_MODMASK ( (rstate & Mod1Mask) || (rstate & Mod4Mask) )
#define EQUAL_MODMASK ( (rstate == Mod1Mask) || (rstate == Mod4Mask) )

/* How far (in SCREEN PIXELS) a Button1 press may travel before its release stops
 * counting as a click on a graph. Real mice jitter a pixel or two on a click, so a
 * zero-travel test would lose clicks; a few pixels is far below any intentional drag.
 * Issue 0152.
 *
 * ⚠ TWO SPACES, one constant. The older arms (:710/:711 the marker click,
 * :1047/:1048 the wave-bold click) compare distances that are already in XSCHEM
 * WORLD units, so they write `GRAPH_CLICK_TOL * xctx->zoom` (zoom is world units
 * per pixel). The axis-region drag zoom (issue 0190) hands it to
 * graph_axis_map(), whose p0/p1 are RAW CANVAS PIXELS, so it passes the bare
 * constant -- multiplying there would compare pixels against world units. The
 * meaning is the same 3 screen pixels either way; only the space of the operands
 * differs. Decision-doc correction 3 in
 * doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md. */
#define GRAPH_CLICK_TOL 3.0

/* THE click-vs-drag threshold, for the one caller that is not in this file.
 * `xschem get graph_axis_map` (scheduler.c) is the seam a headless suite drives
 * the axis-zoom formula through, and it must drive it with the SAME threshold
 * the gesture at the ButtonRelease arm uses -- a second literal 3.0 over there
 * is landmine 45(a) in its purest form: one number, two homes, and no
 * behavioural leg can see them disagree (raise this #define and the gesture
 * changes while the getter does not).
 *
 * The #define itself stays FILE-PRIVATE on purpose (landmine 20: in the header
 * it would sit next to GRAPH_TRACE_PICK_TOL and be read as its twin, which it is
 * not -- that one is a 10-px PICKING radius, this one is a TRAVEL threshold).
 * An accessor exports the value without exporting the confusion.
 *
 * ⚠ Returns SCREEN PIXELS, unscaled -- see the note on the #define above. */
double graph_click_tol(void)
{
  return GRAPH_CLICK_TOL;
}

/* waveform-marker gesture helpers, defined just above waves_callback().
 * Forward-declared because waves_selected() (further up) must be able to drop an
 * armed gesture, and abort_operation() must too. */
static void graph_marker_drag_abort(void);
/* Its axis-region drag zoom twin (issue 0190), forward-declared for the same
 * reason: abort_operation() (further up) has to be able to drop an armed drag. */
static void graph_axis_drag_abort(void);

/* Read-only guard. If the current window is marked read-only (xctx->readonly,
 * which is per-window), warn the user with a modal dialog and return 1 so the
 * caller aborts the edit; return 0 when editing is allowed. Only object-mutating
 * actions call this -- navigation, zoom/pan, selection, highlight, descend,
 * netlisting, view-attributes and exports stay allowed. Clear read-only from
 * Edit > Make Editable (or the descend (edit) context item / Ctrl-2). */
static int readonly_block(void)
{
  if(!xctx || !xctx->readonly) return 0;
  if(has_x) {
    tcleval("tk_messageBox -type ok -icon info -parent [xschem get topwindow] "
            "-title {Read-only view} "
            "-message {View is Read Only.\n\nUse Edit > Make Editable to enable editing.}");
  } else {
    dbg(0, "readonly_block(): view is read-only, edit ignored\n");
  }
  return 1;
}

/* Symbol-view twin of readonly_block(): a symbol holds only pins + artwork, never
 * instances of other symbols, so instance creation is meaningless there. Returns 1
 * (with a notice) when the current view is a symbol, letting the interactive insert-
 * symbol entry points bail out BEFORE opening a file picker. place_symbol()'s own
 * guard (editing_symbol_view) is the hard backstop that covers every route; this is
 * the friendly early exit so the symbol editor never even shows a chooser. */
static int symbol_view_block(void)
{
  if(!editing_symbol_view()) return 0;
  if(has_x) {
    tcleval("symbol_view_notice");
  } else {
    dbg(0, "symbol_view_block(): symbol view, instance creation ignored\n");
  }
  return 1;
}

static int waves_selected(int event, KeySym key, int state, int button)
{
  int rstate; /* state without ShiftMask */
  int i, check;
  int graph_use_ctrl_key = tclgetboolvar("graph_use_ctrl_key");
  int is_inside = 0, skip = 0;
  static unsigned int excl = STARTZOOM | STARTRECT | STARTLINE | STARTWIRE |
                             STARTPAN | STARTSELECT | STARTMOVE | STARTCOPY;
  /* the crosshair is suppressed on a no_snap canvas (issue 0177), and this local
   * ALSO picks the cursor shape below -- with crosshair_size 0 the `draw_xhair`
   * arm hides the pointer entirely (`-cursor none`) on the assumption that a
   * crosshair is standing in for it. On a viewer nothing would be, so the pointer
   * would simply vanish. Read the property here, at call time. */
  int draw_xhair = tclgetboolvar("draw_crosshair") && !xctx->no_snap;
  double border;
  /* THE INSET IS IN SCREEN PIXELS AND IT HAS TO BE CONVERTED (issue 0177).
   *
   * This margin is what keeps a graph from swallowing pointer events right at its
   * rect edge, so the rect itself stays selectable/grabbable on a schematic canvas.
   * The intent has always been "a fixed number of screen pixels" -- but the value
   * was subtracted from r->x1/r->y1/r->x2/r->y2, which are XSCHEM units, with no
   * conversion. 1 screen pixel is xctx->zoom xschem units (X_TO_XSCHEM), so the
   * inset was off by 1/zoom.
   *
   * MEASURED on the shipping ASE viewer (1000x776 canvas, zoom 0.2738,
   * tk_scaling 1.334): (int)(5.0*1.334) = 6 xschem units = 21.9 canvas pixels, a
   * 3.3x overshoot. That band contains the TOP OF THE LEGEND -- legend_slot_hit()
   * starts its horizontal slots at gr->ry1, the rect top itself (draw.c ~4518) --
   * so the top 22 pixels of every legend entry answered the QUERY correctly and
   * then had the press routed to the schematic canvas instead of the graph: the
   * click selected nothing, and the pointer picked up the schematic crosshair.
   * The (int) cast also floored the value, which at tk_scaling 1.0 quietly made it
   * 5 units rather than 5 pixels.
   *
   * Converting restores the documented intent. At zoom ~1 (an embedded schematic
   * graph at normal magnification) the value barely moves; it is only the
   * zoomed-out end -- which is where the viewer lives -- that was wrong. */
  border = 5.0 * tk_scaling * xctx->zoom;
  rstate = state; /* rstate does not have ShiftMask bit, so easier to test for KeyPress events */
  rstate &= ~ShiftMask; /* don't use ShiftMask, identifying characters is sufficient */
  if(xctx->ui_state & excl) skip = 1;
  /* else if(event != -3 && sch_waves_loaded() < 0 ) skip = 1; */
  /* allow to work on graphs even if ctrl released while in GRAPHPAN mode
   * This is useful on touchpads with TappingDragLock enabled */
  else if(graph_use_ctrl_key && !(state & ControlMask) && !(xctx->ui_state & GRAPHPAN)) skip = 1;
  else if(SET_MODMASK) skip = 1;
  /* Button2 (middle) OVER A GRAPH is the GRAPH pan (waves_callback), not the
   * schematic canvas pan. It used to be skipped here so handle_button_press ->
   * start_pan_logged always got it; the graph pan then lived on Button1 drag,
   * which collides with everything precise LMB now has to do over a strip
   * (cursor grab, wave-bold click, and the ASE viewer's drag-to-reorder seam —
   * doc/claude/specs/waveform_viewer_modes.md). MMB does not need trace-level
   * precision, so the two swapped: LMB no longer pans a graph, MMB does.
   * Off a graph MMB still pans the canvas exactly as before — this returns 0
   * there and handle_button_press takes over. */
  else if(event == MotionNotify && (state & Button1Mask) && (state & ShiftMask)) skip = 1;
  else if(event == ButtonPress && button == Button1 && (state & ShiftMask) ) skip = 1;
  /* else if(event == KeyPress && (state & ShiftMask)) skip = 1; */
  else if(!skip) for(i=0; i< xctx->rects[GRIDLAYER]; ++i) {
    double lmargin;
    xRect *r;
    r = &xctx->rect[GRIDLAYER][i];
    lmargin = (r->x2 - r->x1) / 20.;
    lmargin = lmargin < 3. ? 3. : lmargin;
    lmargin = lmargin > 20. ? 20. : lmargin;
    if(!(r->flags & 1) ) continue;
    if( !graph_use_ctrl_key && !(state & ControlMask) &&
       !strboolcmp(get_tok_value(xctx->rect[GRIDLAYER][i].prop_ptr, "lock", 0), "true")) continue;

    check =
      (xctx->ui_state & GRAPHPAN) ||
      ((event == ButtonPress || event == ButtonRelease) && button == Button3 &&
         (
           POINTINSIDE(xctx->mousex, xctx->mousey, r->x1,  r->y1,  r->x2,  r->y2)
         )
      ) ||
      (event != -3 &&
         (
           POINTINSIDE(xctx->mousex, xctx->mousey, r->x1 + border,  r->y1 + border,  r->x2 - border,  r->y2 - border)
         )
      ) ||
      (event == -3 && /* double click */
         (
           POINTINSIDE(xctx->mousex, xctx->mousey, r->x1 + border,  r->y1 + border,  r->x2 - border,  r->y2 - border)
         )
      );

    if(check) {
       is_inside = 1;
       if(! (xctx->ui_state & GRAPHPAN) ) {
         xctx->graph_master = i;
       }
       if(draw_xhair) draw_crosshair(1, 0); /* remove crosshair, re-enable mouse cursor */
       tclvareval(xctx->top_path, ".drw configure -cursor tcross" , NULL);
       break;
    }
  }
  if(!is_inside) {
    xctx->graph_master = -1;
    /* defensive: during a real marker drag GRAPHPAN forces `check` true so this
     * branch cannot run, but a stray release of another button could reach it */
    graph_marker_drag_abort();
    /* The axis-region drag zoom's twin (issue 0190), and NOT defensive -- this
     * one was MEASURED reachable, by the `skip` route rather than the geometry
     * one. GRAPHPAN does keep the pointer-outside case out of here, but every
     * `skip = 1` clause above jumps the whole rect loop, leaving is_inside 0
     * with GRAPHPAN still set: hold LMB down in a margin and add Shift, and
     * `event == MotionNotify && Button1Mask && ShiftMask` skips, so this branch
     * runs, clears GRAPHPAN and dropped the marker drag -- but left the AXIS arm
     * up. The stale arm then survived the release (the same skip keeps
     * waves_callback out) and graph_axis_press_arm() does not clear it either:
     * it returns early when the new press is not in a margin. The next plain LMB
     * press-drag in the PLOT BODY -- which owns no axis gesture at all -- then
     * committed a zoom from the abandoned press position. Measured before the
     * fix: y1/y2 0..2.5 -> 1.2537228..2.3920389 on a body drag. Leg AG15. */
    graph_axis_drag_abort();
    xctx->ui_state &= ~GRAPHPAN; /* terminate ongoing GRAPHPAN to avoid deadlocks */
    if(draw_xhair) {
      if(tclgetintvar("crosshair_size") == 0) {
        tclvareval(xctx->top_path, ".drw configure -cursor none" , NULL);
      } else {
        tclvareval(xctx->top_path, ".drw configure -cursor {}" , NULL);
      }
    } else
      tclvareval(xctx->top_path, ".drw configure -cursor {}" , NULL);
    if(xctx->graph_flags & 64) {
      tcleval("graph_show_measure stop");
    }
  }
  return is_inside;
}

/* do nothing if coordinates not changed unless force is given */
void redraw_w_a_l_r_p_z_rubbers(int force)
{
  double mx = xctx->mousex_snap;
  double my = xctx->mousey_snap;

  if(!force && xctx->mousex_snap == xctx->prev_rubberx && xctx->mousey_snap == xctx->prev_rubbery) return;

  if(xctx->ui_state & STARTZOOM) zoom_rectangle(RUBBER);
  if(xctx->ui_state & STARTWIRE) {
    if(xctx->constr_mv == 1) my = xctx->my_double_save;
    if(xctx->constr_mv == 2) mx = xctx->mx_double_save;
    if(tclgetboolvar("orthogonal_wiring")) {
      new_wire(RUBBER|CLEAR, xctx->mousex_snap, xctx->mousey_snap);
      recompute_orthogonal_manhattanline(xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2);
    }
    new_wire(RUBBER, mx, my);
  }
  if(xctx->ui_state & STARTARC) {
    if(xctx->constr_mv == 1) my = xctx->my_double_save;
    if(xctx->constr_mv == 2) mx = xctx->mx_double_save;
    new_arc(RUBBER, 0, mx, my);
  }
  if(xctx->ui_state & STARTLINE) {
    if(xctx->constr_mv == 1) my = xctx->my_double_save;
    if(xctx->constr_mv == 2) mx = xctx->mx_double_save;
    new_line(RUBBER, mx, my);
  }
  if(xctx->ui_state & STARTRECT) new_rect(RUBBER,mx, my);
  if(xctx->ui_state & STARTPOLYGON) {
    if(xctx->constr_mv == 1) my = xctx->my_double_save;
    if(xctx->constr_mv == 2) mx = xctx->mx_double_save;
    new_polygon(RUBBER, mx, my);
  }
  xctx->prev_rubberx = xctx->mousex_snap;
  xctx->prev_rubbery = xctx->mousey_snap;
}

/* Issue 0243 F3. Every EARLY RETURN in abort_operation() owes by hand what the `ui_state = 0` at
 * the bottom would have done for it. These bits are owned by no callee -- move_objects(ABORT)
 * clears STARTMOVE, copy_objects(ABORT) clears STARTCOPY, the placement teardown clears the
 * placement bits, and that is all -- so an early return leaves a drawing gesture armed with no
 * owner: redraw_w_a_l_r_p_z_rubbers() re-strokes its band on every pointer motion (and those paths
 * run no draw(), so nothing erases it), and the NEXT canvas click is consumed by the orphan, which
 * for STARTRECT/STARTARC means new_rect/new_arc(PLACE|END) commits a stray object and marks the
 * file modified. The set is exactly the gesture bits redraw_w_a_l_r_p_z_rubbers() re-strokes, plus
 * the menu arm; STARTWIRE|STARTLINE are excluded because the wire/line block owns them.
 *
 * ISSUE 0269 -- the shape half of that set now has a real owner, abort_shape_draw() below, so this
 * calls it instead of clearing the bits by hand. Two things change on these paths, both fixes:
 * the rubber band is ERASED rather than merely orphaned (none of the three early returns runs a
 * draw(), so the last stroke used to stay on screen), and the shape bits of ui_state2 go with it
 * (issue 0268: `arc gui` + `wire gui` + ESC left ui_state2 = MENUSTARTARC, ui_state = 0).
 * The bare `&= ~MENUSTART` stays for the NON-shape menu arms -- pending move / copy / wirecut /
 * rotate / descend -- which own no band and which abort_shape_draw() deliberately does not touch. */
static void clear_orphan_gesture_bits(void)
{
  abort_shape_draw();
  xctx->ui_state &= ~MENUSTART;
}

/* Is a verb-noun descend pick still waiting for its click? (issue 0257)
 *
 * MENUSTARTDESCEND ALONE, deliberately -- not the (MENUSTART && MENUSTARTDESCEND) conjunction the
 * check_menu_start_commands() arm uses. The state that needs ESC most is the one where MENUSTART
 * has already been BURNED: handle_button_release() clears MENUSTART unconditionally on any
 * Button1Mask release, so a press that some other Button-1 owner swallowed (a click mode, a
 * resting wire command) leaves MENUSTARTDESCEND set with MENUSTART clear. Measured under xvfb
 * 2026-08-10: ESC then fell straight through to the blanket `ui_state = 0` below,
 * hi_descend_pick_cancel never fired, and cmdmode::is_suspended stayed 1 for the rest of the
 * session -- command mode dead, and the residue survived a subsequent `xschem load`.
 * Reading the discriminator alone makes ESC able to redeem a stranded arm. It cannot misfire on a
 * live OTHER arm: every arming site ASSIGNS ui_state2 wholesale, so MENUSTARTDESCEND is set only
 * by `xschem descend_pick`, and the arm's own consumer (check_menu_start_commands) clears it.
 * The release-side unconditional MENUSTART clear is deliberately left alone -- it is the terminal
 * of every menu-armed gesture and its residue is asserted on by test_shape_draw_gate.tcl and
 * test_placement_wire_gate.tcl. */
static int descend_pick_arm_live(void)
{
  if(!xctx) return 0;
  return (xctx->ui_state2 & MENUSTARTDESCEND) ? 1 : 0;
}

/* resets UI state and aborts any pending operation. deselect!=0 also clears the
 * selection when nothing was pending (the legacy ESC behavior); deselect==0 keeps the
 * current selection and just redraws. ESC drives this via the `escape_deselects` var
 * (see src/xschem.tcl); all other internal callers pass 1.
 *
 * NOT wrapped in a log-suppress scope (issue 0071 Refactor B foundation, §20):
 * abort_operation is NOT a pure teardown -- the STARTPOLYGON arm below calls
 * new_polygon(END), which COMPLETES the polygon (store_poly + push_undo) and
 * self-logs `xschem polygon ...` (actions.c). ESC-closes-a-polygon is a real
 * logged edit, so a blanket suppress here would DROP that line (adversarial-review
 * MAJOR, empirically confirmed). No production composite is a genuinely zero-drift
 * suppress target today; the composite hazard is closed structurally by the
 * replay seam (replay_action_log) + the general push/pop primitive instead. */
void abort_operation(int deselect)
{
  int keep_last_command = 0;
  xctx->no_draw = 0;
  xctx->pin_pending = 0; /* drop any armed pin-click gesture (pin_selection.md D3) */
  xctx->pin_pending_add = 0; /* and any armed SHIFT+pin additive gesture (D6) */
  /* An aborted move never reaches end_move_copy_logged, which is the only place that
   * consumes a pending cadence deferred-selection restore (drag_sel_restore, spec
   * doc/claude/specs/cadence_modifier_drag.md). Free it here so it cannot leak past this
   * gesture into a later keyboard 'm'/'c' move (which has no press-select to clear it) and
   * spuriously restore a stale pre-press selection -- deselecting the just-moved object. */
  drag_sel_free();
  /* ESC also drops an armed waveform-marker gesture: the renderer stops
   * substituting the scratch record the moment the flag clears, and
   * abort_operation already redraws (doc/claude/specs/graph_markers.md) */
  graph_marker_drag_abort();
  /* ...and an armed axis-region drag zoom (issue 0190): the release then commits
   * nothing, and the draw() at the end of this function repaints over the rubber
   * band. XK_Escape has no waves_selected guard, so this is reached from the ASE
   * viewer too (wviewer::key_filter forwards ESC after cancelling its own drag). */
  graph_axis_drag_abort();
  tcleval("set constr_mv 0" );
  dbg(1, "abort_operation(): Escape: ui_state=%d, last_command=%d\n", xctx->ui_state, xctx->last_command);
  xctx->constr_mv=0;

  /* ESC while a verb-noun descend pick is armed (doc/claude/issues/0200-...). The blanket
   * `ui_state = 0` at the bottom of this function already drops the arm, but it does so
   * SILENTLY -- and since 0201 the Tcl side has, by then, SUSPENDED whatever command mode
   * was interrupted to make the pick possible (ASE Direct Plot's Button-1 seize, which
   * had to let go before an armed pick could ever see a click). With no continuation that
   * command stays suspended forever: its bindings never come back and its queued traces
   * are unreachable. Route ESC to the same terminal the click-on-empty-space cancel uses.
   * Clearing MENUSTARTDESCEND is hygiene rather than necessity -- every arming site
   * ASSIGNS ui_state2 wholesale, so a stale bit cannot be misread as a live arm -- but it
   * keeps `xschem get ui_state2` an honest report of what is armed, which is what the
   * 0200/0201 tests assert on.
   * Placed here, above the DESEL_MODE early return, because that arm returns.
   *
   * ISSUE 0257: the guard was the (MENUSTART && MENUSTARTDESCEND) conjunction and is now
   * descend_pick_arm_live() -- see it above for why a STRANDED arm (MENUSTART already burned by
   * the matching ButtonRelease) is exactly the state that needs this continuation. */
  if(descend_pick_arm_live()) {
    xctx->ui_state &= ~MENUSTART;
    xctx->ui_state2 &= ~MENUSTARTDESCEND;
    /* blanking the prompt is deliberate, so it must not be dropped by that prompt's own hold
     * (issue 0248): ESC is a KEY, and only a ButtonPress releases a hold on its own */
    statusmsg_hold_clear();
    if(has_x) statusmsg(" ", 1);
    tcleval("hi_descend_pick_cancel");
  }

  /* leaving interactive net-(un)highlight mode: clear its persistent statusbar prompt
   * (abort_operation does not otherwise refresh the statusbar) */
  if(xctx->ui_state & (NET_HILIGHT | NET_UNHILIGHT))
    tclvareval(xctx->top_path, ".statusbar.10 configure -state normal -text { }", NULL);

  /* leaving deselect-one-at-a-time mode (doc/claude/specs/deselect_one_mode.md): ESC
   * just exits the mode and KEEPS whatever is still selected (unlike the net-(un)hilight
   * modes above, which fall through to unselect_all). Clear the prompt and return. */
  if(xctx->ui_state & DESEL_MODE) {
    xctx->ui_state &= ~DESEL_MODE;
    clear_orphan_gesture_bits();  /* third early return, same debt (issue 0243 F3) */
    if(has_x)
      tclvareval(xctx->top_path, ".statusbar.10 configure -state normal -text { }", NULL);
    return;
  }

  if(xctx->ui_state & STARTPOLYGON) new_polygon(END, xctx->mousex_snap, xctx->mousey_snap);
  /* No `xctx->last_command &&` conjunct here (issue 0243 F3). It was there only to protect the
   * two-stage ESC below, but SEVERAL arms zero last_command while leaving STARTWIRE/STARTLINE set
   * -- `r`/`P`/`t` (callback.c: 'r', 'P', 't'), `xschem rect|polygon gui`, `place_text`. With the
   * conjunct, ESC after one of those skipped the rubber CLEAR, so the band had no owner left to
   * erase it (redraw_w_a_l_r_p_z_rubbers() only re-strokes while the bit is set) and skipped the
   * `ui_state &= ~(STARTWIRE|STARTLINE)` below, leaving the wire gesture armed after an ESC:
   * the reported "grey lines of the same dimensions as the wire drawn". The two-stage ESC is
   * preserved exactly where it is meaningful -- see the `if(xctx->last_command)` below. */
  if(xctx->ui_state & (STARTWIRE | STARTLINE)) {
    if(xctx->ui_state & STARTWIRE) new_wire(RUBBER|CLEAR, xctx->mousex_snap, xctx->mousey_snap);
    if(xctx->ui_state & STARTLINE) new_line(RUBBER|CLEAR, xctx->mousex_snap, xctx->mousey_snap);
    if(tclgetboolvar("draw_crosshair")) draw_crosshair(2, 0);
    /* The `return` below is the two-stage ESC of commit a797bc59 and exists for ONE reason: to
     * jump over `xctx->last_command=0;` so persistent wire/line COMMAND mode survives the first
     * ESC (the second one leaves it). But it also jumped over every teardown below -- and a
     * placement gesture can be armed ON TOP of a live wire draw (Add-Wire-Label / Add-Pin form,
     * symbol/text placement: none of them clears STARTWIRE, and unselect_all() only zeroes
     * ui_state when something was selected). One ESC then zeroed ui_state WHOLESALE, dropping
     * START_SYMPIN without ever running the delete() at :393 or the sympin_preview /
     * wirelabel_preview clears at :398-399. Result: the preview instance stays committed in
     * xctx->inst[] and sympin_preview stays 1 with ui_state == 0 -- the issue 0123 desync, here
     * terminal: :7878's click-select guard requires !sympin_preview, so no press can select,
     * grab or complete anything ever again, and wire_label_try_commit() (:2843) refuses forever
     * because START_SYMPIN is gone. Issue 0240; WIRING.md §8 class D (decline residue).
     * So: keep skipping last_command=0, stop skipping the teardown. Only the states that HAVE
     * teardown below fall through; a bare wire/line draw with a live command mode still returns
     * here, unchanged.
     * The rubber CLEAR above must stay FIRST: it erases by tiling from save_pixmap, which
     * delete()'s trailing full draw() (select.c:790) regenerates. */
    if(!(xctx->ui_state & (STARTMOVE | STARTCOPY | STARTMERGE))) {
      /* ...and the return is only meaningful when there IS a command mode to preserve. With
       * last_command == 0 (issue 0243 F3: the arms listed above zero it) it would jump over
       * nothing and merely skip unselect_all()/draw() at the bottom -- and draw() is the full
       * repaint the rubber CLEAR above depends on. So in that case fall through, which is what
       * this path did before F3 too (the conjunct kept it out of this block entirely). */
      if(xctx->last_command) {
        xctx->ui_state = 0;
        return;
      }
    }
    xctx->ui_state &= ~(STARTWIRE | STARTLINE);
    if(xctx->last_command) keep_last_command = 1;
  }
  if(!keep_last_command) xctx->last_command=0;
  /* xctx->manhattan_lines = 0; */
  if(xctx->ui_state & STARTMOVE)
  {
   move_objects(ABORT,0,0,0);
   abort_placement_preview();  /* no-op unless a cursor placement is armed (issue 0243 F2 / 0242) */
   /* ISSUE 0265 -- the teardown that was inline here (and again at the bare arm below) is now
    * abort_pending_merge(); the long rationale for the narrowed delete, the flag restore and the
    * repaint debt lives there, at the one copy. Called DIRECTLY rather than through
    * leave_merge_for(): this is ESC, not a competing gesture, so there is no `what` to name and no
    * statusbar hold to raise -- exactly as this arm calls abort_placement_preview() rather than
    * leave_placement_for() one line above.
    * ORDER IS LOAD-BEARING and unchanged: abort_placement_preview() above runs FIRST because the
    * two teardowns share xctx->preview_sel, and the four placement arms that keep the user's
    * selection stamp a SUPERSET of a co-armed merge -- so the placement teardown removes the paste
    * with the placement and this call then correctly resolves 0. Swapping them would delete the
    * merge subset and orphan the placement. (Co-arming is no longer reachable through a gated door
    * now that every arm calls leave_merge_for(), but gate_bypass still constructs it, and the
    * property is the reason the shared slot is safe at all.) */
   abort_pending_merge();
   /* Issue 0243 F3. This return is deliberate -- an ABORTED MOVE KEEPS ITS SELECTION
    * (move_objects(ABORT) never unselects; tests/headless/test_drag_keeps_selection.tcl case 7
    * pins it), so it must not fall through to the unselect_all() at the bottom -- which is
    * exactly why it owes the clear below. STARTWIRE|STARTLINE are not part of that debt: the
    * wire/line block above owns them and reaching here with either still set is impossible. */
   clear_orphan_gesture_bits();
   return;
  }
  if(xctx->ui_state & STARTCOPY)
  {
   copy_objects(ABORT);
   /* same early-return debt as the STARTMOVE branch above: copy_objects(ABORT) clears STARTCOPY
    * and nothing else, and this path runs no draw() either (issue 0243 F3) */
   clear_orphan_gesture_bits();
   return;
  }
  /* The BARE STARTMERGE arm: reached when STARTMOVE has already been cleared while the merge is
   * still pending. move_objects(ABORT) and move_objects(END)'s zero-delta early return (move.c)
   * both clear STARTMOVE and return BEFORE the END tail's STARTMERGE clear, so a
   * click-without-drag release on a pending paste followed by ESC lands here. Headlessly:
   * `xschem merge f` + `xschem move_objects abort` + `xschem abort_operation` (measured
   * ui_state 296 -> 264 -> 0). Same two defects as the nested arm above, same two fixes --
   * see issue 0244 and the comments there. */
  /* ISSUE 0265 -- same one teardown as the nested arm above; see abort_pending_merge(). This arm
   * falls through to the draw() at the bottom of the function, so the repaint the helper's else
   * branch pays here is redundant rather than missing -- and it only runs when the stamp resolves
   * to nothing. Accepted: see the branch's own comment for why one body with a spare draw() beats
   * a `dr` parameter answered eleven times. */
  /* ISSUE 0269 -- the shape half, on the fall-through path. The `ui_state = 0` two lines down would
   * drop the bits anyway and the draw() below would repaint over the band, so this is not about the
   * pixels: it is about ui_state2, which nothing has ever cleared here (issue 0268), and about one
   * owner for the state rather than three places that each know part of it. Sited BEFORE
   * abort_pending_merge(), which can draw(): the shape erase tiles from save_pixmap and must
   * precede any full repaint. Called directly rather than through leave_shape_draw_for(), for the
   * reason the merge arm above states: ESC is not a competing gesture, so there is no `what` to
   * name and no statusbar hold to raise. A live STARTPOLYGON never reaches here -- new_polygon(END)
   * at the top of this function has already committed it, which is the ratified ESC behaviour. */
  abort_shape_draw();
  abort_pending_merge();
  xctx->ui_state = 0;
  if(deselect) unselect_all(1);
  draw();
}

/* One click in interactive net-(un)highlight mode: act on the net/label/pin under the
 * cursor and stay in the mode (ESC exits via abort_operation). add!=0 highlights with
 * the current style and advances the style cursor (per-net); add==0 removes the
 * highlight. The clicked object is not left selected (transient). */
static void net_hilight_mode_click(int add)
{
  /* unselect_all() and unhilight_net() reset ui_state to 0 when something is selected,
   * which would drop us out of the mode after one click; save and restore the mode bit. */
  unsigned int mode = xctx->ui_state & (NET_HILIGHT | NET_UNHILIGHT);
  Selected sel = find_closest_obj(xctx->mousex, xctx->mousey, 0);
  /* act only on nets: a wire, or a net-bearing instance (label/pin), never a plain
   * device body (which hilight_net would highlight by its first pin, surprising the user) */
  if(sel.type == ELEMENT) {
    const char *t;
    if(xctx->inst[sel.n].ptr < 0) return; /* unbound/missing symbol: no symbol to inspect */
    t = (xctx->inst[sel.n].ptr + xctx->sym)->type;
    if(!(t && IS_LABEL_SH_OR_PIN(t))) return;
  } else if(sel.type != WIRE) return;
  unselect_all(0);
  select_object(xctx->mousex, xctx->mousey, SELECTED, 0, &sel);
  rebuild_selected_array();
  if(add) {
    hilight_net_styled();             /* re-style + advance cursor per net (shared) */
    unselect_all(0);                  /* transient: leave nothing selected */
    redraw_hilights(0);
  } else {
    unhilight_net(0);                 /* removes highlight; also unselects + redraws */
  }
  xctx->ui_state |= mode;             /* stay in the mode until ESC */
}

static void start_place_symbol(void)
{
    if(readonly_block()) return;
    if(symbol_view_block()) return;   /* no instances in a symbol view (ctx-menu / native insert) */
    /* phase 2 -- see leave_wire_draw_for(). The `xschem place_symbol` verb has been gated since
     * 0243 F1; this is the OTHER component-insert route (context-menu Insert symbol, the `I` key
     * and the Insert key, whenever new_file_browser is off) and it never went through it. */
    leave_wire_draw_for("Insert symbol");
    leave_shape_draw_for("Insert symbol");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
    /* issue 0242 -- the keyboard/context-menu twin of the `xschem place_symbol` verb, which is
     * gated in scheduler.c. Same rule at every arm, not just the one the bug report named. */
    leave_placement_for("Insert symbol");
    leave_merge_for("Insert symbol");  /* issue 0265 -- the pending-paste twin, always second (the
                                        * two teardowns share xctx->preview_sel) */
    xctx->last_command = 0;
    rebuild_selected_array();
    if(xctx->lastsel && xctx->sel_array[0].type==ELEMENT) {
      /* issue 0831 -- the symbol reference is .sch DATA and the old splice sat inside
       * a `[file dirname {...}]` COMMAND SUBSTITUTION, so a `}` or a `[` in it was
       * script (issues 0827 + 0829 at one site). The substitution is deleted outright:
       * the dirname is taken by tcl_call() and the result assigned with tclsetvar(),
       * which is Tcl_SetVar/TCL_GLOBAL_ONLY -- exactly what the old global-level `set`
       * did. abs_sym_path() returns tclresult() and tcl_call()'s tclsetvar() writes
       * through the interpreter, invalidating it, so each result is copied out before
       * the next call (the token.c sanitize() rule, util.c:1122). Heap copies, not a
       * fixed buffer: a symbol reference has no length bound and a bounded copy would
       * truncate silently. NB tcl_hook2() still evaluates a `tcleval(`-prefixed name
       * here -- that is by design (issue 0823) and no conversion changes it. */
      char *symref = NULL;
      char *instdir = NULL;
      my_strdup2(_ALLOC_ID_, &symref,
           abs_sym_path(tcl_hook2(xctx->inst[xctx->sel_array[0].n].name), ""));
      my_strdup2(_ALLOC_ID_, &instdir, tcl_call("file dirname", symref, NULL, NULL));
      tclsetvar("INITIALINSTDIR", instdir);
      my_free(_ALLOC_ID_, &symref);
      my_free(_ALLOC_ID_, &instdir);
    }
    xctx->mx_double_save = xctx->mousex_snap;
    xctx->my_double_save = xctx->mousey_snap;
    if(place_symbol(-1,NULL,xctx->mousex_snap, xctx->mousey_snap, 0, 0, NULL, 4, 1, 1/* to_push_undo */) ) {
     xctx->mousey_snap = xctx->my_double_save;
      xctx->mousex_snap = xctx->mx_double_save;
      move_objects(START,0,0,0);
      stamp_placement_preview();   /* issue 0241 -- see stamp_placement_preview() in select.c */
      xctx->ui_state |= PLACE_SYMBOL;
    }
}

void start_line(double mx, double my)
{
    if(readonly_block()) return;
    xctx->last_command = STARTLINE;
    if(xctx->ui_state & STARTLINE) {
      if(xctx->constr_mv != 2) {
        xctx->mx_double_save=mx;
      }
      if(xctx->constr_mv != 1) {
        xctx->my_double_save=my;
      }
      if(xctx->constr_mv == 1) my = xctx->my_double_save;
      if(xctx->constr_mv == 2) mx = xctx->mx_double_save;
    } else {
      /* xctx->manhattan_lines = 0; */
      xctx->mx_double_save=mx;
      xctx->my_double_save=my;
    }
    new_line(PLACE, mx, my);
}

static void draw_snap_cursor(int action);   /* defined below; used by the gate right here */

/* THE ESCAPE TERMINAL (issue 0245) -- the body of `case XK_Escape:` in handle_key_press(), lifted
 * out verbatim so it has a NAME and, through scheduler.c's `xschem escape`, a Tcl entry point.
 * It was previously reachable ONLY from the keysym switch, i.e. only from a real X key event that
 * Tk chose to hand to the generic `<KeyPress>` dispatcher. A modeless placement form that seizes
 * `.drw <Key-Escape>` (Add-Pin, Add-Wire-Label, Create-Instance) takes Escape instead -- Tk fires
 * the specific `<Key-Escape>` binding and never the generic one -- so with a form open these
 * sixteen lines simply did not run: measured under xvfb, `xschem wire` (ui_state 65536,
 * ui_state2 1) followed by a canvas Escape with an IDLE Add-Wire-Label form open left both words
 * byte-identical and the very next canvas click began an unrequested wire draw.
 *
 * Two halves, and they are deliberately not the same teardown:
 *   - the ABORT, gated by the `semaphore < 2` re-entrancy guard;
 *   - four REENTRANT siblings that run even when the guard skips the abort.
 * The siblings are NOT hoisted into abort_operation(): that has 24 call sites inside this file
 * alone plus 9 more in C and 10 in Tcl, and a .load dialog Cancel or a context-menu abort must
 * never stop a running simulation (tclstop) nor drop the resting wire command mode.
 * `snap_cursor` and `cadence_compat` are handle_key_press() parameters read from Tcl by callback()
 * microseconds earlier; re-reading them here keeps the helper self-contained and callable from a
 * verb, at the cost of two tclgetboolvar() lookups on a key press. */
void escape_terminal(void)
{
  if(!xctx) return;
  if(xctx->semaphore < 2) {
    /* escape_deselects gates the idle-case unselect: 0 => keep selection,
     * only redraw; 1 => legacy deselect-all. Pending ops abort regardless. */
    abort_operation(tclgetboolvar("escape_deselects"));
  }
  /* stuff that can be done reentrantly ... */
  tclsetvar("tclstop", "1"); /* stop simulation if any running */
  if(xctx->ui_state2 & MENUSTARTWIRE) {
    /* abort_operation() alone NEVER clears this bit (measured: `xschem wire` then
     * `xschem abort_operation` leaves ui_state 0 but ui_state2 1), and wire_draw_active
     * below reads it conjoined with MENUSTART */
    xctx->ui_state2 &= ~MENUSTARTWIRE;
  }
  if(tclgetboolvar("snap_cursor")) draw_snap_cursor(1); /* erase */
  if(tclgetboolvar("persistent_command") && (xctx->last_command & STARTWIRE) &&
     tclgetboolvar("cadence_compat")) {
    xctx->last_command &= ~STARTWIRE;
  }
}

/* Leave any live (or menu-armed) wire/line DRAW, or the RESTING wire/line command mode, before a
 * modal PLACEMENT is armed on top of it
 * (issue 0240). Two modal gestures at once is not a usable state even when every flag is
 * consistent: end_place_move_copy_zoom() tests STARTWIRE (:2872) BEFORE the placement arm
 * (:2927), so while a wire draw is live every click feeds the wire and the label/pin preview can
 * never reach its drop gate -- "you want to place the label, but XSCHEM wants to keep drawing
 * wire". User-ratified policy: entering Add-Wire-Label CANCELS the in-progress wire (nothing is
 * committed -- new_wire() pushes undo and stores only at PLACE, so an abandoned draw strands no
 * undo baseline and no copper) and then opens the form.
 * Surgical on purpose: it touches ONLY the wire/line gesture. abort_operation() cannot be reused
 * here -- on a form's per-keystroke `-place` RE-ARM a preview is already live, and tearing that
 * down would clear sympin_preview and make the next -place push a SECOND undo baseline for one
 * gesture (add_wire_label.md: one baseline per gesture).
 * Returns 1 if something was actually abandoned. */
int abort_wire_line_command(void)
{
  int aborted = 0;
  if(!xctx) return 0;
  if(xctx->ui_state & (STARTWIRE | STARTLINE)) {
    if(xctx->ui_state & STARTWIRE) new_wire(RUBBER|CLEAR, xctx->mousex_snap, xctx->mousey_snap);
    if(xctx->ui_state & STARTLINE) new_line(RUBBER|CLEAR, xctx->mousex_snap, xctx->mousey_snap);
    if(tclgetboolvar("draw_crosshair")) draw_crosshair(2, 0);
    xctx->ui_state &= ~(STARTWIRE | STARTLINE);
    aborted = 1;
  }
  /* a MENU-armed wire/line whose first click has not landed yet: left armed, the next canvas
   * press would start a wire UNDER the fresh preview and re-create the clash with no keystroke */
  if((xctx->ui_state & MENUSTART) &&
     (xctx->ui_state2 & (MENUSTARTWIRE | MENUSTARTSNAPWIRE | MENUSTARTLINE))) {
    xctx->ui_state &= ~MENUSTART;
    xctx->ui_state2 = 0;
    aborted = 1;
  }
  /* THE RESTING COMMAND MODE -- the state a user is in after ending a segment with a double
   * click: no STARTWIRE in ui_state, no rubber band, but `last_command` still owns the next
   * click and the diamond snap cursor is still up. Under `persistent_command` (set by
   * cadence_style_rc) the press handler at :7843 tests `last_command` ALONE and calls
   * start_wire() before any placement is offered the click -- so a label armed here can never
   * be dropped: every click starts a new wire while the preview rides the cursor (the reported
   * symptom, user 2026-08-06; ui_state has no STARTWIRE, which is why gating on ui_state alone
   * missed it). last_command only ever holds 0 / STARTWIRE / STARTLINE (:541, :476). */
  if(xctx->last_command) aborted = 1;
  if(aborted) {
    /* leave wire/line COMMAND mode too: keeping last_command armed would restart a wire on the
     * next press (:7843-7856, persistent_command) while the placement preview is still attached */
    xctx->last_command = 0;
    xctx->constr_mv = 0;
    tcleval("set constr_mv 0");
    /* the diamond snap cursor is drawn while `wire_draw_active` (:8665 -- STARTWIRE, or
     * persistent_command with last_command) and would otherwise linger until the next motion */
    if(has_x && tclgetintvar("snap_cursor")) draw_snap_cursor(1);
  }
  return aborted;
}

/* Tear down a modal cursor PLACEMENT preview (Add-Pin / Add-Wire-Label form preview, symbol or
 * text placement) without committing it. The mirror image of abort_wire_line_command(): that one
 * abandons a wire/line DRAW so a placement can be armed, this one abandons a PLACEMENT so a
 * wire/line draw can be armed (issue 0243 F2). Factored out of abort_operation(), which is its
 * first caller and keeps behaving exactly as before -- issue 0242 asks for the same helper for a
 * different set of callers, so it is written once, here, gated on the flags rather than on who is
 * calling. Not gated on `sympin_preview` alone: PLACE_SYMBOL / PLACE_TEXT previews carry no such
 * flag and are precisely the placements the 0243 census found jamming a wire draw.
 * Returns 1 if a preview was actually torn down. */
int abort_placement_preview(void)
{
  int save;
  if(!xctx) return 0;
  if(!(xctx->ui_state & (START_SYMPIN | PLACE_SYMBOL | PLACE_TEXT))) return 0;
  /* the preview rides the cursor as a move-in-progress; drop that first so delete() below
   * removes a settled object (abort_operation has already done this when it calls us) */
  if(xctx->ui_state & STARTMOVE) move_objects(ABORT, 0, 0, 0);
  save = xctx->modified;
  /* ISSUE 0241 -- delete the PREVIEW, not "whatever is selected".
   * delete() below is SELECTION-scoped (select.c). The "selection == preview" invariant is
   * established at the ARM and nothing defends it afterwards: the Add-Pin / Add-Wire-Label forms
   * are MODELESS, so between the arm and this teardown the user can reach Ctrl+A, Edit>Select
   * all or select_dangling_nets -- none of which inspects ui_state -- and the cancel then took
   * the whole drawing (measured: 1 wire + 1 instance -> 0/0). Worse, set_modify(save) below
   * restored the pre-delete flag on the assumption that only the preview went, so the emptied
   * schematic reported itself UNMODIFIED and closed with no prompt.
   * So re-establish the invariant HERE, from the identity stamped at the arm, instead of
   * trusting it to have survived. Everything downstream then becomes correct unchanged: the
   * delete(0)/delete(1) discriminator, the save/set_modify(save) pair, the undo baseline.
   * BACKSTOP: nothing resolves -> delete nothing and just clear the flags. A stray preview
   * object left in the drawing is cosmetic; a wiped schematic is not. */
  if(select_placement_preview() > 0) {
    /* An Add-Pin cursor preview pushed its undo baseline at arm and must be torn down
     * undo-free: delete(1) here would snapshot the (about-to-be-removed) preview pin and a
     * later undo would resurrect it (cadence_pin_name_text.md item #3). delete(0) keeps the
     * baseline as the single rollback point. Normal placements use delete(1) as before.
     * The START_SYMPIN conjunct is what keeps a STALE sympin_preview from making an UNRELATED
     * placement abort (PLACE_SYMBOL/PLACE_TEXT/graph) drop ITS undo snapshot. Issue 0240 justified
     * that conjunct with "a live preview always has START_SYMPIN set", which was NOT TRUE when it
     * was written: `add_graph` (scheduler.c) re-set START_SYMPIN after its own unselect_all(1), so
     * arming a graph on top of a live label preview left sympin_preview==1 with START_SYMPIN==1 and
     * this line read delete(0) for the GRAPH -- measured, an aborted graph vanished with no undo
     * baseline of its own. Issue 0242 made the premise true rather than assumed: every door that
     * can carry a stale sympin_preview into a fresh arm now tears the preview down first
     * (leave_placement_for() below). The conjunct stays -- it is the cheap local guard that keeps
     * this correct if a thirteenth arm is ever added without its gate, which is exactly the
     * residue check_placement_preview_invariant() reports. */
    delete((xctx->sympin_preview && (xctx->ui_state & START_SYMPIN)) ? 0 : 1/* to_push_undo */);
    set_modify(save); /* aborted placement: no change, so reset modify flag set by delete() */
  } else {
    /* Nothing to delete -- but select_placement_preview() may already have dropped the user's
     * selection with dr=0, on the promise that delete()'s trailing draw() (select.c) would
     * repaint. On THIS branch there is no delete(), and abort_operation()'s STARTMOVE arm
     * returns before its own draw(), so the SELLAYER highlight of the just-deselected objects
     * would stay painted until some unrelated redraw -- a paint/state desync of the class
     * WIRING.md tracks. Before the narrowing delete() ran unconditionally here and always drew,
     * so this keeps the repaint exactly as it was. */
    draw();
  }
  xctx->ui_state &= ~START_SYMPIN;
  xctx->ui_state &= ~PLACE_SYMBOL;
  xctx->ui_state &= ~PLACE_TEXT;
  xctx->sympin_preview = 0;
  xctx->wirelabel_preview = 0;   /* add_wire_label.md: torn-down label preview */
  clear_placement_preview();     /* issue 0241: the stamp dies with the preview it named */
  return 1;
}

/* ISSUE 0262, RATIFIED 2026-08-11 (decision D1) -- THE CLASS-WIDE ANSWER to the desync the
 * tripwire below reports. Not a gate: a REPAIR, run at the two funnels every actor passes through.
 *
 * WHY A REPAIR AND NOT A GATE ON THE VERB. The door 0262 measured is the bare `xschem unselect_all`
 * verb, and it stays ungated: it ARMS nothing, so the ratified "whatever you just pressed is what
 * you meant" rule (0240/0243 F2) has no subject, and gating it would put a delete() behind 866
 * scripted call sites and 82 C ones (re-measured 2026-08-11) whose dominant idiom is
 * `xschem unselect_all ; xschem select <thing>` -- a housekeeping PREFIX to a fresh selection, not
 * a gesture cancel. That includes slickprop::restore_selection (property_form.tcl), the Property
 * form's Cancel path, which is 0262's own stated worst case. Issue 0123's objection, unchanged.
 * And gating that one verb would close exactly ONE of the doors anyway: `save`/`saveas`/Ctrl+S
 * reaches the identical state through save_schematic()'s own unselect_all(1) (issue 0358).
 *
 * WHY REPORT-ONLY IS NO LONGER ENOUGH (decision D2). The tripwire's log-only form rested on 0262's
 * premise that the door is "not reachable from the GUI". Measured FALSE (issue 0397) on two routes,
 * one of them the DEFAULT chord Ctrl+Button2 -- `button,2,ctrl,canvas,edit.cycle_pin_type`
 * (mousebindings.csv) -> addpin::cycle_type (xschem.tcl), whose re-arm guard tests
 * `[winfo exists .addpin]` and so falls through for a live `.addlabel` preview -- and the other the
 * Hilight > "Compare schematics" menu item, whose entire -command body is the bare verb. The state
 * it leaves is TERMINAL, not merely wrong (see the tripwire header), and ESC cannot repair it: the
 * teardown is gated on the very bit that is gone. The only in-session recovery measured is
 * discarding the document.
 *
 * WHAT IT DOES, AND DELIBERATELY DOES NOT (decision D3). It clears the three fields unselect_all()
 * cannot reach -- sympin_preview, wirelabel_preview and the preview_sel stamp -- and posts one held
 * status line. It DELETES NOTHING: the object the user never dropped stays in the drawing and still
 * renames its net, and `modified` is left exactly as the door left it. So every door in the class,
 * named or not yet found, goes from TERMINAL to ORPHAN-ONLY at ONE site. Running the full stamped
 * teardown here instead was rejected: that is the gate's blast radius deferred to a later,
 * unrelated command entry and made less predictable, and it would cost a user OBJECT rather than a
 * flag on any future false positive.
 * Two of the three clears are load-bearing, not hygiene:
 *   - the STAMP: after the door preview_sel names what is now an ordinary document object, so a
 *     later unrelated place_text/place_symbol abort would resolve it and delete the user's work;
 *   - wirelabel_preview: left stale, end_place_move_copy_zoom()'s STARTMOVE branch routes the NEXT
 *     symbol drop into wire_label_try_commit(), which returns 0 while the branch still returns 1 --
 *     the click is swallowed and the symbol can never be committed.
 * BUT the stamp slot is SHARED with the pending merge (see abort_pending_merge() above), and a
 * co-armed `placement then merge` leaves this very desync while the MERGE owns the slot. Clearing
 * it there would destroy the paste's identity and make its own cancel delete nothing. So the stamp
 * clear is conditional on no OTHER gesture owning the slot; the two flags are not, they belong to
 * the dead placement alone.
 *
 * NO draw() (decision D8): this repairs STATE, not PAINT. Any rubber ghost the dropped STARTMOVE
 * left clears on the next full redraw, exactly as today -- and a draw() here would run at the head
 * of motion-event dispatch, which is the window-only-overlay erase hazard.
 * HONOURS gate_bypass (decision D6, rule 0247: the test-only construction seam every other gate
 * already honours -- suites must still be able to BUILD this state) but NOT `readonly`: that guard
 * exists on leave_placement_for() because that teardown IS a delete(), and copying it here would
 * leave read-only windows terminally dead forever.
 * Returns 1 if it repaired something. */
int repair_orphan_placement_preview(void)
{
  char msg[128];
  if(!xctx) return 0;
  /* BELT AND BRACES, NOT THE LOAD-BEARING GUARD, and no test can turn it red: the only caller,
   * check_placement_preview_invariant() below, tests this exact predicate before calling, so
   * mutating this line is semantically dead (measured -- issue 0262 sabotage S7 reddened nothing;
   * the same mutation AT THE TRIPWIRE reddened 5 predicted rows and 63 more). Kept because this
   * function is extern in xschem.h and a second caller would need it. The condition that decides
   * whether a repair happens is in the tripwire, not here. */
  if(!xctx->sympin_preview || (xctx->ui_state & START_SYMPIN)) return 0;  /* invariant holds */
  if(xctx->gate_bypass) return 0;   /* test-only construction seam, see xschem.h gate_bypass */
  xctx->sympin_preview = 0;
  xctx->wirelabel_preview = 0;
  /* the stamp dies with the preview it named (issue 0241) -- unless a live merge or a live
   * symbol/text placement is what the slot describes now (see the note above).
   * CORRECT ONLY BECAUSE OF AN UNENFORCED INVARIANT, restated here because nothing checks it:
   * every arm STAMPS immediately before it sets its bit (paste.c, scheduler.c, actions.c, draw.c
   * -- verified by inspection 2026-08-11), so a live bit always means the slot describes THAT
   * gesture. An arm that ever sets PLACE_SYMBOL/PLACE_TEXT/STARTMERGE without re-stamping would
   * make this line preserve a stale stamp naming a now-real document object -- which is exactly
   * the deletion hazard the header above calls load-bearing. */
  if(!(xctx->ui_state & (PLACE_SYMBOL | PLACE_TEXT | STARTMERGE))) clear_placement_preview();
  /* issue 0241: a teardown must name what it is tearing down. stderr alone (the dbg(0) below) is
   * not an answer -- no GUI user reads it, and a repair the user cannot see is indistinguishable
   * from the bug. statusmsg_hold() so the coordinate readout cannot eat it (issue 0248). */
  my_snprintf(msg, S(msg), "Pending placement abandoned by a deselect; object left in place");
  statusmsg_hold(msg, 1);
  return 1;
}

/* ISSUE 0242 tripwire -- NOT an assert (C89, and abort() in a GUI app is not acceptable).
 * The invariant: xctx->sympin_preview must never outlive START_SYMPIN. It is set only by the
 * three form `-place` arms (scheduler.c add_sch_pin / add_pin / add_wire_label) and cleared only
 * alongside the bit -- by abort_placement_preview() above, by the per-keystroke re-arm drop, by
 * the commit funnel, and by clear_drawing() (actions.c). Every OTHER actor that zeroes ui_state
 * -- which is every caller of unselect_all() with something selected, and a live preview is
 * always selected -- breaks it, because sympin_preview and wirelabel_preview are plain
 * Xschem_ctx fields, not ui_state bits. When it is broken the canvas is DEAD, not merely wrong:
 * the Button-1 click-select/grab block below requires !sympin_preview and wire_label_try_commit()
 * requires START_SYMPIN, so nothing can ever be selected, grabbed or dropped again until ESC --
 * and ESC cannot fix it either, since abort_placement_preview() is gated on the bit that is gone.
 * The doors 0242 enumerated are now gated (leave_placement_for() below, called from merge_file(),
 * place_symbol, place_text, add_graph, add_image and the undo/redo verbs), so this reports on a
 * door NOBODY HAS FOUND YET. That is the point: it turns "how many doors are left" from an
 * argument into an empirical question, permanently.
 * ISSUE 0262, RATIFIED: it no longer only reports. The detection branch now calls
 * repair_orphan_placement_preview() above, which un-sticks the flags and the stamp so the canvas
 * comes back -- deleting nothing, so the object the user never dropped is still there. Read that
 * function's header for why the repair, and not a gate on the door, is the ratified answer. The
 * DETECTION CONDITION IS UNCHANGED (decision D5): place_net_label() sets START_SYMPIN with no
 * sympin_preview and stays outside it on purpose, because that wider surface has never been
 * measured for false positives and a false positive now costs state rather than a log line.
 * Reports the TRANSITION, once per desync episode, not the state: at callback() entry this runs
 * on every motion event, and a stuck flag would otherwise emit thousands of identical lines.
 * The REPAIR is deliberately OUTSIDE that latch -- an episode built through the gate_bypass seam
 * is reported once and repaired on the first entry after the seam closes, which the latch would
 * otherwise swallow.
 * The latch is file-static rather than per-context on purpose -- it exists to make one line
 * appear on stderr, and a second window silently sharing the latch is a better failure than a
 * flooded log. Same for the repair, which acts on whichever xctx is current at entry: a second
 * window's orphan is repaired when that window becomes current. dbg(0) so it needs no -d flag: the
 * tests read it off stderr as a second oracle beside `xschem get sympin_preview`. */
void check_placement_preview_invariant(const char *where)
{
  static int reported = 0;
  if(!xctx) return;
  if(xctx->sympin_preview && !(xctx->ui_state & START_SYMPIN)) {
    if(!reported) {
      reported = 1;
      dbg(0, "placement_preview: sympin_preview=%d outlived START_SYMPIN at %s entry "
             "(ui_state=%u wirelabel_preview=%d instances=%d) -- issue 0242: an ungated door "
             "cleared the gesture bits without tearing the preview down; click-select and "
             "wire_label_try_commit() were dead. Issue 0262: repairing the flags now (the object "
             "the user never dropped is LEFT IN PLACE and still names its net)\n",
          xctx->sympin_preview, where, xctx->ui_state, xctx->wirelabel_preview, xctx->instances);
    }
    repair_orphan_placement_preview();
  } else {
    reported = 0;
  }
}

/* The reverse door of leave_wire_draw_for() (scheduler.c): a modal PLACEMENT and a wire/line draw
 * cannot coexist in EITHER order, because end_place_move_copy_zoom() tests STARTWIRE (:2872) before
 * the placement arm (:2927) and under persistent_command the press handler seizes the click one
 * step earlier still. Issue 0240 stopped a placement being armed on top of a draw; this stops a
 * draw being armed on top of a placement, where the symptom is worse -- Add-Pin has no escape but
 * ESC, which throws the pin away. User-ratified policy (2026-08-07, issue 0243 F2), the same rule
 * as 0240: whatever you just pressed is what you meant, so `w` / Shift+L / snap-wire / menu Wire
 * abandon the pending preview and start drawing.
 * Called from each wire/line VERB -- key, menu, toolbar, context menu, scripted `xschem wire|line
 * gui` -- and deliberately NOT from start_wire()/start_line() themselves: those are also the
 * per-CLICK continuation of a running draw (persistent_command calls start_wire() on every press,
 * before end_place_move_copy_zoom() ever sees the click), so a teardown there would kill a preview
 * on an ordinary mouse click instead of on the keystroke the user actually typed.
 * ISSUE 0242 generalizes it beyond wire/line: a placement preview may not coexist with ANY second
 * modal gesture, so the same door is now called from merge_file() (paste.c -- the `paste`/`merge`
 * verbs, Ctrl+V and the `-file` replay form), from `place_symbol`, `place_text`, `add_graph`,
 * `add_image`, and from the `undo`/`redo` verbs at the perform_action boundary. Same ratified
 * policy, same message, one implementation -- `what` is just the name of whatever seized the
 * gesture. The one door 0242 measured that is deliberately NOT gated here is the bare
 * `xschem unselect_all` verb: it arms nothing, so the "whatever you just pressed is what you
 * meant" rule has no subject, and gating it would put a delete() behind 866 scripted call sites
 * and 82 C ones (re-measured 2026-08-11) -- the same objection that keeps the teardown out of
 * unselect_all() itself (issue 0123). RATIFIED, issue 0262 decision D1, 2026-08-11: that carve-out
 * is permanent and it is not an open question any more. The terminal half of the residue is
 * answered ONCE, class-wide, by repair_orphan_placement_preview() above -- no verb acquires a
 * delete() for the sake of the flags alone. The other half of the ratified rule (D9 rule B) is
 * that a door which additionally COMMITS or PERSISTS the orphan still needs its own VERB gate,
 * because a repair is retroactive and cannot un-write a file or un-emit a deck: `netlist` has that
 * gate (issue 0263), `save`/`saveas`/Ctrl+S does not (issue 0358, still open).
 * Not called from the pure-commit coordinate forms (`xschem wire x1 y1 x2 y2`, snapped_wire()'s
 * END half): those commit outright, arm no draw, and are the replay/test seams.
 * Returns 1 if the caller may go ahead and arm the draw. It no longer returns 0 for anything --
 * the one decline it ever had was the 0241 carve-out below, now gone -- but the int result is
 * kept: every wire/line arm already tests it, so a future refusal needs no call-site churn. */
int leave_placement_for(const char *what)
{
  char msg[128];
  if(!xctx) return 1;
  if(xctx->gate_bypass) return 1;   /* test-only construction seam, see xschem.h gate_bypass */
  if(!(xctx->ui_state & (START_SYMPIN | PLACE_SYMBOL | PLACE_TEXT))) return 1;
  /* a read-only window refuses the teardown outright: it is a delete(), and `xschem snap_wire` is
   * the one wire arm with no readonly reject of its own (the others call readonly_block() /
   * scheduler_readonly_reject() before they get here) */
  if(xctx->readonly) return 1;
  /* Between 0243 F2 and 0241 this function DECLINED (returned 0, draw not armed) whenever
   * xctx->lastsel > 1, because abort_placement_preview() then removed the SELECTION rather than
   * the preview and handing that delete() to the three commonest drawing keys would have wiped
   * the drawing on the first `w` after a Ctrl+A (measured: 2 wires + preview + select_all + `w`
   * -> 0 wires). The teardown is now scoped to the preview's stamped identity, so the reason is
   * gone and so is the guard -- which also removes the single inconsistency left in the ratified
   * modal-gesture rule: every other verb cancelled the pending gesture, this one alone refused.
   * tests/headless/test_placement_wire_gate.tcl E7 now asserts the opposite. */
  if(!abort_placement_preview()) return 1;
  my_snprintf(msg, S(msg), "%s: pending placement abandoned", what);
  statusmsg_hold(msg, 1);
  return 1;
}

/* Tear down a pending PASTE/MERGE (STARTMERGE) without committing it -- the merge twin of
 * abort_placement_preview() above, and the body abort_operation()'s two merge arms used to carry
 * inline, once each. Issue 0265.
 *
 * WHY IT IS A FUNCTION. STARTMERGE has exactly ONE setter (merge_file(), paste.c) and three
 * teardown-bearing clears: the commit tail (move.c) and abort_operation()'s two arms. Every OTHER
 * way the bit disappeared was unselect_all()'s wholesale `ui_state = 0` (select.c), which fires
 * whenever anything is selected -- and a pending paste is ALWAYS selected, because that selection
 * is what the drag carries. So the paste was never CANCELLED by a second gesture; it was silently
 * ACCEPTED, leaving a committed, netlist-visible set of objects the user never dropped (measured:
 * `merge` `merge` ESC -> wires 1 -> 2 -> 3 -> 2, i.e. paste #1 kept). Gating the arms needs a third
 * caller of these four statements, and the duplication between the two existing copies is LITERALLY
 * how issue 0244 was born -- the 2022 fix 0bb4c9f2 made to the placement arm was never carried
 * across to them. So: one body, here.
 *
 * WHY NOT INSIDE unselect_all(): 87 C call sites and 817 scripted ones, several inside netlisting
 * and live fluid passes -- it would make a DESELECT silently delete objects. Issue 0123's reason,
 * re-ratified by 0262. Gate the ARMS (leave_merge_for() below is what they call).
 *
 * THE SHARED preview_sel SLOT. The stamp read here is the same field the placement preview uses
 * (see the riders in abort_operation() and merge_file()). Callers that may have BOTH gestures live
 * must run the PLACEMENT teardown FIRST, exactly as abort_operation() does: the four placement arms
 * that keep the user's selection stamp a SUPERSET of the merge, so the placement teardown removes
 * the paste with the placement and this one then correctly resolves 0 and deletes nothing. Running
 * this one first would delete the merge subset and leave the placement's own objects behind.
 *
 * Returns 1 if a pending merge was actually torn down. */
int abort_pending_merge(void)
{
  unsigned int seq;
  if(!xctx) return 0;
  if(!(xctx->ui_state & STARTMERGE)) return 0;
  /* ISSUE 0267 -- read the modify sequence BEFORE this teardown's own delete() dirties it, so the
   * comparison below is "did anyone OTHER THAN this cancel claim a modification since the arm".
   * Taken before move_objects(ABORT) too: an aborted move deliberately does not set_modify (move.c),
   * so this is only belt, and belt on the conservative side (a spurious mismatch leaves the buffer
   * DIRTY, which loses nothing). */
  seq = xctx->modify_seq;
  /* the paste rides the cursor as a move-in-progress; drop that first so the delete() below removes
   * a settled object. abort_operation() has already done this when IT calls; a fresh caller
   * (merge_file(), a placement arm, a wire/line arm) has not. move_objects(ABORT) clears STARTMOVE,
   * so the guard also makes the call idempotent. */
  if(xctx->ui_state & STARTMOVE) move_objects(ABORT, 0, 0, 0);
  /* ISSUE 0244 part B / ISSUE 0241 -- delete the PASTE, not "whatever is selected". delete() is
   * selection-scoped, and the "selection == the merged objects" invariant is established by
   * merge_file() with nothing defending it afterwards: one Ctrl+A between the paste and here turned
   * the cancel into a whole-document delete. The stamp taken at the arm re-establishes it.
   * BACKSTOP: nothing resolves -> delete nothing. A leftover pasted object is cosmetic; a wiped
   * schematic is not. */
  if(select_placement_preview() > 0) {
    delete(1/* to_push_undo */);
  } else {
    /* THIS FUNCTION OWNS THE REPAINT DEBT, unconditionally -- decided, not inherited.
     * select_placement_preview() drops the current selection with dr=0 on the promise that
     * delete()'s trailing draw() (select.c) repaints; on this branch there is no delete(), so the
     * SELLAYER highlight of the just-deselected objects would stay painted. Some callers redraw
     * straight after (merge_file() is about to load and draw; abort_operation()'s bare arm falls
     * through to its own draw()) and for them this is one redundant full repaint -- on a branch that
     * only runs when the stamp resolves to nothing, i.e. never in the common case. A `dr` parameter
     * would buy that back at the price of a per-call-site correctness question at 23 arms; a
     * silently-wrong repaint is the expensive mistake here, not a spare draw(). Same reasoning, same
     * shape, as abort_placement_preview()'s else branch. */
    draw();
  }
  clear_placement_preview();  /* the stamp dies with the gesture it named: ids survive an undo, so a
                               * resurrected paste must not be deletable by a later, unrelated
                               * abort (the 0123/0240 desync class, WIRING.md §8 D) */
  xctx->ui_state &= ~STARTMERGE;
  /* ISSUE 0244 -- an aborted merge restores the document, so it must restore the FLAG, not zero it.
   * See xctx->pre_merge_modified (xschem.h) and its latch in merge_file() (paste.c) for why the
   * pre-merge value has to be latched rather than read here. `if(!pre_merge_modified)` rather than
   * set_modify(xctx->pre_merge_modified): on the dirty path delete()'s own set_modify(1) has
   * already rewritten the `~` backup with the correct restored content, so the flat form would
   * trigger a second, redundant write_backup(); it also keeps set_modify(0)'s
   * `mod == 0 && prev_set_modify` branch -- the Netlist/Simulate/Waves button recolor -- on exactly
   * the paths that had it before.
   * ISSUE 0267 -- and only while the latch still DESCRIBES this document. pre_merge_modified is
   * written once, at the arm; gating every arm (leave_merge_for() below) bounds a pending merge's
   * lifetime against every ARMING gesture, but NOT against the pure-commit forms
   * (`xschem wire x1 y1 x2 y2`, `xschem text ...`, menus, keybindings, action-log replay), which are
   * deliberately never gated -- they are the replay/test seams. So a real edit can still land
   * between the arm and the ESC, and restoring a flag that predates it reported that edit SAVED
   * (measured: clean doc, merge, move_objects abort, one wire + one text, ESC -> both survive,
   * modified == 0). The sequence test is what makes the latch self-invalidating; a second latch
   * would only move the problem. */
  if(!xctx->pre_merge_modified && seq == xctx->merge_modify_seq) set_modify(0);
  return 1;
}

/* The merge twin of leave_placement_for() above: same ratified rule (whatever you just pressed is
 * what you meant), same shape, same reason for living at the VERBS rather than inside the shared
 * primitive every click also reaches. Called from merge_file() itself (a second Ctrl+V), from all
 * twelve placement arms, and from the wire/line draw arms -- the last of those is the remaining
 * direction of plan_modal_gesture_exclusion.md phase 4. (That plan also recorded `merge cancels a
 * live draw` as already working, "because merge_file() calls leave_placement_for(), which is the
 * wire/line teardown too" -- FALSE, and measured so: leave_placement_for() calls
 * abort_placement_preview(), which never touches STARTWIRE|STARTLINE. Issue 0271 gave merge_file()
 * the wire gate it never had.)
 * Deliberately NOT called from the undo/redo verbs, unlike leave_placement_for(): a pending merge is
 * fully covered by the undo stack (merge_file() pushes its baseline BEFORE loading), so `undo`
 * already removes the paste correctly -- and a delete()+push_undo run in front of the pop would make
 * undo RESTORE the paste instead. A placement preview has no such coverage, which is why 0242
 * needed the gate there.
 * `what` is just the name of whatever seized the gesture. Returns 1 if the caller may go ahead; like
 * leave_placement_for() it never declines today, but the int is kept so a future refusal needs no
 * call-site churn. */
/* Tear down a live SHAPE draw -- rectangle, polygon, arc, circle or zoom box -- without committing
 * it. The fourth teardown of the family, after abort_wire_line_command(), abort_placement_preview()
 * and abort_pending_merge(). Issue 0269, phase 3 of
 * doc/claude/suggestions/plan_modal_gesture_exclusion.md.
 *
 * WHY IT IS NEEDED. Until this existed NOTHING abandoned a shape draw: the four bits were set by
 * actions.c and cleared only by their own completion, by unselect_all()'s wholesale `ui_state = 0`,
 * or by clear_orphan_gesture_bits() below on the ESC path -- a residue sweep, not a teardown. So
 * every other gesture armed straight on top of a live shape (measured: `rect gui` + `wire gui` ->
 * ui_state 3, `rect gui` + `place_symbol` -> 8234, `rect gui` + merge -> 298), and the co-armed
 * state is unusable in exactly the way issue 0240 documented for wire/line: handle_button_press()
 * runs check_menu_start_commands() BEFORE end_place_move_copy_zoom(), and inside the latter all
 * four shape bits are tested before the STARTMOVE arm that commits a placement. STARTPOLYGON is
 * the worst case and is UNBOUNDED -- new_polygon(ADD) never clears it, so every click adds a point
 * and a preview armed on top can never be dropped at all.
 *
 * WHAT IT DOES, AND WHAT IT DOES NOT. A shape draw owns no objects: new_rect/new_arc/new_polygon
 * push undo and store only when the gesture COMPLETES, and zoom_rectangle() never touches the
 * document. So unlike the placement and merge teardowns there is no delete(), no undo baseline to
 * strand, no selection stamp to resolve and (since issue 0270 moved the polygon's set_modify(1)
 * down to its store_poly) no modify flag to restore. What it does owe is the RUBBER BAND: it is
 * painted, and clearing the bit only stops redraw_w_a_l_r_p_z_rubbers() re-stroking it on the next
 * motion -- the last stroke stays on screen. Hence the RUBBER|CLEAR erase FIRST, before the bits go
 * and before any caller's draw(): the erase tiles from save_pixmap, which a full draw() regenerates
 * (the ordering rule already documented in abort_operation() below).
 *
 * BOTH INTERFACE BRANCHES. `infix_interface 1` arms the gesture at the keystroke (STARTRECT etc.);
 * `0` -- what cadence_style_rc sets -- arms MENUSTART plus a MENUSTARTSHAPE bit in ui_state2 and the
 * first click starts it. Testing ui_state alone would look green and do nothing for cadence users
 * (plan landmine 5). MENUSTART is cleared only when the bit that qualifies it IS a shape: the same
 * bit also carries pending move / copy / wirecut / rotate / descend arms, which own no band.
 *
 * THE POLYGON, ratified 2026-08-09: a competing gesture ABANDONS an in-progress polygon (no
 * store_poly, no push_undo, no `xschem polygon ...` action-log line), while ESC keeps COMMITTING it
 * -- abort_operation() still calls new_polygon(END) below, unchanged. The two are not inconsistent:
 * ESC is the gesture's own terminal and closing the polygon is its documented meaning, whereas a
 * second gesture is the ratified "whatever you just pressed is what you meant" rule, and silently
 * committing a half-drawn polygon because the user pressed `w` is exactly the issue 0265 defect
 * class. Abandoning also owes the point buffers, which only the commit branch frees today.
 *
 * THE ZOOM BOX is included, ratified the same day. It stores nothing and dirties nothing, so the
 * teardown is a pure bit-clear plus band erase (zoom_rectangle() writes xorigin/zoom only inside
 * its END branch, so an abandoned box owes no viewport restore) -- but it jams identically, because
 * it owns the next click, and leaving it armed under a fresh gesture steals that click.
 *
 * Returns 1 if a shape draw was actually torn down. */
int abort_shape_draw(void)
{
  unsigned int live, menu;
  if(!xctx) return 0;
  live = xctx->ui_state & (STARTRECT | STARTPOLYGON | STARTARC | STARTZOOM);
  menu = (xctx->ui_state & MENUSTART) ? (xctx->ui_state2 & MENUSTARTSHAPE) : 0;
  if(!live && !menu) return 0;
  /* THE ERASE, FIRST -- while the bits and the nl_* coordinates still describe the painted band.
   * Each of these is the RUBBER branch minus its re-stroke (actions.c); every drawtemp* primitive
   * is has_x-guarded, so this is a no-op headless rather than a crash. */
  if(live & STARTZOOM)    zoom_rectangle(RUBBER | CLEAR);
  if(live & STARTARC)     new_arc(RUBBER | CLEAR, 0., xctx->mousex_snap, xctx->mousey_snap);
  if(live & STARTRECT)    new_rect(RUBBER | CLEAR, xctx->mousex_snap, xctx->mousey_snap);
  if(live & STARTPOLYGON) new_polygon(RUBBER | CLEAR, xctx->mousex_snap, xctx->mousey_snap);
  xctx->ui_state &= ~(STARTRECT | STARTPOLYGON | STARTARC | STARTZOOM);
  /* ...and the shape bits of ui_state2, on BOTH paths. Not just the menu one: the first canvas
   * click consumes MENUSTART (callback.c's release arm) and LEAVES the discriminator behind, so a
   * clicked-then-abandoned arc kept ui_state2 = MENUSTARTARC with ui_state 0 -- the same stale-bit
   * residue issue 0268 measured on the ESC path, one step further along. Only the shape bits:
   * abort_wire_line_command() above zeroes the word wholesale, which is safe there only because it
   * has already established that the arm is a wire/line one, whereas the same blanket clear here
   * would silently cancel a co-existing MENUSTARTSTRETCH or MENUSTARTDESCEND. */
  xctx->ui_state2 &= ~MENUSTARTSHAPE;
  if(menu) xctx->ui_state &= ~MENUSTART;
  if(live & STARTPOLYGON) {
    /* the point buffers, freed by the commit branch (actions.c) and by nobody else. AFTER the
     * erase above, which reads nl_polyx/nl_polyy and nl_points. */
    my_free(_ALLOC_ID_, &xctx->nl_polyx);
    my_free(_ALLOC_ID_, &xctx->nl_polyy);
    xctx->nl_maxpoints = xctx->nl_points = 0;
  }
  return 1;
}

/* The shape twin of leave_wire_draw_for() (scheduler.c) and, like it, `void`: this gate can never
 * decline. The other two gates return int because their teardown is a delete() they may have to
 * refuse; this one deletes nothing, so there is no refusal to express -- including no `readonly`
 * check. That asymmetry is deliberate and load-bearing for the zoom box: `z` / `xschem zoom_box` is
 * a VIEW gesture and is the one shape arm a read-only window can actually reach, so a readonly
 * refusal here would leave exactly that case ungated. Issue 0269.
 * Called from every ARM -- key, menu, toolbar, context menu, scripted verb -- and never from the
 * shared per-click primitives (new_rect(PLACE) and friends are also the CONTINUATION of a running
 * draw, so a teardown there would kill a gesture on an ordinary mouse click; the same rule keeps
 * leave_placement_for() out of start_wire()/start_line()). Never from a pure-commit coordinate form
 * (`xschem rect x1 y1 x2 y2`, `xschem polygon ...`, `xschem arc x y r a b layer`,
 * `xschem zoom_box x1 y1 x2 y2`): those are the replay/test seams. Gate by BRANCH, not by verb --
 * a truncated form (`xschem rect 10 20`) falls into the ARM branch. */
void leave_shape_draw_for(const char *what)
{
  char msg[128];
  if(!xctx) return;
  if(xctx->gate_bypass) return;   /* test-only construction seam, see xschem.h gate_bypass */
  if(!abort_shape_draw()) return;
  my_snprintf(msg, S(msg), "%s: in-progress shape abandoned", what);
  statusmsg_hold(msg, 1);
}

int leave_merge_for(const char *what)
{
  char msg[128];
  if(!xctx) return 1;
  if(xctx->gate_bypass) return 1;   /* test-only construction seam, see xschem.h gate_bypass */
  if(!(xctx->ui_state & STARTMERGE)) return 1;
  /* a read-only window refuses the teardown outright: it IS a delete(). Unreachable today (the
   * `merge`/`paste` verbs both run scheduler_readonly_reject, so no read-only window can hold a
   * pending merge) -- kept for the same reason leave_placement_for() keeps its copy: the cheap
   * local guard that stays correct if a future door arms one. */
  if(xctx->readonly) return 1;
  if(!abort_pending_merge()) return 1;
  my_snprintf(msg, S(msg), "%s: pending paste abandoned", what);
  statusmsg_hold(msg, 1);
  return 1;
}

/* THE FIFTH TEARDOWN of the family (issue 0257), after abort_wire_line_command(),
 * abort_placement_preview(), abort_pending_merge() and abort_shape_draw(). This one ends a
 * persistent CLICK MODE -- interactive net-highlight, net-unhighlight, or deselect-one-at-a-time.
 *
 * WHY. Those three are the only gestures that own Button-1 from a RESTING ui_state bit rather than
 * from a live band or preview, and handle_button_press() dispatches all three (callback.c, the
 * NET_HILIGHT|NET_UNHILIGHT arm, the DESEL_MODE arm) with a `return` BEFORE the single
 * check_menu_start_commands() call site. So an armed verb-noun descend pick -- MENUSTART plus
 * MENUSTARTDESCEND, which only that call site reads -- can never receive its click while one of
 * them is up. Measured 2026-08-10 under xvfb: arming the pick inside net-highlight mode left the
 * press resolving nothing, and the matching ButtonRelease then cleared MENUSTART while leaving
 * MENUSTARTDESCEND set -- a combination no reader tests -- so cmdmode stayed suspended forever.
 *
 * WHAT IT DOES NOT DO. It touches NO selection: deselect mode is entered ON a selection and ending
 * the mode is not a reason to drop it (doc/claude/specs/deselect_one_mode.md), and the net-hilight
 * modes leave nothing selected by construction. It removes no highlights. It is a pure mode exit.
 * Note this is deliberately NARROWER than ESC: abort_operation()'s net-(un)hilight arm falls
 * through to `ui_state = 0` + unselect_all(), which is ESC's documented meaning, not a gate's.
 *
 * NO leave_click_mode_for() WRAPPER, unlike the other four. Its only caller (`xschem descend_pick`,
 * scheduler.c) arms a PROMPT one statement later, and a held prompt replaces a held gate line
 * (statusmsg_hold(), scheduler.c) -- so a gate message written here would be destroyed by the very
 * arm that asked for the teardown. The caller composes ONE held sentence carrying both facts
 * instead, which is what issue 0241's "a teardown must name what it is tearing down" asks for.
 * Hence the return type: the NAME of what ended (a static string, safe to hold), or NULL.
 * gate_bypass is honoured here rather than in a wrapper for the same reason. */
const char *abort_click_mode(void)
{
  const char *what = NULL;
  if(!xctx) return NULL;
  if(xctx->gate_bypass) return NULL;  /* test-only construction seam, see xschem.h gate_bypass */
  if(xctx->ui_state & NET_HILIGHT)        what = "net-highlight";
  else if(xctx->ui_state & NET_UNHILIGHT) what = "net-unhighlight";
  else if(xctx->ui_state & DESEL_MODE)    what = "deselect";
  if(!what) return NULL;
  xctx->ui_state &= ~(NET_HILIGHT | NET_UNHILIGHT | DESEL_MODE);
  /* the persistent mode prompt lives in the SECOND status field, written by
   * net_hilight_interactive() (scheduler.c) and enter_deselect_mode() above, and cleared by
   * abort_operation()'s two mode arms. A mode that ended must not keep advertising itself. */
  if(has_x)
    tclvareval(xctx->top_path, ".statusbar.10 configure -state normal -text { }", NULL);
  return what;
}

void start_wire(double mx, double my)
{
  dbg(1, "start_wire(): ui_state=%d, ui_state2=%d last_command=%d\n",
      xctx->ui_state, xctx->ui_state2, xctx->last_command);
  if(readonly_block()) return;
  xctx->last_command = STARTWIRE;
  if(xctx->ui_state & STARTWIRE) {
    if(tclgetboolvar("orthogonal_wiring") && !tclgetboolvar("constr_mv")){
      xctx->constr_mv = xctx->manhattan_lines;
      new_wire(CLEAR, mx, my);
      redraw_w_a_l_r_p_z_rubbers(1);
    }
    if(xctx->constr_mv != 2) {
      xctx->mx_double_save = mx;
    }
    if(xctx->constr_mv != 1) {
      xctx->my_double_save = my;
    }
    if(xctx->constr_mv == 1) my = xctx->my_double_save;
    if(xctx->constr_mv == 2) mx = xctx->mx_double_save;
  } else {
    /* xctx->manhattan_lines = 1; */
    xctx->mx_double_save=mx;
    xctx->my_double_save=my;
  }
  new_wire(PLACE,mx, my);
  if(tclgetboolvar("orthogonal_wiring") && !tclgetboolvar("constr_mv")) {
      xctx->constr_mv = 0;
  }
}

/* SPEC D4 -- THE RESOLUTION RULE, and it genuinely differs by kind of database.
 * doc/claude/specs/mixed_signal_signal_browser.md row D4 (RULINGS D4-3, D4-4).
 *
 * `p` is the last sample at or before the cursor (see the search in
 * backannotate_at_cursor_b_pos()), and this turns it into the value to report.
 *
 * DENSE ANALOG SWEEP -- interpolate between p and p+1, unchanged. The samples
 * are close enough together that the choice is invisible, and this is what the
 * viewer's readout has always shown (test_wave_viewer G15b pins Tcl-side
 * interpolation against this function's answer).
 *
 * SPARSE EVENT STREAM (sim_type "vcd") -- HOLD. The value at t is the value set
 * by the last event at or before t, which may be far to the left; that is not
 * an approximation, it is what a digital signal DOES between events. And the
 * approximation is not merely imprecise here, it is a different symbol: a VCD
 * database encodes 0 -> 0.0, 1 -> 1.0, X -> 0.5, Z -> 0.3 (spec C3) and
 * get_bus_value() reads anything in 0.2..0.8 as UNKNOWN, so interpolating
 * across the step vcd_read() materializes at each change (spec C2 emits
 * (t - 1 tick, old) then (t, new)) reports X for a perfectly known signal --
 * for a whole tick, which on a `$timescale 1ns` file is a nanosecond wide.
 * Only "vcd" takes this arm: a `table` database is a sampled table, not an
 * event stream.
 *
 * ...AND THE SWEEP COLUMN IS EXEMPT FROM THE HOLD (RULING D4-6, fix round).
 * A time axis is not an event-driven signal. Holding it froze a VCD's own
 * `time` readout at the last event's timestamp while the SAME Raw's annot_x
 * recorded the real cursor position -- the database contradicted itself, and
 * `xschem raw value time {}` on a VCD answered 150n for a cursor at 175n. The
 * sweep column interpolates like a dense analog one, which under D4-4's clamp
 * is simply the cursor position clipped into the database's own span.
 *
 * NEITHER KIND EXTRAPOLATES (RULING D4-4). Outside [sweep[p], sweep[p+1]] the
 * fraction is clamped, so a cursor before a database's first sample reads that
 * first sample verbatim and one past its last sample reads the last -- which is
 * the case a mixed strip creates on every cursor move, the VCD ending at 500 ns
 * under an analog raw that runs to 2 us. The old code extrapolated there off
 * the FORWARD segment's slope, and at the last sample of a dataset it did so by
 * reading values[idx][p + 1] one element past the my_calloc(allpoints) buffer
 * (save.c) -- silently plausible, occasionally not even repeatable. */
static double interpolate_yval(int idx, int p, double x, int sweep_idx, int point_not_last)
{
  Raw *raw = xctx->raw;
  double val = raw->values[idx][p];
  /* HOLD -- but never on the sweep column itself (RULING D4-6) */
  if(idx != sweep_idx && raw->sim_type && !strcmp(raw->sim_type, "vcd")) return val;
  /* not operating point, annotate from 'b' cursor */
  if(point_not_last && (raw->allpoints > 1) && sweep_idx >= 0) {
    SPICE_DATA *sweep_gv = raw->values[sweep_idx];
    SPICE_DATA *gv = raw->values[idx];
    double dx = sweep_gv[p + 1] - sweep_gv[p];
    double dy = gv[p + 1] - gv[p];
    double offset = x - sweep_gv[p];
    double frac = dx != 0.0 ? offset / dx : 0.0;
    if(frac < 0.0) frac = 0.0;   /* before the bracket: hold, never extrapolate */
    if(frac > 1.0) frac = 1.0;   /* past it: ditto */
    val += frac * dy;
  }
  return val;
}

/* Resolve cursor B in the database that is CURRENT RIGHT NOW and stamp its
 * annot_p / annot_x / annot_sweep_idx / cursor_b_val. `write_tcl` is 1 for the
 * one database that also publishes ngspice::ngspice_data (see D4-2 below).
 *
 * This is the shipped body of backannotate_at_cursor_b_pos(), moved down one
 * level so it can be run once per contributing database; nothing inside it
 * changed except the two Tcl_* publishing arms becoming conditional and the
 * point_not_last argument (RULING D4-4). */
static void backannotate_cursor_b_in_db(xRect *r, Graph_ctx *gr, int write_tcl)
{
  {
    int dset, first = -1, last, dataset = gr->dataset, i, p, ofs = 0, ofs_end;
    double start, end;
    int sweepvar_wrap = 0, sweep_idx;
    double xx, cursor2; /* xx is the p-th sweep variable value, cursor2 is cursor 'b' x position */
    Raw *raw = xctx->raw;
    int  save_datasets = -1, save_npoints = -1;
    int use_window = 1;   /* RULING D4-7, see the rescan below */
    if(!raw || !raw->values || !raw->cursor_b_val || raw->nvars <= 0) return;
    /* transform multiple OP points into a dc sweep */
    if(raw->sim_type && !strcmp(raw->sim_type, "op") && raw->datasets > 1 && raw->npoints[0] == 1) {
      save_datasets = raw->datasets;
      raw->datasets = 1;
      save_npoints = raw->npoints[0];
      raw->npoints[0] = raw->allpoints;
    }
    sweep_idx = get_raw_index(find_nth(get_tok_value(r->prop_ptr, "sweep", 0), ", ", "\"", 0, 1), NULL);
    if(sweep_idx < 0) sweep_idx = 0;
    if(r->flags & 4) { /* private_cursor */
      const char *s = get_tok_value(r->prop_ptr, "cursor2_x", 0);
      if(s[0]) {
        cursor2 = atof_spice(s);
      } else {
        cursor2 = xctx->graph_cursor2_x;
      }
    } else {
      cursor2 = xctx->graph_cursor2_x;
    }
    start = (gr->gx1 <= gr->gx2) ? gr->gx1 : gr->gx2;
    end = (gr->gx1 <= gr->gx2) ? gr->gx2 : gr->gx1;
    dbg(1, "start=%g, end=%g\n", start, end);
    if(gr->logx) {
      start = pow(10, start);
      end = pow(10, end);
    }
    dbg(1, "cursor b pos: %g dataset=%d\n",  cursor2, gr->dataset);
    if(dataset < 0) dataset = 0; /* if all datasets are plotted use first for backannotation */
    dbg(1, "dataset=%d\n", dataset);
    ofs = 0;
    rescan_no_window:
    for(dset = 0 ; dset < raw->datasets; dset++) {
      double prev_x, prev_prev_x;
      int cnt=0, wrap;
      register SPICE_DATA *gv = raw->values[sweep_idx];
      int s=0;
      ofs_end = ofs + raw->npoints[dset];
      first = -1;
      prev_prev_x = prev_x = 0;
      last = ofs;

      /* optimization: skip unwanted datasets, if no dc no need to detect sweep variable wraps */
      if(dataset >= 0 && strcmp(xctx->raw->sim_type, "dc") && dataset != sweepvar_wrap) goto done;

      for(p = ofs ; p < ofs_end; p++) {
        xx = gv[p];
        wrap = ( cnt > 1 && XSIGN(xx - prev_x) != XSIGN(prev_x - prev_prev_x));
        if(wrap) {
           sweepvar_wrap++;
           cnt = 0;
        }
        if(!use_window || (xx >= start && xx <= end)) {
          if(dataset == sweepvar_wrap) {
            dbg(1, "xx=%g cursor2=%g first=%d last=%d start=%g end=%g p=%d wrap=%d sweepvar_wrap=%d ofs=%d\n",
              xx, cursor2, first, last, start, end, p, wrap, sweepvar_wrap, ofs);
            if(first == -1) first = p;
            if(p == first) {
              if(xx == cursor2) {goto found;}
              s = XSIGN0(xx - cursor2);
              dbg(1, "s=%d\n", s);
            } else {
              int ss =  XSIGN0(xx -  cursor2);
              dbg(1, "s=%d, ss=%d\n", s, ss);
              if(ss != s) {goto found;}
            }
            last = p;
          }
          ++cnt;
        } /* if(!use_window || (xx >= start && xx <= end)) */
        prev_prev_x = prev_x;
        prev_x = xx;
      } /* for(p = ofs ; p < ofs + raw->npoints[dset]; p++) */
      /* offset pointing to next dataset */

      done:

      ofs = ofs_end;
      sweepvar_wrap++;
    } /* for(dset...) */
    /* RULING D4-7 (fix round) -- THE X WINDOW IS A RENDERING CONCERN AND MUST
     * NOT GATE THE ANNOTATION.
     *
     * The scan above only considers samples inside the STRIP'S CURRENT X WINDOW
     * [gr->gx1, gr->gx2]. That is fine while every contributing database
     * overlaps the window, and it is exactly wrong the moment one does not:
     * with the fan-out of RULING D4-1 a database whose samples all fall outside
     * the window fell straight through here with first == -1 and had NOTHING
     * stamped, so it kept the annot_p / annot_x / cursor_b_val of wherever the
     * cursor USED to be -- or, if it had never been annotated, the -1 and the
     * my_calloc zeros that read as "that signal is 0" rather than "nothing
     * asked". One cursor, two times: the databases drift apart again the moment
     * the user turns a wheel. Reachable by any ordinary X zoom
     * (wviewer::wheel_zoom writes x1/x2 on the graph rect), and by the fan-out
     * over sibling strips, whose windows are not this one's.
     *
     * So when the window yields nothing, rescan the SAME database with the
     * window filter off. The answer is then D4-4's own rule applied to that
     * database's whole sweep -- nearest of its own samples, clamped at both
     * ends, never extrapolated -- which is the answer a cursor at t deserves
     * from a database that simply is not on screen right now. It cannot loop:
     * use_window is only ever cleared. */
    if(first == -1 && use_window) {
      use_window = 0;
      ofs = 0;
      sweepvar_wrap = 0;
      goto rescan_no_window;
    }
    found:
    if(first != -1) {
      if(p > last) {
        double sweep0, sweep1;
        p = last;
        sweep0 = raw->values[sweep_idx][first];
        sweep1 = raw->values[sweep_idx][p];
        if(fabs(sweep0 - cursor2) < fabs(sweep1 - cursor2)) {
          p = first;
        }
      }
      dbg(1, "xx=%g, p=%d\n", xx, p);
      if(write_tcl) Tcl_UnsetVar(interp, "ngspice::ngspice_data", TCL_GLOBAL_ONLY);
      raw->annot_p = p;
      raw->annot_x = cursor2;
      raw->annot_sweep_idx = sweep_idx;
      for(i = 0; i < raw->nvars; ++i) {
        char s[100];
        /* (p + 1 < ofs_end), not (p < ofs_end): at the LAST sample of the
         * dataset the old test let interpolate_yval() read values[idx][p + 1],
         * one past the end of the buffer. RULING D4-4. */
        raw->cursor_b_val[i] = interpolate_yval(i, p, cursor2, sweep_idx, (p + 1 < ofs_end));
        if(write_tcl) {
          sprintf(s, "%.*g", xctx->ev_precision, raw->cursor_b_val[i]);
          /* tclvareval("array set ngspice::ngspice_data [list {",  raw->names[i], "} ", s, "]", NULL); */
          Tcl_SetVar2(interp, "ngspice::ngspice_data", raw->names[i], s, TCL_GLOBAL_ONLY);
        }
      }
      if(write_tcl) {
        Tcl_SetVar2(interp, "ngspice::ngspice_data", "n\\ vars", my_itoa( raw->nvars), TCL_GLOBAL_ONLY);
        Tcl_SetVar2(interp, "ngspice::ngspice_data", "n\\ points", "1", TCL_GLOBAL_ONLY);
      }
    }
    if(save_npoints != -1) { /* restore multiple OP points from artificial dc sweep */
      raw->datasets = save_datasets;
      raw->npoints[0] = save_npoints;
    }
  }
}

/* SPEC D4 -- ONE CURSOR, EVERY DATABASE.
 * doc/claude/specs/mixed_signal_signal_browser.md row D4.
 *
 * A cursor placed at time t is ONE object at ONE time. The state it resolves
 * to is per-`Raw` (annot_p, annot_x, annot_sweep_idx, cursor_b_val), so
 * resolving it in xctx->raw alone made it N objects that happened to have been
 * placed together and then drifted apart: on a mixed analog+VCD strip the
 * cursor read correctly on whichever database the registry cursor was parked on
 * and read whatever stale index the other one still held from the last time it
 * happened to be current -- or, for a database that was never current, index
 * -1, i.e. no readout at all.
 *
 * RULING D4-1: resolve in the CURRENT database plus every database contributing
 * a trace to this strip. graph_cursor_dbs() (draw.c) owns that set and the `%`
 * parse behind it; the switch/restore bracket lives here, where the unwind
 * point is known (issue 0305), and restores BOTH halves of the registry cursor.
 *
 * RULING D4-2: exactly ONE database publishes ngspice::ngspice_data, and it is
 * the one that is current on entry -- slots[0] by construction. The Tcl array is
 * a flat name->value map read by the schematic voltage overlay and by every
 * floater; letting each database rewrite it would make the last switch win.
 *
 * RULING D5-1/D5-3 (spec row D5, enforcement point 3 of 3) -- AND IF THAT ONE
 * DATABASE IS DIGITAL, NOBODY PUBLISHES AND THE ARRAY IS CLEARED. D4 left this
 * open and it was a live hole: `xschem raw read <f>.vcd vcd` makes the VCD
 * CURRENT (extra_rawfile()'s read arm), so the very next cursor motion wrote
 * that VCD's logic levels into ngspice::ngspice_data under the VCD's own names
 * -- and where a name collides with an analog one (`TOP.m.q` is a legal vector
 * name in a spice raw and the natural name in a VCD) the schematic overlay
 * silently swapped a measured voltage for a logic level. See RULING D5-1: a
 * logic level is not a voltage.
 *
 * The array is UNSET rather than left alone, and no OTHER database is promoted
 * into the publisher's place:
 *   - leaving it alone keeps the last analog position's numbers on screen while
 *     the user moves the cursor -- a stale overlay that looks live, which is the
 *     silent-wrong-answer shape this whole section exists to remove.
 *   - promoting the first analog slot would make the overlay follow a database
 *     the user did not make current, so which values the schematic showed would
 *     depend on registry order. "No analog database is current, so there is
 *     nothing to show" is the true statement, and `?` is how
 *     ngspice::get_voltage already renders it.
 * Nothing is echoed to the CIW here: this runs on EVERY cursor motion, and a
 * message on every motion is noise, not a notice. The `annotate_op` /
 * `update_op` request paths are where the user is told why (RULING D5-4).
 *
 * The per-`Raw` half of D4 is untouched: every contributing database, digital
 * ones included, still gets its annot_p / annot_x / cursor_b_val stamped, so
 * the viewer's readout bar still reads the digital trace at the cursor. D5 is
 * about the SCHEMATIC, not about the waveform window.
 */
void backannotate_at_cursor_b_pos(xRect *r, Graph_ctx *gr)
{
  /* S9 / invariant I3: the cursor-B live path republishes the annotation point
   * without changing anything the overlay's epoch can observe. See update_op()
   * (save.c) for the same bump and the reason it exists. */
  annot_data_changed();
  tcleval("catch {eval $cursor_2_hook}");
  if(sch_waves_loaded() >= 0) {
    int *slots = NULL, n, k;
    int entry_extra_idx = xctx->extra_idx, entry_prev_idx = xctx->extra_prev_idx;
    /* the entry database is the publisher (D4-2); a digital one publishes
     * nothing and the array is emptied instead (D5-3) */
    int publish = !raw_is_digital(xctx->raw);

    if(!publish) Tcl_UnsetVar(interp, "ngspice::ngspice_data", TCL_GLOBAL_ONLY);
    n = graph_cursor_dbs(r, &slots);
    if(n <= 0) {                      /* no rect, or no registry: the current DB */
      backannotate_cursor_b_in_db(r, gr, publish);
      my_free(_ALLOC_ID_, &slots);
      return;
    }
    for(k = 0; k < n; k++) {
      /* slots[0] IS the entry database, so the first pass needs no switch and a
       * session with one database makes no extra_rawfile() call at all */
      if(k > 0) {
        char buf[30];
        my_snprintf(buf, S(buf), "%d", slots[k]);
        if(!extra_rawfile(2, buf, NULL, -1.0, -1.0)) continue;
      }
      backannotate_cursor_b_in_db(r, gr, k == 0 && publish);
    }
    if(n > 1) {
      char buf[30];
      my_snprintf(buf, S(buf), "%d", entry_extra_idx);
      extra_rawfile(2, buf, NULL, -1.0, -1.0);
      /* the registry cursor is a PAIR: extra_prev_idx is where `xschem raw
       * switch_back` goes, and every switch above overwrote it (batch F item 2,
       * finding 1). draw.c's node_db_prev_restore() is the same two lines. */
      if(entry_prev_idx >= 0) xctx->extra_prev_idx = entry_prev_idx;
    }
    my_free(_ALLOC_ID_, &slots);
  }
}

/* S11 -- THE SAME CURSOR, WITH NO GRAPH IN THE PICTURE.
 * doc/claude/specs/op_annotation.md step S11; issues 0477-0480.
 *
 * `xschem set cursor2_x <t>` used to annotate ONLY when a graph rect sat on
 * GRIDLAYER with cursor B enabled (scheduler.c), so a schematic with a
 * transient raw loaded and NOTHING plotted -- the ordinary state for the
 * op_annot `6` / `Alt-6` keys -- moved a global nobody read while every
 * annotated value stayed frozen at update_op()'s point 0 (save.c). This
 * resolves cursor B directly against xctx->raw instead.
 *
 * NOTHING IS REIMPLEMENTED HERE. The sample scan, RULING D4-7's window rescan,
 * RULING D4-4's clamp and RULING D4-1's per-database fan-out are all reached
 * through the shipped public entry below, with a synthetic rect and a
 * stack-local Graph_ctx standing in for the graph that is not there. Invariant
 * I1 -- one behaviour, never two builders that drift: an out-of-range t
 * therefore HOLDS the endpoint here exactly as it does on the graph path, and a
 * vector missing from the raw still renders blank (I3), because both answers
 * come out of the same code rather than out of a private copy of it.
 *
 * THE ZEROED xRect IS A CORRECT ONE, and that was verified in the callees, not
 * assumed. backannotate_cursor_b_in_db() reads only two things out of the rect:
 * the `sweep` token -- and get_tok_value() returns "" for a NULL prop_ptr
 * (token.c), so sweep_idx falls back to 0, the time column -- and `flags & 4`
 * (private_cursor), clear, so the position is xctx->graph_cursor2_x.
 * graph_cursor_dbs() (draw.c) has an explicit non-graph arm,
 * `if(!(r->flags & 1)) goto cursor_dbs_done;`, that yields the current database
 * and nothing else: no `%` parse, no extra_rawfile() switch.
 *
 * THE Graph_ctx IS A STACK LOCAL AND CARRIES AN EXPLICIT WHOLE-SWEEP WINDOW.
 * Both halves of that are load-bearing:
 *
 *   - A STACK LOCAL, NEVER &xctx->graph_struct. save.c's raw_read() already
 *     does exactly this, for exactly this reason: the shared struct is live
 *     inside draw_graph(), which calls raw_read(). Writing into it from here
 *     would corrupt an in-progress draw. There is also no rect 0 to
 *     setup_graph_data() from -- that function indexes
 *     xctx->rect[GRIDLAYER][i] on its first line.
 *
 *   - [-HUGE_VAL, +HUGE_VAL], NOT a memset-0 window, and this is the step's
 *     sharpest trap because the zeroed one looks safe. A zeroed Graph_ctx is
 *     the degenerate window [0,0], and EVERY transient raw has a sample at
 *     exactly t = 0, which passes the scan's `xx >= start && xx <= end`. So
 *     `first` becomes 0 rather than -1, D4-7's rescan_no_window never fires,
 *     the scan exits with p = first = 0, and interpolate_yval() then clamps
 *     frac to 1 and walks one segment forward: POINT 1's value for every t past
 *     the second sample. Measured, v(d) = 1 at t = 3 ns on a raw whose point 3
 *     holds 3.0 -- a plausible wrong number on a schematic, which is precisely
 *     what invariant I3 and save.c RULING D5-1 forbid. The wide window admits
 *     every sample and reproduces the no-window answer exactly (nearest sample,
 *     clamped at both ends, never extrapolated) without touching the shipped
 *     scan. Row T4 of tests/headless/test_op_annot.tcl is the discriminator,
 *     and issue 0480 records the same defect where it is NOT fixed: the graph
 *     path, which borrows the shared struct and can therefore answer from a
 *     window belonging to a schematic that is no longer loaded.
 *
 * THE sch_waves_loaded() GATE IS HERE, AHEAD OF THE CALL, rather than left to
 * the one inside backannotate_at_cursor_b_pos(). That function fires
 * annot_data_changed() and `catch {eval $cursor_2_hook}` BEFORE its own test,
 * so calling it unconditionally would fire a user hook that has been graph-only
 * since it was written, and would move the very S9b flush counter that exists
 * to detect over-flushing, on every sheet with no data (rows T19/T20).
 *
 * Returns 1 when it annotated, so the caller knows whether the floater caches
 * need refreshing; 0 when there is nothing to annotate against and the call was
 * a byte-exact no-op. */
int backannotate_at_cursor_b_nograph(void)
{
  xRect r;
  Graph_ctx gr;
  if(!xctx || sch_waves_loaded() < 0) return 0;
  memset(&r, 0, sizeof(r));
  memset(&gr, 0, sizeof(gr));
  gr.gx1 = -HUGE_VAL;
  gr.gx2 = HUGE_VAL;
  backannotate_at_cursor_b_pos(&r, &gr);
  return 1;
}

/* ---------------------------------------------------------------------------
 * Waveform-marker gestures (doc/claude/specs/graph_markers.md).
 *
 * The whole gesture is SCRATCH-BASED: the record being dragged lives in
 * xctx->graph_marker_scratch and draw_graph_markers() substitutes it for the
 * stored one, so a motion event costs no allocation and no undo point, the
 * commit is a single token write at release, and ESC is one flag clear. The
 * cursor drags next door do the opposite (a subst_token per motion event) and
 * are why the graph writes have never been undoable.
 *
 * The press only ARMS. The RELEASE decides, on the same travel test the
 * issue-0152 wave-bold uses: no travel = SELECT, travel = COMMIT (landmine 20).
 * --------------------------------------------------------------------------- */

/* Arm a marker gesture if the press landed on one.
 *   1 = ours (armed): the caller must suppress the cursor grab / wave-bold /
 *       key arms for this event
 *  -1 = not ours, but the press CLEARED a selection somewhere: the caller must
 *       still repaint, and broadly, because the stale ring may be on another
 *       strip than the one under the pointer
 *   0 = not ours, nothing changed */
static int graph_marker_press(int i, Graph_ctx *gr, xRect *r)
{
  int num, part = 0;
  GraphMarker m;
  int gi = -1;

  (void) r;
  /* The ASE strip-reorder GRIP owns the right GRAPH_REORDER_HANDLE_W screen
   * pixels of the container over the full band height. A callout is clamped to
   * the PLOT box so it normally cannot reach there, but on a narrow strip the
   * two zones overlap -- the grip keeps first refusal, in C and in Tcl alike. */
  if(gr->reorder_handle &&
     X_TO_SCREEN(xctx->mousex) >= gr->sx2 - GRAPH_REORDER_HANDLE_W) return 0;
  num = graph_marker_at(i, X_TO_SCREEN(xctx->mousex), Y_TO_SCREEN(xctx->mousey),
                        GRAPH_MARKER_TOL, &part);
  if(num <= 0 || part == 0) {
    /* A press on empty graph space DESELECTS. Without this a stale window-wide
     * selection would make a later Delete over any strip eat the marker instead
     * of the schematic selection. */
    if(xctx->graph_marker_n_sel > 0) {
      graph_marker_select(-1, -1);
      return -1; /* the ring must be erased, possibly on another strip */
    }
    return 0;
  }
  if(!graph_marker_find(num, &gi, &m)) return 0;
  xctx->graph_marker_scratch = m;
  xctx->graph_marker_drag = part;
  /* THE EFFECTIVE MODE, LATCHED HERE -- from the selection state as it is at
   * PRESS time, and never re-read afterwards. `part` says what was GRABBED; the
   * mode says what the gesture DOES, and a text drag on an ALREADY-SELECTED
   * marker moves the anchor too (a rigid translation of the whole marker), so
   * part alone no longer determines the commit.
   *
   * It has to be latched rather than read at release for two independent
   * reasons: the renderer previews the mode on every motion event through the
   * scratch, and a release that re-read the selection would change the meaning
   * of a gesture the user had already half-performed.
   *
   * The three early returns above (the reorder-grip refusal, and the two
   * empty-space arms) latch nothing -- they are not our gesture. */
  if(part == 2 && graph_marker_is_selected(num))
    xctx->graph_marker_dragmode = GRAPH_MARKER_MODE_RIGID;
  else
    xctx->graph_marker_dragmode = part;
  xctx->graph_marker_dragnum = num;
  xctx->graph_marker_draggraph = gi;
  xctx->graph_marker_moved = 0;
  xctx->graph_marker_press_x = xctx->mousex;
  xctx->graph_marker_press_y = xctx->mousey;
  xctx->graph_marker_ldx0 = m.ldx;
  xctx->graph_marker_ldy0 = m.ldy;
  /* the anchor SAMPLE at press -- the origin a RIGID drag translates from. It
   * cannot be read back off the scratch, which drag_to rewrites on the first
   * motion event. Like ldx0/ldy0 it is press-time payload rather than gesture
   * state, and is only ever read while graph_marker_dragmode is RIGID -- which
   * this same press is what sets. */
  xctx->graph_marker_x0 = m.x;
  xctx->graph_marker_y0 = m.y;
  return 1;
}

/* Motion during an armed marker gesture. mx_w/my_w are SCHEMATIC coordinates.
 * Builds its OWN local Graph_ctx for the graph the drag was bound to at press
 * time (landmine 11 + landmine 5): the drag must never be re-keyed onto
 * whatever strip graph_master happens to be under the pointer now.
 * Returns 1 when the scratch changed and a repaint is needed. */
static int graph_marker_drag_to(double mx_w, double my_w)
{
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  int gi = xctx->graph_marker_draggraph;
  int saveflags;

  if(!xctx->graph_marker_drag) return 0;
  if(gi < 0 || gi >= xctx->rects[GRIDLAYER]) return 0;
  if(!(xctx->rect[GRIDLAYER][gi].flags & 1)) return 0;
  /* below the click threshold nothing happens at all: a 1-px jitter would
   * visibly re-snap the anchor and then be discarded as a click */
  if(!xctx->graph_marker_moved) {
    if(fabs(mx_w - xctx->graph_marker_press_x) <= GRAPH_CLICK_TOL * xctx->zoom &&
       fabs(my_w - xctx->graph_marker_press_y) <= GRAPH_CLICK_TOL * xctx->zoom) return 0;
    xctx->graph_marker_moved = 1;
  }
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  /* landmine 37: setup_graph_data() rewrites graph_flags' hcursor bits from the
   * rect it is given. Today this is provably a no-op here -- GRAPHPAN freezes
   * graph_master for the whole drag and graph_marker_draggraph is that same
   * graph, so the bits rewritten are the ones waves_callback just set -- but
   * the bracket is two lines and the invariant should not rest on that. */
  saveflags = xctx->graph_flags & (128 | 256);
  setup_graph_data(gi, 0, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->scx == 0.0 || gr->scy == 0.0) return 0;
  if(xctx->graph_marker_dragmode == GRAPH_MARKER_MODE_ANCHOR ||
     xctx->graph_marker_dragmode == GRAPH_MARKER_MODE_RIGID) {
    /* the ANCHOR: slide along its OWN trace, following the CURVE (issue 0193 --
     * it used to stop at real samples, which stranded a drag off-screen once the
     * zoom was tighter than the sample spacing) */
    GraphPointHit hit;
    double tx = mx_w, ty = my_w;

    if(xctx->graph_marker_dragmode == GRAPH_MARKER_MODE_RIGID) {
      /* RIGID TRANSLATION -- the selected-marker text drag. The pointer is over
       * the CALLOUT, not near the trace, so the anchor cannot chase it directly
       * and the projection rule has to be stated: the target is the pointer
       * MINUS the constant press-to-anchor vector latched at press, i.e. where
       * the anchor would be if the whole marker translated with the hand. That
       * target is then snapped by the SAME point-to-segment nearest-sample rule
       * a direct anchor drag uses, restricted to this marker's own wave and
       * dataset. ldx/ldy are left frozen at their press values, so the callout
       * keeps its offset and follows the anchor.
       *
       * Deliberately NOT a strict x-projection of the pointer onto the trace.
       * Two reasons: with ldx/ldy frozen, x-projection would make a purely
       * vertical text drag move nothing at all, and it would introduce a second
       * snapping rule different from the one the anchor drag already ships. On
       * a locally shallow trace -- most of a waveform -- translate-then-snap IS
       * the x-projection; they differ only on a steep segment, where following
       * 2D proximity is exactly what a direct anchor drag does there too. */
      double a0x = W_X(gr->logx ? mylog10(xctx->graph_marker_x0) : xctx->graph_marker_x0);
      double a0y = W_Y(gr->logy ? mylog10(xctx->graph_marker_y0) : xctx->graph_marker_y0);
      tx = a0x + (mx_w - xctx->graph_marker_press_x);
      ty = a0y + (my_w - xctx->graph_marker_press_y);
    }
    if(!graph_point_at(gi, X_TO_SCREEN(tx), Y_TO_SCREEN(ty), 1e30,
                       xctx->graph_marker_scratch.wave,
                       xctx->graph_marker_scratch.dataset, &hit)) return 0;
    /* ⚠ issue 0193: the no-op test is on the POSITION, not on (dataset, point).
     * The anchor is now the segment's left sample, so it is CONSTANT for the
     * whole length of a segment -- comparing it would make a drag within one
     * segment a no-op and the marker would jump sample to sample instead of
     * sliding along the curve. */
    if(hit.seg_point == xctx->graph_marker_scratch.point &&
       hit.seg_dataset == xctx->graph_marker_scratch.dataset &&
       hit.seg_x == xctx->graph_marker_scratch.x &&
       hit.seg_y == xctx->graph_marker_scratch.y) return 0;
    xctx->graph_marker_scratch.dataset = hit.seg_dataset;
    xctx->graph_marker_scratch.point = hit.seg_point;
    xctx->graph_marker_scratch.x = hit.seg_x;
    xctx->graph_marker_scratch.y = hit.seg_y;
  } else { /* the LABEL: a delta from the press, so it does not jump to the cursor */
    double ldx, ldy;
    if(gr->w == 0.0 || gr->h == 0.0) return 0;
    ldx = xctx->graph_marker_ldx0 + (mx_w - xctx->graph_marker_press_x) / gr->w;
    ldy = xctx->graph_marker_ldy0 + (my_w - xctx->graph_marker_press_y) / gr->h;
    if(ldx < -2.0) ldx = -2.0;
    if(ldx >  2.0) ldx =  2.0;
    if(ldy < -2.0) ldy = -2.0;
    if(ldy >  2.0) ldy =  2.0;
    if(ldx == xctx->graph_marker_scratch.ldx && ldy == xctx->graph_marker_scratch.ldy) return 0;
    xctx->graph_marker_scratch.ldx = ldx;
    xctx->graph_marker_scratch.ldy = ldy;
  }
  return 1;
}

static void graph_marker_drag_clear(void)
{
  xctx->graph_marker_drag = 0;
  xctx->graph_marker_dragmode = GRAPH_MARKER_MODE_NONE;
  xctx->graph_marker_dragnum = -1;
  xctx->graph_marker_draggraph = -1;
  xctx->graph_marker_moved = 0;
  xctx->graph_marker_press_x = xctx->graph_marker_press_y = -1e30;
}

/* Drop an armed gesture without committing (ESC, or a non-Button1 release). */
static void graph_marker_drag_abort(void)
{
  if(xctx && xctx->graph_marker_drag) graph_marker_drag_clear();
}

/* Release of an armed marker gesture. Resolves everything from
 * graph_marker_draggraph, never from the graph the pointer happens to be over,
 * so a drag that ends outside its own strip still commits to the right rect.
 * Returns 1 when the repaint must cover more than the master strip (the
 * selection moved off another graph, whose ring has to be erased). */
static int graph_marker_release(void)
{
  int num = xctx->graph_marker_dragnum;
  int gi = xctx->graph_marker_draggraph;
  int mode = xctx->graph_marker_dragmode;
  int moved = xctx->graph_marker_moved;
  int oldsel = xctx->graph_marker_sel;
  int oldgraph = xctx->graph_marker_selgraph;
  GraphMarker m = xctx->graph_marker_scratch;

  graph_marker_drag_clear();
  if(num <= 0) return 0;
  if(gi < 0 || gi >= xctx->rects[GRIDLAYER]) return 0;
  if(!(xctx->rect[GRIDLAYER][gi].flags & 1)) return 0;
  if(moved) {
    /* the EFFECTIVE MODE decides, not the grabbed part: a text drag on a
     * SELECTED marker is part 2 but commits an ANCHOR move. ldx/ldy were frozen
     * for the whole of that gesture, so there is nothing to commit on the label
     * side -- one token write, one undo point, one notify, and the action log
     * gets the data-addressed `xschem graph_marker anchor` line for free,
     * because the log line belongs to whichever primitive ran. */
    if(mode == GRAPH_MARKER_MODE_ANCHOR || mode == GRAPH_MARKER_MODE_RIGID)
      /* the scratch carries the interpolated position the drag ended on
       * (issue 0193), so the commit must pass it -- re-deriving from
       * (dataset, point) would snap the marker back to the segment's left end */
      graph_marker_anchor_at(num, m.dataset, m.point, 1, m.x, m.y);
    else if(mode == GRAPH_MARKER_MODE_LABEL)
      graph_marker_label_offset(num, m.ldx, m.ldy);
    return 0;
  }
  /* A plain CLICK selects. Clicking the ALREADY-SELECTED marker deselects, as
   * it always has -- but only when it is the WHOLE selection. With a pair
   * selected (issue 0189) the click is DISAMBIGUATING, so it COLLAPSES to the
   * one clicked (the issue-0174 D3 rule for traces), and a second click on it
   * then still deselects. */
  if(graph_marker_is_selected(num) && xctx->graph_marker_n_sel == 1)
    graph_marker_select(-1, -1);
  else graph_marker_select(num, gi);
  return (oldsel >= 0 && oldgraph != gi);
}

/* ---- axis-region drag zoom (issue 0190) gesture helpers -------------------
 *
 * doc/claude/specs/waveform_viewer_modes.md §17. LMB press-drag in a strip's
 * bottom (X-number) or left (Y-number) margin zooms that axis only. The three
 * pieces of geometry live in draw.c -- graph_axis_at() (which margin),
 * graph_axis_map() (THE formula) and graph_axis_zoom() (THE apply) -- and this
 * file only arms, paints the rubber band and commits. The map is NEVER inlined
 * here: it is shared with `xschem graph_axis_zoom`'s replay and with
 * `xschem get graph_axis_map`, and two copies would drift (landmine 45(a)). */

/* Drop an armed axis drag. Does NOT erase the rubber band -- the caller either
 * erases it first (the release) or redraws over it (abort_operation's draw()). */
static void graph_axis_drag_clear(void)
{
  if(!xctx) return;
  xctx->graph_axis_drag = GRAPH_AXIS_NONE;
  xctx->graph_axis_draggraph = -1;
  xctx->graph_axis_press = 0.0;
}

/* ESC / abort_operation hook, the graph_marker_drag_abort() twin. */
static void graph_axis_drag_abort(void)
{
  if(xctx && xctx->graph_axis_drag) {
    graph_axis_drag_clear();
    xctx->graph_rubber_active = 0; /* abort_operation() ends in draw() */
  }
}

/* The band the live rubber outline covers, in XSCHEM coordinates (what
 * drawtemprect takes, like the Button3 box-zoom rubber it sits beside). The
 * dragged axis runs press -> `moving`; the OTHER axis spans the whole plot box,
 * which is what makes it read as "this slice of the x axis" rather than a box.
 * Both ends clamped to the plot box, exactly as the Button3 rubber clamps its
 * moving corner. `gr` must be set up for the dragged graph. */
static void graph_axis_band(Graph_ctx *gr, int ax, double moving,
                            double *bx1, double *by1, double *bx2, double *by2)
{
  double p0, a1, b1, a2, b2;
  double xlo = gr->x1 < gr->x2 ? gr->x1 : gr->x2;
  double xhi = gr->x1 < gr->x2 ? gr->x2 : gr->x1;
  double ylo = gr->y1 < gr->y2 ? gr->y1 : gr->y2;
  double yhi = gr->y1 < gr->y2 ? gr->y2 : gr->y1;

  if(ax == GRAPH_AXIS_X) {
    p0 = X_TO_XSCHEM(xctx->graph_axis_press);
    if(p0 < xlo) p0 = xlo; if(p0 > xhi) p0 = xhi;
    if(moving < xlo) moving = xlo; if(moving > xhi) moving = xhi;
    a1 = p0; a2 = moving; b1 = ylo; b2 = yhi;
  } else {
    p0 = Y_TO_XSCHEM(xctx->graph_axis_press);
    if(p0 < ylo) p0 = ylo; if(p0 > yhi) p0 = yhi;
    if(moving < ylo) moving = ylo; if(moving > yhi) moving = yhi;
    a1 = xlo; a2 = xhi; b1 = p0; b2 = moving;
  }
  RECTORDER(a1, b1, a2, b2);
  *bx1 = a1; *by1 = b1; *bx2 = a2; *by2 = b2;
}

/* Arm on a Button1 press, from the EVENT's own canvas pixels (never
 * xctx->mousex/mousey -- landmine 43: every picking query on a strip takes the
 * caller's pixels and converts once). graph_axis_at() does all the deciding,
 * including declining the reorder grip and the legend. */
static void graph_axis_press_arm(int i, int mx, int my)
{
  int ax = graph_axis_at(i, (double)mx, (double)my);
  if(ax == GRAPH_AXIS_NONE) return;
  xctx->graph_axis_drag = ax;
  xctx->graph_axis_draggraph = i;
  xctx->graph_axis_press = (ax == GRAPH_AXIS_X) ? (double)mx : (double)my;
  xctx->graph_rubber_active = 0; /* fresh gesture: nothing drawn yet */
  dbg(1, "graph_axis_press_arm(): graph=%d axis=%d press=%g\n",
      i, ax, xctx->graph_axis_press);
}

/* process user input (arrow keys for now) when only graphs are selected */

/* xctx->graph_flags:
 *  1: dnu, reserved, used in draw_graphs()
 *  2: draw x-cursor1
 *  4: draw x-cursor2
 *  8: dnu, reserved, used in draw_graphs()
 * 16: move x-cursor1
 * 32: move x-cursor2
 * 64: show measurement tooltip
 * 128: draw y-cursor1 (hcursor)
 * 256: draw y-cursor2 (hcursor)
 * 512: move y-cursor1
 * 1024: move y-cursor2
 */
static int waves_callback(int event, int mx, int my, KeySym key, int button, int aux, int state)
{
  Graph_ctx *gr;
  int rstate; /* reduced state wit ShiftMask bit filtered out */
  int graph_use_ctrl_key = tclgetboolvar("graph_use_ctrl_key");
  int i, dataset = 0;
  int need_fullredraw = 0, need_all_redraw = 0, need_redraw = 0, need_redraw_master = 0;
  double xx1 = 0.0, xx2 = 0.0, yy1, yy2;
  double delta_threshold = 0.25;
  double zoom_m = 0.5;
  int save_mouse_at_end = 0, clear_graphpan_at_end = 0;
  int track_dset = -2; /* used to find dataset of closest wave to mouse if 't' is pressed */
  int mkpress = 0; /* graph_marker_press() verdict: 1 armed, -1 deselected, 0 not ours */
  /* issue 0191: the CTRL+wheel axis zoom consumed this event, so the plain wheel
   * PAN arms below must stand down -- and *only* then, which is what keeps
   * CTRL+wheel over the plot BODY behaving exactly as it does today (a graph X
   * pan of 0.05*gw, MEASURED, byte-identical to a plain wheel). */
  int wheel_axis_done = 0;
  xRect *r = NULL;
  int access_cond = !graph_use_ctrl_key || (state & ControlMask);

  dbg(1, "uistate=%d, graph_flags=%d\n", xctx->ui_state, xctx->graph_flags);
  /* if(event != -3 && !xctx->raw) return 0; */
  /* The snap grid is a schematic concept and does not apply to graphs (issue
   * 0143 — user: "snap grid does not apply to graph windows"). Override the
   * snapped pointer with the raw one for ALL graph interaction (box-zoom
   * rectangle, pan, region detection, cursors) so a drag can select any
   * sub-region, not grid steps. waves_callback only ever mutates graph tokens /
   * cursors, never schematic geometry, and callback() returns right after this
   * handler (the next event recomputes the snap), so this override is safe and
   * does not leak into schematic editing.
   *
   * ⚠ ITS SCOPE, STATED HONESTLY (issue 0177). This covers exactly the code
   * reached THROUGH waves_callback and nothing else. It said "safe and does not
   * leak", which is true, but the useful question is the other one: what does it
   * NOT reach? Everything that runs when waves_selected() DECLINES the event --
   * which on a strip includes the band just inside the rect edge, and therefore
   * the top of the LEGEND. On the ASE waveform viewer that hole is now closed one
   * level up: the window sets `xschem set no_snap 1` and callback() computes both
   * fields unsnapped at the source (~8200), so this assignment is a no-op there.
   *
   * It is NOT redundant and must stay: an ordinary SCHEMATIC window can embed
   * graphs, waves_callback runs on those too, and that context is not no_snap --
   * its grid is real and wanted everywhere except inside a graph. This line is
   * what keeps 0143's promise for them. */
  xctx->mousex_snap = xctx->mousex;
  xctx->mousey_snap = xctx->mousey;
  rstate = state; /* rstate does not have ShiftMask bit, so easier to test for KeyPress events */
  rstate &= ~ShiftMask; /* don't use ShiftMask, identifying characters is sufficient */
  #if HAS_CAIRO==1
  cairo_save(xctx->cairo_ctx);
  cairo_save(xctx->cairo_save_ctx);
  xctx->cairo_font =
        cairo_toy_font_face_create("Sans-Serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
  cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
  cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
  cairo_font_face_destroy(xctx->cairo_font);
  #endif
  gr = &xctx->graph_struct;
  if((i = xctx->graph_master) >= 0 && ((r = &xctx->rect[GRIDLAYER][i])->flags & 1)) {
    /* check if this is the master graph (the one containing the mouse pointer) */
    /* determine if mouse pointer is below xaxis or left of yaxis in some graph */
    setup_graph_data(i, 0, gr);

   /* Remember where a Button1 press landed, so its release can tell a CLICK from the
    * end of a drag (issue 0152). Kept in dedicated fields -- see the xschem.h comment
    * on graph_press_x for why mx/my_double_save cannot be used here. */
    if(event == ButtonPress && button == Button1) {
      xctx->graph_press_x = xctx->mousex;
      xctx->graph_press_y = xctx->mousey;
      /* A fresh press can never be the continuation of an armed marker drag, so
       * this is the one place that can guarantee no stale arm survives. It has
       * to be HERE, before the `if(ui_state & GRAPHPAN) goto finish;` below and
       * outside graph_marker_press(): the ASE viewer binds
       * <Shift-ButtonRelease-1> / <Alt-ButtonRelease-1> to a bare {break}, so a
       * modifier-held release never reaches C at all and the release-side
       * teardown cannot run. A surviving arm would make marker_grabbed answer 1
       * for every later press (killing the trace-drag and reorder seams) and
       * would commit the old move on the user's next unrelated click. */
      graph_marker_drag_abort();
    }

   /* Toggle bold ("selected") rendering of the wave nearest the pointer.
    *
    * This is a plain LMB CLICK on the plot body: the RELEASE of a Button1 press that
    * did not travel more than GRAPH_CLICK_TOL pixels. It used to be a Button3 PRESS,
    * which meant every RMB press-drag box-zoom (issue 0142) also bolded whatever trace
    * was nearest the press point -- the reported defect. A release-with-no-travel
    * trigger cannot be produced by any drag gesture, so the class is closed rather
    * than moved. Button3 inside the plot body is now box-zoom only.
    *
    * The click deliberately WINS over a cursor grab armed by the same press (user
    * decision): with no travel no cursor moved, and the ButtonRelease arm in the
    * per-graph loop below clears the grab flags regardless.
    *
    * Applies to every graph, on-canvas schematic graphs included, not just the ASE
    * waveform viewer. doc/claude/issues/0152-graph-rmb-bolds-wave.md
    *
    * Issue 0174 made the PICK precise and the toggle per-trace. Two tests gate
    * this arm and they answer different questions -- keep both:
    *   - GRAPH_CLICK_TOL (3 px * zoom, WORLD units) below: is this release a
    *     click or the end of a drag? The double-click arm (~1199) poisons
    *     graph_press_x/y with -1e30 to make this unsatisfiable, which is what
    *     stops a double-click from bolding underneath the wave dialog -- so this
    *     gate must stay on those two fields;
    *   - GRAPH_TRACE_PICK_TOL (10 SCREEN px) inside: is the click on a trace?
    * POINTINSIDE still reads the schematic-space mouse mirror because the arm is
    * plot-BODY-only (the legend margins are Button3's, ~896) and that contract is
    * unchanged. */
    /* A marker gesture owns its own release and MUST come first: the wave-bold
     * arm below is a release-only travel test with no knowledge of what the
     * press hit, so a no-travel marker SELECT would also toggle hilight_wave.
     * A non-Button1 release aborts the arm -- the per-graph teardown further
     * down only runs for button != Button3, so a stale arm would otherwise
     * commit an anchor move on the NEXT Button1 release.
     * It must NOT return: falling through is what reaches the GRAPHPAN clear. */
    if(event == ButtonRelease && xctx->graph_marker_drag) {
      if(button == Button1) {
        if(graph_marker_release()) need_all_redraw = 1;
      } else {
        graph_marker_drag_abort();
      }
      need_redraw_master = 1;
    }
    else if(event == ButtonRelease && button == Button1 &&
       fabs(xctx->mousex - xctx->graph_press_x) <= GRAPH_CLICK_TOL * xctx->zoom &&
       fabs(xctx->mousey - xctx->graph_press_y) <= GRAPH_CLICK_TOL * xctx->zoom) {
      int wcnt;
      /* TWO picking surfaces, one gesture (issue 0175). The plot BODY answers
       * with graph_wave_at (proximity to a drawn trace); the LEGEND answers with
       * graph_legend_at (which per-node slot the pointer is in). They are
       * mutually exclusive by construction -- the legend sits outside the plot
       * box -- and a click that is in neither (an axis margin, the reorder grip)
       * must change NOTHING, which is why `on_body` is carried separately
       * instead of being folded into `wcnt < 0`.
       *
       * ⚠ The body test used to be part of this `else if` condition. It moved
       * inside so a legend click reaches the arm at all; the TRAVEL test stays in
       * the condition, because it is what the double-click interlock rides on
       * (the -3 arm poisons graph_press_x/y with -1e30) and what separates a
       * click from the end of a strip drag-reorder. */
      int on_body = POINTINSIDE(xctx->mousex, xctx->mousey, gr->x1, gr->y1, gr->x2 , gr->y2);
      /* Ctrl+click ADDS to / REMOVES from the selection instead of replacing it
       * (issue 0175). Measured before choosing the modifier: Ctrl+B1 over a graph
       * does today exactly what a plain B1 does -- wviewer::strip_drag_press
       * declines a modified press and forwards it verbatim, and this arm never
       * looked at `state` -- so nothing is being taken away. The one other
       * meaning ControlMask carries over a graph is waves_selected's locked-rect
       * bypass (~line 116), which only concerns rects carrying `lock=true`; the
       * ASE viewer never writes that token. See 0175 D3. */
      int ctrl = (state & ControlMask) ? 1 : 0;
      /* Did the SELECTION change? Not "did hilight_wave change" -- since 0175
       * the selection is a SET, and collapsing {0,2} to {0} or adding node 5
       * behind node 2 both leave the scalar alone while changing every pixel.
       * The redraw has to key off the set. */
      int selchg = 0;
      /* WHICH trace, if any, the click is on -- a real point-to-segment distance
       * in SCREEN PIXELS through the engine's own transform, capped at
       * GRAPH_TRACE_PICK_TOL, answering the trace's NODE index or -1
       * (issue 0174). It replaces find_closest_wave(), which had no threshold at
       * all: it minimised |dy| at the nearest sample and returned the winner
       * however far away it was, so "click near a trace" was really "click
       * anywhere in the plot body" (measured: 714 of 776 body rows of a
       * three-trace strip are more than 10 px from every trace, and a click on
       * every one of them bolted something).
       *
       * This is the SAME query, at the SAME tolerance, that the RMB trace menu
       * and the LMB trace drag already gate on -- the asymmetry (precise menu,
       * imprecise select, same pixel, same strip) was the reported defect.
       *
       * It takes the EVENT's own pixels, not xctx->mousex/mousey: the C mouse
       * mirror is schematic-space and is stale for a press with no preceding
       * Motion (landmine 33), and graph_wave_at wants canvas pixels. It also
       * uses a LOCAL Graph_ctx and brackets the hcursor flag bits (landmines 11
       * and 37), so it cannot disturb `gr`, which an active draw may be using.
       *
       * Digital strips and bus traces answer -1 by construction (their rendering
       * is a band/ribbon, not a polyline). That loses nothing: find_closest_wave()
       * refused both too -- but it refused by returning BEFORE writing
       * *node_number, so `wcnt` was read uninitialised and the garbage was
       * persisted into the hilight_wave token (measured: -1859984240 on a digital
       * strip and with no raw loaded). The refusal now just reads as "no trace
       * here", which on such a strip means a click clears the selection. */
      if(on_body) {
        wcnt = graph_wave_at(i, (double)mx, (double)my, GRAPH_TRACE_PICK_TOL);
      } else {
        /* THE LEGEND (issue 0175). Clicking an entry's text selects its trace --
         * asked for directly, and on a DIGITAL or bus strip it is the only way
         * there is, because graph_wave_at answers -1 across their whole body.
         * The SAME query the Button3 legend arm below uses, so the two buttons
         * cannot disagree about where an entry is. Raw event pixels, like
         * graph_wave_at above and for the same reason. -1 for the axis margins
         * and the reorder grip, which own no trace and must change nothing. */
        wcnt = graph_legend_at(i, (double)mx, (double)my);
      }
      if(ctrl) {
        /* CTRL+CLICK: ADD an unselected trace, REMOVE a selected one, and touch
         * NOTHING else -- not the other strips (a window-wide selection is built
         * up across strips exactly this way) and not the selection at all when
         * the click missed. "Ctrl+click on empty space clears everything" would
         * make the modifier useless for its one job. */
        if(wcnt >= 0 && graph_sel_waves_toggle(i, wcnt)) selchg = 1;
      } else if(on_body || wcnt >= 0) {
        /* THE SELECTION BECOMES WHAT THE CLICK PICKED, AND ONLY THAT. One
         * assignment covers the whole rule (issue 0174 D2/D3, settled by the
         * user at review; issue 0175 adds the COLLAPSE half):
         *   - on another trace -> the selection MOVES there (0174's defect);
         *   - on empty BODY    -> the selection is CLEARED;
         *   - on the trace that is already selected -> it STAYS selected. A
         *     plain click never deselects what it lands on;
         *   - with several traces selected -> it collapses to the one clicked.
         * A plain click on a legend entry that is NOT a hit (wcnt < 0 and not on
         * the body: an axis margin, the grip) falls out of this branch entirely
         * and changes nothing -- only the plot body clears.
         *
         * ⚠ Clearing on a body miss and the strip drag-reorder do NOT collide:
         * they are separated by the travel test in the condition above, not by
         * this branch. A real reorder drag travels well past GRAPH_CLICK_TOL and
         * its release never reaches here.
         *
         * graph_sel_waves_set writes BOTH tokens and answers "did anything
         * change", so a click that re-picks what was already picked does not
         * churn the prop string. */
        if(graph_sel_waves_set(i, &wcnt, wcnt >= 0 ? 1 : 0)) selchg = 1;
        /* THE SELECTION IS ONE SET IN THE WHOLE WINDOW, NOT ONE PER STRIP.
         *
         * `hilight_wave`/`sel_waves` are PER-RECT prop tokens, so everything
         * above only ever touches the strip under the pointer. Without this
         * sweep, selecting a trace on strip A and then clicking one on strip B
         * leaves BOTH bold -- the same "the selection cannot move" defect one
         * level up. Reported at 0174's review: "clicking on another trace SHOULD
         * deselect all currently selected traces", and likewise for empty space.
         * Ctrl+click deliberately does NOT run it: that is how a selection
         * spanning two strips is built.
         *
         * An ABSENT token means nothing is bold there -- it must not be read as
         * index 0, which is what a bare atoi("") would give. `sel_waves` is only
         * ever present alongside a non-negative `hilight_wave` (graph_sel_waves_set
         * writes the pair), so testing the scalar covers both.
         *
         * The cleared strips are repainted by the all-graphs loop further down
         * (`need_all_redraw`), which does its own setup_graph_data(k, 0, gr) per
         * rect and so re-reads the tokens just rewritten. Doing it here instead
         * would mean calling setup_graph_data on a non-master rect with the
         * SHARED xctx->graph_struct this arm is still using (landmines 11/37). */
        {
          int k;
          for(k = 0; k < xctx->rects[GRIDLAYER]; ++k) {
            xRect *rk = &xctx->rect[GRIDLAYER][k];
            const char *hw;
            if(k == i) continue;
            if(!(rk->flags & 1)) continue;             /* 1: graph, 3: graph_unlocked */
            hw = get_tok_value(rk->prop_ptr, "hilight_wave", 0);
            if(!hw[0] || atoi(hw) < 0) continue;       /* absent or already clear */
            if(graph_sel_waves_set(k, NULL, 0)) need_all_redraw = 1;
          }
        }
      }
      /* Repaint through need_redraw_master rather than the inline draw_graph
       * this arm used to do: the per-graph loop at the tail re-runs
       * setup_graph_data(i, 0, gr) first, so the redraw reads back the tokens
       * just written instead of relying on this arm having patched every field
       * of the SHARED xctx->graph_struct by hand (it now writes two of them,
       * hilight_wave and sel_wave[], and forgetting one is a silent stale
       * render). need_all_redraw already covers the whole stack when the
       * cross-strip sweep fired. */
      if(selchg) need_redraw_master = 1;
    }
    /* Button3 press on a wave label (outside the plot body) -> TOGGLE that
     * trace's membership of the selection. NOT the wave-attributes dialog, which
     * this comment claimed for years: `what == 2` has been the toggle since the
     * selection became a set (issue 0175, draw.c edit_wave_attributes), and
     * before that it was a plain hilight_wave toggle. The dialog is `what == 1`,
     * on the double-click arm below.
     *
     * ⚠ THIS IS FOR GRAPHS EMBEDDED IN A SCHEMATIC (issue 0178). The ASE
     * waveform viewer no longer reaches it: an unmodified Button3 PRESS on a
     * legend entry is swallowed by wviewer::btn3_filter, which posts the TRACE
     * CONTEXT MENU on the release instead -- the legend was the one region of
     * that window where RMB was not a context menu, reported at the 0177
     * eyeball. An embedded graph has no context menus, so it keeps this. */
    else if(event == ButtonPress && button == Button3 &&
            !POINTINSIDE(xctx->mousex, xctx->mousey, gr->x1, gr->y1, gr->x2 , gr->y2)) {
      if( edit_wave_attributes(2, i, gr)) {
        draw_graph(i, 1 + 8 + 16 + (xctx->graph_flags & (2 | 4 | 128 | 256)), gr, NULL); /* draw data in graph box */
        return 0;
      }
    }

    /* destroy / show measurement widget */
    if(xctx->graph_flags & 64) {
      char sx[100], sy[100];
      double xval, yval;
      if(gr->digital) {
        double deltag = gr->gy2 - gr->gy1;
        double s1 = DIG_NWAVES; /* 1/DIG_NWAVES  waveforms fit in graph if unscaled vertically */
        double s2 = DIG_SPACE; /* (DIG_NWAVES - DIG_SPACE) spacing between traces */
        double c = s1 * deltag;
        deltag = deltag * s1 / s2;
        yval=(DG_Y(xctx->mousey) - c) / s2;
        yval=fmod(yval, deltag ) +  gr->gy1;
        if(yval > gr->gy2 + deltag * (s1 + s2) * 0.5) yval -= deltag;
      } else {
        yval = G_Y(xctx->mousey);
      }

      xval = G_X(xctx->mousex);
      if(gr->logx) xval = pow(10, xval);
      if(gr->logy) yval = pow(10, yval);
      if(gr->unitx != 1.0)
        sprintf(sx, "%.*g%c", xctx->ev_precision, gr->unitx * xval, gr->unitx_suffix);
      else
        my_strncpy(sx, dtoa_eng(xval, xctx->ev_precision), S(sx));

      if(gr->unitx != 1.0)
        sprintf(sy, "%.*g%c", xctx->ev_precision, gr->unity * yval, gr->unity_suffix);
      else
        my_strncpy(sy, dtoa_eng(yval, xctx->ev_precision), S(sy));

      tclvareval("set measure_text \"y=", sy, "\nx=", sx, "\"", NULL);
      tcleval("graph_show_measure");
    } /* if(xctx->graph_flags & 64) */

    gr->master_gx1 = gr->gx1;
    gr->master_gx2 = gr->gx2;
    gr->master_gw = gr->gw;
    gr->master_cx = gr->cx;
    /* A live marker drag pre-empts all four cursor-move arms. It must sit BEFORE
     * the `if(ui_state & GRAPHPAN) goto finish;` below, because during a drag
     * GRAPHPAN is set and that goto IS taken. It deliberately does not set
     * save_mouse_at_end and never touches mx/my_double_save (landmine 20). */
    if(event == MotionNotify && (state & Button1Mask) && xctx->graph_marker_drag) {
      if(graph_marker_drag_to(xctx->mousex, xctx->mousey)) need_redraw_master = 1;
    }
    /* move hcursor1 */
    else if(event == MotionNotify && (state & Button1Mask) && (xctx->graph_flags & 512 )) {
      double c;

      c = G_Y(xctx->mousey);
      if(gr->logy) c = pow(10, c);
      my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "hcursor1_y", dtoa(c)));
      need_redraw_master = 1;
    }

    /* move hcursor2 */
    else if(event == MotionNotify && (state & Button1Mask) && (xctx->graph_flags & 1024 )) {
      double c;

      c = G_Y(xctx->mousey);
      if(gr->logy) c = pow(10, c);
      my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "hcursor2_y", dtoa(c)));
      need_redraw_master = 1;
    }

    /* move cursor1 */
    /* set cursor position from master graph x-axis */
    else if(event == MotionNotify && (state & Button1Mask) && (xctx->graph_flags & 16 )) {
      double c;

      c = G_X(xctx->mousex);
      if(gr->logx) c = pow(10, c);
      if(r->flags & 4) { /* private_cursor */
        my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "cursor1_x", dtoa(c)));
      } else {
        xctx->graph_cursor1_x = c;
      }
      need_all_redraw = 1;
    }
    /* move cursor2 */
    /* set cursor position from master graph x-axis */
    else if(event == MotionNotify && (state & Button1Mask) && (xctx->graph_flags & 32 )) {
      double c;
      int floaters = there_are_floaters();

      c = G_X(xctx->mousex);
      if(gr->logx) c = pow(10, c);
      if(r->flags & 4) { /* private_cursor */
        my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "cursor2_x", dtoa(c)));
      } else {
        xctx->graph_cursor2_x = c;
      }
      if(tclgetboolvar("live_cursor2_backannotate")) {
        backannotate_at_cursor_b_pos(r, gr);
        if(floaters) set_modify(-2); /* update floater caches to reflect actual backannotation */
        need_fullredraw = 1;
      } else {
        need_all_redraw = 1;
      }
    }

    if(xctx->ui_state & GRAPHPAN) goto finish; /* After GRAPHPAN only need to check Motion events for cursors */
    if(xctx->mousey_snap < W_Y(gr->gy2)) {
      xctx->graph_top = 1;
    } else {
      xctx->graph_top = 0;
    }
    if(xctx->mousex_snap < W_X(gr->gx1)) {
      xctx->graph_left = 1;
    } else {
      xctx->graph_left = 0;
    }
    if(xctx->mousey_snap > W_Y(gr->gy1)) {
      xctx->graph_bottom = 1;
    } else {
      xctx->graph_bottom = 0;
    }
    zoom_m = (xctx->mousex  - gr->x1) / gr->w;
    /* A press ON A MARKER pre-empts the cursor grab and the a/b/s/m/d/t key arms
     * for this event, and nukes the wave-bold click anchor (the belt to edit
     * 12's braces -- the `-3` double-click arm uses the same idiom).
     * It deliberately does NOT do the `event = 0; button = 0;` trick used by the
     * numeric cursor set: that would also suppress the GRAPHPAN latch below,
     * which is the ROUTING latch every drag needs (landmine 36). */
    mkpress = (event == ButtonPress && button == Button1) ? graph_marker_press(i, gr, r) : 0;
    /* a press that only DESELECTED is not our gesture -- it falls through to the
     * cursor grab -- but the ring still has to be erased, and possibly on a
     * different strip than the one under the pointer */
    if(mkpress < 0) need_all_redraw = 1;
    if(mkpress > 0) {
      xctx->graph_press_x = xctx->graph_press_y = -1e30;
    }
    else if(event == ButtonPress && button == Button1) {
      /* dragging cursors when mouse is very close */
      if(xctx->graph_flags & 128) { /* hcursor1 */
        double cursor;
        cursor = gr->hcursor1_y;
        if(gr->logy ) {
          cursor = mylog10(cursor);
        }
        if(fabs(xctx->mousey - W_Y(cursor)) < 10) {
          xctx->graph_flags |= 512; /* Start move hcursor1 */
        }
      }
      if(xctx->graph_flags & 256) { /* hcursor2 */
        double cursor;
        cursor = gr->hcursor2_y;
        if(gr->logy ) {
          cursor = mylog10(cursor);
        }
        if(fabs(xctx->mousey - W_Y(cursor)) < 10) {
          xctx->graph_flags |= 1024; /* Start move hcursor2 */
        }
      }
      if(xctx->graph_flags & 2) { /* cursor1 */
        double cursor1;
        if(r->flags & 4) { /* private_cursor */
          const char *s = get_tok_value(r->prop_ptr, "cursor1_x", 0);
          if(s[0]) {
            cursor1 = atof_eng(s);
          } else {
            cursor1 = xctx->graph_cursor1_x;
          }
        } else {
          cursor1 = xctx->graph_cursor1_x;
        }
        if(gr->logx ) {
          cursor1 = mylog10(cursor1);
        }
        if(fabs(xctx->mousex - W_X(cursor1)) < 10) {
          xctx->graph_flags |= 16; /* Start move cursor1 */
        }
      }
      if(xctx->graph_flags & 4) { /* cursor2 */
        double cursor2;
        if(r->flags & 4) { /* private_cursor */
          const char *s = get_tok_value(r->prop_ptr, "cursor2_x", 0);
          if(s[0]) {
            cursor2 = atof_eng(s);
          } else {
            cursor2 = xctx->graph_cursor2_x;
          }
        } else {
          cursor2 = xctx->graph_cursor2_x;
        }
        if(gr->logx) {
          cursor2 = mylog10(cursor2);
        }
        if(fabs(xctx->mousex - W_X(cursor2)) < 10) {
          xctx->graph_flags |= 32; /* Start move cursor2 */
        }
      }
      /* The axis-region drag zoom (issue 0190) arms LAST, and only when this
       * same press grabbed no cursor. A cursor's LINE crosses the margin and its
       * numeric READOUT is DRAWN there -- draw_cursor (draw.c) spans
       * gr->ry1..gr->ry2 and labels at gr->ry2-1, draw_hcursor spans
       * rx1+10..rx2-10 and labels at gr->rx1+5 -- so a press there really can be
       * aimed at the cursor, and "a press that grabbed a cursor keeps the whole
       * drag" is the shipped rule (waveform_viewer_modes.md §12.1/§13.1). The
       * four grab tests above have NO plot-box confinement, which is exactly why
       * this has to be a test and not an assumption.
       * A press on a MARKER pre-empts this whole block already (mkpress above),
       * and the reorder grip / the legend are declined inside graph_axis_at(). */
      if(!(xctx->graph_flags & (16 | 32 | 512 | 1024))) graph_axis_press_arm(i, mx, my);
    }
    else if(event == ButtonPress && button == Button3) {
      /* Numerically set cursor position */
      if(xctx->graph_flags & 2) {
        double logcursor, cursor;
        if(r->flags & 4) { /* private_cursor */
          const char *s = get_tok_value(r->prop_ptr, "cursor1_x", 0);
          if(s[0]) {
            cursor = atof_spice(s);
          } else {
            cursor = xctx->graph_cursor1_x;
          }
        } else {
          cursor = xctx->graph_cursor1_x;
        }
        logcursor = cursor;
        if(gr->logx ) {
          logcursor = mylog10(cursor);
        }
        if(fabs(xctx->mousex - W_X(logcursor)) < 10) {
          tclvareval("input_line {Pos:} {} ", dtoa_eng(cursor, xctx->ev_precision), NULL);
          cursor = atof_eng(tclresult());
          if(r->flags & 4) {
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "cursor1_x", dtoa(cursor)));
          } else {
            xctx->graph_cursor1_x = cursor;
          }
          event = 0; button = 0; /* avoid further processing ButtonPress that might set GRAPHPAN */
        }
        need_all_redraw = 1;
      }
      /* Numerically set cursor position  *** DO NOT PUT AN `else if` BELOW *** */
      if(xctx->graph_flags & 4) {
        double logcursor, cursor;
        int floaters = there_are_floaters();
        if(r->flags & 4) { /* private_cursor */
          const char *s = get_tok_value(r->prop_ptr, "cursor2_x", 0);
          if(s[0]) {
            cursor = atof_spice(s);
          } else {
            cursor = xctx->graph_cursor2_x;
          }
        } else {
          cursor = xctx->graph_cursor2_x;
        }
        logcursor = cursor;
        if(gr->logx) {
          logcursor = mylog10(cursor);
        }
        if(fabs(xctx->mousex - W_X(logcursor)) < 10) {
          tclvareval("input_line {Pos:} {} ", dtoa_eng(cursor, xctx->ev_precision), NULL);
          cursor = atof_eng(tclresult());
          if(r->flags & 4) {
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "cursor2_x", dtoa(cursor)));
          } else {
            xctx->graph_cursor2_x = cursor;
          }
          event = 0; button = 0; /* avoid further processing ButtonPress that might set GRAPHPAN */
        }
        if(tclgetboolvar("live_cursor2_backannotate")) {
          backannotate_at_cursor_b_pos(r, gr);
          if(floaters) set_modify(-2); /* update floater caches to reflect actual backannotation */
          need_fullredraw = 1;
        } else {
          need_all_redraw = 1;
        }
      }
      /* Numerically set hcursor position  *** DO NOT PUT AN `else if` BELOW *** */
      if(xctx->graph_flags & 128) {
        double logcursor, cursor;
        logcursor = cursor = gr->hcursor1_y;
        if(gr->logy ) {
          logcursor = mylog10(cursor);
        }
        if(fabs(xctx->mousey - W_Y(logcursor)) < 10) {
          tclvareval("input_line {Pos:} {} ", dtoa_eng(cursor, xctx->ev_precision), NULL);
          cursor = atof_eng(tclresult());
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "hcursor1_y", dtoa(cursor)));
          event = 0; button = 0; /* avoid further processing ButtonPress that might set GRAPHPAN */
        }
        need_redraw_master = 1;
      }
      /* Numerically set hcursor position *** DO NOT PUT AN `else if` BELOW *** */
      if(xctx->graph_flags & 256) {
        double logcursor, cursor;
        logcursor = cursor = gr->hcursor2_y;
        if(gr->logy ) {
          logcursor = mylog10(cursor);
        }
        if(fabs(xctx->mousey - W_Y(logcursor)) < 10) {
          tclvareval("input_line {Pos:} {} ", dtoa_eng(cursor, xctx->ev_precision), NULL);
          cursor = atof_eng(tclresult());
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "hcursor2_y", dtoa(cursor)));
          event = 0; button = 0; /* avoid further processing ButtonPress that might set GRAPHPAN */
        }
        need_redraw_master = 1;
      }
    }
    /* CTRL+WHEEL IN AN AXIS-NUMBER MARGIN = a zoom of THAT AXIS ONLY, anchored
     * at the pointer (issue 0191, doc/claude/specs/waveform_viewer_modes.md
     * §18). The wheel twin of the LMB drag armed ~100 lines above, sharing its
     * region oracle (graph_axis_at) and its apply (graph_axis_zoom).
     *
     * ⚠ WHY IT IS HERE AND NOT A BINDING ROW (landmine 48). A wheel press whose
     * pointer is over a graph NEVER reaches handle_mouse_wheel(): the inline
     * `if(waves_selected(...)) { waves_callback(...); return; }` at the head of
     * handle_button_press pre-empts it fourteen branches earlier, so the four
     * ACTX_OVER_GRAPH wheel rows in init_input_bindings are unreachable dead
     * code and a modifier's over-graph wheel behaviour can only be decided in
     * here.
     *
     * !(state & ShiftMask): Ctrl+Shift+wheel keeps the shipped Shift zoom arms
     *   below, which are already pointer-anchored (a different, non-reversible
     *   0.2-of-the-range step -- see GRAPH_AXIS_WHEEL_FACTOR).
     * !graph_use_ctrl_key: in that mode Ctrl IS the graph ACCESS modifier
     *   (waves_selected, access_cond above, and handle_mouse_wheel's own
     *   reservation), so every graph gesture holds it and taking Ctrl+wheel
     *   would leave the mode with no graph wheel pan at all (D-32).
     * No GRAPHPAN term is owed (landmine 36): that latch admits Button1/2/3
     *   only, so a Button4/5 press never enters it, and a wheel is one event
     *   with no release to lose. An in-flight drag is already short-circuited by
     *   the `goto finish` above.
     * graph_axis_at() is the region oracle and a NONE answer means "fall through
     *   to the pan below", which is the whole body-unchanged contract: only a
     *   real margin hit sets wheel_axis_done.
     * need_all_redraw, not need_fullredraw: X propagates so every rect must
     *   repaint, the per-graph loop's draw_graph(i, 1+8+16+...) repaints the
     *   background, grid and axis NUMBERS under bit 8, and there is no rubber
     *   band to erase. */
    else if(event == ButtonPress && (button == Button4 || button == Button5) &&
            (state & ControlMask) && !(state & ShiftMask) && !graph_use_ctrl_key) {
      int ax = graph_axis_at(i, (double)mx, (double)my);
      if(ax != GRAPH_AXIS_NONE) {
        double p = (ax == GRAPH_AXIS_X) ? (double)mx : (double)my;
        double lo = 0.0, hi = 0.0;
        if(graph_axis_wheel_map(i, ax, p, button == Button4 ? 1 : -1, &lo, &hi)) {
          graph_axis_zoom(i, ax, lo, hi);
          wheel_axis_done = 1;
          need_all_redraw = 1;
        }
      }
    }
    else if(event == -3 && button == Button1) {
      int mnum, mpart = 0;
      /* issue 0152: a double-click is press,release,`-3`,release -- invalidate the click
       * anchor so the trailing release does not also toggle the wave bold on top of the
       * attributes/properties dialog this opens. */
      xctx->graph_press_x = xctx->graph_press_y = -1e30;
      /* A DOUBLE-CLICK ON A MARKER selects it and, when it carries a delta
       * block, the marker its deltas are derived from (issue 0189). It must be
       * tested BEFORE the wave dialog: a marker ANCHOR sits on a trace by
       * construction and a callout is clamped inside the plot box, so this
       * double-click otherwise reaches graph_edit_properties. need_all_redraw
       * because the partner may live on a different strip -- the selection is by
       * NUMBER and is deliberately not scoped to one rect. */
      mnum = graph_marker_at(i, (double)mx, (double)my, GRAPH_MARKER_TOL, &mpart);
      if(mnum > 0 && mpart) {
        graph_marker_select_pair(mnum, i);
        need_all_redraw = 1;
      }
      else if(!edit_wave_attributes(1, i, gr)) {
        tclvareval("graph_edit_properties ", my_itoa(i), NULL);
      }
    }
    /* x cursor1 toggle */
    else if(key == 'a' && access_cond) {
      xctx->graph_flags ^= 2;
      need_all_redraw = 1;
      if(xctx->graph_flags & 2) {
        double c = G_X(xctx->mousex);

        if(gr->logx) c = pow(10, c);
        if(r->flags & 4) {
          if(!get_tok_value(r->prop_ptr, "cursor1_x", 0)[0]) {
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "cursor1_x", dtoa(c)));
          }
        } else {
          xctx->graph_cursor1_x = c;
        }
      }
    }
    /* x cursor2 toggle */
    else if(key == 'b'  && access_cond) {
      int floaters = there_are_floaters();

      xctx->graph_flags ^= 4;
      if(xctx->graph_flags & 4) {
        double c = G_X(xctx->mousex);

        if(gr->logx) c = pow(10, c);
        if(r->flags & 4) {
          if(!get_tok_value(r->prop_ptr, "cursor2_x", 0)[0]) {
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "cursor2_x", dtoa(c)));
          }
        } else {
          xctx->graph_cursor2_x = c;
        }
        if(tclgetboolvar("live_cursor2_backannotate")) {
          backannotate_at_cursor_b_pos(r, gr);
          if(floaters) set_modify(-2); /* update floater caches to reflect actual backannotation */
          need_fullredraw = 1;
        } else {
          need_all_redraw = 1;
        }
      } else if(xctx->raw) {
        xctx->raw->annot_p = -1;
        xctx->raw->annot_sweep_idx = -1;
        /* need_all_redraw = 1; */
        need_fullredraw = 1;
      }
    }
    /* swap cursors */
    else if((key == 's' && access_cond) ) {
      if( (xctx->graph_flags & 2) && (xctx->graph_flags & 4)) {
        double tmp, cursor1, cursor2;
        int floaters = there_are_floaters();

        if(r->flags & 4) { /* private_cursor */
          const char *s = get_tok_value(r->prop_ptr, "cursor1_x", 0);
          if(s[0]) {
            cursor1 = atof_spice(s);
          } else {
            cursor1 = xctx->graph_cursor1_x;
          }
        } else {
          cursor1 = xctx->graph_cursor1_x;
        }

        if(r->flags & 4) { /* private_cursor */
          const char *s = get_tok_value(r->prop_ptr, "cursor2_x", 0);
          if(s[0]) {
            cursor2 = atof_spice(s);
          } else {
            cursor2 = xctx->graph_cursor2_x;
          }
        } else {
          cursor2 = xctx->graph_cursor2_x;
        }

        tmp = cursor2;
        cursor2 = cursor1;
        cursor1 = tmp;

        if(r->flags & 4) {
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "cursor1_x", dtoa(cursor1)));
        } else {
          xctx->graph_cursor1_x = cursor1;
        }
        if(r->flags & 4) {
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "cursor2_x", dtoa(cursor2)));
        } else {
          xctx->graph_cursor2_x = cursor2;
        }
        if(tclgetboolvar("live_cursor2_backannotate")) {
          backannotate_at_cursor_b_pos(r, gr);
          if(floaters) set_modify(-2); /* update floater caches to reflect actual backannotation */
          need_fullredraw = 1;
        }
        else need_all_redraw = 1;
      }
    }
    /* measurement tooltip -- RELOCATED from `m` to `M` (Shift+m) when `m` became
     * marker creation (doc/claude/specs/graph_markers.md). Bit 64 and both of its
     * teardown paths (waves_selected's leave-the-graph stop, the <Leave> bind)
     * stay wired; losing the only key that can SET it would make the whole
     * tooltip render block dead code. Not Ctrl+m: with graph_use_ctrl_key set,
     * access_cond REQUIRES Ctrl, so Ctrl+m would have to be both. */
    else if((key == 'M') && access_cond) {
      xctx->graph_flags ^= 64;
      if(!(xctx->graph_flags & 64)) {
        tcleval("graph_show_measure stop");
      }
    }
    /* create a marker at the sample nearest the pointer; `d` also attaches a
     * delta measurement against the most recently created marker */
    /* Read-only is enforced INSIDE the marker ops (draw.c), not here. Two
     * reasons, both learned the hard way: the gate must also cover the
     * DRAG-COMMIT path, which does not come through a key arm at all; and the
     * refusal must use the feature's own non-blocking channel
     * (graph_marker_refuse -> ciw_echo, like "no trace near the pointer"),
     * because readonly_block() pops a MODAL and a modal on a keystroke deadlocks
     * every headless test that exercises the refusal. The ASE viewer, readonly
     * for its whole life by construction, gets through because
     * wviewer::key_filter forwards m/d/Delete inside wviewer::with_edit. */
    else if((key == 'm') && access_cond) {
      if(graph_marker_create(i, X_TO_SCREEN(xctx->mousex), Y_TO_SCREEN(xctx->mousey), 0) > 0)
        need_redraw_master = 1;
    }
    else if((key == 'd') && access_cond) {
      if(graph_marker_create(i, X_TO_SCREEN(xctx->mousex), Y_TO_SCREEN(xctx->mousey), 1) > 0)
        need_redraw_master = 1;
    }
    else if(key == 't' && access_cond) {
      if(!gr->digital) {
          const char *d = get_tok_value(r->prop_ptr, "dataset", 0);
        if(d[0]) {
          track_dset = atoi(d);
        } else {
          track_dset = -1; /* all datasets */
        }
        if(track_dset < 0) {
          int tmp;
          track_dset = find_closest_wave(i, gr, &tmp);
        } else {
          track_dset = -1; /* all datasets */
        }
      }
    } /* key == 't' */
  } /* if((i = xctx->graph_master) >= 0 && ((r = &xctx->rect[GRIDLAYER][i])->flags & 1)) */

  /* save mouse position when doing pan operations.
   * Button2 joined the set when the graph pan moved off LMB: GRAPHPAN is what
   * keeps waves_selected routing the whole drag to the graph and what latches
   * graph_left/graph_top/graph_bottom at press time (the `goto finish` above).
   * Button1 stays in the set: it still owns cursor drags and the wave-bold
   * click, both of which need that same routing latch. */
  if(
      ( event == ButtonPress &&
        (button == Button1 || button == Button2 || button == Button3)) &&
      !(xctx->ui_state & GRAPHPAN) &&
      /* ⚠ THE STATED REASON WAS WRONG AND IS CORRECTED HERE (issue 0177). This
       * used to say graph_top is computed from the SNAPPED pointer while the
       * marker hit test uses the raw one. It is not: the 0143 override at the
       * head of this function un-snaps both fields before any branch, and
       * nothing rewrites them before the margin computation, so the two read the
       * SAME coordinate and no grid setting can separate them. The real gap is a
       * TOLERANCE one -- graph_marker_press hit-tests within GRAPH_MARKER_TOL
       * (8 screen px) of the anchor, so a press up to 8 px ABOVE the plot box
       * still grabs a marker anchored just inside it while graph_top is already
       * 1. The extra term is therefore still required; only its justification
       * changes. GRAPHPAN is not a pan here -- it is the
       * ROUTING latch (waves_selected keeps an in-flight drag routed and freezes
       * graph_master with it), so an armed marker drag must always get it or the
       * release is silently dropped. Provably a no-op when nothing is armed. */
      /* ⚠ AND an armed AXIS-REGION drag zoom (issue 0190), for the SAME reason,
       * MEASURED rather than assumed. The two axis regions are mostly
       * graph_top == 0 -- the bottom margin always is, and so is the left margin
       * at plot-box heights -- but the region graph_axis_at() calls Y is "left of
       * the plot box, anywhere in the container", so a press in the TOP-LEFT
       * corner of a strip that owns no legend entry there (legend=0, or no `node`
       * token yet) arms a Y drag with graph_top already 1. Without this term that
       * drag's release is silently dropped: GRAPHPAN is the ROUTING latch
       * (landmine 36), not a pan. */
      (!xctx->graph_top || xctx->graph_marker_drag || xctx->graph_axis_drag)
      /* && !xctx->graph_bottom */
    ) {
    xctx->ui_state |= GRAPHPAN;
    /* box-zoom needs BOTH press coords: an interior RMB drag zooms X and Y */
    xctx->mx_double_save = xctx->mousex_snap;
    xctx->my_double_save = xctx->mousey_snap;
    xctx->graph_rubber_active = 0; /* fresh gesture: no rubber rect drawn yet */
  }
  dbg(1, "graph_master=%d\n", xctx->graph_master);

  finish:

  /* parameters for absolute positioning by mouse drag in bottom graph area
   * (Button2 since the pan moved off LMB — this IS a graph-range move) */
  if( xctx->raw && event == MotionNotify && (state & Button2Mask) && xctx->graph_bottom ) {
    int idx;
    int dset;
    double wwx1, wwx2, pp, delta, ccx, ddx;

    char *rawfile = NULL;
    char *sim_type = NULL;
    int switched = 0;

    my_strdup2(_ALLOC_ID_, &rawfile, get_tok_value(r->prop_ptr, "rawfile", 0));
    my_strdup2(_ALLOC_ID_, &sim_type, get_tok_value(r->prop_ptr, "sim_type", 0));
    if(rawfile[0] && sim_type[0]) switched = extra_rawfile(2, rawfile, sim_type, -1.0, -1.0);
    my_free(_ALLOC_ID_, &rawfile);
    my_free(_ALLOC_ID_, &sim_type);

    idx = get_raw_index(find_nth(get_tok_value(r->prop_ptr, "sweep", 0), ", ", "\"", 0, 1), NULL);
    dset = dataset == -1 ? 0 : dataset;

    if(idx < 0 ) idx = 0;
    delta = gr->gw;
    wwx1 =  get_raw_value(dset, idx, 0);
    wwx2 = get_raw_value(dset, idx, xctx->raw->npoints[dset] - 1);
    if(wwx1 == wwx2) wwx2 += 1e-6;
    if(gr->logx) {
      wwx1 = mylog10(wwx1);
      wwx2 = mylog10(wwx2);
    }
    ccx = (gr->x2 - gr->x1) / (wwx2 - wwx1);
    ddx = gr->x1 - wwx1 * ccx;
    pp = (xctx->mousex_snap - ddx) / ccx;
    xx1 = pp - delta / 2.0;
    xx2 = pp + delta / 2.0;
    if(switched) extra_rawfile(5, NULL, NULL, -1.0, -1.0); /* switch back to previous raw file */
  }
  else if(button == Button3 && (xctx->ui_state & GRAPHPAN) && !xctx->graph_left && !xctx->graph_top) {
    /* parameters for zoom area by mouse drag */
    xx1 = G_X(xctx->mx_double_save);
    xx2 = G_X(xctx->mousex_snap);
    if(state & ShiftMask) {
      if(xx1 < xx2) { double tmp; tmp = xx1; xx1 = xx2; xx2 = tmp; }
    } else {
      if(xx2 < xx1) { double tmp; tmp = xx1; xx1 = xx2; xx2 = tmp; }
    }

    if(xx1 == xx2) xx2 += 1e-6;
  }
  /* RMB interior drag: draw the live box-zoom rubber rectangle (both axes). gr
   * is set up for the master graph (above). Each motion erases the previous
   * outline via the tiled GC (restores the graph pixmap under it) then draws the
   * new one in the selection color, exactly like the schematic zoom_rectangle.
   * Display-only: drawtemprect no-ops when !has_x, so the headless box-zoom math
   * below is unaffected. */
  if(event == MotionNotify && (state & Button3Mask) && (xctx->ui_state & GRAPHPAN) &&
     !xctx->graph_marker_drag && /* a B1+B3 chord must not move a marker AND
     paint the box-zoom rubber (same class as the MMB pan guard above) */
     !xctx->graph_axis_drag &&   /* ...nor an axis-region drag zoom (issue 0190):
     the reciprocal of the term in that arm's own guard just below */
     xctx->graph_master >= 0 && !xctx->graph_left && !xctx->graph_top && !xctx->graph_bottom) {
    double xlo = gr->x1 < gr->x2 ? gr->x1 : gr->x2;
    double xhi = gr->x1 < gr->x2 ? gr->x2 : gr->x1;
    double ylo = gr->y1 < gr->y2 ? gr->y1 : gr->y2;
    double yhi = gr->y1 < gr->y2 ? gr->y2 : gr->y1;
    double cx2 = xctx->mousex_snap, cy2 = xctx->mousey_snap;
    if(cx2 < xlo) cx2 = xlo; if(cx2 > xhi) cx2 = xhi;   /* clamp to the plot box */
    if(cy2 < ylo) cy2 = ylo; if(cy2 > yhi) cy2 = yhi;
    if(xctx->graph_rubber_active) { /* erase the previous outline */
      double ex1 = xctx->mx_double_save, ey1 = xctx->my_double_save;
      double ex2 = xctx->graph_rubber_x, ey2 = xctx->graph_rubber_y;
      RECTORDER(ex1, ey1, ex2, ey2);
      drawtemprect(xctx->gctiled, NOW, ex1, ey1, ex2, ey2);
    }
    { /* draw the new outline */
      double dx1 = xctx->mx_double_save, dy1 = xctx->my_double_save, dx2 = cx2, dy2 = cy2;
      RECTORDER(dx1, dy1, dx2, dy2);
      drawtemprect(xctx->gc[SELLAYER], NOW, dx1, dy1, dx2, dy2);
    }
    xctx->graph_rubber_x = cx2;
    xctx->graph_rubber_y = cy2;
    xctx->graph_rubber_active = 1;
  }
  /* Button3 release: erase the last rubber outline before the zoom redraw */
  if(event == ButtonRelease && button == Button3 && xctx->graph_rubber_active) {
    double ex1 = xctx->mx_double_save, ey1 = xctx->my_double_save;
    double ex2 = xctx->graph_rubber_x, ey2 = xctx->graph_rubber_y;
    RECTORDER(ex1, ey1, ex2, ey2);
    drawtemprect(xctx->gctiled, NOW, ex1, ey1, ex2, ey2);
    xctx->graph_rubber_active = 0;
  }
  /* AXIS-REGION DRAG ZOOM (issue 0190): the live band, the twin of the Button3
   * rubber above and using the same gctiled-erase / gc[SELLAYER]-draw /
   * graph_rubber_* bookkeeping. It spans the whole plot box across the axis NOT
   * being dragged, so it reads as "this slice of the x axis" rather than a box.
   * Display-only: drawtemprect no-ops when !has_x, so the headless map/apply
   * below is unaffected. graph_master is frozen for the whole drag by GRAPHPAN,
   * so it is also the guard that keeps `gr` pointing at the dragged strip. */
  if(event == MotionNotify && (state & Button1Mask) && !(state & Button3Mask) &&
     xctx->graph_axis_drag && !xctx->graph_marker_drag &&
     xctx->graph_master >= 0 && xctx->graph_master == xctx->graph_axis_draggraph) {
    double nb1, nb2, nb3, nb4;
    double moving = (xctx->graph_axis_drag == GRAPH_AXIS_X) ?
                    xctx->mousex_snap : xctx->mousey_snap;
    if(xctx->graph_rubber_active) { /* erase the previous outline */
      double eb1, eb2, eb3, eb4;
      graph_axis_band(gr, xctx->graph_axis_drag,
                      xctx->graph_axis_drag == GRAPH_AXIS_X ?
                        xctx->graph_rubber_x : xctx->graph_rubber_y,
                      &eb1, &eb2, &eb3, &eb4);
      drawtemprect(xctx->gctiled, NOW, eb1, eb2, eb3, eb4);
    }
    graph_axis_band(gr, xctx->graph_axis_drag, moving, &nb1, &nb2, &nb3, &nb4);
    drawtemprect(xctx->gc[SELLAYER], NOW, nb1, nb2, nb3, nb4);
    xctx->graph_rubber_x = moving;
    xctx->graph_rubber_y = moving;
    xctx->graph_rubber_active = 1;
  }
  /* Button1 release with an axis drag armed: erase the band, disarm, and commit
   * whatever graph_axis_map() makes of the press/release pair. The map owns the
   * click-vs-drag threshold, the clamp and the direction test -- this arm must
   * not second-guess any of them, and must NOT carry its own copy of the formula
   * (landmine 45(a); the `xschem graph_axis_zoom` verb replays through the same
   * graph_axis_zoom() this calls). No set_modify, no push_undo: landmine 19.
   *
   * ⚠ GRAPH_CLICK_TOL goes in BARE here, not `* xctx->zoom` as at :710/:711 and
   * :1047/:1048. p0/p1 are canvas PIXELS (mx/my), not world coordinates, so the
   * threshold is compared in pixel space -- see the note on the #define. */
  if(event == ButtonRelease && button == Button1 && xctx->graph_axis_drag) {
    int ax = xctx->graph_axis_drag;
    int gi = xctx->graph_axis_draggraph;
    double p0 = xctx->graph_axis_press;
    double p1 = (ax == GRAPH_AXIS_X) ? (double)mx : (double)my;
    double lo = 0.0, hi = 0.0;
    if(xctx->graph_rubber_active && xctx->graph_master >= 0 &&
       xctx->graph_master == gi) {
      double eb1, eb2, eb3, eb4;
      graph_axis_band(gr, ax, ax == GRAPH_AXIS_X ?
                      xctx->graph_rubber_x : xctx->graph_rubber_y,
                      &eb1, &eb2, &eb3, &eb4);
      drawtemprect(xctx->gctiled, NOW, eb1, eb2, eb3, eb4);
    }
    xctx->graph_rubber_active = 0;
    graph_axis_drag_clear();
    if(graph_axis_map(gi, ax, p0, p1, &lo, &hi, GRAPH_CLICK_TOL)) {
      graph_axis_zoom(gi, ax, lo, hi);
      need_fullredraw = 1;
    }
  }
  /* loop: after having operated on the master graph do the others */
  for(i=0; i< xctx->rects[GRIDLAYER]; ++i) {
    int same_sim_type = 0;
    char *curr_sim_type = NULL;
    r = &xctx->rect[GRIDLAYER][i];
    need_redraw = 0;
    if( !(r->flags & 1) ) continue; /* 1: graph; 3: graph_unlocked */
    my_strdup2(_ALLOC_ID_, &curr_sim_type, get_tok_value(r->prop_ptr, "sim_type", 0));
    gr->gx1 = gr->master_gx1;
    gr->gx2 = gr->master_gx2;
    gr->gw = gr->master_gw;
    setup_graph_data(i, 1, gr); /* skip flag set, no reload x1 and x2 fields */
    if(gr->dataset >= 0 /* && gr->dataset < xctx->raw->datasets */) dataset =gr->dataset;
    else dataset = -1;

    /* if master graph has unlocked X axis do not zoom/pan any other graphs: same_sim_type = 0 */
    if(!(xctx->rect[GRIDLAYER][xctx->graph_master].flags & 2) &&
       !strcmp(curr_sim_type,
          get_tok_value(xctx->rect[GRIDLAYER][xctx->graph_master].prop_ptr, "sim_type", 0))) {
      same_sim_type = 1;
    }
    my_free(_ALLOC_ID_, &curr_sim_type);

    /* THE graph pan: drag the data window. Button2 (MMB), not Button1 — LMB over
     * a strip is reserved for precise interaction and, in the ASE viewer, for
     * drag-to-reorder. The cursor-move flags stay in the guard: a MMB drag while
     * a cursor is grabbed must not also pan. */
    if(event == MotionNotify && (state & Button2Mask) && !xctx->graph_bottom &&
      !xctx->graph_marker_drag && /* same reason as the cursor flags: a B1+B2
      chord must not move a marker AND pan in the same event. The marker drag
      deliberately sets no graph_flags bit (landmine 6), so it needs its own term. */
      !(xctx->graph_flags & (16 | 32 | 512 | 1024))) {
      double delta;
      /* vertical move of waveforms */
      if(xctx->graph_left) {
        if(i == xctx->graph_master) {
          if(gr->digital) {
            delta = gr->posh;
            delta_threshold = 0.01;
            if(fabs(xctx->my_double_save - xctx->mousey_snap) > fabs(gr->dcy * delta) * delta_threshold) {
              yy1 = gr->ypos1 + (xctx->my_double_save - xctx->mousey_snap) / gr->dcy;
              yy2 = gr->ypos2 + (xctx->my_double_save - xctx->mousey_snap) / gr->dcy;
              my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos1", dtoa(yy1)));
              my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos2", dtoa(yy2)));
              xctx->my_double_save = xctx->mousey_snap;
              need_redraw = 1;
            }
          } else {
            delta = gr->gh / gr->divy;
            delta_threshold = 0.01;
            if(fabs(xctx->my_double_save - xctx->mousey_snap) > fabs(gr->cy * delta) * delta_threshold) {
              yy1 = gr->gy1 + (xctx->my_double_save - xctx->mousey_snap) / gr->cy;
              yy2 = gr->gy2 + (xctx->my_double_save - xctx->mousey_snap) / gr->cy;
              my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y1", dtoa(yy1)));
              my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y2", dtoa(yy2)));
              xctx->my_double_save = xctx->mousey_snap;
              need_redraw = 1;
            }
          }
        }
      }
      /* horizontal move of waveforms */
      else {
        save_mouse_at_end = 1;
        delta = gr->gw;
        delta_threshold = 0.01;
        /* selected or locked or master */
        if( r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master) {
          dbg(1, "moving waves: %d\n", i);
          if(fabs(xctx->mx_double_save - xctx->mousex_snap) > fabs(gr->cx * delta) * delta_threshold) {
            xx1 = gr->gx1 + (xctx->mx_double_save - xctx->mousex_snap) / gr->cx;
            xx2 = gr->gx2 + (xctx->mx_double_save - xctx->mousex_snap) / gr->cx;
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
            need_redraw = 1;
          }
        }
      }
    }

    /* `!wheel_axis_done`: the CTRL+wheel axis zoom in the master block above
     * already consumed this event (issue 0191). It is a DIFFERENT if/else chain
     * and a different loop, so without this term the margin zoom would also pan.
     * The flag is set ONLY when graph_axis_at() found a margin AND the map
     * answered, so CTRL+wheel over the plot body still pans exactly as it does
     * today -- that is the whole body-unchanged contract. */
    else if(event == ButtonPress && button == Button5 && !(state & ShiftMask) &&
            !wheel_axis_done) {
      double delta;
      /* vertical move of waveforms with mouse wheel */
      if(xctx->graph_left) {
        if(i == xctx->graph_master) {
          if(gr->digital) {
            delta = gr->posh * 0.05;
            yy1 = gr->ypos1 + delta;
            yy2 = gr->ypos2 + delta;
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos1", dtoa(yy1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos2", dtoa(yy2)));
            need_redraw = 1;
          } else {
            delta = gr->gh/ gr->divy;
            delta_threshold = 1.0;
            yy1 = gr->gy1 + delta * delta_threshold;
            yy2 = gr->gy2 + delta * delta_threshold;
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y1", dtoa(yy1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y2", dtoa(yy2)));
            need_redraw = 1;
          }
        }
      }
      /* horizontal move of waveforms with mouse wheel */
      else {
        /* selected or locked or master */
        if( r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master) {
          delta = gr->gw;
          delta_threshold = 0.05;
          xx1 = gr->gx1 - delta * delta_threshold;
          xx2 =gr->gx2 - delta * delta_threshold;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
          need_redraw = 1;
        }
      }
    }
    else if(event == ButtonPress && button == Button4 && !(state & ShiftMask) &&
            !wheel_axis_done)  {
      double delta;
      /* vertical move of waveforms with mouse wheel */
      if(xctx->graph_left) {
        if(i == xctx->graph_master) {
          if(gr->digital) {
            delta = gr->posh * 0.05;
            yy1 = gr->ypos1 - delta;
            yy2 = gr->ypos2 - delta;
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos1", dtoa(yy1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos2", dtoa(yy2)));
            need_redraw = 1;
          } else {
            delta = gr->gh / gr->divy;
            delta_threshold = 1.0;
            yy1 = gr->gy1 - delta * delta_threshold;
            yy2 = gr->gy2 - delta * delta_threshold;
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y1", dtoa(yy1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y2", dtoa(yy2)));
            need_redraw = 1;
          }
        }
      }
      /* horizontal move of waveforms with mouse wheel */
      else {
        /* selected or locked or master */
        if(r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master) {
          delta = gr->gw;
          delta_threshold = 0.05;
          xx1 = gr->gx1 + delta * delta_threshold;
          xx2 = gr->gx2 + delta * delta_threshold;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
          need_redraw = 1;
        }
      }
    }
    else if(event == ButtonPress && button == Button5 && (state & ShiftMask)) {
      if(xctx->graph_left) {
        if(i == xctx->graph_master) {
          if(gr->digital) {
            double m = DG_Y(xctx->mousey);
            double a = m - gr->ypos1;
            double b = gr->ypos2 -m;
            double delta = gr->posh;
            double var = delta * 0.05;
            yy2 = gr->ypos2 + var * b / delta;
            yy1 = gr->ypos1 - var * a / delta;
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos1", dtoa(yy1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos2", dtoa(yy2)));
            need_redraw = 1;

          } else {
            double m = G_Y(xctx->mousey);
            double a = m - gr->gy1;
            double b = gr->gy2 -m;
            double delta = (gr->gy2 - gr->gy1);
            double var = delta * 0.2;
            yy2 = gr->gy2 + var * b / delta;
            yy1 = gr->gy1 - var * a / delta;
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y1", dtoa(yy1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y2", dtoa(yy2)));
            need_redraw = 1;
          }
        }
      } else {
        /* selected or locked or master */
        if(r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master) {
          double var = 0.2 * gr->gw;
          xx2 = gr->gx2 + var * (1 - zoom_m);
          xx1 = gr->gx1 - var * zoom_m;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
          need_redraw = 1;
        }
      }
    }
    else if(event == ButtonPress && button == Button4 && (state & ShiftMask)) {
      if(xctx->graph_left) {
        if(i == xctx->graph_master) {
          if(gr->digital) {
            double m = DG_Y(xctx->mousey);
            double a = m - gr->ypos1;
            double b = gr->ypos2 -m;
            double delta = (gr->ypos2 - gr->ypos1);
            double var = delta * 0.05;
            yy2 = gr->ypos2 - var * b / delta;
            yy1 = gr->ypos1 + var * a / delta;
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos1", dtoa(yy1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos2", dtoa(yy2)));
            need_redraw = 1;
          } else {
            double m = G_Y(xctx->mousey);
            double a = m - gr->gy1;
            double b = gr->gy2 -m;
            double delta = (gr->gy2 - gr->gy1);
            double var = delta * 0.2;
            yy2 = gr->gy2 - var * b / delta;
            yy1 = gr->gy1 + var * a / delta;
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y1", dtoa(yy1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y2", dtoa(yy2)));
            need_redraw = 1;
          }
        }
      } else {
        /* selected or locked or master */
        if(r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master) {
          double var = 0.2 * gr->gw;
          xx2 = gr->gx2 - var * (1 - zoom_m);
          xx1 = gr->gx1 + var * zoom_m;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
          need_redraw = 1;
        }
      }
    }
    /* y hcursor1 toggle */
    else if(event == KeyPress && key == 'A' && access_cond && i == xctx->graph_master) {
      xctx->graph_flags ^= 128;
      need_redraw = 1;
      if(xctx->graph_flags & 128) {
        double c = G_Y(xctx->mousey);
        if(gr->logy) c = pow(10, c);
        my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "hcursor1_y", dtoa(c)));
      } else {
        my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "hcursor1_y", NULL));
      }
    }
    /* y hcursor2 toggle */
    else if(event == KeyPress && key == 'B' && access_cond && i == xctx->graph_master) {
      xctx->graph_flags ^= 256;
      need_redraw = 1;
      if(xctx->graph_flags & 256) {
        double c = G_Y(xctx->mousey);
        if(gr->logy) c = pow(10, c);
        my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "hcursor2_y", dtoa(c)));
      } else {
        my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "hcursor2_y", NULL));
      }
    }
    else if(event == KeyPress && key == 't' && access_cond ) {
      if(track_dset != -2) { /* -2 means no dataset selection ('t' key) was started */
        /*
        const char *unlocked = strstr(get_tok_value(r->prop_ptr, "flags", 0), "unlocked");
        */
        int unlocked = r->flags & 2;
        int floaters = there_are_floaters();
        if(i == xctx->graph_master || !unlocked) {
          gr->dataset = track_dset;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "dataset", my_itoa(track_dset)));

        }
       /* do this here to update texts printing current dataset in graph
        *     tcleval([xschem getprop rect 2 n dataset]) */
        if(i == xctx->graph_master && floaters) {
          set_modify(-2); /* update floater caches to reflect actual backannotation */
          need_fullredraw = 1;
        }
        if((xctx->graph_flags & 4)  && tclgetboolvar("live_cursor2_backannotate")) {
          if(i == xctx->graph_master) {
            backannotate_at_cursor_b_pos(r, gr);
          }
          need_fullredraw = 1;
        } else {
          if(!need_fullredraw) need_redraw = 1;
        }

      }
    } /* key == 't' */
    else if(event == KeyPress && key == XK_Left) {
      double delta;
      if(xctx->graph_left) {
        if(!gr->digital && i == xctx->graph_master) {
          double m = G_Y(xctx->mousey);
          double a = m - gr->gy1;
          double b = gr->gy2 -m;
          double delta = gr->gh;
          double var = delta * 0.2;
          yy2 = gr->gy2 + var * b / delta;
          yy1 = gr->gy1 - var * a / delta;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y1", dtoa(yy1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y2", dtoa(yy2)));
          need_redraw = 1;
        }
      } else {
        if(r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master) {
          delta = gr->gw;
          delta_threshold = 0.05;
          xx1 = gr->gx1 - delta * delta_threshold;
          xx2 = gr->gx2 - delta * delta_threshold;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
          need_redraw = 1;
        }
      }
    }
    else if(event == KeyPress && key == XK_Right) {
      double delta;
      if(xctx->graph_left) {
        if(!gr->digital && i == xctx->graph_master) {
          double m = G_Y(xctx->mousey);
          double a = m - gr->gy1;
          double b = gr->gy2 -m;
          double delta = gr->gh;
          double var = delta * 0.2;
          yy2 = gr->gy2 - var * b / delta;
          yy1 = gr->gy1 + var * a / delta;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y1", dtoa(yy1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y2", dtoa(yy2)));
          need_redraw = 1;
        }
      } else {
        if(r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master) {
          delta = gr->gw;
          delta_threshold = 0.05;
          xx1 = gr->gx1 + delta * delta_threshold;
          xx2 = gr->gx2 + delta * delta_threshold;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
          need_redraw = 1;
        }
      }
    }
    else if(event == KeyPress && key == XK_Down) {
      if(!xctx->graph_left) {
        /* selected or locked or master */
        if(r->sel || !(r->flags & 2) || i == xctx->graph_master) {
          double var = 0.2 * gr->gw;
          xx2 = gr->gx2 + var * (1 - zoom_m);
          xx1 = gr->gx1 - var * zoom_m;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
          need_redraw = 1;
        }
      }
    }
    else if(event == KeyPress && key == XK_Up) {
      if(!xctx->graph_left) {
        /* selected or locked or master */
        if(r->sel || !(r->flags & 2) || i == xctx->graph_master) {
          double var = 0.2 * gr->gw;
          xx2 = gr->gx2 - var * (1 - zoom_m);
          xx1 = gr->gx1 + var * zoom_m;
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
          need_redraw = 1;
        }
      }
    }
    else if(event == KeyPress && key == 'f' && access_cond) {
      if(xctx->raw && xctx->raw->values) {
        if(xctx->graph_left) { /* full Y zoom*/
          if(i == xctx->graph_master) {
            need_redraw = graph_fullyzoom(r, gr, dataset);
          } /* graph_master */
        } else { /* not graph_left, full X zoom*/
          /* selected or locked or master */
          if(r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master) {
            need_redraw = graph_fullxzoom(i, gr, dataset);
          }
        }
      } /* raw->values */
    } /* key == 'f' */
    /* absolute positioning by mouse drag in bottom graph area (MMB, see above) */
    else if(event == MotionNotify && (state & Button2Mask) && xctx->graph_bottom ) {
      if(xctx->raw && xctx->raw->values) {
        /* selected or locked or master */
        if(r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master) {

          /* xx1 and xx2 calculated for master graph above */
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
          need_redraw = 1;
        }
      }
    }


    else if(event == ButtonRelease) {
      if(button != Button3) {
        xctx->ui_state &= ~GRAPHPAN;
        xctx->graph_flags &= ~(16 | 32 | 512 | 1024); /* clear move cursor flags */
      }
      /* zoom X+Y area by mouse drag (box zoom): X window across all
       * participating graphs (as before), Y window on the master graph only
       * (Y is per-graph). The Y branch mirrors the left-margin Y zoom below. */
      else if(button == Button3 && (xctx->ui_state & GRAPHPAN) &&
              !xctx->graph_left && !xctx->graph_top) {
        int xmoved = (xctx->mx_double_save != xctx->mousex_snap);
        int ymoved = (xctx->my_double_save != xctx->mousey_snap);
        /* X: selected or locked or master */
        if(xmoved && (r->sel || (same_sim_type && !(r->flags & 2)) || i == xctx->graph_master)) {
          clear_graphpan_at_end = 1;
          /* xx1 and xx2 calculated for master graph above */
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
          need_redraw = 1;
        }
        /* Y: master graph only */
        if(ymoved && i == xctx->graph_master) {
          double byy1, byy2;
          clear_graphpan_at_end = 1;
          if(!gr->digital) {
            byy1 = G_Y(xctx->my_double_save);
            byy2 = G_Y(xctx->mousey_snap);
            if(state & ShiftMask) {
              if(byy1 < byy2) { double tmp = byy1; byy1 = byy2; byy2 = tmp; }
            } else {
              if(byy2 < byy1) { double tmp = byy1; byy1 = byy2; byy2 = tmp; }
            }
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y1", dtoa(byy1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y2", dtoa(byy2)));
          } else {
            byy1 = DG_Y(xctx->my_double_save);
            byy2 = DG_Y(xctx->mousey_snap);
            if(state & ShiftMask) {
              if(byy1 < byy2) { double tmp = byy1; byy1 = byy2; byy2 = tmp; }
            } else {
              if(byy2 < byy1) { double tmp = byy1; byy1 = byy2; byy2 = tmp; }
            }
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos1", dtoa(byy1)));
            my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos2", dtoa(byy2)));
          }
          need_redraw = 1;
        }
        if(!xmoved && !ymoved && i == xctx->graph_master) {
          clear_graphpan_at_end = 1;
        }
      }
      /* zoom Y area by mouse drag */
      else if(button == Button3 && (xctx->ui_state & GRAPHPAN) &&
              xctx->graph_left && !xctx->graph_top) {
        /* Only on master */
        if(i == xctx->graph_master) {
          if(xctx->my_double_save != xctx->mousey_snap) {
            double yy1, yy2;
            clear_graphpan_at_end = 1;
            if(!gr->digital) {
              yy1 = G_Y(xctx->my_double_save);
              yy2 = G_Y(xctx->mousey_snap);
              if(state & ShiftMask) {
                if(yy1 < yy2) { double tmp; tmp = yy1; yy1 = yy2; yy2 = tmp; }
              } else {
                if(yy2 < yy1) { double tmp; tmp = yy1; yy1 = yy2; yy2 = tmp; }
              }
              my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y1", dtoa(yy1)));
              my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y2", dtoa(yy2)));
            } else {
              yy1 = DG_Y(xctx->my_double_save);
              yy2 = DG_Y(xctx->mousey_snap);
              if(state & ShiftMask) {
                if(yy1 < yy2) { double tmp; tmp = yy1; yy1 = yy2; yy2 = tmp; }
              } else {
                if(yy2 < yy1) { double tmp; tmp = yy1; yy1 = yy2; yy2 = tmp; }
              }
              my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos1", dtoa(yy1)));
              my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos2", dtoa(yy2)));
            }
            need_redraw = 1;
          } else if(i == xctx->graph_master) {
            clear_graphpan_at_end = 1;
          }
        }
      }
    } /* else if( event == ButtonRelease) */
    if(need_redraw || need_all_redraw || ( i == xctx->graph_master && need_redraw_master) ) {
      setup_graph_data(i, 0, gr);
      draw_graph(i, 1 + 8 + 16 + (xctx->graph_flags & (4 | 2 | 128 | 256)), gr, NULL); /* draw data in each graph box */
    }
  } /* for(i=0; i< xctx->rects[GRIDLAYER]; i++ */

  if(need_fullredraw ==1) {
    draw();
    need_fullredraw = 0;
  }
  if(clear_graphpan_at_end) xctx->ui_state &= ~GRAPHPAN;
  /* update saved mouse position after processing all graphs */
  if(save_mouse_at_end) {
    if( fabs(xctx->mx_double_save - xctx->mousex_snap) > fabs(gr->master_cx * gr->master_gw) * delta_threshold) {
      dbg(1, "save mouse pos\n");
      xctx->mx_double_save = xctx->mousex_snap;
      xctx->my_double_save = xctx->mousey_snap;
    }
  }


  draw_selection(xctx->gc[SELLAYER], 0);
  #if HAS_CAIRO==1
  cairo_restore(xctx->cairo_ctx);
  cairo_restore(xctx->cairo_save_ctx);
  #endif
  return 0;
}

/* action-log Layer C: can s be embedded in a logged command as a {braced} Tcl
 * word with no reparse risk? Conservative: refuse braces and backslashes
 * outright rather than balance-check, so the log file ALWAYS stays
 * source-able (the Layer B invariant). */
int tcl_braceable(const char *s)
{
  for(; *s; s++) if(*s == '{' || *s == '}' || *s == '\\') return 0;
  return 1;
}

/* action-log Layer C: emit one replayable command whose argv is already fully
 * stringified (numeric fields pre-formatted). Tcl_Merge quotes EVERY element
 * into a valid, re-parsable list, so ANY legal instance name / property string --
 * including one with braces or backslashes (Windows paths, escaped tokens) --
 * round-trips and the placement stays replayable, instead of being dropped to a
 * '#' comment by the tcl_braceable brace-wrap guard (issue 0048). Guarantees the
 * Layer B "log always source-able" invariant rather than merely preserving it. */
/* Log one already-parsed command as a faithfully-quoted replayable line:
 * Tcl_Merge re-quotes each argv element so braces/spaces/backslashes round-trip.
 * Exposed (non-static) so scheduler.c self-logs arg-carrying subcommands (setprop)
 * with the same fidelity as the gesture read-back paths here. */
void log_action_argv(int argc, const char *const *argv)
{
  char *line = Tcl_Merge(argc, argv);
  log_action("%s", line);
  Tcl_Free(line);
}

/* Read the lone placed instance back and log its coordinate replay form
 * `xschem instance {sym} x y rot flip {prop}` (Tcl_Merge quotes name/prop safely
 * -> replayable for any legal string, incl. the braces/backslashes the old
 * tcl_braceable guard rejected, issue 0048). Returns 1 if a single ELEMENT was
 * logged, else 0 (the caller emits its own '#' fallback marker). Shared by the
 * PLACE_SYMBOL drop and the schematic Add-Pin drop -- add_sch_pin -place places
 * an ipin/opin/iopin INSTANCE, so its drop replays exactly like a normal symbol
 * placement (issue 0069 sympin atom 11). The coordinate form bypasses this
 * funnel on replay, so a replayed line never re-logs. */
static int log_placed_instance(void)
{
  int n = (xctx->lastsel == 1 && xctx->sel_array[0].type == ELEMENT) ? xctx->sel_array[0].n : -1;
  const char *name, *prop;
  char xb[64], yb[64], rb[16], fb[16];
  const char *av[8];
  if(n < 0 || n >= xctx->instances) return 0;
  name = xctx->inst[n].name ? xctx->inst[n].name : "";
  prop = xctx->inst[n].prop_ptr ? xctx->inst[n].prop_ptr : "";
  my_snprintf(xb, S(xb), "%.16g", xctx->inst[n].x0);
  my_snprintf(yb, S(yb), "%.16g", xctx->inst[n].y0);
  my_snprintf(rb, S(rb), "%d", (int)xctx->inst[n].rot);
  my_snprintf(fb, S(fb), "%d", (int)xctx->inst[n].flip);
  av[0] = "xschem"; av[1] = "instance"; av[2] = name; av[3] = xb;
  av[4] = yb; av[5] = rb; av[6] = fb; av[7] = prop;
  log_action_argv(8, av);
  return 1;
}

/* issue 0246: WHO owns the sympin drop that is about to be counted. wirelabel_preview is the
 * exact discriminator, but ONLY here inside the commit funnel: the two pin arms force it to 0
 * (scheduler.c add_symbol_pin / add_sch_pin -place), the label arm sets it (add_wire_label
 * -place), and wire_label_try_commit() calls end_move_copy_logged() BEFORE zeroing it. By the
 * time either Tcl after_drop runs it is already down, which is why the split has to happen in C.
 * Kept as two tiny functions on purpose: the fix must be neutralizable by a macro rename. */
static int sympin_owner_is_label(void)
{
  return xctx && xctx->wirelabel_preview;
}
static void sympin_count_owner(void)
{
  if(!xctx) return;
  if(sympin_owner_is_label()) xctx->sympin_drops_label++;
  else                        xctx->sympin_drops_pin++;
}

/* action-log Layer C (spec section 2): complete a move/copy drag and record
 * the single command reproducing its effect. The two callback completion
 * paths (end_place_move_copy_zoom and the intuitive-interface release) both
 * come through here; the scheduler's own move_objects(END) calls and the
 * inline key rotate/flip sequences do NOT (they are not drag gestures --
 * hooking move.c instead would double-log every replay).
 * deltax/deltay/move_rot/move_flip and the placement ui_state flags are
 * captured BEFORE the END (which resets them); the line is written after the
 * END ran (record-after-evaluation, as everywhere else). A plain translation
 * replays as `xschem move_objects/copy_objects dx dy [kissing]` on the then-
 * current selection -- fidelity bounded by issue 0005 exactly like the
 * Layer B cut/copy picks. Drops completing a placement flow read the placed
 * object back instead (coordinate-replayable) or leave a '#' marker. */
static void end_move_copy_logged(int is_copy)
{
  int ui = xctx->ui_state;
  double dx = xctx->deltax, dy = xctx->deltay;
  int rot = xctx->move_rot, flip = xctx->move_flip;
  /* Log the ARMED flag, not the OUTCOME flag. xctx->kissing is connect_by_kissing()'s return --
   * "at least one rescue stub was stored" -- and it used to be a safe stand-in for "the gesture
   * was a connected drag", because arming with nothing to kiss changed nothing.
   * wire_label_ride.md S1 broke that equivalence: a connected drag of a NET LABEL deliberately
   * stores no stub (change #4) yet the LEASH keys off the arming flag, so logging the outcome
   * would emit a bare `move_objects dx dy` whose replay is a RIGID move -- which detaches the
   * label and renames its net (the K1 policy). Both flags are still live here: move_objects(END)
   * below is what resets connect_by_kissing. */
  int kissing = xctx->connect_by_kissing || xctx->kissing;
  /* paste/merge drop (issue 0069): reset/overwritten by move_objects(END) below, capture
   * now. The source test is merge_source == clip_file (bare `xschem paste`) vs anything
   * else (-file rider) -- NOT paste_from, which any failed/cancelled mid-gesture
   * merge_file() call resets to 0 without touching the pending gesture (atom-9 review);
   * merge_source is written only on a successful open, so it stays owned by the pending
   * merge. rotatelocal picks the per-object pivot for a mid-gesture in-place rotate/flip;
   * x1/y1 is the shared rotation anchor (from the merged file's G record), recorded as
   * `-anchor` because a whole-log replay regenerates the clipboard via the replayed
   * `xschem copy` with a DIFFERENT pointer position -> different G record -> a rot/flip
   * drop would land rotated about the wrong point (atom-9 review). */
  int rotl = xctx->rotatelocal;
  double ax = xctx->x1, ay = xctx->y1;
  /* mirror the END early-return: click on elements without motion does nothing */
  int nothing = xctx->drag_elements && dx == 0. && dy == 0.;

  /* issue 0122 E1: count a COMMITTED Add-Pin/Add-Wire-Label FORM drop for the Tcl form queue.
   * end_move_copy_logged is the only commit funnel (aborts are deleted in a different path and
   * never reach here; an off-copper net-label refusal returns from wire_label_try_commit() before
   * calling us). Gate on sympin_preview -- set ONLY by the three form -place arms (add_sch_pin /
   * add_symbol_pin / add_wire_label, scheduler.c) and still 1 here (cleared AFTER this funnel) --
   * so a NON-form START_SYMPIN placement that also uses this machinery (place_net_label,
   * add_graph, add_image, image paste) does NOT bump the count and cannot make an armed form
   * spuriously drain. Bump BEFORE the nothing/early returns so even a no-motion drop is recorded.
   * issue 0246: the same drop is also counted PER OWNER (sympin_count_owner, above) in this one
   * place and under this one gate, so total == pin + label always holds and no second gate can
   * drift from this one. */
  if((ui & START_SYMPIN) && xctx->sympin_preview) {
    xctx->sympin_drops++;
    sympin_count_owner();
  }

  if(is_copy) copy_objects(END);
  else        move_objects(END, 0, 0, 0);

  /* cadence deferred-selection (doc/claude/specs/cadence_modifier_drag.md): a plain drag that
   * transiently selected a previously-unselected object restores the pre-press selection -- so the
   * grabbed object ends UNSELECTED (or a pre-existing selection is preserved untouched). Only when
   * it actually MOVED: a click (nothing) keeps the normal click-select. Never on copy (the new copy
   * stays selected). Armed only for a plain no-modifier move of a not-already-selected object. */
  if(xctx->drag_sel_restore) {
    if(!is_copy && !nothing) drag_sel_restore_now();  /* frees the snapshot internally */
    else                     drag_sel_free();
  }

  if(nothing) return;
  if(ui & STARTMERGE) {
    /* action-log (issue 0069): the drop replays through the scheduler's coordinate
     * paste arm (`xschem paste dx dy [rot flip [local]] [-file {f}]`), which calls
     * merge_file + move_objects(END) directly -- never this funnel -- so a replay
     * cannot re-log (coordinate-form-bypass invariant). A clipboard paste logs the
     * bare form and replays against the replay-time clipboard file (faithful-to-op
     * accepted delta, like the libmgr do_checkin_lib re-sweep); file merges carry
     * the recorded source via -file. The cross-window selection transfer
     * (paste_from == 1) logs its transient sel_file path: usually gone at replay,
     * so the line no-ops -- accepted, the source has no durable referent. */
    char xb[64], yb[64], rb[16], fb[16], axb[64], ayb[64];
    const char *av[12];
    int ac = 0;
    my_snprintf(xb, S(xb), "%.16g", dx);
    my_snprintf(yb, S(yb), "%.16g", dy);
    av[ac++] = "xschem"; av[ac++] = "paste"; av[ac++] = xb; av[ac++] = yb;
    if(rot || flip) {
      my_snprintf(rb, S(rb), "%d", rot);
      my_snprintf(fb, S(fb), "%d", flip);
      av[ac++] = rb; av[ac++] = fb;
      if(rotl) av[ac++] = "local";
      else {
        /* shared-pivot transform: pin the anchor, see the capture comment above.
         * (translation-only and `local` drops are pivot-independent -> no rider) */
        my_snprintf(axb, S(axb), "%.16g", ax);
        my_snprintf(ayb, S(ayb), "%.16g", ay);
        av[ac++] = "-anchor"; av[ac++] = axb; av[ac++] = ayb;
      }
    }
    if(strcmp(xctx->merge_source, clip_file) && xctx->merge_source[0]) {
      av[ac++] = "-file"; av[ac++] = xctx->merge_source;
    }
    log_action_argv(ac, av);
  }
  else if(ui & START_SYMPIN) {
    /* Two drops share START_SYMPIN + the sympin_preview move machinery (issue 0069
     * atom 11), told apart here by the dropped object's type:
     *  (a) SYMBOL pin -- a PINLAYER rect (+ its owned name view) placed by
     *      `add_symbol_pin -place`. Replays via the direct `add_symbol_pin x y name
     *      dir 0 1` form: draw off (a full redraw follows on replay) and NO-LINE on,
     *      because the -place drop stores only the rect + name view while the raw
     *      add_symbol_pin form also stores a 20-unit stub leg line; the trailing `1`
     *      suppresses it so the replay geometry is byte-identical to the drop.
     *  (b) SCHEMATIC pin -- an ipin/opin/iopin INSTANCE placed by `add_sch_pin
     *      -place`. Replays via the same `xschem instance` read-back as any symbol
     *      placement (log_placed_instance).
     * Both replay forms are coordinate commands that bypass this funnel, so a
     * replayed line never re-logs (coordinate-form-bypass invariant). */
    int i, pr = -1;
    for(i = 0; i < xctx->lastsel; ++i) {
      if(xctx->sel_array[i].type == xRECT && xctx->sel_array[i].col == PINLAYER) {
        pr = xctx->sel_array[i].n;
        break;
      }
    }
    if(pr >= 0 && pr < xctx->rects[PINLAYER]) {
      xRect *p = &xctx->rect[PINLAYER][pr];
      char *nm = NULL, *dr = NULL;
      char xb[64], yb[64];
      const char *av[8];
      /* get_tok_value() shares one volatile static buffer -> copy each token out
       * before the next call (cf. create_pin, actions.c) */
      my_strdup(_ALLOC_ID_, &nm, get_tok_value(p->prop_ptr, "name", 0));
      my_strdup(_ALLOC_ID_, &dr, get_tok_value(p->prop_ptr, "dir", 0));
      my_snprintf(xb, S(xb), "%.16g", (p->x1 + p->x2) / 2.0);
      my_snprintf(yb, S(yb), "%.16g", (p->y1 + p->y2) / 2.0);
      av[0] = "xschem"; av[1] = "add_symbol_pin"; av[2] = xb; av[3] = yb;
      av[4] = nm ? nm : ""; av[5] = dr ? dr : ""; av[6] = "0"; av[7] = "1";
      log_action_argv(8, av);
      my_free(_ALLOC_ID_, &nm);
      my_free(_ALLOC_ID_, &dr);
      return;
    }
    if(log_placed_instance()) return;
    log_action("# place symbol pin (pin not cleanly recordable)");
  }
  else if(ui & PLACE_SYMBOL) {
    if(log_placed_instance()) return;
    log_action("# place symbol (instance not cleanly recordable)");
  }
  else if(ui & PLACE_TEXT) {
    int n = (xctx->lastsel == 1 && xctx->sel_array[0].type == xTEXT) ? xctx->sel_array[0].n : -1;
    if(n >= 0 && n < xctx->texts) {
      const char *txt = xctx->text[n].txt_ptr ? xctx->text[n].txt_ptr : "";
      const char *prop = xctx->text[n].prop_ptr ? xctx->text[n].prop_ptr : "";
      char xb[64], yb[64], rb[16], fb[16], sb[64];
      const char *av[10];
      my_snprintf(xb, S(xb), "%.16g", xctx->text[n].x0);
      my_snprintf(yb, S(yb), "%.16g", xctx->text[n].y0);
      my_snprintf(rb, S(rb), "%d", (int)xctx->text[n].rot);
      my_snprintf(fb, S(fb), "%d", (int)xctx->text[n].flip);
      my_snprintf(sb, S(sb), "%.16g", xctx->text[n].xscale);
      av[0] = "xschem"; av[1] = "text"; av[2] = xb; av[3] = yb; av[4] = rb;
      av[5] = fb; av[6] = txt; av[7] = prop; av[8] = sb; av[9] = "1";
      log_action_argv(10, av);
      return;
    }
    log_action("# place text (text not cleanly recordable)");
  }
  else if(rot || flip) {
    /* action-log (issue 0069 atom 13): a mid-move/copy rotate/flip drop replays through
     * the scheduler's own coordinate move_objects/copy_objects arm, which sets
     * move_rot/move_flip/rotatelocal (+ the anchor) then calls START/END directly -- never
     * this funnel -- so a replay never re-logs (coordinate-form-bypass invariant). `local`
     * marks the per-object in-place transform (Alt-R/F on a single object, pivot-
     * independent); a shared-pivot group rotate (Shift-R/F/V, or Alt-R/F on a multi-object
     * connected drag) pins x1/y1 as `-anchor` because a whole-log replay's move START seeds
     * x1/y1 from the replay-time cursor, not the recorded grab point -> the rotation would
     * be about the wrong point (the atom-9 paste G-record pivot lesson, verified there).
     * Translation-only and `local` drops are pivot-independent -> no rider. `kissing` rides
     * last, exactly as the plain-translation arm below records it. */
    char xb[64], yb[64], rb[16], fb[16], axb[64], ayb[64];
    const char *av[12];
    int ac = 0;
    my_snprintf(xb, S(xb), "%.16g", dx);
    my_snprintf(yb, S(yb), "%.16g", dy);
    my_snprintf(rb, S(rb), "%d", rot);
    my_snprintf(fb, S(fb), "%d", flip);
    av[ac++] = "xschem"; av[ac++] = is_copy ? "copy_objects" : "move_objects";
    av[ac++] = xb; av[ac++] = yb; av[ac++] = rb; av[ac++] = fb;
    if(rotl) av[ac++] = "local";
    else {
      my_snprintf(axb, S(axb), "%.16g", ax);
      my_snprintf(ayb, S(ayb), "%.16g", ay);
      av[ac++] = "-anchor"; av[ac++] = axb; av[ac++] = ayb;
    }
    if(kissing) av[ac++] = "kissing";
    log_action_argv(ac, av);
  }
  else {
    log_action("xschem %s %.16g %.16g%s", is_copy ? "copy_objects" : "move_objects",
      dx, dy, kissing ? " kissing" : "");
  }
}

/* action-log Layer C (Phase 3 slice C): a drag-pan has no single completion
 * function -- pan(RUBBER) shifts the origin continuously and the two un-pan
 * sites only clear STARTPAN. The START wrapper snapshots the origin; the END
 * hook logs the accumulated shift as its replay form `xschem pan dx dy`
 * (record-after-evaluation: the shift has already happened). */
static double pan_log_xorig, pan_log_yorig;
static void start_pan_logged(int mx, int my)
{
  pan_log_xorig = xctx->xorigin;
  pan_log_yorig = xctx->yorigin;
  pan(START, mx, my);
  xctx->ui_state |= STARTPAN;
}
static void log_pan_end(void)
{
  double dx = xctx->xorigin - pan_log_xorig;
  double dy = xctx->yorigin - pan_log_yorig;
  /* dx/dy are a VIEWPORT delta (origin shift), NOT a coordinate on the snap grid --
   * the origin is arbitrary, so snap_to_grid() does not apply here (unlike the pivot
   * verbs / select_at). Pan is view-only (never touches schematic/netlist), so the
   * shift need not be grid-aligned; %.10g (was %.16g) only trims the float noise a
   * mouse-pixel*zoom delta accrues, keeping the log readable. */
  if(dx != 0. || dy != 0.) log_action("xschem pan %.10g %.10g", dx, dy);
}

/* Cadence net-label drop gate (doc/claude/specs/add_wire_label.md). The armed wire-label
 * preview may be COMMITTED only where its pin lands on copper (a wire or a non-selected instance
 * pin, point_on_wire_or_pin()). Returns 1 = committed (move END + preview flags cleared, undo
 * baseline kept), 0 = refused (preview left attached to the cursor, queue not advanced). Shared
 * by the GUI button drop (end_place_move_copy_zoom, below) and the headless `add_wire_label
 * -drop` seam so both enforce the identical rule. Not our gesture -> 0 (caller must not treat
 * that as a refusal of a real label drop). */
int wire_label_try_commit(void)
{
  if(!xctx) return 0;
  if(!(xctx->ui_state & START_SYMPIN) || !xctx->wirelabel_preview) return 0;
  if(!point_on_wire_or_pin(xctx->mousex_snap, xctx->mousey_snap)) {
    tcleval("if {[info procs addlabel::on_reject] ne {}} {addlabel::on_reject}");
    return 0;  /* off copper: keep the preview live so the user can reposition */
  }
  end_move_copy_logged(0);
  xctx->ui_state &= ~START_SYMPIN;
  xctx->sympin_preview = 0;
  xctx->wirelabel_preview = 0;
  clear_placement_preview();  /* issue 0241: committed, so it is no longer a deletable preview */
  xctx->constr_mv = 0;
  tcleval("set constr_mv 0");
  return 1;
}

/* complete the STARTWIRE, STARTRECT, STARTZOOM, STARTCOPY ... operations */
static int end_place_move_copy_zoom()
{
  if(xctx->ui_state & STARTZOOM) {
    zoom_rectangle(END);
    if( xctx->nl_x1 == xctx->nl_x2 && xctx->nl_y1 == xctx->nl_y2) {
      return 0;
    }
    /* action-log Layer C: the final coords replay through `xschem zoom_box`
     * (factor defaults to 1 -> same origin/zoom math as zoom_rectangle(END);
     * the degenerate no-op rectangle above is skipped in both). */
    log_action("xschem zoom_box %.16g %.16g %.16g %.16g",
      xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2);
    return 1;
  }
  else if(xctx->ui_state & STARTWIRE) {
    if(tclgetboolvar("persistent_command")) {
      if(xctx->constr_mv != 2) {
        xctx->mx_double_save=xctx->mousex_snap;
      }
      if(xctx->constr_mv != 1) {
        xctx->my_double_save=xctx->mousey_snap;
      }
      if(xctx->constr_mv == 1) xctx->mousey_snap = xctx->my_double_save;
      if(xctx->constr_mv == 2) xctx->mousex_snap = xctx->mx_double_save;
      new_wire(PLACE, xctx->mousex_snap, xctx->mousey_snap);

    } else {
      new_wire(PLACE|END, xctx->mousex_snap, xctx->mousey_snap);
    }
    xctx->constr_mv=0;
    tcleval("set constr_mv 0" );
    return 0;
  }
  else if(xctx->ui_state & STARTARC) {
    new_arc(SET, 0, xctx->mousex_snap, xctx->mousey_snap);
    return 0;
  }
  else if(xctx->ui_state & STARTLINE) {
    if(tclgetboolvar("persistent_command")) {
      if(xctx->constr_mv != 2) {
        xctx->mx_double_save=xctx->mousex_snap;
      }
      if(xctx->constr_mv == 1) {
        xctx->my_double_save=xctx->mousey_snap;
      }
      if(xctx->constr_mv == 1) xctx->mousey_snap = xctx->my_double_save;
      if(xctx->constr_mv == 2) xctx->mousex_snap = xctx->mx_double_save;
      new_line(PLACE, xctx->mousex_snap, xctx->mousey_snap);
    } else {
      new_line(PLACE|END, xctx->mousex_snap, xctx->mousey_snap);
    }
    xctx->constr_mv=0;
    tcleval("set constr_mv 0" );
    return 0;
  }
  else if(xctx->ui_state & STARTRECT) {
    new_rect(PLACE|END,xctx->mousex_snap, xctx->mousey_snap);
    return 0;
  }
  else if(xctx->ui_state & STARTPOLYGON) {
    if(xctx->constr_mv == 1) xctx->mousey_snap = xctx->my_double_save;
    if(xctx->constr_mv == 2) xctx->mousex_snap = xctx->mx_double_save;
    new_polygon(ADD, xctx->mousex_snap, xctx->mousey_snap);
    xctx->mx_double_save=xctx->mousex_snap;
    xctx->my_double_save=xctx->mousey_snap;
    xctx->constr_mv=0;
    tcleval("set constr_mv 0" );
    return 0;
  }
  else if(xctx->ui_state & STARTMOVE) {
    /* add_wire_label.md: a Cadence net-label preview may only drop on copper. Route it through
     * the shared gate; on REFUSAL swallow the click (return 1 -> the caller records the press as
     * a committed placement click and does NOT fall through to click-select) but leave the
     * preview attached so the next motion + click retries. */
    if(xctx->wirelabel_preview) {
      wire_label_try_commit();
      return 1;
    }
    end_move_copy_logged(0);
    xctx->ui_state &=~START_SYMPIN;
    /* an Add-Pin preview pin was just dropped (committed): the gesture's undo baseline is
     * on the stack already, so clear the preview flag -> the drop-hook's next arm starts a
     * fresh baseline for the next pin (cadence_pin_name_text.md item #3). */
    xctx->sympin_preview = 0;
    clear_placement_preview(); /* issue 0241: committed objects are not a deletable preview */
    xctx->constr_mv=0;
    tcleval("set constr_mv 0" );
    return 1;
  }
  else if(xctx->ui_state & STARTCOPY) {
    end_move_copy_logged(1);
    xctx->constr_mv=0;
    tcleval("set constr_mv 0" );
    return 1;
  }
  return 0;
}

static void draw_snap_cursor_shape(GC gc, double x, double y, int snapcursor_size) {
  /* Convert coordinates to screen space */
  double screen_x = X_TO_SCREEN(x);
  double screen_y = Y_TO_SCREEN(y);
  double left = screen_x - snapcursor_size;
  double right = screen_x + snapcursor_size;
  double top = screen_y - snapcursor_size;
  double bottom = screen_y + snapcursor_size;
  int i;
  /* Define crosshair lines */
  double lines[4][4];
  lines[0][0] = screen_x; lines[0][1] = top;      lines[0][2] = right;    lines[0][3] = screen_y;
  lines[1][0] = right;    lines[1][1] = screen_y; lines[1][2] = screen_x; lines[1][3] = bottom;
  lines[2][0] = screen_x; lines[2][1] = bottom;   lines[2][2] = left;     lines[2][3] = screen_y;
  lines[3][0] = left;     lines[3][1] = screen_y; lines[3][2] = screen_x; lines[3][3] = top;
  /* Draw crosshair lines */
  for (i = 0; i < 4; i++) {
      draw_xhair_line(gc, snapcursor_size, lines[i][0], lines[i][1], lines[i][2], lines[i][3]);
  }
}

static void erase_snap_cursor(double prev_x, double prev_y, int snapcursor_size) {
  if (fix_broken_tiled_fill || !_unix) {
      MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
          (int)X_TO_SCREEN(prev_x) - INT_LINE_W(xctx->lw) - snapcursor_size,
          (int)Y_TO_SCREEN(prev_y) - INT_LINE_W(xctx->lw) - snapcursor_size,
          2 * INT_LINE_W(xctx->lw) + 2 * snapcursor_size,
          2 * INT_LINE_W(xctx->lw) + 2 * snapcursor_size,
          (int)X_TO_SCREEN(prev_x) - INT_LINE_W(xctx->lw) - snapcursor_size,
          (int)Y_TO_SCREEN(prev_y) - INT_LINE_W(xctx->lw) - snapcursor_size);
  } else {
      draw_snap_cursor_shape(xctx->gctiled, prev_x, prev_y, snapcursor_size);
  }
}

static void find_snap_position(double *x, double *y, int pos_changed) {
  if (!pos_changed) {
    *x = xctx->prev_snapx;
    *y = xctx->prev_snapy;
  } else {
    xctx->closest_pin_found = find_closest_net_or_symbol_pin(
      xctx->mousex, xctx->mousey, x, y);
  }
}

/* action == 3 : delete and draw
 * action == 1 : delete
 * action == 2 : draw
 * action == 5 : delete even if pos not changed
 */
static void draw_snap_cursor(int action) {
  int snapcursor_size;
  int pos_changed;
  int prev_draw_window = xctx->draw_window;
  int prev_draw_pixmap = xctx->draw_pixmap;

  if (!xctx->mouse_inside) return;  /* Early exit if mouse is outside */
  /* NOT A CONCEPT ON A no_snap CANVAS (issue 0177): this glyph snaps to the
   * nearest net or symbol pin, and a waveform canvas has neither -- with nothing
   * found, find_closest_net_or_symbol_pin() falls back to mousex_snap/mousey_snap
   * (findnet.c ~208), i.e. it paints the grid.
   * ⚠ THE TEST BELONGS HERE, NOT IN THE CALLERS' `snap_cursor` LOCALS. Those are
   * computed at the TOP of callback(), BEFORE handle_window_switching() may
   * reassign xctx -- so on the EnterNotify that switches into (or out of) a
   * viewer they describe the PREVIOUS context. And the cadence 'z' arm calls this
   * directly without consulting any local at all. A test inside the drawer is
   * evaluated at call time, on the right context, from every site there is. */
  if (xctx->no_snap) return;
  snapcursor_size = tclgetintvar("snap_cursor_size");
  pos_changed = (xctx->mousex_snap != xctx->prev_gridx) || (xctx->mousey_snap != xctx->prev_gridy);
  /* Save current drawing context */
  xctx->draw_pixmap = 0;
  xctx->draw_window = 1;
  if(pos_changed || action == 5) {
    /* Erase the cursor */
    if (action & 1) {
      erase_snap_cursor(xctx->prev_snapx, xctx->prev_snapy, snapcursor_size);
      draw_selection(xctx->gc[SELLAYER], 0);
    }
    /* Redraw the cursor */
    if (action & 2) {
      double new_x, new_y;
      find_snap_position(&new_x, &new_y, pos_changed);
      draw_snap_cursor_shape(xctx->gc[xctx->crosshair_layer],new_x, new_y, snapcursor_size);
      /* Update previous position tracking */
      xctx->prev_gridx = xctx->mousex_snap;
      xctx->prev_gridy = xctx->mousey_snap;
      xctx->prev_snapx = new_x;
      xctx->prev_snapy = new_y;
    }
  }
  /* Restore previous drawing context */
  xctx->draw_window = prev_draw_window;
  xctx->draw_pixmap = prev_draw_pixmap;
}

static void erase_crosshair(int size) {

  int prev_cr_x = (int)X_TO_SCREEN(xctx->prev_crossx);
  int prev_cr_y = (int)Y_TO_SCREEN(xctx->prev_crossy);
  int lw = INT_LINE_W(xctx->lw);
  if(size) {
    MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
         prev_cr_x - 1 * lw - size, prev_cr_y - 1 * lw - size, 2 * lw + 2 * size, 2 * lw + 2 * size,
         prev_cr_x - 1 * lw - size, prev_cr_y - 1 * lw - size);
    MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
         prev_cr_x - 1 * lw - size, prev_cr_y - 1 * lw - size, 2 * lw + 2 * size, 2 * lw + 2 * size,
         prev_cr_x - 1 * lw - size, prev_cr_y - 1 * lw - size);
  } else { /* full screen span xhair */
    MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
         0, prev_cr_y - 1 * lw, xctx->xrect[0].width, 2 * lw, 0, prev_cr_y - 1 * lw);
    MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
         prev_cr_x - 1 * lw, 0, 2 * lw, xctx->xrect[0].height, prev_cr_x - 1 * lw, 0);
  }
}

static void draw_crosshair_shape(GC gc, double x, double y, int size)
{
  double screen_x = X_TO_SCREEN(x);
  double screen_y = Y_TO_SCREEN(y);
  if(size) {
    draw_xhair_line(gc, size, screen_x - size, screen_y - size, screen_x + size, screen_y - size);
    draw_xhair_line(gc, size, screen_x - size, screen_y + size, screen_x + size, screen_y + size);
    draw_xhair_line(gc, size, screen_x - size, screen_y - size, screen_x - size, screen_y + size);
    draw_xhair_line(gc, size, screen_x + size, screen_y - size, screen_x + size, screen_y + size);
  } else { /* full screen span xhair */
    draw_xhair_line(gc, size, xctx->areax1, screen_y, xctx->areax2, screen_y);
    draw_xhair_line(gc, size, screen_x, xctx->areay1, screen_x, xctx->areay2);
  }
}

/* what == 3 (+4) : delete and draw (force)
 * what == 1 (+4) : delete (force)
 * what == 2 (+4) : draw (force)
 * what == 4 : force (re)clear and/or (re)draw even if on same point */
void draw_crosshair(int what, int state)
{
  int sdw, sdp;
  int xhair_size = tclgetintvar("crosshair_size");
  int snap_cursor = tclgetintvar("snap_cursor");
  double mx, my;
  int changed = 0;
  dbg(1, "draw_crosshair(): what=%d\n", what);
  sdw = xctx->draw_window;
  sdp = xctx->draw_pixmap;

  if(!xctx->mouse_inside) return;
  /* NOT A CONCEPT ON A no_snap CANVAS (issue 0177). This is drawn AT
   * mousex_snap/mousey_snap (just below), so on a grid it is the snap grid made
   * visible -- which is what the 0177 reporter saw hopping over the waveform
   * legend. It is also a schematic pointer aid on a surface that has no
   * schematic geometry.
   * ⚠ THE TEST BELONGS HERE, NOT IN THE CALLERS. draw() itself ends with
   * `if(tclgetboolvar("draw_crosshair")) draw_crosshair(7, 0);` (draw.c ~8433),
   * and move.c has three more such sites -- none of them consults callback()'s
   * `draw_xhair` local. Gating only the local would suppress every ERASE path
   * while leaving those PAINT paths live: a crosshair stroked on the waveform at
   * each full redraw that then never moves and never clears, not even on Leave.
   * (Measured as a regression against the first cut of this fix.) The callers'
   * locals are also computed before handle_window_switching() may reassign xctx,
   * so they can describe the wrong context; a test here is evaluated at call
   * time on the right one. */
  if(xctx->no_snap) return;
  mx = xctx->mousex_snap;
  my = xctx->mousey_snap;
  if( ( (xctx->ui_state & (MENUSTART | STARTWIRE) ) || xctx->ui_state == 0 ) &&
        (state == ShiftMask)) {
    if(!snap_cursor) {
      /* mouse not changed so closest net or symbol pin unchanged too */
      if(mx == xctx->prev_m_crossx && my == xctx->prev_m_crossy) {
        mx = xctx->prev_crossx; /* get previous one */
        my = xctx->prev_crossy;
      } else {
        /* mouse position changed, so find new closest net or pin */
        find_closest_net_or_symbol_pin(xctx->mousex_snap, xctx->mousey_snap, &mx, &my);
        changed = 1; /* we force a cursor redraw */
        dbg(1, "find\n");
      }
    } else {
      /* draw_snap_cursor(what); */
    }
  }

  /* no changed closest pin/net, no force, mx,my is not changed. --> do nothing
         |             _____________|                |
         |            |         _____________________|____________________________ */
  if(!changed && !(what & 4) && mx == xctx->prev_crossx && my == xctx->prev_crossy) {
    return;
  }
  dbg(1, "draw %d\n", what);
  xctx->draw_pixmap = 0;
  xctx->draw_window = 1;
  if(what & 1) { /* delete previous */
    if(fix_broken_tiled_fill || !_unix) {
      erase_crosshair(xhair_size);
    } else {
      draw_crosshair_shape(xctx->gctiled, xctx->prev_crossx, xctx->prev_crossy, xhair_size);
    }
  }
  if(what & 2) { /* draw new */
    draw_crosshair_shape(xctx->gc[xctx->crosshair_layer], mx, my, xhair_size);
  }
  if(what) draw_selection(xctx->gc[SELLAYER], 0);

  if(what & 2) {
    /* previous closest pin or net position (if snap wire or Shift pressed) */
    xctx->prev_crossx = mx;
    xctx->prev_crossy = my;
    /* previous mouse_snap position */
    xctx->prev_m_crossx = xctx->mousex_snap;
    xctx->prev_m_crossy = xctx->mousey_snap;
  }
  xctx->draw_window = sdw;
  xctx->draw_pixmap = sdp;
}

/* Hover (awareness) highlight: outline the object under the tracking cursor with
 * a mild dashed line (xctx->gc_hover). WINDOW-ONLY, exactly like draw_crosshair():
 * the outline never enters save_pixmap, so it is erased by re-stamping the
 * background pixmap (xctx->gctiled) over the previously-outlined shape and then
 * re-stroking the selection + scope overlays it may have covered (they are
 * window-only too). Suppressed while busy (semaphore>=2), mid-gesture
 * (ui_state!=0), when disabled (hover_highlight) or the pointer is outside the
 * canvas (!mouse_inside) — in all those cases the previous outline is erased and
 * none is drawn. <force> redraws even if the hovered object is unchanged (used to
 * re-establish the outline after a full redraw). Focus-independent: it runs on
 * MotionNotify, which X11 delivers to the window under the pointer regardless of
 * keyboard focus. See doc/claude/code_analysis/hover_highlight_decision.md. */

/* Is the object (type, n, layer c) currently selected? Used to suppress the
 * hover outline on an already-selected object — the dashed-yellow cue and the
 * selection highlight would otherwise fight on the same shape. */
static int hover_obj_selected(int type, int n, int c)
{
  switch(type) {
    case ELEMENT: return n >= 0 && n < xctx->instances && xctx->inst[n].sel == SELECTED;
    case WIRE:    return n >= 0 && n < xctx->wires     && xctx->wire[n].sel == SELECTED;
    case xTEXT:   return n >= 0 && n < xctx->texts     && xctx->text[n].sel == SELECTED;
    case xRECT:   return c >= 0 && c < cadlayers && n >= 0 && n < xctx->rects[c]    && xctx->rect[c][n].sel == SELECTED;
    case LINE:    return c >= 0 && c < cadlayers && n >= 0 && n < xctx->lines[c]    && xctx->line[c][n].sel == SELECTED;
    case POLYGON: return c >= 0 && c < cadlayers && n >= 0 && n < xctx->polygons[c] && xctx->poly[c][n].sel == SELECTED;
    case ARC:     return c >= 0 && c < cadlayers && n >= 0 && n < xctx->arcs[c]     && xctx->arc[c][n].sel == SELECTED;
    default: return 0;
  }
}

void draw_hover(int force)
{
  int sdw = xctx->draw_window, sdp = xctx->draw_pixmap;
  int prev_type = xctx->hover_type;
  Selected newsel;

  if(!has_x) return;
  /* SELECTION and the interactive net-(un)highlight pick modes (NET_HILIGHT/NET_UNHILIGHT,
   * the verb-noun "press 9/8 then click a net" states) are RESTING ui_state bits, not
   * transient gestures, so they must NOT suppress the hover cue — during a pick mode the
   * hover outline is exactly what tells the user which net/label they are about to click.
   * Mask them off before the idle check; the remaining bits (STARTMOVE, STARTWIRE, panning,
   * ...) still gate it, so a real gesture started mid-pick still suppresses hover. */
  if(tclgetboolvar("hover_highlight") && xctx->mouse_inside &&
     (xctx->ui_state & ~(SELECTION | NET_HILIGHT | NET_UNHILIGHT)) == 0 && xctx->semaphore < 2) {
    newsel = find_closest_obj(xctx->mousex, xctx->mousey, 0);
    /* don't outline an object that is already selected (overlays would fight) */
    if(newsel.type && hover_obj_selected(newsel.type, (int)newsel.n, newsel.col)) {
      newsel.type = 0; newsel.n = 0; newsel.col = 0;
    }
  } else {
    newsel.type = 0; newsel.n = 0; newsel.col = 0;
  }
  /* unchanged hovered object -> nothing to do */
  if(!force && newsel.type == prev_type &&
     (int)newsel.n == xctx->hover_n && newsel.col == xctx->hover_col) return;

  xctx->draw_pixmap = 0;
  xctx->draw_window = 1;
  if(prev_type) { /* erase the previous outline, then repair selection/scope overlays */
    /* draw_selection() repaints from sel_array/lastsel (it is the move-time drawer);
     * on the motion/hover path that snapshot can be stale (lastsel==0) while objects
     * are still selected by their .sel flag. Without this rebuild the repair would be
     * a no-op, so the erase below (which, with fix_broken_tiled_fill, restores a whole
     * bounding box from the backing pixmap and thus wipes the window-only selection
     * overlay) would leave selected objects looking deselected. See issue 0011. */
    rebuild_selected_array();
    draw_hover_shape(xctx->gctiled, prev_type, xctx->hover_n, xctx->hover_col);
    draw_selection(xctx->gc[SELLAYER], 0);
    draw_scope_highlight();
  }
  if(newsel.type) draw_hover_shape(xctx->gc_hover, newsel.type, (int)newsel.n, newsel.col);
  xctx->hover_type = newsel.type;
  xctx->hover_n = (int)newsel.n;
  xctx->hover_col = newsel.col;

  xctx->draw_window = sdw;
  xctx->draw_pixmap = sdp;
}

/* Stroke the currently-tracked fly-line star (xctx->fly_seg) window-only through gc_flyline.
 * Shared by draw_flylines() (draw the freshly-computed star) and the draw() re-stamp (re-establish
 * the overlay after a full redraw wipes the window). No recompute -- it replays stored world-coord
 * segments, which drawtempline maps through the current zoom/pan. Read-only (invariant C1). */
void flyline_restamp(void)
{
  int i, sdw, sdp;
  if(!has_x || xctx->fly_nseg <= 0 || !xctx->fly_seg) return;
  if(!tclgetboolvar("flylines")) return;   /* disabled mid-show: a redraw must not re-stamp it */
  sdw = xctx->draw_window; sdp = xctx->draw_pixmap;
  xctx->draw_pixmap = 0; xctx->draw_window = 1;   /* window-only frame */
  for(i = 0; i < xctx->fly_nseg; ++i)
    drawtempline(xctx->gc_flyline, ADD, xctx->fly_seg[4 * i], xctx->fly_seg[4 * i + 1],
                 xctx->fly_seg[4 * i + 2], xctx->fly_seg[4 * i + 3]);
  drawtempline(xctx->gc_flyline, END, 0.0, 0.0, 0.0, 0.0);
  xctx->draw_window = sdw; xctx->draw_pixmap = sdp;
}

/* Erase the drawn fly-line star by repainting its world bbox from the backing pixmap -- the
 * regional-draw() idiom of draw_hilight_region() (hilight.c). The CALLER must clear fly_nseg /
 * fly_shown_net first, so the draw() re-stamp hook sees an empty overlay and does not immediately
 * re-stroke what we are erasing. Read-only w.r.t. schematic content (C1). */
static void flyline_erase_region(double x1, double y1, double x2, double y2)
{
  double marg;
  if(!has_x || !xctx->save_pixmap) return;
  marg = xctx->cadhalfdotsize + 4.0 / xctx->mooz;   /* cover line width + dash + endpoint dots */
  bbox(START, 0.0, 0.0, 0.0, 0.0);
  bbox(ADD, x1 - marg, y1 - marg, x2 + marg, y2 + marg);
  bbox(SET, 0.0, 0.0, 0.0, 0.0);
  draw();
  bbox(END, 0.0, 0.0, 0.0, 0.0);
}

/* Forget the tracked fly-line star, erasing its pixels when the caller asks (a regional redraw
 * over the old bbox). Order matters: state is cleared BEFORE the erase-draw() so the re-stamp
 * hook does not redraw the very star we are erasing. */
static void flyline_clear(int erase)
{
  double ox1 = xctx->fly_x1, oy1 = xctx->fly_y1, ox2 = xctx->fly_x2, oy2 = xctx->fly_y2;
  int had = xctx->fly_nseg > 0;
  xctx->fly_nseg = 0;
  xctx->fly_hub_nmem = 0;   /* no star -> no hub cluster to slide within */
  if(xctx->fly_shown_net) my_free(_ALLOC_ID_, &xctx->fly_shown_net);
  if(erase && had) flyline_erase_region(ox1, oy1, ox2, oy2);
}

/* Map a picked object to its FlyMember key {kind, idx, pin} and test membership in the cached
 * hub cluster (fly_hub_mem). O(hub size), no re-clustering. Lets same-net motion that crosses
 * between objects of the SAME hub cluster (a wire junction, a wire->its pin) stay on the cheap
 * slide path instead of triggering a full recompute (H2 refinement, review of d1f3624c). */
static int flyline_pick_in_hub_cluster(const Selected *pick)
{
  int kind, idx, pin, i;
  if(xctx->fly_hub_nmem <= 0 || !xctx->fly_hub_mem) return 0;
  if(pick->type == WIRE)          { kind = 0; idx = pick->n; pin = -1; }
  else if(pick->type == INST_PIN) { kind = 1; idx = pick->n; pin = (int)pick->col; }
  else if(pick->type == ELEMENT)  { kind = 1; idx = pick->n; pin = 0; }   /* label/pin: pin 0 */
  else return 0;
  for(i = 0; i < xctx->fly_hub_nmem; ++i) {
    const int *k = &xctx->fly_hub_mem[3 * i];
    if(k[0] == kind && k[1] == idx && k[2] == pin) return 1;
  }
  return 0;
}

/* H2 cheap path: slide the tracked star's ORIGIN to (hx,hy) without re-clustering. The
 * destinations already live in fly_seg[4*i+2..3]; only the per-segment origin + bbox change.
 * Same net + same hub object, so fly_shown_net stays. Mirrors the net-change erase/redraw order
 * (flyline.c/draw() re-stamp trap): zero fly_nseg BEFORE the erase-draw() so the re-stamp hook
 * does not redraw the OLD star, then rebuild + re-stroke the NEW origins. Read-only (C1). */
static void flyline_move_origin(double hx, double hy)
{
  double ox1 = xctx->fly_x1, oy1 = xctx->fly_y1, ox2 = xctx->fly_x2, oy2 = xctx->fly_y2;
  double x1, y1, x2, y2;
  int i, n = xctx->fly_nseg;
  if(n <= 0 || !xctx->fly_seg) return;
  if(hx == xctx->fly_seg[0] && hy == xctx->fly_seg[1]) return;   /* origin unchanged: no redraw */
  xctx->fly_nseg = 0;                          /* the erase-draw() must not re-stamp the old star */
  flyline_erase_region(ox1, oy1, ox2, oy2);
  x1 = x2 = hx; y1 = y2 = hy;
  for(i = 0; i < n; ++i) {
    double dx = xctx->fly_seg[4 * i + 2], dy = xctx->fly_seg[4 * i + 3];
    xctx->fly_seg[4 * i] = hx; xctx->fly_seg[4 * i + 1] = hy;   /* move origin, keep destination */
    if(dx < x1) x1 = dx; if(dx > x2) x2 = dx;
    if(dy < y1) y1 = dy; if(dy > y2) y2 = dy;
  }
  xctx->fly_nseg = n;
  xctx->fly_x1 = x1; xctx->fly_y1 = y1; xctx->fly_x2 = x2; xctx->fly_y2 = y2;
  flyline_restamp();                           /* stroke the star from its new origin */
}

/* Hover fly-line overlay (doc/claude/specs/hover_flylines.md, Track B). Draw the implicit-
 * connectivity "star" for the net under the cursor: thin dashed lines (gc_flyline) from the
 * hovered cluster to every other cluster of the same net that is joined only by name (no drawn
 * wire between them). Rides the same motion pump as draw_hover() but is independent of
 * hover_highlight (spec §3.1) and gated by its own `flylines` var.
 *
 * INVARIANT C1: pure read-only overlay. All connectivity comes from flyline_compute()
 * (flyline.c), which never mutates schematic state; here we only stroke the window (via
 * drawtempline / a regional erase draw()) and update the transient fly_* fields -- nothing
 * touches hilight_table / inst.color / .sel / the modified flag / saved bytes.
 *
 * B2: compute + draw + track fly_shown_net. B3: erase the previous star on a net change / leave
 * (regional draw() over the old bbox) and re-stamp after pan/zoom/full-redraw (draw() hook +
 * the retained xctx->fly_seg). */
void draw_flylines(int force)
{
  const char *netname = NULL;
  Selected pick;

  if(!has_x) return;
  if(!tclgetboolvar("flylines")) {
    flyline_clear(1);                              /* feature off: erase any lingering star */
    my_strdup(_ALLOC_ID_, &xctx->fly_last_net, NULL);
    return;
  }
  /* Mid-gesture (a drag/wire/... owns the screen): leave the overlay untouched. A regional erase
   * draw() here would fight the rubber-band redraw drawn earlier in the same frame (one-frame
   * tear). The star refreshes when idle motion resumes -- and any edit clears prep_hi_structs,
   * forcing a correct recompute then. The masked bits (SELECTION / net-pick modes) are resting
   * states, not gestures, so they do not trigger this. */
  if(xctx->mouse_inside &&
     (xctx->ui_state & ~(SELECTION | NET_HILIGHT | NET_UNHILIGHT)) != 0) return;
  if(xctx->semaphore >= 2) return;
  if(xctx->mouse_inside) {
    /* If prep_hi_structs is clear, an edit has invalidated wire[].node/clustering since the star
     * was last drawn (check.c/paste.c/... reset it): force a recompute even when the net NAME is
     * unchanged, else a same-name-but-restructured net would keep a stale star (spec §5.4/§6.3). */
    if(!xctx->prep_hi_structs) force = 1;
    prepare_netlist_structs(0);           /* rebuilds wire[].node / inst[].node iff stale */
    pick = find_closest_obj(xctx->mousex, xctx->mousey, 0);
    netname = flyline_net_of(pick.type, pick.n, pick.col);
    if(netname && netname[0] == '#') netname = NULL;   /* A6: auto-named nets never fly */
  }
  /* else: pointer off-canvas (leave) -> netname stays NULL -> erase + clear below. */
  /* change detection against the last RESOLVED net (not just the drawn one): a starless net --
   * e.g. a fully-wired single-cluster net, the common case -- also short-circuits, so repeated
   * motion over it does not re-run the full member scan. Turns same-net motion into O(1).
   *
   * H2: when the net is unchanged AND a star is on screen AND the cursor is still over the SAME
   * hub object, slide the origin under the cursor (flyline_move_origin) instead of short-circuiting
   * -- a wire hub then tracks the pointer. This recomputes ONLY the hub point + rebuilds fly_seg
   * from the cached destinations; NO re-cluster (the review fixed the full-rescan cost). Moving to
   * a different object of the same net (hub-cluster change) falls through to a full recompute. */
  if(!force) {
    const char *cur = xctx->fly_last_net ? xctx->fly_last_net : "";
    const char *nw  = netname ? netname : "";
    if(!strcmp(cur, nw)) {
      if(netname && xctx->fly_nseg > 0 && flyline_pick_in_hub_cluster(&pick)) {
        double hx, hy;
        flyline_hub_point(&pick, xctx->mousex, xctx->mousey, &hx, &hy);
        flyline_move_origin(hx, hy);           /* no-op when the projected origin is unchanged */
        return;
      }
      if(!(netname && xctx->fly_nseg > 0)) return;   /* starless same-net motion: O(1) short-circuit */
      /* else: same net but a DIFFERENT hub cluster -> fall through to a full recompute */
    }
  }
  my_strdup(_ALLOC_ID_, &xctx->fly_last_net, netname);   /* NULL -> frees to NULL */
  /* net changed (possibly to nothing): erase the old star, then draw the new one (if any). */
  flyline_clear(1);
  if(!netname) return;   /* moved to empty / off-canvas: erased, nothing to draw */
  {
    FlyResult res;
    /* hub = hovered cluster; origin = the point on the hovered object under the pointer */
    flyline_compute(netname, 1, &pick, xctx->mousex, xctx->mousey, &res);
    if(res.nseg > 0) {
      int i;
      double x1 = res.sx1[0], y1 = res.sy1[0], x2 = res.sx1[0], y2 = res.sy1[0];
      if(res.nseg * 4 > xctx->fly_seg_alloc) {   /* grow the retained segment buffer */
        xctx->fly_seg_alloc = res.nseg * 4;
        my_realloc(_ALLOC_ID_, &xctx->fly_seg, xctx->fly_seg_alloc * sizeof(double));
      }
      for(i = 0; i < res.nseg; ++i) {
        xctx->fly_seg[4 * i]     = res.sx1[i]; xctx->fly_seg[4 * i + 1] = res.sy1[i];
        xctx->fly_seg[4 * i + 2] = res.sx2[i]; xctx->fly_seg[4 * i + 3] = res.sy2[i];
        if(res.sx1[i] < x1) x1 = res.sx1[i]; if(res.sx1[i] > x2) x2 = res.sx1[i];
        if(res.sx2[i] < x1) x1 = res.sx2[i]; if(res.sx2[i] > x2) x2 = res.sx2[i];
        if(res.sy1[i] < y1) y1 = res.sy1[i]; if(res.sy1[i] > y2) y2 = res.sy1[i];
        if(res.sy2[i] < y1) y1 = res.sy2[i]; if(res.sy2[i] > y2) y2 = res.sy2[i];
      }
      xctx->fly_nseg = res.nseg;
      xctx->fly_x1 = x1; xctx->fly_y1 = y1; xctx->fly_x2 = x2; xctx->fly_y2 = y2;
      /* cache the hub CLUSTER's member keys so subsequent same-cluster motion slides the origin
       * without re-clustering (H2); res is still live here (freed below). */
      xctx->fly_hub_nmem = 0;
      {
        int a;
        for(a = 0; a < res.nmem; ++a) {
          if(res.clu[a] != res.hub) continue;
          if(3 * (xctx->fly_hub_nmem + 1) > xctx->fly_hub_mem_alloc) {
            xctx->fly_hub_mem_alloc = xctx->fly_hub_mem_alloc ? xctx->fly_hub_mem_alloc * 2 : 48;
            my_realloc(_ALLOC_ID_, &xctx->fly_hub_mem, xctx->fly_hub_mem_alloc * sizeof(int));
          }
          xctx->fly_hub_mem[3 * xctx->fly_hub_nmem]     = res.mem[a].kind;
          xctx->fly_hub_mem[3 * xctx->fly_hub_nmem + 1] = res.mem[a].idx;
          xctx->fly_hub_mem[3 * xctx->fly_hub_nmem + 2] = res.mem[a].pin;
          ++xctx->fly_hub_nmem;
        }
      }
      my_strdup(_ALLOC_ID_, &xctx->fly_shown_net, netname);
      flyline_restamp();                          /* stroke the freshly-stashed star */
    }
    flyline_result_free(&res);
  }
}

static void unselect_at_mouse_pos(int mx, int my)
{
       xctx->last_command = 0;
       xctx->mx_save = mx; xctx->my_save = my;
       xctx->mx_double_save=xctx->mousex_snap;
       xctx->my_double_save=xctx->mousey_snap;
       select_object(xctx->mousex, xctx->mousey, 0, 0, NULL);
       rebuild_selected_array(); /* sets or clears xctx->ui_state SELECTION flag */
}

/* Enter the persistent deselect-one-at-a-time mode (doc/claude/specs/deselect_one_mode.md).
 * Shared by the bound key (act_deselect_mode) and the `xschem deselect_mode` subcommand.
 * Modelled on the net-(un)highlight pick modes: a resting ui_state bit, exited by ESC.
 * Gated on a non-empty selection (the mode only makes sense when there is something to
 * deselect): with nothing selected it is a no-op with a hint, matching the spec's
 * "if there are objects selected, ... goes into deselect mode". Non-mutating, so it is
 * allowed in a read-only view (deselecting changes no schematic content). */
void enter_deselect_mode(void)
{
  rebuild_selected_array();
  if(xctx->lastsel <= 0) {
    if(has_x)
      tcleval("if {[info procs ciw_echo] ne {}} {ciw_echo {Deselect mode: nothing is selected.}}");
    return;
  }
  xctx->ui_state |= DESEL_MODE;
  if(has_x) {
    tclvareval(xctx->top_path, ".statusbar.10 configure -state active -text {",
      "DESELECT! (click a selected object to deselect it, ESC to end) }", NULL);
    tcleval("if {[info procs ciw_echo] ne {}} {ciw_echo "
            "{Deselect mode: click a selected object to remove it from the selection; press ESC to end.}}");
  }
}

/* One click while in deselect-one-at-a-time mode: deselect the object under the cursor
 * if it is selected, and STAY in the mode (preserve the bit). unselect_at_mouse_pos()
 * uses select_object(..., select_mode=0, ...), which deselects the hit object and can
 * never select one, so a click on an unselected object or on empty space is a no-op.
 * Save/restore the mode bit like net_hilight_mode_click(), in case the selection-array
 * path clears ui_state. */
static void deselect_mode_click(int mx, int my)
{
  unsigned int mode = xctx->ui_state & DESEL_MODE;
  /* D7 (pin_selection.md §3.2): if a SELECTED pin is under the cursor, deselect just
   * that pin (leave other selected pins/objects intact), mirroring the select-side pin
   * priority. Otherwise fall through to the object deselect. Gated on en_pin_select
   * (GLOBAL Tcl var, not the per-context field). Inert -> read-only safe. */
  if(tclgetboolvar("en_pin_select")) {
    Selected psel;
    if(find_closest_pin(xctx->mousex, xctx->mousey, &psel)) {
      int i = (int)psel.n, j = (int)psel.col;
      if(xctx->inst[i].pin_sel && j < xctx->inst[i].pin_sel_size && xctx->inst[i].pin_sel[j]) {
        select_pin(i, j, 0, 0);          /* deselect just this pin */
        rebuild_selected_array();
        xctx->ui_state |= mode;
        return;
      }
    }
  }
  unselect_at_mouse_pos(mx, my);
  xctx->ui_state |= mode;
}

static void snapped_wire(double c_snap)
{
  double x, y;
  if(!(xctx->ui_state & STARTWIRE)){
    find_closest_net_or_symbol_pin(xctx->mousex, xctx->mousey, &x, &y);
    xctx->mx_double_save = my_round(x / c_snap) * c_snap;
    xctx->my_double_save = my_round(y / c_snap) * c_snap;
    /* xctx->manhattan_lines = 1; */
    new_wire(PLACE, x, y);
    new_wire(RUBBER, xctx->mousex_snap,xctx->mousey_snap);
  }
  else {
    find_closest_net_or_symbol_pin(xctx->mousex, xctx->mousey, &x, &y);
    new_wire(RUBBER, x, y);
    new_wire(PLACE|END, x, y);
    xctx->constr_mv=0;
    tcleval("set constr_mv 0" );
    if((xctx->ui_state & MENUSTART) && !tclgetboolvar("persistent_command") ) xctx->ui_state &= ~MENUSTART; /*CD*/
  }
}

static int check_menu_start_commands(int state, double c_snap, int mx, int my)
{
  dbg(1, "check_menu_start_commands(): ui_state=%x, ui_state2=%x last_command=%d\n",
      xctx->ui_state, xctx->ui_state2, xctx->last_command);

  if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTDESEL) ) {
    /* unselect by area (the 'D' / Shift+D area-deselect). The old single-shot 'd'
     * click-deselect path was removed when 'd' became the persistent deselect mode
     * (doc/claude/specs/deselect_one_mode.md). */
    xctx->mx_save = mx; xctx->my_save = my;
    xctx->mx_double_save=xctx->mousex;
    xctx->my_double_save=xctx->mousey;
    xctx->ui_state |= DESEL_AREA;
    return 1;
  }
  if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTDESCEND)) {
    /* verb-noun descend (doc/claude/issues/0200-descend-has-no-verb-noun-pick.md): the
     * descend verb fired with an empty selection armed this, so THIS click names the
     * instance to descend into. Unlike the move/copy/rotate arms below, the click does
     * NOT select what it picks -- the user asked for "information to one command", not a
     * selection change -- so find_closest_instance() (read-only) resolves it and nothing
     * touches .sel / sel_array / the hilight tables.
     * override_lock=1: selection IS the lock (issue 0160), and a pick that never selects
     * cannot make a locked instance editable -- but it must still be descendable.
     * Non-mutating, hence deliberately NOT in the read-only backstop mask below: browsing
     * a read-only schematic must still descend.
     * The chooser dialog is modal (grab + tkwait); opening it from inside this callback
     * would pump a nested event loop and land every later event at semaphore >= 2, so the
     * Tcl continuation defers it to `after idle`. */
    int n;
    xctx->ui_state &= ~MENUSTART;
    xctx->ui_state2 &= ~MENUSTARTDESCEND;
    n = find_closest_instance(xctx->mousex, xctx->mousey, 1);
    if(n >= 0) {
      statusmsg_hold_clear();   /* same as the ESC path: the blank must land (issue 0248) */
      statusmsg(" ", 1);
      tcl_call("hi_descend_pick_done", xctx->inst[n].instname, NULL, NULL);
    } else { /* clicked empty space or a non-instance: cancel the armed descend cleanly */
      statusmsg_hold("Descend: cancelled (no instance there)", 1);
      tcleval("hi_descend_pick_cancel");
    }
    return 1;
  }
  /* read-only backstop: any armed object-mutating command is refused here (the
   * keyboard/context-menu sites already guard at arming time; this catches any
   * other MENUSTART path). DESEL/ZOOM above are non-mutating and pass through. */
  if((xctx->ui_state & MENUSTART) &&
     (xctx->ui_state2 & (MENUSTARTWIRECUT | MENUSTARTWIRECUT2 | MENUSTARTMOVE | MENUSTARTCOPY |
                         MENUSTARTWIRE | MENUSTARTSNAPWIRE | MENUSTARTLINE | MENUSTARTRECT |
                         MENUSTARTPOLYGON | MENUSTARTARC | MENUSTARTCIRCLE | MENUSTARTROTATE)) &&
     readonly_block()) {
    xctx->ui_state &= ~MENUSTART;
    xctx->ui_state2 = 0;
    xctx->menu_pending_transform = PENDING_TR_NONE;
    return 1;
  }
  if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTWIRECUT)) {
    break_wires_at_point(xctx->mousex_snap, xctx->mousey_snap, 1);
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTWIRECUT2)) {
    break_wires_at_point(xctx->mousex_snap, xctx->mousey_snap, 0);
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTMOVE)) {
    /* verb-noun (cadence_pin_name_text.md copy/move UX): 'm' on an empty selection arms
     * MENUSTARTMOVE, so this click SELECTS the object under the cursor and picks it up in
     * one gesture. With something already selected (Edit>Move menu path) the existing
     * selection is moved and the click is just the pick-up point.
     * MENUSTARTSTRETCH (cadence 'm') additionally grabs attached nets so wires stay
     * connected/reroute — see doc/claude/specs/cadence_stretch_move_keys.md */
    int stretch_move = (xctx->ui_state2 & MENUSTARTSTRETCH) ? 1 : 0;
    rebuild_selected_array();
    if(xctx->lastsel == 0) {
      select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
      rebuild_selected_array();
    }
    if(xctx->lastsel == 0) { /* clicked empty space: cancel the armed move cleanly */
      xctx->ui_state &= ~MENUSTART;
      xctx->ui_state2 = 0;
      return 1;
    }
    xctx->mx_double_save=xctx->mousex_snap;
    xctx->my_double_save=xctx->mousey_snap;
    if(stretch_move) { /* connected: kissing armed before select_attached_nets (through-run tap skip) */
      xctx->connect_by_kissing = 2;
      select_attached_nets();
    }
    move_objects(START,0,0,0);
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTCOPY)) {
    /* verb-noun mirror of MENUSTARTMOVE: 'c' on an empty selection selects the object
     * under this click and starts the copy in one gesture (see comment above). */
    rebuild_selected_array();
    if(xctx->lastsel == 0) {
      select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
      rebuild_selected_array();
    }
    xctx->mx_double_save=xctx->mousex_snap;
    xctx->my_double_save=xctx->mousey_snap;
    copy_objects(START);
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTROTATE)) {
    /* verb-noun prompt-for-object rotate/flip (Cases 1 & 3, rotate_keep_connected_stretch.md):
     * a rotate/flip verb fired with nothing selected armed this; this click SELECTS the object
     * under the cursor and applies the pending transform about the click point, in one shot.
     * PLAIN transform -- no select_attached_nets(), so wires are NOT kept connected (Case 3
     * deliberately abandoned any pending stretch). Unlike move/copy this is instantaneous, so
     * it clears MENUSTART itself (the caller only clears MENUSTART for the fall-through click). */
    int t = xctx->menu_pending_transform;
    rebuild_selected_array();
    if(xctx->lastsel == 0) {
      select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
      rebuild_selected_array();
    }
    if(xctx->lastsel == 0) { /* clicked empty space: cancel the armed rotate cleanly */
      xctx->ui_state &= ~MENUSTART;
      xctx->ui_state2 = 0;
      xctx->menu_pending_transform = PENDING_TR_NONE;
      return 1;
    }
    xctx->mx_double_save = xctx->mousex_snap;
    xctx->my_double_save = xctx->mousey_snap;
    if(t == PENDING_TR_ROTATE_IP) {
      /* rotate_in_place standalone (verb-noun deferred apply): route through the mutation
       * boundary (Refactor B atom 3), which owns readonly + the ONE `xschem rotate_in_place`
       * log site + its own rebuild+START+ROTATE|ROTATELOCAL+END effect. It must NOT be nested
       * inside the shared move_objects(START/END) the other transform cases use -- that would
       * double the START/END. readonly was already refused at the MENUSTART backstop above. */
      perform_action("rotate_in_place", 0, NULL);
    } else if(t == PENDING_TR_FLIP_IP) {
      /* flip_in_place standalone (verb-noun deferred apply): same shape as rotate_in_place,
       * routed through the boundary (Refactor B atom 4). perform_action->run_core owns its own
       * rebuild+START+FLIP|ROTATELOCAL+END, so it must NOT nest inside the shared START/END below. */
      perform_action("flip_in_place", 0, NULL);
    } else if(t == PENDING_TR_FLIPV_IP) {
      /* flipv_in_place standalone (verb-noun deferred apply): routed through the boundary
       * (Refactor B atom 5). perform_action->run_core owns its own rebuild+START+ROTATE|
       * ROTATELOCAL x2 + FLIP|ROTATELOCAL + END (a net vertical mirror), so it must NOT nest
       * inside the shared START/END below. */
      perform_action("flipv_in_place", 0, NULL);
    } else if(t == PENDING_TR_ROTATE) {
      /* PENDING_TR_ROTATE pivot verb (verb-noun deferred apply): the deferred PIVOT rotate crosses
       * the boundary like the _IP cases above, but carries the click-point pivot (mx/my_double_save,
       * seeded just above from mousex/y_snap). PULLED OUT of the shared move_objects(START) … switch
       * … move_objects(END) block below (Refactor B atom 6): perform_action->run_core owns its own
       * rebuild+seed-pivot+START+ROTATE+END and must NOT nest inside the outer START/END. run_core
       * re-seeds mx/my_double_save = mousex/y_snap from the argv pivot, so the effect is unchanged.
       * The flip/flipv PIVOT cases followed in atoms 7/8 -- all six arms now cross the boundary. */
      char sx[64], sy[64]; const char *av[4];
      my_snprintf(sx, S(sx), "%.16g", xctx->mx_double_save);
      my_snprintf(sy, S(sy), "%.16g", xctx->my_double_save);
      av[0] = "xschem"; av[1] = "rotate"; av[2] = sx; av[3] = sy;
      perform_action("rotate", 4, av);
    } else if(t == PENDING_TR_FLIP) {
      /* PENDING_TR_FLIP pivot verb (verb-noun deferred apply): the deferred PIVOT flip crosses the
       * boundary like PENDING_TR_ROTATE above, carrying the click-point pivot (mx/my_double_save,
       * seeded just above from mousex/y_snap). PULLED OUT of the shared move_objects(START) … switch
       * … move_objects(END) block below (Refactor B atom 7): perform_action->run_core owns its own
       * rebuild+seed-pivot+START+FLIP+END and must NOT nest inside the outer START/END. run_core
       * re-seeds mx/my_double_save = mousex/y_snap from the argv pivot, so the effect is unchanged.
       * The flipv PIVOT case followed in atom 8 (its own else-if arm just below). */
      char sx[64], sy[64]; const char *av[4];
      my_snprintf(sx, S(sx), "%.16g", xctx->mx_double_save);
      my_snprintf(sy, S(sy), "%.16g", xctx->my_double_save);
      av[0] = "xschem"; av[1] = "flip"; av[2] = sx; av[3] = sy;
      perform_action("flip", 4, av);
    } else if(t == PENDING_TR_FLIPV) {
      /* PENDING_TR_FLIPV pivot verb (verb-noun deferred apply): the deferred PIVOT flipv crosses the
       * boundary like PENDING_TR_FLIP above, carrying the click-point pivot (mx/my_double_save, seeded
       * just above from mousex/y_snap). PULLED OUT of the (now removed) shared move_objects(START) …
       * switch … move_objects(END) block (Refactor B atom 8, the LAST pivot form): perform_action->
       * run_core owns its own rebuild+seed-pivot+START+ROTATE+ROTATE+FLIP+END (net vertical mirror)
       * and must NOT nest inside an outer START/END. run_core re-seeds mx/my_double_save = mousex/
       * y_snap from the argv pivot, so the effect is unchanged. With this pull the shared block is
       * EMPTY and removed -- the whole verb-noun transform chain is now six boundary arms, one
       * perform_action each. An unexpected t simply no-ops off the end of the chain (which is armed
       * only for the six PENDING_TR_* transform values -- no spurious default re-added). */
      char sx[64], sy[64]; const char *av[4];
      my_snprintf(sx, S(sx), "%.16g", xctx->mx_double_save);
      my_snprintf(sy, S(sy), "%.16g", xctx->my_double_save);
      av[0] = "xschem"; av[1] = "flipv"; av[2] = sx; av[3] = sy;
      perform_action("flipv", 4, av);
    }
    xctx->ui_state &= ~MENUSTART;
    xctx->ui_state2 = 0;
    xctx->menu_pending_transform = PENDING_TR_NONE;
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTWIRE)) {
    int prev_state = xctx->ui_state;
    if(xctx->semaphore >= 2) return 0;
    if( state & ShiftMask) {
      snapped_wire(c_snap);
    } else {
      start_wire(xctx->mousex_snap, xctx->mousey_snap);
      if(prev_state == STARTWIRE) {
        tcleval("set constr_mv 0" );
        xctx->constr_mv=0;
      }
    }

    /*
     * xctx->mx_double_save=xctx->mousex_snap;
     * xctx->my_double_save=xctx->mousey_snap;
     * new_wire(PLACE, xctx->mousex_snap, xctx->mousey_snap);
     * xctx->ui_state &=~MENUSTART;
     */
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTSNAPWIRE)) {
    snapped_wire(c_snap);
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTLINE)) {
    int prev_state = xctx->ui_state;
    if(xctx->semaphore >= 2) return 0;
    start_line(xctx->mousex_snap, xctx->mousey_snap);
    if(prev_state == STARTLINE) {
      tcleval("set constr_mv 0" );
      xctx->constr_mv=0;
    }

    /*
     * xctx->mx_double_save=xctx->mousex_snap;
     * xctx->my_double_save=xctx->mousey_snap;
     * new_line(PLACE, xctx->mousex_snap, xctx->mousey_snap);
     * xctx->ui_state &=~MENUSTART;
     */
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTRECT)) {
    xctx->mx_double_save=xctx->mousex_snap;
    xctx->my_double_save=xctx->mousey_snap;
    new_rect(PLACE,xctx->mousex_snap, xctx->mousey_snap);
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTPOLYGON)) {
    xctx->mx_double_save=xctx->mousex_snap;
    xctx->my_double_save=xctx->mousey_snap;
    new_polygon(PLACE, xctx->mousex_snap, xctx->mousey_snap);
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTARC)) {
    xctx->mx_double_save=xctx->mousex_snap;
    xctx->my_double_save=xctx->mousey_snap;
    new_arc(PLACE, 180., xctx->mousex_snap, xctx->mousey_snap);
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTCIRCLE)) {
    xctx->mx_double_save=xctx->mousex_snap;
    xctx->my_double_save=xctx->mousey_snap;
    new_arc(PLACE, 360., xctx->mousex_snap, xctx->mousey_snap);
    return 1;
  }
  else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTZOOM)) {
    zoom_rectangle(START);
    return 1;
  }
  return 0;
}

static int add_wire_from_inst(Selected *sel, double mx, double my)
{
  int res = 0;
  int prev_state = xctx->ui_state;
  int i, type = sel->type;
  double pinx0, piny0;
  if(type == ELEMENT) {
    int n = sel->n;
    xSymbol *symbol = xctx->sym + xctx->inst[n].ptr;
    int npin = symbol->rects[PINLAYER];
    for(i = 0; i < npin; ++i) {
      get_inst_pin_coord(n, i, &pinx0, &piny0);
      if(pinx0 == mx && piny0 == my) {
        break;
      }
    }
    if(i < npin) {
      dbg(1, "pin: %g %g\n", pinx0, piny0);
      unselect_all(1);
      start_wire(xctx->mousex_snap, xctx->mousey_snap);
      if(prev_state == STARTWIRE) {
        tcleval("set constr_mv 0" );
        xctx->constr_mv=0;
      }
      res = 1;
    }
  }
  return res;
}

static int add_wire_from_wire(Selected *sel, double mx, double my)
{
  int res = 0;
  int prev_state = xctx->ui_state;
  int type = sel->type;
  if(type == WIRE) {
    int n = sel->n;
    double x1 = xctx->wire[n].x1;
    double y1 = xctx->wire[n].y1;
    double x2 = xctx->wire[n].x2;
    double y2 = xctx->wire[n].y2;
    dbg(1, "add_wire_from_wire\n");
    if( (mx == x1 && my == y1) || (mx == x2 && my == y2) ) {
      unselect_all(1);
      start_wire(xctx->mousex_snap, xctx->mousey_snap);
      if(prev_state == STARTWIRE) {
        tcleval("set constr_mv 0" );
        xctx->constr_mv=0;
      }
      res = 1;
    }
  }
  return res;
}

/* sets xctx->shape_point_selected */
static int edit_line_point(int state)
{
   int line_n = -1, line_c = -1;
   dbg(1, "1 Line selected\n");
   /* Fluid editing: a modifier-held press is a Cadence copy (Shift) / detach (Ctrl)
    * gesture, not a stretch. Bail BEFORE setting shape_point_selected so the press falls
    * through cleanly to the whole-object modifier-drag path (which is gated on
    * !shape_point_selected); otherwise the flag stays stuck and the copy/detach silently
    * no-ops with a spurious commit on release. */
   if(state & (ControlMask | ShiftMask)) return 0;
   line_n = xctx->sel_array[0].n;
   line_c = xctx->sel_array[0].col;
  /* lineangle point: Check is user is clicking a control point of a lineangle */
  if(line_n >= 0) {
    double ds = xctx->cadhalfdotsize * 2 * xctx->zoom;
    xLine *p = &xctx->line[line_c][line_n];

    xctx->need_reb_sel_arr=1;
    /* C4: a cadhalfdotsize tolerance zone around each endpoint (was an exact snap-match),
     * matching rect corners / arc endpoints for a forgiving, consistent grab. */
    if(POINTINSIDE(xctx->mousex, xctx->mousey, p->x1 - ds, p->y1 - ds, p->x1 + ds, p->y1 + ds)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED1;
    }
    else if(POINTINSIDE(xctx->mousex, xctx->mousey, p->x2 - ds, p->y2 - ds, p->x2 + ds, p->y2 + ds)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED2;
    }
    if(xctx->shape_point_selected) {
      /* move one line selected point (undo push owned by move_objects START) */
      move_objects(START,0,0,0);
      return 1;
    } /* if(xctx->shape_point_selected) */
  } /* if(line_n >= 0) */
  return 0;
}

/* sets xctx->shape_point_selected */
static int edit_wire_point(int state)
{
   int wire_n = -1;
   dbg(1, "edit_wire_point, ds = %g\n", xctx->cadhalfdotsize);
   /* Fluid editing: modifier-held press = copy/detach gesture, not a stretch (see
    * edit_line_point). Bail before setting shape_point_selected. */
   if(state & (ControlMask | ShiftMask)) return 0;
   wire_n = xctx->sel_array[0].n;
  /* wire point: Check is user is clicking a control point of a wire */
  if(wire_n >= 0) {
    double ds = xctx->cadhalfdotsize * 2 * xctx->zoom;
    xWire *p = &xctx->wire[wire_n];

    xctx->need_reb_sel_arr=1;
    /* C4: tolerance zone around each endpoint (was exact snap-match). Free/connected wire
     * endpoints are still consumed earlier by grab_free_wire_vertex / add_wire_from_wire;
     * this forgiving zone applies when the wire reaches edit_wire_point (already selected,
     * or a near-endpoint click that missed those paths). */
    if(POINTINSIDE(xctx->mousex, xctx->mousey, p->x1 - ds, p->y1 - ds, p->x1 + ds, p->y1 + ds)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED1;
    }
    else if(POINTINSIDE(xctx->mousex, xctx->mousey, p->x2 - ds, p->y2 - ds, p->x2 + ds, p->y2 + ds)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED2;
    }
    if(xctx->shape_point_selected) {
      /* move one wire selected point (undo push owned by move_objects START) */
      move_objects(START,0,0,0);
      return 1;
    } /* if(xctx->shape_point_selected) */
  } /* if(wire_n >= 0) */
  return 0;
}

/* Issue 0017 — is wire n's endpoint `which` (1 or 2) FREE/dangling, i.e. sitting on no
 * instance pin AND touched by no other wire? Such an end has nothing to "continue", so a
 * press+drag on it should move the end (shorten/grow), not start a new wire. */
static int wire_endpoint_is_free(int n, int which)
{
  double ex = (which == 1) ? xctx->wire[n].x1 : xctx->wire[n].x2;
  double ey = (which == 1) ? xctx->wire[n].y1 : xctx->wire[n].y2;
  int i, r, rects, m;
  double px, py;
  for(i = 0; i < xctx->instances; i++) {
    if(xctx->inst[i].ptr < 0) continue;
    rects = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; r++) {
      get_inst_pin_coord(i, r, &px, &py);
      if(px == ex && py == ey) return 0;            /* on an instance pin */
    }
  }
  for(m = 0; m < xctx->wires; m++) {
    if(m == n) continue;
    if(touch(xctx->wire[m].x1, xctx->wire[m].y1, xctx->wire[m].x2, xctx->wire[m].y2, ex, ey))
      return 0;                                     /* touched by another wire */
  }
  return 1;
}

/* Issue 0017 (cadence fluid editing) — directly grab a FREE wire vertex on press, with no
 * pre-select step. A press exactly on a dangling wire endpoint selects that wire and hands
 * off to edit_wire_point(), which marks the grabbed end and starts move_objects() — so the
 * drag moves the endpoint (toward the other end = shorten, away = grow) and COMMITS ON
 * RELEASE, never entering wire-draw mode (STARTWIRE). Connected endpoints return 0 here and
 * fall through to add_wire_from_wire() (draw a new branch wire) as before. Reuses
 * edit_wire_point so the grabbed-vertex behavior stays identical to the already-selected
 * case. */
static int grab_free_wire_vertex(Selected *sel, double mx, double my, int state)
{
  int n, which = 0;
  if(sel->type != WIRE) return 0;
  n = sel->n;
  if(mx == xctx->wire[n].x1 && my == xctx->wire[n].y1) which = 1;
  else if(mx == xctx->wire[n].x2 && my == xctx->wire[n].y2) which = 2;
  if(!which) return 0;                               /* press not on an endpoint */
  if(!wire_endpoint_is_free(n, which)) return 0;     /* free/dangling ends only */
  unselect_all(1);
  select_object(xctx->mousex, xctx->mousey, SELECTED, 0, sel);
  rebuild_selected_array();
  return edit_wire_point(state); /* sets shape_point_selected + move_objects(START); commit-on-release */
}

/* `fluid` = fluid_editing (C4). Corners grab whenever this editor is reached (the caller
 * already applied the two-step/fluid gate); the side EDGES are fluid-only. sets
 * xctx->shape_point_selected */
static int edit_rect_point(int state, int fluid)
{
   int rect_n = -1, rect_c = -1;
   dbg(1, "1 Rectangle selected\n");
   /* Fluid editing: modifier-held press = Cadence copy/detach gesture, not a stretch
    * (see edit_line_point). Bail before setting shape_point_selected. */
   if(state & (ControlMask | ShiftMask)) return 0;
   rect_n = xctx->sel_array[0].n;
   rect_c = xctx->sel_array[0].col;
  /* rectangle point: Check is user is clicking a control point of a rectangle */
  if(rect_n >= 0) {
    double ds = xctx->cadhalfdotsize * 2 * xctx->zoom;
    xRect *p = &xctx->rect[rect_c][rect_n];

    xctx->need_reb_sel_arr=1;
    if(POINTINSIDE(xctx->mousex, xctx->mousey, p->x1, p->y1, p->x1 + ds, p->y1 + ds)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED1;
    }
    else if(POINTINSIDE(xctx->mousex, xctx->mousey, p->x2 - ds, p->y1, p->x2, p->y1 + ds)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED2;
    }
    else if(POINTINSIDE(xctx->mousex, xctx->mousey, p->x1, p->y2 - ds, p->x1 + ds, p->y2)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED3;
    }
    else if(POINTINSIDE(xctx->mousex, xctx->mousey, p->x2 - ds, p->y2 - ds, p->x2, p->y2)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED4;
    }
    /* Fluid editing (C3, doc/claude/specs/fluid_editing.md): a click near a SIDE (not a
     * corner) grabs that whole edge -- both of its corners -- so the drag stretches the
     * side. The four corner zones are tested first (else-if), so an edge branch only fires
     * away from the corners; each side is a full-span band +/- ds perpendicular to the
     * edge line. The two-corner SELECTED pairs match move.c's edge-stretch commit cases:
     *   top    (y1) -> SELECTED1|SELECTED2   bottom (y2) -> SELECTED3|SELECTED4
     *   left   (x1) -> SELECTED1|SELECTED3   right  (x2) -> SELECTED2|SELECTED4
     * Gated on `fluid` (fluid_editing) so stock behaviour (the two-step, corners only) is
     * unchanged. An edge band is only enabled when the rect is thicker than 2*ds in the
     * perpendicular direction. That keeps the two opposite bands DISJOINT (so the far
     * edge stays grabbable) and always leaves an interior dead zone wider than the two
     * bands, so a body click still falls through to the whole-object move. Without this
     * guard a thin (or zoomed-out) rect has its whole interior covered by the bands and
     * can never be moved, only deformed. */
    else if(fluid && (p->y2 - p->y1) > 2 * ds &&
            POINTINSIDE(xctx->mousex, xctx->mousey, p->x1, p->y1 - ds, p->x2, p->y1 + ds)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED1 | SELECTED2;              /* top edge (y1) */
    }
    else if(fluid && (p->y2 - p->y1) > 2 * ds &&
            POINTINSIDE(xctx->mousex, xctx->mousey, p->x1, p->y2 - ds, p->x2, p->y2 + ds)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED3 | SELECTED4;              /* bottom edge (y2) */
    }
    else if(fluid && (p->x2 - p->x1) > 2 * ds &&
            POINTINSIDE(xctx->mousex, xctx->mousey, p->x1 - ds, p->y1, p->x1 + ds, p->y2)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED1 | SELECTED3;              /* left edge (x1) */
    }
    else if(fluid && (p->x2 - p->x1) > 2 * ds &&
            POINTINSIDE(xctx->mousex, xctx->mousey, p->x2 - ds, p->y1, p->x2 + ds, p->y2)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED2 | SELECTED4;              /* right edge (x2) */
    }
    if(xctx->shape_point_selected) {
      /* move one rectangle control point / edge (undo push owned by move_objects START) */
      move_objects(START,0,0,0);
      return 1;
    } /* if(xctx->shape_point_selected) */
  } /* if(rect_n >= 0) */
  return 0;
}

/* Fluid editing (C2, doc/claude/specs/fluid_editing.md) -- grab an arc angular endpoint.
 * Mirrors edit_rect_point: a cadhalfdotsize-scaled tolerance zone on each grabbable arc
 * handle. The point->SELECTED mapping matches the area-stretch path in select.c
 * (select_inside, arc branch) so the same move.c commit code applies:
 *   end endpoint (xb,yb)   -> SELECTED3  (arc sweep b)
 *   start endpoint (xa,ya) -> SELECTED2  (start angle a)
 * The end endpoint is tested first, so a full-circle arc where xa==xb resolves to it.
 * NOTE: the arc CENTER (radius handle, SELECTED1 in select.c/move.c) is intentionally NOT
 * offered here: the center is not on the curve, so a click there never hits/selects the
 * arc (find_closest_arc measures distance to the ring), which means the arc is never
 * sel_array[0] for a center press -- a center zone would be dead code. Radius editing
 * stays available via the area-stretch (rubber-band) path. A click on the arc BODY away
 * from the endpoints returns 0 and falls through to the whole-object move.
 * Gated on `fluid` (fluid_editing) -- a NEW handle with no prior editor, like the C3 rect
 * edges -- so the stock two-step keeps moving the whole arc. sets xctx->shape_point_selected */
static int edit_arc_point(int state, int fluid)
{
   int arc_n = -1, arc_c = -1;
   dbg(1, "1 Arc selected\n");
   if(!fluid) return 0;
   /* modifier-held press = copy/detach gesture, not a stretch (see edit_line_point) */
   if(state & (ControlMask | ShiftMask)) return 0;
   arc_n = xctx->sel_array[0].n;
   arc_c = xctx->sel_array[0].col;
  if(arc_n >= 0) {
    double ds = xctx->cadhalfdotsize * 2 * xctx->zoom;
    xArc *p = &xctx->arc[arc_c][arc_n];
    double xa = p->x + p->r * cos(p->a * XSCH_PI / 180.);
    double ya = p->y - p->r * sin(p->a * XSCH_PI / 180.);
    double xb = p->x + p->r * cos((p->a + p->b) * XSCH_PI / 180.);
    double yb = p->y - p->r * sin((p->a + p->b) * XSCH_PI / 180.);

    xctx->need_reb_sel_arr=1;
    if(POINTINSIDE(xctx->mousex, xctx->mousey, xb - ds, yb - ds, xb + ds, yb + ds)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED3;
    }
    else if(POINTINSIDE(xctx->mousex, xctx->mousey, xa - ds, ya - ds, xa + ds, ya + ds)) {
      xctx->shape_point_selected = 1;
      p->sel = SELECTED2;
    }
    if(xctx->shape_point_selected) {
      /* move one arc endpoint (undo push owned by move_objects START) */
      move_objects(START,0,0,0);
      return 1;
    } /* if(xctx->shape_point_selected) */
  } /* if(arc_n >= 0) */
  return 0;
}

/* sets xctx->shape_point_selected */
static int edit_polygon_point(int state)
{
   int poly_n = -1, poly_c = -1;
   dbg(1, "1 Polygon selected\n");
   poly_n = xctx->sel_array[0].n;
   poly_c = xctx->sel_array[0].col;
  /* polygon point: Check is user is clicking a control point of a polygon */
  if(poly_n >= 0) {
    int i;
    double ds = xctx->cadhalfdotsize;
    int c = poly_c;
    int n = poly_n;
    xPoly *p = &xctx->poly[c][n];

    xctx->need_reb_sel_arr=1;
    for(i = 0; i < p->points; i++) {
      if(
          POINTINSIDE(xctx->mousex, xctx->mousey, p->x[i] - ds, p->y[i] - ds,
                        p->x[i] + ds, p->y[i] + ds)
        ) {
          dbg(1, "selecting point %d\n", i);
          p->selected_point[i] = 1;
          xctx->shape_point_selected = 1;
          break;
      }
    }
    if(xctx->shape_point_selected) {
      int j;
      int points = p->points;

      /* add a new polygon/bezier point after selected one and start moving it*/
      if(state & ShiftMask) {
        xctx->push_undo();
        points++;
        my_realloc(_ALLOC_ID_, &p->x, sizeof(double) * points);
        my_realloc(_ALLOC_ID_, &p->y, sizeof(double) * points);
        my_realloc(_ALLOC_ID_, &p->selected_point, sizeof(unsigned short) * points);
        p->selected_point[i] = 0;
        for(j = points - 2; j > i; j--) {
          p->x[j + 1] = p->x[j];
          p->y[j + 1] = p->y[j];
          p->selected_point[j + 1] = p->selected_point[j];
        }
        p->selected_point[i + 1] = 1;
        p->x[i + 1] = p->x[i];
        p->y[i + 1] = p->y[i];
        p->points = points;
        p->sel = SELECTED1;
        move_objects(START,0,0,0);
        return 1;
      }
      /* delete polygon/bezier selected point */
      else if(points > 2 && state & ControlMask) {
        xctx->push_undo();
        points--;
        for(j = i ; j < points ; j++) {
           p->x[j] = p->x[j + 1];
           p->y[j] = p->y[j + 1];
           p->selected_point[j] = p->selected_point[j + 1];
        }
        my_realloc(_ALLOC_ID_, &p->x, sizeof(double) * points);
        my_realloc(_ALLOC_ID_, &p->y, sizeof(double) * points);
        my_realloc(_ALLOC_ID_, &p->selected_point, sizeof(unsigned short) * points);
        p->points = points;
        p->sel = SELECTED;
        return 1;
      /* move one polygon/bezier selected point */
      } else if(!(state & (ControlMask | ShiftMask))){
        /* xctx->push_undo(); */
        p->sel = SELECTED1;
        move_objects(START,0,0,0);
        return 1;
      }
    } /* if(xctx->shape_point_selected) */
  } /* if(poly_n >= 0) */
  return 0;
}

/* Fluid editing (C4, doc/claude/specs/fluid_editing.md): try to start a first-click
 * control-point grab on the single selected object under the cursor. Returns 1 if a grab
 * started (move_objects(START) called) so the caller returns, skipping the whole-object
 * move; 0 to fall through. Gating, preserved from the per-type if-chain it replaces:
 *   - polygon vertex: grabs unconditionally (legacy; intuitive-independent).
 *   - rect corner / line end / wire end: grabs when already-selected (the stock two-step)
 *     OR `fluid` (fluid_editing) -- and only in the intuitive interface.
 *   - rect side EDGE and arc endpoint: NEW handles, fluid-only (enforced inside the
 *     editors), so the stock two-step is unchanged. */
static int try_grab_shape_point(int state, int intuitive, int already_selected, int fluid)
{
  if(xctx->readonly || xctx->lastsel != 1) return 0;
  if(xctx->sel_array[0].type == POLYGON) return edit_polygon_point(state);
  if(!intuitive || !(already_selected || fluid)) return 0;
  switch(xctx->sel_array[0].type) {
    case xRECT: return edit_rect_point(state, fluid);
    case LINE:  return edit_line_point(state);
    case WIRE:  return edit_wire_point(state);
    case ARC:   return edit_arc_point(state, fluid);
    default:    return 0;
  }
}

/* Action-log Layer B (spec section 2): the replayable command recorded when a
 * context-menu pick fires, indexed by the menu's retval (1..21). One table, the
 * complete classification, so the log call below stays a single line:
 *   "xschem ..."  logged verbatim -- a replayable command;
 *   "# ..."       logged as a non-replayable marker (dialog / object-ref gap);
 *   NULL          nothing logged -- gesture-starts, whose replayable form is the
 *                 gesture END (Layer C / Phase 2, shared with their key/toolbar
 *                 twins), and abort (no replayable effect).
 * The selection/cursor/hierarchy-dependent commands (cut/copy/delete/
 * descend_symbol/go_back/paste) are the real action taken; their replay fidelity
 * is bounded by the click-select gap (issue 0005), exactly as for the Layer A
 * hilight commands. 'load recent' is dynamic (the filename) and is logged at its
 * own case instead of here. */
static const char *ctxmenu_log_cmd[] = {
  NULL,                          /*  0  (unused: retval is 1-based)        */
  NULL,                          /*  1  place symbol      -> Layer C       */
  NULL,                          /*  2  place wire        -> Layer C       */
  NULL,                          /*  3  place line        -> Layer C       */
  NULL,                          /*  4  place rectangle   -> Layer C       */
  NULL,                          /*  5  place polygon     -> Layer C       */
  NULL,                          /*  6  place text        -> Layer C       */
  "xschem cut",                  /*  7  cut selection -> clipboard         */
  NULL,                          /*  8  paste clipboard   -> Layer C: the pick only STARTS the
                                  *     merge gesture; the drop logs the replayable
                                  *     `xschem paste dx dy ...` line (issue 0069). A pick line
                                  *     here would replay a second merge on top of it. */
  NULL,                          /*  9  load recent  (dynamic; see case 9) */
  "# context-menu: edit attributes (dialog, not replayable)",            /* 10 */
  "# context-menu: edit attributes in editor (dialog, not replayable)",  /* 11 */
  "# context-menu: descend to schematic (not replayable: needs object reference, issue 0005)", /* 12 */
  "xschem descend_symbol",       /* 13  descend into symbol                */
  "xschem go_back",              /* 14  go back up the hierarchy           */
  "xschem copy",                 /* 15  copy selection -> clipboard        */
  NULL,                          /* 16  move selection    -> Layer C       */
  NULL,                          /* 17  duplicate selection -> Layer C     */
  "xschem delete",               /* 18  delete selection                   */
  NULL,                          /* 19  place arc         -> Layer C       */
  NULL,                          /* 20  place circle      -> Layer C       */
  NULL,                          /* 21  abort (no replayable effect)       */
  "# context-menu: descend to schematic (edit) (not replayable: needs object reference, issue 0005)" /* 22 */
};

static void context_menu_action(double mx, double my)
{
  int ret;
  const char *status;
  int prev_state;
  const char *logcmd = NULL;     /* action-log Layer B: what this pick records */
  /* issue 0249: the wrapper below is gated on "the core did not already log it",
   * NOT on whether the verb did anything, and the descend verbs self-log only on
   * their success path -- so a REFUSED descend pick fell through to the
   * classification table and wrote `xschem descend_symbol` for a descend that never
   * happened. Replaying that log descends where the recording did not. This is the
   * ratified "an aborted gesture must not lie about the modify flag" (0244/0267/0270)
   * applied to the action log. Index 13 is the only replay hazard (12/22 record `#`
   * comments) but one flag covers all three uniformly. */
  int verb_refused = 0;
  xctx->semaphore++;
  status = tcleval("context_menu");
  xctx->semaphore--;
  if(!status) return;
  ret = atoi(status);
  /* read-only: refuse the object-mutating context-menu picks (place sym/wire/line/
   * rect/poly/text/arc/circle, cut, paste, move, duplicate, delete, edit-in-editor).
   * Navigation picks (descend/pop/load/copy-to-clipboard) fall through -- and so does
   * "Edit attributes" (case 10), which opens the property form as a read-only VIEWER
   * (issue 0051): viewing properties is not an edit. (case 11 = edit-in-editor stays
   * blocked, the right-click twin of the 'Q' key.) */
  switch(ret) {
    case 1: case 2: case 3: case 4: case 5: case 6: case 7: case 8:
    case 11: case 16: case 17: case 18: case 19: case 20:
      if(readonly_block()) return;
      break;
    default: break;
  }
  actionlog_cmd_logged = 0;   /* dedup: skip the Layer B line if the pick's core self-logs */
  switch(ret) {
    case 1:
      start_place_symbol();
      break;
    case 2:
      leave_shape_draw_for("Insert wire");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
      if(!leave_placement_for("Insert wire")) break;  /* issue 0243 F2 -- see leave_placement_for() */
      /* issue 0265 / plan_modal_gesture_exclusion.md phase 4 -- one direction: a DRAW cancels a
       * live merge. Without this the paste stayed armed UNDER the new draw -- measured ui_state
       * 297 = STARTWIRE|STARTMERGE|STARTMOVE|SELECTION -- and one ESC then had to serve two
       * gestures. The OTHER direction was recorded as already working, "because merge_file() calls
       * leave_placement_for(), which is the wire/line teardown too" -- that was FALSE (issue 0271,
       * measured: the SAME ui_state 297 from `wire gui` + `merge`), and merge_file() now carries
       * leave_wire_draw_for() of its own. */
      if(!leave_merge_for("Insert wire")) break;
      prev_state = xctx->ui_state;
      start_wire(mx, my);
      if(prev_state == STARTWIRE) {
        tcleval("set constr_mv 0" );
        xctx->constr_mv=0;
      }
      break;
    case 3:
      leave_shape_draw_for("Insert line");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
      if(!leave_placement_for("Insert line")) break;  /* issue 0243 F2 -- see leave_placement_for() */
      if(!leave_merge_for("Insert line")) break;      /* issue 0265 -- phase 4, see the wire pick */
      prev_state = xctx->ui_state;
      start_line(mx, my);
      if(prev_state == STARTLINE) {
        tcleval("set constr_mv 0" );
        xctx->constr_mv=0;
      }
      break;
    case 4:
      leave_wire_draw_for("Rectangle");  /* phase 1 -- see leave_wire_draw_for() */
      /* ISSUE 0269 -- phase 3, and the half of it the plan's own box called "call from every
       * placement verb". A SHAPE arm is a co-arm in EVERY direction, not just against a wire draw:
       * phase 1 gave the shape arms leave_wire_draw_for() and stopped there, so `rect gui` over a
       * live Add-Pin preview (measured ui_state 8234 / 16426) or over a pending paste (298) still
       * left BOTH gestures armed -- and a shape over another shape is a co-arm too (`rect gui`
       * then `rect 10 20` -> 65538, STARTRECT under a fresh MENUSTARTRECT). One ratified rule, all
       * four gates, at every shape arm. Order: the two band-erasing gates first (they tile from
       * save_pixmap), then placement before merge for the shared preview_sel slot. */
      leave_shape_draw_for("Rectangle");
      leave_placement_for("Rectangle");
      leave_merge_for("Rectangle");
      xctx->mx_double_save=xctx->mousex_snap;
      xctx->my_double_save=xctx->mousey_snap;
      xctx->last_command = 0;
      new_rect(PLACE,mx, my);
      break;
    case 5:
      leave_wire_draw_for("Polygon");    /* phase 1 -- see leave_wire_draw_for() */
      leave_shape_draw_for("Polygon");   /* issue 0269 -- phase 3, all four gates at every shape arm: see the ctx-menu Rectangle pick */
      leave_placement_for("Polygon");
      leave_merge_for("Polygon");
      xctx->mx_double_save=xctx->mousex_snap;
      xctx->my_double_save=xctx->mousey_snap;
      xctx->last_command = 0;
      new_polygon(PLACE, mx, my);
      break;
    case 6: /* place text */
      /* phase 2 -- see leave_wire_draw_for(). Pick 6, not 8: 8 is Paste clipboard (a merge, whose
       * preview carries STARTMERGE and belongs to phase 4 / issues 0242+0244). */
      leave_wire_draw_for("Insert text");
      leave_shape_draw_for("Insert text");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
      leave_placement_for("Insert text");  /* issue 0242 -- twin of the place_text verb */
      leave_merge_for("Insert text");      /* issue 0265 -- ditto for a pending paste. This is one
                                            * of the four arms that do NOT unselect_all, so before
                                            * the gate the merge stayed armed and its objects got
                                            * folded into this placement's stamp; now the paste is
                                            * torn down here and the stamp names only the text. */
      xctx->last_command = 0;
      xctx->mx_double_save=xctx->mousex_snap;
      xctx->my_double_save=xctx->mousey_snap;
      if(place_text(0, mx, my)) { /* 1 = draw text */
        xctx->mousey_snap = xctx->my_double_save;
        xctx->mousex_snap = xctx->mx_double_save;
        move_objects(START,0,0,0);
        /* issue 0241. place_text() does not unselect first, so the stamp captures the new text
         * AND whatever was already selected -- which is what move_objects(START) just grabbed
         * and what the cancel has always removed. Preserved verbatim; narrowing it further
         * would be a separate change to what `t` does with a live selection. */
        stamp_placement_preview();
        xctx->ui_state |= PLACE_TEXT;
      }
      break;
    case 7: /* cut selection into clipboard */
      rebuild_selected_array();
      if(xctx->lastsel) { /* 20071203 check if something selected */
        save_selection(2);
        delete(1/* to_push_undo */);
      }
      break;
    case 8: /* paste from clipboard */
      merge_file(2,".sch");
      break;
    case 9: /* load most recent file (read-only, like the File menu's Open Most Recent) */
      /* action-log: the resolved filename is recorded by the scheduler load
       * branch's -gui hook (file-menu logging), shared with the File menu's
       * recent/last-closed picks -- nothing to log here anymore. */
      tclvareval("xschem load -gui -readonly [lindex $tctx::recentfile 0]", NULL);
      break;
    case 10: /* edit attributes */
      edit_property(0);
      break;
    case 11: /* edit attributes in editor */
      edit_property(1);
      break;
    case 12:
      if(!descend_schematic(0, 1, 1, 1)) verb_refused = 1;
      break;
    case 22: /* descend schematic, then force editable (overrides descend_readonly) */
      if(descend_schematic(0, 1, 1, 1)) {
        xctx->readonly = 0;
        set_modify(-1); /* refresh title: clear the read-only marker */
      } else verb_refused = 1;
      break;
    case 13:
      if(!descend_symbol()) verb_refused = 1;
      break;
    case 14:
      go_back(1);
      break;
    case 15: /* copy selection into clipboard */
      rebuild_selected_array();
      if(xctx->lastsel) {
        save_selection(2);
      }
      break;
    case 16: /* move selection */
      if(!(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
        xctx->mx_double_save=xctx->mousex_snap;
        xctx->my_double_save=xctx->mousey_snap;
        move_objects(START,0,0,0);
      }
      break;
    case 17: /* duplicate selection */
      if(!(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
        xctx->mx_double_save=xctx->mousex_snap;
        xctx->my_double_save=xctx->mousey_snap;
        copy_objects(START);
      }
      break;
    case 18: /* delete selection */
      if(xctx->ui_state & SELECTION) delete(1/* to_push_undo */);
      break;
    case 19: /* place arc */
      leave_wire_draw_for("Arc");        /* phase 1 -- see leave_wire_draw_for() */
      leave_shape_draw_for("Arc");       /* issue 0269 -- phase 3, all four gates at every shape arm: see the ctx-menu Rectangle pick */
      leave_placement_for("Arc");
      leave_merge_for("Arc");
      xctx->mx_double_save=xctx->mousex_snap;
      xctx->my_double_save=xctx->mousey_snap;
      xctx->last_command = 0;
      new_arc(PLACE, 180., mx, my);
      break;
    case 20: /* place circle */
      leave_wire_draw_for("Circle");     /* phase 1 -- see leave_wire_draw_for() */
      leave_shape_draw_for("Circle");    /* issue 0269 -- phase 3, all four gates at every shape arm: see the ctx-menu Rectangle pick */
      leave_placement_for("Circle");
      leave_merge_for("Circle");
      xctx->mx_double_save=xctx->mousex_snap;
      xctx->my_double_save=xctx->mousey_snap;
      xctx->last_command = 0;
      new_arc(PLACE, 360., mx, my);
      break;
    case 21: /* abort & redraw */
      abort_operation(1);
      break;
    default:
      break;
  }
  /* action-log Layer B: record the pick AFTER it ran (record-after-evaluation,
   * as in Layer A / the CIW). The classification table decides (command,
   * # marker, or NULL = nothing). */
  if(!logcmd && ret > 0 && ret < (int)(sizeof(ctxmenu_log_cmd)/sizeof(ctxmenu_log_cmd[0])))
    logcmd = ctxmenu_log_cmd[ret];
  /* issue 0249: a REFUSED verb must not leave a replayable COMMAND behind (replay would
   * then descend where the recording did not). A '#' marker is inert commentary about
   * what was PICKED -- replay skips it, so it cannot lie, and suppressing it would erase
   * the only record that the user clicked anything (locked by
   * tests/headless/test_context_menu_log.tcl, "descend pick logs a '# ' marker", which
   * picks descend with nothing selected). So: gate the commands, keep the markers. */
  if(logcmd && !actionlog_cmd_logged && (!verb_refused || logcmd[0] == '#'))
    log_action("%s", logcmd);
}

/* ===========================================================================
 * Phase 3a: data-driven input-action dispatch (mouse wheel).
 * See doc/claude/suggestions/refactor_plan_action_registry_phase3.md.
 *
 * Separates *binding* (which physical input maps to which action -- held as
 * data in input_bindings[], remappable at runtime via `xschem bind`) from
 * *behavior* (the act_* functions, which stay in C and touch xctx). This first
 * slice covers only the mouse wheel; the built-in defaults reproduce the
 * previous hard-coded handling exactly. Later phases extend the same table to
 * mouse buttons, gestures and the handle_key_press keysym chain, and may move
 * this block into its own translation unit.
 * ===========================================================================*/

/* input device classes for a binding signature */
enum { DEV_WHEEL = 1, DEV_BUTTON = 2, DEV_KEY = 3 };
/* wheel direction codes (DEV_WHEEL) */
enum { WHEEL_UP = 1, WHEEL_DOWN = 2 };
/* binding context (kept tiny on purpose; grows in Phase 3c) */
enum { ACTX_GLOBAL = 0, ACTX_CANVAS = 1, ACTX_OVER_GRAPH = 2 };

/* event handed to an action function; gesture/key actions will use the extra
 * fields in later phases, the Phase 3a wheel actions ignore them. */
typedef struct {
  int device;       /* DEV_*                            */
  int code;         /* WHEEL_*, button number, or KeySym */
  int mods;         /* normalized modifier mask         */
  int ctx;          /* ACTX_*                           */
  int mx, my;       /* pointer position                 */
  int state;        /* raw X modifier/button mask       */
  /* raw X event params, for actions that re-forward the event (e.g. graph.forward) */
  int xevent;       /* X event type (ButtonPress, ...)  */
  KeySym key;       /* raw keysym (0 for mouse)         */
  int button;       /* raw X button number (0 for key)  */
  int aux;
} ActionEvent;

typedef int (*action_fn)(const ActionEvent *e);  /* returns 1 if handled */

/* --- action behaviors (the "what it does"; ids match src/actions.csv) --- */
static int act_zoom_in(const ActionEvent *e)  { (void)e; view_zoom(CADZOOMSTEP);   return 1; }
static int act_zoom_out(const ActionEvent *e) { (void)e; view_unzoom(CADZOOMSTEP); return 1; }
static int act_zoom_full(const ActionEvent *e) {
  int flags = 1;
  (void)e;
  if(tclgetboolvar("zoom_full_center")) flags |= 2;
  zoom_full(1, 0, flags, 0.97);
  return 1;
}
/* Phase 3 (action-logging): the view-step bodies, shared between the act_*
 * wrappers and the `xschem pan|scroll <dir>` subcommands (scheduler.c) -- the
 * csv command for these ids is the subcommand, so the line Layer A logs
 * replays through the SAME code the bound chord ran (equivalence by
 * construction). The scroll (full-step, arrow-key) and pan (half-step, wheel)
 * sign conventions differ on purpose: each is preserved verbatim from its
 * historical arithmetic in handle_key_press / the wheel acts (Right scrolls
 * xorigin the same way the wheel's pan_left does -- not "corrected"). */
int view_pan_dir(const char *dir)     /* half step; wheel signs */
{
  double s = CADMOVESTEP * xctx->zoom / 2.;
  if(!strcmp(dir, "left"))       xctx->xorigin += -s;
  else if(!strcmp(dir, "right")) xctx->xorigin -= -s;
  else if(!strcmp(dir, "up"))    xctx->yorigin += -s;
  else if(!strcmp(dir, "down"))  xctx->yorigin -= -s;
  else return 0;
  draw();
  redraw_w_a_l_r_p_z_rubbers(1);
  return 1;
}
int view_scroll_dir(const char *dir)  /* full step; arrow-key signs */
{
  double s = CADMOVESTEP * xctx->zoom;
  if(!strcmp(dir, "up"))         xctx->yorigin -= -s;
  else if(!strcmp(dir, "down"))  xctx->yorigin += -s;
  else if(!strcmp(dir, "left"))  xctx->xorigin -= -s;
  else if(!strcmp(dir, "right")) xctx->xorigin += -s;
  else return 0;
  draw();
  redraw_w_a_l_r_p_z_rubbers(1);
  return 1;
}
static int act_pan_left(const ActionEvent *e)  { (void)e; return view_pan_dir("left");  }
static int act_pan_right(const ActionEvent *e) { (void)e; return view_pan_dir("right"); }
static int act_pan_up(const ActionEvent *e)    { (void)e; return view_pan_dir("up");    }
static int act_pan_down(const ActionEvent *e)  { (void)e; return view_pan_dir("down");  }
/* full-step viewport scroll, bound to the arrow keys (Phase 3c c4/c5). Named by
 * the triggering arrow so a binding row reads naturally. */
static int act_scroll_up(const ActionEvent *e)    { (void)e; return view_scroll_dir("up");    }
static int act_scroll_down(const ActionEvent *e)  { (void)e; return view_scroll_dir("down");  }
static int act_scroll_left(const ActionEvent *e)  { (void)e; return view_scroll_dir("left");  }
static int act_scroll_right(const ActionEvent *e) { (void)e; return view_scroll_dir("right"); }
/* gesture START: only the initiating chord is data-driven. zoom_rectangle(START)
 * sets ui_state STARTZOOM; the rubber-band (motion) and completion (release)
 * already key off that bit, so they need no per-button binding (Phase 3b). */
static int act_zoom_rect_start(const ActionEvent *e) { (void)e; zoom_rectangle(START); return 1; }
/* forward the raw event to the waveform-graph handler. Bound to over_graph rows
 * so that e.g. wheeling while the pointer is over a graph drives the graph rather
 * than the canvas — the data-driven replacement for the old inline
 * waves_selected/waves_callback guards (Phase 3c). */
static int act_graph_forward(const ActionEvent *e) {
  waves_callback(e->xevent, e->mx, e->my, e->key, e->button, e->aux, e->state); return 1; }
/* canvas-only symbol commands migrated out of the switch (Phase 3d.2). They call
 * the exact C functions the old `case 'H'` did (operate on the selection, no mouse
 * coords, no semaphore guard). */
static int act_attach_labels(const ActionEvent *e) { (void)e; attach_labels_to_inst(1); return 1; }
static int act_make_sch_sym_from_sel(const ActionEvent *e) { (void)e; make_schematic_symbol_from_sel(); return 1; }
/* more clean canvas-only command keys (Phase 3d.2 batch 2). The snap acts read the
 * current snap the same way the c_snap parameter is derived (tclgetdoublevar
 * "cadsnap", callback.c); the stretch act flips the enable_stretch tcl var (the old
 * branch's local toggle was dead after the function returned). */
/* shared bodies for the snap/toggle acts and their `xschem snap half|double`,
 * `xschem toggle_*` subcommands (Phase 3, same rule as view_pan_dir above) */
void view_snap_change(int dbl)
{
  char msg[128];
  double old = tclgetdoublevar("cadsnap");
  set_snap(old * (dbl ? 2.0 : 0.5));
  change_linewidth(-1.);
  draw();
  /* Self-log the ABSOLUTE resolved snap, NOT the relative step (the 0066 cadsnap
   * rule, same as toggle_stretch below: never a relative form when an absolute one
   * exists -- a replayed `xschem snap double` lands on a different value whenever
   * the start snap differs from record time). set_snap() maps 0 -> the default, so
   * read cadsnap BACK rather than logging the computed argument. Every entry point
   * funnels here (the bound Alt+Up/Alt+Down chords of cadence_style_rc, the View
   * menu items, `xschem snap half|double` from a script), and log_action sets
   * actionlog_cmd_logged, so the csv log_cmd copy in dispatch_input_action dedups
   * to exactly ONE line. Snap is edit geometry, not saved content -> no read-only
   * guard, so this logs on a read-only view too (descend browse mode).
   * See doc/claude/specs/snap_spacing_bindkeys.md. */
  log_action("xschem set cadsnap %.10g", tclgetdoublevar("cadsnap"));
  /* ...plus the outcome a user reads in the CIW: which way it moved and from
   * what. Silent-action complaint class -- a snap change that only shows up as a
   * statusbar colour is invisible while the eye is on the schematic. */
  my_snprintf(msg, S(msg), "snap %.10g -> %.10g (%s)", old, tclgetdoublevar("cadsnap"),
              dbl ? "x2" : "x0.5");
  log_action_result(msg);
}
void toggle_stretch_cmd(void)
{
  tclsetboolvar("enable_stretch", !tclgetboolvar("enable_stretch"));
  /* self-log the ABSOLUTE resolved state, NOT the relative flip (0062 tail / atom 16):
   * a replayed `xschem toggle_stretch` lands on the OPPOSITE value whenever the start
   * state differs from record time, so log the set-class form read back AFTER the flip
   * (the 0066 cadsnap rule: never a relative/gesture form when an absolute one exists).
   * Both callers -- the scheduler `toggle_stretch` branch and the 'y'-key
   * act_toggle_stretch -- funnel here (1:1 with the verb), so this one site covers
   * key/menu/script; the key's csv log_cmd copy dedups via dispatch's
   * actionlog_cmd_logged gate. The `set enable_stretch` scheduler replay arm reproduces
   * the effect (the mirrored tcl var) without re-logging. */
  log_action("xschem set enable_stretch %d", tclgetboolvar("enable_stretch"));
}
static int act_toggle_stretch(const ActionEvent *e) { (void)e; toggle_stretch_cmd(); return 1; }
/* Refactor B atom 12: the equivalent Shift+T key routes through the perform_action
 * boundary (not the raw toggle_ignore()), exactly like the '&'/Alt-U inline keys.
 * perform_action's rc is DISCARDED -- an ActionEvent handler returns 1 (event handled),
 * NOT perform_action's TCL_OK(0)/TCL_ERROR(1), so `return perform_action(...)` would
 * break the handler contract. The readonly gate this key already had (the registry
 * `mutates=1` field -> dispatch_input_action's readonly_block, kept) blocks it BEFORE
 * this handler runs on a read-only cell, so perform_action's own gate is redundant
 * belt-and-suspenders here (it is load-bearing for the menu/script BRANCH, which had
 * none). The key ALSO already logged `xschem toggle_ignore` via Layer A (d->log_cmd
 * from actions.csv, not-nolog); routing through the boundary moves that log onto
 * core_log_action -- and log_action sets actionlog_cmd_logged, so dispatch's Layer A
 * copy DEDUPS to exactly ONE line. Net: same gate, same single log line, now via the
 * unified boundary mechanism. */
static int act_toggle_ignore(const ActionEvent *e) { (void)e; perform_action("toggle_ignore", 0, NULL); return 1; }
static int act_snap_half(const ActionEvent *e)   { (void)e; view_snap_change(0); return 1; }
static int act_snap_double(const ActionEvent *e) { (void)e; view_snap_change(1); return 1; }
static int act_toggle_colorscheme(const ActionEvent *e) {
  (void)e;
  tclsetboolvar("dark_colorscheme", !tclgetboolvar("dark_colorscheme"));
  tclsetdoublevar("dim_value", 0.0);
  tclsetdoublevar("dim_bg", 0.0);
  build_colors(0.0, 0.0);
  draw();
  return 1;
}
/* Phase 3d.2 batch 3 — clean canvas-only command keys. Each replicates its switch
 * branch verbatim (multi-statement tcl-var toggle / C-flag toggle), reading the
 * source of truth rather than any handle_key_press parameter. */
void toggle_show_netlist_cmd(void)
{
  int v = !tclgetboolvar("netlist_show");
  if(v) { tcleval("alert_ { enabling show netlist window} {}");  tclsetvar("netlist_show","1"); }
  else  { tcleval("alert_ { disabling show netlist window } {}"); tclsetvar("netlist_show","0"); }
}
void toggle_orthogonal_wiring_cmd(void)
{
  if(tclgetboolvar("orthogonal_wiring")) { tclsetboolvar("orthogonal_wiring", 0); xctx->manhattan_lines = 0; }
  else                                   { tclsetboolvar("orthogonal_wiring", 1); }
  redraw_w_a_l_r_p_z_rubbers(1);
  /* self-log the ABSOLUTE resolved state (0062 tail / atom 16): see toggle_stretch_cmd
   * for the relative-flip-is-replay-fragile rationale. The `set orthogonal_wiring`
   * scheduler replay arm reproduces the FULL side effect (manhattan_lines + rubber
   * redraw), so a replayed line is faithful, not just the tcl var. */
  log_action("xschem set orthogonal_wiring %d", tclgetboolvar("orthogonal_wiring"));
}
void toggle_draw_pixmap_cmd(void)
{
  xctx->draw_pixmap = !xctx->draw_pixmap;
  if(xctx->draw_pixmap) tcleval("alert_ { enabling draw pixmap} {}");
  else                  tcleval("alert_ { disabling draw pixmap} {}");
}
static int act_toggle_show_netlist(const ActionEvent *e) { (void)e; toggle_show_netlist_cmd(); return 1; }
static int act_toggle_orthogonal_wiring(const ActionEvent *e) { (void)e; toggle_orthogonal_wiring_cmd(); return 1; }
static int act_toggle_draw_pixmap(const ActionEvent *e) { (void)e; toggle_draw_pixmap_cmd(); return 1; }

/* "Highlight net and send to waveform viewer" — verbatim body of the old Alt-g
 * (EQUAL_MODMASK) branch of the hardcoded case 'g' (doc/claude/specs/keybind_snap_grid_actions.md).
 * No-op while busy: returns 0 so the dispatch falls through exactly as the old `break`. */
static int act_highlight_send_waveform(const ActionEvent *e)
{
  char str[PATH_MAX + 100];
  int tool = 0;
  int exists = 0;
  char *tool_name = NULL;
  (void)e;

  if(xctx->semaphore >= 2) return 0;
  tcleval("winfo exists .graphdialog");
  if(tclresult()[0] == '1') tool = XSCHEM_GRAPH;
  else if(xctx->graph_lastsel >=0 &&
      xctx->rects[GRIDLAYER] > xctx->graph_lastsel &&
      xctx->rect[GRIDLAYER][xctx->graph_lastsel].flags & 1) {
    tool = XSCHEM_GRAPH;
  }
  tcleval("info exists sim");
  if(tclresult()[0] == '1') exists = 1;
  xctx->enable_drill = 0;
  if(exists) {
    if(!tool) {
      tool = tclgetintvar("sim(spicewave,default)");
      my_snprintf(str, S(str), "sim(spicewave,%d,name)", tool);
      my_strdup(_ALLOC_ID_, &tool_name, tclgetvar(str));
      dbg(1,"act_highlight_send_waveform(): tool_name=%s\n", tool_name);
      if(strstr(tool_name, "Gaw")) tool=GAW;
      else if(strstr(tool_name, "Bespice")) tool=BESPICE;
      my_free(_ALLOC_ID_, &tool_name);
    }
  }
  if(tool) {
    hilight_net(tool);
    redraw_hilights(0);
  }
  Tcl_ResetResult(interp);
  return 1;
}

/* Enter the persistent deselect-one-at-a-time mode (doc/claude/specs/deselect_one_mode.md).
 * Canvas-only; the click loop + ESC exit live in handle_button_press / abort_operation. */
static int act_deselect_mode(const ActionEvent *e) { (void)e; enter_deselect_mode(); return 1; }

/* Center the view so the current cursor position becomes the screen center (the old
 * Shift+P pan). Shipped UNBOUND (bind a key in keybindings.csv). */
static int act_view_center_at_cursor(const ActionEvent *e)
{
  (void)e;
  xctx->xorigin = -xctx->mousex_snap + xctx->areaw * xctx->zoom / 2.0;
  xctx->yorigin = -xctx->mousey_snap + xctx->areah * xctx->zoom / 2.0;
  draw();
  redraw_w_a_l_r_p_z_rubbers(1);
  return 1;
}

/* --- SPACE's three behaviors, extracted so they are separately rebindable actions
 * (B6, doc/claude/specs/wire_stub_netlabel.md). The default SPACE binding is
 * edit.add_pin_stubs; it SELF-GATES and declines (returns 0 -> dispatch falls
 * through to the legacy `case ' '`), so mid-gesture SPACE still cycles the manhattan
 * corner and idle/empty-selection SPACE still pans -- both run from the same cores
 * below, whether reached via a rebound action or the case ' ' fallback. */

/* Cycle the manhattan corner-mode of an in-progress move/wire/line gesture (rotate
 * xctx->manhattan_lines through 0..2, refreshing the rubber). Self-gating: does
 * nothing and returns 0 unless a STARTMOVE/STARTWIRE/STARTLINE gesture is active. */
static int cycle_manhattan_lines(void)
{
  if(xctx->ui_state & STARTMOVE) {
    draw_selection(xctx->gctiled, 0);
    xctx->manhattan_lines++;
    xctx->manhattan_lines %= 3;
    draw_selection(xctx->gc[SELLAYER], 0);
  } else if(xctx->ui_state & STARTWIRE) { /*  & instead of == 20190409 */
    new_wire(RUBBER | CLEAR, xctx->mousex_snap, xctx->mousey_snap);
    xctx->manhattan_lines++;
    xctx->manhattan_lines %= 3;
    new_wire(RUBBER, xctx->mousex_snap, xctx->mousey_snap);
  } else if(xctx->ui_state & STARTLINE) {
    new_line(RUBBER | CLEAR, xctx->mousex_snap, xctx->mousey_snap);
    xctx->manhattan_lines++;
    xctx->manhattan_lines %= 3;
    new_line(RUBBER, xctx->mousex_snap, xctx->mousey_snap);
  } else {
    return 0;
  }
  return 1;
}

/* Start a drag-pan of the canvas at (mx,my). Off a modal/busy state it first
 * refreshes the selected-object array so the SELECTION ui_state flag reflects
 * reality, exactly as the old `case ' '` pan branch did. */
static void start_pan_at(int mx, int my)
{
  if(xctx->semaphore < 2) {
    rebuild_selected_array(); /* sets or clears the SELECTION ui_state flag */
  }
  start_pan_logged(mx, my);
}

/* edit.cycle_manhattan: cycle the active gesture's manhattan corner. Returns 0
 * (declines -> dispatch falls through) when no gesture is active. */
static int act_cycle_manhattan(const ActionEvent *e) { (void)e; return cycle_manhattan_lines(); }

/* view.pan: start a drag-pan of the canvas from the event position. */
static int act_pan(const ActionEvent *e) { start_pan_at(e->mx, e->my); return 1; }

/* edit.add_pin_stubs (SPACE default): draw a wire stub + outward net-label out of each
 * selected pin / each unconnected pin of a selected instance. Declines (returns 0 ->
 * dispatch falls through to the legacy `case ' '`) whenever it does NOT stub, so SPACE
 * keeps its historical fallbacks in every non-stub case:
 *   - during a move/wire/line gesture -> decline (SPACE cycles the manhattan corner)
 *   - with an empty selection          -> decline (SPACE starts a pan)
 *   - a selection with nothing stubbable (e.g. only a wire, or all pins already wired),
 *     a read-only view, or symbol mode  -> add_pin_stubs returns 0 without mutating, so
 *     decline (SPACE pans -- no dead key, no modal read-only dialog)
 *   - otherwise it stubbed -> consume (add_pin_stubs already did the one undo + draw). */
static int act_add_pin_stubs(const ActionEvent *e)
{
  (void)e;
  if(xctx->ui_state & (STARTMOVE | STARTWIRE | STARTLINE)) return 0;
  rebuild_selected_array();
  if(xctx->lastsel == 0) return 0;
  return add_pin_stubs("", "", 0) > 0 ? 1 : 0;
}

/* select.same_net_by_label: select the whole LOGICAL net under the pointer --
 * every wire segment carrying the same net name, INCLUDING segments that touch
 * nothing but share a wire-label (one node in the netlist), plus the labels /
 * ports that name it. The double-click grow (select_grow_connected) is the
 * geometric counterpart and stops where the copper stops.
 * doc/claude/specs/select_same_net_by_label.md.
 *
 * Ships UNBOUND: src/cadence_style_rc maps it to Ctrl+Alt+Shift+Button1. Remap or
 * un-bind it from any rc / --script with
 *   xschem bind button 1 ctrl+alt+shift canvas select.same_net_by_label
 *   xschem unbind button 1 ctrl+alt+shift canvas
 * xctx->mousex/mousey are the unsnapped schematic coords callback() computed for
 * this event -- the same ones the other press branches pick objects with.
 * The core self-logs (command + outcome, log file and CIW), and the csv rows are
 * nolog, so nothing here logs a second line. */
static int act_select_same_net(const ActionEvent *e)
{
  (void)e;
  select_same_net_by_name(xctx->mousex, xctx->mousey, 1, 0);
  return 1;
}
/* additive twin: keeps the current selection and adds the clicked net to it */
static int act_select_same_net_add(const ActionEvent *e)
{
  (void)e;
  select_same_net_by_name(xctx->mousex, xctx->mousey, 1, 1);
  return 1;
}

/* --- Alt-R / Alt-F / Alt-V: the in-place transforms, made REMAPPABLE ---------
 * These three were hardcoded `else if(EQUAL_MODMASK)` arms of the switch cases 'r',
 * 'f' and 'v' -- reachable only from those physical keys, invisible to `xschem bind`,
 * to keybindings.csv and to the generated cheat-sheet. Each body is migrated here
 * VERBATIM (the mid-drag STARTMOVE/STARTCOPY arms, the empty-selection arming arm and
 * the standalone apply) and registered as an action, so the chord is data-driven like
 * every other migrated key. The DEFAULTS ARE UNCHANGED: two rows per key, Mod1Mask
 * (Alt) and Mod4Mask (Super), reproduce the EQUAL_MODMASK test exactly -- see
 * init_input_bindings, and src/cadence_style_rc for the user-facing remap recipe.
 *
 * The readonly gate these arms had (`if(readonly_block()) break;`) is now the registry
 * `mutates=1` column: dispatch_input_action refuses on a read-only view BEFORE the
 * handler runs -- same modal, same no-op, one less inline gate.
 *
 * NO log_cmd, on purpose: the actions.csv rows are label-only (empty command), so
 * dispatch_input_action's Layer A never fires for them. The standalone arms self-log at
 * the perform_action boundary (`xschem rotate_in_place` / `rotate x y` / ...), while the
 * mid-drag and arming arms MUST stay silent -- a drag is logged at its END (Layer C) and
 * an `xschem rotate_in_place` line emitted mid-drag would replay as one extra rotation
 * (the same trap the scheduler's rotate_in_place/flip_in_place branches warn about).
 *
 * The snap is read here exactly the way handle_key_press's c_snap parameter is derived
 * (tclgetdoublevar("cadsnap"), callback entry), so the group pivot is identical. */
static int connected_drag_group_transform(void);
static void standalone_group_transform(int what, double c_snap);

/* edit.rotate_in_place (default Alt-R / Super-R): old case 'r' EQUAL_MODMASK arm. */
static int act_rotate_in_place(const ActionEvent *e)
{
  (void)e;
  /* issue 0114: a multi-object connected drag rotates the whole selection as a group
   * (shared pivot, ROTATELOCAL dropped) so wires stay connected; a single object keeps
   * the per-object in-place rotate (rotatelocal about its own origin). */
  if(xctx->ui_state & STARTMOVE)
    move_objects(ROTATE | (connected_drag_group_transform() ? 0 : ROTATELOCAL),0,0,0);
  else if(xctx->ui_state & STARTCOPY)
    copy_objects(ROTATE | (connected_drag_group_transform() ? 0 : ROTATELOCAL));
  else {
    rebuild_selected_array();
    if(xctx->lastsel == 0) { /* Cases 1 & 3: arm prompt-for-object rotate-in-place */
      xctx->ui_state |= MENUSTART;
      xctx->ui_state2 = MENUSTARTROTATE;
      xctx->menu_pending_transform = PENDING_TR_ROTATE_IP;
      statusmsg_hold("Rotate in place: click an object to rotate", 1);
    } else {
      /* issue 0116 bug 2: multi-object selection rotates as one rigid body (group, about the
       * grid-snapped bbox centre); a single object keeps its own-origin in-place rotate. */
      standalone_group_transform(ROTATE, tclgetdoublevar("cadsnap"));
    }
  }
  return 1;
}

/* edit.flip_in_place (default Alt-F / Super-F): old case 'f' EQUAL_MODMASK arm --
 * HORIZONTAL mirror (left<->right) about each object's own origin, or about the
 * selection bbox centre for a multi-object selection. */
static int act_flip_in_place(const ActionEvent *e)
{
  (void)e;
  /* issue 0114: multi-object connected drag flips the whole selection as a group
   * (shared pivot); a single object keeps the per-object in-place flip. */
  if(xctx->ui_state & STARTMOVE)
    move_objects(FLIP | (connected_drag_group_transform() ? 0 : ROTATELOCAL),0,0,0);
  else if(xctx->ui_state & STARTCOPY)
    copy_objects(FLIP | (connected_drag_group_transform() ? 0 : ROTATELOCAL));
  else {
    rebuild_selected_array();
    if(xctx->lastsel == 0) { /* Cases 1 & 3: arm prompt-for-object flip-in-place */
      xctx->ui_state |= MENUSTART;
      xctx->ui_state2 = MENUSTARTROTATE;
      xctx->menu_pending_transform = PENDING_TR_FLIP_IP;
      statusmsg_hold("Flip in place: click an object to flip", 1);
    } else {
      /* issue 0116 bug 2: multi-object selection flips as one rigid body (group, about the
       * grid-snapped bbox centre); a single object keeps its own-origin in-place flip.
       * Self-logs at the helper (issue 0068): standalone reaches only here, never the
       * scheduler branch, so no double-log; replay sources the verb into the scheduler. */
      standalone_group_transform(FLIP, tclgetdoublevar("cadsnap"));
    }
  }
  return 1;
}

/* edit.flipv_in_place (default Alt-V / Super-V): old case 'v' EQUAL_MODMASK arm --
 * VERTICAL mirror (up<->down), built as rotate+rotate+flip. NOTE the asymmetry with
 * the two above: there is no standalone_group_transform arm (no issue-0116 group form),
 * so a multi-object selection flips each object about its OWN origin. */
static int act_flipv_in_place(const ActionEvent *e)
{
  (void)e;
  /* issue 0114: multi-object connected drag = group vertical flip (shared pivot);
   * single object keeps the per-object in-place flip. rl applied to all three steps. */
  if(xctx->ui_state & STARTMOVE) {
    int rl = connected_drag_group_transform() ? 0 : ROTATELOCAL;
    move_objects(ROTATE|rl,0,0,0);
    move_objects(ROTATE|rl,0,0,0);
    move_objects(FLIP|rl,0,0,0);
  }
  else if(xctx->ui_state & STARTCOPY) {
    int rl = connected_drag_group_transform() ? 0 : ROTATELOCAL;
    copy_objects(ROTATE|rl);
    copy_objects(ROTATE|rl);
    copy_objects(FLIP|rl);
  }
  else {
    rebuild_selected_array();
    if(xctx->lastsel == 0) { /* Cases 1 & 3: arm prompt-for-object vertical flip-in-place */
      xctx->ui_state |= MENUSTART;
      xctx->ui_state2 = MENUSTARTROTATE;
      xctx->menu_pending_transform = PENDING_TR_FLIPV_IP;
      statusmsg_hold("Vertical flip in place: click an object to flip", 1);
    } else {
      /* standalone vertical flip-in-place: route through the mutation boundary (Refactor B
       * atom 5). perform_action owns the readonly gate + the ONE `xschem flipv_in_place`
       * log site + the rebuild+START+ROTATE|ROTATELOCAL x2 + FLIP|ROTATELOCAL+END effect.
       * Unlike Alt-R/Alt-F, Alt-V has NO standalone_group_transform (no issue-0116 group
       * form): the standalone apply is always the per-object in-place flip, so the WHOLE
       * apply crosses the boundary here. ROTATELOCAL pivots each object about its own origin,
       * so the mx/my_double_save previously seeded here was immaterial to the transform. */
      perform_action("flipv_in_place", 0, NULL);
    }
  }
  return 1;
}

/* --- action registry: stable id -> behavior --- */
/* An action is backed by EITHER a C function (fn) OR a Tcl command (tcl); exactly
 * one is non-NULL. Tcl-backing (Phase 3d) lets the ~60 tcleval keysym branches
 * become data without a throwaway C wrapper per command.
 * log_cmd (action-log Layer A slice 2) is the canonical replayable Tcl command
 * recorded when a C-BACKED action dispatches. It is NEVER initialized here:
 * xschem.tcl pushes it from actions.csv (the single source, col 'command') at
 * startup via `xschem set_action_log_cmd`, gated by the csv 'nolog' column for
 * ids whose csv command is not behavior-equivalent to fn. Tcl-backed actions
 * log their `tcl` directly and ignore this field.
 * nolog (Phase 3 slice D) suppresses Layer A logging for TCL-backED actions
 * too -- set from the same csv column via `xschem set_action_nolog`. Used by
 * the gesture-START ids (xschem wire / move_objects / place_symbol ...):
 * their effect is logged at the gesture END (Layer C), so the start would be
 * a second line for the same gesture -- and two of them open dialogs when a
 * log is sourced. An aborted gesture thus leaves no trace, which matches the
 * spec's granularity rule (log the effect; an abort has none). */
typedef struct { const char *id; action_fn fn; const char *tcl; const char *help;
                 int mutates; char *log_cmd; int nolog; } ActionDef;
/* mutates (issue 0041): 1 if this action changes the current schematic/symbol contents,
 * so a read-only window refuses it (see action_id_mutates / readonly_block). Declared per
 * row below (the positional 5th field; omitted rows default to 0) instead of a separate
 * hand-maintained allowlist, so a new mutating action is covered by construction. Dual-use
 * self-gating actions (e.g. edit.add_pin_stubs, which also pans on read-only) stay 0 and
 * are guarded at their core so the shared key still works. */

static ActionDef action_registry[] = {
  { "view.zoom_in",   act_zoom_in,   NULL, "Zoom in"   },
  { "view.zoom_out",  act_zoom_out,  NULL, "Zoom out"  },
  { "view.zoom_full", act_zoom_full, NULL, "Zoom full" },
  { "view.pan_left",  act_pan_left,  NULL, "Pan left"  },
  { "view.pan_right", act_pan_right, NULL, "Pan right" },
  { "view.pan_up",    act_pan_up,    NULL, "Pan up"    },
  { "view.pan_down",  act_pan_down,  NULL, "Pan down"  },
  { "view.scroll_up",    act_scroll_up,    NULL, "Scroll up (Up arrow)"       },
  { "view.scroll_down",  act_scroll_down,  NULL, "Scroll down (Down arrow)"   },
  { "view.scroll_left",  act_scroll_left,  NULL, "Scroll left (Left arrow)"   },
  { "view.scroll_right", act_scroll_right, NULL, "Scroll right (Right arrow)" },
  { "view.zoom_rect", act_zoom_rect_start, NULL, "Zoom to rectangle (drag)" },
  { "graph.forward",  act_graph_forward,   NULL, "Forward event to the waveform graph" },
  /* Tcl-backed (Phase 3d.1): fn is NULL, the dispatch runs `tcl` via tcleval.
   * (id renamed at d4a to the pre-existing actions.csv id for the same command.) */
  { "prop.edit_header_license_text", NULL, "update_schematic_header", "Edit schematic header/license", 1 },
  /* Phase 3d.2 — canvas-only symbol commands (C-backed and Tcl-backed). */
  { "sym.attach_net_labels_to_component_instance", act_attach_labels, NULL,
    "Attach net labels to selected instances", 1 },
  { "sym.make_schematic_and_symbol_from_selected_components", act_make_sch_sym_from_sel, NULL,
    "Make schematic and symbol from selected components", 1 /* mutates: delete sel + place LCC (0041) */ },
  { "sym.create_symbol_pins_from_selected_schematic_pins", NULL, "schpins_to_sympins",
    "Create symbol pins from selected schematic pins", 1 },
  { "sym.place_symbol_pin", NULL, "xschem add_symbol_pin",
    "Add a symbol pin (Name + Direction dialog)", 1 },
  { "tools.insert_polygon", NULL, "xschem polygon gui", "Start drawing a polygon", 1 },
  /* graphic-line placement, migrated off the plain-'l' switch case so 'l' can host the
   * Add-Wire-Label form (add_wire_label.md). Default chord Shift+L (see init_input_bindings). */
  { "tools.insert_line", NULL, "xschem line gui", "Start drawing a line", 1 },
  { "view.center_at_cursor", act_view_center_at_cursor, NULL,
    "Center the view on the cursor position" },
  /* Phase 3d.2 batch 2 — clean canvas-only command keys (C-backed). All ids below
   * have actions.csv rows (label/help metadata) since d4a. */
  { "edit.toggle_stretch", act_toggle_stretch, NULL, "Toggle stretching of attached wires" },
  { "view.snap_half",   act_snap_half,   NULL, "Halve the snap factor" },
  { "view.snap_double", act_snap_double, NULL, "Double the snap factor" },
  { "prop.toggle_ignore_attribute_on_selected_instances", act_toggle_ignore, NULL,
    "Toggle *_ignore attribute on selected instances", 1 },
  { "view.toggle_colorscheme", act_toggle_colorscheme, NULL, "Toggle light/dark colorscheme" },
  /* Phase 3d.2 batch 3 — three C-backed plus `=` reusing the csv id
   * tools.execute_tcl_command (Tcl-backed -> "tclcmd"). */
  { "view.toggle_show_netlist", act_toggle_show_netlist, NULL, "Toggle the show-netlist window" },
  { "edit.toggle_orthogonal_wiring", act_toggle_orthogonal_wiring, NULL, "Toggle orthogonal (manhattan) wiring" },
  { "view.toggle_draw_pixmap", act_toggle_draw_pixmap, NULL, "Toggle pixmap (off-screen) drawing" },
  { "tools.execute_tcl_command", NULL, "tclcmd", "Open the Tcl command console" },
  /* tools.raise_ciw: raise (or open) the CIW command window. Tcl-backed -- ciw_create
   * builds the CIW, or deiconifies + raises it if it already exists. Default chord
   * Alt-F5 (seeded in init_input_bindings below, mirrored in keybindings.csv). Rebind
   * or un-bind from a custom rc / --script with e.g.
   *   xschem bind key 65474 alt canvas tools.raise_ciw   ;# move to another chord
   *   xschem unbind key 65474 alt canvas                 ;# un-bind Alt-F5 */
  { "tools.raise_ciw", NULL, "ciw_create", "Raise/open the CIW (Command Interpreter Window)" },
  /* Phase 3d.2 sem-gated batch 1 — Tcl-backed, reusing actions.csv ids whose commands
   * are verified identical to the switch branches' C calls (idle_only-bound below). */
  { "toolbar.netlist",      NULL, "xschem netlist -erc",      "Netlist (hierarchical) + ERC" },
  { "file.clear_schematic", NULL, "xschem clear schematic",   "Clear the current schematic", 1 },
  { "edit.redo",            NULL, "xschem redo; xschem redraw", "Redo", 1 },
  { "edit.undo",            NULL, "xschem undo; xschem redraw", "Undo", 1 },
  /* Phase 3d.2 sem-gated batch 2 — the hilight cluster (k, K). Tcl commands verified
   * byte-identical to the switch C branches (incl. the redraw_hilights/draw calls). */
  { "hilight.highlight_selected_net_pins",           NULL, "xschem hilight",            "Highlight selected net/pins" },
  { "hilight.un_highlight_selected_net_pins",        NULL, "xschem unhilight",          "Un-highlight selected net/pins" },
  { "hilight.select_hilight_nets_pins",              NULL, "xschem select_hilight_net", "Select highlighted nets/pins" },
  /* logical (net-name) connected select -- see act_select_same_net above. Non-mutating. */
  { "select.same_net_by_label",     act_select_same_net,     NULL,
    "Select the whole net under the pointer, including label-connected segments" },
  { "select.same_net_by_label_add", act_select_same_net_add, NULL,
    "Add the net under the pointer (incl. label-connected segments) to the selection" },
  { "hilight.un_highlight_all_net_pins",             NULL, "xschem unhilight_all",      "Un-highlight all net/pins" },
  { "hilight.propagate_highlight_selected_net_pins", NULL, "xschem hilight drill",      "Propagate highlight (drill)" },
  /* Phase 3d.2 sem-gated batch 3 — `j` hilight-list (branch migration). Tcl commands
   * are `xschem print_hilight_net N` = print_hilight_net(N), identical to the switch. */
  { "sym.list.print_list_of_highlight_nets",    NULL, "xschem print_hilight_net 1", "Print list of highlight nets" },
  { "sym.list.create_pins_from_highlight_nets", NULL, "xschem print_hilight_net 0", "Create pins from highlight nets", 1 },
  { "sym.list.create_labels_from_highlight_nets", NULL, "xschem print_hilight_net 4", "Create labels from highlight nets", 1 },
  /* keybind_snap_grid_actions: snap / grid / highlight ops made bindable; they ship
   * UNBOUND (no default chord) — the user binds them via `xschem bind` / their rc.
   * Two Tcl-backed (reuse the View/Options menu commands), one C-backed (sim-tool
   * detection). doc/claude/specs/keybind_snap_grid_actions.md. */
  /* nolog (0066): input_line is async -- it returns before the user types, so the
   * dispatcher would log this dialog-OPEN prompt string as a bogus line while the
   * resolved value logs later at the `set cadsnap` core. Suppress the prompt; the
   * core self-log emits the one replayable `xschem set cadsnap <value>` line.
   * (fn, tcl, help, mutates=0, log_cmd=NULL, nolog=1) */
  { "view.set_snap_value", NULL,
    "input_line {Enter snap value (float):} {xschem set cadsnap} $cadsnap", "Set snap value (dialog)",
    0, NULL, 1 },
  { "view.toggle_draw_grid", NULL,
    "set draw_grid [expr {!$draw_grid}]; xschem redraw", "Toggle grid display" },
  { "hilight.send_to_waveform", act_highlight_send_waveform, NULL,
    "Highlight net and send to waveform viewer" },
  /* bus_thickness_scroll: grow/shrink every selected object (wire thickness, and the
   * [N:M] bus suffix on pin/netlabel `lab` or instance `name`). Tcl-backed: the logic
   * lives in utils/bus_resize.tcl (busresize_apply), sourced by cadence_style_rc. Ship
   * UNBOUND; cadence_style_rc binds them to Alt-wheel, any user can rebind via
   * `xschem bind`. doc/claude/specs/bus_thickness_scroll.md. */
  { "edit.grow_selection",   NULL, "busresize_apply grow",
    "Grow selected: wire thickness / bus width [N:M]", 1 },
  { "edit.shrink_selection", NULL, "busresize_apply shrink",
    "Shrink selected: wire thickness / bus width [N:M]", 1 },
  /* bus_transpose_scroll: SHIFT the bus index/range up/down by 1 on a pin/netlabel `lab`
   * or an instance `name` (wires/text tolerated) -- moves the index, does not widen the
   * bus (that is busresize). Tcl-backed: utils/bus_transpose.tcl. Ship UNBOUND;
   * cadence_style_rc binds them to Alt+Shift-wheel. doc/claude/specs/bus_transpose_scroll.md. */
  { "edit.transpose_up_selection",   NULL, "bustranspose_apply up",
    "Transpose selected up: bus index/range +1 (e.g. [N:M] -> [N+1:M+1])", 1 },
  { "edit.transpose_down_selection", NULL, "bustranspose_apply down",
    "Transpose selected down: bus index/range -1, floored at 0", 1 },
  /* text_size_scroll: grow/shrink displayed text size of selected text notes and
   * pin/netlabel names (~10%, min step, per-type floor). Tcl-backed:
   * utils/text_resize.tcl. Ship UNBOUND; cadence_style_rc binds Ctrl+Plus/Minus.
   * doc/claude/specs/text_size_scroll.md. */
  { "edit.text_grow",   NULL, "textsize_apply grow",
    "Grow displayed text size of selected notes / pin-label names", 1 },
  { "edit.text_shrink", NULL, "textsize_apply shrink",
    "Shrink displayed text size of selected notes / pin-label names", 1 },
  /* deselect-one-at-a-time mode (doc/claude/specs/deselect_one_mode.md): default key 'd'.
   * C-backed; the csv command `xschem deselect_mode` is behavior-equivalent but nolog'd
   * (mode entry is a UI affordance; its effect — the deselect clicks — is not logged). */
  { "edit.deselect_mode", act_deselect_mode, NULL,
    "Deselect one object at a time (click a selected object; ESC to end)" },
  /* B6 wire-stubs (doc/claude/specs/wire_stub_netlabel.md): SPACE's three behaviors,
   * now separately rebindable actions. edit.add_pin_stubs is the SPACE default; it
   * self-gates and declines (dispatch falls through to case ' ') during a gesture or
   * with no selection, so cycle_manhattan (mid-gesture) and pan (idle) still run from
   * the same extracted cores. cycle_manhattan + pan ship UNBOUND (bind via
   * keybindings.csv) so the user can move the manhattan-corner cycle onto another key. */
  { "edit.add_pin_stubs", act_add_pin_stubs, NULL,
    "Add wire stubs + net-labels to selected pins / instance pins" },
  { "edit.cycle_manhattan", act_cycle_manhattan, NULL,
    "Cycle the manhattan corner of an in-progress move/wire/line" },
  { "view.pan", act_pan, NULL, "Drag-pan the canvas" },
  /* Alt-2: toggle the current window's view TYPE (schematic <-> symbol) of the same
   * cell. Tcl-backed (src/alt2_toggle_view.tcl). mutates=0 -- the toggle changes no
   * schematic content. See doc/claude/specs/alt2_toggle_view.md. */
  { "view.toggle_view_type", NULL, "alt2_toggle_view",
    "Open the alternate view (schematic<->symbol) of the current cell" },
  /* Schematic/symbol Add-Pin (doc/claude/specs/schematic_add_pin.md): while a pin preview is
   * attached to the cursor, cycle its direction/type (input/output/inout, i.e.
   * ipin<->opin<->iopin in a schematic) and re-arm the current name. Tcl-backed
   * (addpin::cycle_type). Default chord Ctrl+Button2 (seeded in init_input_bindings, mirrored
   * in mousebindings.csv); rebind with `xschem bind`. mutates=0: it only re-arms an
   * undo-managed preview -- no standalone content change. */
  { "edit.cycle_pin_type", NULL, "addpin::cycle_type",
    "Cycle the direction/type (input/output/inout) of the pin being placed",
    0 /* mutates */, NULL /* log_cmd */, 1 /* nolog: GUI-only chord, self-guards, not replayable */ },
  /* Cadence-style Add Wire Label form (add_wire_label.md): open the modeless net-label form
   * (typed name queue -> lab_pin instances, bus split, drop-on-copper constraint). Tcl-backed;
   * mutates=0 -- opening the dialog changes nothing; the -place/-drop verbs own their undo.
   * Default key 'l' (init_input_bindings). Rebindable. */
  { "edit.add_wire_label", NULL, "xschem add_wire_label",
    "Open the Add Wire Label form (place net labels)" },
  /* TWO-PANE item 17 (R10): the schematic's "Show in Signal Browser" reaches the C
   * table, so the chord is REMAPPABLE (`xschem bind` / keybindings.csv) and works in
   * every profile. It used to be a `bind .drw <Control-Key-5>` in src/cadence_style_rc,
   * which only cadence-profile users ever loaded while the Tools cascade advertised
   * the accelerator to everyone. Tcl-backed, fn NULL.
   * ⚠ THE COMMAND TAKES NO WINDOW ARGUMENT, ON PURPOSE. dispatch_input_action runs a
   * CONSTANT string -- there is no %-substitution -- so the Tcl side must be the
   * `{win {}}` (current-context) arm of ase::show_in_browser_for_current, and the
   * logged replay line is context-free BY DESIGN rather than by accident. The menu
   * entry (src/xschem.tcl) still passes ${topwin}.drw: a menu click knows its window,
   * a key press is already IN one.
   * mutates=0: revealing a hierarchy position changes no schematic content, so it
   * works in a read-only view. See doc/claude/specs/waveform_signal_browser_two_pane.md
   * and doc/claude/signal_browser_2pane_batch/PLAN.md item 17. */
  { "wave.show_in_signal_browser", NULL, "ase::show_in_browser_for_current",
    "Show in Signal Browser" },
  /* In-place transforms, defaults Alt-R / Alt-F / Alt-V (plus the Super twins), migrated
   * out of the hardcoded switch so the chords are remappable -- see the block comment above
   * act_rotate_in_place and src/cadence_style_rc. mutates=1: dispatch_input_action's
   * readonly gate replaces the readonly_block() each arm used to call. log_cmd stays NULL
   * (label-only actions.csv rows, empty command): the standalone arms self-log at the
   * perform_action boundary and the mid-drag arms must not log at all. */
  { "edit.rotate_in_place", act_rotate_in_place, NULL,
    "Rotate in place (selection, or the objects being dragged)", 1 },
  { "edit.flip_in_place", act_flip_in_place, NULL,
    "Horizontal flip in place (selection, or the objects being dragged)", 1 },
  { "edit.flipv_in_place", act_flipv_in_place, NULL,
    "Vertical flip in place (selection, or the objects being dragged)", 1 },
};
static const int num_action_defs = (int)(sizeof(action_registry)/sizeof(action_registry[0]));

/* resolve an action id to its definition (C fn or Tcl command), or NULL if unknown */
static const ActionDef *find_action_def(const char *id)
{
  int i;
  for(i = 0; i < num_action_defs; ++i)
    if(!strcmp(action_registry[i].id, id)) return &action_registry[i];
  return NULL;
}

/* --- binding table: input signature -> action id (mutable; the "where") --- */
typedef struct {
  int  device;        /* DEV_*  */
  int  code;          /* WHEEL_*, button number, or KeySym */
  int  mods;          /* normalized modifier mask */
  int  ctx;           /* ACTX_* */
  int  idle_only;     /* Phase 3d.1b: skip this chord while busy (semaphore>=2) */
  char action_id[64];
} InputBinding;

#define MAX_INPUT_BINDINGS 256
static InputBinding input_bindings[MAX_INPUT_BINDINGS];
static int num_input_bindings = 0;
static int input_bindings_initialized = 0;

/* find the binding for an exact signature, or NULL */
static InputBinding *find_binding(int device, int code, int mods, int ctx)
{
  int i;
  for(i = 0; i < num_input_bindings; ++i) {
    InputBinding *b = &input_bindings[i];
    if(b->device==device && b->code==code && b->mods==mods && b->ctx==ctx) return b;
  }
  return NULL;
}

/* install or replace the action bound to a signature; returns 0, or -1 if the
 * table is full. Does not validate the action id (callers reject unknown ids
 * first where appropriate). */
static int set_input_binding(int device, int code, int mods, int ctx, const char *id)
{
  InputBinding *b = find_binding(device, code, mods, ctx);
  if(b) { my_strncpy(b->action_id, id, S(b->action_id)); return 0; }
  if(num_input_bindings >= MAX_INPUT_BINDINGS) return -1;
  input_bindings[num_input_bindings].device    = device;
  input_bindings[num_input_bindings].code      = code;
  input_bindings[num_input_bindings].mods      = mods;
  input_bindings[num_input_bindings].ctx       = ctx;
  input_bindings[num_input_bindings].idle_only = 0;  /* default; set_input_binding_idle flips it */
  my_strncpy(input_bindings[num_input_bindings].action_id, id,
             S(input_bindings[num_input_bindings].action_id));
  num_input_bindings++;
  return 0;
}

/* Phase 3d.1b: install a binding marked "idle only" — the DEV_KEY dispatch skips it
 * (and the side-effectful graph context) while the editor is busy (semaphore>=2),
 * reproducing the `if(xctx->semaphore>=2) break;` that guarded these switch chords. */
static int set_input_binding_idle(int device, int code, int mods, int ctx, const char *id)
{
  InputBinding *b;
  int r = set_input_binding(device, code, mods, ctx, id);
  b = find_binding(device, code, mods, ctx);
  if(b) b->idle_only = 1;
  return r;
}

/* true if any DEV_KEY binding for this chord is idle-only (busy-skip) */
static int key_chord_is_idle_only(int code, int mods)
{
  int i;
  for(i = 0; i < num_input_bindings; ++i) {
    InputBinding *b = &input_bindings[i];
    if(b->device==DEV_KEY && b->code==code && b->mods==mods && b->idle_only) return 1;
  }
  return 0;
}

/* remove the binding for a signature; returns 1 if one was removed, else 0 */
static int unset_input_binding(int device, int code, int mods, int ctx)
{
  int i;
  for(i = 0; i < num_input_bindings; ++i) {
    InputBinding *b = &input_bindings[i];
    if(b->device==device && b->code==code && b->mods==mods && b->ctx==ctx) {
      input_bindings[i] = input_bindings[--num_input_bindings];
      return 1;
    }
  }
  return 0;
}

/* built-in defaults: reproduce the previous hard-coded wheel handling exactly */
static void init_input_bindings(void)
{
  num_input_bindings = 0;
  set_input_binding(DEV_WHEEL, WHEEL_UP,   0,           ACTX_CANVAS, "view.zoom_in");
  set_input_binding(DEV_WHEEL, WHEEL_DOWN, 0,           ACTX_CANVAS, "view.zoom_out");
  set_input_binding(DEV_WHEEL, WHEEL_UP,   ShiftMask,   ACTX_CANVAS, "view.pan_left");
  set_input_binding(DEV_WHEEL, WHEEL_DOWN, ShiftMask,   ACTX_CANVAS, "view.pan_right");
  set_input_binding(DEV_WHEEL, WHEEL_UP,   ControlMask, ACTX_CANVAS, "view.pan_up");
  set_input_binding(DEV_WHEEL, WHEEL_DOWN, ControlMask, ACTX_CANVAS, "view.pan_down");
  set_input_binding(DEV_BUTTON, Button3,   0,           ACTX_CANVAS, "view.zoom_rect");
  /* Ctrl+Middle-click cycles the pin direction/type while placing (schematic_add_pin.md).
   * Button2-pan requires state==0, so this exact-Ctrl chord never collides with the pan. */
  set_input_binding(DEV_BUTTON, Button2,   ControlMask, ACTX_CANVAS, "edit.cycle_pin_type");
  /* ⚠ THESE FOUR ROWS ARE UNREACHABLE, and the claim they used to carry
   * ("Ctrl-wheel never did, so it has no over_graph row and stays canvas pan")
   * was wrong over a graph -- landmine 48 in
   * doc/claude/code_analysis/waveform_subsystem_reference.md.
   *
   * handle_button_press() opens with an inline
   * `if(waves_selected(...)) { waves_callback(...); return; }`, and
   * handle_mouse_wheel() is only reached FOURTEEN branches later. So for any
   * wheel press whose pointer is inside a graph rect the function has already
   * returned, and handle_mouse_wheel's own ctx -- computed from that same
   * waves_selected() -- can then only ever be ACTX_CANVAS. A binding row is
   * therefore NOT a way to add or change an over-graph wheel gesture: that is
   * decided inside waves_callback (see the CTRL+wheel axis zoom, issue 0191).
   * MEASURED: Ctrl+wheel over a strip is a graph X PAN, byte-identical to the
   * plain wheel, and xorigin/yorigin/zoom never move.
   *
   * The rows are kept, not deleted: they are inert, and removing them has its
   * own regression surface (`xschem bind` / keybindings.csv round-trip). */
  set_input_binding(DEV_WHEEL, WHEEL_UP,   0,         ACTX_OVER_GRAPH, "graph.forward");
  set_input_binding(DEV_WHEEL, WHEEL_DOWN, 0,         ACTX_OVER_GRAPH, "graph.forward");
  set_input_binding(DEV_WHEEL, WHEEL_UP,   ShiftMask, ACTX_OVER_GRAPH, "graph.forward");
  set_input_binding(DEV_WHEEL, WHEEL_DOWN, ShiftMask, ACTX_OVER_GRAPH, "graph.forward");
  /* Phase 3c c4/c5: context-routed keys become data. Plain 'f' over a graph
   * forwards to the waveform handler (the old inline waves_selected guard, now a
   * row); on the canvas it runs view.zoom_full. Other 'f' chords (Ctrl=search,
   * Alt=flip) are NOT migrated, so they stay in the handle_key_press switch. */
  set_input_binding(DEV_KEY, 'f', 0, ACTX_CANVAS,     "view.zoom_full");
  set_input_binding(DEV_KEY, 'f', 0, ACTX_OVER_GRAPH, "graph.forward");
  /* arrow keys: only the NO-MODIFIER scroll is migrated (canvas scroll / forward
   * over a graph). Modified arrows stay in the switch — Ctrl+Left/Right are tab
   * switching, and Up/Down historically pan under *any* modifier; those chords have
   * no rows here so they fall through unchanged. mods for named keysyms = raw state,
   * so a plain arrow press (state 0) matches these rows. */
  set_input_binding(DEV_KEY, XK_Up,    0, ACTX_CANVAS,     "view.scroll_up");
  set_input_binding(DEV_KEY, XK_Up,    0, ACTX_OVER_GRAPH, "graph.forward");
  set_input_binding(DEV_KEY, XK_Down,  0, ACTX_CANVAS,     "view.scroll_down");
  set_input_binding(DEV_KEY, XK_Down,  0, ACTX_OVER_GRAPH, "graph.forward");
  set_input_binding(DEV_KEY, XK_Left,  0, ACTX_CANVAS,     "view.scroll_left");
  set_input_binding(DEV_KEY, XK_Left,  0, ACTX_OVER_GRAPH, "graph.forward");
  set_input_binding(DEV_KEY, XK_Right, 0, ACTX_CANVAS,     "view.scroll_right");
  set_input_binding(DEV_KEY, XK_Right, 0, ACTX_OVER_GRAPH, "graph.forward");
  /* Ctrl+Left/Right switch tabs on the canvas (that behavior stays in the switch);
   * over a graph they forward, exactly as the old inline guard did. Routing-only:
   * over_graph row, no canvas row. Exact chord (state==ControlMask), waves-first. */
  set_input_binding(DEV_KEY, XK_Left,  ControlMask, ACTX_OVER_GRAPH, "graph.forward");
  set_input_binding(DEV_KEY, XK_Right, ControlMask, ACTX_OVER_GRAPH, "graph.forward");
  /* Group B (Phase 3c): keys whose *canvas* behavior stays in the C switch, but
   * whose graph-vs-canvas *routing* becomes data. Only an over_graph row is added
   * (no canvas row); on the canvas the dispatch finds nothing and falls through to
   * the switch, which runs the original behavior. Seeded only for the EXACT chords
   * (== 0 / == ControlMask) whose inline waves guard had no preceding semaphore
   * check — so hoisting the forward to the top dispatch is behavior-preserving. */
  set_input_binding(DEV_KEY, 'a', ControlMask, ACTX_OVER_GRAPH, "graph.forward"); /* select all */
  set_input_binding(DEV_KEY, 'A', 0,           ACTX_OVER_GRAPH, "graph.forward"); /* toggle show netlist */
  set_input_binding(DEV_KEY, 'A', ControlMask, ACTX_OVER_GRAPH, "graph.forward"); /* graph-only (hcursor1) */
  /* TWO-PANE item 16 (R9): the Ctrl+b over_graph row is GONE. The waveform
   * viewer's Signal Browser moved to Ctrl-B (doc/claude/specs/
   * waveform_signal_browser_two_pane.md §8.1), and wave_viewer.tcl's key_filter
   * now refuses to forward 98 under ControlMask, so nothing in the viewer can
   * reach this row any more. Consequence, declared rather than hidden (spec §10
   * limit 9): over a graph EMBEDDED IN A SCHEMATIC Ctrl+b falls through to the
   * switch below and toggles sym_txt, like it always did on bare canvas.
   * Pinned by tests/headless/test_key_graph_context.tcl. The BARE-b idle
   * over_graph row further down is NOT deleted -- bare `b` still forwards. */
  set_input_binding(DEV_KEY, 'B', 0,           ACTX_OVER_GRAPH, "graph.forward"); /* edit header */
  set_input_binding(DEV_KEY, 'B', ControlMask, ACTX_OVER_GRAPH, "graph.forward"); /* graph-only (hcursor2) */
  /* Phase 3d.1: 'B' canvas behavior is now a Tcl-backed action; with this row the
   * whole `case 'B'` is data and was deleted from the switch (first fully-migrated key). */
  set_input_binding(DEV_KEY, 'B', 0,           ACTX_CANVAS,     "prop.edit_header_license_text");
  /* Phase 3d.2: canvas-only command keys (no over_graph row — they never forwarded
   * to a graph). With the dispatch refinement, a canvas-only chord uses ACTX_CANVAS
   * directly, so deleting their switch cases is correct even over a graph. */
  set_input_binding(DEV_KEY, 'H', 0,           ACTX_CANVAS, "sym.attach_net_labels_to_component_instance");
  set_input_binding(DEV_KEY, 'H', ControlMask, ACTX_CANVAS, "sym.make_schematic_and_symbol_from_selected_components");
  /* Alt-h (EQUAL_MODMASK = Alt OR Super in the switch) -> two rows */
  set_input_binding(DEV_KEY, 'h', Mod1Mask,    ACTX_CANVAS, "sym.create_symbol_pins_from_selected_schematic_pins");
  set_input_binding(DEV_KEY, 'h', Mod4Mask,    ACTX_CANVAS, "sym.create_symbol_pins_from_selected_schematic_pins");
  set_input_binding_idle(DEV_KEY, 'p', 0,      ACTX_CANVAS, "sym.place_symbol_pin");  /* P -> add pin dialog */
  set_input_binding_idle(DEV_KEY, 'P', 0,      ACTX_CANVAS, "tools.insert_polygon");  /* Shift+P -> polygon */
  /* view.center_at_cursor ships UNBOUND (old Shift+P pan); bind a key in keybindings.csv */
  /* Phase 3d.2 batch 2: plain-chord command keys (the cases' Ctrl/Alt branches stay in C). */
  set_input_binding(DEV_KEY, 'y', 0, ACTX_CANVAS, "edit.toggle_stretch");
  /* snap/grid/highlight ops ship UNBOUND — no default chord; the user binds them via
   * `xschem bind` / their rc (doc/claude/specs/keybind_snap_grid_actions.md). The old 'g'/'G'
   * snap defaults were removed here (keybindings.csv regenerated to match). */
  set_input_binding(DEV_KEY, 'T', 0, ACTX_CANVAS, "prop.toggle_ignore_attribute_on_selected_instances");
  set_input_binding(DEV_KEY, 'O', 0, ACTX_CANVAS, "view.toggle_colorscheme");
  /* Phase 3d.2 batch 3: A is graph-routed (over_graph rows above at 'A'); adding its
   * canvas row makes the whole case data. L/=/$ are canvas-only (no over_graph row),
   * so only their plain-chord switch branch is deleted (Ctrl/Alt branches stay in C). */
  set_input_binding(DEV_KEY, 'A', 0, ACTX_CANVAS, "view.toggle_show_netlist");
  /* add_wire_label.md (user-ratified): plain 'l' opens the Add-Wire-Label form (was: start a
   * graphic line -- that switch case is now shadowed and relocated to Shift+L below). Shift+L
   * hosts the graphic line (was: edit.toggle_orthogonal_wiring, which now ships UNBOUND -- rebind
   * via keybindings.csv / `xschem bind`, same pattern as view.center_at_cursor). Both are freely
   * reconfigurable from a user rc/script. */
  set_input_binding_idle(DEV_KEY, 'l', 0, ACTX_CANVAS, "edit.add_wire_label");
  set_input_binding(DEV_KEY, 'L', 0, ACTX_CANVAS, "tools.insert_line");
  set_input_binding(DEV_KEY, '=', 0, ACTX_CANVAS, "tools.execute_tcl_command");
  set_input_binding(DEV_KEY, '$', 0, ACTX_CANVAS, "view.toggle_draw_pixmap");
  /* 't': plain (place text) is an EXACT chord -> its switch guard is deleted like
   * the rest of Group B. Ctrl+t uses `rstate & ControlMask` (a FAMILY), so its guard
   * is KEPT but narrowed to `rstate != ControlMask`: the row below owns the exact
   * Ctrl+t chord, the guard still serves the Ctrl+<other mods> remainder. */
  set_input_binding(DEV_KEY, 't', 0,           ACTX_OVER_GRAPH, "graph.forward"); /* place text */
  set_input_binding(DEV_KEY, 't', ControlMask, ACTX_OVER_GRAPH, "graph.forward"); /* new schematic */
  /* Phase 3d.5a: the zoom chords the Phase-2 Tk intercept used to own (the intercept
   * is retired — a Tk key-detail binding pre-empted the generic <KeyPress>, hiding
   * these keys from this table). view_zoom/view_unzoom(0.0) default their factor to
   * CADZOOMSTEP, so the acts are identical to the old case 'Z' / Ctrl-'z' branches.
   * Canvas-only, no semaphore guard in the old code -> plain (non-idle) rows. */
  set_input_binding(DEV_KEY, 'Z', 0,           ACTX_CANVAS, "view.zoom_in");
  set_input_binding(DEV_KEY, 'z', ControlMask, ACTX_CANVAS, "view.zoom_out");
  /* Phase 3d.1b: the semaphore-first chords. Their switch branch is
   * `if(sem>=2)break; if(waves_selected){...;break;} <canvas>`. Migrate ONLY the graph
   * routing: an idle_only over_graph row forwards to the graph when idle, and the
   * dispatch skips it at semaphore>=2 (reproducing the deleted break). Canvas behavior
   * + the `if(sem>=2)break;` stay in C; only the inline waves guard is deleted.
   * (plain 's' and Ctrl+r are ALSO cadence_compat-gated — the table can't express that
   * mode — so they stay in C for now.) */
  set_input_binding_idle(DEV_KEY, 'a', 0,           ACTX_OVER_GRAPH, "graph.forward"); /* make symbol */
  set_input_binding_idle(DEV_KEY, 'b', 0,           ACTX_OVER_GRAPH, "graph.forward"); /* merge schematic */
  set_input_binding_idle(DEV_KEY, 'f', ControlMask, ACTX_OVER_GRAPH, "graph.forward"); /* property search */
  set_input_binding_idle(DEV_KEY, 's', ControlMask, ACTX_OVER_GRAPH, "graph.forward"); /* save */
  /* Phase 3d.2 sem-gated batch 1: fully-migrated sem-gated command keys. Each was
   * `if(sem>=2)break; <tcleval/C>` — now an idle_only CANVAS row (canvas-only, no graph
   * routing). The dispatch skips them at sem>=2; case 'n'/'U' are deleted whole, case
   * 'u' keeps its Alt/Ctrl branches. Tcl commands verified identical to the C branches. */
  set_input_binding_idle(DEV_KEY, 'n', 0,           ACTX_CANVAS, "toolbar.netlist");      /* hierarchical netlist+erc */
  set_input_binding_idle(DEV_KEY, 'n', ControlMask, ACTX_CANVAS, "file.clear_schematic"); /* clear schematic */
  set_input_binding_idle(DEV_KEY, 'U', 0,           ACTX_CANVAS, "edit.redo");            /* redo */
  set_input_binding_idle(DEV_KEY, 'u', 0,           ACTX_CANVAS, "edit.undo");            /* undo */
  /* Phase 3d.2 sem-gated batch 2: the hilight cluster (k, K), both cases deleted whole.
   * k/K plain+Ctrl are sem-gated -> idle_only; k Alt (select_hilight_net) has NO sem
   * guard -> non-idle (EQUAL_MODMASK = Mod1 or Mod4 -> two rows). All canvas-only. */
  set_input_binding_idle(DEV_KEY, 'k', 0,           ACTX_CANVAS, "hilight.highlight_selected_net_pins");
  set_input_binding_idle(DEV_KEY, 'k', ControlMask, ACTX_CANVAS, "hilight.un_highlight_selected_net_pins");
  set_input_binding     (DEV_KEY, 'k', Mod1Mask,    ACTX_CANVAS, "hilight.select_hilight_nets_pins"); /* Alt, non-idle */
  set_input_binding     (DEV_KEY, 'k', Mod4Mask,    ACTX_CANVAS, "hilight.select_hilight_nets_pins"); /* Super, non-idle */
  set_input_binding_idle(DEV_KEY, 'K', 0,           ACTX_CANVAS, "hilight.un_highlight_all_net_pins");
  set_input_binding_idle(DEV_KEY, 'K', ControlMask, ACTX_CANVAS, "hilight.propagate_highlight_selected_net_pins");
  /* Phase 3d.2 sem-gated batch 3: `j` hilight-list, BRANCH migration. The 3 exact-chord
   * sem-gated branches become idle_only canvas rows; case 'j' keeps its 4th branch
   * (SET_MODMASK && Ctrl -> print_hilight_net(3), a non-sem family). All canvas-only. */
  set_input_binding_idle(DEV_KEY, 'j', 0,           ACTX_CANVAS, "sym.list.print_list_of_highlight_nets");
  set_input_binding_idle(DEV_KEY, 'j', ControlMask, ACTX_CANVAS, "sym.list.create_pins_from_highlight_nets");
  set_input_binding_idle(DEV_KEY, 'j', Mod1Mask,    ACTX_CANVAS, "sym.list.create_labels_from_highlight_nets"); /* Alt */
  set_input_binding_idle(DEV_KEY, 'j', Mod4Mask,    ACTX_CANVAS, "sym.list.create_labels_from_highlight_nets"); /* Super */
  /* deselect-one-at-a-time mode (doc/claude/specs/deselect_one_mode.md): default key 'd'.
   * Canvas-only (never forwarded to a graph); idle-gated so the mode is not entered while
   * a modal dialog is up (semaphore>=2). Replaces the old hardcoded `case 'd'` deselect. */
  set_input_binding_idle(DEV_KEY, 'd', 0,           ACTX_CANVAS, "edit.deselect_mode");
  /* ... but OVER A GRAPH 'd' creates a marker with a delta measurement
   * (doc/claude/specs/graph_markers.md). Without this row current_input_ctx
   * resolves ACTX_CANVAS even over a strip and deselect-one mode was entered
   * there. Routing-only: the canvas row above is untouched, so `d` off a graph
   * is byte-for-byte unchanged. Non-idle by choice, but note the chord-wide
   * idle gate: key_chord_is_idle_only() matches on device+code+mods and is
   * context-blind, so `d` still does nothing while a modal dialog is up. */
  set_input_binding(DEV_KEY, 'd', 0,                ACTX_OVER_GRAPH, "graph.forward");
  /* B6 wire-stubs (doc/claude/specs/wire_stub_netlabel.md): SPACE -> edit.add_pin_stubs.
   * Canvas-only, idle_only: SPACE now triggers a MUTATING edit (add_pin_stubs), which must
   * not run re-entrantly while the editor is busy (semaphore>=2, e.g. under a modal dialog).
   * When busy the dispatch skips this chord and SPACE falls through to case ' ', reproducing
   * the historical SAFE behavior (cycle an in-progress gesture's manhattan corner, else
   * drag-pan) with no edit -- exactly what the old hardcoded case ' ' did at semaphore>=2.
   * When idle it dispatches and self-gates (decline mid-gesture / empty selection -> dispatch
   * returns 0 -> case ' ' fallback runs the SAME cores). */
  set_input_binding_idle(DEV_KEY, ' ', 0, ACTX_CANVAS, "edit.add_pin_stubs");
  /* Alt-F5 raises (or opens) the CIW command window. Shipped default; mirrored in
   * keybindings.csv. A user overrides it by editing their USER_CONF_DIR
   * keybindings.csv, or at runtime from a custom rc/--script via `xschem bind key
   * 65474 alt canvas <action>` (or `xschem unbind key 65474 alt canvas`). Alt =
   * Mod1Mask, matching the other Alt chords above ('h', the j-cluster). */
  set_input_binding(DEV_KEY, XK_F5, Mod1Mask, ACTX_CANVAS, "tools.raise_ciw");
  /* TWO-PANE item 17 (R10): Ctrl-Alt-V reveals the schematic's hierarchy position (or
   * the selected instance's) in the waveform viewer's Signal Browser. 'v' == keysym
   * 118; Ctrl+Alt == ControlMask|Mod1Mask, matching the other Alt chords here, and a
   * physical Alt sets Mod1Mask in the X event. NOTHING COLLIDES: `case 'v'` in the C
   * switch has arms for rstate==0, rstate==ControlMask and EQUAL_MODMASK only, and
   * EQUAL_MODMASK is an EXACT test, so ControlMask|Mod1Mask matched nothing before
   * this row. Replaces the cadence-only `bind .drw <Control-Key-5>`.
   * ⚠ `event generate <Control-Alt-Key-v>` does NOT produce this chord -- Tk's `Alt`
   * PATTERN modifier is the virtual META bit, not Mod1. A test must drive
   * <Control-Mod1-Key-v> or `-state 12`. */
  set_input_binding(DEV_KEY, 'v', ControlMask|Mod1Mask, ACTX_CANVAS,
                    "wave.show_in_signal_browser");
  /* In-place transforms: Alt-R rotate, Alt-F horizontal flip, Alt-V vertical flip.
   * These were hardcoded `else if(EQUAL_MODMASK)` arms of the switch cases 'r'/'f'/'v';
   * EQUAL_MODMASK is `rstate == Mod1Mask || rstate == Mod4Mask`, so each key needs TWO
   * rows (Alt and Super) to keep the shipped behavior byte-identical. 'r'=114, 'f'=102,
   * 'v'=118. NON-idle on purpose: the arms had no `semaphore>=2` guard because they must
   * keep working DURING a move/copy drag (that is the whole point of Alt-R mid-drag).
   * Canvas-only -- no over_graph row, so the dispatch never consults the (side-effectful)
   * graph context for these chords. NOTHING COLLIDES: plain 'f' (view.zoom_full), plain/
   * Ctrl 'r' and 'v' and Ctrl-Alt-'v' (wave.show_in_signal_browser) are different chords.
   * Remap or un-bind from keybindings.csv or a custom rc, e.g.
   *   xschem bind key 114 ctrl+shift canvas edit.rotate_in_place
   *   xschem unbind key 118 alt canvas                              */
  set_input_binding(DEV_KEY, 'r', Mod1Mask, ACTX_CANVAS, "edit.rotate_in_place"); /* Alt-R   */
  set_input_binding(DEV_KEY, 'r', Mod4Mask, ACTX_CANVAS, "edit.rotate_in_place"); /* Super-R */
  set_input_binding(DEV_KEY, 'f', Mod1Mask, ACTX_CANVAS, "edit.flip_in_place");   /* Alt-F   */
  set_input_binding(DEV_KEY, 'f', Mod4Mask, ACTX_CANVAS, "edit.flip_in_place");   /* Super-F */
  set_input_binding(DEV_KEY, 'v', Mod1Mask, ACTX_CANVAS, "edit.flipv_in_place");  /* Alt-V   */
  set_input_binding(DEV_KEY, 'v', Mod4Mask, ACTX_CANVAS, "edit.flipv_in_place");  /* Super-V */
  /* Alt-2 toggles the current window between the schematic-type and symbol-type view
   * of the same cell (doc/claude/specs/alt2_toggle_view.md). Tcl-backed
   * (alt2_toggle_view). '2' == keysym 50; Alt = Mod1Mask. Plain '2' (logic level) and
   * Ctrl-2 (choose layer) still fall through to the C switch (exact code+mods match).
   * Kept LAST so it is the last key row when keybindings.csv is regenerated. */
  set_input_binding(DEV_KEY, '2', Mod1Mask, ACTX_CANVAS, "view.toggle_view_type");
  input_bindings_initialized = 1;
}

static void ensure_input_bindings(void)
{
  if(!input_bindings_initialized) init_input_bindings();
}

/* true if any DEV_KEY binding (in any context) exists for this keysym+mods chord.
 * The handle_key_press DEV_KEY dispatch uses this to gate itself: only a chord we
 * actually migrated consults the (side-effectful) graph context via
 * current_input_ctx/waves_selected, so un-migrated keys behave exactly as before
 * (Phase 3c c4/c5). */
static int key_chord_has_binding(int code, int mods)
{
  int i;
  ensure_input_bindings();
  for(i = 0; i < num_input_bindings; ++i) {
    InputBinding *b = &input_bindings[i];
    if(b->device==DEV_KEY && b->code==code && b->mods==mods) return 1;
  }
  return 0;
}

/* map an input event to its binding context: over a waveform graph, or the normal
 * schematic canvas. The single place that consults waves_selected for routing,
 * replacing the inline guards scattered through the handlers (Phase 3c). */
static int current_input_ctx(int event, KeySym key, int state, int button)
{
  return waves_selected(event, key, state, button) ? ACTX_OVER_GRAPH : ACTX_CANVAS;
}

/* Whether a registered (data-driven) action modifies the current schematic/symbol; used
 * to refuse it in a read-only window (see readonly_block). The classification now lives
 * with each action as the `mutates` column of action_registry[] (single source of truth),
 * so a newly-added mutating action is covered by construction rather than depending on a
 * separate allowlist being kept in sync here. Navigation/view/highlight/netlist and
 * make-symbol/create-schematic actions declare mutates=0 -- they do not change the current
 * view's contents. Unknown ids default to non-mutating. */
static int action_id_mutates(const char *id)
{
  const ActionDef *d = find_action_def(id);
  return d ? d->mutates : 0;
}

/* look up and run the action bound to an event signature; returns 1 if a binding
 * matched and ran, 0 otherwise. Most-specific-wins: try the event's own context,
 * then fall back to a context-independent (ACTX_GLOBAL) binding (Phase 3c). */
static int dispatch_input_action(const ActionEvent *e)
{
  InputBinding *b;
  const ActionDef *d;
  ensure_input_bindings();
  b = find_binding(e->device, e->code, e->mods, e->ctx);
  if(!b && e->ctx != ACTX_GLOBAL) b = find_binding(e->device, e->code, e->mods, ACTX_GLOBAL);
  if(!b) return 0;
  d = find_action_def(b->action_id);
  if(!d) return 0;
  /* read-only window: refuse mutating data-driven actions (undo/redo, clear,
   * attribute/pin/label edits); report consumed so the legacy switch is skipped. */
  if(action_id_mutates(b->action_id) && readonly_block()) return 1;
  if(d->fn) {                          /* C-backed behavior */
    /* Action log Layer A slice 2: record the canonical csv command, but only
     * after the fn reports it handled the event (record-after-evaluation, as
     * for the Tcl branch below). No log_cmd pushed -> silent: gesture starts,
     * graph routing and the not-yet-mintable view actions (spec: Phase 3). */
    int ret;
    actionlog_cmd_logged = 0;          /* dedup: skip log_cmd if the core self-logged */
    ret = d->fn(e);
    if(ret && d->log_cmd && !actionlog_cmd_logged) log_action("%s", d->log_cmd);
    return ret;
  }
  if(d->tcl) {                         /* Tcl-backed: run the command (Phase 3d.1) */
    /* Action log Layer A (spec §2): record the canonical command verbatim, AFTER
     * evaluation so a failed one becomes a '#' comment and the log stays
     * source-able (same rule as CIW-typed commands). Tcl_GlobalEval instead of
     * tcleval because the latter swallows the return code. A mutating subcommand
     * that self-logs at its core sets actionlog_cmd_logged; skip the wrapper line
     * then so the action is recorded exactly once (self-log-at-core dedup). */
    actionlog_cmd_logged = 0;
    if(Tcl_GlobalEval(interp, d->tcl) != TCL_OK) {
      fprintf(errfp, "dispatch_input_action(): evaluation of script: %s failed\n", d->tcl);
      fprintf(errfp, "         : %s\n", Tcl_GetStringResult(interp));
      if(!d->nolog && !actionlog_cmd_logged) log_action("# failed: %s", d->tcl);
      Tcl_ResetResult(interp);
    } else {
      if(!d->nolog && !actionlog_cmd_logged) log_action("%s", d->tcl);
    }
    return 1;
  }
  return 0;
}

/* dispatch a mouse-button chord (button + modifiers) through the binding table.
 * `state` here is already button-mask-stripped by the caller, so it is the clean
 * modifier mask. Returns 1 if a binding matched and ran (Phase 3b). */
static int dispatch_button_chord(int button, int state, int mx, int my)
{
  ActionEvent ae;
  /* `state` arrives already normalized: callback() strips Caps Lock / Num Lock
   * (LockMask, Mod2Mask) for every event and the caller strips the button masks,
   * so what is left is exactly the real modifier chord -- an exact match against
   * a binding row's mods is safe with the latch keys in any state. */
  ae.device = DEV_BUTTON; ae.code = button; ae.mods = state; ae.ctx = ACTX_CANVAS;
  ae.mx = mx; ae.my = my; ae.state = state;
  ae.xevent = 0; ae.key = 0; ae.button = button; ae.aux = 0;
  return dispatch_input_action(&ae);
}

/* --- string <-> int helpers for the `xschem bind/unbind/bindings` commands - */
static int parse_device(const char *s)
{
  if(!strcmp(s, "wheel"))  return DEV_WHEEL;
  if(!strcmp(s, "button")) return DEV_BUTTON;
  if(!strcmp(s, "key"))    return DEV_KEY;
  return -1;
}

static int parse_code(int device, const char *s)
{
  if(device == DEV_WHEEL) {
    if(!strcmp(s, "up"))   return WHEEL_UP;
    if(!strcmp(s, "down")) return WHEEL_DOWN;
    return -1;
  }
  return atoi(s);   /* button number / raw code */
}

static int parse_mods(const char *s)
{
  int mask = 0;
  char buf[128];
  char *tok;
  if(!s || !*s || !strcmp(s, "0") || !strcmp(s, "none")) return 0;
  my_strncpy(buf, s, S(buf));
  tok = strtok(buf, "+");
  while(tok) {
    if(!strcmp(tok, "shift") || !strcmp(tok, "Shift")) mask |= ShiftMask;
    else if(!strcmp(tok, "ctrl") || !strcmp(tok, "control") ||
            !strcmp(tok, "Ctrl") || !strcmp(tok, "Control")) mask |= ControlMask;
    else if(!strcmp(tok, "alt") || !strcmp(tok, "Alt") || !strcmp(tok, "mod1")) mask |= Mod1Mask;
    else if(!strcmp(tok, "super") || !strcmp(tok, "Super") || !strcmp(tok, "mod4")) mask |= Mod4Mask;
    else return -1;
    tok = strtok(NULL, "+");
  }
  return mask;
}

static int parse_ctx(const char *s)
{
  if(!s || !*s || !strcmp(s, "canvas")) return ACTX_CANVAS;
  if(!strcmp(s, "global")) return ACTX_GLOBAL;
  if(!strcmp(s, "graph") || !strcmp(s, "over_graph")) return ACTX_OVER_GRAPH;
  return -1;
}

static const char *device_name(int d)
{
  return d==DEV_WHEEL ? "wheel" : d==DEV_BUTTON ? "button" : d==DEV_KEY ? "key" : "?";
}

static const char *code_name(int device, int code)
{
  static char buf[16];
  if(device == DEV_WHEEL) return code==WHEEL_UP ? "up" : code==WHEEL_DOWN ? "down" : "?";
  my_snprintf(buf, S(buf), "%d", code);
  return buf;
}

static const char *mods_name(int mods)
{
  static char buf[32];
  buf[0] = '\0';
  if(mods == 0) return "0";
  if(mods & ControlMask) strcat(buf, buf[0] ? "+ctrl"  : "ctrl");
  if(mods & ShiftMask)   strcat(buf, buf[0] ? "+shift" : "shift");
  if(mods & Mod1Mask)    strcat(buf, buf[0] ? "+alt"   : "alt");
  if(mods & Mod4Mask)    strcat(buf, buf[0] ? "+super" : "super");
  return buf;
}

static const char *ctx_name(int ctx)
{
  return ctx==ACTX_GLOBAL ? "global" : ctx==ACTX_CANVAS ? "canvas"
       : ctx==ACTX_OVER_GRAPH ? "graph" : "?";
}

/* `xschem bind <wheel|button|key> <code> <mods> <ctx> <action_id> [idle]` */
/* `xschem set_action_log_cmd <action_id> <tcl_cmd>` -- action-log Layer A
 * slice 2: store the canonical replayable command logged when the C-backed
 * action <action_id> dispatches. Called by xschem.tcl at startup for every
 * actions.csv row with a non-empty 'command' and no 'nolog' flag; commands are
 * never hand-written into C. Result is 1 (stored) or 0 (id not in the C
 * registry -- menu-only csv ids are legitimate non-matches, not errors). */
int action_cmd_set_log_cmd(int argc, const char **argv)
{
  int i;
  if(argc < 4) {
    Tcl_SetResult(interp, "usage: xschem set_action_log_cmd <action_id> <tcl_cmd>", TCL_STATIC);
    return TCL_ERROR;
  }
  for(i = 0; i < num_action_defs; ++i) {
    if(!strcmp(action_registry[i].id, argv[2])) {
      my_strdup(_ALLOC_ID_, &action_registry[i].log_cmd, argv[3]);
      Tcl_SetResult(interp, "1", TCL_STATIC);
      return TCL_OK;
    }
  }
  Tcl_SetResult(interp, "0", TCL_STATIC);
  return TCL_OK;
}

/* `xschem set_action_nolog <action_id>` -- action-log Phase 3 slice D: mark
 * the action as not-to-be-logged at dispatch (csv 'nolog' column, pushed by
 * xschem.tcl at startup; see the ActionDef comment). Same return convention
 * as set_action_log_cmd: 1 = flagged, 0 = id not in the C registry. */
int action_cmd_set_nolog(int argc, const char **argv)
{
  int i;
  if(argc < 3) {
    Tcl_SetResult(interp, "usage: xschem set_action_nolog <action_id>", TCL_STATIC);
    return TCL_ERROR;
  }
  for(i = 0; i < num_action_defs; ++i) {
    if(!strcmp(action_registry[i].id, argv[2])) {
      action_registry[i].nolog = 1;
      Tcl_SetResult(interp, "1", TCL_STATIC);
      return TCL_OK;
    }
  }
  Tcl_SetResult(interp, "0", TCL_STATIC);
  return TCL_OK;
}

int action_cmd_bind(int argc, const char **argv)
{
  int device, code, mods, ctx, idle = 0;
  ensure_input_bindings();
  if(argc < 7) {
    Tcl_SetResult(interp,
      "usage: xschem bind <wheel|button|key> <code> <mods> <ctx> <action_id> [idle]", TCL_STATIC);
    return TCL_ERROR;
  }
  if(argc >= 8) {
    if(!strcmp(argv[7], "idle")) idle = 1;
    else { Tcl_AppendResult(interp, "bind: expected 'idle', got '", argv[7], "'", NULL); return TCL_ERROR; }
  }
  device = parse_device(argv[2]);
  if(device < 0) { Tcl_SetResult(interp, "bind: unknown device", TCL_STATIC); return TCL_ERROR; }
  code = parse_code(device, argv[3]);
  if(code < 0)   { Tcl_SetResult(interp, "bind: bad code", TCL_STATIC); return TCL_ERROR; }
  mods = parse_mods(argv[4]);
  if(mods < 0)   { Tcl_SetResult(interp, "bind: bad modifiers", TCL_STATIC); return TCL_ERROR; }
  ctx = parse_ctx(argv[5]);
  if(ctx < 0)    { Tcl_SetResult(interp, "bind: bad context", TCL_STATIC); return TCL_ERROR; }
  if(!find_action_def(argv[6])) {   /* accept Tcl-backed ids too, not only C-backed */
    Tcl_AppendResult(interp, "bind: unknown action '", argv[6], "'", NULL);
    return TCL_ERROR;
  }
  if(set_input_binding(device, code, mods, ctx, argv[6]) < 0) {
    Tcl_SetResult(interp, "bind: binding table full", TCL_STATIC);
    return TCL_ERROR;
  }
  /* set idle_only to the requested value explicitly, so re-binding a row flips it both
   * ways (the replace path in set_input_binding leaves other fields untouched). */
  { InputBinding *b = find_binding(device, code, mods, ctx); if(b) b->idle_only = idle; }
  Tcl_ResetResult(interp);
  return TCL_OK;
}

/* `xschem unbind <device> <code> <mods> <ctx>` -> result = #removed (0 or 1) */
int action_cmd_unbind(int argc, const char **argv)
{
  int device, code, mods, ctx, removed;
  char res[32];
  ensure_input_bindings();
  if(argc < 6) {
    Tcl_SetResult(interp, "usage: xschem unbind <device> <code> <mods> <ctx>", TCL_STATIC);
    return TCL_ERROR;
  }
  device = parse_device(argv[2]);
  code   = parse_code(device, argv[3]);
  mods   = parse_mods(argv[4]);
  ctx    = parse_ctx(argv[5]);
  if(device < 0 || code < 0 || mods < 0 || ctx < 0) {
    Tcl_SetResult(interp, "unbind: bad argument", TCL_STATIC);
    return TCL_ERROR;
  }
  removed = unset_input_binding(device, code, mods, ctx);
  my_snprintf(res, S(res), "%d", removed);
  Tcl_SetResult(interp, res, TCL_VOLATILE);
  return TCL_OK;
}

/* `xschem bindings dump` -> Tcl list of {device code mods ctx action_id} rows */
int action_cmd_bindings(int argc, const char **argv)
{
  int i;
  ensure_input_bindings();
  if(argc >= 3 && strcmp(argv[2], "dump")) {
    Tcl_SetResult(interp, "usage: xschem bindings dump", TCL_STATIC);
    return TCL_ERROR;
  }
  Tcl_ResetResult(interp);
  for(i = 0; i < num_input_bindings; ++i) {
    InputBinding *b = &input_bindings[i];
    char row[160];
    /* Phase 3d.1b: idle_only rows carry a trailing " idle" marker (additive — other
     * rows are unchanged). */
    my_snprintf(row, S(row), "%s %s %s %s %s%s",
      device_name(b->device), code_name(b->device, b->code),
      mods_name(b->mods), ctx_name(b->ctx), b->action_id,
      b->idle_only ? " idle" : "");
    Tcl_AppendElement(interp, row);
  }
  return TCL_OK;
}

/* Mouse wheel events: signature -> action via the (remappable) binding table.
 * Graph routing (pointer over a waveform graph) stays in C for now; only the
 * no-modifier and Shift wheel ever routed to a graph, exactly as before. */
static int handle_mouse_wheel(int event, int mx, int my, KeySym key, int button, int aux, int state)
{
   int graph_use_ctrl_key = tclgetboolvar("graph_use_ctrl_key");
   ActionEvent ae;
   int wheel, mods, ctx;
   /* normalized modifier mask (the bits the bind table uses), lock/button bits dropped */
   int m;

   if(button == Button4)      wheel = WHEEL_UP;
   else if(button == Button5) wheel = WHEEL_DOWN;
   else return 0;

   m = state & (ShiftMask | ControlMask | Mod1Mask | Mod4Mask);

   /* The graph-vs-canvas routing that used to be a hardcoded
    * waves_selected/waves_callback block is now data: over_graph wheel rows map
    * to "graph.forward". The no-modifier and Shift wheel consult the context (they
    * may land on a graph); Ctrl-wheel never did, so it stays canvas. */
   if(state == 0) {
     mods = 0; ctx = current_input_ctx(event, key, state, button);
   }
   else if(!graph_use_ctrl_key && m == ShiftMask && !(state & Button2Mask)) {
     mods = ShiftMask; ctx = current_input_ctx(event, key, state, button);
   }
   else if(!graph_use_ctrl_key && m == ControlMask && !(state & Button2Mask)) {
     mods = ControlMask; ctx = ACTX_CANVAS;
   }
   else {
     /* Any OTHER modifier combo (Alt, Super, multi-mod like Ctrl+Shift or Alt+Shift):
      * consult the binding table on the canvas, so users can map e.g. Alt-wheel or
      * Alt+Shift-wheel to an action (doc/claude/specs/bus_thickness_scroll.md,
      * bus_transpose_scroll.md). The Shift / Ctrl branches above match the LONE
      * modifier EXACTLY (m == ...), so a combo containing Shift/Ctrl falls through here
      * instead of being mistaken for plain Shift/Ctrl. Lone Shift / lone Ctrl / no-mod
      * keep their routing (incl. the graph_use_ctrl_key reservation). No matching
      * binding -> dispatch_input_action() is a harmless no-op. */
     mods = m;
     if(mods == 0 || mods == ShiftMask || mods == ControlMask) return 0;
     ctx = ACTX_CANVAS;
   }

   ae.device = DEV_WHEEL; ae.code = wheel; ae.mods = mods; ae.ctx = ctx;
   ae.mx = mx; ae.my = my; ae.state = state;
   ae.xevent = event; ae.key = key; ae.button = button; ae.aux = aux;
   dispatch_input_action(&ae);
   /* preserve the old contract: a graph-consumed event returns 1 (caller stops);
    * a canvas zoom/pan returned 0 to let the caller continue */
   return (ctx == ACTX_OVER_GRAPH);
}

static void end_shape_point_edit(void)
{
     int save = xctx->modified;
     int edited = 0;
     /* Did the gesture actually move anything? move_objects(END) commits the accumulated
      * xctx->deltax/deltay (set by the last RUBBER) and zeroes them, so capture the net
      * move HERE, before any END below. This replaces an older "release cell == press cell"
      * test that assumed the move reference is the mouse -- false for an arc, whose START
      * reference is the arc CENTER (move.c:1600), so a drag-and-return would silently change
      * the arc yet reset the modified flag to clean (a lost edit on close-without-save). */
     int moved = (xctx->deltax != 0.0 || xctx->deltay != 0.0);
     dbg(1, "%g %g %g %g\n",
         xctx->mx_double_save, xctx->my_double_save, xctx->mousex_snap, xctx->mousey_snap);
     if(xctx->lastsel == 1 && xctx->sel_array[0].type==POLYGON) {
        int k;
        int n = xctx->sel_array[0].n;
        int c = xctx->sel_array[0].col;
        move_objects(END,0,0,0);
        edited = 1;
        xctx->constr_mv=0;
        tcleval("set constr_mv 0" );
        xctx->poly[c][n].sel = SELECTED;
        xctx->shape_point_selected = 0;
        for(k=0; k<xctx->poly[c][n].points; ++k) {
          xctx->poly[c][n].selected_point[k] = 0;
        }
        xctx->need_reb_sel_arr=1;
     }
     else if(xctx->lastsel == 1 && xctx->sel_array[0].type==xRECT) {
        int n = xctx->sel_array[0].n;
        int c = xctx->sel_array[0].col;
        move_objects(END,0,0,0);
        edited = 1;
        xctx->constr_mv=0;
        tcleval("set constr_mv 0" );
        xctx->rect[c][n].sel = SELECTED;
        xctx->shape_point_selected = 0;
        xctx->need_reb_sel_arr=1;
     }
     else if(xctx->lastsel == 1 && xctx->sel_array[0].type==LINE) {
        int n = xctx->sel_array[0].n;
        int c = xctx->sel_array[0].col;
        move_objects(END,0,0,0);
        edited = 1;
        xctx->constr_mv=0;
        tcleval("set constr_mv 0" );
        xctx->line[c][n].sel = SELECTED;
        xctx->shape_point_selected = 0;
        xctx->need_reb_sel_arr=1;
     }
     else if(xctx->lastsel == 1 && xctx->sel_array[0].type==WIRE) {
        int n = xctx->sel_array[0].n;
        move_objects(END,0,0,0);
        edited = 1;
        xctx->constr_mv=0;
        tcleval("set constr_mv 0" );
        xctx->wire[n].sel = SELECTED;
        xctx->shape_point_selected = 0;
        xctx->need_reb_sel_arr=1;
     }
     else if(xctx->lastsel == 1 && xctx->sel_array[0].type==ARC) {
        int n = xctx->sel_array[0].n;
        int c = xctx->sel_array[0].col;
        move_objects(END,0,0,0);
        edited = 1;
        xctx->constr_mv=0;
        tcleval("set constr_mv 0" );
        xctx->arc[c][n].sel = SELECTED;
        xctx->shape_point_selected = 0;
        xctx->need_reb_sel_arr=1;
     }
     if(!moved) {
       /* no net move: restore the pre-gesture modified flag so a click that did not drag
        * (or dragged back to the start) does not leave the buffer spuriously dirty. */
       set_modify(save);
     }
     /* action-log Layer C: a control-point drag has no replayable form yet
      * (needs a stable object referent, issue 0005) -> '#' marker, skipped
      * for the no-net-move case restored just above. */
     else if(edited) {
       log_action("# edit shape control point (drag; not replayable: needs object referent, issue 0005)");
     }
     /* a shape-point (vertex/edge) grab captured a pre-press snapshot at press but never armed the
      * deferred-selection restore (this precise edit keeps its shape selected). Free the unused
      * snapshot so it does not linger to the next gesture. */
     drag_sel_free();
}

void unselect_attached_floaters(void)
{
  int c, i, found = 0;
  for(c = 0; c < cadlayers; c++) {
    for(i = 0; i < xctx->rects[c]; i++) {
      if(get_tok_value(xctx->rect[c][i].prop_ptr, "name", 0)[0]) {
        found = 1;
        select_box(c, i, 0, 1,  1);
      }
    }
    for(i = 0; i < xctx->lines[c]; i++) {
      if(get_tok_value(xctx->line[c][i].prop_ptr, "name", 0)[0]) {
        found = 1;
        select_line(c, i, 0, 1, 1);
      }
    }

    for(i = 0; i < xctx->polygons[c]; i++) {
      if(get_tok_value(xctx->poly[c][i].prop_ptr, "name", 0)[0]) {
        found = 1;
        select_polygon(c, i, 0, 1, 1);
      }
    }
    for(i = 0; i < xctx->arcs[c]; i++) {
      if(get_tok_value(xctx->arc[c][i].prop_ptr, "name", 0)[0]) {
        found = 1;
        select_arc(c, i, 0, 1, 1);
      }
    }
  }
  for(i = 0; i < xctx->wires; i++) {
    if(get_tok_value(xctx->wire[i].prop_ptr, "name", 0)[0]) {
     found = 1;
     select_wire(i, 0, 1, 1);
    }
  }
  for(i = 0; i < xctx->texts; i++) {
    if(get_tok_value(xctx->text[i].prop_ptr, "name", 0)[0]) {
     found = 1;
     select_text(i, 0, 1, 1);
    }
  }
  if(found) {
    rebuild_selected_array();
    draw_selection(xctx->gc[SELLAYER],0);
  }
}

static void handle_enter_notify(int draw_xhair, int crosshair_size)
{
    struct stat buf;
    dbg(2, "callback(): Enter event, ui_state=%d\n", xctx->ui_state);
    xctx->mouse_inside = 1;
    /* `-cursor none` is only safe when a crosshair is standing in for the pointer.
     * On a no_snap canvas (issue 0177) none is drawn, so the pointer would just
     * vanish -- and the caller's draw_xhair local is computed BEFORE the context
     * switch this very event may have performed, so the property has to be read
     * here rather than trusted from the argument. */
    if(draw_xhair && !xctx->no_snap) {
      if(crosshair_size == 0) {
        tclvareval(xctx->top_path, ".drw configure -cursor none" , NULL);
      }
    } else
      tclvareval(xctx->top_path, ".drw configure -cursor {}" , NULL);
    /* xschem window *sending* selected objects
       when the pointer comes back in abort copy operation since it has been done
       in another xschem xctx->window; STARTCOPY set and selection file does not exist any more */
    if(stat(sel_file, &buf) && (xctx->ui_state & STARTCOPY) )
    {
      dbg(1, "xschem window *sending* selected objects: abort\n");
      copy_objects(ABORT);
      unselect_all(1);
    }
    /* xschem window *receiving* selected objects selection cleared --> abort */
    else if(xctx->paste_from == 1 && stat(sel_file, &buf) && (xctx->ui_state & STARTMERGE)) {
      dbg(1, " xschem window *receiving* selected objects selection cleared: abort\n");
      abort_operation(1);
    }
    /*xschem window *receiving* selected objects
     * no selected objects and selection file exists --> start merge */
    else if(xctx->lastsel == 0 && !stat(sel_file, &buf)) {
      dbg(1,"xschem window *receiving* selected objects: start merge\n");
      xctx->mousex_snap = 490;
      xctx->mousey_snap = -340;
      merge_file(1, ".sch");
    }

    return;
}

static void handle_motion_notify(int event, KeySym key, int state, int rstate, int button,
                                 int mx, int my, int aux, int draw_xhair, int enable_stretch,
                                 int tabbed_interface, const char *win_path, int snap_cursor, int wire_draw_active)
{
    char str[PATH_MAX + 100];
    static double tk_scaling = 1.0;
    /* no Tk under true headless (--nogui, has_x==0): skip the `tk scaling` query so it
     * doesn't error; keep the default. */
    if(has_x) tk_scaling = atof(tcleval("tk scaling"));
    /* Ignore motion that belongs to a DIFFERENT window's canvas, so the crosshair/hover
     * is drawn in the window under the pointer, not in the focused one (issue 0036).
     * Non-tabbed mode: any path mismatch qualifies (unchanged). Tabbed mode: only with
     * mouse_follows_focus on, and only when a REAL (detached, own canvas) window is
     * involved on either side -- the matching EnterNotify switch (handle_window_switching)
     * makes the hovered window the context, so its own motion still draws; background tabs
     * share .drw and match the active tab's current_win_path. When mouse_follows_focus is
     * OFF there is no compensating switch, so fall back to the pre-0036 behavior (don't
     * drop in tabbed mode) -- the opt-out keeps the old background-tab motion. */
    if(strcmp(win_path, xctx->current_win_path)) {
      int drop = !tabbed_interface;
      if(tabbed_interface && tclgetboolvar("mouse_follows_focus")) {
        int wn = get_tab_or_window_number(win_path);
        Xschem_ctx **sx = get_save_xctx();
        int win_is_real = (wn > 0 && sx[wn] && sx[wn]->top_path && sx[wn]->top_path[0]);
        int cur_is_real = (xctx->top_path && xctx->top_path[0]);
        drop = (win_is_real || cur_is_real);
      }
      if(drop) return;
    }
    /* A motion delivered to this canvas means the pointer is inside it. EnterNotify
     * is the only other setter, but with the shared tabbed canvas a tab switch
     * does not regenerate an Enter -- so without this the hover cue and crosshair
     * would stay dead until the schematic is reopened. LeaveNotify still clears it. */
    xctx->mouse_inside = 1;
    if( waves_selected(event, key, state, button)) {
      waves_callback(event, mx, my, key, button, aux, state);
      /* viewer plan item 9: the diamond snap cursor rides the graph motion
       * pump, AFTER waves_callback so an armed gesture has already updated
       * ui_state and the snap yields to it on this very event rather than one
       * event late. */
      if(event == MotionNotify) draw_graph_snap_cursor(mx, my);
      return;
    }
    /* pointer left every graph (still inside the canvas): drop the snap glyph,
     * or it would sit frozen on the last sample it found */
    graph_snap_clear();
    if(draw_xhair) {
      draw_crosshair(1, state); /* when moving mouse: first action is delete crosshair, will be drawn later */
    }
    if(snap_cursor) draw_snap_cursor(1); /* clear */
    /* pan schematic */
    if(xctx->ui_state & STARTPAN) pan(RUBBER, mx, my);

    if(xctx->semaphore >= 2) {
      if(draw_xhair) {
        draw_crosshair(2, state); /* locked UI: draw new crosshair and break out */
      }
      if(snap_cursor && ((state == ShiftMask) || wire_draw_active)) draw_snap_cursor(2); /* redraw */
      return;
    }

    /* update status bar messages.
     * This readout is what issue 0248 was filed against: note the `if(xctx->ui_state)` guard --
     * a gesture is armed exactly when a gate message or verb-noun prompt has something to say, so
     * every one of them died on the first 8-pixel flick of the mouse. It is not gated here: the
     * hold is enforced inside statusmsg() (scheduler.c), which drops an ordinary line while a held
     * one is up. Same for the press/release twins below and for select.c's object-info lines. */
    if(xctx->ui_state) {
      if(abs(mx-xctx->mx_save) > 8 || abs(my-xctx->my_save) > 8 ) {
        my_snprintf(str, S(str), "mouse = %.16g %.16g - selected: %d w=%.6g h=%.6g",
          xctx->mousex_snap, xctx->mousey_snap,
          xctx->lastsel ,
          xctx->mousex_snap-xctx->mx_double_save, xctx->mousey_snap-xctx->my_double_save
        );
        statusmsg(str,1);
      }
    }

    /* determine direction of a rectangle selection  (or unselection with ALT key) */
    if(xctx->ui_state & STARTSELECT && !(xctx->ui_state & (PLACE_SYMBOL | STARTPAN | PLACE_TEXT)) ) {
      /* Unselect by area : determine direction */
      int stretch = (state & ControlMask) ? !enable_stretch : enable_stretch;
      if( ((state & Button1Mask)  && SET_MODMASK) || (xctx->ui_state & DESEL_AREA)) {
        if(mx >= xctx->mx_save) xctx->nl_dir = 0;
        else  xctx->nl_dir = 1;
        select_rect(stretch, RUBBER,0);
      /* select by area : determine direction */
      } else if(state & Button1Mask) {
        if(mx >= xctx->mx_save) xctx->nl_dir = 0;
        else  xctx->nl_dir = 1;
        select_rect(stretch, RUBBER,1);
      }
    }
    /* draw objects being moved */
    if(xctx->ui_state & STARTMOVE) {
      if(xctx->constr_mv == 1) xctx->mousey_snap = xctx->my_double_save;
      if(xctx->constr_mv == 2) xctx->mousex_snap = xctx->mx_double_save;
      move_objects(RUBBER,0,0,0);
    }

    /* draw objects being copied */
    if(xctx->ui_state & STARTCOPY) {
      if(xctx->constr_mv == 1) xctx->mousey_snap = xctx->my_double_save;
      if(xctx->constr_mv == 2) xctx->mousex_snap = xctx->mx_double_save;
      copy_objects(RUBBER);
    }

    /* draw moving objects being inserted, wires, arcs, lines, rectangles, polygons or zoom box */
    redraw_w_a_l_r_p_z_rubbers(0);

    /* start of a mouse area select. Button1 pressed. No shift pressed
     * Do not start an area select if user is dragging a polygon/bezier point */
    if(!(xctx->ui_state & STARTPOLYGON) && (state&Button1Mask) && !(xctx->ui_state & STARTWIRE) &&
       !(xctx->ui_state & STARTPAN) && !(SET_MODMASK) && !xctx->shape_point_selected &&
       !(state & ShiftMask) && !(xctx->ui_state & (PLACE_SYMBOL | PLACE_TEXT)))
    {
      /* make motion a bit sticky. require 10 pixels (screen units, not xschem units) */
      if(abs(mx - xctx->mx_save) > tk_scaling * 2  || abs(my - xctx->my_save) > tk_scaling * 2) {
        xctx->mouse_moved = 1;
        if(!xctx->drag_elements) {
          int stretch = (state & ControlMask) ? !enable_stretch : enable_stretch;
          if( !(xctx->ui_state & STARTSELECT)) {
            select_rect(stretch, START,1);
            xctx->onetime=1;
          }
          if(abs(mx-xctx->mx_save) > 8 ||
             abs(my-xctx->my_save) > 8 ) { /* set reasonable threshold before unsel */
            if(xctx->onetime) {
              unselect_all(1); /* 20171026 avoid multiple calls of unselect_all() */
              xctx->onetime=0;
            }
            xctx->ui_state|=STARTSELECT; /* set it again cause unselect_all(1) clears it... */
          }
        }
      }
    }
    /* Unselect by area */
    if( (((state & Button1Mask)  && SET_MODMASK) || (xctx->ui_state & DESEL_AREA)) &&
       !(state & ShiftMask) &&
       !(xctx->ui_state & STARTPAN) &&
       !xctx->shape_point_selected &&
       !(xctx->ui_state & STARTSELECT) &&
       !(xctx->ui_state & (PLACE_SYMBOL | PLACE_TEXT))) { /* unselect area */
      int stretch = (state & ControlMask) ? !enable_stretch : enable_stretch;
      select_rect(stretch, START,0);
    }
    /* Select by area. Shift pressed */
    else if((state&Button1Mask) && (state & ShiftMask) && !(xctx->ui_state & STARTWIRE) &&
             !(xctx->ui_state & (PLACE_SYMBOL | PLACE_TEXT)) && !xctx->shape_point_selected &&
             !xctx->drag_elements && !(xctx->ui_state & STARTPAN) ) {
      if(mx != xctx->mx_save || my != xctx->my_save) {
        if( !(xctx->ui_state & STARTSELECT)) {
          int stretch = (state & ControlMask) ? !enable_stretch : enable_stretch;
          select_rect(stretch, START,1);
        }
        if(abs(mx-xctx->mx_save) > 8 ||
           abs(my-xctx->my_save) > 8 ) { /* set reasonable threshold before unsel */
          if(!xctx->already_selected) {
            select_object(X_TO_XSCHEM(xctx->mx_save),
                          Y_TO_XSCHEM(xctx->my_save), 0, 0, NULL); /* remove near obj if dragging */
          }
          rebuild_selected_array();
        }
      }
    }
    /* hover (awareness) highlight: outline the object under the cursor. Before the
     * crosshair redraw so the crosshair stays on top. No-op when disabled / mid-
     * gesture (ui_state!=0 here) / pointer outside. */
    draw_hover(0);
    draw_flylines(0); /* hover fly-line overlay: independent of hover_highlight (spec §3.1) */
    if(draw_xhair) {
      draw_crosshair(2, state); /* what = 2(draw) */
    }
    if(snap_cursor && ((state == ShiftMask) || wire_draw_active)) draw_snap_cursor(2); /* redraw */

    return;
}

/* issue 0114: is the in-flight move/copy a MULTI-OBJECT selection? A rotate/flip during a
 * connected drag must transform the WHOLE selection rigidly about a shared pivot (Cadence
 * Stretch semantics, wires kept connected), NOT spin each object about its own origin
 * (ROTATELOCAL). A follow-set (select_attached_nets) only ever adds WIREs, so every selected
 * non-wire object is user-owned; the user's own wires are counted by fluid_startsel_wires during
 * a fluid stretch, or are simply every selected wire for a rigid (non-stretch) move. Scans the
 * object arrays directly (not sel_array) so it is correct even if need_reb_sel_arr is unset
 * mid-gesture. >1 user object => coerce ROTATELOCAL to the group ROTATE/FLIP form. */
static int connected_drag_group_transform(void)
{
  int i, c, nonwire = 0, wires = 0, userwires;
  for(i = 0; i < xctx->instances; ++i) if(xctx->inst[i].sel) ++nonwire;
  for(i = 0; i < xctx->texts;     ++i) if(xctx->text[i].sel) ++nonwire;
  for(c = 0; c < cadlayers; ++c) {
    for(i = 0; i < xctx->arcs[c];     ++i) if(xctx->arc[c][i].sel)  ++nonwire;
    for(i = 0; i < xctx->rects[c];    ++i) if(xctx->rect[c][i].sel) ++nonwire;
    for(i = 0; i < xctx->lines[c];    ++i) if(xctx->line[c][i].sel) ++nonwire;
    for(i = 0; i < xctx->polygons[c]; ++i) if(xctx->poly[c][i].sel) ++nonwire;
  }
  for(i = 0; i < xctx->wires; ++i) if(xctx->wire[i].sel) ++wires;
  userwires = xctx->stretch_select ? xctx->fluid_startsel_wires : wires;
  return (nonwire + userwires) > 1;
}

/* issue 0116 bug 2: standalone (non-drag) Alt-R / Alt-F on the CURRENT selection. With >1 object
 * selected, transform the WHOLE selection as one rigid body about its grid-snapped bounding-box
 * centre (Cadence "treat the selection as one object" -- an in-place group rotate/flip), NOT each
 * object spun about its own origin (the old unconditional ROTATELOCAL). A single object keeps the
 * per-object in-place transform about its own 0,0. `what` is ROTATE or FLIP. Records the matching
 * replay verb via the perform_action boundary (group ROTATE -> `xschem rotate x y`, Refactor B
 * atom 6; group FLIP -> `xschem flip x y`, atom 7; single -> `xschem rotate_in_place|flip_in_place`,
 * atoms 3/4). Caller has ensured lastsel>0 and passed the readonly guard. */
static void standalone_group_transform(int what, double c_snap)
{
  if(connected_drag_group_transform()) {
    xRect bb; double px, py;
    calc_drawing_bbox(&bb, 1);
    px = my_round(((bb.x1 + bb.x2) * 0.5) / c_snap) * c_snap;
    py = my_round(((bb.y1 + bb.y2) * 0.5) / c_snap) * c_snap;
    if(what & ROTATE) {
      /* GROUP rotate (issue 0116): the whole selection spins rigidly about the grid-snapped bbox
       * centre px,py. Route through the mutation boundary (Refactor B atom 6) -- perform_action->
       * run_core owns the readonly gate + the rebuild+seed-pivot(px,py)+START+ROTATE+END effect
       * (ROTATELOCAL dropped -> shared pivot, exactly the old group form) + the ONE
       * `xschem rotate px py` log (core_log_action). The pivot is passed as argv[2]/argv[3];
       * run_core re-seeds mx/my_double_save = mousex/y_snap = px,py from it. readonly was already
       * refused by the caller (readonly_block at the Alt-R key). */
      char sx[64], sy[64]; const char *av[4];
      my_snprintf(sx, S(sx), "%.16g", px);
      my_snprintf(sy, S(sy), "%.16g", py);
      av[0] = "xschem"; av[1] = "rotate"; av[2] = sx; av[3] = sy;
      perform_action("rotate", 4, av);
    } else {
      /* GROUP flip (what == FLIP): the whole selection mirrors rigidly about the grid-snapped bbox
       * centre px,py. Route through the mutation boundary (Refactor B atom 7) -- perform_action->
       * run_core owns the readonly gate + the rebuild+seed-pivot(px,py)+START+FLIP+END effect
       * (ROTATELOCAL dropped -> shared pivot, exactly the old group form) + the ONE
       * `xschem flip px py` log (core_log_action). The pivot is passed as argv[2]/argv[3]; run_core
       * re-seeds mx/my_double_save = mousex/y_snap = px,py from it. readonly was already refused by
       * the caller (readonly_block at the Alt-F key). After atom 7 both group arms (ROTATE + FLIP)
       * cross the boundary. */
      char sx[64], sy[64]; const char *av[4];
      my_snprintf(sx, S(sx), "%.16g", px);
      my_snprintf(sy, S(sy), "%.16g", py);
      av[0] = "xschem"; av[1] = "flip"; av[2] = sx; av[3] = sy;
      perform_action("flip", 4, av);
    }
  } else {
    /* single-object standalone in-place transform: route through the mutation boundary
     * (Refactor B atom 3 rotate_in_place, atom 4 flip_in_place). perform_action owns the
     * readonly gate + the ONE `xschem rotate_in_place`/`xschem flip_in_place` log site + the
     * rebuild+START+what|ROTATELOCAL+END effect. ROTATELOCAL pivots each object about its own
     * origin, so the mx/my_double_save seeded here is immaterial to the transform (carried only
     * for symmetry with the group form above). `what` is ROTATE or FLIP; kept as two explicit
     * verb calls (not a ternary verb string) so each self-log site stays greppable (S1). */
    xctx->mx_double_save = xctx->mousex_snap;
    xctx->my_double_save = xctx->mousey_snap;
    if(what & ROTATE) perform_action("rotate_in_place", 0, NULL);
    else              perform_action("flip_in_place", 0, NULL);
  }
}

static void handle_key_press(int event, KeySym key, int state, int rstate, int mx, int my,
                             int button, int aux, int infix_interface, int enable_stretch,
                             const char *win_path, double c_snap,
                             int cadence_compat, int wire_draw_active, int snap_cursor)
{
  /* `snap_cursor` no longer has a reader in this function: the only one was the Escape arm's
   * snap-cursor erase, which moved into escape_terminal() (issue 0245) and re-reads the Tcl
   * variable itself so the verb behaves identically to the key. The parameter is kept for
   * signature symmetry with handle_button_press() / handle_button_release(), which callback()
   * feeds from the same three locals. */
  char str[PATH_MAX + 100];

  /* Phase 3c c4/c5: data-driven context routing for migrated keys, tried before
   * the switch. The gate ensures only chords we actually bound consult the
   * (side-effectful) graph context, so every un-migrated key reaches the switch
   * exactly as before. mods normalized the way the switch branches: letter/
   * printable keysyms strip ShiftMask (rstate); named keys (arrows, Tab, ...)
   * use the raw state.
   *
   * Phase 3d.2: only chords that actually have an over_graph row consult the graph
   * context (current_input_ctx -> waves_selected, which is side-effectful). A
   * canvas-only chord uses ACTX_CANVAS directly: this both avoids a spurious
   * waves_selected side effect and is *required* for correctness — otherwise a
   * canvas-only key whose case has been deleted would resolve to ACTX_OVER_GRAPH
   * (pointer over a graph), find no row, and do nothing. */
  {
    int kmods = (key < 0xff00) ? rstate : state;
    /* Phase 3d.1b: an idle-only chord is skipped while the editor is busy
     * (semaphore>=2), BEFORE current_input_ctx (=waves_selected, side-effectful)
     * runs — matching the `if(semaphore>=2) break;` that preceded the waves guard in
     * these branches. Skipping falls through to the switch, whose own sem check (or
     * absence of a case) reproduces the old no-op. */
    if(key_chord_has_binding((int)key, kmods) &&
       !(xctx->semaphore >= 2 && key_chord_is_idle_only((int)key, kmods))) {
      ActionEvent ae;
      ae.device = DEV_KEY; ae.code = (int)key; ae.mods = kmods;
      ae.ctx = find_binding(DEV_KEY, (int)key, kmods, ACTX_OVER_GRAPH)
               ? current_input_ctx(event, key, state, button)
               : ACTX_CANVAS;
      ae.mx = mx; ae.my = my; ae.state = state;
      ae.xevent = event; ae.key = key; ae.button = button; ae.aux = aux;
      if(dispatch_input_action(&ae)) return;
    }
  }

  switch (key) {
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
      if(state == 0) { /* toggle pin logic level */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        if(key == '4') logic_set(-1, 1, NULL);
        else logic_set((int)key - '0', 1, NULL);
      }
      else if(state==ControlMask) { /* choose layer */
        char n[30];
        xctx->rectcolor = (int)key - '0';
        my_snprintf(n, S(n), "%d", xctx->rectcolor);
        tclvareval("xschem set rectcolor ", n, NULL);

        if(has_x) {
          if(!strcmp(win_path, ".drw")) {
            tclvareval("reconfigure_layers_button {}", NULL);
          } else {
            tclvareval("reconfigure_layers_button [winfo parent ", win_path, "]", NULL);
          }
        }
        dbg(1, "callback(): new color: %d\n",xctx->color_index[xctx->rectcolor]);
      }
      break;

    case '5':
      if(rstate == 0) { /* 20110112 display only probes */
        xctx->only_probes = !xctx->only_probes;
        tclsetboolvar("only_probes", xctx->only_probes);
        toggle_only_probes();
        break;
      }
    case '6':
    case '7':
    case '8':
    case '9':
      if(state==ControlMask) { /* choose layer */
        char n[30];
        xctx->rectcolor = (int)key - '0';
        my_snprintf(n, S(n), "%d", xctx->rectcolor);
        tclvareval("xschem set rectcolor ", n, NULL);

        if(has_x) {
          if(!strcmp(win_path, ".drw")) {
            tclvareval("reconfigure_layers_button {}", NULL);
          } else {
            tclvareval("reconfigure_layers_button [winfo parent ", win_path, "]", NULL);
          }
        }
        dbg(1, "callback(): new color: %d\n",xctx->color_index[xctx->rectcolor]);
      }
      break;

    case 'a':
      if(rstate == 0) { /* make symbol */
        if(xctx->semaphore >= 2) break;
        /* graph routing migrated (Phase 3d.1b): idle_only over_graph -> graph.forward.
         * The waves guard is deleted; the dispatch skips at sem>=2 (handled above). */
        tcleval("tk_messageBox -type okcancel -parent [xschem get topwindow] "
                "-message {do you want to make symbol view ?}");
        if(strcmp(tclresult(),"ok")==0)
        {
         /* keyboard 'a' (no canvas binding entry -> legacy switch). Don't overwrite a
          * read-only schematic on disk (0041); make_symbol() self-logs at its core. */
         if(!xctx->readonly) save_schematic(xctx->sch[xctx->currsch], 0);
         make_symbol();
        }
      }
      else if(rstate == ControlMask) { /* select all (graph routing is data: over_graph -> graph.forward) */
        select_all();
      }
      break;

    /* case 'A' fully migrated to the binding table (Phase 3d.2 batch 3): canvas ->
     * view.toggle_show_netlist (C-backed), over_graph -> graph.forward (already data).
     * The Ctrl branch was a canvas no-op (graph hcursor handled by the over_graph row),
     * so the whole case is gone. See init_input_bindings. */

    case 'b':
      if(rstate==0) { /* merge schematic */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        /* graph routing migrated (Phase 3d.1b): idle_only over_graph -> graph.forward. */
        merge_file(0, ""); /* 2nd parameter not used any more for merge 25122002 */
      }
      else if(rstate==ControlMask) { /* toggle show text in symbol (graph routing is data) */
        xctx->sym_txt =!xctx->sym_txt;
        if(xctx->sym_txt) {
            /* tcleval("alert_ { enabling text in symbol} {}"); */
            tclsetvar("sym_txt","1");
            draw();
        }
        else {
            /* tcleval("alert_ { disabling text in symbol} {}"); */
            tclsetvar("sym_txt","0");
            draw();
        }
      }
      else if(EQUAL_MODMASK) { /* hide/show instance details */
        if(xctx->semaphore >= 2) break;
        xctx->hide_symbols++;
        if(xctx->hide_symbols >= 3) xctx->hide_symbols = 0;
        tclsetintvar("hide_symbols", xctx->hide_symbols);
        draw();
      }
      break;

    /* case 'B' fully migrated to the binding table (Phase 3d.1): canvas ->
     * prop.edit_header_license_text (Tcl-backed), graph -> graph.forward.
     * See init_input_bindings. */

    case 'c':
      /* duplicate selection (Cadence-style copy command, cadence_pin_name_text.md copy/move
       * UX): noun-verb (something selected) starts the copy IMMEDIATELY so the ghost follows
       * the cursor at once; verb-noun (nothing selected) arms copy mode + a prompt so the
       * next canvas click selects the object under the cursor and starts the copy. This
       * overrides the infix_interface preference for the copy/move keys -- otherwise with
       * infix_interface off 'c' only armed MENUSTART and nothing followed until a click. */
      if(rstate==0 && !(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        rebuild_selected_array();
        if(xctx->lastsel > 0) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          copy_objects(START);
        } else {
          /* verb-noun: arm copy mode so the NEXT canvas click selects the object under the
           * cursor AND starts the copy in one gesture (check_menu_start_commands). */
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTCOPY;
          statusmsg_hold("Copy: click an object to copy it", 1);
        }
      }
      /* copy selection into clipboard */
      else if(rstate == ControlMask) {
        if(xctx->semaphore >= 2) break;
        rebuild_selected_array();
        if(xctx->lastsel) { /* 20071203 check if something selected */
          save_selection(2);
          /* self-log Ctrl-C (0062): inline path bypasses the scheduler copy branch;
           * under the selection guard so an empty-selection press logs no phantom */
          log_action("xschem copy");
        }
      }
      /* duplicate selection */
      else if(EQUAL_MODMASK && !(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        xctx->connect_by_kissing = 2; /* 2 will be used to reset var to 0 at end of move */
        if(infix_interface) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          copy_objects(START);
        } else {
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTCOPY;
        }
      }
      break;

    case 'C':
      if(/* !xctx->ui_state && */ rstate == 0) { /* place arc */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        leave_wire_draw_for("Arc");     /* phase 1, both branches -- see leave_wire_draw_for() */
        leave_shape_draw_for("Arc");    /* issue 0269 -- phase 3, all four gates at every shape arm: see the ctx-menu Rectangle pick */
        leave_placement_for("Arc");
        leave_merge_for("Arc");
        if(infix_interface) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          xctx->last_command = 0;
          new_arc(PLACE, 180., xctx->mousex_snap, xctx->mousey_snap);
        } else {
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTARC;
        }
      }
      else if(/* !xctx->ui_state && */ rstate == ControlMask) { /* place circle */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        leave_wire_draw_for("Circle");  /* phase 1, both branches -- see leave_wire_draw_for() */
        leave_shape_draw_for("Circle"); /* issue 0269 -- phase 3, all four gates at every shape arm: see the ctx-menu Rectangle pick */
        leave_placement_for("Circle");
        leave_merge_for("Circle");
        if(infix_interface) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          xctx->last_command = 0;
          new_arc(PLACE, 360., xctx->mousex_snap, xctx->mousey_snap);
        } else {
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTCIRCLE;
        }
      }
      break;

    case 'd':
      /* plain 'd' (unselect-under-mouse) is now the data-driven action
       * edit.deselect_mode (default key 'd', remappable); see
       * doc/claude/specs/deselect_one_mode.md. Only Ctrl+d stays here. */
      if(rstate == ControlMask) { /* delete files */
        if(xctx->semaphore >= 2) break;
        delete_files();
      }
      break;

    case 'D':
      if(rstate == 0) { /* unselect by area */
        if( !(xctx->ui_state & STARTPAN) && !xctx->shape_point_selected &&
          !(xctx->ui_state & (PLACE_SYMBOL | PLACE_TEXT)) && !(xctx->ui_state & STARTSELECT)) {
          if(infix_interface) {
            xctx->mx_save = mx; xctx->my_save = my;
            xctx->mx_double_save=xctx->mousex;
            xctx->my_double_save=xctx->mousey;
            xctx->ui_state |= DESEL_AREA;
          } else {
            xctx->ui_state |= MENUSTART;
            xctx->ui_state2 = MENUSTARTDESEL;
          }
        }
      }
      break;

    case 'e':
      if(rstate == 0) { /* descend to schematic */
        if(xctx->semaphore >= 2) break;
        descend_schematic(0, 1, 1, 1);
      }
      else if(rstate == ControlMask) {
        if(xctx->semaphore >= 2) break;
        go_back(1);
      }
      else if(EQUAL_MODMASK) { /* edit schematic in new window */
        int save = xctx->semaphore;
        xctx->semaphore--; /* so semaphore for current context wll be saved correctly */
        /*  schematic_in_new_window(0, 1, 0); */
        tcleval("open_sub_schematic");
        xctx->semaphore = save;
      }
      break;

    case 'E':
      if(EQUAL_MODMASK) { /* edit schematic in new window - new xschem process */
        int save = xctx->semaphore;
        xctx->semaphore--; /* so semaphore for current context wll be saved correctly */
        schematic_in_new_window(1, 1, 0, 0);
        xctx->semaphore = save;
      }
      break;

    case 'f':
      /* rstate==0 (full zoom on canvas / forward over a graph) is data-driven now;
       * handled by the DEV_KEY dispatch above. See init_input_bindings (Phase 3c). */
      if(rstate == ControlMask) { /* search */
        if(xctx->semaphore >= 2) break;
        /* graph routing migrated (Phase 3d.1b): idle_only over_graph -> graph.forward. */
        tcleval("property_search");
      }
      /* Alt-f / Super-f (flip objects around their anchor points, 20171208) is
       * data-driven now: edit.flip_in_place, default rows key 102 alt|super canvas.
       * Handled by the DEV_KEY dispatch above; see act_flip_in_place. */
      break;

    case 'F':
      if(rstate == 0) { /* flip */
        if(readonly_block()) break;
        if(xctx->ui_state & STARTMOVE) move_objects(FLIP,0,0,0);
        else if(xctx->ui_state & STARTCOPY) copy_objects(FLIP);
        else {
          rebuild_selected_array();
          if(xctx->lastsel == 0) { /* Cases 1 & 3: arm prompt-for-object flip */
            xctx->ui_state |= MENUSTART;
            xctx->ui_state2 = MENUSTARTROTATE;
            xctx->menu_pending_transform = PENDING_TR_FLIP;
            statusmsg_hold("Flip: click an object to flip", 1);
          } else {
            /* standalone Shift-F (single-inline apply, no group form): route through the mutation
             * boundary (Refactor B atom 7, mirror of Shift-R atom 6). perform_action->run_core owns
             * the readonly gate + the rebuild+seed-pivot+START+FLIP+END effect + the ONE
             * `xschem flip x y` log (core_log_action). The pivot is the mouse-snap point, passed as
             * argv[2]/argv[3]; run_core re-seeds mx/my_double_save = mousex/y_snap from it exactly as
             * this block did. readonly was already refused by readonly_block() at the top of case 'F'
             * (which also guards the raw gesture arms + the arming path). issue 0068's "Shift-F logs
             * nothing" note is now stale -- Shift-F self-logs its pivot form via the boundary. */
            char sx[64], sy[64]; const char *av[4];
            my_snprintf(sx, S(sx), "%.16g", xctx->mousex_snap);
            my_snprintf(sy, S(sy), "%.16g", xctx->mousey_snap);
            av[0] = "xschem"; av[1] = "flip"; av[2] = sx; av[3] = sy;
            perform_action("flip", 4, av);
          }
        }
      }
      else if(rstate == ControlMask ) { /* full zoom selection */
        if(xctx->ui_state == SELECTION) {
          zoom_full(1, 1, 3, 0.97);
        }
      }
      break;

    /* 'g'/'G' (halve/double snap), Ctrl-g (set snap value) and Alt-g (highlight net ->
     * waveform viewer) are fully data-driven now: registered actions view.snap_half /
     * view.snap_double / view.set_snap_value / hilight.send_to_waveform, shipped UNBOUND
     * and user-bound via `xschem bind` (doc/claude/specs/keybind_snap_grid_actions.md). The hardcoded
     * case 'g' (incl. its Ctrl/Alt branches) and case 'G' are removed. */

    case 'h':
      if(rstate==ControlMask ) { /* go to http link */
        int savesem = xctx->semaphore;
        xctx->semaphore = 0;
        launcher();
        xctx->semaphore = savesem;
      }
      else if (rstate == 0) { /* horizontally constrained drag 20171023 */
        if ( xctx->constr_mv == 1 ) {
          tcleval("set constr_mv 0" );
          xctx->constr_mv = 0;
        } else {
          tcleval("set constr_mv 1" );
          xctx->constr_mv = 1;
        }
        if(xctx->ui_state & STARTWIRE) {
          if(xctx->constr_mv == 1) xctx->mousey_snap = xctx->my_double_save;
          if(xctx->constr_mv == 2) xctx->mousex_snap = xctx->mx_double_save;
          new_wire(RUBBER, xctx->mousex_snap, xctx->mousey_snap);
        }
        if(xctx->ui_state & STARTLINE) {
          if(xctx->constr_mv == 1) xctx->mousey_snap = xctx->my_double_save;
          if(xctx->constr_mv == 2) xctx->mousex_snap = xctx->mx_double_save;
          new_line(RUBBER, xctx->mousex_snap, xctx->mousey_snap);
        }
      }
      /* Alt-h (schpins_to_sympins) migrated to the binding table (Phase 3d.2):
       * key 'h' Mod1/Mod4 canvas -> sym.create_symbol_pins_from_selected_schematic_pins. */
      break;

    /* case 'H' fully migrated to the binding table (Phase 3d.2): plain ->
     * sym.attach_net_labels_to_component_instance, Ctrl -> sym.make_schematic_and_
     * symbol_from_selected_components. See init_input_bindings. */

    case 'i':
      if(rstate==0) { /* descend to  symbol */
        if(xctx->semaphore >= 2) break;
        descend_symbol();
      }
      else if(rstate == ControlMask) { /* insert sym */
        if(readonly_block()) break;
        if(symbol_view_block()) break;   /* no instances in a symbol view: refuse before the chooser opens */
        if(tclgetboolvar("new_file_browser")) {
          tcleval("file_chooser");
        } else {
          tcleval("load_file_dialog {Insert symbol} *.\\{sym,tcl\\} INITIALINSTDIR 2");
        }
      }
      else if(EQUAL_MODMASK) { /* edit symbol in new window */
        int save =  xctx->semaphore;
        xctx->semaphore--; /* so semaphore for current context wll be saved correctly */
        symbol_in_new_window(0);
        xctx->semaphore = save;
      }
      break;

    case 'I':
      if(rstate == 0) { /* insert sym */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        if(symbol_view_block()) break;   /* no instances in a symbol view: refuse before the chooser opens */
        if(tclgetboolvar("new_file_browser")) {
          tcleval("file_chooser");
        } else {
          start_place_symbol();
        }
      }
      else if(EQUAL_MODMASK) { /* edit symbol in new window - new xschem process */
        int save =  xctx->semaphore;
        xctx->semaphore--; /* so semaphore for current context wll be saved correctly */
        symbol_in_new_window(1);
        xctx->semaphore = save;
      }
      break;

    case 'j':
      /* plain / Ctrl / Alt branches migrated to the binding table (Phase 3d.2 sem-gated
       * batch 3): idle_only canvas rows -> sym.list.{print_list,create_pins,create_labels}
       * (Tcl `xschem print_hilight_net 1|0|4`, identical to the old C calls). The 4th
       * branch (SET_MODMASK && Ctrl -> print_hilight_net(3)) is a non-sem FAMILY chord,
       * so it stays in C. See init_input_bindings. */
      if( SET_MODMASK && (state & ControlMask) ) { /* print list of highlight net with label expansion */
        print_hilight_net(3);
      }
      break;

    case 'J':
      if(SET_MODMASK ) { /* create labels with i prefix from hilight nets */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        print_hilight_net(2);
      }
      break;

    /* case 'k' fully migrated to the binding table (Phase 3d.2 sem-gated batch 2):
     * plain -> hilight.highlight_selected_net_pins (idle), Ctrl ->
     * hilight.un_highlight_selected_net_pins (idle), Alt -> hilight.select_hilight_nets_pins
     * (non-idle, Mod1/Mod4). All Tcl-backed, identical to the old C calls.
     * See init_input_bindings. */

    /* case 'K' fully migrated to the binding table (Phase 3d.2 sem-gated batch 2):
     * plain -> hilight.un_highlight_all_net_pins (idle), Ctrl ->
     * hilight.propagate_highlight_selected_net_pins (drill, idle). See init_input_bindings. */

    case 'l':
      /* plain 'l' is bound to edit.add_wire_label in the binding table (add_wire_label.md),
       * dispatched BEFORE this switch, so the start-line branch below is a dormant fallback that
       * only resurfaces if the user unbinds 'l' (graphic line now defaults to Shift+L). */
      if(/* !xctx->ui_state && */ rstate == 0) { /* start line (shadowed by edit.add_wire_label) */
        int prev_state = xctx->ui_state;
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        leave_shape_draw_for("Line");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
        if(!leave_placement_for("Line")) break;   /* issue 0243 F2 -- see leave_placement_for() */
        if(!leave_merge_for("Line")) break;       /* issue 0265 -- phase 4, a draw cancels a paste */
        prev_state = xctx->ui_state;    /* the teardowns just cleared the placement/merge bits */
        if(infix_interface) {
          start_line(xctx->mousex_snap, xctx->mousey_snap);
          if(prev_state == STARTLINE) {
            tcleval("set constr_mv 0" );
            xctx->constr_mv=0;
          }
        } else {
          xctx->last_command = 0;
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTLINE;
        }
      }
      else if(rstate == ControlMask) { /* create schematic from selected symbol 20171004 */
        if(xctx->semaphore >= 2) break;
        create_sch_from_sym();
      }
      else if(EQUAL_MODMASK) { /* Alt+L: open the Add-Wire-Label form (was place_net_label(1)) */
        if(readonly_block()) break;
        tcleval("addlabel::open");
      }
      break;

    case 'L':
      /* plain 'L' (Shift+L) is bound in the binding table to tools.insert_line (graphic line),
       * relocated here from 'l' so 'l' can host the Add-Wire-Label form (add_wire_label.md);
       * edit.toggle_orthogonal_wiring now ships UNBOUND. The Alt branch (place lab_wire label)
       * stays in C. See init_input_bindings. */
      if(EQUAL_MODMASK ) { /* Alt+Shift+L: place a lab_wire net label */
        if(readonly_block()) break;
        place_net_label(0);
      }
      break;

    case 'm':
      /* Move selection (Cadence-style move command, mirror of 'c'): noun-verb (selected)
       * starts the move immediately so it follows the cursor; verb-noun (nothing selected)
       * arms move mode + a prompt so the next click selects + starts. Overrides
       * infix_interface for this key (see case 'c'). */
      if(rstate==0 && !(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
        if(waves_selected(event, key, state, button)) {
          waves_callback(event, mx, my, key, button, aux, state);
          break;
        }
        if(readonly_block()) break;
        if(cadence_compat) {
          /* Cadence 'm' = STRETCH (connectivity-preserving), mirror of the plain LMB drag.
           * noun-verb: pick up the selection now with attached nets so wires reroute;
           * verb-noun: arm a connected pickup (MENUSTARTSTRETCH) for the next click.
           * see doc/claude/specs/cadence_stretch_move_keys.md */
          rebuild_selected_array();
          if(xctx->lastsel > 0) {
            xctx->connect_by_kissing = 2; /* armed before select_attached_nets (through-run tap skip) */
            select_attached_nets();
            xctx->mx_double_save=xctx->mousex_snap;
            xctx->my_double_save=xctx->mousey_snap;
            move_objects(START,0,0,0);
          } else {
            xctx->ui_state |= MENUSTART;
            xctx->ui_state2 = MENUSTARTMOVE | MENUSTARTSTRETCH;
            statusmsg_hold("Stretch: click an object to move it (wires stay connected)", 1);
          }
          break;
        }
        if(enable_stretch) select_attached_nets(); /* stretch nets that land on selected instance pins */
        rebuild_selected_array();
        if(xctx->lastsel > 0) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          move_objects(START,0,0,0);
        } else {
          /* verb-noun: arm move mode so the NEXT canvas click selects the object under the
           * cursor AND starts the move in one gesture (check_menu_start_commands). */
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTMOVE;
          statusmsg_hold("Move: click an object to move it", 1);
        }
      }
      /* move selection stretching attached nets */
      else if(rstate == ControlMask && !(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
        if(waves_selected(event, key, state, button)) {
          waves_callback(event, mx, my, key, button, aux, state);
          break;
        }
        if(readonly_block()) break;
        if(!enable_stretch) select_attached_nets(); /* stretch nets that land on selected instance pins */
        if(infix_interface) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          move_objects(START,0,0,0);
        } else {
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTMOVE;
        }
      }
      /* Move selection adding wires to moved pins */
      else if(EQUAL_MODMASK && !(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
        if(readonly_block()) break;
        xctx->connect_by_kissing = 2; /* 2 will be used to reset var to 0 at end of move */
        if(infix_interface) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          /* select_attached_nets(); */ /* stretch nets that land on selected instance pins */
          move_objects(START,0,0,0);
        } else {
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTMOVE;
        }
      }
      break;

    case 'M':
      /* Move selection adding wires to moved pins */
      if((rstate == 0) && !(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
        /* over a graph Shift+M is the measurement tooltip (relocated from `m`
         * when `m` became marker creation, doc/claude/specs/graph_markers.md).
         * The `case 'm'` idiom verbatim. Before this, Shift+M over a graph ran
         * readonly_block() + the schematic move -- an existing wrong. */
        if(waves_selected(event, key, state, button)) {
          waves_callback(event, mx, my, key, button, aux, state);
          break;
        }
        if(readonly_block()) break;
        if(cadence_compat) {
          /* Cadence Shift+M = MOVE (rigid / disconnected): move selected objects only,
           * attached wires stay put (connections break). Mirror of Ctrl+LMB drag detach.
           * see doc/claude/specs/cadence_stretch_move_keys.md */
          rebuild_selected_array();
          if(xctx->lastsel > 0) {
            xctx->mx_double_save=xctx->mousex_snap;
            xctx->my_double_save=xctx->mousey_snap;
            move_objects(START,0,0,0);
          } else {
            xctx->ui_state |= MENUSTART;
            xctx->ui_state2 = MENUSTARTMOVE;
            statusmsg_hold("Move: click an object to move it (disconnected)", 1);
          }
          break;
        }
        xctx->connect_by_kissing = 2; /* 2 will be used to reset var to 0 at end of move */
        if(infix_interface) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          /* select_attached_nets(); */ /* stretch nets that land on selected instance pins */
          move_objects(START,0,0,0);
        } else {
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTMOVE;
        }
      }
      /* move selection, stretch attached nets, create new wires on pin-to-moved-pin connections */
      else if(rstate == ControlMask && !(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
        if(readonly_block()) break;
        xctx->connect_by_kissing = 2; /* armed before select_attached_nets (through-run tap skip) */
        if(!enable_stretch) select_attached_nets(); /* stretch nets that land on selected instance pins */
        if(infix_interface) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          move_objects(START,0,0,0);
        } else {
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTMOVE;
        }
      }
      break;

    /* case 'n' fully migrated to the binding table (Phase 3d.2 sem-gated batch 1):
     * plain -> toolbar.netlist, Ctrl -> file.clear_schematic, both idle_only canvas
     * (Tcl-backed, identical to the old tcleval). The idle gate reproduces the deleted
     * `if(sem>=2)break;`. See init_input_bindings. */

    case 'N':
      if(rstate == 0) { /* current level only netlist */
        int err = 0;
        yyparse_error = 0;
        if(xctx->semaphore >= 2) break;
        /* ISSUE 0263 -- the third door into the same drivers, gated the same way as the `netlist`
         * verb (scheduler.c, where the full reasoning lives). It MUST precede the unselect_all(1)
         * below: that call is what zeroes ui_state wholesale (select.c) and so destroys the very
         * bits both gates test -- after it there is no gesture left to abandon, only a committed
         * object nobody asked for. Placement first, merge second (shared preview_sel stamp).
         * Code-proved only, like the screen-grab gate in draw.c: this path needs `xschem callback`
         * and a live window, so it carries no headless check. */
        leave_placement_for("Netlist");
        leave_merge_for("Netlist");
        unselect_all(1);
        if( set_netlist_dir(0, NULL) ) {
          dbg(1, "callback(): -------------\n");
          if(xctx->netlist_type == CAD_SPICE_NETLIST)
            err = global_spice_netlist(0, 1);
          else if(xctx->netlist_type == CAD_VHDL_NETLIST)
            err = global_vhdl_netlist(0, 1);
          else if(xctx->netlist_type == CAD_SPECTRE_NETLIST)
            err = global_spectre_netlist(0, 1);
          else if(xctx->netlist_type == CAD_VERILOG_NETLIST)
            err = global_verilog_netlist(0, 1);
          else if(xctx->netlist_type == CAD_TEDAX_NETLIST)
            err = global_tedax_netlist(0, 1);
          else
            tcleval("tk_messageBox -type ok -parent [xschem get topwindow] "
                    "-message {Please Set netlisting mode (Options menu)}");
          dbg(1, "callback(): -------------\n");
          /* action-log (issue 0071 atom 14): the Shift-N current-level netlist
           * bypasses the scheduler `netlist` branch (it calls global_*_netlist()
           * directly), so it logs its own equivalent at this entry site (the atom-4
           * Ctrl-S/Alt-S keyboard-bypass pattern). The key runs global_*_netlist(0,1)
           * and touches NOTHING else -- crucially it does NOT clear xctx->netlist_name
           * and does NOT force show_infowindow_after_netlist=never. The faithful branch
           * form is therefore `netlist -erc -nohier`, NOT bare `-nohier`: `-nohier`
           * gives current-level (hier_netlist=0 -> the same global_*_netlist(0,1)), and
           * `-erc` (erc=1) is the STATE-PRESERVING flag here -- it is NOT separate ERC
           * work (ERC checks run inside global_*_netlist regardless of the flag); erc=1
           * simply skips BOTH the netlist_name clear and the infowindow suppression that
           * the branch's erc==0 arm performs (scheduler.c), which the key never does. A
           * bare `-nohier` line would clear a custom netlist_name the key had preserved,
           * diverging a LATER replayed netlist to the wrong output file (adversarial
           * review MAJOR, 2 independent verifiers). Logged inside the set_netlist_dir()
           * success arm so the dir-unwritable else logs nothing; disjoint from the branch
           * (no Shift-N binding entry -> the legacy switch runs) so one action = one line. */
          log_action("xschem netlist -erc -nohier");
        }
        else {
           if(has_x) tcleval("alert_ {Can not write into the netlist directory. Please check} {}");
           else dbg(0, "Can not write into the netlist directory. Please check");
           err = 1;
        }
        if(err) {
          if(has_x) {
            tclvareval("catch {", xctx->top_path, ".menubar entryconfigure Netlist -background red}", NULL);
            tclvareval("set tctx::", xctx->current_win_path, "_netlist red", NULL);
          }
        } else {
          if(has_x) {
            tclvareval("catch {", xctx->top_path, ".menubar entryconfigure Netlist -background Green}", NULL);
            tclvareval("set tctx::", xctx->current_win_path, "_netlist Green", NULL);
          }
        }

      }
      else if(rstate == ControlMask ) { /* clear symbol */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        tcleval("xschem clear symbol");
      }
      break;

    case 'o':
      if(EQUAL_MODMASK) { /* load in new tab/window */
        xctx->semaphore--;
        ask_new_file(1, NULL);
        tcleval("load_additional_files");
        xctx->semaphore++;
      }
      else if(rstate == ControlMask) { /* load */
        if(xctx->semaphore >= 2) break;
        if(tclgetboolvar("new_file_browser")) {
          tcleval("file_chooser");
        } else {
          xctx->semaphore--;
          ask_new_file(0, NULL);
          tcleval("load_additional_files");
          xctx->semaphore++;
        }
      }
      break;

    case 'O':
      if(rstate == ControlMask ) { /* load most recent tile */
        xctx->semaphore--;
        if(tclgetboolvar("open_in_new_window")) {
          tclvareval("xschem load_new_window -lastopened", NULL);
        } else {
          tclvareval("xschem load -gui -lastopened", NULL);
        }
        xctx->semaphore++;
      }
      /* plain 'O' (toggle light/dark colorscheme) is data-driven now ->
       * view.toggle_colorscheme (Phase 3d.2). */
      break;

    case 'p':
      /* plain p -> sym.place_symbol_pin (add-pin dialog); Shift+P -> tools.insert_polygon:
       * both are registry actions (init_input_bindings), dispatched before this switch. */
      if(rstate == ControlMask) { /* Ctrl+P: place input port label */
         if(readonly_block()) break;
         place_net_label(2);
      }
      break;

    case 'P':
      /* old Shift+P pan is now view.center_at_cursor (registry action, shipped unbound);
       * Shift+P now starts a polygon via the registry. */
      if(rstate == ControlMask) { /* Ctrl+Shift+P: place output port label */
         if(readonly_block()) break;
         place_net_label(3);
      }
      break;

    case 'q':
      if(rstate==ControlMask) { /* quit xschem */
        if(xctx->semaphore >= 2) break;
        /* must be set to zero, otherwise switch_tab/switch_win does not proceed
         * and these are necessary when closing tabs/windows */
        xctx->semaphore = 0;
        tcleval("quit_xschem");
      }
      else if(rstate==0) { /* edit attributes */
        if(xctx->semaphore >= 2) break;
        /* Viewing properties is NOT an edit (issue 0051): open the form even on a
         * read-only view. The form opens as a viewer there -- OK/Apply greyed,
         * Enter == Esc (Cancel) -- so nothing can be committed (property_form.tcl
         * + the gfx/legacy dialogs). The menu path (xschem edit_prop) was already
         * unguarded; this makes the 'q' key match it. ('Q' = edit-with-editor
         * stays an explicit edit and keeps its readonly_block below.) */
        edit_property(0);
      }
      else if(EQUAL_MODMASK) { /* edit .sch file (DANGER!!) */
        if(xctx->semaphore >= 2) break;
        rebuild_selected_array();
        if(xctx->lastsel==0 ) {
          my_snprintf(str, S(str), "edit_file {%s}", abs_sym_path(xctx->sch[xctx->currsch], ""));
          tcleval(str);
        }
        else if(xctx->sel_array[0].type==ELEMENT) {
          my_snprintf(str, S(str), "edit_file {%s}",
             abs_sym_path(tcl_hook2(xctx->inst[xctx->sel_array[0].n].name), ""));
          tcleval(str);

        }
      }
      break;

    case 'Q':
      if(rstate == 0) { /* edit attributes in editor */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        edit_property(1);
      }
      else if(rstate == ControlMask) { /* view attributes */
        edit_property(2);
      }
      break;

    case 'r':
      if(/* !xctx->ui_state && */ rstate==0) { /* start rect */
        dbg(1, "callback(): start rect\n");
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        /* A shape draw jams a live wire draw exactly as a placement does, and this is the key the
         * user hit: `w`, click, `r` under cadence_style_rc left ui=65537 [STARTWIRE|MENUSTARTRECT]
         * with the wire claiming every click, so the rectangle could never start (2026-08-07).
         * Gated OUTSIDE the infix test because both branches need it -- see leave_wire_draw_for(),
         * phase 1 of plan_modal_gesture_exclusion.md. */
        leave_wire_draw_for("Rectangle");
        leave_shape_draw_for("Rectangle");   /* issue 0269 -- phase 3, all four gates at every shape
                                              * arm: see the ctx-menu Rectangle pick */
        leave_placement_for("Rectangle");
        leave_merge_for("Rectangle");
        if(infix_interface) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          xctx->last_command = 0;
          new_rect(PLACE,xctx->mousex_snap, xctx->mousey_snap);
        } else {
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTRECT;
        }
      }
      else if((rstate == ControlMask) && cadence_compat) { /* simulate (for cadence users) */
        int noask = tclgetboolvar("no_ask_simulate");
        if(xctx->semaphore >= 2) break;
        if(waves_selected(event, key, state, button)) {
          waves_callback(event, mx, my, key, button, aux, state);
          break;
        }
        if(!noask) tcleval("tk_messageBox -type okcancel -parent [xschem get topwindow] "
                "-message {Run circuit simulation?}");
        if(noask || strcmp(tclresult(),"ok")==0) {
          tcleval("[xschem get top_path].menubar invoke Simulate");
        }
      }
      /* Alt-r / Super-r (rotate objects around their anchor points, 20171208) is
       * data-driven now: edit.rotate_in_place, default rows key 114 alt|super canvas.
       * Handled by the DEV_KEY dispatch above; see act_rotate_in_place. */
      break;

    case 'R':
      if(rstate == 0) { /* rotate */
        if(readonly_block()) break;
        if(xctx->ui_state & STARTMOVE) move_objects(ROTATE,0,0,0);
        else if(xctx->ui_state & STARTCOPY) copy_objects(ROTATE);
        else {
          rebuild_selected_array();
          if(xctx->lastsel == 0) {
            /* Cases 1 & 3 (rotate_keep_connected_stretch.md): nothing selected -> arm a
             * prompt-for-object rotate. Assigning ui_state2 abandons any pending verb-noun
             * move/stretch (Case 3). Plain rotate; wires are NOT kept connected. */
            xctx->ui_state |= MENUSTART;
            xctx->ui_state2 = MENUSTARTROTATE;
            xctx->menu_pending_transform = PENDING_TR_ROTATE;
            statusmsg_hold("Rotate: click an object to rotate", 1);
          } else {
            /* standalone Shift-R (single-inline apply, no group form): route through the mutation
             * boundary (Refactor B atom 6). perform_action->run_core owns the readonly gate + the
             * rebuild+seed-pivot+START+ROTATE+END effect + the ONE `xschem rotate x y` log
             * (core_log_action). The pivot is the mouse-snap point, passed as argv[2]/argv[3];
             * run_core re-seeds mx/my_double_save = mousex/y_snap from it exactly as this block
             * did. readonly was already refused by readonly_block() at the top of case 'R' (which
             * also guards the raw gesture arms + the arming path). issue 0068's "Shift-R logs
             * nothing" note is now stale -- Shift-R self-logs its pivot form via the boundary. */
            char sx[64], sy[64]; const char *av[4];
            my_snprintf(sx, S(sx), "%.16g", xctx->mousex_snap);
            my_snprintf(sy, S(sy), "%.16g", xctx->mousey_snap);
            av[0] = "xschem"; av[1] = "rotate"; av[2] = sx; av[3] = sy;
            perform_action("rotate", 4, av);
          }
        }

      }
      break;

    case 's':
      if((rstate == 0) && !cadence_compat) { /* simulate (original keybind) */
        int noask = tclgetboolvar("no_ask_simulate");
        if(xctx->semaphore >= 2) break;
        if(waves_selected(event, key, state, button)) {
          waves_callback(event, mx, my, key, button, aux, state);
          break;
        }
        if(!noask) tcleval("tk_messageBox -type okcancel -parent [xschem get topwindow] "
                "-message {Run circuit simulation?}");
        if(noask || strcmp(tclresult(),"ok")==0) {
          tcleval("[xschem get top_path].menubar invoke Simulate");
        }
      }
      /* create wire snapping to closest instance pin (cadence keybind) */
      else if(/* !xctx->ui_state && */ (rstate == 0) && cadence_compat) {
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        leave_shape_draw_for("Snap wire");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
        if(!leave_placement_for("Snap wire")) break;   /* issue 0243 F2 -- see leave_placement_for() */
        if(!leave_merge_for("Snap wire")) break;       /* issue 0265 -- phase 4 */
        snapped_wire(c_snap);
      }
      else if(rstate == ControlMask ){ /* save 20121201 */
        if(xctx->semaphore >= 2) break;
        /* graph routing migrated (Phase 3d.1b): idle_only over_graph -> graph.forward. */
        /* check if unnamed schematic, use saveas in this case */
        if(!strcmp(xctx->sch[xctx->currsch],"") || strstr(xctx->sch[xctx->currsch], "untitled")) {
          saveas(NULL, SCHEMATIC);
        } else {
          /* Ctrl-S is an explicit, unambiguous save: just write the file, no
           * "save file?" confirmation (matches the File>Save menu / `xschem save`,
           * which already call save(0,...)). */
          save(0, 0);
          /* self-log Ctrl-S (0062): inline path bypasses the scheduler save branch
           * (the branch rejects read-only before its log; mirror that here) */
          if(!xctx->readonly) log_action("xschem save");
        }
      }

      else if(EQUAL_MODMASK) { /* reload */
        if(xctx->semaphore >= 2) break;
        tcleval("tk_messageBox -type okcancel -parent [xschem get topwindow] "
                 "-message {Are you sure you want to reload from disk?}");
        if(strcmp(tclresult(),"ok")==0) {
          char filename[PATH_MAX];
          unselect_all(1);
          remove_symbols();
          my_strncpy(filename, abs_sym_path(xctx->sch[xctx->currsch], ""), S(filename));
          load_schematic(1, filename, 1, 1);
          draw();
          /* self-log Alt-S (0062): inline reload bypasses the scheduler branch;
           * inside the "ok" arm so a cancelled dialog logs nothing */
          log_action("xschem reload");
        }
      }

      else if(SET_MODMASK && (state & ControlMask) ) { /* save as symbol */
        if(xctx->semaphore >= 2) break;
        saveas(NULL, SYMBOL);
      }
      break;

    case 'S':
      if(rstate == 0) { /* change element order */
        /* Refactor B atom 21: the Shift-S key routes through the perform_action boundary (not the
         * raw change_elem_order(-1)) with av[2]="-1" -- the break_wires Ctrl-! FLAG-arg pattern. The
         * inline rebuild_selected_array + had_sel gate + change_elem_order(-1) + log_action are GONE
         * (run_core rebuilds/guards; core_log_action logs the ONE value-preserving
         * `xschem change_elem_order -1` line). The semaphore>=2 + readonly_block() key self-guards
         * STAY (like break_wires's '!'/Ctrl-! keys) -- readonly_block() keeps the read-only messageBox
         * this legacy-switch key posted, which the boundary's silent TCL_ERROR would drop (an
         * ActionEvent-style handler DISCARDS perform_action's rc and falls through to break, the
         * toggle_ignore atom-12 event-handled contract). C89: av at block top. */
        const char *av[3];
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        av[0] = "xschem"; av[1] = "change_elem_order"; av[2] = "-1";
        perform_action("change_elem_order", 3, av);
      }
      else if(rstate == ControlMask) { /* save as schematic */
        if(xctx->semaphore >= 2) break;
        saveas(NULL, SCHEMATIC);
      }
      break;

    case 't':
      if(rstate == 0) { /* place text (graph routing is data: over_graph -> graph.forward) */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        /* phase 2 -- see leave_wire_draw_for(). `t` needs a Tk toplevel (place_text opens the text
         * dialog), so this branch is not drivable headlessly; `xschem place_text` is its scriptable
         * twin and carries the same gate. Before the gate this key left ui=1 [STARTWIRE] with
         * last_command zeroed -- the exact residue issue 0243 F3 had to teach ESC to clean up. */
        leave_wire_draw_for("Place text");
        leave_shape_draw_for("Place text");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
        leave_placement_for("Place text");  /* issue 0242 -- the `t` key, twin of the verb */
        leave_merge_for("Place text");      /* issue 0265 -- ditto for a pending paste */
        xctx->last_command = 0;
        xctx->mx_double_save = xctx->mousex_snap;
        xctx->my_double_save = xctx->mousey_snap;
        if(place_text(0, xctx->mousex_snap, xctx->mousey_snap)) { /* 1 = draw text 24122002 */
          xctx->mousey_snap = xctx->my_double_save;
          xctx->mousex_snap = xctx->mx_double_save;
          move_objects(START,0,0,0);
          stamp_placement_preview();  /* issue 0241, same note as the context-menu twin at :4460 */
          xctx->ui_state |= PLACE_TEXT;
        }
      }
      else if(rstate & ControlMask) { /* new schematic */
        int save = xctx->semaphore;
        /* Exact Ctrl+t routing is data (over_graph row); this guard remains only for
         * the Ctrl+<other mods> remainder the row doesn't cover (rstate != ControlMask).
         * Skipping it for the exact chord also avoids a redundant waves_selected. */
        if((rstate != ControlMask) && waves_selected(event, key, state, button)) {
          waves_callback(event, mx, my, key, button, aux, state);
          break;
        }
        if(xctx->semaphore >= 2) break;
        xctx->semaphore = 0;
        new_schematic("create", NULL, NULL, 1);
        xctx->semaphore = save;
      }
      break;

    case 'T':
      /* plain 'T' (toggle *_ignore on selected instances) is data-driven now ->
       * prop.toggle_ignore_attribute_on_selected_instances (Phase 3d.2). */
      if(rstate == ControlMask ) { /* load last closed */
        xctx->semaphore--;
        if(tclgetboolvar("open_in_new_window")) {
          tclvareval("xschem load_new_window -lastclosed", NULL);
        } else {
          tclvareval("xschem load -gui -lastclosed", NULL);
        }
        xctx->semaphore++;
      }

      break;

    case 'u':
      /* plain 'u' (undo) migrated to the binding table (Phase 3d.2 sem-gated batch 1):
       * key 'u' 0 canvas -> edit.undo, idle_only (Tcl `xschem undo; xschem redraw` =
       * pop_undo(0,1)+draw()). The Alt (align) and Ctrl (unselect floaters) branches
       * stay in C. See init_input_bindings. */
      if(EQUAL_MODMASK) { /* align to grid */
        if(xctx->semaphore >= 2) break;       /* key-specific re-entrancy guard stays here */
        /* Route through the single mutation boundary (Refactor B atom 2, scheduler.c): it
         * owns the readonly gate (scheduler_readonly_reject -> a CIW note, replacing this
         * key's old readonly_block() modal), the push_undo + round_schematic_to_grid +
         * maintain + draw effect, and the ONE `xschem align` log site. No inline readonly/
         * undo/log here. The boundary reads cadsnap the same way the c_snap local was
         * derived (tclgetdoublevar("cadsnap"), callback entry), so the snap is identical. */
        perform_action("align", 0, NULL);
      }
      else if(rstate==ControlMask) { /* Unselect floater texts */
        unselect_attached_floaters();
      }

      break;

    /* case 'U' (redo) fully migrated to the binding table (Phase 3d.2 sem-gated
     * batch 1): plain -> edit.redo, idle_only canvas (Tcl `xschem redo; xschem redraw`
     * = pop_undo(1,1)+draw()). See init_input_bindings. */

    case 'v':
      if(rstate==0) { /* vertically constrained drag 20171023 */
        if ( xctx->constr_mv == 2 ) {
          tcleval("set constr_mv 0" );
          xctx->constr_mv = 0;
        } else {
          tcleval("set constr_mv 2" );
          xctx->constr_mv = 2;
        }
        if(xctx->ui_state & STARTWIRE) {
          if(xctx->constr_mv == 1) xctx->mousey_snap = xctx->my_double_save;
          if(xctx->constr_mv == 2) xctx->mousex_snap = xctx->mx_double_save;
          new_wire(RUBBER, xctx->mousex_snap, xctx->mousey_snap);
        }
        if(xctx->ui_state & STARTLINE) {
          if(xctx->constr_mv == 1) xctx->mousey_snap = xctx->my_double_save;
          if(xctx->constr_mv == 2) xctx->mousex_snap = xctx->mx_double_save;
          new_line(RUBBER, xctx->mousex_snap, xctx->mousey_snap);
        }
      }
      else if(rstate == ControlMask) { /* paste from clipboard */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        merge_file(2,".sch");
      }
      /* Alt-v / Super-v (vertical flip around anchor points) is data-driven now:
       * edit.flipv_in_place, default rows key 118 alt|super canvas. Handled by the
       * DEV_KEY dispatch above; see act_flipv_in_place. */
      break;

    case 'V':
      if(rstate == 0) { /* vertical flip */
        if(readonly_block()) break;
        if(xctx->ui_state & STARTMOVE) {
          move_objects(ROTATE,0,0,0);
          move_objects(ROTATE,0,0,0);
          move_objects(FLIP,0,0,0);
        }
        else if(xctx->ui_state & STARTCOPY) {
          copy_objects(ROTATE);
          copy_objects(ROTATE);
          copy_objects(FLIP);
        }
        else {
          rebuild_selected_array();
          if(xctx->lastsel == 0) { /* Cases 1 & 3: arm prompt-for-object vertical flip */
            xctx->ui_state |= MENUSTART;
            xctx->ui_state2 = MENUSTARTROTATE;
            xctx->menu_pending_transform = PENDING_TR_FLIPV;
            statusmsg_hold("Vertical flip: click an object to flip", 1);
          } else {
            /* standalone Shift-V (single-inline apply, no group form): route through the mutation
             * boundary (Refactor B atom 8, the LAST pivot form, mirror of Shift-F atom 7).
             * perform_action->run_core owns the readonly gate + the rebuild+seed-pivot+START+
             * ROTATE+ROTATE+FLIP+END effect (net vertical mirror) + the ONE `xschem flipv x y` log
             * (core_log_action). The pivot is the mouse-snap point, passed as argv[2]/argv[3];
             * run_core re-seeds mx/my_double_save = mousex/y_snap from it exactly as this block did.
             * readonly was already refused by readonly_block() at the top of case 'V' (which also
             * guards the raw gesture arms + the arming path). Unlike Alt-R/Alt-F, Shift-V has NO
             * standalone_group_transform (no group form), so this is flipv's only key entry site. */
            char sx[64], sy[64]; const char *av[4];
            my_snprintf(sx, S(sx), "%.16g", xctx->mousex_snap);
            my_snprintf(sy, S(sy), "%.16g", xctx->mousey_snap);
            av[0] = "xschem"; av[1] = "flipv"; av[2] = sx; av[3] = sy;
            perform_action("flipv", 4, av);
          }
        }
      }
      else if(rstate == ControlMask) { /* toggle spice/vhdl netlist */
        xctx->netlist_type++;
        if(xctx->netlist_type==7) xctx->netlist_type=1;
        set_tcl_netlist_type();
        draw(); /* needed to ungrey or grey out  components due to *_ignore attribute */
      }
      break;

    case 'w':
      if(/* !xctx->ui_state && */ rstate==0) { /* place wire. */
        int prev_state = xctx->ui_state;
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        leave_shape_draw_for("Wire");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
        if(!leave_placement_for("Wire")) break;   /* issue 0243 F2 -- see leave_placement_for() */
        if(!leave_merge_for("Wire")) break;       /* issue 0265 -- phase 4, a draw cancels a paste */
        prev_state = xctx->ui_state;   /* the teardowns just cleared the placement/merge bits */

        if(infix_interface) {
          start_wire(xctx->mousex_snap, xctx->mousey_snap);
          if(prev_state == STARTWIRE) {
            tcleval("set constr_mv 0" );
            xctx->constr_mv=0;
          }
        } else {
          xctx->last_command = 0;
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTWIRE;
          if(prev_state & STARTWIRE) start_wire(xctx->mousex_snap, xctx->mousey_snap);
        }
      }
      else if(rstate == ControlMask) { /* close current schematic */
        int save_sem;
        if(xctx->semaphore >= 2) break;
        save_sem = xctx->semaphore;
        /* must be 0 so the go_back walk-up in close_schematic_window can proceed
         * (mirrors the Ctrl-Q / quit_xschem path) */
        xctx->semaphore = 0;
        tcleval("close_schematic_window");
        xctx->semaphore = save_sem;
      }
      break;

    case 'W':
      if(/* !xctx->ui_state && */ (rstate == 0) && !cadence_compat) { /* create wire snapping to closest instance pin (original keybind) */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        leave_shape_draw_for("Snap wire");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
        if(!leave_placement_for("Snap wire")) break;   /* issue 0243 F2 -- see leave_placement_for() */
        if(!leave_merge_for("Snap wire")) break;       /* issue 0265 -- phase 4 */
        snapped_wire(c_snap);
      }
      break;

    case 'x':
      if(rstate == 0) { /* new cad session */
        new_xschem_process(NULL ,0);
      }
      else if(EQUAL_MODMASK) { /* toggle draw crosshair at mouse pos */
        if(tclgetboolvar("draw_crosshair")) {
          tclsetvar("draw_crosshair", "0");
        } else {
          tclsetvar("draw_crosshair", "1");
        }
        draw();
      }
      else if(rstate == ControlMask) { /* cut selection into clipboard */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        rebuild_selected_array();
        if(xctx->lastsel) { /* 20071203 check if something selected */
          save_selection(2);
          delete(1/* to_push_undo */);
          /* action-log (issue 0071): Ctrl-X is an inline legacy-switch key -- it never
           * reaches the `xschem cut` scheduler branch, so it must self-log here. Logged as
           * `xschem cut` (fills the clipboard), NOT `xschem delete`. delete() is a shared
           * primitive (aborts/merges/preview teardown call it too) so it is deliberately not
           * the log site -- the cut/delete VERBS live at the scheduler branch + these keys.
           * See doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md */
          log_action("xschem cut");
        }
      }
      break;

    case 'X':
      if(rstate == 0) { /* highlight discrepanciens between selected instance pin and net names */
        hilight_net_pin_mismatches();
      }
      if(rstate == ControlMask) { /* create xplot command of hilight signals for ngspice */
        create_plot_cmd();
      }
      break;

    /* case 'y' (toggle stretching) migrated to the binding table (Phase 3d.2):
     * key 'y' 0 canvas -> edit.toggle_stretch. See init_input_bindings. */

    case 'z':
      /* zoom box */
      if(rstate == 0) {
        /* ISSUE 0269 -- phase 3. The guard below used to be a DECLINE: with any other draw live,
         * `z` did nothing at all and the user got no feedback. The ratified rule is cancel-and-arm
         * ("whatever you just pressed is what you meant"), so the four gates run first and the
         * guard is now a backstop that is always true by the time it is reached -- kept rather than
         * deleted because it is the cheap local statement of what this arm may not coexist with.
         * Sited INSIDE the rstate==0 test on purpose: with a modifier held this case falls through
         * to the other `z` chords (the cadence snap-cursor branch below), and tearing down a live
         * gesture for one of those would be a mutation the user never asked for. */
        leave_shape_draw_for("Zoom box");
        leave_wire_draw_for("Zoom box");
        leave_placement_for("Zoom box");
        leave_merge_for("Zoom box");
        if(!(xctx->ui_state & (STARTRECT | STARTLINE | STARTWIRE | STARTPOLYGON | STARTARC))) {
          dbg(1, "callback(): zoom_rectangle call\n");
          zoom_rectangle(START);
        }
      }
      /* Ctrl-'z' (zoom out) migrated to the binding table (Phase 3d.5a): exact chord,
       * canvas row -> view.zoom_out. Plain 'z' stays (ui_state-conditioned modal
       * zoom-rect start) and so does the cadence_compat snap-cursor branch below. */
      else if(EQUAL_MODMASK && cadence_compat) { /* toggle snap-cursor option */
        if(tclgetboolvar("snap_cursor")) {
          tclsetvar("snap_cursor", "0");
          draw_snap_cursor(1);
          xctx->closest_pin_found = 0;
          xctx->prev_snapx = 0.0;
          xctx->prev_snapy = 0.0;
        } else {
          tclsetvar("snap_cursor", "1");
          if(wire_draw_active) draw_snap_cursor(3);
        }
      }
      break;

    /* case 'Z' fully migrated to the binding table (Phase 3d.5a): canvas ->
     * view.zoom_in (modified-Z chords were no-ops before and still are; no row
     * matches them, and there is no case to fall back to). */

    case ' ':
      /* SPACE's default action is edit.add_pin_stubs (binding table). It is idle_only, so the
       * dispatch skips it while busy (semaphore>=2) -- and act_add_pin_stubs also declines
       * (returns 0) during a move/wire/line gesture, with an empty selection, or whenever it
       * did not stub (nothing stubbable / read-only view). In all those cases SPACE reaches
       * here and this fallback reproduces the historical SPACE behavior from the SAME extracted
       * cores: cycle the gesture's manhattan corner, else drag-pan. Also the graceful degrade
       * if SPACE is un-bound in keybindings.csv. (B6, doc/claude/specs/wire_stub_netlabel.md.) */
      if(!cycle_manhattan_lines()) start_pan_at(mx, my);
      break;

    case '_':                                         /* toggle change line width */
      if(!xctx->change_lw) {
          tcleval("alert_ { enabling change line width} {}");
          tclsetvar("change_lw","1");
          xctx->change_lw = 1;
      }
      else {
          tcleval("alert_ { disabling change line width} {}");
          tclsetvar("change_lw","0");
          xctx->change_lw = 0;
      }
      break;

    /* '%' (toggle draw grid) is data-driven now: registered action view.toggle_draw_grid,
     * shipped UNBOUND and user-bound via `xschem bind` (cadence_style_rc binds CTRL-G to
     * it by default). doc/claude/specs/keybind_snap_grid_actions.md. The hardcoded case is removed. */

    case '$':
      /* plain '$' (toggle pixmap saving) migrated to the binding table (Phase 3d.2
       * batch 3): key '$' 0 canvas -> view.toggle_draw_pixmap. The Ctrl branch
       * (toggle window drawing) stays in C. See init_input_bindings. */
      if(state & ControlMask) { /* toggle window  drawing */
        xctx->draw_window =!xctx->draw_window;
        if(xctx->draw_window) {
          tcleval("alert_ { enabling draw window} {}");
          tclsetvar("draw_window","1");
        } else {
          tcleval("alert_ { disabling draw window} {}");
          tclsetvar("draw_window","0");
        }
      }
      break;

    case '=':
      /* plain '=' (Tcl command console) migrated to the binding table (Phase 3d.2
       * batch 3): key '=' 0 canvas -> tools.execute_tcl_command (Tcl-backed "tclcmd").
       * The Ctrl branch (toggle fill rectangles) stays in C. See init_input_bindings. */
      if(state & ControlMask) { /* toggle fill rectangles */
        int x;
        xctx->fill_pattern++;
        if(xctx->fill_pattern==2) xctx->fill_pattern=0;

        if(xctx->fill_pattern==1) {
         tcleval("alert_ { Stippled pattern fill} {}");
         for(x=0;x<cadlayers;x++) {
           if(xctx->fill_type[x]==2) XSetFillStyle(display,xctx->gcstipple[x],FillSolid);
           else XSetFillStyle(display,xctx->gcstipple[x],FillStippled);
         }
        }
        else if(xctx->fill_pattern==2) {
         tcleval("alert_ { solid pattern fill} {}");
         for(x=0;x<cadlayers;x++)
          XSetFillStyle(display,xctx->gcstipple[x],FillSolid);
        }
        else  {
         tcleval("alert_ { No pattern fill} {}");
         for(x=0;x<cadlayers;x++)
          XSetFillStyle(display,xctx->gcstipple[x],FillStippled);
        }

        draw();
      }
      break;

    case '+':
      if(state & ControlMask) { /* change line width */
        xctx->lw = round_to_n_digits(xctx->lw + 0.5, 2);
        change_linewidth(xctx->lw);
        draw();
      }
      break;

    case '-':
      if(state & ControlMask) { /* change line width */
        xctx->lw = round_to_n_digits(xctx->lw - 0.5, 2);
        if(xctx->lw < 0.0) xctx->lw = 0.0;
        change_linewidth(xctx->lw);
        draw();
      }
      else if(EQUAL_MODMASK) {
        tcleval("input_line \"Enter linewidth (float):\" \"xschem line_width\"");
      }
      break;

    case XK_Return:
      if((state == 0 ) && xctx->ui_state & STARTPOLYGON) { /* close polygon */
        new_polygon(ADD|END, xctx->mousex_snap, xctx->mousey_snap);
      }
      break;

    case XK_Escape:                                       /* abort & redraw */
      /* the whole body now lives in escape_terminal() (issue 0245), so a Tk form that seized
       * `.drw <Key-Escape>` can forward to it through `xschem escape` instead of swallowing
       * Escape whole. Behaviour here is unchanged. */
      escape_terminal();
      break;

    case XK_Delete:
      /* Delete a SELECTED waveform marker (doc/claude/specs/graph_markers.md).
       * Deliberately an inline guard and NOT an ACTX_OVER_GRAPH binding row: a
       * row would consume Delete over a graph unconditionally and silently break
       * "select a graph rect, hover it, press Delete -> the graph is deleted".
       * The selgraph test scopes the delete to the strip the pointer is over.
       * With nothing selected graph_marker_delete_selected() returns 0 without
       * touching anything and control falls into the historical body below.
       * The hoisted semaphore test is a strict no-op for the old behaviour (the
       * body already breaks on it, and without SELECTION the case does nothing)
       * but it keeps a marker delete -- push_undo + prop write + a Tcl push --
       * from firing while a modal dialog is up. */
      if(xctx->semaphore >= 2) break;
      if(rstate == 0 && xctx->graph_marker_sel >= 0 &&
         waves_selected(event, key, state, button)) {
        /* the owning strip is RE-RESOLVED, not read off graph_marker_selgraph:
         * that is a rect index and goes stale on a strip reorder / a multi-plot
         * prepend, which would fire the delete from the wrong strip and refuse
         * on the one actually showing the ring */
        int sgi = -1;
        if(graph_marker_find(xctx->graph_marker_sel, &sgi, NULL) &&
           sgi == xctx->graph_master) {
          /* read-only is refused inside graph_marker_delete(), non-blocking --
           * see the m/d arms in waves_callback for why not readonly_block() */
          if(graph_marker_delete_selected()) {
            draw();
            break;
          }
        }
      }
      if(xctx->ui_state & SELECTION) { /* delete selection */
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        delete(1/* to_push_undo */);
        /* action-log (issue 0071): the Delete key is an inline legacy-switch handler that
         * never reaches the `xschem delete` scheduler branch, so it self-logs here. Guarded
         * by the SELECTION check above, so an empty-selection Delete logs nothing (no
         * phantom). delete() itself is a shared primitive (aborts/merges call it) and is not
         * the log site. See
         * doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md */
        log_action("xschem delete");
      }
      break;

    case XK_Tab:
      if(state == ControlMask) {
        int save = xctx->semaphore;
        if(xctx->semaphore >= 2) break;
        xctx->semaphore = 0;
        /* tcleval("next_tab"); */
        new_schematic("switch", "previous", "", 1);
        xctx->semaphore = save;
      }
#ifndef __unix__
      else if(state == ShiftMask) {
        int save = xctx->semaphore;
        if(xctx->semaphore >= 2) break;
        xctx->semaphore = 0;
        tcleval("next_tab");
        xctx->semaphore = save;
      }
      else if(state == (ControlMask | ShiftMask)) {
        int save = xctx->semaphore;
        if(xctx->semaphore >= 2) break;
        xctx->semaphore = 0;
        tcleval("prev_tab");
        xctx->semaphore = save;
      }
#endif
      break;
#ifdef __unix__
    case XK_ISO_Left_Tab: /* Shift is pressed */
      if(state == (ControlMask | ShiftMask)) {
        int save = xctx->semaphore;
        if(xctx->semaphore >= 2) break;
        xctx->semaphore = 0;
        tcleval("prev_tab");
        xctx->semaphore = save;
      }
      else if(state == ShiftMask) {
        int save = xctx->semaphore;
        if(xctx->semaphore >= 2) break;
        xctx->semaphore = 0;
        tcleval("next_tab");
        xctx->semaphore = save;
      }

      break;
#endif
    case XK_Right:
      /* No-modifier scroll is data-driven now (view.scroll_right; see
       * init_input_bindings, Phase 3c) and never reaches here. This case still owns
       * Ctrl (tab switch) and every other modified chord — do not delete the else
       * pan, it serves Shift/Alt/lock-mask arrows. */
      if(state == ControlMask) { /* tab switch (graph routing is data: over_graph -> graph.forward) */
        int save = xctx->semaphore;
        if(xctx->semaphore >= 2) break;
        xctx->semaphore = 0;
        tcleval("next_tab");
        xctx->semaphore = save;
      }
      else { /* left */
        if(waves_selected(event, key, state, button)) {
          waves_callback(event, mx, my, key, button, aux, state);
          break;
        }
        xctx->xorigin+=-CADMOVESTEP*xctx->zoom;
        draw();
        redraw_w_a_l_r_p_z_rubbers(1);
      }
      break;

    case XK_Left:
      /* No-modifier scroll is data-driven (view.scroll_left, Phase 3c). This case
       * still owns Ctrl (tab switch) and other modified chords. */
      if(state == ControlMask) { /* tab switch (graph routing is data: over_graph -> graph.forward) */
        int save = xctx->semaphore;
        if(xctx->semaphore >= 2) break;
        xctx->semaphore = 0;
        tcleval("prev_tab");
        xctx->semaphore = save;
      }
      else { /* right */
        if(waves_selected(event, key, state, button)) {
          waves_callback(event, mx, my, key, button, aux, state);
          break;
        }
        xctx->xorigin-=-CADMOVESTEP*xctx->zoom;
        draw();
        redraw_w_a_l_r_p_z_rubbers(1);
      }
      break;

    case XK_Down:          /* down */
      /* No-modifier scroll is data-driven (view.scroll_down, Phase 3c); this case
       * still handles Down + ANY modifier (the historical mod-agnostic pan, incl.
       * lock masks) — keep it. */
      if(waves_selected(event, key, state, button)) {
        waves_callback(event, mx, my, key, button, aux, state);
        break;
      }
      xctx->yorigin+=-CADMOVESTEP*xctx->zoom;
      draw();
      redraw_w_a_l_r_p_z_rubbers(1);
      break;

    case XK_Up:           /* up */
      /* No-modifier scroll is data-driven (view.scroll_up, Phase 3c); this case
       * still handles Up + ANY modifier — keep it. */
      if(waves_selected(event, key, state, button)) {
        waves_callback(event, mx, my, key, button, aux, state);
        break;
      }
      xctx->yorigin-=-CADMOVESTEP*xctx->zoom;
      draw();
      redraw_w_a_l_r_p_z_rubbers(1);
      break;

    case XK_BackSpace:
      if(xctx->semaphore >= 2) break;
      if(state == 0) go_back(1); /* go up in hierarchy */
      break;

#if defined(__unix__) && HAS_CAIRO==1
    case XK_Print:
      xctx->ui_state |= GRABSCREEN;
      tclvareval(xctx->top_path, ".drw configure -cursor {}" , NULL);
      tclvareval("grab set -global ", xctx->top_path, ".drw", NULL);
      break;
#endif

    case XK_Insert:
      if(state == ShiftMask) { /* insert sym */
        if(readonly_block()) break;
        if(symbol_view_block()) break;   /* no instances in a symbol view: refuse before the chooser opens */
        if(tclgetboolvar("new_file_browser")) {
          tcleval("file_chooser");
        } else {
          tcleval("load_file_dialog {Insert symbol} *.\\{sym,tcl\\} INITIALINSTDIR 2");
        }
      }
      else {
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        if(symbol_view_block()) break;   /* no instances in a symbol view: refuse before the chooser opens */
        if(tclgetboolvar("new_file_browser")) {
          tcleval("file_chooser");
        } else {
          start_place_symbol();
        }
      }
      break;

    case '*':
      if(rstate == 0 ) { /* postscript print */
        if(xctx->semaphore >= 2) break;
        ps_draw(7, 0, 0);
      }
      else if(rstate == ControlMask) {/* xpm print */
        if(xctx->semaphore >= 2) break;
        print_image();
      }
      else if(EQUAL_MODMASK) { /* svg print , 20121108 */
        if(xctx->semaphore >= 2) break;
        svg_draw();
      }
      break;

    case '&':                               /* check wire connectivity */
      if(xctx->semaphore >= 2) break;       /* key-specific re-entrancy guard stays here */
      /* Route through the single mutation boundary (Refactor B, scheduler.c): it owns
       * the readonly gate (scheduler_readonly_reject -> a CIW note, replacing this
       * key's old readonly_block() modal), the push_undo + trim_wires + draw effect,
       * and the ONE `xschem trim_wires` log site. No inline readonly/undo/log here. */
      perform_action("trim_wires", 0, NULL);
      break;

    case '\\':
      if(state==0) { /* fullscreen */
        dbg(1, "callback(): toggle fullscreen, win_path=%s\n", win_path);
        toggle_fullscreen(win_path);
      }
      break;

    case '>':
      if(xctx->semaphore >= 2) break;
      if(xctx->draw_single_layer< cadlayers-1) xctx->draw_single_layer++;
      xctx->draw_single_layer = xctx->rectcolor;
      draw();
      break;

    case '<':
      if(xctx->semaphore >= 2) break;
      xctx->draw_single_layer = -1;
      draw();
      break;

    case '?':
      if(xctx->semaphore >= 2) break;
      tcleval("textwindow \"${XSCHEM_SHAREDIR}/xschem.help\"");
      break;
    case XK_slash:
     if(xctx->semaphore >= 2) break;
     tcleval("show_bindkeys");
     break;
    /* toggle flat netlist (only spice)  */
    case ':':
      if(!tclgetboolvar("flat_netlist")) {
          tcleval("alert_ { enabling flat netlist} {}");
          tclsetvar("flat_netlist","1");
      }
      else {
          tcleval("alert_ { set hierarchical netlist } {}");
          tclsetvar("flat_netlist","0");
      }
      break;

    case '#':
      if((state & ControlMask)) {
        /* Ctrl+#: rename duplicates -- route through the mutation boundary (Refactor B atom 26):
         * readonly gate (was NONE -- a read-only cell was silently RENAMED) + effect + the ONE
         * `xschem check_unique_names 1` log (was UNLOGGED -- a 0068-class legacy-switch gap; no
         * keybindings.csv row exists, so this case is the only handler). rc DISCARDED (the
         * toggle_ignore §32 / Shift-S §41 event-handled contract). No semaphore/readonly_block
         * added: this key never had them (sibling keys only KEPT pre-existing guards);
         * scheduler_readonly_reject's ciw_echo is the read-only feedback. C89: av at block top. */
        const char *av[3];
        av[0] = "xschem"; av[1] = "check_unique_names"; av[2] = "1";
        perform_action("check_unique_names", 3, av);
      }
      else {
        /* #: duplicate highlight -- read-only-legal, stays RAW + gains its own log, mirroring the
         * scheduler branch's mode-0 front (asymmetric split, atom 26). ADDITIVE coverage: this key
         * logged nothing before. */
        check_unique_names(0);
        log_action("xschem check_unique_names 0");
      }
      break;

    case ';':
      if(0 && (state & ControlMask)) { /* testmode */
      }
      break;

    case '~':
      if(0 && (state & ControlMask)) { /* testmode */
      }
      break;

    case '|':
      if(0 && (state & ControlMask)) { /* testmode */
      }
      break;

    case '!':
      /* Route through the single mutation boundary (Refactor B atom 9, scheduler.c):
       * it owns the effect (break_wires_at_pins, which owns its own undo/draw) + the
       * ONE `xschem break_wires [1]` log site (core_log_action canonicalizes the FLAG).
       * The key-specific semaphore>=2 re-entrancy guard and the readonly_block() guard
       * stay here (the key guards itself first, like the transform keys); no inline
       * break_wires_at_pins()/log_action() remains. The Ctrl-! form carries the remove
       * FLAG in av[2]="1" (the arg is a flag, not a coordinate pivot -- so no snprintf
       * of a mouse coord, unlike the pivot keys Shift-R/F/V). */
      if((state & ControlMask)) {
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        {
          const char *av[3];
          av[0] = "xschem"; av[1] = "break_wires"; av[2] = "1";
          perform_action("break_wires", 3, av);
        }
      }
      else {
        if(xctx->semaphore >= 2) break;
        if(readonly_block()) break;
        perform_action("break_wires", 0, NULL);
      }
      break;

    default:
      break;
  }

  return;
}

static void handle_button_press(int event, int state, int rstate, KeySym key, int button, int mx, int my,
                                double c_snap, int draw_xhair, int crosshair_size, int enable_stretch,
                                int cadence_compat, int tabbed_interface, const char *win_path, int aux)
{
   int use_cursor_for_sel = tclgetintvar("use_cursor_for_selection");
   int excl = xctx->ui_state & (STARTWIRE | STARTRECT | STARTLINE | STARTPOLYGON | STARTARC);

   state &= ~(Button1Mask | Button2Mask | Button3Mask | Button4Mask | Button5Mask ); /* ignore ButtonStates */
   if(!tabbed_interface && strcmp(win_path, xctx->current_win_path)) return;
   dbg(1, "callback(): ButtonPress  ui_state=%d state=%d semaphore=%d\n",xctx->ui_state,state, xctx->semaphore);
   dbg(1, "callback(): win_path=%s\n", win_path);
   if(waves_selected(event, key, state, button)) {
     waves_callback(event, mx, my, key, button, aux, state);
     return;
   }
   /* This press is not a double-click's `-3` grow: mark it so the matching release runs the
    * escalation-reset (dblclick_connected_select.md). The grow sets the flag back to 1. */
   if(button == Button1) xctx->dblgrow_last_press_was_grow = 0;
   /* terminate a schematic pan action */
   if(xctx->ui_state & STARTPAN) {
     xctx->ui_state &=~STARTPAN;
     log_pan_end();
     return;
   }

   /* select instance and connected nets stopping at wire junctions */
   if(!excl && button == Button3 && state == ControlMask && xctx->semaphore <2)
   {
     Selected sel;
     sel = select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
     if(sel.type) select_connected_nets(1);
   }

   /* break wire at mouse coordinates, move break point to nearest grid point */
   else if(!excl && button == Button3 && EQUAL_MODMASK &&
           !(state & ShiftMask) && xctx->semaphore <2)
   {
     break_wires_at_point(xctx->mousex_snap, xctx->mousey_snap, 1);
   }
   /* break wire at mouse coordinates */
   else if(!excl && button == Button3 && EQUAL_MODMASK &&
           (state & ShiftMask) && xctx->semaphore <2)
   {
     break_wires_at_point(xctx->mousex_snap, xctx->mousey_snap, 0);
   }
   /* select instance and connected nets NOT stopping at wire junctions */
   else if(!excl && button == Button3 && state == ShiftMask && xctx->semaphore <2)
   {
     Selected sel;
     sel = select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
     if(sel.type) select_connected_nets(0);
   }
   /* moved to Button3 release */
   /*
    * else if(button == Button3 && state == 0 && xctx->semaphore <2) {
    *   context_menu_action(xctx->mousex_snap, xctx->mousey_snap);
    * }
    */

   /* Initiating chord for a mouse-button gesture (default: right-drag = zoom
    * rectangle). The chord is data-driven via the binding table, so it is
    * remappable with `xschem bind button ...`; the action sets a STARTxxx
    * ui_state bit and the rubber-band/completion handle the rest. Guards match
    * the previous hard-coded zoom branch (!excl, semaphore<2). Phase 3b. */
   else if(!excl && xctx->semaphore < 2 && dispatch_button_chord(button, state, mx, my)) {
     return;
   }

   /* Mouse wheel events */
   else if(handle_mouse_wheel(event, mx, my, key, button, aux, state)) return;

   /* terminate wire placement in snap mode */
   else if(button==Button1 && (state & ShiftMask) && (xctx->ui_state & STARTWIRE) ) {
     snapped_wire(c_snap);
   }
   /* Alt - Button1 click to unselect */
   else if(button==Button1 && (SET_MODMASK) ) {
     unselect_at_mouse_pos(mx, my);
   }

   /* Middle button press (Button2) will pan the schematic. */
   else if(button==Button2 && (state == 0)) {
     start_pan_logged(mx, my);
   }

   /* button1 click to select another instance while edit prop dialog open */
   else if(button==Button1 && xctx->semaphore >= 2) {
     if(xctx->semaphore >= 3) { /* record clicked point coordinates when ctxmenu is shown */
       xctx->mx_save = mx; xctx->my_save = my;
       xctx->mx_double_save=xctx->mousex;
       xctx->my_double_save=xctx->mousey;
     }
     /* NOTE (M2, issue 0009): the slick property form (slickprop::edit_form) is now
      * NON-BLOCKING and no longer raises the semaphore, so it is NOT reached here —
      * a live click while it is open runs at semaphore<2 and goes through the normal
      * selection path below; the form is re-targeted from the relocated hook at the
      * end of handle_button_release(). The branches below remain for the LEGACY
      * blocking dialogs (edit_prop_legacy / text_line / enter_text), which still
      * raise the semaphore. See doc/claude/code_analysis/modeless_form_M2_decision.md. */
     if(tcleval("winfo exists .dialog.f2.txt")[0] == '1') { /* proc enter_text */
       tcleval(".dialog.buttons.ok invoke");
       return;
     } else if(tcleval("winfo exists .dialog.textinput")[0] == '1') { /* proc text_line */
       tcleval(".dialog.f1.b1 invoke");
       return;
     } else if(tcleval("winfo exists .dialog.txt")[0] == '1') { /* proc enter_text */
       tcleval(".dialog.buttons.ok invoke");
       return;
     } else if(state==0 && tclgetvar("edit_symbol_prop_new_sel")[0]) {
       tcleval("set edit_symbol_prop_new_sel 1; .dialog.f1.b1 invoke"); /* invoke 'OK' of edit prop dialog */
     } else if((state & ShiftMask) && tclgetvar("edit_symbol_prop_new_sel")[0]) {
       select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
       tclsetvar("preserve_unchanged_attrs", "1");
       rebuild_selected_array();
     }
   }

   /* Handle the remaining Button1Press events */
   else if(button==Button1) /* MOD button is not pressed here. Processed above */
   {
     xctx->onetime = 0;
     xctx->mouse_moved = 0;
     xctx->drag_elements = 0;

     /* interactive net-(un)highlight mode: a click acts on the net under the cursor
      * and stays in the mode until ESC (no normal selection happens) */
     if(xctx->ui_state & (NET_HILIGHT | NET_UNHILIGHT)) {
       net_hilight_mode_click((xctx->ui_state & NET_HILIGHT) ? 1 : 0);
       return;
     }

     /* deselect-one-at-a-time mode (doc/claude/specs/deselect_one_mode.md): a click
      * deselects the object under the cursor if it is selected and stays in the mode
      * until ESC. Placed before pin-select / persistent-wire / normal-select so the
      * mode owns plain Button1 clicks; empty / unselected clicks are no-ops. */
     if(xctx->ui_state & DESEL_MODE) {
       deselect_mode_click(mx, my);
       return;
     }

     /* start another wire or line in persistent mode */
     if(!xctx->readonly && tclgetboolvar("persistent_command") && xctx->last_command) {
       if(xctx->last_command == STARTLINE)  start_line(xctx->mousex_snap, xctx->mousey_snap);
       if(xctx->last_command == STARTWIRE){
        if(tclgetboolvar("snap_cursor")
             && (xctx->prev_snapx == xctx->mousex_snap
             && xctx->prev_snapy == xctx->mousey_snap)
             && (xctx->ui_state & STARTWIRE)
             && xctx->closest_pin_found){
          new_wire(PLACE|END, xctx->mousex_snap, xctx->mousey_snap);
          xctx->ui_state &= ~STARTWIRE;
        }
        else
          start_wire(xctx->mousex_snap, xctx->mousey_snap);
      }
        return;
     }
     /* handle all object insertions started from Tools/Edit menu */
     if(check_menu_start_commands(state, c_snap, mx, my)) return;

     /* complete the pending STARTWIRE, STARTRECT, STARTZOOM, STARTCOPY ... operations */
     {
       /* issue 0113: a verb-noun / keyboard 'm' (or 'c') move started on a PRIOR event, so this
        * press is the PLACEMENT click -- end_place_move_copy_zoom() commits it here (move END).
        * Latch it so the matching RELEASE skips the cadence deselect-others (and every click-select)
        * path: with STARTMOVE already cleared and mouse_moved reset to 0 at press, that path would
        * otherwise collapse a moved multi-selection down to the single object under the cursor. */
       int had_move = (xctx->ui_state & (STARTMOVE | STARTCOPY)) ? 1 : 0;
       /* issue 0123: a placement click witness. If a preview is live but STARTMOVE is absent, this
        * press will MISS end_place_move_copy_zoom (STARTMOVE branch) and, without the guard below,
        * would be stolen by the fluid tip-grab -- the exact desync that mis-routed Add-Pin. */
       if(fluid_trace_on() &&
          ((xctx->ui_state & (PLACE_SYMBOL | PLACE_TEXT | START_SYMPIN)) || xctx->sympin_preview))
         fltrace("FLTRACE press: placement-live ui=%s sympin_preview=%d STARTMOVE=%d\n",
                 fltrace_uistate(xctx->ui_state), xctx->sympin_preview,
                 (xctx->ui_state & STARTMOVE) ? 1 : 0);
       if(end_place_move_copy_zoom()) {
         if(had_move) xctx->place_click_committed = 1;
         return;
       }
     }

     /* Button1Press to select objects.
      * issue 0123 (secondary): while a placement preview is LIVE (a symbol/pin/text/sympin drop
      * following the cursor) a plain press must NEVER be captured by the fluid tip-grab / wire-add /
      * shape-point grab in this block -- that path calls move_objects(START), starting a spurious
      * wire-stretch (and tripping the leaked-armed fluid tripwire) whenever STARTMOVE has been
      * desynced from the live placement flags. The legit drop is committed just above by
      * end_place_move_copy_zoom() (STARTMOVE set => it returns first); this guard only bites in the
      * desync window, where declining the grab is strictly safer than stealing the click. */
     if(!excl && !(xctx->ui_state & STARTSELECT) &&
        !(xctx->ui_state & (PLACE_SYMBOL | PLACE_TEXT | START_SYMPIN)) && !xctx->sympin_preview) {
       Selected sel;
       int already_selected = 0;
       int did_snapshot = 0;   /* cadence deferred-selection: pre-press selection was captured */
       int prev_last_sel = xctx->lastsel;
       int no_shift_no_ctrl = !(state & (ShiftMask | ControlMask));
       /* cadence_compat forces the intuitive interface (Cadence-style direct
        * click-drag to move/copy objects), spec doc/claude/specs/cadence_modifier_drag.md */
       int intuitive = xctx->intuitive_interface || cadence_compat;
       /* fluid_editing (C4): gates first-click tip/edge grab independently of cadence_compat.
        * Default ON as of the 0091-0096 reroute chain (dragging an INSTANCE body still needs the
        * intuitive/cadence interface; this gates the tip-grab + reroute). See
        * doc/claude/specs/fluid_editing.md. */
       int fluid_editing = tclgetboolvar("fluid_editing");

       xctx->shape_point_selected = 0;
       drag_sel_free();   /* cadence deferred-selection: wipe any leaked pre-press snapshot */
       xctx->mx_save = mx; xctx->my_save = my;
       xctx->mx_double_save=xctx->mousex;
       xctx->my_double_save=xctx->mousey;

       #if 0 /* disabled */
       /* Clicking and dragging from a **selected** instance pin will start a new wire
        * if no other elements are selected */
       if(xctx->lastsel == 1 && xctx->sel_array[0].type==ELEMENT) {
         if(add_wire_from_wire(&xctx->sel_array[0], xctx->mousex_snap, xctx->mousey_snap)) return;
         if(add_wire_from_inst(&xctx->sel_array[0], xctx->mousex_snap, xctx->mousey_snap)) return;
       }
       #endif

       /* In *NON* intuitive interface
        * a button1 press with no modifiers will first unselect everything...
        * For intuitive interface unselection see below... */
       if(!intuitive && no_shift_no_ctrl) unselect_all(1);

       /* find closest object. Use snap coordinates if full crosshair is enabled
        * since the mouse pointer is obscured and crosshair is snapped to grid points */
       if(draw_xhair && (use_cursor_for_sel || crosshair_size == 0)) {
         sel = find_closest_obj(xctx->mousex_snap, xctx->mousey_snap, 0);
       } else {
         sel = find_closest_obj(xctx->mousex, xctx->mousey, 0);
       }
       dbg(1, "sel.type=%d\n", sel.type);
       /* determine if closest object was already selected when button1 was pressed */
       switch(sel.type) {
         case WIRE:    if(xctx->wire[sel.n].sel)          already_selected = 1; break;
         case xTEXT:   if(xctx->text[sel.n].sel)          already_selected = 1; break;
         case LINE:    if(xctx->line[sel.col][sel.n].sel) already_selected = 1; break;
         case POLYGON: if(xctx->poly[sel.col][sel.n].sel) already_selected = 1; break;
         case xRECT:   if(xctx->rect[sel.col][sel.n].sel) already_selected = 1; break;
         case ARC:     if(xctx->arc[sel.col][sel.n].sel)  already_selected = 1; break;
         case ELEMENT: if(xctx->inst[sel.n].sel)          already_selected = 1; break;
         default: break;
       } /*end switch */

       /* Pin selection (en_pin_select, doc/claude/specs/pin_selection.md D3/D5): when the
        * cursor is within the tight radius of an instance pin, pick that pin. Pin
        * selection is INERT (no edit), so it works even in a READ-ONLY view -- that is
        * exactly the browse/probe use case. Two paths:
        *   - read-only: select the pin immediately (NO wire is possible; importantly do
        *     NOT call start_wire(), whose readonly_block() pops a modal dialog).
        *   - editable: ARM a wire from the pin and record it; the release handler then
        *     decides click(select pin) vs drag(draw wire). Runs BEFORE add_wire_from_inst.
        * Read the GLOBAL Tcl var, not xctx->en_pin_select: the C field is per-context and
        * gets reset to the (stale) Tcl var by housekeeping_ctx on every window/tab focus
        * change (close/open/paste), which made the feature flaky. The Tcl global is the
        * single source of truth (set by the menu, the rc, and the setter). */
       if(tclgetboolvar("en_pin_select") && !already_selected && intuitive &&
          !(state & (ShiftMask | ControlMask))) {
         Selected psel;
         /* Detect the pin from the RAW cursor position (not the snapped one): a pin
          * may not sit on the snap grid, and find_closest_pin already applies a
          * zoom-scaled radius, so the raw cursor is both more accurate and forgiving. */
         if(find_closest_pin(xctx->mousex, xctx->mousey, &psel)) {
           if(xctx->readonly) {
             /* inert select, no wire (and no readonly_block dialog) */
             unselect_all(1);
             select_pin((int)psel.n, (int)psel.col, SELECTED, 0);
             rebuild_selected_array();
             draw_selection(xctx->gc[SELLAYER], 0);
             xctx->ui_state |= SELECTION;
           } else {
             double pinx, piny;
             int prev_state = xctx->ui_state;
             get_inst_pin_coord((int)psel.n, (int)psel.col, &pinx, &piny);
             xctx->pin_pending   = 1;
             xctx->pin_pending_n = (int)psel.n;
             xctx->pin_pending_c = (int)psel.col;
             xctx->pin_press_x   = mx;   /* screen anchor for click-vs-drag at release */
             xctx->pin_press_y   = my;
             unselect_all(1);
             start_wire(pinx, piny);          /* wire emanates from the pin if dragged */
             if(prev_state == STARTWIRE) { tcleval("set constr_mv 0"); xctx->constr_mv = 0; }
           }
           return;
         }
       }

       /* Pin multi-select (pin_selection.md D6): SHIFT+click on a pin ADDS it to the
        * selection. This is a pure selection gesture -- no unselect_all, no wire arming,
        * and crucially it is intercepted BEFORE the SHIFT cadence-copy path below so the
        * underlying instance is not copied. Click-vs-drag is decided at release (like D3)
        * via pin_pending_add: click -> add the pin; drag -> ignore (pins are inert, so a
        * SHIFT+drag starting on a pin copies/moves nothing). A SHIFT press that misses
        * every pin falls through untouched, so SHIFT+drag-copy on objects is preserved.
        * Read the GLOBAL Tcl var (per-context field is reset by housekeeping_ctx). */
       if(tclgetboolvar("en_pin_select") && intuitive &&
          (state & ShiftMask) && !(state & ControlMask)) {
         Selected psel;
         if(find_closest_pin(xctx->mousex, xctx->mousey, &psel)) {
           xctx->pin_pending     = 1;
           xctx->pin_pending_add = 1;     /* additive: select on click, no wire, no copy */
           xctx->pin_pending_n   = (int)psel.n;
           xctx->pin_pending_c   = (int)psel.col;
           xctx->pin_press_x     = mx;    /* screen anchor for click-vs-drag at release */
           xctx->pin_press_y     = my;
           return;                        /* consume the press; release decides */
         }
       }

       /* Clicking and drag on an instance pin -> drag a new wire */
       if(!xctx->readonly && intuitive && !already_selected) {
         if(add_wire_from_inst(&sel, xctx->mousex_snap, xctx->mousey_snap)) return;
       }

       /* Issue 0017 (cadence fluid editing): clicking+drag on a FREE/dangling wire end
        * grabs that vertex and moves it (toward the other end = shorten, away = grow),
        * committing on release -- instead of starting a new wire (and getting stuck in
        * wire-draw mode). Plain drag only; connected ends fall through to
        * add_wire_from_wire() below (draw a new branch wire). Gated on fluid_editing (C4:
        * this is first-click tip grab of a wire end) so it toggles with the rest of fluid
        * editing; stock behavior is unchanged. Must run BEFORE add_wire_from_wire. */
       if(!xctx->readonly && fluid_editing && intuitive && !already_selected &&
          !(state & (ControlMask | ShiftMask))) {
         if(grab_free_wire_vertex(&sel, xctx->mousex_snap, xctx->mousey_snap, state)) return;
       }

       /* Clicking and drag on a wire end -> drag a new wire */
       if(!xctx->readonly && intuitive && !already_selected) {
         if(add_wire_from_wire(&sel, xctx->mousex_snap, xctx->mousey_snap)) return;
       }

       /* In intuitive interface a button1 press with no modifiers will
        *  unselect everything... we do it here */
       if(intuitive && !already_selected && no_shift_no_ctrl ) {
         /* cadence deferred-selection: snapshot the pre-press selection BEFORE clearing it, so a
          * drag of this (not-yet-selected) object can restore it at release and leave the selection
          * unchanged. Only when an object was actually hit (a drag candidate); armed at drag-start. */
         if(sel.type) { drag_sel_snapshot(); did_snapshot = 1; }
         unselect_all(1);
       }

       /* select the object under the mouse and rebuild the selected array.
        * Shift held = augment (unselect_all above was skipped) -> tell the
        * select_at funnel to log the ` add` marker so replay augments too
        * (doc/claude/specs/select_at.md). One-shot: reset right after. */
       if(!already_selected) {
         select_at_add = (state & ShiftMask) ? 1 : 0;
         select_object(xctx->mousex, xctx->mousey, SELECTED, 0, &sel);
         select_at_add = 0;
       }
       rebuild_selected_array();
       dbg(1, "Button1Press to select objects, lastsel = %d\n", xctx->lastsel);

       /* If the click landed on a grabbable control point (rect corner/edge, line/wire end,
        * arc endpoint, polygon vertex) start a first-click stretch and return -- the drag
        * then stretches that sub-part and commits on release (Motion draws the preview).
        * A body click returns 0 here and falls through to the whole-object move. The whole
        * feature (rect/line/wire/arc) is gated on fluid_editing (doc/claude/specs/
        * fluid_editing.md); polygon vertices grab regardless (legacy). */
       if(try_grab_shape_point(state, intuitive, already_selected, fluid_editing)) return;
       dbg(1, "shape_point_selected=%d, lastsel=%d\n", xctx->shape_point_selected, xctx->lastsel);

       /* intuitive interface: directly drag elements */
       if(!xctx->readonly && sel.type && intuitive && xctx->lastsel >= 1 &&
          !xctx->shape_point_selected) {
         xctx->drag_elements = 1;
         if(cadence_compat) {
           /* Cadence-style modifier-drag (spec doc/claude/specs/cadence_modifier_drag.md),
            * INDEPENDENT of enable_stretch:
            *   plain  -> attached move (wires follow)
            *   Ctrl   -> detached move (wires left behind)
            *   Shift  -> copy
            * The plain move also follows abutments and T-junctions via
            * connect_by_kissing() (wire-follow spec Phase 3): a pin that abuts
            * another pin or touches a wire mid-span gets a connecting wire so the
            * connection survives the drag. This restores what cadence_compat lost
            * when Shift+drag became copy (legacy Shift+drag set kissing). */
           if(state & ShiftMask) {
             copy_objects(START);
           } else if(state & ControlMask) {
             move_objects(START,0,0,0);
           } else {
             xctx->connect_by_kissing = 2; /* armed BEFORE select_attached_nets so a through-run
                                            * tap arm is skipped (stub replaces it); reset at move end */
             select_attached_nets(); /* nets that land on selected instance pins follow */
             move_objects(START,0,0,0);
             if(did_snapshot) xctx->drag_sel_restore = 1;  /* cadence deferred-selection: arm restore */
           }
         } else {
           /* enable_stretch (from TCL variable) reverses command if enabled:
            * - move --> stretch move
            * - stretch move (with ctrl key) --> move
            */
           int stretch = (state & ControlMask ? 1 : 0) ^ enable_stretch;
           /* select attached nets depending on ControlMask and enable_stretch */
           if(stretch && !(state & ShiftMask)) {
             /* plain stretch drag also follows abutments and T-junctions
              * (wire-follow spec Phase 3); kissing only adds wires where a pin
              * abuts a pin or touches a wire, so non-stretch (default) moves are
              * unaffected. Armed BEFORE select_attached_nets so a through-run tap arm
              * is skipped (a stub replaces it). */
             xctx->connect_by_kissing = 2; /* 2 will be used to reset var to 0 at end of move */
             select_attached_nets(); /* stretch nets that land on selected instance pins */
           }
           /* if dragging instances with stretch enabled and Shift down add wires to pins
            * attached to something */
           if((state & ShiftMask) && stretch) {
             xctx->connect_by_kissing = 2; /* 2 will be used to reset var to 0 at end of move */
             move_objects(START,0,0,0);
           }
           /* dragging away an object with Shift pressed is a copy (duplicate object) */
           else if(state & ShiftMask) copy_objects(START);
           /* else it is a normal move */
           else {
             move_objects(START,0,0,0);
             if(did_snapshot) xctx->drag_sel_restore = 1;  /* cadence deferred-selection: arm restore */
           }
         }
       }

       if(tclgetboolvar("auto_hilight") && !xctx->shape_point_selected) {
         if(!(state & ShiftMask) && xctx->hilight_nets && sel.type == 0 ) {
           if(!prev_last_sel) {
             redraw_hilights(1); /* 1: clear all hilights, then draw */
           }
         }
         hilight_net(0);
         if(xctx->lastsel) {
           redraw_hilights(0);
         }
       }
       return;
     } /* if(!excl) */
   } /* button==Button1 */

   return;
}

static void handle_button_release(int event, KeySym key, int state, int button, int mx, int my,
                                  int aux, double c_snap, int enable_stretch, int draw_xhair,
                                  int cadence_compat, int snap_cursor, int wire_draw_active)
{
   char str[PATH_MAX + 100];
   /* cadence_compat forces the intuitive interface (matches handle_button_press),
    * spec doc/claude/specs/cadence_modifier_drag.md */
   int intuitive = xctx->intuitive_interface || cadence_compat;
   /* issue 0113: consume the "placement press committed a move/copy" latch exactly once, at the
    * TOP of the release so it is cleared on EVERY exit path -- BEFORE the waves_selected early
    * return below (a placement dropped over a waveform graph routes there; the press cleared
    * STARTMOVE so waves_selected, skipped on the press, now fires -- review wf_fdd928d4). When set,
    * this release ends a verb-noun / keyboard 'm' placement whose move already committed on the
    * matching PRESS; force mouse_moved=1 so the cadence deselect-others path (guarded !mouse_moved)
    * is suppressed and does not collapse the moved multi-selection. Cleared unconditionally so it
    * can never leak to a later, unrelated click. */
   {
     int placed_committed = xctx->place_click_committed;
     xctx->place_click_committed = 0;
     if(placed_committed) xctx->mouse_moved = 1; /* mark as a completed gesture, not a bare click */
   }
   /* End any double-click connected-select escalation on a button-1 release that is NOT the
    * release of a double-click: snapshot the level (so a real double's following `-3` can
    * restore it) and tentatively zero it. A standalone single click's zero is never restored
    * and so sticks -> the next double-click on the seed restarts at ring1. The double's own
    * release2 is skipped (its preceding press was the `-3` grow, which set the flag).
    * doc/claude/specs/dblclick_connected_select.md. */
   if(button == Button1 && !xctx->dblgrow_last_press_was_grow) {
     xctx->dblgrow_level_save = xctx->dblgrow_level;
     xctx->dblgrow_level = 0;
   }
   if(waves_selected(event, key, state, button)) {
     waves_callback(event, mx, my, key, button, aux, state);
     return;
   }
   dbg(1, "release: shape_point_selected=%d\n", xctx->shape_point_selected);

   /* Pin-selection gesture (pin_selection.md D3): a press on a pin armed a wire from
    * that pin and recorded the pin. Decide click vs drag now by how far the pointer
    * travelled from the press anchor (mouse_moved is NOT set while STARTWIRE is
    * active, so it cannot be used here):
    *   no drag -> it was a click: abort the armed wire and select the pin.
    *   drag    -> the user wants a wire: leave STARTWIRE active (wire-drawing mode,
    *              rubber follows the cursor) and consume the release without placing,
    *              so a plain click is the ONLY way to select and any movement means
    *              "draw a wire". */
   if(xctx->pin_pending) {
     int pn = xctx->pin_pending_n, pc = xctx->pin_pending_c;
     int add = xctx->pin_pending_add;
     int moved = (abs(mx - xctx->pin_press_x) > (int)(tk_scaling * 3) ||
                  abs(my - xctx->pin_press_y) > (int)(tk_scaling * 3));
     xctx->pin_pending = 0;
     xctx->pin_pending_add = 0;
     if(add) {
       /* D6 SHIFT+pin: click -> ADD the pin (additive, NO unselect_all, no wire armed);
        * drag -> ignore (pins are inert; nothing was armed at press, so just return). */
       if(!moved) {
         select_pin(pn, pc, SELECTED, 0);
         rebuild_selected_array();
         draw_selection(xctx->gc[SELLAYER], 0);
         xctx->ui_state |= SELECTION;
       }
       return;
     }
     if(!moved) {
       if(xctx->ui_state & STARTWIRE) {
         new_wire(RUBBER | CLEAR, xctx->mousex_snap, xctx->mousey_snap);
         xctx->ui_state &= ~STARTWIRE;
         xctx->last_command = 0;
       }
       unselect_all(1);
       select_pin(pn, pc, SELECTED, 0);
       rebuild_selected_array();
       draw_selection(xctx->gc[SELLAYER], 0);
       xctx->ui_state |= SELECTION;
       return; /* click: pin selected, done */
     }
     /* drag: leave STARTWIRE armed and FALL THROUGH to the normal release handling so
      * the legacy wire-commit still runs -- end_place_move_copy_zoom() at the
      * STARTWIRE branch below (intuitive && !persistent_command) places the wire on
      * release; with persistent_command on (or cadence's deselect branch) STARTWIRE
      * stays active and the wire keeps drawing, as before. */
   }

   /* bring up context menu if no pending operation */
   if(state == Button3Mask && xctx->semaphore <2) {
     if(!end_place_move_copy_zoom()) {
       context_menu_action(xctx->mousex_snap, xctx->mousey_snap);
     }
   }
   /* Phase 3b: a zoom gesture remapped onto a non-Button3 chord must complete on
    * that button's release too (rubber-band/END are ui_state-driven; only the
    * start chord and the context-menu branch above were Button3-specific, and the
    * context menu stays Button3-only). With default bindings STARTZOOM is never
    * pending on a non-Button3 release, so this is inert unless the user rebinds. */
   else if((xctx->ui_state & STARTZOOM) && xctx->semaphore < 2) {
     end_place_move_copy_zoom();
   }

   /* A plain intuitive press starts a move and may run connect_by_kissing(),
    * which inserts zero-length stub wires at kissed pins (to be stretched by the
    * drag). If the gesture ends with NO motion it is just a select click: abort
    * the move here -- BEFORE the cadence deselect-others test below reads
    * xctx->lastsel -- so the kiss stub neither inflates the selection (spuriously
    * triggering the deselect branch) nor survives as a degenerate wire.
    * move_objects(ABORT) sweeps the stub via check_collapsing_objects().
    * Shift(copy)/Ctrl(detached or launcher) have their own branches, so exclude
    * them; gestures WITH motion complete normally further down. */
   if(intuitive && (xctx->ui_state & STARTMOVE) && xctx->drag_elements &&
      !xctx->mouse_moved && !(state & (ShiftMask | ControlMask))) {
     move_objects(ABORT, 0, 0.0, 0.0);
     xctx->drag_elements = 0;
     /* This is a plain CLICK (no drag) whose press armed a move + a cadence deferred-selection
      * restore (drag_sel_restore, spec doc/claude/specs/cadence_modifier_drag.md §5b). A click
      * keeps its click-select and must NOT restore the pre-press selection, so free the snapshot
      * (mirrors end_move_copy_logged's no-motion `nothing` path). This ABORT bypasses
      * end_move_copy_logged, so without freeing here the flag LEAKS past this gesture: a later
      * keyboard 'm'/'c' move has no press-select to clear it (drag_sel_free at the press-select
      * head), consumes the leak at its END, and deselects the just-moved object. */
     drag_sel_free();
     /* When a kiss happened, ABORT's pop_undo cleared the selection; a click must
      * leave the clicked object selected, so re-select what is under the cursor.
      * When nothing was kissed the selection is intact, so leave it untouched
      * (preserves the normal click / multi-select-then-isolate behavior). */
     if(xctx->lastsel == 0) {
       select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
       rebuild_selected_array();
     }
   }

   /* launcher, no intuitive interface */
   if(!intuitive && state == (Button1Mask | ControlMask) &&
      !xctx->shape_point_selected && xctx->mouse_moved == 0) {
     int savesem = xctx->semaphore;
     xctx->semaphore = 0;
     launcher(); /* works only if lastsel == 1 */
     xctx->semaphore = savesem;
   }

   /* launcher, intuitive_interface, only if no movement has been done */
   else if(intuitive && state == (Button1Mask | ControlMask) &&
      !xctx->shape_point_selected && (xctx->ui_state & STARTMOVE) && xctx->mouse_moved == 0) {
     int savesem = xctx->semaphore;
     move_objects(ABORT, 0, 0.0, 0.0);
     unselect_all(1);
     xctx->drag_elements = 0; /* after ctrl-Button1Press on a launcher need to clear this */
     select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
     rebuild_selected_array();
     xctx->semaphore = 0;
     launcher(); /* works only if lastsel == 1 */
     xctx->semaphore = savesem;
   }

   /* in cadence_compat mode a button release on a selected item will unselect everything
    * but the item under the mouse. NOT while a move/copy is in flight: a verb-noun 'm'
    * pickup starts a connected move whose selection includes the grabbed attached nets
    * (lastsel > 1), and this collapse would drop them mid-gesture.
    * see doc/claude/specs/cadence_stretch_move_keys.md */
   else if(cadence_compat && xctx->lastsel != 1 && state == Button1Mask && !xctx->mouse_moved &&
           !(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
     Selected sel;
     int already_selected = 0;

     sel = find_closest_obj(xctx->mousex_snap, xctx->mousey_snap, 0);
     switch(sel.type) {
       case WIRE:    if(xctx->wire[sel.n].sel)          already_selected = 1; break;
       case xTEXT:   if(xctx->text[sel.n].sel)          already_selected = 1; break;
       case LINE:    if(xctx->line[sel.col][sel.n].sel) already_selected = 1; break;
       case POLYGON: if(xctx->poly[sel.col][sel.n].sel) already_selected = 1; break;
       case xRECT:   if(xctx->rect[sel.col][sel.n].sel) already_selected = 1; break;
       case ARC:     if(xctx->arc[sel.col][sel.n].sel)  already_selected = 1; break;
       case ELEMENT: if(xctx->inst[sel.n].sel)          already_selected = 1; break;
       default: break;
     } /*end switch */

     if(already_selected) {
       unselect_all(1);
       select_object(xctx->mousex, xctx->mousey, SELECTED, 0, &sel);
     }
   }

   /* end wire creation when dragging in intuitive interface from an inst pin or wire endpoint */
   else if(state == Button1Mask && intuitive && !tclgetboolvar("persistent_command")
        && (xctx->ui_state & STARTWIRE) && !(xctx->ui_state & MENUSTART)) {
     if(end_place_move_copy_zoom()) return;
   }

   /* end intuitive_interface copy or move */
   if(xctx->ui_state & STARTCOPY && xctx->drag_elements) {
      end_move_copy_logged(1);
      xctx->constr_mv=0;
      tcleval("set constr_mv 0" );
      xctx->drag_elements = 0;
   }
   else if(xctx->ui_state & STARTMOVE && xctx->drag_elements) {
      /* motion was below 5 screen units so no motion was set, abort */
      if(!(state & ShiftMask) && !xctx->mouse_moved) {
        move_objects(ABORT,0,0,0);
      } else {
        end_move_copy_logged(0);
      }
      xctx->constr_mv=0;
      tcleval("set constr_mv 0" );
      xctx->drag_elements = 0;
   }

   /* if a polygon/bezier/rectangle control point was clicked, end point move operation
    * and set polygon state back to SELECTED from SELECTED1 */
   else if((xctx->ui_state & (STARTMOVE | SELECTION)) && xctx->shape_point_selected) {
     end_shape_point_edit();
   }

   if(xctx->ui_state & STARTPAN) {
     xctx->ui_state &=~STARTPAN;
     log_pan_end();
     /* xctx->mx_save = mx; xctx->my_save = my; */
     /* xctx->mx_double_save=xctx->mousex_snap; */
     /* xctx->my_double_save=xctx->mousey_snap; */
     redraw_w_a_l_r_p_z_rubbers(1);
     return;
   }
   dbg(1, "callback(): ButtonRelease  ui_state=%d state=%d\n",xctx->ui_state,state);
   if(xctx->semaphore >= 2) return;
   if(xctx->ui_state & STARTSELECT) {
     if(state & ControlMask) {
       select_rect(!enable_stretch, END,-1);
     } else {
       /* Button1 release: end of rectangle select */
       if(!(state & (Button4Mask|Button5Mask) ) ) {
         select_rect(enable_stretch, END,-1);
       }
     }
     xctx->ui_state &= ~DESEL_AREA;
     rebuild_selected_array();
     my_snprintf(str, S(str), "mouse = %.16g %.16g - selected: %d path: %s",
       xctx->mousex_snap, xctx->mousey_snap, xctx->lastsel, xctx->sch_path[xctx->currsch] );
     statusmsg(str,1);   /* held messages survive this -- the hold lives in statusmsg() (0248) */
   }

   /* clear start from menu flag or infix_interface=0 start commands */
   if( state == Button1Mask && xctx->ui_state & MENUSTART) {
     xctx->ui_state &= ~MENUSTART;
     return;
   }
   if(draw_xhair) draw_crosshair(3, state); /* restore crosshair when selecting / unselecting */
   if(snap_cursor && ((state == ShiftMask) || wire_draw_active)) draw_snap_cursor(3); /* erase & redraw */
   /* M2 (issue 0009): a live canvas selection change re-targets the open modeless
    * property form. This is M1's on_selection_changed hook, relocated off the old
    * semaphore>=2 carve-out (the form no longer locks the dispatcher) onto the
    * normal selection-completion path. Fires at button release — after any
    * click-select / rubber-band / move gesture has settled — and on_selection_changed
    * itself no-ops if the selection set did not actually change. */
   if(tclgetboolvar("slickprop_form_open")) tcleval("slickprop::on_selection_changed");
   return;
}

static void handle_double_click(int event, int state, KeySym key, int button,
                                int mx, int my, int aux, int cadence_compat)
{
    if( waves_selected(event, key, state, button)) {
      waves_callback(event, mx, my, key, button, aux, state);
      return;
    } else {
     if(xctx->semaphore >= 2) return;
     dbg(1, "callback(): DoubleClick  ui_state=%d state=%d\n",xctx->ui_state,state);
     if(button==Button1) {
       Selected sel;
       /* Cadence double-click incremental connected-select
        * (doc/claude/specs/dblclick_connected_select.md): under cadence_compat a
        * LMB double-click grows the selection outward along wire connectivity, one
        * ring per double-click (Edit Properties is reached via 'q' instead).
        *
        * With the cadence profile (fluid_editing + en_pin_select) the 2nd press of
        * the double-click ALWAYS arms a TRANSIENT press-gesture before -3 fires: a
        * fluid move-grab (STARTMOVE) on a wire/instance body, or a pin wire-arm
        * (STARTWIRE + pin_pending) on an instance pin. So ui_state at -3 is almost
        * never a bare 0/SELECTION. Detect those transient arms and abort_operation()
        * them first -- that also pops the move's undo, restoring the pre-press
        * selection (which, on a 2nd/3rd double-click, IS the previously-grown set,
        * so escalation survives). Then grow, and latch place_click_committed so the
        * matching release2 does NOT collapse the grown multi-selection down to the
        * object under the cursor (same latch issue 0113 uses). A genuine multi-point
        * draw (STARTLINE/STARTPOLYGON, or a real STARTWIRE draw without pin_pending)
        * is NOT transient and falls through to the termination code below. */
       {
         int transient_pin  = (xctx->ui_state & STARTWIRE) && xctx->pin_pending;
         int transient_move = (xctx->ui_state & (STARTMOVE | STARTCOPY)) && !xctx->mouse_moved;
         if(cadence_compat && (xctx->ui_state == 0 || xctx->ui_state == SELECTION ||
                               transient_pin || transient_move)) {
           if(transient_pin || transient_move) {
             abort_operation(1);
             xctx->drag_elements = 0;
           }
           /* This -3 confirms the preceding press/release was the first half of a double,
            * NOT a standalone click: undo the release's tentative escalation-reset before
            * growing, and flag so the double's own release2 does not re-trigger the reset
            * (dblclick_connected_select.md). */
           xctx->dblgrow_level = xctx->dblgrow_level_save;
           xctx->dblgrow_last_press_was_grow = 1;
           select_grow_connected_step(xctx->mousex, xctx->mousey, 1);
           xctx->place_click_committed = 1; /* release2: suppress cadence deselect-others */
           return;
         }
       }
       if(!xctx->lastsel && xctx->ui_state ==  0) {
         /* Following 5 lines do again a selection overriding lock,
          * so locked instance attrs can be edited */
         sel = select_object(xctx->mousex, xctx->mousey, SELECTED, 1, NULL);
         if(sel.type) {
           xctx->ui_state = SELECTION;
           rebuild_selected_array();
         }
       }
       if(xctx->ui_state ==  0 || xctx->ui_state == SELECTION) {
         edit_property(0);
       } else {
         if(xctx->ui_state & STARTWIRE) {
           if( cadence_compat ) {
             redraw_w_a_l_r_p_z_rubbers(1);
             start_wire(mx, my);
           }
           xctx->ui_state &= ~STARTWIRE;
         }
         if(xctx->ui_state & STARTLINE) {
           xctx->ui_state &= ~STARTLINE;
         }
         if( (xctx->ui_state & STARTPOLYGON) && (state ==0 ) ) {
           new_polygon(SET, xctx->mousex_snap, xctx->mousey_snap);
         }
       }
     }
    }
}


static void update_statusbar(int persistent_command, int wire_draw_active)
{
  #ifndef __unix__
  short cstate = GetKeyState(VK_CAPITAL);
  short nstate = GetKeyState(VK_NUMLOCK);
  #else
  XKeyboardState kbdstate;
  #endif

  int line_draw_active = (xctx->ui_state & STARTLINE) ||
                         ((xctx->ui_state2 & MENUSTARTLINE) && (xctx->ui_state & MENUSTART)) ||
                         (persistent_command && (xctx->last_command & STARTLINE));
  int poly_draw_active = (xctx->ui_state & STARTPOLYGON) ||
                         ((xctx->ui_state2 & MENUSTARTPOLYGON) && (xctx->ui_state & MENUSTART)) ||
                         (persistent_command && (xctx->last_command & STARTPOLYGON));
  int arc_draw_active =  (xctx->ui_state & STARTARC) ||
                         ((xctx->ui_state2 & MENUSTARTARC) && (xctx->ui_state & MENUSTART)) ||
                         (persistent_command && (xctx->last_command & STARTARC));
  int rect_draw_active =  (xctx->ui_state & STARTRECT) ||
                         ((xctx->ui_state2 & MENUSTARTRECT) && (xctx->ui_state & MENUSTART)) ||
                         (persistent_command && (xctx->last_command & STARTRECT));

  #ifndef __unix__
  if(cstate & 0x0001) { /* caps lock */
    tclvareval(xctx->top_path, ".statusbar.8 configure -state active -text {CAPS LOCK SET! }", NULL);
  } else if (nstate & 0x0001) { /* num lock */
    tclvareval(xctx->top_path, ".statusbar.8 configure -state active -text {NUM LOCK SET! }", NULL);
  } else { /* normal state */
    tclvareval(xctx->top_path, ".statusbar.8 configure -state  normal -text {}", NULL);
  }
  #else
  XGetKeyboardControl(display, &kbdstate);
  if(kbdstate.led_mask & 1) { /* caps lock */
    tclvareval(xctx->top_path, ".statusbar.8 configure -state active -text {CAPS LOCK SET! }", NULL);
  } else if(kbdstate.led_mask & 2) { /* num lock */
    tclvareval(xctx->top_path, ".statusbar.8 configure -state active -text {NUM LOCK SET! }", NULL);
  } else { /* normal state */
    tclvareval(xctx->top_path, ".statusbar.8 configure -state  normal -text {}", NULL);
  }
  #endif

  if(wire_draw_active) {
     tclvareval(xctx->top_path, ".statusbar.10 configure -state active -text {DRAW WIRE! }", NULL);
  } else if(line_draw_active) {
     tclvareval(xctx->top_path, ".statusbar.10 configure -state active -text {DRAW LINE! }", NULL);
  } else if(poly_draw_active) {
     tclvareval(xctx->top_path, ".statusbar.10 configure -state active -text {DRAW POLYGON! }", NULL);
  } else if(arc_draw_active) {
     tclvareval(xctx->top_path, ".statusbar.10 configure -state active -text {DRAW ARC! }", NULL);
  } else if(rect_draw_active) {
     tclvareval(xctx->top_path, ".statusbar.10 configure -state active -text {DRAW RECTANGLE! }", NULL);
  } else if(xctx->ui_state & NET_HILIGHT) {
     tclvareval(xctx->top_path, ".statusbar.10 configure -state active -text {HIGHLIGHT NET! (click a net or label, ESC to end) }", NULL);
  } else if(xctx->ui_state & NET_UNHILIGHT) {
     tclvareval(xctx->top_path, ".statusbar.10 configure -state active -text {UNHIGHLIGHT NET! (click a net or label, ESC to end) }", NULL);
  } else {
     tclvareval(xctx->top_path, ".statusbar.10 configure -state normal -text { }", NULL);
  }

  tclvareval(xctx->top_path, ".statusbar.7 configure -text $netlist_type", NULL);
  tclvareval(xctx->top_path, ".statusbar.3 delete 0 end;",
                      xctx->top_path, ".statusbar.3 insert 0 $cadsnap", NULL);
  tclvareval(xctx->top_path, ".statusbar.5 delete 0 end;",
                      xctx->top_path, ".statusbar.5 insert 0 $cadgrid", NULL);
}

static void handle_expose(int mx,int my,int button,int aux)
{
  XRectangle xr[1];
  MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0], mx,my,button,aux,mx,my);
  xr[0].x=(short)mx;
  xr[0].y=(short)my;
  xr[0].width=(unsigned short)button;
  xr[0].height=(unsigned short)aux;
  /* redraw selection on expose, needed if no backing store available on the server 20171112 */
  XSetClipRectangles(display, xctx->gc[SELLAYER], 0,0, xr, 1, Unsorted);
  rebuild_selected_array();
  if(tclgetboolvar("compare_sch") /* && xctx->sch_to_compare[0] */){
    compare_schematics("");
  } else {
    draw_selection(xctx->gc[SELLAYER],0);
  }
  XSetClipMask(display, xctx->gc[SELLAYER], None);
}

static int handle_window_switching(int event, int tabbed_interface, const char *win_path,
                                   char *restore_win)
{
  int redraw_only = 0;
  int n = get_tab_or_window_number(win_path);
  Xschem_ctx **save_xctx = get_save_xctx();
  /* A real top-level window (non-empty top_path) owns its own X canvas, so focus/
   * expose/enter must switch xctx to it — even in tabbed mode, where windows and
   * tabs now coexist (doc/claude/specs/multi_window_detach.md). Pure tabs share the main
   * canvas and switch via the tab bar, so they stay out of this path. The switch
   * runs when either the event window OR the current context is a real window. */
  int win_is_real = (n > 0 && save_xctx[n] && save_xctx[n]->top_path && save_xctx[n]->top_path[0]);
  int cur_is_real = (xctx->top_path && xctx->top_path[0]);
  if(!tabbed_interface || win_is_real || cur_is_real) {
    if((event == FocusIn  || event == Expose || event == EnterNotify) &&
       strcmp(xctx->current_win_path, win_path) ) {
      struct stat buf;

      if(xctx->pending_fullzoom == 1) return 0; /* no switching if opening a new window */
      dbg(1, "handle_window_switching(): event=%d, ui_state=%d win_path=%s\n",
          event, xctx->ui_state, win_path);
      /* This will switch context only when copying stuff across windows
       * this is the window *receiving* copied objects */
      tcleval("destroy .ctxmenu");
      if( event == EnterNotify && !stat(sel_file, &buf) && (xctx->ui_state & STARTCOPY)) {
        dbg(1, "callback(): switching window context for copy : %s --> %s, semaphore=%d\n",
                xctx->current_win_path, win_path, xctx->semaphore);
        new_schematic("switch", win_path, "", 1);
      /* switch context to window *sending* copied objects, when returning back in.
       * Guard the slot: get_tab_or_window_number() returns -1 for an unknown win_path
       * (e.g. a stale EnterNotify during teardown), and the widened entry condition
       * (cur_is_real) now admits this branch in tabbed mode too, so save_xctx[n] must
       * be range/NULL checked before the deref (issue 0021). */
      } else if( event == EnterNotify && n >= 0 && save_xctx[n] &&
                 /* stat(sel_file, &buf) && */ (save_xctx[n]->ui_state & STARTCOPY)) {
        dbg(1, "callback(): switching window context for copy : %s --> %s, semaphore=%d\n",
                xctx->current_win_path, win_path, xctx->semaphore);
        redraw_only = 1;
        my_strncpy(restore_win, xctx->current_win_path, PATH_MAX);
        new_schematic("switch_no_tcl_ctx", win_path, "", 1);
      /* This does a "temporary" switch just to redraw obscured window parts */
      } else if(event == Expose || xctx->semaphore >= 1 ) {
        dbg(1, "callback(): switching window context for redraw ONLY: %s --> %s\n",
                xctx->current_win_path, win_path);
        redraw_only = 1;
        my_strncpy(restore_win, xctx->current_win_path, PATH_MAX);
        new_schematic("switch_no_tcl_ctx", win_path, "", 1);
      /* The regular context switch. mouse_follows_focus selects the SOURCE OF TRUTH for
       * which window is active, and only one source drives it so the two can't fight:
       *  - ON  (default): the POINTER. Switch on EnterNotify (pointer crossing) and sync
       *    the Tk keyboard focus to it. A FocusIn is IGNORED here -- otherwise the WM
       *    re-asserting focus on the previously-active window (e.g. during a Ctrl+wheel
       *    zoom redraw) would bounce the context off the window the pointer is over.
       *  - OFF: the WM FOCUS. Switch on FocusIn only (click to activate), as before.
       * Idle only (semaphore==0): never steal context mid-gesture. */
      } else if(((event == EnterNotify && tclgetboolvar("mouse_follows_focus")) ||
                 (event == FocusIn && !tclgetboolvar("mouse_follows_focus"))) &&
                xctx->semaphore == 0) {
        dbg(1, "callback(): switching window context: %s --> %s, semaphore=%d\n",
                xctx->current_win_path, win_path, xctx->semaphore);
        new_schematic("switch", win_path, "", 1);
        if(event == EnterNotify) tclvareval("focus ", win_path, NULL);
        dbg(1, "switching to %s\n", win_path);
      }

    }
  } else {
    /* if something needs to be done in tabbed interface do it here */
  }
  return redraw_only;
}

/* main window callback */
/* mx and my are set to the mouse coord. relative to window  */
/* win_path: set to .drw or sub windows .x1.drw, .x2.drw, ...  */
int callback(const char *win_path, int event, int mx, int my, KeySym key, int button, int aux, int state)
{
  char str[PATH_MAX + 100];
  int redraw_only;
  /* Window to switch BACK to after a redraw-only (temporary) context borrow. Kept call-
   * LOCAL (not the shared global old_win_path) so a nested cross-window redraw -- e.g. a
   * zoom that exposes another window and reenters callback() -- cannot overwrite this
   * call's restore target and strand the context on the wrong window (Ctrl+wheel bug). */
  char restore_win[PATH_MAX];
  double c_snap;
  int tabbed_interface = tclgetboolvar("tabbed_interface");
  int enable_stretch = tclgetboolvar("enable_stretch");
  /* ⚠ THESE TWO ARE NOT WHERE THE issue-0177 no_snap TEST GOES, and the first cut
   * of that fix put it here, wrongly. They are initialisers, so they run BEFORE
   * handle_window_switching() below may reassign xctx -- on the EnterNotify that
   * switches into or out of a waveform viewer they would describe the PREVIOUS
   * context. And they do not reach draw()'s own crosshair call (draw.c ~8433) or
   * move.c's three, so gating them would kill the erase paths and leave the paint
   * paths live. The property is tested inside draw_crosshair()/draw_snap_cursor()
   * instead, at call time. What these locals still legitimately decide is the
   * CURSOR SHAPE, and that decision does consult no_snap where it is made. */
  int draw_xhair = tclgetboolvar("draw_crosshair");
  int crosshair_size = tclgetintvar("crosshair_size");
  int infix_interface = tclgetboolvar("infix_interface");
  int rstate; /* (reduced state, without ShiftMask) */
  int snap_cursor = tclgetboolvar("snap_cursor");
  int cadence_compat = tclgetboolvar("cadence_compat");
  int persistent_command = tclgetboolvar("persistent_command");
  int wire_draw_active = (xctx->ui_state & STARTWIRE) ||
                         ((xctx->ui_state2 & MENUSTARTWIRE) && (xctx->ui_state & MENUSTART)) ||
                         (persistent_command && (xctx->last_command & STARTWIRE));
  struct stat buf;

  /* this fix uses an alternative method for getting mouse coordinates on KeyPress/KeyRelease
   * events. Some remote connection softwares do not generate the correct coordinates
   * on such events */
  if(fix_mouse_coord) {
    if(event == KeyPress || event == KeyRelease) {
      tclvareval("getmousex ", win_path, NULL);
      mx = atoi(tclresult());
      tclvareval("getmousey ", win_path, NULL);
      my = atoi(tclresult());
      dbg(1, "mx = %d  my=%d\n", mx, my);
    }
  }

  /* issue 0242 tripwire -- see check_placement_preview_invariant(). Sited at the top of the GUI
   * event entry and of xschem() (scheduler.c), the two funnels every actor passes through, so a
   * door reached by a keystroke, a click, a menu or a script is caught wherever it lives. */
  check_placement_preview_invariant("callback()");

  update_statusbar(persistent_command, wire_draw_active);

  #if 0
  /* exclude Motion and Expose events */
  if(event!=6 /* && event!=12 */) {
    dbg(0, "callback(): state=%d event=%d, win_path=%s, current_win_path=%s, old_win_path=%s, semaphore=%d\n",
            state, event, win_path, xctx->current_win_path, old_win_path, xctx->semaphore+1);
  }
  #endif

  /* Schematic window context switch */
  restore_win[0] = '\0';
  redraw_only = handle_window_switching(event, tabbed_interface, win_path, restore_win);

  /* artificially set semaphore to allow only redraw operations in switched schematic,
   * so we don't need  to switch tcl context which is costly performance-wise
   */
  if(redraw_only) {
    dbg(1, "callback(): incrementing semaphore for redraw_only\n");
    xctx->semaphore++;
  }

  xctx->semaphore++; /* to recognize recursive callback() calls */


  /* file exists and modification time on disk has changed since file loaded ... */
  /* ... but NOT for a read-only window: set_modify(1) means "has unsaved local edits",
   * which a read-only (browse) view can never have, so flagging it modified is wrong --
   * it spuriously shows the '*' marker and prompts to save on close (issue 0035, seen
   * on a freshly descended read-only window on the first mouse event). External on-disk
   * changes for a read-only file are surfaced by the reload mechanism, not set_modify. */
  if(!xctx->readonly && !xctx->modified && !stat( xctx->sch[xctx->currsch], &buf) &&
     xctx->time_last_modify && xctx->time_last_modify != buf.st_mtime) {
     set_modify(1);
  }

  c_snap = tclgetdoublevar("cadsnap");
  #ifdef __unix__
  state &= (1 <<13) -1; /* filter out anything above bit 12 (4096) */
  #endif
  state &= ~Mod2Mask; /* 20170511 filter out NumLock status */
  state &= ~LockMask; /* filter out Caps Lock */
  rstate = state; /* rstate does not have ShiftMask bit, so easier to test for KeyPress events */
  rstate &= ~ShiftMask; /* don't use ShiftMask, identifying characters is sufficient */
  rstate &= ~Button1Mask; /* ignore button-1 */
  if(xctx->semaphore >= 2)
  {
    if(debug_var>=2)
      if(event != MotionNotify)
        fprintf(errfp, "callback(): reentrant call of callback(), semaphore=%d, ev=%d, ui_state=%d\n",
                xctx->semaphore, event, xctx->ui_state);
  }
  xctx->mousex=X_TO_XSCHEM(mx);
  xctx->mousey=Y_TO_XSCHEM(my);
  /* THE SNAP GRID IS A PROPERTY OF THE CANVAS, AND IT IS DECIDED HERE (issue 0177).
   *
   * These four lines run for every event on every window, so this is the ONE place
   * where "this surface has no schematic snap grid" can be expressed once and cover
   * every downstream reader -- present and future. Issue 0143 instead overrode the
   * two fields locally at the head of waves_callback(), which was correct but only
   * for code reached THROUGH that handler: anything that runs when waves_selected()
   * DECLINES the event still saw a grid-snapped schematic coordinate. On the ASE
   * viewer that was measurable and visible -- see the 0177 issue file for the
   * numbers -- because waves_selected() refuses a band just inside the strip rect
   * that contains the top of the LEGEND, and in that band handle_motion_notify()
   * falls through to the schematic arm and draws the crosshair AT mousex_snap.
   *
   * On a no_snap canvas the two "_snap" fields are simply honest copies of the raw
   * pointer. Every reader keeps working; none of them gets a grid. waves_callback's
   * own override stays, because an ordinary SCHEMATIC window can embed graphs and
   * that context is not no_snap. */
  if(xctx->no_snap) {
    xctx->mousex_snap=xctx->mousex;
    xctx->mousey_snap=xctx->mousey;
  } else {
    xctx->mousex_snap=my_round(xctx->mousex / c_snap) * c_snap;
    xctx->mousey_snap=my_round(xctx->mousey / c_snap) * c_snap;
  }

  /* The readout that reaches furthest (issue 0248): it runs for EVERY event -- motion, key press,
   * enter/leave -- so a gate message died on the next keystroke even if the pointer never moved
   * again (mx_save is only refreshed on a press, so the 8-pixel test stays true once the hand has
   * moved). Held messages survive it via statusmsg() itself. */
  if(abs(mx-xctx->mx_save) > 8 || abs(my-xctx->my_save) > 8 ) {
    my_snprintf(str, S(str), "mouse = %.16g %.16g - selected: %d path: %s",
      xctx->mousex_snap, xctx->mousey_snap, xctx->lastsel, xctx->sch_path[xctx->currsch] );
    statusmsg(str,1);
  }
  /* A click is the user acting on what they just read, so the held message is released here and
   * the coordinate readout resumes on the very next motion -- which is what keeps the live w=/h=
   * size feedback during a move/copy/stretch (issue 0248 landmine 1). Placed AFTER the readout
   * above so the press event itself still shows the message. */
  if(event == ButtonPress) statusmsg_hold_clear();

  dbg(2, "key=%d EQUAL_MODMASK=%d, SET_MODMASK=%d\n", key, SET_MODMASK, EQUAL_MODMASK);

  #if defined(__unix__) && HAS_CAIRO==1
  if(xctx->ui_state & GRABSCREEN) {
    grabscreen(win_path, event, mx, my, key, button, aux, state);
  } else
  #endif
  switch(event)
  {

   case LeaveNotify:
     if(draw_xhair) draw_crosshair(1, state); /* clear crosshair when exiting window */
     if(snap_cursor) draw_snap_cursor(1); /* erase */
     tclvareval(xctx->top_path, ".drw configure -cursor {}" , NULL);
     xctx->mouse_inside = 0;
     draw_hover(0); /* erase the hover outline when the pointer leaves the canvas */
     draw_flylines(0); /* drop the fly-line overlay state on leave (mouse_inside==0) */
     graph_snap_clear(); /* item 9: and the graph snap diamond */
     break;

   case EnterNotify:
     handle_enter_notify(draw_xhair, crosshair_size);
     break;

   case Expose:
     handle_expose(mx,my,button,aux);
     break;

   case ConfigureNotify:
     dbg(1,"callback(): ConfigureNotify event: %s %dx%d\n", win_path, button, aux);
     resetwin(1, 1, 0, 0, 0);
     draw();
     break;

   case MotionNotify:
     handle_motion_notify(event, key, state, rstate, button, mx, my,
                          aux, draw_xhair, enable_stretch, tabbed_interface, win_path,
                          snap_cursor, wire_draw_active);
     break;

   case KeyRelease:
     /* force clear (even if mouse pos not changed) */
     /* if(snap_cursor && (key == XK_Shift_L || key == XK_Shift_R) ) draw_snap_cursor(5); */
     break;

   case KeyPress:
     handle_key_press(event, key, state, rstate, mx, my, button, aux,
                      infix_interface, enable_stretch, win_path, c_snap,
                      cadence_compat, wire_draw_active, snap_cursor);
     break;

   case ButtonPress:
     handle_button_press(event, state, rstate, key, button, mx, my,
                         c_snap, draw_xhair, crosshair_size, enable_stretch, cadence_compat,
                         tabbed_interface, win_path, aux);
     break;

   case ButtonRelease:
     handle_button_release(event, key, state, button, mx, my, aux, c_snap, enable_stretch,
                           draw_xhair, cadence_compat, snap_cursor, wire_draw_active);
     break;

   case -3:  /* double click  : edit prop */
     handle_double_click(event, state, key, button, mx, my, aux, cadence_compat);
     break;

   default:
    dbg(1, "callback(): Event:%d\n",event);
    break;
  } /* switch(event) */

  if(xctx->semaphore > 0) xctx->semaphore--;
  if(redraw_only) {
    xctx->semaphore--; /* decrement articially incremented semaphore (see above) */
    dbg(1, "callback(): semaphore >=2 restoring window context: %s <-- %s\n", restore_win, win_path);
    if(restore_win[0]) new_schematic("switch_no_tcl_ctx", restore_win, "", 1);
  }
  return 0;
}

