# Create Instance (Cadence-style Add Instance; doc/claude/specs/cadence_create_instance.md).
# New two-dialog design:
#   - `xschem create_instance` opens the .ciform FORM (Edit > Create Instance);
#     Tools > Insert symbol is gone. The form has Library/Cell/View/Instance-name
#     entry fields + a Browse button. There is NO Place button.
#   - typing fields that resolve to a real .sym view arms a live placement preview;
#     a missing/blank View arms nothing (no view -> no preview -> cannot place).
#   - the Instance Name field becomes the placed instance's name= attribute.
#   - Browse opens the .mkinst Library Browser (OK / Apply / Cancel). The browser
#     is a pure selector: selecting a cell does NOT arm. Apply sends the selection
#     to the form (and re-arms) and keeps the browser open; OK sends and closes;
#     Cancel closes without sending. The View column shows only SYMBOL views.
#   - keep-placing: each canvas drop re-arms the same symbol.
#   - Esc ends placement AND dismisses both the form and the browser.
#   - reopening restores the form's fields and re-arms.
#   - recursion guard: a cell may not be instantiated inside its own (or an
#     ancestor's) schematic.
#   - the Legacy button routes to the no-arg place_symbol dialog.
#
# Needs X. Run under X with --pipe from src/:
#   ./xschem --pipe -q --script ../tests/headless/test_create_instance.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc touch {f txt} { file mkdir [file dirname $f]; set fp [open $f w]; puts $fp $txt; close $fp }
proc armed {} { return [expr {([xschem get ui_state] & 8192) != 0}] }
proc menu_cmd {m label} {
  if {![winfo exists $m]} { return "" }
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {![catch {$m entrycget $i -label} l] && $l eq $label} { return [$m entrycget $i -command] }
  }
  return ""
}
proc menu_has {m label} { return [expr {[menu_cmd $m $label] ne {}}] }
# fill the form fields (as if typed) and re-evaluate the preview
proc setf {l c v {i {}}} {
  set ::ciform::lib $l; set ::ciform::cell $c; set ::ciform::view $v; set ::ciform::instname $i
  ciform::arm
}
# pick a row in a browser column and run its handler
proc pick {col txt handler} {
  set lb .mkinst.pw.$col.lb
  set i [lsearch -exact [$lb get 0 end] $txt]
  if {$i < 0} return
  $lb selection clear 0 end; $lb selection set $i; $lb activate $i
  eval $handler
}

# --- fixture: a library with a sym+sch cell, a sch-only cell, and a 2-level
#     parent/child hierarchy for the ancestor-recursion test --------------------
set hdr "v {xschem version=3.4.8RC file_version=1.3}"
set tmp [test_scratch mkinst]
touch $tmp/tlib/withsym/symbol/withsym.sym    $hdr
touch $tmp/tlib/withsym/schematic/withsym.sch $hdr
touch $tmp/tlib/schonly/schematic/schonly.sch $hdr
# a cell with TWO symbol views, for the single-vs-multiple auto-fill rule
touch $tmp/tlib/multisym/symbol/multisym.sym     $hdr
touch $tmp/tlib/multisym/symbol_alt/multisym.sym $hdr
touch $tmp/tlib/child/symbol/child.sym     $hdr
touch $tmp/tlib/child/schematic/child.sch  $hdr
touch $tmp/tlib/parent/symbol/parent.sym   $hdr
touch $tmp/tlib/parent/schematic/parent.sch "$hdr\nC {tlib/child} 0 0 0 0 {}"
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tlib $tmp/tlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs

# === CI1 — create_instance opens the FORM; menu surgery; field layout ========
catch {destroy .ciform}; catch {destroy .mkinst}
xschem create_instance
update idletasks
check "CI1a xschem create_instance opens .ciform" [winfo exists .ciform] {}
check "CI1b Edit > Create Instance wired to the command" \
  [expr {[menu_cmd .menubar.edit {Create Instance}] eq {xschem create_instance}}] \
  "(=> '[menu_cmd .menubar.edit {Create Instance}]')"
