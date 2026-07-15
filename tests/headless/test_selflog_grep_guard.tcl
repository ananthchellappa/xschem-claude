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
# Atom 11 (0069 sympin) added: the START_SYMPIN drop-log sites (the sympin
# add_symbol_pin line + the shared log_placed_instance read-back), the scheduler
# add_symbol_pin no-line/writeback replay-arm rows, `add_symbol_pin`/`add_sch_pin`
# in S2 + S3 (the drop funnel is the SOLE logger), and the S1c scan for the old
# `# place symbol pin` marker.
# Atom 12 (0053 Cadence Ctrl-E window hop) added: the S1 focus_window emit row
# (utils/cadence_nav.tcl) and the S6 SEAM-EXCLUSIVITY block -- `new_schematic
# switch` (a shared core: tab-strip/alt2/window-open machinery) must be logged
# ONLY at the cadence::focus_window seam, never in the C core (else every tab
# redraw floods the log). `new_schematic` is deliberately NOT in the S2 CVERBS set
# (it is Tcl-seam-logged, not C-self-logged, so the Tcl literal log is legitimate).
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
    {if\(fast != 1 && argc > 2 && !strcmp\(argv\[2\], "instance"\)\)} 1 {setprop self-log gate stays instance-only: the wire/rect/text/line/arc/poly `allprops` replay arms must NOT self-log (atom 10)}
    {if\(!\(xctx->ui_state & STARTMERGE\)\)}          1 {paste replay arm: pending-merge completion gate (atom 9)}
    {merge_file\(8, f\)}                              1 {paste replay arm: -file merge form (atom 9)}
    {!strcmp\(argv\[k\], "-anchor"\)}                 1 {paste replay arm: -anchor pivot parse (atom 9 review)}
    {if\(argc > 7\) noline = atoi\(argv\[7\]\);}      1 {add_symbol_pin no-stub-line replay arg: the sympin drop replay form matches the -place geometry (atom 11)}
    {if\(vi >= 0\) pin_view_writeback\(vi\);}         1 {add_symbol_pin noline reproduces the -place move-time name_* writeback so the replay saves byte-identically (atom 11)}
    {strcmp\(argv\[4\], "kissing"\) && strcmp\(argv\[4\], "stretch"\)} 2 {move_objects + copy_objects replay arms parse `rot flip [local] [-anchor]`, guarded against the kissing/stretch flag words so a plain line parses unchanged (atom 13 / 0069)}
    {if\(done_netlist && !keep_symbols\)}            1 {netlist branch self-log gate: `-keep_symbols` cellview/reroute machinery stays SILENT, the atom-4 `save fast` axis; dir-unwritable (done_netlist==0) logs nothing (atom 14 / 0062)}
    {av\[ac\+\+\] = "netlist";}                       1 {netlist branch emits the resolved `xschem netlist [-erc] [-nohier] [{fname}]` replay form -- the branch IS the 1:1 self-log site (atom 14 / 0062)}
    {tclsetboolvar\("enable_stretch", atoi\(argv\[3\]\)} 1 {set enable_stretch replay arm applies the resolved tcl var, the absolute form toggle_stretch_cmd self-logs; NO self-log here -> no double on replay (atom 16 / 0062 tail)}
    {if\(!v\) xctx->manhattan_lines = 0;}             1 {set orthogonal_wiring replay arm reproduces the manhattan_lines side effect (edit-mode faithfulness), matching toggle_orthogonal_wiring_cmd; NO self-log here (atom 16 / 0062 tail)}
    {!strcmp\(argv\[2\], "-suppress"\)}               1 {log_action -suppress push|pop: the re-entrant scope guard the replay seam + composite ops ride on -- a DEPTH COUNTER so replay{composite{core}} stays suppressed until the outermost pop (issue 0071 Refactor B foundation / audit §3.2)}
    {!strcmp\(argv\[2\], "actionlog_suppress"\)}      1 {set actionlog_suppress N: the absolute (hard-reset) setter; NOT self-logged (a control command, and once >0 the log_action is a no-op anyway)}
  }
  src/util.c {
    {void actionlog_suppress_push\(void\)}            1 {the re-entrant suppress-scope PUSH (depth counter): the write site actionlog_suppress lacked -- the gate existed in log_action* but nothing ever set it (audit §3.2)}
    {void actionlog_suppress_pop\(void\)}             1 {the matching POP, underflow-clamped (>0 guard) so an unbalanced extra pop keeps logging ON}
  }
  src/callback.c {
    {log_action\("xschem set enable_stretch}          1 {toggle_stretch_cmd core self-logs the ABSOLUTE resolved state, not the replay-fragile relative flip (atom 16 / 0062 tail)}
    {log_action\("xschem set orthogonal_wiring}       1 {toggle_orthogonal_wiring_cmd core self-logs the ABSOLUTE resolved state (atom 16 / 0062 tail)}
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
    {(?n)^\s*av\[ac\+\+\] = "-anchor";}               2 {paste/merge (atom 9) + rotmove (atom 13) drop -anchor pivot rider: a whole-log replay's regenerated clipboard / move-START seeds a different pivot}
    {(?n)^\s*log_action_argv\(ac, av\);}              2 {paste/merge (atom 9) + rotmove (atom 13) drop emit calls, line-anchored: if(0)/line-comment counts as removed (a BLOCK comment still evades -- the behavioral test is the real lock)}
    {(?n)^\s*av\[ac\+\+\] = "xschem"; av\[ac\+\+\] = is_copy \? "copy_objects" : "move_objects";} 1 {rotmove drop: mid-move/copy rotate/flip replay line, one form for both verbs (atom 13 / 0069)}
    {(?n)^\s*av\[0\] = "xschem"; av\[1\] = "add_symbol_pin";} 1 {sympin drop: symbol-pin replay line (atom 11 / 0069)}
    {(?n)^\s*av\[0\] = "xschem"; av\[1\] = "instance";} 1 {placed-instance read-back line in log_placed_instance -- shared by PLACE_SYMBOL + schematic Add-Pin drop (atom 11)}
    {(?n)^\s*if\(log_placed_instance\(\)\) return;}   2 {log_placed_instance called by both the PLACE_SYMBOL arm and the START_SYMPIN sch-pin arm (atom 11)}
    {log_action\("xschem netlist -erc -nohier"}      1 {Shift-N current-level netlist key entry-site: bypasses the branch (direct global_*_netlist(0,1)), logs `-erc -nohier` -- `-erc`=state-preserving (erc=1 skips the netlist_name clear + infowindow suppression the key never does), NOT bare `-nohier` which would clear a custom netlist_name (atom 14 review MAJOR / 0062)}
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
    {(?n)^\s*log_prop_edit_replayable\(type, presel_names\);} 1 {property-dialog per-object replayable emit tail, line-anchored (atom 10 / 0063)}
    {"schprop";}                                      1 {global-attrs edit -> `set sch<X>prop {..}` replay emit (atom 10)}
    {(?n)^\s*presel_names\[s\] = NULL;}               1 {ELEMENT emit pre-edit-name snapshot: a rename must address the OLD name (atom 10 review)}
  }
  src/xschem.tcl {
    {log_action -reset}                               2 {stdin REPL + TCP handler dedup resets (0003)}
    {log_action -emitted}                             4 {stdin REPL + TCP handler -emitted gates (0003)}
    {# failed: }                                      2 {stdin REPL + TCP failed-command comment form (0003)}
    {(?n)^\s*xschem\s+log_action\s+\[list\s+net_hilight_style_set_live\M} 2 {nhse_apply_live + delete-last-row live-commit lines, raw replay form (atom 8 / 0065)}
    {(?n)^\s*xschem\s+log_action\s+net_hilight_style_reset\M} 1 {nhse_reset live-reset line (atom 8 / 0065)}
    {(?n)^\s*xschem\s+log_action\s+\[list\s+set\s+::net_hilight_style\M} 1 {nhse_save staged-table line (atom 8 review: Save writes the staged var)}
    {(?n)^\s*xschem\s+log_action\s+\[list\s+write_net_hilight_style_conf\M} 1 {nhse_save resolved-path line (atom 8 / 0065)}
    {(?n)^\s*xschem toggle_stretch$} 1 {Options-menu "Enable stretch" checkbutton -command routes through the self-logging toggle_stretch_cmd (atom 16 / 0062 tail): a bare -variable checkbutton bypassed the cmd and logged nothing}
    {(?n)^\s*xschem toggle_orthogonal_wiring$} 1 {Options-menu "Enable orthogonal wiring" checkbutton -command routes through toggle_orthogonal_wiring_cmd -- the ONLY interactive control for the keyless verb -- applying side effects AND self-logging (atom 16 / 0062 tail)}
    {(?n)^\s*xschem log_action -suppress push$} 1 {replay_action_log seam: source a recorded log IN-SESSION under the suppress scope so lines re-EXECUTE but do not re-LOG -- the audit §3.2 replay re-entrancy hazard, made safe for an in-session replay (Refactor B foundation)}
    {(?n)^\s*xschem log_action -suppress pop$}  1 {replay_action_log seam close: balanced via catch so a mid-file error still pops the scope}
  }
  src/library_manager.tcl {
    {(?n)^\s*xschem\s+log_action\s+\[list\s+libmgr::do_} 14 {do_* mutation-seam logs, one per worker, line-anchored so a commented-out site does not count (atom 7 / 0064)}
  }
  utils/cadence_nav.tcl {
    {(?n)^\s*xschem log_action "xschem new_schematic switch } 1 {focus_window logs the Cadence Ctrl-E parent-window hop at the entry seam, line-anchored so the prose in the comment above does not count (atom 12 / 0053)}
  }
  utils/apply_hilight.tcl {
    {(?n)^\s*xschem log_action \[list net_hilight_apply \$style\]} 1 {aphl::try_apply CLICK-arm emit: the click-to-apply style logs the RESOLVED row (atom 15 / 0065 §4 / 0067 §5); the click's own select_at is logged by the core (atom 1) and re-selects the net on replay}
    {(?n)^\s*xschem log_action \[list net_hilight_apply \$row\]}   1 {apply_hilight IMMEDIATE-arm emit: the raw cadence F5 bind (bypasses dispatch_input_action) records here; the CIW-typed path dedups via ciw_exec `-emitted` -> exactly once (atom 15)}
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
# atom 11: the sympin drop marker is replaced by replayable add_symbol_pin /
# instance lines -- it must not creep back (it would shadow the real record).
check "S1c old '# place symbol pin (no replayable...)' marker stays removed" \
  [expr {[rxcount $cbtext {# place symbol pin \(no replayable}] == 0}]
# atom 10: the property-dialog marker is replaced by replayable setprop lines --
# it must not creep back for the converted types (it would shadow the real record).
check "S1c old '# property-edit' marker stays removed (property dialogs now replayable)" \
  [expr {[rxcount [srctext src/editprop.c] {# property-edit}] == 0}]
# atom 13: the mid-move/copy rotate/flip marker is replaced by replayable
# move_objects/copy_objects lines -- the dead `no single-command replay` marker
# must not creep back (it would shadow the real record and drop the orientation).
check "S1c old rotate/flip 'no single-command replay' marker stays removed (rot/flip drops now replayable)" \
  [expr {[rxcount $cbtext {no single-command replay}] == 0}]

# ---------------------------------------------------------------------------
# S1d) apply_hilight CLOSURE (atom 15): the two S1 emit rows lock the KNOWN apply
#      arms, but they cannot see a NEW unlogged net_hilight_apply call site. So
#      count every statement-position `net_hilight_apply` invocation in
#      utils/apply_hilight.tcl (the log lines start with `xschem`, comments with
#      `#`, so neither matches) -- there must be EXACTLY 2 (aphl::try_apply and the
#      apply_hilight immediate arm). A NEW apply arm bumps this and fails closed
#      until its own log_action + S1 row are added. Pairs with the 2 emit rows to
#      guarantee 2 invocations <-> 2 logs.
# ---------------------------------------------------------------------------
set aphtext [srctext utils/apply_hilight.tcl]
check "S1d exactly 2 net_hilight_apply invocation sites in apply_hilight.tcl (both logged)" \
  [expr {[rxcount $aphtext {(?n)^\s*net_hilight_apply\M}] == 2}] \
  "got=[rxcount $aphtext {(?n)^\s*net_hilight_apply\M}]"

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
  add_symbol_pin add_sch_pin netlist
  move_objects copy_objects load load_new_window
  {set cadsnap} {set cadgrid} {set header_text} {set rectcolor}
  {set enable_stretch} {set orthogonal_wiring}
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
# would re-log every replayed drop. `add_symbol_pin`/`add_sch_pin` (atom 11):
# the drop funnel (end_move_copy_logged, callback.c) is the SOLE logger -- both
# the `-place` gesture start and the direct `add_symbol_pin` replay form must
# stay silent in the scheduler, else a replayed sympin drop double-logs.
# `move_objects`/`copy_objects` (atom 13): same shape -- the scheduler arms ARE
# the coordinate replay form (rot/flip/-anchor), the drop funnel is the sole
# logger, so a log in the branch would re-log every replayed rot/flip drop.
# toggle_stretch/toggle_orthogonal_wiring (atom 16 / 0062 tail): the cores
# (toggle_*_cmd, callback.c) self-log the ABSOLUTE `set <var> <v>` form, so the
# scheduler branches must NOT log the replay-fragile relative flip; likewise the
# `set enable_stretch`/`set orthogonal_wiring` replay arms ARE the coordinate/replay
# form and must not self-log (a log there would double every replayed line).
foreach verb {make_symbol make_sch make_sch_from_sel descend descend_symbol
              go_back select_grow_connected update_net_hilight_style paste
              add_symbol_pin add_sch_pin move_objects copy_objects
              toggle_stretch toggle_orthogonal_wiring
              {set enable_stretch} {set orthogonal_wiring}} {
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
# The suppress-scope guard (issue 0071 Refactor B foundation) is NEW dedup wiring:
# the setter + the two re-entrancy seams. If any of these four go missing, the
# replay/composite double-log hazard (§3.2) re-opens -> fail closed.
set utl [srctext src/util.c]
set xtcl [srctext src/xschem.tcl]
check "S4 suppress-scope: util.c defines the push/pop depth guard" \
  [expr {[rxcount $utl {void actionlog_suppress_push}] >= 1 &&
         [rxcount $utl {void actionlog_suppress_pop}]  >= 1}]
check "S4 suppress-scope: scheduler.c wires -suppress push|pop + the absolute set" \
  [expr {[rxcount $sched {!strcmp\(argv\[3\], "push"\)}] >= 1 &&
         [rxcount $sched {!strcmp\(argv\[2\], "actionlog_suppress"\)}] >= 1}]
# NOTE: abort_operation is deliberately NOT suppress-wrapped (adversarial-review
# MAJOR, §20): its STARTPOLYGON arm calls new_polygon(END) which self-logs a real
# `xschem polygon` line, so a blanket wrap would drop it. The composite hazard is
# closed via the replay seam + the general push/pop primitive instead. The
# suppress-gate test's case (g) locks the "abort must not suppress" behaviour.
check "S4 suppress-scope: replay_action_log seam push AND pop (xschem.tcl)" \
  [expr {[rxcount $xtcl {log_action -suppress push}] >= 1 &&
         [rxcount $xtcl {log_action -suppress pop}]  >= 1}]

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

# ---------------------------------------------------------------------------
# S6) new_schematic switch SEAM EXCLUSIVITY (atom 12 / 0053): the Cadence Ctrl-E
#     parent-window hop is logged ONLY at the cadence::focus_window seam. The core
#     `new_schematic switch` is shared by the tab-strip click machinery
#     (xschem.tcl `... switch $w {} 0`, no-draw), alt2 toggle and window-open paths
#     -- logging in the C core (or in any of those Tcl callers) would flood every
#     tab redraw. So: exactly ONE Tcl file logs a `new_schematic switch` line, it is
#     utils/cadence_nav.tcl, and the C scheduler branch logs it nowhere.
# ---------------------------------------------------------------------------
set nsw_files {}
set nsw_total 0
foreach rel [concat [glob -directory [file join $REPO src] *.tcl] \
                    [glob -directory [file join $REPO utils] *.tcl]] {
  set t [srctext [string range $rel [expr {[string length $REPO]+1}] end]]
  set n 0
  foreach L [split $t \n] {
    if {[regexp {^\s*#} $L]} continue
    if {[regexp {log_action\s+["\{]?xschem new_schematic switch} $L]} { incr n }
  }
  if {$n > 0} { lappend nsw_files [file tail $rel] ; incr nsw_total $n }
}
check "S6 exactly one Tcl 'new_schematic switch' log line exists" \
  [expr {$nsw_total == 1}] "total=$nsw_total files=$nsw_files"
check "S6 the sole 'new_schematic switch' logger is cadence_nav.tcl (focus_window seam)" \
  [expr {$nsw_files eq {cadence_nav.tcl}}] "files=$nsw_files"
# The C cores must not self-log the SWITCH form (that is the tab-strip/alt2/window-open
# machinery). Scan ALL C files the switch machinery lives in -- scheduler.c (the dispatch
# branch) AND xinit.c (switch_window/new_schematic) AND callback.c (the EnterNotify/FocusIn
# context switch) -- not scheduler.c alone. Match `new_schematic switch` SPECIFICALLY, so
# the legitimate `new_schematic destroy` window-close self-logs (xinit.c:2240/2331, the
# close-window verb) are not false-positives.
set nsw_c 0
foreach cf {scheduler.c xinit.c callback.c} {
  incr nsw_c [rxcount [srctext src/$cf] {log_action\w*\([^;]*"xschem new_schematic switch}]
}
check "S6 no C core self-logs the new_schematic SWITCH form (machinery must stay silent)" \
  [expr {$nsw_c == 0}] "got=$nsw_c across scheduler.c+xinit.c+callback.c"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
