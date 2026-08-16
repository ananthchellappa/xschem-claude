# Ctrl-Shift-X: descend into the ONE selected instance's schematic view in a NEW
# window, read-only -- the E-dialog "New Window" path (cadence::descend_into_inst_newwin_ro).
# See doc/claude/specs/cadence_descend_newwin_ro.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_cadence_descend_newwin_ro.tcl
#
# Reuses the hi_descend fixture (top.sch with instance x1 that has a schematic view).
# The exactly-one-instance GATE and the read-only new-window descend are both scriptable
# headless (the new-window descend is already exercised by SELNW in test_hi_descend.tcl).

set here    [file normalize [file dirname [info script]]]
set utils   [file normalize [file join $here .. .. utils]]
set fixroot [file normalize [file join $here fixtures hi_descend]]
set lib     [file join $fixroot hidlib]
lappend pathlist $lib                 ;# register hidlib (lib/cell/view layout) via auto-discovery
set top     [file join $lib top schematic top.sch]

if {[info commands ciw_echo] eq ""} { proc ciw_echo {args} {} }
source [file join $utils cadence_nav.tcl]

set fails 0
proc check {name ok detail} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name $detail"; flush stdout
  if {!$ok} {incr ::fails}
}
proc schname {} { return [xschem get schname] }
proc has {needle} { return [expr {[string first $needle [schname]] >= 0}] }
# reload top fresh, close any windows a prior subtest opened, clear selection/override
proc reload {} {
  global top
  catch {xschem new_schematic destroy_all force}
  set ::hi_descend_view_path {}
  xschem load $top
  xschem unselect_all
}

# --- GATE-none: nothing selected -> silent no-op (no window, no descend) ----------
reload
set w0 [llength [xschem windows]]
cadence::descend_into_inst_newwin_ro
check "GATE-none nothing selected is a no-op" \
  [expr {[llength [xschem windows]] == $w0 && [xschem get currsch] == 0 && [has top.sch]}] \
  "(wins=$w0->[llength [xschem windows]] currsch=[xschem get currsch] name=[schname])"

# --- GATE-multi: instance + wire selected -> no-op (needs EXACTLY one instance) ----
reload
set w0 [llength [xschem windows]]
xschem select instance x1 fast
xschem select wire 0 fast
cadence::descend_into_inst_newwin_ro
check "GATE-multi instance+wire selection is a no-op" \
  [expr {[llength [xschem windows]] == $w0 && [xschem get currsch] == 0 && [has top.sch]}] \
  "(wins=$w0->[llength [xschem windows]] currsch=[xschem get currsch] name=[schname])"

# --- GATE-nonelem: exactly ONE object selected, but it is not an instance ----------
# The reject half of the gate that the live-read rewrite (issue 0259) must preserve:
# lastsel is 1, so the first arm passes, and only "is it an ELEMENT" can refuse.
# (A wire stands in for any non-ELEMENT type; adding a text to the fixture would dirty
# it and write top~.sch into the committed tree.)
reload
xschem select wire 0 fast
check "GATE-nonelem one non-instance object selected still refuses" \
  [expr {[cadence::one_instance_selected] == 0 && [xschem get lastsel] == 1}] \
  "(gate=[cadence::one_instance_selected] lastsel=[xschem get lastsel] set={[xschem selected_set]})"

# --- GATE-stale: THE FALSE REFUSAL (issue 0259 part b) ----------------------------
# `xschem get first_sel` is a sticky MEMO: set_first_sel() (select.c) stores only into an
# EMPTY slot, and the slot is emptied only by unselect_all / delete. So select a wire,
# then an instance, then deselect the wire, and the selection really IS exactly one
# instance -- lastsel 1, selected_set {x1} -- while first_sel still names the WIRE.
# The gate answered 0: Ctrl-X did nothing and said nothing, while `xschem descend` on the
# very same selection returned 1. The gate now asks live.
reload
xschem select wire 0 fast
xschem select instance x1 fast
xschem select wire 0 fast clear
check "GATE-stale-setup exactly one INSTANCE is selected, but first_sel still says WIRE" \
  [expr {[xschem get lastsel] == 1 && [xschem selected_set] eq {{x1}} &&
         [lindex [xschem get first_sel] 0] == 1}] \
  "(lastsel=[xschem get lastsel] set={[xschem selected_set]} first_sel={[xschem get first_sel]})"
check "GATE-stale the gate reads the LIVE selection, not the memo" \
  [expr {[cadence::one_instance_selected] == 1}] \
  "(gate=[cadence::one_instance_selected])"
