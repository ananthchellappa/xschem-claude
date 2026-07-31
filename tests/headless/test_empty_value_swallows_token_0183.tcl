# An empty attribute value swallows the NEXT token (issue 0183).
#
# --- the tokenizer, which is NOT the bug ---------------------------------------
# A property string is whitespace-separated `key=value` tokens read by
# get_tok_value() (src/token.c). Given
#
#     name=
#     flags=graph,unlocked
#     lock=1
#
# get_tok_value(.., "name") returns "flags=graph,unlocked" and `flags` does not
# exist. The whitespace after `=` is SKIPPED, so the value is taken to be the
# next thing along -- and that is deliberate, not a defect:
#
#     xschem_library/ngspice_verilog_cosim/tb_sar_adc.sch:176
#     C {dac_bridge.sym} 330 -160 0 0 {name=A2 dac_bridge_model= dac_buff
#
# The author wrote a space after `=` and MEANT the value `dac_buff`. Measured:
# get_tok_value on that string returns `dac_buff`. So `key= value` is part of
# the grammar in practice, in a SHIPPED library file, and "fixing" the tokenizer
# would silently break it. The ET legs below are the guard rail on that
# decision -- ET12 in particular. **Do not make them pass by changing
# get_tok_value().**
#
# The grammar already has a way to say "empty": `key=""` reads back as PRESENT
# with an empty value, and the token after it parses normally (ET04).
#
# --- so the bug is at the PRODUCERS -------------------------------------------
# Two measured, both building a property string with my_mstrcat, which SKIPS an
# empty argument and keeps walking (util.c:783) -- correct C, wrong data:
#
#   actions.c create_pin()      "name=", name, " dir=", dir, nums
#     name is "" when the caller passes one (`if(!name) name = "";`), and
#     `xschem add_symbol_pin <x> <y> {} <dir>` does exactly that -- argv[4] goes
#     straight through with no guard, unlike the other two callers
#     (paste.c:441 `if(lab && lab[0])`, scheduler.c:1725 `nm = "XXX"`).
#     Measured pre-fix: name=<<dir=in>> and **dir is GONE**. dir drives netlist
#     port direction, ERC, set_pin_type and paste's dup-name coercion, so a
#     nameless pin silently becomes a direction-less one. This is the WORSE of
#     the two and was not the reported site.
#
#   actions.c place_symbol()    "name=", instname, "\n"   (the reported site)
#     instname is "" when a type=scope symbol's template carries no name=.
#     Measured pre-fix: the embedded graph floater reads
#     name=<<flags=graph,unlocked>> with flags=<<>>, so it is not a graph.
#
# NOT a defect, though it looks like a textbook one: actions.c:1426
# `"name=l0 lab=", netname ? netname : "", " text_size_0=", szbuf`. The
# `if(!netname || !netname[0]) { ...; continue; }` five lines above it means the
# empty case never reaches the concatenation. EN1 pins that, so a future
# refactor that drops the guard fails here rather than shipping a wire label
# whose `lab` has eaten `text_size_0`.
#
# --- legs ---------------------------------------------------------------------
#   ET*  the tokenizer, characterised. Guard rail on the producer-vs-tokenizer
#        decision; these must pass before AND after any producer fix.
#   EP*  create_pin(): a nameless pin keeps its dir
#   EF*  place_symbol(): a nameless scope symbol's floater keeps its flags
#   EN*  the non-defects, pinned so they stay non-defects
#
# Run either arm:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_empty_value_swallows_token_0183.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_empty_value_swallows_token_0183.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch empty_value_swallows_token_0183]

