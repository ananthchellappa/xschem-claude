#
#  File: xschem_test_utility.tcl
#
#  This file is part of XSCHEM,
#  a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
#  simulation.
#  Copyright (C) 1998-2022 Stefan Frederik Schippers
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

set OS [lindex $tcl_platform(os) 0]

# ---------------------------------------------------------------------------
# THE TEST HOME: every run gets a throwaway HOME unless it asks otherwise
# (outsider fixes batch; doc/claude/outsider_fixes_batch/DECISIONS.md D4-D8)
# ---------------------------------------------------------------------------
# Nothing in this harness used to point xschem at anything but the tester's
# real home, so T1 overwrote their xschem clipboard, same-named netlists in
# ~/.xschem/simulations and saved window positions, and `tclsh netlisting.tcl`
# with no built binary ran an installed xschem against the real ~/.xschem --
# measured by the outsider audit (F6, F7, F8, F10). A per-suite redirect cannot
# fix it: C fixes the clipboard path at startup, before a script's first line.
# HOME has to be different when xschem STARTS, so the switch is made here, for
# the whole driver process, and every child inherits it.
#
# ⚠ IT RUNS AT SOURCE TIME, ON PURPOSE. That covers `tclsh run_regression.tcl`
# AND the documented single-case `tclsh netlisting.tcl`, which is the command
# F10 was measured with. It is idempotent and nesting-aware, so a case run by
# T1 reuses T1's throwaway instead of making its own.
#
# ⚠ AND IT IS A NO-OP INSIDE AN XSCHEM INTERPRETER. Switching HOME after xschem
# has started splits C's startup-cached paths (the clipboard, `~/` expansion)
# from Tcl's, which is worse than not switching. Checked 2026-09-18: nothing in
# this tree sources this file inside xschem (test_regression_concurrency_1476
# deliberately sources it only in child tclsh processes), so the guard is a
# promise about the future, not a patch over a present caller.
#
# THE MODES, chosen by XSCHEM_TEST_HOME:
#   unset          a throwaway `${TMPDIR:-/tmp}/xschem-test-home.<pid>.XXXXXX`,
#                  deleted by its owner when the run ends.
#   real           HOME is left alone, with a loud banner on every run.
#   <absolute dir> that directory is HOME and is NEVER deleted -- for
#                  reproducing a bug against a copy of someone's configuration.
# XSCHEM_TEST_KEEP_HOME=1 keeps a throwaway and prints where it is.
#
# ⚠ XSCHEM_TEST_REAL_HOME CARRIES A PATH AND NOTHING ELSE. An earlier study used
# `XSCHEM_TEST_REAL_HOME=1` as an opt-out, and read loosely that value would make
# a run "nested", keep the real HOME and carry `1/.claude/...` paths. So a value
# that is not an absolute, existing, non-throwaway directory is refused loudly.
#
# ⚠ THE DANGEROUS LINES ARE OWNERSHIP AND DELETION (the S2a critic's point 1).
# Only the process that created a throwaway deletes it, only that exact path,
# and only after re-checking it is where it was made and is not the real home.
# A run killed before it could delete is collected by the NEXT run's sweep --
# same uid, owner dead, older than 300 s -- and "a leftover survives" is always
# the failure direction, never "a live run's home is deleted".

## One pattern for every reader: the sweep, the nesting test, the delete.
## mktemp's suffix is mixed case, which the S2a critic measured harmless for
## HOME (the lowercase rule applies to checkout paths, not to this).
set ::t1_home_pattern {^xschem-test-home\.([0-9]+)\.[A-Za-z0-9]+$}
set ::t1_home_repo [file normalize [file join [file dirname [file normalize [info script]]] ..]]

proc t1_home_refuse {msg} {
  puts stderr "!! test home REFUSED: $msg"
  puts stderr "!! Nothing was run, and your real HOME was not used in its place\
 (tests/test_utility.tcl, t1_arm_home)."
  flush stderr
  exit 3
}

## Liveness. Conservative where it cannot tell: an unknown answer is "alive",
## so neither the nesting test nor the sweep can act on a guess.
proc t1_home_pid_alive {p} {
  if {![string is integer -strict $p] || $p <= 0} { return 0 }
  if {[file isdirectory /proc/self]} { return [file isdirectory /proc/$p] }
  if {[catch {exec kill -0 $p} err]} {
    return [expr {![string match -nocase {*no such process*} $err]}]
  }
  return 1
}
## Running, as opposed to a zombie nobody has reaped yet -- our own killed
## Xvfb stays in /proc as state Z until Tcl reaps it, and that is not "alive".
proc t1_home_pid_running {p} {
  if {![t1_home_pid_alive $p]} { return 0 }
  if {[catch {set f [open /proc/$p/stat r]; set s [read $f]; close $f}]} { return 1 }
  set i [string last ")" $s]
  return [expr {[string trim [string index [string range $s [expr {$i + 1}] end] 1]] ne "Z"}]
}
## argv[0]'s basename, or {} -- identity, not mere liveness, before any kill.
proc t1_home_pid_prog {p} {
  if {[catch {set f [open /proc/$p/cmdline r]; fconfigure $f -translation binary
              set c [read $f]; close $f}]} { return {} }
  return [file tail [lindex [split $c \x00] 0]]
}
proc t1_home_read_int {f} {
  if {[catch {set h [open $f r]; set v [string trim [read $h]]; close $h}]} { return {} }
  if {![string is integer -strict $v] || $v <= 0} { return {} }
  return $v
}
proc t1_home_kill {p} {
  catch {exec kill -TERM $p}
  for {set i 0} {$i < 30 && [t1_home_pid_running $p]} {incr i} { after 100 }
  if {[t1_home_pid_running $p]} { catch {exec kill -KILL $p} }
}

## A path with EVERY component resolved, the last one included (DECISIONS
## D13.5). `file normalize` resolves symlinks in all components BUT the last,
## so on its own it called a symlink to the real home a different directory
## (the round-1 safety refuter: XSCHEM_TEST_HOME=<a link to the real HOME> was
## accepted as "custom" and the run wrote into the real home), and it made a
## symlinked TMPDIR -- /tmp itself on macOS -- refuse every arm, because the
## mktemp result resolved and the root it was compared with did not (measured
## on the round-1 build: refused, and the fresh directory leaked). Resolving a
## child of the path resolves the path itself. A path that does not exist is
## returned normalized.
proc t1_home_resolve {p} {
  if {$p eq {}} { return {} }
  set n [file normalize $p]
  if {![file exists $n]} { return $n }
  return [file dirname [file normalize [file join $n __t1_home_resolve__]]]
}

## The temp root, ${TMPDIR:-/tmp}, fully resolved, so that the delete's
## re-check, the sweep's glob and a recorded process's HOME all compare like
## with like.
proc t1_home_root {} {
  set r /tmp
  if {[info exists ::env(TMPDIR)] && $::env(TMPDIR) ne {}} { set r $::env(TMPDIR) }
  return [t1_home_resolve $r]
}

## Every symlink followed, the last component's included, and the target NEED
## NOT EXIST -- a dangling link into the real home is still a link into it,
## which t1_home_resolve (it returns a missing path merely normalized) cannot
## say. `readlink -m` is GNU; where it is missing, t1_home_resolve.
proc t1_home_resolve_any {p} {
  if {![catch {exec readlink -m -- $p} r] && [string trim $r] ne {}} { return [string trim $r] }
  return [t1_home_resolve $p]
}

## D17.4: is $h a directory DIRECTLY under the temp root, compared fully
## resolved? The fresh arm makes its throwaway there, and the shell's handoff
## requires it; nesting must too, or a throwaway-shaped directory planted
## anywhere -- the round-2 safety refuter's `<real home>/xschem-test-home.1.forged`
## -- is taken for a live run's home and used as HOME inside the real one.
proc t1_home_under_root {h} {
  if {$h eq {} || ![file isdirectory $h]} { return 0 }
  return [expr {[file dirname [t1_home_resolve $h]] eq [t1_home_root]}]
}

