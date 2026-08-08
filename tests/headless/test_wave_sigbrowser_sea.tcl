# tests/headless/test_wave_sigbrowser_sea.tcl — TWO-PANE Signal Browser,
# PLAN item 11: THE LOWER PANE GOES LIVE.
# doc/claude/specs/waveform_signal_browser_two_pane.md (R3, R4, R5, R6, R8, §5,
# §7.1, §7.2, §7.5, §7.6)
# doc/claude/signal_browser_2pane_batch/PLAN.md item 11 (BQ50-BQ64).
#
# ============================================================================
# WHAT THIS FILE IS ABOUT
# ============================================================================
# The upper pane (item 10) is the navigation surface: instances only, collapsed
# by default, one selection. This file is about the OTHER half — the "sea of
# names", a canvas that flows the signals owned by the selected instance's OWN
# LEVEL, column-major, scrolling sideways only.
#
# Three things about it are easy to get subtly wrong and are therefore each
# pinned from more than one side:
#
#  1. THE TWO PANES TAKE DIFFERENT SETS. Spec §7.1: the tree comes from the
#     BAR-UNFILTERED inventory, the sea is the half the bars narrow. A build
#     that fed both the same set would look right in every screenshot and would
#     re-introduce the flicker R5 exists to remove. BQ65 is the pair of values.
#  2. OWN LEVEL, NOT RECURSIVE. `browser_level_names` against
#     `browser_leaf_names`. MEASURED on tb_bandgap's x1: 43 against 172 under
#     the shipped class filter. BQ51's DESCENDED leg is what sees a swap — its
#     root leg stays right either way, which is why the check names x1.
#  3. THE LABEL IS A DISPLAY. R8 renders `i(x1.x2.net5)` as `net5:i`, and no raw
#     name contains `net5:i`. Every gesture must resolve through the INDEX into
#     the full raw name; BQ56 and BQ58 are the two ends of that.
#  4. ITEM 20 MAKES THE LABEL THE BARS' SUBJECT TOO, and that does NOT weaken
#     (3): a filter selects WHAT TO SHOW and resolves nothing. BQ70-BQ74 are the
#     driver's own case, and BQ73 is (3) restated from the bar's side — the
#     matcher matches the label and RETURNS THE RAW NAME.
#
# ============================================================================
# CONVENTIONS (inherited — test_wave_sigbrowser.tcl:38-49, ruling 30)
# ============================================================================
# GROUP PREFIX: the sea of names is `BQ`, never reused. Numbers are BLOCKED by
# arm: 01-19 source/pure (BOTH arms), 50-69 the throwaway toplevel (X only),
# 70-79 ITEM 20's live-bar block, also X only. PLAN reserves BQ01-BQ13 for items
# 6/7's pure model, which shipped inside test_wave_sigbrowser_2pane.tcl's TP
# band instead (the as-built convention); nothing here renumbers into them.
#
# ⚠ EXPECTED LITERALS ARE STRING REPS, NEVER NESTED LISTS. `check` compares
# STRINGS, and `[list {g:} 0]` has the string rep `g: 0`, not `{g:} 0`. Five
# checks were red on CORRECT code in item 10 for exactly this.
#
# ⚠ `pcall` ANSWERS THE STRING `ERR:<msg>`. `expr` on it THROWS past the check
# into the outer catch and deletes every remaining check; `lsearch` on it does
# NOT throw — it answers -1, so `< 0` goes GREEN on a failed read. Use
# `bs_num`/`bs_set`, or assertable sentinels.
#
# ⚠ THE CHECK COUNT IS THE ONLY WITNESS TO VACUITY. Item 10's change silently
# stopped 43 checks running and the file reported a plausible 276 instead of
# 319 with zero failures. Diff the COUNT on every run.
#
# ============================================================================
# THE CORPUS, AND TWO NUMBERS THE PLAN GOT WRONG
# ============================================================================
# tests/headless/fixtures/tb_bandgap_vars.txt (424 names) is fed into a LIVE
# browser through `browsersigs($token)` — the same hand-seed route
# test_wave_sigbrowser_panes.tcl:434 and test_wave_sigbrowser.tcl:1337 use,
# because no committed raw exists (the real ones are 69 MB and 621 MB).
#
# Re-MEASURED against the shipped pipeline rather than copied from the PLAN:
#   own level at the design root      18   (PLAN said 18 — reproduces)
#   own level at x1                   43   (PLAN said 43 — reproduces)
#   RECURSIVE under x1               172   ⚠ PLAN SAYS 406. 406 is the
#                                         PRE-class-filter figure; browser_rows
#                                         is built from browser_class_filter's
#                                         output (0 1), so the row model holds
#                                         190 leaves, not 424, and R6's
#                                         recursive plot answers 172.
#   tree rows                         45   = 44 kept instance nodes + the design
#                                         root (spec §3.3's 44 counts instances)
#   nodes rendering EMPTY             12   pure ancestors, an ANSWER not a bug
#
# ⚠⚠ AND ONE SPEC CLAIM THAT NEITHER CORPUS REPRODUCES. §7.5 says the "class
# filter hid everything at this level" state is reachable. MEASURED over both
# committed corpora at the shipped `devint 0 srccur 1`: tb_bandgap has ZERO
# nodes where the own level survives unfiltered but is emptied by the filter,
# and tb_charge_pump has four nodes where the filter takes SOME (4->2, 5->4,
# 5->4) and none where it takes ALL. The state is reachable in principle — a
# wrapper kept because a DESCENDANT carries a net, whose own level is all
# device — so BQ67c builds exactly that inventory by hand rather than leaving
# the third sentence untested. Stated here because "we could not reach it" and
# "we did not look" are different facts.

set ::wvbs_tag  wvsigbrowser_sea
set ::wvbs_name test_wave_sigbrowser_sea
source [file join [file dirname [info script]] wvbs_common.tcl]

# --- pure helpers (both arms) -------------------------------------------------

