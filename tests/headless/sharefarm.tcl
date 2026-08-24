## File: tests/headless/sharefarm.tcl
## A throw-away XSCHEM_SHAREDIR, and a CHILD xschem launched against it.
##
## WHY THIS EXISTS (issue 0658). The degraded state the notify bootstrap serves
## is "src/ciw.tcl failed to load". No in-process rename reproduces it: a rename
## removes ONE proc, while a failed `source` removes the whole file AND happens
## at startup, before any test script runs. The only honest reproduction is a
## SECOND xschem process whose share dir carries a broken ciw.tcl -- and the
## developer's src/ tree must obviously not be the thing that gets broken.
##
## So: a directory of SYMLINKS to every entry of the repo's src/, with named
## files REPLACED by literal content. XSCHEM_SHAREDIR is priority 1 in the share
## dir search (src/xinit.c:2985), so the child picks the farm up with no other
## plumbing. Measured at HEAD, 2026-08-24: a farm whose ciw.tcl is a one-line
## `error` makes the child SIGSEGV at startup (exit 139) -- src/xschem.tcl:14648
## is a BARE `source`, the raise propagates out of xschem.tcl, source_tcl_file()
## (src/xinit.c:1513) prints and returns, and Tcl_AppInit walks on into
## `tclgetdoublevar(cairo_font_line_spacing)` against unset variables.
##
## The child idiom itself (a private --logdir, then read Xschem.log) is
## test_descend_log_absorb.tcl:48 and test_ciw_actionlog_output.tcl:36; this file
## only adds the share dir.
##
## Usage:
##     source [file join [file dirname [info script]] sharefarm.tcl]
##     set farm [share_farm $repo [file join $scratch farm_broken] \
##                 [list ciw.tcl "error {deliberate failure}\n"]]
##     set r [share_farm_child $farm [file join $scratch c1] $inner_script]
##     dict get $r -status      ;# "0" for a clean exit
##     dict get $r -out         ;# merged stdout+stderr
##     dict get $r -log         ;# Xschem.log lines, or {} if it was never written

## Build (or rebuild) the farm. $replace is a flat {name content name content}
## list; a name present there is written as a REAL file and never symlinked, so
## the repo's own src/ is read-only throughout.
proc share_farm {repo dir {replace {}}} {
  set src [file join $repo src]
  file delete -force $dir
  file mkdir $dir
  foreach ent [glob -nocomplain -tails -directory $src *] {
    if {[dict exists $replace $ent]} continue
    catch {file link -symbolic [file join $dir $ent] [file join $src $ent]}
  }
  foreach {name body} $replace {
    set fd [open [file join $dir $name] w]
    puts -nonewline $fd $body
    close $fd
  }
  return $dir
}

## Normalize `exec`'s failure reporting into ONE comparable string, so a check
## can spell its expectation as "0" and a segfault reads as "CHILDKILLED SIGSEGV"
## rather than as an empty result. errorCode is CHILDSTATUS/CHILDKILLED (Tcl
## exec(n)); anything else (the binary missing, say) becomes EXECFAIL.
proc share_farm_status {rc ec} {
  if {!$rc} { return 0 }
  switch -exact -- [lindex $ec 0] {
    CHILDSTATUS { return "CHILDSTATUS [lindex $ec 2]" }
    CHILDKILLED { return "CHILDKILLED [lindex $ec 2]" }
    default     { return "EXECFAIL $ec" }
  }
}

## Run $inner in a fresh child xschem: farm as XSCHEM_SHAREDIR, $dir as the
## private --logdir AND the script's home. $flags defaults to the true-headless
## set; pass {--pipe -q} to get an X session instead (the caller must have a
## DISPLAY). ::env is restored on every path.
proc share_farm_child {farm dir inner {flags {--nogui --pipe -q}}} {
  file mkdir $dir
  set sf [file join $dir inner.tcl]
  set fd [open $sf w] ; puts $fd $inner ; close $fd

  set had [info exists ::env(XSCHEM_SHAREDIR)]
  if {$had} { set old $::env(XSCHEM_SHAREDIR) }
  set ::env(XSCHEM_SHAREDIR) $farm
  set out {}
  set rc [catch {eval exec [list [info nameofexecutable]] $flags \
                   [list --logdir $dir --script $sf] 2>@1} out]
  set st [share_farm_status $rc $::errorCode]
  if {$had} { set ::env(XSCHEM_SHAREDIR) $old } \
  else      { unset -nocomplain ::env(XSCHEM_SHAREDIR) }

  set loglines {}
  set lf [file join $dir Xschem.log]
  if {[file exists $lf]} {
    set rf [open $lf r] ; set body [read $rf] ; close $rf
    set loglines [split [string trimright $body \n] \n]
  }
  return [dict create -status $st -out $out -log $loglines]
}

## count log/output lines containing $s
proc share_farm_count {lines s} {
  set n 0
  foreach l $lines { if {[string first $s $l] >= 0} { incr n } }
  return $n
}
