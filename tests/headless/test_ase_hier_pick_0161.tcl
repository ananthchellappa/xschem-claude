# A signal picked from a DESCENDED schematic queued an unqualified name (issue 0161).
#
# `ase::ui::sod_expr` is a pure string wrap, so a click at currsch>0 produced
# `v(mid)` where the simulator only knows `v(x1.x2.mid)`, and `i(v1)` where it
# knows `i(v.x1.x2.v1)`. Measured against ngspice-42 on this very fixture
# (xschem netlist -> ngspice -b), the raw carries:
#     x1.x2.mid           : voltage
#     v.x1.x2.v1#branch   : current
# and `.save v(x1.x2.mid) i(v.x1.x2.v1)` is accepted verbatim.
#
# The fix qualifies the TOKEN at the click site (`ase::ui::sod_qualify`, called
# from sod_click) and leaves `sod_expr` a pure string wrap -- HP1-HP3 below are
# that contract, mirroring test_ase_interact H1 which calls sod_expr with no
# design loaded.
#
# Why the engine does the resolving and not a Tcl path-prefix:
#   - a child PORT is not `x1.A`, it is the PARENT's net (HP7/HP12: leaf `A` two
#     levels down resolves to the top-level `TOPNET`),
#   - an unconnected port picks up the parent's auto-name at the level where it
#     stops (HP13: leaf `B` -> `x1.net1`, prefixed ONE level, not two),
#   - a global net is flat, never prefixed (HP16: `0` -> `0`),
#   - buses expand per bit under the prefix (HP14).
# `xschem resolved_net` (hilight.c) already does all four; nothing in Tcl could.
#
# Currents have no such resolver, so sod_qualify mirrors send_current_to_graph()
# (hilight.c): `i(` + the branch prefix + sch_path + name + `)` when there is
# hierarchy, bare `i(name)` at the top -- which is exactly what ngspice showed.
# CORRECTED for casemode item 9: that used to read "v." + the LOWERCASED
# sch_path. sod_qualify no longer folds anything -- it answers in the schematic's
# own spelling and the prefix follows the token's first character -- and sod_expr
# folds the composed name when (and only when) the requested mode is `fold`. The
# fold-mode literals below are therefore unchanged byte for byte; the other two
# modes are pinned in test_ase_sod_case.tcl.
#
# Legs (HP*):
#   HP1-HP3   sod_expr stays PURE (no design loaded) and stays UNQUALIFIED even
#             while descended -- the qualification belongs to its caller.
#   HP4-HP6   top level is unchanged, byte for byte (voltage, current, notice).
#   HP7-HP8   depth 1: a child port resolves to the parent net.
#   HP9-HP17  depth 2: internal net, current, port chase, dangling port,
#             auto-named `#` net, bus + 0159 bit dialog, global, and the 0153
#             colour cue still getting the RAW schematic token.
#   HP18      ascending restores the plain top-level name (no state leak).
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_hier_pick_0161.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
## call sod_qualify without letting a missing proc abort the file: RED-first, the
## proc does not exist yet and the remaining legs still have to report.
proc q {kind token} {
  if {[catch {ase::ui::sod_qualify $kind $token} r]} { return "ERR: $r" }
  return $r
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here   [file normalize [file dirname [info script]]]
set fixdir [file join $here fixtures ase_hier]

# --- HP1-HP2  purity: sod_expr with NOTHING loaded (test_ase_interact H1) ------
## RESTATED, casemode batch item 9 (same ids, same expected strings): sod_expr's
## case mode is now a REQUIRED third argument. `fold` is A1's default everywhere,
## so both literals are unchanged; the purity contract these two legs exist for is
## strengthened rather than weakened, because passing the mode in is exactly what
## keeps sod_expr from having to ask the engine for it.
check "HP1 sod_expr is pure and lowercases a net (no design loaded)" \
  [ase::ui::sod_expr voltage MID fold] {v(mid)}
check "HP2 sod_expr is pure and lowercases a source (no design loaded)" \
  [ase::ui::sod_expr current V1 fold] {i(v1)}
check "HP3 sod_qualify is a no-op with no design loaded" \
  [q voltage mid] {mid}

# --- pick harness: stub the queues so no ASE session is needed (0160 idiom) ----
set ::queued {}
set ::hilit  {}
proc ase::ui::dp_queue {key ex {kind {}} {token {}}} {
  lappend ::queued $ex ; lappend ::hilit $token
}
proc ase::ui::sod_queue {key ex} { lappend ::queued $ex }
proc ase::ui::bus_dialog {key token bits} { return $::bus_dialog_answer }
set ::bus_dialog_answer {}
set ::notices {}
if {[info commands ciw_echo] ne {}} { rename ciw_echo real_ciw_echo }
proc ciw_echo {msg args} { lappend ::notices $msg }

# one pick, returning what it queued
proc pick {x y {mode plot} {flavor tobeplotted}} {
  array set ase::ui::sod [list k,flavor $flavor k,mode $mode k,count 0]
  xschem unselect_all
  set ::queued {} ; set ::hilit {} ; set ::notices {}
  ase::ui::sod_click k $x $y
  return $::queued
}

if {[catch {

if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$fixdir:$XSCHEM_LIBRARY_PATH"
xschem load [file join $fixdir ase_hier_top.sch]

# --- HP4-HP6  the top level must not move -------------------------------------
check "HP4 (control) top level still queues the plain net name" \
  [pick 50 0] {v(topnet)}
check "HP5 (control) top level still queues the plain source current" \
  [pick 0 90] {i(v9)}
check "HP6 (control) top level, Outputs flavor too" \
  [pick 50 0 outputs tobesaved] {v(topnet)}
## teeth for the `currsch<=0 -> identity` guard: at the top level sod_qualify must
## not call the engine at all. A bus RANGE is the discriminator -- resolved_net
## expands it (`a[1:0]` -> `a[1],a[0]`), identity does not. Without this leg,
## deleting the guard passes the whole file (measured).
check "HP6b sod_qualify is identity at the top, engine not consulted" \
  [q voltage {a[1:0]}] {a[1:0]}

# --- HP7-HP8  depth 1 ----------------------------------------------------------
xschem unselect_all; xschem select instance x1; xschem descend
check_true "HP7 fixture: descended one level" \
  [expr {[xschem get currsch] == 1 && [xschem get sch_path] eq {.x1.}}]
## `A` is a PORT of ase_hier_mid, wired at the top to TOPNET: the correct
## simulator name is the PARENT's net, with no prefix at all.
check "HP8 a descended port pick resolves to the parent net" \
  [pick 50 0] {v(topnet)}

# --- HP9-HP17  depth 2 ---------------------------------------------------------
xschem unselect_all; xschem select instance x2; xschem descend
check_true "HP9 fixture: descended two levels" \
  [expr {[xschem get currsch] == 2 && [xschem get sch_path] eq {.x1.x2.}}]

check "HP10 an internal net is path-qualified" \
  [pick 250 60] {v(x1.x2.mid)}
check "HP11 a source current takes the i(v.<path>.<name>) form" \
  [pick 200 30] {i(v.x1.x2.v1)}
check "HP12 a port chases TWO levels up to the parent net" \
  [pick 50 0] {v(topnet)}
## leaf pin B is dangling at the mid level, so resolution stops there: the name
## is the mid-level auto net, prefixed by ONE level -- not x1.x2.B.
check "HP13 a dangling port stops at the level that names it" \
  [pick 50 -200] {v(x1.net1)}
set ::bus_dialog_answer [list {bus[1]} {bus[0]}]
check "HP14 a bus qualifies PER BIT (composes with the 0159 bit dialog)" \
  [pick 50 -100] [list {v(x1.x2.bus[1])} {v(x1.x2.bus[0])}]
set ::bus_dialog_answer {}
## 0154's `#` strip and this prefix must compose: the marker goes, the path stays.
check "HP15 an auto-named net is stripped AND qualified" \
  [pick 450 -100] {v(x1.x2.net1)}
check "HP16 a global net stays flat (never prefixed)" \
  [q voltage 0] {0}
## the 0153 colour cue needs the RAW schematic token -- `xschem hilight_netname
## x1.x2.mid` finds nothing. Qualification must touch the expr only.
check "HP17 the 0153 colour cue still gets the RAW token, not the qualified one" \
  [list [pick 250 60] $::hilit] [list {v(x1.x2.mid)} {mid}]

## sod_expr itself must STILL be the pure wrap, even here: it is the caller that
## qualifies. If this ever fails, the resolution leaked into the pure helper and
## H1 (no design loaded) is living on borrowed time.
## RESTATED with an explicit `fold` (casemode item 9); expectation unchanged.
check "HP3b sod_expr stays unqualified while descended (purity contract)" \
  [ase::ui::sod_expr voltage mid fold] {v(mid)}

# --- HP18  ascending leaves no residue ----------------------------------------
xschem go_back; xschem go_back
check_true "HP18 fixture: back at the top" [expr {[xschem get currsch] == 0}]
check "HP18b the top-level name is plain again" [pick 50 0] {v(topnet)}

} err]} { puts "FATAL: $err" ; incr fail }

## restore the real ciw_echo OUTSIDE the catch, so a FATAL cannot leave the stub
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
