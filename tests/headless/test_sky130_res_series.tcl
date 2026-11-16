# tests/headless/test_sky130_res_series.tcl -- series segments (ns) on the sky130 resistors.
#
# The user's request, 2026-11-16: the sky130 resistor form showed only L and mult, and
# mult is parallel copies. Every sky130_fd_pr/res_* symbol now carries `ns` (template
# default 1); ns > 1 netlists ns chained instances (sky130_res_series, in
# sky130A/xschem_libs/sky130_fd_pr/sky130_res.tcl, which the symbols load by themselves
# and sky130_procs.tcl sources); the symbol's R= text is the total (one segment x ns / mult)
# and an `ns=` text shows only when ns is not 1; the property form has a hover text on
# ns, a computed R row and an "Import split" checkbox (a placeholder: import_split=true
# on the instance, read by nothing yet). The form side goes through three hooks of the
# cell form (src/property_form.tcl): field_tips, field_bools, field_readouts.
#
#   RS0  the symbol population is derived (glob), not listed, and is not empty
#   RS1  every symbol: ns=1 in the template, edit_form=sky130_res, a format that loads
#        sky130_res.tcl from the symbol's own library directory when the helper is not
#        defined and then calls it behind an `info commands` guard, an R= text that uses
#        @ns, and the ns text; and that file is where each symbol's format looks for it
#   RS2  ns=1 netlists the one line the symbol wrote before ns existed
#   RS3  an instance with no ns token (a sheet saved before the change) netlists as RS2
#   RS4  ns=10: ten chained instances, body pin on each, both end nets kept, nine
#        internal nets
#   RS5  a two-pin (metal) resistor at ns=3: three instances, no body pin
#   RS6  ns that is not a whole number >= 1 is not netlisted as a plausible single
#        segment: a comment line with the reason, then the device once with its model
#        name prefixed ns_not_expanded__ (no model file defines it: the simulator stops)
#   RS7  the symbol texts: no ns text at ns=1, `ns=10` at 10; R at ns=10 is ten times
#        R at ns=1, and R at mult=2 is half
#   RS8  sky130_res::total_r, the form's R row, agrees with the symbol's own R= text and
#        answers nothing for a field that is not a plain number
#   RS9  the instance form's bool rows for a resistor include import_split, on-value true
#   RS10 the series proc on a BUSSED instance (the name arrives as a comma list): every
#        segment is written as a bussed line, names R1_<k>[bit], internal nets
#        R1_s<k>[bit], the end pins passed on as they came; an end pin that takes more
#        than one net per instance is refused with the ns_not_expanded__ model
#   RS11 import_split is not clutter (the user, 2026-11-16: "We don't want this showing
#        on the schematic"): no text of any resistor symbol names the token, and an
#        instance carrying import_split=true shows the same six texts and netlists the
#        same lines as one without it. (The SVG export is compared on the display arm,
#        row F4: without a display it writes no drawing at all.)
#   RS12 a session that has NOT sourced sky130_procs.tcl (the helper deleted from the
#        interpreter): netlisting an ns=10 instance loads the helper from the library
#        and writes the ten segments of RS4
#   RS13 the helper cannot be found either (the symbols copied into a library directory
#        with no sky130_res.tcl): an instance at ns=1, or with no ns token, netlists the
#        line of RS2; one at ns=10 gets a comment line and the ns_not_expanded__ model,
#        never a `?` line and never one plausible segment
#   RS14 fixed-width cells (res_high_po_0p69 ...): a cell is fixed-width by its name
#        exactly when its template does not declare W and its format does not netlist
#        it, and the width in the name is the one its own text shows; for such a cell
#        the form hook field_fixed answers one row, "W (fixed)" with the cell's width
#        and a hover text naming the custom-size cell; a custom-size cell answers none.
#        The user, 2026-11-16: a W listed under "Extra (undeclared)" looked adjustable
#        and changed nothing; show it as fixed, greyed, information only.
#   RS15 a stray W on a fixed-width cell changes neither the netlist line nor the R text
#   RS16 ns is kept a whole number >= 1 (the user, 2026-11-16: "enforce ns as natural
#        number"): the limits rule every sky130 resistor cell answers (derived over the
#        symbols) corrects 2.5 to 3, 0 and -3 to 1, a parameter name back to the value
#        before the edit (else 1), 007 and 1e1 to plain decimal, and leaves 7, a removed
#        token and an edit that did not touch ns alone; `xschem setprop` goes through it
#   RS17 a bussed instance R1[3:0] at ns=3 on a real sheet: twelve devices, one chain
#        per bit between that bit's two nets, the body net on each; a bussed metal
#        resistor with one end on a single net; ns=1 on the same sheet is the four
#        devices xschem always wrote
#
# The F rows drive the real form (`xschem edit_prop`) and need Tk:
#   F1   the form has an ns field, a hover text on its label, an R row and an unticked
#        Import split checkbox; OK with nothing edited leaves the instance string as it was
#   F2   typing ns=10 changes the R row to ten times its value
#   F3   ticking Import split and OK writes import_split=true and ns=10; unticking and
#        OK removes the token
#   F4   adding import_split=true to an instance changes no byte of the SVG export,
#        whose texts are the six of RS11. Control: changing ns does.
#   F5   the window itself: the same edit changes no pixel (`xschem window_snapshot`).
#        Control: changing ns does. A build without that test hook prints a `skip:`
#        line for this row.
#   F6   the real form on a fixed-width cell: a first row "W (fixed)" whose entry shows
#        the cell's width, disabled, with the hover text of RS14; W is not a field of
#        the form, a W token left on the instance is not listed under "Extra
#        (undeclared)" and OK leaves it as it was; a custom-size cell has no such row,
#        its W is an ordinary field and typing it moves the R row
#   F7   ns in the real form: 2.5 typed and the field left shows 3 with one CIW warning
#        line; a parameter name typed and the field left shows the value the form
#        opened with; 0 typed and OK pressed stores 1
#   F8   an instance with a real undeclared token: ns, the R row and Import split are
#        above the "Extra (undeclared)" heading, that token below it
# Without Tk the F band prints one `skip:` line; the display arm (dcases) runs it.
# Run: tests/headless/run_suites.sh --nogui test_sky130_res_series   (RS rows)
#      tests/headless/run_suites.sh test_sky130_res_series           (RS and F rows)

