# test_untitled_autosave_1486.tcl -- xschem's untitled autosave must not touch a
# file it did not write, and a driver must not leave one in the checkout.
#
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_untitled_autosave_1486.tcl
#   tests/headless/run_suites.sh --nogui test_untitled_autosave_1486     (armed)
#
# WHAT IT GUARDS (issue 1486; 0609, 1480, 0060, 0601).
# xschem names the unsaved buffer `<$PWD>/untitled.sch` and autosaves it to
# `<$PWD>/untitled~.sch` on the first edit -- `set_modify(1)` -> `write_backup()`,
# which backs an untitled buffer up ON PURPOSE because `go_back` restores an
# unsaved top level from that file (issue 0060). So a suite that edits the
# startup buffer writes into whatever directory the run was launched from.
#
# MEASURED 2026-09-20, all 405 headless suites each run in a private directory
# holding a seeded `untitled~.sch`: 51 of them destroy it -- 34 overwrite it and
# 17 DELETE it, `test_add_pin_lib_symbol_view` taking `untitled~.sym` too. No
# suite leaves anything else IN ITS WORKING DIRECTORY, so inside that directory
# this file is the whole of the class. With the launch directory = a tester's
# home, that seeded file is their own unsaved work (issue 1486's opening
# measurement).
# ⚠ IT IS NOT THE WHOLE CLASS OF "WHAT A SUITE WRITES OUTSIDE ITS SCRATCH", and
# an earlier revision of this header said it was. `backup_file_name()` puts the
# `~` beside the CELL, so nine suites write a `cellName~.sch` into the checkout
# whatever `$PWD` is -- named in tests/headless/suite_cwd.sh's header, measured
# identical on the pre-1486 binary (not a regression), and belonging to issues
# 0609/1480. The D rows below watch `untitled*` only, deliberately.
#
# TWO DEFECTS, TWO FIXES, and the rows below are in those two groups.
#
#   U* THE DELETE IS A PRODUCT DEFECT, not a test artefact. `clear_schematic()`
#      called `remove_backup()` unconditionally, so a plain `xschem clear force`
#      -- File > New, with no edit anywhere -- removed a `untitled~.sch` this
#      session never wrote. That file is a PREVIOUS session's crash recovery,
#      which `xschem_recover_backup` exists to offer back. It now removes only a
#      backup this session wrote, tracked as the PATH written
#      (`xctx->backup_owned`, set by `write_backup`, dropped by
#      `drop_owned_backup` / `remove_backup_if_owned`).
#      ⚠ THE FIRST CUT OF THIS FIX USED A BOOLEAN AND WEAKENED B8 INSTEAD, and
#      this header claimed the opposite in capitals. B8 is "a leftover `~` on the
#      next open unambiguously means a crash, not an intentional discard", so it
#      is weakened in BOTH directions -- by deleting a `~` we did not write (the
#      defect above) and by LEAVING one we did. A boolean cleared by
#      `load_schematic` did the second: `load foo; edit; load foo; clear` left
#      `foo~.sch` behind, measured on two builds, so the next open offered
#      deliberately discarded edits back as crash recovery. Tracking the path
#      closes both: every unlink is a file we demonstrably wrote, and a reload
#      cannot make us forget it. U5 is that case; U3 and U6 are the
#      leaves-one-behind direction, so the fix cannot be "never remove anything".
#      ⚠ The 0601 guard does NOT cover this: `set ::autosave_backup 0` stops
#      `write_backup()` and not `remove_backup()`, so the nine guarded suites
#      deleted the seeded file exactly like the unguarded ones (measured on
#      test_instance_update, test_paste_modify_flag_0244, test_placement_wire_gate
#      and test_shape_draw_gate). Suppression was never the fix here.
#
#   D* THE WRITE IS THE HARNESS'S TO CONTAIN. The autosave has to be written, so
#      the drivers redirect it instead of suppressing it: cwd stays the
#      repository root (suites resolve fixtures against `[pwd]` --
#      test_reopen_readonly globs `[file join [pwd] xschem_library ...]` and dies
#      from anywhere else) and only `$PWD`, which is what xschem composes the
#      buffer path from, points at a private directory that is deleted when the
#      driver finishes. tests/headless/suite_cwd.sh.
#
# ROWS
#   N0  the binary, the three drivers and suite_cwd.sh are where this thinks
#   U1  POSITIVE CONTROL + product: `xschem clear force` alone, no edit at all,
#       leaves a seeded untitled~.sch byte-identical
#   U2  the autosave is still WRITTEN on a real edit (issue 0060 not gutted)
#   U3  ... and a backup this session DID write is still dropped on discard (B8)
#   U4  a loaded cell's foreign `cell~.sch` survives a later discard too
#   U5  ... and a backup we DID write survives a RELOAD of the same cell, so the
#       discard after it still drops it (the boolean's regression, B8 direction 2)
#   U6  `go_back` answering "No" drops OUR backup but not a foreign one, with the
#       issue-0601 guard on -- the sibling call site of the U1 defect
#   D1  a known leaker through run_suites.sh leaves the repository root, and the
#       caller's own directory, exactly as it found them
#   D2  POSITIVE CONTROL for D1: the same suite run BARE does litter its cwd, so
#       D1 cannot pass because the suite stopped leaking
#   D3  the driver leaves no _suitecwd_* directory behind
#   S1  source guard: each driver arms, disarms, disarms on EVERY exit in
#       between, and puts PWD= on EVERY binary invocation -- a fourth exec site
#       or a new early exit added without it reds here

