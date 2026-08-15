# Phase 3d.5a: the Phase-2 Tk keyboard intercept is RETIRED — no key has a Tk
# key-detail binding any more, so every chord reaches the generic <KeyPress> ->
# C handle_key_press -> input-binding-table dispatch. This smoke proves:
#   (1) the four ex-intercepted sequences (u, Shift+U, Shift+Z, Ctrl+z) have NO
#       Tk binding (a key-detail bind would pre-empt the generic path),
#   (2) the same physical chords still produce the same effects, now via the C
#       table (zoom in/out ratios, wire undo/redo),
#   (3) u regained the idle gate the Tk path used to bypass: at semaphore>=2 the
#       GUI key no longer undoes (the old C switch did nothing while busy).
# Run under X with --pipe:
#   ./src/xschem --pipe --script tests/headless/test_accelerators.tcl
update idletasks
focus -force .drw
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# 1) the ex-intercepted chords have no Tk shadow; the C table has their rows
foreach seq {<Key-u> <Shift-Key-U> <Shift-Key-Z> <Control-Key-z>} {
  check "no Tk binding for $seq" [expr {[bind .drw $seq] eq {}}] {}
}
set dump [xschem bindings dump]
check "Z -> view.zoom_in row" \
  [expr {[lsearch -exact $dump {key 90 0 canvas view.zoom_in}] >= 0}] {}
check "Ctrl+z -> view.zoom_out row" \
  [expr {[lsearch -exact $dump {key 122 ctrl canvas view.zoom_out}] >= 0}] {}

# view_zoom/view_unzoom multiply 'zoom' by a constant factor per call, so the
# key press and the direct command must apply the SAME ratio.
proc approx_eq {a b} { return [expr {abs($a - $b) < 1e-9 * (abs($a) + 1)}] }

# 2) zoom in: physical Shift+Z -> generic <KeyPress> -> C dispatch -> view.zoom_in
set z0 [xschem get zoom]
event generate .drw <Shift-Key-Z> ; update idletasks ; set z1 [xschem get zoom]
xschem zoom_in ; set z2 [xschem get zoom]
set r_key [expr {$z1 / $z0}]
set r_cmd [expr {$z2 / $z1}]
check "zoom_in key effect (via C table)" \
  [expr {$r_key < 1.0 && [approx_eq $r_key $r_cmd]}] "(ratio key=$r_key cmd=$r_cmd)"

# 3) zoom out
set zo0 [xschem get zoom]
event generate .drw <Control-Key-z> ; update idletasks ; set zo1 [xschem get zoom]
xschem zoom_out ; set zo2 [xschem get zoom]
set ro_key [expr {$zo1 / $zo0}]
set ro_cmd [expr {$zo2 / $zo1}]
check "zoom_out key effect (via C table)" \
  [expr {$ro_key > 1.0 && [approx_eq $ro_key $ro_cmd]}] "(ratio key=$ro_key cmd=$ro_cmd)"

# 4) undo / redo: create a wire, then drive undo+redo from the keyboard
set n0 [xschem get wires]
xschem wire 0 0 1000 0
set n1 [xschem get wires]
check "wire added" [expr {$n1 == $n0 + 1}] "(n0=$n0 n1=$n1)"
event generate .drw <Key-u> ; update idletasks   ;# undo
set n_undo [xschem get wires]
check "undo key removes wire" [expr {$n_undo == $n0}] "(=> $n_undo)"
event generate .drw <Shift-Key-U> ; update idletasks ;# redo
set n_redo [xschem get wires]
check "redo key restores wire" [expr {$n_redo == $n1}] "(=> $n_redo)"

# 5) the idle gate now applies to the GUI key (the Tk intercept bypassed it):
#    while busy (semaphore>=2) u must NOT undo; back at 0 it must again.
xschem set semaphore 2
event generate .drw <Key-u> ; update idletasks
check "busy: u skipped (idle gate)" [expr {[xschem get wires] == $n1}] \
  "(wires [xschem get wires])"
xschem set semaphore 0
event generate .drw <Key-u> ; update idletasks
check "idle again: u undoes" [expr {[xschem get wires] == $n0}] \
  "(wires [xschem get wires])"
event generate .drw <Shift-Key-U> ; update idletasks ;# leave the wire restored
xschem undo ; xschem redraw                          ;# ...then drop it for real
check "fixture restored" [expr {[xschem get wires] == $n0}] {}

# 6) keys never intercepted must still have no Tcl bind (reach the C dispatcher)
foreach k {f s w} {
  check "<Key-$k> reaches C dispatcher (no Tcl bind)" [expr {[bind .drw <Key-$k>] eq {}}] {}
}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