check "CI1c Tools > Insert symbol removed" [expr {![menu_has .menubar.tools {Insert symbol}]}] {}
check "CI1d four entry fields present" \
  [expr {[winfo exists .ciform.f.elib] && [winfo exists .ciform.f.ecell] && \
         [winfo exists .ciform.f.eview] && [winfo exists .ciform.f.einstname]}] {}
check "CI1e Browse button present" [winfo exists .ciform.f.browse] {}
check "CI1f no Place/Create button on the form" \
  [expr {![winfo exists .ciform.f.place] && ![winfo exists .ciform.b.create]}] {}

# === CI2 — single window: re-launch reuses it (same X id) ====================
set id1 [winfo id .ciform]
xschem create_instance
update idletasks
check "CI2 single window: same X id on re-launch" \
  [expr {[winfo exists .ciform] && [winfo id .ciform] eq $id1}] "(=> $id1 / [winfo id .ciform])"

# === CI3 — typed fields arm a valid symbol; no/blank view arms nothing ========
xschem clear force
xschem abort_operation
setf tlib withsym symbol
check "CI3a complete valid fields arm the preview" [armed] "(=> ui=[xschem get ui_state])"
setf tlib withsym {}
check "CI3b blank View does NOT arm (no view -> no preview)" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
check "CI3c status asks for the missing pieces" \
  [string match {*Library, Cell and View*} [.ciform.status cget -text]] "(=> [.ciform.status cget -text])"
setf tlib schonly schematic
check "CI3d a non-symbol (schematic) view does NOT arm" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
check "CI3e status explains no symbol view" \
  [string match {*no symbol view*} [.ciform.status cget -text]] "(=> [.ciform.status cget -text])"

# === CI4 — Instance Name becomes the placed instance's name= attribute ========
xschem clear force
xschem abort_operation
setf tlib withsym symbol M7
check "CI4a armed with an instance name" [armed] {}
xschem callback .drw 4 300 300 0 1 0 0
xschem callback .drw 5 300 300 0 1 0 0
update idletasks
check "CI4b an instance named M7 was placed" [expr {![catch {xschem instance_bbox M7}]}] \
  "(=> instances=[xschem get instances])"

# === CI5 — Browse opens a live-picker browser: Cancel only, no OK/Apply =======
catch {destroy .mkinst}
xschem clear force
xschem abort_operation
ciform::browse
update idletasks
check "CI5a Browse opens .mkinst" [winfo exists .mkinst] {}
check "CI5b Cancel button present" [winfo exists .mkinst.b.cancel] {}
check "CI5c no OK / Apply buttons" \
  [expr {![winfo exists .mkinst.b.ok] && ![winfo exists .mkinst.b.apply]}] {}
check "CI5d browser lists tlib" [expr {[lsearch [.mkinst.pw.lib.lb get 0 end] tlib] >= 0}] {}

# === CI6 — every selection applies to the form LIVE ==========================
pick lib tlib mkinst::on_lib
check "CI6a selecting a library fills the form's Library field" \
  [expr {$::ciform::lib eq {tlib} && $::ciform::cell eq {} && $::ciform::view eq {}}] \
  "(=> $::ciform::lib/$::ciform::cell/$::ciform::view)"
pick cell withsym mkinst::on_cell
check "CI6b View column shows only symbol views" [expr {[.mkinst.pw.view.lb get 0 end] eq {symbol}}] \
  "(=> [.mkinst.pw.view.lb get 0 end])"
check "CI6c single symbol view: clicking the cell ALSO fills the form's View" \
  [expr {$::ciform::cell eq {withsym} && $::ciform::view eq {symbol}}] \
  "(=> $::ciform::cell/$::ciform::view)"
check "CI6d a complete live selection arms the preview" [armed] "(=> ui=[xschem get ui_state])"

# === CI6e/f — multiple symbol views: cell click does NOT fill View ===========
pick cell multisym mkinst::on_cell
check "CI6e multiple symbol views listed" \
  [expr {[lsort [.mkinst.pw.view.lb get 0 end]] eq {symbol symbol_alt}}] "(=> [.mkinst.pw.view.lb get 0 end])"
