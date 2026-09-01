# hi_descend: human-interface descend with view + destination choice.
# Covers the headless (scripted, no-dialog) paths: view enumeration, descending
# into the DEFAULT and a NAMED ALTERNATE schematic view, the symbol view, bad-view
# rejection, the one-shot C view override NOT dirtying the parent, and no override
# leak into a subsequent plain descend. doc/claude/specs/hi_descend.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_hi_descend.tcl
#
# The new-window / new-tab destinations and the chooser dialog need Tk and are
# exercised by a GUI smoke (scratchpad), noted in the spec as manual-eyeball.

set fixroot [file normalize [file join [file dirname [info script]] fixtures hi_descend]]
set lib [file join $fixroot hidlib]
lappend pathlist $lib                 ;# register hidlib (lib/cell/view layout) via auto-discovery
set top [file join $lib top schematic top.sch]

set fails 0
proc check {name ok detail} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name $detail"; flush stdout
  if {!$ok} {incr ::fails}
}
# load the top fresh and clear any selection/override
proc reload {} {
  global top
  set ::hi_descend_view_path {}
  xschem load $top
  xschem unselect_all
}
proc schname {} { return [xschem get schname] }
proc has {needle} { return [expr {[string first $needle [schname]] >= 0}] }

# --- enumeration: default schematic + named alternate + symbol all present ------
reload
set rows [hi_descend_enum_views x1]
set names {}
foreach r $rows { lappend names [lindex $r 0] }
check "ENUM lists default+alternate+symbol views" \
  [expr {[lsearch $names schematic] >= 0 && [lsearch $names schematic_old] >= 0 && [lsearch $names symbol] >= 0}] \
  "(views=$names)"

# --- HID1: default schematic view, current window ------------------------------
reload
set c0 [xschem get currsch]
set r1 [hi_descend inst=x1 target=current]
check "HID1 default schematic, current window" \
  [expr {$r1 == 1 && [xschem get currsch] == $c0 + 1 && [has /schematic/leaf.sch]}] \
  "(ret=$r1 name=[schname])"
xschem go_back

# --- HID2: NAMED ALTERNATE view selection (the core new capability) -------------
reload
set r2 [hi_descend inst=x1 view=schematic_old target=current]
check "HID2 named alternate view (schematic_old)" \
  [expr {$r2 == 1 && [has /schematic_old/leaf.sch]}] \
  "(ret=$r2 name=[schname])"
# HID6 discriminator: it must NOT be the default schematic view
check "HID2 alternate is NOT the default view" \
  [expr {![has /schematic/leaf.sch]}] "(name=[schname])"
xschem go_back
# the view override must not have dirtied the parent (it sets a tcl var, not the instance)
check "HID2 parent not dirtied by view override" \
  [expr {[xschem get modified] == 0 && [has top.sch]}] \
  "(modified=[xschem get modified] name=[schname])"

# --- HID3: symbol view ----------------------------------------------------------
reload
set r3 [hi_descend inst=x1 view=symbol target=current]
check "HID3 symbol view" \
  [expr {$r3 == 1 && [xschem get netlist_type] eq "symbol" && [has /symbol/leaf.sym]}] \
  "(ret=$r3 type=[xschem get netlist_type] name=[schname])"
xschem go_back

# --- SELGATE: a mixed selection (instance + wire) still descends into the instance
reload
xschem select instance x1 fast
xschem select wire 0 fast
set rsg [hi_descend target=current]
check "SELGATE mixed selection (instance+wire) descends into the instance" \
  [expr {$rsg == 1 && [has /schematic/leaf.sch]}] "(ret=$rsg name=[schname])"
xschem go_back

# --- TYPE: type=symbol with no view name picks the symbol view (not the schematic) --
reload
set rty [hi_descend inst=x1 type=symbol target=current]
check "TYPE symbol (no view name) descends into the symbol view" \
  [expr {$rty == 1 && [xschem get netlist_type] eq "symbol" && [has /symbol/leaf.sym]}] \
  "(ret=$rty type=[xschem get netlist_type] name=[schname])"
xschem go_back

# --- HID5: bad view name -> no descend, no crash --------------------------------
reload
set c5 [xschem get currsch]
set r5 [hi_descend inst=x1 view=does_not_exist target=current]
check "HID5 bad view name rejected, no descend" \
  [expr {$r5 == 0 && [xschem get currsch] == $c5 && [has top.sch]}] \
  "(ret=$r5 currsch=[xschem get currsch])"

# --- DEFAULT: omitting the view descends the default schematic (== HID1) --------
reload
set rd [hi_descend inst=x1 target=current]
check "DEFAULT omitted view -> default schematic" \
  [expr {$rd == 1 && [has /schematic/leaf.sch]}] "(name=[schname])"
xschem go_back

