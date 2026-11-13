# tests/headless/test_t1_display_arm.tcl
#
# A T1 GATE NEVER WAITS FOR THE DEV DISPLAY (backlog batch 2026-11-12, stage B;
# doc/claude/backlog_1112_batch/receipts/B-t1display.md).
#
# Two sessions on this machine share the persistent dev display. T1's display
# arm attached to it whenever `devdisplay.sh status` said alive, so a gate run
# while another run had windows there either disturbed that run or had to ask
# it to stop. run_regression.tcl now, in `auto` (the default of T1_DISPLAY):
#   * asks t1_dev_display_users whether another live run is on the dev display
#     -- by /proc identity (comm, cmdline, exec-time environment), never by a
#     pattern over command lines -- and takes a private Xvfb when one is;
#   * hands the private arm's state dir and number to the hcases children too,
#     so the hcases rows that route one display child through
#     `devdisplay.sh exec` run on a private gate exactly as on an attached one;
#   * obeys T1_DISPLAY=dev (attach anyway) and T1_DISPLAY=private (never
#     attach); anything else is read as private, the side that disturbs nobody.
#
# STAGE E (doc/claude/backlog_1112_batch/receipts/E-launchers.md): the
# launchers step aside too. The detector moved to
# tests/headless/dev_display_users.tcl, which run_regression.tcl sources and
# xvfb_arm.sh runs as a script, so run_suites.sh, full_audit.sh and
# gated_xschem.sh answer "who holds the dev display" by the same code.
# AUDIT_DISPLAY takes T1_DISPLAY's vocabulary (auto|dev|private). Rows TL1-TL9
# run the REAL launchers against the same fixture dev display, with a stand-in
# binary; TL3 asks a T1 copy and a launcher about one process table at once.
#
# THE METHOD. Every row but TD11 runs a COPY of the real run_regression.tcl
# (rows are measured against the driver as it stands, not a model of it) with
# empty tcases, one hcases and one dcases entry, and a stand-in for the binary
# that reports which display and which devdisplay state it was handed. The
# "dev display" is a FIXTURE: a real devdisplay.sh started in a fixture HOME on
# a reserved number, so nothing here looks at, attaches to or counts anything
# on the real dev display, and no other session's processes match the
# fixture's state dir. Holders are copies of ordinary binaries given the names
# the detector keys on, started as siblings of the driver copy (a driver never
# counts its own ancestors or descendants -- row TD6 is that half).
#
# TD11 is the population row: every registered hcases suite that prints a
# `skip:` line gated on `devdisplay.sh status` is run with a state dir and
# number naming the fixture display -- the shape the private arm hands them --
# and must run its gated rows rather than skip them. A control run of one
# member with a state dir that does not exist must skip, so the row is not
# green merely because the gate stopped asking.
#
#   headless (the only arm; the displays here are fixtures it starts and stops)
#     tests/headless/run_suites.sh --nogui test_t1_display_arm
#   XSCHEM_T1DA_BASE  first fixture display number (default 240; 16 are tried)

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail" ; incr npass } else { puts "FAIL: $name $detail" ; incr fail }
}
proc skip {name why} { puts "skip: $name -- $why" }
proc has_text {haystack needle} { expr {[string first $needle $haystack] >= 0} }
proc slurp {p} {
  if {[catch {open $p r} f]} { return {} }
  fconfigure $f -translation binary
  set t [read $f] ; close $f ; return $t
}
proc spit {p body} {
  set f [open $p w] ; puts -nonewline $f $body ; close $f ; return $p
}
proc running {p} {
  if {![string is integer -strict $p] || ![file isdirectory /proc/$p]} { return 0 }
  if {[catch {set f [open /proc/$p/stat r]; set s [read $f]; close $f}]} { return 1 }
  set i [string last ")" $s]
  return [expr {[string index [string range $s [expr {$i + 1}] end] 1] ne "Z"}]
}
proc stop_pid {p} {
  if {![string is integer -strict $p]} { return }
  catch {exec kill -TERM $p}
  for {set i 0} {$i < 30 && [running $p]} {incr i} { after 100 }
  if {[running $p]} { catch {exec kill -KILL $p} }
}

set here  [file normalize [file dirname [info script]]]
set repo  [file normalize [file join $here .. ..]]
set tdir  [file join $repo tests]
set RRSRC [file join $tdir run_regression.tcl]
set DDSH  [file join $here devdisplay.sh]
set DDU   [file join $here dev_display_users.tcl]
set S     [test_scratch t1da]
set PATHV $::env(PATH)
set XS    [info nameofexecutable]

set ::started {}
set ::reserved {}
set ::fixtures {}
proc cleanup {} {
  foreach p $::started { stop_pid $p }
  set ::started {}
  foreach fx $::fixtures {
    lassign $fx h sd n
    catch {exec timeout 30 env -i PATH=$::PATHV HOME=$h XSCHEM_DEVDISPLAY_DIR=$sd DEVDISPLAY_NUM=$n $::DDSH stop 2>@1}
  }
  set ::fixtures {}
  foreach r $::reserved { if {[string trim [slurp $r]] eq [pid]} { catch {file delete -- $r} } }
  set ::reserved {}
}

## A display number with no server, lock or socket on it, RESERVED for this run
## by an O_EXCL file naming this pid (the same discipline as
## test_home_isolation's free_fixture_num, on its own range and file names).
proc free_num {} {
  set base 240
  if {[info exists ::env(XSCHEM_T1DA_BASE)] && [string is integer -strict $::env(XSCHEM_T1DA_BASE)]} {
    set base $::env(XSCHEM_T1DA_BASE)
  }
  set ss {}
  catch {set ss [exec ss -xl 2>/dev/null]}
  for {set n $base} {$n < $base + 16} {incr n} {
    if {[file exists /tmp/.X$n-lock] || [file exists /tmp/.X11-unix/X$n]} { continue }
    if {[regexp "@/tmp/\\.X11-unix/X$n\\M" $ss]} { continue }
    set r /tmp/xschem-t1da-fixture.$n
    if {[file exists $r]} {
      set o [string trim [slurp $r]]
      if {[string is integer -strict $o] && [file isdirectory /proc/$o]} { continue }
      if {[catch {file mtime $r} mt] || [clock seconds] - $mt <= 120} { continue }
      catch {file delete -- $r}
    }
    if {[catch {open $r {WRONLY CREAT EXCL}} f]} { continue }
    puts $f [pid] ; close $f
    lappend ::reserved $r
    return $n
  }
  return {}
}