check "CI6f multi-view cell leaves the form's View empty (no auto-fill)" \
  [expr {$::ciform::cell eq {multisym} && $::ciform::view eq {}}] "(=> $::ciform::cell/$::ciform::view)"
check "CI6g multi-view cell with no View chosen does NOT arm" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
pick view symbol_alt mkinst::on_view
check "CI6h clicking a View fills it and arms" \
  [expr {$::ciform::view eq {symbol_alt} && [armed]}] "(=> view=$::ciform::view ui=[xschem get ui_state])"

# === CI7 — Esc and Cancel dismiss the browser (form keeps the selection) ======
check "CI7a browser open before dismiss" [winfo exists .mkinst] {}
check "CI7b Esc on the browser is wired to mkinst::cancel" \
  [string match {*mkinst::cancel*} [bind .mkinst <Key-Escape>]] "(=> [bind .mkinst <Key-Escape>])"
check "CI7c Cancel button is wired to mkinst::cancel" \
  [expr {[.mkinst.b.cancel cget -command] eq {mkinst::cancel}}] {}
mkinst::cancel   ;# what both Esc and the Cancel button invoke
update idletasks
check "CI7d browser dismissed" [expr {![winfo exists .mkinst]}] {}
check "CI7e the form survived and kept the live selection" \
  [expr {[winfo exists .ciform] && $::ciform::cell eq {multisym} && $::ciform::view eq {symbol_alt}}] \
  "(=> $::ciform::cell/$::ciform::view)"
xschem abort_operation

# === CI8 — keep-placing: each drop re-arms the same symbol ====================
xschem clear force
xschem abort_operation
setf tlib withsym symbol
check "CI8a armed (preview attached)" [armed] {}
xschem callback .drw 4 300 300 0 1 0 0
xschem callback .drw 5 300 300 0 1 0 0
check "CI8b drop cleared the placement" [expr {![armed]}] {}
ciform::after_drop 1
check "CI8c same symbol re-armed after drop" [armed] {}
xschem callback .drw 4 500 500 0 1 0 0
xschem callback .drw 5 500 500 0 1 0 0
ciform::after_drop 1
check "CI8d two instances placed (continuous)" [expr {[xschem get instances] >= 2}] "(=> [xschem get instances])"
check "CI8e drop hook wired on the canvas" [string match {*after_drop*} [bind .drw <ButtonRelease>]] {}

# === CI9 — Esc ends placement AND dismisses form + browser ===================
ciform::browse
update idletasks
setf tlib withsym symbol
check "CI9a armed, browser open, before Esc" [expr {[armed] && [winfo exists .mkinst]}] {}
ciform::escape
update idletasks
check "CI9b Esc cleared the placement" [expr {![armed]}] {}
check "CI9c Esc dismissed the form" [expr {![winfo exists .ciform]}] {}
check "CI9d Esc dismissed the browser too" [expr {![winfo exists .mkinst]}] {}

# === CI10 — reopen restores the form fields and re-arms =======================
xschem create_instance
update idletasks
check "CI10a reopened" [winfo exists .ciform] {}
check "CI10b fields persisted" \
  [expr {$::ciform::lib eq {tlib} && $::ciform::cell eq {withsym} && $::ciform::view eq {symbol}}] \
  "(=> $::ciform::lib/$::ciform::cell/$::ciform::view)"
check "CI10c preview re-armed on reopen" [armed] "(=> ui=[xschem get ui_state])"
xschem abort_operation

# === CI11 — Legacy button routes to the no-arg place_symbol dialog ============
check "CI11a Legacy button calls ciform::legacy" [expr {[.ciform.b.legacy cget -command] eq {ciform::legacy}}] {}
check "CI11b ciform::legacy uses no-arg place_symbol" \
  [expr {[string trim [info body ciform::legacy]] eq {xschem place_symbol}}] \
  "(=> '[string trim [info body ciform::legacy]]')"

# === CI12 — recursion guard (self and ancestor) ==============================
xschem abort_operation
xschem load $tmp/tlib/withsym/schematic/withsym.sch
setf tlib withsym symbol
check "CI12a placing a cell in its OWN schematic is blocked" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
check "CI12b status explains the recursion" [string match {*recursion*} [.ciform.status cget -text]] \
  "(=> [.ciform.status cget -text])"
