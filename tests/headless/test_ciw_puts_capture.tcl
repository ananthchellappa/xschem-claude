# Integration smoke for CIW puts-capture (src/ciw.tcl ciw_capture_puts + ciw_exec scoping).
# Spec: doc/claude/specs/ciw_puts_capture.md. Run under X with --pipe (the CIW only exists with has_x):
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --preinit "set XSCHEM_SHAREDIR [pwd]/src" \
#       --script tests/headless/test_ciw_puts_capture.tcl
update idletasks

proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"
  if {!$ok} {incr ::fails}
}
set ::fails 0

if {![winfo exists .ciw.c.e]} {
  puts "FATAL: CIW entry .ciw.c.e does not exist (need an X / interactive session)"
  exit 1
}

# run a command exactly as if typed + Enter
proc run_cmd {s} {.ciw.c.e delete 1.0 end; .ciw.c.e insert end $s; ciw_exec}
proc clear_log {} {.ciw.l.t configure -state normal; .ciw.l.t delete 1.0 end; .ciw.l.t configure -state disabled}
proc log_lines {} {return [split [string trimright [.ciw.l.t get 1.0 end] \n] \n]}
proc count_line {s} {return [llength [lsearch -all -exact [log_lines] $s]]}
proc log_text {} {return [.ciw.l.t get 1.0 end]}

# PC1 -- puts STRING -> stdout -> log pane, exactly once (no double echo from the result path)
clear_log; run_cmd "puts hello"
check "PC1 'puts hello' shows 'hello'"        [expr {[count_line hello] == 1}]

# PC2 -- explicit stdout channel
clear_log; run_cmd "puts stdout world"
check "PC2 'puts stdout world' shows 'world'" [expr {[count_line world] == 1}]

# PC3 -- stderr -> log pane, carrying the red 'error' tag. NB: the echoed command line
# "> puts stderr oops" also contains 'oops' (tag 'input'); locate the STANDALONE captured line
# (whole line == "oops") and check ITS tag, not the first substring match.
clear_log; run_cmd "puts stderr oops"
set li [lsearch -exact [log_lines] oops]
set idx "[expr {$li + 1}].0"
check "PC3 'puts stderr oops' shows 'oops'"   [expr {$li >= 0}]
check "PC3 'oops' carries the error tag"      [expr {$li >= 0 && [lsearch -exact [.ciw.l.t tag names $idx] error] >= 0}]

# PC4 -- -nonewline accepted + ignored (line still appears)
clear_log; run_cmd "puts -nonewline nonl"
check "PC4 '-nonewline' still shows 'nonl'"   [expr {[count_line nonl] == 1}]

# PC5 -- a real (file) channel is delegated to the real puts, NOT captured
set tmp "/tmp/ciw_pc_[pid].txt"
catch {file delete $tmp}
clear_log
run_cmd "set ch \[open $tmp w]; puts \$ch filedata; close \$ch"
set ondisk {}
if {![catch {open $tmp r} fh]} {set ondisk [string trim [read $fh]]; close $fh}
check "PC5 file channel write reached the file" [expr {$ondisk eq "filedata"}]
# NB: the echoed command line contains the literal word 'filedata'; the test is that it was NOT
# captured as its OWN log line (which is what a wrongly-hijacked file-channel puts would produce).
check "PC5 file write NOT echoed to the CIW"     [expr {[count_line filedata] == 0}]
catch {file delete $tmp}

# PC6 -- capture is fully torn down after the command (scoped, not global)
check "PC6 ::ciw_saved_puts gone after exec"  [expr {[llength [info commands ::ciw_saved_puts]] == 0}]
check "PC6 ::puts is the real (C) command"    [expr {[catch {info body ::puts}] == 1}]

# PC7 -- puts still returns "" so the result-echo path adds nothing extra (covered by PC1 count==1)
clear_log; run_cmd "puts again"
check "PC7 no double echo ('again' once)"     [expr {[count_line again] == 1}]

puts "----"
puts "[expr {$::fails ? "FAIL" : "PASS"}]: ciw puts-capture ($::fails failure(s))"
exit [expr {$::fails ? 1 : 0}]
