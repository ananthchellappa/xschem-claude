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
#     item 10  BM   ...
#     item 11  BH   ...
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
check {BT09 ...so the guide still carries GH0's fifteen keys and ten accelerators} \
  [list $bt_seqs $bt_accs] [list 15 10]

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
    rename ::wviewer::plot_signals ::wviewer::__bt_real_plot_signals
    proc ::wviewer::plot_signals {token exprs {colors {}}} {
      lappend ::bt_plot_calls [list $token $exprs]
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
    pcall ::wviewer::browser_plot_selection $tok
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
    pcall ::wviewer::browser_plot_selection $tok
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