set fail 0
set pass 0
proc check {name ok detail} {
  global fail pass
  if {$ok} { puts "ok:   $name $detail"; incr pass } else { puts "FAIL: $name $detail"; incr fail }
}
proc skiprow {name why} { puts "skip: $name -- $why" }
proc slurp {p} {
  if {![file exists $p]} { return "<absent>" }
  set fp [open $p rb]; set d [read $fp]; close $fp; return $d
}

set here [file dirname [file normalize [info script]]]
source [file join $here scratch.tcl]
set repo [file normalize [file join $here .. ..]]
set S [test_scratch unt1486]
set xschem [info nameofexecutable]

set CAN "CANARY 1486 -- the tester's own unsaved work. Nothing may touch this.\n"

# Run a child xschem in $dir with $body as its script.
# ⚠ ::env(PWD) AS WELL AS cd: a child inherits the parent's ::env(PWD) and
# prefers it over getcwd() when composing the buffer path, so a bare `cd` sends
# the child's untitled~.sch to the PARENT's directory -- which is how 0609's
# first guardian read its own positive control as "no litter".
proc child {dir body {tmo 90}} {
  global xschem
  set s [file join $dir _child.tcl]
  set fp [open $s w]; puts $fp $body; puts $fp "exit 0"; close $fp
  set save [pwd]
  set had [info exists ::env(PWD)]
  if {$had} { set savepwd $::env(PWD) }
  cd $dir
  set ::env(PWD) $dir
  set err {}
  if {[catch {exec timeout $tmo $xschem --nogui --pipe -q --nolog --script $s 2>@1} err]} { }
  cd $save
  if {$had} { set ::env(PWD) $savepwd } else { unset -nocomplain ::env(PWD) }
  file delete -force $s
  return $err
}

proc newdir {name} {
  global S
  set d [file join $S $name]
  file delete -force $d
  file mkdir $d
  return $d
}

# ---------------------------------------------------------------- N0
set drivers {run_suites.sh full_audit.sh gated_xschem.sh suite_cwd.sh}
set missing {}
foreach f $drivers { if {![file exists [file join $here $f]]} { lappend missing $f } }
check "N0 binary + the drivers and suite_cwd.sh are present" \
  [expr {[file executable $xschem] && $missing eq {}}] "(missing: $missing)"

