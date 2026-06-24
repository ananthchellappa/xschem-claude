# test_crlf.tcl
set src_csv "../../src/actions.csv"
set test_dir "/tmp/xschem_test_crlf"
file mkdir $test_dir
set f_in [open $src_csv r]
set f_out [open "$test_dir/actions.csv" w]
fconfigure $f_out -translation crlf
puts -nonewline $f_out [read $f_in]
close $f_in
close $f_out

set ::XSCHEM_SHAREDIR $test_dir
source "../../src/action_registry.tcl"
load_action_table
set fail 0
foreach row $::action_table {
  set help [dict get $row help]
  if {[string index $help end] eq "\r"} {
    puts "FAIL: row [dict get $row id] has trailing \\r in help field"
    incr fail
  }
}

if {$fail == 0} {
  puts "PASS: test_crlf.tcl"
  exit 0
} else {
  exit 1
}
