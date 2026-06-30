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
# 10. Pin property form schema + dispatch (headless Tcl; the dialog is GUI-manual).
# ---------------------------------------------------------------------------
set sch [slickprop::gfx_schema pin]
set toks {}
foreach row $sch { lappend toks [dict get $row tok] }
check "pin form fields"        $toks {name dir show_pinname name_size}
check "pin dir is a dropdown"  [dict get [lindex $sch 1] widget] enum
check "pin dir choices"        [dict keys [dict get [lindex $sch 1] choices]] {in out inout}
check "pin name is single-line" [dict get [lindex $sch 0] widget] string
# a selected PINLAYER (layer 5) rect routes to the pin form, not the generic rect form
xschem clear force
xschem add_symbol_pin 0 0 IN in 0
xschem unselect_all
xschem select rect 5 0
check "selected_type = pin"    [gfxform::selected_type] pin

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

file delete -force $wd

if {$nfail == 0} { puts "ALL PASS (pin_name_text)" } else { puts "$nfail FAILURES (pin_name_text)" }