set w0 [llength [xschem windows]]
cadence::descend_into_inst
check "GATE-stale-descend Ctrl-X on that selection descends (it used to do nothing)" \
  [expr {[xschem get currsch] == 1 && [xschem get sch_path] eq {.x1.} && [has /schematic/leaf.sch]}] \
  "(currsch=[xschem get currsch] path=[xschem get sch_path] name=[schname])"

# --- GATE-brace: an instname the Tcl list parser cannot read (issue 0388) ----------
# The first live-read rewrite of the gate asked `llength [xschem selected_set]`, and
# selected_set hand-wraps each instname in braces with NO quoting (scheduler.c). An
# instance whose name= holds an unbalanced brace therefore makes it an INVALID Tcl list,
# llength THROWS, and cadence::descend_into_inst propagates the error -- a working Ctrl-X
# turned into a stack trace. The gate now asks `xschem selection`, which carries indices
# and type words only and cannot be poisoned by user text.
# Works on a /tmp copy for the same reason the NAMELESS block in test_hi_descend does:
# inserting an instance dirties the sheet and the set_modify hook would write top~.sch
# into the COMMITTED fixture.
set bwork /tmp/cadence_gate_brace_work
file delete -force $bwork; file mkdir $bwork
file copy -force $lib $bwork/blib     ;# different lib NAME so `hidlib/leaf` still resolves via $lib
catch {xschem new_schematic destroy_all force}
set ::hi_descend_view_path {}
xschem load [file join $bwork blib top schematic top.sch]
xschem unselect_all
xschem instance hidlib/leaf 600 600 0 0 {name=xb\{roken}
xschem unselect_all
xschem select instance 2 fast
set rcg [catch {cadence::one_instance_selected} gres]
check "GATE-brace an unreadable instname neither throws nor closes the gate" \
  [expr {$rcg == 0 && $gres == 1 && [xschem get lastsel] == 1}] \
  "(rc=$rcg res={$gres} lastsel=[xschem get lastsel] set={[xschem selected_set]})"
set rcd [catch {cadence::descend_into_inst} dres]
check "GATE-brace-descend Ctrl-X on it still descends" \
  [expr {$rcd == 0 && [xschem get currsch] == 1 && [has /schematic/leaf.sch]}] \
  "(rc=$rcd res={$dres} currsch=[xschem get currsch] name=[schname])"
while {[xschem get currsch] > 0} { xschem go_back }
file delete -force $bwork

# --- DESCEND: exactly one instance -> new window, REAL descend, read-only ----------
reload
set w0 [llength [xschem windows]]
xschem select instance x1 fast
cadence::descend_into_inst_newwin_ro
check "DESCEND opens a NEW window" \
  [expr {[llength [xschem windows]] == $w0 + 1}] \
  "(wins=$w0->[llength [xschem windows]])"
check "DESCEND is a REAL descend into x1's schematic" \
  [expr {[xschem get currsch] == 1 && [xschem get sch_path] eq {.x1.} && [has /schematic/leaf.sch]}] \
  "(currsch=[xschem get currsch] path=[xschem get sch_path] name=[schname])"
check "DESCEND child is READ-ONLY" \
  [expr {[xschem get readonly] == 1}] "(ro=[xschem get readonly])"
catch {xschem new_schematic destroy_all force}

# --- Ctrl-Y : descend into the selected instance's SYMBOL (issue 0410) ------------
# The `i` steal in src/cadence_style_rc ends in `break`, which stops the event reaching
# the generic <KeyPress> -> C dispatcher -- the only key route to descend-into-symbol.
# So in cadence mode the verb had NO key at all. Ctrl-Y (Cadence's own chord) restores it.
# --nogui has no Tk (`info commands bind` is empty), so the chord is asserted from the
# SHIPPED rc TEXT -- the same precedent as test_snap_bindkeys.tcl / test_keybind_snap_grid.tcl
# -- and the captured body is then EVALUATED, so the behaviour rows exercise the line that
# actually ships rather than a hand-copied duplicate of the verb.
# (The installed-on-.drw half needs real Tk and lives in test_altf5_ciw.tcl: CYT1-CYT3.)
set rcfile [file normalize [file join $here .. .. src cadence_style_rc]]
set fh [open $rcfile r] ; set rctext [read $fh] ; close $fh

set cybody {}
set cyn [regexp -line {^bind \.drw <Control-Key-y>\s+\{([^\}]*)\}} $rctext -> cybody]
check "CY1 cadence_style_rc binds Ctrl-Y on .drw" [expr {$cyn == 1}] \
  "(matches=$cyn body={$cybody})"
