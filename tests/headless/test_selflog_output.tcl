# test_selflog_output.tcl
#
# Verifies the self-log-at-core + command-output plumbing
# (doc/claude/code_analysis/action_log_ciw_coverage_and_virtuoso_parity.md,
#  issues 0070 / 0071, D1 comment-lines + D2 core self-log):
#   - mutating subcommands (cut/delete/undo/redo) self-log even when driven
#     RAW (as a hand-written menu item or toolbar button would);
#   - the menu_action_logged wrapper de-dups (exactly one line, not two);
#   - the -reset / -emitted dedup primitives report core self-logging;
#   - -result / -error write source-able '#=' / '#!' comment lines, one per
#     physical line of output.
#
# Run under X with --pipe and --logdir:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_selflog_output.tcl

set ::fail 0
proc check {name ok} {
  if {$ok} { puts "ok   - $name" } else { puts "FAIL - $name" ; set ::fail 1 }
}
proc loglines {} {
  set fd [open [xschem get actionlog_filename] r]
  set body [read $fd]; close $fd
  return [split [string trimright $body \n] \n]
}
proc count_lines {pat} {
  set n 0
  foreach l [loglines] { if {[string equal $l $pat]} { incr n } }
  return $n
}
proc has_line {pat} { expr {[lsearch -exact [loglines] $pat] >= 0} }

check "action log open" [expr {[xschem get actionlog_filename] ne {}}]

xschem load xschem_library/examples/nand2.sch

# --- 1. RAW self-log (no wrapper): the Edit-menu / toolbar path ---------------
# A bare `xschem <cmd>` is exactly what a hand-written menu -command or a toolbar
# button issues. Previously unlogged; must now self-log at the core.
xschem select_all
xschem delete
check "raw delete self-logs"      [has_line "xschem delete"]
xschem undo
check "raw undo self-logs"        [has_line "xschem undo"]
xschem redo
check "raw redo self-logs"        [has_line "xschem redo"]
xschem select_all
xschem cut
check "raw cut self-logs"         [has_line "xschem cut"]

# --- 2. menu_action_logged dedup: exactly ONE line, not two -------------------
# The wrapper must see the core self-log (via -emitted) and skip its own copy.
xschem undo   ;# restore from the cut so there is something to act on
set before [count_lines "xschem undo"]
menu_action_logged {xschem undo}
set after [count_lines "xschem undo"]
check "menu wrapper logs undo exactly once" [expr {$after - $before == 1}]

# --- 3. -reset / -emitted primitive ------------------------------------------
xschem log_action -reset
xschem redo
check "core self-log sets -emitted"        [expr {[xschem log_action -emitted] == 1}]
xschem log_action -reset
xschem get xorigin                         ;# a query: no self-log
check "non-mutating cmd leaves -emitted 0" [expr {[xschem log_action -emitted] == 0}]

# --- 3b. transform family self-logs at core (0061 Edit/Tools menu, 0062 toolbar) --
# Standalone (non-gesture) flip/rotate/align must self-log from ANY entry point --
# the hand-written Edit-menu `-command {xschem flip}` items and the toolbar were
# previously unlogged. Explicit-coord forms are deterministic and replayable.
xschem select_all
xschem flip 10 20
check "flip self-logs with pivot"        [expr {[count_lines "xschem flip 10 20"] == 1}]
xschem select_all
xschem flipv 10 20
check "flipv self-logs with pivot"       [expr {[count_lines "xschem flipv 10 20"] == 1}]
xschem select_all
xschem rotate 10 20
check "rotate self-logs with pivot"      [expr {[count_lines "xschem rotate 10 20"] == 1}]
xschem select_all
xschem flip_in_place
check "flip_in_place self-logs"          [has_line "xschem flip_in_place"]
xschem select_all
xschem flipv_in_place
check "flipv_in_place self-logs"         [has_line "xschem flipv_in_place"]
xschem select_all
xschem rotate_in_place
check "rotate_in_place self-logs"        [has_line "xschem rotate_in_place"]
xschem select_all
xschem align
check "align self-logs"                  [has_line "xschem align"]
# wrapper dedup for a transform verb: exactly one line, not two.
xschem select_all
set before [count_lines "xschem rotate 10 20"]
menu_action_logged {xschem rotate 10 20}
set after [count_lines "xschem rotate 10 20"]
check "menu wrapper logs rotate exactly once" [expr {$after - $before == 1}]

