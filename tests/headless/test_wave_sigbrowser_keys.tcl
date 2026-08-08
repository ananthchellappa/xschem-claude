# tests/headless/test_wave_sigbrowser_keys.tcl — TWO-PANE item 16, R9:
# the Signal Browser's chord moves from Ctrl-L to Ctrl-B, and the C binding
# table loses its `key 98 ctrl graph graph.forward` row so the viewer's own
# key_filter carve-out is the ONLY thing standing between Ctrl-B and the
# schematic's `case 'b'`.
# Spec: doc/claude/specs/waveform_signal_browser_two_pane.md §8.1, R9.
# PLAN: doc/claude/signal_browser_2pane_batch/PLAN.md item 16.
#
# ============================================================================
# WHERE THIS FILE SITS — RULING 30's FILE MAP
# ============================================================================
#   tests/headless/test_wave_sigbrowser.tcl        items 8, 9, 10   BS BT BM
#   tests/headless/test_wave_sigbrowser_i11.tcl    item 11          BH
#   tests/headless/test_wave_sigbrowser_i12.tcl    item 12          BX
#   tests/headless/test_wave_sigbrowser_i1315.tcl  items 13, 15     BP
#   tests/headless/test_wave_sigbrowser_i14.tcl    item 14          BD
#   tests/headless/test_wave_sigbrowser_panes.tcl  two-pane 9-13    BW
#   tests/headless/test_wave_sigbrowser_keys.tcl   two-pane 16, 17b, 18 BK <- HERE
#
# CHECK-ID BAND: BK01-BK18 two-pane item 16 / BK19 UNSPENT (reserved to item
# 16's own file band by 16_receipt.md §11) / BK20-BK31 two-pane item 17b /
# BK32-BK42 two-pane item 18 (R12's auto-unhide).
# Measured free before use in all three rounds (greps over tests/ and
# doc/claude/; BK20+ was reserved to item 17b by the PLAN and taking it earlier
# would have repeated the item-10/item-12 BW40 collision).
# NEXT FREE IN THIS FILE: BK43.
#
# ⚠ THE PLAN'S BAND FOR ITEM 18 WAS `BK40`-`BK47` UNDER A HEADING AND
# `BK40`-`BK49` IN ITS CODE BLOCK — internally inconsistent, and DEAD ON ARRIVAL
# either way: it was written before items 16 and 17b spent BK01-BK31. Measured
# first free is BK32, exactly as two-pane item 12's receipt §3.1 requires and as
# item 17b found for its own band. BK19 stays reserved and unspent.
#
# ⚠ TWO-PANE ITEM 18's OWN X BLOCK IS AT THE END OF THE FILE and it is the ONLY
# group here that needs a signal corpus. It builds its OWN synthetic toplevel
# (`test_wave_sigbrowser_panes.tcl`'s recipe) rather than reusing the BKV
# sky130 session, because R12 needs an inventory with DEVICE classes in it and
# `test_nfet_final` has none. It tears that toplevel down again — spec §9's live
# note: a ticked box makes `browser_state` non-default, so a leaked one would
# start emitting a `browser` key in another file's snapshot.
#
# ⚠ THE SKIP BANNER WORDING IS LOAD-BEARING. `SKIPPED: <group> (Tk/X arm only)`
# is what a reader greps for when a headless count comes up short; a different
# wording reads as a crash.
#
# ============================================================================
# WHAT THIS ITEM ACTUALLY CHANGES, AND WHY THE BEHAVIOURAL CHECKS EXIST
# ============================================================================
# The rename (bind, menu accelerator, guide row) is a pure rename and every leg
# of it is a source or file grep. The DANGEROUS half is invisible to greps:
#
#   * 98 (`b`) IS a `graphkeys` member, and membership is UNCONDITIONAL on
#     modifiers — so before this item `wviewer::key_filter` FORWARDED Ctrl-b to
#     the C dispatcher whenever the pointer was over a graph.
#   * this item DELETES `set_input_binding(DEV_KEY, 'b', ControlMask,
#     ACTX_OVER_GRAPH, "graph.forward")` from src/callback.c, so a forwarded
#     Ctrl-b no longer finds an over_graph row and falls through to the C
#     switch, whose ControlMask arm toggles `xctx->sym_txt`.
#
# So without the modifier carve-out in key_filter the new chord would BOTH open
# the browser (the WaveViewer tag binding fires and key_filter never `break`s)
# AND flip sym_txt behind it. MEASURED, not reasoned: with the C row still in
# place a direct `key_filter … 98 … 4` drive over a graph forwarded (1 call) and
# moved graph_flags 4 -> 0; the carve-out is what takes that forward to 0.
# BK12 and BK18 are the only checks in the repo that can see it — `set fwd` at
# wave_viewer.tcl had ZERO test coverage before this file existed.
# ============================================================================

set ::wvbs_tag  wvsigbrowser_keys
set ::wvbs_name test_wave_sigbrowser_keys
source [file join [file dirname [info script]] wvbs_common.tcl]

# --- the other three texts this item edits, read once ------------------------
proc bk_slurp {path} {
  if {[catch {open $path r} fp]} { return NO-FILE }
  set d [read $fp]; close $fp
  return $d
}
set guide   [file join $repo doc waveform_viewer_guide.html]
set gsrc    [bk_slurp $guide]
set csrc    [bk_slurp [file join $repo src callback.c]]
set gridsrc [bk_slurp [file join $repo tests headless test_wave_grid.tcl]]
set kbpath  [file join $repo src keybindings.csv]
if {[info exists ::XSCHEM_SHAREDIR] && $::XSCHEM_SHAREDIR ne {}} {
  set kbpath [file join $::XSCHEM_SHAREDIR keybindings.csv]
}
set kbcsv [bk_slurp $kbpath]

# ============================================================================
# BK01-BK10 — BOTH ARMS. Source greps, file greps and one PURE evaluation of
# the shipped expression.
# ============================================================================

# ⚠ TWO LEGS, NOT ONE. Leg 1 is the carve-out; leg 2 is the ABSENCE of the old
# single-keysym form, which is what stops a "fix" that ADDS a second `set fwd`
# line beside the original and leaves the original winning.
check {BK01 (SOURCE) the carve-out names BOTH keysyms in ONE expression, and the
       single-keysym form is gone} \
  [list [regexp {set fwd \[expr \{!\(\(\$N == 100 \|\| \$N == 98\) && \(\$s & 4\)\)\}\]} $wsrc] \
        [regexp {set fwd \[expr \{!\(\$N == 100 && \(\$s & 4\)\)\}\]} $wsrc]] \
  {1 0}

# ⚠ THE PLAN'S BK02 WAS VACUOUS AND IS REPLACED. It read
#     [lsearch -exact {97 98 100 115 109 116 65 66 77} 98] 1
# i.e. it searched a literal the check itself had just written — green before
# the code existed, green after, and green under the very sabotage it was named
# to catch. This one instead EXTRACTS the shipped expression from the source and
# EVALUATES it, so the check's answer comes from the code rather than from the
# test. MEASURED on the unchanged tree: 1 1 0 1 1 1 (Ctrl-b forwarded).
set bk_ex NO-EXPR
regexp -line {set fwd \[expr \{(.+)\}\]} $wsrc -> bk_ex
# NEVER THROWS: a vanished or unparsable expression is an assertable VALUE, so
# "the line I am reading is gone" cannot masquerade as a routing answer.
proc bk_fwd {ex N s} {
  if {$ex eq {NO-EXPR}} { return NO-EXPR }
  if {[catch {expr $ex} r]} { return ERR }
  return $r
}
set bk_dec {}
foreach pr {{98 0} {98 4} {100 4} {97 4} {66 4} {100 0}} {
  lappend bk_dec [bk_fwd $bk_ex [lindex $pr 0] [lindex $pr 1]]
}
check {BK02 (PURE) the SHIPPED expression, evaluated: bare b forwards, Ctrl-b
       does not, Ctrl-d does not, Ctrl-a / Ctrl-Shift-B / bare d all still do} \
  $bk_dec {1 0 0 1 1 1}

