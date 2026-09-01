# tests/headless/test_descend_doors_1228.tcl
#
# THE CONTROLS THAT OPEN A SUB-SCHEMATIC DO NOT AGREE WITH EACH OTHER, AND ONE OF
# THEM OPENS A DIFFERENT SCHEMATIC THAN THE ONE THE INSTANCE IS SET TO OPEN.
#
# Run TRUE HEADLESS from the repo root:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_doors_1228.tcl
#
# ============================================================================
# WHAT A PERSON SEES
# ============================================================================
# A symbol placed on a sheet can be told, one copy at a time, WHICH schematic
# file that copy should open -- its "schematic" setting. XSCHEM ships a sheet
# that does exactly this: xschem_library/inst_sch_select/inst_sch_select.sch.
# Copy x2 is set to open comp3_parax.sch, copy x5 to open comp3_empty.sch, and
# copy x3 is set to open a file that is not there.
#
# There are two user-visible faults, and the SECOND one is the worse of the two.
#
#   FAULT A -- issue 0979, the blank page. The toolbar button, the command
#   palette row and the Cadence chords all reach the same engine, and that
#   engine cannot fall back to the cell's own schematic. On copy x3 the person
#   is put ONE LEVEL DOWN inside an empty page named after a file that does not
#   exist. Getting out needs Pop schematic. At least it looks broken.
#
#   FAULT B -- unfiled before this pass, and it does NOT look broken. Pressing
#   the E key, or Edit > Push schematic, on copy x2 opens comp3.sch -- 54
#   copies on it -- when the instance is set to open comp3_parax.sch, which has
#   8 and which is right there on disk. No prompt, no message, no error. Every
#   channel reports success. A person reading that page believes they are
#   looking inside x2, and they are not.
#
#   FAULT C -- a third disagreement, about whether the page opens editable.
#   In the Cadence read-only browse mode the FAILED descend of x3 comes back
#   EDITABLE, on a blank page named after the missing file, so an accidental
#   save would create that junk file -- inside the one mode whose whole purpose
#   is looking without touching.
#
# ============================================================================
# WHY NO EXISTING SUITE CATCHES ANY OF THIS
# ============================================================================
# tests/headless/test_hi_descend.tcl and tests/headless/test_descend_views.tcl
# are both GREEN at HEAD, and no fixture under
# tests/headless/fixtures/hi_descend/ carries a per-copy "schematic" setting at
# all. So no committed row anywhere drives an instance-level binding through the
# E key. That hole is exactly what let FAULT B through.
#
# ============================================================================
# THE ANSWER DISCIPLINE
# ============================================================================
# Every helper answers NOPROC when the command it needs does not exist and
# RAISED:<text> when it blows up, so a missing proc can never quietly satisfy a
# golden that expected an empty string.
# ============================================================================

set fail 0
set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch descend_doors_1228]

# ---------------------------------------------------------------------------
# THIS SUITE IS HEADLESS-ONLY, AND RUNNING IT WITH A DISPLAY USED TO HANG FOREVER.
# Row A5 descends into copy x3, whose schematic file is not there. With a screen
# to ask on, that is exactly the case that pops the "this file is not there -- open
# the cell's own schematic instead?" question and WAITS for a person to answer, so
# the run blocks with nothing on stdout (Tcl buffers to a pipe and this file only
# flushes at the end). Measured: ten minutes, no output, no clue.
# Every runner drives this file with --nogui, where has_x is 0 and no question is
# ever asked -- tests/run_regression.tcl's hcases list and full_audit.sh's
# nogui_tests string. This refuses in one second instead of hanging, so somebody
# who reaches for the dev-display arm out of habit gets told which arm to use.
# ---------------------------------------------------------------------------
if {[info exists ::has_x] && $::has_x} {
  puts "This suite has to run without a display. One of its checks opens a copy"
  puts "whose schematic file is missing, and with a display that pops a question"
  puts "and waits for someone to answer it, so the run never finishes."
  puts "Run it like this instead:"
  puts "  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_doors_1228.tcl"
  puts "RESULT: 1 FAILED (0 passed)"
  puts "OVERALL: notok"
  flush stdout
  exit 2
}

