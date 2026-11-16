# sky130_res.tcl -- the Tcl half of the sky130_fd_pr/res_* resistor symbols:
# series segments (ns) at netlist time, and their Edit-Properties form extras.
# User request 2026-11-16. Proc definitions, and one registration at the end (the
# rule that keeps `ns` a whole number in the property form); nothing else.
#
# It lives in the library directory, beside the cells, so the symbols find it
# themselves. Every res_* symbol's format= begins
#   if {[info commands sky130_res_series] eq {}} { catch {source <library dir>/sky130_res.tcl} }
# with the library directory worked out from the instance's own symbol (@symref), so
# an `ns` > 1 expands in any session that can find the symbol: this workarea, another
# project's rc, a headless runner that sources no PDK file at all.
# sky130A/sky130_procs.tcl sources it too, so the workarea's form has the extras from
# the first edit. Fence: tests/headless/test_sky130_res_series.tcl.

# Series segments. Every sky130_fd_pr/res_* symbol carries `ns` (template default 1)
# and its format= calls
#   sky130_res_series { @ns } { @spiceprefix@name } { @pinlist } { <model and params> }
# (the spaces inside the braces are needed: xschem ends a @token only at whitespace or
# a backslash).
# The model subcircuits have no series parameter and one cannot be folded into L: each
# segment has its own two contact ends and its own mismatch draw. So ns > 1 netlists ns
# instances in a chain, <name>_1 .. <name>_<ns>, joined by the internal nets
# <name>_s1 .. <name>_s<ns-1>. The first two pins are the resistor's ends; any further
# pin (the body, B) goes to every segment. ns = 1 returns what the symbols produced
# before ns existed.
# What arrives here is the netlister's intermediate line, not the final one: the name
# may be preceded by a `**** spice_prefix X` line and every net by its `?<n>` multiplicity
# marker; both are kept so the netlister's own later pass finishes the job.
#
# An ns that cannot be honoured is NOT netlisted as one plausible segment (the sheet
# would show one resistance and the simulator use another). The device is written once
# with its model name prefixed `ns_not_expanded__`, which no model file defines, under a
# comment line giving the reason, so the simulator stops on that line; the reason also
# goes to stderr. That is an ns that is not a whole number >= 1 in plain decimal (a
# parameter name, an expression, 2.5): the property form and `xschem setprop` correct
# such a value when it is entered (sky130_res_limits below), so this is what a hand-edited
# sheet gets.
#
# A BUSSED instance (R1[3:0]) arrives as xschem hands every bussed instance on: the name
# as a comma list (R1[3],R1[2],R1[1],R1[0]) and each pin as `?1 <net>[,<net>...]`, which
# the netlister's later pass (spice.awk) unrolls into one device per name, taking each
# pin's nets in turn. So every segment is written the same way: a comma list of names,
# R1_<k>[3],R1_<k>[2],.. and, for the internal nodes, a comma list of nets
# R1_s<k>[3],R1_s<k>[2],.. (the suffix goes before the first bracket). The two end pins
# are passed on as they came, so a bus, a single net or anything else xschem accepts
# there connects exactly as it does at ns = 1.
# If this file cannot be loaded at all (a library copied without it), the symbols'
# format= still netlists an instance at ns = 1 as it always did, and writes one at any
# other ns with the same `ns_not_expanded__` prefix.
proc sky130_res_series {ns name pins tail} {
  set name [string trim $name]
  set tail [string trim $tail]
  # one pad space each side came from the format's own braces; the rest is @pinlist's
  regsub {^ } $pins {} pins
  regsub { $} $pins {} pins
  set one "$name $pins $tail"
  set n [string trim $ns]
  # a format evaluated before its tokens were substituted: nothing to decide yet
  if {$n eq {} || $n eq {1} || [string index $n 0] eq {@}} { return $one }
  set inst [lindex [split $name \n] end]
  set head [string range $name 0 end-[string length $inst]]
  # the pins: `?<m> <nets>` pairs, <m> the number of nets one instance takes there
  set p [regexp -all -inline {\S+} $pins]
  set why {}
  if {![regexp {^[1-9][0-9]*$} $n]} {
    set why "ns=$n is not a whole number >= 1"
  } elseif {[llength $p] < 4 || [llength $p] % 2} {
    set why "ns=$n needs two end pins"
  } elseif {[lindex $p 0] ne {?1} || [lindex $p 2] ne {?1}} {
    set why "ns=$n on an end pin that takes more than one net per instance"
  }
  if {$why ne {}} {
    puts stderr "sky130_res_series: $inst: $why; netlisted with an undefined model (ns_not_expanded__...) so the simulator stops there"
    return "* $inst : $why\n$name $pins ns_not_expanded__$tail"
  }
  set a "?1 [lindex $p 1]"
  set b "?1 [lindex $p 3]"
  set body {}
  foreach {m nets} [lrange $p 4 end] { append body "$m $nets " }
  # one name per bit of a bussed instance; a plain instance is a list of one
  set bits {}
  foreach nm [split $inst ,] {
    if {![regexp {^([^\[]*)(\[.*)$} $nm -> base idx]} { set base $nm ; set idx {} }
    lappend bits $base $idx
  }
  set lines {}
  for {set k 1} {$k <= $n} {incr k} {
    set names {} ; set los {} ; set his {}
    foreach {base idx} $bits {
      lappend names ${base}_$k$idx
      lappend los   ${base}_s[expr {$k - 1}]$idx
      lappend his   ${base}_s$k$idx
    }
    set lo [expr {$k == 1  ? $a : "?1 [join $los ,]"}]
    set hi [expr {$k == $n ? $b : "?1 [join $his ,]"}]
    lappend lines "${head}[join $names ,] $lo $hi $body $tail"
  }
  return [join $lines \n]
}

# The Edit-Properties form of the sky130 resistors: every sky130_fd_pr/res_* symbol
# declares edit_form=sky130_res, and src/property_form.tcl asks this namespace for the
# hover texts, the "Import split" checkbox and the computed R row.
# doc/claude/specs/cell_custom_form.md.
namespace eval sky130_res {}

# The width, in microns, that a FIXED-WIDTH resistor cell has (res_high_po_0p69 -> 0.69),
# or {} for a cell whose W is the designer's (res_high_po, res_generic_*, res_iso_pw).
# Read off the cell name, which is how the PDK itself names the fixed flavours: their
# model wrappers take only l and mult and wire w themselves, and their symbols neither
# declare W nor netlist it. <symbol> is a lib/cell reference or a path to the .sym.
proc sky130_res::fixed_w {symbol} {
  if {[regexp {_([0-9])p([0-9][0-9])$} [file rootname [file tail $symbol]] -> a b]} { return $a.$b }
  return {}
}

# A fixed-width cell shows its width in the form as information: a greyed "W (fixed)"
# row with the cell's width (the user, 2026-11-16). Older sheets often still carry a
# W= token on such a cell (the shipped sky130 test sheets do); the symbol does not
# declare it and the netlist never uses it, so the form does not offer it for editing
# and leaves it as it is.
proc sky130_res::field_fixed {} {
  if {![info exists ::symbol] || [set w [sky130_res::fixed_w $::symbol]] eq {}} { return {} }
  regsub {_[0-9]p[0-9][0-9]$} [file rootname [file tail $::symbol]] {} base
  return [list [list tok W label {W (fixed)} value $w \
    tip "This cell's width is fixed at $w um.\nFor another width use $base."]]
}

proc sky130_res::field_tips {} {
  return {
    ns   {Number of series segments (a whole number, 1 or more)}
    mult {Number of parallel copies}
    L    {Length of one segment, in microns}
    W    {Width of one segment, in microns}
    import_split {Placeholder for layout import; has no effect yet}
  }
}

# A PLACEHOLDER (it will be read by the layout import later): import_split=true on the
# instance when ticked, no token when not. Nothing reads it today, the netlist included.
proc sky130_res::field_bools {} {
  return {{tok import_split label {Import split} on true}}
}

proc sky130_res::field_readouts {} {
  return {{label R cmd sky130_res::total_r tip {Total resistance: one segment x ns / mult}}}
}

# The R= text of the symbol being edited ($::symbol), as written in its .sym file:
#   R=[to_eng [ev { <one segment> * @ns / @mult }]]
# Read from the file so the 22 symbols' formulas live in one place each.
proc sky130_res::r_text {symbol} {
  variable rtext
  if {[info exists rtext($symbol)]} { return $rtext($symbol) }
  set t {}
  catch {
    set fd [open [abs_sym_path $symbol] r]
    set body [read $fd]
    close $fd
    if {[regexp -line {^T \{tcleval\((R=.*)\)\} } $body -> t]} {
      set t [string map [list "\\\{" "\{" "\\\}" "\}"] $t]
    }
  }
  set rtext($symbol) $t
  return $t
}

# The form's R row: the symbol's own R= text evaluated on the values in the form.
# A field holding anything but a plain number (a parameter name, an expression) gives
# no value: nothing here evaluates text typed into the form.
proc sky130_res::total_r {vals} {
  if {![info exists ::symbol]} { return {} }
  set t [sky130_res::r_text $::symbol]
  if {$t eq {}} { return {} }
  foreach tok [regexp -all -inline {@[A-Za-z_][A-Za-z0-9_]*} $t] {
    set name [string range $tok 1 end]
    if {![dict exists $vals $name]} { return {} }
    set v [string trim [dict get $vals $name]]
    if {![string is double -strict $v]} { return {} }
    set map($tok) $v
  }
  set t [string map [array get map] $t]
  if {[catch {subst -novariables $t} r]} { return {} }
  regsub {^R=} $r {} r
  return $r
}

# `ns` is a count: the property form and `xschem setprop` keep it a whole number >= 1
# (devlim, src/property_form.tcl: on leaving the field, on OK/Apply, on setprop), saying
# so in the CIW. <cell> is the bare cell name, as devlim hands it to every provider.
proc sky130_res_limits {cell model} {
  set m [string map {sky130_fd_pr__ {}} $model]
  if {![regexp {^res_(generic_(po|nd|pd|l1|m[1-5])|x?high_po(_[0-9]p[0-9][0-9])?|iso_pw)$} $m]
      && ![regexp {^res_(generic_(po|nd|pd|l1|m[1-5])|x?high_po(_[0-9]p[0-9][0-9])?|iso_pw)$} $cell]} {
    return {}
  }
  return [dict create unit {} rules [list [list ns 1 {} {} count]]]
}
if {[info procs ::devlim::register] ne {}} { devlim::register sky130_res_limits }
