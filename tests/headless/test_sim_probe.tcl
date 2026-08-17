# test_sim_probe.tcl — THE CAPABILITY PROBE AND THE RUN PROBE, and the hard
# timeout that is mandatory for both. Casemode batch item 7; PLAN.md section 3b
# item 7; DECISIONS.md B3 (the two probes + "the probe needs a hard timeout"),
# A1 (offer only what the binary can deliver) and A2 (`.spiceinit` overrides, so
# ask the simulator rather than guessing). Spec:
# doc/claude/specs/simulator_profiles.md section 11.
#
# WHAT THIS ITEM IS. Item 6 built the profile MODEL — `exe`, `args`, `casemode`
# (requested) and `detected`/`probed` (measured) — and started no process. This
# item starts the process, and it is TWO questions with one mechanism:
#
#   capability probe  at registration, in an EMPTY directory, no deck exists yet
#                     -> RECORDS `detected`/`probed`, which is what item 13's
#                        dropdown is built from
#   run probe         immediately before a run, from the DECK'S OWN DIRECTORY,
#                     with the run's own argv -> RECORDS NOTHING
#
# THE LOAD-BEARING CHECKS, and why:
#   CS167   THE PARSING TRAP. ngspice ECHOES the command before answering it, so
#           the output carries a literal `echo CCM=$curcasemode` line and a
#           parser that takes "the first line containing CCM=" reads back
#           `$curcasemode` instead of a mode. One assertion carries both halves.
#   CS169b  THE HARD TIMEOUT, driven by actually hanging it. A timeout with no
#           test that it fires is not evidence (B3; the first probe of this
#           feature hung for two minutes). It asserts the deadline fired, the
#           call returned inside it, and the child is GONE.
#   CS169h  WHY EACH MODE IS PROBED SEPARATELY rather than inferred from the
#           presence of `$curcasemode`: a binary that ACCEPTS `-D casemode=` and
#           silently delivers `fold` must be measured as fold-only, or A1's rule
#           ("nobody may select a mode their simulator will silently ignore") is
#           broken by exactly the shape item 3 measured for a wrong-case KEY.
#   CS169g  A1's other half: a binary with NO casemode support answers
#           `Error: curcasemode: no such variable.` + an empty `CCM=`, and that
#           IS the capability answer — recorded as `detected {fold}`, so the
#           ordinary `apt install` user is offered `fold` and nothing else.
#   CS169j  A TIMED-OUT LEG NEVER CONTRIBUTES A MODE even when it parsed one.
#           The stand-in answers, then hangs. CS170f hangs a REAL ngspice (a
#           `.control` blocked in `shell sleep`) and shows the other half: a
#           batch simulator killed mid-run has flushed nothing at all.
#   CS170n  THE PROBE MUST NOT NEED AN X SERVER. `ngspice -p` opens $DISPLAY and
#           this item's first transport did too — until a WSLg :0 ran out of
#           client slots mid-item and every real-binary check reported "unknown"
#           for a binary that supports all three modes. With DISPLAY unset the
#           same command DUMPS CORE. The transport is a batch deck now.
#   CS170c  A2, measured end to end: a `.spiceinit` beside the deck beats
#           `-D casemode=preserve`, which is why the run probe exists and why
#           "look for a .spiceinit next to the deck" is not a substitute.
#   CS170e  the `~/.spiceinit` layer, driven with HOME pointed at a scratch dir
#           (MEASURED: ngspice honours HOME), so the developer's own home
#           directory is never written to. Its CONTROL probe -- the same command
#           with the real HOME -- is what would notice a missed restore; the old
#           `home_restored=` term re-read the test's own assignment two lines
#           earlier and could not fail, so it is gone (same for CS170n's
#           `display_restored=`).
#
# THE SECTION-C2 CHECKS ARE THE REVIEW ROUND'S, and they exist because the first
# cut's evidence had holes that a machine without ver_50 could not see:
#   CS173d/e THE PER-MODE SWEEP ITSELF, with no simulator. CS169h's stand-in
#           answers `fold` whatever it is asked, so it cannot tell "ask each
#           mode" from "ask ONE mode three times" -- the rejected design passed
#           the whole suite on the skip arm. These two read `-D casemode=<m>`
#           back out of their own argv.
#   CS173f  ONE STALLED LEG INVALIDATES THE WHOLE MEASUREMENT. Recording only
#           the legs that answered narrowed a row PERMANENTLY (and, with `fold`
#           the stalling leg, claimed the global default was undeliverable) --
#           worse than never probing, since a recorded row is not stale.
#   CS173g  THE TIMEOUT IS A BUDGET FOR THE WHOLE PROBE. Three legs against one
#           deadline each blocked the interpreter for 3x the timeout -- 15 s at
#           the shipped default, in the dialog B3's timeout exists to protect.
#   CS173i / CS174 A PROBE MAY NOT WRITE IN THE DIRECTORY IT ASKS ABOUT: a
#           profile carrying `-r <raw> -o <log>` made the run probe overwrite
#           the user's previous run outputs -- and lose its own answer into the
#           log it had just created.
#   CS173k  `no such variable` IS A MEASURED DELIVERY OF `fold`. The run probe
#           used to call it "nothing measured" for the one mismatch B4 REFUSES.
#
# ver_50 IS A PRIVATE BUILD AND IT KEEPS MOVING (three times in four days). Every
# leg that needs it SKIPS rather than fails when it is absent, and prints a
# `note:` line — never a column-0 skip banner, which full_audit.sh would score as
# a skip for the WHOLE FILE, silently discarding every check that did run.
#
# Run TRUE HEADLESS from the repo root (needs no display):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_sim_probe.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}
# every call goes through this: a proc that does not exist yet must FAIL a
# check, never abort the file with no RESULT line
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
proc raises {args} {
  return [expr {[catch {uplevel 1 $args}] ? 1 : 0}]
}
# dict read that cannot abort the file (pcall returns a non-dict string when the
# proc under test is missing)
# `dict keys` on a non-dict RAISES, which would abort the file with no RESULT
# line -- measured: the master red died at CS169g's `legs=` term. Same reason as
# `dg` and as item 6's CS163k abort-proofing.
proc dkeys {d} {
  if {[catch {dict keys $d} v]} { return {} }
  return $v
}
proc dg {d k} {
  if {[catch {dict get $d $k} v]} { return "NO:$k" }
  return $v
}
proc alive {pid} {
  if {![string is integer -strict $pid]} { return unknown }
  if {[catch {exec kill -0 $pid}]} { return dead }
  return alive
}
# write an executable stand-in simulator
proc fake {dir name body} {
  set p [file join $dir $name]
  set f [open $p w]
  puts $f "#!/bin/sh"
  puts $f $body
  close $f
  file attributes $p -permissions 0755
  return $p
}
proc putfile {p txt} {
  set f [open $p w] ; puts -nonewline $f $txt ; close $f
}
proc readfile {p} {
  if {[catch {open $p r} f]} { return "NOFILE" }
  set t [read $f] ; close $f ; return [string map {\n \\n} $t]
}
# ABORT-PROOFING (the LEDGER carry-forward from items 1, 2, 5b and 6): a bare
# [pargv ...] inside a command substitution raises when the proc has
# been sabotaged away, which ends the file with NO RESULT line -- under which
# every sabotage reads as "nothing went red". CS168..CS168d test that proc
# directly; everything below goes through this stub instead.
proc pargv {arglist mode nsi} {
  if {[catch {sim_probe_argv $arglist $mode $nsi} r]} { return [list -b] }
  return $r
}