## D17.5 + D20.4: why home $dir may not be used because something the harness
## WRITES under it resolves into the real home $realr (resolved), or {} when
## nothing does. xschem writes under .xschem (the clipboard, simulations/,
## geometry), openbox under .cache, the gate under .claude -- so each of those
## is checked: the directory itself, every entry in it, and for .xschem one
## level further down, where simulations/clean.spice lives. A "copy of someone's
## configuration" whose .xschem is a SYMLINK into the real home wrote the
## tester's own files while the banner said "your HOME is untouched" (the
## round-2 safety refuter); so did one whose .cache, or whose
## simulations/{clean,short}.spice, were symlinks (the round-3 one). Only a
## symlink can lead out of a real directory of $dir, so only symlinks are
## resolved. Allowed only where $dir is itself inside the real home and the entry
## stays inside $dir -- the case the banner already announces as writing there.
## Used for a custom home and, since D20.4, for a NESTED one: a throwaway-shaped
## HOME planted under the temp root with such a link was reused as nested.
## test_home.sh's _th_custom_escapes is the same rule; rows L15 and L19 of
## test_home_isolation.tcl hold the two to one answer.
proc t1_home_custom_escapes {dir realr} {
  set cr [t1_home_resolve $dir]
  set cands {}
  foreach top {.xschem .cache .claude} {
    set x [file join $dir $top]
    lappend cands $x
    if {![file isdirectory $x]} { continue }
    foreach f [glob -nocomplain -directory $x -- * .*] {
      if {[file tail $f] in {. ..}} { continue }
      lappend cands $f
      if {$top eq ".xschem" && [file isdirectory $f]} {
        foreach g [glob -nocomplain -directory $f -- * .*] {
          if {[file tail $g] ni {. ..}} { lappend cands $g }
        }
      }
    }
  }
  foreach c $cands {
    if {[catch {file lstat $c st}] || $st(type) ne "link"} { continue }
    set r [t1_home_resolve_any $c]
    if {[string first "$realr/" "$r/"] != 0} { continue }
    if {[string first "$realr/" "$cr/"] == 0 && [string first "$cr/" "$r/"] == 0} { continue }
    return "its [string range $c [expr {[string length $dir] + 1}] end] resolves to $r, inside your real HOME ($realr) -- this run would write your own xschem files there. Copy the directory instead of linking it"
  }
  return {}
}

## Does ANY component of $p look like a throwaway? The same test as
## test_home.sh's _th_path_has_throwaway: a directory INSIDE a throwaway is
## deleted with it, so it can be neither the real home nor a custom one. The
## resolved spelling is checked too: a symlink INTO a throwaway is one.
proc t1_home_has_throwaway {p} {
  foreach c [concat [file split $p] [file split [file normalize $p]] [file split [t1_home_resolve $p]]] {
    if {[regexp $::t1_home_pattern $c]} { return 1 }
  }
  return 0
}

## Why $v may not be XSCHEM_TEST_REAL_HOME, or {} when it may.
proc t1_home_bad_real {v} {
  if {$v eq {}} { return "it is empty" }
  if {[string index $v 0] ne "/"} { return "it is not an absolute path" }
  if {![file isdirectory $v]} { return "it is not an existing directory" }
  if {[t1_home_has_throwaway $v]} {
    return "it is itself, or is inside, a test throwaway home"
  }
  return {}
}

## ---------------------------------------------------------------------------
## WHO OWNS A THROWAWAY, AND WHEN IS THAT OWNER DEAD (DECISIONS D13.6)
## ---------------------------------------------------------------------------
## `.owner` is ONE line, `<pid> <boot_id> <pidns>`:
##   boot_id  /proc/sys/kernel/random/boot_id
##   pidns    the link text of the owner's /proc/<pid>/ns/pid (`pid:[4026531836]`)
## each `-` where it cannot be read. A bare pid -- the round-1 format -- reads
## as `<pid> - -`.
## ⚠ A PID ALONE IS NOT AN IDENTITY. The round-1 safety refuter measured a LIVE
## run inside `bwrap --unshare-pid`, sharing TMPDIR, having its home swept by a
## host run: its .owner said 1504, which is that run's pid in ITS namespace and
## a dead pid in the host's. And a TMPDIR that survives a reboot carries pids
## that mean nothing any more. So the owner is DEAD when either
##   * its boot_id differs from the current one, or
##   * its boot_id AND pidns both match the sweeper's own, and the pid is not
##     alive.
## A matching boot_id with a DIFFERENT pidns (a container, bwrap, flatpak) is
## FOREIGN: its liveness cannot be seen from here, so it is never swept unless
## the entry is older than 7 days. Where a field is `-`, the old rule (the pid
## is not alive) applies -- except that a pidns known to differ stays foreign
## when the boot_id is `-` (see t1_home_owner_state). test_home.sh implements
## the same rule; section L of tests/headless/test_home_isolation.tcl locks
## that the two agree (rows L6 and L7).
##
## /proc/self rather than /proc/<pid>: inside a pid namespace [pid] is the
## namespace's number, and a /proc mounted for another namespace would name a
## different process by it. For the process itself the two are the same link.
proc t1_home_boot_id {} {
  if {[info exists ::t1_home_bootid]} { return $::t1_home_bootid }
  set b -
  catch {set f [open /proc/sys/kernel/random/boot_id r]; set b [string trim [read $f]]; close $f}
  if {$b eq {} || [regexp {\s} $b]} { set b - }
  return [set ::t1_home_bootid $b]
}
proc t1_home_pidns {} {
  if {[info exists ::t1_home_nsid]} { return $::t1_home_nsid }
  set n -
  catch {set n [file readlink /proc/self/ns/pid]}
  if {$n eq {} || [regexp {\s} $n]} { set n - }
  return [set ::t1_home_nsid $n]
}
## The line this process writes into a throwaway it creates.
proc t1_home_owner_line {} { return "[pid] [t1_home_boot_id] [t1_home_pidns]" }
## {pid boot_id pidns} from $d/.owner, `-` for a field it lacks; {} when the
## first field is not a plain decimal pid (or there is no readable .owner).
proc t1_home_read_owner {d} {
  if {[catch {set h [open [file join $d .owner] r]; set l [gets $h]; close $h}]} { return {} }
  set f [regexp -all -inline {\S+} $l]
  set p [lindex $f 0]
  if {![regexp {^[1-9][0-9]{0,9}$} $p]} { return {} }
  set b [lindex $f 1] ; if {$b eq {}} { set b - }
  set n [lindex $f 2] ; if {$n eq {}} { set n - }
  return [list $p $b $n]
}
## alive | dead | foreign, for an owner record {pid boot_id pidns} -- the rule
## above, in order: a boot_id known on both sides and differing is dead whatever
## the pid; else a pidns known on both sides and differing is foreign; else the
## pid's liveness decides (the old rule), and our own pid is alive.
## ⚠ ONE COMBINATION THE WORDING LEAVES OPEN: boot_id `-` with a pidns known to
## differ. Read as "a `-` field falls back to the old rule", a host sweep would
## judge a container's pid by the HOST's /proc and delete a live run's home --
## the very defect D13.6 removes. Read as "not known to be another boot, and
## known to be another namespace", it is foreign and survives a week. The
## second is the contract's standing failure direction (a leftover survives,
## never a live home deleted), and it is what test_home.sh does; row L7 of
## test_home_isolation.tcl holds the two sweeps to one answer on it.
proc t1_home_owner_state {rec} {
  lassign $rec p b n
  set mb [t1_home_boot_id] ; set mn [t1_home_pidns]
  if {$b ne "-" && $mb ne "-" && $b ne $mb} { return dead }
  if {$n ne "-" && $mn ne "-" && $n ne $mn} { return foreign }
  if {$p == [pid] || [t1_home_pid_alive $p]} { return alive }
  return dead
}

## Is $h a throwaway whose owner is still running? One of the three nesting
## conditions; XSCHEM_TEST_REAL_HOME being set is checked by the caller.
## ⚠ "Running" by the SAME rule the sweep uses (D13.6), not by the bare pid: a
## home from another boot whose pid happens to be alive again, or one owned in
## another pid namespace, must not be reused -- the sweep would call its owner
## dead and could delete it under the nested run. A fresh arm is the safe answer.
proc t1_home_live_throwaway {h} {
  if {$h eq {} || ![file isdirectory $h]} { return 0 }
  if {![regexp $::t1_home_pattern [file tail [file normalize $h]]]} { return 0 }
  set rec [t1_home_read_owner $h]
  if {$rec eq {}} { return 0 }
  return [expr {[t1_home_owner_state $rec] eq "alive"}]
}