# ================================================================== U: product
# U1  A CLEAR WITH NO EDIT MUST NOT TOUCH A FOREIGN untitled~.sch.
# Red on the base build: `clear_schematic` -> `remove_backup()` deleted it, and
# the child reports nothing wrong while doing so.
set d [newdir u1]
set seed [file join $d untitled~.sch]
set fp [open $seed w]; puts -nonewline $fp $CAN; close $fp
child $d {xschem clear force}
check "U1 `xschem clear force` with no edit leaves a pre-existing untitled~.sch\
 byte-identical (it is a PREVIOUS session's crash recovery, not ours to delete)" \
  [expr {[slurp $seed] eq $CAN}] "(now: [string range [slurp $seed] 0 40]...)"

# U2  ... and the autosave is still WRITTEN on a real edit. Without this row the
# whole file passes on a build that simply stopped backing untitled buffers up,
# which is the regression issue 0060 is about (it lost the entire top level on
# descend+ascend).
set d [newdir u2]
set bak [file join $d untitled~.sch]
set dev [file join $repo xschem_library devices]
if {![file isdirectory $dev]} {
  skiprow "U2 the untitled autosave is still written" "no $dev in this checkout"
} else {
  child $d "xschem instance [list [file join $dev lab_pin.sym]] 100 100 0 0 {name=zz1}"
  set got [slurp $bak]
  check "U2 an edit to the untitled buffer still WRITES untitled~.sch (issue 0060:\
 go_back restores an unsaved top level from it)" \
    [expr {[string match "v *xschem version*" $got] && [string match "*zz1*" $got]}] \
    "([string length $got] bytes)"
}

# U3  THE OTHER DIRECTION, so the fix cannot be "remove_backup never fires".
# A backup this session DID write is still dropped when the buffer is discarded
# (the B8 invariant: a leftover ~ means a crash, not an intentional discard).
set d [newdir u3]
set bak [file join $d untitled~.sch]
if {![file isdirectory $dev]} {
  skiprow "U3 our own backup is still dropped on discard" "no $dev in this checkout"
} else {
  child $d "xschem instance [list [file join $dev lab_pin.sym]] 100 100 0 0 {name=zz1}\nxschem clear force"
  check "U3 a backup THIS session wrote is still removed when the buffer is\
 discarded (spec B8 -- the invariant the U1 fix must not break)" \
    [expr {![file exists $bak]}] "(exists: [file exists $bak])"
}

# U4  THE SAME DEFECT ONE STEP ON: edit untitled (so this session owns a backup),
# then open a cell, then discard. The cell's own `cell~.sch` is a foreign file and
# must survive. Red on the base build for the same reason as U1.
set d [newdir u4]
set cell [file join $d cell.sch]
set cellbak [file join $d cell~.sch]
set libsch [lindex [lsort [glob -nocomplain [file join $repo xschem_library *.sch]]] 0]
if {$libsch eq {}} {
  set libsch [lindex [lsort [glob -nocomplain [file join $repo xschem_library * *.sch]]] 0]
}
if {$libsch eq {} || ![file isdirectory $dev]} {
  skiprow "U4 a loaded cell's foreign cell~.sch survives a discard" \
    "no library .sch (or no $dev) in this checkout"
} else {
  file copy -force $libsch $cell
  set fp [open $cellbak w]; puts -nonewline $fp $CAN; close $fp
  child $d "xschem instance [list [file join $dev lab_pin.sym]] 100 100 0 0 {name=zz1}\nxschem load [list $cell]\nxschem clear force"
  check "U4 opening a cell and then discarding it leaves that cell's foreign\
 cell~.sch byte-identical (we own untitled~.sch, not this file)" \
    [expr {[slurp $cellbak] eq $CAN}] "(now: [string range [slurp $cellbak] 0 40]...)"
}

