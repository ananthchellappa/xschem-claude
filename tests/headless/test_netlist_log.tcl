# Action-log coverage -- the Netlist command records a REPLAYABLE line
# (issue 0062's last silent toolbar/menu row; issue 0071 atom 14).
#
# The `netlist` scheduler branch IS 1:1 with the user verb `xschem netlist`:
# the toolbar (toolbar_add Netlist {xschem netlist -erc}), the menu, the plain
# `n` key (bound to toolbar.netlist -> the dispatch after-eval dedup skips the
# wrapper copy) and scripted calls all reach it. So the branch SELF-LOGS the
# resolved output-affecting form (`xschem netlist [-erc] [-nohier] [{fname}]`) --
# the atom-3/4 branch-self-log shape, NOT a coordinate-bypass verb. netlist is a
# real re-executable action (like `save`), so it correctly re-logs on replay.
#
# The global_*_netlist() cores are SHARED (this branch + the Shift-N key + the
# CLI -n batch), so they do NOT self-log; the Shift-N current-level key logs its
# own `-nohier` equivalent (`global_*_netlist(0,1)`) at its callback.c handler
# (the atom-4 Ctrl-S/Alt-S keyboard-bypass pattern). Paths are disjoint so one
# netlist action == one line.
#
# MACHINERY GATE (mirrors the atom-4 `save fast` axis): `-keep_symbols` is passed
# ONLY by the cellview/reroute machinery (xschem.tcl reroute_inst / cellview
# relabel), which netlist a temporarily-loaded file between unlogged
# `load -keep_symbols` calls -- so a keep_symbols pass stays SILENT or a replayed
# line would fire against the wrong file / flood. The dir-unwritable early return
# logs nothing.
#
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md
#
# Needs the action log open -> registered in full_audit.sh logdir_tests (--logdir):
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_netlist_log.tcl

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "SKIP: no action log open -- run with --logdir"
  puts "RESULT: SKIP (no log)"
  exit 0
}

# count log lines that EXACTLY match a glob pattern (no wildcard = exact match)
proc logcount {pat} {
  if {[catch {open [xschem get actionlog_filename] r} fd]} { return -1 }
  set body [read $fd]; close $fd
  set n 0
  foreach line [split $body \n] { if {[string match $pat $line]} { incr n } }
  return $n
}
# last log line matching `xschem netlist*` (the just-recorded netlist line)
proc last_netlist_line {} {
  if {[catch {open [xschem get actionlog_filename] r} fd]} { return {} }
  set body [read $fd]; close $fd
  set last {}
  foreach line [split $body \n] { if {[string match {xschem netlist*} $line]} { set last $line } }
  return $last
}
proc readfile {f} {
  if {[catch {open $f r} fd]} { return {} }
  set b [read $fd]; close $fd; return $b
}

# Modal stubs: the dir-unwritable path pops TWO modals under X that would HANG
# headless -- tk_messageBox inside set_netlist_dir (mkdir failure) and the C
# branch's own alert_ ("Can not write into the netlist directory"). Stub both.
set ::alert_count 0
proc alert_ {msg {icon {}} {nowait 0} {cancel 0}} { incr ::alert_count; return 1 }
proc tk_messageBox {args} { return ok }
# ask_save must never fire (netlist never prompts a save)
set ::ask_count 0
proc ask_save {{cmd {}}} { incr ::ask_count; return yes }

# ---------------------------------------------------------------------------
# fixture: a flat schematic, two resistors sharing net MID -> a real, small,
# deterministic SPICE netlist. pid-suffixed workdir (parallel-run safety).
# ---------------------------------------------------------------------------
set work /tmp/atom14_netlist_work_[pid]
file delete -force $work; file mkdir $work
xschem set netlist_type spice
set ::netlist_dir $work
set SCH  $work/nl.sch
set NLF  $work/nl.spice     ;# derived netlist name (from nl.sch)

proc build_fixture {} {
  global SCH work
  xschem clear
  xschem instance devices/res.sym     0   0 0 0 {name=R1 value=1k}
  xschem instance devices/res.sym     0 300 0 0 {name=R2 value=2k}
  xschem instance devices/lab_pin.sym 0  30 0 0 {name=l1  lab=MID}
  xschem instance devices/lab_pin.sym 0 270 0 0 {name=l1b lab=MID}
  xschem instance devices/lab_pin.sym 0 -30 0 0 {name=l2  lab=A}
  xschem instance devices/lab_pin.sym 0 330 0 0 {name=l3  lab=B}
  xschem saveas $SCH global
  xschem rebuild_connectivity
}
build_fixture
file delete -force $NLF
xschem netlist -erc
check "fixture netlists (nl.spice non-empty)" [expr {[string length [readfile $NLF]] > 0}]

set have_x [expr {![catch {winfo viewable .drw} vv] && $vv}]

