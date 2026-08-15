#
#  File: symbol_pin_scope_form.tcl
#
#  SP2 of "Apply to" scope in the SYMBOL editor: the pin form's scope selector + Name-greying.
#  See doc/claude/specs/symbol_editor_apply_scope.md
#
#  SP2 is Tcl (gfxform in xschem.tcl). Logic is tested through headless seams (deterministic):
#    - scope_label_for / scope_value_for  (label<->canonical mapping)
#    - name_editable <scope>              (the Name-greying DECISION; 1=editable 0=grey)
#    - do_apply <prop>                    (routes the pin scope to apply_pin_prop)
#  A DISPLAY-gated smoke opens the real dialog and checks the combobox + Name widget state;
#  it self-skips under --nogui.
#
#  Run:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script symbol_pin_scope_form.tcl     ;# logic gate
#      ../src/xschem --pipe -q --script symbol_pin_scope_form.tcl  ;# + gui smoke
#

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

set wd [file normalize ./symbol_pin_scope_form_work]
file delete -force $wd
file mkdir $wd
proc write_sym {path body} {
  set fp [open $path w]
  foreach h {{v {xschem version=3.4.8RC file_version=1.3}} {G {}} {K {type=subcircuit}} {V {}} {S {}} {E {}}} {
    puts $fp $h
  }
  puts -nonewline $fp $body
  close $fp
}

# A(in) B(out) C(inout), distinct names, all shown.
set sym $wd/pins3.sym
write_sym $sym \
"B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_dx=20 name_dy=-5 name_size=0.2}
B 5 -2.5 17.5 2.5 22.5 {name=B dir=out show_pinname=true name_dx=-25 name_dy=-5 name_size=0.2 name_flip=1}
B 5 -2.5 37.5 2.5 42.5 {name=C dir=inout show_pinname=true name_dx=-25 name_dy=-5 name_size=0.2 name_flip=1}
"
# two pins sharing a name (uniform)
set symdup $wd/pins_dup.sym
write_sym $symdup \
"B 5 -2.5 -2.5 2.5 2.5 {name=P dir=in show_pinname=true name_dx=20 name_dy=-5 name_size=0.2}
B 5 -2.5 17.5 2.5 22.5 {name=P dir=out show_pinname=true name_dx=-25 name_dy=-5 name_size=0.2 name_flip=1}
"

set showoff "name=A dir=in show_pinname=false name_dx=20 name_dy=-5 name_size=0.2"
proc selAB {} { xschem unselect_all; xschem select rect 5 0; xschem select rect 5 1 }
proc showv {n} { xschem getprop rect 5 $n show_pinname }

# ---------------------------------------------------------------------------
# A. label <-> canonical scope mapping (pure)
# ---------------------------------------------------------------------------
check "map: current -> label"   [gfxform::scope_label_for current]      {Only Current}
check "map: selected -> label"  [gfxform::scope_label_for selected]     {All Selected}
check "map: all -> label"       [gfxform::scope_label_for all]          {All}
check "map: label -> current"   [gfxform::scope_value_for {Only Current}] current
check "map: label -> selected"  [gfxform::scope_value_for {All Selected}] selected
check "map: label -> all"       [gfxform::scope_value_for {All}]        all
check "map: round-trip"         [gfxform::scope_value_for [gfxform::scope_label_for selected]] selected

# ---------------------------------------------------------------------------
# B. name_editable = the Name-greying decision (1 editable / 0 grey)
# ---------------------------------------------------------------------------
xschem load $sym ; selAB
check "grey: current single -> editable"    [gfxform::name_editable current]  1
check "grey: selected differ -> grey"       [gfxform::name_editable selected] 0
check "grey: all differ -> grey"            [gfxform::name_editable all]      0
xschem load $sym ; xschem unselect_all ; xschem select rect 5 0
check "grey: single selected -> editable"   [gfxform::name_editable selected] 1
xschem load $symdup ; xschem unselect_all ; xschem select rect 5 0 ; xschem select rect 5 1
check "grey: same-name pair -> editable"    [gfxform::name_editable selected] 1