# --- 3c. wire-surgery self-logs at core (0061 Tools menu, 0062 toolbar) --------
# trim_wires / break_wires were driven raw from the Tools menu and the toolbar
# (`toolbar_add ... "xschem trim_wires"`) -- previously unlogged. break_wires
# carries an optional `remove` arg; the exact canonical form must be preserved.
xschem trim_wires
check "trim_wires self-logs"             [has_line "xschem trim_wires"]
xschem break_wires
check "break_wires (bare) self-logs"     [has_line "xschem break_wires"]
xschem break_wires 1
check "break_wires 1 self-logs with arg" [has_line "xschem break_wires 1"]
# wrapper dedup for a wire-surgery verb: exactly one line, not two.
set before [count_lines "xschem trim_wires"]
menu_action_logged {xschem trim_wires}
set after [count_lines "xschem trim_wires"]
check "menu wrapper logs trim_wires exactly once" [expr {$after - $before == 1}]

# --- 3d. read-only rejects mutating transform/surgery AND logs nothing (0041) -
# flipv / *_in_place / break_wires previously mutated a read-only design (only
# flip and rotate carried scheduler_readonly_reject). With the guard added they
# must reject -- and, crucially for the action log, emit NO line for an edit that
# never happened.
xschem set readonly 1
foreach v {flipv flip_in_place flipv_in_place rotate_in_place break_wires} {
  set before [llength [loglines]]
  catch {xschem $v}
  set after [llength [loglines]]
  check "read-only rejects $v with no log line" [expr {$after == $before}]
}
xschem set readonly 0

# --- 3e. keyboard shortcuts self-log at their inline callback.c handlers (0068) -
# The transform/surgery keys are handled inline in callback.c and never reach the
# scheduler branch, so they carry their own log_action. Drive them via
# `xschem callback` (headless `event generate` is unreliable). rstate strips
# ShiftMask, so an uppercase keysym alone selects the Shift-<K> branch (state 0);
# Alt-<k> = lowercase keysym + Mod1Mask. Assert a NEW matching line appears (count
# delta >= 1) so a line left by an earlier section cannot make this pass falsely.
proc count_pfx {pfx} {
  set n 0 ; foreach l [loglines] { if {[string match "$pfx*" $l]} { incr n } } ; return $n
}
proc keydelta {ks st matcher pat} {
  xschem select_all
  set b [$matcher $pat]
  xschem callback .drw 2 400 300 $ks 0 0 $st ; update idletasks
  return [expr {[$matcher $pat] - $b}]
}
set Ctrl 4 ; set Alt 8   ;# ShiftMask is stripped from rstate, so Shift-<K> uses state 0
check "key Shift-F logs flip"          [expr {[keydelta 70  0     count_pfx   {xschem flip }] >= 1}]
check "key Alt-F logs flip_in_place"   [expr {[keydelta 102 $Alt  count_lines {xschem flip_in_place}] >= 1}]
check "key Shift-R logs rotate"        [expr {[keydelta 82  0     count_pfx   {xschem rotate }] >= 1}]
check "key Alt-R logs rotate_in_place" [expr {[keydelta 114 $Alt  count_lines {xschem rotate_in_place}] >= 1}]
check "key Shift-V logs flipv"         [expr {[keydelta 86  0     count_pfx   {xschem flipv }] >= 1}]
check "key Alt-V logs flipv_in_place"  [expr {[keydelta 118 $Alt  count_lines {xschem flipv_in_place}] >= 1}]
check "key Alt-U logs align"           [expr {[keydelta 117 $Alt  count_lines {xschem align}] >= 1}]
check "key & logs trim_wires"          [expr {[keydelta 38  0     count_lines {xschem trim_wires}] >= 1}]
check "key ! logs break_wires"         [expr {[keydelta 33  0     count_lines {xschem break_wires}] >= 1}]
check "key Ctrl-! logs break_wires 1"  [expr {[keydelta 33  $Ctrl count_lines {xschem break_wires 1}] >= 1}]

