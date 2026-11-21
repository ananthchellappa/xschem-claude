# tests/headless/test_wave_sigbrowser_panes.tcl — TWO-PANE Signal Browser,
# PLAN item 9: THE PANED SKELETON.
# doc/claude/specs/waveform_signal_browser_two_pane.md (R3, R4, R11, M3, M4, M5)
# doc/claude/signal_browser_2pane_batch/PLAN.md item 9 + §3 traps 1 and 9.
#
# ⚠⚠ WHAT ITEM 9 IS, AND WHAT IT DELIBERATELY IS NOT.
# It moves the browser's single tree into a vertical `ttk::panedwindow` with an
# empty sea-of-names canvas below it, adds the tree's SECOND scrollbar, switches
# the tree to `-selectmode browse` (R4) and adds R11's two checkbuttons INERT.
# NO BEHAVIOUR CHANGES: the tree is populated exactly as it was. Items 10-13 add
# behaviour to a shape that has already stopped moving. This is the batch's ONLY
# pinned-surface move and it happens exactly once — which is why nothing else
# rides along in it, and why this file's claims are all about SHAPE.
#
# ============================================================================
# ⚠⚠ THE TWO TRAPS THIS FILE EXISTS FOR — both were RUN, not reasoned about
# ============================================================================
# TRAP 1 (PLAN §3 row 1) — `browser_width`'s four literals are SOURCE GREPS and
# stay GREEN while the width rule stops applying. BT08
# (test_wave_sigbrowser.tcl) and BP07 (_i1315.tcl) both read `wvproc_body`,
# never a live widget. Build `$f.pw` as a child of the TOPLEVEL instead of `$f`
# and both stay green while the sidebar silently stops governing the panes.
# BW05 is those greps, kept as STANDING CONTROLS and deliberately NOT trusted
# alone; BW31 (a real sash fraction strictly inside (0,1) on a MAPPED pane) and
# BW32 (`winfo parent`, and the pane's width tracking the SIDEBAR's) are the
# live checks that actually catch it.
#
# TRAP 2 (PLAN §3 row 9) — `-selectmode browse` gates only the CLASS BINDINGS.
# VERIFIED at /usr/share/tcltk/tk8.6/ttk/treeview.tcl:263: `$tv selection set
# {a b}` is UNAFFECTED and really does select two. So BW26 ("selecting two
# leaves one") is green on a broken widget unless it is paired with BW27, which
# reconfigures THE SAME WIDGET to `extended` and gets 2. Neither means anything
# without the other.
#
# ============================================================================
# ⚠ M4, AND THE MEASUREMENT THAT CORRECTED THE PLAN
# ============================================================================
# M4 requires column #0 to become `-stretch 0` WITH an explicit width AND to
# gain `-xscrollcommand`: inside `pack propagate 0` a stretching column always
# fits, so an h-scrollbar added without the stretch change is decorative.
#
# ⚠ THE PLAN'S OWN BW12/BW13 ("a DEEP tree really has something to h-scroll, a
# ONE-LEVEL tree does not") IS WRONG, and this was measured on Tk 8.6.14 rather
# than argued: ttk::treeview does NOT auto-grow column #0 to fit deep or long
# items. A six-level tree of 32-character names inside a 570 px pane reports
# `xview {0.0 1.0}` under BOTH stretch settings. Depth is not the discriminator.
# What IS the discriminator, measured on the same run:
#     -stretch 0, col #0 width 200, tree 570 px wide  -> col stays 200
#     -stretch 1, col #0 width 200, tree 570 px wide  -> col becomes 568
#     -stretch 0, col #0 wider than the pane          -> xview {0.0 0.79}
# so BW28/BW29/BW30 pin THAT: the column does not track the pane (BW28), the
# same widget switched to `-stretch 1` does track it and has nothing to scroll
# (BW29, the control and the exact state M4 forbids), and the `-xscrollcommand`
# wiring really reaches the scrollbar when there IS something to scroll (BW30).
#
# ============================================================================
# CONVENTIONS — SHARED WITH EVERY OTHER BROWSER FILE (wvbs_common.tcl)
# ============================================================================
# `check`, `check_true`, `pcall`, the counting `::bgerror`, `wvproc_body`,
# `bs_packed`, `bs_order`, `bs_wait_mapped`, `bs_sash_frac`, `bs_wait_sash`,
# `viewer_ready`, `$wsrc` and `wvbs_finish` come from wvbs_common.tcl, which is
# deliberately NOT named `test_*.tcl` (full_audit.sh selects with `test_*.tcl`).
#
# GROUP PREFIX: the two-pane skeleton is `BW`, never reused. Numbers are BLOCKED
# by arm: 01-19 source/pure (BOTH arms), 20-39 the throwaway toplevel (X only).
#
# A SECOND BAND, `BV` (issue 1724), sits at the foot of the file: "Descend to
# here" on a DEVICE node. BV01-BV15 drive the walk on a scratch design and need
# no Tk (both arms); BV20-BV27 drive the real command with a real viewer and a
# real design window (X only). The band's own header says what it claims.
#
# ⚠ THE ARM STATEMENT. The `--nogui` arm runs BW01-BW14 only — the source greps.
# EVERY shape claim (the panedwindow, the scrollbars, browse-mode, the sash
# fraction, the checkbuttons) needs real Tk and real X, so A GREEN `--nogui` RUN
# PROVES ALMOST NOTHING ABOUT ITEM 9. Run the X arm through
# tests/headless/run_suites.sh so the GUI gate can pause it.
#
# ⚠ SKIP-BANNER WORDING IS LOAD-BEARING. The X-gated group prints
# `SKIPPED: <group> (Tk/X arm only)`. NEVER `RESULT: SKIP`, never
# `skipped: no X`, never `SKIP: no X connection` — full_audit.sh's `is_skip`
# matches those three and would score the WHOLE FILE as SKIP, silently
# discarding every check that did run.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_panes.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_panes.tcl

set ::wvbs_tag  wvsigbrowser_panes
set ::wvbs_name test_wave_sigbrowser_panes
source [file join [file dirname [info script]] wvbs_common.tcl]

# ============================================================================
# ⚠⚠ TRAP 2's PAIR — AND THE PLAN'S OWN VERSION OF IT WAS SELF-CONTRADICTORY
# ============================================================================
# The PLAN's BW10 asserts "selecting two rows programmatically leaves ONE" while
# its OWN trap row 9 says `$tv selection set {a b}` is unaffected by
# `-selectmode`. Both cannot be true. RUN, not reasoned about: `selection set`
# really does select two under `browse`, so BW10 as written is red on a
# CORRECTLY built widget. Confirmed in the source at
# /usr/share/tcltk/tk8.6/ttk/treeview.tcl:262-275 — `-selectmode` is read in
# ONE place, `ttk::treeview::SelectOp`, which only the CLASS BINDINGS call.
# `selection set` is a widget command and never goes near it.
#
# So the discriminating pair has to be a REAL GESTURE. `<Button-1>` then
# `<Shift-Button-1>` dispatches `select.extend.<mode>`: under `browse` that is
# `BrowseTo` (one row), under `extended` it is `selection set [between ...]`
# (two). Same widget, same two rows, same two events — only `-selectmode`
# differs, which is exactly the control BW26 needs to mean anything.
#
# BW26b keeps the measured fact itself assertable, because it is a live hazard
# rather than trivia: a state file written by the shipped `extended` version
# restores a two-id `sel` list straight through `selection set` and R4 is false
# from the first restore. Narrowing that is item 13/14's job; item 9 pins that
# the widget will NOT do it for them.
proc bw_click2 {tv a b} {
  if {[catch {$tv bbox $a} ba]} { return "no-tree" }
  if {[catch {$tv bbox $b} bb]} { return "no-tree" }
  if {$ba eq {} || $bb eq {}} { return "no-bbox" }
  set ya [expr {[lindex $ba 1] + [lindex $ba 3] / 2}]
  set yb [expr {[lindex $bb 1] + [lindex $bb 3] / 2}]
  catch {$tv selection set {}}
  focus -force $tv
  event generate $tv <Button-1>       -x 30 -y $ya ; update
  event generate $tv <ButtonRelease-1> -x 30 -y $ya ; update
  event generate $tv <Shift-Button-1> -x 30 -y $yb ; update
  event generate $tv <ButtonRelease-1> -x 30 -y $yb ; update
  set n [llength [$tv selection]]
  catch {$tv selection set {}}
  return $n
}
proc bw_click2_as_extended {tv a b} {
  if {[catch {$tv cget -selectmode} was]} { return "no-tree" }
  $tv configure -selectmode extended
  set n [bw_click2 $tv $a $b]
  $tv configure -selectmode $was
  return $n
}
proc bw_setsel2 {tv a b} {
  catch {$tv selection set [list $a $b]}
  if {[catch {$tv selection} sel]} { return "no-tree" }
  set n [llength $sel]
  catch {$tv selection set {}}
  return $n
}

# --- item 10's three "the selection is never empty" routes --------------------
# ⚠ THE PLAN'S `begin {...}` IDIOM IS NOT A REAL PROC. Item 9 hit this too. Each
# of these is a NAMED helper that does one thing, answers a VALUE (never a
# throw), and RESTORES whatever it changed — a helper that leaves the fixture
# altered makes the next check's result depend on the order of the file.
proc bw_nonempty_sel {tv} {
  if {[catch {$tv selection} sel]} { return no-tree }
  return [expr {[llength $sel] > 0 ? 1 : 0}]
}
# a programmatic clear, then the next populate — which is the only thing that
# owes the invariant. See BW50's ⚠ for why the clear ALONE is not asserted.
proc bw_sel_after_clear_and_refresh {tok tv} {
  catch {$tv selection set {}}
  if {[catch {::wviewer::browser_refresh $tok 0}]} { return refresh-threw }
  update
  return [bw_nonempty_sel $tv]
}
proc bw_sel_after_refresh {tok tv} {
  if {[catch {::wviewer::browser_refresh $tok 0}]} { return refresh-threw }
  update
  return [bw_nonempty_sel $tv]
}
# a real keystroke through the bar's own <KeyRelease> pump, restored afterwards.
proc bw_sel_after_keystroke {tok tv bar} {
  set was {}
  catch {set was [$bar.pat get]}
  if {[bs_type $bar {v}] eq {no-bar}} { return no-bar }
  set r [bw_nonempty_sel $tv]
  bs_type $bar $was
  update
  return $r
}
# THE MEASURED FACT the invariant does NOT cover, asserted so nobody assumes it
# does: a bare programmatic `selection set {}` really does leave the tree with
# nothing selected until the next populate. The user cannot reach that state —
# under `-selectmode browse` ttk's BrowseTo always lands ON a row — but a script
# can, and pretending otherwise would make BW50 a claim about code nobody wrote.
proc bw_sel_after_bare_clear {tv} {
  catch {$tv selection set {}}
  update
  return [bw_nonempty_sel $tv]
}

