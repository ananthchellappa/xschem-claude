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

## ---------------------------------------------------------------------------
## Simulator-registry isolation (issue 1377)
## ---------------------------------------------------------------------------
## `src/xschem.tcl` calls `ase::sim_load_conf` once at startup, beside the other
## startup loaders, so EVERY `--script` suite begins with whatever is in the
## person's own `~/.xschem/ase_simulators` already registered, already in force,
## and already answering `ase::sim_status`. SIX suites pinned expectations
## against that answer and went red the day the developer registered a build:
## `test_ase_core` 7, `test_ase_persist` 5, `test_ase_final` 3,
## `test_ase_preflight` 2 and `test_ase_sod_case` 11 failures, plus
## `test_ase_final_gf180` which ABORTS on a registry naming a program that is
## not there. All six are ALL PASS under a HOME with no registry: same tree,
## same commit, same binary — see
## doc/claude/issues/1377-four-ase-suites-read-the-developers-simulator-registry.md
##
## ⚠ NOTHING HERE TOUCHES A FILE, AND THAT IS THE POINT. The obvious remedy —
## move `~/.xschem/ase_simulators` aside for the duration — writes the user's
## live data and loses it on any abort, and there are two aborts in this very
## defect's own measurements. The registry is already in MEMORY by the time a
## suite's first line runs, so clearing memory is both sufficient and the only
## safe move. The user's file is never read, written, renamed or backed up.
##
## ⚠ OPT-IN, NOT AUTOMATIC, and deliberately not folded into `test_scratch`.
## 171 suites source this file and 66 of them speak `ase::`; several are ABOUT
## the registry (`test_ase_simreg_0931`, `test_sim_casemode_registry`) and build
## their own fixtures in it. A clear that arrived as a side effect of asking for
## a directory would be a second invisible dependency replacing the first. The
## call is one greppable line at the top of a suite, which is also how a reader
## sees the suite DECLARING its independence instead of inheriting it.

## Forget every registered simulator, every measured capability, and the rc-layer
## seeds that could put one back. Safe to call more than once, safe to call in a
## tree where `ase.tcl` was never sourced, and never raises.
proc test_sim_registry_isolate {} {
  ## ⚠ AND NOTHING THIS SUITE REGISTERS MAY REACH THE DISK (2026-09-08).
  ## `ase::sim_register` / `ase::sim_unregister` now persist the registry at the
  ## moment it changes -- the user's ruling, and the repair for a Command-window
  ## registration that vanished at the next start. Their target is
  ## $::USER_CONF_DIR/ase_simulators, i.e. the developer's REAL list when a
  ## suite has not redirected it, so a suite that registers `/bin/sh` as a
  ## simulator would take away the build they actually use. Clearing the
  ## autosave seam is how this helper keeps the promise it already makes above:
  ## nothing here touches a file. A suite whose SUBJECT is the saving
  ## (test_ase_simreg_0931, test_ase_simdlg_0937) does not call this helper --
  ## it redirects ::USER_CONF_DIR into its own scratch instead, and keeps the
  ## real writer under test.
  catch {set ::ase::sim_autosave 0}
  ## the conf layer + the session layer + the choice in force
  catch {ase::sim_clear}
  ## measured capability answers are keyed on a resolved path: a cleared
  ## registry must not leave the OLD program's `altshow` verdict behind, which
  ## is what moved test_ase_core's C5b/C6/C8 save tier.
  catch {ase::sim_caps_clear}
  ## the rc layer, so nothing re-seeds from a workarea rc or a startup file
  set ::ASE_SIMULATORS {}
  set ::ASE_SIMULATOR  {}
  return {}
}
## ⚠ THE LAST THREE LINES ABOVE ARE FENCED BY `ISO1377b` IN test_ase_core.tcl,
## NOT BY THE PER-SUITE ROW. MEASURED on this box: at the instant a suite's first
## line runs the capability cache is EMPTY and both rc seeds are `{}`, so no HOME
## anyone can construct reds them — they guard a WORKAREA rc (layer 1 of the
## registry design) and a suite that probes before it isolates. ISO1377b builds
## that dirty precondition itself and demands all three clears undo it, because a
## line nothing can red is a line that quietly stops working.