# ancestor: descend parent>child, then try to place parent (and child)
xschem abort_operation
xschem load $tmp/tlib/parent/schematic/parent.sch
xschem select_all
xschem descend
check "CI12c descended one level into child" [expr {[xschem get currsch] == 1}] "(=> currsch=[xschem get currsch])"
setf tlib parent symbol
check "CI12d placing an ANCESTOR (parent) in a descendant is blocked" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
setf tlib child symbol
check "CI12e the current cell (child) is also blocked" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
setf tlib withsym symbol
check "CI12f a cell not in the stack still arms" [armed] "(=> ui=[xschem get ui_state])"
xschem abort_operation

# === CI13 — `create_instance <lcv>` pre-fills the form (library_manager-style) ==
xschem clear force
xschem abort_operation
catch {destroy .ciform}
xschem create_instance {tlib withsym symbol}
update idletasks
check "CI13a list arg pre-fills the fields" \
  [expr {$::ciform::lib eq {tlib} && $::ciform::cell eq {withsym} && $::ciform::view eq {symbol}}] \
  "(=> $::ciform::lib/$::ciform::cell/$::ciform::view)"
check "CI13b pre-filled fields arm the preview" [armed] {}
# the reported bug: an ALREADY-OPEN form switches to the new cell, not the old one
xschem create_instance {tlib child symbol}
update idletasks
check "CI13c re-open with a list switches cell on the open form" \
  [expr {$::ciform::cell eq {child}}] "(=> $::ciform::cell)"
# a 4th element sets the Instance Name
xschem create_instance {tlib withsym symbol N9}
update idletasks
check "CI13d 4-element list sets the Instance Name" \
  [expr {$::ciform::instname eq {N9}}] "(=> $::ciform::instname)"
# a bare reopen keeps the last fields (singleton, no clobber)
xschem abort_operation
xschem create_instance
update idletasks
check "CI13e bare reopen keeps the last fields" [expr {$::ciform::cell eq {withsym}}] "(=> $::ciform::cell)"
xschem abort_operation

# === CI14 — issue 0245: the `.drw <Key-Escape>` grab must not SWALLOW canvas Escape ====
# The form seizes the single `.drw <Key-Escape>` slot so Escape closes it from the canvas.
# create_instance.tcl does that with an UNGUARDED `{ciform::escape; break}` -- no
# `winfo exists` test at all -- and ciform::escape is `armed 0; abort_if_placing; destroy`,
# where abort_if_placing only fires while PLACE_SYMBOL is set. With the form open but no
# preview armed, the whole Escape is a destroy, and the sixteen lines of callback.c's
# `case XK_Escape:` never run: no abort_operation, no tclstop, no MENUSTARTWIRE clear, no
# snap-cursor erase, no cadence last_command fixup.
# Measured under xvfb: `xschem wire` (ui=65536 ui2=1), one real `<Key-Escape>` on .drw with
# a form open -> ui/ui2 BYTE-IDENTICAL, and the next canvas click began an unrequested wire
# draw (ui 65537, last_command 1). With .addpin AND .addlabel open it took THREE Escapes to
# reach ui=0. Tk delivers Escape to `<Key-Escape>` ONLY -- the generic `<KeyPress>` -> C
# dispatcher on the same bindtag never fires, with or without the `break` -- so this half is
# measurable only under a real display, which is why it lives in THIS suite.
# The fix: a TOTAL slot script (form alive -> ciform::canvas_escape, else -> `xschem escape`,
# the named C terminal) and a release-to-sibling on_destroy instead of a blanket unbind.
# ⚠ Do NOT "harden" this into a poll for `[focus] eq .drw`. That was tried on :0
# (2026-08-15) and is a trap: with a form toplevel open, `[focus]` reports the FORM
# (.ciform / .addlabel) even after `focus -force .drw`, because it names the focus
# window of whichever toplevel the WM has focused. A 5 s poll therefore ran to its
# full timeout on 2 of the 3 esc14 calls, never reached `.drw`, changed no verdict,
# and added ~10 s per run -- lengthening the window in which WSLg's Xwayland can die
# under it. The generated Escape lands anyway. The CI14c/CI14d/CI14g reds seen on a
# BUSY :0 travel with `X connection to :0 broken (explicit kill or server shutdown)`
# in sibling runs: they are the documented Xwayland teardown, not a settle lag, and
# no amount of waiting fixes a server that is going away. Left as it was, deliberately.
proc esc14 {} { focus -force .drw ; update ; event generate .drw <Key-Escape> ; update }

