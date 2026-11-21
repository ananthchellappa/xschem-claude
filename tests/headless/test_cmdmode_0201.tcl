# cmdmode — the generic command-mode suspend/resume contract, on its own.
# doc/claude/issues/0201-no-command-suspend-resume-contract.md
#
# It exercises src/cmdmode.tcl against STUB modes, so nothing here depends on ASE, the
# waveform viewer or a schematic — which is the point of D1 (the contract must be usable
# by anything, not be ASE glue). Legs CR1 to CR7 are pure Tcl: no C, no canvas, no Tk.
# Leg CR8 is about clone_canvas_bindings (src/xschem.tcl), which asks
# cmdmode::pristine for each script it copies: it needs Tk and that proc, runs on a
# display, and says SKIPPED anywhere else.
#
# Legs (CR*):
#   CR1a-CR1c  register / registered / unregister
#   CR1d-CR1f  suspend_all releases only the LIVE modes, and reports how many
#   CR1g-CR1i  resume_all puts back exactly those, LIFO, with the canvas argument
#   CR1j-CR1l  the D6 latch: double suspend is a no-op, stray resume is a no-op
#   CR1m-CR1n  resume_all's default canvas, and an explicit one
#   CR2a-CR2c  a THROWING suspend arm does not strand the others and is not resumed
#   CR2d-CR2e  a THROWING resume arm does not stop the ones after it
#   CR2f       unregister while suspended: the mode is not resumed by a dead callback
#   CR3a-CR3c  rehome: re-homes live modes, no-op while a suspend is in flight
#   CR4        register with and without a held callback; the two signatures
#   CR5        pristine: the walk down through what the modes declare they hold
#   CR6        the order suspend_all releases a stack in (the top first, read from what
#              the modes declare they hold) and resume_all puts it back in
#   CR7        every proc of the namespace answers (on the --nogui arm: with no Tk);
#              with no Tk the spelling proc and clone_canvas_bindings answer too
#   CR8        clone_canvas_bindings between real canvases, and through the real
#              new-window door, while a stub mode holds slots of the source canvas
#
# Run it (from anywhere; a throwaway HOME, a private display, a timeout):
#   tests/headless/run_suites.sh --nogui test_cmdmode_0201      the pure-Tcl legs
#   tests/headless/run_suites.sh test_cmdmode_0201              the same plus CR8
# Standalone repro of the pure-Tcl legs from the repo ROOT (either form):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_cmdmode_0201.tcl
#   tclsh tests/headless/test_cmdmode_0201.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

# The stall bound. Leg CR8 creates widgets and a window and reaches the Tk event loop;
# scratch.tcl's watchdog ends the process if a wait there never returns.
source [file join [file dirname [file normalize [info script]]] scratch.tcl]

# Source the file under test ONLY if the binary has not already loaded it. Re-sourcing
# would re-initialise the namespace variables and silently drop ASE's real registration,
# which the DISPLAY-gated sibling (test_cmdmode_descend_0201.tcl) then depends on.
# RED-first: before the wiring lands, the procs are simply undefined and every leg errors.
if {[info commands cmdmode::register] eq {}} {
  set here [file dirname [file normalize [info script]]]
  set f [file join $here .. .. src cmdmode.tcl]
  if {[file exists $f]} { source $f }
}
proc val {body} { if {[catch {uplevel 1 $body} r]} { return "ERR: $r" } ; return $r }

# --- stub modes -----------------------------------------------------------------------
# Each records what it was told, so the legs can assert on ORDER and on ARGUMENTS, not
# just on counts. `live` is the suspend arm's return value: the contract's "was there
# anything to release?".
set ::trace {}
proc mk {name live} {
  proc sus_$name {} "lappend ::trace sus:$name; return $live"
  proc res_$name {cv} "lappend ::trace res:$name:\$cv; return 1"
}
mk a 1
mk b 0        ;# registered but not live -> must be suspended-asked, never resumed
mk c 1
proc sus_boom {}   { lappend ::trace sus:boom; error "suspend exploded" }
proc res_boom {cv} { lappend ::trace res:boom:$cv; return 1 }
proc sus_ok    {}  { lappend ::trace sus:ok; return 1 }
proc res_boom2 {cv} { lappend ::trace res:boom2:$cv; error "resume exploded" }

proc clear_all {} {
  foreach k [cmdmode::registered] { cmdmode::unregister $k }
  catch {cmdmode::resume_all}      ;# drop any latch a previous leg left standing
  set ::trace {}
}

