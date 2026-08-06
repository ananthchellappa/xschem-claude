# tests/headless/test_wave_sigbrowser.tcl — the Signal Browser sidebar
# (doc/claude/signal_browser_batch/PLAN.md items 8-15 — per settled decision 9
# this ONE file carries every item-8..15 check; each item APPENDS its group,
# exactly as test_wave_sigsearch.tcl does for items 1-7).
#
# ============================================================================
# CONVENTIONS THIS FILE ESTABLISHES — items 9-15 inherit them
# ============================================================================
#
# GROUP PREFIXES: one two-letter prefix per item, never reused.
#     item  8  BS   the sidebar shell (this file's first group)
#     item  9  BT   the browser tree
#     item 10  BM   the row context menu
#     item 11  BH   hierarchy sync, browser -> schematic
#           ⚠ DECLARED DEVIATION from the block rule below: the BH2x/BH3x block
#           runs against a REAL LOADED SCHEMATIC FIXTURE in BOTH arms, not
#           against a throwaway Tk toplevel. Item 11's subject is the xschem
#           hierarchy walk, which needs no Tk at all — gating it on X would
#           have made the item's central claim (the rollback) X-only for no
#           reason. The Tk half is BH4x/BH5x, gated as usual.
#     item 12  BX   ...
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
# went with it). It DOES leave `::bgerror` overridden and the helper procs
# (`bs_packed`, `bs_order`, `bs_wait_mapped`, `bs_spy_on`/`bs_spy_off`,
# `send_key`, `viewer_ready`, `wvproc_body`) defined — items 9-15 append to this
# file and reuse them. It writes nothing to the tree beyond the standard
# `test_scratch` dir, which it removes on its last line.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_sigbrowser.tcl
# (the first is the one that measures anything; the second runs the source and
# pure arms only)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# Error-guarded call (test_wave_sigsearch's `pcall`, same `{args}` +
# `uplevel 1 $args` shape). REQUIRED, not stylistic: a sabotage can make the
# code under test THROW, and an unguarded throw hits the outer catch and aborts
# every remaining check — turning a one-target sabotage into a file-wide abort.
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}

# bgerror override. REQUIRED: the fixture groups build real Tk widgets with real
# bindings, and an error that escapes to background level pops the stock bgerror
# dialog — MODAL under X, which HANGS a headless run. Swallow it, print it, and
# COUNT IT AS A FAILURE: a silent swallow hides a defect, a re-throw hangs, only
# this shape does neither.
proc ::bgerror {msg} { puts "BGERROR: $msg"; incr ::fail }

# recent-files gate (issue 0119)
set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvsigbrowser]