# ⚠ POSITIVE CONTROL, and it reads the LIVE variable rather than a literal.
# R9's fix is a MODIFIER CARVE-OUT, not a membership deletion: delete 98 from
# `graphkeys` and bare `b` stops reaching waves_callback at all. Asserting the
# WHOLE list byte-exactly makes a deletion of ANY member visible, not just 98's.
check {BK03 (SOURCE, POSITIVE CONTROL) graphkeys STILL contains 98 and is
       otherwise untouched — the fix is a carve-out, not a deletion} \
  [list [lsearch -exact $::wviewer::graphkeys 98] $::wviewer::graphkeys] \
  {1 {97 98 100 115 109 116 65 66 77}}

# ⚠ THE CONTROL IS IN THE SAME TUPLE, not only in BK05: a csv that failed to
# regenerate, a csv truncated to nothing and a csv regenerated correctly must
# not share an answer. Leg 2 is what separates them.
check {BK04 (FILE) no ctrl row for 98 survives in the shipped keybindings.csv,
       and the file is not simply empty} \
  [list [regexp -line {^key,98,ctrl,} $kbcsv] \
        [regexp -line {^key,98,0,graph,graph\.forward,1} $kbcsv]] \
  {0 1}
check {BK05 (FILE, BK04's CONTROL) ...while the BARE-b graph row does} \
  [regexp -line {^key,98,0,graph,graph\.forward,1} $kbcsv] 1

# ⚠ THIS IS WHAT MAKES "hand-edited the csv" DISTINGUISHABLE FROM "the C table
# moved". A csv edit alone does not unbind anything (load_input_bindings_file
# only ADDS/REMAPS; only an `action '-'` row unbinds), so BK04 can be satisfied
# by a hand-edit that leaves the live table untouched. Leg 2 is the control: the
# bare-b idle row at callback.c is NOT deleted.
check {BK06 (SOURCE, C) callback.c lost the Ctrl-b over_graph row and KEPT the
       bare-b idle one} \
  [list [regexp {set_input_binding\(DEV_KEY, 'b', ControlMask, ACTX_OVER_GRAPH} $csrc] \
        [regexp {set_input_binding_idle\(DEV_KEY, 'b', 0, +ACTX_OVER_GRAPH} $csrc]] \
  {0 1}

set bk_idb [wvproc_body $wsrc wviewer::install_default_binds]
check_true {BK07 install_default_binds was found in the source} \
  [expr {$bk_idb ne {}}]
check {BK07 (SOURCE) the default is <Control-Key-b>, behind the rc-wins guard,
       with the break — and <Control-Key-l> is gone from the proc} \
  [list [expr {[string first {if {[bind WaveViewer <Control-Key-b>] eq {}} } $bk_idb] >= 0}] \
        [regexp {\n\s*bind WaveViewer <Control-Key-b> \{wviewer::browser_toggle_at %W;[^\n]*break\}} $bk_idb] \
        [regexp -all {Control-Key-l} $bk_idb]] \
  {1 1 0}

set bk_mb [wvproc_body $wsrc wviewer::build_menubar]
check_true {BK08 build_menubar was found in the source} [expr {$bk_mb ne {}}]
check {BK08 (SOURCE) the View entry spells the new accelerator adjacently, and
       Ctrl+L is gone from the proc} \
  [list [expr {[string first "-label \{Signal Browser\} -accelerator Ctrl+B" $bk_mb] >= 0}] \
        [regexp -all {Ctrl\+L} $bk_mb]] \
  {1 0}

check {BK09 (FILE) the guide's §9.1 row carries all three renamed literals and
       no Ctrl-L spelling survives anywhere in the guide} \
  [list [expr {[string first {data-seq="Control-Key-b"} $gsrc] >= 0}] \
        [expr {[string first {<kbd>Ctrl-B</kbd>} $gsrc] >= 0}] \
        [expr {[string first {data-menu="Signal Browser" data-accel="Ctrl+B"} $gsrc] >= 0}] \
        [expr {[regexp -all {Control-Key-l} $gsrc] + [regexp -all {Ctrl-L} $gsrc] \
               + [regexp -all {Ctrl\+L} $gsrc]}]] \
  {1 1 1 0}

# ⚠ GREEN BEFORE AND AFTER BY DESIGN, and it is the ONLY check in this file
# permitted to be. It is the standing guard that the rename was done by EDITING
# the guide's one row rather than by ADDING a second one: GH0's 16/11 counts
# cannot tell those apart on their own, because an added row moves the count and
# an edited literal does not — so the count and the two grid literals are pinned
# together here, locally, where item 16 is attributed.
check {BK10 (FILE, LOCKSTEP — the local twin of BX13) the guide still has
       sixteen data-seq rows and eleven menu/accel pairs, and test_wave_grid
       still pins exactly those two numbers} \
  [list [regexp -all {data-seq="} $gsrc] \
        [regexp -all {data-menu="[^"]*" data-accel="[^"]*"} $gsrc] \
        [regexp {\[llength \$gh_seqs\] 16} $gridsrc] \
        [regexp {\[llength \$gh_menus\] 11} $gridsrc]] \
  {16 11 1 1}

# ============================================================================
# BK20-BK31 — TWO-PANE item 17b, R10: "Show in Signal Browser" moves off the
# cadence_style_rc `Ctrl-5` Tk bind and onto the C action registry as
# `Ctrl+Alt+V`, so it is REMAPPABLE (`xschem bind` / keybindings.csv) and works
# for every profile rather than only for cadence users.
# Spec: doc/claude/specs/waveform_signal_browser_two_pane.md §8.2, R10.
#
# ⚠ MEASURED, and it is the whole reason the item is not cosmetic: in the
# shipped DEFAULT profile `bind .drw <Control-Key-5>` is EMPTY — cadence_style_rc
# is an opt-in profile file, not sourced by default — while the Tools cascade
# advertised `Ctrl+5` to everyone. The accelerator was a LIE for every
# non-cadence user; the C row makes it true.
#
# ⚠ THE SELECTION ARM IS NOT RE-TESTED HERE. Item 17's other half (one selected
# instance extends the browser path) shipped in 882694cc and is covered by
# BX16-BX18 headless / BX51-BX53 under X; item 17b RESTATES it through the NEW
# chord at BX56 rather than duplicating it.
# ============================================================================
set bk_rc   [bk_slurp [file join $repo src cadence_style_rc]]
set bk_xsrc [bk_slurp [file join $repo src xschem.tcl]]
set bk_acsv [bk_slurp [file join $repo src actions.csv]]

# The one actions.csv row, split into fields. A missing row answers an
# assertable {} rather than throwing.
set bk_arows {}
foreach bk_l [split $bk_acsv "\n"] {
  if {[string match {wave.show_in_signal_browser,*} $bk_l]} { lappend bk_arows $bk_l }
}
set bk_af {}
if {[llength $bk_arows] == 1} { set bk_af [split [lindex $bk_arows 0] ,] }
check {BK20 (FILE) actions.csv carries EXACTLY ONE wave.show_in_signal_browser
       row, and it is the row the cheat-sheet and the palette read: the label
       and the DISPLAY accel} \
  [list [llength $bk_arows] [lindex $bk_af 3] [lindex $bk_af 4]] \
  {1 {Show in Signal Browser} Ctrl+Alt+V}

# ⚠ LEG 2 IS THE MODS-ORDER WITNESS. `mods_name` (callback.c) is the ONLY writer
# of the `ctrl+shift+alt+super` spelling, so a hand-typed `alt+ctrl` reds leg 1;
# leg 2 proves the file was not simply emptied to satisfy leg 1's absence twin.
# MEASURED before the item: ZERO ctrl+alt rows and ZERO code-118 rows in the
# shipped csv, so the row is unambiguous.
check {BK21 (FILE) the regenerated keybindings.csv row is spelled EXACTLY,
       mods order included, and it is the file's only ctrl+alt row} \
  [list [regexp -line {^key,118,ctrl\+alt,canvas,wave\.show_in_signal_browser,$} $kbcsv] \
        [regexp -all -line {^key,[0-9]+,ctrl\+alt,} $kbcsv]] \
  {1 1}

# ⚠ LEG 2 IS A BARE-NAME FILE-WIDE COUNT (the BD06 shape, on callback.c): the id
# must appear TWICE and only twice — the registry row and the set_input_binding.
# A third occurrence means someone wrote it into a comment, which is
# indistinguishable from a second wiring site to every grep in this file.
check {BK22 (SOURCE, C) the registry row is Tcl-backed with a NULL fn, and the
       action id appears in callback.c exactly TWICE} \
  [list [regexp {\{ "wave\.show_in_signal_browser", NULL, "ase::show_in_browser_for_current",} $csrc] \
        [regexp -all {wave\.show_in_signal_browser} $csrc]] \
  {1 2}

# ⚠ LEG 3 IS THE POINT OF THE WHOLE `{win {}}` ARGUMENT. dispatch_input_action
# runs a CONSTANT string — there is no %-substitution — so a csv command written
# with a window argument or a `%W` would be dispatched LITERALLY. Asserting the
# ABSENCE of any argument makes the logged replay line context-free BY DESIGN.
check {BK23 (SOURCE, C) the canvas chord is ControlMask|Mod1Mask on keysym 'v',
       and the Tcl command takes NO window argument and no %W} \
  [list [regexp {set_input_binding\(DEV_KEY, 'v', ControlMask\|Mod1Mask, ACTX_CANVAS,\s+"wave\.show_in_signal_browser"\);} $csrc] \
        [regexp {"ase::show_in_browser_for_current"} $csrc] \
        [regexp {"ase::show_in_browser_for_current[^"]+"} $csrc]] \
  {1 1 0}

check {BK24 (FILE) cadence_style_rc no longer binds Control-Key-5 — R10 is a
       MOVE, not an ADD} [regexp {Control-Key-5} $bk_rc] 0
# ⚠ WITHOUT THIS, BK24 IS GREEN ON A DELETED OR EMPTIED FILE. Ctrl-4 (Direct
# Plot) and Ctrl-$ (plot mode) are the neighbours item 17b must not touch.
check {BK25 (BK24's CONTROL, SAME FILE) ...and it still binds Control-Key-4 for
       Direct Plot and Control-Key-dollar for the plot mode} \
  [list [regexp {Control-Key-4} $bk_rc] [regexp {Control-Key-dollar} $bk_rc]] \
  {1 1}

# ⚠ AN ABSENCE CLAIM THAT WAS TRUE BEFORE THE CODE EXISTED. Nothing bound
# Control-Alt-v anywhere, so leg 1 alone is VACUOUS — it passes on the red run.
# Leg 2 carries the positive evidence in the SAME tuple: the chord exists, and it
# exists in the C table. BOTH Tk spellings are grepped because a `bind` PATTERN
# written with `Alt-` resolves against the real keymap and would work.
check {BK26 (FILE, REMAPPABILITY) no rc file binds the chord in EITHER Tk
       spelling — an rc bind bypasses `xschem bind` — and the C table does} \
  [list [regexp {Control-(Alt|Mod1)-Key-v} $bk_rc] \
        [regexp {set_input_binding\(DEV_KEY, 'v', ControlMask\|Mod1Mask} $csrc]] \
  {0 1}

# ⚠ LEG 2 IS THE COMMENT LANDMINE, and it is BX12 leg 2's local twin: the phrase
# is counted FILE-WIDE over src/xschem.tcl and must stay at ONE. Writing the
# label into a comment there reds both.
check {BK27 (FILE) the Tools entry spells the new accelerator adjacent to the
       label, and the phrase still occurs EXACTLY ONCE in src/xschem.tcl} \
  [list [regexp -- {-label "Show in Signal Browser" \\\n\s+-accelerator Ctrl\+Alt\+V} $bk_xsrc] \
        [regexp -all {Show in Signal Browser} $bk_xsrc]] \
  {1 1}

# ⚠ LEG 1 IS WHAT MAKES THE THREE ZEROS NON-VACUOUS. The guide's §11.5 is PROSE
# ONLY: the chord is renamed inside a <kbd> run and the guide gains NO
# data-seq/data-menu attribute, which is exactly what keeps test_wave_grid's GH0
# at 16/11 and BX13's tuple at zeros.
check {BK28 (FILE, GUIDE, LOCKSTEP) the guide's prose names the new chord, the
       old one is gone, and NO guide row was added for either} \
  [list [expr {[string first {<kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>V</kbd>} $gsrc] >= 0}] \
        [regexp -all {<kbd>Ctrl</kbd>\+<kbd>5</kbd>} $gsrc] \
        [regexp -all {data-seq="Control-Alt-Key-v"} $gsrc] \
        [regexp -all {data-menu="Show in Signal Browser"} $gsrc]] \
  {1 0 0 0}

# ============================================================================
# BK32-BK35 — TWO-PANE item 18 (R12), BOTH ARMS. One PURE evaluation of the new
# formatter arm, one nine-legged control over every SHIPPED rendering, and two
# source oracles.
#
# ⚠ WHY THE CONTROLS CARRY A MOVING LEG. BK33 and BK35 restate facts that are
# already true, and a check that is green before the code exists proves nothing
# about the code — item 12 shipped two of those and only its red run found them.
# Each therefore carries ONE leg that MOVES with this item, in the SAME tuple as
# the stability claim: BK33's tenth leg is the formatter's return count (9 -> 10)
# and BK35's fourth and fifth are the two class-scope reads the R12 arm adds to
# `browser_show_path` (0 -> 1 each). Both were RED on the red run; without those
# legs both were GREEN on it, which is exactly how the two vacuous checks item 12
# shipped got through.
# ============================================================================

# ⚠ MEASURED PRE-STATE: this exact call answered `g:x1.x1.xm1` — the switch's
# fall-through `[lindex $res 1]` — before the arm existed. So it is red first and
# green after, not a restatement.
# ⚠ AND THE NODE IS REAL. The PLAN's example `g:x1.xm1` / `x1.xm1` exists in
# NEITHER model of the batch's corpus (measured through the shipped pipeline on
# fixtures/tb_bandgap_vars.txt: 45 nodes with the box off, 129 with it on, and
# `x1.xm1` in neither set). `x1.x1.xm1` does: absent with the box off, present
# with it on, three own-level signals, all device-classed. Every id and path in
# this band is that node.
check {BK32 (PURE, TWO-PANE item 18) browser_msg renders the new `unhidden`
       result as ONE sentence naming the node it had to unhide to reach} \
  [pcall ::wviewer::browser_msg {unhidden g:x1.x1.xm1 x1.x1.xm1}] \
  {showing device internals to reach x1.x1.xm1}

# ⚠ THE PLAN SAYS "the four SHIPPED results still render as BX13's four" AND IS
# WRONG TWICE. The four verbatim renderings are pinned by **BX14**
# (test_wave_sigbrowser_i12.tcl:387-396); BX13 is the guide oracle. And there
# have been NINE since two-pane item 11 added seanone/seaempty/seabars/seaclass/
# seacount. All nine are re-measured here, in ONE tuple, so a tenth arm inserted
# in the wrong place — or an arm that swallows another's input — is one red
# rather than nine silent ones.
set bk_msg9 [list \
  [pcall ::wviewer::browser_msg {ok g:x1.x2 x1.x2}] \
  [pcall ::wviewer::browser_msg {partial g:x1.x2 x1.x2 x1.x2.x9}] \
  [pcall ::wviewer::browser_msg {root {}}] \
  [pcall ::wviewer::browser_msg {err boom}] \
  [pcall ::wviewer::browser_msg {seanone}] \
  [pcall ::wviewer::browser_msg {seaempty x1.x2}] \
  [pcall ::wviewer::browser_msg {seabars 0 43}] \
  [pcall ::wviewer::browser_msg {seaclass 0 43}] \
  [pcall ::wviewer::browser_msg {seacount 3 43}] \
  [regexp -all {return } [wvproc_body $wsrc wviewer::browser_msg]]]
check {BK33 (BK32's CONTROL) all NINE shipped renderings are byte-unchanged —
       WITH the tenth leg that moves, so "nothing happened" cannot pass this} \
  $bk_msg9 \
  [list {showing x1.x2} \
        {no signals under 'x1.x2.x9' - showing x1.x2 instead} \
        {showing the simulation top level} \
        {boom} \
        {no node selected} \
        {x1.x2 has no signals of its own} \
        {0 of 43 signals (the Search/Filter bar is hiding them)} \
        {0 of 43 signals (device internals are hidden)} \
        {3 of 43 signals} \
        10]

# ⚠⚠ THIS IS THE ONLY WITNESS TO THE "compose the sentence inline" SABOTAGE, and
# it needs BOTH of its first two legs. That sabotage moves the literal OUT of the
# formatter and into browser_show_path: the file-wide count stays 1, the `.ph`
# text stays byte-identical, every behavioural check in this band stays GREEN,
# and the sidebar, the CIW echo and the ASE echo quietly stop being one account.
# Leg 2 — "and that one occurrence is inside the formatter" — is what sees it.
# Leg 3 is the mint site: `unhidden` appears TWICE in browser_say's body, once as
# the switch pattern and once in the result list, exactly as `ok`'s arm does.
# Leg 4 is the ONE call site in browser_show_path.
check {BK34 (SOURCE, THE ONE-FORMATTER ORACLE) the sentence is spelled in
       exactly ONE place in the file and that place is browser_msg; the kind is
       minted in browser_say and called from exactly one arm} \
  [list [regexp -all {device internals to reach} $wsrc] \
        [regexp -all {device internals to reach} [wvproc_body $wsrc wviewer::browser_msg]] \
        [regexp -all {unhidden} [wvproc_body $wsrc wviewer::browser_say]] \
        [regexp -all {unhidden} [wvproc_body $wsrc wviewer::browser_show_path]]] \
  {1 1 2 1}

# ⚠ TP44's TWIN, KEPT LOCAL SO THE TRAP IS VISIBLE IN THE FILE THAT SPRINGS IT.
# The one-line temptation in the R12 arm is to decode the revealed node's path
# there; that reds `TP44` in test_wave_sigbrowser_2pane.tcl:849-851 — a file this
# item has no other reason to open — for a reason no behavioural check can see.
# Legs 1-3 are frozen numbers (MEASURED 1 / 2 / 0 before the item); legs 4 and 5
# are the two reads the R12 arm adds, which is what stops this check being green
# on an item that never shipped.
set bk_spb [wvproc_body $wsrc wviewer::browser_show_path]
check {BK35 (SOURCE, TP44's TWIN) the R12 arm reuses the ONE decode, adds no
       third refresh and no sch_path read — while really adding the two
       class-scope reads that make its probe scoped} \
  [list [regexp -all {browser_id_path} $bk_spb] \
        [regexp -all {browser_refresh} $bk_spb] \
        [regexp -all {(^|[^_])sch_path} $bk_spb] \
        [regexp -all {browser_devint} $bk_spb] \
        [regexp -all {browser_srccur} $bk_spb]] \
  {1 2 0 1 1}

# ============================================================================
# BKV — BK11-BK18, the X arm. A REAL viewer on the sky130A ngspice_state1
# fixture (test_wave_sigbrowser's BSV recipe), with TWO STRIPS PLOTTED.
#
# ⚠⚠ THE STRIPS ARE NOT DECORATION. `wviewer::key_filter` forwards a graphkey
# only when `wviewer::over_graph` says the pointer is over a graph, and
# over_graph consults `graphbb` — which on a viewer with NOTHING PLOTTED is
# EMPTY. MEASURED: on the bare BSV fixture over_graph answers 0 at every pixel,
# every graphkey is swallowed, and a landmine check written on it would have
# been green for a reason that has nothing to do with the carve-out. Two strips
# (mq_layout's recipe, test_wave_markers.tcl) make graphbb cover the canvas.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
  set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
  set f [open [file join $scratch library.defs] w]
  puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
  puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
  puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
  close $f
  set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
  set ::library_registry_defs_only 1
  set ::XSCHEM_LIBRARY_PATH {}

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check {BK11 wviewer::open returns 1} [pcall ::wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: BKV group (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  set ::bkvdrw $vdrw
  set ::bktok  $tok
  set ::bkt    100000
  proc bk_tr {v c} { return [dict create expr $v name {} vec $v color $c] }
  wviewer::set_graphs $tok [list \
    [dict replace [wviewer::empty_graph] sdid A traces [list [bk_tr v_a 4] [bk_tr v_b 5]]] \
    [dict replace [wviewer::empty_graph] sdid B traces [list [bk_tr v_d 7]]]]
  wviewer::regenerate $tok
  wviewer::fit $tok

  # ⚠⚠ THE CONTEXT RE-ESTABLISH IS MANDATORY AND IT IS NOT BOILERPLATE.
  # over_graph's FIRST test is `[xschem get current_win_path] ne $wp -> 0`, and
  # every forwarded key runs a C callback that can leave the context somewhere
  # else. MEASURED on the red tree: with a single `switch` before each drive,
  # drive #1 saw over_graph 1 and drives #2-#6 ALL saw 0 — so five of six legs
  # would have measured "not forwarded" for a reason that has nothing to do with
  # the carve-out. This polls the PRECONDITION and RETURNS it, so an expired
  # budget reads 0 and FAILS the caller's own tuple instead of being rescued.
  proc bk_ctx {} {
    for {set i 0} {$i < 60} {incr i} {
      catch {xschem new_schematic switch $::bkvdrw}
      catch {focus -force $::bkvdrw}
      update
      catch {xschem new_schematic switch $::bkvdrw}
      catch {event generate $::bkvdrw <Motion> \
               -x [expr {[winfo width $::bkvdrw]/2}] \
               -y [expr {[winfo height $::bkvdrw]/2}] -time [incr ::bkt 1000]}
      catch {xschem new_schematic switch $::bkvdrw}
      if {[pcall ::wviewer::over_graph $::bkvdrw] eq {1}} { return 1 }
      after 20
    }
    return 0
  }
  proc bk_cb_trace {cmd args} {
    if {[lindex $cmd 1] eq {callback}} { incr ::bkcb }
  }
  proc bk_cvb {} {
    if {[info exists ::wviewer::cvb($::bktok)]} { return $::wviewer::cvb($::bktok) }
    return NO-CVB
  }
  # Drive the REAL key_filter and answer an ASSERTABLE 5-TUPLE, never a verdict
  # and never a throw:
  #   over  the gate's own answer (1 = the drive was actually eligible)
  #   fwd   how many `xschem callback` calls the forward made
  #   dsym  did ::sym_txt move        dgf  did graph_flags move
  #   dcvb  did the Tcl cursor-B mirror move
  # ⚠ THE TRACE IS REMOVED BEFORE THE `update` (MQ9's rule): an `update` inside
  # a live execution trace re-enters it from the event loop and the count stops
  # meaning "this drive".
  proc bk_drive {N s} {
    set over [bk_ctx]
    set ::bkcb 0
    set s0 $::sym_txt
    set g0 [bs_num [pcall xschem get graph_flags]]
    set c0 [bk_cvb]
    trace add execution xschem enter bk_cb_trace
    catch {wviewer::key_filter $::bkvdrw 2 100 100 $N x $s}
    catch {trace remove execution xschem enter bk_cb_trace}
    update
    catch {xschem new_schematic switch $::bkvdrw}
    set g1 [bs_num [pcall xschem get graph_flags]]
    return [list $over $::bkcb \
              [expr {$::sym_txt ne $s0 ? 1 : 0}] \
              [expr {$g1 ne $g0 ? 1 : 0}] \
              [expr {[bk_cvb] ne $c0 ? 1 : 0}]]
  }

  # ---- BK12: THE LANDMINE. --------------------------------------------------
  # This is the check the whole item hangs on. `over 1` in the expected tuple is
  # the positive evidence carried in the SAME tuple as the stability claim: a
  # drive that was never eligible answers `0 0 0 0 0`, which is NOT this.
  check {BK12 (X, THE LANDMINE) Ctrl-b over a strip is NOT forwarded, so it
         cannot fall through to the C switch and flip sym_txt — and the drive
         really was over a graph} \
    [bk_drive 98 4] {1 0 0 0 0}

  # ---- BK13: R9's SAFETY CLAIM, measured rather than asserted. --------------
  # `graphkeys` membership is untouched, so bare `b` still reaches
  # waves_callback and still toggles cursor B. Both the ENGINE bit and the Tcl
  # mirror, because key_cursor_tail only runs when the forward happened.
  check {BK13 (X, R9's SAFETY CLAIM) bare b over the same strip still forwards,
         still moves the cursor-B engine bit AND its Tcl mirror, and still
         leaves sym_txt alone} \
    [bk_drive 98 0] {1 1 0 1 1}
  # put cursor B back where it was
  bk_drive 98 0

  # ---- BK14: the carve-out is keyed on 98, and on 98 ALONE. -----------------
  check {BK14 (X, CONTROL) Ctrl-d is still refused (the carve-out's other half,
         unchanged by this item)} [lrange [bk_drive 100 4] 0 1] {1 0}
  check {BK14 (X, CONTROL) ...and Ctrl-Shift-B (keysym 66) still forwards, so
         the carve-out did not swallow the shifted twin} \
    [lrange [bk_drive 66 4] 0 1] {1 1}

  # ---- BK15: the four-part binding shape, at the NEW chord. -----------------
  # BS45 pins this in test_wave_sigbrowser.tcl; restating it locally is what
  # makes a later edit fail THIS file too, where item 16 is attributed.
  check {BK15 (X) Ctrl-B is on the WaveViewer tag, calls browser_toggle_at with
         the EVENT's canvas, and breaks so the chord never travels on} \
    [list [expr {[bind WaveViewer <Control-Key-b>] ne {}}] \
          [string match {*wviewer::browser_toggle_at %W*} [bind WaveViewer <Control-Key-b>]] \
          [string match {*break*} [bind WaveViewer <Control-Key-b>]]] \
    {1 1 1}
  pcall wviewer::strip_bindings $vdrw
  check {BK15 (X) ...it survives the strip_bindings sweep, and it is NOT bound
         on the canvas widget itself (which is what the sweep would take)} \
    [list [expr {[bind WaveViewer <Control-Key-b>] ne {}}] \
          [bind $vdrw <Control-Key-b>]] \
    {1 {}}

  # ---- BK16: the live table's 98 rows, exactly. -----------------------------
  # A csv edit cannot unbind, so this reads the LIVE table: the Ctrl row is gone
  # and the bare-b idle row is the only 98 row left.
  set bk_dump [pcall xschem bindings dump]
  set bk_98 {}
  if {[bs_set $bk_dump]} {
    foreach r $bk_dump { if {[lrange $r 0 1] eq {key 98}} { lappend bk_98 $r } }
  }
  check {BK16 (X) the live binding table's 98 rows are exactly the bare-b
         idle over_graph row — the ctrl row is gone from the TABLE, not just
         from the file} \
    $bk_98 {{key 98 0 graph graph.forward idle}}

  # ---- BK17: byte-identity, in-process. -------------------------------------
  # ⚠ THE SOLE WITNESS TO "hand-edited the generated csv". BK04/BK06/BK16 are
  # all satisfiable by a hand-edit plus the C deletion done in either order;
  # only a fresh generation compared byte-for-byte catches a file that was typed
  # rather than produced. test_bindings_file.tcl:29 makes the same claim from
  # outside this batch; this is its local twin.
  set bk_fresh [file join $scratch kb_fresh.csv]
  pcall save_input_bindings_file $bk_fresh {key}
  # ⚠ LEG 1 IS THE FIXTURE, NOT DECORATION. `save_input_bindings_file` returns
  # the EMPTY STRING (measured), so its return value is not an oracle: a
  # generation that silently wrote nothing would make leg 2 compare two empty
  # reads and pass. Leg 1 asserts the generated file is a real table.
  check {BK17 (X) the shipped keybindings.csv is byte-identical to a fresh
         generation from the live table, and that generation is a real table} \
    [list [expr {[regexp -all -line {^key,} [bk_slurp $bk_fresh]] > 40}] \
          [expr {[bk_slurp $kbpath] eq [bk_slurp $bk_fresh]}]] \
    {1 1}

  # ---- BK18: A REAL Ctrl-B KEYSTROKE, AND THE ONE NEW COLLISION CLASS. ------
  # Two legs of one claim: where does a real Ctrl-B EVENT land? On the canvas it
  # must reach the WaveViewer tag binding; in the browser's own search entry it
  # must reach nothing at all.
  #
  # THE COLLISION CLASS Ctrl-L NEVER HAD.
  # Tk maps the virtual event <<PrevChar>> to <Control-Key-b> (`event info
  # <<PrevChar>>` answers `<Key-Left> <Control-Key-b> <Control-Lock-Key-B>`), and
  # the browser's search entry is a text widget. So the chord now has a
  # candidate consumer that Ctrl-L never had.
  # ⚠ THE EXPECTED VALUE HERE WAS MEASURED, NOT PREDICTED. The bar's entry is a
  # ttk entry and the WaveViewer bindtag lives on the CANVAS, not on the entry
  # or the toplevel, so neither consumer fires: the insert cursor does not move
  # and the sidebar does not toggle. Pinning the measurement is what turns a
  # future Tk/ttk change, or a bindtag added to the toplevel, into a red here.
  pcall ::wviewer::browser_show $tok
  update
  set bk_e $vtop.wvbrowser.wvsearch.pat
  if {![winfo exists $bk_e]} {
    puts "SKIPPED: BK18 (the browser search entry was never built)"
  } else {
    catch {$bk_e delete 0 end}
    catch {$bk_e insert 0 abcdef}
    catch {$bk_e icursor 6}
    for {set i 0} {$i < 50} {incr i} {
      focus -force $bk_e; update
      if {[focus -displayof $bk_e] eq $bk_e} break
      after 20
    }
    set bk_shown0 [pcall ::wviewer::browser_shown $tok]
    set bk_sym0 $::sym_txt
    catch {event generate $bk_e <Control-Key-b> -time [incr ::bkt 1000]}
    update
    check {BK18 (X, MEASURED) Ctrl-B typed INTO the browser's search entry moves
           no insert cursor, edits no text, toggles no sidebar and flips no
           sym_txt — the chord's one new collision class does not fire} \
      [list [pcall $bk_e index insert] [pcall $bk_e get] \
            [pcall ::wviewer::browser_shown $tok] $::sym_txt] \
      [list 6 abcdef $bk_shown0 $bk_sym0]
  }

  # THE CANVAS LEG.
  # ⚠ NOT A HARD ORACLE, and BS46's precedent is why: its only signal is "did
  # the state change", which cannot tell a WSLg key-delivery stall from a broken
  # binding. It SELF-SKIPS with a printed line; the hard oracles stay BK12 (the
  # routing) and BK15 (the binding). What it adds that neither has is the whole
  # Tk path — widget binding first, tag binding second — in one press.
  pcall ::wviewer::browser_show $::bktok
  update
  bk_ctx
  set bk_start [pcall ::wviewer::browser_shown $tok]
  set bk_s0 $::sym_txt
  set bk_del [send_key $vdrw <Control-Key-b> \
                {[wviewer::browser_shown $::bktok] != $bk_start}]
  if {!$bk_del} {
    puts "SKIPPED: BK18 real-key leg (Ctrl-B delivery never confirmed)"
  } else {
    update
    check {BK18 (X) a REAL Ctrl-B on the canvas flipped the sidebar and its mirror together
           and left sym_txt exactly where it was} \
      [list [pcall ::wviewer::browser_shown $tok] \
            $::wviewer::browsershow($tok) $::sym_txt] \
      [list [expr {!$bk_start}] [expr {!$bk_start}] $bk_s0]
  }

  catch {wviewer::close $tok}
  }
} else {
  puts "SKIPPED: BKV group (Tk/X arm only)"
}

# ============================================================================
# BK29-BK31 — TWO-PANE item 17b's X arm. NO viewer and no fixture: every claim
# here is about the LIVE binding table and the cheat-sheet generated from it,
# which are exactly the two things a source grep cannot see.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # NEVER THROWS: an unreadable dump is the assertable value NO-DUMP, so "the
  # table vanished" cannot answer 0 and read as "the row is correctly absent".
  proc bk_row {} {
    set d [pcall xschem bindings dump]
    if {![bs_set $d]} { return NO-DUMP }
    return [expr {[lsearch -exact $d \
      {key 118 ctrl+alt canvas wave.show_in_signal_browser}] >= 0 ? 1 : 0}]
  }
  proc bk_nrows {} {
    set d [pcall xschem bindings dump]
    if {![bs_set $d]} { return NO-DUMP }
    return [llength $d]
  }
  proc bk_n53 {} {
    set d [pcall xschem bindings dump]
    if {![bs_set $d]} { return NO-DUMP }
    set n 0
    foreach r $d { if {[lrange $r 0 1] eq {key 53}} { incr n } }
    return $n
  }

  # ⚠ LEG 2 IS A PRE-EXISTING ZERO and is NOT the evidence — keysym 53 ('5')
  # never had a binding-table row; the old chord was a Tk `bind` in an rc file,
  # which the table cannot see. It is here as the statement that item 17b did not
  # "fix" the move by ADDING a 53 row. Leg 1 and leg 3 are what carry the item.
  # MEASURED before the item: 71 rows; the row this item adds makes it 72, and no
  # other test in the repo asserts that length, so this is its count oracle.
  check {BK29 (X) the LIVE binding table carries the ctrl+alt row, still has no
         canvas row for keysym 53, and grew by exactly one} \
    [list [bk_row] [bk_n53] [bk_nrows]] {1 0 72}

  # ⚠ THE CASE SPLIT IS REAL AND MEASURED, do not "tidy" it: the Tools menu
  # accelerator is `Ctrl+Alt+V` (house style, cf. file.save_as_symbol's
  # Ctrl+Alt+S) while `keybinding_chord_label` renders keysym 118 as `%c` and so
  # emits `Ctrl+Alt+v`. Two different literals for one chord.
  # Leg 2 is test_keybindings_help's `(bare: <id>)` claim brought INSIDE this
  # baseline: the registry row without the actions.csv row renders the raw id.
  set bk_help [pcall generate_keybindings_text]
  check {BK30 (X) the cheat-sheet renders the chord WITH its actions.csv label,
         lowercase v, and no `(bare:` fallback anywhere} \
    [list [expr {[llength [regexp -line -inline \
                    {^  Ctrl\+Alt\+v\s+Show in Signal Browser$} $bk_help]] > 0}] \
          [regexp -all {\(bare: } $bk_help]] \
    {1 0}

  # ---- BK31: R10's WHOLE POINT, at the table level. -------------------------
  # An rc `bind` is indistinguishable from a registry row by behaviour alone —
  # BX54 would be green either way. Only the UN-BIND can tell them apart, and
  # only a registry row can be un-bound.
  set bk_t1 [bk_row]
  pcall xschem unbind key 118 ctrl+alt canvas
  set bk_t2 [bk_row]
  set bk_t3 [bk_nrows]
  pcall xschem bind key 118 ctrl+alt canvas wave.show_in_signal_browser
  set bk_t4 [bk_row]
  set bk_t5 [bk_nrows]
  check {BK31 (X, REMAPPABILITY) bound -> unbind removes the row and the table
         shrinks -> rebind puts it back and the table grows again} \
    [list $bk_t1 $bk_t2 $bk_t3 $bk_t4 $bk_t5] {1 0 71 1 72}
} else {
  puts "SKIPPED: BK29-BK31 (Tk/X arm only)"
}

# ============================================================================
# BK36-BK42 — TWO-PANE item 18's X arm. R12 END TO END on a corpus that HAS
# device classes.
#
# ⚠⚠ IT BUILDS ITS OWN TOPLEVEL AND ITS OWN TOKEN, and both are forced:
#   * the BKV sky130 `test_nfet_final` session has no device-classed signals at
#     all, so `devint 0` and `devint 1` describe the same tree and the whole item
#     would be untestable on it;
#   * spec §9's live note — a ticked box makes `browser_state` non-default, so
#     `snapshot` starts emitting a `browser` key it did not emit before. That is
#     CORRECT, and the mitigation is fixture hygiene rather than a code change:
#     this group owns `wvbk18` end to end and destroys it, so no later file
#     inherits a ticked box or a 424-name browser. BK42's teardown leg is that
#     claim as a value.
#
# ⚠ `browser_refresh <tok> 1` MUST NEVER APPEAR IN THIS BLOCK's own helpers.
# It runs `browser_reload`, whose job is to overwrite `browsersigs` from
# `signal_list` — `{}` with no raw loaded — and two-pane item 12 lost three
# checks to exactly that. `bk_seed` re-seeds and refreshes with reload 0.
# The ONE place a reload legitimately happens is INSIDE `browser_show_path`'s
# shipped improve-or-restore, and BK42 is the check that it puts everything back.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  catch {destroy .wvbk18}
  toplevel .wvbk18
  wm title .wvbk18 {two-pane item18 R12 auto-unhide fixture}
  wm geometry .wvbk18 1400x620+40+40
  canvas .wvbk18.drw -background white -width 1200 -height 580
  pack .wvbk18.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbk18 [dict create top .wvbk18 win_path .wvbk18.drw]
  update
  bs_wait_mapped .wvbk18.drw

  set BKF   .wvbk18.wvbrowser
  set BKTV  $BKF.pw.tvf.tv
  set bktok wvbk18

  set bk_built [pcall ::wviewer::browser_build $bktok .wvbk18]
  # ⚠ THE SIDEBAR MUST BE PACKED AND MAPPED. `browser_reveal`'s `$tv see` is the
  # expansion, and `see` on an unmapped tree is a no-op — BK38's open-set legs
  # would then read 0 for a reason that has nothing to do with this item.
  pcall ::wviewer::browser_toggle 1 $bktok
  update
  bs_wait_mapped $BKTV

  # THE CORPUS, SEEDED AFTER THE SHOW. `browser_show` ends with
  # `browser_refresh $token 1`, so a corpus seeded before it is wiped by the
  # show itself.
  proc bk_fixture {name} {
    set p [file join [file dirname [info script]] fixtures $name]
    if {![file exists $p]} { return NO-FIXTURE }
    set fp [open $p r] ; set t [read $fp] ; close $fp
    set out {}
    foreach l [split [string trim $t] "\n"] {
      set l [string trim $l]
      if {$l ne {}} { lappend out $l }
    }
    if {![llength $out]} { return EMPTY-FIXTURE }
    return $out
  }
  set bk_corpus [bk_fixture tb_bandgap_vars.txt]

  # The pre-state every group in this block starts from: the shipped default
  # pair (box OFF / source currents ON), the corpus back, one reload-free
  # refresh. It writes the -variable arrays directly, which is all a click does.
  proc bk_seed {} {
    set ::wviewer::browsersigs(wvbk18) $::bk_corpus
    set ::wviewer::browserdev(wvbk18) 0
    set ::wviewer::browsersrc(wvbk18) 1
    catch {::wviewer::browser_refresh wvbk18 0}
    update
    return ok
  }

  # ⚠ THE SPY IS INSTALLED BY RENAME AND CALLS THROUGH, and nothing else works:
  # the checkbutton's -command is `[list wviewer::browser_refresh $token]`, which
  # Tk resolves BY NAME at invoke time. A wrapper installed any other way counts
  # zero and BK41 goes green on a broken item.
  # ⚠ IT IS NEVER ON DURING `bk_seed` — the seeder's own refresh would inflate
  # every count by one.
  set ::bk_nref 0
  proc bk_spy_on {} {
    set ::bk_nref 0
    if {[info commands ::wviewer::__bk_refresh_real] eq {}} {
      rename ::wviewer::browser_refresh ::wviewer::__bk_refresh_real
      proc ::wviewer::browser_refresh {token {reload 0}} {
        incr ::bk_nref
        return [::wviewer::__bk_refresh_real $token $reload]
      }
    }
    return ok
  }
  proc bk_spy_off {} {
    if {[info commands ::wviewer::__bk_refresh_real] ne {}} {
      rename ::wviewer::browser_refresh {}
      rename ::wviewer::__bk_refresh_real ::wviewer::browser_refresh
    }
    return ok
  }

  # "the row vanished" as an assertable VALUE, never an exception.
  proc bk_node {id} {
    set tv .wvbk18.wvbrowser.pw.tvf.tv
    if {[catch {winfo exists $tv} e] || !$e} { return NO-TREE }
    if {[catch {$tv exists $id} r]} { return NO-TREE }
    return [expr {$r ? 1 : 0}]
  }

  bk_seed
  check {BK36 (FIXTURE) the item-18 toplevel builds, the sidebar is PACKED, and
         the 424-name corpus really drove the measured 45-node box-OFF tree} \
    [list $bk_built [bs_packed $BKF] [llength $bk_corpus] \
          [llength [bs_tree_ids $BKTV]]] \
    {1 1 424 45}

  # --- BK36: R12 ITSELF -----------------------------------------------------
  # ⚠ LEGS 1 AND 2 ARE THE PRECONDITION AND THEY ARE IN THE SAME TUPLE ON
  # PURPOSE. Without them "the node is selected and the box is 1" is satisfied by
  # a browser that was ALREADY showing device internals — the item working and
  # the item never running look identical from the far side.
  # MEASURED SHIPPED PRE-STATE for this path: `{partial g:x1.x1 x1.x1 x1.x1.xm1}`
  # (the walk reaches 2 of 3 segments). This item turns that into a full landing.
  bk_seed
  set bk_box0 [pcall ::wviewer::browser_devint $bktok]
  set bk_pre  [bk_node g:x1.x1.xm1]
  bk_spy_on
  set bk_res  [pcall ::wviewer::browser_show_path $bktok x1.x1.xm1]
  set bk_n1   $::bk_nref
  bk_spy_off
  update
  check {BK36 (X, R12) with the box OFF and the node genuinely ABSENT, a reveal
         onto a device instance unhides it, lands on it, selects it, and leaves
         the box TICKED} \
    [list $bk_box0 $bk_pre $bk_res [pcall $BKTV selection] \
          [pcall ::wviewer::browser_devint $bktok] [bk_node g:x1.x1.xm1]] \
    [list 0 0 {unhidden g:x1.x1.xm1 x1.x1.xm1} g:x1.x1.xm1 1 1]

  # ⚠ BYTE-EXACT, NOT `string match`, and on `.ph` — which is where the shipped
  # `browser_msg` sentence has always landed (`browser_status` writes
  # "Signal Browser\n<msg>" and `browser_say` calls it on every branch). MEASURED
  # before writing this: no `.ph` move is required, so the twelve byte-identity
  # pins carried in from item 12 (BD52, BX37, BX42, BX44-BX46, BH50, BH51, BH54)
  # are untouched. §7.2's three-state caption still owns that widget's future.
  check {BK37 (X) ...and it SAYS SO, in the SAME "Signal Browser\n<msg>" format
         the rest of the family pins byte-for-byte} \
    [pcall $BKF.ph cget -text] \
    "Signal Browser\nshowing device internals to reach x1.x1.xm1"

  # --- BK38: R12's LAST SENTENCE --------------------------------------------
  # "The box stays ticked." A refresh is the cheapest thing that could put it
  # back, so the claim is asserted one refresh LATER, not immediately.
  # ⚠ THE LAST THREE LEGS ARE ITEM 13's REVEAL CONTRACT, restated here because
  # this is the batch's only reveal onto a node that did not exist a moment ago:
  # the ancestors OPEN, the target CLOSED. A bbox read would flake on geometry;
  # `-open` is a stored value.
  pcall ::wviewer::browser_refresh $bktok 0
  update
  check {BK38 (X, R12's LAST SENTENCE) one refresh later the box is STILL
         ticked, the accessor and the -variable agree, the node is still
         selected, and item 13's reveal left the ANCESTORS open and the TARGET
         closed} \
    [list [pcall ::wviewer::browser_devint $bktok] \
          [pcall set ::wviewer::browserdev($bktok)] \
          [pcall $BKTV selection] \
          [pcall $BKTV item g:x1 -open] \
          [pcall $BKTV item g:x1.x1 -open] \
          [pcall $BKTV item g:x1.x1.xm1 -open]] \
    {1 1 g:x1.x1.xm1 1 1 0}

  # --- BK39: THE ABSENCE CONTROL, AND HALF OF THE DUAL PAIR -----------------
  # "The node is missing, so tick the box" would tick it HERE. The probe's
  # POSITIVE test is the only thing that stops it.
  #
  # ⚠⚠ THE PAIR IS IN ONE TUPLE, AND THE RED RUN IS WHY. Written as the absence
  # alone this check was GREEN before a line of item 18 existed — "the box did
  # not move" is precisely what NO CODE produces, the hollow shape item 12
  # shipped twice. Legs 1-2 are the call that MUST tick; legs 3-5 the call that
  # must NOT. With the pair together, the `0` in leg 3 is a DECISION rather than
  # inertia, and there is no state of the world in which both halves are
  # satisfied by an item that never ran.
  # ⚠ Leg 3 unavoidably reads the value `bk_seed` wrote (an absence control has
  # nowhere else to start). Legs 1-2 are the answer to that: they prove this same
  # code path CAN move the box on this same fixture, moments earlier.
  #
  # ⚠ THE REFRESH COUNT IS THE SHIPPED ONE, MEASURED, NOT THE ITEM'S: the
  # improve-or-restore arm already spends exactly one `browser_refresh <tok> 1`
  # on any miss. The probe adds none. It is also what makes the rejected
  # "tick, refresh, re-resolve, untick" shape visible — that shape spends three.
  bk_seed
  set bk_hit39  [pcall ::wviewer::browser_show_path $bktok x1.x1.xm1]
  set bk_hbox39 [pcall ::wviewer::browser_devint $bktok]
  bk_seed
  bk_spy_on
  set bk_res2 [pcall ::wviewer::browser_show_path $bktok zzz.qqq]
  set bk_n2 $::bk_nref
  bk_spy_off
  update
  check {BK39 (X, THE DUAL PAIR) the SAME call that ticks for a hidden device
         node leaves the box UNTICKED for a path in NEITHER model, reports the
         SHIPPED err sentence, and spends exactly the ONE refresh the shipped
         retry already spent} \
    [list $bk_hbox39 $bk_hit39 \
          [pcall ::wviewer::browser_devint $bktok] $bk_res2 $bk_n2] \
    [list 1 {unhidden g:x1.x1.xm1 x1.x1.xm1} \
          0 {err {no signals under 'zzz.qqq'}} 1]

  # --- BK40: THE OTHER CONTROL ----------------------------------------------
  # ⚠ RECORDED DIVERGENCE FROM THE PLAN. The PLAN calls this "a node hidden by
  # the SEARCH BAR". Since two-pane item 10 the tree's node set is
  # bar-UNFILTERED (spec §7.1), so a bar can no longer hide a NODE at all and
  # that state is unreachable. What survives — and what this pins — is that the
  # bars-active HEDGE still fires on the err sentence and still does not tick.
  # ⚠ SAME RED-RUN LESSON AS BK39: legs 5-6 clear the bar and run the call that
  # MUST tick, in this tuple, because the barred half alone was green before the
  # item existed.
  set bk_typed [bs_type $BKF.wvsearch {net*}]
  update
  set bk_res3    [pcall ::wviewer::browser_show_path $bktok zzz.qqq]
  set bk_bar_box [pcall ::wviewer::browser_devint $bktok]
  set bk_bar_ph  [string match {*Search/Filter*} [pcall $BKF.ph cget -text]]
  bs_type $BKF.wvsearch {}
  update
  set bk_hit40 [pcall ::wviewer::browser_show_path $bktok x1.x1.xm1]
  update
  check {BK40 (X, THE OTHER CONTROL) with a pattern in the Search bar the same
         absent path STILL does not tick and the sentence still carries the
         shipped bars hedge — while clearing the bar and asking for a real
         hidden node ticks it after all} \
    [list $bk_typed $bk_bar_box $bk_res3 $bk_bar_ph \
          $bk_hit40 [pcall ::wviewer::browser_devint $bktok]] \
    [list {net*} 0 \
          {err {no signals under 'zzz.qqq' (the Search/Filter bar may be hiding it)}} 1 \
          {unhidden g:x1.x1.xm1 x1.x1.xm1} 1]

  # --- BK41: ONE REFRESH, THEN ZERO -----------------------------------------
  # ⚠ THE `1` IS ALSO THE SPY'S OWN CONTROL. A spy that cannot count answers 0
  # for both calls, which would make the `0` leg — the actual claim — worthless.
  bk_seed
  bk_spy_on
  set bk_res4 [pcall ::wviewer::browser_show_path $bktok x1.x1.xm1]
  set bk_n4 $::bk_nref
  set ::bk_nref 0
  set bk_res5 [pcall ::wviewer::browser_show_path $bktok x1.x1.xm1]
  set bk_n5 $::bk_nref
  bk_spy_off
  update
  check {BK41 (X) the auto-tick costs exactly ONE refresh — and with the box
         ALREADY on the very same call is a plain `ok` costing ZERO, so there is
         no spurious "I turned it on"} \
    [list $bk_n4 $bk_res4 $bk_n5 $bk_res5] \
    [list 1 {unhidden g:x1.x1.xm1 x1.x1.xm1} 0 {ok g:x1.x1.xm1 x1.x1.xm1}]

  # --- BK42: THE IMPROVE-OR-RESTORE CONTROL ---------------------------------
  # The R12 probe rides IN FRONT of the shipped retry, so the retry's own
  # discipline has to be re-measured with the probe in place: a reload that finds
  # LESS must put browsersigs, browserrows, browserdbsigs AND the selection back.
  # ⚠ browserdbsigs is seeded by hand because this fixture has no foreign DB —
  # without it leg 3 would be 0 both sides and prove nothing.
  # ⚠⚠ LEGS 9-10 ARE THE MOVING HALF, and the red run is why they exist: the
  # eight restore legs alone were GREEN before the item, because they assert
  # SHIPPED behaviour. What they cannot see on their own is the one thing that
  # actually changed here — the probe now reads `browsersigs` on the way in, so a
  # restore that put back an EMPTY inventory would leave the R12 arm permanently
  # blind and every restore leg would still be green. Legs 9-10 ask the browser
  # for a real hidden node immediately AFTER the restore.
  bk_seed
  pcall $BKTV selection set [list g:x1.x2]
  update
  set ::wviewer::browserdbsigs($bktok) \
    [list [dict create id d0 label L names {v(a)} path {}]]
  set bk_sig0 [llength $::wviewer::browsersigs($bktok)]
  set bk_row0 [llength $::wviewer::browserrows($bktok)]
  set bk_db0  [llength $::wviewer::browserdbsigs($bktok)]
  set bk_sel0 [pcall $BKTV selection]
  pcall ::wviewer::browser_show_path $bktok zzz.qqq
  update
  set bk_sig1 [llength $::wviewer::browsersigs($bktok)]
  set bk_row1 [expr {[llength $::wviewer::browserrows($bktok)] == $bk_row0}]
  set bk_db1  [llength $::wviewer::browserdbsigs($bktok)]
  set bk_sel1 [pcall $BKTV selection]
  set bk_hit42 [pcall ::wviewer::browser_show_path $bktok x1.x1.xm1]
  update
  check {BK42 (X, THE IMPROVE-OR-RESTORE CONTROL) the shipped retry re-reads the
         raw, finds LESS, and puts browsersigs, browserrows, browserdbsigs AND
         the selection back exactly — and the restored inventory is one the R12
         probe can still see a hidden node through} \
    [list $bk_sig0 [expr {$bk_row0 > 0}] $bk_db0 $bk_sel0 \
          $bk_sig1 $bk_row1 $bk_db1 $bk_sel1 \
          $bk_hit42 [pcall ::wviewer::browser_devint $bktok]] \
    [list 424 1 1 g:x1.x2 424 1 1 g:x1.x2 \
          {unhidden g:x1.x1.xm1 x1.x1.xm1} 1]

  # --- BK42's TEARDOWN, AS A VALUE ------------------------------------------
  catch {destroy .wvbk18}
  catch {dict unset ::wviewer::windows wvbk18}
  foreach bk_a {browsersigs browserrows browserdbsigs browserdev browsersrc
                browserseaent browserraw browsercurdb} {
    catch {unset ::wviewer::${bk_a}(wvbk18)}
  }
  update
  check {BK42 (TEARDOWN, spec §9's live note) the fixture leaves NOTHING behind
         — no toplevel, no windows entry, no ticked box for another file's
         snapshot to inherit, and the refresh spy really was un-installed} \
    [list [winfo exists .wvbk18] \
          [expr {[dict exists $::wviewer::windows wvbk18] ? 1 : 0}] \
          [info exists ::wviewer::browserdev(wvbk18)] \
          [info exists ::wviewer::browsersigs(wvbk18)] \
          [info commands ::wviewer::__bk_refresh_real]] \
    [list 0 0 0 0 {}]
} else {
  puts "SKIPPED: BK36-BK42 (Tk/X arm only)"
}

wvbs_finish