## ---------------------------------------------------------------------------
## KILL ONLY WHAT CAN BE IDENTIFIED (DECISIONS D13.7)
## ---------------------------------------------------------------------------
## The HOME in a live process's environment, or {} when it cannot be read.
proc t1_home_pid_home {p} {
  if {![string is integer -strict $p] || $p <= 0} { return {} }
  if {[catch {set f [open /proc/$p/environ r]; fconfigure $f -translation binary
              set e [read $f]; close $f}]} { return {} }
  foreach kv [split $e \x00] {
    if {[string first HOME= $kv] == 0} { return [string range $kv 5 end] }
  }
  return {}
}
## Is $p running program $prog (argv[0]'s basename) with HOME exactly $d? A
## pid file outlives its process and pids recycle, so a name alone is not an
## identity: the round-1 safety refuter had both sweeps kill a LIVE foreign
## Xvfb and openbox named in a forged dead home's records. The private display
## and its WM are always started with HOME set to the directory that records
## them (run_regression.tcl t1_private_xvfb), so the record and the process
## name each other. "Exactly" is the same directory: the same string, or the
## same fully resolved path.
proc t1_home_pid_is {p prog d} {
  if {$p eq {} || $prog eq {} || ![t1_home_pid_running $p]} { return 0 }
  if {[t1_home_pid_prog $p] ne $prog} { return 0 }
  set h [t1_home_pid_home $p]
  if {$h eq {}} { return 0 }
  if {$h eq $d} { return 1 }
  return [expr {[file isdirectory $h] && [file isdirectory $d] && [t1_home_resolve $h] eq [t1_home_resolve $d]}]
}
## The private display's reapers (D13.15): each identified by its own record,
## $d/.xvfb/reaper.<pid>.pid (or the round-3 single `reaper.pid`), AND a command
## line naming both its marker and $d. More than one can be live: every attempt
## at a server has its own (D20.5), and a lost race makes two attempts.
proc t1_home_reapers_of {d} {
  set out {}
  foreach f [glob -nocomplain -directory [file join $d .xvfb] -- reaper*.pid] {
    set r [t1_home_read_int $f]
    if {$r eq {} || ![t1_home_pid_running $r]} { continue }
    if {[catch {set h [open /proc/$r/cmdline r]; fconfigure $h -translation binary
                set c [split [read $h] \x00]; close $h}]} { continue }
    if {[lsearch -exact $c xschem-t1-reaper] < 0 || [lsearch -exact $c $d] < 0} { continue }
    lappend out $r
  }
  return $out
}

## Kill a private display recorded in $d (DECISIONS D5/D8/D13.7):
## `.xvfb/reaper*.pid` for its reapers, `.xvfb/wm.pid` for its window manager and
## `.xvfb.pid` for the server -- each only if that pid is still running the
## program it was recorded as, WITH HOME = $d (the reaper: its marker and $d on
## its command line).
proc t1_home_kill_xvfb {d} {
  set sd [file join $d .xvfb]
  ## The reapers first, so that none is itself racing to kill what follows.
  foreach r [t1_home_reapers_of $d] { t1_home_kill $r }
  foreach f [glob -nocomplain -directory $sd -- reaper*.pid] { catch {file delete -- $f} }
  set w [t1_home_read_int [file join $sd wm.pid]]
  set wname {}
  catch {set h [open [file join $sd wm] r]; set wname [string trim [read $h]]; close $h}
  if {[t1_home_pid_is $w $wname $d]} { t1_home_kill $w }
  set x [t1_home_read_int [file join $d .xvfb.pid]]
  if {[t1_home_pid_is $x Xvfb $d]} {
    t1_home_kill $x
    ## A SIGKILLed server leaves its lock behind, and the private arm skips a
    ## number with a lock on it -- so a lock naming the pid just killed goes too.
    set n {}
    catch {set h [open [file join $sd display] r]; set n [string trim [read $h]]; close $h}
    set n [string trimleft $n :]
    if {[string is integer -strict $n] && [t1_home_read_int /tmp/.X$n-lock] eq $x} {
      catch {file delete -- /tmp/.X$n-lock}
    }
  }
  catch {file delete -- [file join $d .xvfb.pid]}
}

## Kill a GUI-gate panel whose control dir is $gd -- the one a SHELL driver
## launches inside its own throwaway when the real gate dir does not exist (D7).
## Identified exactly as test_home.sh's _th_kill_panel_in does it: its pid is in
## widget.pid or widget.launching AND its command line names both
## gui_gate_widget and that exact dir, so a shared panel is never touched. T1
## launches no panel; this is here so a T1 sweeping a dead shell run's home does
## not orphan one (the two sweeps are one contract).
proc t1_home_kill_panel_in {gd} {
  foreach f [list [file join $gd widget.pid] [file join $gd widget.launching]] {
    if {[catch {set h [open $f r]; set v [read $h 64]; close $h}]} { continue }
    set p [lindex [split [string trim $v] " \t\n"] 0]
    if {![string is integer -strict $p] || $p <= 0 || ![t1_home_pid_running $p]} { continue }
    if {[catch {set h [open /proc/$p/cmdline r]; fconfigure $h -translation binary
                set c [string map [list \x00 { }] [read $h]]; close $h}]} { continue }
    ## literal, not a glob: `*gui_gate_widget*"$gd"*` in the shell
    set w [string first gui_gate_widget $c]
    if {$w < 0 || [string first $gd $c [expr {$w + 15}]] < 0} { continue }
    t1_home_kill $p
  }
}

## Sweep dead runs' throwaways out of $root (DECISIONS D5, D13.6): an entry is
## removed only when it is a real directory (never a symlink), owned by $uid,
## matches the pattern and carries no `.keep`, and its owner is
##   dead     (t1_home_owner_state) and the entry is older than $age seconds, or
##   foreign  (another pid namespace, same boot) and it is older than 7 days.
## Where liveness cannot be established (no /proc) NOTHING is swept -- the same
## contract as sweep_dead_run_dirs below.
## $uid is a parameter so that the "another uid's entry" rule can be tested
## without root: nothing unprivileged can create a directory another uid owns.
set ::t1_home_foreign_age [expr {7 * 24 * 3600}]
proc t1_home_sweep {root {uid {}} {age 300}} {
  if {![file isdirectory /proc/self] || ![file isdirectory $root]} { return {} }
  if {$uid eq {}} {
    if {[catch {exec id -u} uid] || ![string is integer -strict [string trim $uid]]} { return {} }
    set uid [string trim $uid]
  }
  set now [clock seconds]
  set swept {}
  foreach d [glob -nocomplain -directory $root -- xschem-test-home.*] {
    set base [file tail $d]
    if {![regexp $::t1_home_pattern $base -> npid]} { continue }
    if {[catch {file lstat $d st}]} { continue }
    if {$st(type) ne "directory" || $st(uid) != $uid} { continue }
    if {[file exists [file join $d .keep]]} { continue }
    set rec [t1_home_read_owner $d]
    if {$rec eq {}} { set rec [list $npid - -] }
    set state [t1_home_owner_state $rec]
    set old [expr {$now - $st(mtime)}]
    if {$state eq "alive"} { continue }
    if {$state eq "foreign" && $old <= $::t1_home_foreign_age} { continue }
    if {$state eq "dead" && $old <= $age} { continue }
    catch {t1_home_kill_xvfb $d}
    catch {t1_home_kill_panel_in [file join $d .claude gui_test_gate]}
    if {![catch {file delete -force -- $d}]} { lappend swept $base }
  }
  if {[llength $swept]} {
    puts "test home: swept [llength $swept] dead run(s)' throwaway home(s) from $root ([join $swept {, }])"
  }
  return $swept
}

