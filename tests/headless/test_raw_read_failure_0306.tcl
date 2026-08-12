# test_raw_read_failure_0306.tcl — a failed raw read must leave the editor in
# the state it found it.
# doc/claude/issues/0306-a-failed-raw-read-leaves-a-state-the-next-operation-crashes-on.md
#
# TWO SIGSEGVs, one shape. A read fails, returns 0 into Tcl, the script carries
# on to the next line, and that line dereferences what the failure left behind.
#
#  PART 1  table_read() (src/save.c) probes with a bare open() and reads with
#          my_fopen(). The two disagree about S_ISREG, so a DIRECTORY or
#          /dev/null gets past the probe, reaches the my_calloc + int_hash_init,
#          then falls out of `if(fd)` into `err:` — which frees nothing. The
#          orphan left in xctx->raw has rawfile == NULL and sim_type == NULL and
#          is INVISIBLE: raw->level is -1, so `xschem raw loaded` still says -1.
#          The next non-spice read adopts it into the registry (extra_rawfile()
#          inserts whatever xctx->raw points at as entry 0) and dedups on
#          filename alone: strcmp(NULL, f). The spice arm survives only because
#          it tests sim_type first and short-circuits. ~250 KB leaks per attempt.
#          FIX: the one line vcd_read() has had at its `done:` label since it was
#          written — `if(xctx->raw) free_rawfile(&xctx->raw, 0, 1);` at `err:`.
#          Plus NULL-rawfile guards in the registry's lookup loops (defence in
#          depth; see the sabotage table — the pair is falsifiable, the guard is
#          not falsifiable on its own).
#
#          CAVEAT ON THE "no reachable producer" ARGUMENT, which SAB-2/SAB-7/
#          SAB-12 lean on. It is true of the REGISTRY, which is all those rows
#          claim, and it is NOT true of raw_read() in general: read_dataset()
#          has four malformed-header aborts that `goto` PAST its own
#          free_rawfile(), leaking the same ~250 KB Raw and destroying the
#          loaded database on the way (measured, 253,152 bytes). Those orphans
#          are never registered, so no NULL-rawfile entry results and the rows
#          stand — but "raw_read() frees on failure" is only true of its
#          fall-through path. Filed as issue 0316; deliberately NOT fixed here
#          (a third instance of the same shape, in a third function).
#
#  PART 2  the `set raw_level` arm of xschem_cmds_s (src/scheduler.c) range-checks
#          n but never tested xctx->raw. Both shipped callers — open_sub_schematic
#          and hi_descend's new-window arm — emit it on the line IMMEDIATELY after
#          `xschem raw_read`, without testing the result, and that arm CLEARS the
#          whole registry before it reads. So any failed read hands the setter a
#          NULL xctx->raw, as does a brand-new window's fresh context.
#          FIX: `if(xctx->raw && n >= 0 && n <= xctx->currsch)`; -1 is already
#          this arm's "did not take" answer, matching the getter, which has always
#          been guarded.
#
# ---------------------------------------------------------------------------
# THE SHAPE OF THE TEST, AND WHY IT IS SHAPED THAT WAY
# ---------------------------------------------------------------------------
# A SIGSEGV kills the process, and full_audit.sh scores the row CRASH on the
# fatal-signal banner appearing ANYWHERE in the output. A check written in the
# same process as the crash can therefore report nothing at all. So:
#
#   * every crash-provoking sequence runs in a CHILD xschem (--nogui, bounded by
#     timeout(1)); the parent never executes one and survives every path, so a
#     regression reads as FAIL with named ids instead of as an opaque CRASH.
#     Established in-tree pattern: test_undo_link_symbols.tcl,
#     test_wave_sigbrowser_i1315.tcl.
#   * THE FORGERY TRAP (load-bearing): child stdout is arbitrary text. Echoed
#     raw, a crashing child would force this row to CRASH and any child could
#     forge a pass. Child output goes to a FILE and is never printed unscrubbed:
#     `ctail` scrubs, and `zval` scrubs too, so every path from child stdout to
#     a detail line goes through `scrub`. It neutralises all SIX sentinels
#     full_audit.sh greps for (three in is_pass, three in is_skip -- the third
#     skip trigger, "SKIP: no X connection", was missing from the map until the
#     phase-3 review). The sentinels are BUILT at runtime so not one of them
#     appears literally in this file either. Every value compared against is a
#     literal containing no sentinel, so scrubbing cannot mask a mismatch. The
#     parent's own final banner is the only pass banner this file can emit.
#   * the in-process S band is safe before AND after the fix: the crash needs a
#     FOLLOWING non-spice read through the registry door, and every S check
#     starts with `xschem raw clear` (which NULLs xctx->raw unconditionally).
#
# `xschem raw info` is the orphan discriminator, not `xschem raw loaded`:
# extra_rawfile()'s what==4 arm appends "<idx> current\n" IFF xctx->raw is
# non-NULL, so pre-fix it answers "0 current" and post-fix it is empty — while
# `raw loaded` says -1 in both cases, which is exactly why the issue calls the
# orphan invisible. `raw loaded` is deliberately never used as evidence here.
#
# NOT ASSERTED HERE. (a) The leak: on the extra_rawfile() restore path the orphan
# is overwritten by `xctx->raw = save` and is invisible to every Tcl probe. It is
# the same allocation the free_rawfile() removes; measured out of band with
# valgrind and recorded in the receipt. (b) The fifo hang (table_read()'s probe
# open() blocks on a fifo with no writer, before my_fopen() is ever reached): a
# hanging check would kill the suite; filed as issue 0317. (c) The Waves menubar
# cue: free_rawfile() paints it grey unconditionally, so the new free at `err:`
# greyed it on the restore path while a good database was still current. Fixed
# by update_waves_menu_cue() after both restores in extra_rawfile(); the STATE it
# derives from is asserted headless by S7d, but has_x is 0 under --nogui so the
# pixel itself is not asserted anywhere and wants an eyeball.
#
# ---------------------------------------------------------------------------
# SABOTAGE TABLE — one mutation per claim, applied to the SOURCE, rebuilt, this
# suite re-run, reverted. 14 mutations, RE-MEASURED 2026-08-12 after the
# adversarial review moved several anchors. Every id below is a measured red,
# not an estimate, and SAB-6's list is enumerated rather than counted.
# ---------------------------------------------------------------------------
#  SAB-1  delete the whole discard+free block from table_read()'s `err:`
#           reds  C1r..C9r C1f..C9f C18r C19r S1b S2 S3 S4 S5  (25)
#           GREEN C1..C9, C18, C19 — the crash ids DO NOT fire, because the
#                 NULL-rawfile guards catch the orphan the missing free let
#                 through. That gap is the measurement of what they contribute.
#  SAB-1b delete ONLY the free_rawfile(), keep the discard dbg()
#           reds  C1r..C9r C18r C19r S1b S2 S3 S4 S5  (16) — the nine <id>f
#                 ids stay GREEN, which is what separates "the orphan was
#                 built" from "the orphan was freed". Pair with SAB-11.
#  SAB-2  revert the WHOLE NULL-rawfile guard sweep, all 7 sites (the free kept)
#           reds  NOTHING. A measured hole, and a STRUCTURAL one: with the free
#                 in place nothing reachable produces a NULL-rawfile registry
#                 entry, so the guards are falsifiable only in PAIRS. Both
#                 pairs are measured flips, not assertions:
#                   SAB-1 -> SAB-3 flips 10 ids: C1..C8 (dedup loop) + C18 C19
#                                   (the what==3 by-name arms)
#                   SAB-1 -> SAB-8 flips  9 ids: C1r..C9r (the `raw info` guard)
#                 THREE of the seven sites are unfalsifiable BY CONSTRUCTION,
#                 not by omission: the spice dedup loop, the what==2 switch
#                 loop and new_rawfile() all test sim_type BEFORE rawfile, and
#                 an orphan's sim_type is NULL too, so their strcmp is never
#                 reached. C20 measures that for new_rawfile() — the one of the
#                 three that also owns an adopt block — on the pre-fix tree.
#  SAB-3  SAB-1 + SAB-2 = the pre-fix tree
#           reds  C1..C8 C1r..C8r C1f..C9f C18 C19 S1b S2 S3 S4 S5 (32) — the
#                 measured reproduction of the SIGSEGV, through TEN doors.
#                 C9 stays green (it is the control), and so does C9r, because
#                 this state also removes the `raw info` guard: see SAB-8.
#  SAB-4  drop `xctx->raw &&` from the `set raw_level` arm
#           reds  C10 C11 C12 C13 C14 C15 C16 (7) — including BOTH end-to-end
#                 ids, i.e. the two shipped procs really do crash.
#  SAB-5  make that arm always refuse (`if(0 && xctx->raw && ...)`)
#           reds  S9 — the guard did not neuter the setter.
#  SAB-6  move the free from `err:` to before `return res` (free on SUCCESS too)
#           reds  C1..C7 C1r..C9r C1f..C9f C15 C16 C18r C19r S1b S2 S3 S4 S5
#                 (34) AND KILLS THE PARENT at S7b: the freed-but-successful
#                 read stores a NULL ENTRY POINTER in the registry and the next
#                 lookup dereferences extra_raw_arr[i] itself — a different
#                 mechanism from the NULL rawfile this issue is about, and the
#                 one mutation in this battery that the child-harness design
#                 does not contain. Recorded, not patched: a NULL entry needs a
#                 reader that returns success having produced nothing, which no
#                 shipped reader does, so guarding it would be a fourth
#                 unfalsifiable guard.
#  SAB-7  drop the NULL guard on the what==4 `raw info` append, alone
#           reds  NOTHING (same structural reason as SAB-2).
#  SAB-8  SAB-1 + SAB-7 — the pair that falsifies SAB-7
#           reds  C1f..C9f C18r C19r S1b S2 S3 S4 S5 (16). C1r..C9r GO BACK TO
#                 GREEN even though the orphan IS in the registry: the NULL
#                 ends that ONE Tcl_AppendResult() call, so the orphan's line
#                 loses its newline and merges with the next entry's, and the
#                 segment count is 2 again. (It ends the CALL, not the loop —
#                 the following entries still print. Traced wrong by one phase-3
#                 reviewer, who predicted C1r..C9r would red; measured green.)
#                 C18r/C19r survive the blinding because they assert an EMPTY
#                 listing, and "0 current" is still there.
#  SAB-9  `xctx->raw->level = n` -> `= n + 1` (the atoi->n edit on that line)
#           reds  S9b — the only id that can see it; S9 cannot, both spellings
#                 return the same number to Tcl.
#  SAB-10 widen the range check: `n <= xctx->currsch` -> `n <= CADMAXHIER - 1`
#           reds  S10b — and NOT S10, which is why S10b exists: 99 is out of
#                 range under both, so only the adjacent case can see the bound.
#  SAB-11 the issue's own second suggestion — probe with my_fopen() so the two
#         opens agree and the orphan is NEVER CREATED (this also cures the fifo
#         hang, issue 0317)
#           reds  C1f..C9f (9) and NOTHING ELSE. This is the measured answer to
#                 "can the C band tell 'the orphan was freed' from 'the orphan
#                 never existed'?" — the crash and registry ids cannot; the nine
#                 <id>f ids can, and they are the only reason a future tree that
#                 adopts this fix cannot silently delete the free_rawfile().
#  SAB-12 drop the new_rawfile() NULL-rawfile guard, alone
#           reds  NOTHING — see SAB-2's third paragraph and control C20.
#  SAB-13 delete both update_waves_menu_cue() calls
#           reds  NOTHING. An honest hole: has_x is 0 under --nogui, so the
#                 Waves menubar cue cannot be observed by any check in this
#                 file. What it is derived from — sch_waves_loaded() after the
#                 restore — IS asserted, by S7d. The pixel wants an eyeball.
#
# Run TRUE HEADLESS from the repo root (needs no display; it is in
# full_audit.sh's nogui_tests):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_raw_read_failure_0306.tcl

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
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}