# --- 3f. arg-carrying mutators: setprop / change_layer / change_elem_order -----
# Reload a clean nand2 first: the earlier sections leave the buffer heavily mutated
# (repeated delete/undo/cut + transforms), and setprop on that churned state is
# unrelated to what we exercise here.
xschem load xschem_library/examples/nand2.sch
# setprop self-logs the exact arg-carrying line (Tcl_Merge fidelity) but ONLY for an
# undoable *instance* edit: instance subtype AND not -fast. (Gate rationale below.)
xschem setprop instance 0 selflogtok selflogval
check "setprop instance (non-fast) self-logs" [has_line "xschem setprop instance 0 selflogtok selflogval"]
# -fast (fast==1) skips push_undo = backannotate machinery -> NOT logged.
set sp_before [count_pfx "xschem setprop"]
xschem setprop -fast instance 0 selflogtok selflogval2
check "setprop -fast does NOT log" [expr {[count_pfx "xschem setprop"] == $sp_before}]
# -fastundo (fast==3) DOES push undo -> it MUST log (the old !fast gate wrongly dropped it).
set fu_before [count_pfx "xschem setprop"]
xschem setprop -fastundo instance 0 selflogtok selflogval3
check "setprop -fastundo (undoable) self-logs" [expr {[count_pfx "xschem setprop"] > $fu_before}]
# a rect setprop is graph machinery (create_graph / graph dialog), non-replayable -> nolog.
xschem set rectcolor 2
xschem rect -100 -100 100 100
set rsp_before [count_pfx "xschem setprop"]
xschem setprop rect 2 0 flags graph
check "setprop rect (graph) is nolog" [expr {[count_pfx "xschem setprop"] == $rsp_before}]

# change_elem_order: logs only with a selection (no-op otherwise); scheduler + Shift-S key.
xschem select_all
xschem change_elem_order -1
check "change_elem_order (w/ sel) self-logs" [has_line "xschem change_elem_order -1"]
check "key Shift-S logs change_elem_order" \
  [expr {[keydelta 83 0 count_lines {xschem change_elem_order -1}] >= 1}]
xschem unselect_all
set ceo_before [count_lines "xschem change_elem_order -1"]
xschem change_elem_order -1
check "change_elem_order (no sel) is nolog" [expr {[count_lines "xschem change_elem_order -1"] == $ceo_before}]

# change_layer (`set rectcolor`): logs ONLY when a selection makes it a content edit;
# a bare layer-cursor pick with no selection stays unlogged (0066); and it REJECTS
# (TCL_ERROR, not a silent success) on a read-only view.
xschem select_all
xschem set rectcolor 5
check "set rectcolor w/ selection logs"  [has_line "xschem set rectcolor 5"]
xschem unselect_all
set rc_before [count_pfx "xschem set rectcolor"]
xschem set rectcolor 3
check "set rectcolor w/o selection is nolog" [expr {[count_pfx "xschem set rectcolor"] == $rc_before}]
xschem select_all
xschem set readonly 1
check "set rectcolor on read-only rejects (TCL_ERROR)" [expr {[catch {xschem set rectcolor 4}] == 1}]
xschem set readonly 0

