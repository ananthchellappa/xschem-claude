# Reopen shortcuts (Open Most Recent / Open Last Closed / Recent menu) open a file in READ mode, while
# File > Open stays editable. Mechanism: a `-readonly` flag on `xschem load` forces xctx->readonly=1
# after the load (a writable file would otherwise open editable); the reopen entry points pass it,
# File > Open does not. Edit anytime with Ctrl-2 / View > Toggle Read Only (like descend_readonly).
#
# Headless:  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_reopen_readonly.tcl
# (cwd = repo root, so the wiring checks read src/actions.csv and src/xschem.tcl)

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }

# ---- (1) core: `xschem load -readonly` forces read mode; plain load of a writable file is editable ----
source [file join [file dirname [info script]] scratch.tcl]
set dir [test_scratch ro]
set f [file join $dir cell.sch]
# a real, WRITABLE schematic (copy a library cell so load_schematic has valid content)
set src [lindex [glob -nocomplain [file join [pwd] xschem_library devices *.sym]] 0]
set lib [lindex [glob -nocomplain [file join [pwd] xschem_library *.sch]] 0]
if {$lib eq {}} { set lib [lindex [glob -nocomplain [file join [pwd] xschem_library * *.sch]] 0] }
file copy -force $lib $f
file attributes $f -permissions 0644

xschem load $f
check "R1 plain load of a writable file opens EDITABLE" [expr {[xschem get readonly] == 0}] "(ro=[xschem get readonly])"

xschem load -readonly $f
check "R2 load -readonly opens READ mode" [expr {[xschem get readonly] == 1}] "(ro=[xschem get readonly])"

# the flag does not stick: a subsequent plain load is editable again
xschem load $f
check "R3 plain load after -readonly is editable again" [expr {[xschem get readonly] == 0}] "(ro=[xschem get readonly])"

# ---- (1b) the ACTUAL bug: the keyboard Ctrl+Shift+O runs `xschem load -gui -lastopened` directly
# (the actions.csv accel is display-only), so -lastopened/-lastclosed must THEMSELVES imply read mode.
set fa [file join $dir a.sch] ; set fb [file join $dir b.sch]
file copy -force $lib $fa ; file copy -force $lib $fb
file attributes $fa -permissions 0644 ; file attributes $fb -permissions 0644
set fc [file join $dir c.sch]
file copy -force $lib $fc ; file attributes $fc -permissions 0644
set fpark [file join $dir park.sch]
file copy -force $lib $fpark ; file attributes $fpark -permissions 0644
# The recents list is HARD-GATED OFF in a --nogui/--pipe session (no_recent_files, issue 0119 --
# xinit.c sets it for every test harness), so a plain `xschem load` here records NOTHING. Feeding
# the resolver that way left it reading the USER's persisted $USER_CONF_DIR/recent_files, and R10
# then asserted whatever that file happened to hold on this machine -- a standing red that says
# nothing about the code. Drive tctx::recentfile DIRECTLY: it is the variable get_lastopened reads,
# and setting it writes no user file (write_recent_file stays gated).
# NOTE the ORDER: fb is the HEAD and fb is what gets loaded, so returning fa REQUIRES the
# skip-the-loaded-entry step to run. With fa at the head the check would pass without it.
set tctx::recentfile [list $fb $fa]
xschem load $fb
check "R8 plain load of fb is editable" [expr {[xschem get readonly] == 0}] "(ro=[xschem get readonly])"
set got [xschem load -lastopened]   ;# == the keyboard reopen path, WITHOUT an explicit -readonly
check "R9 -lastopened (keyboard reopen) implies READ mode" [expr {[xschem get readonly] == 1}] "(ro=[xschem get readonly])"
check "R10 -lastopened skips the loaded head (fb) and resolves to fa" [expr {[file tail $got] eq {a.sch}}] "(=> $got)"
# Positive twin for R10 (issue 0839): the skip is CONDITIONAL, not an unconditional "never index 0".
# With nothing in the list loaded, the head itself must come back.
xschem load $fc
set tctx::recentfile [list $fa $fb]
set got2 [xschem load -lastopened]
check "R10b -lastopened returns the HEAD when the head is not loaded" [expr {[file tail $got2] eq {a.sch}}] "(=> $got2)"

# ---- (2) wiring: the reopen shortcuts carry -readonly; File > Open (file_chooser_place) does not ----
proc slurp {p} { set fd [open $p r] ; set s [read $fd] ; close $fd ; return $s }
set csv [slurp [file join [pwd] src actions.csv]]
set tcl [slurp [file join [pwd] src xschem.tcl]]

set most [lsearch -inline [split $csv \n] *open_most_recent*]
set last [lsearch -inline [split $csv \n] *open_last_closed*]
check "R4 open_most_recent (Ctrl+Shift+O) passes -readonly" [string match {*-lastopened -readonly*} $most] "(=> $most)"
check "R5 open_last_closed (Ctrl+Shift+T) passes -readonly" [string match {*-lastclosed -readonly*} $last] "(=> $last)"

# the Recent-files menu entries load read-only too
check "R6 recent menu (setup_recent_menu) passes -readonly" \
  [regexp {xschem load -gui -readonly \{\$i\}} $tcl] {}

# File > Open New File (file_chooser_place) must stay EDITABLE (no -readonly on that load)
check "R7 File>Open stays editable (no -readonly in file_chooser_place)" \
  [regexp {xschem load -gui \$f\n} $tcl] {}

