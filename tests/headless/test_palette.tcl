# Integration smoke for the command palette. Run under X with --pipe:
#   ./src/xschem --pipe --script tests/headless/test_palette.tcl
update idletasks

# 1) the Ctrl+Shift+P binding is installed on the drawing canvas
set b [bind .drw <Control-Shift-Key-P>]
puts "BINDING: [expr {$b ne {} ? {present} : {MISSING}}]"

# 2) fuzzy filtering over the table
command_palette .
set ::palette_query save
palette_refilter
puts "QUERY 'save' -> [llength $::palette_rows] results"
foreach row [lrange $::palette_rows 0 4] { puts "  hit: [dict get $row label]" }
set ::palette_query {}
unset -nocomplain ::palette_last_query
palette_refilter
puts "QUERY '' -> [llength $::palette_rows] results (all commands)"
destroy .cmd_palette

# 3) the keybinding actually opens the palette (KeyPress delivery needs focus)
focus -force .drw
update idletasks
event generate .drw <Control-Shift-Key-P>
update idletasks
puts "EVENT opens palette: [expr {[winfo exists .cmd_palette] ? {yes} : {NO}}]"
catch {destroy .cmd_palette}

flush stdout
exit 0
