# The Ctrl-4 Select-On-Design pick must NOT select what it clicks (issue 0204).
#
# The user's report: "My CTRL-4 to enter command mode to select-signals-to-plot lets me
# click on netlabels and wires, but allows those to get selected. So, when I then press e
# key to descend, it thinks there's already an instance selected."
#
# The mechanism, before the fix: `ase::ui::sod_click` classified each mode click with
#     set hit [xschem select_at $x $y]
# and `select_at` is the MUTATING coordinate pick by construction (doc/claude/specs/
# select_at.md): unselect_all, select_object, rebuild_selected_array, draw_selection. So
# every plot click left its target selected. `hi_descend` then reads
#     if {[llength [xschem selected_set]] == 0} { return [hi_descend_pick_arm] }
# (src/xschem.tcl) -- a non-empty selection means noun-verb, so E descended into whatever
# the plot click left behind instead of arming the verb-noun pick issue 0200 built.
#
# `xschem selected_set` filters to ELEMENT (scheduler.c), so the two halves of the report
# were predicted to behave DIFFERENTLY: a net label / pin / vsource is an instance and
# poisons selected_set; a bare wire is a WIRE and is filtered out. SO3/SO4 and SO5/SO6
# measure that prediction rather than assuming it -- see the issue's write-up for what they
# actually showed.
#
# Legs (SO*):
#   SO0       fixture sanity: what is actually under each click point
#   SO1-SO2   a NET LABEL click: queues its net, selects nothing, and E arms the pick
#   SO3-SO4   a BARE NAMED WIRE click: same three things (the "does the wire half break
#             too?" measurement)
#   SO5-SO6   an UNNAMED (#netN) wire: the 0154 fallback still resolves it WITHOUT a
#             selection to read -- the leg that proves the read-only twin really replaced
#             `nets -selected`
#   SO7-SO8   a VOLTAGE SOURCE body: current queued, nothing selected, E arms
#   SO9       a non-source device body: still queues nothing and still gets the v1 notice
#   SO10      an empty-canvas click: still silent, still selects nothing
#   SO11      THE USER'S GESTURE through real Tk events: a seized-canvas click on the net
#             label, then a real <Key-e>
#   SO12      a selection made BEFORE the mode was armed still routes E noun-verb: the fix
#             removes the pick's own mutation, it does not make E ignore the user
#   SO13-SO14 the two new C probes pinned DIRECTLY (not through sod_click): object_at
#             returns select_at's exact row and selects nothing; net_name_at returns the
#             raw token on a wire and "" on everything else
#
# MUST run under X (real <Key-e> events, `xschem callback` dispatch):
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_sod_pick_no_select_0204.tcl
# or, gated:
#   tests/headless/run_suites.sh test_sod_pick_no_select_0204
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; real key events)"; flush stdout; exit 0 }
update idletasks
focus -force .drw
update idletasks

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc note {name got} { puts "note: $name = {$got}"; flush stdout }

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch sod_pick_no_select_0204]

proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }

set MENUSTART      65536
set MENUSTARTDESC  32768
proc armed {} {
  expr {([xschem get ui_state] & $::MENUSTART) && ([xschem get ui_state2] & $::MENUSTARTDESC) ? 1 : 0}
}
proc sx {u} { expr {int(($u + [xschem get xorigin]) / [xschem get zoom])} }
proc sy {v} { expr {int(($v + [xschem get yorigin]) / [xschem get zoom])} }
proc seized {} { expr {[string match "*ase::ui::sod_click*" [bind .drw <ButtonPress-1>]] ? 1 : 0} }

# ESC is the only way to drop an armed pick -- ui_state is read-only from Tcl. It also
# resumes whatever command the arm suspended, which is exactly the clean state each leg
# wants to start from (arm_sod re-arms from scratch regardless).
set KEY 2 ; set XK_Escape 65307
proc disarm {} { catch {xschem callback .drw $::KEY 0 0 $::XK_Escape 0 0 0}; update idletasks }

# the two things a leftover selection is read through
proc selstate {} { list [xschem selected_set] [xschem get lastsel] }

