# tests/headless/wvbs_common.tcl — the SHARED PRELUDE of the signal-browser
# test files (doc/claude/signal_browser_batch/PLAN.md items 8-15).
#
# ============================================================================
# WHY THIS FILE EXISTS — DRIVER RULING 30
# ============================================================================
# Settled decision 9 put items 8-15 in ONE file. At 489 checks that file was
# killed mid-run by WSLg with ZERO check failures (0 of 9 completions measured
# 2026-08-06), so every later item's verification became unmeasurable. Ruling 30
# REVISED decision 9: the browser checks are split BY ITEM RANGE across a small
# number of files, each still re-run whole by every later verifier.
#
#   tests/headless/test_wave_sigbrowser.tcl       items 8, 9, 10   BS BT BM
#   tests/headless/test_wave_sigbrowser_i11.tcl   item 11          BH
#   tests/headless/test_wave_sigbrowser_i12.tcl   item 12          BX
#   (items 13-15 create ONE more file; item 13 owns that decision)
#
# ⚠ THIS FILE IS NOT A TEST AND MUST NEVER BE NAMED `test_*.tcl`.
# `full_audit.sh` selects its cases with `ls "$HERE"/test_*.tcl`, so a shared
# prelude called `test_…` would be executed as a case, would run zero checks,
# would print no RESULT banner and would be scored FAIL forever. `scratch.tcl`
# and `harness.tcl` are the house precedent for a non-`test_` helper.
#
# ============================================================================
# WHAT IT CARRIES, AND WHY EACH PIECE IS HERE RATHER THAN DUPLICATED
# ============================================================================
# Item 8's header declared the conventions items 9-15 inherit. Duplicating them
# three times is how they drift; a common file is how they cannot. Everything
# below was previously defined ONCE in test_wave_sigbrowser.tcl and used by two
# or more items, so moving it here is a relocation, not a rewrite:
#
#   check / check_true      the scoring pair
#   pcall                   error-guarded call — a sabotage that makes the code
#                           under test THROW must fail ONE check, not abort the
#                           file
#   ::bgerror               PRINTS and increments ::fail (a silent swallow hides
#                           a defect, a re-throw hangs a headless run under X)
#   wvproc_body             named proc body, CODE LINES ONLY
#   bs_packed / bs_order    the widget-state masquerade answers
#   bs_wait_mapped          item 5's `at_wait_mapped` idiom: polls the
#                           PRECONDITION and RETURNS the mapping
#   send_key / viewer_ready WSLg-robust key delivery and viewer map-wait
#   $wsrc                   src/wave_viewer.tcl as text (every item greps it)
#
# ⚠ TWO PROCS DELIBERATELY DID NOT MOVE. `bs_spy_on`/`bs_spy_off` spy on
# `wviewer::browser_show`, which is item 8's subject and nobody else's; and the
# per-item readers (`bt_tree`, `bm_menu_state`, `bx_vis`, …) belong to the item
# that reasons about them. A shared prelude is for what MORE THAN ONE file
# needs — anything else moved here would be coverage nobody's verifier reads.
#
# ⚠ bs_wait_mapped / send_key / viewer_ready ARE NOW DEFINED UNCONDITIONALLY.
# They used to sit inside item 8's `if {$::has_x}` fixture blocks. A `proc`
# body is not evaluated at definition time, so defining them without the gate
# is a no-op for behaviour — and it is what lets the item-11 and item-12 files,
# whose first X-gated block is their own, still reach them. Every CALL SITE is
# still inside an X gate, exactly as before.
#
# ============================================================================
# CONTRACT WITH THE FILE THAT SOURCES IT
# ============================================================================
# Before sourcing, the caller sets:
#     set ::wvbs_tag  <short scratch tag>      e.g. wvsigbrowser_i11
#     set ::wvbs_name <banner name>            e.g. test_wave_sigbrowser_i11
# After sourcing, the caller has: $fail $npass $here $repo $scratch $wsrc and
# every proc above. The caller ends with `wvbs_finish`, which prints the banner
# and exits 0/1 — the `RESULT: ALL PASS (N checks)` line full_audit.sh greps.
# ============================================================================

if {![info exists ::wvbs_tag]}  { set ::wvbs_tag  wvsigbrowser }
if {![info exists ::wvbs_name]} { set ::wvbs_name test_wave_sigbrowser }

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
set scratch [test_scratch $::wvbs_tag]

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