## The registry's observable state, as the four things a suite actually depends
## on: how many entries exist, which is in force, which entry the resolver
## attributes an `ngspice` run to, and whether that answer came from the PATH or
## from the registry. An isolated suite reads {0 {} {} path}.
proc test_sim_registry_state {} {
  set n 0 ; set sel {} ; set entry {} ; set src {}
  catch {set n   [llength [ase::sim_list]]}
  catch {set sel [ase::sim_selected]}
  catch {
    set s [ase::sim_status ngspice]
    set entry [dict get $s entry]
    set src   [dict get $s source]
  }
  return [list $n $sel $entry $src]
}

## ---------------------------------------------------------------------------
## The stall watchdog (issue 1403)
## ---------------------------------------------------------------------------
## A SUITE THAT HANGS MUST SAY SO. On 2026-09-11 `test_ase_optier_0963` printed
## 86 of its 103 rows on the display arm, stopped after row N3, and sat there for
## EIGHT HOURS AND SEVEN MINUTES. A suite that is slow and a suite that is wedged
## emit byte-identical output -- none -- so nothing could tell them apart and
## nothing woke anyone. Write-up:
## doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md
##
## ⚠ THIS IS THE LAYER THAT WORKS WHEN NOTHING WRAPS THE RUN, which is the only
## gap the shipped drivers leave. `run_suites.sh` already wraps every arm in
## `timeout 200` and `full_audit.sh` in `timeout 300`, and both print a stall as
## its own named verdict. Neither can reach the command that is actually typed
## most often in a working session:
##
##     ./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl
##
## Nothing arms that and nothing bounds it -- and a hand-rolled `for` loop around
## it is exactly what was running for those eight hours. This watchdog rides
## INSIDE the suite, so it is armed by the suite being a suite rather than by the
## caller remembering anything.
##
## ⚠ IT IS NOT A GENERAL TIMEOUT AND MUST NOT BE SOLD AS ONE. A Tcl `after` timer
## fires only when the interpreter reaches the event loop. Measured 2026-09-11
## against this binary, three hang shapes:
##
##     hang in `vwait` / `tkwait`    watchdog FIRES         <- issue 1375's modal
##     hang in a blocking `exec`     watchdog does NOT fire
##     hang in a busy Tcl loop       watchdog does NOT fire
##
## The one class it covers is the class that bit: `descend_schematic()` calling
## `tcl_call("ask_save")` behind a gate that tests `has_x` alone, a `tkwait` under
## `--script` that nothing can click (issue 1375). For the other two shapes the
## answer is still an EXTERNAL bound -- `run_suites.sh`, or a bare `timeout` on
## the command -- and `tests/run_regression.tcl` now carries one on each of its
## four `exec` sites, which is where the other half of 1403 lives. Row **W13** of
## `test_suite_watchdog_1403.tcl` pins this limitation by measurement, so the
## paragraph cannot drift away from the code.
##
## ⚠ THE BUDGET IS DELIBERATELY LARGER THAN EITHER SHIPPED DRIVER'S. A run under
## one of them must report THAT driver's verdict, with that driver's number in
## it; a watchdog that preempted `run_suites.sh` at a different number would
## replace an accurate `TIMEOUT | <suite> (after 200s)` with a confusing one.
## This exists to bound the UNWRAPPED case, not to compete with the wrapped one.
##
##     XSCHEM_SUITE_WATCHDOG_MS   milliseconds; 0 disables; unset -> 900000
##
## On firing it prints ONE line -- to stdout AND to stderr, because a caller that
## captured only one of them would otherwise still see a silent death -- and
## exits **124**, the code `timeout(1)` uses and the code `run_suites.sh` already
## classifies as `TIMEOUT` (run_suites.sh:195). So a stall stays a NAMED OUTCOME
## in every reader that already exists, with no reader change required.
##
## ⚠ AND IT EXITS CLEANLY, WHICH AN EXTERNAL KILL CANNOT. `exit` here is the
## WRAPPED exit above, so the scratch dirs are removed on the way out. Measured
## on the same hang: killed externally by SIGTERM the binary takes its emergency
## -save path and leaves `/tmp/xschem_emergencysave_*` plus the suite's scratch
## dir behind. Row **W12** pins the cleanup.