if {[catch {

# ============================================================================
# BW01-BW14 — SOURCE / PURE. Both arms.
# ============================================================================
set bw_build [wvproc_body $wsrc wviewer::browser_build]
set bw_show  [wvproc_body $wsrc wviewer::browser_show]
set bw_width [wvproc_body $wsrc wviewer::browser_width]
set bw_sea   [wvproc_body $wsrc wviewer::browser_sea_build]
set bw_sash  [wvproc_body $wsrc wviewer::browser_sash]

# THE POSITIVE-EXTRACTION CONTROL. Without it every grep below is vacuously
# green on an empty string — the exact shape that let four checks pass on
# nothing during item 2's first RED run (`lsearch` on `ERR:` is -1).
check {BW01 (POSITIVE CONTROL) all five bodies were really extracted} \
  [list [expr {$bw_build ne {}}] [expr {$bw_show ne {}}] \
        [expr {$bw_width ne {}}] [expr {$bw_sea ne {}}] [expr {$bw_sash ne {}}]] \
  {1 1 1 1 1}

# M4's SOURCE half. `-stretch 1` inside a `pack propagate 0` frame is the exact
# state that makes the new h-scrollbar decorative, so its ABSENCE is assertable
# on its own — and BW29 is the live twin that proves WHY.
check {BW02 (SOURCE, M4) browser_build carries no -stretch 1 any more} \
  [regexp -all -- {-stretch 1} $bw_build] 0
check {BW03 (SOURCE, M4) ...and column #0 is -stretch 0 with an explicit width} \
  [regexp -all {column #0 -width 200 -minwidth 80 -stretch 0} $bw_build] 1
check {BW04 (SOURCE, M4) ...and the tree gained -xscrollcommand for the new bar} \
  [list [regexp -all -- {-xscrollcommand \[list \$f\.pw\.tvf\.hsb set\]} $bw_build] \
        [regexp -all -- {-yscrollcommand \[list \$f\.pw\.tvf\.sb set\]}  $bw_build]] \
  {1 1}

# R4: the tree is single-select in the SOURCE too, so a later edit that flips it
# back fails here as well as at BW26.
check {BW05 (SOURCE, R4) the tree is built -selectmode browse} \
  [list [regexp -all -- {-selectmode browse}   $bw_build] \
        [regexp -all -- {-selectmode extended} $bw_build]] {1 0}

# R11: per-TOKEN, namespace-qualified, and seeded with the two DIFFERENT
# defaults. A namespace global would make two viewers share one checkbox.
check {BW06 (SOURCE, R11) the checkbutton variables are per-TOKEN and qualified} \
  [list [regexp -all -- {-variable ::wviewer::browserdev\(\$token\)} $bw_build] \
        [regexp -all -- {-variable ::wviewer::browsersrc\(\$token\)} $bw_build]] \
  {1 1}
# INERT (item 12 wires them). `-command` on either one now would steal item 12's
# attribution as well as breaking this item's "no behaviour changes" claim.
check {BW07 (SOURCE) the two checkbuttons are built with NO -command at all} \
  [regexp -all {\$f\.opt\.(dev|src)[^\n]*-command} $bw_build] 0

# BT08's LOCAL TWIN (ruling 30: the frozen file must not be the only oracle).
# browser_build must stay geometry-neutral or item 8's BS21 — "built but not
# packed, nothing moved" — stops meaning anything. `pack $f ` with the trailing
# space is deliberate: `pack $f.opt` and `pack $f.pw` are children, not the
# sidebar itself.
check {BW08 (BT08's LOCAL TWIN) browser_build still changes NO geometry of its own} \
  [list [regexp -all {pack propagate} $bw_build] \
        [regexp -all {pack \$f } $bw_build]] {0 0}

# ⚠⚠ THE STANDING CONTROLS FOR TRAP 1, AND THEY ARE NOT TRUSTED ALONE.
# M5 says browser_width is untouched. These four literals are BT08's and BP07's
# subject; restating them here means a THIRD file fails if the width rule is
# gutted. But all three are SOURCE greps: they stay green under the trap-1
# sabotage. BW31/BW32 are the checks that actually catch it.
check {BW09 (M5, STANDING CONTROL — a GREP, see BW32) browser_width keeps its four literals} \
  [list [expr {[string first {pack propagate $f 0} $bw_width] >= 0}] \
        [expr {[string first {[winfo reqwidth $f.wvsearch] -} $bw_width] >= 0}] \
        [expr {[string first {[winfo reqwidth $f.wvsearch.err]} $bw_width] >= 0}] \
        [expr {[string first {0.45 * [winfo width $top]} $bw_width] >= 0}]] \
  {1 1 1 1}
# M5 again, the other direction: the panedwindow must not have leaked INTO the
# width rule. browser_width knows about `$f` and nothing below it.
check {BW10 (M5) browser_width says nothing about the panes} \
  [regexp -all {\$f\.pw} $bw_width] 0

# R3: the sea has a HORIZONTAL scrollbar and NO vertical one, in the source as
# well as on the widget — a name is never below the fold, only to the right.
check {BW11 (SOURCE, R3) browser_sea_build wires x-scrolling only} \
  [list [regexp -all -- {-xscrollcommand} $bw_sea] \
        [regexp -all -- {-yscrollcommand} $bw_sea] \
        [regexp -all -- {-orient horizontal} $bw_sea] \
        [regexp -all -- {-orient vertical} $bw_sea]] \
  {1 0 1 0}

# The sash is applied from browser_show's PACK branch and AFTER browser_width,
# because `sashpos` on an unmapped panedwindow computes fraction x 0 and
# collapses the tree pane (MEASURED: unmapped height 1, sashpos 0).
check {BW12 (SOURCE) browser_show applies the sash from the PACK branch, AFTER the width} \
  [expr {[string first {wviewer::browser_sash $token} $bw_show] >
         [string first {wviewer::browser_width $token} $bw_show]}] 1
check {BW13 (SOURCE) ...and the fraction is what is stored, never pixels (M3)} \
  [list [regexp -all {browsersash\(\$token\)} $bw_sash] \
        [expr {[string first {sashpos 0} $bw_sash] >= 0}]] \
  [list [regexp -all {browsersash\(\$token\)} $bw_sash] 1]
# the teardown block: an undeclared/never-unset array leaks one entry per closed
# window forever (the rule `browsersigs`/`browserrows` are already under).
check {BW14 the three new per-token arrays are unset on window teardown} \
  [list [regexp -all {catch \{unset browsersash\(\$token\)\}} $wsrc] \
        [regexp -all {catch \{unset browserdev\(\$token\)\}}  $wsrc] \
        [regexp -all {catch \{unset browsersrc\(\$token\)\}}  $wsrc]] \
  {1 1 1}

# --- BW15 — TWO-PANE ITEM 13, the ONE claim that survives without X ----------
# ⚠⚠ THE SHAPE OF ITEM 13's `browser_reveal` CHANGE IS A DELETION, NOT A LOOP,
# and this check is the only witness the `--nogui` arm gets. `$tv see $id` IS
# the expansion — ttk sets EVERY ancestor's `-open` to true and then scrolls —
# so an explicit expand-ancestors loop would be dead code no sabotage could
# reach. What item 13 removes is the ONE line that additionally force-opened
# THE TARGET, because R3 makes the LOWER pane the answer to "what is inside
# this node": landing on `x1.x2` selects it, `<<TreeviewSelect>>` fires, and the
# sea below draws its signals. Opening the node as well would say the same thing
# twice, in the pane spec §4.1 keeps for nodes only.
#
# ⚠ LEG 1 IS MANDATORY, NOT DECORATION. `wvproc_body` answers {} on a rename or
# a reformatted signature, and `regexp -all` over {} is 0 — so WITHOUT it the
# `0` on leg 2 is exactly what a vanished proc produces (BR01/BP01's idiom,
# which cost item 2 four vacuously-green checks).
#
# ⚠ LEG 3 IS THE STANDING CONTROL FOR THE SUBSTITUTED SABOTAGE. Deleting `see`
# "to honour collapsed-by-default" would satisfy leg 2 and break scrolling; it
# reds here AND at BW53 AND at BX31/BX32 in test_wave_sigbrowser_i12.tcl.
set bw_revealb [wvproc_body $wsrc wviewer::browser_reveal]
check {BW15 (SOURCE, TWO-PANE item 13) browser_reveal no longer force-opens its
       TARGET, while `see` — which IS the expansion — is still there exactly
       once; leg 1 is the body-found guard both greps are vacuous without} \
  [list [expr {$bw_revealb ne {}}] \
        [regexp -all {\$tv item \$id -open 1} $bw_revealb] \
        [regexp -all {\$tv see} $bw_revealb]] \
  {1 0 1}

# ============================================================================
# BW20-BW39 — THE LIVE SHAPE. X arm only.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  catch {destroy .wvbw1}
  toplevel .wvbw1
  wm title .wvbw1 {two-pane item9 paned skeleton fixture}
  wm geometry .wvbw1 1400x620+40+40
  canvas .wvbw1.drw -background white -width 1200 -height 580
  pack .wvbw1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbw [dict create top .wvbw1 win_path .wvbw1.drw]
  update
  set bw_mapped [bs_wait_mapped .wvbw1.drw]

  set F  .wvbw1.wvbrowser
  set TV $F.pw.tvf.tv
  set tok wvbw

  # ⚠ "NEVER BUILT" IS A DISTINCT VALUE FROM "BUILT AND EMPTY" (the whole point
  # of bs_sash_frac's -1 / -2). Assert the absence as a VALUE before the build.
  check {BW20 (POSITIVE CONTROL) before the build there is no panedwindow at all} \
    [list [winfo exists $F.pw] [bs_sash_frac $F.pw]] {0 -1}
  check {BW20 browser_build returns 1 and the panes now exist} \
    [list [pcall ::wviewer::browser_build $tok .wvbw1] \
          [winfo exists $F.pw] [winfo exists $TV] [winfo exists $F.pw.sea.c]] \
    {1 1 1 1}

  # M3: STACKED, vertical, tree on top, exactly two panes.
  check {BW21 (M3) $f.pw is a vertical TPanedwindow with exactly two panes, tree first} \
    [list [pcall winfo class $F.pw] [pcall $F.pw cget -orient] [pcall $F.pw panes]] \
    [list TPanedwindow vertical [list $F.pw.tvf $F.pw.sea]]

  # ⚠ M4 AS ONE CHECK, DELIBERATELY. Either leg alone goes green on a dead
  # scrollbar: `-stretch 0` without `-xscrollcommand` scrolls nothing, and
  # `-xscrollcommand` without `-stretch 0` has nothing to scroll.
  check {BW22 (M4, ONE CHECK) column #0 is -stretch 0 with a width, AND -xscrollcommand is set} \
    [list [pcall $TV column #0 -stretch] [expr {[bs_num [pcall $TV column #0 -width]] > 0}] \
          [bs_set [pcall $TV cget -xscrollcommand]] \
          [winfo exists $F.pw.tvf.sb] [winfo exists $F.pw.tvf.hsb]] \
    {0 1 1 1 1}

  # R3: horizontal only. A vertical scrollbar here would be a design change, not
  # an oversight — the sea flows column-major, so nothing is ever below the fold.
  #
  # ⚠ THE CHILD SET GREW IN TWO-PANE ITEM 11, AND IT IS RESTATED RATHER THAN
  # RELAXED. `$f.pw.sea.st` is spec §7.2's caption — the line that says whether
  # an empty pane means "this instance has no signals of its own", "the
  # Search/Filter bar is hiding them" or "device internals are hidden". It sits
  # HERE, under the list it describes, instead of on the sidebar's `.ph` status
  # line, because a dozen checks across four files assert `.ph`'s text BYTE-
  # IDENTICALLY as "Signal Browser\n<msg>" (BD52, BX37, BX42, BX44-BX46, BH50,
  # BH51, BH54) and `.ph` is about the WHOLE inventory, not the selected node.
  # The pinned set stays a pinned set — it is now three, not "at least two".
  check {BW23 (R3) the sea has a HORIZONTAL scrollbar, NO vertical one, and
         item 11's caption} \
    [list [lsort [pcall winfo children $F.pw.sea]] [pcall $F.pw.sea.hsb cget -orient] \
          [pcall $F.pw.sea.c cget -yscrollcommand] \
          [bs_set [pcall $F.pw.sea.c cget -xscrollcommand]] \
          [pcall winfo class $F.pw.sea.st]] \
    [list [lsort [list $F.pw.sea.c $F.pw.sea.hsb $F.pw.sea.st]] horizontal {} 1 Label]

  # R11: two boxes, TWO DIFFERENT DEFAULTS. A check that asserted "both 0" or
  # "both 1" would be green on a copy-paste of one line.
  check {BW24 (R11) the two checkbuttons exist with R11's DIFFERENT defaults} \
    [list [pcall winfo class $F.opt.dev] [pcall winfo class $F.opt.src] \
          [pcall set ::wviewer::browserdev($tok)] \
          [pcall set ::wviewer::browsersrc($tok)]] \
    {TCheckbutton TCheckbutton 0 1}
  # ⚠⚠ RESTATED BY TWO-PANE ITEM 12, WHICH IS THE ITEM ITEM 9 SAID WOULD RED IT.
  # Item 9's wording was "they are INERT for now (item 12 wires them)" asserting
  # `{{} {}}`, with the note that "wiring them now reds this and steals item 12's
  # own attribution". Item 12 wired them, so the INERT claim is now false BY
  # DESIGN and is replaced rather than deleted — the PLAN's "this item reds
  # nothing" was wrong, and this comment is the record of it.
  #
  # WHAT SURVIVES THE WIRING is the half item 9 actually cared about: the boxes
  # are OPTIONS ON THE SIDEBAR, so both must be wired to THE SAME command and it
  # must name THIS window's token. A copy-paste that leaves one box on another
  # window's token is invisible to every arithmetic check in the BW56 band —
  # they all drive `$tok` — and shows up only as a viewer whose box moves a
  # DIFFERENT viewer's tree. BW64 pins WHICH command it is and that it carries
  # no reload flag; this pins that there is one, that it is shared, and that the
  # token is ours.
  check {BW25 (RESTATED, item 12) both boxes are now WIRED, to the SAME command,
         and it names THIS window's token} \
    [list [expr {[bs_set [pcall $F.opt.dev cget -command]] ? 1 : 0}] \
          [expr {[pcall $F.opt.dev cget -command] eq [pcall $F.opt.src cget -command]}] \
          [expr {[lindex [pcall $F.opt.dev cget -command] end] eq $tok}]] \
    {1 1 1}

  # ⚠ EVERYTHING BELOW NEEDS THE SIDEBAR PACKED AND MAPPED, and that is not
  # fussiness: `$tv bbox <id>` answers {} for a row in an UNMAPPED tree, so the
  # gesture pair below silently degrades to `no-bbox` (observed) and the width
  # and sash reads collapse to 1. browser_build leaves the sidebar HIDDEN by
  # design (item 8's BS21), so the show is this fixture's job.
  pcall ::wviewer::browser_toggle 1 $tok
  update
  set bw_sidew [bs_wait_widths .wvbw1 $F .wvbw1.drw]
  bs_wait_mapped $TV

  # --- BW26/BW27: TRAP 2. NEITHER MEANS ANYTHING WITHOUT THE OTHER ----------
  pcall $TV insert {} end -id g:x1     -text x1
  pcall $TV insert {} end -id g:x1.x2  -text x2
  update
  check {BW26 (PRECONDITION) both rows really have a bbox to click} \
    [list [bs_set [pcall $TV bbox g:x1]] \
          [bs_set [pcall $TV bbox g:x1.x2]]] {1 1}
  check {BW26 (R4) a click-then-Shift-click across two rows leaves ONE selected} \
    [bw_click2 $TV g:x1 g:x1.x2] 1
  check {BW27 (BW26's CONTROL) the SAME widget as extended gets 2 on the SAME gesture} \
    [bw_click2_as_extended $TV g:x1 g:x1.x2] 2
  check {BW27 ...and the control put -selectmode back} [pcall $TV cget -selectmode] browse
  # ⚠ MEASURED, AND IT IS THE HAZARD, NOT TRIVIA (see the block comment above):
  # `-selectmode` gates the CLASS BINDINGS only, so `selection set` still sets
  # two under `browse`. A restore that hands a shipped two-id `sel` list to the
  # widget therefore breaks R4 unless the RESTORE narrows it — item 13/14's job,
  # pinned here as the reason it is owed.
  check {BW26b (MEASURED) `selection set` is blind to -selectmode and still sets TWO} \
    [bw_setsel2 $TV g:x1 g:x1.x2] 2
  catch {$TV delete [list g:x1 g:x1.x2]}

  # --- BW28/BW29/BW30: M4, LIVE. See the ⚠ block at the top of this file ----
  set bw_col0 [pcall $TV column #0 -width]
  if {![string is integer -strict $bw_col0]} { set bw_col0 -1 }
  check {BW28 (M4 LIVE) with -stretch 0 column #0 keeps its width and does NOT track the pane} \
    [list $bw_col0 [expr {$bw_col0 > 0 && $bw_col0 < [bs_num [pcall winfo width $TV]]}]] {200 1}
  # ⚠ THE CONTROL, ON THE SAME WIDGET AT THE SAME GEOMETRY. This is the state
  # M4 forbids: the column tracks the pane, so it always fits and the
  # h-scrollbar has nothing to scroll — decorative, exactly as M4 says.
  pcall $TV column #0 -stretch 1
  update
  set bw_col1 [pcall $TV column #0 -width]
  if {![string is integer -strict $bw_col1]} { set bw_col1 -1 }
  check {BW29 (BW28's CONTROL) the SAME widget as -stretch 1 DOES track the pane, and cannot scroll} \
    [list [expr {$bw_col1 > $bw_col0}] \
          [expr {$bw_col1 > 0 && abs($bw_col1 - [bs_num [pcall winfo width $TV]]) < 12}] \
          [pcall $TV xview]] \
    [list 1 1 {0.0 1.0}]
  if {$bw_col0 > 0} { pcall $TV column #0 -stretch 0 -width $bw_col0 }
  update
  # ⚠ THE WIRING IS LIVE, not merely present: widen #0 past the pane and the
  # SCROLLBAR ITSELF must move off {0 1}. `-xscrollcommand` set to a command
  # that never reaches the widget passes BW22 and fails this.
  catch {$TV column #0 -width [expr {[winfo width $TV] + 300}]}
  update
  check {BW30 (M4 WIRING IS LIVE) an oversized column really scrolls, and the SCROLLBAR knows} \
    [list [expr {[pcall $TV xview] ne {0.0 1.0}}] \
          [expr {[pcall $F.pw.tvf.hsb get] ne {0.0 1.0}}]] {1 1}
  if {$bw_col0 > 0} { pcall $TV column #0 -width $bw_col0 }
  update

  # --- BW31/BW32: TRAP 1. THE LIVE CHECKS THE FOUR GREPS CANNOT REPLACE -----
  set bw_frac [bs_wait_sash $F.pw]
  check {BW31 (TRAP 1) the sash reads a FRACTION strictly inside (0,1) on a MAPPED pane} \
    [list [expr {[bs_num [pcall winfo height $F.pw]] > 1}] \
          [expr {$bw_frac > 0 && $bw_frac < 1}]] {1 1}
  # ⚠⚠ THE ONE THAT CATCHES THE SABOTAGE. Built as a child of the TOPLEVEL the
  # panes still exist, the tree still works, BW08/BW09 stay GREEN — and the
  # sidebar has silently stopped governing them. `winfo parent` plus the width
  # tracking says so in one value.
  check {BW32 (TRAP 1 KILLER) the panes are a child of the SIDEBAR, whose width still governs them} \
    [list [pcall winfo parent $F.pw] \
          [expr {[bs_num [pcall winfo width $F.pw]] > 1}] \
          [expr {[bs_num [pcall winfo width $F.pw]] <= [winfo width $F]}] \
          [expr {[winfo width $F] - [bs_num [pcall winfo width $F.pw]] < 30}] \
          [expr {[winfo width $F] < [winfo width .wvbw1]}]] \
    [list $F 1 1 1 1]
  # the accessor round-trips a fraction (persistence itself is item 14)
  check {BW33 browser_sash moves the sash to the fraction it is given} \
    [list [pcall ::wviewer::browser_sash $tok 0.30] \
          [expr {abs([bs_wait_sash $F.pw] - 0.30) < 0.05}]] {0.30 1}
  pcall ::wviewer::browser_sash $tok 0.55

  # --- BW34: THE TREE IS REALLY FILLED --------------------------------------
  # Item 9's version of this check asserted "populated exactly as before",
  # naming a LEAF id. Item 10 takes the leaves out of the tree, so the claim is
  # restated: the tree is filled, it holds the design root and the instance
  # nodes, and the leaf is now an ASSERTABLE ABSENCE rather than a presence.
  set ::wviewer::browsersigs($tok) {v(out) v(x1.x2.net5) v(x1.y3.net5)}
  pcall ::wviewer::browser_refresh $tok 0
  update
  set bw_ids [pcall $TV children {}]
  check {BW34 (item 10) the tree is filled with NODES and the design root} \
    [list [expr {[bs_set $bw_ids] && [llength $bw_ids] > 0}] \
          [pcall $TV exists {g:x1}] [pcall $TV exists {g:}]] {1 1 1}
  # ⚠ ITEM 11 FILLED THE SEA, so "the canvas is empty" stopped being true — and
  # the restatement is a STRONGER claim, not a weaker one. R4 keeps exactly one
  # node selected, so on this three-signal fixture the design root is selected
  # and its OWN LEVEL is the single top-level signal `v(out)`. That is one cell,
  # labelled `out`, and it is what proves the two panes are wired to each other
  # from the pane that owns the skeleton.
  check {BW35 (item 11) ...and the sea now draws the SELECTED NODE's own level:
         the design root is selected, so its one top-level signal is the one
         cell, by its R8 label} \
    [list [pcall $TV selection] [bs_sea_labels $F.pw.sea.c] \
          [pcall ::wviewer::browser_sea_names $tok]] \
    [list {g:} {out} {v(out)}]
  check {BW35 (item 11) ...and a DESCENDED node shows ITS own level instead,
         while the PURE ANCESTOR between them renders legitimately EMPTY —
         which is what makes the pane a function of the selection} \
    [list [bs_sea_at $TV $F.pw.sea.c {g:x1.x2}] \
          [bs_sea_at $TV $F.pw.sea.c {g:x1}] \
          [bs_sea_at $TV $F.pw.sea.c {g:}]] \
    [list {net5} empty {out}]

  # ==========================================================================
  # BW40-BW53 — TWO-PANE ITEM 10: THE UPPER PANE GOES LIVE
  # ==========================================================================
  #
  # The fixture above is the whole inventory for this block:
  #   v(out)          path {}      -> the design root's own level
  #   v(x1.x2.net5)   path x1.x2
  #   v(x1.y3.net5)   path x1.y3
  # so the NODES are exactly {g: g:x1 g:x1.x2 g:x1.y3} and the leaves are three
  # rows that must NOT be in the tree.
  #
  # ⚠ EVERY READ BELOW GOES THROUGH `pcall` + `bs_num`/`bs_set`/an assertable
  # sentinel. Item 9 paid for that rule: an unguarded `expr` on a `pcall` result
  # threw into the outer catch and deleted 17 of 34 checks while the file still
  # printed a plausible failure count.

  # "the tree holds no leaf rows" as a SET of id namespaces, not a count.
  #   no-tree / empty / the sorted unique two-character prefixes present
  proc bw_kinds_in_tree {tv} {
    if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
    set ids [bs_tree_ids $tv]
    if {![llength $ids]} { return empty }
    set out {}
    foreach id $ids { lappend out [string range $id 0 1] }
    return [lsort -unique $out]
  }
  #   -1 no tree / 0 empty / the deepest nesting level, root = 1
  proc bw_depth {tv {id {}} {d 0}} {
    if {$d == 0} {
      if {[catch {winfo exists $tv} e] || !$e} { return -1 }
      if {![llength [bs_tree_ids $tv]]} { return 0 }
    }
    set best $d
    if {[catch {$tv children $id} kids]} { return $best }
    foreach k $kids {
      set sub [bw_depth $tv $k [expr {$d + 1}]]
      if {$sub > $best} { set best $sub }
    }
    return $best
  }

  # --- R2 / R4: one root, and it is selected --------------------------------
  # ⚠ THE EXPECTED LITERALS IN THIS BAND ARE STRING REPS, NOT NESTED LISTS, and
  # the difference cost a whole red run. `check` compares STRINGS, and
  # `[list {g:} 0]` has the string rep `g: 0` — Tcl brace-quotes an element only
  # when it must. Writing `{{g:} 0}` therefore asserts the two-character string
  # `{g:}` as the first element and is red on a CORRECT widget. Every literal
  # below is the measured string rep.
  check {BW40 (R2) the tree's top level is exactly ONE node, id `g:`, and it IS
         the selection — R4 is satisfied from the very first populate} \
    [list [pcall $TV children {}] [pcall $TV selection] \
          [pcall $TV item {g:} -text]] {g: g: design}
  # ⚠ THE SET, NEVER A COUNT (M11). "1 open" is the same number for a correct
  # tree and for one where the root is shut and a child is open.
  check {BW41 (M11) the ROOT is open and EVERY other node is closed} \
    [list [bs_open_set $TV] [pcall $TV item {g:x1} -open]] {g: 0}

  # --- R1/R3: the tree is nodes only ----------------------------------------
  check {BW42 (R1) every id in the tree is a GROUP id — no `s:` namespace at all} \
    [bw_kinds_in_tree $TV] {g:}
  # ⚠ AN ASSERTABLE ABSENCE, and its POSITIVE CONTROL on the same line: the leaf
  # is gone from the TREE while the same name is still in the ROW MODEL. One of
  # those two legs alone is green on a browser that lost the signal entirely.
  check {BW43 ...`$tv exists` on a leaf id is 0, while browserrows still has it} \
    [list [pcall $TV exists {s:v(x1.x2.net5)}] \
          [llength [pcall ::wviewer::browser_leaf_names \
                      $::wviewer::browserrows($tok) {s:v(x1.x2.net5)}]]] {0 1}
  # ⚠⚠ THE R6 CONTROL, AND THE SINGLE MOST LIKELY WRONG EDIT IN THE BATCH is
  # putting browser_tree_rows' output into browserrows as well. Everything would
  # still LOOK right and nothing would be plottable. Three values, one check:
  # the root reaches all three names, g:x1 reaches its two, and the model still
  # holds more rows than the tree shows.
  check {BW44 (R6) browserrows keeps the LEAVES, so the recursive plot still works} \
    [list [llength [pcall ::wviewer::browser_leaf_names \
                      $::wviewer::browserrows($tok) {g:}]] \
          [llength [pcall ::wviewer::browser_leaf_names \
                      $::wviewer::browserrows($tok) {g:x1}]] \
          [expr {[llength $::wviewer::browserrows($tok)] > [llength [bs_tree_ids $TV]]}]] \
    {3 2 1}
  # M11 again, behaviourally: a collapsed tree is still a TREE. Depth 1 would
  # mean the root swallowed everything, which is what "collapsed by default"
  # taken literally including the root produces.
  check {BW45 (M11) the tree still has real depth under the root} \
    [list [bw_depth $TV] [pcall $TV children {g:}]] {3 g:x1}

  # --- R5 / spec §7.1: THE BARS DO NOT TOUCH THE TREE AT ALL ----------------
  #
  # ⚠⚠ THIS BLOCK FOUND TWO REAL DEFECTS, both by being RUN.
  #
  # (1) THE HELPER LIED. `bs_type` had no focus loop, and Tk delivers KEY events
  #     to the toplevel's FOCUS widget rather than to the window named in
  #     `event generate` — so the bar ended up HOLDING the pattern, the helper
  #     cheerfully ANSWERED it, and `browser_refresh` ran ZERO times (measured).
  #     Every R5 claim below was green and hollow. See bs_type's ⚠ in
  #     wvbs_common.tcl. THE PRECONDITION BELOW IS WHAT STOPS THAT RECURRING:
  #     it asserts the STATUS LINE moved off its unfiltered count, so a dead bar
  #     can no longer make "the tree did not change" trivially true.
  #
  # (2) THE TREE WAS BEING FILTERED BY THE BARS, which spec §7.1 forbids in so
  #     many words. Typing `v(x1.x2*` one character at a time — as a user does —
  #     makes the shell pattern `v` on the FIRST keystroke, which matches
  #     nothing, so the tree emptied, `g:x1` was deleted, and the remaining
  #     seven keystrokes rebuilt it CLOSED. No amount of open-set carrying
  #     inside `browser_populate` can survive that: the node was not there to
  #     carry. The fix is in `browser_refresh` (the tree is built from the
  #     bar-UNFILTERED inventory); this check is its live witness.
  #
  # The fixture EXPANDS a node first, so "the open set survived" is not
  # vacuously green on a tree that was collapsed anyway.
  pcall $TV item {g:x1} -open 1
  update
  set bw_ids0  [bs_tree_ids $TV]
  set bw_open0 [bs_open_set $TV]
  set bw_stat0 [pcall $F.ph cget -text]
  # ⚠ ITEM 20 RE-PATTERNED THIS. The old `v(x1.x2*` matched 1 of the 3 RAW names
  # and now matches 0 labels; `net*` matches 0 raw names and 2 of the 3 LABELS
  # ({out net5 net5}), so the count moves 3 -> 2 instead of 3 -> 1 and the
  # anti-vacuity leg below still has a number to see. The flicker-provoking
  # property that made (2) below a real test is unchanged and MEASURED: typing
  # it a character at a time gives `n`, `ne`, `net` — all matching NOTHING —
  # before `net*` matches two.
  set bw_typed [bs_type $F.wvsearch {net*}]
  update
  # ⚠ THE ANTI-VACUITY GUARD FOR THE CHECK BELOW, and it is load-bearing: the
  # status line is the ONE surface the bars are still allowed to move in this
  # item, so it is the only proof available here that the search RAN at all.
  check {BW46 (R5, PRECONDITION) the tree really was expanded, the keystrokes
         really reached the bar, and the search really RAN — the status line
         moved off its unfiltered count} \
    [list $bw_typed $bw_open0 [llength $bw_ids0] \
          [string match {*3 of 3 signals*} $bw_stat0] \
          [string match {*2 of 3 signals*} [pcall $F.ph cget -text]]] \
    [list {net*} {g: g:x1} 4 1 1]
  check {BW46 (R5, spec §7.1) ...and it left the tree's NODE SET and its OPEN SET
         byte-identical — the bars narrow the lower pane, never the tree} \
    [list [bs_tree_ids $TV] [bs_open_set $TV]] [list $bw_ids0 $bw_open0]
  # BOTH SIGNS, ON ONE LINE. R5's letter is "never auto-OPENS"; auto-CLOSING is
  # the same defect wearing the other sign and is the one this rebuild could
  # have introduced.
  check {BW47 (R5) ...neither auto-OPENING a node nor auto-CLOSING one} \
    [list [expr {[lsearch -exact [bs_open_set $TV] {g:x1.x2}] < 0}] \
          [pcall $TV item {g:x1} -open]] {1 1}
  bs_type $F.wvsearch {}
  update

  # --- R4: the selection survives, and is never empty -----------------------
  check {BW48 (R4) a refresh PRESERVES an existing valid selection} \
    [list [pcall $TV selection set [list {g:x1}]] \
          [pcall ::wviewer::browser_refresh $tok 0] [pcall $TV selection]] \
    {{} 1 g:x1}
  # ...and falls back to the root when the selected node stops existing.
  #
  # ⚠ THE DRIVER HAD TO CHANGE, AND THE REASON IS THE POINT OF THE CHECK ABOVE.
  # This used to type a no-match pattern into the Search bar. After §7.1 a
  # search CANNOT remove a node from the tree — that is now BW46's claim — so
  # driving it that way would assert nothing and go green on the root fallback
  # never running. The only honest way for a selected node to stop existing is
  # for it to leave the INVENTORY, so that is what the fixture does, and the
  # PRECONDITION leg proves the node really went (otherwise "the selection is
  # still g:x1, which is also the root" could pass by accident).
  set bw_sigs0 $::wviewer::browsersigs($tok)
  set ::wviewer::browsersigs($tok) {v(out)}
  pcall ::wviewer::browser_refresh $tok 0
  update
  check {BW49 (R4, PRECONDITION) the selected node really left the tree} \
    [list [pcall $TV exists {g:x1}] [bs_tree_ids $TV]] {0 g:}
  check {BW49 (R4) ...so the selection fell back to the ROOT, never to empty} \
    [pcall $TV selection] {g:}
  set ::wviewer::browsersigs($tok) $bw_sigs0
  pcall ::wviewer::browser_refresh $tok 0
  update
  check {BW49 (R4, RESTORE) the fixture inventory is back, so the checks below
         start where BW48 left them} \
    [bs_tree_ids $TV] $bw_ids0
  # ⚠ THE INVARIANT IS ABOUT POPULATE, AND THE FOURTH LEG SAYS SO. Trap 10 names
  # the real hazard: `$tv delete` drops the selection silently and
  # browser_refresh runs on every character typed in either bar. That is legs
  # 1-3. Leg 4 is the boundary — a bare programmatic clear DOES leave the tree
  # unselected until the next populate, which no user gesture can reach
  # (`-selectmode browse` makes ttk's BrowseTo land on a row) but a script can.
  # Asserting it as 0 is what stops BW50 claiming an invariant nobody wrote.
  check {BW50 (R4) the selection survives a clear+refresh, a refresh and a
         keystroke — and a BARE clear is the declared boundary} \
    [list [bw_sel_after_clear_and_refresh $tok $TV] \
          [bw_sel_after_refresh $tok $TV] \
          [bw_sel_after_keystroke $tok $TV $F.wvsearch] \
          [bw_sel_after_bare_clear $TV]] {1 1 1 0}
  pcall ::wviewer::browser_refresh $tok 0
  update

  # --- browser_show_path's sim-root branch ----------------------------------
  # It used to CLEAR the selection, which R4 now forbids: there is a row that
  # means "the whole design" and it is the answer.
  check {BW51 browser_show_path at the sim root SELECTS the root, never clears} \
    [list [pcall ::wviewer::browser_show_path $tok {}] [pcall $TV selection]] \
    {{root {}} g:}

  # --- the state helper's premise, which item 10 invalidated ----------------
  # ⚠ browser_tree_nodes used to mean "rows WITH CHILDREN", which was the same
  # set as "groups" only while leaves were in the tree. `g:x1.x2`'s children
  # were all signals, so after item 10 it has none — and the old predicate would
  # have dropped it, silently un-persisting the collapse state of exactly the
  # leaf-most nodes.
  check {BW52 browser_tree_nodes reaches the LEAF-MOST nodes, which have no
         children of their own any more} \
    [lsort [pcall ::wviewer::browser_tree_nodes $TV]] {g: g:x1 g:x1.x2 g:x1.y3}
  check {BW53 (SOURCE) the populate path never calls `see` — that is R5's fix} \
    [list [regexp -all {\$tv see} [wvproc_body $wsrc wviewer::browser_populate]] \
          [regexp -all {\$tv see} [wvproc_body $wsrc wviewer::browser_reveal]]] \
    {0 1}
  # ⚠⚠ AND THE BEHAVIOURAL TWIN, WHICH THE SOURCE CHECK ALONE DOES NOT GIVE YOU.
  # MEASURED: adding `$tv see $want` to `browser_populate` reds BW53 and NOTHING
  # ELSE across this whole band, because every check above restores a selection
  # that is either the top-level root or a child of the already-open root — and
  # `see` on a row whose ancestors are all open changes nothing. The hazard only
  # bites when the restored selection sits under a CLOSED ancestor, which is
  # precisely the state R5 protects: the user collapses x1, types a character,
  # and `see` silently re-opens it. So the fixture MAKES that state, and the
  # PRE leg is carried in the tuple so "the ancestor was open all along" cannot
  # masquerade as "the repopulate left it alone".
  pcall $TV item {g:x1} -open 0
  pcall $TV selection set [list {g:x1.x2}]
  update
  set bw_deep0 [list [pcall $TV item {g:x1} -open] [pcall $TV selection]]
  pcall ::wviewer::browser_refresh $tok 0
  update
  check {BW53 (BEHAVIOURAL) a repopulate that restores a selection under a CLOSED
         ancestor must NOT re-open it — `see` would, and that is R5} \
    [list $bw_deep0 [pcall $TV item {g:x1} -open] [pcall $TV selection]] \
    [list {0 g:x1.x2} 0 g:x1.x2]

  # ==========================================================================
  # BW56-BW67 — TWO-PANE ITEM 12: THE TWO CHECKBOXES STOP BEING INERT
  # ==========================================================================
  #
  # ⚠⚠ THE BAND. The PLAN gives item 12 `BW40`-`BW49`; item 10 spent
  # BW40-BW53 in this file and BW53-BW55 in `_i1315.tcl`. MEASURED over both
  # files before a line was written: BW56 is the first free id. Nothing existing
  # is renumbered.
  #
  # ⚠⚠ THE PLAN SAYS THIS ITEM REDS NOTHING. IT REDS BW25, and item 9 said so
  # at the time — "INERT. Item 12 wires them; wiring them now reds this and
  # steals item 12's own attribution." BW25 is RESTATED below (not deleted): the
  # boxes still have exactly one `-command` each and it is still the same one
  # for both, which is the claim that survives the wiring.
  #
  # ⚠⚠ THE PLAN'S NODE COUNTS (44/128) ARE WRONG; MEASURED 45/129. Same
  # off-by-one item 11 already corrected once: spec §3.3's 44 counts INSTANCE
  # nodes and R2's design root is the 45th ROW. Its four SIGNAL totals
  # (424/190/374/140) do reproduce exactly. Re-measured through the shipped
  # pipeline on `fixtures/tb_bandgap_vars.txt` before any literal below existed.
  #
  # ⚠⚠ `srccur` DOES NOT MOVE THE NODE COUNT — ONLY `devint` DOES. 45 either
  # way, 129 either way. A node-count leg on the source-currents box would be
  # VACUOUSLY GREEN, so BW61 asserts the node count only across the axis that
  # discriminates and says so in its own name; srccur is asserted through the
  # SIGNAL total (BW60), which is the only place it shows.
  #
  # ⚠ THE MEASURED SET IS `browserseaent`, NOT THE `.ph` STATUS LINE. It is the
  # class-filtered ∩ bar-matched set spec §6 calls "one consistent set", it is
  # what BOTH panes consume, and with the bars empty it IS the class-filtered
  # inventory.
  #
  # ⚠⚠ THIS COMMENT USED TO END "Moving the status line is not in this item (see
  # the receipt)", and gave as its reason that "a dozen checks across four files
  # pin it BYTE-IDENTICALLY (BD52, BX37, BX42, BX44-BX46, BH50, BH51, BH54)".
  # **ISSUE 1615 MEASURED THAT AND IT WAS WRONG**: there are 43 checks in the tree
  # that read `.ph`, nine of the ten distinct named ids pin NAVIGATION sentences
  # the caption does not build, and not one of the 43 constrained the number —
  # every fixture asserting a count is entirely `net`-classed. The status line was
  # indeed `"[llength $names] of $total signals"`, BAR-matched and class-filter
  # blind, and it is now `$seaent`. **Rows BW80-BW84 below are that fence**, and
  # they live in this file because the 424-name corpus that discriminates is
  # already loaded here.

  # THE CORPUS. The three-name inventory above cannot carry this item's claim —
  # its whole content is `net`-classed, so all four combinations answer 3 and
  # the four totals collapse by construction. `fixtures/tb_bandgap_vars.txt`
  # (424 names) is hand-seeded the same way `test_wave_sigbrowser_sea.tcl` does,
  # and RESTORED afterwards by BW67's control — otherwise every later BW check
  # in this file would silently inherit a 424-name browser.
  proc bw_slurp {name} {
    set p [file join [file dirname [info script]] fixtures $name]
    if {![file exists $p]} { return NO-FIXTURE }
    set fp [open $p r]
    set t [read $fp]
    close $fp
    set out {}
    foreach l [split [string trim $t] "\n"] {
      set l [string trim $l]
      if {$l ne {}} { lappend out $l }
    }
    if {![llength $out]} { return EMPTY-FIXTURE }
    return $out
  }
  # the class-filtered ∩ bar-matched set, as a COUNT. -1 rather than a throw.
  proc bw_seen {tok} {
    if {![info exists ::wviewer::browserseaent($tok)]} { return -1 }
    return [llength $::wviewer::browserseaent($tok)]
  }
  # the upper pane's row count, live off the widget. -1 rather than a throw.
  proc bw_nodes {tv} {
    if {[catch {winfo exists $tv} e] || !$e} { return -1 }
    return [llength [bs_tree_ids $tv]]
  }
  # ONE combination, driven the way the widget drives it: write the two
  # -variable arrays (which is all a click does) and then fire the SAME
  # -command the checkbutton carries. Answers {signals nodes}; restores nothing,
  # because bw_four owns the restore.
  proc bw_combo {tok tv d s} {
    set ::wviewer::browserdev($tok) $d
    set ::wviewer::browsersrc($tok) $s
    if {[catch {::wviewer::browser_refresh $tok 0}]} { return refresh-threw }
    update
    return [list [bw_seen $tok] [bw_nodes $tv]]
  }
  # the four combinations, in the PLAN's order, restoring R11's shipped defaults.
  proc bw_four {tok tv} {
    set out {}
    foreach {d s} {1 1  0 1  1 0  0 0} {
      lappend out [lindex [bw_combo $tok $tv $d $s] 0]
    }
    bw_combo $tok $tv 0 1
    return $out
  }
  proc bw_four_nodes {tok tv} {
    set out {}
    foreach {d s} {1 1  0 1  1 0  0 0} {
      lappend out [lindex [bw_combo $tok $tv $d $s] 1]
    }
    bw_combo $tok $tv 0 1
    return $out
  }
  # a REAL gesture: ttk::checkbutton invoke toggles -variable AND runs -command,
  # which is the only route that proves the wiring rather than the arithmetic.
  proc bw_invoke {w} {
    if {[catch {$w invoke}]} { return invoke-threw }
    update
    return ok
  }
  # signal_list spy. THE ONLY THING THAT SEPARATES "re-filters" FROM "re-reads
  # the raw": browser_refresh with reload=0 never re-enters the engine, so a
  # `-command` wired to browser_reload (or to browser_refresh $tok 1) is
  # invisible to every count check above — the numbers come out identical.
  # RESTORES the real proc, always.
  proc bw_spy_on {} {
    set ::bw_spy 0
    if {[info commands ::wviewer::__bw_real_signal_list] ne {}} { return already }
    rename ::wviewer::signal_list ::wviewer::__bw_real_signal_list
    # ⚠ THE SIGNATURE MUST TRACK THE REAL PROC'S (issue 0313/0314). `signal_list`
    # grew an optional status out-var, and `browser_reload` — the very proc this
    # spy exists to detect — now calls it with two arguments. A one-argument spy
    # does not merely fail: it THROWS inside browser_refresh's `catch`, which
    # makes browser_reload dead code while the spy is installed and turns this
    # group's "the toggle re-read nothing" leg vacuously green.
    proc ::wviewer::signal_list {token {statusVar {}}} {
      incr ::bw_spy
      if {$statusVar ne {}} {
        upvar 1 $statusVar st
        return [::wviewer::__bw_real_signal_list $token st]
      }
      return [::wviewer::__bw_real_signal_list $token]
    }
    return ok
  }
  proc bw_spy_off {} {
    if {[info commands ::wviewer::__bw_real_signal_list] eq {}} { return not-on }
    rename ::wviewer::signal_list {}
    rename ::wviewer::__bw_real_signal_list ::wviewer::signal_list
    return ok
  }

  # --- BW56-BW59: THE TWO ACCESSORS, PURE -----------------------------------
  # ⚠ THE DEFAULTS MUST DIFFER. `{0 0}` or `{1 1}` is what a copy-paste of one
  # line produces and it is green against any check that asserts them
  # separately, which is why both are in ONE tuple.
  check {BW56 (R11) the defaults read back through the accessors, and they DIFFER} \
    [list [pcall ::wviewer::browser_devint $tok] [pcall ::wviewer::browser_srccur $tok]] \
    {0 1}
  # a token that was never built. The variables are seeded per token in
  # browser_build, so this is the state between a teardown and the next build —
  # and `{}` reaching browser_class_filter's `if {$devint && $srccur}` is a
  # throw, not a filter.
  check {BW57 an unknown token answers R11's defaults, not {} and not a throw} \
    [list [pcall ::wviewer::browser_devint nosuchtok] \
          [pcall ::wviewer::browser_srccur nosuchtok]] \
    {0 1}
  # the write arm, both directions, and PER TOKEN: seeding the namespace instead
  # of the array makes a second viewer inherit the first one's boxes.
  set bw_rt {}
  lappend bw_rt [pcall ::wviewer::browser_devint $tok 1]
  lappend bw_rt [pcall ::wviewer::browser_devint $tok]
  lappend bw_rt [pcall ::wviewer::browser_srccur $tok 0]
  lappend bw_rt [pcall ::wviewer::browser_srccur $tok]
  lappend bw_rt [pcall ::wviewer::browser_devint nosuchtok2]
  pcall ::wviewer::browser_devint $tok 0
  pcall ::wviewer::browser_srccur $tok 1
  lappend bw_rt [pcall ::wviewer::browser_devint $tok]
  lappend bw_rt [pcall ::wviewer::browser_srccur $tok]
  check {BW58 `want` round-trips BOTH ways, and the write is PER TOKEN — a
         second token still answers R11's default} \
    $bw_rt {1 1 0 0 0 0 1}
  # BD06's rule, applied to both new accessors: defined once and called from a
  # KNOWN, ENUMERATED set of sites, FILE-WIDE. ⚠ COUNTED AS A BARE NAME, which
  # is only legitimate because item 12 REWORDED browser_refresh's item-10
  # comment, which named both procs and would have made every count start at 1.
  # That rewording is part of item 12 precisely so this check can be the same
  # shape as BD06.
  #
  # ⚠⚠ RESTATED BY TWO-PANE ITEM 14, FROM {2 2} TO {4 4}, AND THE FOUR SITES ARE
  # ENUMERATED SO THE BIGGER NUMBER IS NOT A BLANKET PERMISSION:
  #   1  the definition
  #   2  the ONE read on the filter path (browser_refresh)
  #   3  the ONE read in the state reader   (browser_state)
  #   4  the ONE write in the state writer  (browser_state_apply)
  # ⚠⚠ RESTATED AGAIN BY TWO-PANE ITEM 18, FROM {4 4} TO {5 5}. THE FIFTH SITE:
  #   5  the ONE read each in `browser_show_path`'s R12 auto-unhide arm — the
  #      entry guard ("is the box already on?") and the scope the pure probe
  #      builds its would-be model with ("...and with the source-currents box
  #      exactly as the user left it"). MEASURED 4 and 4 before that item, 5 and
  #      5 after; legs 3 and 4 are UNMOVED at 1 and 1 because browser_refresh is
  #      not touched.
  # ⚠ AND THE ITEM'S PLAN SAID IT RED NOTHING. It said the same about item 12,
  # which red this check's ancestor. A file-wide bare-name count is invisible to
  # every behavioural check in the batch, so "reds existing: none" is never
  # evidence — grepping for the counts is.
  # ⚠ DODGING THIS BY READING `::wviewer::browserdev($token)` DIRECTLY IN THE NEW
  # ARM WOULD KEEP THE NUMBER AT 4 AND DESTROY THE CHECK'S ONLY PURPOSE. The
  # accessor exists so a scoping sabotage has one place to land; bypassing it to
  # keep a literal green is the test driving the code.
  # ⚠ THE PER-PROC LEG IS WHY THIS IS STILL A CHECK AND NOT A COUNT. A file-wide
  # 5 is satisfied by five reads crammed into the filter path and none in the
  # state pair — exactly the drift item 12 built this check to catch — so the
  # last two legs pin that the filter path still has EXACTLY ONE of each. That is
  # the "one place for a scoping sabotage to land" claim, and it is what the
  # number alone stopped buying the moment the number grew.
  check {BW59 (SOURCE, BD06's RULE) each accessor is defined ONCE and read from
         exactly the five enumerated sites, with exactly ONE of each on the
         filter path — one place for a scoping sabotage to land} \
    [list [regexp -all {browser_devint} $wsrc] [regexp -all {browser_srccur} $wsrc] \
          [regexp -all {browser_devint} [wvproc_body $wsrc wviewer::browser_refresh]] \
          [regexp -all {browser_srccur} [wvproc_body $wsrc wviewer::browser_refresh]]] \
    {5 5 1 1}

  # --- BW60/BW61: THE MEASURED ARITHMETIC, END TO END -----------------------
  set bw_sig_was $::wviewer::browsersigs($tok)
  set bw_corpus [bw_slurp tb_bandgap_vars.txt]
  check {BW60 (PRECONDITION) the 424-name corpus really loaded} \
    [expr {[llength $bw_corpus] == 424}] 1
  set ::wviewer::browsersigs($tok) $bw_corpus
  check {BW60 (THE MEASURED ARITHMETIC) the four combinations are FOUR
         DIFFERENT signal totals, driven through the widget variables} \
    [bw_four $tok $TV] {424 190 374 140}
  # ⚠ THE NODE COUNT DISCRIMINATES ON `devint` ONLY — see this block's header.
  # Asserting it across srccur too would be four legs and two facts.
  check {BW61 the tree's row count follows `devint` and is BLIND to `srccur`
         (45/129 WITH R2's design root; the spec's 44/128 count instances)} \
    [bw_four_nodes $tok $TV] {129 45 129 45}
  # ⚠ THIS IS THE SWEEP'S RESTORE, NOT A CLAIM ABOUT THE SHIPPED DEFAULT, and
  # the sabotage run is what forced the distinction. It was first written as
  # "(THE SHIPPED DEFAULT) devint 0 + srccur 1 is what a user gets" — and it
  # stayed GREEN under S2 (swap the two seeded defaults in browser_build),
  # because `bw_four` above sets both arrays explicitly on its way out. It was
  # reading its own helper's restore, not the build.
  #
  # THE BUILD-TIME PIN IS BW24 (item 9's), which reds on S2 as it should, and
  # BW56/BW57 are the accessors' own defaults. What this check is actually good
  # for is the pairing: after a four-way sweep the browser is back at 0/1 AND
  # that pair really is the 190/45 one, so no combination leaked state forward.
  check {BW61 (THE SWEEP'S RESTORE) the four-way sweep leaves the browser at 0/1,
         and that pair really is the 190/45 one — no combination leaked forward} \
    [list [pcall ::wviewer::browser_devint $tok] [pcall ::wviewer::browser_srccur $tok] \
          [bw_seen $tok] [bw_nodes $TV]] \
    {0 1 190 45}

  # --- BW80-BW84 — ISSUE 1615: THE `.ph` CAPTION'S OWN TWO NUMBERS ----------
  #
  # ⚠⚠ THIS BLOCK EXISTS BECAUSE THIS FILE'S OWN HEADER DECLARED THE STATUS LINE
  # OUT OF SCOPE, and the reason it gave was measured and WRONG. It says: "a
  # dozen checks across four files pin it BYTE-IDENTICALLY (BD52, BX37, BX42,
  # BX44-BX46, BH50, BH51, BH54)", and the spec repeats it as "nobody else may
  # move that string". Issue 1615 enumerated every `.ph`-pinning check in the
  # tree — there are 43, not 12 — and found that **not one of them constrains
  # the count**: nine of the ten named ids pin NAVIGATION sentences written by
  # `browser_say`/`browser_msg`, which the caption does not build, and every
  # fixture that does assert a count is entirely `net`-classed, so the class
  # filter removes nothing from it and the caption reads the same either way.
  # The ONE inventory in the tree that can move the number is the 424-name
  # corpus loaded above, and the three suites that seed it — this one, `_keys`
  # and `_sea` — never asserted `.ph` at all. **The caption was free to be
  # wrong here and nothing in the tree would have said so.** That is the same
  # shape as `test_scratch_home_note`'s row `C1`: a fence nobody runs, one level
  # in. So the number is asserted HERE, where the discriminating corpus already
  # lives, rather than in a new file that would need its own fixture.
  #
  # ⚠ THE READ IS OFF THE WIDGET, NEVER OFF `$st`. `browser_refresh` builds the
  # sentence into a local and hands it to `browser_status`, which is what adds
  # the `Signal Browser\n` prefix; asserting the local would stay green on a
  # `browser_status` that dropped the message on the floor.
  #
  # ⚠ AND THE NUMERATOR IS ASSERTED AGAINST `browserseaent` IN THE SAME TUPLE,
  # not on its own. A literal alone is green on a caption that agrees with
  # nothing; the pairing is spec §6's "one consistent set" stated as a check.
  # It cannot be satisfied by making BOTH wrong, because `bw_seen` is the very
  # number `BW60` above pins to `{424 190 374 140}`.

  # The caption's TWO numbers, straight off the label. `no-label` and
  # `no-count: <text>` are VALUES rather than throws, so "a navigation sentence
  # is sitting on `.ph`" stays distinguishable from "the numbers moved" — the
  # distinction `bt_count` makes in `test_wave_sigbrowser.tcl` for the same
  # widget, and the reason neither returns a bare -1.
  proc bw_ph {w} {
    if {[catch {$w cget -text} t]} { return no-label }
    if {[regexp {([0-9]+) of ([0-9]+) signals} $t - a b]} { return [list $a $b] }
    return "no-count: $t"
  }
  # The FOREIGN panes' own totals, off `browserseadbent`: {<signals> <databases
  # holding at least one>}. This is what the `+N from M other DB` suffix claims,
  # so asserting the suffix against THIS rather than against a literal is what
  # makes the row self-proving. ⚠ THE SECOND ELEMENT COUNTS NON-EMPTY ENTRIES,
  # not `dict size`: a foreign database whose every signal is class-filtered
  # away keeps its (empty) key here and mints NO row in the tree, so `dict size`
  # would agree with the defect instead of catching it.
  proc bw_dbtot {tok} {
    if {![info exists ::wviewer::browserseadbent($tok)]} { return {-1 -1} }
    set n 0 ; set k 0
    dict for {id ent} $::wviewer::browserseadbent($tok) {
      incr n [llength $ent]
      if {[llength $ent]} { incr k }
    }
    return [list $n $k]
  }
  # the four combinations again, this time reading the CAPTION and the pane set
  # together. Restores 0/1 on the way out exactly as `bw_four` does, so BW62's
  # `{0 190}` opening leg is unaffected by this block existing.
  proc bw_ph_four {tok tv w} {
    set out {}
    foreach {d s} {1 1  0 1  1 0  0 0} {
      bw_combo $tok $tv $d $s
      lappend out [list [bw_ph $w] [bw_seen $tok]]
    }
    bw_combo $tok $tv 0 1
    return $out
  }

  # --- BW80: THE HEADLINE ---------------------------------------------------
  # ⚠ THE DENOMINATOR IS DELIBERATELY STILL 424 IN ALL FOUR. The raw holds 424
  # names whatever is ticked, and that is the fact that makes the gap legible:
  # "190 of 424" says 234 are hidden, where "190 of 190" would say nothing and
  # "424 of 424" says something false.
  check {BW80 (ISSUE 1615) driven through the widget variables over the 424-name
         corpus, the `.ph` caption's NUMERATOR is the set both panes consume —
         asserted against `browserseaent` in the same tuple, with the
         denominator staying the raw's own 424 in all four combinations} \
    [bw_ph_four $tok $TV $F.ph] \
    {{{424 424} 424} {{190 424} 190} {{374 424} 374} {{140 424} 140}}

  # --- BW81: THE SENTENCE A USER ACTUALLY GETS ------------------------------
  # BW80 reads the numbers out; this reads the whole string, at the ONE
  # combination R11 ships as the default. Byte-exact, prefix included.
  check {BW81 (ISSUE 1615) at R11's shipped defaults the whole caption, prefix
         included, names the 190 signals the panes hold and the 424 the raw has} \
    [pcall $F.ph cget -text] "Signal Browser\n190 of 424 signals"

  # --- BW82: THE BAR AND THE CLASS FILTER COMPOSE ---------------------------
  # ⚠ THE PATTERN WAS CHOSEN BY MEASUREMENT, NOT BY EYE, and it has to be: the
  # bars match the LABEL, not the raw name, so `*x1*` matches ZERO of the 424
  # (the hierarchy path is not in the label). `*b*` matches 238 — 234 devnode,
  # 2 net, 2 srcbranch — which is why hiding device internals takes it to 4.
  # That 238-vs-4 gap is the largest this corpus offers, and before this issue
  # the caption reported the 238.
  set bw_ph_bar {}
  bw_combo $tok $TV 1 1
  set bw_typed_b [bs_type $F.wvsearch {*b*}]
  lappend bw_ph_bar [list [bw_ph $F.ph] [bw_seen $tok]]
  bw_combo $tok $TV 0 1
  lappend bw_ph_bar [list [bw_ph $F.ph] [bw_seen $tok]]
  check {BW82 (ISSUE 1615) with a pattern in the bar the caption follows BOTH
         narrowings — the bar moves the numerator and so does the class filter,
         and the entry really did take the pattern} \
    [list $bw_typed_b $bw_ph_bar] \
    [list {*b*} {{{238 424} 238} {{4 424} 4}}]
  bs_type $F.wvsearch {}
  check {BW82 (THE BAR'S RESTORE, ASSERTED) clearing the bar puts the caption
         back on the whole class-filtered inventory} \
    [list [bw_ph $F.ph] [bw_seen $tok]] [list {190 424} 190]

  # --- BW83/BW84: THE `+N from M other DB` SUFFIX IS THE SAME DEFECT ---------
  # ⚠⚠ ONE SENTENCE MUST NOT CARRY ONE FILTERED AND ONE UNFILTERED COUNT. The
  # All-DBs loop narrows each foreign inventory with `browser_class_filter` and
  # hands the NARROWED list to both the tree and `browserseadbent` — then
  # accumulates the PRE-filter list into the suffix. So correcting the current
  # database's numerator alone would ship a caption whose two halves disagree
  # about what the checkboxes did, which is worse than either half being wrong.
  #
  # TWO foreign databases on purpose, and the second one is the interesting one:
  # `bw_dbZ` is entirely device-classed, so at R11's defaults the class filter
  # empties it, it mints NO header and NO row in the tree, and its pane snapshot
  # is empty — yet it still contributed its full count to `+N` AND a full +1 to
  # `M`. A sentence claiming signals from a database the user cannot see is the
  # defect at its plainest.
  set bw_dbs_was {}
  if {[info exists ::wviewer::browserdbsigs($tok)]} {
    set bw_dbs_was $::wviewer::browserdbsigs($tok)
  }
  set bw_alldb_was 0
  if {[info exists ::wviewer::sballdb($F.wvsearch)]} {
    set bw_alldb_was $::wviewer::sballdb($F.wvsearch)
  }
  # ⚠ THE CLASSES ARE ASSERTED, NOT ASSUMED (BW84). A name I merely BELIEVE is
  # devnode would make BW83's arithmetic agree with the wrong thing.
  set bw_dbA [list {v(alpha)} {v(x9.beta)} {v(m.x9.mn1#body)} {i(v.x9.vsup)}]
  set bw_dbZ [list {v(m.x8.mn1#body)} {v(m.x8.mn2#body)}]
  set ::wviewer::browserdbsigs($tok) \
    [list [dict create id {d:7} label {bw_a.raw (tran)} names $bw_dbA] \
          [dict create id {d:8} label {bw_z.raw (tran)} names $bw_dbZ]]
  set ::wviewer::sballdb($F.wvsearch) 1
  check {BW84 (BW83's PRECONDITION) the two seeded foreign inventories really
         carry the classes the next row's arithmetic depends on — mixed in one,
         entirely device-classed in the other} \
    [list [llength [::wviewer::browser_class_filter \
                     [lmap n $bw_dbA {::wviewer::signal_entry $n {}}] 1 1]] \
          [llength [::wviewer::browser_class_filter \
                     [lmap n $bw_dbA {::wviewer::signal_entry $n {}}] 0 1]] \
          [llength [::wviewer::browser_class_filter \
                     [lmap n $bw_dbA {::wviewer::signal_entry $n {}}] 0 0]] \
          [llength [::wviewer::browser_class_filter \
                     [lmap n $bw_dbZ {::wviewer::signal_entry $n {}}] 1 1]] \
          [llength [::wviewer::browser_class_filter \
                     [lmap n $bw_dbZ {::wviewer::signal_entry $n {}}] 0 1]]] \
    {4 3 2 2 0}
  set bw_ph_db {}
  bw_combo $tok $TV 1 1
  lappend bw_ph_db [list [pcall $F.ph cget -text] [bw_dbtot $tok]]
  bw_combo $tok $TV 0 1
  lappend bw_ph_db [list [pcall $F.ph cget -text] [bw_dbtot $tok]]
  check {BW83 (ISSUE 1615) the `+N from M other DB` suffix counts the foreign
         signals and databases the panes actually hold — asserted against
         `browserseadbent` in the same tuple, so a database the class filter
         emptied drops out of BOTH numbers instead of being claimed} \
    $bw_ph_db \
    [list [list "Signal Browser\n424 of 424 signals, +6 from 2 other DBs" {6 2}] \
          [list "Signal Browser\n190 of 424 signals, +3 from 1 other DB" {3 1}]]
  # RESTORED AND ASSERTED IN THE SAME TUPLE (BW67's lesson): every check after
  # this one runs against the single-database browser.
  set ::wviewer::sballdb($F.wvsearch) $bw_alldb_was
  set ::wviewer::browserdbsigs($tok) $bw_dbs_was
  bw_combo $tok $TV 0 1
  check {BW83 (THE FOREIGN RESTORE, ASSERTED) the All-DBs box and the foreign
         inventory are back where this block found them, and the caption has no
         suffix at all} \
    [list [pcall set ::wviewer::sballdb($F.wvsearch)] \
          [llength $::wviewer::browserdbsigs($tok)] \
          [pcall $F.ph cget -text]] \
    [list $bw_alldb_was [llength $bw_dbs_was] "Signal Browser\n190 of 424 signals"]

  # --- BW62: THE WIRING, AS A REAL GESTURE ----------------------------------
  # Everything above sets the -variable by hand. This is the click: `invoke`
  # toggles the variable AND fires -command, so it is red on a box whose
  # -command is still {} while every arithmetic check above stays green.
  set bw_g0 [list [pcall set ::wviewer::browserdev($tok)] [bw_seen $tok]]
  bw_invoke $F.opt.dev
  set bw_g1 [list [pcall set ::wviewer::browserdev($tok)] [bw_seen $tok]]
  bw_invoke $F.opt.dev
  set bw_g2 [list [pcall set ::wviewer::browserdev($tok)] [bw_seen $tok]]
  check {BW62 (THE GESTURE) invoking the device-internals box really re-filters,
         and invoking it back really restores} \
    [list $bw_g0 $bw_g1 $bw_g2] [list {0 190} {1 424} {0 190}]
  set bw_h0 [list [pcall set ::wviewer::browsersrc($tok)] [bw_seen $tok]]
  bw_invoke $F.opt.src
  set bw_h1 [list [pcall set ::wviewer::browsersrc($tok)] [bw_seen $tok]]
  bw_invoke $F.opt.src
  check {BW62 (THE SECOND BOX IS INDEPENDENTLY WIRED) the source-currents box
         moves the total on its own — a shared -variable collapses this} \
    [list $bw_h0 $bw_h1 [pcall set ::wviewer::browsersrc($tok)] [bw_seen $tok]] \
    [list {1 190} {0 140} 1 190]

  # --- BW63/BW64: IT RE-FILTERS, IT DOES NOT RE-READ THE RAW ----------------
  # ⚠⚠ THIS CHECK WAS VACUOUS ON ITS FIRST RED RUN AND THE RED RUN IS HOW I KNOW.
  # With `-command {}` the invoke does nothing, so the spy counts 0 and BW63 was
  # GREEN before a line of item 12 existed — one of the two checks in this band
  # that passed before the code did. A zero only means something next to a leg
  # that made the spy count, and next to a leg that says the toggle DID work:
  #   [0] the spy can count at all      — browser_refresh RELOAD=1 must move it
  #   [1] the toggle re-read nothing    — the actual claim
  #   [2] the toggle nevertheless RE-FILTERED — else "nothing happened" passes
  #   [3] the real signal_list is back  — the rename is restored
  # ⚠⚠ THE CONTROL EATS THE FIXTURE, AND THE FIRST GREEN RUN IS HOW I FOUND OUT.
  # `browser_refresh $tok 1` is the only way to make signal_list run — and
  # browser_reload's whole job is to OVERWRITE `browsersigs($token)` from it.
  # With no raw loaded in this fixture that read correctly answers {}, so the
  # 424-name corpus is gone the instant the control fires and BW63, BW65 and
  # BW66 all failed on an EMPTY browser rather than on anything they claim.
  # The control therefore re-seeds what it consumed, before the measurement.
  bw_spy_on
  pcall ::wviewer::browser_refresh $tok 1
  update
  set bw_spy_ctl $::bw_spy
  set ::bw_spy 0
  set ::wviewer::browsersigs($tok) $bw_corpus
  pcall ::wviewer::browser_refresh $tok 0
  update
  set bw_p0 [bw_seen $tok]
  bw_invoke $F.opt.dev
  set bw_p1 [bw_seen $tok]
  bw_invoke $F.opt.dev
  set bw_spy_n $::bw_spy
  bw_spy_off
  check {BW63 toggling a box does NOT re-enter the engine — signal_list is not
         called (item 9's D6 snapshot rule) — WITH the control that proves the
         spy counts, and the leg that proves the toggle still did its job} \
    [list [expr {$bw_spy_ctl > 0}] $bw_spy_n \
          [expr {$bw_p1 != $bw_p0}] [info commands ::wviewer::signal_list]] \
    [list 1 0 1 ::wviewer::signal_list]
  # BW63's SOURCE twin, and it is not redundant: the spy proves nothing was
  # called on THIS fixture, where browser_reload's engine reads are already
  # wrapped in `catch` and answer {} with no xschem raw loaded. The -command
  # itself is the claim.
  check {BW64 both boxes carry the SAME -command, and it is browser_refresh with
         NO reload flag — `browser_reload` or a trailing 1 re-reads the raw} \
    [list [pcall $F.opt.dev cget -command] [pcall $F.opt.src cget -command]] \
    [list "wviewer::browser_refresh $tok" "wviewer::browser_refresh $tok"]

  # --- BW65: R5's DISCIPLINE, APPLIED TO THE BOXES --------------------------
  # The bars must not move the user's navigation surface; neither may these.
  # ⚠ THE OPEN NODE IS CHOSEN SO IT SURVIVES BOTH SCOPES. `g:x1` exists at
  # devint 0 and at devint 1, so a changed open set means the boxes disturbed
  # it — not that the node stopped existing.
  # ⚠⚠ THE SECOND CHECK IN THIS BAND THAT WAS GREEN BEFORE THE CODE EXISTED.
  # "Nothing changed" is exactly what an unwired checkbutton produces, so the
  # stability legs are worthless alone. THE SCOPE CHANGE IS CARRIED IN THE SAME
  # TUPLE: the box must have really re-filtered (190 -> 424 -> 190) WHILE the
  # open set and the selection sat still. An inert box fails leg [2]; a box that
  # rebuilds the tree from scratch fails legs [0]/[1].
  pcall $TV item {g:x1} -open 1
  pcall $TV selection set [list {g:x1}]
  update
  set bw_r0 [list [lsort [pcall bs_open_set $TV]] [pcall $TV selection]]
  set bw_n0 [bw_seen $tok]
  bw_invoke $F.opt.dev
  set bw_r1 [list [lsort [pcall bs_open_set $TV]] [pcall $TV selection]]
  set bw_n1 [bw_seen $tok]
  bw_invoke $F.opt.dev
  set bw_r2 [list [lsort [pcall bs_open_set $TV]] [pcall $TV selection]]
  set bw_n2 [bw_seen $tok]
  check {BW65 (R5's DISCIPLINE) toggling a box changes neither the open set nor
         the selected node — WHILE it really re-filters, so an inert box cannot
         satisfy this by doing nothing} \
    [list [expr {$bw_r1 eq $bw_r0}] [expr {$bw_r2 eq $bw_r0}] \
          [list $bw_n0 $bw_n1 $bw_n2] [lindex $bw_r0 1]] \
    [list 1 1 {190 424 190} g:x1]

  # --- BW66: THE CLASS FILTER REACHES THE TREE, NOT ONLY THE COUNT ----------
  # ⚠ A COUNT CAN MOVE WITHOUT THE TREE MOVING. This is the id itself: a node
  # whose every signal is device-classed must be ABSENT at devint 0 and PRESENT
  # at devint 1, which is R1's quantifier read off the live widget.
  # ids in $a that are NOT in $b. A count of 0 is "subset"; the ids themselves
  # would be the diagnosis if it ever moves.
  proc bw_not_in {a b} {
    set out {}
    foreach id $a { if {[lsearch -exact $b $id] < 0} { lappend out $id } }
    return $out
  }
  pcall ::wviewer::browser_devint $tok 1
  pcall ::wviewer::browser_refresh $tok 0
  update
  set bw_on_ids [bs_tree_ids $TV]
  pcall ::wviewer::browser_devint $tok 0
  pcall ::wviewer::browser_refresh $tok 0
  update
  set bw_off_ids [bs_tree_ids $TV]
  check {BW66 (R1, OFF THE WIDGET) the device-only nodes are an ASSERTABLE
         ABSENCE at devint 0 and really come back at devint 1 — and the OFF set
         is a strict SUBSET of the ON set, never a different tree} \
    [list [llength $bw_off_ids] [llength $bw_on_ids] \
          [expr {[llength $bw_off_ids] < [llength $bw_on_ids]}] \
          [llength [bw_not_in $bw_off_ids $bw_on_ids]]] \
    {45 129 1 0}

  # --- BW67: THE RESTORE, AS A CHECK ----------------------------------------
  # ⚠ NOT A `catch {...}` AT THE END OF THE BLOCK. The corpus is a fixture
  # change, and a restore nobody asserts is a restore that silently stops
  # happening — every later BW check would then run against a 424-name browser
  # and the file would still be green.
  set ::wviewer::browsersigs($tok) $bw_sig_was
  pcall ::wviewer::browser_devint $tok 0
  pcall ::wviewer::browser_srccur $tok 1
  pcall ::wviewer::browser_refresh $tok 0
  update
  check {BW67 (THE RESTORE, ASSERTED) the three-name inventory and R11's shipped
         defaults are back, and the tree is item 10's four nodes again} \
    [list $::wviewer::browsersigs($tok) \
          [pcall ::wviewer::browser_devint $tok] [pcall ::wviewer::browser_srccur $tok] \
          [lsort [bs_tree_ids $TV]]] \
    [list {v(out) v(x1.x2.net5) v(x1.y3.net5)} 0 1 {g: g:x1 g:x1.x2 g:x1.y3}]

  # ==========================================================================
  # BW68-BW76 — TWO-PANE ITEM 13: browser_reveal / browser_tree_apply UNDER
  # COLLAPSED-BY-DEFAULT
  # ==========================================================================
  # spec §4.2 (`see` may only be reached from a USER-INITIATED reveal, and the
  # persisted `open` set must BEAT it) and spec §7.3 (a shipped multi-id `sel`
  # is narrowed to its first SURVIVING id; an all-dead one falls back to the
  # root). Two procs move: `browser_reveal` loses one line, `browser_tree_apply`
  # gains a narrowing and a fallback. The ORDER inside `browser_tree_apply`
  # — SELECTION FIRST, OPEN-SET LAST — is untouched and BW76 is why.
  #
  # ⚠⚠ THE BAND, AND WHY IT IS NOT THE PLAN'S. PLAN item 13 asks for
  # `BW50`-`BW58`. MEASURED: `BW50`-`BW53` are two-pane item 10's (they are
  # above, in this file) and `BW56`-`BW58` are two-pane item 12's. First free id
  # at the time of writing is BW68, and the one SOURCE claim takes BW15 out of
  # this file's own 01-19 "both arms" block. Nothing is renumbered.
  #
  # ⚠⚠ THE NODE IDS ARE NOT THE PLAN'S EITHER. Every PLAN check in item 13 names
  # `g:y3`. MEASURED: this file's fixture tree is exactly
  # `{g: g:x1 g:x1.x2 g:x1.y3}` — THERE IS NO `g:y3` here; that id belongs to
  # test_wave_sigbrowser_i1315.tcl's raw-backed fixture (BP43a). The sibling
  # available on THIS tree is the TARGET's sibling `g:x1.y3`, which is the
  # better discriminator anyway: `g:x1` is the root's ONLY child, so "a sibling
  # of an ANCESTOR stays collapsed" is not even expressible here.
  #
  # ⚠⚠⚠ THE ONE PLAN CLAUSE THIS ITEM REFUSES, AND THE REFUSAL IS BW76.
  # PLAN item 13 also asks `browser_tree_apply` to "union the selection's
  # ancestor chain into the applied open set". IT IS NOT IMPLEMENTED, because
  # spec §4.2 forbids it in so many words:
  #     "the persisted `open` set must beat it — BP54 already pins that a
  #      persisted collapse beats `see`'s ancestor-expansion, and that check
  #      stays green."
  # MEASURED on this fixture, before any code changed:
  #   * with NO `open` key the open pass is SKIPPED and `see` has ALREADY opened
  #     the whole chain — so the union is a NO-OP exactly where it is harmless;
  #   * with `{open {g: g:x1.y3} sel {g:x1.x2}}` the open pass runs LAST and
  #     leaves `g:x1` CLOSED — which is the state the union would flip, i.e. it
  #     is a §4.2 violation exactly where it bites.
  # It also breaks round-trip idempotency: the widened set is what the next
  # `browser_state` persists, so the user's collapse dissolves over sessions.
  # BW76 is its standing guard here, and it is green BEFORE and AFTER on
  # purpose; BP53 (i1315:1468) and BP54 (i1315:1495) are the cross-file twins.
  # Implementing the union reds all three — three files triangulating one proc.

  # SEVEN-VALUED, NEVER THROWS — the same contract as `bx_vis` in
  # test_wave_sigbrowser_i12.tcl. `unmapped` is checked BEFORE bbox precisely
  # because bbox cannot see it, and `collapsed` must be distinguishable from
  # `offscreen` or "it is visible" means two different things.
  proc bw_vis {tv id} {
    if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
    if {$id eq {}} { return root }
    if {[catch {$tv exists $id} ex] || !$ex} { return absent }
    set p $id
    while {1} {
      set par {}
      if {[catch {$tv parent $p} par]} { return absent }
      if {$par eq {}} break
      set o 0
      catch {set o [$tv item $par -open]}
      if {!$o} { return collapsed }
      set p $par
    }
    set m 0
    catch {set m [winfo ismapped $tv]}
    if {!$m} { return unmapped }
    set bb {}
    catch {set bb [$tv bbox $id]}
    if {$bb eq {}} { return offscreen }
    return visible
  }
  # THE PRECONDITION EVERY CHECK BELOW STARTS FROM, and it ANSWERS the state it
  # reached rather than assuming it: item 10's lesson is that "the ancestor was
  # open all along" must never be able to masquerade as "the reveal opened it".
  proc bw_collapse_all {tv} {
    foreach id [bs_tree_ids $tv] { catch {$tv item $id -open 0} }
    update
    return [bs_open_set $tv]
  }

  # {pre-open-set  ret  root-open  anc-open  TARGET-open  sibling-open  vis  sel}
  proc bw_reveal_probe {tok tv root anc id sib} {
    set pre [bw_collapse_all $tv]
    set r [pcall ::wviewer::browser_reveal $tok $id]
    update
    return [list $pre $r [pcall $tv item $root -open] [pcall $tv item $anc -open] \
                 [pcall $tv item $id -open] [pcall $tv item $sib -open] \
                 [bw_vis $tv $id] [pcall $tv selection]]
  }
  # {before  after-set  after-cleared  children}  — is `-open` even a live
  # discriminator on a CHILDLESS node? Without this, BW68's `0` asserts nothing.
  proc bw_open_roundtrip {tv id} {
    bw_collapse_all $tv
    set a [pcall $tv item $id -open]
    catch {$tv item $id -open 1}
    set b [pcall $tv item $id -open]
    catch {$tv item $id -open 0}
    set c [pcall $tv item $id -open]
    return [list $a $b $c [pcall $tv children $id]]
  }
  # {open-set-before  open-set-after-a-reveal}
  proc bw_multi_open_probe {tok tv ids target} {
    bw_collapse_all $tv
    foreach id $ids { catch {$tv item $id -open 1} }
    update
    set before [bs_open_set $tv]
    pcall ::wviewer::browser_reveal $tok $target
    update
    return [list $before [bs_open_set $tv]]
  }
  # {ret-on-{}  sel-after-{}  ret-on-a-real-id  sel-after-it}
  proc bw_reveal_pair {tok tv presel other} {
    bw_collapse_all $tv
    catch {$tv selection set [list $presel]}
    update
    set a [pcall ::wviewer::browser_reveal $tok {}]
    set b [pcall $tv selection]
    set c [pcall ::wviewer::browser_reveal $tok $other]
    set d [pcall $tv selection]
    return [list $a $b $c $d]
  }
  # {ret  selection}
  proc bw_apply_sel {tok tv open sel} {
    bw_collapse_all $tv
    set r [pcall ::wviewer::browser_tree_apply $tok [list open $open sel $sel]]
    update
    return [list $r [pcall $tv selection]]
  }
  # {pre-selection  ret  post-selection  post-open-set}
  # ⚠ LEG 4 IS THE ANTI-VACUITY LEG, and it is what stops the EMPTY-`sel` arm
  # (BW74's second) being green on a `browser_tree_apply` that does NOTHING at
  # all: the open pass really ran, so "the selection was left alone" is a
  # decision the proc took rather than a call that never happened.
  proc bw_apply_dead {tok tv presel sel} {
    bw_collapse_all $tv
    catch {$tv selection set [list $presel]}
    update
    set pre [pcall $tv selection]
    set r [pcall ::wviewer::browser_tree_apply $tok [list open {g:} sel $sel]]
    update
    return [list $pre $r [pcall $tv selection] [bs_open_set $tv]]
  }
  # THE NO-ROOT ARM, AND ITS OWN POSITIVE ARM, IN ONE TUPLE:
  #   {root-id-with-the-swapped-model  ret  selection  root-id-after-the-restore
  #    ret-on-the-RESTORED-model  selection-on-the-RESTORED-model}
  #
  # ⚠⚠ MEASURED ON THE RED RUN, AND THIS IS WHY THE HELPER HAS SIX LEGS INSTEAD
  # OF FOUR. The four-leg version asserted only "with no root the fallback is a
  # no-op" — which is byte-identical to "there is no fallback at all", i.e. it
  # was GREEN BEFORE ITEM 13's CODE EXISTED. That is precisely the shape
  # two-pane item 12 shipped twice. Legs 5-6 repeat the SAME call on the
  # RESTORED model, where the fallback MUST fire, so the no-op on legs 2-3 is
  # now a decision the proc took rather than a proc that does not exist.
  #
  # ⚠⚠ AND IT EATS THE FIXTURE IF IT DOES NOT PUT IT BACK: browserrows is the
  # array browser_leaf_names / browser_plot_ids / browser_menu_ids all read. Leg
  # 4 asserts the restore IN THE SAME TUPLE (item 12's BW67 lesson) and is also
  # the precondition legs 5-6 rest on — a restore nobody asserts is a restore
  # that silently stops happening.
  proc bw_apply_dead_norootrows {tok tv presel} {
    bw_collapse_all $tv
    catch {$tv selection set [list $presel]}
    update
    set was $::wviewer::browserrows($tok)
    set rows {}
    foreach r $was {
      if {[pcall ::wviewer::dget $r id {}] eq {g:}} { continue }
      lappend rows $r
    }
    set ::wviewer::browserrows($tok) $rows
    set seen [pcall ::wviewer::browser_root_id $::wviewer::browserrows($tok)]
    if {$seen eq {}} { set seen no-root }
    set r [pcall ::wviewer::browser_tree_apply $tok [list open {g:} sel {g:zz}]]
    update
    set sel [pcall $tv selection]
    # THE RESTORE, then THE POSITIVE ARM on the very same call shape.
    set ::wviewer::browserrows($tok) $was
    set back [pcall ::wviewer::browser_root_id $::wviewer::browserrows($tok)]
    bw_collapse_all $tv
    catch {$tv selection set [list $presel]}
    update
    set r2 [pcall ::wviewer::browser_tree_apply $tok [list open {g:} sel {g:zz}]]
    update
    return [list $seen $r $sel $back $r2 [pcall $tv selection]]
  }
  # {see-ALONE opened $anc?  $anc after the SAME sel WITH the open set  the
  #  whole open set  the selection}. Leg 1 is the positive control without which
  # "it was closed anyway" reads exactly like "the open pass won".
  proc bw_order_probe {tok tv anc sel open} {
    bw_collapse_all $tv
    pcall ::wviewer::browser_tree_apply $tok [list sel $sel]
    update
    set seealone [pcall $tv item $anc -open]
    bw_collapse_all $tv
    pcall ::wviewer::browser_tree_apply $tok [list open $open sel $sel]
    update
    return [list $seealone [pcall $tv item $anc -open] [bs_open_set $tv] \
                 [pcall $tv selection]]
  }

  # --- BW68: THE ITEM'S HEADLINE --------------------------------------------
  # ⚠ LEG 1 (`none`) IS ITEM 10's S3 LESSON MADE A LEG: the tree really was
  # FULLY COLLAPSED on entry, so legs 3/4 are things the reveal DID rather than
  # things that were already true. Leg 5 is the item. Leg 6 says the expansion
  # is a CHAIN, not a subtree. Legs 7/8 keep "the reveal did nothing at all"
  # excluded, which is what makes leg 5's `0` a claim.
  check {BW68 (TWO-PANE item 13, R1/R3) a reveal from a FULLY COLLAPSED tree
         opens the ANCESTOR CHAIN AND NOTHING ELSE: the target's own node and
         the target's SIBLING stay closed, and it is VISIBLE and SELECTED} \
    [bw_reveal_probe $tok $TV {g:} {g:x1} {g:x1.x2} {g:x1.y3}] \
    [list none 1 1 1 0 0 visible g:x1.x2]

  # --- BW69: BW68's POSITIVE CONTROL ----------------------------------------
  # ⚠ WITHOUT THIS, BW68's leg 5 is green on a widget that cannot report `-open`
  # for a childless row at all. Same node, both values, plus the fact that it
  # HAS no children — so "closed" is a real state and not an artefact.
  check {BW69 (BW68's POSITIVE CONTROL) `-open` is settable and readable on the
         CHILDLESS target, so BW68's `0` leg really discriminates} \
    [bw_open_roundtrip $TV {g:x1.x2}] {0 1 0 {}}

  # --- BW70: R1, on the ids this fixture actually has ------------------------
  # Green BEFORE and AFTER, declared: it is R1's quantifier ("more than one
  # subtree may be expanded at once") plus the guarantee that a reveal is
  # ADDITIVE — it never closes what the user opened. Sabotage (b)'s control.
  check {BW70 (R1, STANDING CONTROL — green before AND after) MORE THAN ONE
         subtree may be expanded at once, and a reveal closes none of them} \
    [bw_multi_open_probe $tok $TV {g: g:x1 g:x1.x2 g:x1.y3} {g:x1.x2}] \
    [list {g: g:x1 g:x1.x2 g:x1.y3} {g: g:x1 g:x1.x2 g:x1.y3}]

  # --- BW71: the empty-id refusal, NOT as a lone stability claim -------------
  # ⚠ DECLARED: the refusal half is green before this item, and its OWNER is
  # BX33 (test_wave_sigbrowser_i12.tcl:607-611). It is carried here only so the
  # deletion above cannot be "verified" against a proc that stopped working —
  # legs 3/4 are the SAME call shape on a REAL id, moving the selection.
  check {BW71 (DECLARED CONTROL, owner BX33) reveal REFUSES the empty id
         (`$tv exists {}` is TRUE) and leaves the selection alone, while the
         SAME call on a real id moves it — the refusal is about the ID} \
    [bw_reveal_pair $tok $TV {g:x1.x2} {g:x1.y3}] {0 g:x1.x2 1 g:x1.y3}

  # --- BW72/BW73: spec §7.3's narrowing --------------------------------------
  # ⚠⚠ TWO SURVIVORS, DELIBERATELY. The PLAN's version of this check hands
  # `{g:zz g:x1.x2}` — one dead id and ONE survivor — and MEASURED it is VACUOUS:
  # today's keep-everything already answers `g:x1.x2` because only one id is
  # left to keep. The claim only has teeth when narrowing and keeping DISAGREE.
  # ⚠ AND THE WIDGET WILL NOT DO THIS FOR THE RESTORE: BW26b above MEASURED
  # that `$tv selection set {a b}` is blind to `-selectmode browse` and really
  # sets two. Its comment has said since item 9 that narrowing is item 13/14's
  # job; this is item 13 paying it.
  check {BW72 (§7.3) a SHIPPED-shape multi-id `sel` with TWO SURVIVING ids
         narrows to the FIRST, so R4 holds through a restore (BW26b is why the
         widget cannot be relied on to do it)} \
    [bw_apply_sel $tok $TV {g:} {g:x1.x2 g:x1.y3}] {1 g:x1.x2}
  check {BW73 (§7.3) ...and it is the first SURVIVING id, not `lindex 0`: a DEAD
         id at the HEAD neither widens the selection nor blanks it} \
    [bw_apply_sel $tok $TV {g:} {g:zz g:x1.x2 g:x1.y3}] {1 g:x1.x2}

  # --- BW74: §7.3's root fallback, and the EMPTY-`sel` ruling ----------------
  # ⚠ THE READING OF §7.3 ADOPTED HERE, STATED SO IT IS NOT RE-DECIDED SILENTLY:
  # the fallback fires only when `sel` was NON-EMPTY and nothing survived. An
  # EMPTY `sel` is not "all dead" — it has no ids that "have gone" — and
  # `browser_state_apply` passes `sel {}` for every legacy and default state, so
  # treating it as all-dead would move the selection on every plain restore. R4
  # is already satisfied by `browser_populate`'s own root selection.
  check {BW74 (§7.3) an ALL-DEAD `sel` falls back to the design ROOT — never to
         empty and never to whatever happened to be selected; leg 1 names what
         it had to move away from and leg 4 that the open pass still ran} \
    [bw_apply_dead $tok $TV {g:x1.y3} {g:zz}] {g:x1.y3 1 g: g:}
  check {BW74 (THE OTHER READING, REFUSED) ...and an EMPTY `sel` is NOT "all
         dead": the selection is left alone WHILE the open pass still runs, so
         this cannot be green on a call that did nothing} \
    [bw_apply_dead $tok $TV {g:x1.y3} {}] {g:x1.y3 1 g:x1.y3 g:}

  # --- BW75: the fallback's NO-ROOT arm --------------------------------------
  # The All-DBs state two-pane item 15 owns emits NO design root, so the row
  # list answers `{}` — and that absence is an ANSWER (browser_root_id's own ⚠).
  # The fallback must then be a NO-OP: not a clear, not a throw.
  # ⚠ SIX LEGS, AND THE RED RUN IS WHY — see the helper's ⚠⚠. Legs 1-3 are the
  # no-op; leg 4 is the asserted restore; legs 5-6 are the SAME call on the
  # RESTORED model, where the fallback fires. Without them "the fallback is a
  # no-op here" and "there is no fallback anywhere" are the same picture, and
  # the four-leg version of this check was MEASURED green before item 13's code
  # existed.
  check {BW75 (BW74's OTHER ARM) with a row list that has NO design root the
         fallback is a NO-OP — not a clear, not a throw — while the SAME call
         on the restored model still lands on the root} \
    [bw_apply_dead_norootrows $tok $TV {g:x1.y3}] {no-root 1 g:x1.y3 g: 1 g:}

  # --- BW76: THE DIVERGENCE'S STANDING GUARD --------------------------------
  # GREEN BEFORE AND AFTER, ON PURPOSE. See the ⚠⚠⚠ block at the top of this
  # band: PLAN item 13 asks for the selection's ancestor chain to be UNIONED
  # into the applied open set, and spec §4.2 forbids it —
  #     "the persisted `open` set must beat it — BP54 already pins that a
  #      persisted collapse beats `see`'s ancestor-expansion, and that check
  #      stays green."
  # Leg 1 is `see` ALONE on the SAME tree (no `open` key -> the open pass is
  # skipped), so "g:x1 was closed anyway" cannot pass for "the open pass won".
  # Cross-file twins: BP53 (i1315:1468) and BP54 (i1315:1495).
  check {BW76 (SPEC §4.2 — AND WHAT THE PLAN'S "UNION" WOULD HAVE BROKEN) the
         persisted OPEN SET still BEATS `see`: the restored selection's own
         ancestor is left COLLAPSED when the persisted set says so} \
    [bw_order_probe $tok $TV {g:x1} {g:x1.x2} {g: g:x1.y3}] \
    [list 1 0 {g: g:x1.y3} g:x1.x2]

  # --- BW77/BW78: THE HEADLINE ON A NODE WHERE IT IS OBSERVABLE -------------
  # ⚠⚠ THIS IS THE HOLE THE ITEM-13 VERIFIER FOUND, AND IT WAS A REAL ONE.
  # `BW68` and `BX31` both reveal `g:x1.x2` — and `BW69` itself asserts that node
  # is CHILDLESS. On a childless row `-open 0` is a state the widget stores and
  # reports but NEVER RENDERS: the user sees no expander either way. So the whole
  # live witness for "the reveal expands the CHAIN and stops" sat on the one node
  # class where the claim changes NOTHING the user can see, and a strictly
  # ADDITIVE re-add of the pre-item-13 open — guarded on `[llength [$tv children
  # $id]] > 0`, and written `-open true` so BW15's literal regexp cannot match it
  # — passed ALL FOUR suites in BOTH arms.
  #
  # `g:x1` is in this same shipped fixture and HAS children, so no new fixture is
  # needed. MEASURED RED-FIRST under exactly that additive re-add: leg 5 reads
  # `1`, which is also what it read before item 13.
  #
  # ⚠ LEG 6 IS A DESCENDANT HERE, NOT A SIBLING. `g:x1` has no same-level
  # sibling in this fixture, so the 6th slot is spent on `g:x1.x2` instead: it
  # says the reveal did not open the target's SUBTREE either, which is S2's
  # claim restated on the observable node. Legs 3/4 (the root and the chain, both
  # `1`) still exclude "the reveal did nothing"; leg 1's `none` still proves the
  # tree really was fully collapsed on entry.
  check {BW77 (TWO-PANE item 13, R3 — THE HEADLINE ON AN OBSERVABLE NODE) a
         reveal onto a node that HAS CHILDREN opens the chain ABOVE it and
         leaves the node ITSELF closed: the lower pane, not the expander, is
         what answers "what is inside this"} \
    [bw_reveal_probe $tok $TV {g:} {g:} {g:x1} {g:x1.x2}] \
    [list none 1 1 1 0 0 visible g:x1]

  # ⚠ BW77's POSITIVE CONTROL, and it is the leg BW69 could not carry: it pins
  # that this target HAS CHILDREN, so BW77's `0` is a state the user can SEE
  # (a collapsed expander) rather than an unrendered widget attribute.
  check {BW78 (BW77's POSITIVE CONTROL) the BW77 target really HAS CHILDREN and
         `-open` round-trips on it, so BW77's closed leg is a VISIBLE claim} \
    [bw_open_roundtrip $TV {g:x1}] [list 0 1 0 [list {g:x1.x2} {g:x1.y3}]]

  catch {destroy .wvbw1}
  catch {dict unset ::wviewer::windows wvbw}
  catch {unset ::wviewer::browsersigs(wvbw)}
  catch {unset ::wviewer::browserrows(wvbw)}
} else {
  puts "SKIPPED: BW2x/BW3x group (Tk/X arm only)"
}

# ============================================================================
# BV — "DESCEND TO HERE" ON A DEVICE NODE (issue 1724)
#
# A terminal current `i(x1.xm9.d)` files under the path `x1.xm9`, so the
# browser's tree has a node for the transistor, and "Descend to here" on it
# used to fail: `no instance 'xm9'` for a FET the sheet calls `M9` (its
# `spiceprefix` makes the deck's `XM9`), or `descend refused` with the design
# window rolled back to where it was. A device is a place on its PARENT's
# sheet. The command now goes there and selects it.
#
# WHAT THE BAND CLAIMS
#   BV02  wviewer::hier_device finds, for every element the fixture's instances
#         write into the deck, the instance that wrote it, or nothing -- NEVER
#         another instance. The comparand is the Select-On-Design pick's own
#         expansion of each instance's format (bv_elems), a different mechanism
#         from the one under test (`ase::inst_path_segment`).
#   BV05-BV08  the walk with `leaf` on stays on the parent sheet with the device
#         selected; two instances that could be the segment select NONE; the
#         deck's name beats the instance's own.
#   BV04, BV09  what did NOT change: the default walk, a real block, a name
#         nothing answers to.
#   BV13, BV14  the answer's read-backs: the selection that did not take, the
#         sheet the walk is not standing on, the index a row is selected by.
#   BV15  a descend refused for any reason other than not-a-block is not a
#         device, and neither is a device in the middle of a path.
#   BV20-BV27  the same through wviewer::browser_descend_to and the real menu
#         entry, read back on the design window BY NAME.
#
# DECLARED MISSES, asserted as misses (BV02's `none` leg, BV09): a format that
# writes a literal letter in front of `@name`, and the second element of a
# two-line format. Such a node still says `no instance`.
#
# THE FIXTURE IS WRITTEN INTO THE SCRATCH DIRECTORY, never a repo sheet, and
# BV12 asserts the band left it unmodified.
# ============================================================================
proc bv_w {path text} { set fp [open $path w] ; puts -nonewline $fp $text ; close $fp }
proc bv_home {} {
  for {set k 0} {$k < 20} {incr k} {
    set c 0
    catch {set c [xschem get currsch]}
    if {![string is integer -strict $c] || $c <= 0} { break }
    catch {xschem go_back}
  }
  catch {xschem unselect_all}
}
# the selected instances as a plain list of names; `ERR` when it cannot be read
proc bv_sel {} {
  if {[catch {xschem selected_set} s]} { return ERR }
  if {[catch {lrange $s 0 end} l]} { return ERR }
  return $l
}
proc bv_at {} {
  return [list [pcall xschem get sim_sch_path] [pcall xschem get currsch] [bv_sel]]
}
# THE COMPARAND: the element name(s) instance `i` writes into the deck -- the
# first word of each element line its own format expands to, by the chain the
# Select-On-Design pick names a terminal with (src/ase_window.tcl). `ERR:...`
# as a value when a step raises, so a broken comparand reddens a row by name.
proc bv_elems {i} {
  if {[catch {
    set out {}
    set fmt [lindex [ase::ui::sod_term_format $i] 0]
    if {[string trim $fmt] ne {}} {
      set pins [ase::ui::sod_term_pins $i]
      set marked [ase::ui::sod_term_rewrite $pins [ase::ui::sod_term_pieces $fmt]]
      foreach l [ase::ui::sod_term_lines $i $marked] { lappend out [lindex $l 0] }
    }
  } err]} { return [list "ERR:$err"] }
  return $out
}

set bv_lib [file join $scratch bvlib]
file mkdir $bv_lib
set bv_symh "v {xschem version=3.4.8RC file_version=1.3}\nG {}"
set bv_symt "V {}\nS {}\nF {}\nE {}\nL 4 -40 -20 40 -20 {}\nL 4 -40 20 40 20 {}"
set bv_schh "v {xschem version=3.4.8RC file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nF {}\nE {}"
set bv_pins "B 5 17.5 -32.5 22.5 -27.5 {name=D dir=inout}\nB 5 -22.5 -2.5 -17.5 2.5 {name=G dir=in}\nB 5 17.5 27.5 22.5 32.5 {name=S dir=inout}\nB 5 17.5 -2.5 22.5 2.5 {name=B dir=in}\n"
# a format that writes a LITERAL prefix, and one that writes TWO elements
bv_w [file join $bv_lib bv_lit.sym] "$bv_symh\nK {type=nmos\nformat=\"X@name @pinlist nf W=1\"\ntemplate=\"name=M1\"}\n$bv_symt\n$bv_pins"
bv_w [file join $bv_lib bv_two.sym] "$bv_symh\nK {type=nmos\nformat=\"@name @pinlist nm W=1u L=1u\nR@name @@D @@S 1k\"\ntemplate=\"name=M1\"}\n$bv_symt\n$bv_pins"
bv_w [file join $bv_lib bv_blk.sym] "$bv_symh\nK {type=subcircuit\nformat=\"@name @pinlist @symname\"\ntemplate=\"name=x1\"}\n$bv_symt\nB 5 -42.5 -12.5 -37.5 -7.5 {name=in_p dir=inout}\nB 5 -42.5 7.5 -37.5 12.5 {name=in_n dir=inout}\nB 5 37.5 -2.5 42.5 2.5 {name=out dir=inout}\n"
bv_w [file join $bv_lib bv_blk.sch] "$bv_schh
C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=in_p}
C {devices/ipin.sym} 0 200 0 0 {name=p2 lab=in_n}
C {devices/opin.sym} 300 100 0 0 {name=p3 lab=out}
C {devices/res.sym} 100 50 0 0 {name=R1 value=10k}
C {devices/nmos4.sym} 200 150 0 0 {name=M1 model=nm}
C {devices/nmos4.sym} 400 150 0 0 {name=M2 model=nm spiceprefix=X}
"
# TOP, in this instance order: a source, a resistor, a prefixed FET (`M9`, the
# deck's XM9), the two declared misses, two FETs that netlist under ONE name in
# two cases (`M5`, `m5`), an instance CALLED `XM4` that netlists as XXM4 beside
# the `M4` that netlists as XM4, a block, a label.
bv_w [file join $bv_lib bv_top.sch] "$bv_schh
C {devices/vsource.sym} 0 0 0 0 {name=V1 value=1}
C {devices/res.sym} 200 0 0 0 {name=RT value=1k}
C {devices/nmos4.sym} 400 0 0 0 {name=M9 model=nm spiceprefix=X}
C {bv_lit.sym} 600 0 0 0 {name=M7}
C {bv_two.sym} 800 0 0 0 {name=M3}
C {devices/nmos4.sym} 1000 0 0 0 {name=M5 model=nm spiceprefix=X}
C {devices/nmos4.sym} 1200 0 0 0 {name=m5 model=nm spiceprefix=X}
C {devices/nmos4.sym} 1400 0 0 0 {name=XM4 model=nm spiceprefix=X}
C {devices/nmos4.sym} 1600 0 0 0 {name=M4 model=nm spiceprefix=X}
C {bv_blk.sym} 700 300 0 0 {name=xa}
C {devices/lab_pin.sym} 0 -100 0 0 {name=l1 sig_type=std_logic lab=g}
"
set bv_path0 {} ; set bv_pfx0 1
catch {set bv_path0 $XSCHEM_LIBRARY_PATH}
catch {set bv_pfx0 $::spiceprefix}
# UNQUALIFIED on purpose: the write trace that rebuilds the search path compares
# the variable's name as it was written (test_wave_sigbrowser_0319.tcl's note).
set XSCHEM_LIBRARY_PATH "$bv_lib:[file join $repo xschem_library]"
set ::spiceprefix 1
set bv_top [file join $bv_lib bv_top.sch]
set bv_load [pcall xschem load $bv_top]
set bv_dwin0 [pcall xschem get current_win_path]
check {BV01 (FIXTURE) the scratch design loads at its top, its symbols resolve (a FET is an nmos, the block a subcircuit) and the spiceprefix switch is on} \
  [list [expr {![string match ERR:* $bv_load]}] [pcall xschem get sim_sch_path] \
        [pcall xschem get currsch] [pcall xschem getprop instance M9 cell::type] \
        [pcall xschem getprop instance xa cell::type] $::spiceprefix] \
  [list 1 {} 0 nmos subcircuit 1]

# --- BV02: the scan against the pick's expansion, element by element --------
set bv_all {} ; set bv_own {} ; set bv_none {} ; set bv_several {} ; set bv_wrong {}
set bv_n [pcall xschem get instances]
if {![string is integer -strict $bv_n]} { set bv_n 0 }
for {set bv_i 0} {$bv_i < $bv_n} {incr bv_i} {
  foreach bv_e [bv_elems $bv_i] {
    lappend bv_all $bv_e
    set bv_seg [string tolower $bv_e]
    set bv_idx {}
    foreach bv_r [pcall ::wviewer::hier_device $bv_seg] { lappend bv_idx [lindex $bv_r 0] }
    if {![llength $bv_idx]} {
      lappend bv_none $bv_seg
    } elseif {$bv_idx eq [list $bv_i]} {
      lappend bv_own $bv_seg
    } elseif {[llength $bv_idx] > 1 && [lsearch -exact $bv_idx $bv_i] >= 0} {
      lappend bv_several $bv_seg
    } else {
      lappend bv_wrong "$bv_seg->$bv_idx"
    }
  }
}
check {BV02 (THE COMPARAND IS REAL) the pick's expansion names every element the fixture writes, in instance order -- not a list of error sentinels} \
  $bv_all {V1 RT XM9 XM7 M3 RM3 XM5 Xm5 XXM4 XM4 xa}
check {BV02 (NEVER THE WRONG INSTANCE) for every element of the deck, lower-cased as a raw spells it, hier_device answers the instance that wrote it, or nothing, or several including it -- and never another one} \
  [list $bv_wrong $bv_own $bv_none $bv_several] \
  [list {} {v1 rt xm9 m3 xxm4 xm4 xa} {xm7 rm3} {xm5 xm5}]

check {BV03 hier_resolve finds the ONE instance that netlists under a name no instance is called (xm9 is M9), still finds a name in another case, and answers NOTHING for two candidates or for a declared miss} \
  [list [pcall ::wviewer::hier_resolve xm9] [pcall ::wviewer::hier_resolve rt] \
        [pcall ::wviewer::hier_resolve xm5] [pcall ::wviewer::hier_resolve xm7] \
        [pcall ::wviewer::hier_resolve {xa[3]}]] \
  [list M9 RT {} {} VECTOR]

# --- BV04: what did not change ----------------------------------------------
bv_home
check {BV04 (THE DEFAULT WALK IS WHAT IT WAS) without leaf a device is a refused descend and a missing name is no instance, each an err that leaves the walk at the top} \
  [list [pcall ::wviewer::hier_walk rt] [pcall xschem get sim_sch_path] \
        [pcall ::wviewer::hier_walk zz9] [pcall xschem get sim_sch_path]] \
  [list {err {descend refused at 'RT'} {}} {} {err {no instance 'zz9'} {}} {}]
bv_home
pcall ::wviewer::hier_walk xa
check {BV04 (STILL A ROLLBACK, AFTER REAL MOVEMENT) with leaf ON a last segment nothing answers to errs and returns to the sheet it started from: up out of xa, a miss at the top, back into xa} \
  [list [pcall xschem get sim_sch_path] [pcall ::wviewer::hier_walk zz9 1 1] \
        [pcall xschem get sim_sch_path] [pcall xschem get currsch]] \
  [list {xa.} {err {no instance 'zz9'} xa} {xa.} 1]

# --- BV05: the device arm, FROM ANOTHER SHEET -------------------------------
# The start is inside `xa`, so "stays on the parent" is an ASCEND that happens
# and is kept -- from the top it would be indistinguishable from not moving.
bv_home
pcall ::wviewer::hier_walk xa
check {BV05 (THE DEVICE ARM) from inside the block, the walk to a top-level transistor ascends, STAYS at the top and leaves the transistor selected: xm9 is M9} \
  [list [pcall ::wviewer::hier_walk xm9 1 1] [bv_at]] \
  [list {device {} M9 1} [list {} 0 M9]]

bv_home
check {BV06 (A DEVICE INSIDE A BLOCK) the walk descends into the block and stays there with the device selected, by its own name and by the name its spiceprefix gives it} \
  [list [pcall ::wviewer::hier_walk xa.m1 1 1] [bv_at] \
        [pcall ::wviewer::hier_walk xa.xm2 1 1] [bv_at]] \
  [list {device xa M1 1} [list {xa.} 1 M1] {device xa M2 1} [list {xa.} 1 M2]]

# --- BV07: two instances could be it -> NONE is selected --------------------
bv_home
pcall xschem select instance RT
set bv_presel [bv_sel]
check {BV07 (TWO CANDIDATES) a segment two instances netlist under selects NEITHER, names both, and clears the selection that was there, so none-selected is true of the sheet} \
  [list $bv_presel [pcall ::wviewer::hier_walk xm5 1 1] [bv_at]] \
  [list RT {device {} {M5 m5} 0} [list {} 0 {}]]

# --- BV08: the DECK's name beats the instance's own -------------------------
bv_home
set bv_r4 [pcall ::wviewer::hier_walk xm4 1 1]
set bv_a4 [bv_at]
bv_home
check {BV08 (DECK NAME FIRST) xm4 is the M4 that netlists as XM4, not the instance merely CALLED XM4, which is the raw's xxm4} \
  [list $bv_r4 $bv_a4 [pcall ::wviewer::hier_walk xxm4 1 1] [bv_at]] \
  [list {device {} M4 1} [list {} 0 M4] {device {} XM4 1} [list {} 0 XM4]]

# --- BV09: a real block, and the declared misses ----------------------------
bv_home
set bv_rb [pcall ::wviewer::hier_walk xa 1 1]
set bv_ab [bv_at]
bv_home
check {BV09 with leaf on a REAL block is still entered, and a declared miss (a literal prefix in the format, a second element line) is still no instance with the walk back at the top} \
  [list $bv_rb $bv_ab [pcall ::wviewer::hier_walk xm7 1 1] \
        [pcall ::wviewer::hier_walk rm3 1 1] [bv_at]] \
  [list {ok xa} [list {xa.} 1 {}] {err {no instance 'xm7'} {}} \
        {err {no instance 'rm3'} {}} [list {} 0 {}]]

# --- BV10: the sentences, PURE ----------------------------------------------
set bv_m1 [pcall ::wviewer::hier_device_msg xm9 {} M9 1]
set bv_m2 [pcall ::wviewer::hier_device_msg m1 xa M1 1]
set bv_m3 [pcall ::wviewer::hier_device_msg xm5 {} {M5 m5} 0]
set bv_m4 [pcall ::wviewer::hier_device_msg xm9 {} M9 0]
check {BV10 the three sentences: a device selected on its sheet, several candidates with none selected, a device that could not be selected} \
  [list $bv_m1 $bv_m2 $bv_m3 $bv_m4] \
  [list "'xm9' is a device with no sheet of its own; selected M9 at the top level" \
        "'m1' is a device with no sheet of its own; selected M1 at xa" \
        "'xm5' could be any of 2 instances at the top level (M5, m5); none is selected" \
        "'xm9' is a device with no sheet of its own; it is M9 at the top level, which could not be selected"]
set bv_bad 0
foreach bv_m [list $bv_m1 $bv_m2 $bv_m3 $bv_m4] {
  if {[string match {*no instance*} $bv_m] || [string match {*failed*} $bv_m] || [string match ERR:* $bv_m]} { incr bv_bad }
}
check {BV10 ...and none of them says no instance or failed} $bv_bad 0

# --- BV11: which refusals are "no sheet" ------------------------------------
bv_home
pcall xschem descend -inst RT
set bv_ns1 [pcall ::wviewer::hier_no_sheet]
set bv_why1 [pcall xschem get descend_error]
bv_home
pcall xschem descend -inst xa
set bv_ns2 [pcall ::wviewer::hier_no_sheet]
bv_home
check {BV11 hier_no_sheet is 1 after a descend refused because the instance is not a block, with the engine's own token to show for it, and 0 after a descend that entered one} \
  [list $bv_ns1 [string match {not-descendable*} $bv_why1] $bv_ns2] [list 1 1 0]

# --- BV13: the selection is READ BACK, never assumed ------------------------
# The select verb is made a no-op for ONE walk (the `xschem` command wrapped,
# then put back -- the last leg says it is back). The refused descend has
# selected M9 by then; hier_stay clears that, asks for the selection, and has to
# notice it did not take.
bv_home
rename ::xschem ::bv_real_xschem
proc ::xschem {args} {
  if {[lindex $args 0] eq {select}} { return 0 }
  return [uplevel 1 [linsert $args 0 ::bv_real_xschem]]
}
set bv_r13 [pcall ::wviewer::hier_walk xm9 1 1]
rename ::xschem {}
rename ::bv_real_xschem ::xschem
set bv_a13 [bv_at]
bv_home
check {BV13 (THE SELECTION IS READ BACK) with the select verb a no-op for one walk the answer says the device was NOT selected, and nothing is; with the verb back the same walk selects it} \
  [list $bv_r13 $bv_a13 [pcall ::wviewer::hier_walk xm9 1 1] [bv_at] \
        [expr {[info commands ::bv_real_xschem] eq {}}]] \
  [list {device {} M9 0} [list {} 0 {}] {device {} M9 1} [list {} 0 M9] 1]

# --- BV14: hier_stay's own two read-backs, driven directly ------------------
# Leg 1: a target whose parent sheet (`xa`) the design is NOT standing on --
# nothing is answered and the selection that was there is untouched. Leg 2: at
# the top, the one row is selected. Leg 3: the row is selected BY INDEX: its
# name is the all-digit `1`, which the engine would read as instance number 1
# (the resistor), while its index 2 is the transistor -- so the transistor is
# what gets selected, and the read-back, which compares NAMES, says 0.
bv_home
pcall xschem select instance RT
set bv_r14 [pcall ::wviewer::hier_stay {xa m1} [list [list 0 V1 exact exact]]]
set bv_a14 [bv_at]
set bv_r14b [pcall ::wviewer::hier_stay {v1} [list [list 0 V1 {} nocase]]]
set bv_a14b [bv_at]
check {BV14 (THE POSITION IS READ BACK, AND THE INDEX IS WHAT IS SELECTED) off the parent sheet hier_stay answers nothing and touches nothing; on it, it selects the one row; and a row whose name is all digits is selected by its index, not by that name} \
  [list $bv_r14 $bv_a14 $bv_r14b $bv_a14b \
        [pcall ::wviewer::hier_stay {zz} [list [list 2 1 {} nocase]]] [bv_at] \
        [pcall xschem getprop instance 1 name] [pcall xschem getprop instance 2 name]] \
  [list {} [list {} 0 RT] {device {} V1 1} [list {} 0 V1] \
        {device {} 1 0} [list {} 0 M9] RT M9]
bv_home

# --- BV15: ONLY an instance that is not a block makes a device --------------
# Two refusals that must stay errors with leaf on. The first is a descend the
# engine declines for a reason that says nothing about the instance: its
# dispatcher gate is raised for the one walk (`xschem set semaphore`, put back
# and asserted back), so the verb answers 0 with the token `busy`. The second
# is a device in the MIDDLE of a path, which is not where a walk can end.
set bv_sem0 [pcall xschem get semaphore]
pcall xschem set semaphore 1
set bv_r15 [pcall ::wviewer::hier_walk rt 1 1]
set bv_why15 [pcall xschem get descend_error]
pcall xschem set semaphore $bv_sem0
bv_home
check {BV15 (ONLY A NON-BLOCK IS A DEVICE) a last-segment descend refused because the engine is busy is an err and not a device, and so is a device in the middle of a path} \
  [list $bv_sem0 $bv_why15 $bv_r15 [pcall xschem get semaphore] \
        [pcall ::wviewer::hier_walk rt.foo 1 1] [pcall xschem get sim_sch_path]] \
  [list 0 busy {err {descend refused at 'RT'} {}} 0 \
        {err {descend refused at 'RT'} {}} {}]
bv_home

# --- BV12: hygiene ----------------------------------------------------------
check {BV12 the walks and the scans changed nothing: the design is unmodified at its top with nothing selected, and no backup sits beside the fixture} \
  [list [bv_at] [pcall xschem get modified] [glob -nocomplain -directory $bv_lib *~*]] \
  [list [list {} 0 {}] 0 {}]

# --- BV20-BV27: THE COMMAND, a real viewer AND a real design window ---------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set bv_defs [file join $scratch bv_library.defs]
  bv_w $bv_defs "DEFINE bvlib $bv_lib\n"
  set bv_had_defs [info exists XSCHEM_LIBRARY_DEFS]
  set bv_defs0 {}
  if {$bv_had_defs} { set bv_defs0 $XSCHEM_LIBRARY_DEFS }
  set XSCHEM_LIBRARY_DEFS $bv_defs
  set bv_state [file join $scratch bv_top.state]
  pcall ase::state_save $bv_state [dict merge [ase::state_default] \
    [dict create design [dict create lib bvlib cell bv_top view schematic]]]
  set bv_tok [ase::session_key bvlib bv_top schematic]
  pcall ase::session_open $bv_tok $bv_state
  set bv_open [pcall ::wviewer::open $bv_tok]
  set bv_vtop [pcall ::wviewer::window_for $bv_tok]
  if {$bv_open ne 1 || $bv_vtop eq {} || [string match ERR:* $bv_vtop] || ![viewer_ready $bv_vtop]} {
    puts "SKIPPED: BV2x group (the bv_top viewer never opened/mapped)"
    catch {wviewer::close $bv_tok}
  } else {
    # the verified context switch of test_wave_sigbrowser_i11.tcl (bh_ctx_to):
    # synchronous on the fast path, a bounded retry for the bounce an `update`
    # can cause by delivering an Enter on the other canvas
    proc bv_ctx_to {w} {
      if {[xschem get current_win_path] eq $w} { return 1 }
      catch {xschem new_schematic switch $w}
      if {[xschem get current_win_path] eq $w} { return 1 }
      for {set i 0} {$i < 10} {incr i} {
        update
        catch {xschem new_schematic switch $w}
        if {[xschem get current_win_path] eq $w} { return 1 }
        after 20
      }
      return 0
    }
    # where the DESIGN window is, read on it by name: {switched sim currsch sel}
    proc bv_design {w} {
      set ok [bv_ctx_to $w]
      return [linsert [bv_at] 0 $ok]
    }
    proc bv_status {vtop} {
      return [pcall $vtop.wvbrowser.ph cget -text]
    }

    # a raw in the VIEWER's own context, with a terminal current under each
    # kind of node the band walks to
    xschem new_schematic switch $bv_vtop.drw
    pcall xschem raw new bv_e2e.raw dc vsweep 0 1.0 0.5
    foreach bv_nm {v(g) i(xm9.d) i(rt.n1) i(xa.m1.d) i(xa.in_p) i(xm5.d) i(zz9.d)} {
      pcall xschem raw add $bv_nm {vsweep 1 +}
    }
    xschem new_schematic switch $bv_dwin0
    pcall ::wviewer::browser_toggle 1 $bv_tok
    update
    set BVTV $bv_vtop.wvbrowser.pw.tvf.tv
    check {BV20 (FIXTURE) the browser populated from the real raw: every device is a tree node, and the transistor's node resolves to the path xm9} \
      [list [pcall $BVTV exists {g:xm9}] [pcall $BVTV exists {g:rt}] \
            [pcall $BVTV exists {g:xa.m1}] [pcall $BVTV exists {g:xm5}] \
            [pcall ::wviewer::browser_target_path $bv_tok {g:xm9}]] \
      [list 1 1 1 1 {ok xm9}]

    # THE ROW. The design window is walked INTO the block first, so the parent
    # of `xm9` (the top) is somewhere the command has to go and stay.
    bv_ctx_to $bv_dwin0
    bv_home
    pcall ::wviewer::hier_walk xa
    set bv_pre [bv_design $bv_dwin0]
    set bv_m [pcall ::wviewer::browser_menu_build $bv_tok {g:xm9}]
    set bv_inv [pcall $bv_m invoke 7]
    update
    set bv_st [bv_status $bv_vtop]
    check {BV21 (THE ROW) the REAL menu entry on a transistor's node, with the design window inside another block: it answers 1, the design window is at the top, the parent of xm9, and M9 is selected there} \
      [list $bv_pre [pcall $bv_m entrycget 7 -label] $bv_inv [bv_design $bv_dwin0]] \
      [list [list 1 {xa.} 1 {}] {Descend to here} 1 [list 1 {} 0 M9]]
    check {BV21 ...and the status line says what it is and what was selected, with no instance and failed nowhere in it} \
      [list $bv_st [string match {*no instance*} $bv_st] [string match {*failed*} $bv_st]] \
      [list "Signal Browser\n'xm9' is a device with no sheet of its own; selected M9 at the top level" 0 0]

    bv_ctx_to $bv_dwin0
    bv_home
    set bv_r2 [pcall ::wviewer::browser_descend_to $bv_tok {g:xa.m1}]
    update
    check {BV22 a device INSIDE a block: the design window descends into the block and stays there with the device selected} \
      [list $bv_r2 [bv_design $bv_dwin0] [bv_status $bv_vtop]] \
      [list 1 [list 1 {xa.} 1 M1] \
            "Signal Browser\n'm1' is a device with no sheet of its own; selected M1 at xa"]

    bv_ctx_to $bv_dwin0
    bv_home
    set bv_r3 [pcall ::wviewer::browser_descend_to $bv_tok {g:xm5}]
    update
    check {BV23 two instances could be the node: the command answers 0, selects neither and names both} \
      [list $bv_r3 [bv_design $bv_dwin0] [bv_status $bv_vtop]] \
      [list 0 [list 1 {} 0 {}] \
            "Signal Browser\n'xm5' could be any of 2 instances at the top level (M5, m5); none is selected"]

    bv_ctx_to $bv_dwin0
    bv_home
    set bv_r4 [pcall ::wviewer::browser_descend_to $bv_tok {g:xa}]
    update
    check {BV24 (CONTROL) a real block's node still descends and says so} \
      [list $bv_r4 [bv_design $bv_dwin0] [bv_status $bv_vtop]] \
      [list 1 [list 1 {xa.} 1 {}] "Signal Browser\ndescended to xa"]

    # still inside xa: a node nothing on the top sheet answers to
    set bv_r5 [pcall ::wviewer::browser_descend_to $bv_tok {g:zz9}]
    update
    check {BV25 (CONTROL) a node nothing answers to is still a failure that says no instance and returns the design window to the block it was in} \
      [list $bv_r5 [bv_design $bv_dwin0] [bv_status $bv_vtop]] \
      [list 0 [list 1 {xa.} 1 {}] \
            "Signal Browser\ndescend to 'zz9' failed: no instance 'zz9' (returned to xa)"]

    # THE LOWER PANE'S ROUTE: the cell of the terminal current itself
    bv_ctx_to $bv_dwin0
    bv_home
    pcall ::wviewer::hier_walk xa
    pcall $BVTV selection set [list {g:rt}]
    update
    set bv_cell [pcall ::wviewer::browser_sea_names $bv_tok]
    set bv_r6 [pcall ::wviewer::browser_sea_descend_to $bv_tok {0}]
    update
    check {BV26 the lower pane's own Descend on the cell of a terminal current goes the same way: the resistor is selected on its sheet} \
      [list $bv_cell $bv_r6 [bv_design $bv_dwin0]] \
      [list {i(rt.n1)} 1 [list 1 {} 0 RT]]

    bv_ctx_to $bv_dwin0
    bv_home
    check {BV27 (HYGIENE) the design is unmodified at its top, and closing the viewer returns 1} \
      [list [bv_design $bv_dwin0] [pcall xschem get modified] [pcall ::wviewer::close $bv_tok]] \
      [list [list 1 {} 0 {}] 0 1]
  }
  if {$bv_had_defs} { set XSCHEM_LIBRARY_DEFS $bv_defs0 } else { catch {unset XSCHEM_LIBRARY_DEFS} }
} else {
  puts "SKIPPED: BV2x group (Tk/X arm only)"
}
bv_home
set XSCHEM_LIBRARY_PATH $bv_path0
set ::spiceprefix $bv_pfx0

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

wvbs_finish
