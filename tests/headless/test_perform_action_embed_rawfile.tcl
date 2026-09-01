# perform_action() BOUNDARY -- SIXTEENTH per-verb migration (Refactor B, audit §4 /
# §36): embed_rawfile.
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-check
# it?" and "did we log it?" are structural invariants, not per-path checklist items
# (audit §3.1). Atom 16 is a PLAIN per-verb migration onto the UNCHANGED atom-13
# log-on-success boundary (NO shared-machinery change) -- the DEFERRED runner-up the
# atom-15 fan-out scout named (the scout left EXACTLY TWO friction-free candidates:
# show_unconnected_pins = atom 15, embed_rawfile = this atom; the pool is now EXHAUSTED).
# embed_rawfile is a HYBRID of two prior templates:
#   * the reset_inst_prop (§33) SINGLE-STRING-REFERENT + argc-GATE template: it is a
#     VALIDATING-LITE verb -- run_core rejects a missing file argument with an early
#     TCL_ERROR *before* any mutation, and its referent (the RAW argv[2] file path) is
#     logged via log_action_argv/Tcl_Merge, NOT a raw %s, so a metachar path replays and
#     the `~/` form re-expands identically;
#   * the floaters (§30) / show_unconnected_pins (§35) CORE-OWNS-ITS-OWN-UNDO template:
#     the core embed_rawfile() (draw.c) OWNS the SINGLE push_undo + set_modify when it
#     embeds (lastsel==1 && ELEMENT), so run_core adds NEITHER -- adding push_undo would
#     double-push (the atom-1 rule).
# The `~/` expansion (via the home_dir global) MOVES from the scheduler branch INTO
# run_core unchanged.
#
# Entry points, all funnelled through perform_action:
#   scheduler branch (scripted `xschem embed_rawfile <path>`) -> return perform_action(...)
#   It is a PURE SCRIPTED verb: NO key (keybindings/mousebindings.csv), NO menu
#   (xschem.tcl -command), NO command palette (actions.csv), NO callback.c act_*/legacy
#   switch, NO Tcl caller anywhere. So there is NO callback.c edit and NO key-equivalence
#   decision (like reset_inst_prop §33 / replace_symbol §34).
#
# TWO DELIBERATE behaviour deltas of this atom, both captured below:
#   1. THE ARGC GATE (check (b)): the old branch SILENTLY no-op'd on a missing arg
#      (argc<=2, rc=0). The migration makes it a TCL_ERROR + verb-named message AND, via
#      log-on-success, records NO phantom line. The one design choice (the alternative --
#      keep the silent no-op and let log-on-success log a useless bare line -- is worse).
#   2. THE READONLY GATE, a CORRECTNESS FIX (check (c)): the scheduler branch NEVER HAD a
#      scheduler_readonly_reject -- it push_undo+set_modify+embedded on a read-only cell
#      (a scattered 0041/0051-class mutation-on-a-read-only-cell gap). The boundary's ONE
#      gate now CLOSES it. Safe -- embed_rawfile has NO read-only-safe form (every path
#      with a selected element mutates; argc<3 and nothing-selected are no-ops, not
#      queries), so the all-or-nothing gate cannot OVER-reject (contrast check_unique_names
#      §30). The WRITABLE effect + log are byte-identical to pre-migration.
#
# WRINKLE 3 -- external-file replay fidelity (check (e)): the log records the PATH, not the
# embedded content (too large to inline). Replay RE-READS the file, so a round-trip where
# the file is PRESENT replays the SAME spice_data (asserted). CAVEAT (documented, not a
# blocker): a file removed between record and replay replays an empty/cleared attribute --
# base64_from_file returns NULL on a missing/non-regular file and subst_token BLANKS
# spice_data, so a missing file is a MUTATION, not a failure (verified on the binary).
# Selection-dependent: the verb embeds into the SINGLE selected element (lastsel==1); the
# log does NOT encode WHICH instance (the accepted floaters/attach_labels/toggle_ignore
# model) -- the fixture selects exactly one element.
#
#   (a) SUCCESS: select one inst + a real raw file -> exactly +1 log line + the effect
#       applies (spice_data empty -> a base64 blob) + the logged line is the Tcl_Merge form
#       [list xschem embed_rawfile <path>] (a plain path logs unbraced, minimal quoting)
#   (a2) referent replay-safety (the atom-13 metachar lesson): a path with a space/bracket
#       logs BRACE-QUOTED (Tcl_Merge) and REPLAYS without a Tcl error and re-embeds
#   (b) VALIDATION NOT LOGGED (the argc gate): bare `xschem embed_rawfile` -> TCL_ERROR +
#       non-empty verb-named message + no mutation + +0 log (log-on-success drops it)
#   (c) READONLY reject (the correctness fix): readonly 1 -> TCL_ERROR + verb-named msg +
#       no embed + no log
#   (d) `~/` expansion: `xschem embed_rawfile ~/<f>` embeds IDENTICALLY to the absolute
#       path (regsub expands via home_dir); the log records the RAW `~/` form (NOT the
#       expanded $HOME path) and replays
#   (e) replay re-executes (self-contained) through the replay_action_log suppress seam
#       but does NOT re-log; a control unwrapped source DOES re-log. The external file must
#       still exist (wrinkle 3) -- the replay re-embeds the SAME spice_data
#   (f) undo DEPTH (the atom-1 no-double-push rule): ONE undo removes the spice_data, a
#       SECOND removes the instance -- the core's SINGLE push_undo is the only snapshot; a
#       spurious run_core push_undo would need two undos to clear the attribute
#
# Effect oracle (byte-identical WRITABLE effect before/after atom 16 -- the migration MOVES
# the `~/` expansion + ADDS the argc/readonly gates + gates the log, it does not change the
# embed): a resistor (devices/res.sym) placed at the origin and SELECTED; a small raw file
# on disk. `xschem embed_rawfile <path>` base64-encodes the file into the instance's
# spice_data attribute, so `xschem getprop instance 0 spice_data` goes empty -> a base64
# blob. Determined empirically on the pre-migration binary (and the deltas on the migrated
# binary): no-arg rc 0->TCL_ERROR, readonly rc 0(embedded)->TCL_ERROR(no embed), `~/` and
# undo-depth unchanged.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_embed_rawfile.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §36

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers
# this in logdir_tests so LOG is always set in the real run; the guard keeps a bare
# invocation from erroring. (deferred, NOT "skipped: no X".)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Exact-line counters. The logged verb is arg-carrying via Tcl_Merge, so the canonical
# recorded line for a given path is EXACTLY [list xschem embed_rawfile $path] -- the Tcl
# `list` command joins with the SAME minimal quoting as the C log_action_argv/Tcl_Merge.
proc ec {path} {
  set want [list xschem embed_rawfile $path]
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {$l eq $want} { incr n } }
  return $n
}
# ANY embed_rawfile* line -- to prove a FAILED call logs NOTHING (not even a variant).
proc ec_any {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem embed_rawfile*} $l]} { incr n } }
  return $n
}
proc sd {} { return [xschem getprop instance 0 spice_data] }

