## File: tests/headless/scratch.tcl
## Shared scratch-directory discipline for the headless tests.
##
## A headless test usually needs a private throw-away directory: netlist output,
## a synthetic library.defs, a USER_CONF_DIR to keep xschem's config writes off
## the developer's real ~/.xschem. The hand-rolled idiom was
##
##     set scratch [file normalize [file join [pwd] _tag_[pid]]]
##     file delete -force $scratch; file mkdir $scratch
##     ...
##     file delete -force $scratch          ;# last line of the test
##
## which leaks the directory on every path that does not reach that last line:
## an early `SKIP -> exit` guard, an uncaught Tcl error, a segfault, a timeout
## kill, Ctrl-C. Because [pwd] is normally the repo root, the corpses pile up
## there as `_tag_<pid>` dirs. `.gitignore` hides them from `git status`, so the
## pile grows unnoticed. See doc/claude/issues/0148-scratch-dir-leak-recurrence.md
## (and commit cf57955c, which fixed two individual tests but left the class).
##
## Usage:
##     source [file join [file dirname [info script]] scratch.tcl]
##     set scratch [test_scratch vpwl]
##
## `test_scratch` gives you an empty directory and takes over its lifetime:
##   * it lives under tests/headless/.scratch/ (gitignored), NOT the repo root,
##     so even a leak never litters the working tree the developer looks at;
##   * it is deleted on every `exit` -- including `exit 1` from a failing test
##     and an early skip-guard `exit 0` -- because `exit` itself is wrapped;
##   * anything that survives even that (SIGKILL, segfault, timeout) is swept by
##     the NEXT run: on first use we delete sibling scratch dirs whose owning pid
##     is gone. So the pile is self-healing rather than monotonically growing.
##
## Override the location with $env(XSCHEM_TEST_SCRATCH) if a test needs the
## scratch tree somewhere else (e.g. a tmpfs).

## Directories this process owns; emptied by __scratch_cleanup_all.
if {![info exists ::__scratch_dirs]} { set ::__scratch_dirs {} }

## Legacy scratch locations swept for dead-pid corpses on first use: the repo
## root and tests/headless itself, the two cwds tests have historically run from.
## Resolve the repo NOW, while [info script] still names this file -- inside a
## proc called from a test it would name the test instead.
set ::__scratch_home [file normalize [file join [file dirname [info script]] .. ..]]
proc __scratch_repo {} { return $::__scratch_home }

proc __scratch_root {} {
  if {[info exists ::env(XSCHEM_TEST_SCRATCH)] && $::env(XSCHEM_TEST_SCRATCH) ne {}} {
    return [file normalize $::env(XSCHEM_TEST_SCRATCH)]
  }
  return [file normalize [file join [__scratch_repo] tests headless .scratch]]
}

## Is $p a live process? Conservative: when we cannot tell, answer "alive" so a
## sweep never removes a directory that another running test still owns.
proc __scratch_pid_alive {p} {
  if {![string is integer -strict $p]} { return 1 }
  if {[file isdirectory /proc]} { return [file exists /proc/$p] }
  if {[catch {exec kill -0 $p} err]} {
    ## "no such process" is the only error that proves it is gone; a missing
    ## kill(1) or an EPERM must not be read as "dead".
    return [expr {![string match -nocase {*no such process*} $err]}]
  }
  return 1
}

## Remove `_<tag>_<pid>` directories in $dir whose pid is dead. The age floor is
## belt-and-braces against pid reuse on a box that just wrapped its pid space.
proc __scratch_sweep {dir {min_age 300}} {
  if {![file isdirectory $dir]} return
  set now [clock seconds]
  foreach d [glob -nocomplain -directory $dir -type d {_*_[0-9]*}] {
    set base [file tail $d]
    if {![regexp {^_.*_([0-9]+)$} $base -> p]} continue
    if {$p eq [pid]} continue
    if {[__scratch_pid_alive $p]} continue
    if {[catch {file mtime $d} mt]} continue
    if {$now - $mt < $min_age} continue
    catch {file delete -force $d}
  }
}

## Delete every scratch dir this process owns. Called from the wrapped `exit`.
proc __scratch_cleanup_all {} {
  ## xschem's exit path writes window geometry into USER_CONF_DIR; if a test
  ## pointed that at its scratch dir the write would either fault or RE-CREATE
  ## the directory we just deleted (that is where the stale
  ## tests/headless/_nhangle_*/geometry corpses came from). No-op it first.
  catch {proc ::store_geom {args} {}}
  foreach d $::__scratch_dirs { catch {file delete -force $d} }
  set ::__scratch_dirs {}
}

## Wrap `exit` once, so cleanup runs on the failing-test `exit 1` and on every
## early skip-guard `exit 0` as well as the normal end of the script.
if {[info commands ::__scratch_real_exit] eq {}} {
  rename ::exit ::__scratch_real_exit
  proc ::exit {{code 0}} {
    catch {__scratch_cleanup_all}
    ::__scratch_real_exit $code
  }
}

## Create and return an empty scratch directory owned by this process.
proc test_scratch {tag} {
  if {![info exists ::__scratch_swept]} {
    set ::__scratch_swept 1
    set repo [__scratch_repo]
    ## Every directory an unconverted test has been observed to drop a corpse
    ## in: the scratch root, plus the four cwds tests get launched from and the
    ## one non-[pwd] root (test_sweep_diff.tcl anchors at tests/).
    foreach d [list [__scratch_root] $repo \
                    [file join $repo tests] [file join $repo tests headless] \
                    [file join $repo src]] {
      catch {__scratch_sweep $d}
    }
  }
  set root [__scratch_root]
  catch {file mkdir $root}
  set d [file normalize [file join $root _${tag}_[pid]]]
  file delete -force $d
  file mkdir $d
  if {[lsearch -exact $::__scratch_dirs $d] < 0} { lappend ::__scratch_dirs $d }
  return $d
}

## Drop a scratch dir early (optional; exit-time cleanup already covers it).
proc test_scratch_drop {d} {
  set i [lsearch -exact $::__scratch_dirs $d]
  if {$i >= 0} { set ::__scratch_dirs [lreplace $::__scratch_dirs $i $i] }
  catch {file delete -force $d}
}
