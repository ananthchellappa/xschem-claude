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
  check {BW23 (R3) the sea has a HORIZONTAL scrollbar and NO vertical one} \
    [list [lsort [pcall winfo children $F.pw.sea]] [pcall $F.pw.sea.hsb cget -orient] \
          [pcall $F.pw.sea.c cget -yscrollcommand] \
          [bs_set [pcall $F.pw.sea.c cget -xscrollcommand]]] \
    [list [lsort [list $F.pw.sea.c $F.pw.sea.hsb]] horizontal {} 1]

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

  # --- BW34: "NO BEHAVIOUR CHANGES" MADE ASSERTABLE -------------------------
  # The tree is still populated exactly as it was. Without this the item could
  # ship a beautiful skeleton with a tree nothing fills any more.
  set ::wviewer::browsersigs($tok) {v(out) v(x1.x2.net5) v(x1.y3.net5)}
  pcall ::wviewer::browser_refresh $tok 0
  update
  set bw_ids [pcall $TV children {}]
  check {BW34 (NO BEHAVIOUR CHANGE) the tree is still populated exactly as before} \
    [list [expr {[bs_set $bw_ids] && [llength $bw_ids] > 0}] \
          [pcall $TV exists {s:v(out)}] [pcall $TV exists {g:x1}]] {1 1 1}
  check {BW35 ...and the sea is still EMPTY — item 11 fills it, not item 9} \
    [llength [pcall $F.pw.sea.c find all]] 0

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