## The budget, in ms. A malformed env value is ignored rather than obeyed: a
## typo must not silently disarm the only bound on an unwrapped run.
proc __wd_budget_ms {} {
  if {[info exists ::env(XSCHEM_SUITE_WATCHDOG_MS)]} {
    set v [string trim $::env(XSCHEM_SUITE_WATCHDOG_MS)]
    if {[string is integer -strict $v] && $v >= 0} { return $v }
  }
  return 900000
}

## The suite's own file, not this one. `info script` inside a sourced library
## names the LIBRARY; frame 1 is the outermost script, which is the suite.
proc __wd_suite_name {} {
  if {![catch {info frame 1} d] && [dict exists $d file]} {
    set f [dict get $d file]
    if {$f ne {}} { return [file tail $f] }
  }
  return [file tail [info script]]
}

## Remember the last line the suite wrote to stdout, so the watchdog can say
## WHERE it stopped rather than merely that it stopped. "86 of 103 rows, stops
## after row N3" is the finding; "it hung" is what an external timeout can
## already tell you. Cost is one string assignment per `puts`.
##
## Every `puts` form is handled: `puts s`, `puts -nonewline s`, `puts chan s`,
## `puts -nonewline chan s`. Only stdout is recorded -- a suite writing its own
## log through a file channel is not producing progress output. The delegation
## is `eval` on a properly-built list, which is quoting-safe and works on 8.4.
if {[info commands ::__wd_real_puts] eq {}} {
  rename ::puts ::__wd_real_puts
  proc ::puts {args} {
    catch {
      set a $args
      if {[string equal [lindex $a 0] {-nonewline}]} { set a [lrange $a 1 end] }
      if {[llength $a] == 1} {
        set ::__wd_last [string trim [lindex $a 0]]
      } elseif {[llength $a] == 2 &&
                [lsearch -exact {stdout ::stdout} [lindex $a 0]] >= 0} {
        set ::__wd_last [string trim [lindex $a 1]]
      }
    }
    eval [linsert $args 0 ::__wd_real_puts]
  }
}

## Fire: say it once on both streams, then leave through the wrapped exit.
proc __wd_fire {} {
  set last {}
  if {[info exists ::__wd_last] && [string trim $::__wd_last] ne {}} {
    set last $::__wd_last
  } else {
    set last {(the suite printed nothing)}
  }
  set who {a suite}
  if {[info exists ::__wd_suite]} { set who $::__wd_suite }
  set ms 0
  if {[info exists ::__wd_budget]} { set ms $::__wd_budget }
  set msg "###### WATCHDOG TIMEOUT ###### $who exceeded ${ms}ms -- last output: $last"
  catch { ::__wd_real_puts stdout $msg ; flush stdout }
  catch { ::__wd_real_puts stderr $msg ; flush stderr }
  ## 124 is timeout(1)'s code and run_suites.sh already reads it as TIMEOUT.
  exit 124
}

## Arm once. A second `source` of this file must not stack a second timer.
if {![info exists ::__wd_armed]} {
  set ::__wd_armed 1
  set ::__wd_budget [__wd_budget_ms]
  set ::__wd_suite  [__wd_suite_name]
  if {$::__wd_budget > 0} { catch {after $::__wd_budget ::__wd_fire} ::__wd_token }
}

