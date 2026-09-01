# A FAILED `source` OF xschem.tcl MUST NOT WALK ON INTO UNSET VARIABLES (issue 0663).
#
# THE CLASS. src/xschem.tcl sources FIFTEEN helpers with a BARE `source`
# (:14568 action_registry, :14584 library_defs, :14586 library_git, :14588
# library_manager, :14590 copy_form, :14592 create_instance, :14594
# save_as_form, :14796 op_annot, :14800 cmdmode, :14802 ase, :14804 ase_window,
# :14806 wave_viewer, :14809 calculator, :14811 property_form, :14815
# alt2_toggle_view) plus ONE guarded by issue 0658 (:14854 ciw.tcl). A Tcl error
# inside any of the fifteen propagates OUT of xschem.tcl, so the REST of
# xschem.tcl -- the statusbar widgets, build_widgets, ciw_create, the colour and
# layer setup -- never runs. Then source_tcl_file() (src/xinit.c:1513) merely
# PRINTS the error and returns TCL_ERROR, Tcl_AppInit (src/xinit.c:3406)
# DISCARDS that return, and control walks on into
# `tclgetdoublevar("cairo_font_line_spacing")` (:3417) and nine siblings against
# variables that were never set, then into alloc_xschem_data(), whose
# `strcmp(tclgetvar("undo_type"), "disk")` (src/xinit.c:658) is handed a NULL.
# SIGSEGV. main.c:32's handler then derefs `xctx->sch[xctx->currsch]` on a
# half-initialised xctx and DOUBLE-faults, which is why the code is 139 and not
# the handler's own exit(1).
#
# THIS IS THE ROOT CAUSE OF ISSUE 0424, not a relative of it. 0424 lost
# op_annot.tcl from the install list; 275 in-tree checks stayed GREEN and the
# INSTALLED binary was dead on arrival, exit 139. The fix then was to put the
# file back on the install list -- the crash mechanism was never touched, and
# op_annot.tcl is STILL one of the fifteen bare sources (src/xschem.tcl:14796).
# So the subject file of R1/R3 below is op_annot.tcl DELIBERATELY: it is 0424's
# own file, and ciw.tcl is already guarded so breaking it would prove nothing
# about the class.
#
# THE SUITE IS STRUCTURALLY BLIND TO THIS WITHOUT A FARM. In-tree
# XSCHEM_SHAREDIR resolves to src/, so a file missing from the install list is
# still found. Only an installed tree or a throw-away share dir can see it --
# hence sharefarm.tcl (a directory of symlinks to src/ with named entries
# REPLACED or REMOVED) and a CHILD xschem launched against it. Every row here is
# a child process; nothing in this suite can be satisfied in-tree.
#
# THE CONTRACT THESE ROWS DEFINE (red-first; the implementation must match):
#   * a failed source of xschem.tcl ABORTS CLEANLY -- `CHILDSTATUS 1`, never
#     `CHILDKILLED SIGSEGV`, and never a silently degraded start;
#   * it ANNOUNCES, naming the FAILING FILE, on stderr AND in the DURABLE LOG
#     (issue 0423's standing objection: a caught failure that is not announced
#     is a worse defect than the crash);
#   * EXACTLY ONE durable line per failure -- one notice, one line, never
#     0665's two (0497 rule 1: count per pass, never alert per item);
#   * the NORMAL path is byte-unchanged: a clean tree starts exactly as before,
#     with no announcement and no new stderr line. A fix that announced on a
#     healthy startup would be worse than the bug;
#   * issue 0658's per-file ciw.tcl catch (src/xschem.tcl:14854) keeps its
#     shipped behaviour: still alive, still ONE `NOTICE CHANNEL DEGRADED` line,
#     and NO second announcement from the C backstop.
#
# ROWS. SG0 harness sanity | SG1-SG6 R1 the broken op_annot.tcl child | SG7 R1b
# the error at the END of the file | SG8 R3 the file ABSENT (the pure 0424
# shape) | SG9 R2-early (action_registry.tcl, :14568, the FIRST bare source and
# BEFORE ::xschem::notify_log exists at ~14671) | SG10 R2-late
# (alt2_toggle_view.tcl, :14815, the LAST) | SG11 xschem.tcl ITSELF, the case a
# per-file catch measurably cannot cover | SG12-SG13 R6 the normal path |
# SG14 the 0658 control | SG15-SG19 R7 the same on a DISPLAY | SG20 R5 one
# durable line | SG21 the audit classifier's literal is preserved.
#
# WHY THE CHECKS ONLY EVER COMPARE COUNTS AND STATUS STRINGS, never a raw -out
# blob: a broken child's stderr carries `Tcl_AppInit() error: ...` at column 0,
# and full_audit.sh:316 classify() scores a whole suite CRASH on that line if
# the suite is not passing. Printing a child's output into this parent's stdout
# would reclassify a plain FAIL as a CRASH.
#
# Both arms. The children carry their own private --logdir (share_farm_child),
# so R4 does not depend on the parent's logging flags -- this suite is correct
# under --nolog too. The GUI legs need a DISPLAY on the PARENT and self-skip
# with a printed reason when there is none.
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_startup_guard_0663.tcl
#   GUI_GATE=0 DISPLAY=:99 ./src/xschem --pipe -q --nolog --script tests/headless/test_startup_guard_0663.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
## non-asserting evidence line (the test_ase_log_seam_0207.tcl idiom)
proc note {name got} { puts "note: $name = {$got}"; flush stdout }