catch {destroy .addlabel}; catch {destroy .addpin}; catch {destroy .mkinst}
catch {destroy .ciform}
xschem clear force
xschem abort_operation
ciform::open
update idletasks
set b14 [bind .drw <Key-Escape>]
check "CI14a the slot names the form it is tearing down" \
  [expr {[string match {*winfo exists .ciform*} $b14] && \
         [string match {*ciform::canvas_escape*} $b14]}] "(=> '$b14')"
check "CI14b the slot is TOTAL: a dead form falls through to the C terminal" \
  [string match {*xschem escape*} $b14] "(=> '$b14')"

# CI14c/d — REAL delivery: one canvas Escape with the form open must run the C terminal.
xschem abort_operation
xschem wire
check "CI14c precondition: menu wire armed" \
  [expr {[xschem get ui_state] == 65536 && [xschem get ui_state2] == 1}] \
  "(=> ui=[xschem get ui_state] ui2=[xschem get ui_state2])"
esc14
check "CI14c one canvas Escape aborted the arm" [expr {[xschem get ui_state] == 0}] \
  "(=> ui=[xschem get ui_state])"
check "CI14d one canvas Escape cleared MENUSTARTWIRE" [expr {[xschem get ui_state2] == 0}] \
  "(=> ui2=[xschem get ui_state2])"
xschem abort_operation

# CI14e — 0122-E2 clobber: ciform::on_destroy clears the SHARED slot unconditionally, so
#   closing the Create-Instance form strands a still-open Add-Wire-Label form with no canvas
#   Escape at all. Asserted on the SLOT CONTENT, not on the Escape outcome: with a total slot
#   script the Escape still works, so an outcome-only row would stay green over the clobber.
catch {destroy .ciform}; catch {destroy .addlabel}
xschem clear force
xschem abort_operation
addlabel::open
update idletasks
ciform::open
update idletasks
destroy .ciform
update idletasks
check "CI14e closing the form releases the slot to the live sibling" \
  [expr {[winfo exists .addlabel] && [string match {*addlabel::*} [bind .drw <Key-Escape>]]}] \
  "(=> alive=[winfo exists .addlabel] slot='[bind .drw <Key-Escape>]')"
catch {destroy .addlabel}
update idletasks

# CI14f — ONE Escape is enough. Two sibling forms open, addlabel owns the slot; today the
#   first Escape only closes addlabel and hands the slot to addpin, the second closes addpin,
#   and only the THIRD reaches C.
xschem clear force
xschem abort_operation
addpin::open
update idletasks
addlabel::open
update idletasks
xschem abort_operation
xschem wire
check "CI14f precondition: two forms open, wire armed" \
  [expr {[winfo exists .addpin] && [winfo exists .addlabel] && [xschem get ui_state] == 65536}] \
  "(=> ui=[xschem get ui_state])"
esc14
check "CI14f one Escape aborts the gesture with two forms open" \
  [expr {[xschem get ui_state] == 0}] "(=> ui=[xschem get ui_state])"
catch {destroy .addlabel}; catch {destroy .addpin}
update idletasks

# CI14g — a STALE grab. clone_canvas_bindings copies a live grab onto every newly created
#   canvas and release_esc only ever unbinds `.drw`, so a grab whose form is gone becomes a
#   permanent Escape sink (0122-F3). The total slot script makes that harmless.
xschem clear force
xschem abort_operation
catch {destroy .addlabel}
addlabel::grab_esc          ;# the grab, with no .addlabel toplevel behind it
xschem wire
check "CI14g precondition: stale grab installed, wire armed" \
  [expr {![winfo exists .addlabel] && [bind .drw <Key-Escape>] ne {} && \
         [xschem get ui_state] == 65536}] "(=> ui=[xschem get ui_state])"
