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

# A C-registered id not yet in actions.csv falls back to showing the id (folded in at d4).
check "C-only id falls back to its id (view.scroll_up)" \
  [expr {[string first "view.scroll_up" $txt] >= 0}] {}

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
