#
#  File: pin_name_text.tcl
#
#  Headless regression for Cadence-style pin-owned name text (Option B), phases P0-P1:
#  on load, materialize an editable pin-name "view" (a transient xText) for every OWNED
#  + SHOWN symbol pin; never persist those views on save (S3); regenerate on load (S1).
#  See doc/claude/specs/cadence_pin_name_text.md
#
#  Run UNDER xschem:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script pin_name_text.tcl
#

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

set wd [file normalize ./pin_name_text_work]
file delete -force $wd
file mkdir $wd

# write a minimal symbol file: standard header + caller-supplied body
proc write_sym {path body} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
  puts $fp "G {}"
  puts $fp "K {type=subcircuit}"
  puts $fp "V {}"
  puts $fp "S {}"
  puts $fp "E {}"
  puts -nonewline $fp $body
  close $fp
}

# count lines in a file matching a glob pattern
proc count_lines {path pat} {
  set n 0
  set fp [open $path r]
  while {[gets $fp line] >= 0} { if {[string match $pat $line]} { incr n } }
  close $fp
  return $n
}

# ---------------------------------------------------------------------------
# 1. OWNED + SHOWN pin (show_pinname=true), NO standalone T in the file.
#    On load, exactly one synthesized name view must appear (S1).
# ---------------------------------------------------------------------------
set f1 $wd/owned.sym
write_sym $f1 "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_dx=20 name_dy=-5 name_size=0.2}\n"
xschem load $f1
check "owned pin: one PINLAYER rect"     [xschem get rects 5] 1
check "owned pin: one synth view"        [xschem get texts]   1

# ---------------------------------------------------------------------------
# 2. Save must NOT persist the view (S3): saved file has 0 T records, keeps the pin.
# ---------------------------------------------------------------------------
set o1 $wd/owned_out.sym
xschem saveas $o1 symbol
check "save: view not persisted (0 T)"   [count_lines $o1 "T *"]   0
check "save: pin B record kept"          [count_lines $o1 "B 5 *"] 1
check "save: show_pinname token kept"    [expr {[count_lines $o1 "*show_pinname=true*"] >= 1}] 1

# ---------------------------------------------------------------------------
# 3. Round-trip: reload the saved file (view re-synthesized, S1) and save again ->
#    byte-identical, proving views never leak and load is deterministic.
# ---------------------------------------------------------------------------
xschem load $o1
check "reload: one synth view again"     [xschem get texts] 1
set o2 $wd/owned_out2.sym
xschem saveas $o2 symbol
set same [expr {![catch {exec cmp -s $o1 $o2}]}]
check "round-trip byte-identical"        $same 1

# ---------------------------------------------------------------------------
# 4. Negative: a LEGACY pin (no show_pinname token) must NOT get a view.
# ---------------------------------------------------------------------------
set f2 $wd/legacy.sym
write_sym $f2 "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"
xschem load $f2
check "legacy pin: no synth view"        [xschem get texts] 0

# ---------------------------------------------------------------------------
# 5. Negative: OWNED but HIDDEN (show_pinname=false) must NOT get a view.
# ---------------------------------------------------------------------------
set f3 $wd/hidden.sym
write_sym $f3 "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=false name_size=0.2}\n"
xschem load $f3
check "hidden pin: no synth view"        [xschem get texts] 0

# ---------------------------------------------------------------------------
# 6. Mixed: an owned pin + a legacy pin + a real stray T. Only the owned pin gets a
#    view; the stray T persists on save, the view does not.
# ---------------------------------------------------------------------------
set f4 $wd/mixed.sym
write_sym $f4 "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_size=0.2}\nB 5 -2.5 17.5 2.5 22.5 {name=B dir=in}\nT {hello} 30 30 0 0 0.2 0.2 {}\n"
xschem load $f4
# in memory: stray "hello" (1) + synth view for A (1) = 2
check "mixed: stray T + one synth view"  [xschem get texts] 2
set o4 $wd/mixed_out.sym
xschem saveas $o4 symbol
check "mixed save: only stray T persists" [count_lines $o4 "T *"]   1
check "mixed save: two pins kept"         [count_lines $o4 "B 5 *"] 2