check "CY2 the Ctrl-Y body is non-empty and runs the BARE verb `xschem descend_symbol`" \
  [expr {[string trim $cybody] ne {} &&
         [regexp {(?:^|;)\s*xschem\s+descend_symbol\s*(?:;|$)} $cybody]}] \
  "(body={$cybody})"
check "CY3 the Ctrl-Y body ends in `break`, like the rest of the hierarchy family" \
  [regexp {;\s*break\s*$} $cybody] "(body={$cybody})"
check "CY4 the `i` -> Create Instance steal is untouched" \
  [regexp -line {^bind \.drw <Key-i> \{xschem create_instance; break\}$} $rctext] \
  "(rc=$rcfile)"
set cydup 0
foreach ln [split $rctext \n] {
  if {[string match {bind .drw *} $ln] && [string match {*descend_symbol*} $ln]} { incr cydup }
}
check "CY5 exactly ONE .drw bind line in the rc names descend_symbol" \
  [expr {$cydup == 1}] "(lines=$cydup)"
check "CY10 no competing chord: no <Control-Shift-Key-Y> bind and no C-table ctrl-y row" \
  [expr {![regexp -line {^bind \.drw <Control-Shift-Key-Y>} $rctext] &&
         ![regexp -line {^xschem bind key 121 ctrl} $rctext]}] "(rc=$rcfile)"

# Behaviour, driven by the shipped body with its trailing `break` removed. A body that
# will not run in a bare interpreter -- an empty `{break}`, a renamed callee, a cadence::
# wrapper proc the rc defines but no headless session can source -- must make these rows
# RED, not abort the suite before the later ones report, so the eval is caught.
set cyrun [regsub {;\s*break\s*$} $cybody {}]
proc cyeval {script} {
  if {[catch {uplevel #0 $script} r]} { return "ERR:$r" }
  return $r
}
reload
xschem select instance x1 fast
set cyret [cyeval $cyrun]
set cydeep [xschem get currsch]
check "CY6 Ctrl-Y on one selected instance descends into its SYMBOL" \
  [expr {$cyret eq {1} && $cydeep == 1 && [has /hidlib/leaf/symbol/leaf.sym]}] \
  "(ret={$cyret} currsch=$cydeep name=[schname])"
cadence::return_one_level
check "CY8 Ctrl-E returns from a Ctrl-Y symbol descend (no extra bookkeeping needed)" \
  [expr {$cydeep == 1 && [xschem get currsch] == 0 && [has /hidlib/top/schematic/top.sch]}] \
  "(currsch=$cydeep->[xschem get currsch] name=[schname])"

# The refusal SPEAKS (the issue-0251 channel), which is exactly why the bind calls the
# bare verb instead of a cadence:: wrapper: descend_into_inst's gate refuses in silence.
reload
set cyret [cyeval $cyrun]
check "CY7 Ctrl-Y with nothing selected refuses OUT LOUD, and does not descend" \
  [expr {$cyret eq {0} && [xschem get descend_error] eq {no-selection} &&
         [xschem get statusmsg] eq {Descend symbol: select an instance to descend into} &&
         [xschem get currsch] == 0}] \
  "(ret={$cyret} err={[xschem get descend_error]} msg={[xschem get statusmsg]} currsch=[xschem get currsch])"

# ACCEPT-SET RAIL: the core accepts instance+wire (it counts ELEMENTs), the cadence gate
# does not. Goes red the moment anyone re-routes Ctrl-Y through descend_into_inst-style
# gating, which would ADD a silent refusal on a selection the core handles.
reload
xschem select instance x1 fast
xschem select wire 0 fast
set cygate [cadence::one_instance_selected]
set cyret [cyeval $cyrun]
check "CY9 Ctrl-Y keeps the CORE's accept set (instance+wire descends; the gate refuses)" \
  [expr {$cyret eq {1} && [xschem get currsch] == 1 && [has /hidlib/leaf/symbol/leaf.sym] &&
         $cygate == 0}] \
  "(ret={$cyret} gate=$cygate currsch=[xschem get currsch] name=[schname])"
catch {xschem new_schematic destroy_all force}

puts "cadence_descend_newwin_ro headless: [expr {$fails ? "$fails FAILURE(S)" : {all checks passed}}]"