# ---- (3) LOUDNESS (issue 0845, the user's ruling): the read-only default is ratified, so the
# door must SAY SO. Only the window title used to, and nobody reads a title bar. The notice goes
# through the house channel; here ::xschem::notify is replaced by a recorder so the sentence,
# the -short form and the remedy can be asserted without a display.
rename ::xschem::notify ::xschem::_notify_real
proc ::xschem::notify {msg args} { lappend ::notified [linsert $args 0 $msg] ; return 1 }
proc cap {script} { set ::notified {} ; uplevel 1 $script ; return $::notified }
# ⚠ NEVER `-gui` LOAD A FILE THAT IS ALREADY LOADED. Under a real display the C side
# raises a modal "Warning: <file> already open." and the suite hangs forever. It is
# INVISIBLE under --nogui -- has_x is false there, so that arm only calls dbg() -- which
# is why every row below passed when run standalone the documented way and the suite
# TIMED OUT the moment the full audit ran it under Xvfb. Park the buffer on another file
# first, so the `-gui` load is always of something not currently open.
proc park {} { uplevel 1 {xschem load $fpark} }
proc first_ro {} {
  foreach n $::notified { if {[string match {*Read-Only*} [lindex $n 0]]} { return $n } }
  return {}
}
set ::cadence_compat 0

park
cap {xschem load -gui -readonly $fa}
set n [first_ro]
set sentence {Opened Read-Only. Use Edit > Make Editable (Ctrl-2) if needed}
check "R11 an interactive reopen ANNOUNCES the read-only open" [expr {$n ne {}}] "(=> [lindex $n 0])"
check "R12 the notice is the user's ratified sentence, verbatim" [expr {[lindex $n 0] eq $sentence}] "(=> [lindex $n 0])"
check "R13 the remedy is INSIDE the sentence (menu and key)" \
  [expr {[string match {*Edit > Make Editable*} [lindex $n 0]] && [string match {*Ctrl-2*} [lindex $n 0]]}] {}
check "R14 the notice carries a short form for the statusbar" [expr {[lsearch -exact $n -short] >= 0}] {}

# ⚠ THE LENGTH GUARD, and it is the whole point of this revision. The first version of the
# notice explained the rule -- three door names and a reason -- and the user's verdict on
# reading it was "full line is too much". -menu/-command are TEXT options: xschem::notify
# appends " Fix: <menu>." and " CIW command: <cmd>" to the rendered line, and passing them
# is how the sentence silently grows back. So assert both the absence and the size.
check "R14a no -menu/-command tail (they re-lengthen the rendered line)" \
  [expr {[lsearch -exact $n -menu] < 0 && [lsearch -exact $n -command] < 0}] "(=> $n)"
check "R14b the sentence stays short (<= 70 chars)" [expr {[string length [lindex $n 0]] <= 70}] \
  "(len=[string length [lindex $n 0]])"

# negative twin A: a SCRIPTED load (no -gui) must stay silent -- a replay must not narrate.
cap {xschem load -readonly $fa}
check "R15 a scripted -readonly load announces NOTHING" [expr {[first_ro] eq {}}] "(=> [first_ro])"

# negative twin B: an ordinary interactive open is editable, so there is nothing to announce.
park
cap {xschem load -gui $fa}
check "R16 a plain -gui load announces NOTHING" [expr {[first_ro] eq {}}] "(=> [first_ro])"

# The sentence does NOT vary by mode. An earlier revision named Ctrl-2 only under
# cadence_compat, on the theory that the key is cadence-only -- but the Edit menu itself
# advertises `Ctrl+2` unconditionally (xschem.tcl toggle_readonly_menu), so a conditional
# here would have made the notice and the menu disagree about the same key. One claim.
set ::cadence_compat 1
park
cap {xschem load -gui -readonly $fa}
set nc [lindex [first_ro] 0]
set ::cadence_compat 0
park
cap {xschem load -gui -readonly $fa}
check "R17 the sentence does not vary with cadence_compat" [expr {$nc eq [lindex [first_ro] 0]}] \
  "(cadence='$nc' legacy='[lindex [first_ro] 0]')"

# the read-only state itself must still be reached by the announcing path (the notice is an
# ADDITION, not a replacement -- a door that only talks is worse than one that only acts).
check "R18 the announcing path still opens READ mode" [expr {[xschem get readonly] == 1}] "(ro=[xschem get readonly])"

# WHY the announcement sits OUTSIDE scheduler.c's `if(!xctx->readonly)` block: a NON-WRITABLE
# file is already read-only by the time that block is reached (save.c's file-protection
# fallback set it during the load), so the block is a no-op -- and an announcement nested
# inside it would go silent for exactly the file the user is LEAST able to edit. Same
# surprise, so the same sentence.
set fro [file join $dir ro.sch]
file copy -force $lib $fro
file attributes $fro -permissions 0444
park
cap {xschem load -gui -readonly $fro}
check "R19 a NON-WRITABLE reopen is announced too (notice is not nested in the state change)" \
  [expr {[first_ro] ne {}}] "(=> [lindex [first_ro] 0])"
file attributes $fro -permissions 0644

# END-TO-END through the door the user actually presses: Ctrl+Shift+O runs
# `xschem load -gui -lastopened` from callback.c with NO explicit -readonly, so the
# announcement has to survive the implied-readonly path too, not just the flagged one.
xschem load $fc
set tctx::recentfile [list $fc $fa]
cap {xschem load -gui -lastopened}
check "R20 the KEYBOARD door (-gui -lastopened, no explicit flag) announces" \
  [expr {[first_ro] ne {}}] "(=> [lindex [first_ro] 0])"

rename ::xschem::notify {}
rename ::xschem::_notify_real ::xschem::notify

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