# ---------------------------------------------------------------------------
# 7. P2 creation: add_symbol_pin makes an OWNED pin (tokens) + a view; the view is
#    not persisted, but the name_* / show_pinname tokens are, so reload reproduces it.
#    (draw=0 to stay headless; scripted path = exact placement.)
# ---------------------------------------------------------------------------
xschem clear force
xschem add_symbol_pin 0 0 IN in 0
check "create: one PINLAYER rect"        [xschem get rects 5] 1
check "create: one synth view"           [xschem get texts]  1
check "create: show_pinname token"       [xschem getprop rect 5 0 show_pinname] true
check "create: name_size token"          [xschem getprop rect 5 0 name_size] 0.2
set oc $wd/created.sym
xschem saveas $oc symbol
check "create save: view not persisted"  [count_lines $oc "T *"]   0
check "create save: pin persisted"       [count_lines $oc "B 5 *"] 1
check "create save: layout token persisted" [expr {[count_lines $oc "*name_dx=*"] >= 1}] 1
xschem load $oc
check "create reload: view re-synth"     [xschem get texts] 1

# out/inout pin: name placed on the left (name_flip=1)
xschem clear force
xschem add_symbol_pin 0 0 OUT out 0
check "create out: name_flip token"      [xschem getprop rect 5 0 name_flip] 1

# ---------------------------------------------------------------------------
# 8. DISK undo must regenerate views (pop_undo -> read_xschem_file has no synth of its
#    own). Load an owned-pin symbol (1 view), add a second pin (push_undo), undo, and
#    the first pin's view must reappear. Before the fix, disk-undo left texts at 0.
# ---------------------------------------------------------------------------
catch {xschem undo_type disk}
xschem load $f1
check "disk-undo: baseline one view"     [xschem get texts] 1
xschem add_symbol_pin 0 40 B in 0
check "disk-undo: two views after add"   [xschem get texts] 2
xschem undo
check "disk-undo: view regenerated"      [xschem get texts] 1

# ---------------------------------------------------------------------------
# 9. P3 move write-through. owned.sym pin center is (0,0) with name_dx=20.
#    (a) Moving the VIEW alone records the new offset on the pin (name_dx -> 40).
#    (b) Moving pin+view together (translation) leaves the offset unchanged.
# ---------------------------------------------------------------------------
xschem load $f1
xschem unselect_all
xschem select text 0                  ;# the synthesized name view
xschem move_objects 20 0              ;# drag the label +20 in x
set o9 $wd/moved_view.sym
xschem saveas $o9 symbol
check "move view: name_dx written back" [xschem getprop rect 5 0 name_dx] 40

xschem load $f1                       ;# fresh: name_dx back to 20
xschem unselect_all
xschem select rect 5 0                ;# the pin
xschem select text 0                  ;# and its view -> move together
xschem move_objects 20 0
set o9b $wd/moved_both.sym
xschem saveas $o9b symbol
check "move both: name_dx unchanged"    [xschem getprop rect 5 0 name_dx] 20