# --- 3g. symbol/schematic generators: make_symbol / make_sch / make_sch_from_sel --
# These self-log at their C cores (save.c) on the REAL operation only, so every entry
# point (menu/script subcommand, the keyboard 'a'/Ctrl+L inline handlers, the Ctrl+H
# registered action) yields exactly one line and an early-return/cancel yields none.
# They write files + make_symbol re-saves the current .sch, so redirect the buffer to a
# scratch file and stub the disk-writing Tcl helpers + dialogs (which also block under X).
xschem load xschem_library/examples/nand2.sch
set scratch [file join [file dirname [xschem get actionlog_filename]] selflog_gen.sch]
set lccpath [file join [file dirname [xschem get actionlog_filename]] selflog_lcc.sch]
xschem saveas $scratch schematic
proc tk_messageBox {args} {return ok}
proc make_symbol {args} {return {}}        ;# shadow the awk generator (no .sym write)
proc make_symbol_lcc {args} {return {}}
set ::sfd_ret {}
proc save_file_dialog {args} {return $::sfd_ret}

# finding-1 (0041): make_symbol must NOT overwrite a read-only .sch on disk. Put a
# distinctive wire in the buffer (disk still holds the as-saved copy), mark read-only,
# make the symbol -> the save_schematic must be skipped so the wire never reaches disk.
xschem wire 12345 6789 12399 6789
xschem set readonly 1
xschem make_symbol
xschem set readonly 0
set fp [open $scratch r]; set disktxt [read $fp]; close $fp
check "make_symbol read-only does NOT overwrite .sch" \
  [expr {![string match {*12345 6789 12399 6789*} $disktxt]}]

# reload a clean copy (drop the unsaved wire) for the positive logging checks.
xschem load $scratch
# make_symbol: subcommand (the sym menu's make_symbol_dialog Tcl path is deferred, 0061)
# and the keyboard 'a' inline handler (keysym 97, state 0). Both call make_symbol().
set mk_before [count_lines "xschem make_symbol"]
xschem make_symbol
check "make_symbol self-logs" [expr {[count_lines "xschem make_symbol"] > $mk_before}]
set mk_before [count_lines "xschem make_symbol"]
xschem callback .drw 2 400 300 97 0 0 0 ; update idletasks
check "key 'a' logs make_symbol" [expr {[count_lines "xschem make_symbol"] > $mk_before}]

# make_sch: gated on a real write. A multi-selection makes create_sch_from_sym()
# early-return -> NO phantom line (the fix for the old unconditional-log path).
xschem select_all
set ms_before [count_lines "xschem make_sch"]
xschem make_sch
check "make_sch multi-select logs nothing (no phantom)" \
  [expr {[count_lines "xschem make_sch"] == $ms_before}]

# make_sch_from_sel: gated on the real edit. A cancelled Save dialog (empty name) is a
# no-op -> no line; a real filename writes the LCC pair -> exactly one line.
set ::sfd_ret {}
xschem select_all
set msf_before [count_lines "xschem make_sch_from_sel"]
xschem make_sch_from_sel
check "make_sch_from_sel cancel logs nothing (no phantom)" \
  [expr {[count_lines "xschem make_sch_from_sel"] == $msf_before}]
set ::sfd_ret $lccpath
xschem select_all
set msf_before [count_lines "xschem make_sch_from_sel"]
xschem make_sch_from_sel
check "make_sch_from_sel (real edit) self-logs" \
  [expr {[count_lines "xschem make_sch_from_sel"] > $msf_before}]

# make_sch_from_sel REJECTS on read-only (TCL_ERROR, no line) -- it mutates the buffer
# (delete selection + place LCC), issue 0041; the Ctrl+H action now also carries mutates=1.
xschem load $scratch
xschem select_all
xschem set readonly 1
set msf_before [count_lines "xschem make_sch_from_sel"]
check "make_sch_from_sel read-only rejects (TCL_ERROR)" \
  [expr {[catch {xschem make_sch_from_sel}] == 1}]
check "make_sch_from_sel read-only logs nothing" \
  [expr {[count_lines "xschem make_sch_from_sel"] == $msf_before}]