# the `at_wait_mapped` idiom (item 5). Polls the PRECONDITION — mapping —
# never the asserted value, and RETURNS the mapping so every caller can carry
# it in its own tuple: a budget expiry then reads as "never mapped" and cannot
# masquerade as a real failure.
# ⚠ NEVER THROWS, and that is a WIDENING rather than a weakening (ruling 17,
# and the same argument bs_wait_mapped_top already carries). `winfo ismapped`
# on a widget that does not exist THROWS, and an unguarded throw here lands in
# the calling file's outer catch and deletes every remaining check — measured:
# the item-9 trap-1 sabotage stopped the panes file at check 22 of 34, so the
# two checks written to CATCH that sabotage never ran. A missing widget now
# reads 0, which still FAILS every caller's own comparison.
proc bs_wait_mapped {w {budget 1500}} {
  for {set t 0} {$t < $budget} {incr t} {
    if {[catch {winfo ismapped $w} m]} { return 0 }
    if {$m} { break }
    after 10 ; update
  }
  update
  if {[catch {winfo ismapped $w} m]} { return 0 }
  return $m
}

# ⚠ THE TOPLEVEL TWIN OF bs_wait_mapped, ADDED BY THE RULING-30 SPLIT and the
# answer to flaky check BH54. `winfo ismapped .` on the MAIN window is not a
# fact the test may assume: a raise is asynchronous, the WM answers when it
# answers, and under a loaded WSLg compositor the answer can arrive after the
# assertion. BH54 asserted it as an instantaneous truth and flapped 1-in-4 with
# item 12 ABSENT — the un-named ~20% flap `11_receipt.md` §13.4 could not name.
#
# ⚠ IT IS A WIDENING, NOT A WEAKENING (ruling 17). It still RETURNS THE
# MAPPING, so an expired budget reads `0` and FAILS the check exactly as an
# unmapped window always did — this cannot go always-true. What it adds is the
# time the WM is allowed to take. A window that is genuinely never mapped burns
# the whole budget and still fails; only a window that maps LATE is rescued.
proc bs_wait_mapped_top {w {budget 3000}} {
  for {set t 0} {$t < $budget} {incr t} {
    if {[catch {winfo ismapped $w} m]} { return 0 }
    if {$m} { return 1 }
    after 10 ; update
  }
  update
  if {[catch {winfo ismapped $w} m]} { return 0 }
  return $m
}

# ⚠ ADDED BY THE RULING-30 SPLIT, and the answer to flaky check BT45. A widget's
# GEOMETRY is not readable until the WM has grown the TOPLEVEL to its final size;
# `update` alone does not guarantee that under WSLg. MEASURED on the real viewer:
#   settled   top 1067  sidebar 480  canvas 587
#   flapping  top  400  sidebar 240  canvas 160
# `wviewer::browser_width` caps the sidebar at 45% of the toplevel but FLOORS it
# at 240 px, so mid-resize the floor wins and the sidebar really is wider than
# the canvas. The flap was a read taken before the window finished growing.
#
# ⚠ WIDENING, NOT WEAKENING. It polls the PRECONDITION — the TOPLEVEL's width
# has been unchanged for `settle` consecutive polls — and RETURNS
# {topw aw bw settled|unsettled}, never a verdict. The caller still does the
# comparing, so an equal or inverted layout still fails; an expired budget comes
# back tagged `unsettled` with the widths it saw, so it is visible in the log
# rather than masquerading as a layout result. Nothing here can make a false
# claim true.
proc bs_wait_widths {top a b {budget 300} {settle 12}} {
  set last -1 ; set same 0
  for {set t 0} {$t < $budget} {incr t} {
    set wt 0; set wa 0; set wb 0
    catch {set wt [winfo width $top]}
    catch {set wa [winfo width $a]}
    catch {set wb [winfo width $b]}
    if {$wt > 1 && $wa > 1 && $wb > 1} {
      if {$wt == $last} { incr same } else { set same 0 ; set last $wt }
      if {$same >= $settle} { return [list $wt $wa $wb settled] }
    }
    after 10 ; update
  }
  set wt 0; set wa 0; set wb 0
  catch {set wt [winfo width $top]}
  catch {set wa [winfo width $a]}
  catch {set wb [winfo width $b]}
  return [list $wt $wa $wb unsettled]
}