# body of a named proc up to the closing brace in column 0, CODE LINES ONLY
# (test_wave_grid's helper, verbatim) — the bodies here carry comments naming
# the very strings being grepped, and a leg that counts prose is a leg that goes
# green on a deleted line of code.
proc wvproc_body {src name} {
  set i [string first "\nproc $name \{" $src]
  if {$i < 0} { return {} }
  set j [string first "\n\}\n" $src $i]
  if {$j < 0} { set j end }
  set out {}
  foreach line [split [string range $src $i $j] "\n"] {
    if {[regexp {^\s*#} $line]} { continue }
    lappend out $line
  }
  return [join $out "\n"]
}

# --- the two answers to the widget-state masquerade -------------------------
# NEVER THROWS: a destroyed widget and a hidden one both read 0, which is why
# every use of it is PAIRED with a `winfo exists` assertion.
proc bs_packed {w} { expr {[catch {pack info $w}] ? 0 : 1} }
# An ASSERTABLE STRING, never a boolean and never an exception. `pack info` does
# not report -before; the SLAVE ORDER is what -before set (the house oracle,
# test_wave_tabs.tcl). "a was never packed", "b was never packed", "there is no
# toplevel" and "they are packed the wrong way round" are FOUR DIFFERENT values.
proc bs_order {top a b} {
  if {[catch {pack slaves $top} sl]} { return "no-top" }
  set ia [lsearch -exact $sl $a]; set ib [lsearch -exact $sl $b]
  if {$ia < 0} { return "a-missing" }
  if {$ib < 0} { return "b-missing" }
  return [expr {$ia < $ib ? "a-before-b" : "a-after-b"}]
}

if {[catch {

# ============================================================================
# BS01-BS09 — SOURCE arm. Runs in BOTH arms: these read src/wave_viewer.tcl and
# doc/waveform_viewer_guide.html as text, so they need neither Tk nor X. They
# are the only item-8 checks a `--nogui` run can honour.
# ============================================================================
set wv [file join $repo src wave_viewer.tcl]
set fp [open $wv r]; set wsrc [read $fp]; close $fp

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

  # the `at_wait_mapped` idiom (item 5). Polls the PRECONDITION — mapping —
  # never the asserted value, and RETURNS the mapping so every caller can carry
  # it in its own tuple: a budget expiry then reads as "never mapped" and cannot
  # masquerade as a real failure.
  proc bs_wait_mapped {w {budget 1500}} {
    for {set t 0} {$t < $budget && ![winfo ismapped $w]} {incr t} {
      after 10 ; update
    }
    update
    return [winfo ismapped $w]
  }

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
  check {BS22 the frame's children are exactly item 9's set} \
    [lsort [winfo children .wvbs1.wvbrowser]] \
    [lsort [list .wvbs1.wvbrowser.ph .wvbs1.wvbrowser.wvsearch \
                 .wvbs1.wvbrowser.tb .wvbs1.wvbrowser.tvf \
                 .wvbs1.wvbrowser.wvfilter]]
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

  # WSLg-robust key delivery (test_wave_grid's helper): a bare `event generate`
  # loses the key when the focus round-trip has not completed (~1 run in 5).
  # Gate on Tk reporting the canvas as focus owner and retry until the effect
  # shows; report whether delivery was ever CONFIRMED so a stall can self-skip
  # rather than masquerade as a broken binding (the BAR25 rule).
  proc send_key {w ev done} {
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {![winfo exists $w]} { return 0 }
      focus -force $w
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[focus -displayof $w] eq $w} {
        event generate $w $ev
        update
        if {[uplevel 1 [list expr $done]]} { return 1 }
      }
      after 50
    }
    puts "  send_key: $ev delivery to $w never confirmed (WSLg focus stall)"
    return 0
  }
  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }

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
  [regexp -all {bind \$f\.tvf\.tv <Button-2>} $bt_build] 1
check {BT04 ...and Double-Button-1 exactly once, to the same proc} \
  [regexp -all {bind \$f\.tvf\.tv <Double-Button-1>} $bt_build] 1
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
  set BTTV $BTF.tvf.tv
  set BTSB $BTF.wvsearch
  set BTFB $BTF.wvfilter
  # ⚠ "NEVER BUILT" IS A DISTINCT VALUE FROM "BUILT AND EMPTY" (trap 1).
  check {BT20 before the build there is no tree at all} [bt_tree $BTTV] no-tree
  check {BT20 browser_build returns 1 and the tree now EXISTS but is EMPTY} \
    [list [pcall ::wviewer::browser_build wvbt .wvbt1] [winfo exists $BTTV] \
          [bt_tree $BTTV]] \
    [list 1 1 empty]

  check {BT21 the sidebar's children are exactly the item-9 set} \
    [lsort [winfo children $BTF]] \
    [lsort [list $BTF.ph $BTF.wvsearch $BTF.tb $BTF.tvf $BTF.wvfilter]] 
  check {BT21 the tree is a ttk::treeview, extended-select, with a scrollbar} \
    [list [winfo class $BTTV] [$BTTV cget -selectmode] [winfo exists $BTF.tvf.sb]] \
    [list Treeview extended 1]
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
  check {BT21 the sidebar's packing recipe is the exact five-slave stack} \
    [pack slaves $BTF] \
    [list $BTF.wvsearch $BTF.tb $BTF.ph $BTF.wvfilter $BTF.tvf]
  check {BT21 ...with the sides that put the tree between the toolbar and the filter} \
    [list [dict get [pack info $BTF.wvsearch] -side] \
          [dict get [pack info $BTF.tb] -side] \
          [dict get [pack info $BTF.ph] -side] \
          [dict get [pack info $BTF.wvfilter] -side] \
          [dict get [pack info $BTF.tvf] -side] \
          [dict get [pack info $BTF.tvf] -expand]] \
    [list top top bottom bottom top 1]

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
  set BTALL [list {s:v(out)|v(out)} {s:v(out2)|v(out2)} {g:x1|x1} {g:x1.x2|x2} \
                  {s:v(x1.x2.net5)|net5} {s:i(x1.x2.net5)|net5} {g:x1.y3|y3} \
                  {s:v(x1.y3.net5)|net5} {s:i(v1)|i(v1)} {s:net1|net1} \
                  {s:vsweep|vsweep}]
  # ⚠ SABOTAGE (c)'s LIVE ORACLE: real ttk nesting, depth-first, ids and texts.
  check {BT24 the populated tree is the grouped hierarchy, depth first} \
    [bt_tree $BTTV] $BTALL
  # ⚠ `pcall` IS MANDATORY ON EVERY HARD-CODED ROW ID. `$tv parent g:x1.x2`
  # THROWS "Item ... not found" when the row is absent, and an unguarded throw
  # here hits the file's outer catch and silently aborts every later check while
  # the fail count still looks plausible — item 6's lesson, and MEASURED again
  # by item 9's own sabotage (c), which aborted 51 checks the first time round.
  check {BT24 the group rows really are ttk PARENTS, with the right children} \
    [list [pcall $BTTV parent {s:v(x1.x2.net5)}] [pcall $BTTV parent {g:x1.x2}] \
          [pcall $BTTV children {g:x1}]] \
    [list g:x1.x2 g:x1 {g:x1.x2 g:x1.y3}]
  check {BT24 the status line reports shown-of-total, not just a name} \
    [string match {*8 of 8 signals*} [$BTF.ph cget -text]] 1

  # --- live search, driven through the ENTRY's own KeyRelease ---------------
  set BTSEARCH [list {s:v(out)|v(out)} {s:v(out2)|v(out2)} {g:x1|x1} {g:x1.x2|x2} \
                     {s:v(x1.x2.net5)|net5} {g:x1.y3|y3} {s:v(x1.y3.net5)|net5}]
  set bt_k [bt_type $BTSB {v(*)}]
  check {BT25 typing in the SEARCH entry live-filters the tree to the four v( names} \
    [list $bt_k [bt_tree $BTTV]] [list 1 $BTSEARCH]
  check {BT25 ...and the status line counts them} \
    [string match {*4 of 8 signals*} [$BTF.ph cget -text]] 1
  # the BUTTON route must agree (decision 5 ships both)
  $BTTV delete [$BTTV children {}]
  check {BT25 the tree really was emptied, so the button has work to do} \
    [bt_tree $BTTV] empty
  $BTSB.search invoke
  update
  check {BT25 the Search BUTTON rebuilds the same tree as the live route} \
    [bt_tree $BTTV] $BTSEARCH

  # --- ⚠⚠ BT26: THE AND, LIVE, THREE DIFFERENT ANSWERS ---------------------
  set BTAND [list {g:x1|x1} {g:x1.x2|x2} {s:v(x1.x2.net5)|net5} \
                  {g:x1.y3|y3} {s:v(x1.y3.net5)|net5}]
  set bt_k [bt_type $BTFB {*net5*}]
  check {BT26 the FILTER bar narrows the SEARCH bar's result — the live AND} \
    [list $bt_k [bt_tree $BTTV]] [list 1 $BTAND]
  check {BT26 ...and the count says two of eight, not four and not three} \
    [string match {*2 of 8 signals*} [$BTF.ph cget -text]] 1
  # THE DISCRIMINATOR: clearing the search bar must give a DIFFERENT tree from
  # the AND. A filter-ignoring break makes these two equal.
  set BTFILT [list {g:x1|x1} {g:x1.x2|x2} {s:v(x1.x2.net5)|net5} \
                   {s:i(x1.x2.net5)|net5} {g:x1.y3|y3} {s:v(x1.y3.net5)|net5}]
  set bt_k [bt_type $BTSB {}]
  check {BT26 the FILTER bar alone gives a THIRD, larger tree (i( is back)} \
    [list $bt_k [bt_tree $BTTV]] [list 1 $BTFILT]
  check_true {BT26 and the three trees are genuinely three different values} \
    [expr {$BTAND ne $BTFILT && $BTAND ne $BTSEARCH && $BTSEARCH ne $BTFILT}]
  set bt_k [bt_type $BTSB {v(*)}]
  check {BT26 re-typing the search puts the AND back} \
    [list $bt_k [bt_tree $BTTV]] [list 1 $BTAND]

  # --- decision 4, live: the error is VISIBLE and the tree is HELD ----------
  bt_syntax $BTFB RegExp
  set bt_k [bt_type $BTFB {net5(}]
  check {BT27 an invalid regexp writes a message to the STATUS line} \
    [list $bt_k [expr {[string first {parenthes} [$BTF.ph cget -text]] >= 0}]] \
    [list 1 1]
  check {BT27 ...and the tree is HELD, never blanked and never widened} \
    [bt_tree $BTTV] $BTAND
  check_true {BT27 the bar's own err label carries it too (even though clipped)} \
    [expr {[string first {parenthes} [$BTFB.err cget -text]] >= 0}]
  set bt_k [bt_type $BTFB {.*net5.*}]
  check {BT27 a valid regexp recovers, and the AND is back} \
    [list $bt_k [bt_tree $BTTV]] [list 1 $BTAND]
  bt_syntax $BTFB Shell
  bt_type $BTFB {}
  set bt_k [bt_type $BTSB {}]
  check {BT27 clearing both bars restores the whole tree} \
    [list $bt_k [bt_tree $BTTV]] [list 1 $BTALL]

  # --- the three plot gestures ---------------------------------------------
  bt_spy_on
  set bt_c [bt_centre $BTTV {s:v(out2)}]
  if {$bt_c eq {}} {
    puts "SKIPPED: BT28 MMB leg (row s:v(out2) never mapped)"
  } else {
    set ::bt_plot_calls {}
    # ⚠ THE REAL TK ROUTE, not the handler proc behind it (driver note f).
    event generate $BTTV <Button-2> -x [lindex $bt_c 0] -y [lindex $bt_c 1]
    update
    check {BT28 a MIDDLE-CLICK on a row plots exactly that one signal} \
      $::bt_plot_calls [list [list wvbt {v(out2)}]]
  }
  # DOUBLE-CLICK on a leaf
  set bt_c [bt_centre $BTTV {s:net1}]
  if {$bt_c eq {}} {
    puts "SKIPPED: BT29 double-click leg (row s:net1 never mapped)"
  } else {
    set ::bt_plot_calls {}
    bt_dclick $BTTV [lindex $bt_c 0] [lindex $bt_c 1]
    check {BT29 a DOUBLE-CLICK on a leaf plots exactly that one signal} \
      $::bt_plot_calls [list [list wvbt {net1}]]
  }
  # ...and on a GROUP it plots NOTHING (D3: ttk's expand/collapse owns that
  # gesture). THE NEGATIVE CONTROL for the double-click route.
  set bt_c [bt_centre $BTTV {g:x1}]
  if {$bt_c eq {}} {
    puts "SKIPPED: BT29 group leg (row g:x1 never mapped)"
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
  # THE PLOT BUTTON, with a multi-row selection
  pcall $BTTV selection set [list {s:v(out)} {s:net1}]
  set ::bt_plot_calls {}
  $BTF.tb.plot invoke
  update
  check {BT30 the Plot BUTTON plots every selected row, in row order} \
    $::bt_plot_calls [list [list wvbt {v(out) net1}]]
  # THE NEGATIVE CONTROL for the button: nothing selected records ZERO calls.
  pcall $BTTV selection set {}
  set ::bt_plot_calls {}
  $BTF.tb.plot invoke
  update
  check {BT31 the Plot button with an EMPTY selection plots nothing} \
    $::bt_plot_calls {}
  # ...and a click on empty canvas below the last row records zero too
  set ::bt_plot_calls {}
  event generate $BTTV <Button-2> -x 20 -y [expr {[winfo height $BTTV] - 3}]
  update
  check {BT31 a middle-click below the last row plots nothing} \
    $::bt_plot_calls {}
  # THE POSITIVE CONTROL, on the same spy, immediately after: the zeros above
  # are a rule, not a broken recorder.
  pcall $BTTV selection set [list {s:vsweep}]
  set ::bt_plot_calls {}
  $BTF.tb.plot invoke
  update
  check {BT31 ...and the very next real gesture still records (the spy is alive)} \
    $::bt_plot_calls [list [list wvbt {vsweep}]]
  # a GROUP selected + Plot button
  pcall $BTTV selection set [list {g:x1.x2}]
  set ::bt_plot_calls {}
  $BTF.tb.plot invoke
  update
  check {BT32 selecting a GROUP and pressing Plot plots its leaves, in row order} \
    $::bt_plot_calls [list [list wvbt {v(x1.x2.net5) i(x1.x2.net5)}]]
  # a selection spanning a group AND one of its own leaves plots that leaf ONCE
  pcall $BTTV selection set [list {g:x1.x2} {s:v(x1.x2.net5)}]
  set ::bt_plot_calls {}
  $BTF.tb.plot invoke
  update
  check {BT32 a group plus one of its own leaves does not plot that leaf twice} \
    $::bt_plot_calls [list [list wvbt {v(x1.x2.net5) i(x1.x2.net5)}]]
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
  check {BT33 a 2000-signal refresh really populated the tree} \
    [list $bt_ok [llength [$BTTV children {}]]] [list 1 20]
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
    set BTVTV $BTVF.tvf.tv
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
    check {BT40 ...and it populated from the REAL raw, vsweep included} \
      [bt_tree $BTVTV] \
      [list {s:vsweep|vsweep} {s:v(out)|v(out)} {g:x1|x1} {g:x1.x2|x2} \
            {s:v(x1.x2.net5)|net5} {s:i(x1.x2.net5)|net5} {g:x1.y3|y3} \
            {s:v(x1.y3.net5)|net5}]
    # THE 0173 LOAN, at the browser level: signal_list owns the bracket, and a
    # populate must leave the context exactly where it found it.
    check {BT41 the xschem context is back where it started after the populate} \
      [xschem get current_win_path] $BTCTX0
    check {BT42 a real hierarchical name really nests, x2 under x1} \
      [list [pcall $BTVTV parent {g:x1.x2}] [pcall $BTVTV parent {s:v(x1.x2.net5)}] \
            [pcall $BTVTV children {g:x1}]] \
      [list g:x1 g:x1.x2 {g:x1.x2 g:x1.y3}]

    # --- BT43: REAL gestures, REAL traces -----------------------------------
    proc bt_traces {token} {
      set n 0
      foreach G [dict get [wviewer::layout_for $token] graphs] {
        incr n [llength [wviewer::dget $G traces {}]]
      }
      return $n
    }
    set bt_n0 [bt_traces $tok]
    set bt_c [bt_centre $BTVTV {s:v(out)}]
    if {$bt_c eq {}} {
      puts "SKIPPED: BT43 real MMB leg (row s:v(out) never mapped)"
    } else {
      event generate $BTVTV <Button-2> -x [lindex $bt_c 0] -y [lindex $bt_c 1]
      update
      check_true {BT43 a REAL middle-click added a trace to the real model} \
        [expr {[bt_traces $tok] == $bt_n0 + 1}]
    }
    set bt_n1 [bt_traces $tok]
    set bt_c [bt_centre $BTVTV {s:v(x1.x2.net5)}]
    if {$bt_c eq {}} {
      puts "SKIPPED: BT43 real double-click leg (row never mapped)"
    } else {
      bt_dclick $BTVTV [lindex $bt_c 0] [lindex $bt_c 1]
      check_true {BT43 a REAL double-click added another one} \
        [expr {[bt_traces $tok] == $bt_n1 + 1}]
    }

    # --- BT44: the DESTINATION is honoured, through plot_signals (ruling 24) --
    set bt_g0 [llength [dict get [wviewer::layout_for $tok] graphs]]
    pcall ::wviewer::set_plot_dest newstrip $tok
    check {BT44 the window's destination really is newstrip now} \
      [pcall ::wviewer::plot_dest $tok] newstrip
    pcall $BTVTV selection set [list {s:i(x1.x2.net5)}]
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
    pcall $BTVTV selection set [list {s:v(x1.y3.net5)}]
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
    check {BT45 the sidebar is narrower than the canvas on a real viewer} \
      [expr {[winfo width $BTVF] < [winfo width $vdrw2]}] 1
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
  [list [regexp -all {bind \$f\.tvf\.tv <Button-3>} $bm_build] \
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
# what BM25's successor BH40/BH41 assert on the live widget.
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

  set BMF  .wvbm1.wvbrowser
  set BMTV $BMF.tvf.tv
  set BMM  .wvbm1.wvbrowsermenu
  set BMS  $BMM.dest
  pcall ::wviewer::browser_build wvbm .wvbm1
  bm_log_on
  pcall ::wviewer::browser_toggle 1 wvbm
  bm_log_off
  set ::wviewer::browsersigs(wvbm) $BTFIX
  pcall ::wviewer::browser_refresh wvbm
  update
  bs_wait_mapped $BMTV

  check {BM20 the fixture really is a populated tree before any menu exists} \
    [list [winfo exists $BMTV] [expr {[bt_tree $BMTV] ne {empty}}]] [list 1 1]
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
  set ::bm_popped {}
  check {BM21 an RMB on BLANK tree space below the last row refuses} \
    [pcall ::wviewer::browser_menu_post wvbm $BMTV 20 \
       [expr {[winfo height $BMTV] - 3}] 100 100] 0
  check {BM21 ...and posts NOTHING — still `absent`, never an empty menu} \
    [list [bm_menu_state $BMM] $::bm_popped] [list absent {}]

  # --- BM22: a post on a real leaf -----------------------------------------
  set bm_c [bm_centre $BMTV {s:v(out)}]
  if {$bm_c eq {}} {
    puts "SKIPPED: BM22-BM34 (row s:v(out) never mapped)"
  } else {
    set bm_x [lindex $bm_c 0] ; set bm_y [lindex $bm_c 1]
    set ::bm_popped {}
    check {BM22 an RMB on a leaf row posts, and returns 1} \
      [pcall ::wviewer::browser_menu_post wvbm $BMTV $bm_x $bm_y 771 553] 1
    # ORACLE VALUE 3 of 4
    check {BM22 the oracle now says `built:8` — present, eight entries, not mapped} \
      [bm_menu_state $BMM] built:8
    # THE ROOT-COORD CONTRACT: tk_popup gets %X/%Y, never the widget pixels
    check {BM22 tk_popup was handed the menu and the ROOT coords, not the tree pixels} \
      $::bm_popped [list $BMM 771 553]
    # ...and when the caller has no root coords they are DERIVED from the tree
    set ::bm_popped {}
    pcall ::wviewer::browser_menu_post wvbm $BMTV $bm_x $bm_y
    check {BM22 with no root coords supplied they are derived from the tree's origin} \
      $::bm_popped \
      [list $BMM [expr {[winfo rootx $BMTV] + $bm_x}] \
                 [expr {[winfo rooty $BMTV] + $bm_y}]]

    # --- BM23: the whole entry table, BY INDEX ------------------------------
    # ⚠ index 7 UPDATED BY ITEM 11, which consumes the reserved slot: with a
    # single row the target path is unambiguous, so `Descend to here` is now
    # `normal`. The rest of the table is byte-identical to item 10's, which is
    # the point of the reservation. The still-`disabled` state has NOT been
    # dropped from coverage — BH41 pins it for a disagreeing multi-row target.
    check {BM23 the menu is the exact eight-entry table, by index, types and states} \
      [bm_entries $BMM] \
      [list {command|v(out)|disabled} \
            {separator||} \
            {command|Plot (Append)|normal} \
            {cascade|Plot to|normal} \
            {command|Send to Add Trace...|normal} \
            {command|Copy name|normal} \
            {separator||} \
            {command|Descend to here|normal}]
    check {BM23 the header names the row the gate picked, and is the only greyed entry bar the last} \
      [list [pcall $BMM entrycget 0 -label] [pcall $BMM entrycget 0 -state] \
            [pcall $BMM entrycget 2 -state] [pcall $BMM entrycget 5 -state]] \
      [list {v(out)} disabled normal normal]

    # --- BM24: the cascade --------------------------------------------------
    check {BM24 the `Plot to` entry really is a cascade pointing at the submenu} \
      [list [pcall $BMM type 3] [pcall $BMM entrycget 3 -menu]] [list cascade $BMS]
    check {BM24 the submenu carries the four destinations, in dest_labels order} \
      [bm_entries $BMS] \
      [list {command|Append|normal} {command|Replace|normal} \
            {command|New Strip|normal} {command|New Tab|normal}]
    check {BM24 every cascade -command is fully resolved: token, ids AND code} \
      [list [pcall $BMS entrycget 0 -command] [pcall $BMS entrycget 1 -command] \
            [pcall $BMS entrycget 2 -command] [pcall $BMS entrycget 3 -command]] \
      [list [list wviewer::browser_plot_ids wvbm {s:v(out)} append] \
            [list wviewer::browser_plot_ids wvbm {s:v(out)} replace] \
            [list wviewer::browser_plot_ids wvbm {s:v(out)} newstrip] \
            [list wviewer::browser_plot_ids wvbm {s:v(out)} newtab]]
    # the TOP Plot entry passes NO override — it is the window's own policy
    check {BM24 the top Plot entry passes no override at all} \
      [pcall $BMM entrycget 2 -command] \
      [list wviewer::browser_plot_ids wvbm {s:v(out)}]

    # --- BM25: the slot item 11 CONSUMED ------------------------------------
    # ⚠ REWRITTEN BY ITEM 11. It pinned the reservation (disabled, no -command);
    # item 11 fills it, so the check has to move. Rewriting an inherited check
    # is the shape that hides a regression, so what it pins is UNCHANGED except
    # for the two properties item 11 owns: still LAST, still index 7, still
    # labelled `Descend to here` — now live, and wired to THIS click's ids. The
    # DISABLED state it used to pin is not lost: BH41 asserts it for a
    # disagreeing multi-row target, which is the only case that still greys it.
    check {BM25 `Descend to here` is LAST and item 11 has made it LIVE on this click's ids} \
      [list [pcall $BMM index end] [pcall $BMM entrycget 7 -label] \
            [pcall $BMM entrycget 7 -state] [pcall $BMM entrycget 7 -command]] \
      [list 7 {Descend to here} normal \
            [list wviewer::browser_descend_to wvbm {s:v(out)}]]

    # --- BM26: a multi-row target ------------------------------------------
    pcall $BMTV selection set [list {s:v(out)} {s:net1} {s:vsweep}]
    set bm_c2 [bm_centre $BMTV {s:net1}]
    if {$bm_c2 eq {}} {
      puts "SKIPPED: BM26 (row s:net1 never mapped)"
    } else {
      pcall ::wviewer::browser_menu_post wvbm $BMTV \
        [lindex $bm_c2 0] [lindex $bm_c2 1] 10 10
      check {BM26 a 3-row target headers `3 signals` and offers `Copy names (3)`} \
        [list [pcall $BMM entrycget 0 -label] [pcall $BMM entrycget 5 -label]] \
        [list {3 signals} {Copy names (3)}]
      check {BM26 ...and the entries act on all three ids, in row order} \
        [pcall $BMM entrycget 2 -command] \
        [list wviewer::browser_plot_ids wvbm {s:v(out) s:net1 s:vsweep}]
    }

    # --- BM27: the GROUP decision, made deliberately and stated -------------
    # RMB on a group DOES post and DOES act on its leaves — MMB's semantics,
    # not the double-click's refusal (item 9's D3 exists only to yield the
    # double-click to ttk's expand/collapse, and ttk owns no Button-3).
    pcall $BMTV selection set {}
    set bm_c3 [bm_centre $BMTV {g:x1.x2}]
    if {$bm_c3 eq {}} {
      puts "SKIPPED: BM27 (group row g:x1.x2 never mapped)"
    } else {
      check {BM27 an RMB on a GROUP posts (unlike the double-click, which refuses)} \
        [pcall ::wviewer::browser_menu_post wvbm $BMTV \
           [lindex $bm_c3 0] [lindex $bm_c3 1] 10 10] 1
      check {BM27 ...and it acts on the group's leaves, headered as `2 signals`} \
        [list [pcall $BMM entrycget 0 -label] [pcall $BMM entrycget 2 -command]] \
        [list {2 signals} [list wviewer::browser_plot_ids wvbm {g:x1.x2}]]
    }

    # --- BM28: the RMB never mutates the selection --------------------------
    pcall $BMTV selection set [list {s:net1}]
    set bm_sel0 [pcall $BMTV selection]
    pcall ::wviewer::browser_menu_post wvbm $BMTV $bm_x $bm_y 10 10
    check {BM28 an RMB on an UNSELECTED row leaves the selection untouched} \
      [pcall $BMTV selection] $bm_sel0
    set bm_c4 [bm_centre $BMTV {s:net1}]
    if {$bm_c4 ne {}} {
      pcall ::wviewer::browser_menu_post wvbm $BMTV \
        [lindex $bm_c4 0] [lindex $bm_c4 1] 10 10
      check {BM28 ...and on a SELECTED row it leaves it untouched too} \
        [pcall $BMTV selection] $bm_sel0
    }

    # --- BM29: item 9's in/out-of-selection rule, on the gate ---------------
    pcall $BMTV selection set [list {s:v(out)} {s:net1}]
    check {BM29 an RMB on a row INSIDE the selection targets the whole selection} \
      [pcall ::wviewer::browser_menu_ids wvbm $BMTV $bm_x $bm_y] \
      {s:v(out) s:net1}
    if {[bm_centre $BMTV {s:vsweep}] ne {}} {
      set bm_c5 [bm_centre $BMTV {s:vsweep}]
      check {BM29 ...and on a row OUTSIDE it targets that row alone} \
        [pcall ::wviewer::browser_menu_ids wvbm $BMTV \
           [lindex $bm_c5 0] [lindex $bm_c5 1]] \
        {s:vsweep}
    }
    pcall $BMTV selection set {}

    # --- BM30: the Plot entry, on a recorder with both controls -------------
    bm_spy_on
    pcall ::wviewer::browser_menu_post wvbm $BMTV $bm_x $bm_y 10 10
    set ::bm_plot_calls {}
    pcall $BMM invoke 2
    check {BM30 invoking `Plot` plots that row with NO override (the window's policy)} \
      $::bm_plot_calls [list [list wvbm {v(out)} {}]]
    # NEGATIVE CONTROL: a DISABLED entry records nothing...
    set ::bm_plot_calls {}
    pcall $BMM invoke 0
    pcall $BMM invoke 7
    check {BM30 invoking either DISABLED entry records nothing} $::bm_plot_calls {}
    # ...and the very next real invoke still records, so that zero is a rule
    set ::bm_plot_calls {}
    pcall $BMM invoke 2
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
    pcall $BMS invoke 2
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
    foreach bm_i {0 1 3} { pcall $BMS invoke $bm_i }
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
    pcall ::wviewer::browser_menu_post wvbm $BMTV $bm_x $bm_y 10 10
    set bm_lab_single [list [pcall $BMS entrycget 1 -label] \
                            [pcall $BMM entrycget 2 -label]]
    set ::wviewer::mode(wvbm) multi
    pcall ::wviewer::set_plot_dest replace wvbm
    pcall ::wviewer::browser_menu_post wvbm $BMTV $bm_x $bm_y 10 10
    set bm_lab_multi [list [pcall $BMS entrycget 1 -label] \
                           [pcall $BMM entrycget 2 -label]]
    check {BM32 under SINGLE both Replace surfaces read plainly} \
      $bm_lab_single [list Replace {Plot (Append)}]
    check {BM32 under MULTI both admit the declared limit, from the ONE shared proc} \
      $bm_lab_multi [list {Replace -> appends} {Plot (Replace -> appends)}]
    array unset ::wviewer::dest wvbm
    array unset ::wviewer::mode wvbm

    # --- BM33: Copy really reaches the clipboard ----------------------------
    pcall ::wviewer::browser_menu_post wvbm $BMTV $bm_x $bm_y 10 10
    catch {clipboard clear -displayof .wvbm1}
    catch {clipboard append -displayof .wvbm1 {__bm_sentinel__}}
    check {BM33 the sentinel proves the fixture can read its own clipboard} \
      [pcall clipboard get -displayof .wvbm1] {__bm_sentinel__}
    pcall $BMM invoke 5
    check {BM33 `Copy name` puts the full raw name on the clipboard} \
      [pcall clipboard get -displayof .wvbm1] {v(out)}
    check {BM33 ...and it says so on the sidebar's status line} \
      [string match {*copied 1 name*} [pcall $BMF.ph cget -text]] 1
    pcall $BMTV selection set [list {s:v(out)} {s:net1} {s:vsweep}]
    if {[bm_centre $BMTV {s:net1}] ne {}} {
      set bm_c6 [bm_centre $BMTV {s:net1}]
      pcall ::wviewer::browser_menu_post wvbm $BMTV \
        [lindex $bm_c6 0] [lindex $bm_c6 1] 10 10
      pcall $BMM invoke 5
      check {BM33 `Copy names (3)` joins the three names with newlines, in row order} \
        [pcall clipboard get -displayof .wvbm1] "v(out)\nnet1\nvsweep"
      check {BM33 ...and the status line pluralises} \
        [string match {*copied 3 names*} [pcall $BMF.ph cget -text]] 1
    }
    pcall $BMTV selection set {}
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
    pcall ::wviewer::browser_menu_unpost wvbm
    update
    set bm_seq {}
    lappend bm_seq [bm_menu_state $BMM]
    catch {
      set bm_m [wviewer::browser_menu_build wvbm [list {s:v(out)}]]
      lappend bm_seq [bm_menu_state $BMM]
      tk_popup $bm_m [expr {[winfo rootx $BMTV] + 40}] \
                     [expr {[winfo rooty $BMTV] + 40}]
      update
      lappend bm_seq [bm_menu_state $BMM]
      $bm_m unpost
      update
      lappend bm_seq [bm_menu_state $BMM]
    }
    set bm_un1 [pcall ::wviewer::browser_menu_unpost wvbm]
    set bm_un2 [pcall ::wviewer::browser_menu_unpost wvbm]
    update
    lappend bm_seq [bm_menu_state $BMM]
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
  check {BM35 the tree's bindtags are the measured four, and the canvas is not one of them} \
    [list [bindtags $BMTV] \
          [expr {[lsearch -exact [bindtags $BMTV] .wvbm1.drw] >= 0}]] \
    [list [list $BMTV Treeview .wvbm1 all] 0]
  check {BM35 the tree DOES carry the item-10 binding, so the zeros above are a rule} \
    [expr {[string first {wviewer::browser_menu_post wvbm} [bind $BMTV <Button-3>]] >= 0}] 1

  # --- BM36: teardown -------------------------------------------------------
  catch {wviewer::browser_menu_unpost wvbm}
  pcall ::wviewer::forget wvbm
  check {BM36 forget leaves no browser menu widget behind} \
    [list [winfo exists $BMM] [bm_menu_state $BMM]] [list 0 absent]
  destroy .wvbm1
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
    set BMVF  $vtop3.wvbrowser
    set BMVTV $BMVF.tvf.tv
    set BMVM  $vtop3.wvbrowsermenu
    set BMVS  $BMVM.dest
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
    bs_wait_mapped $BMVTV
    check {BM40 the real sidebar populated from the real raw} \
      [bt_tree $BMVTV] \
      [list {s:vsweep|vsweep} {s:v(out)|v(out)} {g:x1|x1} {g:x1.x2|x2} \
            {s:v(x1.x2.net5)|net5} {s:i(x1.x2.net5)|net5}]
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
    set bm_c [bm_centre $BMVTV {s:v(out)}]
    if {$bm_c eq {}} {
      puts "SKIPPED: BM42-BM45 (real row s:v(out) never mapped)"
    } else {
      set ::bm_b3_calls 0
      set ::bm_popped {}
      event generate $BMVTV <Button-3> -x [lindex $bm_c 0] -y [lindex $bm_c 1]
      update
      check {BM42 a REAL RMB on a browser row posts the menu and reaches the canvas ZERO times} \
        [list $::bm_b3_calls [expr {[lindex $::bm_popped 0] eq $BMVM}] \
              [bm_menu_state $BMVM]] \
        [list 0 1 built:8]

      # --- BM43: the real header, and a real trace -------------------------
      check {BM43 the real menu's header is the real raw name from `xschem raw list`} \
        [pcall $BMVM entrycget 0 -label] {v(out)}
      set bm_n0 [bm_traces $tok]
      pcall $BMVM invoke 2
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
      set bm_c7 [bm_centre $BMVTV {s:i(x1.x2.net5)}]
      if {$bm_c7 eq {}} {
        puts "SKIPPED: BM45 (real row s:i(x1.x2.net5) never mapped)"
      } else {
        catch {destroy $vtop3.wvadd}
        event generate $BMVTV <Button-3> \
          -x [lindex $bm_c7 0] -y [lindex $bm_c7 1]
        update
        pcall $BMVM invoke 4
        update
        check {BM45 `Send to Add Trace...` opens the dialog with the EXACT raw name prefilled} \
          [list [winfo exists $vtop3.wvadd] [pcall $vtop3.wvadd.expr get]] \
          [list 1 {i(x1.x2.net5)}]
        # ⚠ DECLARED LIMIT, ASSERTED AS A LIMIT: the Expression entry holds ONE
        # expression, so a multi-row target prefills the FIRST name only. A
        # batch goes through the dialog's own multi-select listbox (item 6).
        pcall $BMVTV selection set [list {s:v(out)} {s:i(x1.x2.net5)}]
        catch {destroy $vtop3.wvadd}
        pcall ::wviewer::browser_send_to_add_trace $tok \
          [list {s:v(out)} {s:i(x1.x2.net5)}]
        update
        check {BM45 with a MULTI-row target only the FIRST name is prefilled (declared limit)} \
          [list [winfo exists $vtop3.wvadd] [pcall $vtop3.wvadd.expr get]] \
          [list 1 {v(out)}]
        pcall $BMVTV selection set {}
        catch {destroy $vtop3.wvadd}
      }

      # --- BM46: the OTHER teardown route, a real tab switch ---------------
      event generate $BMVTV <Button-3> -x [lindex $bm_c 0] -y [lindex $bm_c 1]
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
    check {BM47 closing the viewer returns 1} [pcall ::wviewer::close $tok] 1
    check {BM47 ...and no browser menu survived the close} \
      [list [winfo exists $BMVM] [bm_menu_state $BMVM]] [list 0 absent]
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


# ============================================================================
# BH — signal-browser PLAN item 11: HIERARCHY SYNC, browser -> schematic
# ("Descend to here"). The user picks a browser row and the session's DESIGN
# window ends up at that point in the hierarchy, raised — or exactly where it
# started, with a reason, if any step fails.
#
# ⚠ THE POSITIVE CONTROL COMES FIRST, AND IT IS NOT DECORATION. The item's
# defining behaviour is a NEGATIVE claim — "sim_sch_path is EXACTLY as it
# started" — and that reads identically whether the rollback worked, the
# descend never started, or the fixture could not descend at all. BH20/BH21
# prove the SAME fixture in the SAME process DOES move; only then do BH23-BH25
# mean anything.
#
# ⚠ EVERY BEHAVIOURAL LEG ASSERTS ON THE WORLD (`xschem get sim_sch_path` read
# back), never on "the proc returned without throwing" — item 10's swallowed
# `clipboard clear` is the shape being defended against, and item 11 calls bare
# `xschem ...` verbs inside `catch` in exactly the same way.
#
# ⚠ THE PIVOT IS `sim_sch_path`, NEVER `sch_path` (settled decision 10), and
# with NO raw loaded the two getters are BYTE-IDENTICAL — which is why the
# PLAN's sabotage (b) as written would have fired nothing. BH29-BH31 read a raw
# and set raw_level so the divergence exists at all; they are the only teeth
# that sabotage has.
# ============================================================================

# --- BH01-BH09: PURE + SOURCE, both arms ------------------------------------

check {BH01 hier_split strips the trailing dot sim_sch_path really carries} \
  [list [pcall ::wviewer::hier_split {x1.x2.}] \
        [pcall ::wviewer::hier_split {x1.}] \
        [pcall ::wviewer::hier_split {x1.x2}]] \
  [list {x1 x2} {x1} {x1 x2}]
check {BH01 ...and the sim root, which sim_sch_path returns EMPTY, is {}} \
  [list [pcall ::wviewer::hier_split {}] [pcall ::wviewer::hier_split {.}]] \
  [list {} {}]

# EXACT, deliberately: this is what makes "an exact hit always wins" survive a
# design carrying both `x1` and `X1` (the wvhier fixture does).
check {BH02 hier_common is BYTE-exact: {X1} and {x1} share no prefix} \
  [list [pcall ::wviewer::hier_common {X1} {x1}] \
        [pcall ::wviewer::hier_common {X1 X2} {X1 y3}] \
        [pcall ::wviewer::hier_common {X1 X2} {X1 X2 z}]] \
  [list 0 1 2]

check {BH03 hier_plan: two ascends to the root, no descends} \
  [pcall ::wviewer::hier_plan {x1 x2} {}] [list 2 {}]
check {BH03 ...from the root, no ascends and two descends} \
  [pcall ::wviewer::hier_plan {} {x1 x2}] [list 0 {x1 x2}]
check {BH03 ...equal paths are {0 {}}, and a sibling is one up + one down} \
  [list [pcall ::wviewer::hier_plan {x1 x2} {x1 x2}] \
        [pcall ::wviewer::hier_plan {x1 x2} {x1 y3}]] \
  [list [list 0 {}] [list 1 {y3}]]

# THE MEASURED TRAP. ngspice lowercases, so a correct walk of `x1.x2` lands on
# the schematic's own `x1.X2`; a byte-exact final verify rejects its own
# correct result and rolls back (reproduced before the code was written).
check {BH04 hier_same, the FINAL VERIFY, is case-INSENSITIVE} \
  [list [pcall ::wviewer::hier_same {X1 X2} {x1 x2}] \
        [pcall ::wviewer::hier_same {x1 X2} {x1 x2}] \
        [pcall ::wviewer::hier_same {} {}]] \
  [list 1 1 1]
check {BH04 ...but it is still a comparison: different paths are NOT the same} \
  [list [pcall ::wviewer::hier_same {X1 X2} {x1 y3}] \
        [pcall ::wviewer::hier_same {X1} {x1 x2}] \
        [pcall ::wviewer::hier_same {X1} {}]] \
  [list 0 0 0]

# browser_target_path against a synthetic row snapshot (PURE — no Tk, no raw)
set ::wviewer::browserrows(wvbh) [wviewer::browser_rows [list \
  [wviewer::signal_entry {v(out)}] \
  [wviewer::signal_entry {v(x1.x2.net5)}] \
  [wviewer::signal_entry {i(x1.x2.net5)}] \
  [wviewer::signal_entry {v(x1.y3.net5)}]]]
check {BH05 a GROUP id IS the dotted instance path (decision 14)} \
  [list [pcall ::wviewer::browser_target_path wvbh {g:x1.x2}] \
        [pcall ::wviewer::browser_target_path wvbh {g:x1}]] \
  [list {ok x1.x2} {ok x1}]
check {BH05 a LEAF id resolves through its row's raw name, not through the id} \
  [pcall ::wviewer::browser_target_path wvbh {s:v(x1.x2.net5)}] {ok x1.x2}
check {BH05 a TOP-LEVEL signal is {ok {}} — a legitimate ascend to the sim root} \
  [pcall ::wviewer::browser_target_path wvbh {s:v(out)}] [list ok {}]
check {BH05 rows that AGREE on one path resolve; two leaves of the same group} \
  [pcall ::wviewer::browser_target_path wvbh {s:v(x1.x2.net5) s:i(x1.x2.net5)}] \
  {ok x1.x2}
# ruling 17: a disagreeing set is refused, NOT silently first-wins
check {BH05 rows that DISAGREE are an err, never a silent first-wins} \
  [pcall ::wviewer::browser_target_path wvbh {s:v(x1.x2.net5) s:v(x1.y3.net5)}] \
  {err {those rows are in different parts of the hierarchy}}
check {BH05 an empty selection and an unknown id are both errs, never a throw} \
  [list [lindex [pcall ::wviewer::browser_target_path wvbh {}] 0] \
        [lindex [pcall ::wviewer::browser_target_path wvbh {s:nosuch}] 0] \
        [lindex [pcall ::wviewer::browser_target_path wvNOSUCH {g:x1}] 0]] \
  [list err err err]
unset ::wviewer::browserrows(wvbh)

# THE DECISION-10 SOURCE GUARD, named as such: hier_now is the ONE pivot read
# and it must not be able to reach for sch_path.
set bh_now [wvproc_body $wsrc wviewer::hier_now]
check_true {BH06 hier_now was found in the source} [expr {$bh_now ne {}}]
check {BH06 hier_now reads sim_sch_path and NEVER sch_path (decision 10)} \
  [list [expr {[string first {sim_sch_path} $bh_now] >= 0}] \
        [regexp -all {(^|[^_])sch_path} $bh_now]] \
  [list 1 0]

set bh_idb [wvproc_body $wsrc wviewer::install_default_binds]
check_true {BH07 install_default_binds carries `bind WaveViewer <Key-E>`} \
  [expr {[string first {bind WaveViewer <Key-E>} $bh_idb] >= 0}]
check_true {BH07 ...calling browser_descend_at, and it BREAKs} \
  [regexp {bind WaveViewer <Key-E> \{wviewer::browser_descend_at %W; break\}} $bh_idb]

set bh_bb [wvproc_body $wsrc wviewer::browser_build]
check_true {BH08 browser_build binds <Key-E> on the TREE ITSELF (the tag cannot reach it)} \
  [regexp {bind \$f\.tvf\.tv <Key-E> \{wviewer::browser_descend_at %W ; break\}} $bh_bb]

set bh_mb [wvproc_body $wsrc wviewer::build_menubar]
check_true {BH09 build_menubar carries `-label {Descend to here} -accelerator E`} \
  [expr {[string first {-label {Descend to here} -accelerator E} $bh_mb] >= 0}]
check_true {BH09 ...on the VIEW cascade, calling browser_descend_here} \
  [expr {[string first "\$mb.view add command -label {Descend to here} -accelerator E" $bh_mb] >= 0 &&
         [string first {wviewer::browser_descend_here $token} $bh_mb] >= 0}]

# --- BH20-BH39: THE WALK, on a REAL fixture, in BOTH ARMS -------------------
# fixtures/wvhier: top holds `X1` AND `x1` (both instances of mid — this is
# what gives exact-first TEETH) plus the non-subcircuit `V9`; mid holds `X2`;
# leaf is a leaf.
set bh_fix [file join $repo tests headless fixtures wvhier]
set XSCHEM_LIBRARY_PATH "$bh_fix:[file join $repo xschem_library]"
set bh_load [pcall xschem load [file join $bh_fix wvhier_top.sch]]
proc bh_sim {} { set p {} ; catch {set p [xschem get sim_sch_path]} ; return $p }
check {BH20 (FIXTURE) the 3-level fixture loads and starts at its top} \
  [list [expr {![string match ERR:* $bh_load]}] [bh_sim] [pcall xschem get currsch]] \
  [list 1 {} 0]

# ⚠⚠ THE POSITIVE CONTROL. Without this the four rollback checks below are
# vacuous — "unmoved" would look identical to "could never move".
check {BH20 (POSITIVE CONTROL) hier_walk X1.X2 really MOVES the hierarchy} \
  [list [pcall ::wviewer::hier_walk X1.X2] [bh_sim]] \
  [list {ok X1.X2} {X1.X2.}]

# a sibling sync: no common prefix at all, so this is TWO ascends AND a
# descend — a leg a descend-only implementation cannot pass
check {BH21 sibling-to-sibling: X1.X2 -> x1 ascends twice, then descends} \
  [list [pcall ::wviewer::hier_walk x1] [bh_sim] [pcall xschem get currsch]] \
  [list {ok x1} {x1.} 1]

set bh_sel0 [pcall xschem selected_set]
set bh_cur0 [pcall xschem get currsch]
check {BH22 already-at-target is {ok already}, byte-exactly where it was} \
  [list [pcall ::wviewer::hier_walk x1] [bh_sim]] [list {ok already x1} {x1.}]
check {BH22 ...and it TOUCHED NOTHING: same selection, same level} \
  [list [pcall xschem selected_set] [pcall xschem get currsch]] \
  [list $bh_sel0 $bh_cur0]

# --- the ROLLBACK, the item's defining behaviour ----------------------------
# ⚠ THE TARGET IS CHOSEN SO THAT MOVEMENT REALLY HAPPENS FIRST. `X1.X2` ->
# `x1.nosuch` shares NO byte-exact prefix, so the walk ascends TWICE, descends
# into `x1`, and only then fails — a rollback that has to undo three steps. The
# obvious `X1` -> `X1.nosuch` would have been VACUOUS: the plan is a single
# descend that never happens, so "unmoved" is true whether the rollback exists
# or not (measured — that first cut passed with the rollback deleted).
pcall ::wviewer::hier_walk X1.X2
check {BH23 (fixture) we are two levels down, at X1.X2} \
  [list [bh_sim] [pcall xschem get currsch]] [list {X1.X2.} 2]
check {BH23 (ROLLBACK, AFTER REAL MOVEMENT) a bad last segment errs and names it} \
  [pcall ::wviewer::hier_walk x1.nosuch] \
  {err {no instance 'nosuch'} X1.X2}
check {BH23 ...and sim_sch_path is EXACTLY as it started — two ascends and a descend undone} \
  [list [bh_sim] [pcall xschem get currsch]] [list {X1.X2.} 2]

pcall ::wviewer::hier_walk {}
check {BH24 (fixture) we are back at the sim root} [list [bh_sim] [pcall xschem get currsch]] [list {} 0]
check {BH24 (ROLLBACK from the root) a bad segment errs and rolls back to the root} \
  [list [pcall ::wviewer::hier_walk X1.nosuch] [bh_sim] [pcall xschem get currsch]] \
  [list {err {no instance 'nosuch'} {}} {} 0]

# ⚠ THE NON-THROWING REFUSAL, driver note (d)'s exact shape: `descend -inst V9`
# resolves the instance fine (V9 exists), returns the STRING `0`, throws
# NOTHING, and does not move. A `catch`-only implementation reads that as
# success. Only the sim_sch_path readback sees it.
check {BH25 (ROLLBACK, NON-THROWING) descend -inst on a non-subcircuit is refused} \
  [pcall ::wviewer::hier_walk V9] {err {descend refused at 'V9'} {}}
check {BH25 ...and the raw verb really did return `0` without throwing} \
  [list [pcall xschem descend -inst V9] [bh_sim]] [list 0 {}]

# --- case, and exact-first ---------------------------------------------------
# ONE leg exercising all three: exact-first (`x1` exists byte-exactly),
# the case-insensitive retry (`x2` -> `X2`) and the case-insensitive final
# verify (landed `x1.X2` vs target `x1.x2`).
check {BH26 (CASE) a lowercased ngspice path lands, and reports the SCHEMATIC spelling} \
  [list [pcall ::wviewer::hier_walk x1.x2] [bh_sim]] [list {ok x1.X2} {x1.X2.}]

pcall ::wviewer::hier_walk {}
check {BH27 (EXACT-FIRST) X1 lands on X1, not on its lowercase twin} \
  [list [pcall ::wviewer::hier_walk X1] [bh_sim]] [list {ok X1} {X1.}]
pcall ::wviewer::hier_walk {}
check {BH27 ...and x1 lands on x1: a design with BOTH still resolves each} \
  [list [pcall ::wviewer::hier_walk x1] [bh_sim]] [list {ok x1} {x1.}]

# --- the declared [D]: vector instances (issue 0212) ------------------------
pcall ::wviewer::hier_walk {}
check {BH28 (VECTOR, declared [D]) a bracketed segment is REFUSED, naming 0212} \
  [pcall ::wviewer::hier_walk {x1[3].x2}] \
  {err {vector instance 'x1[3]' cannot be addressed (issue 0212)} {}}
# this one has ROLLBACK TEETH too: `X1` descends fine and only `X2[0]` refuses,
# so a missing rollback leaves the tree parked one level down
check {BH28 ...and a bracketed segment DEEPER in the path rolls back too} \
  [list [pcall ::wviewer::hier_walk {X1.X2[0]}] [bh_sim]] \
  [list {err {vector instance 'X2[0]' cannot be addressed (issue 0212)} {}} {}]
pcall ::wviewer::hier_walk {}
check {BH28 hier_resolve answers the VECTOR sentinel, not a wrong instance} \
  [list [pcall ::wviewer::hier_resolve {x1[3]}] [pcall ::wviewer::hier_resolve X1] \
        [pcall ::wviewer::hier_resolve x2]] \
  [list VECTOR X1 {}]

# --- BH29-BH31: SETTLED DECISION 10, and the ONLY teeth for sabotage (b) ----
# With no raw loaded `sch_waves_loaded()` is -1, the skip loop in the C getter
# never runs, and sim_sch_path is sch_path-minus-its-leading-dot BYTE FOR BYTE.
# So every leg above would pass just as happily on sch_path. These three read a
# raw and move raw_level so the two getters actually diverge.
pcall ::wviewer::hier_walk X1.X2
set bh_rawnew [pcall xschem raw new bh_item11.raw dc vsweep 0 1.0 0.5]
pcall xschem raw add {v(x1.x2.net5)} {vsweep 1 +}
# MEASURED: `xschem raw new` stamps the raw at the CURRENT level (2 here), so
# the level is set explicitly rather than assumed — an assumed 0 would have made
# BH29's "the two getters agree" leg pass for the wrong reason.
pcall xschem set raw_level 0
check {BH29 (fixture) a raw is loaded at level 0, at hierarchy depth 2} \
  [list $bh_rawnew [pcall xschem raw loaded] [pcall xschem get currsch]] \
  [list 1 0 2]
check {BH29 at raw_level 0 the two getters AGREE — this is why the PLAN's sabotage (b) fired nothing} \
  [list [bh_sim] [pcall xschem get sch_path]] [list {X1.X2.} {.X1.X2.}]

check {BH30 raw_level 1 makes them DIVERGE: sim `X2.` vs sch `.X1.X2.`} \
  [list [pcall xschem set raw_level 1] [bh_sim] [pcall xschem get sch_path]] \
  [list 1 {X2.} {.X1.X2.}]
check {BH30 ...and hier_now follows the SIM origin, one segment not two} \
  [pcall ::wviewer::hier_now] {X2}

# THE DISCRIMINATOR. Under the sim origin we are already at `X2`, so this is a
# no-op that touches nothing. Under sch_path we would read {X1 X2}, ascend
# twice and try to descend into an `X2` that does not exist at the top — an
# err and a rollback.
check {BH31 (DECISION 10) `X2` under the sim origin is a NO-OP, not a two-level move} \
  [list [pcall ::wviewer::hier_walk X2] [bh_sim] [pcall xschem get currsch]] \
  [list {ok already X2} {X2.} 2]

pcall xschem set raw_level 0
pcall ::wviewer::hier_walk {}

# --- BH32: THE ORIGIN GUARD --------------------------------------------------
# The item's only claim a readback cannot check: when the design window's top
# is ABOVE the session's design and no raw is loaded there, the pivot and the
# verify share the same wrong origin. Only the guard can see it.
check {BH32 with a raw loaded in THIS context the origin is genuinely sim-relative} \
  [list [pcall xschem raw loaded] [pcall ::wviewer::hier_origin_ok bh_notasession]] \
  [list 0 1]
pcall xschem raw clear
check {BH32 (control) the raw really is gone, so the branch below is the other one} \
  [pcall xschem raw loaded] -1

set bh_defs [file join $scratch bh_library.defs]
set bh_f [open $bh_defs w]
puts $bh_f "DEFINE wvhier $bh_fix"
close $bh_f
set XSCHEM_LIBRARY_DEFS $bh_defs
set bh_stTOP [dict merge [ase::state_default] \
  [dict create design [dict create lib wvhier cell wvhier_top view schematic]]]
set bh_stMID [dict merge [ase::state_default] \
  [dict create design [dict create lib wvhier cell wvhier_mid view schematic]]]
pcall ase::state_save [file join $scratch bh_top.state] $bh_stTOP
pcall ase::state_save [file join $scratch bh_mid.state] $bh_stMID
pcall ase::session_open bh/wvhier_top/schematic [file join $scratch bh_top.state]
pcall ase::session_open bh/wvhier_mid/schematic [file join $scratch bh_mid.state]
check {BH32 (control) both sessions' designs really resolve to the fixture files} \
  [list [file tail [pcall ase::ui::design_path bh/wvhier_top/schematic]] \
        [file tail [pcall ase::ui::design_path bh/wvhier_mid/schematic]]] \
  [list wvhier_top.sch wvhier_mid.sch]
check {BH32 at the top, with the session's design AS the top, the guard passes} \
  [list [pcall ase::ui::sod_base_level bh/wvhier_top/schematic] \
        [pcall ::wviewer::hier_origin_ok bh/wvhier_top/schematic]] \
  [list 0 1]
pcall ::wviewer::hier_walk X1
check {BH32 (THE ANCESTOR CASE) design at stack level 1 -> the guard REFUSES} \
  [list [pcall ase::ui::sod_base_level bh/wvhier_mid/schematic] \
        [pcall ::wviewer::hier_origin_ok bh/wvhier_mid/schematic]] \
  [list 1 0]
pcall ::wviewer::hier_walk {}
# DECLARED LIMIT, asserted rather than pretended away: sod_base_level answers 0
# when the session's design is not in the stack AT ALL (its own documented
# rule, which keeps a scripted/stubbed pick on the shipped path), so the guard
# passes there too. That hole is sod_base_level's, is pre-existing, and item 11
# does not restructure ase_window.tcl to close it.
check {BH32 (DECLARED LIMIT) design not in the stack at all -> sod_base_level 0, guard passes} \
  [list [pcall ase::ui::sod_base_level bh/wvhier_mid/schematic] \
        [pcall ::wviewer::hier_origin_ok bh/wvhier_mid/schematic]] \
  [list 0 1]

# --- BH40-BH54: the Tk half -------------------------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # BH40/BH41 are BM25's SUCCESSOR — item 11 consumes the reserved slot, so the
  # inherited check has to be rewritten, and the replacement pins BOTH states.
  toplevel .wvbh1
  wm withdraw .wvbh1
  pcall ::wviewer::browser_build wvbh1 .wvbh1
  dict set ::wviewer::windows wvbh1 [dict create top .wvbh1 win_path .wvbh1.drw]
  set BHTV .wvbh1.wvbrowser.tvf.tv
  set ::wviewer::browserrows(wvbh1) [wviewer::browser_rows [list \
    [wviewer::signal_entry {v(out)}] \
    [wviewer::signal_entry {v(x1.x2.net5)}] \
    [wviewer::signal_entry {v(x1.y3.net5)}]]]
  set BHM [pcall ::wviewer::browser_menu_build wvbh1 {g:x1.x2}]
  check {BH40 `Descend to here` is STILL last and still index 7} \
    [list [pcall $BHM index end] [pcall $BHM entrycget 7 -label]] \
    [list 7 {Descend to here}]
  check {BH40 ...and item 11 has made it LIVE, wired to browser_descend_to} \
    [list [pcall $BHM entrycget 7 -state] [pcall $BHM entrycget 7 -command]] \
    [list normal [list wviewer::browser_descend_to wvbh1 {g:x1.x2}]]
  set BHM2 [pcall ::wviewer::browser_menu_build wvbh1 \
              {s:v(x1.x2.net5) s:v(x1.y3.net5)}]
  check {BH41 a DISAGREEING multi-row target leaves it disabled with NO command} \
    [list [pcall $BHM2 entrycget 7 -label] [pcall $BHM2 entrycget 7 -state] \
          [pcall $BHM2 entrycget 7 -command]] \
    [list {Descend to here} disabled {}]
  set BHM3 [pcall ::wviewer::browser_menu_build wvbh1 \
              {s:v(x1.x2.net5) g:x1.x2}]
  check {BH41 ...but an AGREEING multi-row target is live} \
    [list [pcall $BHM3 entrycget 7 -state] [pcall $BHM3 entrycget 7 -command]] \
    [list normal [list wviewer::browser_descend_to wvbh1 {s:v(x1.x2.net5) g:x1.x2}]]

  # ⚠ THE REAL-KEY LEGS ARE NOT HERE, AND THAT IS MEASURED, NOT TASTE. A
  # throwaway toplevel is not the WM's active window, so `focus -displayof`
  # never reports its widgets as the focus owner and `send_key` correctly
  # reports `delivery ... never confirmed (WSLg focus stall)` — the gate doing
  # its job, not a broken binding. Item 10's Button-3 legs work here because
  # pointer events need no focus; keys do. BH43-BH45 therefore run on the REAL
  # viewer below, which is also where the user actually is.
  # What DOES belong here is the structural reason the item binds twice.
  check {BH42 the canvas is NOT in the tree's bindtags, which is why both binds exist} \
    [list [expr {[lsearch -exact [bindtags $BHTV] .wvbh1.drw] >= 0}] \
          [expr {[lsearch -exact [bindtags $BHTV] WaveViewer] >= 0}]] \
    [list 0 0]
  check {BH42 the tree DOES carry item 11's own <Key-E>, so the zeros above are a rule} \
    [expr {[string first {wviewer::browser_descend_at} [bind $BHTV <Key-E>]] >= 0}] 1
  check {BH42 the WaveViewer tag carries <Key-E> on the LIVE tag too} \
    [expr {[string first {browser_descend_at} [bind WaveViewer <Key-E>]] >= 0}] 1

  pcall ::wviewer::forget wvbh1
  catch {unset ::wviewer::browserrows(wvbh1)}
  destroy .wvbh1

} else {
  puts "SKIPPED: BH4x group (Tk/X arm only)"
}

# --- BH50-BH54: END TO END, a real viewer AND a real design window ----------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set bh_tok [ase::session_key wvhier wvhier_top schematic]
  pcall ase::session_open $bh_tok [file join $scratch bh_top.state]
  set bh_open [pcall ::wviewer::open $bh_tok]
  set bh_vtop [wviewer::window_for $bh_tok]
  if {$bh_open ne 1 || $bh_vtop eq {} || ![viewer_ready $bh_vtop]} {
    puts "SKIPPED: BH5x group (the wvhier viewer never opened/mapped)"
    catch {wviewer::close $bh_tok}
  } else {
    # a REAL raw in the VIEWER's own context (the BTV/BMV idiom), carrying both
    # a two-level path and a one-level one
    set bh_main [xschem get current_win_path]
    xschem new_schematic switch $bh_vtop.drw
    pcall xschem raw new bh_e2e.raw dc vsweep 0 1.0 0.5
    foreach bh_n {v(out) v(x1.x2.net5) v(x1.topsig)} {
      pcall xschem raw add $bh_n {vsweep 1 +}
    }
    xschem new_schematic switch $bh_main
    pcall ::wviewer::browser_toggle 1 $bh_tok
    update
    set bh_rows0 {}
    catch {set bh_rows0 $::wviewer::browserrows($bh_tok)}
    check {BH50 (fixture) the browser populated from the real raw, x1.x2 among them} \
      [list [expr {[llength $bh_rows0] > 0}] \
            [lindex [pcall ::wviewer::browser_target_path $bh_tok {g:x1.x2}] 1]] \
      [list 1 x1.x2]

    # THE ITEM, END TO END: invoke the REAL menu entry, then assert on THE
    # WORLD — the design window's own sim_sch_path, read back.
    set bh_m [pcall ::wviewer::browser_menu_build $bh_tok {g:x1.x2}]
    set bh_inv [pcall $bh_m invoke 7]
    update
    set bh_dwin {}
    catch {set bh_dwin [xschem get current_win_path]}
    check {BH50 invoking `Descend to here` lands the DESIGN window at x1.X2} \
      [list [pcall xschem get sim_sch_path] [pcall xschem get currsch]] \
      [list {x1.X2.} 2]
    check {BH50 ...and the context really is the DESIGN window, not the viewer} \
      [list [expr {$bh_dwin ne {} && $bh_dwin ne "$bh_vtop.drw"}] \
            [file tail [pcall xschem get schname 0]]] \
      [list 1 wvhier_top.sch]
    # the status line SAYS SO, in the SCHEMATIC's spelling, so a case fold is
    # visible to the user rather than silent
    check {BH50 the browser status line reports the landing} \
      [pcall $bh_vtop.wvbrowser.ph cget -text] \
      "Signal Browser\ndescended to x1.X2"

    # item 9's D6: the tree is a SNAPSHOT of the VIEWER's raw, and a design
    # descend touches neither — so nothing went stale.
    set bh_rows1 {}
    catch {set bh_rows1 $::wviewer::browserrows($bh_tok)}
    check {BH52 the browser tree is UNCHANGED by the sync (item 9's D6 holds)} \
      [expr {$bh_rows1 eq $bh_rows0}] 1

    check {BH53 the design window's toplevel is mapped after the raise} \
      [list [bs_wait_mapped .] [winfo ismapped .]] [list 1 1]

    # already-at-target: a byte-exact target this time (`x1` exists exactly),
    # so this really is the no-op path — and it STILL raises and STILL says so.
    set bh_m2 [pcall ::wviewer::browser_menu_build $bh_tok {g:x1}]
    pcall $bh_m2 invoke 7
    update
    check {BH54 (fixture) a one-level sync first moves there} \
      [pcall xschem get sim_sch_path] {x1.}
    pcall $bh_m2 invoke 7
    update
    check {BH54 already-at-target is a no-op that still lands and still reports} \
      [list [pcall xschem get sim_sch_path] \
            [pcall $bh_vtop.wvbrowser.ph cget -text]] \
      [list {x1.} "Signal Browser\nalready at x1"]
    check {BH54 ...and it still raised the design window} [winfo ismapped .] 1

    # A bad path through the REAL command surface: refused, reported, rolled
    # back. ⚠ THE TARGET IS `X1.nosuch` WHILE WE SIT AT `x1`, deliberately: the
    # byte-exact prefix is EMPTY, so the walk really ascends out of `x1` and
    # descends into `X1` before failing. `x1.nosuch` would have been the vacuous
    # shape §3.5 of the receipt describes — measured: with the rollback deleted,
    # a `x1.nosuch` target left this check GREEN.
    set ::wviewer::browserrows($bh_tok) [wviewer::browser_rows [list \
      [wviewer::signal_entry {v(X1.nosuch.net5)}]]]
    set bh_m3 [pcall ::wviewer::browser_menu_build $bh_tok {g:X1.nosuch}]
    set bh_bad [pcall $bh_m3 invoke 7]
    update
    check {BH51 a bad path through the REAL entry ROLLS BACK and says why} \
      [list $bh_bad [pcall xschem get sim_sch_path] \
            [pcall $bh_vtop.wvbrowser.ph cget -text]] \
      [list 0 {x1.} "Signal Browser\ndescend to 'X1.nosuch' failed: no instance 'nosuch' (returned to x1)"]
    set ::wviewer::browserrows($bh_tok) $bh_rows0

    # --- BH43/BH44/BH45: THE REAL KEY, on the REAL viewer --------------------
    # ⚠ A DELEGATING rename recorder (item 10's shape), so both halves are
    # observable: that the binding fired AND that the world moved. A swallowing
    # recorder would have made the world half untestable, and a world-only
    # assertion could not tell the key from the menu.
    set ::bh_calls 0
    rename ::wviewer::browser_descend_at ::wviewer::__bh_real_descend_at
    proc ::wviewer::browser_descend_at {W} {
      incr ::bh_calls
      return [::wviewer::__bh_real_descend_at $W]
    }
    set BHVTV $bh_vtop.wvbrowser.tvf.tv
    set BHVE  $bh_vtop.wvbrowser.wvsearch.pat
    # ⚠ REQUIRED BETWEEN LEGS, and it is the item's own doing: a successful sync
    # RAISES AND ACTIVATES THE DESIGN WINDOW, which takes the WM focus away from
    # the viewer. Without this the next `send_key` correctly reports a delivery
    # stall and the leg self-skips (observed). Re-raise the viewer first, the
    # same idiom the item itself uses.
    proc bh_focus_viewer {top} {
      catch {raise_activate_toplevel $top}
      catch {focus -force $top}
      update
      return [bs_wait_mapped $top]
    }
    bh_focus_viewer $bh_vtop
    pcall ::wviewer::hier_walk {}
    pcall $BHVTV selection set {g:x1.x2}
    set ::bh_calls 0
    # the CANVAS route (the `WaveViewer` bindtag). Waiting on the WORLD, not on
    # the recorder: the key has not done its job until sim_sch_path has moved.
    set bh_k1 [send_key $bh_vtop.drw <Key-E> {[xschem get sim_sch_path] eq {x1.X2.}}]
    if {!$bh_k1} {
      puts "SKIPPED: BH43 (WSLg key-delivery stall on the viewer canvas)"
    } else {
      check {BH43 a REAL <Key-E> on the CANVAS descends the design window} \
        [list [expr {$::bh_calls > 0}] [pcall xschem get sim_sch_path]] \
        [list 1 {x1.X2.}]
      # NEGATIVE CONTROL: same recorder, same widget, a key that is not bound
      set bh_c1 $::bh_calls
      for {set bh_i 0} {$bh_i < 6} {incr bh_i} {
        focus -force $bh_vtop.drw ; update
        catch {event generate $bh_vtop.drw <Key-D>} ; update
      }
      check {BH43 (NEGATIVE CONTROL) the same recorder reads ZERO more for an unbound <Key-D>} \
        [expr {$::bh_calls - $bh_c1}] 0
    }
    # the TREE route — the one a WaveViewer-only bind could never serve, since
    # the canvas is not in the tree's bindtags (BH42)
    bh_focus_viewer $bh_vtop
    pcall ::wviewer::hier_walk {}
    pcall $BHVTV selection set {g:x1}
    set ::bh_calls 0
    set bh_k2 [send_key $BHVTV <Key-E> {[xschem get sim_sch_path] eq {x1.}}]
    if {!$bh_k2} {
      puts "SKIPPED: BH44 (WSLg key-delivery stall on the browser tree)"
    } else {
      check {BH44 a REAL <Key-E> on the TREE descends the design window too} \
        [list [expr {$::bh_calls > 0}] [pcall xschem get sim_sch_path]] \
        [list 1 {x1.}]
    }
    # the searchbar Entry carries no WaveViewer tag and is not the tree, so
    # typing E there must NOT fire the command — with the delivery PROVEN by
    # the entry's own text, so a stalled key cannot masquerade as a refusal
    if {![winfo exists $BHVE]} {
      puts "SKIPPED: BH45 (the viewer's searchbar pattern entry was not found)"
    } else {
      bh_focus_viewer $bh_vtop
      pcall $BHVE delete 0 end
      set bh_c2 $::bh_calls
      set bh_k3 [send_key $BHVE <Key-E> {[string length [$BHVE get]] > 0}]
      if {!$bh_k3} {
        puts "SKIPPED: BH45 (WSLg key-delivery stall on the search entry)"
      } else {
        check {BH45 `E` TYPED INTO THE SEARCH ENTRY does not fire the command...} \
          [expr {$::bh_calls - $bh_c2}] 0
        check {BH45 ...and the key really WAS delivered — the entry now holds it} \
          [pcall $BHVE get] E
      }
      pcall $BHVE delete 0 end
      pcall ::wviewer::browser_refresh $bh_tok
    }
    rename ::wviewer::browser_descend_at {}
    rename ::wviewer::__bh_real_descend_at ::wviewer::browser_descend_at
    check {BH45 the real browser_descend_at is back in place} \
      [list [expr {[info commands ::wviewer::__bh_real_descend_at] eq {}}] \
            [expr {[info commands ::wviewer::browser_descend_at] ne {}}]] \
      [list 1 1]

    catch {wviewer::close $bh_tok}
  }

} else {
  puts "SKIPPED: BH5x group (Tk/X arm only)"
}

# ============================================================================
# BX01-BX52 — item 12: hierarchy sync SCHEMATIC -> BROWSER
# ("Show in Signal Browser", Tools menu + Ctrl-5). The MIRROR of item 11.
#
# ⚠⚠ THE ORACLE, and it is the reason this block can make the claim at all
# (driver note (d) / ruling 26). "The node is VISIBLE" has FOUR failure modes
# that `selection` cannot tell apart and that `bbox` alone reports IDENTICALLY:
#   * the node is not in the tree at all              -> `absent`
#   * it is there but an ancestor is COLLAPSED        -> `collapsed`
#   * ancestors are open but the tree is SCROLLED off -> `offscreen`
#   * the widget itself was never mapped / was
#     withdrawn (bbox answers for a once-mapped,
#     now-withdrawn tree, so bbox CANNOT see this)    -> `unmapped`
# plus `root` (id {}, which `exists` reports TRUE) and `no-tree`. SEVEN
# assertable strings, every one of them measured on this fixture, in the shape
# item 9's `bs_order` and item 10's `bm_menu_state` established. It never throws.
#
# ⚠ THE VACUOUS-CHECK TRAP (driver note (c)) — all three PLAN sabotages look
# identical to "the command did nothing". The POSITIVE CONTROLS come FIRST and
# are named as such: BX30 proves collapsed->visible really happens on the good
# path, BX32 proves offscreen->visible, BX34 asserts the selection is EMPTY
# before claiming the fallback moved it, and BX40 asserts the sidebar is
# `browser_shown` 0 AND absent from `pack info` before claiming it un-hid.
#
# ⚠ WHAT THIS BLOCK DOES NOT CLAIM, stated rather than hidden: settled decision
# 10's PIVOT CHOICE is NOT behaviourally proven here, for the same reason item
# 11 could not prove it — in the DESIGN window no raw is loaded, so
# `sim_sch_path` and `sch_path` are byte-identical and swapping the getter fires
# nothing. What IS proven is the level>0 ORIGIN MAPPING (BX48: the same
# hierarchy position answers `x1.x2` under a level-0 session and `x2` under a
# level-1 one) plus a source guard that the shipped bodies contain zero
# `sch_path` reads (BX09). Claim narrowed, not check invented (ruling 17).
# ============================================================================

# SEVEN-VALUED, NEVER THROWS. `unmapped` is checked BEFORE bbox precisely
# because bbox cannot see it.
proc bx_vis {tv id} {
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

# ⚠ THE MAPPING-AWARE WRAPPER, and it is item 5's rule not a fudge: POLL THE
# PRECONDITION, NEVER THE ASSERTED VALUE. Under WSLg a freshly raised viewer can
# still report `winfo ismapped` 0 for a few milliseconds, and `bx_vis` would then
# answer `unmapped` for a node that is perfectly visible a moment later.
# MEASURED: BX42's second leg flaked exactly that way, 1 run in 4 — the same
# shape as item 11's own BH54 `winfo ismapped .` flap. This waits for the
# MAPPING (the precondition) and then asks the oracle once; a genuinely unmapped
# widget still reads `unmapped` after the budget, so no failure mode is hidden.
# The throwaway-toplevel group deliberately keeps the RAW `bx_vis`, because
# BX33's whole point is to observe `unmapped` on purpose.
proc bx_vis_m {tv id} {
  if {![catch {winfo ismapped $tv} m] && $m} { return [bx_vis $tv $id] }
  # a BOUNDED wait -- 2s is orders of magnitude more than a map race needs, and
  # bs_wait_mapped's 1500-iteration default would spin `update` (and therefore
  # redraws) for 15 SECONDS on a widget that is genuinely unmapped
  catch {bs_wait_mapped $tv 200}
  return [bx_vis $tv $id]
}

# --- BX01-BX14: PURE + SOURCE, BOTH ARMS ------------------------------------
# `browser_node_for` and `browser_origin_drop` take no Tk and no xschem, which
# is exactly why the deepest-ancestor fallback and the origin arithmetic — the
# two things sabotages (b) and (d) attack — are provable in `--nogui`.
set bx_rows [wviewer::browser_rows [list \
  [wviewer::signal_entry {v(x1.x2.net5)}] \
  [wviewer::signal_entry {v(x1.y3.net7)}] \
  [wviewer::signal_entry {v(out)}]]]
check {BX01 (fixture) the row set really carries the two group levels} \
  [list [wviewer::browser_kind $bx_rows g:x1] \
        [wviewer::browser_kind $bx_rows g:x1.x2] \
        [wviewer::browser_kind $bx_rows {s:v(out)}]] \
  [list group group leaf]
check {BX01 an EXACT two-segment path finds the deep group} \
  [pcall ::wviewer::browser_node_for $bx_rows {x1 x2}] {g:x1.x2 2}
# ⚠ THE CASE LEG, and it is the one that decides whether this item works on a
# real ngspice raw at all: ngspice lowercases the raw while sim_sch_path reports
# the SCHEMATIC's own `X1.X2`. Sabotage (d) deletes the -nocase candidate.
check {BX02 (CASE) the SCHEMATIC's X1.X2 finds the raw's lowercase x1.x2} \
  [pcall ::wviewer::browser_node_for $bx_rows {X1 X2}] {g:x1.x2 2}
set bx_rows2 [wviewer::browser_rows [list \
  [wviewer::signal_entry {v(x1.a)}] \
  [wviewer::signal_entry {v(X1.b)}]]]
check {BX03 (EXACT-FIRST) a level carrying BOTH x1 and X1 resolves each to itself} \
  [list [pcall ::wviewer::browser_node_for $bx_rows2 {x1}] \
        [pcall ::wviewer::browser_node_for $bx_rows2 {X1}]] \
  [list {g:x1 1} {g:X1 1}]
# ⚠ THE DEEPEST-ANCESTOR FALLBACK — sabotage (b)'s pure target. The PLAN's
# "select the deepest ancestor that does exist" IS this return value.
check {BX04 (FALLBACK) a path one segment too deep answers the deepest ancestor} \
  [pcall ::wviewer::browser_node_for $bx_rows {X1 X2 X9}] {g:x1.x2 2}
check {BX04 ...and two segments too deep answers the same node, matched 2} \
  [pcall ::wviewer::browser_node_for $bx_rows {x1 x2 x9 x8}] {g:x1.x2 2}
check {BX05 a path with nothing in common answers {} and matched 0} \
  [pcall ::wviewer::browser_node_for $bx_rows {Z9 Q1}] {{} 0}
check {BX06 an EMPTY segment list is {} 0 — the sim-root case, handled elsewhere} \
  [pcall ::wviewer::browser_node_for $bx_rows {}] {{} 0}
# a leaf is a SIGNAL, not an instance: `v(out)` must not make `out` descendable,
# and `net5` must not extend the path past its own group
check {BX07 (DECLARED LIMIT) leaves are NOT matched — a top-level signal name} \
  [pcall ::wviewer::browser_node_for $bx_rows {out}] {{} 0}
check {BX07 ...nor a leaf under a real group: x1.x2.net5 stops at x1.x2} \
  [pcall ::wviewer::browser_node_for $bx_rows {x1 x2 net5}] {g:x1.x2 2}
# THE ORIGIN ARITHMETIC (issue 0168's mapping, without touching sch_path)
check {BX08 browser_origin_drop: no raw in the design ctx -> drop `level` segments} \
  [list [pcall ::wviewer::browser_origin_drop 0 -1] \
        [pcall ::wviewer::browser_origin_drop 1 -1] \
        [pcall ::wviewer::browser_origin_drop 2 -1]] \
  [list 0 1 2]
check {BX08 ...a raw AT the session's level cancels out; below it is NEGATIVE (refused)} \
  [list [pcall ::wviewer::browser_origin_drop 1 1] \
        [pcall ::wviewer::browser_origin_drop 2 1] \
        [pcall ::wviewer::browser_origin_drop 0 1]] \
  [list 0 1 -1]
check {BX08 ...and junk from either getter degrades to the level-0/no-raw case} \
  [list [pcall ::wviewer::browser_origin_drop {} {}] \
        [pcall ::wviewer::browser_origin_drop -3 xx]] \
  [list 0 0]

# --- BX09-BX13: the SOURCE guards -------------------------------------------
set bx_ap [file join $repo src ase.tcl]
set bx_fp [open $bx_ap r]; set bx_asrc [read $bx_fp]; close $bx_fp
set bx_sib [wvproc_body $bx_asrc ase::show_in_browser_for_current]
check_true {BX09 ase::show_in_browser_for_current was found in the source} \
  [expr {$bx_sib ne {}}]
# THE DECISION-10 SOURCE GUARD, item 11's BH06 one layer over. It is a SOURCE
# check on purpose: with no raw in the design window the two getters are
# byte-identical, so no behavioural check can tell them apart (see the block
# header's narrowed claim).
check {BX09 it pivots on hier_now (sim_sch_path) and NEVER reads sch_path} \
  [list [expr {[string first {wviewer::hier_now} $bx_sib] >= 0}] \
        [regexp -all {(^|[^_])sch_path} $bx_sib]] \
  [list 1 0]
set bx_bsp [wvproc_body $wsrc wviewer::browser_show_path]
set bx_bnf [wvproc_body $wsrc wviewer::browser_node_for]
check {BX09 ...and neither viewer-side body reads sch_path either} \
  [list [regexp -all {(^|[^_])sch_path} $bx_bsp] \
        [regexp -all {(^|[^_])sch_path} $bx_bnf]] \
  [list 0 0]
# ⚠ ORDER, not merely presence: `wviewer::open` and the sidebar show both move
# the xschem context to the VIEWER, so a pivot read after them measures the
# viewer's own untitled buffer. Measured in the scout's probes; the check is
# what stops a future edit reordering the two lines.
set bx_i1 [string first {wviewer::hier_now} $bx_sib]
set bx_i2 [string first {wviewer::open} $bx_sib]
check {BX10 the PIVOT is read BEFORE wviewer::open moves the context} \
  [list [expr {$bx_i1 >= 0}] [expr {$bx_i2 > $bx_i1}]] [list 1 1]
check {BX10 ...and it does NOT re-implement an opener — wviewer::open is the only one} \
  [regexp -all {load_new_window|window_for \$key} $bx_sib] 0
# THE KEY, in the file the PLAN names
set bx_rcp [file join $repo src cadence_style_rc]
set bx_fp [open $bx_rcp r]; set bx_rc [read $bx_fp]; close $bx_fp
set bx_rcline {}
foreach bx_l [split $bx_rc "\n"] {
  if {[string first {<Control-Key-5>} $bx_l] >= 0} { set bx_rcline $bx_l ; break }
}
check {BX11 cadence_style_rc binds .drw <Control-Key-5> to the command, and BREAKs} \
  [regexp {^bind \.drw <Control-Key-5>\s+\{ase::show_in_browser_for_current %W; break\}$} \
     $bx_rcline] 1
check {BX11 ...and it is the ONLY Control-Key-5 line in the rc (no double-bind)} \
  [regexp -all {<Control-Key-5>} $bx_rc] 1
# THE MENU, in src/xschem.tcl (the PLAN said ase_window.tcl; that file builds
# the ASE-L SESSION window's menubar, not the design window's — see the receipt)
set bx_xp [file join $repo src xschem.tcl]
set bx_fp [open $bx_xp r]; set bx_xsrc [read $bx_fp]; close $bx_fp
check {BX12 the design window's Tools cascade carries `Show in Signal Browser`} \
  [regexp {menubar\.tools add command -label "Show in Signal Browser" \\\n\s+-accelerator Ctrl\+5 -command "ase::show_in_browser_for_current \$\{topwin\}\.drw"} \
     $bx_xsrc] 1
check {BX12 ...exactly once, and right after Launch ASE-L (Tools stays one ASE block)} \
  [list [regexp -all {Show in Signal Browser} $bx_xsrc] \
        [expr {[string first {Show in Signal Browser} $bx_xsrc] >
               [string first {Launch ASE-L} $bx_xsrc]}]] \
  [list 1 1]
# ⚠ THE BUMP THAT MUST NOT HAPPEN. test_wave_grid's GH0 counts VIEWER keys
# (`bind WaveViewer ...` in install_default_binds) and VIEWER menu accelerators
# (build_menubar). Item 12's key is a SCHEMATIC `.drw` bind and its menu entry
# is on xschem.tcl's Tools cascade, so 16/11 must stay put and the guide must
# gain no data-seq row — adding one would break GH0 and GH2.
set bx_fp [open [file join $repo tests headless test_wave_grid.tcl] r]
set bx_gsrc [read $bx_fp]; close $bx_fp
check {BX13 test_wave_grid's GH0 literals are UNCHANGED at 16/11} \
  [list [regexp {\[llength \$gh_seqs\] 16} $bx_gsrc] \
        [regexp {\[llength \$gh_menus\] 11} $bx_gsrc]] \
  [list 1 1]
set bx_fp [open [file join $repo doc waveform_viewer_guide.html] r]
set bx_gd [read $bx_fp]; close $bx_fp
check {BX13 ...and the guide gained NO data-seq/data-menu row for the schematic key} \
  [list [regexp -all {data-seq="Control-Key-5"} $bx_gd] \
        [regexp -all {data-menu="Show in Signal Browser"} $bx_gd]] \
  [list 0 0]
check {BX13 (control) the guide DOES still carry item 11's viewer key row} \
  [regexp {data-seq="Key-E"} $bx_gd] 1
# the four sentences, PURE — one formatter, so the status line, the CIW echo and
# the ASE-side echo cannot drift into three accounts of one event
check {BX14 browser_msg: ok} [pcall ::wviewer::browser_msg {ok g:x1.x2 x1.x2}] \
  {showing x1.x2}
check {BX14 browser_msg: partial names BOTH the asked path and the landing} \
  [pcall ::wviewer::browser_msg {partial g:x1.x2 x1.x2 x1.x2.x9}] \
  {no signals under 'x1.x2.x9' - showing x1.x2 instead}
check {BX14 browser_msg: root} [pcall ::wviewer::browser_msg {root {}}] \
  {showing the simulation top level}
check {BX14 browser_msg: err passes its own reason through} \
  [pcall ::wviewer::browser_msg {err {no simulation data loaded - read a raw file first}}] \
  {no simulation data loaded - read a raw file first}

# --- BX20-BX39: the REVEAL, on a throwaway toplevel (X only) -----------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  catch {destroy .wvbx1}
  toplevel .wvbx1
  wm title .wvbx1 {item12 show-in-browser fixture}
  wm geometry .wvbx1 900x400+40+40
  canvas .wvbx1.drw -background white -width 700 -height 360
  pack .wvbx1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbx [dict create top .wvbx1 win_path .wvbx1.drw]
  pcall ::wviewer::browser_build wvbx .wvbx1
  set BXF .wvbx1.wvbrowser
  set BXTV $BXF.tvf.tv
  pack $BXF -side left -fill y -before .wvbx1.drw
  set bx_mapped [bs_wait_mapped .wvbx1.drw]
  catch {bs_wait_mapped $BXTV}
  update

  # seed the inventory + the tree DIRECTLY (the BT2x idiom): this fixture has no
  # xschem raw behind it, which is also what makes BX39's restore leg real.
  proc bx_seed {names} {
    global BXTV
    set ::wviewer::browsersigs(wvbx) $names
    set e {}
    foreach n $names { lappend e [wviewer::signal_entry $n] }
    set r [wviewer::browser_rows $e]
    set ::wviewer::browserrows(wvbx) $r
    wviewer::browser_populate $BXTV $r
    update
    return [llength $r]
  }
  set bx_names {v(x1.x2.net5) v(x1.y3.net7) v(out)}
  check {BX20 (FIXTURE) the sidebar built, is mapped, and the tree is seeded} \
    [list $bx_mapped [winfo exists $BXTV] [expr {[bx_seed $bx_names] > 0}]] \
    [list 1 1 1]

  # ⚠⚠ POSITIVE CONTROL #1, and without it every "not visible" claim below is
  # worthless: prove the fixture can be put into `collapsed` at all, and that
  # `collapsed` is a DIFFERENT value from `visible` on the very same node.
  check {BX30 (POSITIVE CONTROL) a freshly populated tree reads `visible`} \
    [bx_vis $BXTV g:x1.x2] visible
  pcall $BXTV item g:x1 -open 0
  pcall $BXTV selection set {}
  update
  check {BX30 (POSITIVE CONTROL) collapsing the ancestor reads `collapsed`, selection empty} \
    [list [bx_vis $BXTV g:x1.x2] [pcall $BXTV selection]] [list collapsed {}]

  # THE ITEM, on the HIT path (sidebar already shown, node present) — so no
  # repopulate can intervene and erase the evidence.
  check {BX31 browser_show_path returns ok with the exact node} \
    [pcall ::wviewer::browser_show_path wvbx x1.x2] {ok g:x1.x2 x1.x2}
  update
  check {BX31 ...the node is SELECTED} [pcall $BXTV selection] {g:x1.x2}
  # ⚠ SABOTAGE (a)'s TARGET. `selection` above stays GREEN under it — that is
  # the built-in control that excludes "the command did nothing".
  check {BX31 ...and it is VISIBLE: `see` re-opened the collapsed ancestor} \
    [list [bx_vis $BXTV g:x1.x2] [pcall $BXTV item g:x1 -open]] [list visible 1]

  # THE SCROLL LEG — a node whose ancestors are ALL open and which is still not
  # on screen. `collapsed` cannot see this one; only the bbox can.
  set bx_fill {}
  for {set bx_i 0} {$bx_i < 60} {incr bx_i} { lappend bx_fill "v(zz$bx_i)" }
  bx_seed [concat $bx_names $bx_fill]
  pcall $BXTV yview moveto 1.0
  pcall $BXTV selection set {}
  update
  check {BX32 (POSITIVE CONTROL) scrolled to the bottom, x1.x2 reads `offscreen`} \
    [list [bx_vis $BXTV g:x1.x2] [pcall $BXTV item g:x1 -open]] [list offscreen 1]
  check {BX32 browser_reveal scrolls it back into view} \
    [list [pcall ::wviewer::browser_reveal wvbx g:x1.x2] [bx_vis $BXTV g:x1.x2]] \
    [list 1 visible]
  bx_seed $bx_names

  # F4: `see`/`selection set`/`bbox` THROW on a missing id, and `exists {}` is
  # TRUE (the root) — both are refused rather than swallowed into a false 1.
  set bx_f0 $::fail
  check {BX33 revealing a MISSING id returns 0 and does not throw} \
    [list [pcall ::wviewer::browser_reveal wvbx g:nope] [bx_vis $BXTV g:nope]] \
    [list 0 absent]
  check {BX33 revealing the EMPTY id returns 0 — `exists {}` is TRUE, so this is explicit} \
    [list [pcall ::wviewer::browser_reveal wvbx {}] [pcall $BXTV exists {}]] \
    [list 0 1]
  check {BX33 ...and neither raised a bgerror} [expr {$::fail - $bx_f0}] 0

  # ⚠ THE FALLBACK, on the widget — sabotage (b)'s behavioural target. The
  # selection is CLEARED first and asserted empty, so "it selected the ancestor"
  # cannot be satisfied by a leftover.
  pcall $BXTV selection set {}
  update
  check {BX34 (control) the selection really is empty before the fallback runs} \
    [pcall $BXTV selection] {}
  check {BX34 a path one segment too deep answers `partial` naming BOTH paths} \
    [pcall ::wviewer::browser_show_path wvbx x1.x2.x9] \
    {partial g:x1.x2 x1.x2 x1.x2.x9}
  update
  check {BX34 ...and the DEEPEST ANCESTOR is selected and visible} \
    [list [pcall $BXTV selection] [bx_vis $BXTV g:x1.x2]] [list {g:x1.x2} visible]

  # the sim root: an ANSWER, not a failure — the selection is cleared and the
  # tree scrolled home on purpose
  pcall $BXTV selection set {g:x1.x2}
  check {BX36 an EMPTY path is the `root` branch} \
    [pcall ::wviewer::browser_show_path wvbx {}] {root {}}
  check {BX36 ...and it CLEARS the selection deliberately} \
    [pcall $BXTV selection] {}

  # THE FOUR SENTENCES, on the real status label
  bx_seed $bx_names
  pcall ::wviewer::browser_show_path wvbx x1.x2
  check {BX37 the status line says `showing <path>` on a hit} \
    [pcall $BXF.ph cget -text] "Signal Browser\nshowing x1.x2"
  pcall ::wviewer::browser_show_path wvbx x1.x2.x9
  check {BX37 ...names both paths on the fallback} \
    [pcall $BXF.ph cget -text] \
    "Signal Browser\nno signals under 'x1.x2.x9' - showing x1.x2 instead"
  pcall ::wviewer::browser_show_path wvbx {}
  check {BX37 ...and says so at the sim root} \
    [pcall $BXF.ph cget -text] "Signal Browser\nshowing the simulation top level"
  # ⚠ the SELECTION IS LEFT ALONE on an outright miss (decision 11's mirror:
  # a failed sync leaves the user where they were)
  bx_seed $bx_names
  pcall $BXTV selection set {g:x1}
  check {BX35 a path matching nothing is an `err` that names what was asked} \
    [pcall ::wviewer::browser_show_path wvbx z9.q1] {err {no signals under 'z9.q1'}}
  check {BX35 ...the status line carries it} \
    [pcall $BXF.ph cget -text] "Signal Browser\nno signals under 'z9.q1'"
  check {BX35 ...and the user's SELECTION SURVIVED the refusal} \
    [pcall $BXTV selection] {g:x1}
  # the Search/Filter clause: a bar CAN hide a node that is really in the raw,
  # which is otherwise indistinguishable from "the raw has no such node"
  check {BX38 (control) with both bars EMPTY the message carries no bar clause} \
    [expr {[string first {Search/Filter} [pcall $BXF.ph cget -text]] >= 0}] 0
  pcall $BXF.wvsearch.pat insert 0 zzz
  check {BX38 with a bar non-empty the message NAMES the bars} \
    [pcall ::wviewer::browser_show_path wvbx z9.q1] \
    {err {no signals under 'z9.q1' (the Search/Filter bar may be hiding it)}}
  check {BX38 ...and the bars were NOT cleared behind the user's back (declared limit)} \
    [pcall $BXF.wvsearch.pat get] zzz
  pcall $BXF.wvsearch.pat delete 0 end

  # ⚠ IMPROVE-OR-RESTORE. This fixture has no xschem raw behind it, so the
  # miss-retry's `browser_refresh $token 1` genuinely FAILS and would otherwise
  # replace a good tree with an empty one — measured on the first cut of
  # browser_show_path, which turned BX34's `partial` into an `err`. The guard is
  # what makes BX34 and BX35 mean anything at all here.
  bx_seed $bx_names
  set bx_rows_before $::wviewer::browserrows(wvbx)
  pcall ::wviewer::browser_show_path wvbx x1.x2.x9
  check {BX39 a MISS whose reload fails RESTORES the rows byte-for-byte} \
    [expr {$::wviewer::browserrows(wvbx) eq $bx_rows_before}] 1
  check {BX39 ...and the widget still holds them, so the tree is not emptied} \
    [list [pcall $BXTV exists g:x1.x2] [bx_vis $BXTV g:x1.x2]] [list 1 visible]

  # `unmapped` — the value bbox CANNOT produce (a withdrawn-but-once-mapped tree
  # still answers bbox), which is why the oracle checks ismapped first
  wm withdraw .wvbx1
  update
  check {BX33 (ORACLE) a withdrawn tree reads `unmapped`, and bbox still answers} \
    [list [bx_vis $BXTV g:x1.x2] [expr {[pcall $BXTV bbox g:x1.x2] ne {}}]] \
    [list unmapped 1]

  destroy .wvbx1
  catch {unset ::wviewer::browsersigs(wvbx)}
  catch {unset ::wviewer::browserrows(wvbx)}
  catch {dict unset ::wviewer::windows wvbx}
  check {BX39 (teardown) the throwaway toplevel and its registry entry are gone} \
    [list [winfo exists .wvbx1] [dict exists $::wviewer::windows wvbx]] [list 0 0]

} else {
  puts "SKIPPED: BX2x/BX3x group (Tk/X arm only)"
}

# --- BX40-BX52: END TO END — real viewer, real design window, real key -------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # item 11 left the design window loaded on the wvhier fixture (at `x1`) with
  # TWO sessions registered — bh/wvhier_top/schematic AND bh/wvhier_mid/schematic
  # — and session_for_design returns the FIRST match in insertion order. That is
  # exploited below rather than fought: closing/reopening the MID session is how
  # this block moves `level` between 0 and 1 without a second fixture.
  # ⚠ THE DESIGN WINDOW IS NAMED, NOT INHERITED. item 11's BH5x block closes its
  # viewer last, so `current_win_path` on arrival may still point at a window
  # that no longer exists — reading the fixture through it produces a skip that
  # looks like "the viewer would not open". The fixture was loaded into the MAIN
  # window (BH20's `xschem load`), so that is the one, and the switch is
  # VERIFIED like every other switch in this file.
  set bx_dwin .drw
  # ⚠ AND THE SWITCH IS RETRIED AND VERIFIED, never fired once and trusted. An
  # `update` between a raise and a context read can deliver an Enter/FocusIn on
  # some other canvas, which switches the context straight back — measured: the
  # first cut of this block read `.x1.drw` (the viewer) after switching to
  # `.drw`, and self-skipped the whole group. So: DRAIN, switch, RE-READ.
  # ⚠ THE FAST PATH PUMPS NO EVENTS, AND THAT IS A MEASURED REQUIREMENT, not
  # tidiness. `xschem new_schematic switch` is synchronous, so `current_win_path`
  # is already true on return; the `update` retry exists only for the rare bounce
  # above. An unconditional `update` per call redraws BOTH canvases, and with ~25
  # call sites that pushed this file's X-request count from ~5k to ~68k — enough
  # to trip WSLg's Xwayland `can't send file descriptor` abort on nearly every
  # run (receipt §10.2). Measured: 32s and 0/6 completions before, ~4s after.
  proc bx_ctx_to {w} {
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
  bx_ctx_to $bx_dwin
  set bx_tok bh/wvhier_top/schematic
  set bx_mid bh/wvhier_mid/schematic
  pcall ::wviewer::hier_walk {}
  check {BX40 (FIXTURE) the design window is on wvhier_top, at its top level} \
    [list [file tail [pcall xschem get schname 0]] [pcall xschem get sim_sch_path] \
          [pcall xschem get currsch]] \
    [list wvhier_top.sch {} 0]

  set bx_open [pcall ::wviewer::open $bx_tok]
  set bx_vtop [wviewer::window_for $bx_tok]
  # wviewer::open leaves the context ON THE VIEWER (measured) — go back before
  # reading anything hierarchical, and VERIFY the switch followed
  bx_ctx_to $bx_dwin
  set bx_ready [expr {$bx_vtop ne {} && [viewer_ready $bx_vtop]}]
  set bx_ctx [expr {[bx_ctx_to $bx_dwin] ? $bx_dwin : [xschem get current_win_path]}]
  if {$bx_open ne 1 || !$bx_ready || $bx_ctx ne $bx_dwin} {
    # name WHICH precondition failed — a bare skip line hides a broken fixture
    puts "SKIPPED: BX4x/BX5x group (open=$bx_open top='$bx_vtop'\
 ready=$bx_ready ctx='$bx_ctx' want='$bx_dwin')"
    catch {wviewer::close $bx_tok}
  } else {
    set BXVTV $bx_vtop.wvbrowser.tvf.tv
    # ⚠⚠ POSITIVE CONTROL #3 (sabotage (c)): the sidebar is HIDDEN before the
    # command runs, asserted TWO ways — the authority and the packing order —
    # because `pack info` alone cannot tell "hidden" from "never built".
    check {BX40 (POSITIVE CONTROL) a fresh viewer's sidebar is HIDDEN, but BUILT} \
      [list [pcall ::wviewer::browser_shown $bx_tok] \
            [bs_packed $bx_vtop.wvbrowser] \
            [winfo exists $bx_vtop.wvbrowser]] \
      [list 0 0 1]

    # a REAL raw in the VIEWER's own context (the BTV/BMV/BH5x idiom): a
    # two-level path, a one-level one, and a top-level `x2.` — the last so that
    # a level-1 origin has somewhere real to land as well as a level-0 one.
    bx_ctx_to $bx_vtop.drw
    pcall xschem raw new bx_item12.raw dc vsweep 0 1.0 0.5
    foreach bx_n {v(out) v(x1.x2.net5) v(x1.topsig) v(x2.deep)} {
      pcall xschem raw add $bx_n {vsweep 1 +}
    }
    bx_ctx_to $bx_dwin
    check {BX40 (control) the context is back on the DESIGN window} \
      [expr {[pcall xschem get current_win_path] eq $bx_dwin}] 1

    # WHICH session resolves, asserted before anything is claimed about the
    # viewer (the scout's risk: item 11's two sessions are still live)
    pcall ase::session_close $bx_mid
    pcall ::wviewer::hier_walk X1.X2
    set bx_sfc [pcall ase::session_for_current]
    check {BX41 at X1.X2 with the MID session closed, the TOP session resolves at level 0} \
      [list [lindex $bx_sfc 0] [lindex $bx_sfc 1]] [list $bx_tok 0]

    # ==== THE ITEM, END TO END ====
    set bx_r [pcall ase::show_in_browser_for_current $bx_dwin]
    # ⚠ READ THE CONTEXT WITH NO EVENT PUMP IN BETWEEN — an `update` here can
    # deliver a stray Enter and move it, which would make the DECLARED context
    # rule below untestable rather than false.
    set bx_ctxafter [xschem get current_win_path]
    update
    check {BX42 the command returns the session key} $bx_r $bx_tok
    # ← sabotage (c)
    check {BX42 (SIDEBAR) it UN-HID the sidebar — authority AND packing agree} \
      [list [pcall ::wviewer::browser_shown $bx_tok] \
            [bs_packed $bx_vtop.wvbrowser] \
            [bs_order $bx_vtop $bx_vtop.wvbrowser $bx_vtop.drw]] \
      [list 1 1 a-before-b]
    # ← sabotage (d): X1.X2 must find the raw's lowercase x1.x2
    check {BX42 (SELECTION) the node for X1.X2 is selected — the raw's x1.x2} \
      [pcall $BXVTV selection] {g:x1.x2}
    # ← sabotage (a)
    check {BX42 (VISIBLE) and it is on screen with its ancestors open} \
      [bx_vis_m $BXVTV g:x1.x2] visible
    check {BX42 the browser status line reports the landing} \
      [pcall $bx_vtop.wvbrowser.ph cget -text] "Signal Browser\nshowing x1.x2"
    # THE DECLARED CONTEXT RULE (item 11's mirror): the viewer was raised, so
    # the context is left there. Asserted, not accidental.
    check {BX42 (DECLARED) the context is LEFT ON THE VIEWER, the raised window} \
      [expr {$bx_ctxafter eq "$bx_vtop.drw"}] 1
    bx_ctx_to $bx_dwin
    check {BX42 ...and the DESIGN window never moved: still wvhier_top, still at X1.X2} \
      [list [file tail [pcall xschem get schname 0]] \
            [pcall xschem get sim_sch_path]] \
      [list wvhier_top.sch {X1.X2.}]

    # ⚠⚠ THE FIRST INVOKE CANNOT PROVE THE EXPANSION, and that was MEASURED, not
    # reasoned: un-hiding the sidebar repopulates the tree, and `browser_populate`
    # inserts every group `-open 1`, so the node is visible whether or not
    # anything expanded it. Sabotage (a) (delete `$tv see`) left the leg above
    # GREEN. The SECOND invoke is the real one — sidebar already shown, so no
    # repopulate intervenes, and the ancestor deliberately collapsed first.
    pcall $BXVTV item g:x1 -open 0
    pcall $BXVTV selection set {}
    update
    check {BX42 (POSITIVE CONTROL) with its ancestor collapsed the node reads `collapsed`} \
      [list [bx_vis_m $BXVTV g:x1.x2] [pcall $BXVTV selection]] [list collapsed {}]
    bx_ctx_to $bx_dwin
    pcall ase::show_in_browser_for_current $bx_dwin
    update
    check {BX42 (SECOND INVOKE) on an already-shown COLLAPSED tree it still lands VISIBLE} \
      [list [pcall $BXVTV selection] [bx_vis_m $BXVTV g:x1.x2] \
            [pcall $BXVTV item g:x1 -open]] \
      [list {g:x1.x2} visible 1]
    bx_ctx_to $bx_dwin

    # THE 0168 AGREEMENT, as a VALUE rather than an assumption (driver note (f)).
    # sod_rel_path is the ASE session side's own answer to the same question;
    # this asserts the two agree at level 0 AND level 1. ⚠ TEST-ONLY: the shipped
    # path never calls it (it reads sch_path, which decision 10 forbids us) —
    # BX09 is what guards that.
    set bx_segs [pcall ::wviewer::hier_now]
    check {BX49 (0168 AGREEMENT) drop-0 equals sod_rel_path 0, byte for byte} \
      [list "[join [lrange $bx_segs 0 end] .]." [pcall ase::ui::sod_rel_path 0]] \
      [list {X1.X2.} {X1.X2.}]
    check {BX49 ...and drop-1 equals sod_rel_path 1 — the ancestor-owned-raw case} \
      [list "[join [lrange $bx_segs 1 end] .]." [pcall ase::ui::sod_rel_path 1]] \
      [list {X2.} {X2.}]

    # ==== BX48: THE LEVEL>0 MAPPING — the one behavioural proof of the origin
    # arithmetic. SAME hierarchy position, DIFFERENT session level, DIFFERENT
    # browser path: x1.x2 at level 0 (BX42 above), x2 at level 1.
    # ⚠ MEASURED BY SPY, and the spy is the RIGHT instrument here rather than a
    # shortcut. The claim is exactly "which PATH does the command compute", and
    # a second real viewer toplevel adds only WSLg fragility to it (the first cut
    # self-skipped when the mid session's window would not map). BX42 already
    # proves the whole chain end to end at level 0; this isolates the ORIGIN
    # ARITHMETIC and runs BOTH levels from the SAME hierarchy position, so the
    # two answers are a genuine discriminator rather than one value in a vacuum.
    set ::bx_paths {}
    rename ::wviewer::open ::wviewer::__bx_open
    proc ::wviewer::open {token} { return 1 }
    rename ::wviewer::browser_show_path ::wviewer::__bx_bsp
    proc ::wviewer::browser_show_path {token path} {
      lappend ::bx_paths [list $token $path]
      return [list err {spy}]
    }
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1.X2
    # leg 1 — the level-0 session (mid still closed): the WHOLE path
    set ::bx_paths {}
    pcall ase::show_in_browser_for_current $bx_dwin
    set bx_p0 $::bx_paths
    # leg 2 — the level-1 session: the SAME position, one segment shorter
    pcall ase::session_open $bx_mid [file join $scratch bh_mid.state]
    bx_ctx_to $bx_dwin
    set bx_sfc2 [pcall ase::session_for_current]
    check {BX48 (control) with the MID session back, X1.X2 resolves it at level 1} \
      [list [lindex $bx_sfc2 0] [lindex $bx_sfc2 1]] [list $bx_mid 1]
    set ::bx_paths {}
    pcall ase::show_in_browser_for_current $bx_dwin
    set bx_p1 $::bx_paths
    check {BX48 (ORIGIN) one position, two session levels, two DIFFERENT browser paths} \
      [list $bx_p0 $bx_p1] \
      [list [list [list $bx_tok X1.X2]] [list [list $bx_mid X2]]]
    # leg 3 — a raw loaded IN THE DESIGN CONTEXT at level 1. sim_sch_path is then
    # already `X2.`, so the level-1 session needs NO drop and lands identically —
    # while the level-0 session is a NEGATIVE drop and must be REFUSED outright
    # rather than guessed at.
    pcall xschem raw new bx_dsgn.raw dc vsweep 0 1.0 0.5
    pcall xschem raw add {v(zz)} {vsweep 1 +}
    pcall xschem set raw_level 1
    check {BX48 (control) the design ctx now really has a raw at level 1} \
      [list [pcall xschem raw loaded] [pcall xschem get sim_sch_path]] [list 1 {X2.}]
    set ::bx_paths {}
    pcall ase::show_in_browser_for_current $bx_dwin
    check {BX48 a raw at the session's OWN level needs no drop — same path, no double-strip} \
      $::bx_paths [list [list $bx_mid X2]]
    pcall ase::session_close $bx_mid
    bx_ctx_to $bx_dwin
    set ::bx_paths {}
    set bx_neg [pcall ase::show_in_browser_for_current $bx_dwin]
    check {BX48 (NEGATIVE DROP) a raw read BELOW the session's design is REFUSED, not guessed} \
      [list $bx_neg $::bx_paths] [list {} {}]
    pcall xschem raw clear
    rename ::wviewer::browser_show_path {}
    rename ::wviewer::__bx_bsp ::wviewer::browser_show_path
    rename ::wviewer::open {}
    rename ::wviewer::__bx_open ::wviewer::open
    check {BX48 (teardown) both spied procs are back in place} \
      [list [expr {[info commands ::wviewer::__bx_bsp] eq {}}] \
            [expr {[info commands ::wviewer::__bx_open] eq {}}] \
            [expr {[info commands ::wviewer::browser_show_path] ne {}}] \
            [expr {[info commands ::wviewer::open] ne {}}]] \
      [list 1 1 1 1]
    bx_ctx_to $bx_dwin

    # ==== BX44: the REAL Tools entry, found BY LABEL ====
    set bx_tm .menubar.tools
    if {![winfo exists $bx_tm]} {
      puts "SKIPPED: BX44 (the main window has no Tools menu)"
    } else {
      set bx_ti -1
      catch {set bx_ti [$bx_tm index {Show in Signal Browser}]}
      check {BX44 the Tools entry exists, with its accelerator and its command} \
        [list [expr {$bx_ti >= 0}] \
              [pcall $bx_tm entrycget $bx_ti -accelerator] \
              [pcall $bx_tm entrycget $bx_ti -command]] \
        [list 1 {Ctrl+5} {ase::show_in_browser_for_current .drw}]
      # invoke it FOR REAL from a different hierarchy position and assert the
      # world moved to match
      bx_ctx_to $bx_dwin
      pcall ::wviewer::hier_walk x1
      pcall $BXVTV selection set {}
      update
      pcall $bx_tm invoke $bx_ti
      update
      check {BX44 invoking it really re-targets the browser at x1} \
        [list [pcall $BXVTV selection] [bx_vis_m $BXVTV g:x1] \
              [pcall $bx_vtop.wvbrowser.ph cget -text]] \
        [list {g:x1} visible "Signal Browser\nshowing x1"]
      bx_ctx_to $bx_dwin
    }

    # ==== BX45: at the TOP -> the `root` branch; the sidebar STAYS shown ====
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk {}
    pcall $BXVTV selection set {g:x1.x2}
    update
    pcall ase::show_in_browser_for_current $bx_dwin
    update
    check {BX45 at the sim top the selection is cleared and the reason given} \
      [list [pcall $BXVTV selection] \
            [pcall $bx_vtop.wvbrowser.ph cget -text]] \
      [list {} "Signal Browser\nshowing the simulation top level"]
    check {BX45 ...and the sidebar is STILL shown (a no-op must not re-hide it)} \
      [list [pcall ::wviewer::browser_shown $bx_tok] \
            [bs_packed $bx_vtop.wvbrowser]] \
      [list 1 1]
    bx_ctx_to $bx_dwin

    # ==== BX50: RELOAD-ON-MISS (item 9's D6, decided deliberately) ====
    # a signal added to the raw BEHIND the browser's back is invisible to the
    # snapshot; a MISS spends one reload and finds it. A HIT must NOT reload —
    # a repopulate would clear the selection and re-open every group.
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1
    set bx_rows_a $::wviewer::browserrows($bx_tok)
    pcall ase::show_in_browser_for_current $bx_dwin
    update
    bx_ctx_to $bx_dwin
    check {BX50 (control) a HIT does not reload — the row snapshot is byte-identical} \
      [expr {$::wviewer::browserrows($bx_tok) eq $bx_rows_a}] 1
    bx_ctx_to $bx_vtop.drw
    pcall xschem raw add {v(x1.x2.x7.late)} {vsweep 1 +}
    bx_ctx_to $bx_dwin
    check {BX50 (control) the browser has NOT seen the new signal yet (D6 snapshot)} \
      [lindex [pcall ::wviewer::browser_node_for $::wviewer::browserrows($bx_tok) \
                 {x1 x2 x7}] 1] 2
    pcall ::wviewer::hier_walk X1.X2
    # there is no X7 instance in the fixture, so walk there by hand-feeding the
    # path — what is under test is the RELOAD, not the descend
    set bx_r3 [pcall ::wviewer::browser_show_path $bx_tok x1.x2.x7]
    update
    check {BX50 a MISS reloads once and FINDS the late signal's group} \
      [list $bx_r3 [expr {[llength $::wviewer::browserrows($bx_tok)] >
                          [llength $bx_rows_a]}]] \
      [list {ok g:x1.x2.x7 x1.x2.x7} 1]

    # ==== BX46: NO RAW AT ALL -> the honest report, sidebar untouched ====
    bx_ctx_to $bx_vtop.drw
    pcall xschem raw clear
    bx_ctx_to $bx_dwin
    catch {unset ::wviewer::browsersigs($bx_tok)}
    pcall $BXVTV selection set {}
    update
    pcall ase::show_in_browser_for_current $bx_dwin
    update
    check {BX46 with no raw loaded it says so rather than doing nothing} \
      [pcall $bx_vtop.wvbrowser.ph cget -text] \
      "Signal Browser\nno simulation data loaded - read a raw file first"
    check {BX46 ...nothing is selected, and the sidebar is still shown} \
      [list [pcall $BXVTV selection] [pcall ::wviewer::browser_shown $bx_tok] \
            [bs_packed $bx_vtop.wvbrowser]] \
      [list {} 1 1]
    bx_ctx_to $bx_dwin

    # ==== BX43: THE REAL KEY, on the REAL design canvas ====
    # ⚠ NOT `source`d from cadence_style_rc (that installs every cadence bind and
    # sources eight util files, perturbing later groups) — the exact line is
    # grepped in BX11 and bound HERE, verbatim, the test_cadence_window_hop_log
    # idiom.
    set ::bx_calls 0
    rename ::ase::show_in_browser_for_current ::ase::__bx_real
    proc ::ase::show_in_browser_for_current {{win {}}} {
      incr ::bx_calls
      return [uplevel 1 [list ::ase::__bx_real $win]]
    }
    bind .drw <Control-Key-5> {ase::show_in_browser_for_current %W; break}
    bx_ctx_to $bx_dwin
    # rebuild the inventory the raw clear above emptied
    bx_ctx_to $bx_vtop.drw
    pcall xschem raw new bx_key.raw dc vsweep 0 1.0 0.5
    foreach bx_n {v(out) v(x1.x2.net5)} { pcall xschem raw add $bx_n {vsweep 1 +} }
    bx_ctx_to $bx_dwin
    pcall ::wviewer::browser_refresh $bx_tok 1
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1.X2
    pcall $BXVTV selection set {}
    catch {raise_activate_toplevel .}
    catch {focus .drw}
    update
    set bx_c0 $::bx_calls
    if {![send_key .drw <Control-Key-5> {$::bx_calls > $bx_c0}]} {
      puts "SKIPPED: BX43 (WSLg key-delivery stall on the design canvas)"
    } else {
      update
      check {BX43 a REAL Ctrl-5 on the design canvas targets the browser at x1.x2} \
        [list [expr {$::bx_calls - $bx_c0}] \
              [pcall $BXVTV selection] [bx_vis_m $BXVTV g:x1.x2]] \
        [list 1 {g:x1.x2} visible]
      # NEGATIVE CONTROL on the SAME recorder: an unbound chord must read ZERO,
      # which is what stops the recorder passing vacuously
      bx_ctx_to $bx_dwin
      catch {raise_activate_toplevel .}
      catch {focus -force .drw}
      update
      set bx_c1 $::bx_calls
      catch {event generate .drw <Control-Key-6>}
      update
      check {BX43 (NEGATIVE CONTROL) an unbound Ctrl-6 records ZERO on the same spy} \
        [expr {$::bx_calls - $bx_c1}] 0
    }
    catch {bind .drw <Control-Key-5> {}}
    rename ::ase::show_in_browser_for_current {}
    rename ::ase::__bx_real ::ase::show_in_browser_for_current
    check {BX43 the real ase::show_in_browser_for_current is back in place} \
      [list [expr {[info commands ::ase::__bx_real] eq {}}] \
            [expr {[info commands ::ase::show_in_browser_for_current] ne {}}]] \
      [list 1 1]

    # ==== BX47: NO SESSION AT ALL -> an honest notice, and no viewer opened ==
    bx_ctx_to $bx_dwin
    set bx_tops0 [llength [winfo children .]]
    pcall ase::session_close $bx_tok
    pcall ase::session_close wvhier/wvhier_top/schematic
    set bx_none [pcall ase::show_in_browser_for_current $bx_dwin]
    update
    check {BX47 with no session bound the command returns {} and opens nothing} \
      [list $bx_none [expr {[llength [winfo children .]] - $bx_tops0}]] \
      [list {} 0]
    pcall ase::session_open $bx_tok [file join $scratch bh_top.state]
    bx_ctx_to $bx_dwin
    catch {wviewer::close $bx_tok}
  }

} else {
  puts "SKIPPED: BX4x/BX5x group (Tk/X arm only)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

catch {test_scratch_drop $scratch}

puts "----"
puts "test_wave_sigbrowser: $npass passed, $fail failed"
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  flush stdout
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  flush stdout
  exit 1
}
