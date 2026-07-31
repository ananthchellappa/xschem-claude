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
# Half a defect: actions.c:1426
# `"name=l0 lab=", netname ? netname : "", " text_size_0=", szbuf`. The
# `if(!netname || !netname[0]) { ...; continue; }` five lines above it stops the
# EMPTY case from reaching the concatenation -- but it did NOT stop the BLANK
# case, and `xschem add_pin_stubs -prefix { }` over a nameless pin measured
# lab=<<text_size_0=0.2>> with text_size_0 destroyed. The guard now tests
# str_is_blank(). EN1 pins it, so a future refactor that drops the guard fails
# here rather than shipping a wire label whose `lab` has eaten `text_size_0`.
#
# --- the BLANK variant --------------------------------------------------------
# A value made only of SEPARATOR characters is empty to get_tok_value() as well,
# and SPACE() (token.c:24) counts ';' as one alongside space, tab and newline. So
# `key= ` and `key=;` destroy the next token exactly like `key=` does. The first
# round of this fix tested value[0] / eq {} / == "" and caught none of them; the
# producers now use str_is_blank(), which lives next to SPACE() so the two cannot
# drift apart. EW legs.
#
# --- legs ---------------------------------------------------------------------
#   ET*  the tokenizer, characterised. Guard rail on the producer-vs-tokenizer
#        decision; these must pass before AND after any producer fix.
#   EP*  create_pin(): a nameless pin keeps its dir
#   EF*  place_symbol(): a nameless scope symbol's floater keeps its flags
#   EL*  add_pinlayer_boxes() (save.c): the LCC path, a .sch used as a symbol
#   EC*  create_symbol() (xschem.tcl): a scripting entry point that writes a .sym
#   EA*  make_sym.awk / make_sym_lcc.awk: "make symbol from schematic"
#   ER*  the quoted empty value survives save + reload, in both a .sym and a .sch
#   EV*  make_sch_from_vhdl.awk: a wrapped port declaration
#   EX*  viewdraw_import.awk: a pin with no label text
#   EW*  the BLANK variant: whitespace and ';' are empty to the tokenizer too
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

# read one attribute of a rect as {value found}; `found` is what separates an
# attribute that is present and empty from one that is not there at all.
proc rtok {layer n t} {
  set v [xschem getprop rect $layer $n $t]
  return [list $v [expr {[xschem get_tok_size] ? 1 : 0}]]
}

# --- EC: create_symbol, a scripting entry point that WRITES A .sym -------------
# `create_symbol <file> {in…} {out…} {inout…}` (src/xschem.tcl) is a documented
# user-facing scripting proc with no in-repo callers, so nothing else covers it.
# It emits one `B 5 … {name=$pin dir=…}` per list element, and an EMPTY element
# wrote `name= dir=in` straight into the .sym on disk -- the generated pin then
# reads back as name=<<dir=in>> with NO dir at all. Persisted, unlike the LCC
# path which regenerates its pins on every load. Measured pre-fix:
#     B 5 -152.5 17.5 -147.5 22.5 {name= dir=in}   ->  rect5[1] dir absent (found=0)
set csym [file join $scratch created.sym]
set csres [create_symbol $csym {A {} B} {Q} {IO}]
xschem clear force
xschem load $csym
check "EC1 create_symbol writes one pin box per list element" \
  [list $csres [xschem get rects 5]] {1 5}
check "EC2 an EMPTY pin name does not eat the dir token" [rtok 5 1 dir] {in 1}
check "EC3 ...and reads back as present-and-empty" [rtok 5 1 name] {{} 1}
check "EC4 the named pins either side are untouched" \
  [list [rtok 5 0 name] [rtok 5 2 name]] {{A 1} {B 1}}
check "EC5 the out and inout branches are unharmed" \
  [list [rtok 5 3 dir] [rtok 5 4 dir]] {{out 1} {inout 1}}