# --- the two-pane SASH readers (two-pane PLAN item 9) -----------------------
# ⚠ AN ASSERTABLE VALUE, NEVER A THROW AND NEVER A BARE 0. The sash is stored
# and restored as a FRACTION (M3), and a fraction read on a panedwindow that is
# not yet MAPPED is the batch's ranked silent-green trap #1: MEASURED on this
# machine, an unmapped `ttk::panedwindow` reports `winfo height` 1 and
# `sashpos 0` 0, so `fraction x height` collapses the tree pane to nothing and
# every fraction reads 0.0 — indistinguishable from "the sash really is at the
# top" unless the two failures have their OWN values. They do:
#     -1  there is no panedwindow there at all
#     -2  there is one, but its height is not real yet (unmapped / mid-map)
# so a mid-map read is visible in the log instead of masquerading as 0.0.
proc bs_sash_frac {pw} {
  if {[catch {winfo exists $pw} e] || !$e} { return -1 }
  if {[catch {winfo class $pw} c] || $c ne {TPanedwindow}} { return -1 }
  set h 0
  catch {set h [winfo height $pw]}
  if {$h <= 1} { return -2 }
  set p 0
  if {[catch {$pw sashpos 0} p]} { return -1 }
  return [expr {$p * 1.0 / $h}]
}
# `bs_wait_widths`' settle poll, turned on the sash. Polls the PRECONDITION —
# the panedwindow has a real height and the fraction has stopped moving — and
# RETURNS THE FRACTION, never a verdict, so an expired budget still fails the
# caller's own comparison rather than being rescued by the helper.
proc bs_wait_sash {pw {budget 300} {settle 12}} {
  set last -99 ; set same 0 ; set f -2
  for {set t 0} {$t < $budget} {incr t} {
    set f [bs_sash_frac $pw]
    if {$f > 0} {
      if {abs($f - $last) < 0.0005} { incr same } else { set same 0 ; set last $f }
      if {$same >= $settle} { return $f }
    }
    after 10 ; update
  }
  return [bs_sash_frac $pw]
}

# --- REDUCING A `pcall` RESULT TO SOMETHING `expr` CAN EAT --------------------
# ⚠ REQUIRED, NOT TIDINESS. `pcall` answers the STRING `ERR:<msg>` when the call
# threw, and `expr {[pcall winfo width $w] > 1}` on that string throws AGAIN --
# straight past the check and into the file's outer catch, which deletes every
# remaining check. That is exactly the failure the item-9 trap-1 sabotage
# produced: the run stopped at check 17 and the two checks written to CATCH the
# sabotage never ran at all. These two turn a throw into a VALUE instead.
proc bs_num {v} { if {[string is double -strict $v]} { return $v } ; return -1 }
proc bs_set {v} { expr {$v ne {} && [string range $v 0 3] ne {ERR:}} }

