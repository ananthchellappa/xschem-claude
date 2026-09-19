# tests/headless/test_home_isolation.tcl
#
# THE TEST HOME CONTRACT -- the Tcl half of Item 2 of the outsider fixes batch
# (doc/claude/outsider_fixes_batch/DECISIONS.md D4-D8; receipt S2c-T.md).
#
# Until this landed, every documented test command wrote into the tester's real
# home: T1 overwrote their xschem clipboard, same-named netlists in
# ~/.xschem/simulations and saved window positions; `tclsh netlisting.tcl` with
# no built binary ran an INSTALLED xschem against the real ~/.xschem; and the
# display arm started a persistent Xvfb + openbox into a stranger's real home
# and never stopped it. All of it measured by the outsider audit (F6 F7 F8 F10
# F36). The fix is `t1_arm_home` in tests/test_utility.tcl, which switches HOME
# to a throwaway for the whole driver process, at source time.
#
# ⚠ EVERY ROW HERE RUNS IN A CHILD tclsh UNDER `env -i`, and that is the point.
# The helper arms at SOURCE time, so the only way to measure what it does to an
# environment is to hand it one that is completely known: a seeded canary as
# HOME, a private TMPDIR, and nothing inherited -- not this process's HOME, not
# XSCHEM_TEST_REAL_HOME, not DISPLAY. A row that inherited T1's own throwaway
# would be measuring the nesting rule by accident, and a row that inherited the
# real HOME is the defect this suite exists to prevent.
#
# ⚠ AND IT NEVER SOURCES test_utility.tcl INTO THIS INTERPRETER. This is an
# xschem interpreter; the helper is a no-op in one (row K1 pins that on an
# emulated one), and its globals (`OS`, `xschem_cmd`) would land beside
# xschem's own.
#
# SECTIONS
#   A  a fresh arm: the throwaway, its owner, .xschem 0700, the banner, the
#      delete at exit, and the carry table (D7) including git safe.directory
#   B  nesting: reuse under a live owner, and ALL THREE conditions required
#   C  XSCHEM_TEST_REAL_HOME carries a path and nothing else: refusals
#   D  the opt-outs: `real` (loud, untouched) and `<dir>` (used, never deleted)
#   E  ownership: a non-owner never deletes, a failed re-check never deletes,
#      a kept home is kept -- including from the next run's sweep
#   F  the sweep: dead + old + same uid + pattern + real directory, only
#   J  an unwritable TMPDIR refuses; there is no fallback to the real HOME
#   K  inside an xschem interpreter arming is a no-op; sourcing twice is too
#   G  issue 1397's trap: every $HOME/.claude default in tests/ is carried or
#      allowlisted with a reason
#   G2 D17.1: every script under tests/ that STARTS xschem is armed, runs
#      inside xschem (D9), or is allowlisted with a reason -- the launcher
#      guard that replaces finding unarmed entry points one round at a time
#   H  T1's display arm (D8), through a copy of the real driver: the private
#      Xvfb, the auto-start with the PRE-switch HOME, the fallback when that
#      start fails, and the header fields (D6)
#   L  ONE contract across the two languages: the same environment gets the
#      same verdict from t1_arm_home and test_home.sh's test_home_arm, a home
#      armed by either is nested for the other, `.keep` and the sweep are
#      shared, and the throwaway regex is one string wherever it is spelled
#
# ROUND 2 (DECISIONS D13, after the S2c refuters) added, each red first on the
# round-1 build: the TMPDIR-inside-HOME banner (A4, D13.4), a symlinked TMPDIR
# (A5), XSCHEM_TEST_HOME resolved through a symlink (D4, D5; D13.5), the
# `<pid> <boot_id> <pidns>` owner and its dead rule (A1b, F6, F7 under a real
# `bwrap --unshare-pid`; D13.6), kill-by-identity (F1c; D13.7), `.keep` at arm
# time (E2c; D13.9), `binary=` resolved (H5; D13.10), cleanup checked by
# identity (H1b; D13.14), the private display's reaper (H6; D13.15), the
# pre-switch environment as a snapshot (A3e, B1d, H2b; D13.16), no sentinel
# text in a header value (H1f; D13.17), and section L's rows L6-L12 for the
# same rules across the two languages. The round-2 integration (S2c-R2-I) added
# L10b (the WM record, by identity), L11b (a custom home inside the real one is
# not "untouched"), L13 (nesting only under an owner alive by the D13.6 rule),
# L14 (one reading of a malformed `.owner` pid) and two more L9 shapes, and
# H7 (the private arm takes a display only if its lock names the server it
# started -- a race the batch's concurrent pairs found in the round-1 arm), and
# H6b (the private server is started -noreset, so openbox cannot arrive in the
# middle of a reset and die at startup -- the `wm 0` H6 went red on).
#
# ROUND 3 (DECISIONS D17, after the round-2 refuters) added, each red on the
# round-2 build (receipt S2c-R3-build.md): G2 (the launcher guard), H6c (a T1
# killed before its private server answers leaves no display: the reaper starts
# at the exec), H8 (an installed Xvfb that will not start is a counted HARNESS
# FAIL, never NODISPLAY -- the refuter's sabotage V3), L15 (a custom home whose
# .xschem resolves into the real HOME is refused by both), L16 (nesting only
# directly under the temp root, both), L17 (a relative TMPDIR is exported
# absolute by both), L18 (a nested arm is silent in both); and section H's
# fixture numbers became 150-169, each released when its row is done, so four
# concurrent runs no longer skip H3.
#
#   headless (the only arm; nothing here maps a window of its own)
#     ./src/xschem --nogui --pipe -q --script tests/headless/test_home_isolation.tcl

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
## The value of the first `KEY=value` line of $out, or the sentinel <absent>.
proc kv {out key} {
  foreach l [split $out \n] {
    if {[string first "$key=" $l] == 0} { return [string range $l [string length "$key="] end] }
  }
  return <absent>
}
## The integer in file $f, or {}.
proc t1r_int {f} {
  set v [string trim [slurp $f]]
  if {[string is integer -strict $v] && $v > 0} { return $v }
  return {}
}
proc count_lines {txt needle} {
  set n 0
  foreach l [split $txt \n] { if {[string first $needle $l] >= 0} { incr n } }
  return $n
}

set here  [file normalize [file dirname [info script]]]
set repo  [file normalize [file join $here .. ..]]
set tdir  [file join $repo tests]
set UTIL  [file join $tdir test_utility.tcl]
set RRSRC [file join $tdir run_regression.tcl]
set DDSH  [file join $here devdisplay.sh]
set S     [test_scratch homeiso]
set PATHV $::env(PATH)
set MYUID [string trim [exec id -u]]
set PAT   {^xschem-test-home\.([0-9]+)\.[A-Za-z0-9]+$}

## Processes this suite starts and must not leave behind, whatever happens.
set ::started {}
proc cleanup_started {} {
  foreach p $::started { stop_pid $p }
  set ::started {}
  reap_scratch_displays
  foreach r $::reserved { if {[string trim [slurp $r]] eq [pid]} { catch {file delete -- $r} } }
  set ::reserved {}
}
## TERM, wait, then KILL -- and a SIGKILLed X server leaves /tmp/.X<n>-lock
## behind (measured: a straight KILL after TERM left one for :150), so a lock
## naming the pid just stopped goes too.
proc stop_pid {p} {
  if {![string is integer -strict $p]} { return }
  catch {exec kill -TERM $p}
  for {set i 0} {$i < 30 && [running $p]} {incr i} { after 100 }
  if {[running $p]} { catch {exec kill -KILL $p} }
  foreach lk [glob -nocomplain -directory /tmp -- {.X1[0-9][0-9]-lock}] {
    if {[string trim [slurp $lk]] eq $p} { catch {file delete -- $lk} }
  }
}
## ⚠ AND THE ONES THE CODE UNDER TEST FAILED TO STOP. Section H drives the
## real display arm; when that arm regresses (measured, on the sabotages that
## remove its kills) it leaves an Xvfb or openbox running with a HOME inside
## this suite's scratch, and nothing else would ever stop it. Only those two
## programs, and only with such a HOME -- identity, never a pattern match on a
## command line.
proc reap_scratch_displays {} {
  foreach d [glob -nocomplain -directory /proc -- {[0-9]*}] {
    set p [file tail $d]
    if {$p == [pid]} { continue }
    if {[catch {set f [open $d/environ r]; fconfigure $f -translation binary
                set e [split [read $f] \x00]; close $f}]} { continue }
    set h [lsearch -inline -glob $e HOME=*]
    if {[string first "HOME=$::S/" $h] != 0} { continue }
    if {[catch {set f [open $d/cmdline r]; fconfigure $f -translation binary
                set c [lindex [split [read $f] \x00] 0]; close $f}]} { continue }
    if {[file tail $c] in {Xvfb openbox}} { catch {exec kill -TERM $p} }
  }
  foreach p [reapers_in $::S] { catch {exec kill -TERM $p} }
}
## Live private-display reapers (run_regression.tcl t1_reaper_sh) whose run
## directory is $dir or lies under it -- identified by the marker and the path
## on their own command line, never by a pattern over everyone's.
proc reapers_in {dir} {
  set hits {}
  foreach d [glob -nocomplain -directory /proc -- {[0-9]*}] {
    set p [file tail $d]
    if {$p == [pid]} { continue }
    if {[catch {set f [open $d/cmdline r]; fconfigure $f -translation binary
                set c [split [read $f] \x00]; close $f}]} { continue }
    set i [lsearch -exact $c xschem-t1-reaper]
    if {$i < 0} { continue }
    set rd [lindex $c [expr {$i + 3}]]
    if {$rd eq $dir || [string first "$dir/" $rd] == 0} { lappend hits $p }
  }
  return $hits
}

## Run $body in a child `tclsh` under `env -i` with PATH plus $envl.
## Returns {rc output}; stderr is folded into the output.
set ::kidn 0
proc kid {envl body {tmo 60}} {
  incr ::kidn
  set f [spit [file join $::S kid$::kidn.tcl] $body]
  set rc 0
  if {[catch {exec timeout $tmo env -i PATH=$::PATHV {*}$envl tclsh $f 2>@1} out opt]} {
    set ec [dict get $opt -errorcode]
    set rc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
  }
  return [list $rc $out]
}
## What a long-lived process would actually be started with: the environment of
## `exec {*}[t1_home_preswitch_env] env`, one `P_<name>=<value>` line each --
## behaviour, not the representation of the prefix (D13.16).
set PREENV {
  foreach _l [split [exec {*}[t1_home_preswitch_env] env] \n] {
    if {[regexp {^([A-Za-z_][A-Za-z0-9_]*)=(.*)$} $_l -> _k _v]} { puts "P_$_k=$_v" }
  }
}
## Every name in $out's `<prefix>NAME=` lines that matches glob $pat.
proc kv_names {out prefix pat} {
  set hits {}
  set n [string length $prefix]
  foreach l [split $out \n] {
    if {[string first $prefix $l] != 0} { continue }
    set rest [string range $l $n end]
    set i [string first = $rest]
    if {$i <= 0} { continue }
    set k [string range $rest 0 [expr {$i - 1}]]
    if {[string match $pat $k]} { lappend hits $k }
  }
  return [lsort -unique $hits]
}
## This process's boot_id and pid namespace, read the way D13.6 says to.
set MYBOOT [string trim [slurp /proc/sys/kernel/random/boot_id]]
set MYNS {}
catch {set MYNS [file readlink /proc/self/ns/pid]}