# U5  THE FIRST FIX'S OWN REGRESSION, kept as a row because it passed the whole
# file while live. Ownership was a BOOLEAN that load_schematic cleared, so any
# load between the write and the discard made xschem forget its own backup:
#   load foo.sch -> edit (foo~.sch written) -> load foo.sch (the reload DISCARDS
#   the edit) -> clear force
# left foo~.sch behind, and the next open of foo.sch offers those deliberately
# discarded edits back as crash recovery. Measured on two builds of the same
# tree: pre-1486 `exists=0`, boolean-fix `exists=1`, path-fix `exists=0`.
# U4 cannot see it (no intervening load) and U3 cannot (no load at all).
set d [newdir u5]
set cell [file join $d cell.sch]
set cellbak [file join $d cell~.sch]
if {$libsch eq {} || ![file isdirectory $dev]} {
  skiprow "U5 a reload does not make xschem forget its own backup" \
    "no library .sch (or no $dev) in this checkout"
} else {
  file copy -force $libsch $cell
  child $d "xschem load [list $cell]\nxschem instance [list [file join $dev lab_pin.sym]] 100 100 0 0 {name=zz1}\nxschem load [list $cell]\nxschem clear force"
  check "U5 a backup THIS session wrote is still dropped on discard after the\
 same cell was RELOADED (ownership follows the file we wrote, not the buffer)" \
    [expr {![file exists $cellbak]}] "(exists: [file exists $cellbak])"
}

# U6  THE SIBLING CALL SITE. go_back()'s "No" arm ("discard this level's edits")
# called remove_backup() unconditionally too, so it deleted a foreign cellName~
# whenever the buffer was modified but no backup of OURS had been written -- which
# is exactly what the issue-0601 guard `set ::autosave_backup 0` produces, because
# it stops write_backup() and not remove_backup(). MEASURED red on a build whose
# only difference is that one call: the seeded canary came back exists=0.
# U6b is the other direction so the guard cannot degenerate into "never remove".
set fixd [file join $here fixtures descend]
if {![file exists [file join $fixd descend_child.sym]]} {
  skiprow "U6 go_back \"No\" leaves a foreign cellName~.sch alone" "no fixtures/descend"
  skiprow "U6b go_back \"No\" still drops a backup we wrote" "no fixtures/descend"
} else {
  # U6: write suppressed by the 0601 guard -> we own nothing -> delete nothing
  set d [newdir u6]
  foreach fn {descend_child.sch descend_child.sym} { file copy -force [file join $fixd $fn] $d }
  set kid [file join $d descend_child~.sch]
  set fp [open $kid w]; puts -nonewline $fp $CAN; close $fp
  child $d "proc ask_save {{a {}} {b {}}} { return no }
set ::autosave_backup 0
xschem clear force
xschem instance [list [file join $d descend_child.sym]] 0 0 0 0 {name=x1}
xschem unselect_all
xschem select instance 0
xschem descend
xschem instance [list [file join $d descend_child.sym]] 200 200 0 0 {name=x9}
xschem go_back"
  check "U6 go_back answering \"No\" with the issue-0601 guard on (no backup of\
 ours was ever written) leaves the child's foreign descend_child~.sch untouched" \
    [expr {[slurp $kid] eq $CAN}] "(now: [string range [slurp $kid] 0 40]...)"

  # U6b: no guard -> the child's edit writes OUR backup -> "No" must drop it
  set d [newdir u6b]
  foreach fn {descend_child.sch descend_child.sym} { file copy -force [file join $fixd $fn] $d }
  set kid [file join $d descend_child~.sch]
  # ⚠ The child records whether the backup was there BEFORE go_back. Without that
  # this row passes on a build that never writes the child's backup at all -- the
  # same green-by-absence that D2 exists to stop for D1.
  set pre [file join $d precond]
  child $d "proc ask_save {{a {}} {b {}}} { return no }
xschem clear force
xschem instance [list [file join $d descend_child.sym]] 0 0 0 0 {name=x1}
xschem unselect_all
xschem select instance 0
xschem descend
xschem instance [list [file join $d descend_child.sym]] 200 200 0 0 {name=x9}
if {\[file exists [list $kid]\]} { close \[open [list $pre] w\] }
xschem go_back"
  check "U6b go_back answering \"No\" still DROPS the child's cellName~.sch when\
 this session wrote it (spec B8 -- the invariant U6 must not break)" \
    [expr {[file exists $pre] && ![file exists $kid]}] \
    "(written before go_back: [file exists $pre]; still there after: [file exists $kid])"
}

