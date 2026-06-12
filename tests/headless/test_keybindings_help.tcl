# Smoke for the keybindings cheat-sheet (Phase 3d.3): it is now a generated VIEW of the
# live binding table (`xschem bindings dump`), joined with actions.csv for human labels.
# Run with --pipe (needs xctx for the dump):
#   DISPLAY=:0 ./src/xschem --pipe --script tests/headless/test_keybindings_help.tcl
set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

set txt [generate_keybindings_text]

# Header advertises the live source.
check "header names the live binding table" \
  [expr {[string first "Generated live from the binding table" $txt] >= 0}] {}

# A csv-backed migrated key renders <chord> + <label> joined by id.
check "k -> Highlight selected net/pins" \
  [regexp -line {^  k\s+Highlight selected net/pins} $txt] {}
check "Ctrl+k -> Un-highlight selected net/pins" \
  [regexp -line {^  Ctrl\+k\s+Un-highlight selected net/pins} $txt] {}

# idle_only rows are annotated.
check "idle rows annotated (when idle)" [expr {[string first "(when idle)" $txt] >= 0}] {}

# Super (Mod4) renders as a chord (proves d3a + chord rendering).
check "Super+k chord present" [regexp -line {^  Super\+k\s} $txt] {}

# Mouse section: wheel + button, with labels where available.
check "Wheel up -> Zoom In" [regexp -line {^  Wheel up\s+Zoom In} $txt] {}
check "Button 3 row present" [regexp -line {^  Button 3\s} $txt] {}

# graph-routing rows are footnoted, not listed as commands.
check "no graph.forward rows in the sheet" [expr {[string first "graph.forward" $txt] < 0}] {}

# d4a: actions.csv is the single source of truth for EVERY bound id — no row in the
# live table (graph.forward excepted: routing plumbing, footnoted not listed) may
# fall back to a bare id. A failure here means a C-registered id has no csv row.
set bare {}
set labels {}
foreach row $action_table { dict set labels [dict get $row id] 1 }
foreach row [xschem bindings dump] {
  set id [lindex $row 4]
  if {$id eq "graph.forward"} continue
  if {![dict exists $labels $id]} { lappend bare $id }
}
check "every bound id has an actions.csv label" \
  [expr {[llength $bare] == 0}] "(bare: [lsort -unique $bare])"

# spot-check two d4a additions render chord + label
check "Up -> Scroll up" [regexp -line {^  Up\s+Scroll up} $txt] {}
check "B -> Edit Header/License text (id reconciled to the csv id)" \
  [regexp -line {^  B\s+Edit Header/License text} $txt] {}

# the new idle column parses: every action_table row carries the idle key, and the
# 11 idle-bound ids are flagged (spot-check undo).
set has_idle 1
foreach row $action_table { if {![dict exists $row idle]} { set has_idle 0; break } }
check "csv rows expose the idle column" $has_idle {}
foreach row $action_table {
  if {[dict get $row id] eq "edit.undo"} { check "edit.undo idle=1" \
    [expr {[dict get $row idle] eq "1"}] {} }
}

# label-only rows (empty command) are skipped by the palette
set pal_bare 0
foreach row $action_table {
  if {[dict get $row type] ne "command"} continue
  if {[dict get $row command] eq "" && [dict get $row id] eq "view.zoom_rect"} { set pal_bare 1 }
}
check "view.zoom_rect is a label-only row (empty command)" $pal_bare {}
command_palette .
set ::palette_query {}
unset -nocomplain ::palette_last_query
palette_refilter
set in_palette 0
foreach row $::palette_rows { if {[dict get $row id] eq "view.zoom_rect"} { set in_palette 1 } }
destroy .cmd_palette
check "palette skips label-only rows" [expr {!$in_palette}] {}

# The sheet follows the LIVE table: unbind k -> its label disappears; rebind -> returns.
xschem unbind key 107 0 canvas
set txt2 [generate_keybindings_text]
check "sheet follows the table (unbind k drops its row)" \
  [expr {![regexp -line {^  k\s+Highlight selected net/pins} $txt2]}] {}
xschem bind key 107 0 canvas hilight.highlight_selected_net_pins idle
set txt3 [generate_keybindings_text]
check "rebind restores the row (idle)" \
  [regexp -line {^  k\s+Highlight selected net/pins \(when idle\)} $txt3] {}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
