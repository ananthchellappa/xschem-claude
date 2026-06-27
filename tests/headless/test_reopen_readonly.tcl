# Reopen shortcuts (Open Most Recent / Open Last Closed / Recent menu) open a file in READ mode, while
# File > Open stays editable. Mechanism: a `-readonly` flag on `xschem load` forces xctx->readonly=1
# after the load (a writable file would otherwise open editable); the reopen entry points pass it,
# File > Open does not. Edit anytime with Ctrl-2 / View > Toggle Read Only (like descend_readonly).
#
# Headless:  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_reopen_readonly.tcl
# (cwd = repo root, so the wiring checks read src/actions.csv and src/xschem.tcl)

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }

# ---- (1) core: `xschem load -readonly` forces read mode; plain load of a writable file is editable ----
set dir [file join [pwd] _ro_[pid]] ; file delete -force $dir ; file mkdir $dir
set f [file join $dir cell.sch]
# a real, WRITABLE schematic (copy a library cell so load_schematic has valid content)
set src [lindex [glob -nocomplain [file join [pwd] xschem_library devices *.sym]] 0]
set lib [lindex [glob -nocomplain [file join [pwd] xschem_library *.sch]] 0]
if {$lib eq {}} { set lib [lindex [glob -nocomplain [file join [pwd] xschem_library * *.sch]] 0] }
file copy -force $lib $f
file attributes $f -permissions 0644

xschem load $f
check "R1 plain load of a writable file opens EDITABLE" [expr {[xschem get readonly] == 0}] "(ro=[xschem get readonly])"

xschem load -readonly $f
check "R2 load -readonly opens READ mode" [expr {[xschem get readonly] == 1}] "(ro=[xschem get readonly])"

# the flag does not stick: a subsequent plain load is editable again
xschem load $f
check "R3 plain load after -readonly is editable again" [expr {[xschem get readonly] == 0}] "(ro=[xschem get readonly])"

# ---- (1b) the ACTUAL bug: the keyboard Ctrl+Shift+O runs `xschem load -gui -lastopened` directly
# (the actions.csv accel is display-only), so -lastopened/-lastclosed must THEMSELVES imply read mode.
set fa [file join $dir a.sch] ; set fb [file join $dir b.sch]
file copy -force $lib $fa ; file copy -force $lib $fb
file attributes $fa -permissions 0644 ; file attributes $fb -permissions 0644
xschem load $fa            ;# fa becomes recent, then we move off it so it is the "last opened" not-loaded
xschem load $fb
check "R8 plain load of fb is editable" [expr {[xschem get readonly] == 0}] "(ro=[xschem get readonly])"
set got [xschem load -lastopened]   ;# == the keyboard reopen path, WITHOUT an explicit -readonly
check "R9 -lastopened (keyboard reopen) implies READ mode" [expr {[xschem get readonly] == 1}] "(ro=[xschem get readonly])"
check "R10 -lastopened resolved to the prior file (fa)" [expr {[file tail $got] eq {a.sch}}] "(=> $got)"

# ---- (2) wiring: the reopen shortcuts carry -readonly; File > Open (file_chooser_place) does not ----
proc slurp {p} { set fd [open $p r] ; set s [read $fd] ; close $fd ; return $s }
set csv [slurp [file join [pwd] src actions.csv]]
set tcl [slurp [file join [pwd] src xschem.tcl]]

set most [lsearch -inline [split $csv \n] *open_most_recent*]
set last [lsearch -inline [split $csv \n] *open_last_closed*]
check "R4 open_most_recent (Ctrl+Shift+O) passes -readonly" [string match {*-lastopened -readonly*} $most] "(=> $most)"
check "R5 open_last_closed (Ctrl+Shift+T) passes -readonly" [string match {*-lastclosed -readonly*} $last] "(=> $last)"

# the Recent-files menu entries load read-only too
check "R6 recent menu (setup_recent_menu) passes -readonly" \
  [regexp {xschem load -gui -readonly \{\$i\}} $tcl] {}

# File > Open New File (file_chooser_place) must stay EDITABLE (no -readonly on that load)
check "R7 File>Open stays editable (no -readonly in file_chooser_place)" \
  [regexp {xschem load -gui \$f\n} $tcl] {}

file delete -force $dir
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
