# tests/headless/test_wave_sigbrowser_0312.tcl — issue 0312: the Signal
# Browser's search bar clipped its own controls, and the sidebar width could
# not be dragged.
# doc/claude/issues/0312-the-signal-browser-search-bar-clips-its-own-controls-and-the-width-is-not-draggable.md
#
# ============================================================================
# ⚠⚠ WHAT SHIPPED BROKEN, AND WHY 353 GREEN CHECKS NEVER SAW IT
# ============================================================================
# `browser_width` sizes the sidebar to `min(bar reqwidth - err reqwidth,
# 0.45 x toplevel)` with a 240 px floor, and `pack propagate $f 0` stops the
# frame growing back. On the shipped 1000 px window the cap wins at 450 px while
# the bar needs ~654, so the packer DROPS the right-hand controls: the error
# label, then `Search`, then `All DBs`. A dropped Tk widget still EXISTS, still
# holds its `-variable` and still answers `invoke` — which is exactly what every
# existing check reads. `winfo ismapped` is the one oracle that separates
# "built" from "on screen", and this file is built around it (BF22 and its
# control BF21b).
#
# The second half is that there was NOTHING to drag: the sidebar is a plain
# frame packed `-side left -fill y -before $top.drw` and its width was whatever
# `browser_width` last wrote. Measured by hand 2026-08-11 (EYEBALL_QUEUE item 5
# RE-RUN): reaching `All DBs` took Ctrl-B, maximise, Ctrl-B, restore.
#
# ============================================================================
# THE TWO HALVES, AND WHY BOTH WERE NEEDED
# ============================================================================
# BG — THE GRIP. A 6 px `$top.wvbgrip` frame packed BETWEEN the sidebar and the
# canvas, dragging the sidebar's width through `browser_width`'s own `want`
# argument. NOT the `ttk::panedwindow` the issue's third candidate proposed:
# that owns its panes, so `.wvbrowser` would stop being a pack slave of the
# toplevel and BS01/BS02/BS24/BS41/BT21 in the FROZEN test_wave_sigbrowser.tcl
# (ruling 30) would go red — five checks in a file that may not be edited, plus
# item 0's `xschem reload` waiver, which was measured on that exact packing.
# BG01/BG02/BG21 are the standing controls for that: the frozen literals and the
# live slave order are RE-ASSERTED here so this file fails first if a later
# editor reaches for the panedwindow again.
#
# BF — THE WRAP. Below its own requirement the bar lays out on TWO ROWS (query
# on top, modifiers below) instead of losing the tail. The threshold is
# `browser_width`'s own arithmetic minus the err label, because a threshold that
# counted err would fire at the shipped width and wrap a bar that is not losing
# anything.
#
# ⚠ NEITHER HALF SUBSUMES THE OTHER, and the arithmetic says why: a live drag
# takes `browser_width`'s SAME 45% cap (BG25), so on a 1000 px window the
# sidebar cannot be dragged past 450 px while the bar needs ~654. The grip
# reaches the NARROW end (EYEBALL_QUEUE item 5 step 7 wants ~250 px); the wrap
# is what makes `All DBs` reachable at the wide end. BF27 is the end-to-end
# check that the shipped default window now shows every control.
#
# ============================================================================
# THE SABOTAGE BATTERY — 39 mutations, RUN, one at a time
# ============================================================================
# Every claim below has an oracle because a mutation that breaks it was applied
# to src/wave_viewer.tcl and the suite re-run. Four findings came OUT of the
# battery and the review it fed, and each is recorded where it landed rather
# than summarised away:
#
#   * S33 (`frame $g -width 0`) was FULLY GREEN across all 57 of the first
#     draft's checks. BG22 said `> 0`, and Tk floors a frame at 1 px, so an
#     unhittable divider passed. BG22 now names a GRABBABLE width.
#   * NO CHECK DROVE A REAL Tk BUTTON EVENT. Every drag check called the three
#     handlers as PROCS, so deleting all three `bind $g` lines left the suite
#     fully green with the divider as undraggable as issue 0312 reported.
#     BG06b (source) and BG33 (a real `event generate` sequence) close it.
#   * S18 STOPPED REDDING when the auto-sizing guard was added — BF26a's plain
#     frame made a DIFFERENT guard answer first, so the unmapped guard could be
#     deleted for free. BF26a's container is now `pack propagate 0` + a width.
#   * BG24 and BG35 each had a wrong PREMISE first time (BG24 widened the
#     toplevel expecting the bar to unwrap — it follows the SIDEBAR; BG35 shrank
#     the window to split `winfo width` from `cget -width` — the cap then
#     clamped both answers to the same number). Both restated with the premise
#     asserted separately.
#
#   S01 grip packs without -before        -> BG02 BG21 BG22 BG33 BG34
#   S02 grip hide is a no-op              -> BG03 BG27 BG28
#   S03 drag grows its own clamp          -> BG04 BG25 BG26 BG35
#   S04 motion tracks absolute x          -> BG23 BG27 BG28 BG33
#   S05 no floor-to-1                     -> BG24
#   S06 release keeps the anchor          -> BG26 BG33
#   S07 release does not store            -> BG27 BG28 BG33
#   S08 pref accepts 0/negatives          -> BG08
#   S10 restore does not own the pref     -> BG32
#   S11 <Configure> never armed           -> BF02 BF27 BF28 BG28 BG29
#   S12 flat does not release the grid    -> BF03 BF24
#   S13 wrapped does not release the pack -> BF03 BF22 BF23
#   S14 requirement counts err            -> BF04 BF20 BF21 BF24 BG24
#   S15 wrapped shows err                 -> BF22 BF23 BF28 BG28 BG29
#   S16 weight on the wrong column        -> BF05
#   S17 no hysteresis band                -> BF25
#   S18 no unmapped guard                 -> BF26
#   S19 layout flag outlives the bar      -> BF06 BF29
#   S20 teardown keeps the preference     -> BG06 BG30
#   S21 grip never shown                  -> BG21
#   S22 grip never hidden                 -> BG27 BG28
#   S23 a pad drifts in the flat layout   -> BF24
#   S24 a dead-token gesture THROWS       -> BG31
#   S25 grip built by browser_build       -> BG20 BG21 BG34
#   S26 no resize cursor                  -> BG22
#   S27 browser_show loses -before        -> BG01 BG21 BG23-29 BG32-34 BF27
#                                            + FROZEN BS01 BS24 BT21 (16 reds)
#   S28 a BT08 literal is re-spelled      -> BG05 + FROZEN BT08
#   S29 unknown token gets a preference   -> BG07 BG23 BG29 BG33
#   S30 wrapped assumes All DBs exists    -> BF28
#   S31 a named proc is renamed           -> BG00 BF04
#   S32 the two wrapped rows are swapped  -> BF23
#   S33 the grip is zero-width            -> BG22
#   S34 the build leaves the bar WRAPPED  -> BF01 BF26 BF30
#   S35 flat packs in the wrong order     -> BF21 BF24
#   S36 the idle flush is unconditional   -> BG07a
#   S37 the derivation ignores the wrap   -> BG07b BG29c
#   S38 browser_build keeps the grip      -> BG07c BG34
#   S40 no auto-sizing guard (the latch)  -> BF30
#   S41 press anchors on winfo width      -> BG35
#   S43 the show ignores the preference   -> BG28 BG32
#
# (S09 and S39 are retired numbers: S09 sabotaged a SEED in `browser_show` that
# the review removed — the derivation is wrap-immune now, so there is nothing to
# seed. Numbers are not reused, so the table cannot silently renumber.)
#
# ⚠ FOUR CHECKS ARE STANDING CONTROLS WITH NO SABOTAGE OF THEIR OWN, which is a
# property of what they assert rather than a gap: BF20a's "the bar is on screen"
# is a PRECONDITION; BF22a reproduces the SHIPPED DEFECT (its "sabotage" is Tk's
# own clipping, which is not ours to break); BF22b asserts the non-pixel oracles
# stay green THROUGH that defect — the explanation for why 353 existing checks
# missed it; and BG07d's second leg ("GH8's sixteen bseq rows are untouched") is
# a no-collateral claim about a file this change deliberately does not edit that
# way. S27 and S28 are the two that matter most: they are the FROZEN file's own
# claims, restated here so a `ttk::panedwindow` reparent lands somewhere that
# can carry the reason.
#
# ============================================================================
# CONVENTIONS — shared with every other browser file (wvbs_common.tcl)
# ============================================================================
# `check`, `check_true`, `pcall`, the counting `::bgerror`, `wvproc_body`,
# `bs_packed`, `bs_order`, `bs_wait_mapped`, `$wsrc` and `wvbs_finish` come from
# wvbs_common.tcl, which is deliberately NOT named `test_*.tcl` (full_audit.sh
# selects with `test_*.tcl`).
#
# GROUP PREFIXES: `BG` (the grip) and `BF` (the bar's flow), neither previously
# used anywhere in tests/headless. Numbers are BLOCKED by arm:
#   01-19  SOURCE and PURE — both arms
#   20-39  live widgets    — X arm only
#
# ⚠ SKIP-BANNER WORDING IS LOAD-BEARING. The X-gated groups print
# `SKIPPED: <group> (Tk/X arm only)`. NEVER `RESULT: SKIP`, never
# `skipped: no X`, never `SKIP: no X connection` — full_audit.sh's `is_skip`
# matches those three and would score the WHOLE FILE as SKIP, silently
# discarding every check that did run.
#
# PROCESS STATE LEFT BEHIND: `.wvbg1` and `.wvbf1` are destroyed, the `wvbg`
# registry entry and its per-token arrays are dropped (BG30 is the check that
# they went), and every bar built here is destroyed with its toplevel. It does
# leave `::bgerror` overridden, in common with the other browser files.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_0312.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_0312.tcl
# (the first is the one that measures the pixels; the second runs BG01-BG08 and
# BF01-BF06 only)