# --- THE TREE'S EXPANDED SET (two-pane item 10) -------------------------------
# ⚠ THREE DISTINCT SHAPES, NEVER A COUNT AND NEVER A BOOLEAN, for the reason
# spec §13.2 gives: "the thing I am reading is gone" has to be an assertable
# value, distinct from "present but empty".
#   no-tree   the widget does not exist
#   none      it exists and NOTHING is expanded — which after item 10 would mean
#             even the design root is collapsed, i.e. a one-line tree
#   <ids>     the expanded ids, depth-first, in tree order
# A count would say "1" for both `{g:}` and `{g:x1}`, which are opposite states.
proc bs_open_set {tv} {
  if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
  set out {}
  foreach id [bs_tree_ids $tv] {
    set o 0
    if {[catch {$tv item $id -open} o]} { continue }
    if {[string is boolean -strict $o] && [string is true -strict $o]} {
      lappend out $id
    }
  }
  if {![llength $out]} { return none }
  return $out
}
# EVERY item in the tree, depth-first. Deliberately NOT the "rows with children"
# predicate wviewer::browser_tree_nodes used to carry: after item 10 a node whose
# children were all signals has no children at all, and a helper that skipped it
# would report the leaf-most nodes as permanently collapsed.
proc bs_tree_ids {tv {id {}}} {
  set out {}
  if {[catch {$tv children $id} kids]} { return {} }
  foreach k $kids {
    lappend out $k
    foreach d [bs_tree_ids $tv $k] { lappend out $d }
  }
  return $out
}
# Type into a searchbar's entry the way a USER does — one <KeyRelease> per
# character through the bar's own pump — and answer what the bar ended up
# holding, so "the keystrokes never arrived" cannot masquerade as "the filter
# matched nothing". `no-bar` / `no-focus` / the entry's contents.
#
# ⚠⚠ THE FOCUS LOOP IS MANDATORY, AND THIS WAS MEASURED RATHER THAN ASSUMED.
# Tk delivers KEY events to the TOPLEVEL'S FOCUS WIDGET, not to the window named
# in `event generate`, so a bare `event generate $e <KeyRelease>` on an
# unfocused entry updates the entry's text and fires NOTHING. The first cut of
# this helper had no focus loop, and on the panes fixture it measured:
#     bs_type returned |v(x1.x2*|   entry now |v(x1.x2*|
#     browser_refresh calls fired   0
#     tree ids after                unchanged, all four nodes
# i.e. the bar HELD the pattern, this helper cheerfully ANSWERED it, and the
# filter never ran — so every R5 claim built on it (BW46/BW47) was green and
# hollow. `bt_type` (test_wave_sigbrowser.tcl) has carried this loop since item
# 9 for exactly this reason; the divergence was the bug.
#
# A focus stall is answered as the VALUE `no-focus`, never printed and swallowed:
# "the keystrokes could not be delivered" must not read like "the filter matched
# nothing" either.
proc bs_type {bar text} {
  set e $bar.pat
  if {[catch {winfo exists $e} ok] || !$ok} { return no-bar }
  catch {$e delete 0 end}
  for {set i 0} {$i < 50} {incr i} {
    focus -force $e
    update
    if {[focus -displayof $e] eq $e} { break }
    after 20
  }
  if {[catch {focus -displayof $e} f] || $f ne $e} { return no-focus }
  foreach ch [split $text {}] {
    catch {$e insert end $ch}
    catch {event generate $e <KeyRelease> -keysym a}
  }
  # ⚠ AND THE EMPTY STRING MUST STILL FIRE ONCE. `split {} {}` yields no
  # elements, so the loop above runs zero times: `bs_type $bar {}` would leave
  # the ENTRY empty while the OLD pattern was still applied — the same hollow
  # shape wearing the other sign, and the state BW48/BW49 would then start from.
  # A user clearing the last character does release a key; so does this.
  if {$text eq {}} { catch {event generate $e <KeyRelease> -keysym BackSpace} }
  update
  set v {}
  catch {set v [$e get]}
  return $v
}

# --- THE SEA OF NAMES (two-pane item 11) --------------------------------------
# ⚠ THREE DISTINCT SHAPES, for spec §13.2's reason and for one more that is
# specific to this pane: 12 of tb_bandgap's 44 kept nodes are PURE ANCESTORS and
# render legitimately EMPTY, so "nothing is drawn" is a correct answer here far
# more often than it is anywhere else in the browser. A count or a boolean would
# make it indistinguishable from "the canvas was never built" and from "the
# filter correctly left nothing".
#   no-pane   the canvas does not exist
#   empty     it exists and NOTHING is drawn
#   <labels>  the rendered labels, IN FLOW ORDER
#
# ⚠ ORDER COMES FROM THE `n<idx>` TAG, NOT FROM `find withtag`'s return order.
# Canvas display order is creation order today, but it is changed by `raise`,
# `lower` and by any future re-draw that touches selected cells first — and a
# helper that silently reported a different order would make BQ50's "exact
# ordered list" pass on a scrambled pane.
proc bs_sea_labels {c} {
  if {[catch {winfo exists $c} e] || !$e} { return no-pane }
  set ids {}
  if {[catch {$c find withtag cell} ids]} { return no-pane }
  if {![llength $ids]} { return empty }
  set pairs {}
  foreach it $ids {
    set k -1
    foreach t [$c gettags $it] {
      if {[regexp {^n([0-9]+)$} $t - k]} { break }
    }
    set tx {}
    catch {set tx [$c itemcget $it -text]}
    lappend pairs [list $k $tx]
  }
  set out {}
  foreach p [lsort -integer -index 0 $pairs] { lappend out [lindex $p 1] }
  return $out
}

