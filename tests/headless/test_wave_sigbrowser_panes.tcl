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
  # INERT. Item 12 wires them; wiring them now reds this and steals item 12's
  # own attribution.
  check {BW25 ...and they are INERT for now (item 12 wires them)} \
    [list [pcall $F.opt.dev cget -command] [pcall $F.opt.src cget -command]] {{} {}}

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
  set bw_typed [bs_type $F.wvsearch {v(x1.x2*}]
  update
  # ⚠ THE ANTI-VACUITY GUARD FOR THE CHECK BELOW, and it is load-bearing: the
  # status line is the ONE surface the bars are still allowed to move in this
  # item, so it is the only proof available here that the search RAN at all.
  check {BW46 (R5, PRECONDITION) the tree really was expanded, the keystrokes
         really reached the bar, and the search really RAN — the status line
         moved off its unfiltered count} \
    [list $bw_typed $bw_open0 [llength $bw_ids0] \
          [string match {*3 of 3 signals*} $bw_stat0] \
          [string match {*1 of 3 signals*} [pcall $F.ph cget -text]]] \
    [list {v(x1.x2*} {g: g:x1} 4 1 1]
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

  catch {destroy .wvbw1}
  catch {dict unset ::wviewer::windows wvbw}
  catch {unset ::wviewer::browsersigs(wvbw)}
  catch {unset ::wviewer::browserrows(wvbw)}
} else {
  puts "SKIPPED: BW2x/BW3x group (Tk/X arm only)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

wvbs_finish