# --- stub modes that declare what they hold (legs CR4 on) ------------------------------
# A held callback answers groups of four words: canvas, sequence, the script the mode
# bound there, the script that slot held before. `held_of` answers the rows a leg gave
# its mode and notes each time it is asked, so a leg can assert HOW OFTEN the walk asked.
# A registration that raises is noted in ::hfail rather than thrown, so one refused call
# costs the rows that needed it and not every row after it.
set ::hasked {}
set ::hfail  {}
proc held_of {name} { lappend ::hasked $name ; return $::hrows($name) }
proc held_boom {}   { lappend ::hasked boom ; error "held exploded" }
proc held_level {}  { set ::held_level [info level] ; return {.c <s> MODE PRED} }
proc hreg {name held_cb} {
  if {[catch {cmdmode::register $name sus_a res_a $held_cb} e]} { lappend ::hfail "$name: $e" }
}
proc hmode {name rows} {
  set ::hrows($name) $rows
  mk $name 1
  if {[catch {cmdmode::register $name sus_$name res_$name [list held_of $name]} e]} {
    lappend ::hfail "$name: $e"
  }
}
proc hclear {} { clear_all ; set ::hasked {} ; array unset ::hrows }
# A stub mode whose held callback also writes itself into ::trace, for the legs about
# what was asked before what was released.
proc held_tr {name} { lappend ::trace held:$name ; return $::hrows($name) }
proc tmode {name rows} {
  set ::hrows($name) $rows
  mk $name 1
  if {[catch {cmdmode::register $name sus_$name res_$name [list held_tr $name]} e]} {
    lappend ::hfail "$name: $e"
  }
}
# cmdmode::release_order, and one suspend_all + resume_all round on canvas .x1.drw read
# as {released-in-this-order resumed-in-this-order}: the mode names only.
proc ro {} { return [val {cmdmode::release_order}] }
proc round {} {
  set ::trace {}
  if {[catch {cmdmode::suspend_all ; cmdmode::resume_all .x1.drw} e]} { return "ERR: $e" }
  set sus {} ; set res {}
  foreach t $::trace {
    lassign [split $t :] what name
    if {$what eq {sus}} { lappend sus $name } elseif {$what eq {res}} { lappend res $name }
  }
  return [list $sus $res]
}
# cmdmode::pristine, with a raise turned into a value no leg expects
proc pr {args} { return [val [linsert $args 0 cmdmode::pristine]] }

# Stand-ins for the caller's spelling prefix. The first maps the two spellings these
# legs use onto the one Tk lists; the second raises; the third takes a leading word.
proc canon_fake {s} {
  set ::canon_level [info level]
  return [string map {ButtonPress- Button- <Escape> <Key-Escape>} $s]
}
proc canon_boom {s}     { error "no spelling" }
proc canon_pre  {tag s} { return [canon_fake $s] }

# --- leg CR8's canvases ----------------------------------------------------------------
# The canvases are never mapped, so no pointer or key event reaches them. The scripts
# bound there are comments, so the one kind Tk does run (a <Destroy> script, when the
# canvases go) does nothing.
proc sc {name} { return "# cm0201 $name" }
proc cb_fresh {} {
  hclear
  catch {destroy .cm0201}
  toplevel .cm0201
  wm withdraw .cm0201
  canvas .cm0201.src
  canvas .cm0201.dst
}
proc cb_clone {} { return [val {clone_canvas_bindings .cm0201.src .cm0201.dst}] }
proc cb_slots {cv seqs} { set o {} ; foreach s $seqs { lappend o [bind $cv $s] } ; return $o }
# the canvas of every additional schematic window that exists now
proc cb_canvases {} {
  set o {}
  foreach w [winfo children .] { if {[winfo exists $w.drw]} { lappend o $w.drw } }
  return $o
}