# ---------------------------------------------------------------------------
# 10. Two property editors over the pin's tokens (D-split, headless Tcl; dialogs GUI-manual):
#     `pin` (Q on the pin body) edits identity; `pinname` (Q on the name text) edits the
#     name-text appearance. Each shows only its own fields and HIDES (preserves) the rest.
# ---------------------------------------------------------------------------
proc visible_toks {schema} {
  set t {}
  foreach row $schema {
    if {!([dict exists $row hide] && [dict get $row hide])} { lappend t [dict get $row tok] }
  }
  return $t
}
set sch [slickprop::gfx_schema pin]
check "pin form visible fields"  [visible_toks $sch] {name dir show_pinname}
check "pin dir is a dropdown"    [dict get [lindex $sch 1] widget] enum
check "pin dir choices"          [dict keys [dict get [lindex $sch 1] choices]] {input output inout}
check "pin name is single-line"  [dict get [lindex $sch 0] widget] string
set scn [slickprop::gfx_schema pinname]
check "pinname form visible fields" [visible_toks $scn] {name_size name_font name_dx name_dy name_rot name_flip}
# schema_assemble must preserve each editor's HIDDEN tokens (so editing one editor never
# drops the other's fields). orig carries both identity and layout tokens.
set orig {name=A dir=in show_pinname=true name_dx=25 name_size=0.2}
set pinx  [slickprop::schema_extra $sch $orig]
set pinres [slickprop::schema_assemble $sch $orig {name B dir in show_pinname true} $pinx]
check "pin edit keeps name_dx"   [xschem get_tok $pinres name_dx 2] 25
check "pin edit sets name"       [xschem get_tok $pinres name 2] B
set pnx   [slickprop::schema_extra $scn $orig]
set pnres [slickprop::schema_assemble $scn $orig {name_size 0.5 name_font {} name_dx 25 name_dy {} name_rot {} name_flip {}} $pnx]
check "pinname edit keeps name"  [xschem get_tok $pnres name 2] A
check "pinname edit keeps dir"   [xschem get_tok $pnres dir 2] in
check "pinname edit sets size"   [xschem get_tok $pnres name_size 2] 0.5
# a selected PINLAYER (layer 5) rect routes to the pin form; the via-name marker -> pinname
xschem clear force
xschem add_symbol_pin 0 0 IN in 0
xschem unselect_all
xschem select rect 5 0
set ::gfxform_via_name 0
check "selected_type = pin"           [gfxform::selected_type] pin
set ::gfxform_via_name 1
check "selected_type = pinname (name)" [gfxform::selected_type] pinname
set ::gfxform_via_name 0
# name_font (the pinname editor's Font field) carries onto the synthesized view: set it on
# the pin, round-trip, and the regenerated view must wear the font.
xschem setprop rect 5 0 name_font Courier
set off $wd/pinfont.sym
xschem saveas $off symbol
xschem load $off
check "font: token persisted"    [xschem getprop rect 5 0 name_font] Courier
check "font: view wears it"      [xschem getprop text 0 font] Courier

# ---------------------------------------------------------------------------
# 10b. Live Apply (xschem apply_pin_prop): the pin/pinname forms' Apply commits to the
#      selected pin(s) + redraws without closing. Idempotent (no-op -> no undo slot).
# ---------------------------------------------------------------------------
xschem clear force symbol
xschem add_symbol_pin 0 0 NN in 0
xschem unselect_all; xschem select rect 5 0
set base "name=NN dir=in show_pinname=true name_dx=25 name_dy=-5 name_size=0.2"
set changed "name=NN dir=in show_pinname=true name_dx=25 name_dy=-5 name_size=0.4 name_font=Courier"
check "apply: changed -> 1"      [xschem apply_pin_prop $changed] 1
check "apply: size on pin"       [xschem getprop rect 5 0 name_size] 0.4
check "apply: font on pin"       [xschem getprop rect 5 0 name_font] Courier
check "apply: view wears font"   [xschem getprop text 0 font] Courier
check "apply: re-apply -> 0"     [xschem apply_pin_prop $changed] 0
xschem undo
check "apply: undo reverts size" [xschem getprop rect 5 0 name_size] 0.2
# show_pinname=false via Apply removes the name view
xschem apply_pin_prop "name=NN dir=in show_pinname=false name_dx=25 name_dy=-5 name_size=0.2"
check "apply: hide removes view" [xschem get texts] 0

# ---------------------------------------------------------------------------
# 11. Creation via the Add-pin dialog: addpin::place sets ::pin_new_name/::pin_new_dir,
#     then `xschem add_symbol_pin -place` creates the pin (rect + owned name view).
# ---------------------------------------------------------------------------
xschem clear force
set ::pin_new_name CK
set ::pin_new_dir out
xschem add_symbol_pin -place
check "dialog place: one pin"   [xschem get rects 5] 1
check "dialog place: name set"  [xschem getprop rect 5 0 name] CK
check "dialog place: dir set"   [xschem getprop rect 5 0 dir] out
check "dialog place: view made" [xschem get texts] 1

