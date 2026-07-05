#
#  File: cadence_note_nav.tcl
#
#  Headless regression for the text-note-aware Cadence nav helpers.
#  See doc/claude/specs/cadence_note_nav.md and suggestions/plan_cadence_note_nav.md
#
#  Run UNDER xschem (the `xschem` command + descend must be available):
#      cd tests
#      ../src/xschem --nogui --pipe -q --script cadence_note_nav.tcl
#
#  Covers the headless-verifiable logic: the pure parse helpers, the selection
#  classifier, and the shared descend engine. The GUI behaviours (Library Manager
#  locate, read-only new-window open, pre-filled note placement) are verified
#  manually — see the spec's GUI checklist.
#

set here  [file normalize [file dirname [info script]]]
set utils [file normalize [file join $here .. utils]]
set fix   [file join $here buried_hilight]   ;# reuse the 4-level A>x_b>x_c>x_d fixture

# cadence_nav.tcl calls ciw_echo; stub only if the real one (src/ciw.tcl) isn't loaded.
if {[info commands ciw_echo] eq ""} { proc ciw_echo {args} {} }
source [file join $utils cadence_nav.tcl]

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

# --- pure parse helpers (no engine state) ---------------------------------
check "first_libcell bare"        [cadence::first_libcell "devices/res"]        {devices res}
check "first_libcell embedded"    [cadence::first_libcell "see devices/res ok"] {devices res}
check "first_libcell first-of-many" [cadence::first_libcell "a/b then c/d"]     {a b}
check "first_libcell none"        [cadence::first_libcell "plainword"]          {}
check "first_libcell empty"       [cadence::first_libcell ""]                   {}

check "deeppath 3-level"          [cadence::deeppath_from_text "Xamp/Xstage1/Xmir"] {Xamp Xstage1 Xmir}
check "deeppath 2-level"          [cadence::deeppath_from_text "devices/res"]   {devices res}
check "deeppath leading space"    [cadence::deeppath_from_text "  a/b "]        {a b}
check "deeppath single word"      [cadence::deeppath_from_text "nopath"]        {}
check "deeppath empty"            [cadence::deeppath_from_text ""]              {}

# --- shared descend engine (needs the fixture) ----------------------------
cd $fix
xschem load {a.sch}
check "descend_instnames returns 1"   [cadence::descend_instnames {x_b x_c x_d}] 1
check "descend_instnames reached leaf" [xschem get sch_path]                     {.x_b.x_c.x_d.}

xschem load {a.sch}   ;# fresh top
check "descend bad name returns 0"    [cadence::descend_instnames {x_b nope x_d}] 0

# --- selection classifier -------------------------------------------------
xschem load {a.sch}
xschem unselect_all
check "selkind none"  [cadence::selkind] none
xschem select instance x_b
check "selkind inst"  [lindex [cadence::selkind] 0] inst
xschem unselect_all
xschem text 100 100 0 0 {devices/res} {} 0.4 1   ;# fresh load had 0 texts -> this is index 0
xschem select text 0
check "selkind text class"  [lindex [cadence::selkind] 0]   text
check "selkind text string" [lindex [cadence::selkind] 2]   devices/res

# --- Ctrl-Alt-D write seam: remembered_path -------------------------------
set cadence::last_loc(.dummywin) {x_b x_c x_d}
check "remembered_path joins with /"     [cadence::remembered_path .dummywin] {x_b/x_c/x_d}
check "remembered_path empty when unset"  [cadence::remembered_path .nope]     {}

# --- Ctrl-Alt-D read path: descend from a selected deep-location note ------
xschem load {a.sch}
xschem text 100 100 0 0 {x_b/x_c/x_d} {} 0.4 1   ;# fresh load -> text index 0
xschem select text 0
cadence::deeploc_note
check "deeploc_note descends from note"  [xschem get sch_path] {.x_b.x_c.x_d.}

if {$nfail} { puts "cadence_note_nav: $nfail check(s): FAIL" } \
else        { puts "cadence_note_nav: all checks PASS" }
