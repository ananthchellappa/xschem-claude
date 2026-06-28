# issue 0053: return (Ctrl-E) / return-to-top (Alt-E) from a descend-NEW-WINDOW child
# must navigate the WINDOW chain (focus the parent window) instead of ascending the
# child in place. Drives the Cadence nav procs directly.
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_newwin_return.tcl
#
# Window creation works at the context level under --nogui (the Tk widgets do not, so
# focus_window's raise/focus is catch-guarded); the assertions check the C-side context
# (current_win_path / currsch / schname), which is what the navigation actually moves.

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
source [file join $REPO utils cadence_nav.tcl]

set ::fails 0
proc chk {name ok got} { puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name  -> $got"; flush stdout; if {!$ok} {incr ::fails} }
proc result {} { puts [expr {$::fails==0 ? {RESULT: ALL PASS} : "RESULT: $::fails FAILED"}]; flush stdout; exit [expr {$::fails!=0}] }
proc tail {} { return [file tail [xschem get schname]] }

# --- build hierarchy  A -> x1(B) -> x2(C) ---------------------------------
set work /tmp/descend_newwin_return_work
file delete -force $work; file mkdir $work
proc subsym {path} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.4 file_version=1.2}"
  puts $fp "G {type=subcircuit\ntemplate=\"name=x1\"}"
  puts $fp "V {}"; puts $fp "S {}"; puts $fp "E {}"
  puts $fp "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=inout}"
  puts $fp "T {@symname} -20 -34 0 0 0.2 0.2 {}"
  close $fp
}
proc sch_with_inst {path sym instname} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.4 file_version=1.2}"
  puts $fp "G {}"; puts $fp "V {}"; puts $fp "S {}"; puts $fp "E {}"
  if {$sym ne {}} { puts $fp "C {$sym} 0 0 0 0 {name=$instname}" }
  close $fp
}
subsym $work/b.sym
subsym $work/c.sym
sch_with_inst $work/a.sch b.sym x1
sch_with_inst $work/b.sch c.sym x2
sch_with_inst $work/c.sch {} {}
set XSCHEM_LIBRARY_PATH $work

# ---- Scenario 1: Ctrl-E from a descend-new-window child returns to the parent window
xschem load $work/a.sch
xschem unselect_all; xschem select instance 0
hi_descend target=new_window
set w2 [xschem get current_win_path]
chk "S1 descend-newwin opens child showing B" \
  [expr {$w2 ne {.drw} && [tail] eq {b.sch} && [xschem get currsch]==1}] \
  "win=$w2 sch=[tail] currsch=[xschem get currsch]"
chk "S1 parent link recorded (.drw, entry 1)" \
  [expr {[cadence::parent_window $w2] eq {.drw} && [cadence::entry_level $w2]==1}] \
  "parent=[cadence::parent_window $w2] entry=[cadence::entry_level $w2]"
cadence::return_one_level
chk "S1 Ctrl-E focuses parent window showing A (child not ascended in place)" \
  [expr {[xschem get current_win_path] eq {.drw} && [tail] eq {a.sch} && [xschem get currsch]==0}] \
  "win=[xschem get current_win_path] sch=[tail] currsch=[xschem get currsch]"
chk "S1 child window kept open" [cadence::win_live $w2] "win_live($w2)=[cadence::win_live $w2]"
catch {xschem new_schematic destroy_all force}

# ---- Scenario 2: Alt-E (return-to-top); W1 descends A->B in place, then new-window C
xschem load $work/a.sch
xschem unselect_all; xschem select instance 0; xschem descend
xschem unselect_all; xschem select instance 0
hi_descend target=new_window
set w2b [xschem get current_win_path]
chk "S2 descend-newwin opens child showing C (currsch 2)" \
  [expr {$w2b ne {.drw} && [tail] eq {c.sch} && [xschem get currsch]==2}] \
  "win=$w2b sch=[tail] currsch=[xschem get currsch]"
cadence::return_to_top
chk "S2 Alt-E focuses original window, ascended to top (A)" \
  [expr {[xschem get current_win_path] eq {.drw} && [tail] eq {a.sch} && [xschem get currsch]==0}] \
  "win=[xschem get current_win_path] sch=[tail] currsch=[xschem get currsch]"
chk "S2 Alt-X location remembered on root window" \
  [expr {[info exists cadence::last_loc(.drw)] && [llength $cadence::last_loc(.drw)]==2}] \
  "last_loc=[expr {[info exists cadence::last_loc(.drw)] ? $cadence::last_loc(.drw) : {<unset>}}]"
catch {xschem new_schematic destroy_all force}

# ---- Scenario 3 (Q2): in-place descents inside a child unwind before hopping out
xschem load $work/a.sch
xschem unselect_all; xschem select instance 0
hi_descend target=new_window               ;# child shows B (entry 1)
set w2c [xschem get current_win_path]
xschem unselect_all; xschem select instance 0; xschem descend   ;# in-place B->C in the child
chk "Q2 child descended further in place to C (entry stays 1)" \
  [expr {[xschem get current_win_path] eq $w2c && [tail] eq {c.sch} && [xschem get currsch]==2 && [cadence::entry_level $w2c]==1}] \
  "win=[xschem get current_win_path] sch=[tail] currsch=[xschem get currsch] entry=[cadence::entry_level $w2c]"
cadence::return_one_level
chk "Q2 first Ctrl-E unwinds in place within the child (C->B)" \
  [expr {[xschem get current_win_path] eq $w2c && [tail] eq {b.sch} && [xschem get currsch]==1}] \
  "win=[xschem get current_win_path] sch=[tail] currsch=[xschem get currsch]"
cadence::return_one_level
chk "Q2 next Ctrl-E hops to the parent window (A)" \
  [expr {[xschem get current_win_path] eq {.drw} && [tail] eq {a.sch}}] \
  "win=[xschem get current_win_path] sch=[tail]"
catch {xschem new_schematic destroy_all force}

# ---- Scenario 4: a plain window (no descend link) ascends in place like go_back
xschem load $work/a.sch
xschem unselect_all; xschem select instance 0; xschem descend
cadence::return_one_level
chk "plain (no-link) window Ctrl-E ascends in place to A" \
  [expr {[xschem get current_win_path] eq {.drw} && [tail] eq {a.sch} && [xschem get currsch]==0}] \
  "win=[xschem get current_win_path] sch=[tail] currsch=[xschem get currsch]"

result