# ---------------------------------------------------------------------------
# 11b. Add-Pin live cursor PREVIEW (item #3). The modeless dialog re-issues `-place`
#      on every Name/Direction keystroke. Re-arming must (a) replace the previous
#      preview pin in place (not stack a second one), and (b) do so WITHOUT polluting
#      undo; aborting an undropped preview must remove it undo-free, so a later undo
#      must NOT resurrect it. (Sabotage: revert abort_operation's delete(0) -> delete(1)
#      and "preview abort: undo keeps it gone" fails; revert -place's self-abort and
#      "preview rearm: still one pin" fails.)
# ---------------------------------------------------------------------------
xschem clear force
set ::pin_new_dir in
set ::pin_new_name VD
xschem add_symbol_pin -place              ;# first arm: ONE undo baseline + preview pin
check "preview arm: one pin"             [xschem get rects 5] 1
set ::pin_new_name VDD
xschem add_symbol_pin -place              ;# re-arm: drop old preview (no undo), new preview
check "preview rearm: still one pin"     [xschem get rects 5] 1
check "preview rearm: name updated"      [xschem getprop rect 5 0 name] VDD
xschem abort_operation                     ;# undropped preview torn down undo-free
check "preview abort: no pin"            [xschem get rects 5] 0
check "preview abort: no view"           [xschem get texts]   0
xschem undo                                ;# the aborted preview must stay gone
check "preview abort: undo keeps it gone" [xschem get rects 5] 0

# ---------------------------------------------------------------------------
# 11c. Desync guard: the modeless form can stay OPEN across a file load / clear / new,
#      which resets ui_state (and frees the preview pin) out from under sympin_preview.
#      clear_drawing must drop the flag so the NEXT arm pushes a FRESH undo baseline; a
#      stale flag would skip the push and the arm's undo would roll back to the WRONG
#      (pre-clear) document. We make the pre-clear state non-empty (load owned.sym, 1 pin)
#      so a lost baseline reveals itself by resurrecting that pin instead of undoing P2.
#      (Sabotage: drop clear_drawing's `sympin_preview = 0` AND revert the -place
#      START_SYMPIN gate -> "desync: undo did not resurrect the cleared pin" sees 1.)
# ---------------------------------------------------------------------------
xschem load $f1                            ;# pre-clear state S0 = a symbol with one pin
check "desync: loaded one pin"           [xschem get rects 5] 1
set ::pin_new_dir in
set ::pin_new_name P1
xschem add_symbol_pin -place              ;# arm: baseline snapshots S0 (the loaded pin)
xschem clear force                         ;# load/new-equivalent: must invalidate the flag
check "desync: doc cleared"              [xschem get rects 5] 0
set ::pin_new_name P2
xschem add_symbol_pin -place              ;# stale flag must NOT skip the fresh (empty) baseline
xschem abort_operation                      ;# remove the undropped preview (undo-free)
check "desync: aborted to empty"         [xschem get rects 5] 0
xschem undo                                ;# fresh baseline = the CLEARED doc, NOT stale S0
check "desync: undo did not resurrect the cleared pin" [xschem get rects 5] 0

# ---------------------------------------------------------------------------
# 12. The name view is OWNED by its pin: deleting the view alone is refused; deleting
#     the pin takes the view with it.
# ---------------------------------------------------------------------------
xschem clear force
xschem add_symbol_pin 0 0 IN in 0
xschem unselect_all
xschem select text 0                  ;# select just the name view
xschem delete
check "del view alone: view kept" [xschem get texts]   1
check "del view alone: pin kept"  [xschem get rects 5] 1
xschem unselect_all
xschem select rect 5 0                ;# select the pin -> cascades to its view
xschem delete
check "del pin: pin gone"         [xschem get rects 5] 0
check "del pin: view gone"        [xschem get texts]   0