# The corpus as a plain name list, or an assertable sentinel. NEVER {} — an
# absent fixture must not read as an empty design.
proc bq_slurp {name} {
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

# THE COMPOSITION UNDER TEST, spelled out of the same three procs the source
# composes: entries -> browser_level_names -> browser_label. PURE.
proc bq_compose {ents path} {
  if {[string match {*-FIXTURE} $ents]} { return $ents }
  set out {}
  foreach n [::wviewer::browser_level_names $ents $path] {
    lappend out [::wviewer::browser_label [::wviewer::signal_entry $n]]
  }
  return $out
}

proc bq_ents {names} {
  if {[string match {*-FIXTURE} $names]} { return $names }
  set r {}
  foreach n $names { lappend r [::wviewer::signal_entry $n] }
  return $r
}

# Do two label lists share nothing? An ASSERTABLE 1/0 plus the shapes, never a
# bare boolean that reads the same for "both empty".
proc bq_disjoint {a b} {
  if {![llength $a] || ![llength $b]} { return "degenerate: [llength $a] [llength $b]" }
  foreach x $a { if {[lsearch -exact $b $x] >= 0} { return "shares: $x" } }
  return 1
}

if {[catch {

set bq_names [bq_slurp tb_bandgap_vars.txt]
check {BQ50 (PRECONDITION) the committed corpus is the 424-name one} \
  [expr {[string match {*-FIXTURE} $bq_names] ? $bq_names : [llength $bq_names]}] 424
set bq_all [bq_ents $bq_names]
set bq_fil [::wviewer::browser_class_filter $bq_all 0 1]
check {BQ50 (PRECONDITION) the shipped class policy leaves 190 of them} \
  [llength $bq_fil] 190

# ⚠ THE EXPECTED LIST IS THE MEASURED ONE, and it is spelled out rather than
# recomputed: a check whose expectation is `[bq_compose ...]` against
# `[bq_compose ...]` is an identity, green on any implementation at all.
set bq_x1x1x1 {vmeas:i vmeas1:i dn dp}
check {BQ50 (PURE) the composition level_names -> label gives the exact ordered
       list, R8's currents rendered <instance>:<param> and its voltages bare} \
  [bq_compose $bq_fil x1.x1.x1] $bq_x1x1x1
check {BQ50 (PURE, THE ORDER IS RAW-FILE ORDER) ...and it is not sorted} \
  [expr {[bq_compose $bq_fil x1.x1.x1] eq [lsort $bq_x1x1x1]}] 0
check {BQ50 (PURE) a level of 23 renders 23 labels, currents first} \
  [lrange [bq_compose $bq_fil x1.x2] 0 9] \
  {v1:i v2:i v3:i v4:i v5:i v6:i v7:i v17:i g1 g2}
check {BQ50 (PURE) a PURE ANCESTOR composes to the EMPTY list — an answer} \
  [bq_compose $bq_fil x1.xr1] {}

# ⚠ THE ARM STATEMENT. Everything below needs a mapped canvas with a real
# height: the flow's rows-per-column is `paneh / rowh`, so with no display there
# is no pane, no height and no flow. `--nogui` runs the five pure checks above
# and skips the rest, and the banner says which.
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # --- the fixture ----------------------------------------------------------
  # A throwaway toplevel and a faked registry entry, test_wave_sigbrowser_panes'
  # recipe verbatim. 760 px tall so the sea gets a usable share at the default
  # 0.55 sash; the sash is moved deliberately in BQ54/BQ55 and put back.
  catch {destroy .wvbq1}
  toplevel .wvbq1
  wm title .wvbq1 {two-pane item11 sea-of-names fixture}
  wm geometry .wvbq1 1400x760+40+40
  canvas .wvbq1.drw -background white -width 1200 -height 720
  pack .wvbq1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbq [dict create top .wvbq1 win_path .wvbq1.drw]
  update
  set bq_mapped [bs_wait_mapped .wvbq1.drw]

  set F   .wvbq1.wvbrowser
  set TV  $F.pw.tvf.tv
  set C   $F.pw.sea.c
  set HSB $F.pw.sea.hsb
  set ST  $F.pw.sea.st
  set SB  $F.wvsearch
  set FB  $F.wvfilter
  set tok wvbq

  check {BQ51 (PRECONDITION) the fixture toplevel really mapped} $bq_mapped 1
  check {BQ51 browser_build returns 1 and BOTH panes exist} \
    [list [pcall ::wviewer::browser_build $tok .wvbq1] \
          [winfo exists $TV] [winfo exists $C] [winfo exists $ST]] \
    [list 1 1 1 1]
  pcall ::wviewer::browser_toggle 1 $tok
  update
  set bq_sidew [bs_wait_widths .wvbq1 $F .wvbq1.drw]
  bs_wait_mapped $TV
  bs_wait_mapped $C
  set bq_frac [bs_wait_sash $F.pw]

  # THE INVENTORY. Hand-seeded for the reason stated in the header: the fixture
  # has no xschem context, so browser_reload's signal_list read (correctly)
  # answers {}. browserraw is seeded too, so the design root is named
  # `tb_bandgap` rather than the `design` floor — §7.2's first state prints it.
  set ::wviewer::browsersigs($tok) $bq_names
  set ::wviewer::browserraw($tok)  {/nowhere/tb_bandgap.raw}
  set bq_ref [pcall ::wviewer::browser_refresh $tok 0]
  update
  check {BQ51 (PRECONDITION) the refresh rewrote the tree over the 424 names} \
    $bq_ref 1
  check {BQ51 (PRECONDITION) the tree is the 45-row projection — 44 kept
         instance nodes and the design root — and the root is named} \
    [list [llength [bs_tree_ids $TV]] [pcall $TV item {g:} -text] \
          [pcall $TV exists {g:x1}] [pcall $TV exists {s:v(vbg)}]] \
    [list 45 tb_bandgap 1 0]

  # --- BQ51: OWN LEVEL, NOT RECURSIVE ---------------------------------------
  # ⚠ THE DESCENDED LEG IS THE ONE THAT SEES A browser_leaf_names SWAP. At the
  # design root the two answers coincide closely enough to look plausible; at
  # x1 they are 43 and 172.
  set bq_root [bs_sea_at $TV $C {g:}]
  set bq_rootn [pcall ::wviewer::browser_sea_names $tok]
  set bq_x1   [bs_sea_at $TV $C {g:x1}]
  set bq_x1n  [pcall ::wviewer::browser_sea_names $tok]
  check {BQ51 selecting the ROOT shows its 18 OWN-level signals; selecting g:x1
         shows 43; and the two sets are DISJOINT (a recursive pane would read
         424 at the root and 172 at x1)} \
    [list [llength $bq_root] [llength $bq_x1] [bq_disjoint $bq_rootn $bq_x1n]] \
    [list 18 43 1]
  # ⚠⚠ MEASURED, AND IT IS WHY THE PREVIOUS CHECK COMPARES *NAMES*: the two
  # levels' LABEL sets are NOT disjoint — the root and x1 both render a `net1`,
  # from `v(net1)` and `v(x1.net1)`. R8's label drops the path, so the same
  # label legitimately appears at every level that has such a net. Written as a
  # value rather than left as a trap for the next person to compare labels.
  check {BQ51 (THE LABEL IS NOT AN IDENTITY, MEASURED) ...while the two levels'
         LABEL sets DO collide, which is exactly why nothing resolves through
         one} \
    [bq_disjoint $bq_root $bq_x1] {shares: net1}
  check {BQ51 ...and the pane's labels are the PURE composition's, exactly} \
    [list [lrange $bq_root 0 5] [lrange $bq_x1 0 5]] \
    [list [lrange [bq_compose $bq_fil {}] 0 5] \
          [lrange [bq_compose $bq_fil x1] 0 5]]
  check {BQ51 the full raw names behind them are the RAW names, not the labels} \
    [list [lindex [pcall ::wviewer::browser_sea_names $tok] 0] \
          [lindex $bq_x1 0]] \
    [list {i(v.x1.v1)} {v1:i}]

  # --- BQ52: a PURE ANCESTOR renders EMPTY and the caption SAYS SO ------------
  set bq_prev_n [llength [bs_sea_labels $C]]
  set bq_pure [bs_sea_at $TV $C {g:x1.xr1}]
  set bq_st [pcall $ST cget -text]
  check {BQ52 a PURE ANCESTOR renders EMPTY and the caption SAYS SO — and the
         pane was NON-empty one selection earlier} \
    [list $bq_prev_n $bq_pure \
          [string match {*has no signals of its own*} $bq_st]] \
    [list 43 empty 1]
  check {BQ52 ...and it NAMES the node, so the sentence is about something} \
    [expr {[string first {x1.xr1 has no signals} $bq_st] >= 0}] 1
  check {BQ52 (THE OTHER SHAPE) `empty` is not `no-pane` — the canvas is there} \
    [list [winfo exists $C] [llength [pcall $C find all]]] [list 1 0]

  # --- BQ53: R5's HEADLINE ---------------------------------------------------
  # ⚠⚠ THE WHOLE POINT OF THE TWO PANES. Typing narrows the LOWER pane and
  # leaves the tree's open set alone; only a DELIBERATE reveal opens it.
  proc bq_openset {tv} { return [bs_open_set $tv] }
  # ⚠⚠ THIS LEG WAS ADDED BECAUSE THE SABOTAGE ONLY HAD A SOURCE WITNESS.
  # Putting `$tv see` back into browser_sea_refresh reddened BQ64's source grep
  # and NOTHING ELSE: every behavioural leg below captured its "before" AFTER a
  # selection change, by which time `see` had already force-opened the ancestor,
  # so before and after agreed and the check passed. `see` opens every ancestor
  # of its target — that is browser_reveal's central finding (spec §4.2) — so
  # the claim that sees it is SELECTING A COLLAPSED DESCENDANT and finding the
  # tree still collapsed. Exactly item 10's S3 lesson, one pane over.
  catch {$TV item {g:x1} -open 0}
  update
  set bq_precol [bq_openset $TV]
  catch {$TV selection set [list {g:x1.x2}]}
  update
  set bq_open0 [bq_openset $TV]
  check {BQ53 (R5, BEHAVIOURAL) selecting a COLLAPSED descendant fills the sea
         WITHOUT opening its ancestor — the lower pane never calls `see`} \
    [list $bq_precol $bq_open0 [llength [bs_sea_labels $C]]] \
    [list {g:} {g:} 23]
  set bq_sea0  [bs_sea_labels $C]
  # ⚠ ITEM 20 RE-PATTERNED THIS, and the property it was chosen for is intact.
  # It used to read `v(x1.x2.net5*`, whose FIRST keystroke (`v`) matched nothing
  # — that is what makes this a real R5 test rather than a no-op. `net5*` has
  # the same shape (`n`, `ne`, `net`, `net5` all match nothing at this level,
  # MEASURED) and narrows the pane to the same ONE row, so only the STRING in
  # the precondition moved. It is now also the driver's own case: this pattern
  # matches the label the pane draws, and matches ZERO raw names.
  set bq_typed [bs_type $SB {net5*}]
  update
  set bq_open1 [bq_openset $TV]
  set bq_sea1  [bs_sea_labels $C]
  check {BQ53 (PRECONDITION) the keystrokes were really delivered and the pane
         had something to lose} \
    [list $bq_typed [llength $bq_sea0]] [list {net5*} 23]
  check {BQ53 (R5's HEADLINE) a Search keystroke leaves the tree's OPEN SET
         UNCHANGED while the sea's contents CHANGE} \
    [list [expr {$bq_open1 eq $bq_open0}] [expr {$bq_sea1 ne $bq_sea0}] \
          $bq_sea1] \
    [list 1 1 {net5}]
  check {BQ53 ...and the tree's NODE SET is untouched too (§7.1)} \
    [llength [bs_tree_ids $TV]] 45
  set bq_show [pcall ::wviewer::browser_show_path $tok x1.x2]
  update
  set bq_open2 [bq_openset $TV]
  check {BQ53 ...while an EXPLICIT browser_show_path DOES open the ancestor} \
    [list [lindex $bq_show 0] \
          [expr {[lsearch -exact $bq_open2 {g:x1}] >= 0}]] \
    [list ok 1]
  bs_type $SB {}
  update

  # --- BQ65 (MINE): THE TWO PANES REALLY DO TAKE DIFFERENT SETS -------------
  # ⚠ THE SABOTAGE THIS EXISTS FOR: feed the sea the bar-UNFILTERED set. Every
  # other check in the file stays green, because with the bars EMPTY the two
  # sets are identical. Only a check that types a pattern AND reads both panes
  # can see it.
  catch {$TV selection set [list {g:x1.x2}]}
  update
  set bq_treeA [bs_tree_ids $TV]
  set bq_seaA  [bs_sea_labels $C]
  bs_type $FB {*net1*}
  update
  set bq_treeB [bs_tree_ids $TV]
  set bq_seaB  [bs_sea_labels $C]
  check {BQ65 (§7.1) a Filter pattern moves the SEA and NOT the tree — the two
         panes take different sets, and the tree keeps every one of its 45
         nodes while the sea drops to the four that match, in RAW order} \
    [list [expr {$bq_treeB eq $bq_treeA}] [llength $bq_treeB] \
          [expr {$bq_seaB ne $bq_seaA}] $bq_seaB] \
    [list 1 45 1 {net1 net10 net11 net12}]
  check {BQ65 (THE CLASS FILTER IS SHARED, spec §6) all four survivors are real
         names and no DEVICE-classed name reaches the sea at all} \
    [list [llength [pcall ::wviewer::browser_sea_names $tok]] \
          [lsearch -glob [pcall ::wviewer::browser_sea_names $tok] {*@*}] \
          [lindex [pcall ::wviewer::browser_sea_names $tok] 0]] \
    [list 4 -1 {v(x1.x2.net1)}]
  bs_type $FB {}
  update
  check {BQ65 (CONTROL) clearing the bar puts the sea back, tree still 45} \
    [list [llength [bs_sea_labels $C]] [llength [bs_tree_ids $TV]]] \
    [list 23 45]

  # --- BQ66 (MINE): a bar keystroke that changes NO selection still moves it --
  # ⚠ browser_populate fires <<TreeviewSelect>> only when the selection really
  # CHANGED. The tail call in browser_refresh is what covers the case where it
  # did not — drop it and this is the check that reds.
  set bq_before [bs_sea_labels $C]
  set bq_selb [pcall $TV selection]
  bs_type $SB {*net12*}
  update
  check {BQ66 a bar keystroke moves the sea even when the tree SELECTION did
         not change (the refresh tail, not <<TreeviewSelect>>)} \
    [list $bq_selb [pcall $TV selection] \
          [expr {[bs_sea_labels $C] ne $bq_before}] [bs_sea_labels $C]] \
    [list {g:x1.x2} {g:x1.x2} 1 {net12}]
  bs_type $SB {}
  update

  # ⚠⚠ BQ66 ABOVE DOES NOT SEE THE TAIL CALL, AND THAT WAS MEASURED, NOT
  # ASSUMED. Removing `browser_sea_refresh` from `browser_refresh`'s tail
  # produced ZERO reds across the whole file. The reason is a ttk behaviour this
  # file had been relying on without saying so:
  #
  #     ttk::treeview fires <<TreeviewSelect>> on EVERY `selection set`,
  #     INCLUDING one that sets the value it already held.
  #
  # Measured on a bare two-row treeview: same-value `selection set` -> 1 event.
  # `browser_populate` re-sets the selection on every repopulate, so the event
  # route already refreshes the sea on every keystroke and the tail call is
  # belt-and-braces on TODAY's path. It is kept — `browser_populate` skips
  # `selection set` entirely when no previous selection survives AND there is no
  # root row (the All-DBs shape BP43a is the tombstone for), and there the tail
  # is the only refresh — so the check below makes it LOAD-BEARING by removing
  # the other route, which is the only way to attribute a red to it.
  #
  # ⚠ IT RESTORES THE BINDING IT REMOVED (the named-helper rule): leaving the
  # tree's <<TreeviewSelect>> unbound would silently make every later check in
  # this file depend on the tail call.
  set bq_bindwas [bind $TV <<TreeviewSelect>>]
  bind $TV <<TreeviewSelect>> {}
  catch {$TV selection set [list {g:x1.x2}]}
  update
  set bq_t0 [bs_sea_labels $C]
  bs_type $SB {*net12*}
  update
  set bq_t1 [bs_sea_labels $C]
  bind $TV <<TreeviewSelect>> $bq_bindwas
  bs_type $SB {}
  update
  check {BQ66b (THE TAIL CALL, ATTRIBUTABLE) with the tree's <<TreeviewSelect>>
         binding REMOVED, a bar keystroke still moves the sea — so the refresh's
         own tail call is what did it, and nothing else could have} \
    [list [expr {$bq_bindwas ne {}}] [llength $bq_t0] $bq_t1 \
          [expr {[bind $TV <<TreeviewSelect>>] eq $bq_bindwas}]] \
    [list 1 23 {net12} 1]

  # --- BQ54/BQ55: HORIZONTAL, AND ONLY HORIZONTAL ---------------------------
  # A SHORT pane is what forces many columns: rows-per-column is paneh/rowh, so
  # the same 43 names flow into 5 columns at the default sash and into many more
  # when the sea is squeezed. The sash is restored afterwards.
  set bq_sash_was [pcall ::wviewer::browser_sash $tok]
  pcall ::wviewer::browser_sash $tok 0.90
  update ; update idletasks
  catch {$TV selection set [list {g:x1}]}
  update
  set bq_sr [pcall $C cget -scrollregion]
  # ⚠ `[$hsb get] ne {0 1}` WAS THE FIRST SPELLING AND IT IS VACUOUS: a
  # scrollbar answers FLOATS (`0.0 1.0`), so that expression is 1 whatever the
  # pane does. The claim is that the thumb covers LESS than the whole trough.
  set bq_hg [pcall $HSB get]
  check {BQ54 the canvas scrolls HORIZONTALLY and only horizontally: the
         scrollregion is WIDER than the widget, exactly as TALL as it, and the
         horizontal scrollbar's thumb really covers less than the whole trough} \
    [list [expr {[bs_num [lindex $bq_sr 2]] > [winfo width $C]}] \
          [expr {[bs_num [lindex $bq_sr 3]] == [winfo height $C]}] \
          [expr {[bs_num [lindex $bq_hg 1]] - [bs_num [lindex $bq_hg 0]] < 1.0}] \
          [pcall $C cget -yscrollcommand]] \
    [list 1 1 1 {}]
  check {BQ54 (M4/R3, SOURCE) there is no vertical scrollbar to reach it with} \
    [lsort [pcall winfo children $F.pw.sea]] \
    [lsort [list $C $HSB $ST]]
  catch {$TV selection set [list {g:x1.x8}]}
  update
  check {BQ55 (BQ54's CONTROL) with ONE name in a squeezed pane there is
         nothing to scroll, and the pane is not empty either} \
    [list [pcall $HSB get] [bs_sea_labels $C]] [list {0.0 1.0} {s}]
  pcall ::wviewer::browser_sash $tok $bq_sash_was
  update ; update idletasks

  # --- BQ56/BQ63: THE LABEL IS A DISPLAY, THE INDEX IS THE HANDLE ------------
  catch {$TV selection set [list {g:x1.x2}]}
  update
  set bq_lab [bs_sea_labels $C]
  set bq_k [lsearch -exact $bq_lab {v1:i}]
  # ⚠ MEASURED, NOT ASSUMED. The first cut of this check looked for `net5:i`
  # beside `net5` — the panes fixture's SYNTHETIC pair. tb_bandgap's x1.x2 has
  # no such name; its currents are all source branches (`i(v.x1.x2.v1)`). The
  # claim survives with the real pair, and the corrected precondition is what
  # stops it silently testing an absent cell (which reads `{} {}`, not a red).
  check {BQ56 (PRECONDITION) the level really carries both shapes — a bare
         voltage label and an <instance>:<param> current one} \
    [list [expr {[lsearch -exact $bq_lab {net1}] >= 0}] \
          [expr {$bq_k >= 0}]] [list 1 1]
  check {BQ56 the item at flow index k shows the LABEL while its identity is
         the FULL RAW NAME — and no raw name contains the label} \
    [list [pcall $C itemcget [bs_sea_item $C $bq_k] -text] \
          [pcall ::wviewer::browser_sea_name $tok $bq_k] \
          [string first {v1:i} [pcall ::wviewer::browser_sea_name $tok $bq_k]]] \
    [list {v1:i} {i(v.x1.x2.v1)} -1]
  check {BQ56 ...and the VOLTAGE beside it renders bare, from a different raw} \
    [list [pcall $C itemcget [bs_sea_item $C [lsearch -exact $bq_lab {net1}]] -text] \
          [pcall ::wviewer::browser_sea_name $tok [lsearch -exact $bq_lab {net1}]]] \
    [list {net1} {v(x1.x2.net1)}]
  check {BQ63 the sea's item tags do NOT alias the tree's s:/g: namespace} \
    [list [regexp {^[sg]:} [lindex [pcall $C gettags [bs_sea_item $C 0]] 0]] \
          [lsort [pcall $C gettags [bs_sea_item $C 0]]]] \
    [list 0 [lsort [list cell n0]]]
  check {BQ63 (AND THE RAW NAME IS NOT A TAG) a name carrying ( ) [ ] @ would
         make `find withtag` a tag EXPRESSION that throws on its own data} \
    [expr {[lsearch -glob [pcall $C gettags [bs_sea_item $C $bq_k]] {*(*}] >= 0}] 0

  # --- BQ57: SHIFT EXTENDS IN FLOW ORDER ------------------------------------
  catch {$TV selection set [list {g:x1}]}
  update
  set bq_c0 [bs_sea_click $C 0]
  set bq_sel1 [pcall ::wviewer::browser_sea_selection $tok]
  set bq_c30 [bs_sea_click $C 30 <Shift-Button-1>]
  set bq_sel2 [pcall ::wviewer::browser_sea_selection $tok]
  set bq_want {}
  for {set i 0} {$i <= 30} {incr i} { lappend bq_want $i }
  # INDEPENDENT EVIDENCE that 0 and 30 are in different COLUMNS: read the two
  # items' own bboxes rather than the layout arithmetic under test.
  set bq_bb0 [pcall $C bbox [bs_sea_item $C 0]]
  set bq_bb30 [pcall $C bbox [bs_sea_item $C 30]]
  check {BQ57 (PRECONDITION) both gestures landed, and cell 30 really is in a
         different COLUMN from cell 0 — so this crosses a column boundary} \
    [list $bq_c0 $bq_c30 \
          [expr {[bs_num [lindex $bq_bb30 0]] > [bs_num [lindex $bq_bb0 0]]}]] \
    [list ok ok 1]
  check {BQ57 a plain click selects exactly ONE} $bq_sel1 {0}
  check {BQ57 Shift-click from column 0 into column N selects the ARITHMETIC
         range in FLOW order, all 31 of them, not a visual rectangle} \
    [list [llength $bq_sel2] $bq_sel2] [list 31 $bq_want]
  set bq_c5 [bs_sea_click $C 5 <Control-Button-1>]
  check {BQ57 Ctrl-click TOGGLES one out and keeps the other thirty} \
    [list $bq_c5 [llength [pcall ::wviewer::browser_sea_selection $tok]] \
          [lsearch -exact [pcall ::wviewer::browser_sea_selection $tok] 5]] \
    [list ok 30 -1]
  # ⚠⚠ THIS IS THE CHECK THAT FOUND THE `-time` TRAP. Two Ctrl-clicks on ONE
  # cell read 30 and then 30 again: `event generate` stamps time 0, Tk's
  # double-click detector saw a zero delta, and the SECOND press went to
  # `<Double-Button-1>` — i.e. it PLOTTED instead of toggling. An `after 700`
  # between them changed nothing, because wall-clock time is not what Tk
  # compares. `bs_sea_click` now carries a strictly increasing `-time`, and the
  # SAME-CELL repeat is the only gesture in the file that can see it.
  bs_sea_click $C 5 <Control-Button-1>
  check {BQ57 ...and back in again, because a toggle is a toggle} \
    [llength [pcall ::wviewer::browser_sea_selection $tok]] 31
  # a click in the gutter past the last column: browser_flow_hit's honest MISS,
  # which `find closest` could not have answered
  set bq_w [winfo width $C]
  catch {event generate $C <Button-1> -x [expr {$bq_w - 2}] -y 2}
  update
  check {BQ57 (THE MISS) a click past the last column CLEARS rather than
         selecting a neighbour} \
    [pcall ::wviewer::browser_sea_selection $tok] {}

  # --- BQ58/BQ59: THE PLOT ROUTES -------------------------------------------
  proc bq_spy_on {} {
    set ::bq_plot {}
    set ::bq_dest {}
    rename ::wviewer::plot_signals ::wviewer::__bq_real_plot_signals
    proc ::wviewer::plot_signals {token exprs {colors {}} {destover {}}} {
      lappend ::bq_plot [list $token $exprs]
      lappend ::bq_dest [list $token $destover]
      return {}
    }
  }
  proc bq_spy_off {} {
    rename ::wviewer::plot_signals {}
    rename ::wviewer::__bq_real_plot_signals ::wviewer::plot_signals
  }
  bq_spy_on
  catch {$TV selection set [list {g:x1.x2}]}
  update
  set bq_lab [bs_sea_labels $C]
  set bq_k [lsearch -exact $bq_lab {net1}]
  set ::bq_plot {}
  set bq_d [bs_sea_dclick $C $bq_k]
  check {BQ58 a double-click plots exactly that ONE signal, by its FULL RAW
         NAME — the label `net1` is not a name any raw carries} \
    [list $bq_d $::bq_plot] [list ok [list [list wvbq {v(x1.x2.net1)}]]]
  set ::bq_plot {}
  bs_sea_click $C 0
  bs_sea_click $C 2 <Shift-Button-1>
  bs_sea_click $C 2 <Button-2>
  check {BQ58 MMB on a cell INSIDE the selection plots the WHOLE selection, in
         flow order} \
    $::bq_plot [list [list wvbq {i(v.x1.x2.v1) i(v.x1.x2.v2) i(v.x1.x2.v3)}]]
  set ::bq_plot {}
  bs_sea_click $C 7 <Button-2>
  check {BQ58 ...and MMB OUTSIDE it plots just that one (browser_plot_at's rule,
         spelled the same way one pane over)} \
    $::bq_plot [list [list wvbq {i(v.x1.x2.v17)}]]
  set ::bq_plot {}
  set bq_tb [pcall $TV bbox {g:x1}]
  if {[llength $bq_tb] != 4} {
    puts "SKIPPED: BQ59 tree-MMB leg (g:x1 has no bbox — row not on screen)"
  } else {
    event generate $TV <Button-2> \
      -x [expr {[lindex $bq_tb 0] + [lindex $bq_tb 2] / 2}] \
      -y [expr {[lindex $bq_tb 1] + [lindex $bq_tb 3] / 2}]
    update
    check {BQ59 (R6 REGRESSION GUARD, BEHAVIOURAL) MMB on the TREE's g:x1 is
           still RECURSIVE — 172 signals, descendants included, against the 43
           its own level holds} \
      [list [llength [lindex [lindex $::bq_plot 0] 1]] \
            [llength [::wviewer::browser_level_names $bq_fil x1]]] \
      [list 172 43]
  }
  bq_spy_off

  # --- BQ60: COPY YIELDS FULL RAW NAMES -------------------------------------
  catch {$TV selection set [list {g:x1.x2}]}
  update
  bs_sea_click $C 0
  bs_sea_click $C 1 <Shift-Button-1>
  set bq_cn [pcall ::wviewer::browser_sea_copy_names $tok \
               [::wviewer::browser_sea_selection $tok]]
  set bq_clip {}
  catch {set bq_clip [::clipboard get -displayof .wvbq1]}
  check {BQ60 copy yields FULL RAW NAMES, newline joined — never labels} \
    [list $bq_cn $bq_clip] [list 2 "i(v.x1.x2.v1)\ni(v.x1.x2.v2)"]

  # --- BQ61/BQ68: THE SEA'S MENU IS A DISTINCT WIDGET -----------------------
  proc bq_entries {m} {
    if {[catch {winfo exists $m} e] || !$e} { return absent }
    set n {}
    if {[catch {$m index end} n]} { return unreadable }
    if {$n eq {none}} { return "built:0" }
    set out {}
    for {set i 0} {$i <= $n} {incr i} {
      set t {}
      catch {set t [$m type $i]}
      set l {}
      catch {set l [$m entrycget $i -label]}
      lappend out [expr {$t eq {separator} ? {--} : $l}]
    }
    return $out
  }
  # The entry TYPES, which is the half of the table that cannot differ between
  # the two panes no matter what they are pointed at.
  proc bq_types {m} {
    if {[catch {winfo exists $m} e] || !$e} { return absent }
    set n {}
    if {[catch {$m index end} n]} { return unreadable }
    if {$n eq {none}} { return "built:0" }
    set out {}
    for {set i 0} {$i <= $n} {incr i} {
      set t {}
      catch {set t [$m type $i]}
      lappend out $t
    }
    return $out
  }
  # ONE cell selected, so the header names a signal rather than a count — the
  # previous block left two selected and the menu correctly said `2 signals`.
  bs_sea_click $C 0
  set bq_p [bs_sea_xy $C 0]
  set bq_post [pcall ::wviewer::browser_sea_menu_post $tok $C \
                 [lindex $bq_p 0] [lindex $bq_p 1] 300 300]
  set bq_seam .wvbq1.wvseamenu
  set bq_treem .wvbq1.wvbrowsermenu
  set bq_seaents [bq_entries $bq_seam]
  set bq_seatypes [bq_types $bq_seam]
  set bq_seadesc [pcall $bq_seam entrycget 7 -state]
  set bq_seacmd  [pcall $bq_seam entrycget 7 -command]
  catch {::wviewer::browser_sea_menu_unpost $tok}
  set bq_tb [pcall $TV bbox {g:x1}]
  set bq_tpost 0
  if {[llength $bq_tb] == 4} {
    set bq_tpost [pcall ::wviewer::browser_menu_post $tok $TV \
                    [expr {[lindex $bq_tb 0] + [lindex $bq_tb 2] / 2}] \
                    [expr {[lindex $bq_tb 1] + [lindex $bq_tb 3] / 2}] 300 300]
  }
  set bq_treeents [bq_entries $bq_treem]
  set bq_treetypes [bq_types $bq_treem]
  catch {::wviewer::browser_menu_unpost $tok}
  check {BQ61 the sea's RMB menu is a DISTINCT widget from the tree's, and BOTH
         posted} \
    [list $bq_post $bq_tpost [expr {$bq_seam ne $bq_treem}]] [list 1 1 1]
  check {BQ68 (MINE) ...carrying the SAME eight-entry table in the same ORDER
         and of the same TYPES, so BM23's index table describes both panes} \
    [list [llength $bq_seaents] $bq_seatypes \
          [expr {$bq_seatypes eq $bq_treetypes}]] \
    [list 8 {command separator command cascade command command separator command} 1]
  # ⚠ THE LABELS ARE COMPARED BY SHAPE, NOT BYTE FOR BYTE, AND THAT IS THE
  # CLAIM. Entry 0 names what the gate picked (a SIGNAL on one pane, a NODE's
  # leaf count on the other) and the Copy entry carries the count, so two menus
  # over two different targets must differ THERE and nowhere else. A byte
  # comparison would either be false or would force both panes onto one target.
  check {BQ68 the sea's entry labels are the shipped table's, with the header
         naming the ONE signal the click picked} \
    [list [lindex $bq_seaents 0] [lindex $bq_seaents 1] \
          [string match {Plot (*)} [lindex $bq_seaents 2]] \
          [lrange $bq_seaents 3 7]] \
    [list {i(v.x1.x2.v1)} -- 1 \
          [list {Plot to} {Send to Add Trace...} {Copy name} -- {Descend to here}]]
  check {BQ68 ...and the tree's differ ONLY in the header and the Copy count} \
    [list [lindex $bq_treeents 1] \
          [expr {[lindex $bq_treeents 2] eq [lindex $bq_seaents 2]}] \
          [lrange $bq_treeents 3 4] [lrange $bq_treeents 6 7] \
          [string match {Copy name*} [lindex $bq_treeents 5]]] \
    [list -- 1 [list {Plot to} {Send to Add Trace...}] \
          [list -- {Descend to here}] 1]
  check {BQ68 `Descend to here` is LIVE on a single sea cell and its command
         carries the SEA's currency (a flow INDEX), never a row id} \
    [list $bq_seadesc $bq_seacmd \
          [pcall ::wviewer::browser_sea_target_path $tok 0]] \
    [list normal {wviewer::browser_sea_descend_to wvbq 0} {ok x1.x2}]
  check {BQ68 ...and two cells at the SAME level still agree on one path, while
         two at DIFFERENT levels are refused rather than first-won} \
    [list [pcall ::wviewer::browser_sea_target_path $tok [list 0 1]] \
          [lindex [pcall ::wviewer::browser_sea_target_path $tok [list 0 999]] 0]] \
    [list {ok x1.x2} err]

  # --- BQ64: THE ROW PITCH IS READ AT RUNTIME -------------------------------
  set bq_rowbody [wvproc_body $wsrc wviewer::browser_sea_rowh]
  check {BQ64 rowHeight came from font metrics at RUNTIME, and no constant row
         pitch is spelled anywhere in the proc that answers it} \
    [list [regexp {font metrics AseEntryFont -linespace} $bq_rowbody] \
          [regexp {rowh +[0-9]+} $bq_rowbody]] {1 0}
  check {BQ64 (BEHAVIOURAL) ...and it really equals the font's linespace plus
         the padding, on THIS display} \
    [pcall ::wviewer::browser_sea_rowh] \
    [expr {[font metrics AseEntryFont -linespace] + 4}]
  set bq_seabody [wvproc_body $wsrc wviewer::browser_sea_refresh]
  check {BQ64 (SOURCE, R5) the refresh never calls `see` and never touches the
         tree's open state} \
    [list [regexp -all {\$tv see} $bq_seabody] \
          [regexp -all {item .* -open} $bq_seabody]] {0 0}
  check {BQ64 (SOURCE, §7.6) it selects with browser_level_names, not with
         browser_leaf_names} \
    [list [regexp -all {browser_level_names} $bq_seabody] \
          [regexp -all {browser_leaf_names} $bq_seabody]] {1 0}

  # --- BQ67: §7.2's THREE STATES ARE THREE DIFFERENT SENTENCES ---------------
  catch {$TV selection set [list {g:x1.x2}]}
  update
  set bq_s_count [pcall $ST cget -text]
  catch {$TV selection set [list {g:x1.xr1}]}
  update
  set bq_s_empty [pcall $ST cget -text]
  catch {$TV selection set [list {g:x1.x2}]}
  bs_type $FB {zzz-no-such-signal}
  update
  set bq_s_bars [pcall $ST cget -text]
  bs_type $FB {}
  update
  check {BQ67 (§7.2) the ordinary line counts SHOWN of OWN, for the node} \
    $bq_s_count {23 of 23 signals}
  check {BQ67 a PURE ANCESTOR gets its own sentence, naming the node} \
    $bq_s_empty {x1.xr1 has no signals of its own}
  check {BQ67 an emptying BAR gets a THIRD sentence that names the remedy} \
    $bq_s_bars {0 of 23 signals (the Search/Filter bar is hiding them)}
  check {BQ67 the three are genuinely THREE DIFFERENT VALUES} \
    [expr {$bq_s_count ne $bq_s_empty && $bq_s_empty ne $bq_s_bars &&
           $bq_s_count ne $bq_s_bars}] 1
  check {BQ67 (THE ROOT NAMES THE DESIGN) `has no signals of its own` about an
         empty path would read as a bug report} \
    [pcall ::wviewer::browser_sea_label $tok {}] tb_bandgap

  # ⚠⚠ BQ67c BUILDS ITS OWN INVENTORY, and the header says why: MEASURED, the
  # "class filter hid EVERYTHING at this level" state is NOT REACHABLE on either
  # committed corpus at the shipped policy. §7.5 says it is reachable in
  # principle, and it is — this is exactly the shape it describes: x1 survives
  # in the tree because its DESCENDANT x1.x2 carries a real net, while x1's own
  # level holds nothing but a device internal node.
  set bq_sig_was $::wviewer::browsersigs($tok)
  set ::wviewer::browsersigs($tok) {v(x1.x2.net5) v(m.x1.mn1#body)}
  pcall ::wviewer::browser_refresh $tok 0
  update
  catch {$TV selection set [list {g:x1}]}
  update
  check {BQ67c (§7.5, SYNTHESISED — see the header) a node whose own level is
         ALL DEVICE survives in the tree, renders EMPTY, and gets the THIRD
         sentence — not the bar one and not the pure-ancestor one} \
    [list [pcall $TV exists {g:x1}] [bs_sea_labels $C] [pcall $ST cget -text]] \
    [list 1 empty {0 of 1 signals (device internals are hidden)}]
  check {BQ67c (ITS POSITIVE CONTROL) the DESCENDANT that kept it alive still
         shows its one real net} \
    [list [bs_sea_at $TV $C {g:x1.x2}] [pcall $ST cget -text]] \
    [list {net5} {1 of 1 signals}]
  set ::wviewer::browsersigs($tok) $bq_sig_was
  pcall ::wviewer::browser_refresh $tok 0
  update
  check {BQ67c (RESTORED) the corpus is back} \
    [llength [bs_tree_ids $TV]] 45

  # === BQ70-BQ74 (ITEM 20): THE BARS FILTER WHAT THE USER SEES ===============
  #
  # ⚠⚠ THE DRIVER'S OWN CASE, VERBATIM: "descend to x1 and there are signals
  # named net1, net2. The user SHOULD be able to filter based on what is
  # presented, not what the actual database value is. `net*` should show the
  # netXYZ signals. User should not have to put in `*net*` or `v(x1.net*`."
  #
  # MEASURED on THIS corpus at g:x1 (43 own-level signals under the shipped
  # class policy), the same pattern against the RAW name and against the R8
  # LABEL the lower pane actually draws:
  #
  #     net*        raw  0   label 26
  #     net1*       raw  0   label 11
  #     *1          raw  0   label  4
  #     v(x1.net*   raw 26   label  0
  #
  # Every zero in the raw column is ruling 3 doing its job: wildcards anchor to
  # the WHOLE name, so a leading-anchored pattern can never reach inside a
  # wrapped one. The pane renders `net1`; the matcher was globbing
  # `v(x1.net1)`. Only the `*...*` substring form ever worked, and only by
  # accident — which is why BQ65's `*net1*` above is the one bar check in this
  # file that does NOT move.
  catch {$TV selection set [list {g:x1}]}
  update
  check {BQ70 (PRECONDITION) at g:x1 with both bars EMPTY the sea draws the
         node's 43 OWN-level signals, and the caption counts them} \
    [list [llength [bs_sea_labels $C]] [pcall $ST cget -text]] \
    [list 43 {43 of 43 signals}]
  set bq_k16 [bs_type $SB {net*}]
  update
  check {BQ70 (THE DRIVER'S OWN CASE) `net*` — which matches NOTHING against the
         raw names — draws the 26 signals whose LABEL starts `net`, in raw-file
         order} \
    [list $bq_k16 [llength [bs_sea_labels $C]] [lrange [bs_sea_labels $C] 0 3] \
          [pcall $ST cget -text]] \
    [list {net*} 26 {net1 net2 net3 net4} {26 of 43 signals}]
  check {BQ70 ...and §7.1 is NOT weakened by it: the tree keeps all 45 nodes} \
    [llength [bs_tree_ids $TV]] 45

  # ⚠ TWO MORE PATTERNS, BECAUSE ONE COUNT IS ONE COUNT. 26 alone would also be
  # the answer of a break that ignored the pattern and drew every net-classed
  # row; 26/11/4 from three patterns cannot be.
  set bq_k16 [bs_type $SB {net1*}]
  update
  set bq_n1 [llength [bs_sea_labels $C]]
  set bq_l1 [lrange [bs_sea_labels $C] 0 2]
  set bq_k16b [bs_type $SB {*1}]
  update
  check {BQ71 `net1*` narrows to 11 and `*1` to a DIFFERENT four — and `*1`'s
         four are not all nets, so this is the LABEL being matched and not a
         `net` prefix being special-cased} \
    [list $bq_k16 $bq_n1 $bq_l1 $bq_k16b [bs_sea_labels $C]] \
    [list {net1*} 11 {net1 net10 net11} {*1} {f1 net1 net11 net21}]

  # ⚠⚠ THE RAW FORM STOPS WORKING, AND IT IS ASSERTED AS A VALUE RATHER THAN
  # LEFT AS A SURPRISE (work order §4.4: no `raw:` escape hatch and no
  # label-OR-raw union — a union makes "why did that match?" unanswerable). The
  # cost is declared here, in the file, next to the benefit.
  set bq_k16 [bs_type $SB {v(x1.net*}]
  update
  check {BQ72 (THE DECLARED COST) the RAW-shaped pattern that used to match all
         26 now matches NOTHING — and the caption names the remedy rather than
         leaving an empty pane unexplained} \
    [list $bq_k16 [bs_sea_labels $C] [pcall $ST cget -text]] \
    [list {v(x1.net*} empty \
          {0 of 43 signals (the Search/Filter bar is hiding them)}]

  # ⚠⚠ THE LABEL IS A FILTER SUBJECT, NEVER AN IDENTITY. The whole point of the
  # `-key` shape is that the matcher matches the transform and RETURNS THE
  # ORIGINAL. Return the label instead and every gesture downstream plots a
  # string no raw file contains — measured as item 11's S3, 26 reds over two
  # files. This is that claim stated once more from the bar's side.
  set bq_k16 [bs_type $SB {net*}]
  update
  check {BQ73 (THE LABEL IS A DISPLAY) the 26 SURVIVORS are the RAW names, not
         the labels that were matched} \
    [list [lrange [pcall ::wviewer::browser_sea_names $tok] 0 2] \
          [llength [pcall ::wviewer::browser_sea_names $tok]]] \
    [list {v(x1.net1) v(x1.net2) v(x1.net3)} 26]
  bs_type $SB {}
  update

  # ⚠⚠ THE TYPE DROPDOWN STAYS ON THE RAW NAME, AND THAT IS A RULING. `sig_type`
  # reads the `v(` / `i(` prefix, which R8's label deliberately destroys — a
  # current renders `v1:i`, whose sig_type is `other`. Key the type filter off
  # the label too and Current/Voltage select NOTHING, everywhere. Three legs, so
  # a break cannot hide in a zero: 6 currents with no pattern, the SAME 6 under
  # a label pattern that keeps them all, and 2 under one that keeps two.
  pcall ::wviewer::searchbar_set $SB [dict create pattern {} type i]
  update
  set bq_ti0 [bs_sea_labels $C]
  pcall ::wviewer::searchbar_set $SB [dict create pattern {*:i} type i]
  update
  set bq_ti1 [bs_sea_labels $C]
  pcall ::wviewer::searchbar_set $SB [dict create pattern {vb*} type i]
  update
  check {BQ74 (THE TYPE DROPDOWN READS THE RAW PREFIX) Current alone answers the
         level's six currents; a label pattern narrows THEM, and the two filters
         compose instead of cancelling} \
    [list $bq_ti0 [expr {$bq_ti1 eq $bq_ti0}] [bs_sea_labels $C]] \
    [list {v1:i v2:i vb1:i vb2:i vc1:i vc2:i} 1 {vb1:i vb2:i}]
  pcall ::wviewer::searchbar_set $SB [dict create]
  update
  check {BQ74 (RESTORED) the bar is back to its defaults and the whole level is
         showing again — read field by field, because the Search bar carries
         item 14's conditional fifth `alldbs` key and a whole-dict comparison
         here would be asserting THAT instead} \
    [list [pcall ::wviewer::dget [::wviewer::searchbar_get $SB] pattern MISSING] \
          [pcall ::wviewer::dget [::wviewer::searchbar_get $SB] type MISSING] \
          [llength [bs_sea_labels $C]]] \
    [list {} all 43]


  # === BQ75-BQ77: THE HOVER TOOLTIP — item 11's EIGHTH GESTURE ===============
  #
  # ⚠⚠ AN ACKNOWLEDGED MISS BEING PAID, not a new feature. PLAN item 11's scope
  # names "Tooltip on hover shows `browser_label_full`"; item 11 shipped SEVEN
  # binds on this canvas and recorded the omission (11_receipt.md §8). It lands
  # beside item 20 because it is the same defect wearing the other sign: the
  # pane draws a LABEL, and until now there was no way to see the NAME behind
  # it. Item 20 lets the user filter on what they see; this tells them what they
  # are looking at.
  #
  # ⚠ THE DELAY IS SET TO 0 AND RESTORED (the named-helper rule). `seatipdelay`
  # is a variable for exactly this reason — `balloon` takes the same argument —
  # because a 600 ms wall-clock wait in a suite is a flake generator, while
  # `after 0` is a real trip through the same scheduler.
  set bq_tipwas $::wviewer::seatipdelay
  set ::wviewer::seatipdelay 0
  set bq_tipxy [bs_sea_xy $C 0]
  set bq_tipi [pcall ::wviewer::browser_sea_tip $tok $C \
                 [lindex $bq_tipxy 0] [lindex $bq_tipxy 1]]
  update
  set TIP $C.seatip
  # ⚠⚠ THE LITERAL PAIR IS THE CHECK. `[browser_sea_name $tok 0]` on both sides
  # would be an identity, green on a tip that showed the label; BQ51 already
  # pins this cell as raw `i(v.x1.v1)` drawn as `v1:i`, so the two spellings go
  # in by hand and a tip that showed either the label or nothing reds.
  check {BQ75 hovering a cell posts a tip whose text is the FULL RAW NAME — not
         the label that cell draws} \
    [list $bq_tipi [winfo exists $TIP] [pcall $TIP.txt cget -text] \
          [lindex [bs_sea_labels $C] 0]] \
    [list 0 1 {i(v.x1.v1)} {v1:i}]
  # THE SECOND CELL, because one cell is one cell: a tip that had baked its
  # string at bind time (which is what `balloon` does, and why it could not be
  # reused) would still be showing the first name here.
  set bq_tipxy [bs_sea_xy $C 3]
  set bq_tipi [pcall ::wviewer::browser_sea_tip $tok $C \
                 [lindex $bq_tipxy 0] [lindex $bq_tipxy 1]]
  update
  check {BQ75 ...and it FOLLOWS the pointer to another cell, so the string is
         resolved per hover and not baked at bind time} \
    [list $bq_tipi [pcall $TIP.txt cget -text] [lindex [bs_sea_labels $C] 3]] \
    [list 3 {i(v.x1.vb2)} {vb2:i}]
  # A MISS: past the last cell there is nothing to name, and the tip that WAS up
  # must go. `-1` is the hit-test's own miss value, asserted rather than assumed.
  set bq_tipi [pcall ::wviewer::browser_sea_tip $tok $C 5000 5000]
  update
  check {BQ76 (THE MISS) hovering past the last cell answers -1, posts nothing,
         and takes down the tip that was already up} \
    [list $bq_tipi [winfo exists $TIP] \
          [info exists ::wviewer::seatipidx($tok)]] \
    [list -1 0 0]
  # THE PENDING TIMER IS CANCELLED, and this is the leg that would catch a tip
  # arriving after the pointer left. Scheduled with a delay long enough not to
  # fire, then hidden, then given an `update` it could have fired in.
  set ::wviewer::seatipdelay 100000
  set bq_tipxy [bs_sea_xy $C 0]
  pcall ::wviewer::browser_sea_tip $tok $C [lindex $bq_tipxy 0] [lindex $bq_tipxy 1]
  set bq_tippend [info exists ::wviewer::seatipafter($tok)]
  pcall ::wviewer::browser_sea_tip_hide $tok
  update
  check {BQ77 browser_sea_tip_hide cancels a PENDING tip as well as a posted
         one — the timer really was armed, and nothing arrives after it is
         cancelled} \
    [list $bq_tippend [info exists ::wviewer::seatipafter($tok)] \
          [winfo exists $TIP]] \
    [list 1 0 0]
  set ::wviewer::seatipdelay $bq_tipwas
  check {BQ77 (RESTORED) the hover delay is back to the shipped default, so no
         later check inherits a 0} \
    [list $::wviewer::seatipdelay [expr {$bq_tipwas > 0}]] [list $bq_tipwas 1]

  # --- BQ62: BOTH MENUS DIE WITH THE WINDOW ---------------------------------
  set bq_p [bs_sea_xy $C 0]
  catch {::wviewer::browser_sea_menu_post $tok $C [lindex $bq_p 0] \
           [lindex $bq_p 1] 300 300}
  set bq_tb [pcall $TV bbox {g:x1}]
  if {[llength $bq_tb] == 4} {
    catch {::wviewer::browser_menu_post $tok $TV \
             [expr {[lindex $bq_tb 0] + [lindex $bq_tb 2] / 2}] \
             [expr {[lindex $bq_tb 1] + [lindex $bq_tb 3] / 2}] 300 300}
  }
  set bq_alive [list [winfo exists $bq_seam] [winfo exists $bq_treem]]
  pcall ::wviewer::forget $tok
  catch {destroy .wvbq1}
  update
  check {BQ62 both menus were POSTED and both are destroyed when the window
         closes — the transition, not the end state} \
    [list $bq_alive [list [winfo exists $bq_seam] [winfo exists $bq_treem]]] \
    [list {1 1} {0 0}]
  check {BQ62 ...and forget really dropped the lower pane's four arrays too} \
    [list [info exists ::wviewer::browsersea($tok)] \
          [info exists ::wviewer::browserseaent($tok)] \
          [info exists ::wviewer::browserseasel($tok)] \
          [info exists ::wviewer::browserseaanchor($tok)]] \
    {0 0 0 0}

  catch {dict unset ::wviewer::windows wvbq}
  catch {unset ::wviewer::browsersigs(wvbq)}
  catch {unset ::wviewer::browserrows(wvbq)}
  catch {unset ::wviewer::browserraw(wvbq)}

} else {
  puts "SKIPPED: BQ5x/BQ6x group (Tk/X arm only)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

wvbs_finish
