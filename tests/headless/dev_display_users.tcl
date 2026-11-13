## tests/headless/dev_display_users.tcl
##
## IS THE DEV DISPLAY IN USE BY SOMEONE ELSE? (backlog 2026-11-12, stages B and E)
##
## ONE implementation, two callers, so the rule cannot drift between them:
##   * tests/run_regression.tcl SOURCES this file (T1's display arm, T1_DISPLAY);
##   * tests/headless/xvfb_arm.sh RUNS it as a script (run_suites.sh,
##     full_audit.sh, gated_xschem.sh and every `xvfb_arm.sh --arm` suite):
##         tclsh dev_display_users.tcl [--root <pid>] <num> <state dir>
##     printing the holders as one line (t1_dev_display_who), or nothing when
##     there are none, exit 0; exit 2 on a usage error. --root names the run asking (the launcher's own pid), whose
##     ancestors and descendants are never counted; without it, this process.
## Row TL8 of test_t1_display_arm.tcl asserts that no other file in tests/
## defines these procs and that both callers reach this one.
##
## Two sessions on one machine share the persistent dev display, and a run that
## attaches to it while another run's windows are mapped there measures a
## display it does not own. So a caller in `auto` asks this question first and
## takes a private Xvfb when the answer is yes.
##
## ⚠ BY IDENTITY, NEVER BY PATTERN (CLAUDE.md, "Match shared namespaces by
## identity"). `pgrep -f run_regression` matches the shell that asked. This
## reads /proc/<pid>/comm, cmdline and environ, and a process counts only as
## one of these shapes:
##   * comm `xschem` whose environment names the dev display (`DISPLAY=:N`);
##   * a T1 (comm `tclsh*`, an argument whose tail is run_regression.tcl) or a
##     run_suites.sh / full_audit.sh (by comm, or as the script argument of a
##     shell), whose EFFECTIVE dev display is this one: its own
##     XSCHEM_DEVDISPLAY_DIR (else the default under XSCHEM_TEST_REAL_HOME,
##     else under HOME -- xvfb_arm.sh's own rule, which is devdisplay.sh's
##     with the throwaway home seen through) names the same state dir, and its
##     DEVDISPLAY_NUM (else 99) the same number. A run pointed somewhere else --
##     the old missing-state-dir trick, a fixture state dir, an AUDIT_DISPLAY
##     naming another display, `none` or `private`, or T1_DISPLAY=private -- is
##     not using this display, and is not counted.
##   * a run_suites.sh / full_audit.sh that has ALREADY CHOSEN says so in its
##     exec-time environment: xvfb_arm.sh re-execs a launcher it sends private
##     under xvfb-run with XSCHEM_XVFB_ARM=1 and DISPLAY set to the private
##     display. With XSCHEM_XVFB_ARM=1 in it, the launcher counts exactly when
##     that DISPLAY is this one (a nested launcher inheriting an attached
##     parent's arm is on this display; one sent private, or told none, is not).
##   * a T1 that has already gone private says so by identity too: a live Xvfb
##     whose environment carries XSCHEM_TEST_T1_XVFB_TAG=t1.<its pid>.<...>
##     (t1_private_xvfb's tag) is that run's own display, so the run is not
##     counted.
## ⚠ /proc/<pid>/environ is the EXEC-TIME environment, which is exactly what
## devdisplay.sh's own default reads, so the comparison is like for like.
## ⚠ SELF, ANCESTORS AND DESCENDANTS ARE NEVER COUNTED: a T1 launched from a
## suite that runs under run_suites.sh is part of that run, not a rival to it.
## Returns a list of {pid comm reason}.
proc t1_proc_words {pid what} {
  if {[catch {set f [open /proc/$pid/$what r]; fconfigure $f -translation binary
              set d [read $f]; close $f}]} { return {} }
  return [lrange [split $d \x00] 0 end-1]
}
proc t1_proc_envget {envl name} {
  set i [lsearch -glob $envl "$name=*"]
  if {$i < 0} { return {} }
  return [string range [lindex $envl $i] [string length "$name="] end]
}
proc t1_proc_stat {pid} {
  if {[catch {set f [open /proc/$pid/stat r]; set s [read $f]; close $f}]} { return {} }
  set r [string last ") " $s]
  if {$r < 0} { return {} }
  set l [string first "(" $s]
  return [list [string range $s [expr {$l + 1}] [expr {$r - 1}]] \
               [lindex [string range $s [expr {$r + 2}] end] 1]]
}
proc t1_dev_display_users {num state {me {}}} {
  set state [file normalize $state]
  if {$me eq {}} { set me [pid] }
  array set ppid {} ; array set comm {}
  foreach p [glob -nocomplain -directory /proc -tails {[0-9]*}] {
    if {![string is integer -strict $p]} continue
    set st [t1_proc_stat $p]
    if {![llength $st]} continue
    set comm($p) [lindex $st 0]
    set ppid($p) [lindex $st 1]
  }
  ## my ancestors
  set skip [list $me]
  set q $me
  for {set i 0} {$i < 64 && [info exists ppid($q)] && $ppid($q) > 1} {incr i} {
    set q $ppid($q) ; lappend skip $q
  }
  set users {} ; set cand {} ; set private {}
  foreach p [array names comm] {
    if {[lsearch -exact $skip $p] >= 0} continue
    ## my descendants
    set q $p ; set mine 0
    for {set i 0} {$i < 64 && [info exists ppid($q)] && $ppid($q) > 1} {incr i} {
      set q $ppid($q)
      if {$q == $me} { set mine 1 ; break }
    }
    if {$mine} continue
    set c $comm($p)
    set role {}
    if {$c eq {xschem}} {
      set role xschem
    } elseif {$c eq {Xvfb}} {
      set role xvfb
    } elseif {$c in {run_suites.sh full_audit.sh}} {
      set role $c
    } else {
      set args [t1_proc_words $p cmdline]
      if {[string match tclsh* $c]} {
        foreach a [lrange $args 1 end] {
          if {[file tail $a] eq {run_regression.tcl}} { set role T1 ; break }
        }
      } elseif {$c in {sh bash dash}} {
        foreach a [lrange $args 1 end] {
          if {[file tail $a] in {run_suites.sh full_audit.sh}} { set role [file tail $a] ; break }
        }
      }
    }
    if {$role eq {}} continue
    set e [t1_proc_words $p environ]
    set dpy_here [regexp "^:$num\(\\.\[0-9\]+\)?\$" [t1_proc_envget $e DISPLAY]]
    if {$role eq {xvfb}} {
      set tag [t1_proc_envget $e XSCHEM_TEST_T1_XVFB_TAG]
      if {[regexp {^t1\.([0-9]+)\.} $tag -> owner]} { lappend private $owner }
      continue
    }
    if {$role eq {xschem}} {
      if {$dpy_here} {
        lappend users [list $p xschem "an xschem with DISPLAY=:$num"]
      }
      continue
    }
    if {$role ne {T1} && [t1_proc_envget $e XSCHEM_XVFB_ARM] eq {1}} {
      if {$dpy_here} { lappend cand [list $p $role] }
      continue
    }
    set sd [t1_proc_envget $e XSCHEM_DEVDISPLAY_DIR]
    if {$sd eq {}} {
      set h [t1_proc_envget $e XSCHEM_TEST_REAL_HOME]
      if {$h eq {}} { set h [t1_proc_envget $e HOME] }
      if {$h eq {}} continue
      set sd [file join $h .claude xschem_dev_display]
    }
    if {[file normalize $sd] ne $state} continue
    set n [t1_proc_envget $e DEVDISPLAY_NUM]
    if {$n eq {}} { set n 99 }
    if {$n ne $num} continue
    if {$role eq {T1}} {
      if {[string tolower [string trim [t1_proc_envget $e T1_DISPLAY]]] eq {private}} continue
    } else {
      set ad [t1_proc_envget $e AUDIT_DISPLAY]
      if {$ad ni [list {} auto dev ":$num"]} continue
    }
    lappend cand [list $p $role]
  }
  foreach pr $cand {
    lassign $pr p role
    if {$role eq {T1} && [lsearch -exact $private $p] >= 0} continue
    lappend users [list $p $comm($p) "a $role run on the dev display's state dir"]
  }
  return [lsort -integer -index 0 $users]
}

## The holders as one phrase, for the notice both callers print:
## `pid P (comm: reason), pid Q (...)`.
proc t1_dev_display_who {users} {
  set who {}
  foreach u $users { lappend who "pid [lindex $u 0] ([lindex $u 1]: [lindex $u 2])" }
  return [join $who {, }]
}

## The script entry, for the shell launchers (xvfb_arm.sh). Sourced, this
## block does nothing: argv0 is then the sourcing script.
if {[info exists ::argv0] && [file normalize $::argv0] eq [file normalize [info script]]} {
  set root {}
  set av $::argv
  if {[lindex $av 0] eq {--root}} { set root [lindex $av 1] ; set av [lrange $av 2 end] }
  if {[llength $av] != 2 || ![string is integer -strict [lindex $av 0]]
      || ($root ne {} && ![string is integer -strict $root])} {
    puts stderr "usage: tclsh dev_display_users.tcl \[--root <pid>\] <display number> <state dir>"
    exit 2
  }
  set u [t1_dev_display_users [lindex $av 0] [lindex $av 1] $root]
  if {[llength $u]} { puts [t1_dev_display_who $u] }
  exit 0
}