# ---------------------------------------------------------------------------
# 13. P4 copy/paste. A pin's name view is a derived object: copying/pasting a pin must
#     REGENERATE the view for the copy (bound to its fresh id), never duplicate the view as
#     a stray real text. (Sabotage: drop the synth_pin_views() in copy_objects/merge_file
#     and "... two views" drops to 1; drop the copy_objects view-skip and a stray T survives
#     the round-trip -> "copy roundtrip: no stray" sees 3.)
# ---------------------------------------------------------------------------
# 13a. In-session copy of a PIN ONLY -> the copy gets its own regenerated view.
xschem clear force symbol
xschem add_symbol_pin 0 0 AA in 0
xschem unselect_all; xschem select rect 5 0
xschem copy_objects 0 40
check "copy pin: two pins"         [xschem get rects 5] 2
check "copy pin: two views"        [xschem get texts]   2
# 13b. Copy PIN+VIEW -> the view is not duplicated as a stray persisted text. Save skips
#      synth views, so a round-trip stays at 2 pins / 2 views (a stray would make it 3).
xschem clear force symbol
xschem add_symbol_pin 0 0 BB in 0
xschem unselect_all; xschem select rect 5 0; xschem select text 0
xschem copy_objects 0 40
check "copy pin+view: two pins"    [xschem get rects 5] 2
check "copy pin+view: two views"   [xschem get texts]   2
set ocp $wd/copied.sym
xschem saveas $ocp symbol
xschem load $ocp
check "copy roundtrip: two pins"   [xschem get rects 5] 2
check "copy roundtrip: no stray"   [xschem get texts]   2
# 13c. Clipboard copy/paste -> the pasted pin gets a regenerated view (clipboard has none).
xschem clear force symbol
xschem add_symbol_pin 0 0 CC in 0
xschem unselect_all; xschem select rect 5 0
xschem copy
xschem paste
check "paste: two pins"            [xschem get rects 5] 2
check "paste: two views"           [xschem get texts]   2
xschem abort_operation               ;# end the merge drag (cleanup)

# ---------------------------------------------------------------------------
# 14. P5 global show/hide tri-state (show_pin_names, §4.8). The global toggle WINS over
#     the per-pin show_pinname: on -> every OWNED pin shows, off -> all hide, auto ->
#     defer to each pin. A LEGACY pin (no show_pinname token) is never revealed by 'on'
#     (its appearance is preserved). Visibility == existence of the synth view, so we
#     count [xschem get texts].
# ---------------------------------------------------------------------------
set fp5 $wd/p5.sym
write_sym $fp5 [join {
  "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_size=0.2}"
  "B 5 -2.5 17.5 2.5 22.5 {name=B dir=in show_pinname=false name_size=0.2}"
  "B 5 -2.5 37.5 2.5 42.5 {name=C dir=in show_pinname=true name_size=0.2}"
  "B 5 -2.5 57.5 2.5 62.5 {name=D dir=in}"
} "\n"]\n
set ::show_pin_names auto
xschem load $fp5
check "p5: 4 pins loaded"           [xschem get rects 5] 4
check "p5 auto: 2 shown (A,C)"      [xschem get texts]   2
# global ON wins: every owned pin (A,B,C) shows; legacy D stays hidden.
check "p5 on: returns on"           [xschem pin_names on]  on
check "p5 on: 3 shown (A,B,C)"      [xschem get texts]   3
check "p5 on: var set"              $::show_pin_names      on
# global OFF wins: all owned pins hide.
check "p5 off: returns off"         [xschem pin_names off] off
check "p5 off: 0 shown"             [xschem get texts]   0
# back to AUTO: per-pin flags decide again (A,C shown; B hidden).
xschem pin_names auto
check "p5 auto again: 2 shown"      [xschem get texts]   2
# query with no arg returns current mode without changing it.
check "p5 query: auto"              [xschem pin_names]     auto
check "p5 query: unchanged"         [xschem get texts]   2
# cycle: auto -> on -> off -> auto.
check "p5 cycle1: on"               [xschem pin_names cycle] on
check "p5 cycle1: 3 shown"          [xschem get texts]   3
check "p5 cycle2: off"              [xschem pin_names cycle] off
check "p5 cycle2: 0 shown"          [xschem get texts]   0
check "p5 cycle3: auto"             [xschem pin_names cycle] auto
check "p5 cycle3: 2 shown"          [xschem get texts]   2
# toggling visibility is display-only: saving still persists the per-pin tokens intact
# and never leaks a view (S3), regardless of the global mode.
xschem pin_names on
set op5 $wd/p5_out.sym
xschem saveas $op5 symbol
check "p5 save: 0 T (no view leak)"        [count_lines $op5 "T *"] 0
check "p5 save: show_pinname=false kept"   [expr {[count_lines $op5 "*show_pinname=false*"] >= 1}] 1

