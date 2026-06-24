source "../../src/action_registry.tcl"

set line "a,b,\"c,d\",e,\"f\"\"g\",h"
set fields [action_parse_csv_line $line]
set expected [list "a" "b" "c,d" "e" "f\"g" "h"]

if {$fields ne $expected} {
  puts "FAIL: expected {$expected}, got {$fields}"
  exit 1
}

# Add a test for multiple keys (e.g. accelerators with commas)
set line2 "id,type,menu,label,accel,command,submenu,hook,help"
set line3 "tools.insert_symbol,command,tools,Insert symbol,\"Ins, Shift-I\",xschem place_symbol,,,Insert symbol"

set fields3 [action_parse_csv_line $line3]
set expected3 [list "tools.insert_symbol" "command" "tools" "Insert symbol" "Ins, Shift-I" "xschem place_symbol" "" "" "Insert symbol"]

if {$fields3 ne $expected3} {
  puts "FAIL: expected {$expected3}, got {$fields3}"
  exit 1
}

puts "PASS: test_csv_parser.tcl"
exit 0