set here [file normalize [file dirname [info script]]]
set tmp  [test_scratch simprobe]
# THE cwd BASELINE, captured before any probe runs. It must NOT be re-taken just
# before the probe under test: [pwd] is process-global, so a probe that leaked
# the cwd would simply move the baseline with it and the check would pass --
# measured, mutation M15 (the restore after `open` deleted) left the suite fully
# green until this was hoisted.
set cwd_at_start [pwd]

# an isolated USER_CONF_DIR: nothing here may touch the developer's ~/.xschem
set ::USER_CONF_DIR [file join $tmp conf]
file mkdir $::USER_CONF_DIR

# the case-capable build and the released one. Overridable, because the private
# build's path is a developer's, not a fact about the repo.
set NG50 {}
if {[info exists ::env(NGSPICE_CASE_TEST)]} {
  set cand $::env(NGSPICE_CASE_TEST)
} else {
  set cand /home/qflow/dev/ngspice_test/build-ver_50/src/ngspice
}
if {[file executable $cand]} { set NG50 $cand }
set NGSTOCK {}
foreach c {/usr/local/bin/ngspice /usr/bin/ngspice} {
  if {[file executable $c]} { set NGSTOCK $c ; break }
}
puts "note: case-capable ngspice = '$NG50'   released ngspice = '$NGSTOCK'"

# a private sim() configuration; nothing below reads or writes the user's simrc
proc reset_sim {} {
  if {[info exists ::sim]} { unset ::sim }
  set_sim_defaults
}
# append a configured row and return its index
proc add_row {tool name exe {args_ {}} {casemode {}} {nsi 0}} {
  set i $::sim($tool,n)
  set ::sim($tool,$i,cmd)  "$exe \"\$N\""
  set ::sim($tool,$i,name) $name
  set ::sim($tool,$i,exe)  $exe
  incr ::sim($tool,n)
  set_sim_defaults
  if {$args_ ne {}}    { sim_profile_set $tool $i args $args_ }
  if {$casemode ne {}} { sim_profile_set $tool $i casemode $casemode }
  if {$nsi}            { sim_profile_set $tool $i nospiceinit 1 }
  return $i
}

# ===========================================================================
# A — the parse. THE ECHO IS THE TRAP.
# ===========================================================================
# Verbatim shapes, captured from the two binaries on 2026-08-17.
set out_ver50 "echo CCM=\$curcasemode\nCCM=fold\nngspice 10002 -> quit\nngspice-46+ done\n"
set out_stock "echo CCM=\$curcasemode\nError: curcasemode: no such variable.\nCCM=\nngspice 10002 -> quit\nngspice-46 done\n"
set out_dist  "Warning: casemode 'distinguish' is experimental. Identifier identity is case sensitive.\necho CCM=\$curcasemode\nCCM=distinguish\nngspice 10002 -> quit\nngspice-46+ done\n"

set p [pcall sim_probe_parse $out_ver50]
# ONE assertion, two facts: the real answer is read AND the echoed command is
# not. Take away the anchor and `value` reads back `$curcasemode`.
eqcheck CS167-echoed-command-is-not-the-answer \
  "answered=[dg $p answered] mode=[dg $p mode] value=[dg $p value] nocm=[dg $p nocasemode]" \
  {answered=1 mode=fold value=fold nocm=0}
# the echo line ALONE must answer nothing at all
set p [pcall sim_probe_parse "echo CCM=\$curcasemode\n"]
eqcheck CS167b-echo-line-alone-answers-nothing \
  "answered=[dg $p answered] mode=[dg $p mode]" {answered=0 mode=}
# a prompt may precede the line
set p [pcall sim_probe_parse "ngspice 10002 -> CCM=preserve\n"]
eqcheck CS167c-prompt-prefixed-answer-is-read \
  "answered=[dg $p answered] mode=[dg $p mode]" {answered=1 mode=preserve}
# THE RELEASED BINARY'S ANSWER: empty value + the error line = "no casemode"
set p [pcall sim_probe_parse $out_stock]
eqcheck CS167d-stock-shape-is-a-no-casemode-ANSWER \
  "answered=[dg $p answered] value=<[dg $p value]> mode=<[dg $p mode]> nocm=[dg $p nocasemode]" \
  {answered=1 value=<> mode=<> nocm=1}
# BOTH halves are required: an empty value with no error line is not a claim
set p [pcall sim_probe_parse "CCM=\n"]
eqcheck CS167e-empty-value-without-the-error-line-claims-nothing \
  "answered=[dg $p answered] nocm=[dg $p nocasemode]" {answered=1 nocm=0}
# a value that is not one of the three modes: answered, but no mode
set p [pcall sim_probe_parse "CCM=sideways\n"]
eqcheck CS167f-unknown-mode-word-is-answered-but-not-a-mode \
  "answered=[dg $p answered] value=[dg $p value] mode=<[dg $p mode]>" \
  {answered=1 value=sideways mode=<>}
# the distinguish banner does not disturb it
set p [pcall sim_probe_parse $out_dist]
eqcheck CS167g-experimental-banner-does-not-disturb-the-parse [dg $p mode] distinguish
# a trailing CR (a pipe from a Windows-built binary) is trimmed
set p [pcall sim_probe_parse "CCM=preserve\r\n"]
eqcheck CS167h-trailing-CR-is-trimmed [dg $p mode] preserve

# ===========================================================================
# B — the argv, and the timeout resolution
# ===========================================================================
eqcheck CS168-argv-asks-for-the-mode-in-BATCH-mode \
  [pcall sim_probe_argv {} fold 0] {-b -D casemode=fold}
eqcheck CS168b-argv-carries-profile-args-then-A2s--n \
  [pcall sim_probe_argv {--foo bar} preserve 1] {-b --foo bar -n -D casemode=preserve}
# mode {} = "ask for nothing", which is how the binary's DEFAULT is measured
eqcheck CS168c-no-mode-means-no--D-flag [pcall sim_probe_argv {} {} 0] {-b}
eqcheck CS168d-nospiceinit-0-adds-no--n [pcall sim_probe_argv {} fold 0] {-b -D casemode=fold}
# THE PROFILE'S `args` ARE SPLICED INTO TCL EXEC SYNTAX, so a word that exec
# reads as a REDIRECTION never reaches the simulator -- it redirects the probe
# instead. Measured before the filter: `args {> zap.txt}` created `zap.txt` in
# the probe's cwd (the user's own rundir, for a run probe) and returned
# `status error`; `args {| cat}` swallowed the answer, which the capability probe
# then recorded as "measured, delivers nothing" -- item 13's dropdown offering no
# mode at all. `sim_profile_valid` cannot refuse these: any well-formed Tcl list
# is a valid `args`. A bare operator takes its file with it; a pipeline
# separator ends the words that belong to this command.
eqcheck CS173-exec-redirection-words-never-reach-the-probe-argv \
  [pcall sim_probe_argv {--keep 1 > zap.txt 2>/dev/null >>also.txt | cat -A} fold 0] \
  {-b --keep 1 -D casemode=fold}
