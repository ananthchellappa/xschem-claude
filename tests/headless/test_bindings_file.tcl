# Phase 3d.4b: keybindings.csv / mousebindings.csv are replayed through
# `xschem bind`/`xschem unbind` at startup, so editing a file remaps or un-binds
# any default chord without recompiling. Proves: (1) the shipped share-dir files
# are a faithful generation of the built-in C table (drift guard), (2) re-loading
# them is a no-op, (3) a fixture file remaps + un-binds and LIVE key behavior
# follows, (4) a malformed row warns but doesn't abort the load.
# Run under X with --pipe:
#   ./src/xschem --pipe --script tests/headless/test_bindings_file.tcl
update idletasks
focus -force .drw

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc keyat {ks} { xschem callback .drw 2 100 100 $ks 0 0 0; update idletasks }
proc slurp {path} { set fp [open $path r]; set d [read $fp]; close $fp; return $d }

set baseline [lsort [xschem bindings dump]]

# --- 1) the committed share files == a fresh generation from the live table.
#        A diff here means the C builtins changed without regenerating the files:
#        re-run save_input_bindings_file (see action_registry.tcl) and commit. ---
set tmpdir [file join [file dirname [info script]] results]
file mkdir $tmpdir
save_input_bindings_file $tmpdir/kb_fresh.csv {key}
save_input_bindings_file $tmpdir/mb_fresh.csv {wheel button}
check "shipped keybindings.csv matches the builtin table" \
  [expr {[slurp $XSCHEM_SHAREDIR/keybindings.csv] eq [slurp $tmpdir/kb_fresh.csv]}] {}
check "shipped mousebindings.csv matches the builtin table" \
  [expr {[slurp $XSCHEM_SHAREDIR/mousebindings.csv] eq [slurp $tmpdir/mb_fresh.csv]}] {}

# --- 2) re-loading the defaults is a no-op (they mirror the builtins) ---
set napplied [load_input_bindings]
check "defaults re-load applies rows" [expr {$napplied > 0}] "(applied $napplied)"
check "defaults re-load is a no-op" \
  [expr {[lsort [xschem bindings dump]] eq $baseline}] {}

# --- 3) fixture file: remap + un-bind, live behavior follows ---
# key 96 (backtick, unbound by default — the d1b safe probe) -> toggle_stretch,
# idle-gated; y (edit.toggle_stretch by default, its switch case is deleted) -> '-'.
set fx $tmpdir/kb_fixture.csv
set fp [open $fx w]
puts $fp "device,code,mods,ctx,action,idle"
puts $fp "key,96,0,canvas,edit.toggle_stretch,1"
puts $fp "key,121,0,canvas,-,"
close $fp

# precondition: default y flips enable_stretch (so the un-bind below is observable)
set s0 $enable_stretch
keyat 121
check "precondition: default y flips enable_stretch" \
  [expr {$enable_stretch != $s0}] "($s0 -> $enable_stretch)"

set n [load_input_bindings_file $fx]
check "fixture applies both rows" [expr {$n == 2}] "(applied $n)"
set dump [xschem bindings dump]
check "fixture row bound (backtick -> toggle_stretch, idle)" \
  [expr {[lsearch -exact $dump {key 96 0 canvas edit.toggle_stretch idle}] >= 0}] {}
check "fixture un-bound y (no canvas row left)" \
  [expr {[lsearch -glob $dump {key 121 0 canvas *}] < 0}] {}

# live behavior: backtick now toggles, y is inert
set s1 $enable_stretch
keyat 96
check "live: backtick flips enable_stretch (file-bound chord)" \
  [expr {$enable_stretch != $s1}] "($s1 -> $enable_stretch)"
set s2 $enable_stretch
keyat 121
check "live: y is inert after file un-bind" \
  [expr {$enable_stretch == $s2}] "($s2 -> $enable_stretch)"

# --- 4) a malformed row warns but the rest of the file still applies ---
set bad $tmpdir/kb_bad.csv
set fp [open $bad w]
puts $fp "device,code,mods,ctx,action,idle"
puts $fp "key,96,0,canvas,no.such.action,"
puts $fp "gamepad,1,0,canvas,view.zoom_full,"
puts $fp "key,96,0,canvas,view.zoom_full,"
close $fp
set n [load_input_bindings_file $bad]
check "bad rows skipped, good row applied" [expr {$n == 1}] "(applied $n)"
check "good row took effect" \
  [expr {[lsearch -exact [xschem bindings dump] {key 96 0 canvas view.zoom_full}] >= 0}] {}

# --- restore the defaults and prove we're back to the baseline ---
xschem unbind key 96 0 canvas
xschem bind key 121 0 canvas edit.toggle_stretch
set enable_stretch $s0
check "table restored to baseline" \
  [expr {[lsort [xschem bindings dump]] eq $baseline}] {}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