esc14
check "CI14g a stale grab no longer swallows Escape" [expr {[xschem get ui_state] == 0}] \
  "(=> ui=[xschem get ui_state])"
catch {bind .drw <Key-Escape> {}}
xschem abort_operation

# === CI15 — issue 0245, the half CI14 cannot see: Tk routes a key to `[focus]`, NOT to the
#   window named in `event generate`. Every placement form ends open() by focusing its first
#   entry (.addlabel.f.ename / .addpin.f.ename / .ciform.f.elib), so from the moment the form
#   appears until the user next CLICKS the canvas it is the form's own toplevel <Key-Escape>
#   that fires and the `.drw` slot never runs at all. CI14's esc14 does `focus -force .drw`
#   first, which manufactures a state the product does not reach unaided -- so CI14 alone
#   stayed green while the defect was still live on the plainest user path there is:
#     arm a wire, open Add-Wire-Label from the menu, press Escape.
#   Measured under xvfb with the form-focused binding still `{addlabel::escape}`:
#     armed ui=65536 ui2=1 -> Escape -> ui=65536 ui2=1 (BYTE-IDENTICAL), form destroyed,
#   i.e. exactly the 0245 damage, and the next canvas click began an unrequested wire draw.
#   Note the arm SURVIVES form open (measured: `xschem wire` then addlabel::open leaves
#   ui=65536 ui2=1 and moves focus into the form), so the sequence needs no trickery.
#   The fix points each form's own <Key-Escape> at ::canvas_escape too. The Close BUTTON
#   keeps plain ::escape -- rows L3/P3 in the sibling suites pin that.
#   DELIBERATELY no `focus -force` here: these rows must fail if form focus ever regresses.
proc esc15 {} { event generate .drw <Key-Escape> ; update }

foreach {ci15 opener top wantfocus} {
  a addlabel::open .addlabel .addlabel.f.ename
  b addpin::open   .addpin   .addpin.f.ename
  c ciform::open   .ciform   .ciform.f.elib
} {
  foreach w {.addlabel .addpin .ciform .mkinst} { catch {destroy $w} }
  xschem clear force
  xschem abort_operation
  xschem abort_operation
  focus -force .drw
  update
  catch {$opener}
  # ⚠ WAIT for the focus to actually ARRIVE -- one `update` is not enough on WSLg.
  # `update idletasks` processes no X events at all, so it can never see the FocusIn
  # that open()'s `focus $w.f.ename` depends on; a single full `update` processes only
  # what the server has ALREADY sent, which on :0 is frequently nothing yet, and the
  # precondition then reads `focus=` EMPTY -- focus on nobody, neither form nor .drw.
  #
  # MEASURED, 2026-08-15, by instrumenting this very loop with its iteration count
  # (one iteration = one `update` + 25 ms). On the Xvfb dev display :99: 0 iterations,
  # all three legs, every run -- the single `update` was always enough there, which is
  # why :99 never saw this. On the user's real WSLg screen :0, five runs: 0, 1, 3, 5
  # and 76 iterations (76 = ~1.9 s of real waiting before the form's entry took focus).
  # Under a second gated GUI batch running on :0 concurrently the bare `update` was
  # enough in only 2 runs of 8. So on :0 a single `update` is a coin flip decided by
  # compositor state, not a wait.
  #
  # THE POLL DOES NOT MASK A REAL FAILURE, and that is measured too, not asserted: in
  # one of those five runs the form never took focus at all, the loop ran to its full
  # 200 iterations with `[focus]` still `.drw`, and CI15a went RED exactly as it should.
  # The precondition below stays the ASSERTION -- the loop only tests the same
  # `[focus] eq $wantfocus` the check does, and never forces it. This is the class-(a)
  # WSLg-traffic pattern of test_calc_skeleton S12: force the race in the test; do not
  # chase window managers, and never `focus -force` here -- that would manufacture the
  # state the product must reach unaided, which is the exact hollowness CI15 exists to
  # escape from CI14.
  for {set _f 0} {$_f < 200} {incr _f} {
    update
    if {[winfo exists $top] && [focus] eq $wantfocus} break
    after 25
  }
  xschem wire
  check "CI15$ci15 precondition: $top open, focus in the FORM, wire armed" \
    [expr {[winfo exists $top] && [focus] eq $wantfocus && \
           [xschem get ui_state] == 65536 && [xschem get ui_state2] == 1}] \
    "(=> focus=[focus] ui=[xschem get ui_state] ui2=[xschem get ui_state2])"
  esc15
  check "CI15$ci15 form-focused Escape aborted the arm ($top)" \
    [expr {[xschem get ui_state] == 0 && [xschem get ui_state2] == 0}] \
    "(=> ui=[xschem get ui_state] ui2=[xschem get ui_state2])"
  xschem abort_operation
}
foreach w {.addlabel .addpin .ciform .mkinst} { catch {destroy $w} }
catch {bind .drw <Key-Escape> {}}