# ================================================================== D: drivers
# The leaker used below is measured, not assumed: test_descend_inert_class places
# one instance on the startup untitled buffer (issue 1480 pinned the resulting
# file at 113 B, md5 2dbeb0ea88ae0a73d6d34e6efc5463e3).
set leaker test_descend_inert_class

# D2 FIRST, because it is D1's positive control: run the leaker BARE in a private
# directory and require that it DOES write untitled~.sch there. If this row ever
# goes green-by-absence, D1 below is vacuous.
set d [newdir d2]
if {![file exists [file join $here $leaker.tcl]]} {
  skiprow "D2 positive control: the leaker litters a bare run's cwd" "no $leaker.tcl"
  set d2_ok 0
} else {
  set save [pwd]; set had [info exists ::env(PWD)]
  if {$had} { set savepwd $::env(PWD) }
  cd $d; set ::env(PWD) $d
  catch {exec timeout 90 $xschem --nogui --pipe -q --nolog --script [file join $here $leaker.tcl] 2>@1}
  cd $save
  if {$had} { set ::env(PWD) $savepwd } else { unset -nocomplain ::env(PWD) }
  set d2_ok [file exists [file join $d untitled~.sch]]
  check "D2 POSITIVE CONTROL: $leaker run BARE in its own directory DOES write\
 untitled~.sch there (D1 is only evidence while this is true)" \
    $d2_ok "(left: [lsort [glob -nocomplain -tails -directory $d *]])"
}

# D1  The same suite through run_suites.sh: the repository root and the caller's
# own directory come out exactly as they went in.
# ⚠ A DELTA over the repo root, never an existence test. Another suite -- or T1
# itself, whose cwd is tests/ -- may have left an untitled~.sch there before this
# row ran, and reddening on someone else's litter is the defect issue 0609 §2
# records (test_ase_core's C11 was red in 13 recorded audits for exactly that).
proc untitled_snap {dirs} {
  set out {}
  foreach dir $dirs {
    foreach f [glob -nocomplain -directory $dir untitled*] { lappend out $f }
  }
  return [lsort $out]
}
set watch [list $repo [file join $repo tests] [file join $repo tests headless]]
set d [newdir d1]
set seed [file join $d untitled~.sch]
set fp [open $seed w]; puts -nonewline $fp $CAN; close $fp
set rs [file join $here run_suites.sh]
if {![file executable $rs] || !$d2_ok} {
  skiprow "D1 run_suites.sh leaves the checkout and the caller's directory alone" \
    [expr {[file executable $rs] ? "the D2 positive control did not fire" : "no executable run_suites.sh"}]
} else {
  set pre [untitled_snap $watch]
  # ⚠ A DELTA here too. This suite is USUALLY RUN THROUGH run_suites.sh itself,
  # and that enclosing driver's own _suitecwd_<pid> is live while these rows run:
  # an existence test would red on the driver that is running it.
  set scwd_pre [lsort [glob -nocomplain -directory [file join $repo tests headless .scratch] _suitecwd_*]]
  set save [pwd]; set had [info exists ::env(PWD)]
  if {$had} { set savepwd $::env(PWD) }
  cd $d; set ::env(PWD) $d
  set rsout {}
  catch {exec timeout 300 env AUDIT_DISPLAY=none GUI_GATE=0 $rs --nogui $leaker 2>@1} rsout
  cd $save
  if {$had} { set ::env(PWD) $savepwd } else { unset -nocomplain ::env(PWD) }
  set post [untitled_snap $watch]
  set new {}
  foreach f $post { if {[lsearch -exact $pre $f] < 0} { lappend new $f } }
  set ran [regexp -line {^PASS +\|} $rsout]
  check "D1 $leaker through run_suites.sh adds no untitled* anywhere in the\
 checkout (a DELTA over the repo root, tests/ and tests/headless/)" \
    [expr {$ran && $new eq {}}] "(ran: $ran; new: $new)"
  check "D1b ... and the caller's own untitled~.sch is byte-identical afterwards" \
    [expr {[slurp $seed] eq $CAN}] "(now: [string range [slurp $seed] 0 40]...)"
  # D3 leftovers, read after the same run
  set left {}
  foreach f [lsort [glob -nocomplain -directory [file join $repo tests headless .scratch] _suitecwd_*]] {
    if {[lsearch -exact $scwd_pre $f] < 0} { lappend left $f }
  }
  check "D3 the run removed its private \$PWD directory (suite_cwd_disarm) --\
 a DELTA, so the enclosing run_suites.sh's own live one does not red it" \
    [expr {$left eq {}}] "(left: $left)"
}