# ---------------------------------------------------------------------------
# C. do_apply routes the pin scope to apply_pin_prop
# ---------------------------------------------------------------------------
set ::gfxform::type pin
xschem load $sym ; selAB ; set ::gfxform_pin_scope current  ; gfxform::do_apply $showoff
check "route current: A hidden"    [showv 0] false
check "route current: B untouched" [showv 1] true
check "route current: C untouched" [showv 2] true
xschem load $sym ; selAB ; set ::gfxform_pin_scope selected ; gfxform::do_apply $showoff
check "route selected: A hidden"   [showv 0] false
check "route selected: B hidden"   [showv 1] false
check "route selected: C untouched" [showv 2] true
xschem load $sym ; selAB ; set ::gfxform_pin_scope all      ; gfxform::do_apply $showoff
check "route all: A hidden"       [showv 0] false
check "route all: C hidden"       [showv 2] false
# pinname (and other types) IGNORE the pin scope -> default selected, even with scope=all set
set ::gfxform::type pinname
xschem load $sym ; selAB ; set ::gfxform_pin_scope all      ; gfxform::do_apply $showoff
check "route pinname ignores scope: C untouched" [showv 2] true
set ::gfxform::type pin

# ---------------------------------------------------------------------------
# D. greying discards a pending Name edit so it can't fan when the scope widens (review [2])
# ---------------------------------------------------------------------------
set pinprop "name=A dir=in show_pinname=true name_dx=20 name_dy=-5 name_size=0.2"
xschem load $sym ; selAB
gfxform::init $pinprop pin
set gfxform::val(name) Z              ;# user typed a new name
set ::gfxform_pin_scope selected     ;# widen to a scope where names differ -> Name greyed
gfxform::pin_scope_greying
check "revert: greyed scope discards typed name" $gfxform::val(name) A
xschem load $sym ; xschem unselect_all ; xschem select rect 5 0
gfxform::init $pinprop pin
set gfxform::val(name) Z
set ::gfxform_pin_scope current       ;# editable scope keeps the pending edit
gfxform::pin_scope_greying
check "revert: editable scope keeps typed name"  $gfxform::val(name) Z

# ---------------------------------------------------------------------------
# E. DISPLAY-gated smoke: real dialog has the scope combobox + greys Name live
# ---------------------------------------------------------------------------
if {![catch {winfo exists .}] && [info exists ::env(DISPLAY)]} {
  xschem load $sym ; selAB
  set ::tctx::retval $pinprop
  set ::gfxform_via_name 0
  set ::gfxform_pin_scope selected
  set ::smoke_cb 0 ; set ::smoke_name {} ; set ::smoke_tries 0
  # POLL for the built widgets, don't race text_line_slick's `tkwait visibility` with a
  # fixed delay (review [5]): .dialog.appear.name.e is built last, so it is the "ready"
  # sentinel; the scope combobox is built before it.
  proc ::smoke_poll {} {
    if {[winfo exists .dialog.appear.name.e]} {
      set ::smoke_cb [expr {[winfo exists .dialog.scope.cb] ? 1 : 0}]
      catch {set ::smoke_name [.dialog.appear.name.e cget -state]}
      catch {destroy .dialog}
    } elseif {[incr ::smoke_tries] < 100} {
      after 40 ::smoke_poll
    } else {
      catch {destroy .dialog}
    }
  }
  after 40 ::smoke_poll
  catch {text_line_slick "Text:" 0 normal pin}
  check "gui: scope combobox present"        $::smoke_cb 1
  check "gui: Name greyed under selected"    $::smoke_name disabled
} else {
  puts "skip - gui smoke (no DISPLAY / --nogui)"
}

puts "===================="
if {$nfail == 0} { puts "symbol_pin_scope_form: ALL PASS" } else { puts "symbol_pin_scope_form: $nfail FAIL" ; exit 1 }