## ---------------------------------------------------------------------------
## Whose HOME is this? (outsider fixes batch, DECISIONS.md D9 and D10)
## ---------------------------------------------------------------------------
## Every xschem start reads and writes $HOME/.xschem -- the clipboard, same-named
## netlists under simulations/, window geometry -- BEFORE a suite's first line
## runs, so nothing in this file can redirect those writes (measured in the S2a
## redirect study: a Tcl-side redirect still clobbered the real clipboard). The
## drivers therefore switch HOME for the whole run (`t1_arm_home` in
## tests/test_utility.tcl, tests/headless/test_home.sh for the shell drivers).
## What is left is the bare command no driver wraps,
##
##     ./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl
##
## and D9 settles it by POINTING, not by re-exec'ing: an un-armed suite says, once,
## on stderr, that it is using the tester's real HOME and which command would not.
##
## ⚠ THE LINE MUST NEVER BE COUNTED. Every reader that sees it -- T1's
## summarize_all (`FAIL$`, `GOLD?$`, `RESULT?$`, `^FATAL`), tests/banner_rule.tcl,
## run_suites.sh and full_audit.sh's classifier EREs -- keys on a column-0 or an
## end-of-line shape, so it starts with `note:` and ends with the fixed word `one`
## whatever the suite is called. test_scratch_home_note.tcl holds both ends of it
## against those readers' own patterns.

## Is this run under a test home the harness armed? Exactly D9's rule:
##   * HOME's basename is `xschem-test-home.<pid>.<suffix>` (the one contract
##     regex: t1_home_pattern in tests/test_utility.tcl, _TH_NAME_RE in
##     tests/headless/test_home.sh) AND
##     XSCHEM_TEST_REAL_HOME is set (a driver's throwaway, or a nested run inside
##     one), OR
##   * XSCHEM_TEST_HOME is set -- `real` or a custom directory, the D6 opt-out,
##     whose driver prints its own banner on every run.
## An empty value counts as unset, the way the shell drivers read `${VAR:-}`.
proc __scratch_env {name} {
  if {[info exists ::env($name)]} { return $::env($name) }
  return {}
}
proc __scratch_home_armed {} {
  if {[__scratch_env XSCHEM_TEST_HOME] ne {}} { return 1 }
  set h [__scratch_env HOME]
  if {$h ne {} && [__scratch_env XSCHEM_TEST_REAL_HOME] ne {} &&
      [regexp {^xschem-test-home\.[0-9]+\.[A-Za-z0-9]+$} [file tail $h]]} { return 1 }
  return 0
}

## The tester's REAL home, for READ-ONLY fixture lookups (D10): the fork ngspice
## under ~/dev, the mixed-signal reference artifacts under ~/.xschem/simulations.
## Under a driver HOME is a throwaway that holds none of them, so a suite that
## looked there would lose those rows without a word -- measured, 76 checks
## becoming 70 in test_ase_converge_1459, still ALL PASS.
##
## ⚠ READ-ONLY. Nothing may be written under the path this returns. A suite that
## wants somewhere to write uses `test_scratch`; a suite that wants a config
## copies the file OUT of here into its own scratch.
##
## XSCHEM_TEST_REAL_HOME is honoured only as what D5 says it is -- an absolute,
## existing directory. Anything else (a stray `=1` in someone's shell) falls back
## to HOME, and the rows that then find nothing say so through their `skip:` line,
## which names the path they looked in.
proc test_real_home {} {
  set r [__scratch_env XSCHEM_TEST_REAL_HOME]
  if {$r ne {} && [file pathtype $r] eq {absolute} && [file isdirectory $r]} {
    return $r
  }
  return [__scratch_env HOME]
}

## The one line, once per process however many times this file is sourced.
if {![info exists ::__scratch_home_noted]} {
  set ::__scratch_home_noted 1
  if {![__scratch_home_armed]} {
    set __n [file rootname $::__wd_suite]
    if {$__n eq {}} { set __n <suite> }
    catch {
      ::__wd_real_puts stderr "note: this suite is using your real HOME;\
 tests/headless/run_suites.sh $__n gives it a throwaway one"
      flush stderr
    }
    unset __n
  }
}