# AND THE OUTPUT-DIRECTING OPTIONS, which is the same defect with the simulator
# doing the writing: `-r <raw>`/`-o <log>` is the shape of an ordinary batch
# profile, and the run probe runs in the DECK'S directory -- measured, the probe
# overwrote the previous run's `tb.log` with its own probe log and then answered
# `mode {}`, because its stdout had gone into that file.
eqcheck CS173b-output-directing-args-never-reach-the-probe-argv \
  [pcall sim_probe_argv {-r tb.raw -o tb.log --rawfile x.raw --output=y.log -m mod.osdi} preserve 0] \
  {-b -m mod.osdi -D casemode=preserve}
set saved_tmo {}
if {[info exists ::sim_probe_timeout]} { set saved_tmo $::sim_probe_timeout }
set ::sim_probe_timeout 1234
eqcheck CS168e-timeout-explicit-beats-global-beats-builtin \
  "explicit=[pcall sim_probe_timeout_ms 77] global=[pcall sim_probe_timeout_ms {}]\
 garbage=[pcall sim_probe_timeout_ms zzz]" {explicit=77 global=1234 garbage=1234}
unset ::sim_probe_timeout
eqcheck CS168f-timeout-falls-back-to-5000-with-no-global [pcall sim_probe_timeout_ms {}] 5000
if {$saved_tmo ne {}} { set ::sim_probe_timeout $saved_tmo }

# ===========================================================================
# C — the mechanism, against stand-in executables (needs no simulator at all)
# ===========================================================================
set fdir [file join $tmp fakes]
file mkdir $fdir
set f_answer [fake $fdir answer_preserve "echo 'echo CCM=\$curcasemode'\necho CCM=preserve"]
set f_fold   [fake $fdir always_fold     "echo 'echo CCM=\$curcasemode'\necho CCM=fold"]
set f_stock  [fake $fdir stock_shape \
  "echo 'echo CCM=\$curcasemode'\necho 'Error: curcasemode: no such variable.'\necho 'CCM='"]
set f_garb   [fake $fdir garbage_mode    "echo CCM=sideways"]
set f_silent [fake $fdir silent          "exit 0"]
# THE HANGING STAND-INS `exec` THEIR BLOCKER, and that is not cosmetic: the probe
# kills the process it started (a DECLARED limit -- the kill does not reach
# grandchildren), so a wrapper that merely *runs* `sleep 120` leaves the sleep
# reparented to init for two minutes. MEASURED: every run of this suite orphaned
# 8 such processes, and this batch has already had two audits invalidated by
# orphaned probe children. With `exec`, the pid the probe kills IS the blocker.
set f_hang   [fake $fdir answer_then_hang "echo CCM=preserve\nexec sleep 120"]
set f_mute   [fake $fdir mute_hang        "exec sleep 120"]
# THE STAND-INS THAT MAKE THE PER-MODE SWEEP DRIVABLE WITH NO SIMULATOR PRESENT.
# `always_fold` above cannot tell "ask each mode" from "ask one mode three
# times" -- it answers `fold` whatever it is asked -- so the item's headline
# ruling (probe EACH mode) was pinned only by the ver_50 legs, which SKIP on any
# machine without that private build. These two read the request back out of
# their own argv.
set f_echo   [fake $fdir echo_back {m=fold
for a in "$@"; do case "$a" in casemode=*) m=${a#casemode=};; esac; done
echo CCM=$m}]
# honours `preserve`, silently gives `fold` for `distinguish` -- a partial
# implementation, which is the shape A1 is about
set f_subset [fake $fdir honours_subset {m=fold
for a in "$@"; do case "$a" in casemode=*) m=${a#casemode=};; esac; done
if [ "$m" = distinguish ]; then m=fold; fi
echo CCM=$m}]
# answers two modes and STALLS on the third: the mixed-leg case
set f_mixed  [fake $fdir stalls_on_distinguish {m=fold
for a in "$@"; do case "$a" in casemode=*) m=${a#casemode=};; esac; done
if [ "$m" = distinguish ]; then exec sleep 120; fi
echo CCM=$m}]
# answers one mode when it can READ the deck it was handed, another when it
# cannot -- which is how a relative deck path is caught
set f_deck   [fake $fdir reports_deck_readable {last=
for a in "$@"; do last=$a; done
if [ -r "$last" ]; then echo CCM=preserve; else echo CCM=fold; fi}]
# obeys `-o <file>` the way ngspice does: it WRITES it
set f_clob   [fake $fdir writes_its_o_file {out=; prev=
for a in "$@"; do
  if [ "$prev" = -o ]; then out=$a; fi
  prev=$a
done
if [ -n "$out" ]; then echo CLOBBERED > "$out"; fi
echo CCM=preserve}]
# answers by what is in its CWD, so `-cwd` can be shown to do something
set f_mark   [fake $fdir answers_by_cwd {if [ -f ./MARKER ]; then echo CCM=preserve; else echo CCM=fold; fi}]

set r [pcall sim_probe_once $f_answer [pargv {} preserve 0] $tmp 4000]
eqcheck CS169-a-well-behaved-exe-answers-and-exits \
  "status=[dg $r status] mode=[dg $r mode] fast=[expr {[dg $r ms] < 3000}]" \
  {status=ok mode=preserve fast=1}

# THE HARD TIMEOUT (B3), driven by actually hanging it.
set t0 [clock milliseconds]
set r [pcall sim_probe_once $f_mute [pargv {} fold 0] $tmp 700]
set el [expr {[clock milliseconds] - $t0}]
after 200
eqcheck CS169b-hard-timeout-fires-returns-and-kills-the-child \
  "status=[dg $r status] fired=[expr {$el >= 700}] bounded=[expr {$el < 4000}]\
 child=[alive [lindex [dg $r pids] 0]]" \
  {status=timeout fired=1 bounded=1 child=dead}
# and the interpreter is unharmed: the probe runs the child in ITS cwd, never
# by leaving this process sitting in it ([pwd] is process-global state, and the
# GUI writes files relative to it)
eqcheck CS169c-the-probe-restores-this-processs-cwd \
  "cwd_intact=[expr {[pwd] eq $cwd_at_start}] probe_cwd=[expr {[dg $r cwd] eq $tmp}]" \
  {cwd_intact=1 probe_cwd=1}
# no such executable / unreachable cwd: `error`, not a hang, not a claim
set r [pcall sim_probe_once [file join $fdir no_such_exe] {-b} $tmp 700]
eqcheck CS169d-a-missing-exe-is-an-error-not-an-answer \
  "status=[dg $r status] answered=[dg $r answered]" {status=error answered=0}
set r [pcall sim_probe_once $f_answer {-b} [file join $tmp no_such_dir] 700]
eqcheck CS169e-a-bad-cwd-is-an-error-and-the-cwd-is-restored \
  "status=[dg $r status] cwd_intact=[expr {[pwd] eq $cwd_at_start}]" {status=error cwd_intact=1}

# --- the capability probe over those stand-ins ---
reset_sim
set i_silent [add_row spice {fake silent}  $f_silent]
set i_stock  [add_row spice {fake stock}   $f_stock]
set i_fold   [add_row spice {fake fold}    $f_fold]
set i_garb   [add_row spice {fake garbage} $f_garb]
set i_hang   [add_row spice {fake hang}    $f_hang]

