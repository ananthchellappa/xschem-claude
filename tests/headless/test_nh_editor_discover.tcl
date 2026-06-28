# Net highlight style editor — discoverability (plan slice 2): the command-palette row, the
# first-launch emphasis decision (pure proc), and (under X) the Tools-menu item + stub launcher +
# the palette actually coloring the row. Headless checks run everywhere; GUI checks run only when
# Tk is present.
#   --nogui: ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_nh_editor_discover.tcl
#   GUI:     DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_discover.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
set id tools.net_hilight_style_editor

# --- headless: the action-table row exists and is well-formed -----------------
proc row_by_id {id} {
  global action_table
  foreach r $action_table { if {[dict get $r id] eq $id} { return $r } }
  return {}
}
set row [row_by_id $id]
check "D1a palette/action row present" [expr {$row ne {}}] "(=> [expr {$row ne {} ? {found} : {MISSING}}])"
if {$row ne {}} {
  check "D1b row type=command"            [expr {[dict get $row type] eq {command}}] "(=> [dict get $row type])"
  check "D1c row command = launcher"      [expr {[dict get $row command] eq {net_hilight_style_editor}}] "(=> [dict get $row command])"
  check "D1d row in tools menu"           [expr {[dict get $row menu] eq {tools}}] "(=> [dict get $row menu])"
  check "D1e row has help text"           [expr {[string length [dict get $row help]] > 0}] "(=> [dict get $row help])"
}

# --- headless: the pure first-launch emphasis decision ------------------------
check "D2a palette_emphasis_index proc exists" [expr {[llength [info procs palette_emphasis_index]] == 1}] {}
set rows {}
foreach x {file.open tools.net_hilight_style_editor view.zoom_in} { lappend rows [dict create id $x] }
check "D2b seen=0 -> emphasize editor row (index 1)" [expr {[palette_emphasis_index $rows 0] == 1}] "(=> [palette_emphasis_index $rows 0])"
check "D2c seen=1 -> no emphasis (-1)"               [expr {[palette_emphasis_index $rows 1] == -1}] "(=> [palette_emphasis_index $rows 1])"
set rows2 {}
foreach x {file.open view.zoom_in} { lappend rows2 [dict create id $x] }
check "D2d editor row absent -> -1"                 [expr {[palette_emphasis_index $rows2 0] == -1}] "(=> [palette_emphasis_index $rows2 0])"

# --- GUI-only checks (Tk present) ---------------------------------------------
if {![catch {winfo exists .}]} {
  set ::USER_CONF_DIR [file join [pwd] _nhediscover_[pid]]
  file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

  # stub launcher: opens .nhse, flips seen, writes the marker
  set ::net_hilight_editor_seen 0
  catch {net_hilight_style_editor}
  update idletasks
  check "D3a stub opens .nhse window" [winfo exists .nhse] "(=> [winfo exists .nhse])"
  check "D3b stub sets seen=1"        [expr {$::net_hilight_editor_seen == 1}] "(=> $::net_hilight_editor_seen)"
  check "D3c stub wrote the marker"   [file exists $::USER_CONF_DIR/net_hilight_editor_seen] {}
  catch {destroy .nhse}

  # Tools menu carries the item
  set tm .menubar.tools
  set found 0
  if {[winfo exists $tm]} {
    for {set i 0} {$i <= [$tm index end]} {incr i} {
      if {![catch {$tm entrycget $i -label} lbl] && [string match -nocase {*highlight styles*} $lbl]} { set found 1 }
    }
  }
  check "D4 Tools menu has the editor item" [expr {$found == 1}] "(=> $found)"

  # palette_refilter colors the editor row when seen=0
  set ::net_hilight_editor_seen 0
  command_palette .
  set ::palette_query {}
  unset -nocomplain ::palette_last_query
  palette_refilter
  update idletasks
  set ei [palette_emphasis_index $::palette_rows 0]
  set fg [expr {$ei >= 0 ? [.cmd_palette.l itemcget $ei -foreground] : {}}]
  check "D5 palette colors the editor row (seen=0)" [expr {$ei >= 0 && $fg ne {}}] "(ei=$ei fg=$fg)"
  catch {destroy .cmd_palette}

  file delete -force $::USER_CONF_DIR
} else {
  puts "note: Tk absent (--nogui) -> skipped GUI checks D3/D4/D5"
}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