# --- MODE: read-only browse is the default; mode=edit makes it editable ---------
reload
hi_descend inst=x1 target=current
check "MODE default is read-only" [expr {[xschem get readonly] == 1}] "(ro=[xschem get readonly])"
xschem go_back
reload
hi_descend inst=x1 target=current mode=edit
check "MODE edit makes the descended view editable" [expr {[xschem get readonly] == 0}] "(ro=[xschem get readonly])"
xschem go_back
# issue 0035: a read-only descended (browse) view is never flagged modified -- even a
# forced set_modify(1) (as on-load auto-normalization / mtime change would do) is a no-op
reload
hi_descend inst=x1 target=current
xschem set_modify 1
check "MODE read-only view cannot be flagged modified (0035)" \
  [expr {[xschem get modified] == 0}] "(modified=[xschem get modified])"
xschem go_back

# --- ITER: bussed instance xb[1:0] -> pick the iteration ------------------------
reload
set iters [hi_descend_iters {xb[1:0]}]
check "ITER bus expands to per-bit list" \
  [expr {[llength $iters] == 2 && [lindex $iters 0] eq {xb[1]} && [lindex $iters 1] eq {xb[0]}}] "(iters=$iters)"
check "ITER plain instance is not bussed" [expr {[llength [hi_descend_iters x1]] == 0}] "(x1)"
reload
hi_descend {inst=xb[1:0]} iter=1 target=current
check "ITER iter=1 descends leftmost bit (xb\[1\])" [expr {[xschem get sch_path] eq {.xb[1].}}] "(path=[xschem get sch_path])"
xschem go_back
reload
hi_descend {inst=xb[1:0]} iter=2 target=current
check "ITER iter=2 descends next bit (xb\[0\])" [expr {[xschem get sch_path] eq {.xb[0].}}] "(path=[xschem get sch_path])"
xschem go_back

# --- NOLEAK: after a named-view descend, a plain descend uses the default again --
reload
hi_descend inst=x1 view=schematic_old target=current
xschem go_back
xschem unselect_all
xschem select instance x1 fast
xschem descend
check "NOLEAK plain descend after override uses default" \
  [expr {[has /schematic/leaf.sch] && ![has /schematic_old/leaf.sch]}] "(name=[schname])"
xschem go_back

# --- INSTVIEW: a per-copy "schematic" setting is a view the chooser must offer ----
# ISSUE 1228. A symbol placed on a sheet can be told, one copy at a time, WHICH
# schematic file that copy opens. Until this pass NO fixture under
# tests/headless/fixtures/hi_descend/ carried such a setting at all -- measured
# with grep -- so no committed row anywhere drove one through the E key, and the
# defect below sat green.
#
# Measured on the shipped xschem_library/inst_sch_select sheet: pressing E on a
# copy bound to comp3_parax.sch opens the cell's own comp3.sch instead, with no
# prompt, no message and no error. The cause is here: the list of choices is
# built with the SYMBOL form of the resolver, which cannot see a per-copy
# setting, so the copy's own file is never even one of the choices.
#
# Built in a scratch directory rather than in the committed fixture: adding an
# instance to top.sch would shift the instance numbers the NAMELESS rows below
# select by.
set ivwork /tmp/hi_descend_instview_work
file delete -force $ivwork; file mkdir $ivwork
set ivbound [file join $ivwork leaf_bound.sch]
set fh [open $ivbound w]
puts $fh "v \{xschem version=3.4.4 file_version=1.2\}"
puts $fh "G \{\}"
puts $fh "V \{\}"
puts $fh "S \{\}"
puts $fh "E \{\}"
puts $fh "N 0 0 300 0 \{\}"
puts $fh "T \{VIEW=bound_by_instance\} -40 -140 0 0 0.3 0.3 \{\}"
close $fh
set ivtop [file join $ivwork ivtop.sch]
set fh [open $ivtop w]
puts $fh "v \{xschem version=3.4.4 file_version=1.2\}"
puts $fh "G \{\}"
puts $fh "V \{\}"
puts $fh "S \{\}"
puts $fh "E \{\}"
puts $fh "C \{hidlib/leaf\} 0 0 0 0 \{name=xiv"
puts $fh "schematic=$ivbound\}"
close $fh

set ::hi_descend_view_path {}
xschem load $ivtop
xschem unselect_all
set ivrows [hi_descend_enum_views xiv]
set ivpaths {}
foreach r $ivrows { lappend ivpaths [lindex $r 2] }
check "INSTVIEW-OFFER the file this copy is set to open is one of the choices" \
  [expr {[lsearch -exact $ivpaths $ivbound] >= 0}] \
  "(rows=$ivrows)"

set ivc0 [xschem get currsch]
set ivr [hi_descend inst=xiv target=current]
check "INSTVIEW-LAND pressing E opens the file this copy is set to open" \
  [expr {$ivr == 1 && [xschem get currsch] == $ivc0 + 1 && [schname] eq $ivbound}] \
  "(ret=$ivr currsch=[xschem get currsch] name=[schname])"
catch {xschem go_back}
file delete -force $ivwork