# it ran and never answered: unknown, and NOTHING is recorded (B2b)
set r [pcall sim_profile_probe_capability spice $i_silent -timeout 1500]
eqcheck CS169f-a-silent-binary-is-unknown-and-records-nothing \
  "status=[dg $r status] detected=<[dg $r detected]> recorded=[dg $r recorded]\
 probed=<[pcall sim_profile_get spice $i_silent probed]>\
 selectable=[pcall sim_profile_selectable spice $i_silent]" \
  {status=unknown detected=<> recorded=0 probed=<> selectable=fold}

# A1's "no case support => pre-fill fold and offer nothing else", and the
# short circuit: one leg settles it, so only ONE leg was run.
set r [pcall sim_profile_probe_capability spice $i_stock -timeout 1500]
eqcheck CS169g-no-casemode-support-is-an-ANSWER-recorded-as-fold \
  "status=[dg $r status] detected=<[dg $r detected]> recorded=[dg $r recorded]\
 legs=[llength [dkeys [dg $r legs]]]\
 supports_fold=[pcall sim_profile_supports spice $i_stock fold]\
 selectable=[pcall sim_profile_selectable spice $i_stock]\
 stale=[pcall sim_profile_probe_stale spice $i_stock]" \
  {status=nocasemode detected=<fold> recorded=1 legs=1 supports_fold=1 selectable=fold stale=0}

# THE REASON EACH MODE IS PROBED SEPARATELY: this binary accepts every
# `-D casemode=` and delivers `fold` regardless — exactly the silent-ignore shape
# item 3 measured for a wrong-case KEY. Presence-implies-support would have
# offered all three.
set r [pcall sim_profile_probe_capability spice $i_fold -timeout 1500]
eqcheck CS169h-a-silently-ignored-request-is-measured-as-fold-only \
  "status=[dg $r status] detected=<[dg $r detected]> legs=[llength [dkeys [dg $r legs]]]\
 supports_preserve=[pcall sim_profile_supports spice $i_fold preserve]\
 selectable=[pcall sim_profile_selectable spice $i_fold]" \
  {status=ok detected=<fold> legs=3 supports_preserve=0 selectable=fold}

# measured, and it delivers nothing we recognise: spec section 4's third row.
# `probed` is set, `detected` is empty, and the dropdown offers NOTHING.
set r [pcall sim_profile_probe_capability spice $i_garb -timeout 1500]
eqcheck CS169i-a-measured-binary-that-delivers-no-known-mode-offers-nothing \
  "status=[dg $r status] detected=<[dg $r detected]> recorded=[dg $r recorded]\
 probed_set=[expr {[pcall sim_profile_get spice $i_garb probed] ne {}}]\
 selectable=<[pcall sim_profile_selectable spice $i_garb]>" \
  {status=ok detected=<> recorded=1 probed_set=1 selectable=<>}

# A TIMED-OUT LEG NEVER CONTRIBUTES A MODE, even though it parsed one.
set r [pcall sim_profile_probe_capability spice $i_hang -timeout 700]
eqcheck CS169j-a-timed-out-leg-parses-a-mode-and-still-records-nothing \
  "status=[dg $r status] leg_mode=[dg [dg [dg $r legs] fold] mode] detected=<[dg $r detected]>\
 recorded=[dg $r recorded] probed=<[pcall sim_profile_get spice $i_hang probed]>\
 selectable=[pcall sim_profile_selectable spice $i_hang]" \
  {status=timeout leg_mode=preserve detected=<> recorded=0 probed=<> selectable=fold}

# B3's auto-probe gate: an ngspice-named executable only.
set i_xyce [add_row spice {fake xyce} [file join $fdir Xyce]]
eqcheck CS169k-autoprobe-only-for-ngspice-named-executables \
  "ng=[pcall sim_profile_probe_autoprobe_ok spice $i_fold]\
 stock=[pcall sim_profile_probe_autoprobe_ok spice $i_stock]\
 xyce=[pcall sim_profile_probe_autoprobe_ok spice $i_xyce]\
 builtin_noexe=[pcall sim_profile_probe_autoprobe_ok spice 0]" \
  {ng=0 stock=0 xyce=0 builtin_noexe=0}
set i_ngname [add_row spice {ngspice-named} [file join $fdir ngspice]]
set i_NGname [add_row spice {NGSPICE-named} [file join $fdir bin NGspice-46]]
# the third row is the one that says FILENAME rather than path: it lives in a
# directory called `ngspice_builds` and is called `Xyce`, so a gate that matched
# the whole path would auto-launch a licensed simulator -- which is the exact
# outcome B3's name gate exists to prevent.
set i_ngdir [add_row spice {xyce under an ngspice dir} [file join $fdir ngspice_builds Xyce]]
eqcheck CS169k2-the-name-gate-is-case-insensitive-and-reads-the-FILENAME \
  "lower=[pcall sim_profile_probe_autoprobe_ok spice $i_ngname]\
 upper=[pcall sim_profile_probe_autoprobe_ok spice $i_NGname]\
 ngspice_dir=[pcall sim_profile_probe_autoprobe_ok spice $i_ngdir]" \
  {lower=1 upper=1 ngspice_dir=0}

# the probe's own scratch directory is not a leak
set r [pcall sim_profile_probe_capability spice $i_stock -timeout 1500]
# The `ran=` term is what keeps this one honest: without it, a probe proc that
# does not exist at all returns a non-dict, `dg` answers `NO:cwd`, and both
# halves read as "a directory was made and cleaned up" (measured -- this check
# was one of exactly two survivors of the master red before the term was added).
eqcheck CS169l-the-capability-probe-removes-its-own-temp-dir \
  "ran=[dg $r status] abs=[file pathtype [dg $r cwd]] left=[file exists [dg $r cwd]]" \
  {ran=nocasemode abs=absolute left=0}
# BOTH DIRECTIONS in one expectation: a refuse-everything option parser would
# otherwise pass this, and so would a proc that does not exist (the master red's
# other survivor).
eqcheck CS169m-an-unknown-option-is-refused-and-a-known-one-is-not \
  "good=[raises sim_profile_probe_capability spice $i_stock -timeout 1500]\
 bad=[raises sim_profile_probe_capability spice $i_stock -nosuchopt 1]" {good=0 bad=1}
# a row with no exe cannot be probed, and says so rather than probing something
eqcheck CS169n-a-row-with-no-exe-is-an-error-not-a-guess \
  "status=[dg [pcall sim_profile_probe_once spice 0 fold $tmp 700] status]\
 cap=[dg [pcall sim_profile_probe_capability spice 0 -timeout 700] status]" \
  {status=error cap=error}
# THE PROBE LEAVES NOTHING IN THE DIRECTORY IT ASKS ABOUT. `cwd` is the user's
# own rundir for a run probe; the deck belongs in a temp directory of the
# probe's own, and both it and that directory go away afterwards.
set probecwd [file join $tmp probe_cwd]
file mkdir $probecwd
set before [lsort [glob -nocomplain -tails -directory $probecwd *]]
set r [pcall sim_probe_once $f_answer [pargv {} preserve 0] $probecwd 1500]
eqcheck CS169p-the-probe-drops-no-deck-in-the-directory-it-asks-about \
  "status=[dg $r status] left=<[lsort [glob -nocomplain -tails -directory $probecwd *]]>\
 deckgone=[file exists [lindex [dg $r argv] end]]" \
  {status=ok left=<> deckgone=0}

