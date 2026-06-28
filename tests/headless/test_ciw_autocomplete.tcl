# Integration smoke for CIW Tab autocomplete (src/ciw.tcl ciw_complete + the
# build-generated xschem_subcommands.txt). Spec: doc/claude/specs/ciw_autocomplete.md.
# Run under X with --pipe (the CIW only exists in an interactive/has_x session):
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_ciw_autocomplete.tcl
update idletasks

proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"
  if {!$ok} {incr ::fails}
}
set ::fails 0

# the CIW must have auto-opened (interactive session) or there is nothing to test
if {![winfo exists .ciw.c.e]} {
  puts "FATAL: CIW entry .ciw.c.e does not exist (need an X / interactive session)"
  exit 1
}

# replace the entry contents; the insert cursor lands at end, which is what
# ciw_complete reads as the completion point
proc set_entry {s} {.ciw.c.e delete 1.0 end; .ciw.c.e insert end $s}
proc entry_text {} {string trim [.ciw.c.e get 1.0 end]}

# AC8 -- the binding is wired and ends in 'break' (so Tab does not steal focus)
set tb [bind .ciw.c.e <Tab>]
check "Tab bound on entry"                [expr {$tb ne {}}]
check "Tab binding calls ciw_complete"    [string match *ciw_complete* $tb]
check "Tab binding ends in break"         [string match *break* $tb]

# AC7 -- the generated subcommand list shipped and parses to a non-empty set
ciw_load_subcommands
check "subcommand list non-empty"         [expr {[llength $::ciw_subcommands] > 0}]
check "subcommand list includes 'load'"   [expr {[lsearch -exact $::ciw_subcommands load] >= 0}]

# AC1 -- unique xschem subcommand prefix: insert full name + trailing space
set_entry "xschem add_g"; ciw_complete
check "AC1 unique -> 'xschem add_graph'"  [expr {[entry_text] eq "xschem add_graph"}]
check "AC1 trailing space inserted"       [expr {[.ciw.c.e get 1.0 end-1c] eq "xschem add_graph "}]

# AC2 -- ambiguous prefix advances only to the longest common prefix, no space
set_entry "xschem loa"; ciw_complete
check "AC2 ambiguous -> 'xschem load'"    [expr {[entry_text] eq "xschem load"}]
check "AC2 no trailing space (LCP)"       [expr {[.ciw.c.e get 1.0 end-1c] eq "xschem load"}]

# AC3 -- ambiguous with no progress lists candidates into the log pane
set before [.ciw.l.t get 1.0 end]
set_entry "xschem "; ciw_complete
set after [.ciw.l.t get 1.0 end]
check "AC3 log pane grew (candidates listed)" [expr {[string length $after] > [string length $before]}]
check "AC3 listing mentions a known cmd"  [string match *netlist* $after]
check "AC3 entry unchanged by listing"    [expr {[entry_text] eq "xschem"}]

# AC4 -- no match rings the bell and leaves the entry untouched
set_entry "xschem zzzzzz"; ciw_complete
check "AC4 no-match leaves entry intact"  [expr {[entry_text] eq "xschem zzzzzz"}]

# AC5 -- first token completes against Tcl commands/procs
set_entry "ciw_exe"; ciw_complete
check "AC5 'ciw_exe' -> 'ciw_exec'"       [expr {[entry_text] eq "ciw_exec"}]

# AC6 -- $variable completion, '$' preserved, advances to common prefix
set_entry "puts \$ciw_hi"; ciw_complete
check "AC6 '\$ciw_hi' -> '\$ciw_hist'"    [expr {[entry_text] eq "puts \$ciw_hist"}]

puts "----"
puts "[expr {$::fails ? "FAIL" : "PASS"}]: ciw autocomplete ($::fails failure(s))"
exit [expr {$::fails ? 1 : 0}]