## The environment a LONG-LIVED process must be started with (DECISIONS D7,
## D13.16): the one from BEFORE the switch, so that a persistent display started
## by this run does not outlive a HOME that is about to be deleted -- which is
## exactly the shape of the orphan the outsider audit left holding :99. {} when
## nothing was switched. Used as `exec {*}[t1_home_preswitch_env] <cmd>`, and it
## is `env -i` plus the whole environment, never a patch on this one.
## ⚠ A SNAPSHOT, NOT "THIS ENVIRONMENT WITH HOME PUT BACK" (D13.16). The round-1
## regression refuter found the auto-started Xvfb and openbox carrying
## XSCHEM_TEST_REAL_HOME, the carried XSCHEM_DEVDISPLAY_DIR and the command-scope
## GIT_CONFIG_* safe.directory -- harness state, living on inside a process that
## outlives the run. So the arm snapshots the environment before it changes a
## thing (or takes the one an enclosing arm exported, XSCHEM_TEST_PRE_ENV,
## below), and t1_home_clean_env strips from it whatever an OUTER arm had put
## there. A nested run with no exported snapshot has only its parent's switched
## environment, and gets the same cleaning of that.
proc t1_home_preswitch_env {} {
  if {![info exists ::t1_home(pre)] || [llength $::t1_home(pre)] == 0} { return {} }
  set e [list env -i]
  foreach {k v} $::t1_home(pre) { lappend e "$k=$v" }
  return $e
}
## ⚠ ONE SNAPSHOT FOR THE WHOLE TREE OF RUNS, SHARED WITH test_home.sh. The
## outermost arm -- the one entered with no XSCHEM_TEST_REAL_HOME -- exports
## the environment it found as XSCHEM_TEST_PRE_ENV: base64 of the NUL-separated
## NAME=VALUE list, every XSCHEM_TEST_* removed (the same encoding the shell
## writes with `env -0 | base64`). An arm under an enclosing one keeps an
## inherited snapshot, so a Tcl run nested in a shell driver, or a shell driver
## in T1, starts its long-lived processes from the TESTER's environment rather
## than a reconstruction of it. Past 64 KiB it is not exported (a single
## environment string past MAX_ARG_STRLEN makes every later exec fail E2BIG),
## and the arm falls back to t1_home_clean_env of what it has.
set ::t1_home_pre_env_max 65536
proc t1_home_env_encode {pairs} {
  set parts {}
  foreach {k v} $pairs { if {![string match XSCHEM_TEST_* $k]} { lappend parts "$k=$v" } }
  if {![llength $parts]} { return {} }
  return [binary encode base64 [encoding convertto utf-8 "[join $parts \x00]\x00"]]
}
## {name value ...} from an XSCHEM_TEST_PRE_ENV value, or {} if it does not decode.
proc t1_home_env_decode {s} {
  if {[catch {encoding convertfrom utf-8 [binary decode base64 $s]} raw]} { return {} }
  set out {}
  foreach e [split $raw \x00] {
    set i [string first = $e]
    if {$i <= 0} { continue }
    lappend out [string range $e 0 [expr {$i - 1}]] [string range $e [expr {$i + 1}] end]
  }
  return $out
}
## The inherited snapshot, if this arm is enclosed by another and one was
## exported; {} otherwise.
proc t1_home_inherited_snap {} {
  if {![info exists ::env(XSCHEM_TEST_PRE_ENV)] || $::env(XSCHEM_TEST_PRE_ENV) eq {}} { return {} }
  return [t1_home_env_decode $::env(XSCHEM_TEST_PRE_ENV)]
}

## {name value ...}, sorted by name: $snap (an `array get ::env`) with the real
## home as HOME and nothing any arm put there -- no XSCHEM_TEST_*, XDG_* back to
## the originals an arm recorded (or unset if one points into a throwaway with
## no record), this checkout's safe.directory entry out of GIT_CONFIG_*, and a
## harness path dropped when it names a throwaway or merely spells the default
## that HOME=$real gives anyway (so a carried one the tester never set is gone,
## and one they set to anything else is kept).
proc t1_home_clean_env {snap real} {
  array set e $snap
  foreach k {XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME} {
    if {[info exists e(XSCHEM_TEST_PRE_$k)]} {
      set e($k) $e(XSCHEM_TEST_PRE_$k)
    } elseif {[info exists e($k)] && [t1_home_has_throwaway $e($k)]} {
      unset e($k)
    }
  }
  foreach k [array names e XSCHEM_TEST_*] { unset e($k) }
  set e(HOME) $real
  foreach {k sub} {XSCHEM_DEVDISPLAY_DIR .claude/xschem_dev_display
                   GUI_GATE_DIR .claude/gui_test_gate XAUTHORITY .Xauthority} {
    if {[info exists e($k)] && ($e($k) eq {} || $e($k) eq [file join $real $sub]
                                || [t1_home_has_throwaway $e($k)])} {
      unset e($k)
    }
  }
  if {[info exists e(GIT_CONFIG_COUNT)] && [regexp {^[0-9]+$} $e(GIT_CONFIG_COUNT)]} {
    set keep {}
    for {set i 0} {$i < $e(GIT_CONFIG_COUNT)} {incr i} {
      set k {} ; set v {}
      if {[info exists e(GIT_CONFIG_KEY_$i)]} { set k $e(GIT_CONFIG_KEY_$i) ; unset e(GIT_CONFIG_KEY_$i) }
      if {[info exists e(GIT_CONFIG_VALUE_$i)]} { set v $e(GIT_CONFIG_VALUE_$i) ; unset e(GIT_CONFIG_VALUE_$i) }
      if {!($k eq "safe.directory" && $v eq $::t1_home_repo)} { lappend keep $k $v }
    }
    set j 0
    foreach {k v} $keep { set e(GIT_CONFIG_KEY_$j) $k ; set e(GIT_CONFIG_VALUE_$j) $v ; incr j }
    if {$j} { set e(GIT_CONFIG_COUNT) $j } else { unset e(GIT_CONFIG_COUNT) }
  }
  return [lsort -stride 2 -index 0 [array get e]]
}

## throwaway | real | custom -- the word T1-RUN-BEGIN's `home=` field carries.
proc t1_home_kind {} {
  if {[info exists ::t1_home(kind)]} { return $::t1_home(kind) }
  return unarmed
}

## XSCHEM_TEST_KEEP_HOME=1 marks an owned directory `.keep` AT ARM TIME
## (DECISIONS D13.9), not at exit: a run that is killed never reaches its exit,
## and that crash is exactly the case in which keeping the home matters (the
## round-1 safety refuter measured a killed KEEP run swept 300 s later, in both
## languages). Exactly `1`, as D5 spells it and test_home.sh reads it: one
## contract, so `=yes` means the same thing (nothing) in both languages.
proc t1_home_keep_asked {} {
  expr {[info exists ::env(XSCHEM_TEST_KEEP_HOME)] && $::env(XSCHEM_TEST_KEEP_HOME) eq "1"}
}
proc t1_home_keep_now {d} {
  if {![t1_home_keep_asked]} { return }
  if {[catch {close [open [file join $d .keep] w]} e]} {
    puts "!! test home: could not mark $d kept ($e); a killed run's home may be swept"
  }
}

## A directory this process owns and deletes at exit: its throwaway HOME, or --
## in a nested, custom or real run -- one made on demand, with the same name
## and `.owner`, so that the sweep reaches whatever is recorded in it (the
## private display's pid) if this run is killed. {} if none can be made.
proc t1_home_run_dir {} {
  if {[info exists ::t1_home(owned)] && $::t1_home(owned) ne {}} { return $::t1_home(owned) }
  set root [t1_home_root]
  if {[catch {exec mktemp -d [file join $root xschem-test-home.[pid].XXXXXX]} d]} { return {} }
  set d [file normalize [string trim $d]]
  if {[catch {set h [open [file join $d .owner] w]; puts $h [t1_home_owner_line]; close $h}]} {
    catch {file delete -force -- $d}
    return {}
  }
  t1_home_keep_now $d
  set ::t1_home(owned) $d
  set ::t1_home(owned_root) $root
  set ::t1_home(owned_is_home) 0
  t1_home_hook_exit
  return $d
}