# THE CHILD MUST NOT INHERIT OUR STDIN. In `--pipe` mode xschem's own stdin is
# the command channel, so a simulator reading from it would eat the commands
# driving xschem -- and, since that channel never reaches EOF, a child that waits
# for one blocks until the deadline.
#
# THE STAND-IN REPORTS WHAT IT WAS GIVEN, and the first draft of this check did
# not: a fake that merely drained stdin and answered passed either way, because
# it sees EOF whatever it is handed. MEASURED in this harness: without the
# redirection the child's fd 0 is `socket:[...]` (xschem's own), with it,
# `/dev/null`. So the fake reads the link and answers a DIFFERENT MODE for each,
# and mutation M36 -- deleting the redirection -- reddens this. (Linux-specific
# `/proc`, like this file's `kill -0`; the whole suite is POSIX-bound already.)
set f_stdin [fake $fdir reports_stdin \
  "if [format {%s} {[ "$(readlink /proc/self/fd/0)" = /dev/null ]}]; then echo CCM=preserve; else echo CCM=fold; fi"]
set r [pcall sim_probe_once $f_stdin [pargv {} preserve 0] $tmp 2500]
eqcheck CS169q-the-childs-stdin-is-the-null-device-not-ours \
  "status=[dg $r status] mode=[dg $r mode]" {status=ok mode=preserve}

# the row's args and A2's `-n` really reach the argv
set i_args [add_row spice {fake with args} $f_answer {--alpha 7} preserve 1]
set r [pcall sim_profile_probe_once spice $i_args preserve $tmp 1500]
# argv is exe + these words + THE PROBE DECK, which sim_probe_once owns and whose
# name carries a timestamp; the deck is asserted separately, by shape.
eqcheck CS169o-the-rows-args-and--n-reach-the-probe-argv \
  "words=[lrange [dg $r argv] 1 end-1]\
 deck=[file tail [lindex [dg $r argv] end]]" \
  {words=-b --alpha 7 -n -D casemode=preserve deck=casemode_probe.cir}

# ===========================================================================
# C2 — the review round's findings, every one driven WITHOUT a simulator so it
# survives ver_50 vanishing: the per-mode sweep itself, a partial measurement,
# the whole-probe budget, the three options nothing exercised, a relative
# TMPDIR, and a profile `args` that writes into the user's run directory.
# ===========================================================================

# A RELATIVE $TMPDIR MUST NOT PRODUCE A RELATIVE DECK PATH. The deck is written
# before the `cd` (so it lands correctly) but the child runs in `cwd` and cannot
# open it -- with a real ngspice that is "can't open file", i.e. `unknown` for a
# perfectly good binary, with nothing anywhere saying why. The stand-in answers
# `preserve` when it can READ the last word of its argv and `fold` when it
# cannot, so the two cases are distinguishable at all.
set reltmp [file join $tmp reltmp]
file mkdir $reltmp
set relcwd [file join $tmp relcwd]
file mkdir $relcwd
set tmpdir_before [expr {[info exists ::env(TMPDIR)] ? $::env(TMPDIR) : {}}]
cd $tmp
set ::env(TMPDIR) reltmp
set r [pcall sim_probe_once $f_deck [pargv {} preserve 0] $relcwd 2500]
cd $cwd_at_start
if {$tmpdir_before eq {}} {
  unset -nocomplain ::env(TMPDIR)
} else {
  set ::env(TMPDIR) $tmpdir_before
}
eqcheck CS173c-a-relative-TMPDIR-still-hands-the-child-an-ABSOLUTE-deck \
  "status=[dg $r status] mode=[dg $r mode] deck=[file pathtype [lindex [dg $r argv] end]]\
 cwd_intact=[expr {[pwd] eq $cwd_at_start}]" \
  {status=ok mode=preserve deck=absolute cwd_intact=1}

# THE ITEM'S HEADLINE RULING, DRIVEN WITH NO SIMULATOR. `always_fold` (CS169h)
# cannot tell "ask each mode" from "ask ONE mode three times" -- it answers
# `fold` whatever it is asked -- so a mechanism that asked the profile's single
# mode three times passed the whole suite on any machine without ver_50. This
# stand-in reads `-D casemode=<m>` out of its own argv and answers THAT.
set i_echo [add_row spice {fake echoback} $f_echo]
set r [pcall sim_profile_probe_capability spice $i_echo -timeout 3000]
eqcheck CS173d-each-mode-is-ASKED-separately-and-answers-for-itself \
  "status=[dg $r status] detected=<[dg $r detected]> legs=[llength [dkeys [dg $r legs]]]\
 selectable=<[pcall sim_profile_selectable spice $i_echo]>" \
  {status=ok detected=<fold preserve distinguish> legs=3\
 selectable=<fold preserve distinguish>}
# and the partial implementation A1 is actually about: `preserve` honoured,
# `distinguish` silently downgraded to `fold`. Presence-implies-support would
# offer all three; per-mode measurement offers two.
set i_sub [add_row spice {fake subset} $f_subset]
set r [pcall sim_profile_probe_capability spice $i_sub -timeout 3000]
eqcheck CS173e-a-binary-that-honours-only-SOME-modes-is-measured-mode-by-mode \
  "status=[dg $r status] detected=<[dg $r detected]>\
 supports_distinguish=[pcall sim_profile_supports spice $i_sub distinguish]\
 selectable=<[pcall sim_profile_selectable spice $i_sub]>" \
  {status=ok detected=<fold preserve> supports_distinguish=0 selectable=<fold preserve>}

# ONE STALLED LEG INVALIDATES THE WHOLE MEASUREMENT. This is the case CS169j
# does not reach: there, every leg hangs. Here two answer and the third stalls,
# and recording the survivors would narrow the row PERMANENTLY -- worse than
# never probing, because an unprobed row still offers `fold` and a recorded one
# is not stale, so nothing re-probes it. (With `fold` as the stalling leg the
# row would claim it cannot deliver the global default.) So: `partial`, nothing
# recorded, `probed` empty, `fold` still selectable, still stale.
set i_mixed [add_row spice {fake mixed} $f_mixed]
set r [pcall sim_profile_probe_capability spice $i_mixed -timeout 1200]
after 200
eqcheck CS173f-a-partly-stalled-probe-is-partial-and-records-NOTHING \
  "status=[dg $r status] timedout=[dg $r timedout] detected=<[dg $r detected]>\
 recorded=[dg $r recorded] probed=<[pcall sim_profile_get spice $i_mixed probed]>\
 selectable=[pcall sim_profile_selectable spice $i_mixed]\
 stale=[pcall sim_profile_probe_stale spice $i_mixed]" \
  {status=partial timedout=1 detected=<fold preserve> recorded=0 probed=<>\
 selectable=fold stale=1}