# --- ER: the quoted empty value must SURVIVE a save + reload -------------------
# The whole fix rests on `key=""` being written out and read back as PRESENT with
# an empty value. If save.c ever strips or re-quotes it, the file on disk goes
# back to a bare `key=` and the fix evaporates the moment the cell is reloaded --
# and every leg above would still be green, because they all read the IN-MEMORY
# property string. So round-trip it through the real writer and reader, on both
# file kinds: a .sym (create_pin, PINLAYER rect) and a .sch (place_symbol's
# floater, layer 2). Measured file text: `B 5 ... {name="" dir=in ...}`.
xschem clear force
xschem set netlist_type symbol
xschem add_symbol_pin 0 100 {} in
set rtsym [file join $scratch roundtrip.sym]
xschem saveas $rtsym
xschem clear force
xschem load $rtsym
check "ER1 a nameless symbol pin RELOADS with its dir intact" [rtok 5 0 dir] {in 1}
check "ER2 ...and its name is still PRESENT and empty, not absent" [rtok 5 0 name] {{} 1}

xschem clear force
xschem set netlist_type spice
xschem instance devices/scope.sym 0 0 0 0 {lock=1}
set rtsch [file join $scratch roundtrip.sch]
xschem saveas $rtsch
xschem clear force
xschem load $rtsch
check "ER3 a nameless scope floater RELOADS with flags=graph,unlocked" \
  [rtok 2 0 flags] {graph,unlocked 1}
check "ER4 ...and its name is still PRESENT and empty" [rtok 2 0 name] {{} 1}

# --- EA: the awk symbol generators, which WRITE A .sym FROM A SCHEMATIC --------
# `make_symbol` (xschem.tcl:8455) shells out to src/make_sym.awk, and the LCC
# variant to src/make_sym_lcc.awk. Both build the pin property block as
#     the literal `name=`, then label_pin[i], then vhdt, vert, then ` dir=in`.
# label_pin is the schematic pin's lab= -- empty for an unlabelled pin, the
# same everyday case as the EL legs above. So "make symbol from schematic" on a
# schematic with one unlabelled pin wrote `{name= dir=in}` into the .sym ON DISK
# and the pin had no direction at all. Measured pre-fix on both scripts.
# This is the only coverage either script has, so the legs also assert the
# generator ran at all (a pin count) rather than trusting an empty file.
set awksch [file join $scratch awkgen.sch]
write_file $awksch "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
E {}
C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=GOOD}
C {devices/ipin.sym} 0 -20 0 0 {name=p2}
C {devices/opin.sym} 0 -40 0 0 {name=p3 lab=OUT1}"

set awkbin [file join $repo src make_sym.awk]
set awksym [file join $scratch awkgen_out.sym]
set awkerr [catch {exec awk -v outsym=$awksym -f $awkbin 200 $awksch} awkmsg]
xschem clear force
if {[file exists $awksym]} { xschem load $awksym }
# pins come out ordered by y, so the unlabelled p2 is not index 1 -- find it by
# asking which box has no name rather than assuming a position.
proc pin_with_empty_name {} {
  set n [xschem get rects 5]
  for {set i 0} {$i < $n} {incr i} {
    if {[lindex [rtok 5 $i name] 0] eq {}} { return $i }
  }
  return -1
}
check "EA1 make_sym.awk generated all three pins" \
  [list $awkerr [xschem get rects 5]] {0 3}
set ei [pin_with_empty_name]
check "EA2 the unlabelled pin exists and its name is PRESENT and empty" \
  [expr {$ei < 0 ? "NOTFOUND" : [rtok 5 $ei name]}] {{} 1}
check "EA3 ...and it kept its dir" \
  [expr {$ei < 0 ? "NOTFOUND" : [rtok 5 $ei dir]}] {in 1}

# make_sym_lcc.awk derives its output name from the input: <rootname>.sym
set lccsch [file join $scratch lccgen.sch]
file copy -force $awksch $lccsch
set lccsym [file join $scratch lccgen.sym]
set lccerr [catch {exec awk -f [file join $repo src make_sym_lcc.awk] $lccsch} lccmsg]
xschem clear force
if {[file exists $lccsym]} { xschem load $lccsym }
check "EA4 make_sym_lcc.awk generated all three pins" \
  [list $lccerr [xschem get rects 5]] {0 3}