# Scratch raw file on disk (pid-isolated, under the logdir).
set SCRATCH [file join [file dirname $LOG] emb_[pid]]
file mkdir $SCRATCH
set RAW [file join $SCRATCH small.raw]
set fd [open $RAW w]; puts -nonewline $fd "hello raw data 12345"; close $fd

# Fixture: a resistor at the origin, SELECTED (embed_rawfile acts only on the single
# selected element, lastsel==1 && ELEMENT).
proc fixture {} {
  global RAW
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1}
  xschem select instance 0
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: the ONE script entry -> exactly +1 log line, the effect applies, and the
#     logged line is the Tcl_Merge referent form (a plain path -> minimal quoting = unbraced).
# ---------------------------------------------------------------------------
fixture
check "(a) fixture: spice_data empty before embed" [expr {[sd] eq {}}] "spice_data=>[sd]<"
set c0 [ec $RAW]
xschem embed_rawfile $RAW
check "(a) scripted 'xschem embed_rawfile <path>' -> exactly +1" [expr {[ec $RAW] == $c0 + 1}] "c0=$c0 now=[ec $RAW]"
check "(a) scripted: effect applied (spice_data set to a base64 blob)" \
  [expr {[sd] ne {} && [string match {*aGVsbG8gcmF3IGRhdGEgMTIzNDU=*} [sd]]}] "spice_data=>[sd]<"