# THE TIMEOUT IS A BUDGET FOR THE WHOLE PROBE, NOT PER LEG. Three sequential
# legs against a silent binary used to block this interpreter for 3x the
# timeout -- 15 s at the shipped default, measured -- and B3's whole reason for
# a mandatory timeout is that item 13's dialog must not freeze. `legs=1` is the
# other half: once the budget is gone the remaining legs are not started.
set i_mute [add_row spice {fake mute} $f_mute]
set t0 [clock milliseconds]
set r [pcall sim_profile_probe_capability spice $i_mute -timeout 900]
set el [expr {[clock milliseconds] - $t0}]
after 200
eqcheck CS173g-the-capability-probes-timeout-bounds-the-WHOLE-probe \
  "status=[dg $r status] fired=[expr {$el >= 900}] bounded=[expr {$el < 1800}]\
 legs=[llength [dkeys [dg $r legs]]] recorded=[dg $r recorded]" \
  {status=timeout fired=1 bounded=1 legs=1 recorded=0}

# `-cwd` IS THE OPTION THE WHOLE TWO-PROBES RULING RESTS ON (one mechanism,
# parameterised by cwd) and nothing drove it: making it a no-op left the suite
# green. This stand-in answers by what is in the directory it was started in, so
# the two calls differ only in where the probe ran. The caller's directory must
# also SURVIVE -- only a temp dir the probe made itself may be removed.
set markdir [file join $tmp markdir]
file mkdir $markdir
putfile [file join $markdir MARKER] "x\n"
set i_mark [add_row spice {fake marker} $f_mark]
set r1 [pcall sim_profile_probe_capability spice $i_mark -cwd $markdir -timeout 3000]
set r2 [pcall sim_profile_probe_capability spice $i_mark -timeout 3000]
eqcheck CS173h-the--cwd-option-selects-the-directory-the-probe-runs-in \
  "given=[expr {[dg $r1 cwd] eq $markdir}] kept=[file exists $markdir]\
 withcwd=<[dg $r1 detected]> without=<[dg $r2 detected]>" \
  {given=1 kept=1 withcwd=<preserve> without=<fold>}

# A PROFILE'S `args` MAY NOT WRITE INTO THE DIRECTORY THE PROBE ASKS ABOUT.
# `-r <raw>`/`-o <log>` is an ordinary batch profile, the run probe's cwd is the
# user's own run directory, and the probe overwrote a previous run's log with
# its own -- then answered nothing, because its stdout had gone into that file.
# The stand-in writes its `-o` file exactly as ngspice does, so an unfiltered
# argv is visible as a clobbered file AND as a lost answer.
set rundir [file join $tmp rundir]
file mkdir $rundir
putfile [file join $rundir tb.log] "PREVIOUS-RUN-LOG\n"
set r [pcall sim_probe_once $f_clob [pargv {-o tb.log} preserve 0] $rundir 2500]
eqcheck CS173i-a--o-in-the-args-reaches-neither-the-probe-nor-the-users-file \
  "status=[dg $r status] mode=[dg $r mode] log=<[readfile [file join $rundir tb.log]]>\
 left=<[lsort [glob -nocomplain -tails -directory $rundir *]]>" \
  {status=ok mode=preserve log=<PREVIOUS-RUN-LOG\n> left=<tb.log>}

# THE RUN PROBE'S `-exe` AND `-args`: item 8's own route (it passes the
# executable it is really about to run), and both were accepted, documented and
# driven by nothing -- emptying their switch arms left the suite green. The
# profile here answers `fold`; the override answers what it was asked.
set rpdeck [file join $rundir rp_deck.cir]
putfile $rpdeck "* run probe deck\n.end\n"
pcall sim_profile_set spice $i_fold casemode preserve
set st_f [pcall ase::sim_profile_stamp [pcall ase::state_default] spice $i_fold]
set r [pcall ase::sim_probe_run $st_f -deck $rpdeck -exe $f_echo -args {--zzz 1} -timeout 2500]
eqcheck CS173j-the-run-probes--exe-and--args-beat-the-profiles-own \
  "exe=[file tail [lindex [dg $r argv] 0]] words=[lrange [dg $r argv] 1 end-1]\
 got=[dg $r mode] agree=[dg $r agree]" \
  {exe=echo_back words=-b --zzz 1 -D casemode=preserve got=preserve agree=1}

# "NO SUCH VARIABLE" IS A MEASURED DELIVERY OF `fold`, and the run probe used to
# answer `agree {}` -- documented as "nothing was measured" -- for it. That is
# the commonest real mismatch there is (a released ngspice under a `distinguish`
# request, the case B4 tells item 8 to REFUSE), and it left the two halves of
# this item disagreeing about the same reply: the capability probe records those
# exact bytes as `detected {fold}`. Both directions in one expectation, so a
# `delivers` hardcoded to `fold` fails the second half.
pcall sim_profile_set spice $i_stock casemode distinguish
set st_s [pcall ase::sim_profile_stamp [pcall ase::state_default] spice $i_stock]
set rd [pcall ase::sim_probe_run $st_s -deck $rpdeck -timeout 2500]
pcall sim_profile_set spice $i_stock casemode fold
set rf [pcall ase::sim_probe_run $st_s -deck $rpdeck -timeout 2500]
eqcheck CS173k-a-no-casemode-binary-DELIVERS-fold-and-the-run-probe-compares-it \
  "nocm=[dg $rd nocasemode] req=[dg $rd requested] delivers=[dg $rd delivers]\
 agree=[dg $rd agree] foldreq=[dg $rf requested] folddelivers=[dg $rf delivers]\
 foldagree=[dg $rf agree]" \
  {nocm=1 req=distinguish delivers=fold agree=0 foldreq=fold folddelivers=fold\
 foldagree=1}

