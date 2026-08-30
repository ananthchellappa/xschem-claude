# tests/headless/test_ase_simdlg_0937.tcl -- ISSUE 0937: THE SIMULATOR LIST HAS
# NO DOOR IN THE GUI, AND FORGETS ITSELF AT EVERY RESTART. Backlog item S2.
#
# ============================================================================
# WHAT THE USER CANNOT DO
# ============================================================================
# Issue 0931 shipped a working simulator registry with no way into it. The real
# ASE-L session window was opened on the dev display at 439d1087 and its whole
# menubar walked -- nine menus, and NOT ONE ENTRY ANYWHERE mentions a simulator
# program. Setup offers exactly Design... and Model Files.... The only way to
# point xschem at a build of your own is to type Tcl into the CIW.
#
# And typing it into the CIW does not stick: `ase::sim_write_conf`, the writer
# this dialog is required to call, has ZERO callers in the shipped tree, so a
# simulator registered in one run is completely gone in the next.
#
# ============================================================================
# WHAT THIS FILE OWNS, AND WHAT IT DOES NOT
# ============================================================================
# THIS file owns the DOOR: the menu entry, the dialog, the row editor, the
# in-dialog feedback, and the fact that the dialog calls the ONE writer instead
# of growing a second one.
#
# tests/headless/test_ase_simreg_0931.tcl section H owns the non-GUI half the
# door cannot be built without -- the four new sentences in the mint, the
# per-entry reason a Problem column shows, the recorder that lets the dialog
# repeat the CIW's own words, and the cleared-choice-survives-a-restart fix
# (issue 0932). Every expectation below that quotes a sentence quotes it from
# the MINT, never from a literal here, so this file cannot drift from that one.
#
# ============================================================================
# THE WIDGET CONTRACT -- read this before implementing, it is what the rows
# assert
# ============================================================================
#   $top.mb.setup            entry labelled  Simulators...  (…)
#                            -command [list ase::ui::simulators_dialog $key]
#   $top.simdlg              the dialog toplevel
#   $top.simdlg.tv           treeview, -columns name path problem,
#                            headings Name / Program / Problem, row ids
#                            0..n-1 in registration order
#   $top.simdlg.use          readonly combobox, -textvariable
#                            ase::ui::simuse($key); first value is
#                            ase::ui::simdlg_none_label
#   $top.simdlg.status       THE in-dialog feedback surface
#   $top.simdlg.where        where the list is saved
#   $top.simdlg.btns.add / .edit / .remove / .close
#   $top.simrow              the row editor
#   $top.simrow.name         Name entry, read-only in Edit
#   $top.simrow.path         Program entry
#   $top.simrow.browse       the file browser button
#   $top.simrow.status       the editor's OWN feedback surface
#   $top.simrow.btns.proceed / .cancel
#   procs: ase::ui::simulators_dialog simdlg_fill simdlg_status simdlg_commit
#          simdlg_editor simdlg_browse simdlg_ok simdlg_remove simdlg_use
#          simdlg_none_label
#
# ============================================================================
# THE ANSWER DISCIPLINE -- an absent widget must never satisfy a golden
# ============================================================================
# A missing MINT answers NOMINT; a missing WIDGET answers NOWIDGET; a missing
# PROC answers NOPROC. They are deliberately different words, because a row
# that compares "what the dialog shows" against "what the mint says" would go
# GREEN on a tree where NEITHER exists if both sides answered the same way.
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE -- READ BEFORE TRUSTING IT
# ============================================================================
# * THE FILE BROWSER IS MODAL. tk_getOpenFile grabs and waits, so no headless
#   or Xvfb run can press OK in it. S14 asserts the WIRING and the body, and
#   says so out loud rather than pretending to cover the click.
# * NO SIMULATOR IS EVER STARTED. Every program here is a two-line /bin/sh
#   stub or a deliberately broken file.
# * THE SAVED LIST GOES TO A SCRATCH DIRECTORY. ::USER_CONF_DIR is redirected
#   for the whole run and restored at the end, so a suite run never touches the
#   developer's own saved simulator list.
#
# Arms:
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_simdlg_0937.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_simdlg_0937.tcl   (structural rows only)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- the answer discipline ---------------------------------------------------
proc cx {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR: $r" }
  return $r
}
## The MINT side. NOMINT, never an empty string: an absent sentence must not
## be able to satisfy a row that expects a blank cell.
proc mint {args} {
  set cmd [lindex $args 0]
  if {![llength [info commands $cmd]]} { return NOMINT }
  if {[catch {uplevel #0 $args} r]} { return "MINTRAISED: $r" }
  return $r
}
proc pcall {args} {
  set cmd [lindex $args 0]
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {uplevel #0 $args} r]} { return "RAISED: $r" }
  return $r
}
## The WIDGET side.
proc wex {w} {
  if {[catch {winfo exists $w} e]} { return 0 }
  return $e
}
proc wtext {w} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {$w cget -text} t]} { return NOTEXT }
  return $t
}
proc wcget {w opt} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {$w cget $opt} v]} { return NOOPT }
  return $v
}
proc wrows {tv} {
  if {![wex $tv]} { return NOWIDGET }
  if {[catch {$tv children {}} v]} { return NOROWS }
  return $v
}
proc wcell {tv item col} {
  if {![wex $tv]} { return NOWIDGET }
  if {[catch {$tv set $item $col} v]} { return NOCELL }
  return $v
}
proc whead {tv col} {
  if {![wex $tv]} { return NOWIDGET }
  if {[catch {$tv heading $col -text} v]} { return NOHEAD }
  return $v
}
proc winv {w args} {
  if {![wex $w]} { return NOWIDGET }
  set rc [catch {uplevel #0 [linsert $args 0 $w invoke]} r]
  catch {update}
  if {$rc} { return "INVRAISED: $r" }
  return $r
}
proc went {w txt} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {$w delete 0 end}]} { return NOENTRY }
  if {[catch {$w insert 0 $txt}]} { return NOENTRY }
  return OK
}
proc wget {w} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {$w get} v]} { return NOENTRY }
  return $v
}
## The labels of a menu, in order, so a missing entry is a visible absence
## rather than an exception.
proc mlabels {m} {
  if {![wex $m]} { return NOWIDGET }
  set out {}
  set last -1
  if {[catch {$m index end} last]} { return NOINDEX }
  if {$last eq {none} || $last eq {}} { return {} }
  for {set i 0} {$i <= $last} {incr i} {
    set l {}
    catch {set l [$m entrycget $i -label]}
    lappend out $l
  }
  return $out
}
proc mcmd {m label} {
  if {![wex $m]} { return NOWIDGET }
  if {[catch {$m entrycget $label -command} c]} { return NOENTRY }
  return $c
}

