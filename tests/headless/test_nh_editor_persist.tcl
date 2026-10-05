# Net highlight style editor -- persistence, writer AND the product's startup reader.
# Pure Tcl, true headless (no X): the "seen"-marker writer, the located style-conf
# writer, their hand-sourced round-trip, and -- band 3 onward -- `load_net_hilight_conf`
# itself, which is the proc xschem really calls at startup.
#   tests/headless/run_suites.sh --nogui test_nh_editor_persist
#
# WHY BANDS 3-5 EXIST (issue 0925). Bands 1-2 source the conf files BY HAND, at global
# script scope, where an unqualified `set net_hilight_style {...}` lands exactly where it
# is wanted. The product does not do that: it sources them from inside a proc. Those bands
# therefore fence the WRITER and say nothing about the reader, and they stayed green for a
# month over a reader that discarded every row. Their names now say so. Bands 3-5 drive
# `load_net_hilight_conf` instead, so the claim "a saved table is in force next session" is
# measured against the proc that is supposed to put it there.
#
# THE OBSERVED FAILURE WAS NOT "NOTHING LOADS" BUT "THE DEFAULTS LOAD", which is what the
# user reports. The style conf's own last line is `catch {xschem update_net_hilight_style}`;
# run with the global still empty, the C side re-derives and REPUBLISHES the built-in table,
# so a reader that drops the rows does not leave the global empty -- it leaves it holding
# the default table. A row asserting "not empty" would have passed. Band 3 asserts the
# saved table, and band 4 derives its own oracle rather than trusting a literal.

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail" ; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}

# Isolate from the real ~/.xschem: point USER_CONF_DIR at a throwaway dir.
source [file join [file dirname [info script]] scratch.tcl]
set tmp [test_scratch nhepersist]
set ::USER_CONF_DIR $tmp

# --- 1) the harmless "seen" marker -------------------------------------------
check "S1a net_hilight_editor_seen global exists" \
  [info exists ::net_hilight_editor_seen] \
  "(=> [expr {[info exists ::net_hilight_editor_seen] ? $::net_hilight_editor_seen : {<unset>}}])"

set ::net_hilight_editor_seen 0
set rc1 [catch {write_net_hilight_editor_seen} e1]
check "S1b write_net_hilight_editor_seen runs" [expr {$rc1 == 0}] "(rc=$rc1 $e1)"
set marker $tmp/net_hilight_editor_seen
check "S1c marker file written" [file exists $marker] "(=> $marker)"
set ::net_hilight_editor_seen 0
catch {source $marker}
check "S1d marker sourced BY HAND at global scope sets seen=1 (writer leg)" \
  [expr {$::net_hilight_editor_seen == 1}] "(=> $::net_hilight_editor_seen)"