# ===========================================================================
# D — the real binaries. Every leg here SKIPS when the build is absent.
# ===========================================================================
if {$NG50 ne {}} {
  reset_sim
  set i50 [add_row spice {ver_50} $NG50]
  set r [pcall sim_profile_probe_capability spice $i50]
  eqcheck CS170-ver_50-delivers-all-three-modes-and-it-is-recorded \
    "status=[dg $r status] detected=<[dg $r detected]> recorded=[dg $r recorded]\
 selectable=<[pcall sim_profile_selectable spice $i50]>\
 stale=[pcall sim_profile_probe_stale spice $i50]" \
    {status=ok detected=<fold preserve distinguish> recorded=1\
 selectable=<fold preserve distinguish> stale=0}
  eqcheck CS170b-the-capability-probe-is-fast \
    "under3s=[expr {[dg $r ms] < 3000}] legs=[llength [dkeys [dg $r legs]]]" \
    {under3s=1 legs=3}

  # --- A2, measured: a .spiceinit beside the deck beats the flag ---
  set deckdir [file join $tmp deckdir]
  file mkdir $deckdir
  putfile [file join $deckdir .spiceinit] "set casemode=fold\n"
  set r [pcall sim_probe_once $NG50 [pargv {} preserve 0] $deckdir 5000]
  set r2 [pcall sim_probe_once $NG50 [pargv {} preserve 1] $deckdir 5000]
  eqcheck CS170c-a-spiceinit-beside-the-deck-beats--D-casemode \
    "asked=preserve got=[dg $r mode] with_n=[dg $r2 mode]" \
    {asked=preserve got=fold with_n=preserve}
  # and from a directory with no .spiceinit the request is honoured, so CS170c
  # is about the file and not about the flag being ignored everywhere
  set cleandir [file join $tmp cleandir]
  file mkdir $cleandir
  set r [pcall sim_probe_once $NG50 [pargv {} preserve 0] $cleandir 5000]
  eqcheck CS170d-from-a-clean-directory-the-request-is-honoured [dg $r mode] preserve

  # --- the HOME layer. The developer's own ~ is NEVER written to: HOME is
  # pointed at a scratch directory for the duration (MEASURED: ngspice honours
  # it), and the check asserts it is put back.
  set fakehome [file join $tmp fakehome]
  file mkdir $fakehome
  putfile [file join $fakehome .spiceinit] "set casemode=fold\n"
  set home_before $::env(HOME)
  set ::env(HOME) $fakehome
  set r [pcall sim_probe_once $NG50 [pargv {} preserve 0] $cleandir 5000]
  set ::env(HOME) $home_before
  # THE CONTROL IS IN THE SAME ASSERTION on purpose: "asked for preserve, got
  # fold" is also what a probe that never asks for anything produces, so the
  # second half re-probes the identical command with the real HOME (which has no
  # .spiceinit -- checked) and requires `preserve` back. That second half is also
  # what would redden if HOME were NOT put back, which is why there is no
  # `home_restored=` term: an earlier cut asserted `$::env(HOME) eq $home_before`
  # two lines after setting exactly that, with no product code in between that
  # can touch HOME -- a term that cannot fail. HOME safety here rests on this
  # test's own bookkeeping (the line above) plus this control probe.
  set r2 [pcall sim_probe_once $NG50 [pargv {} preserve 0] $cleandir 5000]
  eqcheck CS170e-a-HOME-spiceinit-overrides-too \
    "fakehome=[dg $r mode] realhome=[dg $r2 mode]" \
    {fakehome=fold realhome=preserve}

  # --- THE REAL HANG. `quit` is stripped out of the probe's own stdin by a
  # wrapper, which is exactly the missing-`quit` case B3 measured: EOF does not
  # end an interactive ngspice, so without the hard timeout this never returns.
  # A REAL ngspice that hangs, on a plausible shape: a `.control` block that
  # blocks in `shell sleep`. The wrapper ignores the probe's own deck and runs
  # this one instead, so the process being killed is ngspice itself, not a shell.
  # `shell sleep` is a GRANDCHILD of the probe, and the kill reaches the child
  # only (the declared limit in spec 11.6): killing ngspice leaves the `sh -c
  # sleep` behind for the rest of its sleep. That is the point of the check --
  # it hangs a REAL ngspice -- so the residue is bounded instead: 25 s is ~20x
  # the 1200 ms deadline below and a fifth of the two minutes the stand-ins used
  # to leave lying around.
  set hangdeck [file join $fdir hang_probe.cir]
  putfile $hangdeck "* hang probe\n.control\necho CCM=\$curcasemode\nshell sleep 25\nquit\n.endc\n.end\n"
  set wrap [fake $fdir hanging_ngspice "exec $NG50 -b $hangdeck"]
  set i_nq [add_row spice {ver_50 without quit} $wrap]
  set t0 [clock milliseconds]
  set r [pcall sim_probe_once $wrap [pargv {} fold 0] $cleandir 1200]
  set el [expr {[clock milliseconds] - $t0}]
  after 200
  # MEASURED, and it is why `parsed` is EMPTY here while CS169j's stand-in
  # parses one: a batch ngspice killed mid-run has written NOTHING -- its stdout
  # is block-buffered into the pipe, `timeout 3` on the same deck yields 0 bytes.
  # So a timed-out real probe usually carries no answer at all, which is exactly
  # the outcome section 11.5's ruling assumes; CS169j drives the harder case,
  # where an answer IS present and is still not recorded.
  eqcheck CS170f-a-real-hanging-ngspice-is-cut-off-by-the-deadline \
    "status=[dg $r status] parsed=<[dg $r mode]> fired=[expr {$el >= 1200}]\
 bounded=[expr {$el < 6000}] child=[alive [lindex [dg $r pids] 0]]" \
    {status=timeout parsed=<> fired=1 bounded=1 child=dead}
  set r [pcall sim_profile_probe_capability spice $i_nq -timeout 1200]
  eqcheck CS170g-a-hanging-real-binary-records-no-capability \
    "status=[dg $r status] recorded=[dg $r recorded]\
 probed=<[pcall sim_profile_get spice $i_nq probed]>" \
    {status=timeout recorded=0 probed=<>}

  # --- the ASE-L run probe, end to end ---
  set st [pcall ase::state_default]
  set st [pcall ase::sim_profile_stamp $st spice $i50]
  pcall sim_profile_set spice $i50 casemode preserve
  set deck [file join $deckdir probe_deck.cir]
  putfile $deck "* probe deck\n.end\n"
  set r [pcall ase::sim_probe_run $st -deck $deck -timeout 5000]
  eqcheck CS170h-the-run-probe-runs-in-the-DECKS-directory-and-reports-the-real-mode \
    "pstat=[dg $r profile_status] requested=[dg $r requested] got=[dg $r mode]\
 agree=[dg $r agree] cwd_is_deckdir=[expr {[dg $r cwd] eq [file normalize $deckdir]}]" \
    {pstat=ok requested=preserve got=fold agree=0 cwd_is_deckdir=1}
  # THE RUN PROBE RECORDS NOTHING: `detected` still says all three, not `fold`
  eqcheck CS170i-the-run-probe-does-not-touch-the-recorded-capability \
    [pcall sim_profile_get spice $i50 detected] {fold preserve distinguish}
  # and out of a clean directory it agrees
  set deck2 [file join $cleandir probe_deck.cir]
  putfile $deck2 "* probe deck\n.end\n"
  set r [pcall ase::sim_probe_run $st -deck $deck2 -timeout 5000]
  eqcheck CS170j-the-same-state-agrees-from-a-directory-with-no-spiceinit \
    "got=[dg $r mode] agree=[dg $r agree]" {got=preserve agree=1}
  # A2's per-profile `-n` is what a user turns on when their .spiceinit is the
  # problem, and it reaches the run probe
  pcall sim_profile_set spice $i50 nospiceinit 1
  set r [pcall ase::sim_probe_run $st -deck $deck -timeout 5000]
  pcall sim_profile_set spice $i50 nospiceinit 0
  eqcheck CS170k-the-profiles--n-reaches-the-run-probe \
    "got=[dg $r mode] agree=[dg $r agree]" {got=preserve agree=1}
  # a state whose profile names no executable: `noexe`, and item 8 decides what
  # ASE-L falls back to (this proc does not reimplement run_cmd's bare ngspice)
  set st0 [pcall ase::sim_profile_stamp [pcall ase::state_default] spice 0]
  set r [pcall ase::sim_probe_run $st0 -deck $deck2 -timeout 1000]
  # `delivers=<>` is part of it: every return from the run probe carries the same
  # keys, so item 8 reads one field instead of asking which branch answered.
  eqcheck CS170l-a-profile-with-no-exe-reports-noexe \
    "status=[dg $r status] requested=[dg $r requested] delivers=<[dg $r delivers]>\
 agree=<[dg $r agree]>" \
    {status=noexe requested=fold delivers=<> agree=<>}
  # A RUN PROBE THAT TIMED OUT MEASURED NOTHING: `mode` may carry the line the
  # binary managed to print, but `agree` must stay EMPTY (B2b -- no answer is
  # unknown, never `fold`), or item 8 would apply B4's policy to a comparison
  # against a run that never finished.
  set stnq [pcall ase::sim_profile_stamp [pcall ase::state_default] spice $i_nq]
  set r [pcall ase::sim_probe_run $stnq -deck $deck2 -timeout 1200]
  eqcheck CS170m-a-timed-out-run-probe-compares-nothing \
    "status=[dg $r status] parsed=<[dg $r mode]> agree=<[dg $r agree]>" \
    {status=timeout parsed=<> agree=<>}

  # THE SAME DEFECT AS CS173i, END TO END WITH A REAL BINARY: an ordinary batch
  # profile carries `-r <raw> -o <log>`, the run probe runs in the deck's own
  # directory, and unfiltered those two words made ngspice OVERWRITE the previous
  # run's outputs with the probe's -- and, stdout having gone to the log, answer
  # nothing at all for a binary that delivers all three modes. Both halves are
  # asserted: the files are byte-identical, and the mode still comes back.
  set clobdir [file join $tmp clobdir]
  file mkdir $clobdir
  putfile [file join $clobdir tb.raw] "PREVIOUS-RUN-RAW\n"
  putfile [file join $clobdir tb.log] "PREVIOUS-RUN-LOG\n"
  set clobdeck [file join $clobdir tb.cir]
  putfile $clobdeck "* run deck\n.end\n"
  pcall sim_profile_set spice $i50 args {-r tb.raw -o tb.log}
  set r [pcall ase::sim_probe_run $st -deck $clobdeck -timeout 5000]
  pcall sim_profile_set spice $i50 args {}
  eqcheck CS174-the-run-probe-leaves-the-rundirs-own-output-files-alone \
    "got=[dg $r mode] agree=[dg $r agree] raw=<[readfile [file join $clobdir tb.raw]]>\
 log=<[readfile [file join $clobdir tb.log]]>\
 left=<[lsort [glob -nocomplain -tails -directory $clobdir *]]>" \
    {got=preserve agree=1 raw=<PREVIOUS-RUN-RAW\n> log=<PREVIOUS-RUN-LOG\n>\
 left=<tb.cir tb.log tb.raw>}

  # THE PROBE MUST NOT NEED AN X SERVER, and this is the defect that changed the
  # transport. `ngspice -p` opens $DISPLAY: with a WSLg `:0` out of client slots
  # it prints `Can't open display` and exits without answering, and with DISPLAY
  # UNSET it DUMPS CORE (`no graphics interface`). Both were measured live during
  # this item -- a binary supporting all three modes reported "unknown" because an
  # X server was busy. A batch deck needs no X. All three displays are driven in
  # one expectation, so a probe that answers nothing everywhere cannot pass.
  set disp_before [expr {[info exists ::env(DISPLAY)] ? $::env(DISPLAY) : {}}]
  set ::env(DISPLAY) :77
  set r_bogus [pcall sim_probe_once $NG50 [pargv {} preserve 0] $cleandir 5000]
  unset -nocomplain ::env(DISPLAY)
  set r_nodisp [pcall sim_probe_once $NG50 [pargv {} preserve 0] $cleandir 5000]
  if {$disp_before ne {}} { set ::env(DISPLAY) $disp_before }
  set r_good [pcall sim_probe_once $NG50 [pargv {} preserve 0] $cleandir 5000]
  # no `display_restored=` term: the restore is the line above, nothing between
  # it and the assertion can move DISPLAY, and a term that re-reads the test's
  # own assignment cannot fail. The `good=` probe is the one that would notice.
  eqcheck CS170n-the-probe-answers-with-a-bad-display-with-none-and-with-a-good-one \
    "bogus=[dg $r_bogus mode] nodisplay=[dg $r_nodisp mode] good=[dg $r_good mode]" \
    {bogus=preserve nodisplay=preserve good=preserve}
} else {
  puts "note: the case-capable build is not present, so the ver_50 legs\
 (CS170..CS170n) did not run. Set NGSPICE_CASE_TEST to a case-capable ngspice."
}

