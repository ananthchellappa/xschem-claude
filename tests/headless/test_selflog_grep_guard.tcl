# Action-log GREP GUARD (issue 0071 atom 5) -- an executable inventory of the
# self-log-at-core migration, so the invariants cannot silently regress.
#
# The audit's root-cause finding: "we logged verb X, but only from the menu, not
# the key" recurred 3+ times AFTER being named -- human discipline does not hold.
# This test makes the discipline structural, in four static scans + one runtime
# canary:
#   S1  MANIFEST -- every landed self-log site still contains its log_action call
#       (a refactor that drops one fails exactly that row). Gate-locking rows pin
#       the save `!fast` and Ctrl-S `!readonly` guards, not just the calls.
#   S2  TCL LITERAL-LOG CONFLICTS -- no .tcl file hand-logs a literal
#       "xschem <verb>" line for a verb whose C side self-logs, unless the write
#       is dedup-gated on `log_action -emitted` (the action_reload double of
#       atom 4 and the library_manager `load -gui` double fixed with this atom
#       are exactly this class).
#   S3  BRANCH-MUST-NOT-LOG -- verbs whose log lives in a core C function
#       (save.c/actions.c/select.c) must have NO log_action in their scheduler
#       branch, or menu/script paths double-log (the slice-6 lesson).
#   S4  RECORDER DEDUP WIRING -- the four dedup-wired recorders keep their
#       reset/-emitted plumbing; losing it double-logs every covered verb.
#   S5  RUNTIME CANARY -- a cheap end-to-end exactly-once check (script path +
#       menu_action_logged dedup), so a suppress-flag/dedup breakage that static
#       text scans cannot see still fails.
#
# MAINTENANCE: adding a new C self-log means (a) adding its S1 manifest row and
# (b) adding the verb to the S2 conflict set. That is the intended ratchet.
# Atom 9 (0069 paste_at) added: the paste/merge drop-log site + merge_source
# stash rows, the scheduler paste replay-arm rows, `paste` in S2 + S3, and the
# S1c must-NOT-reappear scans (old marker / ctx-menu pick-8 literal).
# The library_manager do_* mutation seam (atom 7 / 0064) is Tcl-only and its
# `libmgr::do_*` lines don't start with "xschem " (S2-invisible), so it is
# locked twice: the S1 site-count row (line-anchored, comments don't count)
# and the S1b closure scan, which enumerates every `proc libmgr::do_*` and
# fails any worker that neither logs its own name nor sits on the read-only
# allowlist -- a NEW unlogged worker fails closed with no row bump needed.
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md
#
# Needs the action log open (S5) -> registered in full_audit.sh logdir_tests:
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_selflog_grep_guard.tcl

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
proc srctext {rel} {
  set fd [open [file join $::REPO $rel] r]; set t [read $fd]; close $fd
  return $t
}
proc rxcount {text re} { return [regexp -all -- $re $text] }

