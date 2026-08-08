/* File: scheduler.c
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
#include <stdarg.h>
/* n=1: messages in status bar
 * n=2: append str in ERC window messages
 * n=3: set ERC messages to str */
void statusmsg(char str[],int n)
{
  if(!str) return;
  if(str[0]== '\0') {
    my_free(_ALLOC_ID_, &xctx->infowindow_text);
    return;
  } else {
    if(n == 3) {
      my_strdup(_ALLOC_ID_, &xctx->infowindow_text, str);
    } else if(n == 2) {
      if(xctx->infowindow_text && xctx->infowindow_text[0]) {
        my_strcat(_ALLOC_ID_, &xctx->infowindow_text, "\n");
      }
      my_strcat(_ALLOC_ID_, &xctx->infowindow_text, str);
    }
  }
  if(!has_x) return;
  if(n == 2 || n == 3) {
    dbg(3, "statusmsg(): n = 2, str = %s\n", str);
  }
  else {
    tclvareval(xctx->top_path, ".statusbar.1 configure -text {", str, "}", NULL);
    dbg(3, "statusmsg(str, %d): -> str = %s\n", n, str);
  }
}

static int get_text(const char *s)
{
  int i, found=0;
  if(isonlydigit(s)) {
    i=atoi(s);
    found = 1;
  } else for(i=0;i<xctx->texts; ++i) {
    if(!strcmp(get_tok_value(xctx->text[i].prop_ptr, "name", 0), s)) {
      found=1;
      break;
    }
  }
  if(!found || i < 0 || i >= xctx->texts) return -1;
  return i;
}

static int get_symbol(const char *s)
{
  int i, found=0;
  if(isonlydigit(s)) {
    i=atoi(s);
    found = 1;
  } else for(i=0;i<xctx->symbols; ++i) {
    if(!strcmp(xctx->sym[i].name, s)) {
      found=1;
      break;
    }
  }
  if(!found || i < 0 || i >= xctx->symbols) return -1;
  return i;
}

int get_instance(const char *s)
{
  int i = -1, found=0;
  Int_hashentry *entry;

  if(isonlydigit(s)) {
     i=atoi(s);
     found = 1;
  }
  else if(xctx->floater_inst_table.table) {
    entry = int_hash_lookup(&xctx->floater_inst_table, s, 0, XLOOKUP);
    if(entry) {
      i = entry->value;
      found = 1;
    }
  } else {
    for(i=0;i<xctx->instances; ++i) {
      if(!strcmp(xctx->inst[i].instname, s)) {
        found=1;
        break;
      }
    }
  }
  if(!found || i < 0 || i >= xctx->instances) return -1;
  return i;
}

static int object_type_from_name(const char *s); /* defined below; used by xschem_cmds_h */
static void object_descriptor(char *buf, int bufsz, int type, int i, int c); /* used by `hover` */

static void xschem_cmd_help(int argc, const char **argv)
{
  char prog[PATH_MAX];
  const char *xschem_sharedir=tclgetvar("XSCHEM_SHAREDIR");
  #ifdef __unix__
  int running_in_src_dir = tclgetintvar("running_in_src_dir");
  #endif
  if( get_file_path("x-www-browser")[0] == '/' ) goto done;
  if( get_file_path("firefox")[0] == '/' ) goto done;
  if( get_file_path("chromium")[0] == '/' ) goto done;
  if( get_file_path("chrome")[0] == '/' ) goto done;
  if( get_file_path("xdg-open")[0] == '/' ) goto done;
  #ifndef __unix__
  wchar_t app[MAX_PATH] = {0};
  wchar_t w_url[PATH_MAX];
  char url[PATH_MAX]="", url2[PATH_MAX]="";
  int result = 0;
  if (xschem_sharedir) {
    my_snprintf(url, S(url), "%s/../doc/xschem_man/developer_info.html", xschem_sharedir);
    MultiByteToWideChar(CP_ACP, 0, url, -1, w_url, S(w_url));
    /* The file:// url scheme doesn't have any allowance for HTTP parameters.
     So, use FindExecutable to get the browser app and then ShellExecute */
    result = (int)FindExecutable(w_url, NULL, app);
    if (result > 32) goto done;
  }
  #endif
  if(has_x) tcleval("alert_ { No application to display html documentation} {}");
  else  dbg(0, "No application to display html documentation\n");
  return;
  done:
  my_strncpy(prog, tclresult(), S(prog));
  #ifdef __unix__
  if(running_in_src_dir) {
    tclvareval("launcher {", "file://", xschem_sharedir,
               "/../doc/xschem_man/developer_info.html#cmdref", "} ", prog, NULL);
  } else {
    tclvareval("launcher {", "file://", xschem_sharedir,
               "/../doc/xschem/xschem_man/developer_info.html#cmdref", "} ", prog, NULL);
  }
  #else
  my_snprintf(url2, S(url2), "file://%s#cmdref", url);
  MultiByteToWideChar(CP_ACP, 0, url2, -1, w_url, S(w_url));
  ShellExecute(0, NULL, app, w_url, NULL, SW_SHOWNORMAL);
  #endif
  Tcl_ResetResult(interp);
}

/* can be used to reach C functions from the Tk shell. */
static char *not_avail = "Not available in this context. If using --tcl consider using --command";

/* Refuse a mutating `xschem` subcommand on a read-only buffer (issue 0041). The
 * interactive keyboard/menu paths are guarded by readonly_block() (callback.c); this
 * closes the Tcl command surface -- scripts, the persistent/TCP command server and
 * action-log replay -- so a file-protected schematic cannot be mutated by any route.
 * Returns 1 (with the interp error result set + a CIW note) when the edit must be
 * refused, 0 when it may proceed. Call at an edit subcommand's top, AFTER its !xctx
 * check (it dereferences xctx->readonly). Mirrors the existing `xschem save` guard. */
static int scheduler_readonly_reject(Tcl_Interp *interp, const char *subcmd)
{
  if(!xctx || !xctx->readonly) return 0;
  /* CIW echo FIRST: tclvareval() overwrites the interp result, so running it after
   * Tcl_AppendResult silently blanked the "read-only" error message in GUI (has_x)
   * sessions -- scripts matching on the message saw an empty error. */
  if(has_x) tclvareval("if {[info procs ciw_echo] ne {}} {ciw_echo {read-only: ",
                       subcmd, " ignored}}", NULL);
  Tcl_ResetResult(interp);
  Tcl_AppendResult(interp, "xschem ", subcmd, ": schematic is read-only "
                   "(use Edit > Make Editable to enable editing)", NULL);
  return 1;
}

/* Forward decl: pin_scope_resolve() is defined below (after the xschem_cmds_a group) but
 * run_core's apply_pin_prop arm (Refactor B atom 18) calls it above its definition. */
static int pin_scope_resolve(const char *scope, int *primary_out, int **targets_out);

/* run_core -- the EFFECT half of the perform_action boundary. Dispatches a
 * migrated verb to its raw core with no readonly check and no log_action of its
 * own (perform_action owns both). Returns TCL_OK on success. Migrated verbs so
 * far: trim_wires (Refactor B atom 1), align (atom 2), rotate_in_place (atom 3),
 * flip_in_place (atom 4), flipv_in_place (atom 5) -- each a bare no-arg verb -- and
 * the ARG-CARRYING pivot verbs rotate (atom 6, the FIRST), flip (atom 7) and flipv (atom 8,
 * the LAST): each reads the shared pivot x0,y0 from argv[2]/argv[3] (falling back to the mouse
 * coords). flipv is a net vertical mirror = 180 rotate + horizontal flip, so its arm is THREE
 * move_objects calls (ROTATE, ROTATE, FLIP) about the shared pivot (NO ROTATELOCAL), not one.
 * rotate/flip/flipv/rotate_in_place/flip_in_place/flipv_in_place are the mid-gesture-split verbs: ONLY
 * their standalone (non-gesture) form crosses this boundary -- the during-move/during-
 * copy arms stay raw in the scheduler branch + callback.c key and are logged at the
 * move/copy END (issue 0069), never here (see the branch comment below).
 * check_unique_names (atom 26) is the ASYMMETRIC split: only its mode-1 RENAME
 * form crosses (the arm calls check_unique_names(1)); the mode-0 highlight is a
 * read-only-legal LOGGED QUERY that stays raw in the branch front + '#' key.
 * clear_drawing (atom 27) is a bare no-arg verb in the delete (atom 24) mold:
 * silent -> logged + a NEW readonly gate; its core is a SHARED teardown
 * primitive (load/undo-restore/window-teardown/clear_schematic/debug) whose
 * seven raw C callers stay below the boundary, and the core stays SILENT.
 * redo (atom 28) is the ZERO-DELTA consistency migration: the old branch was
 * already boundary-shaped (inline reject + fixed bare log + reset-on-success),
 * so gate and log consolidate with NO observable change; NO arity gate
 * (tolerant argc preserved -- the old branch executed + logged bare at ANY
 * argc) and NO push_undo (a redo is undo-stack NAVIGATION).
 * undo (atom 29) is redo's argv-parsed F-shared twin (the same consistency
 * class): its arm parses redo/set_modify from argv[2]/argv[3] with atoi
 * defaults exactly as the old branch did (tolerant argc, NO arity gate, NO
 * push_undo -- stack navigation) and its log is core_log_action's NORMALIZING
 * undo arm (bare at argc==2, `xschem undo %d %d` else).
 * More verbs add an arm here as they move onto the boundary. argc/argv are unused
 * for a bare no-arg verb but carry the pivot for an arg-carrying verb (rotate/flip/flipv); the
 * general boundary shape (audit §4) is the same either way.
 * NB: only the VERB dispatch routes here -- the shared C functions BELOW a verb are
 * ALSO internal sub-steps of other operations (trim_wires() is called raw by
 * align()/move-END autotrim; maintain_wire_segments() is called raw by many edits),
 * and those callers keep calling them raw (they are not user verbs and must not
 * self-log). round_schematic_to_grid() is exclusive to the align verb. */
static int run_core(const char *verb, int argc, const char *argv[])
{
  (void)argc; (void)argv;
  if(!strcmp(verb, "trim_wires")) {
    xctx->push_undo();
    trim_wires();
    draw();
    return TCL_OK;
  }
  else if(!strcmp(verb, "align")) {
    xctx->push_undo();
    round_schematic_to_grid(tclgetdoublevar("cadsnap"));
    /* W3: align-to-grid can snap a pin onto/off a wire -> re-split/rejoin (maintain).
     * Gated on autotrim_wires; undo pushed above. See wire_segment_splitting.md (W3). */
    if(tclgetboolvar("autotrim_wires")) maintain_wire_segments();
    set_modify(1);
    xctx->prep_hash_inst=0;
    xctx->prep_hash_wires=0;
    xctx->prep_net_structs=0;
    xctx->prep_hi_structs=0;
    draw();
    return TCL_OK;
  }
  else if(!strcmp(verb, "rotate_in_place")) {
    /* Refactor B atom 3: the STANDALONE (non-gesture) in-place rotate. Byte-identical to
     * the scheduler branch's standalone `else` body (rebuild + START + ROTATE|ROTATELOCAL
     * + END). move_objects(START/END) owns the undo push, so there is NO push_undo()/
     * draw() here -- the standalone body never had one, and adding one would double-push.
     * ROTATELOCAL rotates each object about its OWN 0,0 (move.c pvx/pvy), so no pivot/
     * mousex_snap seeding is needed. The during-move/during-copy arms are NOT here: they
     * are mid-gesture sub-steps logged at move/copy END (issue 0069) and stay raw. */
    rebuild_selected_array();
    move_objects(START,0,0,0);
    move_objects(ROTATE|ROTATELOCAL,0,0,0);
    move_objects(END,0,0,0);
    return TCL_OK;
  }
  else if(!strcmp(verb, "flip_in_place")) {
    /* Refactor B atom 4: the STANDALONE (non-gesture) in-place horizontal flip. Exact mirror
     * of the rotate_in_place arm -- byte-identical to the scheduler branch's standalone `else`
     * body (rebuild + START + FLIP|ROTATELOCAL + END). move_objects(START/END) owns the undo
     * push, so there is NO push_undo()/draw() here (adding one would double-push). ROTATELOCAL
     * flips each object about its OWN origin (move.c pvx/pvy; ROTATION() mirrors x about x0), so
     * no pivot/mousex_snap seeding is needed. The during-move/during-copy arms are NOT here:
     * they are mid-gesture sub-steps logged at move/copy END (issue 0069) and stay raw. */
    rebuild_selected_array();
    move_objects(START,0,0,0);
    move_objects(FLIP|ROTATELOCAL,0,0,0);
    move_objects(END,0,0,0);
    return TCL_OK;
  }
  else if(!strcmp(verb, "flipv_in_place")) {
    /* Refactor B atom 5: the STANDALONE (non-gesture) in-place VERTICAL flip. Byte-identical
     * to the scheduler branch's standalone `else` body. A net vertical mirror = a 180 rotate
     * + a horizontal flip, so it is THREE move_objects calls (ROTATE|ROTATELOCAL x2 then
     * FLIP|ROTATELOCAL), NOT one -- the order matters (transpose is a real bug). move_objects
     * (START/END) owns the undo push, so there is NO push_undo()/draw() here (adding one would
     * double-push). ROTATELOCAL pivots each object about its OWN origin, so no pivot/mousex_snap
     * seeding is needed. The during-move/during-copy arms are NOT here: they are mid-gesture
     * sub-steps logged at move/copy END (issue 0069) and stay raw. */
    rebuild_selected_array();
    move_objects(START,0,0,0);
    move_objects(ROTATE|ROTATELOCAL,0,0,0);
    move_objects(ROTATE|ROTATELOCAL,0,0,0);
    move_objects(FLIP|ROTATELOCAL,0,0,0);
    move_objects(END,0,0,0);
    return TCL_OK;
  }
  else if(!strcmp(verb, "rotate")) {
    /* Refactor B atom 6: the STANDALONE (non-gesture) PIVOT rotate -- the FIRST arg-carrying verb
     * on the boundary. Byte-identical to the scheduler branch's standalone `else` body:
     * rebuild + seed the SHARED pivot into mx_double_save/mousex_snap + START + ROTATE + END.
     * NO ROTATELOCAL (unlike rotate_in_place): the pivot is the single shared point x0,y0, not
     * each object's own origin -- so the whole selection spins rigidly about x0,y0. The pivot is
     * resolved from argv[2]/argv[3] (the scripted/Edit-menu-with-coords form) or the mouse coords
     * (bare `xschem rotate`), EXACTLY as the branch used to before delegating here. move_objects
     * (START/END) owns the undo push, so there is NO push_undo()/draw() here (adding one would
     * double-push). Seeding mousex_snap = x0 also lets core_log_action (which runs AFTER this,
     * perform_action = effect THEN log) read back the same pivot on the mouse-fallback path, so the
     * logged line can never diverge from the applied transform. The during-move/during-copy arms
     * are NOT here: they are mid-gesture sub-steps logged at move/copy END (0069) and stay raw. */
    double x0 = xctx->mousex_snap, y0 = xctx->mousey_snap;
    if(argc > 3) { x0 = atof(argv[2]); y0 = atof(argv[3]); }
    rebuild_selected_array();
    xctx->mx_double_save = xctx->mousex_snap = x0;
    xctx->my_double_save = xctx->mousey_snap = y0;
    move_objects(START,0,0,0);
    move_objects(ROTATE,0,0,0);
    move_objects(END,0,0,0);
    return TCL_OK;
  }
  else if(!strcmp(verb, "flip")) {
    /* Refactor B atom 7: the STANDALONE (non-gesture) PIVOT flip -- the SECOND arg-carrying verb on
     * the boundary, a near-clone of the rotate arm above (atom 6). Byte-identical to the scheduler
     * branch's standalone `else` body: rebuild + seed the SHARED pivot into mx_double_save/mousex_snap
     * + START + FLIP + END. NO ROTATELOCAL (unlike flip_in_place): the pivot is the single shared point
     * x0,y0, so the whole selection mirrors rigidly about the vertical line x=x0, not each object about
     * its own origin. The pivot is resolved from argv[2]/argv[3] (the scripted/Edit-menu-with-coords
     * form) or the mouse coords (bare `xschem flip`), EXACTLY as the branch used to before delegating
     * here. move_objects(START/END) owns the undo push, so there is NO push_undo()/draw() here (adding
     * one would double-push). Seeding mousex_snap = x0 also lets core_log_action (which runs AFTER this,
     * perform_action = effect THEN log) read back the same pivot on the mouse-fallback path, so the
     * logged line can never diverge from the applied transform. The during-move/during-copy arms are
     * NOT here: they are mid-gesture sub-steps logged at move/copy END (0069) and stay raw. */
    double x0 = xctx->mousex_snap, y0 = xctx->mousey_snap;
    if(argc > 3) { x0 = atof(argv[2]); y0 = atof(argv[3]); }
    rebuild_selected_array();
    xctx->mx_double_save = xctx->mousex_snap = x0;
    xctx->my_double_save = xctx->mousey_snap = y0;
    move_objects(START,0,0,0);
    move_objects(FLIP,0,0,0);
    move_objects(END,0,0,0);
    return TCL_OK;
  }
  else if(!strcmp(verb, "flipv")) {
    /* Refactor B atom 8: the STANDALONE (non-gesture) PIVOT vertical-flip -- the THIRD and LAST
     * arg-carrying pivot verb on the boundary, the MIRROR of the flip arm above (atom 7) exactly as
     * flipv_in_place (atom 5) mirrored flip_in_place (atom 4). Byte-identical to the scheduler branch's
     * standalone `else` body. A net vertical mirror = a 180 rotate + a horizontal flip, so it is THREE
     * move_objects calls (ROTATE, ROTATE, FLIP), NOT one -- the order matters (a transpose or a dropped
     * call is a real bug). NO ROTATELOCAL (unlike flipv_in_place): the pivot is the single shared point
     * x0,y0, so the whole selection mirrors rigidly about the horizontal line y=y0, not each object about
     * its own origin. The pivot is resolved from argv[2]/argv[3] (the scripted/Edit-menu-with-coords
     * form) or the mouse coords (bare `xschem flipv`), EXACTLY as the branch used to before delegating
     * here. move_objects(START/END) owns the undo push, so there is NO push_undo()/draw() here (adding
     * one would double-push). Seeding mousex_snap = x0 also lets core_log_action (which runs AFTER this,
     * perform_action = effect THEN log) read back the same pivot on the mouse-fallback path, so the
     * logged line can never diverge from the applied transform. The during-move/during-copy arms are NOT
     * here: they are mid-gesture sub-steps logged at move/copy END (0069) and stay raw. */
    double x0 = xctx->mousex_snap, y0 = xctx->mousey_snap;
    if(argc > 3) { x0 = atof(argv[2]); y0 = atof(argv[3]); }
    rebuild_selected_array();
    xctx->mx_double_save = xctx->mousex_snap = x0;
    xctx->my_double_save = xctx->mousey_snap = y0;
    move_objects(START,0,0,0);
    move_objects(ROTATE,0,0,0);
    move_objects(ROTATE,0,0,0);
    move_objects(FLIP,0,0,0);
    move_objects(END,0,0,0);
    return TCL_OK;
  }
  else if(!strcmp(verb, "break_wires")) {
    /* Refactor B atom 9: the FIRST NON-transform verb on the boundary, and the
     * wire-surgery SIBLING of trim_wires (atom 1). break_wires breaks wires at the
     * pins of the SELECTED instances (and at selected-wire endpoints); its arg is a
     * FLAG (0/1 = split / split-and-remove), NOT a coordinate pivot -- so it is
     * SIMPLER than the arg-carrying pivot verbs rotate/flip/flipv (atoms 6/7/8):
     * one flag to thread, and there is NO mid-gesture split (break_wires is not a
     * transform -- no STARTMOVE/STARTCOPY arms). `remove` is read from argv[2]
     * IDENTICALLY to core_log_action, so the logged form can never diverge from the
     * applied effect. The core break_wires_at_pins() OWNS its own undo (push_undo on
     * first mutation) + draw() + set_modify, so there is NO push_undo()/draw() here --
     * adding one would double-push (the atom-1 no-double-push rule). break_wires_at_pins()
     * is called ONLY by this verb's own entry points (the scheduler branch + the two
     * keys), so it IS the verb (1:1). NB the DISTINCT break_wires_at_point() (the
     * Alt-Right wire_cut mouse gesture) and break_wires_at_attach_points() (the
     * load/save auto-split) are SEPARATE functions and stay OFF this boundary. */
    int remove = 0;
    if(argc > 2) remove = atoi(argv[2]);
    break_wires_at_pins(remove);
    return TCL_OK;
  }
  else if(!strcmp(verb, "floaters_from_selected_inst")) {
    /* Refactor B atom 10: the SECOND NON-transform verb, and the FIRST after the
     * wire-surgery PAIR (trim_wires atom 1 + break_wires atom 9) completed the
     * boundary. It is deliberately the CLEANEST next atom: a BARE no-arg verb (no
     * coordinate pivot, no 0/1 flag, no mid-gesture split) -- even SIMPLER than
     * break_wires -- so run_core takes no argc/argv, and the log falls to
     * core_log_action's DEFAULT `xschem %s` form (NO per-verb branch, like the bare
     * trim_wires/align/in-place verbs). The effect flattens each SELECTED instance's
     * visible symbol texts into standalone floater texts (setting hide_texts + attach
     * on the instance). The core floaters_from_selected_inst() (select.c) OWNS its own
     * undo (push_undo on first mutation), set_modify and draw() -- so there is NO
     * push_undo()/draw() here; adding one would DOUBLE-push (the atom-1 no-double-push
     * rule, as with break_wires_at_pins atom 9). It is called ONLY by this verb's own
     * scheduler branch (NO key, NO other C caller), so it is strictly 1:1 with the
     * verb and the boundary/core_log_action is the single log site. */
    floaters_from_selected_inst();
    return TCL_OK;
  }
  else if(!strcmp(verb, "attach_labels")) {
    /* Refactor B atom 11: the THIRD non-transform verb (after break_wires atom 9 +
     * floaters atom 10). Its arg is a FLAG like break_wires -- `interactive` read
     * from argv[2] (default 0) -- but the value carries THREE DISTINCT meanings
     * (0 = silent place lab_pin, 1 = interactive dialog, 2 = the netlisting
     * lab_show mode), so unlike break_wires (which canonicalizes any nonzero to 1)
     * the value is PRESERVED, not collapsed. `interactive` is read from argv[2]
     * IDENTICALLY to core_log_action, so the logged form can never diverge from the
     * applied effect (the atom-9 FLAG-fidelity rule). The core attach_labels_to_inst()
     * (actions.c) OWNS its own undo (place_symbol pushes it once via to_push_undo on
     * the first placed label), set_modify(1) and draw() -- so there is NO push_undo()/
     * draw() here; adding one would DOUBLE-push (the atom-1 no-double-push rule).
     * attach_labels_to_inst() is NOT strictly 1:1: it is ALSO called RAW as a
     * netlisting sub-step by show_unconnected_pins() (netlist.c, attach_labels_to_inst(2))
     * and by the Shift+H interactive-DIALOG key (act_attach_labels, attach_labels_to_inst(1),
     * a registered csv-nolog non-equivalent path). Both stay BELOW the boundary (raw core,
     * no perform_action, no self-log) -- the boundary wraps the VERB DISPATCH, not the C fn
     * (the trim_wires atom-1 sub-step rule). Only this scheduler branch (Symbol menu +
     * scripted `xschem attach_labels [interactive]`) crosses. */
    int interactive = 0;
    if(argc > 2) interactive = atoi(argv[2]);
    attach_labels_to_inst(interactive);
    return TCL_OK;
  }
  else if(!strcmp(verb, "toggle_ignore")) {
    /* Refactor B atom 12: the FIRST FRICTION-FREE-SCOUTED verb. The exhaustive
     * classification in doc/claude/code_analysis/perform_action_boundary_migration_
     * friction_analysis.md scored ALL 243 mutating scheduler verbs against 6 criteria
     * and found exactly THREE friction-free ones; toggle_ignore is the cleanest. A
     * BARE no-arg verb like floaters (atom 10): run_core takes no argc/argv and the
     * log falls to core_log_action's DEFAULT `xschem %s` form (NO per-verb branch).
     * The effect cycles the *_ignore attribute (none -> "true" -> "short" -> none) on
     * the SELECTED instances AND wires, per the current netlist mode
     * ({spice,verilog,vhdl,tedax,spectre}_ignore). toggle_ignore() (actions.c) OWNS its
     * own undo (push_undo on the FIRST selected element), set_modify(1) and draw() --
     * so there is NO push_undo()/draw() here; adding one would DOUBLE-push (the atom-1
     * no-double-push rule). In a netlist mode where the attribute is undefined
     * (attr==NULL, e.g. `set netlist_type symbol`) toggle_ignore() is a harmless NO-OP
     * (no mutation, no push_undo, no draw) -- but the boundary STILL logs one line
     * unconditionally (the floaters no-op-still-logs property, §30). It is called by
     * ONLY two entry points -- this branch and the equivalent Shift+T key
     * (act_toggle_ignore, callback.c), BOTH routed through the boundary -- so it is 1:1
     * with the verb (NO shared-sub-step lock, unlike attach_labels atom 11). */
    toggle_ignore();
    return TCL_OK;
  }
  else if(!strcmp(verb, "reset_inst_prop")) {
    /* Refactor B atom 13: the FIRST BENEFICIARY of the log-on-success boundary change
     * (the shared-machinery half of this atom). reset_inst_prop resets an instance's
     * property string from its symbol template (set_inst_prop, editprop.c). It is the
     * FIRST VALIDATING verb on the boundary: it rejects a bad request with an early
     * TCL_ERROR + Tcl_SetResult *before* any mutation -- exactly the shape the old
     * unconditional-log boundary could not host (it would phantom-log the rejected
     * call). The two validation gates MOVE here from the scheduler branch and stay
     * BEFORE push_undo, so a bad arg mutates nothing and (via log-on-success) logs
     * nothing. On success argv[2] is the instance referent (a name or a numeric index,
     * resolved by get_instance) read IDENTICALLY to core_log_action's arm, so the
     * logged line can never diverge from the reset one. The undo is a SINGLE push_undo
     * (below), owned here -- there is no core fn that pushes, so unlike the
     * self-undo verbs (toggle_ignore/floaters) this arm DOES push once (and only once).
     * The old branch set the interp result to the instname on success; the boundary's
     * success-path Tcl_ResetResult clears it (no caller consumes it -- verified), so
     * this arm sets NO success result. */
    char *translated_sym = NULL;
    int sym_number = -1;
    int inst;
    if(argc < 3) {
      Tcl_SetResult(interp, "xschem reset_inst_prop needs 1 more argument", TCL_STATIC);
      return TCL_ERROR;
    }
    if((inst = get_instance(argv[2])) < 0 ) {
      Tcl_SetResult(interp, "xschem reset_inst_prop: instance not found", TCL_STATIC);
      return TCL_ERROR;
    }
    symbol_bbox(inst, &xctx->inst[inst].x1, &xctx->inst[inst].y1, &xctx->inst[inst].x2, &xctx->inst[inst].y2);
    xctx->push_undo();
    xctx->prep_hash_inst=0;
    xctx->prep_net_structs=0;
    xctx->prep_hi_structs=0;
    hash_names(-1, XINSERT);
    hash_names(inst, XDELETE);
    set_inst_prop(inst);
    my_strdup2(_ALLOC_ID_, &translated_sym, translate(inst, xctx->inst[inst].name));
    sym_number=match_symbol(translated_sym);
    if(sym_number > 0) {
      delete_inst_node(inst);
      xctx->inst[inst].ptr=sym_number;
    }
    set_inst_flags(&xctx->inst[inst]);
    hash_names(inst, XINSERT);
    /* new symbol bbox after prop changes (may change due to text length) */
    symbol_bbox(inst, &xctx->inst[inst].x1, &xctx->inst[inst].y1, &xctx->inst[inst].x2, &xctx->inst[inst].y2);
    set_modify(-2); /* reset floaters caches */
    draw();
    my_free(_ALLOC_ID_, &translated_sym);
    return TCL_OK;
  }
  else if(!strcmp(verb, "reset_symbol")) {
    /* Refactor B atom 22: the TWENTY-SECOND per-verb migration, the direct INLINE twin of
     * reset_inst_prop (§33, atom 13) sitting a few arms above -- a VALIDATING verb whose two
     * gates reject a bad call with an early TCL_ERROR BEFORE any mutation, so (via log-on-
     * success) a rejected call mutates nothing and logs nothing. This is an ADDITIVE-LOG+GATE
     * atom: the old branch had NEITHER a self-log NOR a readonly gate, so the migration ADDS
     * BOTH -- a replay line AND the C-level read-only gate (a CORRECTNESS FIX: the old branch
     * mutated a read-only cell). reset_symbol is a documented LOW-LEVEL batch sub-step: it
     * merely swaps xctx->inst[...].name; the CALLER (fix_symbols, xschem.tcl) deletes symbols
     * first and reload_symbols afterward.
     * *** CRITICAL DIVERGENCE from the reset_inst_prop template: this arm must NOT push_undo
     * and must NOT set_modify. *** fix_symbols brackets its whole remap loop in a SINGLE
     * `xschem push_undo` before the foreach, so N per-instance reset_symbol calls that each
     * pushed a slot would SHATTER that one-Ctrl-Z batch (one undo would revert only the last
     * remap); and fix_symbols owns the set_modify(1) after the loop. The precedent for a
     * no-undo/no-set_modify run_core arm is replace_symbol's fast-form (which skips both). The old
     * branch already ended in Tcl_ResetResult on success (a BLANK result -- unlike reset_inst_prop,
     * reset_symbol NEVER set the instname), and the boundary's success-path Tcl_ResetResult PRESERVES
     * that blank result. C89: decls at block top. */
    int inst;
    if(argc != 4) {
      Tcl_SetResult(interp, "xschem reset_symbol needs 2 additional arguments", TCL_STATIC);
      return TCL_ERROR;
    }
    if((inst = get_instance(argv[2])) < 0 ) {
      Tcl_SetResult(interp, "xschem reset_symbol: instance not found", TCL_STATIC);
      return TCL_ERROR;
    }
    my_strdup(_ALLOC_ID_, &xctx->inst[inst].name, argv[3]);
    return TCL_OK;
  }
  else if(!strcmp(verb, "replace_symbol")) {
    /* Refactor B atom 14: the SECOND VALIDATING verb, and the FIRST per-verb migration
     * to carry a FAST-FLAG log gate. It rides the atom-13 log-on-success boundary
     * UNCHANGED -- this atom touches NO shared machinery. replace_symbol swaps an
     * instance's symbol for another (delete_inst_node + inst.name = rel_sym_path(sym) +
     * match_symbol + new_prop_string). The fast-flag parse + the two validation gates
     * MOVE here from the scheduler branch and stay BEFORE push_undo: argc!=4 -> TCL_ERROR
     * "needs 2 additional arguments", then get_instance(argv[2])<0 -> TCL_ERROR "instance
     * not found" -- so a bad arg mutates nothing and (via log-on-success) logs nothing.
     * The `fast` flag (argc>4 && argv[4]=="fast") is a MULTI-substitution machinery
     * sub-mode: it SKIPS the single push_undo (exactly as the old branch did --
     * `if(!fast) push_undo()`), and core_log_action SKIPS the log for it too (the atom-4
     * save-fast axis: a replay sub-mode must not be logged). The `fast`/argv reads here
     * MUST be identical to core_log_action's. set_modify(1) is kept; draw() stays
     * COMMENTED-OUT -- replace_symbol relies on the CALLER to redraw (the old branch never
     * drew; adding a draw() would change behaviour). There is no core fn that pushes undo,
     * so (like reset_inst_prop, unlike the self-undo verbs) THIS arm owns the single
     * push_undo, gated on !fast. The old branch set the interp result to the new instname
     * on success; the boundary's success-path Tcl_ResetResult clears it (no caller
     * consumes it -- verified), so this arm sets NO success result. */
    int inst, fast = 0;
    char symbol[PATH_MAX];
    int sym_number, prefix;
    char *name=NULL;
    char *ptr=NULL;
    char *sym = NULL;
    if(argc > 4) {
      argc = 4;
      if(!strcmp(argv[4], "fast")) {
        fast = 1;
      }
    }
    if(argc != 4) {
      Tcl_SetResult(interp, "xschem replace_symbol needs 2 additional arguments", TCL_STATIC);
      return TCL_ERROR;
    }
    if((inst = get_instance(argv[2])) < 0 ) {
      Tcl_SetResult(interp, "xschem replace_symbol: instance not found", TCL_STATIC);
      return TCL_ERROR;
    }
    my_strncpy(symbol, argv[3], S(symbol));
    if(!fast) {
      xctx->push_undo();
      xctx->prep_hash_inst=0;
      xctx->prep_net_structs=0;
      xctx->prep_hi_structs=0;
    }
    my_strdup(_ALLOC_ID_, &sym, tcl_hook2(symbol));
    sym_number=match_symbol(sym);
    my_free(_ALLOC_ID_, &sym);
    if(sym_number>=0)
    {
      prefix=(get_tok_value(xctx->sym[sym_number].templ , "name",0))[0]; /* get new symbol prefix  */
    }
    else prefix = 'x';
    delete_inst_node(inst); /* 20180208 fix crashing bug: delete node info if changing symbol */
                         /* if number of pins is different we must delete these data *before* */
                         /* changing ysmbol, otherwise i might end up deleting non allocated data. */
    my_strdup2(_ALLOC_ID_, &xctx->inst[inst].name, rel_sym_path(symbol));
    xctx->inst[inst].ptr=sym_number;
    my_strdup(_ALLOC_ID_, &name, xctx->inst[inst].instname);
    if(name && name[0] )
    {
      /* 20110325 only modify prefix if prefix not NUL */
      if(prefix) name[0]=(char)prefix; /* change prefix if changing symbol type; */
      my_strdup(_ALLOC_ID_, &ptr,subst_token(xctx->inst[inst].prop_ptr, "name", name) );
      if(!fast) hash_names(-1, XINSERT);
      hash_names(inst, XDELETE);
      new_prop_string(inst, ptr,           /* sets also inst[].instname */
         tclgetboolvar("disable_unique_names")); /* set new prop_ptr */
      hash_names(inst, XINSERT);
      set_inst_flags(&xctx->inst[inst]);
      my_free(_ALLOC_ID_, &ptr);
    }
    my_free(_ALLOC_ID_, &name);
    set_modify(1);
    /* draw(); -- replace_symbol relies on the caller to redraw (old branch behaviour) */
    return TCL_OK;
  }
  else if(!strcmp(verb, "show_unconnected_pins")) {
    /* Refactor B atom 15: a BARE no-arg verb like floaters (atom 10) / toggle_ignore
     * (atom 12) -- run_core takes no argc/argv and the log falls to core_log_action's
     * DEFAULT `xschem %s` form (NO per-verb branch). It is the friction-free verb from
     * the fresh atom-15 fan-out scout (the atom-14 validating shortlist was EXHAUSTED):
     * always-mutating, 1:1, unconditional-log, no key. The effect selects every
     * instance and places a lab_show.sym label on each UNCONNECTED pin. It is the
     * SECOND verb to share the attach_labels_to_inst() core after atom 11: its core
     * show_unconnected_pins() (netlist.c) calls attach_labels_to_inst(2) RAW, which
     * OWNS the undo (place_symbol pushes it once via to_push_undo on the first placed
     * label), set_modify(1) and draw() -- so there is NO push_undo()/draw() here;
     * adding one would DOUBLE-push (the atom-1 no-double-push rule). That raw
     * attach_labels_to_inst(2) call stays SILENT below the boundary (its log lives in
     * core_log_action under the `attach_labels` verb, NOT inside the C fn -- the
     * atom-11 shared-sub-step lock), so routing show_unconnected_pins double-logs
     * NOTHING with the attach_labels verb. A no-unconnected-pins sheet is a harmless
     * no-op (attach_labels_to_inst places nothing, no push_undo, no set_modify) but the
     * boundary STILL logs one line unconditionally (the floaters no-op-still-logs
     * property, §30). */
    show_unconnected_pins();
    return TCL_OK;
  }
  else if(!strcmp(verb, "embed_rawfile")) {
    /* Refactor B atom 16: a HYBRID of reset_inst_prop (§33, the single-STRING referent +
     * an argc gate) and floaters/show_unconnected_pins (§30/§35, the core OWNS its own
     * undo). embed_rawfile base64-encodes a raw file into the single selected element's
     * `spice_data` attribute. The `~/` expansion (via the home_dir global, reachable here)
     * MOVES IN from the scheduler branch unchanged. The argc<3 gate is a VALIDATING-LITE
     * early TCL_ERROR (BEFORE any mutation) -- the old branch SILENTLY no-op'd on a missing
     * arg; the gate makes it error AND, via log-on-success, avoids phantom-logging a
     * no-path call. There is NO push_undo/set_modify/draw here: the core embed_rawfile()
     * (draw.c) OWNS the SINGLE push_undo + set_modify when it embeds (lastsel==1 &&
     * ELEMENT); adding one would DOUBLE-push (the atom-1 rule). NB embed_rawfile() draws
     * NOTHING (the old branch never drew), and a missing/non-regular file is a MUTATION
     * (base64_from_file returns NULL -> subst_token BLANKS spice_data), not a failure, so
     * the arm cannot pre-validate file existence -- the log records the PATH, replay
     * re-reads it (wrinkle 3, the external-file replay caveat). C89: f declared at block
     * top. */
    char f[PATH_MAX + 100];
    if(argc < 3) {
      Tcl_SetResult(interp, "xschem embed_rawfile needs a file argument", TCL_STATIC);
      return TCL_ERROR;
    }
    my_snprintf(f, S(f), "regsub {^~/} {%s} {%s/}", argv[2], home_dir);
    tcleval(f);
    my_strncpy(f, tclresult(), S(f));
    embed_rawfile(f);
    return TCL_OK;
  }
  else if(!strcmp(verb, "wire_cut")) {
    /* Refactor B atom 17: the SILENT-MUTATOR twin of break_wires (atom 9, §29) -- the
     * mouse-position wire cut (break_wires_at_point, check.c) that break_wires' §29 note
     * already flagged as the SEPARATE gesture core kept OFF break_wires' boundary. It logged
     * NOTHING before this atom. Only the SCRIPTED coord form crosses: the scheduler branch's
     * argc>3 guard sends it here; the no-coord GESTURE-START form stays RAW in the branch
     * (arms ui_state, no mutation), exactly the rotate/flip STARTMOVE-stays-raw split. The arg
     * is numeric coords + a bareword `noalign` flag (NO Tcl_Merge -- no metacharacter referent).
     * break_wires_at_point() OWNS a CONDITIONAL SINGLE push_undo (only when a wire is actually
     * split) + its own draw, so there is NO push_undo/draw here -- adding one would double-push
     * (the atom-1 rule); a point off any wire is a NO-OP (no push, no draw) that still returns
     * success. Reached only via the branch's argc>3 guard, so argv[2]/argv[3] are always
     * present; `align` is read from the args IDENTICALLY to core_log_action, so the logged form
     * can never diverge from the applied cut. break_wires_at_point() returns void -> always
     * TCL_OK (a no-op point-off-wire is a SUCCESS -> no-op-still-logs, §30). The interactive
     * Alt-Right gesture (callback.c break_wires_at_point at gesture completion) stays RAW+silent
     * under the chosen option (A) -- a pre-existing 0069-class gesture-drop gap this atom does
     * NOT widen but does NOT close, deferred to a follow-up gesture-logging atom (audit §37).
     * C89: decls at block top. */
    int i, align = 1;
    for(i = 2; i < argc; i++) if(!strcmp(argv[i], "noalign")) align = 0;
    break_wires_at_point(atof(argv[2]), atof(argv[3]), align);
    return TCL_OK;
  }
  else if(!strcmp(verb, "apply_pin_prop")) {
    /* Refactor B atom 18: a HIGHER-FRICTION coverage gain (the friction-free pool is EMPTY) --
     * a symbol-editor mutation that logged NOTHING and had NO C-level read-only gate before this
     * atom, carrying an INLINE mutation body (not a shared core, so strictly 1:1 with the verb --
     * C3) and TWO string referents. Follows the replace_symbol §34 template (a VALIDATING verb
     * whose validation MOVES IN before its single push_undo, and whose TWO referents log via
     * log_action_argv/Tcl_Merge) crossed with the reset_inst_prop §33 argc-gate. apply_pin_prop
     * applies <prop> to the symbol PINLAYER rects named by <scope>, mirroring the pin branch of
     * edit_rect_property without a dialog round-trip (cadence_pin_name_text.md; symbol_editor_
     * apply_scope.md). The whole inline body MOVES here verbatim from the scheduler branch:
     *   - the argc<3 VALIDATION is an early TCL_ERROR *before* any mutation, so (via log-on-
     *     success, §33) a bad arg mutates nothing and logs nothing;
     *   - pin_scope_resolve() is the SHARED READ-ONLY resolver (also used by pin_scope_prop_
     *     uniform / the SP3 preview) -- it stays RAW below the boundary, does NOT mutate;
     *   - the GUARD-PASS no-op (nothing would change) returns "0"+TCL_OK BEFORE push_undo -- NO
     *     undo slot; under log-on-success it STILL logs one line (a no-op is a SUCCESS, §30/§32);
     *   - else the SINGLE push_undo (owned here -- there is no self-undo core) + the apply loop
     *     (set_different_token / pin_reorient / pin_view_apply) + set_modify(1) + draw().
     * RESULT-DROPPED (verified): the old branch returned a MEANINGFUL "0"/"1" interp result; the
     * boundary's success-path Tcl_ResetResult BLANKS it. The production consumer gfxform::do_apply
     * DISCARDS the result; the two standalone tests that asserted it (symbol_pin_scope.tcl /
     * pin_name_text.tcl) were updated to assert the EFFECT (a stronger oracle) -- so no caller
     * regresses. The Tcl_SetResult("0"/"1") is kept here for a byte-faithful body; the boundary
     * clears it on success (like reset_inst_prop's dropped instname, §33). C89: decls at block top. */
    int i, n, change = 0, primary = -1, ntargets;
    int *targets;
    const char *scope, *newprop;
    char *base = NULL;          /* primary pin's prop: the changed-fields baseline */
    if(argc < 3) {
      Tcl_SetResult(interp, "xschem apply_pin_prop needs: [scope] new_prop", TCL_STATIC);
      return TCL_ERROR;
    }
    if(argc >= 4) { scope = argv[2]; newprop = argv[3]; }   /* apply_pin_prop <scope> <prop> */
    else          { scope = "selected"; newprop = argv[2]; } /* apply_pin_prop <prop> (back-compat) */
    ntargets = pin_scope_resolve(scope, &primary, &targets);
    if(primary >= 0) my_strdup(_ALLOC_ID_, &base, xctx->rect[PINLAYER][primary].prop_ptr);
    /* No pin primary (sel_array[0] is not a pin) but a scope like "all" still resolves
     * targets: use the FIRST target as the changed-fields baseline so a fan can NEVER
     * degenerate into a whole-prop overwrite that mass-renames every pin to the same
     * string (the base==NULL else branch below). */
    if(!base && ntargets > 0) my_strdup(_ALLOC_ID_, &base, xctx->rect[PINLAYER][targets[0]].prop_ptr);
    /* guard pass: would applying change any target pin? avoid an empty undo slot */
    for(i = 0; i < ntargets && !change; i++) {
      char *cand = NULL;
      n = targets[i];
      my_strdup(_ALLOC_ID_, &cand, xctx->rect[PINLAYER][n].prop_ptr);
      if(base) {
        if(set_different_token(&cand, newprop, base)) change = 1;
      } else {
        my_strdup(_ALLOC_ID_, &cand, newprop);
        if(!cand || !xctx->rect[PINLAYER][n].prop_ptr || strcmp(cand, xctx->rect[PINLAYER][n].prop_ptr)) change = 1;
      }
      my_free(_ALLOC_ID_, &cand);
    }
    if(!ntargets || !change) {
      if(base) my_free(_ALLOC_ID_, &base);
      my_free(_ALLOC_ID_, &targets);
      Tcl_SetResult(interp, "0", TCL_STATIC);
      return TCL_OK;
    }
    xctx->push_undo();
    for(i = 0; i < ntargets; i++) {
      char olddir[40];
      n = targets[i];
      my_snprintf(olddir, S(olddir), "%s", get_tok_value(xctx->rect[PINLAYER][n].prop_ptr, "dir", 0));
      if(base) {
        set_different_token(&xctx->rect[PINLAYER][n].prop_ptr, newprop, base);
      } else {
        my_strdup(_ALLOC_ID_, &xctx->rect[PINLAYER][n].prop_ptr, newprop);
      }
      set_rect_flags(&xctx->rect[PINLAYER][n]);
      if(strcmp(olddir, get_tok_value(xctx->rect[PINLAYER][n].prop_ptr, "dir", 0))) pin_reorient(n);
      pin_view_apply(n);   /* create/delete the name view per show_pinname, then sync it */
    }
    if(base) my_free(_ALLOC_ID_, &base);
    my_free(_ALLOC_ID_, &targets);
    set_modify(1);
    draw();               /* a pin's name view is a separate object -> full redraw */
    Tcl_SetResult(interp, "1", TCL_STATIC);
    return TCL_OK;
  }
  else if(!strcmp(verb, "move_instance")) {
    /* Refactor B atom 19: a HIGHER-FRICTION coverage gain (the friction-free pool is EMPTY) --
     * a PURE SCRIPTED instance-reposition verb (`xschem move_instance inst x y rot flip [nodraw]
     * [noundo]`, a `-` in any of x/y/rot/flip keeps the existing value) with an INLINE mutation
     * body (not a shared core, so strictly 1:1 with the verb -- C3, like apply_pin_prop §38), a
     * CONDITIONAL push_undo/draw (the noundo/nodraw C5 sub-mode) and an instance-name referent.
     * The whole inline body MOVES here verbatim from the scheduler branch (which merely dropped
     * the !xctx guard + its per-verb scheduler_readonly_reject, both now the boundary's):
     *   - the argc<7 VALIDATION is an early TCL_ERROR *before* any mutation (the reset_inst_prop
     *     §33 / embed_rawfile §36 shape). The old branch SILENTLY no-op'd on a short call
     *     (`if(argc>6)` false -> nothing, TCL_OK); under log-on-success (§33) that would phantom-log
     *     a useless line AND -- worse -- let a short call reach core_log_action, which reads
     *     argv[3..6] and would read OUT OF BOUNDS (the embed_rawfile §36 argv[2]-NULL crash class).
     *     The gate returns before both. Verified no caller relies on the silent no-op (pure scripted,
     *     grep-clean);
     *   - the nodraw/noundo flag parse (argc>7 -> scan argv[7..]);
     *   - get_instance(argv[2])<0 -> TCL_ERROR "instance not found" (BEFORE the conditional push);
     *   - `if(undo) push_undo()` -- ONE CONDITIONAL push, owned here (there is no self-undo core,
     *     like reset_inst_prop/replace_symbol; a normal move pushes once, a `noundo` move pushes
     *     NOTHING). Mirrors replace_symbol's !fast-gated push (§34) but the flag GATES ONLY the undo,
     *     NOT the log (see core_log_action below);
     *   - the dashed x/y/rot/flip sets (each gated on strcmp(argv[N],"-") != 0);
     *   - symbol_bbox recompute + the prep_hash/net/hi flag resets;
     *   - `if(dr) draw()`.
     * NB there is NO set_modify(1) -- the old branch had none, and (verified: a move on a SAVED
     * sheet leaves `modified`==0) adding one would change behaviour. NO success Tcl_SetResult
     * either -- the branch set none (an incidental "0" leaks in from an internal tcleval on the
     * mutation path; the boundary's success-path Tcl_ResetResult blanks it uniformly, and NO caller
     * consumes it -- pure scripted). The original body declared `int i` twice in nested blocks (the
     * flag loop counter + the instance index); flattened here to `i` (loop) + `inst` (index) at the
     * block top (C89). */
    int i, inst, undo = 1, dr = 1;
    if(argc < 7) {
      Tcl_SetResult(interp, "xschem move_instance needs: inst x y rot flip [nodraw] [noundo]", TCL_STATIC);
      return TCL_ERROR;
    }
    for(i = 7; i < argc; i++) {
      if(!strcmp(argv[i], "nodraw")) dr = 0;
      if(!strcmp(argv[i], "noundo")) undo = 0;
    }
    if((inst = get_instance(argv[2])) < 0 ) {
      Tcl_SetResult(interp, "xschem move_instance: instance not found", TCL_STATIC);
      return TCL_ERROR;
    }
    if(undo) xctx->push_undo();
    if(strcmp(argv[3], "-")) xctx->inst[inst].x0 = atof(argv[3]);
    if(strcmp(argv[4], "-")) xctx->inst[inst].y0 = atof(argv[4]);
    if(strcmp(argv[5], "-")) xctx->inst[inst].rot = (unsigned short)atoi(argv[5]);
    if(strcmp(argv[6], "-")) xctx->inst[inst].flip = (unsigned short)atoi(argv[6]);
    symbol_bbox(inst, &xctx->inst[inst].x1, &xctx->inst[inst].y1, &xctx->inst[inst].x2, &xctx->inst[inst].y2);
    xctx->prep_hash_inst=0;
    xctx->prep_net_structs=0;
    xctx->prep_hi_structs=0;
    if(dr) {
      draw();
    }
    return TCL_OK;
  }
#if HAS_CAIRO==1
  else if(!strcmp(verb, "image")) {
    /* Refactor B atom 20 (audit §40): the MUTATING tail of `xschem image [invert|white_transp|
     * black_transp|transp_white|transp_black|blend_white|blend_black|write_back]`, moved verbatim
     * from the scheduler branch (which kept only the read-only-safe help/argc<3 replies IN FRONT of
     * the boundary). HAS_CAIRO-gated because edit_image is `#if HAS_CAIRO==1`; on a no-cairo build
     * the branch itself does not exist, so perform_action("image") is never reached. The branch's
     * bare mutation (it had NO readonly gate) now sits under the boundary's ONE gate -- the
     * correctness fix (pre-migration `image invert` mutated a read-only cell). Order preserved from
     * the branch: the `No images selected` precondition (a MUTATION precondition, NOT a read-only-
     * safe query -- it stays BELOW the boundary so a read-only cell REFUSES first; accepted message
     * change on the readonly+nothing-selected corner), the flag parse, then the `if(what)` block:
     * rebuild_selected_array, set_modify(1) ONLY when write_back (256) is set (a plain invert leaves
     * modified==0 -- pinned on the pre-migration binary), the SINGLE push_undo, the edit_image loop
     * over the selected GRIDLAYER image rects (flags&1024), draw(). Returns TCL_OK on BOTH the
     * mutate AND the what==0 no-op (an unrecognized flag word) so the no-op still logs (§30), while
     * `No images selected` returns TCL_ERROR so a failed precondition logs nothing (log-on-success).
     * C89: the branch's `int n, i, c` + `int what` + `xRect *r` decls move here at block top. */
    int n, i, c, what = 0;
    xRect *r;
    if(xctx->lastsel == 0) {
      Tcl_SetResult(interp, "No images selected", TCL_STATIC);
      return TCL_ERROR;
    }
    for(i = 2; i < argc; i++) {
      if(!strcmp(argv[i], "invert"))       what |=   1;
      if(!strcmp(argv[i], "white_transp")) what |=   2;
      if(!strcmp(argv[i], "black_transp")) what |=   4;
      if(!strcmp(argv[i], "transp_white")) what |=   8;
      if(!strcmp(argv[i], "transp_black")) what |=  16;
      if(!strcmp(argv[i], "blend_white"))  what |=  32;
      if(!strcmp(argv[i], "blend_black"))  what |=  64;
      if(!strcmp(argv[i], "write_back"))   what |= 256;
    }
    if(what) {
      rebuild_selected_array();
      if(what & 256) set_modify(1);
      xctx->push_undo();
      for(n = 0; n < xctx->lastsel; ++n) {
        if(xctx->sel_array[n].type == xRECT) {
          i = xctx->sel_array[n].n;
          c = xctx->sel_array[n].col;
          r = &xctx->rect[c][i];
          if(c == GRIDLAYER && r->flags & 1024) {
            edit_image(what, &xctx->rect[c][i]);
          }
        }
      }
      draw();
    }
    return TCL_OK;
  }
#endif
  else if(!strcmp(verb, "change_elem_order")) {
    /* Refactor B atom 21 (audit §41): reorders the z-order (array position) of the SELECTED
     * object -- `xschem change_elem_order <n>` sets it to position n (n>=0), or n==-1 opens the
     * interactive "Object Sequence number" input_line dialog (the Shift+S / Prop-menu form). Its
     * arg is a value-carrying integer like attach_labels (atom 11), so core_log_action PRESERVES
     * it with %d (not collapsed like break_wires atom 9). The core change_elem_order() (editprop.c)
     * OWNS its own push_undo (on the first mutation, gated on `modified`) + set_modify(1) -- so
     * there is NO push_undo/set_modify/draw here; adding one would DOUBLE-push (the atom-1
     * no-double-push rule, as with break_wires/floaters/toggle_ignore). It rebuilds the selection
     * itself and guards on lastsel==1, so a nothing-selected (or multi-selected) call is a harmless
     * NO-OP. UNLIKE the §30 no-op-still-logs verbs (floaters/toggle_ignore), this verb PRESERVES the
     * pre-migration had_sel LOG GATE (in core_log_action, `if(xctx->lastsel)`) -- §30 was REJECTED
     * here because the verb is SELECTION-DEPENDENT and keeps its target selected, so a phantom
     * empty-selection line would reorder a still-selected object on replay (adversarial-review MAJOR;
     * the spec's form-split fallback, audit §41). TWO
     * validation gates MOVE here from the branch and stay BEFORE the effect: the argc<3 gate (an
     * early TCL_ERROR -- the old branch SILENTLY no-op'd on a missing arg; the gate ALSO prevents
     * core_log_action from reading argv[2] OOB on a short call, the move_instance §39 crash class)
     * and the `n >= 0 || n == -1` range gate (a bad n -- the old branch silently ignored it; now an
     * early TCL_ERROR so, via log-on-success, a bad n mutates nothing AND logs nothing). `n` is read
     * from argv[2] with the SAME atoi as core_log_action, so the logged form can never diverge from
     * the applied reorder. NB change_elem_order() is NOT strictly 1:1: it is ALSO called RAW as a
     * sub-step by the `instance_number inst <n>` scripted verb (scheduler.c) -- that caller stays
     * BELOW the boundary (raw core, no perform_action, no self-log; it logged nothing before and
     * still does), exactly the attach_labels atom-11 shared-sub-step rule. C89: n at block top. */
    int n;
    if(argc < 3) {
      Tcl_SetResult(interp, "xschem change_elem_order needs an integer argument", TCL_STATIC);
      return TCL_ERROR;
    }
    n = atoi(argv[2]);
    if(!(n >= 0 || n == -1)) {
      Tcl_SetResult(interp, "xschem change_elem_order: invalid order (need n >= 0 or -1)", TCL_STATIC);
      return TCL_ERROR;
    }
    change_elem_order(n);
    return TCL_OK;
  }
  else if(!strcmp(verb, "instance_number")) {
    /* Refactor B atom 23 (audit §43): the MUTATE half of `xschem instance_number <inst> <n>`
     * -- reorders the SELECTED instance's z-order (array position) to n. The QUERY form
     * (argc==3, a read-only-safe position read-back) does NOT reach here: the scheduler branch
     * keeps it RAW IN FRONT of the boundary (the image §40 query/mutate split), so run_core is
     * entered ONLY via the branch's `if(argc>3)` delegation -- argc is therefore always >3 and
     * argv[3] is always present. The two gates re-assert defensively BEFORE any mutation (an
     * early TCL_ERROR -- and the argc<3 gate keeps the query branch's message in parity): argc<3
     * -> "1 additional argument", get_instance(argv[2])<0 -> "instance not found". The effect is
     * SELF-CONTAINED -- it unselect_all + select_element(argv[2]) itself, so its replay does NOT
     * depend on the ambient selection (no had_sel/0005 dependence, unlike change_elem_order).
     * *** NO push_undo and NO set_modify here: the shared change_elem_order() core (editprop.c)
     * OWNS both -- it calls push_undo() on the mutate path (before setting its local `modified`)
     * and set_modify(1) at the end (that set_modify gated on `modified`) -- so adding either here
     * would DOUBLE-push (the atom-1 no-double-push rule, the atom-21 precedent). *** The raw
     * change_elem_order(atoi(argv[3])) sub-step stays SILENT below the boundary (the atom-11
     * shared-sub-step lock -- it is ALSO the `change_elem_order` verb's core, but a raw sub-step
     * call must not self-log; instance_number logs its OWN `instance_number` line, NOT a
     * `change_elem_order` line). The branch drew, so draw() is preserved.
     *
     * THE n >= 0 GATE (a replay-safety divergence from change_elem_order's `n >= 0 || n == -1`
     * gate). change_elem_order(n<0) opens the interactive "Object Sequence number" input_line
     * DIALOG (editprop.c) -- change_elem_order's VERB allows this (n==-1 is its Shift-S interactive
     * form, whose logged `-1` line is the accepted interactive-replay class). instance_number is a
     * PURE SCRIPTED verb (no key/menu/interactive entry), so it must NEVER reach that dialog: a
     * scripted verb that opened a modal would WEDGE a headless action-log replay, and -- now that
     * the mutate is LOGGED -- a `xschem instance_number <inst> <neg>` line would replay straight
     * into that wedge. So n<0 is REJECTED here (early TCL_ERROR before any mutation -> via
     * log-on-success it mutates nothing and logs nothing), keeping EVERY logged instance_number
     * line a deterministic, dialog-free, faithfully-replayable reorder (n is read with the SAME
     * atoi as core_log_action, so the logged form can never diverge from the applied reorder;
     * an out-of-range n>=0 is clamped in-core and replays to the same clamp -- the atom-21 value-
     * preserving property). C89: i at block top. */
    int i;
    if(argc < 3) {
      Tcl_SetResult(interp, "xschem instance_number 1 additional argument", TCL_STATIC);
      return TCL_ERROR;
    }
    if((i = get_instance(argv[2])) < 0 ) {
      Tcl_SetResult(interp, "xschem instance_number: instance not found", TCL_STATIC);
      return TCL_ERROR;
    }
    if(atoi(argv[3]) < 0) {
      Tcl_SetResult(interp, "xschem instance_number: invalid order (need n >= 0)", TCL_STATIC);
      return TCL_ERROR;
    }
    unselect_all(0);
    select_element(i, SELECTED, 1, 1);
    rebuild_selected_array();
    change_elem_order(atoi(argv[3]));
    draw();
    return TCL_OK;
  }
  else if(!strcmp(verb, "delete")) {
    /* Refactor B atom 24 (audit §44): a BARE no-arg mutating verb, the near-twin of toggle_ignore
     * (atom 12) / floaters (atom 10) -- it deletes the current selection. The core delete()
     * (select.c) OWNS its undo (push_undo on the first mutation, select.c:707), set_modify (788)
     * and draw() (790), and returns VOID => the branch is always TCL_OK. So run_core adds NO
     * push_undo()/draw() here -- adding one would DOUBLE-push (the atom-1 no-double-push rule).
     *
     * THE ONE FRICTION is the ARITY GATE (F-validate, the reset_inst_prop §33 argc-gate). The old
     * scheduler branch acted only inside `if(argc==2)`, so a malformed `xschem delete <extra>` was
     * a SILENT no-op returning TCL_OK. Under log-on-success (atom 13) that silent no-op would be
     * PHANTOM-logged, so we validate argc==2 and return TCL_ERROR otherwise (mutating nothing,
     * logging nothing -- the one deliberate behaviour tighten: malformed -> rejected, not silent).
     * The bare `xschem delete` form logs via core_log_action's DEFAULT `xschem %s` arm (NO per-verb
     * branch, like floaters/toggle_ignore). delete() reads NO x/y coords -> NOT a coordinate-replay
     * form; it deletes the ambient selection, so its logged line replays against whatever is selected
     * (the standard selection-dependent replay class).
     *
     * delete() is a benign SHARED primitive -- the cut verb (scheduler.c cut branch: save_selection
     * + delete(1)), three preview re-arm teardowns (delete(0)), save.c, and the callback.c interactive
     * gestures all call it RAW -- but it ROUTES NO VERBS through the boundary and stays raw below it;
     * only the `delete` VERB crosses (the trim_wires atom-1 shared-sub-step rule, the attach_labels
     * atom-11 shared-core rule). The two inline legacy-switch KEYS -- Ctrl-X (logs `xschem cut`) and
     * XK_Delete (logs `xschem delete`), both in callback.c -- call delete() DIRECTLY and self-log;
     * they NEVER reach this scheduler branch, so they stay untouched and cannot double-log (the
     * shipped cut arrangement). The boundary's scheduler_readonly_reject also CONSOLIDATES the
     * read-only gate that delete()'s own begin_edit() backstop (select.c:695) already provided --
     * belt-and-suspenders, no behaviour change. */
    if(argc != 2) {
      Tcl_SetResult(interp, "xschem delete: too many arguments", TCL_STATIC);
      return TCL_ERROR;
    }
    delete(1/*to_push_undo*/);
    return TCL_OK;
  }
  else if(!strcmp(verb, "add_pin_stubs")) {
    /* Refactor B atom 25 (audit §45; decision doc perform_action_atom25_add_pin_stubs_returnvalue_
     * condlog_decision.md). Draws a wire stub + outward lab_pin net-label out of each selected/
     * unconnected pin. The flags -prefix/-suffix/-inst-prefix are parsed here IDENTICALLY to
     * core_log_action's arm (so the logged form can never diverge from the applied effect). The core
     * add_pin_stubs() (actions.c) OWNS its single push_undo (on the first store) + set_modify + draw,
     * so this arm adds NONE (the atom-1 no-double-push rule).
     *
     * OPTION (c) -- NO-OP-STILL-LOGS. The core returns `added` (stub count); the old branch gated its
     * log on `if(added>0)`. That gate is INTENTIONALLY DROPPED here: `added==0` is a no-op SUCCESS
     * (nothing unconnected to stub), NOT a failure -- exactly like floaters-nothing-selected (§30),
     * toggle_ignore-attr==NULL (§32) and delete-nothing-selected (§44), all of which log their no-op
     * under log-on-success. So this arm DISCARDS `added`, always returns TCL_OK, and the boundary logs
     * one idempotent, replayable line unconditionally. The old success-path count interp-result is
     * dropped (the boundary clears the interp on success; grep-verified NO Tcl caller consumes it --
     * the Symbol-menu -command discards it, the SPACE key reads the C-fn int return, not the Tcl
     * result; the apply_pin_prop §38 precedent). The boundary ADDS the C-level readonly gate the
     * scripted verb NEVER HAD -- a correctness fix; the core keeps its OWN silent `if(readonly) return
     * 0` for the SPACE key's pan-on-decline dual-use (callback.c act_add_pin_stubs stays RAW below the
     * boundary, so it never double-logs -- the delete/cut F-2ndentry pattern). C89: decls at top. */
    const char *prefix = "", *suffix = "";
    int inst_prefix = 0, i;
    for(i = 2; i < argc; ++i) {
      if(!strcmp(argv[i], "-prefix") && i + 1 < argc) prefix = argv[++i];
      else if(!strcmp(argv[i], "-suffix") && i + 1 < argc) suffix = argv[++i];
      else if(!strcmp(argv[i], "-inst-prefix") || !strcmp(argv[i], "-inst_prefix")) inst_prefix = 1;
    }
    add_pin_stubs(prefix, suffix, inst_prefix);
    return TCL_OK;
  }
  else if(!strcmp(verb, "check_unique_names")) {
    /* Refactor B atom 26 (audit §46; decision doc perform_action_atom26_check_unique_names_
     * asymmetric_split_decision.md): ONLY mode 1 (rename) crosses the boundary -- the branch
     * delegates solely on argv[2]=="1". check_unique_names(1) (token.c) OWNS its undo (push_undo
     * on the FIRST duplicate found, token.c:851) + set_modify(1) (875), so this arm adds NO
     * push_undo/draw (the atom-1 no-double-push rule). Returns void => always TCL_OK; a
     * no-duplicates run is a no-op SUCCESS that still logs one idempotent line (§30
     * no-op-still-logs). Extra args beyond the "1" are ignored, exactly as the old branch did.
     * Mode 0 (duplicate highlight) is the read-only-legal LOGGED QUERY: it stays RAW in the
     * branch front + the '#' key with its own log_action (the asymmetric split -- see the
     * branch comment). */
    check_unique_names(1);
    return TCL_OK;
  }
  else if(!strcmp(verb, "clear_drawing")) {
    /* Refactor B atom 27 (audit §47; decision doc perform_action_atom27_clear_drawing_decision.md):
     * a BARE no-arg mutating verb in the delete (atom 24) mold -- empties the current drawing but
     * does NOT purge symbols. clear_drawing() (actions.c) is a SHARED teardown primitive (load_
     * schematic, disk/memory undo restore, delete_schematic_data, clear_schematic = the separate
     * `xschem clear` verb, debug) -- ALL callers stay RAW below the boundary and the core stays
     * SILENT (a core log would spam every load/undo/close; audit §4 log-at-the-verb rule). Only
     * this VERB crosses. NO push_undo/set_modify/draw exist anywhere on this path and NONE are
     * added: destructive-with-no-undo is ACCEPTED shipped behaviour (the logged line replays
     * faithfully but is irreversible -- decision doc §2); a push_undo here would be a behaviour
     * change, not a migration (and the test's undo-depth detector would catch it).
     * THE ONE FRICTION is the ARITY GATE (F-validate, the reset_inst_prop §33 argc-gate): the old
     * branch acted only inside `if(argc==2)`, so `xschem clear_drawing <extra>` was a silent
     * TCL_OK no-op that log-on-success would PHANTOM-log; validate argc==2 and reject otherwise
     * (the one deliberate behaviour tighten). unselect_all(1) is the branch's original pre-step
     * (selection torn down BEFORE the storage resets free the selected objects) -- kept, same
     * order. Bare-verb log via core_log_action's DEFAULT `xschem %s` arm (NO per-verb branch).
     * The boundary's scheduler_readonly_reject is NEW here -- a correctness fix (pre-migration a
     * READ-ONLY view was silently emptied; the 0041/0051 class, like reset_symbol §42). */
    if(argc != 2) {
      Tcl_SetResult(interp, "xschem clear_drawing: too many arguments", TCL_STATIC);
      return TCL_ERROR;
    }
    unselect_all(1);
    clear_drawing();
    return TCL_OK;
  }
  else if(!strcmp(verb, "redo")) {
    /* Refactor B atom 28 (audit §48; decision doc perform_action_atom28_redo_decision.md): the
     * ZERO-DELTA consistency migration -- the old branch was already boundary-shaped (inline
     * readonly reject + fixed bare log + reset-on-success), so this arm changes NOTHING
     * observable. pop_undo_keep_selection(1,1) (select.c, the issue-0095 selection-keeping
     * wrapper over xctx->pop_undo) is undo-stack NAVIGATION: NO push_undo exists on this path
     * and NONE is added (a push here would fire at cur<head and TRUNCATE the redo tail --
     * save.c push_undo snaps head=++cur -- turning every redo into a no-op); set_modify is
     * passed INTO the core. NO ARITY GATE -- deliberately unlike delete (§44)/clear_drawing
     * (§47), whose OLD branches were if(argc==2) silent no-ops (phantom-log hazard): redo's old
     * branch EXECUTES and logs bare at ANY argc, so tolerant argc is the preserved behaviour
     * (the toggle_ignore §32 precedent) and the DEFAULT `xschem %s` log arm keeps the line
     * byte-identical bare at every argc. An empty redo stack early-returns in-core = a no-op
     * SUCCESS that still logs one idempotent line (§30) -- byte-identical to the old
     * unconditional log. F-shared: run_core's undo arm below (atom 29) calls
     * pop_undo_keep_selection(redo, set_modify) with argv-parsed ints (`xschem undo 1 1` = a
     * redo with its OWN `xschem undo %d %d` log) -- the argv-parsed site, distinct
     * verb, distinct line, no double-log path; the S7 exact-count rows lock both call sites. */
    pop_undo_keep_selection(1, 1); /* issue 0007: keep selection across redo */
    return TCL_OK;
  }
  else if(!strcmp(verb, "undo")) {
    /* Refactor B atom 29 (audit §49; decision doc perform_action_atom29_undo_decision.md): the
     * undo-family twin of redo (§48) -- the old branch was already boundary-shaped (inline
     * readonly reject + normalized two-form log + reset-on-success), so gate and log consolidate
     * with NO observable change. pop_undo_keep_selection(redo, set_modify) (select.c, the
     * issue-0095 selection-keeping wrapper over xctx->pop_undo) is undo-stack NAVIGATION: NO
     * push_undo is added here (the at-head push that arms the redo slot lives INSIDE the core,
     * save.c pop_undo; a spurious push here would pop back the just-pushed state = a no-op undo).
     * NO ARITY GATE -- tolerant argc is the preserved behaviour (§48 rule: an arity gate is a
     * consequence of an OLD if(argc==N) silent no-op, which undo never had); extra args are
     * consumed by the atoi defaults exactly as the old branch did. The redo flag passes through
     * verbatim (0/4 undo, 1 redo, 2 peek -- save.c), so `xschem undo 1 1` IS a redo wearing the
     * undo verb, logged as its OWN `xschem undo 1 1` line by core_log_action's NORMALIZING arm
     * (which reads argv IDENTICALLY to this parse -- the rotate/break_wires/attach_labels
     * invariant). An empty undo stack no-ops in-core (cur==tail early return) = a no-op SUCCESS
     * that still logs one idempotent line (§30). F-shared: the redo arm above calls the SAME core
     * fixed-arg (1, 1) -- distinct verb, distinct line, no double-log path; the S7 exact-count
     * rows pin both call sites (this arm is now the ONE argv-parsed site). */
    int redo = 0, set_modify = 1;
    if(argc > 2) redo = atoi(argv[2]);
    if(argc > 3) set_modify = atoi(argv[3]);
    pop_undo_keep_selection(redo, set_modify); /* issue 0007: keep selection across undo */
    return TCL_OK;
  }
  return TCL_ERROR; /* unreachable: perform_action is only wired for the verbs above */
}

/* core_log_action -- the per-verb LOG-FORM half of the perform_action boundary (audit §4,
 * Refactor A step-2 "log at the core" registry SEED, introduced by atom 6). Formats the ONE
 * self-log line for a migrated verb. The bare no-arg verbs (trim_wires/align/rotate_in_place/
 * flip_in_place/flipv_in_place/floaters_from_selected_inst/toggle_ignore/show_unconnected_pins/delete/
 * clear_drawing/redo -- redo is atom 28, tolerant argc: the default arm ignores argv, so
 * `xschem redo extra` still logs the byte-identical bare line) emit `xschem <verb>`
 * byte-identically to the pre-atom-6 `log_action("xschem %s", verb)`; check_unique_names (atom 26)
 * emits the FIXED literal `xschem check_unique_names 1` (only mode 1 crosses the boundary -- the
 * mode-0 logged-query line lives raw-front in the branch + the '#' key, audit §46); undo (atom 29)
 * has the NORMALIZING integer-pair arm (bare `xschem undo` at argc==2, atoi-canonical
 * default-filled tail-dropped `xschem undo %d %d` else -- argv read IDENTICALLY to run_core's
 * undo arm, byte-identical to the old branch's two forms); the arg-carrying pivot verbs rotate (atom 6), flip (atom 7) and
 * flipv (atom 8) emit their pivot form `xschem rotate|flip|flipv <x0> <y0>`. The pivot is resolved
 * from argv[2]/argv[3] (or the mouse coords as a fallback) IDENTICALLY to run_core's rotate/flip/flipv
 * arm -- and run_core,
 * which perform_action runs FIRST, has already seeded xctx->mousex_snap = x0, so even the
 * mouse-fallback path logs exactly the pivot the effect used (both read the same argv, or the same
 * seeded coord). This dispatcher is the minimal first form of the global registry; after atom 8 all
 * three pivot forms (rotate/flip/flipv) plus the bare verbs are here. Do NOT reorder perform_action to log
 * before running the effect: the fallback path
 * depends on run_core seeding mousex_snap first. */
static void core_log_action(const char *verb, int argc, const char *argv[])
{
  if(!strcmp(verb, "rotate")) {
    /* The logged pivot is the EFFECTIVE coordinate (doc/claude/specs/select_at.md):
     * the mouse-fallback path is mousex_snap, already grid-snapped by the callback
     * (my_round(mousex/cadsnap)*cadsnap) -- routing it through snap_to_grid() is
     * idempotent but normalizes -0 and, with %.10g, strips the residual float noise
     * %.16g re-leaked (242.99999999999997 -> 243). The explicit-arg path stays
     * verbatim (atof of argv, NOT snapped): a scripted `rotate 100 40` must replay
     * byte-identically. %.10g is exact for real inputs (<=10 sig figs). */
    double x0 = snap_to_grid(xctx->mousex_snap), y0 = snap_to_grid(xctx->mousey_snap);
    if(argc > 3) { x0 = atof(argv[2]); y0 = atof(argv[3]); }
    log_action("xschem rotate %.10g %.10g", x0, y0);
  } else if(!strcmp(verb, "flip")) {
    /* atom 7: the SECOND arg-carrying verb, mirror of rotate. Same pivot resolution
     * (argv[2]/argv[3] else the mouse coord run_core just seeded) AND same effective-
     * coordinate rule (snap_to_grid + %.10g on the mouse path, verbatim atof on the
     * explicit-arg path -- see rotate above), so the logged `xschem flip x0 y0`
     * always matches the applied mirror. NB the literal `flip %` (flip+space+%) does
     * NOT match `flipv %` or `flip_in_place` -- flipv keeps its bare-verb `xschem %s`
     * form until its own atom. */
    double x0 = snap_to_grid(xctx->mousex_snap), y0 = snap_to_grid(xctx->mousey_snap);
    if(argc > 3) { x0 = atof(argv[2]); y0 = atof(argv[3]); }
    log_action("xschem flip %.10g %.10g", x0, y0);
  } else if(!strcmp(verb, "flipv")) {
    /* atom 8: the THIRD and LAST arg-carrying pivot verb, mirror of flip. Same pivot
     * resolution (argv[2]/argv[3] else the mouse coord run_core just seeded) AND same
     * effective-coordinate rule (snap_to_grid + %.10g on the mouse path, verbatim atof
     * on the explicit-arg path -- see rotate above), so the logged `xschem flipv x0 y0`
     * always matches the applied vertical mirror. NB the literal `flipv %`
     * (flipv+space+%) does NOT match `flip %` (a `v` intervenes before the space) nor
     * `flipv_in_place` -- the three are counted independently. */
    double x0 = snap_to_grid(xctx->mousex_snap), y0 = snap_to_grid(xctx->mousey_snap);
    if(argc > 3) { x0 = atof(argv[2]); y0 = atof(argv[3]); }
    log_action("xschem flipv %.10g %.10g", x0, y0);
  } else if(!strcmp(verb, "break_wires")) {
    /* atom 9: the FIRST NON-transform verb, and the FIRST whose arg is a FLAG (0/1)
     * rather than a coordinate pivot. `remove` is read from argv[2] IDENTICALLY to
     * run_core's break_wires arm, and canonicalized to the two forms the UI emits:
     * `xschem break_wires 1` (split-and-remove) vs bare `xschem break_wires` (split).
     * break_wires_at_pins() reads remove as a BOOLEAN, so any non-zero argv[2] logs
     * the canonical `1` form -> a deterministic, faithful replay. NB the literals
     * `break_wires 1"` and `break_wires")` are counted independently by the grep guard
     * (S7) so a re-scattered branch log of EITHER form fails closed; neither matches
     * break_wires_at_pins / break_wires_at_point / break_wires_at_attach_points. */
    int remove = 0;
    if(argc > 2) remove = atoi(argv[2]);
    if(remove) log_action("xschem break_wires 1");
    else       log_action("xschem break_wires");
  } else if(!strcmp(verb, "attach_labels")) {
    /* atom 11: the arg is a FLAG `interactive` (default 0) read from argv[2]
     * IDENTICALLY to run_core's attach_labels arm -- so the logged form always
     * matches the applied effect. UNLIKE break_wires (which canonicalizes any
     * nonzero to `1`), attach_labels's 0/1/2 carry DISTINCT meanings (0 = place
     * lab_pin, 1 = interactive dialog, 2 = netlisting lab_show mode), so the actual
     * value is PRESERVED with `%d`, not collapsed. For the canonical decimal-integer
     * arg every live path emits (`xschem attach_labels` argc==2 / `xschem attach_labels
     * <n>` argc>2) this is byte-identical to the old `log_action_argv(argc, argv)`; for a
     * non-canonical or multi-token argv (`007`, `+2`, `2 foo`) the `%d` form logs exactly
     * the value the effect's atoi consumed -- strictly MORE faithful than the raw-token
     * log_action_argv, never a divergence from the applied effect (the atom-9 rule). The
     * literal `attach_labels %` (space+%) and `attach_labels")` (quote+paren) are
     * counted independently by the grep guard (S7). */
    if(argc > 2) log_action("xschem attach_labels %d", atoi(argv[2]));
    else         log_action("xschem attach_labels");
  } else if(!strcmp(verb, "reset_inst_prop")) {
    /* atom 13: the arg is the instance REFERENT argv[2] (a name or a numeric index),
     * read IDENTICALLY to run_core's reset_inst_prop arm -- so the logged
     * `xschem reset_inst_prop <ref>` self-contained line always names exactly the
     * instance the effect reset (SELECTION-INDEPENDENT: the referent is in the line,
     * not the current selection; replay re-resolves it via get_instance). This arm is
     * reached ONLY on TCL_OK (perform_action gates core_log_action on success, atom 13),
     * and run_core returns TCL_OK only after `argc<3` passed -- so argv[2] is always
     * present here; a failed validation logs NOTHING.
     * The referent is emitted via log_action_argv (Tcl_Merge), NOT a raw `%s` -- an
     * arrayed/bussed instance name carries Tcl metacharacters (a real shipped case is
     * `x2[3:0]`), and a raw `xschem reset_inst_prop x2[3:0]` line would replay `[3:0]` as
     * a command substitution ("invalid command name 3:0"). Tcl_Merge brace-quotes it to
     * `xschem reset_inst_prop {x2[3:0]}`, which replays back to the same argv[2]. Tcl_Merge
     * quotes MINIMALLY, so a plain refdes (R1) logs byte-identically to `xschem
     * reset_inst_prop R1`. This is the issue-0048 replay-safe name pattern (adversarial
     * review of this atom flagged the raw-%s replay gap; the sibling `descend -inst %s`
     * shares the latent gap and is left for its own change). */
    const char *av[3];
    av[0] = "xschem"; av[1] = verb; av[2] = argv[2];
    log_action_argv(3, av);
  } else if(!strcmp(verb, "reset_symbol")) {
    /* atom 22: TWO referents -- the instance referent argv[2] (a name or numeric index) AND
     * the symbol reference argv[3] -- read IDENTICALLY to run_core's reset_symbol arm, so the
     * logged `xschem reset_symbol <inst> <symref>` self-contained line always names exactly the
     * instance the effect remapped and the symbol it pointed at (SELECTION-INDEPENDENT: replay
     * re-resolves argv[2] via get_instance). BOTH referents can carry Tcl metacharacters -- an
     * arrayed/bussed instance name (`x2[3:0]`), a symref path with a space or bracket -- so BOTH
     * are emitted via log_action_argv (Tcl_Merge), NOT a raw `%s`: a raw `x2[3:0]` would replay
     * `[3:0]` as a command substitution (the atom-13 issue-0048 replay-safe lesson). Tcl_Merge
     * quotes MINIMALLY, so a plain refdes+path logs byte-identically to `xschem reset_symbol R1
     * devices/res.sym`. The array is named `rs` (NOT av/ev/pp/mi/im -- the §36 collision lesson)
     * so its build/emit lines stay TEXTUALLY DISTINCT from every sibling's; a shared name would
     * make each verb's count == 2, failing the exclusivity rows. Reached ONLY on TCL_OK
     * (log-on-success), and run_core returns TCL_OK only after the argc!=4 + "instance not found"
     * gates passed, so argv[2]/argv[3] are always present here; a failed validation logs nothing. */
    const char *rs[4];
    rs[0] = "xschem"; rs[1] = verb; rs[2] = argv[2]; rs[3] = argv[3];
    log_action_argv(4, rs);
  } else if(!strcmp(verb, "replace_symbol")) {
    /* atom 14: the SECOND validating verb, and the FIRST per-verb log form to carry a
     * FAST-FLAG GATE. The log is the SELF-CONTAINED `xschem replace_symbol <inst> <sym>`:
     * BOTH the instance referent argv[2] (a name or numeric index) AND the symbol path
     * argv[3] can carry Tcl metacharacters (an arrayed name `x2[3:0]`, a path with a
     * space/bracket), so BOTH are emitted via log_action_argv (Tcl_Merge), NOT a raw `%s`
     * -- the atom-13 arrayed-name replay lesson (a raw `x2[3:0]` would replay `[3:0]` as a
     * command substitution). Tcl_Merge quotes MINIMALLY, so a plain refdes + path logs
     * byte-identically to `xschem replace_symbol R1 devices/capa.sym`. Reached ONLY on
     * TCL_OK (log-on-success), so a failed validation logs nothing. GATED on !fast: the
     * fast form (argc>4 && argv[4]=="fast") is a multi-substitution machinery sub-mode
     * that skips undo and MUST NOT be logged (the atom-4 save-fast axis); the argv reads
     * here are IDENTICAL to run_core's, so the logged line can never diverge from the
     * applied swap. NB run_core clamps its OWN local argc to 4, but core_log_action gets
     * the ORIGINAL argc from perform_action, so the fast test reads the untouched argv. */
    if(argc <= 4 || strcmp(argv[4], "fast")) {
      const char *av[4];
      av[0] = "xschem"; av[1] = verb; av[2] = argv[2]; av[3] = argv[3];
      log_action_argv(4, av);
    }
  } else if(!strcmp(verb, "embed_rawfile")) {
    /* atom 16: the arg is the RAW file-path referent argv[2] (a `~/...`, absolute or
     * relative path), read here NOT the expanded form run_core derives -- so the logged
     * `xschem embed_rawfile <path>` re-expands the `~/` IDENTICALLY on replay (arg-fidelity:
     * run_core derives f from argv[2], replay re-derives it). Emitted via log_action_argv
     * (Tcl_Merge), NOT a raw %s -- a path with a space/bracket/brace carries Tcl
     * metacharacters (`sim [1].raw`) and a raw line would misparse on replay; Tcl_Merge
     * brace-quotes it minimally (a plain path logs unbraced) -- the atom-13 replay-safe
     * referent lesson. Reached ONLY on TCL_OK (log-on-success), and run_core returns TCL_OK
     * only after the argc<3 gate passed, so argv[2] is always present here. The array is
     * named `ev` (not `av`) so this build line stays TEXTUALLY DISTINCT from
     * reset_inst_prop's byte-identical `av[...]` build -- the grep guard line-anchors both,
     * and a shared name would make each verb's count == 2, failing the exclusivity rows. */
    const char *ev[3];
    ev[0] = "xschem"; ev[1] = verb; ev[2] = argv[2];
    log_action_argv(3, ev);
  } else if(!strcmp(verb, "wire_cut")) {
    /* atom 17: a numeric COORD + bareword-FLAG log -- NOT log_action_argv (the coords are
     * numeric, there is no Tcl metacharacter referent to brace-quote). TWO forms like
     * break_wires (atom 9): the aligned `xschem wire_cut x y` and the `xschem wire_cut x y
     * noalign`. Unlike the pivot verbs (rotate/flip snap the mouse coord + %.10g), wire_cut
     * KEEPS %.16g and logs the RAW click coords argv[2]/argv[3] (NOT the snapped point
     * break_wires_at_point computes): `align` is applied
     * INSIDE the core (closest_point_calculation), so raw-coords + the flag replay IDENTICALLY
     * (replay re-snaps to the same point). `align` is read here with the SAME loop as run_core's
     * wire_cut arm, so the logged form can never diverge from the applied cut. Reached ONLY on
     * TCL_OK (log-on-success) and only via the branch's argc>3 guard, so argv[2]/argv[3] are
     * always present. NB the literal `wire_cut %` matches BOTH forms (the S7 total == 2), while
     * `wire_cut %.16g %.16g noalign` (space+noalign before the quote) is DISTINCT from the
     * aligned `wire_cut %.16g %.16g"` (quote-terminated) -- counted independently by the grep
     * guard; and neither matches break_wires_at_point / _at_pins / _at_attach_points (an `_`
     * follows). C89: decls at block top. */
    int i, align = 1;
    for(i = 2; i < argc; i++) if(!strcmp(argv[i], "noalign")) align = 0;
    if(align) log_action("xschem wire_cut %.16g %.16g", atof(argv[2]), atof(argv[3]));
    else      log_action("xschem wire_cut %.16g %.16g noalign", atof(argv[2]), atof(argv[3]));
  } else if(!strcmp(verb, "apply_pin_prop")) {
    /* atom 18: TWO referents like replace_symbol (§34), read IDENTICALLY to run_core's arm so the
     * logged line can never diverge from the applied change. TWO forms mirror the branch's arg
     * resolution: argc>=4 -> `xschem apply_pin_prop <scope> <prop>`, argc==3 -> the back-compat
     * `xschem apply_pin_prop <prop>` (default "selected" scope). BOTH are emitted via log_action_argv
     * (Tcl_Merge), NOT a raw %s: <prop> is a full pin-attribute string carrying spaces + brackets +
     * possibly braces (name=X dir=in name_dx=20 ... foo=a[1]) -- a raw line would misparse on replay;
     * <scope> is a bareword (current|selected|all) that Tcl_Merge logs unbraced (minimal quoting), so
     * a plain form logs byte-identically. The array is named `pp` (NOT av/ev -- the §36 collision
     * lesson) so its build/emit lines stay TEXTUALLY DISTINCT from reset_inst_prop's `av`, embed's
     * `ev`, and replace_symbol's `av[3]`. Reached ONLY on TCL_OK (log-on-success), so the argc<3
     * validation failure logs nothing. NB the argc==3 back-compat form replays against the CURRENT
     * selection ("selected" scope) -- the accepted selection-dependent replay class (0005), same as
     * floaters/attach_labels; the resolved pin set is deliberately NOT baked into the line. */
    if(argc >= 4) {
      const char *pp[4];
      pp[0] = "xschem"; pp[1] = verb; pp[2] = argv[2]; pp[3] = argv[3];
      log_action_argv(4, pp);
    } else {
      const char *pp[3];
      pp[0] = "xschem"; pp[1] = verb; pp[2] = argv[2];
      log_action_argv(3, pp);
    }
  } else if(!strcmp(verb, "move_instance")) {
    /* atom 19: the FAITHFUL FULL-CALL log `xschem move_instance <inst> <x> <y> <rot> <flip>
     * [nodraw] [noundo]`. Emitted via log_action_argv (Tcl_Merge), NOT a raw %s: the instance
     * referent argv[2] can carry Tcl metacharacters (an arrayed/bussed name `x2[3:0]`), and a raw
     * line would replay `[3:0]` as a command substitution -- the §33 replay-safe lesson. Tcl_Merge
     * quotes MINIMALLY, so a plain refdes + numeric coords log byte-identically to
     * `xschem move_instance R1 100 40 90 0`, while the dashes (`-`, keep-existing) and any braced
     * name round-trip exactly.
     *
     * THE noundo/nodraw LOG DECISION (the load-bearing design call, resolved from the callers). Both
     * flags are LOGGED FAITHFULLY -- the wire_cut `noalign` approach (§37), NOT the replace_symbol
     * `fast` gate (§34). `fast` is a MULTI-substitution machinery sub-mode: replace_symbol is called
     * as an internal sub-step of a larger logged op, so logging each `fast` call would DOUBLE-log ->
     * it must be gated OUT of the log. move_instance has NO such internal caller -- it is a PURE
     * SCRIPTED verb (grep-verified: no key/menu/palette/callback/C/Tcl caller anywhere), so nodraw/
     * noundo are just faithful user args: a user who scripts `move_instance ... noundo` wants the
     * replay to reproduce it (no undo slot on replay), exactly as they typed it. So they are logged,
     * not gated. The flags are read here with the SAME loop as run_core's arm, so the logged form can
     * never diverge from the applied effect, and are re-emitted in a CANONICAL order (nodraw before
     * noundo) regardless of the input order -- the effect is order-independent (both are booleans),
     * so the canonical line replays to the identical effect (the atom-9/-11 "log the value the effect
     * consumed" rule).
     *
     * The array is named `mi` (NOT av/ev/pp/av[3] -- the §36 collision lesson) so its build/emit lines
     * stay TEXTUALLY DISTINCT, and it is a FRESH build (NOT the bare `log_action_argv(argc, argv)`
     * form, which recurs at three other scheduler.c sites -- add_pin_stubs/paste/... -- and could not
     * be grep-pinned uniquely). `mi[9]` is sized for the max canonical call (xschem, move_instance,
     * inst, x, y, rot, flip, nodraw, noundo = 9), and k never exceeds it. Reached ONLY on TCL_OK
     * (log-on-success) and only after the argc<7 gate passed, so argv[2..6] are always present here;
     * a failed validation logs NOTHING. C89: decls at block top. */
    const char *mi[9];
    int i, k = 0, undo = 1, dr = 1;
    for(i = 7; i < argc; i++) {
      if(!strcmp(argv[i], "nodraw")) dr = 0;
      if(!strcmp(argv[i], "noundo")) undo = 0;
    }
    mi[k++] = "xschem"; mi[k++] = verb;
    mi[k++] = argv[2]; mi[k++] = argv[3]; mi[k++] = argv[4]; mi[k++] = argv[5]; mi[k++] = argv[6];
    if(!dr)   mi[k++] = "nodraw";
    if(!undo) mi[k++] = "noundo";
    log_action_argv(k, mi);
#if HAS_CAIRO==1
  } else if(!strcmp(verb, "image")) {
    /* atom 20: the FAITHFUL RAW full-call log `xschem image <flag> [<flag>...]`. Unlike the
     * fixed-arity mi[9]/pp[4]/av[3]/ev[3] arms, the flag COUNT is variable (1..8), so the array is
     * sized to argc: the `xschem`/verb prefix is hardcoded (im[0]/im[1], the sibling idiom) and the
     * flag tail argv[2..] is copied VERBATIM. RAW, NOT canonical-from-`what`: an unrecognized flag
     * word yields what==0, and a canonical rebuild would collapse that no-op to a bare `xschem image`
     * that REPLAYS as "Missing arguments" -- the raw echo round-trips the same no-op instead. Any
     * recognized-flag call replays to the identical `what` regardless of order/dupes. The flags are
     * barewords (no Tcl metacharacter), so log_action_argv/Tcl_Merge logs them unbraced ==
     * byte-identical to the typed call. A fresh heap array named `im` (NOT the bare
     * `log_action_argv(argc, argv)` form that recurs at three other scheduler.c sites, NOR av/ev/pp/mi
     * -- the §36 collision lesson) keeps the build+emit grep-pinnable. Reached only on TCL_OK
     * (log-on-success) and only past the branch's argc>=3 + non-help guard, so argv[2] is always
     * present (argc>=3 -> im[0]/im[1] always valid). C89: decls at block top. */
    const char **im = my_malloc(_ALLOC_ID_, (size_t)argc * sizeof(char *));
    int j;
    im[0] = "xschem"; im[1] = verb;
    for(j = 2; j < argc; j++) im[j] = argv[j];
    log_action_argv(argc, im);
    my_free(_ALLOC_ID_, &im);
#endif
  } else if(!strcmp(verb, "change_elem_order")) {
    /* atom 21: the arg is a value-carrying integer `n` read from argv[2] IDENTICALLY to run_core's
     * change_elem_order arm -- so the logged `xschem change_elem_order %d` always matches the applied
     * reorder. VALUE-PRESERVING with %d like attach_labels (atom 11), NOT collapsed like break_wires
     * (atom 9): n is a position index whose exact value matters, and the branch logged the RAW n
     * (before change_elem_order's internal clamp to instances-1), so replay re-clamps identically --
     * log the value the user gave. It is a bare integer (no Tcl metacharacter), so
     * log_action("...%d", atoi(argv[2])) is the right form (the attach_labels/break_wires template),
     * NOT log_action_argv -- there is no referent to brace-quote, hence no av/ev/pp/mi/im array and no
     * §36 collision. SINGLE form (no bare variant): the arg is REQUIRED (run_core's argc<3 gate is an
     * early TCL_ERROR), so unlike attach_labels/break_wires there is no argc==2 bare line. Reached
     * ONLY on TCL_OK (log-on-success) and only past run_core's argc<3 gate, so argv[2] is always
     * present. The literal `change_elem_order %d` is UNIQUE (no other verb shares the prefix).
     *
     * THE had_sel LOG GATE (`if(xctx->lastsel)`): this verb PRESERVES the pre-migration had_sel gate
     * rather than taking the §30 no-op-still-logs alignment -- a DELIBERATE per-verb exception (like
     * replace_symbol's `fast` gate). §30 was REJECTED here because change_elem_order is SELECTION-
     * DEPENDENT (0005 class) AND its core keeps the reordered object SELECTED (the array swap in
     * editprop.c moves the .sel bit): a phantom empty-selection line would, on a whole-log replay
     * where an intervening interactive deselect was NOT logged, find that object STILL selected and
     * REORDER it -- a silent z-order divergence (adversarial-review MAJOR). The old branch/key gated
     * the log on `had_sel = xctx->lastsel` taken BEFORE change_elem_order; change_elem_order() rebuilds
     * the selection itself (run just now in run_core) and its swap does not change the COUNT, so
     * xctx->lastsel here == that had_sel EXACTLY (0 = nothing selected -> skip the log; 1 or >1 ->
     * log, matching the branch which logged even the multi-select no-op). Reading xctx state in
     * core_log_action is the rotate/flip mousex_snap precedent -- run_core (which perform_action runs
     * FIRST) has already established it. This locks test_selflog_output.tcl:190
     * `change_elem_order (no sel) is nolog`. INVARIANT this equality relies on (adversarial-review
     * note): NOTHING mutates xctx->lastsel between the effect and this log -- perform_action runs
     * run_core then core_log_action back-to-back with only the rc/suppress checks between, and neither
     * change_elem_order's push_undo/set_modify nor its post-entry work touches the selection COUNT (it
     * rebuilds ONCE at entry and its swap moves the .sel bit with the struct). A future selection-
     * mutating step added inside change_elem_order after that entry rebuild, or between the effect and
     * this log, would break had_sel == lastsel and must re-capture the count explicitly. */
    if(xctx->lastsel) log_action("xschem change_elem_order %d", atoi(argv[2]));
  } else if(!strcmp(verb, "instance_number")) {
    /* atom 23: TWO referents -- the instance referent argv[2] (a name or numeric index) AND the
     * target position n argv[3] (a bareword integer) -- read IDENTICALLY to run_core's
     * instance_number arm, so the logged `xschem instance_number <inst> <n>` self-contained line
     * always names exactly the instance the effect reordered and the position it moved to. BOTH
     * are emitted via log_action_argv (Tcl_Merge), NOT a raw `%s`: the instance name can carry Tcl
     * metacharacters (an arrayed/bussed name `x2[3:0]`), and a raw line would replay `[3:0]` as a
     * command substitution (the atom-13 issue-0048 replay-safe lesson); n is a bareword integer
     * that Tcl_Merge logs unbraced. Tcl_Merge quotes MINIMALLY, so a plain refdes logs
     * byte-identically to `xschem instance_number R1 3`. The array is named `ino` (av/ev/pp/mi/im/
     * rs + replace_symbol's av[3] all taken -- the §36 collision lesson) so its build/emit stay
     * TEXTUALLY DISTINCT from every sibling.
     *
     * NO had_sel GATE (a replay ADVANTAGE over change_elem_order, atom 21): instance_number's
     * mutate is SELF-CONTAINED -- run_core did unselect_all + select_element(argv[2]) itself, so
     * the log is UNCONDITIONAL on success (the selection is always the one it just made, never
     * ambient; no phantom-line/0005 class). Reached ONLY on TCL_OK (log-on-success), and only via
     * the branch's argc>3 delegation past run_core's gates, so argv[2]/argv[3] are always present. */
    const char *ino[4];
    ino[0] = "xschem"; ino[1] = verb; ino[2] = argv[2]; ino[3] = argv[3];
    log_action_argv(4, ino);
  } else if(!strcmp(verb, "add_pin_stubs")) {
    /* atom 25: the FAITHFUL RAW full-call log `xschem add_pin_stubs [-prefix <s>] [-suffix <s>]
     * [-inst-prefix]`. The flag COUNT is variable (0..5 tail words), so the array is sized to argc and
     * the flag tail argv[2..] is copied VERBATIM -- the image im[] template (atom 20), NOT the fixed-
     * arity av/pp/mi arms. The `xschem`/verb prefix is hardcoded (aps[0]/aps[1], the sibling idiom).
     * A fresh heap array named `aps` (av/ev/pp/mi/im/rs/ino all taken -- the §36 collision lesson;
     * and NOT the bare `log_action_argv(argc, argv)` form the old branch used, which recurs at paste/...
     * and could not be grep-pinned uniquely). The flag words + their -prefix/-suffix VALUES may carry
     * Tcl metacharacters, so log_action_argv/Tcl_Merge brace-quotes minimally (a plain word logs
     * unbraced == byte-identical to the typed call). LOGGED UNCONDITIONALLY on TCL_OK -- option (c):
     * add_pin_stubs always returns TCL_OK (added==0 is a no-op success), so a no-op logs one idempotent
     * replayable line (the §30 floaters property); the old `if(added>0)` suppression is dropped. At
     * argc==2 (bare verb) the loop copies nothing and this logs `xschem add_pin_stubs`. C89: decls at
     * block top. */
    const char **aps = my_malloc(_ALLOC_ID_, (size_t)argc * sizeof(char *));
    int j;
    aps[0] = "xschem"; aps[1] = verb;
    for(j = 2; j < argc; j++) aps[j] = argv[j];
    log_action_argv(argc, aps);
    my_free(_ALLOC_ID_, &aps);
  } else if(!strcmp(verb, "check_unique_names")) {
    /* atom 26: FIXED literal -- only "1" ever crosses the boundary (the branch delegates solely
     * argv[2]=="1"; the Ctrl+# key passes a literal "1"), and the OLD branch log canonicalized
     * every call to "1"/"0" via its ?: -- so this literal is byte-identical to the pre-migration
     * log for every argc/argv shape that reaches it. No flag array, no F-flagarg machinery.
     * The mode-0 line is NOT here: it lives raw-front in the branch + the '#' key (the
     * asymmetric logged-query split, §46). */
    log_action("xschem check_unique_names 1");
  } else if(!strcmp(verb, "undo")) {
    /* atom 29: NORMALIZING arm -- byte-identical to the OLD branch's two log forms at every
     * argc/argv. argv is read IDENTICALLY to run_core's undo arm (same defaults, same atoi), so
     * the logged line can never diverge from the applied pop: `xschem undo 00 01` logs
     * `xschem undo 0 1` (atoi canonicalization), `xschem undo 1` logs `xschem undo 1 1`
     * (default fill -- replay preserves DIRECTION), `xschem undo 0 1 extra` logs
     * `xschem undo 0 1` (tail drop). A raw-argv passthrough would diverge on all three; the
     * default `%s` arm would flip `xschem undo 1 1` to a bare undo on replay -- a WRONG-direction
     * replay. Reached ONLY on TCL_OK (log-on-success); bareword ints, no Tcl metachars, so
     * log_action %d is replay-safe (no Tcl_Merge needed). */
    int redo = 0, set_modify = 1;
    if(argc > 2) redo = atoi(argv[2]);
    if(argc > 3) set_modify = atoi(argv[3]);
    if(argc == 2) log_action("xschem undo");
    else          log_action("xschem undo %d %d", redo, set_modify);
  } else {
    log_action("xschem %s", verb);
  }
}

/* perform_action -- the single mutation/command boundary (Refactor B, audit §4).
 * Every entry point that reaches a migrated verb -- the scheduler branch, the
 * inline legacy-switch key, the menu/toolbar (which reach the branch via
 * `xschem <verb>`) -- calls THIS instead of duplicating a readonly check + the
 * effect + a log_action. That collapses the four-edge coverage problem (§3.1) to
 * one edge and makes "did we readonly-check it?" and "did we log it?" structural
 * invariants rather than per-path checklist items (it also unifies the scattered
 * 0041/0051 read-only gates). ONE readonly gate + ONE effect + ONE log site.
 * The log site is gated on !actionlog_suppress -- the re-entrant depth counter
 * from the Refactor B foundation -- so a replayed / composite re-execution re-runs
 * the effect but does not re-log (log_action also honors the gate internally;
 * the explicit check documents the boundary contract). The log line's SHAPE comes
 * from core_log_action(verb, argc, argv) (atom 6): bare verbs -> `xschem <verb>`,
 * the arg-carrying rotate -> `xschem rotate <x0> <y0>`. Effect THEN log, always:
 * core_log_action's mouse-fallback pivot reads the coord run_core just seeded.
 * Uses the global interp.
 *
 * LOG-ON-SUCCESS (Refactor B atom 13 -- the FIRST shared-machinery change): the log
 * site AND the interp reset fire ONLY on rc == TCL_OK. This lets a VALIDATING verb --
 * one whose run_core rejects a bad argument/precondition with Tcl_SetResult(...) +
 * return TCL_ERROR *before* mutating (reset_inst_prop's `argc<3` / "instance not
 * found", and the whole replace_symbol/load_backup/reset_symbol class it unblocks) --
 * live on the boundary without being PHANTOM-logged: a rejected call records no
 * replayable line. The guard MUST NOT be split from the Tcl_ResetResult: on the
 * TCL_ERROR path run_core's error message must survive to the caller, so the reset is
 * skipped on failure (resetting unconditionally here would blank the message -- the
 * known C-side empty-error bug). The readonly early return above already keeps its own
 * message for the same reason. INVARIANT: every verb already on the boundary returns
 * TCL_OK on BOTH its success AND its no-op path (floaters nothing-selected,
 * toggle_ignore attr==NULL) -- so log-on-success drops no existing log and PRESERVES
 * the no-op-still-logs property (§30/§32); a no-op is a SUCCESS, not a failure. */
int perform_action(const char *verb, int argc, const char *argv[])
{
  int rc;
  if(!xctx) { Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR; }
  if(scheduler_readonly_reject(interp, verb)) return TCL_ERROR;   /* ONE readonly gate */
  rc = run_core(verb, argc, argv);                                /* the effect */
  if(rc == TCL_OK) {   /* LOG-ON-SUCCESS + success-only reset (Refactor B atom 13) */
    if(!actionlog_suppress) core_log_action(verb, argc, argv);    /* ONE log site (per-verb form) */
    Tcl_ResetResult(interp);   /* clear on success ONLY -- preserve run_core's error message on TCL_ERROR */
  }
  return rc;
}

/* Shared setup for the symbol-editor pin-scope commands (apply_pin_prop /
 * pin_scope_prop_uniform): rebuild the selection, find the primary pin (sel_array[0] iff it
 * is a PINLAYER rect, else -1), and resolve <scope> into a freshly my_malloc'd targets[]
 * (caller frees). Returns the target count; *primary_out and *targets_out are always written.
 * Keeps the two commands' resolver in lockstep so the greyed set == the applied set. */
static int pin_scope_resolve(const char *scope, int *primary_out, int **targets_out)
{
  int primary = -1, *targets;
  rebuild_selected_array();
  if(xctx->lastsel > 0 && xctx->sel_array[0].type == xRECT &&
     xctx->sel_array[0].col == PINLAYER) primary = xctx->sel_array[0].n;
  targets = my_malloc(_ALLOC_ID_, (xctx->rects[PINLAYER] + 1) * sizeof(int));
  *primary_out = primary;
  *targets_out = targets;
  return pin_scope_targets(primary, scope, targets);
}

/* `xschem a...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 1). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_a(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* abort_operation
     *   Resets UI state, unselect all and abort any pending operation.
     *   `xschem abort_operation [keepsel]`: with keepsel!=0 the current selection is
     *   kept (redraw only); default (or 0) is legacy deselect-all. */
    if(!strcmp(argv[1], "abort_operation"))
    {
      int deselect = 1;
      if(argc > 2) deselect = !atoi(argv[2]);
      abort_operation(deselect);
    }

    /* activate_window <xid>
     *   Ask the WM to raise to the front + focus the top-level X window 'xid' (a hex id
     *   from Tcl `winfo id`) via EWMH _NET_ACTIVE_WINDOW. Raises WITHOUT re-mapping or
     *   moving the window, so there is no position drift (issue 0054). A no-op without X
     *   or on a WM that does not honor the hint. */
    else if(!strcmp(argv[1], "activate_window"))
    {
      if(has_x && argc > 2) {
        net_active_window((Window) strtoul(argv[2], NULL, 0));
      }
    }

    /* allocate_window_number
     *   Hand out the next Cadence-style window number and advance the shared counter
     *   (doc/claude/specs/window_numbering.md) -- the same monotonic, never-reused
     *   sequence the editor birth sites consume via assign_window_number(). Lets
     *   non-editor toplevels built in Tcl (the ASE-L session window,
     *   doc/claude/specs/ase_l.md) claim a collision-free number. A verb, not a
     *   `get`: it MUTATES the counter. */
    else if(!strcmp(argv[1], "allocate_window_number"))
    {
      Tcl_SetResult(interp, my_itoa(allocate_window_number()), TCL_VOLATILE);
    }

    /* apply_properties scope displayed_id new_prop old_prop [keep_name]
     *   Mid-session apply for the slick property form (P2 Apply / OK). Fans the
     *   change set (new_prop vs old_prop, changed-fields-only) to the instances
     *   named by 'scope' (current|selected|all) relative to the displayed
     *   instance, given by its session-stable id (see `xschem instance_id`).
     *   keep_name (optional, default 0): preserve the instance name across a source
     *   change instead of re-prefixing it (issue 0058) -- passed in the logged command
     *   so replay is faithful. Pushes one undo; returns 1 if anything changed, 0 for a
     *   legit no-op, -1 if the displayed instance no longer exists (issue 0042). */
    else if(!strcmp(argv[1], "apply_properties"))
    {
      int modified, keep_name = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "apply_properties")) return TCL_ERROR;
      if(argc < 6) {
        Tcl_SetResult(interp,
          "xschem apply_properties needs: scope displayed_id new_prop old_prop [keep_name]", TCL_STATIC);
        return TCL_ERROR;
      }
      if(argc > 6) keep_name = atoi(argv[6]);
      modified = apply_instance_properties(argv[2],
                   (unsigned int)strtoul(argv[3], NULL, 10), argv[4], argv[5], keep_name);
      /* -1 = target vanished (issue 0042); the Tcl form surfaces it instead of closing. */
      Tcl_SetResult(interp, modified < 0 ? "-1" : (modified ? "1" : "0"), TCL_STATIC);
    }

    /* apply_pin_prop [<scope>] <prop>
     *   Apply <prop> to the symbol pins (PINLAYER rects) named by <scope>, mirroring the pin
     *   branch of edit_rect_property but WITHOUT a dialog round-trip, so the pin/pinname
     *   property forms can offer a live "Apply" (cadence_pin_name_text.md; scope =
     *   symbol_editor_apply_scope.md). <scope> = current | selected | all (default "selected").
     * Routes through the single mutation boundary (Refactor B atom 18 -- a HIGHER-FRICTION
     * coverage gain now the friction-free pool is EMPTY; the replace_symbol §34 two-referent
     * VALIDATING template crossed with the reset_inst_prop §33 argc-gate): the readonly gate,
     * the argc<3 "needs: [scope] new_prop" validation, the guard-pass no-op, the SINGLE
     * push_undo + the inline apply loop (set_different_token/pin_reorient/pin_view_apply), and
     * the ONE `xschem apply_pin_prop [<scope>] <prop>` log site (via core_log_action, both
     * referents Tcl_Merge-quoted, LOGGED ONLY ON SUCCESS) all live in perform_action/run_core.
     * The mutation body is INLINE (not a shared C fn) so it is strictly 1:1 with the verb (C3);
     * pin_scope_resolve() is a SHARED read-only resolver that stays RAW below the boundary. The
     * boundary ADDS the C-level read-only gate the scripted verb NEVER HAD (a correctness fix --
     * the old scripted form mutated a read-only symbol view); the old success-path "0"/"1" interp
     * result is dropped (the boundary clears the interp on success -- gfxform::do_apply discards
     * it, and the two standalone tests were switched to assert the effect). No scattered
     * readonly/log/push_undo here. */
    else if(!strcmp(argv[1], "apply_pin_prop"))
      return perform_action("apply_pin_prop", argc, argv);

    /* add_symbol_pin [x y name dir [draw [noline]]]
     *   place a symbol pin.
     *   x,y : pin coordinates
     *   name = pin name
     *   dir = in|out|inout
     *   draw: 1 | 0 (draw or not the added pin immediately, default = 1)
     *   noline: 0 | 1 (default 0). 1 -> do NOT store/draw the 20-unit stub leg line.
     *     The interactive `-place` drop stores only the rect + owned name view (no
     *     leg); this arg lets the action-log replay form (`end_move_copy_logged`,
     *     issue 0069 sympin atom 11) reproduce that exact geometry.
     *   if no parameters given start a GUI placement of a symbol pin */
    else if(!strcmp(argv[1], "add_symbol_pin"))
    {
      int save, draw = 1, noline = 0, linecol = SYMLAYER;
      double x = xctx->mousex_snap;
      double y = xctx->mousey_snap;
      const char *name = NULL;
      const char *dir = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "add_symbol_pin")) return TCL_ERROR;
      if(argc > 6) draw = atoi(argv[6]);
      if(argc > 7) noline = atoi(argv[7]);
      if(argc > 5) {
        int flip = 0, ri;
        xctx->push_undo();
        x = atof(argv[2]);
        y = atof(argv[3]);
        name = argv[4];
        dir = argv[5];
        if(!strcmp(dir, "inout") || !strcmp(dir, "out") ) flip = 1;
        if(!strcmp(dir, "inout")) linecol = 7;
        /* pin rect + owned name view (Option B); replaces the old rect + standalone T */
        ri = create_pin(x, y, name, dir, 0);
        if(noline) {
          /* replay of a `-place` sympin drop (issue 0069 atom 11): the interactive
           * drop MOVES the pin, and in a symbol view the move syncs the name view's
           * geometry back into the pin's name_* tokens (pin_view_writeback ->
           * name_rot/name_flip), while this raw form would store a 20-unit stub leg
           * line the drop never did. Reproduce the drop exactly: skip the leg line
           * and, under the SAME symbol-view condition the move-time sync uses
           * (actions.c pin-view writeback loop), write the tokens back -> the replay
           * saves byte-identically to the drop. */
          if(xctx->netlist_type == CAD_SYMBOL_ATTRS) {
            int vi = (ri >= 0) ? pin_name_view_of(xctx->rect[PINLAYER][ri].id) : -1;
            if(vi >= 0) pin_view_writeback(vi);
          }
        } else {
          if(flip) {
            storeobject(-1, x - 20, y, x, y, LINE, linecol, 0, NULL);
          } else {
            storeobject(-1, x, y, x + 20, y, LINE, linecol, 0, NULL);
          }
        }

        if(draw) {
          save = xctx->draw_window; xctx->draw_window = 1;
          drawrect(PINLAYER, NOW, x - 2.5, y - 2.5, x + 2.5, y + 2.5, 0.0, 0, -1, -1);
          filledrect(PINLAYER,NOW, x - 2.5, y - 2.5, x + 2.5, y + 2.5, 1, -1, -1);
          if(!noline) {
            if(flip) {
              drawline(linecol, NOW, x -20, y, x, y, 0.0, 0, NULL);
            } else {
              drawline(linecol, NOW, x, y, x + 20, y, 0.0, 0, NULL);
            }
          }
          xctx->draw_window = save;
        }
      } else if(argc == 3 && !strcmp(argv[2], "-place")) {
        /* Interactive, MODELESS placement driven by the Add-Pin dialog (addpin:: in
         * xschem.tcl): the dialog re-issues this command on every Name/Direction change so
         * the cursor preview tracks what the user typed. To keep undo clean across those
         * per-keystroke re-arms (cadence_pin_name_text.md item #3): push ONE baseline at the
         * first arm of a gesture (xctx->sympin_preview marks it active); each subsequent
         * re-arm drops the previous, undropped preview pin with NO undo, so the single
         * baseline is exactly what a later undo rolls back to. The drop (move_objects END,
         * START_SYMPIN -> no push) keeps that baseline; abort_operation removes an undropped
         * preview undo-free. The pin rect + its owned name view are both selected so they
         * translate together with the cursor. */
        const char *nm = tclgetvar("pin_new_name");
        const char *dr = tclgetvar("pin_new_dir");
        if(!nm || !nm[0]) nm = "XXX";
        if(!dr || !dr[0]) dr = "inout";
        /* this arms a symbol PIN preview, never a net-label: clear wirelabel_preview so a
         * still-live Add-Wire-Label preview (both modeless forms open) cannot leak its
         * drop-on-copper gate onto this pin's drop (add_wire_label.md invariant). */
        xctx->wirelabel_preview = 0;
        /* A live preview ALWAYS has START_SYMPIN set; require it so a STALE sympin_preview
         * (the modeless form stayed open while a file load / clear / unselect reset ui_state
         * out from under it) is not mistaken for an armed preview -> we must still push a
         * fresh baseline, else the placed pin would have no undo entry. */
        if(xctx->sympin_preview && (xctx->ui_state & START_SYMPIN)) {
          /* re-arm: discard the previous preview pin WITHOUT pushing undo */
          if(xctx->ui_state & STARTMOVE) {
            int save = xctx->modified;
            move_objects(ABORT,0,0,0);
            delete(0 /* to_push_undo: no, keep the single baseline */);
            set_modify(save);
          }
          xctx->ui_state &= ~START_SYMPIN;
        } else {
          xctx->push_undo();        /* one undo baseline (no preview pin) per gesture */
          xctx->sympin_preview = 1;
        }
        unselect_all(1);
        create_pin(x, y, nm, dr, SELECTED);
        xctx->need_reb_sel_arr=1;
        rebuild_selected_array();
        move_objects(START,0,0,0);
        xctx->ui_state |= START_SYMPIN;
      } else {
        /* no args: open the Add-pin dialog (Name + Direction); its Place button
         * re-invokes this command as `add_symbol_pin -place`. */
        tcleval("addpin::open");
      }
      Tcl_ResetResult(interp);
    }

    /* add_sch_pin -place
     *   Schematic-editor Add-Pin: place an ipin/opin/iopin INSTANCE (the schematic twin of
     *   add_symbol_pin, which places a symbol PINLAYER rect). Driven by the SAME modeless
     *   addpin:: dialog (view-aware: it picks this verb when editing a schematic). Reads
     *   ::pin_new_name / ::pin_new_dir and arms a cursor preview, reusing the sympin_preview +
     *   START_SYMPIN undo-clean re-arm dance so per-keystroke re-issues stay under ONE undo
     *   baseline. Refused in a symbol view (a schematic pin is an instance).
     *   See doc/claude/specs/schematic_add_pin.md. */
    else if(!strcmp(argv[1], "add_sch_pin"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "add_sch_pin")) return TCL_ERROR;
      if(editing_symbol_view()) { Tcl_ResetResult(interp); return TCL_OK; }
      if(argc == 3 && !strcmp(argv[2], "-place")) {
        const char *nm = tclgetvar("pin_new_name");
        const char *dr = tclgetvar("pin_new_dir");
        if(!nm || !nm[0]) nm = "XXX";
        if(!dr || !dr[0]) dr = "inout";
        /* arming a schematic PIN preview, never a net-label: clear wirelabel_preview so a
         * still-live Add-Wire-Label preview cannot leak its drop-on-copper gate onto this
         * pin's drop (add_wire_label.md invariant). */
        xctx->wirelabel_preview = 0;
        if(xctx->sympin_preview && (xctx->ui_state & START_SYMPIN)) {
          /* re-arm: discard the previous preview instance WITHOUT pushing undo */
          if(xctx->ui_state & STARTMOVE) {
            int save = xctx->modified;
            move_objects(ABORT,0,0,0);
            delete(0 /* to_push_undo: no, keep the single baseline */);
            set_modify(save);
          }
          xctx->ui_state &= ~START_SYMPIN;
        } else {
          xctx->push_undo();        /* one undo baseline per gesture */
          xctx->sympin_preview = 1;
        }
        unselect_all(1);
        if(place_sch_pin(nm, dr)) { /* selects the new instance (place_symbol draw&4) */
          xctx->need_reb_sel_arr = 1;
          rebuild_selected_array();
          move_objects(START,0,0,0);
          xctx->ui_state |= START_SYMPIN;
        } else {
          /* Pin symbol unresolvable (e.g. a misconfigured library path with no ipin.sym):
           * place_symbol placed and selected NOTHING, so do NOT arm a phantom preview.
           * Clear sympin_preview so this leaked flag cannot later make an UNRELATED
           * add_graph/add_image abort drop its own undo baseline (callback.c:237). Unlike the
           * mirrored add_symbol_pin, whose create_pin always stores a rect, place_symbol can
           * fail -- so this guard is required here. START_SYMPIN was already cleared (re-arm)
           * or never set (fresh arm); a fresh arm's one push_undo is left as a no-op undo. */
          xctx->sympin_preview = 0;
        }
      }
      Tcl_ResetResult(interp);
    }

    /* add_wire_label [-place | -drop [x y]]
     *   Cadence-style Add Wire Label (doc/claude/specs/add_wire_label.md). Places lab_pin
     *   net-label INSTANCES (lab=<name>) under the SAME modeless addlabel:: dialog / sympin
     *   preview machinery as add_sch_pin, PLUS a "must land on copper" drop constraint.
     *     (bare)      -> open the form (addlabel::open).
     *     -place      -> read ::label_new_name and arm a cursor preview (reusing the sympin
     *                    undo-clean re-arm dance; sets wirelabel_preview so the gate applies).
     *     -drop [x y] -> reposition the preview to (x,y) (snapped; current snap if omitted) then
     *                    run the shared drop gate wire_label_try_commit(); result 1/0 = committed
     *                    /refused. GUI drops go through the button path, which runs the same gate;
     *                    -drop is the headless seam (tests) and a scriptable commit. */
    else if(!strcmp(argv[1], "add_wire_label"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "add_wire_label")) return TCL_ERROR;
      /* Net labels are schematic instances; a .sym view forbids instances (place_symbol fails).
       * Short-circuit like add_sch_pin (scheduler.c ~425) BEFORE the -place body so a form left
       * open over a symbol view does not push a no-op undo baseline + wipe the selection on every
       * keystroke (add_wire_label.md). Also declines the bare form-open there. */
      if(editing_symbol_view()) { Tcl_ResetResult(interp); return TCL_OK; }
      if(argc >= 3 && !strcmp(argv[2], "-place")) {
        const char *nm = tclgetvar("label_new_name");
        if(!nm) nm = "";
        if(xctx->sympin_preview && (xctx->ui_state & START_SYMPIN)) {
          /* re-arm: discard the previous preview instance WITHOUT pushing undo */
          if(xctx->ui_state & STARTMOVE) {
            int save = xctx->modified;
            move_objects(ABORT,0,0,0);
            delete(0 /* to_push_undo: no, keep the single baseline */);
            set_modify(save);
          }
          xctx->ui_state &= ~START_SYMPIN;
        } else {
          xctx->push_undo();        /* one undo baseline per gesture */
          xctx->sympin_preview = 1;
        }
        xctx->wirelabel_preview = 1;  /* mark this preview as a constrained net-label */
        unselect_all(1);
        if(place_wire_label(nm)) {
          xctx->need_reb_sel_arr = 1;
          rebuild_selected_array();
          move_objects(START,0,0,0);
          /* seed x2/y2 = anchor so the first `-drop`/RUBBER reposition (a different snap) passes
           * move_objects(RUBBER)'s no-motion guard (mirror of the move_objects headless seam). */
          xctx->x2 = xctx->x1; xctx->y2 = xctx->y1;
          xctx->ui_state |= START_SYMPIN;
        } else {
          /* lab_pin.sym unresolvable, or a .sym view forbids instances: nothing was placed, so do
           * NOT arm a phantom preview (mirror of the add_sch_pin guard, callback.c:237). */
          xctx->sympin_preview = 0;
          xctx->wirelabel_preview = 0;
        }
        Tcl_ResetResult(interp);
      }
      else if(argc >= 3 && !strcmp(argv[2], "-drop")) {
        if(argc > 4) {              /* reposition the preview to the requested snap point */
          xctx->mousex_snap = atof(argv[3]);
          xctx->mousey_snap = atof(argv[4]);
          if(xctx->ui_state & STARTMOVE) move_objects(RUBBER,0,0,0);
        }
        Tcl_SetResult(interp, wire_label_try_commit() ? "1" : "0", TCL_STATIC);
      }
      else {
        tcleval("addlabel::open");
        Tcl_ResetResult(interp);
      }
    }

    /* add_graph
     *   Start a GUI placement of a graph object */
    else if(!strcmp(argv[1], "add_graph"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "add_graph")) return TCL_ERROR;
      unselect_all(1);
      xctx->graph_lastsel = xctx->rects[GRIDLAYER];
      storeobject(-1, xctx->mousex_snap-400, xctx->mousey_snap-200, xctx->mousex_snap+400, xctx->mousey_snap+200,
                  xRECT, GRIDLAYER, SELECTED,
          "flags=graph\n"
          "y1=0\n"
          "y2=2\n"
          "ypos1=0\n"
          "ypos2=2\n"
          "divy=5\n"
          "subdivy=1\n"
          "unity=1\n"
          "x1=0\n"
          "x2=10e-6\n"
          "divx=5\n"
          "subdivx=1\n"
          "xlabmag=1.0\n"
          "ylabmag=1.0\n"
          "legendmag=1.0\n"
          "node=\"\"\n"
          "color=\"\"\n"
          "dataset=-1\n"
          "unitx=1\n"
          "logx=0\n"
          "logy=0\n"
        );
      xctx->need_reb_sel_arr=1;
      rebuild_selected_array();
      move_objects(START,0,0,0);
      xctx->ui_state |= START_SYMPIN;
      Tcl_ResetResult(interp);
    }

    /* add_image
     *   Ask user to choose a png/jpg file and start a GUI placement of the image */
    else if(!strcmp(argv[1], "add_image"))
    {
      char *f = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "add_image")) return TCL_ERROR;
      unselect_all(1);
      tcleval("tk_getOpenFile -filetypes {{{Images} {.jpg .jpeg .png .svg}} {{All files} *} }");

      if(tclresult()[0]) {
        char *str = NULL;
        my_strdup2(_ALLOC_ID_, &f, tclresult());
        my_mstrcat(_ALLOC_ID_, &str, "flags=image,unscaled\nalpha=0.8\nimage=\"", f, "\"\n", NULL);

        if(strstr(f, ".svg") == f + strlen(f) - 4 ) {
          if(tcleval("info exists svg_to_png")[0] == '1') {
             my_mstrcat(_ALLOC_ID_, &str, "filter=\"", tclgetvar("svg_to_png"), "\"\n", NULL);
          }
        }
        storeobject(-1, xctx->mousex_snap-100, xctx->mousey_snap-100, xctx->mousex_snap+100, xctx->mousey_snap+100,
                    xRECT, GRIDLAYER, SELECTED, str);

        my_free(_ALLOC_ID_, &str);
        xctx->need_reb_sel_arr=1;
        rebuild_selected_array();
        move_objects(START,0,0,0);
        xctx->ui_state |= START_SYMPIN;
      }
      if(f) my_free(_ALLOC_ID_, &f);
      Tcl_ResetResult(interp);
    }

    /* add_pin_stubs [-prefix <s>] [-suffix <s>] [-inst-prefix]
     *   For the current selection (individual pins, else whole instances' unconnected pins),
     *   draw a wire stub out of each pin + a lab_pin net-label at the far end. The net name is
     *   [instname_ if -inst-prefix][-prefix]<pinname>[-suffix]. One undo. B5,
     *   doc/claude/specs/wire_stub_netlabel.md §4.
     * Routes through the single mutation boundary (Refactor B atom 25, run_core above): the readonly
     * gate, the -prefix/-suffix/-inst-prefix flag parse, the add_pin_stubs() effect (core owns its
     * undo+draw) and the ONE `xschem add_pin_stubs [flags]` log site (via core_log_action, LOGGED
     * UNCONDITIONALLY on success -- option (c) no-op-still-logs) all live in perform_action/run_core.
     * The old inline flag-parse + `if(added>0) log_action_argv` gate + the count Tcl_SetResult are GONE
     * (the boundary owns the log; NO caller consumed the count). The SPACE key (act_add_pin_stubs,
     * callback.c) stays RAW below the boundary -- it needs the C-fn int return for its pan-on-decline
     * dual-use and never reaches this branch, so no double-log. */
    else if(!strcmp(argv[1], "add_pin_stubs"))
      return perform_action("add_pin_stubs", argc, argv);

    /* align
     *   Align currently selected objects to current snap setting */
    else if(!strcmp(argv[1], "align"))
    {
      /* Route through the single mutation boundary (Refactor B atom 2, run_core above):
       * ONE readonly gate + the push_undo/round_schematic_to_grid/maintain/draw effect +
       * the ONE `xschem align` log site all live in perform_action. Tools menu / toolbar /
       * command palette / scripted `xschem align` all reach here; the Alt-U key funnels
       * through the same boundary (callback.c). No scattered readonly/undo/log here. */
      return perform_action("align", argc, argv);
    }

    /* annotate_op [raw_file] [level] [sim_type]
     *   Annotate operating point data into current schematic.
     *   use <schematic name>.raw or use supplied argument as raw file to open
     *   look for operating point data and annotate voltages/currents into schematic.
     *   The optional 'level' integer specifies the hierarchy level the raw file refers to.
     *   This is necessary if annotate_op is called from a sub schematic at a hierarchy
     *   level > 0 but simulation was done at top level (hierarchy 0, for example)
     *   The sim_type optional parameter (specify also file name and level in this case) sets the 
     *   simulation to look for (instead of default op, dc, tran fallbacks)
     */
    else if(!strcmp(argv[1], "annotate_op"))
    {
      int level = -1;
      int res = 0;
      char sim_type[256] = "";
      char f[PATH_MAX + 100];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}

      if(argc > 4) {
        my_snprintf(sim_type, S(sim_type),"%s", argv[4]);
      }

      if(argc > 3) {
        level = atoi(argv[3]);
        if(level < 0 || level > xctx->currsch) {
          level = -1;
        }
      }
      if(argc > 2) {
        my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[2], home_dir);
        tcleval(f);
        my_strncpy(f, tclresult(), S(f));
      } else {
        my_snprintf(f, S(f), "%s/%s.raw",  tclgetvar("netlist_dir"), get_cell(xctx->sch[xctx->currsch], 0));
      }
      tclsetboolvar("live_cursor2_backannotate", 1);
      /* delete previously loaded OP */
      if(xctx->raw && xctx->raw->rawfile && xctx->raw->allpoints == 1 &&
         (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
        res = extra_rawfile(3, xctx->raw->rawfile, xctx->raw->sim_type, -1.0, -1.0);
      }
      tcleval("array unset ngspice::ngspice_data");


      if(sim_type[0]) {
        res = extra_rawfile(1, f, sim_type, -1.0, -1.0);
      } else {
        res = extra_rawfile(1, f, "op", -1.0, -1.0);
        if(res != 1) {
          /* Xyce uses a 1-point DC transfer characteristic for operating point (OP) data */
          res = extra_rawfile(1, f, "dc", -1.0, -1.0);
        }
        if(res != 1) { /* try to load a tran analysis (display 1stpoint as OP data in schematic) */
          res = extra_rawfile(1, f, "tran", -1.0, -1.0);
        }
      }
      if(res == 1) {
        if(level >= 0) {
          xctx->raw->level = level;
          my_strdup2(_ALLOC_ID_, &xctx->raw->schname, xctx->sch[level]);
        }
        update_op();
        draw();
      }
    }

    /* arc [x y r a b layer prop]
     *   if arguments are given (center x and y, radius r, start angle a, end angle b, layer number)
     *   place specified arc, otherwise start a GUI placement of an arc.
     *   For GUI placement user should click 3 unaligned points to define the arc */
    /* arc_id layer index
     *   session-stable id of the arc at (layer, index), or -1 if out of range.
     *   Shared graphical id space; resolve back with `xschem arc_index id` */
    else if(!strcmp(argv[1], "arc_id"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
        int c = atoi(argv[2]), n = atoi(argv[3]);
        if(c >= 0 && c < cadlayers && n >= 0 && n < xctx->arcs[c]) {
          char s[30];
          my_snprintf(s, S(s), "%u", xctx->arc[c][n].id);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        } else {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        }
      }
    }
    /* arc_index id
     *   current "{layer index}" of the arc with that id, or -1 if none */
    else if(!strcmp(argv[1], "arc_index"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        unsigned int id = (unsigned int)strtoul(argv[2], NULL, 10);
        int layer, idx = gfx_index_from_id(ARC, id, &layer);
        if(idx < 0) {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        } else {
          char s[40];
          my_snprintf(s, S(s), "%d %d", layer, idx);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        }
      }
    }
    else if(!strcmp(argv[1], "arc"))
    {
      const char *prop = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "arc")) return TCL_ERROR;
      if(argc > 8) {
        prop = argv[8];
      }
      if(argc > 7) {
        double x = atof(argv[2]);
        double y = atof(argv[3]);
        double r = atof(argv[4]);
        double a = atof(argv[5]);
        double b = atof(argv[6]);
        int layer = atoi(argv[7]);

        if(layer >= 0 && layer < cadlayers) {
          xctx->push_undo(); /* issue 0127: checkpoint like interactive new_arc; only when actually storing */
          store_arc(-1, x, y, r, a, b, layer, 0, prop);
          set_modify(1);
          Tcl_SetResult(interp, "1", TCL_STATIC);
        } else {
          Tcl_SetResult(interp, "0", TCL_STATIC);
        }
      } else {
        xctx->ui_state |= MENUSTART;
        xctx->ui_state2 = MENUSTARTARC;
        Tcl_SetResult(interp, "1", TCL_STATIC);
      }
    }

    /* attach_labels [interactive]
     *   Attach net labels to selected component(s) instance(s)
     *   Optional integer 'interactive' (default: 0) is passed to attach_labels_to_inst().
     *   setting interactive=2 will place lab_show.sym labels on unconnected instance pins */
    else if(!strcmp(argv[1], "attach_labels"))
    {
      /* Route through the single mutation boundary (Refactor B atom 11, run_core above):
       * the readonly gate (scheduler_readonly_reject) + the effect (attach_labels_to_inst,
       * reading `interactive` from argv[2]) + the ONE `xschem attach_labels [interactive]`
       * log site (core_log_action PRESERVES the 0/1/2 value -- byte-identical to the old
       * log_action_argv for the canonical integer arg the UI emits, and strictly MORE
       * faithful for a non-canonical token) all live in perform_action, dropping this branch's
       * own `!xctx` guard (the boundary owns it) and its inline effect + self-log. The
       * Symbol menu (hand-written `-command "xschem attach_labels"`, interactive=0) and the
       * command palette reach here. The boundary ADDS a readonly gate this branch never had
       * (a scattered 0041/0051 close): attach_labels always mutates -- every form (0/1/2)
       * places label instances, none is a read-only-safe query -- so the all-or-nothing gate
       * cannot over-reject (contrast check_unique_names, §30). The Shift+H key runs the
       * interactive-DIALOG variant attach_labels_to_inst(1) via its registered action
       * (csv-nolog, NON-equivalent) and stays OFF the boundary; the netlisting sub-step
       * show_unconnected_pins() calls attach_labels_to_inst(2) raw and stays BELOW it. */
      return perform_action("attach_labels", argc, argv);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem b...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 1). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_b(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* bbox begin|end
     *   Start/end bounding box calculation: parameter is either 'begin' or 'end' */
    if(!strcmp(argv[1], "bbox"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        if(!strcmp(argv[2], "end")) {
          bbox(END , 0.0 , 0.0 , 0.0 , 0.0);
        } else if(!strcmp(argv[2], "start")) {
          bbox(START,0.0, 0.0, 0.0, 0.0);
        } else if(!strcmp(argv[2], "set")) {
          bbox(SET,0.0, 0.0, 0.0, 0.0);
        } else if(argc > 6 && !strcmp(argv[2], "add")) {
          bbox(ADD, atof(argv[3]),  atof(argv[4]), atof(argv[5]), atof(argv[6]));
        }
      }
      Tcl_ResetResult(interp);
    }

    /* break_wires [remove]
     *   Break wires at selected instance pins
     *   if '1' is given as 'remove' parameter broken wires that are
     *   all inside selected instances will be deleted */
    else if(!strcmp(argv[1], "break_wires"))
    {
      /* Route through the single mutation boundary (Refactor B atom 9, run_core above):
       * the readonly gate (scheduler_readonly_reject) + the remove-FLAG effect
       * (break_wires_at_pins, which owns its OWN push_undo/draw/set_modify) + the ONE
       * `xschem break_wires [1]` log site (core_log_action canonicalizes the flag) all
       * live in perform_action. The Tools/Edit menu, the toolbar, the command palette
       * and scripted `xschem break_wires [1]` all reach here; the '!'/Ctrl-'!' keys
       * reach the same boundary from callback.c. No inline readonly/effect/log here.
       * This is the FIRST non-transform verb migrated (audit §29): the arg is a FLAG,
       * not a pivot, and there is no mid-gesture split. */
      return perform_action("break_wires", argc, argv);
    }

    /* build_colors
     *   Rebuild color palette using values of tcl vars dim_value and dim_bg */
    else if(!strcmp(argv[1], "build_colors"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      build_colors(tclgetdoublevar("dim_value"), tclgetdoublevar("dim_bg"));
      Tcl_ResetResult(interp);
    }

    /* bind <wheel|button|key> <code> <mods> <ctx> <action_id>
     *   Map an input signature to an action id (Phase 3 remappable input).
     * bindings dump
     *   List current input bindings as {device code mods ctx action_id} rows.
     * (the matching `unbind` lives under case 'u')
     * See doc/claude/suggestions/refactor_plan_action_registry_phase3.md */
    /* backup write|remove|name
     * Autosave "~" backup file for the current cell:
     *   write  -> write cellName~.sch from the current (unsaved) buffer
     *   remove -> delete cellName~.sch
     *   name   -> return the backup filename (or "" if not applicable)
     * (Hooked automatically to edits in set_modify(); also usable directly.) */
    else if(!strcmp(argv[1], "backup"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) { Tcl_SetResult(interp, "xschem backup: missing subcommand", TCL_STATIC); return TCL_ERROR; }
      if(!strcmp(argv[2], "write")) write_backup();
      else if(!strcmp(argv[2], "remove")) remove_backup();
      else if(!strcmp(argv[2], "name")) {
        char bak[PATH_MAX];
        if(xctx->sch[xctx->currsch] && backup_file_name(bak, S(bak), xctx->sch[xctx->currsch]))
          Tcl_SetResult(interp, bak, TCL_VOLATILE);
        else Tcl_SetResult(interp, "", TCL_STATIC);
      }
      else { Tcl_SetResult(interp, "xschem backup: unknown subcommand", TCL_STATIC); return TCL_ERROR; }
    }
    else if(!strcmp(argv[1], "bind"))
    {
      return action_cmd_bind(argc, argv);
    }
    else if(!strcmp(argv[1], "bindings"))
    {
      return action_cmd_bindings(argc, argv);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem c...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 1). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_c(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
  int i;
    /* callback win_path event mx my key button aux state
     *   Invoke the callback event dispatcher with a software event */
    if(!strcmp(argv[1], "callback") )
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* issue 0076: guard argc BEFORE reading argv[2..9]. Without this `xschem callback`
       * (argc<10) passes argv[2]==NULL as win_path into callback() -> NULL deref -> SIGSEGV
       * -> emergency-save -> editor dies (same class as select_inside / issue 0075). */
      if(argc < 10) {
        Tcl_SetResult(interp,
          "xschem callback: usage: callback win_path event mx my key button aux state", TCL_STATIC);
        return TCL_ERROR;
      }
      callback( argv[2], atoi(argv[3]), atoi(argv[4]), atoi(argv[5]), (KeySym)atol(argv[6]),
               atoi(argv[7]), atoi(argv[8]), atoi(argv[9]) );
      dbg(2, "callback %s %s %s %s %s %s %s %s\n",
          argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8], argv[9]);
      Tcl_ResetResult(interp);
    }

    /* cellview_path <lib/cell> <view>
     *   Absolute path of the datafile for cell <cell> view <view> in library
     *   <lib> under the lib/cell/view layout (<libpath>/<cell>/<view>/<cell>.ext),
     *   or "" if the library/cell/view does not exist. <view> is "schematic" or
     *   "symbol". Read-only resolver (library-manager Phase 2); implemented in
     *   Tcl (src/library_defs.tcl). See doc/claude/code_analysis/library_manager_design.md. */
    else if(!strcmp(argv[1], "cellview_path"))
    {
      if(argc > 3) tclvareval("cellview_path {", argv[2], "} {", argv[3], "}", NULL);
      else Tcl_ResetResult(interp);
    }

    /* cell_views <library> <cell>
     *   Sorted list of views present for a cell (subdirs holding a <cell>.<ext>
     *   datafile). Backs the Library Manager tree (library-manager Phase 7a). */
    else if(!strcmp(argv[1], "cell_views"))
    {
      if(argc > 3) tclvareval("cell_views {", argv[2], "} {", argv[3], "}", NULL);
      else Tcl_ResetResult(interp);
    }

    /* create_instance [lcv]
     *   Open the Create Instance form (Cadence-style Add Instance): a properties-
     *   style dialog with Library/Cell/View/Instance-name fields + a Browse button
     *   (which opens the Library Browser). Valid fields arm a live placement
     *   preview; click the canvas to drop. The optional argument is a
     *   {lib cell view [instname]} list that pre-fills the form (e.g.
     *   `xschem create_instance [libmgr::selection]`). Logs itself so the launch
     *   is replayable (CIW + Xschem.log) and bindable.
     *   See doc/claude/specs/cadence_create_instance.md. */
    else if(!strcmp(argv[1], "create_instance"))
    {
      if(has_x) {
        log_action("xschem create_instance");
        if(argc > 2) {
          tclvareval("ciform::open {", argv[2], "}", NULL);
        } else {
          tcleval("ciform::open");
        }
      }
    }

    /* case_insensitive 1|0
     *   Set case insensitive symbol lookup. Use only on case insensitive filesystems */
    else if(!strcmp(argv[1], "case_insensitive"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        int n = atoi(argv[2]);
        if(n) {
          xctx->case_insensitive = 1;
          xctx->x_strcmp = my_strcasecmp;
        } else {
          xctx->case_insensitive = 0;
          xctx->x_strcmp = strcmp;
        }
      }
    }

    /* change_elem_order n
     *   set selected object (instance, wire, line, rect, ...) to
     *   position 'n' in its respective array
     *   Refactor B atom 21 (audit §41): routes through the perform_action boundary.
     *   run_core owns the argc<3 + `n >= 0 || n == -1` validation gates and the
     *   change_elem_order(n) effect (the core OWNS its own push_undo + set_modify);
     *   core_log_action owns the ONE value-preserving `xschem change_elem_order %d`
     *   log site (which PRESERVES the pre-migration had_sel gate via `if(xctx->lastsel)` --
     *   §30 no-op-still-logs was REJECTED for this SELECTION-DEPENDENT verb, see audit §41).
     *   The equivalent Shift+S key (callback.c case 'S', hardcoded -1) routes through the
     *   SAME boundary. No scattered readonly/log/push_undo remains here. */
    else if(!strcmp(argv[1], "change_elem_order"))
    {
      return perform_action("change_elem_order", argc, argv);
    }

    /* change_sch_path n <draw>
     *   if descended into a vector instance change inst number we are into to 'n',
     *   (same rules as 'descend' command) without going up and descending again
     *   if 'draw' string is given redraw screen */
    else if(!strcmp(argv[1], "change_sch_path"))
    {
      int dr = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3 && !strcmp(argv[3], "draw")) dr = 1;
      if(argc > 2) {
        int n = atoi(argv[2]);
        change_sch_path(n, dr);
      }
    }

    /* check_loaded n <filename>
     *   check if schematic / symbol file is already opened and return window path
     *   the loaded schematic is in.
     *   for <filename> use absolute path or use [abs_sym_path filename]
     *     window_path[0] == ".drw"
     *     window_path[1] == ".x1.drw"
     *     ...
     *   else return empty string */
    else if(!strcmp(argv[1], "check_loaded"))
    {
      char win_path[WINDOW_PATH_SIZE] = "";
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        check_loaded(argv[2], win_path);
      }
      Tcl_SetResult(interp, win_path, TCL_VOLATILE);
    }

    /* check_symbols
     *   List all used symbols in current schematic and warn if some symbol is newer */
    else if(!strcmp(argv[1], "check_symbols"))
    {
      char sympath[PATH_MAX];
      const char *name;
      struct stat buf;
      char *res=NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i=0;i<xctx->symbols; ++i) {
        name = xctx->sym[i].name;
        if(!strcmp(xctx->file_version, "1.0")) {
          my_strncpy(sympath, abs_sym_path(name, ".sym"), S(sympath));
        } else {
          my_strncpy(sympath, abs_sym_path(name, ""), S(sympath));
        }
        if(!stat(sympath, &buf)) { /* file exists */
          if(xctx->time_last_modify < buf.st_mtime) {
            my_mstrcat(_ALLOC_ID_, &res, "Warning: symbol ", sympath, " is newer than schematic\n", NULL);
          }
        } else { /* not found */
            my_mstrcat(_ALLOC_ID_, &res, "Warning: symbol ", sympath, " not found\n", NULL);
        }
        my_mstrcat(_ALLOC_ID_, &res, "symbol ", my_itoa(i), " : ", sympath, "\n", NULL);
      }
      Tcl_SetResult(interp, res, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &res);
    }

    /* check_unique_names [1|0]
     *   Check if all instances have a unique refdes (name attribute in xschem),
     *   highlight such instances. If second parameter is '1' rename duplicates */
    else if(!strcmp(argv[1], "check_unique_names"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 && !strcmp(argv[2], "1"))
        return perform_action("check_unique_names", argc, argv);  /* MUTATE: gate + effect + log(=1) */
      /* mode 0: read-only-safe duplicate-refdes HIGHLIGHT stays RAW in front of the boundary
       * (the all-or-nothing readonly gate would over-reject it on a read-only cell -- the image
       * §40 / instance_number §43 split). UNLIKE those unlogged query fronts, mode 0 is a
       * CURRENTLY-LOGGED replayable action, so it KEEPS its own log_action here (the asymmetric
       * logged-query sub-shape, atom 26 / audit §46). Any argv[2] other than exact "1" -- and the
       * bare argc==2 form -- lands here and logs the canonical "0", byte-identical to the old
       * `%s`-with-?: site. */
      check_unique_names(0);
      log_action("xschem check_unique_names 0");
      Tcl_ResetResult(interp);
    }

    /* check_pin_names
     *   P7 ERC for Cadence pin-owned name text (doc/claude/specs/cadence_pin_name_text.md
     *   §4.9). Scans the PINLAYER pins of the current drawing (symbol-edit) for duplicate
     *   pin names, owned-but-nameless pins, and un-adopted legacy name labels. Non-blocking,
     *   display/report only (never edits objects or netlists). Human warnings go to the ERC
     *   info window; the RETURN value is a machine-readable Tcl list of "{type idx {name}}"
     *   issue elements (type = dup|nameless|legacy), empty when the pins are clean. */
    else if(!strcmp(argv[1], "check_pin_names"))
    {
      char *res = NULL;
      int nissues;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      statusmsg("", 2);                 /* clear the ERC info window for a fresh check */
      statusmsg("Pin name check:", 3);
      nissues = check_pin_names(&res);
      if(nissues == 0) statusmsg("  no issues found", 2);
      /* surface in the GUI info window on issues (headless: logs the text) */
      tcleval(nissues ? "if {[info procs show_infotext] ne {}} {show_infotext 1}"
                      : "if {[info procs show_infotext] ne {}} {show_infotext 0}");
      Tcl_SetResult(interp, res ? res : "", TCL_VOLATILE);
      my_free(_ALLOC_ID_, &res);
    }
    /* closest_object
     *   returns index of closest object to mouse coordinates
     *   index = type layer n
     *   type = wire | text | line | poly | rect | arc | inst
     *   layer is the layer number the object is drawn with
     *   (valid for line, poly, rect, arc)
     *   n is the index of the object in the xschem array
     *   example:
     *      $  after 3000 {set obj [xschem closest_object]}
     *   (after 3s)
     *      $ puts $obj
     *      line 4 19 */
    else if(!strcmp(argv[1], "closest_object"))
    {
      char res[100];
      const char *type=NULL;
      Selected sel;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}

      sel = find_closest_obj(xctx->mousex, xctx->mousey, 0);
      switch(sel.type)
      {
       case WIRE:    type="wire"; break;
       case xTEXT:   type="text"; break;
       case LINE:    type="line"; break;
       case POLYGON: type="poly"; break;
       case xRECT:   type="rect"; break;
       case ARC:     type="arc" ; break;
       case ELEMENT: type="inst"; break;
       default: break;
      } /*end switch */

      if(sel.type) my_snprintf(res, S(res), "%s %d %d", type, sel.col, sel.n);
      else my_snprintf(res, S(res), "nosel");
      Tcl_SetResult(interp, res, TCL_VOLATILE);
    }

    /* circle
     *   Start a GUI placement of a circle.
     *   User should click 3 unaligned points to define the circle */
    else if(!strcmp(argv[1], "circle"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      xctx->ui_state |= MENUSTART;
      xctx->ui_state2 = MENUSTARTCIRCLE;
    }

    /* clear [force] [symbol|schematic]
     *   Clear current schematic window. Resets hierarchy level. Remove symbols
     *   the 'force' parameter will not ask to save existing modified schematic.
     *   the 'schematic' or 'symbol' parameter specifies to default to a schematic
     *   or symbol window (default: schematic) */
    else if(!strcmp(argv[1], "clear"))
    {
      int i, cancel = 1, symbol = 0;

      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 2; i < argc; i++) {
        if(!strcmp(argv[i], "force") ) cancel = 0;
        if(!strcmp(argv[i], "symbol")) symbol = 1;
      }
      clear_schematic(cancel, symbol);
      Tcl_ResetResult(interp);
    }

    /* clear_drawing
     *   Clears drawing but does not purge symbols.
     * Routes through the single mutation boundary (Refactor B atom 27, run_core above): the NEW
     * readonly gate (was NONE -- a read-only view was silently emptied), the argc==2 arity
     * validation (was a silent no-op), the unselect_all+clear_drawing effect and the ONE bare
     * `xschem clear_drawing` log site (was SILENT) all live in perform_action/run_core. No undo
     * exists on this path (accepted -- decision doc §2). The seven raw C teardown callers of
     * clear_drawing() (load/undo-restore/window-teardown/clear_schematic/debug) stay raw + silent
     * below the boundary and never reach this branch. */
    else if(!strcmp(argv[1], "clear_drawing"))
      return perform_action("clear_drawing", argc, argv);

    /* color_dim value
     *   Dim colors or brite colors depending on value parameter: -5 <= value <= 5 */
    else if(!strcmp(argv[1], "color_dim"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        tclsetvar("dim_value", argv[2]);
        if(tclgetboolvar("enable_dim_bg") ) {
          tclsetvar("dim_bg", argv[2]);
        }
      }
      build_colors(tclgetdoublevar("dim_value"), tclgetdoublevar("dim_bg"));
      draw();
      Tcl_ResetResult(interp);
    }

    /* compare_schematics [sch_file]
     *   Compare currently loaded schematic with another 'sch_file' schematic.
     *   if no file is given prompt user to choose one */
    else if(!strcmp(argv[1], "compare_schematics"))
    {
      char f[PATH_MAX + 100];
      int ret = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[2], home_dir);
        tcleval(f);
        my_strncpy(f, tclresult(), S(f));
        ret = compare_schematics(f);
      }
      else {
        ret = compare_schematics(NULL);
      }
      Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
    }

    /* connected_nets [0|1|2|3]
     *   Select nets/labels  connected to currently selected instance
     *   if '1' argument is given, stop at wire junctions
     *   if '2' argument is given select only wires directly
     *   attached to selected instance/net
     *   if '3' argument is given combine '1' and '2' */
    else if(!strcmp(argv[1], "connected_nets"))
    {
      int stop_at_junction = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 ) stop_at_junction = atoi(argv[2]);
      select_connected_nets(stop_at_junction);
      Tcl_ResetResult(interp);
    }

    /* copy
     *   Copy selection to clipboard */
    else if(!strcmp(argv[1], "copy"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      rebuild_selected_array();
      save_selection(2);
      /* self-log at core (0062), mirrors the cut branch: covers Edit menu, toolbar,
       * CIW/script (dedup via actionlog_cmd_logged). Ctrl-C and ctx-menu pick 15 call
       * save_selection() directly and record at their own sites. Empty-selection no-op
       * still logs (slice-1 norm); clipboard-only, so a replayed line is always safe. */
      log_action("xschem copy");
      Tcl_ResetResult(interp);
    }

    /* copy_hilights
     *   Copy hilights hash table from previous schematic to new created tab/window */
    else if(!strcmp(argv[1], "copy_hilights"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      copy_hilights();
      Tcl_ResetResult(interp);
    }

    /* copy_hierarchy to from
     *   Copy hierarchy info from tab/window "from" to tab/window "to"
     *   Example: xschem copy_hierarchy .drw .x1.drw */
    else if(!strcmp(argv[1], "copy_hierarchy"))
    {
      int ret = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
        ret = copy_hierarchy_data(argv[2], argv[3]);
      }
      Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
    }

    /* copy_objects [dx dy] [kissing] [stretch]
     *   if kissing is given add nets to pins that touch other instances or nets
     *   if stretch is given stretch connected nets to follow instace pins
     *   if dx and dy are given copy selection
     *   to specified offset, otherwise start a GUI copy operation */
    else if(!strcmp(argv[1], "copy_objects"))
    {
      int nparam = 0;
      int kissing= 0;
      int stretch = 0;
      int rot = 0, flip = 0, rotl = 0, has_anchor = 0, k;
      double ax = 0.0, ay = 0.0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "copy_objects")) return TCL_ERROR;
      if(argc > 2) {
        int i;
        for(i = 2; i < argc; i++) {
          if(!strcmp(argv[i], "kissing")) {kissing = 1; nparam++;}
          if(!strcmp(argv[i], "stretch")) {stretch = 1; nparam++;}
        }
      }
      if(kissing) xctx->connect_by_kissing = 2;
      if(stretch) select_attached_nets();
      if(argc > 3 + nparam) {
        /* mid-copy rotate/flip replay (issue 0069 atom 13): optional `rot flip [local]
         * [-anchor ax ay]` after the delta, mirroring the move_objects and paste arms
         * (see move_objects for the pivot rationale). */
        k = 4;
        if(argc > 5 && argv[4][0] != '-' && argv[5][0] != '-' &&
           strcmp(argv[4], "kissing") && strcmp(argv[4], "stretch") &&
           strcmp(argv[5], "kissing") && strcmp(argv[5], "stretch")) {
          rot = atoi(argv[4]) & 0x3;
          flip = atoi(argv[5]) & 0x1;
          k = 6;
          if(argc > k && !strcmp(argv[k], "local")) { rotl = 1; k++; }
        }
        for(; k < argc; k++) {
          if(!strcmp(argv[k], "-anchor") && k + 2 < argc) {
            ax = atof(argv[k + 1]); ay = atof(argv[k + 2]); has_anchor = 1; k += 2;
          }
        }
        copy_objects(START);
        xctx->deltax = atof(argv[2]);
        xctx->deltay = atof(argv[3]);
        xctx->move_rot = (short)rot;
        xctx->move_flip = (short)flip;
        xctx->rotatelocal = (short)rotl;
        if(has_anchor) { xctx->x1 = ax; xctx->y1 = ay; }
        copy_objects(END);
      } else {
        /* The MENU "Duplicate objects" arms a DEFERRED copy: the mouse is over the menu, not
         * the canvas, so the next canvas click starts it (check_menu_start_commands). The C
         * KEY is made immediate (Cadence noun-verb) separately in callback.c case 'c'. */
        xctx->ui_state |= MENUSTART;
        xctx->ui_state2 = MENUSTARTCOPY;
      }
      Tcl_ResetResult(interp);
    }
    /* count_items string separator quoting_chars
         Debug command */
    else if(!strcmp(argv[1], "count_items"))
    {
      if(argc > 4) {
        Tcl_SetResult(interp, my_itoa(count_items(argv[2], argv[3], argv[4])), TCL_VOLATILE);
      }
    }

    /* create_plot_cmd
     *   Create an xplot file in netlist/simulation directory with
     *   the list of highlighted nodes in a format the selected waveform
     *   viewer understands (bespice, gaw, ngspice) */
    else if(!strcmp(argv[1], "create_plot_cmd") )
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      create_plot_cmd();
      Tcl_ResetResult(interp);
    }

    /* cursor n e
     *   enable or disable cursors.
     *   cursor will be set at 0.0 position. use 'xschem set cursor[12]_x' to set position
     *   n: cursor number (1 or 2, for a or b)
     *   e: enable flag: 1: show, 0: hide */
    else if(!strcmp(argv[1], "cursor"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
        if(atoi(argv[2]) == 2) { /* cursor 2 */
          if(atoi(argv[3]) == 1)
            xctx->graph_flags |= 4;
          else
            xctx->graph_flags &= ~4;

          if(xctx->graph_flags & 4) {
            xctx->graph_cursor2_x = 0.0;
          }
        } else { /* cursor 1 */
          if(atoi(argv[3]) == 1)
            xctx->graph_flags |= 2;
          else
            xctx->graph_flags &= ~2;
          if(xctx->graph_flags & 2) {
            xctx->graph_cursor1_x = 0.0;
          }
        }
      }
      Tcl_ResetResult(interp);
    }

    /* cut
     *   Cut selection to clipboard */
    else if(!strcmp(argv[1], "cut"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "cut")) return TCL_ERROR;
      rebuild_selected_array();
      save_selection(2);
      delete(1/*to_push_undo*/);
      log_action("xschem cut"); /* self-log at core: covers menu/toolbar/key/ctx-menu */
      Tcl_ResetResult(interp);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}


/* `xschem d...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 2). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_d(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* debug n
     *   Set xschem in debug mode.'n' is the debug level
     *   (0=no debug). Higher levels yield more debug info.*/
    if(!strcmp(argv[1], "debug"))
    {
      if(argc > 2) {
         debug_var=atoi(argv[2]);
         tclsetvar("debug_var",argv[2]);
      }
      Tcl_ResetResult(interp);
    }

    /* decr_hilight_color
     *   Step the net-highlight style cursor back one (wrapping modulo the number of
     *   styles) and return the resulting style index. Increment happens automatically
     *   per highlight; this decrement (ALT-minus) lets a user re-apply a recently used
     *   style to the next highlight. See doc/claude/specs/hilight_style_decrement.md */
    else if(!strcmp(argv[1], "decr_hilight_color"))
    {
      char res[30];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(!xctx->net_hilight_style || xctx->n_net_hilight_styles <= 0) build_net_hilight_styles();
      decr_hilight_color();
      my_snprintf(res, S(res), "%d", xctx->hilight_color);
      Tcl_SetResult(interp, res, TCL_VOLATILE);
    }

    /* delete
     *   Delete selection.
     * Routes through the single mutation boundary (Refactor B atom 24, run_core above): the
     * readonly gate, the argc==2 arity validation, the delete() effect (core owns undo/draw) and
     * the ONE `xschem delete` log site all live in perform_action/run_core. The old inline
     * scheduler_readonly_reject + if(argc==2) log_action are GONE (the boundary owns both). Only
     * this branch (menu Edit>Delete + scripted `xschem delete`) crosses; the Ctrl-X / XK_Delete
     * inline keys (callback.c) stay raw + self-logging and never reach here (no double-log). */
    else if(!strcmp(argv[1], "delete"))
      return perform_action("delete", argc, argv);

    /* delete_files
     *   Bring up a file selector the user can use to delete files */
    else if(!strcmp(argv[1], "delete_files"))
    {
      delete_files();
    }

    /* deselect_mode
     *   Enter the persistent deselect-one-at-a-time mode: each subsequent click on a
     *   selected object removes it from the selection (clicks on unselected objects or
     *   empty space do nothing); ESC ends the mode, keeping whatever is still selected.
     *   No-op if nothing is selected. This is the engine behind the rebindable `d`
     *   action edit.deselect_mode. See doc/claude/specs/deselect_one_mode.md */
    else if(!strcmp(argv[1], "deselect_mode"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      enter_deselect_mode();
      Tcl_ResetResult(interp);
    }

    /* descend [n] [notitle]
     *   Descend into selected component instance. Optional number 'n' specifies the
     *   instance number to descend into for vector instances (default: 0).
     *   0 or 1: leftmost instance, 2: second leftmost instance, ...
     *  -1: rightmost instance,-2: second rightmost instance, ...
     *  if integer 'notitle' is given pass it to descend_schematic()
     * descend -inst <name> [notitle]
     *   name-addressed form: descend into the instance called <name> regardless of
     *   the current selection (selects it first). This is the replay-stable form
     *   the action log records. doc/claude/specs/action_log_absorb.md */
    else if(!strcmp(argv[1], "descend"))
    {
      int ret=0;
      int set_title = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(xctx->semaphore == 0) {
        if(argc > 2 && !strcmp(argv[2], "-inst")) {
          /* descend -inst <name> [notitle]
           *   name-addressed, self-contained descend: resolve the instance by
           *   its instname, select it, then descend. This IS the coordinate-free
           *   replay form the action log emits (doc/claude/specs/action_log_absorb.md).
           *   Note: descend_schematic() logs its own outcome line, so no log here. */
          int inst;
          if(argc < 4) {
            Tcl_SetResult(interp, "xschem descend -inst: instance name required", TCL_STATIC);
            return TCL_ERROR;
          }
          if(argc > 4) set_title = atoi(argv[4]);
          inst = get_instance(argv[3]);
          if(inst < 0) {
            Tcl_SetResult(interp, "xschem descend -inst: instance not found", TCL_STATIC);
            return TCL_ERROR;
          }
          unselect_all(1);
          select_element(inst, SELECTED, 1, 1);
          ret = descend_schematic(0, 0, 0, set_title);
        } else {
          if(argc > 3 ) {
            set_title = atoi(argv[3]);
          }
          if(argc > 2) {
            int n = atoi(argv[2]);
            ret = descend_schematic(n, 0, 0, set_title);
          } else {
            ret = descend_schematic(0, 0, 0, set_title);
          }
        }
      }
      Tcl_SetResult(interp, dtoa(ret), TCL_VOLATILE);
    }

    /* descend_symbol [-inst <name>]
     *   Descend into the symbol view of selected component instance.
     *   With -inst <name>: name-addressed, self-contained form -- resolve the
     *   instance by its instname, select it, then descend. This IS the
     *   replay-stable form the action log emits (mirrors `descend -inst`).
     *   Note: descend_symbol() logs its own outcome line, so no log here. */
    else if(!strcmp(argv[1], "descend_symbol"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(xctx->semaphore == 0) {
        if(argc > 2 && !strcmp(argv[2], "-inst")) {
          int inst;
          if(argc < 4) {
            Tcl_SetResult(interp, "xschem descend_symbol -inst: instance name required", TCL_STATIC);
            return TCL_ERROR;
          }
          inst = get_instance(argv[3]);
          if(inst < 0) {
            Tcl_SetResult(interp, "xschem descend_symbol -inst: instance not found", TCL_STATIC);
            return TCL_ERROR;
          }
          unselect_all(1);
          select_element(inst, SELECTED, 1, 1);
        }
        descend_symbol();
      }
      Tcl_ResetResult(interp);
    }

    /* descend_pick
     *   Arm the verb-noun descend pick: the next canvas click names the instance to
     *   descend into, WITHOUT selecting it, and the C arm then calls the Tcl
     *   continuation `hi_descend_pick_done <instname>` (or `hi_descend_pick_cancel`
     *   on a click that hits no instance). ESC drops the arm like any other MENUSTART.
     *   This is the headless-drivable half of the feature: arm here, then deliver the
     *   click with `xschem callback`.
     *   doc/claude/issues/0200-descend-has-no-verb-noun-pick.md */
    else if(!strcmp(argv[1], "descend_pick"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      xctx->ui_state |= MENUSTART;
      xctx->ui_state2 = MENUSTARTDESCEND; /* assign, like every other arming site */
      statusmsg("Descend: click the instance to descend into (ESC to cancel)", 1);
      Tcl_ResetResult(interp);
    }

    /* destroy_all [force]
     *   Close all additional windows/tabs. If 'force' is given do not ask for
     *   confirmation for changed schematics
     *   Returns the remaining # of windows/tabs in addition to main window/tab */
    else if(!strcmp(argv[1], "destroy_all"))
    {
      int force = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 && !strcmp(argv[2], "force")) force = 1;
      if(force)
        new_schematic("destroy_all", "force", NULL, 1);
      else
        new_schematic("destroy_all", NULL, NULL, 1);
      Tcl_SetResult(interp, my_itoa(get_window_count()), TCL_VOLATILE);
    }

    /* display_hilights [nets|instances]
     *   Print a list of highlighted objects (nets, net labels/pins, instances)
     *   if 'instances' is specified list only instance highlights
     *   if 'nets' is specified list only net highlights */
    else if(!strcmp(argv[1], "display_hilights"))
    {
      char *str = NULL;
      int what = 3; /* nets and instances */
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        if(!strcmp(argv[2], "instances")) what = 2; /* instances only */
        else if(!strcmp(argv[2], "nets")) what = 1; /* nets only */
      }
      display_hilights(what, &str);
      Tcl_SetResult(interp, str, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &str);
    }

    /* draw_graph [n] [flags]
     *   Redraw graph rectangle number 'n'.
     *   If the optional 'flags' integer is given it will be used as the
     *   flags bitmask to use while drawing (can be used to restrict what to redraw) */
    else if(!strcmp(argv[1], "draw_graph"))
    {
      int flags;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* has_x: --nogui has no window, no pixmap and no GCs, and draw_graph goes
       * straight to Xlib -> SIGSEGV (pre-existing, found while testing waveform
       * markers). Range: both setup_graph_data() and draw_graph() dereference
       * rect[GRIDLAYER][i] unchecked. Both are now no-ops rather than crashes. */
      if(argc > 2 && has_x && atoi(argv[2]) >= 0 && atoi(argv[2]) < xctx->rects[GRIDLAYER]) {
        int i = atoi(argv[2]);
        setup_graph_data(i, 0,  &xctx->graph_struct);
        if(argc > 3) {
          flags = atoi(argv[3]);
        } else {
          /* 2: draw cursor 1
           * 4: draw cursor 2
           * 128: draw hcursor 1
           * 256: draw hcursor 2 */
          flags = 1 + 8 + 16 + (xctx->graph_flags & (2 + 4 + 128 + 256));
        }
        draw_graph(i, flags, &xctx->graph_struct, NULL);
      }
      Tcl_ResetResult(interp);
    }

    /* draw_hilight_net [1|0]
     *   Redraw only hilight colors on nets and instances
     *   the parameter specifies if drawing on window or only on back buffer */
    else if(!strcmp(argv[1], "draw_hilight_net")) {
      int on_window = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        on_window = atoi(argv[2]);
      }
      draw_hilight_net(on_window);
      Tcl_ResetResult(interp);
    }

    /* drc_check [i]
     *   Perform DRC rulecheck of instances.
     *   if i is specified do check of specified instance
     *   otherwise check all instances in current schematic. */
    else if(!strcmp(argv[1], "drc_check"))
    {
      int i = -1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 && (i = get_instance(argv[2])) < 0 ) {
        Tcl_SetResult(interp, "xschem drc_check: instance not found", TCL_STATIC);
        return TCL_ERROR;
      }
      drc_check(i);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem e...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 2). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_e(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
 int i;
 char name[1024]; /* overflow safe 20161122 */
    /* edit_file
     *   Edit xschem file of current schematic if nothing is selected.
     *   Edit .sym file if a component is selected. */
    if(!strcmp(argv[1], "edit_file") )
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      rebuild_selected_array();
      if(xctx->lastsel==0 ) {
        save_schematic(xctx->sch[xctx->currsch], 0); /* sync data with disk file before editing file */
        my_snprintf(name, S(name), "edit_file {%s}",
            abs_sym_path(xctx->sch[xctx->currsch], ""));
        tcleval(name);
      }
      else if(xctx->sel_array[0].type==ELEMENT) {
        my_snprintf(name, S(name), "edit_file {%s}",
            abs_sym_path(tcl_hook2(xctx->inst[xctx->sel_array[0].n].name), ""));
        tcleval(name);
      }
    }
    /* edit_prop [scope]
     *   Edit global schematic/symbol attributes or attributes
     *   of currently selected instances.
     *   Optional 'scope' (current|selected|all) pins the slick form's "Apply to"
     *   setting before opening, so a keybinding can launch straight into a given
     *   scope (e.g. bind one key to `edit_prop current`, another to
     *   `edit_prop selected`). It updates the sticky ::slickprop_apply_scope. */
    else if(!strcmp(argv[1], "edit_prop"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        if(strcmp(argv[2], "current") && strcmp(argv[2], "selected") && strcmp(argv[2], "all")) {
          Tcl_SetResult(interp, "xschem edit_prop: scope must be current|selected|all", TCL_STATIC);
          return TCL_ERROR;
        }
        tclsetvar("slickprop_apply_scope", argv[2]);
      }
      edit_property(0);
      Tcl_ResetResult(interp);
    }

    /* edit_vi_prop
     *   Edit global schematic/symbol attributes or
     *   attributes of currently selected instances
     *   using a text editor (defined in tcl 'editor' variable) */
    else if(!strcmp(argv[1], "edit_vi_prop"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "edit_vi_prop")) return TCL_ERROR;
      edit_property(1);
      Tcl_ResetResult(interp);
    }

    /* embed_rawfile raw_file
     *   Embed base 64 encoded 'raw_file' into currently
     *   selected element as a 'spice_data' attribute.
     *   Refactor B atom 16 (audit §36): routes through the perform_action boundary.
     *   run_core owns the `~/` expansion + the argc<3 validation gate; the boundary owns
     *   the ONE readonly gate (a CORRECTNESS FIX -- the old branch embedded on a read-only
     *   cell) + the log-on-success self-log (log_action_argv on the RAW argv[2] path so a
     *   metachar path replays and the `~/` form re-expands). The old !xctx guard + the
     *   Tcl_ResetResult are the boundary's now; the old silent argc<=2 no-op becomes a
     *   TCL_ERROR that (via log-on-success) records no phantom line. */
    else if(!strcmp(argv[1], "embed_rawfile"))
      return perform_action("embed_rawfile", argc, argv);

    /* enable_layers
     *   Enable/disable layers depending on tcl array variable enable_layer() */
    else if(!strcmp(argv[1], "enable_layers"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      enable_layers();
      Tcl_ResetResult(interp);
    }

    /* escape_chars source [charset]
     *   escape tcl special characters with backslash
     *   if charset is given escape characters in charset */
    else if(!strcmp(argv[1], "escape_chars"))
    {
      if(argc > 3) {
        Tcl_SetResult(interp, escape_chars(argv[2], argv[3]), TCL_VOLATILE);
      } else if(argc > 2) {
        Tcl_SetResult(interp, escape_chars(argv[2], ""), TCL_VOLATILE);
      }
    }


    /* eval_expr str
     *   debug function: evaluate arithmetic expression in str */
    else if(!strcmp(argv[1], "eval_expr"))
    {
      if(argc > 2) {
        Tcl_SetResult(interp, eval_expr(argv[2]), TCL_VOLATILE);
      }
    }

    /* exit [exit_code] [closewindow] [force]
     *   Exit the program, ask for confirm if current file modified.
     *   if exit_code is given exit with its value, otherwise use 0 exit code
     *   if 'closewindow' is given close the window, otherwise leave with a blank schematic
     *   when closing the last remaining window
     *   if 'force' is given do not ask before closing modified schematic windows/tabs
     *   This command returns the list of remaining open windows in addition to main window */
    else if(!strcmp(argv[1], "exit"))
    {
      int closewindow = 0;
      int force = 0;
      const char *exit_status = "0";

      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 2; i < argc; ++i) {
        if(!strcmp(argv[i], "closewindow")) closewindow = 1;
        if(!strcmp(argv[i], "force")) force = 1;
        if(strpbrk(argv[i], "0123456789-")) exit_status = argv[i];
      }
      if(!strcmp(xctx->current_win_path, ".drw")) {
        /* non tabbed interface */
        if(!tclgetboolvar("tabbed_interface")) {
          int wc = get_window_count();
          dbg(1, "wc=%d\n", wc);
          if(wc > 0 ) {
            if(!force && hierarchy_modified()) {
              tcleval("tk_messageBox -type okcancel  -parent [xschem get topwindow] -message \""
                        "[get_cell [xschem get schname] 0]"
                        ": UNSAVED data: want to exit?\"");
            }
            if(force || !hierarchy_modified() || !strcmp(tclresult(), "ok")) {
              if(has_x) tcleval("store_geom [xschem get topwindow] [xschem get current_name]");
              swap_windows(0);
              set_modify(0); /* set modified status to 0 to avoid another confirm in following line */
              new_schematic("destroy", xctx->current_win_path, NULL, 0);
              draw();
            }
          } else {
            if(!force && hierarchy_modified()) {
              tcleval("tk_messageBox -type okcancel  -parent [xschem get topwindow] -message \""
                        "[get_cell [xschem get schname] 0]"
                        ": UNSAVED data: want to exit?\"");
            }
            if(force || !hierarchy_modified() || !strcmp(tclresult(), "ok")) {
               if(closewindow) {
                 char s[40];
                 /* action-log (file-menu plan): the session ends here -- the
                  * one place every quit path (menu Close/Quit, WM close
                  * button, typed `xschem exit`) funnels through before the
                  * process dies. Logged with closewindow+force so a sourced
                  * full-session replay terminates deterministically, with no
                  * confirm dialog. */
                 log_action("xschem exit closewindow force");
                 my_snprintf(s, S(s), "exit %s", exit_status); /* xwin_exit() saves window geometry */
                 tcleval(s);
               }
               else {
                 if(has_x) tcleval("store_geom [xschem get topwindow] [xschem get current_name]");
                 clear_schematic(0, 0);
               }
            }
          }
        }
        /* tabbed interface */
        else {
          int wc = get_window_count();
          dbg(1, "wc=%d\n", wc);
          if(wc > 0 ) {
            if(has_x && !force && hierarchy_modified()) {
              tcleval("tk_messageBox -type okcancel  -parent [xschem get topwindow] -message \""
                        "[get_cell [xschem get schname] 0]"
                        ": UNSAVED data: want to exit?\"");
            }
            if(!has_x || force || !hierarchy_modified() || !strcmp(tclresult(), "ok")) {
              if(has_x) tcleval("store_geom [xschem get topwindow] [xschem get current_name]");
              swap_tabs();
              set_modify(0);
              new_schematic("destroy", xctx->current_win_path, NULL, 1);
            }
          } else {
            if(has_x && !force && hierarchy_modified()) {
              tcleval("tk_messageBox -type okcancel  -parent [xschem get topwindow] -message \""
                        "[get_cell [xschem get schname] 0]"
                        ": UNSAVED data: want to exit?\"");
            }
            if(!has_x || force || !hierarchy_modified() || !strcmp(tclresult(), "ok")) {
               if(closewindow) {
                 char s[40];
                 /* action-log (file-menu plan): the session ends here -- the
                  * one place every quit path (menu Close/Quit, WM close
                  * button, typed `xschem exit`) funnels through before the
                  * process dies. Logged with closewindow+force so a sourced
                  * full-session replay terminates deterministically, with no
                  * confirm dialog. */
                 log_action("xschem exit closewindow force");
                 my_snprintf(s, S(s), "exit %s", exit_status); /* xwin_exit() saves window geometry */
                 tcleval(s);
               }
               else {
                 if(has_x) tcleval("store_geom [xschem get topwindow] [xschem get current_name]");
                 clear_schematic(0, 0);
               }
            }
          }
        }
      } else {
        if(force) set_modify(0); /* avoid ask to save downstream */
        if(has_x) tcleval("store_geom [xschem get topwindow] [xschem get current_name]");
        new_schematic("destroy", xctx->current_win_path, NULL, 1);
      }
      Tcl_SetResult(interp, my_itoa(get_window_count()), TCL_VOLATILE);
    }

    /* expandlabel lab
     *   Expand vectored labels/instance names:
     *   xschem expandlabel {2*A[3:0]} --> A[3],A[2],A[1],A[0],A[3],A[2],A[1],A[0] 8
     *   last field is the number of bits
     *   since [ and ] are TCL special characters argument must be quoted with { and } */
    else if(!strcmp(argv[1], "expandlabel"))
    {
      int tmp;
      size_t llen;
      char *result=NULL;
      const char *l;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        l = expandlabel(argv[2], &tmp);
        llen = strlen(l);
        dbg(1, "l=%s\n", l ? l : "<NULL>");
        result = my_malloc(_ALLOC_ID_, llen + 30);
        my_snprintf(result, llen + 30, "%s %d", l, tmp);
        Tcl_SetResult(interp, result, TCL_VOLATILE);
        my_free(_ALLOC_ID_, &result);
      }
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem f...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 2). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_f(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* fill_reset [nodraw]
     *   After setting tcl array pixdata(n) reset fill patterns on all layers
     *   If 'nodraw' is given do not redraw window.
     */
    if(!strcmp(argv[1], "fill_reset"))
    {
      int dr = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      init_pixdata();
      free_gc();
      create_gc();
      enable_layers();
      build_colors(0.0, 0.0);
      resetwin(1, 0, 1, 0, 0);  /* recreate pixmap. resetwin(create_pixmap, clear_pixmap, force, w, h) */
      if(argc > 2 && !strcmp(argv[2], "nodraw")) dr = 0;
      if(dr) draw();
    }
    /* fill_type n fill_type [nodraw]
     *   Set fill type for layer 'n', fill_type may be 'solid' or 'stipple' or 'empty'
     *   If 'nodraw' is given do not redraw window.
     */
    else if(!strcmp(argv[1], "fill_type"))
    {
      int dr = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
        int n = atoi(argv[2]);
        if(n >=0 && n < cadlayers) {
          if(!strcmp(argv[3], "solid")) xctx->fill_type[n]=1;
          else if(!strcmp(argv[3], "stipple")) xctx->fill_type[n]=2;
          else if(!strcmp(argv[3], "empty")) xctx->fill_type[n]=0;
          free_gc();
          create_gc();
          enable_layers();
          build_colors(0.0, 0.0);
          resetwin(1, 0, 1, 0, 0);  /* recreate pixmap. resetwin(create_pixmap, clear_pixmap, force, w, h) */
          if(argc > 4 && !strcmp(argv[4], "nodraw")) dr = 0;
          if(dr) draw();
        }
      }
    }

    /* find_nth string sep quote keep_quote n
     *   Find n-th field string separated by characters in sep. 1st field is in position 1
     *   do not split quoted fields (if quote characters are given) and return unquoted.
     *   xschem find_nth {aaa,bbb,ccc,ddd} {,} 2  --> bbb
     *   xschem find_nth {aaa, "bbb, ccc" , ddd} { ,} {"} 2  --> bbb, ccc
     */
    else if(!strcmp(argv[1], "find_nth"))
    {
      if(argc > 6) {
        Tcl_SetResult(interp, find_nth(argv[2], argv[3], argv[4], atoi(argv[5]), atoi(argv[6])), TCL_VOLATILE);
      }
    }

    /* flip [x0 y0]
     *   Flip selection horizontally around point x0 y0.
     *   if x0, y0 not given use mouse coordinates */
    else if(!strcmp(argv[1], "flip"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* flip-during-move/copy: mirror the whole in-flight selection about the shared gesture pivot.
       * These two mid-gesture arms stay RAW -- they are sub-steps of a move/copy logged at that
       * gesture's END (issue 0069), NOT the standalone verb, so they must NOT cross the
       * perform_action boundary (routing them would spuriously emit `xschem flip x y` mid-drag and
       * double-count the move-END line). They need no readonly gate: being in STARTMOVE/STARTCOPY
       * means an edit is already in progress, impossible on a read-only schematic, and the only
       * commit path `xschem move_objects end` is itself readonly-refused at the move_objects command
       * gate (covering start/step/end/abort). */
      if(xctx->ui_state & STARTMOVE) move_objects(FLIP,0,0,0);
      else if(xctx->ui_state & STARTCOPY) copy_objects(FLIP);
      /* standalone verb: the single mutation boundary (Refactor B atom 7, run_core above) owns the
       * readonly gate + the ONE `xschem flip x0 y0` log site (core_log_action formats the pivot) +
       * the rebuild+seed-pivot+START+FLIP+END effect. run_core resolves the pivot from argv[2]/
       * argv[3] (else the mouse coords) exactly as this branch used to, so passing the branch's own
       * argc/argv straight through is byte-identical. The Edit menu (bare `xschem flip`), the context
       * menu and the command palette reach here; the Shift-F key, the Alt-F group transform and the
       * verb-noun apply reach the same boundary from callback.c, each carrying its own pivot. flip is
       * the SECOND arg-carrying verb on the boundary, a near-clone of rotate (atom 6) -- issue 0068's
       * "Shift-F logs nothing" note is now stale (Shift-F logs here too). */
      else return perform_action("flip", argc, argv);
      Tcl_ResetResult(interp);   /* only the mid-gesture arms fall through to here */
    }

    /* flip_in_place
     *   Flip selection horizontally, each object around its center */
    else if(!strcmp(argv[1], "flip_in_place"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* flip-during-move/copy: flip each object about its own center. These two mid-gesture
       * arms stay RAW -- they are sub-steps of a move/copy logged at that gesture's END
       * (issue 0069), NOT the standalone verb, so they must NOT cross the perform_action
       * boundary (routing them would spuriously emit `xschem flip_in_place` mid-drag and
       * double-count the move-END line). They need no readonly gate: being in STARTMOVE/
       * STARTCOPY means an edit is already in progress, which a read-only schematic never
       * permits, and the transform is preview-only -- push_undo/set_modify fire only in
       * move_objects(END), which is itself readonly-refused at the move_objects command gate. */
      if(xctx->ui_state & STARTMOVE) move_objects(FLIP|ROTATELOCAL,0,0,0);
      else if(xctx->ui_state & STARTCOPY) copy_objects(FLIP|ROTATELOCAL);
      /* standalone verb: the single mutation boundary (Refactor B atom 4, run_core above) owns
       * the readonly gate + the ONE `xschem flip_in_place` log site + the rebuild+START+
       * FLIP|ROTATELOCAL+END effect. The Edit menu / context menu / command palette reach here
       * via `xschem flip_in_place`; the Alt-F key + verb-noun apply reach the same boundary from
       * callback.c. Exact mirror of the rotate_in_place branch above. */
      else return perform_action("flip_in_place", argc, argv);
      Tcl_ResetResult(interp);   /* only the mid-gesture arms fall through to here */
    }

    /* flipv [x0 y0]
     *   Flip selection vertically around point x0 y0.
     *   if x0, y0 not given use mouse coordinates */
    else if(!strcmp(argv[1], "flipv"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* flipv-during-move/copy: a net vertical mirror = 180 rotate + horizontal flip of the whole
       * in-flight selection about the shared gesture pivot. These two mid-gesture arms stay RAW --
       * they are sub-steps of a move/copy logged at that gesture's END (issue 0069), NOT the
       * standalone verb, so they must NOT cross the perform_action boundary (routing them would
       * spuriously emit `xschem flipv x y` mid-drag and double-count the move-END line). They need no
       * readonly gate: being in STARTMOVE/STARTCOPY means an edit is already in progress, impossible
       * on a read-only schematic, and the only commit path `xschem move_objects end` is itself
       * readonly-refused at the move_objects command gate (covering start/step/end/abort). */
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
      /* standalone verb: the single mutation boundary (Refactor B atom 8, run_core above) owns the
       * readonly gate + the ONE `xschem flipv x0 y0` log site (core_log_action formats the pivot) +
       * the rebuild+seed-pivot+START+ROTATE+ROTATE+FLIP+END effect (net vertical mirror). run_core
       * resolves the pivot from argv[2]/argv[3] (else the mouse coords) exactly as this branch used
       * to, so passing the branch's own argc/argv straight through is byte-identical. The Edit menu
       * (bare `xschem flipv`), the context menu and the command palette reach here; the Shift-V key
       * and the verb-noun apply reach the same boundary from callback.c, each carrying its own pivot.
       * flipv is the THIRD and LAST arg-carrying pivot verb -- the mirror of flip (atom 7); after atom
       * 8 the whole transform sextet (rotate/flip/flipv x pivot + in-place) is on the boundary. flipv
       * has NO group form (unlike rotate/flip), so callback.c has only two entry sites, not three. */
      else return perform_action("flipv", argc, argv);
      Tcl_ResetResult(interp);   /* only the mid-gesture arms fall through to here */
    }

    /* flipv_in_place
     *   Flip selection vertically, each object around its center */
    else if(!strcmp(argv[1], "flipv_in_place"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* flipv-during-move/copy: a net vertical mirror = a 180 rotate + a horizontal flip, each
       * object about its own centre. These two mid-gesture arms stay RAW -- they are sub-steps
       * of a move/copy logged at that gesture's END (issue 0069), NOT the standalone verb, so
       * they must NOT cross the perform_action boundary (routing them would spuriously emit
       * `xschem flipv_in_place` mid-drag and double-count the move-END line). They need no
       * readonly gate: being in STARTMOVE/STARTCOPY means an edit is already in progress, which
       * a read-only schematic never permits, and the transform is preview-only -- push_undo/
       * set_modify fire only in move_objects(END), which is itself readonly-refused at the
       * move_objects command gate. */
      if(xctx->ui_state & STARTMOVE) {
        move_objects(ROTATE|ROTATELOCAL,0,0,0);
        move_objects(ROTATE|ROTATELOCAL,0,0,0);
        move_objects(FLIP|ROTATELOCAL,0,0,0);
      }
      else if(xctx->ui_state & STARTCOPY) {
        copy_objects(ROTATE|ROTATELOCAL);
        copy_objects(ROTATE|ROTATELOCAL);
        copy_objects(FLIP|ROTATELOCAL);
      }
      /* standalone verb: the single mutation boundary (Refactor B atom 5, run_core above) owns
       * the readonly gate + the ONE `xschem flipv_in_place` log site + the rebuild+START+
       * ROTATE|ROTATELOCAL x2 + FLIP|ROTATELOCAL + END effect. The Edit menu / context menu /
       * command palette reach here via `xschem flipv_in_place`; the Alt-V key + verb-noun apply
       * reach the same boundary from callback.c. Mirror of the flip_in_place branch above, but
       * three move_objects calls (net vertical mirror) instead of one. */
      else return perform_action("flipv_in_place", argc, argv);
      Tcl_ResetResult(interp);   /* only the mid-gesture arms fall through to here */
    }

    /* floaters_from_selected_inst
     *   flatten to current level selected instance texts */
    else if(!strcmp(argv[1], "floaters_from_selected_inst"))
    {
      /* Route through the single mutation boundary (Refactor B atom 10, run_core above):
       * the readonly gate + the flatten-texts effect (floaters_from_selected_inst, which
       * owns its OWN push_undo/set_modify/draw) + the ONE bare `xschem floaters_from_selected_inst`
       * log site (core_log_action's DEFAULT %s form) all live in perform_action. The Symbol
       * menu (hand-written -command) and the command palette (raw) reach here via
       * `xschem floaters_from_selected_inst`; there is NO key entry point. NB this branch
       * NEVER HAD a scheduler_readonly_reject -- floaters mutates, so the boundary's generic
       * gate CLOSES a scattered 0041/0051-class read-only gap (it now correctly refuses on a
       * read-only cell), the one deliberate behaviour delta of this atom. */
      return perform_action("floaters_from_selected_inst", argc, argv);
    }

    /* fluid_snapshot arm
     *   Track-D (D6) single-pass harness: arm the fluid gesture START snapshot on the CURRENT
     *   geometry (no drag), so a subsequent `xschem fluid_pass <name>` can run one END-cleanup
     *   pass in isolation. Returns 1 if a valid snapshot was armed (needs fluid_editing on and
     *   >=1 instance pin), else 0. Arm on the PRISTINE scene BEFORE creating the novel copper a
     *   novelty-scoped pass (straighten, ...) is meant to reshape. */
    else if(!strcmp(argv[1], "fluid_snapshot"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 && !strcmp(argv[2], "arm")) {
        int armed = fluid_harness_snapshot_arm();
        Tcl_SetResult(interp, armed ? "1" : "0", TCL_STATIC);
      } else {
        Tcl_SetResult(interp, "usage: xschem fluid_snapshot arm", TCL_STATIC);
        return TCL_ERROR;
      }
    }

    /* fluid_pass <name>
     *   Track-D (D6) single-pass harness: run one END-cleanup pass (by table name: ripup_
     *   foreign_pin_short, prune_shorting_anchor_tails, remove_redundant_loops, prune_anchor_
     *   tails, straighten_reversals, collapse_axis_overshoot_stub, prune_novel_orphan_stub)
     *   against the current schematic. Returns the pass's changed-count, 0 when it fail-safe-
     *   declines (no armed snapshot -- gate enforcement), or errors for an unknown / MANUAL_SITE
     *   name. */
    else if(!strcmp(argv[1], "fluid_pass"))
    {
      int changed;
      char buf[32];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc <= 2) {
        Tcl_SetResult(interp, "usage: xschem fluid_pass <name>", TCL_STATIC);
        return TCL_ERROR;
      }
      changed = fluid_harness_run_pass(argv[2]);
      if(changed < 0) {
        Tcl_SetResult(interp, "xschem fluid_pass: unknown or non-driver (MANUAL_SITE) pass name",
                      TCL_STATIC);
        return TCL_ERROR;
      }
      my_snprintf(buf, S(buf), "%d", changed);
      Tcl_SetResult(interp, buf, TCL_VOLATILE);
    }

    /* fluid_trace start <path> | stop | status
     *   Runtime FLUID_TRACE control for the Help>Debug menu (issue 0123). `start <path>` opens a
     *   fresh (truncated) trace file and enables tracing; `stop` flush+closes and disables; `status`
     *   reports on/off. start returns the open path (or "" on failure), stop the last path -- so the
     *   caller can echo the filename in the CIW. No xctx needed: the trace file is process-global. */
    else if(!strcmp(argv[1], "fluid_trace"))
    {
      if(argc > 2 && !strcmp(argv[2], "start")) {
        const char *p = fltrace_runtime_start(argc > 3 ? argv[3] : NULL);
        Tcl_SetResult(interp, (char *)(p ? p : ""), TCL_VOLATILE);
      } else if(argc > 2 && !strcmp(argv[2], "stop")) {
        const char *p = fltrace_runtime_stop();
        Tcl_SetResult(interp, (char *)(p ? p : ""), TCL_VOLATILE);
      } else if(argc > 2 && !strcmp(argv[2], "status")) {
        Tcl_SetResult(interp, fluid_trace_on() ? "on" : "off", TCL_STATIC);
      } else {
        Tcl_SetResult(interp, "usage: xschem fluid_trace start <path> | stop | status", TCL_STATIC);
        return TCL_ERROR;
      }
    }

    /* flylines net <name> | at <x> <y>
     *   Read-only net-connectivity query backing the hover fly-line overlay
     *   (doc/claude/specs/hover_flylines.md, suggestions/flyline_implementation_plan.md).
     *   Returns a Tcl dict: net {N} members {{type n pin x y}...} clusters {...} segments {...}.
     *   INVARIANT (C1): pure read-only -- must NEVER write hilight_table, inst.color, .sel,
     *   the modify flag, or saved bytes. A0: skeleton (empty dict). */
    else if(!strcmp(argv[1], "flylines"))
    {
      const char *netname = NULL;   /* points into xctx data; do not free */
      Selected pick; int have_pick = 0;   /* the hovered object (at-form), used to pick the hub */
      double mx = 0.0, my = 0.0;    /* at-form pointer coords (the cursor hub); unused by net-form */
      FlyResult res;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp,
                      "usage: xschem flylines net <name> | at <x> <y> | shown | origin | seg0",
                      TCL_STATIC);
        return TCL_ERROR;
      }
      /* `flylines shown`: introspect the on-screen overlay (Track B) -- the net whose fly-line
       * star is currently drawn, or "" if none. Read-only; no netlist needed. */
      if(!strcmp(argv[2], "shown")) {
        Tcl_SetResult(interp, xctx->fly_shown_net ? xctx->fly_shown_net : "", TCL_VOLATILE);
        return TCL_OK;
      }
      /* `flylines origin`: the world-coord ORIGIN (hub point) of the star currently drawn on
       * screen -- fly_seg[0],fly_seg[1] -- or "" when nothing is drawn. Lets a render test observe
       * that the drawn origin tracks the cursor (the `shown` net name alone cannot). Read-only. */
      if(!strcmp(argv[2], "origin")) {
        char ob[128];
        if(xctx->fly_nseg > 0 && xctx->fly_seg)
          my_snprintf(ob, S(ob), "%.16g %.16g", xctx->fly_seg[0], xctx->fly_seg[1]);
        else ob[0] = '\0';
        Tcl_SetResult(interp, ob, TCL_VOLATILE);
        return TCL_OK;
      }
      /* `flylines seg0`: the full first drawn segment "x1 y1 x2 y2" (origin -> its destination),
       * or "" when none. Exposes the DESTINATION too, so a render test can catch a cheap-slide
       * that keeps stale destinations (e.g. an over-broad hub-cluster match). Read-only. */
      if(!strcmp(argv[2], "seg0")) {
        char ob[128];
        if(xctx->fly_nseg > 0 && xctx->fly_seg)
          my_snprintf(ob, S(ob), "%.16g %.16g %.16g %.16g",
                      xctx->fly_seg[0], xctx->fly_seg[1], xctx->fly_seg[2], xctx->fly_seg[3]);
        else ob[0] = '\0';
        Tcl_SetResult(interp, ob, TCL_VOLATILE);
        return TCL_OK;
      }
      prepare_netlist_structs(0);   /* populate wire[].node / inst[].node / node_table */
      if(!strcmp(argv[2], "net")) {
        if(argc < 4) {
          Tcl_SetResult(interp, "usage: xschem flylines net <name>", TCL_STATIC);
          return TCL_ERROR;
        }
        /* validate the name is a real net in this schematic (same test hilight_netname uses) */
        if(bus_node_hash_lookup(argv[3], "", XLOOKUP, 0, "", "", "", "")) netname = argv[3];
      } else if(!strcmp(argv[2], "at")) {
        if(argc < 5) {
          Tcl_SetResult(interp, "usage: xschem flylines at <x> <y>", TCL_STATIC);
          return TCL_ERROR;
        } else {
          mx = atof(argv[3]); my = atof(argv[4]);   /* the (x,y) IS the "mouse": cursor hub */
          pick = find_closest_obj(mx, my, 1);
          have_pick = 1;
          netname = flyline_net_of(pick.type, pick.n, pick.col);
        }
      } else {
        Tcl_SetResult(interp, "usage: xschem flylines net <name> | at <x> <y>", TCL_STATIC);
        return TCL_ERROR;
      }
      /* All connectivity / clustering / segment logic lives in flyline.c (shared verbatim with
       * the on-screen overlay). flyline_compute() is pure read-only (invariant C1); here we only
       * format its FlyResult into the query dict:
       *   net {N} global 0|1 capped 0|1 members {{kind idx pin x y}...}
       *   clusters {{members {idx...} anchor {x y}}...} segments {{x1 y1 x2 y2}...}. */
      flyline_compute(netname, have_pick, have_pick ? &pick : NULL, mx, my, &res);
      {
        Tcl_DString memds, cluds, segds;
        char buf[128];
        int a, c, m;
        Tcl_DStringInit(&memds);
        Tcl_DStringInit(&cluds);
        Tcl_DStringInit(&segds);
        /* members in build order (list index == member handle) */
        for(a = 0; a < res.nmem; ++a) {
          my_snprintf(buf, S(buf), "%s{%s %d %d %.16g %.16g}", Tcl_DStringLength(&memds) ? " " : "",
                      res.mem[a].kind == 0 ? "wire" : "pin", res.mem[a].idx, res.mem[a].pin,
                      res.mem[a].x, res.mem[a].y);
          Tcl_DStringAppend(&memds, buf, -1);
        }
        /* one {members {..} anchor {x y}} per cluster, in ordinal order */
        for(c = 0; c < res.nclu; ++c) {
          int first = 1;
          Tcl_DStringAppend(&cluds, c ? " {members {" : "{members {", -1);
          for(m = 0; m < res.nmem; ++m) {
            if(res.clu[m] != c) continue;
            my_snprintf(buf, S(buf), "%s%d", first ? "" : " ", m);
            Tcl_DStringAppend(&cluds, buf, -1);
            first = 0;
          }
          my_snprintf(buf, S(buf), "} anchor {%.16g %.16g}}", res.cx[c], res.cy[c]);
          Tcl_DStringAppend(&cluds, buf, -1);
        }
        /* star segments hub -> nearest other clusters */
        for(a = 0; a < res.nseg; ++a) {
          my_snprintf(buf, S(buf), "%s{%.16g %.16g %.16g %.16g}", Tcl_DStringLength(&segds) ? " " : "",
                      res.sx1[a], res.sy1[a], res.sx2[a], res.sy2[a]);
          Tcl_DStringAppend(&segds, buf, -1);
        }
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "net {", res.net ? res.net : "",
                         "} global ", res.is_global ? "1" : "0", " capped ", res.capped ? "1" : "0",
                         " members {", Tcl_DStringValue(&memds), "} clusters {",
                         Tcl_DStringValue(&cluds), "} segments {",
                         Tcl_DStringValue(&segds), "}", NULL);
        Tcl_DStringFree(&memds);
        Tcl_DStringFree(&cluds);
        Tcl_DStringFree(&segds);
      }
      flyline_result_free(&res);
    }

    /* fullscreen
     *   Toggle fullscreen modes: fullscreen with menu & status, fullscreen, normal */
    else if(!strcmp(argv[1], "fullscreen"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) toggle_fullscreen(argv[2]);
      else toggle_fullscreen(".drw");
      Tcl_ResetResult(interp);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem g...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 2). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_g(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
  int i;
    /************ xschem get subcommands *************/
    /* get var
     *   Get C variable/constant 'var' */
    if(!strcmp(argv[1], "get"))
    {
      if(argc > 2) {
        switch(argv[2][0]) {
          case 'a':
          if(!strcmp(argv[2], "actionlog_filename")) { /* path of the open action log, empty if disabled */
            Tcl_SetResult(interp, actionlog_filename, TCL_VOLATILE);
          }
          /* the sibling of `get rects` / `get lines` / `get polygons`, which existed;
           * `get arcs` did not, so a Tcl caller asking for an arc count got the empty
           * string with rc 0 (an unknown `get` does not error). Added for the issue-0172
           * emptiness legs, which must assert the arc they placed survived the open. */
          else if(!strcmp(argv[2], "arcs")) { /* (xschem get arcs n) number of arcs on layer 'n' */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 3) {
              int c = atoi(argv[3]);
              if(c >=0 && c < cadlayers) {
                Tcl_SetResult(interp, my_itoa(xctx->arcs[c]),TCL_VOLATILE);
              } else {
                Tcl_SetResult(interp, "xschem get arcs n: layer number out of range", TCL_STATIC);
                return TCL_ERROR;
              }
            } else {
              Tcl_SetResult(interp, "xschem get arcs n: give a layer number", TCL_STATIC);
              return TCL_ERROR;
            }
          }
          break;

          case 'b':
          if(!strcmp(argv[2], "backlayer")) { /* number of background layer */
            Tcl_SetResult(interp, my_itoa(BACKLAYER), TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "bbox")) { /* bounding box schematic */
            xRect boundbox;
            char res[2048];
            calc_drawing_bbox(&boundbox, 0);
            my_snprintf(res, S(res), "%g %g %g %g", boundbox.x1, boundbox.y1, boundbox.x2, boundbox.y2);
            Tcl_SetResult(interp, res, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "bbox_hilighted")) { /* bounding box of highlinhted objects */
            xRect boundbox;
            char res[2048];
            calc_drawing_bbox(&boundbox, 2);
            my_snprintf(res, S(res), "%g %g %g %g", boundbox.x1, boundbox.y1, boundbox.x2, boundbox.y2);
            Tcl_SetResult(interp, res, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "bbox_selected")) { /* bounding box of selected objects */
            xRect boundbox;
            char res[2048];
            calc_drawing_bbox(&boundbox, 1);
            my_snprintf(res, S(res), "%g %g %g %g", boundbox.x1, boundbox.y1, boundbox.x2, boundbox.y2);
            Tcl_SetResult(interp, res, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "build_date")) { /* time and date this file was built. */
            char date[] =  __DATE__ " : "  __TIME__;
            Tcl_SetResult(interp, date,  TCL_STATIC);
          }
          break;
          case 'c':
          if(!strcmp(argv[2], "cadlayers")) { /* number of layers */
            Tcl_SetResult(interp, my_itoa(cadlayers), TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "case_insensitive")) { /* case_insensitive symbol matching */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->case_insensitive), TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "change_lw")) { /* change line width when zooming */
            if(xctx->change_lw != 0 ) Tcl_SetResult(interp, "1",TCL_STATIC);
            else Tcl_SetResult(interp, "0",TCL_STATIC);
          }
          else if(!strcmp(argv[2], "color_ps")) { /* color postscript flag */
            if(color_ps != 0 ) Tcl_SetResult(interp, "1",TCL_STATIC);
            else Tcl_SetResult(interp, "0",TCL_STATIC);
          }
          else if(!strcmp(argv[2], "constr_mv")) { /* color postscript flag */
            if(xctx->constr_mv != 0 ) Tcl_SetResult(interp, "1",TCL_STATIC);
            else Tcl_SetResult(interp, "0",TCL_STATIC);
          }
          else if(!strcmp(argv[2], "current_dirname")) { /* directory name of current design */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, xctx->current_dirname, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "current_name")) { /* name of current design (no library path) */
            /* optional <win> arg: read that window's context via the Phase-A context-borrow
             * primitive (no GUI side effects), then restore. Doubles as the borrow probe. */
            Xschem_ctx *borrowed = NULL;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 3) borrowed = net_hilight_borrow_ctx(argv[3]);
            Tcl_SetResult(interp, xctx->current_name, TCL_VOLATILE); /* copies before restore */
            net_hilight_restore_ctx(borrowed);
          }
          /* (issue 0207) a byte-equivalent `actionlog_filename` arm used to sit here, under
           * `case 'c':`. The outer switch is on argv[2][0], so this arm was unreachable dead
           * code -- the live one is under `case 'a':` above. Removed, not moved. */
          else if(!strcmp(argv[2], "current_win_path")) { /* path of current tab/window (.drw, .x1.drw, ...) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, xctx->current_win_path, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "currsch")) { /* hierarchy level of current schematic (start at 0) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->currsch),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "cursor1_x")) { /* cursor 1 position */
            char c[70];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(c, S(c), "%g", xctx->graph_cursor1_x);
            Tcl_SetResult(interp, c, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "cursor2_x")) { /* cursor 2 position */
            char c[70];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(c, S(c), "%g", xctx->graph_cursor2_x);
            Tcl_SetResult(interp, c, TCL_VOLATILE);
          }
          break;
          case 'd':
          if(!strcmp(argv[2], "deltax")) { /* current move/copy gesture x delta (diagnostic) */
            char s[128];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(s, S(s), "%.16g", xctx->deltax);
            Tcl_SetResult(interp, s, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "deltay")) { /* current move/copy gesture y delta (diagnostic) */
            char s[128];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(s, S(s), "%.16g", xctx->deltay);
            Tcl_SetResult(interp, s, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "debug_var")) { /* debug level (0 = no debug, 1, 2, 3,...) */
            Tcl_SetResult(interp, my_itoa(debug_var),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "draw_window")) { /* direct draw into window */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->draw_window),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "drawwindowid")) { /* X Window id this context draws into; compare numerically to [winfo id <canvas>] */
            char b[32];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(b, S(b), "%u", (unsigned int)xctx->window); /* XIDs fit in 32 bits; my_snprintf has no %lx */
            Tcl_SetResult(interp, b, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "drawcount")) { /* monotonic count of full draw() runs; a test seam to detect a (missing) redraw */
            char b[32];
            my_snprintf(b, S(b), "%u", draw_count);
            Tcl_SetResult(interp, b, TCL_VOLATILE);
          }
          break;
          case 'e':
          if(!strcmp(argv[2], "editing_symbol_view")) {
            /* 1 if the current view is a symbol (.sym), else 0. The AUTHORITATIVE test
             * (checks the real loaded path xctx->sch[currsch]), unlike a `*.sym` match on
             * `current_name`: a library-manager symbol displays as the extension-less
             * "lib/cell" reference (rel_sym_path -> lib_qualified_rel), so a name-string
             * match wrongly reports "schematic" and mis-routes the view-aware Add-Pin verb
             * (addpin::place_verb) to add_sch_pin, a no-op in a symbol view. */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(editing_symbol_view()),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "en_pin_select")) { /* 1 if clicking a pin selects it (pin_selection.md) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->en_pin_select),TCL_VOLATILE);
          }
          break;
          case 'f':
          if(!strcmp(argv[2], "first_sel")) { /* get data about first selected object */
            char res[40];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(res, S(res), "%hu %d %u", xctx->first_sel.type, xctx->first_sel.n, xctx->first_sel.col);
            Tcl_SetResult(interp, res, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "fix_broken_tiled_fill")) { /* get drawing method setting (for broken GPUs) */
            Tcl_SetResult(interp, my_itoa(fix_broken_tiled_fill),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "fix_mouse_coord")) { /* get fix_mouse_coord setting (fix for broken RDP)*/
            Tcl_SetResult(interp, my_itoa(fix_mouse_coord),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "format")) { /* alternate format attribute to use in netlist (or NULL) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(!xctx->custom_format ) Tcl_SetResult(interp, "<NULL>",TCL_STATIC);
            else Tcl_SetResult(interp, xctx->custom_format,TCL_VOLATILE);
          }
          break;
          case 'g':
          if(!strcmp(argv[2], "graph_lastsel")) { /* number of last graph that was clicked */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->graph_lastsel),TCL_VOLATILE);
          }
          /* xschem get graph_flags
           * The per-session graph interaction flag word (xctx->graph_flags): bits
           * 2/4 = x-cursor A/B drawn, 16/32 = x-cursor A/B being MOVED (grabbed),
           * 64 = measurement tooltip, 128/256 = y-cursor 1/2 drawn, 512/1024 =
           * y-cursor 1/2 being moved. Authoritative legend: callback.c
           * (waves_callback's header comment). NOT xRect.flags, which is the
           * per-graph type/lock word (landmine 6).
           * Added so the ASE viewer's LMB drag-to-reorder seam can tell "this
           * press grabbed a cursor" from "this press landed on empty waveform
           * space" without mirroring cursor state in Tcl (reference backlog #1).
           * Reads a scalar, no side effects — safe to call from a binding. */
          else if(!strcmp(argv[2], "graph_flags")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa((int)xctx->graph_flags), TCL_VOLATILE);
          }
          /* xschem get graph_near_wave <graph_idx> <px> <py> [tol]
           * 1 when the CANVAS PIXEL (px,py) is within `tol` screen pixels
           * (default GRAPH_TRACE_PICK_TOL, 10 -- the one tolerance every
           * trace-picking surface on a strip shares, xschem.h) of a displayed
           * trace of graph <graph_idx>, else 0.
           * Uses the engine's own transform + raw data (draw.c graph_near_wave),
           * so the caller never re-derives the plot box margins in Tcl.
           * The ASE viewer's trace-exclusion zone: near-trace LMB stays with the
           * C engine (cursor grab, wave-bold), empty body space belongs to strip
           * drag-reordering. Deliberately takes the EVENT's pixels rather than the
           * C mouse mirror, which is stale for a press with no preceding Motion. */
          else if(!strcmp(argv[2], "graph_near_wave")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 5) {
              double tol = (argc > 6) ? atof(argv[6]) : GRAPH_TRACE_PICK_TOL;
              Tcl_SetResult(interp,
                my_itoa(graph_near_wave(atoi(argv[3]), atof(argv[4]), atof(argv[5]), tol)),
                TCL_VOLATILE);
            } else {
              Tcl_SetResult(interp, "0", TCL_STATIC);
            }
          }
          /* xschem get graph_plotbox_at <graph_idx> <px> <py>
           * 1 when the CANVAS PIXEL (px,py) is inside graph <graph_idx>'s PLOT
           * BOX -- the rectangle delineated by the two axes and the two lines
           * opposite them -- else 0. NOT a distance to a trace: the whole
           * interior answers 1, the legend/label margins around it answer 0.
           * Exposes draw.c's graph_plotbox_at (viewer plan item 9's snap-cursor
           * gate) unchanged, INCLUDING its refusals: a bad index, a non-graph
           * rect, an off-screen graph, a DIGITAL strip or no loaded data all
           * answer 0.
           * The ASE viewer's strip context menu (item 8) uses it to stay OUT of
           * the label margin, where a Button3 press is already the wave
           * attributes dialog (callback.c ~896). Tcl cannot re-derive the box:
           * the margins come from the engine's own transform. */
          else if(!strcmp(argv[2], "graph_plotbox_at")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 5) {
              Tcl_SetResult(interp,
                my_itoa(graph_plotbox_at(atoi(argv[3]), atof(argv[4]), atof(argv[5]))),
                TCL_VOLATILE);
            } else {
              Tcl_SetResult(interp, "0", TCL_STATIC);
            }
          }
          /* xschem get graph_trace_at <graph_idx> <px> <py> [tol]
           * The NODE INDEX (position in the graph's `node` prop token, the same
           * index space as `hilight_wave` / find_closest_wave's node_number) of
           * the trace passing within `tol` screen pixels (default
           * GRAPH_TRACE_PICK_TOL, 10 -- shared with the RMB trace menu, the LMB
           * trace drag and the LMB wave-bold click, xschem.h) of the CANVAS
           * PIXEL (px,py); -1 when none is that close. Nearest wins.
           * Same engine-side machinery as graph_near_wave above (draw.c
           * graph_wave_at), which is the same query without the identity: the
           * ASE viewer uses this one to pick up a trace and drag it onto another
           * strip. Read-only: no highlight, no prop mutation, no redraw. */
          /* xschem get graph_legend_at <graph_idx> <px> <py>
           * The NODE INDEX of the LEGEND entry under the CANVAS PIXEL (px,py),
           * or -1. The legend's own hit test, extracted out of
           * edit_wave_attributes() by issue 0175 so both mouse buttons and Tcl
           * share one answer -- before that it existed only fused to the
           * Button3 action, which is why two comments in wave_viewer.tcl used to
           * say the engine had "no C hit-test API" for the legend.
           * All THREE legend layouts (vertical, digital, horizontal). It does
           * NOT refuse digital strips, unlike graph_plotbox_at / graph_trace_at:
           * a digital strip's body answers -1 everywhere, so its legend is the
           * only place a trace can be picked at all.
           * ⚠ The `node` token, hence this index space, counts NODES, not model
           * traces (landmine 34). Fails closed: a bad index, a non-graph rect,
           * an off-screen graph, `legend=0` or a strip with no `node` token all
           * answer -1. Read-only: no highlight, no prop mutation, no redraw. */
          else if(!strcmp(argv[2], "graph_legend_at")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 5) {
              Tcl_SetResult(interp,
                my_itoa(graph_legend_at(atoi(argv[3]), atof(argv[4]), atof(argv[5]))),
                TCL_VOLATILE);
            } else {
              Tcl_SetResult(interp, "-1", TCL_STATIC);
            }
          }
          else if(!strcmp(argv[2], "graph_trace_at")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 5) {
              double tol = (argc > 6) ? atof(argv[6]) : GRAPH_TRACE_PICK_TOL;
              Tcl_SetResult(interp,
                my_itoa(graph_wave_at(atoi(argv[3]), atof(argv[4]), atof(argv[5]), tol)),
                TCL_VOLATILE);
            } else {
              Tcl_SetResult(interp, "-1", TCL_STATIC);
            }
          }
          /* ---- axis-region drag zoom, issue 0190 -------------------------
           * doc/claude/specs/waveform_viewer_modes.md §17. Three getters, all
           * FAIL SOFT (a sentinel + TCL_OK, never an error): the ASE viewer
           * wraps them in `catch` and must read a missing verb as "nothing
           * there", never as "locked out". One vocabulary for the whole
           * feature: "" | x | y.
           *
           * xschem get graph_axis_at <graph_idx> <px> <py>
           *   Which axis-number MARGIN that CANVAS PIXEL is in: "" (neither),
           *   "x" (the bottom margin, the X tick numbers) or "y" (the left
           *   margin, the Y tick numbers). Refuses the plot box, everything
           *   outside the container rect, the reorder-grip column at every
           *   height and any pixel `graph_legend_at` claims (for vlegend=1 and
           *   for digital strips the legend IS the left margin). The bottom-LEFT
           *   corner answers "y", matching the shipped RMB left-margin arm.
           *   ⚠ Unlike graph_plotbox_at it does NOT require a loaded raw and
           *   does NOT refuse digital strips -- it is pure geometry. */
          else if(!strcmp(argv[2], "graph_axis_at")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_ResetResult(interp);
            if(argc > 5) {
              int ax = graph_axis_at(atoi(argv[3]), atof(argv[4]), atof(argv[5]));
              if(ax == GRAPH_AXIS_X) Tcl_SetResult(interp, "x", TCL_STATIC);
              else if(ax == GRAPH_AXIS_Y) Tcl_SetResult(interp, "y", TCL_STATIC);
            }
          }
          /* xschem get graph_axis_map <graph_idx> x|y <p0> <p1>
           * The new data window `{lo hi}` a drag from canvas pixel <p0> to <p1>
           * along that axis produces, or {} when the travel is at or below the
           * click threshold / the index is bad / the graph has no transform.
           * THE FORMULA SEAM: the release arm in callback.c and the
           * graph_axis_zoom verb both call the same graph_axis_map(), so a
           * headless suite driving this verb is driving the gesture's own
           * arithmetic -- including BOTH endpoints, which is what a width-only
           * implementation gets wrong.
           * ⚠ The threshold comes from graph_click_tol(), NOT from a literal
           * here. It is the same number the gesture passes (callback.c's
           * file-private GRAPH_CLICK_TOL, kept out of the header so it is not
           * read as GRAPH_TRACE_PICK_TOL's twin); a copy of the VALUE at this
           * seam would let the getter and the gesture disagree silently, which
           * is landmine 45(a) and exactly what the AS* legs exist to prevent. */
          else if(!strcmp(argv[2], "graph_axis_map")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_ResetResult(interp);
            if(argc > 6) {
              int ax = GRAPH_AXIS_NONE;
              double lo = 0.0, hi = 0.0;
              if(argv[4][0] == 'x') ax = GRAPH_AXIS_X;
              else if(argv[4][0] == 'y') ax = GRAPH_AXIS_Y;
              if(graph_axis_map(atoi(argv[3]), ax, atof(argv[5]), atof(argv[6]),
                                &lo, &hi, graph_click_tol())) {
                char res[100];
                my_snprintf(res, S(res), "%.17g %.17g", lo, hi);
                Tcl_SetResult(interp, res, TCL_VOLATILE); /* copies: stack buf is fine */
              }
            }
          }
          /* xschem get graph_axis_wheel_map <graph_idx> x|y <p> in|out
           * The new data window `{lo hi}` ONE CTRL+wheel click at canvas pixel
           * <p> along that axis produces, or {} for an unknown axis word, an
           * unknown direction word, a bad index, a non-graph rect or a graph
           * with no transform (issue 0191, §18).
           * THE FORMULA SEAM, exactly as graph_axis_map above: the Ctrl+wheel
           * arm in callback.c and this getter call the same
           * graph_axis_wheel_map(), so a headless suite driving this verb drives
           * the gesture's own arithmetic -- including the ANCHOR, which is what
           * a width-only implementation gets wrong and what no "the range
           * shrank" assertion can see.
           * ⚠ The DIRECTION WORD is the input, never a factor: the step lives in
           * GRAPH_AXIS_WHEEL_FACTOR inside the formula, so the constant has
           * exactly one home and this seam cannot drive a different step size
           * from the product (landmine 45(a)). */
          else if(!strcmp(argv[2], "graph_axis_wheel_map")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_ResetResult(interp);
            if(argc > 6) {
              int ax = GRAPH_AXIS_NONE, dir = 0;
              double lo = 0.0, hi = 0.0;
              if(!strcmp(argv[4], "x")) ax = GRAPH_AXIS_X;
              else if(!strcmp(argv[4], "y")) ax = GRAPH_AXIS_Y;
              if(!strcmp(argv[6], "in") || !strcmp(argv[6], "up")) dir = 1;
              else if(!strcmp(argv[6], "out") || !strcmp(argv[6], "down")) dir = -1;
              if(dir && graph_axis_wheel_map(atoi(argv[3]), ax, atof(argv[5]), dir, &lo, &hi)) {
                char res[100];
                my_snprintf(res, S(res), "%.17g %.17g", lo, hi);
                Tcl_SetResult(interp, res, TCL_VOLATILE); /* copies: stack buf is fine */
              }
            }
          }
          /* xschem get graph_axis_drag
           * What the last press ARMED: "" (nothing) | "x" | "y". The
           * `graph_marker_drag` twin, and read the same way: the ASE viewer's
           * press seam consults it to decide that C owns the whole gesture
           * (wviewer::axis_grabbed), instead of hit-testing the margins in Tcl
           * and growing a second source of truth for the plot box. */
          else if(!strcmp(argv[2], "graph_axis_drag")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_ResetResult(interp);
            if(xctx->graph_axis_drag == GRAPH_AXIS_X) Tcl_SetResult(interp, "x", TCL_STATIC);
            else if(xctx->graph_axis_drag == GRAPH_AXIS_Y) Tcl_SetResult(interp, "y", TCL_STATIC);
          }
          /* ---- waveform markers, doc/claude/specs/graph_markers.md ----
           * Four read-only getters, all FAIL SOFT (a sentinel + TCL_OK on a
           * short or bad query, never an error): the ASE viewer wraps them in
           * `catch` + `string is integer -strict` and must be able to treat a
           * missing/erroring verb as "nothing there", never as "locked out". */

          /* xschem get graph_marker_at <graph_idx> <px> <py> [tol]
           * Which marker is under that CANVAS PIXEL, and WHICH PART of it:
           * "" (nothing) | "<num> anchor" | "<num> label". The part matters
           * because the two drive DIFFERENT drags -- the anchor slides along its
           * trace, the label just moves. Default tol = GRAPH_MARKER_TOL. */
          else if(!strcmp(argv[2], "graph_marker_at")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 5) {
              int part = 0, num;
              double tol = (argc > 6) ? atof(argv[6]) : GRAPH_MARKER_TOL;
              num = graph_marker_at(atoi(argv[3]), atof(argv[4]), atof(argv[5]), tol, &part);
              if(num > 0 && part) {
                char res[80];
                my_snprintf(res, S(res), "%d %s", num, part == 1 ? "anchor" : "label");
                Tcl_SetResult(interp, res, TCL_VOLATILE);
              } else {
                Tcl_ResetResult(interp);
              }
            } else {
              Tcl_ResetResult(interp);
            }
          }
          /* xschem get graph_marker_drag -> 0 none | 1 anchor drag | 2 label drag.
           * The cursor_grabbed twin: the ASE press seam consults it to decide
           * that C owns the whole gesture. */
          else if(!strcmp(argv[2], "graph_marker_drag")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->graph_marker_drag), TCL_VOLATILE);
          }
          /* xschem get graph_marker_sel -> the selected marker number, -1 = none.
           * THE HEAD of the set below; unchanged by issue 0189 on purpose. */
          else if(!strcmp(argv[2], "graph_marker_sel")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->graph_marker_sel), TCL_VOLATILE);
          }
          /* xschem get graph_marker_sel_set -> the WHOLE selection as marker
           * numbers, HEAD FIRST, space separated ("2 1"); "" when nothing is
           * selected (issue 0189). Never an error -- fails soft like its four
           * neighbours. The set is UI state and is never in a prop token. */
          else if(!strcmp(argv[2], "graph_marker_sel_set")) {
            int k;
            char nbuf[32];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_ResetResult(interp);
            for(k = 0; k < xctx->graph_marker_n_sel; k++) {
              my_snprintf(nbuf, S(nbuf), "%d", xctx->graph_marker_sel_set[k]);
              Tcl_AppendElement(interp, nbuf);
            }
          }
          /* xschem get graph_rects -> how many layer-2 rects are GRAPHS.
           * Not the same as `xschem get rects 2` (every rect on the layer): the
           * ASE marker push hook uses this for its model<->rect 1:1 guard, and a
           * single stray non-graph GRIDLAYER rect would permanently disable it. */
          else if(!strcmp(argv[2], "graph_rects")) {
            int gi, cnt = 0;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            for(gi = 0; gi < xctx->rects[GRIDLAYER]; gi++)
              if(xctx->rect[GRIDLAYER][gi].flags & 1) cnt++;
            Tcl_SetResult(interp, my_itoa(cnt), TCL_VOLATILE);
          }
          /* viewer plan item 9: the snap cursor's current pick, for item 10's
           * status bar. "<graph-index> <node-index> <x> <y>" with x/y the RAW
           * sample values, or "" when nothing is snapped. Read-only, and it
           * NEVER runs the query itself -- it reports what the hover pump last
           * found, so polling it from Tcl costs nothing. */
          else if(!strcmp(argv[2], "graph_snap")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(!xctx->graph_snap_on) {
              Tcl_SetResult(interp, "", TCL_STATIC);
            } else {
              char s[200];
              my_snprintf(s, S(s), "%d %d %.10g %.10g", xctx->graph_snap_gi,
                          xctx->graph_snap_wave, xctx->graph_snap_x, xctx->graph_snap_y);
              Tcl_SetResult(interp, s, TCL_VOLATILE);
            }
          }
          /* xschem get graph_preview
           * Viewer plan item 6, the read-back seam: `<gi> <wave> <scale>` while
           * a shrink preview is armed, else the single word `0`. */
          else if(!strcmp(argv[2], "graph_preview")) {
            char s[128];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(xctx->graph_preview_scale == 0.0) {
              Tcl_SetResult(interp, "0", TCL_STATIC);
            } else {
              my_snprintf(s, S(s), "%d %d %.10g", xctx->graph_preview_gi,
                          xctx->graph_preview_wave, xctx->graph_preview_scale);
              Tcl_SetResult(interp, s, TCL_VOLATILE);
            }
          }
          /* xschem get graph_preview_set -> the WHOLE previewed set as
           * "<gi> <ni> <gi> <ni> ...", HEAD FIRST; "" when nothing is armed
           * (issue 0192). The graph_marker_sel_set idiom above, for the same
           * reason: the HEAD getter keeps its shipped output shape and the set
           * is read through a NEW verb, so every assertion resting on the old
           * one stays byte-identical. Never an error -- fails soft. */
          else if(!strcmp(argv[2], "graph_preview_set")) {
            int k;
            char nbuf[32];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_ResetResult(interp);
            for(k = 0; k < xctx->graph_preview_n; k++) {
              my_snprintf(nbuf, S(nbuf), "%d", xctx->graph_preview_set_gi[k]);
              Tcl_AppendElement(interp, nbuf);
              my_snprintf(nbuf, S(nbuf), "%d", xctx->graph_preview_set_wave[k]);
              Tcl_AppendElement(interp, nbuf);
            }
          }
          else if(!strcmp(argv[2], "graph_snap_cursor")) { /* item 9: per-window snap arming */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, xctx->graph_snap != 0 ? "1" : "0", TCL_STATIC);
          }
          else if(!strcmp(argv[2], "gridlayer")) { /* layer number for grid */
            Tcl_SetResult(interp, my_itoa(GRIDLAYER),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "gc_line_style")) {
            /* Cached X line_style of a layer GC (0=LineSolid, 1=LineOnOffDash,
             * 2=LineDoubleDash; -1 = no X / bad layer). Test seam: draw_selection() strokes
             * the grey selection overlay with gc[SELLAYER], which aliases gc[GRIDLAYER]
             * (both == layer 2). A grid toggle must leave it LineSolid; see
             * doc/claude/issues/0082-grid-toggle-corrupts-selection-gc.md.
             * Usage: xschem get gc_line_style [<layer>]  (default SELLAYER) */
            int ly = (argc > 3) ? atoi(argv[3]) : SELLAYER;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(!has_x || ly < 0 || ly >= cadlayers) {
              Tcl_SetResult(interp, "-1", TCL_STATIC);
            } else {
              XGCValues gcv;
              XGetGCValues(display, xctx->gc[ly], GCLineStyle, &gcv);
              Tcl_SetResult(interp, my_itoa(gcv.line_style), TCL_VOLATILE);
            }
          }
          break;
          case 'h':
          if(!strcmp(argv[2], "help")) { /* command help */
            if(help != 0 ) Tcl_SetResult(interp, "1",TCL_STATIC);
            else Tcl_SetResult(interp, "0",TCL_STATIC);
          }
          else if(!strcmp(argv[2], "header_text")) { /* header metadata (license info etc) present in schematic */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(xctx && xctx->header_text) {
              Tcl_SetResult(interp, xctx->header_text, TCL_VOLATILE);
            } else {
              Tcl_SetResult(interp, "", TCL_VOLATILE);
            }
          }
          else if(!strcmp(argv[2], "hierarchy_modified")) { /* current level OR a dirty ancestor (deep close guard) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(hierarchy_modified()),TCL_VOLATILE);
          }
          /* xschem get hilight_color -> THE CURRENT NET-HIGHLIGHT STYLE CURSOR.
           * `xschem set hilight_color <i>` has existed forever; there was no
           * matching read, so the only way Tcl could observe the cursor was the
           * RETURN VALUE of `incr_hilight_color` / `decr_hilight_color` -- both
           * of which MUTATE it. The waveform viewer's `9` needs "the current
           * style" without moving it (it advances the cursor itself, once, after
           * applying), and a read-modify-read round trip is neither atomic nor
           * safe if it errors in between. Builds the table first, like its two
           * mutating siblings, so a cold read is a real index and not 0 by
           * default. doc/claude/specs/wave_trace_hilight.md D1. */
          else if(!strcmp(argv[2], "hilight_color")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(!xctx->net_hilight_style || xctx->n_net_hilight_styles <= 0) build_net_hilight_styles();
            Tcl_SetResult(interp, my_itoa(xctx->hilight_color), TCL_VOLATILE);
          }
          break;
          case 'i':
          if(!strcmp(argv[2], "infowindow_text")) { /* ERC messages */
            if(xctx && xctx->infowindow_text)
              Tcl_SetResult(interp, xctx->infowindow_text, TCL_VOLATILE);
            else
              Tcl_SetResult(interp, "", TCL_STATIC);
          }

          else if(!strcmp(argv[2], "instances")) { /* number of instances in schematic */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->instances), TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "intuitive_interface")) { /* ERC messages */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->intuitive_interface), TCL_VOLATILE);
          }
          break;
          case 'l':
          if(!strcmp(argv[2], "last_created_window")) { /* return win_path of last created tab or window */
            Tcl_SetResult(interp, get_last_created_window_path(), TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "lastsel")) { /* number of selected objects */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            rebuild_selected_array();
            Tcl_SetResult(interp, my_itoa(xctx->lastsel),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "line_width")) { /* get line width */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, dtoa(xctx->lw), TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "lines")) { /* (xschem get lines n) number of lines on layer 'n' */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 3) {
              int c = atoi(argv[3]);
              if(c >=0 && c < cadlayers) {
                Tcl_SetResult(interp, my_itoa(xctx->lines[c]),TCL_VOLATILE);
              } else {
                Tcl_SetResult(interp, "xschem get rects n: layer number out of range", TCL_STATIC);
                return TCL_ERROR;
              }
            } else {
              Tcl_SetResult(interp, "xschem get rects n: give a layer number", TCL_STATIC);
              return TCL_ERROR;
            }
          }
          break;
          case 'm':
          if(!strcmp(argv[2], "median")) { /* (xschem get median v1 v2 ...) median of the given doubles; B1 test seam (wire_stub_netlabel.md §4.2) */
            int n = argc - 3, k;
            double *v;
            char s[64];
            if(n <= 0) {
              Tcl_SetResult(interp, "xschem get median: give one or more numbers", TCL_STATIC);
              return TCL_ERROR;
            }
            v = my_malloc(_ALLOC_ID_, (size_t)n * sizeof(double));
            for(k = 0; k < n; ++k) v[k] = atof(argv[k + 3]);
            my_snprintf(s, S(s), "%g", median_double(v, n));
            my_free(_ALLOC_ID_, &v);
            Tcl_SetResult(interp, s, TCL_VOLATILE);
          }
          if(!strcmp(argv[2], "min_lw")) { /* minimum line width */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, dtoa(xctx->min_lw),TCL_VOLATILE);
          }
          if(!strcmp(argv[2], "modified")) { /* schematic is in modified state (needs a save) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->modified),TCL_VOLATILE);
          }
          if(!strcmp(argv[2], "mousex_snap")) { /* last snapped mouse x, schematic coords */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, dtoa(xctx->mousex_snap),TCL_VOLATILE);
          }
          if(!strcmp(argv[2], "mousey_snap")) { /* last snapped mouse y, schematic coords */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, dtoa(xctx->mousey_snap),TCL_VOLATILE);
          }
          break;
          case 'n':
          if(!strcmp(argv[2], "netlist_name")) { /* netlist name if set. If 'fallback' given get default name */
            if(argc > 3 &&  !strcmp(argv[3], "fallback")) {
              char f[PATH_MAX];
              if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
              if(xctx->netlist_type == CAD_SPICE_NETLIST) {
                my_snprintf(f, S(f), "%s.spice", get_cell(xctx->current_name, 0));
              }
              else if(xctx->netlist_type == CAD_VHDL_NETLIST) {
                my_snprintf(f, S(f), "%s.vhdl", get_cell(xctx->current_name, 0));
              }
              else if(xctx->netlist_type == CAD_VERILOG_NETLIST) {
                my_snprintf(f, S(f), "%s.v", get_cell(xctx->current_name, 0));
              }
              else if(xctx->netlist_type == CAD_SPECTRE_NETLIST) {
                my_snprintf(f, S(f), "%s.spectre", get_cell(xctx->current_name, 0));
              }
              else if(xctx->netlist_type == CAD_TEDAX_NETLIST) {
                my_snprintf(f, S(f), "%s.tdx", get_cell(xctx->current_name, 0));
              }
              else {
                my_snprintf(f, S(f), "%s.unknown", get_cell(xctx->current_name, 0));
              }
              if(xctx->netlist_name[0] == '\0') {
                Tcl_SetResult(interp, f, TCL_VOLATILE);
              } else {
                Tcl_SetResult(interp, xctx->netlist_name, TCL_VOLATILE);
              }
            } else {
              Tcl_SetResult(interp, xctx->netlist_name, TCL_VOLATILE);
            }
          }
          else if(!strcmp(argv[2], "netlist_type")) { /* get current netlist type (spice/vhdl/verilog/tedax) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(xctx->netlist_type == CAD_SPICE_NETLIST) {
              Tcl_SetResult(interp, "spice", TCL_STATIC);
            }
            else if(xctx->netlist_type == CAD_VHDL_NETLIST) {
              Tcl_SetResult(interp, "vhdl", TCL_STATIC);
            }
            else if(xctx->netlist_type == CAD_SPECTRE_NETLIST) {
              Tcl_SetResult(interp, "spectre", TCL_STATIC);
            }
            else if(xctx->netlist_type == CAD_VERILOG_NETLIST) {
              Tcl_SetResult(interp, "verilog", TCL_STATIC);
            }
            else if(xctx->netlist_type == CAD_TEDAX_NETLIST) {
              Tcl_SetResult(interp, "tedax", TCL_STATIC);
            }
            else if(xctx->netlist_type == CAD_SYMBOL_ATTRS) {
              Tcl_SetResult(interp, "symbol", TCL_STATIC);
            }
            else {
              Tcl_SetResult(interp, "unknown", TCL_STATIC);
            }
          }
          else if(!strcmp(argv[2], "net_hilight_animated")) {
            /* 1 if this window should run the net-highlight animation tick: animation
             * enabled, on-screen, idle, and >=1 highlighted net has an animating style
             * (blinking, Pass 2a; or marching, Pass 2b). The Tcl tick polls this to decide
             * whether to keep rescheduling.
             * Optional <win> arg (multi-window anim, Phase B): evaluate THAT window's context
             * via the Phase-A borrow (no GUI side effects), then restore -- so a per-window
             * tick for a non-front window gets its own window's answer, not the front's. With
             * no arg the front (current) behavior is unchanged. */
            Xschem_ctx *borrowed = NULL;
            int animated;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 3) borrowed = net_hilight_borrow_ctx(argv[3]);
            /* An explicit <win> that is neither the current window nor a known window path
             * cannot be borrowed (borrow -> NULL). Report "not animating" (0) for that window
             * rather than silently answering about the front -- a tick polling a stale/closed
             * window then stops cleanly instead of mirroring the front's state. (borrow also
             * returns NULL when <win> IS the current window; that case correctly answers about
             * the front, hence the current_win_path check distinguishes the two.) */
            if(argc > 3 && !borrowed && xctx->current_win_path && strcmp(argv[3], xctx->current_win_path))
              animated = 0;
            else
              animated = net_hilight_has_animation();
            net_hilight_restore_ctx(borrowed);
            Tcl_SetResult(interp, animated ? "1" : "0", TCL_STATIC);
          }
          else if(!strcmp(argv[2], "no_draw")) { /* disable drawing */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(xctx->no_draw != 0 )
              Tcl_SetResult(interp, "1",TCL_STATIC);
            else
              Tcl_SetResult(interp, "0",TCL_STATIC);
          }
          else if(!strcmp(argv[2], "no_grid")) { /* per-window grid/origin suppression (item 18) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, xctx->no_grid != 0 ? "1" : "0", TCL_STATIC);
          }
          /* xschem get no_snap
           * per-window "this canvas has no schematic snap grid" (issue 0177).
           * The blast-radius witness for the whole feature: a viewer window answers 1
           * and every schematic window answers 0, so a test can prove the property is
           * scoped to the context rather than global. */
          else if(!strcmp(argv[2], "no_snap")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, xctx->no_snap != 0 ? "1" : "0", TCL_STATIC);
          }
          else if(!strcmp(argv[2], "ntabs")) { /* get number of additional tabs (0 = only one tab) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(get_window_count()), TCL_VOLATILE);
          }
          break;
          case 'p':
          if(!strcmp(argv[2], "pinlayer")) { /* layer number for pins */
            Tcl_SetResult(interp, my_itoa(PINLAYER),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "pending_fullzoom")) { /* deferred full-zoom counter */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->pending_fullzoom),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "pin_name_size")) { /* (xschem get pin_name_size inst pin ?win?) name-text yscale of an instance pin (P9, wire_stub_netlabel.md §3.4) */
            char s[64];
            int inst;
            Xschem_ctx *borrowed = NULL;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc <= 4) {
              Tcl_SetResult(interp, "xschem get pin_name_size: give an instance index and a pin index", TCL_STATIC);
              return TCL_ERROR;
            }
            /* optional <win>: read that window's context via the context-borrow primitive (no GUI
             * side effects) so the query is not bound to whatever window is front -- e.g. reading a
             * schematic's instance pins while a symbol window has focus. borrow -> NULL means EITHER
             * <win> is the current window (fine -- answer about it) OR it names no borrowable window
             * (unknown/typo, or a known path whose context slot is momentarily unallocated mid
             * create/teardown); a NULL borrow for a NON-current <win> is a failed borrow, so error
             * rather than silently reading the FRONT window (which would reintroduce the wrong-window
             * bug this arg prevents -- and which net_hilight_win_known alone would miss on the
             * known-but-unallocated slot). Same idiom as `get net_hilight_animated`. Restore before
             * EVERY later return so the borrow/restore stack stays balanced. */
            if(argc > 5) borrowed = net_hilight_borrow_ctx(argv[5]);
            if(argc > 5 && !borrowed && xctx->current_win_path && strcmp(argv[5], xctx->current_win_path)) {
              Tcl_SetResult(interp, "xschem get pin_name_size: unknown or unavailable window path", TCL_STATIC);
              return TCL_ERROR;   /* borrowed == NULL here: nothing to restore */
            }
            inst = atoi(argv[3]);
            if(inst < 0 || inst >= xctx->instances) {
              Tcl_SetResult(interp, "xschem get pin_name_size: instance index out of range", TCL_STATIC);
              net_hilight_restore_ctx(borrowed);
              return TCL_ERROR;
            }
            if(xctx->inst[inst].ptr < 0) {   /* instance whose symbol failed to load: no pins to read */
              Tcl_SetResult(interp, "xschem get pin_name_size: instance has no symbol", TCL_STATIC);
              net_hilight_restore_ctx(borrowed);
              return TCL_ERROR;
            }
            my_snprintf(s, S(s), "%g", get_pin_name_size(xctx->sym + xctx->inst[inst].ptr, atoi(argv[4])));
            Tcl_SetResult(interp, s, TCL_VOLATILE);
            net_hilight_restore_ctx(borrowed);
          }
          else if(!strcmp(argv[2], "polygons")) { /* (xschem get polygons n) number of polygons on layer 'n' */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 3) {
              int c = atoi(argv[3]);
              if(c >=0 && c < cadlayers) {
                Tcl_SetResult(interp, my_itoa(xctx->polygons[c]),TCL_VOLATILE);
              } else {
                Tcl_SetResult(interp, "xschem get polygons n: layer number out of range", TCL_STATIC);
                return TCL_ERROR;
              }
            } else {
              Tcl_SetResult(interp, "xschem get polygons needs a layer number", TCL_STATIC);
              return TCL_ERROR;
            }
          }
          break;
          case 'r':
          if(!strcmp(argv[2], "raw_level")) { /* hierarchy level where raw file was loaded */
            int ret = -1;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(xctx->raw) ret = xctx->raw->level;
            Tcl_SetResult(interp, my_itoa(ret),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "readonly")) { /* window is read-only (file-protected) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->readonly),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "rectcolor")) { /* current layer number */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->rectcolor),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "rects")) { /* (xschem get rects n) number of rectangles on layer 'n' */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 3) {
              int c = atoi(argv[3]);
              if(c >=0 && c < cadlayers) {
                Tcl_SetResult(interp, my_itoa(xctx->rects[c]),TCL_VOLATILE);
              } else {
                Tcl_SetResult(interp, "xschem get rects n: layer number out of range", TCL_STATIC);
                return TCL_ERROR;
              }
            } else {
              Tcl_SetResult(interp, "xschem get rects n: give a layer number", TCL_STATIC);
              return TCL_ERROR;
            }
          }
          break;
          case 's':
          if(!strcmp(argv[2], "sellayer")) { /* layer number for selection */
            Tcl_SetResult(interp, my_itoa(SELLAYER),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "semaphore")) { /* used for debug */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->semaphore),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "sympin_drops")) { /* issue 0122 E1: committed Add-Pin/Add-Wire-Label drop count */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->sympin_drops),TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "schname")) /* get full path of current sch. if 'n' given get sch of level 'n' */
          {
            int x;
            /* allows to retrieve name of n-th parent schematic */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 3) x = atoi(argv[3]);
            else x = xctx->currsch;
            if(x < 0 ) x = xctx->currsch + x;
            if(x<=xctx->currsch && x >= 0) {
              Tcl_SetResult(interp, xctx->sch[x], TCL_VOLATILE); /* if xctx->sch[x]==NULL return empty string */
            }
          }
          else if(!strcmp(argv[2], "schprop")) /* get schematic "spice" global attributes */
          {
             Tcl_SetResult(interp, xctx->schprop ? xctx->schprop : "", TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "schvhdlprop")) /* get schematic "vhdl" global attributes */
          {
             Tcl_SetResult(interp, xctx->schvhdlprop ? xctx->schvhdlprop : "", TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "schverilogprop")) /* get schematic "verilog" global attributes */
          {
             Tcl_SetResult(interp, xctx->schverilogprop ? xctx->schverilogprop : "", TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "schspectreprop")) /* get schematic "spectre" global attributes */
          {
             Tcl_SetResult(interp, xctx->schspectreprop ? xctx->schspectreprop : "", TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "schsymbolprop")) /* get schematic "symbol" global attributes */
          {
             Tcl_SetResult(interp, xctx->schsymbolprop ? xctx->schsymbolprop : "", TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "schtedaxprop")) /* get schematic "tedax" global attributes */
          {
             Tcl_SetResult(interp, xctx->schtedaxprop ? xctx->schtedaxprop : "", TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "sch_path")) /* get hierarchy path. if 'n' given get hierpath of level 'n' */
          {
            int x;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 3) x = atoi(argv[3]);
            else x = xctx->currsch;
            if(x < 0 ) x = xctx->currsch + x;
            if(x<=xctx->currsch && x >= 0) {
              Tcl_SetResult(interp, xctx->sch_path[x], TCL_VOLATILE);
            }
          }
          else if(!strcmp(argv[2], "sch_inst_number")) /* vector-instance slice descended into to REACH
                          * level 'n' (default: current level) = sch_inst_number[n-1], since descend_schematic
                          * records the slice at the PARENT level (sch_inst_number[currsch] before currsch++).
                          * 1 for a scalar instance; 1 for the top level (n==0, no descent). Exposed for the
                          * headless hierarchy-representation dump test (agent_guide §8 Tier B). NOTE: the
                          * raw array element sch_inst_number[currsch] at the deepest level is unset -- do NOT
                          * default to it (that was an off-by-one copy of the sch_path getter). */
          {
            int x;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 3) x = atoi(argv[3]);
            else x = xctx->currsch;
            if(x < 0 ) x = xctx->currsch + x;
            if(x >= 1 && x <= xctx->currsch)
              Tcl_SetResult(interp, my_itoa(xctx->sch_inst_number[x - 1]), TCL_VOLATILE);
            else if(x == 0)
              Tcl_SetResult(interp, "1", TCL_VOLATILE); /* top level has no entering slice */
          }
          else if(!strcmp(argv[2], "sch_to_compare")) /* if set return schematic current design is compared with */
          {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, xctx->sch_to_compare, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "sim_sch_path")) /* get sim hier path. start from level where raw was loaded */
          {
            int x = xctx->currsch;
            char *path = xctx->sch_path[x] + 1;
            int skip = 0;
            int start_level;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            start_level = sch_waves_loaded();
            /* skip path components that are above the level where raw file was loaded */
            while(*path && skip < start_level) {
              if(*path == '.') skip++;
              ++path;
            }
            Tcl_SetResult(interp, path, TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "symbols")) { /* number of loaded symbols */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->symbols), TCL_VOLATILE);
          }

          break;
          case 't':
          #ifndef __unix__
          if(!strcmp(argv[2], "temp_dir")) { /* get windows temporary dir */
            if(win_temp_dir[0] != '\0') Tcl_SetResult(interp, win_temp_dir, TCL_VOLATILE);
            else {
              TCHAR tmp_buffer_path[MAX_PATH];
              DWORD ret_val = GetTempPath(MAX_PATH, tmp_buffer_path);
              if(ret_val > MAX_PATH || (ret_val == 0)) {
                Tcl_SetResult(interp, "xschem get temp_dir failed\n", TCL_STATIC);
                fprintf(errfp, "xschem get temp_dir: path error\n");
                tcleval("exit 1");
              }
              else {
                char s[MAX_PATH];
                size_t num_char_converted;
                int err = wcstombs_s(&num_char_converted, s, MAX_PATH, tmp_buffer_path, MAX_PATH); /*unicode TBD*/
                if(err != 0) {
                  Tcl_SetResult(interp, "xschem get temp_dir conversion failed\n", TCL_STATIC);
                  fprintf(errfp, "xschem get temp_dir: conversion error\n");
                  tcleval("exit 1");
                }
                else {
                  change_to_unix_fn(s);
                  size_t slen = strlen(s);
                  if(s[slen - 1] == '/') s[slen - 1] = '\0';
                  my_strncpy(win_temp_dir, s, S(win_temp_dir));
                  dbg(2, "scheduler(): win_temp_dir is %s\n", win_temp_dir);
                  Tcl_SetResult(interp, s, TCL_VOLATILE);
                }
              }
            }
          }
          else
          #endif
          if(!strcmp(argv[2], "text_svg")) { /* return 1 if using <text> elements in svg export */
            if(text_svg != 0 )
              Tcl_SetResult(interp, "1",TCL_STATIC);
            else
              Tcl_SetResult(interp, "0",TCL_STATIC);
          }
          else if(!strcmp(argv[2], "texts")) { /* number of text objects in schematic */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->texts), TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "textlayer")) { /* layer number for texts */
            Tcl_SetResult(interp, my_itoa(TEXTLAYER), TCL_VOLATILE);
          }
          /* top_path="" for main window, ".x1", ".x2", ... for additional windows.
           * always "" in tabbed interface */
          else if(!strcmp(argv[2], "top_path")) { /* get top hier path of current window (always "" for tabbed if) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, xctx->top_path, TCL_VOLATILE);
          }
          /* same as above but main window returned as "." */
          else if(!strcmp(argv[2], "topwindow")) { /* same as top_path but main window returned as "." */
            char *top_path;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            top_path =  xctx->top_path[0] ? xctx->top_path : ".";
            Tcl_SetResult(interp, top_path,TCL_VOLATILE);
          }
          break;
          case 'u':
          if(!strcmp(argv[2], "ui_state")) { /* return UI state */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp,  my_itoa(xctx->ui_state), TCL_VOLATILE);
          }
          else if(!strcmp(argv[2], "ui_state2")) { /* return the MENUSTART* sub-state word */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp,  my_itoa(xctx->ui_state2), TCL_VOLATILE);
          }
          break;
          case 'v':
          if(!strcmp(argv[2], "version")) { /* return xschem version */
            Tcl_SetResult(interp, XSCHEM_VERSION, TCL_VOLATILE);
          }
          break;
          case 'w':
          /* ---- net-highlight styles on waveform TRACES ----------------------
           * doc/claude/specs/wave_trace_hilight.md §7.1. Three read-only
           * getters, all FAIL SOFT (a sentinel + TCL_OK on a short or bad
           * query, never an error): the ASE viewer wraps them in `catch` and
           * must read a missing verb as "nothing there", never as "locked out"
           * -- the same contract graph_marker_* and graph_axis_* carry. */

          /* xschem get wave_hilights
           * The whole set as `{gi ni style} ...` Tcl sublists, in set order;
           * "" when no trace is highlighted. The `graph_marker list` shape
           * rather than graph_preview_set's flat one, because a triple read
           * back as a flat list is one transcription slip away from a silent
           * off-by-one. */
          if(!strcmp(argv[2], "wave_hilights")) {
            int k;
            Tcl_Obj *lst;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            lst = Tcl_NewListObj(0, NULL);
            for(k = 0; k < xctx->wave_hilight_n; k++) {
              Tcl_Obj *e = Tcl_NewListObj(0, NULL);
              Tcl_ListObjAppendElement(interp, e, Tcl_NewIntObj(xctx->wave_hilight_gi[k]));
              Tcl_ListObjAppendElement(interp, e, Tcl_NewIntObj(xctx->wave_hilight_ni[k]));
              Tcl_ListObjAppendElement(interp, e, Tcl_NewIntObj(xctx->wave_hilight_style[k]));
              Tcl_ListObjAppendElement(interp, lst, e);
            }
            Tcl_SetObjResult(interp, lst);
          }
          /* xschem get wave_hilight_at <gi> <ni>
           * The style index of that trace, or -1. Goes through
           * wave_hilight_style_of(), THE predicate -- a second bare comparison
           * here is exactly the drift the source-level leg forbids. */
          else if(!strcmp(argv[2], "wave_hilight_at")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 4) {
              Tcl_SetResult(interp, my_itoa(wave_hilight_style_of(atoi(argv[3]), atoi(argv[4]))),
                            TCL_VOLATILE);
            } else {
              Tcl_SetResult(interp, "-1", TCL_STATIC);
            }
          }
          /* xschem get wave_hilight_points <gi> <ni>
           * How many points that trace's decimated envelope holds; 0 when there
           * is no envelope to have (bad index, non-graph rect, no raw, an
           * off-screen or digital strip, a bus entry, an unknown vector).
           * THE COST SEAM: it is what lets a headless leg assert that a
           * >= 50 000-sample trace really decimated to <= 2W points and that a
           * sparse one did not decimate at all. It BUILDS the envelope when the
           * cache has none -- the paint path that normally fills the cache is
           * has_x-gated, so a pure cache read would answer 0 forever under
           * --nogui and the whole cost group would pass vacuously. */
          else if(!strcmp(argv[2], "wave_hilight_points")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 4) {
              Tcl_SetResult(interp, my_itoa(wave_hilight_points(atoi(argv[3]), atoi(argv[4]))),
                            TCL_VOLATILE);
            } else {
              Tcl_SetResult(interp, "0", TCL_STATIC);
            }
          }
          /* xschem get wave_viewer
           * per-window "this context is a waveform viewer, not a schematic" (issue
           * 0172). Set by wviewer::open; the witness a test uses to prove that a
           * viewer window is excluded from the pristine-untitled reuse path while
           * every schematic window still answers 0. */
          else if(!strcmp(argv[2], "wave_viewer")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, xctx->wave_viewer != 0 ? "1" : "0", TCL_STATIC);
          } else if(!strcmp(argv[2], "wirelayer")) { /* layer used for wires */
            Tcl_SetResult(interp, my_itoa(WIRELAYER), TCL_VOLATILE);
          } else if(!strcmp(argv[2], "wires")) { /* number of wires */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->wires), TCL_VOLATILE);
          } else if(!strcmp(argv[2], "window_number")) { /* Cadence-style stable window number of current context */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            Tcl_SetResult(interp, my_itoa(xctx->window_number), TCL_VOLATILE);
          }
          break;
          case 'x':
          if(!strcmp(argv[2], "xschem_web_dirname")) {
            Tcl_SetResult(interp, xschem_web_dirname, TCL_STATIC);
          } else if(!strcmp(argv[2], "xorigin")) { /* x coordinate of origin */
            char s[128];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(s, S(s), "%.16g", xctx->xorigin);
            Tcl_SetResult(interp, s,TCL_VOLATILE);
          } else if(!strcmp(argv[2], "x1")) { /* move/copy gesture anchor x (diagnostic) */
            char s[128];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(s, S(s), "%.16g", xctx->x1);
            Tcl_SetResult(interp, s,TCL_VOLATILE);
          } else if(!strcmp(argv[2], "x2")) { /* move/copy gesture current x (diagnostic) */
            char s[128];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(s, S(s), "%.16g", xctx->x2);
            Tcl_SetResult(interp, s,TCL_VOLATILE);
          }
          break;
          case 'y':
          if(!strcmp(argv[2], "yorigin")) { /* y coordinate of origin */
            char s[128];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(s, S(s), "%.16g", xctx->yorigin);
            Tcl_SetResult(interp, s,TCL_VOLATILE);
          } else if(!strcmp(argv[2], "y1")) { /* move/copy gesture anchor y (diagnostic) */
            char s[128];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(s, S(s), "%.16g", xctx->y1);
            Tcl_SetResult(interp, s,TCL_VOLATILE);
          } else if(!strcmp(argv[2], "y2")) { /* move/copy gesture current y (diagnostic) */
            char s[128];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(s, S(s), "%.16g", xctx->y2);
            Tcl_SetResult(interp, s,TCL_VOLATILE);
          }
          break;
          case 'z':
          if(!strcmp(argv[2], "zoom")) { /* zoom level */
            char s[128];
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_snprintf(s, S(s), "%.16g", xctx->zoom);
            Tcl_SetResult(interp, s,TCL_VOLATILE);
          }
          break;
          default:
          *cmd_found = 0;
          break;
        } /* switch */
      }
    }

    /* get_additional_symbols what
     *   create new symbols for instance based implementation selection */
    else if(!strcmp(argv[1], "get_additional_symbols") )
    {
      if(argc > 2) {
        get_additional_symbols(atoi(argv[2]));
      }
      Tcl_ResetResult(interp);
    }

    /* get_cell cell n_dirs
     *   return result of get_cell function */
    else if(!strcmp(argv[1], "get_cell") )
    {
      if(argc > 3) {
        Tcl_SetResult(interp, (char *)get_cell(argv[2], atoi(argv[3])), TCL_VOLATILE);
      }
    }

    /* get_cell_w_ext cell n_dirs
     *   return result of get_cell_w_ext function */
    else if(!strcmp(argv[1], "get_cell_w_ext") )
    {
      if(argc > 3) {
        Tcl_SetResult(interp, (char *)get_cell_w_ext(argv[2], atoi(argv[3])), TCL_VOLATILE);
      }
    }

    /* get_inst_lcv
     *   Return the Cadence library/cell/view of the single selected instance as
     *   a 3-element Tcl list {lib cell view}. Errors out unless exactly one
     *   object is selected and it is an instance. The 'view' is the actual
     *   view-directory name the symbol lives in -- the type is always a symbol
     *   (.sym) view, but the name is arbitrary. Only the Cadence library layout
     *   (<libpath>/<cell>/<view>/<cell>.sym) is supported; an instance whose
     *   symbol is not in a registered library in that layout is an error.
     *   The registry reverse-map lives in Tcl (library_inst_lcv,
     *   library_defs.tcl); this branch validates the selection and delegates,
     *   matching the library/lib_cells/cell_views commands. */
    else if(!strcmp(argv[1], "get_inst_lcv"))
    {
      int n;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      rebuild_selected_array();
      if(xctx->lastsel != 1 || xctx->sel_array[0].type != ELEMENT) {
        Tcl_SetResult(interp,
          "xschem get_inst_lcv: exactly one instance must be selected", TCL_STATIC);
        return TCL_ERROR;
      }
      n = xctx->sel_array[0].n;
      /* delegate the lib/cell/view reverse-map to Tcl, passing the instance's
       * symbol reference (resolved to an abs path Tcl-side via abs_sym_path). */
      tclvareval("library_inst_lcv {", xctx->inst[n].name, "}", NULL);
      if(tclresult()[0] == '\0') {
        Tcl_SetResult(interp,
          "xschem get_inst_lcv: selected instance is not in a Cadence library", TCL_STATIC);
        return TCL_ERROR;
      }
    }
    /************ end xschem get subcommands *************/


    /* get_fqdevice instname param modelparam
     *   get the full pathname of "instname" device
     *   modelparam:
     *     0: current, 1: modelparam, 2: modelvoltage
     *   param: device parameter, like ib, gm, vth
     *   set param to {} (empty str) for just branch current of 2 terminal device
     *   for parameters like "vth" modelparam must be 2
     *   for parameters like "ib" modelparam must be 0
     *   for parameters like "gm" modelparam must be 1
     */
    else if(!strcmp(argv[1], "get_fqdevice"))
    {
      char *fqdev;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 4) {
        fqdev = get_fqdevice(argv[3], atoi(argv[4]), argv[2]);
        Tcl_SetResult(interp, fqdev, TCL_VOLATILE);
        my_free(_ALLOC_ID_, &fqdev);
      } else if(argc > 2) {
        fqdev = get_fqdevice("", 0, argv[2]);
        Tcl_SetResult(interp, fqdev, TCL_VOLATILE);
        my_free(_ALLOC_ID_, &fqdev);
      }
    }

    /* getprop instance|instance_pin|symbol|text ref
     *
     * getprop instance inst
     *   Get the full attribute string of 'inst'
     *
     * getprop instance inst attr
     *   Get the value of attribute 'attr'
     *   If 'attr has the form 'cell::sym_attr' look up attribute 'sym_attr'
     *   of the symbol referenced by the instance.
     *
     * getprop instance_notcl inst attr
     *   Same as above but do not perform tcl substitution
     *
     * getprop instance_pin inst pin
     *   Get the full attribute string of pin 'pin' of instance 'inst'
     *   Example: xschem getprop instance_pin x3 MINUS --> name=MINUS dir=in
     *
     * getprop instance_pin inst pin pin_attr
     *   Get attribute 'pin_attr' of pin 'pin' of instance 'inst'
     *   Example: xschem getprop instance_pin x3 MINUS dir --> in
     *
     * getprop symbol sym_name
     *   Get full attribute string of symbol 'sym_name'
     *   example:
     *   xschem getprop symbol comp_ngspice.sym -->
     *     type=subcircuit
     *     format="@name @pinlist @symname
     *        OFFSET=@OFFSET AMPLITUDE=@AMPLITUDE GAIN=@GAIN ROUT=@ROUT COUT=@COUT"
     *     template="name=x1 OFFSET=0 AMPLITUDE=5 GAIN=100 ROUT=1000 COUT=1p"
     *
     * getprop symbol sym_name sym_attr [with_quotes]
     *   Get value of attribute 'sym_attr' of symbol 'sym_name'
     *   'with_quotes' (default:0) is an integer passed to get_tok_value()
     *
     * getprop rect layer num attr [with_quotes]
     *   if '1' is given as 'keep' return backslashes and unescaped quotes if present in value
     *   Get attribute 'attr' of rectangle number 'num' on layer 'layer'
     *
     * getprop text num attr
     *   Get attribute 'attr' of text number 'num', 'num' can also be the name attribute
     *   of the text object
     *   if 'attr' is 'txt_ptr' return the text string
     *
     * getprop wire num attr
     *   Get attribute 'attr' of wire number 'num'
     *
     * ('inst' can be an instance name or instance number)
     * ('pin' can be a pin name or pin number)
     */
    else if(!strcmp(argv[1], "getprop"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem getprop needs instance|instance_pin|wire|symbol|text|rect", TCL_STATIC);
        return TCL_ERROR;
      }
      if(argc > 2 && (!strcmp(argv[2], "instance") || !strcmp(argv[2], "instance_notcl"))) {
        int i;
        int with_quotes = 0;
        const char *tmp;
        if(argc < 4) {
          Tcl_SetResult(interp, "'xschem getprop instance' needs 1 or 2 additional arguments", TCL_STATIC);
          return TCL_ERROR;
        }
        if((i = get_instance(argv[3])) < 0 ) {
          Tcl_AppendResult(interp, "xschem getprop: instance not found:", argv[3], NULL);
          return TCL_ERROR;
        }
        if(!strcmp(argv[2], "instance_notcl")) with_quotes = 2;
        if(argc < 5) {
          Tcl_SetResult(interp, xctx->inst[i].prop_ptr, TCL_VOLATILE);
        } else if(!strcmp(argv[4], "cell::name")) {
          tmp = xctx->inst[i].name;
          Tcl_SetResult(interp, (char *) tmp, TCL_VOLATILE);
        } else if(strstr(argv[4], "cell::") ) {
          tmp = get_tok_value(xctx->sym[xctx->inst[i].ptr].prop_ptr, argv[4]+6, with_quotes);
          dbg(1, "scheduler(): xschem getprop: looking up instance %d prop cell::|%s| : |%s|\n", i, argv[4]+6, tmp);
          Tcl_SetResult(interp, (char *) tmp, TCL_VOLATILE);
        } else {
          Tcl_SetResult(interp, (char *)get_tok_value(xctx->inst[i].prop_ptr, argv[4], with_quotes), TCL_VOLATILE);
        }
      } else if(argc > 2 && !strcmp(argv[2], "instance_pin")) {
        /*   0       1        2         3   4       5     */
        /* xschem getprop instance_pin X10 PLUS [pin_attr]  */
        /* xschem getprop instance_pin X10  1   [pin_attr]  */
        int inst, n;
        size_t tmp;
        char *subtok=NULL;
        const char *value=NULL;
        if(argc < 5) {
          Tcl_SetResult(interp, "xschem getprop instance_pin needs 2 or 3 additional arguments", TCL_STATIC);
          return TCL_ERROR;
        }
        if((inst = get_instance(argv[3])) < 0 ) {
          Tcl_SetResult(interp, "xschem getprop: instance not found", TCL_STATIC);
          return TCL_ERROR;
        }
        n = get_inst_pin_number(inst, argv[4]);
        if(n>=0  && n < (xctx->inst[inst].ptr+ xctx->sym)->rects[PINLAYER]) {
          if(argc < 6) {
           Tcl_SetResult(interp, (xctx->inst[inst].ptr+ xctx->sym)->rect[PINLAYER][n].prop_ptr, TCL_VOLATILE);
          } else {
            tmp = 100 + strlen(argv[4]) + strlen(argv[5]);
            subtok = my_malloc(_ALLOC_ID_,tmp);
            my_snprintf(subtok, tmp, "%s(%s)", argv[5], argv[4]);
            value = get_tok_value(xctx->inst[inst].prop_ptr,subtok,0);
            if(!value[0]) {
              my_snprintf(subtok, tmp, "%s(%d)", argv[5], n);
              value = get_tok_value(xctx->inst[inst].prop_ptr,subtok,0);
            }
            if(!value[0]) {
              value = get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][n].prop_ptr,argv[5],0);
            }
            if(value[0] != 0) {
              char *ss;
              int slot;
              if((ss = strchr(xctx->inst[inst].instname, ':')) ) {
                sscanf(ss + 1, "%d", &slot);
                if(strstr(value, ":")) value = find_nth(value, ":", "", 0, slot);
              }
              Tcl_SetResult(interp, (char *)value, TCL_VOLATILE);
            }
            my_free(_ALLOC_ID_, &subtok);
          }
        }
      /* xschem getprop symbol lm358.sym [type] */
      } else if(argc > 2 && !strcmp(argv[2], "symbol")) {
        int i;
        if(argc < 4) {
          Tcl_SetResult(interp, "xschem getprop symbol needs 1 or 2 or 3 additional arguments", TCL_STATIC);
          return TCL_ERROR;
        }

        i = get_symbol(argv[3]);
        if( i == -1) {
          Tcl_SetResult(interp, "Symbol not found", TCL_STATIC);
          return TCL_ERROR;
        }
        if(argc < 5)
          Tcl_SetResult(interp, xctx->sym[i].prop_ptr, TCL_VOLATILE);
        else if(argc == 5)
          Tcl_SetResult(interp, (char *)get_tok_value(xctx->sym[i].prop_ptr, argv[4], 0), TCL_VOLATILE);
        else if(argc > 5)
          Tcl_SetResult(interp, (char *)get_tok_value(xctx->sym[i].prop_ptr, argv[4], atoi(argv[5])), TCL_VOLATILE);

      } else if(argc > 2 && !strcmp(argv[2], "rect")) { /* xschem getprop rect c n token */
        if(argc < 6) {
          Tcl_SetResult(interp, "xschem getprop rect needs <color> <n> <token>", TCL_STATIC);
          return TCL_ERROR;
        } else {
          int with_quotes = 0;
          int c = atoi(argv[3]);
          int n = atoi(argv[4]);
          /* issue 0077: bounds-check the caller-supplied layer/index before subscripting,
           * mirroring the `object #layer,index` range-check. Without this an out-of-range
           * c/n does an OOB read of xctx->rect[c][n].prop_ptr (crash / memory disclosure). */
          if(c < 0 || c >= cadlayers || n < 0 || n >= xctx->rects[c]) {
            Tcl_AppendResult(interp, "xschem getprop: rect not found: ", argv[3], " ", argv[4], NULL);
            return TCL_ERROR;
          }
          if(argc > 6) with_quotes = atoi(argv[6]);
          Tcl_SetResult(interp, (char *)get_tok_value(xctx->rect[c][n].prop_ptr, argv[5], with_quotes), TCL_VOLATILE);
        }
      } else if(argc > 2 && !strcmp(argv[2], "text")) { /* xschem getprop text n token */
        if(argc < 5) {
          Tcl_SetResult(interp, "xschem getprop text needs <n> <token>", TCL_STATIC);
          return TCL_ERROR;
        } else {
          int n = get_text(argv[3]);
          if(n < 0) {
            Tcl_AppendResult(interp, "xschem getprop: text object not found:", argv[3], NULL);
            return TCL_ERROR;
          }
          if(!strcmp(argv[4], "txt_ptr"))
            Tcl_SetResult(interp, xctx->text[n].txt_ptr, TCL_VOLATILE);
          else if(!strcmp(argv[4], "size")) { /* pseudo-token: the text's xscale (display size) */
            char buf[40];
            my_snprintf(buf, S(buf), "%.10g", xctx->text[n].xscale);
            Tcl_SetResult(interp, buf, TCL_VOLATILE);
          }
          else
            Tcl_SetResult(interp, (char *)get_tok_value(xctx->text[n].prop_ptr, argv[4], 2), TCL_VOLATILE);
        }
      } else if(argc > 2 && !strcmp(argv[2], "wire")) { /* xschem getprop wire n token */
        if(argc < 5) {
          Tcl_SetResult(interp, "xschem getprop wire needs <n> <token>", TCL_STATIC);
          return TCL_ERROR;
        } else {
          int n = atoi(argv[3]);
          /* issue 0077: bounds-check before subscripting (OOB read otherwise). */
          if(n < 0 || n >= xctx->wires) {
            Tcl_AppendResult(interp, "xschem getprop: wire not found: ", argv[3], NULL);
            return TCL_ERROR;
          }
          Tcl_SetResult(interp, (char *)get_tok_value(xctx->wire[n].prop_ptr, argv[4], 2), TCL_VOLATILE);
        }
      }
    }

    /* get_sch_from_sym inst [symbol]
     *   get schematic associated with instance 'inst'
     *   if inst==-1 and a 'symbol' name is given get sch associated with symbol */
    else if(!strcmp(argv[1], "get_sch_from_sym") )
    {
      int inst = -1;
      int sym = -1;
      char filename[PATH_MAX];
      my_strncpy(filename,  "", S(filename));
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}

      if(argc > 2) {
        if(argc > 3 && atoi(argv[2]) == -1) {
          sym = get_symbol(argv[3]);
          if(sym < 0) {
            Tcl_SetResult(interp, "xschem get_sch_from_sym: symbol not found", TCL_STATIC);
            return TCL_ERROR;
          }
        }
        else {
          inst = get_instance(argv[2]);
          if(inst < 0) {
            Tcl_SetResult(interp, "xschem get_sch_from_sym: instance not found", TCL_STATIC);
            return TCL_ERROR;
          }
        }
        if( xctx->inst[inst].ptr >= 0  && sym == -1) {
          sym = xctx->inst[inst].ptr;
        }
        if(sym >= 0) get_sch_from_sym(filename, sym + xctx->sym, inst, 0);
      }
      Tcl_SetResult(interp, filename, TCL_VOLATILE);
    }

    /* get_sym_type symname
     *   get "type" value from global attributes of symbol,
     *   looking frst in loaded symbols, then looking in symbol file
     *   symbols that are not already loaded in the design will not be loaded */
    else if(!strcmp(argv[1], "get_sym_type") )
    {
      char *s=NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}

      if(argc < 3) {Tcl_SetResult(interp, "Missing arguments", TCL_STATIC);return TCL_ERROR;}
      get_sym_type(argv[2], &s, NULL, NULL, NULL);

      Tcl_SetResult(interp, s, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &s);
    }

    /* get_tok str tok [with_quotes]
     *   get value of token 'tok' in string 'str'
     *   'with_quotes' (default:0) is an integer passed to get_tok_value() */
    else if(!strcmp(argv[1], "get_tok") )
    {
      char *s=NULL;
      int t;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 4) {Tcl_SetResult(interp, "Missing arguments", TCL_STATIC);return TCL_ERROR;}
      if(argc == 5) t = atoi(argv[4]);
      else t = 0;
      my_strdup(_ALLOC_ID_, &s, get_tok_value(argv[2], argv[3], t));
      Tcl_SetResult(interp, s, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &s);
    }

    /* get_tok_size
     *   Get length of last looked up attribute name (not its value)
     *   if returned value is 0 it means that last searched attribute did not exist */
    else if(!strcmp(argv[1], "get_tok_size") )
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      Tcl_SetResult(interp, my_itoa((int)xctx->tok_size), TCL_VOLATILE);
    }

    /* globals
     *   Return various global variables used in the program */
    else if(!strcmp(argv[1], "globals"))
    {
      static char res[8192];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      Tcl_ResetResult(interp);
      my_snprintf(res, S(res), "*******global variables:*******\n"); Tcl_AppendResult(interp, res, NULL);

      my_snprintf(res, S(res), "areax1=%d\n", xctx->areax1); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "areay1=%d\n", xctx->areay1); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "areax2=%d\n", xctx->areax2); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "areay2=%d\n", xctx->areay2); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "areaw=%d\n", xctx->areaw); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "areah=%d\n", xctx->areah); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "xrect[0].width=%d\n",
              xctx->xrect[0].width); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "xrect[0].height=%d\n",
              xctx->xrect[0].height); Tcl_AppendResult(interp, res, NULL);

      my_snprintf(res, S(res), "INT_LINE_W(lw)=%d\n", INT_LINE_W(xctx->lw)); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "INT_BUS_WIDTH(xctx->lw)=%d\n", INT_BUS_WIDTH(xctx->lw));
              Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "cadhalfdotsize=%g\n", xctx->cadhalfdotsize); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "lw=%g\n", xctx->lw); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "wires=%d\n", xctx->wires); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "instances=%d\n", xctx->instances); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "symbols=%d\n", xctx->symbols); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "lastsel=%d\n", xctx->lastsel); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "texts=%d\n", xctx->texts); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "maxt=%d\n", xctx->maxt); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "maxw=%d\n", xctx->maxw); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "maxi=%d\n", xctx->maxi); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "maxsel=%d\n", xctx->maxsel); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "zoom=%.16g\n", xctx->zoom); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "xorigin=%.16g\n", xctx->xorigin); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "yorigin=%.16g\n", xctx->yorigin); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "maxs=%d\n", xctx->maxs); Tcl_AppendResult(interp, res, NULL);
      for(i=0;i<8; ++i)
      {
        my_snprintf(res, S(res), "rects[%d]=%d\n", i, xctx->rects[i]); Tcl_AppendResult(interp, res, NULL);
        my_snprintf(res, S(res), "lines[%d]=%d\n", i, xctx->lines[i]); Tcl_AppendResult(interp, res, NULL);
        my_snprintf(res, S(res), "maxr[%d]=%d\n", i, xctx->maxr[i]); Tcl_AppendResult(interp, res, NULL);
        my_snprintf(res, S(res), "maxl[%d]=%d\n", i, xctx->maxl[i]); Tcl_AppendResult(interp, res, NULL);
      }
      my_snprintf(res, S(res), "current_dirname=%s\n", xctx->current_dirname); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "current_name=%s\n", xctx->current_name); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "currsch=%d\n", xctx->currsch); Tcl_AppendResult(interp, res, NULL);
      for(i=0;i<=xctx->currsch; ++i)
      { const char *p, *t;
        my_snprintf(res, S(res), "previous_instance[%d]=%d\n",
            i,xctx->previous_instance[i]); Tcl_AppendResult(interp, res, NULL);
        my_snprintf(res, S(res), "sch_path[%d]=%s\n",i,xctx->sch_path[i]?
            xctx->sch_path[i]:"<NULL>"); Tcl_AppendResult(interp, res, NULL);
        my_snprintf(res, S(res), "sch[%d]=%s\n",i,xctx->sch[i]); Tcl_AppendResult(interp, res, NULL);

        p = xctx->hier_attr[i].prop_ptr ? xctx->hier_attr[i].prop_ptr : "<NULL>";
        t = xctx->hier_attr[i].templ ? xctx->hier_attr[i].templ : "<NULL>";
        my_snprintf(res, S(res), "lcc[%d].prop_ptr=%s\n", i, p);
        Tcl_AppendResult(interp, res, NULL);
        my_snprintf(res, S(res), "lcc[%d].templ=%s\n", i, t);
        Tcl_AppendResult(interp, res, NULL);

      }
      my_snprintf(res, S(res), "modified=%d\n", xctx->modified); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "color_ps=%d\n", color_ps); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "hilight_nets=%d\n", xctx->hilight_nets); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "semaphore=%d\n", xctx->semaphore); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "constr_mv=%d\n", xctx->constr_mv); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "ui_state=%d\n", xctx->ui_state); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "ui_state2=%d\n", xctx->ui_state2); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "drag_elements=%d\n", xctx->drag_elements); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "last_command=%d\n", xctx->last_command); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "prep_net_structs=%d\n", xctx->prep_net_structs); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "prep_hi_structs=%d\n", xctx->prep_hi_structs); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "prep_hash_inst=%d\n", xctx->prep_hash_inst); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "prep_hash_wires=%d\n", xctx->prep_hash_wires); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "need_reb_sel_arr=%d\n", xctx->need_reb_sel_arr); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "undo_type=%d\n", xctx->undo_type); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "******* end global variables:*******\n"); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "XSCHEM_LIBRARY_PATH=%s\n",
        tclgetvar("XSCHEM_LIBRARY_PATH")); Tcl_AppendResult(interp, res, NULL);

#ifdef __unix__
      my_snprintf(res, S(res), "******* Xserver options: *******\n"); Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "XMaxRequestSize=%ld\n", XMaxRequestSize(display));
      Tcl_AppendResult(interp, res, NULL);
      my_snprintf(res, S(res), "XExtendedMaxRequestSize=%ld\n", XExtendedMaxRequestSize(display));
      Tcl_AppendResult(interp, res, NULL);
#endif

      my_snprintf(res, S(res), "******* Compile options:*******\n"); Tcl_AppendResult(interp, res, NULL);
      #ifdef HAS_DUP2
      my_snprintf(res, S(res), "HAS_DUP2=%d\n", HAS_DUP2); Tcl_AppendResult(interp, res, NULL);
      #endif
      #ifdef HAS_PIPE
      my_snprintf(res, S(res), "HAS_PIPE=%d\n", HAS_PIPE); Tcl_AppendResult(interp, res, NULL);
      #endif
      #ifdef HAS_POPEN
      my_snprintf(res, S(res), "HAS_POPEN=%d\n", HAS_POPEN); Tcl_AppendResult(interp, res, NULL);
      #endif
      #if HAS_CAIRO==1
      my_snprintf(res, S(res), "HAS_CAIRO=%d\n", HAS_CAIRO); Tcl_AppendResult(interp, res, NULL);
      #endif
      #ifdef XSCHEM_SHAREDIR
      my_snprintf(res, S(res), "XSCHEM_SHAREDIR=%s\n", XSCHEM_SHAREDIR); Tcl_AppendResult(interp, res, NULL);
      #endif
      #ifdef PREFIX
      my_snprintf(res, S(res), "PREFIX=%s\n", PREFIX); Tcl_AppendResult(interp, res, NULL);
      #endif
      #ifdef USER_CONF_DIR
      my_snprintf(res, S(res), "USER_CONF_DIR=%s\n", USER_CONF_DIR); Tcl_AppendResult(interp, res, NULL);
      #endif
      #ifdef HAS_SNPRINTF
      my_snprintf(res, S(res), "HAS_SNPRINTF=%s\n", HAS_SNPRINTF); Tcl_AppendResult(interp, res, NULL);
      #endif
    }

    /* go_back [what]
     *   Go up one level (pop) in hierarchy
     *   if integer 'what' given pass it to the go_back() function
     *   what = 1: ask confirm save if current schematic modified.
     *   what = 2: do not reset window title */
    else if(!strcmp(argv[1], "go_back"))
    {
      int what = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 ) {
        what = atoi(argv[2]);
      }
      if(xctx->semaphore == 0) go_back(what);
      Tcl_ResetResult(interp);
    }

    /* grabscreen
     *   grab root window */
    else if(!strcmp(argv[1], "grabscreen"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      #if defined(__unix__) && HAS_CAIRO==1
      xctx->ui_state |= GRABSCREEN;
      tclvareval("grab set -global ", xctx->top_path, ".drw", NULL);
      #endif
      Tcl_ResetResult(interp);
    }

    /* graph_coord <graph_idx> <screen_x> <screen_y>
     * Data-space coordinates `<dx> <dy>` of a CANVAS PIXEL inside graph
     * <graph_idx> (a layer-2 rect with flags&1). The inverse of the draw
     * transform: pixel -> xschem (X_TO_XSCHEM) -> graph data (G_X/G_Y), so it
     * accounts for the plot box's 14% margins that only setup_graph_data knows.
     * Added for the ASE viewer's POINTER-ANCHORED zoom (issue 0146): Tcl must not
     * re-derive the margin math (the documented mirror/desync trap, see
     * doc/claude/code_analysis/waveform_subsystem_reference.md §8).
     * Returns {} for a bad index / non-graph rect, so callers can fall back.
     * Uses a LOCAL Graph_ctx: never clobber xctx->graph_struct, which an active
     * draw_graph may be using (landmine 11 in the same reference). */
    else if(!strcmp(argv[1], "graph_coord"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      Tcl_ResetResult(interp);
      if(argc > 4) {
        i = atoi(argv[2]);
        if(i >= 0 && i < xctx->rects[GRIDLAYER] && (xctx->rect[GRIDLAYER][i].flags & 1)) {
          char res[100];
          Graph_ctx gr_ctx;
          Graph_ctx *gr = &gr_ctx;
          double xx = X_TO_XSCHEM(atof(argv[3]));
          double yy = Y_TO_XSCHEM(atof(argv[4]));
          /* setup_graph_data() RETURNS EARLY for an off-screen graph (draw.c, the
           * RECT_OUTSIDE test) WITHOUT computing the cx/dx/cy/dy transform, so
           * zero it first and treat a still-zero scale as "no transform": G_X/G_Y
           * divide by cx/cy, which would otherwise be a garbage/inf anchor. Empty
           * result -> the caller zooms about centre instead. */
          memset(&gr_ctx, 0, sizeof(gr_ctx));
          setup_graph_data(i, 0, gr);
          if(gr->cx != 0.0 && gr->cy != 0.0) {
            my_snprintf(res, S(res), "%.16g %.16g", G_X(xx), G_Y(yy));
            Tcl_SetResult(interp, res, TCL_VOLATILE); /* copies: stack buf is fine */
          }
        }
      }
    }

    /* xschem graph_axis_zoom <graph_idx> x|y <lo> <hi>      (issue 0190)
     *
     * THE APPLY, and the replay form of the LMB axis-margin drag: 1 when
     * anything was written, 0 for a bad/non-graph index. Fails LOUD (usage +
     * TCL_ERROR) on a wrong argc or an unknown axis word -- a script wants a
     * catchable error, which is the same split the graph_marker verbs use.
     *
     * X writes x1/x2 on that rect AND on every PARTICIPATING rect (the shipped
     * predicate of the MMB pan / RMB box zoom), which is why the log line is the
     * verb and not a setprop: one line replays the whole propagation. Y writes
     * y1/y2 -- ypos1/ypos2 on a digital strip -- on that rect only.
     *
     * ⚠ Deliberately NOT scheduler_readonly_reject()ed, unlike graph_marker.
     * A range write is VIEW state the engine has always been allowed to put in
     * a read-only rect (landmine 17 names the box zoom by name); the ASE viewer
     * is read-only for its whole life and its MMB pan and RMB box zoom already
     * write there. Rejecting would break the viewer's own gesture AND abort any
     * replay of the line this verb logs. A marker is durable CONTENT and is
     * gated; a zoom is not. */
    else if(!strcmp(argv[1], "graph_axis_zoom"))
    {
      int ax = GRAPH_AXIS_NONE;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 6) {
        Tcl_SetResult(interp, "xschem graph_axis_zoom: usage: <graph_idx> x|y <lo> <hi>",
                      TCL_STATIC);
        return TCL_ERROR;
      }
      if(!strcmp(argv[3], "x")) ax = GRAPH_AXIS_X;
      else if(!strcmp(argv[3], "y")) ax = GRAPH_AXIS_Y;
      else {
        Tcl_SetResult(interp, "xschem graph_axis_zoom: axis must be x or y", TCL_STATIC);
        return TCL_ERROR;
      }
      Tcl_SetResult(interp,
        my_itoa(graph_axis_zoom(atoi(argv[2]), ax, atof(argv[4]), atof(argv[5]))),
        TCL_VOLATILE);
    }

    /* xschem graph_marker <sub> ...   (doc/claude/specs/graph_markers.md)
     *
     * The MUTATING half of the marker surface -- fails LOUD (usage + TCL_ERROR),
     * unlike the `xschem get graph_marker_*` getters which fail soft. Must live
     * in xschem_cmds_g: the top-level dispatch is on argv[1][0], so a verb in the
     * wrong first-letter function is reachable only as "invalid command".
     *
     * Persistence needs no verb of its own -- `xschem getprop/setprop rect 2 <i>
     * markers` already round-trips the multi-line token exactly.
     *
     *   add       <gi> <px> <py> [-delta]              -> new number | {}
     *   add_at    <gi> <wave> <dset> <point> [-delta]  -> new number | {}
     *   anchor    <num> <dset> <point>                 -> 1|0
     *   move      <num> <px> <py>                      -> 1|0
     *   label     <num> <ldx> <ldy>                    -> 1|0
     *   delete    <num> | -all [<gi>] | -selected      -> 1|0 | count | count
     *   select    <num> [<gi>] | -none                 -> the new selection HEAD
     *             | -pair <num> [<gi>] | -set <n1> ... -> ditto (issue 0189)
     *   list      [<gi>]  -> {{num graph wave dset point x y prev ldx ldy} ...}
     *   text      <num>   -> the rendered label (embedded newlines)
     *
     * The SELECTION IS A SET since issue 0189, held in xctx and never in a
     * token. Every `select` form still returns the HEAD -- read the whole set
     * with `xschem get graph_marker_sel_set`. `-pair` adds the `prev` partner
     * of a difference marker when it resolves; `delete -selected` removes the
     * whole set under ONE undo point.
     */
    else if(!strcmp(argv[1], "graph_marker"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem graph_marker: usage: add|add_at|anchor|move|label|"
                              "delete|select|list|text ...", TCL_STATIC);
        return TCL_ERROR;
      }
      /* `select` is pure UI state, `list`/`text` are queries: not readonly-gated.
       * Everything else mutates content and is (the ASE viewer defeats the gate
       * deliberately through wviewer::with_edit, the established pattern). */
      if(strcmp(argv[2], "select") && strcmp(argv[2], "list") && strcmp(argv[2], "text")) {
        if(scheduler_readonly_reject(interp, "graph_marker")) return TCL_ERROR;
      }
      Tcl_ResetResult(interp);
      if(!strcmp(argv[2], "add") && argc > 5) {
        int delta = (argc > 6 && !strcmp(argv[6], "-delta"));
        int num = graph_marker_create(atoi(argv[3]), atof(argv[4]), atof(argv[5]), delta);
        /* reset on refusal too: the engine's extra_rawfile() does a tclvareval
         * internally and leaves the substituted filename in the interp result,
         * so "" is only really "" if we clear it here */
        if(num > 0) Tcl_SetResult(interp, my_itoa(num), TCL_VOLATILE);
        else Tcl_ResetResult(interp);
      }
      /* xschem graph_marker add_at <gi> <wave> <dataset> <point> [-delta] [<x> <y>]
       *
       * The trailing position is issue 0193: a marker sits on the POINT OF THE
       * CURVE the diamond snapped to, which is only a sample when the pointer
       * happened to be at one. (dataset, point) remains the anchor. The tail is
       * scanned rather than positional so every log line written before 0193 --
       * which has no x/y and meant "the sample" -- still replays unchanged, and
       * so `-delta` keeps working on either side of the numbers. */
      else if(!strcmp(argv[2], "add_at") && argc > 6) {
        int delta = 0, have_xy = 0, k;
        double mx = 0.0, my = 0.0;
        for(k = 7; k < argc; k++) {
          if(!strcmp(argv[k], "-delta")) delta = 1;
          else if(!have_xy && k + 1 < argc && strcmp(argv[k + 1], "-delta")) {
            mx = atof(argv[k]); my = atof(argv[k + 1]); have_xy = 1; k++;
          }
        }
        {
          int num = graph_marker_create_at(atoi(argv[3]), atoi(argv[4]), atoi(argv[5]),
                                           atoi(argv[6]), delta, have_xy, mx, my);
          if(num > 0) Tcl_SetResult(interp, my_itoa(num), TCL_VOLATILE);
          else Tcl_ResetResult(interp);
        }
      }
      /* xschem graph_marker anchor <num> <dataset> <point> [<x> <y>] -- same
       * rule: no position means "the sample", which is what the old lines said. */
      else if(!strcmp(argv[2], "anchor") && argc > 5) {
        int have_xy = (argc > 7);
        double mx = have_xy ? atof(argv[6]) : 0.0;
        double my = have_xy ? atof(argv[7]) : 0.0;
        Tcl_SetResult(interp,
          my_itoa(graph_marker_anchor_at(atoi(argv[3]), atoi(argv[4]), atoi(argv[5]),
                                         have_xy, mx, my)),
          TCL_VOLATILE);
      }
      else if(!strcmp(argv[2], "move") && argc > 5) {
        Tcl_SetResult(interp,
          my_itoa(graph_marker_move(atoi(argv[3]), atof(argv[4]), atof(argv[5]))),
          TCL_VOLATILE);
      }
      else if(!strcmp(argv[2], "label") && argc > 5) {
        Tcl_SetResult(interp,
          my_itoa(graph_marker_label_offset(atoi(argv[3]), atof(argv[4]), atof(argv[5]))),
          TCL_VOLATILE);
      }
      else if(!strcmp(argv[2], "delete") && argc > 3) {
        if(!strcmp(argv[3], "-all")) {
          int gi = (argc > 4) ? atoi(argv[4]) : -1;
          Tcl_SetResult(interp, my_itoa(graph_marker_delete_all(gi)), TCL_VOLATILE);
        /* -selected: the whole selection, ONE undo point (issue 0189). Exists so
         * the multi-delete, its undo-point count and its `prev` sweep are
         * assertable in BOTH test arms -- the C Delete key path is DISPLAY-only. */
        } else if(!strcmp(argv[3], "-selected")) {
          Tcl_SetResult(interp, my_itoa(graph_marker_delete_selected()), TCL_VOLATILE);
        } else {
          Tcl_SetResult(interp, my_itoa(graph_marker_delete(atoi(argv[3]))), TCL_VOLATILE);
        }
      }
      else if(!strcmp(argv[2], "select") && argc > 3) {
        int res;
        if(!strcmp(argv[3], "-none")) res = graph_marker_select(-1, -1);
        /* -pair: the double-click policy, scriptable. Adds the `prev` partner
         * only when it resolves -- the immediate pair, never the chain. */
        else if(!strcmp(argv[3], "-pair")) {
          if(argc > 4)
            res = graph_marker_select_pair(atoi(argv[4]),
                    (argc > 5) ? atoi(argv[5]) : xctx->graph_master);
          else res = xctx->graph_marker_sel;
        }
        /* -set: an explicit list, permissive like `select <num>` (D-18). It
         * dedupes and caps; the ORDER given is the selection order. */
        else if(!strcmp(argv[3], "-set")) {
          int nums[GRAPH_MARKER_MAX_SEL];
          int k, n = 0;
          for(k = 4; k < argc && n < GRAPH_MARKER_MAX_SEL; k++) nums[n++] = atoi(argv[k]);
          res = graph_marker_select_set(nums, n, xctx->graph_master);
        }
        else res = graph_marker_select(atoi(argv[3]), (argc > 4) ? atoi(argv[4]) : xctx->graph_master);
        /* EVERY form answers the HEAD, including -pair/-set: the set is read
         * with `xschem get graph_marker_sel_set` (D-16). */
        Tcl_SetResult(interp, my_itoa(res), TCL_VOLATILE);
      }
      else if(!strcmp(argv[2], "list")) {
        int gi, want = (argc > 3) ? atoi(argv[3]) : -1;
        Tcl_Obj *lst = Tcl_NewListObj(0, NULL);
        for(gi = 0; gi < xctx->rects[GRIDLAYER]; gi++) {
          GraphMarker *a = NULL;
          int n = 0, k;
          if(!(xctx->rect[GRIDLAYER][gi].flags & 1)) continue;
          if(want >= 0 && want != gi) continue;
          n = graph_markers_parse(xctx->rect[GRIDLAYER][gi].prop_ptr, &a, &n);
          for(k = 0; k < n; k++) {
            char buf[128];
            Tcl_Obj *rec = Tcl_NewListObj(0, NULL);
            Tcl_ListObjAppendElement(interp, rec, Tcl_NewIntObj(a[k].num));
            Tcl_ListObjAppendElement(interp, rec, Tcl_NewIntObj(gi));
            Tcl_ListObjAppendElement(interp, rec, Tcl_NewIntObj(a[k].wave));
            Tcl_ListObjAppendElement(interp, rec, Tcl_NewIntObj(a[k].dataset));
            Tcl_ListObjAppendElement(interp, rec, Tcl_NewIntObj(a[k].point));
            /* %.17g, not Tcl's 6-significant-digit default: this is the seam the
             * tests assert exactness against */
            my_snprintf(buf, S(buf), "%.17g", a[k].x);
            Tcl_ListObjAppendElement(interp, rec, Tcl_NewStringObj(buf, -1));
            my_snprintf(buf, S(buf), "%.17g", a[k].y);
            Tcl_ListObjAppendElement(interp, rec, Tcl_NewStringObj(buf, -1));
            Tcl_ListObjAppendElement(interp, rec, Tcl_NewIntObj(a[k].prev));
            my_snprintf(buf, S(buf), "%.10g", a[k].ldx);
            Tcl_ListObjAppendElement(interp, rec, Tcl_NewStringObj(buf, -1));
            my_snprintf(buf, S(buf), "%.10g", a[k].ldy);
            Tcl_ListObjAppendElement(interp, rec, Tcl_NewStringObj(buf, -1));
            Tcl_ListObjAppendElement(interp, lst, rec);
          }
          if(a) my_free(_ALLOC_ID_, &a);
        }
        Tcl_SetObjResult(interp, lst);
      }
      else if(!strcmp(argv[2], "text") && argc > 3) {
        char buf[512];
        if(graph_marker_text(atoi(argv[3]), buf, S(buf)))
          Tcl_SetResult(interp, buf, TCL_VOLATILE);
        else Tcl_ResetResult(interp);
      }
      else {
        Tcl_SetResult(interp, "xschem graph_marker: usage: add|add_at|anchor|move|label|"
                              "delete|select|list|text ...", TCL_STATIC);
        return TCL_ERROR;
      }
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}


/* Cadence-style interactive net (un)highlight, shared by the '9' (add) and '8' (remove)
 * commands which live in different first-letter dispatch groups. Noun-verb when a
 * net/label/pin is selected (act on it; highlight keeps the selection and advances the
 * style per net); else verb-noun: enter the click-loop mode with a statusbar + CIW
 * prompt (clicks handled in callback.c::net_hilight_mode_click, ESC exits). */
static void net_hilight_interactive(int add)
{
  int n, has_net = 0;
  rebuild_selected_array();
  for(n = 0; n < xctx->lastsel; ++n)
    if(xctx->sel_array[n].type == WIRE || xctx->sel_array[n].type == ELEMENT) { has_net = 1; break; }
  if(has_net) { /* noun-verb */
    if(add) {
      hilight_net_styled();           /* re-style + advance cursor per net (shared), keep selection */
      redraw_hilights(0);
    } else {
      unhilight_net(1); /* noun-verb: remove highlight but keep the selection (like key 9) */
    }
    /* self-log at core (0067): the Cadence-rc keys 9/8 are raw `bind .drw <Key> {xschem
     * <sub>}` -- they bypass dispatch_input_action, so only this core self-log records
     * them. Log the real command (like the registered `xschem hilight` on K); it replays
     * against the replay-time selection (the same accepted selection-dependency, 0005).
     * ONLY the noun-verb branch acts immediately -- the verb-noun branch below merely
     * ENTERS interactive click-mode (a gesture start; each click's effect is 0005/0069),
     * so it stays silent, matching the Phase-3 log-the-effect-not-the-start rule. */
    log_action(add ? "xschem hilight_net_interactive" : "xschem unhilight_net_interactive");
  } else {      /* verb-noun: enter interactive mode */
    if(add) { xctx->ui_state &= ~NET_UNHILIGHT; xctx->ui_state |= NET_HILIGHT; }
    else    { xctx->ui_state &= ~NET_HILIGHT;   xctx->ui_state |= NET_UNHILIGHT; }
    tclvareval(xctx->top_path, ".statusbar.10 configure -state active -text {",
      add ? "HIGHLIGHT NET! (click a net or label, ESC to end) "
          : "UNHIGHLIGHT NET! (click a net or label, ESC to end) ", "}", NULL);
    tcleval(add
      ? "if {[info procs ciw_echo] ne {}} {ciw_echo {Highlight net: click a net or label to highlight it; press ESC to end.}}"
      : "if {[info procs ciw_echo] ne {}} {ciw_echo {Unhighlight net: click a highlighted net or label to clear it; press ESC to end.}}");
  }
}

/* `xschem h...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_h(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* hash_file file [skip_path_lines]
     *   Do a simple hash of 'file'
     *   'skip_path_lines' is an integer (default: 0) passed to hash_file() */
    if(!strcmp(argv[1], "hash_file"))
    {
      unsigned int h;
      char s[40];
      if(argc > 2) {
        if(argc > 3) {
          h = hash_file(argv[2], atoi(argv[3]));
        } else {
          h = hash_file(argv[2], 0);
        }
        my_snprintf(s, S(s), "%u", h);
        Tcl_SetResult(interp, s, TCL_VOLATILE);
      }
    }

    /* hash_string str
     *   Do a simple hashing of string 'str' */
    else if(!strcmp(argv[1], "hash_string"))
    {
      if(argc > 2) {
        unsigned int h;
        char s[50];
        h = str_hash(argv[2]);
        my_snprintf(s, S(s), "%u", h);
        Tcl_SetResult(interp, s, TCL_VOLATILE);
      }
    }

    /* help
     *  Print command help */
    else if(!strcmp(argv[1], "help"))
    {
      xschem_cmd_help(argc, argv);
    }

    /* hover
     *   The hover (awareness) highlight. Return the uniform descriptor dict of the
     *   object currently under the tracking cursor (same {type index layer id name}
     *   format as `xschem object`), or "" if none. Read-only — the outline itself
     *   is driven by motion events (draw_hover()). */
    else if(!strcmp(argv[1], "hover"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(xctx->hover_type) {
        char buf[512];
        object_descriptor(buf, S(buf), xctx->hover_type, xctx->hover_n, xctx->hover_col);
        Tcl_SetResult(interp, buf, TCL_VOLATILE);
      } else {
        Tcl_ResetResult(interp);
      }
    }

    /* hier_psprint [file]
     *   Hierarchical postscript / pdf print
     *   if 'file' is not given show a fileselector dialog box */
    else if(!strcmp(argv[1], "hier_psprint"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        my_strncpy(xctx->plotfile, argv[2], S(xctx->plotfile));
      }
      hier_psprint(NULL, 1);
      Tcl_ResetResult(interp);
    }

    /* highlight_scope [clear | ids | <scope> <displayed_id>]
     *   The apply-scope highlight overlay (the white outline on edit targets).
     *   With <scope> <displayed_id>: resolve the SAME set apply_symbol_prop
     *   would write (shared scope_targets(), so outlined==applied) relative to
     *   the displayed instance's stable id, store it as the overlay, redraw, and
     *   return the resolved stable-id list. No args: return the overlay count.
     *   'ids': return the stored stable-id list. 'clear': empty + redraw. */
    else if(!strcmp(argv[1], "highlight_scope"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc == 2) {
        Tcl_SetResult(interp, my_itoa(xctx->scope_hi_n), TCL_VOLATILE);
      } else if(!strcmp(argv[2], "clear")) {
        clear_scope_highlight();
        draw();
        Tcl_ResetResult(interp); /* draw() leaves a stale tcleval result */
      } else if(!strcmp(argv[2], "ids")) {
        int k;
        for(k = 0; k < xctx->scope_hi_n; ++k)
          Tcl_AppendElement(interp, my_itoa((int)xctx->scope_hi_id[k]));
      } else if(argc == 4) {
        int idx = inst_index_from_id((unsigned int)strtoul(argv[3], NULL, 10));
        int *targets, n, k;
        if(idx < 0) { Tcl_SetResult(interp, "", TCL_STATIC); return TCL_OK; }
        rebuild_selected_array(); /* 'selected' scope reads the live selection */
        targets = my_malloc(_ALLOC_ID_, (xctx->instances + 1) * sizeof(int));
        n = scope_targets(idx, argv[2], targets);
        clear_scope_highlight();
        for(k = 0; k < n; ++k) add_scope_highlight(ELEMENT, xctx->inst[targets[k]].id);
        my_free(_ALLOC_ID_, &targets);
        draw();
        /* build the result AFTER draw() (its internal tcleval()s clobber the
         * interp result); report from the stored overlay = the resolved set. */
        Tcl_ResetResult(interp);
        for(k = 0; k < xctx->scope_hi_n; ++k)
          Tcl_AppendElement(interp, my_itoa((int)xctx->scope_hi_id[k]));
      } else {
        Tcl_SetResult(interp,
          "xschem highlight_scope needs: [clear | ids | <scope> <displayed_id>]", TCL_STATIC);
        return TCL_ERROR;
      }
    }

    /* highlight_pin_scope [clear | ids | <scope>]
     *   Pin analog of highlight_scope: outline the symbol pins an Apply with <scope>
     *   (current|selected|all) would touch, resolved by the SHARED pin_scope_resolve() so the
     *   outlined set == the applied set by construction. Stores the pins' rect[PINLAYER] stable
     *   ids in the same overlay store (draw_scope_highlight's xRECT case renders them), redraws,
     *   and returns the resolved id list. No args: overlay count. 'ids': stored ids. 'clear':
     *   empty + redraw. (doc/claude/specs/symbol_editor_apply_scope.md §5.4) */
    else if(!strcmp(argv[1], "highlight_pin_scope"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc == 2) {
        Tcl_SetResult(interp, my_itoa(xctx->scope_hi_n), TCL_VOLATILE);
      } else if(!strcmp(argv[2], "clear")) {
        clear_scope_highlight();
        draw();
        Tcl_ResetResult(interp); /* draw() leaves a stale tcleval result */
      } else if(!strcmp(argv[2], "ids")) {
        int k;
        for(k = 0; k < xctx->scope_hi_n; ++k)
          Tcl_AppendElement(interp, my_itoa((int)xctx->scope_hi_id[k]));
      } else if(argc == 3) {
        int *targets, n, k, primary;
        n = pin_scope_resolve(argv[2], &primary, &targets);
        clear_scope_highlight();
        for(k = 0; k < n; ++k)
          add_scope_highlight(xRECT, xctx->rect[PINLAYER][targets[k]].id);
        my_free(_ALLOC_ID_, &targets);
        draw();
        /* build the result AFTER draw() (its internal tcleval()s clobber the interp
         * result); report from the stored overlay = the resolved set. */
        Tcl_ResetResult(interp);
        for(k = 0; k < xctx->scope_hi_n; ++k)
          Tcl_AppendElement(interp, my_itoa((int)xctx->scope_hi_id[k]));
      } else {
        Tcl_SetResult(interp,
          "xschem highlight_pin_scope needs: [clear | ids | <scope>]", TCL_STATIC);
        return TCL_ERROR;
      }
    }

    /* highlight_objects <type> <id> [<type> <id> ...]
     *   The GENERAL overlay primitive: outline an explicit list of drawable
     *   objects (any of wire|instance|rect|line|poly|arc), each by its stable id,
     *   in its natural shape. The property form only ever feeds instances (via
     *   highlight_scope), but this proves the per-type dispatch — notably a WIRE
     *   outlined as its line segment. Returns the resulting overlay count. */
    else if(!strcmp(argv[1], "highlight_objects"))
    {
      int j;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3 || ((argc - 2) % 2) != 0) {
        Tcl_SetResult(interp,
          "xschem highlight_objects needs: <type> <id> [<type> <id> ...]", TCL_STATIC);
        return TCL_ERROR;
      }
      clear_scope_highlight();
      for(j = 2; j + 1 < argc; j += 2) {
        int type = object_type_from_name(argv[j]);
        if(type >= 0)
          add_scope_highlight(type, (unsigned int)strtoul(argv[j + 1], NULL, 10));
      }
      draw();
      Tcl_SetResult(interp, my_itoa(xctx->scope_hi_n), TCL_VOLATILE);
    }

    /* hilight [drill]
     *   Highlight selected element/pins/labels/nets
     *   if 'drill' is given propagate net highlights through conducting elements
     *   (elements that have the 'propag' attribute on pins ) */
    else if(!strcmp(argv[1], "hilight"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      xctx->enable_drill = 0;
      if(argc >=3 && !strcmp(argv[2], "drill")) xctx->enable_drill = 1;
      hilight_net(0);
      redraw_hilights(0);
      net_hilight_anim_update(); /* Pass 2a: the standard highlight path may add a blink style */
      net_hilight_sync_descend_windows(); /* issue 0073: push into linked descend children */
      Tcl_ResetResult(interp);
    }
    /* hilight_net_interactive
     *   Cadence-style key '9': noun-verb if a net/label/pin is selected (highlight it,
     *   advancing the style cursor per net, leaving the selection intact); else verb-noun
     *   (enter interactive highlight mode: each click highlights the net under the cursor
     *   with the next style, until ESC). */
    else if(!strcmp(argv[1], "hilight_net_interactive"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      net_hilight_interactive(1);
      Tcl_ResetResult(interp);
    }
    /* hilight_instname [-fast] [-layer <n>] inst
     *   Highlight instance 'inst'
     * if '-fast' is specified do not redraw
     *   'inst' can be an instance name or number
     *   -layer <n>  highlight in the plain color of drawing layer n instead of the next
     *               style from the net-hilight style table, and do NOT advance the style
     *               cursor. Same mechanism and same rationale as hilight_netname -layer
     *               (see there): a negative hilight value means "layer color, no style".
     *               Used by the ASE Direct Plot signal picker to paint a current-probe
     *               source body in the color its waveform trace will use. */
    else if(!strcmp(argv[1], "hilight_instname"))
    {
      const char *instname=NULL;
      int i, fast = 0, layer = 0;

      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 2; i < argc; i++) {
        if(argv[i][0] == '-') {
          if(!strcmp(argv[i], "-fast")) {
            fast = 1;
          } else if(!strcmp(argv[i], "-layer") && i + 1 < argc) {
            layer = atoi(argv[++i]);
            if(layer <= 0 || layer >= cadlayers) {
              Tcl_SetResult(interp, "hilight_instname: -layer must be in 1..cadlayers-1", TCL_STATIC);
              return TCL_ERROR;
            }
          }
        } else {
          instname = argv[i];
          break;
        }
      }
      if(instname) {
        int inst;
        char *type;
        int incr_hi;
        int saved_col = xctx->hilight_color;
        xctx->enable_drill=0;
        incr_hi = tclgetboolvar("incr_hilight");
        /* an explicit layer neither uses nor advances the style cursor */
        if(layer) { xctx->hilight_color = -layer; incr_hi = 0; }
        prepare_netlist_structs(0);
        if((inst = get_instance(instname)) < 0 ) {
          xctx->hilight_color = saved_col; /* restore on the error path too */
          Tcl_SetResult(interp, "xschem hilight_instname: instance not found", TCL_STATIC);
          return TCL_ERROR;
        } else {
          type = (xctx->inst[inst].ptr+ xctx->sym)->type;
          if( type && xctx->inst[inst].node && IS_LABEL_SH_OR_PIN(type) ) { /* instance must have a pin! */
                /* sets xctx->hilight_nets=1 */
            if(!bus_hilight_hash_lookup(xctx->inst[inst].node[0], xctx->hilight_color, XINSERT_NOREPLACE)) {
              dbg(1, "xschem hilight_instname: node=%s\n", xctx->inst[inst].node[0]);
              if(incr_hi) incr_hilight_color();
            }
          } else {
            dbg(1, "xschem hilight_instname: setting hilight flag on inst %d\n",inst);
            /* xctx->hilight_nets=1; */  /* done in hilight_hash_lookup() */
            xctx->inst[inst].color = xctx->hilight_color;
            inst_hilight_hash_lookup(inst, xctx->hilight_color, XINSERT_NOREPLACE);
            if(incr_hi) incr_hilight_color();
          }
          dbg(1, "hilight_nets=%d\n", xctx->hilight_nets);
          if(!fast) {
            if(xctx->hilight_nets) propagate_hilights(1, 0, XINSERT_NOREPLACE);
            redraw_hilights(0);
            net_hilight_sync_descend_windows(); /* issue 0073: push into linked descend children */
          }
        }
        xctx->hilight_color = saved_col; /* no-op unless -layer overrode it */
      }
      Tcl_ResetResult(interp);
    }

    /* hilight_buried <instname>
     *   Read-only query: return the style index of a highlighted net buried in the
     *   named instance's subtree (a net not exposed at the instance's pins), or -1 if
     *   none. Derived state recomputed in propagate_hilights(); this only reads
     *   inst[i].buried_hilight. See doc/claude/specs/buried_net_hilight.md */
    else if(!strcmp(argv[1], "hilight_buried"))
    {
      int inst, val = -1;
      char res[30];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem hilight_buried: missing instance name", TCL_STATIC);
        return TCL_ERROR;
      }
      prepare_netlist_structs(0);
      if((inst = get_instance(argv[2])) >= 0) val = xctx->inst[inst].buried_hilight;
      my_snprintf(res, S(res), "%d", val);
      Tcl_SetResult(interp, res, TCL_VOLATILE);
    }

    /* hilight_netname [-fast] [-style <n> | -layer <n>] net
     *   Highlight net name 'net'
     *   if '-fast' is given do not redraw hilights after operation
     *   -style <n>  highlight with net-hilight-style index n (the style table decides
     *               color/width/dash/animation); does not advance the style cursor
     *   -layer <n>  highlight in the PLAIN COLOR OF DRAWING LAYER n, bypassing the style
     *               table entirely (no width/dash/blink). Needed by callers that must
     *               match a color chosen elsewhere in layer terms -- the ASE Direct Plot
     *               signal picker paints each wire in the layer its waveform trace will
     *               use (doc/claude/issues/0153-*), and layers 4/5 of the viewer palette
     *               have no style-table entry at all (default styles cover layers >= 7
     *               only, hilight.c default_net_hilight_styles). Implemented with the
     *               NEGATIVE hilight value the engine already uses for this exact
     *               purpose (get_color/hilight_pixel_of: value < 0 -> layer -value),
     *               as draw.c's auto_hilight_graph_nodes path does via
     *               hilight_graph_node(). Layer 0 is the background and is refused
     *               (-0 == 0 == style 0). */
    else if(!strcmp(argv[1], "hilight_netname"))
    {
      int ret = 0, fast = 0, i, style = 0, have_style = 0;
      const char *net = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 2; i < argc; i++) {
        if(argv[i][0] == '-') {
          if(!strcmp(argv[i], "-fast")) {
            fast = 1;
          } else if(!strcmp(argv[i], "-style") && i + 1 < argc) {
            style = atoi(argv[++i]); /* explicit style index; does not advance the cursor */
            if(style < 0) {
              Tcl_SetResult(interp, "hilight_netname: -style index must be >= 0", TCL_STATIC);
              return TCL_ERROR;
            }
            have_style = 1;
          } else if(!strcmp(argv[i], "-layer") && i + 1 < argc) {
            int layer = atoi(argv[++i]);
            if(layer <= 0 || layer >= cadlayers) {
              Tcl_SetResult(interp, "hilight_netname: -layer must be in 1..cadlayers-1", TCL_STATIC);
              return TCL_ERROR;
            }
            style = -layer; /* negative hilight value = plain layer color, no style */
            have_style = 1;
          }
        } else {
          net = argv[i];
          break;
        }
      }
      if(net && have_style) {
        /* highlight with an explicit style/layer: set the cursor, then restore it so the
         * style cursor is neither used nor advanced (waveform-viewer / scripted bridge) */
        int saved = xctx->hilight_color;
        xctx->hilight_color = style;
        ret = hilight_netname(net, fast);
        xctx->hilight_color = saved;
      } else if(net) {
        ret = hilight_netname(net,  fast);
      }
      Tcl_SetResult(interp, ret ? "1" : "0" , TCL_STATIC);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem i...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_i(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* incr_hilight_color
     *   Step the net-highlight style cursor forward one (wrapping modulo the number
     *   of styles) and return the resulting style index. This normally happens
     *   automatically per highlight; exposed for symmetry with decr_hilight_color.
     *   See doc/claude/specs/hilight_style_decrement.md */
    if(!strcmp(argv[1], "incr_hilight_color"))
    {
      char res[30];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(!xctx->net_hilight_style || xctx->n_net_hilight_styles <= 0) build_net_hilight_styles();
      incr_hilight_color();
      my_snprintf(res, S(res), "%d", xctx->hilight_color);
      Tcl_SetResult(interp, res, TCL_VOLATILE);
    }
    /* inst_name_text inst
     *   For the named/indexed instance, find the symbol text that displays the net/pin
     *   NAME (the "@lab" text of a pin / net label) and return "<index> <size>", where
     *   size is its current effective display size -- the per-instance text_size_<n>
     *   override if present, else the symbol's default text xscale (via
     *   get_sym_text_size). Returns "" when the symbol has no @lab text (e.g. a normal
     *   component), so callers skip non-label instances. Read-only.
     *   Used by the CTRL+Plus/Minus text-size feature, doc/claude/specs/text_size_scroll.md */
    else if(!strcmp(argv[1], "inst_name_text"))
    {
      int i, j, symn, idx = -1;
      double xs, ys;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem inst_name_text needs <inst>", TCL_STATIC); return TCL_ERROR;
      }
      i = get_instance(argv[2]);
      if(i < 0) {
        Tcl_AppendResult(interp, "xschem inst_name_text: instance not found: ", argv[2], NULL);
        return TCL_ERROR;
      }
      symn = xctx->inst[i].ptr;
      if(symn >= 0) {
        for(j = 0; j < xctx->sym[symn].texts; ++j) {
          const char *tp = xctx->sym[symn].text[j].txt_ptr;
          if(tp && !strcmp(tp, "@lab")) { idx = j; break; }
        }
      }
      if(idx < 0) {
        Tcl_ResetResult(interp);
      } else {
        char buf[60];
        get_sym_text_size(i, idx, &xs, &ys);
        my_snprintf(buf, S(buf), "%d %.10g", idx, xs);
        Tcl_SetResult(interp, buf, TCL_VOLATILE);
      }
    }
    #if HAS_CAIRO==1
    /* image [invert|white_transp|black_transp|transp_white|transp_black|write_back|
     *        blend_white|blend_black]
     *   Apply required changes to selected images
     *   invert: invert colors
     *   white_transp: transform white color to transparent (alpha=0)
     *   black_transp: transform black color to transparent (alpha=0)
     *   transp_white: transform transparent to white color
     *   transp_black: transform transparent to black color
     *   blend_white:  blend with white background and remove alpha
     *   blend_black:  blend with black background and remove alpha
     *   write_back:   write resulting image back into `image_data` attribute
     */
    else if(!strcmp(argv[1], "image"))
    {
      /* Refactor B atom 20 (audit §40): the FIRST HAS_CAIRO-gated migration and the first verb with
       * a read-only-SAFE query sub-form. Only the MUTATING tail routes through the boundary; the two
       * pre-mutation read-only-safe replies stay RAW here IN FRONT of it -- `help` (a static usage
       * string) and the argc<3 "Missing arguments" validation -- because the boundary's ONE readonly
       * gate (scheduler.c:1031) is unconditional per-verb: routing `image help` through it would
       * REFUSE a pure query on a read-only cell (the read-only-safe-query over-reject the atom-19
       * handoff flagged). This is the wire_cut §37 form-split (coord form -> boundary, no-mutation
       * gesture-start -> raw) applied to a query/mutate split. Everything past help -- the
       * `No images selected` precondition, the flag parse, the CONDITIONAL push_undo + the
       * edit_image loop over the selected GRIDLAYER image rects, set_modify-only-on-write_back, and
       * the ONE faithful `xschem image <flag>...` log site -- lives in perform_action/run_core. The
       * boundary ADDS the C read-only gate the verb NEVER HAD (a correctness fix: pre-migration
       * `image invert` MUTATED a read-only cell). !xctx stays first to preserve the pre-migration
       * precedence (not_avail BEFORE help). */
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "Missing arguments", TCL_STATIC);
        return TCL_ERROR;
      }
      if(!strcmp(argv[2], "help")) {
        Tcl_SetResult(interp,
           "xschem image [invert|white_transp|black_transp|transp_white|transp_black|\n"
           "              blend_white|blend_black|write_back]",
            TCL_STATIC);
        return TCL_OK;
      }
      return perform_action("image", argc, argv);
    }
    #endif
    /* instance sym_name x y rot flip [prop] [n]
     *   Place a new instance of symbol 'sym_name' at position x,y,
     *   rotation and flip  set to 'rot', 'flip'
     *   if 'prop' is given it is the new instance attribute
     *   string (default: symbol template string)
     *   if 'n' is given it must be 0 on first call
     *   and non zero on following calls
     *   It is used only for efficiency reasons if placing multiple instances */
    else if(!strcmp(argv[1], "instance"))
    {
      int placed = 0; /* issue 0125: rc of place_symbol, 1-placed / 0-refused */
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "instance")) return TCL_ERROR;
      if(argc==7) {
       /*           pos sym_name      x                y             rot       */
        placed = place_symbol(-1, argv[2], atof(argv[3]), atof(argv[4]), (short)atoi(argv[5]),
               /* flip              prop draw first to_push_undo */
               (short)atoi(argv[6]),NULL,  3,   1,      1);
      } else if(argc==8) {
        placed = place_symbol(-1, argv[2], atof(argv[3]), atof(argv[4]), (short)atoi(argv[5]),
               (short)atoi(argv[6]), argv[7], 3, 1, 1);
      } else if(argc==9) {
        int x = !(atoi(argv[8]));
        placed = place_symbol(-1, argv[2], atof(argv[3]), atof(argv[4]), (short)atoi(argv[5]),
               (short)atoi(argv[6]), argv[7], 0, x, 1);
      }
      /* issue 0125: a refusal (symbol-view guard, empty name, scope-ammeter bail) must not
       * dirty the buffer; it used to set_modify(1) unconditionally and leak a stale result */
      if(placed) set_modify(1);
      /* W3: a placed instance may drop a pin / net-label onto a wire -> split it into
       * inter-attachment segments (maintain = split + pin-aware merge); if it lands off any
       * wire nothing changes. Gated on autotrim_wires; place_symbol already pushed undo, so
       * this rides the same transaction. See doc/claude/specs/wire_segment_splitting.md (W3). */
      if(placed && tclgetboolvar("autotrim_wires")) maintain_wire_segments();
      Tcl_SetResult(interp, placed ? "1" : "0", TCL_STATIC); /* issue 0125: 1-placed / 0-refused */
    }

    /* instance_at <x> <y>
     *   The name of the instance whose bounding box contains the schematic-coordinate
     *   point (x,y), or "" if there is none. READ-ONLY: it selects nothing and changes
     *   nothing -- this is the probe half of the verb-noun descend pick, and the
     *   deliberate opposite of `select_at`, which is the mutating coordinate pick.
     *   Locked instances are reported (selection is the lock, issue 0160; a probe that
     *   never selects cannot make one editable).
     *   doc/claude/issues/0200-descend-has-no-verb-noun-pick.md */
    else if(!strcmp(argv[1], "instance_at"))
    {
      int i;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 4) {
        Tcl_SetResult(interp, "xschem instance_at: x and y required", TCL_STATIC);
        return TCL_ERROR;
      }
      i = find_closest_instance(atof(argv[2]), atof(argv[3]), 1);
      Tcl_ResetResult(interp);
      if(i >= 0 && xctx->inst[i].instname) Tcl_AppendResult(interp, xctx->inst[i].instname, NULL);
    }

    /* instance_bbox inst
     *   return instance and symbol bounding boxes
     *   'inst' can be an instance name or number */
    else if(!strcmp(argv[1], "instance_bbox"))
    {
      int i;
      char s[200];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        if((i = get_instance(argv[2])) < 0 ) {
          Tcl_SetResult(interp, "xschem instance_bbox: instance not found", TCL_STATIC);
          return TCL_ERROR;
        }

        my_snprintf(s, S(s), "Instance: %g %g %g %g", xctx->inst[i].x1, xctx->inst[i].y1,
                                                       xctx->inst[i].x2, xctx->inst[i].y2);
        Tcl_AppendResult(interp, s, NULL);
        my_snprintf(s, S(s), "\nSymbol: %g %g %g %g",
   	  (xctx->inst[i].ptr+ xctx->sym)->minx,
   	  (xctx->inst[i].ptr+ xctx->sym)->miny,
   	  (xctx->inst[i].ptr+ xctx->sym)->maxx,
   	  (xctx->inst[i].ptr+ xctx->sym)->maxy);
        Tcl_AppendResult(interp, s, NULL);
      }
    }

    /* instance_id inst
     *   return the session-stable id of the given instance ('inst' is an
     *   instance name or array index, resolved via get_instance), or -1 if it
     *   does not resolve. Ids are stamped at instance creation (store.c
     *   inst_register), never reused within a window/tab session and not
     *   persisted in .sch files. Resolve back with `xschem instance_index id`.
     *   The id is the durable machine handle; the name is the human /
     *   cross-session form (reusable, renamable) — see
     *   doc/claude/code_analysis/instance_identity_decision.md */
    else if(!strcmp(argv[1], "instance_id"))
    {
      int i;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        i = get_instance(argv[2]);
        if(i >= 0) {
          char s[30];
          my_snprintf(s, S(s), "%u", xctx->inst[i].id);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        } else {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        }
      }
    }
    /* instance_index id
     *   return the current array index of the instance whose session-stable id
     *   (see `xschem instance_id`) is given, or -1 if no live instance carries
     *   that id (deleted, or invalidated by a disk-undo restore) */
    else if(!strcmp(argv[1], "instance_index"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        unsigned int id = (unsigned int)strtoul(argv[2], NULL, 10);
        Tcl_SetResult(interp, my_itoa(inst_index_from_id(id)), TCL_VOLATILE);
      }
    }

    /* instance_coord [instance]
     *   Return instance name, symbol name, x placement coord, y placement coord, rotation and flip
     *   of selected instances
     *   if 'instance' is given (instance name or number) return data about specified instance
     *   Example:
     *     xschem [~] xschem instance_coord
     *     {R5} {res.sym} 260 260 0 0
     *     {C1} {capa.sym} 150 150 1 1 */
    else if(!strcmp(argv[1], "instance_coord"))
    {
      xSymbol *symbol;
      short flip, rot;
      double x0,y0;
      int n, i = 0;
      int user_inst = -1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        i = get_instance(argv[2]);
        if(i < 0) {
          Tcl_SetResult(interp, "xschem instance_net: instance not found", TCL_STATIC);
          return TCL_ERROR;
        }
        user_inst = i;
      }

      rebuild_selected_array();
      for(n=0; user_inst >=0 || n < xctx->lastsel; ++n) {
        if(user_inst >=0 || xctx->sel_array[n].type == ELEMENT) {
          char srot[16], sflip[16], sx0[70], sy0[70];
          if(user_inst == -1) i = xctx->sel_array[n].n;
          else i = user_inst;
          x0 = xctx->inst[i].x0;
          y0 = xctx->inst[i].y0;
          rot = xctx->inst[i].rot;
          flip = xctx->inst[i].flip;
          symbol = xctx->sym + xctx->inst[i].ptr;
          my_snprintf(srot, S(srot), "%d", rot);
          my_snprintf(sflip, S(sflip), "%d", flip);
          my_snprintf(sx0, S(sx0), "%g", x0);
          my_snprintf(sy0, S(sy0), "%g", y0);
          Tcl_AppendResult(interp, "{", xctx->inst[i].instname, "} ", "{", symbol->name, "} ",
             sx0, " ", sy0, " ", srot, " ", sflip, "\n", NULL);
          if(user_inst >= 0) break;
        }
      }
    }

    /* instance_list
     *   Return a list of 3-items. Each 3-item is
     *   an instance name followed by the symbol reference and symbol type.
     *   Example: xschem instance_list -->
     *     {x1}  {sky130_tests/bandgap.sym} {subcircuit}
     *     {...} {...}                      {...}
     *     ...
     */
    else if(!strcmp(argv[1], "instance_list"))
    {
      int i;
      char *s = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 0; i < xctx->instances; ++i) {
        const char *name = xctx->inst[i].name ? xctx->inst[i].name : "";
        char *instname = xctx->inst[i].instname ? xctx->inst[i].instname : "";
        char *type = (xctx->inst[i].ptr + xctx->sym)->type;
        type = type ? type : "";
        if(i > 0) my_mstrcat(_ALLOC_ID_, &s, "\n", NULL);
        my_mstrcat(_ALLOC_ID_, &s,  "{", instname, "} {", name, "} {", type, "}", NULL);
      }
      Tcl_SetResult(interp, (char *)s, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &s);
    }
    /* instance_net inst pin
     *   Return the name of the net attached to pin 'pin' of instance 'inst'
     *   Example: xschem instance_net x3 MINUS --> REF */
    else if(!strcmp(argv[1], "instance_net"))
    {
      /* xschem instance_net inst pin */
      int no_of_pins, i, p, multip;
      const char *str_ptr=NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 4) {
        Tcl_SetResult(interp, "xschem instance_net needs 2 additional arguments", TCL_STATIC);
        return TCL_ERROR;
      }
      if((i = get_instance(argv[2])) < 0 ) {
        Tcl_SetResult(interp, "xschem instance_net: instance not found", TCL_STATIC);
        return TCL_ERROR;
      }
      prepare_netlist_structs(0);
      no_of_pins= (xctx->inst[i].ptr+ xctx->sym)->rects[PINLAYER];
      for(p=0;p<no_of_pins;p++) {
        if(!strcmp(get_tok_value(xctx->sym[xctx->inst[i].ptr].rect[PINLAYER][p].prop_ptr, "name",0), argv[3])) {
          str_ptr =  net_name(i,p, &multip, 0, 1);
          break;
        }
      } /* /20171029 */
      if(p>=no_of_pins) {
        Tcl_SetResult(interp, "Pin not found", TCL_STATIC);
        return TCL_ERROR;
      }
      Tcl_SetResult(interp, (char *)str_ptr, TCL_VOLATILE);
    }

    /* instance_nodemap inst [pin]
     *   Return the instance name followed by a list of 'pin net' associations
     *   example:  xschem instance_nodemap x3
     *   --> x3 PLUS LED OUT LEVEL MINUS REF
     *   instance x3 pin PLUS is attached to net LED, pin OUT to net LEVEL and so on...
     *   If 'pin' is given restrict map to only that pin */
    else if(!strcmp(argv[1], "instance_nodemap"))
    {
    /* xschem instance_nodemap [instance_name] */
      int p, no_of_pins;
      int inst = -1, first=1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      prepare_netlist_structs(0);
      if(argc > 2) {
        inst = get_instance(argv[2]);
        if(inst >=0) {
          Tcl_AppendResult(interp,  xctx->inst[inst].instname, " ",  NULL);
          no_of_pins= (xctx->inst[inst].ptr+ xctx->sym)->rects[PINLAYER];
          for(p=0;p<no_of_pins;p++) {
            const char *pin;
            pin = get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][p].prop_ptr, "name",0);
            if(!pin[0]) pin = "--ERROR--";
            if(argc > 3 && strcmp(argv[3], pin)) continue;
            if(first == 0) Tcl_AppendResult(interp, " ", NULL);
            Tcl_AppendResult(interp, pin, " ",
                  xctx->inst[inst].node && xctx->inst[inst].node[p] ? xctx->inst[inst].node[p] : "{}", NULL);
            first = 0;
          }
        }
      }
    }

    /* instance_number inst [n]
     *   QUERY form (argc == 3): return the array position of instance 'inst'.
     *   MUTATE form (argc  > 3): set instance 'inst' to array position 'n'.
     *
     *   Refactor B atom 23 (audit §43): a QUERY/MUTATE SPLIT (the image §40 template applied
     *   to a query vs a mutation). ONLY the MUTATE form crosses the perform_action boundary --
     *   the argc>3 tail delegates for the boundary's ONE readonly gate + the ONE self-logged
     *   `xschem instance_number <inst> <n>` line. The read-only-SAFE QUERY form (argc==3) stays
     *   RAW IN FRONT of the boundary: routing it through perform_action would (a) let the
     *   boundary's unconditional readonly gate OVER-REJECT a pure position read-back on a
     *   read-only cell, and (b) let its success-path Tcl_ResetResult WIPE the position result
     *   that callers consume (`idx` in the tests, the z-order read-back). NOTE this verb owns
     *   NO push_undo/set_modify -- the shared change_elem_order() core (editprop.c) brackets the
     *   mutate (it calls push_undo() on the mutate path + set_modify(1), the latter gated on its
     *   local `modified`); and that raw change_elem_order() sub-step stays SILENT below the
     *   boundary (the atom-11 shared-sub-step
     *   lock -- it logs nothing, the `instance_number` verb logs its own line). No scattered
     *   readonly/log/push_undo remains here. */
    else if(!strcmp(argv[1], "instance_number"))
    {
      int i;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem instance_number 1 additional argument", TCL_STATIC);
        return TCL_ERROR;
      }
      if((i = get_instance(argv[2])) < 0 ) {
        Tcl_SetResult(interp, "xschem instance_number: instance not found", TCL_STATIC);
        return TCL_ERROR;
      }
      /* MUTATE form: route through the boundary (readonly gate + self-log). */
      if(argc > 3) return perform_action("instance_number", argc, argv);
      /* QUERY form (argc == 3): read-only-safe array-position read-back, kept RAW in front. */
      Tcl_SetResult(interp, my_itoa(i), TCL_VOLATILE);
    }

    /* instance_pin_coord inst attr value
     *   Return the name and coordinates of pin with
     *   attribute 'attr' set to 'value' of instance 'inst'
     *   'inst can be an instance name or a number
     *   Example: xschem instance_pin_coord x3 name MINUS --> {MINUS} 600 -840 */
    else if(!strcmp(argv[1], "instance_pin_coord"))
    {
    /*   0            1           2       3     4
     * xschem instance_pin_coord m12  pinnumber 2
     * xschem instance_pin_coord U3:2 pinnumber 5
     * xschem instance_pin_coord m12 name d
     * returns pin_name x y */
      xSymbol *symbol;
      xRect *rct;
      double pinx0, piny0;
      char num[60];
      int p, i, no_of_pins, slot;
      const char *pin;
      char *ss;
      char *tmpstr = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 5) {
        Tcl_SetResult(interp,
          "xschem instance_pin_coord requires an instance, a pin attribute and a value", TCL_STATIC);
        return TCL_ERROR;
      }
      i = get_instance(argv[2]);
      if(i < 0) {
        Tcl_SetResult(interp, "", TCL_STATIC);
        return TCL_OK;
      }
      symbol = xctx->sym + xctx->inst[i].ptr;
      no_of_pins= symbol->rects[PINLAYER];
      rct=symbol->rect[PINLAYER];
      /* slotted devices: name= U1:2, pinnumber=2:5 */
      slot = -1;
      tmpstr = my_malloc(_ALLOC_ID_, sizeof(xctx->inst[i].instname));
      if((ss=strchr(xctx->inst[i].instname, ':')) ) {
        sscanf(ss+1, "%s", tmpstr);
        if(isonlydigit(tmpstr)) {
          slot = atoi(tmpstr);
        }
      }
      for(p = 0;p < no_of_pins; p++) {
        pin = get_tok_value(rct[p].prop_ptr,argv[3],0);
        if(slot > 0 && !strcmp(argv[3], "pinnumber") && strstr(pin, ":")) pin = find_nth(pin, ":", "", 0, slot);
        if(!strcmp(pin, argv[4])) break;
      }
      if(p >= no_of_pins) {
        Tcl_SetResult(interp, "", TCL_STATIC);
        return TCL_OK;
      }
      get_inst_pin_coord(i, p, &pinx0, &piny0);
      my_snprintf(num, S(num), "{%s} %g %g", get_tok_value(rct[p].prop_ptr, "name", 0), pinx0, piny0);
      Tcl_SetResult(interp, num, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &tmpstr);
    }

    /* instance_pins inst
     *   Return list of pins of instance 'inst'
     *   'inst can be an instance name or a number */
    else if(!strcmp(argv[1], "instance_pins"))
    {
      char *pins = NULL;
      int p, i, no_of_pins;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        prepare_netlist_structs(0);
        if((i = get_instance(argv[2])) < 0 ) {
          Tcl_SetResult(interp, "xschem instance_pins: instance not found", TCL_STATIC);
          return TCL_ERROR;
        }
        no_of_pins= (xctx->inst[i].ptr+ xctx->sym)->rects[PINLAYER];
        for(p=0;p<no_of_pins;p++) {
          const char *pin;
          pin = get_tok_value(xctx->sym[xctx->inst[i].ptr].rect[PINLAYER][p].prop_ptr, "name",0);
          if(!pin[0]) pin = "--ERROR--";
          my_mstrcat(_ALLOC_ID_, &pins, "{", pin, "}", NULL);
          if(p< no_of_pins-1) my_strcat(_ALLOC_ID_, &pins, " ");
        }
        Tcl_SetResult(interp, pins, TCL_VOLATILE);
        my_free(_ALLOC_ID_, &pins);
      }
    }

    /* instance_pos inst
     *   Get number (position) of instance name 'inst' */
    else if(!strcmp(argv[1], "instance_pos"))
    {
      int i;
      char s[30];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        i = get_instance(argv[2]);
        my_snprintf(s, S(s), "%d", i);
        Tcl_SetResult(interp, s, TCL_VOLATILE);
      }
    }

    /* instances_to_net net
     *   Return list of instances names and pins attached to net 'net'
     *   Example: xschem instances_to_net PANEL
     *    --> { {Vsw} {plus} {580} {-560} } { {p2} {p} {660} {-440} }
     *        { {Vpanel1} {minus} {600} {-440} } */
    else if(!strcmp(argv[1], "instances_to_net"))
    {
      xSymbol *symbol;
      xRect *rct;
      double pinx0, piny0;
      char *pins = NULL;
      int p, i, no_of_pins;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      prepare_netlist_structs(0);
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem instances_to_net requires a net name argument", TCL_STATIC);
        return TCL_ERROR;
      }
      for(i = 0;i < xctx->instances; ++i) {
        symbol = xctx->sym + xctx->inst[i].ptr;
        no_of_pins= symbol->rects[PINLAYER];
        rct=symbol->rect[PINLAYER];
        for(p = 0;p < no_of_pins; p++) {
          const char *pin;
          char xx[70], yy[70];
          pin = get_tok_value(rct[p].prop_ptr, "name",0);
          if(!pin[0]) pin = "--ERROR--";
          if(xctx->inst[i].node[p] && !strcmp(xctx->inst[i].node[p], argv[2]) &&
             !IS_LABEL_SH_OR_PIN( (xctx->inst[i].ptr+xctx->sym)->type )) {
            my_mstrcat(_ALLOC_ID_, &pins, "{ {", xctx->inst[i].instname, "} {", pin, NULL);
            get_inst_pin_coord(i, p, &pinx0, &piny0);
            my_strncpy(xx, dtoa(pinx0), S(xx));
            my_strncpy(yy, dtoa(piny0), S(yy));
            my_mstrcat(_ALLOC_ID_, &pins, "} {", xx, "} {", yy, "} } ", NULL);
          }
        }
      }
      Tcl_SetResult(interp, pins ? pins : "", TCL_VOLATILE);
      my_free(_ALLOC_ID_, &pins);
    }

    /* is_generator symbol
     *   tell if 'symbol' is a generator (symbol(param1,param2,...) */
    else if(!strcmp(argv[1], "is_generator"))
    {
      char s[30];
      if(argc > 2) {
        my_snprintf(s, S(s), "%d", is_generator(argv[2]));
        Tcl_SetResult(interp, s, TCL_VOLATILE);
      }
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* Match the conventional scratch-buffer name produced by clear_schematic:
 * "untitled.sch" / "untitled-<n>.sch" (and the .sym variants). Compared on the
 * BASENAME, not strstr of the whole path, so a real file under a directory whose
 * name merely contains "untitled" is not mistaken for a scratch buffer (issue 0023). */
static int is_untitled_basename(const char *path)
{
  const char *base, *p;
  if(!path) return 0;
  base = strrchr(path, '/');
  base = base ? base + 1 : path;
  if(strncmp(base, "untitled", 8)) return 0;
  p = base + 8;
  if(*p == '-') {                       /* untitled-<n> */
    p++;
    if(*p < '0' || *p > '9') return 0;
    while(*p >= '0' && *p <= '9') p++;
  }
  return (!strcmp(p, ".sch") || !strcmp(p, ".sym"));
}

/* True if the current window holds a pristine, reusable "untitled" scratch buffer:
 * top level, never modified, empty (no instances/wires), and the conventional
 * untitled name (or none). Editor behavior (NEdit/Notepad++): the launch placeholder
 * is consumed by the first file opened, so untitled.sch never sits alongside a real
 * file. A scratch buffer the user has actually drawn in is `modified`, so it is NOT
 * reused (their work is preserved; the open goes to a new window/tab instead). */
static int is_pristine_untitled(void)
{
  int i;
  if(!xctx) return 0;
  /* issue 0172: a waveform-viewer window is NEVER a reuse target. It is a schematic
   * buffer by construction -- top level, named untitled, no instances, no wires -- and
   * wviewer::with_edit (contract D1) ends every mutation with `xschem set_modify 0`, so
   * `modified` is 0 for the buffer's whole life: a viewer never ages out of "pristine"
   * the way a scratch buffer does the moment the user draws in it. A real schematic was
   * therefore loaded INTO a live viewer, destroying its graph rects and leaving the
   * document under the viewer's bindtag and menubar, where Ctrl-D (wviewer::clear_all)
   * wipes it. The test lives HERE, in the shared predicate, rather than in the three
   * callers (the `xschem load -gui` routing, `load_new_window <file>`, and
   * `load_new_window` via the file dialog) so all three doors close at once and the
   * next caller cannot reintroduce the hijack. */
  /* Every refusal names itself at dbg level 1: "why did opening a file give me a new
   * window instead of reusing my blank one?" must be one `xschem -d 1` away, not an
   * afternoon of git log. Level 1 costs nothing in normal use (dbg() returns
   * immediately when debug_var < level). */
  if(xctx->wave_viewer) {
    dbg(1, "is_pristine_untitled(): NO -- this window is a waveform viewer\n");
    return 0;
  }
  if(xctx->currsch != 0) {
    dbg(1, "is_pristine_untitled(): NO -- not top level (currsch=%d)\n", xctx->currsch);
    return 0;
  }
  if(xctx->modified) {
    dbg(1, "is_pristine_untitled(): NO -- buffer is modified\n");
    return 0;
  }
  if(xctx->instances != 0 || xctx->wires != 0) {
    dbg(1, "is_pristine_untitled(): NO -- buffer has content (instances=%d wires=%d)\n",
        xctx->instances, xctx->wires);
    return 0;
  }
  /* ...and "pristine" means the buffer is actually EMPTY, not merely free of instances
   * and wires (issue 0172). Drawing normally sets `modified`, which is what used to
   * make the rest of the object arrays redundant -- but any path that clears it (the
   * viewer's D1 contract; a script calling `xschem set_modify 0`) then handed a buffer
   * with content in it to the next open, silently. rects/lines/polygons/arcs are
   * per-layer counters, so this is a per-layer scan; a freshly created untitled buffer
   * is 0 in every one of them (measured, startup and after `xschem clear force`). */
  if(xctx->texts != 0) {
    dbg(1, "is_pristine_untitled(): NO -- buffer has %d text object(s)\n", xctx->texts);
    return 0;
  }
  for(i = 0; i < cadlayers; i++) {
    if(xctx->rects && xctx->rects[i]) {
      dbg(1, "is_pristine_untitled(): NO -- %d rect(s) on layer %d\n", xctx->rects[i], i);
      return 0;
    }
    if(xctx->lines && xctx->lines[i]) {
      dbg(1, "is_pristine_untitled(): NO -- %d line(s) on layer %d\n", xctx->lines[i], i);
      return 0;
    }
    if(xctx->polygons && xctx->polygons[i]) {
      dbg(1, "is_pristine_untitled(): NO -- %d polygon(s) on layer %d\n", xctx->polygons[i], i);
      return 0;
    }
    if(xctx->arcs && xctx->arcs[i]) {
      dbg(1, "is_pristine_untitled(): NO -- %d arc(s) on layer %d\n", xctx->arcs[i], i);
      return 0;
    }
  }
  if(!xctx->sch[xctx->currsch]) {           /* NULL-safe (issue 0023) */
    dbg(1, "is_pristine_untitled(): NO -- no schematic name\n");
    return 0;
  }
  {
    int pristine = (xctx->sch[xctx->currsch][0] == '\0' ||
                    is_untitled_basename(xctx->sch[xctx->currsch]));
    dbg(1, "is_pristine_untitled(): %s -- empty buffer named \"%s\"%s\n",
        pristine ? "YES" : "NO", xctx->sch[xctx->currsch],
        pristine ? " (reused in place)" : " (not an untitled basename)");
    return pristine;
  }
}

/* `xschem l...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_l(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* line [x1 y1 x2 y2] [pos] [propstring] [draw]
     * line
     * line gui
     *   if 'x1 y1 x2 y2'is given place line on current
     *   layer (rectcolor) at indicated coordinates.
     *   if 'pos' is given insert at given position in line array.
     *   if 'pos' set to -1 append to last element in line array.
     *   'propstring' is the attribute string. Set to empty if not given.
     *   if 'draw' is set to 1 (default) draw the new object, else don't
     *   If no coordinates are given start a GUI operation of line placement
     *   if `gui` argument is given start a line GUI placement with 1st point
     *   set to current mouse coordinates */
    if(!strcmp(argv[1], "line"))
    {
      double x1,y1,x2,y2;
      int pos, save;
      int draw = 1;
      const char *prop_str = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "line")) return TCL_ERROR;
      if(argc > 5) {
        x1=atof(argv[2]);
        y1=atof(argv[3]);
        x2=atof(argv[4]);
        y2=atof(argv[5]);
        ORDER(x1,y1,x2,y2);
        pos=-1;
        if(argc > 6) pos=atoi(argv[6]);
        if(argc > 7) prop_str = argv[7];
        if(argc > 8) draw = atoi(argv[8]);
        xctx->push_undo(); /* issue 0127: checkpoint like interactive new_line + the wire coord arm */
        storeobject(pos, x1,y1,x2,y2,LINE,xctx->rectcolor,0,prop_str);
        if(draw) {
          save = xctx->draw_window; xctx->draw_window = 1;
          drawline(xctx->rectcolor,NOW, x1,y1,x2,y2, 0.0, 0, NULL);
          xctx->draw_window = save;
        }
        set_modify(1);
      }
      else if(argc == 3 && !strcmp(argv[2], "gui")) {
        int prev_state = xctx->ui_state;
        int infix_interface = tclgetboolvar("infix_interface");
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
      else {
        xctx->last_command = 0;
        xctx->ui_state |= MENUSTART;
        xctx->ui_state2 = MENUSTARTLINE;
      }
    }

    /* line_id layer index
     *   session-stable id of the line at (layer, index), or -1 if out of range.
     *   Shared graphical id space; resolve back with `xschem line_index id` */
    else if(!strcmp(argv[1], "line_id"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
        int c = atoi(argv[2]), n = atoi(argv[3]);
        if(c >= 0 && c < cadlayers && n >= 0 && n < xctx->lines[c]) {
          char s[30];
          my_snprintf(s, S(s), "%u", xctx->line[c][n].id);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        } else {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        }
      }
    }
    /* line_index id
     *   current "{layer index}" of the line with that id, or -1 if none */
    else if(!strcmp(argv[1], "line_index"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        unsigned int id = (unsigned int)strtoul(argv[2], NULL, 10);
        int layer, idx = gfx_index_from_id(LINE, id, &layer);
        if(idx < 0) {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        } else {
          char s[40];
          my_snprintf(s, S(s), "%d %d", layer, idx);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        }
      }
    }
    /* line_width n
     *   set line width to floating point number 'n' */
    else if(!strcmp(argv[1], "line_width"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        double w;
        w = atof(argv[2]);
        change_linewidth(w);
        tclsetdoublevar("line_width", w);
        Tcl_ResetResult(interp);
      }
    }

    /* list_hierarchy
     *   List all schematics at or below current hierarchy with modification times.
     *   Example: xschem list_hiearchy
     *   -->
     *   20230302_003134  {/home/.../ngspice/solar_panel.sch}
     *   20230211_010031  {/home/.../ngspice/pv_ngspice.sch}
     *   20221011_175308  {/home/.../ngspice/diode_ngspice.sch}
     *   20221014_091945  {/home/.../ngspice/comp_ngspice.sch}
     */
    else if(!strcmp(argv[1], "list_hierarchy"))
    {
      char *res = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      Tcl_ResetResult(interp);
      hier_psprint(&res, 2);
      Tcl_SetResult(interp, res, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &res);
    }

    /* list_hilights [sep | all | all_nets | all_inst]
     *    Sorted list of non port or non top level current level highlight nets,
     *    separated by character 'sep' (default: space)
     *    if `all_inst` is given list all instance hilights
     *    if `all_nets` is given list all net hilights
     *    if `all` is given list all hash content */
    else if(!strcmp(argv[1], "list_hilights"))
    {
      const char *sep = "{ }";
      int i, all = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 2; i < argc; i++) {
        if(!strcmp(argv[i], "all")) all = 3;
        else if(!strcmp(argv[i], "all_inst")) all = 2;
        else if(!strcmp(argv[i], "all_nets")) all = 1;
        else sep = argv[i];
      }
      list_hilights(all);
      if(!all) tclvareval("join [lsort -decreasing -dictionary {", tclresult(), "}] ", sep, NULL);
    }

    /* list_nets
     *    List all nets with type (in / out / inout / net) */
    else if(!strcmp(argv[1], "list_nets"))
    {
      char *result = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      list_nets(&result);
      Tcl_SetResult(interp, result, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &result);
    }

    /* list_tokens str with_quotes
     *   List tokens in string 'str'
     *   with_quotes:
     *   0: eat non escaped quotes (")
     *   1: return unescaped quotes as part of the token value if they are present
     *   2: eat backslashes */
    else if(!strcmp(argv[1], "list_tokens"))
    {
      if(argc > 3) {
        Tcl_ResetResult(interp);
        Tcl_SetResult(interp, (char *)list_tokens(argv[2], atoi(argv[3])), TCL_VOLATILE);
      }
    }

    /* load [-nosymbols|-gui|-noundoreset|-nofullzoom|-keep_symbols] f
     *   Load a new file 'f'.
     *   '-gui': ask to save modified file or warn if opening an already
     *       open file or opening a new(not existing) file.
     *   '-noundoreset': do not reset the undo history
     *   '-lastclosed': open last closed file
     *   '-lastopened': open last opened file
     *   '-nosymbols': do not load symbols (used if loading a symbol instead of
     *       a schematic)
     *   '-nofullzoom': do not do a full zoom on new schematic.
     *   '-nodraw': do not draw.
     *   '-keep_symbols': retain symbols that are already loaded.
     *   '-readonly': open the loaded file in read mode (read-only) regardless of its writability
     *       -- used by the reopen shortcuts (Open Most Recent / Last Closed / Recent menu) so
     *       reopening defaults to a safe browse view; edit with Ctrl-2 / View > Toggle Read Only.
     */
    else if(!strcmp(argv[1], "load") )
    {
      int load_symbols = 1, force = 1, undo_reset = 1, nofullzoom = 0, nodraw = 0;
      int keep_symbols = 0, first, readonly_open = 0;
      int lastclosed = 0, lastopened = 0;
      int first_loaded = 0;
      int inplace = 0;              /* -inplace: force legacy in-place load (opt out of routing) */
      const char *target_win = NULL; /* -window <winpath>: reuse a specific existing window */
      int i;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}

      for(i = 2; i < argc; i++) {
        if(argv[i][0] == '-') {
          if(!strcmp(argv[i], "-nosymbols")) {
            load_symbols = 0 ;
          } else if(!strcmp(argv[i], "-gui")) {
            force = 0;
          } else if(!strcmp(argv[i], "-lastclosed")) {
            lastclosed = 1;
          } else if(!strcmp(argv[i], "-lastopened")) {
            lastopened = 1;
          } else if(!strcmp(argv[i], "-noundoreset")) {
            undo_reset = 0;
          } else if(!strcmp(argv[i], "-nofullzoom")) {
            nofullzoom = 1;
          } else if(!strcmp(argv[i], "-nodraw")) {
            nofullzoom = 1; nodraw = 1;
          } else if(!strcmp(argv[i], "-keep_symbols")) {
            keep_symbols = 1;
          } else if(!strcmp(argv[i], "-readonly")) {
            readonly_open = 1;
          } else if(!strcmp(argv[i], "-inplace")) {
            inplace = 1;
          } else if(!strcmp(argv[i], "-window")) {
            /* -window <winpath>: consume the next arg as the target window path
             * (a .drw / .x1.drw Tk path, not a filename) */
            if(i + 1 < argc) target_win = argv[++i];
          }
        } else {
          break;
        }
      }
      first = i;
      /* -lastopened/-lastclosed come ONLY from the reopen shortcuts (Open Most Recent Ctrl+Shift+O /
       * Open Last Closed Ctrl+Shift+T / the Recent menu), which default to read mode. Treat them as
       * -readonly so EVERY dispatch site gets it -- the keyboard handlers (callback.c case 'O'/'T')
       * run `xschem load -gui -lastopened` directly, bypassing the actions.csv command, so threading
       * the flag only through the menu rows is not enough. Edit with Ctrl-2 / View > Toggle Read Only. */
      if(lastclosed || lastopened) readonly_open = 1;
      if(argc==first && !(lastclosed || lastopened)) {
        if(tclgetboolvar("new_file_browser")) {
          tcleval("file_chooser");
        } else {
          ask_new_file(0, NULL);
          tcleval("load_additional_files");
        }
      } else {
      /* Window routing (doc/claude/specs/load_window_routing.md): a user-facing
       * open must not clobber an occupied editor window. Scripted / internal
       * in-place loads always carry a hint flag (-nodraw / -nofullzoom /
       * -keep_symbols / -noundoreset / -nosymbols / -inplace) and are exempt. */
      int inplace_hint = inplace || !load_symbols || nodraw || nofullzoom ||
                         keep_symbols || !undo_reset;
      int route_newwin = 0;
      int target_done = 0;

      if(has_x && target_win && target_win[0]) {
        /* -window <winpath>: reuse the named existing window. Switch to it and,
         * if its cellview is modified, pop "Save changes?" (ask_save). Cancel
         * aborts the load and leaves the target untouched. */
        int n = get_tab_or_window_number(target_win);
        char *tgt_path = (n >= 0) ? get_window_path(n) : NULL;
        Xschem_ctx *tctx = (n >= 0) ? get_window_ctx(n, NULL) : NULL;
        char orig_win[WINDOW_PATH_SIZE];
        orig_win[0] = '\0';
        if(xctx->current_win_path) my_strncpy(orig_win, xctx->current_win_path, S(orig_win));
        if(!tctx || !tgt_path || !tgt_path[0]) {
          Tcl_SetResult(interp, "xschem load -window: no such window", TCL_STATIC);
          return TCL_ERROR;
        }
        if(orig_win[0] && strcmp(tgt_path, orig_win)) {
          new_schematic("switch", tgt_path, "", 0);
        }
        if(xctx->modified && save(1, 0) == -1) { /* user clicked Cancel: abort, restore focus */
          if(orig_win[0] && strcmp(tgt_path, orig_win)) new_schematic("switch", orig_win, "", 0);
          Tcl_ResetResult(interp);
          return TCL_OK;
        }
        target_done = 1; /* save prompt already handled; don't re-prompt below */
      } else {
        /* Route only INTERACTIVE opens (-gui, so force==0): the File>Open / recent /
         * Library-Manager paths. Bare `xschem load <f>` (force==1) and scripted loads
         * stay in place -- the whole regression suite drives repeated bare loads into
         * one window and relies on that. A -gui open reuses the current window only
         * when it is a pristine empty untitled scratch; otherwise it opens a new one. */
        route_newwin = has_x && !force && !inplace_hint && !is_pristine_untitled();
        /* preset first_loaded so the FIRST file opens via new_schematic (a new
         * window/tab), exactly like the 2nd..Nth file already does today, instead
         * of loading in place over the occupied current window */
        if(route_newwin) first_loaded = 1;
      }

      for(i = first; i < argc || lastclosed || lastopened; i++) {
        char f[PATH_MAX + 100];

        if(lastclosed) {
          my_strncpy(f, tcleval("get_lastclosed"), S(f));
          i--;
          lastclosed = 0;
        } else if(lastopened) {
          my_strncpy(f, tcleval("get_lastopened"), S(f));
          i--;
          lastopened = 0;
        } else {
          my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[i], home_dir);
          tcleval(f);
          my_strncpy(f, tclresult(), S(f));
        }
        /* route_newwin: not clobbering the current window, so never prompt to save it.
         * target_done: the -window target's save prompt was already handled above. */
        if(route_newwin || target_done || force || !has_x || !xctx->modified  ||
           save(1, 0) != -1 ) { /* save(1)==-1 --> user cancel */
          char win_path[WINDOW_PATH_SIZE];
          int skip = 0;
          if(has_x) tcleval("store_geom [xschem get topwindow] [xschem get current_name]");
          dbg(1, "scheduler(): load: filename=%s\n", f);
          my_strncpy(f,  abs_sym_path(f, ""), S(f));
          /* interactive open (-gui) of a file load_schematic() can't open: alert and skip,
           * rather than letting it rename the current (e.g. pristine untitled) buffer to a
           * missing/unreadable path -- that strands the buffer and cascades into broken
           * untitled-reuse and window-close. Probe with the same my_fopen() test
           * load_schematic() uses (covers missing AND unreadable, every path form). Generators
           * (run via popen) and web urls are not local files and are exempt. Scripted loads
           * (no -gui) keep the legacy create-on-missing behavior. */
          if(!force && f[0] && !is_generator(f) && !is_from_web(f)) {
            FILE *probe = my_fopen(f, fopen_read_mode);
            if(probe) fclose(probe);
            else {
              if(has_x) tclvareval("alert_ {Unable to open file: ", f, "}", NULL);
              else dbg(0, "xschem load -gui: unable to open file: %s\n", f);
              skip = 1;
            }
          }
          if(!force && !skip && f[0] && check_loaded(f, win_path) &&
              xctx->current_win_path && strcmp(win_path, xctx->current_win_path)) {
            char msg[PATH_MAX + 100];
            my_snprintf(msg, S(msg),
               "tk_messageBox -type okcancel -icon warning -parent [xschem get topwindow] "
               "-message {Warning: %s already open.}", f);
            if(has_x) {
              tcleval(msg);
              if(strcmp(tclresult(), "ok")) skip = 1;
            }
            else dbg(0, "xschem load: %s already open: %s\n", f, win_path);
          }
          if(!skip) {
            int ret;
            /* when routing to a new window the current window is left as-is;
             * its hilights/selection must not be touched */
            if(!route_newwin) {
              clear_all_hilights();
              unselect_all(1);
            }
            /* no implicit undo: if needed do it before loading */
            /* if(!undo_reset) xctx->push_undo(); */
            if(!first_loaded) {
              if(undo_reset) xctx->currsch = 0;
              if(!keep_symbols) remove_symbols();
              if(!nofullzoom) {
                xctx->zoom=CADINITIALZOOM;
                xctx->mooz=1/CADINITIALZOOM;
                xctx->xorigin=CADINITIALX;
                xctx->yorigin=CADINITIALY;
              }
            }
            dbg(1, "scheduler: undo_reset=%d\n", undo_reset);

            if(first_loaded) {
              int dr = nofullzoom * 2 + !nodraw;
              ret = new_schematic("create", "noconfirm", f, dr);
              if(undo_reset) {
                tclvareval("update_recent_file {", f, "}", NULL);
              }
            } else {
              first_loaded = 1;
              ret = load_schematic(load_symbols, f, undo_reset, !force);
              /* action-log (file-menu plan): -gui marks the interactive menu
               * invocations (recent / last-closed / most-recent / context
               * menu / file_chooser) whose filename resolves here. Replay
               * lines never carry -gui, so replays don't re-log. */
              if(!force && has_x && tcl_braceable(f)) log_action("xschem load {%s}", f);
              dbg(1, "xschem load: f=%s, ret=%d\n", f, ret);
              if(undo_reset) {
                tclvareval("update_recent_file {", f, "}", NULL);
                my_strdup(_ALLOC_ID_, &xctx->sch_path[xctx->currsch], ".");
                if(xctx->portmap[xctx->currsch].table) str_hash_free(&xctx->portmap[xctx->currsch]);
                str_hash_init(&xctx->portmap[xctx->currsch], HASHSIZE);
                xctx->sch_path_hash[xctx->currsch] = 0;
                xctx->sch_inst_number[xctx->currsch] = 1;
              }
              if(nofullzoom) {
                if(!nodraw) draw();
              } else zoom_full(1, 0, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
              /* Crash recovery: an interactive open (-gui) of a cell that still has a
               * cellName~.sch autosave backup means the previous session ended without
               * saving (a clean discard/save removes the ~). Offer to restore it. Only
               * in GUI + interactive mode -- never on scripted/replay loads or headless.
               * doc/claude/specs/descend_hierarchy_in_memory.md (B8) */
              if(!force && has_x) {
                tclvareval("xschem_recover_backup {", xctx->sch[xctx->currsch], "}", NULL);
              }
            }
          }
        }
      } /* for(i = first ...) */
      } /* else (routing branch) */
      /* -readonly (reopen shortcuts: Open Most Recent / Last Closed / Recent menu): force the freshly
       * loaded buffer into read mode regardless of file writability, so reopening defaults to a safe
       * browse view. Edit it with Ctrl-2 / View > Toggle Read Only (mirrors descend_readonly). */
      if(readonly_open && first_loaded && !xctx->readonly) {
        xctx->readonly = 1;
        set_modify(-1); /* refresh window title to show the read-only marker */
      }
      Tcl_SetResult(interp, xctx->sch[xctx->currsch], TCL_STATIC);
    }

    /* load_backup <cellfile> [notitle]
     *   Load <cellfile>'s "~" autosave backup as the current buffer's content while
     *   keeping the buffer's logical identity = <cellfile> (flagged modified). Used
     *   by crash recovery on open (xschem_recover_backup). Returns 1 if a backup
     *   existed and was loaded, 0 otherwise. */
    else if(!strcmp(argv[1], "load_backup"))
    {
      int ret = 0, set_title = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem load_backup needs a cell filename", TCL_STATIC);
        return TCL_ERROR;
      }
      if(argc > 3) set_title = atoi(argv[3]);
      ret = load_backup_as(argv[2], set_title);
      if(ret) draw();
      Tcl_SetResult(interp, dtoa(ret), TCL_VOLATILE);
    }

    /* load_new_window [-lastclosed | -lastopened] [f]
     *   Load schematic in a new tab/window. If 'f' not given prompt user
     *   -lastclosed or -lastopened can be used to open the last closed or last opened file
     *   if 'f' is given as empty '{}' then open untitled.sch */
    else if(!strcmp(argv[1], "load_new_window") )
    {
      char f[PATH_MAX + 100];
      int cancel = 0;
      int reopen = 0; /* -lastopened/-lastclosed: a reopen shortcut, open the new window read-only */
      int force_window = 0; /* -window: open a real top-level even in tabbed mode */
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        int i;
        for(i = 2; i < argc; i++) {

          if(!strcmp(argv[i], "-window")) {
            force_window = 1;
            continue;
          } else if(!strcmp(argv[i], "-lastclosed")) {
            my_strncpy(f, tcleval("get_lastclosed"), S(f));
            reopen = 1;
          } else if(!strcmp(argv[i], "-lastopened")) {
            my_strncpy(f, tcleval("get_lastopened"), S(f));
            reopen = 1;
          } else if(!is_from_web(argv[i])) {
            my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[i], home_dir);
            tcleval(f);
            /* tclvareval("file normalize {", tclresult(), "}", NULL); */
            my_strncpy(f, abs_sym_path(tclresult(), ""), S(f));
          } else {
            my_strncpy(f, argv[i], S(f));
          }
          if(f[0]) {
           char win_path[WINDOW_PATH_SIZE];
           dbg(1, "f=%s\n", f);
           if(check_loaded(f, win_path) && xctx->current_win_path && strcmp(win_path, xctx->current_win_path)) {
             char msg[PATH_MAX + 100];
             my_snprintf(msg, S(msg),
                "tk_messageBox -type okcancel -icon warning -parent [xschem get topwindow] "
                "-message {Warning: %s already open.}", f);
             tcleval(msg);
             if(strcmp(tclresult(), "ok")) continue;
           }
           /* reuse a pristine untitled scratch buffer rather than leaving it
            * orphaned beside the file being opened (editor behavior). Only when the
            * path can be safely brace-wrapped; otherwise fall through to new_schematic
            * (which takes f as a C string, no Tcl quoting) so a brace/backslash in the
            * path can't corrupt the load command (issue 0022). */
           if(is_pristine_untitled() && tcl_braceable(f)) tclvareval("xschem load {", f, "}", NULL);
           else new_schematic(force_window ? "create_window" : "create", "noconfirm", f, 1);
           tclvareval("update_recent_file {", f, "}", NULL);
           /* a reopen-shortcut new-window open is read mode by default, like the in-window reopen */
           if(reopen && xctx && !xctx->readonly) { xctx->readonly = 1; set_modify(-1); }
          } else {
            new_schematic(force_window ? "create_window" : "create", NULL, NULL, 1);
          }
        }
      } else {
        tcleval("load_file_dialog {Load file} *.\\{sch,sym,tcl\\} INITIALLOADDIR");
        if(tclresult()[0]) {
          my_snprintf(f, S(f), "%s", tclresult());
        } else {
          cancel = 1;
        }
        if(!cancel) {
          if(f[0]) {
           dbg(1, "f=%s\n", f);
           /* reuse a pristine untitled scratch buffer (editor behavior); brace-wrap
            * only when safe, else fall through to new_schematic (issue 0022) */
           if(is_pristine_untitled() && tcl_braceable(f)) tclvareval("xschem load {", f, "}", NULL);
           else new_schematic("create", "noconfirm", f, 1);
           /* action-log (file-menu plan): dialog-resolved new-window open;
            * the with-filename arm above is the replay form and stays silent */
           if(tcl_braceable(f)) log_action("xschem load_new_window {%s}", f);
           tclvareval("update_recent_file {", f, "}", NULL);
          } else {
            new_schematic("create", NULL, NULL, 1);
          }
        }
      }
      Tcl_ResetResult(interp);
    }

    /* log f
     *   If 'f' is given output stderr messages to file 'f'
     *   if 'f' is not given and a file log is open, close log
     *   file and resume logging to stderr */
    else if(!strcmp(argv[1], "log"))
    { /* added check to avoid multiple open */
      if(argc > 2 && errfp == stderr ) {
        char f[PATH_MAX + 100];
        FILE *fp;

        my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[2], home_dir);
        tcleval(f);
        my_strncpy(f, tclresult(), S(f));
        fp = fopen(f, "w");
        if(fp) errfp = fp;
        else dbg(0, "xschem log: problems opening file %s\n", f);
    }
      else if(argc==2 && errfp != stderr) { fclose(errfp); errfp=stderr; }
    }

    /* log_action [-noecho] text
     *   Append 'text' as one line to the ACTION log (Xschem.log, the replayable
     *   session record -- distinct from the 'log'/'log_write' debug stream) and
     *   mirror it to the CIW log pane. With -noecho the line goes to the file
     *   only: used by the CIW command entry, which echoes typed commands itself.
     *   No-op when action logging is disabled. */
    else if(!strcmp(argv[1], "log_action"))
    {
      /* -emitted: report whether the core self-logged the just-run command, so a
       * Tcl wrapper can skip its own duplicate line (self-log-at-core dedup). */
      if(argc > 2 && !strcmp(argv[2], "-emitted")) {
        Tcl_SetResult(interp, actionlog_cmd_logged ? "1" : "0", TCL_STATIC);
        return TCL_OK;
      }
      if(argc > 3 && !strcmp(argv[2], "-noecho")) log_action_noecho("%s", argv[3]);
      /* -result/-error TEXT: record command OUTPUT as source-able comment lines
       * (D1, issue 0070); the pane echo is done by the Tcl caller. */
      else if(argc > 3 && !strcmp(argv[2], "-result")) log_output(0, argv[3]);
      else if(argc > 3 && !strcmp(argv[2], "-error"))  log_output(1, argv[3]);
      /* -suppressecho 0|1: while 1, a core self-log writes the file but not the
       * CIW mirror (the CIW entry already echoed the typed input line). */
      else if(argc > 3 && !strcmp(argv[2], "-suppressecho")) actionlog_suppress_echo = atoi(argv[3]);
      /* -suppress push|pop: re-entrant scope guard (issue 0071 Refactor A step 2).
       * Wrap a REPLAY (source a log with the log still OPEN) or a COMPOSITE op so
       * its sub-lines re-EXECUTE but do NOT re-LOG. A DEPTH COUNTER -> nested
       * scopes (replay { composite { core } }) stay suppressed until the OUTERMOST
       * pop. This is the SAFE surface (`replay_action_log`, xschem.tcl, uses it);
       * `xschem set actionlog_suppress N` below is the absolute (hard-reset) form.
       * NOT self-logged and never mints a line -- a control command, and once >0
       * every log_action is a no-op anyway. Distinct from -suppressecho (which
       * still writes the file). */
      else if(argc > 3 && !strcmp(argv[2], "-suppress")) {
        if(!strcmp(argv[3], "push"))      actionlog_suppress_push();
        else if(!strcmp(argv[3], "pop"))  actionlog_suppress_pop();
        else actionlog_suppress = atoi(argv[3]);   /* -suppress 0|1 absolute */
      }
      /* -reset: clear the dedup flag before a wrapper evaluates a command. */
      else if(argc > 2 && !strcmp(argv[2], "-reset")) actionlog_cmd_logged = 0;
      /* (issue 0207) A value-taking flag with its VALUE MISSING must NOT fall through to the
       * bare-line arm below. Every flag arm above is gated on argc > 3, so
       * `xschem log_action -result` with no text used to write the literal line `-result`
       * into Xschem.log -- and replaying that file then executes `-result` as a command and
       * aborts the `source`. The ASE seam (ase::echo, src/ase.tcl) calls this API from ~80
       * catch-wrapped sites with variable-derived text, so a legitimately empty variable made
       * it reachable. A missing value now logs NOTHING, which is the honest meaning of an
       * empty message. Only the KNOWN value-taking flags are swallowed: an unrecognised
       * argv[2] still reaches the bare-line arm, as before. */
      else if(argc > 2 && (!strcmp(argv[2], "-noecho")       || !strcmp(argv[2], "-result") ||
                           !strcmp(argv[2], "-error")        || !strcmp(argv[2], "-suppressecho") ||
                           !strcmp(argv[2], "-suppress"))) { /* flag without a value: no-op */ }
      else if(argc > 2) log_action("%s", argv[2]);
      Tcl_ResetResult(interp);
    }

    /* load_symbol [symbol_file]
     *   Load specified symbol_file
     *   Returns:
     *     >= 0: symbol is already loaded or has been loaded
     *     <  0: symbol was not loaded
     */
    else if(!strcmp(argv[1], "load_symbol") )
    {
      int res = -2;
      struct stat buf;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        int i = get_symbol(rel_sym_path(argv[2]));
        if(i < 0 ) {
          if(!stat(argv[2], &buf)) { /* file exists */
            res = load_sym_def(rel_sym_path(argv[2]), NULL);
            if(res == 0) res = -1;
          } else {
            res = -3;
          }
        } else {
          res = 1;
        }
      }
      Tcl_SetResult(interp, my_itoa(res), TCL_VOLATILE);
    }

    /* log_write text
     *   write given string to log file, so tcl can write messages on the log file
     */
    else if(!strcmp(argv[1], "log_write"))
    {
      if(argc > 2) {
        dbg(0, "%s\n", argv[2]);
      }
    }

    /* logic_get_net net_name
     *   Get logic state of net named 'net_name'
     *   Returns 0, 1, 2, 3 for logic levels 0, 1, X, Z or nothing if no net found.
     */
    else if(!strcmp(argv[1], "logic_get_net"))
    {
      static char s[2];

      my_strncpy(s, "2", S(s));
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      Tcl_ResetResult(interp);
      if(argc > 2) {
        Hilight_hashentry  *entry;
        entry = bus_hilight_hash_lookup(argv[2], 0, XLOOKUP);
        if(entry) {
          switch(entry->value) {
            case -5:
            s[0] = '1';
            break;
            case -12:
            s[0] = '0';
            break;
            case -1:
            s[0] = '2'; /* Unknown (X) */
            break;
            case -13:
            s[0] = '3'; /* Hi-Z (Z) */
            break;
            default:
            s[0] = '2';
            break;
          }
        }
        Tcl_SetResult(interp, s, TCL_VOLATILE);
      }
    }

    /* logic_set_net net_name n [num]
     *   set 'net_name' to logic level 'n' 'num' times.
     *   'n':
     *       0  set to logic value 0
     *       1  set to logic value 1
     *       2  set to logic value X
     *       3  set to logic value Z
     *      -1  toggle logic valie (1->0, 0->1)
     *   the 'num' parameter is essentially useful only with 'toggle' (-1)  value
     */
    else if(!strcmp(argv[1], "logic_set_net"))
    {
      int num =  1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 4 ) num = atoi(argv[4]);
      if(argc > 3) {
        int n = atoi(argv[3]);
        if(n == 4) n = -1;
        logic_set(n, num, argv[2]);
      }
      Tcl_ResetResult(interp);
    }

    /* logic_set n [num]
     *   set selected nets, net labels or pins to logic level 'n' 'num' times.
     *   'n':
     *       0  set to logic value 0
     *       1  set to logic value 1
     *       2  set to logic value X
     *       3  set to logic value Z
     *      -1  toggle logic valie (1->0, 0->1)
     *   the 'num' parameter is essentially useful only with 'toggle' (-1)  value
     */
    else if(!strcmp(argv[1], "logic_set"))
    {
      int num =  1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3 ) num = atoi(argv[3]);
      if(argc > 2) {
        int n = atoi(argv[2]);
        if(n == 4) n = -1;
        logic_set(n, num, NULL);
      }
      Tcl_ResetResult(interp);
    }

    /* libraries
     *   Read-only library registry query (library-manager Phase 1). Returns a
     *   Tcl list of {name path} pairs for every defined library. The registry =
     *   library.defs files listed in $XSCHEM_LIBRARY_DEFS plus auto-discovered
     *   dirs carrying a library.tag on the search path. Implemented in Tcl
     *   (src/library_defs.tcl); see doc/claude/code_analysis/library_manager_design.md. */
    else if(!strcmp(argv[1], "libraries"))
    {
      tcleval("library_list");
    }

    /* library <name>
     *   Absolute path of the named library, or "" if it is not defined. */
    else if(!strcmp(argv[1], "library"))
    {
      if(argc > 2) tclvareval("library_resolve {", argv[2], "}", NULL);
      else Tcl_ResetResult(interp);
    }

    /* lib_cells <library>
     *   Sorted list of cells in a library (subdirs holding a view directory).
     *   Backs the Library Manager tree (library-manager Phase 7a). */
    else if(!strcmp(argv[1], "lib_cells"))
    {
      if(argc > 2) tclvareval("library_cells {", argv[2], "}", NULL);
      else Tcl_ResetResult(interp);
    }

    /* library_manager [lcv]
     *   Open the Library Manager window (or, if already open, raise it and move
     *   focus into it -- see libmgr::open). Logs itself so the launch is a
     *   replayable action (CIW + Xschem.log) and can be bound to a key.
     *   The optional argument is a list: a single element is a library name; a
     *   {lib cell} or {lib cell view} list pre-selects and scrolls to that
     *   entry -- handy for locating a cell (e.g. `xschem library_manager
     *   [xschem get_inst_lcv]`). See doc/claude/specs/library_manager_launch.md. */
    else if(!strcmp(argv[1], "library_manager"))
    {
      if(has_x) {
        /* Log the argument-bearing form so the CIW / action-log line reproduces the
         * located cell (issue 0055), not just "open the manager". The lcv is one Tcl
         * list arg -- brace it, matching the adjacent libmgr::open call. */
        if(argc > 2) {
          log_action("xschem library_manager {%s}", argv[2]);
          tclvareval("libmgr::open {", argv[2], "}", NULL);
        } else {
          log_action("xschem library_manager");
          tcleval("libmgr::open");
        }
      }
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem m...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_m(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* make_sch
     *   Make a schematic from selected symbol */
    if(!strcmp(argv[1], "make_sch")) /* make schematic from selected symbol 20171004 */
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      create_sch_from_sym(); /* self-logs `xschem make_sch` at its core on success */
      Tcl_ResetResult(interp);
    }

    /* make_sch_from_sel
     *   Create an LCC instance from selection and place it instead of selection
     *   also ask if a symbol (.sym) file needs to be created */
    else if(!strcmp(argv[1], "make_sch_from_sel"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* mutates current buffer (delete selection + place LCC symbol) -> refuse on
       * read-only (issue 0041 hole; the Ctrl+H registered action now also carries
       * mutates=1). */
      if(scheduler_readonly_reject(interp, "make_sch_from_sel")) return TCL_ERROR;
      make_schematic_symbol_from_sel(); /* self-logs at its core on the real edit only */
      Tcl_ResetResult(interp);
    }

    /* make_symbol
     *   From current schematic (circuit.sch) create a symbol (circuit.sym)
     *   using ipin.sym, opin.sym, iopin.sym in schematic
     *   to deduce symbol interface pins. */
    else if(!strcmp(argv[1], "make_symbol"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(has_x) tcleval("tk_messageBox -type okcancel -parent [xschem get topwindow] "
                        "-message {do you want to make symbol view ?}");
      if(!has_x || strcmp(tclresult(), "ok")==0) {
        /* don't overwrite a read-only schematic on disk (0041 sibling hole): the
         * on-disk file already matches the buffer since read-only blocks edits, so
         * the symbol still generates from it. make_symbol() self-logs. */
        if(!xctx->readonly) save_schematic(xctx->sch[xctx->currsch], 0);
        make_symbol();
      }
      Tcl_ResetResult(interp);
    }

    /* merge [f]
     *   Merge another file. if 'f' not given prompt user. */
    else if(!strcmp(argv[1], "merge"))
    {
      char f[PATH_MAX + 100];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "merge")) return TCL_ERROR;
      if(argc < 3) {
        merge_file(0, "");  /* 2nd param not used for merge 25122002 */
      }
      else {
        my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[2], home_dir);
        tcleval(f);
        my_strncpy(f, tclresult(), S(f));
        merge_file(0, f);
      }
      Tcl_ResetResult(interp);
    }

    /* move_instance inst x y rot flip [nodraw] [noundo]
     *   resets instance coordinates, and rotaton/flip. A dash will keep existing value
     *   if 'nodraw' is given do not draw the moved instance
     *   if 'noundo' is given operation is not undoable
     * Routes through the perform_action boundary (Refactor B atom 19 -- the NINETEENTH per-verb
     * migration, a HIGHER-FRICTION coverage gain now the friction-free pool is EMPTY; a PURE SCRIPTED
     * instance-reposition verb with an INLINE mutation body, a CONDITIONAL noundo/nodraw push/draw (the
     * C5 sub-mode) and an instance-name referent). run_core MOVES the WHOLE INLINE body IN -- the argc<7
     * "needs: inst x y rot flip [nodraw] [noundo]" validation (early TCL_ERROR BEFORE any mutation, which
     * also prevents an OOB argv read in core_log_action on a short call), the nodraw/noundo flag parse,
     * the get_instance "instance not found" validation, the CONDITIONAL single push_undo (`if(undo)`,
     * owned here -- no self-undo core), the dashed x/y/rot/flip sets, symbol_bbox + prep-flag resets, and
     * the CONDITIONAL `if(dr) draw()`. core_log_action logs the FAITHFUL FULL CALL `xschem move_instance
     * <inst> <x> <y> <rot> <flip> [nodraw] [noundo]` (via log_action_argv/Tcl_Merge, instance name
     * metachar-safe, a `mi` array distinct from av/ev/pp; nodraw/noundo LOGGED not gated -- the wire_cut
     * noalign approach, since there is NO internal machinery caller, unlike replace_symbol's fast) on
     * success only. The mutation body is INLINE so it is strictly 1:1 with the verb (C3). The !xctx guard
     * + the per-verb scheduler_readonly_reject are DROPPED (the boundary re-checks both -- a readonly
     * CONSOLIDATION, not a new gate: the old branch already refused on a read-only cell, and the readonly
     * guard test locks it). NO set_modify (the branch had none). No scattered readonly/log/push_undo here. */
    else if(!strcmp(argv[1], "move_instance"))
      return perform_action("move_instance", argc, argv);
    /* move_objects [dx dy] [kissing] [stretch]
     *   Start a move operation on selection and let user terminate the operation in the GUI
     *   if kissing is given add nets to pins that touch other instances or nets
     *   if stretch is given stretch connected nets to follow instace pins
     *   if dx and dy are given move by that amount. */
    else if(!strcmp(argv[1], "move_objects"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "move_objects")) return TCL_ERROR;
      /* Headless incremental-drag seam (incremental_wire_reroute.md Phase II). Drive a stretch
       * drag one snap step at a time -- the way the GUI does on each Motion event -- so a test can
       * commit the SAME gesture BOTH stepwise (a move_objects(RUBBER) per snap grid) and one-shot
       * at release, and assert the resulting .sch is byte-identical. Sub-verbs:
       *   move_objects start <ax> <ay> [kissing] [stretch]  arm + move_objects(START) at anchor
       *   move_objects step  <x>  <y>                        one move_objects(RUBBER) at (x,y)
       *   move_objects end   [<dx> <dy>]                     move_objects(END) (explicit delta if given)
       * The one-shot release form `move_objects <dx> <dy> [kissing] [stretch]` is the final else. */
      if(argc > 2 && !strcmp(argv[2], "start")) {
        int i, k2 = 0, s2 = 0;
        for(i = 5; i < argc; i++) {                 /* flags after the two anchor coords */
          if(!strcmp(argv[i], "kissing")) k2 = 1;
          else if(!strcmp(argv[i], "stretch")) s2 = 1;
        }
        if(argc > 4) { xctx->mousex_snap = atof(argv[3]); xctx->mousey_snap = atof(argv[4]); }
        if(k2) xctx->connect_by_kissing = 2;        /* arm BEFORE select_attached_nets (tap-arm skip) */
        if(s2) select_attached_nets();
        move_objects(START, 0, 0, 0);
        /* START does not initialise x2/y2; seed them to the anchor so the first `step`
         * (necessarily a different snap) always passes the RUBBER no-motion guard. */
        xctx->x2 = xctx->x1; xctx->y2 = xctx->y1;
      }
      else if(argc > 2 && !strcmp(argv[2], "step")) {
        if(argc > 4) { xctx->mousex_snap = atof(argv[3]); xctx->mousey_snap = atof(argv[4]); }
        move_objects(RUBBER, 0, 0, 0);
      }
      else if(argc > 2 && !strcmp(argv[2], "end")) {
        if(argc > 4) move_objects(END, 0, atof(argv[3]), atof(argv[4]));
        else         move_objects(END, 0, 0, 0);
      }
      else if(argc > 2 && !strcmp(argv[2], "abort")) {
        move_objects(ABORT, 0, 0, 0);
      }
      else {
        int nparam = 0, kissing = 0, stretch = 0, i;
        int rot = 0, flip = 0, rotl = 0, has_anchor = 0, k;
        double ax = 0.0, ay = 0.0;
        if(argc > 2) {
          for(i = 2; i < argc; i++) {
            if(!strcmp(argv[i], "kissing")) {kissing = 1; nparam++;}
            if(!strcmp(argv[i], "stretch")) {stretch = 1; nparam++;}
          }
        }
        /* arm kissing BEFORE select_attached_nets so the latter can see it and skip
         * grabbing a through-run tap arm (a stub will replace it). See wire_through_tap_arm(). */
        if(kissing) xctx->connect_by_kissing = 2;
        if(stretch) select_attached_nets();
        if(argc > 3 + nparam) {
          /* mid-move rotate/flip replay (issue 0069 atom 13): optional `rot flip [local]
           * [-anchor ax ay]` after the delta, mirroring the paste arm. `local` = per-object
           * pivot (ROTATELOCAL); `-anchor` pins the shared group-rotate pivot (x1/y1) that a
           * replay's START would otherwise seed from the replay-time cursor. Guarded so a
           * plain `move_objects dx dy [kissing]` line parses identically to before. */
          k = 4;
          if(argc > 5 && argv[4][0] != '-' && argv[5][0] != '-' &&
             strcmp(argv[4], "kissing") && strcmp(argv[4], "stretch") &&
             strcmp(argv[5], "kissing") && strcmp(argv[5], "stretch")) {
            rot = atoi(argv[4]) & 0x3;
            flip = atoi(argv[5]) & 0x1;
            k = 6;
            if(argc > k && !strcmp(argv[k], "local")) { rotl = 1; k++; }
          }
          for(; k < argc; k++) {
            if(!strcmp(argv[k], "-anchor") && k + 2 < argc) {
              ax = atof(argv[k + 1]); ay = atof(argv[k + 2]); has_anchor = 1; k += 2;
            }
          }
          move_objects(START,0,0,0);
          /* unconditional: the line is the FULL transform record -- a stale rotatelocal /
           * move_rot from a prior gesture must not leak into this one (paste-arm discipline) */
          xctx->move_rot = (short)rot;
          xctx->move_flip = (short)flip;
          xctx->rotatelocal = (short)rotl;
          if(has_anchor) { xctx->x1 = ax; xctx->y1 = ay; }
          move_objects( END,0,atof(argv[2]), atof(argv[3]));
        }
        else {
          /* MENU "Move objects" arms a DEFERRED move (mouse over the menu); the canvas click
           * starts it. The M KEY is made immediate separately in callback.c case 'm'. */
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTMOVE;
        }
      }
      Tcl_ResetResult(interp);
    }
    /* my_strtok_r str delim quote keep_quote
     * test for my_strtok_r() function */
    else if(!strcmp(argv[1], "my_strtok_r"))
    {
      if(argc > 5) {
        char *strcopy = NULL, *strptr = NULL, *saveptr = NULL, *tok;

        my_strdup2(_ALLOC_ID_, &strcopy, argv[2]);
        strptr = strcopy;

        while( (tok = my_strtok_r(strptr, argv[3], argv[4], atoi(argv[5]), &saveptr)) ) {
          strptr = NULL;
          Tcl_AppendResult(interp, "{", tok, "}\n", NULL);
        }
        my_free(_ALLOC_ID_, &strptr);

      }
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem n...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
/* --- net-as-object read API (step-3 direction (c2)) -----------------------
 * A net is DERIVED — no struct, no array, no id of its own. Its durable handle
 * is the stable id of a wire or label-instance ON it (an "anchor"); resolving
 * an anchor re-runs connectivity and yields the net's CURRENT token + members.
 * These helpers are READ-ONLY and assume the caller has already run
 * prepare_netlist_structs(0) (and rebuild_selected_array() if it reads the
 * selection) — the §2c coherence rule (tcl_introspection_wire.md, NC3).
 * See doc/claude/code_analysis/net_identity_decision.md (c2, ratified). */

/* Resolve a net selector to its current net token, or NULL if it does not
 * resolve (dangling anchor / unknown pin). 'base' is the argv index of the
 * first selector word. Forms:
 *   @wire <id>        -> the net wire-id <id> is on (xctx->wire[i].node)
 *   @inst <id> <pin>  -> the net at instance-id <id>'s named pin
 *   <token>           -> the token itself (a net name; the human form)
 * The returned pointer is owned by xctx (.node) or argv — do NOT free it; it is
 * valid only until the next connectivity rebuild. */
static const char *net_selector_token(int argc, const char *argv[], int base)
{
  if(base >= argc) return NULL;
  if(!strcmp(argv[base], "@wire")) {
    int i;
    if(base + 1 >= argc) return NULL;
    i = wire_index_from_id((unsigned int)strtoul(argv[base + 1], NULL, 10));
    if(i < 0) return NULL;
    return xctx->wire[i].node;                 /* may be NULL: wire on no net */
  } else if(!strcmp(argv[base], "@inst")) {
    int i, p, no_of_pins;
    if(base + 2 >= argc) return NULL;
    i = inst_index_from_id((unsigned int)strtoul(argv[base + 1], NULL, 10));
    if(i < 0 || xctx->inst[i].ptr < 0) return NULL;
    no_of_pins = xctx->sym[xctx->inst[i].ptr].rects[PINLAYER];
    for(p = 0; p < no_of_pins; p++) {
      if(!strcmp(get_tok_value(xctx->sym[xctx->inst[i].ptr].rect[PINLAYER][p].prop_ptr, "name", 0),
                 argv[base + 2])) break;
    }
    if(p >= no_of_pins) return NULL;            /* no such pin */
    if(xctx->inst[i].node && xctx->inst[i].node[p]) return xctx->inst[i].node[p];
    return NULL;
  } else {
    return argv[base];                          /* a net name (token) */
  }
}

/* Append the bare descriptor of the net named 'token' to the interp result:
 *   name {<token>} nwires N npins M anchor {wire <id>} | {inst <id> <pin>} | {}
 * Counts wire segments and instance pins on the net; the anchor prefers a
 * label/pin DRIVER (lowest instance id, the net's authority per §2d), else the
 * lowest-id wire, else {} (an anchorless net). Ids are stable step-1/2 ids. */
static void net_emit_descriptor(Tcl_Interp *interp, const char *token)
{
  int i, p, no_of_pins, nwires = 0, npins = 0;
  int anc_wire_id = -1;                          /* lowest wire id on the net */
  int anc_inst_id = -1;                          /* lowest label/pin driver id */
  const char *anc_pin = NULL;
  char buf[512];
  for(i = 0; i < xctx->wires; i++) {
    if(xctx->wire[i].node && !strcmp(xctx->wire[i].node, token)) {
      nwires++;
      if(anc_wire_id < 0 || (int)xctx->wire[i].id < anc_wire_id) anc_wire_id = (int)xctx->wire[i].id;
    }
  }
  for(i = 0; i < xctx->instances; i++) {
    const char *type;
    if(xctx->inst[i].ptr < 0 || !xctx->inst[i].node) continue;
    type = xctx->sym[xctx->inst[i].ptr].type;
    no_of_pins = xctx->sym[xctx->inst[i].ptr].rects[PINLAYER];
    for(p = 0; p < no_of_pins; p++) {
      if(xctx->inst[i].node[p] && !strcmp(xctx->inst[i].node[p], token)) {
        npins++;
        if(type && IS_LABEL_SH_OR_PIN(type) &&
           (anc_inst_id < 0 || (int)xctx->inst[i].id < anc_inst_id)) {
          anc_inst_id = (int)xctx->inst[i].id;
          anc_pin = get_tok_value(xctx->sym[xctx->inst[i].ptr].rect[PINLAYER][p].prop_ptr, "name", 0);
        }
      }
    }
  }
  if(anc_inst_id >= 0)
    my_snprintf(buf, S(buf), "name {%s} nwires %d npins %d anchor {inst %d %s}",
                token, nwires, npins, anc_inst_id, anc_pin ? anc_pin : "");
  else if(anc_wire_id >= 0)
    my_snprintf(buf, S(buf), "name {%s} nwires %d npins %d anchor {wire %d}",
                token, nwires, npins, anc_wire_id);
  else
    my_snprintf(buf, S(buf), "name {%s} nwires %d npins %d anchor {}",
                token, nwires, npins);
  Tcl_AppendResult(interp, buf, NULL);
}

/* Add 'tok' to the distinct-token list (*seen, *nseen) if non-empty and not
 * already present. Stores the pointer (owned by xctx), not a copy; used by
 * `xschem nets` to dedup. Returns 1 if newly added, 0 otherwise. */
static int net_token_add(const char ***seen, int *nseen, const char *tok)
{
  int k;
  if(!tok || !tok[0]) return 0;
  for(k = 0; k < *nseen; k++) if(!strcmp((*seen)[k], tok)) return 0;
  my_realloc(_ALLOC_ID_, seen, (*nseen + 1) * sizeof(char *));
  (*seen)[*nseen] = tok;
  (*nseen)++;
  return 1;
}

static int xschem_cmds_n(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* net <selector>
     *   Return the uniform descriptor of ONE net, or "" if it does not resolve.
     *   A net is derived, so it is addressed by an ANCHOR (a stored-object
     *   handle on it) or by its current name. <selector> is one of
     *     @wire <id>          the net the wire with stable id <id> is on
     *     @inst <id> <pin>    the net at instance-id <id>'s named pin
     *     <token>             by current net name (the human form; may alias)
     *   The descriptor is {name {<tok>} nwires N npins M anchor {wire <id>} |
     *   {inst <id> <pin>} | {}}. Read-only. See `xschem nets` /
     *   `xschem net_members`; doc/claude/code_analysis/net_identity_decision.md (c2). */
    if(!strcmp(argv[1], "net"))
    {
      const char *token;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem net needs a selector "
                      "(@wire <id> | @inst <id> <pin> | <token>)", TCL_STATIC);
        return TCL_ERROR;
      }
      prepare_netlist_structs(0);
      Tcl_ResetResult(interp);  /* prepare_netlist_structs leaves "0" in result */
      token = net_selector_token(argc, argv, 2);
      if(token) net_emit_descriptor(interp, token);
      /* else leave the result empty — a dangling anchor / unknown net */
    }

    /* net_hilight_test_now <ms> [<win>]
     *   TEST HOOK (Pass 2a): force the net-highlight blink phase to a fixed time so a render
     *   can deterministically sample an ON-phase vs OFF-phase frame. A negative <ms> (or no
     *   arg) turns the override off (back to wall-clock). Never used in production.
     *   The forced time is per-Xschem_ctx; the optional <win> sets it on THAT window's context
     *   (Phase-A borrow) so a background window's animation frame can be driven from the front
     *   (multi-window anim, Phase C). */
    else if(!strcmp(argv[1], "net_hilight_test_now"))
    {
      char *endp = NULL;
      double ms;
      Xschem_ctx *borrowed = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* strtod (not atof) so a non-numeric arg is rejected rather than parsed as 0.0, which
       * would silently activate the override at t=0 instead of erroring. */
      if(argc > 2) ms = strtod(argv[2], &endp);
      else { ms = -1.0; endp = NULL; }
      if(argc > 2 && (endp == argv[2] || *endp != '\0')) {
        Tcl_SetResult(interp, "net_hilight_test_now: <ms> must be a number", TCL_STATIC);
        return TCL_ERROR;
      }
      /* an explicit <win> that names no open window must error, not silently force the time on
       * the FRONT context (borrow -> NULL is "already current" OR "unknown"; disambiguate). */
      if(argc > 3 && !net_hilight_win_known(argv[3])) {
        Tcl_SetResult(interp, "net_hilight_test_now: unknown window path", TCL_STATIC);
        return TCL_ERROR;
      }
      if(argc > 3) borrowed = net_hilight_borrow_ctx(argv[3]);
      if(ms >= 0.0) {
        xctx->net_hilight_test_active = 1;
        xctx->net_hilight_test_ms = ms;
      } else {
        xctx->net_hilight_test_active = 0;
        xctx->net_hilight_test_ms = 0.0;
      }
      net_hilight_restore_ctx(borrowed);
      Tcl_ResetResult(interp);
    }

    /* net_hilight_anim_update_all
     *   (Re)evaluate and arm/cancel the net-highlight animation tick for EVERY open window
     *   (multi-window anim, Phase D). Thin Tcl entry to the C fan-out so a change to a GLOBAL
     *   animation input (e.g. toggling the net_hilight_animate kill-switch) refreshes all
     *   windows, not just the front. Background tabs are skipped inside the fan-out. */
    else if(!strcmp(argv[1], "net_hilight_anim_update_all"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      net_hilight_anim_update();
      Tcl_ResetResult(interp);
    }

    /* net_hilight_sync_suspend / net_hilight_sync_resume
     *   Bracket a bulk-highlight loop (many `xschem hilight_netname` in a row) so the expensive
     *   cross-window descend-child sync runs ONCE at the end instead of per net (issue 0073 §9d /
     *   review perf). Nestable (counter). The Tcl caller MUST pair them with a catch so a mid-loop
     *   error still resumes (else the counter stays >0 and suppresses all later syncs). */
    else if(!strcmp(argv[1], "net_hilight_sync_suspend"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      net_hilight_sync_suspend();
      Tcl_ResetResult(interp);
    }
    else if(!strcmp(argv[1], "net_hilight_sync_resume"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      net_hilight_sync_resume();
      Tcl_ResetResult(interp);
    }

    /* net_hilight_relay_enable [<0|1>]
     *   Toggle (or query) the deep-gap net-highlight relay (issue 0073 §9c fix): translating an
     *   EXACT highlight across a linked-window gap of more than one hierarchy level by transiently
     *   loading the intermediate schematics. With no arg, returns the current 0/1 state. Also the
     *   test sabotage seam: setting it 0 forces the clear-through-only fallback. */
    else if(!strcmp(argv[1], "net_hilight_relay_enable"))
    {
      if(argc >= 3) net_hilight_set_relay_enable(atoi(argv[2]));
      Tcl_SetResult(interp, net_hilight_get_relay_enable() ? "1" : "0", TCL_STATIC);
    }

    /* net_hilight_sync_force_headless <0|1>
     *   TEST-ONLY (issue 0073 §8 Tier C): force the cross-window highlight sync + deep-gap relay to
     *   run under --nogui (has_x==0) over logical contexts, so it can be exercised in the fast headless
     *   suite. The sync's draws self-skip (no save_pixmap headless). Never set in production. */
    else if(!strcmp(argv[1], "net_hilight_sync_force_headless"))
    {
      if(argc >= 3) net_hilight_set_sync_force_headless(atoi(argv[2]));
      Tcl_ResetResult(interp);
    }

    /* net_hilight_dump_pixmap <file> [<win>]
     *   TEST HOOK (Pass 2-multiwin, Phase C): write the LIVE backing pixmap (save_pixmap) of
     *   <win> (default: current window) to a PNG, WITHOUT re-rendering. Unlike `xschem print
     *   png` (which calls draw() and so captures steady highlights), this captures exactly the
     *   pixels a preceding `redraw_hilight_region` painted -- the blink/march phase -- so a
     *   per-window animation frame can be byte-compared (cmp) and front/background cross-talk
     *   detected. Never used in production. */
    else if(!strcmp(argv[1], "net_hilight_dump_pixmap"))
    {
      Xschem_ctx *borrowed = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "net_hilight_dump_pixmap: missing <file>", TCL_STATIC);
        return TCL_ERROR;
      }
      /* an explicit <win> that names no open window must error, not silently dump the FRONT
       * window's pixmap (which would make the byte-compare test the wrong surface). */
      if(argc > 3 && !net_hilight_win_known(argv[3])) {
        Tcl_SetResult(interp, "net_hilight_dump_pixmap: unknown window path", TCL_STATIC);
        return TCL_ERROR;
      }
      if(argc > 3) borrowed = net_hilight_borrow_ctx(argv[3]);
      /* Fail LOUDLY on any non-write rather than returning OK with no file: a test that then
       * cmp's a stale/missing PNG would otherwise get a false verdict. */
#if defined(__unix__) && HAS_CAIRO==1
      if(has_x && xctx->save_pixmap) {
        cairo_surface_t *sfc = cairo_xlib_surface_create(display, xctx->save_pixmap, visual,
                                 xctx->xrect[0].width, xctx->xrect[0].height);
        cairo_status_t st = cairo_surface_write_to_png(sfc, argv[2]);
        cairo_surface_destroy(sfc);
        net_hilight_restore_ctx(borrowed);
        if(st != CAIRO_STATUS_SUCCESS) {
          Tcl_AppendResult(interp, "net_hilight_dump_pixmap: PNG write failed: ",
                           cairo_status_to_string(st), NULL);
          return TCL_ERROR;
        }
        Tcl_ResetResult(interp);
      } else {
        net_hilight_restore_ctx(borrowed);
        Tcl_SetResult(interp, "net_hilight_dump_pixmap: no pixmap to dump "
                      "(no X, or window not drawn yet)", TCL_STATIC);
        return TCL_ERROR;
      }
#else
      net_hilight_restore_ctx(borrowed);
      Tcl_SetResult(interp, "net_hilight_dump_pixmap: requires a unix cairo build", TCL_STATIC);
      return TCL_ERROR;
#endif
    }

    /* net_hilight_march_offset <idx>
     *   INTROSPECTION/TEST HOOK (Pass 2b): return the marching-ants dash scroll offset
     *   (dash-length units, reduced into [0,P)) computed for net highlight style <idx> at the
     *   current animation time (honoring the net_hilight_test_now override). 0 for a
     *   non-marching / empty-dash style. Lets the deterministic offset formula be asserted
     *   numerically without pixel analysis. */
    else if(!strcmp(argv[1], "net_hilight_march_offset"))
    {
      char *endp = NULL;
      long idx;
      char buf[64];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "net_hilight_march_offset: missing <idx>", TCL_STATIC);
        return TCL_ERROR;
      }
      idx = strtol(argv[2], &endp, 10);
      if(endp == argv[2] || *endp != '\0') {
        Tcl_SetResult(interp, "net_hilight_march_offset: <idx> must be an integer", TCL_STATIC);
        return TCL_ERROR;
      }
      if(!xctx->net_hilight_style || xctx->n_net_hilight_styles <= 0) build_net_hilight_styles();
      if(idx < 0 || idx >= xctx->n_net_hilight_styles) {
        Tcl_SetResult(interp, "net_hilight_march_offset: <idx> out of range", TCL_STATIC);
        return TCL_ERROR;
      }
      my_snprintf(buf, S(buf), "%.6f",
        net_hilight_march_offset(&xctx->net_hilight_style[(int)idx], net_hilight_now_ms()));
      Tcl_SetResult(interp, buf, TCL_VOLATILE);
    }

    /* nets [-selected]
     *   Return a Tcl LIST of net descriptors, one per DISTINCT net (deduped by
     *   token). With -selected, restrict to nets touched by the current
     *   selection (selected wires + selected instances' pins). Each element is a
     *   {name {<tok>} nwires N npins M anchor {..}} dict. Read-only.
     *   -selected rebuilds the selection array first, so a COLD call is correct
     *   (the §2c fix resolved_net lacks — see test NC3 vs NH5). */
    else if(!strcmp(argv[1], "nets"))
    {
      int only_sel = 0, a, i, p, no_of_pins, first = 1;
      const char **seen = NULL;
      int nseen = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(a = 2; a < argc; a++) if(!strcmp(argv[a], "-selected")) only_sel = 1;
      prepare_netlist_structs(0);
      if(only_sel) rebuild_selected_array();
      Tcl_ResetResult(interp);  /* prepare_netlist_structs leaves "0" in result */
      for(i = 0; i < xctx->wires; i++) {
        if(only_sel && xctx->wire[i].sel != SELECTED) continue;
        net_token_add(&seen, &nseen, xctx->wire[i].node);
      }
      for(i = 0; i < xctx->instances; i++) {
        if(only_sel && xctx->inst[i].sel != SELECTED) continue;
        if(xctx->inst[i].ptr < 0 || !xctx->inst[i].node) continue;
        no_of_pins = xctx->sym[xctx->inst[i].ptr].rects[PINLAYER];
        for(p = 0; p < no_of_pins; p++) net_token_add(&seen, &nseen, xctx->inst[i].node[p]);
      }
      for(i = 0; i < nseen; i++) {
        if(!first) Tcl_AppendResult(interp, " ", NULL);
        Tcl_AppendResult(interp, "{", NULL);
        net_emit_descriptor(interp, seen[i]);
        Tcl_AppendResult(interp, "}", NULL);
        first = 0;
      }
      if(seen) my_free(_ALLOC_ID_, &seen);
    }

    /* net_members <selector>
     *   Return the membership of a net BY HANDLE:
     *     {wires {<id> <id> ...} pins {{<inst-id> <pin>} ...}}
     *   <selector> is as for `xschem net`. wires lists the stable ids of the
     *   wire segments on the net; pins lists {stable-instance-id pin-name} for
     *   every instance pin on it (including the driving label/pin). Read-only;
     *   composes with `xschem object <type> @id`. */
    else if(!strcmp(argv[1], "net_members"))
    {
      const char *token;
      int i, p, no_of_pins, first;
      char num[64];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem net_members needs a selector "
                      "(@wire <id> | @inst <id> <pin> | <token>)", TCL_STATIC);
        return TCL_ERROR;
      }
      prepare_netlist_structs(0);
      token = net_selector_token(argc, argv, 2);
      Tcl_ResetResult(interp);  /* prepare_netlist_structs leaves "0" in result */
      if(!token) return TCL_OK;                  /* empty: dangling / unknown */
      Tcl_AppendResult(interp, "wires {", NULL);
      first = 1;
      for(i = 0; i < xctx->wires; i++) {
        if(xctx->wire[i].node && !strcmp(xctx->wire[i].node, token)) {
          my_snprintf(num, S(num), "%d", (int)xctx->wire[i].id);
          if(!first) Tcl_AppendResult(interp, " ", NULL);
          Tcl_AppendResult(interp, num, NULL);
          first = 0;
        }
      }
      Tcl_AppendResult(interp, "} pins {", NULL);
      first = 1;
      for(i = 0; i < xctx->instances; i++) {
        if(xctx->inst[i].ptr < 0 || !xctx->inst[i].node) continue;
        no_of_pins = xctx->sym[xctx->inst[i].ptr].rects[PINLAYER];
        for(p = 0; p < no_of_pins; p++) {
          if(xctx->inst[i].node[p] && !strcmp(xctx->inst[i].node[p], token)) {
            const char *pin = get_tok_value(xctx->sym[xctx->inst[i].ptr].rect[PINLAYER][p].prop_ptr, "name", 0);
            my_snprintf(num, S(num), "%d", (int)xctx->inst[i].id);
            if(!first) Tcl_AppendResult(interp, " ", NULL);
            Tcl_AppendResult(interp, "{", num, " ", pin, "}", NULL);
            first = 0;
          }
        }
      }
      Tcl_AppendResult(interp, "}", NULL);
    }

    /* net_label [type]
     *   Place a new net label
     *   'type': 1: place a 'lab_pin.sym' label
     *           0: place a 'lab_wire.sym' label
     *   User should complete the placement in the GUI. */
    else if(!strcmp(argv[1], "net_label"))
    {
      if(scheduler_readonly_reject(interp, "net_label")) return TCL_ERROR;
      if(argc > 2) {
        place_net_label(atoi(argv[2]));
      }
    }

    /* net_at x y
     *   Return 1 if (x,y) lands on copper -- ON a wire or EXACTLY on a (non-selected) instance
     *   pin -- else 0. The predicate behind the Add-Wire-Label drop constraint
     *   (doc/claude/specs/add_wire_label.md); exposed for tests/scripts. Read-only. */
    else if(!strcmp(argv[1], "net_at"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
        Tcl_SetResult(interp,
          point_on_wire_or_pin(atof(argv[2]), atof(argv[3])) ? "1" : "0", TCL_STATIC);
      } else {
        Tcl_SetResult(interp, "usage: xschem net_at x y", TCL_STATIC);
        return TCL_ERROR;
      }
    }

    /* net_name_at <x> <y> | net_name_at -wire <index>
     *   The RAW net token of a WIRE, or "" if there is none there. READ-ONLY: it selects
     *   nothing and changes nothing -- the probe half of the ASE signal pick, and the
     *   deliberate opposite of `select_at` + `nets -selected`, which was the mutating way
     *   to ask the same question.
     *
     *   Coordinate form: "" unless the closest object at (x,y) is a wire. Index form: the
     *   token of wire <index> directly -- for a caller that has ALREADY hit-tested and
     *   holds the row (`xschem object_at` returns `wire <index> ...`). Prefer it: the
     *   coordinate form runs a SECOND, independent hit test, and `find_closest_text`
     *   expands floater text through Tcl on every pass, so a floater whose expansion
     *   changed between the two passes could win the cascade the second time and turn a
     *   resolved wire into a silent "". Wire indices are stable across
     *   prepare_netlist_structs (it names nodes; it never stores, splits or trims wires),
     *   so an index taken before the prep is still the same wire after it.
     *
     *   "" also when the wire has no node at all -- i.e. one the ACTIVE netlist type skips
     *   (spice_ignore / lvs_ignore, netlist.c skip_wire). Note a merely dangling wire is
     *   NOT that case: name_unlabeled_nets gives it a `#netN` token like any other.
     *   doc/claude/issues/0204-sod-pick-mutates-the-selection.md
     *
     *   NOT `net_at`: that name was already taken by the branch immediately above -- an
     *   on-copper boolean PREDICATE, nothing to do with naming a net.
     *
     *   Three details are copied from the selection-based idiom it replaces, and each one
     *   is load-bearing:
     *   - WIRE ONLY. On a device BODY `nets -selected` reports every net the device
     *     touches, and a two-pin device shorted onto one net reports exactly one -- so a
     *     count test alone misclassified a non-source device click as a voltage pick
     *     (test_ase_unnamed_net AN7b). A wire lies on exactly one net by construction, so
     *     the type gate IS the correctness argument. The COORDINATE form enforces it here
     *     rather than leaving it to the caller; the index form cannot -- addressing
     *     xctx->wire[n] IS the gate, and it is the caller's job to have got that index
     *     from a wire row (as sod_net_at does, from its `$hit`).
     *   - find_closest_obj, not find_closest_wire: the caller asked "what is under this
     *     point", and a wire crossing a symbol must NOT win over the symbol. Restricting
     *     the cascade would resolve a net for clicks that did not land on a wire at all.
     *   - override_lock 0 in the COORDINATE form, matching select_at exactly, so a
     *     lock=true wire still resolves nothing there and issue 0160's locked-wire path
     *     keeps going through `xschem flylines at` (which does override the lock) exactly
     *     as it does today. The index form has no lock semantics at all -- the lock lives
     *     only inside find_closest_obj, which it does not run -- so `-wire <n>` on a
     *     locked wire DOES return its token. That is consistent, not an oversight: a lock
     *     gates edits, and this verb cannot edit. It is invisible to the ASE pick, whose
     *     index always comes from an override_lock=0 `object_at` row. Making the whole
     *     family agree on override_lock=1 is issue 0205, because that changes what a
     *     locked object CLASSIFIES as, which is user-visible.
     *
     *   The token is returned with its `#` and in its original case -- the same string
     *   `xschem nets` reports as the descriptor `name`, since both read xctx->wire[].node
     *   verbatim. prepare_netlist_structs(0) first, so a COLD call on a freshly loaded
     *   schematic is correct (the same reason `nets` does it). */
    else if(!strcmp(argv[1], "net_name_at"))
    {
      int n = -1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 4) {
        Tcl_SetResult(interp, "usage: xschem net_name_at x y | xschem net_name_at -wire n",
                      TCL_STATIC);
        return TCL_ERROR;
      }
      /* prepare FIRST, pick SECOND -- the order `flylines at` uses, and it matters:
       * prepare_netlist_structs() runs delete_netlist_structs() internally, which frees
       * every .node string, so a pointer taken before the call could not be trusted
       * after it. (An INDEX can: prep never changes xctx->wires or the wire order.) */
      prepare_netlist_structs(0);
      if(!strcmp(argv[2], "-wire")) {
        n = atoi(argv[3]);
      } else {
        Selected s = find_closest_obj(atof(argv[2]), atof(argv[3]), 0);
        if(s.type == WIRE) n = s.n;
      }
      /* Reset AFTER the pick, not before: find_closest_text() expands floater text
       * (get_text_floater -> translate), which evaluates Tcl and can leave a result
       * behind. prepare_netlist_structs itself now ends clean (issue 0155). */
      Tcl_ResetResult(interp);
      if(n >= 0 && n < xctx->wires && xctx->wire[n].node && xctx->wire[n].node[0])
        Tcl_AppendResult(interp, xctx->wire[n].node, NULL);
    }

    /* net_pin_mismatch
     *   Highlight nets attached to selected symbols with
     *   a different name than symbol pin */
    else if(!strcmp(argv[1], "net_pin_mismatch"))
    {
      hilight_net_pin_mismatches();
    }

    /* netlist [-keep_symbols|-noalert|-messages|-erc | -nohier] [filename]
     *   do a netlist of current schematic in currently defined netlist format
     *   if 'filename'is given use specified name for the netlist
     *   if 'filename' contains path components place the file in specified path location.
     *   if only a name is given and no path ('/') components are given use the
     *   default netlisting directory.
     *   This means that 'xschem netlist test.spice' and 'xschem netlist ./test.spice'
     *   will create the netlist in different places.
     *   netlisting directory is reset to previous setting after completing this command
     *   If -messages is given return the ERC messages instead of just a fail (1)
     *   or no fail (0) code.
     *   If -erc is given it means netlister is called from gui, enable show infowindow
     *   If -nohier is given netlist only current level
     *   If -keep_symbols is given no not purge symbols encountered traversing the
     *   design hierarchy */
    else if(!strcmp(argv[1], "netlist") )
    {
      char *saveshow = NULL;
      int err = 0;
      int hier_netlist = 1;
      int i, messages = 0;
      int alert = 1;
      int keep_symbols=0, save_keep;
      int erc = 0;
      const char *fname = NULL;
      const char *path;
      char savedir[PATH_MAX];
      int done_netlist = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      yyparse_error = 0;
      my_strdup(_ALLOC_ID_, &saveshow, tclgetvar("show_infowindow_after_netlist"));
      set_netlist_dir(0, NULL);

      my_strncpy(savedir, tclgetvar("netlist_dir"), S(savedir));
      for(i = 2; i < argc; i++) {
        if(argv[i][0] == '-') {
          if(!strcmp(argv[i], "-messages")) {
            messages = 1;
          } else if(!strcmp(argv[i], "-erc")) {
            erc = 1;
          } else if(!strcmp(argv[i], "-keep_symbols")) {
            keep_symbols = 1;
          } else if(!strcmp(argv[i], "-noalert")) {
            alert = 0;
          } else if(!strcmp(argv[i], "-nohier")) {
            hier_netlist = 0;
          }
        } else {
          fname = argv[i];
          break;
        }
      }
      if(erc == 0) tclsetvar("show_infowindow_after_netlist", "never");
      if(fname) {
        my_strncpy(xctx->netlist_name, get_cell_w_ext(fname, 0), S(xctx->netlist_name));
        tclvareval("file dirname ", fname, NULL);
        path = tclresult();
        if(strchr(fname, '/')) {
          set_netlist_dir(1, path);
        }
      }
      if(set_netlist_dir(0, NULL) ) {
        done_netlist = 1;

        save_keep = tclgetboolvar("keep_symbols");
        if(keep_symbols) tclsetboolvar("keep_symbols", keep_symbols);
        if(xctx->netlist_type == CAD_SPICE_NETLIST)
          err = global_spice_netlist(hier_netlist, alert);
        else if(xctx->netlist_type == CAD_VHDL_NETLIST)
          err = global_vhdl_netlist(hier_netlist, alert);
        else if(xctx->netlist_type == CAD_VERILOG_NETLIST)
          err = global_verilog_netlist(hier_netlist, alert);
        else if(xctx->netlist_type == CAD_SPECTRE_NETLIST)
          err = global_spectre_netlist(hier_netlist, alert);
        else if(xctx->netlist_type == CAD_TEDAX_NETLIST)
          global_tedax_netlist(hier_netlist, alert);
        else
          if(has_x) tcleval("tk_messageBox -type ok -parent [xschem get topwindow] "
                            "-message {Please Set netlisting mode (Options menu)}");
        tclsetboolvar("keep_symbols", save_keep);

        if(erc == 0) {
          my_strncpy(xctx->netlist_name, "", S(xctx->netlist_name));
        }
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
      tclsetvar("show_infowindow_after_netlist", saveshow);
      tcleval("eval_netlist_postprocess");
      set_netlist_dir(1, savedir);
      /* action-log (issue 0062 last silent toolbar/menu row / issue 0071 atom 14):
       * this `netlist` branch IS 1:1 with the user verb `xschem netlist` -- it is the
       * replay form reached by the toolbar (xschem.tcl toolbar_add Netlist), the menu,
       * the plain `n` key (bound to toolbar.netlist -> the dispatch after-eval dedup
       * skips the wrapper copy since we set actionlog_cmd_logged here) and scripted
       * calls. So the branch self-logs the resolved output-affecting form (the atom-3/4
       * branch-self-log shape, NOT a coordinate-bypass verb -- netlist is a real
       * re-executable action like `save`, so it correctly re-logs on replay). The
       * global_*_netlist() cores are SHARED (this branch + the Shift-N key +
       * the CLI -n batch), so they must NOT self-log; the Shift-N current-level key
       * logs its own `-nohier` equivalent at its callback.c handler (keyboard-bypass).
       * MACHINERY GATE (mirrors the atom-4 `save fast` axis): `-keep_symbols` is passed
       * ONLY by the cellview/reroute machinery (xschem.tcl reroute_inst / cellview
       * relabel, which netlist a temporarily-loaded file between unlogged
       * `load -keep_symbols` calls), so a keep_symbols pass stays SILENT or a replayed
       * line would fire against the wrong file / flood. The dir-unwritable early return
       * (done_netlist == 0) logs nothing. */
      if(done_netlist && !keep_symbols) {
        const char *av[5];
        int ac = 0;
        av[ac++] = "xschem";
        av[ac++] = "netlist";
        if(erc) av[ac++] = "-erc";
        if(!hier_netlist) av[ac++] = "-nohier";
        if(fname) av[ac++] = fname;
        log_action_argv(ac, (const char *const *)av);
      }
      if(done_netlist) {
        if(messages) {
          Tcl_SetResult(interp, xctx->infowindow_text, TCL_VOLATILE);
        } else {
         Tcl_SetResult(interp, my_itoa(err), TCL_VOLATILE);
        }
      }
      my_free(_ALLOC_ID_, &saveshow);
    }

    /* new_process [f]
     *   Start a new xschem process for a schematic.
     *   If 'f' is given load specified schematic. */
    else if(!strcmp(argv[1], "new_process"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        char f[PATH_MAX + 100];
        my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[2], home_dir);
        tcleval(f);
        my_strncpy(f, tclresult(), S(f));
        new_xschem_process(f, 0);
      } else new_xschem_process("", 0);
      Tcl_ResetResult(interp);
    }

    /* new_schematic create|destroy|destroy_all|switch win_path file [draw]
     *   Open/destroy a new tab or window
     *     create: create new empty window or with 'file' loaded if 'file' given.
     *             The win_path must be given (even {} is ok).
     *             '1' win_path ({1}) will avoid warnings if opening the
     *             same file multiple times.
     *     destroy: destroy tab/window identified by win_path. Example:
     *              xschem new_schematic destroy .x1.drw
     *     destroy_all: close all tabs/additional windows
     *              if the 'force'argument is given do not issue a warning if modified
     *              tabs are about to be closed.
     *     switch: switch context to specified 'win_path' window or specified schematic name
     *              If 'draw' is given and set to 0 do not redraw after switching tab
     *              (only tab i/f)
     *              if win_path set to "previous" switch to previous schematic.
     *   Main window/tab has win_path set to .drw,
     *   Additional windows/tabs have win_path set to .x1.drw, .x2.drw and so on...
     */
    else if(!strcmp(argv[1], "new_schematic"))
    {
      int r = -1;
      int dr = 1;
      char s[20];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {

        if(argc >= 6 ) dr = atoi(argv[5]);
        if(argc == 3) r = new_schematic(argv[2], NULL, NULL, 1);
        else if(argc == 4) r = new_schematic(argv[2], argv[3], NULL, 1);
        else if(argc >= 5) {
          char f[PATH_MAX + 100];
          my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[4], home_dir);
          tcleval(f);
          my_strncpy(f, abs_sym_path(tclresult(), ""), S(f));
          r = new_schematic(argv[2], argv[3], f, dr);
        }
        my_snprintf(s, S(s), "%d", r);
        Tcl_SetResult(interp, s, TCL_VOLATILE);
      }
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem o...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
/* Map a uniform-API type name ("wire"/"instance"/"rect"/"line"/"poly"/"arc"/
 * "text") to its internal type constant, or -1 if unknown. Used by the
 * `xschem object`/`objects` read API. */
static int object_type_from_name(const char *s)
{
  if(!strcmp(s, "wire"))     return WIRE;
  if(!strcmp(s, "instance")) return ELEMENT;
  if(!strcmp(s, "rect"))     return xRECT;
  if(!strcmp(s, "line"))     return LINE;
  if(!strcmp(s, "poly"))     return POLYGON;
  if(!strcmp(s, "arc"))      return ARC;
  if(!strcmp(s, "text"))     return xTEXT;
  return -1;
}

/* Build the uniform descriptor of one object into 'buf' as a BARE Tcl dict:
 *   type T index I layer C id ID name {N}
 * (no outer braces — the single-object `object` command returns this verbatim;
 * the `objects` list enumerator wraps each in {...} to make a list element.)
 * 'type' is one of WIRE/ELEMENT/xRECT/LINE/POLYGON/ARC/xTEXT; i is the array
 * index; c is the layer (the real per-layer layer for graphical types, the
 * fixed display layer otherwise, or the text's own .layer). id is the stable
 * id (-1 for text, which has none yet); name is the instance name (empty for
 * every other type). The id is held as int and printed %d so -1 renders
 * correctly, matching the `selection` enumerator. */
static void object_descriptor(char *buf, int bufsz, int type, int i, int c)
{
  const char *tname, *name = "";
  int id = -1;
  switch(type) {
    case WIRE:    tname = "wire";     id = (int)xctx->wire[i].id; break;
    case ELEMENT: tname = "instance"; id = (int)xctx->inst[i].id;
                  name = xctx->inst[i].instname ? xctx->inst[i].instname : ""; break;
    case xRECT:   tname = "rect";     id = (int)xctx->rect[c][i].id; break;
    case LINE:    tname = "line";     id = (int)xctx->line[c][i].id; break;
    case POLYGON: tname = "poly";     id = (int)xctx->poly[c][i].id; break;
    case ARC:     tname = "arc";      id = (int)xctx->arc[c][i].id;  break;
    case xTEXT:   tname = "text";     id = (int)xctx->text[i].id; break;
    default:      tname = "unknown";  break;
  }
  my_snprintf(buf, bufsz, "type %s index %d layer %d id %d name {%s}",
              tname, i, c, id, name);
}

static int xschem_cmds_o(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* object <type> <selector>
     *   return the uniform descriptor dict of ONE object, or "" if it does not
     *   resolve. <type> is wire|instance|rect|line|poly|arc|text. <selector> is
     *     @<id>            resolve by stable id (the durable handle)
     *     #<index>         resolve by array index (flat types: wire/instance/text)
     *     #<layer>,<index> resolve by per-layer position (rect/line/poly/arc)
     *     <name>           resolve by name (instance only)
     *   The dict is {type T index I layer C id ID name {N}}. Read-only.
     *   See `xschem objects` for the bulk enumerator. */
    if(!strcmp(argv[1], "object"))
    {
      int type, i = -1, c = WIRELAYER;
      const char *sel;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 4) {
        Tcl_SetResult(interp, "xschem object needs <type> <selector>", TCL_STATIC);
        return TCL_ERROR;
      }
      if((type = object_type_from_name(argv[2])) < 0) {
        Tcl_SetResult(interp, "xschem object: unknown type", TCL_STATIC);
        return TCL_ERROR;
      }
      sel = argv[3];
      if(sel[0] == '@') {                       /* by stable id */
        unsigned int id = (unsigned int)strtoul(sel + 1, NULL, 10);
        switch(type) {
          case WIRE:    i = wire_index_from_id(id); c = WIRELAYER; break;
          case ELEMENT: i = inst_index_from_id(id); c = WIRELAYER; break;
          case xRECT: case LINE: case POLYGON: case ARC:
                        i = gfx_index_from_id(type, id, &c); break;
          case xTEXT:   i = text_index_from_id(id);
                        if(i >= 0) c = xctx->text[i].layer; break;
        }
      } else if(sel[0] == '#') {                /* by index or layer,index */
        const char *comma = strchr(sel + 1, ',');
        if(comma) { c = atoi(sel + 1); i = atoi(comma + 1); }
        else      { i = atoi(sel + 1); }
        /* range-check and fix up the layer for flat types */
        switch(type) {
          case WIRE:    if(i < 0 || i >= xctx->wires) i = -1; c = WIRELAYER; break;
          case ELEMENT: if(i < 0 || i >= xctx->instances) i = -1; c = WIRELAYER; break;
          case xTEXT:   if(i < 0 || i >= xctx->texts) i = -1;
                        else c = xctx->text[i].layer; break;
          case xRECT:   if(c < 0 || c >= cadlayers || i < 0 || i >= xctx->rects[c]) i = -1; break;
          case LINE:    if(c < 0 || c >= cadlayers || i < 0 || i >= xctx->lines[c]) i = -1; break;
          case POLYGON: if(c < 0 || c >= cadlayers || i < 0 || i >= xctx->polygons[c]) i = -1; break;
          case ARC:     if(c < 0 || c >= cadlayers || i < 0 || i >= xctx->arcs[c]) i = -1; break;
        }
      } else {                                  /* by name (instance only) */
        if(type == ELEMENT) { i = get_instance(sel); c = WIRELAYER; }
        else i = -1;
      }
      if(i >= 0) {
        char row[256];
        object_descriptor(row, S(row), type, i, c);
        Tcl_SetResult(interp, row, TCL_VOLATILE);
      }
      /* else: leave the result empty — a dangling/unknown reference */
    }

    /* object_at <x> <y>
     *   The object closest to schematic coordinate (x,y) as one BARE `type index col id`
     *   row -- byte-identical to what `xschem select_at <x> <y>` returns -- or "" on a
     *   miss. READ-ONLY: it selects nothing, draws nothing and logs nothing. This is the
     *   probe half of a click: the same pairing `instance_at` is to the instance pick
     *   (issue 0200), generalised to all seven drawable types.
     *   doc/claude/issues/0204-sod-pick-mutates-the-selection.md
     *
     *   Identical classification to select_at, on purpose: same find_closest_obj cascade,
     *   same override_lock=0 (so a lock=true object still reads as a miss here, and every
     *   locked-object contract issue 0160 pinned stays exactly where it is).
     *
     *   `col` is reconstructed rather than read from sel_array, which a probe has no
     *   business rebuilding: rebuild_selected_array (move.c) stores WIRELAYER for wires
     *   and instances and TEXTLAYER for texts, and the per-layer types already carry
     *   their own layer out of find_closest_obj. So the row matches an `xschem selection`
     *   row field for field without a selection ever existing. */
    else if(!strcmp(argv[1], "object_at"))
    {
      Selected s;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 4) {
        Tcl_SetResult(interp, "xschem object_at: x and y required", TCL_STATIC);
        return TCL_ERROR;
      }
      s = find_closest_obj(atof(argv[2]), atof(argv[3]), 0);
      /* load-bearing: find_closest_text() expands floater text (get_text_floater ->
       * translate), which evaluates Tcl and can leave a result behind. */
      Tcl_ResetResult(interp);
      if(s.type) {
        const char *tname;
        int id = -1, n = s.n, c = (int)s.col;
        char row[100];
        switch(s.type) {
          case WIRE:    tname = "wire";     c = WIRELAYER; id = (int)xctx->wire[n].id; break;
          case ELEMENT: tname = "instance"; c = WIRELAYER; id = (int)xctx->inst[n].id; break;
          case xTEXT:   tname = "text";     c = TEXTLAYER; id = (int)xctx->text[n].id; break;
          case xRECT:   tname = "rect";     id = (int)xctx->rect[c][n].id; break;
          case LINE:    tname = "line";     id = (int)xctx->line[c][n].id; break;
          case POLYGON: tname = "poly";     id = (int)xctx->poly[c][n].id; break;
          case ARC:     tname = "arc";      id = (int)xctx->arc[c][n].id; break;
          default:      tname = "unknown";  break;
        }
        my_snprintf(row, S(row), "%s %d %d %d", tname, n, c, id);
        Tcl_SetResult(interp, row, TCL_VOLATILE);
      }
    }

    /* objects [-type T] [-selected] [-layer L]
     *   return a Tcl LIST of uniform descriptor dicts, one per object, across
     *   all seven drawable types (wire, instance, text, rect, line, poly, arc).
     *   Filters (combinable):
     *     -type T      only objects of type T (a type name as in `object`)
     *     -selected    only currently-selected objects
     *     -layer L     only objects whose reported layer == L
     *   Each element is {type T index I layer C id ID name {N}}. Read-only. */
    else if(!strcmp(argv[1], "objects"))
    {
      int filt_type = -1, filt_layer = -1, only_sel = 0;
      int a, c, i, first = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(a = 2; a < argc; a++) {
        if(!strcmp(argv[a], "-type") && a + 1 < argc) {
          filt_type = object_type_from_name(argv[++a]);
          if(filt_type < 0) { Tcl_SetResult(interp, "xschem objects -type: unknown type", TCL_STATIC); return TCL_ERROR; }
        }
        else if(!strcmp(argv[a], "-layer") && a + 1 < argc) filt_layer = atoi(argv[++a]);
        else if(!strcmp(argv[a], "-selected")) only_sel = 1;
      }
      #define OBJ_EMIT(TYPE, IDX, LAY) do { \
          char row[256]; \
          object_descriptor(row, S(row), (TYPE), (IDX), (LAY)); \
          if(!first) Tcl_AppendResult(interp, " ", NULL); \
          Tcl_AppendResult(interp, "{", row, "}", NULL); first = 0; \
        } while(0)
      /* flat types: wire, instance, text */
      if(filt_type == -1 || filt_type == WIRE)
        for(i = 0; i < xctx->wires; i++) {
          if(only_sel && xctx->wire[i].sel != SELECTED) continue;
          if(filt_layer != -1 && filt_layer != WIRELAYER) continue;
          OBJ_EMIT(WIRE, i, WIRELAYER);
        }
      if(filt_type == -1 || filt_type == ELEMENT)
        for(i = 0; i < xctx->instances; i++) {
          if(only_sel && xctx->inst[i].sel != SELECTED) continue;
          if(filt_layer != -1 && filt_layer != WIRELAYER) continue;
          OBJ_EMIT(ELEMENT, i, WIRELAYER);
        }
      if(filt_type == -1 || filt_type == xTEXT)
        for(i = 0; i < xctx->texts; i++) {
          if(only_sel && xctx->text[i].sel != SELECTED) continue;
          if(filt_layer != -1 && filt_layer != xctx->text[i].layer) continue;
          OBJ_EMIT(xTEXT, i, xctx->text[i].layer);
        }
      /* per-layer graphical types */
      for(c = 0; c < cadlayers; c++) {
        if(filt_layer != -1 && filt_layer != c) continue;
        if(filt_type == -1 || filt_type == xRECT)
          for(i = 0; i < xctx->rects[c]; i++) {
            if(only_sel && xctx->rect[c][i].sel != SELECTED) continue;
            OBJ_EMIT(xRECT, i, c);
          }
        if(filt_type == -1 || filt_type == LINE)
          for(i = 0; i < xctx->lines[c]; i++) {
            if(only_sel && xctx->line[c][i].sel != SELECTED) continue;
            OBJ_EMIT(LINE, i, c);
          }
        if(filt_type == -1 || filt_type == POLYGON)
          for(i = 0; i < xctx->polygons[c]; i++) {
            if(only_sel && xctx->poly[c][i].sel != SELECTED) continue;
            OBJ_EMIT(POLYGON, i, c);
          }
        if(filt_type == -1 || filt_type == ARC)
          for(i = 0; i < xctx->arcs[c]; i++) {
            if(only_sel && xctx->arc[c][i].sel != SELECTED) continue;
            OBJ_EMIT(ARC, i, c);
          }
      }
      #undef OBJ_EMIT
    }

    /* only_probes
     * dim schematic to better show highlights */
    else if(!strcmp(argv[1], "only_probes"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      xctx->only_probes = !xctx->only_probes;
      tclsetboolvar("only_probes", xctx->only_probes);
      toggle_only_probes();
      Tcl_ResetResult(interp);
    }

    /* origin x y [zoom]
     *   Move origin to 'x, y', optionally changing zoom level to 'zoom'
     *   A dash ('-') given for x or y will keep existing value */
    else if(!strcmp(argv[1], "origin"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
        if(strcmp(argv[2], "-")) xctx->xorigin = atof(argv[2]);
        if(strcmp(argv[3], "-")) xctx->yorigin = atof(argv[3]);
        if(argc > 4) {
          xctx->zoom = atof(argv[4]);
          xctx->mooz=1/xctx->zoom;
        }
        draw();
      }
      Tcl_ResetResult(interp);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem p...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_p(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* pan up|down|left|right
     *   Pan the viewport half a step in the given direction (the wheel-pan
     *   action; full-step arrow scrolling is `xschem scroll`).
     * pan dx dy
     *   Shift the view origin by (dx, dy) schematic units -- the replay form
     *   of a middle-button drag-pan recorded in the action log (Phase 3). */
    if(!strcmp(argv[1], "pan"))
    {
      char *end1, *end2;
      double dx, dy;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3 &&
         (dx = strtod(argv[2], &end1), dy = strtod(argv[3], &end2),
          end1 != argv[2] && end2 != argv[3])) {
        xctx->xorigin += dx;
        xctx->yorigin += dy;
        draw();
        redraw_w_a_l_r_p_z_rubbers(1);
      } else if(argc < 3 || !view_pan_dir(argv[2])) {
        Tcl_SetResult(interp, "xschem pan: expected up|down|left|right or dx dy", TCL_STATIC);
        return TCL_ERROR;
      }
      Tcl_ResetResult(interp);
    }

    /* parse_cmd
     *   debug command to test parse_cmd_string()
     *   splits a command string into argv-like arguments
     *   return # of args in *argc
     *   argv[*argc] is always set to NULL */
    else if(!strcmp(argv[1], "parse_cmd"))
    {
      if(argc > 2) {
        int c, i;
        char **av;
        av = parse_cmd_string(argv[2], &c);
        for(i = 0; i < c; ++i) {
          dbg(0, "--> %s\n", av[i]);
        }
      }
    }

    /* parselabel str
     *   Debug command to test vector net syntax parser */
    else if(!strcmp(argv[1], "parselabel"))
    {
      if(argc > 2) {
        parse(argv[2]);
      }
    }

    /* paste [x y [rot flip [local]] [-anchor ax ay] [-file {f}]]
     *   Paste clipboard. If 'x y' not given user should complete placement in the GUI.
     *   With 'x y' this is the action-log REPLAY form of a paste/merge drop (issue
     *   0069): it completes an already-pending STARTMERGE at delta x y, or, with none
     *   pending, merges the clipboard (default) / file 'f' (-file) first. 'rot flip'
     *   replay a mid-gesture rotate/flip ('local' = per-object pivot, in-place
     *   variant); '-anchor ax ay' pins the shared rotation pivot (the clipboard's G
     *   record is regenerated by a replayed `xschem copy`, so the pivot must ride the
     *   line -- see end_move_copy_logged). Calls merge_file + move_objects(END)
     *   directly -- never the gesture funnel (end_move_copy_logged) -- so a replayed
     *   line never re-logs (coordinate-form-bypass invariant); do NOT add a
     *   log_action here. */
    else if(!strcmp(argv[1], "paste"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "paste")) return TCL_ERROR;
      if(argc > 3) {
        char f[PATH_MAX + 100];
        const char *mfile = NULL;
        int k = 4, rot = 0, flip = 0, rotl = 0, has_anchor = 0;
        double ax = 0.0, ay = 0.0;
        if(argc > 5 && argv[4][0] != '-' && argv[5][0] != '-') {
          rot = atoi(argv[4]) & 0x3;
          flip = atoi(argv[5]) & 0x1;
          k = 6;
          if(argc > k && !strcmp(argv[k], "local")) { rotl = 1; k++; }
        }
        for(; k < argc; k++) {
          if(!strcmp(argv[k], "-anchor") && k + 2 < argc) {
            ax = atof(argv[k + 1]); ay = atof(argv[k + 2]);
            has_anchor = 1; k += 2;
          }
          else if(!strcmp(argv[k], "-file") && k + 1 < argc) {
            mfile = argv[k + 1]; k++;
          }
        }
        if(!(xctx->ui_state & STARTMERGE)) {
          if(mfile) {
            /* logged -file names are already resolved (merge_file stashes what it
             * opened); expand ~/ only for hand-written lines, so a brace-y absolute
             * path never goes through tcleval */
            if(mfile[0] == '~' && mfile[1] == '/') {
              my_snprintf(f, S(f), "%s/%s", home_dir, mfile + 2);
            } else {
              my_strncpy(f, mfile, S(f));
            }
            merge_file(8, f); /* named file; bit 3 avoids move_objects(RUBBER,...) */
          } else {
            merge_file(10, ".sch"); /* set bit 3 to avoid doing move_objects(RUBBER,...) */
          }
        }
        /* a failed merge (missing clipboard/file) sets no STARTMERGE: skip the END,
         * or it would translate whatever selection happens to exist by the delta */
        if(xctx->ui_state & STARTMERGE) {
          xctx->deltax = atof(argv[2]);
          xctx->deltay = atof(argv[3]);
          xctx->move_rot = (short)rot;
          xctx->move_flip = (short)flip;
          /* unconditional: the line is the FULL transform record -- a pending
           * gesture's interactive rotatelocal must not leak into a no-local line */
          xctx->rotatelocal = (short)rotl;
          if(has_anchor) { xctx->x1 = ax; xctx->y1 = ay; }
          move_objects(END, 0, 0.0, 0.0);
        }
      } else {
        merge_file(2, ".sch");
      }
      Tcl_ResetResult(interp);
    }

    /* pin_escape_normal inst attr value
     *   Return the outward escape normal (a unit axis vector "nx ny") of the pin whose
     *   attribute 'attr' equals 'value' on instance 'inst' (nice_drag_rerouting §6,
     *   geometry-only). Example: xschem pin_escape_normal m1 name d --> 0 -1
     *   Empty string if the instance or pin is not found. */
    else if(!strcmp(argv[1], "pin_escape_normal"))
    {
      xSymbol *symbol;
      xRect *rct;
      double nx, ny;
      char num[60];
      int p, i, no_of_pins;
      const char *pin;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 5) {
        Tcl_SetResult(interp,
          "xschem pin_escape_normal requires an instance, a pin attribute and a value", TCL_STATIC);
        return TCL_ERROR;
      }
      i = get_instance(argv[2]);
      if(i < 0) { Tcl_SetResult(interp, "", TCL_STATIC); return TCL_OK; }
      symbol = xctx->sym + xctx->inst[i].ptr;
      no_of_pins = symbol->rects[PINLAYER];
      rct = symbol->rect[PINLAYER];
      for(p = 0; p < no_of_pins; p++) {
        pin = get_tok_value(rct[p].prop_ptr, argv[3], 0);
        if(!strcmp(pin, argv[4])) break;
      }
      if(p >= no_of_pins) { Tcl_SetResult(interp, "", TCL_STATIC); return TCL_OK; }
      get_pin_escape_normal(i, p, &nx, &ny);
      my_snprintf(num, S(num), "%g %g", nx, ny);
      Tcl_SetResult(interp, num, TCL_VOLATILE);
    }

    /* pinlist inst [attr]
     *   List all pins of instance 'inst'
     *   if no 'attr' is given return full attribute string,
     *   else return value for attribute 'attr'.
     *   Example: xschem pinlist x3 name
     *   -->  { {0} {PLUS} } { {1} {OUT} } { {2} {MINUS} }
     *   Example: xschem pinlist x3 dir
     *   -->  { {0} {in} } { {1} {out} } { {2} {in} }
     *   Example: xschem pinlist x3
     *   --> { {0} {name=PLUS dir=in } } { {1} {name=OUT dir=out } }
     *       { {2} {name=MINUS dir=in } }
     */
    /* pin_names [on|off|auto|cycle]
     *   P5 global pin-name visibility tri-state (doc/claude/specs/cadence_pin_name_text.md
     *   §4.8). Sets the show_pin_names Tcl var (on=force-show all owned pins, off=force-hide,
     *   auto=defer to each pin's show_pinname), reconciles the symbol's name views and
     *   redraws. "cycle" advances auto->on->off->auto. With no arg just returns the
     *   current mode. Pure view op: no undo, no modify. */
    else if(!strcmp(argv[1], "pin_names"))
    {
      const char *cur;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      cur = tclgetvar("show_pin_names");
      if(!cur || (strcmp(cur, "on") && strcmp(cur, "off") && strcmp(cur, "auto"))) {
        cur = "auto";
        tclsetvar("show_pin_names", cur);   /* normalize an unset/bogus value so the var,
                                             * the menu radios and pin_name_shown() agree */
      }
      if(argc > 2) {
        const char *mode = argv[2];
        if(!strcmp(mode, "cycle"))
          mode = !strcmp(cur, "auto") ? "on" : !strcmp(cur, "on") ? "off" : "auto";
        if(strcmp(mode, "on") && strcmp(mode, "off") && strcmp(mode, "auto")) {
          Tcl_SetResult(interp, "xschem pin_names: expected on|off|auto|cycle", TCL_STATIC);
          return TCL_ERROR;
        }
        if(strcmp(mode, cur)) {             /* only reconcile+redraw on an actual change */
          tclsetvar("show_pin_names", mode);
          pin_names_sync_cache();           /* keep the cache correct even in schematic mode,
                                             * where reconcile_all early-returns (symbol-only) */
          pin_views_reconcile_all();
          draw();
          cur = mode;
        }
      }
      Tcl_SetResult(interp, (char *)cur, TCL_VOLATILE);
    }

    /* pin_scope_prop_uniform <scope> <token>
     *   Returns "1" if <token>'s value is identical across every pin in <scope>
     *   (current|selected|all), else "0". An empty or single-pin scope is "1" (uniform by
     *   construction). Drives the pin form's Name-greying rule: the Name entry is disabled iff
     *   NOT uniform (a >1-pin scope with differing names), editable otherwise
     *   (symbol_editor_apply_scope.md §4.2/§5.3). Uses the same pin_scope_targets() resolver as
     *   apply_pin_prop so the decision matches what an Apply would touch. Read-only. */
    else if(!strcmp(argv[1], "pin_scope_prop_uniform"))
    {
      int i, n, ntargets, primary = -1, uniform = 1;
      int *targets;
      const char *scope, *tok, *val;
      char *first = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 4) {
        Tcl_SetResult(interp, "xschem pin_scope_prop_uniform needs: scope token", TCL_STATIC);
        return TCL_ERROR;
      }
      scope = argv[2]; tok = argv[3];
      ntargets = pin_scope_resolve(scope, &primary, &targets);
      for(i = 0; i < ntargets; i++) {
        n = targets[i];
        val = get_tok_value(xctx->rect[PINLAYER][n].prop_ptr, tok, 0);
        if(i == 0) my_strdup(_ALLOC_ID_, &first, val);   /* copy: get_tok_value's buffer is reused */
        else if(!first || strcmp(first, val)) { uniform = 0; break; }
      }
      if(first) my_free(_ALLOC_ID_, &first);
      my_free(_ALLOC_ID_, &targets);
      Tcl_SetResult(interp, uniform ? "1" : "0", TCL_STATIC);
    }

    /* pin_stub_geom: (xschem pin_stub_geom inst pin stublen) "x1 y1 x2 y2 dx dy" -- the stub
     * segment for that instance pin extended outward by stublen: start = pin abs coord, end =
     * start + outward*stublen, (dx dy) = the absolute outward unit direction. B4, §4.3. */
    else if(!strcmp(argv[1], "pin_stub_geom"))
    {
      Pin_stub_geom g;
      char b[160];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc <= 4) {
        Tcl_SetResult(interp, "xschem pin_stub_geom: give an instance index, pin index and stub length", TCL_STATIC);
        return TCL_ERROR;
      }
      if(compute_pin_stub_geom(atoi(argv[2]), atoi(argv[3]), atof(argv[4]), &g)) {
        my_snprintf(b, S(b), "%g %g %g %g %g %g", g.x1, g.y1, g.x2, g.y2, g.dx, g.dy);
        Tcl_SetResult(interp, b, TCL_VOLATILE);
      } else {
        Tcl_SetResult(interp, "", TCL_STATIC);
      }
    }
    /* pin_stub_sizing: (xschem pin_stub_sizing) "size textheight stublen" the wire-stubber would
     * use for the current selection's targets -- median pin-name size, label line height, and the
     * grid-snapped stub length (>2*height). Empty when nothing is selected. B3, §4.2. */
    else if(!strcmp(argv[1], "pin_stub_sizing"))
    {
      Pin_stub_target *t = NULL;
      Pin_stub_sizing sz;
      int nt;
      char b[96];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      nt = collect_pin_stub_targets(&t);
      if(nt > 0 && compute_pin_stub_sizing(t, nt, &sz)) {
        my_snprintf(b, S(b), "%g %g %g", sz.size, sz.text_h, sz.stub_len);
        Tcl_SetResult(interp, b, TCL_VOLATILE);
      } else {
        Tcl_SetResult(interp, "", TCL_STATIC);
      }
      if(t) my_free(_ALLOC_ID_, &t);
    }
    /* pin_stub_targets: (xschem pin_stub_targets) the (instance, pin) pairs the wire-stubber
     * would process for the current selection, as a Tcl list of {inst pin} pairs -- selected
     * pins win, else a whole instance's not-already-wired pins. B2, wire_stub_netlabel.md §4.1.
     * Read-only dry-run of the selection scan (the mutating `add_pin_stubs` lands at B6). */
    else if(!strcmp(argv[1], "pin_stub_targets"))
    {
      Pin_stub_target *t = NULL;
      int nt, k;
      char *res = NULL;
      char b[64];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      nt = collect_pin_stub_targets(&t);
      for(k = 0; k < nt; ++k) {
        my_snprintf(b, S(b), "%s{%d %d}", k ? " " : "", t[k].inst, t[k].pin);
        my_mstrcat(_ALLOC_ID_, &res, b, NULL);
      }
      if(t) my_free(_ALLOC_ID_, &t);
      Tcl_SetResult(interp, res ? res : "", TCL_VOLATILE);
      my_free(_ALLOC_ID_, &res);
    }

    else if(!strcmp(argv[1], "pinlist"))
    {
      int i, p, no_of_pins, first = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        if((i = get_instance(argv[2])) < 0 ) {
          Tcl_SetResult(interp, "xschem pinlist: instance not found", TCL_STATIC);
          return TCL_ERROR;
        }
        no_of_pins= (xctx->inst[i].ptr+ xctx->sym)->rects[PINLAYER];
        for(p=0;p<no_of_pins;p++) {
          if(first == 0) Tcl_AppendResult(interp, " ", NULL);
          if(argc > 3 && argv[3][0]) {
            Tcl_AppendResult(interp, "{ {", my_itoa(p), "} {",
              get_tok_value(xctx->sym[xctx->inst[i].ptr].rect[PINLAYER][p].prop_ptr, argv[3], 0),
              "} }", NULL);
          } else {
            Tcl_AppendResult(interp, "{ {", my_itoa(p), "} {",
               (xctx->inst[i].ptr+ xctx->sym)->rect[PINLAYER][p].prop_ptr, "} }", NULL);
          }
          first = 0;
        }
      }
    }

    /* place_symbol [sym_name] [prop]
     *   Start a GUI placement operation of specified 'sym_name' symbol.
     *   If 'sym_name' not given prompt user
     *   'prop' is the attribute string of the symbol.
     *   If not given take from symbol template attribute.
     */
    else if(!strcmp(argv[1], "place_symbol"))
    {
      int ret;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "place_symbol")) return TCL_ERROR;
      xctx->semaphore++;
      rebuild_selected_array();
      if(xctx->lastsel && xctx->sel_array[0].type==ELEMENT) {
        tclvareval("set INITIALINSTDIR [file dirname {",
             abs_sym_path(tcl_hook2(xctx->inst[xctx->sel_array[0].n].name), ""), "}]", NULL);
      }
      xctx->mx_double_save = xctx->mousex_snap;
      xctx->my_double_save = xctx->mousey_snap;
      if(argc > 3) {
        /*               pos  name     x                  y               rot flip prop   draw first to_push_undo */
        ret = place_symbol(-1,argv[2],xctx->mousex_snap, xctx->mousey_snap, 0, 0,  argv[3], 4,   1,    1);
      } else if(argc > 2) {
        ret = place_symbol(-1,argv[2],xctx->mousex_snap, xctx->mousey_snap, 0, 0,  NULL,    4,   1,    1);
      } else {
        xctx->last_command = 0;
        ret = place_symbol(-1,NULL,   xctx->mousex_snap, xctx->mousey_snap, 0, 0,  NULL,    4,   1,    1);
      }
      if(ret) {
        xctx->mousey_snap = xctx->my_double_save;
        xctx->mousex_snap = xctx->mx_double_save;
        move_objects(START,0,0,0);
        xctx->ui_state |= PLACE_SYMBOL;
      }
      xctx->semaphore--;
      Tcl_ResetResult(interp);
    }

    /* place_text
     *   Start a GUI placement of a text object */
    else if(!strcmp(argv[1], "place_text"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      xctx->semaphore++;
      xctx->last_command = 0;
      unselect_all(1);
      xctx->mx_double_save = xctx->mousex_snap;
      xctx->my_double_save = xctx->mousey_snap;
      if(place_text(0, xctx->mousex_snap, xctx->mousey_snap)) { /* 1 = draw text 24122002 */
        xctx->mousey_snap = xctx->my_double_save;
        xctx->mousex_snap = xctx->mx_double_save;
        move_objects(START,0,0,0);
        xctx->ui_state |= PLACE_TEXT;
      }
      xctx->semaphore--;
      Tcl_ResetResult(interp);
    }

    /* polygon x1 y1 x2 y2 x3 y3 ... [prop]
     *   Place a polygon with the given points on the current layer
     *   (rectcolor); an odd trailing argument is the attribute string.
     *   This is the replay form of a drawn polygon in the action log
     *   (Phase 3 slice B). Coordinates are stored as given -- pass the first
     *   point again as the last to close the polygon.
     * polygon [gui]
     *   Start a GUI placement of a polygon
     *   if `gui` argument is given start a polygon GUI placement with 1st point
     *   set to current mouse coordinates */
    /* poly_id layer index
     *   session-stable id of the polygon at (layer, index), or -1 if out of
     *   range. Shared graphical id space; resolve back with `poly_index id` */
    else if(!strcmp(argv[1], "poly_id"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
        int c = atoi(argv[2]), n = atoi(argv[3]);
        if(c >= 0 && c < cadlayers && n >= 0 && n < xctx->polygons[c]) {
          char s[30];
          my_snprintf(s, S(s), "%u", xctx->poly[c][n].id);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        } else {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        }
      }
    }
    /* poly_index id
     *   current "{layer index}" of the polygon with that id, or -1 if none */
    else if(!strcmp(argv[1], "poly_index"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        unsigned int id = (unsigned int)strtoul(argv[2], NULL, 10);
        int layer, idx = gfx_index_from_id(POLYGON, id, &layer);
        if(idx < 0) {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        } else {
          char s[40];
          my_snprintf(s, S(s), "%d %d", layer, idx);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        }
      }
    }
    else if(!strcmp(argv[1], "polygon"))
    {
      char *endp;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "polygon")) return TCL_ERROR;
      if(argc > 7 && (strtod(argv[2], &endp), endp != argv[2])) {
        int i, points = 0, save;
        const char *prop = NULL;
        double *px, *py;
        for(i = 2; i + 1 < argc; i += 2) {     /* count leading coordinate pairs */
          strtod(argv[i], &endp);
          if(endp == argv[i]) break;
          points++;
        }
        if(i < argc) prop = argv[i];           /* odd trailing arg = attributes */
        if(points < 3) {
          Tcl_SetResult(interp, "xschem polygon: need at least 3 x y points", TCL_STATIC);
          return TCL_ERROR;
        }
        px = my_malloc(_ALLOC_ID_, points * sizeof(double));
        py = my_malloc(_ALLOC_ID_, points * sizeof(double));
        for(i = 0; i < points; ++i) {
          px[i] = atof(argv[2 + 2*i]);
          py[i] = atof(argv[3 + 2*i]);
        }
        store_poly(-1, px, py, points, xctx->rectcolor, 0, (char *)prop);
        save = xctx->draw_window; xctx->draw_window = 1;
        drawpolygon(xctx->rectcolor, NOW, px, py, points, 0, 0, 0.0, 0);
        xctx->draw_window = save;
        my_free(_ALLOC_ID_, &px);
        my_free(_ALLOC_ID_, &py);
        set_modify(1);
        Tcl_ResetResult(interp);
      }
      else if(argc > 2 && !strcmp(argv[2], "gui")) {
        int infix_interface = tclgetboolvar("infix_interface");
        if(infix_interface) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          xctx->last_command = 0;
          new_polygon(PLACE, xctx->mousex_snap, xctx->mousey_snap);
        } else {
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTPOLYGON;
        }
      } else {
        xctx->ui_state |= MENUSTART;
        xctx->ui_state2 = MENUSTARTPOLYGON;
      }
    }

    /* preview_window create|draw|destroy|close [win_path] [file]
     *   destroy: will delete preview schematic data and destroy container window
     *   close: same as destroy but leave the container window.
     *   Used in fileselector to show a schematic preview.
     */
    else if(!strcmp(argv[1], "preview_window"))
    {
      int res = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc == 3) res = preview_window(argv[2], "", NULL);
      else if(argc == 4) res = preview_window(argv[2], argv[3], NULL);
      else if(argc == 5) {
        char f[PATH_MAX + 100];
        my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[4], home_dir);
        tcleval(f);
        my_strncpy(f, tclresult(), S(f));
        res = preview_window(argv[2], argv[3], f);
      }
      Tcl_SetResult(interp, my_itoa(res), TCL_VOLATILE);
    }


    /* print png|svg|ps|pdf|ps_full|pdf_full img_file [img_x img_y] [x1 y1 x2 y2]
     *   If img_x and img_y are set to 0 (recommended for svg and ps/pdf)
     *   they will be calculated by xschem automatically
     *   if img_x and img_y are given they will set the bitmap size, if
     *   area to export is not given then use the selection boundbox if
     *   a selection exists or do a full zoom.
     *   Export current schematic to image.
     *                            img x   y size    xschem area to export
     *      0     1    2    3         4   5             6    7   8   9
     *   xschem print png file.png  [400 300]       [ -300 -200 300 200 ]
     *   xschem print svg file.svg  [400 300]       [ -300 -200 300 200 ]
     *   xschem print ps  file.ps   [400 300]       [ -300 -200 300 200 ]
     *   xschem print eps file.eps  [400 300]       [ -300 -200 300 200 ]
     *   xschem print pdf file.pdf  [400 300]       [ -300 -200 300 200 ]
     *   xschem print ps_full  file.ps
     *   xschem print pdf_full file.pdf
     */
    else if(!strcmp(argv[1], "print") )
    {
      Zoom_info zi;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem print needs at least 1 more arguments: plot_type", TCL_STATIC);
        return TCL_ERROR;
      }
      /* P6: the svg/ps export paths (svg_draw_symbol/ps_draw_symbol) don't go through draw(),
       * so refresh the pin-name visibility cache here (png uses the screen draw() path). */
      pin_names_sync_cache();
      if(argc > 3) {
        tclvareval("file normalize {", argv[3], "}", NULL);
        my_strncpy(xctx->plotfile, Tcl_GetStringResult(interp), S(xctx->plotfile));
      }
      if(!strcmp(argv[2], "pdf") || !strcmp(argv[2],"ps") || !strcmp(argv[2],"eps")) {
        double save_lw = xctx->lw;
        int fullzoom = 0;
        int w = 0, h = 0;
        int eps = 0;
        double x1 = 0., y1 = 0., x2 = 0., y2 = 0.;

        if(!strcmp(argv[2],"eps")) eps = 1;
        if(eps && xctx->lastsel == 0) {
          if(has_x) tcleval("alert_ {EPS export works only on a selection} {}");
          else  dbg(0, "EPS export works only on a selection\n");
        } else if(argc == 6 && eps == 0) {
          if(xctx->lastsel) {
            xRect boundbox;
            calc_drawing_bbox(&boundbox, 1);
            x1 =boundbox.x1;
            y1 =boundbox.y1;
            x2 =boundbox.x2;
            y2 =boundbox.y2;
          } else {
            fullzoom = 2; /* 2: set paper size to bounding box instead of a4/letter */
          }
          w = atoi(argv[4]);
          h = atoi(argv[5]);
          if(w == 0) w = xctx->xrect[0].width;
          if(h == 0) h = xctx->xrect[0].height;
          save_restore_zoom(1, &zi);
          set_viewport_size(w, h, xctx->lw);
          if(xctx->lastsel) {
            zoom_box(x1, y1, x2, y2, 1.0);
            unselect_all(0);
          }
          else zoom_full(0, 0, 2 * tclgetboolvar("zoom_full_center"), 0.97);
          resetwin(1, 1, 1, w, h);
          ps_draw(7, fullzoom, eps);
          save_restore_zoom(0, &zi);
          resetwin(1, 1, 1, xctx->xrect[0].width, xctx->xrect[0].height);
          change_linewidth(save_lw);
        } else if(argc == 10 || xctx->lastsel) {
          if(xctx->lastsel) {
            xRect boundbox;
            calc_drawing_bbox(&boundbox, 1);
            unselect_all(0);
            x1 =boundbox.x1;
            y1 =boundbox.y1;
            x2 =boundbox.x2;
            y2 =boundbox.y2;
            w = (int) fabs(x2 - x1);
            h = (int) fabs(y2 - y1);
          } else {
            w = atoi(argv[4]);
            h = atoi(argv[5]);
            x1 = atof(argv[6]);
            y1 = atof(argv[7]);
            x2 = atof(argv[8]);
            y2 = atof(argv[9]);
          }
          fullzoom = 2;
          if(w == 0) w = (int) fabs(x2 - x1);
          if(h == 0) h = (int) fabs(y2 - y1);
          save_restore_zoom(1, &zi);
          set_viewport_size(w, h, xctx->lw);
          zoom_box(x1, y1, x2, y2, 1.0);
          resetwin(1, 1, 1, w, h);
          ps_draw(7, fullzoom, eps);
          save_restore_zoom(0, &zi);
          resetwin(1, 1, 1, xctx->xrect[0].width, xctx->xrect[0].height);
          change_linewidth(save_lw);
        } else {
          fullzoom = 0;
          ps_draw(7, fullzoom, eps);
        }
      }
      else if(!strcmp(argv[2], "pdf_full") || !strcmp(argv[2],"ps_full")) {
        int fullzoom = 1;
        ps_draw(7, fullzoom, 0);
      }
      else if(!strcmp(argv[2], "png")) {
        double save_lw = xctx->lw;
        int w = 0, h = 0;
        double x1 = 0., y1 = 0., x2 = 0., y2 = 0.;
        if(argc == 6) {
          if(xctx->lastsel) {
            xRect boundbox;
            calc_drawing_bbox(&boundbox, 1);
            x1 =boundbox.x1;
            y1 =boundbox.y1;
            x2 =boundbox.x2;
            y2 =boundbox.y2;
          }
          w = atoi(argv[4]);
          h = atoi(argv[5]);
          if(w == 0) w = xctx->xrect[0].width;
          if(h == 0) h = xctx->xrect[0].height;
          save_restore_zoom(1, &zi);
          set_viewport_size(w, h, xctx->lw);
          if(xctx->lastsel) {
            zoom_box(x1, y1, x2, y2, 1.0);
            unselect_all(0);
          }
          else zoom_full(0, 0, 2 * tclgetboolvar("zoom_full_center"), 0.97);
          resetwin(1, 1, 1, w, h);
          print_image();
          save_restore_zoom(0, &zi);
          resetwin(1, 1, 1, xctx->xrect[0].width, xctx->xrect[0].height);
          change_linewidth(save_lw);
        } else if(argc == 10 || xctx->lastsel) {
          if(xctx->lastsel) {
            xRect boundbox;
            calc_drawing_bbox(&boundbox, 1);
            unselect_all(0);
            x1 =boundbox.x1;
            y1 =boundbox.y1;
            x2 =boundbox.x2;
            y2 =boundbox.y2;
            w = (int) fabs(x2 - x1);
            h = (int) fabs(y2 - y1);
          } else {
            w = atoi(argv[4]);
            h = atoi(argv[5]);
            x1 = atof(argv[6]);
            y1 = atof(argv[7]);
            x2 = atof(argv[8]);
            y2 = atof(argv[9]);
          }
          if(w == 0) w = (int) fabs(x2 - x1);
          if(h == 0) h = (int) fabs(y2 - y1);
          dbg(1, "w=%d h=%d, lw=%g bbox=%g %g %g %g\n", w, h, xctx->lw, x1, y1, x2, y2);
          save_restore_zoom(1, &zi);
          set_viewport_size(w, h, xctx->lw);
          zoom_box(x1, y1, x2, y2, 1.0);
          resetwin(1, 1, 1, w, h);
          print_image();
          save_restore_zoom(0, &zi);
          resetwin(1, 1, 1, xctx->xrect[0].width, xctx->xrect[0].height);
          change_linewidth(save_lw);
        } else {
          print_image();
        }
      }
      else if(!strcmp(argv[2], "svg")) {
        double save_lw = xctx->lw;
        int w = 0, h = 0;
        double x1 = 0., y1 = 0., x2 = 0., y2 = 0.;
        if(argc == 6) {
          if(xctx->lastsel) {
            xRect boundbox;
            calc_drawing_bbox(&boundbox, 1);
            x1 =boundbox.x1;
            y1 =boundbox.y1;
            x2 =boundbox.x2;
            y2 =boundbox.y2;
          }
          w = atoi(argv[4]);
          h = atoi(argv[5]);
          if(w == 0) w = xctx->xrect[0].width;
          if(h == 0) h = xctx->xrect[0].height;
          save_restore_zoom(1, &zi);
          set_viewport_size(w, h, xctx->lw);
          if(xctx->lastsel) {
            zoom_box(x1, y1, x2, y2, 1.0);
            unselect_all(0);
          }
          else zoom_full(0, 0, 2 * tclgetboolvar("zoom_full_center"), 0.97);
          resetwin(1, 1, 1, w, h);
          svg_draw();
          save_restore_zoom(0, &zi);
          resetwin(1, 1, 1, xctx->xrect[0].width, xctx->xrect[0].height);
          change_linewidth(save_lw);
        } else if(argc == 10 || xctx->lastsel) {
          if(xctx->lastsel) {
            xRect boundbox;
            calc_drawing_bbox(&boundbox, 1);
            unselect_all(0);
            x1 =boundbox.x1;
            y1 =boundbox.y1;
            x2 =boundbox.x2;
            y2 =boundbox.y2;
            w = (int) fabs(x2 - x1);
            h = (int) fabs(y2 - y1);
          } else {
            w = atoi(argv[4]);
            h = atoi(argv[5]);
            x1 = atof(argv[6]);
            y1 = atof(argv[7]);
            x2 = atof(argv[8]);
            y2 = atof(argv[9]);
          }
          if(w == 0) w = (int) fabs(x2 - x1);
          if(h == 0) h = (int) fabs(y2 - y1);
          dbg(1, "w=%d, h=%d\n", w, h);
          save_restore_zoom(1, &zi);
          set_viewport_size(w, h, xctx->lw);
          zoom_box(x1, y1, x2, y2, 1.0);
          resetwin(1, 1, 1, w, h);
          svg_draw();
          save_restore_zoom(0, &zi);
          resetwin(1, 1, 1, xctx->xrect[0].width, xctx->xrect[0].height);
          change_linewidth(save_lw);
        } else {
          svg_draw();
        }
      }
      draw();
      Tcl_ResetResult(interp);
    }

    /* print_hilight_net show
     *   from highlighted nets/pins/labels:
     *   show == 0   ==> create pins from highlight nets
     *   show == 1   ==> show list of highlight net in a dialog box
     *   show == 2   ==> create labels with i prefix from hilight nets
     *   show == 3   ==> show list of highlight net with path and label
     *                  expansion in a dialog box
     *   show == 4   ==> create labels without i prefix from hilight nets
     *   for show = 0, 2, 4 user should complete GUI placement
     *   of created objects */
    else if(!strcmp(argv[1], "print_hilight_net"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        print_hilight_net(atoi(argv[2]));
        /* self-log at core (0061): the sym.list menu items + script. Modes 0/2/4
         * create pins/labels (mutate), 1/3 print; all are deterministic + replayable.
         * Tcl-backed registered keys eval this same command -> deduped here. */
        log_action("xschem print_hilight_net %d", atoi(argv[2]));
      }
    }

    /* print_spice_element inst
     *   Print spice raw netlist line for instance (number or name) 'inst' */
    else if(!strcmp(argv[1], "print_spice_element") )
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        int inst;
        if((inst = get_instance(argv[2])) < 0 ) {
          Tcl_SetResult(interp, "xschem replace_symbol: instance not found", TCL_STATIC);
          return TCL_ERROR;
        }
        print_spice_element(stderr, inst);
      }
    }


    /* propagate_hilights [set clear]
     *   Debug: wrapper to propagate_hilights() function */
    else if(!strcmp(argv[1], "propagate_hilights"))
    {
      int set = 1, clear = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
         set = atoi(argv[2]);
         clear = atoi(argv[3]);
      }
      propagate_hilights(set, clear, XINSERT_NOREPLACE);
    }

    /* push_undo
     *   Push current state on undo stack */
    else if(!strcmp(argv[1], "push_undo"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      xctx->push_undo();
      Tcl_ResetResult(interp);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem r...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_r(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{

    /* raw what ...
     *     what = add | clear | datasets | index | info | loaded | list |
     *            new | points | rawfile | del | read | set | rename |
     *            sim_type | switch | switch_back | table_read | value | values | pos_at | vars |
     *
     *   xschem raw read filename [type [sweep1 sweep2]]
     *     if sweep1, sweep2 interval is given in 'read' subcommand load only the interval
     *     sweep1 <= sweep_var < sweep2
     *     type is the analysis type to load (tran, dc, ac, op, ...). If not given load first found in
     *     raw file.
     *
     *   xschem raw clear [rawfile [type]]
     *     unload given file and type. If type not given delete all type sfrom rawfile
     *     If a number 'n' is given as 'rawfile' delete the 'nth' raw file
     *     if no file is given unload all raw files.
     *
     *   xschem raw del name
     *     delete named vector from current raw file
     *
     *   xschem raw rename old_name new_name
     *     rename a node in the loaded raw file.
     *
     *   xschem raw info
     *     print information about loaded raw files and show the currently active one.
     *
     *   xschem raw new name type sweepvar start end step
     *     create a new raw file with sweep variable 'sweepvar' with number=(end - start) / step datapoints
     *     from start value 'start' and step 'step'
     *
     *   xschem raw list
     *     get list of saved simulation variables
     *
     *   xschem raw vars
     *     get number of simulation variables
     *
     *   xschem raw switch [n | rawfile type]
     *     make the indicated 'rawfile, type' the active one
     *     else if a number n is specified make the n-th raw data the active one.
     *     if no file or number is specified then switch to the next rawdata in the list.
     *
     *   xschem switch_back
     *     switch to previously active rawdata.
     *
     *   xschem raw datasets
     *     get number of datasets (simulation runs)
     *
     *   xschem raw value node n [dset]
     *     return n-th value of 'node' in raw file
     *     dset is the dataset to look into in case of multiple runs (first run = 0).
     *     if dset = -1 consider n as the absolute position into the whole data file
     *     (all datasets combined).
     *     If n is given as empty string {} return value at cursor b,
     *     dset not used in this case
     *
     *   xschem raw loaded
     *     return hierarchy level where raw file was loaded or -1 if no raw loaded
     *
     *   xschem raw rawfile
     *      return raw filename
     *
     *   xschem raw sim_type
     *      return raw loaded simulation type (ac, op, tran, ...)
     *
     *   xschem raw index node
     *     get index of simulation variable 'node'.
     *     Example:  raw index v(led) --> 46
     *
     *   xschem raw values node [dset]
     *     print all simulation values of 'node' for dataset 'dset' (default dset=0)
     *     dset= -1: print all values for all datasets
     *
     *   xschem raw pos_at node value [dset] [from_start] [to_end]
     *     returns the position, starting from 0 or from_start if given, to the end of dataset
     *     or to_end if given of the first point 'p' where node[p] and node[p+1] bracket value.
     *     If dset not given assume dset 0 (first one)
     *     This is usually done on the sweep (time) variable in transient sims where timestep is
     *     not uniform
     *
     *   xschem raw points [dset]
     *     print simulation points for dataset 'dset' (default: all dataset points combined)
     *
     *   xschem raw set node n value [dset]
     *     change loaded raw file data node[n] to value
     *     dset is the dataset to look into in case of multiple runs (first run = 0)
     *     dset = -1: consider n as the absolute position in the whole raw file
     *     (all datasets combined)
     *
     *   xschem raw table_read tablefile
     *     read a tabular data file.
     *     First line is the header line containing variable names.
     *     data is presented in column format after the header line
     *     First column is sweep (x-axis) variable
     *     Double empty lines start a new dataset
     *     Single empty lines are ignored
     *     Datasets can have different # of lines.
     *     new dataset do not start with a header row.
     *     Lines beginning with '#' are comments and ignored
     *
     *        time    var_a   var_b   var_cnode in the loaded raw file.
     *     # this is a comment, ignored
     *         0.0     0.0     1.8    0.3
     *       <single empty line: ignored>
     *         0.1     0.0     1.5    0.6
     *         ...     ...     ...    ...
     *       <empty line>
     *       <Second empty line: start new dataset>
     *         0.0     0.0     1.8    0.3
     *         0.1     0.0     1.5    0.6
     *         ...     ...     ...    ...
     *
     *   xschem raw add varname [expr] [sweep_var]
     *     add a 'varname' vector with all values set to 0 to loaded raw file if expr not given
     *     otherwise initialize data with values calculated from expr.
     *     if expr is given and also sweep_var is given use indicated sweep_var for expressions
     *     that need it. If sweep_var not given use first raw file variable as sweep variable.
     *     If varname is already existing and expr given recalculate data
     *     Example: xschem raw add power {outm outp - i(@r1[i]) *}
     *
     */
    /* recompute_inst_bbox [inst]
     *   Recompute the cached bounding box (x1/y1/x2/y2, which includes the instance's
     *   texts) of one instance (by name or index) or, with no arg, of every currently
     *   SELECTED instance. Does NOT push undo or redraw — it just refreshes the bbox
     *   the hit-test/selection/redraw machinery relies on. Needed after a batch of
     *   `setprop -fast instance` edits (the fast path skips symbol_bbox) so a single
     *   undo can cover a multi-object gesture while hit-testing stays correct.
     *   See doc/claude/specs/bus_thickness_scroll.md / its undo update. */
    if(!strcmp(argv[1], "recompute_inst_bbox"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        int i = get_instance(argv[2]);
        if(i < 0) { Tcl_SetResult(interp, "xschem recompute_inst_bbox: instance not found",
                                   TCL_STATIC); return TCL_ERROR; }
        symbol_bbox(i, &xctx->inst[i].x1, &xctx->inst[i].y1, &xctx->inst[i].x2, &xctx->inst[i].y2);
      } else {
        int i;
        rebuild_selected_array();
        for(i = 0; i < xctx->lastsel; ++i) {
          if(xctx->sel_array[i].type == ELEMENT) {
            int n = xctx->sel_array[i].n;
            symbol_bbox(n, &xctx->inst[n].x1, &xctx->inst[n].y1, &xctx->inst[n].x2, &xctx->inst[n].y2);
          }
        }
      }
      Tcl_ResetResult(interp);
    }
    else if(!strcmp(argv[1], "raw") || !strcmp(argv[1], "raw_query"))
    {
      double sweep1 = -1.0, sweep2 = -1.0;
      int err = 0;
      int ret = 0;
      int i;
      Raw *raw = xctx->raw;
      Tcl_ResetResult(interp);
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3 && !strcmp(argv[2], "table_read")) {
        ret = extra_rawfile(1, argv[3], "table", sweep1, sweep2);
        Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
      } else if(argc > 3 && !strcmp(argv[2], "read")) {
        if(argc > 6) {
          sweep1 = atof_spice(argv[5]);
          sweep2 = atof_spice(argv[6]);
        }
        if(argc > 4) ret = extra_rawfile(1, argv[3], argv[4], sweep1, sweep2);
        else ret = extra_rawfile(1, argv[3], NULL, sweep1, sweep2);
        Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
      } else if(argc > 2 && !strcmp(argv[2], "switch")) {
        if(argc > 4) {
          ret = extra_rawfile(2, argv[3], argv[4], -1.0, -1.0);
        } else if(argc > 3) {
          ret = extra_rawfile(2, argv[3], NULL, -1.0, -1.0);
        } else {
          ret = extra_rawfile(2, NULL, NULL, -1.0, -1.0);
        }
        /* only update_op() if switching into a 1-point OP or DC */
        if(ret && raw && raw->rawfile && raw->allpoints == 1 &&
           (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
          update_op();
        }
        Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
      } else if(argc ==9 && !strcmp(argv[2], "new")) {
        ret = new_rawfile(argv[3], argv[4], argv[5], atof(argv[6]), atof(argv[7]),atof(argv[8]));
        Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
      } else if(argc > 2 && !strcmp(argv[2], "info")) {
        ret = extra_rawfile(4, NULL, NULL, -1.0, -1.0);
      } else if(argc > 2 && !strcmp(argv[2], "switch_back")) {
        ret = extra_rawfile(5, NULL, NULL, -1.0, -1.0);
        /* only update_op() if switching into a 1-point OP or DC */
        if(ret && raw && raw->rawfile && raw->allpoints == 1 &&
           (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
          update_op();
        }
        Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
      } else if(argc > 2 && !strcmp(argv[2], "clear")) {
        if(argc > 4)  {
          ret = extra_rawfile(3, argv[3], argv[4], -1.0, -1.0);
        } else if(argc > 3)  {
          ret = extra_rawfile(3, argv[3], NULL, -1.0, -1.0);
        } else {
          ret = extra_rawfile(3, NULL, NULL, -1.0, -1.0);
        }
        Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
      } else if(argc > 2 && !strcmp(argv[2], "loaded")) {
        Tcl_SetResult(interp, my_itoa(sch_waves_loaded()), TCL_VOLATILE);
      } else if(raw && raw->values) {
        /* xschem raw value v(ldcp) 123 */
        if(argc > 4 && !strcmp(argv[2], "value")) {
          int dataset = -1;
          int point = argv[4][0] ? atoi(argv[4]) : -1;
          const char *node = argv[3];
          int idx = -1;
          if(argc > 5) dataset = atoi(argv[5]);
          idx = get_raw_index(node, NULL);
          if(idx >= 0) {
            double val;
            if( (dataset >=0 && point >= 0 && point < raw->npoints[dataset]) ||
                (dataset == -1 && point >= 0 && point < raw->allpoints)
              ) {
              val = get_raw_value(dataset, idx, point);
              Tcl_SetResult(interp, dtoa(val), TCL_VOLATILE);
            } else if(xctx->raw->cursor_b_val) {
              val = xctx->raw->cursor_b_val[idx];
              Tcl_SetResult(interp, dtoa(val), TCL_VOLATILE);
            }
          }
        } else if(argc > 3 && !strcmp(argv[2], "del")) {
          ret = raw_deletevar(argv[3]);
          Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
        } else if(argc > 4 && !strcmp(argv[2], "rename")) {
          ret = raw_renamevar(argv[3], argv[4]);
          Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
        } else if(argc > 3 && !strcmp(argv[2], "index")) {
          /* xschem raw index v(ldcp) */
          int idx;
          idx = get_raw_index(argv[3], NULL);
          Tcl_SetResult(interp, my_itoa(idx), TCL_VOLATILE);
        } else if(argc > 3 && !strcmp(argv[2], "values")) {
          /* xschem raw values ldcp [dataset] */
          int idx;
          char n[70];
          int p, dataset = 0;
          idx = get_raw_index(argv[3], NULL);
          if(argc > 4) dataset = atoi(argv[4]);
          if(idx >= 0) {
            int np;
            if(dataset < 0 )
              np = raw->allpoints;
            else
              np = raw->npoints[dataset];
            Tcl_ResetResult(interp);
            for(p = 0; p < np; p++) {
              sprintf(n, "%.16g", get_raw_value(dataset, idx, p));
              Tcl_AppendResult(interp, n, " ", NULL);
            }
          }
        } else if(argc > 4 && !strcmp(argv[2], "pos_at")) {
          /* xschem raw pos_at node value [dset] [from_start] [to_end] */
          int dset = 0;
          int from_start = -1;
          int to_end = -1;
          int pos = -1;
          double value = 0.0;
          if(argc > 5) {
            dset = atoi(argv[5]);
          }
          if(argc > 6) {
            from_start = atoi(argv[6]);
          }
          if(argc > 7) {
            to_end = atoi(argv[7]);
          }
          value = atof_spice(argv[4]);
          pos = raw_get_pos(argv[3], value, dset, from_start, to_end);
          Tcl_SetResult(interp, my_itoa(pos), TCL_VOLATILE);
        } else if(argc > 3 && !strcmp(argv[2], "add")) {
          int res = 0;
          int sweep_idx = 0;
          if(argc > 5) { /* provided sweep variable */
            sweep_idx =  get_raw_index(argv[5], NULL);
            if(sweep_idx <= 0) sweep_idx = 0;
          }
          if(argc > 4) {
            #if 0 /* seems not necessary... */
            int save_datasets = -1, save_npoints = -1;
            /* transform multiple OP points into a dc sweep */
            if(sch_waves_loaded()!= -1 && xctx->raw && xctx->raw->sim_type && !strcmp(xctx->raw->sim_type, "op")
               && xctx->raw->datasets > 1 && xctx->raw->npoints[0] == 1) {
              save_datasets = xctx->raw->datasets;
              xctx->raw->datasets = 1;
              save_npoints = xctx->raw->npoints[0];
              xctx->raw->npoints[0] = xctx->raw->allpoints;
            }
            #endif
            res = raw_add_vector(argv[3], argv[4], sweep_idx);

            #if 0
            if(sch_waves_loaded()!= -1 && save_npoints != -1) { /* restore multiple OP points */
              xctx->raw->datasets = save_datasets;
              xctx->raw->npoints[0] = save_npoints;
            }
            #endif
          } else {
            res = raw_add_vector(argv[3], NULL, 0);
          }
          Tcl_SetResult(interp, my_itoa(res), TCL_VOLATILE);
        } else if(argc > 2 && !strcmp(argv[2], "datasets")) {
          Tcl_SetResult(interp, my_itoa(raw->datasets), TCL_VOLATILE);
        } else if(argc > 2 && !strcmp(argv[2], "points")) {
          int dset = -1;
          if(argc > 3) dset = atoi(argv[3]);
          if(dset == -1) Tcl_SetResult(interp, my_itoa(raw->allpoints), TCL_VOLATILE);
          else {
            if(dset >= 0 && dset <  raw->datasets)
                Tcl_SetResult(interp, my_itoa(raw->npoints[dset]), TCL_VOLATILE);
          }
        } else if(argc > 2 && !strcmp(argv[2], "rawfile")) {
          Tcl_SetResult(interp, raw->rawfile, TCL_VOLATILE);
        } else if(argc > 2 && !strcmp(argv[2], "sim_type")) {
          Tcl_SetResult(interp, raw->sim_type, TCL_VOLATILE);
        } else if(argc > 2 && !strcmp(argv[2], "vars")) {
          Tcl_SetResult(interp, my_itoa(raw->nvars), TCL_VOLATILE);
        } else if(argc > 2 && !strcmp(argv[2], "list")) {
          for(i = 0 ; i < raw->nvars; ++i) {
            if(i > 0) Tcl_AppendResult(interp, "\n", NULL);
            Tcl_AppendResult(interp, raw->names[i], NULL);
          }
        /*    0      1        2   3   4   5       6
         *  xschem raw set node n value [dataset] */
        } else if(argc > 5 && !strcmp(argv[2], "set")) {
          int dataset = -1, ofs = 0;
          int point = atoi(argv[4]);
          const char *node = argv[3];
          int idx = -1;
          if(argc > 6) dataset = atoi(argv[6]);
          idx = get_raw_index(node, NULL);
          if(idx >= 0) {
            if( dataset < xctx->raw->datasets &&
                ( (dataset >=0 && point >= 0 && point < raw->npoints[dataset]) ||
                  (dataset == -1 && point >= 0 && point < raw->allpoints) )
              ) {
              if(dataset != -1) {
                for(i = 0; i < dataset; ++i) {
                  ofs += xctx->raw->npoints[i];
                }
                if(ofs + point < xctx->raw->allpoints) {
                  point += ofs;
                }
              }
              xctx->raw->values[idx][point] = (SPICE_DATA) atof(argv[5]);
              Tcl_SetResult(interp, dtoa(xctx->raw->values[idx][point]), TCL_VOLATILE);
            }
          }
        } else {
          err = 1;
        }
      } else {
        Tcl_SetResult(interp, "No raw file loaded", TCL_STATIC); return TCL_ERROR;
      }
      if(err) {Tcl_SetResult(interp, "Wrong command", TCL_STATIC); return TCL_ERROR;}
    }

    /* raw_clear
     *   Unload all simulation raw files
     *   You can use xschem raw clear as well.
     */
    else if(!strcmp(argv[1], "raw_clear"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      extra_rawfile(3, NULL, NULL, -1.0, -1.0); /* unload additional raw files */
      /* free_rawfile(&xctx->raw, 1, 0); */ /* unload base (current) raw file */
      draw();
      Tcl_ResetResult(interp);
    }

    /* raw_read [file] [sim] [sweep1 sweep2]
     *   If a raw file is already loaded delete from memory
     *   then load specified file and analysis 'sim' (dc, ac, tran, op, ...)
     *   If 'sim' not specified load first section found in raw file.
     *   if sweep1, sweep2 interval is given load only the interval
     *   sweep1 <= sweep_var < sweep2 */
    else if(!strcmp(argv[1], "raw_read"))
    {
      char f[PATH_MAX + 100];
      int res = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /*
      * if(sch_waves_loaded() >= 0) {
      *   tcleval("array unset ngspice::ngspice_data");
      *   extra_rawfile(3, NULL, NULL, -1.0, -1.0);
      *   free_rawfile(&xctx->raw, 1, 0);
      * } else
      */
      if(argc > 2) {
        double sweep1 = -1.0, sweep2 = -1.0;
        tcleval("array unset ngspice::ngspice_data");
        extra_rawfile(3, NULL, NULL, -1.0, -1.0);
        /* free_rawfile(&xctx->raw, 0, 0); */
        my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[2], home_dir);
        tcleval(f);
        my_strncpy(f, tclresult(), S(f));
        if(argc > 5) {
          sweep1 = atof_spice(argv[4]);
          sweep2 = atof_spice(argv[5]);
        }
        if(argc > 3) res = raw_read(f, &xctx->raw, argv[3], 0, sweep1, sweep2);
        else res = raw_read(f, &xctx->raw, NULL, 0, -1.0, -1.0);
        if(sch_waves_loaded() >= 0) {
          draw();
        }
      }
      Tcl_SetResult(interp, my_itoa(res), TCL_VOLATILE);
    }

    /* raw_read_from_attr [sim]
     *   If a simulation raw file is already loaded delete from memory
     *   else read section 'sim' (tran, dc, ac, op, ...)
     *   of base64 encoded data from a 'spice_data'
     *   attribute of selected instance
     *   If sim not given read first section found */
    else if(!strcmp(argv[1], "raw_read_from_attr"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(sch_waves_loaded() >= 0) {
        extra_rawfile(3, NULL, NULL, -1.0, -1.0);
        /* free_rawfile(&xctx->raw, 1, 0); */
        draw();
      } else {
        extra_rawfile(3, NULL, NULL, -1.0, -1.0);
        /* free_rawfile(&xctx->raw, 0, 0); */
        if(argc > 2) raw_read_from_attr(&xctx->raw, argv[2], -1.0, -1.0);
        else  raw_read_from_attr(&xctx->raw, NULL, -1.0, -1.0);
        if(sch_waves_loaded() >= 0) {
          draw();
        }
      }
      Tcl_ResetResult(interp);
    }

    /* rebuild_connectivity
     *   Rebuild logical connectivity abstraction of schematic */
    else if(!strcmp(argv[1], "rebuild_connectivity"))
    {
      int err = 0;
      int n = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) n = atoi(argv[2]);
      xctx->prep_hash_inst=0;
      xctx->prep_hash_wires=0;
      xctx->prep_net_structs=0;
      xctx->prep_hi_structs=0;
      err |= prepare_netlist_structs(n);
      Tcl_SetResult(interp, my_itoa(err), TCL_VOLATILE);
    }

    /* rebuild_selection
         Rebuild selection list*/
    else if(!strcmp(argv[1], "rebuild_selection"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      rebuild_selected_array();
    }

    /* record_global_node n node
         call the record_global_node function (list of netlist global nodes) */
    else if(!strcmp(argv[1], "record_global_node"))
    {
      int ret = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        int n = atoi(argv[2]);
        if(n == 4 && argc > 3) ret = record_global_node(4,NULL, argv[3]); /* insert node */
        else if(n == 1 && argc > 3) ret = record_global_node(1,NULL, argv[3]); /* insert node */
        else if(n == 0) ret = record_global_node(0, stdout, NULL);
        else if(n == 2) ret = record_global_node(2, NULL, NULL);
        else if(n == 3 && argc > 3) ret = record_global_node(3, NULL, argv[3]); /* look up node */
      }
      Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
    }

    /* rect ...
     *   rect [x1 y1 x2 y2] [pos] [propstring] [draw]
     *     if 'x1 y1 x2 y2'is given place recangle on current
     *     layer (rectcolor) at indicated coordinates.
     *     if 'pos' is given insert at given position in rectangle array.
     *     if 'pos' set to -1 append rectangle to last element in rectangle array.
     *     'propstring' is the attribute string. Set to empty if not given.
     *     if 'draw' is set to 1 (default) draw the new object, else don't
     *   rect
     *     If no coordinates are given start a GUI operation of rectangle placement
     *   rect gui
     *     if `gui` argument is given start a GUI placement of a rectangle with 1st
     *     point starting from current mouse coordinates */
    /* rect_id layer index
     *   return the session-stable id of the rect at (layer, index), or -1 if
     *   out of range. Graphical ids are stamped at creation (store.c
     *   gfx_register), one shared id space across rect/line/poly/arc, never
     *   reused within a window/tab session and not persisted in .sch files.
     *   Resolve back with `xschem rect_index id` */
    else if(!strcmp(argv[1], "rect_id"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
        int c = atoi(argv[2]), n = atoi(argv[3]);
        if(c >= 0 && c < cadlayers && n >= 0 && n < xctx->rects[c]) {
          char s[30];
          my_snprintf(s, S(s), "%u", xctx->rect[c][n].id);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        } else {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        }
      }
    }
    /* rect_index id
     *   return the current location "{layer index}" of the rect whose
     *   session-stable id (see `xschem rect_id`) is given, or -1 if no live
     *   rect carries that id (deleted, layer-changed -> reconstructed with a
     *   new id, or invalidated by a disk-undo restore) */
    else if(!strcmp(argv[1], "rect_index"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        unsigned int id = (unsigned int)strtoul(argv[2], NULL, 10);
        int layer, idx = gfx_index_from_id(xRECT, id, &layer);
        if(idx < 0) {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        } else {
          char s[40];
          my_snprintf(s, S(s), "%d %d", layer, idx);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        }
      }
    }
    else if(!strcmp(argv[1], "rect"))
    {
      double x1,y1,x2,y2;
      int pos, save;
      int draw = 1;
      const char *prop_str = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "rect")) return TCL_ERROR;
      if(argc > 5) {
        x1=atof(argv[2]);
        y1=atof(argv[3]);
        x2=atof(argv[4]);
        y2=atof(argv[5]);
        RECTORDER(x1,y1,x2,y2);
        pos=-1;
        if(argc > 6) pos=atoi(argv[6]);
        if(argc > 7) prop_str = argv[7];
        if(argc > 8) draw = atoi(argv[8]);
        xctx->push_undo(); /* issue 0127: checkpoint like interactive new_rect + the wire coord arm */
        storeobject(pos, x1,y1,x2,y2,xRECT,xctx->rectcolor,0,prop_str);
        if(draw) {
          int c = xctx->rectcolor;
          int n = xctx->rects[c] - 1;
          int e_a = xctx->rect[c][n].ellipse_a;
          int e_b = xctx->rect[c][n].ellipse_b;
          save = xctx->draw_window; xctx->draw_window = 1;
          drawrect(xctx->rectcolor,NOW, x1,y1,x2,y2, 0.0, 0, e_a, e_b);
          filledrect(xctx->rectcolor, NOW, x1, y1, x2, y2, 1, -1, -1);
          xctx->draw_window = save;
        }
        set_modify(1);
      } else if(argc > 2 && !strcmp(argv[2], "gui")) {
        int infix_interface = tclgetboolvar("infix_interface");
        if(infix_interface) {
          xctx->mx_double_save=xctx->mousex_snap;
          xctx->my_double_save=xctx->mousey_snap;
          xctx->last_command = 0;
          new_rect(PLACE,xctx->mousex_snap, xctx->mousey_snap);
        } else {
          xctx->ui_state |= MENUSTART;
          xctx->ui_state2 = MENUSTARTRECT;
        }
      } else {
        xctx->ui_state |= MENUSTART;
        xctx->ui_state2 = MENUSTARTRECT;
      }
    }

    /* redo
     *   Redo last undone action.
     *   Refactor B atom 28 (audit §48): routes through the perform_action boundary. The ONE
     *   readonly gate (same scheduler_readonly_reject + "redo" verb string = byte-identical
     *   message), the pop_undo_keep_selection(1,1) effect and the ONE bare `xschem redo` log
     *   site (core_log_action's DEFAULT %s arm) all live in perform_action/run_core. Every
     *   entry funnels here: the Shift+U key is a Tcl-funneled binding (edit.redo ->
     *   `xschem redo; xschem redraw`, legacy case 'U' deleted), deduped via
     *   actionlog_cmd_logged; menu/toolbar run the same compound; scripts call the verb.
     *   Tolerant argc PRESERVED (extra args execute + log bare, as before -- no arity gate). */
    else if(!strcmp(argv[1], "redo"))
    {
      return perform_action("redo", argc, argv);
    }

    /* redraw
     *   redraw window */
    else if(!strcmp(argv[1], "redraw"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      draw();
      Tcl_ResetResult(interp);
    }

    /* redraw_hilight_region
     *   One net-highlight animation frame (Pass 2a): regional-redraw the union bbox of the
     *   animating (blinking) highlighted nets to restore underlying pixels for the new blink
     *   phase. Driven by the Tcl tick (net_hilight_anim_tick); no-op when nothing animates or
     *   no blink edge occurred since the last frame. Returns 1 if it redrew, else 0.
     *   Optional <win> arg (multi-window anim, Phase C): regional-redraw THAT window, not the
     *   front. Borrow <win>'s context (Phase A), run draw_hilight_region() against it -- which
     *   draws into that window's own save_pixmap + canvas via bbox()/draw() -- then restore.
     *   The borrow wraps a COMPLETE, synchronous draw_hilight_region() (no vwait/update inside,
     *   non-reentrant), which is the condition the A3 audit requires for the file-scope draw
     *   batch buffers (draw.c) to stay safe under a context swap. */
    else if(!strcmp(argv[1], "redraw_hilight_region"))
    {
      int r;
      double next = NET_HILIGHT_TICK_BUSY; /* default retry cadence (overwritten by draw_hilight_region) */
      char buf[64];
      Xschem_ctx *borrowed = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* explicit <win> that names no open window -> nothing to redraw, stop the tick (0).
       * net_hilight_win_known() (not the borrow's NULL, which also means "already current")
       * is the unknown test, so a transiently-NULL current_win_path during window
       * alloc/teardown can't make an unknown win fall through to redraw the FRONT. A known
       * <win> that IS the current window borrows to NULL and correctly redraws the front. */
      if(argc > 2 && !net_hilight_win_known(argv[2])) {
        r = 0;
      } else if(net_hilight_ctx_gesturing()) {
        /* E1: the focused (global) window is mid-GESTURE (drag / wire / move / select). Never
         * animate ANY window's frame now -- a borrow would swap xctx out from under the in-flight
         * rubber-band draw and the shared draw batch buffers. Checked BEFORE the borrow: a gesture
         * lives in the focused window. (Gesturing, NOT net_hilight_ctx_busy: the semaphore is also
         * held by passive ops like a modal dialog, which must not freeze OTHER windows' animation.
         * If a gesture were ever left in a now-background window -- switch_window only blocks on the
         * semaphore, not ui_state -- the post-borrow per-context check in draw_hilight_region still
         * catches it.) Return 2 (busy, keep ticking; next stays at the NET_HILIGHT_TICK_BUSY
         * default); resume promptly once the gesture ends. */
        r = 2;
      } else {
        if(argc > 2) borrowed = net_hilight_borrow_ctx(argv[2]);
        /* Background-TAB guard: a real borrow (borrowed != NULL) onto a context with an empty
         * top_path is a non-front tab -- it shares the single visible .drw canvas with the
         * ACTUAL front tab, so drawing it would scribble the wrong nets onto the shown tab.
         * Stop the tick (0). This restores the pre-Phase-C "non-front window doesn't draw" bail,
         * but narrowed to TABS: a detached window (non-empty top_path) owns its own canvas and
         * DOES draw, which is the whole multi-window feature. (.drw's path is always
         * `winfo viewable`, so the Tcl-side visibility gate cannot catch this.) */
        if(borrowed && (!xctx->top_path || !xctx->top_path[0]) && strcmp(argv[2], get_drw_front_win()))
          r = 0; /* a HIDDEN background tab (empty top_path, and not the tab currently shown on .drw).
                  * The main window / front tab (== get_drw_front_win()) IS visible on .drw even when a
                  * DETACHED window has focus, so it must keep animating -- issue 0073 animated-highlight. */
        else
          r = draw_hilight_region(&next); /* guards save_pixmap==0 (unexposed bg window) internally */
        net_hilight_restore_ctx(borrowed);
      }
      /* Return "tristate next_ms": 0 = stop the tick, 1 = redrew (edge), 2 = keep ticking
       * (busy/no edge); next_ms = ms the tick should sleep before the next call. */
      my_snprintf(buf, S(buf), "%d %d", r, (int)next);
      Tcl_SetResult(interp, buf, TCL_VOLATILE);
    }

    /* reload
     *   Forced (be careful!) Reload current schematic from disk */
    else if(!strcmp(argv[1], "reload"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      unselect_all(1);
      remove_symbols();
      load_schematic(1, xctx->sch[xctx->currsch], 1, 1);
      if(argc > 2 && !strcmp(argv[2], "zoom_full") ) {
        zoom_full(1, 0, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
      } else {
        draw();
      }
      /* self-log at core (0062): covers the toolbar FileReload confirmed arm (was the
       * silent gap), File>Reload (action_reload -- its own log line removed, this is
       * now the single site) and CIW/script (dedup). Both confirm dialogs sit in the
       * callers, so a Cancel never reaches this branch -> no line. The Alt-S key
       * reloads inline in callback.c and logs at its own site. */
      log_action("xschem reload%s",
                 (argc > 2 && !strcmp(argv[2], "zoom_full")) ? " zoom_full" : "");
      Tcl_ResetResult(interp);
    }

    /* reload_symbols
     *   Reload all used symbols from disk */
    else if(!strcmp(argv[1], "reload_symbols"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      remove_symbols();
      link_symbols_to_instances(-1);
      xctx->prep_hi_structs=0;
      xctx->prep_net_structs=0;
      Tcl_ResetResult(interp);
    }

    /* remove_symbols
     *   Internal command: remove all symbol definitions */
    else if(!strcmp(argv[1], "remove_symbols"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      remove_symbols();
      Tcl_ResetResult(interp);
    }

    /* replace_symbol inst new_symbol [fast]
     *   Replace 'inst' symbol with 'new_symbol'
     *   If doing multiple substitutions set 'fast' to {}
     *    on first call and 'fast' on next calls
     *   for faster operation.
     *   do a 'xschem redraw' at end to update screen
     *   Example: xschem replace_symbol R3 capa.sym
     * Routes through the single mutation boundary (Refactor B atom 14): the readonly
     * gate, the fast-flag parse + the argc!=4 / "instance not found" validation, the
     * (non-fast) push_undo + the symbol swap, and the ONE `xschem replace_symbol <inst>
     * <sym>` log site (via core_log_action, LOGGED ONLY ON SUCCESS and ONLY when NOT
     * fast) all live in perform_action/run_core. This is the SECOND VALIDATING verb on
     * the boundary and the FIRST per-verb migration to carry a FAST-FLAG log gate: the
     * fast form is a multi-substitution machinery/replay sub-mode that skips BOTH the
     * undo and the log. No scattered readonly/log/push_undo here; the old success-path
     * instname interp result is dropped (the boundary clears the interp on success; no
     * caller consumed it). */
    else if(!strcmp(argv[1], "replace_symbol"))
      return perform_action("replace_symbol", argc, argv);

    /* reset_caches
     *   Reset cached instance and symbol cached flags (inst->flags, sym->flags) */
    else if(!strcmp(argv[1], "reset_caches"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      reset_caches();
      Tcl_ResetResult(interp);
    }

    /* reset_inst_prop inst
     *   Reset instance attribute string taking it from symbol template string.
     * Routes through the single mutation boundary (Refactor B atom 13): the readonly
     * gate, the argc<3 / "instance not found" validation, the single push_undo + the
     * reset effect, and the ONE `xschem reset_inst_prop <ref>` log site (via
     * core_log_action, LOGGED ONLY ON SUCCESS) all live in perform_action/run_core.
     * This is the FIRST VALIDATING verb on the boundary -- the atom-13 log-on-success
     * change is what lets its early-TCL_ERROR paths cross without being phantom-logged.
     * No scattered readonly/log/push_undo here; the old success-path instname result is
     * dropped (the boundary clears the interp on success; no caller consumed it). */
    else if(!strcmp(argv[1], "reset_inst_prop"))
      return perform_action("reset_inst_prop", argc, argv);

    /* reset_symbol inst symref
     *   Low-level command: it merely swaps the xctx->inst[...].name field. It is the CALLER's
     *   responsibility to delete all symbols before and do a reload_symbols afterward
     *   (fix_symbols, xschem.tcl, does exactly this -- bracketing its remap loop in ONE
     *   push_undo).
     * Routes through the single mutation boundary (Refactor B atom 22 -- the direct INLINE twin
     * of reset_inst_prop (atom 13); an ADDITIVE-LOG+GATE migration: the branch had NEITHER a
     * self-log NOR a readonly gate, so the boundary ADDS both -- a replay line AND the read-only
     * gate that closes a latent mutate-on-read-only bug). The readonly gate + the argc!=4 /
     * "instance not found" validation + the my_strdup effect + the ONE `xschem reset_symbol
     * <inst> <symref>` log site (via core_log_action, LOGGED ONLY ON SUCCESS) all live in
     * perform_action/run_core. NOTE this verb owns NO push_undo/set_modify -- fix_symbols
     * brackets the batch with a single undo, so a per-call push here would shatter it. No
     * scattered readonly/log/push_undo here; the old success-path Tcl_ResetResult is the
     * boundary's job now. */
    else if(!strcmp(argv[1], "reset_symbol"))
      return perform_action("reset_symbol", argc, argv);

    /* resetwin create_pixmap clear_pixmap force w h   (full internal form)
     * resetwin w h                                     (fit form, issue 0035/0037)
     *   Recreate the backing pixmap from the window geometry and redraw -- like the
     *   ConfigureNotify handler. The 2-arg form forces a refit to an explicit w/h (e.g. Tk's
     *   `winfo width/height`), bypassing XGetWindowAttributes -- which on some WMs (WSLg) still
     *   reports a transient 1x1 for a just-mapped window even though Tk knows the real size.
     *   If a deferred full-zoom is armed (pending_fullzoom) resetwin() performs it against that
     *   geometry, so a freshly-opened new window whose WM never delivered a settling Configure
     *   still gets fit. */
    else if(!strcmp(argv[1], "resetwin"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 6) {
        resetwin(atoi(argv[2]), atoi(argv[3]), atoi(argv[4]), atoi(argv[5]), atoi(argv[6]));
      } else if(argc > 3) {
        resetwin(1, 1, 1, atoi(argv[2]), atoi(argv[3])); /* create, clear, force, w, h */
        draw();
      }
      Tcl_ResetResult(interp);
    }

    /* resolved_net [net [level]]
     *   if 'net' is given  return its topmost full hierarchy name
     *   else returns the topmost full hierarchy name of selected net/pin/label.
     *   Nets connected to I/O ports are mapped to upper level recursively.
     *   'level' (issue 0168) names the hierarchy level the returned path is
     *   measured FROM (0 = the window's top). Omitted / negative keeps the
     *   shipped behavior: measure from the level the loaded raw belongs to
     *   (sch_waves_loaded()), else from the top. ASE-L passes the level of the
     *   design its session simulates, so a pick made while descended is named
     *   the way THAT deck names it. */
    else if(!strcmp(argv[1], "resolved_net"))
    {
      const char *net = NULL;
      char  *rn = NULL;
      int from_level = -1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      Tcl_ResetResult(interp);
      prepare_netlist_structs(0);
      if(argc > 3) from_level = atoi(argv[3]);
      if(argc > 2) {
        net = argv[2];
      } else if(xctx->lastsel == 1) {
        if(xctx->sel_array[0].type == ELEMENT) {
          int n=xctx->sel_array[0].n;
          if(xctx->inst[n].ptr >= 0) {
           const  char *type = xctx->sym[xctx->inst[n].ptr].type;
            if(IS_LABEL_SH_OR_PIN(type) && xctx->inst[n].node && xctx->inst[n].node[0]) {
              net = xctx->inst[n].node[0];
            }
          }
        } else if(xctx->sel_array[0].type == WIRE) {
          int n=xctx->sel_array[0].n;
          if(xctx->wire[n].node) {
            net = xctx->wire[n].node;
          }
        }
      }
      rn = resolved_net_from(net, from_level);
      Tcl_AppendResult(interp, rn, NULL);
      my_free(_ALLOC_ID_, &rn);
    }

    /* rotate [x0 y0]
     *   Rotate selection around point x0 y0.
     *   if x0, y0 not given use mouse coordinates */
    else if(!strcmp(argv[1], "rotate"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* rotate-during-move/copy: rotate the whole in-flight selection about the shared gesture
       * pivot. These two mid-gesture arms stay RAW -- they are sub-steps of a move/copy logged
       * at that gesture's END (issue 0069), NOT the standalone verb, so they must NOT cross the
       * perform_action boundary (routing them would spuriously emit `xschem rotate x y` mid-drag
       * and double-count the move-END line). They need no readonly gate: being in STARTMOVE/
       * STARTCOPY means an edit is already in progress, impossible on a read-only schematic, and
       * the only commit path `xschem move_objects end` is itself readonly-refused at the
       * move_objects command gate (covering start/step/end/abort). */
      if(xctx->ui_state & STARTMOVE) move_objects(ROTATE,0,0,0);
      else if(xctx->ui_state & STARTCOPY) copy_objects(ROTATE);
      /* standalone verb: the single mutation boundary (Refactor B atom 6, run_core above) owns the
       * readonly gate + the ONE `xschem rotate x0 y0` log site (core_log_action formats the pivot)
       * + the rebuild+seed-pivot+START+ROTATE+END effect. run_core resolves the pivot from
       * argv[2]/argv[3] (else the mouse coords) exactly as this branch used to, so passing the
       * branch's own argc/argv straight through is byte-identical -- and it fixes a latent order
       * bug: the pivot is now read AFTER perform_action's !xctx guard, not before it. The Edit menu
       * (bare `xschem rotate`), the context menu and the command palette reach here; the Shift-R
       * key, the Alt-R group transform and the verb-noun apply reach the same boundary from
       * callback.c, each carrying its own pivot. rotate is the FIRST arg-carrying verb on the
       * boundary (issue 0068's "Shift-R logs nothing" note is now stale -- Shift-R logs here too). */
      else return perform_action("rotate", argc, argv);
      Tcl_ResetResult(interp);   /* only the mid-gesture arms fall through to here */
    }

    /* rotate_in_place
     *   Rotate selected objects around their 0,0 coordinate point */
    else if(!strcmp(argv[1], "rotate_in_place"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* rotate-during-move/copy: rotate each object about its own center. These two
       * mid-gesture arms stay RAW -- they are sub-steps of a move/copy logged at that
       * gesture's END (issue 0069), NOT the standalone verb, so they must NOT cross the
       * perform_action boundary (routing them would spuriously emit `xschem rotate_in_place`
       * mid-drag and double-count the move-END line). They need no readonly gate: being in
       * STARTMOVE/STARTCOPY means an edit is already in progress, which a read-only schematic
       * never permits. (ROTATE|ROTATELOCAL matters -- an earlier bug had FLIP here by
       * copy-paste from flip_in_place, mirror-flipping instead of rotating.) */
      if(xctx->ui_state & STARTMOVE) move_objects(ROTATE|ROTATELOCAL,0,0,0);
      else if(xctx->ui_state & STARTCOPY) copy_objects(ROTATE|ROTATELOCAL);
      /* standalone verb: the single mutation boundary (Refactor B atom 3, run_core above)
       * owns the readonly gate + the ONE `xschem rotate_in_place` log site + the rebuild+
       * START+ROTATE|ROTATELOCAL+END effect. The Edit menu / context menu / command palette
       * reach here via `xschem rotate_in_place`; the Alt-R key + verb-noun apply reach the
       * same boundary from callback.c. */
      else return perform_action("rotate_in_place", argc, argv);
      Tcl_ResetResult(interp);   /* only the mid-gesture arms fall through to here */
    }

    /* round_to_n_digits i n
     *   round number 'i' to 'n' digits */
    else if(!strcmp(argv[1], "round_to_n_digits"))
    {
      double r;
      if(argc > 3) {
        r = round_to_n_digits(atof(argv[2]), atoi(argv[3]));
        Tcl_SetResult(interp, dtoa(r), TCL_VOLATILE);
      }
    }

    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem s...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_s(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
  int i;
    /* save [fast]
     *   Save schematic if modified. Does not ask confirmation!
     *   if 'fast' is given it is passed to save_schematic() to avoid
     *   updating window/tab/sim button states */
    if(!strcmp(argv[1], "save"))
    {
      int fast = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(xctx->readonly) {
        Tcl_SetResult(interp, "xschem save: schematic is read-only (use 'saveas' to write a copy)", TCL_STATIC);
        return TCL_ERROR;
      }
      dbg(1, "scheduler(): saving: current schematic\n");
      for(i = 2; i < argc; i++) {
        if(!strcmp(argv[i], "fast")) fast |= 1;
      }

      if(!strcmp(xctx->sch[xctx->currsch], "")) {   /* check if unnamed schematic, use saveas in this case... */
        /* not logged here: saveas() records the resolved `xschem saveas {f} schematic`
         * at its dialog arm; a bare `xschem save` line would re-open the dialog on replay */
        saveas(NULL, SCHEMATIC);
      } else {
        save(0, fast);
        /* self-log at the BRANCH, not inside save() (0062): save() is a shared
         * confirm-wrapper also entered from go_back/descend/window-close flows, where a
         * log would emit phantom saves inside already-logged composite verbs (the
         * delete()-class hazard, atom 2). Covers toolbar FileSave, File>Save
         * (menu_action_logged dedups), tab-menu Save, mouse binds, CIW/script. Ctrl-S
         * saves inline in callback.c and logs at its own site. Policy: an unmodified
         * no-op save still logs (slice-1 norm -- and save() force-writes when the
         * on-disk mtime changed, so gating on `modified` would drop real writes);
         * `save fast` stays SILENT: fast is passed only by internal cellview/attr
         * machinery that saves a temporarily-loaded file between unlogged `load
         * -keep_symbols` calls -- a logged line would replay against the wrong file
         * (same machinery axis as the setprop -fast gate, slice 5). */
        if(!fast) log_action("xschem save");
      }
    }

    /* saveas [file] [type]
     *   save current schematic as 'file'
     *   if file is empty ({}) use current schematic name
     *   as defalt and prompt user with file selector
     *   'type' is used used to set/change file extension:
     *     schematic: save as schematic (*.sch)
     *     symbol: save as symbol (*.sym)
     *     If not specified default to schematic (*.sch)
     *   Does not ask confirmation if file name given
     */
    else if(!strcmp(argv[1], "saveas"))
    {
      const char *fptr;
      char f[PATH_MAX + 100];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}

      if(argc > 2) {
        my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[2], home_dir);
        tcleval(f);
        my_strncpy(f, tclresult(), S(f));
      }
      if(argc > 3) {
        fptr = !strcmp(f, "") ? NULL : f;
        if(!strcmp(argv[3], "schematic")) saveas(fptr, SCHEMATIC);
        else if(!strcmp(argv[3], "symbol")) saveas(fptr, SYMBOL);
        else saveas(fptr, SCHEMATIC);
      }
      else if(argc > 2) {
        fptr = !strcmp(f, "") ? NULL : f;
        saveas(fptr, SCHEMATIC);
      }
      else saveas(NULL, SCHEMATIC);
      /* after Save As the current file may have changed: re-derive read-only from
       * the new file's writability (a cancelled dialog leaves the file unchanged) */
      if(xctx) {
        xctx->readonly = !file_writable(xctx->sch[xctx->currsch]);
        set_modify(-1); /* refresh title marker */
      }
    }

    /* sch_pinlist
     *   List a 2-item list of all pins  and directions of current schematic
     *   Example: xschem sch_pinlist
     *   -->  {PLUS} {in} {OUT} {out} {MINUS} {in} {VCC} {inout} {VSS} {inout}
     */
    else if(!strcmp(argv[1], "sch_pinlist"))
    {
      int i, first = 1;
      char *dir = NULL;
      const char *lab;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 0; i < xctx->instances; ++i) {
        if( !strcmp((xctx->inst[i].ptr + xctx->sym)->type, "ipin") ) dir="in";
        else if( !strcmp((xctx->inst[i].ptr + xctx->sym)->type, "opin") ) dir="out";
        else if( !strcmp((xctx->inst[i].ptr + xctx->sym)->type, "iopin") ) dir="inout";
        else dir = NULL;
        if(dir) {
          lab = xctx->inst[i].lab;
          if(first == 0) Tcl_AppendResult(interp, " ", NULL);
          Tcl_AppendResult(interp, "{", lab, "} {", dir, "}", NULL);
          first = 0;

        }
      }
    }

    /* schematic_in_new_window [new_process] [nodraw] [force] [window]
     *   When a symbol is selected edit corresponding schematic
     *   in a new tab/window if not already open.
     *   If nothing selected open another window of the second
     *   schematic (issues a warning).
     *   if 'new_process' is given start a new xschem process
     *   if 'nodraw' is given do not draw loaded schematic
     *   if 'window' is given force a real top-level window even in tabbed mode
     *     (doc/claude/specs/multi_window_detach.md)
     *   returns '1' if a new schematic was opened, 0 otherwise */
    else if(!strcmp(argv[1], "schematic_in_new_window"))
    {
      int res = 0;
      int new_process = 0;
      int nodraw = 0;
      int force = 0;
      int win = 0;
      int i;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 2; i < argc; i++) {
        if(!strcmp(argv[i], "new_process")) new_process = 1;
        if(!strcmp(argv[i], "nodraw")) nodraw = 1;
        if(!strcmp(argv[i], "force")) force = 1;
        if(!strcmp(argv[i], "window")) win = 1;
      }
      res = schematic_in_new_window(new_process, !nodraw, force, win);
      Tcl_SetResult(interp, my_itoa(res), TCL_VOLATILE);
    }

    /* search regex|exact select tok val [no_match_case] [nodraw]
     *   Search instances / wires / rects / texts with attribute string containing 'tok'
     *   and value 'val'
     *   search can be exact ('exact') or as a regular expression ('regex')
     *   select:
     *      0 : highlight matching instances
     *      1 : select matching instances
     *     -1 : unselect matching instances
     *   'tok' set as:
     *       propstring : will search for 'val' in the entire
     *       *instance* attribute string.
     *       cell::propstring : will search for 'val' in the entire
     *       *symbol* attribute string.
     *       cell::name : will search for 'val' in the symbol name
     *       cell::<attr> will search for 'val' in symbol attribute 'attr'
     *         example: xschem search regex 0 cell::template GAIN=100
     *    if 'no_match_case' is specified do not consider case sensitivity in search
     *    if 'nodraw' is specified do not draw search result
     */
    else if(!strcmp(argv[1], "search") || !strcmp(argv[1], "searchmenu"))
    {
      /*   0      1         2        3       4   5        6      */
      /*                           select                        */
      /* xschem search regex|exact 0|1|-1   tok val [match_case] */
      int select, r;
      int match_case = 1;
      int draw = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 6) {
        int i;
        for(i = 0; i < argc; i++) {
          if(!strcmp(argv[i], "no_match_case")) match_case = 0;
          if(!strcmp(argv[i], "nodraw")) draw = 0;
        }
      }
      if(argc < 6) {
        Tcl_SetResult(interp, "xschem search requires 4 or 5 additional fields.", TCL_STATIC);
        return TCL_ERROR;
      }
      if(argc > 5) {
        select = atoi(argv[3]);
        if(!strcmp(argv[2], "regex") )  r = search(argv[4],argv[5],0,select, match_case, draw);
        else  r = search(argv[4],argv[5],1,select, match_case, draw);
        if(r == 0) {
          if(has_x && !strcmp(argv[1], "searchmenu"))
            tcleval("tk_messageBox -type ok -parent [xschem get topwindow] -message {Not found.}");
          Tcl_SetResult(interp, "0", TCL_STATIC);
        } else {
          Tcl_SetResult(interp, "1", TCL_STATIC);
        }
        return TCL_OK;
      }
    }

    /* select instance|wire|text id [clear] [fast] [nodraw]
     * select rect|line|poly|arc layer id [clear] [fast]
     * Select indicated instance or wire or text, or
     * Select indicated (layer, number) rectangle, line, polygon, arc.
     * For 'instance' 'id' can be the instance name or number
     * for all other objects 'id' is the position in the respective arrays
     * if 'clear' is specified does an unselect operation
     * if 'fast' is specified avoid sending information to infowindow and status bar
     * if 'nodraw' is given do not draw selection
     * returns 1 if something selected, 0 otherwise */
    else if(!strcmp(argv[1], "select"))
    {
      short unsigned int  sel = SELECTED;
      int fast = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem select: missing arguments.", TCL_STATIC);
        return TCL_ERROR;
      } else if(argc < 5 && (!strcmp(argv[2], "rect") || !strcmp(argv[2], "line") ||
                     !strcmp(argv[2], "poly") || !strcmp(argv[2], "arc") ||
                     !strcmp(argv[2], "pin"))) {
        Tcl_SetResult(interp, "xschem select: missing arguments.", TCL_STATIC);
        return TCL_ERROR;
      } else if(argc < 4) {
        Tcl_SetResult(interp, "xschem select: missing arguments.", TCL_STATIC);
        return TCL_ERROR;
      }
      if(argc > 4) {
       int i;
       for(i = 4; i < argc; i++) {
         if(!strcmp(argv[i], "clear")) sel = 0;
         if(!strcmp(argv[i], "fast")) fast |= 1;
         if(!strcmp(argv[i], "nodraw")) fast |= 2;
       }
      }
      if(!strcmp(argv[2], "instance") && argc > 3) {
        int n;
        /* find by instance name  or number*/
        n = get_instance(argv[3]);
        if(n >= 0) {
           select_element(n, sel, fast, 1);
           xctx->ui_state |= SELECTION;
        }
        Tcl_SetResult(interp, (n >= 0) ? "1" : "0" , TCL_STATIC);
      }
      /* xschem select pin <inst> <pinidx> [clear|nodraw] : select/deselect one pin of
       * an instance. <inst> is a name or index (get_instance), <pinidx> indexes the
       * symbol's PINLAYER pins. Primarily a headless hook for tests + future pin ops.
       * See doc/claude/specs/pin_selection.md */
      else if(!strcmp(argv[2], "pin") && argc > 4) {
        int n = get_instance(argv[3]);
        int p = atoi(argv[4]);
        int rects = (n >= 0 && xctx->inst[n].ptr >= 0) ?
                    (xctx->inst[n].ptr + xctx->sym)->rects[PINLAYER] : 0;
        int valid = (n >= 0 && p >= 0 && p < rects);
        if(valid) {
          select_pin(n, p, sel, fast);
          if(sel) xctx->ui_state |= SELECTION;
          rebuild_selected_array();
        }
        Tcl_SetResult(interp, valid ? "1" : "0" , TCL_STATIC);
      }
      else if(!strcmp(argv[2], "wire") && argc > 3) {
        int n=atoi(argv[3]);
        int valid = n < xctx->wires && n >= 0;
        if(valid) {
          select_wire(n, sel, fast, 1);
          xctx->ui_state |= SELECTION;
        }
        Tcl_SetResult(interp, valid ? "1" : "0" , TCL_STATIC);
      }
      else if(!strcmp(argv[2], "line") && argc > 4) {
        int c=atoi(argv[3]);
        int n=atoi(argv[4]);
        int valid = n < xctx->lines[c] && n >= 0 && c < cadlayers && c >= 0;
        if(valid) {
          select_line(c, n, sel, fast, 0);
          xctx->ui_state |= SELECTION;
        }
        Tcl_SetResult(interp, valid ? "1" : "0" , TCL_STATIC);
      }
      else if(!strcmp(argv[2], "rect") && argc > 4) {
        int c=atoi(argv[3]);
        int n=atoi(argv[4]);
        int valid = n < xctx->rects[c] && n >= 0 && c < cadlayers && c >= 0;
        if(valid) {
          select_box(c, n, sel, fast, 0);
          xctx->ui_state |= SELECTION;
        }
        Tcl_SetResult(interp, valid ? "1" : "0" , TCL_STATIC);
      }
      else if(!strcmp(argv[2], "arc") && argc > 4) {
        int c=atoi(argv[3]);
        int n=atoi(argv[4]);
        int valid = n < xctx->arcs[c] && n >= 0 && c < cadlayers && c >= 0;
        if(valid) {
          select_arc(c, n, sel, fast, 0);
          xctx->ui_state |= SELECTION;
        }
        Tcl_SetResult(interp, valid ? "1" : "0" , TCL_STATIC);
      }
      else if(!strcmp(argv[2], "poly") && argc > 4) {
        int c=atoi(argv[3]);
        int n=atoi(argv[4]);
        int valid = n < xctx->polygons[c] && n >= 0 && c < cadlayers && c >= 0;
        if(valid) {
          select_polygon(c, n, sel, fast, 0);
          xctx->ui_state |= SELECTION;
        }
        Tcl_SetResult(interp, valid ? "1" : "0" , TCL_STATIC);
      }
      else if(!strcmp(argv[2], "text") && argc > 3) {
        int n=atoi(argv[3]);
        int valid = n < xctx->texts && n >= 0;
        if(valid) {
          select_text(n, sel, fast, 0);
          xctx->ui_state |= SELECTION;
        }
        Tcl_SetResult(interp, valid ? "1" : "0" , TCL_STATIC);
      }
      drawtemparc(xctx->gc[SELLAYER], END, 0.0, 0.0, 0.0, 0.0, 0.0);
      drawtemprect(xctx->gc[SELLAYER], END, 0.0, 0.0, 0.0, 0.0);
      drawtempline(xctx->gc[SELLAYER], END, 0.0, 0.0, 0.0, 0.0);
    }

    /* select_at <x> <y> [add] [nodraw]
     *   Select the closest object at SCHEMATIC coordinate (x,y) -- the replayable
     *   form of a mouse click (doc/claude/specs/select_at.md). Default replaces the
     *   current selection (plain click); `add` augments it (shift-click); `nodraw`
     *   skips the redraw. Returns the hit object as one `{type index col id}` row
     *   (== an `xschem selection` row), or "" on a miss. Logs `xschem select_at
     *   x y [add]` via the holding area (like the interactive click): deferred one
     *   action, and a following `descend` absorbs it into a single coordinate-free
     *   line. doc/claude/specs/action_log_absorb.md */
    else if(!strcmp(argv[1], "select_at"))
    {
      double x, y;
      int add = 0, draw = 1, i;
      Selected s;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 4) {
        Tcl_SetResult(interp, "xschem select_at: need <x> <y>.", TCL_STATIC);
        return TCL_ERROR;
      }
      x = atof(argv[2]);
      y = atof(argv[3]);
      for(i = 4; i < argc; i++) {
        if(!strcmp(argv[i], "add")) add = 1;
        else if(!strcmp(argv[i], "nodraw")) draw = 0;
      }
      if(!add) unselect_all(1);
      select_at_suppress_log = 1;        /* the command logs its own line (with `add`) below */
      s = select_object(x, y, SELECTED, 0, NULL);
      select_at_suppress_log = 0;
      rebuild_selected_array();
      if(draw && has_x) draw_selection(xctx->gc[SELLAYER], 0);
      if(s.type) {
        const char *tname;
        int id = -1, n = s.n, c = s.col, k;
        char row[100];
        /* take col from sel_array so the returned row is byte-identical to an
         * `xschem selection` row: find_closest_obj returns col=0 for the flat
         * types (wire/instance/text) whereas the selection enumerator reports the
         * stored col. Match by (type,n); for the per-layer types also match col. */
        for(k = 0; k < xctx->lastsel; k++) {
          if(xctx->sel_array[k].type == s.type && xctx->sel_array[k].n == n &&
             (s.type == WIRE || s.type == ELEMENT || s.type == xTEXT ||
              xctx->sel_array[k].col == s.col)) {
            c = xctx->sel_array[k].col;
            break;
          }
        }
        switch(s.type) {
          case WIRE:    tname = "wire";     id = (int)xctx->wire[n].id; break;
          case xRECT:   tname = "rect";     id = (int)xctx->rect[c][n].id; break;
          case LINE:    tname = "line";     id = (int)xctx->line[c][n].id; break;
          case ELEMENT: tname = "instance"; id = (int)xctx->inst[n].id; break;
          case xTEXT:   tname = "text";     id = (int)xctx->text[n].id; break;
          case POLYGON: tname = "poly";     id = (int)xctx->poly[c][n].id; break;
          case ARC:     tname = "arc";      id = (int)xctx->arc[c][n].id; break;
          default:      tname = "unknown";  break;
        }
        /* Stash (not write): identical to the interactive funnel, so a following
         * `descend` absorbs this into one stable line; else the next action flushes
         * it verbatim. Deferred by one action. doc/claude/specs/action_log_absorb.md */
        log_action_stash_select_at(x, y, add, s.type == ELEMENT ? s.n : -1);
        /* one object -> a BARE `type index col id` row (mirrors `xschem object`'s
         * bare single vs `xschem objects`'/`selection`'s brace-wrapped list rows) */
        my_snprintf(row, S(row), "%s %d %d %d", tname, n, c, id);
        Tcl_SetResult(interp, row, TCL_VOLATILE);
      } else {
        Tcl_ResetResult(interp);
      }
    }

    /* select_all
     *   Selects all objects in schematic */
    else if(!strcmp(argv[1], "select_all"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      select_all();
      Tcl_ResetResult(interp);
    }

    /* select_dangling_nets
     *   Select all nets/labels that are dangling, ie not attached to any non pin/port/probe components
     *   Returns number of selected items (wires,labels) if danglings found, 0 otherwise */
    else if(!strcmp(argv[1], "select_dangling_nets"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      select_dangling_nets();
      Tcl_SetResult(interp, my_itoa(xctx->lastsel), TCL_VOLATILE);
    }

    /* select_grow_connected [x y]
     *   Cadence double-click incremental connected-select
     *   (doc/claude/specs/dblclick_connected_select.md). One escalation step per
     *   call, keyed on a seed:
     *     1st call on a seed -> ring1 (seed + directly-touching wire segments)
     *     2nd  -> ring2 (one more ring of touching segments)
     *     3rd  -> whole net (geometric flood, wires only)
     *     4th+ -> no-op (already whole)
     *   Rings are WIRES ONLY; the seed object (of any type) stays selected. With
     *   [x y] the object under that schematic coord becomes/refreshes the seed and
     *   is added (additively) to the selection; without coords the step runs on the
     *   current selection & seed. Returns the new level (1, 2 or 3). */
    else if(!strcmp(argv[1], "select_grow_connected"))
    {
      int level;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* No log_action here: select_grow_connected_step() self-logs at its core so the
       * double-click gesture (which calls the core directly) is covered too. See select.c
       * and doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md. */
      if(argc >= 4) {
        level = select_grow_connected_step(atof(argv[2]), atof(argv[3]), 1);
      } else {
        level = select_grow_connected_step(0.0, 0.0, 0);
      }
      Tcl_SetResult(interp, my_itoa(level), TCL_VOLATILE);
    }

    /* select_hilight_net
     *   Select all highlight objects (wires, labels, pins, instances) */
    else if(!strcmp(argv[1], "select_hilight_net"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      select_hilight_net();
      Tcl_ResetResult(interp);
    }

    /* select_inside x1 y1 x2 y2 [sel]
     *   Select all objects inside the indicated area
         if [sel] is set to '0' do an unselect operation */
    else if(!strcmp(argv[1], "select_inside"))
    {
      int sel = SELECTED;
      double x1, y1, x2, y2;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      /* issue 0075: guard argc BEFORE the atof(argv[2..5]) reads. Without this a short
       * command (e.g. the `xschem select_inside x1` typo for `select instance x1`) reaches
       * atof(argv[3]) == atof(NULL) -> SIGSEGV -> emergency-save -> whole editor dies. */
      if(argc < 6) {
        Tcl_SetResult(interp,
          "xschem select_inside: usage: select_inside x1 y1 x2 y2 [0]", TCL_STATIC);
        return TCL_ERROR;
      }
      if(argc > 6 && argv[6][0] == '0') sel = 0;
      x1 = atof(argv[2]);
      y1 = atof(argv[3]);
      x2 = atof(argv[4]);
      y2 = atof(argv[5]);
      select_inside(tclgetboolvar("enable_stretch"), x1, y1, x2, y2, sel);
      Tcl_ResetResult(interp);
    }

    /* selected_set [what]
     *   Return a list of selected instance names
     *   If what is not given or set to 'inst' return list of selected instance names
     *   If what set to 'rect' return list of selected rectangles with their coordinates
     *   If what set to 'text' return list of selected texts with their coordinates */
    else if(!strcmp(argv[1], "selected_set"))
    {
      int n, i, first = 1;
      int what = ELEMENT;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}

      if(argc > 2) {
        if(!strcmp(argv[2], "rect")) what = xRECT;
        else if(!strcmp(argv[2], "text")) what = xTEXT;
      }
      rebuild_selected_array();
      for(n=0; n < xctx->lastsel; ++n) {
        if(what == xRECT &&  xctx->sel_array[n].type == xRECT) {
          char col[30], num[30], coord[200];
          int c = xctx->sel_array[n].col;
          i = xctx->sel_array[n].n;
          my_strncpy(col, my_itoa(c), S(col));
          my_strncpy(num, my_itoa(i), S(num));
          my_snprintf(coord, S(coord), "%g %g %g %g",
            xctx->rect[c][i].x1, xctx->rect[c][i].y1, xctx->rect[c][i].x2, xctx->rect[c][i].y2);
          if(first == 0) Tcl_AppendResult(interp, "\n", NULL);
          first = 0;
          Tcl_AppendResult(interp,col, " ", num, " ", coord , NULL);
        } else if(what == xTEXT &&  xctx->sel_array[n].type == xTEXT) {
          char num[30], coord[200];
          i = xctx->sel_array[n].n;
          my_strncpy(num, my_itoa(i), S(num));
          my_snprintf(coord, S(coord), "%g %g %d %d",
          xctx->text[i].x0, xctx->text[i].y0, xctx->text[i].rot, xctx->text[i].flip);
          if(first == 0) Tcl_AppendResult(interp, "\n", NULL);
          first = 0;
          Tcl_AppendResult(interp, num, " ", coord , " {", xctx->text[i].txt_ptr, "}", NULL);
        } else if(what == ELEMENT && xctx->sel_array[n].type == ELEMENT) {
          i = xctx->sel_array[n].n;
          if(first == 0)  Tcl_AppendResult(interp, " ", NULL);
          Tcl_AppendResult(interp, "{", xctx->inst[i].instname, "}", NULL);
          first = 0;
        }
      }
    }

    /* selected_wire
     *  Return list of selected nets */
    else if(!strcmp(argv[1], "selected_wire"))
    {
      int n, i, first = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      rebuild_selected_array();
      for(n=0; n < xctx->lastsel; ++n) {
        if(xctx->sel_array[n].type == WIRE) {
          i = xctx->sel_array[n].n;
          if(first == 0)  Tcl_AppendResult(interp, " ", NULL);
          Tcl_AppendResult(interp, "{", get_tok_value(xctx->wire[i].prop_ptr, "lab",0), "}", NULL);
          first = 0;
        }
      }
    }

    /* selection
     *   Return the WHOLE current selection as a Tcl list, one
     *   '{type index col id}' element per selected object, across all seven
     *   object types (unlike 'selected_set', which reports only
     *   instances/rect/text and is blind to wires/lines/polygons/arcs).
     *     type  : wire|instance|rect|line|poly|arc|text
     *     index : the object's array index in its xctx array
     *     col   : its layer (WIRELAYER/TEXTLAYER for the flat-array types)
     *     id    : the session-stable wire id (see 'wire_id') for wire rows,
     *             -1 for the other types (which have no stable id yet)
     *   The full selection lives in xctx->sel_array (rebuilt here); this is
     *   the generic enumerator that makes the selection scriptable. */
    else if(!strcmp(argv[1], "selection"))
    {
      int n, i, c, first = 1;
      char row[100];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      rebuild_selected_array();
      for(n = 0; n < xctx->lastsel; ++n) {
        const char *tname;
        /* id is the session-stable wire id for wires, -1 otherwise. Held in an
         * int (not the wire's unsigned id) and printed with %d: ids are small
         * and -1 must render as "-1" — my_snprintf's minimal formatter does not
         * handle %ld and would print an unsigned -1 as 4294967295. */
        int id = -1;
        i = xctx->sel_array[n].n;
        c = xctx->sel_array[n].col;
        switch(xctx->sel_array[n].type) {
          case WIRE:    tname = "wire";     id = (int)xctx->wire[i].id; break;
          case xRECT:   tname = "rect";     id = (int)xctx->rect[c][i].id; break;
          case LINE:    tname = "line";     id = (int)xctx->line[c][i].id; break;
          case ELEMENT: tname = "instance"; id = (int)xctx->inst[i].id; break;
          case xTEXT:   tname = "text";     id = (int)xctx->text[i].id; break;
          case POLYGON: tname = "poly";     id = (int)xctx->poly[c][i].id; break;
          case ARC:     tname = "arc";      id = (int)xctx->arc[c][i].id; break;
          case INST_PIN: tname = "pin";     id = (int)xctx->inst[i].id; break; /* i=inst, c=pin */
          default:      tname = "unknown";  break;
        }
        my_snprintf(row, S(row), "{%s %d %d %d}", tname, i, c, id);
        if(first == 0) Tcl_AppendResult(interp, " ", NULL);
        Tcl_AppendResult(interp, row, NULL);
        first = 0;
      }
    }

    /* send_to_viewer
     *   Send selected wires/net labels/pins/voltage source or ammeter currents to current
     *   open viewer (gaw or bespice) */
    else if(!strcmp(argv[1], "send_to_viewer"))
    {
      int viewer = 0;
      int exists = 0;
      char *viewer_name = NULL;
      char tcl_str[200];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      tcleval("info exists sim");
      if(tclresult()[0] == '1') exists = 1;
      xctx->enable_drill = 0;
      if(exists) {
        viewer = atoi(tclgetvar("sim(spicewave,default)"));
        my_snprintf(tcl_str, S(tcl_str), "sim(spicewave,%d,name)", viewer);
        my_strdup(_ALLOC_ID_, &viewer_name, tclgetvar(tcl_str));
        dbg(1, "send_to_viewer: viewer_name=%s\n", viewer_name);
        if(strstr(viewer_name, "Gaw")) viewer=GAW;
        else if(strstr(viewer_name, "Bespice")) viewer=BESPICE;
        if(viewer) {
          hilight_net(viewer);
          redraw_hilights(0);
          net_hilight_anim_update(); /* Pass 2a: waveform-viewer highlight may add a blink style */
          net_hilight_sync_descend_windows(); /* issue 0073: push into linked descend children */
        }
        my_free(_ALLOC_ID_, &viewer_name);
      }
      Tcl_ResetResult(interp);
    }

    /* set var value
     *   Set C variable 'var' to 'value' */
    else if(!strcmp(argv[1], "set"))
    {
      /* Action-log policy (issue 0066): only three kinds of `set` self-log here --
       * (a) saved-content mutations (header_text below; rectcolor+selection ->
       * change_layer) log a replayable command + read-only-guard; (b) edit-geometry
       * state the log must reproduce (cadsnap/cadgrid) logs its resolved value. Every
       * other `set <var>` is pure session-config/display preference and stays UNLOGGED
       * by design -- that is full-session config replay, explicitly out of v1 (action
       * logging spec §6). Do not add blanket logging here; re-flagging them is expected. */
      if(argc > 3) {
        if(argv[2][0] < 'n') {
          if(!strcmp(argv[2], "actionlog_suppress")) {
            /* Absolute set of the replay/composite log-suppress depth counter
             * (issue 0071 Refactor A step 2). A HARD set: 0 clears ANY nesting,
             * unlike the balanced `xschem log_action -suppress push|pop`. Provided
             * for scripts/tests that want a flat on/off; the seams use push/pop.
             * NOT self-logged (a control command; and once >0 the log_action that
             * would record it is already a no-op). Not a saved-content edit -> no
             * read-only guard. C int, not tcl-mirrored (globals.c). */
            actionlog_suppress = atoi(argv[3]);
            if(actionlog_suppress < 0) actionlog_suppress = 0;
          }
          else if(!strcmp(argv[2], "graph_snap_cursor")) { /* item 9: per-window snap arming */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->graph_snap = atoi(argv[3]) ? 1 : 0;
            /* disarming must also take the painted glyph down, or it would sit
             * frozen on the canvas with no pump left to erase it */
            if(!xctx->graph_snap) graph_snap_clear();
          }
          /* xschem set graph_preview <gi> <wave> <scale> [<gi> <ni> ...]
           * xschem set graph_preview 0            -> disarm
           * Viewer plan item 6: draw NODE <wave> of graph <gi> vertically
           * shrunk by <scale> about the plot box centre, on screen only. Purely
           * transient: no prop token, no model write, no undo point, and
           * draw_graph applies it only for flags & 16 so no export sees it.
           * A scale of 0 (or a short argument list) disarms, which is also the
           * calloc default -- there is no sentinel to maintain.
           * Caller redraws; this does not, so a motion event can arm and repaint
           * in one place.
           * Issue 0192: the three-argument form is unchanged and is the
           * single-trace arm; TRAILING <gi> <ni> PAIRS extend it to the whole
           * set a multi-trace drag carries. The head is element 0 either way, so
           * `xschem get graph_preview` answers exactly what it always did and
           * the whole set is read through `xschem get graph_preview_set`.
           * A trailing odd argument (a gi with no ni) is ignored rather than
           * refused -- this is chrome, and half a pair is not worth a Tcl error. */
          else if(!strcmp(argv[2], "graph_preview")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(argc > 5) {
              int pgi[GRAPH_MAX_PREVIEW_WAVES], pwv[GRAPH_MAX_PREVIEW_WAVES];
              int pn = 0, a;
              pgi[0] = atoi(argv[3]);
              pwv[0] = atoi(argv[4]);
              pn = 1;
              for(a = 6; a + 1 < argc && pn < GRAPH_MAX_PREVIEW_WAVES; a += 2) {
                pgi[pn] = atoi(argv[a]);
                pwv[pn] = atoi(argv[a + 1]);
                pn++;
              }
              graph_preview_arm(pgi, pwv, pn, atof(argv[5]));
            } else {
              graph_preview_arm(NULL, NULL, 0, 0.0);
            }
          }
          else if(!strcmp(argv[2], "cadgrid")) { /* set cad grid (default: 20) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            set_grid( atof(argv[3]) );
            /* self-log the RESOLVED grid (0066): set_grid maps 0 -> the default, so
             * log cadgrid read back, not argv[3] -- one replayable line for every
             * entry point (View-menu dialog / statusbar entry / script). Edit-geometry
             * state, not saved content -> no read-only guard. */
            log_action("xschem set cadgrid %.10g", tclgetdoublevar("cadgrid"));
          }
          else if(!strcmp(argv[2], "cadsnap")) { /* set mouse snap (default: 10) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            set_snap( atof(argv[3]) );
            change_linewidth(-1.);
            draw();
            /* self-log the RESOLVED snap (0066): see cadgrid above. The bindable
             * view.set_snap_value dialog action is nolog'd (callback.c) so the async
             * input_line prompt does not also log -- the value logs here at the core. */
            log_action("xschem set cadsnap %.10g", tclgetdoublevar("cadsnap"));
          }
          else if(!strcmp(argv[2], "change_lw")) { /* allow change line width when zooming */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->change_lw = atoi(argv[3]);
            dbg(1, "xschem change_lw: change_lw = %d\n", xctx->change_lw);
            tclsetboolvar("change_lw", xctx->change_lw);
          }
          else if(!strcmp(argv[2], "color_ps")) { /* set color psoscript (1 or 0) */
            color_ps=atoi(argv[3]);
          }
          else if(!strcmp(argv[2], "crosshair_layer")) { /* set layer for mouse crosshair */
             int c = atoi(argv[3]);
             tclsetintvar("crosshair_layer", c);
             xctx->crosshair_layer = c;
             if(xctx->crosshair_layer < 0 ) xctx->crosshair_layer = 2;
             if(xctx->crosshair_layer >= cadlayers ) xctx->crosshair_layer = 2;
          }
          else if(!strcmp(argv[2], "constr_mv")) { /* set constrained move (1=horiz, 2=vert, 0=none) */
            xctx->constr_mv = atoi(argv[3]);
            if(xctx->constr_mv < 0 || xctx->constr_mv > 2) xctx->constr_mv = 0;
          }
          else if(!strcmp(argv[2], "cursor1_x")) { /* set graph cursor1 position */
            xctx->graph_cursor1_x = atof_spice(argv[3]);

            #if 0
            if(xctx->rects[GRIDLAYER] > 0) {
              Graph_ctx *gr = &xctx->graph_struct;
              xRect *r = &xctx->rect[GRIDLAYER][0];
              if(r->flags & 1) {
                backannotate_at_cursor_b_pos(r, gr);
              }
            }
            #endif
          }
          else if(!strcmp(argv[2], "cursor2_x")) { /* set graph cursor2 position */
            int floaters = there_are_floaters();
            xctx->graph_cursor2_x = atof_spice(argv[3]);

            if(xctx->rects[GRIDLAYER] > 0) {
              Graph_ctx *gr = &xctx->graph_struct;
              xRect *r = &xctx->rect[GRIDLAYER][0];
              if(r->flags & 1) {
                if(xctx->graph_flags & 4) {
                  backannotate_at_cursor_b_pos(r, gr);
                  if(floaters) set_modify(-2); /* update floater caches to reflect actual backannotation */
                }
              }
            }
          }
          else if(!strcmp(argv[2], "draw_window")) { /* set drawing to window (1 or 0) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->draw_window=atoi(argv[3]);
          }
          else if(!strcmp(argv[2], "fix_broken_tiled_fill")) { /* alternate drawing method for broken GPUs */
            fix_broken_tiled_fill = atoi(argv[3]);
          }
          else if(!strcmp(argv[2], "fix_mouse_coord")) { /* fix for wrong mouse coords in RDP software */
            fix_mouse_coord = atoi(argv[3]);
          }
          else if(!strcmp(argv[2], "format")) { /* set name of custom format attribute used for netlisting */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_strdup(_ALLOC_ID_, &xctx->custom_format, argv[3]);
          }
          else if(!strcmp(argv[2], "header_text")) { /* set header metadata (used for license info) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(!xctx->header_text || strcmp(xctx->header_text, argv[3])) {
              /* header/license text is saved schematic metadata -> a content edit
               * (0066). Refuse on a read-only view like the sibling set rectcolor
               * (0041) -- return TCL_ERROR so a caller/replay `catch`es it -- then
               * self-log the replayable command. Gated inside the "value changed"
               * guard so a no-op set logs nothing and pushes no undo. log_action_argv
               * (Tcl_Merge) keeps arbitrary/multi-line license text source-able. */
              if(scheduler_readonly_reject(interp, "set header_text")) return TCL_ERROR;
              set_modify(1); xctx->push_undo();
              my_strdup2(_ALLOC_ID_, &xctx->header_text, argv[3]);
              log_action_argv(argc, (const char *const *)argv);
            }
          }
          else if(!strcmp(argv[2], "en_pin_select")) { /* enable selecting individual instance pins */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->en_pin_select = atoi(argv[3]);
            /* keep the mirrored Tcl var in sync so a CIW 'xschem set en_pin_select 1'
             * is not later clobbered by housekeeping_ctx pushing the (stale) Tcl var
             * back to C on a window/tab focus change (pin_selection.md). */
            tclsetboolvar("en_pin_select", xctx->en_pin_select);
          }
          else if(!strcmp(argv[2], "enable_stretch")) { /* attached-wire stretch on move (edit-mode) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            /* absolute-set / replay arm for toggle_stretch_cmd's self-log (0062 tail /
             * atom 16): the toggle records `xschem set enable_stretch <resolved>`, this
             * applies it. The effect is only the mirrored tcl var (toggle_stretch_cmd sets
             * just that). NO self-log here -- this IS the replay form (coordinate/
             * replay-form-bypass): a log would double every replay. Edit-mode session
             * config, not saved content -> no read-only guard (0066 policy b, like cadsnap). */
            tclsetboolvar("enable_stretch", atoi(argv[3]) ? 1 : 0);
          }
          else if(!strcmp(argv[2], "hide_symbols")) { /* set to 0,1,2 for various hiding level of symbols */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->hide_symbols=atoi(argv[3]);
          }
          else if(!strcmp(argv[2], "hilight_color")) { /* set hilight color for next hilight */
            int c = atoi(argv[3]);
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(c >= cadlayers) c = 4;
            xctx->hilight_color= c;
          }

          else if(!strcmp(argv[2], "infowindow_text")) { /* ERC messages */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_strdup(_ALLOC_ID_, &xctx->infowindow_text, argv[3]);
          }
          else if(!strcmp(argv[2], "intuitive_interface")) { /* set intuitive interface */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->intuitive_interface = atoi(argv[3]);
          }
          else if(!strcmp(argv[2], "line_width")) /* set line width */
          {
            double w;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            w = atof(argv[3]);
            change_linewidth(w);
            tclsetdoublevar("line_width", w);
            Tcl_ResetResult(interp);
          }
        } else { /* argv[2][0] >= 'n' */
          if(!strcmp(argv[2], "netlist_name")) { /* set custom netlist name */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_strncpy(xctx->netlist_name, argv[3], S(xctx->netlist_name));
          }
          else if(!strcmp(argv[2], "netlist_type")) /* set netlisting mode (spice, verilog, vhdl, tedax, symbol) */
          {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(!strcmp(argv[3], "spice")){
              xctx->netlist_type=CAD_SPICE_NETLIST;
            }
            else if(!strcmp(argv[3], "vhdl")) {
              xctx->netlist_type=CAD_VHDL_NETLIST;
            }
            else if(!strcmp(argv[3], "spectre")) {
              xctx->netlist_type=CAD_SPECTRE_NETLIST;
            }
            else if(!strcmp(argv[3], "verilog")) {
              xctx->netlist_type=CAD_VERILOG_NETLIST;
            }
            else if(!strcmp(argv[3], "tedax")) {
              xctx->netlist_type=CAD_TEDAX_NETLIST;
            }
            else if(!strcmp(argv[3], "symbol")) {
              xctx->netlist_type=CAD_SYMBOL_ATTRS;
            }
            else {
              dbg(0, "Warning: undefined netlist format: %s\n", argv[3]);
            }
            set_tcl_netlist_type();
          }
          else if(!strcmp(argv[2], "no_draw")) { /* set no drawing flag (0 or 1) */
            int s = atoi(argv[3]);
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->no_draw=s;
          }
          else if(!strcmp(argv[2], "no_grid")) { /* per-window grid/origin suppression (item 18) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->no_grid = atoi(argv[3]) ? 1 : 0;
          }
          /* xschem set no_snap 0|1
           * "this canvas has no schematic snap grid" (issue 0177). PER CONTEXT, like
           * no_grid above -- `cadsnap` is a global the waveform viewer has no business
           * sharing. Consulted at the SOURCE in callback() (where mousex_snap is born)
           * and by the two schematic pointer glyphs, so setting it once covers every
           * downstream reader instead of one override per handler. */
          else if(!strcmp(argv[2], "no_snap")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->no_snap = atoi(argv[3]) ? 1 : 0;
          }
          /* xschem set wave_viewer 0|1
           * "this context is a waveform viewer, not a schematic" (issue 0172). PER
           * CONTEXT, like no_grid / no_snap above, and stamped by wviewer::open in the
           * same block. Read by is_pristine_untitled(), which refuses to hand a viewer
           * to an open as a reuse target. Settable from Tcl both because that is where
           * the viewer is built and because it is what lets a regression test brand a
           * buffer as a viewer HEADLESSLY, with no Tk and no DISPLAY. */
          else if(!strcmp(argv[2], "wave_viewer")) {
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->wave_viewer = atoi(argv[3]) ? 1 : 0;
          }
          else if(!strcmp(argv[2], "readonly")) { /* set window read-only (0 or 1); refresh title */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->readonly = atoi(argv[3]) ? 1 : 0;
            set_modify(-1); /* force window-title refresh to show/clear the marker */
          }
          else if(!strcmp(argv[2], "no_undo")) { /* set to 1 to disable undo */
            int s = atoi(argv[3]);
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->no_undo=s;
          }
          else if(!strcmp(argv[2], "orthogonal_wiring")) { /* orthogonal (manhattan) wire drawing (edit-mode) */
            int v = atoi(argv[3]) ? 1 : 0;
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            /* absolute-set / replay arm for toggle_orthogonal_wiring_cmd's self-log (0062
             * tail / atom 16). Reproduces the cmd's FULL effect, not just the tcl var:
             * turning it OFF also zeroes manhattan_lines, and either way redraws the rubber
             * layers -- exactly toggle_orthogonal_wiring_cmd (callback.c). NO self-log here
             * (this IS the replay form -> no double-log on replay); edit-mode config, no
             * read-only guard (0066 policy b). */
            tclsetboolvar("orthogonal_wiring", v);
            if(!v) xctx->manhattan_lines = 0;
            redraw_w_a_l_r_p_z_rubbers(1);
          }
          else if(!strcmp(argv[2], "pending_fullzoom")) {
            /* arm a deferred full-zoom: the next ConfigureNotify with valid (mapped,
             * >1x1) geometry performs zoom_full() in resetwin(). Used by the new-window
             * descend paths, whose zoom_full() runs before the just-created window has
             * settled to its real size, so the immediate view is computed for the wrong
             * geometry (blank / off-screen until a manual F). See issue 0035/0037. */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->pending_fullzoom = atoi(argv[3]);
          }
          else if(!strcmp(argv[2], "raw_level")) { /* set hierarchy level loaded raw file refers to */
            int n = atoi(argv[3]);
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            if(n >= 0 && n <= xctx->currsch) {
              xctx->raw->level = atoi(argv[3]);
              my_strdup2(_ALLOC_ID_, &xctx->raw->schname, xctx->sch[xctx->raw->level]);
              Tcl_SetResult(interp, my_itoa(n), TCL_VOLATILE);
            } else {
              Tcl_SetResult(interp, "-1", TCL_VOLATILE);
            }
          }
          else if(!strcmp(argv[2], "rectcolor")) { /* set current layer (0, 1, .... , cadlayers-1) */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->rectcolor=atoi(argv[3]);
            if(xctx->rectcolor < 0 ) xctx->rectcolor = 0;
            if(xctx->rectcolor >= cadlayers ) xctx->rectcolor = cadlayers - 1;
            rebuild_selected_array();
            /* A bare layer-cursor pick (no selection) is pure display state and stays
             * unlogged (issue 0066: pure-display sets are nolog). Only when there is a
             * selection does this become a content edit -- change_layer() recolors the
             * selected objects -- so log THAT, and refuse it on a read-only view. */
            if(xctx->lastsel) {
              /* Reject on a read-only view like the other mutators -- and return
               * TCL_ERROR (not a silent TCL_OK) so a caller/replay `catch`es it. */
              if(scheduler_readonly_reject(interp, "set rectcolor")) return TCL_ERROR;
              change_layer();
              log_action("xschem set rectcolor %d", xctx->rectcolor);
            }
          }
          else if(!strcmp(argv[2], "sch_to_compare")) { /* set name of schematic to compare current window with */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_strncpy(xctx->sch_to_compare, abs_sym_path(argv[3], ""), S(xctx->sch_to_compare));
          }
          else if(!strcmp(argv[2], "schsymbolprop")) { /* set global symbol attribute string */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_strdup(_ALLOC_ID_, &xctx->schsymbolprop, argv[3]);
          }
          else if(!strcmp(argv[2], "schprop")) { /* set schematic global spice attribute string */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_strdup(_ALLOC_ID_, &xctx->schprop, argv[3]);
          }
          else if(!strcmp(argv[2], "schverilogprop")) { /* set schematic global verilog attribute string */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_strdup(_ALLOC_ID_, &xctx->schverilogprop, argv[3]);
          }
          else if(!strcmp(argv[2], "schspectreprop")) { /* set schematic global spectre attribute string */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_strdup(_ALLOC_ID_, &xctx->schspectreprop, argv[3]);
          }
          else if(!strcmp(argv[2], "schvhdlprop")) { /* set schematic global vhdl attribute string */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_strdup(_ALLOC_ID_, &xctx->schvhdlprop, argv[3]);
          }
          else if(!strcmp(argv[2], "schtedaxprop")) { /* set schematic global tedax attribute string */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            my_strdup(_ALLOC_ID_, &xctx->schtedaxprop, argv[3]);
          }
          else if(!strcmp(argv[2], "text_svg")) { /* set to 1 to use svg <text> elements */
            text_svg=atoi(argv[3]);
          }
          else if(!strcmp(argv[2], "semaphore")) { /* debug */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            dbg(1, "scheduler(): set semaphore to %s\n", argv[3]);
            xctx->semaphore=atoi(argv[3]);
          }
          else if(!strcmp(argv[2], "show_hidden_texts")) { /* set to 1 to enable showing texts with attr hide=true */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            dbg(1, "scheduler(): set show_hidden_texts to %s\n", argv[3]);
            xctx->show_hidden_texts=atoi(argv[3]);
          }
          else if(!strcmp(argv[2], "sym_txt")) { /* set to 0 to hide symbol texts */
            if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
            xctx->sym_txt=atoi(argv[3]);
          }
          else {
            *cmd_found = 0;
          }
        } /* argv[2][0] >= 'n' */
      } /* if(argc > 3 */
    }
    /************ end xschem set subcommands *************/
    /* set_different_tok str new_str old_str
     *   Return string 'str' replacing/adding/removing tokens that are
     *   different between 'new_str' and 'old_str' */
    else if(!strcmp(argv[1], "set_different_tok") )
    {
      char *s = NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 5) {Tcl_SetResult(interp, "Missing arguments", TCL_STATIC);return TCL_ERROR;}
      my_strdup(_ALLOC_ID_, &s, argv[2]);
      set_different_token(&s, argv[3], argv[4]);
      Tcl_SetResult(interp, s, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &s);
    }

    /* set_modify [n]
     *   Force modify status on current schematic
     *   integer 'n':
     *   0 : clear modified flag, update title and tab names, upd. simulation button colors.
     *   1 : set modified flag, update title and tab names, upd. simulation button colors, rst floater caches.
     *   2 : clear modified flag, do nothing else.
     *   3 : set modified flag, do nothing else.
     *  -1 : set title, rst floater caches.
     *  -2 : rst floater caches, update simulation button colors (Simulate, Waves, Netlist).
     */
    /* set_action_log_cmd action_id tcl_cmd
     *   Action-log Layer A: register the canonical replayable command recorded
     *   when the C-backed action <action_id> dispatches. Pushed from
     *   actions.csv by xschem.tcl at startup (single source of commands).
     *   Returns 1 if the id exists in the C action registry, 0 otherwise. */
    else if(!strcmp(argv[1], "set_action_log_cmd"))
    {
      return action_cmd_set_log_cmd(argc, argv);
    }
    /* set_action_nolog action_id
     *   Action-log Phase 3: suppress Layer A logging for this action id
     *   (csv 'nolog' column; gesture-start commands whose effect is logged
     *   at the gesture END). Returns 1 if the id exists, 0 otherwise. */
    else if(!strcmp(argv[1], "set_action_nolog"))
    {
      return action_cmd_set_nolog(argc, argv);
    }
    else if(!strcmp(argv[1], "set_modify"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        set_modify(atoi(argv[2]));
      }
      Tcl_ResetResult(interp);
    }
    /* set_pin_type in|out|inout|-cycle [inst]
     *   Cadence-parity pin-type editing (doc/claude/specs/pin_type_editing.md).
     *   Schematic view: swaps devices/ipin|opin|iopin.sym on the named port instance
     *   (or every SELECTED one), via `replace_symbol ... fast` so this branch owns ONE
     *   undo slot for the whole call; lab/position/rotation are preserved.
     *   Symbol view: rewrites dir= on every SELECTED PINLAYER pin rect (name view
     *   geometry untouched). -cycle advances each target in->out->inout->in.
     *   Returns the number of pins changed; a fully no-op call pushes no undo.
     *   Logged raw on success; the inner fast replace_symbol calls self-suppress. */
    else if(!strcmp(argv[1], "set_pin_type"))
    {
      int i, changed = 0, cycle, undo_done = 0, named = 0;
      const char *want = NULL;
      char nres[30];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "set_pin_type")) return TCL_ERROR;
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem set_pin_type needs in|out|inout|-cycle", TCL_STATIC);
        return TCL_ERROR;
      }
      cycle = !strcmp(argv[2], "-cycle");
      if(!cycle) {
        if(!strcmp(argv[2], "in") || !strcmp(argv[2], "out") || !strcmp(argv[2], "inout")) {
          want = argv[2];
        } else {
          Tcl_SetResult(interp, "xschem set_pin_type: bad type (in|out|inout|-cycle)", TCL_STATIC);
          return TCL_ERROR;
        }
      }
      if(!editing_symbol_view()) {
        int first = 0, last = xctx->instances;
        if(argc > 3) {
          if((first = get_instance(argv[3])) < 0) {
            Tcl_SetResult(interp, "xschem set_pin_type: instance not found", TCL_STATIC);
            return TCL_ERROR;
          }
          if(!pin_sym_dir(xctx->inst[first].name)) {
            Tcl_SetResult(interp, "xschem set_pin_type: not a port (ipin/opin/iopin) instance", TCL_STATIC);
            return TCL_ERROR;
          }
          last = first + 1;
          named = 1;
        }
        for(i = first; i < last; ++i) {
          const char *cur, *tgt;
          char num[30];
          cur = pin_sym_dir(xctx->inst[i].name);
          if(!cur) continue;
          if(!named && xctx->inst[i].sel != SELECTED) continue;
          if(cycle) tgt = !strcmp(cur, "in") ? "out" : !strcmp(cur, "out") ? "inout" : "in";
          else tgt = want;
          if(!strcmp(tgt, cur)) continue;
          if(!undo_done) { xctx->push_undo(); undo_done = 1; }
          my_snprintf(num, S(num), "%d", i);
          tclvareval("xschem replace_symbol {", num, "} {", dir_pin_sym(tgt), "} fast", NULL);
          ++changed;
        }
      } else {
        if(argc > 3) {
          Tcl_SetResult(interp, "xschem set_pin_type: named target only in schematic view", TCL_STATIC);
          return TCL_ERROR;
        }
        for(i = 0; i < xctx->rects[PINLAYER]; ++i) {
          xRect *r = &xctx->rect[PINLAYER][i];
          const char *cur, *tgt;
          if(r->sel != SELECTED) continue;
          if(!get_tok_value(r->prop_ptr, "name", 0)[0]) continue;
          if(!get_tok_value(r->prop_ptr, "dir", 0)[0]) continue;
          cur = dir_literal(get_tok_value(r->prop_ptr, "dir", 0));
          if(cycle) tgt = !strcmp(cur, "in") ? "out" : !strcmp(cur, "out") ? "inout" : "in";
          else tgt = want;
          if(!strcmp(tgt, cur)) continue;
          if(!undo_done) { xctx->push_undo(); undo_done = 1; }
          my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "dir", tgt));
          set_rect_flags(r);
          ++changed;
        }
      }
      if(changed) {
        set_modify(1);
        xctx->prep_hash_inst = 0;
        xctx->prep_net_structs = 0;
        xctx->prep_hi_structs = 0;
        draw();
        if(argc > 3) log_action("xschem set_pin_type %s {%s}", argv[2], argv[3]);
        else log_action("xschem set_pin_type %s", argv[2]);
      }
      my_snprintf(nres, S(nres), "%d", changed);
      Tcl_SetResult(interp, nres, TCL_VOLATILE);
    }
    /* setprop [-fast|-fastundo] instance|symbol|text|rect|wire ref tok [val]
     *
     * setprop [-fast] instance inst [tok] [val]
     *   set attribute 'tok' of instance (name or number) 'inst' to value 'val'
     *   If 'tok' set to 'allprops' replace whole instance prop_str with 'val'
     *   If 'val' not given (no attribute value) delete attribute from instance
     *   If 'tok' not given clear completely instance attribute string
     *   If '-fast' argument if given does not redraw and is not undoable
     *
     * setprop symbol name tok [val]
     *   Set attribute 'tok' of symbol name 'name' to 'val'
     *   If 'val' not given (no attribute value) delete attribute from symbol
     *   This command is not very useful since changes are not saved into symbol
     *   and netlisters reload symbols, so changes are lost anyway.
     *
     * setprop rect [-fast|-fastundo] lay n tok [val]
     *   Set attribute 'tok' of rectangle number'n' on layer 'lay'
     *   If 'val' not given (no attribute value) delete attribute from rect
     *   If '-fast' argument is given does not redraw and is not undoable
     *   If '-fastundo' s given same as above but action is undoable.
     *    
     * setprop rect 2 n fullxzoom
     * setprop rect 2 n fullyzoom
     *   These commands do full x/y zoom of graph 'n' (on layer 2, this is hardcoded).
     *
     * setprop wire [-fast|-fastundo] n tok [val]
     *   Set attribute 'tok' of wire number'n'
     *   If 'val' not given (no attribute value) delete attribute from wire
     *   If '-fast' argument is given does not redraw and is not undoable
     *   If '-fastundo' s given same as above but action is undoable.
     *
     * setprop [-fast|-fastundo] text n [tok] [val]
     *   Set attribute 'tok' of text number 'n'
     *   If 'tok' not specified set text string (txt_ptr) to value
     *   If "txt_ptr" is given as token replace the text txt_ptr ("the text")
     *   If 'val' not given (no attribute value) delete attribute from text
     *   If '-fast' argument is given does not redraw and is not undoable
     *   If '-fastundo' is given same as above but action is undoable.
     */
    else if(!strcmp(argv[1], "setprop"))
    {
      int i, fast = 0, shift = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "setprop")) return TCL_ERROR;

      for(i = 2; i < argc; i++) {
        if(argv[i][0] == '-') {
          if(!strcmp(argv[i], "-fast")) {
            fast = 1; shift++;
          } else if(!strcmp(argv[i], "-fastundo")) {
            fast = 3; shift++;
          }
        } else {
          break;
        }
      }
      /* remove option (-xxx) arguments and shift remaining */
      if(shift) for(; i < argc; i++) {
        argv[i - shift] = argv[i];
      }
      argc -= shift;


    /*   0       1       2     3    4     5
     * xschem setprop instance R4 value [30k]  */
      if(argc > 2 && !strcmp(argv[2], "instance")) {
        int inst;

        if(argc < 4) {
          Tcl_SetResult(interp, "xschem setprop instance needs 1 or more additional arguments", TCL_STATIC);
          return TCL_ERROR;
        }
        if((inst = get_instance(argv[3])) < 0 ) {
          Tcl_SetResult(interp, "xschem setprop: instance not found", TCL_STATIC);
          return TCL_ERROR;
        } else {
          char *translated_sym = NULL;
          int sym_number = -1;
          char *subst = NULL, *old_name = NULL;;
          char *old_lab = NULL; /* pin name before the edit (pin-rename propagation) */

          /* copied before the property write: get_tok_value's buffer is rotating
           * (doc/claude/specs/pin_rename_propagation.md) */
          my_strdup2(_ALLOC_ID_, &old_lab, get_tok_value(xctx->inst[inst].prop_ptr, "lab", 0));

          if(!fast) {
            symbol_bbox(inst, &xctx->inst[inst].x1, &xctx->inst[inst].y1, &xctx->inst[inst].x2, &xctx->inst[inst].y2);
            xctx->push_undo();
          }
          xctx->prep_hash_inst=0;
          xctx->prep_net_structs=0;
          xctx->prep_hi_structs=0;
          if(argc > 4 && !strcmp(argv[4], "name")) {
            if(fast == 0) {
              hash_names(-1, XINSERT);
            }
            my_strdup2(_ALLOC_ID_, &old_name, xctx->inst[inst].instname);
          }
          if(argc > 5) {
            if(!strcmp(argv[4], "allprops")) {
              hash_names(-1, XINSERT);
              my_strdup2(_ALLOC_ID_, &subst, argv[5]);
            } else {
              my_strdup2(_ALLOC_ID_, &subst, subst_token(xctx->inst[inst].prop_ptr, argv[4], argv[5]));
            }
          } else if(argc > 4) {/* assume argc == 5 , delete attribute */
            my_strdup2(_ALLOC_ID_, &subst, subst_token(xctx->inst[inst].prop_ptr, argv[4], NULL));
          } else if(argc > 3) {
            /* clear all instance prop_str */
            my_free(_ALLOC_ID_, &subst);

          }
          hash_names(inst, XDELETE);
          new_prop_string(inst, subst, tclgetboolvar("disable_unique_names"));
          if(old_name) {
            update_attached_floaters(old_name, inst, 0);
          }
          my_strdup2(_ALLOC_ID_, &translated_sym, translate(inst, xctx->inst[inst].name));
          sym_number=match_symbol(translated_sym);

          if(sym_number > 0) {
            delete_inst_node(inst);
            xctx->inst[inst].ptr=sym_number;
          }
          if(subst) my_free(_ALLOC_ID_, &subst);
          if(old_name) my_free(_ALLOC_ID_, &old_name);
          set_inst_flags(&xctx->inst[inst]);
          hash_names(inst, XINSERT);
          /* Renaming an interface pin drags its net labels along, in the undo slot
           * pushed above (doc/claude/specs/pin_rename_propagation.md).
           *
           * Not under -fast (fast==1): that form pushes no undo and skips draw(),
           * and its callers loop over a whole selection themselves --
           * utils/bus_resize.tcl issues one -fast setprop per selected pin AND
           * label under a single outer undo, so propagating would double-edit
           * exactly the objects the loop is about to edit. -fastundo (fast==3)
           * and the plain form both push undo and both propagate. */
          if(fast != 1) propagate_pin_rename(inst, old_lab);
          my_free(_ALLOC_ID_, &old_lab);
          set_modify(1); /* set modified state */
          if(!fast) {
            /* new symbol bbox after prop changes (may change due to text length) */
            symbol_bbox(inst, &xctx->inst[inst].x1, &xctx->inst[inst].y1, &xctx->inst[inst].x2, &xctx->inst[inst].y2);
            draw();
          }
          my_free(_ALLOC_ID_, &translated_sym);
          Tcl_SetResult(interp, xctx->inst[inst].instname , TCL_VOLATILE);
        }
      } else if(argc > 2 && !strcmp(argv[2], "symbol")) {
      /*  0       1       2      3    4     5
       * xschem setprop symbol name token [value] */

        int i;
        xSymbol *sym;
        if(argc < 4) {
          Tcl_SetResult(interp, "xschem setprop symbol needs 1 or 2 or 3 additional arguments", TCL_STATIC);
          return TCL_ERROR;
        }
        i = get_symbol(argv[3]);
        if(i == -1) {
          Tcl_SetResult(interp, "Symbol not found", TCL_STATIC);
          return TCL_ERROR;
        }
        sym = &xctx->sym[i];
        if(argc > 5)
          my_strdup2(_ALLOC_ID_, &sym->prop_ptr, subst_token(sym->prop_ptr, argv[4], argv[5]));
        else
          my_strdup2(_ALLOC_ID_, &sym->prop_ptr, subst_token(sym->prop_ptr, argv[4], NULL)); /* delete attr */

      } else if(argc > 5 && !strcmp(argv[2], "rect")) {
      /*  0       1      2   3 4   5    6
       * xschem setprop rect c n token [value] */
        int change_done = 0;
        xRect *r;
        int c = atoi(argv[3]);
        int n = atoi(argv[4]);
        if(!(c>=0 && c < cadlayers && n >=0 && n < xctx->rects[c]) ) {
          Tcl_SetResult(interp, "xschem setprop rect: wrong layer or rect number", TCL_STATIC);
          return TCL_ERROR;
        }
        r = &xctx->rect[c][n];
        if(!fast) {
          bbox(START,0.0,0.0,0.0,0.0);
        }
        if(argc > 5 && c == 2 && !strcmp(argv[5], "fullxzoom")) {
          Graph_ctx *gr = &xctx->graph_struct;
          int dataset;
          setup_graph_data(n, 0, gr);
          if(xctx->raw && gr->dataset >= 0 && gr->dataset < xctx->raw->datasets) dataset = gr->dataset;
          else dataset = -1;
          graph_fullxzoom(n, gr, dataset);
        }
        if(argc > 5 && c == 2 && !strcmp(argv[5], "fullyzoom")) {
          xRect *r = &xctx->rect[c][n];
          Graph_ctx *gr = &xctx->graph_struct;
          int dataset;
          setup_graph_data(n, 0, gr);
          if(xctx->raw && gr->dataset >= 0 && gr->dataset < xctx->raw->datasets) dataset = gr->dataset;
          else dataset = -1;
          graph_fullyzoom(r, gr, dataset);
        }
        else if(argc > 6 && !strcmp(argv[5], "allprops")) {
          /* 0063 atom 10: replace the WHOLE prop string (property-dialog replay form).
           * Recompute the cached derived fields (dash/ellipse/fill/bus) from the new
           * prop exactly as edit_rect_property() does -- the shared tail below only
           * recomputes .fill when the edited token WAS "fill", which allprops is not,
           * so a whole-prop replace would otherwise leave them stale for rendering. */
          if(strcmp(argv[6], r->prop_ptr ? r->prop_ptr : "")) {
            const char *a;
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &r->prop_ptr, argv[6]);
            a = get_tok_value(r->prop_ptr, "dash", 0);
            r->dash = strcmp(a, "") ? (short)(atoi(a) >= 0 ? atoi(a) : 0) : 0;
            a = get_tok_value(r->prop_ptr, "ellipse", 0);
            if(strcmp(a, "")) {
              int ea, eb;
              if(sscanf(a, "%d%*[ ,]%d", &ea, &eb) != 2) { ea = 0; eb = 360; }
              r->ellipse_a = ea; r->ellipse_b = eb;
            } else { r->ellipse_a = -1; r->ellipse_b = -1; }
            a = get_tok_value(r->prop_ptr, "fill", 0);
            if(!strcmp(a, "full")) r->fill = 2;
            else if(!strboolcmp(a, "false")) r->fill = 0;
            else r->fill = 1;
            r->bus = get_attr_val(get_tok_value(r->prop_ptr, "bus", 0));
          }
        }
        else if(argc > 6) {
          /* verify if there is some difference */
          if(strcmp(argv[6], get_tok_value(r->prop_ptr, argv[5], 0))) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, argv[5], argv[6]));
          }
        } else {
          get_tok_value(r->prop_ptr, argv[5], 0);
          if(xctx->tok_size) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, argv[5], NULL)); /* delete attr */
          }
        }
        if(change_done) set_modify(1);
        set_rect_flags(r); /* set cached .flags bitmask from attributes */
        if(argc > 5 && !strcmp(argv[5], "fill")) {
          const char *attr = get_tok_value(r->prop_ptr,"fill", 0);
          if(!strcmp(attr, "full")) xctx->rect[c][n].fill = 2;
          else if(!strboolcmp(attr, "false")) xctx->rect[c][n].fill = 0;
          else xctx->rect[c][n].fill = 1;
        }
        set_rect_extraptr(0, &xctx->rect[c][n]);
        if(!fast) {
          bbox(ADD, r->x1, r->y1, r->x2, r->y2);
          /* redraw rect with new props */
          bbox(SET,0.0,0.0,0.0,0.0);
          draw();
          bbox(END,0.0,0.0,0.0,0.0);
        }
        Tcl_ResetResult(interp);
      } else if(argc > 4 && !strcmp(argv[2], "wire")) {
      /*  0       1      2   3   4     5
       * xschem setprop wire n token [value] */
        double bus, oldbus, width, ov, y1, y2;
        int change_done = 0;
        xWire *w;
        int n = atoi(argv[3]);
        if(!(n >=0 && n < xctx->wires) ) {
          Tcl_SetResult(interp, "xschem setprop wire: wrong wire number", TCL_STATIC);
          return TCL_ERROR;
        }
        w = &xctx->wire[n];
        oldbus = w->bus;
        if(!fast) {
          bbox(START,0.0,0.0,0.0,0.0);
        }
        if(argc > 5) {
          if(!strcmp(argv[4], "allprops")) {
            /* 0063 atom 10: replace the WHOLE prop string (the property-dialog
             * replay form). The wire-property dialog commits a full prop string
             * per selected wire, so editprop.c logs `setprop wire n allprops {..}`. */
            if(strcmp(argv[5], w->prop_ptr ? w->prop_ptr : "")) {
              change_done = 1;
              if(fast == 3 || fast == 0) xctx->push_undo();
              my_strdup2(_ALLOC_ID_, &w->prop_ptr, argv[5]);
            }
          } else
          /* verify if there is some difference */
          if(strcmp(argv[5], get_tok_value(w->prop_ptr, argv[4], 0))) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &w->prop_ptr, subst_token(w->prop_ptr, argv[4], argv[5]));
          }
        } else {
          get_tok_value(w->prop_ptr, argv[4], 0);
          if(xctx->tok_size) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &w->prop_ptr, subst_token(w->prop_ptr, argv[4], NULL)); /* delete attr */
          }
        }
        if(change_done) set_modify(1);
        w->bus = bus = get_attr_val(get_tok_value(w->prop_ptr,"bus", 0));
        set_wire_flags(w); /* set cached .flags bitmask from attributes */


        if(!fast) {
          if(bus > 0.0) width = XLINEWIDTH(bus) / 2.0;
          else width = INT_BUS_WIDTH(xctx->lw) / 2.0;
          if(oldbus / 2.0 > width) width = XLINEWIDTH(oldbus) / 2.0;
    
          ov = width > xctx->cadhalfdotsize ? width : xctx->cadhalfdotsize;
          if(w->y1 < w->y2) { y1 = w->y1 - ov; y2 = w->y2 + ov; }
          else { y1 = w->y1 + ov; y2 = w->y2 - ov; }
          bbox(ADD, w->x1 - ov, y1 , w->x2 + ov , y2 );
          /* redraw rect with new props */
          bbox(SET,0.0,0.0,0.0,0.0);
          draw();
          bbox(END,0.0,0.0,0.0,0.0);
        }
        Tcl_ResetResult(interp);
      } else if(argc > 3 && !strcmp(argv[2], "text")) {
      /*  0       1      2   3   4      5      6
       * xschem setprop text n [token] value [fast|fastundo]
       * if "txt_ptr" is given as token replace the text txt_ptr ("the text") */
        int change_done = 0;
        int tmp;
        double xx1, xx2, yy1, yy2, dtmp;
        xText *t;
        int n = atoi(argv[3]);
        if(!(n >=0 && n < xctx->texts) ) {
          Tcl_SetResult(interp, "xschem setprop text: wrong text number", TCL_STATIC);
          return TCL_ERROR;
        }
        t = &xctx->text[n];

        if(!fast) {
          bbox(START,0.0,0.0,0.0,0.0);
        }
        if(argc > 5) {
         char *estr = NULL;
         if(!fast) {
            estr = my_expand(get_text_floater(n), tclgetintvar("tabstop"));
            text_bbox(estr, t->xscale,
                  t->yscale, t->rot, t->flip, t->hcenter,
                  t->vcenter, t->x0, t->y0,
                  &xx1,&yy1,&xx2,&yy2, &tmp, &dtmp);
            my_free(_ALLOC_ID_, &estr);
            bbox(ADD, xx1, yy1, xx2, yy2);
          }
          /* verify if there is some difference */
          if(!strcmp(argv[4], "txt_ptr")) {
            if(strcmp(argv[5], t->txt_ptr)) {
              change_done = 1;
              if(fast == 3 || fast == 0) xctx->push_undo();
              my_strdup2(_ALLOC_ID_, &t->txt_ptr, argv[5]);
            }
          } else if(!strcmp(argv[4], "size")) {
            /* pseudo-token: set display size. One value -> xscale=yscale (legacy);
             * an optional second value (0063 atom 10) sets vscale independently, so
             * the text-property dialog's independent hsize/vsize round-trips. */
            double vh = atof(argv[5]);
            double vv = (argc > 6) ? atof(argv[6]) : vh;
            if(vh != t->xscale || vv != t->yscale) {
              change_done = 1;
              if(fast == 3 || fast == 0) xctx->push_undo();
              t->xscale = vh; t->yscale = vv;
            }
          } else if(!strcmp(argv[4], "allprops")) {
            /* 0063 atom 10: replace the WHOLE attribute prop string (text's txt_ptr
             * and size are separate facets, logged as their own setprop lines). */
            if(strcmp(argv[5], t->prop_ptr ? t->prop_ptr : "")) {
              change_done = 1;
              if(fast == 3 || fast == 0) xctx->push_undo();
              my_strdup2(_ALLOC_ID_, &t->prop_ptr, argv[5]);
            }
          } else if(strcmp(argv[5], get_tok_value(t->prop_ptr, argv[4], 0))) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &t->prop_ptr, subst_token(t->prop_ptr, argv[4], argv[5]));
          }
        } else if(argc > 4) {
          get_tok_value(t->prop_ptr, argv[4], 0);
          if(xctx->tok_size) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &t->prop_ptr, subst_token(t->prop_ptr, argv[4], NULL)); /* delete attr */
          }
        }
        if(change_done) {
          char *estr = NULL;
          set_modify(1);
          set_text_flags(t);
          estr = my_expand(get_text_floater(n), tclgetintvar("tabstop"));
          text_bbox(estr, t->xscale,
                  t->yscale, t->rot, t->flip, t->hcenter,
                  t->vcenter, t->x0, t->y0,
                  &xx1,&yy1,&xx2,&yy2, &tmp, &dtmp);
          my_free(_ALLOC_ID_, &estr);
          if(!fast) bbox(ADD, xx1, yy1, xx2, yy2);
        }
        if(!fast) {
          /* redraw rect with new props */
          bbox(SET,0.0,0.0,0.0,0.0);
          if(change_done) draw();
          bbox(END,0.0,0.0,0.0,0.0);
        }
        Tcl_ResetResult(interp);
      }
      /* line / arc / polygon: these had NO setprop case at all (audit 0063 gap),
       * so the property-edit dialogs could not be replayed. Add token + `allprops`
       * (whole-prop) forms mirroring the rect/wire arms, then recompute the cached
       * derived fields (bus/dash/fill) from the attributes exactly as the
       * edit_{line,arc,polygon}_property() commit paths do, so a replayed edit
       * renders identically. A full draw() (not a partial bbox) keeps these arms
       * simple and always correct.  0063 atom 10.
       *  0       1      2    3 4   5      6
       * xschem setprop line c n token|allprops [value] */
      else if(argc > 5 && !strcmp(argv[2], "line")) {
        int change_done = 0;
        xLine *l;
        const char *dash;
        int c = atoi(argv[3]);
        int n = atoi(argv[4]);
        if(!(c >= 0 && c < cadlayers && n >= 0 && n < xctx->lines[c])) {
          Tcl_SetResult(interp, "xschem setprop line: wrong layer or line number", TCL_STATIC);
          return TCL_ERROR;
        }
        l = &xctx->line[c][n];
        if(argc > 6 && !strcmp(argv[5], "allprops")) {
          if(strcmp(argv[6], l->prop_ptr ? l->prop_ptr : "")) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &l->prop_ptr, argv[6]);
          }
        } else if(argc > 6) {
          if(strcmp(argv[6], get_tok_value(l->prop_ptr, argv[5], 0))) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &l->prop_ptr, subst_token(l->prop_ptr, argv[5], argv[6]));
          }
        } else {
          get_tok_value(l->prop_ptr, argv[5], 0);
          if(xctx->tok_size) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &l->prop_ptr, subst_token(l->prop_ptr, argv[5], NULL)); /* delete attr */
          }
        }
        if(change_done) set_modify(1);
        l->bus = get_attr_val(get_tok_value(l->prop_ptr, "bus", 0));
        dash = get_tok_value(l->prop_ptr, "dash", 0);
        l->dash = strcmp(dash, "") ? (short)(atoi(dash) >= 0 ? atoi(dash) : 0) : 0;
        if(!fast && change_done) draw();
        Tcl_ResetResult(interp);
      }
      /*  0       1      2    3 4   5      6
       * xschem setprop arc c n token|allprops [value] */
      else if(argc > 5 && !strcmp(argv[2], "arc")) {
        int change_done = 0;
        xArc *a;
        const char *attr;
        int c = atoi(argv[3]);
        int n = atoi(argv[4]);
        if(!(c >= 0 && c < cadlayers && n >= 0 && n < xctx->arcs[c])) {
          Tcl_SetResult(interp, "xschem setprop arc: wrong layer or arc number", TCL_STATIC);
          return TCL_ERROR;
        }
        a = &xctx->arc[c][n];
        if(argc > 6 && !strcmp(argv[5], "allprops")) {
          if(strcmp(argv[6], a->prop_ptr ? a->prop_ptr : "")) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &a->prop_ptr, argv[6]);
          }
        } else if(argc > 6) {
          if(strcmp(argv[6], get_tok_value(a->prop_ptr, argv[5], 0))) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &a->prop_ptr, subst_token(a->prop_ptr, argv[5], argv[6]));
          }
        } else {
          get_tok_value(a->prop_ptr, argv[5], 0);
          if(xctx->tok_size) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &a->prop_ptr, subst_token(a->prop_ptr, argv[5], NULL)); /* delete attr */
          }
        }
        if(change_done) set_modify(1);
        attr = get_tok_value(a->prop_ptr, "fill", 0);
        if(!strcmp(attr, "full")) a->fill = 2;
        else if(!strboolcmp(attr, "true")) a->fill = 1;
        else a->fill = 0;
        attr = get_tok_value(a->prop_ptr, "dash", 0);
        a->dash = strcmp(attr, "") ? (short)(atoi(attr) >= 0 ? atoi(attr) : 0) : 0;
        a->bus = get_attr_val(get_tok_value(a->prop_ptr, "bus", 0));
        if(!fast && change_done) draw();
        Tcl_ResetResult(interp);
      }
      /*  0       1      2       3 4   5      6
       * xschem setprop poly c n token|allprops [value] */
      else if(argc > 5 && !strcmp(argv[2], "poly")) {
        int change_done = 0;
        xPoly *p;
        const char *attr;
        int c = atoi(argv[3]);
        int n = atoi(argv[4]);
        if(!(c >= 0 && c < cadlayers && n >= 0 && n < xctx->polygons[c])) {
          Tcl_SetResult(interp, "xschem setprop poly: wrong layer or polygon number", TCL_STATIC);
          return TCL_ERROR;
        }
        p = &xctx->poly[c][n];
        if(argc > 6 && !strcmp(argv[5], "allprops")) {
          if(strcmp(argv[6], p->prop_ptr ? p->prop_ptr : "")) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &p->prop_ptr, argv[6]);
          }
        } else if(argc > 6) {
          if(strcmp(argv[6], get_tok_value(p->prop_ptr, argv[5], 0))) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &p->prop_ptr, subst_token(p->prop_ptr, argv[5], argv[6]));
          }
        } else {
          get_tok_value(p->prop_ptr, argv[5], 0);
          if(xctx->tok_size) {
            change_done = 1;
            if(fast == 3 || fast == 0) xctx->push_undo();
            my_strdup2(_ALLOC_ID_, &p->prop_ptr, subst_token(p->prop_ptr, argv[5], NULL)); /* delete attr */
          }
        }
        if(change_done) set_modify(1);
        attr = get_tok_value(p->prop_ptr, "fill", 0);
        if(!strcmp(attr, "full")) p->fill = 2;
        else if(!strboolcmp(attr, "true")) p->fill = 1;
        else p->fill = 0;
        attr = get_tok_value(p->prop_ptr, "dash", 0);
        p->dash = strcmp(attr, "") ? (short)(atoi(attr) >= 0 ? atoi(attr) : 0) : 0;
        p->bus = get_attr_val(get_tok_value(p->prop_ptr, "bus", 0));
        if(!fast && change_done) draw();
        Tcl_ResetResult(interp);
      }
      /* self-log at core, narrowly: only an *instance* property edit that pushed
       * undo. Two axes, both needed:
       *   - subtype == "instance": `setprop rect ...` is graph machinery
       *     (create_graph.tcl, the graph-properties dialog) issued with layer/rect
       *     indices that would not match on replay -- logging it both floods the
       *     transcript and produces non-replayable lines; text/wire props reach the
       *     log via their own dialogs. So only instance edits are recorded here.
       *   - fast != 1: `-fast` (fast==1) skips push_undo -- it is pure machinery
       *     (op-point backannotation) -- so it is excluded; `-fastundo` (fast==3)
       *     and the plain form (fast==0) DO push_undo and ARE logged.
       * Property-*dialog* edits take a different path (apply_instance_properties),
       * so this does not double-log them. Tcl_Merge keeps braces/spaces faithful.
       *
       * 0063 atom 10: the wire/rect/text/line/arc/polygon `allprops` arms above
       * are the REPLAY form of a property-dialog commit -- editprop.c emits the
       * `setprop <shape> ... allprops {..}` line itself, so these arms must NOT
       * self-log (the gate below already excludes every non-instance subtype; a
       * log here would re-log each replayed shape edit -- the coordinate-form-
       * bypass invariant). Keep the gate instance-only. */
      if(fast != 1 && argc > 2 && !strcmp(argv[2], "instance"))
        log_action_argv(argc, (const char *const *)argv);
    }
    /* show_unconnected_pins
     *   Add a "lab_show.sym" to all instance pins that are not connected to anything.
     *   Refactor B atom 15: routes through the perform_action boundary. The readonly
     *   gate (NEW -- the branch never had one, a correctness fix; the old branch let
     *   show_unconnected_pins place labels on a read-only cell) + the effect
     *   (show_unconnected_pins, run_core) + the ONE `xschem show_unconnected_pins`
     *   log site (core_log_action's DEFAULT bare `xschem %s` form) all live in
     *   perform_action. The hilight menu / command palette invoke `xschem
     *   show_unconnected_pins` verbatim -> this branch -> the boundary, with no
     *   separate routing. The `!xctx` guard + the Tcl_ResetResult are DROPPED (the
     *   boundary owns both -- Tcl_ResetResult on the success path only, atom 13). */
    else if(!strcmp(argv[1], "show_unconnected_pins") )
      return perform_action("show_unconnected_pins", argc, argv);
    /* simulate [callback]
     *   Run a simulation (start simulator configured as default in
     *   Tools -> Configure simulators and tools)
     *   If 'callback' procedure name is given execute the procedure when simulation
     *   is finished. all execute(..., id) data is available (id = execute(id) )
     *   A callback prodedure is useful if simulation is launched in background mode
     *   ( set sim(spice,1,fg) 0 ) */
    else if(!strcmp(argv[1], "simulate") )
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(set_netlist_dir(0, NULL) ) {
        if(argc > 2) tclvareval("simulate ", argv[2], NULL);
        else tcleval("simulate");
      }
      Tcl_ResetResult(interp);
    }

    /* scroll up|down|left|right
     *   Scroll the viewport one full step in the given direction (the
     *   arrow-key action; half-step wheel panning is `xschem pan`). */
    else if(!strcmp(argv[1], "scroll"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3 || !view_scroll_dir(argv[2])) {
        Tcl_SetResult(interp, "xschem scroll: expected up|down|left|right", TCL_STATIC);
        return TCL_ERROR;
      }
      Tcl_ResetResult(interp);
    }

    /* snap half|double
     *   Halve or double the mouse snap factor (relative, like the bound keys;
     *   absolute setting stays `xschem set cadsnap <value>`). */
    else if(!strcmp(argv[1], "snap"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 && !strcmp(argv[2], "half"))        view_snap_change(0);
      else if(argc > 2 && !strcmp(argv[2], "double")) view_snap_change(1);
      else {
        Tcl_SetResult(interp, "xschem snap: expected half|double", TCL_STATIC);
        return TCL_ERROR;
      }
      Tcl_ResetResult(interp);
    }

    /* snap_wire
     *   Start a GUI start snapped wire placement (click to start a
     *   wire to closest pin/net endpoint) */
    else if(!strcmp(argv[1], "snap_wire"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      xctx->ui_state |= MENUSTART;
      xctx->ui_state2 = MENUSTARTSNAPWIRE;
    }

    /* str_replace str rep with [escape] [count]
     *   replace 'rep' with 'with' in string 'str'
     *   if rep not preceeded by an 'escape' character */
    else if(!strcmp(argv[1], "str_replace"))
    {
      int escape = 0, count = -1;
      if(argc > 5) escape = argv[5][0];
      if(argc > 6) count = atoi(argv[6]);
      if(argc > 4) {
        Tcl_AppendResult(interp, str_replace(argv[2], argv[3], argv[4], escape, count), NULL);
      } else {
        Tcl_SetResult(interp, "Missing arguments", TCL_STATIC);
        return TCL_ERROR;
      }
    }

    /* subst_tok str tok newval
     *   Return string 'str' with 'tok' attribute value replaced with 'newval' */
    else if(!strcmp(argv[1], "subst_tok"))
    {
      char *s=NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 5) {Tcl_SetResult(interp, "Missing arguments", TCL_STATIC);return TCL_ERROR;}
      my_strdup(_ALLOC_ID_, &s, subst_token(argv[2], argv[3], strcmp(argv[4], "<NULL>") ? argv[4] : NULL));
      Tcl_SetResult(interp, s, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &s);
    }
    /* symbol_base_name n
     *   Return the base_name field of a symbol with name or number `n`
     *   Normally this is empty. It is set for overloaded symbols, that is symbols
     *   derived from the base symbol due to instance based implementation selection
     *   (the instance `schematic` attribute) */
    else if(!strcmp(argv[1], "symbol_base_name"))
    {
      int i = -1, found = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 && argv[2][0]) {
        i = get_symbol(argv[2]);
        if(i >=0) {
          found = 1;
        }
      }
      if(found) {
        Tcl_AppendResult(interp, xctx->sym[i].base_name, NULL);
      } else {
        Tcl_SetResult(interp, "Missing arguments or symbol not found", TCL_STATIC);
        return TCL_ERROR;
      }
    }


    /* symbol_in_new_window [new_process]
     *   When a symbol is selected edit it in a new tab/window if not already open.
     *   If nothing selected open another window of the second schematic (issues a warning).
     *   if 'new_process' is given start a new xschem process */
    else if(!strcmp(argv[1], "symbol_in_new_window"))
    {
      int new_process = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 && !strcmp(argv[2], "new_process")) new_process = 1;
      symbol_in_new_window(new_process);
      Tcl_ResetResult(interp);
    }

    /* swap_cursors
     *   swap cursor A (1)  and cursor B (2) positions.
     */
    else if(!strcmp(argv[1], "swap_cursors"))
    {
      xRect *r;
      Graph_ctx *gr;
      double tmp;
      int floaters = there_are_floaters();
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(xctx->rects[GRIDLAYER] > 0) {
        r =  &xctx->rect[GRIDLAYER][0];
        gr = &xctx->graph_struct;
        setup_graph_data(0, 0, gr);
        tmp = xctx->graph_cursor2_x;
        xctx->graph_cursor2_x = xctx->graph_cursor1_x;
        xctx->graph_cursor1_x = tmp;
        if(tclgetboolvar("live_cursor2_backannotate")) {
          if(xctx->graph_flags & 4) {
            backannotate_at_cursor_b_pos(r, gr);
            if(floaters) set_modify(-2); /* update floater caches to reflect actual backannotation */
          }
        }
      }
    }

    /* swap_windows
     *   swap first and second window in window interface (internal command)
     */
    else if(!strcmp(argv[1], "swap_windows"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(!tclgetboolvar("tabbed_interface") && get_window_count()) {
        swap_windows(1);
      }
    }

    /* switch [window_path |schematic_name]
     *   Switch context to indicated window path or schematic name
     *   returns 0 if switch was successfull or 1 in case of errors
     *   if "previous" given as window path switch to previously active tab
     *   (only for tabbed interface)
     *   (no tabs/windows present or no matching win_path / schematic name
     *   found).
     */
    else if(!strcmp(argv[1], "switch"))
    {
      int r = 1; /* error: no switch was done */
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) r = new_schematic("switch", argv[2], NULL, 1);
      Tcl_SetResult(interp, my_itoa(r), TCL_VOLATILE);
    }

    /* symbols [n | 'derived_symbols']
     *   if 'n' given list symbol with name or number 'n', else list all
     *   if 'derived_symbols' is given list also symbols derived from base symbol
     *   due to instance based implementation selection. This option must be used
     *   after a netlist operation with 'keep_symbols' TCL variable set to 1 */
    else if(!strcmp(argv[1], "symbols"))
    {
      int i;
      int derived_symbols = 0;
      int one_symbol = 0;
      char n[100];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 && !strcmp(argv[2], "derived_symbols")) derived_symbols = 1;
      else if(argc > 2 && argv[2][0] && isonlydigit(argv[2])) {
        one_symbol = 1;
        i = get_symbol(argv[2]);
        if(i >=0) Tcl_AppendResult(interp,  my_itoa(i), " {", xctx->sym[i].name, "}", NULL);
        else Tcl_SetResult(interp, "", TCL_STATIC);
      }
      if(!one_symbol) {
        for(i=0; i<xctx->symbols; ++i) {
          const char *base_name = xctx->sym[i].base_name;
          if(base_name && !derived_symbols) continue;
          my_snprintf(n , S(n), "%d", i);
          Tcl_AppendResult(interp, "  {", n, " ", "{", xctx->sym[i].name, "}", "}\n", NULL);
        }
      }
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem t...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_t(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* tab_list
     *   list all windows / tabs with window pathname and associated filename */
    if(!strcmp(argv[1], "tab_list"))
    {
      int i;
      Xschem_ctx *ctx;
      const char *wp;
      int found = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 0; i < MAX_NEW_WINDOWS; ++i) {
        ctx = get_window_ctx(i, &wp);
        if(ctx) {
          /* guard a NULL schematic name: it would terminate Tcl_AppendResult's variadic list early,
           * dropping the trailing " {...}\n" and corrupting the row (matches the 'windows' branch). */
          const char *nm = ctx->sch[ctx->currsch] ? ctx->sch[ctx->currsch] : "";
          Tcl_AppendResult(interp, wp, " {", nm, "}\n", NULL);
        }
      }
      dbg(1, "tab_list: return %d\n", found);
      return found;
    }

    /* table_read [table_file]
     *   If a simulation raw file is lodaded unload from memory.
     *   else read a tabular file 'table_file'
     *   First line is the header line containing variable names.
     *   data is presented in column format after the header line
     *   First column is sweep (x-axis) variable
     *   Double empty lines start a new dataset
     *   Single empty lines are ignored
     *   Datasets can have different # of lines.
     *   new dataset do not start with a header row.
     *   Lines beginning with '#' are comments and ignored
     *
     *      time    var_a   var_b   var_c
     *   # this is a comment, ignored
     *       0.0     0.0     1.8    0.3
     *     <single empty line: ignored>
     *       0.1     0.0     1.5    0.6
     *       ...     ...     ...    ...
     *     <empty line>
     *     <Second empty line: start new dataset>
     *       0.0     0.0     1.8    0.3
     *       0.1     0.0     1.5    0.6
     *       ...     ...     ...    ...
     */
    else if(!strcmp(argv[1], "table_read"))
    {
      char f[PATH_MAX + 100];
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(sch_waves_loaded() >= 0) {
        extra_rawfile(3, NULL, NULL, -1.0, -1.0);
        /* free_rawfile(&xctx->raw, 1, 0); */
        draw();
      } else if(argc > 2) {
        my_snprintf(f, S(f),"regsub {^~/} {%s} {%s/}", argv[2], home_dir);
        tcleval(f);
        my_strncpy(f, tclresult(), S(f));
        extra_rawfile(3, NULL, NULL, -1.0, -1.0);
        /* free_rawfile(&xctx->raw, 0, 0); */
        table_read(f);

        if(sch_waves_loaded() >= 0) {
          my_strdup(_ALLOC_ID_, &xctx->raw->sim_type, "table");
          draw();
        }
      }
      Tcl_ResetResult(interp);
    }

    /* test
     *   Testmode ... */
    else if(1 && !strcmp(argv[1], "test") )
    {
      Iterator_ctx ctx;
      Objectentry *objectptr;
      int type, n, c;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}

      if(argc > 2 && atoi(argv[2]) == 1) {
        hash_objects();
        dbg(0, "n_hash_objects=%d\n", xctx->n_hash_objects);

        for(init_object_iterator(&ctx, -420., -970., 1300., -250.); (objectptr = object_iterator_next(&ctx)) ;) {
          type = objectptr->type;
          n = objectptr->n;
          c = objectptr->c;
          dbg(0, "type=%d, n=%d c=%d\n", type, n, c);
          switch(type) {
            case ELEMENT:
              select_element(n, SELECTED, 1, 1);
              break;
            case WIRE:
              select_wire(n, SELECTED, 1, 1);
              break;
            case xTEXT:
              select_text(n, SELECTED, 1, 1);
              break;
            case xRECT:
              select_box(c, n, SELECTED, 1, 1);
              break;
            case LINE:
              select_line(c, n, SELECTED, 1, 1);
              break;
            case POLYGON:
              select_polygon(c, n, SELECTED, 1, 1);
              break;
            case ARC:
              select_arc(c, n, SELECTED, 1, 1);
              break;
          }
        }
        rebuild_selected_array();
        draw();

        del_object_table();
        Tcl_ResetResult(interp);
      }
      else if(argc > 2 && atoi(argv[2]) == 5) {
        xctx->prep_hash_inst=0;
        hash_instances();
      }
      else if(argc > 2 && atoi(argv[2]) == 4) {
        xctx->prep_hash_object=0;
        hash_objects();
      }
      else if(argc > 2 && atoi(argv[2]) == 6) {
        xctx->prep_hash_wires=0;
        hash_wires();
      }
      else if(argc > 2 && atoi(argv[2]) == 7) {
        auto_set_wire_bus(0, xctx->wires);
      }
      else if(argc > 5 && atoi(argv[2]) == 2) {
        /* example: xschem test 2 .xctrl. LDCP_REF 8 */
        prepare_netlist_structs(0);
        hier_hilight_hash_lookup(argv[4], atoi(argv[5]), argv[3], XINSERT);
        propagate_hilights(1, 0, XINSERT_NOREPLACE);
        Tcl_ResetResult(interp);
      }
      else if(argc > 2 && atoi(argv[2]) == 3) {

        char *s = "aa	bb	cc	dd\n"
                  "eee	fff	ggg	hhh";

        char *t = my_expand(s, 8);

        dbg(0, "%s\n----\n", s);
        Tcl_SetResult(interp, t, TCL_VOLATILE);
        my_free(_ALLOC_ID_, &t);
      }
    }

    /* text x y rot flip text props size draw
     *   Create a text object
     *     x, y, rot, flip specify the position and orientation
     *     text is the text string
     *     props is the attribute string
     *     size sets the size
     *     draw is a flag. If set to 1 will draw the created text */
    /* text_id index
     *   return the session-stable id of text[index], or -1 if out of range.
     *   text is a flat array, so this mirrors `xschem wire_id`. Ids are stamped
     *   at text creation (store.c text_register), never reused within a session
     *   and not persisted. Resolve back with `xschem text_index id` */
    else if(!strcmp(argv[1], "text_id"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        int n = atoi(argv[2]);
        if(n >= 0 && n < xctx->texts) {
          char s[30];
          my_snprintf(s, S(s), "%u", xctx->text[n].id);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        } else {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        }
      }
    }
    /* text_index id
     *   return the current array index of the text whose session-stable id is
     *   given, or -1 if no live text carries that id (deleted, or invalidated
     *   by a disk-undo restore) */
    else if(!strcmp(argv[1], "text_index"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        unsigned int id = (unsigned int)strtoul(argv[2], NULL, 10);
        Tcl_SetResult(interp, my_itoa(text_index_from_id(id)), TCL_VOLATILE);
      }
    }
    else if(!strcmp(argv[1], "text") )
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "text")) return TCL_ERROR;
      if(argc < 10) {Tcl_SetResult(interp,
          "xschem text requires 8 additional arguments", TCL_STATIC); return TCL_ERROR;}

      xctx->push_undo(); /* issue 0127 residual: checkpoint like interactive place_text + the rect/line/arc coord arms */
      create_text(atoi(argv[9]), atof(argv[2]), atof(argv[3]), atoi(argv[4]), atoi(argv[5]),
                    argv[6], argv[7], atof(argv[8]), atof(argv[8]));
      set_modify(1); /* issue 0127 residual: mark modified like the rect/line/arc coord arms */
      Tcl_ResetResult(interp);
    }


    /* text_string n
     *   get text string of text object 'n' */
    else if(!strcmp(argv[1], "text_string") )
    {
      int n;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {Tcl_SetResult(interp,
          "xschem text_string requires 1 additional argument", TCL_STATIC); return TCL_ERROR;}
      n = atoi(argv[2]);
      if(n >= 0 && n < xctx->texts) {
        Tcl_SetResult(interp, xctx->text[n].txt_ptr, TCL_VOLATILE);
      } else {
        Tcl_ResetResult(interp);
      }
    }

    /* toggle_colorscheme
     *   Toggle dark/light colorscheme */
    else if(!strcmp(argv[1], "toggle_colorscheme"))
    {
      int d_c;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      d_c = tclgetboolvar("dark_colorscheme");
      d_c = !d_c;
      tclsetboolvar("dark_colorscheme", d_c);
      tclsetdoublevar("dim_value", 0.0);
      tclsetdoublevar("dim_bg", 0.0);
      build_colors(0.0, 0.0);
      draw();
      Tcl_ResetResult(interp);
    }

    /* toggle_draw_pixmap
     *   Toggle off-screen pixmap (double buffered) drawing */
    else if(!strcmp(argv[1], "toggle_draw_pixmap"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      toggle_draw_pixmap_cmd();
      Tcl_ResetResult(interp);
    }

    /* toggle_show_netlist
     *   Toggle showing the netlist window when netlisting */
    else if(!strcmp(argv[1], "toggle_show_netlist"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      toggle_show_netlist_cmd();
      Tcl_ResetResult(interp);
    }

    /* toggle_stretch
     *   Toggle stretching of wires attached to moved objects */
    else if(!strcmp(argv[1], "toggle_stretch"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      toggle_stretch_cmd();
      Tcl_ResetResult(interp);
    }

    /* toggle_orthogonal_wiring
     *   Toggle orthogonal (manhattan) wire drawing */
    else if(!strcmp(argv[1], "toggle_orthogonal_wiring"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      toggle_orthogonal_wiring_cmd();
      Tcl_ResetResult(interp);
    }

    /* toggle_ignore
     *   toggle *_ignore={true,short} attribute on selected instances AND wires
     *   * = {spice,verilog,vhdl,tedax,spectre} depending on current netlist mode.
     * Refactor B atom 12: routes through the perform_action boundary -- the ONE
     * readonly gate (this branch NEVER HAD one: a scattered 0041/0051 mutation-on-a-
     * read-only-cell gap the boundary now CLOSES) + the ONE effect (run_core arm) + the
     * ONE log site (core_log_action's DEFAULT `xschem %s` bare form -- this branch
     * logged NOTHING before, so the boundary is a pure COVERAGE ADD) all live in
     * perform_action. No scattered readonly/log/push_undo here. The equivalent Shift+T
     * key (act_toggle_ignore, callback.c) routes through the SAME boundary. */
    else if(!strcmp(argv[1], "toggle_ignore"))
    {
      return perform_action("toggle_ignore", argc, argv);
    }

    /* touch x1 y1 x2 y2 x0 y0
     *   returns 1 if line {x1 y1 x2 y2} touches point {x0 y0}, 0 otherwise */
    else if(!strcmp(argv[1], "touch") )
    {
      if(argc>7) {
        double x1, y1, x2, y2, x0, y0;
        int r;
        x0 = atof(argv[6]);
        y0 = atof(argv[7]);
        x1 = atof(argv[2]);
        y1 = atof(argv[3]);
        x2 = atof(argv[4]);
        y2 = atof(argv[5]);
        r = touch(x1, y1, x2, y2, x0, y0);
        Tcl_SetResult(interp, my_itoa(r), TCL_VOLATILE);
      }
    }

    /* translate n str
     *   Translate string 'str' replacing @xxx tokens with values in instance 'n' attributes
     *     Example: xschem translate vref {the voltage is @value}
     *     the voltage is 1.8
     *   If -1 is given as the instance number try to translate the string without using any
     *   instance specific data */
    else if(!strcmp(argv[1], "translate") )
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc>3) {
        int i;
        char *s = NULL;
        if(!strcmp(argv[2], "-1")) i = -1;
        else if((i = get_instance(argv[2])) < 0 ) {
          Tcl_SetResult(interp, "xschem translate: instance not found", TCL_STATIC);
          return TCL_ERROR;
        }
        my_strdup2(_ALLOC_ID_, &s, translate(i, argv[3]));
        Tcl_ResetResult(interp);
        Tcl_SetResult(interp, s, TCL_VOLATILE);
        my_free(_ALLOC_ID_, &s);
      }
    }

    /* translate3 str eat_escapes s1 [s2] [s3]
     *   Translate string 'str' replacing @xxx tokens with values in string s1 or if
     *     not found in string s2 or if not found in string s3
     *     eat_escapes should be either 1 (remove backslashes) or 0 (keep them)
     *     Example: xschem translate3 {the voltage is @value} {name=x12} {name=x1 value=1.8}
     *     the voltage is 1.8 */
    else if(!strcmp(argv[1], "translate3") )
    {
      char *s = NULL;
      int eat_escapes = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) eat_escapes = atoi(argv[3]);
      if(argc > 6) my_strdup2(_ALLOC_ID_, &s, translate3(argv[2], eat_escapes, argv[4], argv[5], argv[6], NULL));
      else if(argc > 5) my_strdup2(_ALLOC_ID_, &s, translate3(argv[2], eat_escapes, argv[4], argv[5], NULL, NULL));
      else if(argc > 4) my_strdup2(_ALLOC_ID_, &s, translate3(argv[2], eat_escapes, argv[4], NULL, NULL, NULL));
      else {
        Tcl_SetResult(interp, "xschem translate3: missing arguments", TCL_STATIC);
        return TCL_ERROR;
      }
      Tcl_ResetResult(interp);
      Tcl_SetResult(interp, s, TCL_VOLATILE);
      my_free(_ALLOC_ID_, &s);
    }

    /* trim_chars str sep
     *   Remove leading and trailing chars matching any character in 'sep' from str */
    else if(!strcmp(argv[1], "trim_chars"))
    {
      if(argc > 3) {
        char *s = trim_chars(argv[2], argv[3]);
        Tcl_SetResult(interp, s, TCL_VOLATILE);
      }
    }

    /* trim_wires
     *   Remove operlapping wires, join lines, trim wires at intersections.
     *   Migrated onto the perform_action() boundary (Refactor B, first per-verb
     *   migration): the ONE readonly gate + ONE effect + ONE log site now live in
     *   perform_action, so this branch AND the inline '&' key (callback.c) funnel
     *   through the same choke point -- no scattered readonly_reject/log_action here.
     *   Menu (Tools) + toolbar + the auto-trim checkbutton reach this branch via
     *   `xschem trim_wires`. */
    else if(!strcmp(argv[1], "trim_wires"))
    {
      return perform_action("trim_wires", argc, argv);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem u...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_u(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* unbind <device> <code> <mods> <ctx>
     *   Remove an input binding (result = number removed). Pairs with `bind`
     *   under case 'b'. See doc/claude/suggestions/refactor_plan_action_registry_phase3.md */
    if(!strcmp(argv[1], "unbind"))
    {
      return action_cmd_unbind(argc, argv);
    }

    /* undo  [redo [set_modify]]
     *   Undo last action. Optional integers redo and set_modify are passed to pop_undo()
     *   (redo: 0/4 = undo, 1 = redo, 2 = peek -- so `xschem undo 1 1` performs a redo with its
     *   own log line, distinct from the `redo` verb's).
     *   Refactor B atom 29 (audit §49): routes through the perform_action boundary. The ONE
     *   readonly gate (same scheduler_readonly_reject + "undo" verb string = byte-identical
     *   message), the argv-parsed pop_undo_keep_selection effect and the ONE NORMALIZED log site
     *   (core_log_action's undo arm: bare at argc==2, `xschem undo %d %d` else -- atoi-canonical,
     *   default-filled, tail-dropped, exactly the old branch's forms) all live in
     *   perform_action/run_core. Every entry funnels here: the `u` key is a Tcl-funneled binding
     *   (edit.undo -> `xschem undo; xschem redraw`, legacy case 'u' deleted), deduped via
     *   actionlog_cmd_logged; menu/toolbar run the same compound; scripts call the verb.
     *   Tolerant argc PRESERVED (no arity gate -- every argc executes + logs, as before). */
    else if(!strcmp(argv[1], "undo"))
    {
      return perform_action("undo", argc, argv);
    }

    /* undo_type disk|memory
     *   Use disk file ('disk') or RAM ('memory') for undo bufer
     */
    else if(!strcmp(argv[1], "undo_type"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        dbg(1, "xschem undo_type %s\n", argv[2]);
        if(!strcmp(argv[2], "disk")) {
          if(xctx->undo_type == 1) {
            mem_delete_undo(); /*reset memory undo */
          }
          /* redefine undo function pointers */
          xctx->push_undo = push_undo;
          xctx->pop_undo = pop_undo;
          xctx->delete_undo = delete_undo;
          xctx->clear_undo = clear_undo;
          xctx->undo_type = 0; /* disk */
        } else { /* "memory" */
          if(xctx->undo_type == 0) {
            delete_undo(); /*reset disk undo */
          }
          /* redefine undo function pointers */
          xctx->push_undo = mem_push_undo;
          xctx->pop_undo = mem_pop_undo;
          xctx->delete_undo = mem_delete_undo;
          xctx->clear_undo = mem_clear_undo;
          xctx->undo_type = 1; /* memory */
        }
      }
    }

    /* unhilight_all [fast]
     *   if 'fast' is given do not redraw
     *   Clear all highlights */
    else if(!strcmp(argv[1], "unhilight_all"))
    {
      int fast = 0;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 && !strcmp(argv[2], "fast")) fast = 1;
      xctx->enable_drill=0;
      clear_all_hilights();
      /* undraw_hilight_net(1); */
      if(!fast) draw();
      net_hilight_anim_update(); /* Pass 2a: clearing all highlights stops the tick */
      net_hilight_sync_descend_windows(); /* issue 0073: clear-through into linked descend children */
      /* self-log at core (0067): deterministic + replayable. Covers the raw Cadence-rc
       * `bind .drw <Key-0>` and the mouse binding (both call `xschem unhilight_all`
       * directly, bypassing dispatch). The registered Shift+K action carries the same
       * csv command -> its Layer A copy is deduped here via actionlog_cmd_logged. */
      log_action("xschem unhilight_all");
      Tcl_ResetResult(interp);
    }

    /* unhilight
     *   Unhighlight selected nets/pins */
    else if(!strcmp(argv[1], "unhilight"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      unhilight_net(0);
    }

    /* unhilight_net_interactive
     *   Cadence-style key '8': noun-verb if a net/label/pin is selected (remove its
     *   highlight); else verb-noun (enter interactive unhighlight mode: each click
     *   removes the highlight on the net under the cursor, until ESC). */
    else if(!strcmp(argv[1], "unhilight_net_interactive"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      net_hilight_interactive(0);
      Tcl_ResetResult(interp);
    }

    /* unselect_all [draw]
     *   Unselect everything. If draw is given and set to '0' no drawing is done */
    else if(!strcmp(argv[1], "unselect_all"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) unselect_all(atoi(argv[2]));
      else unselect_all(1);
      Tcl_ResetResult(interp);
    }

    /* unselect_attached_floaters
     *   Unselect objects (not symbol instances) attached to some instance with a
     *   non empty name=... attribute */
    else if(!strcmp(argv[1], "unselect_attached_floaters"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      unselect_attached_floaters();
    }
    /* update_net_hilight_style
     *   Recompile the net highlight style table from the 'net_hilight_style' Tcl
     *   variable (after editing it) and redraw. Required: changing the variable
     *   alone has no effect, since styles are compiled into the C table.
     *   Out-of-range stripe angles are clamped to [-45,45] with a warning.
     *   An empty variable resets to the layer-derived default (re-materialized into
     *   the variable). */
    else if(!strcmp(argv[1], "update_net_hilight_style"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      build_net_hilight_styles();
      /* the edited net_hilight_style var is global but the compiled table is per-window; rebuilding
       * only the current xctx leaves other windows stale (issue 0031) -- invalidate theirs so each
       * rebuilds lazily from the new var on its next use/draw. */
      net_hilight_invalidate_other_styles();
      draw();                            /* repaint the current window's highlights with the new style */
      net_hilight_redraw_other_windows(); /* and every other detached window's, so static ones aren't
                                           * left showing the old style until they happen to repaint */
      net_hilight_anim_update(); /* Pass 2a: an edit may add/remove blink on highlighted nets */
    }
    /* update_all_sym_bboxes
     *   Update all symbol bounding boxes */
    else if(!strcmp(argv[1], "update_all_sym_bboxes"))
    {
      int i;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 0; i < xctx->texts; i++)
      if(xctx->text[i].flags & TEXT_FLOATER) {
        my_free(_ALLOC_ID_, &xctx->text[i].floater_ptr); /* clear floater cached value */
      }
      for(i = 0; i < xctx->instances; ++i) {
        symbol_bbox(i, &xctx->inst[i].x1, &xctx->inst[i].y1, &xctx->inst[i].x2, &xctx->inst[i].y2);
      }
      Tcl_ResetResult(interp);
    }

    /* update_op
     *   update tcl ngspice::ngspice array data from raw file point 0 */
    else if(!strcmp(argv[1], "update_op"))
    {
      int ret;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      ret = update_op();
      Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
    }

    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem v...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_v(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* view_prop
     *   View attributes of selected element (read only)
     *   if multiple selection show the first element (in xschem  array order) */
    if(!strcmp(argv[1], "view_prop"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      edit_property(2);
      Tcl_ResetResult(interp);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem w...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_w(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* warning_overlapped_symbols [sel]
         Highlight or select (if 'sel' set to 1) perfectly overlapped instances
         this is usually an error and difficult to grasp visually */
    if(!strcmp(argv[1], "warning_overlapped_symbols"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        warning_overlapped_symbols(atoi(argv[2]));
      } else {
        warning_overlapped_symbols(0);
      }
    }
    /* xschem wave_hilight <gi> <ni> <style>
     * xschem wave_hilight -clear [<gi>]
     *
     * NET-HIGHLIGHT STYLES ON WAVEFORM TRACES
     * (doc/claude/specs/wave_trace_hilight.md §7.1). THE mutation, and the
     * replay form of the viewer's `9`/`8`/`0` keys.
     *   <gi> <ni> <style>  1 when the set changed, 0 when it did not (that
     *                      trace already carried exactly this style, an unknown
     *                      trace was asked to be un-highlighted, or the
     *                      GRAPH_MAX_HILIGHT_WAVES cap is full). `style` -1
     *                      CLEARS that trace.
     *   -clear [<gi>]      drop every highlight of strip <gi>, or of the whole
     *                      window when <gi> is omitted; returns the count.
     * Fails LOUD on a usage error (the graph_marker / graph_axis_zoom
     * convention: a script wants a catchable error, a gesture must not raise a
     * modal).
     *
     * ⚠ Deliberately NOT scheduler_readonly_reject()ed, and for exactly the
     * reason graph_axis_zoom is not (landmine 17 names the box zoom): this is
     * session-only VIEW state -- no prop token, no undo point, no dirty flag --
     * the engine has always been allowed to write into a read-only rect, the
     * ASE viewer is read-only for its whole life, and rejecting would abort
     * every replay of the line the viewer logs. A marker is durable CONTENT and
     * is gated; a highlight is not.
     *
     * It does NOT redraw: the caller owns that (wviewer::set_wave_hilights does
     * one `xschem redraw` for the whole batch, the delete_all_markers shape).
     * It DOES re-arm the animation tick, because a style that blinks or marches
     * must start moving the moment it is applied and must stop the moment the
     * last animating highlight goes. */
    else if(!strcmp(argv[1], "wave_hilight"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc < 3) {
        Tcl_SetResult(interp, "xschem wave_hilight: usage: <gi> <ni> <style> | -clear [<gi>]",
                      TCL_STATIC);
        return TCL_ERROR;
      }
      {
        int n;
        if(!strcmp(argv[2], "-clear")) {
          n = wave_hilight_clear((argc > 3) ? atoi(argv[3]) : -1);
        } else if(argc > 4) {
          n = wave_hilight_set(atoi(argv[2]), atoi(argv[3]), atoi(argv[4]));
        } else {
          Tcl_SetResult(interp, "xschem wave_hilight: usage: <gi> <ni> <style> | -clear [<gi>]",
                        TCL_STATIC);
          return TCL_ERROR;
        }
        /* ⚠ ORDER. net_hilight_anim_update() runs `tclvareval("net_hilight_anim_update
         * {<win>}")` per open window, and a Tcl eval OVERWRITES the interp result --
         * the landmine-24 class, measured here: with the result set first, this verb
         * returned the tick proc's empty answer instead of its own count, and it did so
         * ONLY under a real DISPLAY (the fan-out opens with `if(!has_x) return;`, so the
         * headless arm could not see it). Re-arm first, answer second. */
        net_hilight_anim_update(); /* a blinking/marching style must start (or stop) now */
        Tcl_SetResult(interp, my_itoa(n), TCL_VOLATILE);
      }
    }
    /* windowid topwin_path
     *   Used by xschem.tcl for configure events (set icon) */
    else if(!strcmp(argv[1], "windowid"))
    {
      if(argc > 2) {
        windowid(argv[2]);
      }
    }
    /* windows
     *   List open schematic contexts, one Tcl sublist each:
     *     {win_path top_path group xwindow current_name number}
     *   'group' is the owning top-level ("." for the main window). 'number' is the
     *   Cadence-style stable window number (doc/claude/specs/window_numbering.md). Read-only
     *   introspection seam for multi-window / detach
     *   (doc/claude/specs/multi_window_detach.md). In Phase 0 group == top_path (the owning
     *   toplevel); per-window tab grouping (Phase 1) refines it. */
    else if(!strcmp(argv[1], "windows"))
    {
      int i;
      Xschem_ctx *ctx;
      /* build the result as a proper Tcl list of 5-element sublists so a schematic
       * name containing braces/spaces can't break the list structure (issue 0022) */
      Tcl_Obj *result = Tcl_NewListObj(0, NULL);
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 0; i < MAX_NEW_WINDOWS; ++i) {
        const char *wp, *tp, *nm;
        char xwin[32], wnum[16];
        int lvl;
        Tcl_Obj *entry, *hier;
        ctx = get_window_ctx(i, &wp);
        if(!ctx) continue;
        tp = (ctx->top_path && ctx->top_path[0]) ? ctx->top_path : ".";
        nm = ctx->sch[ctx->currsch] ? ctx->sch[ctx->currsch] : "";
        my_snprintf(xwin, S(xwin), "%lu", (unsigned long)ctx->window);
        my_snprintf(wnum, S(wnum), "%d", ctx->window_number);
        /* the window's whole hierarchy STACK, sch[0] (the top) .. sch[currsch] (what
         * is on screen). 'current_name' above is only the last element, so a window
         * DESCENDED into a design was invisible to every "which window holds X?"
         * scan -- issue 0168, where ASE-L's Results > Direct Plot re-opened the top
         * elsewhere instead of picking in the window the user had navigated. */
        hier = Tcl_NewListObj(0, NULL);
        for(lvl = 0; lvl <= ctx->currsch && lvl < CADMAXHIER; ++lvl) {
          Tcl_ListObjAppendElement(interp, hier,
            Tcl_NewStringObj(ctx->sch[lvl] ? ctx->sch[lvl] : "", -1));
        }
        /* {win_path top_path group xwindow current_name number hier}; group == tp for
         * now (Phase 0). 'number' is the Cadence-style stable window number
         * (doc/claude/specs/window_numbering.md) appended as a 6th trailing field,
         * 'hier' the stack above as a 7th. Both are APPENDED, so every existing
         * `lindex $e 0..5` consumer is unaffected. */
        entry = Tcl_NewListObj(0, NULL);
        Tcl_ListObjAppendElement(interp, entry, Tcl_NewStringObj(wp, -1));
        Tcl_ListObjAppendElement(interp, entry, Tcl_NewStringObj(tp, -1));
        Tcl_ListObjAppendElement(interp, entry, Tcl_NewStringObj(tp, -1));
        Tcl_ListObjAppendElement(interp, entry, Tcl_NewStringObj(xwin, -1));
        Tcl_ListObjAppendElement(interp, entry, Tcl_NewStringObj(nm, -1));
        Tcl_ListObjAppendElement(interp, entry, Tcl_NewStringObj(wnum, -1));
        Tcl_ListObjAppendElement(interp, entry, hier);
        Tcl_ListObjAppendElement(interp, result, entry);
      }
      Tcl_SetObjResult(interp, result);
    }
    /* wire_coord n
     *   return 4 coordinates of wire[n] */
    else if(!strcmp(argv[1], "wire_coord"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        char *r = NULL;
        int n = atoi(argv[2]);
        if(n >= 0 && n < xctx->wires) {  /* was n > 0: wire index 0 was unqueryable */
          xWire * const wire = xctx->wire;
          my_mstrcat(_ALLOC_ID_, &r, dtoa(wire[n].x1), " ", NULL);
          my_mstrcat(_ALLOC_ID_, &r, dtoa(wire[n].y1), " ", NULL);
          my_mstrcat(_ALLOC_ID_, &r, dtoa(wire[n].x2), " ", NULL);
          my_mstrcat(_ALLOC_ID_, &r, dtoa(wire[n].y2), NULL);
          Tcl_SetResult(interp, r, TCL_VOLATILE);
        }
      }
    }
    /* wire_id n
     *   return the session-stable id of wire[n], or -1 if n is out of range.
     *   Ids are stamped at wire creation (store.c), never reused within a
     *   window/tab session and not persisted in .sch files. Resolve back
     *   with `xschem wire_index id` */
    else if(!strcmp(argv[1], "wire_id"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        int n = atoi(argv[2]);
        if(n >= 0 && n < xctx->wires) {
          char s[30];
          my_snprintf(s, S(s), "%u", xctx->wire[n].id);
          Tcl_SetResult(interp, s, TCL_VOLATILE);
        } else {
          Tcl_SetResult(interp, "-1", TCL_STATIC);
        }
      }
    }
    /* wire_index id
     *   return the current array index of the wire whose session-stable id
     *   (see `xschem wire_id`) is given, or -1 if no live wire carries that
     *   id (deleted, or invalidated by a disk-undo restore) */
    else if(!strcmp(argv[1], "wire_index"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2) {
        unsigned int id = (unsigned int)strtoul(argv[2], NULL, 10);
        Tcl_SetResult(interp, my_itoa(wire_index_from_id(id)), TCL_VOLATILE);
      }
    }
    /* wire [x1 y1 x2 y2] [pos] [prop] [sel]
     *   wire
     *   wire gui
     *   Place a new wire
     *   if no coordinates are given start a GUI wire placement
     *   if `gui` argument is given start a GUI placement of a wire with 1st point
     *   starting from current mouse coordinates */
    else if(!strcmp(argv[1], "wire"))
    {
      double x1,y1,x2,y2;
      int pos = -1, save, sel = 0;
      const char *prop=NULL;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "wire")) return TCL_ERROR;
      if(argc > 5) {
        x1=atof(argv[2]);
        y1=atof(argv[3]);
        x2=atof(argv[4]);
        y2=atof(argv[5]);
        ORDER(x1,y1,x2,y2);
        if(argc > 6) pos=atoi(argv[6]);
        if(argc > 7) prop = argv[7];
        if(argc > 8) sel = atoi(argv[8]);
        xctx->push_undo();
        storeobject(pos, x1,y1,x2,y2,WIRE,0,(short)sel,prop);
        if(sel) xctx->need_reb_sel_arr=1;
        xctx->prep_hi_structs=0;
        xctx->prep_net_structs=0;
        xctx->prep_hash_wires=0;
        save = xctx->draw_window; xctx->draw_window = 1;
        drawline(WIRELAYER,NOW, x1,y1,x2,y2, 0.0, 0, NULL);
        xctx->draw_window = save;
        /* W3: a scripted wire may pass under existing pins/net-labels -> split it into
         * inter-attachment segments (maintain = split + pin-aware merge). Gated on
         * autotrim_wires; undo pushed by the wire command above. See wire_segment_splitting.md. */
        if(tclgetboolvar("autotrim_wires")) maintain_wire_segments();
        set_modify(1);
      }
      else if(argc > 2 && !strcmp(argv[2], "gui")) {
        int prev_state = xctx->ui_state;
        int infix_interface = tclgetboolvar("infix_interface");
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
        }
      } else {
        xctx->last_command = 0;
        xctx->ui_state |= MENUSTART;
        xctx->ui_state2 = MENUSTARTWIRE;
      }
    }
    /* wire_cut [x y] [noalign]
     *   start a wire cut operation. Point the mouse in the middle of a wire and
     *   Alt-click right button.
     *   if x and y are given cut wire at given point
     *   if noalign is given and is set to 'noalign' do not align the cut point to closest snap point */
    else if(!strcmp(argv[1], "wire_cut"))
    {
      /* Refactor B atom 17: SPLIT on the coord form. Only the SCRIPTED/replay coord form
       * (argc>3 -- `xschem wire_cut x y [noalign]`) is a mutation and crosses the boundary;
       * the no-coord GESTURE-START form (`xschem wire_cut [noalign]`, the two Alt-Right menu
       * items) ARMS ui_state and mutates NOTHING, so it stays RAW here and logs NOTHING --
       * exactly the rotate/flip STARTMOVE-stays-raw split (the during-gesture arm is silent,
       * the standalone/scripted form crosses). The !xctx guard covers the gesture-START path
       * (it dereferences xctx->ui_state); the coord form re-checks it inside perform_action
       * (harmless redundancy). The interactive Alt-Right cut COMPLETION lives in callback.c
       * (break_wires_at_point at mousex/y_snap) and stays RAW+silent under option (A) -- a
       * pre-existing 0069-class gesture-drop gap, deferred to a follow-up (audit §37). */
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 3) {
        return perform_action("wire_cut", argc, argv);   /* the scripted/replay coord MUTATION */
      } else {                                            /* gesture START: arms ui_state, no mutation, no log */
        int i, align = 1;
        for(i = 2; i < argc; i++) {
          if(!strcmp(argv[i], "noalign")) align = 0;
        }
        xctx->ui_state |= MENUSTART;
        xctx->ui_state2 = align ? MENUSTARTWIRECUT : MENUSTARTWIRECUT2;
        Tcl_ResetResult(interp);
      }
    }

    else { *cmd_found = 0;}
  return TCL_OK;
}

/* `xschem x...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_x(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    #ifdef HAS_XCB
    /* xcb_info
     *   For debug */
    if(!strcmp(argv[1], "xcb_info"))
    {
      dbg(0, "maximum xcb req length=%u\n", xcb_get_maximum_request_length(xcb_conn));
    }
    else { *cmd_found = 0;}
    #endif
  return TCL_OK;
}

/* `xschem z...` commands, moved verbatim from the xschem() dispatcher
 * (dispatcher decomposition batch 3). Sets *cmd_found = 0 when argv[1]
 * matches no command in this group; early returns propagate unchanged. */
static int xschem_cmds_z(Tcl_Interp *interp, int argc, const char *argv[], int *cmd_found)
{
    /* zoom_box [x1 y1 x2 y2] [factor]
     *   Zoom to specified coordinates, if 'factor' is given reduce view (factor < 1.0)
     *   or add border (factor > 1.0)
     *   If no coordinates are given start GUI zoom box operation */
    if(!strcmp(argv[1], "zoom_box"))
    {
      double x1, y1, x2, y2, factor;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      dbg(1, "scheduler(): xschem zoom_box: argc=%d, argv[2]=%s\n", argc, argv[2]);
      if(argc==6 || argc == 7) {
        x1 = atof(argv[2]);
        y1 = atof(argv[3]);
        x2 = atof(argv[4]);
        y2 = atof(argv[5]);
        if(argc == 7) factor = atof(argv[6]);
        else          factor = 1.;
        if(factor == 0.) factor = 1.;
        zoom_box(x1, y1, x2, y2, factor);
        change_linewidth(-1.);
        draw();
      }
      else {
        xctx->ui_state |= MENUSTART;
        xctx->ui_state2 = MENUSTARTZOOM;
      }
      Tcl_ResetResult(interp);
    }

    /* zoom_full [center|nodraw|nolinewidth]
     *   Set full view.
     *   If 'center' is given center vire instead of lower-left align
     *   If 'nodraw' is given don't redraw
     *   If 'nolinewidth]' is given don't reset line widths. */
    else if(!strcmp(argv[1], "zoom_full"))
    {
      int i, flags = 1;
      int draw = 1;
      double shrink = 0.97;
      char * endptr;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      for(i = 2; i < argc; ++i) {
        if(!strcmp(argv[i], "center")) flags  |= 2;
        else if(!strcmp(argv[i], "nodraw")) draw = 0;
        else if(!strcmp(argv[i], "nolinewidth")) flags &= ~1;
        else {
          shrink = strtod(argv[i], &endptr);
          if(endptr == argv[i]) shrink = 1.0;
        }
      }
      if(tclgetboolvar("zoom_full_center")) flags |= 2;
      zoom_full(draw, 0, flags, shrink);
      Tcl_ResetResult(interp);
    }

    /* zoom_hilighted
     *   Zoom to highlighted objects */
    else if(!strcmp(argv[1], "zoom_hilighted"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      zoom_full(1, 2, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
      Tcl_ResetResult(interp);
    }

    /* zoom_in
     *   Zoom in drawing */
    else if(!strcmp(argv[1], "zoom_in"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      view_zoom(0.0);
      Tcl_ResetResult(interp);
    }

    /* zoom_out
     *   Zoom out drawing */
    else if(!strcmp(argv[1], "zoom_out"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      view_unzoom(0.0);
      Tcl_ResetResult(interp);
    }

    /* zoom_selected
     *   Zoom to selection */
    else if(!strcmp(argv[1], "zoom_selected"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      zoom_full(1, 1, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
      Tcl_ResetResult(interp);
    }
    else { *cmd_found = 0;}
  return TCL_OK;
}

int xschem(ClientData clientdata, Tcl_Interp *interp, int argc, const char * argv[])
{
 int cmd_found = 1;
 int retcode = TCL_OK;

 Tcl_ResetResult(interp);
 if(argc < 2) {
   Tcl_SetResult(interp, "Missing arguments.", TCL_STATIC);
   return TCL_ERROR;
 }
 if(debug_var>=2) {
   int i;
   fprintf(errfp, "xschem():");
   for(i=0; i<argc; ++i) {
     fprintf(errfp, "%s ", argv[i]);
   }
   fprintf(errfp, "\n");
 }
 /*
  * ********** xschem commands  IN SORTED ORDER !!! *********
  */
  switch(argv[1][0]) {
    case 'a': /*----------------------------------------------*/
    retcode = xschem_cmds_a(interp, argc, argv, &cmd_found);
    break;
    case 'b': /*----------------------------------------------*/
    retcode = xschem_cmds_b(interp, argc, argv, &cmd_found);
    break;
    case 'c': /*----------------------------------------------*/
    retcode = xschem_cmds_c(interp, argc, argv, &cmd_found);
    break;
    case 'd': /*----------------------------------------------*/
    retcode = xschem_cmds_d(interp, argc, argv, &cmd_found);
    break;
    case 'e': /*----------------------------------------------*/
    retcode = xschem_cmds_e(interp, argc, argv, &cmd_found);
    break;
    case 'f': /*----------------------------------------------*/
    retcode = xschem_cmds_f(interp, argc, argv, &cmd_found);
    break;
    case 'g': /*----------------------------------------------*/
    retcode = xschem_cmds_g(interp, argc, argv, &cmd_found);
    break;
    case 'h': /*----------------------------------------------*/
    retcode = xschem_cmds_h(interp, argc, argv, &cmd_found);
    break;
    case 'i': /*----------------------------------------------*/
    retcode = xschem_cmds_i(interp, argc, argv, &cmd_found);
    break;
    case 'l': /*----------------------------------------------*/
    retcode = xschem_cmds_l(interp, argc, argv, &cmd_found);
    break;
    case 'm': /*----------------------------------------------*/
    retcode = xschem_cmds_m(interp, argc, argv, &cmd_found);
    break;
    case 'n': /*----------------------------------------------*/
    retcode = xschem_cmds_n(interp, argc, argv, &cmd_found);
    break;
    case 'o': /*----------------------------------------------*/
    retcode = xschem_cmds_o(interp, argc, argv, &cmd_found);
    break;
    case 'p': /*----------------------------------------------*/
    retcode = xschem_cmds_p(interp, argc, argv, &cmd_found);
    break;
    case 'r': /*----------------------------------------------*/
    retcode = xschem_cmds_r(interp, argc, argv, &cmd_found);
    break;
    case 's': /*----------------------------------------------*/
    retcode = xschem_cmds_s(interp, argc, argv, &cmd_found);
    break;
    case 't': /*----------------------------------------------*/
    retcode = xschem_cmds_t(interp, argc, argv, &cmd_found);
    break;
    case 'u': /*----------------------------------------------*/
    retcode = xschem_cmds_u(interp, argc, argv, &cmd_found);
    break;
    case 'v': /*----------------------------------------------*/
    retcode = xschem_cmds_v(interp, argc, argv, &cmd_found);
    break;
    case 'w': /*----------------------------------------------*/
    retcode = xschem_cmds_w(interp, argc, argv, &cmd_found);
    break;
    case 'x': /*----------------------------------------------*/
    retcode = xschem_cmds_x(interp, argc, argv, &cmd_found);
    break;
    case 'z': /*----------------------------------------------*/
    retcode = xschem_cmds_z(interp, argc, argv, &cmd_found);
    break;
    default:
    cmd_found = 0;
    break;
  } /* switch */
  if(retcode != TCL_OK) return retcode;
  if(!cmd_found) {
    Tcl_AppendResult(interp, "xschem ", argv[1], ": invalid command.", NULL);
    return TCL_ERROR;
  }
  return TCL_OK;
}

double tclgetdoublevar(const char *s)
{
  const char *p;
  p = Tcl_GetVar(interp, s, TCL_GLOBAL_ONLY | TCL_LEAVE_ERR_MSG);
  if(!p) {
    dbg(0, "%s\n", tclresult());
    return 0.0;
  }
  return atof_spice(p);
}

int tclgetintvar(const char *s)
{
  const char *p;
  p = Tcl_GetVar(interp, s, TCL_GLOBAL_ONLY | TCL_LEAVE_ERR_MSG);
  if(!p) {
    dbg(0, "%s\n", tclresult());
    return 0;
  }
  return atoi(p);
}

int tclgetboolvar(const char *s)
{
  int res;
  const char *p;
  p = Tcl_GetVar(interp, s, TCL_GLOBAL_ONLY | TCL_LEAVE_ERR_MSG);
  if(!p) {
    dbg(0, "%s\n", tclresult());
    return 0;
  }
  if(Tcl_GetBoolean(interp, p, &res) == TCL_ERROR) {
    dbg(0, "%s\n", tclresult());
    return 0;
  }
  return res;
}

const char *tclgetvar(const char *s)
{
  const char *p;
  p = Tcl_GetVar(interp, s, TCL_GLOBAL_ONLY | TCL_LEAVE_ERR_MSG);
  if(!p) {
    dbg(1, "%s\n", tclresult());
    return NULL;
  }
  return p;
}

const char *tcleval(const char str[])
{
  if(Tcl_GlobalEval(interp, str) != TCL_OK) {
    fprintf(errfp, "tcleval(): evaluation of script: %s failed\n", str);
    fprintf(errfp, "         : %s\n", Tcl_GetStringResult(interp));
    Tcl_ResetResult(interp);
  }
  return Tcl_GetStringResult(interp);
}
const char *tclresult(void)
{
  return Tcl_GetStringResult(interp);
}

void tclsetvar(const char *s, const char *value)
{
  if(!Tcl_SetVar(interp, s, value, TCL_GLOBAL_ONLY)) {
    fprintf(errfp, "tclsetvar(): error setting variable %s to %s\n", s, value);
  }
}

void tclsetdoublevar(const char *s, const double value)
{
  char str[80];
  sprintf(str, "%.16g", value);
  if(!Tcl_SetVar(interp, s, str, TCL_GLOBAL_ONLY)) {
    fprintf(errfp, "tclsetdoublevar(): error setting variable %s to %g\n", s, value);
  }
}

void tclsetintvar(const char *s, const int value)
{
  char str[80];
  sprintf(str, "%d", value);
  if(!Tcl_SetVar(interp, s, str, TCL_GLOBAL_ONLY)) {
    fprintf(errfp, "tclsetintvar(): error setting variable %s to %d\n", s, value);
  }
}

void tclsetboolvar(const char *s, const int value)
{
  if(!Tcl_SetVar(interp, s, (value ? "1" : "0"), TCL_GLOBAL_ONLY)) {
    fprintf(errfp, "tclsetboolvar(): error setting variable %s to %d\n", s, value);
  }
}

/* Replacement for Tcl_VarEval, which despite being very useful is deprecated */
int tclvareval(const char *script, ...)
{
  char *str = NULL;
  int return_code;
  size_t size;
  const char *p;
  va_list args;

  va_start(args, script);
  size = my_strcat(_ALLOC_ID_, &str, script);
  while( (p = va_arg(args, const char *)) ) {
    size = my_strcat(_ALLOC_ID_, &str, p);
    dbg(2, "tclvareval(): p=%s, str=%s, size=%d\n", p, str, size);
  }
  dbg(2, "tclvareval(): script=%s, str=%s, size=%d\n", script, str ? str : "<NULL>", size);
  return_code = Tcl_EvalEx(interp, str, (Tcl_Size)size, TCL_EVAL_GLOBAL); /* Tcl_Size: no-op on 8.6 (=int), avoids >2GB truncation on Tcl 9 */
  va_end(args);
  if(return_code != TCL_OK) {
    dbg(0, "tclvareval(): error executing %s: %s\n", str, tclresult());
    Tcl_ResetResult(interp);
  }
  my_free(_ALLOC_ID_, &str);
  return return_code;
}