xschem set readonly 0

# --- 3h. property-edit dialogs record a REPLAYABLE line (issue 0063 atom 10) --------
# editprop.c commits (wire/rect/line/arc/poly/text + global attrs + instance-via-vi)
# once logged only a dead `# property-edit` marker; they now emit the scheduler's own
# replay form -- `xschem setprop <type> <ref> allprops {prop}` per selected object
# (`xschem set sch<X>prop {str}` for global attrs) -- reading each object's committed
# prop back. Drive by stubbing the dialog procs; assert the replayable line and that
# the old marker is GONE. (The exhaustive per-type + replay coverage is in
# tests/headless/test_shape_setprop_log.tcl.)
xschem load xschem_library/examples/nand2.sch
proc text_line {args}    { set ::tctx::rcode ok; append ::tctx::retval " tsttok=1" }
proc edit_vi_prop {args} { set ::tctx::rcode ok; append ::tctx::retval " tsttok=1"; return $::tctx::retval }

# WIRE (x=0 text widget): nand2 has 20 wires.
xschem unselect_all; xschem select wire 0
set b [count_pfx "xschem setprop wire 0 allprops"]
xschem edit_prop
check "edit wire property logs a replayable setprop line" \
  [expr {[count_pfx "xschem setprop wire 0 allprops"] > $b}]

# RECT (x=0): create one on a fresh layer, select it by index.
xschem set rectcolor 6
set rb [xschem get rects 6]
xschem rect 500 500 600 600
xschem unselect_all; xschem select rect 6 $rb
set b [count_pfx "xschem setprop rect 6 $rb allprops"]
xschem edit_prop
check "edit rect property logs a replayable setprop line" \
  [expr {[count_pfx "xschem setprop rect 6 $rb allprops"] > $b}]

# INSTANCE via external editor (x=1): edit_symbol_property x==1 -> update_symbol. The
# slick text-widget instance form (x=0) is excluded because it self-logs apply_properties.
xschem unselect_all; xschem select instance 0
set b [count_pfx "xschem setprop instance"]
xschem edit_vi_prop
check "edit instance property (vi editor) logs a replayable setprop line" \
  [expr {[count_pfx "xschem setprop instance"] > $b}]

# GLOBAL schematic attributes (lastsel==0, x==1) -> `xschem set schprop {..}`.
xschem unselect_all
set b [count_pfx "xschem set schprop"]
xschem edit_vi_prop
check "edit global schematic property logs a replayable set line" \
  [expr {[count_pfx "xschem set schprop"] > $b}]

# The old `# property-edit` marker is GONE for the converted types.
check "property-edit marker no longer emitted" [expr {[count_pfx "# property-edit"] == 0}]

# CANCEL (empty rcode) commits nothing -> no line.
proc text_line {args} { set ::tctx::rcode {} }
xschem unselect_all; xschem select wire 1
set b [count_pfx "xschem setprop wire 1 allprops"]
xschem edit_prop
check "cancelled property edit logs nothing" \
  [expr {[count_pfx "xschem setprop wire 1 allprops"] == $b}]

# --- 3i. non-File menubar mutators self-log at their scheduler cores (issue 0061) --
# The Symbol/Highlight/sym.list menus are hand-written `-command "xschem <sub>"` (not
# csv-built), so their picks logged nothing until the subcommand self-logs. Cover the
# terminal mutators; the menu path hits the scheduler branch directly (keys go via the
# registered actions / inline handlers -> disjoint or deduped).
xschem load xschem_library/examples/nand2.sch

xschem unselect_all; xschem select instance 0
set b [count_pfx "xschem attach_labels"]
xschem attach_labels
check "attach_labels self-logs" [expr {[count_pfx "xschem attach_labels"] > $b}]

xschem select_all
set b [count_pfx "xschem floaters_from_selected_inst"]
xschem floaters_from_selected_inst
check "floaters_from_selected_inst self-logs" [expr {[count_pfx "xschem floaters_from_selected_inst"] > $b}]