# Select tree row `id` and answer what the sea then draws. ONE helper rather
# than a `begin {...}`: it does one thing and answers a VALUE, and both the sea
# file and the panes file drive the two panes through it, so "selecting a node
# fills the pane" cannot be spelled two slightly different ways.
proc bs_sea_at {tv c id} {
  if {[catch {$tv selection set [list $id]}]} { return no-tree }
  update
  return [bs_sea_labels $c]
}

# The canvas item drawn for flow index `idx`, or {}. It insists on the `cell`
# tag as well, so a selection rectangle can never be mistaken for a name.
proc bs_sea_item {c idx} {
  if {[catch {$c find withtag n$idx} ids]} { return {} }
  foreach it $ids {
    if {[catch {$c gettags $it} tg]} { continue }
    if {[lsearch -exact $tg cell] >= 0} { return $it }
  }
  return {}
}

# WIDGET coordinates of a drawn cell's centre — `absent` / `nobbox` / {x y}.
#
# ⚠⚠ DERIVED FROM THE ITEM'S OWN bbox, NEVER FROM browser_flow_cell. A gesture
# test that computed its click point with the arithmetic under test would click
# wherever that arithmetic said, hit whatever that arithmetic said, and stay
# green through any consistent error in it. Reading the pixels Tk actually drew
# is what makes the click independent evidence.
proc bs_sea_xy {c idx} {
  set it [bs_sea_item $c $idx]
  if {$it eq {}} { return absent }
  if {[catch {$c bbox $it} bb] || [llength $bb] != 4} { return nobbox }
  set cx [expr {([lindex $bb 0] + [lindex $bb 2]) / 2}]
  set cy [expr {([lindex $bb 1] + [lindex $bb 3]) / 2}]
  set ox 0 ; set oy 0
  catch {set ox [$c canvasx 0]}
  catch {set oy [$c canvasy 0]}
  return [list [expr {int($cx - $ox)}] [expr {int($cy - $oy)}]]
}

# One event on the cell at flow index `idx`. Answers `absent`/`nobbox`/`ok`, so
# "the cell was not drawn" cannot masquerade as "the binding did nothing".
#
# ⚠ NO FOCUS LOOP, and that is not an oversight: Tk routes BUTTON events by
# POINTER POSITION (the window named in `event generate`), not by focus. Only
# KEY events need the loop `bs_type` carries.
#
# ⚠⚠ `-time` IS MANDATORY AND IT IS NOT A DELAY. MEASURED: `event generate`
# leaves the event's TIME FIELD AT ZERO unless it is given one, so EVERY
# synthesised press carries timestamp 0 — and Tk's double-click detector
# (tkBind.c, same position within 500 ms) sees a delta of 0 between any two
# presses at one spot and matches the SECOND one as a `<Double-Button-1>`.
# Two Ctrl-clicks on one cell therefore toggled ONCE and then PLOTTED, and no
# amount of `after` between them helped, because wall-clock time is not what Tk
# compares. A strictly increasing stamp is what makes each click its own click.
proc bs_sea_click {c idx {ev <Button-1>}} {
  set p [bs_sea_xy $c $idx]
  if {[llength $p] != 2} { return $p }
  if {![info exists ::bs_sea_t]} { set ::bs_sea_t 100000 }
  incr ::bs_sea_t 1000
  if {[catch {event generate $c $ev -x [lindex $p 0] -y [lindex $p 1] \
                -time $::bs_sea_t}]} {
    return nogen
  }
  update
  return ok
}

# ⚠ `event generate <Double-Button-1>` IS ILLEGAL (Tk: "Double, Triple, or
# Quadruple modifier not allowed"). A double-click is a PATTERN Tk recognises in
# the press/release stream, so it has to be replayed as one — bt_dclick's rule,
# one pane over.
#
# ⚠ ALL FOUR EVENTS SHARE ONE `-time`, which is the OPPOSITE of bs_sea_click's
# rule and for the same reason: here a zero delta is what MAKES the double.
proc bs_sea_dclick {c idx} {
  set p [bs_sea_xy $c $idx]
  if {[llength $p] != 2} { return $p }
  set x [lindex $p 0] ; set y [lindex $p 1]
  if {![info exists ::bs_sea_t]} { set ::bs_sea_t 100000 }
  incr ::bs_sea_t 1000
  foreach ev {<ButtonPress-1> <ButtonRelease-1> <ButtonPress-1> <ButtonRelease-1>} {
    if {[catch {event generate $c $ev -x $x -y $y -time $::bs_sea_t}]} {
      return nogen
    }
  }
  update
  return ok
}

