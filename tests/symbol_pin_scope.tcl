#
#  File: symbol_pin_scope.tcl
#
#  Headless regression for SP1 of "Apply to" scope in the SYMBOL editor (multi-pin edit).
#  See doc/claude/specs/symbol_editor_apply_scope.md
#
#  SP1 = the C engine, no UI:
#    - pin_scope_targets(primary_n, scope, targets)  (editprop.c)
#    - xschem apply_pin_prop [<scope>] <prop>         (scope-aware; default 'selected')
#    - xschem pin_scope_prop_uniform <scope> <token>  (drives the Name-greying rule)
#
#  Scope semantics for pins (spec §3):
#    current  -> the primary pin only (sel_array[0])
#    selected -> every selected PINLAYER rect
#    all      -> every PINLAYER rect in the symbol   (no master concept -> all pins)
#
#  Run UNDER xschem, from tests/ :
#      ../src/xschem --nogui --pipe -q --script symbol_pin_scope.tcl
#

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

set wd [file normalize ./symbol_pin_scope_work]
file delete -force $wd
file mkdir $wd

proc write_sym {path body} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
  puts $fp "G {}"
  puts $fp "K {type=subcircuit}"
  puts $fp "V {}"
  puts $fp "S {}"
  puts $fp "E {}"
  puts -nonewline $fp $body
  close $fp
}

# 3-pin symbol: A(in) B(out) C(inout), all show_pinname=true. Loaded as
# rect[5][0]=A, rect[5][1]=B, rect[5][2]=C (file order).
set sym $wd/pins3.sym
write_sym $sym \
"B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_dx=20 name_dy=-5 name_size=0.2}
B 5 -2.5 17.5 2.5 22.5 {name=B dir=out show_pinname=true name_dx=-25 name_dy=-5 name_size=0.2 name_flip=1}
B 5 -2.5 37.5 2.5 42.5 {name=C dir=inout show_pinname=true name_dx=-25 name_dy=-5 name_size=0.2 name_flip=1}
"

# primary=A's prop with ONLY show_pinname flipped to false: set_different_token vs A's
# baseline changes exactly that token -> fans to the scope, name/dir untouched.
set showoff "name=A dir=in show_pinname=false name_dx=20 name_dy=-5 name_size=0.2"
# primary=A's prop with ONLY dir flipped: exercises the per-target pin_reorient hook.
set dirout  "name=A dir=out show_pinname=true name_dx=20 name_dy=-5 name_size=0.2"

proc selAB {} { xschem unselect_all; xschem select rect 5 0; xschem select rect 5 1 }
proc showv {n} { xschem getprop rect 5 $n show_pinname }
proc dirv  {n} { xschem getprop rect 5 $n dir }
# catch-wrap so the new command's absence reports FAIL instead of aborting the script (RED)
proc uni {scope tok} { if {[catch {xschem pin_scope_prop_uniform $scope $tok} r]} { return ERR } ; return $r }

# ---------------------------------------------------------------------------
# 1. scope=current -> only the primary pin (A) changes
# ---------------------------------------------------------------------------
xschem load $sym ; selAB
check "current: apply reports change"  [xschem apply_pin_prop current $showoff] 1
check "current: A hidden"              [showv 0] false
check "current: B untouched"           [showv 1] true
check "current: C untouched"           [showv 2] true

# ---------------------------------------------------------------------------
# 2. scope=selected -> both selected pins (A,B), not the unselected C
# ---------------------------------------------------------------------------
xschem load $sym ; selAB
check "selected: apply reports change" [xschem apply_pin_prop selected $showoff] 1
check "selected: A hidden"             [showv 0] false
check "selected: B hidden"             [showv 1] false
check "selected: C untouched"          [showv 2] true
check "selected: B name NOT fanned"    [xschem getprop rect 5 1 name] B

# ---------------------------------------------------------------------------
# 3. scope=all -> every pin of the symbol, incl the unselected C
# ---------------------------------------------------------------------------
xschem load $sym ; selAB
check "all: apply reports change"      [xschem apply_pin_prop all $showoff] 1
check "all: A hidden"                  [showv 0] false
check "all: B hidden"                  [showv 1] false
check "all: C hidden (unselected)"     [showv 2] false

# ---------------------------------------------------------------------------
# 4. back-compat: no scope arg -> defaults to 'selected'
# ---------------------------------------------------------------------------
xschem load $sym ; selAB
check "noscope: apply reports change"  [xschem apply_pin_prop $showoff] 1
check "noscope: A hidden"              [showv 0] false
check "noscope: C untouched"           [showv 2] true

# ---------------------------------------------------------------------------
# 5. pin_scope_prop_uniform -> the Name-greying decision (spec §4.2/§5.3)
# ---------------------------------------------------------------------------
xschem load $sym ; selAB
check "uniform: names A,B differ -> 0"     [uni selected name] 0
check "uniform: show all true -> 1"        [uni selected show_pinname] 1
check "uniform: all dirs differ -> 0"      [uni all dir] 0
xschem load $sym ; xschem unselect_all ; xschem select rect 5 0
check "uniform: single selected name -> 1" [uni selected name] 1
check "uniform: current single -> 1"       [uni current name] 1

# ---------------------------------------------------------------------------
# 6. dir change fans + fires per-target pin_reorient (in -> out sets name_flip=1)
# ---------------------------------------------------------------------------
xschem load $sym ; selAB
check "dir: apply reports change"      [xschem apply_pin_prop selected $dirout] 1
check "dir: A dir=out"                 [dirv 0] out
check "dir: B dir=out"                 [dirv 1] out
check "dir: A reoriented name_flip=1"  [xschem getprop rect 5 0 name_flip] 1

puts "===================="
if {$nfail == 0} { puts "symbol_pin_scope: ALL PASS" } else { puts "symbol_pin_scope: $nfail FAIL" ; exit 1 }
