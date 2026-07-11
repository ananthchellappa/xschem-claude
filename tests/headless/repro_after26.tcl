# repro for after_26 short: drag R18 left from before_8.sch, both pins end on same copper
set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} { puts "SKIP no X"; exit 0 }
update idletasks; catch { focus -force $WIN }; update idletasks

set BP 4 ; set BR 5 ; set MOTION 6
set Button1Mask 256
set ::HERE [file dirname [file normalize [info script]]]

proc load_fixture {} {
  xschem load [file join $::HERE fixture_0105_pre.sch]
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::cadence_compat 1
  set ::fluid_editing 1; catch { xschem set fluid_editing 1 }
  set ::orthogonal_wiring 1; catch { xschem set orthogonal_wiring 1 }
  set ::autotrim_wires 1
  set ::enable_stretch 0
  xschem zoom_full; update idletasks
}
proc pnet {pin} { return [lindex [xschem instance_net R18 $pin] 0] }
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(round(($sx+$xo)/$zm))}] [expr {int(round(($sy+$yo)/$zm))}]
}
proc dumpwires {tag} {
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    puts "  $tag w$i: [xschem wire_coord $i]"
  }
}

# waypoints: list of {dx dy} relative to R18 origin; drag via LMB press on R18, motions, release at last
proc drag_case {label waypoints} {
  load_fixture
  lassign [xschem instance_coord R18] j1 j2 rx ry
  xschem unselect_all
  lassign [screen $rx $ry] psx psy
  xschem callback $::WIN $::BP $psx $psy 0 1 0 0
  xschem callback $::WIN $::MOTION $psx [expr {$psy-4}] 0 0 0 $::Button1Mask
  set tx $psx; set ty $psy
  foreach wp $waypoints {
    lassign $wp dx dy
    lassign [screen [expr {$rx+$dx}] [expr {$ry+$dy}]] tx ty
    xschem callback $::WIN $::MOTION $tx $ty 0 0 0 $::Button1Mask
  }
  xschem callback $::WIN $::BR $tx $ty 0 1 0 $::Button1Mask
  update idletasks
  lassign [xschem instance_coord R18] a1 a2 nrx nry
  set p [pnet P]; set m [pnet M]
  set verdict [expr {$p eq $m ? "SHORT" : "ok"}]
  puts "$label: R18 at ($nrx,$nry) P=$p M=$m -> $verdict"
  if {$p eq $m} { dumpwires $label }
}

# case 1: pure left in steps
drag_case "case1-pure-left" {{-30 0} {-60 0} {-90 0} {-110 0}}
# case 2: wobble left past target then back right (trace gesture 4 pattern)
drag_case "case2-wobble" {{-20 0} {-90 0} {-110 0} {-140 0} {-170 0} {-160 0} {-150 0} {-140 0} {-130 -10} {-110 0}}
# case 3: diagonal dip then return to row (trace gesture 1 pattern then settle left)
drag_case "case3-dip" {{-10 -10} {-50 -30} {-140 -80} {-170 -100} {-150 -100} {-140 -100} {-120 -40} {-110 0}}
puts "DONE"
exit 0