# 14b. (review fix) create_pin honors the global tri-state: a pin ADDED while global=off
#      must not show its name; flipping to auto then reveals it (reconcile creates the view).
xschem clear force symbol
xschem pin_names off
xschem add_symbol_pin 0 0 AA in 0
check "p5 add-under-off: 1 pin"     [xschem get rects 5] 1
check "p5 add-under-off: 0 views"   [xschem get texts]   0
xschem pin_names auto
check "p5 add-under-off->auto: view" [xschem get texts]  1

# 14c. (review fix) hiding while a name view is SELECTED must rebuild the selection, not
#      leave sel_array dangling at a deleted/shifted text slot. After 'off' deletes the
#      selected view, lastsel must drop to 0 (stale-cache bug would leave it at 1).
xschem clear force symbol
xschem pin_names auto
xschem add_symbol_pin 0 0 BB in 0
xschem unselect_all; xschem select text 0
check "p5 selview: 1 selected"      [xschem get lastsel] 1
xschem pin_names off
check "p5 selview: 0 views"         [xschem get texts]   0
check "p5 selview: selection rebuilt" [xschem get lastsel] 0
set ::show_pin_names auto             ;# restore default for any later cases

# ---------------------------------------------------------------------------
# 15. P6 instance display: a PLACED instance renders its symbol's pin names directly from the
#     pin tokens (draw_symbol / svg_draw_symbol), gated by the same tri-state -- no synth view
#     on instances (Way A). Verified via SVG export (text_svg=1 emits <text>NAME</text>): auto
#     shows show_pinname=true pins only, off hides all, on shows every owned pin (global wins
#     over a per-pin show_pinname=false). A LEGACY pin (no token) is never shown.
# ---------------------------------------------------------------------------
set p6sym $wd/p6.sym
write_sym $p6sym [join {
  "L 4 -20 -10 20 50 {}"
  "B 5 -2.5 -2.5 2.5 2.5 {name=INP dir=in show_pinname=true name_dx=8 name_dy=0 name_size=0.4}"
  "B 5 -2.5 17.5 2.5 22.5 {name=HID dir=in show_pinname=false name_size=0.4}"
  "B 5 -2.5 37.5 2.5 42.5 {name=OUTP dir=out show_pinname=true name_dx=-8 name_size=0.4 name_flip=1}"
  "B 5 -2.5 57.5 2.5 62.5 {name=LEG dir=in}"
} "\n"]\n
set p6sch $wd/p6.sch
set fp [open $p6sch w]
foreach ln {"v {xschem version=3.4.8RC file_version=1.3}" "G {}" "K {}" "V {}" "S {}" "E {}"} { puts $fp $ln }
puts $fp "C {$p6sym} 0 0 0 0 {name=x1}"
close $fp
# count <text>PAT</text> occurrences in an SVG (text_svg emits the literal name as content)
proc svgcount {f pat} {
  if {![file exists $f]} { return -1 }
  set fd [open $f r]; set b [read $fd]; close $fd
  return [regexp -all ">$pat<" $b]
}
set ::text_svg 1
xschem load $p6sch
check "p6: instance placed"        [xschem get instances] 1
xschem pin_names auto
xschem print svg $wd/p6_auto.svg 0 0
check "p6 auto: INP shown"         [svgcount $wd/p6_auto.svg INP]  1
check "p6 auto: OUTP shown"        [svgcount $wd/p6_auto.svg OUTP] 1
check "p6 auto: HID hidden"        [svgcount $wd/p6_auto.svg HID]  0
check "p6 auto: LEG (legacy) hidden" [svgcount $wd/p6_auto.svg LEG] 0
xschem pin_names off
xschem print svg $wd/p6_off.svg 0 0
check "p6 off: INP hidden"         [svgcount $wd/p6_off.svg INP]   0
check "p6 off: OUTP hidden"        [svgcount $wd/p6_off.svg OUTP]  0
xschem pin_names on
xschem print svg $wd/p6_on.svg 0 0
check "p6 on: INP shown"           [svgcount $wd/p6_on.svg INP]    1
check "p6 on: OUTP shown"          [svgcount $wd/p6_on.svg OUTP]   1
check "p6 on: HID shown (wins)"    [svgcount $wd/p6_on.svg HID]    1
check "p6 on: LEG still hidden"    [svgcount $wd/p6_on.svg LEG]    0
set ::show_pin_names auto
set ::text_svg 0