# ---------------------------------------------------------------------------
# S1) MANIFEST: every self-log site is still present.  {file {regex min label}...}
# ---------------------------------------------------------------------------
set MANIFEST {
  src/scheduler.c {
    {log_action\("xschem cut"}                        1 {cut branch}
    {log_action\("xschem delete"}                     1 {delete branch}
    {log_action\("xschem copy"}                       1 {copy branch (atom 4)}
    {log_action\("xschem undo"}                       1 {undo branch}
    {log_action\("xschem redo"}                       1 {redo branch}
    {if\(!fast\) log_action\("xschem save"}           1 {save branch incl. fast-machinery gate (atom 4)}
    {log_action\("xschem reload%s"}                   1 {reload branch incl. zoom_full arg (atom 4)}
    {log_action\("xschem align"}                      1 {align branch}
    {log_action\("xschem trim_wires"}                 1 {trim_wires branch}
    {log_action\("xschem break_wires 1"}              1 {break_wires remove form}
    {log_action\("xschem break_wires"\)}              1 {break_wires bare form}
    {log_action\("xschem flip %}                      1 {flip branch (pivot form)}
    {log_action\("xschem flipv %}                     1 {flipv branch}
    {log_action\("xschem rotate %}                    1 {rotate branch}
    {log_action\("xschem flip_in_place"}              1 {flip_in_place branch}
    {log_action\("xschem flipv_in_place"}             1 {flipv_in_place branch}
    {log_action\("xschem rotate_in_place"}            1 {rotate_in_place branch}
    {log_action\("xschem change_elem_order %d"}       1 {change_elem_order branch}
    {log_action\("xschem check_unique_names}          1 {check_unique_names branch}
    {log_action\("xschem create_instance"}            1 {create_instance branch}
    {log_action\("xschem floaters_from_selected_inst"} 1 {floaters branch}
    {log_action\("xschem print_hilight_net}           1 {print_hilight_net branch}
    {log_action\("xschem exit closewindow force"}     2 {exit hook (both terminating sites)}
    {log_action\("xschem set cadgrid}                 1 {set cadgrid resolved-value}
    {log_action\("xschem set cadsnap}                 1 {set cadsnap resolved-value}
    {log_action\("xschem set rectcolor}               1 {set rectcolor}
    {"xschem hilight_net_interactive" : "xschem unhilight_net_interactive"} 1 {hilight interactive noun-verb (ternary log)}
    {log_action\("xschem library_manager}             1 {library_manager open}
    {log_action_stash_select_at}                      1 {select_at stash flush}
    {if\(!\(xctx->ui_state & STARTMERGE\)\)}          1 {paste replay arm: pending-merge completion gate (atom 9)}
    {merge_file\(8, f\)}                              1 {paste replay arm: -file merge form (atom 9)}
    {!strcmp\(argv\[k\], "-anchor"\)}                 1 {paste replay arm: -anchor pivot parse (atom 9 review)}
  }
  src/callback.c {
    {log_action\("xschem copy"}                       1 {Ctrl-C inline key (atom 4)}
    {if\(!xctx->readonly\) log_action\("xschem save"} 1 {Ctrl-S inline key incl. readonly gate (atom 4)}
    {log_action\("xschem reload"}                     1 {Alt-S inline key ok-arm (atom 4)}
    {log_action\("xschem cut"}                        1 {Ctrl-X inline key (atom 2)}
    {log_action\("xschem delete"}                     1 {Delete inline key (atom 2)}
    {log_action\("xschem change_elem_order -1"}       1 {Shift-S inline key}
    {log_action\("xschem align"}                      1 {Alt-U inline key}
    {log_action\("xschem trim_wires"}                 1 {'&' inline key}
    {log_action\("xschem break_wires 1"}              1 {Ctrl-! inline key}
    {log_action\("xschem break_wires"\)}              1 {'!' inline key}
    {log_action\("xschem flip %}                      2 {Shift-F key + move-END}
    {log_action\("xschem flipv %}                     2 {Shift-V key + move-END}
    {log_action\("xschem rotate %}                    2 {Shift-R key + move-END}
    {log_action\("xschem pan %}                       1 {drag-pan END}
    {log_action\("xschem zoom_box %}                  1 {zoom-drag END}
    {(?n)^\s*av\[ac\+\+\] = "xschem"; av\[ac\+\+\] = "paste";} 1 {paste/merge drop replay line (atom 9 / 0069)}
    {(?n)^\s*av\[ac\+\+\] = "-file";}                 1 {paste/merge drop -file source rider (atom 9)}
    {(?n)^\s*av\[ac\+\+\] = "-anchor";}               1 {paste/merge drop -anchor pivot rider: whole-log replay regenerates the clipboard G record (atom 9 review)}
    {(?n)^\s*log_action_argv\(ac, av\);}              1 {paste/merge drop emit call, line-anchored: if(0)/line-comment counts as removed (a BLOCK comment still evades -- the behavioral test is the real lock) (atom 9)}
  }
  src/paste.c {
    {(?n)^\s*my_strncpy\(xctx->merge_source,}         1 {merge_file source stash for the drop logger (atom 9)}
    {(?n)^\s*xctx->ui_state &= ~STARTMERGE;}          1 {merge_file empty-merge dangling-flag clear (atom 9 review: a dangler mislogs the next move drop as a paste)}
  }
  src/actions.c {
    {log_action\("xschem saveas \{%s\}}               1 {saveas dialog-resolution arm}
    {log_action\("xschem load \{%s\}"}                1 {load ask-dialog arm}
    {log_action\("xschem load_new_window \{%s\}"}     1 {load_new_window ask-dialog arm}
    {log_action_descend\("descend"}                   1 {descend core self-contained -inst form}
    {log_action\("xschem go_back"\)}                  1 {go_back core bare form (atom 3)}
    {log_action\("xschem go_back %d"}                 1 {go_back core what!=1 form (atom 3)}
    {log_action\("xschem wire %}                      1 {new_wire storeobject site}
    {log_action\("xschem line %}                      1 {new_line storeobject site}
    {log_action\("xschem rect %}                      1 {new_rect storeobject site}
    {log_action\("xschem arc %}                       1 {new_arc site}
  }
  src/save.c {
    {log_action\("xschem make_symbol"}                1 {make_symbol core (slice 6)}
    {log_action\("xschem make_sch_from_sel"}          1 {make_sch_from_sel core (slice 6)}
    {log_action\("xschem make_sch"\)}                 1 {make_sch core (slice 6)}
    {log_action_descend\("descend_symbol"}            1 {descend_symbol core -inst form (atom 3)}
  }
  src/select.c {
    {log_action\("xschem select_grow_connected}       2 {connected-grow core, both forms (atom 1)}
  }
  src/editprop.c {
    {# property-edit}                                 1 {property-dialog marker (0063)}
  }
  src/xschem.tcl {
    {log_action -reset}                               2 {stdin REPL + TCP handler dedup resets (0003)}
    {log_action -emitted}                             4 {stdin REPL + TCP handler -emitted gates (0003)}
    {# failed: }                                      2 {stdin REPL + TCP failed-command comment form (0003)}
    {(?n)^\s*xschem\s+log_action\s+\[list\s+net_hilight_style_set_live\M} 2 {nhse_apply_live + delete-last-row live-commit lines, raw replay form (atom 8 / 0065)}
    {(?n)^\s*xschem\s+log_action\s+net_hilight_style_reset\M} 1 {nhse_reset live-reset line (atom 8 / 0065)}
    {(?n)^\s*xschem\s+log_action\s+\[list\s+set\s+::net_hilight_style\M} 1 {nhse_save staged-table line (atom 8 review: Save writes the staged var)}
    {(?n)^\s*xschem\s+log_action\s+\[list\s+write_net_hilight_style_conf\M} 1 {nhse_save resolved-path line (atom 8 / 0065)}
  }
  src/library_manager.tcl {
    {(?n)^\s*xschem\s+log_action\s+\[list\s+libmgr::do_} 14 {do_* mutation-seam logs, one per worker, line-anchored so a commented-out site does not count (atom 7 / 0064)}
  }
}
foreach {relfile rows} $MANIFEST {
  set text [srctext $relfile]
  foreach {re min label} $rows {
    set n [rxcount $text $re]
    check "S1 $relfile: $label" [expr {$n >= $min}] "want>=$min got=$n re=$re"
  }
}

# ---------------------------------------------------------------------------
# S1b) libmgr do_* seam CLOSURE (atom 7 review): the >=14 floor above cannot
#      see a NEW unlogged worker, so enumerate every `proc libmgr::do_*` and
#      require each to be either an allowlisted read-only viewer or to carry an
#      UNCOMMENTED log_action of its own name (line-anchored; \M so do_checkin
#      does not satisfy do_checkin_lib). A new mutating worker fails closed
#      until it logs or is allowlisted.
# ---------------------------------------------------------------------------
set LBM_READONLY {do_show_checkouts do_history do_history_view do_history_cell do_history_lib}
set lbmtext [srctext src/library_manager.tcl]
set lbmworkers {}
foreach {m name} [regexp -all -inline {proc\s+libmgr::(do_\w+)} $lbmtext] {
  lappend lbmworkers $name
}
set lbmworkers [lsort -unique $lbmworkers]
check "S1b do_* worker inventory found" [expr {[llength $lbmworkers] >= 19}] \
  "n=[llength $lbmworkers]"
foreach w $lbmworkers {
  if {[lsearch -exact $LBM_READONLY $w] >= 0} continue
  set re "(?n)^\\s*xschem\\s+log_action\\s+\\\[list\\s+libmgr::${w}\\M"
  check "S1b libmgr::$w logs its own line (uncommented)" \
    [expr {[rxcount $lbmtext $re] >= 1}] "re=$re"
}

# ---------------------------------------------------------------------------
# S1c) must-NOT-reappear (atom 9): the paste/merge drop marker and the
#      ctx-menu pick-8 literal are gone for good -- re-adding either would
#      shadow or double the drop's replayable `xschem paste dx dy` line.
# ---------------------------------------------------------------------------
set cbtext [srctext src/callback.c]
check "S1c old '# paste/merge drop' marker stays removed" \
  [expr {[rxcount $cbtext {# paste/merge drop}] == 0}]
check "S1c ctx-menu pick-8 'xschem paste' literal stays removed (drop line is the record)" \
  [expr {[rxcount $cbtext {"xschem paste"}] == 0}]

# ---------------------------------------------------------------------------
# S2) TCL LITERAL-LOG CONFLICTS: no ungated hand-rolled `xschem log_action
#     "xschem <verb> ..."` for a verb the C side self-logs.
#     Gated = the same or one of the 2 preceding lines carries `log_action
#     -emitted` (the menu_action_logged / library_manager pattern).
# ---------------------------------------------------------------------------
# Verbs self-logged in C. `set` is keyed per-subcommand (set cadsnap|cadgrid|
# header_text|rectcolor log in C; `set readonly` is Tcl-owned).
set CVERBS {
  cut delete copy undo redo save reload saveas align trim_wires break_wires
  flip flipv rotate flip_in_place flipv_in_place rotate_in_place
  change_elem_order check_unique_names create_instance
  floaters_from_selected_inst print_hilight_net attach_labels add_pin_stubs
  setprop unhilight_all hilight_net_interactive unhilight_net_interactive
  make_symbol make_sch make_sch_from_sel descend descend_symbol go_back
  select_grow_connected select_at library_manager exit
  wire line rect arc polygon instance text pan zoom_box paste
  move_objects copy_objects load load_new_window
  {set cadsnap} {set cadgrid} {set header_text} {set rectcolor}
}
# (file,verb) pairs allowed UNGATED: the file-menu dialog-resolution arms eval
# the WITH-FILENAME form, for which the C side is silent by design (C logs only
# its own ask-dialog arm) -- a single faithful line, no dedup needed.
set S2_ALLOW { {xschem.tcl load_new_window} }
set nviol 0
foreach f [glob -directory [file join $REPO src] *.tcl] {
  set lines [split [srctext src/[file tail $f]] \n]
  set n [llength $lines]
  for {set i 0} {$i < $n} {incr i} {
    set L [lindex $lines $i]
    if {[regexp {^\s*#} $L]} continue
    # literal log: xschem log_action "xschem ..."   or   {xschem ...}
    if {![regexp {xschem log_action\s+["\{]xschem\s+(\S+)(\s+(\S+))?} $L -> v1 - v2]} continue
    set verb [string trim $v1 "\"\}"]
    if {$verb eq "set" && $v2 ne ""} { set verb "set [string trim $v2 "\"\}"]" }
    if {[lsearch -exact $CVERBS $verb] < 0} continue
    if {[lsearch -exact $S2_ALLOW [list [file tail $f] $verb]] >= 0} continue
    set gated 0
    for {set j [expr {$i-2}]} {$j <= $i} {incr j} {
      if {$j >= 0 && [string match {*log_action -emitted*} [lindex $lines $j]]} { set gated 1 }
    }
    if {!$gated} {
      incr nviol
      check "S2 ungated Tcl literal log of C-logged verb '$verb'" 0 "[file tail $f]:[expr {$i+1}]: [string trim $L]"
    }
  }
}
check "S2 no ungated Tcl literal logs of C-self-logged verbs" [expr {$nviol == 0}] "violations=$nviol"

# ---------------------------------------------------------------------------
# S3) BRANCH-MUST-NOT-LOG: verbs whose log lives in a core C function must not
#     ALSO log in scheduler.c (menu/script would double). Word-boundary regexes
#     so make_sch does not match make_sch_from_sel, descend not descend_symbol.
# ---------------------------------------------------------------------------
set sched [srctext src/scheduler.c]
# `paste`: the branch IS the coordinate replay form (atom 9) -- a log there
# would re-log every replayed drop.
foreach verb {make_symbol make_sch make_sch_from_sel descend descend_symbol
              go_back select_grow_connected update_net_hilight_style paste} {
  set n [rxcount $sched "log_action\\(\"xschem $verb\[\"% \]"]
  check "S3 scheduler.c has NO log_action for core-logged verb '$verb'" \
    [expr {$n == 0}] "got=$n"
}
check "S3 scheduler.c has NO log_action_descend (lives in the cores)" \
  [expr {[rxcount $sched {log_action_descend\(}] == 0}]

# ---------------------------------------------------------------------------
# S4) RECORDER DEDUP WIRING: the four dedup-wired recorders + the lbm gated
#     fallback keep their reset/-emitted plumbing.
# ---------------------------------------------------------------------------
set ar  [srctext src/action_registry.tcl]
set cw  [srctext src/ciw.tcl]
set cb  [srctext src/callback.c]
set lbm [srctext src/library_manager.tcl]
check "S4 menu_action_logged: reset wired"    [expr {[rxcount $ar {log_action -reset}]   >= 1}]
check "S4 menu_action_logged: -emitted gates" [expr {[rxcount $ar {log_action -emitted}] >= 2}]
check "S4 ciw_exec: reset wired"              [expr {[rxcount $cw {log_action -reset}]   >= 1}]
check "S4 ciw_exec: -emitted gates"           [expr {[rxcount $cw {log_action -emitted}] >= 2}]
check "S4 callback.c: dedup flag resets (ctx menu + dispatch)" \
  [expr {[rxcount $cb {actionlog_cmd_logged = 0}] >= 2}]
check "S4 callback.c: dedup flag checks (ctx menu + dispatch)" \
  [expr {[rxcount $cb {!actionlog_cmd_logged}] >= 2}]
check "S4 library_manager open_cellview: gated fallback (-emitted x2)" \
  [expr {[rxcount $lbm {log_action -emitted}] >= 2}]

# ---------------------------------------------------------------------------
# S5) RUNTIME CANARY: exactly-once end-to-end (static scans can't see a broken
#     suppress flag or dedup at runtime). Cheap no-fixture verbs only.
# ---------------------------------------------------------------------------
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  check "S5 runtime canary (skipped: no --logdir)" 1 "static scans only"
} else {
  proc logcount {pat} {
    set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
    set n 0
    foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
    return $n
  }
  foreach verb {undo redo copy trim_wires} {
    set c0 [logcount "xschem $verb"]
    xschem $verb
    check "S5 script 'xschem $verb' -> exactly +1" \
      [expr {[logcount "xschem $verb"] == $c0 + 1}] "c0=$c0 now=[logcount "xschem $verb"]"
  }
  set c0 [logcount {xschem copy}]
  menu_action_logged {xschem copy}
  check "S5 menu_action_logged dedup live (copy exactly +1)" \
    [expr {[logcount {xschem copy}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem copy}]"
}

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