# --- deliver a REAL generated key, WSLg-robustly (test_ase_dialogs idiom) -----
proc send_key {w ev done} {
  for {set i 0} {$i < 200} {incr i} {
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    if {[winfo exists $w]} {
      focus -force $w
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[winfo exists $w] && [focus -displayof $w] eq $w} {
        event generate $w $ev
        update
        if {[uplevel 1 [list expr $done]]} { return 1 }
      }
    }
    after 50
  }
  return 0
}

# --- registry drivers --------------------------------------------------------
proc simnames {} {
  if {![llength [info commands ase::sim_list]]} { return NOPROC }
  set out {}
  foreach e [ase::sim_list] { catch {lappend out [dict get $e name]} }
  return $out
}
proc simfield {name key} {
  if {![llength [info commands ase::sim_list]]} { return NOPROC }
  foreach e [ase::sim_list] {
    if {[catch {dict get $e name} n]} { continue }
    if {$n ne $name} { continue }
    if {[catch {dict get $e $key} v]} { return "NOKEY-$key" }
    return $v
  }
  return "NOENTRY-$name"
}
proc simreset {} { catch {ase::sim_clear} }

# --- source readers, for the structural rows ---------------------------------
proc slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
proc nocomment {path} {
  set out {}
  foreach l [split [slurp $path] "\n"] {
    if {[regexp {^\s*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
proc scount {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
## Every proc body in $src whose name begins with $prefix, concatenated. The
## count comes back too, so a row about "there is no second log call in these
## procs" cannot pass by finding no procs at all.
proc procbodies {src prefix} {
  set out {} ; set n 0 ; set on 0
  foreach l [split $src "\n"] {
    if {$on} {
      if {[regexp {^\}} $l]} { set on 0 ; continue }
      lappend out $l
      continue
    }
    if {[regexp {^proc\s+(\S+)\s} $l -> nm]} {
      if {[string first $prefix $nm] == 0} { set on 1 ; incr n }
    }
  }
  return [list $n [join $out "\n"]]
}

# --- locations, cwd-independent ---------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_simdlg]

set ASETCL [file join $repo src ase.tcl]
set ASEWIN [file join $repo src ase_window.tcl]
set SPECMD [file join $repo doc claude specs ase_l.md]

proc a_wr {path body {mode 0644}} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
  catch {file attributes $path -permissions $mode}
}

set STUB    [file join $scratch bin ngstub]
set STUB2   [file join $scratch bin ngstub2]
set STUB3   [file join $scratch bin ngstub3]
set MISSING [file join $scratch bin there-is-no-such-file]
set ADIR    [file join $scratch bin adir]
a_wr $STUB  "#!/bin/sh\nexit 0\n" 0755
a_wr $STUB2 "#!/bin/sh\nexit 0\n" 0755
a_wr $STUB3 "#!/bin/sh\nexit 0\n" 0755
file mkdir $ADIR
file delete -force $MISSING

## THE SAVED LIST GOES HERE, NOT INTO THE DEVELOPER'S OWN CONFIG. Redirected
## for the whole run and restored in the teardown, because this suite makes the
## dialog SAVE and the writer's target is $::USER_CONF_DIR/ase_simulators.
set UCD_HAD [info exists ::USER_CONF_DIR]
set UCD_OLD {}
if {$UCD_HAD} { set UCD_OLD $::USER_CONF_DIR }
set CONFDIR [file join $scratch conf]
file mkdir $CONFDIR
set ::USER_CONF_DIR $CONFDIR

# ============================================================================
# STRUCTURAL ROWS -- these run on BOTH arms, display or none
# ============================================================================

## S13: the 0930 interceptor already logs every menu pick BY CONSTRUCTION. A
## dialog that adds its own log call would double every line. Non-vacuous by
## construction: the row also counts the procs it scanned, so "no log call"
## cannot be satisfied by "no procs".
set SRCW [nocomment $ASEWIN]
set S13B [procbodies $SRCW ase::ui::simdlg]
set S13B2 [procbodies $SRCW ase::ui::simulators_dialog]
set S13TXT "[lindex $S13B 1]\n[lindex $S13B2 1]"
set S13N [expr {[lindex $S13B 0] + [lindex $S13B2 0]}]
check {S13 STRUCTURAL the dialog does not log its own picks a second time -- the menu interceptor already does it, by construction} \
  [list [expr {$S13N >= 5}] [scount $S13TXT {log_action}] [scount $S13TXT {log_gesture}] \
        [scount $SRCW "-command \[list ase::ui::simulators_dialog \$key\]"]] \
  [list 1 0 0 1]

## S14 STRUCTURAL HALF. THE BROWSER IS MODAL AND THEREFORE UNPRESSABLE FROM A
## SUITE: tk_getOpenFile grabs the display and waits for a human. What is
## assertable is that the button is wired to a proc, and that the proc really
## opens a file browser and really writes what it gets back into the Program
## field. The click itself is DECLARED UNCOVERED here rather than faked.
set S14B [lindex [procbodies $SRCW ase::ui::simdlg_browse] 1]
check {S14a STRUCTURAL the Browse button's proc really opens a file browser and puts the answer in the Program field -- the modal click itself is not coverable by any suite} \
  [list [expr {[scount $S14B {tk_getOpenFile}] >= 1}] \
        [expr {[scount $S14B {.path}] >= 1}]] \
  [list 1 1]

## S16: the written menu tree is what a reader trusts before they open the
## program. W1m of test_ase_window treats these labels as v2-spec-fixed.
set SPEC [slurp $SPECMD]
set S16BUL {}
if {[regexp {\n- \*\*Setup\*\*(.*?)\n- \*\*} $SPEC -> S16BUL]} { } else { set S16BUL ZZNOBULLET }
check {S16 STRUCTURAL the written menu tree lists the new Setup entry, so the document and the menubar say the same thing} \
  [expr {[string first {Simulators} $S16BUL] >= 0}] 1

# ============================================================================
# THE FIXTURE -- a real library, cell and simulation-state view
# ============================================================================
set sch_text {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 420 -330 600 -330 {}
N 380 -300 380 -330 {}
N 380 -330 250 -330 {}
N 250 -270 600 -270 {}
N 420 -300 420 -270 {}
C {sky130_fd_pr/nfet_01v8} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1}
C {devices/vsource} 250 -300 0 0 {name=V2 value=1.8}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 500 -330 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -330 0 0 {name=lG lab=G}
}
file mkdir [file join $scratch aselib nfet_clean schematic]
set f [open [file join $scratch aselib nfet_clean schematic nfet_clean.sch] w]
puts -nonewline $f $sch_text
close $f
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE aselib [file join $scratch aselib]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}
set rundir [file normalize [file join $scratch run]]

set FIXOK 1
if {[catch {
  library_new_view aselib nfet_clean ngspice_state1 ngspice_state1
  set spath [xschem cellview_path aselib/nfet_clean ngspice_state1]
  if {$spath eq {}} { error "fixture: state view did not resolve" }
  set spath [file normalize $spath]
  set key [ase::session_key aselib nfet_clean ngspice_state1]
  ase::session_open $key $spath
  set st [ase::session_state $key]
  dict set st rundir $rundir
  ase::session_update $key $st
  ase::session_save $key
  ase::session_close $key
} fixerr]} {
  set FIXOK 0
  puts "FIXTURE ERROR: $fixerr"
}
check {S0 the fixture library, cell and simulation-state view were created} $FIXOK 1

# ============================================================================
# THE GUI LEGS -- a real session window, a real menubar, real widgets
# ============================================================================
if {$FIXOK && [info exists ::has_x] && [info commands winfo] ne {}} {

  check {S1a the ASE-L session window opens} [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  check_true {S1a the session window is up} [expr {$top ne {} && [winfo exists $top]}]

  # --- S1: THE DOOR -----------------------------------------------------
  # Measured at 439d1087: nine menus walked, "menu entries mentioning a
  # simulator = 0". Setup offered Design... and Model Files... and nothing
  # else. The row asserts the LABEL, the COMMAND and that invoking the real
  # menu entry -- not calling the proc -- is what opens the dialog.
  set SIMLBL "Simulators…"
  set S1LABELS [mlabels $top.mb.setup]
  set S1CMD [mcmd $top.mb.setup $SIMLBL]
  set S1OPEN [winv $top.mb.setup $SIMLBL]
  check {S1 the Setup menu has a Simulators entry, wired to the dialog, and picking it from the real menu is what opens the dialog} \
    [list [expr {[lsearch -exact $S1LABELS $SIMLBL] >= 0}] \
          $S1CMD \
          [expr {[string first todo_stub $S1CMD] < 0}] \
          [wex $top.simdlg]] \
    [list 1 [list ase::ui::simulators_dialog $key] 1 1]

  # --- S12: THE PICK REACHES THE ACTION LOG -----------------------------
  # The W1m2 idiom of test_ase_window: spy on the 0930 interceptor itself, so
  # this works under --nolog where there is no log file to read. Two terms,
  # and the first is what makes it non-vacuous -- the interceptor must be
  # installed, or the second would pass on any tree at all.
  set ::s12_seen {}
  set s12_installed [expr {[info commands ::menu_unlogged] ne {} ? 1 : 0}]
  if {$s12_installed} {
    rename ::menu_invoke_logged ::s12_real
    proc ::menu_invoke_logged {w real args} {
      if {[lindex $args 0] eq {invoke}} {
        set c {}
        catch {set c [$real entrycget [lindex $args 1] -command]}
        lappend ::s12_seen $c
      }
      uplevel 1 [list ::s12_real $w $real {*}$args]
    }
  }
  catch {destroy $top.simdlg}
  update
  winv $top.mb.setup $SIMLBL
  if {$s12_installed} {
    rename ::menu_invoke_logged {}
    rename ::s12_real ::menu_invoke_logged
  }
  check {S12 picking Simulators from the menu goes through the logger every menu pick goes through, carrying that entry's own command -- once, not twice} \
    [list $s12_installed $::s12_seen] \
    [list 1 [list [list ase::ui::simulators_dialog $key]]]

  # --- S2: THE LIST SHOWS WHAT IS REGISTERED ----------------------------
  # Three entries, one good and two broken in different ways. The Problem
  # cell must be the SAME sentence the registry gives for that entry -- not
  # a re-worded one, and not a bare flag.
  simreset
  pcall ase::sim_register good2 $STUB
  pcall ase::sim_register miss2 $MISSING
  pcall ase::sim_register dir2  $ADIR
  catch {destroy $top.simdlg}
  winv $top.mb.setup $SIMLBL
  pcall ase::ui::simdlg_fill $key
  update
  set TV $top.simdlg.tv
  set S2ROWS [wrows $TV]
  set S2P1 [wcell $TV 1 problem]
  set S2P2 [wcell $TV 2 problem]
  ## THE FIRST TWO PROBLEM TERMS DO NOT MENTION THE MINT, AND THAT IS THE
  ## POINT. "the cell equals ase::sim_entry_why" is a TAUTOLOGY when that
  ## proc returns an empty string: both sides go blank together and the row
  ## stays green while the Problem column tells the user nothing about a
  ## simulator that cannot start. Measured -- blanking the body of
  ## ase::sim_entry_why reddened only the registry rows R5 R6 R7 and left
  ## this file 23/23 until these two terms existed. The answer discipline at
  ## the top of this file covers a proc that is ABSENT; this covers the one
  ## shape it cannot, a proc that is PRESENT and says nothing. Each broken
  ## entry's cell must carry words, and must name that entry's own program.
  check {S2 the dialog lists every registered simulator, with the user's own name and program, and says against each broken one exactly what the registry says about it} \
    [list $S2ROWS \
          [whead $TV name] [whead $TV path] [whead $TV problem] \
          [wcell $TV 0 name] [wcell $TV 0 path] [wcell $TV 0 problem] \
          [wcell $TV 1 name] [wcell $TV 1 path] \
          [expr {[string trim $S2P1] ne {} && [string first $MISSING $S2P1] >= 0}] \
          [expr {[string trim $S2P2] ne {} && [string first $ADIR $S2P2] >= 0}] \
          [expr {$S2P1 eq [mint ase::sim_entry_why miss2]}] \
          [expr {$S2P2 eq [mint ase::sim_entry_why dir2]}]] \
    [list [list 0 1 2] Name Program Problem good2 $STUB {} miss2 $MISSING 1 1 1 1]

  # --- S3: THE IN-FORCE CONTROL IS A REAL WIDGET WITH A REAL VARIABLE ----
  simreset
  pcall ase::sim_register a3 $STUB
  pcall ase::sim_register b3 $STUB2
  catch {destroy $top.simdlg}
  winv $top.mb.setup $SIMLBL
  update
  set S3VAR [wcget $top.simdlg.use -textvariable]
  set S3BEFORE NOVAR
  if {$S3VAR ne {NOWIDGET} && $S3VAR ne {NOOPT} && $S3VAR ne {}} {
    catch {set S3BEFORE [set ::$S3VAR]}
    catch {set ::$S3VAR b3}
    catch {event generate $top.simdlg.use <<ComboboxSelected>>}
    update
  }
  set S3EXE [pcall ase::sim_exe ngspice]
  check {S3 the dialog says which simulator is in use, and choosing another one in it really changes which program will start} \
    [list $S3BEFORE [pcall ase::sim_selected] $S3EXE \
          [expr {[wtext $top.simdlg.status] eq [mint ase::sim_why in_force b3 $STUB2]}]] \
    [list a3 b3 $STUB2 1]

  # --- S4: "NONE OF MINE -- USE THE PROGRAM ON MY PATH" ------------------
  set S4NONE [mint ase::ui::simdlg_none_label]
  set S4VALS [wcget $top.simdlg.use -values]
  if {$S3VAR ne {NOWIDGET} && $S3VAR ne {NOOPT} && $S3VAR ne {}} {
    catch {set ::$S3VAR $S4NONE}
    catch {event generate $top.simdlg.use <<ComboboxSelected>>}
    update
  }
  set S4ST [pcall ase::sim_status ngspice]
  set S4SRC NOSRC
  catch {set S4SRC [dict get $S4ST source]}
  check {S4 the dialog offers "none of mine, use the program on my PATH", it is offered first, and picking it really hands control back to the PATH} \
    [list [expr {[lindex $S4VALS 0] eq $S4NONE && $S4NONE ne {NOMINT}}] \
          [pcall ase::sim_selected] $S4SRC \
          [expr {[wtext $top.simdlg.status] eq [mint ase::sim_why path_in_force ngspice {}]}]] \
    [list 1 {} path 1]

  # --- S5: ADD, THROUGH THE REAL ROW EDITOR -----------------------------
  simreset
  catch {destroy $top.simdlg}
  winv $top.mb.setup $SIMLBL
  update
  winv $top.simdlg.btns.add
  update
  set S5OPEN [wex $top.simrow]
  went $top.simrow.name mybuild5
  went $top.simrow.path $STUB
  winv $top.simrow.btns.proceed
  update
  check {S5 Add lets you type a name and the location of your own build, and after OK it is in the list and in the registry} \
    [list $S5OPEN [wex $top.simrow] [wrows $top.simdlg.tv] \
          [wcell $top.simdlg.tv 0 name] [simnames] [simfield mybuild5 path]] \
    [list 1 0 [list 0] mybuild5 [list mybuild5] $STUB]

  # --- S6: VALIDATION FEEDBACK IS IN THE DIALOG, NOT ONLY IN THE CIW -----
  # Silence is this area's failure mode and the precedent next door is bad:
  # Setup > Design and the shared list dialog behind Model Files report to
  # the CIW only. An editor that just sits there teaches the user nothing.
  winv $top.simdlg.btns.add
  update
  went $top.simrow.name {}
  went $top.simrow.path $STUB2
  winv $top.simrow.btns.proceed
  update
  set S6MSG [wtext $top.simrow.status]
  set S6PLAIN PLAIN
  if {$S6MSG eq {NOWIDGET} || $S6MSG eq {NOTEXT} || [string trim $S6MSG] eq {}} {
    set S6PLAIN NOSENTENCE
  } else {
    ## `ase: ` -- ONE colon and a space -- IS ON THIS LIST DELIBERATELY, and
    ## `ase::` cannot stand in for it. Every refusal the registry raises is
    ## prefixed "ase: ", a CIW convention that means nothing next to the
    ## field the user just got wrong, and ase::ui::simdlg_plain exists to
    ## take it off before the editor shows it. Measured -- deleting that
    ## strip left this file 23/23 and the registry file 58/58, because
    ## "ase::" does not match "ase: ", and the user read the internal prefix
    ## on every refusal in the row editor with no suite saying a word.
    foreach tok {ase:: {ase: } sim_ dict proc} {
      if {[string first $tok $S6MSG] >= 0} { set S6PLAIN "JARGON-$tok" }
    }
  }
  check {S6 pressing OK with no name keeps the editor up and writes a plain-English reason INSIDE it, where the user is looking} \
    [list [wex $top.simrow] $S6PLAIN [simnames]] \
    [list 1 PLAIN [list mybuild5]]
  winv $top.simrow.btns.cancel
  update

  # --- S7: A BAD PATH IS KEPT AND EXPLAINED, IN THE SAME WORDS ----------
  pcall ase::sim_said_clear
  winv $top.simdlg.btns.add
  update
  set S7OPEN [wex $top.simrow]
  went $top.simrow.name broken7
  went $top.simrow.path $MISSING
  winv $top.simrow.btns.proceed
  update
  set S7SAID [pcall ase::sim_said]
  check {S7 a location with no program at it is kept and explained rather than thrown away, and the dialog shows the very sentence the CIW was given} \
    [list $S7OPEN [wex $top.simrow] [simnames] \
          [expr {[wcell $top.simdlg.tv 1 problem] eq [mint ase::sim_entry_why broken7]}] \
          [expr {$S7SAID ne {NOPROC} && $S7SAID ne {} \
                 && [wtext $top.simdlg.status] eq $S7SAID}]] \
    [list 1 0 [list mybuild5 broken7] 1 1]

  # --- S10: THE DIALOG SAVES, THROUGH THE ONE WRITER --------------------
  # Nothing in the shipped tree calls ase::sim_write_conf. Measured across
  # two real restarts: SAVED FILE EXISTS: 0, and the next run printed
  # AFTER RESTART registered = (nothing).
  set CONFFILE [pcall ase::sim_conf_file]
  set S10TXT {}
  if {$CONFFILE ne {NOPROC} && $CONFFILE ne {} && [file exists $CONFFILE]} {
    set S10TXT [slurp $CONFFILE]
  }
  check {S10a adding a simulator in the dialog saves the list where it will be read back at the next start} \
    [list [expr {$CONFFILE ne {NOPROC} && $CONFFILE ne {} && [file isfile $CONFFILE]}] \
          [expr {[string first {ase::sim_register} $S10TXT] >= 0}] \
          [expr {[string first {mybuild5} $S10TXT] >= 0}]] \
    [list 1 1 1]

  ## The 0932 half, seen from the dialog: "use the program on my PATH" is a
  ## choice, and the file has to carry it or the next start silently puts the
  ## first entry back in force.
  set S10VAR [wcget $top.simdlg.use -textvariable]
  if {$S10VAR ne {NOWIDGET} && $S10VAR ne {NOOPT} && $S10VAR ne {}} {
    catch {set ::$S10VAR [mint ase::ui::simdlg_none_label]}
    catch {event generate $top.simdlg.use <<ComboboxSelected>>}
    update
  }
  set S10TXT2 {}
  if {$CONFFILE ne {NOPROC} && $CONFFILE ne {} && [file exists $CONFFILE]} {
    set S10TXT2 [slurp $CONFFILE]
  }
  check {S10b choosing "use the program on my PATH" in the dialog is written down too, so the next start does not quietly put one of yours back in charge} \
    [list [pcall ase::sim_selected] \
          [expr {[string first "ase::sim_select \{\}" $S10TXT2] >= 0}]] \
    [list {} 1]

  # --- S8: REMOVE WORKS ON THE ONE IN USE, AND SAYS WHAT HAPPENS NEXT ----
  # Measured in all three arms at 439d1087: "removing the in-force entry
  # SAID: (nothing at all)".
  simreset
  pcall ase::sim_register keep8 $STUB2
  pcall ase::sim_register gone8 $STUB
  pcall ase::sim_select gone8
  catch {destroy $top.simdlg}
  winv $top.mb.setup $SIMLBL
  update
  catch {$top.simdlg.tv selection set 1}
  update
  winv $top.simdlg.btns.remove
  update
  check {S8a removing the simulator that was in use, with one left, says which one takes over -- and it really does} \
    [list [simnames] [pcall ase::sim_selected] \
          [expr {[wtext $top.simdlg.status] eq [mint ase::sim_why removed_now_other gone8 {} keep8]}]] \
    [list [list keep8] keep8 1]

  catch {$top.simdlg.tv selection set 0}
  update
  winv $top.simdlg.btns.remove
  update
  check {S8b removing the last one says the program your system finds on your PATH is what will start now} \
    [list [simnames] [pcall ase::sim_selected] \
          [expr {[wtext $top.simdlg.status] eq [mint ase::sim_why removed_now_path keep8 {}]}]] \
    [list {} {} 1]

  # --- S9: EDIT DOES NOT THROW AWAY WHAT THE DIALOG DOES NOT SHOW -------
  # The dialog offers Name and Program only. Extra arguments and the backend
  # an entry was registered for are invisible in it -- and an editor that
  # rebuilt the entry from its two visible fields would silently delete them.
  simreset
  pcall ase::sim_register one9   $STUB
  pcall ase::sim_register two9   $STUB2 -args {-q -x} -backend ngspice
  pcall ase::sim_register three9 $STUB3
  catch {destroy $top.simdlg}
  winv $top.mb.setup $SIMLBL
  update
  catch {$top.simdlg.tv selection set 1}
  update
  winv $top.simdlg.btns.edit
  update
  set S9OPEN [wex $top.simrow]
  set S9NAME [wget $top.simrow.name]
  set S9RO [wcget $top.simrow.name -state]
  went $top.simrow.path $STUB3
  winv $top.simrow.btns.proceed
  update
  check {S9 changing an entry's program leaves everything the dialog does not show exactly as it was, and the entry keeps its place in the list} \
    [list $S9OPEN $S9NAME [expr {$S9RO ne {normal} && $S9RO ne {NOWIDGET} && $S9RO ne {NOOPT}}] \
          [simnames] [simfield two9 path] [simfield two9 args] [simfield two9 backend]] \
    [list 1 two9 1 [list one9 two9 three9] $STUB3 [list -q -x] ngspice]

  # --- S11: A SAVE THAT CANNOT HAPPEN IS NOT SILENT ---------------------
  catch {file attributes $CONFDIR -permissions 0500}
  if {[file writable $CONFDIR]} {
    puts "SKIP: S11 needs a directory this user cannot write to (running as root?)"
    catch {file attributes $CONFDIR -permissions 0755}
  } else {
    simreset
    catch {destroy $top.simdlg}
    winv $top.mb.setup $SIMLBL
    update
    pcall ase::sim_said_clear
    winv $top.simdlg.btns.add
    update
    went $top.simrow.name cantsave11
    went $top.simrow.path $STUB
    winv $top.simrow.btns.proceed
    update
    set S11SAID [pcall ase::sim_said]
    check {S11 when the list cannot be saved the dialog says so, in the same words, and still keeps what you just added} \
      [list [simnames] \
            [expr {$S11SAID ne {NOPROC} && $S11SAID ne {} \
                   && [wtext $top.simdlg.status] eq $S11SAID}] \
            [expr {[string first {could not be saved} $S11SAID] >= 0}]] \
      [list [list cantsave11] 1 1]
    catch {file attributes $CONFDIR -permissions 0755}
  }

  # --- S17: THE DIALOG RE-WORDS NOTHING ---------------------------------
  # Ruling D5-4: a user-facing sentence is minted in ONE place and rendered
  # by callers. Three states, three minted sentences, byte for byte.
  simreset
  pcall ase::sim_register ok17 $STUB
  catch {destroy $top.simdlg}
  winv $top.mb.setup $SIMLBL
  update
  set S17A [wtext $top.simdlg.status]
  simreset
  pcall ase::sim_register bad17 $MISSING
  pcall ase::ui::simdlg_fill $key
  update
  set S17B [wtext $top.simdlg.status]
  simreset
  pcall ase::ui::simdlg_fill $key
  update
  set S17C [wtext $top.simdlg.status]
  check {S17 whatever state the list is in, the dialog shows the sentence the rest of xschem would show -- it never writes its own version} \
    [list [expr {$S17A eq [mint ase::sim_why in_force ok17 $STUB]}] \
          [expr {$S17B eq [mint ase::sim_why missing bad17 $MISSING]}] \
          [expr {$S17C eq [mint ase::sim_why path_in_force ngspice {}]}]] \
    [list 1 1 1]

  # --- S14 WIRING HALF --------------------------------------------------
  simreset
  pcall ase::sim_register w14 $STUB
  catch {destroy $top.simdlg}
  winv $top.mb.setup $SIMLBL
  update
  winv $top.simdlg.btns.add
  update
  check {S14b the Browse button sits in the row editor beside the Program field and is wired to the file browser} \
    [list [wex $top.simrow.browse] [wcget $top.simrow.browse -command]] \
    [list 1 [list ase::ui::simdlg_browse $key]]

  # --- S15: ESC, AND NO RECORDS LEFT BEHIND -----------------------------
  ## THE FIRST TERM IS NOT DECORATION. `send_key` returns 1 the moment its
  ## done-condition holds, and "the row editor is gone" holds trivially on a
  ## tree where the row editor was never built -- so without a witness that
  ## both windows were UP first, this row passes an empty tree.
  ##
  ## THE LAST TERM HERE MEASURES THE ESC PATH ONLY, and cannot be read as
  ## cover for the session-level cleanup: ESC runs ase::ui::simdlg_close,
  ## which drops the dialog's own records itself, so ase::ui::close finds
  ## nothing left to drop and deleting its cleanup lines reddens nothing
  ## here. S18 below is the row that reaches them, by closing the session
  ## window with the Simulators window still standing.
  set S15WAS [list [wex $top.simrow] [wex $top.simdlg]]
  set S15E1 [send_key $top.simrow <Key-Escape> {![winfo exists $top.simrow]}]
  update
  set S15E2 [send_key $top.simdlg <Key-Escape> {![winfo exists $top.simdlg]}]
  update
  ase::ui::close $key
  update
  set S15LEFT [array names ::ase::ui::dlg $key,*]
  check {S15 ESC dismisses the row editor and the dialog through their own Cancel path, and closing the session window leaves nothing of them behind} \
    [list $S15WAS $S15E1 [wex $top.simrow] $S15E2 [wex $top.simdlg] $S15LEFT] \
    [list [list 1 1] 1 0 1 0 {}]

  # --- S18: CLOSE THE SESSION WITH THE DIALOG STILL STANDING ------------
  ## S15 ABOVE CANNOT SEE THE SESSION-LEVEL CLEANUP AND NEVER COULD. Its ESC
  ## runs ase::ui::simdlg_close, which already drops the dialog's own two
  ## records and the combobox variable, so by the time ase::ui::close is
  ## reached there is nothing left for it to find -- measured, by deleting
  ## BOTH of ase::ui::close's cleanup lines in turn and watching this file
  ## stay at 23/23 and the registry file at 58/58 each time.
  ##
  ## The only way to reach that cleanup is the way a user reaches it: leave
  ## the Simulators window open and close the ASE-L session window out from
  ## under it. Whichever simulator the combobox was showing is remembered
  ## per SESSION on purpose -- it has to outlive the dialog, so that
  ## re-opening the dialog shows the same choice -- which is exactly why the
  ## session going away is the moment it has to be dropped. Without that,
  ## the next session opened under the same name inherits a stale pick.
  ##
  ## The first term is the witness that makes the rest non-vacuous: both
  ## records must be PRESENT before the close, or "they are gone afterwards"
  ## is true of a tree where they were never written.
  check {S18a the session window opens again after being closed} \
    [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top18 [ase::ui::window_for $key]
  simreset
  pcall ase::sim_register keeps18 $STUB
  winv $top18.mb.setup $SIMLBL
  update
  set S18WAS [list [wex $top18.simdlg] \
                   [info exists ::ase::ui::dlg($key,simnames)] \
                   [info exists ::ase::ui::simuse($key)]]
  ase::ui::close $key
  update
  check {S18 closing the ASE-L session window while the Simulators window is still open takes the whole of it with it -- the list it was showing and the simulator it had picked are not left behind for the next session to inherit} \
    [list $S18WAS [wex $top18.simdlg] \
          [array names ::ase::ui::dlg $key,*] \
          [info exists ::ase::ui::simuse($key)]] \
    [list [list 1 1 1] 0 {} 0]

} else {
  puts "SKIP: S1-S12 S14b S15 S17 S18 need a display (the dialog is the subject)"
}

# --- teardown ----------------------------------------------------------------
simreset
catch {file attributes $CONFDIR -permissions 0755}
if {$UCD_HAD} { set ::USER_CONF_DIR $UCD_OLD } else { catch {unset ::USER_CONF_DIR} }

# --- verdict -----------------------------------------------------------------
# THE DUAL BANNER IS REQUIRED by tests/run_regression.tcl's hcases list, which
# this file is registered in. banner_complete needs a WHOLE-LINE OVERALL line
# as well as the RESULT line.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