# ================================================================== S: source
# A textual guard, so the redirect cannot be dropped by an edit that still looks
# reasonable. It reads the three drivers: each must arm, each must disarm, and
# EVERY line that starts the binary must carry the PWD= prefix -- a fourth exec
# site added without one is the way this comes back.
# A line STARTS the binary when, in some command position on it, the first word
# is $XSCHEM -- after the wrapper words and VAR=value prefixes a launch carries
# (`timeout "$TIMEOUT" env "PWD=$d" FOO=bar "$XSCHEM" ...`). Position, not shape:
# the previous version required `"$XSCHEM"` to be followed by a flag or `"$@"`,
# which would have missed a site written `"$XSCHEM" "$f"` or with $XSCHEM
# unquoted (nit measured in the F verify round). $( and ) open and close a
# command position, so `$(dirname "$XSCHEM")` is a lookup while
# `out=$(timeout ... "$XSCHEM" --script ...)` is a launch; `case "$XSCHEM" in`,
# `[ ! -x "$XSCHEM" ]` and an echo of a FATAL message never reach first position.
proc launches_binary {ln} {
  regsub -all {\$\(} $ln " \x01 " ln
  regsub -all {[()]} $ln " \x01 " ln
  regsub -all {&&|\|\||;|\|} $ln " \x01 " ln
  foreach seg [split $ln \x01] {
    set toks [regexp -all -inline {\S+} $seg]
    set i 0
    while {$i < [llength $toks]} {
      set t [lindex $toks $i]
      if {[regexp {^(if|then|else|elif|do|while|until|!|\{|\}|exec|env|nohup|command)$} $t]} { incr i; continue }
      if {$t eq "timeout"} { incr i 2; continue }   ;# eats its duration argument
      if {[regexp {^"?[A-Za-z_][A-Za-z0-9_]*=} $t]} { incr i; continue }
      break
    }
    if {[regexp {^"?\$\{?XSCHEM\}?"?$} [lindex $toks $i]]} { return 1 }
  }
  return 0
}
# `exit` as a COMMAND, i.e. at the start of a line or right after ; && || { }.
# Not after any other word or after `(`: run_suites.sh:217 and :255 both spell
# the WORD "exit" inside a message string, and a looser pattern reds on those.
proc exits_here {ln} { return [regexp {(^|[;&|{}])[ \t]*exit([ \t]|$)} $ln] }

set s1bad {}
foreach f {run_suites.sh full_audit.sh gated_xschem.sh} {
  set src [slurp [file join $here $f]]
  if {$src eq "<absent>"} { lappend s1bad "$f: absent"; continue }
  # ⚠ NON-COMMENT LINES ONLY. A whole-file regexp passed on the strength of a
  # COMMENT that merely mentions suite_cwd_arm: sabotage 3 deleted full_audit.sh's
  # actual call and this row stayed green, because line 76 of that file says
  # "see the suite_cwd_arm below". Measured, and the reason for the split.
  #
  # ⚠ THE DISARM TERMINATOR TAKES `;` AND `)` TOO. The old one required a space
  # or end-of-line, so it did not see a semicolon-terminated call -- the INLINE
  # form every early exit uses. Measured: commenting out only
  # run_suites.sh's standalone call reported "no suite_cwd_disarm call" although
  # the inline one at :149 was still there. It failed toward red, so it was safe,
  # but the row's stated intent was met by accident.
  set armed -1; set covered 0
  set lines [split $src \n]
  for {set i 0} {$i < [llength $lines]} {incr i} {
    set ln [lindex $lines $i]
    if {[string match "#*" [string trimleft $ln]]} continue
    set has_arm [regexp {(^|[ \t;&|]) *suite_cwd_arm[ \t]} $ln]
    set has_dis [regexp {(^|[ \t;&|]) *suite_cwd_disarm([ \t;&|)]|$)} $ln]
    if {$has_arm && $armed < 0} { set armed [expr {$i + 1}] }
    if {$armed < 0} continue
    # EVERY EXIT BETWEEN THE ARM AND THE DISARM MUST DISARM. Two were missed --
    # full_audit.sh's gate-stop (pressing Stop on the panel, an ordinary user
    # action) and gated_xschem.sh's "binary not executable" FATAL, the second
    # measured leaving tests/headless/.scratch/_suitecwd_<pid> in the checkout.
    # The old row could not see either: it only asked that SOME disarm existed
    # somewhere in the file. A trap would cover the growing list of exits by
    # construction and is refused on purpose (see suite_cwd.sh: one EXIT trap per
    # shell, and test_home.sh and gui_gate.sh already contend for it), so the
    # test carries that job instead.
    if {[exits_here $ln] && !$has_dis && !$covered} {
      lappend s1bad "$f:[expr {$i + 1}]: exit after suite_cwd_arm with no disarm -> [string trim $ln]"
    }
    if {$has_dis && ![exits_here $ln]} { set covered 1 }
    if {[launches_binary $ln] && ![regexp {PWD=} $ln]} {
      lappend s1bad "$f:[expr {$i + 1}]: starts the binary with no PWD= -> [string trim $ln]"
    }
  }
  if {$armed < 0} { lappend s1bad "$f: no suite_cwd_arm call" }
  if {!$covered}  { lappend s1bad "$f: no standalone suite_cwd_disarm call" }
}
check "S1 run_suites.sh, full_audit.sh and gated_xschem.sh each arm and disarm\
 suite_cwd, every exit between the two disarms, and every binary invocation\
 carries the private PWD=" \
  [expr {$s1bad eq {}}] "([join $s1bad {; }])"

# ⚠ THE COMPLETION BANNER IS NOT DECORATION -- IT IS WHAT MAKES THIS SUITE
# REGISTRABLE IN T1. `run_suites.sh` scores a suite from its `^RESULT` line and
# needs no banner, so this file passed there for its whole life without one;
# `tests/run_regression.tcl` scores an hcases entry with
# `regression_case_failed`, which is exit 0 AND `banner_complete` AND no death
# marker. MEASURED on this suite's own output before the banner existed:
# `banner_complete` 0, `regression_case_failed` 1 -- so registering it would have
# appended `HARNESS: ... did not complete cleanly` and counted a failure in the
# one file whose baseline is ZERO, while every one of its 13 checks passed. That
# is issue 0689's false red from the other side. The shape is banner_rule.tcl's,
# whole-line, and the failure spelling is `notok` as the other ~130 suites use.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($pass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($pass passed)"
  puts "OVERALL: notok"
}
exit [expr {$fail != 0}]