if {[catch {

# --- CR1a-CR1c: registration ----------------------------------------------------------
clear_all
check "CR1a registered is empty to start" [cmdmode::registered] {}
cmdmode::register a sus_a res_a
cmdmode::register b sus_b res_b
check "CR1b register keeps insertion order" [cmdmode::registered] {a b}
cmdmode::unregister b
check "CR1c unregister drops just that one" [cmdmode::registered] {a}
check_true "CR1c2 an empty key is refused" [string match "ERR:*" [val {cmdmode::register {} x y}]]
check_true "CR1c3 a missing resume cb is refused" [string match "ERR:*" [val {cmdmode::register z sus_a {}}]]

# --- CR1d-CR1i: the round trip --------------------------------------------------------
clear_all
cmdmode::register a sus_a res_a
cmdmode::register b sus_b res_b        ;# not live
cmdmode::register c sus_c res_c
check "CR1d suspend_all counts only the LIVE modes" [cmdmode::suspend_all] 2
check "CR1e every registered mode was ASKED, in registration order" $::trace {sus:a sus:b sus:c}
check "CR1f the pending list is the live ones, newest first" [cmdmode::pending] {c a}
set ::trace {}
check "CR1g resume_all resumes exactly those" [cmdmode::resume_all .x1.drw] 2
check "CR1h resume is LIFO and carries the canvas" $::trace {res:c:.x1.drw res:a:.x1.drw}
check "CR1i the not-live mode was never resumed" [string match "*res:b*" $::trace] 0

# --- CR1j-CR1l: the D6 latch ----------------------------------------------------------
clear_all
cmdmode::register a sus_a res_a
check "CR1j not suspended to start" [cmdmode::is_suspended] 0
check "CR1k1 first suspend releases 1" [cmdmode::suspend_all] 1
check "CR1k2 the latch is up" [cmdmode::is_suspended] 1
set ::trace {}
check "CR1k3 a second suspend is a no-op" [cmdmode::suspend_all] 0
check "CR1k4 and it did not call the arm again" $::trace {}
check "CR1k5 one resume clears it" [cmdmode::resume_all] 1
check "CR1k6 the latch is down" [cmdmode::is_suspended] 0
set ::trace {}
check "CR1l a second resume is a no-op" [cmdmode::resume_all] 0
check "CR1l2 and it did not call the arm again" $::trace {}

# --- CR1m-CR1n: the canvas argument ---------------------------------------------------
clear_all
cmdmode::register a sus_a res_a
cmdmode::suspend_all
set ::trace {}
cmdmode::resume_all
# With no argument resume_all reads `xschem get current_win_path` itself -- under the
# binary that is a real canvas path, under bare tclsh the command does not exist and the
# catch leaves it empty. Either way the arm is CALLED with exactly one argument.
check_true "CR1m default canvas: the arm still ran with one argument" \
  [regexp {^res:a:} [lindex $::trace 0]]
check "CR1n2 exactly one resume happened" [llength $::trace] 1

# --- CR2a-CR2c: a throwing suspend arm ------------------------------------------------
clear_all
cmdmode::register boom sus_boom res_boom
cmdmode::register a    sus_a    res_a
check "CR2a a throwing suspend does not abort the sweep" [cmdmode::suspend_all] 1
check "CR2b the modes after it were still asked" $::trace {sus:boom sus:a}
check "CR2c the thrower is NOT queued for resume" [cmdmode::pending] {a}
set ::trace {}
cmdmode::resume_all .drw
check "CR2c2 and it is not resumed -- a half-released seize stays down" $::trace {res:a:.drw}

# --- CR2d-CR2e: a throwing resume arm -------------------------------------------------
clear_all
cmdmode::register boom2 sus_ok  res_boom2
cmdmode::register a     sus_a   res_a
cmdmode::suspend_all
set ::trace {}
check "CR2d a throwing resume is not counted, the rest still are" [cmdmode::resume_all .drw] 1
check "CR2e the arms after the thrower still ran (LIFO: a, then boom2)" \
  $::trace {res:a:.drw res:boom2:.drw}
check "CR2e2 the latch still came down" [cmdmode::is_suspended] 0

# --- CR2f: unregistered while suspended -----------------------------------------------
clear_all
cmdmode::register a sus_a res_a
cmdmode::register c sus_c res_c
cmdmode::suspend_all
cmdmode::unregister a
set ::trace {}
check "CR2f resume skips the mode that was unregistered mid-flight" [cmdmode::resume_all .drw] 1
check "CR2f2 and it called only the survivor" $::trace {res:c:.drw}

# --- CR3a-CR3c: rehome ----------------------------------------------------------------
clear_all
cmdmode::register a sus_a res_a
set ::trace {}
check "CR3a rehome re-homes the live mode onto the new canvas" [cmdmode::rehome .x2.drw] 1
check "CR3b it is a suspend+resume pair, not a bare rebind" $::trace {sus:a res:a:.x2.drw}
check "CR3b2 rehome leaves no latch standing" [cmdmode::is_suspended] 0
cmdmode::suspend_all
set ::trace {}
check "CR3c rehome is a no-op while a suspend is in flight" [cmdmode::rehome .x3.drw] 0
check "CR3c2 it did not touch the arms" $::trace {}
check "CR3c3 and the pending suspend is still pending" [cmdmode::is_suspended] 1
cmdmode::resume_all

# --- CR4: register with and without a held callback -------------------------------------
hclear
check "CR4a three arguments still register a mode" [val {cmdmode::register a sus_a res_a}] a
check "CR4b a fourth argument, the held callback, is accepted" \
  [val {cmdmode::register h sus_a res_a {held_of h}}] h
check "CR4c both are registered, in order" [cmdmode::registered] {a h}
check_true "CR4d a fifth argument is refused" \
  [string match "ERR: wrong # args*" [val {cmdmode::register z sus_a res_a {held_of z} extra}]]
check "CR4e register's formals as the interpreter holds them: the held callback is optional, empty by default" \
  [val {list [info args cmdmode::register] [info default cmdmode::register held_cb cm_d] $cm_d}] \
  {{key suspend_cb resume_cb held_cb} 1 {}}
check "CR4f pristine's formals as the interpreter holds them: the spelling prefix is optional, empty by default" \
  [val {list [info args cmdmode::pristine] [info default cmdmode::pristine canon cm_d] $cm_d}] \
  {{canvas sequence script canon} 1 {}}
hclear
hmode h {.c <s> MODE PRED}
set before [pr .c <s> MODE]
cmdmode::register h sus_h res_h
set ::hasked {}
check "CR4g a key registered again without a held callback is no longer asked what it holds" \
  [list $before [pr .c <s> MODE] $::hasked] {PRED MODE {}}

# --- CR5: pristine, the walk down through what the modes hold ---------------------------
hclear
set r0 [pr .c <s> USER]                       ;# nothing is registered
cmdmode::register a sus_a res_a
set r1 [pr .c <s> USER]                       ;# one mode, which declares nothing
# h holds another script in the slot asked about, and USER in another slot and on
# another canvas
hmode h {.c <s> MODE PRED   .c <t> USER PRED2   .d <s> USER PRED3}
set r2 [pr .c <s> USER]
check "CR5a a script no mode holds in that slot is answered unchanged" [list $r0 $r1 $r2] {USER USER USER}
check "CR5a2 and the same groups do step when canvas, sequence and script all match" \
  [list [pr .c <s> MODE] [pr .c <t> USER] [pr .d <s> USER]] {PRED PRED2 PRED3}

hclear
hmode h {.c <s> MODE PRED   .c <t> MODE2 {}}
check "CR5b one mode: the answer is the predecessor of that slot" [pr .c <s> MODE] PRED
check "CR5b2 a slot held over nothing answers the empty string" [pr .c <t> MODE2] {}

foreach {tag order} {c {low top} c2 {top low}} {
  hclear
  set grp(low) {.c <s> LOW PRED}
  set grp(top) {.c <s> TOP LOW}
  foreach m $order { hmode $m $grp($m) }
  check "CR5$tag two modes stacked on one slot, registered $order: the walk steps through both" \
    [pr .c <s> TOP] PRED
}
# Modes that bind one and the same script in a slot (a one-word script on a release,
# say): a mode seized over another then declares that same word as its predecessor.
foreach {tag order} {c3 {m1 m2 m3} c4 {m3 m2 m1}} {
  hclear
  set grp(m1) {.c <r> break PRED}
  set grp(m2) {.c <r> break break}
  set grp(m3) {.c <r> break break}
  foreach m $order { hmode $m $grp($m) }
  check "CR5$tag three modes holding one and the same script in a slot, registered $order: what the lowest took" \
    [pr .c <r> break] PRED
}

hclear
hreg boom held_boom
set alone [pr .c <s> MODE]
hmode h {.c <s> MODE PRED}
check "CR5d a held callback that raises is passed over, and a mode behind it is still read" \
  [list $alone [pr .c <s> MODE]] {MODE PRED}
check_true "CR5d2 and the raising callback really was asked" [expr {[lsearch -exact $::hasked boom] >= 0}]

set got {}
# the third answer is one open brace, which no list command accepts
foreach {m answer} [list three {.c <s> MODE} five {.c <s> MODE PRED extra} nolist [format %c 123]] {
  hclear
  set ::hrows($m) $answer
  hreg $m [list held_of $m]
  lappend got [pr .c <s> MODE]
  hmode h {.c <s> MODE PRED}
  lappend got [pr .c <s> MODE]
}
check "CR5e an answer of three words, of five words, or one that is no list: each passed over, the next mode read" \
  $got {MODE PRED MODE PRED MODE PRED}

hclear
hmode h {.c <s> MODE MODE}
check "CR5f a group whose predecessor is its own script is not stepped: one pass, the script stands" \
  [list [pr .c <s> MODE] $::hasked] {MODE h}
hmode low {.c <s> MODE PRED}
check "CR5f2 and it does not hide another mode's group for the same script" [pr .c <s> MODE] PRED

hclear
hmode ring {.c <s> X Y   .c <s> Y X}
set ans [pr .c <s> X]
set steps [llength $::hasked]
check "CR5g a ring of two groups: the walk stops after eight steps" $steps 8
check_true "CR5g2 and answers one of the ring's two scripts" [expr {$ans in {X Y}}]
hclear
hmode ra {.c <s> X Y}
hmode rb {.c <s> Y X}
set ans [pr .c <s> X]
check_true "CR5g3 a ring across two modes stops as well, on one of its scripts" \
  [expr {$ans in {X Y} && [llength $::hasked] > 0 && [llength $::hasked] <= 16}]

# a real stack as deep as the ring walk was long
hclear
for {set i $steps} {$i >= 1} {incr i -1} { hmode d$i [list .c <s> S$i S[expr {$i - 1}]] }
check "CR5h a stack of as many modes as that walk took steps is stepped through to the bottom" \
  [list [expr {$steps > 1}] [pr .c <s> S$steps]] {1 S0}

hclear
hmode h {.c <s> MODE PRED}
set first [pr .c <s> MODE]
cmdmode::unregister h
check "CR5i a mode unregistered between two calls is no longer read" [list $first [pr .c <s> MODE]] {PRED MODE}

hclear
hmode h {.gone.drw <s> MODE PRED}
check "CR5j a held list may name a canvas that does not exist: the name is compared as a string" \
  [list [pr .c <s> MODE] [pr .gone.drw <s> MODE]] {MODE PRED}

hclear
hmode h {.c <ButtonPress-1> MODE PRED   .c <Key-Escape> ESC {}}
check "CR5k without a spelling prefix two spellings of one sequence are two slots" \
  [list [pr .c <Button-1> MODE] [pr .c <ButtonPress-1> MODE]] {MODE PRED}
check "CR5k2 with one, the mode's spelling and the asker's both go through it" \
  [list [pr .c <Button-1> MODE canon_fake] [pr .c <ButtonPress-1> MODE canon_fake] \
        [pr .c <Escape> ESC canon_fake]] {PRED PRED {}}
check "CR5k3 the prefix does not merge two different slots" [pr .c <ButtonRelease-1> MODE canon_fake] MODE
set ::canon_level {}
pr .c <Button-1> MODE canon_fake
check "CR5k4 the prefix is called at global level" $::canon_level 1
hclear
hmode h {.c <Button-1> MODE PRED}
check "CR5k5 the same when the mode declares the listed spelling and the asker the other" \
  [pr .c <ButtonPress-1> MODE canon_fake] PRED
check "CR5k6 a prefix that raises leaves both spellings as they were given" \
  [list [pr .c <ButtonPress-1> MODE canon_boom] [pr .c <Button-1> MODE canon_boom]] {MODE PRED}
check "CR5k7 the prefix may carry leading words" [pr .c <ButtonPress-1> MODE {canon_pre x}] PRED

hclear
hmode h [list .c <s> "mode_click; break" PRED]
check "CR5l the script is compared as a string: a trailing blank or newline makes it another script" \
  [list [pr .c <s> "mode_click; break "] [pr .c <s> "mode_click; break\n"] [pr .c <s> "mode_click; break"]] \
  [list "mode_click; break " "mode_click; break\n" PRED]

hclear
hmode h {.c <ButtonPress-1> MODE {}   .c <Double-Button-1> MODE EDIT}
check "CR5m one script held in two slots: each slot steps to its own predecessor" \
  [list [pr .c <ButtonPress-1> MODE] [pr .c <Double-Button-1> MODE] \
        [pr .c <Button-1> MODE canon_fake] [pr .c <Double-Button-1> MODE canon_fake]] {{} EDIT {} EDIT}

hclear
hreg lv held_level
set ::held_level {}
check "CR5n the held callback is called with no arguments, at global level" \
  [list [pr .c <s> MODE] $::held_level] {PRED 1}

hclear
hmode idle {}
hmode h {.c <s> MODE PRED}
check "CR5o a mode that holds nothing now answers an empty list and is passed by" \
  [list [pr .c <s> MODE] [lsort -unique $::hasked]] {PRED {h idle}}

# --- CR6: the order a stack is released in, and put back in ------------------------------
# suspend_all asks every mode what it holds, once, before it releases any, and releases
# a mode before every mode it is seized over: a mode that names, as what a slot of its
# held before, a script another mode holds on the same canvas. resume_all goes the
# other way round and asks nothing.
hclear
hmode h {.c <s> MODE PRED}
set ::hrows(b) {}
mk b 0
if {[catch {cmdmode::register b sus_b res_b {held_of b}} e]} { lappend ::hfail "b: $e" }
set ::trace {}
check "CR6a suspend_all still calls each suspend callback and counts the live modes" \
  [list [cmdmode::suspend_all] $::trace] {1 {sus:h sus:b}}
set asked_suspend $::hasked ; set ::hasked {}
set ::trace {}
check "CR6b resume_all still calls the resume callback of those, with the canvas" \
  [list [cmdmode::resume_all .x1.drw] $::trace] {1 res:h:.x1.drw}
set asked_resume $::hasked ; set ::hasked {}
set ::trace {}
check "CR6c rehome is still that pair" [list [cmdmode::rehome .x2.drw] $::trace] {1 {sus:h sus:b res:h:.x2.drw}}
check "CR6d suspend_all asks each mode once what it holds, resume_all asks none, and rehome asks as its suspend does" \
  [list $asked_suspend $asked_resume $::hasked] {{h b} {} {h b}}

hclear
tmode low {.c <p> LOWP {}}
tmode top {.c <p> TOPP LOWP}
set ::trace {}
cmdmode::suspend_all
check "CR6e every mode is asked what it holds before the first one is released" \
  $::trace {held:low held:top sus:top sus:low}
cmdmode::resume_all .x1.drw

hclear
hmode low {.c <p> LOWP {}}
hmode top {.c <p> TOPP LOWP}
check "CR6f a mode seized over one registered before it: released first, put back last" \
  [list [ro] [round]] {{top low} {{top low} {low top}}}
cmdmode::suspend_all
check "CR6f2 and the pending list is the order they go back in" [cmdmode::pending] {low top}
cmdmode::resume_all .x1.drw
set ::trace {}
check "CR6f3 rehome moves that stack top first off, bottom first on" \
  [list [cmdmode::rehome .x2.drw] $::trace] {2 {sus:top sus:low res:low:.x2.drw res:top:.x2.drw}}

hclear
hmode top {.c <p> TOPP LOWP}
hmode low {.c <p> LOWP {}}
check "CR6g the same stack with the upper mode registered first: the same order" \
  [list [ro] [round]] {{top low} {{top low} {low top}}}

hclear
for {set i 1} {$i <= 3} {incr i} { hmode d$i [list .c <p> S$i [expr {$i > 1 ? "S[expr {$i - 1}]" : {}}]] }
check "CR6h three modes stacked, the lowest registered first: released from the top down, put back from the bottom up" \
  [list [ro] [round]] {{d3 d2 d1} {{d3 d2 d1} {d1 d2 d3}}}

hclear
hmode low {.c <p> LOWP {}}
mk plain 1
cmdmode::register plain sus_plain res_plain
set after_low [list [ro] [round]]
# The same mode registered BETWEEN the two of a stack. It is under nothing by what is
# declared, so it does not wait; the lower mode waits for the mode seized over it.
hclear
hmode low {.c <p> LOWP {}}
mk plain 1
cmdmode::register plain sus_plain res_plain
hmode top {.c <p> TOPP LOWP}
check "CR6i a mode with no held callback: registered after the mode it would be over, nothing is known and the two go in registration order; registered between the two of a stack, it goes ahead of the lower mode, which waits for the upper one" \
  [list $after_low [list [ro] [round]]] \
  {{{low plain} {{low plain} {plain low}}} {{plain top low} {{plain top low} {low top plain}}}}
hclear
mk plain 1
cmdmode::register plain sus_plain res_plain
hmode top {.c <p> TOPP PLAINP}
check "CR6i2 and registered before a mode that names a script nobody declares: registration order as well" \
  [list [ro] [round]] {{plain top} {{plain top} {top plain}}}

hclear
hmode low  {.c <p> LOWP {}}
hmode side {.d <p> SIDEP {}}
hmode top  {.c <p> TOPP LOWP}
check "CR6j a third mode on another canvas, registered between the two of a stack: the lower mode waits for the upper one, the third goes ahead of both" \
  [list [ro] [round]] {{side top low} {{side top low} {low top side}}}

hclear
hmode low {.c <ButtonPress-1> LOWP {}}
hmode top {.c <Button-1> TOPP LOWP}
check "CR6k the two modes spell the slot differently: the order is read from the canvas and the scripts alone" \
  [ro] {top low}

hclear
hmode low {.c <p> LOWP {}}
hmode top {.d <p> TOPP LOWP}
check "CR6l the same pair of scripts on two different canvases is no stack: registration order" [ro] {low top}

# One word bound by both modes (a release that is swallowed, say). The lower mode took a
# slot that already held that word, and the upper mode binds the same word in a slot of
# its own: by that word alone each would be over the other.
hclear
hmode low {.c <p> LOWP {}     .c <r> break {}      .c <d> LOWP break}
hmode top {.c <p> TOPP LOWP   .c <r> break break   .c <d> break LOWP}
check "CR6m a script the mode binds on that canvas itself is not taken as another mode's: the stack is still read top first" \
  [list [ro] [round]] {{top low} {{top low} {low top}}}
hclear
hmode m1 {.c <p> P1 {}   .c <r> break {}}
hmode m2 {.c <p> P2 P1   .c <r> break break}
hmode m3 {.c <p> P3 P2   .c <r> break break}
check "CR6m2 three modes that all swallow the release with one word: top first" [ro] {m3 m2 m1}

foreach {tag order} {n {ra rb} n2 {rb ra}} {
  hclear
  set grp(ra) {.c <s> X Y}
  set grp(rb) {.c <s> Y X}
  foreach m $order { hmode $m $grp($m) }
  check "CR6$tag two modes that each name the other's script as what was there before, registered $order: registration order" \
    [list [ro] [round]] [list $order [list $order [lreverse $order]]]
}
hclear
hmode ra {.c <s> X Y}
hmode rb {.c <s> Y X}
hmode top {.c <p> TOPP X}
check "CR6n3 a mode seized over a ring of two still goes before both" [ro] {top ra rb}

hclear
hreg boom held_boom
hmode low {.c <p> LOWP {}}
hmode top {.c <p> TOPP LOWP}
check "CR6o a held callback that raises: that mode keeps its place, the others are still ordered" [ro] {boom top low}
check_true "CR6o2 and the raising callback really was asked" [expr {[lsearch -exact $::hasked boom] >= 0}]
set got {}
foreach {m answer} [list three {.c <p> TOPP} five {.c <p> TOPP LOWP extra} nolist [format %c 123]] {
  hclear
  hmode low {.c <p> LOWP {}}
  set ::hrows($m) $answer
  hreg $m [list held_of $m]
  lappend got [ro]
}
check "CR6o3 an answer of three words, of five words, or one that is no list: read as holding nothing, registration order" \
  $got {{low three} {low five} {low nolist}}

# A mode that declares an EMPTY script in a slot (it took a binding away), registered
# first; another mode took a slot that held nothing.
hclear
hmode cut {.c <q> {} OLDQ}
hmode a   {.c <p> AP {}}
check "CR6p a slot taken over nothing says nothing about a mode that declares an empty script: registration order" \
  [ro] {cut a}

hclear
hreg lv held_level
set ::held_level {}
cmdmode::suspend_all
cmdmode::resume_all .x1.drw
check "CR6q suspend_all calls the held callback with no arguments, at global level" $::held_level 1

hclear
hmode low {.c <p> LOWP {}}
hmode top {.c <p> TOPP LOWP}
cmdmode::suspend_all
set ::hrows(low) {}
set ::hrows(top) {}
check "CR6r modes that report nothing held, as a paused mode does, are in registration order; a second suspend_all releases nothing and leaves the pending order alone" \
  [list [ro] [cmdmode::suspend_all] [cmdmode::pending]] {{low top} 0 {low top}}
cmdmode::resume_all .x1.drw

hclear
set none [list [ro] [cmdmode::suspend_all] [cmdmode::resume_all]]
# One mode registered and taken out again: the order names it while it is there and
# is empty once it has gone.
hmode solo {.c <p> SOLOP {}}
set with_solo [ro]
cmdmode::unregister solo
check "CR6s with nothing registered the order is empty; one mode registered is the whole order, and unregistering it leaves the order empty again" \
  [list $none $with_solo [ro]] {{{} 0 0} solo {}}

# --- CR7: every proc of the namespace answers -------------------------------------------
# The procs are taken from the interpreter and each is called with a stock word for
# every formal it has, so a proc added later is driven too, and one whose formal has no
# stock word here is named. On the --nogui arm this is the proof that the file needs no Tk.
hclear
set stock {key cm0201_k suspend_cb sus_a resume_cb res_a held_cb {} canvas .drw
           sequence <ButtonPress-1> script x canon {} upper {} lower {}}
set raised {} ; set unknown {} ; set driven {}
foreach p [lsort [info procs ::cmdmode::*]] {
  set call [list $p] ; set known 1
  foreach f [info args $p] {
    if {![dict exists $stock $f]} { lappend unknown "${p}: $f" ; set known 0 ; break }
    lappend call [dict get $stock $f]
  }
  if {!$known} { continue }
  lappend driven [namespace tail $p]
  if {[catch {uplevel #0 $call} r]} { lappend raised "${p}: $r" }
}
check "CR7a every proc of the namespace answers when called with a stock word for each formal" \
  [list $raised $unknown] {{} {}}
set missing {}
foreach p {register unregister registered is_suspended pending suspend_all resume_all rehome pristine
           release_order} {
  if {$p ni $driven} { lappend missing $p }
}
check "CR7a2 and that sweep reached the procs the contract names" $missing {}
hclear
# With no Tk the caller's spelling prefix has nothing to ask: it answers the sequence
# as given, and the walk still works on equal spellings.
if {[info commands bind_seq_spelling] ne {} && [info commands bind] eq {}} {
  hmode h {.c <ButtonPress-1> MODE PRED}
  check "CR7b with no Tk the spelling proc answers a sequence as given, and pristine with it still steps" \
    [list [val {bind_seq_spelling <ButtonPress-1>}] [pr .c <ButtonPress-1> MODE bind_seq_spelling] \
          [pr .c <Button-1> MODE bind_seq_spelling]] {<ButtonPress-1> PRED MODE}
  hclear
}
# The engine calls clone_canvas_bindings for every window it makes, with or without a
# display, and goes on when the proc raises, so a row that makes a window cannot tell
# whether it did. The proc is called here by name: with no Tk it has nothing to copy,
# and it must answer and not raise.
if {[info commands clone_canvas_bindings] ne {} && [info commands winfo] eq {}} {
  check "CR7c with no Tk clone_canvas_bindings answers nothing and does not raise" \
    [list [catch {clone_canvas_bindings .drw .x1.drw} e] $e] {0 {}}
}

# --- CR8: clone_canvas_bindings while a stub mode holds slots of the source canvas -------
if {[info commands winfo] eq {} || [info commands clone_canvas_bindings] eq {}} {
  puts "SKIPPED: leg CR8 (clone_canvas_bindings between real canvases) needs xschem on a display; run tests/headless/run_suites.sh test_cmdmode_0201"
} else {

# The reason a spelling prefix exists: Tk lists a binding under its own spelling.
cb_fresh
bind .cm0201.src <ButtonPress-1> [sc MODE_PRESS]
set listed [bind .cm0201.src]
check_true "CR8a Tk lists the press binding under a spelling of its own, not the one it was made with" \
  [expr {[llength $listed] == 1 && [lindex $listed 0] ne {<ButtonPress-1>}}]
check "CR8a2 and the spelling proc answers that listing" [val {bind_seq_spelling <ButtonPress-1>}] [lindex $listed 0]
set bad {} ; set moved 0
foreach s {<ButtonPress-1> <Button-1> <1> <ButtonRelease-1> <Double-ButtonPress-1> <Double-1>
           <Button1-Motion> <B1-Motion> <Escape> <KeyPress-Escape> <Key-Escape> <Destroy>
           <Shift-Control-Key-P> <Key-a>} {
  foreach q [bind .cm0201.src] { bind .cm0201.src $q {} }
  bind .cm0201.src $s [sc ANY]
  set listed [lindex [bind .cm0201.src] 0]
  set got [val [list bind_seq_spelling $s]]
  if {$got ne $listed} { lappend bad "$s: $got against $listed" }
  if {$listed ne $s} { incr moved }
}
check "CR8b for each spelling tried, the spelling proc answers what bind lists for a binding made with it" $bad {}
check_true "CR8b2 and some of those are listed differently from how they were made" [expr {$moved > 0}]
check "CR8b3 a sequence Tk does not accept is answered as given" \
  [list [val {bind_seq_spelling <NoSuchEvent-1>}] [val {bind_seq_spelling {}}]] {<NoSuchEvent-1> {}}

cb_fresh
bind .cm0201.src <Key-Escape>     [sc MODE_ESC]
bind .cm0201.src <Control-Key-F7> [sc USER_F7]
hmode h [list .cm0201.src <Key-Escape> [sc MODE_ESC] {}]
set r [cb_clone]
check "CR8c a slot a mode holds over nothing is not copied; a binding no mode holds still is" \
  [list $r [cb_slots .cm0201.dst {<Key-Escape> <Control-Key-F7>}]] [list {} [list {} [sc USER_F7]]]

cb_fresh
bind .cm0201.src <Key-Escape> [sc MODE_ESC]
hmode h [list .cm0201.src <Key-Escape> [sc MODE_ESC] [sc USER_ESC]]
cb_clone
check "CR8d a slot a mode holds over a binding: the new canvas gets that binding" \
  [bind .cm0201.dst <Key-Escape>] [sc USER_ESC]

cb_fresh
bind .cm0201.src <Key-Escape> [sc MODE_ESC]
bind .cm0201.dst <Key-Escape> [sc DST_OWN]
hmode h [list .cm0201.src <Key-Escape> [sc MODE_ESC] [sc USER_ESC]]
cb_clone
check "CR8e a slot the new canvas already binds keeps its own script" \
  [bind .cm0201.dst <Key-Escape>] [sc DST_OWN]

foreach {tag decl} {f <ButtonPress-1> f2 <Button-1> f3 <1>} {
  cb_fresh
  bind .cm0201.src <ButtonPress-1> [sc MODE_PRESS]
  hmode h [list .cm0201.src $decl [sc MODE_PRESS] {}]
  set r [cb_clone]
  check "CR8$tag a mode that declares its press slot as $decl: the press is not copied" \
    [list $r [bind .cm0201.dst <ButtonPress-1>]] {{} {}}
}

cb_fresh
bind .cm0201.src <ButtonPress-1> [sc MODE_PRESS]
cb_clone
check "CR8g with no mode declaring it, the same binding is copied as it stands" \
  [bind .cm0201.dst <ButtonPress-1>] [sc MODE_PRESS]

cb_fresh
bind .cm0201.src <ButtonPress-1> [sc TOP_PRESS]
hmode low [list .cm0201.src <ButtonPress-1> [sc LOW_PRESS] [sc USER_PRESS]]
hmode top [list .cm0201.src <ButtonPress-1> [sc TOP_PRESS] [sc LOW_PRESS]]
cb_clone
check "CR8h two modes stacked on the slot: the new canvas gets what was under both" \
  [bind .cm0201.dst <ButtonPress-1>] [sc USER_PRESS]

# A stub mode holding several slots at once: one script on the press and on the double
# click, one word on the release and on the held motion, a script of its own on Escape
# and on <Destroy>. The destination binds a double click of its own before the copy.
cb_fresh
set seqs {<ButtonPress-1> <ButtonRelease-1> <B1-Motion> <Key-Escape> <Double-Button-1> <Destroy>
          <Control-Key-F7>}
set made [list [sc MODE_PRESS] break break [sc MODE_ESC] [sc MODE_PRESS] [sc MODE_GONE] [sc USER_F7]]
foreach s $seqs m $made { bind .cm0201.src $s $m }
bind .cm0201.dst <Double-Button-1> [sc DST_DBL]
hmode h [list .cm0201.src <ButtonPress-1>   [sc MODE_PRESS] {} \
              .cm0201.src <ButtonRelease-1> break           {} \
              .cm0201.src <B1-Motion>       break           {} \
              .cm0201.src <Key-Escape>      [sc MODE_ESC]   [sc USER_ESC] \
              .cm0201.src <Double-Button-1> [sc MODE_PRESS] [sc EDIT_DBL] \
              .cm0201.src <Destroy>         [sc MODE_GONE]  {}]
cb_clone
check "CR8i a mode holding press, release, held motion, Escape, double click and Destroy at once: the new canvas gets none of its scripts" \
  [cb_slots .cm0201.dst $seqs] [list {} {} {} [sc USER_ESC] [sc DST_DBL] {} [sc USER_F7]]
check "CR8i2 and the source canvas keeps every script it had" [cb_slots .cm0201.src $seqs] $made

cb_fresh
canvas .cm0201.old
hmode h [list .cm0201.old <Key-Escape> [sc MODE_ESC] {}]
destroy .cm0201.old
bind .cm0201.src <Key-Escape>     [sc MODE_ESC]
bind .cm0201.src <Control-Key-F7> [sc USER_F7]
set r [cb_clone]
check "CR8j a held list naming a canvas that was destroyed: the copy runs and that group matches no other canvas" \
  [list $r [cb_slots .cm0201.dst {<Key-Escape> <Control-Key-F7>}]] [list {} [list [sc MODE_ESC] [sc USER_F7]]]

cb_fresh
hreg boom held_boom
bind .cm0201.src <Key-Escape>     [sc MODE_ESC]
bind .cm0201.src <Control-Key-F7> [sc USER_F7]
hmode h [list .cm0201.src <Key-Escape> [sc MODE_ESC] {}]
set r [cb_clone]
check "CR8k a held callback that raises stops neither the copy nor the other mode's answer" \
  [list $r [cb_slots .cm0201.dst {<Key-Escape> <Control-Key-F7>}]] [list {} [list {} [sc USER_F7]]]
catch {destroy .cm0201}

# The door itself: a window made with no suspend first, while a stub mode holds the
# main canvas's press slot over nothing. The main canvas also carries a binding no
# mode holds; finding it on the new canvas shows the copy ran.
hclear
set door [list [bind .drw <ButtonPress-1>] [bind .drw <Control-Key-F7>]]
check "CR8m fixture: the main canvas binds neither sequence before the stub mode takes one" $door {{} {}}
if {$door eq {{} {}}} {
  set before [cb_canvases]
  bind .drw <ButtonPress-1>  [sc MODE_PRESS]
  bind .drw <Control-Key-F7> [sc USER_F7]
  hmode h [list .drw <ButtonPress-1> [sc MODE_PRESS] {}]
  val {xschem new_schematic create_window {} {}}
  update
  set new {}
  foreach c [cb_canvases] { if {$c ni $before} { lappend new $c } }
  bind .drw <ButtonPress-1>  {}
  bind .drw <Control-Key-F7> {}
  hclear
  check "CR8m2 the door made one new canvas" [llength $new] 1
  set second [lindex $new 0]
  if {$second ne {}} {
    check "CR8m3 a window made while the stub mode is up: its canvas has the user's binding and not the mode's press" \
      [cb_slots $second {<ButtonPress-1> <Control-Key-F7>}] [list {} [sc USER_F7]]
    val [list xschem new_schematic destroy $second {}]
    update
    val {xschem new_schematic switch .drw}
    check "CR8m4 and the window is closed again" [winfo exists $second] 0
  }
}

}   ;# leg CR8

check "CR9 every stub mode of legs CR4 on was accepted by register" $::hfail {}

clear_all

} err]} { puts "FATAL: $err" ; incr fail }

# The completion sentinel tests/banner_rule.tcl's banner_complete requires of a
# registered case, printed only when every check passed. The verdict line stays
# last: the regression driver carries a case's last verdict line into its block.
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