# byte-exact: Tcl_Merge quotes MINIMALLY, so a plain path logs unbraced, exactly [list ...].
set want [list xschem embed_rawfile $RAW]
set fd [open [xschem get actionlog_filename] r]; set allE [read $fd]; close $fd
set exactE ""
foreach l [split $allE \n] { if {$l eq $want} { set exactE $l } }
check "(a) logged line is byte-exact the Tcl_Merge form (unbraced for a plain path)" \
  [expr {$exactE eq $want}] "want=>$want< got=>$exactE<"

# (a2) REPLAY-SAFE REFERENT (the atom-13 adversarial lesson). A path with a space AND a
# bracket carries Tcl metacharacters; a RAW `xschem embed_rawfile /d/sim [1].raw` log line
# would replay `[1]` as a command substitution. The log MUST Tcl-quote the referent
# (log_action_argv/Tcl_Merge -> brace-quoted) so it round-trips. Assert the logged line is
# brace-quoted AND that replaying that EXACT line re-embeds (the file exists).
set RAW2 [file join $SCRATCH "sim \[1\] data.raw"]
set fd [open $RAW2 w]; puts -nonewline $fd "bracketed path payload"; close $fd
fixture
xschem embed_rawfile $RAW2
check "(a2) metachar path: embed applied (spice_data set)" [expr {[sd] ne {}}] "spice_data-len=[string length [sd]]"
set want2 [list xschem embed_rawfile $RAW2]
check "(a2) metachar path: the Tcl_Merge form is brace-quoted (contains braces), not raw" \
  [expr {[string match "*\{*\}*" $want2]}] "want2=>$want2<"