set li [pin_with_empty_name]
check "EA5 the unlabelled pin keeps its dir there too" \
  [expr {$li < 0 ? "NOTFOUND" : [rtok 5 $li dir]}] {in 1}

# --- EG: gschemtoxschem.awk, the gEDA/lepton import path -----------------------
# The converter copies attributes VERBATIM out of the gEDA file, so an empty one
# in the input becomes an empty one in the xschem property block -- and eats the
# attribute after it. This is user data, not xschem code, so the empty value is
# entirely ordinary. doc/xschem_man/tutorial_gschemtoxschem.html tells the user to
# run the script over their whole gEDA library, and
# xschem_library/gschem_import/convert_script does the same over the lepton-eda
# examples. Measured pre-fix on the component path:
#   value= between refdes=R5 and device=RESISTOR
#     -> value == "device=RESISTOR" and `device` GONE, so a resistor whose spice
#        format is @value netlists as `R5 n1 n2 device=RESISTOR`.
# and on the symbol path, an empty pinnumber ate pinseq AND an empty pinlabel ate
# the pin's dir.
set gsch [file join $scratch geda_in.sch]
write_file $gsch "v 20130925 2
C 3670 5470 1 0 0 resistor-1.sym
\{
T 3770 5570 5 10 1 1 0 0 1
refdes=R5
T 3770 5600 5 10 0 0 0 0 1
value=
T 3770 5630 5 10 0 0 0 0 1
device=RESISTOR
T 3770 5660 5 10 0 0 0 0 1
footprint=0805
\}"
set gawk [file join $repo src gschemtoxschem.awk]
set gconv [file join $scratch geda_out.sch]
set gerr [catch {exec awk -f $gawk $gsch} gout]
if {!$gerr} { write_file $gconv $gout }
# pull the instance's {...} property block out of the converted text and ask the
# real tokenizer what it sees -- the symbol it references does not exist here, so
# loading the schematic would prove nothing.
set gprop {}
if {[regexp {C \{resistor-1\.sym\} [^\{]*\{(.*?)\n\}} $gout -> gprop]} {}
check "EG1 the converter ran and produced an instance property block" \
  [list $gerr [expr {$gprop eq {} ? "EMPTY" : "ok"}]] {0 ok}
check "EG2 an empty attribute does not eat the NEXT attribute" \
  [tok $gprop device] {RESISTOR 1}
check "EG3 ...and itself reads back as present-and-empty" [tok $gprop value] {{} 1}
check "EG4 the attributes either side are untouched" \
  [list [tok $gprop name] [tok $gprop footprint]] {{R5 1} {0805 1}}

# The symbol path, which is self-contained enough to load for real.
set gsym [file join $scratch geda_in.sym]
write_file $gsym "v 20130925 2
P 0 200 200 200 1 0 0
\{
T 100 250 5 8 0 1 0 0 1
pinnumber=
T 100 250 5 8 0 1 0 0 1
pinseq=1
T 0 200 5 8 0 1 0 0 1
pinlabel=
T 0 200 5 8 0 1 0 0 1
pintype=in
\}
T 0 0 8 10 0 0 0 0 1
device=
T 0 0 8 10 0 0 0 0 1
value=
T 0 0 8 10 0 0 0 0 1
footprint=0805"
set gsymconv [file join $scratch geda_out.sym]
set gserr [catch {exec awk -f $gawk $gsym} gsout]
if {!$gserr} { write_file $gsymconv $gsout }
xschem clear force
if {[file exists $gsymconv]} { xschem load $gsymconv }
check "EG5 the converted symbol has its pin" \
  [list $gserr [xschem get rects 5]] {0 1}
# pre-fix: pinnumber ate pinseq, and the pin's name (from the empty pinlabel) ate dir.
check "EG6 an empty pinnumber does not eat pinseq" [rtok 5 0 pinseq] {1 1}
check "EG7 an empty pin name does not eat dir" [rtok 5 0 dir] {in 1}
check "EG8 both empties read back as present-and-empty" \
  [list [rtok 5 0 pinnumber] [rtok 5 0 name]] {{{} 1} {{} 1}}
# the template= path goes through escape_chars(), which writes the quotes in the
# template's own doubled-backslash convention -- check xschem's reader agrees.
set gtmpl [xschem get_tok [xschem get schsymbolprop] template]
check "EG9 an empty template attribute does not eat the next one" \
  [list [tok $gtmpl value] [tok $gtmpl footprint]] {{{} 1} {0805 1}}

# --- EW: a WHITESPACE-only value is just as empty, and slipped past every guard -
# The first round of this fix tested emptiness as `value[0]` (C), `eq {}` (Tcl) and
# `== ""` (awk). None of them catches a value made only of SEPARATOR characters,
# which get_tok_value() treats identically to "" -- and SPACE() in token.c counts
# ';' as a separator alongside space, tab and newline. So `key= ` followed by
# another token destroys that token exactly like `key=` does. The producers now
# test str_is_blank() (token.c, next to SPACE() so the two cannot drift).
check "EW0 a single space value eats the next token, like an empty one" \
  [tok "name= \ndir=in\n" name] {dir=in 1}
check "EW0b a SEMICOLON does too -- SPACE() counts it as a separator" \
  [tok "name=;\ndir=in\n" name] {dir=in 1}
check "EW0c ...and in both cases the eaten token is gone" \
  [list [tok "name= \ndir=in\n" dir] [tok "name=;\ndir=in\n" dir]] {{{} 0} {{} 0}}

# create_pin, through the shared my_mstrcat_tok helper.
# Measured pre-fix: name=<<dir=in>> and dir GONE.
xschem clear force
xschem set netlist_type symbol
xschem add_symbol_pin 0 100 { } in
check "EW1 a pin named with one SPACE keeps its dir" [rtok 5 0 dir] {in 1}
check "EW1b ...and its name reads back as present-and-empty" [rtok 5 0 name] {{} 1}

# add_pin_stubs: its guard is meant to SKIP a pin that yields no net name. A
# whitespace prefix over a nameless pin passed the old `!netname[0]` test and
# emitted `name=l0 lab=  text_size_0=0.2`, destroying text_size_0.
write_file [file join $scratch nameless.sym] "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit}
V {}
S {}
E {}
L 4 -50 -50 50 -50 {}
B 5 -52.5 -2.5 -47.5 2.5 {}"
write_file [file join $scratch stubtop.sch] "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
E {}
C {nameless.sym} 0 0 0 0 {name=U1}"
set XSCHEM_LIBRARY_PATH "$scratch:[file join $repo xschem_library]"
xschem clear force
xschem load [file join $scratch stubtop.sch]
xschem select_all
set stuberr [catch {xschem add_pin_stubs -prefix { }} stubmsg]
check "EW2 a blank prefix over a nameless pin adds NO label (the guard's own intent)" \
  [list $stuberr [xschem get instances]] {0 1}

# save.c's LCC path, where the blank arrives from a schematic pin written lab=" ".
write_file [file join $scratch wschild.sch] "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
E {}
C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=GOOD}
C {devices/ipin.sym} 0 -20 0 0 {name=p2 lab=\" \"}"
write_file [file join $scratch wsparent.sch] "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
E {}
C {[file join $scratch wschild.sch]} 300 0 0 0 {name=X1}"
xschem clear force
xschem load [file join $scratch wsparent.sch]
check "EW3 a pin labelled with one SPACE keeps its dir through symbol generation" \
  [xschem pinlist X1 dir] {{ {0} {in} } { {1} {in} }}

# create_symbol, the Tcl side.
set wsym [file join $scratch wscreated.sym]
set wsres [create_symbol $wsym [list A { } B] {Q} {}]
xschem clear force
xschem load $wsym
set wi [pin_with_empty_name]
check "EW4 create_symbol treats a blank list element as empty, not as a name" \
  [expr {$wi < 0 ? "NOTFOUND" : [rtok 5 $wi dir]}] {in 1}

# --- EV: make_sch_from_vhdl.awk, the VHDL importer -----------------------------
# It emits `{name=p0 sig_type=<type> lab=<port> }`. A port declaration WRAPPED over
# two lines -- legal VHDL, and common in wide port lists --
#
#     CLK : in
#       std_logic;
#
# leaves $4 empty on the line that decides the direction, so sig_type is empty and
# swallows `lab=CLK`: the generated schematic's port has NO net name. Measured
# pre-fix: sig_type=<<lab=CLK>> with lab absent. The signal branch of print_sch()
# already quoted its sig_type, so quoting was this file's own existing idiom.
# The script is a /bin/sh wrapper around a gawk program and writes <entity>.sch
# into the CURRENT directory, hence the sh -c cd.
set vhdlawk [file join $repo src make_sch_from_vhdl.awk]
if {[catch {exec sh -c {command -v gawk}} gawkpath]} {
  puts "SKIP: gawk not installed -- EV legs (make_sch_from_vhdl.awk) not run"
} else {
  write_file [file join $scratch wrapped.vhdl] "library ieee;
use ieee.std_logic_1164.all;

entity wrapped is
  port (
    CLK : in
      std_logic;
    Q : out std_logic
  );
end wrapped;

architecture rtl of wrapped is
begin
end rtl;"
  set vres [catch {exec sh -c "cd [file join $scratch] && sh $vhdlawk wrapped.vhdl"} vmsg]
  set vsch [file join $scratch wrapped.sch]
  set vprop {}
  if {[file exists $vsch]} {
    set f [open $vsch r]; set vtxt [read $f]; close $f
    # the ipin instance line; its property block runs to the closing brace
    regexp {C \{devices/ipin\}[^\{]*\{([^\}]*)\}} $vtxt -> vprop
  }
  check "EV1 the VHDL converter ran and emitted the wrapped-declaration port" \
    [list $vres [expr {$vprop eq {} ? "EMPTY" : "ok"}]] {0 ok}
  check "EV2 an empty sig_type does not eat the port's lab" [tok $vprop lab] {CLK 1}
  check "EV3 ...and reads back as present-and-empty" [tok $vprop sig_type] {{} 1}
  check "EV4 the well-formed port on the next line is untouched" \
    [expr {[regexp {C \{devices/opin\}[^\{]*\{([^\}]*)\}} $vtxt -> voprop] ?
           [list [tok $voprop sig_type] [tok $voprop lab]] : "NOTFOUND"}] \
    {{std_logic 1} {Q 1}}
}

# --- EX: viewdraw_import.awk, the ViewDraw importer ----------------------------
# `b = b " {name=" pin_name " dir=" pin_dir "}"`, with pin_name = $10 of the pin's
# `L` (label) line. A pin whose L line carries no text_label field gives $10 == ""
# and the imported symbol pin loses its direction entirely. Measured pre-fix on the
# SHIPPED fixture with its label stripped: {name= dir=in} -> name=<<dir=in>>, no dir.
set vdawk [file join $repo xschem_library viewdraw_import viewdraw_import.awk]
set vdlib [file join $repo xschem_library viewdraw_import xschem_lib]
set vdsrc [file join $repo xschem_library viewdraw_import test sym INPUT.1]
if {![file exists $vdsrc]} {
  puts "SKIP: viewdraw fixture missing -- EX legs not run"
} else {
  set f [open $vdsrc rb]; set vdtxt [read $f]; close $f
  # drop the trailing text_label field from the L line, keeping the CRLF endings
  set vdtxt [string map [list "L 17 7 5 0 9 0 1 0 IN\r" "L 17 7 5 0 9 0 1 0\r"] $vdtxt]
  set vdin [file join $scratch NOLABEL.1]
  set f [open $vdin wb]; puts -nonewline $f $vdtxt; close $f
  set xres [catch {exec awk -f $vdawk $vdin $vdlib} xout]
  set xprop {}
  foreach l [split $xout \n] {
    if {[regexp {^B 5 .*\{(name=.*)\}$} $l -> p]} { set xprop $p }
  }
  check "EX1 the ViewDraw converter ran and emitted the pin box" \
    [list $xres [expr {$xprop eq {} ? "EMPTY" : "ok"}]] {0 ok}
  check "EX2 a label-less pin does not eat its dir token" [tok $xprop dir] {in 1}
  check "EX3 ...and its name reads back as present-and-empty" [tok $xprop name] {{} 1}
}

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