# --- BLANK TREE SPACE, WHICH STOPPED BEING FREE (two-pane item 9) ------------
# ⚠⚠ WHY THIS EXISTS. Two checks — BT31's "a middle-click below the last row
# plots nothing" and BM21's "an RMB on BLANK tree space refuses" — spelled the
# blank coordinate as `[winfo height $tv] - 3`. That was sound while the tree
# was as tall as the sidebar. The two-pane item 9 made it ONE PANE of a
# panedwindow at a 0.55 sash, so on the 500 px fixtures the eleven rows FILL the
# tree and `height - 3` lands ON A ROW: both checks went red reporting a plot
# and a posted menu. The gate never stopped refusing — there was no blank space
# left to click. Fixing the coordinate without asserting the precondition would
# have re-armed exactly that trap for the next person who changes the layout.
#
# So: find a y that is PROVABLY blank, escalating only as far as it must, and
# report failure as a VALUE rather than as a plausible-looking 0.
#   -1  no such widget
#   -2  no real height yet (unmapped / mid-map)
#   -3  the rows fill it even with the tree pane at its tallest and every
#       top-level group collapsed — the fixture genuinely cannot express the case
# Returns {y undo}; hand `undo` to `bs_blank_undo` AFTER the gesture.
# ⚠ `identify row` TAKES BOTH COORDINATES — `$tv identify row $x $y`, exactly as
# browser_plot_at and browser_menu_post call it. The one-argument spelling is
# parsed as the legacy `identify $x $y` and throws `expected integer but got
# "row"`, which `catch` would have turned into a plausible-looking -1.
proc bs_scan_blank {tv {x 20}} {
  set h 0
  catch {set h [winfo height $tv]}
  if {$h <= 4} { return -2 }
  for {set y [expr {$h - 3}]} {$y > 2} {incr y -4} {
    if {[catch {$tv identify row $x $y} r]} { return -1 }
    if {$r eq {}} { return $y }
  }
  return -3
}
proc bs_blank_y {tv {pw {}}} {
  if {[catch {winfo exists $tv} e] || !$e} { return [list -1 {}] }
  set y [bs_scan_blank $tv]
  if {$y > 0} { return [list $y {}] }
  set undo {}
  # 1) give the tree pane the whole panedwindow
  if {$pw ne {} && ![catch {winfo class $pw} c] && $c eq {TPanedwindow}} {
    if {![catch {$pw sashpos 0} was]} {
      lappend undo [list $pw sashpos 0 $was]
      catch {$pw sashpos 0 [expr {[winfo height $pw] - 24}]}
      update idletasks ; update
      set y [bs_scan_blank $tv]
      if {$y > 0} { return [list $y $undo] }
    }
  }
  # 2) collapse the top-level groups
  foreach id [$tv children {}] {
    if {![catch {$tv item $id -open} o] && $o} {
      lappend undo [list $tv item $id -open 1]
      catch {$tv item $id -open 0}
    }
  }
  update idletasks ; update
  return [list [bs_scan_blank $tv] $undo]
}
# ⚠ Applied in REVERSE order, and NOT with `lreverse`: the repo targets Tcl
# 8.4-8.6 (rawhist_add's own note, and BP06 pins the same rule in src).
proc bs_blank_undo {undo} {
  for {set i [expr {[llength $undo] - 1}]} {$i >= 0} {incr i -1} {
    catch {eval [lindex $undo $i]}
  }
  update idletasks ; update
}

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

# src/wave_viewer.tcl as text — every item's SOURCE arm greps it, so it is read
# once here instead of once per file.
set wv [file join $repo src wave_viewer.tcl]
set fp [open $wv r]; set wsrc [read $fp]; close $fp

# The closing banner every file shares. `RESULT: ALL PASS (N checks)` is what
# full_audit.sh's is_pass greps; `RESULT: N FAILED` is not a substring of it.
proc wvbs_finish {} {
  global fail npass scratch
  catch {test_scratch_drop $scratch}
  puts "----"
  puts "$::wvbs_name: $npass passed, $fail failed"
  if {$fail == 0} {
    puts "RESULT: ALL PASS ($npass checks)"
    flush stdout
    exit 0
  } else {
    puts "RESULT: $fail FAILED ($npass passed)"
    flush stdout
    exit 1
  }
}