set fd [open [xschem get actionlog_filename] r]; set allE2 [read $fd]; close $fd
set exactE2 ""
foreach l [split $allE2 \n] { if {$l eq $want2} { set exactE2 $l } }
check "(a2) metachar path logged BRACE-QUOTED (Tcl_Merge), byte-exact" [expr {$exactE2 eq $want2}] "want=>$want2< got=>$exactE2<"
# replay-safety: re-place + select, eval the EXACT logged line, assert it resolved (no Tcl
# error) + re-embedded.
fixture
set rrc [catch {uplevel #0 $exactE2} rres]
check "(a2) metachar path: the logged line REPLAYS without a Tcl error (metachar-safe)" \
  [expr {$rrc == 0}] "rc=$rrc res=>$rres<"
check "(a2) metachar path: replay re-embedded (spice_data set)" [expr {[sd] ne {}}] "spice_data-len=[string length [sd]]"

# ---------------------------------------------------------------------------
# (b) THE ARGC GATE -- FAILURE IS NOT LOGGED, and the error message SURVIVES. The old
#     branch silently no-op'd on a missing arg; the migration makes it a TCL_ERROR that
#     (via log-on-success) records NO line. The message-non-empty check is the landmine
#     proof (success-only Tcl_ResetResult must not wipe run_core's message).
# ---------------------------------------------------------------------------
fixture
set t0 [sd]
set a0 [ec_any]
set e1 [catch {xschem embed_rawfile} m1]
check "(b) no-arg: TCL_ERROR" [expr {$e1 == 1}] "rc=$e1"
check "(b) no-arg: NON-EMPTY verb-named message (landmine: Tcl_ResetResult did not wipe it)" \
  [expr {[string match {*embed_rawfile*argument*} $m1]}] "msg=>$m1<"
check "(b) no-arg: NO log line (+0 -- failure not logged)" [expr {[ec_any] == $a0}] "a0=$a0 now=[ec_any]"
check "(b) no-arg: NO mutation" [expr {[sd] eq $t0}] "before=>$t0< after=>[sd]<"

# ---------------------------------------------------------------------------
# (c) READONLY reject (the CORRECTNESS FIX -- this branch never had a readonly gate):
#     TCL_ERROR, verb-named read-only message, NO embed (spice_data stays empty), NO log.
#     Pre-migration the verb EMBEDDED on a read-only cell (push_undo+set_modify+embed ran).
# ---------------------------------------------------------------------------
fixture
set t0 [sd]
xschem set readonly 1
set a0 [ec_any]
set e3 [catch {xschem embed_rawfile $RAW} m3]
check "(c) readonly: TCL_ERROR" [expr {$e3 == 1}] "rc=$e3"
check "(c) readonly: message names the verb + read-only (non-empty)" \
  [expr {[string match {*embed_rawfile*read-only*} $m3]}] "msg=>$m3<"
check "(c) readonly: NO log line (+0)" [expr {[ec_any] == $a0}] "a0=$a0 now=[ec_any]"
check "(c) readonly: NO embed (spice_data unchanged)" [expr {[sd] eq $t0}] "before=>$t0< after=>[sd]<"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) `~/` expansion. Copy the raw into $HOME, embed via `~/<name>`, and assert it embeds
#     IDENTICALLY to the absolute path (regsub expands `^~/` via the home_dir global,
#     moved into run_core). The log records the RAW `~/` form (NOT the expanded $HOME path)
#     so replay re-expands identically -- and the recorded line matches the Tcl_Merge form.
#
#     $HOME IS LOAD-BEARING HERE: run_core rewrites only a LEADING `~/` into `$home_dir/`
#     (scheduler.c `regsub {^~/}`, home_dir = getenv("HOME")), so the probe file can ONLY
#     live directly under $HOME -- a test_scratch dir is unreachable by the `~/` form and
#     would make check (d) test nothing. So the PATH stays and the REMOVAL is hardened
#     instead -- this is the 0148 leak class in its worst variant, the corpse lands in the
#     developer's real $HOME: (i) this run's probe is deleted on EVERY exit path, not only
#     by the statement after check (d), and (ii) corpses of earlier runs killed mid-script
#     (segfault/timeout/^C) are swept on the way in, since nothing else ever sweeps $HOME.
# ---------------------------------------------------------------------------
source [file join [file dirname [info script]] scratch.tcl]   ;# exit discipline + pid-liveness
set HNAME embprobe_[pid].raw
set HRAW [file join $::env(HOME) $HNAME]
foreach f [glob -nocomplain -directory $::env(HOME) embprobe_*.raw] {
  if {![regexp {^embprobe_([0-9]+)\.raw$} [file tail $f] -> p]} continue
  if {$p eq [pid] || [__scratch_pid_alive $p]} continue    ;# never touch a concurrent run's
  catch {file delete -force $f}
}
if {[info commands ::__emb_real_exit] eq {}} {
  rename ::exit ::__emb_real_exit
  proc ::exit {{code 0}} { catch {file delete -force $::HRAW}; ::__emb_real_exit $code }
}
file copy -force $RAW $HRAW
# canonical: the absolute-path embed's spice_data
fixture
xschem embed_rawfile $HRAW
set sdAbs [sd]
# the `~/` form
fixture
xschem embed_rawfile ~/$HNAME
check "(d) ~/ form: embed applied" [expr {[sd] ne {}}] "spice_data-len=[string length [sd]]"
check "(d) ~/ form embeds IDENTICALLY to the absolute path (regsub expanded via home_dir)" \
  [expr {[sd] eq $sdAbs}] "tilde-len=[string length [sd]] abs-len=[string length $sdAbs]"
# the log records the RAW ~/ form (not the expanded $HOME path)
set wantT [list xschem embed_rawfile ~/$HNAME]
set fd [open [xschem get actionlog_filename] r]; set allT [read $fd]; close $fd
set exactT ""; set sawExpanded 0
foreach l [split $allT \n] {
  if {$l eq $wantT} { set exactT $l }
  if {$l eq [list xschem embed_rawfile $HRAW] && $l ne $wantT} { }
}
check "(d) log records the RAW '~/' form (Tcl_Merge), not the expanded \$HOME path" \
  [expr {$exactT eq $wantT && [string match {*~/*} $exactT]}] "want=>$wantT< got=>$exactT<"
# replay the raw ~/ line -> re-expands + re-embeds identically
fixture
set trc [catch {uplevel #0 $wantT} tres]
check "(d) ~/ form REPLAYS without error (re-expands via home_dir)" [expr {$trc == 0}] "rc=$trc res=>$tres<"
check "(d) ~/ form replay re-embeds IDENTICALLY" [expr {[sd] eq $sdAbs}] "replay-len=[string length [sd]] abs-len=[string length $sdAbs]"
file delete -force $HRAW   ;# early drop; the exit hook above is the backstop

# ---------------------------------------------------------------------------
# (EINJ) ISSUE 0812 -- THE `~/` EXPANSION IS A TCL SPLICE, AND A FILENAME IS NOT
#     SCRIPT. run_core builds `regsub {^~/} {<argv[2]>} {<home_dir>/}` and
#     tcleval()s it, so a `}` in the path CLOSES the brace group and the rest of
#     the filename RUNS AS TCL -- measured on this tree, sentinel asserted.
#     doc/claude/issues/0812-extra-rawfile-substs-the-raw-path-so-a-crafted-filename-executes-tcl.md
#
#     ⚠ THE PAYLOAD SHAPE IS THE REGSUB ONE, NOT THE `subst` ONE AND NOT THE
#     ARRAY-INDEX ONE. save.c's sink falls to `q}; set ::SC_PWNED 1; list {a.raw`;
#     fed HERE that lands as `regsub {^~/} {..q}` -- too few arguments, the script
#     errors on command 1, the sentinel never runs and the row reports a clean
#     PWNED=0 over a live defect. The ARRAY-INDEX payload `$a([exec ...]).raw` is
#     likewise INERT here and was measured so (host file NOT created at HEAD):
#     this splice puts the path inside a BRACE GROUP, which performs no
#     substitution at all, so only a `}` escapes it. The regsub sink needs
#     `x} {y} {z}; set ::SC_PWNED 1; list {a`, and the payload itself must
#     contain NO SLASH or the name becomes a directory path that never reaches
#     the splice -- which is why EINJ2's `exec` target is reached through a
#     global variable instead of being spelled out.
#
#     ⚠ ASSERT THE SIDE EFFECT, NOT THE RETURN CODE. embed_rawfile then fails to
#     open the mangled name and blanks spice_data (wrinkle 3), so an
#     error-shaped row passes while the attacker's Tcl has already run. EINJ1
#     asserts the sentinel; EINJ2 asserts a FILE CREATED ON DISK, which is the
#     form no reader can argue with.
#
#     Check (d) above is the counterweight and stays green: the legitimate `~/`
#     form must still expand and embed IDENTICALLY to the absolute path.
# ---------------------------------------------------------------------------
set INJ [file join $SCRATCH "x\} \{y\} \{z\}; set ::SC_PWNED 1; list \{a"]
set fd [open $INJ w]; puts -nonewline $fd "injection payload raw"; close $fd
fixture
set ::SC_PWNED 0
catch {xschem embed_rawfile $INJ} injmsg
check "(EINJ1) a filename carrying Tcl is NOT executed by the '~/' regsub splice (sentinel, not rc)" \
  [expr {$::SC_PWNED == 0}] "SC_PWNED=$::SC_PWNED msg=>$injmsg<"

set ::OWN0812 [file join $SCRATCH OWNED_EMBED]
catch {file delete -force $::OWN0812}
set INJ2 [file join $SCRATCH "x\} \{y\} \{z\}; exec touch \$::OWN0812; list \{a"]
set fd [open $INJ2 w]; puts -nonewline $fd "injection payload raw"; close $fd
fixture
catch {xschem embed_rawfile $INJ2} injmsg2
set injowned [file exists $::OWN0812]
catch {file delete -force $::OWN0812}
check "(EINJ2) ...and it does not reach the HOST: `exec touch` in the path creates no file" \
  [expr {$injowned == 0}] "created=$injowned msg=>$injmsg2<"


# ---------------------------------------------------------------------------
# (e) REPLAY. embed_rawfile is a self-contained, re-executable verb (the path is in the
#     line): replaying re-reads the file + re-embeds. Through the replay_action_log
#     suppress seam the effect applies but does NOT re-log; a control unwrapped `source`
#     DOES re-log. WRINKLE 3: the external file must still exist -- the replay re-embeds the
#     SAME spice_data (asserted); a removed file would replay an empty attribute (caveat).
# ---------------------------------------------------------------------------
# canonical spice_data from a direct embed
fixture
xschem embed_rawfile $RAW
set sdCanon [sd]
set rec [file join [file dirname $LOG] paw_embed_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd [list xschem embed_rawfile $RAW]; close $fd

fixture
set nc [ec $RAW]
replay_action_log $rec
check "(e) replay seam: EFFECT applied (spice_data re-embedded)" [expr {[sd] ne {}}] "spice_data-len=[string length [sd]]"
check "(e) replay seam: external file present -> SAME spice_data (wrinkle 3 fidelity)" \
  [expr {[sd] eq $sdCanon}] "replay-len=[string length [sd]] canon-len=[string length $sdCanon]"
check "(e) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[ec $RAW] == $nc}] "nc=$nc now=[ec $RAW]"

fixture
set nc [ec $RAW]
uplevel #0 [list source $rec]
check "(e) control (unwrapped source): EFFECT applied (spice_data set)" [expr {[sd] ne {}}] "spice_data-len=[string length [sd]]"
check "(e) control (unwrapped source): re-logged (+1, re-executable action)" [expr {[ec $RAW] == $nc + 1}] "nc=$nc now=[ec $RAW]"
file delete $rec

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (the atom-1 no-double-push rule): the core embed_rawfile() OWNS the SINGLE
#     push_undo (captured BEFORE subst_token, so the snapshot has spice_data empty). The
#     fixture's undo stack holds the instance-place snapshot + embed's ONE push. So ONE
#     undo removes the spice_data and a SECOND removes the instance. A spurious run_core
#     double-push would capture the SAME pre-embed state, so the attribute would survive the
#     first undo (two undos needed).
# ---------------------------------------------------------------------------
fixture
xschem embed_rawfile $RAW
check "(f) undo depth: embed applied (spice_data set)" [expr {[sd] ne {}}] "spice_data-len=[string length [sd]]"
xschem undo
check "(f) undo depth: ONE undo removes the spice_data (attribute cleared)" \
  [expr {[xschem get instances] == 1 && [sd] eq {}}] "instances=[xschem get instances] spice_data=>[sd]<"
xschem undo
check "(f) undo depth: a SECOND undo removes the instance (R1 gone) -- the core's single push_undo is the ONLY embed snapshot; the discriminator is THIS second undo: with a single push undo#2 winds back past the place snapshot to empty (instances==0), but a run_core double-push would leave an identical extra R1-empty-spice_data snapshot so undo#2 restores THAT (instances stays 1, R1 survives). NB undo#1 clears the spice_data under BOTH single- and double-push -- it is undo#2 that distinguishes them" \
  [expr {[xschem get instances] == 0}] "instances=[xschem get instances]"

file delete -force $SCRATCH
catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