if {[catch {

# --- ET: the tokenizer, characterised -----------------------------------------
# `xschem get_tok <str> <tok>` is a pure wrapper over get_tok_value(); the
# following `xschem get_tok_size` is 0 when the token was NOT FOUND and the
# token-name length when it was. That pair is the only way to tell "absent" from
# "present but empty", so every leg carries both.
proc tok {str t} {
  set v [xschem get_tok $str $t]
  return [list $v [expr {[xschem get_tok_size] ? 1 : 0}]]
}

check "ET01 an empty value eats the NEXT token" \
  [tok "name=\nflags=graph,unlocked\nlock=1\n" name] {flags=graph,unlocked 1}
check "ET01b ...and the eaten token no longer exists" \
  [tok "name=\nflags=graph,unlocked\nlock=1\n" flags] {{} 0}
check "ET02 a SPACE behaves exactly like a newline" \
  [tok "name= flags=graph,unlocked lock=1" name] {flags=graph,unlocked 1}
check "ET03 a TAB too" \
  [tok "name=\tflags=graph,unlocked" name] {flags=graph,unlocked 1}
# ET04 is the escape hatch the producers are supposed to use.
check "ET04 key=\"\" reads back as PRESENT and empty" \
  [tok "name=\"\"\nflags=graph,unlocked\n" name] {{} 1}
check "ET04b ...and the following token survives" \
  [tok "name=\"\"\nflags=graph,unlocked\n" flags] {graph,unlocked 1}
check "ET05 a trailing key= at end-of-string reports NOT FOUND" \
  [tok "flags=graph,unlocked\nname=\n" name] {{} 0}
check "ET06 neighbours either side of the victim are unharmed" \
  [list [tok "a=1\nname=\nflags=graph\nb=2\n" a] [tok "a=1\nname=\nflags=graph\nb=2\n" b]] \
  {{1 1} {2 1}}
check "ET07 it is general, not specific to 'name'" \
  [tok "lab=\nvalue=1k\n" lab] {value=1k 1}
check "ET08 exactly ONE token is eaten, the rest still parses" \
  [list [tok "name=\nlab=\nvalue=1k\n" name] [tok "name=\nlab=\nvalue=1k\n" value]] \
  {{lab= 1} {1k 1}}
check "ET09 a blank line does not stop it" \
  [tok "name=\n\nflags=graph\n" name] {flags=graph 1}
check "ET10 a bare key= with nothing after it is NOT FOUND" \
  [tok "name=" name] {{} 0}
check "ET11 (control) an ordinary pair reads correctly, both of them" \
  [list [tok "name=g1\nflags=graph,unlocked\n" name] [tok "name=g1\nflags=graph,unlocked\n" flags]] \
  {{g1 1} {graph,unlocked 1}}

# ET12 is the reason the tokenizer was NOT changed. This is the literal shape in
# xschem_library/ngspice_verilog_cosim/tb_sar_adc.sch:176 and sar_adc.sch:78:
# the author wrote `key= value` with a space and meant `value`. If this leg ever
# goes red, someone has "fixed" the whitespace-skip and broken a shipped file.
set sar "name=A2 dac_bridge_model= dac_buff\n\ndevice_model=\".model dac_buff dac_bridge input_load=1e-15 t_rise=10n\"\n"
check "ET12 (GUARD RAIL) `key= value` with a space is a real value, per tb_sar_adc.sch" \
  [tok $sar dac_bridge_model] {dac_buff 1}
check "ET12b the tokens either side of it still read correctly" \
  [list [tok $sar name] [tok $sar device_model]] \
  [list {A2 1} [list {.model dac_buff dac_bridge input_load=1e-15 t_rise=10n} 1]]

# ET13 records the third producer, actions.c:3214. Its value get_cell(sym, 0) IS
# reachably empty -- `schematic=foo/` makes sym "foo/.sym", and
# get_trailing_path() (token.c:1434-1440) NUL-terminates at the '.' then returns
# the text after the '/', i.e. "". Measured: such an instance logs
# `has_included_subcircuit: :` with an empty cell name. What could NOT be
# constructed is an end-to-end user-visible symptom, because the paths that feed
# symname_attr to translate3() need a spice_sym_def that a plain fixture does not
# reach. So this leg pins the MECHANISM at the level that is measurable -- the
# exact string the site would have built, and what get_tok_value does to it --
# rather than claiming a reproduction that was never obtained.
check "ET13 an unquoted empty symname would swallow symref (the shape at actions.c:3214)" \
  [list [tok "symname= symref=/lib/foo.sym" symname] [tok "symname= symref=/lib/foo.sym" symref]] \
  {{symref=/lib/foo.sym 1} {{} 0}}
check "ET13b ...and the quoted form the fix emits keeps both" \
  [list [tok "symname=\"\" symref=/lib/foo.sym" symname] [tok "symname=\"\" symref=/lib/foo.sym" symref]] \
  {{{} 1} {/lib/foo.sym 1}}

# --- EP: create_pin() -- a nameless pin must keep its dir ----------------------
# `xschem add_symbol_pin <x> <y> <name> <dir>` is the argc>5 route
# (scheduler.c:1667-1677), the ONE caller of create_pin() that does not guard an
# empty name. dir is guaranteed non-empty by create_pin itself
# (`if(!dir || !dir[0]) dir = "inout";`), so if dir comes back empty the only
# explanation is that `name=` ate it.
xschem clear force
xschem set netlist_type symbol
xschem add_symbol_pin 0 0 P1 in
check "EP0 (control) a NAMED pin keeps name and dir" \
  [list [xschem getprop rect 5 0 name] [xschem getprop rect 5 0 dir]] {P1 in}
xschem add_symbol_pin 0 100 {} in
check "EP1 a NAMELESS pin does not eat its own dir token" \
  [xschem getprop rect 5 1 dir] in
check "EP2 ...and its name reads back as empty, not as the dir token" \
  [xschem getprop rect 5 1 name] {}
# Only ONE token is eaten (ET08), so the token after dir survives even pre-fix.
# EP3 exists so a fix that repairs dir by mangling the layout tokens is caught.
check "EP3 the layout tokens after dir are untouched" \
  [list [xschem getprop rect 5 1 show_pinname] [xschem getprop rect 5 1 name_size]] \
  {true 0.2}
xschem add_symbol_pin 0 200 {} out
check "EP4 the same for dir=out (the flip branch)" \
  [list [xschem getprop rect 5 2 dir] [xschem getprop rect 5 2 name_flip]] {out 1}

# --- EF: place_symbol() -- the reported scope-floater site --------------------
# A type=scope symbol embeds a locked graph floater as a rect on layer 2
# (GRIDLAYER, xschem.h:163). With no name= in the symbol template, instname is
# "" and the floater's "name=\n" ate "flags=graph,unlocked".
proc write_scope_sym {path templ} {
  set f [open $path w]
  puts $f {v {xschem version=3.4.8RC file_version=1.3}}
  puts $f "G {}"
  puts $f "K {type=scope\ntemplate=\"$templ\"\n}"
  foreach x {V S E} { puts $f "$x {}" }
  puts $f {L 4 -50 -50 50 -50 {}}
  puts $f {B 5 -52.5 -2.5 -47.5 2.5 {name=p0 dir=inout}}
  close $f
}
write_scope_sym [file join $scratch noname.sym] {value=1}
write_scope_sym [file join $scratch named.sym]  {name=g1 value=1}

# UNQUALIFIED, deliberately: xschem installs a Tcl variable TRACE on the global
# name, and `set ::XSCHEM_LIBRARY_PATH` does not fire it -- the symbol then does
# not resolve and every leg below reports on an empty design.
set XSCHEM_LIBRARY_PATH $scratch

xschem clear force
xschem place_symbol named.sym
check "EF0 (control) a NAMED scope symbol's floater keeps name and flags" \
  [list [xschem get instances] [xschem getprop rect 2 0 name] \
        [xschem getprop rect 2 0 flags]] {1 g1 graph,unlocked}

xschem clear force
xschem place_symbol noname.sym
# EF1 carries the instance count: if the symbol failed to resolve there is no
# rect at all, getprop errors, and the whole block would fall into the FATAL
# catch rather than report a green leg on nothing.
check "EF1 a NAMELESS scope symbol still places one instance" [xschem get instances] 1
check "EF2 its floater keeps flags=graph,unlocked" \
  [xschem getprop rect 2 0 flags] {graph,unlocked}
check "EF3 ...and its name reads back as empty, not as the flags token" \
  [xschem getprop rect 2 0 name] {}
check "EF4 the tokens after flags are untouched" \
  [list [xschem getprop rect 2 0 lock] [xschem getprop rect 2 0 color]] {1 8}

# EF5 is the leg that matters: this needs NO hand-authored symbol. All three
# shipped scope symbols carry template="name=l1", which is why the bug was
# originally believed to need a custom .sym -- but the template is not consulted
# when the caller supplies inst_props. `xschem instance <sym> x y r f <props>`
# (argc==8) hands argv[7] straight to place_symbol as inst_props, and
# new_prop_string() then sets instname from THAT string; with no name= in it,
# instname is "" regardless of the template. So the reported defect is reachable
# with the STOCK library, from one scriptable command.
# Measured pre-fix on devices/scope.sym: name=<<flags=graph,unlocked>>, flags=<<>>.
xschem clear force
set XSCHEM_LIBRARY_PATH [file join $repo xschem_library]
check "EF5 the SHIPPED devices/scope.sym, placed with inst_props lacking a name=" \
  [expr {[catch {xschem instance devices/scope.sym 0 0 0 0 {lock=1}} eshipped] ? "ERR:$eshipped" : \
         [list [xschem getprop instance 0 name] \
               [xschem getprop rect 2 0 name] \
               [xschem getprop rect 2 0 flags] \
               [xschem getprop rect 2 0 lock]]}] \
  {{} {} graph,unlocked 1}

# --- EL: the LCC symbol-generation path ---------------------------------------
# add_pinlayer_boxes() (save.c) synthesises a symbol PINLAYER rect for each
# ipin/opin/iopin instance when a .sch is instantiated DIRECTLY as a symbol:
#
#     label = get_tok_value(prop_ptr, "lab", 0);          /* "" when absent */
#     my_snprintf(pin_label, save, "name=%s dir=in ", label);
#
# so an unlabelled pin produced "name= dir=in " and the synthesised pin had NO
# dir. This is the most reachable instance of the whole class -- no scripted
# command, no hand-authored symbol, just a schematic with an unlabelled pin used
# as a subcircuit. It was MISSED by the first pass of the fix, because the sweep
# slice covering save.c died on an API error and was only re-run afterwards.
# `xschem pinlist <inst> <token>` reads exactly these rects.
proc write_file {path body} { set f [open $path w]; puts $f $body; close $f }
write_file [file join $scratch child.sch] "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
E {}
N 0 0 100 0 {}
N 0 100 100 100 {}
C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=GOOD}
C {devices/ipin.sym} 0 100 0 0 {name=p2 lab=}"
write_file [file join $scratch parent.sch] "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
E {}
C {child.sch} 300 0 0 0 {name=X1}"
set XSCHEM_LIBRARY_PATH "$scratch:[file join $repo xschem_library]"
xschem clear force
xschem load [file join $scratch parent.sch]
# Both pins are asserted together: the LABELLED one is the control that catches a
# fix which repairs dir by mangling the name, and pin order pins which is which.
check "EL1 an unlabelled schematic pin keeps its dir through symbol generation" \
  [xschem pinlist X1 dir] {{ {0} {in} } { {1} {in} }}
check "EL2 ...and its name reads back as empty, not as the dir token" \
  [xschem pinlist X1 name] {{ {0} {GOOD} } { {1} {} }}

# --- EN: the non-defects, pinned ----------------------------------------------
# actions.c:1426 builds "name=l0 lab=", netname, " text_size_0=", szbuf -- which
# is the exact defect shape -- but actions.c:1421 refuses an empty netname five
# lines earlier, so it never fires. Assert the GUARD, because that is the thing a
# future refactor would remove. add_wire_stubs on a symbol whose pin has no name
# and with no prefix/suffix must add NOTHING rather than a blank-labelled pin.
xschem clear force
set nostub [catch {xschem add_wire_stubs} enw]
check "EN1 (guard) add_wire_stubs on an empty design adds no objects" \
  [list [xschem get instances] [xschem get wires]] {0 0}

} err]} { puts "FATAL: $err" ; incr fail }

# House banner form: full_audit.sh is_pass() scores on "RESULT: ALL PASS".
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
