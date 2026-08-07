# tests/headless/test_wave_sigbrowser.tcl — the Signal Browser sidebar,
# PLAN items 8, 9 and 10 (doc/claude/signal_browser_batch/PLAN.md).
#
# ⚠⚠ THIS FILE NO LONGER CARRIES EVERY BROWSER CHECK — DRIVER RULING 30.
# Settled decision 9 originally put items 8-15 here. At 489 checks the file was
# killed mid-run by WSLg with ZERO check failures (measured 2026-08-06: 0 of 9
# completions, against 2 of 4 for the 194-check items-1-7 file in the SAME
# window), which made every later item's verification unmeasurable. Ruling 30
# revised decision 9 and SPLIT the checks BY ITEM RANGE:
#
#   test_wave_sigbrowser.tcl       items 8, 9, 10   BS BT BM   <- THIS FILE
#   test_wave_sigbrowser_i11.tcl   item 11          BH
#   test_wave_sigbrowser_i12.tcl   item 12          BX
#   (items 13-15 create ONE more file; item 13 owns that decision)
#
# ⚠ WHERE THE SPLIT WAS CUT, AND WHY IT WAS CUT THERE. Not by check count — by
# FIXTURE COST, which is the mechanism. In the 8 pre-split runs NOT ONE died
# inside BS, BT or BM; three died inside BH5x and five inside BX4x/BX5x. Those
# two groups are precisely the ones that hold a REAL VIEWER AND THE REAL DESIGN
# WINDOW AT THE SAME TIME, each with its own loaded schematic and hierarchy
# walk. This file keeps the three VIEWER-ONLY items — it opens no design-window
# schematic and never has two live document windows at once — and items 11 and
# 12 get one file each precisely because each is a two-window item.
#
# ============================================================================
# CONVENTIONS — SHARED WITH EVERY OTHER BROWSER FILE (wvbs_common.tcl)
# ============================================================================
# `check`, `check_true`, `pcall`, the counting `::bgerror`, `wvproc_body`,
# `bs_packed`, `bs_order`, `bs_wait_mapped`, `bs_wait_mapped_top`,
# `bs_wait_widths`, `send_key`, `viewer_ready`, `$wsrc` and `wvbs_finish` now
# live in `tests/headless/wvbs_common.tcl`, which every browser file sources.
# It is deliberately NOT named `test_*.tcl`: full_audit.sh selects cases with
# `ls test_*.tcl`, so a shared prelude with that name would be run as a case and
# scored FAIL forever. Item-8-specific helpers (`bs_spy_on`/`bs_spy_off`) stay
# here, with the item that reasons about them.
#
# GROUP PREFIXES: one two-letter prefix per item, never reused.
#     item  8  BS   the sidebar shell (this file's first group)
#     item  9  BT   the browser tree
#     item 10  BM   the row context menu
#     item 11  BH   hierarchy sync, browser -> schematic   (-> _i11.tcl)
#     item 12  BX   hierarchy sync, schematic -> browser   (-> _i12.tcl)
#     item 13  BR   ...
#     item 14  BD   ...
#     item 15  BP   ...
#   Within a prefix the numbers are BLOCKED by arm: 01-19 source/pure (both
#   arms), 20-39 the throwaway-toplevel fixture, 40-59 the REAL viewer.
#
# ⚠ THE ARM STATEMENT, and it is the most important line in this header.
# The `--nogui` arm of this file is SOURCE-LEVEL AND PURE-TCL ONLY. Every
# behavioural claim about the sidebar — that it packs, that it packs BEFORE the
# canvas, that the canvas survives, that the menu entry and the key agree —
# needs real Tk and real X. So A GREEN `--nogui` RUN PROVES NOTHING ABOUT THE
# SIDEBAR. Of item 8's checks, 14 run in both arms and the rest are X-only.
# That split is deliberate, not accidental: `wviewer::open` returns 0 without
# `::has_x`, and `pack`/`winfo` need a display.
#
# ⚠ SKIP-BANNER WORDING IS LOAD-BEARING. The X-gated groups print
# `SKIPPED: <group> group (Tk/X arm only)`. NEVER `RESULT: SKIP`, never
# `skipped: no X`, never `SKIP: no X connection` — full_audit.sh's `is_skip`
# matches those three strings and would score the WHOLE FILE as SKIP, silently
# discarding every check that did run.
#
# ⚠ WIDGET-STATE MASQUERADE — the trap this item was warned about, and the
# answer this file standardises. `pack forget` on a never-packed widget succeeds
# silently; `catch {pack info $w}` reports "not packed" identically for a
# DESTROYED widget and a HIDDEN one; and a frame that was NEVER CREATED also
# yields no packing. Three different defects, one indistinguishable symptom.
# So: `winfo exists` is asserted POSITIVELY in both states (BS20/BS21/BS29),
# `bs_packed` cannot throw, and `bs_order` returns an ASSERTABLE STRING
# (`a-before-b` / `a-after-b` / `a-missing` / `b-missing` / `no-top`) rather
# than a boolean or an exception.
#
# WHAT ITEM 8 DOES NOT CLAIM, stated rather than hidden:
#   * the PIXELS. "the canvas does not jump", "the sidebar width is sane" is
#     EYEBALL-ONLY (receipts/08_receipt.md). BS26/BS27 assert only that the
#     canvas and the sidebar have non-zero width — a regression guard, and
#     explicitly NOT the discriminator for the missing-`-before` sabotage (with
#     a wide toplevel that layout is pixel-identical; the discriminator is
#     BS24's pack-slaves ORDER).
#   * PERSISTENCE. `wviewer::snapshot` is deliberately untouched, so sidebar
#     visibility does not survive a session save/restore. A declared limit item
#     15 inherits, not a defect.
#   * a DIVIDER/SASH. Item 8's content is "a placeholder label only"; none was
#     added, so "the divider is draggable" is NOT APPLICABLE.
#
# PROCESS STATE LEFT BEHIND: the item-8 groups clean up after themselves —
# `.wvbs1` is destroyed and `wviewer::forget wvbs` drops its registry and array
# entries (BS37), the real viewer is closed (BS48 is the check that its arrays
# went with it). It DOES leave `::bgerror` overridden and the shared helpers
# defined. It writes nothing to the tree beyond the standard `test_scratch`
# dir, which `wvbs_finish` removes on its last line.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_sigbrowser.tcl
# (the first is the one that measures anything; the second runs the source and
# pure arms only)

set ::wvbs_tag  wvsigbrowser
set ::wvbs_name test_wave_sigbrowser
source [file join [file dirname [info script]] wvbs_common.tcl]