set ::FIX  [file join $repo xschem_library inst_sch_select inst_sch_select.sch]
if {![file isfile $::FIX]} {
  puts "FAIL: FIXTURE the shipped sheet xschem_library/inst_sch_select is missing : FAIL"
  puts "RESULT: 1 FAILED (0 passed)"
  puts "OVERALL: notok"
  exit 1
}

# ---------------------------------------------------------------------------
# behavioural helpers
# ---------------------------------------------------------------------------
proc dd_reload {} {
  set ::hi_descend_view_path {}
  xschem load $::FIX
  xschem unselect_all
}
proc dd_ans {script} {
  set rc [catch {uplevel #0 $script} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc dd_sheet {} { return [file tail [xschem get schname]] }
proc dd_n     {} { return [xschem get instances] }
proc dd_w     {} { return [xschem get wires] }

# ---------------------------------------------------------------------------
# structural helpers -- comments stripped first, or the prose matches
# ---------------------------------------------------------------------------
proc dd_slurp {p} {
  if {![file isfile $p]} { return "" }
  set f [open $p r]; set s [read $f]; close $f; return $s
}
# C block comments away. Tcl regexp dot matches newline by default, so this
# spans a multi-line comment in one go.
proc dd_nocomment_c {s} { regsub -all {/\*.*?\*/} $s { } s ; return $s }
# Tcl and CSV: drop whole lines whose first non-blank character is a hash, AND
# truncate a TRAILING comment -- the `;#` form -- at the semicolon.
#
# ⚠ THE TRAILING FORM IS NOT A REFINEMENT, IT IS THE WHOLE POINT OF THE ROWS
# BELOW THAT COUNT. A sabotage pass stripped the fallback flag from five of the
# seven controls a person can press, put the literal text back as five trailing
# `;#` comments, and this file scored 29/29 ALL PASS -- rows E6, E7 and F1 all
# count text, and a stripper that only understood a hash in column one counted
# the comments. Five controls would have gone back to stranding people one level
# down on a blank page, green.
#
# Quote parity is tracked because a `;#` INSIDE a double-quoted string is real
# code, not a comment -- src/xschem.tcl:2489 writes a settings file whose CONTENT
# is a commented Tcl line. A `;` inside a string sits at odd parity and is left
# alone; even parity means the semicolon really does end a command. That is
# conservative in the safe direction: a line this cannot prove is a comment keeps
# the behaviour it had before, which is what every row was already written
# against.
#
# The text before the semicolon is kept BYTE FOR BYTE, trailing blanks included.
# dd_block finds the end of a Tcl proc with the regexp `^\}$`, so trimming would
# turn a `} ;# note` line into a bare closing brace and cut a proc block short.
proc dd_nocomment_tcl {s} {
  set out {}
  foreach ln [split $s \n] {
    if {[regexp {^[ \t]*#} $ln]} { continue }
    lappend out [dd_strip_trailing_comment $ln]
  }
  return [join $out \n]
}
# Truncate $ln at the first `;` that is outside a double-quoted string and is
# followed by optional blanks and a hash. Returns the line unchanged when there
# is no such semicolon.
proc dd_strip_trailing_comment {ln} {
  set n [string length $ln]
  set inq 0
  for {set i 0} {$i < $n} {incr i} {
    set c [string index $ln $i]
    if {$c eq "\\"} { incr i ; continue }
    if {$c eq "\""} { set inq [expr {!$inq}] ; continue }
    if {$inq} { continue }
    if {$c ne ";"} { continue }
    if {[regexp {^[ \t]*#} [string range $ln [expr {$i + 1}] end]]} {
      return [string range $ln 0 [expr {$i - 1}]]
    }
  }
  return $ln
}
proc dd_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0; set i 0
  while {1} {
    set i [string first $needle $hay $i]
    if {$i < 0} { break }
    incr n; incr i
  }
  return $n
}
# Lines from the first line matching $startpat down to the first later line
# matching $endpat, inclusive. Both are regexps against the whole line. Used for
# top-level C functions, indented scheduler branches and Tcl procs alike, all of
# which close on a line that is nothing but a brace at a known indent.
proc dd_block {src startpat endpat} {
  set lines [split $src \n]
  set n [llength $lines]
  set i -1
  for {set k 0} {$k < $n} {incr k} {
    if {[regexp $startpat [lindex $lines $k]]} { set i $k; break }
  }
  if {$i < 0} { return "" }
  for {set k [expr {$i + 1}]} {$k < $n} {incr k} {
    if {[regexp $endpat [lindex $lines $k]]} {
      return [join [lrange $lines $i $k] \n]
    }
  }
  return ""
}
proc dd_cfun    {src sig}  { return [dd_block $src $sig {^\}} ] }
proc dd_branch  {src sig}  { return [dd_block $src $sig {^    \}$}] }
proc dd_tclproc {src name} { return [dd_block $src "^proc $name " {^\}$}] }
proc dd_has {hay needle} { return [expr {[string first $needle $hay] >= 0 ? 1 : 0}] }

set SRC_SCHED  [dd_nocomment_c   [dd_slurp [file join $repo src scheduler.c]]]
set SRC_ACT    [dd_nocomment_c   [dd_slurp [file join $repo src actions.c]]]
set SRC_TCL    [dd_nocomment_tcl [dd_slurp [file join $repo src xschem.tcl]]]
set SRC_CSV    [dd_nocomment_tcl [dd_slurp [file join $repo src actions.csv]]]
set SRC_CAD    [dd_nocomment_tcl [dd_slurp [file join $repo utils cadence_nav.tcl]]]
set SRC_WAVE   [dd_nocomment_tcl [dd_slurp [file join $repo src wave_viewer.tcl]]]
set SRC_SKY    [dd_nocomment_tcl [dd_slurp [file join $repo sky130A sky130_procs.tcl]]]
set SRC_IHP    [dd_nocomment_tcl [dd_slurp [file join $repo ihp-sg13g2 sg13g2_procs.tcl]]]
set SRC_OPANN  [dd_slurp [file join $repo src op_annot.tcl]]
set SRC_TOPANN [dd_slurp [file join $repo tests headless test_op_annot.tcl]]
set SRC_TOPT   [dd_slurp [file join $repo tests headless test_ase_optier_0963.tcl]]
# F1 counts text in BOTH directions, so it needs the source both ways. The
# "it asks for the fallback" half must read comment-stripped, or a trailing
# `;# xschem descend -fallback` satisfies it while the code does nothing of the
# kind. The "it no longer hand-arms the override" half must read RAW, because a
# comment that still talks about arming the override is exactly as misleading to
# the next reader as the code was. SRC_OPANN and SRC_TOPANN below stay raw on
# purpose: F2 is about stale line numbers, which live only in comments.
set SRC_TOPTS  [dd_nocomment_tcl $SRC_TOPT]

# ===========================================================================
# SECTION A -- the doors, and whether they land on the same page
# ===========================================================================

# A1. The one thing that is already right and must stay right: the bare verb DOES
# honour a per-copy binding that names a real file.
dd_reload
set a1 [dd_ans {xschem descend -inst x2}]
check {A1 the toolbar button and the command palette open the file copy x2 is set\
 to open, comp3_parax.sch, with its 8 copies on it} \
  [list $a1 [dd_sheet] [dd_n] [dd_w]] {1 comp3_parax.sch 8 3}

# A2. FAULT B, the headline. Pressing E must open the same file the toolbar does.
dd_reload
set a2 [dd_ans {hi_descend inst=x2 target=current}]
check {A2 pressing E on copy x2 opens the file that copy is set to open,\
 comp3_parax.sch with 8 copies -- not the cell's own comp3.sch with 54} \
  [list $a2 [dd_sheet] [dd_n] [dd_w]] {1 comp3_parax.sch 8 3}

# A3. The same fault on a second, independent copy.
dd_reload
set a3 [dd_ans {hi_descend inst=x5 target=current}]
check {A3 pressing E on copy x5 opens comp3_empty.sch, the file that copy is set\
 to open, with its 7 copies} \
  [list $a3 [dd_sheet] [dd_n]] {1 comp3_empty.sch 7}

# A4. The ordinary copy, which carries no per-copy setting, must not move.
dd_reload
set a4 [dd_ans {hi_descend inst=x1 target=current}]
check {A4 pressing E on copy x1, which has no per-copy setting, still opens the\
 cell's own comp3.sch with 54 copies} \
  [list $a4 [dd_sheet] [dd_n]] {1 comp3.sch 54}

# A5. FAULT A, the headline, on the door a script drives. With the opt-in flag the
# verb must open the cell's own schematic instead of stranding the person.
dd_reload
set c0 [xschem get currsch]
set a5 [dd_ans {xschem descend -fallback -inst x3}]
check {A5 with the fallback asked for, copy x3 -- whose file is not there -- opens\
 the cell's own comp3.sch one level down, and reports no error} \
  [list $a5 [dd_sheet] [expr {[xschem get currsch] - $c0}] [xschem get descend_error]] \
  {1 comp3.sch 1 {}}

# C3 rides on A5's state: the sentence the person reads afterwards.
# PLAIN ENGLISH is a hard requirement -- it must name the copy, the file that is
# missing and the file that was opened instead, in words, with no internal
# vocabulary at all.
set c3msg [xschem get statusmsg]
set c3 {}
foreach w {x3 comp3_pex comp3.sch} { lappend c3 [dd_has $c3msg $w] }
foreach w {load-failed view-missing get_sch_from_sym fallback} {
  lappend c3 [expr {[dd_has $c3msg $w] ? 0 : 1}]
}
check {C3 the message after the fallback names the copy, the file that is missing\
 and the file opened instead, in plain words, with no internal vocabulary} \
  $c3 {1 1 1 1 1 1 1}

# C4 also rides on A5's state, and it is the ONLY row that can see whether the
# person gets to the END of that message.
#
# ⚠ C3 IS NOT ENOUGH, AND A SABOTAGE PASS PROVED IT. The status line is a fixed
# 256-byte buffer (xctx->statusmsg_text, src/xschem.h). Name the two schematic
# files by their full paths instead of their file names and the sentence runs to
# 255 characters and stops mid-word: the person is told a file is missing and is
# never told what was opened instead. C3 asks only whether the words x3,
# comp3_pex and comp3.sch APPEAR -- all three still do, and the suite scored
# 29/29 ALL PASS with the message cut off at "Opened the c". A sentence a person
# cannot finish reading is not plain English, so the last clause is asserted
# WHOLE. That first element is the witness: put the paths back and it reads 0.
#
# The second element is an EARLY WARNING, and the threshold is deliberately not
# 256. A 256-byte buffer TRUNCATES rather than overflows, so "under 256" is true
# even of the cut-off message -- measured, it read 255 -- and a row asserting it
# could never go red. The sentence is 190 characters here and does not vary with
# where the repo is checked out, because it names the two files by file name. 240
# leaves fifty characters of room: a future rewording that creeps toward the
# ceiling reddens this row while the sentence still finishes, instead of shipping
# a message that stops mid-word.
check {C4 the person actually reaches the end of the message, where it says what\
 was opened instead, and the wording still has room to spare in the status line} \
  [list [string match {*Opened the cell's own schematic instead.} $c3msg] \
        [expr {[string length $c3msg] < 240 ? 1 : 0}]] \
  {1 1}

# A6. The E key must never strand a person on an empty page, even when the copy's
# file is not there. GREEN AT HEAD BY CONSTRUCTION -- today E ignores the binding
# entirely and so happens to land on a populated page. It is here to catch the
# half-fix that teaches E to honour the binding without teaching it to fall back.
dd_reload
set a6 [dd_ans {hi_descend inst=x3 target=current}]
check {A6 pressing E on copy x3, whose file is not there, still lands on a page\
 with something on it rather than an empty one} \
  [list $a6 [expr {[dd_n] > 0 ? 1 : 0}] [dd_sheet]] {1 1 comp3.sch}

# A7. THE PROTECTION ROW. Without the flag, nothing about the scripted verb moves.
# test_op_annot's W30a and two committed workarounds depend on exactly this.
dd_reload
set c0 [xschem get currsch]
set a7 [dd_ans {xschem descend -inst x3}]
check {A7 without the fallback asked for, the verb behaves exactly as it always\
 has -- it refuses, records why, and leaves the person one level down} \
  [list $a7 [expr {[xschem get currsch] - $c0}] [xschem get descend_error]] \
  {0 1 load-failed}

# ===========================================================================
# SECTION B -- the list of views the chooser offers, and which one it lands on
# ===========================================================================

proc dd_enum {inst} {
  if {![llength [info commands hi_descend_enum_views]]} { return NOPROC }
  set rc [catch {hi_descend_enum_views $inst} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc dd_enum_tails {inst} {
  set rows [dd_enum $inst]
  if {[lsearch -exact {NOPROC} $rows] >= 0} { return $rows }
  set t {}
  foreach r $rows { lappend t [file tail [lindex $r 2]] }
  return $t
}

# B1. The file copy x2 is actually set to open must be one of the choices.
# Reload first: row A7 deliberately leaves the session one level down inside a
# page that has no copy x2 on it, and an empty list would redden B1 for the wrong
# reason.
dd_reload
check {B1 the list of views offered for copy x2 includes comp3_parax.sch, the file\
 that copy is set to open} \
  [expr {[lsearch -exact [dd_enum_tails x2] comp3_parax.sch] >= 0 ? 1 : 0}] 1

# B2. And the cell's own schematic must still be offered beside it.
set b2 [dd_enum x2]
check {B2 the cell's own comp3.sch is still offered, under the name schematic, so\
 a person can still choose it} \
  [expr {[lsearch -exact $b2 [list schematic schematic \
     [file join $::repo xschem_library inst_sch_select comp3.sch]]] >= 0 ? 1 : 0}] 1

# B3. Offered is not the same as chosen. The chooser must DEFAULT to the copy's
# own binding.
proc dd_b3 {} {
  if {![llength [info commands hi_descend_inst_defsch]]} { return NOPROC }
  if {![llength [info commands hi_descend_pick_view]]}   { return NOPROC }
  set rows [dd_enum x2]
  set rc [catch {hi_descend_inst_defsch x2} dp]
  if {$rc} { return "RAISED:$dp" }
  set rc [catch {hi_descend_pick_view $rows {} {} $dp} r]
  if {$rc} { return "RAISED:$r" }
  return [file tail [lindex $r 2]]
}
dd_reload
check {B3 the chooser starts out pointing at comp3_parax.sch, the file copy x2 is\
 set to open, rather than at the cell's own schematic} \
  [dd_b3] comp3_parax.sch

# B4. The person can still ask for the cell's own schematic by name.
dd_reload
set b4 [dd_ans {hi_descend inst=x2 view=schematic target=current}]
check {B4 asking for the view named schematic still opens the cell's own\
 comp3.sch with 54 copies, so nothing is taken away} \
  [list $b4 [dd_sheet] [dd_n]] {1 comp3.sch 54}

# B5. THE NAME COLLISION. A copy bound to a file whose name happens to be
# schematic.sch would give the chooser two different rows both called schematic,
# and a chooser that picks by name would silently return the wrong one.
set b5dir [file join $scratch b5]
file mkdir $b5dir
set fh [open [file join $b5dir dd5.sym] w]
puts $fh "v \{xschem version=3.4.4 file_version=1.2\}"
puts $fh "G \{\}"
puts $fh "K \{type=subcircuit"
puts $fh "format=\"@name @pinlist @symname\""
puts $fh "template=\"name=x1\""
puts $fh "\}"
puts $fh "V \{\}"
puts $fh "S \{\}"
puts $fh "E \{\}"
puts $fh "L 4 -20 -20 20 -20 \{\}"
close $fh
foreach {nm nwire} {dd5.sch 2 schematic.sch 1} {
  set fh [open [file join $b5dir $nm] w]
  puts $fh "v \{xschem version=3.4.4 file_version=1.2\}"
  puts $fh "G \{\}"
  puts $fh "V \{\}"
  puts $fh "S \{\}"
  puts $fh "E \{\}"
  for {set i 0} {$i < $nwire} {incr i} { puts $fh "N 0 [expr {$i*100}] 100 [expr {$i*100}] \{\}" }
  close $fh
}
set fh [open [file join $b5dir ddtop.sch] w]
puts $fh "v \{xschem version=3.4.4 file_version=1.2\}"
puts $fh "G \{\}"
puts $fh "V \{\}"
puts $fh "S \{\}"
puts $fh "E \{\}"
puts $fh "C \{dd5.sym\} 0 0 0 0 \{name=xz"
puts $fh "schematic=schematic.sch\}"
close $fh
lappend ::pathlist $b5dir
set ::hi_descend_view_path {}
xschem load [file join $b5dir ddtop.sch]
xschem unselect_all
set b5rows [dd_enum xz]
set b5 {}
if {[lsearch -exact {NOPROC} $b5rows] < 0} {
  foreach r $b5rows {
    if {[lindex $r 1] eq {schematic}} { lappend b5 [list [lindex $r 0] [file tail [lindex $r 2]]] }
  }
  set b5 [lsort $b5]
} else { set b5 $b5rows }
check {B5 a copy bound to a file that happens to be called schematic.sch still\
 gets two distinct choices -- the cell's own dd5.sch and the bound one -- so the\
 chooser cannot pick the wrong one by name} \
  $b5 {{instance schematic.sch} {schematic dd5.sch}}

# B6. The no-binding case must not gain or lose a row.
dd_reload
check {B6 for copy x1, which has no per-copy setting, the choices are exactly the\
 two they have always been} \
  [dd_enum x1] \
  [list [list schematic schematic [file join $::repo xschem_library inst_sch_select comp3.sch]] \
        [list symbol    symbol    [file join $::repo xschem_library inst_sch_select comp3.sym]]]

# B7. LOOKING AT THE LIST MUST NOT CHANGE ANYTHING.
#
# ⚠ THE ONLY ROW THAT CAN SEE THIS, AND A SABOTAGE PASS PROVED THE OTHERS CANNOT.
# Working out which file a copy opens goes through the INSTANCE form of the
# resolver, and that call READS AND CLEARS the one-shot view override -- the
# variable the E-key dialog arms to say "open THIS view". So merely building the
# list of choices for a copy used to throw away a view another caller had already
# asked for. hi_descend_inst_defsch saves and restores it for exactly that
# reason; delete those two lines and this suite, test_hi_descend and test_ase_view
# all stay fully green, because nothing else anywhere asks the question.
set b7pick [file join $::repo xschem_library inst_sch_select comp3_empty.sch]
dd_reload
set ::hi_descend_view_path $b7pick
set b7rows [dd_enum x2]
set b7kept $::hi_descend_view_path
set b7go   [dd_ans {xschem descend -inst x2}]
set b7land [list $b7go [dd_sheet] [dd_n]]
set ::hi_descend_view_path {}
check {B7 after the list of schematics has been looked at, the view the person\
 picked is still the one that opens -- comp3_empty.sch with its 7 copies, not\
 comp3_parax.sch with 8} \
  [list [expr {$b7kept eq $b7pick ? 1 : 0}] {*}$b7land] {1 1 comp3_empty.sch 7}

# ===========================================================================
# SECTION C -- the fallback must not throw away a binding that DOES resolve
# ===========================================================================
# The obvious repair for FAULT A is to let the verb fall back. Done carelessly it
# turns every headless descend into a VALID per-copy binding into a descend into
# the cell's own schematic instead -- FAULT B arriving through the other door.
# These are the only two rows in the file that can see that.

dd_reload
set c1 [dd_ans {xschem descend -fallback -inst x2}]
check {C1 asking for the fallback does NOT throw away a per-copy setting that\
 names a real file -- copy x2 still opens comp3_parax.sch with 8 copies} \
  [list $c1 [dd_sheet] [dd_n]] {1 comp3_parax.sch 8}

dd_reload
set c2 [dd_ans {xschem descend -fallback -inst x5}]
check {C2 the same for copy x5, which still opens comp3_empty.sch with 7 copies} \
  [list $c2 [dd_sheet] [dd_n]] {1 comp3_empty.sch 7}

# ===========================================================================
# SECTION D -- read-only browse mode, the third disagreement
# ===========================================================================

proc dd_ro_case {roval script} {
  set ::descend_readonly $roval
  dd_reload
  set rc [dd_ans $script]
  return [list $rc [xschem get readonly]]
}

check {D1 in read-only browse mode a failed descend leaves the page read-only, so\
 an accidental save cannot create a junk file named after a file that is missing} \
  [dd_ro_case 1 {xschem descend -inst x3}] {0 1}

set d2 [dd_ro_case 1 {xschem descend -fallback -inst x3}]
check {D2 in read-only browse mode the fallback opens the cell's own comp3.sch and\
 it too is read-only} \
  [list {*}$d2 [dd_sheet]] {1 1 comp3.sch}

set d3a [dd_ro_case 0 {xschem descend -inst x3}]
set d3b [dd_ro_case 0 {xschem descend -fallback -inst x3}]
check {D3 with read-only browse mode off, neither the refusal nor the fallback\
 forces read-only on -- the setting is still the only thing that turns it on} \
  [list {*}$d3a {*}$d3b] {0 0 1 0}
set ::descend_readonly 0

# ===========================================================================
# SECTION E -- STRUCTURAL. Guards that no behaviour on this arm can reach.
# ===========================================================================

# E1. The verb's opt-in flag, and the fact that the two fallback arguments move
# together. No behavioural row can tell an opt-in flag from a hardcoded 1.
set e1b [dd_branch $SRC_SCHED {else if\(!strcmp\(argv\[1\], "descend"\)\)}]
check {E1 STRUCTURAL the descend command takes one opt-in fallback flag, and all\
 three of its forms pass it through instead of a hardcoded number} \
  [list [dd_count $e1b {-fallback}] \
        [dd_count $e1b {descend_schematic(}] \
        [dd_count $e1b {, fallback, fallback,}] \
        [dd_count $e1b {, 0, 0,}] \
        [dd_count $e1b {, 1, 1,}]] \
  {1 3 3 0 0}

# E2. The existence test must not sit behind the display test. Without this, a
# headless descend into a copy whose binding IS there opens the wrong file.
set e2b [dd_cfun $SRC_ACT {^void get_sch_from_sym\(}]
check {E2 STRUCTURAL whether the bound file is actually there is checked whether\
 or not there is a screen to ask a question on} \
  [list [dd_has $e2b {if(fallback && !is_gen && filename[0])}] \
        [dd_has $e2b {if(has_x && fallback}]] \
  {1 0}

# E3. RULING D5-4: a user-facing sentence is minted in ONE place and rendered by
# callers. Definition once, calls twice, and the old cryptic wording gone.
check {E3 STRUCTURAL the sentence about a missing schematic file is written in one\
 place and used by both the question and the status line} \
  [list [dd_count $SRC_ACT {static void descend_view_missing_sentence(}] \
        [dd_count $SRC_ACT {descend_view_missing_sentence(}] \
        [dd_count $e2b {does not exist}]] \
  {1 3 0}

# E4. Answering No to the question must leave the person where they are. The
# question is only asked when there is a screen, and a canvas event cannot be
# driven under --nogui at all, so this row is its ONLY witness.
set e4b [dd_cfun $SRC_ACT {^int descend_schematic\(}]
check {E4 STRUCTURAL answering No to the missing-file question records its own\
 reason and opens nothing, and the later no-schematic reason cannot overwrite it} \
  [list [dd_count $e2b {"view-missing"}] \
        [expr {[dd_count $e4b {descend_err[0]}] >= 1 ? 1 : 0}]] \
  {1 1}

# E5. Reading instance number minus one. Out of bounds reads do not reliably
# fault, so nothing behavioural can see this.
# The anchor tolerates the space this dispatcher writes between the two closing
# parentheses -- `"get_sch_from_sym") )` -- which 24 of scheduler.c's branches use.
# Without it dd_branch found nothing and the row failed for a reason that had
# nothing to do with the guard it is about. The assertion itself is unchanged: at
# HEAD, with the anchor matching, the branch still had no instance-number test.
set e5b [dd_branch $SRC_SCHED {else if\(!strcmp\(argv\[1\], "get_sch_from_sym"\) *\)}]
set e5i [string first {inst >= 0} $e5b]
set e5j [string first {xctx->inst[inst].ptr} $e5b]
check {E5 STRUCTURAL the symbol form of the view resolver checks the instance\
 number before it uses it as an index} \
  [list [expr {$e5i >= 0 ? 1 : 0}] [expr {($e5i >= 0 && $e5j >= 0 && $e5i < $e5j) ? 1 : 0}]] \
  {1 1}

# E6. Seven controls ask for the fallback; five scripted walks deliberately do
# not. Asserted by COUNT so a later crew cannot quietly opt one of the five in
# without meeting the measurement issue 1233 asks for.
check {E6 STRUCTURAL every control a person can press asks for the fallback, and\
 the five scripted walks that must keep agreeing with the netlist do not} \
  [list [dd_count $SRC_TCL  {xschem descend -fallback}] \
        [dd_count $SRC_CAD  {xschem descend -fallback}] \
        [dd_count $SRC_CSV  {xschem descend -fallback}] \
        [dd_count $SRC_WAVE {descend -fallback}] \
        [dd_count $SRC_SKY  {descend -fallback}] \
        [dd_count $SRC_IHP  {descend -fallback}] \
        [dd_count $SRC_TCL  {xschem descend 1 6}] \
        [dd_count $SRC_TCL  {xschem descend $instnum}]] \
  {3 3 1 0 0 0 1 1}

# E7. The literal deviation from this tool's own spec, doc/claude/specs/hi_descend.md
# lines 132-134: the list of choices must be built with the INSTANCE form of the
# resolver, which is the only form that can see a per-copy setting.
set e7enum [dd_tclproc $SRC_TCL hi_descend_enum_views]
set e7help [dd_tclproc $SRC_TCL hi_descend_inst_defsch]
check {E7 STRUCTURAL the list of choices is built with the form of the resolver\
 that can see a per-copy setting, and still adds the cell's own schematic beside it} \
  [list [expr {[dd_has $e7enum {get_sch_from_sym $instname}] || \
               [dd_has $e7enum {hi_descend_inst_defsch}] ? 1 : 0}] \
        [dd_has $e7help {get_sch_from_sym $instname}] \
        [dd_count $e7enum {get_sch_from_sym -1 $sym}]] \
  {1 1 1}

# E8. The refactor that lets the question NAME the file it is offering.
check {E8 STRUCTURAL working out the cell's own schematic is one helper, used by\
 both the question and the fallback itself} \
  [list [dd_count $SRC_ACT {static void get_base_sch_from_sym(}] \
        [dd_count $SRC_ACT {get_base_sch_from_sym(}]] \
  {1 3}

# ===========================================================================
# SECTION F -- the workarounds this fix retires
# ===========================================================================
# A workaround left standing behind a fix is how the next reader concludes the
# fix does not work.

set f1b  [dd_tclproc $SRC_TOPT  n_dsc_base]
set f1bs [dd_tclproc $SRC_TOPTS n_dsc_base]
check {F1 STRUCTURAL the operating-point tier suite no longer hand-arms the\
 one-shot override to get past this defect, it just asks for the fallback} \
  [list [dd_has $f1bs {xschem descend -fallback}] [dd_has $f1b {hi_descend_view_path}]] \
  {1 0}

set f2 {}
foreach s {actions.c:4139 actions.c:4145 actions.c:4176 {unreachable from the verb}} {
  lappend f2 [dd_count $SRC_OPANN $s]
}
foreach s {actions.c:4139 actions.c:4145 actions.c:4176} {
  lappend f2 [dd_count $SRC_TOPANN $s]
}
check {F2 STRUCTURAL the code comments no longer quote line numbers that moved by\
 about eleven hundred lines, nor claim a fallback is unreachable once it is not} \
  $f2 {0 0 0 0 0 0 0}

# --- teardown ---------------------------------------------------------------
set ::descend_readonly 0
set ::hi_descend_view_path {}

# --- verdict ----------------------------------------------------------------
# The DUAL banner is required by tests/run_regression.tcl's hcases list, which
# this file is registered in. banner_complete needs a WHOLE-LINE "OVERALL: ok"
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