set b [count_lines "xschem check_unique_names 1"]
xschem check_unique_names 1
check "check_unique_names 1 (rename) self-logs" [expr {[count_lines "xschem check_unique_names 1"] > $b}]
set b [count_lines "xschem check_unique_names 0"]
xschem check_unique_names 0
check "check_unique_names 0 (highlight) self-logs" [expr {[count_lines "xschem check_unique_names 0"] > $b}]

set b [count_lines "xschem print_hilight_net 4"]
xschem print_hilight_net 4
check "print_hilight_net 4 (create labels) self-logs" [expr {[count_lines "xschem print_hilight_net 4"] > $b}]
set b [count_lines "xschem print_hilight_net 1"]
xschem print_hilight_net 1
check "print_hilight_net 1 (print) self-logs" [expr {[count_lines "xschem print_hilight_net 1"] > $b}]

# add_pin_stubs migrated onto the perform_action boundary under option (c) NO-OP-STILL-LOGS (atom 25):
# a nothing-selected no-op is a TCL_OK success, so it STILL self-logs one line -- the old `if(added>0)`
# suppression is intentionally dropped (the §30 floaters / §44 delete property). See
# doc/claude/code_analysis/perform_action_atom25_add_pin_stubs_returnvalue_condlog_decision.md.
xschem unselect_all
set b [count_pfx "xschem add_pin_stubs"]
xschem add_pin_stubs
check "add_pin_stubs no-op STILL logs +1 (atom 25 option c no-op-still-logs)" \
  [expr {[count_pfx "xschem add_pin_stubs"] == $b + 1}]

# --- 3j. `xschem set` config/content sets (issue 0066) -----------------------
# The set branch splits three ways (issue 0066 §5): saved-content mutations MUST
# log + read-only-guard (header_text; rectcolor covered in §3f); edit-geometry
# state logs its RESOLVED value (cadsnap/cadgrid); pure session-config/display
# sets stay unlogged by design. Load a clean schematic (earlier sections leave
# the buffer in an edited/generator state).
xschem load xschem_library/examples/nand2.sch

# header_text: saved license metadata -> content edit. Logs a replayable command
# ONLY when the value actually changes; refuses on a read-only view.
set hb [count_pfx "xschem set header_text"]
xschem set header_text {selflog header text}
check "set header_text self-logs replayable" \
      [has_line "xschem set header_text {selflog header text}"]
set hb1 [count_pfx "xschem set header_text"]
xschem set header_text {selflog header text}   ;# same value -> no change -> no log
check "set header_text no-op logs nothing" [expr {[count_pfx "xschem set header_text"] == $hb1}]
xschem set readonly 1
check "set header_text read-only rejects (TCL_ERROR)" \
      [expr {[catch {xschem set header_text {ro attempt}}] == 1}]
set hb2 [count_pfx "xschem set header_text"]
catch {xschem set header_text {ro attempt2}}
check "set header_text read-only logs nothing" [expr {[count_pfx "xschem set header_text"] == $hb2}]
xschem set readonly 0

# cadsnap/cadgrid: log the RESOLVED value (not the dialog-open prompt), so any
# entry point (menu dialog OK / statusbar entry / Options half-double / script)
# yields one replayable line. Not a content edit -> allowed on read-only.
xschem set cadsnap 8
check "set cadsnap self-logs resolved value"  [has_line "xschem set cadsnap 8"]
xschem set cadgrid 40
check "set cadgrid self-logs resolved value"  [has_line "xschem set cadgrid 40"]
# RESOLVED, not raw: `set cadsnap 0` maps to the default snap -- the log must show
# that default (read back), never a literal `0`. Guards against logging argv[3].
xschem set cadsnap 0
check "set cadsnap 0 logs the RESOLVED default (not 0)" \
      [expr {[has_line "xschem set cadsnap [format %.10g $cadsnap]"] \
             && ![has_line "xschem set cadsnap 0"]}]