# --- 2) the located style-table conf -----------------------------------------
set want {{0 4 1 {} 0 0 none 0} {1 red 3 {6 4} 30 0 march_fwd 2} {2 #00ff00 2 {} 0 250 none 0}}
set ::net_hilight_style $want
set ::net_hilight_editor_seen 1
set conf $tmp/net_hilight_style
set rc2 [catch {write_net_hilight_style_conf $conf} e2]
check "S2a write_net_hilight_style_conf runs" [expr {$rc2 == 0}] "(rc=$rc2 $e2)"
check "S2b conf file written" [file exists $conf] "(=> $conf)"

# simulate a fresh session: clear both, then source the conf BY HAND at global scope
set ::net_hilight_style {}
set ::net_hilight_editor_seen 0
set rc3 [catch {source $conf} e3]
check "S2c conf sources cleanly" [expr {$rc3 == 0}] "(rc=$rc3 $e3)"
check "S2d table round-trips exactly through a HAND global source (writer leg)" \
  [expr {$::net_hilight_style eq $want}] "(=> $::net_hilight_style)"
check "S2e HAND global source restores seen=1 (writer leg)" \
  [expr {$::net_hilight_editor_seen == 1}] "(=> $::net_hilight_editor_seen)"

# --- 3) the PRODUCT reader: load_net_hilight_conf -----------------------------
# A table deliberately DIFFERENT from band 2's, so a leftover global from the hand source
# above cannot satisfy any row here.
set want2 {{0 11 2 {} 0 0 none 0} {1 blue 4 {3 3} 45 0 march_rev 5} {2 #abcdef 1 {} 0 120 none 0}}
set ::net_hilight_style $want2
set ::net_hilight_editor_seen 1
check "L0a write_net_hilight_style_conf wrote the autoload location" \
  [expr {[write_net_hilight_style_conf [file join $tmp net_hilight_style]] == 1}] "(=> $tmp)"
# Non-vacuity for L2: a reader that discards the rows leaves the BUILT-IN DEFAULT table in
# force (the conf's own trailing `xschem update_net_hilight_style` republishes it), so L2
# only discriminates if the saved table differs from that default. Measure that here rather
# than assume it.
set ::net_hilight_style {}
catch {xschem update_net_hilight_style}
set nh_default $::net_hilight_style
check "L0b the saved table DIFFERS from the built-in default (L2 non-vacuity)" \
  [expr {[string trim $nh_default] ne [string trim $want2]}] \
  "(default rows=[llength $nh_default] saved rows=[llength $want2])"

set ::net_hilight_style {}
set ::net_hilight_editor_seen 0
set rcL [catch {load_net_hilight_conf} eL]
check "L1 load_net_hilight_conf does not throw" [expr {$rcL == 0}] "(rc=$rcL $eL)"
check "L2 load_net_hilight_conf restores the SAVED table into the GLOBAL" \
  [expr {$::net_hilight_style eq $want2}] "(=> $::net_hilight_style)"
check "L3 load_net_hilight_conf restores the breadcrumb into the GLOBAL" \
  [expr {$::net_hilight_editor_seen == 1}] "(=> $::net_hilight_editor_seen)"

# The user's own ~/.xschem holds the breadcrumb and NO style table (issue 0925 s6), so the
# breadcrumb must survive on its own -- that is the palette's first-launch emphasis.
file delete -force [file join $tmp net_hilight_style]
set ::net_hilight_editor_seen 0
set ::net_hilight_style {}
catch {load_net_hilight_conf}
check "L4 breadcrumb alone (no style conf) still reaches the GLOBAL" \
  [expr {$::net_hilight_editor_seen == 1}] "(=> $::net_hilight_editor_seen)"

# --- 4) DERIVED: every `set` target in the writers' own output reaches the global ---
# No hand-kept list of variable names: the population comes from the bytes the writers
# emitted, and the expected VALUE comes from sourcing the same file in a child interpreter
# -- Tcl's own parse of the file, not this suite's. A variable added to either writer is
# covered the day it is added.
proc nh0925_set_targets {path} {
  set names {}
  if {[catch {open $path r} fd]} { return {} }
  set txt [read $fd] ; close $fd
  foreach line [split $txt \n] {
    set line [string trim $line]
    if {[string index $line 0] eq "#"} continue
    if {![regexp {^set[ \t]+([^ \t]+)[ \t]} $line -> n]} continue
    set n [string trimleft $n :]
    if {[lsearch -exact $names $n] < 0} { lappend names $n }
  }
  return $names
}

# Re-create both confs, then derive.
set ::net_hilight_style $want2
set ::net_hilight_editor_seen 0
write_net_hilight_editor_seen
set ::net_hilight_editor_seen 1
write_net_hilight_style_conf [file join $tmp net_hilight_style]

set derived {}
set oracle [dict create]
foreach f {net_hilight_editor_seen net_hilight_style} {
  set p [file join $tmp $f]
  set ip [interp create]
  catch {$ip eval [list source $p]}
  foreach n [nh0925_set_targets $p] {
    if {[lsearch -exact $derived $n] < 0} { lappend derived $n }
    if {[catch {$ip eval [list set $n]} v]} { set v {<unset-in-child>} }
    dict set oracle $n $v
  }
  interp delete $ip
}
check "D1 the writers' output yields a non-empty derived variable population" \
  [expr {[llength $derived] >= 2}] "(=> $derived)"
# Clear every derived name, then let the PRODUCT reader be the only thing that sets them.
foreach n $derived { catch {unset ::$n} }
catch {load_net_hilight_conf}
set dbad {}
foreach n $derived {
  if {![info exists ::$n]} { lappend dbad "$n=<unset>" ; continue }
  if {[set ::$n] ne [dict get $oracle $n]} { lappend dbad "$n=<[set ::$n]>" }
}
check "D2 every derived `set` target reaches the GLOBAL through load_net_hilight_conf" \
  [expr {[llength $dbad] == 0}] "(checked=[llength $derived] wrong=$dbad)"

# --- 5) the reader's failure arms ---------------------------------------------
# A damaged conf must not take startup down, and must not leave a half-applied table.
set bad [file join $tmp net_hilight_style]
set fd [open $bad w] ; puts $fd "set net_hilight_style \{unbalanced" ; close $fd
set ::net_hilight_editor_seen 0
set rcB [catch {load_net_hilight_conf} eB]
check "L5 a damaged style conf does not throw out of the reader" [expr {$rcB == 0}] "(rc=$rcB $eB)"
check "L6 a damaged style conf still lets the breadcrumb through" \
  [expr {$::net_hilight_editor_seen == 1}] "(=> $::net_hilight_editor_seen)"

# An absent USER_CONF_DIR (first ever run) is a no-op, not an error.
set ::USER_CONF_DIR [file join $tmp nothing_here]
set rcN [catch {load_net_hilight_conf} eN]
check "L7 an absent USER_CONF_DIR leaves the reader a silent no-op" [expr {$rcN == 0}] "(rc=$rcN $eN)"
set ::USER_CONF_DIR $tmp

# --- 6) the two halves of the repair that bands 3-5 cannot tell apart ---------
# Both of these were BUILT as sabotages against the fix and passed every row above, so
# they are fenced here rather than declared. See `uplevel #0 [list ...]` in
# load_net_hilight_conf: the band above pins that the names reach the global, and these two
# pin WHICH SPELLING gets them there.

# L8: an ABSOLUTE level, not a relative one. `uplevel 1` is the caller's frame, which IS the
# global frame for the single startup call site -- so every row above stays green under it.
# It stops being the global frame the moment anything calls the reader from inside a proc (a
# "reload my config" menu item is the obvious future one). Driving it from a wrapper proc is
# the only thing that separates the two spellings.
set ::net_hilight_style $want2
set ::net_hilight_editor_seen 1
write_net_hilight_style_conf [file join $tmp net_hilight_style]
write_net_hilight_editor_seen
proc nh0925_call_from_a_proc {} { load_net_hilight_conf }
set ::net_hilight_style {}
set ::net_hilight_editor_seen 0
catch {nh0925_call_from_a_proc}
check "L8 the reader reaches the GLOBAL when called from INSIDE a proc, not only from top level" \
  [expr {$::net_hilight_editor_seen == 1 && $::net_hilight_style eq $want2}] \
  "(seen=$::net_hilight_editor_seen table_ok=[expr {$::net_hilight_style eq $want2}])"

# L9: the sourced path is passed as a LIST element, not interpolated into a script string.
# A conf directory whose name contains a space makes the two spellings differ: the bare
# string form splits the path into two words and `source` reports the wrong # args. Every
# row above runs under a space-free scratch path, so none of them can see it.
set spacedir [file join $tmp {conf dir with spaces}]
file mkdir $spacedir
set ::USER_CONF_DIR $spacedir
set ::net_hilight_style $want2
set ::net_hilight_editor_seen 1
write_net_hilight_style_conf [file join $spacedir net_hilight_style]
write_net_hilight_editor_seen
set ::net_hilight_style {}
set ::net_hilight_editor_seen 0
set rcS [catch {load_net_hilight_conf} eS]
check "L9 the reader loads a conf whose DIRECTORY NAME CONTAINS A SPACE" \
  [expr {$rcS == 0 && $::net_hilight_editor_seen == 1 && $::net_hilight_style eq $want2}] \
  "(rc=$rcS seen=$::net_hilight_editor_seen table_ok=[expr {$::net_hilight_style eq $want2}] $eS)"
set ::USER_CONF_DIR $tmp

if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