# ---------------------------------------------------------------------------
# 16. P7 ERC: `xschem check_pin_names` scans the edited symbol's PINLAYER pins and returns a
#     machine-readable Tcl list of "{type idx {name}}" issue elements (type = dup|nameless|
#     legacy). Non-blocking, display/report only. Sub-tests exercise each check in isolation,
#     a clean symbol (empty result), and a combined symbol (one of each), plus the human
#     ERC-info-window channel. §4.9.
# ---------------------------------------------------------------------------
# count list elements whose first field equals 'type'
proc count_type {lst type} {
  set n 0
  foreach el $lst { if {[lindex $el 0] eq $type} { incr n } }
  return $n
}

# 16a. Duplicate pin names: two un-owned pins both name=A -> exactly one dup issue, no others.
set p7dup $wd/p7_dup.sym
write_sym $p7dup [join {
  "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}"
  "B 5 -2.5 17.5 2.5 22.5 {name=A dir=out}"
} "\n"]\n
xschem load $p7dup
set r [xschem check_pin_names]
check "p7 dup: total issues"       [llength $r]            1
check "p7 dup: one dup element"    [count_type $r dup]     1
check "p7 dup: names/nameless=0"   [count_type $r nameless] 0
check "p7 dup: legacy=0"           [count_type $r legacy]  0
check "p7 dup: issue names later pin (idx 1)" [lindex [lindex $r 0] 1] 1

# 16b. Owned but nameless: show_pinname token present but empty name= -> one nameless issue.
# (An empty value must be written name="" -- xschem's tokenizer reads a bare `name= <tok>`
#  as taking the next token as the value.)
set p7nm $wd/p7_nameless.sym
write_sym $p7nm "B 5 -2.5 -2.5 2.5 2.5 {name=\"\" dir=in show_pinname=true name_size=0.2}\n"
xschem load $p7nm
set r [xschem check_pin_names]
check "p7 nameless: total issues"  [llength $r]            1
check "p7 nameless: one nameless"  [count_type $r nameless] 1
check "p7 nameless: dup=0"         [count_type $r dup]     0
check "p7 nameless: no synth view (nameless pin not shown)" [xschem get texts] 0

# 16c. Legacy adoption gap: an un-owned pin with a literal T {name} label next to it.
set p7leg $wd/p7_legacy.sym
write_sym $p7leg [join {
  "B 5 -2.5 -2.5 2.5 2.5 {name=LEG dir=in}"
  "T {LEG} 22 -5 0 0 0.2 0.2 {}"
} "\n"]\n
xschem load $p7leg
check "p7 legacy: legacy T is a real text (no synth view)" [xschem get texts] 1
set r [xschem check_pin_names]
check "p7 legacy: total issues"    [llength $r]            1
check "p7 legacy: one legacy"      [count_type $r legacy]  1
check "p7 legacy: element name"    [lindex [lindex $r 0] 2] LEG

# 16d. Clean symbol: two distinct owned names, no legacy label -> empty result.
set p7ok $wd/p7_ok.sym
write_sym $p7ok [join {
  "B 5 -2.5 -2.5 2.5 2.5 {name=IN dir=in show_pinname=true name_dx=20 name_size=0.2}"
  "B 5 -2.5 17.5 2.5 22.5 {name=OUT dir=out show_pinname=true name_dx=-20 name_size=0.2 name_flip=1}"
} "\n"]\n
xschem load $p7ok
set r [xschem check_pin_names]
check "p7 clean: no issues"        [llength $r]            0
check "p7 clean: info window text says clean" \
  [expr {[string match "*no issues found*" [xschem get infowindow_text]] ? 1 : 0}] 1

# 16e. Combined: dup (pins 0/1) + nameless (pin 2) + legacy (pin 3, T {LEG} nearby).
set p7all $wd/p7_all.sym
write_sym $p7all [join {
  "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}"
  "B 5 -2.5 17.5 2.5 22.5 {name=A dir=out}"
  "B 5 -2.5 37.5 2.5 42.5 {name=\"\" dir=in show_pinname=true}"
  "B 5 -2.5 57.5 2.5 62.5 {name=LEG dir=in}"
  "T {LEG} 22 55 0 0 0.2 0.2 {}"
} "\n"]\n
xschem load $p7all
set r [xschem check_pin_names]
check "p7 all: total issues"       [llength $r]            3
check "p7 all: one dup"            [count_type $r dup]     1
check "p7 all: one nameless"       [count_type $r nameless] 1
check "p7 all: one legacy"         [count_type $r legacy]  1
check "p7 all: info window lists a warning" \
  [expr {[string match "*Warning:*" [xschem get infowindow_text]] ? 1 : 0}] 1