# === CI16/CI17/CI18 — issue 0831: the two insert-symbol brace-concat sinks ===
# BOTH doors take a string and hand it to Tcl by C string CONCATENATION, so a
# `}` in the string closes the brace group and the rest parses as script:
#   scheduler.c:2726  tclvareval("ciform::open {", argv[2], "}", NULL)
#   callback.c:559    tclvareval("set INITIALINSTDIR [file dirname {",
#                          abs_sym_path(tcl_hook2(inst[].name), ""), "}]", NULL)
# The second is the sharper one: `inst[].name` is a SYMBOL REFERENCE read
# straight out of the `.sch`, `\}` is the file format's OWN escape for a literal
# brace (so the fixture is well-formed, not corrupt), and the splice sits inside
# a `[file dirname {…}]` COMMAND SUBSTITUTION — 0829's bracket problem on top of
# 0827's brace problem. 0831 §4 recorded callback.c:559 as "verified present,
# NOT individually driven"; CI17 drives it through the real key, so the claim is
# upgraded on a measurement.
#
# WHY THE KEY AND NOT THE VERB. `xschem place_symbol` reaches the scheduler.c
# twin (covered headless by LM10/LM11 in test_raw_read_dispatch.tcl). This
# block is the ONLY cover for callback.c's copy, which is reached from key `I`
# (callback.c:7693), the Insert key (:8831) and context-menu pick 1 (:5264),
# and only when new_file_browser is OFF. `xschem callback . KeyPress … 73 …`
# SEGFAULTS under --nogui (a separate, pre-existing defect), so a real
# `event generate` under X is the only honest drive.
#
# ⚠ THE DIALOG IS STUBBED, and that is what makes this row terminate.
# start_place_symbol() calls place_symbol(-1,NULL,…), which opens a MODAL
# chooser and hangs the script AFTER the payload has already fired — measured.
# A stub returning "" makes place_symbol hit `if(!name1[0]) return 0`
# (actions.c:3359) and come straight back. Same pattern as
# test_wave_clear_all.tcl / test_nh_editor_load.tcl. Never assert on a `puts`
# placed after the keypress; assert on the host file and the variable.
#
# ⚠ ANTI-HOLLOW (issue 0828). CI16's positive twins are the EXISTING CI13a /
# CI13c / CI13d (plus CI6b-CI6h, CI7e) — they drive the ARGUMENT form
# `xschem create_instance {tlib withsym symbol}` and so run the converted
# tcl_call at scheduler.c:2729. NOT CI1a: this comment used to name it and
# that was WRONG (issue 0835). CI1a calls the verb BARE, taking scheduler.c's
# untouched `else tcleval("ciform::open")` branch, so it stays green with the
# argument path gutted. Measured under sabotage: CI13b/c/d and CI6b-CI6h went
# red, CI1a did not. Name the row that drives the converted path.
# CI17's twin is CI18 below — without it, deleting start_place_symbol()'s whole
# INITIALINSTDIR block scores a pass.
#
# ⚠ CLAIMS (issue 0823). A `.sch` is executable BY DESIGN — and callback.c:560
# calls tcl_hook2() on the instance name ITSELF, so a `tcleval(`-prefixed
# reference still runs its Tcl here whatever these rows say. What they pin is
# narrower: the path that executes WITHOUT SAYING SO.
proc ci_sch_esc {s} { return [string map [list \{ \\\{ \} \\\}] $s] }
proc ci_pay {host} { return "x\} ; set ::SC_PWNED 1; exec touch $host; list \{y" }
proc ci_sch {path nm} {
  set fp [open $path w]
  puts -nonewline $fp "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {[ci_sch_esc $nm]} 0 0 0 0 {name=x1}\n"
  close $fp
}