if {$NGSTOCK ne {}} {
  reset_sim
  set ist [add_row spice {released ngspice} $NGSTOCK]
  set r [pcall sim_profile_probe_capability spice $ist]
  # THE NEGATIVE CONTROL. A released ngspice has no `$curcasemode`, and that
  # reply IS the capability answer: fold, and nothing else on offer (A1).
  eqcheck CS171-a-released-ngspice-answers-no-casemode-and-is-offered-fold-alone \
    "status=[dg $r status] detected=<[dg $r detected]> recorded=[dg $r recorded]\
 selectable=<[pcall sim_profile_selectable spice $ist]>\
 supports_preserve=[pcall sim_profile_supports spice $ist preserve]" \
    {status=nocasemode detected=<fold> recorded=1 selectable=<fold> supports_preserve=0}
  # it ACCEPTS `-D casemode=preserve` and ignores it — the measurement A1 rests
  # on, re-taken here rather than inherited
  set r [pcall sim_probe_once $NGSTOCK [pargv {} preserve 0] $tmp 5000]
  eqcheck CS171b-released-ngspice-accepts-and-ignores-the-flag \
    "status=[dg $r status] answered=[dg $r answered] nocm=[dg $r nocasemode]\
 mode=<[dg $r mode]>" {status=ok answered=1 nocm=1 mode=<>}
} else {
  puts "note: no released ngspice on this machine, so the negative-control legs\
 (CS171, CS171b) did not run."
}

# ===========================================================================
# E — no Tk in the probe (src/ase.tcl is sourced at startup and runs headless,
# and item 13 owns every widget)
# ===========================================================================
set tkre {(^|[^a-zA-Z0-9_:.])(tk_[a-zA-Z_]+|winfo|wm|toplevel|grab|ttk::[a-z]+|bind|focus|frame|button|entry|label|canvas|listbox|checkbutton|radiobutton|menu|labelframe|combobox|text|scrollbar|update idletasks)([^a-zA-Z0-9_:.]|$)}
proc strip_tcl_comments {body} {
  set out {}
  foreach l [split $body "\n"] {
    if {[regexp {^[ \t]*#} $l]} { continue }
    regsub {;[ \t]*#.*$} $l {} l
    append out $l "\n"
  }
  return $out
}
# the detector must be able to SEE Tk, or "no hits" is vacuous
set tk_blind {}
foreach s {{ set w [toplevel .p] } { button .b -text x } { winfo exists .x }} {
  if {![regexp $tkre $s]} { lappend tk_blind $s }
}
set tk_hits {}
foreach p {sim_probe_timeout_ms sim_probe_kill sim_probe_tmpdir sim_probe_argv
           sim_probe_parse sim_probe_once sim_profile_probe_once
           sim_profile_probe_autoprobe_ok sim_profile_probe_capability
           ase::sim_probe_run} {
  if {[catch {info body $p} b]} { lappend tk_hits MISSING:$p ; continue }
  if {[regexp $tkre [strip_tcl_comments $b] -> _pre cmdname]} { lappend tk_hits $p:$cmdname }
}
eqcheck CS172-no-Tk-in-any-probe-proc-and-the-detector-can-see-Tk \
  "hits=<$tk_hits> blind=<$tk_blind>" "hits=<> blind=<>"

catch {test_scratch_drop $tmp}
puts "----"
puts "test_sim_probe: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