## The driver copy: the real driver with its lists and binary replaced at the
## first `foreach tc $tcases` line, beside the files it sources.
proc mkdrv {name} {
  set fd [file join $::S $name]
  file mkdir [file join $fd headless]
  foreach f {test_utility.tcl banner_rule.tcl cleanup_debug_file.awk} { file copy -force [file join $::tdir $f] $fd }
  file copy -force $::DDSH [file join $fd headless devdisplay.sh]
  file copy -force $::DDU [file join $fd headless dev_display_users.tcl]
  set sa [spit [file join $fd standin.sh] [join [list \
    {#!/bin/sh} \
    {"$(dirname "$0")/headless/devdisplay.sh" status >/dev/null 2>&1; st=$?} \
    {echo "STANDIN DISPLAY=${DISPLAY:-unset} DDDIR=${XSCHEM_DEVDISPLAY_DIR:-unset} DDNUM=${DEVDISPLAY_NUM:-unset} DDSTATUS=$st"} \
    {echo "OVERALL: ok"} {exit 0} {}] \n]]
  file attributes $sa -permissions 0755
  set inj "set tcases {} ; set hcases \[list hprobe\] ; set dcases \[list st1\] ; set xschem_cmd \[list $sa\]"
  set out {} ; set done 0
  foreach l [split [slurp $::RRSRC] \n] {
    if {!$done && [regexp {^[ \t]*foreach[ \t]+tc[ \t]+\$tcases} $l]} { append out $inj \n ; set done 1 }
    append out $l \n
  }
  spit [file join $fd drv.tcl] $out
  return [list $fd $done]
}
## Run a driver copy with a clean environment naming the fixture dev display.
## `anc`, when given, is a shell binary renamed so that it is the driver's
## ANCESTOR (row TD6); the shell is kept alive around tclsh on purpose.
proc rundrv {fd extra {anc {}}} {
  global FH FSD FN
  set envl [list PATH=$::PATHV HOME=$FH TMPDIR=$::S DEVDISPLAY_NUM=$FN DEVDISPLAY_WM=none {*}$extra]
  if {$anc eq {}} {
    set cmd [list sh -c {cd "$1" && exec tclsh drv.tcl} sh $fd]
  } else {
    set cmd [list $anc -c {cd "$1" && tclsh drv.tcl; rc=$?; exit $rc} xschem $fd]
  }
  set rc 0
  if {[catch {exec timeout 150 env -i {*}$envl {*}$cmd 2>@1} out opt]} {
    set ec [dict get $opt -errorcode]
    set rc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
  }
  catch {spit [file join $fd drv.out] "rc=$rc\n$out\n"}
  return [list $rc $out]
}
## What the stand-in reported in one published case log, as a dict.
proc standin {log} {
  set d [dict create DISPLAY <absent> DDDIR <absent> DDNUM <absent> DDSTATUS <absent>]
  regexp {STANDIN DISPLAY=(\S+) DDDIR=(\S+) DDNUM=(\S+) DDSTATUS=(\S+)} [slurp $log] -> a b c e
  if {[info exists e]} { set d [dict create DISPLAY $a DDDIR $b DDNUM $c DDSTATUS $e] }
  return $d
}
## The arm a driver output chose: {attached {}} | {private <n>} | {other <line>}.
proc arm_of {out} {
  if {[regexp -line {^display arm: PRIVATE Xvfb :([0-9]+) } $out -> p]} { return [list private $p] }
  if {[regexp -line {^display arm: attached to the dev display} $out]} { return [list attached {}] }
  set l {} ; regexp -line {^display arm: .*$} $out l
  return [list other $l]
}
## A copy of an existing binary under the name the detector keys on, in a
## directory of its own so the name is exactly that.
proc named {src name} {
  set d [file join $::S bin_[incr ::named_n]]
  file mkdir $d
  set p [file join $d $name]
  file copy -force $src $p
  file attributes $p -permissions 0755
  return $p
}
set ::named_n 0
## Start a holder with exactly the environment given; wait until /proc shows it
## under its new image (env execs over itself, so the pid is the holder's).
proc hold {envl args} {
  set p [exec env -i PATH=$::PATHV {*}$envl {*}$args </dev/null >/dev/null 2>/dev/null &]
  lappend ::started $p
  set want [file tail [lindex $args 0]]
  if {$want in {sh tclsh}} { set want {} }
  for {set i 0} {$i < 50} {incr i} {
    if {[catch {set f [open /proc/$p/comm r]; set c [string trim [read $f]]; close $f}]} { break }
    if {$c ne {env} && ($want eq {} || [string range $want 0 14] eq $c)} { break }
    after 50
  }
  after 100
  return $p
}
proc unhold {ps} {
  foreach p $ps {
    stop_pid $p
    set i [lsearch -exact $::started $p]
    if {$i >= 0} { set ::started [lreplace $::started $i $i] }
  }
}

## ---------------------------------------------------------------------------
## The fixture dev display.
## ---------------------------------------------------------------------------
set FN [free_num]
if {[auto_execok Xvfb] eq {} || $FN eq {}} {
  skip TD0-TD11 "no Xvfb, or no free fixture display number from [expr {[info exists ::env(XSCHEM_T1DA_BASE)] ? $::env(XSCHEM_T1DA_BASE) : 240}] up, so nothing here could run"
  cleanup
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok ($npass checks)"
  flush stdout
  exit 0
}
set FH  [file join $S fixhome]
set FSD [file join $FH .claude xschem_dev_display]
file mkdir $FSD
catch {exec timeout 30 env -i PATH=$PATHV HOME=$FH XSCHEM_DEVDISPLAY_DIR=$FSD DEVDISPLAY_NUM=$FN DEVDISPLAY_WM=none $DDSH start 2>@1} fxo
lappend ::fixtures [list $FH $FSD $FN]
set fxrc [catch {exec timeout 30 env -i PATH=$PATHV HOME=$FH XSCHEM_DEVDISPLAY_DIR=$FSD DEVDISPLAY_NUM=$FN $DDSH status 2>@1} fxs]
check TD0-the-fixture-dev-display-is-up \
  [expr {$fxrc == 0 && [string match {*state:*alive*} $fxs]}] \
  "-- devdisplay.sh start on :$FN in a fixture HOME; status rc=$fxrc ([string map {\n { | }} [string trim $fxs]])"

## Real files, symlinks resolved: a copy must keep working under its new name,
## and a multicall binary (this box's sleep is one) dispatches on that name.
set SLEEP [lindex [auto_execok sleep] 0]
set SH    [exec readlink -f [lindex [auto_execok sh] 0]]
set TCLSH [exec readlink -f [lindex [auto_execok tclsh] 0]]
set NAP   [spit [file join $S nap.tcl] "after 120000\n"]

## ---------------------------------------------------------------------------
## THE LAUNCHERS (stage E). run_suites.sh, full_audit.sh and gated_xschem.sh,
## the REAL ones in this directory, run with XSCHEM pointing at a stand-in that
## appends the DISPLAY it was handed to a log, in a clean environment naming
## the fixture dev display. Their own private Xvfb numbers from
## $LBASE (AUDIT_XVFB_BASE), clear of the fixture range; AUDIT_WM=none.
## full_audit.sh runs only files that exist, so it is handed this suite's own
## name; the stand-in runs in its place, so nothing recurses.
## ---------------------------------------------------------------------------
set LBASE [expr {$FN + 20}]
set LPROBE [spit [file join $S lprobe.tcl] "# a stand-in suite: the stand-in binary never reads it\n"]
set LSA [spit [file join $S lstandin.sh] [join [list \
  {#!/bin/sh} \
  {echo "LSTANDIN DISPLAY=${DISPLAY:-unset}" >> "$LSTANDIN_LOG"} \
  {echo "RESULT: ALL PASS (1 checks)"} {echo "OVERALL: ok (1 checks)"} {exit 0} {}] \n]]
file attributes $LSA -permissions 0755
set ::lch_n 0
## Run one launcher; returns {rc output displays-the-stand-in-saw}.
proc runlch {which extra {anc {}}} {
  global FH FN LBASE LSA LPROBE
  set log [file join $::S lch_[incr ::lch_n].log]
  set envl [list PATH=$::PATHV HOME=$FH TMPDIR=$::S DEVDISPLAY_NUM=$FN AUDIT_XVFB_BASE=$LBASE \
              AUDIT_WM=none GUI_GATE=0 XSCHEM=$LSA LSTANDIN_LOG=$log {*}$extra]
  switch -- $which {
    run_suites { set cmd [list bash [file join $::here run_suites.sh] $LPROBE] }
    full_audit { set cmd [list bash [file join $::here full_audit.sh] test_t1_display_arm] }
    gated      { set cmd [list bash [file join $::here gated_xschem.sh] --version] }
  }
  if {$anc ne {}} { set cmd [list $anc -c {"$@"; exit $?} xschem {*}$cmd] }
  set rc 0
  if {[catch {exec timeout 120 env -i {*}$envl {*}$cmd 2>@1} out opt]} {
    set ec [dict get $opt -errorcode]
    set rc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
  }
  set seen {}
  foreach {- d} [regexp -all -inline -line {^LSTANDIN DISPLAY=(\S+)} [slurp $log]] { lappend seen $d }
  set seen [lsort -unique $seen]
  return [list $rc $out $seen]
}
## The arm a launcher took: {attached :N} | {private :N} | {other <line>}, read
## from the display the stand-in saw, cross-checked against xvfb_arm's line.
proc larm_of {out seen} {
  global FN
  if {[llength $seen] != 1} { return [list other "stand-in saw [list $seen]"] }
  if {$seen eq ":$FN" && [regexp -line "^display arm: ATTACHED to persistent dev display :$FN " $out]} {
    return [list attached $seen]
  }
  if {[regexp -line {^display arm: private Xvfb from } $out] && $seen ne ":$FN" && [regexp {^:[0-9]+$} $seen]} {
    return [list private $seen]
  }
  return [list other "saw $seen"]
}
## The pids an IN-USE notice names, sorted.
proc named_pids {out} {
  set l {} ; regexp -line {IN USE by (.*?) -- using} $out -> l
  set r {} ; foreach {- p} [regexp -all -inline {pid ([0-9]+)} $l] { lappend r $p }
  return [lsort -integer $r]
}

## Every row below runs inside one catch, so a Tcl error in any of them is a
## counted ABORTED line and the fixture display and holders are still stopped
## (an uncaught error exits 0 from --nogui and would leave both behind).
set td_rc [catch {

## ---------------------------------------------------------------------------
## TD1 -- idle: auto attaches, and says nothing about stepping aside.
## TD10a -- and the hcases child is handed nothing new: the carried state dir
##          already names the dev display, so its devdisplay.sh status says yes.
## ---------------------------------------------------------------------------
lassign [mkdrv d1] fd1 inj1
lassign [rundrv $fd1 {}] rc1 out1
set a1 [arm_of $out1]
set s1 [standin [file join $fd1 st1.disp.log]]
set h1 [standin [file join $fd1 hprobe.log]]
check TD1-auto-with-nobody-on-the-dev-display-attaches-to-it \
  [expr {$inj1 && $rc1 == 0 && [lindex $a1 0] eq {attached} && ![has_text $out1 {IN USE}]
         && [dict get $s1 DISPLAY] eq ":$FN"}] \
  "-- rc=$rc1 arm=[list $a1] (must be attached), the display case saw DISPLAY=[dict get $s1 DISPLAY] (must be :$FN), IN-USE notice present=[has_text $out1 {IN USE}] (must be 0)"
check TD10a-attached-the-hcases-child-reaches-the-dev-display-through-the-carried-state-dir \
  [expr {[dict get $h1 DISPLAY] eq {unset} && [dict get $h1 DDNUM] eq $FN
         && [file normalize [dict get $h1 DDDIR]] eq [file normalize $FSD] && [dict get $h1 DDSTATUS] eq {0}}] \
  "-- the hcases stand-in saw [list $h1] (DISPLAY unset, the fixture state dir and number, devdisplay.sh status 0)"

## ---------------------------------------------------------------------------
## TD2 -- an xschem on the dev display: auto goes private and names the pid.
## TD10b -- and hands the hcases child the PRIVATE display's state dir and
##          number, on which its devdisplay.sh status answers yes.
## ---------------------------------------------------------------------------
set hx [named $TCLSH xschem]
set px [hold [list DISPLAY=:$FN] $hx $NAP]
lassign [mkdrv d2] fd2 inj2
lassign [rundrv $fd2 {}] rc2 out2
unhold [list $px]
set a2 [arm_of $out2]
set s2 [standin [file join $fd2 st1.disp.log]]
set h2 [standin [file join $fd2 hprobe.log]]
check TD2-auto-with-an-xschem-on-the-dev-display-goes-private-and-names-it \
  [expr {$inj2 && $rc2 == 0 && [lindex $a2 0] eq {private} && [lindex $a2 1] != $FN
         && [regexp "IN USE by pid $px \\(xschem" $out2] && [dict get $s2 DISPLAY] eq ":[lindex $a2 1]"}] \
  "-- holder pid $px (comm xschem, DISPLAY=:$FN): rc=$rc2 arm=[list $a2] (must be private), notice naming it=[regexp "IN USE by pid $px \\(xschem" $out2], the display case saw DISPLAY=[dict get $s2 DISPLAY]"
check TD10b-private-the-hcases-child-is-handed-the-private-display-and-reaches-it \
  [expr {[lindex $a2 0] eq {private} && [dict get $h2 DISPLAY] eq {unset} && [dict get $h2 DDNUM] eq [lindex $a2 1]
         && [file normalize [dict get $h2 DDDIR]] ne [file normalize $FSD] && [dict get $h2 DDSTATUS] eq {0}}] \
  "-- private arm :[lindex $a2 1]; the hcases stand-in saw [list $h2] (must be DISPLAY unset, DDNUM=[lindex $a2 1], the private state dir, devdisplay.sh status 0)"

## ---------------------------------------------------------------------------
## TD3 -- a peer T1 on the same state dir and number: auto goes private.
## TD4 -- a run_suites.sh (by comm) and a full_audit.sh (as a shell's script
##        argument), each alone: auto goes private, naming it.
## ---------------------------------------------------------------------------
set pdir [file join $S peer] ; file mkdir $pdir
set peerrr [spit [file join $pdir run_regression.tcl] "after 120000\n"]
set pt [hold [list HOME=$FH DEVDISPLAY_NUM=$FN] $TCLSH $peerrr]
lassign [mkdrv d3] fd3 inj3
lassign [rundrv $fd3 {}] rc3 out3
unhold [list $pt]
set a3 [arm_of $out3]
check TD3-auto-with-a-peer-T1-on-the-same-dev-display-goes-private \
  [expr {$inj3 && $rc3 == 0 && [lindex $a3 0] eq {private} && [regexp "IN USE by pid $pt \\(tclsh" $out3]}] \
  "-- peer tclsh $pt running a run_regression.tcl with HOME=fixture, DEVDISPLAY_NUM=$FN: rc=$rc3 arm=[list $a3], notice naming it=[regexp "IN USE by pid $pt \\(tclsh" $out3]"

set rsd [file join $S rs] ; file mkdir $rsd
set rs1 [spit [file join $rsd run_suites.sh] "#!/bin/sh\nwhile :; do sleep 1; done\n"]
file attributes $rs1 -permissions 0755
set fa1 [spit [file join $rsd full_audit.sh] "while :; do sleep 1; done\n"]
set td4 {}
foreach {tag cmd want} [list run_suites.sh [list $rs1] run_suites.sh full_audit.sh [list $SH $fa1] [file tail $SH]] {
  set ph [hold [list HOME=$FH DEVDISPLAY_NUM=$FN] {*}$cmd]
  lassign [mkdrv d4_[string map {. _} $tag]] fd4 inj4
  lassign [rundrv $fd4 {}] rc4 out4
  unhold [list $ph]
  set a4 [arm_of $out4]
  set named4 [regexp "IN USE by pid $ph \\($want" $out4]
  if {!($inj4 && $rc4 == 0 && [lindex $a4 0] eq {private} && $named4)} {
    lappend td4 "$tag (pid $ph): rc=$rc4 arm=[list $a4] named=$named4"
  }
}
check TD4-auto-with-a-run_suites-or-full_audit-on-the-same-dev-display-goes-private \
  [expr {[llength $td4] == 0}] \
  "-- a run_suites.sh run by its own name, and a full_audit.sh run as `sh full_audit.sh`, each with HOME=fixture and DEVDISPLAY_NUM=$FN, each alone. Not sent private and named (must be none): [expr {[llength $td4] ? [join $td4 {; }] : {none}}]"

## ---------------------------------------------------------------------------
## TD5 -- identity, not pattern: seven processes that LOOK like users and are
## not, all live at once; auto must still attach.
##   an xschem on another display; a sleep (not xschem) on the dev display; a
##   peer T1 on another state dir (the old missing-state-dir trick); a peer T1
##   with T1_DISPLAY=private; a peer T1 whose own private Xvfb carries its tag;
##   a run_suites.sh with AUDIT_DISPLAY naming another display; and a shell
##   whose command line merely CONTAINS the words run_regression.tcl and
##   run_suites.sh.
## ---------------------------------------------------------------------------
set other [expr {$FN + 1}]
set ps5 {}
lappend ps5 [hold [list DISPLAY=:$other] $hx $NAP]
lappend ps5 [hold [list DISPLAY=:$FN] $SLEEP 120]
lappend ps5 [hold [list HOME=$FH DEVDISPLAY_NUM=$FN XSCHEM_DEVDISPLAY_DIR=[file join $S nonexistent]] $TCLSH $peerrr]
lappend ps5 [hold [list HOME=$FH DEVDISPLAY_NUM=$FN T1_DISPLAY=private] $TCLSH $peerrr]
set ptag [hold [list HOME=$FH DEVDISPLAY_NUM=$FN] $TCLSH $peerrr]
lappend ps5 $ptag
lappend ps5 [hold [list XSCHEM_TEST_T1_XVFB_TAG=t1.$ptag.0.150.1] [named $TCLSH Xvfb] $NAP]
lappend ps5 [hold [list HOME=$FH DEVDISPLAY_NUM=$FN AUDIT_DISPLAY=:$other] $rs1]
lappend ps5 [hold [list HOME=$FH DEVDISPLAY_NUM=$FN] $SH -c {while :; do sleep 1; done # run_regression.tcl run_suites.sh}]
## stage E: a launcher that already took a private Xvfb (xvfb_arm.sh re-execs it
## with XSCHEM_XVFB_ARM=1 and the private DISPLAY), and one told
## AUDIT_DISPLAY=private, are not on the dev display either.
lappend ps5 [hold [list HOME=$FH DEVDISPLAY_NUM=$FN XSCHEM_XVFB_ARM=1 DISPLAY=:$other] $rs1]
lappend ps5 [hold [list HOME=$FH DEVDISPLAY_NUM=$FN AUDIT_DISPLAY=private] $rs1]
lassign [mkdrv d5] fd5 inj5
lassign [rundrv $fd5 {}] rc5 out5
## TL4: the same decoys, the same moment, asked by a launcher.
set tl4 {}
foreach w {run_suites gated} {
  lassign [runlch $w {}] lrc lout lseen
  set la [larm_of $lout $lseen]
  if {[lindex $la 0] ne {attached} || [has_text $lout {IN USE}]} {
    set n {} ; regexp -line {IN USE by .*$} $lout n
    lappend tl4 "$w: rc=$lrc arm=[list $la] notice=[expr {$n eq {} ? {none} : $n}]"
  }
}
set alive5 0 ; foreach p $ps5 { incr alive5 [running $p] }
unhold $ps5
set a5 [arm_of $out5]
set n5 {} ; regexp -line {IN USE by .*$} $out5 n5
check TD5-auto-ignores-processes-that-merely-look-like-users \
  [expr {$inj5 && $rc5 == 0 && $alive5 == [llength $ps5] && [lindex $a5 0] eq {attached} && $n5 eq {}}] \
  "-- [llength $ps5] decoys, $alive5 still alive when the driver finished (all must be); rc=$rc5 arm=[list $a5] (must be attached); notice: [expr {$n5 eq {} ? {none} : $n5}]"
check TL4-a-launcher-in-auto-ignores-the-same-decoys-and-attaches \
  [expr {$alive5 == [llength $ps5] && [llength $tl4] == 0}] \
  "-- run_suites.sh and gated_xschem.sh asked while the same [llength $ps5] decoys were alive ($alive5 alive at the end). Not attached, or a notice printed (must be none): [expr {[llength $tl4] ? [join $tl4 {; }] : {none}}]"

## ---------------------------------------------------------------------------
## TD6 -- never itself: the driver run UNDER an ancestor named xschem whose
## environment names the dev display must not count it, and attaches.
## ---------------------------------------------------------------------------
set anc [named $SH xschem]
lassign [mkdrv d6] fd6 inj6
lassign [rundrv $fd6 [list DISPLAY=:$FN] $anc] rc6 out6
set a6 [arm_of $out6]
check TD6-the-detector-never-counts-the-run-itself-or-its-ancestors \
  [expr {$inj6 && $rc6 == 0 && [lindex $a6 0] eq {attached} && ![has_text $out6 {IN USE}]}] \
  "-- the driver ran under `$anc` (comm xschem, DISPLAY=:$FN): rc=$rc6 arm=[list $a6] (must be attached)"

## ---------------------------------------------------------------------------
## TD7 -- T1_DISPLAY=dev attaches even with an xschem on the dev display.
## TD8 -- T1_DISPLAY=private goes private with nobody on it, and says why.
## TD9 -- an unknown T1_DISPLAY is read as private, and says so.
## ---------------------------------------------------------------------------
set px7 [hold [list DISPLAY=:$FN] $hx $NAP]
lassign [mkdrv d7] fd7 inj7
lassign [rundrv $fd7 [list T1_DISPLAY=dev]] rc7 out7
unhold [list $px7]
set a7 [arm_of $out7]
check TD7-T1_DISPLAY=dev-attaches-even-when-the-dev-display-is-in-use \
  [expr {$inj7 && $rc7 == 0 && [lindex $a7 0] eq {attached} && ![has_text $out7 {IN USE}]}] \
  "-- holder pid $px7 on :$FN: rc=$rc7 arm=[list $a7] (must be attached)"
lassign [mkdrv d8] fd8 inj8
lassign [rundrv $fd8 [list T1_DISPLAY=private]] rc8 out8
set a8 [arm_of $out8]
set h8 [standin [file join $fd8 hprobe.log]]
check TD8-T1_DISPLAY=private-never-attaches-and-says-why \
  [expr {$inj8 && $rc8 == 0 && [lindex $a8 0] eq {private}
         && [regexp -line {^display arm: T1_DISPLAY=private -- not attaching} $out8]
         && [dict get $h8 DDNUM] eq [lindex $a8 1] && [dict get $h8 DDSTATUS] eq {0}}] \
  "-- nobody on :$FN: rc=$rc8 arm=[list $a8] (must be private), the reason line present=[regexp -line {^display arm: T1_DISPLAY=private} $out8], hcases saw [list $h8]"
lassign [mkdrv d9] fd9 inj9
lassign [rundrv $fd9 [list T1_DISPLAY=Dve]] rc9 out9
set a9 [arm_of $out9]
check TD9-an-unknown-T1_DISPLAY-is-read-as-private-and-said-so \
  [expr {$inj9 && $rc9 == 0 && [lindex $a9 0] eq {private}
         && [regexp -line {^display arm: T1_DISPLAY=Dve is not auto, dev or private -- using private} $out9]}] \
  "-- T1_DISPLAY=Dve: rc=$rc9 arm=[list $a9] (must be private), notice present=[regexp -line {T1_DISPLAY=Dve is not} $out9]"

## ---------------------------------------------------------------------------
## TD12 -- a run that does not attach AND gets no private display either (an
## Xvfb that will not start) must not hand its hcases children the dev
## display's state dir: through it their `devdisplay.sh exec` would route onto
## the very display the run stepped aside from or was told to keep off. Both
## ways in: T1_DISPLAY=private, and auto with an xschem on the dev display.
## The Xvfb is a stand-in that exits at once, first on PATH.
## ---------------------------------------------------------------------------
set fxb [file join $S fakexvfb] ; file mkdir $fxb
set fxv [spit [file join $fxb Xvfb] "#!/bin/sh\nexit 1\n"]
file attributes $fxv -permissions 0755
set td12 {} ; set td12n 0
foreach {lab extra holds} [list private [list T1_DISPLAY=private] 0 auto-in-use {} 1] {
  set ph {}
  if {$holds} { set ph [hold [list DISPLAY=:$FN] $hx $NAP] }
  lassign [mkdrv d12_$lab] fd12 inj12
  lassign [rundrv $fd12 [list PATH=$fxb:$::PATHV {*}$extra]] rc12 out12
  if {$ph ne {}} { unhold [list $ph] }
  set h12 [standin [file join $fd12 hprobe.log]]
  set none12 [regexp -line {^display arm: NONE} $out12]
  incr td12n
  if {!($inj12 && $rc12 == 0 && $none12 && [dict get $h12 DDSTATUS] ne {<absent>}
        && [dict get $h12 DDSTATUS] ne {0})} {
    lappend td12 "$lab: rc=$rc12 arm-NONE=$none12 hcases saw [list $h12]"
  }
}
check TD12-no-display-arm-at-all-the-hcases-child-is-not-handed-the-dev-display \
  [expr {$td12n == 2 && [llength $td12] == 0}] \
  "-- $td12n drive(s) with an Xvfb that will not start; the hcases stand-in must see a devdisplay.sh status that is NOT 0 (and the arm must say NONE). Not so (must be none): [expr {[llength $td12] ? [join $td12 {; }] : {none}}]"

## ---------------------------------------------------------------------------
## TL -- THE LAUNCHERS STEP ASIDE TOO (stage E). xvfb_arm.sh asks the same
## question by the same code (tests/headless/dev_display_users.tcl) for
## run_suites.sh, full_audit.sh and gated_xschem.sh.
## TL1 idle: each attaches.  TL2 an xschem on the dev display: each goes
## private and names it.  TL3 parity: with an xschem and a peer T1 holding it
## at once, a T1 copy and a launcher name the SAME pids, and a run_suites.sh
## holder alone is named too.  TL5 a nested launcher that inherited an
## attached arm (XSCHEM_XVFB_ARM=1, DISPLAY=:N) IS a holder.  TL6 the knobs:
## AUDIT_DISPLAY=dev attaches anyway, =private never attaches and says so, an
## explicit display wins and asks nobody.  TL7 never itself: a launcher under
## an ancestor named xschem on the dev display attaches.  TL8 one
## implementation.  TL9 a launcher that cannot ask goes private.
## ---------------------------------------------------------------------------
set tl1 {} ; set tl2 {}
foreach w {run_suites full_audit gated} {
  lassign [runlch $w {}] lrc lout lseen
  set la [larm_of $lout $lseen]
  if {[lindex $la 0] ne {attached} || [has_text $lout {IN USE}]} { lappend tl1 "$w: rc=$lrc arm=[list $la]" }
  set ph [hold [list DISPLAY=:$FN] $hx $NAP]
  lassign [runlch $w {}] lrc lout lseen
  unhold [list $ph]
  set la [larm_of $lout $lseen]
  if {[lindex $la 0] ne {private} || [named_pids $lout] ne [list $ph]} {
    lappend tl2 "$w (holder $ph): rc=$lrc arm=[list $la] named=[list [named_pids $lout]]"
  }
}
check TL1-a-launcher-in-auto-with-nobody-on-the-dev-display-attaches \
  [expr {[llength $tl1] == 0}] \
  "-- run_suites.sh, full_audit.sh, gated_xschem.sh with the fixture dev display :$FN up and idle; the stand-in must see :$FN. Not so (must be none): [expr {[llength $tl1] ? [join $tl1 {; }] : {none}}]"
check TL2-a-launcher-in-auto-with-an-xschem-on-the-dev-display-goes-private-and-names-it \
  [expr {[llength $tl2] == 0}] \
  "-- the same three, each with an xschem (DISPLAY=:$FN) alive; each must take a private Xvfb from :$LBASE and name exactly that pid. Not so (must be none): [expr {[llength $tl2] ? [join $tl2 {; }] : {none}}]"

set ph1 [hold [list DISPLAY=:$FN] $hx $NAP]
set ph2 [hold [list HOME=$FH DEVDISPLAY_NUM=$FN] $TCLSH $peerrr]
lassign [mkdrv dl3] fdl3 injl3
lassign [rundrv $fdl3 {}] rcl3 outl3
lassign [runlch run_suites {}] lrc3 lout3 lseen3
unhold [list $ph1 $ph2]
set want3 [lsort -integer [list $ph1 $ph2]]
set t1n [named_pids $outl3] ; set lnn [named_pids $lout3]
set ph3 [hold [list HOME=$FH DEVDISPLAY_NUM=$FN] $rs1]
lassign [runlch full_audit {}] lrc3b lout3b lseen3b
unhold [list $ph3]
check TL3-a-T1-and-a-launcher-name-the-same-holders-on-one-process-table \
  [expr {$injl3 && $t1n eq $want3 && $lnn eq $want3 && [lindex [larm_of $lout3 $lseen3] 0] eq {private}
         && [named_pids $lout3b] eq [list $ph3] && [lindex [larm_of $lout3b $lseen3b] 0] eq {private}}] \
  "-- holders {xschem $ph1, peer T1 $ph2} at once: the T1 copy named [list $t1n], run_suites.sh named [list $lnn] (both must be [list $want3]) and took [list [larm_of $lout3 $lseen3]]; a run_suites.sh holder $ph3 alone: full_audit.sh named [list [named_pids $lout3b]] and took [list [larm_of $lout3b $lseen3b]]"

set ph5 [hold [list HOME=$FH DEVDISPLAY_NUM=$FN XSCHEM_XVFB_ARM=1 DISPLAY=:$FN] $rs1]
lassign [runlch run_suites {}] lrc5 lout5 lseen5
unhold [list $ph5]
## and one told AUDIT_DISPLAY=dev, which attaches whatever else is there
## (stage E verify: that holder rule was asserted by no row).
set ph5d [hold [list HOME=$FH DEVDISPLAY_NUM=$FN AUDIT_DISPLAY=dev] $rs1]
lassign [runlch run_suites {}] lrc5d lout5d lseen5d
unhold [list $ph5d]
check TL5-a-nested-launcher-on-an-attached-arm-or-one-told-dev-is-a-holder \
  [expr {[named_pids $lout5] eq [list $ph5] && [lindex [larm_of $lout5 $lseen5] 0] eq {private}
         && [named_pids $lout5d] eq [list $ph5d] && [lindex [larm_of $lout5d $lseen5d] 0] eq {private}}] \
  "-- a run_suites.sh with XSCHEM_XVFB_ARM=1 and DISPLAY=:$FN (pid $ph5): named [list [named_pids $lout5]], arm [list [larm_of $lout5 $lseen5]]; one with AUDIT_DISPLAY=dev (pid $ph5d): named [list [named_pids $lout5d]], arm [list [larm_of $lout5d $lseen5d]] (both must be named, both arms private)"

set tl6 {}
set ph6 [hold [list DISPLAY=:$FN] $hx $NAP]
lassign [runlch run_suites [list AUDIT_DISPLAY=dev]] r o v
set la [larm_of $o $v]
if {[lindex $la 0] ne {attached} || [has_text $o {IN USE}]} { lappend tl6 "dev with a holder: arm=[list $la]" }
lassign [runlch run_suites [list AUDIT_DISPLAY=:$other]] r o v
if {$v ne ":$other" || [has_text $o {IN USE}] || ![regexp -line "^display arm: :$other \\(explicit" $o]} {
  lappend tl6 "explicit :$other with a holder: saw [list $v] IN-USE=[has_text $o {IN USE}]"
}
unhold [list $ph6]
lassign [runlch run_suites [list AUDIT_DISPLAY=private]] r o v
set la [larm_of $o $v]
if {[lindex $la 0] ne {private} || ![regexp -line {^display arm: AUDIT_DISPLAY=private -- not attaching} $o]} {
  lappend tl6 "private, idle: arm=[list $la] reason-line=[regexp -line {AUDIT_DISPLAY=private --} $o]"
}
check TL6-AUDIT_DISPLAY-dev-attaches-private-never-does-an-explicit-display-wins \
  [expr {[llength $tl6] == 0}] \
  "-- run_suites.sh with AUDIT_DISPLAY=dev and an xschem on :$FN (must attach), =:$other with the same holder (must use it verbatim, ask nobody), =private with nobody there (must go private and say why). Not so (must be none): [expr {[llength $tl6] ? [join $tl6 {; }] : {none}}]"

lassign [runlch run_suites [list DISPLAY=:$FN] $anc] r7 o7 v7
set la7 [larm_of $o7 $v7]
check TL7-a-launcher-never-counts-itself-or-its-ancestors \
  [expr {[lindex $la7 0] eq {attached} && ![has_text $o7 {IN USE}]}] \
  "-- run_suites.sh under `$anc` (comm xschem, DISPLAY=:$FN): rc=$r7 arm=[list $la7] (must be attached)"

## TL8: the rule exists once. Every *.tcl / *.sh under tests/ (scratch and
## worktree copies aside) is read; exactly one defines t1_dev_display_users,
## the driver sources that file, and xvfb_arm.sh runs it.
set defs {}
foreach f [split [exec find $tdir -type f ( -name *.tcl -o -name *.sh ) -not -path */.scratch/* -not -path */.work.* -not -path */results*] \n] {
  if {[regexp -line {^\s*proc\s+(::)?t1_dev_display_users\M} [slurp $f]]} { lappend defs [file tail $f] }
}
set rrsrc [regexp -line {^\s*source\s+\[file join headless dev_display_users\.tcl\]} [slurp $RRSRC]]
set xasrc [regexp -line {^\s*who=\$\(env -u DISPLAY tclsh "\$helper" } [slurp [file join $here xvfb_arm.sh]]]
set xahlp [regexp -line {^\s*helper="\$\(dirname "\$_XVFB_ARM_SELF"\)/dev_display_users\.tcl"} [slurp [file join $here xvfb_arm.sh]]]
check TL8-one-implementation-the-driver-sources-it-and-xvfb_arm-runs-it \
  [expr {$defs eq {dev_display_users.tcl} && $rrsrc && $xasrc && $xahlp}] \
  "-- files under tests/ defining t1_dev_display_users: [list $defs] (must be exactly dev_display_users.tcl); run_regression.tcl sources it=$rrsrc; xvfb_arm.sh names it=$xahlp and runs it=$xasrc"

## TL9: a launcher whose helper is missing cannot ask, and goes private. A copy
## of this directory's arming files WITHOUT dev_display_users.tcl.
set cpd [file join $S nohelper] ; file mkdir $cpd
foreach f {xvfb_arm.sh devdisplay.sh test_home.sh} { file copy -force [file join $here $f] $cpd }
set log9 [file join $S lch_nohelper.log]
catch {exec timeout 120 env -i PATH=$::PATHV HOME=$FH TMPDIR=$S DEVDISPLAY_NUM=$FN AUDIT_XVFB_BASE=$LBASE AUDIT_WM=none GUI_GATE=0 \
         LSTANDIN_LOG=$log9 bash [file join $cpd xvfb_arm.sh] --arm $LSA 2>@1} o9
set v9 {} ; foreach {- d} [regexp -all -inline -line {^LSTANDIN DISPLAY=(\S+)} [slurp $log9]] { lappend v9 $d }
check TL9-a-launcher-that-cannot-ask-who-holds-the-dev-display-goes-private \
  [expr {[regexp -line {^display arm: cannot ask who holds the dev display} $o9] && [llength $v9] == 1 && $v9 ne ":$FN"}] \
  "-- xvfb_arm.sh --arm from a copy with no dev_display_users.tcl beside it, nobody on :$FN: the stand-in saw [list $v9] (must be one private display), the reason line present=[regexp -line {cannot ask who holds} $o9]"

## TL10 (stage E verify): a helper that HANGS (a tclsh that never returns, the
## shape of a /proc read stuck on a D-state process) is bounded: the launcher
## goes private and says the ask failed, inside XVFB_ARM_ASK_TIMEOUT, instead
## of waiting forever before any suite has a timeout of its own.
set hangd [file join $S hangbin] ; file mkdir $hangd
spit [file join $hangd tclsh] "#!/bin/sh\nexec sleep 600\n"
file attributes [file join $hangd tclsh] -permissions 0755
set t10 [clock milliseconds]
lassign [runlch run_suites [list PATH=$hangd:$::PATHV XVFB_ARM_ASK_TIMEOUT=3]] r10 o10 v10
set t10 [expr {[clock milliseconds] - $t10}]
set la10 [larm_of $o10 $v10]
check TL10-a-launcher-whose-ask-hangs-is-bounded-and-goes-private \
  [expr {$r10 == 0 && [lindex $la10 0] eq {private} && [regexp -line {^display arm: asking who holds the dev display .* failed \(rc=124} $o10] && $t10 < 60000}] \
  "-- run_suites.sh with a tclsh that never returns first on PATH, XVFB_ARM_ASK_TIMEOUT=3, nobody on :$FN: rc=$r10 (must be 0, not the outer timeout's 124) after ${t10}ms, arm=[list $la10] (must be private), the ask-failed line present=[regexp -line {asking who holds the dev display .* failed} $o10]"

## TL11 (stage E verify): stepping aside must never land on the INHERITED
## display. With no xvfb-run on PATH the spawn path falls back to whatever
## DISPLAY the launcher inherited -- the user's real screen here -- where HEAD
## attached the dev display. A launcher that stepped aside (auto, with a holder)
## or was told private runs with DISPLAY unset instead, and says so.
set noxr [file join $S noxr] ; file mkdir $noxr
foreach dir [split $::PATHV :] {
  foreach f [glob -nocomplain -directory $dir *] {
    set b [file tail $f]
    if {$b eq {xvfb-run} || [file exists [file join $noxr $b]]} continue
    catch {file link -symbolic [file join $noxr $b] $f}
  }
}
set tl11 {}
set ph11 [hold [list DISPLAY=:$FN] $hx $NAP]
lassign [runlch run_suites [list PATH=$noxr DISPLAY=:$other]] r o v
if {$v ne {unset} || ![has_text $o {IN USE}]} { lappend tl11 "auto with a holder: rc=$r saw [list $v]" }
unhold [list $ph11]
lassign [runlch run_suites [list PATH=$noxr DISPLAY=:$other AUDIT_DISPLAY=private]] r o v
if {$v ne {unset}} { lappend tl11 "private: rc=$r saw [list $v]" }
check TL11-stepping-aside-without-xvfb-run-never-inherits-the-launchers-display \
  [expr {[llength $tl11] == 0}] \
  "-- run_suites.sh with no xvfb-run on PATH and DISPLAY=:$other inherited (standing for the user's screen); the stand-in must see DISPLAY unset. Not so (must be none): [expr {[llength $tl11] ? [join $tl11 {; }] : {none}}]"

## ---------------------------------------------------------------------------
## TD11 -- the population: every registered hcases suite whose `skip:` line is
## gated on `devdisplay.sh status`, run with the state dir and number of a live
## display (the shape the private arm hands it), must run those rows. Derived
## from the driver's own list and each suite's own text, so a fourth such suite
## joins by existing.
## ---------------------------------------------------------------------------
set rrtxt [slurp $RRSRC]
set hlist {}
set inl 0
foreach l [split $rrtxt \n] {
  if {!$inl && [regexp {^\s*set\s+hcases\s+\[list} $l]} { set inl 1 }
  if {$inl} {
    foreach m [regexp -all -inline {"([^"]+)"} $l] { if {![string match {"*} $m]} { lappend hlist $m } }
    if {![regexp {\\$} $l]} break
  }
}
set pop {}
foreach h $hlist {
  set f [file join $tdir $h.tcl]
  if {![file exists $f]} continue
  set ids {}
  foreach l [split [slurp $f] \n] {
    if {[regexp {^\s*puts\s+"skip:\s+(.*?)\s+--\s+tests/headless/devdisplay\.sh status} $l -> w]} { lappend ids $w }
  }
  if {[llength $ids]} { lappend pop [list $h $f $ids] }
}
## ⚠ EACH CHILD GETS A HOME OF ITS OWN. Their display children run on the
## fixture display, which has no WM, and what they leave in HOME is read by
## every later case sharing this run's throwaway HOME (which file was not
## isolated): test_wave_subwindows row SWA14 reddened in the same T1 when these
## children shared it, and passed when they did not.
set td11 {} ; set td11ok {}
set n11 0
foreach m $pop {
  lassign $m h f ids
  set rc 0
  set h11 [file join $S home11_[incr n11]] ; file mkdir $h11
  if {[catch {exec timeout 240 env -u DISPLAY HOME=$h11 XSCHEM_DEVDISPLAY_DIR=$FSD DEVDISPLAY_NUM=$FN \
                $XS --nogui --pipe -q --script $f 2>@1} o opt]} { set rc 1 }
  set sk {}
  foreach id $ids { if {[regexp -line "^skip: [string map {( \\( ) \\) . \\.} $id] --" $o]} { lappend sk $id } }
  set ok [regexp -line {^OVERALL: ok} $o]
  if {$rc || !$ok || [llength $sk]} {
    lappend td11 "[file tail $h]: rc=$rc OVERALL_ok=$ok still-skipped=[list $sk]"
  } else { lappend td11ok "[file tail $h] ([join $ids {, }])" }
}
## The control: the cheapest member with a state dir that does not exist must
## skip, or the row above would be green merely because a gate stopped asking.
set ctl {}
if {[llength $pop]} {
  set best {} ; set bsz {}
  foreach m $pop { set z [file size [lindex $m 1]] ; if {$bsz eq {} || $z < $bsz} { set bsz $z ; set best $m } }
  lassign $best h f ids
  set h11 [file join $S home11_ctl] ; file mkdir $h11
  catch {exec timeout 240 env -u DISPLAY HOME=$h11 XSCHEM_DEVDISPLAY_DIR=[file join $S nonexistent] DEVDISPLAY_NUM=$FN \
           $XS --nogui --pipe -q --script $f 2>@1} co
  set ctl [list [file tail $h] [regexp -line "^skip: [string map {( \\( ) \\) . \\.} [lindex $ids 0]] --" $co]]
}
check TD11-every-hcases-row-gated-on-devdisplay-status-runs-on-the-display-T1-hands-it \
  [expr {[llength $pop] >= 1 && [llength $td11] == 0 && [lindex $ctl 1] == 1}] \
  "-- population derived from hcases and each suite's own `skip: ... devdisplay.sh status` line: [llength $pop] suite(s);\
 ran their gated rows on :$FN named only by XSCHEM_DEVDISPLAY_DIR/DEVDISPLAY_NUM: [expr {[llength $td11ok] ? [join $td11ok {; }] : {none}}];\
 failed or still skipped (must be none): [expr {[llength $td11] ? [join $td11 {; }] : {none}}];\
 control [lindex $ctl 0] with a missing state dir skipped=[lindex $ctl 1] (must be 1)"

} td_err]
if {$td_rc} {
  puts "FAIL: TD-ABORTED the rows stopped on a Tcl error: [string map {\n { | }} $td_err]"
  incr fail
}
cleanup
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