# test_scratch owns the directory's lifetime (issue 0148).
set tmp [test_scratch raw0306]
proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}

# ---------------------------------------------------------------------------
# the forgery trap
# ---------------------------------------------------------------------------
set ::SIGMARK [format {%s: %s} FATAL signal]
set ::SCRUB [list \
  $::SIGMARK                        {F#TAL sig} \
  [format {%s() %s} Tcl_AppInit error] {Tcl_App#nit err} \
  [format {%s:} RESULT]             {R#SULT:} \
  [format {%s: %s} OVERALL ok]      {OV#RALL ok} \
  [format {%s: %s} skipped {no X}]  {sk#pped noX} \
  [format {%s: no X %s} SKIP connection] {SK#P noX conn}]
proc scrub {s} { return [string map $::SCRUB $s] }

# ---------------------------------------------------------------------------
# the child harness
# ---------------------------------------------------------------------------
set ::XBIN [info nameofexecutable]

# Run $body in a fresh --nogui xschem. Returns {rc captured_text}. Never prints.
#
# THE BODY IS WRAPPED IN A catch AND THE TIMEOUT IS SHORT, and both halves of
# that matter for the audit budget. A `--pipe --script` child that takes an
# UNCAUGHT Tcl error does not exit: it falls into the stdin loop and idles until
# something kills it. 24 children x a 60 s bound is 24 minutes against
# full_audit.sh's AUDIT_TIMEOUT of 120 s, so two idlers would have scored this
# row TIMEOUT/CRASH -- the opaque outcome the whole child design exists to
# avoid, and indistinguishable from the SIGSEGV it is here to detect. The
# wrapper turns any Tcl error into a prompt exit 9 with the message captured as
# Z_ERR (so the owning check reds with a readable detail instead of hanging),
# and 10 s is ~50x the ~0.2 s a child actually takes. `exit` inside the catch
# still exits: Tcl_Exit is not catchable.
proc run_child {tag body} {
  global tmp
  set script [file join $tmp c_$tag.tcl]
  set out    [file join $tmp c_$tag.out]
  wr $script "if {\[catch {\n$body\n} ::zerr\]} {\n  puts \"Z_ERR=\$::zerr\"\n  flush stdout\n  exit 9\n}\n"
  set rc 0
  if {[catch {exec timeout 10 $::XBIN --nogui --pipe -q --nolog --script $script >& $out} e opts]} {
    set ec {}
    catch {set ec [dict get $opts -errorcode]}
    switch -- [lindex $ec 0] {
      CHILDSTATUS { set rc [lindex $ec 2] }
      CHILDKILLED { set rc 139 }
      default     { set rc 1 }
    }
  }
  set txt {}
  if {[file exists $out]} { set fp [open $out r]; set txt [read $fp]; close $fp }
  # A child killed by a signal writes an on-disk-undo emergency save into /tmp.
  # Reap it here so neither a regression nor a sabotaged state litters the box.
  foreach {all d} [regexp -all -inline {EMERGENCY SAVE DIR: (\S+)} $txt] {
    if {[string match {*xschem_emergencysave*} $d]} { catch {file delete -force $d} }
  }
  return [list $rc $txt]
}
proc survived {r} {
  lassign $r rc txt
  return [expr {$rc == 0 && [string first Z_SURVIVED $txt] >= 0 \
                && [string first $::SIGMARK $txt] < 0}]
}
# zval returns the value ALREADY SCRUBBED: every one of these is child stdout,
# it all ends up interpolated into a check's detail line, and the forgery trap
# is only as good as its narrowest hole. (Z_TRIG / Z_INFO / Z_ERR are command
# results and error messages, so "the values are harmless in practice" was true
# but was not the invariant the header claimed.) Comparisons are against
# literals that contain no sentinel, so scrubbing cannot mask a real mismatch.
proc zval {r key} {
  lassign $r rc txt
  set v {}
  regexp "${key}=(\[^\n\r\]*)" $txt -> v
  return [scrub [string trim $v]]
}
# did the child's output contain $needle? Raw text, never printed.
proc zhas {r needle} {
  lassign $r rc txt
  return [expr {[string first $needle $txt] >= 0}]
}
# scrubbed tail of the child's output, for the check detail line
proc ctail {r} {
  lassign $r rc txt
  set one [string map [list \n { | } \r {}] $txt]
  return "rc=$rc tail='[scrub [string range $one end-180 end]]'"
}

# ---------------------------------------------------------------------------
# fixtures
# ---------------------------------------------------------------------------
set good  [file join $tmp good.tbl]
set vcd   [file join $tmp t.vcd]
set anraw [file join $tmp an.raw]
set adir  [file join $tmp adir]
set gone  [file join $tmp gone.raw]
set devnull /dev/null

wr $good "time a b\n0 0 1\n1 2 3\n2 4 5\n"
wr $vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
#100
1!
#200
"
wr $anraw "Title: i0306
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 3
Variables:
\t0\ttime\ttime
\t1\tv(n1)\tvoltage
Values:
0\t0.000000000000000e+00
\t1.000000000000000e+00

1\t1.000000000000000e-08
\t2.000000000000000e+00

2\t2.000000000000000e-08
\t3.000000000000000e+00

"
file mkdir $adir
file delete -force $gone

# ===========================================================================
# H — harness self-test. Nothing below is evidence unless these hold.
# ===========================================================================
set r [run_child h1 "puts Z_ALIVE\nflush stdout\nexit 3\n"]
check {H1 a child that exits 3 is reported rc=3 and NOT survived} \
  [expr {[lindex $r 0] == 3 && ![survived $r]}] [ctail $r]

set r [run_child h2 "puts Z_SURVIVED\nflush stdout\nexit 0\n"]
check {H2 a child that prints the marker and exits 0 is reported survived} \
  [survived $r] [ctail $r]

# H3 proves the harness can SEE a fatal signal without waiting for a sabotage
# run: the child raises SIGSEGV on itself and xschem's own handler prints the
# banner. If this is green, a C-band green means "did not crash", not "the
# detector is blind".
set r [run_child h3 "flush stdout\ncatch {exec kill -SEGV \[pid\]}\nafter 2000\nputs Z_SURVIVED\nflush stdout\nexit 0\n"]
check {H3 a child that segfaults is seen: NOT survived and the fatal banner is captured} \
  [expr {![survived $r] && [string first $::SIGMARK [lindex $r 1]] >= 0}] [ctail $r]

# H4 is the audit-budget guard. A `--pipe --script` child that takes an UNCAUGHT
# Tcl error does not exit — it falls into the stdin loop and idles until killed,
# which at the old `timeout 60` meant two such children could eat full_audit.sh's
# whole 120 s budget and score this row TIMEOUT. run_child wraps every body in a
# catch; this proves the wrapper fires and the child dies at once with rc 9.
set r [run_child h4 "error {H4 deliberate}\nputs Z_SURVIVED\nflush stdout\nexit 0\n"]
check {H4 a child that takes an uncaught Tcl error exits at once, it does not idle} \
  [expr {[lindex $r 0] == 9 && ![survived $r] && [zval $r Z_ERR] ne {}}] \
  "(rc=[lindex $r 0] want 9; Z_ERR='[zval $r Z_ERR]'; [ctail $r])"

# ===========================================================================
# C1..C9 — PART 1, crash absence. Each child makes the orphan, then triggers
# with a REGISTRY door (`xschem raw table_read` / `raw vcd_read`): the
# top-level `xschem table_read` verb clears the registry first and therefore
# never adopts, so it can orphan but cannot trigger. Each yields three ids
# (<id>, <id>r, <id>f); C17 and C20 are controls and C18/C19 are two more
# doors found by the phase-3 battery, further down.
# ===========================================================================
proc part1_child {orphan trigger} {
  return "
$orphan
flush stdout
catch {$trigger} zt
puts \"Z_TRIG=\$zt\"
catch {xschem raw vars} zv
puts \"Z_VARS=\$zv\"
catch {xschem raw info} zi
puts \"Z_INFO=\[string map \[list \\n { | }\] \$zi\]\"
puts Z_SURVIVED
flush stdout
exit 0
"
}
# Each part-1 child yields THREE ids, deliberately kept apart, because three
# different mutations falsify them:
#   <id>   the CRASH claim  — the process is alive and the following read worked.
#                             Flips only when BOTH the free and the dedup guard
#                             are gone (SAB-3).
#   <id>r  the STATE claim  — the failed read left the REGISTRY as it found it.
#                             Flips on the free alone (SAB-1). That gap IS the
#                             measurement of what the dedup guard contributes.
#   <id>f  the ENTRY claim  — the orphan was really BUILT and really DISCARDED.
#
# <id>f exists because the other two are assertions about the ABSENCE of a bad
# state, and absence has two causes: the state was cleaned up, or it was never
# created. A fix that stopped table_read() ever allocating on a non-regular path
# (fstat the probe fd for S_ISREG — the issue's own second suggestion, which
# also cures the fifo hang) would keep every crash and registry id green with
# the free_rawfile() deleted. Measured, not argued: that is sabotage SAB-11, and
# it reds exactly the nine <id>f ids and nothing else. The observable is the
# dbg(0) line table_read() prints at `err:` when — and only when — it has
# something to discard; C17 is the other side of it, a path that must NOT print
# it. `xschem raw loaded` cannot see any of this: it answers -1 either way.
set ::DISCARD [format {%s(): discarding the partially built database} table_read]

proc c_part1 {id orphan trigger want_trig want_vars want_file} {
  set tag [lindex [split $id] 0]
  set r [run_child $tag [part1_child $orphan $trigger]]
  set t [zval $r Z_TRIG]
  set v [zval $r Z_VARS]
  set zi [zval $r Z_INFO]
  check $id [expr {[survived $r] && $t eq $want_trig && $v eq $want_vars}] \
    "(Z_TRIG='$t' want '$want_trig'; Z_VARS='$v' want '$want_vars'; [ctail $r])"
  # `raw info` prints "<idx> current" then one line per registry entry, so a
  # clean registry after ONE successful read is exactly two segments. Counting
  # them (rather than grepping for "<NULL>") also catches the way an unguarded
  # Tcl_AppendResult mangles a NULL rawfile: the NULL ends that ONE call's
  # vararg list, so the orphan's line loses its trailing newline and MERGES with
  # the next entry's — two segments again, orphan hidden. Both halves of the
  # test are needed: the merge keeps the count at 2, the good file's name is
  # what proves the surviving segment is the good entry.
  set segs {}
  foreach s [split $zi |] { if {[string trim $s] ne {}} { lappend segs [string trim $s] } }
  check "${tag}r the failed read left NO orphan entry in the registry" \
    [expr {[llength $segs] == 2 && [string first [file tail $want_file] $zi] >= 0}] \
    "(segments=[llength $segs] want 2; Z_INFO='$zi')"
  check "${tag}f the orphan was actually built, and the reader said it discarded it" \
    [zhas $r $::DISCARD] "([ctail $r])"
}

set TRIG_TBL "xschem raw table_read $good"

c_part1 {C1 top-level `xschem table_read <dir>` orphans; next registry read must not crash} \
  "catch {xschem table_read $adir}" $TRIG_TBL 1 3 $good
c_part1 {C2 `xschem raw table_read <dir>` orphans} \
  "catch {xschem raw table_read $adir}" $TRIG_TBL 1 3 $good
c_part1 {C3 `xschem raw read <dir> table` orphans} \
  "catch {xschem raw read $adir table}" $TRIG_TBL 1 3 $good
c_part1 {C4 `xschem raw_read <dir> table` orphans (the spelling 1afca8a2 added)} \
  "catch {xschem raw_read $adir table}" $TRIG_TBL 1 3 $good
c_part1 {C5 `xschem raw table_read /dev/null` orphans} \
  "catch {xschem raw table_read $devnull}" $TRIG_TBL 1 3 $good
c_part1 {C6 `xschem raw_read /dev/null table` orphans} \
  "catch {xschem raw_read $devnull table}" $TRIG_TBL 1 3 $good
c_part1 {C7 two failed `raw table_read <dir>` in a row is the shortest form} \
  "catch {xschem raw table_read $adir}\ncatch {xschem raw table_read $adir}" $TRIG_TBL 1 3 $good
c_part1 {C8 the ARM not the reader: orphan then trigger with `raw vcd_read`} \
  "catch {xschem raw table_read $adir}" "xschem raw vcd_read $vcd" 1 2 $vcd
# C9 is a CONTROL for the CRASH ONLY: the spice dedup loop tests sim_type first
# and the orphan's sim_type is NULL, so it short-circuits — C9 is green before
# AND after and must never be read as evidence for the fix. Its registry twin
# C9r is NOT a control: it reds pre-fix like the others, because the orphan
# pollutes the spice arm's registry too. It just does not kill it.
c_part1 {C9 CONTROL the spice arm short-circuits on sim_type and never crashed} \
  "catch {xschem raw table_read $adir}" "xschem raw read $anraw tran" 1 2 $anraw

# C17 — the other side of the <id>f evidence. A NONEXISTENT path `goto err`s
# BEFORE the my_calloc, so there is nothing to discard and the line must not
# appear. Without this, "<id>f is green" would be consistent with table_read()
# printing the line unconditionally, which would make the nine <id>f ids
# unfalsifiable by SAB-11.
set r [run_child c17 "
catch {xschem raw table_read $gone} z1
puts \"Z_RET=\$z1\"
puts Z_SURVIVED
flush stdout
exit 0
"]
check {C17 CONTROL a nonexistent path allocates nothing, so it discards nothing} \
  [expr {[survived $r] && [zval $r Z_RET] eq {0} && ![zhas $r $::DISCARD]}] \
  "(Z_RET='[zval $r Z_RET]' want '0'; discard-line-present=[zhas $r $::DISCARD] want 0; [ctail $r])"

# ---------------------------------------------------------------------------
# C18/C19 — TWO MORE DOORS onto the same orphan, found by the phase-3 review
# battery and NOT in the issue. `xschem raw clear <file>` reaches
# extra_rawfile()'s what==3 by-name arm, whose two strcmp(rawfile, ...) had no
# guard AT ALL (unlike the spice lookup loops, which merely got away with it by
# testing sim_type first). The adopt block at the top of extra_rawfile() puts
# the orphan in slot 0 for this arm exactly as it does for the read arms, so
# both spellings segfault on the pre-fix tree — measured, both of them.
# These are what make the what==3 guards falsifiable: SAB-2 alone reds nothing
# anywhere, but SAB-1+SAB-2 reds these.
# ---------------------------------------------------------------------------
proc c_clear {id clearcmd} {
  global adir
  set tag [lindex [split $id] 0]
  set r [run_child $tag "
catch {xschem raw table_read $adir}
flush stdout
catch {$clearcmd} zc
puts \"Z_CLR=\$zc\"
catch {xschem raw info} zi
puts \"Z_INFO=\[string map \[list \\n { | }\] \$zi\]\"
puts Z_SURVIVED
flush stdout
exit 0
"]
  check $id [expr {[survived $r] && [zval $r Z_CLR] eq {0}}] \
    "(Z_CLR='[zval $r Z_CLR]' want '0'; [ctail $r])"
  check "${tag}r and the registry is still empty, not holding an adopted orphan" \
    [expr {[zval $r Z_INFO] eq {}}] "(Z_INFO='[zval $r Z_INFO]' want '')"
}
c_clear {C18 `xschem raw clear <file>` after an orphan (what==3 by-name arm)} \
  "xschem raw clear $good"
c_clear {C19 `xschem raw clear <file> <type>` after an orphan (the typed arm)} \
  "xschem raw clear $good table"

# C20 documents why the sweep's remaining three sites cannot be falsified: they
# all test sim_type BEFORE rawfile, and the orphan's sim_type is NULL too, so
# the strcmp is never reached. new_rawfile() is the one that also owns an adopt
# block, i.e. the one where "unreachable" is least obvious — measured green on
# the pre-fix tree, so its guard is defence in depth against a future producer,
# not a fix for anything reachable today.
set r [run_child c20 "
catch {xschem raw table_read $adir}
flush stdout
catch {xschem raw new n0306 tran t 0 1 0.1} zn
puts \"Z_NEW=\$zn\"
puts Z_SURVIVED
flush stdout
exit 0
"]
check {C20 CONTROL `raw new` after an orphan survived pre-fix too (sim_type short-circuit)} \
  [expr {[survived $r] && [zval $r Z_NEW] eq {1}}] \
  "(Z_NEW='[zval $r Z_NEW]' want '1'; [ctail $r])"

# ===========================================================================
# C10..C14 — PART 2, crash absence. Each asserts BOTH "no crash" and "the arm
# answers its existing -1", so one child proves the guard is present and that
# it reports the refusal the way the out-of-range case already does.
# ===========================================================================
proc part2_child {setup} {
  return "
$setup
flush stdout
catch {xschem set raw_level 0} zr
puts \"Z_RL=\$zr\"
puts Z_SURVIVED
flush stdout
exit 0
"
}
proc c_part2 {id setup} {
  set r [run_child [lindex [split $id] 0] [part2_child $setup]]
  set v [zval $r Z_RL]
  check $id [expr {[survived $r] && $v eq {-1}}] \
    "(Z_RL='$v' want '-1'; [ctail $r])"
}

c_part2 {C10 repro (a): raw_read of a missing file, then set raw_level} \
  "catch {xschem raw_read $gone tran}"
c_part2 {C11 repro (b): wrong declared type on a real file (0290 requires it to fail)} \
  "catch {xschem raw_read $good tran}"
c_part2 {C12 repro (c): clear-then-fail destroys a LOADED database, then set raw_level} \
  "catch {xschem raw table_read $good}\ncatch {xschem raw_read $gone tran}"
c_part2 {C13 the `op` branch: annotate_op of a missing file, then set raw_level} \
  "catch {xschem annotate_op $gone}"
c_part2 {C14 a virgin context: nothing was ever loaded} \
  "# nothing loaded at all"

# ===========================================================================
# C15/C16 — PART 2 END TO END, the user's path. The two shipped procs emit the
# failing read and the setter on consecutive lines with no test in between.
# Group C10-C14 can be green while these crash, because these go through the
# Tcl round trip in a NEW window.
# ===========================================================================
set fixroot [file normalize [file join [file dirname [info script]] fixtures hi_descend]]
set lib [file join $fixroot hidlib]
set top [file join $lib top schematic top.sch]
set e2e_tbl [file join $tmp e2e.tbl]

proc e2e_child {lib top tbl proc_call} {
  return "
lappend pathlist $lib
xschem load $top
xschem unselect_all
catch {xschem raw table_read $tbl} z1
puts \"Z_LOAD=\$z1\"
puts \"Z_WAVES=\[xschem raw loaded\]\"
file delete -force $tbl
flush stdout
catch {$proc_call} zp
puts \"Z_PROC=\$zp\"
puts Z_SURVIVED
flush stdout
exit 0
"
}
proc c_e2e {id proc_call} {
  global lib top e2e_tbl good
  file copy -force $good $e2e_tbl
  set r [run_child [lindex [split $id] 0] [e2e_child $lib $top $e2e_tbl $proc_call]]
  set w [zval $r Z_WAVES]
  set p [zval $r Z_PROC]
  check $id [expr {[survived $r] && $w eq {0} && $p eq {1}}] \
    "(Z_WAVES='$w' want '0'; Z_PROC='$p' want '1'; [ctail $r])"
}

c_e2e {C15 open_sub_schematic carries a rawfile that has since been deleted} \
  "open_sub_schematic x1"
c_e2e {C16 hi_descend's new-window arm does the same} \
  "hi_descend inst=x1 target=new_window"
catch {file delete -force $e2e_tbl}

# ===========================================================================
# S1..S11 — in-process state. All safe before AND after the fix.
# ===========================================================================
proc rclear {} { pcall xschem raw clear }
# `raw info` is empty exactly when xctx->raw is NULL (extra_rawfile what==4).
proc rinfo {} { return [string trim [pcall xschem raw info]] }
proc info_has {f type} {
  return [string match "*[file tail $f] $type*" [pcall xschem raw info]]
}

rclear
# S1 is a SMOKE check, not evidence: S6 shows a nonexistent path returns 0 too,
# so "returns 0" on its own distinguishes nothing. S1b carries the claim.
eqcheck {S1 SMOKE `raw table_read <dir>` returns 0} [pcall xschem raw table_read $adir] 0
eqcheck {S1b and leaves NO orphan in xctx->raw (`raw info` empty)} [rinfo] {}

rclear
pcall xschem raw table_read $devnull
eqcheck {S2 /dev/null leaves no orphan} [rinfo] {}

rclear
pcall xschem raw read $adir table
eqcheck {S3 `raw read <dir> table` leaves no orphan} [rinfo] {}

rclear
pcall xschem raw_read $adir table
eqcheck {S4 `raw_read <dir> table` leaves no orphan} [rinfo] {}

rclear
pcall xschem table_read $adir
eqcheck {S5 top-level `table_read <dir>` leaves no orphan} [rinfo] {}

rclear
eqcheck {S6 CONTROL a nonexistent path returns 0} [pcall xschem raw table_read $gone] 0
eqcheck {S6b CONTROL and always was safe (open() fails before the my_calloc)} [rinfo] {}

# ANTI-OVER-FREE, and precisely which path it covers. S7b is the
# extra_rawfile() RESTORE branch: the arm stashes the live database in `save`,
# NULLs xctx->raw, the reader builds an orphan and frees it at `err:`, and the
# arm puts `save` back. So S7c/S7d/S7e assert that the new free took the orphan
# and NOT the caller's database. (This is also the leak path the issue measured:
# pre-fix `xctx->raw = save` was what overwrote the only pointer to the orphan.)
#
# It is NOT table_read()'s ENTRY guard: every shipped caller NULLs xctx->raw
# before calling a reader, so that guard is unreachable and nothing here can
# exercise it. The nearest measured relative is SAB-6, which moves the free onto
# the success path and kills the parent right here, at S7b.
rclear
eqcheck {S7 a good table loads} [pcall xschem raw table_read $good] 1
eqcheck {S7b a FAILING read after it still returns 0} [pcall xschem raw table_read $adir] 0
eqcheck {S7c and the good database is UNTOUCHED: vars} [pcall xschem raw vars] 3
check   {S7d and still current: `raw loaded` >= 0} [expr {[pcall xschem raw loaded] >= 0}] \
  "(loaded=[pcall xschem raw loaded])"
check   {S7e and the registry lists exactly the one good file} \
  [expr {[info_has $good table] && ![string match {*adir*} [pcall xschem raw info]]}] \
  "(info='[string map [list \n { | }] [rinfo]]')"

rclear
pcall xschem raw table_read $good
check   {S8 POSITIVE CONTROL a good table is listed by `raw info` as type table} \
  [info_has $good table] "(info='[string map [list \n { | }] [rinfo]]')"

# Part 2, in-process: the guard must not neuter the setter.
eqcheck {S9 with a database loaded, `set raw_level 0` still takes} \
  [pcall xschem set raw_level 0] 0
# S9b is the ONLY check that can see the `atoi(argv[3])` -> `n` edit on the
# assignment line (both spellings produce the same number, so S9 cannot).
eqcheck {S9b and the getter agrees, i.e. the level that was WRITTEN is n} \
  [pcall xschem get raw_level] 0
eqcheck {S10 the range check is preserved: a far out-of-range level is refused} \
  [pcall xschem set raw_level 99] -1
# S10b is the ADJACENT out-of-range case, one past currsch (which is 0 here:
# nothing was descended into). It exists so the upper bound has a mutation that
# does not walk off xctx->sch[CADMAXHIER] — 99 does, and a sabotage whose
# observable is undefined behaviour measures nothing. SAB-10 widens the bound to
# CADMAXHIER-1: S10 stays green, S10b reds.
eqcheck {S10b and the bound is currsch, not merely "some bound": level 1 is refused} \
  [pcall xschem set raw_level 1] -1

rclear
eqcheck {S11 CONTROL getter symmetry: with nothing loaded the getter answers -1} \
  [pcall xschem get raw_level] -1
# NOTE there is deliberately no in-process "set raw_level with nothing loaded"
# check: pre-fix that is the SIGSEGV itself, and a parent that dies scores the
# whole row CRASH with no ids. C14 makes exactly that assertion, in a child.

rclear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_raw_read_failure_0306: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