# --- locations (cwd-independent) --------------------------------------------
set here [file normalize [file dirname [info script]]]      ;# tests/headless
set repo [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
## the throw-away XSCHEM_SHAREDIR + CHILD xschem idiom (issue 0658)
source [file join $here sharefarm.tcl]
set scratch [test_scratch startup_guard_0663]

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

# --- helpers -----------------------------------------------------------------
proc sg_slurp {p} { set f [open $p r] ; set d [read $f] ; close $f ; return $d }

## -out is one blob; every counter below works on LINES so a check can say
## "exactly one" and mean it.
proc sg_out_lines {r} { return [split [string trimright [dict get $r -out] \n] \n] }
proc sg_out_count {r s} { return [share_farm_count [sg_out_lines $r] $s] }
proc sg_log_count {r s} { return [share_farm_count [dict get $r -log] $s] }

## count LOG lines matching a glob -- this is where the announcement's SHAPE is
## pinned (the `#! ` durable prefix from log_output, src/util.c:536, and the
## order sourced-file -> failing-file -> cause), not just its keyword.
proc sg_log_glob {r pat} {
  set n 0
  foreach l [dict get $r -log] { if {[string match $pat $l]} { incr n } }
  return $n
}
proc sg_out_glob {r pat} {
  set n 0
  foreach l [sg_out_lines $r] { if {[string match $pat $l]} { incr n } }
  return $n
}

## THE deliberate failure text. It must NOT name any file: SG3/SG9/SG10 assert
## that the ANNOUNCEMENT names the failing helper, and if the injected message
## carried the name those rows would pass on the cause text alone even when the
## origin extraction is dead (that is exactly what sabotage variant SAB-D
## removes).
set SG_BOOM "error {SG0663 deliberate helper failure}\n"

## the child's liveness witness: if this never reaches -out the child never ran
## a line of script, so an "exit 0" would be a lie.
set SG_INNER {
  puts "SG-ALIVE cadlayers=[expr {[info exists ::cadlayers] ? $::cadlayers : {NONE}}]"
  flush stdout
  exit 0
}

proc sg_run {tag replace {flags {--nogui --pipe -q}} {drop {}}} {
  global repo scratch SG_INNER
  set farm [share_farm $repo [file join $scratch farm_$tag] $replace]
  foreach d $drop { file delete -force [file join $farm $d] }
  set r [share_farm_child $farm [file join $scratch c_$tag] $SG_INNER $flags]
  note "SG child $tag status" [dict get $r -status]
  return $r
}

if {[catch {

# --- SG0: harness sanity -- the files this suite breaks are really sourced ---
# Without this the whole suite could pass vacuously: rename op_annot.tcl in
# src/xschem.tcl and every farm below breaks a file nobody sources, so every
# child starts cleanly and SG1 reds for a reason that has nothing to do with
# the class. Also declares the GUI-leg mode, so a --nogui arm is honest about
# what it did not run.
set sg_xtcl [sg_slurp [file join $repo src xschem.tcl]]
set sg_have_display [expr {[info exists ::env(DISPLAY)] && $::env(DISPLAY) ne {}}]
note "SG0 GUI legs" [expr {$sg_have_display ? "ENABLED (DISPLAY=$::env(DISPLAY))" \
                                            : "SKIPPED (no DISPLAY on the parent)"}]
check "SG0 harness sanity: op_annot.tcl, action_registry.tcl and\
 alt2_toggle_view.tcl are BARE sources in src/xschem.tcl and ciw.tcl is the\
 one CAUGHT source (issue 0658) -- every farm below breaks a file that is\
 really on the startup path" \
  [list [expr {[string first "\nsource \$XSCHEM_SHAREDIR/op_annot.tcl" $sg_xtcl] >= 0 ? 1 : 0}] \
        [expr {[string first "\nsource \$XSCHEM_SHAREDIR/action_registry.tcl" $sg_xtcl] >= 0 ? 1 : 0}] \
        [expr {[string first "\nsource \$XSCHEM_SHAREDIR/alt2_toggle_view.tcl" $sg_xtcl] >= 0 ? 1 : 0}] \
        [expr {[string first "catch {source \$XSCHEM_SHAREDIR/ciw.tcl}" $sg_xtcl] >= 0 ? 1 : 0}] \
        [expr {[string first "\nsource \$XSCHEM_SHAREDIR/ciw.tcl" $sg_xtcl] >= 0 ? 1 : 0}]] \
  [list 1 1 1 1 0]

# =============================================================================
# R1 -- the headline: op_annot.tcl raises at the TOP  (SG1-SG6, SG20, SG21)
# =============================================================================
set sg_err [sg_run opannot_err [list op_annot.tcl $SG_BOOM]]

# --- SG1: R1 the child STARTS instead of dying ------------------------------
# RED AT HEAD: `CHILDKILLED SIGSEGV`, the 0423/0424 exit-139 signature.
# The expected value is `CHILDSTATUS 1` -- a clean, named abort (the answer to
# the design question is (b): announce and abort, because a C-level continue
# runs with cadlayers=0, undo_type NULL and no bindings, and can still be told
# to SAVE a schematic; a subtly-wrong tool is worse than a refusal).
check "SG1 0663 R1 a child whose op_annot.tcl RAISES exits CLEANLY (CHILDSTATUS\
 1), it does NOT segfault" \
  [dict get $sg_err -status] {CHILDSTATUS 1}

# --- SG2: R4 the failure is ANNOUNCED, in the DURABLE log -------------------
# RED AT HEAD: zero. In every crashing row the child's Xschem.log holds only its
# 3 header lines. The glob pins the `#! ` carrier (log_output, util.c:536), so a
# fix that announced on stdout only would still be red here.
check "SG2 0663 R4 the failure reaches the DURABLE LOG as exactly ONE `#! `\
 line carrying STARTUP ABORTED" \
  [sg_log_glob $sg_err {#! *STARTUP ABORTED*}] 1

# --- SG3: R4 the announcement NAMES THE FILE --------------------------------
# RED AT HEAD: zero, and not merely for want of an announcement -- at HEAD the
# whole stderr of this shape is `Tcl_AppInit() error: can not execute
# <...>/xschem.tcl, please fix:` / `SG0663 deliberate helper failure` /
# `Line No: 14796`. NOTHING names op_annot.tcl. `Line No:` indexes the source
# line in xschem.tcl but does not name the helper, and the injected message
# deliberately does not either.
check "SG3 0663 R4 exactly ONE durable line NAMES op_annot.tcl -- 0424's own\
 file -- as the cause, in the shape `STARTUP ABORTED: <sourced> did not finish\
 ... op_annot.tcl ...`" \
  [sg_log_glob $sg_err {*STARTUP ABORTED:*did not finish*op_annot.tcl*}] 1

# --- SG4: R4 the stderr half, once ------------------------------------------
check "SG4 0663 R4 exactly ONE stderr line carries STARTUP ABORTED (the\
 announcement is not repeated per later reference)" \
  [sg_out_count $sg_err {STARTUP ABORTED}] 1

# --- SG5: non-vacuity for SG1 -- the abort is a real abort ------------------
# GREEN AT HEAD (the child segfaults before the script runs) and it must STAY
# green: it is the fence that stops SG1 being satisfied by a degraded start
# that limps on into the script with no layers and no bindings.
check "SG5 0663 the aborted child never runs a line of the script (SG-ALIVE\
 absent) -- CHILDSTATUS 1 is a refusal, not a degraded start" \
  [sg_out_count $sg_err SG-ALIVE] 0

# --- SG6: the mechanism itself is gone --------------------------------------
# RED AT HEAD: ten. `can't read "cairo_font_line_spacing": no such variable`
# (xinit.c:3417) through `can't read "cairo_font_scale": no such variable` are
# the ten reads that prove control walked past the failed source into the
# unset-variable field. Zero of them means the walk no longer happens.
check "SG6 0663 control never reaches xinit.c:3417's unset-variable reads (no\
 `no such variable` line at all)" \
  [sg_out_count $sg_err {no such variable}] 0

# --- SG20: R5 ONE durable line, never 0665's two ----------------------------
# RED AT HEAD: zero. The counterpart hazard is a fix that dumps ::errorInfo
# whole: log_output prefixes EVERY physical line with `#! `, so one failure
# would write six-plus durable lines -- 0665's exact shape, which R5 forbids.
check "SG20 0663 R5 the aborted child's durable log holds EXACTLY ONE `#! `\
 line IN TOTAL: one notice, one line, never two" \
  [sg_log_count $sg_err {#! }] 1

# --- SG21: the audit classifier's literal is preserved ----------------------
# GREEN AT HEAD, and a regression guard: full_audit.sh:316 classify() scores a
# suite CRASH on a line matching `^Tcl_AppInit\(\) error`, and
# test_audit_classifier.tcl:295-296 pins that literal. source_tcl_file() must
# keep printing its block byte-for-byte, and the new announcement must NOT
# borrow that prefix.
check "SG21 0663 source_tcl_file()'s own stderr block is unchanged: exactly ONE\
 line begins `Tcl_AppInit() error`, and the new announcement does not borrow\
 that classifier prefix" \
  [list [sg_out_glob $sg_err {Tcl_AppInit() error*}] \
        [sg_out_glob $sg_err {Tcl_AppInit() error*STARTUP ABORTED*}]] \
  [list 1 0]

# =============================================================================
# R1b / R3 -- the other two shapes of the same failure
# =============================================================================
# --- SG7: the error at the END of a real helper -----------------------------
# The whole file parses and runs; only the last line raises. Position WITHIN
# the file must be irrelevant. RED AT HEAD (139).
set sg_end [sg_run opannot_end \
  [list op_annot.tcl "[sg_slurp [file join $repo src op_annot.tcl]]\n$SG_BOOM"]]
check "SG7 0663 R1b a real op_annot.tcl with a TRAILING error aborts cleanly\
 and names op_annot.tcl -- position within the file is irrelevant" \
  [list [dict get $sg_end -status] \
        [sg_log_glob $sg_end {*STARTUP ABORTED*op_annot.tcl*}]] \
  [list {CHILDSTATUS 1} 1]

# --- SG8: R3 the file ABSENT -- the pure 0424 shape -------------------------
# Built by naming op_annot.tcl in the replace list (so share_farm does NOT
# symlink it) and then deleting the stub. Deliberately not an omit sentinel in
# sharefarm.tcl: that file is shared with test_ase_core and
# test_ase_log_seam_0207 and must not change in the same commit as a C fix.
set sg_abs [sg_run opannot_abs [list op_annot.tcl {}] {--nogui --pipe -q} op_annot.tcl]
check "SG8 0663 R3 op_annot.tcl ABSENT (0424's exact shape: a helper missing\
 from the install list) aborts cleanly and names it" \
  [list [dict get $sg_abs -status] \
        [sg_log_glob $sg_abs {*STARTUP ABORTED*op_annot.tcl*}] \
        [sg_out_count $sg_abs SG-ALIVE]] \
  [list {CHILDSTATUS 1} 1 0]

# =============================================================================
# R2 -- the fix must not be position-dependent
# =============================================================================
# EARLY = action_registry.tcl (src/xschem.tcl:14568, the FIRST bare source) and
# LATE = alt2_toggle_view.tcl (:14815, the LAST). They bracket the whole run,
# and the pair proves one more thing a pair of adjacent picks could not: at
# :14568 `::xschem::notify_log` (defined ~:14671) DOES NOT EXIST YET, so an
# announcement routed through any Tcl-side notify proc would be silent for the
# first seven of the fifteen helpers. The announcement must come from C.
set sg_early [sg_run early [list action_registry.tcl $SG_BOOM]]
check "SG9 0663 R2-early action_registry.tcl (:14568, the FIRST bare source,\
 BEFORE ::xschem::notify_log is defined) aborts cleanly and names\
 action_registry.tcl -- so the announcement cannot depend on a Tcl notify proc" \
  [list [dict get $sg_early -status] \
        [sg_log_glob $sg_early {*STARTUP ABORTED*action_registry.tcl*}]] \
  [list {CHILDSTATUS 1} 1]

set sg_late [sg_run late [list alt2_toggle_view.tcl $SG_BOOM]]
check "SG10 0663 R2-late alt2_toggle_view.tcl (:14815, the LAST bare source)\
 aborts cleanly and names alt2_toggle_view.tcl -- position in the list is\
 irrelevant" \
  [list [dict get $sg_late -status] \
        [sg_log_glob $sg_late {*STARTUP ABORTED*alt2_toggle_view.tcl*}]] \
  [list {CHILDSTATUS 1} 1]

# --- SG11: xschem.tcl ITSELF -- the case a per-file catch cannot cover -------
# THE CLASS ROW. Sixteen `catch` wrappers do not fix this class: the hazard is
# not "a helper source raises", it is "ANYTHING in xschem.tcl raises". Measured:
# with all fifteen sources wrapped, src/xschem.tcl:14569 `load_action_table` and
# :16873 `wviewer::rawhist_load` are bare top-level CALLS into helper namespaces
# and STILL exit 139, because they escape a source-only catch. A backstop at the
# ONE call in Tcl_AppInit covers those, the seventeenth helper nobody has added
# yet, and this row.
# NOTE its HEAD colour is different from every other broken row: a TRAILING
# error in xschem.tcl runs the whole file first, so `cadlayers`/`undo_type`
# (:16575, :16663) ARE set and HEAD exits 0 rather than 139. Red at HEAD all the
# same -- exit 0 with no announcement at all is precisely the silent-continue
# the contract forbids.
set sg_self [sg_run selftcl \
  [list xschem.tcl "[sg_slurp [file join $repo src xschem.tcl]]\n$SG_BOOM"]]
check "SG11 0663 xschem.tcl ITSELF failing (no helper involved -- the shape a\
 per-file catch measurably cannot cover: :14569 load_action_table and :16873\
 wviewer::rawhist_load escape a source-only catch) aborts cleanly and names\
 xschem.tcl" \
  [list [dict get $sg_self -status] \
        [sg_log_glob $sg_self {*STARTUP ABORTED*xschem.tcl*}] \
        [sg_out_count $sg_self SG-ALIVE]] \
  [list {CHILDSTATUS 1} 1 0]

# =============================================================================
# R6 -- THE NORMAL PATH IS UNCHANGED  (green at HEAD, and must stay green)
# =============================================================================
# A fix that announced on a healthy startup would be worse than the bug. These
# two rows are the R6 fence and sabotage variant SAB-C exists to redden them.
set sg_clean [sg_run clean {}]
check "SG12 0663 R6 a CLEAN farm starts exactly as before: exit 0, the script\
 runs, NO announcement, and no unset-variable read" \
  [list [dict get $sg_clean -status] \
        [sg_out_count $sg_clean SG-ALIVE] \
        [sg_out_count $sg_clean {STARTUP ABORTED}] \
        [sg_out_count $sg_clean {no such variable}]] \
  [list 0 1 0 0]

check "SG13 0663 R6 hard form: a healthy startup writes ZERO `#! ` lines to the\
 durable log -- not one error line of any kind" \
  [sg_log_count $sg_clean {#! }] 0

# --- SG14: the 0658 control -- no interaction, no double announcement -------
# GREEN AT HEAD and it must stay green. With ciw.tcl broken, xschem.tcl SUCCEEDS
# (0658's catch at :14854 swallows it), so source_tcl_file returns TCL_OK and
# the C backstop never fires: one announcement, ONE durable line, 0658's shipped
# output byte-unchanged. The `#! ` total is the anti-0665 half -- one notice
# must not become two durable lines.
set sg_ciw [sg_run ciw [list ciw.tcl $SG_BOOM]]
check "SG14 0663 the 0658 CONTROL: a broken ciw.tcl still starts (exit 0),\
 writes EXACTLY ONE `NOTICE CHANNEL DEGRADED` line and no STARTUP ABORTED, and\
 the log gains exactly ONE `#! ` line in total -- the C backstop does not fire\
 and does not double-announce" \
  [list [dict get $sg_ciw -status] \
        [sg_out_count $sg_ciw SG-ALIVE] \
        [sg_log_count $sg_ciw {NOTICE CHANNEL DEGRADED}] \
        [sg_log_count $sg_ciw {STARTUP ABORTED}] \
        [sg_log_count $sg_ciw {#! }]] \
  [list 0 1 1 0 1]

# =============================================================================
# R7 -- THE SAME ON A DISPLAY  (SG15-SG19)
# =============================================================================
# The crash is in the cairo/colour setup path, so a --nogui-only proof would not
# be a proof. Measured at HEAD: every row below is 139 on :99 exactly as it is
# headless. The GUI children run `--pipe -q`, which is what keeps them off
# source_tcl_file's modal-messageBox branch (xinit.c:1535: `has_x &&
# !cli_opt_pipe && !cli_opt_quit`) -- a bare GUI launch hangs forever on a
# dialog nobody clicks, which is issue 0669, not this suite's subject.
if {!$sg_have_display} {
  puts "SKIP: SG15-SG19 need a DISPLAY on the PARENT (none set). Run:\
 GUI_GATE=0 DISPLAY=:99 ./src/xschem --pipe -q --nolog --script\
 tests/headless/test_startup_guard_0663.tcl"
  flush stdout
} else {
  # SG17 first: it is also the display PROBE. If a clean GUI child cannot even
  # start, the rest of the GUI legs would red for a display reason and say
  # nothing about 0663, so they are skipped with a printed reason instead.
  set sg_gclean [sg_run gui_clean {} {--pipe -q}]
  check "SG17 0663 R7+R6 a CLEAN farm on a DISPLAY starts exactly as before:\
 exit 0, the script runs, no announcement" \
    [list [dict get $sg_gclean -status] \
          [sg_out_count $sg_gclean SG-ALIVE] \
          [sg_out_count $sg_gclean {STARTUP ABORTED}]] \
    [list 0 1 0]

  if {[dict get $sg_gclean -status] ne 0 || [sg_out_count $sg_gclean SG-ALIVE] != 1} {
    puts "SKIP: SG15/SG16/SG18/SG19 -- the clean GUI probe (SG17) did not start,\
 so a GUI child cannot reach this DISPLAY; these rows would red for a display\
 reason, not for 0663"
    flush stdout
  } else {
    set sg_gerr [sg_run gui_err [list op_annot.tcl $SG_BOOM] {--pipe -q}]
    check "SG15 0663 R7 on a DISPLAY, a broken op_annot.tcl aborts cleanly and\
 names it -- the crash is not a --nogui artefact" \
      [list [dict get $sg_gerr -status] \
            [sg_log_glob $sg_gerr {*STARTUP ABORTED*op_annot.tcl*}] \
            [sg_out_count $sg_gerr SG-ALIVE]] \
      [list {CHILDSTATUS 1} 1 0]

    set sg_gabs [sg_run gui_abs [list op_annot.tcl {}] {--pipe -q} op_annot.tcl]
    check "SG16 0663 R7+R3 on a DISPLAY, an ABSENT op_annot.tcl (0424's shape)\
 aborts cleanly and names it" \
      [list [dict get $sg_gabs -status] \
            [sg_log_glob $sg_gabs {*STARTUP ABORTED*op_annot.tcl*}]] \
      [list {CHILDSTATUS 1} 1]

    set sg_gciw [sg_run gui_ciw [list ciw.tcl $SG_BOOM] {--pipe -q}]
    check "SG18 0663 R7 the 0658 control on a DISPLAY: broken ciw.tcl still\
 starts, exactly one NOTICE CHANNEL DEGRADED, zero STARTUP ABORTED" \
      [list [dict get $sg_gciw -status] \
            [sg_log_count $sg_gciw {NOTICE CHANNEL DEGRADED}] \
            [sg_log_count $sg_gciw {STARTUP ABORTED}]] \
      [list 0 1 0]

    set sg_gearly [sg_run gui_early [list action_registry.tcl $SG_BOOM] {--pipe -q}]
    set sg_glate  [sg_run gui_late  [list alt2_toggle_view.tcl $SG_BOOM] {--pipe -q}]
    check "SG19 0663 R7+R2 on a DISPLAY, the FIRST bare source\
 (action_registry.tcl) and the LAST (alt2_toggle_view.tcl) both abort cleanly\
 and both name their file" \
      [list [dict get $sg_gearly -status] \
            [sg_log_glob $sg_gearly {*STARTUP ABORTED*action_registry.tcl*}] \
            [dict get $sg_glate -status] \
            [sg_log_glob $sg_glate {*STARTUP ABORTED*alt2_toggle_view.tcl*}]] \
      [list {CHILDSTATUS 1} 1 {CHILDSTATUS 1} 1]
  }
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