# ---------------------------------------------------------------------------
# 17. P9 get_pin_name_size getter -- the single source of truth for "a pin's own
#     text size", consumed by the wire-stub / net-label feature
#     (doc/claude/specs/wire_stub_netlabel.md §3.4/§4.2). Exposed for headless
#     coverage as `xschem get pin_name_size <inst> <pin>`: returns pin `pin`'s
#     name_size token, else the global sym_pin_name_size default (fallback 0.2 --
#     the SAME default create_pin stamps, so a legacy pin and a created one agree).
#     Runs in SCHEMATIC mode against a placed instance (Thread B's actual context).
# ---------------------------------------------------------------------------
set p9 $wd/p9_sizes.sym
write_sym $p9 [join {
  "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_dx=20 name_dy=-5 name_size=0.35}"
  "B 5 -2.5 17.5 2.5 22.5 {name=B dir=in show_pinname=true name_dx=20 name_dy=-5 name_size=0.15}"
  "B 5 -2.5 37.5 2.5 42.5 {name=C dir=in}"
} "\n"]\n

# place an instance in a fresh schematic; the getter reads the instance's symbol pins
set save_sz [expr {[info exists ::sym_pin_name_size] ? $::sym_pin_name_size : ""}]
set ::sym_pin_name_size 0.2
xschem clear force
xschem instance $p9 0 0 0 0 {name=x1}
set ip [expr {[xschem get instances]-1}]

check "p9: pin 0 reads its name_size"       [xschem get pin_name_size $ip 0]  0.35
check "p9: pin 1 reads its name_size"       [xschem get pin_name_size $ip 1]  0.15
check "p9: legacy pin -> global default"    [xschem get pin_name_size $ip 2]  0.2
check "p9: out-of-range pin -> default"     [xschem get pin_name_size $ip 99] 0.2
check "p9: negative pin -> default"         [xschem get pin_name_size $ip -1] 0.2

# the fallback tracks the global sym_pin_name_size var (exactly what create_pin stamps);
# an OWNED pin keeps its own token regardless of the global default
set ::sym_pin_name_size 0.27
check "p9: legacy default follows sym_pin_name_size" [xschem get pin_name_size $ip 2] 0.27
check "p9: owned pin ignores global (has token)"     [xschem get pin_name_size $ip 0] 0.35
set ::sym_pin_name_size ""
check "p9: empty global var falls back to 0.2"       [xschem get pin_name_size $ip 2] 0.2
set ::sym_pin_name_size $save_sz

# argument validation: too few args and a bad instance index both error out
check "p9: missing args errors"    [catch {xschem get pin_name_size}]         1
check "p9: bad inst index errors"  [catch {xschem get pin_name_size 99999 0}] 1

# optional <win> context-borrow arg: the query need not be bound to the front window.
# Single-window headless coverage here; the true 2-window cross-borrow (symbol window
# front, schematic addressed by path) is the GUI test tests/headless/test_pin_name_size_win.tcl.
# Passing the CURRENT window's own path borrows-to-current (a no-op) and returns the same
# value; a bogus path errors instead of silently using the front window; and a plain query
# still works afterward with current_win_path unchanged (borrow/restore left it intact).
set cwp [xschem get current_win_path]
check "p9 win: own-path passthrough == plain" \
  [xschem get pin_name_size $ip 0 $cwp] [xschem get pin_name_size $ip 0]
check "p9 win: unknown window errors"          [catch {xschem get pin_name_size $ip 0 .nope.drw}] 1
check "p9 win: front context intact after borrow"     [xschem get pin_name_size $ip 1] 0.15
check "p9 win: current window unchanged after borrow" [xschem get current_win_path]    $cwp

file delete -force $wd

if {$nfail == 0} { puts "ALL PASS (pin_name_text)" } else { puts "$nfail FAILURES (pin_name_text)" }
