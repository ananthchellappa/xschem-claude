#
#  File: symbol_pin_scope_hilight.tcl
#
#  SP3 of "Apply to" scope in the SYMBOL editor: the apply-set highlight overlay for pins.
#  See doc/claude/specs/symbol_editor_apply_scope.md §4.4/§5.4
#
#  `xschem highlight_pin_scope <scope>` outlines exactly the pins an Apply with that scope
#  would touch, via the SHARED pin_scope_resolve() -> outlined set == applied set. Reuses the
#  generic scope_hi_* overlay (draw_scope_highlight xRECT case) + stable xRect.id.
#
#  Run:  cd tests ; ../src/xschem --nogui --pipe -q --script symbol_pin_scope_hilight.tcl
#

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

set wd [file normalize ./symbol_pin_scope_hilight_work]
file delete -force $wd ; file mkdir $wd
proc write_sym {path body} {
  set fp [open $path w]
  foreach h {{v {xschem version=3.4.8RC file_version=1.3}} {G {}} {K {type=subcircuit}} {V {}} {S {}} {E {}}} { puts $fp $h }
  puts -nonewline $fp $body ; close $fp
}
set sym $wd/pins3.sym
write_sym $sym \
"B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_size=0.2}
B 5 -2.5 17.5 2.5 22.5 {name=B dir=out show_pinname=true name_size=0.2}
B 5 -2.5 37.5 2.5 42.5 {name=C dir=inout show_pinname=true name_size=0.2}
"
proc selAB {} { xschem unselect_all; xschem select rect 5 0; xschem select rect 5 1 }
# stable ids of the currently selected PINLAYER rects, from `xschem selection` ({rect n col id})
proc sel_pin_ids {} {
  set ids {}
  foreach row [xschem selection] { if {[lindex $row 0] eq "rect" && [lindex $row 2]==5} { lappend ids [lindex $row 3] } }
  return $ids
}

# ---------------------------------------------------------------------------
# 1. overlay count tracks the scope's target set
# ---------------------------------------------------------------------------
xschem load $sym ; selAB
check "count: current -> 1"   [llength [xschem highlight_pin_scope current]]  1
check "count: selected -> 2"  [llength [xschem highlight_pin_scope selected]] 2
check "count: all -> 3"       [llength [xschem highlight_pin_scope all]]      3

# ---------------------------------------------------------------------------
# 2. outlined set == applied set (same resolver): overlay ids == the in-scope pin ids
# ---------------------------------------------------------------------------
xschem load $sym ; selAB
set selids [sel_pin_ids]
check "outlined==applied: selected ids" [lsort [xschem highlight_pin_scope selected]] [lsort $selids]
check "outlined==applied: current = primary" [xschem highlight_pin_scope current] [lindex $selids 0]

# ---------------------------------------------------------------------------
# 3. overlay-state subcommands: count / ids / clear
# ---------------------------------------------------------------------------
xschem load $sym ; selAB
xschem highlight_pin_scope selected
check "state: count subcmd"   [xschem highlight_pin_scope]      2
check "state: ids subcmd"     [lsort [xschem highlight_pin_scope ids]] [lsort [sel_pin_ids]]
xschem redraw
check "state: survives redraw" [xschem highlight_pin_scope] 2
xschem highlight_pin_scope clear
check "clear: empties overlay" [xschem highlight_pin_scope] 0

# ---------------------------------------------------------------------------
# 4. 'all' outlines every pin even with nothing selected (scripted, no primary)
# ---------------------------------------------------------------------------
xschem load $sym ; xschem unselect_all
check "no-selection all: count 3" [llength [xschem highlight_pin_scope all]] 3
xschem highlight_pin_scope clear

puts "===================="
if {$nfail == 0} { puts "symbol_pin_scope_hilight: ALL PASS" } else { puts "symbol_pin_scope_hilight: $nfail FAIL" ; exit 1 }
