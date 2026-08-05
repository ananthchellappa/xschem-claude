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
# it changes WIDGET GEOMETRY only. The canvas resize already goes
# <Configure> -> on_configure -> configure_apply, which captures AND
# regenerates; a second one here would double-fold and double-draw.
check {BS08 browser_toggle neither captures nor regenerates} \
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
  check {BS22 the placeholder label is the frame's ONLY child} \
    [list [winfo exists .wvbs1.wvbrowser.ph] [winfo class .wvbs1.wvbrowser.ph] \
          [winfo children .wvbs1.wvbrowser]] \
    [list 1 Label .wvbs1.wvbrowser.ph]
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
