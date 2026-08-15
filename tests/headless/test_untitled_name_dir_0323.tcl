# Issue 0323: the untitled namer must probe the directory it is about to WRITE into.
#
# get_unused_untitled_name() used to decide a name was free with a relative stat(), which
# resolves against the live process cwd -- while both callers compose the buffer path from a
# directory captured at startup ($PWD in save.c, pwd_dir in actions.c). Tcl's `cd` updates
# neither, so after any cd the probe and the write hit different directories, and the loop
# would hand back a name that was already occupied at the destination. Measured pre-fix: an
# untitled.sch holding unsaved content was silently overwritten.
#
# Both assertions below FAIL on the pre-fix binary:
#   A (save.c:4413)    -- startup in a dir that already holds untitled.sch must name the
#                         buffer untitled-1.sch. Pre-fix this happens to pass, because at
#                         startup cwd == $PWD; it is here so a sabotage of the save.c call
#                         site (wrong dir argument) is caught.
#   B (actions.c:3942) -- the real regression. cd away, `xschem clear force`, save: the
#                         occupied file at the destination must survive and the buffer must
#                         take the next free number.
#
# The work happens in CHILD processes because the property under test is decided by the
# child's startup cwd/$PWD, which this script cannot change for itself after the fact.
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_untitled_name_dir_0323.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

source [file join [file dirname [info script]] scratch.tcl]
set scratch [test_scratch untitled0323]

set bin [info nameofexecutable]
set saved_pwd_var $::env(PWD)
set saved_cwd [pwd]

set SENTINEL "PRECIOUS UNSAVED WORK"

## Run $body inside a child xschem whose cwd AND $PWD are $dir. Both must be set: Tcl's `cd`
## leaves env(PWD) alone, and a child inheriting a stale PWD would reproduce the very
## desync under test instead of starting from a consistent state.
proc run_child {dir body} {
  global bin scratch
  set f [file join $scratch child.tcl]
  set fh [open $f w]; puts $fh $body; close $fh
  set out [file join $scratch child.out]
  set save_cwd [pwd] ; set save_pwd $::env(PWD)
  cd $dir ; set ::env(PWD) $dir
  catch {exec timeout 60 $bin --nogui --pipe -q --nolog --script $f >& $out} err
  cd $save_cwd ; set ::env(PWD) $save_pwd
  set fh [open $out r]; set txt [read $fh]; close $fh
  return $txt
}

proc grepline {txt tag} {
  foreach l [split $txt \n] {
    if {[string match "$tag *" $l]} { return [string range $l [expr {[string length $tag] + 1}] end] }
  }
  return ""
}

# ---------------------------------------------------------------------------
# A. save.c:4413 -- the startup naming probes the directory it will write into.
# ---------------------------------------------------------------------------
set dirA [file join $scratch a]
file mkdir $dirA
set fh [open [file join $dirA untitled.sch] w]; puts $fh $SENTINEL; close $fh

set txtA [run_child $dirA {
  puts "SCHNAME [xschem get schname]"
  exit 0
}]
check "A: startup skips the occupied untitled.sch" \
  [file tail [grepline $txtA SCHNAME]] untitled-1.sch
check "A: and names it in the startup directory" \
  [file normalize [file dirname [grepline $txtA SCHNAME]]] [file normalize $dirA]
check "A: the occupied file is untouched" \
  [string trim [exec cat [file join $dirA untitled.sch]]] $SENTINEL

# ---------------------------------------------------------------------------
# B. actions.c:3942 -- `xschem clear force` after a cd. THE regression: pre-fix the
#    namer probed the cd'd-to directory (empty -> "untitled.sch is free") while the
#    write went to the startup directory, destroying the file already there.
# ---------------------------------------------------------------------------
set dirB [file join $scratch b]
set away [file join $scratch away]
file mkdir $dirB $away
set fh [open [file join $dirB untitled.sch] w]; puts $fh $SENTINEL; close $fh

set txtB [run_child $dirB [subst -nocommands {
  cd $away
  xschem clear force
  puts "SCHNAME [xschem get schname]"
  xschem wire 0 0 100 0
  xschem save
  exit 0
}]]

check "B: clear-after-cd skips the occupied name" \
  [file tail [grepline $txtB SCHNAME]] untitled-1.sch
check "B: and still writes into the startup directory" \
  [file normalize [file dirname [grepline $txtB SCHNAME]]] [file normalize $dirB]
check "B: the occupied file SURVIVES (0323 data loss)" \
  [string trim [exec cat [file join $dirB untitled.sch]]] $SENTINEL
check "B: the new buffer was actually written" \
  [file exists [file join $dirB untitled-1.sch]] 1
check "B: nothing landed in the cd'd-to directory" \
  [lsort [glob -nocomplain -tails -directory $away *]] {}

cd $saved_cwd
set ::env(PWD) $saved_pwd_var

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