set ::wvbs_tag  wvsigbrowser_0312
set ::wvbs_name test_wave_sigbrowser_0312
source [file join [file dirname [info script]] wvbs_common.tcl]

if {[catch {

# ============================================================================
# BG01-BG08 / BF01-BF06 — SOURCE and PURE arm. Both arms.
# ============================================================================
set g_show  [wvproc_body $wsrc wviewer::browser_show]
set g_grip  [wvproc_body $wsrc wviewer::browser_grip_show]
set g_hide  [wvproc_body $wsrc wviewer::browser_grip_hide]
set g_mot   [wvproc_body $wsrc wviewer::browser_grip_motion]
set g_pref  [wvproc_body $wsrc wviewer::browser_width_pref]
set g_wid   [wvproc_body $wsrc wviewer::browser_width]
set g_forg  [wvproc_body $wsrc wviewer::forget]
set f_build [wvproc_body $wsrc wviewer::searchbar_build]
set f_flat  [wvproc_body $wsrc wviewer::searchbar_pack_flat]
set f_wrap  [wvproc_body $wsrc wviewer::searchbar_pack_wrapped]
set f_need  [wvproc_body $wsrc wviewer::searchbar_need]
set f_ref   [wvproc_body $wsrc wviewer::searchbar_reflow]
set f_forg  [wvproc_body $wsrc wviewer::searchbar_forget]

check {BG00 every proc this file names was found in the source} \
  [list [expr {$g_grip ne {}}] [expr {$g_hide ne {}}] [expr {$g_mot ne {}}] \
        [expr {$g_pref ne {}}] [expr {$f_flat ne {}}] [expr {$f_wrap ne {}}] \
        [expr {$f_need ne {}}] [expr {$f_ref ne {}}]] \
  [list 1 1 1 1 1 1 1 1]

# ⚠⚠ THE ANTI-REPARENT CONTROL, and the reason it is restated in a file that
# does not own it. `test_wave_sigbrowser.tcl` asserts both of these and is
# FROZEN by ruling 30 — so if a later editor swaps the grip for the horizontal
# `ttk::panedwindow` issue 0312 originally proposed, the frozen file goes red
# and cannot be amended. Asserting it HERE too means the failure lands in a file
# that CAN carry the explanation.
check {BG01 browser_show still packs the sidebar into the TOPLEVEL, verbatim,
       exactly once (frozen BS01/BS02's claim, restated)} \
  [list [expr {[string first {pack $f -side left -fill y -before $top.drw} $g_show] >= 0}] \
        [regexp -all {pack \$f -side} $g_show] \
        [regexp -all {pack forget \$f} $g_show]] \
  [list 1 1 1]
check_true {BG02 the grip packs into the same LEFT slot, before the canvas} \
  [expr {[string first {pack $g -side left -fill y -before $top.drw} $g_grip] >= 0}]
# The hide path must not be spelled with `$f`: BS02 counts `pack forget $f`
# inside browser_show and a second one there would red a frozen file.
check {BG03 the grip's hide is spelled against $g, never $f} \
  [list [expr {[string first {pack forget $g} $g_hide] >= 0}] \
        [regexp -all {pack forget \$f} $g_hide]] \
  [list 1 0]
# ⚠ ONE AUTHORITY ON THE CLAMP. The 45% cap and the 240 px floor are inline in
# `browser_width` because BT08 greps them THERE and that file is frozen; a
# second copy in the drag handler would be a second authority and the two would
# drift the first time either was tuned.
check {BG04 the drag handler carries NO cap/floor arithmetic of its own} \
  [list [regexp -all {0\.45} $g_mot] [regexp -all {240} $g_mot] \
        [expr {[string first {wviewer::browser_width $token $want} $g_mot] >= 0}]] \
  [list 0 0 1]
# STANDING CONTROL for BT08's four literals: this change routes a drag THROUGH
# browser_width, so anyone tempted to "simplify" the rule breaks this file too.
check {BG05 browser_width still carries all four of BT08's literals} \
  [list [expr {[string first {pack propagate $f 0} $g_wid] >= 0}] \
        [expr {[string first {[winfo reqwidth $f.wvsearch] -} $g_wid] >= 0}] \
        [expr {[string first {[winfo reqwidth $f.wvsearch.err]} $g_wid] >= 0}] \
        [expr {[string first {0.45 * [winfo width $top]} $g_wid] >= 0}]] \
  [list 1 1 1 1]
# ⚠⚠ THE CHECK THE FIRST DRAFT DID NOT HAVE, AND ITS ABSENCE WAS THE ONE FINDING
# THE ADVERSARIAL REVIEW LANDED. Every BG drag check calls
# `browser_grip_press`/`_motion`/`_drop` AS PROCS. Delete all three `bind $g`
# lines and the procs still clamp, still store, still answer — 57 of 57 green,
# and the divider is exactly as undraggable as issue 0312 reported. This is the
# SOURCE half of closing that hole; BG33 is the live half, and neither is
# sufficient alone (a source grep cannot see a binding Tk never delivers, and a
# live gesture cannot say WHICH sequence carried it).
check {BG06b the three gesture bindings exist, on the right sequences, and pass
       the ROOT x (%X) the delta arithmetic needs} \
  [list [expr {[string first {bind $g <Button-1>        [list wviewer::browser_grip_press $token %X]} $g_grip] >= 0}] \
        [expr {[string first {bind $g <B1-Motion>       [list wviewer::browser_grip_motion $token %X]} $g_grip] >= 0}] \
        [expr {[string first {bind $g <ButtonRelease-1> [list wviewer::browser_grip_drop $token]} $g_grip] >= 0}]] \
  [list 1 1 1]
# ⚠⚠ THE THREE FINDINGS THE Tk-CORRECTNESS REVIEW LANDED, EACH NOW PINNED.
# BG07a: `browser_width`'s `update idletasks` services the idle queue, and
# `on_configure`'s ENTIRE job is to park a `capture_live_view_state` +
# `regenerate` there. A grip drag calls `browser_width` per <B1-Motion>, so an
# unconditional flush ran a full graph regeneration per pixel dragged. The flush
# exists only to make the `reqwidth` read real, which an explicit `want`
# discards anyway — so it belongs on the DERIVING path alone.
check_true {BG07a the idle flush is GATED on the deriving path, so a drag does
            not pump the event loop once per motion event} \
  [expr {[string first {if {![string is integer -strict $want] || $want <= 0} { catch {update idletasks} }} \
                       $g_wid] >= 0}]
# BG07b: the derivation's own input is the bar's reqwidth, and the wrap SHRINKS
# it — so a second show of a wrapped sidebar derived ~180 and floored at 240.
# Fixed AT the derivation rather than papered over with a seeded preference.
check_true {BG07b ...and the derivation ignores the WRAP by asking what the bar
            needs FLAT} \
  [expr {[string first {set w [wviewer::searchbar_need $f.wvsearch]} $g_wid] >= 0}]
# BG07c: a rebuilt sidebar with a surviving packed grip is not merely an orphan
# — the next show packs the sidebar AFTER it, putting the divider on the wrong
# side of the pane it resizes.
check_true {BG07c browser_build destroys the grip with the sidebar it belongs to} \
  [expr {[string first {catch {destroy $top.wvbgrip}} \
                       [wvproc_body $wsrc wviewer::browser_build]] >= 0}]
# ⚠ THE GESTURE IS DOCUMENTED, and it had to be documented WITHOUT `data-bseq`:
# test_wave_grid's GH8/GH9 pair counts those rows against `bind $f.` lines in
# `browser_build`, and the grip is bound on `$g` inside `browser_grip_show`. A
# `data-bseq` row would have demanded a `bind $f.` that does not exist and red
# GH8 in both directions. `data-gseq` documents it and leaves GH8's sixteen
# exactly sixteen — which the second leg asserts, because "I did not disturb the
# ledger" is a claim, not an assumption.
set g_guide {}
catch {
  set gfp [open [file join $repo doc waveform_viewer_guide.html] r]
  set g_guide [read $gfp]; close $gfp
}
check {BG07d the divider drag has a guide row, and GH8's sixteen bseq rows are
       untouched} \
  [list [expr {[string first {data-gseq="wvbgrip &lt;B1-Motion&gt;"} $g_guide] >= 0}] \
        [regexp -all {data-bseq="[^"]+"} $g_guide]] \
  [list 1 16]
check {BG06 the teardown sweep drops BOTH new per-token arrays} \
  [list [expr {[string first {unset browserwidth($token)} $g_forg] >= 0}] \
        [expr {[string first {unset gripdrag($token)} $g_forg] >= 0}]] \
  [list 1 1]

# --- BG07/BG08: the preference accessor, PURE (no widget, no window) ---------
# `0` is "no preference", and it has to be, because that is `browser_width`'s
# own ignore value — `browser_width $token [browser_width_pref $token]` must be
# literally the pre-item-15 derived path on a window nobody chose a width for.
check {BG07 an unknown token has NO width preference} \
  [pcall ::wviewer::browser_width_pref no-such-token-0312] 0
check {BG08 a positive integer is stored and read back; 0, a negative and a
       word are all IGNORED rather than stored} \
  [list [pcall ::wviewer::browser_width_pref bgpure 317] \
        [pcall ::wviewer::browser_width_pref bgpure] \
        [pcall ::wviewer::browser_width_pref bgpure 0] \
        [pcall ::wviewer::browser_width_pref bgpure -5] \
        [pcall ::wviewer::browser_width_pref bgpure wide] \
        [pcall ::wviewer::browser_width_pref bgpure]] \
  [list 317 317 317 317 317 317]
catch {unset ::wviewer::browserwidth(bgpure)}

# --- BF01-BF06: the two layouts, SOURCE and PURE -----------------------------
check {BF01 searchbar_build leaves the bar FLAT and grids nothing itself} \
  [list [expr {[string first {wviewer::searchbar_pack_flat $w} $f_build] >= 0}] \
        [regexp -all {^\s*grid } $f_build]] \
  [list 1 0]
check_true {BF02 the build arms the ONE trigger: <Configure> -> searchbar_reflow} \
  [expr {[string first {bind $w <Configure> [list wviewer::searchbar_reflow $w]} \
                       $f_build] >= 0}]
# ⚠⚠ MANDATORY, NOT DEFENSIVE. Tk refuses `pack` inside a frame that already has
# grid-managed slaves ("cannot use geometry manager pack inside ..."), and vice
# versa. A layout switch that forgets to release the OTHER manager first leaves
# the bar with no managed children at all — an empty strip, strictly worse than
# the clipping this change removes.
check {BF03 each layout releases the other geometry manager before claiming the
       children} \
  [list [expr {[string first {grid forget} $f_flat] >= 0}] \
        [expr {[string first {pack forget} $f_wrap] >= 0}]] \
  [list 1 1]
# The threshold has to be browser_width's own number or the layout fights the
# width rule: the sidebar is sized to hold the bar WITHOUT err (settled decision
# 5), so counting err here would wrap a bar that is losing nothing.
check_true {BF04 the requirement EXCLUDES the error label, exactly as the width
            rule's derivation does} \
  [expr {[string first {if {$c eq {err}} { continue }} $f_need] >= 0}]
check_true {BF05 the wrapped layout weights column 1 only, so the entry is what
            grows and what shrinks} \
  [expr {[string first {grid columnconfigure $w 1 -weight 1} $f_wrap] >= 0}]
check_true {BF06 searchbar_forget drops the layout flag with the bar} \
  [expr {[string first {unset sbwrap($w)} $f_forg] >= 0}]

# ============================================================================
# BG20-BG31 / BF20-BF29 — LIVE WIDGETS. X arm only.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # --- the BF fixture: a bar whose width we own ------------------------------
  # A container with `pack propagate 0` and an explicit width is EXACTLY the
  # sidebar's own situation (browser_width does the same two things), so a
  # width set here reaches the bar the same way the sidebar's does.
  proc bf_width {c w} {
    $c configure -width $w
    update
    return [winfo width [lindex [pack slaves $c] 0]]
  }
  proc bf_mapped {w} {
    set out {}
    foreach c {type pat syntax case alldb search err} {
      if {![winfo exists $w.$c]} { lappend out - ; continue }
      lappend out [expr {[winfo ismapped $w.$c] ? 1 : 0}]
    }
    return $out
  }
  proc bf_slaves {w} {
    return [list [llength [pack slaves $w]] [llength [grid slaves $w]]]
  }

  catch {destroy .wvbf1}
  toplevel .wvbf1
  wm title .wvbf1 {0312 searchbar reflow fixture}
  wm geometry .wvbf1 900x120+60+60
  frame .wvbf1.c -width 800 -height 60
  pack propagate .wvbf1.c 0
  pack .wvbf1.c -side top -fill y
  set BFW [wviewer::searchbar_build .wvbf1.c -command {} -alldbs 1]
  pack $BFW -side top -fill x
  update
  set bf_mapped_ok [bs_wait_mapped $BFW]
  check_true {BF20a the fixture bar is really on screen} [expr {$bf_mapped_ok}]

  set BFNEED [wviewer::searchbar_need $BFW]
  # The measurement itself, recorded rather than assumed: this is the number
  # every threshold check below is expressed against.
  puts "  BF: bar requirement (excluding err) = $BFNEED px"
  check_true {BF20b the requirement is a sane pixel count, not 0 and not the
              whole screen} \
    [expr {$BFNEED > 300 && $BFNEED < 1500}]
  # ⚠⚠ BF04's LIVE TWIN, AND IT IS HERE BECAUSE BF04 ALONE IS SELF-CANCELLING.
  # Every threshold check below asks `searchbar_need` for the number it then
  # tests against, so a `need` that counted the error label would move BOTH
  # sides of those comparisons and stay green. This one compares it against the
  # OTHER authority — the sidebar width rule's own `reqwidth(bar) -
  # reqwidth(err)` — which does not move when `searchbar_need` does. The 12 px
  # tolerance is the pads the two derivations account for differently.
  set bf_wr [expr {[winfo reqwidth $BFW] - [winfo reqwidth $BFW.err]}]
  check_true {BF20c the requirement AGREES with browser_width's own derivation
              (reqwidth of the bar minus the clippable err label)} \
    [expr {abs($BFNEED - $bf_wr) <= 12}]

  # ⚠ THE HEADROOM IS DERIVED, NOT A ROUND NUMBER. `BFNEED` deliberately
  # EXCLUDES `$w.err` (that is the whole of BF04), so "wide enough for every
  # child" is `need + err + a pad`. The first version used a flat `+ 200`, which
  # on this machine left ~20 px of margin over err's ~180 — a wider
  # `AseLabelFont` would have unmapped `err` and reddened BF21b/BF24a for a
  # fixture reason that has nothing to do with the fix.
  set BFWIDE [expr {$BFNEED + [winfo reqwidth $BFW.err] + 40}]
  set bf_w [bf_width .wvbf1.c $BFWIDE]
  check {BF21a wide: the bar really got the width, is FLAT — every child packed, none gridded, and the
         pack order is ViVA §3.2's} \
    [list [expr {$bf_w >= $BFWIDE - 4}] [wviewer::searchbar_wrapped $BFW] \
          [bf_slaves $BFW] [pack slaves $BFW]] \
    [list 1 0 [list 7 0] \
          [list $BFW.type $BFW.pat $BFW.syntax $BFW.case $BFW.alldb \
                $BFW.search $BFW.err]]
  check {BF21b wide: every control is ON SCREEN} [bf_mapped $BFW] \
    [list 1 1 1 1 1 1 1]

  # ⚠⚠ BF21b IS THE SHIPPED DEFECT, REPRODUCED. The <Configure> trigger is
  # unbound so the bar CANNOT reflow, the width is dropped to the shipped
  # sidebar's 450 px, and the flat layout is re-applied by hand. This is what
  # the user saw. Without it BF22 would be a claim about a state nobody proved
  # was ever broken.
  bind $BFW <Configure> {}
  set bf_w450 [bf_width .wvbf1.c 450]
  wviewer::searchbar_pack_flat $BFW
  update
  set bf_broken [bf_mapped $BFW]
  check {BF22a (THE DEFECT) flat at the shipped 450 px: All DBs, Search and the
         error label are BUILT but NOT ON SCREEN} \
    [list [expr {$bf_w450 >= 440 && $bf_w450 <= 455}] $bf_broken] \
    [list 1 [list 1 1 1 1 0 0 0]]
  # ...and the reason no existing check saw it: every non-pixel oracle is happy.
  check {BF22b ...while `winfo exists` and the checkbutton's variable both still
         answer normally — which is why 353 green checks missed this} \
    [list [winfo exists $BFW.alldb] \
          [expr {[info exists ::wviewer::sballdb($BFW)] ? 1 : 0}] \
          [dict exists [wviewer::searchbar_get $BFW] alldbs]] \
    [list 1 1 1]

  bind $BFW <Configure> [list wviewer::searchbar_reflow $BFW]
  # ⚠ THE `update` IS NOT COSMETIC AND IT COST A RED ON THE FIRST RUN: Tk maps
  # newly managed children on the IDLE QUEUE, so reading `winfo ismapped` in the
  # same event-loop turn as the layout switch answers 0 for EVERY child --
  # including the ones that were already on screen. That reads as "the fix maps
  # nothing", which is a different and much more alarming claim than the truth.
  set bf_r [pcall ::wviewer::searchbar_reflow $BFW]
  update
  check {BF22c (THE FIX) reflowed at the SAME 450 px: two rows, and All DBs and
         Search are on screen} \
    [list $bf_r [wviewer::searchbar_wrapped $BFW] [bf_mapped $BFW]] \
    [list 1 1 [list 1 1 1 1 1 1 0]]
  check {BF23a wrapped: the children are GRID-managed, none packed, and the error
         label is the one deliberately withheld} \
    [list [bf_slaves $BFW] [winfo ismapped $BFW.err]] [list [list 0 6] 0]
  # The row split is the claim, not just "two rows exist": query on top,
  # modifiers below.
  check {BF23b wrapped: row 0 is the QUERY, row 1 the MODIFIERS} \
    [list [dict get [grid info $BFW.type] -row] \
          [dict get [grid info $BFW.pat] -row] \
          [dict get [grid info $BFW.syntax] -row] \
          [dict get [grid info $BFW.case] -row] \
          [dict get [grid info $BFW.alldb] -row] \
          [dict get [grid info $BFW.search] -row]] \
    [list 0 0 0 1 1 1]

  # ⚠ UNWRAP FIDELITY. `pack slaves` is what BAR03 asserts on a freshly built
  # bar, so the round trip has to reproduce it EXACTLY — order and all — or a
  # bar that was ever narrow is permanently different from one that never was.
  set bf_w2 [bf_width .wvbf1.c $BFWIDE]
  check {BF24a widened again: back to FLAT, with BAR03's pack order restored
         byte-for-byte} \
    [list [expr {$bf_w2 >= $BFWIDE - 4}] [wviewer::searchbar_wrapped $BFW] \
          [bf_slaves $BFW] [pack slaves $BFW] [bf_mapped $BFW]] \
    [list 1 0 [list 7 0] \
          [list $BFW.type $BFW.pat $BFW.syntax $BFW.case $BFW.alldb \
                $BFW.search $BFW.err] \
          [list 1 1 1 1 1 1 1]]
  # and the pad options survived the round trip, not only the order
  check {BF24b ...including the asymmetric pads the build shipped} \
    [list [dict get [pack info $BFW.type] -padx] \
          [dict get [pack info $BFW.pat] -expand] \
          [dict get [pack info $BFW.search] -padx]] \
    [list {6 4} 1 {0 6}]

  # ⚠⚠ THE OSCILLATION GUARD, and it is a real hazard rather than a theoretical
  # one: on a bar packed `-fill x` into a toplevel that sizes itself to the
  # bar's REQUEST, wrapping shrinks the request, which shrinks the toplevel,
  # which re-fires <Configure>. Inside the band the layout must not move.
  # ⚠ THE ACHIEVED WIDTHS ARE ASSERTED, NOT DISCARDED. "still wrapped at
  # need+8" is ALSO what you get if the resize never reached the bar at all —
  # <Configure> is a real X event and one `update` is not a guarantee under
  # load. Naming the width each leg ran at turns a lost event into a red instead
  # of a silent green.
  set bf_under [bf_width .wvbf1.c [expr {$BFNEED - 4}]]
  set bf_in [wviewer::searchbar_wrapped $BFW]
  set bf_over [bf_width .wvbf1.c [expr {$BFNEED + 8}]]
  check {BF25a the hysteresis band holds: wrapped just under the requirement,
         and still wrapped 8 px over it — it unwraps only past the band} \
    [list [expr {abs($bf_under - ($BFNEED - 4)) <= 4}] $bf_in \
          [expr {abs($bf_over - ($BFNEED + 8)) <= 4}] \
          [wviewer::searchbar_wrapped $BFW]] \
    [list 1 1 1 1]
  set bf_past [bf_width .wvbf1.c [expr {$BFNEED + 40}]]
  check {BF25b ...and past the band it really does go flat again} \
    [list [expr {abs($bf_past - ($BFNEED + 40)) <= 4}] \
          [wviewer::searchbar_wrapped $BFW]] [list 1 0]

  # An unmapped bar has width 1; deciding a layout from that would wrap every
  # bar at build time, before the packer has run once.
  #
  # ⚠⚠ THE CONTAINER HERE IS DELIBERATELY `pack propagate 0` + A WIDTH, AND THE
  # SABOTAGE BATTERY IS WHY. The first version used a plain frame, so BF30's
  # auto-sizing guard declined FIRST and removing the `aw <= 1` guard reddened
  # nothing at all — the check was green on a defect because a different guard
  # was answering. A FIXED container gets past that one, so the unmapped guard
  # is the only thing left standing between this and a bar wrapped at build
  # time.
  frame .wvbf1.hidden -width 800 -height 60
  pack propagate .wvbf1.hidden 0
  set BFH [wviewer::searchbar_build .wvbf1.hidden -command {}]
  pack $BFH -side top -fill x
  check {BF26a reflow DECLINES on a bar in a FIXED container that was never
         mapped, and leaves it flat} \
    [list [expr {[winfo ismapped $BFH] ? 1 : 0}] \
          [pcall ::wviewer::searchbar_reflow $BFH] \
          [wviewer::searchbar_wrapped $BFH] [llength [pack slaves $BFH]]] \
    [list 0 -1 0 6]
  check {BF26b ...and on a widget that is not a searchbar at all} \
    [pcall ::wviewer::searchbar_reflow .wvbf1.c] -1

  # The Filter-bar variant: five children, no All DBs, no Search button. It must
  # wrap on its own terms — its requirement is smaller, so it wraps LATER.
  frame .wvbf1.c2 -width 800 -height 60
  pack propagate .wvbf1.c2 0
  pack .wvbf1.c2 -side top -fill y
  set BFF [wviewer::searchbar_build .wvbf1.c2 -command {} -showbutton 0]
  pack $BFF -side top -fill x
  update
  bs_wait_mapped $BFF
  set BFFNEED [wviewer::searchbar_need $BFF]
  check_true {BF28a the -showbutton 0 variant needs LESS width than the full bar} \
    [expr {$BFFNEED < $BFNEED}]
  set bf_fw [bf_width .wvbf1.c2 [expr {$BFFNEED - 40}]]
  check {BF28b ...and wraps on its own five, keeping all four visible controls} \
    [list [expr {abs($bf_fw - ($BFFNEED - 40)) <= 4}] \
          [wviewer::searchbar_wrapped $BFF] [bf_mapped $BFF] \
          [llength [grid slaves $BFF]]] \
    [list 1 1 [list 1 1 1 1 - - 0] 4]

  # ⚠⚠ BF30 IS THE CASE EVERY OTHER BF CHECK CANNOT SEE, and it was a finding:
  # all the fixtures above pin their container (`pack propagate 0` + a width),
  # which is the sidebar's situation. In a container that sizes itself to its
  # children — the Add Trace dialog's bar, and every bar a test packs straight
  # into a bare toplevel — `winfo width` IS the bar's own request, so wrapping
  # shrinks the request and the unwrap test can never be true again: a ONE-WAY
  # LATCH. It would also let a BAR-band toplevel wrap on its first <Configure>
  # and turn BAR03's `pack slaves` into `{}`. The answer is that a bar whose
  # container propagates is never reflowed at all — a bar that does not fit
  # there simply asks for more room and gets it.
  toplevel .wvbf2
  wm geometry .wvbf2 +90+300
  set BFA [wviewer::searchbar_build .wvbf2 -command {} -alldbs 1]
  pack $BFA -side top -fill x
  update
  bs_wait_mapped $BFA
  wm geometry .wvbf2 380x60+90+300
  for {set i 0} {$i < 40} {incr i} { update ; after 20 }
  check {BF30 a bar in an AUTO-SIZING container is never reflowed, however
         narrow the container gets — no latch, and BAR03's pack slaves survive} \
    [list [pcall ::wviewer::searchbar_reflow $BFA] \
          [wviewer::searchbar_wrapped $BFA] \
          [llength [pack slaves $BFA]] [llength [grid slaves $BFA]]] \
    [list -1 0 7 0]
  catch {destroy .wvbf2}

  check {BF29 destroying a bar drops its layout flag} \
    [list [expr {[info exists ::wviewer::sbwrap($BFF)] ? 1 : 0}] \
          [expr {[catch {destroy $BFF}] ? 1 : 0}] \
          [expr {[info exists ::wviewer::sbwrap($BFF)] ? 1 : 0}]] \
    [list 1 0 0]

  catch {destroy .wvbf1}

  # ==========================================================================
  # BG20-BG31 — THE GRIP, on the item-9 sidebar fixture
  # ==========================================================================
  # 1000x600 is the SHIPPED default window size, deliberately: the whole issue
  # is what the sidebar does at the size users actually get. cap = 450 px.
  catch {destroy .wvbg1}
  toplevel .wvbg1
  wm title .wvbg1 {0312 grip fixture}
  wm geometry .wvbg1 1000x600+60+60
  canvas .wvbg1.drw -background white -width 900 -height 560
  pack .wvbg1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbg [dict create top .wvbg1 win_path .wvbg1.drw]
  update
  bs_wait_mapped .wvbg1.drw

  set BGF .wvbg1.wvbrowser
  set BGG .wvbg1.wvbgrip
  set BGB $BGF.wvsearch
  pcall ::wviewer::browser_build wvbg .wvbg1

  check {BG20 before the sidebar is shown there is no grip at all} \
    [list [winfo exists $BGG] [bs_packed $BGG]] [list 0 0]

  pcall ::wviewer::browser_toggle 1 wvbg
  update
  bs_wait_mapped $BGF

  check {BG21 the grip exists and is packed, and the ORDER is sidebar, grip,
         canvas — the sidebar is STILL a pack slave of the toplevel} \
    [list [winfo exists $BGG] [bs_packed $BGG] \
          [bs_order .wvbg1 $BGF $BGG] [bs_order .wvbg1 $BGG .wvbg1.drw] \
          [bs_order .wvbg1 $BGF .wvbg1.drw] \
          [winfo parent $BGF]] \
    [list 1 1 a-before-b a-before-b a-before-b .wvbg1]
  # ⚠⚠ `>= 4`, NOT `> 0`, AND THE BATTERY IS WHY. The first version of this
  # check said `> 0` and sabotage S33 — building the grip `-width 0` — stayed
  # FULLY GREEN across all 57: Tk floors a frame at 1 px, so an invisible,
  # unhittable divider satisfied `> 0` perfectly. A 1 px target is the same
  # defect issue 0312 is about (there is nothing to grab), so the check has to
  # name a GRABBABLE width, not a non-zero one.
  check {BG22 it is a full-height strip, wide enough to actually grab, with the
         resize cursor} \
    [list [expr {[winfo width $BGG] >= 4 && [winfo width $BGG] <= 12}] \
          [expr {[winfo height $BGG] > 100}] \
          [$BGG cget -cursor]] \
    [list 1 1 sb_h_double_arrow]

  # --- BG23: THE DEFECT'S OTHER HALF, ANSWERED ------------------------------
  # `press` then `motion` is the whole gesture. The sidebar must follow the
  # pointer's DELTA, not jump to its absolute position.
  proc bg_drag {token f x0 dx} {
    pcall ::wviewer::browser_grip_press $token $x0
    pcall ::wviewer::browser_grip_motion $token [expr {$x0 + $dx}]
    update
    return [winfo width $f]
  }
  # The two waits, defined HERE because the first width read below already needs
  # one. `browser_width` reads `winfo width $top`, so every check that asserts a
  # cap has to know the WM has finished with the geometry request.
  proc bg_wait_top {top want {budget 100}} {
    for {set i 0} {$i < $budget} {incr i} {
      update
      if {[winfo width $top] == $want} { return $want }
      after 20
    }
    return [winfo width $top]
  }
  proc bg_wait_flat {bar {budget 100}} {
    for {set i 0} {$i < $budget} {incr i} {
      update
      if {![wviewer::searchbar_wrapped $bar]} { return 0 }
      after 20
    }
    return 1
  }
  # ⚠⚠ THE ONE THAT REPLAYS THE WHOLE Tk SEQUENCE, and the reason it exists is
  # a finding rather than a preference: every OTHER drag check in this file
  # calls the three handlers AS PROCS, so deleting all three `bind $g` lines
  # left 57 of 57 green with the divider as undraggable as issue 0312 reported.
  # Only a real `event generate` on the real widget can see that.
  #
  # ⚠ `-rootx`/`-rooty` ARE NOT OPTIONAL: the handlers are bound with `%X`, the
  # ROOT x, because a delta has to be measured against something that does not
  # move when the widget it is on does. An event generated with `-x` alone
  # delivers `%X` as 0 and the drag jumps.
  # ⚠ MONOTONIC `-time`, the house rule from `bs_sea_click`: Tk's own bindings
  # read the timestamp, and a repeated one can be swallowed as a double.
  proc bg_real_drag {g dx} {
    if {![info exists ::bg_t]} { set ::bg_t 300000 }
    if {[catch {winfo rootx $g} rx]} { return no-widget }
    set ry [expr {[winfo rooty $g] + 40}]
    foreach {ev step} [list <Button-1> 0 <B1-Motion> $dx <ButtonRelease-1> $dx] {
      incr ::bg_t 200
      if {[catch {event generate $g $ev -x [expr {3 + $step}] -y 40 \
                    -rootx [expr {$rx + 3 + $step}] -rooty $ry \
                    -time $::bg_t}]} {
        return nogen
      }
      update
    }
    return ok
  }
  # BG23a reads the width the WM actually gave us, not the one we asked for:
  # `browser_width` computes `0.45 * [winfo width $top]`, so a cap measured
  # while the resize is still in flight is the documented flap
  # (wvbs_common.tcl's bs_wait_widths note), not a finding.
  bg_wait_top .wvbg1 1000
  set bg_w0 [winfo width $BGF]
  puts "  BG: sidebar width at the shipped default = $bg_w0 px"
  check {BG23a the window is really 1000 px and the sidebar starts at its 45%
         cap} \
    [list [winfo width .wvbg1] [expr {$bg_w0 >= 440 && $bg_w0 <= 455}]] \
    [list 1000 1]

  # --- BG33: THE REAL GESTURE, end to end -----------------------------------
  set bg_before [winfo width $BGF]
  set bg_gen [bg_real_drag $BGG -120]
  set bg_after [winfo width $BGF]
  check {BG33a (THE REAL GESTURE) a Button-1 / B1-Motion / ButtonRelease-1
         sequence generated ON THE GRIP WIDGET moves the sidebar by the drag
         delta — the bindings are reachable, not just the procs} \
    [list $bg_gen [expr {$bg_before - $bg_after}]] [list ok 120]
  # ...and the RELEASE in that same real sequence is what left a preference
  # behind, which is the only thing that proves <ButtonRelease-1> is bound at
  # all (BG27a drives `browser_grip_drop` directly and cannot see the binding).
  check {BG33b ...and the real release stored the preference and dropped the
         anchor} \
    [list [pcall ::wviewer::browser_width_pref wvbg] \
          [expr {[info exists ::wviewer::gripdrag(wvbg)] ? 1 : 0}]] \
    [list $bg_after 0]
  catch {unset ::wviewer::browserwidth(wvbg)}
  pcall ::wviewer::browser_width wvbg 450
  update
  # narrower: EYEBALL_QUEUE item 5 step 7 asks for ~250 px, which is the gesture
  # that had no way to happen before this change.
  set bg_narrow [bg_drag wvbg $BGF 500 [expr {250 - $bg_w0}]]
  check {BG23b dragging LEFT narrows the sidebar to the dragged width (item 5
         step 7's ~250 px is now reachable)} \
    [list $bg_narrow [$BGF cget -width]] [list 250 250]
  # ...and the canvas got the space back, which is the half a width read cannot
  # see on its own
  check_true {BG23c ...and the canvas grew by what the sidebar gave up} \
    [expr {[winfo width .wvbg1.drw] > 700}]

  check {BG24a the 240 px FLOOR holds — dragging past the left edge stops there
         rather than collapsing or jumping back to the derived width} \
    [bg_drag wvbg $BGF 500 -800] 240
  # ⚠⚠ BG24 ON ITS OWN CANNOT SEE THE FLOOR-TO-1, AND THAT WAS MEASURED, NOT
  # GUESSED. `browser_width` IGNORES a non-positive `want` and falls back to the
  # DERIVED base — and while the bar is wrapped the derived answer is ALSO 240.
  # Both the fix and the bug read 240 and BG24 is green either way. The
  # discriminating state is a sidebar wide enough for a FLAT bar: the derived
  # answer is then ~651 while the floored answer is still 240, so dragging off
  # the left edge either stops at the floor or jumps RIGHT, past where the drag
  # started.
  #
  # ⚠ AND THE FIRST VERSION OF THIS CHECK GOT THE PREMISE WRONG, MEASURED: it
  # widened the TOPLEVEL and expected the bar to unwrap. The bar's width comes
  # from the SIDEBAR, which was still sitting at the 240 px BG24 had just
  # dragged it to, so it stayed wrapped and the check was red for a reason that
  # had nothing to do with the claim.
  wm geometry .wvbg1 1600x600+60+60
  check {BG24b (THE DISCRIMINATING ONE's PRECONDITION) a 1600 px window with a
         700 px sidebar really does hold the bar FLAT, so the derived width and
         the floor now disagree} \
    [list [bg_wait_top .wvbg1 1600] \
          [pcall ::wviewer::browser_width wvbg 700] \
          [bg_wait_flat $BGB] \
          [expr {[winfo reqwidth $BGB] - [winfo reqwidth $BGB.err] > 400}]] \
    [list 1600 700 0 1]
  check {BG24c (THE DISCRIMINATING ONE) with the two answers apart, dragging off
         the left edge stops at the 240 px floor — it does not jump right to the
         derivation} \
    [bg_drag wvbg $BGF 500 -900] 240
  # back to the shipped size for the cap check, and WAITED FOR: `browser_width`
  # reads `winfo width $top`, so computing the cap while the WM is still
  # delivering the resize gives 720 instead of 450.
  wm geometry .wvbg1 1000x600+60+60
  check {BG24d the window is back at the shipped size before the cap is measured} \
    [list [bg_wait_top .wvbg1 1000] [pcall ::wviewer::browser_width wvbg 450]] \
    [list 1000 450]
  update
  # ⚠ THE CAP CHECK STARTS FROM 300, NOT FROM 450, AND THAT IS THE WHOLE
  # DIFFERENCE BETWEEN A CLAIM AND A COINCIDENCE. Run from a sidebar that is
  # ALREADY 450, "the cap holds" is green on a gesture that did nothing at all —
  # a press that failed its own guard, a motion that rejected its argument.
  # Starting at 300 means only a live gesture that really clamps can answer 450.
  pcall ::wviewer::browser_width wvbg 300
  update
  check {BG25 the 45% CAP holds — a right drag from 300 px stops at 450 on a
         1000 px window, which is browser_width's own clamp} \
    [list [winfo width $BGF] [bg_drag wvbg $BGF 300 900]] [list 300 450]

  # ⚠ WRITTEN AS "AFTER A RELEASE", NOT "WITH NO PRESS EVER", AND THE FIRST
  # VERSION WAS RED FOR THE RIGHT REASON: BG23-BG25 each press without
  # releasing, so an anchor really was still set and the motion really did move
  # the divider. The claim that matters is the one this now makes — a release
  # must CLEAR the anchor, or the sidebar follows the pointer forever after the
  # first drag.
  check {BG26 the RELEASE clears the anchor, so a stray motion afterwards is a
         NO-OP rather than a divider that follows the mouse for good} \
    [list [pcall ::wviewer::browser_grip_drop wvbg] \
          [expr {[info exists ::wviewer::gripdrag(wvbg)] ? 1 : 0}] \
          [pcall ::wviewer::browser_grip_motion wvbg 800] \
          [winfo width $BGF]] \
    [list 450 0 0 450]

  # --- BG27/BG28: the preference, and the Ctrl-B round trip -----------------
  bg_drag wvbg $BGF 500 [expr {320 - [winfo width $BGF]}]
  check {BG27a the RELEASE is what stores the preference, and it stores the
         CLAMPED width the frame really has} \
    [list [pcall ::wviewer::browser_grip_drop wvbg] \
          [pcall ::wviewer::browser_width_pref wvbg]] \
    [list 320 320]
  pcall ::wviewer::browser_toggle 0 wvbg
  update
  check {BG27b hiding the sidebar unpacks the GRIP too — no orphan divider
         against a hidden pane} \
    [list [bs_packed $BGF] [bs_packed $BGG] [winfo exists $BGG]] [list 0 0 1]

  pcall ::wviewer::browser_toggle 1 wvbg
  update
  bs_wait_mapped $BGF
  # ⚠⚠ THE REGRESSION THE PREFERENCE EXISTS FOR, AND IT IS NOT AN ABSTRACTION.
  # `browser_width` derives its base from `[winfo reqwidth $f.wvsearch]`, and
  # the bar in this sidebar IS WRAPPED (450 px < its ~654 requirement), so the
  # derivation now reads a two-row bar and lands UNDER the 240 px floor. Without
  # the stored preference a second show would collapse the sidebar to 240.
  check {BG28a a Ctrl-B/Ctrl-B round trip re-applies the dragged width — it does
         NOT re-derive it from the (now wrapped) bar} \
    [list [winfo width $BGF] [bs_packed $BGG] \
          [bs_order .wvbg1 $BGF $BGG]] \
    [list 320 1 a-before-b]
  # the control for BG28's premise: the bar really IS wrapped here, so the
  # derivation really would be wrong
  check {BG28b (BG28a's PREMISE, measured) the sidebar's own bar is wrapped at
         this width, so its RAW reqwidth would floor at 240 — the dragged 320
         can only have come from the stored preference} \
    [list [wviewer::searchbar_wrapped $BGB] \
          [expr {[winfo reqwidth $BGB] - [winfo reqwidth $BGB.err] < 240}]] \
    [list 1 1]

  # --- BF27: the end-to-end claim, on the real sidebar ----------------------
  # This is the user's bug, at the user's window size, through the real
  # browser_show path: the shipped default must show every control.
  #
  # ⚠⚠ THE WIDTH IS PUT BACK TO 450 AND THEN ASSERTED, and that is a correction:
  # the first version ran straight after BG27's drag, so it measured a
  # hand-dragged 320 px sidebar while its own name claimed "the shipped
  # default". Worse, 320 is BELOW the ~350 px band the source declares as the
  # point where even two rows start to clip — so the check and the declared
  # limit disagreed about what should be visible. 450 is the number the bug was
  # reported at, so 450 is the number this must measure, stated in the tuple
  # rather than assumed.
  pcall ::wviewer::browser_width wvbg 450
  update
  check {BF27 (END TO END) at the shipped default 450 px the sidebar's search
         bar shows All DBs and Search — the controls issue 0312 dropped} \
    [list [winfo width $BGF] [wviewer::searchbar_wrapped $BGB] \
          [winfo ismapped $BGB.alldb] [winfo ismapped $BGB.search] \
          [winfo ismapped $BGB.pat] [winfo ismapped $BGB.type]] \
    [list 450 1 1 1 1 1]

  # --- BG29: the SEED, on a window nobody ever dragged -----------------------
  # ⚠⚠ BG28 PROVES THE DRAG SURVIVES A ROUND TRIP; IT DOES NOT PROVE THE SEED,
  # because the preference it reads was written by a real release. The seed is
  # what protects a sidebar the user never touched at all, and it needs a window
  # with no preference of its own — hence a second toplevel rather than an unset
  # on the first (unsetting mid-life would re-seed from the ALREADY WRAPPED bar,
  # which is the very state the seed exists to avoid, and the check would then
  # pass on a broken build).
  catch {destroy .wvbg2}
  toplevel .wvbg2
  wm title .wvbg2 {0312 seed fixture}
  wm geometry .wvbg2 1000x600+80+80
  canvas .wvbg2.drw -background white -width 900 -height 560
  pack .wvbg2.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbg2 [dict create top .wvbg2 win_path .wvbg2.drw]
  update
  bs_wait_mapped .wvbg2.drw
  set BG2F .wvbg2.wvbrowser
  pcall ::wviewer::browser_build wvbg2 .wvbg2
  check {BG29a a fresh window has NO width preference before its first show} \
    [pcall ::wviewer::browser_width_pref wvbg2] 0
  pcall ::wviewer::browser_toggle 1 wvbg2
  update
  bs_wait_mapped $BG2F
  set bg2_first [winfo width $BG2F]
  # ⚠⚠ AND IT STILL HAS NO PREFERENCE AFTERWARDS. An earlier version of this fix
  # SEEDED the derived answer here, which made "has a preference" and "has been
  # shown" the same fact — and because the seed was the CAPPED answer, a sidebar
  # first shown on a 600 px window stored 270 and stayed 270 on every window
  # size forever, with the user never having touched anything. Absence means
  # nobody chose a width, exactly as `browser_sash_pref`'s does.
  check {BG29b the FIRST show derives 450 and leaves the window with NO
         preference of its own} \
    [list $bg2_first [pcall ::wviewer::browser_width_pref wvbg2]] [list 450 0]
  pcall ::wviewer::browser_toggle 0 wvbg2
  update
  pcall ::wviewer::browser_toggle 1 wvbg2
  update
  bs_wait_mapped $BG2F
  # THE REGRESSION IN ONE LINE: the second show DERIVES again, and the bar it
  # derives from is now on two rows. Unless the derivation asks what the bar
  # needs FLAT, it reads ~180 and the sidebar collapses onto the 240 px floor —
  # a sidebar punished for having once been narrow.
  check {BG29c (THE REGRESSION GUARD) a Ctrl-B/Ctrl-B on a never-dragged,
         WRAPPED sidebar re-derives 450 — it does NOT collapse onto the floor,
         and it still mints no preference} \
    [list [winfo width $BG2F] [wviewer::searchbar_wrapped $BG2F.wvsearch] \
          [pcall ::wviewer::browser_width_pref wvbg2]] \
    [list 450 1 0]
  # the premise, measured on the spot: the RAW reqwidth really would have
  # floored, so BG29c is not green on an arithmetic coincidence
  check {BG29d (BG29c's PREMISE) the wrapped bar's raw reqwidth really is under
         the floor, while what it needs FLAT is not} \
    [list [expr {[winfo reqwidth $BG2F.wvsearch] -
                 [winfo reqwidth $BG2F.wvsearch.err] < 240}] \
          [expr {[wviewer::searchbar_need $BG2F.wvsearch] > 400}]] \
    [list 1 1]

  # --- BG32: a session restore owns the preference too -----------------------
  # `browser_state_apply` sets the width AFTER the show, so without writing the
  # preference as well, the show's seed would win the next round trip and a
  # restored width would evaporate on the first Ctrl-B.
  pcall ::wviewer::browser_state_apply wvbg2 \
    [dict create shown 1 width 300 sash 0 devint 0 srccur 1]
  update
  set bg2_rw [winfo width $BG2F]
  pcall ::wviewer::browser_toggle 0 wvbg2
  update
  pcall ::wviewer::browser_toggle 1 wvbg2
  update
  bs_wait_mapped $BG2F
  check {BG32 a RESTORED width becomes the preference, so it survives hiding and
         re-showing the sidebar} \
    [list $bg2_rw [pcall ::wviewer::browser_width_pref wvbg2] \
          [winfo width $BG2F]] \
    [list 300 300 300]
  catch {destroy .wvbg2}
  catch {pcall ::wviewer::forget wvbg2}
  catch {dict unset ::wviewer::windows wvbg2}

  # --- BG34: a REBUILT sidebar must not leave the divider behind -------------
  # Without `browser_build`'s `destroy $top.wvbgrip` the grip survives PACKED,
  # and the next show packs the sidebar `-before $top.drw` — i.e. AFTER the grip
  # — so the divider ends up on the wrong side of the pane it resizes.
  pcall ::wviewer::browser_build wvbg .wvbg1
  update
  check {BG34 rebuilding the sidebar takes the grip with it} \
    [list [winfo exists $BGG] [bs_packed $BGG]] [list 0 0]
  pcall ::wviewer::browser_toggle 1 wvbg
  update
  bs_wait_mapped $BGF
  check {BG34 ...and the next show puts it back on the RIGHT side, between the
         sidebar and the canvas} \
    [list [bs_packed $BGG] [bs_order .wvbg1 $BGF $BGG] \
          [bs_order .wvbg1 $BGG .wvbg1.drw]] \
    [list 1 a-before-b a-before-b]

  # --- BG35: the anchor is the CONFIGURED width, not the granted one ---------
  # ⚠⚠ THE FIRST VERSION OF THIS CHECK COULD NOT SEE ITS OWN CLAIM, and the
  # measurement is worth keeping. It shrank the WINDOW to make `winfo width` and
  # `cget -width` diverge — but shrinking the window also shrinks the 45% cap,
  # and the cap then clamps both the right anchor and the wrong one to the same
  # number. Anchoring is only observable where the two reads differ AND the
  # clamp does not bind, so the divergence has to be made directly: configure a
  # new width and press before the packer has serviced it. On a 1600 px window
  # the cap is 720 and neither 420 nor 500 goes near it, so the answer is the
  # anchor and nothing else.
  wm geometry .wvbg1 1600x600+60+60
  bg_wait_top .wvbg1 1600
  pcall ::wviewer::browser_width wvbg 420
  update
  $BGF configure -width 500          ;# NO update: the packer has not run yet
  set bg_cfg [$BGF cget -width]
  set bg_got [winfo width $BGF]
  pcall ::wviewer::browser_grip_press wvbg 500
  pcall ::wviewer::browser_grip_motion wvbg 500
  update
  check {BG35 press anchors on the CONFIGURED width: with the two reads 80 px
         apart and the cap far away, a zero-delta drag lands on the configured
         500, not on the granted 420} \
    [list $bg_cfg $bg_got [$BGF cget -width]] [list 500 420 500]
  catch {unset ::wviewer::gripdrag(wvbg)}
  wm geometry .wvbg1 1000x600+60+60
  bg_wait_top .wvbg1 1000
  pcall ::wviewer::browser_width wvbg 450
  update

  # --- BG30/BG31: teardown ---------------------------------------------------
  # ⚠⚠ THE PRESS IS THE POINT, AND WITHOUT IT LEG 4 WAS VACUOUS. The last thing
  # to touch `gripdrag(wvbg)` was a RELEASE, which unsets it — so the "anchor is
  # gone after forget" leg was asserting a post-state identical to its
  # pre-state, and deleting `unset gripdrag($token)` from `wviewer::forget` left
  # it green. A window forgotten MID-DRAG (the user closes the viewer with the
  # button still down) is the real path, so the check now sets that state up and
  # asserts both halves of the pre-state before tearing down.
  pcall ::wviewer::browser_width_pref wvbg 300
  pcall ::wviewer::browser_grip_press wvbg 400
  check {BG30 wviewer::forget drops the width preference AND a live mid-drag
         anchor with the window} \
    [list [expr {[info exists ::wviewer::browserwidth(wvbg)] ? 1 : 0}] \
          [expr {[info exists ::wviewer::gripdrag(wvbg)] ? 1 : 0}] \
          [expr {[catch {wviewer::forget wvbg}] ? 1 : 0}] \
          [expr {[info exists ::wviewer::browserwidth(wvbg)] ? 1 : 0}] \
          [expr {[info exists ::wviewer::gripdrag(wvbg)] ? 1 : 0}]] \
    [list 1 1 0 0 0]
  # a gesture arriving after the window went must ANSWER, not throw — the same
  # rule every other browser accessor keeps
  check {BG31 the three grip gestures answer 0 on a forgotten token instead of
         throwing} \
    [list [pcall ::wviewer::browser_grip_press wvbg 100] \
          [pcall ::wviewer::browser_grip_motion wvbg 100] \
          [pcall ::wviewer::browser_grip_drop wvbg] \
          [pcall ::wviewer::browser_grip_show wvbg] \
          [pcall ::wviewer::browser_grip_hide wvbg]] \
    [list 0 0 0 0 0]

  catch {destroy .wvbg1}
  catch {dict unset ::wviewer::windows wvbg}
  catch {unset ::wviewer::browsersigs(wvbg)}
  catch {unset ::wviewer::browserrows(wvbg)}
  catch {unset ::wviewer::browserwidth(wvbg)}
} else {
  puts "SKIPPED: BF2x group (Tk/X arm only)"
  puts "SKIPPED: BG2x/BG3x group (Tk/X arm only)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

wvbs_finish