# --- NAMELESS: an instance with no name= property (issue 0260) -------------------
# `xschem selected_set` brace-wraps each selected instance's instname with no emptiness
# check, so a NAMELESS instance comes back as a ONE-element list whose element is the
# empty string -- llength 1, so every "did I get a target" test above passes and
# hi_descend_target_inst's `lindex $sel 0` then returns "". Before this, hi_descend and
# hi_descend_dialog both returned 0 with ZERO echoes, an untouched descend_error and an
# untouched status line: byte-identical to having done nothing.
#
# It must keep REFUSING, not start guessing: every consumer of the resolver is name-keyed
# and hi_descend_inst_sym {} matches the FIRST nameless row of `xschem instance_list`, so
# letting "" through enumerates and descends into ANOTHER CELL.
#
# Works on a /tmp copy of the library: inserting the instance dirties the sheet, and the
# set_modify hook would write top~.sch into the COMMITTED fixture (observed).
set nlwork /tmp/hi_descend_nameless_work
file delete -force $nlwork; file mkdir $nlwork
file copy -force $lib $nlwork/nlib          ;# a different lib NAME, so `hidlib/leaf` still resolves via $lib
set nltop [file join $nlwork nlib top schematic top.sch]

# collect the CIW channel and count enumerations (the aliasing guard has to hold: a
# refused nameless instance must never reach hi_descend_enum_views)
rename ciw_echo ciw_echo_real
set ::REC {}
proc ciw_echo {msg args} { lappend ::REC [list $msg [lindex $args 0]]; }
rename hi_descend_enum_views hi_descend_enum_views_real
set ::nenum 0
proc hi_descend_enum_views {instname} { incr ::nenum; return [hi_descend_enum_views_real $instname] }
proc rec_has {pat} { foreach r $::REC { if {[string match $pat [lindex $r 0]]} { return 1 } }; return 0 }

set ::hi_descend_view_path {}
xschem load $nltop
xschem unselect_all
xschem instance hidlib/leaf 600 600 0 0 {name=}
xschem unselect_all
xschem select instance 2 fast
set nlsel [xschem selected_set]
check "NAMELESS-setup the nameless instance selects as a 1-element list holding {}" \
  [expr {[xschem get lastsel] == 1 && [llength $nlsel] == 1 && [lindex $nlsel 0] eq {}}] \
  "(lastsel=[xschem get lastsel] set={$nlsel} llength=[llength $nlsel])"

set ::REC {} ; set ::nenum 0
xschem statusmsg { }
set c0 [xschem get currsch]
set rnl [hi_descend target=current]
check "NAMELESS-echo hi_descend refuses AND says why (pre-fix: 0 echoes)" \
  [expr {$rnl == 0 && [xschem get currsch] == $c0 && [rec_has {*no name=*}]}] \
  "(ret=$rnl currsch=[xschem get currsch] echoes={$::REC})"
check "NAMELESS-hold the same sentence reached the HELD status line (no CIW needed)" \
  [expr {[string match {*no name=*} [xschem get statusmsg]] && [xschem get statusmsg_hold] == 1}] \
  "(msg={[xschem get statusmsg]} hold=[xschem get statusmsg_hold])"
check "NAMELESS-noalias the refusal never reached hi_descend_enum_views" \
  [expr {$::nenum == 0}] "(enum calls=$::nenum)"

# the control: the new check is not a blanket refusal
xschem unselect_all
xschem select instance x1 fast
set ::REC {} ; set ::nenum 0
set rnc [hi_descend target=current]
check "NAMELESS-control a NAMED instance in the same sheet still descends" \
  [expr {$rnc == 1 && $::nenum > 0 && [has /schematic/leaf.sch]}] \
  "(ret=$rnc enum=$::nenum name=[schname])"
xschem go_back

rename hi_descend_enum_views {}
rename hi_descend_enum_views_real hi_descend_enum_views
rename ciw_echo {}
rename ciw_echo_real ciw_echo
file delete -force $nlwork

# --- SELNW: new-window descend with the instance SELECTED is a REAL descend --------
# Regression: hi_descend_newwin must unselect before schematic_in_new_window, else it
# opens the child as a flat top-level (currsch 0, hierarchy lost) and the descend no-ops.
reload
xschem select instance x1 fast
set w0 [llength [xschem windows]]
set rnw [hi_descend target=new_window]
check "SELNW selected-instance new window does a REAL descend" \
  [expr {$rnw == 1 && [llength [xschem windows]] == $w0 + 1 && [xschem get currsch] == 1 \
         && [xschem get sch_path] eq {.x1.} && [has /schematic/leaf.sch]}] \
  "(ret=$rnw wins=$w0->[llength [xschem windows]] currsch=[xschem get currsch] path=[xschem get sch_path] name=[schname])"
catch {xschem new_schematic destroy_all force}

puts "hi_descend headless: [expr {$fails ? "$fails FAILURE(S)" : {all checks passed}}]"
