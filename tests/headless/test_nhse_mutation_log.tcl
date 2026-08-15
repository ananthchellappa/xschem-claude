# Action-log coverage -- the Net Highlight Style editor's commits record
# replayable lines (issue 0065, issue 0071 atom 8).
#
# The editor is a STAGED dialog: every edit restages the net_hilight_style Tcl
# var (apply=0); nhse_apply_live is the single staged->live point (Apply / OK /
# Cancel-revert). It now logs the SELF-CONTAINED table line
#     net_hilight_style_replace {<full table>}
# (a bare `xschem update_net_hilight_style` would replay against the ambient
# var -- the atom-3 self-contained-line rule). nhse_reset commits live outside
# that seam and logs `net_hilight_style_reset`; nhse_save logs the resolved
#     write_net_hilight_style_conf {<path>}
# on the success arm only. Machinery stays silent: the scripting helpers
# (net_hilight_style_replace/... apply=1) and the startup conf-file source call
# `xschem update_net_hilight_style` directly and never log.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_nhse_mutation_log.tcl

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
# On a display-less box Tk never loads: nhse_rebuild's winfo (via nhse_reset) and
# the tk_getSaveFile/tk_messageBox renames would be invalid-command CRASHES, not
# skips (atom-8 review) -- self-skip like every other GUI test.
if {[info commands winfo] eq {}} {
  puts "SKIP: no Tk (display-less session)"
  puts "RESULT: SKIP (no Tk)"
  exit 0
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set work /tmp/atom8_nhse_mutation_log_work.[pid]
file delete -force $work; file mkdir $work

proc logcountf {f pat} {
  if {[catch {open $f r} fd]} { return -1 }
  set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
proc logcount {pat} { return [logcountf [xschem get actionlog_filename] $pat] }
# count of ANY staged->live table line (prefix match)
proc replcount {} { return [logcount {net_hilight_style_set_live *}] }

set save_table $::net_hilight_style   ;# restore at the end

# ---------------------------------------------------------------------------
# A) Apply / OK / Cancel log the self-contained table line, exactly once
# ---------------------------------------------------------------------------
# distinctive staged table (colors by name; no glob metachars)
set T1 {{0 red 3 {6 4} 15 250 march_fwd 4} {1 orange 1 {} 0 0 none 0}}
set c0 [replcount]
net_hilight_style_replace $T1 0            ;# STAGE only (editor-style edit): machinery, no log
check "A1 staging (apply=0) logs nothing" [expr {[replcount] == $c0}] \
  "c0=$c0 now=[replcount]"

set expline [list net_hilight_style_set_live $::net_hilight_style]
set c0 [logcount $expline]
nhse_apply
check "A2 nhse_apply logs the full staged table exactly once" \
  [expr {[logcount $expline] == $c0 + 1}] "line={$expline}"
check "A2 table is live-normalized (row 0 keeps the custom color)" \
  [expr {[lindex [lindex $::net_hilight_style 0] 1] eq {red}}]

set c0 [logcount $expline]
nhse_ok
check "A3 nhse_ok logs the table line exactly once more" \
  [expr {[logcount $expline] == $c0 + 1}]

# Cancel: restores the open-time snapshot and pushes THAT live -> logs the snapshot
set SNAP {{0 blue 2 {} 0 0 none 0}}
set ::nhse_snapshot [net_hilight_style_replace $SNAP 0]   ;# normalized snapshot value
net_hilight_style_replace $T1 0                            ;# stage something else
set snapline [list net_hilight_style_set_live $::nhse_snapshot]
set c0 [logcount $snapline]
nhse_cancel
check "A4 nhse_cancel restores the snapshot" \
  [expr {$::net_hilight_style eq $::nhse_snapshot}]
check "A4 nhse_cancel logs the restored snapshot exactly once" \
  [expr {[logcount $snapline] == $c0 + 1}] "line={$snapline}"
unset -nocomplain ::nhse_snapshot

# Raw-value fidelity (atom-8 review): a sloppy hand-set table (documented manual
# workflow, hilight.c:418) must be logged VERBATIM -- the C parser and the Tcl
# normalizer coerce sloppy fields differently (width 2.5: C atoi -> 2, norm -> 1),
# so a normalizing log form would replay a different live state than the session.
set RAW {{0 red 2.5 {} 0 0 none 0}}
set ::net_hilight_style $RAW
set ::nhse_snapshot $RAW
set rawline [list net_hilight_style_set_live $RAW]
set c0 [logcount $rawline]
nhse_cancel
check "A6 sloppy raw table is logged verbatim (width 2.5 preserved)" \
  [expr {[logcount $rawline] == $c0 + 1}] "line={$rawline}"
eval $rawline
check "A6 replaying the raw line keeps the var verbatim (no normalization)" \
  [expr {$::net_hilight_style eq $RAW}]
unset -nocomplain ::nhse_snapshot

# Reset: live immediately, own bare line
set c0 [logcount {net_hilight_style_reset}]
nhse_reset
check "A5 nhse_reset logs its bare line exactly once" \
  [expr {[logcount {net_hilight_style_reset}] == $c0 + 1}]
check "A5 reset re-derived a non-empty default table" \
  [expr {[llength $::net_hilight_style] > 0}]

# ---------------------------------------------------------------------------
# B) machinery stays silent
# ---------------------------------------------------------------------------
set c0 [replcount]; set r0 [logcount {net_hilight_style_reset}]
xschem update_net_hilight_style            ;# direct C recompile (startup-source form)
net_hilight_style_replace $T1 1            ;# scripting helper, live apply
net_hilight_style_set_live $T1             ;# the replay form itself is silent (channel records typed calls)
net_hilight_style_reset                    ;# scripting reset
check "B1 direct update / scripted replace / set_live / scripted reset log nothing" \
  [expr {[replcount] == $c0 && [logcount {net_hilight_style_reset}] == $r0}] \
  "repl $c0->[replcount] reset $r0->[logcount {net_hilight_style_reset}]"

# ---------------------------------------------------------------------------
# C) Save: resolved-path line on success only (counting stubs)
# ---------------------------------------------------------------------------
array set ::stubn {getsave 0 msgbox 0}
set ::stub_save_path {}
rename tk_getSaveFile ::atom8_orig_getsave
proc tk_getSaveFile {args} { incr ::stubn(getsave); return $::stub_save_path }
rename tk_messageBox ::atom8_orig_msgbox
proc tk_messageBox {args} { incr ::stubn(msgbox); return ok }

set c0 [logcount {write_net_hilight_style_conf *}]
nhse_save                                   ;# stub returns {} = dialog Cancel
check "C1 Save dialog-Cancel consulted the file dialog" [expr {$::stubn(getsave) == 1}]
check "C1 Save dialog-Cancel logs nothing" \
  [expr {[logcount {write_net_hilight_style_conf *}] == $c0}]

# F2 lock (atom-8 review): Save writes the STAGED var -- stage a table WITHOUT
# applying, so the log's last set_live line (from section A/B) differs from what
# Save writes; the staged-table `set` line must carry the STAGED value or a
# replay writes the wrong table to the path.
set STAGED {{0 green 4 {2 3} -10 0 none 0}}
net_hilight_style_replace $STAGED 0
set ::stub_save_path [file join $work styles_out]
set expset  [list set ::net_hilight_style $::net_hilight_style]
set expsave [list write_net_hilight_style_conf $::stub_save_path]
set c0 [logcount $expsave]; set s0 [logcount $expset]
nhse_save
check "C2 Save success logs the resolved path exactly once" \
  [expr {[logcount $expsave] == $c0 + 1}] "line={$expsave}"
check "C2 Save logs the STAGED table set-line exactly once (not the last applied)" \
  [expr {[logcount $expset] == $s0 + 1}] "line={$expset}"
check "C2 the styles file was written" [file isfile $::stub_save_path]
check "C2 written file parses back to the staged table" \
  [expr {[nhse_parse_style_file $::stub_save_path] eq $::net_hilight_style}]
check "C2 staged Save did not push the staged table live-logged (set-line, not set_live)" \
  [expr {[logcount [list net_hilight_style_set_live $::net_hilight_style]] == 0}]

set ::stub_save_path [file join $work no_such_dir styles_out]
set c0 [logcount {write_net_hilight_style_conf *}]
set m0 $::stubn(msgbox)
nhse_save                                   ;# open fails -> error arm
check "C3 Save write-failure logs nothing" \
  [expr {[logcount {write_net_hilight_style_conf *}] == $c0}]
check "C3 Save write-failure raised the error box" [expr {$::stubn(msgbox) == $m0 + 1}]

rename tk_getSaveFile {}; rename ::atom8_orig_getsave tk_getSaveFile
rename tk_messageBox {}; rename ::atom8_orig_msgbox tk_messageBox

# ---------------------------------------------------------------------------
# D) replay: re-eval logged lines in-process
# ---------------------------------------------------------------------------
net_hilight_style_replace $T1 0
nhse_apply                                  ;# record the T1 commit
set want $::net_hilight_style
set line [list net_hilight_style_set_live $want]
net_hilight_style_reset                     ;# scramble (silent scripting reset)
check "D0 table scrambled before replay" [expr {$::net_hilight_style ne $want}]
eval $line
check "D1 replayed table line restores the exact table" \
  [expr {$::net_hilight_style eq $want}]
eval {net_hilight_style_reset}
check "D2 replayed reset line re-derives the default" \
  [expr {$::net_hilight_style ne $want && [llength $::net_hilight_style] > 0}]

# ---------------------------------------------------------------------------
# E) --nogui child: the logged commit lines replay with no Tk loaded, and
#    nhse_apply still records there (atom-7 lesson: prove the seam headless)
# ---------------------------------------------------------------------------
set XSCHEM [file join $REPO src xschem]
set childscript $work/ng_child.tcl
set fp [open $childscript w]
puts $fp {set rc1 [catch {net_hilight_style_replace {{0 red 3 {6 4} 15 250 march_fwd 4}} 1} e1]}
puts $fp {set rc2 [catch {nhse_apply} e2]}
puts $fp {set rc3 [catch {net_hilight_style_reset} e3]}
puts $fp "set fp \[open [list $work/ng_rc] w\]; puts \$fp \[list \$rc1 \$rc2 \$rc3 \$e1 \$e2 \$e3\]; close \$fp"
puts $fp {exit 0}
close $fp
set nglogdir $work/ng_logdir; file mkdir $nglogdir
catch {exec $XSCHEM --nogui --pipe -q --logdir $nglogdir --script $childscript \
         < /dev/null > $work/ng.out 2> $work/ng.err}
set nglog [file join $nglogdir Xschem.log]
check "E1 --nogui child ran and wrote a log" [file exists $nglog]
set ngres {9 9 9}
catch {set fp [open $work/ng_rc r]; set ngres [string trim [read $fp]]; close $fp}
check "E2 replace/apply/reset all survive with no Tk" \
  [expr {[lrange $ngres 0 2] eq {0 0 0}}] "rc,err=$ngres"
check "E3 nhse_apply recorded its table line in the --nogui log" \
  [expr {[logcountf $nglog {net_hilight_style_set_live *}] >= 1}] \
  "n=[logcountf $nglog {net_hilight_style_set_live *}]"

# ---------------------------------------------------------------------------
# F) delete-last-row live-commit (atom-8 review): emptying the table makes
#    nhse_rebuild's net_hilight_style_current re-materialize the layer default
#    LIVE, outside the apply seam -- it must log the materialized table. The
#    rebuild path needs the editor's table-body widget; plain frames suffice.
# ---------------------------------------------------------------------------
proc logtext {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  return $b
}
frame .nhse; frame .nhse.tbl; frame .nhse.tbl.sf; frame .nhse.tbl.sf.body
net_hilight_style_replace {{0 red 3 {6 4} 15 250 march_fwd 4}} 1  ;# 1-row live table (scripted, silent)
nhse_rebuild                      ;# sync the row widgets to the table (editor flow)
set ::nhse_focus_row 0
set c0 [replcount]
nhse_op_delete
check "F1 delete-last-row re-materialized a non-empty default live" \
  [expr {[llength $::net_hilight_style] > 0}]
# the C-materialized default is a MULTILINE Tcl value (indented rows), so the
# logged line spans physical lines inside balanced braces (the accepted
# multi-line class) -- assert via whole-text match, count via the line prefix.
check "F1 delete-last-row logged the materialized table exactly once" \
  [expr {[replcount] == $c0 + 1 && \
         [string match "*[list net_hilight_style_set_live $::net_hilight_style]*" [logtext]]}] \
  "repl $c0->[replcount]"
check "F1 logged multiline segment is a complete sourceable command" \
  [info complete "[list net_hilight_style_set_live $::net_hilight_style]\n"]
# a NON-last delete stays staged-only and silent
net_hilight_style_replace {{0 red 1 {} 0 0 none 0} {1 blue 1 {} 0 0 none 0}} 1
nhse_rebuild                      ;# re-sync widgets (else nhse_flush re-commits stale rows)
set ::nhse_focus_row 1
set c0 [replcount]
nhse_op_delete
check "F2 non-last delete stays staged and logs nothing" \
  [expr {[replcount] == $c0 && [llength $::net_hilight_style] == 1}] \
  "repl $c0->[replcount] rows=[llength $::net_hilight_style]"
destroy .nhse

# restore the session table
set ::net_hilight_style $save_table
catch { xschem update_net_hilight_style }
file delete -force $work
catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