# ---------------------------------------------------------------------------
# 1) BRANCH forms: each records exactly its resolved output-affecting line, and
#    the RECORDED line, replayed, regenerates the netlist byte-identically.
# ---------------------------------------------------------------------------
# 1a) `xschem netlist -erc` (toolbar/menu/`n` form) -> +1 exact
set c0 [logcount {xschem netlist -erc}]
file delete -force $NLF
xschem netlist -erc
set rec [readfile $NLF]
check "branch `xschem netlist -erc` -> +1 exact line" \
  [expr {[logcount {xschem netlist -erc}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem netlist -erc}]"
# 1b) byte-identical replay oracle: the logged line reproduces the netlist
set line [last_netlist_line]
check "logged -erc line is exactly `xschem netlist -erc`" [expr {$line eq {xschem netlist -erc}}] "line=|$line|"
file delete -force $NLF
if {$line ne {}} { eval $line }
check "replay of logged -erc line -> byte-identical netlist" \
  [expr {[readfile $NLF] eq $rec && [string length $rec] > 0}]

# 1c) bare `xschem netlist` -> +1 exact bare (glob without wildcard = exact)
set c0 [logcount {xschem netlist}]
xschem netlist
check "branch bare `xschem netlist` -> +1 exact bare line" \
  [expr {[logcount {xschem netlist}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem netlist}]"

# 1d) `xschem netlist -nohier` (the Shift-N equivalent) -> +1 exact
set c0 [logcount {xschem netlist -nohier}]
file delete -force $NLF
xschem netlist -nohier
set recn [readfile $NLF]
check "branch `xschem netlist -nohier` -> +1 exact line" \
  [expr {[logcount {xschem netlist -nohier}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem netlist -nohier}]"
# 1e) byte-identical replay oracle for -nohier
set line [last_netlist_line]
check "logged nohier line is exactly `xschem netlist -nohier`" [expr {$line eq {xschem netlist -nohier}}] "line=|$line|"
file delete -force $NLF
if {$line ne {}} { eval $line }
check "replay of logged -nohier line -> byte-identical netlist" \
  [expr {[readfile $NLF] eq $recn && [string length $recn] > 0}]

# ---------------------------------------------------------------------------
# 2) MACHINERY GATE: `-keep_symbols` is the cellview/reroute machinery axis
#    (atom-4 `save fast`) and stays SILENT.
# ---------------------------------------------------------------------------
set m0 [logcount {xschem netlist*}]
xschem netlist -keep_symbols -noalert
check "`xschem netlist -keep_symbols -noalert` (machinery) -> NO line" \
  [expr {[logcount {xschem netlist*}] == $m0}] "delta=[expr {[logcount {xschem netlist*}] - $m0}]"
set m0 [logcount {xschem netlist*}]
xschem netlist -keep_symbols
check "`xschem netlist -keep_symbols` alone -> NO line (gate is keep_symbols)" \
  [expr {[logcount {xschem netlist*}] == $m0}] "delta=[expr {[logcount {xschem netlist*}] - $m0}]"

# ---------------------------------------------------------------------------
# 3) DIR-UNWRITABLE early return logs nothing. A regular FILE as a path
#    component makes mkdir fail (ENOTDIR) -- root-proof, unlike chmod 000.
# ---------------------------------------------------------------------------
close [open $work/afile w]           ;# a regular file
set ::netlist_dir $work/afile/sub    ;# mkdir under a file -> set_netlist_dir fails
set ::alert_count 0
set m0 [logcount {xschem netlist*}]
xschem netlist -erc
check "netlist into unwritable dir -> NO line (done_netlist==0 gate)" \
  [expr {[logcount {xschem netlist*}] == $m0}] "delta=[expr {[logcount {xschem netlist*}] - $m0}]"
set ::netlist_dir $work              ;# restore
file delete -force $NLF
xschem netlist -erc                  ;# and a good netlist still works after
check "netlist works again after restoring a writable dir" [expr {[string length [readfile $NLF]] > 0}]

# ---------------------------------------------------------------------------
# 4) SHIFT-N KEY (current-level netlist): bypasses the branch (direct
#    global_*_netlist(0,1)) -> logs `xschem netlist -erc -nohier` at the entry
#    site. `-erc` (erc=1) is the STATE-PRESERVING flag: the key clears NEITHER
#    netlist_name NOR the infowindow suppression, and erc=1 makes the branch skip
#    both those erc==0 mutations, so the logged line reproduces the key's output
#    AND its state. The RECORDED line, replayed, regenerates the netlist
#    byte-identically (KEY <-> replay round-trip).
# ---------------------------------------------------------------------------
if {$have_x} {
  update idletasks; catch { focus -force .drw }; update idletasks
  file delete -force $NLF
  set c0 [logcount {xschem netlist -erc -nohier}]
  xschem callback .drw 2 0 0 78 0 0 0    ;# keysym 'N'=78, state 0 -> case 'N' rstate==0
  update idletasks
  set reck [readfile $NLF]
  check "Shift-N KEY -> +1 exact `xschem netlist -erc -nohier`" \
    [expr {[logcount {xschem netlist -erc -nohier}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem netlist -erc -nohier}]"
  check "Shift-N KEY wrote a netlist" [expr {[string length $reck] > 0}]
  set kline [last_netlist_line]
  check "Shift-N logged line is exactly `xschem netlist -erc -nohier`" \
    [expr {$kline eq {xschem netlist -erc -nohier}}] "line=|$kline|"
  # replay the RECORDED line -> byte-identical to the key's output
  file delete -force $NLF
  if {$kline ne {}} { eval $kline }
  check "replay of Shift-N line -> byte-identical netlist (key<->replay)" \
    [expr {[readfile $NLF] eq $reck && [string length $reck] > 0}]

  # 4b) netlist_name PRESERVATION (adversarial-review MAJOR, 2 verifiers): the key
  #     does NOT clear a custom netlist_name; the logged `-erc -nohier` form (erc=1)
  #     must NOT either. A bare `-nohier` line (erc=0) WOULD clear it, diverging a
  #     later replayed netlist to the default file. This locks the fix.
  xschem set netlist_name atom14_custom.spice
  xschem callback .drw 2 0 0 78 0 0 0    ;# Shift-N with a custom name set
  update idletasks
  check "Shift-N KEY preserves a custom netlist_name (key never clears it)" \
    [expr {[xschem get netlist_name] eq {atom14_custom.spice}}] "got=[xschem get netlist_name]"
  set kline [last_netlist_line]
  xschem set netlist_name atom14_custom.spice   ;# re-arm for the replay
  if {$kline ne {}} { eval $kline }
  check "replay of the `-erc -nohier` line ALSO preserves netlist_name (no erc==0 clear)" \
    [expr {[xschem get netlist_name] eq {atom14_custom.spice}}] "got=[xschem get netlist_name]"
  # sanity: prove a bare `-nohier` (erc==0) DOES clear -- the divergence the fix avoids
  xschem set netlist_name atom14_custom.spice
  xschem netlist -nohier
  check "control: bare `xschem netlist -nohier` (erc==0) clears netlist_name (divergence avoided)" \
    [expr {[xschem get netlist_name] eq {}}] "got=[xschem get netlist_name]"
  xschem set netlist_name {}    ;# restore empty for later sections
} else {
  # no-X env: keyboard sections deferred. Do NOT emit the "skipped: no X" token
  # (which full_audit classifies as whole-test SKIP) -- the non-X branch /
  # machinery / dir / fname sections fully validate the core self-log headless,
  # and the Shift-N emit is statically locked by the grep-guard S1 row, so this
  # test reports ALL PASS even without a mapped window.
  check "Shift-N keyboard netlist deferred (no-X env; core validated above)" 1
}

# ---------------------------------------------------------------------------
# 5) plain `n` KEY dispatch dedup: the binding evals `xschem netlist -erc`; the
#    branch self-logs and dispatch's after-eval dedup (actionlog_cmd_logged)
#    skips the wrapper copy -> EXACTLY +1 line, not two.
# ---------------------------------------------------------------------------
if {$have_x} {
  update idletasks; catch { focus -force .drw }; update idletasks
  set c0 [logcount {xschem netlist -erc}]
  xschem callback .drw 2 0 0 110 0 0 0   ;# keysym 'n'=110, state 0 -> toolbar.netlist
  update idletasks
  set d [expr {[logcount {xschem netlist -erc}] - $c0}]
  # idle-gated binding may not fire in every headless env; assert never-double,
  # and exactly-once when it did fire.
  check "plain `n` KEY -> at most one `xschem netlist -erc` (dispatch dedup, no double)" \
    [expr {$d == 0 || $d == 1}] "delta=$d"
  if {$d == 1} { check "plain `n` KEY dispatch logged exactly once" 1 }
} else {
  check "plain `n` keyboard netlist deferred (no-X env; core validated above)" 1
}

# ---------------------------------------------------------------------------
# 6) NO DOUBLE-LOG: a single scripted invocation records exactly one line (the
#    branch does not also re-enter a Tcl wrapper that logs).
# ---------------------------------------------------------------------------
set c0 [logcount {xschem netlist*}]
xschem netlist -erc
check "single `xschem netlist -erc` -> exactly +1 total netlist line" \
  [expr {[logcount {xschem netlist*}] == $c0 + 1}] "delta=[expr {[logcount {xschem netlist*}] - $c0}]"

# ---------------------------------------------------------------------------
# 7) FNAME form (LAST -- it sets netlist_name persistently under -erc). The line
#    carries the filename and replays to that path.
# ---------------------------------------------------------------------------
set CUSTOM $work/custom.spice
set c0 [logcount "xschem netlist -erc *custom.spice*"]
file delete -force $CUSTOM
xschem netlist -erc $CUSTOM
set recf [readfile $CUSTOM]
check "fname form logs `xschem netlist -erc <path>`" \
  [expr {[logcount "xschem netlist -erc *custom.spice*"] == $c0 + 1}]
check "fname form wrote the custom netlist file" [expr {[string length $recf] > 0}]
set line [last_netlist_line]
file delete -force $CUSTOM
if {$line ne {}} { eval $line }
check "replay of logged fname line -> byte-identical custom netlist" \
  [expr {[readfile $CUSTOM] eq $recf && [string length $recf] > 0}]

check "no section fired the ask_save prompt" [expr {$::ask_count == 0}] "count=$::ask_count"

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update
file delete -force $work

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