# --- CI16: scheduler.c:2726, the `xschem create_instance <lcv>` argument ----
catch {destroy .ciform}; catch {destroy .mkinst}
set ::SC_PWNED 0
set CI_H16 [file join $tmp HOST_CI16]
catch {file delete -force $CI_H16}
set ci_p16 [ci_pay $CI_H16]
catch {xschem create_instance $ci_p16} ci_r16
update idletasks
set CI_E16 [file exists $CI_H16]
catch {file delete -force $CI_H16}
check "CI16 create_instance lcv argument does not execute (0831, scheduler.c:2726)" \
  [expr {$::SC_PWNED == 0 && $CI_E16 == 0}] \
  "(=> pwned=$::SC_PWNED host=$CI_E16 answer='$ci_r16')"
catch {destroy .ciform}; catch {destroy .mkinst}

# --- CI17: callback.c:559, the REAL key-`I` route ---------------------------
set ci_nfb [expr {[info exists ::new_file_browser] ? $::new_file_browser : 0}]
set ::new_file_browser 0
set ci_stub 0
if {![catch {rename load_file_dialog __ci_real_lfd}]} {
  proc load_file_dialog {args} { return {} }
  set ci_stub 1
}
set ::SC_PWNED 0
set CI_H17 [file join $tmp HOST_CI17]
catch {file delete -force $CI_H17}
ci_sch [file join $tmp ci_evil.sch] [ci_pay $CI_H17]
catch {xschem set_modify 0}
catch {xschem load [file join $tmp ci_evil.sch]}
catch {xschem select_all}
set ::INITIALINSTDIR NOTSET
update
focus -force .drw
update
event generate .drw <KeyPress> -keysym I
update
set CI_E17 [file exists $CI_H17]
set CI_IID17 $::INITIALINSTDIR
catch {file delete -force $CI_H17}
catch {xschem abort_operation}
check "CI17 key-I start_place_symbol does not execute the .sch symbol reference (0831, callback.c:559)" \
  [expr {$::SC_PWNED == 0 && $CI_E17 == 0 && $CI_IID17 ne "y"}] \
  "(=> pwned=$::SC_PWNED host=$CI_E17 INITIALINSTDIR='$CI_IID17' — `y` is the\
 payload's own `list {y}` tail returned through the command substitution)"

# --- CI18: ANTI-HOLLOW twin of CI17 -----------------------------------------
ci_sch [file join $tmp ci_ok.sch] tlib/withsym
catch {xschem set_modify 0}
catch {xschem load [file join $tmp ci_ok.sch]}
catch {xschem select_all}
set ::INITIALINSTDIR NOTSET
update
focus -force .drw
update
event generate .drw <KeyPress> -keysym I
update
set CI_IID18 $::INITIALINSTDIR
catch {xschem abort_operation}
check "CI18 key-I still sets INITIALINSTDIR to the selected symbol's directory" \
  [expr {$CI_IID18 eq [file join $tmp tlib withsym symbol] && [file isdirectory $CI_IID18]}] \
  "(=> INITIALINSTDIR='$CI_IID18' want '[file join $tmp tlib withsym symbol]')"
if {$ci_stub} {
  catch {rename load_file_dialog {}}
  catch {rename __ci_real_lfd load_file_dialog}
}
set ::new_file_browser $ci_nfb
catch {xschem set_modify 0}

catch {destroy .ciform}; catch {destroy .mkinst}
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