## The owner's delete (DECISIONS D5). Kills the private display first, then
## removes EXACTLY the path it created -- after re-checking that it is still
## directly under the temp root it was made in, still matches the pattern,
## still names this pid as owner, and is neither the real home nor an ancestor
## of it. Anything else is refused and left for a human, never guessed at.
## run_regression.tcl calls this after its T1-RUN-END trailer; every owner also
## reaches it through `exit` (a single case has no trailer), and it is a no-op
## the second time and in any process that owns nothing.
proc t1_home_release {} {
  if {![info exists ::t1_home(owned)] || $::t1_home(owned) eq {}} { return }
  set d $::t1_home(owned)
  set ::t1_home(owned) {}
  catch {t1_home_kill_xvfb $d}
  set is_home [expr {[info exists ::t1_home(owned_is_home)] && $::t1_home(owned_is_home)}]
  ## Put HOME back first: nothing may go on pointing at a directory being deleted.
  ## `restore` holds the snapshot's own values of the names the arm changed.
  if {$is_home && [info exists ::t1_home(restore)]} {
    foreach {k v} $::t1_home(restore) {
      if {[lindex $v 0] eq "unset"} { catch {unset ::env($k)} } else { set ::env($k) [lindex $v 1] }
    }
  }
  ## ⚠ `.keep` exempts it from every later sweep: a kept home that the next
  ## run deleted 300 s later would not have been kept. Written at arm time
  ## (t1_home_keep_now); written again here in case it was removed meanwhile.
  if {[t1_home_keep_asked]} {
    catch {close [open [file join $d .keep] w]}
    puts "test home: kept $d as asked (XSCHEM_TEST_KEEP_HOME); nothing sweeps it, so delete it yourself"
    return
  }
  set n [file normalize $d]
  set real {}
  if {[info exists ::t1_home(real)]} { set real $::t1_home(real) }
  set why {}
  if {[file dirname $n] ne $::t1_home(owned_root)} {
    set why "it is no longer directly under $::t1_home(owned_root)"
  } elseif {![regexp $::t1_home_pattern [file tail $n]]} {
    set why "its name does not match the throwaway pattern"
  } elseif {$real ne {} && ($n eq $real || [string first "$n/" "$real/"] == 0)} {
    set why "it is the real home or an ancestor of it"
  } elseif {[t1_home_read_owner $n] ne [list [pid] [t1_home_boot_id] [t1_home_pidns]]} {
    set why "its .owner does not name this process ([t1_home_owner_line])"
  }
  if {$why ne {}} {
    puts "test home: NOT deleting $d -- $why"
    return
  }
  catch {file delete -force -- $n}
}

proc t1_home_hook_exit {} {
  if {[llength [info commands ::t1_home_real_exit]]} { return }
  rename ::exit ::t1_home_real_exit
  proc ::exit {{code 0}} {
    catch {t1_home_release}
    ::t1_home_real_exit $code
  }
}