# pure session-config/display set stays unlogged by design (issue 0066 §5.3).
xschem set color_ps 0
check "pure-display set (color_ps) is nolog" [expr {[count_pfx "xschem set color_ps"] == 0}]

# --- 3k. raw Tk-bind subcommands self-log at their cores (issue 0067) ---------
# The Cadence-rc keys 9/8/0 are raw `bind .drw <Key> {xschem <sub>}` -- they never
# reach dispatch_input_action, so the sub must self-log. Deterministic unhilight_all
# logs the real command; the interactive hilight/unhilight log the real command ONLY
# in the noun-verb (a net/element is selected) branch, and stay silent when they enter
# interactive click-mode (a gesture START -- per-click effect is 0005/0069).
xschem load xschem_library/examples/nand2.sch

xschem unhilight_all
check "unhilight_all self-logs (key 0)"        [has_line "xschem unhilight_all"]

xschem unselect_all; xschem select instance 0
xschem hilight_net_interactive
check "hilight_net_interactive noun-verb self-logs (key 9)" \
      [has_line "xschem hilight_net_interactive"]
xschem select instance 0
xschem unhilight_net_interactive
check "unhilight_net_interactive noun-verb self-logs (key 8)" \
      [has_line "xschem unhilight_net_interactive"]

# no selection -> enters interactive click-mode = gesture start -> logs nothing.
xschem unselect_all
set hi_b [count_pfx "xschem hilight_net_interactive"]
xschem hilight_net_interactive
check "hilight_net_interactive interactive-mode logs nothing (gesture start)" \
      [expr {[count_pfx "xschem hilight_net_interactive"] == $hi_b}]

# +/- bus-index (change_index.tcl raw binds) mutate only via `xschem setprop instance
# $i lab …` (non-fast) -> already covered by the slice-5 setprop self-log. Confirm the
# actual path: set a bussed lab, run change_index, the incremented setprop must log.
# change_index iterates `xschem selected_set` which yields instance NAMES, so the
# logged line addresses the instance by name (p1), not index.
source [file join $XSCHEM_SHAREDIR change_index.tcl]
xschem unselect_all; xschem select instance 0
xschem setprop instance 0 lab {selfbus[3]}
change_index 1
check "change_index (+/-) routes through logged setprop" \
      [has_line "xschem setprop instance p1 lab {selfbus\[4\]}"]

# --- 4. -result / -error output comments (source-able) ------------------------
xschem log_action -result "hello world"
check "result -> '#= ' comment"   [has_line "#= hello world"]
xschem log_action -error "boom"
check "error  -> '#! ' comment"   [has_line "#! boom"]
# multi-line output: every physical line must carry its own comment prefix, or a
# continuation line would become live Tcl on replay.
xschem log_action -result "line1\nline2"
check "multiline result prefixes each line" \
  [expr {[has_line "#= line1"] && [has_line "#= line2"]}]

# --- 5. whole log stays source-able: accumulate physical lines into LOGICAL
#         commands (a braced prop value -- e.g. setprop ... allprops {..} -- may
#         span physical lines, the accepted multiline class), then require each
#         to be a comment or a replayable `xschem ...` command (no bare output) --
set srcok 1
set acc {}
foreach l [loglines] {
  if {$acc eq {} && $l eq {}} continue
  append acc $l "\n"
  if {![info complete $acc]} continue               ;# mid multi-line command -> keep going
  set first [lindex [split [string trimright $acc "\n"] \n] 0]
  set acc {}
  if {[string index $first 0] eq "#"} continue       ;# comment (header/output)
  if {[string match "xschem *" $first]} continue      ;# replayable command
  set srcok 0 ; puts "  non-source-able command starting: <$first>"
}
check "log file is source-able" $srcok

if {$::fail} { puts "RESULT: FAIL" } else { puts "RESULT: ALL PASS" }