if {[catch {

# --- fixture -------------------------------------------------------------------
# NAMED  wire y=0    with a lab_pin driving it        -> flylines resolves it
# (none) wire y=100  with no label at all             -> #netN, the 0154 fallback
# V1                 an unlocked vsource              -> a current pick
# R1                 a non-source device              -> the v1-scope notice
wfile [file join $scratch sp.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 0 200 0 {}
N 0 100 200 100 {}
C {devices/lab_pin} 0 0 0 0 {name=l1 lab=NAMED}
C {devices/res} 400 -200 0 0 {name=R1 value=1k}
C {devices/vsource} 400 300 0 0 {name=V1 value=1}}

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}
xschem load [file join $scratch sp.sch]
xschem zoom_full; update idletasks

# click points. The label's BODY is off to one side of its pin, so its bbox centre is a
# point where the instance really is the closest object -- computed rather than guessed.
proc bbox_centre {inst} {
  lassign [lindex [split [xschem instance_bbox $inst] "\n"] 0] _ x1 y1 x2 y2
  list [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}]
}
lassign [bbox_centre l1] LX LY
lassign [bbox_centre V1] VX VY
lassign [bbox_centre R1] RX RY
set WNX 100 ; set WNY 0            ;# on the NAMED wire, clear of the label
set WUX 100 ; set WUY 100          ;# on the unnamed (#netN) wire
set EMX 5000 ; set EMY 5000        ;# empty canvas

# --- harness: stub the queues so no ASE session / viewer is needed ---------------
set ::queued {}
set ::hilit  {}
proc ase::ui::dp_queue {key ex {kind {}} {token {}}} { lappend ::queued $ex ; lappend ::hilit $token }
proc ase::ui::sod_queue {key ex} { lappend ::queued $ex }
rename ase::ui::dp_finish ase::ui::dp_finish_real
proc ase::ui::dp_finish {key queue {qcolors {}}} { set ::plotted $queue; incr ::nplot }
set ::plotted {} ; set ::nplot 0

set ::notices {}
if {[info commands ciw_echo] ne {}} { rename ciw_echo real_ciw_echo }
proc ciw_echo {msg args} { lappend ::notices $msg }

# Observe what E resolved, and never let the chooser open: with no views the
# hi_descend_dialog_body bail is terminal, so a wrong noun-verb descend is visible as a
# non-empty ::resolved rather than as a modal that hangs the run.
rename hi_descend_enum_views hi_descend_enum_views_real
proc hi_descend_enum_views {instname} { set ::resolved $instname; return {} }
set ::resolved {}

# Arm a real Direct-Plot-flavour mode. do_raise 0 skips ase::ui::design_window, so no ASE
# session window has to exist -- the part under test is the canvas pick, which is
# session-free.
proc arm_sod {} {
  catch {ase::ui::sod_end K}
  array unset ::ase::ui::sod K,*
  unset -nocomplain ::ase::ui::sod(active)
  ase::ui::select_on_design K {save 0 plot 1} plot 0
  set ::queued {} ; set ::hilit {} ; set ::notices {} ; set ::resolved {}
  set ::plotted {} ; set ::nplot 0
  update idletasks
}

# One pick, then one E, with NOTHING in between -- the user's sequence exactly. Returns
# {queued selstate armed resolved}.
proc pick_then_e {x y} {
  xschem unselect_all
  arm_sod
  ase::ui::sod_click K $x $y
  update idletasks
  set st [selstate]
  hi_descend
  update idletasks
  list $::queued $st [armed] $::resolved
}

# --- SO0  fixture sanity: what IS under each click point ------------------------
# select_at is used here deliberately -- as an independent oracle of the hit-test, not as
# part of the pick. Each leg unselects afterwards so it cannot leak into the measurement.
xschem unselect_all
check "SO0a the label bbox centre really hits the label instance" \
  [lindex [xschem select_at $LX $LY] 0] {instance}
xschem unselect_all
check "SO0b the named-wire point really hits a wire" \
  [lindex [xschem select_at $WNX $WNY] 0] {wire}
xschem unselect_all
check "SO0c the unnamed-wire point really hits a wire" \
  [lindex [xschem select_at $WUX $WUY] 0] {wire}
xschem unselect_all
check "SO0d the vsource point really hits an instance" \
  [lindex [xschem select_at $VX $VY] 0] {instance}
xschem unselect_all
check "SO0e the named wire's net resolves through flylines" \
  [dict get [xschem flylines at $WNX $WNY] net] {NAMED}
xschem unselect_all
# No `catch` here on purpose: `xschem flylines at` always returns the six-key dict, so a
# bare `dict get` is safe -- and a catch would let an ERRORING flylines pass this leg with
# an empty variable, which is the failure mode this leg exists to rule out.
check "SO0f rule A6: flylines deliberately does NOT resolve the auto-named net" \
  [dict get [xschem flylines at $WUX $WUY] net] {}
xschem unselect_all

# --- SO13-SO14  the probes themselves: same answer, no side effect ---------------
# SO1-SO12 exercise the probes THROUGH sod_click. These two legs pin the C commands
# directly, so a regression in them is attributed to the right place -- and so the
# "byte-identical to a select_at row" claim in doc/claude/specs/select_at.md is a tested
# claim rather than a comment.
foreach {nm px py} [list label $LX $LY namedwire $WNX $WNY unnamedwire $WUX $WUY \
                         vsource $VX $VY device $RX $RY empty $EMX $EMY] {
  xschem unselect_all
  set probe [xschem object_at $px $py]
  # the probe must not have touched anything...
  check "SO13a/$nm object_at selects nothing" [selstate] {{} 0}
  check "SO13b/$nm object_at draws no selection" [xschem get lastsel] 0
  # ...and must return exactly what the MUTATING pick returns for the same point
  xschem unselect_all
  set mutating [xschem select_at $px $py]
  check "SO13c/$nm object_at row == select_at row" $probe $mutating
  xschem unselect_all
}

# net_name_at: the raw token on a WIRE, "" on anything else. The `#` and the original case
# must survive -- dp_hilight needs that form (`hilight_netname net1` finds nothing).
xschem unselect_all
check "SO14a net_name_at on a named wire gives the RAW token" \
  [xschem net_name_at $WNX $WNY] {NAMED}
check "SO14b net_name_at on the unnamed wire keeps the # form" \
  [expr {[string match {#net*} [xschem net_name_at $WUX $WUY]] ? 1 : 0}] 1
check "SO14c net_name_at on an INSTANCE body is empty (the wire-only gate)" \
  [list [xschem net_name_at $VX $VY] [xschem net_name_at $RX $RY] \
        [xschem net_name_at $LX $LY]] {{} {} {}}
check "SO14d net_name_at on empty canvas is empty" [xschem net_name_at $EMX $EMY] {}
check "SO14e and none of that selected anything" [selstate] {{} 0}
note "SO14f the unnamed token" [xschem net_name_at $WUX $WUY]
# the INDEX form -- what sod_net_at actually calls, so that it is not the untested half.
# Same answer as the coordinate form for the same wire, and out-of-range is "" not a crash.
# Pinned against a LITERAL, not against the coordinate form: comparing the two forms to
# each other would pass on a build where both return "".
set idx_named   [lindex [xschem object_at $WNX $WNY] 1]
set idx_unnamed [lindex [xschem object_at $WUX $WUY] 1]
check "SO14g net_name_at -wire on the named wire gives the token" \
  [xschem net_name_at -wire $idx_named] {NAMED}
check "SO14g2 net_name_at -wire on the unnamed wire keeps the # form" \
  [expr {[string match {#net*} [xschem net_name_at -wire $idx_unnamed]] ? 1 : 0}] 1
check "SO14g3 ... and both forms agree" \
  [list [xschem net_name_at -wire $idx_named] [xschem net_name_at -wire $idx_unnamed]] \
  [list [xschem net_name_at $WNX $WNY] [xschem net_name_at $WUX $WUY]]
check "SO14h net_name_at -wire out of range is empty, not an error" \
  [list [xschem net_name_at -wire 99999] [xschem net_name_at -wire -1]] {{} {}}
check "SO14i and the index form selected nothing either" [selstate] {{} 0}
xschem unselect_all

# --- SO1-SO2  a NET LABEL click: the reported bug -------------------------------
lassign [pick_then_e $LX $LY] q sel arm res
check "SO1a a net-label click still queues its net"            $q {v(named)}
check "SO1b THE POINT: it selected nothing"                    $sel {{} 0}
check "SO2a E right afterwards ARMS the pick (verb-noun)"      $arm 1
check "SO2b ... and did NOT descend into the label"            $res {}
disarm ; xschem unselect_all

# --- SO3-SO4  a BARE NAMED WIRE click -------------------------------------------
# The issue predicted this half might already be fine, because selected_set filters to
# ELEMENT and a selected WIRE is invisible to it. Measured, not assumed.
lassign [pick_then_e $WNX $WNY] q sel arm res
check "SO3a a named-wire click still queues its net"           $q {v(named)}
check "SO3b and selects nothing"                               $sel {{} 0}
check "SO4a E right afterwards arms the pick"                  $arm 1
check "SO4b ... and resolved no instance"                      $res {}
disarm ; xschem unselect_all

# --- SO5-SO6  an UNNAMED (#netN) wire: the fallback with no selection to read ----
lassign [pick_then_e $WUX $WUY] q sel arm res
# sod_expr maps `#netN` to `netN` for the simulator (test_ase_unnamed_net AN1 pins that),
# so the queued expression carries no `#`; the RAW token with its `#` is what sod_net_at
# must return, and dp_hilight is what needs that form.
check "SO5a THE 0154 FALLBACK still resolves an auto-named net" \
  [expr {[llength $q] == 1 && [string match {v(net*)} [lindex $q 0]] ? 1 : 0}] 1
check "SO5b and it did so without selecting the wire"          $sel {{} 0}
check "SO6a E right afterwards arms the pick"                  $arm 1
check "SO6b ... and resolved no instance"                      $res {}
note "SO5c the token the fallback produced"                    $q
disarm ; xschem unselect_all

# --- SO7-SO8  a VOLTAGE SOURCE body ---------------------------------------------
lassign [pick_then_e $VX $VY] q sel arm res
check "SO7a a vsource click still queues its current"          $q {i(v1)}
check "SO7b and selects nothing"                               $sel {{} 0}
check "SO8a E right afterwards arms the pick"                  $arm 1
check "SO8b ... and did NOT descend into the source"           $res {}
disarm ; xschem unselect_all

# --- SO9  a non-source device body: unchanged classification --------------------
xschem unselect_all
arm_sod
ase::ui::sod_click K $RX $RY
update idletasks
check "SO9a a non-source device body still queues nothing"     $::queued {}
check "SO9b ... but still gets the v1-scope notice"            \
  [expr {[llength $::notices] == 1 && [string match {ase: v1 queues source*} [lindex $::notices 0]] ? 1 : 0}] 1
check "SO9c and it selected nothing either"                    [selstate] {{} 0}
# a click that queues NOTHING used to poison the selection just as badly as one that
# queued: pre-fix this left R1 selected and E descended into the resistor. Same E leg as
# every other click class, so the "queues nothing" row of the issue's table is measured
# rather than assumed.
lassign [pick_then_e $RX $RY] q sel arm res
check "SO9d E after a click that queued nothing still arms"    $arm 1
check "SO9e ... and did NOT descend into the resistor"         $res {}
check "SO9f (and it still queued nothing, and selected nothing)" [list $q $sel] {{} {{} 0}}
disarm ; xschem unselect_all

# --- SO10  empty canvas: still silent ------------------------------------------
xschem unselect_all
arm_sod
ase::ui::sod_click K $EMX $EMY
update idletasks
check "SO10a an empty-canvas click still queues nothing"       $::queued {}
check "SO10b ... and still says nothing (no scolding a miss)"  $::notices {}
check "SO10c and selects nothing"                              [selstate] {{} 0}

# --- SO11  the user's gesture, through REAL Tk events ---------------------------
# Everything above calls sod_click as a proc. This group goes through the seized
# <ButtonPress-1> binding and the real <Key-e> binding installed by set_bindings, i.e.
# the path the user's hands actually take.
xschem unselect_all
arm_sod
focus -force .drw
update idletasks
check "SO11a the mode is seized before the click"              [seized] 1
event generate .drw <Motion>          -x [sx $LX] -y [sy $LY]
update idletasks
event generate .drw <ButtonPress-1>   -x [sx $LX] -y [sy $LY]
event generate .drw <ButtonRelease-1> -x [sx $LX] -y [sy $LY]
update idletasks
# SO11b is a CHECK, not a note, and it is the precondition of the whole group: if the
# synthesized ButtonPress ever stops landing on the label (a geometry or zoom change making
# sx/sy truncate elsewhere, a lost seize), SO11c/d/e would all pass on a click that did
# nothing at all, and the one group that reproduces the user's report end to end would be
# silently vacuous.
check "SO11b the real click actually picked the label"         $::queued {v(named)}
check "SO11c the real click selected nothing"                  [selstate] {{} 0}
event generate .drw <Key-e>
update idletasks ; update
check "SO11d THE USER'S BUG: a real E after a real pick ARMS"  [armed] 1
check "SO11e ... and descended into nothing"                   $::resolved {}
disarm ; xschem unselect_all

# --- SO12  a selection made BEFORE the mode still routes E noun-verb -------------
# The fix removes the PICK's mutation. It must not make E blind to a selection the user
# made deliberately -- that would break noun-verb descend (issue 0200's other half).
xschem unselect_all
xschem select_at $RX $RY
arm_sod
set ::resolved {}
hi_descend
update idletasks
check "SO12a a pre-existing instance selection still takes noun-verb" $::resolved {R1}
check "SO12b so E did NOT arm the pick"                        [armed] 0
disarm ; xschem unselect_all

} err]} { puts "FATAL: $err" ; incr fail }

if {[info commands real_ciw_echo] ne {}} {
  catch {rename ciw_echo {}}
  catch {rename real_ciw_echo ciw_echo}
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