proc t1_arm_home {} {
  global t1_home
  if {[info exists t1_home(kind)]} { return $t1_home(kind) }
  if {[llength [info commands ::xschem]]} {
    set t1_home(kind) inxschem
    return inxschem
  }
  ## D17.3: a RELATIVE TMPDIR is exported absolute before anything reads it, as
  ## test_home.sh does. t1_home_root already resolves it -- against THIS cwd --
  ## but a child started in another cwd would resolve it elsewhere, and with
  ## D17.4 that child's nesting test would fail and arm a second throwaway.
  if {[info exists ::env(TMPDIR)] && $::env(TMPDIR) ne {} && [file pathtype $::env(TMPDIR)] ne "absolute"
      && [file isdirectory $::env(TMPDIR)]} {
    set ::env(TMPDIR) [file normalize $::env(TMPDIR)]
  }
  set t1_home(owned) {}
  set t1_home(pre) {}
  set t1_home(restore) {}
  ## ⚠ THE PRE-SWITCH ENVIRONMENT IS A SNAPSHOT (DECISIONS D13.16), taken
  ## before a single variable is touched; see t1_home_preswitch_env. `own` is
  ## this process's, for the owner's restore; `snap` is the tester's -- the
  ## same, unless an enclosing arm exported one (XSCHEM_TEST_PRE_ENV).
  set t1_home(ownsnap) [array get ::env]
  set t1_home(snap) {}
  set t1_home(export_snap) 0
  if {[info exists ::env(XSCHEM_TEST_REAL_HOME)]} { set t1_home(snap) [t1_home_inherited_snap] }
  if {![llength $t1_home(snap)]} {
    set t1_home(snap) $t1_home(ownsnap)
    set t1_home(export_snap) 1
  }

  ## 1. XSCHEM_TEST_REAL_HOME, when present, must be a real path.
  set rh {}
  if {[info exists ::env(XSCHEM_TEST_REAL_HOME)]} {
    set rh $::env(XSCHEM_TEST_REAL_HOME)
    set why [t1_home_bad_real $rh]
    if {$why ne {}} {
      t1_home_refuse "XSCHEM_TEST_REAL_HOME='$rh' -- $why. It carries the path of\
 your real home directory and nothing else; it is never a flag. To run against\
 your real HOME, set XSCHEM_TEST_HOME=real instead."
    }
    set rh [file normalize $rh]
  }
  set home {}
  if {[info exists ::env(HOME)]} { set home $::env(HOME) }
  set opt {}
  if {[info exists ::env(XSCHEM_TEST_HOME)]} { set opt $::env(XSCHEM_TEST_HOME) }

  ## 2. The explicit opt-out: HOME untouched, and said loudly EVERY time.
  ## Exactly `real`, as test_home.sh reads it; `REAL` is refused below as a
  ## custom directory that is not absolute.
  if {$opt eq "real"} {
    set t1_home(kind) real
    catch {t1_home_sweep [t1_home_root]}
    puts "!! test home: REAL -- XSCHEM_TEST_HOME=real, so this run uses your real HOME ($home)."
    puts "!! It can overwrite your xschem clipboard, same-named netlists in ~/.xschem/simulations"
    puts "!! and your saved window positions. Unset XSCHEM_TEST_HOME for a throwaway home instead."
    flush stdout
    return real
  }

  ## 3. Nested: ALL FOUR of a live-owned throwaway HOME, DIRECTLY UNDER THE TEMP
  ## ROOT (D17.4), and XSCHEM_TEST_REAL_HOME set (validated above). Reuse; never
  ## create, never delete, say nothing.
  if {$opt eq {} && $rh ne {} && [file isdirectory $home] && ![t1_home_under_root $home]
      && [regexp $::t1_home_pattern [file tail [file normalize $home]]]} {
    puts "!! test home: note: HOME ($home) is named like a throwaway but is not directly under the temp root ([t1_home_root]), so it is not reused; arming a fresh one"
  }
  ## ⚠ AND NOTHING IN IT MAY LEAD INTO THE REAL HOME (D20.4): the round-3 safety
  ## refuter planted a throwaway-shaped HOME directly under /tmp, `.owner`
  ## naming a live pid, `.xschem` a symlink into the real home, and this branch
  ## reused it. An arm never makes such a home, so it is not one; a fresh
  ## throwaway is armed instead, as for D17.4.
  set nest_esc {}
  if {$opt eq {} && $rh ne {} && [t1_home_live_throwaway $home] && [t1_home_under_root $home]} {
    set nest_esc [t1_home_custom_escapes $home [t1_home_resolve $rh]]
    if {$nest_esc ne {}} {
      puts "!! test home: note: HOME ($home) is named like a throwaway but $nest_esc; it is not reused -- arming a fresh one"
    }
  }
  if {$opt eq {} && $rh ne {} && $nest_esc eq {} && [t1_home_live_throwaway $home] && [t1_home_under_root $home]} {
    set t1_home(kind) throwaway
    set t1_home(real) $rh
    set t1_home(th) [file normalize $home]
    ## A nested run can still start a long-lived process (a nested T1's
    ## display arm), and the environment from before the switch is the
    ## PARENT's. What it knows: the real home, the XDG_* originals the first
    ## arm recorded as XSCHEM_TEST_PRE_<name>, that any other XDG_* still
    ## pointing into the throwaway was repointed there with its original lost
    ## (so that one is unset and follows HOME again), and which names are
    ## harness state -- t1_home_clean_env strips all of it (D13.16).
    set src [t1_home_inherited_snap]
    if {![llength $src]} { set src [array get ::env] }
    set t1_home(pre) [t1_home_clean_env $src $rh]
    return throwaway
  }

  ## 4. Whose home is being protected.
  if {$rh ne {}} {
    set real $rh
  } elseif {$home ne {} && [t1_home_has_throwaway $home]} {
    t1_home_refuse "HOME ($home) is itself a test throwaway home and\
 XSCHEM_TEST_REAL_HOME is not set, so there is no way to tell where your real\
 home is. Run from your ordinary environment, or set XSCHEM_TEST_HOME=<a copy>."
  } elseif {$home ne {} && [string index $home 0] eq "/"} {
    set real $home
  } else {
    set real {}
    if {![catch {exec id -un} un] && ![catch {exec getent passwd [string trim $un]} pw]} {
      set real [lindex [split [string trim $pw] :] 5]
    }
    if {$real eq {} || [t1_home_bad_real $real] ne {}} {
      t1_home_refuse "HOME is '$home' and the real home cannot be determined."
    }
  }
  set real [file normalize $real]
  set t1_home(real) $real
  ## Every comparison with the real home is made FULLY RESOLVED (D13.5): a
  ## symlink to it, or a HOME that is itself a symlink, is still it.
  set realr [t1_home_resolve $real]
  set root [t1_home_root]
  catch {t1_home_sweep $root}

  ## 5. Make (or adopt) the home.
  if {$opt ne {}} {
    set why {}
    if {[string index $opt 0] ne "/"} {
      set why "it is not an absolute path"
    } elseif {![file isdirectory $opt]} {
      set why "it is not an existing directory"
    } elseif {[t1_home_has_throwaway $opt]} {
      set why "it is a throwaway home, which another run's sweep may delete -- copy it somewhere of your own"
    } elseif {[t1_home_resolve $opt] eq $realr} {
      ## ⚠ RESOLVED, the last component included (D13.5): the round-1 build
      ## compared `file normalize` spellings, so a SYMLINK to the real home was
      ## "custom", printed "your HOME is untouched" and wrote into it.
      set why "it is your real HOME ([t1_home_resolve $opt], once every symlink is followed) -- say XSCHEM_TEST_HOME=real for that, which also warns every run"
    } else {
      set why [t1_home_custom_escapes $opt $realr]
    }
    if {$why ne {}} {
      t1_home_refuse "XSCHEM_TEST_HOME='$opt' -- $why. It takes `real` or the absolute\
 path of an existing directory to use as HOME (which is never deleted)."
    }
    set th [file normalize $opt]
    set t1_home(kind) custom
  } else {
    if {[catch {exec mktemp -d [file join $root xschem-test-home.[pid].XXXXXX]} th]} {
      t1_home_refuse "could not create a throwaway home under $root ([string trim $th]).\
 Point TMPDIR at a writable directory."
    }
    set th [t1_home_resolve [string trim $th]]
    if {$th eq $realr || [string first "$th/" "$realr/"] == 0 || [file dirname $th] ne $root \
          || ![regexp $::t1_home_pattern [file tail $th]]} {
      t1_home_refuse "mktemp returned '$th', which is the real home, an ancestor of\
 it, or not a fresh entry directly under $root."
    }
    if {[catch {set h [open [file join $th .owner] w]; puts $h [t1_home_owner_line]; close $h} e]} {
      catch {file delete -force -- $th}
      t1_home_refuse "could not record the owner in $th ($e)."
    }
    t1_home_keep_now $th
    set t1_home(owned) $th
    set t1_home(owned_root) $root
    set t1_home(owned_is_home) 1
    set t1_home(kind) throwaway
    ## D5 refuses only "equal to or an ancestor of" the real home; a TMPDIR
    ## INSIDE it is allowed and said, in the same words test_home.sh uses --
    ## and then the banner below must not say "your HOME is untouched" (D13.4).
    if {[string first "$realr/" "$th/"] == 0} {
      set t1_home(inside) 1
      puts "!! test home: note: the throwaway is INSIDE your real home ($realr) because TMPDIR is; set TMPDIR elsewhere to keep it out"
    }
  }
  set t1_home(th) $th
  ## F25: sixteen parallel first starts race to create ~/.xschem, and the loser
  ## exits 1 -- measured 11/320 on an empty HOME, 0/320 once it exists.
  if {![file isdirectory [file join $th .xschem]]} {
    if {[catch {file mkdir [file join $th .xschem]
                file attributes [file join $th .xschem] -permissions 0700} e]} {
      t1_home_refuse "could not create [file join $th .xschem] ($e)."
    }
  }

  ## 6. The carry table (DECISIONS D7), computed from the real home BEFORE the
  ## switch, each only if not already set. Every harness path that defaults to
  ## $HOME/.claude/... must be here or allowlisted with a reason: an uncarried
  ## one does not fail, it SKIPS -- issue 1397's trap, locked by row G1 of
  ## tests/headless/test_home_isolation.tcl.
  if {![info exists ::env(XSCHEM_TEST_REAL_HOME)]} { set ::env(XSCHEM_TEST_REAL_HOME) $real }
  ## "Set" means set and non-empty for the three paths below, as test_home.sh
  ## reads them (`${VAR:-}`): an empty one is replaced, never kept.
  if {![info exists ::env(XSCHEM_DEVDISPLAY_DIR)] || $::env(XSCHEM_DEVDISPLAY_DIR) eq {}} {
    set ::env(XSCHEM_DEVDISPLAY_DIR) [file join $real .claude xschem_dev_display]
  }
  ## Only if it EXISTS (the critic's point 3): otherwise an arm with a live gate
  ## would create ~/.claude/gui_test_gate in a stranger's real home.
  if {(![info exists ::env(GUI_GATE_DIR)] || $::env(GUI_GATE_DIR) eq {}) && [file isdirectory [file join $real .claude gui_test_gate]]} {
    set ::env(GUI_GATE_DIR) [file join $real .claude gui_test_gate]
  }
  if {(![info exists ::env(XAUTHORITY)] || $::env(XAUTHORITY) eq {}) && [file isfile [file join $real .Xauthority]]} {
    set ::env(XAUTHORITY) [file join $real .Xauthority]
  }
  ## XDG_* only if ALREADY set: an unset one keeps following HOME, which keeps
  ## the suites that switch HOME for their own children coherent (critic).
  ## The original is exported as XSCHEM_TEST_PRE_<name> (first arm wins), the
  ## record tests/headless/test_home.sh keeps too, so that a nested or custom
  ## run can still start a long-lived process with the tester's own value.
  ## `restore` is what the owner's release puts back before deleting: each
  ## name's own value from the snapshot, so nothing is left pointing into it.
  array set snap $t1_home(ownsnap)
  set restore {}
  foreach k {HOME XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME} {
    if {[info exists snap($k)]} { lappend restore $k [list set $snap($k)] } else { lappend restore $k unset }
  }
  set t1_home(restore) $restore
  foreach {k sub} {XDG_CACHE_HOME .cache XDG_CONFIG_HOME .config
                   XDG_DATA_HOME .local/share XDG_STATE_HOME .local/state} {
    if {[info exists ::env($k)]} {
      if {![info exists ::env(XSCHEM_TEST_PRE_$k)]} { set ::env(XSCHEM_TEST_PRE_$k) $::env($k) }
      set ::env($k) [file join $th $sub]
    }
  }
  set t1_home(pre) [t1_home_clean_env $t1_home(snap) $real]
  if {$t1_home(export_snap)} {
    set enc [t1_home_env_encode $t1_home(snap)]
    if {$enc ne {} && [string length $enc] <= $::t1_home_pre_env_max} {
      set ::env(XSCHEM_TEST_PRE_ENV) $enc
    } else {
      catch {unset ::env(XSCHEM_TEST_PRE_ENV)}
      if {$enc ne {}} {
        puts "!! test home: note: the environment is too large to export as a snapshot ([string length $enc] B encoded); a nested run reconstructs it instead"
      }
    }
  }
  ## git's safe.directory as COMMAND-scope config: it is honoured (it is a
  ## protected scope), and it imports nothing from the tester's own config.
  ## Appended, so a GIT_CONFIG_COUNT the tester already uses survives.
  set gn 0
  if {[info exists ::env(GIT_CONFIG_COUNT)]} { set gn $::env(GIT_CONFIG_COUNT) }
  if {[string is integer -strict $gn] && $gn >= 0} {
    set have 0
    for {set i 0} {$i < $gn} {incr i} {
      if {[info exists ::env(GIT_CONFIG_KEY_$i)] && $::env(GIT_CONFIG_KEY_$i) eq "safe.directory"
          && [info exists ::env(GIT_CONFIG_VALUE_$i)] && $::env(GIT_CONFIG_VALUE_$i) eq $::t1_home_repo} {
        set have 1
      }
    }
    ## Not stacked again by a custom-mode child, which re-runs this carry.
    if {!$have} {
      set ::env(GIT_CONFIG_KEY_$gn) safe.directory
      set ::env(GIT_CONFIG_VALUE_$gn) $::t1_home_repo
      set ::env(GIT_CONFIG_COUNT) [expr {$gn + 1}]
    }
  }
  set ::env(HOME) $th
  if {$t1_home(owned) ne {}} { t1_home_hook_exit }

  if {$t1_home(kind) eq "custom" && [string first "$realr/" "[t1_home_resolve $th]/"] == 0} {
    ## D13.4's rule, for the same reason: a custom home INSIDE the real one is
    ## written by this run, so "your HOME is untouched" would be false there.
    ## The same words as test_home.sh; row L11b of test_home_isolation.tcl.
    puts "test home: custom $th (never deleted; it is inside your HOME, so this run writes there)"
  } elseif {$t1_home(kind) eq "custom"} {
    puts "test home: custom $th (never deleted; your HOME is untouched)"
  } elseif {[info exists t1_home(inside)]} {
    ## ⚠ D13.4: the throwaway is written, and deleted, UNDER the real home, so
    ## "your HOME is untouched" would be false. What is true is narrower.
    puts "test home: throwaway $th (your ~/.xschem is untouched; the throwaway lives under your HOME because TMPDIR does; XSCHEM_TEST_HOME=real to opt out)"
  } else {
    puts "test home: throwaway $th (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)"
  }
  flush stdout
  return $t1_home(kind)
}
t1_arm_home

