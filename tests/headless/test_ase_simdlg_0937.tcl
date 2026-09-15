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
# AND, since issue 1370, the SESSION WINDOW'S OWN BOTTOM BAR where it reports
# what a gesture in this dialog just changed -- rows S20-S23. That is a pixel
# question in two ways this suite is the only home for: the bar must follow a
# real gesture with no session update behind it, and it must follow it in
# EVERY open session window, because the registry is process-global while the
# dialog is per-session. What the bar is told to SAY in each registry state is
# section L of tests/headless/test_ase_simreg_0931.tcl, with no display at all.
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
#   procs: ase::ui::simulators_dialog simdlg_fill simdlg_status
#          simdlg_editor simdlg_browse simdlg_ok simdlg_remove simdlg_use
#          simdlg_none_label
#   1395:  there is NO ase::ui::simdlg_commit any more. It was the dialog's own
#          `catch {ase::sim_write_conf}` after every gesture and the tree's only
#          caller of the writer; the write now lives on ase::sim_register /
#          sim_unregister, so the Command-window door persists too. S10a still
#          measures that the dialog's Add reaches the file -- through the
#          mutation instead of through the gesture.
#   1370:  $top.status.sim  carries "Simulator: [ase::sim_label <backend>]";
#          ase::ui::refresh_status_all walks every open session and is called
#          from the LAST LINE of ase::ui::simdlg_fill
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
#
# ============================================================================
# FLOOR: 55 checks on the display arm, 5 on the structural one. RAISED, NEVER
# LOWERED. It was 48 / 5 before issue 1395, with S10b red -- that row asserted
# the pre-ruling contract (the dialog's choice reaching disk) and was rewritten
# in place rather than deleted; S40-S46 are the new contract's own rows.
# ============================================================================

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
## The chooser side (issue 1371). NOVALUES / NOPICK, never {} or a silent
## success: a row that reads "what is offered" must not be satisfiable by a
## chooser that does not exist.
proc wvalues {w} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {$w cget -values} v]} { return NOVALUES }
  return $v
}
## PICK THE WAY A USER PICKS: only what the chooser is OFFERING can be chosen.
## `$w set` would happily store a label the list does not contain, which would
## let a row about the offered set pass on a tree that offers nothing.
proc wpick {w label} {
  if {![wex $w]} { return NOWIDGET }
  set vals [wvalues $w]
  if {$vals eq {NOVALUES}} { return NOVALUES }
  set i [lsearch -exact $vals $label]
  if {$i < 0} { return "NOTOFFERED: $label" }
  if {[catch {$w current $i}]} { return NOPICK }
  catch {update}
  return OK
}
proc wcheck {w val} {
  if {![wex $w]} { return NOWIDGET }
  set v {}
  if {[catch {$w cget -variable} v]} { return NOVAR }
  if {$v eq {}} { return NOVAR }
  if {[catch {set ::$v $val}]} { return NOVAR }
  catch {update}
  return OK
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

## --- ISSUE 1371: TWO STUBS THAT REALLY ANSWER THE CASE-MODE PROBE ----------
## The capability probe asks the program three times, once per mode, with
## `-D casemode=<mode>` on the command line, and reads the `CCM=` line back
## (src/xschem.tcl, sim_probe_deck / sim_probe_parse). A `#!/bin/sh exit 0`
## stub answers nothing, so it measures as NEVER PROBED -- which is one of the
## cases below, but it cannot be the case where a chooser has something to
## offer. CMSTUB echoes back whatever was asked for, so it measures as
## delivering all three; NOCM answers the way a released ngspice with no
## casemode feature at all answers, which the probe records as `fold` alone.
## Neither is a simulator and neither is asked to be one: every row here is
## about which modes are OFFERED, and that is a question about the probe's
## answer, not about a circuit.
set CMSTUB [file join $scratch bin ngcase]
set NOCM   [file join $scratch bin ngnocase]
a_wr $CMSTUB "#!/bin/sh\nm=fold\nfor a in \"\$@\"; do\n  case \"\$a\" in\n    casemode=*) m=\${a#casemode=} ;;\n  esac\ndone\necho \"CCM=\$m\"\nexit 0\n" 0755
a_wr $NOCM "#!/bin/sh\necho 'Error: curcasemode: no such variable.'\necho 'CCM='\nexit 0\n" 0755

## THE THIRD STUB, AND IT IS ISSUE 1371's REPAIR: ONE FILE, TWO TRUTHS. It
## answers the way NOCM does when it is given `-q` and the way CMSTUB does when
## it is not, so "what can the program at this location do" has no answer until
## you also say what it will be started WITH. The capability probe has always
## run the program with the entry's own extra arguments (ruling A2 -- probe with
## the real argv), so this is not a contrivance; what WAS a contrivance was a
## cache keyed on the file name alone. Row S38 is the measurement.
set ARGSTUB [file join $scratch bin ngargs]
a_wr $ARGSTUB "#!/bin/sh\nq=0\nm=fold\nfor a in \"\$@\"; do\n  case \"\$a\" in\n    -q) q=1 ;;\n    casemode=*) m=\${a#casemode=} ;;\n  esac\ndone\nif \[ \$q = 1 ]; then\n  echo 'Error: curcasemode: no such variable.'\n  echo 'CCM='\nelse\n  echo \"CCM=\$m\"\nfi\nexit 0\n" 0755

## THE PROBE ITSELF, REPLACED FOR ONE GESTURE. Two of the states issue 1371's
## adversary found cannot be reached with a stub program: a probe that COMPLETES
## and recognises nothing (`casemode_detected {}`, the second arm of the
## `casemode_measured` mint), and the question "what did the status line say at
## the instant the launch began". Both are properties of the hook, so the hook
## is what is stood in for -- renamed, not redefined in place, so the real one
## comes back byte-identical.
proc probe_stub_install {body} {
  if {![llength [info commands ::ase::backend::ngspice::capabilities]]} { return 0 }
  if {[llength [info commands ::zz_real_caps]]} { return 0 }
  rename ::ase::backend::ngspice::capabilities ::zz_real_caps
  proc ::ase::backend::ngspice::capabilities {exe exeargs workdir} $body
  return 1
}
proc probe_stub_remove {} {
  if {![llength [info commands ::zz_real_caps]]} { return 0 }
  rename ::ase::backend::ngspice::capabilities {}
  rename ::zz_real_caps ::ase::backend::ngspice::capabilities
  return 1
}

## THE PROBE'S SCRATCH AREA MUST NOT LAND IN THE DEVELOPER'S OWN SIMULATION
## DIRECTORY. ase::cap_workdir builds `.ase_probe` under `set_netlist_dir 0`;
## ::netlist_dir is the documented global that answers with, and this is the
## same redirection test_ase_simcaps_0948.tcl makes for the same reason.
set NDSAVE [expr {[info exists ::netlist_dir] ? $::netlist_dir : {ZZUNSET}}]
set LNDSAVE [expr {[info exists ::local_netlist_dir] ? $::local_netlist_dir : {ZZUNSET}}]
set ::local_netlist_dir 0
set ::netlist_dir [file join $scratch simdir]
file mkdir $::netlist_dir

## --- a real restart, for the one row that claims one -------------------------
## Nothing in-process can prove "it comes back after a restart". HOME is what
## moves ::USER_CONF_DIR, so the child is given a HOME of its own inside this
## suite's scratch tree and never sees the developer's list.
##
## THE FORGERY TRAP (test_ase_simreg_0931's): anything lifted out of a child's
## stdout is scrubbed before it can reach a check's detail line, so a child
## that printed a banner cannot forge this file's own verdict.
set ::SCRUB [list [format {%s:} RESULT] {R#SULT:} \
                  [format {%s: %s} OVERALL ok] {OV#RALL ok} \
                  {FAIL:} {F#IL:} \
                  [format {%s: %s} FATAL signal] {F#TAL sig}]
proc child_val {tag body home key} {
  global scratch
  set script [file join $scratch ch_$tag.tcl]
  set out    [file join $scratch ch_$tag.out]
  a_wr $script "if {\[catch {\n$body\n} ::zerr\]} {\n  puts \"Z_ERR=\$::zerr\"\n  flush stdout\n  exit 9\n}\n"
  set had [info exists ::env(HOME)] ; set old {}
  if {$had} { set old $::env(HOME) }
  set ::env(HOME) $home
  catch {exec timeout 40 [info nameofexecutable] --nogui --pipe -q --nolog \
           --script $script >& $out}
  if {$had} { set ::env(HOME) $old } else { catch {unset ::env(HOME)} }
  set txt {}
  if {[file exists $out]} { set fp [open $out r] ; set txt [read $fp] ; close $fp }
  set v NOCHILD
  regexp "${key}=(\[^\n\r\]*)" $txt -> v
  return [string map $::SCRUB [string trim $v]]
}

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

## --- S38: ONE PROGRAM, TWO ARGUMENT LISTS, TWO ANSWERS -------------------
## ISSUE 1371's ADVERSARY, AND IT NEEDS NO DISPLAY. The capability cache was
## keyed on the resolved path ALONE, while the probe has always run the program
## with the entry's own extra arguments (ruling A2 -- probe with the real
## argv). Before this item only the in-force route could write that cache, so
## two argument lists never met; the Case chooser and its Detect button are a
## second writer, and they ask about a location the user typed, with whatever
## arguments the entry happens to carry.
##
## MEASURED BEFORE THE REPAIR, on the stub below: an entry registered
## `-args -q`, in force, answering `fold` alone; ONE dialog-side measurement of
## the same file with no arguments; and `ase::sim_casemode_selectable ngspice`
## -- the accessor the RUN reads -- then answered `fold preserve distinguish`.
## `preserve` offered, and requested, for a program that folds.
##
## THE PEEK IS HALF THE ROW. `ase::sim_caps_have_path` is what lets the editor
## promise it starts nothing (row S27): a peek that answered "yes, in hand" for
## an argv nobody measured would send the editor into the accessor, and the
## accessor launches.
simreset
catch {ase::sim_caps_clear}
pcall ase::sim_register a38 $ARGSTUB -args {-q}
pcall ase::sim_select a38
set S38DLG   [pcall ase::sim_casemode_selectable_path ngspice $ARGSTUB {}]
## THE PEEK, BETWEEN THE TWO MEASUREMENTS: one argument list has been measured
## and the other has not, and the peek has to be able to tell them apart. Taken
## HERE, because after the in-force call below both are in hand and a peek that
## ignored the argv would pass.
set S38HAVE0 [pcall ase::sim_caps_have_path ngspice $ARGSTUB {}]
set S38HAVEQ [pcall ase::sim_caps_have_path ngspice $ARGSTUB {-q}]
set S38FORCE [pcall ase::sim_casemode_selectable ngspice]
## The other order, from cold, so neither answer can be the one that merely
## happened to be taken first.
catch {ase::sim_caps_clear}
set S38FORCE2 [pcall ase::sim_casemode_selectable ngspice]
set S38DLG2   [pcall ase::sim_casemode_selectable_path ngspice $ARGSTUB {}]
simreset
catch {ase::sim_caps_clear}
check {S38 what was measured is remembered about a program AND the words it was started with, so a question asked from the row editor cannot answer for the run} \
  [list $S38DLG $S38FORCE $S38FORCE2 $S38DLG2 $S38HAVE0 $S38HAVEQ] \
  [list [list fold preserve distinguish] [list fold] \
        [list fold] [list fold preserve distinguish] 1 0]

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

  ## --- S10b: THE CHOICE DOES NOT GO IN THE FILE (issue 1395) -----------
  ## THIS ROW USED TO ASSERT THE OPPOSITE, and the old contract is written
  ## here rather than deleted, because it was a real guarantee and it moved
  ## rather than went away. It read: *choosing "use the program on my PATH" in
  ## the dialog is written down too, so the next start does not quietly put one
  ## of yours back in charge*, and its second term was that the saved list now
  ## contains `ase::sim_select {}`.
  ##
  ## THE USER RULED THAT WRONG, verbatim 2026-09-08: *whether* a registered
  ## simulator "gets assigned as 'the one to use' is an option that is part of
  ## the ASE-L state. If changed, that results in dirtiness. User must
  ## explicitly save and, if user initiates an Xschem shutdown, then she must
  ## get a warning and a prompt to save." A pick that wrote itself to
  ## ~/.xschem/ase_simulators reached disk with no save gesture behind it, from
  ## a window the user might be about to abandon, and overwrote the
  ## installation default with one bench's opinion.
  ##
  ## 0932's ACTUAL GUARANTEE -- a deliberately cleared choice is not silently
  ## undone at the next start -- did not go away with it. It lives where the
  ## default lives now, and is measured by row R8 of
  ## tests/headless/test_ase_simreg_0931.tcl against a saved file whose own
  ## selection line is empty. What THIS row measures is the new half: the
  ## gesture changes the SESSION and leaves the file exactly as it was.
  ##
  ## A CLEAN BENCH FIRST. Rows S3 and S4 above have already made a pick in this
  ## session, so without this the "not dirty before" term would be measuring
  ## nothing at all -- and the pick that follows must be a real CHANGE, or an
  ## unchanged state would answer "not dirty" for the wrong reason.
  set S10CLEAN [pcall ase::session_update $key \
                  [pcall ase::sim_choice_set [pcall ase::session_state $key] entry mybuild5]]
  pcall ase::session_save $key
  set S10DIRTY0 [pcall ase::session_dirty $key]
  set S10WAS {}
  set S10MT0 ZZNOFILE
  if {$CONFFILE ne {NOPROC} && $CONFFILE ne {} && [file exists $CONFFILE]} {
    set S10WAS [slurp $CONFFILE]
    set S10MT0 [file mtime $CONFFILE]
  }
  set S10VAR [wcget $top.simdlg.use -textvariable]
  if {$S10VAR ne {NOWIDGET} && $S10VAR ne {NOOPT} && $S10VAR ne {}} {
    catch {set ::$S10VAR [mint ase::ui::simdlg_none_label]}
    catch {event generate $top.simdlg.use <<ComboboxSelected>>}
    update
  }
  set S10TXT2 {}
  set S10MT1 ZZNOFILE
  if {$CONFFILE ne {NOPROC} && $CONFFILE ne {} && [file exists $CONFFILE]} {
    set S10TXT2 [slurp $CONFFILE]
    set S10MT1 [file mtime $CONFFILE]
  }
  ## THE FILE'S OWN SELECTION LINE IS THE SHARP TERM. It names the installation
  ## DEFAULT, which is still mybuild5 -- the first entry registered after this
  ## file's last simreset -- while the session is now running the PATH program.
  ## Byte-comparing the whole file catches a write that happened to land in the
  ## same second, which an mtime alone would not.
  check {S10b choosing "use the program on my PATH" in the dialog changes THIS BENCH and nothing else -- the saved list is not touched, byte for byte, and the session is now unsaved work the user has to decide about} \
    [list $S10CLEAN $S10DIRTY0 \
          [pcall ase::sim_selected] \
          [pcall ase::session_dirty $key] \
          [expr {$S10WAS ne {} && $S10TXT2 eq $S10WAS}] \
          [expr {$S10MT0 ne {ZZNOFILE} && $S10MT1 eq $S10MT0}] \
          [expr {[string first "ase::sim_select \{\}" $S10TXT2] >= 0}] \
          [expr {[string first {ase::sim_select mybuild5} $S10TXT2] >= 0}]] \
    [list 1 0 {} 1 1 1 0 1]

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


  # --- S19: ISSUE 0941, AT THE PIXELS -----------------------------------
  # Taking away a simulator that a startup configuration file put there,
  # while it is the one in use, has TWO true things to say: which simulator
  # takes over, and that this one will be back next time. Both reach the CIW.
  # Measured at d733209e: the dialog's own line showed only the second, so
  # the user was never told, anywhere they were looking, that the program
  # which will actually run had just changed.
  #
  # Both sentences are quoted from the mint, never from a literal here, so
  # this row cannot drift from the wording in ase.tcl. S8a and S8b above are
  # the control: one sentence still renders as exactly one sentence.
  simreset
  set ::ase::sim_origin rc
  pcall ase::sim_register rc19 $STUB
  set ::ase::sim_origin session
  pcall ase::sim_register mine19 $STUB2
  pcall ase::sim_select rc19
  catch {destroy $top.simdlg}
  winv $top.mb.setup $SIMLBL
  update
  catch {$top.simdlg.tv selection set 0}
  update
  winv $top.simdlg.btns.remove
  update
  set S19TXT [wtext $top.simdlg.status]
  set S19O [mint ase::sim_why removed_now_other rc19 {} mine19]
  set S19R [mint ase::sim_why rc_removed rc19 {}]
  set S19IO [string first $S19O $S19TXT]
  set S19IR [string first $S19R $S19TXT]
  check {S19 removing a simulator a startup file put there, while it is the one in use, tells you BOTH true things on the dialog's own line -- which simulator takes over, said first, and that this one comes back the next time xschem starts} \
    [list [simnames] [pcall ase::sim_selected] \
          [expr {$S19IO >= 0}] [expr {$S19IR >= 0}] \
          [expr {$S19IO >= 0 && $S19IR > $S19IO}]] \
    [list [list mine19] mine19 1 1 1]

  # --- S9: EDIT DOES NOT THROW AWAY ANY FIELD OF THE ENTRY ---------------
  # Extra arguments and the backend an entry was registered for are invisible
  # in this dialog -- and an editor that rebuilt the entry from its visible
  # fields alone would silently delete them.
  #
  # ⚠ AND THE CASE MODE AND `-n` ARE THE HALF THIS ROW USED TO MISS (issue
  # 1371). It asserted `args` and `backend` only, so it was GREEN on a tree
  # where opening Edit… on an entry carrying `casemode preserve` and pressing
  # OK without typing anything ERASED that mode and saved the erasure --
  # measured through these very widgets. Those two fields are now shown by the
  # editor, so the row asserts a round trip through the form rather than a
  # carry-through; either way the fix is the same, and the hole was that
  # nothing here looked at them at all.
  simreset
  pcall ase::sim_register one9   $STUB
  pcall ase::sim_register two9   $STUB2 -args {-q -x} -backend ngspice \
    -casemode preserve -nospiceinit 1
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
  check {S9 changing an entry's program leaves every other field of it exactly as it was -- the extra arguments, the backend, the case mode and the -n flag -- and the entry keeps its place in the list} \
    [list $S9OPEN $S9NAME [expr {$S9RO ne {normal} && $S9RO ne {NOWIDGET} && $S9RO ne {NOOPT}}] \
          [simnames] [simfield two9 path] [simfield two9 args] [simfield two9 backend] \
          [simfield two9 casemode] [simfield two9 nospiceinit]] \
    [list 1 two9 1 [list one9 two9 three9] $STUB3 [list -q -x] ngspice preserve 1]

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

  # --- S20-S23: ISSUE 1370, THE BAR NAMES WHAT WILL RUN -----------------
  # THE USER'S WORDS: "In the ASE-L, in status bar, Simulator: <name> should
  # show the correct name. If user has designated (registered) a new instance
  # of ngspice named ngspice-ver50, and the 'use this one:' field shows that,
  # then the status bar in ASE-L should show that."
  #
  # MEASURED BEFORE THE FIX on a live .ase4 window: the bar read
  # `Simulator: ngspice` with `ngspice-ver50` in force, with the choice
  # cleared, and with it re-selected -- three registry states, one
  # byte-identical bar. And there was no refresh either: not one of the five
  # dialog gestures touched the bar, so even a correct label would have gone
  # stale the moment the user changed "Use this one:" and stayed stale until
  # the run they were trying to predict actually started.
  #
  # tests/headless/test_ase_simreg_0931.tcl section L owns what the label is
  # told to say in every registry state, without a display. THESE rows own the
  # half only pixels can answer: that the real bottom bar carries it, that it
  # follows a real gesture with NO session update behind it, and that a second
  # open session follows a gesture made in the first -- the registry is
  # process-global, the dialog is per-session.
  #
  # ⚠ THE MARKER'S WORDING IS THE USER'S RULING (issue 1370, on their queue).
  # It is lifted off one known-broken arm here and never retyped, so the rows
  # fence the behaviour and a re-wording costs nothing.

  ## The Simulator segment of the real bottom bar, off the widget, through the
  ## same reader tests and scripting use. NOSEG rather than {}: an absent
  ## segment must never satisfy a row that expects a name.
  proc barsim {k} {
    if {![llength [info commands ase::ui::status_text]]} { return NOPROC }
    set t [ase::ui::status_text $k]
    if {$t eq {}} { return NOWIDGET }
    foreach seg [split $t |] {
      set seg [string trim $seg]
      if {[string first {Simulator:} $seg] == 0} {
        return [string trim [string range $seg [string length {Simulator:}] end]]
      }
    }
    return NOSEG
  }
  ## Pick one from the dialog's own "Use this one:" combobox, the way a user
  ## does -- the variable the combobox is bound to, then the proc its
  ## <<ComboboxSelected>> binding calls. NOT ase::sim_select: the whole point
  ## of these rows is that the GESTURE is what updates the bar.
  proc dlg_use {k v} {
    if {![llength [info commands ase::ui::simdlg_use]]} { return NOPROC }
    set ::ase::ui::simuse($k) $v
    ase::ui::simdlg_use $k
    catch {update}
    return OK
  }

  ## THE MARKER, LIFTED OFF ONE KNOWN-BROKEN ARM AND NEVER RETYPED.
  set S20MARK ZZ-NO-MARKER
  simreset
  pcall ase::sim_register ngmark20 $MISSING
  set S20L [pcall ase::sim_label ngspice]
  if {[string first ngmark20 $S20L] == 0} {
    set S20MARK [string range $S20L [string length ngmark20] end]
  }

  ## THREE ENTRIES AND A CHOICE ALREADY IN FORCE BEFORE EITHER WINDOW OPENS,
  ## so every "before" reading below comes from that window's OWN open-time
  ## refresh and not from the process-wide one these rows are about. Two
  ## healthy ones, so nothing here depends on what this machine has on its
  ## PATH.
  simreset
  pcall ase::sim_register alpha20 $STUB
  pcall ase::sim_register beta20  $STUB2
  pcall ase::sim_register gone20  $MISSING
  pcall ase::sim_select   alpha20

  check {S20a the session window opens again for the status-bar rows} \
    [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top20 [ase::ui::window_for $key]
  catch {destroy $top20.simdlg}
  winv $top20.mb.setup $SIMLBL
  update

  # --- S20: THE HEADLINE, AT THE PIXELS ---------------------------------
  set S20BAR [barsim $key]
  check {S20 THE HEADLINE the bottom bar names the simulator the user registered and picked, not the kind of simulator it is} \
    [list $S20BAR \
          [expr {$S20BAR eq {ngspice} ? {STILL-THE-BACKEND-WORD} : {named}}] \
          [pcall ase::sim_selected] \
          [string match {*| Simulator: alpha20 |*} [ase::ui::status_text $key]]] \
    [list alpha20 named alpha20 1]

  # A SECOND SESSION, on its own state view, opened while alpha20 is in force
  # so its own bar starts from the same place window one's did.
  set S22OK 1
  if {[catch {
    library_new_view aselib nfet_clean ngspice_state2 ngspice_state2
    set spath2 [xschem cellview_path aselib/nfet_clean ngspice_state2]
    if {$spath2 eq {}} { error "state2 view did not resolve" }
    set key2 [ase::session_key aselib nfet_clean ngspice_state2]
    ase::session_open $key2 [file normalize $spath2]
    set st2 [ase::session_state $key2]
    dict set st2 rundir $rundir
    ase::session_update $key2 $st2
    ase::session_save $key2
    ase::session_close $key2
  } e22]} { set S22OK 0 ; puts "S22 FIXTURE ERROR: $e22" }
  check {S22a a second simulation state view and its own session window are up, and they are a different session} \
    [list $S22OK [ase::open_state aselib nfet_clean ngspice_state2] \
          [expr {$key ne $key2 ? 1 : 0}]] {1 1 1}
  update
  set top22 [ase::ui::window_for $key2]

  # --- S21: IT FOLLOWS THE GESTURE ---------------------------------------
  # The bar is refreshed by ase::session_notify. Before issue 1370 nothing on
  # the dialog's own path refreshed it, so it kept the name the window opened
  # with until the run started -- exactly the moment the user was trying to
  # predict.
  #
  # ⚠ THE TWO DIRTY TERMS HAVE REVERSED, AND THE REVERSAL IS THE POINT. They
  # used to read `0 0` and their comment read *the witness that no session
  # update happened on either side of the gesture* -- because the registry is
  # not session state and the choice used to live in the registry. Issue 1395
  # moved the CHOICE into the state on the user's ruling, so a pick made here
  # is now unsaved work: `0` before, `1` after. The bar still has to follow the
  # gesture, which is what the first three terms are; what changed is that the
  # session now knows it was changed. Rows S40-S45 below are that half's own
  # measurements.
  #
  # THE `0` BEFORE IS NOT FREE. S20a re-opened this session from its file, so
  # the picks rows S3/S4/S10b made are gone; if that ever stopped being true
  # this term reds rather than the row passing vacuously.
  set S21WAS [barsim $key]
  set S21D [ase::session_dirty $key]
  dlg_use $key beta20
  set S21B [barsim $key]
  dlg_use $key alpha20
  set S21A [barsim $key]
  check {S21 changing "Use this one:" changes the bottom bar there and then -- the user does not have to start a run to find out which simulator a run would start -- and the bench is now unsaved work} \
    [list $S21WAS $S21B $S21A $S21D [ase::session_dirty $key]] \
    [list alpha20 beta20 alpha20 0 1]

  # --- S22: EVERY OPEN SESSION FOLLOWS IT -------------------------------
  # The registry is process-global; the dialog is per-session (0937's own
  # known-issues note). A second window still showing the old name would be
  # telling the user something untrue about what ITS run would start.
  set S22W1 [barsim $key]
  set S22W2 [barsim $key2]
  dlg_use $key beta20
  set S22A1 [barsim $key]
  set S22A2 [barsim $key2]
  check {S22 a simulator picked in one session window is what EVERY open session window's bar says, because the choice is one choice for the whole program} \
    [list $S22W1 $S22W2 $S22A1 $S22A2] \
    [list alpha20 alpha20 beta20 beta20]

  # --- S23: A NAME THE BAR SHOWS IS NEVER A PROMISE ---------------------
  # The user's own rule: "It must never silently print a name for a simulator
  # that is not going to run - a false name is worse than the backend word."
  # The name stays -- it is what they need in order to go and fix the entry --
  # and it is marked. The structural half keeps the marker out of this file:
  # ruling D5-4, and row R9 of the registry suite.
  dlg_use $key gone20
  set S23BAR [barsim $key]
  check {S23 a simulator whose program has gone is still named on the bar and is marked as one that will not run, and that marking is not a second piece of wording living in the window file} \
    [list $S23BAR \
          [expr {[string first gone20 $S23BAR] == 0}] \
          [expr {$S23BAR ne {gone20}}] \
          [expr {$S20MARK ne {ZZ-NO-MARKER}}] \
          [scount $SRCW $S20MARK]] \
    [list "gone20$S20MARK" 1 1 1 0]

  dlg_use $key alpha20
  catch {destroy $top20.simdlg}
  update

  # --- S32: THE REGISTRY'S OTHER DOOR (1370's repair) -------------------
  # 1370 hung the bar's refresh off ase::ui::simdlg_fill, which every gesture
  # of THIS DIALOG funnels through -- and nothing else. The registry has a
  # second door: `ase::sim_register <name> <path>` then `ase::sim_select
  # <name>` typed into the Command window. That is the pre-0937 path, it is
  # still supported, and it is how this user's own ngspice-ver50 entry was
  # first created. Measured live by this item's adversary, with a window open
  # on `Simulator: ngspice-ver50`: that pair left the bar naming the OLD entry
  # while ase::sim_label already answered the new one -- a name on the bar for
  # a simulator that would NOT run, healed only by the run it was supposed to
  # predict.
  #
  # THE DIALOG IS DESTROYED FIRST, and the first term is the witness: nothing
  # dialog-side can be doing this work. Both windows are still open, because
  # the registry is process-global and one CIW gesture changes what BOTH would
  # start.
  #
  # THE MIDDLE PAIR IS THE CONTROL. Registering alone must NOT move the bar --
  # a later registration never steals the choice (ase::sim_register's own
  # rule) -- so a refresh that fired and rendered something arbitrary reds
  # here rather than passing on the last term alone.
  set S32DLG [expr {[winfo exists $top20.simdlg] ? 1 : 0}]
  set S32W1 [barsim $key]
  set S32W2 [barsim $key2]
  pcall ase::sim_register ciw32 $STUB2
  update
  set S32R1 [barsim $key]
  set S32R2 [barsim $key2]
  pcall ase::sim_select ciw32
  update
  set S32A1 [barsim $key]
  set S32A2 [barsim $key2]
  ## AND THE REMOVAL, the other Command-window gesture. Taking out the entry in
  ## force with more than one left picks nothing at all, so the bar must stop
  ## naming it. What it says INSTEAD depends on what this machine has on its
  ## PATH, so the term is that the gone name is gone -- not a literal.
  pcall ase::sim_unregister ciw32
  update
  set S32X1 [barsim $key]
  set S32X2 [barsim $key2]
  check {S32 a simulator registered and picked from the Command window -- the\
 registry's other door, with the Simulators dialog shut -- changes every open\
 window's bar there and then, and removing it stops every bar naming it} \
    [list $S32DLG $S32W1 $S32W2 $S32R1 $S32R2 $S32A1 $S32A2 \
          [expr {[string first ciw32 $S32X1] < 0 ? 1 : 0}] \
          [expr {[string first ciw32 $S32X2] < 0 ? 1 : 0}] \
          [pcall ase::sim_selected]] \
    [list 0 alpha20 alpha20 alpha20 alpha20 ciw32 ciw32 1 1 {}]

  pcall ase::sim_select alpha20
  ase::ui::close $key2
  update

  # =====================================================================
  # S24-S31: ISSUE 1371, THE MEASURED CASE MODE FINALLY HAS A DOOR
  # =====================================================================
  # THE USER'S WORDS: "If the run *is* using ver_50, then why is case-mode
  # support not showing up? What needs to be done for that? I plot the VBG
  # net from top level of sky130_tests_ase/tb_bandgap and it plots v(vbg)
  # not v(VBG). What's going on? I thought we nailed this weeks ago."
  #
  # MEASURED ON THEIR OWN BENCH BEFORE THE FIX: their build really is in
  # force, and it really was measured -- `casemode_detected` and
  # `casemode_selectable` both answered `fold preserve distinguish`. Their
  # registry entry carried `casemode {}`, so the request fell to the global
  # floor `fold`, and a `fold` request deliberately emits no `-D casemode=`
  # at all. The one broken link was that NOTHING COULD ASK: this row editor
  # built two rows, Name and Program, so `preserve` could only be reached by
  # hand-editing the saved list -- and pressing Edit… on an entry that had
  # been hand-edited ERASED it again (row S9).
  #
  # RULE A1 is what these rows are really about: never offer a mode the
  # binary was not measured to deliver. So every row below compares what the
  # chooser OFFERS against what the MEASUREMENT says, per entry -- never
  # against a literal list written here, which would drift.
  #
  # THE STUBS REALLY ANSWER THE PROBE. See the CMSTUB / NOCM note in the
  # fixture block: this section measures three programs that answer three
  # different ways, and a `#!/bin/sh exit 0` that answers nothing.
  set GD [mint ase::ui::simdlg_case_label {}]

  proc open_editor {top key row} {
    catch {destroy $top.simrow}
    catch {destroy $top.simdlg}
    winv $top.mb.setup "Simulators…"
    update
    catch {$top.simdlg.tv selection set $row}
    update
    winv $top.simdlg.btns.edit
    update
    return [wex $top.simrow]
  }

  # --- S24: THE HEADLINE ------------------------------------------------
  simreset
  pcall ase::sim_register cm24 $CMSTUB
  set S24MEAS [pcall ase::sim_casemode_selectable_for cm24]
  set S24OPEN [open_editor $top20 $key 0]
  set S24VALS [wvalues $top20.simrow.casemode]
  check {S24 THE HEADLINE the row editor has a Case chooser, and what it offers is exactly what THAT program was measured to deliver, plus the "leave it to the global default" line} \
    [list $S24OPEN [wex $top20.simrow.casemode] \
          [wcget $top20.simrow.casemode -state] \
          $S24MEAS $S24VALS \
          [wtext $top20.simrow.lcasemode]] \
    [list 1 1 readonly [list fold preserve distinguish] \
          [linsert $S24MEAS 0 $GD] {Case:}]

  # --- S25: A1, AGAINST A SECOND PROGRAM THAT ANSWERS DIFFERENTLY -------
  ## Two programs, two measurements, one dialog. NOCM answers the way a build
  ## with no casemode feature at all answers, which the probe records as
  ## `fold` and nothing else -- so if the chooser were offering a fixed list,
  ## or the in-force program's list, this row is where it shows.
  simreset
  pcall ase::sim_register cm25   $CMSTUB
  pcall ase::sim_register nocm25 $NOCM
  set S25A [pcall ase::sim_casemode_selectable_for cm25]
  set S25B [pcall ase::sim_casemode_selectable_for nocm25]
  open_editor $top20 $key 0
  set S25VA [wvalues $top20.simrow.casemode]
  open_editor $top20 $key 1
  set S25VB [wvalues $top20.simrow.casemode]
  check {S25 A1 the chooser never offers a mode the program was not measured to deliver -- a build that measures as folding only is offered folding only} \
    [list $S25A $S25B $S25VA $S25VB \
          [expr {[lsearch -exact $S25VB preserve] < 0}]] \
    [list [list fold preserve distinguish] [list fold] \
          [linsert $S25A 0 $GD] [linsert $S25B 0 $GD] 1]

  # --- S26: THE ROW BEING EDITED, NOT THE ROW IN FORCE ------------------
  ## MEASURED BEFORE THE FIX: `ase::sim_casemode_selectable ngspice` -- the
  ## accessor a door would reach for first -- answered `fold preserve
  ## distinguish` or `fold` depending ONLY on which entry was selected, so a
  ## chooser built from it offers one program's modes while the user is
  ## editing another's. That is an A1 breach introduced by the very door
  ## meant to enforce A1, and no row above can see it: they all edit the
  ## entry that happens to be in force.
  pcall ase::sim_select nocm25
  set S26INFORCE [pcall ase::sim_casemode_selectable ngspice]
  open_editor $top20 $key 0
  set S26EDITED [wvalues $top20.simrow.casemode]
  pcall ase::sim_select cm25
  set S26INFORCE2 [pcall ase::sim_casemode_selectable ngspice]
  open_editor $top20 $key 1
  set S26EDITED2 [wvalues $top20.simrow.casemode]
  check {S26 the chooser describes the row the user clicked, not whichever simulator happens to be in force} \
    [list $S26INFORCE $S26EDITED $S26INFORCE2 $S26EDITED2] \
    [list [list fold] [linsert $S25A 0 $GD] \
          [list fold preserve distinguish] [linsert $S25B 0 $GD]]

  # --- S27: NOTHING MEASURED MEANS FOLD ALONE, AND NOTHING IS STARTED ---
  ## `fold` is what a released ngspice does whether or not it was asked, so
  ## it is the one request no binary can silently fail -- the only honest
  ## offer for a program nobody has measured. The last term is the one that
  ## matters most: opening a row editor must not be a gesture that starts the
  ## user's simulator. On a licensed tool that would check out a licence.
  simreset
  pcall ase::sim_register never27 $STUB
  pcall ase::sim_register gone27  $MISSING
  set S27HAVE [pcall ase::sim_caps_have never27]
  set S27OPEN [open_editor $top20 $key 0]
  set S27A [wvalues $top20.simrow.casemode]
  set S27HAVE2 [pcall ase::sim_caps_have never27]
  open_editor $top20 $key 1
  set S27B [wvalues $top20.simrow.casemode]
  check {S27 a program nobody has measured, and one whose file has gone, are each offered folding alone -- and merely opening the editor never starts anything} \
    [list $S27OPEN $S27A $S27B $S27HAVE $S27HAVE2] \
    [list 1 [list $GD fold] [list $GD fold] 0 0]

  # --- S28: DETECT IS THE ONLY THING THAT MAY START A PROGRAM -----------
  ## The other half of S27's rule. The chooser offers fold alone until the
  ## user asks, and Detect is the asking: it says what it is doing first --
  ## the sentence has to be painted BEFORE the launch, because the launch
  ## freezes Tk and a sentence arriving afterwards can only ever read as a
  ## report about something already finished -- and then rebuilds the offer
  ## from what came back. Every sentence is ase::sim_why's; this file mints
  ## nothing (ruling D5-4).
  simreset
  pcall ase::sim_register det28 $CMSTUB
  set S28OPEN [open_editor $top20 $key 0]
  set S28BEFORE [wvalues $top20.simrow.casemode]
  winv $top20.simrow.detect
  update
  set S28AFTER [wvalues $top20.simrow.casemode]
  set S28SAID [wtext $top20.simrow.status]
  set S28MINT [mint ase::sim_why casemode_measured {} $CMSTUB \
                 [list fold preserve distinguish]]
  set S28UNMEAS [mint ase::sim_why casemode_unmeasured {} $CMSTUB]
  check {S28 Detect measures the program in the Program field, rebuilds the offer from the answer, and reports it in the words the rest of xschem uses} \
    [list $S28OPEN $S28BEFORE $S28AFTER \
          [expr {$S28MINT ne {NOMINT} && $S28SAID eq $S28MINT}] \
          [expr {$S28UNMEAS ne {NOMINT} && $S28SAID ne $S28UNMEAS}] \
          [scount $SRCW [string range $S28MINT 0 20]]] \
    [list 1 [list $GD fold] [list $GD fold preserve distinguish] 1 1 0]

  # --- S29: PICK IT, PRESS OK, AND THE RUN REALLY ASKS FOR IT -----------
  ## THE WHOLE ITEM, END TO END, IN ONE ROW. The user picks `preserve` the
  ## way a user can -- only from what the chooser is OFFERING, which is what
  ## `wpick` enforces -- presses OK, and every consumer downstream has to
  ## agree: the entry, the request the run reads off it, the flag the command
  ## builder emits, the saved file, and a REAL FRESH PROCESS reading that
  ## file back. Without the last one this row cannot say "and it is still
  ## there tomorrow", which is the user's actual complaint.
  simreset
  pcall ase::sim_register run29 $CMSTUB
  pcall ase::sim_select run29
  pcall ase::sim_capabilities_for run29
  set S29OPEN [open_editor $top20 $key 0]
  set S29PICK [wpick $top20.simrow.casemode preserve]
  set S29NPICK [wcheck $top20.simrow.nospiceinit 1]
  winv $top20.simrow.btns.proceed
  update
  set S29FIELD [simfield run29 casemode]
  set S29NS [simfield run29 nospiceinit]
  set S29REQ [pcall ase::sim_casemode_requested ngspice]
  set S29FLAG [pcall ase::run_casemode_flag [ase::session_state $key]]
  set S29TXT {}
  if {$CONFFILE ne {NOPROC} && $CONFFILE ne {} && [file exists $CONFFILE]} {
    set S29TXT [slurp $CONFFILE]
  }
  ## The restart, for real. The saved list is copied into a HOME of this
  ## suite's own and a fresh --nogui xschem is asked what it reads there.
  set RHOME [file join $scratch rhome]
  file mkdir [file join $RHOME .xschem]
  catch {file copy -force $CONFFILE [file join $RHOME .xschem ase_simulators]}
  set S29CHILD [child_val s29 {
    set m NOENTRY
    if {[llength [info commands ase::sim_entry]]} {
      set e [ase::sim_entry run29]
      if {$e ne {}} { set m [ase::state_get $e casemode ZZNONE] }
    }
    puts "CM29=$m"
    flush stdout
    exit 0
  } $RHOME CM29]
  check {S29 picking preserve and pressing OK is the whole chain -- the entry keeps it, the run asks for it, the command carries it, the file records it, and a fresh xschem reads it back} \
    [list $S29OPEN $S29PICK $S29NPICK $S29FIELD $S29NS $S29REQ $S29FLAG \
          [expr {[string first {-casemode preserve} $S29TXT] >= 0}] \
          $S29CHILD] \
    [list 1 OK OK preserve 1 preserve [list -D casemode=preserve -D casemodewrite] 1 preserve]
  ## ⚠ MOVED BY ISSUE 1470 (debt M21): the run's flag now carries
  ## `-D casemodewrite` beside the mode, as the classic path's `sim_run_flags`
  ## always has, so the rawfile the run writes says which mode wrote it.

  # --- S30: A MODE THE USER WROTE BY HAND IS SHOWN, NOT SILENTLY DROPPED -
  ## Until this item landed, hand-editing the saved list was the ONLY way to
  ## ask for a case mode, so an entry carrying a mode its program was never
  ## measured to deliver is the normal legacy shape, not a corner case.
  ## Opening the editor on one must not quietly rewrite it: the mode is shown,
  ## MARKED, and pressing OK without touching anything leaves it alone.
  ##
  ## THE MARK IS `not tried yet` AND NOT `NOT supported`, and after issue
  ## 1371's repair those are two different words for two different states (see
  ## ase::ui::simdlg_case_label). This row is the first: nobody has measured
  ## $STUB, so nothing is known about `distinguish` either way. Row S34 is the
  ## second, where the program WAS measured and does not deliver it.
  simreset
  pcall ase::sim_register hand30 $STUB -casemode distinguish
  set S30OPEN [open_editor $top20 $key 0]
  set S30VALS [wvalues $top20.simrow.casemode]
  set S30SHOWN [wget $top20.simrow.casemode]
  set S30MARK [mint ase::ui::simdlg_case_label distinguish untried]
  winv $top20.simrow.btns.proceed
  update
  check {S30 a case mode the user wrote by hand, for a program that was never measured, is shown marked rather than dropped -- and pressing OK leaves it exactly as it was} \
    [list $S30OPEN $S30VALS $S30SHOWN \
          [expr {$S30MARK ne {NOMINT} && $S30SHOWN eq $S30MARK}] \
          [simfield hand30 casemode] \
          [mint ase::ui::simdlg_case_value $S30MARK]] \
    [list 1 [list $GD fold $S30MARK] $S30MARK 1 distinguish distinguish]

  # --- S31 STRUCTURAL: ONE PLACE ASKS, SO A1 CANNOT BE COPIED -----------
  ## The A1 rule lives in the model (ase::sim_casemode_selectable* and the
  ## caps-dict rule behind them) and this window file may hold exactly one
  ## caller of it, inside the proc that builds the chooser's values. A second
  ## caller elsewhere in the dialog is how a door built to enforce A1 ends up
  ## carrying a second, drifting copy of it -- which is the shape that killed
  ## `fluid-editing`'s eleven sim_profile_* procs.
  ##
  ## Non-vacuous by construction: it counts the proc it scanned, so "no second
  ## caller" cannot be satisfied by "no proc".
  set S31B [procbodies $SRCW ase::ui::simdlg_case_values]
  set S31ALL [lindex [procbodies $SRCW ase::ui::] 1]
  check {S31 STRUCTURAL exactly one place in the window file asks what a program may be offered, so the rule cannot be copied behind the dialog} \
    [list [lindex $S31B 0] \
          [expr {[scount [lindex $S31B 1] {casemode_selectable}] == 1}] \
          [scount $S31ALL {casemode_selectable}] \
          [scount $S31ALL {casemode_detected}]] \
    [list 1 1 1 0]

  # =====================================================================
  # S33-S37: ISSUE 1371's OWN REFUTATION, ROW BY ROW
  # =====================================================================
  # Everything above was green while five things were wrong, and every one of
  # them was reached by an ordinary gesture. The rows below are the fences the
  # first pass did not have; each one names the measurement that produced it.

  # --- S33: THE OFFER FOLLOWS THE PROGRAM FIELD -------------------------
  ## THE CLAIM THAT WAS FALSE. This item's own write-up said the chooser is
  ## "keyed on the PROGRAM NAMED IN THE PROGRAM FIELD, not on the entry ...
  ## because a user who has just typed a NEW location into the Program field
  ## would otherwise be offered the OLD program's modes". It WAS keyed on the
  ## field -- and built only at editor-open and by Detect, with nothing bound
  ## to the field at all. Measured through the real widgets: an entry measuring
  ## `fold preserve distinguish`, the location of a build measuring `fold`
  ## alone typed in, and the chooser still offering `preserve`; OK saved it,
  ## `ase::sim_casemode_requested` answered `preserve`, and
  ## `ase::run_casemode_flag` emitted `-D casemode=preserve` for a program
  ## measured not to deliver it. And the adversary's proof that no row could
  ## see it: re-keying BOTH readers on the entry's stored path -- the shape the
  ## write-up says it had to correct -- left the suite at ALL PASS.
  ##
  ## THE THIRD TERM IS WHAT MAKES IT ABOUT THE FIELD. The program now named
  ## there really is measured, and really delivers `fold` alone, so the offer
  ## collapsing to `fold` cannot be an accident of "nothing is measured".
  ##
  ## WHAT OK THEN SAVES IS THE RECORDED, UNRATIFIED CHOICE (issue 1371's rule
  ## debt): a mode the user can SEE is marked `(NOT supported)` is still
  ## written down, exactly as row S30's hand-written one is. The alternative --
  ## refusing at OK -- would have the dialog tighten a rule the registry itself
  ## does not have, mid-gesture.
  simreset
  catch {ase::sim_caps_clear}
  pcall ase::sim_register cm33 $CMSTUB
  set S33MEAS [pcall ase::sim_casemode_selectable_for cm33]
  set S33FIELDCAN [pcall ase::sim_casemode_selectable_path ngspice $NOCM]
  set S33OPEN [open_editor $top20 $key 0]
  set S33V0 [wvalues $top20.simrow.casemode]
  set S33PICK [wpick $top20.simrow.casemode preserve]
  went $top20.simrow.path $NOCM
  update
  set S33V1 [wvalues $top20.simrow.casemode]
  set S33SHOWN [wget $top20.simrow.casemode]
  set S33MARK [mint ase::ui::simdlg_case_label preserve unsupported]
  set S33UNTRIED [mint ase::ui::simdlg_case_label preserve untried]
  winv $top20.simrow.btns.proceed
  update
  check {S33 typing another location into the Program field rebuilds what the Case chooser offers, from the program NOW named there -- and the pick that program cannot deliver is marked, not left looking measured} \
    [list $S33OPEN $S33V0 $S33PICK $S33FIELDCAN $S33V1 $S33SHOWN \
          [expr {$S33MARK ne {NOMINT} && $S33MARK ne $S33UNTRIED}] \
          [simfield cm33 path] [simfield cm33 casemode]] \
    [list 1 [linsert $S33MEAS 0 $GD] OK [list fold] \
          [list $GD fold $S33MARK] $S33MARK 1 $NOCM preserve]

  # --- S39: DETECT MEASURES WHAT IS IN THE FIELD, NOT WHAT WAS REGISTERED -
  ## Row S28 says "Detect measures the program in the Program field" and cannot
  ## see it: it opens the editor and presses Detect without touching the field,
  ## where the two are the same string. The adversary re-keyed simdlg_detect
  ## onto the entry's stored path and S28 stayed green. The symptom that leaves
  ## is "Detect does nothing": the user types a new location, presses the one
  ## button that may measure something, and the offer does not move -- because
  ## what got measured was the program they are replacing.
  ##
  ## THE LAST TERM IS THE ONE THAT CANNOT BE FAKED. The entry's own program is
  ## still unmeasured afterwards, so a Detect that answered correctly by
  ## measuring BOTH would redden here too.
  simreset
  catch {ase::sim_caps_clear}
  pcall ase::sim_register det39 $STUB
  set S39OPEN [open_editor $top20 $key 0]
  set S39V0 [wvalues $top20.simrow.casemode]
  went $top20.simrow.path $CMSTUB
  update
  set S39V1 [wvalues $top20.simrow.casemode]
  winv $top20.simrow.detect
  update
  set S39V2 [wvalues $top20.simrow.casemode]
  set S39SAID [wtext $top20.simrow.status]
  set S39MINT [mint ase::sim_why casemode_measured {} $CMSTUB \
                 [list fold preserve distinguish]]
  set S39HAVEFIELD [pcall ase::sim_caps_have_path ngspice $CMSTUB]
  set S39HAVEENTRY [pcall ase::sim_caps_have_path ngspice $STUB]
  catch {ase::sim_caps_clear}
  check {S39 Detect measures the program named in the Program field even when it is not the one the entry was registered with -- otherwise typing a new location and pressing Detect measures the program being replaced} \
    [list $S39OPEN $S39V0 $S39V1 $S39V2 \
          [expr {$S39MINT ne {NOMINT} && $S39SAID eq $S39MINT}] \
          $S39HAVEFIELD $S39HAVEENTRY] \
    [list 1 [list $GD fold] [list $GD fold] \
          [list $GD fold preserve distinguish] 1 1 0]

  # --- S34: MEASURED-AND-CANNOT IS NOT THE SAME AS NOBODY-ASKED ---------
  ## The other half of the mark. Row S30 is a mode stored for a program NOBODY
  ## HAS MEASURED -- nothing is known about it either way, and the label says
  ## so. This row is a mode stored for a program that WAS measured and does not
  ## deliver it, which is a statement about the user's own program, and it used
  ## to wear the same words: `(NOT measured)`, 449 ms after the measurement.
  simreset
  catch {ase::sim_caps_clear}
  pcall ase::sim_register hand34 $NOCM -casemode distinguish
  set S34CAN [pcall ase::sim_casemode_selectable_for hand34]
  set S34OPEN [open_editor $top20 $key 0]
  set S34VALS [wvalues $top20.simrow.casemode]
  set S34SHOWN [wget $top20.simrow.casemode]
  set S34MARK [mint ase::ui::simdlg_case_label distinguish unsupported]
  set S34UNTRIED [mint ase::ui::simdlg_case_label distinguish untried]
  check {S34 a stored mode the program was MEASURED not to deliver is marked with different words from one nobody has measured, and still maps back to the mode itself} \
    [list $S34OPEN $S34CAN $S34VALS $S34SHOWN \
          [expr {$S34MARK ne {NOMINT} && $S34MARK ne $S34UNTRIED}] \
          [mint ase::ui::simdlg_case_value $S34MARK]] \
    [list 1 [list fold] [list $GD fold $S34MARK] $S34MARK 1 distinguish]

  # --- S35: DETECT NEVER SAYS "NOT TRIED YET" AFTER IT HAS TRIED --------
  ## FOUR STATES, ALL MEASURED THROUGH THE REAL BUTTON, all of which used to
  ## print "<path> has not been tried yet, so fold is all that can be offered;
  ## press Detect to try it." -- a false claim plus an instruction to press the
  ## button that had just been pressed:
  ##   (a) a program that exists, is executable and ANSWERED the probe but
  ##       published no casemode key -- which is every executable that is not
  ##       an ngspice;
  ##   (b) a program whose file has gone, while the SAME dialog's Problem
  ##       column two widgets away carried the correct sentence;
  ##   (c) Detect pressed with the Program field empty -- two clicks from the
  ##       menu -- which printed two sentences with no subject and a leading
  ##       space;
  ##   (d) a probe that COMPLETES and recognises nothing, which is the second
  ##       arm of the `casemode_measured` mint and the one shape no stub
  ##       program can produce, so the probe hook itself stands in. A1's own
  ##       two-empties rule then leaves the global-default line ALONE in the
  ##       offer: measured, and it delivers nothing this window can ask for.
  ## Every sentence is compared against the MINT (ruling D5-4) and against the
  ## "not tried yet" one, so a tree that reworded either cannot pass.
  set S35UNMEAS [mint ase::sim_why casemode_unmeasured {} $STUB]
  simreset
  catch {ase::sim_caps_clear}
  pcall ase::sim_register det35a $STUB
  open_editor $top20 $key 0
  winv $top20.simrow.detect
  update
  set S35A [wtext $top20.simrow.status]
  set S35AMINT [mint ase::sim_why casemode_nokey {} $STUB]

  simreset
  catch {ase::sim_caps_clear}
  pcall ase::sim_register det35b $MISSING
  open_editor $top20 $key 0
  winv $top20.simrow.detect
  update
  set S35B [wtext $top20.simrow.status]
  set S35BMINT [mint ase::sim_why casemode_noprogram {} $MISSING missing]
  set S35BCELL [wcell $top20.simdlg.tv 0 problem]

  simreset
  catch {ase::sim_caps_clear}
  catch {destroy $top20.simrow}
  catch {destroy $top20.simdlg}
  winv $top20.mb.setup "Simulators…"
  update
  winv $top20.simdlg.btns.add
  update
  set S35COPEN [wex $top20.simrow]
  set S35CPATH [wget $top20.simrow.path]
  winv $top20.simrow.detect
  update
  set S35C [wtext $top20.simrow.status]
  set S35CMINT [mint ase::sim_why casemode_nopath {} {}]
  ## THE FLASH IS STRUCTURAL AND SAYS SO. With the guard removed the FINAL
  ## sentence is unchanged -- ase::casemode_report answers an empty path the
  ## same way -- so what the guard actually buys is that "Trying  now, to find
  ## out which spellings of a net name it can hand back." is never painted and
  ## flushed about no program at all. No widget can see a label that is
  ## overwritten in the same event, so the ordering in the source is the
  ## measurement: the empty-field answer is given BEFORE anything about a
  ## launch is said.
  set S35CB [procbodies $SRCW ase::ui::simdlg_detect]
  set S35CBT [lindex $S35CB 1]
  set S35CI1 [string first {casemode_status} $S35CBT]
  set S35CI2 [string first {casemode_measuring} $S35CBT]
  set S35CGUARD [expr {$S35CI1 >= 0 && $S35CI2 > $S35CI1}]
  catch {destroy $top20.simrow}
  catch {destroy $top20.simdlg}

  simreset
  catch {ase::sim_caps_clear}
  set S35DINST [probe_stub_install {
    return [dict create known 1 usable 1 appendwrite 0 blanket_op_save 0 \
                       hier_op_names 0 casemode_detected {}]
  }]
  pcall ase::sim_register det35d $STUB2
  open_editor $top20 $key 0
  winv $top20.simrow.detect
  update
  set S35D [wtext $top20.simrow.status]
  set S35DVALS [wvalues $top20.simrow.casemode]
  set S35DMINT [mint ase::sim_why casemode_measured {} $STUB2 {}]
  set S35DREM [probe_stub_remove]
  catch {ase::sim_caps_clear}
  check {S35 after Detect has really tried a program the editor says what happened -- it answered but said nothing about spellings, its file is gone, no location was given, or it was tried and delivers none of them -- and never that it has not been tried} \
    [list [expr {$S35AMINT ne {NOMINT} && $S35A eq $S35AMINT}] \
          [expr {$S35BMINT ne {NOMINT} && $S35B eq $S35BMINT}] \
          [expr {$S35CMINT ne {NOMINT} && $S35C eq $S35CMINT}] \
          [expr {$S35DMINT ne {NOMINT} && $S35D eq $S35DMINT}] \
          [expr {$S35UNMEAS ne {NOMINT} && $S35A ne $S35UNMEAS \
                 && $S35B ne $S35UNMEAS && $S35C ne $S35UNMEAS \
                 && $S35D ne $S35UNMEAS}] \
          $S35COPEN $S35CPATH $S35CGUARD [lindex $S35CB 0] \
          $S35DINST $S35DREM $S35DVALS \
          [expr {$S35BCELL ne $S35B && [string first $MISSING $S35BCELL] >= 0}] \
          [scount $SRCW {has not been tried yet}]] \
    [list 1 1 1 1 1 1 {} 1 1 1 1 [list $GD] 1 0]

  # --- S36: WHAT THE EDITOR SAYS BEFORE ANYTHING IS TRIED ---------------
  ## THE THIRD REFUTATION, and it is the deliverable itself: this item's answer
  ## to the user said "Edit… -> a Case chooser listing exactly what that
  ## program was measured to deliver -> pick preserve -> OK", with no mention
  ## of Detect. Measured COLD on their own entry and binary, that gesture finds
  ## `{global default (fold)} fold` and no `preserve` -- correct, because
  ## nothing has been measured and A1 forbids the rest, and indistinguishable
  ## from the bug the item was filed about. The editor now says so, in the
  ## mint's words, and names the one button that changes it.
  ##
  ## AND THE SAME SENTENCE COMES BACK AFTER OK, WHICH IS NOT A DEFECT BUT IS
  ## WHAT THE USER SEES: ase::sim_register's look-again (issue 0950, row D10 of
  ## test_ase_simcaps_0948) forgets every measurement on every registry edit,
  ## deliberately, so the reopen after a save is a cold open again. Before this
  ## row the chooser said `preserve (NOT measured)` about a program measured
  ## 449 ms earlier and the status line said nothing at all.
  ##
  ## LAST TERM: opening the editor, twice, and reopening it after a save, still
  ## starts nothing. Row S27's promise survives the status line being painted.
  simreset
  catch {ase::sim_caps_clear}
  pcall ase::sim_register cold36 $CMSTUB
  set S36HAVE0 [pcall ase::sim_caps_have cold36]
  set S36OPEN [open_editor $top20 $key 0]
  set S36COLD [wtext $top20.simrow.status]
  set S36HAVE1 [pcall ase::sim_caps_have cold36]
  set S36UNMEAS [mint ase::sim_why casemode_unmeasured {} $CMSTUB]
  winv $top20.simrow.detect
  update
  set S36AFTER [wtext $top20.simrow.status]
  set S36MEAS [mint ase::sim_why casemode_measured {} $CMSTUB \
                 [list fold preserve distinguish]]
  ## Reopened with the measurement still in hand: the status is the measured
  ## sentence and NOTHING was started to say it.
  open_editor $top20 $key 0
  set S36WARM [wtext $top20.simrow.status]
  set S36PICK [wpick $top20.simrow.casemode preserve]
  winv $top20.simrow.btns.proceed
  update
  ## And after the save, which is where the user looks next.
  open_editor $top20 $key 0
  set S36SAVED [wtext $top20.simrow.status]
  set S36SVALS [wvalues $top20.simrow.casemode]
  set S36SMARK [mint ase::ui::simdlg_case_label preserve untried]
  check {S36 the row editor says what is known about the program it is showing, before anything is tried -- it names Detect when nothing has been measured, repeats the measurement when there is one, and starts nothing to do either} \
    [list $S36OPEN $S36HAVE0 $S36HAVE1 \
          [expr {$S36UNMEAS ne {NOMINT} && $S36COLD eq $S36UNMEAS}] \
          [expr {$S36MEAS ne {NOMINT} && $S36AFTER eq $S36MEAS}] \
          [expr {$S36WARM eq $S36MEAS}] $S36PICK \
          [expr {$S36SAVED eq $S36UNMEAS}] $S36SVALS \
          [simfield cold36 casemode]] \
    [list 1 0 0 1 1 1 OK 1 [list $GD fold $S36SMARK] preserve]

  # --- S37: THE SENTENCE IS ON SCREEN BEFORE THE LAUNCH, NOT AFTER ------
  ## Detect can block Tk for 31.2 seconds on a program that exists and never
  ## answers, so the source paints its sentence and flushes the display BEFORE
  ## it starts anything -- a sentence arriving afterwards could only ever read
  ## as a report about something already finished. NOTHING IN THE TREE
  ## ASSERTED IT: `casemode_measuring` appeared in no test file at all, and the
  ## adversary deleted both the sentence and the `update idletasks` with the
  ## suite at ALL PASS.
  ##
  ## MEASURED FROM INSIDE THE LAUNCH. The probe hook stands in for one gesture
  ## and reads the status label at the instant it is entered, which is the only
  ## place the ordering is a fact rather than a reading of the source. The
  ## structural half is the flush, which no widget can see: `update idletasks`
  ## has to sit between the sentence and the measurement.
  simreset
  catch {ase::sim_caps_clear}
  set ::ZZ_STATUSW $top20.simrow.status
  set ::ZZ_SEEN ZZNOTRUN
  set S37INST [probe_stub_install {
    set ::ZZ_SEEN ZZNOLABEL
    catch {set ::ZZ_SEEN [$::ZZ_STATUSW cget -text]}
    return [dict create known 1 usable 1 appendwrite 0 blanket_op_save 0 \
                       hier_op_names 0 casemode_detected {fold preserve}]
  }]
  pcall ase::sim_register say37 $STUB3
  open_editor $top20 $key 0
  winv $top20.simrow.detect
  update
  set S37SEEN $::ZZ_SEEN
  set S37REM [probe_stub_remove]
  set S37MINT [mint ase::sim_why casemode_measuring {} $STUB3]
  set S37B [procbodies $SRCW ase::ui::simdlg_detect]
  set S37TXT [lindex $S37B 1]
  set S37I1 [string first {casemode_measuring} $S37TXT]
  set S37I2 [string first {update idletasks} $S37TXT]
  set S37I3 [string first {sim_capabilities_path} $S37TXT]
  check {S37 Detect says it is starting the program BEFORE it starts it, and flushes the display first -- the launch freezes Tk and a sentence arriving afterwards would be a report about something already over} \
    [list $S37INST $S37REM \
          [expr {$S37MINT ne {NOMINT} && $S37SEEN eq $S37MINT}] \
          [lindex $S37B 0] \
          [expr {$S37I1 >= 0 && $S37I2 > $S37I1 && $S37I3 > $S37I2}] \
          [scount $SRCW {to find out which spellings}]] \
    [list 1 1 1 1 1 0]
  catch {ase::sim_caps_clear}

  # =====================================================================
  # S40-S45: ISSUE 1395 -- WHICH SIMULATOR TO USE IS THE BENCH'S OWN, AND
  #          IT IS UNSAVED WORK UNTIL THE USER SAYS OTHERWISE
  # =====================================================================
  # THE USER'S RULING, verbatim 2026-09-08: "Yes, registering a simulator (so
  # that future Xschems see the 'new' simulator instance) is something that can
  # make it to disk right away as soon as done. But, registering a simulator is
  # not part of the simulator state that accompanies a test-bench cell in the
  # library manager. *Whether* the 'new' simulator just registered gets assigned
  # as 'the one to use' is an option that is part of the ASE-L state. If
  # changed, that results in dirtiness. User must explicitly save and, if user
  # initiates an Xschem shutdown, then she must get a warning and a prompt to
  # save."
  #
  # MEASURED BEFORE THE FIX, through these very widgets (row S21's old terms):
  # picking another simulator in the combobox left ase::session_dirty at 0, so
  # the title grew no marker, Save State had nothing to save, and the
  # xschem-quit sweep walked straight past the window without asking. The pick
  # went to ~/.xschem/ase_simulators instead -- the one place the ruling says it
  # must not go.
  #
  # EVERY ROW BELOW DRIVES THE REAL COMBOBOX through dlg_use -- the variable the
  # widget is bound to, then the proc its <<ComboboxSelected>> binding calls --
  # so none of them can pass on a tree where the gesture is wired to something
  # else.
  proc wtitle {w} {
    if {![wex $w]} { return NOWIDGET }
    if {[catch {wm title $w} t]} { return NOTITLE }
    return $t
  }
  ## THE CONF FILE IS REAL HERE and these two registrations write it, so "the
  ## file was not touched" below is a statement about a file that exists and
  ## that this suite has just seen change. ::USER_CONF_DIR is this suite's own
  ## scratch (see the redirect above); nothing here can reach the developer's.
  simreset
  catch {ase::sim_caps_clear}
  pcall ase::sim_register one41 $STUB
  pcall ase::sim_register two41 $STUB2
  catch {destroy $top20.simdlg}
  winv $top20.mb.setup $SIMLBL
  update

  # --- S40: THE PICK DIRTIES THE BENCH AND LEAVES THE FILE ALONE --------
  ## A SAVED, CLEAN BENCH THAT ALREADY HAS A CHOICE, so the pick that follows is
  ## a real CHANGE. Without the pre-set choice a "clean before / dirty after"
  ## could be produced by any first write to the key.
  set S40SET [pcall ase::session_update $key \
                [pcall ase::sim_choice_set [pcall ase::session_state $key] entry one41]]
  pcall ase::session_save $key
  pcall ase::ui::simdlg_fill $key
  update
  set S40D0 [pcall ase::session_dirty $key]
  set S40BOX0 ZZNOVAR
  catch {set S40BOX0 $::ase::ui::simuse($key)}
  set S40WAS ZZNOFILE ; set S40MT0 ZZNOFILE
  if {$CONFFILE ne {NOPROC} && $CONFFILE ne {} && [file exists $CONFFILE]} {
    set S40WAS [slurp $CONFFILE]
    set S40MT0 [file mtime $CONFFILE]
  }
  set S40T0 [wtitle $top20]
  dlg_use $key two41
  set S40D1 [pcall ase::session_dirty $key]
  set S40BOX1 ZZNOVAR
  catch {set S40BOX1 $::ase::ui::simuse($key)}
  set S40NOW ZZNOFILE ; set S40MT1 ZZNOFILE
  if {$CONFFILE ne {NOPROC} && $CONFFILE ne {} && [file exists $CONFFILE]} {
    set S40NOW [slurp $CONFFILE]
    set S40MT1 [file mtime $CONFFILE]
  }
  check {S40 THE HEADLINE picking another simulator in "Use this one:" is a change to THIS test bench -- it is unsaved work from that moment, it is what will run, and the saved simulator list on disk is not touched by it, byte for byte} \
    [list $S40SET $S40D0 $S40BOX0 $S40D1 $S40BOX1 \
          [pcall ase::sim_selected] \
          [lindex [pcall ase::sim_choice_of [pcall ase::session_state $key]] 0] \
          [lindex [pcall ase::sim_choice_of [pcall ase::session_state $key]] 1] \
          [expr {$S40WAS ne {ZZNOFILE} && $S40NOW eq $S40WAS}] \
          [expr {$S40MT0 ne {ZZNOFILE} && $S40MT1 eq $S40MT0}]] \
    [list 1 0 one41 1 two41 two41 entry two41 1 1]

  # --- S41: AND THE TITLE SAYS SO ---------------------------------------
  ## ase::ui::refresh_title appends ` *` to a dirty session's title, and the
  ## dialog's own gesture has to be enough to make that happen -- the marker is
  ## repainted by ase::session_notify, which only fires from
  ## ase::session_update. A gesture that set the registry and not the state
  ## would leave the title clean while the run had already changed.
  ##
  ## THE MARKER IS NOT RETYPED FROM THE SOURCE: the row asserts that the clean
  ## title is a prefix of the dirty one and that the dirty one is longer, so a
  ## re-wording of the marker costs nothing here.
  set S41T1 [wtitle $top20]
  check {S41 the window title marks the bench as changed the moment the simulator is picked, so the user can see there is something to save} \
    [list [expr {$S40T0 ne {NOWIDGET} && $S40T0 ne {NOTITLE}}] \
          [expr {[string first {Analog Sim Environment} $S40T0] == 0}] \
          [expr {[string match {* \*} $S40T0] ? 1 : 0}] \
          [expr {[string match {* \*} $S41T1] ? 1 : 0}] \
          [expr {[string first $S40T0 $S41T1] == 0}]] \
    [list 1 1 0 1 1]

  # --- S42: SAVE IS WHAT MAKES IT STICK, AND IT REALLY COMES BACK -------
  ## The other half of the ruling: the user must save on purpose. After Save
  ## State the bench is clean, and re-reading the state file from disk
  ## (ase::session_load -- Session > Load State, which discards everything in
  ## memory) still answers the simulator that was picked. That is the row that
  ## proves the choice is in the FILE FORMAT and not merely in a dict: it goes
  ## through ase::state_save / ase::state_load, the same pair the 104 committed
  ## .state files go through.
  pcall ase::session_save $key
  set S42D0 [pcall ase::session_dirty $key]
  set S42RC [pcall ase::session_load $key]
  set S42CH [pcall ase::sim_choice_of [pcall ase::session_state $key]]
  set S42TXT {}
  catch {set S42TXT [slurp [pcall ase::session_path $key]]}
  check {S42 saving the bench is what makes the pick stick -- afterwards there is nothing left to save, and re-reading the bench from disk still says the simulator the user chose} \
    [list $S42D0 $S42RC $S42CH [pcall ase::session_dirty $key] \
          [expr {[string first {sim_entry} $S42TXT] >= 0}]] \
    [list 0 1 [list entry two41] 0 1]

  # --- S45: THE COMBOBOX IS THIS BENCH'S, NOT THE PROGRAM'S -------------
  ## ase::sim_selected answers what is in force in the PROCESS -- one answer for
  ## every open window. The choice is the bench's. So the two can differ, and
  ## the combobox must follow the bench: the Command-window door
  ## (`ase::sim_select <name>`, this user's own first door) changes what is in
  ## force without touching any bench at all.
  ##
  ## THE SECOND TERM IS THE WITNESS that they are genuinely two different
  ## sources: the bottom bar names what is in force, so it says the OTHER one.
  ## That divergence is the known limitation recorded as D5 in
  ## doc/claude/ase_simchoice_batch/DECISIONS.md -- the run resolves it, because
  ## ase::run_deck applies the running bench's own choice before it starts
  ## anything.
  pcall ase::session_update $key \
    [pcall ase::sim_choice_set [pcall ase::session_state $key] entry one41]
  pcall ase::sim_select two41
  pcall ase::ui::simdlg_fill $key
  update
  set S45BOX ZZNOVAR
  catch {set S45BOX $::ase::ui::simuse($key)}
  check {S45 the "Use this one:" box shows the simulator THIS bench asks for, not whichever one the program happens to be running for somebody else} \
    [list $S45BOX [pcall ase::sim_selected] [barsim $key]] \
    [list one41 two41 two41]

  # --- S46: THE REFUSAL ARM STILL REFUSES -------------------------------
  ## A name the registry does not know must not become this bench's choice.
  ## ase::sim_apply_choice never raises -- it is called from inside a run -- so
  ## the refusal is taken from the registry itself before anything is written:
  ## ase::sim_select refuses exactly this and changes nothing while doing it.
  ## Storing it instead would dirty the bench with a pick that cannot run and
  ## would then show it back as the truth, which is the one thing this arm
  ## exists to prevent.
  ##
  ## THE SENTENCE IS THE MINT'S, quoted from ase::sim_why and never from a
  ## literal here (ruling D5-4).
  set S46CH0 [pcall ase::sim_choice_of [pcall ase::session_state $key]]
  dlg_use $key ghost46
  set S46BOX ZZNOVAR
  catch {set S46BOX $::ase::ui::simuse($key)}
  check {S46 picking a simulator that is not in the list is refused in the registry's own words, and the bench keeps the choice it had} \
    [list $S46CH0 [pcall ase::sim_choice_of [pcall ase::session_state $key]] \
          $S46BOX \
          [expr {[wtext $top20.simdlg.status] eq [mint ase::sim_why noentry ghost46 {} [list one41 two41]]}]] \
    [list [list entry one41] [list entry one41] one41 1]

  # --- S44: A BENCH THAT ASKS FOR A SIMULATOR THAT IS GONE --------------
  ## A saved bench outlives the registry: the entry it names can be removed, or
  ## the bench can be opened on a machine that never had it. That must not be a
  ## stack trace in the middle of a run, and it must not be silence either.
  ## ase::sim_apply_choice never raises; it says the ONE sentence that already
  ## exists for a name nobody registered, and leaves in force whatever was in
  ## force. The dialog then shows the bench's own answer rather than quietly
  ## substituting one -- that name is what the user has to go and fix.
  ##
  ## THE SENTENCE IS COUNTED, NOT JUST SEEN. ase::sim_said joins everything said
  ## since the clear, so a second sentence would still leave the first one
  ## visible; the length of the record is what pins "one".
  pcall ase::session_update $key \
    [pcall ase::sim_choice_set [pcall ase::session_state $key] entry ghost44]
  pcall ase::sim_said_clear
  set S44FORCE0 [pcall ase::sim_selected]
  set S44RC [catch {ase::sim_apply_choice [ase::session_state $key]} S44RES]
  set S44N -1
  catch {set S44N [llength $::ase::sim_said]}
  set S44SAID [pcall ase::sim_said]
  set S44FILL [pcall ase::ui::simdlg_fill $key]
  update
  set S44BOX ZZNOVAR
  catch {set S44BOX $::ase::ui::simuse($key)}
  check {S44 a bench that asks for a simulator nobody has registered any more explains itself once and carries on -- it does not stop the run with an error, and it does not quietly pretend to be something else} \
    [list $S44RC $S44N \
          [expr {$S44SAID ne {NOPROC} && $S44SAID eq [mint ase::sim_why noentry ghost44 {} [list one41 two41]]}] \
          [pcall ase::sim_selected] $S44FORCE0 \
          [expr {$S44FILL eq {NOPROC} ? {NOPROC} : {ran}}] $S44BOX] \
    [list 0 1 1 two41 two41 ran ghost44]

  # --- S43: AND THE QUIT ASKS ------------------------------------------
  ## The last clause of the ruling: "if user initiates an Xschem shutdown, then
  ## she must get a warning and a prompt to save." src/xschem.tcl's quit path
  ## calls ase::ui::prompt_all_on_quit, which walks every open session and asks
  ## about each DIRTY one. MEASURED BEFORE THE FIX: it never fired, because a
  ## simulator pick did not dirty anything.
  ##
  ## ask_save_close IS STUBBED, not invoked for real -- it is a modal dialog and
  ## no headless or Xvfb run can press a button in it. The stub answers Cancel,
  ## which aborts the quit and leaves this window open for the teardown; a
  ## `no` answer would close the session out from under it.
  ##
  ## THE CLEAN CONTROL IS HALF THE ROW. A sweep that asked about every window
  ## regardless would pass the dirty half on its own.
  set ::s43_fired 0
  set s43_had [expr {[llength [info commands ase::ui::ask_save_close]] ? 1 : 0}]
  if {$s43_had} {
    rename ase::ui::ask_save_close ::s43_real
    proc ase::ui::ask_save_close {k} { incr ::s43_fired ; return cancel }
  }
  pcall ase::session_load $key
  set S43CLEAN [pcall ase::session_dirty $key]
  set S43R0 [pcall ase::ui::prompt_all_on_quit]
  set S43F0 $::s43_fired
  dlg_use $key one41
  set S43DIRTY [pcall ase::session_dirty $key]
  set S43R1 [pcall ase::ui::prompt_all_on_quit]
  set S43F1 $::s43_fired
  if {$s43_had} {
    rename ase::ui::ask_save_close {}
    rename ::s43_real ase::ui::ask_save_close
  }
  check {S43 quitting xschem with a simulator picked and not saved stops and asks about this bench, and quitting with nothing changed does not} \
    [list $s43_had $S43CLEAN $S43R0 $S43F0 $S43DIRTY $S43F1 $S43R1] \
    [list 1 0 1 0 1 1 0]

  catch {destroy $top20.simrow}
  catch {destroy $top20.simdlg}
  ase::ui::close $key
  update

} else {
  ## NAMES THE ROWS THAT DID RUN, NOT THE ONES THAT DID NOT, and that is the
  ## repair: the hand-typed list of skipped rows here was EIGHT ROWS out of
  ## date -- it never mentioned S24-S32 -- so the message under-reported what
  ## this arm does not cover, which is the one thing it exists to say. Four
  ## names stay true when a GUI row is added; a list of skipped ones does not.
  puts "SKIP: only S0 S13 S14a S16 S38 run without a display. Every other row\
 in this file needs one -- the dialog, its row editor and the session window's\
 own status bar are the subject."
}

# --- teardown ----------------------------------------------------------------
simreset
catch {file attributes $CONFDIR -permissions 0755}
if {$UCD_HAD} { set ::USER_CONF_DIR $UCD_OLD } else { catch {unset ::USER_CONF_DIR} }
if {$NDSAVE eq {ZZUNSET}} { catch {unset ::netlist_dir} } else { set ::netlist_dir $NDSAVE }
if {$LNDSAVE eq {ZZUNSET}} { catch {unset ::local_netlist_dir} } else { set ::local_netlist_dir $LNDSAVE }

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