set fail 0 ; set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}
set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set repo [file normalize [file join $here .. ..]]
if {[catch {uplevel #0 [list source [file join $repo sky130A/sky130_procs.tcl]]} e]} {
  puts "note: sourcing sky130_procs.tcl: $e"
}
set scr [test_scratch sky130_res_series]

proc symf {cell} {
  global repo
  return [file join $repo sky130A xschem_libs sky130_fd_pr $cell symbol $cell.sym]
}
proc slurp {f} { set fd [open $f r] ; set s [read $fd] ; close $fd ; return $s }

# one instance of <cell> alone on a sheet with <props>; answers the netlist's device lines
set nl_n 0
# the device lines of the netlist of the sheet as it is
proc sheet_lines {} {
  global scr nl_n
  set ::netlist_dir $scr
  set name rs[incr nl_n].spice
  xschem set netlist_name $name
  xschem netlist
  set out {}
  foreach l [split [slurp [file join $scr $name]] \n] {
    if {[string match {*sky130_fd_pr__*} $l] || [string match {\* R*} $l]} { lappend out [string trim $l] }
  }
  return $out
}
proc device_lines {cell props {symfile {}}} {
  if {$symfile eq {}} { set symfile [symf $cell] }
  xschem clear force schematic
  xschem instance $symfile 0 0 0 0 $props
  return [sheet_lines]
}

# ---------------------------------------------------------------------------
set syms [lsort [glob -nocomplain [file join $repo sky130A xschem_libs sky130_fd_pr res_* symbol res_*.sym]]]
check {RS0 the resistor symbols are found by glob and there are some} [expr {[llength $syms] > 0}] 1

set bad {}
foreach f $syms {
  set s [slurp $f]
  set why {}
  if {![regexp -line {^ns=1"$} $s]}                       { lappend why template }
  if {![regexp -line {^edit_form=sky130_res$} $s]}         { lappend why edit_form }
  if {![regexp -line {^format="tcleval\(\[$} $s] || ![regexp -line {^  if \\\{\[info commands sky130_res_series\] ne } $s]
      || ![regexp -line {^    sky130_res_series \\\{ @ns \\\} } $s] || [regexp -all {ns_not_expanded__sky130_fd_pr__@model } $s] != 1} {
    lappend why format
  }
  if {[string first {catch \{source [file join [file dirname [file dirname [file dirname [abs_sym_path [string trim \{ @symref \}]]]]] sky130_res.tcl]\}} $s] < 0} {
    lappend why selfload
  }
  if {![file readable [file join [file dirname [file dirname [file dirname $f]]] sky130_res.tcl]]} { lappend why helperfile }
  if {![regexp -line {^T \{tcleval\(R=.*\* @ns / @mult } $s]} { lappend why rtext }
  if {![regexp -line {^T \{tcleval\(.*ns=@ns .*\)\} 15 27\.5 } $s]} { lappend why nstext }
  if {$why ne {}} { lappend bad [file tail $f] $why }
}
check "RS1 each of the [llength $syms] symbols carries ns in template, edit_form, a self-loading guarded format, R text and ns text, with sky130_res.tcl where its format looks" $bad {}

set P {name=R1 L=56.2 model=res_high_po_0p69 spiceprefix=X mult=1}
set l1 [device_lines res_high_po_0p69 "$P ns=1"]
check {RS2 ns=1 netlists one line, the one written before ns existed} \
  [list [llength $l1] [regexp {^XR1 \S+ \S+ \S+ sky130_fd_pr__res_high_po_0p69 L=56.2 mult=1$} [lindex $l1 0]]] {1 1}
check {RS3 an instance with no ns token netlists exactly as ns=1} [device_lines res_high_po_0p69 $P] $l1

set l10 [device_lines res_high_po_0p69 "$P ns=10"]
set names {} ; set los {} ; set his {} ; set bodies {} ; set tails {}
foreach l $l10 {
  lassign $l n lo hi b
  lappend names $n ; lappend los $lo ; lappend his $hi ; lappend bodies $b
  lappend tails [lrange $l 4 end]
}
set ends1 [lrange [lindex $l1 0] 1 3]
set want_names {} ; for {set k 1} {$k <= 10} {incr k} { lappend want_names XR1_$k }
set chain 1
for {set k 0} {$k < 9} {incr k} { if {[lindex $his $k] ne [lindex $los [expr {$k + 1}]]} { set chain 0 } }
check {RS4 ns=10: ten instances XR1_1..XR1_10 in a chain between the same two end nets, the body net on each, nine internal nets, the same model and params on each} \
  [list $names [lindex $los 0] [lindex $his end] [lsort -unique $bodies] $chain \
        [llength [lsort -unique [lrange $his 0 8]]] [lsort -unique $tails]] \
  [list $want_names [lindex $ends1 0] [lindex $ends1 1] [list [lindex $ends1 2]] 1 9 \
        [list {sky130_fd_pr__res_high_po_0p69 L=56.2 mult=1}]]

set m3 [device_lines res_generic_m1 {name=R2 W=1 L=4 model=res_generic_m1 mult=1 ns=3}]
set shape {}
foreach l $m3 { lappend shape [llength $l] [lindex $l 0] }
check {RS5 a two-pin metal resistor at ns=3: three instances, two nets each, chained} \
  [list $shape [expr {[lindex $m3 0 2] eq [lindex $m3 1 1]}] [expr {[lindex $m3 1 2] eq [lindex $m3 2 1]}]] \
  {{6 R2_1 6 R2_2 6 R2_3} 1 1}

set got {}
foreach v {2.5 NSEG 0 -3} {
  set l [device_lines res_high_po_0p69 "$P ns=$v"]
  lappend got [llength $l] [expr {[lindex $l 0] eq "* R1 : ns=$v is not a whole number >= 1"}] \
    [regexp {^XR1 \S+ \S+ \S+ ns_not_expanded__sky130_fd_pr__res_high_po_0p69 L=56.2 mult=1$} [lindex $l 1]]
}
check {RS6 ns of 2.5, a parameter name, 0 and -3: a comment line with the reason, then the device once with the undefined ns_not_expanded__ model} $got \
  {2 1 1 2 1 1 2 1 1 2 1 1}

# RS7 -- the symbol's own texts, as the sheet shows them
proc sym_text {cell re} {
  foreach l [split [slurp [symf $cell]] \n] {
    if {[string match {T \{*} $l] && [regexp $re $l]} {
      regexp {^T \{(.*)\} [-0-9.]+ [-0-9.]+ } $l -> t
      return [string map [list "\\\{" "\{" "\\\}" "\}"] $t]
    }
  }
  return {}
}
proc shown {cell props re} {
  xschem clear force schematic
  xschem instance [symf $cell] 0 0 0 0 $props
  return [xschem translate R1 [sym_text $cell $re]]
}
set RT {^T \{tcleval\(R=}
set NT {ns=@ns }
set r1  [shown res_high_po_0p69 "$P ns=1" $RT]
set r10 [shown res_high_po_0p69 "$P ns=10" $RT]
set r10m2 [shown res_high_po_0p69 {name=R1 L=56.2 model=res_high_po_0p69 spiceprefix=X mult=2 ns=10} $RT]
check {RS7a the ns text: nothing at ns=1, nothing with no ns token, ns=10 at 10} \
  [list [shown res_high_po_0p69 "$P ns=1" $NT] [shown res_high_po_0p69 $P $NT] [shown res_high_po_0p69 "$P ns=10" $NT]] \
  {{} {} ns=10}
check {RS7b the R text: 28.03k for one 56.2 um segment, 280.3k at ns=10, 140.2k at ns=10 mult=2} \
  [list $r1 $r10 $r10m2] {R=28.03k R=280.3k R=140.2k}

# RS8 -- the form's R row
set ::symbol [symf res_high_po_0p69]
check {RS8 the form's R row equals the symbol's R text and answers nothing for a parameter or a missing field} \
  [list [sky130_res::total_r {L 56.2 ns 10 mult 1}] [sky130_res::total_r {L 56.2 ns 10 mult 2}] \
        [sky130_res::total_r {L LEN ns 10 mult 1}] [sky130_res::total_r {L 56.2 mult 1}] \
        [sky130_res::total_r {L {[exit]} ns 1 mult 1}]] \
  {280.3k 140.2k {} {} {}}
set ::symbol [symf res_generic_m1]
check {RS8b the R row reads each symbol's own formula: res_generic_m1 W=1 L=4 ns=3} \
  [sky130_res::total_r {W 1 L 4 ns 3 mult 1}] 1.5

# RS9
xschem clear force schematic
xschem instance [symf res_high_po_0p69] 0 0 0 0 $P
set sch [slickprop::inst_schema [xschem getprop instance 0 cell::name]]
set row {}
foreach r $sch { if {[dict get $r tok] eq {import_split}} { set row [list [dict get $r label] [dict get $r on] [dict get $r widget]] } }
check {RS9 a resistor's form bool rows include Import split, written as true} \
  [list $row [slickprop::inst_owned [xschem getprop instance 0 cell::name]]] {{{Import split} true bool} import_split}

# RS10 -- a bussed instance, as the netlister hands it to the helper
set v [sky130_res_series { 2 } " **** spice_prefix X\nR1\[1\],R1\[0\] " { ?1 A[1],A[0] ?1 TOP ?1 VSS  } { sky130_fd_pr__res_high_po L=1 }]
set v2 [sky130_res_series { 2 } { R1 } { ?2 A[1],A[0] ?1 B ?1 VSS } { sky130_fd_pr__res_high_po L=1 }]
check {RS10 a bussed instance at ns=2 is written as two bussed segments (names R1_k[bit], internal nets R1_s1[bit], end pins as they came); an end pin with two nets per instance is refused with the ns_not_expanded__ model} \
  [list [split $v \n] [split $v2 \n]] \
  [list [list {**** spice_prefix X} {R1_1[1],R1_1[0] ?1 A[1],A[0] ?1 R1_s1[1],R1_s1[0] ?1 VSS  sky130_fd_pr__res_high_po L=1} \
              {**** spice_prefix X} {R1_2[1],R1_2[0] ?1 R1_s1[1],R1_s1[0] ?1 TOP ?1 VSS  sky130_fd_pr__res_high_po L=1}] \
        [list {* R1 : ns=2 on an end pin that takes more than one net per instance} \
              {R1 ?2 A[1],A[0] ?1 B ?1 VSS ns_not_expanded__sky130_fd_pr__res_high_po L=1}]]

# RS11 -- import_split draws nothing and netlists nothing
set naming {}
foreach f $syms {
  foreach l [split [slurp $f] \n] {
    if {[string match {T \{*} $l] && [string match *import_split* $l]} { lappend naming [file tail $f] }
  }
}
check "RS11a none of the [llength $syms] symbols has a text that names import_split" $naming {}
# every text of the symbol, as the sheet shows it for an instance with <props>, in file order
proc all_texts {cell props} {
  xschem clear force schematic
  xschem instance [symf $cell] 0 0 0 0 $props
  set out {}
  foreach l [split [slurp [symf $cell]] \n] {
    if {[regexp {^T \{(.*)\} [-0-9.]+ [-0-9.]+ [0-9] [0-9] } $l -> t]} {
      lappend out [xschem translate R1 [string map [list "\\\{" "\{" "\\\}" "\}"] $t]]
    }
  }
  return $out
}
set P10 "$P ns=10"
check {RS11b import_split=true on the instance: the texts the sheet shows are the six of the instance without it, and so is the netlist} \
  [list [all_texts res_high_po_0p69 "$P10 import_split=true"] \
        [expr {[device_lines res_high_po_0p69 "$P10 import_split=true"] eq [device_lines res_high_po_0p69 $P10]}]] \
  [list {B R1 {1 * 0.69 / 56.2} res_high_po_0p69 R=280.3k ns=10} 1]

# RS12 -- the helper not defined: the symbol loads it from its own library directory
set helper [file join $repo sky130A xschem_libs sky130_fd_pr sky130_res.tcl]
rename sky130_res_series {}
set gone [expr {[info commands sky130_res_series] eq {}}]
set sl10 [device_lines res_high_po_0p69 $P10]
set back [expr {[info commands sky130_res_series] ne {}}]
if {!$back} { uplevel #0 [list source $helper] }
check {RS12 with sky130_res_series deleted from the interpreter, netlisting an ns=10 instance loads it from the library and writes the ten segments of RS4} \
  [list $gone $back [expr {$sl10 eq $l10}] [llength $sl10]] {1 1 1 10}

# RS13 -- the helper cannot be found: copies of two symbols in a library with no sky130_res.tcl
set nolib [file join $scr nolib]
foreach c {res_high_po_0p69 res_generic_m1} {
  file mkdir [file join $nolib $c symbol]
  file copy -force [symf $c] [file join $nolib $c symbol $c.sym]
}
set nsym  [file join $nolib res_high_po_0p69 symbol res_high_po_0p69.sym]
set nsymm [file join $nolib res_generic_m1 symbol res_generic_m1.sym]
rename sky130_res_series {}
set np1  [device_lines res_high_po_0p69 "$P ns=1" $nsym]
set np0  [device_lines res_high_po_0p69 $P $nsym]
set np10 [device_lines res_high_po_0p69 $P10 $nsym]
set npm  [device_lines res_generic_m1 {name=R2 W=1 L=4 model=res_generic_m1 mult=1 ns=3} $nsymm]
set still_gone [expr {[info commands sky130_res_series] eq {}}]
uplevel #0 [list source $helper]
check {RS13 with no sky130_res.tcl in the symbol's library and the helper not defined: ns=1 and no ns token netlist the one line of RS2; ns=10 and a metal ns=3 get a comment line and the ns_not_expanded__ model} \
  [list [expr {$np1 eq $l1}] [expr {$np0 eq $l1}] [llength $np10] \
        [expr {[lindex $np10 0] eq {* R1 : ns=10 needs sky130_res_series from sky130_fd_pr/sky130_res.tcl, which could not be loaded}}] \
        [regexp {^XR1 \S+ \S+ \S+ ns_not_expanded__sky130_fd_pr__res_high_po_0p69 L=56.2 mult=1$} [lindex $np10 1]] \
        [llength $npm] [regexp {^R2 \S+ \S+ ns_not_expanded__sky130_fd_pr__res_generic_m1 W=1 L=4$} [lindex $npm 1]] \
        $still_gone [expr {[info commands sky130_res_series] ne {}}]] \
  {1 1 2 1 1 2 1 1 1}

# RS14 -- fixed-width cells
set cls {} ; set nfixed 0 ; set ncustom 0
foreach f $syms {
  set s [slurp $f]
  set fw [sky130_res::fixed_w $f]
  set fixed [expr {$fw ne {}}]
  if {$fixed} { incr nfixed } else { incr ncustom }
  set declares_w [regexp -line {^W=} $s]
  set nets_w [expr {[string first {W=@W} $s] >= 0}]
  set tw {}
  regexp -line {^T \{@mult \* ([0-9.]+) / @L\}} $s -> tw
  if {$fixed == $declares_w || $fixed == $nets_w || ($fixed && $fw ne $tw)} { lappend cls [file tail $f] }
}
check "RS14a over the [llength $syms] symbols a cell is fixed-width by name exactly when it neither declares nor netlists W, and its name's width is the one its text shows; both kinds exist" \
  [list $cls [expr {$nfixed > 0}] [expr {$ncustom > 0}]] {{} 1 1}
set ::symbol [symf res_xhigh_po_1p41]
set ff [sky130_res::field_fixed]
set ::symbol sky130_fd_pr/res_high_po_0p69
set fr [sky130_res::field_fixed]
set ::symbol [symf res_high_po]
set fc [sky130_res::field_fixed]
# a fixed row as {count tok label value}, and its hover text; a missing row or key answers
# empty rather than raising, so a cell that stops declaring the row is a FAIL line
proc frow {rows} {
  set r [lindex $rows 0]
  set o [list [llength $rows]]
  foreach k {tok label value} { lappend o [expr {[dict exists $r $k] ? [dict get $r $k] : {}}] }
  return $o
}
proc ftip {rows} {
  set r [lindex $rows 0]
  return [expr {[dict exists $r tip] ? [dict get $r tip] : {}}]
}
check {RS14b a fixed-width cell answers one fixed row, W (fixed) with the cell's width and a hover text naming the custom-size cell, by path and by library reference; a custom-size cell answers none} \
  [list [frow $ff] [string match {*fixed at 1.41 um*use res_xhigh_po.} [ftip $ff]] \
        [frow $fr] [string match {*fixed at 0.69 um*use res_high_po.} [ftip $fr]] $fc \
        [info commands ::sky130_res::field_labels]] \
  [list {1 W {W (fixed)} 1.41} 1 {1 W {W (fixed)} 0.69} 1 {} {}]

# RS15
set PX {name=R1 L=20 model=res_xhigh_po_1p41 spiceprefix=X mult=1}
check {RS15 a stray W=5 on a fixed-width cell: the netlist line and the R text are those of the instance without it} \
  [list [expr {[device_lines res_xhigh_po_1p41 "$PX W=5"] eq [device_lines res_xhigh_po_1p41 $PX]}] \
        [llength [device_lines res_xhigh_po_1p41 $PX]] \
        [shown res_xhigh_po_1p41 "$PX W=5" $RT] [shown res_xhigh_po_1p41 $PX $RT]] {1 1 R=28.37k R=28.37k}

# RS16 -- ns is a count
set norule {}
foreach f $syms {
  set cell [file rootname [file tail $f]]
  set d [devlim::spec $cell $cell]
  set rule {}
  if {[llength $d]} { foreach r [dict get $d rules] { if {[lindex $r 0] eq {ns}} { set rule $r } } }
  if {$rule ne {ns 1 {} {} count}} { lappend norule $cell }
}
set fetrule {}
set d [devlim::spec nfet_01v8 nfet_01v8]
if {[llength $d]} { foreach r [dict get $d rules] { if {[lindex $r 0] eq {ns}} { set fetrule $r } } }
proc cnt {typed {before 10}} {
  set old "name=R1 L=56.2 model=res_high_po_0p69 spiceprefix=X mult=1 ns=$before"
  set new [xschem subst_tok $old ns $typed]
  lassign [devlim::corrections R1 res_high_po_0p69 res_high_po_0p69 $old $new $new] out fixes
  return [list [xschem get_tok $out ns] [llength $fixes]]
}
set o25 {name=R1 L=56.2 model=res_high_po_0p69 spiceprefix=X mult=1 ns=2.5}
set nL [xschem subst_tok $o25 L 20]
set o10 {name=R1 L=56.2 model=res_high_po_0p69 spiceprefix=X mult=1 ns=10}
set gone [xschem subst_tok $o10 ns <NULL>]
check "RS16a each of the [llength $syms] resistor cells answers the count rule for ns and a FET does not; 2.5 -> 3, 2.4 -> 2, 0 and -3 -> 1, a parameter name -> the value before the edit (else 1), 007 and 1e1 and +4 -> plain decimal, 7 untouched; a removed ns and an edit of L alone are left as they are; the sentence" \
  [list $norule $fetrule [cnt 2.5] [cnt 2.4] [cnt 0] [cnt -3] [cnt NSEG] [cnt NSEG x] [cnt 007] [cnt 1e1] [cnt +4] [cnt 7] \
        [lindex [devlim::corrections R1 res_high_po_0p69 res_high_po_0p69 $o10 $gone $gone] 1] \
        [lindex [devlim::corrections R1 res_high_po_0p69 res_high_po_0p69 $o25 $nL $nL] 1] \
        [lindex [devlim::corrections R1 res_high_po_0p69 res_high_po_0p69 $o10 [xschem subst_tok $o10 ns 2.5] [xschem subst_tok $o10 ns 2.5]] 1 0 2]] \
  [list {} {} {3 1} {2 1} {1 1} {1 1} {10 1} {1 1} {7 1} {10 1} {4 1} {7 0} {} {} \
        {R1 (res_high_po_0p69): ns=2.5 must be a whole number >= 1; ns set to 3}]
xschem clear force schematic
xschem instance [symf res_high_po_0p69] 0 0 0 0 $P10
set ::devlim::last {}
xschem setprop instance R1 ns 2.5
set sp1 [list [xschem getprop instance 0 ns] $::devlim::last]
xschem setprop instance R1 ns NSEG
set sp2 [xschem getprop instance 0 ns]
set ::devlim::last {}
xschem setprop instance R1 ns 12
check {RS16b xschem setprop goes through the rule: ns 2.5 is stored as 3 with the sentence, a parameter name goes back to 3, and 12 is stored as typed with nothing said} \
  [list $sp1 $sp2 [xschem getprop instance 0 ns] $::devlim::last] \
  [list [list 3 [list {R1 (res_high_po_0p69): ns=2.5 must be a whole number >= 1; ns set to 3}]] 3 12 {}]

# RS17 -- a bussed instance on a real sheet
set labsym [file join $repo xschem_library devices lab_pin.sym]
proc bus_sheet {ns} {
  global labsym
  xschem clear force schematic
  xschem instance [symf res_high_po_0p69] 0 0 0 0 "name=R1\[3:0\] L=56.2 model=res_high_po_0p69 spiceprefix=X mult=1 ns=$ns"
  xschem instance $labsym 0 -30 0 0 {name=l1 lab=A[3:0]}
  xschem instance $labsym 0 30 0 0 {name=l2 lab=B[3:0]}
  xschem instance $labsym -20 0 0 0 {name=l3 lab=VSS}
  xschem instance [symf res_generic_m1] 200 0 0 0 "name=R2\[1:0\] W=1 L=4 model=res_generic_m1 mult=1 ns=[expr {$ns == 1 ? 1 : 2}]"
  xschem instance $labsym 200 -30 0 0 {name=l4 lab=TOP}
  xschem instance $labsym 200 30 0 0 {name=l5 lab=C[1:0]}
  return [lsort [sheet_lines]]
}
set T {sky130_fd_pr__res_high_po_0p69 L=56.2 mult=1}
set TM {sky130_fd_pr__res_generic_m1 W=1 L=4}
set want3 {} ; set want1 {}
foreach b {3 2 1 0} {
  lappend want3 "XR1_1\[$b\] B\[$b\] R1_s1\[$b\] VSS $T" "XR1_2\[$b\] R1_s1\[$b\] R1_s2\[$b\] VSS $T" "XR1_3\[$b\] R1_s2\[$b\] A\[$b\] VSS $T"
  lappend want1 "XR1\[$b\] B\[$b\] A\[$b\] VSS $T"
}
foreach b {1 0} {
  lappend want3 "R2_1\[$b\] C\[$b\] R2_s1\[$b\] $TM" "R2_2\[$b\] R2_s1\[$b\] TOP $TM"
  lappend want1 "R2\[$b\] C\[$b\] TOP $TM"
}
check {RS17 a bussed R1[3:0] at ns=3 netlists twelve devices, one chain per bit between that bit's nets with the body net on each, and a bussed metal R2[1:0] at ns=2 with one end on a single net four; at ns=1 the sheet is the six devices xschem always wrote} \
  [list [expr {[bus_sheet 3] eq [lsort $want3]}] [llength $want3] [expr {[bus_sheet 1] eq [lsort $want1]}] [llength $want1]] {1 16 1 6}

# ---------------------------------------------------------------------------
set f_rows {F1 F2 F3 F4 F5 F6 F7 F8}
set f_ran 0
if {[catch {winfo exists .}]} {
  puts "skip: [join $f_rows {, }] -- the instance property form is a Tk dialog and\
 this arm has no Tk; the display arm (dcases) runs them"
} else {
  set f_ran 1
  proc settle {{n 6}} { for {set i 0} {$i < $n} {incr i} { update idletasks; update } }
  proc close_form {} {
    catch {while {[winfo exists .dialog]} { catch {slickprop::cancel}; catch {destroy .dialog}; update }}
  }
  proc form_on {cell props} {
    close_form
    xschem clear force schematic
    xschem instance [symf $cell] 0 0 0 0 $props
    xschem set_modify 0
    xschem unselect_all
    xschem select instance 0
    xschem edit_prop
    settle
    return [winfo exists .dialog]
  }
  proc ent {tok} { return $::slickprop::cur(entry,$tok) }
  # the label widget of <tok>'s row: same row index, .l instead of .e
  proc lab {tok} { regsub {\.e([0-9]+)$} [ent $tok] {.l\1} w ; return $w }
  proc r_row {} { return [[lindex $::slickprop::cur(readouts) 0 0] cget -text] }
  proc type_into {tok v} {
    set e [ent $tok]
    focus -force $e ; settle
    $e delete 0 end ; $e insert 0 $v
    event generate $e <KeyRelease> -keysym 0
    settle
  }

  set up [form_on res_high_po_0p69 $P]
  set tip [expr {[winfo exists [lab ns]] ? [bind [lab ns] <Enter>] : {}}]
  set before [xschem getprop instance 0]
  set r_at_1 [r_row]
  check {F1a the form opens with an ns field showing the default as a placeholder, a hover text on its label, an R row and an unticked Import split} \
    [list $up [winfo class [ent ns]] [slickprop::field_value ns] $::slickprop::cur(default,ns) \
          [string match {*Number of series segments*} $tip] $r_at_1 \
          [winfo class [ent import_split]] $::slickprop::chk(import_split)] \
    {1 Entry {} 1 1 28.03k Checkbutton 0}
  .dialog.fb.ok invoke
  settle
  check {F1b OK with nothing edited leaves the instance string as it was and the sheet unmodified} \
    [list [expr {[xschem getprop instance 0] eq $before}] [xschem get modified]] {1 0}

  form_on res_high_po_0p69 $P
  type_into ns 10
  set r_at_10 [r_row]
  type_into mult 2
  check {F2 typing ns=10 shows 280.3k in the R row, then mult=2 shows 140.2k} [list $r_at_10 [r_row]] {280.3k 140.2k}
  type_into mult 1

  [ent import_split] invoke
  settle
  .dialog.fb.ok invoke
  settle
  set after_tick [list [xschem getprop instance 0 ns] [xschem getprop instance 0 import_split]]
  xschem unselect_all ; xschem select instance 0 ; xschem edit_prop ; settle
  set reopened $::slickprop::chk(import_split)
  [ent import_split] invoke
  settle
  .dialog.fb.ok invoke
  settle
  check {F3 ticking Import split and OK writes ns=10 and import_split=true; reopened it is ticked; unticking and OK removes the token and keeps ns} \
    [list $after_tick $reopened [xschem getprop instance 0 ns] [xschem getprop instance 0 import_split]] \
    {{10 true} 1 10 {}}
  close_form

  # F4 -- the SVG export.  F5 -- the window's own pixels (needs the window_snapshot test hook)
  proc svg_now {tag} {
    global scr
    set f [file join $scr $tag.svg]
    xschem print svg $f
    return [slurp $f]
  }
  proc svg_texts {svg} {
    set out {}
    foreach {m t} [regexp -all -inline {<text[^>]*>([^<]*)} $svg] { lappend out [string trim $t] }
    return [lsort $out]
  }
  set has_snap 1
  if {[catch {xschem window_snapshot free} e] && [string match {*invalid command*} $e]} { set has_snap 0 }
  proc snap {slot} { if {$::has_snap} { xschem window_snapshot take $slot } }
  xschem clear force schematic
  xschem instance [symf res_high_po_0p69] 0 0 0 0 $P10
  xschem unselect_all
  xschem zoom_full
  xschem redraw ; settle
  snap 0
  set svg0 [svg_now f4a]
  xschem setprop instance R1 import_split true
  xschem redraw ; settle
  snap 1
  set svg1 [svg_now f4b]
  set has [xschem getprop instance 0 import_split]
  xschem setprop instance R1 ns 11
  xschem redraw ; settle
  snap 2
  set svg2 [svg_now f4c]
  check {F4 adding import_split=true to an instance changes no byte of the SVG export, whose texts are the six; changing ns from 10 to 11 does change it} \
    [list $has [expr {$svg1 eq $svg0}] [svg_texts $svg1] [expr {$svg2 eq $svg1}]] \
    [list true 1 [lsort {B R1 {1 * 0.69 / 56.2} res_high_po_0p69 R=280.3k ns=10}] 0]
  if {$has_snap} {
    check {F5 adding import_split=true to an instance changes no pixel of the window; changing ns from 10 to 11 does} \
      [list [lindex [xschem window_snapshot diff 0 1] 0] [expr {[lindex [xschem window_snapshot diff 1 2] 0] > 0}]] {0 1}
    catch {xschem window_snapshot free}
  } else {
    puts "skip: F5 -- this build has no `xschem window_snapshot` test hook; F4 compared the SVG export"
  }
  xschem set_modify 0

  proc grow {w} { return [dict get [grid info $w] -row] }

  # F6 -- a fixed-width cell: W is shown as fixed; a stray W token is neither offered nor touched
  form_on res_xhigh_po_1p41 "$PX W=5"
  set fx $::slickprop::cur(fixed)
  lassign [lindex $fx 0] ftok flab fent
  # read through catch: with no fixed row there are no widgets to ask, and the row must
  # say so as a FAIL rather than end the suite
  if {[catch {
    list [llength $fx] $ftok [$flab cget -text] [$fent get] [$fent cget -state] [string match {*fixed at 1.41 um*use res_xhigh_po.*} [bind $flab <Enter>]] [expr {[grow $fent] < [grow [ent L]]}] [lsearch -exact $::slickprop::cur(tokens) W] [winfo exists [winfo parent $fent].xlbl] [r_row]
  } got6]} { set got6 "no fixed row ([llength $fx]): $got6" }
  check {F6a on a fixed-width cell the form's first row is "W (fixed)": a disabled entry showing the cell's 1.41, a hover text giving the fixed width and the custom-size cell; W is not a field, and the W=5 left on the instance is not listed under Extra} $got6 {1 W {W (fixed)} 1.41 disabled 1 1 -1 0 28.37k}
  set before [xschem getprop instance 0]
  .dialog.fb.ok invoke
  settle
  check {F6b OK on that form leaves the instance as it was, the leftover W=5 included} \
    [list [expr {[xschem getprop instance 0] eq $before}] [xschem getprop instance 0 W] [xschem get modified]] {1 5 0}
  form_on res_high_po {name=R1 W=1 L=1 model=res_high_po spiceprefix=X mult=1}
  set cust [list [llength $::slickprop::cur(fixed)] [winfo class [ent W]] [[ent W] cget -state] \
                 [expr {[lsearch -exact $::slickprop::cur(tokens) W] >= 0}] [r_row]]
  type_into W 2
  check {F6c a custom-size cell has no fixed row: its W is an ordinary field, and typing W=2 halves the R row} \
    [list $cust [r_row]] {{0 Entry normal 1 695.5} 347.7}
  close_form
  xschem set_modify 0

  # F7 -- ns is kept a whole number in the form
  set ::rs_ciw {}
  set rs_had_ciw [llength [info commands ::ciw_echo]]
  if {$rs_had_ciw} { rename ::ciw_echo ::rs_ciw_echo_saved }
  proc ::ciw_echo {line {tag {}}} { if {[string match {warning: *} $line]} { lappend ::rs_ciw $line } }
  # leave <tok>'s field as Tab does (the `all` binding for Tab runs exactly this)
  proc tab_out {tok} { tk::TabToWindow [tk_focusNext [ent $tok]] ; settle }
  form_on res_high_po_0p69 $P10
  type_into ns 2.5
  tab_out ns
  set a7 [list [[ent ns] get] $::rs_ciw]
  set ::rs_ciw {}
  type_into ns NSEG
  tab_out ns
  set b7 [list [[ent ns] get] [llength $::rs_ciw]]
  set ::rs_ciw {}
  type_into ns 0
  .dialog.fb.ok invoke
  settle
  set c7 [list [xschem getprop instance 0 ns] [llength $::rs_ciw]]
  check {F7 in the form: ns=2.5 typed and the field left shows 3 with one CIW warning; a parameter name typed and the field left shows 10, the value the form opened with; 0 typed and OK pressed stores 1 with one warning} \
    [list $a7 $b7 $c7] \
    [list [list 3 [list {warning: R1 (res_high_po_0p69): ns=2.5 must be a whole number >= 1; ns set to 3}]] {10 1} {1 1}]
  close_form
  rename ::ciw_echo {}
  if {$rs_had_ciw} { rename ::rs_ciw_echo_saved ::ciw_echo }
  xschem set_modify 0

  # F8 -- the cell's own rows sit above the Extra heading
  form_on res_high_po_0p69 "$P10 foo=bar"
  set fr8 [winfo parent [ent foo]]
  set xrow [expr {[winfo exists $fr8.xlbl] ? [grow $fr8.xlbl] : -1}]
  check {F8 with a real undeclared token on the instance, ns, the R row and Import split are above the "Extra (undeclared)" heading and that token below it} \
    [list [winfo exists $fr8.xlbl] [expr {[grow [ent ns]] < $xrow}] \
          [expr {[grow [lindex $::slickprop::cur(readouts) 0 0]] < $xrow}] \
          [expr {[grow [ent import_split]] < $xrow}] [expr {[grow [ent foo]] > $xrow}]] {1 1 1 1 1}
  close_form
  xschem set_modify 0
}

xschem clear force schematic
test_scratch_drop $scr
set floor 23
if {$f_ran} { set floor [expr {$has_snap ? 34 : 33}] }
if {$npass + $fail < $floor} {
  puts "FAIL: RSFLOOR ran [expr {$npass + $fail}] checks, below the floor of $floor"
  incr fail
}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
}
puts "RESULT: $fail FAILED ($npass passed)"
exit 1