# Resolve the xschem binary (issue 0147). Priority: $XSCHEM override, then the
# IN-TREE build, then a bare name for an installed copy on PATH. Before this, the
# bare name was the only option, so in an uninstalled dev workarea EVERY case
# died on spawn -- headless cases as a synthesized "did not complete cleanly"
# FAIL, golden cases as thousands of silent `exit 127` sh jobs -- and the suite
# reported a mixture of phantom and hidden results.
# The path MUST be absolute: it is interpolated into /bin/sh job strings that
# `cd` elsewhere first (netlisting.tcl, open_close.tcl, create_save.tcl), so a
# relative one would resolve against the wrong directory. `info script` is this
# file, so the anchor holds no matter where the case was launched from. Mirrors
# tests/headless/full_audit.sh's XSCHEM="${XSCHEM:-$REPO/src/xschem}".
set xschem_cmd "xschem"
if {[info exists env(XSCHEM)] && $env(XSCHEM) ne ""} {
  # Only absolutise something that IS a path. A bare `XSCHEM=xschem` means "find
  # it on PATH"; normalizing that would invent a bogus cwd-relative path and
  # destroy the very fallback it asked for.
  if {[string first / $env(XSCHEM)] >= 0} {
    set xschem_cmd [file normalize $env(XSCHEM)]
  } else {
    set xschem_cmd $env(XSCHEM)
  }
} else {
  set _xs_tree [file normalize \
      [file join [file dirname [file normalize [info script]]] .. src xschem]]
  if {[file executable $_xs_tree]} { set xschem_cmd $_xs_tree }
  unset _xs_tree
}

# ---------------------------------------------------------------------------
# Parallel-dispatch helpers (see doc/claude/suggestions/parallel_regression_tests.md).
#
# The regression cases are thousands of independent, short xschem spawns. We run
# them through a bounded xargs pool instead of a sequential foreach. Each job is a
# self-contained /bin/sh command string so that any `cd` and redirection stays
# isolated to the child process (the Tcl interpreter's cwd is never touched), and
# each job writes only into a private work dir so concurrent writers never collide.
# ---------------------------------------------------------------------------

# Number of parallel jobs: all online CPUs minus 4 (leave headroom for an
# interactive machine), with a hard floor of 1. No user-facing knob by design.
proc test_njobs {} {
  set n 0
  if {![catch {exec nproc} out]} { set n [string trim $out] }
  if {(![string is integer -strict $n] || $n <= 0) && \
      ![catch {exec getconf _NPROCESSORS_ONLN} out]} { set n [string trim $out] }
  if {![string is integer -strict $n] || $n <= 0} { set n 1 }
  set j [expr {$n - 4}]
  if {$j < 1} { set j 1 }
  return $j
}

# Run a list of shell command strings with bounded parallelism.
# Each element of $cmds is an arbitrary /bin/sh command line (it may contain cd,
# redirections, ';', '$?', etc.). NUL-delimiting them lets xargs hand each command
# verbatim to a fresh shell as $0, which `eval "$0"` then executes.
proc run_parallel_cmds {cmds njobs} {
  if {[llength $cmds] == 0} { return }
  set tmp [file join [pwd] .parallel_jobs.[pid]]
  set fd [open $tmp w]
  fconfigure $fd -translation binary
  foreach c $cmds {
    puts -nonewline $fd $c
    puts -nonewline $fd "\x00"
  }
  close $fd
  # xargs exits nonzero if any job did; that's expected (per-job status files carry
  # the real outcome), so swallow it.
  catch {exec xargs -0 -P $njobs -n1 sh -c {eval "$0"} < $tmp 2>@ stderr}
  file delete -force $tmp
}

# Normalize a batch of debug/result files in parallel.
# The original cleanup spawned one awk per file; with thousands of files that serial
# spawn cost dwarfs the (now parallel) xschem work. cleanup_debug_file.awk already
# handles many files in one process (its beginfile/endfile logic writes each FILENAME
# back independently), so we batch files per awk and run batches through the pool.
# Files are disjoint across batches, so parallel awks never touch the same file.
#
# ⚠ AND ONE MISSING FILE USED TO COST ITS WHOLE BATCH, SILENTLY (issue 1476,
# face 3). gawk's "cannot open file" is a FATAL, not a warning: it aborts the awk
# process, so the up-to-63 files batched WITH the missing one are left
# un-normalized too -- cleanup_debug_file.awk writes a file back from endfile(),
# and END{endfile()} is the only thing that flushes the last file of a batch.
# Then `catch {exec ...}` with no result variable discarded the message as well,
# so the caller was told nothing at all. Reproducible in two awk spawns with no
# concurrency whatever (test_regression_concurrency_1476.tcl section C).
# Absent files are now dropped BEFORE batching -- a file that vanished costs only
# itself -- and whatever went wrong is both printed and RETURNED to the caller.
proc cleanup_debug_files {files njobs} {
  if {[llength $files] == 0} { return {} }
  set present {}
  set missing {}
  foreach f $files {
    if {[file exists $f]} { lappend present $f } else { lappend missing $f }
  }
  # ⚠ AND DEDUPED, because the batches must stay disjoint: two parallel awks
  # rewriting one file at once is a corrupted file, and that invariant is the
  # only reason this may be run in parallel at all. netlisting's last-writer-wins
  # rename can put one published netlist path in the list twice (the library has
  # duplicate .sch basenames).
  set present [lsort -unique $present]
  set problems {}
  if {[llength $missing]} {
    set m "cleanup_debug_files: [llength $missing] result file(s) gone before\
 normalization (first: [lindex $missing 0]) -- another run in this tree is the\
 usual cause (issue 1476)"
    lappend problems $m
    puts "FATAL: $m"
  }
  if {[llength $present]} {
    set tmp [file join [pwd] .cleanup_files.[pid]]
    set fd [open $tmp w]
    fconfigure $fd -translation binary
    foreach f $present {
      puts -nonewline $fd $f
      puts -nonewline $fd "\x00"
    }
    close $fd
    if {[catch {exec xargs -0 -P $njobs -n 64 awk -f cleanup_debug_file.awk \
                     < $tmp 2>@ stderr} err]} {
      set e [string trim $err]
      if {$e eq {}} { set e "awk exited nonzero" }
      lappend problems "cleanup_debug_files: $e"
      puts "FATAL: cleanup_debug_files: $e -- result files may be un-normalized"
    }
    file delete -force $tmp
  }
  return $problems
}

# ---------------------------------------------------------------------------
# Job status: the two ways a status can fail to BE a status (issue 1476).
#
# `echo $?` writes 0..255, so neither sentinel can collide with a code a job
# really wrote -- which is the entire point of them. Both used to be -1 and the
# three callers printed `FATAL: <cmd> : exit -1`: a phantom failure of a job that
# had run perfectly, wearing the exact shape of a real crash. 656 of them in one
# measured collision, and `exit -1` is not a code any xschem process writes --
# that tell is what identified the defect in the first place.
#
# A MISSING status file means somebody deleted it (the other run in this tree);
# a GARBLED one means the job wrote nonsense. Different defects, different words.
set JOB_STATUS_MISSING -1001
set JOB_STATUS_GARBLED -1002

# Read an integer exit status written by a job's `echo $? > status` tail.
proc read_job_status {statusfile} {
  if {![file exists $statusfile]} { return $::JOB_STATUS_MISSING }
  # The file can vanish between the test and the open -- that race IS the defect.
  if {[catch {open $statusfile r} fd]} { return $::JOB_STATUS_MISSING }
  set s [string trim [read $fd]]
  close $fd
  if {![string is integer -strict $s]} { return $::JOB_STATUS_GARBLED }
  return $s
}

