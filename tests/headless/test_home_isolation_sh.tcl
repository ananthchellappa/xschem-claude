## test_home_isolation_sh.tcl -- the SHELL side of the throwaway-HOME contract.
##
##   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_home_isolation_sh.tcl
##
## WHAT IT GUARDS (doc/claude/outsider_fixes_batch, Item 2; DECISIONS D4-D7, D13).
## run_suites.sh, full_audit.sh and gated_xschem.sh used to run every suite
## against the tester's REAL home, overwriting their xschem clipboard, same-named
## netlists in ~/.xschem/simulations and saved window geometry. They now source
## tests/headless/test_home.sh, which switches HOME to a throwaway for the whole
## driver process and deletes it at exit. Round 2 (D13) armed the remaining
## documented entry points too -- `xvfb_arm.sh --arm` (the 7 standalone display
## suites), test_devdisplay.sh, `owed.sh drain`'s shell debts, run.sh and
## run_nogui.sh -- and hardened who deletes and who kills what. The dangerous
## lines are the ones that decide WHO deletes WHAT, so most rows below are about
## exactly that: nesting, the xvfb-run re-exec handoff, the dead-owner sweep,
## the reaper and the refusals.
##
## HOW. Every row execs bash with an EXPLICIT HOME (a scratch canary) and TMPDIR,
## and a scrubbed environment, never the caller's -- so the suite is safe to run
## bare, and gives the same answers nested inside T1 or a shell driver. The
## canary is snapshotted (find -printf + md5 of every file) before and after, so
## a NEW file in it is seen, not only a changed one.
##
## DISPLAY ROWS. The xvfb-run handoff rows (X*, W5), the reaper rows (X7, X9) and
## the gate rows (K*) need Xvfb, xvfb-run and wish. They use display numbers from
## XSCHEM_TEST_XVFB_BASE (default 160) upward -- never :99, the developer's
## persistent dev display: a shim in front of xvfb-run drops whatever `-n` the
## caller passed and puts this suite's base first -- and print `skip:` with a
## reason when a tool is missing. Every process a row starts is killed before
## the suite exits.
##
## ROUND 4 (DECISIONS D20) added, each red on the round-3 build: W3b (xarm.sh
## and tools/migrate/test_ase_migrate.py arm, read from the files), W11 (the
## same two, RUN from an empty home) and W10 (winshot.sh builds into the
## checkout's gitignored .winshot-cache, never ~/.cache).
##
## ROUND 3 (DECISIONS D17) added, each red on the round-2 build: X9 (no reaper
## window: the reaper starts before the exec into xvfb-run), X10 (xvfb-run gets
## `-n <base> -a`, base >= 100, so :99 is never chosen), X11 (the server is
## recorded in the owner's throwaway for the sweep), W8b (owed.sh drain prints
## the banner once), B2 (a relative TMPDIR through run_suites.sh), N10 updated
## for D17.4 (a home outside the temp root is not reused), and W3's three new
## launchers.

source [file join [file dirname [info script]] scratch.tcl]

set npass 0
set fail 0
set nskip 0
proc flat {s} { return [string map {"\n" " | "} $s] }
proc check {name got exp} {
  global npass fail
  if {$got eq $exp} { incr npass; puts "ok: $name" } \
  else { puts "FAIL: $name -> {[flat $got]} (exp {[flat $exp]})"; incr fail }
}
proc skip {name why} { global nskip; incr nskip; puts "skip: $name -- $why" }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set repo_phys [exec sh -c {cd "$1" && pwd -P} _ $repo]
set TH_SH [file join $here test_home.sh]
set XS [info nameofexecutable]

set S [test_scratch thsh]
set CAN [file join $S home]       ;# the parent HOME: a canary, never the caller's
set TMP [file join $S tmp]        ;# TMPDIR for every probe
set REC [file join $S rec.txt]
file mkdir $CAN $TMP

## Processes this suite started; killed at the end whatever happens.
set ::started {}
proc track {pid} { lappend ::started $pid }
proc kill_all {} {
  foreach p $::started { catch {exec kill $p} }
  after 300
  foreach p $::started { if {[file exists /proc/$p]} { catch {exec kill -9 $p} } }
  set ::started {}
}

proc have {tool} { return [expr {![catch {exec sh -c "command -v $tool"}]}] }

## Gone = no /proc entry, or a zombie nobody has reaped yet.
proc gone {p} {
  if {$p eq {} || ![string is integer -strict $p]} { return 1 }
  if {![file exists /proc/$p]} { return 1 }
  if {[catch {set f [open /proc/$p/stat]; set s [read $f]; close $f}]} { return 1 }
  set i [string last ")" $s]
  return [expr {[string index [string trim [string range $s [expr {$i + 1}] end]] 0] eq "Z"}]
}
proc wait_gone {pids secs} {
  set t [expr {[clock milliseconds] + $secs * 1000}]
  while {[clock milliseconds] < $t} {
    set all 1
    foreach p $pids { if {![gone $p]} { set all 0 } }
    if {$all} { return 1 }
    after 200
  }
  return 0
}

## The environment every probe starts from: nothing of the caller's test-home,
## display or gate state survives, whatever ran this suite.
set UNSET {}
foreach v {DISPLAY XAUTHORITY XSCHEM_TEST_HOME XSCHEM_TEST_REAL_HOME XSCHEM_TEST_HOME_HANDOFF
           XSCHEM_TEST_KEEP_HOME XSCHEM_TEST_PRE_ENV XSCHEM_TEST_HOME_WRAPPED
           GUI_GATE GUI_GATE_DIR GUI_GATE_AUTOSTART XSCHEM_DEVDISPLAY_DIR AUDIT_DISPLAY
           AUDIT_WM XSCHEM_XVFB_ARM XSCHEM_XVFB_WM_PID GIT_CONFIG_COUNT GIT_CONFIG_KEY_0
           GIT_CONFIG_VALUE_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1
           XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME
           XSCHEM_TEST_PRE_XDG_CACHE_HOME XSCHEM_TEST_PRE_XDG_CONFIG_HOME
           XSCHEM_TEST_PRE_XDG_DATA_HOME XSCHEM_TEST_PRE_XDG_STATE_HOME XSCHEM_OWED_DIR
           PROBE_BODY PROBE_RC PROBE_XVFB T1_LOG_TAG AUDIT_XVFB_BASE XSCHEM_TEST_XVFB_TAG} {
  lappend UNSET -u $v
}

## run SECS ENVLIST CMD... -> {rc output}. stdout+stderr merged.
proc run {secs envlist args} {
  global UNSET CAN TMP REC
  set cmd [list timeout -k 5 $secs env {*}$UNSET HOME=$CAN TMPDIR=$TMP PROBE_REC=$REC \
             {*}$envlist {*}$args]
  set rc 0
  if {[catch {exec {*}$cmd 2>@1} out opts]} {
    set ec [dict get $opts -errorcode]
    if {[lindex $ec 0] eq "CHILDSTATUS"} { set rc [lindex $ec 2] } \
    elseif {[lindex $ec 0] eq "CHILDKILLED"} { set rc [lindex $ec 2] } else { set rc -1 }
  }
  return [list $rc $out]
}
## runin CWD SECS ENVLIST CMD... -> the same, from another working directory.
proc runin {cwd secs envlist args} {
  return [run $secs $envlist bash -c {cd "$1" && shift && exec "$@"} _ $cwd {*}$args]
}

## A snapshot that sees new files, not only changed ones (D11).
proc snap {dir} {
  set out ""
  catch {exec bash -c {cd "$1" && find . -printf '%p %y %s %T@ %m\n' | LC_ALL=C sort &&
                       find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r md5sum} _ $dir} out
  return $out
}

proc throwaways {} {
  global TMP
  return [lsort [glob -nocomplain -directory $TMP -tails xschem-test-home.*]]
}

## The recorder's output: one dict per armed probe body reached, in order.
proc recs {} {
  global REC
  set l {}
  if {![file exists $REC]} { return $l }
  set f [open $REC]; set txt [read $f]; close $f
  set cur {}
  foreach line [split $txt \n] {
    if {$line eq "---"} { if {[dict size $cur]} { lappend l $cur }; set cur {}; continue }
    if {[regexp {^([a-z_]+)=(.*)$} $line -> k v]} { dict set cur $k $v }
  }
  if {[dict size $cur]} { lappend l $cur }
  return $l
}
proc rec_reset {} { global REC; file delete -force $REC }
proc rget {r k} { if {[dict exists $r $k]} { return [dict get $r $k] }; return <none> }

proc count_lines {out re} {
  set n 0
  foreach l [split $out \n] { if {[regexp $re $l]} { incr n } }
  return $n
}
proc slurp {f} { set h [open $f]; set t [read $h]; close $h; return $t }
proc spit {f txt} { set h [open $f w]; puts -nonewline $h $txt; close $h }

## A pid that is certainly dead now.
proc dead_pid {} { return [exec sh -c {echo $$}] }

## This machine's boot_id and this process's pid namespace -- what a sweeper
## run from here compares a `.owner` with (D13.6).
set BOOT [string trim [slurp /proc/sys/kernel/random/boot_id]]
set MYNS [file readlink /proc/[pid]/ns/pid]