if {[catch {


# ============================================================================
# BS01-BS09 — SOURCE arm. Runs in BOTH arms: these read src/wave_viewer.tcl and
# doc/waveform_viewer_guide.html as text, so they need neither Tk nor X. They
# are the only item-8 checks a `--nogui` run can honour.
# ============================================================================
# `$wsrc` (src/wave_viewer.tcl as text) is read once by wvbs_common.tcl.
set bs_show [wvproc_body $wsrc wviewer::browser_show]
check_true {BS00 browser_show was found in the source} [expr {$bs_show ne {}}]

# ⚠ THE CHECK THAT GUARDS ITEM 0's WAIVER. Item 0 measured that a sidebar packed
# with EXACTLY this line survives an `xschem reload` on a viewer context
# (receipts/00_precondition.md §3), and that measurement is what waived the
# items-8-15 auto-defer. Any divergence from the line invalidates the waiver.
check_true {BS01 browser_show packs the settled-decision-1 idiom VERBATIM} \
  [expr {[string first {pack $f -side left -fill y -before $top.drw} $bs_show] >= 0}]
check_true {BS02 ...and hides it with a guarded pack forget} \
  [expr {[string first "catch \{pack forget \$f\}" $bs_show] >= 0}]
# the two halves are a PAIR: a show with no hide, or a hide with no show, both
# leave a checkbutton that only works once
check {BS02 exactly one pack and one pack forget in the proc} \
  [list [regexp -all {pack \$f -side} $bs_show] \
        [regexp -all {pack forget \$f} $bs_show]] [list 1 1]

set bs_idb [wvproc_body $wsrc wviewer::install_default_binds]
check_true {BS03 install_default_binds was found in the source} [expr {$bs_idb ne {}}]
check_true {BS03 Ctrl-L is a WaveViewer default and it breaks} \
  [regexp {\n\s*bind WaveViewer <Control-Key-l> \{[^\n]*break\}} $bs_idb]
check_true {BS03 ...behind the rc-wins guard every other default uses} \
  [expr {[string first {if {[bind WaveViewer <Control-Key-l>] eq {}} } $bs_idb] >= 0}]
check_true {BS04 the binding body calls browser_toggle_at with the EVENT's canvas} \
  [regexp {bind WaveViewer <Control-Key-l> \{wviewer::browser_toggle_at %W;} $bs_idb]

set bs_mb [wvproc_body $wsrc wviewer::build_menubar]
check_true {BS05 build_menubar was found in the source} [expr {$bs_mb ne {}}]
# GH3 in test_wave_grid greps for exactly this adjacency; assert it here too so
# a reflow of the source line is attributed to item 8, not to the grid suite
check_true {BS05 the View entry spells -label {Signal Browser} -accelerator Ctrl+L adjacently} \
  [expr {[string first "-label \{Signal Browser\} -accelerator Ctrl+L" $bs_mb] >= 0}]
check_true {BS05 ...on the View cascade, not another one} \
  [regexp {\$mb\.view add checkbutton -label \{Signal Browser\}} $bs_mb]
# BS06 is where a collapse to ONE variable becomes visible: the menu must be
# driven by the MIRROR and must run browser_from_menu, never browser_toggle.
check_true {BS06 the entry's -variable is the browsershow mirror} \
  [expr {[string first {-variable ::wviewer::browsershow($token)} $bs_mb] >= 0}]
check_true {BS06 ...and its -command is browser_from_menu} \
  [expr {[string first {-command [list wviewer::browser_from_menu $token]} $bs_mb] >= 0}]

set bs_forget [wvproc_body $wsrc wviewer::forget]
check_true {BS07 forget was found in the source} [expr {$bs_forget ne {}}]
# DECLARED and UNSET, both: an undeclared `variable` makes the unset address a
# LOCAL array, fail, and be swallowed by its own catch — the exact leak the
# gridshow comment in that proc documents.
check {BS07 forget declares BOTH arrays and unsets BOTH} \
  [list [regexp -all {variable browser;} $bs_forget] \
        [regexp -all {variable browsershow} $bs_forget] \
        [regexp -all {unset browser\(\$token\)} $bs_forget] \
        [regexp -all {unset browsershow\(\$token\)} $bs_forget]] \
  [list 1 1 1 1]

set bs_tog [wvproc_body $wsrc wviewer::browser_toggle]
check_true {BS08 browser_toggle was found in the source} [expr {$bs_tog ne {}}]
# ⚠ COMMENT NARROWED BY ITEM 9 (ruling 17). It used to read "browser_toggle
# changes WIDGET GEOMETRY only ... no context switch", and item 9 made the
# second half untrue OF THE GESTURE: toggling ON now repopulates the tree, and
# that read takes a 0173 context loan. The loan lives ONE LEVEL DOWN, inside
# `wviewer::signal_list`, so the three greps below stay green BY CONSTRUCTION
# rather than by luck — which is exactly the kind of check name that would
# otherwise overstate what is pinned. What this check really pins, and all it
# pins, is that browser_toggle's OWN BODY neither captures, regenerates nor
# switches. The capture/regenerate half is still a live claim: the canvas resize
# already goes <Configure> -> on_configure -> configure_apply, which captures
# AND regenerates, so a second one here would double-fold and double-draw.
check {BS08 browser_toggle's own body neither captures, regenerates nor switches} \
  [list [regexp -all {capture_live_(view|graph)_state} $bs_tog] \
        [regexp -all {wviewer::regenerate} $bs_tog] \
        [regexp -all {switch_ctx} $bs_tog]] [list 0 0 0]
# ...and it logs exactly one replayable line, carrying the RESOLVED state and
# the explicit token (grid_toggle's contract)
check {BS08 exactly one log_action, with the resolved state and the token} \
  [regexp -all {wviewer::log_action \[list wviewer::browser_toggle \$new \$token\]} $bs_tog] 1
# ORDER is load-bearing: the mirror must be pushed before the geometry changes,
# so a <Configure> handler that reads the state during the pack sees the new one
check_true {BS08 the mirror is synced BEFORE browser_show packs} \
  [expr {[string first {wviewer::sync_browser_mirror $token} $bs_tog] <
         [string first {wviewer::browser_show $token} $bs_tog] &&
         [string first {wviewer::sync_browser_mirror $token} $bs_tog] > 0}]

set guide [file join $repo doc waveform_viewer_guide.html]
check_true {BS09 the viewer guide exists} [file isfile $guide]
set fp [open $guide r]; set gsrc [read $fp]; close $fp
# test_wave_grid GH0-GH4 enforce "every shipped key has a guide row and every
# guide row is a shipped key" by COUNT; this names the row so a miss is
# attributed to item 8 rather than read as a grid-suite regression
check_true {BS09 §9.1 carries the Control-Key-l row} \
  [expr {[string first {data-seq="Control-Key-l"} $gsrc] >= 0}]
check_true {BS09 ...with the menu twin and the accelerator it advertises} \
  [expr {[string first {data-menu="Signal Browser" data-accel="Ctrl+L"} $gsrc] >= 0}]

# ============================================================================
# BS10-BS14 — PURE arm. Also both arms: these call the accessors with tokens
# that resolve to nothing, and every one of them must ANSWER rather than throw.
# `pcall` is what makes the difference visible — an `ERR:...` return fails the
# check instead of aborting the file.
# ============================================================================
check {BS10 browser_shown of the empty token is 0, not an error} \
  [pcall ::wviewer::browser_shown {}] 0
check {BS11 browser_shown of an unknown token is 0} \
  [pcall ::wviewer::browser_shown bs_nosuch_token] 0
check {BS12 browser_toggle on an unknown token is a spoken refusal, not a throw} \
  [pcall ::wviewer::browser_toggle {} bs_nosuch_token] {}
check {BS12 ...and it created no array entry for it} \
  [list [info exists ::wviewer::browser(bs_nosuch_token)] \
        [info exists ::wviewer::browsershow(bs_nosuch_token)]] [list 0 0]
# the unknown-token guard fires FIRST, so this pins "refused whatever the want
# word is", not the bad-word branch — that one needs a LIVE token and is BS28.
check {BS13 an unknown token is refused whatever the want word} \
  [pcall ::wviewer::browser_toggle bogus bs_nosuch_token] {}
check {BS14 browser_toggle_at on a canvas in no registry is silent} \
  [pcall ::wviewer::browser_toggle_at .bs_nosuch.drw] {}

# ============================================================================
# BSF — BS20-BS37, the DISPLAY fixture group.
#
# A throwaway toplevel carrying a canvas packed EXACTLY like the real one
# (`-side right -fill both -expand true`, xschem.tcl), registered straight into
# `::wviewer::windows` — the test_wave_sigsearch fixture idiom. No
# `wviewer::open`, no state file, no C context: everything item 8 ships is pure
# Tk geometry, and a fixture with no moving parts is what makes the sabotage
# targets single.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # `bs_wait_mapped` — the item-5 `at_wait_mapped` idiom — now lives in
  # wvbs_common.tcl so the item-11 and item-12 files can reach it too.

  # ⚠ A CALL RECORDER (item 7's ds_spy_* idiom), because "the sidebar ended up
  # packed" and "browser_show ran" are DIFFERENT claims, and only the second one
  # can see a no-op. Both spies DELEGATE (browser_show) or SWALLOW (log_action —
  # deliberately, so the fixture writes nothing to the real action log). Every
  # use below is paired with a NEGATIVE control: a refused or redundant call
  # must record ZERO, which is what stops the recorder passing vacuously.
  proc bs_spy_on {} {
    set ::bs_show_calls {} ; set ::bs_log_calls {}
    rename ::wviewer::browser_show ::wviewer::__bs_real_browser_show
    proc ::wviewer::browser_show {token} {
      lappend ::bs_show_calls $token
      return [::wviewer::__bs_real_browser_show $token]
    }
    rename ::wviewer::log_action ::wviewer::__bs_real_log_action
    proc ::wviewer::log_action {line} { lappend ::bs_log_calls $line }
  }
  proc bs_spy_off {} {
    rename ::wviewer::browser_show {}
    rename ::wviewer::__bs_real_browser_show ::wviewer::browser_show
    rename ::wviewer::log_action {}
    rename ::wviewer::__bs_real_log_action ::wviewer::log_action
  }

  catch {destroy .wvbs1}
  toplevel .wvbs1
  wm title .wvbs1 {item8 signal browser fixture}
  wm geometry .wvbs1 700x420+80+80
  # the REAL packing of the viewer canvas (xschem.tcl): -expand true is what
  # makes -before load-bearing
  canvas .wvbs1.drw -background white -width 600 -height 380
  pack .wvbs1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbs [dict create top .wvbs1 win_path .wvbs1.drw]
  update
  set bs_mapped [bs_wait_mapped .wvbs1.drw]

  # ⚠ "NEVER CREATED" MUST BE DISTINGUISHABLE FROM "CREATED AND HIDDEN".
  # This is the before-picture that makes BS21 mean something.
  check {BS20 before the build the frame does NOT exist, and nothing is packed for it} \
    [list [winfo exists .wvbs1.wvbrowser] [bs_packed .wvbs1.wvbrowser] \
          [bs_order .wvbs1 .wvbs1.wvbrowser .wvbs1.drw]] \
    [list 0 0 a-missing]

  check {BS21 browser_build returns 1} [pcall ::wviewer::browser_build wvbs .wvbs1] 1
  update
  # TWO POSITIVE ASSERTIONS, not one absence: it EXISTS (so this is not BS20's
  # picture again) and it is NOT packed (the geometry-unchanged rule).
  check {BS21 after the build the frame EXISTS and is NOT packed} \
    [list [winfo exists .wvbs1.wvbrowser] [winfo class .wvbs1.wvbrowser] \
          [bs_packed .wvbs1.wvbrowser]] \
    [list 1 Frame 0]
  # ⚠ WIDENED BY ITEM 9, NOT DELETED (ruling 17: widen the coverage or narrow
  # the claim, never neither). Item 8's leg asserted the placeholder was the
  # frame's ONLY child, which filling the sidebar necessarily falsifies. The
  # label SURVIVES — repurposed as item 9's status/error line — so the exists /
  # class / "says what it is" legs are untouched, and the only-child leg becomes
  # an assertion of the FULL item-9 child set, in creation order. That is
  # strictly more coverage: it now also fails if a child is dropped or renamed.
  check {BS22 the placeholder label still exists, is a Label, and is child #1} \
    [list [winfo exists .wvbs1.wvbrowser.ph] [winfo class .wvbs1.wvbrowser.ph] \
          [lindex [winfo children .wvbs1.wvbrowser] 0]] \
    [list 1 Label .wvbs1.wvbrowser.ph]
  # ⚠ WIDENED AGAIN BY ITEM 13, NOT DELETED (ruling 17, and item 9's own
  # precedent eight lines up). Item 13 adds the LOCATION ROW `.loc` to the
  # sidebar, which falsifies any claim that names the item-9 child set — so the
  # SET is extended and the check NAME is corrected with it. A name that says
  # "item 9's set" while pinning item 13's is itself a defect.
  # ⚠ WIDENED A THIRD TIME BY THE TWO-PANE ITEM 9, same rule. `.tvf` is no
  # longer a child of the sidebar at all — it moved INSIDE the new
  # `ttk::panedwindow` `.pw` — and `.opt` (R11's two checkbuttons) is new. This
  # is the batch's ONLY pinned-surface move and it happens exactly once.
  check {BS22 the frame's children are exactly the two-pane set} \
    [lsort [winfo children .wvbs1.wvbrowser]] \
    [lsort [list .wvbs1.wvbrowser.ph .wvbs1.wvbrowser.wvsearch \
                 .wvbs1.wvbrowser.tb .wvbs1.wvbrowser.opt .wvbs1.wvbrowser.pw \
                 .wvbs1.wvbrowser.wvfilter .wvbs1.wvbrowser.loc]]
  check_true {BS22 ...and it says what it is} \
    [expr {[string first {Signal Browser} [.wvbs1.wvbrowser.ph cget -text]] >= 0}]
  check {BS23 a freshly built sidebar is hidden, and the mirror says so} \
    [list [pcall ::wviewer::browser_shown wvbs] $::wviewer::browsershow(wvbs)] \
    [list 0 0]

  # --- BS24: THE PRIMARY ORACLE FOR SABOTAGE (a) -----------------------------
  # `pack info` does NOT report -before, so the SLAVE ORDER is the only thing
  # that can see it. This is the discriminator; BS26/BS27 below are not.
  check {BS24 toggle ON returns the new state} [pcall ::wviewer::browser_toggle 1 wvbs] 1
  update
  check {BS24 the sidebar is packed} [bs_packed .wvbs1.wvbrowser] 1
  check {BS24 and packed BEFORE the canvas in the slave order (-before)} \
    [bs_order .wvbs1 .wvbs1.wvbrowser .wvbs1.drw] a-before-b
  check {BS25 packed to the LEFT, filling the height} \
    [list [dict get [pack info .wvbs1.wvbrowser] -side] \
          [dict get [pack info .wvbs1.wvbrowser] -fill]] \
    [list left y]
  # REGRESSION GUARD, and explicitly NOT the (a) discriminator: with a wide
  # toplevel a sabotaged layout is pixel-identical, so this is predicted to stay
  # green under (a). Its job is to catch a sidebar that eats the canvas.
  check {BS26 the canvas survives the toggle intact} \
    [list [winfo exists .wvbs1.drw] [winfo manager .wvbs1.drw] \
          [expr {[winfo width .wvbs1.drw] > 1}] {ismapped} $bs_mapped] \
    [list 1 pack 1 {ismapped} 1]
  # "the width is sane" made assertable — the PIXEL judgement stays an eyeball.
  # The mapping is carried in the tuple so an unmapped fixture reads as
  # "never mapped" instead of as "the sidebar has no width".
  check {BS27 the sidebar has a real width of its own} \
    [list [bs_wait_mapped .wvbs1.wvbrowser] \
          [expr {[winfo width .wvbs1.wvbrowser] > 1}]] \
    [list 1 1]

  # --- the spies: a positive AND a negative control --------------------------
  bs_spy_on
  check {BS28 a redundant toggle ON returns the state it already had} \
    [pcall ::wviewer::browser_toggle 1 wvbs] 1
  update
  # THE NEGATIVE CONTROL. A no-op must not log and must not re-pack: neither is
  # visible to a state check, because the state is already right.
  check {BS28 ...and it logged nothing and did not re-run browser_show} \
    [list [llength $::bs_log_calls] [llength $::bs_show_calls] \
          [bs_packed .wvbs1.wvbrowser]] \
    [list 0 0 1]
  check {BS28 a refused toggle (bad word) is silent too} \
    [list [pcall ::wviewer::browser_toggle bogus wvbs] \
          [llength $::bs_log_calls] [llength $::bs_show_calls]] \
    [list {} 0 0]
  # THE POSITIVE CONTROL, immediately after, on the same spies: a real change
  # records exactly one of each. Without this pair the zeros above would also be
  # what a dead recorder returns.
  check {BS29 toggle OFF returns 0} [pcall ::wviewer::browser_toggle {} wvbs] 0
  update
  # HIDDEN IS NOT DESTROYED — the other half of the masquerade. The frame and
  # its child must still be there, or the next toggle would have nothing to pack.
  check {BS29 hidden means unpacked, NOT destroyed} \
    [list [bs_packed .wvbs1.wvbrowser] [winfo exists .wvbs1.wvbrowser] \
          [winfo exists .wvbs1.wvbrowser.ph]] \
    [list 0 1 1]
  check {BS30 and the slave order reports a VALUE for the absence, not an error} \
    [bs_order .wvbs1 .wvbs1.wvbrowser .wvbs1.drw] a-missing
  check {BS30 the canvas is still packed and still alive} \
    [list [bs_packed .wvbs1.drw] [expr {[winfo width .wvbs1.drw] > 1}]] [list 1 1]
  check {BS32 exactly one replay line per real change, with state and token} \
    [list [llength $::bs_log_calls] [lindex $::bs_log_calls end]] \
    [list 1 {wviewer::browser_toggle 0 wvbs}]
  check {BS33 browser_show ran exactly once, on this window} \
    [list [llength $::bs_show_calls] [lindex $::bs_show_calls end]] \
    [list 1 wvbs]
  bs_spy_off
  check {BS33 the spies were removed and the real procs are back} \
    [list [expr {[info commands ::wviewer::browser_show] ne {}}] \
          [expr {[info commands ::wviewer::__bs_real_browser_show] eq {}}] \
          [expr {[info commands ::wviewer::log_action] ne {}}] \
          [expr {[info commands ::wviewer::__bs_real_log_action] eq {}}]] \
    [list 1 1 1 1]

  # explicit SET, not invert — the leg that separates `browser_toggle 1` from
  # `browser_toggle {}`
  check {BS31 an explicit 1 sets rather than inverts} \
    [list [pcall ::wviewer::browser_toggle 1 wvbs] \
          [pcall ::wviewer::browser_toggle 1 wvbs] \
          [pcall ::wviewer::browser_shown wvbs]] \
    [list 1 1 1]
  check {BS31 an explicit 0 does too} \
    [list [pcall ::wviewer::browser_toggle 0 wvbs] \
          [pcall ::wviewer::browser_toggle 0 wvbs] \
          [pcall ::wviewer::browser_shown wvbs]] \
    [list 0 0 0]
  update

  # --- BS34: THE PRIMARY ORACLE FOR SABOTAGE (b) -----------------------------
  # ⚠ THE COMMAND ROUTE IS THE ONLY ONE THAT CAN SEE IT, and that asymmetry is
  # the point. On the MENU route Tk writes the mirror ITSELF before -command
  # runs, so a missing sync_browser_mirror is invisible there (BS35/BS43 are
  # predicted to stay green under (b)). Here nothing writes the mirror but the
  # toggle, so the mirror and the authority must be pushed into agreement.
  check {BS34 after a COMMAND toggle ON the menu mirror equals the authority} \
    [list [pcall ::wviewer::browser_toggle {} wvbs] \
          $::wviewer::browsershow(wvbs) [pcall ::wviewer::browser_shown wvbs]] \
    [list 1 1 1]
  check {BS34 ...and after a COMMAND toggle OFF too} \
    [list [pcall ::wviewer::browser_toggle {} wvbs] \
          $::wviewer::browsershow(wvbs) [pcall ::wviewer::browser_shown wvbs]] \
    [list 0 0 0]

  # --- the menu route, driven the way Tk drives it ---------------------------
  # Tk writes the -variable BEFORE running -command, so the fixture writes it by
  # hand and then calls the handler. `browser_from_menu` must SET that value: a
  # plain invert here would double-flip and the menu would look dead.
  set ::wviewer::browsershow(wvbs) 1
  check {BS35 from_menu SETS the mirror's value rather than inverting it} \
    [list [pcall ::wviewer::browser_from_menu wvbs] \
          [pcall ::wviewer::browser_shown wvbs] [bs_packed .wvbs1.wvbrowser]] \
    [list 1 1 1]
  set ::wviewer::browsershow(wvbs) 0
  check {BS35 ...in the other direction too} \
    [list [pcall ::wviewer::browser_from_menu wvbs] \
          [pcall ::wviewer::browser_shown wvbs] [bs_packed .wvbs1.wvbrowser]] \
    [list 0 0 0]
  # a redundant menu invoke is the no-op path again, reached through the menu
  set ::wviewer::browsershow(wvbs) 0
  check {BS35 a menu invoke that asks for the current state is a no-op, not a throw} \
    [pcall ::wviewer::browser_from_menu wvbs] 0

  # a token whose window went away: answer, do not throw, and do not LEAK an
  # array entry into either array on the way out
  set ::wviewer::browsershow(bs_dead_token) 1
  check {BS36 from_menu on a token with no window refuses without throwing} \
    [pcall ::wviewer::browser_from_menu bs_dead_token] {}
  check {BS36 ...and left no authority entry behind} \
    [info exists ::wviewer::browser(bs_dead_token)] 0
  unset ::wviewer::browsershow(bs_dead_token)

  # forget drops BOTH arrays — the gridshow lesson, asserted rather than assumed
  check {BS37 before forget both arrays hold this token} \
    [list [info exists ::wviewer::browser(wvbs)] \
          [info exists ::wviewer::browsershow(wvbs)]] [list 1 1]
  pcall ::wviewer::forget wvbs
  check {BS37 forget drops BOTH arrays} \
    [list [info exists ::wviewer::browser(wvbs)] \
          [info exists ::wviewer::browsershow(wvbs)] \
          [dict exists $::wviewer::windows wvbs]] \
    [list 0 0 0]
  destroy .wvbs1

} else {
  # WORDING IS LOAD-BEARING — see the ⚠ in the file header.
  puts "SKIPPED: BSF group (Tk/X arm only)"
}

# ============================================================================
# BSV — BS40-BS48, the REAL viewer group. `wviewer::open` on the sky130A
# ngspice_state1 fixture, the test_wave_grid recipe verbatim. THIS IS THE
# FIXTURE ITEMS 9-15 INHERIT: a real toplevel, a real menubar, a real canvas
# with a real xschem context behind it.
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

  # `send_key` (WSLg-robust key delivery, test_wave_grid's helper) and
  # `viewer_ready` now live in wvbs_common.tcl — items 11 and 12 use them too.

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check {BS40 wviewer::open returns 1} [pcall ::wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: BSV group (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  # THE DEFAULT IS HIDDEN, and it is load-bearing beyond aesthetics: packing the
  # sidebar shrinks the canvas, which moves viewport_rect / band_geometry /
  # graphbb — the basis of assertions all over the wave suites. Stated as the
  # two claims it really is: the frame EXISTS (so item 9 has something to fill)
  # and it is NOT in the packing order (so nothing moved).
  check {BS40 a fresh viewer HAS the sidebar frame and its placeholder} \
    [list [winfo exists $vtop.wvbrowser] [winfo exists $vtop.wvbrowser.ph]] \
    [list 1 1]
  check {BS40 ...and it is not packed, so the canvas geometry is unchanged} \
    [bs_packed $vtop.wvbrowser] 0
  check {BS41 pack slaves of the viewer toplevel contains no sidebar} \
    [expr {[lsearch -exact [pack slaves $vtop] $vtop.wvbrowser] >= 0}] 0
  check {BS41 the canvas IS a packed slave of it} \
    [expr {[lsearch -exact [pack slaves $vtop] $vdrw] >= 0}] 1
  check {BS41 the browser state seeded by open agrees with the widget} \
    [list [pcall ::wviewer::browser_shown $tok] $::wviewer::browsershow($tok)] \
    [list 0 0]

  # the View-menu twin, found by LABEL (an index would rot the moment the menu
  # grows)
  set vm $vtop.wvmenubar.view
  set vidx -1
  if {[winfo exists $vm]} {
    for {set i 0} {$i <= [$vm index end]} {incr i} {
      if {[catch {$vm entrycget $i -label} lb]} continue
      if {$lb eq {Signal Browser}} { set vidx $i; break }
    }
  }
  check_true {BS42 the View menu has a Signal Browser entry} [expr {$vidx >= 0}]
  if {$vidx >= 0} {
    check {BS42 it is a checkbutton, it advertises Ctrl+L, and it is bound to the mirror} \
      [list [$vm type $vidx] [$vm entrycget $vidx -accelerator] \
            [$vm entrycget $vidx -variable]] \
      [list checkbutton Ctrl+L "::wviewer::browsershow($tok)"]

    # ⚠ `invoke`, NOT `select` (item 4's lesson): `select` writes the variable
    # WITHOUT running -command, which would pin nothing at all.
    $vm invoke $vidx
    update
    check {BS43 invoking the menu entry packs the sidebar before the canvas} \
      [list [pcall ::wviewer::browser_shown $tok] [bs_packed $vtop.wvbrowser] \
            [bs_order $vtop $vtop.wvbrowser $vdrw]] \
      [list 1 1 a-before-b]
    check {BS43 the mirror agrees after the menu route} \
      [expr {$::wviewer::browsershow($tok)}] 1

    # the canvas AND the C context behind it survive the resize
    xschem new_schematic switch $vdrw
    check {BS44 the canvas is alive, packed and non-zero after the toggle} \
      [list [winfo exists $vdrw] [winfo manager $vdrw] \
            [expr {[winfo width $vdrw] > 1}] [expr {[winfo height $vdrw] > 1}]] \
      [list 1 pack 1 1]
    check {BS44 the viewer's xschem context still answers, and is unmodified} \
      [list [string is integer -strict [pcall xschem get graph_rects]] \
            [pcall xschem get modified]] \
      [list 1 0]
  }

  # the binding seam, the TG15 four-part shape
  check {BS45 Ctrl-L is on the WaveViewer tag by default} \
    [expr {[bind WaveViewer <Control-Key-l>] ne {}}] 1
  check_true {BS45 it calls browser_toggle_at with the event's canvas} \
    [string match {*wviewer::browser_toggle_at %W*} [bind WaveViewer <Control-Key-l>]]
  check_true {BS45 and it breaks, so the chord never travels on} \
    [string match {*break*} [bind WaveViewer <Control-Key-l>]]
  wviewer::strip_bindings $vdrw
  check_true {BS45 it survives the strip_bindings sweep} \
    [expr {[bind WaveViewer <Control-Key-l>] ne {}}]
  check {BS45 Ctrl-L is NOT bound on the canvas widget itself} \
    [bind $vdrw <Control-Key-l>] {}

  # A REAL Ctrl-L. ⚠ THIS CANNOT BE A HARD ORACLE: its only signal is "did the
  # state change", which cannot tell a WSLg key-delivery stall from a broken
  # binding. So it SELF-SKIPS with a printed line, and the hard oracle for the
  # mirror stays BS34 (the command route). Two presses, which also puts the
  # window back where the menu legs left it.
  set bs_start [pcall ::wviewer::browser_shown $tok]
  set bs_del [send_key $vdrw <Control-Key-l> \
                {[wviewer::browser_shown $tok] != $bs_start}]
  if {!$bs_del} {
    puts "SKIPPED: BS46 real-key leg (Ctrl-L delivery never confirmed)"
  } else {
    update
    check {BS46 a REAL Ctrl-L flipped the sidebar and the mirror together} \
      [list [pcall ::wviewer::browser_shown $tok] $::wviewer::browsershow($tok) \
            [bs_packed $vtop.wvbrowser]] \
      [list [expr {!$bs_start}] [expr {!$bs_start}] [expr {!$bs_start}]]
    send_key $vdrw <Control-Key-l> {[wviewer::browser_shown $tok] == $bs_start}
    update
    check {BS46 ...and a second press put it back} \
      [list [pcall ::wviewer::browser_shown $tok] $::wviewer::browsershow($tok)] \
      [list $bs_start $bs_start]
  }

  if {$vidx >= 0} {
    $vm invoke $vidx
    update
    # hidden again — and STILL NOT DESTROYED, the masquerade check on the real
    # widget tree this time
    check {BS47 invoking again unpacks it, and the frame survives} \
      [list [pcall ::wviewer::browser_shown $tok] [bs_packed $vtop.wvbrowser] \
            [winfo exists $vtop.wvbrowser] [winfo exists $vtop.wvbrowser.ph] \
            [expr {$::wviewer::browsershow($tok)}]] \
      [list 0 0 1 1 0]
    check {BS47 the canvas came back to a full-width packed slave} \
      [list [bs_packed $vdrw] [expr {[winfo width $vdrw] > 1}] \
            [bs_order $vtop $vtop.wvbrowser $vdrw]] \
      [list 1 1 a-missing]
  }

  check {BS48 closing the viewer returns 1} [pcall ::wviewer::close $tok] 1
  check {BS48 ...and both browser arrays went with it} \
    [list [info exists ::wviewer::browser($tok)] \
          [info exists ::wviewer::browsershow($tok)]] \
    [list 0 0]
  }

} else {
  puts "SKIPPED: BSV group (Tk/X arm only)"
}

# ############################################################################
# BT — PLAN item 9, the browser CONTENT: tree + search + filter + the three
# plot gestures. Appended per settled decision 9; conventions inherited from
# the item-8 header above (pcall, the counting ::bgerror, bs_wait_mapped,
# bs_order, send_key, wvproc_body, the `SKIPPED: <group> (Tk/X arm only)`
# wording, and the 01-19 / 20-39 / 40-59 arm blocking).
#
# ⚠ THE TWO MASQUERADE TRAPS THIS GROUP IS BUILT AROUND.
#  1. THE TREE. "never built", "built and empty" and "correctly filtered to
#     zero rows" are three different states and a row COUNT cannot tell them
#     apart. `bt_tree` therefore returns an ASSERTABLE STRING with three
#     distinct shapes — `no-tree`, `empty`, or the depth-first `id|text` row
#     list — never a number.
#  2. THE AND. An AND whose second term is ignored is indistinguishable from
#     one whose second term matches everything. The fixture is chosen so that
#     search-alone, filter-alone and the AND give THREE DIFFERENT ANSWERS
#     (4 / 3 / 2 names), and all three are asserted BY NAME. A filter-ignored
#     break reads 4, a search-ignored break reads 3.
# ############################################################################

# depth-first `id|text` rows, parent immediately before its children. NOT a
# count, by design (see trap 1).
proc bt_flat {tv node} {
  set out {}
  foreach c [$tv children $node] {
    lappend out "$c|[$tv item $c -text]"
    foreach s [bt_flat $tv $c] { lappend out $s }
  }
  return $out
}
proc bt_tree {tv} {
  if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
  if {[catch {$tv children {}} kids]} { return no-tree }
  if {![llength $kids]} { return empty }
  return [bt_flat $tv {}]
}

# ============================================================================
# ⚠⚠ ITEM 10 MOVED THE DISCRIMINATOR TWICE, NOT ONCE.
# ============================================================================
# (1) The TREE stopped varying: leaf rows never enter it (R1/R3) and a single
#     `g:` design root sits on top (R2), so ALL / SEARCH / FILTER / AND all draw
#     the same four nodes. `bt_tree` alone is now a control that cannot fail.
# (2) The ROW MODEL stopped varying TOO, and this is the part it is easy to get
#     wrong: `browser_refresh` no longer feeds the bar-matched `$names` into
#     `browser_rows` — it feeds `$browsersigs($token)`, the BAR-UNFILTERED
#     inventory, on purpose (spec §7.1: "the tree's node set is derived from the
#     unfiltered inventory ... a pattern that matches nothing leaves the tree
#     intact and the sea of names empty"). So `browserrows` is CONSTANT across
#     the four bar states.
#
# WHAT IS LEFT THAT VARIES, and therefore what trap 2's oracle has to become:
#   * the STATUS LINE count — `[llength $names] of $total signals`, computed
#     from the bar-matched set, mirrored through browser_status as
#     "Signal Browser\n<msg>"; 8 / 4 / 3 / 2 on this fixture;
#   * `wviewer::browser_match`, which re-reads BOTH live searchbars through
#     searchbar_get and answers {ok <names>} / {err <msg>} — the by-NAME oracle
#     the display arm lost, and NOT a back door: it is the exact proc
#     browser_refresh itself calls.
# ⚠ THE LOWER PANE IS NOT AN ORACLE. It is empty until item 11.

# The ROW MODEL's surviving leaf names. Item 10 makes this BAR-INDEPENDENT, and
# that invariant is worth pinning: feeding `browser_tree_rows`' projection into
# `browserrows` is named in the source as "the single most likely wrong edit in
# the batch", and it would read here as `no-leaves` while every tree check
# stayed green.
#   no-rows    the token has no row list at all (never built, or forgotten)
#   no-leaves  a row list that survived with ZERO leaves — the projection leak
#   <names>    the surviving raw names, in browser_rows' raw-file order (D7)
proc bt_leaves {token} {
  if {![info exists ::wviewer::browserrows($token)]} { return no-rows }
  set out {}
  foreach r $::wviewer::browserrows($token) {
    if {[wviewer::dget $r kind {}] ne {leaf}} { continue }
    lappend out [wviewer::dget $r name {}]
  }
  if {![llength $out]} { return no-leaves }
  return $out
}

# The ROW MODEL's kind for one id, with the two absences kept APART — "there is
# no row list" and "the row list has no such id" are different defects.
#   no-rows / absent / group / leaf
proc bt_kind {token id} {
  if {![info exists ::wviewer::browserrows($token)]} { return no-rows }
  set k [wviewer::browser_kind $::wviewer::browserrows($token) $id]
  if {$k eq {}} { return absent }
  return $k
}

# THE SURVIVING BAR-STATE ORACLE, as an assertable string. browser_status writes
# "Signal Browser\n<msg>", so the count is extracted rather than string-matched,
# and the three non-count states stay distinguishable from each other.
#   no-label / blank / "N of M" / "no-count: <text>"
proc bt_count {w} {
  if {[catch {$w cget -text} t]} { return no-label }
  if {$t eq {}} { return blank }
  if {[regexp {([0-9]+) of ([0-9]+) signals} $t - a b]} { return "$a of $b" }
  return "no-count: $t"
}

# Every id in the TREE, depth-first. ⚠ DELIBERATELY NOT `browser_tree_nodes`:
# item 10 rewrote that proc (it used to answer only rows WITH CHILDREN) and a
# check that walks the tree with the very proc under test cannot see it regress.
proc bt_ids {tv {node {}}} {
  set out {}
  if {[catch {$tv children $node} kids]} { return {} }
  foreach c $kids {
    lappend out $c
    foreach s [bt_ids $tv $c] { lappend out $s }
  }
  return $out
}

# How many children a row has, with "no such row" kept apart from a count.
# ⚠ A BARE `[llength [$tv children g:]]` THROWS when the root is missing, and an
# unguarded throw here hits the file's outer catch and deletes every later check.
#   absent / unreadable / <integer>
proc bt_nkids {tv id} {
  if {[catch {$tv exists $id} ex] || !$ex} { return absent }
  if {[catch {$tv children $id} k]} { return unreadable }
  return [llength $k]
}

# The DISTINCT kinds the tree's rows have IN THE ROW MODEL. Item 10's R1/R3
# makes `group` the only possible answer; a leaf that leaked back into the upper
# pane reads `{group leaf}`, and a widget row the model does not know reads
# `{absent group}`. `no-tree-rows` keeps "the tree is empty" apart from both.
proc bt_tree_kinds {tv token} {
  set ids [bt_ids $tv]
  if {![llength $ids]} { return no-tree-rows }
  set out {}
  foreach id $ids { lappend out [bt_kind $token $id] }
  return [lsort -unique $out]
}

# ONE bar state's whole signature: what the pane DRAWS, what the model KEPT,
# what the status line COUNTED, and what the two LIVE bars matched by name.
# The last two are the only elements that vary in item 10 — the first two are
# carried so that a future item which DOES make them vary keeps this control
# honest without another rewrite.
proc bt_sig {tv token lbl} {
  return [list [bt_tree $tv] [bt_leaves $token] [bt_count $lbl] \
               [pcall ::wviewer::browser_match $token]]
}

# N values -> `distinct:N`, or `collision: <the repeated value>`. An assertable
# string, never a count of uniques: the failure line has to say WHICH two states
# collapsed onto each other.
proc bt_distinct {args} {
  set seen {}
  foreach v $args {
    if {[lsearch -exact $seen $v] >= 0} { return "collision: $v" }
    lappend seen $v
  }
  return "distinct:[llength $args]"
}

# THE fixture inventory, shared by the pure and the fixture arms so the three
# AND answers are the same numbers everywhere.
set BTFIX {v(out) v(out2) v(x1.x2.net5) v(x1.y3.net5) i(x1.x2.net5) i(v1) net1 vsweep}
proc bt_ents {names} {
  set out {}
  foreach n $names { lappend out [wviewer::signal_entry $n] }
  return $out
}
proc bt_d {pat {syn shell} {case 0} {type all}} {
  return [dict create pattern $pat syntax $syn case $case type $type]
}

# ============================================================================
# BT01-BT09 — SOURCE arm, BOTH arms. `wsrc` was read by the BS group above.
# ============================================================================
set bt_and [wvproc_body $wsrc wviewer::browser_and]
check_true {BT01 browser_and was found in the source} [expr {$bt_and ne {}}]
# ⚠ THE TARGET OF SABOTAGE (a). The AND *IS* the chaining: the second bar must
# filter the FIRST bar's OUTPUT. `[lindex $r1 1]` as the second call's input is
# the whole claim, and `$sigs` must appear as an INPUT exactly once.
check_true {BT01 the second sig_match takes the FIRST one's output as its input} \
  [expr {[string first {browser_match_one [lindex $r1 1] $d2} $bt_and] >= 0}]
check {BT01 ...and the ORIGINAL list is the input of the first call only} \
  [regexp -all {browser_match_one \$sigs} $bt_and] 1
check_true {BT01 an err from either bar short-circuits (decision 4, no match-all)} \
  [expr {[string first {if {[lindex $r1 0] ne {ok}} { return $r1 }} $bt_and] >= 0}]
# nothing re-implements matching (the :1465 rule)
set bt_one [wvproc_body $wsrc wviewer::browser_match_one]
check {BT01 the matcher itself is sig_match, called once, never re-implemented} \
  [list [regexp -all {wviewer::sig_match} $bt_one] \
        [regexp -all {string match} $bt_one] [regexp -all {regexp } $bt_one]] \
  [list 1 0 0]

set bt_rows [wvproc_body $wsrc wviewer::browser_rows]
check_true {BT02 browser_rows was found in the source} [expr {$bt_rows ne {}}]
# ⚠ THE TARGET OF SABOTAGE (c). One group row per dot SEGMENT of the path, the
# prefix accumulated as it walks (ruling 14's tree: x1 > x2 > net5).
check_true {BT02 groups are minted per dot SEGMENT, over a growing prefix} \
  [expr {[string first {foreach seg [split $path .]} $bt_rows] >= 0 &&
         [string first {set pfx [expr {$pfx eq {} ? $seg : "$pfx.$seg"}]} $bt_rows] >= 0}]
check_true {BT02 ...and each new segment becomes the next row's parent} \
  [expr {[string first {set parent $gid} $bt_rows] >= 0}]
check_true {BT02 the flat clause keys off "no entry has a path"} \
  [expr {[string first {if {$anypath && $path ne {}}} $bt_rows] >= 0}]

check_true {BT03 group ids carry the g: prefix and leaf ids the s: prefix} \
  [expr {[string first {set gid "g:$pfx"} $bt_rows] >= 0 &&
         [string first {set id "s:$name"} $bt_rows] >= 0}]
# MANDATORY, not defensive: a duplicate treeview id THROWS, and this rides the
# searchbar <KeyRelease> pump where a throw becomes a modal bgerror under X.
check_true {BT03 the de-dup guard loops until the id is free} \
  [expr {[string first {while {[info exists seen($cand)]}} $bt_rows] >= 0}]

set bt_build [wvproc_body $wsrc wviewer::browser_build]
check_true {BT04 browser_build was found in the source} [expr {$bt_build ne {}}]
# ⚠ THE TARGET OF SABOTAGE (b).
check {BT04 the tree binds Button-2 (MMB) exactly once, to browser_plot_at} \
  [regexp -all {bind \$f\.pw\.tvf\.tv <Button-2>} $bt_build] 1
check {BT04 ...and Double-Button-1 exactly once, to the same proc} \
  [regexp -all {bind \$f\.pw\.tvf\.tv <Double-Button-1>} $bt_build] 1
# the GROUPS flag is what makes the two gestures differ (D3): MMB plots a
# group's leaves, a double-click leaves the group to ttk's expand/collapse
check_true {BT04 double-click passes groups=0 and MMB groups=1} \
  [expr {[string first {browser_plot_at $token %W %x %y 0} $bt_build] >= 0 &&
         [string first {browser_plot_at $token %W %x %y 1} $bt_build] >= 0}]

check_true {BT05 the TOP bar keeps its Search button (ruling 20)} \
  [regexp {searchbar_build \$f -command \[list wviewer::browser_search_cb} $bt_build]
check_true {BT05 the BOTTOM bar is the -showbutton 0 Filter variant, named wvfilter} \
  [expr {[string first {searchbar_build $f -name wvfilter -showbutton 0} $bt_build] >= 0}]
check {BT05 both bars are packed -fill x (item 4's stated requirement)} \
  [list [regexp -all {pack \$f\.wvsearch -side top -fill x} $bt_build] \
        [regexp -all {pack \$f\.wvfilter -side bottom -fill x} $bt_build]] \
  [list 1 1]
check_true {BT05 the filter bar's callback is the filter one, not the search one} \
  [expr {[string first {wviewer::browser_filter_cb $token} $bt_build] >= 0}]

# ruling 24: plot_dest is THE destination accessor and nothing re-implements the
# policy. All three gestures funnel into plot_signals, which owns it.
set bt_pids [wvproc_body $wsrc wviewer::browser_plot_ids]
set bt_psel [wvproc_body $wsrc wviewer::browser_plot_selection]
set bt_pat  [wvproc_body $wsrc wviewer::browser_plot_at]
check_true {BT06 all three gesture procs were found in the source} \
  [expr {$bt_pids ne {} && $bt_psel ne {} && $bt_pat ne {}}]
check {BT06 exactly one plot_signals call, in browser_plot_ids} \
  [list [regexp -all {wviewer::plot_signals} $bt_pids] \
        [regexp -all {wviewer::plot_signals} $bt_psel] \
        [regexp -all {wviewer::plot_signals} $bt_pat]] \
  [list 1 0 0]
check {BT06 the Plot button and both click gestures route through browser_plot_ids} \
  [list [regexp -all {wviewer::browser_plot_ids} $bt_psel] \
        [regexp -all {wviewer::browser_plot_ids} $bt_pat]] \
  [list 1 1]
check {BT06 NOTHING in the browser re-reads plot_dest, plan_plot or dest_prepare} \
  [list [regexp -all {plot_dest|plan_plot|dest_prepare} $bt_pids] \
        [regexp -all {plot_dest|plan_plot|dest_prepare} $bt_psel] \
        [regexp -all {plot_dest|plan_plot|dest_prepare} $bt_pat] \
        [regexp -all {plot_dest|plan_plot|dest_prepare} $bt_build]] \
  [list 0 0 0 0]

set bt_ref [wvproc_body $wsrc wviewer::browser_refresh]
check_true {BT07 browser_refresh was found in the source} [expr {$bt_ref ne {}}]
# it rides BOTH searchbars' <KeyRelease> pump: a throw there is bgerror, which
# is modal under X and HANGS a headless run (add_trace_filter's discipline)
check {BT07 browser_refresh raises nothing itself} \
  [list [regexp -all {return -code error} $bt_ref] [regexp -all {\n\s*error } $bt_ref]] \
  [list 0 0]
check {BT07 ...and every throwing call it makes is catch-wrapped} \
  [list [regexp -all {catch \{wviewer::browser_match} $bt_ref] \
        [regexp -all {catch \{wviewer::browser_rows} $bt_ref] \
        [regexp -all {catch \{wviewer::browser_populate} $bt_ref] \
        [regexp -all {catch \{wviewer::browser_reload} $bt_ref]] \
  [list 1 1 1 1]
# decision 4's second display surface: the bar's own err label is the first
# thing to clip in a sidebar this narrow, so the message is mirrored here
check {BT07 an err HOLDS the tree and writes the message to the status line} \
  [regexp -all {browser_status \$token \[lindex \$r 1\]} $bt_ref] 1
check {BT07 forget declares AND unsets both item-9 arrays} \
  [list [regexp -all {variable browsersigs; variable browserrows} $bs_forget] \
        [regexp -all {unset browsersigs\(\$token\)} $bs_forget] \
        [regexp -all {unset browserrows\(\$token\)} $bs_forget]] \
  [list 1 1 1]

set bt_show [wvproc_body $wsrc wviewer::browser_show]
set bt_wid  [wvproc_body $wsrc wviewer::browser_width]
check_true {BT08 browser_width was found in the source} [expr {$bt_wid ne {}}]
# MEASURED: with propagation ON a 700 px toplevel gave sidebar 700 AND canvas
# 700 — a broken layout, not a narrow one.
check_true {BT08 the width rule turns pack propagation OFF} \
  [expr {[string first {pack propagate $f 0} $bt_wid] >= 0}]
check_true {BT08 ...derives the width from the bar MINUS the clippable err label} \
  [expr {[string first {[winfo reqwidth $f.wvsearch] -} $bt_wid] >= 0 &&
         [string first {[winfo reqwidth $f.wvsearch.err]} $bt_wid] >= 0}]
check_true {BT08 ...and caps it so the sidebar cannot eat the canvas} \
  [expr {[string first {0.45 * [winfo width $top]} $bt_wid] >= 0}]
check_true {BT08 sizing runs from browser_show's PACK branch} \
  [expr {[string first {wviewer::browser_width $token} $bt_show] >= 0}]
# browser_build must stay geometry-neutral or item 8's BS21 stops meaning
# anything ("built but not packed, nothing moved")
check {BT08 browser_build changes no geometry of its own} \
  [list [regexp -all {pack propagate} $bt_build] \
        [regexp -all {pack \$f } $bt_build]] [list 0 0]
check_true {BT08 showing the sidebar repopulates it} \
  [expr {[string first {wviewer::browser_refresh $token 1} $bt_show] >= 0}]

# BT09 — the GH0 no-bump claim, ASSERTED rather than assumed. Item 9 adds no
# key and no menu entry, so test_wave_grid's two hard-coded literals (15 guide
# rows / 10 documented menu accelerators) need no bump.
set bt_bodies [list $bt_build $bt_rows $bt_and $bt_one $bt_ref $bt_pids \
                    $bt_psel $bt_pat $bt_wid $bt_show]
set bt_binds 0; set bt_menus 0
foreach b $bt_bodies {
  incr bt_binds [regexp -all {bind WaveViewer} $b]
  incr bt_menus [regexp -all {\$mb\.[a-z]+ add } $b]
}
check {BT09 item 9 adds no WaveViewer key binding and no menu entry} \
  [list $bt_binds $bt_menus] [list 0 0]
set bt_seqs [regexp -all {data-seq="[^"]+"} $gsrc]
set bt_accs [regexp -all {data-menu="[^"]+" data-accel="[^"]+"} $gsrc]
# ⚠ REWRITTEN BY ITEM 11, which DOES add a key and a menu entry (`E` /
# View > Descend to here) and so DID bump test_wave_grid's two literals to
# 16/11. The item-9 leg above is UNTOUCHED — it still says item 9's own bodies
# contribute zero — and the leg below now pins WHERE the one addition came
# from, so this check cannot be quietly satisfied by some third key appearing.
check {BT09 ...so the guide carries GH0's sixteen keys and eleven accelerators} \
  [list $bt_seqs $bt_accs] [list 16 11]
set bt_i11 [wvproc_body $wsrc wviewer::install_default_binds]
set bt_m11 [wvproc_body $wsrc wviewer::build_menubar]
# count bind STATEMENTS only (test_wave_grid GH2's rule): each one sits under an
# `if {[bind WaveViewer <seq>] eq {}}` rc-wins guard that names the same words.
set bt_nb 0; set bt_ne 0
foreach bt_l [split $bt_i11 "\n"] {
  if {[regexp {^\s*bind WaveViewer <} $bt_l]} { incr bt_nb }
  if {[regexp {^\s*bind WaveViewer <Key-E>} $bt_l]} { incr bt_ne }
}
check {BT09 ...and the ONE bump is item 11's <Key-E> / `Descend to here`, nothing else} \
  [list $bt_ne \
        [regexp -all {\-label \{Descend to here\} -accelerator E} $bt_m11] \
        $bt_nb \
        [regexp -all {\-accelerator } $bt_m11]] \
  [list 1 1 $bt_seqs $bt_accs]

# ============================================================================
# BT10-BT19 — PURE arm, BOTH arms. No Tk at all: the row list, the AND and the
# perf number are all computed by procs that touch no widget.
# ============================================================================
set bt_r [pcall ::wviewer::browser_rows [bt_ents $BTFIX]]
set bt_ids {}
catch { foreach r $bt_r { lappend bt_ids "[dict get $r id]|[dict get $r kind]|[dict get $r text]" } }
# ⚠ SABOTAGE (c)'s PURE ORACLE. `v(x1.x2.net5)` -> x1 > x2 > net5, per ruling 14
# — the ruling that exists precisely so no node is ever called `v(x1`.
check {BT10 browser_rows gives the exact ordered row list, ids kinds and texts} \
  $bt_ids \
  [list {s:v(out)|leaf|v(out)} {s:v(out2)|leaf|v(out2)} \
        {g:x1|group|x1} {g:x1.x2|group|x2} {s:v(x1.x2.net5)|leaf|net5} \
        {g:x1.y3|group|y3} {s:v(x1.y3.net5)|leaf|net5} \
        {s:i(x1.x2.net5)|leaf|net5} {s:i(v1)|leaf|i(v1)} \
        {s:net1|leaf|net1} {s:vsweep|leaf|vsweep}]
check {BT10 the hierarchy is by PARENT, not by name — x2 under x1, net5 under x2} \
  [list [dict get [lindex $bt_r 2] parent] [dict get [lindex $bt_r 3] parent] \
        [dict get [lindex $bt_r 4] parent]] \
  [list {} g:x1 g:x1.x2]
check_true {BT10 no node is called v(x1 (ruling 14's whole point)} \
  [expr {[lsearch -glob $bt_ids {g:v(*}] < 0}]

# FLAT when NO entry has a path, and the flat rows show the WHOLE name
set bt_flatr [pcall ::wviewer::browser_rows [bt_ents {v(out) i(v1) net1}]]
set bt_flatids {}
catch { foreach r $bt_flatr { lappend bt_flatids "[dict get $r id]|[dict get $r kind]|[dict get $r text]" } }
check {BT11 no entry has a path -> a FLAT list, whole names, zero groups} \
  $bt_flatids \
  [list {s:v(out)|leaf|v(out)} {s:i(v1)|leaf|i(v1)} {s:net1|leaf|net1}]
# ...and still grouped when only SOME have one. This is the leg that stays GREEN
# under sabotage (c) — the discriminator that says the tree FLATTENED rather
# than that browser_rows broke outright.
set bt_mixr [pcall ::wviewer::browser_rows [bt_ents {v(out) v(x1.net5)}]]
set bt_mixids {}
catch { foreach r $bt_mixr { lappend bt_mixids "[dict get $r id]|[dict get $r kind]" } }
check {BT11 only SOME entries have a path -> pathless stay top-level, the rest group} \
  $bt_mixids [list {s:v(out)|leaf} {g:x1|group} {s:v(x1.net5)|leaf}]

# ⚠ MEASURED: `$tv insert {} end -id X` twice THROWS. Both collisions are real.
set bt_dupr [pcall ::wviewer::browser_rows [bt_ents {v(out) v(out) x1.x2 v(x1.x2.net5)}]]
set bt_dupids {}
catch { foreach r $bt_dupr { lappend bt_dupids [dict get $r id] } }
check {BT12 a repeated name gets a distinct id, and a bare x1.x2 leaf misses g:x1.x2} \
  $bt_dupids \
  [list {s:v(out)} {s:v(out)#2} {g:x1} {s:x1.x2} {g:x1.x2} {s:v(x1.x2.net5)}]
check {BT12 ...so every id in the list is unique} \
  [expr {[llength [lsort -unique $bt_dupids]] == [llength $bt_dupids]}] 1

check {BT13 leaf_names of a GROUP are its leaves, deepest included, in row order} \
  [pcall ::wviewer::browser_leaf_names $bt_r g:x1] \
  {v(x1.x2.net5) v(x1.y3.net5) i(x1.x2.net5)}
check {BT13 ...of a deeper group, only that subtree} \
  [pcall ::wviewer::browser_leaf_names $bt_r g:x1.x2] \
  {v(x1.x2.net5) i(x1.x2.net5)}
check {BT13 ...of a LEAF, itself} \
  [pcall ::wviewer::browser_leaf_names $bt_r {s:v(out)}] {v(out)}
check {BT13 ...of a row that is not there, nothing (an answer, not a throw)} \
  [pcall ::wviewer::browser_leaf_names $bt_r {g:nosuch}] {}
check {BT13 browser_kind separates the two, and answers {} for a stranger} \
  [list [pcall ::wviewer::browser_kind $bt_r g:x1] \
        [pcall ::wviewer::browser_kind $bt_r {s:net1}] \
        [pcall ::wviewer::browser_kind $bt_r nope]] \
  [list group leaf {}]

# ============================================================================
# ⚠⚠ BT14 — THE AND, AND THE THREE DISTINCT ANSWERS. This is the check the
# whole item is built to make honest (driver note d): a broken AND and a
# working one must give DIFFERENT results, and they are asserted BY NAME, never
# by count. search-alone = 4, filter-alone = 3, ANDed = 2.
# ============================================================================
set bt_s [bt_d {v(*)}]
set bt_f [bt_d {*net5*}]
check {BT14 the SEARCH bar alone matches four names} \
  [pcall ::wviewer::browser_and $BTFIX $bt_s {}] \
  {ok {v(out) v(out2) v(x1.x2.net5) v(x1.y3.net5)}}
check {BT14 the FILTER bar alone matches three, a DIFFERENT set} \
  [pcall ::wviewer::browser_and $BTFIX {} $bt_f] \
  {ok {v(x1.x2.net5) v(x1.y3.net5) i(x1.x2.net5)}}
# ⚠ SABOTAGE (a)'s PURE ORACLE. An ignored filter reads as BT14's four; an
# ignored search as its three; only a real AND reads two.
check {BT14 ANDed they match exactly two — the intersection, by name} \
  [pcall ::wviewer::browser_and $BTFIX $bt_s $bt_f] \
  {ok {v(x1.x2.net5) v(x1.y3.net5)}}
check {BT14 the AND is order-independent} \
  [pcall ::wviewer::browser_and $BTFIX $bt_f $bt_s] \
  {ok {v(x1.x2.net5) v(x1.y3.net5)}}
check {BT14 two empty bars are the identity, not a wipe} \
  [pcall ::wviewer::browser_and $BTFIX {} {}] [list ok $BTFIX]

# the TYPE dropdowns AND too, because each call applies its own bar's type to
# the other's survivors
check {BT15 Voltage in one bar and All in the other keeps only the v( names} \
  [pcall ::wviewer::browser_and $BTFIX [bt_d {} shell 0 v] [bt_d {*net5*}]] \
  {ok {v(x1.x2.net5) v(x1.y3.net5)}}
check {BT15 Current in the FILTER bar narrows the search bar's survivors} \
  [pcall ::wviewer::browser_and $BTFIX [bt_d {*net5*}] [bt_d {} shell 0 i]] \
  {ok i(x1.x2.net5)}
check {BT15 two INCOMPATIBLE types AND to nothing, and that is `ok {}` not err} \
  [pcall ::wviewer::browser_and $BTFIX [bt_d {} shell 0 v] [bt_d {} shell 0 i]] \
  {ok {}}

# decision 4: an invalid regexp is an ERROR shown to the user, NEVER a silent
# match-all — in EITHER bar, with sig_match's own message
set bt_bad [bt_d {v(} regexp]
set bt_e1 [pcall ::wviewer::browser_and $BTFIX $bt_bad {}]
set bt_e2 [pcall ::wviewer::browser_and $BTFIX {} $bt_bad]
# BOTH legs of "an ERROR, not a silent match-all": the tag is `err`, AND the
# payload is not the whole inventory handed back unfiltered.
check {BT16 an invalid regexp in the SEARCH bar returns err, not a match-all} \
  [list [lindex $bt_e1 0] [expr {[lindex $bt_e1 1] eq $BTFIX}]] [list err 0]
check {BT16 ...and in the FILTER bar too} \
  [list [lindex $bt_e2 0] [expr {[lindex $bt_e2 1] eq $BTFIX}]] [list err 0]
check {BT16 the message is sig_match's own, byte for byte} \
  [list [lindex $bt_e1 1] [lindex $bt_e2 1]] \
  [list [lindex [wviewer::sig_match {} {v(} -syntax regexp] 1] \
        [lindex [wviewer::sig_match {} {v(} -syntax regexp] 1]]
# whole-name anchoring survives the chain (decision 3)
check {BT16 wildcards stay whole-name anchored through the AND} \
  [pcall ::wviewer::browser_and {v(out) xv(out)y} [bt_d {v\(out\)} regexp] {}] \
  {ok v(out)}

# BT17 — PERF, PRINTED. The 2000-signal clause of the Eyeball, discharged as
# EVIDENCE rather than opinion. Threshold deliberately ~100x the measured time:
# it is a "not unusably slow" guard, not a benchmark.
set bt_big {}
for {set i 0} {$i < 2000} {incr i} {
  lappend bt_big "v(x[expr {$i/100}].y[expr {$i/10}].n$i)"
}
set bt_t0 [clock milliseconds]
set bt_bigrows [pcall ::wviewer::browser_rows [bt_ents $bt_big]]
set bt_ms [expr {[clock milliseconds] - $bt_t0}]
puts "  BT17 browser_rows over 2000 signals: ${bt_ms} ms, [llength $bt_bigrows] rows"
check_true {BT17 2000 signals become rows in well under two seconds} \
  [expr {$bt_ms < 2000}]
check_true {BT17 ...and they really did group (2000 leaves plus their groups)} \
  [expr {[llength $bt_bigrows] > 2000}]

# ============================================================================
# BTF — BT20-BT35, the DISPLAY fixture group. Item 8's throwaway-toplevel
# idiom, at 1400x500 so the width cap does NOT bind and the Search button is
# genuinely on-screen (BT23).
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # ⚠ A CALL RECORDER for plot_signals (item 7's ds_spy_* idiom). The fixture
  # has no xschem context behind it, so the real plot_signals must not run —
  # and "a trace appeared" would anyway be a WEAKER claim than "this gesture
  # asked to plot exactly these names, in this order". Every use below is
  # paired with a NEGATIVE control that must record ZERO.
  proc bt_spy_on {} {
    set ::bt_plot_calls {}
    set ::bt_plot_dest {}
    rename ::wviewer::plot_signals ::wviewer::__bt_real_plot_signals
    # ⚠ THE 4th PARAMETER IS ITEM 10's, AND THE SPY MUST CARRY IT. plot_signals
    # grew a one-shot `destover`; a 3-parameter spy would take the real 4-arg
    # call as "too many arguments", browser_plot_ids' own catch would swallow it,
    # and every BT gesture check below would read as "the gesture did nothing".
    # It is RECORDED as well as accepted so item 10's own checks can assert what
    # the cascade passed (BM30/BM31) on this same recorder.
    proc ::wviewer::plot_signals {token exprs {colors {}} {destover {}}} {
      lappend ::bt_plot_calls [list $token $exprs]
      lappend ::bt_plot_dest [list $token $destover]
      return {}
    }
  }
  proc bt_spy_off {} {
    rename ::wviewer::plot_signals {}
    rename ::wviewer::__bt_real_plot_signals ::wviewer::plot_signals
  }
  # ⚠ `event generate <Double-Button-1>` IS ILLEGAL — Tk answers "Double,
  # Triple, or Quadruple modifier not allowed". A double-click is not an event,
  # it is a PATTERN Tk's binding layer recognises in the press/release STREAM,
  # so the only way to drive the real route is to replay the stream: two
  # press/release pairs at the same spot, close enough in time. This is the
  # gesture-test-full-sequence rule in its most literal form.
  proc bt_dclick {tv x y} {
    event generate $tv <ButtonPress-1>   -x $x -y $y
    event generate $tv <ButtonRelease-1> -x $x -y $y
    event generate $tv <ButtonPress-1>   -x $x -y $y
    event generate $tv <ButtonRelease-1> -x $x -y $y
    update
  }
  # centre of a row's bbox, or {} when the row is not on screen. Guarded so a
  # never-mapped row reads as "never mapped" rather than as a broken binding.
  proc bt_centre {tv id} {
    if {[catch {$tv bbox $id} bb] || [llength $bb] != 4} { return {} }
    return [list [expr {[lindex $bb 0] + [lindex $bb 2]/2}] \
                 [expr {[lindex $bb 1] + [lindex $bb 3]/2}]]
  }
  # ⚠ ITEM 10 MADE "NEVER MAPPED" THE DEFAULT, NOT THE EXCEPTION. Nodes are now
  # inserted `-open 0` (only the design root opens, and only on the FIRST
  # populate), so every node below the first level has no bbox until something
  # opens its ancestors — and `bt_centre`'s bare {} then turns a gesture check
  # into a SKIP that asserts nothing.
  #   absent     — no such row in the tree
  #   offscreen  — the row exists but has no bbox
  #   {x y}      — its clickable centre
  # ⚠ `bt_centre` IS NOT TOUCHED — the BM band still calls it.
  proc bt_spot {tv id} {
    if {[catch {$tv exists $id} ex] || !$ex} { return absent }
    if {[catch {$tv bbox $id} bb] || [llength $bb] != 4} { return offscreen }
    return [list [expr {[lindex $bb 0] + [lindex $bb 2]/2}] \
                 [expr {[lindex $bb 1] + [lindex $bb 3]/2}]]
  }
  proc bt_spot_state {s} {
    if {$s eq {absent} || $s eq {offscreen}} { return $s }
    if {[llength $s] == 2} { return mapped }
    return "unreadable: $s"
  }
  # Make row $id clickable: open every CLOSED ancestor and scroll it into view,
  # remembering exactly which ids THIS CALL opened so `bt_close` can put the
  # fixture back. ⚠ RESTORING IS NOT TIDINESS: item 10 CARRIES THE OPEN SET
  # ACROSS A REPOPULATE (R5), so a helper that leaves a node open changes every
  # later check's displayed-row count — including the one `bs_blank_y` measures.
  # ⚠ The `$tv see` here is FIXTURE SETUP and pins nothing. The production rule
  # (`browser_populate` must never call `see`) is a source/BW claim and is
  # unaffected by a test calling it on its own.
  proc bt_open {tv id} {
    if {[catch {$tv exists $id} ex] || !$ex} { return absent }
    set chg {}
    set p $id
    while {1} {
      if {[catch {$tv parent $p} p] || $p eq {}} { break }
      set o 0
      catch {set o [$tv item $p -open]}
      if {![string is boolean -strict $o] || ![string is true -strict $o]} {
        if {![catch {$tv item $p -open 1}]} { lappend chg $p }
      }
    }
    catch {$tv see $id}
    update
    return [list opened $chg]
  }
  proc bt_close {tv opened} {
    foreach p [lindex $opened 1] { catch {$tv item $p -open 0} }
    update
    return [lindex $opened 0]
  }
  # type into a searchbar entry the way a USER does — the widget's own
  # <KeyRelease> binding, never searchbar_fire (item 4's lesson: a route that
  # sets a variable without running -command pins nothing).
  # ⚠ MEASURED, AND IT IS THE gesture-test-full-sequence LESSON AGAIN: Tk
  # REDIRECTS key events to the focus window of the toplevel, so
  # `event generate $sb.pat <KeyRelease>` on an unfocused entry is delivered
  # somewhere else entirely and the binding never runs — silently, with the
  # tree simply not changing. Focus first, CONFIRM the focus landed, and RETURN
  # whether delivery happened so a WSLg focus stall reads as `0` in the asserted
  # tuple instead of masquerading as a broken filter (the bs_wait_mapped rule).
  proc bt_type {sb text} {
    $sb.pat delete 0 end
    $sb.pat insert end $text
    for {set i 0} {$i < 50} {incr i} {
      focus -force $sb.pat
      update
      if {[focus -displayof $sb.pat] eq "$sb.pat"} {
        event generate $sb.pat <KeyRelease> -keysym space
        update
        return 1
      }
      after 20
    }
    puts "  bt_type: focus never landed on $sb.pat (WSLg focus stall)"
    return 0
  }
  proc bt_syntax {sb label} {
    $sb.syntax set $label
    event generate $sb.syntax <<ComboboxSelected>>
    update
  }

  catch {destroy .wvbt1}
  toplevel .wvbt1
  wm title .wvbt1 {item9 signal browser content fixture}
  wm geometry .wvbt1 1400x500+40+40
  canvas .wvbt1.drw -background white -width 1200 -height 460
  pack .wvbt1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbt [dict create top .wvbt1 win_path .wvbt1.drw]
  update
  set bt_mapped [bs_wait_mapped .wvbt1.drw]

  set BTF .wvbt1.wvbrowser
  set BTTV $BTF.pw.tvf.tv
  set BTC  $BTF.pw.sea.c
  set BTSB $BTF.wvsearch
  set BTFB $BTF.wvfilter
  # ⚠ "NEVER BUILT" IS A DISTINCT VALUE FROM "BUILT AND EMPTY" (trap 1).
  check {BT20 before the build there is no tree at all} [bt_tree $BTTV] no-tree
  check {BT20 browser_build returns 1 and the tree now EXISTS but is EMPTY} \
    [list [pcall ::wviewer::browser_build wvbt .wvbt1] [winfo exists $BTTV] \
          [bt_tree $BTTV]] \
    [list 1 1 empty]

  # ⚠ WIDENED BY ITEM 13, NOT DELETED (ruling 17): the Location row `.loc` is a
  # new child of the sidebar, so the SET grows and the NAME is corrected with it.
  # ⚠ WIDENED AGAIN BY THE TWO-PANE ITEM 9: `.tvf` is now a child of `.pw`, and
  # `.opt` carries R11's two checkbuttons.
  check {BT21 the sidebar's children are exactly the two-pane set} \
    [lsort [winfo children $BTF]] \
    [lsort [list $BTF.ph $BTF.wvsearch $BTF.tb $BTF.opt $BTF.pw $BTF.wvfilter \
                 $BTF.loc]]
  # R4: single selection. M4: BOTH scrollbars — the h-scrollbar is what
  # `-stretch 0` on column #0 makes non-decorative (proven by BW02/BW12/BW13).
  check {BT21 the tree is a ttk::treeview, browse-select, with BOTH scrollbars} \
    [list [winfo class $BTTV] [$BTTV cget -selectmode] \
          [winfo exists $BTF.pw.tvf.sb] [winfo exists $BTF.pw.tvf.hsb]] \
    [list Treeview browse 1 1]
  check {BT21 the Plot button exists on the toolbar} \
    [list [winfo exists $BTF.tb.plot] [$BTF.tb.plot cget -text]] [list 1 Plot]
  pcall ::wviewer::browser_toggle 1 wvbt
  update
  # SLAVE ORDER is the only oracle that sees packing order (item 8's BS24
  # lesson, and driver note b: widths cannot see -before at all).
  check {BT21 the sidebar packs BEFORE the canvas} \
    [bs_order .wvbt1 $BTF .wvbt1.drw] a-before-b
  # ⚠ THE PACKING RECIPE ITSELF, not a pair of orderings. `pack slaves` reports
  # PACKING order, which for a mixed -side top/-side bottom stack is NOT the
  # visual order: `.ph` and `.wvfilter` are packed BEFORE `.tvf` precisely so
  # that the tree (packed last, -expand 1) takes whatever is left BETWEEN them.
  # Asserting the whole list plus each slave's -side pins the layout that
  # actually produces search / toolbar / tree / filter / status top to bottom.
  # ⚠ WIDENED BY ITEM 13: `.loc` is packed FIRST of all (the Location row sits
  # above the Search bar, ViVA §3.1), so the recipe is a SIX-slave stack and the
  # name says six. The `-side` leg below gains `.loc -> top` for the same reason.
  # ⚠ WIDENED BY THE TWO-PANE ITEM 9: SEVEN slaves. `.opt` is packed `-side top`
  # AFTER the two `-side bottom` rows, which is what puts R11's checkboxes
  # directly under the Plot toolbar and above the panedwindow; `.pw` takes the
  # `-expand 1` slot `.tvf` used to hold.
  check {BT21 the sidebar's packing recipe is the exact seven-slave stack} \
    [pack slaves $BTF] \
    [list $BTF.loc $BTF.wvsearch $BTF.tb $BTF.ph $BTF.wvfilter $BTF.opt $BTF.pw]
  check {BT21 ...with the sides that put the panes between the checkboxes and the filter} \
    [list [dict get [pack info $BTF.loc] -side] \
          [dict get [pack info $BTF.wvsearch] -side] \
          [dict get [pack info $BTF.tb] -side] \
          [dict get [pack info $BTF.ph] -side] \
          [dict get [pack info $BTF.wvfilter] -side] \
          [dict get [pack info $BTF.opt] -side] \
          [dict get [pack info $BTF.pw] -side] \
          [dict get [pack info $BTF.pw] -expand]] \
    [list top top top bottom bottom top top 1]

  # the measured 755-px blowout, made assertable
  check {BT22 pack propagation is OFF on the sidebar} \
    [pack propagate $BTF] 0
  check {BT22 the sidebar has a real width and the canvas keeps the larger share} \
    [list [bs_wait_mapped $BTF] \
          [expr {[winfo width $BTF] > 200}] \
          [expr {[winfo width .wvbt1.drw] > [winfo width $BTF]}]] \
    [list 1 1 1]
  # decision 5 is about VISIBLE, not merely existing (the measured failure mode
  # was a Search button at x=502 inside a 280-px sidebar, ismapped 0)
  check {BT23 at 1400 px the top bar's Search button is MAPPED, not just present} \
    [list [winfo exists $BTSB.search] [winfo ismapped $BTSB.search]] [list 1 1]
  check {BT23 the FILTER bar has no Search widget at all (-showbutton 0)} \
    [winfo exists $BTFB.search] 0
  # ⚠ DECLARED LIMIT D1, ASSERTED AS A LIMIT RATHER THAN LEFT SILENT. One bar
  # wants 755 px and the derived width is 583, so the LAST widget in the bar —
  # the error label — really is clipped off the right-hand edge. That is the
  # deliberate trade (Search stays visible), and it is exactly why
  # browser_refresh mirrors the message into the status line: BT27 is the check
  # that keeps settled decision 4 alive through this clip.
  check {BT23 the bar's own err label IS clipped at this width (limit D1)} \
    [list [winfo exists $BTSB.err] [winfo ismapped $BTSB.err]] [list 1 0]
  check {BT23 both bars are live searchbars (searchbar_get answers on both)} \
    [list [expr {[pcall ::wviewer::searchbar_get $BTSB] ne {}}] \
          [expr {[pcall ::wviewer::searchbar_get $BTFB] ne {}}]] \
    [list 1 1]

  # THE INVENTORY. Seeded by hand: this fixture has no xschem context, so
  # browser_reload's signal_list read (correctly) answers {}. Everything from
  # here on exercises the REAL refresh path over a KNOWN inventory.
  set ::wviewer::browsersigs(wvbt) $BTFIX
  check {BT24 a refresh over the fixture inventory returns 1 (the tree was rewritten)} \
    [pcall ::wviewer::browser_refresh wvbt] 1
  update
  # ⚠ ITEM 10 (A)+(C): the TREE is NODES ONLY, under ONE design root. With no
  # raw behind this throwaway fixture browser_root_label answers its FLOOR, the
  # literal `design` — a value, not an absence (an empty label would delete the
  # root row outright and leave R4's "something is always selected" nothing to
  # select).
  set BTNODES [list g:|design g:x1|x1 g:x1.x2|x2 g:x1.y3|y3]
  # ⚠⚠ AND THE ROW MODEL IS THE **BAR-UNFILTERED** INVENTORY IN EVERY STATE.
  # browser_refresh builds its entries from `$browsersigs($token)`, NOT from the
  # bar-matched `$names` (spec §7.1: a pattern that matches nothing must leave
  # the tree intact). All eight fixture names classify `net` — sig_declass needs
  # a SINGLE-letter head and `x1`/`x0` are two characters — so
  # browser_class_filter 0 1 drops none of them. `$BTFIX` is therefore the
  # model's answer under ALL, SEARCH, FILTER and AND alike, and asserting it in
  # each state is what pins that invariant instead of assuming it.
  # ⚠ SABOTAGE (c)'s LIVE ORACLE, IN TWO HALVES NOW: the tree half pins the real
  # ttk nesting, ids and texts, depth-first (MEASURED); the model half pins that
  # item 10 MOVED the leaves rather than losing them — without it, a projection
  # that also emptied `browserrows` reads exactly the same and every plot
  # gesture below would be dead.
  check {BT24 the populated tree is the grouped hierarchy under ONE design root, depth first — and the row model still holds every leaf} \
    [list [bt_tree $BTTV] [bt_leaves wvbt]] [list $BTNODES $BTFIX]
  set BTGALL [bt_sig $BTTV wvbt $BTF.ph]
  # ⚠ `pcall` IS MANDATORY ON EVERY HARD-CODED ROW ID. `$tv parent g:x1.x2`
  # THROWS "Item ... not found" when the row is absent, and an unguarded throw
  # here hits the file's outer catch and silently aborts every later check while
  # the fail count still looks plausible — item 6's lesson, MEASURED again by
  # item 9's sabotage (c) (51 checks aborted), and a THIRD time by item 10
  # itself, whose vanished leaf rows made this very leg answer an ERR string.
  # ⚠ THE LEAF IS READ WITH `exists`, NOT WITH `parent`, and that is the point:
  # item 10 (A) GUARANTEES it is not a tree row, so `0` is the claim. Its kind
  # in the ROW MODEL is asserted beside it, because "not in the tree" and "not
  # in the model" are the two halves item 10 deliberately drove apart.
  check {BT24 the group rows really are ttk PARENTS with the right children, the design root parents the top instance, and the LEAF is in the model but NOT in the tree} \
    [list [pcall $BTTV parent {g:x1.x2}] [pcall $BTTV parent {g:x1}] \
          [pcall $BTTV children {g:x1}] [pcall $BTTV children {g:}] \
          [pcall $BTTV exists {s:v(x1.x2.net5)}] \
          [bt_kind wvbt {s:v(x1.x2.net5)}]] \
    [list g:x1 g: {g:x1.x2 g:x1.y3} g:x1 0 leaf]
  # ⚠ WHAT THE COUNT COUNTS MOVED UNDER ITEM 10, AND IT IS NOW LOAD-BEARING.
  # The status line counts the names the two BARS matched, taken BEFORE
  # browser_class_filter runs. With the tree and the row model both
  # bar-INDEPENDENT in item 10, this count is one of only two things left that
  # varies with the bars — so it is read exactly rather than by `string match`,
  # and the model is asserted beside it.
  check {BT24 the status line reports matched-of-total — a count of NAMES, taken BEFORE the class filter — and the model really did keep all eight} \
    [list [bt_count $BTF.ph] [bt_leaves wvbt]] [list {8 of 8} $BTFIX]

  # --- live search, driven through the ENTRY's own KeyRelease ---------------
  # ⚠⚠ ITEM 10: NEITHER THE TREE NOR THE ROW MODEL MOVES. All four bar states
  # keep at least one signal under every node, and §7.1 feeds browser_rows the
  # BAR-UNFILTERED inventory anyway. The live filter is observable in exactly
  # two places, and both are asserted here:
  #   * `browser_match` — the BY-NAME oracle, and not a back door: it is the
  #     proc browser_refresh itself calls, and it re-reads BOTH searchbars
  #     through searchbar_get, so it also proves the typed text landed in the
  #     widget and that the second bar is ANDed in;
  #   * the status-line count, which proves the live refresh actually RAN.
  # The tree and model legs are KEPT and are not decoration: they are the
  # assertion that a search does NOT re-shape the upper pane — R5's sibling
  # (no auto-open) in its other form, no silent re-shape either.
  set bt_k [bt_type $BTSB {v(*)}]
  check {BT25 typing in the SEARCH entry matches the four v( names live, counts them on the status line, and leaves the tree AND the row model exactly as they were} \
    [list $bt_k [bt_tree $BTTV] [bt_leaves wvbt] [bt_count $BTF.ph] \
          [pcall ::wviewer::browser_match wvbt]] \
    [list 1 $BTNODES $BTFIX {4 of 8} \
          {ok {v(out) v(out2) v(x1.x2.net5) v(x1.y3.net5)}}]
  set BTGSEARCH [bt_sig $BTTV wvbt $BTF.ph]
  check {BT25 ...and the status line counts them} \
    [string match {*4 of 8 signals*} [$BTF.ph cget -text]] 1
  # the BUTTON route must agree (decision 5 ships both)
  $BTTV delete [$BTTV children {}]
  check {BT25 the tree really was emptied, so the button has work to do} \
    [bt_tree $BTTV] empty
  $BTSB.search invoke
  update
  check {BT25 the Search BUTTON rebuilds the same tree, the same row model AND the same count as the live route} \
    [list [bt_tree $BTTV] [bt_leaves wvbt] [bt_count $BTF.ph]] \
    [list $BTNODES $BTFIX {4 of 8}]

  # --- ⚠⚠ BT26: THE AND, LIVE, THREE DIFFERENT ANSWERS ---------------------
  # The AND is now read where it is still visible: `browser_match` (by NAME, off
  # the two live bars) and the count. An ignored FILTER reads four names /
  # `4 of 8`; an ignored SEARCH reads three / `3 of 8`; only a real AND reads
  # two. The tree and model legs pin item 10's deliberate non-reshaping.
  set bt_k [bt_type $BTFB {*net5*}]
  check {BT26 the FILTER bar narrows the SEARCH bar's result — the live AND, by NAME off both live bars, with the tree and the row model deliberately unchanged} \
    [list $bt_k [bt_tree $BTTV] [bt_leaves wvbt] [bt_count $BTF.ph] \
          [pcall ::wviewer::browser_match wvbt]] \
    [list 1 $BTNODES $BTFIX {2 of 8} \
          {ok {v(x1.x2.net5) v(x1.y3.net5)}}]
  set BTGAND [bt_sig $BTTV wvbt $BTF.ph]
  check {BT26 ...and the count says two of eight, not four and not three} \
    [string match {*2 of 8 signals*} [$BTF.ph cget -text]] 1
  # THE DISCRIMINATOR: clearing the search bar must give a DIFFERENT ANSWER
  # from the AND. Under item 10 the difference is `i(x1.x2.net5)` reappearing in
  # the MATCHED SET and the count going 2 -> 3 — not a row appearing in the tree
  # (it shares g:x1.x2 with a v( name present in both states) and not a row
  # appearing in the model (§7.1 never took it out).
  set bt_k [bt_type $BTSB {}]
  check {BT26 the FILTER bar alone gives a THIRD, larger answer — i( is back in the matched set and the count says three} \
    [list $bt_k [bt_tree $BTTV] [bt_leaves wvbt] [bt_count $BTF.ph] \
          [pcall ::wviewer::browser_match wvbt]] \
    [list 1 $BTNODES $BTFIX {3 of 8} \
          {ok {v(x1.x2.net5) v(x1.y3.net5) i(x1.x2.net5)}}]
  set BTGFILT [bt_sig $BTTV wvbt $BTF.ph]
  # ⚠⚠ THE ITEM-10 DISCRIMINATOR, AND WHY IT MOVED TWICE. Item 9's control
  # compared the three TREES. Item 10 (A) takes the leaves out of the tree, so
  # all four states DRAW the same four nodes; and item 10's §7.1 feeds
  # browser_rows the BAR-UNFILTERED inventory, so all four states also hold the
  # same eight rows in `browserrows`. Restated on EITHER of those, this control
  # could never fail — worse than a red one. What still varies is the status
  # COUNT and `browser_match`'s by-NAME answer off the two live bars, so the
  # signature is the four-tuple {tree model count matched-names}: the two
  # constant elements stay in it so a future item that makes them vary keeps
  # this control honest without another rewrite.
  # FOUR states, not three: with the tree equal in all of them, ALL is the only
  # state a "the second bar is ignored" break can still be caught against.
  # ⚠ THE LOWER PANE IS NOT AN ORACLE HERE. It is empty until item 11; any
  # version of this control that read sea labels would be green-because-empty.
  check {BT26 all FOUR bar states give a genuinely different browser signature} \
    [bt_distinct $BTGALL $BTGSEARCH $BTGFILT $BTGAND] {distinct:4}
  set bt_k [bt_type $BTSB {v(*)}]
  check {BT26 re-typing the search puts the AND back — two names, two of eight} \
    [list $bt_k [bt_tree $BTTV] [bt_count $BTF.ph] \
          [pcall ::wviewer::browser_match wvbt]] \
    [list 1 $BTNODES {2 of 8} {ok {v(x1.x2.net5) v(x1.y3.net5)}}]

  # --- decision 4, live: the error is VISIBLE and the tree is HELD ----------
  bt_syntax $BTFB RegExp
  set bt_k [bt_type $BTFB {net5(}]
  check {BT27 an invalid regexp writes a message to the STATUS line} \
    [list $bt_k [expr {[string first {parenthes} [$BTF.ph cget -text]] >= 0}]] \
    [list 1 1]
  # ⚠⚠ "HELD" MOVED TO THE REFRESH'S OWN RETURN VALUE. Every bar state draws the
  # same four nodes under item 10 (A), and §7.1 gives every bar state the same
  # eight rows in `browserrows` — so neither the tree nor the model can tell
  # "held" from "widened". `browser_refresh` CAN: its `{err ...}` arm returns 0
  # BEFORE it rewrites anything, so calling it again while the bar is still
  # invalid must answer 0. A widening break rewrites and answers 1.
  # ⚠ THE RE-CALL IS SAFE: the err arm only re-writes the same message into the
  # status label; it never touches the tree, `browserrows` or either bar's own
  # err label (the check two lines down still reads $BTFB.err).
  # ⚠ AND "NEVER WIDENED" IS NOW UNEXPRESSIBLE FROM THE UPPER PANE, said out
  # loud rather than faked: with the tree and the model bar-independent BY
  # DESIGN there is nothing left for a widened tree to look different from. Its
  # coverage is carried by BT16 (pure: an err payload is NOT the whole inventory
  # handed back) and by the recovery leg below (the count must come back to
  # `2 of 8`, not `4 of 8` and not `8 of 8`).
  check {BT27 ...the refresh REFUSES to rewrite (returns 0) and the tree is never blanked} \
    [list [pcall ::wviewer::browser_refresh wvbt] [bt_tree $BTTV] \
          [bt_leaves wvbt]] \
    [list 0 $BTNODES $BTFIX]
  check_true {BT27 the bar's own err label carries it too (even though clipped)} \
    [expr {[string first {parenthes} [$BTFB.err cget -text]] >= 0}]
  # ⚠ THIS LEG NOW CARRIES "NEVER WIDENED". A break that widened during the
  # error state leaves the recovered count at `4 of 8` or `8 of 8`; only a real
  # hold-then-recover reads `2 of 8` with the AND's two names.
  set bt_k [bt_type $BTFB {.*net5.*}]
  check {BT27 a valid regexp recovers: the count is back to two of eight and the AND's two names are back, with the tree unmoved throughout} \
    [list $bt_k [bt_tree $BTTV] [bt_count $BTF.ph] \
          [pcall ::wviewer::browser_match wvbt]] \
    [list 1 $BTNODES {2 of 8} {ok {v(x1.x2.net5) v(x1.y3.net5)}}]
  bt_syntax $BTFB Shell
  bt_type $BTFB {}
  set bt_k [bt_type $BTSB {}]
  check {BT27 clearing both bars restores the whole inventory — eight of eight, every name back in the matched set} \
    [list $bt_k [bt_tree $BTTV] [bt_leaves wvbt] [bt_count $BTF.ph] \
          [pcall ::wviewer::browser_match wvbt]] \
    [list 1 $BTNODES $BTFIX {8 of 8} [list ok $BTFIX]]

  # --- the three plot gestures ---------------------------------------------
  # ⚠⚠ ITEM 10 (A) TOOK THE LEAF ROWS OUT OF THE TREE, so every gesture that
  # targeted `s:<name>` now targets a NODE. The target was chosen for the CLAIM,
  # not for convenience: `g:x1.y3` is the one node on this fixture whose whole
  # subtree is a SINGLE signal, so "plots exactly that one signal" is still a
  # claim about one name and a break that plotted the parent, the subtree or the
  # whole design still reds it.
  # ⚠ DECLARED COVERAGE MOVE: "MMB on a LEAF ROW plots that signal" is not a
  # gesture the upper pane can offer any more; it becomes the LOWER pane's and
  # item 11's. What is kept here is the one-name precision, plus the row-model
  # leg in BT29 below.
  # ⚠ AND THE SKIP IS NOW ASSERTED. A `bt_centre` that answered {} used to print
  # SKIPPED and pin nothing — which is exactly how a vanished row hides. The
  # PRECONDITION FAILS when the row is absent (item 10 broke it) or offscreen (a
  # collapsed ancestor, a pane too short); the guard that follows only decides
  # whether attempting the gesture is worthwhile. Its first element also pins
  # item 10 (B) on the live widget: `g:x1` was born CLOSED and this call opened it.
  bt_spy_on
  set bt_o [bt_open $BTTV {g:x1.y3}]
  set bt_c [bt_spot $BTTV {g:x1.y3}]
  check {BT28 (PRECONDITION) the one-signal node g:x1.y3 exists, was born under a CLOSED g:x1, and is on screen once opened} \
    [list $bt_o [bt_spot_state $bt_c]] [list [list opened g:x1] mapped]
  if {[bt_spot_state $bt_c] ne {mapped}} {
    puts "SKIPPED: BT28 MMB leg (g:x1.y3 [bt_spot_state $bt_c])"
  } else {
    set ::bt_plot_calls {}
    # ⚠ THE REAL TK ROUTE, not the handler proc behind it (driver note f).
    event generate $BTTV <Button-2> -x [lindex $bt_c 0] -y [lindex $bt_c 1]
    update
    check {BT28 a MIDDLE-CLICK on a one-signal node plots exactly that one signal} \
      $::bt_plot_calls [list [list wvbt {v(x1.y3.net5)}]]
  }
  # ⚠⚠ THE LEAF DOUBLE-CLICK IS UNREACHABLE FROM THE UPPER PANE IN ITEM 10, AND
  # THAT IS STATED, NOT PAPERED OVER. `browser_plot_at ... 0` drops every GROUP
  # id (limit D3 — ttk's expand/collapse owns the gesture); item 10 (A) leaves
  # the tree holding NOTHING BUT groups, so a double-click anywhere in this pane
  # now plots nothing BY CONSTRUCTION. The claim splits, and both halves are
  # asserted:
  #   * the STRUCTURAL half, here: every row the tree holds is a `group` in the
  #     row model, which turns "the double-click plots nothing" from a fact
  #     about one row into a rule about the whole pane;
  #   * the BEHAVIOURAL half, one check down: the LEAF arm of the same route
  #     still resolves a leaf id to exactly one name — called DIRECTLY on
  #     browser_plot_ids, which takes row IDS rather than widget rows and is the
  #     entry point all three gestures converge on, one step in.
  # ⚠ AND THE COVERAGE THAT REALLY LEAVES IS DECLARED: "a double-click on a
  # SIGNAL plots it" becomes the LOWER pane's gesture and item 11's file owns
  # it. Until item 11 lands, no check in this repo drives a real double-click
  # (or a real middle-click) on a SIGNAL row that plots it.
  check {BT29 the upper pane holds NOTHING BUT group rows, so the double-click's leaf arm cannot be reached from it} \
    [bt_tree_kinds $BTTV wvbt] group
  # ⚠⚠ ITEM 11 GAVE THIS ITS GESTURE BACK, and the qualifier came off with it.
  # Between item 10 and item 11 NO check in the repo drove a real click on a
  # SIGNAL that plotted it: the leaf rows had left the tree and the lower pane
  # was a stub, so the positive arm relocated to a DIRECT `browser_plot_ids`
  # call and said so in its own name. The sea of names is where those rows went,
  # so this is a real Tk double-click again — on `net1`, cell 3 of the design
  # root's own level (`v(out) v(out2) i(v1) net1 vsweep`, raw order, limit D7).
  #
  # ⚠ THE CALL AND ITS RECORDING ARE READ IN TWO STEPS, DELIBERATELY. Folding
  # them into one `[list ...]` would make the check depend on Tcl substituting
  # its arguments left to right — true, but invisible to the next reader.
  set bt_selwas [pcall $BTTV selection]
  pcall $BTTV selection set [list {g:}]
  update
  set ::bt_plot_calls {}
  set bt_kd [bt_kind wvbt {s:net1}]
  set bt_seal [bs_sea_labels $BTC]
  set bt_g [bs_sea_dclick $BTC 3]
  check {BT29 a REAL DOUBLE-CLICK on a signal in the lower pane plots exactly
         its one signal, by the full raw name behind the label} \
    [list $bt_kd $bt_seal $bt_g $::bt_plot_calls] \
    [list leaf {out out2 v1:i net1 vsweep} ok [list [list wvbt net1]]]
  # ...and the same target through the ROW MODEL agrees, which is what says the
  # gesture resolved rather than guessed
  set ::bt_plot_calls {}
  set bt_n [pcall ::wviewer::browser_plot_ids wvbt {s:net1}]
  check {BT29 ...and the row-model route answers identically for the same signal} \
    [list $bt_n $::bt_plot_calls] [list 1 [list [list wvbt net1]]]
  pcall $BTTV selection set $bt_selwas
  update
  # ...and on a GROUP it plots NOTHING (D3: ttk's expand/collapse owns that
  # gesture). THE NEGATIVE CONTROL for the double-click route.
  # ⚠ THE PRECONDITION IS ASSERTED, NOT ASSUMED. `g:x1` is on screen only
  # because item 10 (B) opens the DESIGN ROOT on the first populate and (R5)
  # carries that open state across every later repopulate.
  # ⚠ AND NOTE WHAT THE DOUBLE-CLICK BELOW DOES TO THE FIXTURE: ttk's own
  # Toggle CLOSES g:x1 (it has children), so the node BT28 opened is collapsed
  # again here — deliberate, and why the bt_close afterwards is idempotent.
  set bt_c [bt_spot $BTTV {g:x1}]
  check {BT29 (PRECONDITION) the group row g:x1 is on screen — item 10 opened the DESIGN ROOT on the first populate and has carried it ever since} \
    [bt_spot_state $bt_c] mapped
  if {[bt_spot_state $bt_c] ne {mapped}} {
    puts "SKIPPED: BT29 group leg (g:x1 [bt_spot_state $bt_c])"
  } else {
    set ::bt_plot_calls {}
    bt_dclick $BTTV [lindex $bt_c 0] [lindex $bt_c 1]
    check {BT29 a DOUBLE-CLICK on a GROUP plots nothing (declared limit D3)} \
      $::bt_plot_calls {}
    # ...but MMB on the same group DOES, which is what makes the zero above a
    # rule rather than a dead recorder
    set ::bt_plot_calls {}
    event generate $BTTV <Button-2> -x [lindex $bt_c 0] -y [lindex $bt_c 1]
    update
    # ⚠ ROW ORDER MEANS browser_rows' FIRST-APPEARANCE ORDER, which is NOT the
    # tree's visual top-to-bottom order when one group's leaves were interleaved
    # with a sibling's in the raw file: here `i(x1.x2.net5)` appears after
    # `v(x1.y3.net5)` in the raw and therefore plots last, even though ttk draws
    # it above. Declared limit D7 — stated rather than papered over, because the
    # check name would otherwise overstate what is pinned (ruling 17).
    check {BT29 ...while a MIDDLE-CLICK on it plots its three leaves, in raw order} \
      $::bt_plot_calls \
      [list [list wvbt {v(x1.x2.net5) v(x1.y3.net5) i(x1.x2.net5)}]]
  }
  bt_close $BTTV $bt_o
  # THE PLOT BUTTON, with a multi-row selection
  # ⚠ ITEM 10 (A): the two selected rows are NODES now — leaf ids cannot be
  # selected in a tree that does not hold them, and `$tv selection set` THROWS
  # on an unknown id. THE SELECTION IS THEREFORE READ BACK INTO THE TUPLE: a set
  # that threw leaves the PREVIOUS selection in place and the button still plots
  # something plausible (MEASURED: it plotted g:x1's three leaves and this check
  # read as a wrong ORDER rather than as a dead gesture).
  # ⚠ THE ORDER CLAIM IS STILL A CLAIM, and a different one from "global raw
  # order": browser_plot_ids walks the IDS and asks browser_leaf_names for each,
  # so the answer is per-id raw order CONCATENATED. `i(x1.x2.net5)` therefore
  # comes SECOND here while in the raw it is the LAST of the three, so a break
  # that collected globally by row order reds.
  # ⚠ The two ids are given in TREE order, so the expectation does not depend on
  # whether ttk answers `selection` in tree order or in the order it was set.
  pcall $BTTV selection set [list {g:x1.x2} {g:x1.y3}]
  set ::bt_plot_calls {}
  $BTF.tb.plot invoke
  update
  check {BT30 the Plot BUTTON plots EVERY selected row, each row's leaves in raw order} \
    [list [pcall $BTTV selection] $::bt_plot_calls] \
    [list {g:x1.x2 g:x1.y3} \
          [list [list wvbt {v(x1.x2.net5) i(x1.x2.net5) v(x1.y3.net5)}]]]
  # THE NEGATIVE CONTROL for the button: nothing selected records ZERO calls.
  pcall $BTTV selection set {}
  set ::bt_plot_calls {}
  $BTF.tb.plot invoke
  update
  check {BT31 the Plot button with an EMPTY selection plots nothing} \
    $::bt_plot_calls {}
  # ...and a click on empty canvas below the last row records zero too
  # ⚠ THE COORDINATE IS NO LONGER FREE, and the PRECONDITION is now asserted.
  # This was `[winfo height $BTTV] - 3`, which was blank only because the tree
  # was as tall as the sidebar. The two-pane item 9 made it one pane of a
  # panedwindow — MEASURED on this fixture: sidebar 500, panedwindow 286, tree
  # 144 px against ~220 px of rows — so that y lands ON A ROW and this check
  # went red reporting a plot. `bs_blank_y` finds a provably blank y (growing
  # the pane, then collapsing, only as far as it must) and answers a NEGATIVE
  # CODE rather than 0 when it cannot, so "there was nowhere blank to click"
  # can never masquerade as "the gesture correctly plotted nothing".
  set bt_bl [bs_blank_y $BTTV $BTF.pw]
  set bt_by [lindex $bt_bl 0]
  check {BT31 (PRECONDITION) there really is blank tree space below the last row} \
    [list [expr {$bt_by > 0}] [pcall $BTTV identify row 20 $bt_by]] {1 {}}
  set ::bt_plot_calls {}
  event generate $BTTV <Button-2> -x 20 -y $bt_by
  update
  check {BT31 a middle-click below the last row plots nothing} \
    $::bt_plot_calls {}
  bs_blank_undo [lindex $bt_bl 1]
  # THE POSITIVE CONTROL, on the same spy, immediately after: the zeros above
  # are a rule, not a broken recorder.
  # ⚠ ITEM 10 (A): `s:vsweep` is not in the tree, so the control moves to the
  # one node whose subtree is a single signal. The selection is read back for
  # the same reason as BT30 — a `selection set` that threw would leave the empty
  # selection from the negative control above, and this check would then AGREE
  # with the very zeros it exists to disprove.
  pcall $BTTV selection set [list {g:x1.y3}]
  set ::bt_plot_calls {}
  $BTF.tb.plot invoke
  update
  check {BT31 ...and the very next real gesture still records (the spy is alive)} \
    [list [pcall $BTTV selection] $::bt_plot_calls] \
    [list g:x1.y3 [list [list wvbt {v(x1.y3.net5)}]]]
  # a GROUP selected + Plot button
  pcall $BTTV selection set [list {g:x1.x2}]
  set ::bt_plot_calls {}
  $BTF.tb.plot invoke
  update
  check {BT32 selecting a GROUP and pressing Plot plots its leaves, in row order} \
    [list [pcall $BTTV selection] $::bt_plot_calls] \
    [list g:x1.x2 [list [list wvbt {v(x1.x2.net5) i(x1.x2.net5)}]]]
  # ⚠⚠ THE DE-DUP CLAIM, RESTATED ON THE OVERLAP THAT STILL EXISTS IN THE TREE.
  # Item 10 (A) removed the leaf rows, so "a group plus one of its own leaves"
  # is no longer a selection a user can make in this pane — and with the leaf id
  # unselectable the old check DEGRADED INTO A COPY of the one above (MEASURED:
  # the `selection set` threw, the selection stayed `g:x1.x2`, and the two
  # checks asserted the same thing while both stayed green). The overlap that
  # remains is a node and its own DESCENDANT node, which exercises the identical
  # `lsearch -exact $names $n < 0` guard in browser_plot_ids: without it,
  # v(x1.x2.net5) and i(x1.x2.net5) are each recorded TWICE.
  pcall $BTTV selection set [list {g:x1} {g:x1.x2}]
  set ::bt_plot_calls {}
  $BTF.tb.plot invoke
  update
  check {BT32 a group plus one of its own DESCENDANT groups does not plot the shared leaves twice} \
    [list [pcall $BTTV selection] $::bt_plot_calls] \
    [list {g:x1 g:x1.x2} \
          [list [list wvbt {v(x1.x2.net5) v(x1.y3.net5) i(x1.x2.net5)}]]]
  # ...and the LITERAL original claim — a group plus one of its own LEAF ids —
  # survives on the ROW MODEL, which is where those two ids still coexist.
  #
  # ⚠⚠ THIS ONE KEEPS ITS DIRECT-CALL QUALIFIER, AND ITEM 11 DID NOT REMOVE IT
  # BECAUSE IT CANNOT. BT29's and BT43's qualifiers were RELOCATIONS — a gesture
  # that existed, lost its widget in item 10 and got it back in item 11. This is
  # not: the target is a GROUP **and** a LEAF at once, and after the two-pane
  # split those live in two different widgets holding two independent
  # selections. There is no single gesture that expresses it, which is exactly
  # why the dedup rule needs an oracle at the entry point both panes converge
  # on. Declared rather than faked with a two-pane gesture that would be
  # testing something else.
  set ::bt_plot_calls {}
  set bt_n [pcall ::wviewer::browser_plot_ids wvbt [list {g:x1.x2} {s:v(x1.x2.net5)}]]
  check {BT32 (ROW MODEL, a DIRECT browser_plot_ids call — UNEXPRESSIBLE as a gesture, see above) a group plus one of its own LEAF ids still plots that leaf once} \
    [list $bt_n $::bt_plot_calls] \
    [list 2 [list [list wvbt {v(x1.x2.net5) i(x1.x2.net5)}]]]
  pcall $BTTV selection set {}
  bt_spy_off
  check {BT32 the spy was removed and the real plot_signals is back} \
    [list [expr {[info commands ::wviewer::plot_signals] ne {}}] \
          [expr {[info commands ::wviewer::__bt_real_plot_signals] eq {}}]] \
    [list 1 1]

  # BT33 — PERF, PRINTED, through the REAL refresh (match + rows + ttk inserts).
  set ::wviewer::browsersigs(wvbt) $bt_big
  set bt_t0 [clock milliseconds]
  set bt_ok [pcall ::wviewer::browser_refresh wvbt]
  set bt_ms2 [expr {[clock milliseconds] - $bt_t0}]
  puts "  BT33 browser_refresh over 2000 signals: ${bt_ms2} ms"
  # ⚠ ITEM 10 (C): the twenty x<N> groups moved one level down, under the single
  # design root, so `children {}` is now the ROOT — asserted BY ID, because `1`
  # is a count that cannot tell one root from one group. ⚠ AND THE SECOND LEVEL
  # IS READ THROUGH `bt_nkids`, NOT A BARE `[$BTTV children {g:}]`: that would
  # THROW when the root is absent, and the throw would abort every remaining
  # check in the file behind a plausible-looking fail count.
  # The count of leaves is paired with the FIRST and LAST name precisely so that
  # a count alone never carries the claim: `no-rows` and `no-leaves` both have
  # llength 1 and both red here instead of reading as "a small tree".
  check {BT33 a 2000-signal refresh really populated the tree: ONE design root over the twenty top-level nodes, with all 2000 leaves still in the row model} \
    [list $bt_ok [$BTTV children {}] [bt_nkids $BTTV {g:}] \
          [llength [bt_leaves wvbt]] [lindex [bt_leaves wvbt] 0] \
          [lindex [bt_leaves wvbt] end]] \
    [list 1 g: 20 2000 v(x0.y0.n0) v(x19.y199.n1999)]
  check_true {BT33 ...in well under five seconds (not unusably slow)} \
    [expr {$bt_ms2 < 5000}]
  set ::wviewer::browsersigs(wvbt) $BTFIX
  pcall ::wviewer::browser_refresh wvbt
  update

  # --- BT34: THE THREE-PATH COLLISION CHECK, MADE ASSERTABLE ----------------
  # The reason neither binding needs a `break`: the CANVAS is not in the tree's
  # bindtags, so xschem.tcl's canvas-level <Double-Button-1> cannot fire here.
  check {BT34 the tree's bindtags contain no canvas} \
    [expr {[lsearch -exact [bindtags $BTTV] .wvbt1.drw] >= 0}] 0
  check {BT34 they are the measured four: widget, class, toplevel, all} \
    [bindtags $BTTV] [list $BTTV Treeview .wvbt1 all]
  check {BT34 the toplevel in those tags carries no Button or Key binding} \
    [list [bind .wvbt1 <Double-Button-1>] [bind .wvbt1 <Button-2>]] [list {} {}]
  check {BT34 ...and neither does the `all` tag} \
    [list [bind all <Double-Button-1>] [bind all <Button-2>]] [list {} {}]

  # BT35 — teardown. The item-9 arrays go with the rest (the gridshow lesson).
  check {BT35 before forget both item-9 arrays hold this token} \
    [list [info exists ::wviewer::browsersigs(wvbt)] \
          [info exists ::wviewer::browserrows(wvbt)]] [list 1 1]
  pcall ::wviewer::forget wvbt
  check {BT35 forget drops browsersigs and browserrows too} \
    [list [info exists ::wviewer::browsersigs(wvbt)] \
          [info exists ::wviewer::browserrows(wvbt)] \
          [info exists ::wviewer::browser(wvbt)]] \
    [list 0 0 0]
  destroy .wvbt1

} else {
  puts "SKIPPED: BTF group (Tk/X arm only)"
}

# ============================================================================
# BTV — BT40-BT47, the REAL VIEWER group: a real toplevel, a real menubar, a
# real canvas with a real xschem context and a REAL raw behind it. This is the
# only arm that can say the browser reads `xschem raw list` (decision 13) and
# that a gesture really adds a trace.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  check {BT40 re-opening the viewer returns 1} [pcall ::wviewer::open $tok] 1
  set vtop2 [wviewer::window_for $tok]
  set vdrw2 $vtop2.drw
  if {![viewer_ready $vtop2]} {
    puts "SKIPPED: BTV group (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {
    set BTVF $vtop2.wvbrowser
    set BTVTV $BTVF.pw.tvf.tv
    set BTVC  $BTVF.pw.sea.c
    # a REAL raw, built on the VIEWER's own context (the SL idiom)
    set BTMAIN [xschem get current_win_path]
    xschem new_schematic switch $vdrw2
    xschem raw new bt_item9.raw dc vsweep 0 1.0 0.5
    foreach n {v(out) v(x1.x2.net5) i(x1.x2.net5) v(x1.y3.net5)} {
      xschem raw add $n {vsweep 1 +}
    }
    xschem new_schematic switch $BTMAIN
    set BTCTX0 [xschem get current_win_path]

    check {BT40 before the toggle the real viewer's tree is EMPTY, not absent} \
      [bt_tree $BTVTV] empty
    check {BT40 toggling the sidebar ON returns 1} \
      [pcall ::wviewer::browser_toggle 1 $tok] 1
    update
    # ⚠ decision 13: the content came from `xschem raw list`, via signal_list —
    # never from the rect model (issue 0186 is still open).
    # ⚠ ITEM 10 (C): the tree's single top level is the DESIGN ROOT, and on this
    # arm its text is MEASURED rather than defaulted — browser_reload captured
    # `bt_item9.raw` into browserraw in the same pass it took the 0173 loan, and
    # browser_root_label stripped the directory and the extension. This is the
    # only check in the batch that can tell a real capture from the `design`
    # FLOOR the throwaway fixture falls back to.
    # ⚠ AND `vsweep` — the whole point of the old check's name — is now proved
    # in the ROW MODEL, because a top-level signal has no node of its own. The
    # order is the fixture's own `raw new` sweep variable followed by its four
    # `raw add` calls, in source order, which browser_rows preserves (D7).
    check {BT40 ...and it populated from the REAL raw: the design root is NAMED for the raw, and vsweep heads the row model} \
      [list [bt_tree $BTVTV] [bt_leaves $tok]] \
      [list [list g:|bt_item9 g:x1|x1 g:x1.x2|x2 g:x1.y3|y3] \
            [list vsweep v(out) v(x1.x2.net5) i(x1.x2.net5) v(x1.y3.net5)]]
    # THE 0173 LOAN, at the browser level: signal_list owns the bracket, and a
    # populate must leave the context exactly where it found it.
    check {BT41 the xschem context is back where it started after the populate} \
      [xschem get current_win_path] $BTCTX0
    check {BT42 a real hierarchical name really nests, x2 under x1 under the design root — and the signal is in the ROW MODEL, not in the tree} \
      [list [pcall $BTVTV parent {g:x1.x2}] [pcall $BTVTV parent {g:x1}] \
            [pcall $BTVTV children {g:x1}] \
            [pcall $BTVTV exists {s:v(x1.x2.net5)}] \
            [bt_kind $tok {s:v(x1.x2.net5)}]] \
      [list g:x1 g: {g:x1.x2 g:x1.y3} 0 leaf]

    # --- BT43: REAL gestures, REAL traces -----------------------------------
    proc bt_traces {token} {
      set n 0
      foreach G [dict get [wviewer::layout_for $token] graphs] {
        incr n [llength [wviewer::dget $G traces {}]]
      }
      return $n
    }
    set bt_n0 [bt_traces $tok]
    # ⚠ ITEM 10 (A)+(B): the leaf rows are gone AND the nodes are born CLOSED,
    # so the target is a NODE and its ancestor has to be opened first.
    # `g:x1.y3` is the one node under this raw whose whole subtree is a SINGLE
    # signal, which is what keeps the arithmetic below at `+1`.
    set bt_o [bt_open $BTVTV {g:x1.y3}]
    set bt_c [bt_spot $BTVTV {g:x1.y3}]
    check {BT43 (PRECONDITION) the real tree's one-signal node exists, was born under a CLOSED g:x1, and is on screen once opened} \
      [list $bt_o [bt_spot_state $bt_c]] [list [list opened g:x1] mapped]
    if {[bt_spot_state $bt_c] ne {mapped}} {
      puts "SKIPPED: BT43 real MMB leg (g:x1.y3 [bt_spot_state $bt_c])"
    } else {
      event generate $BTVTV <Button-2> -x [lindex $bt_c 0] -y [lindex $bt_c 1]
      update
      check_true {BT43 a REAL middle-click added a trace to the real model} \
        [expr {[bt_traces $tok] == $bt_n0 + 1}]
    }
    set bt_n1 [bt_traces $tok]
    # ⚠⚠ THE REAL DOUBLE-CLICK'S POSITIVE ARM IS UNREACHABLE IN ITEM 10, and the
    # gesture is asserted for what it now DOES rather than deleted. Every row in
    # this pane is a group and `browser_plot_at ... 0` refuses groups (D3), so a
    # real double-click must leave the model UNTOUCHED. `g:x1.y3` is childless,
    # so ttk's Toggle cannot collapse the node this block just opened.
    # ⚠ RESIDUAL, DECLARED: ttk's Toggle still flips this childless node's own
    # `-open`, which bt_close does not restore. Harmless on this arm (no further
    # populate follows), and named so nobody copies the pattern onto a node
    # whose open state a later check reads.
    set bt_c [bt_spot $BTVTV {g:x1.y3}]
    if {[bt_spot_state $bt_c] ne {mapped}} {
      puts "SKIPPED: BT43 real double-click leg (g:x1.y3 [bt_spot_state $bt_c])"
    } else {
      bt_dclick $BTVTV [lindex $bt_c 0] [lindex $bt_c 1]
      check {BT43 a REAL double-click on a NODE adds nothing (D3), and the row it targeted is still there} \
        [list [expr {[bt_traces $tok] - $bt_n1}] \
              [bt_spot_state [bt_spot $BTVTV {g:x1.y3}]]] \
        [list 0 mapped]
    }
    # ⚠⚠ THE POSITIVE ARM, GIVEN ITS GESTURE BACK BY ITEM 11. It relocated to a
    # DIRECT `browser_plot_ids` call when item 10 took the leaf rows out of the
    # tree — the honest thing to do with a gesture whose widget had gone, and
    # named so. The sea of names is that widget, so this is a REAL Tk
    # double-click on a REAL viewer again, and it is the strongest form of the
    # claim available anywhere in the batch: a click, on a real canvas, over a
    # real raw, adding a real trace to a real model.
    #
    # MEASURED: `xschem raw new ... dc vsweep ...` writes the sweep variable
    # first, so the design root's own level is `{vsweep out}` and `v(out)` is
    # cell 1. The label list is asserted beside the count so a re-ordering
    # cannot quietly plot the sweep variable instead.
    set bt_n1b [bt_traces $tok]
    set bt_kd  [bt_kind $tok {s:v(out)}]
    pcall $BTVTV selection set [list {g:}]
    update
    set bt_seal [bs_sea_labels $BTVC]
    set bt_g    [bs_sea_dclick $BTVC 1]
    check {BT43 a REAL DOUBLE-CLICK on a signal in the lower pane adds a real
           trace to the real model} \
      [list $bt_kd $bt_seal $bt_g [expr {[bt_traces $tok] - $bt_n1b}]] \
      [list leaf {vsweep out} ok 1]
    # ...and MMB on the same cell is the second route, still one trace
    set bt_n1c [bt_traces $tok]
    set bt_g2 [bs_sea_click $BTVC 1 <Button-2>]
    check {BT43 ...and a REAL MIDDLE-CLICK on it does the same} \
      [list $bt_g2 [expr {[bt_traces $tok] - $bt_n1c}]] [list ok 1]
    bt_close $BTVTV $bt_o

    # --- BT44: the DESTINATION is honoured, through plot_signals (ruling 24) --
    set bt_g0 [llength [dict get [wviewer::layout_for $tok] graphs]]
    pcall ::wviewer::set_plot_dest newstrip $tok
    check {BT44 the window's destination really is newstrip now} \
      [pcall ::wviewer::plot_dest $tok] newstrip
    # ⚠ ITEM 10 (A): a NODE, not `s:i(x1.x2.net5)`. WHICH signals land is free —
    # this check is about the DESTINATION — but the selection is read back,
    # because a `selection set` that threw leaves the previous selection and
    # "a new strip appeared" would then be a fact about a different gesture.
    pcall $BTVTV selection set [list {g:x1.x2}]
    check {BT44 (PRECONDITION) the node really is selected, so the button has the target this check names} \
      [pcall $BTVTV selection] g:x1.x2
    # ⚠ ITEM 10's CARRIED-FORWARD FIX (driver note b), and it is one word per
    # line. These two checks are NAMED as "gestures" but used to call
    # `browser_plot_selection` DIRECTLY — the handler, not the Tk route — which
    # ruling 17 counts as a defect in the NAME even though the coverage was not
    # missing (BT30/31/32 pin the real `invoke` route, BT43 drives real MMB and
    # double-click). SWAPPED rather than renamed, because ruling 17 prefers
    # WIDENING: `$BTVF.tb.plot invoke` is the real button route, is synchronous
    # with no focus or mapping dependence (so it adds zero WSLg flake), the
    # selection is already set by the line above so the semantics are
    # byte-identical, and it closes the exact gap item 9's verifier exposed —
    # no single check spanned real-button-route -> real-trace. RULING-23
    # SUPERSET DECLARED: a future sabotage severing the Plot button's -command
    # now fails BT30/31/32 AND these two, instead of leaving these two green.
    pcall $BTVF.tb.plot invoke
    update
    check_true {BT44 a Plot-button gesture under newstrip created a new strip} \
      [expr {[llength [dict get [wviewer::layout_for $tok] graphs]] > $bt_g0}]
    # ⚠ THE DECLARED LIMIT, ASSERTED AS A LIMIT (ruling 24). Under MULTI-plot,
    # `replace` clears nothing — plan_plot emits no clear key there — so a
    # browser gesture offering Replace in multi mode is really offering Append.
    # This is INHERITED through plot_signals, not introduced here, and it is
    # surfaced rather than pretended away.
    pcall ::wviewer::set_plot_mode multi $tok
    pcall ::wviewer::set_plot_dest replace $tok
    set bt_n2 [bt_traces $tok]
    # ⚠ THE SAME SIGNAL ITEM 9's CHECK USED, reached through its node: `g:x1.y3`
    # holds only `v(x1.y3.net5)`, which BT43's middle-click ALREADY plotted —
    # and that makes this the STRONGEST form of the claim, not a weaker one.
    # add_trace appends unconditionally (there is no already-plotted guard), so
    # a real Replace would leave the strip holding ONE trace and the count would
    # FALL; an Append adds a second copy and it rises.
    pcall $BTVTV selection set [list {g:x1.y3}]
    check {BT44 (PRECONDITION) the node really is selected for the replace leg} \
      [pcall $BTVTV selection] g:x1.y3
    pcall $BTVF.tb.plot invoke                    ;# the real route, see above
    update
    check_true {BT44 under multi, a Replace gesture APPENDS (declared limit D2)} \
      [expr {[bt_traces $tok] > $bt_n2}]

    # --- BT45: the canvas survives a filled sidebar --------------------------
    check {BT45 the canvas is alive, packed, non-zero and still after the sidebar} \
      [list [winfo exists $vdrw2] [winfo manager $vdrw2] \
            [expr {[winfo width $vdrw2] > 1}] [expr {[winfo height $vdrw2] > 1}] \
            [bs_order $vtop2 $BTVF $vdrw2]] \
      [list 1 pack 1 1 a-before-b]
    # ⚠⚠ THE NAMED FLAKY CHECK, WIDENED PER RULINGS 30 AND 17 — NOT deleted and
    # NOT weakened. It failed 2 of 9 HEAD runs and 0 of 8 item-11 runs, and it
    # runs before any item-12 code, so it is OURS. The ruling-30 round MEASURED
    # the mechanism instead of guessing it, and it is not "the widths are zero":
    #   settled read : top 1067  sidebar 480  canvas 587   -> narrower, PASS
    #   flapping read: top  400  sidebar 240  canvas 160   -> WIDER,   FAIL
    # `wviewer::browser_width` caps the sidebar at `0.45 * winfo width $top` but
    # FLOORS it at 240 px, so on a toplevel the WM has not yet grown to its final
    # size the FLOOR wins and the sidebar is legitimately wider than the canvas.
    # The old leg read the two widths once, mid-resize, and asserted a claim that
    # is only true once the 45% cap governs.
    #
    # `bs_wait_widths` therefore polls the real PRECONDITION — the TOPLEVEL's
    # width has stopped changing — and RETURNS the settled triple plus
    # `settled`/`unsettled`, never a verdict. The comparison is still made here,
    # on real numbers, so an inverted or equal layout still FAILS; a budget
    # expiry is visible in the printed tuple rather than masquerading as a
    # layout verdict (item 5's `bs_wait_mapped` rule). The verdict itself is an
    # ASSERTABLE STRING, the house idiom (`bs_order`, `bm_menu_state`,
    # `bx_vis`), so the failure line carries the widths instead of a bare `0`.
    set bt_w45 [bs_wait_widths $vtop2 $BTVF $vdrw2]
    puts "  BT45 widths: top/sidebar/canvas/state = $bt_w45"
    check {BT45 the sidebar is narrower than the canvas on a real viewer} \
      [expr {[lindex $bt_w45 1] < [lindex $bt_w45 2] \
               ? {narrower} : "not-narrower (w=$bt_w45)"}] \
      narrower
    check {BT46 the REAL tree's bindtags contain no canvas either} \
      [expr {[lsearch -exact [bindtags $BTVTV] $vdrw2] >= 0}] 0
    check {BT46 ...and the real viewer toplevel carries no Button binding} \
      [list [bind $vtop2 <Double-Button-1>] [bind $vtop2 <Button-2>]] [list {} {}]

    check {BT47 closing the viewer returns 1} [pcall ::wviewer::close $tok] 1
    check {BT47 ...and the item-9 arrays went with it} \
      [list [info exists ::wviewer::browsersigs($tok)] \
            [info exists ::wviewer::browserrows($tok)]] \
      [list 0 0]
  }

} else {
  puts "SKIPPED: BTV group (Tk/X arm only)"
}

# ============================================================================
# BM — item 10, the RMB context menu on a browser row.
#   BM01-BM15 source/pure (BOTH arms), BM20-BM36 the throwaway fixture,
#   BM40-BM47 the REAL viewer.
#
# ⚠ WHAT THIS GROUP DOES AND DOES NOT CLAIM, stated up front because the PLAN's
# own wording does not survive contact with the widget.
#
#  * THE PLAN SAID "follow the Tcl-only Button3 swallow issue 0178 established
#    for the legend — the canvas RMB must not also fire". The swallow is real
#    (wviewer::btn3_filter) but it DOES NOT TRANSFER, and nothing here needs it:
#    ttk's Treeview class binds no <Button-3>, `bind all <Button-3>` is empty,
#    the viewer toplevel carries only FocusIn/Destroy, and the CANVAS IS NOT IN
#    THE TREE'S BINDTAGS. So the `break` on the tree's binding is DEFENCE IN
#    DEPTH and the ONLY check it can fail is BM01's second leg, which is named
#    to say exactly that. The negative claim itself is carried by BM35
#    (structure) and BM42 (behaviour, with a positive AND a negative control).
#
#  * A MENU IS NOT A WIDGET TREE. `winfo children` sees nothing, `entrycget
#    -label` THROWS on a separator, and `$m index end` answers the literal
#    string `none` on an empty menu. So this group ships TWO never-throwing
#    readers: `bm_entries` (type|label|state per index) and `bm_menu_state`,
#    whose FIVE values — absent / empty / built:N / posted:N / unreadable — make
#    "no menu", "an empty menu", "a built menu", "a posted menu" and "a menu I
#    could not read" four different assertable answers instead of one. All of
#    absent, empty, built:N and posted:N are OBSERVED FOR REAL (BM20, BM22,
#    BM34), and `dismissed` is the built:N that FOLLOWS a posted:N.
#
#  * tk_popup TAKES A GLOBAL GRAB and is SPIED for both display groups. Exactly
#    ONE real popup is taken, in the throwaway fixture, as the last thing BM34
#    does, immediately unposted. That one post is what makes `posted:N` a
#    measurement rather than an inference.
# ============================================================================

# --- BM01-BM09: the SOURCE arm ---------------------------------------------
set bm_build [wvproc_body $wsrc wviewer::browser_build]
set bm_mb    [wvproc_body $wsrc wviewer::browser_menu_build]
set bm_gate  [wvproc_body $wsrc wviewer::browser_menu_ids]
set bm_post  [wvproc_body $wsrc wviewer::browser_menu_post]
set bm_ps    [wvproc_body $wsrc wviewer::plot_signals]
set bm_pids  [wvproc_body $wsrc wviewer::browser_plot_ids]
check {BM00 every item-10 proc this group greps was found in the source} \
  [list [expr {$bm_build ne {}}] [expr {$bm_mb ne {}}] [expr {$bm_gate ne {}}] \
        [expr {$bm_post ne {}}] [expr {$bm_ps ne {}}] [expr {$bm_pids ne {}}]] \
  [list 1 1 1 1 1 1]

check {BM01 browser_build binds <Button-3> on the TREE, exactly once} \
  [list [regexp -all {bind \$f\.pw\.tvf\.tv <Button-3>} $bm_build] \
        [regexp -all {wviewer::browser_menu_post \$token} $bm_build]] \
  [list 1 1]
check_true {BM01 ...and it forwards the event's widget, pixel AND root coords} \
  [expr {[string first {%W %x %y %X %Y} $bm_build] >= 0}]
# ⚠ SABOTAGE (a)'s ONLY TARGET, and it is named for what it really pins. The
# `break` fails NO behavioural check on this surface, because the bindtag chain
# has no other <Button-3> handler in it. BM35 and BM42 are what keep the canvas
# out; this leg keeps the guard against a FUTURE toplevel/all-level binding.
check_true {BM01 the tree's Button-3 body ends in `break` (defence in depth; BM35/BM42 are what keep the canvas out)} \
  [expr {[string first {%W %x %y %X %Y ; break} $bm_build] >= 0}]

# ⚠ REWRITTEN BY ITEM 11, WHICH CONSUMES THE RESERVATION THIS PINNED. Item 10
# minted `Descend to here` once, disabled, with no -command; item 11 replaces
# that single line with a two-armed if/else and touches nothing else in the
# body. Rewriting an inherited check is exactly the shape that hides a
# regression, so the replacement pins BOTH arms and pins that the entry is
# still the LAST thing added — which is what item 10's reservation was for, and
# what BM25's successor BH40/BH41 assert on the live widget (item 11's own file,
# test_wave_sigbrowser_i11.tcl -- ruling 30).
check {BM02 `Descend to here` is minted in both arms, live and disabled, exactly once each} \
  [list [regexp -all {add command -label \{Descend to here\} \\?\n?\s*-command} $bm_mb] \
        [regexp -all {add command -label \{Descend to here\} -state disabled} $bm_mb]] \
  [list 1 1]
check_true {BM02 ...and it is still the LAST `add` in the body — the reserved slot, now consumed} \
  [expr {[string last {$m add } $bm_mb] ==
         [string first {$m add command -label {Descend to here} -state disabled} $bm_mb]}]
# the LIVE arm carries item 11's command and nothing else; the DISABLED arm
# still carries none, so a disagreeing multi-row target cannot hide a live
# command behind a grey label
check_true {BM02 ...the live arm is wired to browser_descend_to, gated on browser_target_path} \
  [expr {[string first {wviewer::browser_descend_to $token $ids} $bm_mb] >= 0 &&
         [string first {wviewer::browser_target_path $token $ids} $bm_mb] >= 0}]

check {BM03 the cascade's entries come from dest_labels — one call, zero literals} \
  [list [regexp -all {wviewer::dest_labels} $bm_mb] \
        [regexp -all {New Strip} $bm_mb] \
        [regexp -all {New Tab} $bm_mb]] \
  [list 1 0 0]
check {BM03 ...and each cascade -command carries the CODE, not the label} \
  [regexp -all {browser_plot_ids \$token \$ids \$code} $bm_mb] 1

# ⚠ SABOTAGE (c)'s SOURCE TARGET. A `Plot to` implemented as save / set /
# restore would put set_plot_dest here and would be invisible to any check that
# only counted traces.
check {BM04 the menu build never writes the window's destination (the override is ONE-SHOT)} \
  [regexp -all {set_plot_dest} $bm_mb] 0
# ONE shared label proc, so the top `Plot (...)` entry and the cascade's Replace
# entry can never disagree about the multi-plot limit
check {BM04 both the Plot entry and the cascade label through dest_menu_label} \
  [regexp -all {wviewer::dest_menu_label \$token} $bm_mb] 2

check {BM05 plot_signals resolves the destination ONCE, defaulting to plot_dest} \
  [list [regexp -all {wviewer::plot_dest \$token} $bm_ps] \
        [regexp -all {wviewer::dest_norm \$destover} $bm_ps] \
        [regexp -all {set dest \[expr} $bm_ps]] \
  [list 1 1 1]
check_true {BM05 ...and the override is an ARGUMENT that never writes dest($token)} \
  [expr {[regexp -all {set_plot_dest|set dest\(} $bm_ps] == 0}]
check_true {BM05 the signature really carries the optional destover} \
  [expr {[string first "proc wviewer::plot_signals \{token exprs \{colors \{\}\} \{destover \{\}\}\}" \
           $wsrc] >= 0}]
# ruling 24 / BT06 stay literally true: browser_plot_ids only FORWARDS it
check {BM05 browser_plot_ids forwards destover and reads no destination itself} \
  [list [regexp -all {wviewer::plot_signals \$token \$names \{\} \$destover} $bm_pids] \
        [regexp -all {plot_dest|plan_plot|dest_prepare|dest_norm} $bm_pids]] \
  [list 1 0]

set bm_forget [wvproc_body $wsrc wviewer::forget]
set bm_tdt    [wvproc_body $wsrc wviewer::tab_drop_transients]
check {BM06 BOTH teardown sites unpost the browser menu (a third tk_popup grab)} \
  [list [regexp -all {wviewer::browser_menu_unpost \$token} $bm_forget] \
        [regexp -all {wviewer::browser_menu_unpost \$token} $bm_tdt]] \
  [list 1 1]

check {BM07 the widget comes from ctx_menu_widget and nothing mints a bare `menu`} \
  [list [regexp -all {wviewer::ctx_menu_widget \$token wvbrowsermenu} $bm_mb] \
        [regexp -all {(^|\s)menu \$} $bm_mb]] \
  [list 1 0]
check {BM07 ...and the cascade's submenu comes from the ctx_menu_child sibling} \
  [regexp -all {wviewer::ctx_menu_child \$m dest} $bm_mb] 1

check {BM08 browser_menu_post routes through ctx_menu_popup and never calls tk_popup} \
  [list [regexp -all {wviewer::ctx_menu_popup} $bm_post] \
        [regexp -all {tk_popup} $bm_post]] \
  [list 1 0]
# ⚠ TOTAL BY CONSTRUCTION: it rides a Tk binding, where a throw pops a MODAL
# bgerror. Three guarded rungs, and NOT one big catch — a `return` inside a
# catch script is CAUGHT (TCL_RETURN) and would fall through to the post.
check {BM08 every rung of the post is a guarded `catch {set ...}`} \
  [list [regexp -all {catch \{set } $bm_post] [regexp -all {return 0} $bm_post]] \
  [list 3 2]

check {BM09 the gate READS the tree selection and never writes it} \
  [list [regexp -all {\$W selection\]} $bm_gate] \
        [regexp -all {selection (set|add|remove|toggle)} $bm_gate]] \
  [list 1 0]
check {BM09 ...and it fails closed on a blank-space click (no row -> no ids)} \
  [regexp -all {if \{\$row eq \{\}\} \{ return \{\} \}} $bm_gate] 1

# ⚠⚠ A REAL DEFECT THIS ITEM SHIPPED AND BM33 CAUGHT. This namespace already
# owns a `wviewer::clipboard` (the trace clipboard's 0-argument test seam), and
# Tcl resolves an unqualified command in the ENCLOSING NAMESPACE FIRST — so a
# bare `clipboard clear -displayof $top` here calls THAT, throws, is swallowed
# by the proc's own catch, and the entry silently does nothing. Pinned at the
# source as well as behaviourally, because the behavioural check needs a real X
# clipboard and this one does not.
set bm_copy [wvproc_body $wsrc wviewer::browser_copy_names]
check_true {BM09 browser_copy_names was found in the source} [expr {$bm_copy ne {}}]
check {BM09 it calls the GLOBAL ::clipboard, never the same-namespace 0-arg seam} \
  [list [regexp -all {::clipboard (clear|append)} $bm_copy] \
        [regexp -all {(^|\s)clipboard (clear|append)} $bm_copy]] \
  [list 2 0]

# --- BM10-BM15: the PURE arm ------------------------------------------------
# every accessor answers on rubbish rather than throwing: pcall turns a throw
# into an `ERR:` string, so a throw here is a VISIBLE wrong value
check {BM10 browser_menu_ids on an unknown token answers {}} \
  [pcall ::wviewer::browser_menu_ids __bm_nope .nope 1 1] {}
check {BM10 browser_menu_names on an unknown token answers {}} \
  [pcall ::wviewer::browser_menu_names __bm_nope {s:v(out)}] {}
check {BM10 browser_menu_build on an unknown token answers {}} \
  [pcall ::wviewer::browser_menu_build __bm_nope {s:v(out)}] {}
check {BM10 browser_menu_post / _unpost on an unknown token answer 0} \
  [list [pcall ::wviewer::browser_menu_post __bm_nope .nope 1 1] \
        [pcall ::wviewer::browser_menu_unpost __bm_nope]] \
  [list 0 0]
check {BM10 browser_copy_names / browser_send_to_add_trace on an unknown token answer 0} \
  [list [pcall ::wviewer::browser_copy_names __bm_nope {s:v(out)}] \
        [pcall ::wviewer::browser_send_to_add_trace __bm_nope {s:v(out)}]] \
  [list 0 0]
check {BM10 ...and the EMPTY token is an answer too, never a throw} \
  [list [pcall ::wviewer::browser_menu_names {} {s:v(out)}] \
        [pcall ::wviewer::browser_menu_post {} .nope 1 1] \
        [pcall ::wviewer::browser_menu_unpost {}]] \
  [list {} 0 0]

# a hand-set row snapshot: no Tk, no window, just the accessor's real input
set ::wviewer::browserrows(__bm_pure) [wviewer::browser_rows [bt_ents $BTFIX]]
check {BM11 a LEAF id answers with its own full raw name} \
  [pcall ::wviewer::browser_menu_names __bm_pure {s:v(out)}] {v(out)}
check {BM11 a GROUP id answers with every leaf beneath it} \
  [pcall ::wviewer::browser_menu_names __bm_pure {g:x1.x2}] \
  {v(x1.x2.net5) i(x1.x2.net5)}
check {BM11 a group PLUS one of its own leaves does not repeat that leaf} \
  [pcall ::wviewer::browser_menu_names __bm_pure {g:x1.x2 s:v(x1.x2.net5)}] \
  {v(x1.x2.net5) i(x1.x2.net5)}
check {BM11 an UNKNOWN row id contributes nothing and does not throw} \
  [pcall ::wviewer::browser_menu_names __bm_pure {s:not.a.row}] {}
check {BM11 a mixed selection keeps row order and drops the duplicate} \
  [pcall ::wviewer::browser_menu_names __bm_pure {s:net1 g:x1.x2 s:net1}] \
  {net1 v(x1.x2.net5) i(x1.x2.net5)}

# ⚠ DECLARED LIMIT D7, PINNED ON THE EXACT CASE THAT MAKES IT VISIBLE. In this
# raw listing the two `x1.x2` leaves DRAW adjacent (ttk re-parents the late
# arrival) while the accessor returns them FIRST AND LAST. The menu acts in RAW
# order, and the check name says so rather than claiming "the order you see".
set ::wviewer::browserrows(__bm_d7) \
  [wviewer::browser_rows [bt_ents {v(x1.x2.n) v(x1.y3.n) i(x1.x2.n)}]]
check {BM12 a group's names come back in RAW-FILE order, not the tree's visual order (limit D7)} \
  [pcall ::wviewer::browser_menu_names __bm_d7 {g:x1}] \
  {v(x1.x2.n) v(x1.y3.n) i(x1.x2.n)}
check {BM12 ...and the two x1.x2 leaves really are first-and-last, not adjacent} \
  [pcall ::wviewer::browser_menu_names __bm_d7 {g:x1.x2}] {v(x1.x2.n) i(x1.x2.n)}
array unset ::wviewer::browserrows __bm_pure
array unset ::wviewer::browserrows __bm_d7

set bm_codes {}
foreach bm_l [wviewer::dest_labels] { lappend bm_codes [wviewer::dest_norm $bm_l] }
check {BM13 every dropdown label normalises to a real, distinct code, in order} \
  $bm_codes {append replace newstrip newtab}
check {BM13 dest_menu_label round-trips each code back to its plain label off multi} \
  [list [wviewer::dest_menu_label __bm_nope append] \
        [wviewer::dest_menu_label __bm_nope replace] \
        [wviewer::dest_menu_label __bm_nope newstrip] \
        [wviewer::dest_menu_label __bm_nope newtab]] \
  [list Append Replace {New Strip} {New Tab}]

# ⚠ THE DECLARED LIMIT SURFACED IN THE LABEL (ruling 24 / item 9's D2): under
# multi-plot, `Replace` really Appends. The menu still OFFERS it — dropping the
# entry would make the cascade disagree with the Add Trace dropdown — and says
# so instead.
set ::wviewer::mode(__bm_multi) multi
set ::wviewer::mode(__bm_single) single
check {BM14 under MULTI the Replace label admits it appends} \
  [wviewer::dest_menu_label __bm_multi replace] {Replace -> appends}
check {BM14 ...and under SINGLE it does not} \
  [wviewer::dest_menu_label __bm_single replace] {Replace}
check {BM14 the suffix is on Replace ALONE, not on the other three} \
  [list [wviewer::dest_menu_label __bm_multi append] \
        [wviewer::dest_menu_label __bm_multi newstrip] \
        [wviewer::dest_menu_label __bm_multi newtab]] \
  [list Append {New Strip} {New Tab}]
array unset ::wviewer::mode __bm_multi
array unset ::wviewer::mode __bm_single

check {BM15 plot_signals with an override on a bogus token still answers the unknown-window pair} \
  [pcall ::wviewer::plot_signals __bm_nope {v(out)} {} newstrip] \
  {{{} {unknown viewer window}}}

# ============================================================================
# BMF — BM20-BM36, the throwaway fixture. Item 8's idiom: a real toplevel, a
# real tree, NO xschem context, tk_popup spied.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # --- the two never-throwing menu readers (driver note c) ------------------
  # type|label|state per index. `entrycget -label` THROWS on a separator and
  # `-state` throws on one too, so BOTH go through pcall and an ERR: reads as
  # the empty string — which makes `separator||` a legal, assertable row rather
  # than an abort.
  proc bm_entries {m} {
    if {[catch {winfo exists $m} e] || !$e} { return absent }
    if {[catch {$m index end} n]} { return unreadable }
    if {$n eq {none}} { return {} }
    set out {}
    for {set i 0} {$i <= $n} {incr i} {
      set ty [pcall $m type $i]
      set lb [pcall $m entrycget $i -label]
      set st [pcall $m entrycget $i -state]
      foreach v {ty lb st} {
        if {[string match ERR:* [set $v]]} { set $v {} }
      }
      lappend out "$ty|$lb|$st"
    }
    return $out
  }
  # THE FOUR-VALUE ORACLE (plus `unreadable` as the fifth escape). `absent` and
  # `empty` are DIFFERENT answers — a gate that posted an empty menu instead of
  # refusing would look identical to one that refused, to any reader that only
  # asked `winfo exists`.
  proc bm_menu_state {m} {
    if {[catch {winfo exists $m} e] || !$e} { return absent }
    if {[catch {$m index end} n]} { return unreadable }
    if {$n eq {none}} { return empty }
    set mp 0
    if {[catch {winfo ismapped $m} mp]} { return unreadable }
    return [expr {$mp ? "posted:[expr {$n + 1}]" : "built:[expr {$n + 1}]"}]
  }
  proc bm_centre {tv id} {
    if {[catch {$tv bbox $id} bb] || [llength $bb] != 4} { return {} }
    return [list [expr {[lindex $bb 0] + [lindex $bb 2]/2}] \
                 [expr {[lindex $bb 1] + [lindex $bb 3]/2}]]
  }
  # --- THE SEA OF NAMES IS THE SIGNAL SURFACE NOW (two-pane item 11) ---------
  # ⚠⚠ THE THROWAWAY LEAF TREE THAT USED TO LIVE HERE IS GONE, AND SO IS THE
  # REASON FOR IT. Item 10 took the LEAF rows out of the sidebar's tree, so
  # every gesture in BM21-BM34 — each naming its target by a leaf row id
  # (`s:v(out)`, `s:net1`, `s:vsweep`) — lost the widget it clicked in. Rather
  # than let ~43 checks go silent (they took the `bm_centre ... eq {}` arm:
  # SKIPPED, zero assertions, still green), item 10 built a second `ttk::treeview`
  # in its own toplevel, filled it from `browserrows($token)` and clicked THAT.
  # It was titled "NOT production" and item 11 was named as the thing that would
  # delete it. This is that deletion.
  #
  # WHERE THE CLAIMS WENT, and the split is THREE-WAY rather than two:
  #
  #   * SIGNAL gestures -> `$BMC`, THE REAL LOWER PANE. `browser_sea_menu_post`
  #     is `browser_menu_post`'s twin over the canvas, and its menu carries the
  #     same eight-entry table, so BM22-BM26 and BM28-BM34 assert exactly what
  #     they asserted before. What MOVED is the currency: the tree's menu closes
  #     over ROW IDS (`{s:v(out)}`), the sea's over FLOW INDICES (`0`), because
  #     the sea has no row ids and inventing some would be a fiction.
  #   * GROUP gestures -> `$BMRTV`, THE REAL TREE, which never needed a fixture:
  #     item 10 removed only leaves, so `g:x1.x2` is still a real clickable row.
  #     BM27 was on the throwaway purely because it sat inside the same guard.
  #   * STRUCTURAL claims stay where item 10 put them (BM20, BM35, BM40, BM42).
  #
  # ⚠ THE ANTI-SKIP DISCIPLINE SURVIVES THE MOVE. Every gesture below still
  # asserts its precondition as a VALUE first (`bm_sea_ready`, `bs_sea_xy`), so
  # a band that goes quiet still has a red standing next to it naming the cell
  # that was not drawn.

  # Is the lower pane really drawn and clickable? AN ASSERTABLE STRING:
  #   no-pane   the canvas is not there
  #   unmapped  it is there but never mapped, so nothing has a bbox
  #   empty     mapped and drawing nothing
  #   ok:N      N cells really drawn
  proc bm_sea_ready {c} {
    if {[catch {winfo exists $c} e] || !$e} { return no-pane }
    if {![bs_wait_mapped $c]} { return unmapped }
    set l [bs_sea_labels $c]
    if {$l eq {no-pane}} { return no-pane }
    if {$l eq {empty}} { return empty }
    return "ok:[llength $l]"
  }
  # Centre of the cell at flow index `idx`, or {} — bm_centre's twin for the
  # canvas, so the two panes' gesture code reads the same way.
  proc bm_sea_centre {c idx} {
    set p [bs_sea_xy $c $idx]
    if {[llength $p] != 2} { return {} }
    return $p
  }
  # a plot recorder that also keeps the DESTOVER argument, which is the only
  # thing that can see a one-shot override
  proc bm_spy_on {} {
    set ::bm_plot_calls {}
    rename ::wviewer::plot_signals ::wviewer::__bm_real_plot_signals
    proc ::wviewer::plot_signals {token exprs {colors {}} {destover {}}} {
      lappend ::bm_plot_calls [list $token $exprs $destover]
      return {}
    }
  }
  proc bm_spy_off {} {
    rename ::wviewer::plot_signals {}
    rename ::wviewer::__bm_real_plot_signals ::wviewer::plot_signals
  }
  # the action-log recorder: a save/restore `Plot to` would leave TWO
  # set_plot_dest lines here, which no trace count can see
  proc bm_log_on {} {
    set ::bm_log_calls {}
    rename ::wviewer::log_action ::wviewer::__bm_real_log_action
    proc ::wviewer::log_action {line} { lappend ::bm_log_calls $line ; return }
  }
  proc bm_log_off {} {
    rename ::wviewer::log_action {}
    rename ::wviewer::__bm_real_log_action ::wviewer::log_action
  }

  # ⚠ tk_popup SPIED for the whole group but ONE deliberate real post (BM34).
  rename ::tk_popup ::__bm_real_tk_popup
  proc ::tk_popup {m x y args} { set ::bm_popped [list $m $x $y] ; return {} }
  set ::bm_popped {}

  catch {destroy .wvbm1}
  toplevel .wvbm1
  wm title .wvbm1 {item10 browser context-menu fixture}
  wm geometry .wvbm1 1400x500+40+40
  canvas .wvbm1.drw -background white -width 1200 -height 460
  pack .wvbm1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbm [dict create top .wvbm1 win_path .wvbm1.drw]
  update
  bs_wait_mapped .wvbm1.drw

  set BMF   .wvbm1.wvbrowser
  # ⚠ TWO PANES AND TWO MENUS FROM ITEM 11 ON, AND THE SPLIT IS THE WHOLE EDIT.
  #   $BMRTV  the REAL sidebar tree — NODE-ONLY since item 10. BM20 reads it
  #           ("production populated the node projection under the design
  #           root"), BM35 reads it ("the production <Button-3> binding is on
  #           the production widget, and the canvas is not in its bindtag
  #           chain"), and BM27 clicks a GROUP row in it.
  #   $BMC    the REAL lower pane. Every SIGNAL gesture lands here, because
  #           signals live here now.
  #   $BMM    the TREE's context menu.   $BMSM  the SEA's — a DISTINCT widget,
  #           and BM22b is the check that says so.
  # ⚠ BM35 STAYS ON $BMRTV FOR A SEMANTIC REASON, NOT A VACUITY ONE. Its leg 3
  # (`bind $w <Button-3>` mentions browser_menu_post) is TRUE OF EXACTLY ONE
  # WIDGET, and its leg 2 is a claim about the PRODUCTION bindtag chain.
  set BMRTV $BMF.pw.tvf.tv
  set BMC   $BMF.pw.sea.c
  set BMM   .wvbm1.wvbrowsermenu
  set BMS   $BMM.dest
  set BMSM  .wvbm1.wvseamenu
  set BMSS  $BMSM.dest
  pcall ::wviewer::browser_build wvbm .wvbm1
  bm_log_on
  pcall ::wviewer::browser_toggle 1 wvbm
  bm_log_off
  set ::wviewer::browsersigs(wvbm) $BTFIX
  pcall ::wviewer::browser_refresh wvbm
  update
  bs_wait_mapped $BMRTV
  bs_wait_mapped $BMC
  bs_wait_sash $BMF.pw
  # ⚠ THE SEA'S CONTENT IS A FUNCTION OF THE TREE'S SELECTION, so the fixture
  # states which node it is standing on rather than inheriting whatever R4 left
  # selected. The design root's OWN LEVEL is the five top-level names of $BTFIX,
  # in raw order — which is where every `s:...` id this band used to name has
  # gone: v(out) -> 0, v(out2) -> 1, i(v1) -> 2, net1 -> 3, vsweep -> 4.
  pcall $BMRTV selection set [list {g:}]
  update
  set bm_fill [bm_sea_ready $BMC]

  check {BM20 the fixture really is a populated tree before any menu exists} \
    [list [winfo exists $BMRTV] [expr {[bt_tree $BMRTV] ne {empty}}]] [list 1 1]
  # ⚠⚠ AND HERE IS WHERE ITEM 10's CENTRAL CHANGE IS PINNED WITHOUT A RAW.
  # `ne empty` above is green on a tree that still holds all eight leaves, so on
  # its own it would let (A) regress silently in the one arm that needs no X
  # viewer and no simulation data. The REAL fixture tree is the NODE-ONLY
  # projection of $BTFIX (R1) under ONE design root (R2); with no xschem context
  # `browserraw(wvbm)` is empty, so `browser_root_label` answers its declared
  # floor, `design`. FOUR rows — and the ABSENCE of the eight `s:` rows IS (A).
  # BM40 pins the same two rulings against a REAL raw and a REAL root label;
  # this leg needs neither.
  check {BM20 ...and it is the NODE-ONLY tree (R1) under the design root (R2)} \
    [bt_tree $BMRTV] \
    [list {g:|design} {g:x1|x1} {g:x1.x2|x2} {g:x1.y3|y3}]
  # ⚠⚠ THE ANTI-SKIP GUARD FOR THE WHOLE BAND, kept through item 11's move.
  # Everything from BM21 to BM34 dies quietly — `SKIPPED`, zero assertions, a
  # green file — if the lower pane is missing, unmapped or drawing nothing.
  # Those are THREE different failures and they get three different values here,
  # so a band that goes silent always has a RED standing next to it saying which.
  check {BM20 (FIXTURE) the lower pane is mapped, drawn and its last cell is
         clickable} \
    [list $bm_fill [expr {[bm_sea_centre $BMC 4] ne {}}] \
          [expr {[bm_sea_centre $BMC 0] ne {}}]] \
    [list ok:5 1 1]
  # ...and the CELLS really are the design root's own level, by label AND by the
  # full raw name behind each — so a fixture that quietly drifted from what
  # BM21-BM34 assert is a RED here rather than a wrong-looking failure forty
  # checks later. R8 renders `i(v1)` as `v1:i`, which no raw name contains.
  check {BM20 (FIXTURE) ...and its cells are the design root's OWN LEVEL, five
         of the eight, labels and raw names alike} \
    [list [bs_sea_labels $BMC] [pcall ::wviewer::browser_sea_names wvbm]] \
    [list {out out2 v1:i net1 vsweep} \
          {v(out) v(out2) i(v1) net1 vsweep}]
  # ...and the ROW MODEL still holds all twelve rows, leaves included (R6) —
  # which is what the tree's own recursive plot gesture resolves through, and
  # the reason taking leaves out of the TREE cost no plotting coverage.
  check {BM20 (FIXTURE) ...while browserrows still holds the FULL twelve-row
         list, leaves included (R6)} \
    [list [llength $::wviewer::browserrows(wvbm)] \
          [pcall ::wviewer::browser_menu_names wvbm [list {s:vsweep}]]] \
    [list 12 {vsweep}]
  # ORACLE VALUE 1 of 4
  check {BM20 with no menu ever built the oracle says `absent`} \
    [bm_menu_state $BMM] absent
  check {BM20 ...and bm_entries agrees, with its own distinct word} \
    [bm_entries $BMM] absent
  # ORACLE VALUE 2 of 4, observed on a menu built BY HAND — proving `absent`
  # and `empty` are genuinely different answers and not one symptom
  catch {destroy .wvbm1.__bmempty}
  menu .wvbm1.__bmempty -tearoff 0
  check {BM20 an EMPTY menu reads `empty`, which is NOT `absent`} \
    [list [bm_menu_state .wvbm1.__bmempty] [bm_entries .wvbm1.__bmempty]] \
    [list empty {}]
  destroy .wvbm1.__bmempty

  # --- BM21: the gate FAILS CLOSED -----------------------------------------
  # ⚠ THE BLANK SPACE MOVED WITH THE SIGNALS. This used to hunt for a y below
  # the last ROW of a tree; the lower pane is a canvas flowed column-major, so
  # its blank space is the GUTTER TO THE RIGHT of the last column — and the
  # miss is `browser_flow_hit`'s arithmetic -1 rather than `identify row`'s {}.
  # That difference is the point of the arithmetic: `find closest`, which
  # ::tk::IconList uses, ALWAYS returns something and would have posted a menu
  # for the nearest neighbour instead of refusing.
  #
  # ⚠ THE PRECONDITION IS STILL ASSERTED AS A VALUE. "there was nowhere blank
  # to click" and "the gate refused" are different facts, and a fixture whose
  # five cells happened to fill the pane must red HERE rather than turn the
  # refusal into a refusal that never happened.
  set bm_bx [expr {[winfo width $BMC] - 2}]
  set bm_by [expr {[winfo height $BMC] - 2}]
  check {BM21 (PRECONDITION) the far corner of the pane really is past the last
         cell — an arithmetic MISS, not a near neighbour} \
    [list [expr {$bm_bx > 0}] \
          [pcall ::wviewer::browser_sea_hit wvbm $BMC $bm_bx $bm_by]] {1 -1}
  set ::bm_popped {}
  check {BM21 an RMB on BLANK pane space past the last cell refuses} \
    [pcall ::wviewer::browser_sea_menu_post wvbm $BMC $bm_bx $bm_by 100 100] 0
  check {BM21 ...and posts NOTHING — still `absent`, never an empty menu} \
    [list [bm_menu_state $BMSM] $::bm_popped] [list absent {}]
  check {BM21 (AND THE TREE'S OWN BLANK SPACE STILL REFUSES TOO) the upper pane
         keeps its own fail-closed gate, on its own widget} \
    [list [pcall ::wviewer::browser_menu_post wvbm $BMRTV 20 \
             [expr {[winfo height $BMRTV] - 2}] 100 100] \
          [bm_menu_state $BMM]] [list 0 absent]

  # --- BM22: a post on a real SIGNAL, in the pane that now holds signals -----
  set bm_c [bm_sea_centre $BMC 0]
  if {$bm_c eq {}} {
    # ⚠ NEVER SILENT: BM20's three FIXTURE legs above assert this exact cell's
    # presence and clickability, so a skip here always arrives with a red.
    puts "SKIPPED: BM22-BM34 (sea cell 0 never drawn)"
  } else {
    set bm_x [lindex $bm_c 0] ; set bm_y [lindex $bm_c 1]
    set ::bm_popped {}
    check {BM22 an RMB on a signal cell posts, and returns 1} \
      [pcall ::wviewer::browser_sea_menu_post wvbm $BMC $bm_x $bm_y 771 553] 1
    # ORACLE VALUE 3 of 4
    check {BM22 the oracle now says `built:8` — present, eight entries, not mapped} \
      [bm_menu_state $BMSM] built:8
    # ⚠ ITEM 11's OWN CLAIM, AND IT IS THE REASON THE TWO MENUS ARE TWO WIDGETS.
    # `ctx_menu_widget` DESTROYS and re-mints the name it is handed, so a sea
    # post through `wvbrowsermenu` would tear the tree's menu down mid-life and
    # `ctx_menu_drop` on either name would take the other with it. The two panes
    # hold two independent selections; one widget aliases them.
    check {BM22b the sea's menu is a DISTINCT widget and the tree's is still
           untouched — `absent`, not rebuilt under it} \
      [list [expr {$BMSM ne $BMM}] [winfo exists $BMSM] [bm_menu_state $BMM]] \
      [list 1 1 absent]
    # THE ROOT-COORD CONTRACT: tk_popup gets %X/%Y, never the widget pixels
    check {BM22 tk_popup was handed the menu and the ROOT coords, not the pane pixels} \
      $::bm_popped [list $BMSM 771 553]
    # ...and when the caller has no root coords they are DERIVED from the pane
    set ::bm_popped {}
    pcall ::wviewer::browser_sea_menu_post wvbm $BMC $bm_x $bm_y
    check {BM22 with no root coords supplied they are derived from the pane's origin} \
      $::bm_popped \
      [list $BMSM [expr {[winfo rootx $BMC] + $bm_x}] \
                  [expr {[winfo rooty $BMC] + $bm_y}]]

    # --- BM23: the whole entry table, BY INDEX ------------------------------
    # ⚠ index 7 UPDATED BY ITEM 11, which consumes the reserved slot: with a
    # single row the target path is unambiguous, so `Descend to here` is now
    # `normal`. The rest of the table is byte-identical to item 10's, which is
    # the point of the reservation. The still-`disabled` state has NOT been
    # dropped from coverage — BH41 pins it for a disagreeing multi-row target
    # (item 11's own file, test_wave_sigbrowser_i11.tcl — ruling 30).
    check {BM23 the menu is the exact eight-entry table, by index, types and states} \
      [bm_entries $BMSM] \
      [list {command|v(out)|disabled} \
            {separator||} \
            {command|Plot (Append)|normal} \
            {cascade|Plot to|normal} \
            {command|Send to Add Trace...|normal} \
            {command|Copy name|normal} \
            {separator||} \
            {command|Descend to here|normal}]
    check {BM23 the header names the SIGNAL the gate picked, and is the only greyed entry bar the last} \
      [list [pcall $BMSM entrycget 0 -label] [pcall $BMSM entrycget 0 -state] \
            [pcall $BMSM entrycget 2 -state] [pcall $BMSM entrycget 5 -state]] \
      [list {v(out)} disabled normal normal]

    # --- BM24: the cascade --------------------------------------------------
    # ⚠ THE CURRENCY MOVED AND THE CLAIM DID NOT. The tree's -commands close
    # over ROW IDS; the sea has no row ids, so its close over FLOW INDICES. What
    # is still asserted, and is the whole point of the check, is that every
    # entry is FULLY RESOLVED — token, target AND code — so no entry can act on
    # the previous click's target or on the window's policy by accident.
    check {BM24 the `Plot to` entry really is a cascade pointing at the submenu} \
      [list [pcall $BMSM type 3] [pcall $BMSM entrycget 3 -menu]] [list cascade $BMSS]
    check {BM24 the submenu carries the four destinations, in dest_labels order} \
      [bm_entries $BMSS] \
      [list {command|Append|normal} {command|Replace|normal} \
            {command|New Strip|normal} {command|New Tab|normal}]
    check {BM24 every cascade -command is fully resolved: token, target AND code} \
      [list [pcall $BMSS entrycget 0 -command] [pcall $BMSS entrycget 1 -command] \
            [pcall $BMSS entrycget 2 -command] [pcall $BMSS entrycget 3 -command]] \
      [list [list wviewer::browser_sea_plot_idx wvbm 0 append] \
            [list wviewer::browser_sea_plot_idx wvbm 0 replace] \
            [list wviewer::browser_sea_plot_idx wvbm 0 newstrip] \
            [list wviewer::browser_sea_plot_idx wvbm 0 newtab]]
    # the TOP Plot entry passes NO override — it is the window's own policy
    check {BM24 the top Plot entry passes no override at all} \
      [pcall $BMSM entrycget 2 -command] \
      [list wviewer::browser_sea_plot_idx wvbm 0]

    # --- BM25: the slot item 11 CONSUMED ------------------------------------
    # ⚠ REWRITTEN BY ITEM 11. It pinned the reservation (disabled, no -command);
    # item 11 fills it, so the check has to move. Rewriting an inherited check
    # is the shape that hides a regression, so what it pins is UNCHANGED except
    # for the two properties item 11 owns: still LAST, still index 7, still
    # labelled `Descend to here` — now live, and wired to THIS click's ids. The
    # DISABLED state it used to pin is not lost: BH41 (in
    # test_wave_sigbrowser_i11.tcl, ruling 30) asserts it for a
    # disagreeing multi-row target, which is the only case that still greys it.
    check {BM25 `Descend to here` is LAST and item 11 has made it LIVE on this click's target} \
      [list [pcall $BMSM index end] [pcall $BMSM entrycget 7 -label] \
            [pcall $BMSM entrycget 7 -state] [pcall $BMSM entrycget 7 -command]] \
      [list 7 {Descend to here} normal \
            [list wviewer::browser_sea_descend_to wvbm 0]]

    # --- BM26: a multi-cell target ------------------------------------------
    pcall ::wviewer::browser_sea_select wvbm [list 0 3 4]
    set bm_c2 [bm_sea_centre $BMC 3]
    if {$bm_c2 eq {}} {
      puts "SKIPPED: BM26 (sea cell 3 never drawn)"
    } else {
      pcall ::wviewer::browser_sea_menu_post wvbm $BMC \
        [lindex $bm_c2 0] [lindex $bm_c2 1] 10 10
      check {BM26 a 3-cell target headers `3 signals` and offers `Copy names (3)`} \
        [list [pcall $BMSM entrycget 0 -label] [pcall $BMSM entrycget 5 -label]] \
        [list {3 signals} {Copy names (3)}]
      check {BM26 ...and the entries act on all three, in FLOW order} \
        [pcall $BMSM entrycget 2 -command] \
        [list wviewer::browser_sea_plot_idx wvbm {0 3 4}]
    }

    # --- BM27: the GROUP decision, made deliberately and stated -------------
    # RMB on a group DOES post and DOES act on its leaves — MMB's semantics,
    # not the double-click's refusal (item 9's D3 exists only to yield the
    # double-click to ttk's expand/collapse, and ttk owns no Button-3).
    #
    # ⚠ THIS ONE IS ON THE REAL TREE, and item 11 is where it goes back to it.
    # A group row is a TREE row; item 10 removed only leaves, so `g:x1.x2` was
    # always still clickable there. It sat on the throwaway purely because it
    # was inside the same guard, which is exactly the kind of drift a fixture
    # invites.
    pcall ::wviewer::browser_sea_select wvbm {}
    pcall $BMRTV item {g:} -open 1
    pcall $BMRTV item {g:x1} -open 1
    update
    set bm_c3 [bm_centre $BMRTV {g:x1.x2}]
    if {$bm_c3 eq {}} {
      puts "SKIPPED: BM27 (group row g:x1.x2 never mapped)"
    } else {
      check {BM27 an RMB on a GROUP posts (unlike the double-click, which refuses)} \
        [pcall ::wviewer::browser_menu_post wvbm $BMRTV \
           [lindex $bm_c3 0] [lindex $bm_c3 1] 10 10] 1
      check {BM27 ...and it acts on the group's leaves, headered as `2 signals`} \
        [list [pcall $BMM entrycget 0 -label] [pcall $BMM entrycget 2 -command]] \
        [list {2 signals} [list wviewer::browser_plot_ids wvbm {g:x1.x2}]]
      check {BM27 (AND THE TWO MENUS DID NOT ALIAS) the sea's menu is still the
             SEA's — its header still names a signal, not a group} \
        [pcall $BMSM entrycget 0 -label] {3 signals}
    }
    pcall ::wviewer::browser_menu_unpost wvbm
    # the tree selection is what the sea is a function of — put it back on the
    # design root, and re-assert that it really is (a silent change here would
    # renumber every cell index below)
    pcall $BMRTV selection set [list {g:}]
    update
    check {BM27 (RESTORED) the sea is back on the design root's own level} \
      [bs_sea_labels $BMC] {out out2 v1:i net1 vsweep}

    # --- BM28: the RMB never mutates the selection --------------------------
    pcall ::wviewer::browser_sea_select wvbm [list 3]
    set bm_sel0 [pcall ::wviewer::browser_sea_selection wvbm]
    pcall ::wviewer::browser_sea_menu_post wvbm $BMC $bm_x $bm_y 10 10
    check {BM28 an RMB on an UNSELECTED cell leaves the selection untouched} \
      [pcall ::wviewer::browser_sea_selection wvbm] $bm_sel0
    set bm_c4 [bm_sea_centre $BMC 3]
    if {$bm_c4 ne {}} {
      pcall ::wviewer::browser_sea_menu_post wvbm $BMC \
        [lindex $bm_c4 0] [lindex $bm_c4 1] 10 10
      check {BM28 ...and on a SELECTED cell it leaves it untouched too} \
        [pcall ::wviewer::browser_sea_selection wvbm] $bm_sel0
    }

    # --- BM29: item 9's in/out-of-selection rule, on the gate ---------------
    pcall ::wviewer::browser_sea_select wvbm [list 0 3]
    check {BM29 an RMB on a cell INSIDE the selection targets the whole selection} \
      [pcall ::wviewer::browser_sea_menu_ids wvbm $BMC $bm_x $bm_y] \
      {0 3}
    if {[bm_sea_centre $BMC 4] ne {}} {
      set bm_c5 [bm_sea_centre $BMC 4]
      check {BM29 ...and on a cell OUTSIDE it targets that cell alone} \
        [pcall ::wviewer::browser_sea_menu_ids wvbm $BMC \
           [lindex $bm_c5 0] [lindex $bm_c5 1]] \
        {4}
    }
    pcall ::wviewer::browser_sea_select wvbm {}

    # --- BM30: the Plot entry, on a recorder with both controls -------------
    bm_spy_on
    pcall ::wviewer::browser_sea_menu_post wvbm $BMC $bm_x $bm_y 10 10
    set ::bm_plot_calls {}
    pcall $BMSM invoke 2
    check {BM30 invoking `Plot` plots that row with NO override (the window's policy)} \
      $::bm_plot_calls [list [list wvbm {v(out)} {}]]
    # NEGATIVE CONTROL: a DISABLED entry records nothing...
    set ::bm_plot_calls {}
    pcall $BMSM invoke 0
    pcall $BMSM invoke 7
    check {BM30 invoking either DISABLED entry records nothing} $::bm_plot_calls {}
    # ...and the very next real invoke still records, so that zero is a rule
    set ::bm_plot_calls {}
    pcall $BMSM invoke 2
    check {BM30 ...and the next real invoke still records (the recorder is alive)} \
      $::bm_plot_calls [list [list wvbm {v(out)} {}]]

    # --- BM31: THE ONE-SHOT, WITH TEETH ------------------------------------
    # ⚠ SABOTAGE (c)'s BEHAVIOURAL TARGET. A save / set_plot_dest / restore
    # implementation would pass the same code to plot_signals and plot the same
    # trace — invisible to any count. The three legs below are what see it:
    # the window's policy is UNCHANGED, dest($token) was never even created,
    # and the action log recorded ZERO set_plot_dest lines.
    bm_log_on
    set ::bm_plot_calls {}
    array unset ::wviewer::dest wvbm
    pcall $BMSS invoke 2
    check {BM31 `Plot to -> New Strip` passes newstrip as a ONE-SHOT override} \
      $::bm_plot_calls [list [list wvbm {v(out)} newstrip]]
    check {BM31 ...and the window's own destination is untouched, never even created} \
      [list [pcall ::wviewer::plot_dest wvbm] \
            [info exists ::wviewer::dest(wvbm)]] \
      [list append 0]
    # ⚠ NAME NARROWED TO WHAT IT PINS (ruling 17): the recorder holds every
    # log_action line, and this leg asserts only that none of them is a
    # set_plot_dest — not that the log is empty.
    check {BM31 ...and NO set_plot_dest line reached the action log} \
      [lsearch -glob $::bm_log_calls {*set_plot_dest*}] -1
    # all four cascade entries, one after another, still leave the policy alone
    set ::bm_plot_calls {}
    foreach bm_i {0 1 3} { pcall $BMSS invoke $bm_i }
    check {BM31 the other three cascade entries pass their own codes} \
      $::bm_plot_calls \
      [list [list wvbm {v(out)} append] [list wvbm {v(out)} replace] \
            [list wvbm {v(out)} newtab]]
    check {BM31 ...and after all four the policy is STILL the untouched default} \
      [list [pcall ::wviewer::plot_dest wvbm] [info exists ::wviewer::dest(wvbm)] \
            [lsearch -glob $::bm_log_calls {*set_plot_dest*}]] \
      [list append 0 -1]
    bm_log_off

    # --- BM32: the multi-plot Replace label, live ---------------------------
    set ::wviewer::mode(wvbm) single
    pcall ::wviewer::browser_sea_menu_post wvbm $BMC $bm_x $bm_y 10 10
    set bm_lab_single [list [pcall $BMSS entrycget 1 -label] \
                            [pcall $BMSM entrycget 2 -label]]
    set ::wviewer::mode(wvbm) multi
    pcall ::wviewer::set_plot_dest replace wvbm
    pcall ::wviewer::browser_sea_menu_post wvbm $BMC $bm_x $bm_y 10 10
    set bm_lab_multi [list [pcall $BMSS entrycget 1 -label] \
                           [pcall $BMSM entrycget 2 -label]]
    check {BM32 under SINGLE both Replace surfaces read plainly} \
      $bm_lab_single [list Replace {Plot (Append)}]
    check {BM32 under MULTI both admit the declared limit, from the ONE shared proc} \
      $bm_lab_multi [list {Replace -> appends} {Plot (Replace -> appends)}]
    array unset ::wviewer::dest wvbm
    array unset ::wviewer::mode wvbm

    # --- BM33: Copy really reaches the clipboard ----------------------------
    pcall ::wviewer::browser_sea_menu_post wvbm $BMC $bm_x $bm_y 10 10
    catch {clipboard clear -displayof .wvbm1}
    catch {clipboard append -displayof .wvbm1 {__bm_sentinel__}}
    check {BM33 the sentinel proves the fixture can read its own clipboard} \
      [pcall clipboard get -displayof .wvbm1] {__bm_sentinel__}
    pcall $BMSM invoke 5
    check {BM33 `Copy name` puts the full raw name on the clipboard} \
      [pcall clipboard get -displayof .wvbm1] {v(out)}
    check {BM33 ...and it says so on the sidebar's status line} \
      [string match {*copied 1 name*} [pcall $BMF.ph cget -text]] 1
    pcall ::wviewer::browser_sea_select wvbm [list 0 3 4]
    if {[bm_sea_centre $BMC 3] ne {}} {
      set bm_c6 [bm_sea_centre $BMC 3]
      pcall ::wviewer::browser_sea_menu_post wvbm $BMC \
        [lindex $bm_c6 0] [lindex $bm_c6 1] 10 10
      pcall $BMSM invoke 5
      check {BM33 `Copy names (3)` joins the three names with newlines, in row order} \
        [pcall clipboard get -displayof .wvbm1] "v(out)\nnet1\nvsweep"
      check {BM33 ...and the status line pluralises} \
        [string match {*copied 3 names*} [pcall $BMF.ph cget -text]] 1
    }
    pcall ::wviewer::browser_sea_select wvbm {}
    bm_spy_off

    # --- BM34: THE ONE REAL POPUP, and the fourth oracle value --------------
    # ⚠ LAST THING THIS GROUP DOES WITH THE MENU, catch-wrapped, with an
    # UNCONDITIONAL teardown after it: a live tk_popup takes a GLOBAL GRAB that
    # would swallow every later leg's events. This single post is what makes
    # `posted:N` a MEASUREMENT rather than an inference.
    rename ::tk_popup {}
    rename ::__bm_real_tk_popup ::tk_popup
    # from a KNOWN-CLEAN start: the previous legs left a BUILT menu lying about
    # (a build is not a post), and the sequence below is only a measurement if
    # its first value is `absent` for a reason rather than by luck
    pcall ::wviewer::browser_sea_menu_unpost wvbm
    update
    set bm_seq {}
    lappend bm_seq [bm_menu_state $BMSM]
    catch {
      set bm_m [wviewer::browser_sea_menu_build wvbm [list 0]]
      lappend bm_seq [bm_menu_state $BMSM]
      tk_popup $bm_m [expr {[winfo rootx $BMC] + 40}] \
                     [expr {[winfo rooty $BMC] + 40}]
      update
      lappend bm_seq [bm_menu_state $BMSM]
      $bm_m unpost
      update
      lappend bm_seq [bm_menu_state $BMSM]
    }
    set bm_un1 [pcall ::wviewer::browser_sea_menu_unpost wvbm]
    set bm_un2 [pcall ::wviewer::browser_sea_menu_unpost wvbm]
    update
    lappend bm_seq [bm_menu_state $BMSM]
    # ORACLE VALUE 4 of 4, and `dismissed` as the built:N that FOLLOWS it
    check {BM34 all four oracle values are observed for real: absent, built, posted, dismissed, absent} \
      $bm_seq [list absent built:8 posted:8 built:8 absent]
    check {BM34 unpost answers 1 when there was a menu and 0 when there was not} \
      [list $bm_un1 $bm_un2] [list 1 0]
    # re-spy for anything that follows
    rename ::tk_popup ::__bm_real_tk_popup
    proc ::tk_popup {m x y args} { set ::bm_popped [list $m $x $y] ; return {} }
  }

  # --- BM35: THE STRUCTURAL NEGATIVE ---------------------------------------
  # ⚠ THIS, NOT THE `break`, IS WHAT KEEPS THE CANVAS OUT. Four bindtags, no
  # <Button-3> on any of the other three, and no canvas among them.
  check {BM35 nothing else in the tree's bindtag chain binds Button-3 at all} \
    [list [bind Treeview <Button-3>] [bind all <Button-3>] \
          [bind .wvbm1 <Button-3>] [bind .wvbm1 <ButtonPress-3>] \
          [bind .wvbm1 <ButtonPress>]] \
    [list {} {} {} {} {}]
  # ⚠ BOTH LEGS STAY ON THE **REAL** TREE. Leg 3 is true of exactly ONE widget
  # in the process — browser_build installs the only <Button-3> — and leg 2's
  # negative (the canvas is not in the chain) is only meaningful for the widget
  # that actually receives the RMB. The throwaway is a Treeview too and is
  # deliberately given NO bindings, so `bind Treeview <Button-3>` stays empty and
  # the leg above keeps its meaning.
  check {BM35 the tree's bindtags are the measured four, and the canvas is not one of them} \
    [list [bindtags $BMRTV] \
          [expr {[lsearch -exact [bindtags $BMRTV] .wvbm1.drw] >= 0}]] \
    [list [list $BMRTV Treeview .wvbm1 all] 0]
  check {BM35 the tree DOES carry the item-10 binding, so the zeros above are a rule} \
    [expr {[string first {wviewer::browser_menu_post wvbm} [bind $BMRTV <Button-3>]] >= 0}] 1

  # --- BM36: teardown -------------------------------------------------------
  # ⚠ THE PRE-STATE IS CAPTURED BEFORE `forget`, WHICH IS THE ONLY PLACE IT CAN
  # BE: forget itself reaps both menus, so a capture taken after it would read
  # 0/0 and the check below would pass on a band that never built anything.
  # A menu is re-posted first so BOTH really exist at the moment of capture.
  set bm_lastc [bm_sea_centre $BMC 0]
  if {[llength $bm_lastc] == 2} {
    pcall ::wviewer::browser_sea_menu_post wvbm $BMC \
      [lindex $bm_lastc 0] [lindex $bm_lastc 1] 10 10
  }
  set bm_l_pre [list [winfo exists $BMSM] [winfo exists $BMC]]
  catch {wviewer::browser_menu_unpost wvbm}
  pcall ::wviewer::forget wvbm
  check {BM36 forget leaves no browser menu widget behind} \
    [list [winfo exists $BMM] [bm_menu_state $BMM]] [list 0 absent]
  check {BM36 (ITEM 11) ...and it reaps the SEA's menu too — a distinct widget
         needs its own unpost, and forget is where that is spelled} \
    [list [winfo exists $BMSM] [bm_menu_state $BMSM]] [list 0 absent]
  # ⚠⚠ AND THIS IS NOT `destroy; assert destroyed`, WHICH WOULD ASSERT ONLY THAT
  # `destroy` DESTROYS — green forever, testing nothing. The pre-state was
  # captured above, so "the sea menu was never built" — which would make the
  # whole band vacuous — is a named red rather than a tautology that passes on
  # an absent widget. (The throwaway leaf-tree leg that used to stand here died
  # with the fixture: item 10 built `.wvbmleaf` and named item 11 as its
  # deletion. The zero below is what says the deletion really happened.)
  destroy .wvbm1
  update
  check {BM36 both menus and the lower pane are gone, both really existed
         first, and no throwaway leaf tree exists anywhere any more} \
    [list $bm_l_pre [winfo exists $BMSM] [winfo exists $BMC] \
          [winfo exists .wvbmleaf]] \
    [list {1 1} 0 0 0]
  rename ::tk_popup {}
  rename ::__bm_real_tk_popup ::tk_popup
  check {BM36 the real tk_popup is back in place} \
    [list [expr {[info commands ::tk_popup] ne {}}] \
          [expr {[info commands ::__bm_real_tk_popup] eq {}}]] \
    [list 1 1]

} else {
  puts "SKIPPED: BMF group (Tk/X arm only)"
}

# ============================================================================
# BMV — BM40-BM47, the REAL VIEWER: a real canvas with a real xschem context,
# a real raw, and a REAL <Button-3>. The only arm that can carry the negative
# claim, because it is the only one where a canvas RMB handler exists at all.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  check {BM40 re-opening the viewer returns 1} [pcall ::wviewer::open $tok] 1
  set vtop3 [wviewer::window_for $tok]
  set vdrw3 $vtop3.drw
  if {![viewer_ready $vtop3]} {
    puts "SKIPPED: BMV group (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {
    set BMVF   $vtop3.wvbrowser
    # ⚠ THE SAME TWO-TREE SPLIT AS THE .wvbm1 GROUP, and here the division of
    # labour is sharper:
    #   $BMVRTV  the REAL tree — the ONLY widget carrying browser_build's
    #            <Button-3>, so it is the only one that can carry BM42's
    #            negative claim ("a real RMB reaches the canvas ZERO times").
    #            BM40, BM42 and BM46's re-post read it.
    #   $BMVC    the REAL lower pane. Every SIGNAL gesture lands here — item 11
    #            deleted the throwaway leaf tree that stood in for it, along
    #            with the `::bm_vleaf` sentinel that existed only to tell
    #            "never built" from "built and reaped" for that fixture.
    set BMVRTV $BMVF.pw.tvf.tv
    set BMVC   $BMVF.pw.sea.c
    set BMVM   $vtop3.wvbrowsermenu
    set BMVS   $BMVM.dest
    set BMVSM  $vtop3.wvseamenu
    set BMVSS  $BMVSM.dest
    proc bm_traces {token} {
      set n 0
      foreach G [dict get [wviewer::layout_for $token] graphs] {
        incr n [llength [wviewer::dget $G traces {}]]
      }
      return $n
    }
    # tk_popup SPIED for this whole arm — a live grab here would swallow every
    # later leg AND the suite's own teardown.
    rename ::tk_popup ::__bm_real_tk_popup
    proc ::tk_popup {m x y args} { set ::bm_popped [list $m $x $y] ; return {} }
    # the canvas RMB handler, RENAME-RECORDED and DELEGATING: a recorder that
    # swallowed would make the positive control meaningless.
    set ::bm_b3_calls 0
    rename ::wviewer::btn3_filter ::wviewer::__bm_real_btn3
    proc ::wviewer::btn3_filter {args} {
      incr ::bm_b3_calls
      return [::wviewer::__bm_real_btn3 {*}$args]
    }

    set BMMAIN [xschem get current_win_path]
    xschem new_schematic switch $vdrw3
    xschem raw new bm_item10.raw dc vsweep 0 1.0 0.5
    foreach bm_n {v(out) v(x1.x2.net5) i(x1.x2.net5)} {
      xschem raw add $bm_n {vsweep 1 +}
    }
    xschem new_schematic switch $BMMAIN
    pcall ::wviewer::browser_toggle 1 $tok
    update
    bs_wait_mapped $BMVRTV
    # ⚠ RESTATED BY TWO-PANE ITEM 10, AND IT IS THE VALUE THAT MOVED, NOT THE
    # CLAIM. The claim was and is "the REAL sidebar populated from the REAL raw,
    # and you can read exactly what it holds". Item 10 changed what the UPPER
    # pane holds: NODES ONLY (R1/R3 — the signals move to the sea of names in
    # item 11), under ONE design root named for the raw file (R2). Both halves
    # are visible in this single value: `g:|bm_item10` is `browser_root_label`
    # of `bm_item10.raw`, i.e. browser_reload's capture really reached the tree;
    # the two `g:` nodes are the hierarchy the four raw signals imply; and the
    # ABSENCE of every `s:` row is R1 itself.
    check {BM40 the real sidebar shows the item-10 NODE tree, rooted at the raw's name} \
      [bt_tree $BMVRTV] \
      [list {g:|bm_item10} {g:x1|x1} {g:x1.x2|x2}]
    # ⚠ THE LEAF NAMES ARE NOT LOST FROM COVERAGE, and this is where that is
    # stated as a value rather than as a comment. R6: `browserrows($token)`
    # still holds every leaf, which is what `browser_menu_names` resolves and
    # what makes BM43/BM45's throwaway tree a relocation rather than a rewrite.
    # If this goes red the throwaway is meaningless and the whole band knows.
    check {BM40 ...and the FULL row list still holds the leaves (R6), which is what the menu resolves} \
      [pcall ::wviewer::browser_menu_names $tok [list {s:v(out)}]] {v(out)}
    check {BM40 and no menu exists yet on the real toplevel} \
      [bm_menu_state $BMVM] absent

    # --- BM41: THE POSITIVE CONTROL ----------------------------------------
    # ⚠ WITHOUT THIS, BM42's ZERO IS VACUOUS: "btn3_filter did not run" reads
    # identically when btn3_filter was never wired to the canvas at all. Prove
    # a real press/release on the REAL canvas records exactly 2 first.
    set bm_ok41 0
    for {set bm_i 0} {$bm_i < 5 && !$bm_ok41} {incr bm_i} {
      set ::bm_b3_calls 0
      catch {focus -force $vdrw3}
      update
      event generate $vdrw3 <ButtonPress-3>   -x 60 -y 60
      event generate $vdrw3 <ButtonRelease-3> -x 60 -y 60
      update
      if {$::bm_b3_calls == 2} { set bm_ok41 1 } else { after 40 }
    }
    check {BM41 a REAL press+release on the REAL canvas records 2 btn3_filter calls} \
      [list $bm_ok41 $::bm_b3_calls] [list 1 2]

    # --- BM42: THE NEGATIVE CONTROL, both halves in ONE tuple ---------------
    # "the gesture did nothing at all" is NOT a passing answer here.
    #
    # ⚠ THE TARGET MOVED, AND ONLY THE TARGET. Item 10 took `s:v(out)` out of
    # this tree (R1), so it answers {} to `bbox` and the whole block skips —
    # MEASURED, verbatim: `SKIPPED: BM42-BM45 (real row s:v(out) never mapped)`.
    # `g:` is the row that is guaranteed to EXIST for ANY inventory — flat or
    # hierarchical — and it is the one node `browser_populate` inserts open, so
    # it always has a bbox. (`g:x1` is DRAWN too, being a child of the open
    # root; it is simply not guaranteed to exist for a flat raw. Do not "fix"
    # this to `g:x1`.) Every leg below is ROW-AGNOSTIC — the canvas count is 0
    # for any row, tk_popup gets the same widget, and browser_menu_build emits
    # EIGHT entries on both arms of its only conditional — so this is a
    # coordinate restatement, not a new claim.
    # ⚠ AND IT CANNOT MOVE TO THE THROWAWAY TREE. This is the only widget
    # carrying browser_build's <Button-3>; a fixture that re-bound it would be
    # testing the test.
    set bm_c [bm_centre $BMVRTV {g:}]
    check {BM42 (PRECONDITION) the real tree's design root is present and clickable} \
      [list [expr {[lsearch -exact [bs_tree_ids $BMVRTV] {g:}] >= 0}] \
            [expr {$bm_c ne {}}]] \
      [list 1 1]
    if {$bm_c eq {}} {
      puts "SKIPPED: BM42-BM46 (the real tree's design root never mapped)"
    } else {
      set ::bm_b3_calls 0
      set ::bm_popped {}
      event generate $BMVRTV <Button-3> -x [lindex $bm_c 0] -y [lindex $bm_c 1]
      update
      check {BM42 a REAL RMB on a browser row posts the menu and reaches the canvas ZERO times} \
        [list $::bm_b3_calls [expr {[lindex $::bm_popped 0] eq $BMVM}] \
              [bm_menu_state $BMVM]] \
        [list 0 1 built:8]

      # --- the REAL LOWER PANE for the real-viewer group -------------------
      # ⚠ ITEM 11 DELETED THE THROWAWAY THAT STOOD HERE. `.wvbmvleaf` was item
      # 10's stand-in for the leaf rows it had just removed from the tree; the
      # sea of names is the real widget those rows became, and BM43/BM45 click
      # it. The `::bm_vleaf` sentinel that told "never built" from "built and
      # reaped" went with it — BM47 now asserts the SEA's lifecycle instead,
      # which is a claim about production rather than about a fixture.
      #
      # ⚠ THE SELECTION IS STATED, NOT INHERITED. The pane is a function of the
      # tree's selection; BM42's real RMB above does not change it, but saying
      # so here is what keeps the cell indices below meaningful.
      pcall $BMVRTV selection set [list {g:}]
      update
      set bm_fillv [bm_sea_ready $BMVC]
      # ⚠ CELL **1**, MEASURED. `xschem raw new ... dc vsweep ...` writes the
      # sweep variable FIRST, so the design root's own level is `{vsweep out}`
      # in raw order (limit D7 — the pane preserves it and does not sort).
      # Cell 1 is `v(out)`, which is what the legs below name.
      set bm_cl [bm_sea_centre $BMVC 1]
      # FOUR values, so "no pane", "unmapped", "nothing drawn" and "the model no
      # longer resolves the name" are four different reds and not one skip.
      # ok:2 = the real raw's design-root own level, `v(out)` and `vsweep`.
      check {BM43 (FIXTURE) the real lower pane holds the real raw's own-level
             signals, and they still resolve} \
        [list $bm_fillv [expr {$bm_cl ne {}}] [bs_sea_labels $BMVC] \
              [pcall ::wviewer::browser_sea_name $tok 1]] \
        [list ok:2 1 {vsweep out} {v(out)}]
      if {$bm_cl eq {}} {
       puts "SKIPPED: BM43-BM45 (sea cell 1 never drawn)"
      } else {
      # --- BM43: the real header, and a real trace -------------------------
      # ⚠ DELIVERY RESTATED, CLAIM UNCHANGED. The menu is posted by CALLING
      # `browser_sea_menu_post` with exactly the widget/x/y the canvas binding
      # forwards as `%W %x %y`. The real-event route is NOT dropped from
      # coverage: BM42 above IS that claim on the tree, with BM41 as its
      # positive control, and BT43's sea legs drive real Tk events on this pane.
      # ⚠ AND THE TARGET CANNOT BE A NODE ROW: both legs below are signal-
      # specific (the menu headers `N signals` and plots N traces for n>1), so
      # re-aiming them would replace the claim instead of preserving it.
      pcall ::wviewer::browser_sea_menu_post $tok $BMVC \
        [lindex $bm_cl 0] [lindex $bm_cl 1] 10 10
      update
      check {BM43 the real menu's header is the real raw name from `xschem raw list`} \
        [pcall $BMVSM entrycget 0 -label] {v(out)}
      set bm_n0 [bm_traces $tok]
      pcall $BMVSM invoke 2
      update
      check_true {BM43 ...and invoking its Plot entry added a REAL trace} \
        [expr {[bm_traces $tok] == $bm_n0 + 1}]

      # --- BM44: the one-shot, on the real model ---------------------------
      set bm_g0 [llength [dict get [wviewer::layout_for $tok] graphs]]
      pcall $BMVS invoke 2
      update
      check_true {BM44 `Plot to -> New Strip` really created a strip on the real model} \
        [expr {[llength [dict get [wviewer::layout_for $tok] graphs]] > $bm_g0}]
      check {BM44 ...and the window's own destination is STILL the untouched default} \
        [list [pcall ::wviewer::plot_dest $tok] [info exists ::wviewer::dest($tok)]] \
        [list append 0]
      # ⚠ THE NEW TAB LEG IS pcall-GUARDED ON PURPOSE. Its -command runs
      # dest_prepare -> new_tab -> tab_drop_transients, which now unposts (and
      # DESTROYS) the very menu whose entry is executing. Down the REAL route
      # Tk has already unposted before invoking, so this is safe; a direct
      # `$m invoke` is the one path where it is not, so it is guarded and only
      # the tab count and the untouched policy are asserted.
      set bm_t0 [pcall ::wviewer::tab_count $tok]
      set bm_nt [pcall $BMVS invoke 3]
      update
      check {BM44 `Plot to -> New Tab` added a tab and still left the policy alone} \
        [list [expr {[pcall ::wviewer::tab_count $tok] == $bm_t0 + 1}] \
              [pcall ::wviewer::plot_dest $tok] \
              [info exists ::wviewer::dest($tok)]] \
        [list 1 append 0]
      # and the teardown really did take the menu with it — BM46's claim,
      # observed on the route that actually calls tab_drop_transients
      # ⚠ BUILT, not POSTED: tk_popup is spied for this whole arm, so what the
      # teardown removed is a built menu. The NAME says built (ruling 17); the
      # only REAL post anywhere in this file is BM34's.
      check {BM46 the tab switch inside New Tab took the built menu down with it} \
        [bm_menu_state $BMVM] absent

      # --- BM45: Send to Add Trace -----------------------------------------
      # ⚠ TWO PRECONDITIONS, NOT ONE, and the second is the interesting one:
      # the pane was drawn BEFORE BM44's New Tab, so "the cell is drawn" and
      # "the name still resolves through the pane's own pair list" are separate
      # facts and get separate values. An empty prefill can then never be blamed
      # on the wrong half.
      #
      # ⚠ THE TARGET IS A DESCENDED NODE, which is what makes this a real
      # navigation: `i(x1.x2.net5)` is not at the design root, so the tree
      # selection moves to `g:x1.x2` and the pane re-flows to that level's two
      # signals — R8's `net5` / `net5:i` pair, the one place in this fixture
      # where two names render to two DIFFERENT labels off the same net.
      pcall $BMVRTV selection set [list {g:x1.x2}]
      update
      set bm_c7 [bm_sea_centre $BMVC 1]
      check {BM45 (PRECONDITION) the cell is drawn in the real pane AND still
             resolves to its full raw name} \
        [list [expr {$bm_c7 ne {}}] [bs_sea_labels $BMVC] \
              [pcall ::wviewer::browser_sea_name $tok 1]] \
        [list 1 {net5 net5:i} {i(x1.x2.net5)}]
      if {$bm_c7 eq {}} {
        puts "SKIPPED: BM45 (sea cell 1 of g:x1.x2 never drawn)"
      } else {
        catch {destroy $vtop3.wvadd}
        pcall ::wviewer::browser_sea_menu_post $tok $BMVC \
          [lindex $bm_c7 0] [lindex $bm_c7 1] 10 10
        update
        pcall $BMVSM invoke 4
        update
        check {BM45 `Send to Add Trace...` opens the dialog with the EXACT raw name prefilled} \
          [list [winfo exists $vtop3.wvadd] [pcall $vtop3.wvadd.expr get]] \
          [list 1 {i(x1.x2.net5)}]
        # ⚠ DECLARED LIMIT, ASSERTED AS A LIMIT: the Expression entry holds ONE
        # expression, so a multi-cell target prefills the FIRST name only. A
        # batch goes through the dialog's own multi-select listbox (item 6).
        pcall ::wviewer::browser_sea_select $tok [list 0 1]
        catch {destroy $vtop3.wvadd}
        pcall ::wviewer::browser_sea_send_to_add_trace $tok [list 0 1]
        update
        check {BM45 with a MULTI-cell target only the FIRST name is prefilled (declared limit)} \
          [list [winfo exists $vtop3.wvadd] [pcall $vtop3.wvadd.expr get]] \
          [list 1 {v(x1.x2.net5)}]
        pcall ::wviewer::browser_sea_select $tok {}
        pcall $BMVRTV selection set [list {g:}]
        update
        catch {destroy $vtop3.wvadd}
      }
      }

      # --- BM46: the OTHER teardown route, a real tab switch ---------------
      # ⚠ ON THE REAL TREE, at the same design-root coordinate BM42 used, and
      # OUTSIDE the throwaway's arm on purpose: a fixture that failed to map
      # must not take a claim about the production widget down with it. The
      # menu is EIGHT entries whatever the row resolves to, so `built:8` is the
      # same assertion it always was. The root is row 0 of the tree, so this
      # coordinate survives BM44's tab switch even if the tree was repopulated.
      event generate $BMVRTV <Button-3> -x [lindex $bm_c 0] -y [lindex $bm_c 1]
      update
      set bm_pre [bm_menu_state $BMVM]
      set bm_recs [pcall ::wviewer::tab_records $tok]
      set bm_other {}
      if {![string match ERR:* $bm_recs]} {
        set bm_cur [pcall ::wviewer::tab_index $tok]
        for {set bm_i 0} {$bm_i < [llength $bm_recs]} {incr bm_i} {
          if {$bm_i != $bm_cur} {
            catch {set bm_other [dict get [lindex $bm_recs $bm_i] id]}
            break
          }
        }
      }
      if {$bm_other eq {}} {
        puts "SKIPPED: BM46 real tab-switch leg (only one tab)"
      } else {
        pcall ::wviewer::select_tab $bm_other $tok
        update
        check {BM46 a REAL tab switch takes the built menu down (it was there first)} \
          [list $bm_pre [bm_menu_state $BMVM]] [list built:8 absent]
      }
    }

    # --- BM47: close ---------------------------------------------------------
    rename ::wviewer::btn3_filter {}
    rename ::wviewer::__bm_real_btn3 ::wviewer::btn3_filter
    # ⚠⚠ NOT `destroy; assert destroyed`. `winfo exists` after a teardown reads 0
    # for "reaped" AND for "never built", so a BM42 skip would make a bare
    # after-check pass while asserting nothing. The PRE-state is captured first
    # and the pane's own drawn state with it, so a group that never ran reds
    # HERE too, naming what was missing.
    #
    # ⚠ ITEM 11: the fixture whose lifecycle this used to assert (`.wvbmvleaf`,
    # with its `::bm_vleaf` never-built/built sentinel) is DELETED. The claim
    # moved to production — the real lower pane and the real sea menu — which is
    # a stronger place for it: a throwaway outliving its band was a test-hygiene
    # bug, a production pane outliving its window is a leak.
    set bm_vl_pre [list [bm_sea_ready $BMVC] [winfo exists $BMVC]]
    check {BM47 (PRECONDITION) the real lower pane was alive and drawn right up
           to the close, and no throwaway leaf tree exists anywhere} \
      [list $bm_vl_pre [winfo exists .wvbmvleaf]] [list {ok:2 1} 0]
    check {BM47 closing the viewer returns 1} [pcall ::wviewer::close $tok] 1
    check {BM47 ...and no browser menu survived the close} \
      [list [winfo exists $BMVM] [bm_menu_state $BMVM]] [list 0 absent]
    check {BM47 (ITEM 11) ...nor the SEA's menu, nor the lower pane itself} \
      [list [winfo exists $BMVSM] [bm_menu_state $BMVSM] [winfo exists $BMVC]] \
      [list 0 absent 0]
    rename ::tk_popup {}
    rename ::__bm_real_tk_popup ::tk_popup
    check {BM47 the real btn3_filter and tk_popup are both back} \
      [list [expr {[info commands ::wviewer::__bm_real_btn3] eq {}}] \
            [expr {[info commands ::__bm_real_tk_popup] eq {}}] \
            [expr {[info commands ::tk_popup] ne {}}]] \
      [list 1 1 1]
  }

} else {
  puts "SKIPPED: BMV group (Tk/X arm only)"
}


} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

wvbs_finish