## The standard probe: source the helper, then report.
proc probe {{extra {}}} {
  return "source [list $::UTIL]
puts \"MARK=after-source\"
puts \"HOME=\$::env(HOME)\"
puts \"PID=\[pid\]\"
puts \"KIND=\[t1_home_kind\]\"
foreach k {XSCHEM_TEST_REAL_HOME XSCHEM_DEVDISPLAY_DIR GUI_GATE_DIR XAUTHORITY
           XDG_CACHE_HOME XDG_CONFIG_HOME GIT_CONFIG_COUNT XSCHEM_TEST_PRE_XDG_CACHE_HOME} {
  if {\[info exists ::env(\$k)\]} { puts \"\$k=\$::env(\$k)\" }
}
$extra
"
}

## A seeded canary home: the files the audit measured being overwritten.
proc mkcanary {name args} {
  set c [file join $::S $name]
  file mkdir [file join $c .xschem simulations]
  spit [file join $c .xschem .clipboard.sch] "canary clipboard $name\n"
  spit [file join $c .xschem simulations clean.spice] "* canary clean.spice\n"
  spit [file join $c .xschem simulations short.spice] "* canary short.spice\n"
  spit [file join $c .gitconfig] "\[user\]\n\tname = canary\n"
  foreach a $args {
    lassign [split $a :] kind rel
    if {$kind eq "dir"} { file mkdir [file join $c $rel] } else { spit [file join $c $rel] "canary\n" }
  }
  return $c
}
## Everything under $dir: path, type, size, mtime and contents. An md5 manifest
## alone cannot see a NEW file (the S2a critic's point 6a), so this lists them.
proc snap {dir} {
  set out {}
  set todo [list $dir]
  while {[llength $todo]} {
    set d [lindex $todo 0] ; set todo [lrange $todo 1 end]
    foreach f [lsort [glob -nocomplain -directory $d -- * .*]] {
      set t [file tail $f]
      if {$t eq "." || $t eq ".."} { continue }
      if {[catch {file lstat $f st}]} { continue }
      set rel [string range $f [string length $dir] end]
      set row [list $rel $st(type) $st(size) $st(mtime)]
      if {$st(type) eq "file"} { lappend row [slurp $f] }
      if {$st(type) eq "directory"} { lappend todo $f }
      lappend out $row
    }
  }
  if {![catch {file lstat $dir st}]} { lappend out [list . $st(type) $st(mtime)] }
  return $out
}
proc entries {dir} {
  set out {}
  foreach f [glob -nocomplain -directory $dir -- * .*] {
    set t [file tail $f]
    if {$t ne "." && $t ne ".."} { lappend out $t }
  }
  return [lsort $out]
}
proc mktroot {name} { set d [file join $::S $name] ; file mkdir $d ; return $d }
## A pid that is certainly dead: one of our own children, after it exited.
proc dead_pid {} {
  set p [exec sh -c {sh -c 'echo $$' ; true}]
  for {set i 0} {$i < 50 && [file exists /proc/$p]} {incr i} { after 20 }
  return $p
}
proc backdate {path secs} { catch {file mtime $path [expr {[clock seconds] - $secs}]} }
## $path relative to this process's cwd when it lies under it, else {} -- a
## relative spelling that EXISTS, so that only the "absolute" rule can refuse it.
proc relpath {path} {
  set here [file normalize [pwd]]
  if {[string first "$here/" $path] == 0} { return [string range $path [string length "$here/"] end] }
  return {}
}
proc running {p} {
  if {![string is integer -strict $p] || ![file isdirectory /proc/$p]} { return 0 }
  if {[catch {set f [open /proc/$p/stat r]; set s [read $f]; close $f}]} { return 1 }
  set i [string last ")" $s]
  return [expr {[string index [string range $s [expr {$i + 1}] end] 1] ne "Z"}]
}
## Every live process whose environment has KEY=VAL -- the leak detector for
## "no process of this run is left": anything a run started inherited its HOME.
proc procs_with_env {key val} {
  set hits {}
  foreach d [glob -nocomplain -directory /proc -- {[0-9]*}] {
    set p [file tail $d]
    if {$p == [pid] || ![running $p]} { continue }
    if {[catch {set f [open $d/environ r]; fconfigure $f -translation binary
                set e [read $f]; close $f}]} { continue }
    if {[lsearch -exact [split $e \x00] "$key=$val"] >= 0} { lappend hits $p }
  }
  return $hits
}

## =========================================================================
## SECTION A -- a fresh arm
## =========================================================================
set cA  [mkcanary canaryA]
set tA  [mktroot trootA]
set sA0 [snap $cA]
lassign [kid [list HOME=$cA TMPDIR=$tA] [probe {
  set h $::env(HOME)
  puts "OWNER=[string trim [read [set f [open [file join $h .owner]]]]][close $f]"
  puts "XPERM=[format %o [expr {[file attributes [file join $h .xschem] -permissions] & 0777}]]"
  puts "ENTRIES=[glob -nocomplain -directory [file dirname $h] -- xschem-test-home.*]"
}]] rcA outA
set thA [kv $outA HOME]
set okpat [expr {[regexp $PAT [file tail $thA] -> _npid] && [file dirname $thA] eq $tA}]
check A1a-a-fresh-arm-moves-HOME-to-a-new-throwaway-under-TMPDIR \
  [expr {$rcA == 0 && $thA ne $cA && $okpat && [kv $outA PID] eq $_npid}] \
  "-- rc=$rcA HOME=$thA (the canary was $cA); it must be `xschem-test-home.<pid>.XXXXXX` directly under TMPDIR=$tA and name the arming process"
## ⚠ D13.6: `.owner` is `<pid> <boot_id> <pidns>`, not a bare pid -- a pid
## alone means nothing in another pid namespace or after a reboot (F7 below).
set wantA "[kv $outA PID] $MYBOOT $MYNS"
check A1b-the-throwaway-records-its-owner-and-a-private-xschem-dir \
  [expr {$MYBOOT ne {} && $MYNS ne {} && [kv $outA OWNER] eq $wantA && [kv $outA XPERM] eq {700}}] \
  "-- .owner=`[kv $outA OWNER]` (required `$wantA`: the arming pid, this boot's /proc/sys/kernel/random/boot_id and the pid namespace) .xschem mode=[kv $outA XPERM]; the owner is the only process allowed to delete it, and a pre-made .xschem is what stopped sixteen parallel first starts racing to create it (F25: 11/320 to 0/320)"
set bannerA "test home: throwaway $thA (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)"
check A1c-the-run-says-once-where-its-home-is [expr {[count_lines $outA $bannerA] == 1}] \
  "-- expected exactly one line `$bannerA`, found [count_lines $outA $bannerA]"
check A1d-the-real-home-is-carried-as-a-path \
  [expr {[kv $outA XSCHEM_TEST_REAL_HOME] eq $cA && [kv $outA XSCHEM_DEVDISPLAY_DIR] eq [file join $cA .claude xschem_dev_display]}] \
  "-- XSCHEM_TEST_REAL_HOME=[kv $outA XSCHEM_TEST_REAL_HOME] XSCHEM_DEVDISPLAY_DIR=[kv $outA XSCHEM_DEVDISPLAY_DIR]; the dev display's state is READ from the real home, whichever HOME the run has"
check A2a-the-owner-deletes-its-throwaway-at-exit \
  [expr {$thA ne {<absent>} && ![file exists $thA] && [entries $tA] eq {}}] \
  "-- after the child exited: $thA exists=[file exists $thA], TMPDIR holds [list [entries $tA]]"
check A2b-the-canary-home-is-byte-identical [expr {[snap $cA] eq $sA0}] \
  "-- a whole-tree snapshot (paths, types, sizes, mtimes, contents) of $cA before and after"

## A3 -- the carry table (D7): each harness path only when it exists.
set cA3 [mkcanary canaryA3 dir:.claude/gui_test_gate dir:.claude/xschem_dev_display file:.Xauthority]
lassign [kid [list HOME=$cA3 TMPDIR=$tA XDG_CACHE_HOME=/nonexistent/xdgcache] [probe $PREENV]] rc3 out3
check A3a-existing-harness-state-is-carried-from-the-real-home \
  [expr {$rc3 == 0 && [kv $out3 GUI_GATE_DIR] eq [file join $cA3 .claude gui_test_gate]
         && [kv $out3 XAUTHORITY] eq [file join $cA3 .Xauthority]}] \
  "-- GUI_GATE_DIR=[kv $out3 GUI_GATE_DIR] XAUTHORITY=[kv $out3 XAUTHORITY]; without the gate dir the shared Pause panel stops governing the run, and without the cookie a protected display cannot be opened (S2a map (8))"
check A3b-absent-harness-state-is-not-carried \
  [expr {[kv $outA GUI_GATE_DIR] eq {<absent>} && [kv $outA XAUTHORITY] eq {<absent>}}] \
  "-- canary with no .claude/gui_test_gate and no .Xauthority: GUI_GATE_DIR=[kv $outA GUI_GATE_DIR] XAUTHORITY=[kv $outA XAUTHORITY]; carried unconditionally, an arm with a live gate would CREATE ~/.claude/gui_test_gate in a stranger's real home (the critic's point 3)"
check A3c-XDG-is-repointed-only-when-already-set \
  [expr {[string first "[kv $out3 HOME]/" "[kv $out3 XDG_CACHE_HOME]"] == 0 && [kv $outA XDG_CACHE_HOME] eq {<absent>}
         && [kv $out3 XSCHEM_TEST_PRE_XDG_CACHE_HOME] eq {/nonexistent/xdgcache}
         && [kv $out3 P_HOME] eq $cA3 && [kv $out3 P_XDG_CACHE_HOME] eq {/nonexistent/xdgcache}}] \
  "-- set: XDG_CACHE_HOME=[kv $out3 XDG_CACHE_HOME] (must be inside HOME=[kv $out3 HOME]), original kept as XSCHEM_TEST_PRE_XDG_CACHE_HOME=[kv $out3 XSCHEM_TEST_PRE_XDG_CACHE_HOME] and handed to long-lived processes (they would see HOME=[kv $out3 P_HOME] XDG_CACHE_HOME=[kv $out3 P_XDG_CACHE_HOME]); unset: [kv $outA XDG_CACHE_HOME] (must stay unset, so the suites that switch HOME for their own children stay coherent)"
## git safe.directory, behaviourally: GIT_TEST_ASSUME_DIFFERENT_OWNER is git's
## own test hook for "this checkout belongs to another uid" -- the CI shape.
if {[file exists [file join $repo .git]] && [auto_execok git] ne {}} {
  lassign [kid [list HOME=$cA TMPDIR=$tA] [probe [format {
    set rc [catch {exec env GIT_TEST_ASSUME_DIFFERENT_OWNER=1 git -C %s rev-parse --verify -q HEAD 2>@1} o]
    puts "GITRC=$rc"
    puts "GITOUT=[string map {"\n" " | "} $o]"
    unset ::env(GIT_CONFIG_COUNT)
    set rc [catch {exec env GIT_TEST_ASSUME_DIFFERENT_OWNER=1 git -C %s rev-parse --verify -q HEAD 2>@1} o]
    puts "GITRC0=$rc"
  } [list $repo] [list $repo]]]] rcg outg
  check A3d-git-trusts-this-checkout-without-the-testers-config \
    [expr {[kv $outg GITRC] eq {0} && [kv $outg GITRC0] ne {0}}] \
    "-- with the command-scope safe.directory: rc=[kv $outg GITRC] ([kv $outg GITOUT]); without it: rc=[kv $outg GITRC0] (must fail -- the non-vacuity half: git really does refuse a foreign-owned checkout here)"
} else {
  skip A3d-git-trusts-this-checkout-without-the-testers-config \
    "no .git in $repo (an export) or no git on PATH, so there is no checkout for git to distrust"
}

## A3e -- D13.16: what a long-lived process gets is a SNAPSHOT of the tester's
## environment from before the arm, not this one with HOME put back. The
## round-1 build handed the auto-started dev display XSCHEM_TEST_REAL_HOME, the
## carried XSCHEM_DEVDISPLAY_DIR and the command-scope safe.directory (the
## regression refuter read them in /proc/<pid>/environ of Xvfb and openbox).
## The tester's own variables -- a marker, their own GIT_CONFIG_* entry, and a
## state dir they set themselves -- must survive; nothing the arm added may.
lassign [kid [list HOME=$cA TMPDIR=$tA TESTER_MARK=kept GIT_CONFIG_COUNT=1 \
                 GIT_CONFIG_KEY_0=core.abbrev GIT_CONFIG_VALUE_0=12] [probe $PREENV]] rc3e out3e
lassign [kid [list HOME=$cA TMPDIR=$tA XSCHEM_DEVDISPLAY_DIR=/nonexistent/mine] [probe $PREENV]] rc3f out3f
set harness3e [concat [kv_names $out3e P_ XSCHEM_TEST_*] [kv_names $out3e P_ XSCHEM_DEVDISPLAY_DIR]]
check A3e-a-long-lived-process-gets-the-testers-own-environment-and-nothing-the-arm-added \
  [expr {$rc3e == 0 && $rc3f == 0 && [kv $out3e P_HOME] eq $cA && [kv $out3e P_TESTER_MARK] eq {kept}
         && [kv $out3e P_GIT_CONFIG_COUNT] eq {1} && [kv $out3e P_GIT_CONFIG_KEY_0] eq {core.abbrev}
         && [kv $out3e P_GIT_CONFIG_VALUE_0] eq {12} && [kv $out3e P_GIT_CONFIG_KEY_1] eq {<absent>}
         && [llength $harness3e] == 0 && [kv $out3e GIT_CONFIG_COUNT] eq {2}
         && [kv $out3f P_XSCHEM_DEVDISPLAY_DIR] eq {/nonexistent/mine}}] \
  "-- it would see HOME=[kv $out3e P_HOME] TESTER_MARK=[kv $out3e P_TESTER_MARK] GIT_CONFIG_COUNT=[kv $out3e P_GIT_CONFIG_COUNT] (KEY_0=[kv $out3e P_GIT_CONFIG_KEY_0], KEY_1=[kv $out3e P_GIT_CONFIG_KEY_1]; the run itself has [kv $out3e GIT_CONFIG_COUNT]) and harness names [list $harness3e] (must be none); a state dir the tester set is kept: [kv $out3f P_XSCHEM_DEVDISPLAY_DIR]"

## A4 -- D13.4: TMPDIR inside the real home is honoured, but the banner must
## not then claim "your HOME is untouched": the throwaway is written, and
## deleted, under it. What stays true is that ~/.xschem is not touched.
set cA4 [mkcanary canaryA4 dir:tmp]
set sA4x [snap [file join $cA4 .xschem]]
lassign [kid [list HOME=$cA4 TMPDIR=[file join $cA4 tmp]] [probe]] rcA4 outA4
set thA4 [kv $outA4 HOME]
set bA4 {}
foreach l [split $outA4 \n] { if {[string match {test home: throwaway *} $l]} { lappend bA4 $l } }
check A4-TMPDIR-inside-the-real-HOME-never-claims-your-HOME-is-untouched \
  [expr {$rcA4 == 0 && [llength $bA4] == 1 && ![has_text [lindex $bA4 0] {your HOME is untouched}]
         && [has_text [lindex $bA4 0] {your ~/.xschem is untouched}]
         && [has_text [lindex $bA4 0] {the throwaway lives under your HOME because TMPDIR does}]
         && [has_text $outA4 {!! test home: note:}] && [string first "$cA4/" $thA4] == 0
         && ![file exists $thA4] && [snap [file join $cA4 .xschem]] eq $sA4x}] \
  "-- HOME=$thA4 (inside $cA4 because TMPDIR is); banner `[lindex $bA4 0]` must not say the HOME is untouched, since this very run is writing into it, and must say what IS true: ~/.xschem is untouched. Gone after exit=[expr {![file exists $thA4]}], ~/.xschem identical=[expr {[snap [file join $cA4 .xschem]] eq $sA4x}]"

## A5 -- a TMPDIR that is a SYMLINK (on macOS, /tmp itself is one). `file
## normalize` resolved the mktemp result but not the root it was compared with,
## so the round-1 build refused EVERY arm here and leaked the directory it had
## just made (measured). The root is now resolved the same way.
set rA5 [mktroot realtmpA5]
set lA5 [file join $S linktmpA5]
file link -symbolic $lA5 $rA5
lassign [kid [list HOME=$cA TMPDIR=$lA5] [probe]] rcA5 outA5
set thA5 [kv $outA5 HOME]
check A5-a-symlinked-TMPDIR-arms-and-cleans-up \
  [expr {$rcA5 == 0 && [regexp $PAT [file tail $thA5]] && [file dirname $thA5] eq $rA5
         && ![file exists $thA5] && [entries $rA5] eq {}}] \
  "-- TMPDIR=$lA5 -> $rA5: rc=$rcA5, HOME=$thA5 (must be directly under the resolved root), left behind: [list [entries $rA5]] (must be none)[expr {$rcA5 == 3 ? { -- REFUSED, as the round-1 build did on every such box} : {}}]"

## =========================================================================
## SECTION B -- nesting
## =========================================================================
set cB [mkcanary canaryB]
set tB [mktroot trootB]
set nested [spit [file join $S nested.tcl] [probe "$PREENV
  t1_home_release
  puts \"STILL=\[file isdirectory \$::env(HOME)\]\"
"]]
lassign [kid [list HOME=$cB TMPDIR=$tB] [probe [format {
  set rc [catch {exec tclsh %s 2>@1} nout]
  puts "NESTRC=$rc"
  foreach l [split $nout \n] { puts "N_$l" }
  puts "AFTER=[file isdirectory $::env(HOME)]"
  puts "NENT=[llength [glob -nocomplain -directory %s -- xschem-test-home.*]]"
} [list $nested] [list $tB]]]] rcB outB
set thB [kv $outB HOME]
check B1a-a-nested-run-reuses-the-live-throwaway \
  [expr {[kv $outB NESTRC] eq {0} && [kv $outB N_HOME] eq $thB && [kv $outB N_KIND] eq {throwaway} && [kv $outB NENT] eq {1}}] \
  "-- outer HOME=$thB, nested HOME=[kv $outB N_HOME], entries under TMPDIR while both ran=[kv $outB NENT] (must be 1: a case run by T1 must live in T1's home, not make its own)"
check B1b-a-nested-run-says-nothing [expr {[count_lines $outB {N_test home:}] == 0}] \
  "-- [count_lines $outB {N_test home:}] banner line(s) from the nested run; only the arming run announces"
## ⚠ AND WITH NONE OF THE PARENT'S HARNESS STATE (D13.16): a nested run has no
## snapshot of the tester's own environment, only its parent's switched one,
## so it must strip what an arm adds -- or the display it starts outlives the
## run carrying XSCHEM_TEST_REAL_HOME, the safe.directory and the state dir.
set harnB [concat [kv_names $outB N_P_ XSCHEM_TEST_*] [kv_names $outB N_P_ GIT_CONFIG_*] [kv_names $outB N_P_ XSCHEM_DEVDISPLAY_DIR]]
check B1d-a-nested-run-starts-long-lived-processes-with-the-real-HOME \
  [expr {[kv $outB N_P_HOME] eq $cB && [kv $outB N_P_PATH] ne {<absent>} && [llength $harnB] == 0}] \
  "-- a long-lived process started by the nested run would see HOME=[kv $outB N_P_HOME] (required $cB) and harness names [list $harnB] (must be none); a nested T1 that auto-started the dev display with the PARENT's throwaway would recreate the orphan now holding :99"
check B1c-a-non-owner-never-deletes \
  [expr {[kv $outB N_STILL] eq {1} && [kv $outB AFTER] eq {1} && ![file exists $thB]}] \
  "-- the nested run called t1_home_release and the home still existed=[kv $outB N_STILL]; after it exited=[kv $outB AFTER]; after the OWNER exited it is gone=[expr {![file exists $thB]}]"

## B2 -- short of all three conditions is never a reuse.
set tB2 [mktroot trootB2]
set dp  [dead_pid]
set fake [file join $tB2 xschem-test-home.$dp.deadOw]
file mkdir $fake
spit [file join $fake .owner] "$dp\n"
lassign [kid [list HOME=$fake XSCHEM_TEST_REAL_HOME=$cB TMPDIR=$tB2] [probe]] rcb2 outb2
check B2a-a-dead-owners-throwaway-is-not-reused \
  [expr {$rcb2 == 0 && [kv $outb2 HOME] ne $fake && [regexp $PAT [file tail [kv $outb2 HOME]]] && [file isdirectory $fake]}] \
  "-- HOME was $fake (owner $dp, dead): the run armed [kv $outb2 HOME] instead, and left the dead one for the sweep (still there=[file isdirectory $fake]); reusing it would let a killed run's home be shared with no owner to delete it"
set plain [file join $S plainhome]
file mkdir $plain
lassign [kid [list HOME=$plain XSCHEM_TEST_REAL_HOME=$cB TMPDIR=$tB2] [probe]] rcb3 outb3
check B2b-an-ordinary-HOME-with-the-variable-set-is-a-fresh-arm \
  [expr {$rcb3 == 0 && [kv $outb3 HOME] ne $plain && [regexp $PAT [file tail [kv $outb3 HOME]]] && [kv $outb3 XSCHEM_TEST_REAL_HOME] eq $cB}] \
  "-- HOME=$plain with XSCHEM_TEST_REAL_HOME=$cB set: armed [kv $outb3 HOME], real home still $cB; the variable alone never makes a run nested"
lassign [kid [list HOME=$cB TMPDIR=$tB2] [probe [format {
  set rc [catch {exec env -u XSCHEM_TEST_REAL_HOME tclsh %s 2>@1} nout]
  puts "NESTRC=$rc"
  foreach l [split $nout \n] { puts "N_$l" }
} [list $nested]]]] rcb4 outb4
check B2c-a-live-throwaway-with-no-real-home-recorded-is-refused \
  [expr {[kv $outb4 NESTRC] ne {0} && [has_text $outb4 {test home REFUSED}] && [kv $outb4 N_MARK] eq {<absent>}}] \
  "-- a child of a live run with XSCHEM_TEST_REAL_HOME stripped: rc=[kv $outb4 NESTRC], refused=[has_text $outb4 {test home REFUSED}]. Its HOME is a throwaway, so it cannot tell where the real home is -- and guessing would carry throwaway paths as the real ones"

## B3 -- a HOME whose owner is alive only by its bare pid is NOT nested: the
## owner is judged by the same D13.6 rule the sweep uses. A record from another
## boot (its pid recycled and alive now) or from another pid namespace cannot be
## shown to be running, and reusing it would leave a nested run living in a home
## any sweep may call dead and delete under it. A fresh arm is the safe answer.
set tB3 [mktroot trootB3]
set slB3 [exec sleep 60 &] ; lappend ::started $slB3
set b3 {}
foreach {sfx line} [list OtherBoot "$slB3 00000000-0000-4000-8000-000000000000 $MYNS" \
                         OtherNs   "$slB3 $MYBOOT pid:\[1\]" \
                         SameAll   "$slB3 $MYBOOT $MYNS"] {
  set h [file join $tB3 xschem-test-home.$slB3.$sfx]
  file mkdir $h ; spit [file join $h .owner] "$line\n"
  lassign [kid [list HOME=$h XSCHEM_TEST_REAL_HOME=$cB TMPDIR=$tB3] [probe]] rb3 ob3
  lappend b3 $sfx [expr {$rb3 != 0 ? "rc=$rb3" : ([kv $ob3 HOME] eq $h ? {nested} : {fresh})}]
}
check B3-a-HOME-is-nested-only-if-its-owner-is-alive-by-the-D13.6-rule \
  [expr {$b3 eq {OtherBoot fresh OtherNs fresh SameAll nested}}] \
  "-- [list $b3] (required: another boot's record fresh, another namespace's fresh, our own boot and namespace nested -- the non-vacuity half)"

## =========================================================================
## SECTION C -- XSCHEM_TEST_REAL_HOME carries a path and nothing else
## =========================================================================
set cC [mkcanary canaryC]
set tC [mktroot trootC]
set sC0 [snap $cC]
foreach {id val why} [list \
    C1-the-old-flag-spelling-=1-is-refused 1 \
      "the old opt-out placeholder, which read as a flag would keep the real HOME and carry `1/.claude/...` paths" \
    C2-a-relative-path-is-refused [expr {[relpath $cC] ne {} ? [relpath $cC] : {relative/home}}] "a relative path (to a directory that exists)" \
    C3-a-missing-directory-is-refused /nonexistent/xschem-real "a path that does not exist" \
    C4-a-throwaway-home-is-refused [file join $tC xschem-test-home.1.AbCdEf] "a throwaway home"] {
  if {[string match C4* $id]} { file mkdir $val }
  lassign [kid [list HOME=$cC TMPDIR=$tC XSCHEM_TEST_REAL_HOME=$val] [probe]] rcc outc
  if {[string match C4* $id]} { file delete -force $val }
  check $id-as-XSCHEM_TEST_REAL_HOME \
    [expr {$rcc == 3 && [has_text $outc {test home REFUSED}] && [kv $outc MARK] eq {<absent>} && [entries $tC] eq {}}] \
    "-- XSCHEM_TEST_REAL_HOME='$val' ($why): rc=$rcc, refused=[has_text $outc {test home REFUSED}], ran on=[expr {[kv $outc MARK] ne {<absent>}}], made=[list [entries $tC]]"
}
check C5-a-refusal-leaves-the-real-home-untouched [expr {[snap $cC] eq $sC0}] \
  "-- snapshot of $cC across four refused runs"

## =========================================================================
## SECTION D -- the opt-outs
## =========================================================================
set cD [mkcanary canaryD]
set tD [mktroot trootD]
lassign [kid [list HOME=$cD TMPDIR=$tD XSCHEM_TEST_HOME=real] [probe]] rcd outd
check D1a-XSCHEM_TEST_HOME=real-leaves-HOME-alone \
  [expr {$rcd == 0 && [kv $outd HOME] eq $cD && [kv $outd KIND] eq {real} && [entries $tD] eq {}}] \
  "-- rc=$rcd HOME=[kv $outd HOME] kind=[kv $outd KIND], nothing made under TMPDIR=[list [entries $tD]]"
check D1b-and-says-so-loudly-every-run \
  [expr {[has_text $outd "!! test home: REAL"] && [has_text $outd $cD]}] \
  "-- the banner names REAL and the home it will write ($cD); an opt-out nobody is reminded of is a default"
set cust [file join $S customhome]
file mkdir $cust
spit [file join $cust keepme] "custom\n"
lassign [kid [list HOME=$cD TMPDIR=$tD XSCHEM_TEST_HOME=$cust] [probe {
  puts "XPERM=[format %o [expr {[file attributes [file join $::env(HOME) .xschem] -permissions] & 0777}]]"
}]] rcd2 outd2
check D2a-XSCHEM_TEST_HOME=dir-is-used-as-HOME \
  [expr {$rcd2 == 0 && [kv $outd2 HOME] eq $cust && [kv $outd2 KIND] eq {custom} && [kv $outd2 XPERM] eq {700}
         && [kv $outd2 XSCHEM_TEST_REAL_HOME] eq $cD && [has_text $outd2 "test home: custom $cust"]}] \
  "-- HOME=[kv $outd2 HOME] kind=[kv $outd2 KIND] .xschem=[kv $outd2 XPERM] real=[kv $outd2 XSCHEM_TEST_REAL_HOME]"
check D2b-and-is-never-deleted \
  [expr {[file isdirectory $cust] && [file exists [file join $cust keepme]] && ![file exists [file join $cust .owner]]}] \
  "-- after the run: exists=[file isdirectory $cust], its own file survives=[file exists [file join $cust keepme]], no .owner was written=[expr {![file exists [file join $cust .owner]]}]"
set dfails {}
foreach {val why} [list [expr {[relpath $cust] ne {} ? [relpath $cust] : {relative/dir}}] "relative" \
                        /nonexistent/xschem-custom "absent" $cD "the real HOME" \
                        [file join $tD xschem-test-home.1.AbCdEf] "a throwaway"] {
  if {[regexp $PAT [file tail $val]]} { file mkdir $val }
  lassign [kid [list HOME=$cD TMPDIR=$tD XSCHEM_TEST_HOME=$val] [probe]] rcx outx
  if {[regexp $PAT [file tail $val]]} { file delete -force $val }
  if {!($rcx == 3 && [has_text $outx {test home REFUSED}] && [kv $outx MARK] eq {<absent>})} {
    lappend dfails "$why (rc=$rcx)"
  }
}
check D3-a-custom-home-that-is-not-an-absolute-existing-private-dir-is-refused \
  [expr {[llength $dfails] == 0}] \
  "-- relative, absent, the real HOME itself and a throwaway (which another run's sweep could delete) must all refuse; not refused: [expr {[llength $dfails] ? [join $dfails {; }] : {none}}]"

## D4 -- D13.5: a SYMLINK to the real home is the real home. The round-1 build
## compared `file normalize` spellings, which leave the last component
## unresolved, so XSCHEM_TEST_HOME=<a link to the real HOME> was accepted as
## "custom", printed "your HOME is untouched" and wrote into it -- the round-1
## safety refuter's recipe, which this row replays: the probe writes
## .xschem/probe_wrote if it ever runs.
set lnR  [file join $S link_to_real]  ; file link -symbolic $lnR $cD
set lnR2 [file join $S link_to_link]  ; file link -symbolic $lnR2 $lnR
set lnH  [file join $S link_as_home]  ; file link -symbolic $lnH $cD
set sD4 [snap $cD]
set d4 {}
foreach {what envl} [list "a symlink to the real HOME" [list HOME=$cD XSCHEM_TEST_HOME=$lnR] \
                          "a symlink to that symlink" [list HOME=$cD XSCHEM_TEST_HOME=$lnR2] \
                          "the real HOME's target, with HOME itself a symlink" [list HOME=$lnH XSCHEM_TEST_HOME=$cD]] {
  lassign [kid [concat $envl [list TMPDIR=$tD]] [probe {
    close [open [file join $::env(HOME) .xschem probe_wrote] w]
  }]] rc4 out4
  if {!($rc4 == 3 && [has_text $out4 {test home REFUSED}] && [kv $out4 MARK] eq {<absent>})} {
    lappend d4 "$what (rc=$rc4, ran=[expr {[kv $out4 MARK] ne {<absent>}}], said=`[string trim [lindex [split [string trim $out4] \n] 0]]`)"
  }
}
check D4-XSCHEM_TEST_HOME-that-resolves-to-the-real-HOME-is-refused-through-any-symlink \
  [expr {[llength $d4] == 0 && [snap $cD] eq $sD4 && ![file exists [file join $cD .xschem probe_wrote]]}] \
  "-- not refused: [expr {[llength $d4] ? [join $d4 {; }] : {none}}]; the real home unchanged=[expr {[snap $cD] eq $sD4}], probe_wrote there=[file exists [file join $cD .xschem probe_wrote]]"
## D5 -- the non-vacuity half: a symlink to a directory of your OWN is still a
## custom home, and the writes land in that directory.
set cust5 [file join $S customhome5] ; file mkdir $cust5
set sD5 [snap $cD]
set lnC [file join $S link_to_custom] ; file link -symbolic $lnC $cust5
lassign [kid [list HOME=$cD TMPDIR=$tD XSCHEM_TEST_HOME=$lnC] [probe {
  close [open [file join $::env(HOME) .xschem probe_wrote] w]
}]] rc5 out5
check D5-a-symlink-to-a-directory-of-your-own-is-a-custom-home \
  [expr {$rc5 == 0 && [kv $out5 KIND] eq {custom} && [file exists [file join $cust5 .xschem probe_wrote]]
         && [snap $cD] eq $sD5}] \
  "-- rc=$rc5 kind=[kv $out5 KIND] HOME=[kv $out5 HOME]; the write landed in $cust5=[file exists [file join $cust5 .xschem probe_wrote]] and not in the real home=[expr {[snap $cD] eq $sD5}]"

## =========================================================================
## SECTION E -- ownership
## =========================================================================
set cE [mkcanary canaryE]
set tE [mktroot trootE]
lassign [kid [list HOME=$cE TMPDIR=$tE] [probe {
  set f [open [file join $::env(HOME) .owner] w] ; puts $f 1 ; close $f
}]] rce oute
set thE [kv $oute HOME]
check E1-a-home-whose-owner-record-changed-is-not-deleted \
  [expr {$rce == 0 && [file isdirectory $thE] && [has_text $oute {NOT deleting}]}] \
  "-- the run rewrote its own .owner to name pid 1: its exit left $thE in place=[file isdirectory $thE] and said why=[has_text $oute {NOT deleting}]; a delete that skips the re-check is one handoff bug away from removing a live run's home"
catch {file delete -force $thE}
lassign [kid [list HOME=$cE TMPDIR=$tE XSCHEM_TEST_KEEP_HOME=1] [probe]] rck outk
set thK [kv $outk HOME]
check E2a-XSCHEM_TEST_KEEP_HOME=1-keeps-it-and-says-where \
  [expr {$rck == 0 && [file isdirectory $thK] && [file exists [file join $thK .keep]] && [has_text $outk "kept $thK"]}] \
  "-- kept=[file isdirectory $thK] marked=[file exists [file join $thK .keep]] said=[has_text $outk "kept $thK"]"
backdate $thK 3600
lassign [kid [list HOME=$cE TMPDIR=$tE] [probe]] rck2 outk2
check E2b-and-the-next-runs-sweep-leaves-a-kept-home-alone \
  [expr {$rck2 == 0 && [file isdirectory $thK]}] \
  "-- an hour-old kept home of a dead owner survived the next arm's sweep=[file isdirectory $thK]; a kept home deleted five minutes later would not have been kept"
catch {file delete -force $thK}
## E2c -- D13.9: `.keep` is written at ARM time. A run that is killed never
## reaches its exit, and a crash is exactly when a kept home matters: the
## round-1 safety refuter measured a killed KEEP run swept 300 s later.
lassign [kid [list HOME=$cE TMPDIR=$tE XSCHEM_TEST_KEEP_HOME=1] [probe {
  puts "KEEPNOW=[file exists [file join $::env(HOME) .keep]]"
}]] rck3 outk3
catch {file delete -force [kv $outk3 HOME]}
lassign [kid [list HOME=$cE TMPDIR=$tE XSCHEM_TEST_KEEP_HOME=1] [probe {
  flush stdout
  exec kill -KILL [pid]
}]] rck4 outk4
set thK4 [kv $outk4 HOME]
set k4mark [file exists [file join $thK4 .keep]]
backdate $thK4 3600
lassign [kid [list HOME=$cE TMPDIR=$tE] [probe]] rck5 outk5
check E2c-a-KEEP-run-is-marked-at-arm-time-so-a-killed-one-is-kept-too \
  [expr {[kv $outk3 KEEPNOW] eq {1} && $rck4 != 0 && $thK4 ne {<absent>} && $k4mark && [file isdirectory $thK4]}] \
  "-- .keep while the run was still running=[kv $outk3 KEEPNOW]; a KEEP run killed -9 (rc=$rck4) left $thK4 marked=$k4mark, and an hour later it survived the next arm's sweep=[file isdirectory $thK4]"
catch {file delete -force $thK4}

## =========================================================================
## SECTION F -- the sweep
## =========================================================================
set cF [mkcanary canaryF]
set tF [mktroot trootF]
## A stand-in "Xvfb": tclsh under that name, so the kill leg needs no display.
## (Not `sleep`: on this box it is a multi-call binary that dispatches on its
## own name and refuses to run as `Xvfb` -- measured.)
set fbin [file join $S fbin]
file mkdir $fbin
set fx {}
set tclbin [auto_execok tclsh]
set d1 [dead_pid] ; set d2 [dead_pid]
set f_dead  [file join $tF xschem-test-home.$d1.deadOl]
if {[llength $tclbin]} {
  file link -symbolic [file join $fbin Xvfb] [file normalize [lindex $tclbin 0]]
  file link -symbolic [file join $fbin openbox] [file normalize [lindex $tclbin 0]]
  spit [file join $fbin wait.tcl] "after 300000\n"
  ## ⚠ WITH HOME = the dead home that records it (D13.7): a recorded pid is
  ## killed only when its HOME names that exact directory, which is how
  ## run_regression.tcl starts its private display.
  set fx [exec env HOME=$f_dead [file join $fbin Xvfb] [file join $fbin wait.tcl] &]
}
if {$fx ne {}} { lappend ::started $fx }
set f_young [file join $tF xschem-test-home.$d2.youngD]
set f_live  [file join $tF xschem-test-home.[pid].liveOl]
set f_npat  [file join $tF xschem-test-home.notapid.x]
set f_file  [file join $tF xschem-test-home.$d1.afiLe]
set f_link  [file join $tF xschem-test-home.$d1.aLink]
set f_tgt   [file join $S linktarget]
foreach d [list $f_dead $f_young $f_live $f_npat $f_tgt] { file mkdir $d }
spit [file join $f_dead .owner] "$d1\n"
spit [file join $f_dead .xvfb.pid] "$fx\n"
spit [file join $f_young .owner] "$d2\n"
spit [file join $f_live .owner] "[pid]\n"
spit [file join $f_tgt precious] "must survive\n"
spit $f_file "a file\n"
file link -symbolic $f_link $f_tgt
foreach d [list $f_dead $f_live $f_npat $f_file $f_tgt] { backdate $d 400 }
lassign [kid [list HOME=$cF TMPDIR=$tF] [probe]] rcf outf
check F1a-a-dead-owners-old-home-is-swept [expr {$rcf == 0 && ![file exists $f_dead]}] \
  "-- $f_dead (owner $d1 dead, 400 s old) gone=[expr {![file exists $f_dead]}]; a run killed by T1's 900 s timeout never reaches its own delete, and without this every kill leaks a home"
for {set i 0} {$i < 30 && [running $fx]} {incr i} { after 100 }
check F1b-and-the-private-Xvfb-it-recorded-is-killed [expr {$fx ne {} && ![running $fx]}] \
  "-- the process named Xvfb recorded in its .xvfb.pid (pid $fx) running=[running $fx]; a killed T1 otherwise leaks its display -- F36 again"
check F2-a-dead-owners-young-home-is-kept [file isdirectory $f_young] \
  "-- dead owner but under 300 s old: kept=[file isdirectory $f_young] (the pid-reuse belt-and-braces of sweep_dead_run_dirs)"
check F3-a-live-owners-home-is-kept [file isdirectory $f_live] \
  "-- owner [pid] alive, 400 s old: kept=[file isdirectory $f_live]; the failure direction must always be a leftover, never a live run's home"
check F4-only-real-pattern-directories-are-swept \
  [expr {[file isdirectory $f_npat] && [file isfile $f_file] && [file type $f_link] eq {link} && [file exists [file join $f_tgt precious]]}] \
  "-- non-numeric pid kept=[file isdirectory $f_npat], a FILE kept=[file isfile $f_file], a SYMLINK kept=[expr {[file type $f_link] eq {link}}] and its target's contents untouched=[file exists [file join $f_tgt precious]]"
## F5 -- another uid's entry. Nothing unprivileged can make a directory another
## uid owns, so the sweep is asked directly with a uid that is not ours.
set tF5 [mktroot trootF5]
set tF5o [mktroot trootF5other]
set d3 [dead_pid]
set f_other [file join $tF5 xschem-test-home.$d3.OtherU]
file mkdir $f_other
spit [file join $f_other .owner] "$d3\n"
backdate $f_other 400
lassign [kid [list HOME=$cF TMPDIR=$tF5o] [probe [format {
  puts "OTHER=[llength [t1_home_sweep %s [expr {%s + 1}] 300]]"
  puts "MINE=[llength [t1_home_sweep %s %s 300]]"
} [list $tF5] $MYUID [list $tF5] $MYUID]]] rcf5 outf5
check F5-an-entry-owned-by-another-uid-is-never-swept \
  [expr {$rcf5 == 0 && [kv $outf5 OTHER] eq {0} && [kv $outf5 MINE] eq {1} && ![file exists $f_other]}] \
  "-- swept as uid [expr {$MYUID + 1}]: [kv $outf5 OTHER] (must be 0); as uid $MYUID: [kv $outf5 MINE] (must be 1, the non-vacuity half). /tmp is shared by every user on a box"
foreach d [list $f_young $f_live $f_npat $f_file $f_tgt] { catch {file delete -force $d} }
catch {file delete $f_link}

## F1c -- D13.7: the sweep kills only what it can IDENTIFY. A pid file outlives
## its process and pids recycle, and the round-1 build killed a recorded pid on
## its NAME alone: the round-1 safety refuter had both sweeps kill a live,
## foreign Xvfb and openbox named in a forged dead home. Now the name must match
## AND the HOME in /proc/<pid>/environ must be exactly that dead home.
set tF1c [mktroot trootF1c]
set dA [dead_pid]
set fA [file join $tF1c xschem-test-home.$dA.foreignA]
set fB [file join $tF1c xschem-test-home.$dA.insideB]
set fC [file join $tF1c xschem-test-home.$dA.exactC]
foreach d [list $fA $fB $fC] { file mkdir [file join $d .xvfb] ; spit [file join $d .owner] "$dA\n" }
set xA {} ; set wA {} ; set xB {} ; set wC {}
if {[llength $tclbin]} {
  set xA [exec env HOME=$cF [file join $fbin Xvfb] [file join $fbin wait.tcl] &]
  set wA [exec env HOME=$cF [file join $fbin openbox] [file join $fbin wait.tcl] &]
  set xB [exec env HOME=[file join $fB sub] [file join $fbin Xvfb] [file join $fbin wait.tcl] &]
  set wC [exec env HOME=$fC [file join $fbin openbox] [file join $fbin wait.tcl] &]
  foreach p [list $xA $wA $xB $wC] { lappend ::started $p }
}
spit [file join $fA .xvfb.pid] "$xA\n"
spit [file join $fA .xvfb wm.pid] "$wA\n" ; spit [file join $fA .xvfb wm] "openbox\n"
spit [file join $fB .xvfb.pid] "$xB\n"
spit [file join $fC .xvfb wm.pid] "$wC\n" ; spit [file join $fC .xvfb wm] "openbox\n"
after 200
foreach d [list $fA $fB $fC] { backdate $d 400 }
lassign [kid [list HOME=$cF TMPDIR=$tF1c] [probe]] rcf1c outf1c
for {set i 0} {$i < 30 && [running $wC]} {incr i} { after 100 }
set f1c [list foreignXvfb [running $xA] foreignWM [running $wA] insideXvfb [running $xB] exactWM [running $wC]]
check F1c-a-recorded-process-is-killed-only-if-its-HOME-is-exactly-that-dead-home \
  [expr {$rcf1c == 0 && $xA ne {} && $f1c eq {foreignXvfb 1 foreignWM 1 insideXvfb 1 exactWM 0}
         && ![file exists $fA] && ![file exists $fB] && ![file exists $fC]}] \
  "-- still running after the sweep: [list $f1c] (required foreign Xvfb, foreign WM and an Xvfb whose HOME is merely INSIDE the dead home all alive, the WM whose HOME is exactly it stopped); the three dead homes were still swept=[expr {![file exists $fA] && ![file exists $fB] && ![file exists $fC]}]"
foreach p [list $xA $wA $xB $wC] { stop_pid $p }

## F6 -- D13.6: the dead rule for `<pid> <boot_id> <pidns>`, exactly as written.
## DEAD when the boot_id differs, or when boot_id AND pidns both match ours and
## the pid is not alive; a matching boot_id with another pidns is FOREIGN and is
## swept only past 7 days; a `-` field falls back to the old rule (pid dead). A
## dead owner's home is still swept only past 300 s. One entry per clause; the
## same matrix is handed to the shell sweep by row L7.
set OTHERBOOT 00000000-0000-4000-8000-000000000000
set FOREIGNNS {pid:[1]}
set DAYS8 [expr {8 * 86400 + 60}]
set sleeperF [exec sleep 120 &] ; lappend ::started $sleeperF
proc plant_matrix {troot live dead} {
  set rows [list \
    XbLive     "$live $::OTHERBOOT $::MYNS"     400 swept "another boot, its pid alive here" \
    XbYoung    "$dead $::OTHERBOOT $::MYNS"     100 kept  "another boot, but under 300 s old" \
    FnDead     "$dead $::MYBOOT $::FOREIGNNS"   400 kept  "same boot, another pidns, its pid dead HERE" \
    FnLive     "$live $::MYBOOT $::FOREIGNNS"   400 kept  "same boot, another pidns, its pid alive here" \
    FnOld      "$dead $::MYBOOT $::FOREIGNNS"   $::DAYS8 swept "another pidns, older than 7 days" \
    FnOldLive  "$live $::MYBOOT $::FOREIGNNS"   $::DAYS8 swept "another pidns, older than 7 days, whatever its pid" \
    SameDead   "$dead $::MYBOOT $::MYNS"        400 swept "our boot and pidns, pid dead" \
    SameLive   "$live $::MYBOOT $::MYNS"        400 kept  "our boot and pidns, pid alive" \
    DashDead   "$dead - -"                      400 swept "both fields -, pid dead (old rule)" \
    DashLive   "$live - -"                      400 kept  "both fields -, pid alive (old rule)" \
    NsDashLive "$live $::MYBOOT -"              400 kept  "pidns -, pid alive (old rule)" \
    BootDashFn "$dead - $::FOREIGNNS"           400 kept  "boot_id -, a pidns known to differ: foreign, not judged by our /proc" \
    Bare       "$dead"                          400 swept "a round-1 bare pid, dead (old rule)"]
  foreach {sfx line age exp why} $rows {
    set d [file join $troot xschem-test-home.[lindex $line 0].$sfx]
    file mkdir $d ; spit [file join $d .owner] "$line\n" ; backdate $d $age
  }
  return $rows
}
## {suffix got expected ...} for the entries whose outcome is not the expected one.
proc matrix_wrong {troot rows} {
  set bad {}
  foreach {sfx line age exp why} $rows {
    set d [file join $troot xschem-test-home.[lindex $line 0].$sfx]
    set got [expr {[file exists $d] ? {kept} : {swept}}]
    if {$got ne $exp} { lappend bad "$sfx ($why): $got, required $exp" }
  }
  return $bad
}
set tF6 [mktroot trootF6]
set dF6 [dead_pid]
set rowsF6 [plant_matrix $tF6 $sleeperF $dF6]
lassign [kid [list HOME=$cF TMPDIR=$tF6] [probe]] rcf6 outf6
set badF6 [matrix_wrong $tF6 $rowsF6]
check F6-the-owner-dead-rule-is-boot-id-then-pid-namespace-then-pid \
  [expr {$MYBOOT ne {} && $MYNS ne {} && $rcf6 == 0 && [llength $badF6] == 0}] \
  "-- [expr {[llength $rowsF6] / 5}] planted owners (boot_id $MYBOOT, pidns $MYNS); wrong: [expr {[llength $badF6] ? [join $badF6 {; }] : {none}}]"

## F7 -- the same rule under a REAL second pid namespace, the round-1 safety
## refuter's measurement replayed: a LIVE arm inside `bwrap --unshare-pid`
## sharing TMPDIR with the host. Its .owner pid is its number in ITS namespace,
## which is dead in the host's -- so a bare-pid sweep deletes a live run's home.
## Its number is pushed into a range that is empty on the host before it arms,
## so the row cannot pass by the luck of a live host pid (the non-vacuity half).
if {[auto_execok bwrap] eq {}} {
  skip F7-a-live-run-in-another-pid-namespace-is-never-swept-by-a-host-run "no bwrap on PATH"
} else {
  set tF7 [mktroot trootF7]
  set cF7 [mkcanary canaryF7]
  set target {}
  for {set t 400} {$t < 60000} {incr t 97} {
    set clear 1
    for {set i $t} {$i < $t + 40} {incr i} { if {[file exists /proc/$i]} { set clear 0 ; break } }
    if {$clear} { set target $t ; break }
  }
  set go7 [file join $S f7.go]
  set f7 [spit [file join $S f7.tcl] [probe [format {
    puts "OWNERLINE=[string trim [read [set f [open [file join $::env(HOME) .owner]]]]][close $f]"
    puts "NS=[file readlink /proc/self/ns/pid]"
    flush stdout
    for {set i 0} {$i < 900 && ![file exists %s]} {incr i} { after 100 }
    puts "DONE=1"
  } [list $go7]]]]
  set o7 [file join $S f7.out]
  ## `& wait`, not a bare last command: bash execs a -c string's last command in
  ## place, which would give tclsh bash's own pid (2) whatever the loop did.
  set loop7 {t=$1; shift; while :; do p=$(sh -c 'echo $$'); [ "$p" -ge "$t" ] && break; done; tclsh "$@" & wait $!}
  set b7 {}
  if {$target ne {}} {
    set b7 [exec timeout 150 bwrap --dev-bind / / --unshare-pid --proc /proc \
              env -i PATH=$PATHV HOME=$cF7 TMPDIR=$tF7 bash -c $loop7 sh $target $f7 >& $o7 &]
    lappend ::started $b7
  }
  for {set i 0} {$i < 300 && ![has_text [slurp $o7] OWNERLINE=]} {incr i} { after 100 }
  set out7 [slurp $o7]
  set th7 [kv $out7 HOME] ; set np7 [kv $out7 PID]
  set hostdead [expr {[string is integer -strict $np7] && ![file exists /proc/$np7]}]
  set nsdiff [expr {[kv $out7 NS] ne {<absent>} && [kv $out7 NS] ne $MYNS}]
  backdate $th7 400
  lassign [kid [list HOME=$cF TMPDIR=$tF7] [probe]] rc7 out7h
  set survived [file isdirectory $th7]
  catch {close [open $go7 w]}
  for {set i 0} {$i < 300 && $b7 ne {} && [running $b7]} {incr i} { after 100 }
  set out7 [slurp $o7]
  set gone7 [expr {$th7 ne {<absent>} && ![file exists $th7]}]
  check F7-a-live-run-in-another-pid-namespace-is-never-swept-by-a-host-run \
    [expr {$th7 ne {<absent>} && $hostdead && $nsdiff && $rc7 == 0 && $survived && $gone7 && [has_text $out7 DONE=1]}] \
    "-- inside bwrap, sharing TMPDIR=$tF7: .owner `[kv $out7 OWNERLINE]`, its pid $np7 dead on the host=$hostdead, its pidns differs=$nsdiff (without both the row would prove nothing). Backdated 400 s, a host arm's sweep left it=$survived; the live owner then finished and deleted it itself=$gone7"
}

## =========================================================================
## SECTION J -- an unusable TMPDIR refuses; there is no fallback
## =========================================================================
set cJ [mkcanary canaryJ]
set sJ0 [snap $cJ]
set tJ [mktroot trootJ]
file attributes $tJ -permissions 0555
foreach {id tmp} [list J1 $tJ J2 /nonexistent/xschem-tmp] {
  lassign [kid [list HOME=$cJ TMPDIR=$tmp] [probe]] rcj outj
  check $id-an-unusable-TMPDIR-refuses-and-never-falls-back-to-the-real-HOME \
    [expr {$rcj == 3 && [has_text $outj {test home REFUSED}] && [kv $outj MARK] eq {<absent>}}] \
    "-- TMPDIR=$tmp: rc=$rcj refused=[has_text $outj {test home REFUSED}] ran-anyway=[expr {[kv $outj MARK] ne {<absent>}}]; running on with the real HOME is the defect this whole contract exists to remove"
}
file attributes $tJ -permissions 0755
check J3-and-the-real-home-is-untouched [expr {[snap $cJ] eq $sJ0}] "-- snapshot of $cJ"

## =========================================================================
## SECTION K -- where arming must do nothing
## =========================================================================
set cK [mkcanary canaryK]
set tK [mktroot trootK]
lassign [kid [list HOME=$cK TMPDIR=$tK] "proc xschem {args} {}\n[probe]"] rck1 outk1
check K1-inside-an-xschem-interpreter-arming-is-a-no-op \
  [expr {$rck1 == 0 && [kv $outk1 HOME] eq $cK && [kv $outk1 KIND] eq {inxschem} && [entries $tK] eq {}
         && [count_lines $outk1 {test home:}] == 0}] \
  "-- with an `xschem` command defined: HOME=[kv $outk1 HOME] kind=[kv $outk1 KIND]; switching HOME after xschem has started would split C's startup-cached clipboard path from Tcl's"
lassign [kid [list HOME=$cK TMPDIR=$tK] "[probe]\nsource [list $UTIL]\nputs \"HOME2=\$::env(HOME)\"\nputs \"NENT=\[llength \[glob -nocomplain -directory [list $tK] -- *\]\]\"\n"] rck2 outk2
check K2-sourcing-twice-arms-once \
  [expr {$rck2 == 0 && [kv $outk2 HOME2] eq [kv $outk2 HOME] && [kv $outk2 NENT] eq {1}
         && [count_lines $outk2 {test home: throwaway}] == 1 && [entries $tK] eq {}}] \
  "-- HOME after the second source=[kv $outk2 HOME2] (first: [kv $outk2 HOME]), entries while running=[kv $outk2 NENT], banners=[count_lines $outk2 {test home: throwaway}], left after exit=[list [entries $tK]] (a second arm that forgot it owned the first home would leak it)"

## =========================================================================
## SECTION G -- issue 1397's trap: every $HOME/.claude default is carried
## =========================================================================
## An uncarried harness path does not FAIL under a throwaway HOME -- it quietly
## resolves inside the throwaway and SKIPS, or spawns a second gate panel. So
## every `${VAR:-$HOME/.claude/...}` in tests/ must name a variable the arm
## carries, and every bare `$HOME/.claude` must be allowlisted with a reason.
## The carried set is MEASURED from a child's environment, not typed here, so
## deleting a carry from test_utility.tcl reddens this row by name.
set cG [mkcanary canaryG dir:.claude/gui_test_gate dir:.claude/xschem_dev_display file:.Xauthority]
set tG [mktroot trootG]
lassign [kid [list HOME=$cG TMPDIR=$tG] "source [list $UTIL]\nforeach k \[lsort \[array names ::env\]\] { puts \"ENV \$k=\$::env(\$k)\" }\n"] rcg outg
set carried {}
foreach l [split $outg \n] {
  if {[regexp {^ENV ([A-Za-z_0-9]+)=(.*)$} $l -> k v] && $k ne {HOME} && ($v eq $cG || [string first "$cG/" $v] == 0)} {
    lappend carried $k
  }
}
## file tail, a substring of the line, and why it may read the home itself.
set ALLOW {
  owed.sh XSCHEM_OWED_DIR
    "owed.sh is the user's own ledger tool: it CALLS the drivers and no driver ever runs it, so it always sees the real HOME"
  spawn_reaper.sh {/.claude/xschem_dev_display/display}
    "a read-only guard that refuses to reap the dev display and reads EVERY state file it can find on purpose -- the carried XSCHEM_DEVDISPLAY_DIR, the real home (DECISIONS D10) and HOME itself -- so that no redirection can switch it off"
  runtime_gaps.sh {$HOME/.claude/projects}
    "a developer's transcript reader, never run by a test driver; it only reads"
  gui_gate_widget.tcl {file join $env(HOME) .claude gui_test_gate}
    "the panel is started by gui_gate.sh with the gate dir on argv (from the carried GUI_GATE_DIR); this fallback is reached only when it is started by hand"
  run_regression.tcl {file join $env(HOME) .claude xschem_dev_display}
    "T1's own copy of devdisplay.sh's default, reached only when XSCHEM_DEVDISPLAY_DIR is unset -- i.e. under XSCHEM_TEST_HOME=real, where HOME IS the real home"
  test_wslg_health.sh {creates nothing under \$HOME/.claude}
    "the label of row DH34, not a path: that row asserts the probe creates nothing there"
}
## HOME itself, however it is spelled: $HOME, ${HOME}, ${HOME:-...}, $env(HOME),
## $::env(HOME), ~ -- measured: stage U's guard spells its deliberate read of
## HOME `${HOME:-}`, which a first draft of this row misread as a variable's
## default.
set BARE {(\$HOME|\$\{HOME(:-[^\}]*)?\}|\$(::)?env\(HOME\)|~)\s*/?\s*\.claude}
set sites 0 ; set offenders {} ; set allowed_used {}
set todo [list $tdir]
while {[llength $todo]} {
  set d [lindex $todo 0] ; set todo [lrange $todo 1 end]
  foreach f [glob -nocomplain -directory $d -- *] {
    set t [file tail $f]
    if {[file isdirectory $f]} {
      if {![string match results* $t] && ![string match .* $t] && $t ne {gold}} { lappend todo $f }
      continue
    }
    ## The two suites that LOCK this contract (this one and the shell half's
    ## test_home_isolation_sh.tcl) spell these paths in fixtures and labels by
    ## design; everything else in tests/ is read.
    if {![regexp {\.(tcl|sh|py|awk)$} $t] || $t in {test_home_isolation.tcl test_home_isolation_sh.tcl}} { continue }
    set n 0
    foreach l [split [slurp $f] \n] {
      incr n
      if {[regexp {^\s*#} $l] || ![has_text $l .claude]} { continue }
      set rest $l
      foreach {whole var} [regexp -all -inline {\$\{([A-Za-z_][A-Za-z0-9_]*):-[^\}]*\}} $l] {
        if {$var eq {HOME} || ![regexp {HOME} $whole]} { continue }
        set rest [string map [list $whole {}] $rest]
        incr sites
        if {[lsearch -exact $carried $var] >= 0} { continue }
        set hit 0
        foreach {af an areason} $ALLOW { if {$af eq $t && $an eq $var} { set hit 1 ; lappend allowed_used "$t:$var" } }
        if {!$hit} { lappend offenders "$t:$n \${$var:-...} is not carried" }
      }
      if {[regexp $BARE $rest]} {
        incr sites
        set hit 0
        foreach {af an areason} $ALLOW { if {$af eq $t && [has_text $l $an]} { set hit 1 ; lappend allowed_used "$t:$n" } }
        if {!$hit} { lappend offenders "$t:$n reads the home's .claude directly" }
      }
    }
  }
}
set unused {}
foreach {af an areason} $ALLOW {
  set u 1
  foreach a $allowed_used { if {[string first "$af:" $a] == 0} { set u 0 } }
  if {$u} { lappend unused $af }
}
check G1-every-HOME/.claude-default-in-tests-is-carried-or-allowlisted \
  [expr {$rcg == 0 && $sites > 0 && [llength $offenders] == 0 && [lsearch -exact $carried XSCHEM_DEVDISPLAY_DIR] >= 0}] \
  "-- carried (measured): [list $carried]; $sites site(s) found, allowlisted: [list [lsort -unique $allowed_used]] (allowlist entries matching nothing here: [expr {[llength $unused] ? [join $unused {, }] : {none}}]); offenders: [expr {[llength $offenders] ? [join $offenders {; }] : {none}}]. An uncarried one does not fail under a throwaway HOME -- it SKIPS, which is issue 1397's trap"


## =========================================================================
## SECTION G2 -- D17.1: EVERY SCRIPT UNDER tests/ THAT STARTS XSCHEM IS ARMED
## =========================================================================
## Three rounds each found more documented scripts that ran xschem under the
## tester's real HOME: round 1 the standalone .sh suites, `owed.sh drain` and
## run_nogui.sh; round 2 lookshot.sh, netlist_diff.sh and run_wireedit.sh.
## Whack-a-mole is the wrong shape, so this row enumerates them instead. A
## script STARTS xschem when a non-comment line names the binary -- `src/xschem`,
## `src xschem` (a Tcl file join), `$XSCHEM`/`${XSCHEM`, `env(XSCHEM)` or
## `xschem_cmd` -- and it must then be ONE of:
##   armed      an arm precedes that line: `test_home_arm` (test_home.sh
##              sourced), the `test_home.sh --run` or `xvfb_arm.sh --arm`
##              re-exec guard, or, in Tcl, `source ... test_utility.tcl`
##              (t1_arm_home runs at source time) or t1_arm_home itself;
##   inside     a .tcl suite that runs INSIDE xschem (it sources scratch.tcl or
##              calls the `xschem` command, and has no tclsh shebang): any
##              child it starts inherits the HOME of whatever launched IT -- an
##              armed driver, or the bare `./src/xschem --script` that D9 keeps
##              as the known exception, with scratch.tcl's note;
##   allowed    each such line on ALLOW below, with its one-line reason.
## A line that only names an ARMED driver (gated_xschem.sh, run_suites.sh,
## full_audit.sh) or an arming re-exec delegates to something this same row
## checks, and needs nothing. Every launcher found, and its class, is printed.
set G2ALLOW {
  test_owed.sh {-x "$REPO/src/xschem"}
    "a precondition test, not a start: O13's only xschem run is `owed.sh drain`, which runs the suite through run_suites.sh (armed)"
  test_pdk_launcher.tcl {set xs [file join $repo src xschem]}
    "builds the PDK launcher's command line as a Tcl list and compares it; it never runs it"
  fuzz_sweep.tcl {puts $fh "#   src/xschem}
    "writes a usage COMMENT into a generated replay file; the sweep itself runs inside xschem (--script), D9's case"
}
proc g2_scan {tdir allow} {
  set DIRECT {src/xschem([^.A-Za-z0-9_]|$)|src xschem([^.A-Za-z0-9_]|$)|\$\{?XSCHEM([^A-Za-z0-9_]|$)|env\(XSCHEM\)|(^|[^A-Za-z0-9_])xschem_cmd([^A-Za-z0-9_]|$)}
  ## a BARE `xschem` in command position (0924: never a bare name), after an
  ## optional exec/env/timeout/nohup/setsid prefix with its words
  set BARE {(^\s*|[;&|(`]\s*)((exec|env|timeout|nohup|setsid)\s+([^ ]+=[^ ]*\s+|-[^ ]+\s+|[0-9]+[a-z]?\s+)*)*xschem\s+-}
  set ARM {(^|[;&|\{])\s*test_home_arm(\s|;|$)|xvfb_arm\.sh"?\s+--arm\s|test_home\.sh"?\s+--run\s|^\s*source\s.*test_utility\.tcl|^\s*t1_arm_home\s*$}
  set out [dict create armed {} inside {} allowed {} offenders {} used {}]
  set todo [list $tdir]
  while {[llength $todo]} {
    set d [lindex $todo 0] ; set todo [lrange $todo 1 end]
    foreach f [lsort [glob -nocomplain -directory $d -- *]] {
      set t [file tail $f]
      if {[file isdirectory $f]} {
        if {![string match results* $t] && ![string match .* $t] && $t ne {gold}} { lappend todo $f }
        continue
      }
      set ext [file extension $t]
      set body [slurp $f]
      if {$ext ni {.sh .bash .py .tcl} && !($ext eq {} && [string range $body 0 1] eq "#!")} { continue }
      set rel [string range $f [expr {[string length $tdir] + 1}] end]
      set n 0 ; set armed 0 ; set inside 0 ; set bad {} ; set first 0 ; set allowed {}
      foreach l [split $body \n] {
        incr n
        if {[regexp {^\s*#} $l]} { continue }
        if {$ext eq {.tcl} && ([regexp {(^|[\[;\{]\s*)xschem\s+[a-z_]+} $l] || [regexp {scratch\.tcl} $l])} { set inside 1 }
        if {!$armed && [regexp $ARM $l]} { set armed $n }
        set hit [regexp $DIRECT $l]
        if {!$hit && $ext ne {.tcl} && [regexp $BARE $l]} { set hit 1 }
        if {!$hit} { continue }
        if {!$first} { set first $n }
        if {$armed && $armed <= $n} { continue }
        set ok 0
        foreach {af an areason} $allow {
          if {$af eq $t && [string first $an $l] >= 0} { set ok 1 ; lappend allowed "$rel ($areason)" ; dict lappend out used $af }
        }
        if {!$ok} { lappend bad "$rel:$n `[string trim [string range $l 0 80]]`" }
      }
      if {!$first} { continue }
      if {[llength $bad] && $inside && ![regexp {^#![^\n]*tclsh} $body]} { dict lappend out inside $rel ; continue }
      if {[llength $bad]} {
        foreach b $bad { dict lappend out offenders $b }
      } elseif {[llength $allowed]} {
        foreach a [lsort -unique $allowed] { dict lappend out allowed $a }
      } else {
        dict lappend out armed $rel
      }
    }
  }
  return $out
}
set g2 [g2_scan $tdir $G2ALLOW]
set g2unused {}
foreach {af an areason} $G2ALLOW { if {[lsearch -exact [dict get $g2 used] $af] < 0} { lappend g2unused $af } }
set g2need {headless/lookshot.sh netlist_diff/netlist_diff.sh headless/wireedit/run_wireedit.sh
            headless/run_suites.sh headless/full_audit.sh headless/gated_xschem.sh run_regression.tcl netlisting.tcl}
set g2miss {}
foreach w $g2need { if {[lsearch -exact [dict get $g2 armed] $w] < 0} { lappend g2miss $w } }
check G2-every-script-under-tests-that-starts-xschem-is-armed-or-allowlisted-with-a-reason \
  [expr {[llength [dict get $g2 offenders]] == 0 && [llength $g2miss] == 0 && [llength [dict get $g2 armed]] >= 20
         && [llength [dict get $g2 inside]] > 0}] \
  "-- UNARMED: [expr {[llength [dict get $g2 offenders]] ? [join [dict get $g2 offenders] {; }] : {none}}]. armed ([llength [dict get $g2 armed]]): [join [dict get $g2 armed] {, }]. allowlisted: [expr {[llength [dict get $g2 allowed]] ? [join [dict get $g2 allowed] {; }] : {none}}]. inside xschem (their children inherit their launcher's HOME; bare, D9): [llength [dict get $g2 inside]] suites. Known launchers not seen armed: [expr {[llength $g2miss] ? [join $g2miss {, }] : {none}}]. Allowlist entries matching nothing: [expr {[llength $g2unused] ? [join $g2unused {, }] : {none}}]"

## =========================================================================
## SECTION H -- T1's display arm (D8) and header (D6), through a driver copy
## =========================================================================
## A copy of the REAL run_regression.tcl with its case lists replaced by one
## display case whose "binary" is a shell stand-in that reports the DISPLAY
## and HOME it was given. Everything else -- the arm's choice, the private
## Xvfb, the publish, the release -- is the shipped code.
proc mkdrv {src dst inj} {
  set out {} ; set done 0
  foreach l [split $src \n] {
    if {!$done && [regexp {^[ \t]*foreach[ \t]+tc[ \t]+\$tcases} $l]} { append out $inj \n ; set done 1 }
    append out $l \n
  }
  spit $dst $out
  return $done
}
proc mkfdir {name {dcases st1} {extra {}}} {
  set fd [file join $::S $name]
  file mkdir [file join $fd headless]
  foreach f {test_utility.tcl banner_rule.tcl cleanup_debug_file.awk} { file copy -force [file join $::tdir $f] $fd }
  file copy -force $::DDSH [file join $fd headless devdisplay.sh]
  set sa [spit [file join $fd standin.sh] "#!/bin/sh\necho \"STANDIN DISPLAY=\${DISPLAY:-unset} HOME=\$HOME GATE=\${GUI_GATE:-unset}\"\n$extra\necho \"OVERALL: ok\"\nexit 0\n"]
  file attributes $sa -permissions 0755
  set ok [mkdrv [slurp $::RRSRC] [file join $fd drv.tcl] \
    "set tcases {} ; set hcases {} ; set dcases [list $dcases] ; set xschem_cmd [list $sa]"]
  return [list $fd $ok]
}
## Run the copy with cwd = its dir; stdout+stderr returned.
proc rundrv {fd envl {tmo 150}} {
  set rc 0
  if {[catch {exec timeout $tmo env -i PATH=$::PATHV {*}$envl sh -c {cd "$1" && exec tclsh drv.tcl} sh $fd 2>@1} out opt]} {
    set ec [dict get $opt -errorcode]
    set rc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
  }
  ## kept beside the copy, for whoever has to read a red row
  catch {spit [file join $fd drv.out] "rc=$rc\n$out\n"}
  return [list $rc $out]
}
proc verdict_of {fd} { return [slurp [file join $fd results.log]] }
## A display number in 150-169 with no server, lock or socket on it -- this
## suite's fixture range -- RESERVED for this run, or {} if none is free.
## ⚠ SIZED FOR CONCURRENCY, AND RELEASED AS SOON AS A ROW IS DONE WITH IT
## (D17.9). The range was 150-159, every number was held to the end of the
## suite, and a run takes three: the round-2 regression refuter measured H3
## skipping in 10 of 20 runs four-way concurrent ("no free display number in
## 150-159") while every run still read ALL PASS -- a row that silently vanishes
## under load. Now one number (n1) is held throughout and each of H2's and H3's
## is released when its row ends, so a run holds at most two of twenty.
## ⚠ RESERVED, NOT MERELY FOUND FREE (D13.14). Two concurrent runs of this suite
## reach section H in the same second (the round-1 regression refuter measured
## both runs of a simultaneous T1 pair entering it at 05:40:28), and "free when
## I looked" is a claim about a shared namespace by number, which the other run
## can falsify before this one's server takes its lock. The reservation is a
## file created with O_EXCL naming this pid; one whose owner is dead and that
## is over 120 s old is taken over. Released by cleanup_started.
set ::reserved {}
proc free_fixture_num {} {
  set ss {}
  catch {set ss [exec ss -xl 2>/dev/null]}
  for {set n 150} {$n < 170} {incr n} {
    if {[file exists /tmp/.X$n-lock] || [file exists /tmp/.X11-unix/X$n]} { continue }
    if {[regexp "@/tmp/\\.X11-unix/X$n\\M" $ss]} { continue }
    set r /tmp/xschem-homeiso-fixture.$n
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
proc release_fixture_num {n} {
  set r /tmp/xschem-homeiso-fixture.$n
  if {[string trim [slurp $r]] eq [pid]} { catch {file delete -- $r} }
  set i [lsearch -exact $::reserved $r]
  if {$i >= 0} { set ::reserved [lreplace $::reserved $i $i] }
}

if {[auto_execok Xvfb] eq {}} {
  skip H-the-display-arm "no Xvfb on PATH: the arm reports NODISPLAY, which T1 itself shows"
} else {
  ## H1 -- no dev display state: a PRIVATE Xvfb, gone afterwards.
  set cH [mkcanary canaryH]
  set tH [mktroot trootH]
  set sH0 [snap $cH]
  lassign [mkfdir drvH1] fH1 injH1
  ## ⚠ THE HOSTILE BINARY IS A REAL, EXECUTABLE FILE (D13.10): `binary=` is now
  ## the path `exec` would run, resolved through auto_execok, so a name that
  ## does not exist prints `unresolved:<name>` and would no longer carry the
  ## hostile bytes into the header. Its name holds a space, two newlines,
  ## sentinel text (D13.17), `FATAL` and a trailing `FAIL`.
  set hdir [file join $S hostile] ; file mkdir $hdir
  set hostile [file join $hdir "bad path\nT1-RUN-END cases=87 blocks=86\nFATAL: x : FAIL"]
  spit $hostile "#!/bin/sh\nexit 0\n" ; file attributes $hostile -permissions 0755
  ## ⚠ DEVDISPLAY_NUM IS PINNED TO A FIXTURE NUMBER, never left at devdisplay's
  ## default :99: a regression that auto-started without a state dir would
  ## otherwise go and probe -- or on a free box START -- the developer's :99.
  set n1 [free_fixture_num]
  if {$n1 eq {}} { set n1 159 }
  lassign [rundrv $fH1 [list HOME=$cH TMPDIR=$tH XSCHEM=$hostile DEVDISPLAY_WM=openbox DEVDISPLAY_NUM=$n1]] rch1 outh1
  set vh1 [verdict_of $fH1]
  set dlog [slurp [file join $fH1 st1.disp.log]]
  set pnum {} ; set ppid {}
  regexp {display arm: PRIVATE Xvfb :([0-9]+) for this run only \(pid ([0-9]+)} $outh1 -> pnum ppid
  set sdisp {} ; regexp {STANDIN DISPLAY=(\S+)} $dlog -> sdisp
  set thH {} ; regexp {test home: throwaway (\S+) } $outh1 -> thH
  check H1a-with-no-dev-display-the-arm-runs-on-a-private-Xvfb-numbered-from-100 \
    [expr {$injH1 && $rch1 == 0 && [string is integer -strict $pnum] && $pnum >= 100 && $sdisp eq ":$pnum"
           && [regexp -line {^Total num fail: 0$} $vh1] && ![has_text $vh1 NODISPLAY]}] \
    "-- rc=$rch1, arm said :$pnum (pid $ppid), the case saw DISPLAY=$sdisp; a stranger's T1 used to print 11 uncounted NODISPLAY lines here, or start a PERSISTENT Xvfb into their real home"
  ## ⚠ BY IDENTITY, NOT BY NUMBER (D13.14). This row used to require that
  ## /tmp/.X<n>-lock not EXIST, and the round-1 regression refuter measured it
  ## red in 1 of 14 concurrent pairs: the other run's private Xvfb had taken the
  ## number this one had just freed. The W12b class again -- a shared namespace
  ## matched by number. What this run must not leave is a lock naming ITS pid.
  set lk1 [string trim [slurp /tmp/.X$pnum-lock]]
  check H1b-and-leaves-no-display-no-process-and-no-home-behind \
    [expr {$ppid ne {} && ![running $ppid] && $thH ne {} && [llength [procs_with_env HOME $thH]] == 0
           && ![file exists $thH] && [entries $tH] eq {} && $lk1 ne $ppid && [llength [reapers_in $thH]] == 0}] \
    "-- Xvfb $ppid running=[expr {$ppid ne {} && [running $ppid]}], processes still carrying HOME=$thH: [list [procs_with_env HOME $thH]], its reaper still running=[list [reapers_in $thH]], home left=[file exists $thH], lock naming it left=[expr {$lk1 eq $ppid}] (a lock on :$pnum present=[file exists /tmp/.X$pnum-lock], holding `$lk1` -- another run's, if present; only one naming $ppid is ours)"
  check H1c-and-the-real-home-never-saw-the-display \
    [expr {[snap $cH] eq $sH0}] \
    "-- snapshot of $cH: no .claude, no .cache/openbox, nothing (F36)"
  ## Whatever a regression may have started there, stop it.
  if {[file isdirectory [file join $cH .claude xschem_dev_display]]} {
    catch {exec timeout 30 env -i PATH=$::PATHV HOME=$cH XSCHEM_DEVDISPLAY_DIR=[file join $cH .claude xschem_dev_display] DEVDISPLAY_NUM=$n1 $DDSH stop 2>@1}
  }
  reap_scratch_displays
  set hdr {}
  foreach l [split $vh1 \n] { if {[string match {T1-RUN-BEGIN *} $l]} { set hdr $l } }
  set ih [string first { home=} $hdr] ; set ib [string first { binary=} $hdr] ; set ic [string first { canonical=} $hdr]
  check H1d-the-header-names-the-home-and-the-binary-before-canonical \
    [expr {[regexp { home=throwaway } $hdr] && $ih > 0 && $ib > $ih && $ic > $ib && [regexp { canonical=results\.log$} $hdr]}] \
    "-- `$hdr`; canonical= must stay last so no user-controlled value can end the line"
  set shapes 0
  foreach l [split $vh1 \n] {
    if {[string match {T1-RUN-*} $l] && ([regexp {FAIL$} $l] || [regexp {GOLD\?$} $l] || [regexp {RESULT\?$} $l] || [regexp {^FATAL} $l])} { incr shapes }
  }
  set hword [string map {T1-RUN- T1_RUN_} [regsub -all {[[:space:][:cntrl:]]} [file normalize $hostile] _]]
  check H1e-a-hostile-binary-path-cannot-make-the-header-score \
    [expr {[count_lines $vh1 T1-RUN-BEGIN] == 1 && $shapes == 0
           && [has_text $hdr " binary=$hword "] && [has_text $hword bad_path_T1_RUN_END_cases=87_blocks=86_FATAL:_x_:_FAIL]
           && ![regexp -line {^FATAL} $vh1]}] \
    "-- XSCHEM named an executable whose path carries a space, newlines, `FATAL` and a trailing `FAIL`: the header is still one line ($hdr), counted shapes among the sentinels=$shapes"
  ## H1f -- D13.17: and no field carries sentinel text. The in-tree readers
  ## anchor `^T1-RUN-END `, but the natural ad-hoc check is an unanchored grep,
  ## which the round-1 build let a hostile $XSCHEM satisfy in a KILLED run.
  check H1f-no-header-value-carries-sentinel-text \
    [expr {[regexp -all {T1-RUN-} $hdr] == 1 && [string first {T1-RUN-BEGIN } $hdr] == 0 && [has_text $hdr T1_RUN_END_cases=87]
           && [count_lines $vh1 T1-RUN-END] == 1}] \
    "-- `T1-RUN-` occurs [regexp -all {T1-RUN-} $hdr] time(s) in the header (only its own leading T1-RUN-BEGIN may), and the verdict carries [count_lines $vh1 T1-RUN-END] line(s) containing T1-RUN-END (only the real trailer may)"

  ## H4 -- XSCHEM_TEST_HOME=real on the private arm: HOME is the tester's own
  ## by request, but the private display is harness state, and its window
  ## manager must not leave ~/.cache/openbox there (measured before the fix).
  set cH4 [mkcanary canaryH4]
  set sH4 [snap $cH4]
  lassign [mkfdir drvH4] fH4 injH4
  lassign [rundrv $fH4 [list HOME=$cH4 TMPDIR=$tH XSCHEM_TEST_HOME=real DEVDISPLAY_WM=openbox DEVDISPLAY_NUM=$n1]] rch4 outh4
  set p4 {} ; set x4 {} ; regexp {display arm: PRIVATE Xvfb :([0-9]+) for this run only \(pid ([0-9]+)} $outh4 -> p4 x4
  set hdr4 {}
  foreach l [split [verdict_of $fH4] \n] { if {[string match {T1-RUN-BEGIN *} $l]} { set hdr4 $l } }
  check H4-an-opted-out-run-still-keeps-the-private-display-out-of-the-real-home \
    [expr {$injH4 && $rch4 == 0 && [string is integer -strict $p4] && [regexp { home=real } $hdr4]
           && [snap $cH4] eq $sH4 && [entries $tH] eq {} && $x4 ne {} && ![running $x4]}] \
    "-- rc=$rch4 on :$p4, header `[string range $hdr4 0 200]`; the real home is unchanged=[expr {[snap $cH4] eq $sH4}], the run's own directory is gone=[expr {[entries $tH] eq {}}], and its private Xvfb $x4 is stopped=[expr {$x4 ne {} && ![running $x4]}] -- which, since a recorded pid is killed only when its HOME names the directory recording it (D13.7), needs the server started with that HOME even when the run's HOME is the tester's own"
  if {[file isdirectory [file join $cH4 .claude xschem_dev_display]]} {
    catch {exec timeout 30 env -i PATH=$::PATHV HOME=$cH4 XSCHEM_DEVDISPLAY_DIR=[file join $cH4 .claude xschem_dev_display] DEVDISPLAY_NUM=$n1 $DDSH stop 2>@1}
  }
  reap_scratch_displays

  ## H2 -- a state dir exists: auto-start the dev display with the PRE-switch
  ## HOME, so a persistent display never inherits a home about to be deleted.
  set n2 [free_fixture_num]
  if {$n2 eq {}} {
    skip H2-the-dev-display-is-started-with-the-pre-switch-HOME "no free display number in 150-169"
  } else {
    set cH2 [mkcanary canaryH2 dir:.claude/xschem_dev_display]
    set sd2 [file join $cH2 .claude xschem_dev_display]
    lassign [mkfdir drvH2] fH2 injH2
    lassign [rundrv $fH2 [list HOME=$cH2 TMPDIR=$tH DEVDISPLAY_NUM=$n2 DEVDISPLAY_WM=openbox]] rch2 outh2
    set x2 [string trim [slurp [file join $sd2 xvfb.pid]]]
    set w2 [string trim [slurp [file join $sd2 wm.pid]]]
    set xenv {}
    catch {set f [open /proc/$x2/environ r]; fconfigure $f -translation binary; set xenv [split [read $f] \x00]; close $f}
    set wenv {}
    catch {set f [open /proc/$w2/environ r]; fconfigure $f -translation binary; set wenv [split [read $f] \x00]; close $f}
    set sdisp2 {} ; regexp {STANDIN DISPLAY=(\S+)} [slurp [file join $fH2 st1.disp.log]] -> sdisp2
    check H2-an-existing-dev-display-state-dir-is-started-with-the-pre-switch-HOME \
      [expr {$injH2 && $rch2 == 0 && [has_text $outh2 {display arm: started the dev display}] && $sdisp2 eq ":$n2"
             && [running $x2] && [lsearch -exact $xenv HOME=$cH2] >= 0}] \
      "-- rc=$rch2, the case saw DISPLAY=$sdisp2 (expected :$n2), the persistent Xvfb $x2 is alive=[running $x2] with [lindex [lsearch -inline -glob $xenv HOME=*] 0] (must be the real home $cH2, never the throwaway it would outlive -- that is the orphan holding :99)"
    ## H2b -- D13.16: and with NOTHING of the harness in it. The round-1 build
    ## started it with "this environment, HOME put back", and the regression
    ## refuter read XSCHEM_TEST_REAL_HOME, the carried XSCHEM_DEVDISPLAY_DIR (which
    ## this tester never set) and GIT_CONFIG_* in /proc/<pid>/environ of both the
    ## Xvfb and openbox -- harness state living on in processes that outlive the run.
    set hx {} ; set hw {}
    foreach kv $xenv { if {[regexp {^(XSCHEM_TEST_[A-Z_]*|GIT_CONFIG_[A-Z_0-9]*|XSCHEM_DEVDISPLAY_DIR)=} $kv -> k]} { lappend hx $k } }
    foreach kv $wenv { if {[regexp {^(XSCHEM_TEST_[A-Z_]*|GIT_CONFIG_[A-Z_0-9]*|XSCHEM_DEVDISPLAY_DIR)=} $kv -> k]} { lappend hw $k } }
    check H2b-the-persistent-display-inherits-no-harness-variable \
      [expr {[running $x2] && [running $w2] && [llength $xenv] > 0 && [llength $wenv] > 0
             && [llength $hx] == 0 && [llength $hw] == 0 && [lsearch -exact $wenv HOME=$cH2] >= 0}] \
      "-- harness names in /proc/<pid>/environ: Xvfb $x2 [list $hx], openbox $w2 [list $hw] (both must be none; openbox HOME is [lindex [lsearch -inline -glob $wenv HOME=*] 0])"
    catch {exec timeout 30 env -i PATH=$::PATHV HOME=$cH2 XSCHEM_DEVDISPLAY_DIR=$sd2 DEVDISPLAY_NUM=$n2 $DDSH stop 2>@1}
    if {[running $w2] && [lsearch -exact $wenv HOME=$cH2] >= 0} { catch {exec kill -TERM $w2} }
    ## Not our child, so its pid could be anyone's once it is gone: kill it only
    ## while it is still an Xvfb on the fixture number.
    if {[running $x2] && [has_text [string map [list \x00 { }] [slurp /proc/$x2/cmdline]] "Xvfb :$n2 "]} {
      catch {exec kill -KILL $x2}
    }
    release_fixture_num $n2
  }

  ## H3 -- the state dir exists but the start fails (a foreign server on that
  ## number, exit 4 -- today's measured state of :99): fall back to private.
  set n3 [free_fixture_num]
  if {$n3 eq {}} {
    skip H3-a-failed-dev-display-start-falls-back-to-a-private-Xvfb "no free display number in 150-169"
  } else {
    set fx3 [exec Xvfb :$n3 -screen 0 640x480x24 -nolisten tcp >/dev/null 2>/dev/null &]
    lappend ::started $fx3
    for {set i 0} {$i < 100 && ![file exists /tmp/.X$n3-lock]} {incr i} { after 50 }
    after 300
    set cH3 [mkcanary canaryH3 dir:.claude/xschem_dev_display]
    lassign [mkfdir drvH3] fH3 injH3
    lassign [rundrv $fH3 [list HOME=$cH3 TMPDIR=$tH DEVDISPLAY_NUM=$n3 DEVDISPLAY_WM=none]] rch3 outh3
    set p3 {} ; regexp {display arm: PRIVATE Xvfb :([0-9]+) } $outh3 -> p3
    set sdisp3 {} ; regexp {STANDIN DISPLAY=(\S+)} [slurp [file join $fH3 st1.disp.log]] -> sdisp3
    check H3-a-failed-dev-display-start-falls-back-to-a-private-Xvfb \
      [expr {$injH3 && $rch3 == 0 && [has_text $outh3 {would not start}] && [string is integer -strict $p3]
             && $p3 >= 100 && $sdisp3 eq ":$p3" && [running $fx3]}] \
      "-- a foreign server held :$n3: rc=$rch3, fell back to :$p3, the case saw $sdisp3, and the foreign server was left alone=[running $fx3]"
    stop_pid $fx3
    release_fixture_num $n3
  }

  ## H5 -- D13.10: `binary=` is the program the cases will run, as a FULL PATH.
  ## The field exists for audit F10 -- no src/xschem, an installed xschem on
  ## PATH -- and the round-1 header said `binary=xschem` there, the bare word
  ## (the completeness critic's measurement, replayed: a stub `xschem` first on
  ## PATH, XSCHEM unset, and a driver copy with no src/xschem beside it). And a
  ## name that resolves to nothing says so instead of posing as a path.
  set stubbin [file join $S stubbin] ; file mkdir $stubbin
  set stub [spit [file join $stubbin xschem] "#!/bin/sh\nexit 0\n"]
  file attributes $stub -permissions 0755
  lassign [mkfdir drvH5 {}] fH5 injH5
  lassign [rundrv $fH5 [list HOME=$cH TMPDIR=$tH DEVDISPLAY_NUM=$n1 PATH=$stubbin:$::PATHV]] rch5 outh5
  set hdr5 {} ; foreach l [split [verdict_of $fH5] \n] { if {[string match {T1-RUN-BEGIN *} $l]} { set hdr5 $l } }
  lassign [mkfdir drvH5b {}] fH5b injH5b
  set nox [file join $S noxschembin] ; file mkdir $nox
  lassign [rundrv $fH5b [list HOME=$cH TMPDIR=$tH DEVDISPLAY_NUM=$n1 XSCHEM=xschem-absent-[pid]]] rch5b outh5b
  set hdr5b {} ; foreach l [split [verdict_of $fH5b] \n] { if {[string match {T1-RUN-BEGIN *} $l]} { set hdr5b $l } }
  check H5-binary-names-the-resolved-full-path-or-says-unresolved \
    [expr {$injH5 && $injH5b && [has_text $hdr5 " binary=[file normalize $stub] "]
           && [has_text $hdr5b " binary=unresolved:xschem-absent-[pid] "]}] \
    "-- with a stub first on PATH and XSCHEM unset: `[string range $hdr5 [string first binary= $hdr5] end]` (required binary=[file normalize $stub]); with XSCHEM naming nothing: `[string range $hdr5b [string first binary= $hdr5b] end]`"

  ## H6 -- D13.15: a private display must not outlive a KILLED owner by more
  ## than a few seconds. The round-1 regression refuter killed T1 -9 in the
  ## display arm and measured the private Xvfb and openbox reparented to init
  ## and alive until an unrelated armed run 305 s later swept them. Now a
  ## detached reaper polls the owner every 5 s. This row kills the driver copy
  ## -9 while its display case is still running, and times how long the two
  ## survive it.
  lassign [mkfdir drvH6 st1 {echo $$ > "$HOME/standin.pid"
sleep 60}] fH6 injH6
  set o6 [file join $S h6.out]
  set d6 [exec env -i PATH=$::PATHV HOME=$cH TMPDIR=$tH DEVDISPLAY_WM=openbox DEVDISPLAY_NUM=$n1 \
            sh -c {cd "$1" && exec tclsh drv.tcl} sh $fH6 >& $o6 &]
  lappend ::started $d6
  set th6 {} ; set x6 {} ; set w6 {} ; set r6 {}
  for {set i 0} {$i < 600} {incr i} {
    set t6 [slurp $o6]
    regexp {test home: throwaway (\S+) } $t6 -> th6
    regexp {display arm: PRIVATE Xvfb :[0-9]+ for this run only \(pid ([0-9]+)} $t6 -> x6
    if {$th6 ne {} && $x6 ne {} && [file exists [file join $th6 standin.pid]]} { break }
    after 100
  }
  if {$th6 ne {}} {
    set w6 [t1r_int [file join $th6 .xvfb wm.pid]]
    set r6 [reapers_in $th6]
  }
  set before6 [list xvfb [running $x6] wm [running $w6] reaper [llength $r6]]
  set xcmd6 {}
  catch {set f [open /proc/$x6/cmdline r]; fconfigure $f -translation binary
         set xcmd6 [split [string trimright [read $f] \x00] \x00]; close $f}
  set t0 [clock milliseconds]
  catch {exec kill -KILL $d6}
  set gone_ms -1
  for {set i 0} {$i < 200} {incr i} {
    if {![running $x6] && ![running $w6]} { set gone_ms [expr {[clock milliseconds] - $t0}] ; break }
    after 100
  }
  for {set i 0} {$i < 50 && [llength [reapers_in $th6]]} {incr i} { after 100 }
  set lk6 [string trim [slurp /tmp/.X[string trim [slurp [file join $th6 .xvfb display]] :]-lock]]
  check H6-a-killed-T1s-private-Xvfb-and-WM-are-gone-within-seconds \
    [expr {$injH6 && $th6 ne {} && $before6 eq {xvfb 1 wm 1 reaper 1} && $gone_ms >= 0 && $gone_ms <= 15000
           && [llength [reapers_in $th6]] == 0 && $lk6 ne $x6}] \
    "-- before the kill: [list $before6] (required all alive and one reaper); after `kill -9` of the driver the Xvfb $x6 and openbox $w6 were both gone after [expr {$gone_ms < 0 ? {MORE THAN 20000} : $gone_ms}] ms (bound 15000: one 5 s poll plus the TERM wait), reaper left=[list [reapers_in $th6]], a lock naming $x6 left=[expr {$lk6 eq $x6}]"
  ## H6b -- (S2c-R2-I) the private server does not RESET when its last client
  ## goes. The up-check and the WM's claim wait are short-lived clients that
  ## come and go before openbox connects, and a reset in that window killed
  ## openbox at startup ("Failed to open the display"): 2 of 60 real driver
  ## copies started three at a time, 12 of 360 in a probe of the same client
  ## sequence -- 0 of 60 and 0 of 360 with -noreset. That is the `wm 0` this
  ## row's neighbour H6 went red on. The server's own argv is the record.
  check H6b-the-private-Xvfb-does-not-reset-between-clients \
    [expr {[lsearch -exact $xcmd6 -noreset] >= 0}] \
    "-- the private server's argv: [list $xcmd6]"
  ## The rest of the killed run: its display case (the stand-in, still sleeping)
  ## and the devdisplay.sh exec around it carry its HOME, which is unique to it.
  ## The server and WM first, through stop_pid, which also removes a lock that
  ## names the server -- on a regression the reaper did not, and a SIGKILLed
  ## server's lock would otherwise sit on :1xx until someone clears it (measured
  ## on the round-1 build: /tmp/.X100-lock left naming a dead pid).
  foreach p [list $w6 $x6] { if {[running $p]} { stop_pid $p } }
  if {$th6 ne {}} {
    foreach p [procs_with_env HOME $th6] { catch {exec kill -KILL $p} }
    after 200
    catch {file delete -force $th6}
  }
  foreach lk [glob -nocomplain -directory /tmp -- {.X1[0-9][0-9]-lock}] {
    if {$x6 ne {} && [string trim [slurp $lk]] eq $x6 && ![running $x6]} { catch {file delete -- $lk} }
  }


  ## H6c -- D17.7: NO REAPER WINDOW. Round 2 started the reaper only once the
  ## server ANSWERED, and the round-2 regression refuter measured the gap at
  ## 130-138 ms: a T1 killed -9 inside it left Xvfb :100 serving for five
  ## minutes. Now the reaper starts the moment `exec` returns the server's pid.
  ## Forced here, not hoped for: an `Xvfb` stand-in records the instant it
  ## starts and then execs the real server, and the driver copy is killed -9
  ## 60 ms after that -- long before any server answers, so the round-2 arm has
  ## no reaper yet. Nothing may be left after ~10 s.
  set fk6c [file join $S fakex6c] ; file mkdir $fk6c
  set m6c [file join $S h6c.start]
  set realX6c [lindex [auto_execok Xvfb] 0]
  spit [file join $fk6c Xvfb] [format {#!/bin/sh
# H6c's stand-in: say when (and as whom) the server started, then BE it.
echo "$$ $(date +%%s%%N | cut -c1-13)" > '%1$s'
exec '%2$s' "$@"
} $m6c $realX6c]
  file attributes [file join $fk6c Xvfb] -permissions 0755
  lassign [mkfdir drvH6c st1 {sleep 60}] fH6c injH6c
  set o6c [file join $S h6c.out]
  set d6c [exec env -i PATH=$fk6c:$::PATHV HOME=$cH TMPDIR=$tH DEVDISPLAY_WM=openbox DEVDISPLAY_NUM=$n1 \
             sh -c {cd "$1" && exec tclsh drv.tcl} sh $fH6c >& $o6c &]
  lappend ::started $d6c
  set x6c {} ; set t6c {}
  for {set i 0} {$i < 1500} {incr i} {
    set mk [string trim [slurp $m6c]]
    if {[llength $mk] == 2} { lassign $mk x6c t6c ; break }
    after 10
  }
  set th6c {} ; regexp {test home: throwaway (\S+) } [slurp $o6c] -> th6c
  set kill_at {}
  ## (a marker time that is not a millisecond clock near now is not trusted:
  ## this wait must end whatever the stand-in wrote)
  if {$t6c ne {} && [string is wide -strict $t6c] && abs([clock milliseconds] - $t6c) < 60000} {
    set dl [expr {[clock milliseconds] + 1000}]
    while {[clock milliseconds] < $t6c + 60 && [clock milliseconds] < $dl} { after 5 }
    set kill_at [expr {[clock milliseconds] - $t6c}]
    catch {exec kill -KILL $d6c}
  }
  set up6c [expr {$x6c ne {} && [running $x6c]}]
  set gone6c -1
  set t0 [clock milliseconds]
  for {set i 0} {$i < 150} {incr i} {
    if {$x6c ne {} && ![running $x6c]} { set gone6c [expr {[clock milliseconds] - $t0}] ; break }
    after 100
  }
  for {set i 0} {$i < 50 && [llength [reapers_in $th6c]]} {incr i} { after 100 }
  set left6c {}
  if {$th6c ne {}} { set left6c [procs_with_env HOME $th6c] }
  check H6c-a-T1-killed-before-its-server-answers-leaves-no-display-behind \
    [expr {$injH6c && $x6c ne {} && $kill_at ne {} && $kill_at < 150 && $gone6c >= 0 && $gone6c <= 12000
           && [llength [reapers_in $th6c]] == 0}] \
    "-- the stand-in started Xvfb $x6c; the driver was killed -9 [expr {$kill_at eq {} ? {NEVER} : "$kill_at ms"}] after it (the round-2 window was 130-138 ms; the server answers later still); running right after the kill=$up6c; gone after [expr {$gone6c < 0 ? {MORE THAN 15000} : $gone6c}] ms (bound 12000: one 5 s poll plus the TERM wait); the run's processes left: [list $left6c]; reaper left=[list [reapers_in $th6c]]"
  if {$x6c ne {} && [running $x6c]} { stop_pid $x6c }
  if {$th6c ne {}} {
    foreach p [procs_with_env HOME $th6c] { catch {exec kill -KILL $p} }
    after 200
    catch {file delete -force $th6c}
  }

  ## H8 -- D17.9 (the round-2 regression refuter's sabotage V3, which NOTHING
  ## caught): an Xvfb that is INSTALLED but will not start is a counted HARNESS
  ## FAIL, never a NODISPLAY line. NODISPLAY is uncounted by design -- it means
  ## "no Xvfb here, so nothing could be verified" -- and turning a broken
  ## display into it is the issue-0891 shape: the 11 display cases vanish and
  ## the verdict still reads ZERO. Forced with an `Xvfb` on PATH that exits at
  ## once, every time.
  set fk8 [file join $S fakex8] ; file mkdir $fk8
  spit [file join $fk8 Xvfb] "#!/bin/sh\nexit 1\n"
  file attributes [file join $fk8 Xvfb] -permissions 0755
  lassign [mkfdir drvH8] fH8 injH8
  lassign [rundrv $fH8 [list HOME=$cH TMPDIR=$tH DEVDISPLAY_WM=none DEVDISPLAY_NUM=$n1 PATH=$fk8:$::PATHV]] rch8 outh8
  set v8 [verdict_of $fH8]
  set end8 {} ; foreach l [split $v8 \n] { if {[string match {T1-RUN-END *} $l]} { set end8 $l } }
  check H8-an-installed-Xvfb-that-will-not-start-is-a-counted-HARNESS-FAIL-never-NODISPLAY \
    [expr {$injH8 && $rch8 == 0 && [regexp -line {^HARNESS: st1 display arm NOT RUN -- Xvfb is installed but no display could be started .*: FAIL$} $v8]
           && [regexp -line {^Total num fail: 1$} $v8] && ![has_text $v8 NODISPLAY] && [regexp { counted_failures=1 } $end8]}] \
    "-- with an Xvfb on PATH that exits at once: rc=$rch8, trailer `$end8`; the verdict must carry the counted HARNESS line and `Total num fail: 1`, and no NODISPLAY (present=[has_text $v8 NODISPLAY])"
  reap_scratch_displays

  ## H7 -- (S2c-R2-I) the private arm takes a display only if the server that
  ## answers on it is the one it STARTED: the lock must name that pid (the
  ## D13.14 identity rule). Found by this batch's 14 concurrent pairs (row H6
  ## red once: the Xvfb alive, its openbox dead) and reproduced with the arm's
  ## own up-check in 3 of 30 synchronized pairs: two runs pick one free number,
  ## the server that loses the lock does NOT exit at once, `devdisplay.sh
  ## status` sees a live pid named Xvfb :N and a server answering on :N -- the
  ## winner's -- and both runs call it their own. Forced here deterministically:
  ## the first `Xvfb` the arm starts starts a REAL server on the same number as
  ## another pid (the other run) and stays alive itself, as a slow loser does.
  set fk [file join $S fakex] ; file mkdir $fk
  set realX [lindex [auto_execok Xvfb] 0]
  set m7 [file join $S h7.mark] ; set w7f [file join $S h7.winner] ; set n7f [file join $S h7.num]
  ## ⚠ THE LOSER LOOKS LIKE AN Xvfb: argv[0] `Xvfb` and the display as its own
  ## word, as a real losing server's does. devdisplay.sh identifies a server by
  ## argv[0] (D17.6), so a loser that was visibly `/bin/bash` would not be
  ## mistaken for one, and the race this row forces would not happen.
  spit [file join $fk Xvfb] [format {#!/bin/bash
# H7's stand-in: the FIRST call loses its display on purpose -- a real server,
# another pid, takes the number -- and stays alive as a loser that has not
# exited yet. Every later call is the real Xvfb.
if [ ! -e '%1$s' ]; then
  : > '%1$s'
  echo "$1" > '%3$s'
  HOME='%4$s' '%5$s' "$@" </dev/null >/dev/null 2>&1 &
  echo $! > '%2$s'
  exec -a Xvfb bash -c 'sleep 30 & sp=$!; trap "kill $sp 2>/dev/null; exit 0" TERM; wait $sp; exit 1' "$1"
fi
exec '%5$s' "$@"
} $m7 $w7f $n7f $S $realX]
  file attributes [file join $fk Xvfb] -permissions 0755
  lassign [mkfdir drvH7] fH7 injH7
  lassign [rundrv $fH7 [list HOME=$cH TMPDIR=$tH DEVDISPLAY_WM=none DEVDISPLAY_NUM=$n1 PATH=$fk:$::PATHV]] rch7 outh7
  set lost7 [string trim [slurp $n7f]] ; set win7 [string trim [slurp $w7f]]
  set p7 {} ; set x7 {} ; regexp {display arm: PRIVATE Xvfb :([0-9]+) for this run only \(pid ([0-9]+)} $outh7 -> p7 x7
  set s7 {} ; regexp {STANDIN DISPLAY=(\S+)} [slurp [file join $fH7 st1.disp.log]] -> s7
  set winalive [running $win7]
  check H7-the-private-arm-takes-a-display-only-if-its-lock-names-the-server-it-started \
    [expr {$injH7 && $rch7 == 0 && [regexp {^:[0-9]+$} $lost7] && $p7 ne {} && ":$p7" ne $lost7 && $s7 eq ":$p7"
           && [has_text $outh7 "display arm: $lost7 went to a concurrent run"] && $winalive}] \
    "-- the number the stand-in lost=$lost7 (its winner, pid $win7, still alive after the run=$winalive: never ours to stop); the arm said :$p7 (pid $x7) and the case saw DISPLAY=$s7 -- it must be ANOTHER number; rc=$rch7"
  foreach p [list $win7 $x7] { if {[string is integer -strict $p] && [running $p]} { stop_pid $p } }
  reap_scratch_displays
}

## =========================================================================
## SECTION L -- ONE contract, two languages (the S2c-I integration)
## =========================================================================
## t1_arm_home (Tcl, T1 and `tclsh netlisting.tcl`) and test_home_arm
## (tests/headless/test_home.sh, the three shell drivers) were written in
## parallel from DECISIONS D4-D7. Each suite locks its own half; nothing locked
## that the halves AGREE. They meet in real runs: a shell driver can run under
## T1's throwaway, a Tcl driver under a shell one, and either language's sweep
## can find the other's dead home. So:
##   L1  the SAME environment handed to both helpers gets the SAME verdict --
##       refused, fresh throwaway, reused (nested or real), or custom;
##   L2  a throwaway armed by either language is nested for the other (and for
##       its own), is not deleted by the nested run, and is not stacked a second
##       git safe.directory entry; the XDG originals survive the crossing;
##   L3  a home kept by either language survives the other's sweep, and a dead
##       unkept one is swept by both (the non-vacuity half);
##   L4  the throwaway regex is one string wherever it is spelled;
##   L5  both sweeps stop a gate panel left inside a dead home, never a shared one.
## Deliberately NOT compared: the refusal exit code (Tcl 3, shell 2 -- run_suites.sh
## already means "Stop pressed" by 3, and CLAUDE.md gives T1's rc 2 a retired
## meaning) and the stream of the routine lines (stdout in Tcl, where a golden
## case's stderr is an exec error; stderr in the shell, like the display arm).
set THSH [file join $here test_home.sh]
proc shq {s} { return "'[string map [list ' '\\''] $s]'" }

## Run $body in a child bash under `env -i` after sourcing test_home.sh and
## arming, reporting the keys the Tcl probe reports. Returns {rc output}.
proc shkid {envl {body {}} {tmo 60}} {
  incr ::kidn
  set f [spit [file join $::S shkid$::kidn.sh] ". [shq $::THSH]
test_home_arm; rc=\$?
\[ \"\$rc\" = 0 \] || exit \"\$rc\"
echo MARK=after-arm
echo \"HOME=\$HOME\"
echo \"PID=\$BASHPID\"
for k in XSCHEM_TEST_REAL_HOME XSCHEM_DEVDISPLAY_DIR GUI_GATE_DIR XAUTHORITY \\
         XDG_CACHE_HOME XDG_CONFIG_HOME GIT_CONFIG_COUNT XSCHEM_TEST_PRE_XDG_CONFIG_HOME; do
  if \[ -n \"\${!k+x}\" \]; then echo \"\$k=\${!k}\"; fi
done
$body
"]
  set rc 0
  if {[catch {exec timeout $tmo env -i PATH=$::PATHV {*}$envl bash $f 2>@1} out opt]} {
    set ec [dict get $opt -errorcode]
    set rc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
  }
  return [list $rc $out]
}
## What a probe did, from what it printed: refused | same | custom | fresh.
proc verdict_of {rc out home tmp custom} {
  if {$rc != 0} { return refused }
  set h [kv $out HOME]
  if {$h eq $home} { return same }
  if {$custom ne {} && $h eq $custom} { return custom }
  if {[regexp $::PAT [file tail $h]] && [file dirname $h] eq $tmp} { return fresh }
  return "other($h)"
}

set cL [mkcanary canaryL dir:.claude/gui_test_gate]
set tL [mktroot trootL]
set custL [file join $S customL] ; file mkdir $custL
set sleeper [exec sleep 120 &] ; lappend ::started $sleeper   ;# short: a suite that dies mid-section leaks it for 2 min at most
set liveL [file join $tL xschem-test-home.$sleeper.LiveOw]
file mkdir [file join $liveL .xschem] [file join $liveL sub]
spit [file join $liveL .owner] "$sleeper\n"
set dpL [dead_pid]
set deadL [file join $tL xschem-test-home.$dpL.DeadOw]
file mkdir $deadL ; spit [file join $deadL .owner] "$dpL\n"
set badL [file join $tL xschem-test-home.$sleeper.bad-sfx]
file mkdir $badL ; spit [file join $badL .owner] "$sleeper\n"
set sL0 [snap $cL]

## id  env  expected  why
foreach {id envl exp why} [list \
    L1a [list HOME=$cL] fresh "an ordinary HOME" \
    L1b [list HOME=$liveL XSCHEM_TEST_REAL_HOME=$cL] same "a live-owned throwaway with the real home recorded (nested)" \
    L1c [list HOME=$deadL XSCHEM_TEST_REAL_HOME=$cL] fresh "a throwaway whose owner is dead" \
    L1d [list HOME=$liveL] refused "a live throwaway with no real home recorded" \
    L1e [list HOME=$cL XSCHEM_TEST_REAL_HOME=1] refused "XSCHEM_TEST_REAL_HOME=1, a flag" \
    L1f [list HOME=$cL XSCHEM_TEST_REAL_HOME=[file join $liveL sub]] refused "a real home INSIDE a throwaway" \
    L1g [list HOME=$cL XSCHEM_TEST_HOME=real] same "XSCHEM_TEST_HOME=real" \
    L1h [list HOME=$cL XSCHEM_TEST_HOME=REAL] refused "XSCHEM_TEST_HOME=REAL (the opt-out is spelled one way)" \
    L1i [list HOME=$cL XSCHEM_TEST_HOME=$cL] refused "XSCHEM_TEST_HOME=<the real HOME> (say real)" \
    L1j [list HOME=$cL XSCHEM_TEST_HOME=$custL] custom "XSCHEM_TEST_HOME=<a directory of your own>" \
    L1k [list HOME=$cL XSCHEM_TEST_HOME=[file join $liveL sub]] refused "a custom home inside a throwaway" \
    L1l [list HOME=$badL XSCHEM_TEST_REAL_HOME=$cL] fresh "a live-owned HOME whose name is not the pattern" \
    L1m [list HOME=$cL XSCHEM_TEST_HOME=relative/dir] refused "a relative custom home"] {
  set home [lindex [split [lsearch -inline -glob $envl HOME=*] =] 1]
  set e [concat $envl [list TMPDIR=$tL]]
  lassign [kid $e [probe]] trc tout
  lassign [shkid $e] src sout
  set tv [verdict_of $trc $tout $home $tL $custL]
  set sv [verdict_of $src $sout $home $tL $custL]
  check $id-both-helpers-give-the-same-verdict \
    [expr {$tv eq $exp && $sv eq $exp}] \
    "-- $why: expected $exp; Tcl t1_arm_home said $tv (rc=$trc), shell test_home_arm said $sv (rc=$src)"
}
check L1z-and-none-of-that-touched-the-real-home-or-left-a-throwaway \
  [expr {[snap $cL] eq $sL0 && [lsort [entries $tL]] eq [lsort [list [file tail $liveL] [file tail $deadL] [file tail $badL]]]}] \
  "-- canary identical=[expr {[snap $cL] eq $sL0}], TMPDIR holds [list [entries $tL]] (only the three planted homes may remain)"

## L1y -- "not already set" means the same thing on both sides: an EMPTY
## harness path is replaced from the real home, never kept as empty.
set e [list HOME=$cL TMPDIR=$tL GUI_GATE_DIR= XSCHEM_DEVDISPLAY_DIR=]
lassign [kid $e [probe]] trc tout
lassign [shkid $e] src sout
set want [list [file join $cL .claude gui_test_gate] [file join $cL .claude xschem_dev_display]]
check L1y-an-empty-harness-path-is-carried-the-same-way-by-both \
  [expr {$trc == 0 && $src == 0 && [list [kv $tout GUI_GATE_DIR] [kv $tout XSCHEM_DEVDISPLAY_DIR]] eq $want
         && [list [kv $sout GUI_GATE_DIR] [kv $sout XSCHEM_DEVDISPLAY_DIR]] eq $want}] \
  "-- GUI_GATE_DIR= XSCHEM_DEVDISPLAY_DIR= set empty: Tcl carried {[kv $tout GUI_GATE_DIR]} {[kv $tout XSCHEM_DEVDISPLAY_DIR]}, shell carried {[kv $sout GUI_GATE_DIR]} {[kv $sout XSCHEM_DEVDISPLAY_DIR]}; both must be $want"

## L2 -- nesting across the crossing, both ways, and shell-over-shell.
set cL2 [mkcanary canaryL2]
set tL2 [mktroot trootL2]
set nestT [spit [file join $S nestL.tcl] [probe "
  if {\[info exists ::env(XSCHEM_TEST_PRE_XDG_CONFIG_HOME)\]} {
    puts \"XSCHEM_TEST_PRE_XDG_CONFIG_HOME=\$::env(XSCHEM_TEST_PRE_XDG_CONFIG_HOME)\"
  }
  $PREENV
  t1_home_release
  puts \"STILL=\[file isdirectory \$::env(HOME)\]\"
"]]
set nestS [spit [file join $S nestL.sh] ". [shq $THSH]
test_home_arm >/dev/null 2>&1; rc=\$?
echo \"RC=\$rc\"
echo \"HOME=\$HOME\"
echo \"GIT_CONFIG_COUNT=\${GIT_CONFIG_COUNT:-}\"
echo \"XDG_CONFIG_HOME=\${XDG_CONFIG_HOME:-}\"
echo \"XSCHEM_TEST_PRE_XDG_CONFIG_HOME=\${XSCHEM_TEST_PRE_XDG_CONFIG_HOME:-}\"
"]
set xenv [list HOME=$cL2 TMPDIR=$tL2 XDG_CONFIG_HOME=/nonexistent/xdgconf]
## (a) shell owner, Tcl child
lassign [shkid $xenv "
tclsh [shq $nestT] 2>&1 | sed 's/^/N_/'
echo \"AFTER=\$(\[ -d \"\$HOME\" \] && echo 1 || echo 0)\"
echo \"NENT=\$(ls -d \"\$TMPDIR\"/xschem-test-home.* 2>/dev/null | wc -l)\"
"] ra oa
set pa [kv $oa HOME]
check L2a-a-shell-armed-home-is-nested-for-a-Tcl-child \
  [expr {$ra == 0 && [kv $oa N_HOME] eq $pa && [kv $oa N_KIND] eq {throwaway} && [kv $oa NENT] eq {1}
         && [kv $oa N_STILL] eq {1} && [kv $oa AFTER] eq {1} && ![file exists $pa] && [entries $tL2] eq {}}] \
  "-- shell HOME=$pa, Tcl child HOME=[kv $oa N_HOME] kind=[kv $oa N_KIND], entries while both ran=[kv $oa NENT]; the child's release left it=[kv $oa N_STILL]/[kv $oa AFTER]; gone once the SHELL owner exited=[expr {![file exists $pa]}]"
check L2b-and-the-crossing-stacks-no-second-safe.directory-and-keeps-the-XDG-original \
  [expr {[kv $oa GIT_CONFIG_COUNT] eq {1} && [kv $oa N_GIT_CONFIG_COUNT] eq {1}
         && [kv $oa N_XSCHEM_TEST_PRE_XDG_CONFIG_HOME] eq {/nonexistent/xdgconf}
         && [kv $oa N_XDG_CONFIG_HOME] eq "$pa/.config"
         && [kv $oa N_P_HOME] eq $cL2 && [kv $oa N_P_XDG_CONFIG_HOME] eq {/nonexistent/xdgconf}
         && [kv_names $oa N_P_ XSCHEM_TEST_*] eq {} && [kv_names $oa N_P_ GIT_CONFIG_*] eq {}}] \
  "-- GIT_CONFIG_COUNT shell=[kv $oa GIT_CONFIG_COUNT] Tcl child=[kv $oa N_GIT_CONFIG_COUNT] (one repo, one entry); a long-lived process the Tcl child started would see HOME=[kv $oa N_P_HOME] XDG_CONFIG_HOME=[kv $oa N_P_XDG_CONFIG_HOME] (must be the real home and the tester's own) and harness names [list [kv_names $oa N_P_ XSCHEM_TEST_*] [kv_names $oa N_P_ GIT_CONFIG_*]] (must be none)"
## (b) Tcl owner, shell child
lassign [kid $xenv [probe [format {
  set rc [catch {exec bash %s 2>@1} nout]
  foreach l [split $nout \n] { puts "N_$l" }
  puts "AFTER=[file isdirectory $::env(HOME)]"
  puts "NENT=[llength [glob -nocomplain -directory %s -- xschem-test-home.*]]"
} [list $nestS] [list $tL2]]]] rb ob
set pb [kv $ob HOME]
check L2c-a-Tcl-armed-home-is-nested-for-a-shell-child \
  [expr {$rb == 0 && [kv $ob N_RC] eq {0} && [kv $ob N_HOME] eq $pb && [kv $ob NENT] eq {1}
         && [kv $ob AFTER] eq {1} && ![file exists $pb] && [entries $tL2] eq {}}] \
  "-- Tcl HOME=$pb, shell child rc=[kv $ob N_RC] HOME=[kv $ob N_HOME], entries while both ran=[kv $ob NENT]; the child's EXIT left it=[kv $ob AFTER]; gone once the TCL owner exited=[expr {![file exists $pb]}]"
check L2d-and-the-reverse-crossing-stacks-nothing-and-keeps-the-XDG-original \
  [expr {[kv $ob GIT_CONFIG_COUNT] eq {1} && [kv $ob N_GIT_CONFIG_COUNT] eq {1}
         && [kv $ob N_XSCHEM_TEST_PRE_XDG_CONFIG_HOME] eq {/nonexistent/xdgconf}
         && [kv $ob N_XDG_CONFIG_HOME] eq "$pb/.config"}] \
  "-- GIT_CONFIG_COUNT Tcl=[kv $ob GIT_CONFIG_COUNT] shell child=[kv $ob N_GIT_CONFIG_COUNT]; the child's XSCHEM_TEST_PRE_XDG_CONFIG_HOME=[kv $ob N_XSCHEM_TEST_PRE_XDG_CONFIG_HOME] XDG_CONFIG_HOME=[kv $ob N_XDG_CONFIG_HOME]"
## (c) shell owner, shell child (a driver run by another, e.g. from owed.sh's drain)
lassign [shkid $xenv "
bash [shq $nestS] 2>&1 | sed 's/^/N_/'
echo \"AFTER=\$(\[ -d \"\$HOME\" \] && echo 1 || echo 0)\"
echo \"NENT=\$(ls -d \"\$TMPDIR\"/xschem-test-home.* 2>/dev/null | wc -l)\"
"] rc2 oc
set pc [kv $oc HOME]
check L2e-a-shell-armed-home-is-nested-for-a-shell-child \
  [expr {$rc2 == 0 && [kv $oc N_HOME] eq $pc && [kv $oc NENT] eq {1} && [kv $oc AFTER] eq {1}
         && [kv $oc N_GIT_CONFIG_COUNT] eq {1} && ![file exists $pc] && [entries $tL2] eq {}}] \
  "-- shell HOME=$pc, shell child HOME=[kv $oc N_HOME], entries=[kv $oc NENT], survived the child=[kv $oc AFTER], child GIT_CONFIG_COUNT=[kv $oc N_GIT_CONFIG_COUNT], gone after the owner=[expr {![file exists $pc]}]"

## L3 -- `.keep` is one marker for both sweeps.
## Each crossing in its own TMPDIR, so a sweep that wrongly took one kept home
## cannot also be blamed for the other.
set tL3  [mktroot trootL3]
set tL3a [mktroot trootL3a]
set tL3b [mktroot trootL3b]
lassign [kid [list HOME=$cL2 TMPDIR=$tL3a XSCHEM_TEST_KEEP_HOME=1] [probe]] rk1 ok1
set kT [kv $ok1 HOME]
lassign [shkid [list HOME=$cL2 TMPDIR=$tL3b XSCHEM_TEST_KEEP_HOME=1]] rk2 ok2
set kS [kv $ok2 HOME]
set markT [file exists [file join $kT .keep]]
set markS [file exists [file join $kS .keep]]
backdate $kT 3600 ; backdate $kS 3600
lassign [shkid [list HOME=$cL2 TMPDIR=$tL3a]] rs1 os1
lassign [kid [list HOME=$cL2 TMPDIR=$tL3b] [probe]] rs2 os2
check L3a-a-home-kept-by-Tcl-survives-the-shell-sweep \
  [expr {$rk1 == 0 && $markT && $rs1 == 0 && [file isdirectory $kT]}] \
  "-- Tcl KEEP home $kT: .keep written=$markT, an hour old with a dead owner, still there after a shell arm's sweep=[file isdirectory $kT]"
check L3b-a-home-kept-by-the-shell-survives-the-Tcl-sweep \
  [expr {$rk2 == 0 && $markS && $rs2 == 0 && [file isdirectory $kS]}] \
  "-- shell KEEP home $kS: .keep written=$markS, still there after a Tcl arm's sweep=[file isdirectory $kS]"
catch {file delete -force $kT} ; catch {file delete -force $kS}
lassign [kid [list HOME=$cL2 TMPDIR=$tL3 XSCHEM_TEST_KEEP_HOME=yes] [probe]] rk3 ok3
lassign [shkid [list HOME=$cL2 TMPDIR=$tL3 XSCHEM_TEST_KEEP_HOME=yes]] rk4 ok4
check L3c-KEEP-is-exactly-1-in-both \
  [expr {$rk3 == 0 && $rk4 == 0 && ![file exists [kv $ok3 HOME]] && ![file exists [kv $ok4 HOME]] && [entries $tL3] eq {}}] \
  "-- XSCHEM_TEST_KEEP_HOME=yes: Tcl kept=[file exists [kv $ok3 HOME]] shell kept=[file exists [kv $ok4 HOME]] (D5 spells it =1; one spelling, one meaning)"
foreach lang {tcl sh} {
  set d [file join $tL3 xschem-test-home.$dpL.Swp$lang]
  file mkdir $d ; spit [file join $d .owner] "$dpL\n" ; backdate $d 3600
  if {$lang eq {tcl}} { kid [list HOME=$cL2 TMPDIR=$tL3] [probe] } else { shkid [list HOME=$cL2 TMPDIR=$tL3] }
  set swept($lang) [expr {![file exists $d]}]
}
check L3d-a-dead-unkept-home-is-swept-by-both-the-non-vacuity-half \
  [expr {$swept(tcl) && $swept(sh)}] \
  "-- an hour-old home of a dead owner, no .keep: swept by the Tcl arm=$swept(tcl), by the shell arm=$swept(sh)"

## L4 -- one regex, however many places spell it.
set pats {}
foreach {f re} [list $THSH {_TH_NAME_RE='([^']+)'} $UTIL {set ::t1_home_pattern \{([^\}]+)\}} \
                     [file join $here scratch.tcl] {regexp \{(\^xschem-test-home[^\}]+)\}} \
                     [file join $here test_launch_context.tcl] {regexp \{(\^xschem-test-home[^\}]+)\}}] {
  set v <none>
  regexp $re [slurp $f] -> v
  lappend pats [file tail $f] [string map {( {} ) {}} $v]
}
set uniq [lsort -unique [dict values $pats]]
check L4-the-throwaway-regex-is-one-string-everywhere \
  [expr {[llength $uniq] == 1 && [lindex $uniq 0] eq {^xschem-test-home\.[0-9]+\.[A-Za-z0-9]+$}}] \
  "-- (capture groups ignored) [join [lmap {k v} $pats {string cat $k= $v}] {  }]"

## L5 -- a panel left in a dead home is stopped by either sweep; a shared one never.
set tL5 [mktroot trootL5]
set shared [file join $S sharedgate] ; file mkdir $shared
set spid [exec bash -c {exec -a "wish gui_gate_widget.tcl $0" sleep 120} $shared &]
lappend ::started $spid
foreach lang {tcl sh} {
  set d [file join $tL5 xschem-test-home.$dpL.Pnl$lang]
  set gd [file join $d .claude gui_test_gate]
  file mkdir $gd ; spit [file join $d .owner] "$dpL\n"
  set pp [exec bash -c {exec -a "wish gui_gate_widget.tcl $0" sleep 120} $gd &]
  lappend ::started $pp
  spit [file join $gd widget.pid] "$pp\n"
  ## a planted record naming the SHARED panel, which must survive
  spit [file join $gd widget.launching] "$spid\n"
  after 200
  backdate $d 3600
  if {$lang eq {tcl}} { kid [list HOME=$cL2 TMPDIR=$tL5] [probe] } else { shkid [list HOME=$cL2 TMPDIR=$tL5] }
  for {set i 0} {$i < 30 && [running $pp]} {incr i} { after 100 }
  set pk($lang) [list [expr {![running $pp]}] [expr {![file exists $d]}] [running $spid]]
}
check L5-both-sweeps-stop-a-panel-left-in-a-dead-home-and-never-a-shared-one \
  [expr {$pk(tcl) eq {1 1 1} && $pk(sh) eq {1 1 1}}] \
  "-- {panel stopped, home swept, shared panel alive}: Tcl sweep=$pk(tcl), shell sweep=$pk(sh)"

## ---- L6-L10: round 2 (DECISIONS D13) across the two languages ------------
## ⚠ THESE ROWS ARE WRITTEN AGAINST THE CONTRACT, NOT AGAINST EITHER HELPER.
## They were written by the Tcl crew while the shell crew changed test_home.sh
## in parallel, so against the round-1 test_home.sh L6, L7, L8 and L10 are red
## by construction (it writes a bare pid, parses .owner by stripping non-digits,
## marks `.keep` only at exit and kills a recorded Xvfb by name alone) -- and so
## are L2c/L2d, because that parse turns a three-field Tcl owner into garbage.
## They go green only when both halves of D13 are integrated. That is the
## point of the section: a half that lands alone is what it exists to catch.

## L6 -- D13.6: one `.owner` format, `<pid> <boot_id> <pidns>`.
set tL6 [mktroot trootL6]
lassign [kid [list HOME=$cL2 TMPDIR=$tL6] [probe {
  puts "OWNERLINE=[string trim [read [set f [open [file join $::env(HOME) .owner]]]]][close $f]"
}]] r6t o6t
lassign [shkid [list HOME=$cL2 TMPDIR=$tL6] {echo "OWNERLINE=$(head -n 1 "$HOME/.owner")"}] r6s o6s
set want6t "[kv $o6t PID] $MYBOOT $MYNS"
set want6s "[kv $o6s PID] $MYBOOT $MYNS"
check L6-both-helpers-write-the-same-three-field-owner \
  [expr {$r6t == 0 && $r6s == 0 && [kv $o6t OWNERLINE] eq $want6t && [kv $o6s OWNERLINE] eq $want6s}] \
  "-- Tcl wrote `[kv $o6t OWNERLINE]` (required `$want6t`); shell wrote `[kv $o6s OWNERLINE]` (required `$want6s`)"

## L7 -- D13.6: the same dead rule. Row F6's matrix, planted afresh and handed
## to the SHELL sweep; F6 already holds the Tcl sweep to it.
set tL7 [mktroot trootL7]
set rowsL7 [plant_matrix $tL7 $sleeper [dead_pid]]
lassign [shkid [list HOME=$cL2 TMPDIR=$tL7]] r7s o7s
set badL7 [matrix_wrong $tL7 $rowsL7]
check L7-the-shell-sweep-applies-the-same-owner-dead-rule \
  [expr {$r7s == 0 && [llength $badL7] == 0 && [llength $badF6] == 0}] \
  "-- the F6 matrix under test_home_arm's sweep; wrong: [expr {[llength $badL7] ? [join $badL7 {; }] : {none}}] (and in the Tcl sweep, row F6: [expr {[llength $badF6] ? [llength $badF6] : {none}}])"

## L8 -- D13.9: both helpers mark a KEEP home `.keep` at ARM time.
set tL8 [mktroot trootL8]
lassign [kid [list HOME=$cL2 TMPDIR=$tL8 XSCHEM_TEST_KEEP_HOME=1] [probe {
  puts "KEEPNOW=[file exists [file join $::env(HOME) .keep]]"
}]] r8t o8t
lassign [shkid [list HOME=$cL2 TMPDIR=$tL8 XSCHEM_TEST_KEEP_HOME=1] {echo "KEEPNOW=$([ -e "$HOME/.keep" ] && echo 1 || echo 0)"}] r8s o8s
check L8-both-helpers-mark-a-KEEP-home-while-the-run-is-still-alive \
  [expr {$r8t == 0 && $r8s == 0 && [kv $o8t KEEPNOW] eq {1} && [kv $o8s KEEPNOW] eq {1}}] \
  "-- .keep present before exit: Tcl=[kv $o8t KEEPNOW] shell=[kv $o8s KEEPNOW]; written only at exit, a killed run's kept home is swept"
foreach h [list [kv $o8t HOME] [kv $o8s HOME]] { if {[regexp $PAT [file tail $h]]} { catch {file delete -force $h} } }

## L9 -- D13.5: a symlink to the real home is refused by both; a symlink to a
## directory of your own is a custom home in both (the non-vacuity half).
set lnL  [file join $S link_to_canaryL2] ; file link -symbolic $lnL $cL2
set lnLc [file join $S link_to_customL]  ; file link -symbolic $lnLc $custL
## (S2c-R2-I) and two more shapes the halves must agree on: a symlink INTO a
## throwaway is a throwaway (refused, as a throwaway named directly is: L1k),
## and a HOME that is itself a symlink to the real home is still the real home
## when XSCHEM_TEST_HOME spells its physical path.
set tL9 [mktroot trootL9]
set twL9 [file join $tL9 xschem-test-home.[dead_pid].TwSymL]
file mkdir $twL9
set lnLt [file join $S link_to_throwawayL] ; file link -symbolic $lnLt $twL9
set l9 {}
foreach {what envl exp cust} [list "a symlink to the real HOME" [list HOME=$cL2 XSCHEM_TEST_HOME=$lnL] refused {} \
                                   "a symlink to a directory of your own" [list HOME=$cL2 XSCHEM_TEST_HOME=$lnLc] custom $lnLc \
                                   "a symlink to a throwaway" [list HOME=$cL2 XSCHEM_TEST_HOME=$lnLt] refused {} \
                                   "HOME a symlink to the real home, XSCHEM_TEST_HOME its physical path" [list HOME=$lnL XSCHEM_TEST_HOME=$cL2] refused {}] {
  set e [concat $envl [list TMPDIR=$tL]]
  lassign [kid $e [probe]] trc tout
  lassign [shkid $e] src sout
  set tv [verdict_of $trc $tout $cL2 $tL $cust]
  set sv [verdict_of $src $sout $cL2 $tL $cust]
  if {$tv ne $exp || $sv ne $exp} { lappend l9 "$what: expected $exp, Tcl $tv (rc=$trc), shell $sv (rc=$src)" }
}
check L9-both-helpers-resolve-XSCHEM_TEST_HOME-through-a-symlink \
  [expr {[llength $l9] == 0 && [file isdirectory $twL9]}] \
  "-- disagreements: [expr {[llength $l9] ? [join $l9 {; }] : {none}}]; the linked throwaway survived=[file isdirectory $twL9]"
catch {file delete $lnLt} ; catch {file delete -force $twL9}

## L10 -- D13.7: both sweeps kill a recorded Xvfb only if its HOME is exactly
## the dead home. `.xvfb.pid` is the record both sweeps read.
if {[llength $tclbin]} {
  foreach lang {tcl sh} {
    set tr [mktroot trootL10$lang]
    set dF [file join $tr xschem-test-home.$dpL.Fgn$lang]
    set dE [file join $tr xschem-test-home.$dpL.Ext$lang]
    foreach d [list $dF $dE] { file mkdir $d ; spit [file join $d .owner] "$dpL\n" }
    set pF [exec env HOME=$cL2 [file join $fbin Xvfb] [file join $fbin wait.tcl] &]
    set pE [exec env HOME=$dE [file join $fbin Xvfb] [file join $fbin wait.tcl] &]
    lappend ::started $pF $pE
    spit [file join $dF .xvfb.pid] "$pF\n" ; spit [file join $dE .xvfb.pid] "$pE\n"
    after 200
    backdate $dF 3600 ; backdate $dE 3600
    if {$lang eq {tcl}} { kid [list HOME=$cL2 TMPDIR=$tr] [probe] } else { shkid [list HOME=$cL2 TMPDIR=$tr] }
    for {set i 0} {$i < 30 && [running $pE]} {incr i} { after 100 }
    set k10($lang) [list foreign_alive [running $pF] exact_alive [running $pE]]
    stop_pid $pF ; stop_pid $pE
  }
  check L10-both-sweeps-kill-a-recorded-Xvfb-only-by-its-exact-HOME \
    [expr {$k10(tcl) eq {foreign_alive 1 exact_alive 0} && $k10(sh) eq {foreign_alive 1 exact_alive 0}}] \
    "-- Tcl sweep: $k10(tcl); shell sweep: $k10(sh) (a process named Xvfb whose HOME is another directory must survive; the one whose HOME is exactly the dead home must not)"
} else {
  skip L10-both-sweeps-kill-a-recorded-Xvfb-only-by-its-exact-HOME "no tclsh to stand in for Xvfb"
}

## L11 -- D13.4: the same honest banner from both when TMPDIR is inside the
## real home (the path aside; the streams differ by design).
set cL11 [mkcanary canaryL11 dir:tmp]
set e [list HOME=$cL11 TMPDIR=[file join $cL11 tmp]]
lassign [kid $e [probe]] r11t o11t
lassign [shkid $e] r11s o11s
set b11 {}
foreach o [list $o11t $o11s] {
  set b {}
  foreach l [split $o \n] { if {[regexp {^test home: throwaway (\S+) (.*)$} $l -> _ rest]} { set b $rest } }
  lappend b11 $b
}
check L11-both-helpers-say-the-same-thing-when-TMPDIR-is-inside-the-real-HOME \
  [expr {$r11t == 0 && $r11s == 0 && [lindex $b11 0] ne {} && [lindex $b11 0] eq [lindex $b11 1]
         && ![has_text [lindex $b11 0] {your HOME is untouched}]}] \
  "-- after the path: Tcl `[lindex $b11 0]`, shell `[lindex $b11 1]` (must be equal, and must not claim the HOME is untouched)"

## L12 -- D13.16: ONE snapshot of the tester's environment for a whole tree of
## runs, XSCHEM_TEST_PRE_ENV (base64 of `env -0`, XSCHEM_TEST_* removed), exported
## by the outermost arm of either language and kept by an enclosed one.
##   (a) what a Tcl arm exports, the shell's own decoder (`base64 -d`) reads as
##       the tester's environment;
##   (b) a Tcl run nested in a shell driver starts its long-lived processes from
##       the SHELL's snapshot: the driver unsets a variable of the tester's
##       after arming, and the Tcl child's pre-switch environment still has it --
##       a reconstruction from the current environment cannot.
set tL12 [mktroot trootL12]
lassign [kid [list HOME=$cL2 TMPDIR=$tL12 TESTER_MARK=1] [probe {
  puts "T_PRE=[expr {[info exists ::env(XSCHEM_TEST_PRE_ENV)] ? $::env(XSCHEM_TEST_PRE_ENV) : {}}]"
  set rc [catch {exec bash -c {printf '%s' "$XSCHEM_TEST_PRE_ENV" | base64 -d | tr '\0' '\n' | sed 's/^/D_/'} 2>@1} d]
  puts $d
}]] r12a o12a
set d12 [kv_names $o12a D_ *]
check L12a-a-Tcl-arms-snapshot-decodes-with-the-shells-own-reader-as-the-testers-environment \
  [expr {$r12a == 0 && [kv $o12a T_PRE] ne {} && [kv $o12a D_TESTER_MARK] eq {1} && [kv $o12a D_HOME] eq $cL2
         && [kv_names $o12a D_ XSCHEM_TEST_*] eq {} && [kv $o12a D_GIT_CONFIG_COUNT] eq {<absent>}}] \
  "-- exported=[expr {[kv $o12a T_PRE] ne {}}]; decoded by `base64 -d`: TESTER_MARK=[kv $o12a D_TESTER_MARK] HOME=[kv $o12a D_HOME] (required 1 and $cL2), harness names [list [kv_names $o12a D_ XSCHEM_TEST_*]] GIT_CONFIG_COUNT=[kv $o12a D_GIT_CONFIG_COUNT] (required none: the snapshot is from BEFORE the arm), [llength $d12] names in all"
lassign [shkid [list HOME=$cL2 TMPDIR=$tL12 TESTER_MARK=1] "
unset TESTER_MARK
tclsh [shq $nestT] 2>&1 | sed 's/^/N_/'
"] r12b o12b
check L12b-a-Tcl-run-nested-in-a-shell-driver-starts-long-lived-processes-from-the-shells-snapshot \
  [expr {$r12b == 0 && [kv $o12b N_KIND] eq {throwaway} && [kv $o12b N_P_TESTER_MARK] eq {1} && [kv $o12b N_P_HOME] eq $cL2
         && [kv_names $o12b N_P_ XSCHEM_TEST_*] eq {} && [kv_names $o12b N_P_ GIT_CONFIG_*] eq {}}] \
  "-- the Tcl child (kind=[kv $o12b N_KIND]) would start a long-lived process with TESTER_MARK=[kv $o12b N_P_TESTER_MARK] (required 1: the driver unset it after arming, so only the shell's snapshot has it), HOME=[kv $o12b N_P_HOME], harness names [list [concat [kv_names $o12b N_P_ XSCHEM_TEST_*] [kv_names $o12b N_P_ GIT_CONFIG_*]]] (required none)"

## ---- L10b, L11b, L13, L14: what D13 made common, locked at integration ----
## (S2c-R2-I) Each is a rule both helpers now apply; each was red first on one
## half as the two crews delivered it (the receipt names the sabotage).

## L10b -- D13.7 for the WINDOW MANAGER: `.xvfb/wm.pid`, named by `.xvfb/wm`, is
## the record both sweeps read, and it is killed only when its HOME is exactly
## the dead home -- never a live openbox of someone else's whose pid the record
## happens to name. Row F1c holds the Tcl sweep to it; this hands it to both.
if {[llength $tclbin]} {
  foreach lang {tcl sh} {
    set tr [mktroot trootL10b$lang]
    set dF [file join $tr xschem-test-home.$dpL.WFgn$lang]
    set dE [file join $tr xschem-test-home.$dpL.WExt$lang]
    foreach d [list $dF $dE] { file mkdir [file join $d .xvfb] ; spit [file join $d .owner] "$dpL\n" }
    set wF [exec env HOME=$cL2 [file join $fbin openbox] [file join $fbin wait.tcl] &]
    set wE [exec env HOME=$dE [file join $fbin openbox] [file join $fbin wait.tcl] &]
    lappend ::started $wF $wE
    spit [file join $dF .xvfb wm.pid] "$wF\n" ; spit [file join $dF .xvfb wm] "openbox\n"
    spit [file join $dE .xvfb wm.pid] "$wE\n" ; spit [file join $dE .xvfb wm] "openbox\n"
    after 200
    backdate $dF 3600 ; backdate $dE 3600
    if {$lang eq {tcl}} { kid [list HOME=$cL2 TMPDIR=$tr] [probe] } else { shkid [list HOME=$cL2 TMPDIR=$tr] }
    for {set i 0} {$i < 30 && [running $wE]} {incr i} { after 100 }
    set k10b($lang) [list foreign_alive [running $wF] exact_alive [running $wE] swept [expr {![file exists $dF] && ![file exists $dE]}]]
    stop_pid $wF ; stop_pid $wE
  }
  check L10b-both-sweeps-kill-a-recorded-WM-only-by-its-exact-HOME \
    [expr {$k10b(tcl) eq {foreign_alive 1 exact_alive 0 swept 1} && $k10b(sh) eq {foreign_alive 1 exact_alive 0 swept 1}}] \
    "-- Tcl sweep: $k10b(tcl); shell sweep: $k10b(sh) (an openbox whose HOME is another directory must survive; the one whose HOME is exactly the dead home must not; both dead homes are still swept)"
} else {
  skip L10b-both-sweeps-kill-a-recorded-WM-only-by-its-exact-HOME "no tclsh to stand in for openbox"
}

## L11b -- D13.4's rule for a CUSTOM home: one inside the real home is written
## by the run, so neither helper may say "your HOME is untouched" of it; one
## outside says it in both (the non-vacuity half). Same words, both languages.
set custIn [file join $cL11 mycopy] ; file mkdir $custIn
set b11b {}
foreach cd [list $custIn $custL] {
  set e [list HOME=$cL11 TMPDIR=$tL XSCHEM_TEST_HOME=$cd]
  lassign [kid $e [probe]] rt ot
  lassign [shkid $e] rs os
  foreach o [list $ot $os] {
    set b {}
    foreach l [split $o \n] { if {[regexp {^test home: custom (\S+) (.*)$} $l -> _ rest]} { set b $rest } }
    lappend b11b $b
  }
  lappend b11b $rt $rs
}
lassign $b11b inT inS inRt inRs outT outS outRt outRs
check L11b-a-custom-home-inside-the-real-HOME-is-not-called-untouched-by-either \
  [expr {$inRt == 0 && $inRs == 0 && $outRt == 0 && $outRs == 0 && $inT ne {} && $inT eq $inS && $outT eq $outS
         && ![has_text $inT {your HOME is untouched}] && [has_text $outT {your HOME is untouched}]}] \
  "-- inside the real home: Tcl `$inT`, shell `$inS` (equal, and no claim the HOME is untouched); outside it: Tcl `$outT`, shell `$outS` (equal, and it may say so)"

## L13 -- D13.6 applied to NESTING: a HOME is reused only if its owner is ALIVE
## by the same rule the sweep uses. A live pid recorded under another boot_id,
## or in another pid namespace, is not an owner either helper can see, and the
## sweep may delete that home -- so both arm fresh; our boot, our namespace and
## a live pid is nested in both (the non-vacuity half). The Tcl crew wrote the
## rule (t1_home_live_throwaway); the shell nested on the bare pid until the
## integration aligned it (_th_owner_alive).
set tL13 [mktroot trootL13]
set sl13 [exec sleep 120 &] ; lappend ::started $sl13
set l13 {}
foreach {sfx line exp why} [list \
    NstOb "$sl13 $OTHERBOOT $MYNS"  fresh "a live pid recorded under another boot_id" \
    NstNs "$sl13 $MYBOOT $FOREIGNNS" fresh "a live pid recorded in another pid namespace" \
    NstOk "$sl13 $MYBOOT $MYNS"      same  "our boot, our pid namespace, a live pid"] {
  set h [file join $tL13 xschem-test-home.$sl13.$sfx]
  file mkdir [file join $h .xschem] ; spit [file join $h .owner] "$line\n"
  set e [list HOME=$h XSCHEM_TEST_REAL_HOME=$cL2 TMPDIR=$tL13]
  lassign [kid $e [probe]] trc tout
  lassign [shkid $e] src sout
  set tv [verdict_of $trc $tout $h $tL13 {}]
  set sv [verdict_of $src $sout $h $tL13 {}]
  if {$tv ne $exp || $sv ne $exp} { lappend l13 "$why: expected $exp, Tcl $tv (rc=$trc), shell $sv (rc=$src)" }
}
check L13-both-helpers-nest-only-under-an-owner-alive-by-the-D13.6-rule \
  [expr {[llength $l13] == 0 && [entries $tL13] eq [lsort [list xschem-test-home.$sl13.NstOb xschem-test-home.$sl13.NstNs xschem-test-home.$sl13.NstOk]]}] \
  "-- disagreements: [expr {[llength $l13] ? [join $l13 {; }] : {none}}]; entries left [list [entries $tL13]] (only the three planted homes)"
stop_pid $sl13

## L14 -- ONE reading of `.owner`'s first field: a plain decimal pid, 1-10
## digits, no leading zero. Anything else is not a pid, and both sweeps fall
## back to the pid in the directory's NAME. Read loosely (the shell took any
## digit string), `0<pid>` or an 11-digit field was judged DEAD and the home of
## a live owner swept by one language and kept by the other.
set sl14 [exec sleep 120 &] ; lappend ::started $sl14
set dp14 [dead_pid]
set k14 {}
foreach lang {tcl sh} {
  set tr [mktroot trootL14$lang]
  set dz [file join $tr xschem-test-home.$sl14.Lz$lang]
  set db [file join $tr xschem-test-home.$sl14.Big$lang]
  set dd [file join $tr xschem-test-home.$dp14.Ok$lang]
  foreach {d line} [list $dz "0$sl14 $MYBOOT $MYNS" $db "99999999999 $MYBOOT $MYNS" $dd "$dp14 $MYBOOT $MYNS"] {
    file mkdir $d ; spit [file join $d .owner] "$line\n" ; backdate $d 400
  }
  if {$lang eq {tcl}} { kid [list HOME=$cL2 TMPDIR=$tr] [probe] } else { shkid [list HOME=$cL2 TMPDIR=$tr] }
  lappend k14 $lang [list leadzero_kept [file isdirectory $dz] elevendigit_kept [file isdirectory $db] dead_swept [expr {![file exists $dd]}]]
  catch {file delete -force $dz} ; catch {file delete -force $db}
}
check L14-both-sweeps-read-a-malformed-owner-pid-the-same-way \
  [expr {[dict get $k14 tcl] eq {leadzero_kept 1 elevendigit_kept 1 dead_swept 1}
         && [dict get $k14 sh] eq {leadzero_kept 1 elevendigit_kept 1 dead_swept 1}}] \
  "-- Tcl: [dict get $k14 tcl]; shell: [dict get $k14 sh] (a live owner in the NAME keeps the home when .owner's first field is `0<pid>` or 11 digits; a well-formed dead owner is swept)"
stop_pid $sl14


## ---- L15-L18: round 3 (DECISIONS D17) across the two languages ------------
## Each is red on the round-2 build (the receipt names the sabotage or the
## unfixed half that turns it red).

## Run $body (a probe) in a child of either language STARTED IN $cwd -- the
## only way to measure what a RELATIVE TMPDIR means to the arm.
proc kidin {cwd envl body {tmo 60}} {
  incr ::kidn
  set f [spit [file join $::S kid$::kidn.tcl] $body]
  set rc 0
  if {[catch {exec timeout $tmo env -i PATH=$::PATHV {*}$envl sh -c {cd "$1" && shift && exec "$@"} sh $cwd tclsh $f 2>@1} out opt]} {
    set ec [dict get $opt -errorcode]
    set rc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
  }
  return [list $rc $out]
}
proc shkidin {cwd envl {body {}} {tmo 60}} {
  incr ::kidn
  set f [spit [file join $::S shkid$::kidn.sh] ". [shq $::THSH]
test_home_arm; rc=\$?
\[ \"\$rc\" = 0 \] || exit \"\$rc\"
echo \"HOME=\$HOME\"
echo \"TMPDIR=\${TMPDIR:-}\"
$body
"]
  set rc 0
  if {[catch {exec timeout $tmo env -i PATH=$::PATHV {*}$envl sh -c {cd "$1" && shift && exec "$@"} sh $cwd bash $f 2>@1} out opt]} {
    set ec [dict get $opt -errorcode]
    set rc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
  }
  return [list $rc $out]
}

## L15 -- D17.5: a custom home whose .xschem -- or an entry directly in it --
## resolves into the real HOME is REFUSED by both helpers: that is where xschem
## writes, and the round-2 safety refuter measured the real clipboard
## overwritten (103 -> 198 B) under a banner that said "your HOME is untouched".
## The non-vacuity halves stay custom in both: a .xschem linked OUTSIDE the
## real home, and a custom dir INSIDE the real home with its own .xschem (the
## L11b case, whose banner says it writes there).
set cL15 [mkcanary canaryL15]
set tL15 [mktroot trootL15]
set elsewhere [file join $S elsewhereL15] ; file mkdir [file join $elsewhere .xschem]
set cu {}
foreach {tag how} {a link b sub c dangle d out e inreal f inreal_link} {
  if {$tag in {e f}} { set d [file join $cL15 mycopy$tag] } else { set d [file join $S custL15$tag] }
  file mkdir $d
  switch $how {
    link        { file link -symbolic [file join $d .xschem] [file join $cL15 .xschem] }
    sub         { file mkdir [file join $d .xschem] ; file link -symbolic [file join $d .xschem simulations] [file join $cL15 .xschem simulations] }
    dangle      { exec ln -s [file join $cL15 not_yet .xschem] [file join $d .xschem] }
    out         { file link -symbolic [file join $d .xschem] [file join $elsewhere .xschem] }
    inreal      { file mkdir [file join $d .xschem] }
    inreal_link { file link -symbolic [file join $d .xschem] [file join $cL15 .xschem] }
  }
  lappend cu $tag $d
}
set sL15 [snap $cL15]
set l15 {}
foreach {tag exp why} {a refused "a .xschem that is a symlink to the real ~/.xschem"
                       b refused "a .xschem/simulations that is a symlink into the real ~/.xschem"
                       c refused "a DANGLING .xschem symlink into the real home"
                       d custom  "a .xschem linked OUTSIDE the real home (non-vacuity)"
                       e custom  "a custom dir inside the real home with its own .xschem (non-vacuity; L11b)"
                       f refused "a custom dir inside the real home whose .xschem links to the real ~/.xschem"} {
  set d [dict get $cu $tag]
  set e [list HOME=$cL15 TMPDIR=$tL15 XSCHEM_TEST_HOME=$d]
  lassign [kid $e [probe]] trc tout
  lassign [shkid $e] src sout
  set tv [verdict_of $trc $tout $cL15 $tL15 $d]
  set sv [verdict_of $src $sout $cL15 $tL15 $d]
  if {$tv ne $exp || $sv ne $exp} { lappend l15 "$why: expected $exp, Tcl $tv (rc=$trc), shell $sv (rc=$src)" }
}
check L15-a-custom-home-whose-.xschem-resolves-into-the-real-HOME-is-refused-by-both \
  [expr {[llength $l15] == 0 && [snap $cL15] eq $sL15 && [entries $tL15] eq {}}] \
  "-- disagreements: [expr {[llength $l15] ? [join $l15 {; }] : {none}}]; the real home byte-identical=[expr {[snap $cL15] eq $sL15}]; TMPDIR left [list [entries $tL15]]"

## L16 -- D17.4: nesting requires HOME DIRECTLY UNDER THE TEMP ROOT, in both.
## The round-2 safety refuter's forgery: a throwaway-shaped directory planted
## inside the real home, `.owner` naming a live pid, XSCHEM_TEST_REAL_HOME set --
## both helpers took it as nested and used a directory INSIDE THE REAL HOME as
## HOME. Now both arm fresh and leave it alone; the same home planted under
## TMPDIR is still nested (the non-vacuity half; L13 holds the owner rule).
set cL16 [mkcanary canaryL16]
set tL16 [mktroot trootL16]
set sl16 [exec sleep 120 &] ; lappend ::started $sl16
set forged [file join $cL16 xschem-test-home.$sl16.Forged]
set legit  [file join $tL16 xschem-test-home.$sl16.Legit1]
foreach h [list $forged $legit] { file mkdir [file join $h .xschem] ; spit [file join $h .owner] "$sl16 $MYBOOT $MYNS\n" }
set l16 {}
foreach {h exp why} [list $forged fresh "a live-owned throwaway-shaped HOME inside the real home (forged)" \
                          $legit  same  "the same, directly under TMPDIR (nested)"] {
  set e [list HOME=$h XSCHEM_TEST_REAL_HOME=$cL16 TMPDIR=$tL16]
  lassign [kid $e [probe]] trc tout
  lassign [shkid $e] src sout
  set tv [verdict_of $trc $tout $h $tL16 {}]
  set sv [verdict_of $src $sout $h $tL16 {}]
  if {$tv ne $exp || $sv ne $exp} { lappend l16 "$why: expected $exp, Tcl $tv (rc=$trc), shell $sv (rc=$src)" }
}
check L16-both-helpers-nest-only-in-a-HOME-directly-under-the-temp-root \
  [expr {[llength $l16] == 0 && [file isdirectory $forged] && [entries $tL16] eq [list [file tail $legit]]}] \
  "-- disagreements: [expr {[llength $l16] ? [join $l16 {; }] : {none}}]; the forged home left alone=[file isdirectory $forged]; TMPDIR left [list [entries $tL16]] (only the planted legit home)"
stop_pid $sl16

## L17 -- D17.3: a RELATIVE TMPDIR is resolved against the arming process's
## cwd and EXPORTED ABSOLUTE by both, so every child -- and a driver that then
## changes directory, as run_suites.sh does -- names the same directory. The
## round-2 safety refuter measured the shell exporting a relative HOME, the run
## dying after its cd, and the throwaway left in the caller's cwd.
set w17 [file join $S cwdL17] ; file mkdir [file join $w17 reltmp]
set cL17 [mkcanary canaryL17]
set e [list HOME=$cL17 TMPDIR=reltmp]
lassign [kidin $w17 $e [probe {puts "TMPDIR=$::env(TMPDIR)"}]] r17t o17t
lassign [shkidin $w17 $e {cd / ; echo "AFTERCD=$([ -d "$HOME/.xschem" ] && echo 1 || echo 0)"}] r17s o17s
set want17 [file join $w17 reltmp]
check L17-both-helpers-export-a-relative-TMPDIR-absolute-and-make-the-home-under-it \
  [expr {$r17t == 0 && $r17s == 0 && [kv $o17t TMPDIR] eq $want17 && [kv $o17s TMPDIR] eq $want17
         && [file dirname [kv $o17t HOME]] eq $want17 && [file dirname [kv $o17s HOME]] eq $want17
         && [kv $o17s AFTERCD] eq {1} && [entries [file join $w17 reltmp]] eq {} && [entries $w17] eq {reltmp}}] \
  "-- TMPDIR=reltmp from $w17: Tcl exported TMPDIR=[kv $o17t TMPDIR] HOME=[kv $o17t HOME]; shell TMPDIR=[kv $o17s TMPDIR] HOME=[kv $o17s HOME], its HOME still valid after `cd /`=[kv $o17s AFTERCD]; left in the cwd: [list [entries $w17]] / [list [entries [file join $w17 reltmp]]] (required: reltmp, empty)"

## L18 -- D17.9: a NESTED arm says nothing in either language -- the arm that
## made the home already said where it is. The shell used to repeat its
## banner, so `owed.sh drain`, which arms around a shell suite that arms again,
## printed it twice.
set tL18 [mktroot trootL18]
set sl18 [exec sleep 120 &] ; lappend ::started $sl18
set h18 [file join $tL18 xschem-test-home.$sl18.NestQ1]
file mkdir [file join $h18 .xschem] ; spit [file join $h18 .owner] "$sl18 $MYBOOT $MYNS\n"
set e [list HOME=$h18 XSCHEM_TEST_REAL_HOME=$cL2 TMPDIR=$tL18]
lassign [kid $e [probe]] r18t o18t
lassign [shkid $e] r18s o18s
check L18-a-nested-arm-prints-no-banner-in-either-language \
  [expr {$r18t == 0 && $r18s == 0 && [kv $o18t HOME] eq $h18 && [kv $o18s HOME] eq $h18
         && [count_lines $o18t {test home:}] == 0 && [count_lines $o18s {test home:}] == 0}] \
  "-- nested in $h18: Tcl printed [count_lines $o18t {test home:}] `test home:` line(s), the shell [count_lines $o18s {test home:}] (both must print none)"
stop_pid $sl18

cleanup_started
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