## ---------------------------------------------------------------------------
## The probe driver: exactly the shape of the three real drivers' preamble
## (`. test_home.sh; test_home_arm || exit $?`, then optionally the display arm),
## followed by a recorder that writes what the driver sees to a file OUTSIDE
## the home, so it survives the home's deletion.
## ---------------------------------------------------------------------------
set DRV [file join $S drv.sh]
spit $DRV {#!/bin/bash
set -u
H="$1"; shift
. "$H/test_home.sh"
test_home_arm || exit $?
if [ "${PROBE_XVFB:-0}" = 1 ]; then . "$H/xvfb_arm.sh"; xvfb_arm "$0" "$H" "$@"; fi
{
  echo "pid=$BASHPID"
  echo "ppid=$PPID"
  echo "home=$HOME"
  echo "owner=$(head -n 1 "$HOME/.owner" 2>/dev/null | cut -d' ' -f1)"
  echo "ownerline=$(head -n 1 "$HOME/.owner" 2>/dev/null)"
  echo "bootid=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
  echo "pidns=$(readlink /proc/$BASHPID/ns/pid 2>/dev/null)"
  echo "keep=$([ -e "$HOME/.keep" ] && echo 1 || echo 0)"
  echo "real=${XSCHEM_TEST_REAL_HOME-<unset>}"
  echo "dd=${XSCHEM_DEVDISPLAY_DIR-<unset>}"
  echo "gg=${GUI_GATE_DIR-<unset>}"
  echo "xauth=${XAUTHORITY-<unset>}"
  echo "xdgc=${XDG_CACHE_HOME-<unset>}"
  echo "xdgd=${XDG_DATA_HOME-<unset>}"
  echo "prexdgc=${XSCHEM_TEST_PRE_XDG_CACHE_HOME-<unset>}"
  echo "git=${GIT_CONFIG_COUNT-<unset>}/${GIT_CONFIG_KEY_0-}/${GIT_CONFIG_VALUE_0-}"
  echo "handoff=${XSCHEM_TEST_HOME_HANDOFF-<unset>}"
  echo "wm=${XSCHEM_XVFB_WM_PID-}"
  echo "display=${DISPLAY-}"
  _n=${DISPLAY:-}; _n=${_n#:}; _n=${_n%%.*}
  echo "xlock=$(tr -cd 0-9 < "/tmp/.X$_n-lock" 2>/dev/null)"
  echo "xrec=$(tr -cd 0-9 < "$HOME/.xvfb.pid" 2>/dev/null)"
  echo "xschemmode=$(stat -c %a "$HOME/.xschem" 2>/dev/null)"
  echo "---"
} >> "$PROBE_REC"
# A body's keys form their OWN block, after any nested driver's block.
if [ -n "${PROBE_BODY:-}" ]; then _b="$PROBE_BODY"; unset PROBE_BODY; eval "$_b"; fi
echo "---" >> "$PROBE_REC"
exit "${PROBE_RC:-0}"
}
file attributes $DRV -permissions 0755

## A POSIX probe: what the 7 standalone suites and run.sh / run_nogui.sh are.
## It cannot source test_home.sh; it only records what it was handed.
set PSH [file join $S psh.sh]
spit $PSH {#!/bin/sh
{ echo "pid=$$"; echo "ppid=$PPID"
  echo "gppid=$(cut -d' ' -f4 /proc/$PPID/stat 2>/dev/null)"
  echo "home=$HOME"
  echo "owner=$(head -n 1 "$HOME/.owner" 2>/dev/null | cut -d' ' -f1)"
  echo "real=${XSCHEM_TEST_REAL_HOME-<unset>}"
  echo "display=${DISPLAY-}"
  echo "handoff=${XSCHEM_TEST_HOME_HANDOFF-<unset>}"
  echo "wrapped=${XSCHEM_TEST_HOME_WRAPPED-<unset>}"
  echo "wm=${XSCHEM_XVFB_WM_PID-}"
  echo "---"; } >> "$PROBE_REC"
exit "${PROBE_RC:-0}"
}
## The same, behind run.sh's own re-exec guard (copied from run.sh; W3 holds
## run.sh and run_nogui.sh to that exact line).
set GSH [file join $S gsh.sh]
spit $GSH "#!/bin/sh
HERE=[list $here]
\[ \"\${XSCHEM_TEST_HOME_WRAPPED:-}\" = \"\$PPID\" \] || exec bash \"\$HERE/test_home.sh\" --run sh \"\$0\" \"\$@\"
unset XSCHEM_TEST_HOME_WRAPPED
exec sh [list $PSH]
"

set BANNER_RE {^test home: throwaway (\S+) \(your HOME is untouched; XSCHEM_TEST_HOME=real to opt out\)$}

## ===========================================================================
## W. WIRING -- the three drivers arm BEFORE the display arm (D4), and the
##    handoff is the line right before xvfb_arm's exec (D5). D13.1: every other
##    documented entry point arms too.
## ===========================================================================
foreach drv {run_suites.sh full_audit.sh gated_xschem.sh} {
  set lines [split [slurp [file join $here $drv]] \n]
  set src -1; set arm -1; set xv -1; set i 0
  foreach l $lines {
    incr i
    if {$src < 0 && [regexp {^\s*\.\s+"\$HERE/test_home\.sh"\s*$} $l]} { set src $i }
    if {$arm < 0 && [regexp {^\s*test_home_arm \|\| exit \$\?\s*$} $l]} { set arm $i }
    if {$xv  < 0 && [regexp {^\s*\.\s+"\$HERE/xvfb_arm\.sh"\s*$} $l]} { set xv $i }
  }
  check "W1 $drv sources test_home.sh and arms (refusal exits) BEFORE sourcing xvfb_arm.sh" \
    [expr {$src > 0 && $arm > $src && $xv > $arm}] 1
}
set xa [slurp [file join $here xvfb_arm.sh]]
check "W2 xvfb_arm.sh hands the throwaway off on the line right before its exec" \
  [regexp {\n\s*if type test_home_handoff >/dev/null 2>&1; then test_home_handoff; fi\n\s*exec xvfb-run } $xa] 1

## W3: D13.1 wiring, read from the files themselves.
set w3 {}
## xvfb_arm.sh --arm: arm the home before the display arm, and run the command
## as a CHILD (an exec would skip the EXIT trap that deletes the home).
set ab {}
regexp {"\$\{1:-\}" = "--arm" \]; then\n(.*?)\nfi\n} $xa -> ab
lappend w3 [list --arm [regexp {\n\s*test_home_arm \|\| exit \$\?\n(.*\n)?\s*xvfb_arm "\$@"} $ab] \
                 [regexp {\n\s*exec "\$@"} $ab]]
## test_devdisplay.sh: arms before it starts its first display.
set dl [split [slurp [file join $here test_devdisplay.sh]] \n]
set a -1; set st -1; set i 0
foreach l $dl {
  incr i
  if {$a < 0 && [regexp {^\s*test_home_arm \|\| exit \$\?\s*$} $l]} { set a $i }
  if {$st < 0 && [regexp {^"\$DD" start} $l]} { set st $i }
}
lappend w3 [list devdisplay [expr {$a > 0 && $st > $a}]]
## run.sh / run_nogui.sh: the re-exec guard, before the binary is first run.
foreach {t v} {run.sh HERE run_nogui.sh here} {
  set tl [split [slurp [file join $here $t]] \n]
  set g -1; set x -1; set i 0
  foreach l $tl {
    incr i
    if {$g < 0 && $l eq "\[ \"\${XSCHEM_TEST_HOME_WRAPPED:-}\" = \"\$PPID\" \] || exec bash \"\$$v/test_home.sh\" --run sh \"\$0\" \"\$@\""} { set g $i }
    if {$x < 0 && [regexp -nocase {^\s*(out=\$\()?(REPO="\$REPO" CASES_FILE="\$CASES_FILE" \\)?\s*"\$xschem"} $l]} { set x $i }
  }
  lappend w3 [list $t [expr {$g > 0 && ($x < 0 || $x > $g)}]]
}
## owed.sh drain: a shell debt runs inside a subshell that armed a throwaway.
lappend w3 [list owed [regexp {\n\s*if \[ -f "\$HERE/test_home\.sh" \]; then\n\s*\(\s*# shellcheck[^\n]*\n\s*\. "\$HERE/test_home\.sh" && test_home_arm \|\| exit \$\?\n\s*AUDIT_DISPLAY="\$display" DISPLAY="\$display" bash "\$path"\n\s*_rc=\$\?; exit "\$_rc" \); rc=\$\?\n\s*else\n\s*_warn "no test_home\.sh beside this owed\.sh} [slurp [file join $here owed.sh]]]]
## the 7 standalone suites route through `xvfb_arm.sh --arm`.
foreach s {test_action_log test_action_replay test_file_menu_log test_flylines
           test_readonly_action_dispatch test_readonly_guard test_recent_launchlog} {
  lappend w3 [list $s [regexp -line {^\[ "\$\{XSCHEM_XVFB_ARM:-0\}" = 1 \] \|\| exec bash "\$(HERE|here)/xvfb_arm\.sh" --arm sh "\$0" "\$@"$} \
                          [slurp [file join $here $s.sh]]]]
}
## D17.1: the three round 2 found unarmed -- lookshot.sh and netlist_diff.sh
## source test_home.sh and arm before the binary is first named; run_wireedit.sh
## (POSIX) re-execs through `test_home.sh --run`. (Row G2 of
## test_home_isolation.tcl is the general guard; these are the named cases.)
foreach {t f} [list lookshot [file join $here lookshot.sh] netlist_diff [file join $repo tests netlist_diff netlist_diff.sh]] {
  set a -1; set x -1; set i 0
  foreach l [split [slurp $f] \n] {
    incr i
    if {$a < 0 && [regexp {^\s*test_home_arm \|\| exit \$\?\s*$} $l]} { set a $i }
    if {$x < 0 && ![regexp {^\s*#} $l] && [regexp {src/xschem([^.a-z]|$)} $l]} { set x $i }
  }
  lappend w3 [list $t [expr {$a > 0 && $x > $a}]]
}
set g -1; set x -1; set i 0
foreach l [split [slurp [file join $here wireedit run_wireedit.sh]] \n] {
  incr i
  if {$g < 0 && $l eq "\[ \"\${XSCHEM_TEST_HOME_WRAPPED:-}\" = \"\$PPID\" \] || exec bash \"\$root/tests/headless/test_home.sh\" --run sh \"\$0\" \"\$@\""} { set g $i }
  if {$x < 0 && ![regexp {^\s*#} $l] && [regexp {src/xschem} $l]} { set x $i }
}
lappend w3 [list run_wireedit [expr {$g > 0 && $x > $g}]]
check "W3 D13.1 + D17.1: --arm, test_devdisplay.sh, run.sh, run_nogui.sh, owed.sh drain, the 7 standalone suites, lookshot.sh, netlist_diff.sh and run_wireedit.sh all arm a throwaway HOME" \
  $w3 [list {--arm 1 0} {devdisplay 1} {run.sh 1} {run_nogui.sh 1} {owed 1} \
            {test_action_log 1} {test_action_replay 1} {test_file_menu_log 1} {test_flylines 1} \
            {test_readonly_action_dispatch 1} {test_readonly_guard 1} {test_recent_launchlog 1} \
            {lookshot 1} {netlist_diff 1} {run_wireedit 1}]

## W3b (D20.6): the two launchers round 3's refuters found OUTSIDE what W3 and
## G2 looked at. doc/claude/signal_browser_2pane_batch/xarm.sh arms before it
## runs anything, and runs only ARMED drivers (gated_xschem.sh, run_suites.sh),
## as children -- no `exec` (it would skip the EXIT trap that deletes the home),
## no `xvfb-run -a` (which starts at :99), no bare binary, no hand-launched gate
## panel. tools/migrate/test_ase_migrate.py (Python cannot source test_home.sh)
## re-execs through `test_home.sh --run` before anything else can start xschem.
set w3b {}
set xl [split [slurp [file join $repo doc claude signal_browser_2pane_batch xarm.sh]] \n]
set a -1; set d -1; set bad {}; set i 0
foreach l $xl {
  incr i
  if {[regexp {^\s*#} $l]} { continue }
  if {$a < 0 && [regexp {^\s*test_home_arm \|\| exit \$\?\s*$} $l]} { set a $i }
  if {$d < 0 && [regexp {(gated_xschem|run_suites)\.sh} $l]} { set d $i }
  if {[regexp {(^|\s)exec\s|xvfb-run\s+-a|src/xschem|gui_gate_widget\.tcl} $l]} { lappend bad $i }
}
lappend w3b [list xarm [expr {$a > 0 && $d > $a}] $bad]
set ml [split [slurp [file join $repo tools migrate test_ase_migrate.py]] \n]
set g -1; set x -1; set i 0
foreach l $ml {
  incr i
  if {$g < 0 && [regexp {os\.execvp\("bash", \["bash", os\.path\.join\(_HERE, "\.\.", "\.\.", "tests", "headless", "test_home\.sh"\), "--run", sys\.executable} $l]} { set g $i }
  if {$x < 0 && [regexp {src.*xschem|subprocess} $l] && ![regexp {^\s*#|^import|^\s*"|^\s*on \./src} $l]} { set x $i }
}
lappend w3b [list test_ase_migrate [expr {$g > 0 && $x > $g}]]
check "W3b D20.6: xarm.sh arms and runs only armed drivers as children (no exec, no xvfb-run -a, no bare binary, no panel of its own); test_ase_migrate.py re-execs through test_home.sh --run first" \
  $w3b [list {xarm 1 {}} {test_ase_migrate 1}]

## W11 (D20.6), BEHAVIOUR, not text: W3b and G2 read the arm off the page, and a
## disabled one (`if False:` round the re-exec, `true` for test_home_arm) still
## reads as armed -- that sabotage stayed green through both. So the two
## launchers are RUN, from an EMPTY home: each must announce its throwaway, and
## the home must stay empty. test_ase_migrate.py's integration leg starts xschem
## when ngspice is on PATH (unarmed it created ~/.xschem/op_annot/ in a canary);
## `xarm.sh mode` starts nothing, so for it the banner is the evidence.
if ![have python3] {
  skip W11-test_ase_migrate-and-xarm-run-under-a-throwaway "no python3 on PATH"
} else {
  set w11h [file join $S w11home] ; file mkdir $w11h
  set w11s [snap $w11h]
  lassign [run 300 [list HOME=$w11h] python3 [file join $repo tools migrate test_ase_migrate.py]] m11rc m11out
  lassign [run 60 [list HOME=$w11h] bash [file join $repo doc claude signal_browser_2pane_batch xarm.sh] mode] x11rc x11out
  check "W11 test_ase_migrate.py and xarm.sh, RUN from an empty home, announce a throwaway, keep their exit status, and leave the home empty" \
    [list $m11rc [count_lines $m11out {^test home: throwaway }] [count_lines $m11out {^RESULT: ALL PASS}] \
          $x11rc [count_lines $x11out {^test home: throwaway }] [expr {[snap $w11h] eq $w11s}] [throwaways]] \
    [list 0 1 1 0 1 1 {}]
}

## W10 (D20.3): winshot.sh builds its binary into the CHECKOUT's gitignored
## tests/headless/.winshot-cache/, never into ~/.cache. Run standalone -- it is
## documented to be, and G2 cannot see it (it starts no xschem) -- it wrote
## .cache/xschem-winshot/{build.log,winshot} into an EMPTY home (the round-3
## safety refuter). No display is needed: the build happens before winshot runs,
## and without a DISPLAY winshot then fails to connect (rc 3), which is fine.
## And where the cache cannot be written it builds for this one call in a
## temporary directory and removes it -- still never in the home.
if {![have cc]} {
  skip W10-winshot-builds-in-the-checkout-never-in-HOME "no cc on PATH: winshot.sh cannot build here"
} else {
  set wsh [file join $S wshome] ; file mkdir $wsh
  set wsh0 [snap $wsh]
  set wsout [file join $S ws.png]
  lassign [run 120 [list HOME=$wsh] bash [file join $here winshot.sh] $wsout -root] wsrc wsouttxt
  set wsc [file join $here .winshot-cache]
  set ign {n/a}
  if {[file exists [file join $repo .git]] && [have git]} {
    set ign [expr {![catch {exec git -C $repo check-ignore -q -- tests/headless/.winshot-cache/winshot}]}]
  }
  set ro [file join $S ws_ro] ; file mkdir $ro ; file attributes $ro -permissions 0555
  lassign [run 120 [list HOME=$wsh XSCHEM_WINSHOT_CACHE=$ro] bash [file join $here winshot.sh] $wsout -root] wsrc2 wsout2
  file attributes $ro -permissions 0755
  check "W10 winshot.sh builds into the checkout's gitignored .winshot-cache, never under HOME; an unwritable cache builds once in TMPDIR and cleans up" \
    [list [expr {$wsrc != 5}] [file executable [file join $wsc winshot]] $ign [expr {[snap $wsh] eq $wsh0}] \
          [expr {$wsrc2 != 5}] [glob -nocomplain -directory $TMP -tails xschem-winshot.*] [glob -nocomplain -directory $ro -tails *]] \
    [list 1 1 [expr {$ign eq {n/a} ? {n/a} : 1}] 1 1 {} {}]
}

## ===========================================================================
## F. A FRESH ARM
## ===========================================================================
rec_reset
set before [snap $CAN]
lassign [run 30 {PROBE_RC=7} $DRV $here] rc out
set r [lindex [recs] 0]
set th [rget $r home]
check "F1 the driver's exit status survives the EXIT trap" $rc 7
check "F2 exactly one banner line, naming the throwaway" \
  [list [count_lines $out $BANNER_RE] [regexp -line $BANNER_RE $out -> bth] [expr {[info exists bth] ? $bth : {}}]] \
  [list 1 1 $th]
check "F3 the throwaway is <TMPDIR>/xschem-test-home.<ownerpid>.XXXXXX, and .owner names the driver" \
  [list [file dirname $th] [regexp "^xschem-test-home\\.[rget $r pid]\\.\[A-Za-z0-9\]{6}\$" [file tail $th]] [rget $r owner]] \
  [list $TMP 1 [rget $r pid]]
check "F11 .owner is ONE line '<pid> <boot_id> <pidns>' -- this boot's boot_id and the owner's own pid namespace (D13.6)" \
  [rget $r ownerline] "[rget $r pid] [rget $r bootid] [rget $r pidns]"
check "F4 .xschem is pre-created mode 700 (F25's mkdir race)" [rget $r xschemmode] 700
check "F5 the owner deleted it at exit, and the parent HOME is byte-identical" \
  [list [file exists $th] [throwaways] [expr {[snap $CAN] eq $before}]] {0 {} 1}
check "F6 carried: real home, dev-display state dir, git safe.directory (command scope)" \
  [list [rget $r real] [rget $r dd] [rget $r git]] \
  [list $CAN [file join $CAN .claude xschem_dev_display] "1/safe.directory/$repo_phys"]
check "F7 NOT carried when absent in the real home: GUI_GATE_DIR, XAUTHORITY; unset XDG_* stay unset" \
  [list [rget $r gg] [rget $r xauth] [rget $r xdgc] [rget $r xdgd]] {<unset> <unset> <unset> <unset>}

## F9: the delete re-checks ownership at the moment of deleting. If .owner no
## longer names this process, the home is someone else's now and is left alone.
rec_reset
lassign [run 30 [list {PROBE_BODY=echo 1 > "$HOME/.owner"}] $DRV $here] rc out
set r [lindex [recs] 0]
check "F9 an owner whose .owner was rewritten by another process does NOT delete (and says so)" \
  [list $rc [file isdirectory [rget $r home]] [regexp -line {^!! test home: NOT deleting .*\.owner names pid 1,} $out]] {0 1 1}
file delete -force [rget $r home]

## F10: a GIT_CONFIG_COUNT the tester already uses survives; ours is appended once,
## and a nested arm does not stack a second copy.
rec_reset
lassign [run 30 [list GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=tester \
                     {PROBE_BODY="$0" "$H"; echo "gitn_outer=$GIT_CONFIG_COUNT/${GIT_CONFIG_KEY_0}/${GIT_CONFIG_KEY_1-}" >> "$PROBE_REC"}] $DRV $here] rc out
set rs [recs]
check "F10 a tester's own GIT_CONFIG_COUNT survives; safe.directory is appended once, not stacked by a nested arm" \
  [list $rc [string range [rget [lindex $rs 0] git] 0 1] [string range [rget [lindex $rs 1] git] 0 1] [rget [lindex $rs 2] gitn_outer]] \
  {0 2/ 2/ 2/user.name/safe.directory}

## F8: carried when present -- the gate dir and .Xauthority exist, XDG_CACHE_HOME is set
file mkdir [file join $CAN .claude gui_test_gate] [file join $CAN xdgc]
close [open [file join $CAN .Xauthority] w]
rec_reset
lassign [run 30 [list XDG_CACHE_HOME=[file join $CAN xdgc]] $DRV $here] rc out
set r [lindex [recs] 0]
check "F8 carried when present: gate dir, XAUTHORITY; a SET XDG_CACHE_HOME is repointed into the throwaway, its original kept" \
  [list $rc [rget $r gg] [rget $r xauth] [rget $r xdgc] [rget $r prexdgc] [rget $r xdgd]] \
  [list 0 [file join $CAN .claude gui_test_gate] [file join $CAN .Xauthority] \
        [file join [rget $r home] .cache] [file join $CAN xdgc] <unset>]
file delete -force [file join $CAN .claude] [file join $CAN xdgc] [file join $CAN .Xauthority]

## ===========================================================================
## B. THE BANNER WHEN TMPDIR IS INSIDE THE REAL HOME (D13.4): honoured, but it
##    must not claim "your HOME is untouched".
## ===========================================================================
set tin [file join $CAN tmpin]
file mkdir $tin
rec_reset
lassign [run 30 [list TMPDIR=$tin] $DRV $here] rc out
set r [lindex [recs] 0]
set inre {^test home: throwaway (\S+) \(your ~/\.xschem is untouched; the throwaway lives under your HOME because TMPDIR does; XSCHEM_TEST_HOME=real to opt out\)$}
check "B1 TMPDIR inside the real HOME: armed there, the banner says ~/.xschem is untouched and why the home is under HOME -- never 'your HOME is untouched'" \
  [list $rc [file dirname [rget $r home]] [count_lines $out $inre] [count_lines $out {your HOME is untouched}] \
        [count_lines $out {^!! test home: note: the throwaway is INSIDE your real home}] [file exists [rget $r home]]] \
  [list 0 $tin 1 0 1 0]
file delete -force $tin

## ===========================================================================
## N. NESTING -- only the owner deletes; a nested run reuses and never deletes
## ===========================================================================
rec_reset
set before [snap $CAN]
set body {
  n=$(ls -d "$TMPDIR"/xschem-test-home.* 2>/dev/null | wc -l)
  "$0" "$H"; irc=$?
  { echo "during_n=$n"; echo "inner_rc=$irc"; echo "outer_alive_after_inner=$([ -f "$HOME/.owner" ] && echo 1 || echo 0)"
    echo "owner_env_handoff=${XSCHEM_TEST_HOME_HANDOFF-<unset>}"
    echo "owner_after_inner=$(head -n 1 "$HOME/.owner" 2>/dev/null | cut -d' ' -f1)"; echo "n_after_inner=$(ls -d "$TMPDIR"/xschem-test-home.* 2>/dev/null | wc -l)"; } >> "$PROBE_REC"
}
lassign [run 30 [list PROBE_BODY=$body] $DRV $here] rc out
set rs [recs]
set outer [lindex $rs 0]; set inner [lindex $rs 1]; set ob [lindex $rs 2]
check "N1 a driver calling a driver: the inner REUSES the outer's home (nested), no second throwaway" \
  [list [llength $rs] [expr {[rget $inner home] eq [rget $outer home]}] [rget $ob during_n] [rget $ob n_after_inner]] {3 1 1 1}
check "N2 ...the inner neither took ownership nor deleted: .owner still names the outer, home alive" \
  [list [rget $ob owner_after_inner] [rget $ob outer_alive_after_inner] [rget $ob inner_rc]] \
  [list [rget $outer pid] 1 0]
check "N2b the handoff variable is not in an owner's environment, so its children never inherit it (exported only across xvfb_arm's exec)" \
  [rget $ob owner_env_handoff] <unset>
check "N3 ...and the outer deleted it exactly once, at its own exit; parent HOME byte-identical" \
  [list $rc [throwaways] [expr {[snap $CAN] eq $before}] [count_lines $out {^!! test home}]] {0 {} 1 0}

## owed.sh-drain-style: an UNARMED parent (the ledger owner, in the real HOME)
## calls a driver twice. Each call arms its own throwaway and deletes it; the
## parent's own HOME never moves, so a ledger it writes stays where it was.
rec_reset
set before [snap $CAN]
lassign [run 60 [list DRV=$DRV H=$here] bash -c {
  echo "parent_home=$HOME" > "$TMPDIR/../ledger_probe"
  "$DRV" "$H"; "$DRV" "$H"
  echo "parent_home_after=$HOME" >> "$TMPDIR/../ledger_probe"
}] rc out
set rs [recs]
set led [slurp [file join $S ledger_probe]]
check "N4 owed.sh-drain nesting: two driver calls, two DISTINCT throwaways, both deleted" \
  [list $rc [llength $rs] [expr {[rget [lindex $rs 0] home] ne [rget [lindex $rs 1] home]}] [throwaways]] \
  {0 2 1 {}}
check "N5 ...while the unarmed parent's HOME never moved (its ledger stays in the real home)" \
  [list [string trim $led] [expr {[snap $CAN] eq $before}]] \
  [list "parent_home=$CAN\nparent_home_after=$CAN" 1]

## A home whose owner is DEAD is not nested: a fresh arm, the stale one untouched.
set stale [file join $TMP xschem-test-home.[dead_pid].StAle1]
file mkdir $stale
spit [file join $stale .owner] "[lindex [split [file tail $stale] .] 1]\n"
rec_reset
lassign [run 30 [list HOME=$stale XSCHEM_TEST_REAL_HOME=$CAN] $DRV $here] rc out
set r [lindex [recs] 0]
check "N6 a throwaway-shaped HOME with a DEAD owner is not nested: fresh arm, real home from XSCHEM_TEST_REAL_HOME" \
  [list $rc [expr {[rget $r home] ne $stale}] [rget $r real] [file isdirectory $stale] [llength [throwaways]]] \
  [list 0 1 $CAN 1 1]
file delete -force $stale

## A throwaway-shaped HOME with a LIVE owner but no XSCHEM_TEST_REAL_HOME is not
## nested either -- and it is not a real home, so the run is refused, not armed
## with a throwaway standing in as "real".
set live [file join $TMP xschem-test-home.[pid].LiVe01]
file mkdir $live
spit [file join $live .owner] "[pid]\n"
rec_reset
lassign [run 30 [list HOME=$live] $DRV $here] rc out
check "N7 a live throwaway as HOME without XSCHEM_TEST_REAL_HOME: refused, never reused, never treated as real" \
  [list $rc [llength [recs]] [regexp -line {^!! test home: refusing} $out] [file isdirectory $live] [llength [throwaways]]] \
  {2 0 1 1 1}
file delete -force $live

## A forged handoff from a pid that is neither the parent nor the grandparent is
## ignored: the inner stays nested, and the outer's live home survives it.
## A script file, not `bash -c`: bash execs the last command of a -c string in
## place, which would collapse the great-grandchild into a direct child.
set HOP [file join $S hop.sh]
spit $HOP "#!/bin/bash\n\"\$@\"\nexit \$?\n"
file attributes $HOP -permissions 0755
rec_reset
set body {
  XSCHEM_TEST_HOME_HANDOFF=$BASHPID "$HOP" "$HOP" "$0" "$H"; irc=$?
  { echo "inner_rc=$irc"; echo "outer_alive_after_inner=$([ -f "$HOME/.owner" ] && echo 1 || echo 0)"
    echo "owner_after_inner=$(head -n 1 "$HOME/.owner" 2>/dev/null | cut -d' ' -f1)"; } >> "$PROBE_REC"
}
lassign [run 30 [list PROBE_BODY=$body HOP=$HOP] $DRV $here] rc out
set rs [recs]; set outer [lindex $rs 0]; set ob [lindex $rs 2]
check "N8 a forged XSCHEM_TEST_HOME_HANDOFF from a great-grandparent is refused; the live home survives" \
  [list [llength $rs] [rget $ob outer_alive_after_inner] [rget $ob owner_after_inner] \
        [regexp -line {^!! test home: ignoring XSCHEM_TEST_HOME_HANDOFF=[0-9]+ \(pid [0-9]+ is neither} $out] [throwaways]] \
  [list 3 1 [rget $outer pid] 1 {}]

## N8b (D13.8, the round-1 refuter's recipe): an owner hands the variable to a
## DIRECT CHILD with no exec. Parent, and .owner, both match -- but the parent is
## not running xvfb-run, so the exec never happened and the child must not take
## the home over. In round 1 the child took it and deleted it under the parent.
rec_reset
set body {
  XSCHEM_TEST_HOME_HANDOFF=$BASHPID "$0" "$H"; irc=$?
  { echo "inner_rc=$irc"; echo "outer_alive_after_inner=$([ -f "$HOME/.owner" ] && echo 1 || echo 0)"
    echo "owner_after_inner=$(head -n 1 "$HOME/.owner" 2>/dev/null | cut -d' ' -f1)"; } >> "$PROBE_REC"
}
lassign [run 30 [list PROBE_BODY=$body] $DRV $here] rc out
set rs [recs]; set outer [lindex $rs 0]; set inner [lindex $rs 1]; set ob [lindex $rs 2]
check "N8b a DIRECT child handed XSCHEM_TEST_HOME_HANDOFF without an exec is refused (its parent is not running xvfb-run): the parent's live home survives, still the parent's" \
  [list [llength $rs] [expr {[rget $inner home] eq [rget $outer home]}] [rget $ob outer_alive_after_inner] \
        [rget $ob owner_after_inner] \
        [regexp -line {^!! test home: ignoring XSCHEM_TEST_HOME_HANDOFF=[0-9]+ \(pid [0-9]+ is not running xvfb-run} $out] \
        $rc [throwaways]] \
  [list 3 1 1 [rget $outer pid] 1 0 {}]

## N10: a handoff is honoured only for a home under the temp root. Here the
## handoff names this suite's own pid (the probe's grandparent) and .owner
## agrees, but the home sits OUTSIDE TMPDIR: the driver must not take ownership
## (and so must not delete it). Nor is it nested any more (D17.4: a home is
## reused only DIRECTLY UNDER THE TEMP ROOT), so the driver arms a fresh
## throwaway and leaves this one alone -- still the suite's.
set other [file join $S other_root xschem-test-home.[pid].OthEr1]
file mkdir $other
spit [file join $other .owner] "[pid]\n"
rec_reset
lassign [run 30 [list HOME=$other XSCHEM_TEST_REAL_HOME=$CAN XSCHEM_TEST_HOME_HANDOFF=[pid]] $DRV $here] rc out
set r [lindex [recs] 0]
check "N10 a handoff for a home outside the temp root is refused: not taken, not deleted, not reused (a fresh throwaway instead), still the suite's" \
  [list $rc [string match "$TMP/xschem-test-home.*" [rget $r home]] [file isdirectory $other] [string trim [slurp [file join $other .owner]]] \
        [regexp -line {^!! test home: ignoring XSCHEM_TEST_HOME_HANDOFF=[0-9]+ \(HOME is not under the temp root} $out] \
        [regexp -line {^!! test home: note: HOME .* is not directly under the temp root} $out]] \
  [list 0 1 1 [pid] 1 1]
file delete -force [file join $S other_root]

## ===========================================================================
## R. REFUSALS -- never fall back to the real HOME
## ===========================================================================
set tw [file join $TMP xschem-test-home.123.AbCdEf]
file mkdir $tw
set bogus [list 1 relative/dir /nonexistent/xschem_th_zz $tw {}]
set got {}
foreach b $bogus {
  rec_reset
  lassign [run 30 [list XSCHEM_TEST_REAL_HOME=$b] $DRV $here] rc out
  lappend got [list $rc [llength [recs]] [regexp -line {^!! test home: refusing: XSCHEM_TEST_REAL_HOME=} $out]]
}
file delete -force $tw
check "R1 a bogus XSCHEM_TEST_REAL_HOME (a flag, relative, missing, a throwaway, empty) is refused loudly" \
  $got [lrepeat [llength $bogus] {2 0 1}]
check "R2 ...and no refused run created a throwaway" [throwaways] {}

set got {}
set ro [file join $S readonly_tmp]
file mkdir $ro
file attributes $ro -permissions 0500
foreach t [list /nonexistent/xschem_th_tmp $ro] {
  rec_reset
  lassign [run 30 [list TMPDIR=$t] $DRV $here] rc out
  lappend got [list $rc [llength [recs]] [regexp -line {^!! test home: refusing: cannot create a throwaway HOME} $out] \
                    [regexp -line {does NOT fall back to your real HOME} $out]]
}
file attributes $ro -permissions 0700
if {[exec id -u] eq "0"} {
  skip "R3 unwritable TMPDIR" "running as root: a mode-500 directory is still writable"
} else {
  check "R3 an unwritable or missing TMPDIR refuses the run; it never falls back to the real HOME" \
    $got {{2 0 1 1} {2 0 1 1}}
}
rec_reset
lassign [run 30 {HOME=} $DRV $here] rc out
check "R4 an empty HOME is refused (xschem would fall back to the passwd home)" \
  [list $rc [llength [recs]] [regexp -line {^!! test home: HOME is unset or empty} $out]] {2 0 1}
## R6: a mktemp that hands back the real HOME, or an ancestor of it, is refused.
## Unreachable with a real mktemp (it always makes a NEW directory), so a
## stand-in on PATH is the only way to prove the guard is there at all.
set FMK [file join $S fakemk]
file mkdir $FMK
spit [file join $FMK mktemp] "#!/bin/sh\nprintf '%s\\n' \"\$FAKE_MKTEMP_OUT\"\n"
file attributes [file join $FMK mktemp] -permissions 0755
set before [snap $CAN]
set got {}
foreach o [list $CAN [file dirname $CAN]] {
  rec_reset
  lassign [run 30 [list PATH=$FMK:$::env(PATH) FAKE_MKTEMP_OUT=$o] $DRV $here] rc out
  lappend got [list $rc [llength [recs]] [regexp -line {^!! test home: refusing: the throwaway .* is your real HOME or an ancestor} $out]]
}
check "R6 a throwaway path that IS the real HOME, or an ancestor of it, is refused; the canary is untouched" \
  [list $got [expr {[snap $CAN] eq $before}]] [list {{2 0 1} {2 0 1}} 1]

set got {}
foreach b [list relative/x /nonexistent/xschem_th_custom] {
  rec_reset
  lassign [run 30 [list XSCHEM_TEST_HOME=$b] $DRV $here] rc out
  lappend got [list $rc [llength [recs]]]
}
check "R5 XSCHEM_TEST_HOME naming a relative or missing directory is refused" $got {{2 0} {2 0}}

## ===========================================================================
## O. THE OPT-OUT (D6)
## ===========================================================================
rec_reset
set body {"$0" "$H"}
lassign [run 30 [list XSCHEM_TEST_HOME=real PROBE_BODY=$body] $DRV $here] rc out
set rs [recs]
check "O1 XSCHEM_TEST_HOME=real leaves HOME alone and creates nothing" \
  [list $rc [rget [lindex $rs 0] home] [rget [lindex $rs 1] home] [throwaways]] [list 0 $CAN $CAN {}]
check "O2 ...and prints the loud banner on EVERY run, nested ones included" \
  [count_lines $out {^!! test home: REAL -- XSCHEM_TEST_HOME=real}] 2

set cust [file join $S custom_home]
file mkdir $cust
spit [file join $cust keepme] "seed\n"
rec_reset
lassign [run 30 [list XSCHEM_TEST_HOME=$cust] $DRV $here] rc out
set r [lindex [recs] 0]
check "O3 XSCHEM_TEST_HOME=<dir> uses that dir as HOME, says so, and creates no throwaway" \
  [list $rc [rget $r home] [rget $r real] [regexp -line "^test home: custom [string map {. \\.} $cust] " $out] [throwaways]] \
  [list 0 $cust $CAN 1 {}]
check "O4 ...and never deletes it or its contents" \
  [list [file isdirectory $cust] [file exists [file join $cust keepme]] [file isdirectory [file join $cust .xschem]]] {1 1 1}

## O5 (D13.5): XSCHEM_TEST_HOME naming a SYMLINK to the real HOME -- the last
## component itself the link -- is fully resolved before it is compared, and is
## refused. Round 1: the shell refused it, the Tcl side accepted it and wrote
## into the real home. A symlink to a throwaway is refused the same way.
set lnk [file join $S link_to_home]
file link -symbolic $lnk $CAN
set tws [file join $TMP xschem-test-home.[dead_pid].TwSym1]
file mkdir $tws
set lnk2 [file join $S link_to_throwaway]
file link -symbolic $lnk2 $tws
set before [snap $CAN]
set got {}
foreach {l re} [list $lnk {is your real HOME} $lnk2 {names a test throwaway}] {
  rec_reset
  lassign [run 30 [list XSCHEM_TEST_HOME=$l] $DRV $here] rc out
  lappend got [list $rc [llength [recs]] [regexp -line "^!! test home: refusing: XSCHEM_TEST_HOME=.* $re" $out]]
}
check "O5 XSCHEM_TEST_HOME = a symlink to the real HOME (or to a throwaway) is resolved in full and REFUSED; the canary is untouched" \
  [list $got [expr {[snap $CAN] eq $before}] [file isdirectory $tws]] [list {{2 0 1} {2 0 1}} 1 1]
file delete -force $lnk $lnk2 $tws

## ===========================================================================
## G. THE SWEEP (D5, D13.6, D13.7): same uid, owner DEAD, older than 300 s, no
##    .keep; a recorded Xvfb or WM is killed first -- by identity only.
## ===========================================================================
set old [expr {[clock seconds] - 400}]
set week [expr {[clock seconds] - 8 * 86400}]
proc plant {name owner {age_epoch {}}} {
  global TMP
  set d [file join $TMP $name]
  file mkdir $d
  spit [file join $d .owner] "$owner\n"
  if {$age_epoch ne {}} { exec touch -d @$age_epoch $d }
  return $d
}
## a process that looks like <prog> (argv[0]) and was started with HOME=<home>
proc fake_proc {prog home} {
  set p [exec bash -c {( export HOME="$1"; exec -a "$2" sleep 120 ) >/dev/null 2>&1 & echo $!} _ $home $prog]
  track $p
  return $p
}
set dp [dead_pid]
set g_dead_old   [plant xschem-test-home.$dp.DeadOl $dp $old]
set g_dead_young [plant xschem-test-home.$dp.DeadYg $dp]
set g_live_old   [plant xschem-test-home.[pid].LiveOl [pid] $old]
set g_badname    [plant xschem-test-home.abc.BadNam $dp $old]
## D13.7: the recorded server and WM carry THIS throwaway's path as HOME -> killed
set g_xvfb       [plant xschem-test-home.$dp.WithXv $dp]
set fakex [fake_proc Xvfb $g_xvfb]
set fakew [fake_proc fakewm $g_xvfb]
spit [file join $g_xvfb .xvfb.pid] "$fakex\n"
file mkdir [file join $g_xvfb .xvfb]
spit [file join $g_xvfb .xvfb wm.pid] "$fakew\n"
spit [file join $g_xvfb .xvfb wm] "fakewm\n"
exec touch -d @$old $g_xvfb
## ...and the same records naming processes with ANOTHER HOME -> never killed,
## though their throwaway is still swept (round 1 killed them on name alone)
set g_foreign    [plant xschem-test-home.$dp.ForgXv $dp]
set forx [fake_proc Xvfb $S]
set forw [fake_proc fakewm $S]
spit [file join $g_foreign .xvfb.pid] "$forx\n"
file mkdir [file join $g_foreign .xvfb]
spit [file join $g_foreign .xvfb wm.pid] "$forw\n"
spit [file join $g_foreign .xvfb wm] "fakewm\n"
exec touch -d @$old $g_foreign
set g_target [file join $S sweep_target]
file mkdir $g_target
spit [file join $g_target .owner] "$dp\n"
set g_link [file join $TMP xschem-test-home.$dp.SymLnk]
file link -symbolic $g_link $g_target
exec touch -h -d @$old $g_link
## D13.6: `<pid> <boot_id> <pidns>`
set g_otherboot  [plant xschem-test-home.[pid].OBoot1 "[pid] 00000000-0000-0000-0000-000000000000 $MYNS" $old]
set g_otherns    [plant xschem-test-home.$dp.ONs001 "$dp $BOOT pid:\[1\]" $old]
set g_otherns_wk [plant xschem-test-home.$dp.ONsWk1 "$dp $BOOT pid:\[1\]" $week]
set g_samens_dd  [plant xschem-test-home.$dp.SNsDd1 "$dp $BOOT $MYNS" $old]
set g_samens_lv  [plant xschem-test-home.[pid].SNsLv1 "[pid] $BOOT $MYNS" $old]
set g_dash_dead  [plant xschem-test-home.$dp.Dash01 "$dp - -" $old]
set g_dash_live  [plant xschem-test-home.[pid].Dash02 "[pid] - -" $old]
set g_kept       [plant xschem-test-home.$dp.Kept01 $dp $old]
close [open [file join $g_kept .keep] w]
exec touch -d @$old $g_kept
rec_reset
lassign [run 30 {} $DRV $here] rc out
after 200
check "G1 swept: a dead owner's throwaway older than 300 s" [file exists $g_dead_old] 0
check "G2 kept: a dead owner's throwaway younger than 300 s" [file isdirectory $g_dead_young] 1
check "G3 kept: a LIVE owner's throwaway, however old" [file isdirectory $g_live_old] 1
check "G4 kept: a name that is not xschem-test-home.<pid>.<suffix>" [file isdirectory $g_badname] 1
check "G5 a recorded Xvfb (.xvfb.pid) and WM (.xvfb/wm.pid) whose HOME is that throwaway are killed before it is swept" \
  [list [gone $fakex] [gone $fakew] [file exists $g_xvfb]] {1 1 0}
check "G5b ...but ones with ANOTHER HOME are never killed (D13.7: identity, not name); their dead throwaway is still swept" \
  [list [gone $forx] [gone $forw] [file exists $g_foreign]] {0 0 0}
check "G6 a symlink shaped like a throwaway is neither followed nor removed" \
  [list [file type $g_link] [file isdirectory $g_target]] {link 1}
check "G7 the sweep names what it removed" \
  [list [regexp -line {^test home: swept dead throwaway\(s\):.*DeadOl} $out] [regexp -line {^test home: swept .*DeadYg} $out]] {1 0}
check "G8 D13.6: another boot_id means dead, whatever /proc says of the pid -- swept" [file exists $g_otherboot] 0
check "G9 D13.6: the same boot in ANOTHER pid namespace is presumed live -- kept though its pid is not visible here" \
  [file isdirectory $g_otherns] 1
check "G10 D13.6: ...unless it is older than 7 days -- swept" [file exists $g_otherns_wk] 0
check "G11 D13.6: the same boot and namespace, the pid dead -- swept; the pid alive -- kept" \
  [list [file exists $g_samens_dd] [file isdirectory $g_samens_lv]] {0 1}
check "G12 D13.6: a `-` field falls back to the old rule -- dead pid swept, live pid kept" \
  [list [file exists $g_dash_dead] [file isdirectory $g_dash_live]] {0 1}
check "G13 a .keep marker exempts a dead owner's old throwaway" [file isdirectory $g_kept] 1
foreach p [list $forx $forw] { catch {exec kill $p} }
## every plant goes, swept or not, so a later row never sees one of these
foreach d [list $g_dead_old $g_dead_young $g_live_old $g_badname $g_xvfb $g_foreign $g_link $g_target \
                $g_otherboot $g_otherns $g_otherns_wk $g_samens_dd $g_samens_lv $g_dash_dead $g_dash_live $g_kept] {
  file delete -force $d
}

## ===========================================================================
## X. THE xvfb-run RE-EXEC: exactly one owner, the home deleted exactly once,
##    and the WM started under it dies with the run.
## ===========================================================================
set xbase [expr {[info exists ::env(XSCHEM_TEST_XVFB_BASE)] ? $::env(XSCHEM_TEST_XVFB_BASE) : 160}]
set SHIM [file join $S shim]
file mkdir $SHIM
## Keep this suite's servers on ITS numbers, whatever the caller passes: any
## `-n N` is dropped and `-n $xbase` goes FIRST, before `-a` (xvfb-run applies
## its options in order). Every call's own argv is logged, one line each, for
## X10 -- which is how the caller's `-n <base> -a` is seen without starting
## anything on the number it names.
set XRLOG [file join $S xvfbrun_argv.log]
spit [file join $SHIM xvfb-run] [format {#!/bin/bash
printf '%%s\n' "$*" >> '%1$s'
a=()
while [ $# -gt 0 ]; do
  case "$1" in
    -n) shift 2 ;;
    --server-num=*) shift ;;
    -s|-e|-f|-p|-w) a+=("$1" "$2"); shift 2 ;;
    --) shift; break ;;
    -*) a+=("$1"); shift ;;
    *) break ;;
  esac
done
exec '%2$s' -n %3$s "${a[@]}" "$@"
} $XRLOG [exec sh -c {command -v xvfb-run}] $xbase]
file attributes [file join $SHIM xvfb-run] -permissions 0755
set XPATH "PATH=$SHIM:$::env(PATH)"
set FAKEWM [file join $S fakewm]
spit $FAKEWM "#!/bin/bash\nexec -a fakewm sleep 120\n"
file attributes $FAKEWM -permissions 0755
set haveX [expr {[have xvfb-run] && [have Xvfb]}]
set wm [expr {[have openbox] ? "openbox" : "none"}]

if {!$haveX} {
  skip "X1-X7 xvfb-run handoff and reaper" "xvfb-run or Xvfb not installed"
} else {
  rec_reset
  set before [snap $CAN]
  lassign [run 90 [list $XPATH PROBE_XVFB=1 PROBE_RC=5 AUDIT_WM=$wm] $DRV $here] rc out
  set rs [recs]; set r [lindex $rs 0]
  set th [rget $r home]
  set prepid [expr {[regexp {xschem-test-home\.([0-9]+)\.} $th -> pp] ? $pp : -1}]
  check "X1 through the re-exec: the re-exec'd driver OWNS the home (.owner rewritten to it), the handoff is consumed" \
    [list [llength $rs] [rget $r owner] [rget $r handoff] [expr {[rget $r display] ne {}}]] \
    [list 1 [rget $r pid] <unset> 1]
  check "X2 ...it took ownership from its parent, the pre-exec driver whose pid names the home" \
    [rget $r ppid] $prepid
  ## X11 (D17.7): the server xvfb-run started is RECORDED in the owner's
  ## throwaway, `.xvfb.pid` naming the pid its lock names -- the record the
  ## next arm's sweep kills it from, by identity, should everything else fail.
  ## Round 2 recorded nothing on this path.
  check "X11 the private server is recorded in the owner's throwaway (.xvfb.pid names the pid its lock names)" \
    [list [expr {[rget $r xlock] ne {}}] [rget $r xrec]] [list 1 [rget $r xlock]]
  check "X3 ...one banner, the exit status survives xvfb-run, the home is gone, the parent HOME byte-identical" \
    [list [count_lines $out {^test home: throwaway }] $rc [file exists $th] [throwaways] \
          [expr {[snap $CAN] eq $before}] [count_lines $out {^!! test home}]] \
    [list 1 5 0 {} 1 0]
  if {$wm eq "openbox"} {
    check "X4 openbox (AUDIT_WM=openbox) ran under the throwaway and did not outlive the run" \
      [list [expr {[rget $r wm] ne {}}] [file exists /proc/[rget $r wm]] [file exists [file join $CAN .cache]]] {1 0 0}
  } else { skip "X4 openbox under the throwaway" "openbox not installed" }

  ## exactly once: with XSCHEM_TEST_KEEP_HOME=1 the owner's cleanup announces
  ## itself, so the number of cleanups that ran is the number of "kept" lines.
  rec_reset
  lassign [run 90 [list $XPATH PROBE_XVFB=1 XSCHEM_TEST_KEEP_HOME=1 AUDIT_WM=$FAKEWM] $DRV $here] rc out
  set r [lindex [recs] 0]; set th [rget $r home]
  after 300
  check "X5 exactly ONE cleanup ran across the re-exec (one 'kept' line), and the fake WM it started is dead" \
    [list $rc [count_lines $out {^test home: kept }] [file isdirectory $th] \
          [expr {[rget $r wm] ne {}}] [file exists /proc/[rget $r wm]]] {0 1 1 1 0}
  if {[rget $r wm] ne {} && [file exists /proc/[rget $r wm]]} { track [rget $r wm] }
  if {$th ne {<none>}} { file delete -force $th }

  ## X8 (D13.15, the other direction): the reaper must NEVER stop a LIVE run's
  ## display. A run longer than two of its polls keeps its Xvfb and WM throughout.
  ## The first build of the reaper took its owner's start time inside a $(...),
  ## i.e. a dead subshell's, and killed every private display ~10 s in; every
  ## X row above ends in under 5 s, so none of them could see it.
  rec_reset
  set body {n=${DISPLAY#:}; n=${n%%.*}; x=$(tr -cd 0-9 < /tmp/.X$n-lock)
    sleep 12
    { echo "x_alive=$([ -d /proc/$x ] && echo 1 || echo 0)"
      echo "wm_alive=$([ -d /proc/$XSCHEM_XVFB_WM_PID ] && echo 1 || echo 0)"
      echo "dpy_ok=$(timeout 5 xprop -root _NET_SUPPORTED >/dev/null 2>&1 && echo 1 || echo 0)"; } >> "$PROBE_REC"}
  lassign [run 90 [list $XPATH PROBE_XVFB=1 AUDIT_WM=$FAKEWM PROBE_BODY=$body] $DRV $here] rc out
  set b [lindex [recs] 1]
  check "X8 a run lasting longer than two reaper polls keeps its private Xvfb and WM, and its display answers, to the end" \
    [list $rc [rget $b x_alive] [rget $b wm_alive] [rget $b dpy_ok] [throwaways]] {0 1 1 1 {}}
}

## X6 (D13.9): XSCHEM_TEST_KEEP_HOME=1 writes `.keep` AT ARM TIME, so a run that
## is KILLED keeps its home too. Round 1 wrote it only at exit: a killed kept run
## was swept 300 s later, the one case where keeping it matters.
rec_reset
lassign [run 30 [list XSCHEM_TEST_KEEP_HOME=1 {PROBE_BODY=kill -9 $BASHPID}] $DRV $here] rc out
set r [lindex [recs] 0]; set th [rget $r home]
set keep_after_kill [file exists [file join $th .keep]]
if {[file isdirectory $th]} { exec touch -d @$old $th }
rec_reset
lassign [run 30 {} $DRV $here] rc2 out2
check "X6 KEEP: .keep exists while the run is live, a SIGKILLed kept run leaves it, and the next arm's sweep leaves that home alone" \
  [list [rget $r keep] $rc $keep_after_kill [file isdirectory $th] [regexp {swept} $out2]] {1 SIGKILL 1 1 0}
file delete -force $th

## X7 (D13.15): a private Xvfb and its WM must not outlive a KILLED owner by more
## than a few seconds. The driver the tester launched exec'd into xvfb-run, so
## `kill -9 <that pid>` kills xvfb-run -- which is what stops the server on a
## normal exit. Round 1 measured both surviving until the next armed run's
## sweep (>300 s), and forever if nobody ran again.
proc x7_launch {tag wmname} {
  global UNSET CAN TMP REC XPATH DRV here S
  rec_reset
  set body {n=${DISPLAY#:}; n=${n%%.*}
    { echo "xvfb=$(tr -cd 0-9 < /tmp/.X$n-lock)"; echo "q=$BASHPID"; echo "ready=1"; } >> "$PROBE_REC"
    sleep 60}
  set pid [exec timeout -k 5 90 env {*}$UNSET HOME=$CAN TMPDIR=$TMP PROBE_REC=$REC $XPATH \
             PROBE_XVFB=1 AUDIT_WM=$wmname PROBE_BODY=$body $DRV $here >& [file join $S x7_$tag.out] &]
  track $pid
  set t [expr {[clock milliseconds] + 20000}]
  while {[clock milliseconds] < $t} {
    set rs [recs]
    if {[llength $rs] >= 2 && [rget [lindex $rs 1] ready] eq "1"} { break }
    after 100
  }
  return $pid
}
if {$haveX} {
  set x7wm [expr {$wm eq "openbox" ? "openbox" : $FAKEWM}]
  ## (a) kill -9 of the pid the tester started, AFTER the handoff (it is xvfb-run now)
  set tpid [x7_launch a $x7wm]
  set rs [recs]; set r [lindex $rs 0]; set b [lindex $rs 1]
  set P [expr {[regexp {xschem-test-home\.([0-9]+)\.} [rget $r home] -> pp] ? $pp : {}}]
  set X [rget $b xvfb]; set W [rget $r wm]; set Q [rget $b q]
  set pcmd {}; catch {set pcmd [string map [list \x00 { }] [slurp /proc/$P/cmdline]]}
  set pre [list [expr {$P ne {}}] [string match {*xvfb-run*} $pcmd] [expr {![gone $X]}] [expr {![gone $W]}]]
  catch {exec kill -9 $P}
  set t0 [clock milliseconds]
  set ok [wait_gone [list $X $W] 12]
  set dt [expr {([clock milliseconds] - $t0) / 1000.0}]
  check "X7 kill -9 of the driver AFTER the handoff (now xvfb-run): its private Xvfb and WM are gone within ~10 s (the reaper; took ${dt}s)" \
    [concat $pre $ok] {1 1 1 1 1}
  ## the re-exec'd driver is still running (the tester killed xvfb-run, not it):
  ## TERM its process group -- timeout's -- so its EXIT trap deletes the home and
  ## its `sleep` goes with it
  catch {exec kill -TERM -- -$tpid}
  wait_gone [list $Q] 10
  foreach d [throwaways] { file delete -force [file join $TMP $d] }

  ## (b) kill -9 of the re-exec'd driver instead: xvfb-run is alive and stops the
  ## server itself; the WM dies with it. The control for (a).
  set tpid [x7_launch b $x7wm]
  set rs [recs]; set r [lindex $rs 0]; set b [lindex $rs 1]
  set X [rget $b xvfb]; set W [rget $r wm]; set Q [rget $b q]
  set pre [list [expr {![gone $X]}] [expr {![gone $W]}]]
  catch {exec kill -9 $Q}
  set ok [wait_gone [list $X $W] 12]
  check "X7b kill -9 of the re-exec'd driver: xvfb-run stops its Xvfb and the WM goes with it (control)" \
    [concat $pre $ok] {1 1 1}
  catch {exec kill -TERM -- -$tpid}
  wait_gone [list $tpid] 10
  ## a SIGKILLed owner leaves its home; the next run's sweep would take it later
  foreach d [throwaways] { file delete -force [file join $TMP $d] }
}

## X9 (D17.7): NO REAPER WINDOW. The reaper now starts BEFORE the exec into
## xvfb-run, so there is no instant at which a server is up with nobody
## watching it. Round 2 started it inside the session, after the WM claimed the
## screen, and the round-2 regression refuter measured the gap: kill -9 of the
## tester's pid 98-103 ms after the server started left that Xvfb serving for
## good (3 of 3). Forced here: an `Xvfb` stand-in records its pid and its parent
## (xvfb-run: the tester's pid, since the driver exec'd into it) and the instant
## it starts, then BECOMES the real server; xvfb-run is killed -9 50 ms later --
## before the server has even answered, so no launcher, WM or round-2 reaper
## exists yet. Nothing may be left after ~10 s.
if {$haveX} {
  set SH9 [file join $S shim9] ; file mkdir $SH9
  set M9 [file join $S x9.start]
  spit [file join $SH9 Xvfb] [format {#!/bin/sh
echo "$$ $PPID $(date +%%s%%N | cut -c1-13)" > '%1$s'
exec '%2$s' "$@"
} $M9 [exec sh -c {command -v Xvfb}]]
  file attributes [file join $SH9 Xvfb] -permissions 0755
  file delete -force $M9
  rec_reset
  set t9 [exec timeout -k 5 60 env {*}$UNSET HOME=$CAN TMPDIR=$TMP PROBE_REC=$REC PATH=$SH9:$SHIM:$::env(PATH) \
            PROBE_XVFB=1 AUDIT_WM=$FAKEWM {PROBE_BODY=sleep 30} $DRV $here >& [file join $S x9.out] &]
  track $t9
  set X9 {} ; set P9 {} ; set T9 {}
  set tend [expr {[clock milliseconds] + 20000}]
  while {[clock milliseconds] < $tend} {
    set mk [string trim [expr {[file exists $M9] ? [slurp $M9] : {}}]]
    if {[llength $mk] == 3} { lassign $mk X9 P9 T9 ; break }
    after 5
  }
  set at9 {} ; set pc9 {}
  ## (a marker time that is not a millisecond clock near now is not trusted:
  ## this wait must end whatever the stand-in wrote)
  if {$T9 ne {} && [string is wide -strict $T9] && abs([clock milliseconds] - $T9) < 60000} {
    set dl [expr {[clock milliseconds] + 1000}]
    while {[clock milliseconds] < $T9 + 50 && [clock milliseconds] < $dl} { after 2 }
    set at9 [expr {[clock milliseconds] - $T9}]
    catch {set pc9 [string map [list \x00 { }] [slurp /proc/$P9/cmdline]]}
    catch {exec kill -9 $P9}
  }
  set ok9 [expr {$X9 ne {} && [wait_gone [list $X9] 12]}]
  set lk9 {}
  foreach lk [glob -nocomplain -directory /tmp -- {.X[0-9]*-lock}] {
    if {$X9 ne {} && [string trim [slurp $lk]] eq $X9} { lappend lk9 $lk }
  }
  check "X9 kill -9 of the tester's pid (now xvfb-run) 50 ms after its Xvfb started -- before any launcher or WM exists: the server is gone within ~10 s and leaves no lock naming it" \
    [list [expr {$X9 ne {}}] [expr {$at9 ne {} && $at9 < 150}] [string match {*xvfb-run*} $pc9] $ok9 $lk9] {1 1 1 1 {}}
  if {$X9 ne {} && ![gone $X9]} {
    catch {exec kill -9 $X9}
    wait_gone [list $X9] 3
    ## a SIGKILLed server leaves its lock: remove the one naming it, by content
    foreach lk [glob -nocomplain -directory /tmp -- {.X[0-9]*-lock}] {
      if {[string trim [slurp $lk]] eq $X9} { catch {file delete -- $lk} }
    }
  }
  catch {exec kill -TERM -- -$t9}
  foreach d [throwaways] { file delete -force [file join $TMP $d] }
}

## X10 (D17.8): the private arm hands xvfb-run `-n <base> -a`, base >= 100,
## `-n` FIRST -- xvfb-run's `-a` searches upward from whatever number is current
## when it is read, so `-a` alone (round 2) started at :99: the persistent dev
## display's number, taken for a private run whenever the dev display was down.
## Read from xvfb-run's own argv through a stand-in that runs nothing, so no
## server is started on any number -- :99 least of all.
set SH10 [file join $S shim10] ; file mkdir $SH10
set A10 [file join $S x10.argv]
spit [file join $SH10 xvfb-run] "#!/bin/sh
printf '%s\n' \"\$*\" >> '$A10'
exit 0
"
file attributes [file join $SH10 xvfb-run] -permissions 0755
set x10 {}
foreach b {{} 5 99 abc 150} {
  file delete -force $A10
  set e [list PATH=$SH10:$::env(PATH) AUDIT_WM=none]
  if {$b ne {}} { lappend e AUDIT_XVFB_BASE=$b }
  run 30 $e bash [file join $here xvfb_arm.sh] --arm sh -c true
  set av [expr {[file exists $A10] ? [string trim [slurp $A10]] : {}}]
  lappend x10 [expr {[regexp {^-n ([0-9]+) -a } $av -> nb] ? $nb : "<$av>"}]
}
foreach d [throwaways] { file delete -force [file join $TMP $d] }
check "X10 xvfb-run gets `-n <base> -a`, base >= 100 (default 200; below 100 or not a number is corrected), so :99 can never be chosen" \
  $x10 {200 100 100 200 150}

## ===========================================================================
## W4-W8. THE OTHER DOCUMENTED ENTRY POINTS, RUN (D13.1).
## ===========================================================================
## W4: `xvfb_arm.sh --arm` on a non-spawning arm (AUDIT_DISPLAY=none): the POSIX
## command runs as a CHILD under a throwaway that is deleted when it ends.
rec_reset
set before [snap $CAN]
lassign [run 60 [list AUDIT_DISPLAY=none PROBE_RC=6] bash [file join $here xvfb_arm.sh] --arm sh $PSH] rc out
set r [lindex [recs] 0]
check "W4 xvfb_arm.sh --arm (no spawn): the POSIX command gets a throwaway HOME, its exit status, and the home is gone after; the canary is byte-identical" \
  [list $rc [llength [recs]] [string match "$TMP/xschem-test-home.*" [rget $r home]] [rget $r real] \
        [count_lines $out $BANNER_RE] [throwaways] [expr {[snap $CAN] eq $before}]] \
  [list 6 1 1 $CAN 1 {} 1]
## W5: `xvfb_arm.sh --arm` on the PRIVATE Xvfb path: the home crosses the exec by
## handoff to the --wm-launch-own launcher, which owns it, runs the POSIX command
## as its child and deletes the home -- exactly once.
if {!$haveX} {
  skip "W5 xvfb_arm.sh --arm through xvfb-run" "xvfb-run or Xvfb not installed"
} else {
  rec_reset
  set before [snap $CAN]
  lassign [run 90 [list $XPATH AUDIT_WM=$FAKEWM PROBE_RC=4] bash [file join $here xvfb_arm.sh] --arm sh $PSH] rc out
  set r [lindex [recs] 0]
  set prepid [expr {[regexp {xschem-test-home\.([0-9]+)\.} [rget $r home] -> pp] ? $pp : -1}]
  after 300
  check "W5 xvfb_arm.sh --arm through xvfb-run: the launcher (the command's parent) owns the home, taken from the pre-exec --arm process; one banner; exit status kept; home and fake WM gone; canary byte-identical" \
    [list $rc [rget $r owner] [rget $r gppid] [rget $r handoff] [expr {[rget $r display] ne {}}] \
          [count_lines $out {^test home: throwaway }] [count_lines $out {^!! test home}] \
          [throwaways] [expr {[rget $r wm] ne {} && [gone [rget $r wm]]}] [expr {[snap $CAN] eq $before}]] \
    [list 4 [rget $r ppid] $prepid <unset> 1 1 0 {} 1 1]
}
## W6: `test_home.sh --run` behind run.sh's own guard line: one re-exec, a
## throwaway, the loop guard consumed, the exit status kept.
rec_reset
set before [snap $CAN]
lassign [run 60 [list PROBE_RC=3] sh $GSH] rc out
set r [lindex [recs] 0]
check "W6 test_home.sh --run behind run.sh's guard: re-execs ONCE, the script runs in a throwaway that is gone after, the guard variable is not inherited, exit status kept" \
  [list $rc [llength [recs]] [string match "$TMP/xschem-test-home.*" [rget $r home]] [rget $r wrapped] \
        [count_lines $out $BANNER_RE] [throwaways] [expr {[snap $CAN] eq $before}]] \
  [list 3 1 1 <unset> 1 {} 1]
## W7: XSCHEM_TEST_HOME=real through --run: no throwaway, and no re-exec loop.
rec_reset
lassign [run 30 [list XSCHEM_TEST_HOME=real] sh $GSH] rc out
check "W7 --run with XSCHEM_TEST_HOME=real: runs once in the real HOME, loudly, no loop" \
  [list $rc [llength [recs]] [rget [lindex [recs] 0] home] [count_lines $out {^!! test home: REAL}]] [list 0 1 $CAN 1]

## W8: `owed.sh drain` with ONE shell debt. The debt runs under a throwaway armed
## around it alone; the ledger stays at the path fixed from the HOME drain was
## started with -- a scratch ledger here, never the real one.
set OH [file join $S owedhome]
file mkdir [file join $OH .xschem]
spit [file join $OH .xschem geometry] "SENTINEL-geometry\n"
set OW [file join $OH .claude xschem_owed]
set ob [snap [file join $OH .xschem]]
rec_reset
lassign [run 60 [list HOME=$OH] bash [file join $here owed.sh] add suite $PSH "W8 probe"] arc aout
lassign [run 120 [list HOME=$OH] bash [file join $here owed.sh] drain --display :[expr {$xbase + 9}]] rc out
set r [lindex [recs] 0]
set cleared [expr {[file exists [file join $OW cleared.log]] && [string first psh [slurp [file join $OW cleared.log]]] >= 0}]
check "W8 owed.sh drain: the shell debt ran in a throwaway (not the drain's HOME), passed and was cleared in the ledger at the drain's own HOME; the HOME's other files byte-identical" \
  [list $arc $rc [string match "$TMP/xschem-test-home.*" [rget $r home]] [rget $r real] \
        [llength [glob -nocomplain -directory [file join $OW suite] *]] $cleared [throwaways] \
        [expr {[snap [file join $OH .xschem]] eq $ob}]] \
  [list 0 0 1 $OH 0 1 {} 1]

## W8b (D17.9): the drain says where the debt's home is ONCE. It arms around
## the shell debt, and a debt that arms for itself -- run.sh's guard, here --
## used to print the banner a second time from its NESTED arm.
file delete -force $OW
rec_reset
lassign [run 60 [list HOME=$OH] bash [file join $here owed.sh] add suite $GSH "W8b probe"] arc aout
lassign [run 120 [list HOME=$OH] bash [file join $here owed.sh] drain --display :[expr {$xbase + 9}]] rc out
set r [lindex [recs] 0]
check "W8b owed.sh drain of a shell debt that arms for itself prints the throwaway banner exactly once" \
  [list $arc $rc [string match "$TMP/xschem-test-home.*" [rget $r home]] [count_lines $out {^test home: throwaway }] [throwaways]] \
  [list 0 0 1 1 {}]

## W9: a COPY of owed.sh with no test_home.sh beside it (test_owed.sh drains
## through exactly that, to stub run_suites.sh) has nothing to arm with: the
## debt still runs, UNARMED -- and says so, loudly, every time.
set OC [file join $S owedcopy]
file mkdir $OC
file copy -force [file join $here owed.sh] [file join $OC owed.sh]
set OH2 [file join $S owedhome2]
file mkdir $OH2
rec_reset
lassign [run 60 [list HOME=$OH2] bash [file join $OC owed.sh] add suite $PSH "W9 probe"] arc aout
lassign [run 120 [list HOME=$OH2] bash [file join $OC owed.sh] drain --display :[expr {$xbase + 9}]] rc out
set r [lindex [recs] 0]
check "W9 a relocated owed.sh without test_home.sh still drains a shell debt -- in its own HOME, and with a loud '!! owed WARNING' saying so" \
  [list $arc $rc [rget $r home] [regexp -line {^!! owed WARNING: no test_home\.sh beside this owed\.sh .* WITHOUT a throwaway HOME$} $out]] \
  [list 0 0 $OH2 1]

## ===========================================================================
## C. CWD (D13.3): run_suites.sh and gated_xschem.sh run from the repository
##    root, after making the paths they were given absolute. xschem autosaves
##    unsaved work to ./untitled~.sch, so from a tester's home a suite used to
##    overwrite or delete their own ~/untitled~.sch.
## ===========================================================================
set CWD1 [file join $S cwd1]
file mkdir [file join $CWD1 sub]
set CREC [file join $S cwd_rec.txt]
spit [file join $CWD1 sub fake_cwd.tcl] {set f [open $::env(CWD_REC) w]; puts $f [pwd]; close $f
puts "RESULT: ALL PASS (1 checks)"
exit 0
}
spit [file join $CWD1 untitled~.sch] "SENTINEL autosave of the tester's own work\n"
set cb [snap $CWD1]
file delete -force $CREC
lassign [runin $CWD1 120 [list XSCHEM=$XS AUDIT_DISPLAY=none CWD_REC=$CREC] \
           [file join $here run_suites.sh] --nogui sub/fake_cwd.tcl] rc out
set wd [expr {[file exists $CREC] ? [string trim [slurp $CREC]] : {<none>}}]
check "C1 run_suites.sh run from another directory: a RELATIVE suite path still resolves, and the suite runs with cwd = the repository root; that directory is untouched" \
  [list $rc [regexp -line {^PASS +\| fake_cwd } $out] $wd [expr {[snap $CWD1] eq $cb}]] [list 0 1 $repo_phys 1]
file delete -force $CREC
lassign [runin [file join $CWD1 sub] 120 [list XSCHEM=$XS AUDIT_DISPLAY=none CWD_REC=$CREC] \
           [file join $here gated_xschem.sh] --nogui --pipe -q --nolog --script fake_cwd.tcl] rc out
set wd [expr {[file exists $CREC] ? [string trim [slurp $CREC]] : {<none>}}]
check "C2 gated_xschem.sh: an argument naming a path relative to the caller's cwd is made absolute, and xschem runs from the repository root" \
  [list $rc $wd [expr {[snap $CWD1] eq $cb}]] [list 0 $repo_phys 1]

## B2 (D17.3): a RELATIVE TMPDIR, through the real run_suites.sh from another
## directory. It changes to the repository root (C1), so a relative TMPDIR --
## and the relative HOME round 2 made from it -- named a different directory a
## moment later: the round-2 safety refuter measured `NORESULT 'binary never
## reported'` and the throwaway left behind in the caller's cwd (permanent
## litter in the real home when that is where the tester stood). Now TMPDIR is
## exported absolute before anything is made under it.
set CWD2 [file join $S cwd2]
file mkdir [file join $CWD2 reltmp]
file delete -force $CREC
lassign [runin $CWD2 120 [list TMPDIR=reltmp XSCHEM=$XS AUDIT_DISPLAY=none CWD_REC=$CREC] \
           [file join $here run_suites.sh] --nogui [file join $CWD1 sub fake_cwd.tcl]] rc out
check "B2 a relative TMPDIR: run_suites.sh from another directory still PASSES, the home is made (and deleted) under it, and nothing is left in the caller's directory" \
  [list $rc [regexp -line {^PASS +\| fake_cwd } $out] [regexp -line "^test home: throwaway [file join $CWD2 reltmp]/xschem-test-home\\." $out] \
        [lsort [glob -nocomplain -tails -directory $CWD2 *]] [glob -nocomplain -tails -directory [file join $CWD2 reltmp] *]] \
  [list 0 1 1 reltmp {}]

## ===========================================================================
## S. run_suites.sh PRINTS EVERY `skip:` LINE UNDER ITS VERDICT (D13.11).
## ===========================================================================
set SK [file join $S sk]
file mkdir $SK
spit [file join $SK fake_skip.tcl] {puts "ok: one"
puts "skip: A -- no reference here, so group A did not run"
puts "skip: RP -- needs both files, so group RP did not run"
puts "RESULT: ALL PASS (1 checks)"
exit 0
}
spit [file join $SK fake_skipfail.tcl] {puts "FAIL: two"
puts "skip: Z -- no tool"
puts "RESULT: 1 FAILED (0 passed)"
exit 1
}
lassign [run 120 [list XSCHEM=$XS AUDIT_DISPLAY=none] [file join $here run_suites.sh] --nogui \
           [file join $SK fake_skip.tcl] [file join $SK fake_skipfail.tcl]] rc out
set L [split $out \n]
set ip [lsearch -regexp $L {^PASS +\| fake_skip }]
set iF [lsearch -regexp $L {^FAIL +\| fake_skipfail }]
## ⚠ A ROW NAME MUST NOT END IN A COUNTED SHAPE (FAIL, GOLD?, RESULT?): T1 counts
## `ok: <name>` too. This row said "... on a PASS and on a FAIL" and was a
## counted failure in T1 while passing (measured, 2026-09-18).
check "S1 run_suites.sh prints each suite's skip: lines, indented, right under its verdict line, whatever the verdict" \
  [list $rc [lrange $L [expr {$ip + 1}] [expr {$ip + 2}]] [lrange $L [expr {$iF + 1}] [expr {$iF + 2}]]] \
  [list 1 [list {         | skip: A -- no reference here, so group A did not run} \
                {         | skip: RP -- needs both files, so group RP did not run}] \
          [list {         | FAIL: two} {         | skip: Z -- no tool}]]

## ===========================================================================
## K. THE GATE (D7 + the critic): xvfb_arm's "xvfb-run NOT FOUND" arm leaves the
##    gate live. With no real gate dir it must resolve INSIDE the throwaway, and
##    its panel must not outlive the run. With one, the shared panel gets the
##    environment from before the switch -- a SNAPSHOT of it (D13.16).
## ===========================================================================
proc free_display {from to} {
  for {set n $from} {$n <= $to} {incr n} {
    if {![file exists /tmp/.X$n-lock]} { return $n }
  }
  return -1
}
set kdpy -1
if {![have Xvfb] || ![have wish]} {
  skip "K1-K5 gate rows" "Xvfb or wish not installed"
} else {
  set kn [free_display [expr {$xbase + 3}] [expr {$xbase + 8}]]
  if {$kn < 0} {
    skip "K1-K5 gate rows" "no free display in [expr {$xbase + 3}]..[expr {$xbase + 8}]"
  } else {
    set xp [exec bash -c {HOME="$1" Xvfb ":$2" -screen 0 800x600x24 -nolisten tcp >/dev/null 2>&1 & echo $!} _ $S $kn]
    track $xp
    set up 0
    for {set i 0} {$i < 50} {incr i} {
      if {![catch {exec timeout 2 xdpyinfo -display :$kn >/dev/null 2>@1}]} { set up 1; break }
      after 100
    }
    if {$up} { set kdpy $kn } else { skip "K1-K5 gate rows" "fixture Xvfb :$kn did not come up in 5 s" }
  }
}
if {$kdpy > 0} {
  ## PATH without xvfb-run: a farm of links to everything else.
  set FARM [file join $S farm]
  exec bash -c {mkdir -p "$1"; for d in /usr/local/bin /usr/bin /bin /usr/sbin; do
                  for f in "$d"/*; do b=${f##*/}; [ "$b" = xvfb-run ] && continue
                    [ -e "$1/$b" ] || ln -s "$f" "$1/$b"; done; done} _ $FARM
  set KREC [file join $S krec]
  set REC_XS [file join $S recxs.sh]
  spit $REC_XS {#!/bin/bash
# stands in for the xschem binary: record where the live gate panel is
gd="${GUI_GATE_DIR:-$HOME/.claude/gui_test_gate}"
p=$(cat "$gd/widget.pid" 2>/dev/null)
{ echo "home=$HOME"; echo "gate=$gd"; echo "panel=$p"
  echo "panel_home=$(tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep '^HOME=' | cut -d= -f2-)"
  echo "panel_xdgc=$(tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep '^XDG_CACHE_HOME=' | cut -d= -f2-)"
  echo "panel_display=$(tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep '^DISPLAY=' | cut -d= -f2-)"
  echo "panel_harness=$(tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -E '^(XSCHEM_TEST_|GIT_CONFIG_|XSCHEM_DEVDISPLAY_DIR=|XAUTHORITY=)' | cut -d= -f1 | LC_ALL=C sort | tr '\n' ' ')"
  echo "panel_git=$(tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -E '^GIT_CONFIG_' | LC_ALL=C sort | tr '\n' ' ')"
  echo "panel_autostart=$(tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep '^GUI_GATE_AUTOSTART=' | cut -d= -f2-)"
  echo "xdgc=${XDG_CACHE_HOME-}"; } > "$KREC"
}
  file attributes $REC_XS -permissions 0755
  proc krec {} {
    global KREC
    set d {}
    if {![file exists $KREC]} { return $d }
    foreach l [split [slurp $KREC] \n] { if {[regexp {^([a-z_]+)=(.*)$} $l -> k v]} { dict set d $k $v } }
    return $d
  }
  set KENV [list PATH=$FARM DISPLAY=:$kdpy GUI_GATE_AUTOSTART=1 XSCHEM=$REC_XS KREC=$KREC]

  set before [snap $CAN]
  file delete -force $KREC
  lassign [run 90 $KENV [file join $here gated_xschem.sh] hello] rc out
  set k [krec]
  set th [rget $k home]
  check "K1 xvfb-run absent, gate live, no real gate dir: the gate resolves INSIDE the throwaway" \
    [list $rc [regexp -line {^display arm: xvfb-run NOT FOUND} $out] [rget $k gate] [expr {[rget $k panel] ne {}}]] \
    [list 0 1 [file join $th .claude gui_test_gate] 1]
  check "K2 ...its panel was this run's (throwaway HOME) and did not outlive the run" \
    [list [rget $k panel_home] [file exists /proc/[rget $k panel]] [file exists $th]] [list $th 0 0]
  check "K3 ...and nothing was created in the parent HOME (no ~/.claude/gui_test_gate)" \
    [list [file exists [file join $CAN .claude]] [expr {[snap $CAN] eq $before}]] {0 1}
  if {[rget $k panel] ne {} && [file exists /proc/[rget $k panel]]} { track [rget $k panel] }

  ## The shared case: the real gate dir exists, so it is carried, and the panel --
  ## which outlives the run by design -- gets the environment from before the
  ## switch: HOME, the tester's own XDG_CACHE_HOME and GIT_CONFIG_* -- and nothing
  ## the harness added.
  file mkdir [file join $CAN .claude gui_test_gate] [file join $CAN xdgc]
  file delete -force $KREC
  lassign [run 90 [concat $KENV [list XDG_CACHE_HOME=[file join $CAN xdgc] GIT_CONFIG_COUNT=1 \
                                    GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=tester]] \
                   [file join $here gated_xschem.sh] hello] rc out
  set k [krec]
  set p [rget $k panel]
  if {$p ne {} && [file exists /proc/$p]} { track $p }
  check "K4 a SHARED panel (real gate dir exists) is launched with the pre-switch HOME and XDG_CACHE_HOME" \
    [list $rc [rget $k gate] [rget $k panel_home] [rget $k panel_xdgc] [expr {[rget $k xdgc] ne [file join $CAN xdgc]}]] \
    [list 0 [file join $CAN .claude gui_test_gate] $CAN [file join $CAN xdgc] 1]
  check "K5 D13.16: the shared panel's environment is the SNAPSHOT from before arming -- no XSCHEM_TEST_*, no harness GIT_CONFIG_* entry, no carried XSCHEM_DEVDISPLAY_DIR/XAUTHORITY; the tester's own GIT_CONFIG_* and GUI_GATE_AUTOSTART kept; DISPLAY the gate's" \
    [list [rget $k panel_harness] [rget $k panel_git] [rget $k panel_autostart] [rget $k panel_display]] \
    [list {GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 } \
          {GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=tester } 1 :$kdpy]
  kill_all
  file delete -force [file join $CAN .claude] [file join $CAN xdgc]
}

## K6 (D13.16's SCOPE): only the tester's SHARED panel is started from the
## snapshot -- the carried real control dir, or a GUI_GATE_DIR the tester set
## before arming. A gate dir a suite set AFTER arming (the gate's self-tests: a
## temp dir, a STUB `wish` first on PATH, a fake DISPLAY=:99) keeps the current
## environment; `env -i` there would drop the stub and start a REAL wish at :99.
## Measured on _gate_panel_env itself, so it needs no display.
file mkdir [file join $CAN .claude gui_test_gate] [file join $S suitegate] [file join $S testergate]
rec_reset
set body {
  for g in "$SUITEGATE" "$XSCHEM_TEST_REAL_HOME/.claude/gui_test_gate"; do
    ( export GUI_GATE_DIR="$g" PATH="$STUBD:$PATH"; . "$H/gui_gate.sh"; _gate_panel_env
      case "$g" in */suitegate) k=ksuite ;; *) k=kreal ;; esac
      echo "$k=${penv[0]:-none} ${penv[1]:-none}" >> "$PROBE_REC" )
  done
}
lassign [run 30 [list PROBE_BODY=$body SUITEGATE=[file join $S suitegate] STUBD=[file join $S stubpath]] $DRV $here] rc out
set k6a [lindex [recs] 1]
rec_reset
set body {. "$H/gui_gate.sh"; _gate_panel_env; echo "ktester=${penv[0]:-none} ${penv[1]:-none}" >> "$PROBE_REC"}
lassign [run 30 [list PROBE_BODY=$body GUI_GATE_DIR=[file join $S testergate]] $DRV $here] rc2 out2
set k6b [lindex [recs] 1]
check "K6 D13.16 scope: a gate dir a suite set after arming keeps its environment (PATH stubs kept); the real control dir and a GUI_GATE_DIR set before arming get the snapshot (env -i)" \
  [list $rc [rget $k6a ksuite] [rget $k6a kreal] $rc2 [rget $k6b ktester]] \
  [list 0 "env HOME=$CAN" {env -i} 0 {env -i}]
file delete -force [file join $CAN .claude] [file join $S suitegate] [file join $S testergate]

## ===========================================================================
## E. END TO END: the real run_suites.sh and the real xschem, against a canary
##    seeded as DECISIONS D11 says. E0 is the positive control: with the
##    opt-out the canary DOES change, so E1's silence is evidence.
## ===========================================================================
proc seed {h} {
  file mkdir [file join $h .xschem simulations]
  foreach {rel txt} {
    .xschem/.clipboard.sch    "SENTINEL clipboard"
    .xschem/simulations/clean.spice "SENTINEL clean"
    .xschem/simulations/short.spice "SENTINEL short"
    .xschem/recent_files      "SENTINEL recent"
    .xschem/ase_simulators    "SENTINEL registry"
    .spiceinit                "* SENTINEL spiceinit"
    .ngspice_history          "SENTINEL history"
    .gitconfig                "\[user\]\n\tname = canary"
  } {
    set f [open [file join $h $rel] w]; puts $f $txt; close $f
  }
  set f [open [file join $h .xschem geometry] w]
  for {set i 0} {$i < 100} {incr i} { puts $f "SENTINEL-$i 800x600+$i+$i" }
  close $f
}
set E_HOME [file join $S ehome]
seed $E_HOME
set ESUITE test_paste_modify_flag_0244
set EENV [list HOME=$E_HOME XSCHEM=$XS AUDIT_DISPLAY=none]
if {![file exists [file join $here $ESUITE.tcl]]} {
  skip "E0-E1 end to end" "$ESUITE.tcl not present"
} else {
  set b0 [snap $E_HOME]
  lassign [run 300 [concat $EENV {XSCHEM_TEST_HOME=real}] [file join $here run_suites.sh] --nogui $ESUITE] rc0 out0
  set clip [file join $E_HOME .xschem .clipboard.sch]
  set c0 [string trim [slurp $clip]]
  check "E0 control: with XSCHEM_TEST_HOME=real the suite DOES overwrite the canary's clipboard" \
    [list [regexp -line "^PASS +\\| $ESUITE " $out0] [expr {$c0 ne "SENTINEL clipboard"}] [expr {[snap $E_HOME] ne $b0}]] {1 1 1}
  file delete -force $E_HOME
  seed $E_HOME
  set b1 [snap $E_HOME]
  lassign [run 300 $EENV [file join $here run_suites.sh] --nogui $ESUITE] rc1 out1
  check "E1 the same run through run_suites.sh, armed: PASS, and the canary is byte-identical" \
    [list $rc1 [regexp -line "^PASS +\\| $ESUITE " $out1] [expr {[snap $E_HOME] eq $b1}] [throwaways]] {0 1 1 {}}
}
## E2 (D13.1): run_nogui.sh, the T2 smoke driver, end to end. Unarmed it wrote a
## 1.2 MB ~/.xschem/simulations/0_examples_top.spice into the tester's home.
file delete -force $E_HOME
seed $E_HOME
set b2 [snap $E_HOME]
lassign [run 120 [list HOME=$E_HOME] sh [file join $here run_nogui.sh]] rc2 out2
check "E2 run_nogui.sh, armed: RESULT: PASS, and the canary is byte-identical (no simulations/ netlist)" \
  [list $rc2 [regexp -line {^RESULT: PASS$} $out2] [expr {[snap $E_HOME] eq $b2}] [throwaways]] {0 1 1 {}}

kill_all
## the reaper exits on its own within a second of the server it guards
after 1500
set leftover {}
set reapers {}
foreach p [split [exec sh -c {ls /proc | grep -E '^[0-9]+$'}] \n] {
  if {[catch {set fh [open /proc/$p/environ]; fconfigure $fh -translation binary; set e [read $fh]; close $fh}]} continue
  if {[string first "HOME=$S" $e] >= 0 || [string first "HOME=$TMP" $e] >= 0} { lappend leftover $p }
  if {[catch {set fh [open /proc/$p/cmdline]; fconfigure $fh -translation binary; set c [read $fh]; close $fh}]} continue
  if {[string first --reap $c] >= 0 && [string first $TMP $c] >= 0} { lappend reapers $p }
}
check "Z1 no process started by this suite is left alive (by HOME in /proc/<pid>/environ)" $leftover {}
check "Z2 no reaper (xvfb_arm.sh --reap) naming this suite's homes is left alive" $reapers {}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks[expr {$nskip ? ", $nskip skipped" : ""}])"
  puts "OVERALL: ok"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
  exit 1
}