# The FATAL detail line for a status that is not a clean exit.
# ⚠ A REAL exit code is still reported exactly as it always was -- `exit 139` --
# so a genuine crash keeps the shape every reader, grep and habit in this tree
# already knows. Only the two not-a-status cases get their own words.
proc job_status_reason {rc statusfile} {
  if {$rc == $::JOB_STATUS_MISSING} {
    return "NO STATUS FILE ($statusfile) -- this job's exit code was never\
 written or was deleted by another run in this tree (issue 1476); the job itself\
 may well have succeeded"
  }
  if {$rc == $::JOB_STATUS_GARBLED} {
    return "UNREADABLE STATUS FILE ($statusfile) -- its contents are not an exit\
 code, so this job's real outcome is unknown"
  }
  return "exit $rc"
}

# ---------------------------------------------------------------------------
# Per-run LOG names (issue 1478; ruling R1 as re-decided 2026-09-17)
# ---------------------------------------------------------------------------
# A full T1 run writes 88 fixed-name files under tests/, of which 83 are verdict
# INPUTS -- the driver reads each case's log back and scores it. Two runs in one
# tree therefore scored each other's bodies, and the verdict lock protected
# exactly ONE of the 88. Measured 2026-09-17 on a forced collision, using this
# tree's own banner_rule.tcl as the scorer, wrong in BOTH directions: run A's two
# real failures silently counted as ZERO, and a phantom failure charged to the
# run that passed.
#
# ⚠ THE TAG IS THE DRIVER'S PID AND IT TRAVELS IN THE ENVIRONMENT, which looks
# indirect until you notice who writes this file: print_results runs in the
# CASE's process (`tclsh open_close.tcl`), not the driver's, so the two cannot
# both reach for `[pid]` and get the same answer. run_regression.tcl sets
# T1_LOG_TAG to its own pid; both sides then spell the name with this one proc,
# so they cannot drift.
#
# ⚠ AND AN UNSET TAG MEANS THE OLD NAME, DELIBERATELY. `cd tests && tclsh
# open_close.tcl` is the documented way to run one case by hand (CLAUDE.md says
# so), and it must go on producing `open_close.log` -- a private name for a solo
# run would be a new thing to learn for no benefit.
proc t1_log_tag {} {
  if {[info exists ::env(T1_LOG_TAG)]} {
    set v [string trim $::env(T1_LOG_TAG)]
    if {[string is integer -strict $v] && $v > 0} { return $v }
  }
  return {}
}

# "$stem$suffix" solo, "$stem.<tag>$suffix" under a driver. The suffix is passed
# rather than assumed because the four shapes differ: `.log`, `.disp.log` and
# `_output.txt` are not one extension with one spelling.
proc t1_run_file {stem suffix} {
  set t [t1_log_tag]
  if {$t eq {}} { return "$stem$suffix" }
  return "$stem.$t$suffix"
}

# ---------------------------------------------------------------------------
# Per-run results roots (issue 1476, faces 1 and 2)
# ---------------------------------------------------------------------------
# Each case works in <case>/results.<pid> and publishes it under the canonical
# <case>/results name when the verdict is already computed. Two helpers support
# that; the wipe and the workroot themselves stay in the case files, where a
# reader looking for "what does this case destroy at startup" will find them.

# Restore the canonical <case>/results name from this run's private root.
# `<case>/results/` is the name CLAUDE.md documents, the name a gold baseline is
# promoted FROM, and the name a human looks in. Last run wins -- exactly what a
# second SEQUENTIAL run has always done to this directory.
#
# It runs AFTER print_results has computed the verdict from the private root, so
# nothing here can change a result. A failure is therefore a warning and never a
# death: the files simply stay under their per-run name, which the message says.
proc publish_results {testname resdir} {
  set canon $testname/results
  if {$resdir eq $canon || ![file isdirectory $resdir]} { return 0 }
  if {[catch {
        file delete -force $canon
        file rename -force $resdir $canon
      } e]} {
    puts "WARNING: could not publish $resdir as $canon ($e) -- this run's result\
 files are in $resdir"
    return 0
  }
  return 1
}

# Remove per-run roots left behind by runs that are no longer alive.
# Before per-run roots a killed run's mess was cleaned by the NEXT run's wipe of
# the shared `results`; per-run roots would otherwise accumulate one directory
# per killed run for ever, and open_close's is 1898 files. T1 kills cases for
# real (issue 1403's 900 s per-case timeout), so this is not hypothetical.
#
# The canonical `results` can never match -- it has no `.<pid>` suffix -- and a
# pid that is still alive is left alone even if it is not a regression run: the
# failure direction here must always be "a leftover survives", never "a live
# run's tree is deleted". Where pid liveness cannot be established (no /proc,
# i.e. not Linux) nothing is swept at all.
proc sweep_dead_run_dirs {testname} {
  if {![file isdirectory /proc/[pid]]} { return {} }
  set swept {}
  foreach d [glob -nocomplain -directory $testname -types d -- results.* .work.*] {
    if {![regexp {\.([0-9]+)$} [file tail $d] -> p]} { continue }
    if {$p == [pid] || [file exists /proc/$p]} { continue }
    if {![catch {file delete -force $d}]} { lappend swept [file tail $d] }
  }
  if {[llength $swept]} {
    puts "swept [llength $swept] dead per-run dir(s) under $testname: $swept"
  }
  return $swept
}

# From Glenn Jackman (Stack Overflow answer)
proc comp_file {file1 file2} {
  # optimization: check file size first
  set equal 0
  if {[file size $file1] == [file size $file2]} {
    set fh1 [open $file1 r]
    set fh2 [open $file2 r]
    set equal [string equal [read $fh1] [read $fh2]]
    close $fh1
    close $fh2
  }
  return $equal
}

# Write <testname>.log for summarize_all. ALWAYS writes the log (issue 0147):
# it used to bail silently when <testname>/gold was absent, which discarded
# num_fatals too -- so a case in which every single job failed to even start
# contributed NOTHING to the run's failure count. Now a missing gold dir is
# reported as a non-counting NOGOLD line (absent baseline is a setup state, not a
# regression) while FATALs are always emitted, and summarize_all counts those via
# its ^FATAL pattern.
# $resdir is this run's results root; it defaults to the canonical
# <case>/results for any caller that has not got one (issue 1476 made the three
# regression cases work in <case>/results.<pid> and publish afterwards, so the
# comparison has to be told where the files it is judging actually are).
proc print_results {testname pathlist num_fatals {resdir {}}} {
    if {$resdir eq {}} { set resdir $testname/results }

    ## ⚠ PER-RUN NAME (issue 1478). This log is a VERDICT INPUT -- the driver
    ## reads it back and counts the lines in it -- and it used to be one fixed
    ## slot per case NAME rather than per RUN, so a second run in the tree
    ## overwrote it between this case exiting and the driver summarizing it.
    ## The driver publishes it back to `$testname.log` afterwards, so every
    ## reader's spelling survives.
    set logname [t1_run_file $testname .log]
    set a [catch "open \"$logname\" w" fd]
    if {$a} {
      puts "Couldn't open $logname"
    } else {
     if {[file exists ${testname}/gold]} {
      set i 0
      set num_fail 0
      set num_gold 0
      foreach f $pathlist {
        incr i
        if {![file exists $testname/gold/$f]} {
          puts $fd "$i. $f: GOLD?"
          incr num_gold
          continue
        }
        if {![file exists $resdir/$f]} {
          puts $fd "$i. $f: RESULT?"
          continue
        }
        if ([comp_file $testname/gold/$f $resdir/$f]) {
          puts $fd "$i. $f: PASS"
        } else {
          puts $fd "$i. $f: FAIL"
          incr num_fail
        }
      }
      puts $fd "Summary:"
      puts $fd "Num failed: $num_fail      Num missing gold: $num_gold      Num passed: [expr $i-$num_fail-$num_gold]"
     } else {
      # No baseline to compare against: say so IN THE LOG (not just on stdout,
      # where summarize_all can never see it). Deliberately not counted as a
      # failure -- but any FATALs below still are.
      puts $fd "NOGOLD: $testname has no gold/ directory -- [llength $pathlist]\
 result file(s) produced, none verified.  Set results as gold please."
      puts "No gold folder.  Set results as gold please."
     }
      if {$num_fatals} {
        puts $fd "FATAL: $num_fatals.  Please search for FATAL in its output file for more detail"
      }
      close $fd
    }
}

# Edit lines that change each time regression is ran
proc cleanup_debug_file {output} {
  eval exec {awk -f cleanup_debug_file.awk $output}
}
