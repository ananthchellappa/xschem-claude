# test_ase_terminal_pick_1724.tcl — Select On Design: a click on an instance
# pin queues that terminal's current.  Issue 1724.
#
# Issue  doc/claude/issues/1724-select-on-design-cannot-queue-a-device-terminal-current-a-click-on-an-instance-pin-queues-the-voltage-of-the-pins-net.md
# Code   src/ase_window.tcl, the section "Terminal currents" below
#        ase::ui::sod_click: sod_terminal_at (is the click on a device pin, and
#        on which one), sod_term_name (what the simulator calls the current into
#        it), sod_terminal_resolve (may it be named here, and as what),
#        sod_terminal_pick (queue it, or say why not).
#        src/ase.tcl, for band TPV: ase::probe_pick_report (the pick's word
#        about a simulator that cannot save the current),
#        ase::probe_absent_groups (Direct Plot's reasons), ase::probe_said_keep,
#        ase::probe_said_clear, ase::probe_said_for (what the last run's
#        report said, about which results and for which session),
#        ase::sim_session_view and ase::probe_session_verdict (the program a
#        run of the CLICKING session starts, and what is known of it), and
#        what ase::probe_cure_carry keeps over an edit of the registry.
#
# THE PICK NEVER NETLISTS AND THIS SUITE NEVER RUNS A SIMULATOR.  A terminal's
# name comes from the live sheet -- the instance's netlist format expanded with
# a marker in place of each pin's net -- and, for a subcircuit call, from a
# `.subckt` header.  Every header here is text this file writes: a deck in the
# scratch directory for the netlist ASE-L "last made", and a small model
# library laid out as a corner file is -- sections, a cell file included by a
# relative path, a second library pulled in by section.  (One row, TPX18, reads
# the in-tree sky130 library instead and says SKIPPED when it is not there.)
# Whether the simulator then writes the vector under that name is the deck
# suite's question (test_ase_probe_deck_1724), which holds every real-simulator
# row.
#
# TWO KINDS OF KEY.  `k` is no session at all: the mode records are armed by
# hand and every lookup that needs a session finds nothing, which is the state
# of a scripted pick.  The rows about a session's model files, its netlist, its
# results and its place in the hierarchy use real sessions (ase::new_session)
# on cells of a library registered in scratch.
#
# THREE SHEETS.  tp_top carries the rows written with the feature; tp_rev those
# that came out of its review; tp_geo holds geometry the other two do not have
# (a net label lying over a stub, blocks abutting on facing edges, a source
# abutting a resistor, the stock sources with more or fewer than two pins on
# their netlist line, a shipped symbol whose pin names repeat, a block whose
# box is off its origin in every placement, a one-pin device on a resistor's
# pin, standing after the resistor and standing before it, and symbols whose
# pin names end in a backslash).  A band that has rows on more than one runs
# as two or more `group`s under the band's name, each ending back on tp_top.
# Row TPR4x has a small sheet of its own beside them (tp_note), as band TPU
# has (tp_odd).
#
# BANDS
#   TP0  the binary (the first row of the file) and the fixture
#   TPC  what a device pin is: the netlister's ignore rule, the symbol types
#        that only carry a net, `only_toplevel` below the session's design
#   TPR  range and winner: the 10-unit bound, the pin radius, the pin's own
#        square zoomed far in, label against device, several devices on one
#        point and the side of it the cursor stands on (also for blocks whose
#        pins are all on the facing edge, with equal and with unequal pin
#        sets, under a title that reaches over the neighbour, for a symbol
#        with two pins of one name, for a one-pin device that stands later
#        on the sheet than the device it shares a point with and for one
#        that stands earlier, for symbols whose pin names end in a
#        backslash, and for one with plain pin names beside another pin
#        attribute that ends in one), a wire under the cursor and a wire a
#        pixel beside it
#   TPD  the click the canvas binding makes, with no coordinates: the pin test
#        reads the raw cursor and not the snapped one, also where no pixel's
#        centre is on the wire
#   TPN  names of primitive elements, and the picks that are refused
#   TPX  names of subcircuit calls: the symbol's own block, the header in the
#        netlist (warm, and its cards once it is stale), in a `device_model`,
#        in the model files, the caution and its remedy -- for no header,
#        for several that differ and for one that is too short -- ports that
#        are numbers, the bit dialog
#   TPH  picks made below the top of the hierarchy; a click in a window that
#        shows another design; a block opened in a window or a tab of its own
#   TPP  Direct Plot: only what the last run's results hold, the branch
#        current that stands in on the pin of a source, and what the click
#        says when that trace is not the pin's own current -- its negative on
#        the source's second pin, not that pin's current at all on any other
#   TPV  what the session's simulator can save: at a pick of a row flavour,
#        the one sentence about a simulator already known to save no terminal
#        current below the top level, with which registered one can -- once
#        per click, starting no program; and in Direct Plot, why the results
#        do not hold a terminal and what to do next -- the last run's
#        simulator cannot save it, the last run gave another reason, the row
#        is set and the results do not hold it, or nothing is known.  The
#        simulator a click speaks of is its own session's, whatever is in
#        force in the process
#   TPM  the notices, and the prompt that names the pin a click would take
#        while the pointer is in the window the mode is on
#   TPK  call shapes other suites stub, the cue a Direct Plot pick puts on its
#        pin, and the resolver other gestures are to build on
#   TPU  a pin whose name the deck cannot carry is refused at the click
#   TPZ  (the last row) no message box was asked for in the run beside the
#        engine's own about the one odd bus name of band TPU
#   TPL  the mode's lifecycle, with the canvas stood in for: entering ends a
#        Calculator pick first and asks the Results window's pick mode to take
#        the canvas again, the canvas slots seized and handed back, a
#        paused mode coming back up on another canvas, the canvas going away,
#        what the mode reports it holds (the list src/cmdmode.tcl reads), the
#        mode taking the canvas again after a mode was ended underneath it,
#        its prompt timer writing nothing while a mode sits on top of it, a
#        paused mode's release writing nothing (also the Calculator's and the
#        Results window's), the press script handing the engine its own
#        position, and the canvas looked up for a design in a tab
#
# THE PIN RADIUS IS NEVER A LITERAL.  It is 12 * zoom * tk-scaling schematic
# units and both factors differ between the two arms, so every band that needs
# a radius SETS the zoom, reads the radius back (tp_radius) and carries a leg
# showing its probe points stand where the row says they do.
#
# Runs on both arms; nothing here needs a display.  From the repo ROOT:
#   tests/headless/run_suites.sh --nogui test_ase_terminal_pick_1724
#   AUDIT_DISPLAY=private tests/headless/run_suites.sh test_ase_terminal_pick_1724

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# A row must FAIL, not throw: everything that can raise goes through pcall, and
# a band that raises anyway is scored by `group` as one counted failure.
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        incr ::fail
    }
}
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set scratch [test_scratch ase_terminal_pick_1724]

# ===========================================================================
# TP0 — the binary, before anything else
# ===========================================================================
check "TP0a this binary has the pin probe: `xschem pin_at 0 0` does not raise (a stale build answers `invalid command` here and every row below would be about it)" \
    [catch {xschem pin_at 0 0}] 0

# The names below fold: the suite must not inherit a case mode from whoever's
# ~/.xschem/ase_simulators is live (issue 1377).
test_sim_registry_isolate
check "ISO1377 the suite runs against an empty simulator registry, not the one in ~/.xschem" \
    [test_sim_registry_state] {0 {} {} path}

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
proc wfile {path body} { set f [open $path w]; puts $f $body; close $f }
proc tp_scale {} { return [expr {[info commands tk] ne {} ? [tk scaling] : 1.0}] }
# find_closest_pin()'s radius in schematic units, read NOW
proc tp_radius {} { return [expr {12.0 * [xschem get zoom] * [tp_scale]}] }
# set the zoom so that radius is r (to rounding); answers the radius read back
proc tp_set_radius {r} {
    xschem origin - - [expr {$r / (12.0 * [tp_scale])}]
    return [tp_radius]
}
proc tp_dist {x1 y1 x2 y2} { return [expr {hypot($x1 - $x2, $y1 - $y2)}] }
# `a < b` for two numbers, 0 when either is not one
proc tp_less {a b} {
    return [expr {[string is double -strict $a] && [string is double -strict $b] && $a < $b ? 1 : 0}]
}
# NO ANSWER OF THE CODE UNDER TEST IS INDEXED BARE: a broken build can hand
# back an error text or a dict without the key, and a raise would abort the
# band and take its remaining rows out of the verdict.  One key of a dict, or
# the word NOKEY.
proc tp_get {d key} {
    if {[catch {dict get $d $key} v]} { return NOKEY }
    return $v
}
# the point of a pin, from a door that is not pin_at: instance_pin_coord
# answers {name x y}
proc tp_pin {inst pin} { return [lrange [pcall xschem instance_pin_coord $inst name $pin] 1 2] }
# does the pin probe list pin `pin` of instance `inst` at (x,y)?  1/0
proc tp_listed {x y inst pin} {
    foreach r [pcall xschem pin_at $x $y -all] {
        if {[lindex $r 2] eq $inst && [lindex $r 3] eq $pin} { return 1 }
    }
    return 0
}
# the index of the instance called `name` on the current sheet, -1 if none
proc tp_inst {name} {
    set n [xschem get instances]
    for {set i 0} {$i < $n} {incr i} {
        if {[xschem getprop instance $i name] eq $name} { return $i }
    }
    return -1
}

# stand a proc in for `name`, remembering the real one when there is one;
# tp_unstub puts it back.  A build that lacks the proc gets the stand-in all
# the same, so the row that uses it fails on what it asserts and does not
# abort its band on a rename.
proc tp_stub {name arglist body} {
    if {[llength [info commands $name]]} { rename $name ${name}__tp_real }
    proc $name $arglist $body
}
proc tp_unstub {name} {
    catch {rename $name {}}
    if {[llength [info commands ${name}__tp_real]]} { rename ${name}__tp_real $name }
}

# ---- pick harness: the two queues, the bit dialog and the notice sink are
# ---- replaced by recorders, so no ASE window and no Tk is needed
set ::queued {} ; set ::qkinds {} ; set ::qtokens {} ; set ::notices {} ; set ::ntags {} ; set ::dlg {}
set ::dlg_answer all
rename ::ase::ui::dp_queue ::ase::ui::tp_real_dp_queue
proc ase::ui::dp_queue {key ex {kind {}} {token {}}} { lappend ::queued $ex ; lappend ::qkinds $kind ; lappend ::qtokens $token }
proc ase::ui::sod_queue {key ex} { lappend ::queued $ex }
# the dialog's answer: `all` every bit, `none` Cancel, else a list of indices
# into the bits it was handed, in the order to return them
proc ase::ui::bus_dialog {key token bits} {
    lappend ::dlg [list $key $token $bits]
    if {$::dlg_answer eq {all}} { return $bits }
    if {$::dlg_answer eq {none}} { return {} }
    set out {}
    foreach i $::dlg_answer { lappend out [lindex $bits $i] }
    return $out
}
if {[info commands ciw_echo] ne {}} { rename ciw_echo real_ciw_echo }
proc ciw_echo {msg args} { lappend ::notices $msg ; lappend ::ntags [lindex $args 0] }
# THE MESSAGE BOX.  On a display the engine asks Tk for a MODAL box when a name
# does not expand as a bus, and a modal box nobody answers stops the suite for
# good.  A recorder stands in for it on both arms: it answers `ok` at once and
# keeps what it was asked.  Row TPU6 reads what the engine asked about the one
# such name of the fixture, and the suite's last row that nothing else in the
# whole run asked for a box -- so a box that appears later is a named red and
# not a stall.  ::tp_box_tpu6 is the stretch of the record TPU6's legs made.
set ::tp_boxes {} ; set ::tp_box_tpu6 {0 0}
if {[llength [info commands ::tk_messageBox]]} { rename ::tk_messageBox ::tp_real_tk_messageBox }
proc ::tk_messageBox {args} { lappend ::tp_boxes $args ; return ok }
# the text a recorded box was asked to show, or the whole request when it has none
proc tp_box_text {box} {
    if {[catch {dict get $box -message} m]} { return $box }
    return $m
}
# the boxes recorded from number `from` on, judged: {their count is what this
# arm allows -- none where there is no display, at most one where there is --
# and the texts of those that are NOT the engine's notice about `name`}
proc tp_boxes_about {from name} {
    set new [lrange $::tp_boxes $from end]
    set most [expr {[info commands winfo] ne {} ? 1 : 0}]
    set odd {}
    foreach b $new {
        if {[string first "Syntax error in identifier expansion: $name\n" [tp_box_text $b]] != 0} { lappend odd [tp_box_text $b] }
    }
    return [list [expr {[llength $new] <= $most ? 1 : 0}] $odd]
}

# arm the mode records of `key` by hand, as the entry points would
proc tp_mode {key mode} {
    array unset ase::ui::sod $key,*
    array set ase::ui::sod [list $key,flavor {save 1 plot 0} $key,mode $mode $key,count 0]
}
# one click: what it queued.  `args` are the coordinates, or nothing for the
# click the canvas binding makes.
proc tp_click {key args} {
    set ::queued {} ; set ::qkinds {} ; set ::qtokens {} ; set ::notices {} ; set ::ntags {} ; set ::dlg {}
    set r [pcall ase::ui::sod_click $key {*}$args]
    if {[string match ERR:* $r]} { return $r }
    return $::queued
}
proc tp_at {key inst pin} { return [tp_click $key {*}[tp_pin $inst $pin]] }

# the sentences
set TP_MISS "ase: nothing to queue there — click a wire or a net label for a voltage, an instance pin for its terminal current, or a voltage source/ammeter for its current"
# is `notices` exactly ONE refusal that names the instance and the pin and ends
# with the ammeter alternative?  Answers {count shape}.
proc tp_refused {inst pin} {
    set shape 0
    foreach m $::notices {
        if {[string match "ase: cannot name the terminal current of $inst pin $pin — *; place an ammeter (ammeter.sym) in series" $m]} { set shape 1 }
    }
    return [list [llength $::notices] $shape]
}

# ===========================================================================
# the fixture: one library, written as text into scratch
# ===========================================================================
set tplib [file join $scratch tplib]
file mkdir $tplib
set SYMHEAD "v {xschem version=3.4.8RC file_version=1.3}\nG {}"
set SYMTAIL "V {}\nS {}\nF {}\nE {}\nL 4 -40 -20 40 -20 {}\nL 4 -40 20 40 20 {}"
set SCHHEAD "v {xschem version=3.4.8RC file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nF {}\nE {}"
set PINS_AB "B 5 -42.5 -2.5 -37.5 2.5 {name=A dir=inout}\nB 5 37.5 -2.5 42.5 2.5 {name=Y dir=inout}"

# a block xschem netlists itself: the callee's ports ARE these pins
wfile [file join $tplib tp_blk.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
$SYMTAIL
$PINS_AB"
wfile [file join $tplib tp_blk.sch] "$SCHHEAD
C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=A}
C {devices/opin.sym} 200 0 0 0 {name=p2 lab=Y}
C {devices/res.sym} 400 0 0 0 {name=R1 value=1k}"

# a block with a bus pin and an extra node on each side of the pin list
wfile [file join $tplib tp_bus.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @VCC @pinlist @VSS @symname\"
template=\"name=x1 VCC=VCC VSS=VSS\"}
$SYMTAIL
B 5 -42.5 -2.5 -37.5 2.5 {name=D\[1:0\] dir=in}
B 5 37.5 -2.5 42.5 2.5 {name=Q dir=out}"
wfile [file join $tplib tp_bus.sch] "$SCHHEAD
N 200 -30 200 -80 {lab=ntv}
C {devices/res.sym} 0 0 0 0 {name=R1 value=1k}
C {devices/vsource.sym} 200 0 0 0 {name=VT value=1 only_toplevel=true}
C {devices/lab_pin.sym} 200 -80 0 0 {name=l1 sig_type=std_logic lab=ntv}"

# a block whose template carries a spiceprefix (issue 0488) -- on its SECOND
# line, as a template of any length is laid out -- and a block in it
wfile [file join $tplib tp_pfx.sym] "$SYMHEAD
K {type=subcircuit
format=\"@spiceprefix@name @pinlist @symname\"
template=\"name=x1
spiceprefix=X\"}
$SYMTAIL
$PINS_AB"
wfile [file join $tplib tp_pfx.sch] "$SCHHEAD
C {devices/res.sym} 0 0 0 0 {name=R1 value=1k}
C {tp_blk.sym} 300 0 0 0 {name=xin}"

# a PDK-style wrapper: the symbol's pins are M P B, the subcircuit it calls
# names its ports otherwise (the model library below)
wfile [file join $tplib tp_fres.sym] "$SYMHEAD
K {type=resistor
format=\"@spiceprefix@name @pinlist @model L=@L\"
template=\"name=R1 model=fake_res spiceprefix=X L=1\"}
$SYMTAIL
B 5 -2.5 27.5 2.5 32.5 {name=M dir=inout}
B 5 -2.5 -32.5 2.5 -27.5 {name=P dir=inout}
B 5 -22.5 -2.5 -17.5 2.5 {name=B dir=inout}"

# a two-pin primitive whose instances bring their own format
wfile [file join $tplib tp_two.sym] "$SYMHEAD
K {type=resistor
format=\"@name @pinlist @value\"
template=\"name=R1 value=1k\"}
$SYMTAIL
$PINS_AB"
# ... with its middle pin kept out of the netlist
wfile [file join $tplib tp_ign.sym] "$SYMHEAD
K {type=resistor
format=\"@name @pinlist @value\"
template=\"name=R1 value=1k\"}
$SYMTAIL
B 5 -42.5 -2.5 -37.5 2.5 {name=A dir=inout}
B 5 -2.5 17.5 2.5 22.5 {name=NC dir=inout spice_ignore=1}
B 5 37.5 -2.5 42.5 2.5 {name=Y dir=inout}"
# ... with a pin name used twice (the second `A` is pin 1), then a third pin
wfile [file join $tplib tp_dup.sym] "$SYMHEAD
K {type=resistor
format=\"@name @pinlist @value\"
template=\"name=R1 value=1k\"}
$SYMTAIL
B 5 -42.5 -2.5 -37.5 2.5 {name=A dir=inout}
B 5 -2.5 17.5 2.5 22.5 {name=A dir=inout}
B 5 37.5 -2.5 42.5 2.5 {name=Y dir=inout}"
# ... with a two-bit pin ahead of a scalar one
wfile [file join $tplib tp_wide.sym] "$SYMHEAD
K {type=resistor
format=\"@name @pinlist @value\"
template=\"name=R1 value=1k\"}
$SYMTAIL
B 5 -42.5 -2.5 -37.5 2.5 {name=D\[1:0\] dir=inout}
B 5 37.5 -2.5 42.5 2.5 {name=Q dir=inout}"
# ... with a format per netlisting mode
wfile [file join $tplib tp_fmt.sym] "$SYMHEAD
K {type=resistor
format=\"@name @@A @@Y @value\"
lvs_format=\"@name @@Y @@A @value\"
alt_format=\"@name gnd! @@Y @@A @value\"
template=\"name=R1 value=1k\"}
$SYMTAIL
$PINS_AB"
# ... ignored by its SYMBOL
wfile [file join $tplib tp_symign.sym] "$SYMHEAD
K {type=resistor
format=\"@name @pinlist @value\"
spice_ignore=true
template=\"name=R1 value=1k\"}
$SYMTAIL
$PINS_AB"
# blocks netlisted through a spice_sym_def.  The header's port ORDER is not
# the symbol's pin order, and one port is spelled in another case.
wfile [file join $tplib tp_sd.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"
spice_sym_def=\".subckt tp_sd q P N
.ends\"}
$SYMTAIL
B 5 -42.5 -2.5 -37.5 2.5 {name=N dir=inout}
B 5 -2.5 17.5 2.5 22.5 {name=P dir=inout}
B 5 37.5 -2.5 42.5 2.5 {name=Q dir=inout}"
set PINS_NPQ "B 5 -42.5 -2.5 -37.5 2.5 {name=N dir=inout}\nB 5 -2.5 17.5 2.5 22.5 {name=P dir=inout}\nB 5 37.5 -2.5 42.5 2.5 {name=Q dir=inout}"
# ... one whose header has a port that is no pin of the symbol
wfile [file join $tplib tp_sd2.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"
spice_sym_def=\".subckt tp_sd2 q P zz
.ends\"}
$SYMTAIL
$PINS_NPQ"
# ... one whose format names its pins one by one instead of `@pinlist`
wfile [file join $tplib tp_sd3.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @@Q @@N @@P @symname\"
template=\"name=x1\"
spice_sym_def=\".subckt tp_sd3 q P N
.ends\"}
$SYMTAIL
$PINS_NPQ"
# ... and one whose definition is a file that is not there
wfile [file join $tplib tp_sd4.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"
spice_sym_def=\".include tp_no_such_file_1724.cir\"}
$SYMTAIL
$PINS_NPQ"

# subcircuit symbols xschem does NOT write the body of
wfile [file join $tplib tp_prim.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
spice_primitive=true
template=\"name=x1\"}
$SYMTAIL
$PINS_AB"
wfile [file join $tplib tp_dsi.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
default_schematic=ignore
template=\"name=x1\"}
$SYMTAIL
$PINS_AB"

# one symbol per symbol TYPE that only carries a net, each with the format of
# a device, and a sheet holding one instance of each plus a control
set TP_NETTYPES {label ipin opin iopin show_label scope bus_tap noconn probe}
set tp_types_sch "$SCHHEAD"
set tp_tx 0
foreach t $TP_NETTYPES {
    wfile [file join $tplib tp_t_$t.sym] "$SYMHEAD
K {type=$t
format=\"@name @pinlist @value\"
template=\"name=R1 value=1k\"}
$SYMTAIL
$PINS_AB"
    append tp_types_sch "\nC {tp_t_$t.sym} $tp_tx 0 0 0 {name=T_$t value=1k}"
    incr tp_tx 200
}
append tp_types_sch "\nC {tp_two.sym} $tp_tx 0 0 0 {name=T_control value=1k}"
wfile [file join $tplib tp_types.sch] $tp_types_sch

# The top sheet.  Instance ORDER is part of the fixture where two pins share a
# point: R1 stands before R2, so R1's pin is the first pin_at answers there.
wfile [file join $tplib tp_top.sch] "$SCHHEAD
N 600 -30 600 -80 {lab=nm1}
N 800 -30 800 -80 {lab=nms}
N 1000 -30 1000 -80 {lab=nmo}
N 1600 -30 1600 -100 {lab=nd}
N 2600 -30 2600 -80 {lab=nlv}
N 3004 -30 3004 -80 {lab=NEAR}
N 3200 -30 3200 -80 {lab=nmt}
C {devices/res.sym} 0 0 0 0 {name=R1 value=1k}
C {devices/res.sym} 0 60 0 0 {name=R2 value=1k}
C {devices/vsource.sym} 200 0 0 0 {name=V1 value=1}
C {devices/ammeter.sym} 400 0 0 0 {name=Vmeas savecurrent=true spice_ignore=0}
C {devices/ammeter.sym} 600 0 0 0 {name=VM1 savecurrent=true spice_ignore=1}
C {devices/ammeter.sym} 800 0 0 0 {name=VMS savecurrent=true spice_ignore=short}
C {devices/ammeter.sym} 1000 0 0 0 {name=VMO savecurrent=true spice_ignore=open}
C {devices/nmos4.sym} 1200 0 0 0 {name=M1 model=nm w=1u l=1u del=0 m=1}
C {devices/npn.sym} 1400 0 0 0 {name=Q1 model=qn area=1 m=1}
C {devices/diode.sym} 1600 0 0 0 {name=D1 model=dn area=1}
C {tp_fres.sym} 1800 0 0 0 {name=RW model=fake_res spiceprefix=X L=1}
C {tp_blk.sym} 2000 0 0 0 {name=xb}
C {tp_blk.sym} 2200 0 0 0 {name=xswap format=\"@name @@Y @@A @symname\"}
C {tp_bus.sym} 2400 0 0 0 {name=xbus\[1:0\] VCC=VCC VSS=VSS}
C {devices/ammeter.sym} 2600 0 0 0 {name=VLV savecurrent=true spice_ignore=0 lvs_ignore=open}
C {devices/ammeter.sym} 2800 0 0 0 {name=VMF savecurrent=true spice_ignore=false}
C {devices/res.sym} 3000 0 0 0 {name=R3 value=1k}
C {devices/lab_pin.sym} 3004 -30 0 0 {name=lnr sig_type=std_logic lab=NEAR}
C {devices/ammeter.sym} 3200 0 0 0 {name=VMT savecurrent=true spice_ignore=TRUE}
C {devices/res.sym} 3400 0 0 0 {name=R9 value=1k}
C {devices/vsource.sym} 3600 0 0 0 {name=VTOP value=1 only_toplevel=true}
C {tp_pfx.sym} 3800 0 0 0 {name=SUB1}
C {tp_pfx.sym} 4000 0 0 0 {name=SUB2 spiceprefix=\"\"}
C {devices/res.sym} 4200 0 0 0 {name=RL value=1k lock=true}
C {devices/noconn.sym} 4400 0 0 0 {name=NC1}
C {tp_ign.sym} 4600 0 0 0 {name=RG value=1k}
C {tp_two.sym} 4800 0 0 0 {name=RD2 value=1k format=\"@name @@A @@Y @value
RD2b @@A @@Y @value\"}
C {tp_two.sym} 5000 0 0 0 {name=SU1 value=1k format=\"@name ctl @@A @@Y @value\"}
C {tp_two.sym} 5200 0 0 0 {name=HX1 value=1k format=\"#@name @@A @@Y @value\"}
C {tp_two.sym} 5400 0 0 0 {name=m7 value=1k format=\"#dx#@name @@A @@Y dnwell\"}
C {tp_two.sym} 5600 0 0 0 {name=R7 value=1k format=\"##@name @@A @@Y @value\"}
C {tp_two.sym} 5800 0 0 0 {name=CM1 value=1k format=\"*.alias @name\"}
C {tp_two.sym} 6000 0 0 0 {name=CE1 value=1k format=\"\"}
C {tp_fmt.sym} 6200 0 0 0 {name=RF1 value=1k}
C {tp_sd.sym} 6400 0 0 0 {name=x2sd}
C {tp_sd2.sym} 6600 0 0 0 {name=x3sd}
C {tp_symign.sym} 6800 0 0 0 {name=SYI value=1k}
C {tp_two.sym} 7000 0 0 0 {name=RIF value=1k format=\"@name @@Y @@A @value\"}
C {tp_fres.sym} 7200 0 0 0 {name=RSK model=sky130_fd_pr__res_xhigh_po_0p35 spiceprefix=X L=1}
C {tp_sd3.sym} 7400 0 0 0 {name=x4sd}
C {tp_sd4.sym} 7600 0 0 0 {name=x5sd}
C {tp_dup.sym} 7800 0 0 0 {name=RDU value=1k}
C {tp_wide.sym} 8000 0 0 0 {name=RB1 value=1k}
C {tp_two.sym} 8200 0 0 0 {name=RC1 value=1k format=\"@name @@A
+ @@Y @value\"}
C {tp_two.sym} 8400 0 0 0 {name=RI1 value=1k format=\"@name @@A @@Y @value
* note @@A
.ic @@A\"}
C {tp_two.sym} 8600 0 0 0 {name=RNP value=1k spiceprefix=X}
C {tp_prim.sym} 8800 0 0 0 {name=xprim}
C {tp_dsi.sym} 9000 0 0 0 {name=xdsi}
C {devices/res.sym} 9200 0 0 0 {name=RN1 value=1k}
C {devices/res.sym} 9206 0 0 0 {name=RN2 value=1k}
C {tp_two.sym} 9400 0 0 0 {name=XE1 value=1k format=\"@name VDDX @@A @@Y fake_ext\"}
C {tp_two.sym} 10200 0 0 0 {name=XE2 value=1k format=\"@name @@A @@Y fake_rel\"}
C {tp_two.sym} 10400 0 0 0 {name=XE3 value=1k format=\"@name @@A @@Y fake_dk\"}
C {tp_two.sym} 9600 0 0 0 {name=RA1 value=1k format=\"@name @#0:net_name @@A @@Y @value\"}
C {tp_two.sym} 9800 0 0 0 {name=RH1 value=1k format=\"@name @#1 @#A @value\"}
C {tp_wide.sym} 10000 0 0 0 {name=RB2 value=1k format=\"@name @#D\[1:0\] @#Q @value\"}
C {devices/lab_pin.sym} 600 -80 0 0 {name=l_nm1 sig_type=std_logic lab=nm1}
C {devices/lab_pin.sym} 800 -80 0 0 {name=l_nms sig_type=std_logic lab=nms}
C {devices/lab_pin.sym} 1000 -80 0 0 {name=l_nmo sig_type=std_logic lab=nmo}
C {devices/lab_pin.sym} 1600 -100 0 0 {name=l_nd sig_type=std_logic lab=nd}
C {devices/lab_pin.sym} 2600 -80 0 0 {name=l_nlv sig_type=std_logic lab=nlv}
C {devices/lab_pin.sym} 3200 -80 0 0 {name=l_nmt sig_type=std_logic lab=nmt}"

# ---------------------------------------------------------------------------
# A SECOND SHEET, tp_rev, for the rows that came out of the review of phase 1.
# It is a sheet of its own so the top sheet above, its instance count and every
# coordinate the earlier rows use stay exactly as they were.
#   R1-R2, R3-R4   two device pins joined by a 20-unit and by a 10-unit wire
#   R5 + l_on      a net label placed ON a device pin
#   M9             a three-terminal device whose format writes its source pin
#                  twice on ONE line
#   XDM XSD XSI XDF  calls whose `.subckt` header is in a `device_model`: the
#                  instance's, the symbol's, both (the instance's is the one the
#                  netlister writes), and one that only includes a file
#   RWN XE4 XW1    calls whose header is reached through the netlist ASE-L made:
#                  a file it `.include`s, a `.lib <file> <section>` card, and a
#                  header written in the netlist itself
#   XP1 XN1        calls into the session's model files: a header with
#                  `params:`, and one whose port names are numbers
#   R6 R7 R8       three devices with a pin on one point
#   R10            a device pin with a wire passing 3 units beside it
#   R11            a device pin with a wire leaving it sideways, along the edge
#                  of the symbol's box
#   VB[1:0]        a bus instance of a voltage source: two terminal vectors per pin
#   XT1 XD2        calls whose callee has TWO different headers in one place: in
#                  the netlist ASE-L made, and in the instance's `device_model`
# ---------------------------------------------------------------------------
wfile [file join $tplib tp_dm.sym] "$SYMHEAD
K {type=resistor
format=\"@name @pinlist fake_sdm\"
template=\"name=x1\"
device_model=\".subckt fake_sdm s0 s1
.ends\"}
$SYMTAIL
$PINS_AB"
wfile [file join $tplib tp_tri.sym] "$SYMHEAD
K {type=nmos
format=\"@name @@D @@G @@S @@S @model\"
template=\"name=M1 model=nm\"}
$SYMTAIL
B 5 -2.5 -32.5 2.5 -27.5 {name=D dir=inout}
B 5 -42.5 -2.5 -37.5 2.5 {name=G dir=in}
B 5 -2.5 27.5 2.5 32.5 {name=S dir=inout}"
set tp_rev [file join $tplib tp_rev.sch]
wfile $tp_rev "$SCHHEAD
N 0 30 0 50 {}
N 200 30 200 40 {}
N 2803 -60 2803 0 {}
N 3000 30 3050 30 {}
C {devices/res.sym} 0 0 0 0 {name=R1 value=1k}
C {devices/res.sym} 0 80 0 0 {name=R2 value=1k}
C {devices/res.sym} 200 0 0 0 {name=R3 value=1k}
C {devices/res.sym} 200 70 0 0 {name=R4 value=1k}
C {devices/res.sym} 400 0 0 0 {name=R5 value=1k}
C {devices/lab_pin.sym} 400 -30 0 0 {name=l_on sig_type=std_logic lab=ONPIN}
C {tp_tri.sym} 600 0 0 0 {name=M9 model=nm}
C {tp_two.sym} 800 0 0 0 {name=XDM value=1k format=\"@name @@A @@Y fake_dm\" device_model=\".subckt fake_dm dm0 dm1
.ends\"}
C {tp_dm.sym} 1000 0 0 0 {name=XSD}
C {tp_dm.sym} 1200 0 0 0 {name=XSI device_model=\".subckt fake_sdm i0 i1
.ends\"}
C {tp_two.sym} 1400 0 0 0 {name=XDF value=1k format=\"@name @@A @@Y fake_dmf\" device_model=\".include dm_inc.spice\"}
C {tp_fres.sym} 1600 0 0 0 {name=RWN model=fake_nl spiceprefix=X L=1}
C {tp_two.sym} 1800 0 0 0 {name=XE4 value=1k format=\"@name @@A @@Y fake_nlib\"}
C {tp_two.sym} 2000 0 0 0 {name=XP1 value=1k format=\"@name @@A @@Y fake_par\"}
C {tp_two.sym} 2200 0 0 0 {name=XN1 value=1k format=\"@name @@A @@Y fake_num\"}
C {tp_two.sym} 2400 0 0 0 {name=XW1 value=1k format=\"@name @@A @@Y fake_inl\"}
C {devices/res.sym} 2600 0 0 0 {name=R6 value=1k}
C {devices/res.sym} 2600 60 0 0 {name=R7 value=1k}
C {devices/res.sym} 2570 30 1 0 {name=R8 value=1k}
C {devices/res.sym} 2800 0 0 0 {name=R10 value=1k}
C {devices/res.sym} 3000 0 0 0 {name=R11 value=1k}
C {devices/vsource.sym} 3200 0 0 0 {name=VB\[1:0\] value=1}
C {tp_two.sym} 3400 0 0 0 {name=XT1 value=1k format=\"@name @@A @@Y fake_two\"}
C {tp_two.sym} 3600 0 0 0 {name=XD2 value=1k format=\"@name @@A @@Y fake_dm2\" device_model=\".subckt fake_dm2 da db
.ends
.subckt fake_dm2 dc dd
.ends\"}"

# ---------------------------------------------------------------------------
# A SHEET FOR BAND TPU, tp_odd: names the deck cannot carry as a terminal row.
#   xe             a block whose second port is called `Y=1`
#   R=9 R$8 R'7    devices whose own names hold an equals sign, a dollar sign
#                  and a single quote
#   V=2            a voltage source named with an equals sign
#   R5             a device with an ordinary name, the control
#   xq[1:0]        a two-bit bus instance of that block: two vectors per pin
# ---------------------------------------------------------------------------
wfile [file join $tplib tp_eq.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
$SYMTAIL
B 5 -42.5 -2.5 -37.5 2.5 {name=A dir=inout}
B 5 37.5 -2.5 42.5 2.5 {name=Y=1 dir=inout}"
wfile [file join $tplib tp_eq.sch] "$SCHHEAD
C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=A}
C {devices/opin.sym} 200 0 0 0 {name=p2 lab=Y=1}
C {devices/res.sym} 400 0 0 0 {name=R1 value=1k}"
set tp_odd [file join $tplib tp_odd.sch]
wfile $tp_odd "$SCHHEAD
C {tp_eq.sym} 0 0 0 0 {name=xe}
C {devices/res.sym} 200 0 0 0 {name=R=9 value=1k}
C {devices/res.sym} 400 0 0 0 {name=R\$8 value=1k}
C {devices/res.sym} 600 0 0 0 {name=R'7 value=1k}
C {devices/vsource.sym} 800 0 0 0 {name=V=2 value=1}
C {devices/res.sym} 1000 0 0 0 {name=R5 value=1k}
C {tp_eq.sym} 1200 0 0 0 {name=xq\[1:0\]}
C {devices/res.sym} 1400 0 0 0 {name=R=B\[1:0\] value=1k}"

# ---------------------------------------------------------------------------
# A THIRD SHEET, tp_geo: geometry the two sheets above do not have.
#   RS + l_stub    a device pin with a 20-unit stub and a net label at the
#                  stub's far end, turned so that its box lies back over the
#                  stub and the pin
#   xa|xb          two blocks with EVERY pin on the facing edge, placed pin on
#                  pin; the left block stands first on the sheet
#   xc|xd          the same pair with the right block first
#   Vab|RB         an ammeter's minus pin and a resistor's upper pin on one
#                  point, the ammeter first on the sheet
#   RC|Vcd         the same with the resistor first
#   RE|Vef         a resistor's lower pin on an ammeter's PLUS pin
#   x6sd           a block whose `spice_sym_def` header has one port for a
#                  call line of three nodes
#   xe|xf          a right-edge block of three pins abutting a left-edge block
#                  of FIVE, pins 1 to 3 on pins 1 to 3; the three-pin block
#                  first on the sheet
#   xg|xh          the same pair with the five-pin block first
#   xi|xj          the equal three-pin pair again, the right block's symbol
#                  carrying a title that reaches left over its neighbour
#   E1             the stock PWL-controlled voltage source: four pins, the
#                  third and fourth its controlling nodes
#   A1             the stock file source: its netlist line carries one of its
#                  two pins
#   xk xm          a left-edge block flipped (its pins are on the right) and a
#                  right-edge block turned a quarter (its pins are below)
#   xn|xo          two instances of the shipped examples/xcross.sym, whose pins
#                  repeat the names A and B on two edges: a right-edge pin of
#                  the first on a pin of the second, which is turned half round
#   xt<rot><flip>  a block with no text whose box is off its origin in x and in
#                  y, once in every rotation with and without a flip
#   RH|C9          a resistor lying on its side and, LATER on the sheet, the
#                  stock one-pin capacitor: its pin on the resistor's left pin,
#                  its lead going down
#   D9             the stock LED: two pins in line, its drawing to one side
#   C8|RJ          the same pair as RH|C9 with the capacitor EARLIER on the
#                  sheet than the resistor
#   RQ|RU          a two-pin device whose pin names end in a backslash, and a
#                  resistor's lower pin on its left pin
#   xw|RV          a block whose two ports end in a backslash, and a
#                  resistor's lower pin on its left pin
#   RK|CQ          a resistor lying on its side and a one-pin device whose pin
#                  name ends in a backslash, its lead going down
#   two wires      far from everything, so that reading EVERY wire of the sheet
#                  is told from reading one
# ---------------------------------------------------------------------------
# Four backslashes in a symbol's text are ONE in the pin's name: the file
# format halves them when the attribute string is read and the attribute
# reader halves them again.  TP_BSL is that name's last character as Tcl
# holds it.
set TP_BS4 [string repeat "\\" 4]
set TP_BSL "\\"
set PINS_BSL "B 5 -42.5 -2.5 -37.5 2.5 {name=A$TP_BS4 dir=inout}\nB 5 37.5 -2.5 42.5 2.5 {name=Y$TP_BS4 dir=inout}"
wfile [file join $tplib tp_bsl.sym] "$SYMHEAD
K {type=resistor
format=\"@name @pinlist @value\"
template=\"name=R1 value=1k\"}
$SYMTAIL
$PINS_BSL"
wfile [file join $tplib tp_bslblk.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
$SYMTAIL
$PINS_BSL"
wfile [file join $tplib tp_bslblk.sch] "$SCHHEAD
C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=A$TP_BS4}
C {devices/opin.sym} 200 0 0 0 {name=p2 lab=Y$TP_BS4}
C {devices/res.sym} 400 0 0 0 {name=R1 value=1k}"
# a one-pin device drawn below its pin, as the stock one-pin capacitor is
wfile [file join $tplib tp_bsl1.sym] "$SYMHEAD
K {type=capacitor
format=\"@name @pinlist 0 @value\"
template=\"name=C1 value=1p\"}
V {}\nS {}\nF {}\nE {}
L 4 0 0 0 30 {}\nL 4 -10 30 10 30 {}
B 5 -2.5 -2.5 2.5 2.5 {name=p$TP_BS4 dir=inout}"
set BLOCKBOX "L 4 -40 -40 40 -40 {}\nL 4 -40 40 40 40 {}\nL 4 -40 -40 -40 40 {}\nL 4 40 -40 40 40 {}"
wfile [file join $tplib tp_edger.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
V {}\nS {}\nF {}\nE {}
$BLOCKBOX
B 5 37.5 -22.5 42.5 -17.5 {name=P1 dir=inout}
B 5 37.5 -2.5 42.5 2.5 {name=P2 dir=inout}
B 5 37.5 17.5 42.5 22.5 {name=P3 dir=inout}"
wfile [file join $tplib tp_edgel.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
V {}\nS {}\nF {}\nE {}
$BLOCKBOX
B 5 -42.5 -22.5 -37.5 -17.5 {name=Q1 dir=inout}
B 5 -42.5 -2.5 -37.5 2.5 {name=Q2 dir=inout}
B 5 -42.5 17.5 -37.5 22.5 {name=Q3 dir=inout}"
wfile [file join $tplib tp_sd6.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @@Q @@N @@P @symname\"
template=\"name=x1\"
spice_sym_def=\".subckt tp_sd6 q
.ends\"}
$SYMTAIL
$PINS_NPQ"
# a left-edge block with FIVE pins, whose first three meet the three of the
# right-edge block above when the two abut: the two blocks' pin sets differ
wfile [file join $tplib tp_edgel5.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
V {}\nS {}\nF {}\nE {}
L 4 -40 -40 40 -40 {}\nL 4 -40 80 40 80 {}\nL 4 -40 -40 -40 80 {}\nL 4 40 -40 40 80 {}
B 5 -42.5 -22.5 -37.5 -17.5 {name=Q1 dir=inout}
B 5 -42.5 -2.5 -37.5 2.5 {name=Q2 dir=inout}
B 5 -42.5 17.5 -37.5 22.5 {name=Q3 dir=inout}
B 5 -42.5 37.5 -37.5 42.5 {name=Q4 dir=inout}
B 5 -42.5 57.5 -37.5 62.5 {name=Q5 dir=inout}"
# the three-pin left-edge block again, with a title that reaches far to the
# left of its body: over the neighbour it abuts
wfile [file join $tplib tp_edgelt.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
V {}\nS {}\nF {}\nE {}
$BLOCKBOX
B 5 -42.5 -22.5 -37.5 -17.5 {name=Q1 dir=inout}
B 5 -42.5 -2.5 -37.5 2.5 {name=Q2 dir=inout}
B 5 -42.5 17.5 -37.5 22.5 {name=Q3 dir=inout}
T {a title that reaches a long way to the left of this block} -400 -70 0 0 0.4 0.4 {}"
# the shipped symbol whose pin names repeat, as the examples library has it
file copy -force -- [file join $repo xschem_library examples xcross.sym] [file join $tplib xcross.sym]
# a block with NO text whose box lies off its origin in x and in y, so that its
# middle is somewhere else in every rotation and flip; its instances, one line
# each, in the order rotation 0 to 3 and within each first plain, then flipped
# (TP_ASYM_AT: each one's name and origin)
wfile [file join $tplib tp_asym.sym] "$SYMHEAD
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
V {}\nS {}\nF {}\nE {}
L 4 -10 -20 70 -20 {}\nL 4 -10 100 70 100 {}\nL 4 -10 -20 -10 100 {}\nL 4 70 -20 70 100 {}
B 5 67.5 -2.5 72.5 2.5 {name=A dir=inout}
B 5 67.5 37.5 72.5 42.5 {name=B dir=inout}"
set TP_ASYM_AT {}
set TP_ASYM_LINES {}
set tp_ax 5000
foreach rot {0 1 2 3} {
    foreach flip {0 1} {
        lappend TP_ASYM_AT xt$rot$flip $tp_ax 0
        lappend TP_ASYM_LINES "C {tp_asym.sym} $tp_ax 0 $rot $flip {name=xt$rot$flip}"
        incr tp_ax 300
    }
}
set tp_geo [file join $tplib tp_geo.sch]
wfile $tp_geo "$SCHHEAD
N 0 30 0 50 {lab=STUB}
N 1700 0 1720 0 {}
N 1700 40 1720 40 {}
C {devices/res.sym} 0 0 0 0 {name=RS value=1k}
C {devices/lab_pin.sym} 0 50 3 1 {name=l_stub sig_type=std_logic lab=STUB}
C {tp_edger.sym} 300 0 0 0 {name=xa}
C {tp_edgel.sym} 380 0 0 0 {name=xb}
C {tp_edgel.sym} 680 0 0 0 {name=xd}
C {tp_edger.sym} 600 0 0 0 {name=xc}
C {devices/ammeter.sym} 900 0 0 0 {name=Vab savecurrent=true spice_ignore=0}
C {devices/res.sym} 900 60 0 0 {name=RB value=1k}
C {devices/res.sym} 1100 60 0 0 {name=RC value=1k}
C {devices/ammeter.sym} 1100 0 0 0 {name=Vcd savecurrent=true spice_ignore=0}
C {devices/res.sym} 1300 -60 0 0 {name=RE value=1k}
C {devices/ammeter.sym} 1300 0 0 0 {name=Vef savecurrent=true spice_ignore=0}
C {tp_sd6.sym} 1500 0 0 0 {name=x6sd}
C {tp_edger.sym} 2000 0 0 0 {name=xe}
C {tp_edgel5.sym} 2080 0 0 0 {name=xf}
C {tp_edgel5.sym} 2380 0 0 0 {name=xh}
C {tp_edger.sym} 2300 0 0 0 {name=xg}
C {tp_edger.sym} 3000 0 0 0 {name=xi}
C {tp_edgelt.sym} 3080 0 0 0 {name=xj}
C {devices/vsource_pwl.sym} 3400 0 0 0 {name=E1 TABLE=\"1 0 2 3\"}
C {devices/filesource.sym} 3600 0 0 0 {name=A1 file=filesource.txt amploffset=0 amplscale=1}
C {tp_edgel.sym} 3800 0 0 1 {name=xk}
C {tp_edger.sym} 4000 0 1 0 {name=xm}
C {xcross.sym} 4400 0 0 0 {name=xn}
C {xcross.sym} 4560 -40 2 0 {name=xo}
[join $TP_ASYM_LINES \n]
C {devices/res.sym} 7600 0 1 0 {name=RH value=1k}
C {devices/parax_cap.sym} 7570 10 0 0 {name=C9 gnd=0 value=4f m=1}
C {devices/led.sym} 8000 0 0 0 {name=D9 model=led}
C {devices/parax_cap.sym} 8370 10 0 0 {name=C8 gnd=0 value=4f m=1}
C {devices/res.sym} 8400 0 1 0 {name=RJ value=1k}
C {tp_bsl.sym} 8800 0 0 0 {name=RQ value=1k}
C {devices/res.sym} 8760 -30 0 0 {name=RU value=1k}
C {tp_bslblk.sym} 9200 0 0 0 {name=xw}
C {devices/res.sym} 9160 -30 0 0 {name=RV value=1k}
C {devices/res.sym} 9600 0 1 0 {name=RK value=1k}
C {tp_bsl1.sym} 9570 0 0 0 {name=CQ value=1p}"

# ---------------------------------------------------------------------------
# A SHEET OF ITS OWN, tp_note, for row TPR4x: a two-pin device whose pins have
# plain names and ANOTHER attribute that ends in a backslash, and a resistor's
# lower pin on its left pin.
#   RN|RW at 0,0   RN's left pin A and the resistor's lower pin M
# Two backslashes in the symbol's text are ONE at the end of the pin's
# attribute string: the file format halves them when the string is read.  The
# engine's list of this symbol's pin attribute strings is then no list.  The
# pair is not on the third sheet because row TPP13e walks every instance of
# that sheet by that list.
# ---------------------------------------------------------------------------
set TP_BS2 [string repeat "\\" 2]
wfile [file join $tplib tp_bsnote.sym] "$SYMHEAD
K {type=resistor
format=\"@name @pinlist @value\"
template=\"name=R1 value=1k\"}
$SYMTAIL
B 5 -42.5 -2.5 -37.5 2.5 {name=A dir=inout note=x$TP_BS2}
B 5 37.5 -2.5 42.5 2.5 {name=Y dir=inout note=y$TP_BS2}"
set tp_note [file join $tplib tp_note.sch]
wfile $tp_note "$SCHHEAD
C {tp_bsnote.sym} 40 0 0 0 {name=RN value=1k}
C {devices/res.sym} 0 -30 0 0 {name=RW value=1k}"

# the model library a session names: a corner file with two sections.  The
# section the session asks for pulls in the cell file by a path relative to
# ITSELF and one section of a second library; the other section holds a
# `fake_res` with different ports, which only a reader that ignores sections
# would see.
set tpmod [file join $scratch models]
file mkdir [file join $tpmod cells]
set tp_lib [file join $tpmod fake.lib]
set tp_cells [file join $tpmod cells fake_cells.spice]
set tp_more [file join $tpmod fake_more.lib]
wfile $tp_lib "* a corner library
.lib tt
.include \"cells/fake_cells.spice\"
.lib \"fake_more.lib\" inner
.endl
.lib ff
.subckt fake_res wrong0 wrong1 wrong2
.ends
.endl"
# a second library, reached by a `.lib <file> <section>` line of the first
wfile $tp_more ".lib outer
.subckt fake_ext wrongx wrongy wrongz
.ends
.endl
.lib inner
.subckt fake_ext vddx in out
.ends
.endl"
set TP_CELLS "* the cells
.subckt fake_res r0 r1
+ sub l=1
r1 r0 r1 1k
.ends
.subckt fake_res2 q0 q1 qsub
.ends"
wfile $tp_cells $TP_CELLS

# the model files of the session on tp_rev.  An `includes` row names rev_top,
# which reaches its cell file through an `.inc` line; that file's header for
# fake_par carries `params:` after its ports.  A `models` row asks section `tt`
# of rev_sec, where a `.subckt` stands AFTER that section's `.endl` and before
# the next `.lib`.
set tp_rev_top [file join $tpmod rev_top.spice]
set tp_rev_sec [file join $tpmod rev_sec.lib]
wfile $tp_rev_top "* reached by an includes row
.inc \"cells/rev_cells.spice\"
.subckt fake_num 3 2 7 4 6
.ends"
wfile [file join $tpmod cells rev_cells.spice] ".subckt fake_par pa pb params: w=1 l=2
.ends"
set TP_REV_SEC ".lib tt
.subckt fake_sec s0 s1
.ends
.endl
.subckt fake_after x0 x1
.ends
.lib ff
.subckt fake_ff f0 f1
.ends
.endl"
wfile $tp_rev_sec $TP_REV_SEC
# ... and the files only the netlist ASE-L made for tp_rev names: one by an
# `.include` card, one by a `.lib <file> <section>` card whose other section
# declares the same name with other ports
set tp_nl_inc [file join $tpmod nl_inc.spice]
set tp_nl_sec [file join $tpmod nl_sec.lib]
wfile $tp_nl_inc ".subckt fake_nl nl0 nl1 nlsub\n.ends"
wfile $tp_nl_sec ".lib one
.subckt fake_nlib a0 a1
.ends
.endl
.lib two
.subckt fake_nlib wrong0 wrong1
.ends
.endl"
# ... and the file a `device_model` includes by a bare relative path, which is
# taken from the run directory
set tp_rev_run [file join $scratch runrev]
file mkdir $tp_rev_run
wfile [file join $tp_rev_run dm_inc.spice] ".subckt fake_dmf f0 f1\n.ends"
# the netlist "ASE-L last made" for tp_rev: a header of its own, two different
# headers under one name, and the two cards
set tp_rev_deck [file join $tp_rev_run tp_rev.spice]
set TP_REV_DECK "** sch_path: $tp_rev
.subckt fake_inl p q
.ends
.subckt fake_two a b
.ends
.subckt fake_two c d
.ends
.include $tp_nl_inc
.lib $tp_nl_sec one
.end"

# the 3-level hierarchy of tests/headless/fixtures/ase_hier, its top and mid
# copied into a registered library so a session can be bound to either
set fixdir [file join $here fixtures ase_hier]
set hierlib [file join $scratch hierlib]
file mkdir $hierlib
foreach n {ase_hier_top.sch ase_hier_mid.sch ase_hier_mid.sym} {
    file copy -force -- [file join $fixdir $n] $hierlib
}
wfile [file join $scratch library.defs] "DEFINE tplib $tplib
DEFINE hierlib $hierlib
DEFINE devices [file join $repo xschem_libs_newsym devices]"
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
# assigned UNQUALIFIED: the write trace that rebuilds the search path compares
# the name it is handed with the bare word (test_ase_hier_plot_0168's note)
set XSCHEM_LIBRARY_PATH "$tplib:$hierlib:$fixdir:$XSCHEM_LIBRARY_PATH"
set tp_top [file join $tplib tp_top.sch]

# the switches a row moves, so each band can put them back whatever happened
proc tp_switches_reset {} {
    set ::lvs_ignore 0 ; set ::lvs_netlist 0 ; set ::flat_netlist 0 ; set ::spiceprefix 1
    catch {xschem set format {}}
}
# back to the top sheet of the fixture, whatever a band left
proc tp_home {} {
    while {[xschem get currsch] > 0} { xschem go_back }
    if {[file normalize [xschem get schname]] ne [file normalize $::tp_top]} { xschem load $::tp_top }
    xschem unselect_all
}
# onto the second sheet (tp_rev); every band that goes there ends with tp_home
proc tp_rev_sheet {} {
    while {[xschem get currsch] > 0} { xschem go_back }
    if {[file normalize [xschem get schname]] ne [file normalize $::tp_rev]} { xschem load $::tp_rev }
    xschem unselect_all
}
# onto the sheet of band TPU (tp_odd); the band ends with tp_home
proc tp_odd_sheet {} {
    while {[xschem get currsch] > 0} { xschem go_back }
    if {[file normalize [xschem get schname]] ne [file normalize $::tp_odd]} { xschem load $::tp_odd }
    xschem unselect_all
}
# onto the third sheet (tp_geo); every band that goes there ends with tp_home
proc tp_geo_sheet {} {
    while {[xschem get currsch] > 0} { xschem go_back }
    if {[file normalize [xschem get schname]] ne [file normalize $::tp_geo]} { xschem load $::tp_geo }
    xschem unselect_all
}
# the name the netlister gives the net on pin `pin` of `inst`, as a voltage row
# spells it: no `#`, lower case.  A door that is not the click's (`xschem
# instance_net`), so a row can say which net a wire click must queue.
proc tp_vnet {inst pin} {
    return "v([string tolower [string trimleft [pcall xschem instance_net $inst $pin] #]])"
}
# the refusal sentence of the last click, without its fixed opening and ending:
# the reason alone, or NOREFUSAL
proc tp_why {inst pin} {
    set head "ase: cannot name the terminal current of $inst pin $pin — "
    set tail "; place an ammeter (ammeter.sym) in series"
    set tl [string length $tail]
    foreach m $::notices {
        if {[string first $head $m] == 0 && [string range $m end-[expr {$tl - 1}] end] eq $tail} {
            return [string range $m [string length $head] end-$tl]
        }
    }
    return NOREFUSAL
}
set TP_REMEDY "netlist the design from ASE-L (or run), or name the model file under Setup > Model Files, then pick again"
# what the sentence about a source's second pin ends with when that pin can be named
set TP_OWN "; to plot the pin's own current, pick it under Outputs > To Be Saved > Select On Design and run again"
# ...and what the sentence about a pin that is neither its first nor its second ends with when it cannot
set TP_AMM "; to plot that pin's current, place an ammeter (ammeter.sym) in series with it"
# what a click says in a window that does not show the session's design (here the top sheet's session)
set TP_ELSEWHERE "ase: nothing queued — this window shows neither the session's design 'tplib/tp_top' nor a sheet below it; switch to that design's window or tab and click there"

if {[catch {

# ===========================================================================
# TP0 — the fixture
# ===========================================================================
xschem load $tp_top
set TOPKEY [pcall ase::new_session tplib tp_top schematic]
set BUSKEY [pcall ase::new_session tplib tp_bus schematic]
set tp_nopins {}
for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {![llength [pcall xschem instance_pins $i]]} { lappend tp_nopins [pcall xschem getprop instance $i name] }
}
check "TP0b fixture: the top sheet loads with its instances, EVERY one of them resolved a symbol with pins (the names of those that did not are listed), and it is the registered cellview the top session is bound to at level 0" \
    [list [pcall xschem get instances] $tp_nopins \
          [pcall ase::design_of_path [file normalize $tp_top]] [pcall ase::ui::sod_base_level $TOPKEY]] \
    {62 {} {tplib tp_top schematic} 0}
tp_mode k outputs
tp_mode $TOPKEY outputs
tp_mode $BUSKEY outputs
# the sessions of the rows added after the review: one on the second sheet with
# model files of its own, and one bound to the prefixed block's own cell
set REVKEY [pcall ase::new_session tplib tp_rev schematic]
set PFXKEY [pcall ase::new_session tplib tp_pfx schematic]
tp_mode $REVKEY outputs
tp_mode $PFXKEY outputs
set tp_rst [pcall ase::session_state $REVKEY]
check "TP0c fixture: the session on the second sheet takes its run directory, an includes row and a models row with a section" \
    [list [pcall apply {{key st rd inc lib} {
               dict set st rundir $rd
               dict set st includes [list $inc]
               dict set st models [list [dict create file $lib section tt]]
               ase::session_update $key $st
               set now [ase::session_state $key]
               return [list [ase::state_get $now rundir] [ase::state_get $now includes] [ase::state_get $now models]]
           }} $REVKEY $tp_rst $tp_rev_run $tp_rev_top $tp_rev_sec]] \
    [list [list $tp_rev_run [list $tp_rev_top] [list [dict create file $tp_rev_sec section tt]]]]

# the session on the third sheet, with a run directory for its results
set GEOKEY [pcall ase::new_session tplib tp_geo schematic]
tp_mode $GEOKEY outputs
set tp_geo_run [file join $scratch rungeo]
file mkdir $tp_geo_run
check "TP0d fixture: the third sheet is a registered cellview with a session of its own, which takes its run directory" \
    [list [pcall ase::design_of_path [file normalize $tp_geo]] \
          [pcall apply {{key rd} {
               set st [ase::session_state $key]
               dict set st rundir $rd
               ase::session_update $key $st
               return [ase::state_get [ase::session_state $key] rundir]
           }} $GEOKEY $tp_geo_run]] \
    [list {tplib tp_geo schematic} $tp_geo_run]

# ===========================================================================
# TPC — what a device pin is
# ===========================================================================
group TPC {
    tp_switches_reset
    check "TPC1 a boolean attribute is read as the netlister reads it: true/on/yes in any case and any non-zero integer are 1; 0, false, off, no, the empty string, `short`, `open` and any other word are 0" \
        [lmap v {true TRUE On yes 1 -1 007 0 00 false off no {} short open maybe 1x} { pcall ase::ui::sod_bool $v }] \
        {1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0}
    check "TPC2 the instance is a device or it is not, per instance of the fixture: a plain resistor and the STOCK ammeter (spice_ignore=0) are; so is spice_ignore=false; spice_ignore 1, short, open and TRUE are not, nor a symbol that ignores itself, a net label, a noconn, a format that is a comment and a format set to nothing; an lvs_ignore attribute does not count while the switch is off" \
        [lmap n {R1 Vmeas VMF VM1 VMS VMO VMT SYI l_nd NC1 CM1 CE1 VLV} { pcall ase::ui::sod_inst_is_device k [tp_inst $n] }] \
        {1 1 1 0 0 0 0 0 0 0 0 0 1}
    xschem load [file join $tplib tp_types.sch]
    set got [lmap t $TP_NETTYPES { pcall ase::ui::sod_inst_is_device k [tp_inst T_$t] }]
    set ctl [pcall ase::ui::sod_inst_is_device k [tp_inst T_control]]
    tp_home
    check "TPC2b every symbol TYPE that only carries a net is no device, one instance per type on a sheet of its own -- each of those symbols has the format of a device, and the control beside them, the same format under type `resistor`, is one" \
        [list $TP_NETTYPES $got $ctl] \
        {{label ipin opin iopin show_label scope bus_tap noconn probe} {0 0 0 0 0 0 0 0 0} 1}
    set ::lvs_ignore 1
    set on [pcall ase::ui::sod_inst_is_device k [tp_inst VLV]]
    set ::lvs_ignore 0
    check "TPC3 with the `lvs_ignore` switch ON the instance carrying lvs_ignore=open is no device, and it is one again with the switch off" \
        [list $on [pcall ase::ui::sod_inst_is_device k [tp_inst VLV]]] {0 1}
    tp_set_radius 6
    check "TPC4 a click ON THE PIN of the stock ammeter queues its terminal current, and so does one with spice_ignore=false" \
        [list [tp_at k Vmeas plus] [tp_at k VMF plus]] {i(vmeas:n1) i(vmf:n1)}
    check "TPC5 a click on the pin of an ammeter that is NOT netlisted (spice_ignore 1, short, open, TRUE) takes the voltage path: the wire ending on that pin queues its net" \
        [list [tp_at k VM1 plus] [tp_at k VMS plus] [tp_at k VMO plus] [tp_at k VMT plus]] \
        {v(nm1) v(nms) v(nmo) v(nmt)}
    check "TPC6 a click exactly on a net LABEL's pin stays a voltage pick (the label ends the wire of D1's anode, 70 units from that pin)" \
        [list [tp_at k l_nd p] [pcall ase::ui::sod_terminal_at k {*}[tp_pin l_nd p]]] {v(nd) {}}
    check "TPC7 a LOCKED instance's pin is not offered: the pin probe skips a locked instance, as every pick here does" \
        [list [pcall xschem pin_at {*}[tp_pin RL P] -all] [pcall ase::ui::sod_terminal_at k {*}[tp_pin RL P]]] {{} {}}
    set keep $::en_pin_select
    set ::en_pin_select 0
    set off [tp_at k R9 P]
    set ::en_pin_select 1
    set on [tp_at k R9 P]
    set ::en_pin_select $keep
    check "TPC8 the pin pick does not depend on the editor's `en_pin_select` switch: the same click queues the same terminal with it off and on" \
        [list $off $on] {i(r9:n1) i(r9:n1)}
    check "TPC9 an `only_toplevel` source on the session's OWN sheet is a device: its pin queues a terminal" \
        [tp_at $TOPKEY VTOP p] {i(vtop:n1)}
    # the same attribute, one level down
    xschem unselect_all; xschem select instance [tp_inst {xbus[1:0]}]
    pcall xschem descend 2
    check "TPC10 fixture: descended into bit 0 of the bus instance (level 1, path .xbus\[0\].)" \
        [list [pcall xschem get currsch] [pcall xschem get sch_path]] {1 {.xbus[0].}}
    tp_set_radius 6
    check "TPC11 BELOW the session's design an `only_toplevel` source is in no `.subckt` body, so its pin takes the voltage path -- and under a session bound to THIS cell, where the same sheet is the deck's top, it is a device again" \
        [list [tp_at $TOPKEY VT p] [pcall ase::ui::sod_base_level $BUSKEY] [tp_at $BUSKEY VT p]] \
        {{{v(xbus[0].ntv)}} 1 i(vt:n1)}
    tp_home
}

# ===========================================================================
# TPR — range and winner
# ===========================================================================
group TPR {
    tp_home ; tp_switches_reset
    # the zoom is pinned with a zoom box wide enough that the pin radius is
    # far past the 10-unit bound: here the bound is what decides
    xschem zoom_box -200 -1700 10600 1700
    set r [tp_radius]
    lassign [tp_pin R3 P] dx dy
    lassign [tp_pin lnr p] lx ly
    check "TPR0 fixture: the zoom box pinned a zoom above 2, where the pin radius is past 40 units, and the label's pin stands 4 units from R3's" \
        [list [tp_less 2 [xschem get zoom]] [tp_less 40 $r] [tp_dist $dx $dy $lx $ly]] {1 1 4.0}
    check "TPR1 a net label's pin STRICTLY NEARER than every device pin makes the click a voltage pick: on the label's own pin (0 from it, 4 from the device) the net is queued and no terminal" \
        [list [tp_click k $lx $ly] [pcall ase::ui::sod_terminal_at k $lx $ly]] {v(near) {}}
    check "TPR2 at EQUAL distance the device pin wins: midway between the two pins (2 from each) the terminal is queued" \
        [tp_click k [expr {$dx + 2}] $dy] {i(r3:n1)}
    check "TPR3 a device pin strictly nearer than the label's is the terminal (1 from the device, 3 from the label)" \
        [tp_click k [expr {$dx + 1}] $dy] {i(r3:n1)}
    lassign [tp_pin R1 M] ax ay
    set got [tp_click k $ax $ay]
    check "TPR4 two device pins on ONE point (R1's lower pin, R2's upper; the probe's two nearest rows): ONE terminal is queued, the first in the pin probe's order, and the notice names the other" \
        [list [lrange [pcall xschem pin_at $ax $ay -all] 0 1] $got $::notices] \
        [list [list [list [tp_inst R1] 1 R1 M $ax $ay] [list [tp_inst R2] 0 R2 P $ax $ay]] i(r1:n2) \
              [list "ase: that point is also R2 pin P — the click took R1 pin M"]]
    check "TPR4b the answer of the pin rule itself there: instance, pin, names, point and the sharers" \
        [pcall ase::ui::sod_terminal_at k $ax $ay] \
        [dict create inst [tp_inst R1] pin 1 instname R1 pinname M x $ax y $ay others {{R2 P}}]
    lassign [tp_pin RN1 P] nx ny
    set on1 [tp_click k $nx $ny]
    set n1 $::notices
    check "TPR4c two device pins 6 units apart, both in range, are NOT one point: on the first the nearer one is queued and no other terminal is named, and 4 units along (2 from the second, 4 from the first) the second is" \
        [list [tp_dist $nx $ny {*}[tp_pin RN2 P]] $on1 $n1 [tp_get [pcall ase::ui::sod_terminal_at k $nx $ny] others] \
              [tp_click k [expr {$nx + 4}] $ny] $::notices] \
        {6.0 i(rn1:n1) {} {} i(rn2:n1) {}}
    lassign [tp_pin V1 p] vx vy
    set body [tp_click k $vx [expr {$vy + 30}]]
    check "TPR5 THE 10-UNIT BOUND: V1's body centre is 30 units from both of its pins and both are inside the pin radius here (the probe lists them), yet the click is still the source's branch current" \
        [list [tp_listed $vx [expr {$vy + 30}] V1 p] [tp_listed $vx [expr {$vy + 30}] V1 m] $body] {1 1 i(v1)}
    lassign [tp_pin D1 p] px py
    check "TPR6 ...and a wire point 15 units from D1's anode pin, inside the pin radius too, still queues the wire's voltage" \
        [list [tp_listed $px [expr {$py - 15}] D1 p] [tp_click k $px [expr {$py - 15}]]] {1 v(nd)}
    lassign [tp_pin R9 P] qx qy
    check "TPR7 the bound is 10 units: 9 units down the body from R9's upper pin is the terminal, 11 units down is not (the body of a resistor queues nothing and says so)" \
        [list [tp_click k $qx [expr {$qy + 9}]] [tp_click k $qx [expr {$qy + 11}]] $::notices] \
        [list i(r9:n1) {} [list $TP_MISS]]
    # and the pin radius still bounds it where it is the smaller of the two
    set r2 [tp_set_radius 2]
    check "TPR8 at a zoom where the pin radius is 2 units the radius decides: 1 unit from R9's pin is the terminal, 5 units is not although it is inside the 10-unit bound" \
        [list [tp_less $r2 2.01] [tp_less 1.99 $r2] [tp_click k $qx [expr {$qy - 1}]] \
              [pcall ase::ui::sod_terminal_at k $qx [expr {$qy - 5}]]] \
        {1 1 i(r9:n1) {}}
}

# ---------------------------------------------------------------------------
# TPR, continued — several device pins on one point, a label ON a device pin,
# and wires that end on, pass, or leave a device pin
# ---------------------------------------------------------------------------
group TPR-shared {
    tp_home ; tp_switches_reset
    xschem zoom_box -200 -1700 10600 1700
    lassign [tp_pin R1 M] ax ay
    set upy [expr {$ay - 4}]
    set dny [expr {$ay + 4}]
    set up [tp_click k $ax $upy]
    set upn $::notices
    set dn [tp_click k $ax $dny]
    set dnn $::notices
    check "TPR4d two devices on one point, the cursor on ONE of them: 4 units up R1's lead the click is R1's terminal and the notice names R2; 4 units down R2's lead it is R2's and the notice names R1" \
        [list $up $upn $dn $dnn] \
        [list i(r1:n2) [list "ase: that point is also R2 pin P — the click took R1 pin M"] \
              i(r2:n1) [list "ase: that point is also R1 pin M — the click took R2 pin P"]]
    check "TPR4e the pin rule's answer 4 units down R2's lead: R2's pin with R1's as the sharer, at the shared point" \
        [pcall ase::ui::sod_terminal_at k $ax $dny] \
        [dict create inst [tp_inst R2] pin 0 instname R2 pinname P x $ax y $ay others {{R1 M}}]
    set y1 [expr {$ay - 1}]
    set y2 [expr {$ay + 1}]
    check "TPR4f one unit either side of the shared point, where the two symbols' boxes overlap, the editor's own hit test (`xschem object_at`) finds the device on the FAR side -- R2 one unit up R1's lead, R1 one unit down R2's -- and the click still takes the device whose lead it is on, also 3 units off the axis" \
        [list [lindex [pcall xschem object_at $ax $y1] 1] [lindex [pcall xschem object_at $ax $y2] 1] \
              [tp_click k $ax $y1] [tp_click k $ax $y2] [tp_click k [expr {$ax + 3}] $y1] [tp_click k [expr {$ax + 3}] $y2]] \
        [list [tp_inst R2] [tp_inst R1] i(r1:n2) i(r2:n1) i(r1:n2) i(r2:n1)]
    check "TPR4g how far a cursor stands TOWARDS an instance, measured from a point: 4 units up from R1's lower pin is +4 towards R1 and -4 towards R2, the point itself is 0 for both, and an instance that is not there is 0" \
        [list [pcall ase::ui::sod_term_toward [tp_inst R1] $ax $ay $ax $upy] [pcall ase::ui::sod_term_toward [tp_inst R2] $ax $ay $ax $upy] \
              [pcall ase::ui::sod_term_toward [tp_inst R1] $ax $ay $ax $ay] [pcall ase::ui::sod_term_toward [tp_inst R2] $ax $ay $ax $ay] \
              [pcall ase::ui::sod_term_toward 99999 $ax $ay $ax $upy]] \
        {4.0 -4.0 0.0 0.0 0.0}
    tp_rev_sheet
    tp_set_radius 30
    lassign [tp_pin R6 M] sx sy
    set c0 [tp_click k $sx $sy]
    set n0 $::notices
    set c1 [tp_click k $sx [expr {$sy - 4}]]
    set n1 $::notices
    set c2 [tp_click k $sx [expr {$sy + 4}]]
    set n2 $::notices
    set c3 [tp_click k [expr {$sx - 4}] $sy]
    set n3 $::notices
    check "TPR4h THREE device pins on one point -- R6 from above, R7 from below, R8 from the left (the probe lists the three) -- on the point the first in the probe's order is taken and the other two are named; 4 units towards each device it is that device's terminal with the other two named" \
        [list [llength [pcall xschem pin_at $sx $sy -all]] $c0 $n0 $c1 $n1 $c2 $n2 $c3 $n3] \
        [list 3 \
              i(r6:n2) [list "ase: that point is also R7 pin P, R8 pin P — the click took R6 pin M"] \
              i(r6:n2) [list "ase: that point is also R7 pin P, R8 pin P — the click took R6 pin M"] \
              i(r7:n1) [list "ase: that point is also R6 pin M, R8 pin P — the click took R7 pin P"] \
              i(r8:n1) [list "ase: that point is also R6 pin M, R7 pin P — the click took R8 pin P"]]
    tp_home
}

# ---------------------------------------------------------------------------
# TPR, continued — two blocks whose pins are ALL on the facing edge
# ---------------------------------------------------------------------------
# The middle of such a block's pins lies on the edge itself, so "towards the
# middle of the pins" runs along the edge and says nothing about the side the
# block's body is on.  The side of the point each block's BOX is on is what
# tells them apart -- for equal pin sets, where the two pin measures are the
# same, and for unequal ones, where they differ and neither means anything.
#
# THE SIDE RULE ON TWO ABUTTING BLOCKS, probed where a hand aims: for each pin
# number in `ks`, 4 units into the LEFT block from the shared point and 4
# units into the RIGHT one, each half a unit above and half a unit below the
# pin's axis.  Per point: `ok` when the click queued the terminal of the block
# the point is in and its one sentence names the other block's pin; otherwise
# what the click did.  The pins of `left` are called <lp><k>, those of `right`
# <rp><k>.
proc tp_side_probe {left lp right rp ks} {
    set out {}
    foreach k $ks {
        lassign [tp_pin $left $lp$k] sx sy
        foreach {dx own opin other otherpin} [list -4 $left $lp$k $right $rp$k 4 $right $rp$k $left $lp$k] {
            foreach dy {-0.5 0.5} {
                set q [tp_click k [expr {$sx + $dx}] [expr {$sy + $dy}]]
                set want "i([string tolower $own]:[string tolower $opin])"
                set said [list "ase: that point is also $other pin $otherpin — the click took $own pin $opin"]
                lappend out [expr {$q eq $want && $::notices eq $said ? {ok} : [list $k $dx $dy $q $::notices]}]
            }
        }
    }
    return $out
}
# do the measures of two instances towards the middle of their PINS differ, for
# a cursor 4 units left of pin `lp<k>` of `left` and half a unit below it?  One
# 0/1 per pin number; `differ` is more than a rounding apart.
proc tp_side_differ {left lp right ks} {
    set out {}
    foreach k $ks {
        lassign [tp_pin $left $lp$k] sx sy
        set a [pcall ase::ui::sod_term_toward [tp_inst $left] $sx $sy [expr {$sx - 4}] [expr {$sy + 0.5}]]
        set b [pcall ase::ui::sod_term_toward [tp_inst $right] $sx $sy [expr {$sx - 4}] [expr {$sy + 0.5}]]
        lappend out [expr {[string is double -strict $a] && [string is double -strict $b] && abs($a - $b) > 1e-6 ? 1 : 0}]
    }
    return $out
}
group TPR-edge {
    tp_geo_sheet ; tp_switches_reset
    tp_set_radius 30
    lassign [tp_pin xa P1] ex ey
    set lx [expr {$ex - 4}]
    set rx [expr {$ex + 4}]
    set na [tp_inst xa]
    set nb [tp_inst xb]
    check "TPR4i fixture: the top pin of the left block and of the right block are one point, the left block stands first on the sheet, and 4 units either side of the point the measure towards the middle of a block's pins is 0 for the left block and for the right one: it cannot tell them apart" \
        [list [expr {[tp_pin xb Q1] eq [list $ex $ey]}] [tp_less $na $nb] \
              [pcall ase::ui::sod_term_toward $na $ex $ey $lx $ey] [pcall ase::ui::sod_term_toward $nb $ex $ey $lx $ey] \
              [pcall ase::ui::sod_term_toward $na $ex $ey $rx $ey] [pcall ase::ui::sod_term_toward $nb $ex $ey $rx $ey]] \
        {1 1 0.0 0.0 0.0 0.0}
    set l [tp_click k $lx $ey]
    set ln $::notices
    set r [tp_click k $rx $ey]
    set rn $::notices
    set on [tp_click k $ex $ey]
    set onn $::notices
    check "TPR4j two blocks abutting pin on pin, every pin on the facing edge: 4 units into the LEFT block the click is the left block's terminal and the notice names the right block's pin; 4 units into the RIGHT block it is the right block's and the notice names the left one's; on the point itself the first in the pin probe's order is taken" \
        [list $l $ln $r $rn $on $onn] \
        [list i(xa:p1) [list "ase: that point is also xb pin Q1 — the click took xa pin P1"] \
              i(xb:q1) [list "ase: that point is also xa pin P1 — the click took xb pin Q1"] \
              i(xa:p1) [list "ase: that point is also xb pin Q1 — the click took xa pin P1"]]
    lassign [tp_pin xa P2] mx my
    check "TPR4k ...and on the MIDDLE pin, where the middle of each block's pins is the shared point itself: 4 units to the left is the left block's terminal, 4 units to the right the right block's" \
        [list [expr {[tp_pin xb Q2] eq [list $mx $my]}] [tp_click k [expr {$mx - 4}] $my] [tp_click k [expr {$mx + 4}] $my]] \
        {1 i(xa:p2) i(xb:q2)}
    lassign [tp_pin xc P1] cx cy
    set l [tp_click k [expr {$cx - 4}] $cy]
    set ln $::notices
    set r [tp_click k [expr {$cx + 4}] $cy]
    set rn $::notices
    set on [tp_click k $cx $cy]
    check "TPR4l the same pair with the RIGHT block first on the sheet: 4 units into each block is still that block's terminal, and on the point the first in the probe's order is now the right block" \
        [list [tp_less [tp_inst xd] [tp_inst xc]] $l $ln $r $rn $on] \
        [list 1 i(xc:p1) [list "ase: that point is also xd pin Q1 — the click took xc pin P1"] \
              i(xd:q1) [list "ase: that point is also xc pin P1 — the click took xd pin Q1"] i(xd:q1)]
    check "TPR4m how far a cursor stands towards the middle of an instance's BOX, measured from a point: 4 units left of the shared point is on the left block's side (above zero) and off the right block's (below zero), the point itself is 0 for both, and an instance that is not there is 0" \
        [list [tp_less 0 [pcall ase::ui::sod_term_toward_box $na $ex $ey $lx $ey]] [tp_less [pcall ase::ui::sod_term_toward_box $nb $ex $ey $lx $ey] 0] \
              [pcall ase::ui::sod_term_toward_box $na $ex $ey $ex $ey] [pcall ase::ui::sod_term_toward_box $nb $ex $ey $ex $ey] \
              [pcall ase::ui::sod_term_toward_box 99999 $ex $ey $lx $ey]] \
        {1 1 0.0 0.0 0.0}
    # ---- unequal pin sets: three pins against five
    set shared {}
    foreach k {1 2 3} { lappend shared [expr {[tp_pin xe P$k] eq [tp_pin xf Q$k]}] [expr {[tp_pin xg P$k] eq [tp_pin xh Q$k]}] }
    check "TPR4n fixture: a three-pin right-edge block abuts a five-pin left-edge block, pins 1 to 3 on pins 1 to 3, once with the three-pin block first on the sheet and once with the five-pin block first; and for a cursor 4 units into the left block, half a unit below the pin's axis, the two blocks' measures towards the middle of their PINS are the same on the top pin and DIFFER on the middle and on the bottom pin -- there a rule that compared them would let the side of the axis choose the block (the six pins shared; the first pair's order; the second pair's; differ per pin, first pair; second pair)" \
        [list $shared [tp_less [tp_inst xe] [tp_inst xf]] [tp_less [tp_inst xh] [tp_inst xg]] \
              [tp_side_differ xe P xf {1 2 3}] [tp_side_differ xg P xh {1 2 3}]] \
        {{1 1 1 1 1 1} 1 1 {0 1 1} {0 1 1}}
    check "TPR4o BLOCKS WITH UNEQUAL PIN SETS ARE TOLD APART BY THEIR BOXES AS WELL: at each of the three shared pins, 4 units into the three-pin block the click is that block's terminal and 4 units into the five-pin block it is the five-pin block's, half a unit ABOVE the pin's axis and half a unit BELOW it alike, and each click names the other block's pin (per point, top pin first: into the left block above and below the axis, then into the right block above and below)" \
        [tp_side_probe xe P xf Q {1 2 3}] [lrepeat 12 ok]
    check "TPR4p ...and with the five-pin block first on the sheet" \
        [tp_side_probe xg P xh Q {1 2 3}] [lrepeat 12 ok]
    # ---- a title that reaches over the neighbour
    set jbox [pcall xschem instance_bbox [tp_inst xj]]
    set jleft NOBOX
    regexp {Instance: (\S+) } $jbox -> jleft
    check "TPR4q A TITLE THAT REACHES OVER THE NEIGHBOUR DOES NOT MOVE THE BLOCK'S SIDE: the right block of an equal pair carries a title whose text makes its instance box reach left past the whole body of the block it abuts (fixture leg: the box's left edge against the left block's left edge), and at the same twelve points each click still takes the block the point is in" \
        [list [tp_less $jleft [expr {[lindex [tp_pin xi P2] 0] - 80}]] [tp_side_probe xi P xj Q {1 2 3}]] \
        [list 1 [lrepeat 12 ok]]
    # ---- the two questions the rule asks of an instance
    lassign [tp_pin xe P1] e1x e1y
    lassign [tp_pin xe P2] e2x e2y
    lassign [tp_pin RB P] rbx rby
    lassign [tp_pin Vab minus] vax vay
    lassign [tp_pin E1 p] epx epy
    lassign [tp_pin D9 p] d9x d9y
    check "TPR4r WHEN AN INSTANCE'S PINS SAY NOTHING ABOUT ITS SIDE OF A POINT: a block with every pin on one edge, at its top pin (the pins run along the edge and the box's middle is beside it) and at its middle pin (the middle of its pins is the point); not a resistor and not an ammeter at one of their pins, whose two pins and whose box's middle are on one line; not the four-pin source, whose pins are on no one line; an instance that is not there says nothing; and the stock LED, whose two pins are in line while its drawing lies to one side of them, says nothing either" \
        [list [pcall ase::ui::sod_term_edge_on [tp_inst xe] $e1x $e1y] [pcall ase::ui::sod_term_edge_on [tp_inst xe] $e2x $e2y] \
              [pcall ase::ui::sod_term_edge_on [tp_inst RB] $rbx $rby] [pcall ase::ui::sod_term_edge_on [tp_inst Vab] $vax $vay] \
              [pcall ase::ui::sod_term_edge_on [tp_inst E1] $epx $epy] [pcall ase::ui::sod_term_edge_on 99999 $e1x $e1y] \
              [pcall ase::ui::sod_term_edge_on [tp_inst D9] $d9x $d9y]] \
        {1 1 0 0 0 1 1}
    # ---- a symbol with two pins of one name: its pins cannot be placed by
    # name, so it is not asked for its side by them.  The shared point is the
    # first block's origin plus 80 in x; the pin probe lists pins by index.
    set xsx 4480 ; set xsy 0
    set nxn [tp_inst xn]
    set nxo [tp_inst xo]
    set xnames [lmap row [pcall xschem pinlist $nxo name] { lindex $row 1 }]
    set xanswers {}
    foreach {dx dy} {-3 -8 3 8} {
        set t [pcall ase::ui::sod_terminal_at k [expr {$xsx + $dx}] [expr {$xsy + $dy}]]
        lappend xanswers [list [tp_get $t instname] [tp_get $t pin]]
    }
    check "TPR4u A SYMBOL WITH TWO PINS OF ONE NAME IS NOT ASKED FOR ITS SIDE BY ITS PINS: two instances of the shipped xcross.sym, whose pins repeat the names A and B, share a point -- a right-edge pin of the first, a pin of the second, which is turned half round; neither is said to have its pins along one edge there, and so 3 units left of the point and 8 up, inside the first block, the click is the first block's pin, and 3 right and 8 down, inside the second, the second's (fixture legs: the pins the probe lists on the point, by index; the second block's pin names, sorted, and how many pins it has; then: the predicate for the first block and for the second; the two answers as block and pin index)" \
        [list [lmap r [pcall xschem pin_at $xsx $xsy -all] { lrange $r 1 5 }] [lsort -unique $xnames] [llength $xnames] \
              [pcall ase::ui::sod_term_edge_on $nxn $xsx $xsy] [pcall ase::ui::sod_term_edge_on $nxo $xsx $xsy] $xanswers] \
        [list [list [list 3 xn A $xsx $xsy] [list 1 xo B $xsx $xsy]] {A B} 6 0 0 {{xn 3} {xo 1}}]
    # ---- ONE device of a point whose pins say nothing is enough, and it need
    # not be the first of them on the sheet
    lassign [tp_pin C9 p] c9x c9y
    set nrh [tp_inst RH]
    set nc9 [tp_inst C9]
    set c9down [expr {$c9y + 4}]
    set on_lead {}
    foreach dx {0.5 -0.5} {
        set q [tp_click k [expr {$c9x + $dx}] $c9down]
        lappend on_lead [list $q $::notices]
    }
    # ...nor the last: the same pair once more, the capacitor EARLIER on the
    # sheet than the resistor
    lassign [tp_pin C8 p] c8x c8y
    set nrj [tp_inst RJ]
    set nc8 [tp_inst C8]
    set c8down [expr {$c8y + 4}]
    set on_lead8 {}
    foreach dx {0.5 -0.5} {
        set q [tp_click k [expr {$c8x + $dx}] $c8down]
        lappend on_lead8 [list $q $::notices]
    }
    check "TPR4v ONE DEVICE WHOSE PINS SAY NOTHING IS ENOUGH, WHEREVER IT STANDS ON THE SHEET: the stock one-pin capacitor placed LATER on the sheet than the resistor whose pin it shares, its lead going down from the point while the resistor lies to the right of it -- 4 units down the capacitor's lead, half a unit on the resistor's side of the lead and half a unit on the other side, the click is the capacitor's terminal and names the resistor's pin; and the same with a second such pair whose capacitor stands EARLIER on the sheet than its resistor (fixture legs: the two pins are one point; the resistor stands first; the resistor's pins say its side and the capacitor's do not; half a unit on the resistor's side the measure towards the middle of the pins is larger for the resistor, so a rule that asked the first device alone would take the resistor there; then the two clicks -- and for the second pair: one point; the capacitor stands first; the resistor's pins say its side and the capacitor's do not; the same measure, so a rule that asked the last device alone would take the resistor there; then its two clicks)" \
        [list [expr {[tp_pin RH M] eq [list $c9x $c9y]}] [tp_less $nrh $nc9] \
              [pcall ase::ui::sod_term_edge_on $nrh $c9x $c9y] [pcall ase::ui::sod_term_edge_on $nc9 $c9x $c9y] \
              [tp_less [pcall ase::ui::sod_term_toward $nc9 $c9x $c9y [expr {$c9x + 0.5}] $c9down] \
                       [pcall ase::ui::sod_term_toward $nrh $c9x $c9y [expr {$c9x + 0.5}] $c9down]] \
              $on_lead \
              [expr {[tp_pin RJ M] eq [list $c8x $c8y]}] [tp_less $nc8 $nrj] \
              [pcall ase::ui::sod_term_edge_on $nrj $c8x $c8y] [pcall ase::ui::sod_term_edge_on $nc8 $c8x $c8y] \
              [tp_less [pcall ase::ui::sod_term_toward $nc8 $c8x $c8y [expr {$c8x + 0.5}] $c8down] \
                       [pcall ase::ui::sod_term_toward $nrj $c8x $c8y [expr {$c8x + 0.5}] $c8down]] \
              $on_lead8] \
        [list 1 1 0 1 1 [lrepeat 2 [list i(c9:n1) [list "ase: that point is also RH pin M — the click took C9 pin p"]]] \
              1 1 0 1 1 [lrepeat 2 [list i(c8:n1) [list "ase: that point is also RJ pin M — the click took C8 pin p"]]]]
    # ---- pin names that end in a backslash.  The engine's own list of a
    # symbol's pin names is no list for such a name, and neither is its answer
    # for where the pin is, so the points here are written out and each is
    # read back through the pin probe, which does answer a list.
    #   RQ|RU at 8760,0   RQ's left pin and a resistor's lower pin
    #   xw|RV at 9160,0   a block's left port and a resistor's lower pin
    #   RK|CQ at 9570,0   a lying resistor's left pin and a one-pin device
    set bsA "A$TP_BSL"
    set bsP "p$TP_BSL"
    set bs_listed {}
    foreach {x y} {8760 0 9160 0 9570 0} {
        lappend bs_listed [lmap r [pcall xschem pin_at $x $y -all] { lrange $r 2 3 }]
    }
    set bs_nolist {}
    foreach nm {RQ xw CQ} {
        lappend bs_nolist [catch {llength [xschem pinlist [tp_inst $nm] name]}]
    }
    set bs_names [list [pcall ase::ui::sod_term_pin_names [tp_inst RQ]] [pcall ase::ui::sod_term_pin_names [tp_inst CQ]]]
    set bs_edge [lmap {nm x y} {RQ 8760 0 RU 8760 0 xw 9160 0 CQ 9570 0 RK 9570 0} { pcall ase::ui::sod_term_edge_on [tp_inst $nm] $x $y }]
    set bs_clicks {}
    foreach {x y} {8764 0  8760 -4  9570.5 4  9569.5 4  9574 0  9160 -4} {
        set q [tp_click k $x $y]
        lappend bs_clicks [list $q $::notices]
    }
    # the block's port: what its click queued, how many sentences it said, and
    # whether that one sentence is the refusal for a name a terminal row cannot
    # hold -- its opening, naming the instance and the pin, and its ending
    pcall xschem pin_marker clear -fast
    set bs_q [tp_click k 9164 0]
    set bs_head "ase: nothing queued for xw pin $bsA — its current would be the row '"
    set bs_tail "; rename the instance or the port, or place an ammeter (ammeter.sym) in series"
    set bs_said [lindex $::notices 0]
    set bs_refused [list $bs_q [llength $::notices] \
        [expr {[string first $bs_head $bs_said] == 0 ? {opens as the refusal} : $bs_said}] \
        [expr {[string range $bs_said end-[expr {[string length $bs_tail] - 1}] end] eq $bs_tail ? {ends with what to do} : $bs_said}] \
        [pcall xschem pin_marker list]]
    check "TPR4w A PIN NAME THAT ENDS IN A BACKSLASH DOES NOT STOP THE SAME-POINT RULE: for such a symbol the engine's own list of pin names is no list at all, and the rule reads the names another way.  A two-pin device with such pins against a resistor is told apart by the side towards the middle of the pins: 4 units along its body the click is its terminal, 4 units up the resistor's lead the resistor's, each naming the other.  A ONE-pin device with such a pin, whose pins say nothing about its side, is told from a lying resistor by the boxes: 4 units down its lead, half a unit either side, the click is its terminal, and 4 units along the resistor the resistor's.  And a BLOCK whose port ends in a backslash is chosen by the rule the same way, 4 units into it, and its click is then refused in one sentence for the name its row would carry, with what to do, and queues and marks nothing; 4 units up the resistor on that point the click is the resistor's terminal (fixture legs: the instance and pin names the pin probe lists on each of the three points; for each of the three symbols, asking the engine for its list of names and counting it raises; the names the rule reads for the two-pin and for the one-pin device -- then: whether the pins say nothing about the side, for the two-pin device, its resistor, the block, the one-pin device and its resistor; the six clicks; the block's click)" \
        [list $bs_listed $bs_nolist $bs_names $bs_edge $bs_clicks $bs_refused] \
        [list [list [list [list RQ $bsA] {RU M}] [list [list xw $bsA] {RV M}] [list {RK M} [list CQ $bsP]]] \
              {1 1 1} [list [list $bsA "Y$TP_BSL"] [list $bsP]] {0 0 0 1 0} \
              [list [list i(rq:n1) [list "ase: that point is also RU pin M — the click took RQ pin $bsA"]] \
                    [list i(ru:n2) [list "ase: that point is also RQ pin $bsA — the click took RU pin M"]] \
                    [list i(cq:n1) [list "ase: that point is also RK pin M — the click took CQ pin $bsP"]] \
                    [list i(cq:n1) [list "ase: that point is also RK pin M — the click took CQ pin $bsP"]] \
                    [list i(rk:n2) [list "ase: that point is also CQ pin $bsP — the click took RK pin M"]] \
                    [list i(rv:n2) [list "ase: that point is also xw pin $bsA — the click took RV pin M"]]] \
              [list {} 1 {opens as the refusal} {ends with what to do} {}]]
    # ---- plain pin names beside ANOTHER attribute that ends in a backslash.
    # For such a symbol the engine's list of the pins' attribute strings is no
    # list, while its list of their names is one.  The pair is on a sheet of
    # its own (tp_note); the third sheet and the band's pin radius are put
    # back for the rows below.
    pcall xschem load $tp_note
    tp_set_radius 30
    set nrn [tp_inst RN]
    set nrw [tp_inst RW]
    set note_listed [lmap r [pcall xschem pin_at 0 0 -all] { lrange $r 2 3 }]
    set note_lists [list [catch {llength [xschem pinlist $nrn]}] [catch {llength [xschem pinlist $nrn name]}]]
    set note_names [pcall ase::ui::sod_term_pin_names $nrn]
    set note_edge [list [pcall ase::ui::sod_term_edge_on $nrn 0 0] [pcall ase::ui::sod_term_edge_on $nrw 0 0]]
    set note_toward [list [tp_less 0 [pcall ase::ui::sod_term_toward $nrn 0 0 4 0]] \
                          [tp_less [pcall ase::ui::sod_term_toward $nrn 0 0 -4 0] 0]]
    set note_rule {}
    foreach {x y} {4 0  0 -4} {
        set t [pcall ase::ui::sod_terminal_at k $x $y]
        lappend note_rule [list [tp_get $t instname] [tp_get $t pinname] [tp_get $t others]]
    }
    check "TPR4x PLAIN PIN NAMES ARE READ ALTHOUGH ANOTHER ATTRIBUTE OF THE PIN ENDS IN A BACKSLASH: for a two-pin device whose pins are named A and Y and carry a second attribute that ends in a backslash, the rule reads the two names, so its pins say which side its body is on, and the measure towards the middle of its pins is positive 4 units along its body and negative 4 units the other way.  On the point its left pin shares with a resistor's lower pin the rule takes the device 4 units along its body and the resistor 4 units up the resistor's lead, each with the other listed beside it (fixture legs: the instance and pin names the pin probe lists on the point; counting the engine's list of that device's pin attribute strings raises and counting its list of their names does not -- then: the names read; whether the pins say nothing about the side, for the device and for the resistor; the measure, along the body and the other way; the rule at the two points)" \
        [list $note_listed $note_lists $note_names $note_edge $note_toward $note_rule] \
        [list {{RN A} {RW M}} {1 0} {A Y} {0 0} {1 1} {{RN A {{RW M}}} {RW M {{RN A}}}}]
    tp_geo_sheet
    tp_set_radius 30
    # the middle of a box, measured from the instance's own origin
    proc tp_centre_rel {inst ox oy} {
        set c [pcall ase::ui::sod_term_box_centre [tp_inst $inst]]
        if {[llength $c] != 2 || ![string is double -strict [lindex $c 0]] || ![string is double -strict [lindex $c 1]]} { return "NOCENTRE:$c" }
        return [list [expr {[lindex $c 0] - $ox}] [expr {[lindex $c 1] - $oy}]]
    }
    lassign [tp_pin xk Q2] kx ky
    lassign [tp_pin xm P2] mx2 my2
    # is `p` a point, two numbers?
    proc tp_is_xy {p} {
        return [expr {[llength $p] == 2 && [string is double -strict [lindex $p 0]] && [string is double -strict [lindex $p 1]] ? 1 : 0}]
    }
    # the middle of the ENGINE'S box of an instance (the `Instance:` line of
    # `xschem instance_bbox`): for a symbol with no text that box is the
    # symbol's own, as the engine placed it
    proc tp_engine_mid {inst} {
        set bb [pcall xschem instance_bbox [tp_inst $inst]]
        if {![regexp {Instance: (\S+) (\S+) (\S+) (\S+)} $bb -> x1 y1 x2 y2]} { return "NOBOX:$bb" }
        if {![tp_is_xy [list $x1 $y1]] || ![tp_is_xy [list $x2 $y2]]} { return "NOBOX:$bb" }
        return [list [expr {($x1 + $x2) / 2.0}] [expr {($y1 + $y2) / 2.0}]]
    }
    # the block with no text in each of its placements: the middle the proc
    # answers against the engine's, and where the engine's middle lies from
    # the instance's origin
    set placed {} ; set from_origin {} ; set off_origin 1
    foreach {inst ox oy} $TP_ASYM_AT {
        set e [tp_engine_mid $inst]
        set c [pcall ase::ui::sod_term_box_centre [tp_inst $inst]]
        set same 0
        if {[tp_is_xy $e]} {
            set rel [list [expr {[lindex $e 0] - $ox}] [expr {[lindex $e 1] - $oy}]]
            lappend from_origin $rel
            if {abs([lindex $rel 0]) < 5 || abs([lindex $rel 1]) < 5} { set off_origin 0 }
            if {[tp_is_xy $c]} {
                set same [expr {abs([lindex $c 0] - [lindex $e 0]) < 1e-6 && abs([lindex $c 1] - [lindex $e 1]) < 1e-6 ? 1 : 0}]
            }
        } else { set off_origin 0 }
        lappend placed [expr {$same ? {ok} : [list $inst $c $e]}]
    }
    check "TPR4s THE MIDDLE OF AN INSTANCE'S BOX IS THE SYMBOL'S, WITHOUT ITS TEXTS, PLACED AS THE INSTANCE IS: the block with the long title has its middle where the same block without a title has it, measured from each one's own origin; a block FLIPPED so that its pins are on the right has its body to the left of its middle pin (4 units left of the pin is towards its box, 4 units right is away); a block TURNED a quarter so that its pins are below has its body above them; an instance that is not there has no middle; and a block with NO text, whose box lies off its origin in x and in y, has its middle where the engine's own box of the instance has it, in each of the four rotations, plain and flipped (the titled block's middle against the plain one's; flipped: left, right; turned: above, below; not there; per placement, the proc's middle against the engine's; fixture legs: the engine's middles, each taken from its instance's own origin, are all different points -- their number -- and every one is at least 5 units off the origin both ways)" \
        [list [expr {[tp_centre_rel xj 3080 0] eq [tp_centre_rel xb 380 0] ? {same} : [list [tp_centre_rel xj 3080 0] [tp_centre_rel xb 380 0]]}] \
              [tp_less 0 [pcall ase::ui::sod_term_toward_box [tp_inst xk] $kx $ky [expr {$kx - 4}] $ky]] \
              [tp_less [pcall ase::ui::sod_term_toward_box [tp_inst xk] $kx $ky [expr {$kx + 4}] $ky] 0] \
              [tp_less 0 [pcall ase::ui::sod_term_toward_box [tp_inst xm] $mx2 $my2 $mx2 [expr {$my2 - 4}]]] \
              [tp_less [pcall ase::ui::sod_term_toward_box [tp_inst xm] $mx2 $my2 $mx2 [expr {$my2 + 4}]] 0] \
              [pcall ase::ui::sod_term_box_centre 99999] \
              $placed [llength [lsort -unique $from_origin]] $off_origin] \
        {same 1 1 1 1 {} {ok ok ok ok ok ok ok ok} 8 1}
    # ---- the rule reads only, also where it asks for an instance's placement
    pcall xschem unselect_all
    pcall xschem select instance [tp_inst RB]
    set sel0 [list [pcall xschem get lastsel] [pcall xschem selected_set] [pcall xschem get ui_state] [pcall xschem get modified]]
    set probed [lsort -unique [tp_side_probe xe P xf Q {1 2 3}]]
    set sel1 [list [pcall xschem get lastsel] [pcall xschem selected_set] [pcall xschem get ui_state] [pcall xschem get modified]]
    pcall xschem unselect_all
    check "TPR4t THE SAME-POINT RULE READS ONLY, the box lookup included: with one instance selected beforehand, the twelve clicks of row TPR4o all take the right block and leave the selection, the editor's state word and the sheet's modified flag exactly as they were (the clicks; the state after against before; one object was selected throughout)" \
        [list $probed [expr {$sel1 eq $sel0 ? {as before} : $sel1}] [lindex $sel0 0]] {ok {as before} 1}
    tp_home
}

group TPR-label {
    tp_rev_sheet ; tp_switches_reset
    set r [tp_set_radius 30]
    lassign [tp_pin R5 P] px py
    lassign [tp_pin l_on p] lx ly
    check "TPR9 a net label placed ON a device pin (the probe lists the two pins on the one point; the pin radius here is past the 10-unit bound): the shared point is the DEVICE's terminal, and so is a point 10 units into the label's text; 11 units in, where the object under the cursor is still the label, the click is the net's voltage and nothing is said" \
        [list [list $lx $ly] [llength [pcall xschem pin_at $px $py -all]] [tp_less 10 $r] \
              [lrange [pcall xschem object_at [expr {$px - 11}] $py] 0 1] \
              [tp_click k $px $py] [tp_click k [expr {$px - 10}] $py] [tp_click k [expr {$px - 11}] $py] $::notices] \
        [list [list $px $py] 2 1 [list instance [tp_inst l_on]] i(r5:n1) i(r5:n1) v(onpin) {}]
    tp_home
}

group TPR-wire {
    tp_rev_sheet ; tp_switches_reset
    set r [tp_set_radius 30]
    lassign [tp_pin R1 M] ax ay
    lassign [tp_pin R2 P] bx by
    lassign [tp_pin R3 M] cx cy
    lassign [tp_pin R4 P] ex ey
    set v20 [tp_vnet R1 M]
    set v10 [tp_vnet R3 M]
    check "TPR10 fixture: the pin radius is past the 10-unit bound, so every point of both wires is within range of a device pin; R1's lower pin and R2's upper are 20 units apart and on one net, R3's and R4's 10 apart and on another; and the object under each wire's middle is a wire" \
        [list [tp_less 10 $r] [tp_dist $ax $ay $bx $by] [expr {$v20 eq [tp_vnet R2 P]}] \
              [tp_dist $cx $cy $ex $ey] [expr {$v10 eq [tp_vnet R4 P]}] [expr {$v20 ne $v10}] [string match {v(?*)} $v20] \
              [lindex [pcall xschem object_at $ax [expr {$ay + 10}]] 0] [lindex [pcall xschem object_at $cx [expr {$cy + 5}]] 0]] \
        {1 20.0 1 10.0 1 1 1 wire wire}
    check "TPR11 A CLICK ON A WIRE IS THE WIRE: on the 20-unit wire between two device pins, its middle and the points 3 units from either pin queue the net's voltage and not a terminal, and nothing is said" \
        [list [tp_click k $ax [expr {$ay + 10}]] [tp_click k $ax [expr {$ay + 3}]] [tp_click k $bx [expr {$by - 3}]] $::notices] \
        [list $v20 $v20 $v20 {}]
    check "TPR12 ...and on the 10-unit wire, no point of which is more than 5 units from a device pin: its middle and the points 3 units from either pin queue its net's voltage" \
        [list [tp_click k $cx [expr {$cy + 5}]] [tp_click k $cx [expr {$cy + 3}]] [tp_click k $ex [expr {$ey - 3}]]] \
        [list $v10 $v10 $v10]
    check "TPR13 the pin's own square is still the terminal: on each of the four pin points, and 2 units along the wire from each, which is inside the square, the device's terminal is queued" \
        [list [tp_click k $ax $ay] [tp_click k $bx $by] [tp_click k $cx $cy] [tp_click k $ex $ey] \
              [tp_click k $ax [expr {$ay + 2}]] [tp_click k $bx [expr {$by - 2}]] [tp_click k $cx [expr {$cy + 2}]] [tp_click k $ex [expr {$ey - 2}]]] \
        {i(r1:n2) i(r2:n1) i(r3:n2) i(r4:n1) i(r1:n2) i(r2:n1) i(r3:n2) i(r4:n1)}
    check "TPR14 the device's own LEAD is still the terminal: 6 units up R1's lead and 6 units down R2's, past the wire's two ends, the object under the cursor is still a wire (its pick tolerance reaches past its end) and the click is the terminal" \
        [list [lindex [pcall xschem object_at $ax [expr {$ay - 6}]] 0] [lindex [pcall xschem object_at $bx [expr {$by + 6}]] 0] \
              [tp_click k $ax [expr {$ay - 6}]] [tp_click k $bx [expr {$by + 6}]]] \
        {wire wire i(r1:n2) i(r2:n1)}
    check "TPR15 beside the wire, off its line: 4 units to the side of the 20-unit wire, 6 units along it, the object under the cursor is the wire and the click is its voltage" \
        [list [lindex [pcall xschem object_at [expr {$ax + 4}] [expr {$ay + 6}]] 0] [tp_click k [expr {$ax + 4}] [expr {$ay + 6}]]] \
        [list wire $v20]
    lassign [tp_pin R10 P] tx ty
    check "TPR16 a wire that only PASSES a pin, 3 units beside it: with the cursor inside the pin's square -- 2 units from the pin, 1 from that wire, which is the object under it -- the click is the terminal; on that wire, outside the square, it is a voltage" \
        [list [lindex [pcall xschem object_at [expr {$tx + 2}] $ty] 0] [tp_click k [expr {$tx + 2}] $ty] \
              [lindex [pcall xschem object_at [expr {$tx + 3}] $ty] 0] [string match {v(?*)} [tp_click k [expr {$tx + 3}] $ty]]] \
        {wire i(r10:n1) wire 1}
    lassign [tp_pin R11 M] ux uy
    check "TPR17 a wire leaving the pin SIDEWAYS, along the edge of the symbol's box: 4 units below it and 2 along, the object under the cursor is that wire but the cursor's foot on it is inside the pin's square, and the click is the terminal; 6 along, where the foot is outside the square, it is the wire's voltage" \
        [list [lindex [pcall xschem object_at [expr {$ux + 2}] [expr {$uy + 4}]] 0] [tp_click k [expr {$ux + 2}] [expr {$uy + 4}]] \
              [lindex [pcall xschem object_at [expr {$ux + 6}] [expr {$uy + 4}]] 0] [tp_click k [expr {$ux + 6}] [expr {$uy + 4}]]] \
        [list wire i(r11:n2) wire [tp_vnet R11 M]]
    tp_mode k plot
    set g [tp_click k $ax [expr {$ay + 10}]]
    set gk $::qkinds
    set gn $::notices
    tp_mode k outputs
    check "TPR18 Direct Plot on that wire: the middle of the 20-unit wire queues a trace of kind `voltage` and says nothing about results" \
        [list $g $gk $gn] [list $v20 voltage {}]
    tp_home
}

# ---------------------------------------------------------------------------
# TPR, continued — a click a pixel beside a wire, where the editor's hit test
# names something else
# ---------------------------------------------------------------------------
# The stub below RS's lower pin carries a net label at its far end whose box
# lies back over the stub.  Off the stub's axis the hit test answers that
# label, not the wire, so the wire test that trusts the hit test says nothing
# there; the wires themselves are asked.
group TPR-near {
    tp_geo_sheet ; tp_switches_reset
    set r [tp_set_radius 30]
    set tol [expr {max(2.5, 1.5 * [xschem get zoom])}]
    lassign [tp_pin RS M] ax ay
    lassign [tp_pin l_stub p] lx ly
    set vstub [tp_vnet RS M]
    set lab [list instance [tp_inst l_stub]]
    # the points beside the stub: 0.7 and 1.7 units either side, 4, 6 and 8
    # units from the pin
    set beside {}
    foreach dx {0.7 -0.7 1.7 -1.7} {
        foreach dy {4 6 8} { lappend beside [list [expr {$ax + $dx}] [expr {$ay + $dy}]] }
    }
    check "TPR19 fixture: the pin radius is past the 10-unit bound; the stub runs 20 units down from RS's lower pin to the label's pin; ON the stub the object under the cursor is a wire, and at every one of the twelve points beside it -- 0.7 and 1.7 units either side, 4, 6 and 8 units from the pin -- it is the LABEL; the tolerance of the wire rule here is under 4.5 units" \
        [list [tp_less 10 $r] [list [expr {$lx - $ax}] [expr {$ly - $ay}]] [lindex [pcall xschem object_at $ax [expr {$ay + 6}]] 0] \
              [lsort -unique [lmap p $beside { lrange [pcall xschem object_at {*}$p] 0 1 }]] [llength $beside] [tp_less $tol 4.5]] \
        [list 1 {0 20} wire [list $lab] 12 1]
    set bq {}
    set bn {}
    foreach p $beside {
        lappend bq [tp_click k {*}$p]
        lappend bn {*}$::notices
    }
    check "TPR20 A CLICK A PIXEL BESIDE A WIRE IS THE WIRE: each of those twelve points queues the stub's voltage and not RS's terminal, and none of the twelve clicks says anything" \
        [list [llength $bq] [lsort -unique $bq] [string match {v(?*)} $vstub] $bn] \
        [list 12 [list $vstub] 1 {}]
    check "TPR21 ...while the pin's own square and the device's lead are still the terminal there: 1 unit beside the stub and 1 unit along it, inside the square; 2.6 units up RS's lead, just past the square and within the tolerance of the stub's end; and 6 units up the lead -- where the object under the cursor is the label as well" \
        [list [tp_click k [expr {$ax + 1}] [expr {$ay + 1}]] [tp_less 2.6 $tol] [tp_click k $ax [expr {$ay - 2.6}]] \
              [lrange [pcall xschem object_at $ax [expr {$ay - 6}]] 0 1] [tp_click k $ax [expr {$ay - 6}]]] \
        [list i(rs:n2) 1 i(rs:n2) $lab i(rs:n2)]
    check "TPR22 the wire rule's own answers, point by point against the pin: on the stub 6 units along and 0.7 beside it there it is 1; inside the pin's square it is 0; up the lead, 2.6 and 6 units past the stub's end on the pin, the nearest point of the stub is that end and it is 0; 2.6 units beside the stub and 1 along, outside the square but with the stub's nearest point inside it, it is 0; and 4.5 units beside the stub, past the tolerance, it is 0" \
        [list [pcall ase::ui::sod_wire_near $ax [expr {$ay + 6}] $ax $ay] [pcall ase::ui::sod_wire_near [expr {$ax + 0.7}] [expr {$ay + 6}] $ax $ay] \
              [pcall ase::ui::sod_wire_near [expr {$ax + 1}] [expr {$ay + 1}] $ax $ay] \
              [pcall ase::ui::sod_wire_near $ax [expr {$ay - 2.6}] $ax $ay] [pcall ase::ui::sod_wire_near $ax [expr {$ay - 6}] $ax $ay] \
              [pcall ase::ui::sod_wire_near [expr {$ax + 2.6}] [expr {$ay + 1}] $ax $ay] [pcall ase::ui::sod_wire_near [expr {$ax + 4.5}] [expr {$ay + 6}] $ax $ay]] \
        {1 1 0 0 0 0 0}
    # DECLARED: the label's box reaches within range of the device pin, and off
    # the stub by more than the tolerance that part of the box is the terminal's
    check "TPR23 DECLARED: the box of a net label that reaches within range of a device pin is the TERMINAL's there -- a point inside the label's box, 6 units along the stub and 4.5 units beside it (7.5 from the pin; the object under the cursor is the label), queues RS's terminal -- and the same point moved onto the stub queues the net's voltage" \
        [list [lrange [pcall xschem object_at [expr {$ax + 4.5}] [expr {$ay + 6}]] 0 1] [tp_click k [expr {$ax + 4.5}] [expr {$ay + 6}]] \
              [tp_click k $ax [expr {$ay + 6}]]] \
        [list $lab i(rs:n2) $vstub]
    # the tolerance is a screen distance with a floor in sheet units
    xschem origin - - 4.0
    set wide [list [pcall ase::ui::sod_wire_near [expr {$ax + 4.5}] [expr {$ay + 6}] $ax $ay] [pcall ase::ui::sod_wire_near [expr {$ax + 6.5}] [expr {$ay + 6}] $ax $ay]]
    xschem origin - - 0.2
    set tight [list [pcall ase::ui::sod_wire_near [expr {$ax + 2.4}] [expr {$ay + 6}] $ax $ay] [pcall ase::ui::sod_wire_near [expr {$ax + 2.6}] [expr {$ay + 6}] $ax $ay]]
    check "TPR22b the tolerance is one and a half screen pixels and never under 2.5 units: at 4 units per pixel (6 units) a point 4.5 beside the stub is on it and one 6.5 beside is not; at 0.2 units per pixel (2.5 units) a point 2.4 beside is on it and one 2.6 beside is not" \
        [list $wide $tight] {{1 0} {1 0}}
    # the wires are read only when the answer needs them
    tp_set_radius 30
    set ::tp_xcalls {}
    rename ::xschem ::tp_xschem_real
    proc ::xschem {args} { lappend ::tp_xcalls [lindex $args 0] ; return [uplevel 1 [linsert $args 0 ::tp_xschem_real]] }
    set walked {}
    foreach p [list [list 20000 20000] [list [expr {$ax + 1}] [expr {$ay + 1}]] [list $ax [expr {$ay + 6}]] [list $ax [expr {$ay - 6}]]] {
        set ::tp_xcalls {}
        catch {ase::ui::sod_terminal_at k {*}$p}
        lappend walked [llength [lsearch -all -exact $::tp_xcalls wire_coord]]
    }
    rename ::xschem {}
    rename ::tp_xschem_real ::xschem
    check "TPR22c the sheet's wires are read only when the pin rule needs them, counted as `xschem wire_coord` calls of one pin test: none with no device pin in range, none inside a pin's square, one on the stub (the hit test named that wire and it was enough), and on the lead, where the hit test names the label, one per wire of the sheet" \
        [list $walked [pcall xschem get wires]] {{0 0 1 3} 3}
    tp_home
}

# ---------------------------------------------------------------------------
# TPR, continued — the pin's own square, zoomed far in
# ---------------------------------------------------------------------------
# The pin radius is a distance on the screen.  Zoomed in until it is smaller
# than the 5-unit square a symbol draws for a pin, a corner of that square is
# outside the radius and inside the pin all the same.
group TPR-square {
    tp_home ; tp_switches_reset
    set r [tp_set_radius 1.5]
    lassign [tp_pin R9 P] qx qy
    lassign [tp_pin V1 m] vx vy
    check "TPR24 fixture: the pin radius is pinned to 1.5 units, and the corner point 2 units right of and 2 units below R9's upper pin is farther from the pin's point than that" \
        [list [tp_less 1.49 $r] [tp_less $r 1.51] [tp_less $r [tp_dist $qx $qy [expr {$qx + 2}] [expr {$qy + 2}]]]] {1 1 1}
    set c1 [tp_click k [expr {$qx + 2}] [expr {$qy + 2}]]
    set n1 $::notices
    check "TPR25 A POINT INSIDE THE PIN'S OWN SQUARE IS THE PIN AT ANY ZOOM: that corner point queues R9's terminal and nothing is said; and the corner 2 units right of and 2 above V1's minus pin queues that pin's terminal, not the source's branch current" \
        [list [tp_listed [expr {$qx + 2}] [expr {$qy + 2}] R9 P] $c1 $n1 [tp_click k [expr {$vx + 2}] [expr {$vy - 2}]]] \
        {1 i(r9:n1) {} i(v1:n2)}
    check "TPR26 DECLARED: beyond its square the pin reaches a fixed distance on the SCREEN, so zoomed this far in a point 4 units down R9's lead -- outside the square and outside the radius -- is not the terminal: the body of a resistor queues nothing and says so" \
        [list [pcall ase::ui::sod_terminal_at k $qx [expr {$qy + 4}]] [tp_click k $qx [expr {$qy + 4}]] $::notices] \
        [list {} {} [list $TP_MISS]]
}

# ===========================================================================
# TPD — the click with no coordinates
# ===========================================================================
# The canvas binding calls sod_click with the key alone, so this is the path a
# user is on.  The cursor is put where the row needs it with a MotionNotify
# (event 6) through the engine's own callback: it sets the raw pair and the
# snapped pair together, and no press or release is involved.
group TPD {
    tp_home ; tp_switches_reset
    set z [expr {2.0 / (12.0 * [tp_scale])}]
    xschem origin 100 100 $z
    set r [tp_radius]
    proc tp_move {x y} {
        set z [xschem get zoom]
        set px [expr {int(round(($x + [xschem get xorigin]) / $z))}]
        set py [expr {int(round(($y + [xschem get yorigin]) / $z))}]
        pcall xschem callback .drw 6 $px $py 0 0 0 0
        return [list [xschem get mousex] [xschem get mousey] [xschem get mousex_snap] [xschem get mousey_snap]]
    }
    lassign [tp_pin D1 p] px py
    lassign [tp_move $px $py] rx ry sx sy
    check "TPD0 fixture: the motion put the RAW cursor within a quarter of the pin radius of D1's anode pin (radius 2 units here)" \
        [list [tp_less [tp_dist $rx $ry $px $py] [expr {$r / 4.0}]] [tp_less 1.9 $r] [tp_less $r 2.1]] {1 1 1}
    check "TPD1 the click made with NO coordinates, raw cursor on the pin, queues the terminal" \
        [tp_click k] {i(d1:a)}
    lassign [tp_move $px [expr {$py - 4}]] rx ry sx sy
    check "TPD2 fixture: 4 units up the wire the raw cursor is well outside the pin radius, while the SNAPPED cursor is the pin itself" \
        [list [tp_less [expr {1.5 * $r}] [tp_dist $rx $ry $px $py]] [list $sx $sy]] [list 1 [list $px $py]]
    check "TPD3 ...and that click is NOT a terminal: it queues the voltage of the wire, as it did before pins were picked (a pin test on the snapped cursor would queue the terminal here)" \
        [tp_click k] {v(nd)}
    check "TPD4 with explicit coordinates the pin test uses those, wherever the cursor stands: the same sheet point given by hand IS the terminal" \
        [tp_click k $px $py] {i(d1:a)}
}

# ---------------------------------------------------------------------------
# TPD, continued — the wire rule on the path a user is on: the pin test and the
# wire test read the RAW cursor, the voltage pick that follows the SNAPPED one
# ---------------------------------------------------------------------------
group TPD-wire {
    tp_rev_sheet ; tp_switches_reset
    xschem origin 100 100 1.0
    set r [tp_radius]
    # put the cursor on a sheet point with a MotionNotify: {rawx rawy snapx snapy}
    proc tp_cursor {x y} {
        set z [xschem get zoom]
        set px [expr {int(round(($x + [xschem get xorigin]) / $z))}]
        set py [expr {int(round(($y + [xschem get yorigin]) / $z))}]
        pcall xschem callback .drw 6 $px $py 0 0 0 0
        return [list [xschem get mousex] [xschem get mousey] [xschem get mousex_snap] [xschem get mousey_snap]]
    }
    lassign [tp_pin R1 M] ax ay
    set on [tp_cursor $ax [expr {$ay + 4}]]
    set c1 [tp_click k]
    set in [tp_cursor $ax [expr {$ay + 1}]]
    set c2 [tp_click k]
    check "TPD5 the click the canvas binding makes, on the 20-unit wire: with the raw cursor 4 units along the wire from R1's pin -- inside the pin radius and the 10-unit bound, the SNAPPED cursor being the pin itself -- the click with no coordinates is the wire's voltage; with the raw cursor 1 unit along, inside the pin's square, it is the terminal" \
        [list [tp_less 10 $r] $on $c1 $in $c2] \
        [list 1 [list $ax [expr {$ay + 4}] $ax $ay] [tp_vnet R1 M] \
              [list $ax [expr {$ay + 1}] $ax $ay] i(r1:n2)]
    tp_home
}

# ---------------------------------------------------------------------------
# TPD, continued — where no pixel's centre is on the wire
# ---------------------------------------------------------------------------
# At 1.7 units per pixel, with the origin set so that the stub's axis falls
# midway between two pixel columns, the nearest the raw cursor gets to the stub
# is 0.85 units -- inside the label's box, where the hit test names the label.
group TPD-near {
    tp_geo_sheet ; tp_switches_reset
    lassign [tp_pin RS M] ax ay
    set z 1.7
    xschem origin [expr {$z * 200.5 - $ax}] 100 $z
    set r [tp_radius]
    set row [expr {int(round(($ay + 6 + 100) / $z))}]
    set got {}
    foreach col {200 201} {
        pcall xschem callback .drw 6 $col $row 0 0 0 0
        set rx [xschem get mousex]
        set ry [xschem get mousey]
        lappend got [list [tp_less 0.63 [expr {abs($rx - $ax)}]] [tp_less [expr {abs($rx - $ax)}] 2.5] \
                          [tp_less 2.5 [expr {$ry - $ay}]] [tp_less [expr {$ry - $ay}] 10] \
                          [lrange [pcall xschem object_at $rx $ry] 0 1] \
                          [tp_dist [xschem get mousex_snap] [xschem get mousey_snap] $ax [expr {$ay + 10}]] [tp_click k]]
    }
    set want [list 1 1 1 1 [list instance [tp_inst l_stub]] 0.0 [tp_vnet RS M]]
    check "TPD6 the click the canvas binding makes, a pixel BESIDE the stub: with the cursor put on the pixel column either side of the stub's axis, 6 units along it -- the raw cursor read back is 0.63 units or more off the axis and under 2.5, between 2.5 and 10 units from RS's pin, the object under it is the label, and the snapped cursor is on the stub -- the click with no coordinates queues the stub's voltage, from both columns" \
        [list [tp_less 10 $r] $got] [list 1 [list $want $want]]
    tp_home
}

# ===========================================================================
# TPN — primitive elements
# ===========================================================================
group TPN {
    tp_home ; tp_switches_reset
    tp_set_radius 6
    check "TPN1 the terminal is named by the element's letter and the pin's POSITION on its netlist line: a resistor and a source by n<position>, a bare MOSFET d g s b_tj, a bipolar c b e, a diode a c" \
        [list [tp_at k R1 P] [tp_at k V1 p] [tp_at k V1 m] \
              [tp_at k M1 d] [tp_at k M1 g] [tp_at k M1 s] [tp_at k M1 b] \
              [tp_at k Q1 C] [tp_at k Q1 B] [tp_at k Q1 E] [tp_at k D1 m]] \
        {i(r1:n1) i(v1:n1) i(v1:n2) i(m1:d) i(m1:g) i(m1:s) i(m1:b_tj) i(q1:c) i(q1:b) i(q1:e) i(d1:c)}
    check "TPN2 the letter table itself, position by position: m, q, j, z and d name their terminals, a position past a table and every other letter answer n<position>, and the letter's case does not matter" \
        [list [lmap p {1 2 3 4 5 6 7 8} { pcall ase::ui::sod_term_letter_name m $p }] \
              [lmap p {1 2 3 4 5 6} { pcall ase::ui::sod_term_letter_name Q $p }] \
              [lmap p {1 2 3 4} { pcall ase::ui::sod_term_letter_name j $p }] \
              [lmap p {1 3} { pcall ase::ui::sod_term_letter_name Z $p }] \
              [lmap p {1 2 3} { pcall ase::ui::sod_term_letter_name d $p }] \
              [lmap l {r c l v i e g b} { pcall ase::ui::sod_term_letter_name $l 2 }]] \
        {{d g s b_tj tc n6 n7 n8} {c b e s t n6} {d g s n4} {d s} {a c n3} {n2 n2 n2 n2 n2 n2 n2 n2}}
    check "TPN3 a source's PIN is a terminal and its BODY is still the branch current: the two clicks on V1 queue two different rows" \
        [list [tp_at k V1 p] [tp_click k [lindex [tp_pin V1 p] 0] [expr {[lindex [tp_pin V1 p] 1] + 30}]]] \
        {i(v1:n1) i(v1)}
    check "TPN4 a pin the symbol keeps out of the netlist (spice_ignore=1 on the PIN) takes no position: the pin after it is n2, not n3" \
        [list [tp_at k RG A] [tp_at k RG Y]] {i(rg:n1) i(rg:n2)}
    set g [tp_at k RG NC]
    check "TPN5 ...and a click on that pin itself is REFUSED in one sentence naming the instance and the pin and ending with the ammeter, said as an error: its line does not carry the pin" \
        [list $g [tp_refused RG NC] [string match {*does not carry that pin*} [lindex $::notices 0]] $::ntags] {{} {1 1} 1 error}
    set g [tp_at k RD2 A]
    check "TPN6 a pin written on TWO element lines is refused the same way: the sentence says how many times the format writes it" \
        [list $g [tp_refused RD2 A] [tp_why RD2 A]] {{} {1 1} {its netlist format writes that pin 2 times}}
    set g [tp_at k SU1 A]
    check "TPN7 a word with no width tag ahead of the pin, on an element that is not a subcircuit call, is refused and the sentence quotes the word" \
        [list $g [tp_refused SU1 A] [string match {*has 'ctl' ahead of that pin*} [lindex $::notices 0]]] {{} {1 1} 1}
    set g [tp_at k HX1 A]
    check "TPN8 a line whose first word opens with `#` in a form the netlister's post-processor does not expand is refused, quoting the word" \
        [list $g [tp_refused HX1 A] [string match {*starts with '#HX1'*} [lindex $::notices 0]]] {{} {1 1} 1}
    check "TPN9 the two `#` forms it DOES expand name the element: `#dx#<name>` is dx<name> (a diode by its letter) and `##<name>` is the name" \
        [list [tp_at k m7 A] [tp_at k m7 Y] [tp_at k R7 Y]] {i(dxm7:a) i(dxm7:c) i(r7:n2)}
    check "TPN9b the element is the line's FIRST WORD: an instance carrying spiceprefix=X under a format that does not write the prefix is the bare name, not X<name>" \
        [tp_at k RNP A] {i(rnp:n1)}
    lassign [tp_pin RDU Y] ux uy
    check "TPN9c a pin NAME used twice is written once: clicked on the SECOND pin called A (pin 1 of the symbol, 20 units below its centre) the terminal is where the first stands, and the pin after it is n2, not n3" \
        [list [tp_click k [expr {$ux - 40}] [expr {$uy + 20}]] [tp_get [pcall ase::ui::sod_terminal_at k [expr {$ux - 40}] [expr {$uy + 20}]] pin] [tp_at k RDU Y]] \
        {i(rdu:n1) 1 i(rdu:n2)}
    set ::dlg_answer all
    check "TPN9d a two-bit pin takes two positions: the pin after it is n3, and the pin itself is the two vectors n1 and n2, offered through the bit dialog" \
        [list [tp_at k RB1 Q] [tp_at k RB1 {D[1:0]}] [lindex [lindex $::dlg 0] 2]] \
        {i(rb1:n3) {i(rb1:n1) i(rb1:n2)} {RB1:n1 RB1:n2}}
    check "TPN9e a `+` continuation line belongs to the line above it: the pin written on the continuation is n2 of the same element" \
        [list [tp_at k RC1 A] [tp_at k RC1 Y]] {i(rc1:n1) i(rc1:n2)}
    check "TPN9f a comment line and a card line are not element lines: a pin they repeat is still on ONE element line and is named" \
        [list [tp_at k RI1 A] $::notices] {i(ri1:n1) {}}
    check "TPN9g `@#<n>` names a pin by NUMBER or by NAME: written `@#1 @#A`, pin 1 (Y) stands first and the pin called A second" \
        [list [tp_at k RH1 A] [tp_at k RH1 Y]] {i(rh1:n2) i(rh1:n1)}
    check "TPN9h the colon inside a bus pin's brackets does not make `@#D\[1:0\]` an attribute request: it is the two-bit pin itself -- clicked, it is n1 and n2 -- and the pin after it is n3" \
        [list [tp_at k RB2 {D[1:0]}] [tp_at k RB2 Q]] {{i(rb2:n1) i(rb2:n2)} i(rb2:n3)}
    set g [tp_at k RA1 A]
    check "TPN9i ...while `@#0:net_name` IS an attribute request and stays a word of the line: written ahead of the pins of a primitive it is a word of unknown meaning there, and the pick is refused" \
        [list $g [tp_refused RA1 A] [string match {*ahead of that pin*} [lindex $::notices 0]]] {{} {1 1} 1}
    check "TPN10 an INSTANCE's own format is the line that is read: RIF writes its pins in the other order, so its pin A is n2" \
        [list [tp_at k RIF A] [tp_at k RIF Y]] {i(rif:n2) i(rif:n1)}
    # the format the netlister takes, state by state
    set n [tp_inst RF1]
    set plain [pcall ase::ui::sod_term_format $n]
    set ::lvs_netlist 1
    set lvs [pcall ase::ui::sod_term_format $n]
    set lvsclick [tp_at k RF1 A]
    set lvsfall [pcall ase::ui::sod_term_format [tp_inst R1]]
    set ::lvs_netlist 0
    xschem set format alt_format
    set alt [pcall ase::ui::sod_term_format $n]
    set altclick [tp_at k RF1 A]
    xschem set format {}
    check "TPN11 the format is resolved as the netlister resolves it: plain `format` by default, `lvs_format` under an LVS netlist with plain `format` as the fallback for a symbol that has none, the custom attribute when one is set -- and the pin's position follows the string that is in force (A is n1, then n2 under LVS, then refused under the custom format, which puts an untagged word ahead of it)" \
        [list $plain $lvs $lvsclick $lvsfall $alt $altclick [pcall xschem get format] [tp_at k RF1 A]] \
        [list {{@name @@A @@Y @value} sym} {{@name @@Y @@A @value} sym} i(rf1:n2) \
              {{@name @pinlist @value m=@m} sym} {{@name gnd! @@Y @@A @value} sym} {} <NULL> i(rf1:n1)]
    check "TPN12 where the format comes from is answered with it: the instance's own beats the symbol's, and an attribute that is PRESENT and empty is no format at all (the netlister writes no line), not a reason to ask the symbol" \
        [list [lindex [pcall ase::ui::sod_term_format [tp_inst RIF]] 1] [pcall ase::ui::sod_term_format [tp_inst CE1]] \
              [pcall ase::ui::sod_attr [tp_inst CE1] format] [pcall ase::ui::sod_attr [tp_inst R1] format]] \
        {inst {{} {}} {1 {}} {0 {}}}
    set ::flat_netlist 1
    set g [tp_at k R1 P]
    set ::flat_netlist 0
    check "TPN13 with FLAT netlisting on every pin pick is refused, in the one sentence, and nothing is queued; with it off the same click queues" \
        [list $g [tp_refused R1 P] [string match {*flat netlisting renames every device*} [lindex $::notices 0]] [tp_at k R1 P]] \
        {{} {1 1} 1 i(r1:n1)}
}

group TPN-oneline {
    tp_rev_sheet ; tp_switches_reset
    tp_set_radius 6
    set n [tp_inst M9]
    set lines [pcall ase::ui::sod_term_lines $n [pcall ase::ui::sod_term_rewrite [pcall ase::ui::sod_term_pins $n] \
                                                   [pcall ase::ui::sod_term_pieces [lindex [pcall ase::ui::sod_term_format $n] 0]]]]
    set g [tp_at k M9 S]
    set why [tp_why M9 S]
    check "TPN6b a pin written twice on ONE element line (a source tied to the bulk: D G S S): the format gives one line and the pin stands on it at positions 3 and 4; the click is refused, and the sentence counts the times the pin is written and does not speak of lines" \
        [list [llength $lines] [pcall ase::ui::sod_term_where $lines 2] $g [tp_refused M9 S] $why [string first lines $why]] \
        [list 1 {{M9 3 1 {} nm} {M9 4 1 {} nm}} {} {1 1} {its netlist format writes that pin 2 times} -1]
    check "TPN6c ...while the pins that line writes once are named, by the element's letter" \
        [list [tp_at k M9 D] [tp_at k M9 G]] {i(m9:d) i(m9:g)}
    tp_home
}

# ===========================================================================
# TPX — subcircuit calls
# ===========================================================================
group TPX {
    tp_home ; tp_switches_reset
    tp_set_radius 6
    # ---- the caution: no header anywhere
    set g [tp_at k RW M]
    check "TPX1 a wrapper whose callee has NO header in hand is named by the symbol's pin, and the click says so in one notice that names the callee and ends with what makes the header known" \
        [list $g [llength $::notices] [string match "ase: RW pin M — no .subckt header for 'fake_res' is known*" [lindex $::notices 0]] \
              [string match "*; to be sure, $TP_REMEDY" [lindex $::notices 0]]] \
        {i(xrw:m) 1 1 1}
    # ---- the header in the session's model files
    set st [ase::session_state $TOPKEY]
    dict set st rundir [file join $scratch run]
    dict set st models [list [dict create file $tp_lib section tt]]
    pcall ase::session_update $TOPKEY $st
    set got [list [tp_at $TOPKEY RW M] [tp_at $TOPKEY RW P] [tp_at $TOPKEY RW B]]
    check "TPX2 THE SUBCKT PORT, NEVER THE SYMBOL PIN: with the session's model library naming `.subckt fake_res r0 r1 sub` -- in a cell file the corner file's `tt` section includes by a path relative to itself, the header continued over two lines -- the wrapper's pins M P B are r0 r1 sub, and no caution is said" \
        [list $got $::notices] {{i(xrw:r0) i(xrw:r1) i(xrw:sub)} {}}
    check "TPX2b a call that writes an extra node AHEAD of its pins, named by position against its header: the untagged word counts one node, so pin A is the SECOND port -- and that header is in a second library the corner file pulls one section of (`.lib <file> <section>`), whose other section declares the same name with other ports" \
        [list [tp_at $TOPKEY XE1 A] [tp_at $TOPKEY XE1 Y] $::notices [pcall ase::ui::sod_term_ports $TOPKEY fake_ext]] \
        {i(xe1:in) i(xe1:out) {} {vddx in out}}
    check "TPX3 the reader is SECTION-AWARE: the `ff` section of the same corner file declares a fake_res with other ports, and it was not read" \
        [pcall ase::ui::sod_term_ports $TOPKEY fake_res] {r0 r1 sub}
    check "TPX3b fixture: read whole, the corner file does hold that other header (so TPX3 is about the section and not about a decoy that is not there)" \
        [tp_get [lindex [pcall ase::ui::sod_subckt_scan [pcall apply {{f} { set h [open $f r]; set t [read $h]; close $h; return $t }} $tp_lib] {}] 0] fake_res] \
        {{wrong0 wrong1 wrong2}}
    # ---- the cache
    # the memory is the core's (ase::subckt_lib, src/ase.tcl): this file's three
    # header procs hand their arguments on and keep nothing of their own
    set stamps [tp_get [pcall set ::ase::subckt_cache] stamps]
    check "TPX4 the walk is remembered with the mtime of EVERY file it read: the corner file, the cell file it includes and the library it pulls a section from -- in the core's memory, and this file keeps none of its own" \
        [list [lsort [pcall dict keys $stamps]] [info exists ::ase::ui::sod_subckt_cache]] \
        [list [lsort [list [file normalize $tp_lib] [file normalize $tp_cells] [file normalize $tp_more]]] 0]
    # ONE HEADER READER.  Each of the core's three procs is stood in for by one
    # that answers its own name and arguments, and this file's proc of the same
    # job is asked: it holds no rule of its own exactly when that is its answer.
    foreach p {subckt_scan subckt_walk subckt_lib} {
        tp_stub ::ase::$p args "return \[list CORE $p \$args\]"
    }
    set fwd [list [pcall ase::ui::sod_subckt_scan TEXT SEC] [pcall ase::ui::sod_subckt_walk CARDS] \
                  [pcall ase::ui::sod_subckt_lib CARDS]]
    foreach p {subckt_scan subckt_walk subckt_lib} { tp_unstub ::ase::$p }
    check "TPX4b ONE HEADER READER: this file's three header procs hand their arguments to the core's (ase::subckt_scan, ase::subckt_walk, ase::subckt_lib) and answer what those answer -- with each of the core's stood in for by a proc that answers its own name and arguments, that is what comes back -- and with the core's own back in place they read a header again" \
        [list $fwd [tp_get [lindex [pcall ase::ui::sod_subckt_scan ".subckt back b0 b1\n.ends" {}] 0] back]] \
        [list {{CORE subckt_scan {TEXT SEC}} {CORE subckt_walk CARDS} {CORE subckt_lib CARDS}} {{b0 b1}}]
    # ...and the list of model files is the core's too: with its assembly stood
    # in for by one that names a file no row of the session names, the header
    # lookup reads THAT file
    wfile [file join $tpmod core_only.spice] ".subckt fake_core_only c0 c1\n.ends"
    set ::tp_cards_asked {}
    tp_stub ::ase::subckt_model_cards {state netlist_text} {
        lappend ::tp_cards_asked [list [expr {$state eq [ase::session_state $::TOPKEY]}] $netlist_text]
        return [list [list [file join $::tpmod core_only.spice] {}]]
    }
    set viacore [pcall ase::ui::sod_term_ports $TOPKEY fake_core_only]
    tp_unstub ::ase::subckt_model_cards
    check "TPX4c ...and the MODEL FILES the lookup follows are the core's list (ase::subckt_model_cards, the one the deck side reads a numbered port's position through): with that proc stood in for by one naming a file no row of this session names, the lookup is asked once with the session's state and the netlist text in hand (none here: nothing is netlisted) and answers that file's header; with the core's own back, the session's rows do not reach that file" \
        [list $viacore $::tp_cards_asked [pcall ase::ui::sod_term_ports $TOPKEY fake_core_only]] \
        {{c0 c1} {{1 {}}} {}}
    # (the last leg above walked the session's own cards again, so the memory
    # TPX5 is about holds them, as it did before the stand-in)
    set mt [file mtime $tp_cells]
    wfile $tp_cells [string map {{r0 r1} {z0 z1}} $TP_CELLS]
    file mtime $tp_cells $mt
    set same [tp_at $TOPKEY RW M]
    file mtime $tp_cells [expr {$mt + 7}]
    set moved [tp_at $TOPKEY RW M]
    wfile $tp_cells $TP_CELLS
    file mtime $tp_cells [expr {$mt + 14}]
    check "TPX5 ...and re-done when a file it read changes: the cell file rewritten with other port names under the SAME mtime still answers from memory, under a new mtime it is read again, and put back it answers as before" \
        [list $same $moved [tp_at $TOPKEY RW M]] {i(xrw:r0) i(xrw:z0) i(xrw:r0)}
    # ---- the deck's callee, where it is not the live one
    rename ::op_annot::model_netlist ::op_annot::tp_real_model_netlist
    proc ::op_annot::model_netlist {instname {livevar {}}} {
        if {$livevar ne {}} { upvar 1 $livevar live }
        set live [xschem translate $instname @model]
        return fake_res2
    }
    set got [tp_at $TOPKEY RW M]
    rename ::op_annot::model_netlist {}
    rename ::op_annot::tp_real_model_netlist ::op_annot::model_netlist
    check "TPX6 the callee looked up is the one THE DECK builds the device with: with `op_annot::model_netlist` answering another model than the live one, that model's header names the port -- and the authority was put back" \
        [list $got [tp_at $TOPKEY RW M]] {i(xrw:q0) i(xrw:r0)}
    # ---- where a model path is taken from
    file mkdir [file join $scratch run]
    wfile [file join $scratch run rel_inc.spice] ".subckt fake_rel p0 p1\n.ends"
    set ::TP_MODDIR $tpmod
    wfile [file join $tpmod var_inc.spice] ".subckt fake_var v0 v1\n.ends"
    set stp $st
    dict set stp includes [list rel_inc.spice [dict create file {$::TP_MODDIR/var_inc.spice}]]
    pcall ase::session_update $TOPKEY $stp
    check "TPX6b an `includes` row is read in both of its forms, each path as the deck will carry it: a bare RELATIVE path is taken from the session's run directory, and a {file ...} row written with a Tcl variable is expanded" \
        [list [tp_at $TOPKEY XE2 A] [tp_at $TOPKEY XE2 Y] [pcall ase::ui::sod_term_ports $TOPKEY fake_var]] \
        {i(xe2:p0) i(xe2:p1) {v0 v1}}
    pcall ase::session_update $TOPKEY $st
    # ---- the symbol's own block
    set st2 $st
    dict set st2 includes [list [file join $tpmod decoy.spice]]
    wfile [file join $tpmod decoy.spice] ".subckt tp_blk zz1 zz2\n.ends"
    pcall ase::session_update $TOPKEY $st2
    set got [list [tp_at $TOPKEY xb A] [tp_at $TOPKEY xb Y]]
    check "TPX7 a block xschem writes the body of from the SAME symbol is named by the symbol's pins and no header is asked: an included file declaring `.subckt tp_blk zz1 zz2` changes nothing, and no caution is said" \
        [list $got $::notices [pcall ase::ui::sod_term_ports $TOPKEY tp_blk]] {{i(xb:a) i(xb:y)} {} {zz1 zz2}}
    wfile [file join $tpmod decoy2.spice] ".subckt tp_blk yy1 yy2\n.ends"
    dict set st2 includes [list [file join $tpmod decoy.spice] [file join $tpmod decoy2.spice]]
    pcall ase::session_update $TOPKEY $st2
    check "TPX7b TWO different headers for one name are no header: with a second included file declaring `.subckt tp_blk yy1 yy2` the ports of tp_blk are not known, rather than the first file's" \
        [pcall ase::ui::sod_term_ports $TOPKEY tp_blk] {}
    # ---- a header that cannot name the port, and why: several, or one too short
    wfile [file join $tpmod dup_a.spice] ".subckt fake_res a0 a1 a2\n.ends\n.subckt fake_rel p0 p1\n.ends"
    wfile [file join $tpmod dup_b.spice] ".subckt fake_res b0 b1 b2\n.ends\n.subckt fake_rel q0 q1\n.ends"
    wfile [file join $tpmod short.spice] ".subckt fake_res only0\n.ends\n.subckt fake_rel only0\n.ends"
    set st5 $st
    dict set st5 models {}
    dict set st5 includes [list [file join $tpmod dup_a.spice] [file join $tpmod dup_b.spice]]
    pcall ase::session_update $TOPKEY $st5
    set lists [pcall ase::ui::sod_term_port_lists $TOPKEY fake_res]
    set g [tp_at $TOPKEY RW M]
    set gn $::notices
    set g2 [tp_at $TOPKEY XE2 A]
    set why2 [tp_why XE2 A]
    dict set st5 includes [list [file join $tpmod dup_a.spice]]
    pcall ase::session_update $TOPKEY $st5
    set one [list [tp_at $TOPKEY RW M] $::notices [tp_at $TOPKEY XE2 A] $::notices]
    check "TPX7c TWO DIFFERENT HEADERS ARE NOT `NO HEADER`: with two model files of the session declaring fake_res with different ports, the lookup holds both lists under the place `models`; the wrapper's pin is queued under the symbol's pin name, and its ONE notice says that several headers differ, that the simulator uses one of them, and to leave one definition under Setup > Model Files -- it does not say that none is known" \
        [list $lists $g [llength $gn] [lindex $gn 0] [string first {no .subckt header} [lindex $gn 0]]] \
        [list {models {{a0 a1 a2} {b0 b1 b2}}} i(xrw:m) 1 \
              "ase: RW pin M — the session's model files hold more than one .subckt header for 'fake_res' and their ports differ, so the terminal is named as the symbol's pin; that is right only if the subcircuit the simulator uses names its ports the same way; to be sure, leave one definition of 'fake_res' in the model files (Setup > Model Files), then pick again" -1]
    check "TPX7d ...a call with a format of its own is REFUSED there, for that reason and with that remedy; and with ONE of the two files named, the wrapper and the call are named from its header and nothing is said" \
        [list $g2 $why2 $one] \
        [list {} "it has a netlist format of its own, and the session's model files hold more than one .subckt header for 'fake_rel' and their ports differ, so the port at that position is not known; to name it, leave one definition of 'fake_rel' in the model files (Setup > Model Files), then pick again" \
              {i(xrw:a0) {} i(xe2:p0) {}}]
    dict set st5 includes [list [file join $tpmod short.spice]]
    pcall ase::session_update $TOPKEY $st5
    set s1 [tp_at $TOPKEY RW M]
    set s1n $::notices
    set s2 [tp_at $TOPKEY RW P]
    set s2n $::notices
    set s3 [tp_at $TOPKEY XE2 Y]
    set s3why [tp_why XE2 Y]
    pcall ase::session_update $TOPKEY $st
    check "TPX7e ONE HEADER THAT IS TOO SHORT is not `no header` either: with a header of one port, the wrapper's first pin is that port and nothing is said; its second pin is queued under the symbol's pin name with a notice giving the header's port count against the pin's place on the call line; and the call with a format of its own is refused for its second pin with the same count" \
        [list $s1 $s1n $s2 $s2n $s3 $s3why] \
        [list i(xrw:only0) {} i(xrw:p) \
              [list "ase: RW pin P — the .subckt header known for 'fake_res' has 1 port, too few for that pin, which is node 2 of the call, so the terminal is named as the symbol's pin; that is right only if the subcircuit the simulator uses names its ports the same way; to be sure, $TP_REMEDY"] \
              {} "it has a netlist format of its own, and the .subckt header known for 'fake_rel' has 1 port, too few for that pin, which is node 2 of the call, so the port at that position is not known; to name it, $TP_REMEDY"]
    check "TPX8 what makes it that block, condition by condition on the fixture: a subcircuit symbol with the symbol's format is; an instance format, a spice_sym_def, a `spice_primitive`, a `default_schematic=ignore` and a symbol that is not a subcircuit are not; and a library pattern in `xschem_libs` matching the symbol's path takes it out" \
        [list [pcall ase::ui::sod_term_own_block [tp_inst xb] sym] [pcall ase::ui::sod_term_own_block [tp_inst xb] inst] \
              [pcall ase::ui::sod_term_own_block [tp_inst x2sd] sym] [pcall ase::ui::sod_term_own_block [tp_inst xprim] sym] \
              [pcall ase::ui::sod_term_own_block [tp_inst xdsi] sym] [pcall ase::ui::sod_term_own_block [tp_inst RW] sym] \
              [pcall apply {{n} { set ::xschem_libs [list {/tplib/}] ; set r [ase::ui::sod_term_own_block $n sym] ; set ::xschem_libs {} ; return $r }} [tp_inst xb]]] \
        {1 0 0 0 0 0 0}
    set g [tp_at k xprim A]
    check "TPX8b ...so a `spice_primitive` call, whose body xschem does not write, is named by its pin WITH the caution while no header is known" \
        [list $g [llength $::notices] [string match "ase: xprim pin A — no .subckt header for 'tp_prim' is known*" [lindex $::notices 0]]] {i(xprim:a) 1 1}
    # ---- a call line written from the instance's own format
    set g [tp_at $TOPKEY xswap A]
    check "TPX9 a block whose INSTANCE brings its own format (it writes Y first) is REFUSED while no header is in hand: its pin order is not the header's, so the pin's own name would name the other port" \
        [list $g [tp_refused xswap A] [string match {*has a netlist format of its own*} [lindex $::notices 0]]] {{} {1 1} 1}
    set deck [file join $scratch run tp_top.spice]
    file mkdir [file dirname $deck]
    wfile [file join $tpmod deck_inc.spice] ".subckt fake_dk k0 k1\n.ends"
    set nodeck [tp_at $TOPKEY XE3 A]
    wfile $deck "** sch_path: $tp_top\n.subckt tp_blk A Y\nR1 A Y 1k\n.ends\n.include [file join $tpmod deck_inc.spice]\n.end"
    pcall ase::facts_capture [ase::session_state $TOPKEY] $deck
    set got [list [tp_at $TOPKEY xswap A] [tp_at $TOPKEY xswap Y]]
    check "TPX10 ...and with the netlist ASE-L last made in hand (warm), it is named BY POSITION against that netlist's header: pin A stands second on the line and the second port of `.subckt tp_blk A Y` is Y" \
        [list [tp_get [pcall ase::facts_status [ase::session_state $TOPKEY]] state] $got] {warm {i(xswap:y) i(xswap:a)}}
    check "TPX10b an `.include` line that netlist carries is followed like the session's own model rows: a callee whose header is only in the file it names is refused before the netlist is in hand and named after" \
        [list $nodeck [tp_at $TOPKEY XE3 A] [tp_at $TOPKEY XE3 Y]] {{} i(xe3:k0) i(xe3:k1)}
    wfile $deck "** sch_path: $tp_top\n.subckt tp_blk A Y\nR1 A Y 1k\n.ends\n* touched\n.end"
    set g [tp_at $TOPKEY xswap A]
    check "TPX11 a netlist file that has MOVED since it was taken no longer gives its headers: the same click is refused again" \
        [list [tp_get [pcall ase::facts_status [ase::session_state $TOPKEY]] state] $g [tp_refused xswap A]] {stale {} {1 1}}
    pcall ase::facts_clear
    # ---- spice_sym_def
    check "TPX12 a block netlisted through a `spice_sym_def`, written with `@pinlist`, whose header lists only pins of the symbol: the netlister writes the nets in the HEADER's order, so the terminal is the header port NAMED as the pin, in the header's spelling -- the ports are `q P N` and the pins N P Q, so pin N is port N (not the first port) and pin Q is the port spelled `q`" \
        [list [pcall ase::ui::sod_term_name k [tp_inst x2sd] 0] [tp_get [pcall ase::ui::sod_term_name k [tp_inst x2sd] 2] tokens] \
              [tp_at k x2sd N] [tp_at k x2sd Q] $::notices] \
        [list [dict create ok 1 tokens x2sd:N label x2sd:N caution {}] x2sd:q i(x2sd:n) i(x2sd:q) {}]
    check "TPX13 ...a header listing a port that is NO pin of the symbol is not adopted -- the symbol's order stands -- and the terminal is the port AT THE POSITION: with `.subckt tp_sd2 q P zz`, pin N stands first and is port q, pin Q third and is port zz" \
        [list [tp_at k x3sd N] [tp_at k x3sd P] [tp_at k x3sd Q] $::notices] {i(x3sd:q) i(x3sd:p) i(x3sd:zz) {}}
    check "TPX13b ...and a format that names its pins one by one is never reordered: written Q N P against `.subckt tp_sd3 q P N`, pin N stands second and is port P, pin P third and is port N" \
        [list [tp_at k x4sd N] [tp_at k x4sd P] [tp_at k x4sd Q] $::notices] {i(x4sd:p) i(x4sd:n) i(x4sd:q) {}}
    set g [tp_at k x5sd N]
    check "TPX13c ...while a definition that gives NO header (it includes a file that is not there) is refused: neither the pin's name nor a caution stands in for it" \
        [list $g [tp_refused x5sd N] [string match {*has a spice_sym_def, and no .subckt header for 'tp_sd4'*} [lindex $::notices 0]]] {{} {1 1} 1}
    # ---- several vectors: the bit dialog
    set bits {{xbus[1]:D[1]} {xbus[1]:D[0]} {xbus[0]:D[1]} {xbus[0]:D[0]}}
    set ::dlg_answer all
    set all [tp_at k {xbus[1:0]} {D[1:0]}]
    check "TPX14 a bus instance times a bus pin is one vector per instance bit and pin bit: the bit dialog is opened ONCE, is handed the final tokens as its bits -- the extra node ahead of the pin list is counted, the port names are the pin's bits -- and every bit it returns is queued in its order" \
        [list $::dlg $all] \
        [list [list [list k {xbus[1:0]:D[1:0]} $bits]] {{i(xbus[1]:d[1])} {i(xbus[1]:d[0])} {i(xbus[0]:d[1])} {i(xbus[0]:d[0])}}]
    set ::dlg_answer {3 0}
    set some [tp_at k {xbus[1:0]} {D[1:0]}]
    set ::dlg_answer none
    set none [tp_at k {xbus[1:0]} {D[1:0]}]
    set ::dlg_answer all
    check "TPX15 the dialog's answer is queued as it comes back -- two bits in the order it gave them -- and Cancel queues nothing and says nothing" \
        [list $some $none $::notices] {{{i(xbus[0]:d[0])} {i(xbus[1]:d[1])}} {} {}}
    set q [tp_at k {xbus[1:0]} Q]
    check "TPX16 a scalar pin of the bus instance is still two vectors, one per instance bit, through the same dialog" \
        [list [lindex [lindex $::dlg 0] 2] $q] {{{xbus[1]:Q} {xbus[0]:Q}} {{i(xbus[1]:q)} {i(xbus[0]:q)}}}
    set g [tp_at k R1 P]
    check "TPX17 a single vector opens no dialog" [list $g $::dlg] {i(r1:n1) {}}
    # ---- the in-tree PDK
    set sky [file join $repo sky130A models libs.tech combined sky130.lib.spice]
    if {![file isfile $sky]} {
        puts "SKIPPED: TPX18 -- no sky130 model library at $sky, so the row against the real PDK files did not run"
    } else {
        set st3 $st
        dict set st3 models [list [dict create file $sky section tt]]
        pcall ase::session_update $TOPKEY $st3
        set got [list [tp_at $TOPKEY RSK M] [tp_at $TOPKEY RSK P] [tp_at $TOPKEY RSK B]]
        pcall ase::session_update $TOPKEY $st
        check "TPX18 against the PDK's own files: a wrapper calling sky130_fd_pr__res_xhigh_po_0p35, under a session whose model is the in-tree sky130 library's `tt` section, has the terminals r0 r1 sub and no caution" \
            [list $got $::notices] {{i(xrsk:r0) i(xrsk:r1) i(xrsk:sub)} {}}
    }
}

# ---------------------------------------------------------------------------
# TPX, continued — where a header is found before anything is netlisted and
# after the netlist has gone stale; more of the model-file reader; ports that
# are numbers.  All on the second sheet, under its own session.
# ---------------------------------------------------------------------------
group TPX-rev {
    tp_rev_sheet ; tp_switches_reset
    tp_set_radius 6
    pcall ase::facts_clear
    check "TPX19 fixture: the second sheet is the registered cellview its session is bound to, at level 0, and nothing has been netlisted (the facts are cold)" \
        [list [pcall ase::design_of_path [file normalize $tp_rev]] [pcall ase::ui::sod_base_level $REVKEY] \
              [tp_get [pcall ase::facts_status [pcall ase::session_state $REVKEY]] state]] \
        {{tplib tp_rev schematic} 0 cold}
    set fp_cold [pcall ase::facts_netlist_file [pcall ase::session_state $REVKEY]]
    # ---- the header in a device_model
    set got [list [tp_at $REVKEY XDM A] [tp_at $REVKEY XDM Y]]
    set gn $::notices
    check "TPX20 a call whose INSTANCE carries the callee's header in its `device_model` is named from it with nothing netlisted and no model file holding it: the two pins are the header's two ports and no caution is said -- also with no session at all -- and the header lookup finds it only when it is told the instance" \
        [list $got $gn [tp_at k XDM A] [pcall ase::ui::sod_term_ports $REVKEY fake_dm [tp_inst XDM]] [pcall ase::ui::sod_term_ports $REVKEY fake_dm]] \
        {{i(xdm:dm0) i(xdm:dm1)} {} i(xdm:dm0) {dm0 dm1} {}}
    set a1 [list [tp_at $REVKEY XSD A] [tp_at $REVKEY XSD Y]]
    set a1n $::notices
    set a2 [list [tp_at $REVKEY XSI A] [tp_at $REVKEY XSI Y]]
    set a2n $::notices
    check "TPX20b the SYMBOL's `device_model` answers for an instance that has none, and an instance's own stands in its place: the same symbol twice, the second instance with a `device_model` of its own that declares other ports" \
        [list $a1 $a1n $a2 $a2n] {{i(xsd:s0) i(xsd:s1)} {} {i(xsi:i0) i(xsi:i1)} {}}
    check "TPX20c a `device_model` that only INCLUDES a file is followed into it, its bare relative path taken from the session's run directory" \
        [list [tp_at $REVKEY XDF A] [tp_at $REVKEY XDF Y] $::notices] {i(xdf:f0) i(xdf:f1) {}}
    # ---- with nothing netlisted: the caution and the refusal say what to do
    set g [tp_at $REVKEY RWN M]
    set cn $::notices
    set g2 [tp_at $REVKEY XE4 A]
    set why [tp_why XE4 A]
    check "TPX21 with nothing netlisted, a wrapper whose header is only in a file the NETLIST would name is the symbol's pin with the caution, and a call with a format of its own is refused: both sentences end with what makes the header known" \
        [list $g [llength $cn] [string match "ase: RWN pin M — no .subckt header for 'fake_nl' is known*; to be sure, $TP_REMEDY" [lindex $cn 0]] \
              $g2 [string match "it has a netlist format of its own, and no .subckt header for 'fake_nlib' is known*; to get one, $TP_REMEDY" $why]] \
        {i(xrwn:m) 1 1 {} 1}
    # ---- the netlist ASE-L made: warm
    wfile $tp_rev_deck $TP_REV_DECK
    pcall ase::facts_capture [pcall ase::session_state $REVKEY] $tp_rev_deck
    set warm [tp_get [pcall ase::facts_status [pcall ase::session_state $REVKEY]] state]
    set fp_warm [pcall ase::facts_netlist_file [pcall ase::session_state $REVKEY]]
    set w1 [list [tp_at $REVKEY RWN M] [tp_at $REVKEY RWN P] [tp_at $REVKEY RWN B]]
    set w1n $::notices
    set w2 [list [tp_at $REVKEY XE4 A] [tp_at $REVKEY XE4 Y]]
    set w3 [list [tp_at $REVKEY XW1 A] [tp_at $REVKEY XW1 Y]]
    check "TPX22 WARM, the netlist ASE-L made in hand: the wrapper is named from the file that netlist `.include`s, with no caution, and a call whose header is written in the netlist itself is named from it" \
        [list $warm $w1 $w1n $w3] {warm {i(xrwn:nl0) i(xrwn:nl1) i(xrwn:nlsub)} {} {i(xw1:p) i(xw1:q)}}
    check "TPX10c a `.lib <file> <section>` card of that netlist is followed like its `.include` card: the callee is named from the section the card asks for, and the same library's other section, which declares the name with other ports, is not read" \
        [list $w2 [pcall ase::ui::sod_term_ports $REVKEY fake_nlib]] {{i(xe4:a0) i(xe4:a1)} {a0 a1}}
    check "TPX23 TWO different headers for one callee IN the warm netlist are no header: that callee's ports are not known, while the callee the same netlist declares once is answered" \
        [list [pcall ase::ui::sod_term_ports $REVKEY fake_two] [pcall ase::ui::sod_term_ports $REVKEY fake_inl]] {{} {p q}}
    set t1 [tp_at $REVKEY XT1 A]
    set t1why [tp_why XT1 A]
    check "TPX23b ...and a call into that callee says so: the lookup holds the two lists under the place `netlist`, and the click is refused because the design's netlist holds several headers that differ, with the remedy for a netlist -- not because none is known" \
        [list [pcall ase::ui::sod_term_port_lists $REVKEY fake_two] $t1 $t1why] \
        [list {netlist {{a b} {c d}}} {} "it has a netlist format of its own, and the design's netlist holds more than one .subckt header for 'fake_two' and their ports differ, so the port at that position is not known; to name it, leave one definition of 'fake_two' in the design, netlist it from ASE-L (or run), then pick again"]
    set d2 [tp_at $REVKEY XD2 A]
    set d2why [tp_why XD2 A]
    check "TPX20d two different headers of the callee in the instance's own `device_model`: the lookup holds them under the place `device_model` when it is told the instance, and the click is refused with the remedy for that text" \
        [list [pcall ase::ui::sod_term_port_lists $REVKEY fake_dm2 [tp_inst XD2]] $d2 $d2why] \
        [list {device_model {{da db} {dc dd}}} {} "it has a netlist format of its own, and its device_model holds more than one .subckt header for 'fake_dm2' and their ports differ, so the port at that position is not known; to name it, leave one definition of 'fake_dm2' in that device_model, then pick again"]
    # ---- the sheet's file gets a new stamp, as a save gives it: the facts are
    # ---- stale and the netlist file has not moved
    set mt [file mtime $tp_rev]
    file mtime $tp_rev [expr {$mt + 7}]
    set stale [pcall ase::facts_status [pcall ase::session_state $REVKEY]]
    set s1 [list [tp_at $REVKEY RWN M] [tp_at $REVKEY RWN P] [tp_at $REVKEY RWN B]]
    set s1n $::notices
    set s2 [tp_at $REVKEY XE4 A]
    set s3 [tp_at $REVKEY XW1 A]
    set s3r [tp_refused XW1 A]
    set s4 [pcall ase::ui::sod_term_ports $REVKEY fake_inl]
    set fp_stale [pcall ase::facts_netlist_file [pcall ase::session_state $REVKEY]]
    set fp_stale_cards [pcall ase::ui::sod_term_stale_cards [pcall ase::session_state $REVKEY]]
    file mtime $tp_rev $mt
    check "TPX24 STALE, the sheet's file re-stamped since the netlist was taken: the files that netlist names are still followed -- the wrapper and the `.lib` call are named as they were warm, with no caution -- while the header written IN the netlist is not used any more, so the call that needed it is refused; and with the sheet's stamp put back the facts are warm again" \
        [list [tp_get $stale state] [tp_get $stale why] $s1 $s1n $s2 $s3 $s3r $s4 \
              [tp_get [pcall ase::facts_status [pcall ase::session_state $REVKEY]] state]] \
        {stale schmoved {i(xrwn:nl0) i(xrwn:nl1) i(xrwn:nlsub)} {} i(xe4:a0) {} {1 1} {} warm}
    # ---- the slot holds another design's netlist
    pcall ase::facts_capture [pcall ase::session_state $TOPKEY] $tp_rev_deck
    set o [tp_at $REVKEY RWN M]
    set on [llength $::notices]
    set fp_other [pcall ase::facts_netlist_file [pcall ase::session_state $REVKEY]]
    set fp_owner [pcall ase::facts_netlist_file [pcall ase::session_state $TOPKEY]]
    pcall ase::facts_clear
    check "TPX25 a netlist taken for ANOTHER design is not followed: with the same file captured for the top sheet's session, the wrapper here is the symbol's pin with the caution again" \
        [list $o $on] {i(xrwn:m) 1}
    check "TPX25b WHICH FILE THAT IS, is the core's to say (ase::facts_netlist_file): nothing while nothing is netlisted; the netlist file while the facts are warm AND once they are stale; nothing for a session whose design the netlist was not taken for, while the session it was taken for is answered" \
        [list $fp_cold $fp_warm $fp_stale $fp_other $fp_owner] \
        [list {} [file normalize $tp_rev_deck] [file normalize $tp_rev_deck] {} [file normalize $tp_rev_deck]]
    # the stale-cards reader ASKS that proc and does not read the slot itself:
    # with it stood in for by one naming another file, that file's cards are
    # what comes back
    wfile [file join $tpmod stale_other.spice] ".include other_inc.spice\n.lib other.lib sec\n.subckt in_text a b\n.ends"
    tp_stub ::ase::facts_netlist_file {state} { return [file join $::tpmod stale_other.spice] }
    set viaproc [pcall ase::ui::sod_term_stale_cards [pcall ase::session_state $REVKEY]]
    tp_unstub ::ase::facts_netlist_file
    check "TPX25c the cards of a stale netlist are read off the file THAT PROC names -- stood in for by one naming another file, that file's two cards come back and nothing else of it -- the reader's body does not name the slot; on the real stale state above it answered the netlist's own two cards; and now that the slot is empty it answers none" \
        [list $viaproc [string first netlist_facts_slot [info body ::ase::ui::sod_term_stale_cards]] $fp_stale_cards \
              [pcall ase::ui::sod_term_stale_cards [pcall ase::session_state $REVKEY]]] \
        [list {{other_inc.spice {}} {other.lib sec}} -1 [list [list $tp_nl_inc {}] [list $tp_nl_sec one]] {}]
    # ---- the session's model files
    check "TPX26 a cell file reached through an `.inc` line, whose header carries `params:` after its ports: the ports stop there, and the call is named from them" \
        [list [pcall ase::ui::sod_term_ports $REVKEY fake_par] [tp_at $REVKEY XP1 A] [tp_at $REVKEY XP1 Y] $::notices] \
        {{pa pb} i(xp1:pa) i(xp1:pb) {}}
    check "TPX27 a `.subckt` standing AFTER the asked section's `.endl` and before the next `.lib` is not read: the section's own header is answered and the one behind it is not -- and read whole, the file does hold it" \
        [list [pcall ase::ui::sod_term_ports $REVKEY fake_sec] [pcall ase::ui::sod_term_ports $REVKEY fake_after] \
              [tp_get [lindex [pcall ase::ui::sod_subckt_scan $TP_REV_SEC {}] 0] fake_after]] \
        {{s0 s1} {} {{x0 x1}}}
    check "TPX28 PORTS THAT ARE NUMBERS are queued under their names -- not refused, and not turned into positions: with `.subckt fake_num 3 2 7 4 6` the pin at position 1 is the port called 3, the pin at position 2 the port called 2, and nothing is said" \
        [list [pcall ase::ui::sod_term_ports $REVKEY fake_num] [tp_at $REVKEY XN1 A] $::notices [tp_at $REVKEY XN1 Y] $::notices] \
        {{3 2 7 4 6} i(xn1:3) {} i(xn1:2) {}}
    tp_home
}

group TPX-geo {
    tp_geo_sheet ; tp_switches_reset
    tp_set_radius 6
    set q [tp_at k x6sd Q]
    set qn $::notices
    set g [tp_at k x6sd N]
    check "TPX13d a `spice_sym_def` whose header is TOO SHORT for the call line (one port, three nodes written pin by pin): the pin that stands first is that port; the pin that stands second is refused, with the header's port count against the pin's place on the line and the remedy for a definition -- not because none is known" \
        [list $q $qn $g [tp_why x6sd N]] \
        [list i(x6sd:q) {} {} "it has a spice_sym_def, and the .subckt header known for 'tp_sd6' has 1 port, too few for that pin, which is node 2 of the call, so the port at that position is not known; to name it, give the .subckt header in its spice_sym_def a port for every node of the call, then pick again"]
    tp_home
}

# ===========================================================================
# TPH — below the top
# ===========================================================================
group TPH {
    tp_home ; tp_switches_reset
    xschem unselect_all; xschem select instance [tp_inst {xbus[1:0]}]
    pcall xschem descend 2
    tp_set_radius 6
    check "TPH1 a pick made inside bit 0 of a bus instance (level 1, path .xbus\[0\]. asserted first) carries that bit in its path" \
        [list [pcall xschem get currsch] [pcall xschem get sch_path] [tp_at $TOPKEY R1 P]] \
        {1 {.xbus[0].} {{i(xbus[0].r1:n1)}}}
    tp_home
    # ---- a spiceprefix on a block above the sheet (issue 0488)
    xschem unselect_all; xschem select instance [tp_inst SUB1]; pcall xschem descend
    tp_set_radius 6
    set g [tp_at $TOPKEY R1 P]
    check "TPH2 inside a block whose instance takes a `spiceprefix` from its symbol's template -- from that template's second line -- (the sheet path says .SUB1., the deck says XSUB1) the pick is REFUSED in the one sentence, naming the block" \
        [list [pcall xschem get sch_path] $g [tp_refused R1 P] [string match {*block instance 'SUB1' above this sheet carries a spiceprefix*} [lindex $::notices 0]]] \
        {.SUB1. {} {1 1} 1}
    set ::spiceprefix 0
    set off [tp_at $TOPKEY R1 P]
    set ::spiceprefix 1
    check "TPH3 ...and with the `spiceprefix` switch off no element takes a prefix, so the same click queues" $off {i(sub1.r1:n1)}
    xschem unselect_all; xschem select instance [tp_inst xin]; pcall xschem descend
    tp_set_radius 6
    set g [tp_at $TOPKEY R1 P]
    check "TPH4 the prefixed block TWO levels up is found as well: one level further down, inside a block that has no prefix of its own, the pick is still refused for SUB1" \
        [list [pcall xschem get currsch] [pcall xschem get sch_path] $g [tp_refused R1 P] \
              [pcall ase::ui::sod_term_prefixed_ancestor $TOPKEY]] \
        {2 .SUB1.xin. {} {1 1} SUB1}
    tp_home
    xschem unselect_all; xschem select instance [tp_inst SUB2]; pcall xschem descend
    tp_set_radius 6
    check "TPH5 an instance that sets `spiceprefix` to NOTHING overrides the template: inside it the pick queues, with the instance's name as the path" \
        [list [pcall xschem get sch_path] [tp_at $TOPKEY R1 P] $::notices] {.SUB2. i(sub2.r1:n1) {}}
    tp_home
    # ---- the committed 3-level fixture: top -> x1 (mid) -> x2 (leaf)
    xschem load [file join $hierlib ase_hier_top.sch]
    set HTOP [pcall ase::new_session hierlib ase_hier_top schematic]
    set HMID [pcall ase::new_session hierlib ase_hier_mid schematic]
    tp_mode $HTOP outputs ; tp_mode $HMID outputs
    xschem unselect_all; xschem select instance x1; xschem descend
    xschem unselect_all; xschem select instance x2; xschem descend
    tp_set_radius 6
    check "TPH6 fixture: two levels down the committed hierarchy, and the two sessions sit at levels 0 and 1 of this stack" \
        [list [pcall xschem get currsch] [pcall xschem get sch_path] [pcall ase::ui::sod_base_level $HTOP] [pcall ase::ui::sod_base_level $HMID]] \
        {2 .x1.x2. 0 1}
    check "TPH7 the path is measured from the SESSION's own design: the same two pins are x1.x2.<element> under the top session and x2.<element> under the session bound to the mid cell, and nothing is refused (no block above carries a prefix)" \
        [list [tp_at $HTOP R1 P] [tp_at $HTOP V1 p] [tp_at $HMID R1 P] [tp_at $HMID V1 p] $::notices] \
        {i(x1.x2.r1:n1) i(x1.x2.v1:n1) i(x2.r1:n1) i(x2.v1:n1) {}}
    lassign [tp_pin R1 M] mx my
    check "TPH8 a device pin and a ground symbol's pin on the SAME point: the device wins the tie and the terminal is queued (the probe lists both pins there)" \
        [list [llength [pcall xschem pin_at $mx $my -all]] [tp_at $HTOP R1 M]] {2 i(x1.x2.r1:n2)}
    xschem go_back; xschem go_back
    pcall ase::session_close $HMID
    pcall ase::session_close $HTOP
    tp_home
}

group TPH-mid {
    tp_home ; tp_switches_reset
    xschem unselect_all; xschem select instance [tp_inst SUB1]; pcall xschem descend
    tp_set_radius 6
    set term [pcall ase::ui::sod_terminal_at $TOPKEY {*}[tp_pin R1 P]]
    check "TPH9 a session bound to a cell BELOW a prefixed block is not refused for that block: inside SUB1 (level 1, where that session's design sits; the top session's sits at 0) the prefix scan starts at the session's own level and finds nothing, and the pin queues with no path -- while the top session is still refused for SUB1" \
        [list [pcall xschem get currsch] [pcall ase::ui::sod_base_level $PFXKEY] [pcall ase::ui::sod_base_level $TOPKEY] \
              [pcall ase::ui::sod_term_prefixed_ancestor $PFXKEY] [tp_at $PFXKEY R1 P] $::notices \
              [pcall ase::ui::sod_term_prefixed_ancestor $TOPKEY] [tp_at $TOPKEY R1 P] [tp_refused R1 P]] \
        {1 1 0 {} i(r1:n1) {} SUB1 {} {1 1}}
    set res [pcall ase::ui::sod_terminal_resolve $TOPKEY $term]
    check "TPH10 the resolver's two answers for that pin: refused under the top session with the reason naming the block, named under the session bound to the block's own cell" \
        [list [tp_get $res ok] [string match {the block instance 'SUB1' above this sheet carries a spiceprefix*} [tp_get $res why]] \
              [pcall ase::ui::sod_terminal_resolve $PFXKEY $term]] \
        [list 0 1 [dict create ok 1 tokens R1:n1 label R1:P caution {}]]
    tp_home
}

# ---------------------------------------------------------------------------
# TPH, continued — the window the click is made in
# ---------------------------------------------------------------------------
# The mode's bindings sit on a canvas, and the canvas outlives the sheet it
# shows: another design can be loaded into the window, and with tabs another
# tab can be brought in front, while the mode stays armed.  A click there must
# not name that design's nets and devices into the session's rows
# (ase::ui::sod_design_shown).  The design's own sheet, every sheet below it,
# and a block opened in a window or a tab of its own still pick.
#
# the window/tab contexts that are open, by their paths
proc tp_wins {} { return [lmap w [pcall xschem windows] { lindex $w 0 }] }
# close the context `path` a row made and come back to `first`.  With no Tk
# the context of a detached window is closed by destroy_all.
proc tp_close_ctx {path first} {
    if {[lsearch -exact [tp_wins] $path] >= 0} {
        pcall xschem new_schematic switch $path
        pcall xschem set modified 0
        pcall xschem new_schematic destroy $path {}
    }
    pcall xschem new_schematic switch $first
    if {[info commands winfo] eq {} && [lsearch -exact [tp_wins] $path] >= 0} {
        pcall xschem new_schematic destroy_all {}
        pcall xschem new_schematic switch $first
    }
}
group TPH-shown {
    tp_geo_sheet ; tp_switches_reset
    pcall xschem pin_marker clear -fast
    tp_set_radius 6
    lassign [tp_pin RS P] px py
    lassign [tp_pin RS M] mx my
    set vstub [tp_vnet RS M]
    # a device pin, a point on a wire, and the body of a source, on this sheet
    set pts [list [list $px $py] [list $mx [expr {$my + 10}]] {900 0}]
    set want [list i(rs:n1) $vstub i(vab)]
    check "TPH11 fixture: the window shows the third sheet, which is the design of ITS session and not of the top sheet's or the second sheet's; the scripted key has no design at all; and the three points are a device pin, a wire and the body of an ammeter" \
        [list [file tail [pcall xschem get schname]] [pcall ase::ui::sod_design_shown $GEOKEY] [pcall ase::ui::sod_design_shown $TOPKEY] \
              [pcall ase::ui::sod_design_shown $REVKEY] [pcall ase::ui::design_path k] [pcall ase::ui::sod_design_shown k] \
              [lindex [pcall ase::ui::sod_terminal_at k $px $py] 1] [lindex [pcall xschem object_at {*}[lindex $pts 1]] 0] \
              [pcall ase::ui::sod_source_at [pcall xschem object_at 900 0]]] \
        [list tp_geo.sch 1 0 0 {} 1 [tp_inst RS] wire Vab]
    set other {} ; set said {} ; set tags {}
    foreach p $pts {
        lappend other [tp_click $TOPKEY {*}$p]
        lappend said $::notices ; lappend tags $::ntags
    }
    set marks [pcall xschem pin_marker list]
    check "TPH12 A CLICK IN A WINDOW THAT SHOWS ANOTHER DESIGN QUEUES NOTHING: under the top sheet's session each of the three clicks -- pin, wire, source -- queues nothing, marks no pin, and says exactly one sentence, as an error, naming that session's design and where to click; the mode stays armed" \
        [list $other $said $tags $marks [info exists ase::ui::sod($TOPKEY,flavor)]] \
        [list {{} {} {}} [list [list $TP_ELSEWHERE] [list $TP_ELSEWHERE] [list $TP_ELSEWHERE]] {error error error} {} 1]
    tp_mode $TOPKEY plot
    set plotq [tp_click $TOPKEY $px $py]
    set plotsaid $::notices
    tp_mode $TOPKEY outputs
    check "TPH12b ...in Direct Plot's flavour as well: the pin click queues no trace and says the same sentence" \
        [list $plotq $plotsaid] [list {} [list $TP_ELSEWHERE]]
    set own {} ; set scripted {} ; set quiet {}
    foreach p $pts {
        lappend own [tp_click $GEOKEY {*}$p]
        lappend quiet {*}$::notices
        lappend scripted [tp_click k {*}$p]
        lappend quiet {*}$::notices
    }
    check "TPH12c ...while the same three clicks under the session whose design this sheet is queue the terminal, the net and the source's current, and so do they under the scripted key, which has no design to be elsewhere; none of the six says anything" \
        [list $own $scripted $quiet] [list $want $want {}]
    pcall xschem pin_marker clear -fast
    # ---- a second context beside the design's own
    tp_home
    set first [pcall xschem get current_win_path]
    pcall xschem new_schematic create {} $tp_geo
    set second [pcall xschem get current_win_path]
    tp_set_radius 6
    set there [list [pcall ase::ui::sod_design_shown $TOPKEY] [tp_click $TOPKEY $px $py] $::notices]
    pcall xschem new_schematic switch $first
    tp_set_radius 6
    set back [list [pcall ase::ui::sod_design_shown $TOPKEY] [tp_at $TOPKEY R9 P] $::notices]
    tp_close_ctx $second $first
    check "TPH13 the window that counts is the one the click is made in: with the third sheet opened in a second context beside the top sheet, the top session's click there is refused, and back in the first context the same session's click on R9's pin queues (two different contexts; the answer, the queue and the notice in the second; the same in the first; the contexts left open and the one current)" \
        [list [expr {$second ne $first}] $there $back [tp_wins] [pcall xschem get current_win_path]] \
        [list 1 [list 0 {} [list $TP_ELSEWHERE]] {1 i(r9:n1) {}} [list $first] $first]
    pcall xschem pin_marker clear -fast
    # ---- a block opened in a window, and in a tab, of its own
    set desc {}
    foreach target {new_window new_tab} {
        tp_home
        xschem unselect_all
        set made [pcall hi_descend inst=SUB2 target=$target mode=readonly]
        set below [pcall xschem get current_win_path]
        tp_set_radius 6
        lappend desc [list $made [expr {$below ne $first}] [pcall xschem get sch_path] [pcall xschem get currsch] \
                          [pcall ase::ui::sod_design_shown $TOPKEY] [tp_at $TOPKEY R1 P] $::notices]
        pcall xschem pin_marker clear -fast
        tp_close_ctx $below $first
    }
    check "TPH14 A BLOCK OPENED IN A WINDOW OR A TAB OF ITS OWN STILL PICKS: `hi_descend inst=SUB2` with target new_window, then new_tab, shows the block's sheet one level down in another context, the session's design is above it in that context's hierarchy, and a click on R1's pin there queues with the block's path and says nothing (per target: the descend's answer, another context, the path, the level, the window test, the queue, the notices); both contexts are closed again" \
        [list $desc [tp_wins]] \
        [list {{1 1 .SUB2. 1 1 i(sub2.r1:n1) {}} {1 1 .SUB2. 1 1 i(sub2.r1:n1) {}}} [list $first]]
    tp_home
}

# ===========================================================================
# TPP — Direct Plot
# ===========================================================================
# The plot flavour writes no session row, so the next deck asks for no probe:
# a terminal can be plotted only out of what the LAST run wrote.  The session's
# results here are the committed tests/headless/data/probe_1724_tran.raw, which
# holds i(r9:n1) and does not hold i(r9:n2); no viewer is open and no database
# is loaded -- the file's own header is what is read.
group TPP {
    tp_home ; tp_switches_reset
    tp_set_radius 6
    set st [ase::session_state $TOPKEY]
    set rawf [pcall [ase::backend_hook ngspice raw_file] $st]
    file delete -force $rawf
    tp_mode $TOPKEY plot
    set g [tp_at $TOPKEY R9 P]
    check "TPP1 with NO results yet a terminal pick in plot flavour queues nothing and says, once, where to ask for the current" \
        [list [pcall ase::last_rawfile $TOPKEY] $g $::notices] \
        [list {} {} [list "ase: terminal current 'i(r9:n1)' is not in this session's results — pick it under Outputs > To Be Saved > Select On Design and run again"]]
    file copy -force -- [file join $here data probe_1724_tran.raw] $rawf
    set held [tp_at $TOPKEY R9 P]
    set hk $::qkinds
    set hn $::notices
    check "TPP2 with the session's results holding the vector, the pick is queued as a trace of kind `terminal` and nothing is said" \
        [list [expr {[pcall ase::last_rawfile $TOPKEY] ne {}}] $held $hk $hn] {1 i(r9:n1) terminal {}}
    check "TPP2b ...and what the plot queue is handed WITH it is the PIN the click took -- the instance's index and the pin's index on the sheet shown, which is what the cue on the pin is asked for -- not the vector's name" \
        [list $::qtokens [pcall ase::ui::sod_terminal_at $TOPKEY {*}[tp_pin R9 P]]] \
        [list [list [list [tp_inst R9] 0]] [dict create inst [tp_inst R9] pin 0 instname R9 pinname P x [lindex [tp_pin R9 P] 0] y [lindex [tp_pin R9 P] 1] others {}]]
    set g [tp_at $TOPKEY R9 M]
    check "TPP3 the OTHER pin of the same resistor is not in those results: nothing is queued and the one sentence names it" \
        [list $g [llength $::notices] [string match {ase: terminal current 'i(r9:n2)' is not in this session's results*} [lindex $::notices 0]]] {{} 1 1}
    set g [tp_at $TOPKEY {xbus[1:0]} Q]
    check "TPP4 several absent vectors from one click are ONE sentence naming them all" \
        [list $g [llength $::notices] [string match {ase: terminal currents 'i(xbus\[1\]:q)', 'i(xbus\[0\]:q)' are not in this session's results*} [lindex $::notices 0]]] {{} 1 1}
    tp_mode $TOPKEY outputs
    check "TPP5 the OUTPUTS flavours do not ask the results: the pin that is not in them is queued as a row, for the next deck to probe" \
        [list [tp_at $TOPKEY R9 M] $::notices] {i(r9:n2) {}}
    file delete -force $rawf
}

# ---------------------------------------------------------------------------
# TPP, continued — Direct Plot on the pin of a source
# ---------------------------------------------------------------------------
# The header of a results file holding the vectors named, one point.  ASCII,
# which is all the reader of a file's header needs.
proc tp_rawtext {vectors} {
    set t "Title: * pick fixture\nDate: Thu Nov 19 00:00:00  2026\nPlotname: Transient Analysis\nFlags: real\n"
    append t "No. Variables: [expr {[llength $vectors] + 1}]\nNo. Points: 1\nVariables:\n\t0\ttime\ttime\n"
    set k 0
    foreach v $vectors { append t "\t[incr k]\t$v\tcurrent\n" }
    append t "Values:\n 0\t0.0\n"
    foreach v $vectors { append t "\t1.0e-3\n" }
    return $t
}
group TPP-source {
    tp_home ; tp_switches_reset
    tp_set_radius 6
    set rawf [pcall [ase::backend_hook ngspice raw_file] [pcall ase::session_state $TOPKEY]]
    file delete -force $rawf
    tp_mode $TOPKEY plot
    set g1 [tp_at $TOPKEY V1 p]
    set k1 $::qkinds
    set n1 $::notices
    set g2 [tp_at $TOPKEY Vmeas plus]
    set k2 $::qkinds
    set n2 $::notices
    set g3 [tp_at $TOPKEY R9 P]
    set n3 [llength $::notices]
    check "TPP6 Direct Plot on the PIN of a voltage source and of an ammeter, with no results holding the terminal's vector: the click plots the source's branch current, kind `current`, and says nothing -- while a resistor's pin still queues nothing and says its one sentence" \
        [list [pcall ase::last_rawfile $TOPKEY] $g1 $k1 $n1 $g2 $k2 $n2 $g3 $n3] \
        {{} i(v1) current {} i(vmeas) current {} {} 1}
    set g1b [tp_at $TOPKEY V1 p]
    check "TPP6b ...and the stand-in hands the plot queue the source's NAME, as a click on its body does: it is the instance that takes the colour, and no pin is named" \
        [list $g1b $::qkinds $::qtokens] {i(v1) current V1}
    wfile $rawf [tp_rawtext {i(v1:n1) i(v1)}]
    set h1 [tp_at $TOPKEY V1 p]
    set hk1 $::qkinds
    set hn1 $::notices
    set h2 [tp_at $TOPKEY V1 m]
    set hk2 $::qkinds
    set hn2 $::notices
    check "TPP7 with results that HOLD one terminal vector of the source, that pin is plotted as the terminal, kind `terminal`; its other pin, which those results do not hold, is the branch current -- and because that pin is the source's SECOND terminal, the click says in one sentence that the trace is the current into the first pin, so the clicked pin's current is its negative, and how to get the pin's own plotted" \
        [list [pcall ase::raw_vectors_present $rawf {i(v1:n1) i(v1:n2)}] $h1 $hk1 $hn1 $h2 $hk2 $hn2] \
        [list i(v1:n1) i(v1:n1) terminal {} i(v1) current \
              [list "ase: V1 pin m — the trace is the source's own current 'i(v1)', which is the current into its first pin, so the current into V1 pin m is the negative of that trace$TP_OWN"]]
    wfile $rawf [tp_rawtext {i(v1:n2) i(v1)}]
    set p1 [tp_at $TOPKEY V1 p]
    set pk1 $::qkinds
    set pn1 $::notices
    set p2 [tp_at $TOPKEY V1 m]
    set pk2 $::qkinds
    set pn2 $::notices
    check "TPP7b the other way round -- the results hold the SECOND terminal's vector and not the first's: the first pin is the branch current and NOTHING is said (that trace is that pin's own current), and the second pin is plotted as its terminal" \
        [list [pcall ase::raw_vectors_present $rawf {i(v1:n1) i(v1:n2)}] $p1 $pk1 $pn1 $p2 $pk2 $pn2] \
        {i(v1:n2) i(v1) current {} i(v1:n2) terminal {}}
    file delete -force $rawf
    set a2 [tp_at $TOPKEY Vmeas minus]
    set ak2 $::qkinds
    set an2 $::notices
    check "TPP7c an AMMETER's second pin says the same, with no results at all: its reading is plotted and the sentence names it (the first pin of the same ammeter said nothing, row TPP6)" \
        [list $a2 $ak2 $an2] \
        [list i(vmeas) current [list "ase: Vmeas pin minus — the trace is the source's own current 'i(vmeas)', which is the current into its first pin, so the current into Vmeas pin minus is the negative of that trace$TP_OWN"]]
    check "TPP7d which pin is the FIRST terminal: the position in the terminal's name when it is named by position (n1 is, n2 is not -- also on a pin whose index on the symbol says otherwise), else the pin's index on the symbol (a pin that was refused a name, a name that is no position); anything unreadable is not the first" \
        [list [pcall ase::ui::sod_term_first_pin {pin 0} {ok 1 tokens v1:n1}] [pcall ase::ui::sod_term_first_pin {pin 1} {ok 1 tokens v1:n2}] \
              [pcall ase::ui::sod_term_first_pin {pin 0} {ok 1 tokens x1.v1:n2}] [pcall ase::ui::sod_term_first_pin {pin 1} {ok 1 tokens x1.v1:n1}] \
              [pcall ase::ui::sod_term_first_pin {pin 0} {ok 0 why w}] [pcall ase::ui::sod_term_first_pin {pin 1} {ok 0 why w}] \
              [pcall ase::ui::sod_term_first_pin {pin 0} {ok 1 tokens x1:plus}] [pcall ase::ui::sod_term_first_pin {pin 1} {ok 1 tokens x1:plus}] \
              [pcall ase::ui::sod_term_first_pin {} {}]] \
        {1 0 0 1 1 0 1 0 0}
    set ::flat_netlist 1
    set f1 [tp_at $TOPKEY V1 p]
    set fk1 $::qkinds
    set fn1 $::notices
    set f2 [tp_at $TOPKEY R9 P]
    set fr2 [tp_refused R9 P]
    set f4 [tp_at $TOPKEY V1 m]
    set fk4 $::qkinds
    set fn4 $::notices
    tp_mode $TOPKEY outputs
    set f3 [tp_at $TOPKEY V1 p]
    set fr3 [tp_refused V1 p]
    set ::flat_netlist 0
    check "TPP8 a source's pin that is REFUSED a terminal name (flat netlisting on) is the branch current in Direct Plot as well, and no refusal is said; a resistor's pin is still refused there; and in the outputs flavour the source's pin is refused like any other" \
        [list $f1 $fk1 $fn1 $f2 $fr2 $f3 $fr3] {i(v1) current {} {} {1 1} {} {1 1}}
    check "TPP8b ...and the source's SECOND pin, refused a name the same way, is the branch current with the sentence about its sign -- which does not send the user to save a pin that cannot be named" \
        [list $f4 $fk4 $fn4] \
        [list i(v1) current [list "ase: V1 pin m — the trace is the source's own current 'i(v1)', which is the current into its first pin, so the current into V1 pin m is the negative of that trace"]]
    # a bus instance of a source, one of its two vectors in the results
    tp_rev_sheet
    tp_set_radius 6
    set rrawf [pcall [ase::backend_hook ngspice raw_file] [pcall ase::session_state $REVKEY]]
    wfile $rrawf [tp_rawtext [list {i(vb[1]:n1)}]]
    tp_mode $REVKEY plot
    set ::dlg_answer all
    set m [tp_at $REVKEY {VB[1:0]} p]
    set mk $::qkinds
    set mn $::notices
    set mt1 $::qtokens
    wfile $rrawf [tp_rawtext [list {i(vb[1]:n1)} {i(vb[0]:n1)}]]
    set m2 [tp_at $REVKEY {VB[1:0]} p]
    set mt2 $::qtokens
    wfile $rrawf [tp_rawtext [list {i(vb[0]:n1)}]]
    set m3 [tp_at $REVKEY {VB[1:0]} p]
    set mt3 $::qtokens
    file delete -force $rrawf
    set b2 [tp_at $REVKEY {VB[1:0]} m]
    set bk2 $::qkinds
    set bn2 $::notices
    tp_mode $REVKEY outputs
    check "TPP9 a bus instance of a source with ONE of the pick's two vectors in the results: the held one is plotted as a terminal and the other gets the sentence -- the branch current stands in only when none of the pick's vectors is held" \
        [list $m $mk [llength $mn] [string match {ase: terminal current 'i(vb\[0\]:n1)' is not in this session's results*} [lindex $mn 0]]] \
        {{{i(vb[1]:n1)}} terminal 1 1}
    set vbpin [list [tp_inst {VB[1:0]}] 0]
    check "TPP9b ONE pin, however many vectors: the plot queue is handed the pin ONCE per pick, with the first vector the results hold -- with one of two held (the first, then the second) it rides on that one, with both held on the first and the second is handed nothing" \
        [list $mt1 $m2 $mt2 $m3 $mt3] \
        [list [list $vbpin] {{i(vb[1]:n1)} {i(vb[0]:n1)}} [list $vbpin {}] {{i(vb[0]:n1)}} [list $vbpin]]
    check "TPP9c the SECOND pin of that bus source with no results: a source pick is ONE token whatever the instance's width, so one trace stands in, as on its body, and the one sentence names that trace" \
        [list $b2 $bk2 $bn2] \
        [list {{i(vb[1:0])}} current \
              [list "ase: VB\[1:0\] pin m — the trace is the source's own current 'i(vb\[1:0\])', which is the current into its first pin, so the current into VB\[1:0\] pin m is the negative of that trace$TP_OWN"]]
    tp_home
}

# ---------------------------------------------------------------------------
# TPP, continued — Direct Plot on a pin of a source that is neither its first
# nor its second terminal
# ---------------------------------------------------------------------------
# The branch current of a source is the current into its first node and the
# negative of the current into its second.  It says nothing about any other
# pin: the stock PWL-controlled source (vsource_pwl.sym) has four, the third
# and fourth being its controlling nodes, and the stock file source
# (filesource.sym) writes one of its two pins on its netlist line.  Both are
# of type `vsource`, so in Direct Plot a click on any of their pins plots the
# source's current -- and what the click then says depends on the PLACE of the
# pin on the element (ase::ui::sod_term_pin_place), not on its being "not the
# first".
#
# the place of pin `pin` of `inst` on the sheet shown, through the pin rule and
# the resolver as a click goes: {place, the resolver named it}
proc tp_place {key inst pin} {
    set term [pcall ase::ui::sod_terminal_at $key {*}[tp_pin $inst $pin]]
    set nm [pcall ase::ui::sod_terminal_resolve $key $term]
    return [list [pcall ase::ui::sod_term_pin_place $term $nm] [tp_get $nm ok]]
}
group TPP-place {
    tp_geo_sheet ; tp_switches_reset
    tp_set_radius 6
    check "TPP13 THE PLACE OF A PIN ON ITS ELEMENT, sheet apart: a terminal named by position says it -- n1 is the first, n2 the second, n3 and any further one neither, whatever the pin's index on the symbol and whatever the hierarchy path, a position written with a leading zero included (02 is the second; 08, the eighth, is neither); a pin that was refused a name, or is named some other way, with no instance behind it to read a netlist line from, is neither; and so is anything unreadable (the proc takes the same two arguments as the first-pin test)" \
        [list [pcall info args ::ase::ui::sod_term_pin_place] \
              [lmap {t nm} {{pin 0} {ok 1 tokens v1:n1} {pin 1} {ok 1 tokens v1:n2} {pin 0} {ok 1 tokens x1.v1:n2} {pin 1} {ok 1 tokens x1.v1:n1}
                            {pin 2} {ok 1 tokens e1:n3} {pin 3} {ok 1 tokens {e1:n4 e1:n5}} {pin 0} {ok 1 tokens v1:n02} {pin 0} {ok 1 tokens v1:n08} {pin 0} {ok 1 tokens v1:n10}
                            {pin 0} {ok 0 why w} {pin 1} {ok 0 why w} {pin 0} {ok 1 tokens x1:plus} {inst 99999 pin 0} {ok 0 why w} {} {}} \
                   { pcall ase::ui::sod_term_pin_place $t $nm }]] \
        {{term nm} {first second second first other other second other other other other other other other}}
    set resolved {}
    foreach {inst pin} {E1 cp E1 cm A1 p A1 m} {
        set term [pcall ase::ui::sod_terminal_at k {*}[tp_pin $inst $pin]]
        lappend resolved [tp_get [pcall ase::ui::sod_terminal_resolve k $term] why]
    }
    check "TPP13b fixture: the four-pin source's two controlling pins and both pins of the file source are REFUSED a terminal name, each for what its netlist line holds: a word that may not be a node ahead of the controlling pins and ahead of the file source's first pin, and no word at all for the file source's second pin" \
        $resolved \
        [list {its netlist line has 'pwl(1)' ahead of that pin, which may not be a node} \
              {its netlist line has 'pwl(1)' ahead of that pin, which may not be a node} \
              {its netlist line has '%v([' ahead of that pin, which may not be a node} \
              {its netlist line does not carry that pin}]
    check "TPP13c ...AND ON THE SHEET THE PLACE IS READ OFF THE NETLIST LINE WHERE THE NAME DOES NOT SAY IT: the four-pin source's p is its first node and m its second, both named; its controlling pins cp and cm, refused a name, are neither; the file source's m, which its line does not carry, is neither, and so is its p, behind a word that may not be a node; an ammeter's plus is the first and its minus the second, each on a point no other device shares (per pin: the place, the resolver named it)" \
        [lmap {inst pin} {E1 p E1 m E1 cp E1 cm A1 p A1 m Vab plus Vef minus} { tp_place k $inst $pin }] \
        {{first 1} {second 1} {other 0} {other 0} {other 0} {other 0} {first 1} {second 1}}
    set ::flat_netlist 1
    set flat [lmap {inst pin} {E1 p E1 m E1 cp Vab plus Vef minus} { tp_place k $inst $pin }]
    set ::flat_netlist 0
    check "TPP13d a pin that is refused a name for a reason that has nothing to do with its line (flat netlisting on) keeps the place its line gives it: first, second, neither, and the ammeter's first and second -- none of them named" \
        $flat {{first 0} {second 0} {other 0} {first 0} {second 0}}
    # the two readings of one pin -- its name's position, and its line's --
    # over every device pin of this sheet the resolver names by position.
    # The pins are counted off the engine's list of their attribute strings:
    # its list of their names is no list for a name that ends in a backslash,
    # and this sheet has such symbols.
    set agree 0 ; set differ {}
    for {set i 0} {$i < [xschem get instances]} {incr i} {
        set j 0
        foreach row [pcall xschem pinlist $i] {
            set term [dict create inst $i pin $j]
            set nm [pcall ase::ui::sod_terminal_resolve k $term]
            if {[tp_get $nm ok] eq {1} && [regexp {:n[0-9]+$} [lindex [tp_get $nm tokens] 0]]} {
                set byname [pcall ase::ui::sod_term_pin_place $term $nm]
                set byline [pcall ase::ui::sod_term_pin_place $term {ok 0 why w}]
                ## two answers that are not places -- a build without the proc -- do not agree
                if {$byname eq $byline && $byname in {first second other}} { incr agree } \
                else { lappend differ [list [pcall xschem getprop instance $i name] $j $byname $byline] }
            }
            incr j
        }
    }
    check "TPP13e THE NAME AND THE LINE NEVER DISAGREE: for every pin of this sheet the resolver names by position, the place read off the name is the place read off the netlist line when the name is withheld (the pins that differ; more than ten pins were compared)" \
        [list $differ [tp_less 10 $agree]] {{} 1}
    # ---- the click, Direct Plot, no results behind the scripted key
    tp_mode k plot
    set said {}
    foreach {inst pin} {E1 cp E1 cm A1 m A1 p E1 m E1 p} {
        set q [tp_at k $inst $pin]
        lappend said [list $q $::qkinds $::notices]
    }
    tp_mode k outputs
    proc tp_notthat {inst pin ex} {
        return [list $ex current [list "ase: $inst pin $pin — the trace is the source's own current '$ex', which is not the current into $inst pin $pin$::TP_AMM"]]
    }
    check "TPP14 DIRECT PLOT ON A PIN THAT IS NEITHER THE SOURCE'S FIRST NOR ITS SECOND TERMINAL: the source's current is plotted, and the ONE sentence says that the trace is the source's own current and is NOT the current into that pin, and to place an ammeter for it -- on each controlling pin of the four-pin source and on both pins of the file source, whose places its line does not give; while that four-pin source's SECOND pin says the trace is the negative of its current and how to get its own row, and its FIRST pin says nothing (per click: queued, kind, said)" \
        $said \
        [list [tp_notthat E1 cp i(e1)] [tp_notthat E1 cm i(e1)] [tp_notthat A1 m i(a1)] [tp_notthat A1 p i(a1)] \
              [list i(e1) current [list "ase: E1 pin m — the trace is the source's own current 'i(e1)', which is the current into its first pin, so the current into E1 pin m is the negative of that trace$TP_OWN"]] \
              [list i(e1) current {}]]
    check "TPP14b ...and none of the sentences said for a pin that is neither speaks of a sign (the four sentences that hold the words for the second pin)" \
        [lsearch -all -glob [lmap r [lrange $said 0 3] { lindex $r 2 0 }] {*negative of that trace*}] {}
    tp_home
}

# ---------------------------------------------------------------------------
# TPP, continued — Direct Plot where a source's pin shares its point with
# another device's pin
# ---------------------------------------------------------------------------
# The results hold the resistor's terminal on each shared point and none of the
# ammeters', so on the ammeter's side of the point the click is the stand-in.
group TPP-shared {
    tp_geo_sheet ; tp_switches_reset
    tp_set_radius 30
    set grawf [pcall [ase::backend_hook ngspice raw_file] [pcall ase::session_state $GEOKEY]]
    wfile $grawf [tp_rawtext {i(rb:n1) i(rc:n1) i(re:n2)}]
    tp_mode $GEOKEY plot
    # RE's lower pin on Vef's PLUS pin: Vef's body is below the point
    lassign [tp_pin Vef plus] fx fy
    set a [tp_click $GEOKEY $fx [expr {$fy + 1}]]
    set ak $::qkinds
    set at $::qtokens
    set an $::notices
    set b [tp_click $GEOKEY $fx [expr {$fy - 1}]]
    set bk $::qkinds
    set bn $::notices
    check "TPP10 fixture: the resistor's lower pin and the ammeter's plus pin are one point, and the session's results hold the resistor's terminal there and no terminal of the ammeter" \
        [list [expr {[tp_pin RE M] eq [list $fx $fy]}] [pcall ase::raw_vectors_present $grawf {i(re:n2) i(vef:n1) i(vef:n2)}]] {1 i(re:n2)}
    check "TPP11 Direct Plot on a point a source's pin shares with another device's pin, the cursor on the SOURCE's side: the source's current is plotted, kind `current`, the source's body takes the colour -- and ONE sentence names the pin that shares the point and says the click took the source's current.  On the other device's side the click is that device's terminal and names the source's pin, as it did" \
        [list $a $ak $at $an $b $bk $bn] \
        [list i(vef) current Vef [list "ase: that point is also RE pin M — the click took the current of Vef"] \
              i(re:n2) terminal [list "ase: that point is also Vef pin plus — the click took RE pin M"]]
    # an ammeter's MINUS pin on a resistor's upper pin, either order on the sheet
    set got {}
    foreach {amm res} {Vab RB Vcd RC} {
        lassign [tp_pin $amm minus] sx sy
        set c [tp_click $GEOKEY $sx [expr {$sy - 1}]]
        lappend got [list $c $::qkinds $::notices]
        set c [tp_click $GEOKEY $sx [expr {$sy + 1}]]
        lappend got [list $c $::qkinds $::notices]
    }
    proc tp_standin {amm res} {
        set ex i([string tolower $amm])
        return [list $ex current [list "ase: that point is also $res pin P — the click took the current of $amm" \
            "ase: $amm pin minus — the trace is the source's own current '$ex', which is the current into its first pin, so the current into $amm pin minus is the negative of that trace$::TP_OWN"]]
    }
    check "TPP12 ...and where the shared pin is the source's SECOND terminal the click says both things, one sentence each: which pin shares the point, and that the trace has the opposite sign of the clicked pin's own current -- with the ammeter first on the sheet and with the resistor first; on the resistor's side nothing changes" \
        $got \
        [list [tp_standin Vab RB] [list i(rb:n1) terminal [list "ase: that point is also Vab pin minus — the click took RB pin P"]] \
              [tp_standin Vcd RC] [list i(rc:n1) terminal [list "ase: that point is also Vcd pin minus — the click took RC pin P"]]]
    tp_mode $GEOKEY outputs
    file delete -force $grawf
    tp_home
}

# ===========================================================================
# TPV — what the session's simulator can save: the pick's word, Direct Plot's reasons
# ===========================================================================
# No simulator is started here either.  Stand-in programs sit in the registry,
# each a script that would leave a mark if anything started it, and what ASE-L
# "has measured" about a program is handed to the capability store as the
# probe would have left it -- under the key the store is asked for, never one
# spelled here.  Measuring it for real is the deck suite's (band PH and row
# PN15 of test_ase_probe_deck_1724).
set TPVBIN [file join $scratch tpv_bin]
file mkdir $TPVBIN
set TPVMARK [file join $TPVBIN started]
# A stand-in program: written once, so that its file's stamp stays what it was
# when something was "measured" about it.
proc tpv_prog {name} {
    set p [file join $::TPVBIN $name]
    if {![file exists $p]} {
        wfile $p "#!/bin/sh\necho $name >> '$::TPVMARK'\nexit 0"
        file attributes $p -permissions 0755
    }
    return $p
}
# The top session's OWN choice of simulator, written into its state as the
# Simulators window writes it: the entry `name`, or the program the system
# finds for {}.  It is what a run of that session starts, whatever is in force
# in the process.
proc tpv_choice {name} {
    set st [ase::session_state $::TOPKEY]
    ase::session_update $::TOPKEY [ase::sim_choice_set $st [expr {$name eq {} ? {path} : {entry}}] $name]
}
# The store holding an answer for each `name 0|1` pair of `known`.
proc tpv_known {known} {
    foreach {n v} $known {
        set f [tpv_prog $n]
        dict set ::ase::sim_caps [ase::cap_key $f {}] \
            [list stamp [ase::cap_stamp $f] caps [dict create known 1 usable 1 hier_probes $v]]
    }
}
# The registry holding `names`; `inforce` ({} for none) chosen by the top
# session and in force in the process; the store holding `known`.
proc tpv_setup {names inforce known} {
    test_sim_registry_isolate
    foreach n $names { ase::sim_register $n [tpv_prog $n] }
    ase::sim_select $inforce
    tpv_choice $inforce
    tpv_known $known
    file delete -force $::TPVMARK
}
# One Saves row for `sig`, Save ticked.
proc tpv_row {sig} { return [dict create name $sig expr $sig save 1 plot 0] }
set TPV_LIMIT {it saves terminal currents only on top-level devices that are not subcircuit instances.}
set TPV_DOOR "Setup > Simulators…"
set TPV_REG "Register an ngspice build that saves terminal currents inside subcircuits under $TPV_DOOR"
set TPV_AMM {or place an ammeter (ammeter.sym) in series with the pin.}
proc tpv_pick {who what cure} {
    return "ase: $who, the simulator this session starts, cannot save $what: $::TPV_LIMIT $cure"
}
# The cure's words where no entry is known able and `names` have not been asked.
proc tpv_untried {names} {
    set many [regexp { and } $names]
    return "$names [expr {$many ? {have} : {has}}] not been tried yet — the next run finds out [expr {$many ? {which of them} : {whether it}}] can, or select [expr {$many ? {each} : {it}}] under $::TPV_DOOR, press Edit… and then Detect."
}
proc tpv_head {sigs} {
    set many [expr {[llength $sigs] > 1}]
    return "ase: terminal current[expr {$many ? {s} : {}}] '[join $sigs {', '}]' [expr {$many ? {are} : {is}}] not in this session's results"
}
group TPV {
    tp_home ; tp_switches_reset
    tp_set_radius 6
    set ::tpv_marks {}
    tp_stub ase::ui::sod_mark_pin {pin} { lappend ::tpv_marks $pin ; return 1 }
    set stz [ase::session_state $TOPKEY]
    set zin "zin ([file join $TPVBIN zin])"
    tpv_setup {zin zable} zin {zin 0 zable 1}
    tp_mode $TOPKEY outputs
    set g [tp_at $TOPKEY xb A]
    check "TPV1 AT THE PICK, with the simulator this session starts ALREADY KNOWN to save no terminal current below the top level: a click on the pin of a subcircuit instance queues its row and marks the pin as ever, and says ONE thing more, as an error -- the picked entry with its file, that it cannot save that current and what such a build saves, the registered program that can and where to pick it before the run -- and no program is started to say it (the row, what was said, its tag, pins marked, a program started)" \
        [list $g $::notices $::ntags [llength $::tpv_marks] [file exists $TPVMARK]] \
        [list i(xb:a) [list [tpv_pick $zin {that current} "zable can — pick it under $TPV_DOOR before you run."]] error 1 0]
    set g [tp_at $TOPKEY {xbus[1:0]} Q]
    check "TPV2 ONCE FOR THE CLICK, NOT ONCE FOR EACH BIT: a bus instance's pin queues its two rows and the one sentence speaks of `those currents`" \
        [list $g $::notices] \
        [list {{i(xbus[1]:q)} {i(xbus[0]:q)}} [list [tpv_pick $zin {those currents} "zable can — pick it under $TPV_DOOR before you run."]]]
    set g [tp_at $TOPKEY R9 P]
    check "TPV3 a top-level device that is no subcircuit instance is what such a build does save: its row is queued and nothing is said" \
        [list $g $::notices] {i(r9:n1) {}}
    set ase::ui::sod($TOPKEY,flavor) {save 1 plot 1}
    set g [tp_at $TOPKEY xb A]
    set fd [pcall info body ase::ui::output_editor_from_design]
    check "TPV4 the other flavours that write rows say it too: with the flavour To Be Plotted enters, and the Add Output dialog's From Design button enters the mode through the same door with a flavour and no other mode (the row and what was said; the button's call, read off its body)" \
        [list $g $::notices [regexp {ase::ui::select_on_design \$key \[list save \$s plot \$p\]\s*$} [string trimright $fd]]] \
        [list i(xb:a) [list [tpv_pick $zin {that current} "zable can — pick it under $TPV_DOOR before you run."]] 1]
    tp_mode $TOPKEY outputs
    set t {}
    foreach {names inforce known} {{zin zable} zin {zable 1}  {zin zable} zable {zin 0 zable 1}  {zin zmute} zmute {}} {
        tpv_setup $names $inforce $known
        if {$inforce eq {zmute}} {
            set f [file join $TPVBIN zmute]
            dict set ::ase::sim_caps [ase::cap_key $f {}] [list stamp [ase::cap_stamp $f] caps [dict create known 1 usable 1]]
        }
        lappend t [list [tp_at $TOPKEY xb A] $::notices [file exists $TPVMARK]]
    }
    check "TPV5 NOTHING IS SAID, AND NOTHING IS STARTED, where the program this session starts is not known to be unable: nothing measured about it yet (although another registered one is known able), a program measured able, and one whose answer holds no word on the question -- per case the row, what was said, a program started" \
        $t {{i(xb:a) {} 0} {i(xb:a) {} 0} {i(xb:a) {} 0}}
    tpv_setup {zin zother} zin {zin 0}
    set g1 [list [tp_at $TOPKEY xb A] $::notices [file exists $TPVMARK]]
    tpv_setup {zin zother zthird} zin {zin 0}
    set g1b [list [tp_at $TOPKEY xb A] $::notices [file exists $TPVMARK]]
    tpv_setup {zin} zin {zin 0}
    set g2 [list [tp_at $TOPKEY xb A] $::notices]
    check "TPV6 THE CURE AT A PICK IS READ FROM WHAT IS ALREADY KNOWN, AND A PROGRAM NOBODY HAS ASKED IS NOT A REASON TO REGISTER ANOTHER: a registered program nobody has measured is not started, is called neither able nor unable, and is NAMED as not tried yet with what finds out -- one such entry in the singular, two as `which of them` and `each`; and with only the unable one registered none can, and that sentence ends with what to register before the run, or the ammeter" \
        [list $g1 $g1b $g2] \
        [list [list i(xb:a) [list [tpv_pick $zin {that current} [tpv_untried zother]]] 0] \
              [list i(xb:a) [list [tpv_pick $zin {that current} [tpv_untried {zother and zthird}]]] 0] \
              [list i(xb:a) [list [tpv_pick $zin {that current} "None of the simulators you have registered can. $TPV_REG before you run, $TPV_AMM"]]]]
    # Entries the cure does not ask, beside the session's own, which is known
    # unable: zdel's file is deleted after it was registered; znox is registered
    # on a file that is not executable; zlate likewise, and its file is made
    # executable afterwards without registering it again.  Nothing can start
    # zdel or znox.  zlate's file can be started by then, and the cure still
    # does not ask it: it reads what registering recorded.  The zlate leg holds
    # what the cure does today (issue 1724, Limits).
    foreach n {zdel znox zlate} { file delete -force [file join $TPVBIN $n] }
    tpv_prog zdel
    foreach n {znox zlate} {
        wfile [file join $TPVBIN $n] "#!/bin/sh\necho $n >> '$TPVMARK'\nexit 0"
        file attributes [file join $TPVBIN $n] -permissions 0644
    }
    test_sim_registry_isolate
    set regs {}
    foreach n {zin zdel znox zlate} { lappend regs [ase::sim_register $n [expr {$n eq {zin} ? [tpv_prog zin] : [file join $TPVBIN $n]}]] }
    ase::sim_select zin
    tpv_choice zin
    tpv_known {zin 0}
    file delete -force [file join $TPVBIN zdel]
    file attributes [file join $TPVBIN zlate] -permissions 0755
    file delete -force $TPVMARK
    set fx [list $regs [file exists [file join $TPVBIN zdel]] [file executable [file join $TPVBIN znox]] [file executable [file join $TPVBIN zlate]]]
    set g [list [pcall ase::probe_cure_entries ngspice peek] [tp_at $TOPKEY xb A] $::notices [file exists $TPVMARK]]
    check "TPV6b AN ENTRY THE CURE DOES NOT ASK IS NOT CALLED NOT TRIED YET AT A PICK: beside the session's own entry, known unable, an entry whose file was deleted after it was registered and one registered on a file that is not executable each read `unknown`; so does one registered as not runnable whose file was made executable afterwards without registering it again -- the cure reads what registering recorded, not the file as it is now (issue 1724, Limits: this leg holds what the cure does today, not that nothing could ask such an entry); the click's one sentence says none of the registered simulators is known to and what to register before the run, or the ammeter; and nothing is started (fixture: what registering each of the four answered, the deleted file is gone, the second is not executable, the third is; then what a click reads of the four entries, the row, what was said, a program started)" \
        [list $fx $g] \
        [list {{1 1 0 0} 0 0 1} \
              [list {{zin cannot} {zdel unknown} {znox unknown} {zlate unknown}} i(xb:a) \
                    [list [tpv_pick $zin {that current} "None of the simulators you have registered is known to. $TPV_REG before you run, $TPV_AMM"]] 0]]
    tpv_prog ngspice
    set path0 $::env(PATH)
    tpv_setup {zable} {} {ngspice 0 zable 1}
    set ::env(PATH) "$TPVBIN:$path0" ; auto_reset
    set g [list [tp_at $TOPKEY xb A] $::notices [file exists $TPVMARK]]
    set ::env(PATH) $path0 ; auto_reset
    check "TPV7 WITH NO SIMULATOR PICKED the program is the one the system finds, named by its file, and the registered one that can is still the cure" \
        $g [list i(xb:a) [list [tpv_pick [file join $TPVBIN ngspice] {that current} "zable can — pick it under $TPV_DOOR before you run."]] 0]
    # Two sessions, one process.  The choice in force in the process is the
    # last RUN's, of whichever session ran; the pick is this session's.
    tpv_setup {zin zable} zin {zin 0 zable 1}
    ase::sim_select zable
    set ga [list [tp_at $TOPKEY xb A] $::notices [ase::sim_selected]]
    tpv_choice zable
    ase::sim_select zin
    set gb [list [tp_at $TOPKEY xb A] $::notices [ase::sim_selected]]
    tpv_choice zgone
    set gc [list [tp_at $TOPKEY xb A] $::notices [ase::sim_selected]]
    check "TPV9 THE PROGRAM IS THE PICKING SESSION'S OWN, NOT THE ONE ANOTHER SESSION'S RUN LEFT IN FORCE: with the able entry in force in the process and the unable one chosen by this session, the pick says this session's program cannot; with the unable one in force and the able one chosen by this session it says nothing; a choice naming an entry that is no longer registered leaves what is in force, as a run of it would, and the click says that ONE sentence -- not the run's sentence about the stale entry as well; and in every case the choice in force in the process is what it was before the click (per case: the row, what was said, the entry in force afterwards)" \
        [list $ga $gb $gc] \
        [list [list i(xb:a) [list [tpv_pick $zin {that current} "zable can — pick it under $TPV_DOOR before you run."]] zable] \
              [list i(xb:a) {} zin] \
              [list i(xb:a) [list [tpv_pick $zin {that current} "zable can — pick it under $TPV_DOOR before you run."]] zin]]
    # The registry is edited after the programs were measured: the store is
    # emptied, as an edit always did, and the click still knows who can.
    tpv_setup {zin zable} zin {zin 0 zable 1}
    ase::sim_register znew [tpv_prog znew]
    set ge [list [dict size $::ase::sim_caps] [tp_at $TOPKEY xb A] $::notices [file exists $TPVMARK]]
    check "TPV9b AFTER AN EDIT OF THE REGISTRY the pick still says it, from what the edit carried over: the capability store is empty, the session's program is still known unable and the entry that can is still named -- the new entry, which nobody has asked, is not named and is not started (answers in the store, the row, what was said, a program started)" \
        $ge [list 0 i(xb:a) [list [tpv_pick $zin {that current} "zable can — pick it under $TPV_DOOR before you run."]] 0]
    # Direct Plot, with no results at all.
    tpv_setup {zin zable} zin {zin 0 zable 1}
    tp_mode $TOPKEY plot
    set noraw [pcall ase::last_rawfile $TOPKEY]
    set g8a [list [tp_at $TOPKEY xb A] $::notices]
    set s8 [ase::session_state $TOPKEY]
    dict set s8 outputs [list [tpv_row i(xb:a)]]
    pcall ase::session_update $TOPKEY $s8
    set g8b [list [tp_at $TOPKEY xb A] $::notices]
    tpv_choice zable
    set g8c [list [tp_at $TOPKEY xb A] $::notices]
    check "TPV8 DIRECT PLOT IN A SESSION THAT HAS NO RESULTS: the plot flavour writes no row, so the pick's sentence is not its to say -- a pin whose row is not set queues nothing and is told where to ask for the current, in the click's own sentence and nothing about a simulator; a pin whose row IS set to be saved is told that, that the session has no results yet, and -- the session's simulator being already known unable -- that it cannot save the current and which registered one can, to be picked before the run; and with the able one chosen by the session, only to run (fixture: no results file; then the three clicks)" \
        [list $noraw $g8a $g8b $g8c] \
        [list {} \
              [list {} [list "[tpv_head i(xb:a)] — pick it under Outputs > To Be Saved > Select On Design and run again"]] \
              [list {} [list "[tpv_head i(xb:a)]: it is set to be saved, and this session has no results yet, but $zin, the simulator this session starts, cannot save it. zable can — pick it under $TPV_DOOR before you run."]] \
              [list {} [list "[tpv_head i(xb:a)]: it is set to be saved, and this session has no results yet — run."]]]
    pcall ase::session_update $TOPKEY $stz
    tp_unstub ase::ui::sod_mark_pin
    tp_mode $TOPKEY outputs
    test_sim_registry_isolate
}

# ---------------------------------------------------------------------------
# TPV, continued — Direct Plot's reasons for a terminal the results do not hold
# ---------------------------------------------------------------------------
# The session's results hold i(r9:n1) and nothing else (the committed
# transient file of band TPP).  "The last run's report" is the real
# ase::probe_report, handed the session's state, a plan written here as the
# deck's plan is shaped, and a log in the words of a build without the probe
# extension -- so what Direct Plot reads back is what that report kept.
proc tpv_rec {sig path pin {why {}}} {
    set card "I($path,$pin)"
    if {$why ne {}} { set card {} }
    return [dict create signal $sig path $path pin $pin card $card why $why nohdr {}]
}
set TPV_LOG0 "Warning: Node a is not available for device xb,\n   .probe i(xb,a) will be ignored\nWarning: Could not find the instance line for xbus\[1\],\n   .probe i(xbus\[1\],q) will be ignored\nWarning: Could not find the instance line for xbus\[0\],\n   .probe i(xbus\[0\],q) will be ignored\nWarning: Node zz is not available for device r9,\n   .probe i(r9,2) will be ignored\n[ase::probe_marker] 0\n"
group TPV-plot {
    tp_home ; tp_switches_reset
    tp_set_radius 6
    set stz [ase::session_state $TOPKEY]
    tpv_setup {zin zable zother} zin {zin 0 zable 1}
    set st0 [ase::session_state $TOPKEY]
    set rawf [pcall [ase::backend_hook ngspice raw_file] $st0]
    file copy -force -- [file join $here data probe_1724_tran.raw] $rawf
    set zin "zin ([file join $TPVBIN zin])"
    # HOW THE LAST RUN NAMED ITS PROGRAM: a name nothing here resolves to, so
    # that a sentence naming the program in force at the click reads
    # differently from one naming the run's.
    set zrun {zlast (/zz/bin/zlast)}
    set plan [list [tpv_rec i(xb:a) xb a] [tpv_rec {i(xbus[1]:q)} {xbus[1]} q] [tpv_rec {i(xbus[0]:q)} {xbus[0]} q] \
                   [tpv_rec i(r9:n2) r9 2] [tpv_rec i(r9:n1) r9 1]]
    set kinds {}
    foreach r [pcall ase::probe_report $st0 [dict create probes $plan simname $zrun] $TPV_LOG0 0] { lappend kinds [lrange $r 0 1] }
    # The report may start registered programs for its cure, and what it
    # learns is remembered: the registry is set up again, so that `zother` is
    # once more a program nobody has measured when the clicks below are made.
    tpv_setup {zin zable zother} zin {zin 0 zable 1}
    check "TPV10 fixture: the report over that plan and that log, for the session's own results file, made ONE record for the three terminals the build cannot save and kept the top-level resistor's refusal as its own; the session's results exist; and what the report kept names the session whose state it was handed, which is still the session's state" \
        [list $kinds [expr {[pcall ase::last_rawfile $TOPKEY] ne {}}] [ase::state_get $::ase::last_probes session NOKEY] [expr {[ase::session_state $TOPKEY] eq $st0}]] \
        [list {{hier {i(xb:a) {i(xbus[1]:q)} {i(xbus[0]:q)}}} {refused i(r9:n2)}} 1 $TOPKEY 1]
    tp_mode $TOPKEY plot
    # THE USER'S OWN ORDER: the rows are set to be saved, the run is made, and
    # then Direct Plot is asked.
    set st1 $st0
    dict set st1 outputs [list [tpv_row i(xb:a)] [tpv_row {i(xbus[1]:q)}] [tpv_row {i(xbus[0]:q)}] [tpv_row i(r9:n2)]]
    pcall ase::session_update $TOPKEY $st1
    set set11 [pcall ase::probe_asked [ase::session_state $TOPKEY]]
    set cure "zable can — pick it under $TPV_DOOR and run again."
    set g1 [list [tp_at $TOPKEY xb A] $::notices $::ntags]
    set g2 [list [tp_at $TOPKEY {xbus[1:0]} Q] $::notices]
    check "TPV11 THE LAST RUN'S SIMULATOR CANNOT SAVE IT, and the row IS set to be saved -- set, run, then plotted: Direct Plot on a pin whose terminal that run reported so queues nothing and says, in ONE untagged sentence, that the terminal is not in the results, which program the LAST RUN used -- by the name that run gave it, not the one in force now -- and that it cannot save it, and which registered program can and where to pick it; not that the row is set and to run again, which is what was done; a bus pin's two terminals are one sentence, `them`; and the registered program nobody has measured is not started for either (fixture: the rows the session asks for; the single pick: queue, sentence, tag; the bus pick; a program started)" \
        [list $set11 $g1 $g2 [file exists $TPVMARK]] \
        [list {i(xb:a) {i(xbus[1]:q)} {i(xbus[0]:q)} i(r9:n2)} \
              [list {} [list "[tpv_head i(xb:a)]: $zrun, the simulator of the last run, cannot save it. $cure"] {{}}] \
              [list {} [list "[tpv_head {i(xbus[1]:q) i(xbus[0]:q)}]: $zrun, the simulator of the last run, cannot save them. $cure"]] 0]
    set g [list [tp_at $TOPKEY R9 M] $::notices]
    check "TPV12 THE LAST RUN GAVE ANOTHER REASON, for a row that is set to be saved: the top-level resistor's other pin, which that run's simulator refused in words of its own, is told that reason as a clause -- the card and the simulator's line -- and nothing about picking a simulator or running again" \
        $g [list {} [list "[tpv_head i(r9:n2)]: in the last run the simulator refused it (.probe I(r9,2)): Node zz is not available for device r9."]]
    # The session has taken the cure since: the program it starts now can.
    tpv_choice zable
    set gp [list [tp_at $TOPKEY xb A] $::notices]
    tpv_prog ngspice
    tpv_known {ngspice 1}
    tpv_choice {}
    set path0 $::env(PATH)
    set ::env(PATH) "$TPVBIN:$path0" ; auto_reset
    set gs [list [tp_at $TOPKEY xb A] $::notices [ase::sim_selected]]
    set ::env(PATH) $path0 ; auto_reset
    tpv_choice zin
    check "TPV11b THE CURE HAS BEEN TAKEN: where the entry this session starts NOW is already known able, the sentence about the last run's simulator does not tell the user to pick what is picked -- it says that entry is picked now, and to run again; where the session starts no entry and the program the system finds is known able, it says that program can; and the click leaves the choice in force in the process alone (the two clicks; the entry in force after the second)" \
        [list $gp $gs] \
        [list [list {} [list "[tpv_head i(xb:a)]: $zrun, the simulator of the last run, cannot save it. zable is picked now — run again."]] \
              [list {} [list "[tpv_head i(xb:a)]: $zrun, the simulator of the last run, cannot save it. [file join $TPVBIN ngspice], which this session starts now, can — run again."] zin]]
    # The row is set and the last run said nothing about it.  xb's other pin
    # is a pin of a subcircuit instance; R9's is a top-level resistor's.
    set st2 [ase::session_state $TOPKEY]
    dict set st2 outputs [list [tpv_row i(xb:y)] [tpv_row i(r9:n2)]]
    pcall ase::session_update $TOPKEY $st2
    set h3a [list [tp_at $TOPKEY xb Y] $::notices]
    tpv_choice zable
    set g3a [list [tp_at $TOPKEY xb Y] $::notices]
    pcall ase::probe_report $st0 [dict create probes $plan simname $zrun session $BUSKEY] $TPV_LOG0 0
    set g3o [list [tp_at $TOPKEY xb Y] $::notices]
    # The run's own record says whose run it was.  The report is handed the
    # state that run was started with and a record naming THIS session, while
    # the session has been edited since: no session holds that state any more.
    pcall ase::probe_report $st0 [dict create probes $plan simname $zrun session $TOPKEY] $TPV_LOG0 0
    set g3s [list [tp_at $TOPKEY xb Y] $::notices [expr {[ase::session_state $TOPKEY] ne $st0}] [pcall ase::session_holding $st0]]
    # THIS session's own run, by its record, which DID ask for both rows and
    # said nothing of either (it failed): only the plan keeps these results
    # from being called older than the rows.
    set kinds3b [pcall ase::probe_report $st0 [dict create probes [list [tpv_rec i(xb:y) xb y] [tpv_rec i(r9:n2) r9 2]] simname $zrun session $TOPKEY] {} 1]
    set g3b [list [tp_at $TOPKEY xb Y] $::notices $kinds3b [ase::state_get $::ase::last_probes session NOKEY]]
    tpv_choice zin
    set h3b [list [tp_at $TOPKEY xb Y] $::notices]
    set g3t [list [tp_at $TOPKEY R9 M] $::notices]
    pcall ase::probe_said_clear [ase::run_lock_key $st0]
    tpv_choice zable
    set g3c [list [tp_at $TOPKEY xb Y] $::notices]
    set g4 [list [tp_at $TOPKEY xb A] $::notices]
    set before "[tpv_head i(xb:y)]: it is set to be saved, and these results are from before that"
    set hold "[tpv_head i(xb:y)]: it is set to be saved, but these results do not hold it"
    check "TPV13 THE ROW IS SET TO BE SAVED AND THE LAST RUN SAID NOTHING ABOUT IT.  With the session's simulator not known unable: where the last run's report is about these results, the run was THIS session's and its plan did not hold the terminal, the results are from before the row and the sentence says so and to run again; where the run on these results was ANOTHER session's, where THIS session's own run did ask for the terminal and said nothing of it (a run that failed), and where nothing is remembered about these results at all, the sentence claims only that they do not hold it; and where the report is made from a run record that names THIS session, for the state that run was started with, AFTER the session has been edited -- so that no session holds that state when the report is made -- the results are from before the row all the same, because whose run it was is read from the record; and a terminal that is not set, with nothing remembered, keeps the sentence that says where to ask for it.  With the session's simulator ALREADY KNOWN UNABLE, a pin of a subcircuit instance is not sent into a run that cannot save it: each of the two sentences ends with that program, that it cannot save the current, and the cure -- while a top-level resistor's pin keeps the plain sentence there too (unable: before; then able: before, another session's run, this session's run by its record -- with the session's state moved on and nobody holding the run's state --, this session's run that asked and was silent -- what its report said, and the session it kept; unable: not held, the resistor; able: nothing remembered, not set)" \
        [list $h3a $g3a $g3o $g3s $g3b $h3b $g3t $g3c $g4] \
        [list [list {} [list "$before, but $zin, the simulator this session starts, cannot save it. $cure"]] \
              [list {} [list "$before — run again."]] \
              [list {} [list "$hold — run again."]] \
              [list {} [list "$before — run again."] 1 {}] \
              [list {} [list "$hold — run again."] {} $TOPKEY] \
              [list {} [list "$hold, and $zin, the simulator this session starts, cannot save it. $cure"]] \
              [list {} [list "[tpv_head i(r9:n2)]: it is set to be saved, but these results do not hold it — run again."]] \
              [list {} [list "$hold — run again."]] \
              [list {} [list "[tpv_head i(xb:a)] — pick it under Outputs > To Be Saved > Select On Design and run again"]]]
    pcall ase::session_update $TOPKEY $st0
    # a report about OTHER results: the same plan and log, a state whose run
    # directory is elsewhere
    set stx $st0
    dict set stx rundir [file join $scratch tpv_elsewhere]
    file mkdir [dict get $stx rundir]
    pcall ase::probe_report $stx [dict create probes $plan simname $zrun] $TPV_LOG0 0
    set gx [list [tp_at $TOPKEY xb A] $::notices]
    pcall ase::probe_report $st0 [dict create probes $plan simname $zrun] $TPV_LOG0 0
    pcall ase::probe_said_clear [ase::run_lock_key $stx]
    set gk [lindex [tp_at $TOPKEY xb A] 0][string match {*the simulator of the last run, cannot save it*} [lindex $::notices 0]]
    # ...and a SAVED result in view: the report is about the live results, and
    # the results the click reads are the saved ones.
    set sv [file join $scratch tpv_saved]
    file mkdir $sv
    pcall ase::saved_write_meta [file join $sv result.meta] \
        [dict create format 1 folder [file tail $sv] cell [lindex [ase::saved_design $st0] 1] design [ase::saved_design $st0]]
    set svst $st0
    dict set svst rundir $sv
    set svraw [pcall [ase::backend_hook ngspice raw_file] $svst]
    file copy -force -- $rawf $svraw
    pcall ase::result_sel_note $TOPKEY $svraw
    set gv [list [expr {[pcall ase::result_view $TOPKEY] eq [file normalize $sv]}] [tp_at $TOPKEY xb A] $::notices]
    pcall ase::result_sel_forget $TOPKEY
    set gl [lindex [tp_at $TOPKEY xb A] 0][string match {*the simulator of the last run, cannot save it*} [lindex $::notices 0]]
    pcall ase::probe_said_clear [ase::run_lock_key $st0]
    set gc [list [tp_at $TOPKEY xb A] $::notices]
    check "TPV14 WHICH RESULTS THE REPORT IS ABOUT: a report made for another results file says nothing about this session's -- the click keeps its own sentence; the report for this session's file is not emptied by a run that starts on another file; with a SAVED result in view the report about the live results says nothing either, and it speaks again once the live results are back in view; and it IS emptied by a run that starts on this file (other results: the sentence; this session's report after a clear for the other file: the simulator's sentence is still said; a saved result in view: it is in view, the click's own sentence; the live results back: the simulator's sentence; after a clear for this file: the click's own sentence)" \
        [list $gx $gk $gv $gl $gc] \
        [list [list {} [list "[tpv_head i(xb:a)] — pick it under Outputs > To Be Saved > Select On Design and run again"]] 1 \
              [list 1 {} [list "[tpv_head i(xb:a)] — pick it under Outputs > To Be Saved > Select On Design and run again"]] 1 \
              [list {} [list "[tpv_head i(xb:a)] — pick it under Outputs > To Be Saved > Select On Design and run again"]]]
    pcall ase::probe_report $st0 [dict create probes [list [tpv_rec {i(xbus[1]:q)} {xbus[1]} q]] simname $zrun] $TPV_LOG0 0
    set g [list [tp_at $TOPKEY {xbus[1:0]} Q] $::notices]
    check "TPV15 ONE CLICK, TWO REASONS: of a bus pin's two terminals the last run reported one as beyond its simulator and never asked for the other, which is not set either -- each gets its own sentence, the simulator's first" \
        $g [list {} [list "[tpv_head {{i(xbus[1]:q)}}]: $zrun, the simulator of the last run, cannot save it. $cure" \
                          "[tpv_head {{i(xbus[0]:q)}}] — pick it under Outputs > To Be Saved > Select On Design and run again"]]
    pcall ase::probe_report $st0 [dict create probes [list [tpv_rec {i(xbus[0]:q)} {xbus[0]} q {xbus[0] is held back by this row}] [tpv_rec {i(xbus[1]:q)} {xbus[1]} q]] simname $zrun] $TPV_LOG0 0
    set g [list [tp_at $TOPKEY {xbus[1:0]} Q] $::notices]
    check "TPV16 THE ORDER THE REASONS ARE SAID IN: of a bus pin's two terminals the last run reported one as beyond its simulator and wrote no probe for the other, for a reason of its own -- the simulator's sentence is said first and the other terminal's reason after it, although the run's plan held them the other way round" \
        $g [list {} [list "[tpv_head {{i(xbus[1]:q)}}]: $zrun, the simulator of the last run, cannot save it. $cure" \
                          "[tpv_head {{i(xbus[0]:q)}}]: in the last run no probe was written for it: xbus\[0\] is held back by this row. To measure it, place an ammeter (ammeter.sym) in series."]]
    # The registry is edited after the run, as the user's own next step was:
    # she registered one more entry for the program that can.
    pcall ase::probe_report $st0 [dict create probes $plan simname $zrun] $TPV_LOG0 0
    tpv_setup {zin zable zother} zin {zin 0 zable 1}
    ase::sim_register znew [tpv_prog znew]
    ase::sim_register ztwin [file join $TPVBIN zable]
    set e1 [list [dict size $::ase::sim_caps] [tp_at $TOPKEY xb A] $::notices [file exists $TPVMARK]]
    tpv_choice ztwin
    set e1p [list [tp_at $TOPKEY xb A] $::notices]
    tpv_setup {zin zother} zin {zin 0}
    ase::sim_register znew [tpv_prog znew]
    set e2 [list [tp_at $TOPKEY xb A] $::notices [file exists $TPVMARK]]
    check "TPV17 DIRECT PLOT AFTER AN EDIT OF THE REGISTRY: an edit empties the capability store, and the click still names who can -- the entry measured able before the edit AND the entry just registered for the same program -- without starting anything; with that new entry chosen by the session the sentence says it is picked now; and where no entry is known able, the entries nobody has asked are named as not tried yet, with what finds out, in place of the advice to register another build (answers in the store, the click, a program started; the click with the new entry chosen; the click with none known able, a program started)" \
        [list $e1 $e1p $e2] \
        [list [list 0 {} [list "[tpv_head i(xb:a)]: $zrun, the simulator of the last run, cannot save it. zable and ztwin can — pick one under $TPV_DOOR and run again."] 0] \
              [list {} [list "[tpv_head i(xb:a)]: $zrun, the simulator of the last run, cannot save it. ztwin is picked now — run again."]] \
              [list {} [list "[tpv_head i(xb:a)]: $zrun, the simulator of the last run, cannot save it. [tpv_untried {zother and znew}]"] 0]]
    pcall ase::probe_said_clear [ase::run_lock_key $st0]
    pcall ase::session_update $TOPKEY $stz
    tp_mode $TOPKEY outputs
    file delete -force $rawf $sv
    test_sim_registry_isolate
}

# ===========================================================================
# TPM — the notices
# ===========================================================================
group TPM {
    tp_home ; tp_switches_reset
    tp_set_radius 6
    lassign [tp_pin M1 g] gx gy
    # the body of the MOSFET: 20 units from its gate pin, 20 from its bulk pin
    set bx [expr {$gx + 20}]
    check "TPM1 a click on a device BODY, farther than the radius from every pin, queues nothing and gives exactly ONE notice equal to the whole sentence" \
        [list [pcall ase::ui::sod_terminal_at k $bx $gy] [lindex [pcall xschem object_at $bx $gy] 0] [tp_click k $bx $gy] $::notices] \
        [list {} instance {} [list $TP_MISS]]
    check "TPM1b ...said as a plain notice, not as an error" $::ntags {{}}
    check "TPM2 a click on EMPTY canvas queues nothing and says nothing" \
        [list [pcall xschem object_at 20000 20000] [tp_click k 20000 20000] $::notices] {{} {} {}}
    check "TPM3 a terminal pick says nothing but what it queued: no notice from the click itself" \
        [list [tp_at k R9 P] $::notices] {i(r9:n1) {}}
    check "TPM4 the two entry sentences keep their opening words byte for byte and name the pin pick" \
        [list [string first "ase: Direct Plot — click wires/net labels" [pcall ase::ui::sod_entry_notice plot]] \
              [string first "ase: Select On Design — click wires/net labels" [pcall ase::ui::sod_entry_notice outputs]] \
              [expr {[string first {pins for terminal currents} [pcall ase::ui::sod_entry_notice plot]] > 0}] \
              [expr {[string first {pins for terminal currents} [pcall ase::ui::sod_entry_notice outputs]] > 0}]] \
        {0 0 1 1}
    # ENTERING the mode says that sentence.  select_on_design needs a canvas to
    # seize; without Tk the three Tk words it uses are stood in for inside its
    # OWN namespace only, so nothing outside ase::ui sees a Tk that is not there.
    set fake {}
    if {[info commands ::winfo] eq {}} {
        foreach c {winfo bind focus} { proc ::ase::ui::$c {args} { return 1 } ; lappend fake $c }
    }
    set said {}
    foreach {flavor mode} {{save 1 plot 0} outputs {save 0 plot 1} plot} {
        set ::notices {}
        set rc [pcall ase::ui::select_on_design k $flavor $mode 0]
        lappend said $rc [lindex $::notices end]
        # leave the mode without finishing it: nothing to plot, no window to raise
        pcall ase::ui::sod_release k
        array unset ase::ui::sod k,*
        unset -nocomplain ase::ui::sod(active)
    }
    foreach c $fake { rename ::ase::ui::$c {} }
    tp_mode k outputs
    check "TPM5 entering the mode in each flavour arms it and says that flavour's sentence" \
        $said [list 1 [pcall ase::ui::sod_entry_notice outputs] 1 [pcall ase::ui::sod_entry_notice plot]]
}

# ---------------------------------------------------------------------------
# TPM, continued — the prompt names the pin a click would take
# ---------------------------------------------------------------------------
# The editor's hover outline shows the WIRE on a pin with a wire ending on it,
# where the click takes the terminal; the mode's prompt says which it is
# (ase::ui::sod_prompt_text), and the timer that keeps the prompt up writes it
# (ase::ui::sod_prompt_pump, through ase::ui::sod_prompt_now).  The pointer is
# moved here by the engine's own motion callback, which needs no display, and
# read back; the prompt's widget is stood in for by a recorder.
#
# move the pointer to schematic (x,y); answers how far from it the engine then
# reads the pointer, in units
proc tp_point {x y} {
    set z [xschem get zoom]
    set px [expr {int(round(($x + [xschem get xorigin]) / $z))}]
    set py [expr {int(round(($y + [xschem get yorigin]) / $z))}]
    pcall xschem callback .drw 6 $px $py 0 0 0 0
    return [tp_dist [pcall xschem get mousex] [pcall xschem get mousey] $x $y]
}
# one tick of the timer for `key`: {the text it wrote, it re-armed itself, it
# raised}; the timer it armed is cancelled again
proc tp_tick {key} {
    set ::tp_prompts {}
    set r [pcall ase::ui::sod_prompt_pump $key]
    set id {}
    catch {set id $::ase::ui::sod($key,pump)}
    set armed [expr {$id ne {} && [lsearch -exact [after info] $id] >= 0 ? 1 : 0}]
    catch {after cancel $id}
    return [list [lindex $::tp_prompts end 1] $armed [string match ERR:* $r]]
}
group TPM-prompt {
    tp_geo_sheet ; tp_switches_reset
    tp_set_radius 6
    lassign [tp_pin RS M] ax ay
    lassign [tp_pin l_stub p] lx ly
    set plain [pcall ase::ui::sod_prompt_base outputs]
    set named "$plain — pin RS:M (terminal current)"
    check "TPM6 the mode's own words, per flavour" \
        [list $plain [pcall ase::ui::sod_prompt_base plot]] {{select outputs on design} {select signals to plot}}
    set texts {}
    foreach p [list [list $ax $ay] [list $ax [expr {$ay + 4}]] [list $lx $ly] {20000 20000}] {
        lappend texts [pcall ase::ui::sod_prompt_text $GEOKEY {*}$p]
    }
    check "TPM7 THE PROMPT NAMES THE PIN THE CLICK WOULD TAKE, AND ONLY THERE: on RS's lower pin, where a wire ends, it is the mode's words and then the instance and the pin; 4 units along that wire, on the net label's pin at the wire's far end and on empty canvas it is the mode's words alone -- and the clicks agree: the pin point queues the terminal, the point on the wire the net's voltage" \
        [list $texts [tp_click $GEOKEY $ax $ay] [tp_click $GEOKEY $ax [expr {$ay + 4}]]] \
        [list [list $named $plain $plain $plain] i(rs:n2) [tp_vnet RS M]]
    pcall xschem pin_marker clear -fast
    tp_mode $GEOKEY plot
    set plot [pcall ase::ui::sod_prompt_text $GEOKEY $ax $ay]
    tp_mode $GEOKEY outputs
    set ase::ui::sod($GEOKEY,prompt) {words of the mode}
    set kept [pcall ase::ui::sod_prompt_text $GEOKEY $ax $ay]
    unset ase::ui::sod($GEOKEY,prompt)
    check "TPM7b the pin follows whatever the mode's words are: Direct Plot's, and the words the mode keeps on record once it is entered" \
        [list $plot $kept] \
        [list "[pcall ase::ui::sod_prompt_base plot] — pin RS:M (terminal current)" {words of the mode — pin RS:M (terminal current)}]
    check "TPM8 in a window that does not show the session's design no pin is named, since a click there takes none: under the top sheet's session the prompt on RS's pin is the mode's words alone, while the pin rule itself still finds that pin" \
        [list [pcall ase::ui::sod_prompt_text $TOPKEY $ax $ay] [lindex [pcall ase::ui::sod_terminal_at $TOPKEY $ax $ay] 1]] \
        [list $plain [tp_inst RS]]
    # ---- the timer: the mode records it needs, by hand; no canvas is seized
    set ::tp_prompts {} ; set ::tp_asked 0
    tp_stub ::ase::ui::sod_prompt_set {cv text} { lappend ::tp_prompts [list $cv $text] }
    tp_stub ::ase::ui::sod_terminal_at {key x y} { incr ::tp_asked ; return [::ase::ui::sod_terminal_at__tp_real $key $x $y] }
    array set ase::ui::sod [list active $GEOKEY $GEOKEY,canvas .tp_nowhere $GEOKEY,prompt $plain]
    set d1 [tp_point $ax $ay]
    set t1 [tp_tick $GEOKEY]
    set cv1 [lindex $::tp_prompts end 0]
    set d2 [tp_point $ax [expr {$ay + 4}]]
    set t2 [tp_tick $GEOKEY]
    check "TPM9 THE TIMER WRITES IT: with the pointer moved onto RS's lower pin one tick writes the prompt with the pin, on the mode's canvas, and arms the next tick; with the pointer moved 4 units along the wire the next tick writes the mode's words alone (the pointer was where asked, to half a unit, both times; each tick: the text, re-armed, raised)" \
        [list [tp_less $d1 0.5] $t1 $cv1 [tp_less $d2 0.5] $t2] \
        [list 1 [list $named 1 0] .tp_nowhere 1 [list $plain 1 0]]
    # ---- the pin rule is asked again only when something it depends on moved
    tp_point $ax $ay
    unset -nocomplain ase::ui::sod($GEOKEY,promptat) ase::ui::sod($GEOKEY,prompttext)
    set ::tp_asked 0
    set seen {}
    for {set i 0} {$i < 5} {incr i} { lappend seen [lindex [tp_tick $GEOKEY] 0] }
    set a1 $::tp_asked
    tp_set_radius 7
    lappend seen [lindex [tp_tick $GEOKEY] 0]
    set a2 $::tp_asked
    tp_point $ax [expr {$ay + 1}]
    lappend seen [lindex [tp_tick $GEOKEY] 0]
    set a3 $::tp_asked
    for {set i 0} {$i < 3} {incr i} { lappend seen [lindex [tp_tick $GEOKEY] 0] }
    set a4 $::tp_asked
    # another sheet in the window, the pointer where it was: the top sheet has
    # no pin there, and a prompt kept from the sheet before would still name one
    tp_home
    set other [lindex [tp_tick $GEOKEY] 0]
    tp_geo_sheet
    check "TPM10 A POINTER AT REST COSTS ONE PIN TEST, NOT ONE PER TICK: five ticks with the pointer unmoved on the pin ask the pin rule once; a change of zoom asks it once more, a move of the pointer once more, and three further ticks at rest not at all -- and all ten ticks write the prompt with the pin; another sheet loaded into the window under the resting pointer is asked about afresh, and its prompt is the mode's words alone, this session's design being no longer shown (the pin rule's calls after each step; the texts; the tick on the other sheet)" \
        [list $a1 $a2 $a3 $a4 [lsort -unique $seen] [llength $seen] $other] \
        [list 1 2 3 3 [list $named] 10 $plain]
    tp_set_radius 6
    # ---- what the kept answer is kept with, beside the pointer and the zoom.
    # Under the scripted key, which has no design to be elsewhere, so the pin
    # rule is asked wherever the window is.  Every state below is given the
    # SAME view and the SAME pointer, so only the thing named differs.
    array set ase::ui::sod [list active k k,canvas .tp_nowhere k,prompt $plain]
    # the view and the pointer, set the same way each time; answers what the
    # engine then reads: {zoom pointer-x pointer-y}
    proc tp_same_view {} {
        pcall xschem origin 0 0 0.5
        tp_point 100 100
        return [list [pcall xschem get zoom] [pcall xschem get mousex] [pcall xschem get mousey]]
    }
    # one tick for the scripted key; answers whether the pin rule was asked
    proc tp_asked_tick {} {
        set n $::tp_asked
        tp_tick k
        return [expr {$::tp_asked - $n}]
    }
    set views {} ; set steps {}
    tp_geo_sheet
    lappend views [tp_same_view]
    unset -nocomplain ase::ui::sod(k,promptat) ase::ui::sod(k,prompttext)
    lappend steps [tp_asked_tick] [tp_asked_tick]
    tp_home
    lappend views [tp_same_view]
    lappend steps [tp_asked_tick] [tp_asked_tick]
    set first [pcall xschem get current_win_path]
    set counts [list [pcall xschem get instances] [pcall xschem get wires]]
    # a second context holding a copy of the top sheet under another file
    # name (a file that is open already is not opened a second time)
    set twin [file join $scratch tp_top_twin.sch]
    file copy -force -- $tp_top $twin
    pcall xschem new_schematic create {} $twin
    set second [pcall xschem get current_win_path]
    lappend counts [pcall xschem get instances] [pcall xschem get wires]
    lappend views [tp_same_view]
    lappend steps [tp_asked_tick] [tp_asked_tick]
    tp_close_ctx $second $first
    tp_home
    set paths {}
    foreach bit {2 1} {
        xschem unselect_all ; xschem select instance [tp_inst {xbus[1:0]}]
        pcall xschem descend $bit
        lappend paths [pcall xschem get sch_path]
        lappend views [tp_same_view]
        lappend steps [tp_asked_tick] [tp_asked_tick]
        tp_home
    }
    check "TPM10b ...AND THE KEPT ANSWER IS DROPPED WHEN WHAT THE WINDOW SHOWS CHANGES UNDER A RESTING POINTER: with the zoom and the pointer the same in every state, the pin rule is asked once and then not again on the third sheet; once more on the top sheet loaded into the window; once more in a second context showing a copy of that top sheet, with as many instances and wires; and once more in each of the two bits of a bus instance, the same sheet under two hierarchy paths (one view and pointer in all five states; a second context, and the instance and wire counts of the two; the two paths; asked, then at rest, per state)" \
        [list [llength [lsort -unique $views]] [llength $views] [expr {$second ne $first}] \
              [expr {[lrange $counts 0 1] eq [lrange $counts 2 3] ? {same counts} : $counts}] $paths $steps] \
        [list 1 5 1 {same counts} {{.xbus[0].} {.xbus[1].}} {1 0 1 0 1 0 1 0 1 0}]
    array unset ase::ui::sod k,canvas ; array unset ase::ui::sod k,prompt* ; array unset ase::ui::sod k,pump
    set ase::ui::sod(active) $GEOKEY
    tp_geo_sheet
    tp_set_radius 6
    # ---- a pin rule that raises
    tp_unstub ::ase::ui::sod_terminal_at
    tp_stub ::ase::ui::sod_terminal_at {key x y} { error {the pin rule raised} }
    tp_point $ax $ay
    unset -nocomplain ase::ui::sod($GEOKEY,promptat) ase::ui::sod($GEOKEY,prompttext)
    set traised [tp_tick $GEOKEY]
    set direct [pcall ase::ui::sod_prompt_now $GEOKEY]
    tp_unstub ::ase::ui::sod_terminal_at
    check "TPM11 THE TIMER NEVER RAISES: with a pin rule that raises, the tick writes the mode's words alone, does not raise, and still arms the next one -- an error escaping it would end the prompt for the rest of the mode (the tick; and the raise it swallowed, asked directly)" \
        [list $traised $direct] [list [list $plain 1 0] {ERR:the pin rule raised}]
    # ---- the pointer in another window than the one the mode is on.  Inside
    # namespace ase::ui, and nowhere else, three questions are answered from
    # tables, as in band TPL: which names are widgets, the name of the current
    # context, and the list of windows.  Every other word goes to the engine.
    set ::tp_ctx {} ; set ::tp_wins [list {.x1.drw . . 1 b.sch 0 b.sch}] ; set ::tp_there {.tpm_a .tpm_b .drw}
    proc ::ase::ui::winfo {sub args} {
        return [expr {$sub eq {exists} ? ([lsearch -exact $::tp_there [lindex $args 0]] >= 0) : 1}]
    }
    proc ::ase::ui::xschem {args} {
        if {$args eq {get current_win_path} && $::tp_ctx ne {}} { return $::tp_ctx }
        if {$args eq {windows} && [llength $::tp_wins]} { return $::tp_wins }
        return [uplevel 1 [linsert $args 0 ::xschem]]
    }
    set d3 [tp_point $ax $ay]
    unset -nocomplain ase::ui::sod($GEOKEY,promptat) ase::ui::sod($GEOKEY,prompttext)
    set legs {} ; set elsewhere {}
    foreach {cv ctx} {.tpm_a .tpm_b  .tpm_b .tpm_b  .tp_nowhere .tpm_b  .drw .x1.drw  .tpm_a .x9.drw} {
        set ase::ui::sod($GEOKEY,canvas) $cv
        set ::tp_ctx $ctx
        lappend elsewhere [pcall ase::ui::sod_pointer_elsewhere $GEOKEY]
        lappend legs [lindex [tp_tick $GEOKEY] 0]
        if {[llength $legs] == 1} {
            set still [list [pcall ase::ui::sod_design_shown $GEOKEY] [lindex [pcall ase::ui::sod_terminal_at $GEOKEY $ax $ay] 1] \
                           [pcall ase::ui::sod_prompt_text $GEOKEY $ax $ay]]
        }
    }
    rename ::ase::ui::winfo {} ; rename ::ase::ui::xschem {}
    set ase::ui::sod($GEOKEY,canvas) .tp_nowhere
    check "TPM12 THE PROMPT NAMES A PIN ONLY WHILE THE POINTER IS IN THE WINDOW THE MODE IS ON: with the pointer on RS's lower pin and the current context ANOTHER window than the mode's -- a window of the same design, where a click is the editor's -- the timer writes the mode's words alone, although that window shows the session's design, the pin rule finds the pin there and the prompt for that point names it (fixture legs); once the mode is on the window the pointer is in, nothing else having moved, it names the pin; and where the question cannot be put the prompt is worked out from the pointer: a mode whose recorded canvas is no widget, a current context that is a tab of the mode's own window, and one that has no canvas at all (the pointer was on the pin to half a unit; per state: the pointer is known to be elsewhere, and the text written; the three fixture legs in the first state)" \
        [list [tp_less $d3 0.5] $elsewhere $legs $still] \
        [list 1 {1 0 0 0 0} [list $plain $named $named $named $named] [list 1 [tp_inst RS] $named]]
    tp_unstub ::ase::ui::sod_prompt_set
    array unset ase::ui::sod $GEOKEY,*
    unset -nocomplain ase::ui::sod(active)
    tp_mode $GEOKEY outputs
    tp_home
}

# ===========================================================================
# TPK — call shapes, and the cue on the pin
# ===========================================================================
group TPK {
    tp_home ; tp_switches_reset
    check "TPK1 the signatures other suites stub or call, read off the interpreter: the pin rule takes (key x y), the source rule (hit), the click (key x y) with both coordinates defaulting to empty, and the queues, the dialog and the token seam are as they were" \
        [list [info args ::ase::ui::sod_terminal_at] [info args ::ase::ui::sod_source_at] [info args ::ase::ui::sod_click] \
              [list [info default ::ase::ui::sod_click x dx] $dx [info default ::ase::ui::sod_click y dy] $dy] \
              [info args ::ase::ui::tp_real_dp_queue] [info args ::ase::ui::sod_pick_tokens] \
              [info args ::ase::ui::bus_dialog_build] [info args ::ase::ui::sod_terminal_pick] [info args ::ase::ui::dp_hilight]] \
        {{key x y} hit {key x y} {1 {} 1 {}} {key ex kind token} {key kind token} {parent token bits} {key term} {kind token color}}
    set body [info body ::ase::ui::sod_click]
    check "TPK2 the click's body CALLS the pin rule and the source rule and holds no type test of its own: the text `cell::type` is nowhere in it, comments and strings included" \
        [list [regexp {ase::ui::sod_terminal_at \$key \$px \$py} $body] [regexp {ase::ui::sod_source_at \$hit} $body] \
              [string first cell::type $body]] {1 1 -1}
    set ::dlg {}
    check "TPK3 the token seam answers as it did for the two kinds it serves: a source pick is its one token and opens no dialog, a scalar net is itself, a bus net goes to the dialog" \
        [list [pcall ase::ui::sod_pick_tokens k current V1] [pcall ase::ui::sod_pick_tokens k voltage nd] $::dlg \
              [pcall ase::ui::sod_pick_tokens k voltage {a[1:0]}] [lindex [lindex $::dlg 0] 2]] \
        {V1 nd {} {{a[1]} {a[0]}} {{a[1]} {a[0]}}}
    # a fault inside the new steps must stay inside them
    tp_set_radius 6
    rename ::ase::ui::sod_term_name ::ase::ui::tp_real_term_name
    proc ::ase::ui::sod_term_name {args} { error {naming went wrong} }
    set g [tp_at k R9 P]
    rename ::ase::ui::sod_term_name {}
    rename ::ase::ui::tp_real_term_name ::ase::ui::sod_term_name
    check "TPK3b a naming step that RAISES does not escape the click: nothing is queued and the pick is refused in the one sentence, carrying the error's text -- and with the real proc back the same click queues" \
        [list $g [tp_refused R9 P] [string match {*could not be worked out (naming went wrong)*} [lindex $::notices 0]] [tp_at k R9 P]] \
        {{} {1 1} 1 i(r9:n1)}
    rename ::ase::ui::sod_terminal_at ::ase::ui::tp_real_terminal_at
    proc ::ase::ui::sod_terminal_at {args} { error {pin test went wrong} }
    set wire [tp_click k [lindex [tp_pin D1 p] 0] [expr {[lindex [tp_pin D1 p] 1] - 30}]]
    set wn $::notices
    set wt $::ntags
    set body [tp_click k [lindex [tp_pin V1 p] 0] [expr {[lindex [tp_pin V1 p] 1] + 30}]]
    rename ::ase::ui::sod_terminal_at {}
    rename ::ase::ui::tp_real_terminal_at ::ase::ui::sod_terminal_at
    check "TPK3c a pin test that RAISES does not escape the click either, and does not take the other picks with it: the wire still queues its voltage and the source body its current, and the fault is said once per click, as an error" \
        [list $wire [llength $wn] [string match {ase: the pin test of this click failed (pin test went wrong)*} [lindex $wn 0]] $wt $body] \
        {v(nd) 1 1 error i(v1)}
    # the colour cue: every xschem subcommand the cue issues is recorded
    pcall xschem pin_marker clear -fast
    set r9 [tp_inst R9]
    set ::tp_xcalls {}
    rename ::xschem ::tp_xschem_real
    proc ::xschem {args} { lappend ::tp_xcalls [lindex $args 0] ; return [uplevel 1 [linsert $args 0 ::tp_xschem_real]] }
    set r [catch {
        set t [ase::ui::dp_hilight terminal [list $r9 0] 4]
        set tcalls $::tp_xcalls
        set ::tp_xcalls {}
        set words [list [ase::ui::dp_hilight terminal nd 4] [ase::ui::dp_hilight terminal R9:n1 4] \
                        [ase::ui::dp_hilight terminal {R9 P} 4] [ase::ui::dp_hilight terminal [list $r9 0 0] 4] \
                        [ase::ui::dp_hilight terminal [list $r9 -1] 4] [ase::ui::dp_hilight terminal [list $r9 0] {}] \
                        [ase::ui::dp_hilight terminal [list $r9 0] 0]]
        set wcalls $::tp_xcalls
        set ::tp_xcalls {}
        set nopin [ase::ui::dp_hilight terminal [list $r9 99] 4]
        set ncalls $::tp_xcalls
        set ::tp_xcalls {}
        set v [ase::ui::dp_hilight voltage nd 4]
        set vcalls $::tp_xcalls
    } e]
    rename ::xschem {}
    rename ::tp_xschem_real ::xschem
    set listed [lmap m [pcall xschem pin_marker list] { lrange $m 1 4 }]
    pcall xschem unhilight_all
    check "TPK4 a `terminal` is cued ON ITS PIN: handed the pin as {instance index, pin index} and a layer, the cue answers 1 through ONE xschem command, `pin_marker`, and the list then holds that pin on that layer with the tag `plot`.  Handed anything else it answers 0 and asks the engine nothing: a token that IS a net's name, the vector's own name, an instance and pin by name, three words, a negative index, an empty colour, the colour 0.  A pin the instance does not have is asked of the engine, which refuses it: 0 and no marker.  And the same net's name as a `voltage` still answers 1 through hilight_netname" \
        [list $r [expr {$r ? $e : [list $t $tcalls $words $wcalls $nopin $ncalls $v $vcalls]}] $listed] \
        {0 {1 pin_marker {0 0 0 0 0 0 0} {} 0 pin_marker 1 hilight_netname} {{R9 0 4 plot}}}
    check "TPK4b ...and `xschem unhilight_all`, which clears the other colours of a Direct Plot, cleared that marker" \
        [pcall xschem pin_marker list] {}
    # and through the real plot queue, on a real pick
    set rawf [pcall [ase::backend_hook ngspice raw_file] [ase::session_state $TOPKEY]]
    file copy -force -- [file join $here data probe_1724_tran.raw] $rawf
    tp_set_radius 6
    tp_mode $TOPKEY plot
    set ase::ui::sod($TOPKEY,queue) {}
    set ase::ui::sod($TOPKEY,qcolors) {}
    rename ::ase::ui::dp_queue ::ase::ui::tp_stub_dp_queue
    rename ::ase::ui::tp_real_dp_queue ::ase::ui::dp_queue
    set ::tp_xcalls {}
    rename ::xschem ::tp_xschem_real
    proc ::xschem {args} { lappend ::tp_xcalls [lindex $args 0] ; return [uplevel 1 [linsert $args 0 ::tp_xschem_real]] }
    set r [catch { ase::ui::sod_click $TOPKEY {*}[tp_pin R9 P] } e]
    rename ::xschem {}
    rename ::tp_xschem_real ::xschem
    set hil {}
    set marks 0
    foreach c $::tp_xcalls {
        if {[string match hilight* $c]} { lappend hil $c }
        if {$c eq {pin_marker}} { incr marks }
    }
    set q1 $ase::ui::sod($TOPKEY,queue)
    set qc1 $ase::ui::sod($TOPKEY,qcolors)
    set n1 $ase::ui::sod($TOPKEY,count)
    set l1 [lmap m [pcall xschem pin_marker list] { lrange $m 1 4 }]
    check "TPK5 the REAL plot queue takes a terminal pick: the trace is in the mode's queue with one colour slot, the count moved, the pin carries ONE marker on the layer that slot holds with the tag `plot` -- asked for once -- and no net or instance highlight command was issued on the way" \
        [list $r $q1 [llength $qc1] [expr {[string is integer -strict [lindex $qc1 0]] && [lindex $qc1 0] > 0}] $n1 $l1 $marks $hil] \
        [list 0 i(r9:n1) 1 1 1 [list [list R9 0 [lindex $qc1 0] plot]] 1 {}]
    # the same pin again, its marker cleared in between: the trace is queued
    # already, and the pin is still chosen
    pcall xschem unhilight_all
    set gone [pcall xschem pin_marker list]
    set ::notices {}
    set r2 [catch { ase::ui::sod_click $TOPKEY {*}[tp_pin R9 P] } e2]
    check "TPK5b a pin clicked AGAIN in the same Direct Plot, after `xschem unhilight_all` took its marker away: the trace is not queued twice -- the queue, its colours and the count are what they were and the click says `already queued` -- and the marker is back on the layer its trace has" \
        [list $gone $r2 [expr {$ase::ui::sod($TOPKEY,queue) eq $q1}] [expr {$ase::ui::sod($TOPKEY,qcolors) eq $qc1}] \
              [expr {$ase::ui::sod($TOPKEY,count) eq $n1}] $::notices \
              [lmap m [pcall xschem pin_marker list] { lrange $m 1 4 }]] \
        [list {} 0 1 1 1 [list "ase: trace 'i(r9:n1)' already queued"] [list [list R9 0 [lindex $qc1 0] plot]]]
    rename ::ase::ui::dp_queue ::ase::ui::tp_real_dp_queue
    rename ::ase::ui::tp_stub_dp_queue ::ase::ui::dp_queue
    pcall xschem unhilight_all
    file delete -force $rawf
    tp_mode $TOPKEY outputs
}

# ---------------------------------------------------------------------------
# TPK, continued — the seams other callers build on
# ---------------------------------------------------------------------------
# One pin, asked of the resolver and then clicked: {named|refused, the click
# queued exactly the resolver's tokens (or nothing), the click's refusal is the
# resolver's reason (NOREFUSAL for a named pin)}.
proc tp_as_resolver {key inst pin} {
    set term [pcall ase::ui::sod_terminal_at $key {*}[tp_pin $inst $pin]]
    set res [pcall ase::ui::sod_terminal_resolve $key $term]
    set got [tp_click $key {*}[tp_pin $inst $pin]]
    if {[tp_get $res ok] eq {1}} {
        set want {}
        foreach t [tp_get $res tokens] {
            lappend want [pcall ase::ui::sod_expr terminal $t [pcall ase::ui::sod_case_mode $key]]
        }
        return [list named [expr {$got eq $want ? 1 : 0}] [tp_why $inst $pin]]
    }
    return [list refused [expr {$got eq {} ? 1 : 0}] [expr {[tp_why $inst $pin] eq [tp_get $res why] ? 1 : 0}]]
}
group TPK-resolve {
    tp_home ; tp_switches_reset
    tp_set_radius 6
    check "TPK6 the seams added for other callers, read off the interpreter: the resolver takes (key term), the wire test (x y px py hit), the side test (n px py x y), and the header lookup takes the instance as a third argument that defaults to empty" \
        [list [pcall info args ::ase::ui::sod_terminal_resolve] [pcall info args ::ase::ui::sod_wire_wins] \
              [pcall info args ::ase::ui::sod_term_toward] [pcall info args ::ase::ui::sod_term_ports] \
              [pcall apply {{} { list [info default ::ase::ui::sod_term_ports n d] $d }}]] \
        {{key term} {x y px py hit} {n px py x y} {key callee n} {1 {}}}
    check "TPK6b ...and the further seams of the pin rule, the header lookup and the source stand-in: the wire-only test takes (x y px py), the side by the box (n px py x y), the port lists (key callee n) with the instance defaulting to empty, the reason no header names a port (callee place lists need), the first-terminal test (term nm), and the source stand-in (key term exvar) with the variable's name defaulting to empty" \
        [list [pcall info args ::ase::ui::sod_wire_near] [pcall info args ::ase::ui::sod_term_toward_box] \
              [pcall info args ::ase::ui::sod_term_port_lists] [pcall apply {{} { list [info default ::ase::ui::sod_term_port_lists n d] $d }}] \
              [pcall info args ::ase::ui::sod_term_header_gap] [pcall info args ::ase::ui::sod_term_first_pin] \
              [pcall info args ::ase::ui::sod_terminal_as_source] [pcall apply {{} { list [info default ::ase::ui::sod_terminal_as_source exvar d] $d }}]] \
        {{x y px py} {n px py x y} {key callee n} {1 {}} {callee place lists need} {term nm} {key term exvar} {1 {}}}
    set body [info body ::ase::ui::sod_terminal_pick]
    check "TPK7 the click's terminal arm CALLS the resolver and tests nothing of its own: its body holds that call, and none of the three things the resolver tests -- the flat-netlisting switch, the scan for a prefixed block above, the naming step -- comments included" \
        [list [regexp {ase::ui::sod_terminal_resolve \$key \$term} $body] [string first flat_netlist $body] \
              [string first sod_term_prefixed_ancestor $body] [string first sod_term_name $body]] {1 -1 -1 -1}
    set ::dlg_answer all
    set cases {}
    lappend cases [tp_as_resolver k R9 P] [tp_as_resolver k RW M] [tp_as_resolver k {xbus[1:0]} Q] \
                  [tp_as_resolver k RG NC] [tp_as_resolver k RD2 A] [tp_as_resolver k SU1 A]
    set ::flat_netlist 1
    lappend cases [tp_as_resolver k R1 P]
    set ::flat_netlist 0
    rename ::ase::ui::sod_term_name ::ase::ui::tp_real_term_name
    proc ::ase::ui::sod_term_name {args} { error {naming went wrong} }
    lappend cases [tp_as_resolver k R9 P]
    rename ::ase::ui::sod_term_name {}
    proc ::ase::ui::sod_term_name {args} { return {ok 1} }
    lappend cases [tp_as_resolver k R9 P]
    set shape [pcall ase::ui::sod_terminal_resolve k [pcall ase::ui::sod_terminal_at k {*}[tp_pin R9 P]]]
    rename ::ase::ui::sod_term_name {}
    rename ::ase::ui::tp_real_term_name ::ase::ui::sod_term_name
    check "TPK8 THE PICK'S REFUSALS AND TOKENS ARE THE RESOLVER'S, pin by pin -- each asked of the resolver, then clicked: three it names (one vector, one with a caution, two vectors through the dialog) queue exactly its tokens wrapped; six it refuses (a pin its line does not carry, a pin written twice, a word ahead of the pin, flat netlisting, a naming step that raises, a naming answer without its keys) queue nothing and say its reason" \
        $cases \
        {{named 1 NOREFUSAL} {named 1 NOREFUSAL} {named 1 NOREFUSAL} {refused 1 1} {refused 1 1} {refused 1 1} {refused 1 1} {refused 1 1} {refused 1 1}}
    check "TPK9 the resolver's answers themselves: a named pin is its token in the netlist's own spelling, the label and an empty caution; a refusal is the reason alone; a naming answer that lacks its keys, and a pin that is no pin, are refusals too -- never a dict a caller would trip on" \
        [list [pcall ase::ui::sod_terminal_resolve k [pcall ase::ui::sod_terminal_at k {*}[tp_pin R9 P]]] \
              [pcall ase::ui::sod_terminal_resolve k [pcall ase::ui::sod_terminal_at k {*}[tp_pin RG NC]]] \
              [tp_get $shape ok] [string match {its name could not be worked out (*} [tp_get $shape why]] \
              [lsort [pcall dict keys $shape]] [tp_get [pcall ase::ui::sod_terminal_resolve k {}] ok]] \
        [list [dict create ok 1 tokens R9:n1 label R9:P caution {}] \
              [dict create ok 0 why {its netlist line does not carry that pin}] \
              0 1 {ok why} 0]
}

# ===========================================================================
# TPU — a pin whose name the deck cannot carry
# ===========================================================================
# A terminal's row is `i(<path>:<tname>)`, and the deck writes a `.probe` card
# for it only when the row passes ase::probe_split (src/ase.tcl), which lets no
# dollar sign, equals sign, single quote, brace, semicolon, comma, parenthesis,
# double quote or blank into either half.  An instance or a port can be called
# by such a name on a sheet.  The click refuses it before anything is queued or
# marked (ase::ui::sod_term_unwritable, asked by ase::ui::sod_terminal_pick).
#
# the whole sentence a refused click says for instance `inst`, pin `pin`, the
# row `ex` and the characters `chars` in words
proc tp_unwritable {inst pin ex chars} {
    return "ase: nothing queued for $inst pin $pin — its current would be the row '$ex', and a terminal-current row cannot hold $chars; rename the instance or the port, or place an ammeter (ammeter.sym) in series"
}
# the markers listed, without their points
proc tp_marks {} { return [lmap r [pcall xschem pin_marker list] { lrange $r 1 4 }] }
# one click on pin `pin` of `inst` under the scripted key: {queued notices tags markers}
proc tp_odd_at {inst pin} {
    pcall xschem pin_marker clear -fast
    set q [tp_at k $inst $pin]
    return [list $q $::notices $::ntags [tp_marks]]
}
group TPU {
    tp_odd_sheet ; tp_switches_reset
    tp_mode k outputs
    set names [lmap i {0 1 2 3 4 5 6 7} { pcall xschem getprop instance $i name }]
    set reach {}
    foreach {inst pin} {xe Y=1 R=9 P {R$8} P R'7 P V=2 p} {
        set term [pcall ase::ui::sod_terminal_at k {*}[tp_pin $inst $pin]]
        set nm [pcall ase::ui::sod_terminal_resolve k $term]
        lappend reach [list [tp_get $term instname] [tp_get $term pinname] [tp_get $nm ok] [tp_get $nm tokens]]
    }
    check "TPU0 fixture: SUCH NAMES REACH THE PICK -- the sheet loads with its instances under the names written, and for the block's port `Y=1` and for a pin of each device named with an equals sign, a dollar sign and a single quote the pin rule finds the pin and the resolver NAMES it, with that character in its token; so nothing ahead of the click refuses them (the instance names; per pin: the instance, the pin, named, the tokens)" \
        [list $names $reach] \
        [list {xe R=9 {R$8} R'7 V=2 R5 {xq[1:0]} {R=B[1:0]}} \
              [list {xe Y=1 1 xe:Y=1} {R=9 P 1 R=9:n1} [list {R$8} P 1 [list {R$8:n1}]] {R'7 P 1 R'7:n1} {V=2 p 1 V=2:n1}]]
    check "TPU1 A PORT CALLED `Y=1` IS REFUSED AT THE CLICK: nothing is queued, no pin is marked, and the one sentence, said as an error, names the instance and the pin, the row it would have been, the equals sign, and what to do; while the same block's port `A` queues its row and is marked (the refused click: queued, said, tags, markers; the control)" \
        [list [tp_odd_at xe Y=1] [tp_odd_at xe A]] \
        [list [list {} [list [tp_unwritable xe Y=1 i(xe:y=1) {an equals sign}]] error {}] \
              [list i(xe:a) {} {} {{xe 0 16 save}}]]
    check "TPU2 ...AND SO IS A PIN OF A DEVICE WHOSE OWN NAME HOLDS ONE, each with its character in words: an equals sign, a dollar sign, a single quote; a device with an ordinary name beside them queues and is marked" \
        [list [tp_odd_at R=9 P] [tp_odd_at {R$8} M] [tp_odd_at R'7 P] [tp_odd_at R5 P]] \
        [list [list {} [list [tp_unwritable R=9 P i(r=9:n1) {an equals sign}]] error {}] \
              [list {} [list [tp_unwritable {R$8} M {i(r$8:n2)} {a dollar sign}]] error {}] \
              [list {} [list [tp_unwritable R'7 P i(r'7:n1) {a single quote}]] error {}] \
              [list i(r5:n1) {} {} {{R5 0 16 save}}]]
    # Direct Plot: no results behind the scripted key, so no terminal is held
    tp_mode k plot
    set rplot [tp_odd_at R=9 P]
    set splot [tp_odd_at V=2 m]
    set sfirst [tp_odd_at V=2 p]
    set cplot [tp_odd_at R5 P]
    tp_mode k outputs
    check "TPU3 IN DIRECT PLOT the refusal is the same sentence -- not the advice to pick the row under Outputs, which would be refused there too; on the pin of a SOURCE with such a name the source's own current stands in, as for any pin that cannot be plotted, and on its second pin the sign note ends without that advice; a pin with an ordinary name is told where to ask for its row (a device pin; the source's second pin: queued, said; its first pin; the control's sentence names Outputs)" \
        [list $rplot [lrange $splot 0 1] [lrange $sfirst 0 1] [lindex $cplot 0] \
              [string match {*pick it under Outputs > To Be Saved > Select On Design and run again} [lindex $cplot 1 0]]] \
        [list [list {} [list [tp_unwritable R=9 P i(r=9:n1) {an equals sign}]] error {}] \
              [list i(v=2) [list "ase: V=2 pin m — the trace is the source's own current 'i(v=2)', which is the current into its first pin, so the current into V=2 pin m is the negative of that trace"]] \
              [list i(v=2) {}] {} 1]
    # the test itself, with no sheet: one token per character it must name
    set words {}
    foreach {tok want} [list x1:a=b {an equals sign} {x$1:in} {a dollar sign} x1:in' {a single quote} "x1:a\{b" {a brace} "x1:a\}b" {a brace} \
                             {x1:a;b} {a semicolon} x1:a,b {a comma} x1:a(b {a parenthesis} "x1:a\"b" {a double quote} {x1:a b} {a blank} \
                             x1:a:b {more than one colon} {x=1:a$b} {a dollar sign or an equals sign}] {
        set got [pcall ase::ui::sod_term_unwritable [list $tok] fold]
        lappend words [expr {[lindex $got 1] eq $want && [lindex $got 0] eq "i($tok)" ? {ok} : [list $tok $got]}]
    }
    # ...and its agreement with the deck's predicate over ordinary names
    set agree {}
    foreach tok {R9:n1 x1.xm1:d X1:IN+ xm<2>:d {xm1[3]:d} x1:in- x1.x2.r1:n2} {
        lappend agree [list [llength [pcall ase::probe_split "i([string tolower $tok])"]] [pcall ase::ui::sod_term_unwritable [list $tok] fold]]
    }
    check "TPU4 THE TEST ITSELF, sheet apart: each character the deck's predicate keeps out of a terminal row is named in words, with the row; a token holding two of them names both; and every ordinary name the predicate takes as a terminal answers nothing -- hierarchy dots, a plus, a minus, angle and square brackets among them (per odd token: ok, or what came back; per ordinary token: the predicate's two halves and the test's answer)" \
        [list [lsort -unique $words] [llength $words] $agree] \
        [list ok 12 {{2 {}} {2 {}} {2 {}} {2 {}} {2 {}} {2 {}} {2 {}}}]
    set busclick [tp_odd_at {xq[1:0]} Y=1]
    set busdlg $::dlg
    set busctl [tp_odd_at {xq[1:0]} A]
    set busctl_dlg [llength $::dlg]
    check "TPU5 SEVERAL VECTORS: the port `Y=1` of a two-bit bus instance is refused whole and BEFORE THE BIT DIALOG -- no dialog is opened, nothing is queued or marked, and the sentence names the first row that is not a terminal row; the test itself names the first odd token of a list whose first is ordinary, and carries the case mode into the row it names; the same instance's port `A` goes through the dialog and queues both its rows (the click: queued, said, tags, markers; the dialogs opened; the control's queue and its one dialog; the test with fold, with preserve, and with two ordinary tokens)" \
        [list $busclick $busdlg [lindex $busctl 0] $busctl_dlg [pcall ase::ui::sod_term_unwritable {R1:n1 R=2:n1 R$3:n1} fold] \
              [pcall ase::ui::sod_term_unwritable {R1:n1 R=2:n1} preserve] [pcall ase::ui::sod_term_unwritable {R1:n1 R2:n1} fold]] \
        [list [list {} [list [tp_unwritable {xq[1:0]} Y=1 {i(xq[1]:y=1)} {an equals sign}]] error {}] {} \
              [list {i(xq[1]:a)} {i(xq[0]:a)}] 1 {i(r=2:n1) {an equals sign}} {i(R=2:n1) {an equals sign}} {}]
    # a bus instance whose own name holds the character: its bits come back without it
    set box0 [llength $::tp_boxes]
    set oddterm [pcall ase::ui::sod_terminal_at k {*}[tp_pin {R=B[1:0]} P]]
    set oddnm [pcall ase::ui::sod_terminal_resolve k $oddterm]
    set oddbus [tp_odd_at {R=B[1:0]} P]
    set oddbus_dlg $::dlg
    set oddwords [lmap n {R=9 {RB[1:0]} {x1[3,2]} {R$8} "a b" x(1) R5} { pcall ase::ui::sod_term_odd_inst $n }]
    set ::tp_box_tpu6 [list $box0 [llength $::tp_boxes]]
    check "TPU6 A BUS INSTANCE WHOSE OWN NAME HOLDS ONE is refused by its name: the engine's bit expansion drops the equals sign, so the pin is named by an ordinary token the test of TPU4 passes (fixture leg), and the click still queues nothing, opens no dialog, marks nothing and says the instance's name holds an equals sign; the name test judges no comma, colon or bracket, which are bus syntax in an instance name; and all the ENGINE asked for meanwhile is its own notice about that name, in a message box, once at most and only where there is a display (the count is what this arm allows; the boxes about anything else)" \
        [list [list [tp_get $oddnm ok] [tp_get $oddnm tokens] [pcall ase::ui::sod_term_unwritable [tp_get $oddnm tokens] fold]] \
              $oddbus $oddbus_dlg $oddwords [tp_boxes_about $box0 {R=B[1:0]}]] \
        [list {1 R:n1 {}} \
              [list {} [list "ase: nothing queued for R=B\[1:0\] pin P — the instance's name holds an equals sign, which a terminal-current row cannot hold; rename the instance, or place an ammeter (ammeter.sym) in series"] error {}] {} \
              {{an equals sign} {} {} {a dollar sign} {a blank} {a parenthesis} {}} {1 {}}]
    pcall xschem pin_marker clear -fast
    tp_home
}

# ===========================================================================
# TPL — the mode's lifecycle: entering, the canvas slots, the canvas going away
# ===========================================================================
# No canvas is seized here.  Inside namespace ase::ui, and nowhere else, the
# three Tk words the lifecycle uses are stood in for: `bind` reads and writes a
# table of what each slot of each canvas holds and logs every call, `winfo
# exists` answers from a list of the canvases that are there, `focus` does
# nothing.  So the rows read every binding the mode makes and hands back, on
# either arm.  The real canvas, real events and a real window being closed are
# in test_ase_interact, test_cmdmode_descend_0201, test_sod_pick_no_select_0204
# and band P of test_pin_marker_1724.
proc tp_life_on {} {
    array unset ::tp_slot
    set ::tp_log {}
    set ::tp_there [list [pcall xschem get current_win_path] .tpd]
    proc ::ase::ui::bind {w args} {
        set seq [lindex $args 0]
        if {[llength $args] == 1} {
            lappend ::tp_log [list read $w $seq]
            return [expr {[info exists ::tp_slot($w,$seq)] ? $::tp_slot($w,$seq) : {}}]
        }
        lappend ::tp_log [list write $w $seq]
        set ::tp_slot($w,$seq) [lindex $args 1]
        return {}
    }
    proc ::ase::ui::winfo {sub args} {
        return [expr {$sub eq {exists} ? ([lsearch -exact $::tp_there [lindex $args 0]] >= 0) : 1}]
    }
    proc ::ase::ui::focus {args} { return {} }
}
proc tp_life_off {} { foreach c {bind winfo focus} { catch {rename ::ase::ui::$c {}} } }
# the slots the mode takes, in the order the rows list them: the press, the
# double click, the release, the motion with the button held, ESC, the
# canvas's destruction
set TP_SLOTS {<ButtonPress-1> <Double-Button-1> <ButtonRelease-1> <B1-Motion> <Key-Escape> <Destroy>}
# the script the mode binds on the press and on the double click for `key`
proc tp_press {key} { return "xschem callback %W 6 %x %y 0 0 0 %s; [list ase::ui::sod_click $key]; break" }
# what those slots of canvas `w` hold in the table
proc tp_slots {w} {
    return [lmap s $::TP_SLOTS { expr {[info exists ::tp_slot($w,$s)] ? $::tp_slot($w,$s) : {}} }]
}
# the sequences a proc's body spells, sorted: a text scan, which sees only a
# sequence written out in the body
proc tp_seqs {name} { return [lsort -unique [regexp -all -inline {<[A-Za-z0-9-]+>} [pcall info body $name]]] }
# end whatever mode a row left, without finishing it
proc tp_life_drop {args} {
    foreach key $args { catch {ase::ui::sod_release $key} ; array unset ase::ui::sod $key,* }
    unset -nocomplain ase::ui::sod(active)
}
# the idle calls waiting to drop a mode whose canvas went away
proc tp_idle_drops {} {
    set out {}
    foreach id [after info] {
        set scr [lindex [after info $id] 0]
        if {[lindex $scr 0] eq {ase::ui::sod_drop_gone}} { lappend out $scr ; after cancel $id }
    }
    return $out
}
set TP_EDITOR {xschem callback %W -3 %x %y 0 %b 0 %s}
set TP_GONE "ase: the design window the pick mode was on is gone — mode dropped"
# ...and what follows it when Direct Plot's queue held `n` traces
proc tp_gone_plot {n} {
    set what [expr {$n == 1 ? {1 queued trace was} : "$n queued traces were"}]
    set whose [expr {$n == 1 ? {its pick} : {their picks}}]
    return "$::TP_GONE; $what not plotted, and the colours $whose left on the schematic stay until the highlights are cleared (Highlight > Un-highlight all net/pins, or its key)"
}

group TPL {
    tp_home ; tp_switches_reset
    check "TPL0 the lifecycle's seams, read off the interpreter: the seize takes (key cv), the two halves of the canvas going away (key w), the drop (key), the window test (key), the prompt for a point (key x y) and for the pointer now (key), the mode's words (mode), the own-script test (script) and the sentence for a click elsewhere (key)" \
        [lmap p {sod_seize sod_canvas_gone sod_drop_gone sod_drop sod_design_shown sod_prompt_text sod_prompt_now sod_prompt_base sod_own_script sod_elsewhere_notice} { pcall info args ::ase::ui::$p }] \
        {{key cv} {key w} {key w} key key {key x y} key mode script key}
    check "TPL0b ...and the seams beside them: the slot table and the press script take (key), the list of what the mode holds takes nothing -- src/cmdmode.tcl calls it with no argument -- the editor's double-click script takes (cv), the canvas of a context takes (ctx) and it defaults to empty, the current one, and the test for a name the deck cannot carry takes (toks cmode), its sibling for the instance's own name (iname)" \
        [list [lmap p {sod_slots sod_press_script sod_held sod_dbl_editor sod_canvas sod_term_unwritable sod_term_odd_inst} { pcall info args ::ase::ui::$p }] \
              [list [pcall info default ::ase::ui::sod_canvas ctx tp_dctx] [expr {[info exists tp_dctx] ? $tp_dctx : {UNSET}}]]] \
        {{key key {} cv ctx {toks cmode} iname} {1 {}}}
    tp_life_on
    set cv [pcall xschem get current_win_path]
    # ---- entering ends a Calculator pick first
    set ::tp_calc_live 1
    tp_stub ::calc::pick_running {} { lappend ::tp_log calc-asked ; return $::tp_calc_live }
    tp_stub ::calc::pick_end {{why cancel}} { lappend ::tp_log [list calc-end $why] ; set ::tp_calc_live 0 ; return 1 }
    pcall ase::ui::select_on_design kprev {save 1 plot 0} outputs 0
    set ::tp_calc_live 1 ; set ::tp_log {}
    set rc1 [pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0]
    set log1 $::tp_log
    set at [lsearch -exact $log1 {calc-end cancel}]
    set firstbind -1
    for {set i 0} {$i < [llength $log1]} {incr i} {
        if {[lindex $log1 $i 0] in {read write}} { set firstbind $i ; break }
    }
    check "TPL1 ENTERING THE MODE ENDS A CALCULATOR PICK FIRST: with a Calculator selector waiting for its click and a mode of another session up, the entry asks the Calculator, ends its pick with `cancel` exactly once, and only then touches a binding -- the previous mode's are handed back and this one's read after it, so the Calculator's scripts are never kept as what the canvas had (armed; the first two things done; ends counted; a binding was touched, and later than the end; the mode now up)" \
        [list $rc1 [lrange $log1 0 1] [llength [lsearch -all -exact $log1 {calc-end cancel}]] \
              [expr {$firstbind > $at && $at >= 0 ? 1 : 0}] [pcall set ase::ui::sod(active)]] \
        [list 1 {calc-asked {calc-end cancel}} 1 1 kL]
    set ::tp_calc_live 0 ; set ::tp_log {}
    set rc2 [pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0]
    set quiet [llength [lsearch -all -exact $::tp_log {calc-end cancel}]]
    tp_unstub ::calc::pick_running ; tp_unstub ::calc::pick_end
    tp_stub ::calc::pick_running {} { error {no calculator here} }
    set rc3 [pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0]
    tp_unstub ::calc::pick_running
    check "TPL1b ...with no Calculator pick live nothing of the Calculator's is ended, and a Calculator that cannot be asked does not stop the mode from arming" \
        [list $rc2 $quiet $rc3 [pcall set ase::ui::sod(active)]] {1 0 1 kL}
    # ---- ...and the Results window's pick mode is asked to take the canvas
    # again after each mode this entry ends.  What the entry did, in order, up
    # to its first read of a binding: the words logged, with each binding call
    # shown by its kind alone.
    proc tp_entry_steps {log} {
        set out {}
        foreach e $log {
            if {[lindex $e 0] eq {read}} { break }
            lappend out [expr {[lindex $e 0] eq {write} ? {write} : $e}]
        }
        return $out
    }
    namespace eval ::rdw {}
    tp_stub ::rdw::pick_reseat {} { lappend ::tp_log reseat ; return 0 }
    set ::tp_calc_live 1
    tp_stub ::calc::pick_running {} { lappend ::tp_log calc-asked ; return $::tp_calc_live }
    tp_stub ::calc::pick_end {{why cancel}} { lappend ::tp_log [list calc-end $why] ; set ::tp_calc_live 0 ; return 1 }
    # the mode kL is up from the entry above
    set ::tp_log {}
    set rc4 [pcall ase::ui::select_on_design kM {save 1 plot 0} outputs 0]
    set steps_both [tp_entry_steps $::tp_log]
    tp_life_drop kM kL
    set ::tp_calc_live 0 ; set ::tp_log {}
    set rc5 [pcall ase::ui::select_on_design kM {save 1 plot 0} outputs 0]
    set steps_none [tp_entry_steps $::tp_log]
    tp_life_drop kM
    tp_unstub ::calc::pick_running ; tp_unstub ::calc::pick_end
    # a Results window that raises when asked, and one that is not loaded
    proc ::rdw::pick_reseat {} { error {no results window here} }
    set rc6 [pcall ase::ui::select_on_design kM {save 1 plot 0} outputs 0]
    catch {rename ::rdw::pick_reseat {}}
    set gone [llength [info commands ::rdw::pick_reseat]]
    set rc7 [pcall ase::ui::select_on_design kM {save 1 plot 0} outputs 0]
    tp_unstub ::rdw::pick_reseat
    check "TPL1c THE RESULTS WINDOW'S PICK MODE IS ASKED TO TAKE THE CANVAS AGAIN AFTER EACH MODE THE ENTRY ENDS: with a Calculator pick live and a mode of another session up, the entry ends the Calculator's pick, asks the Results window, hands the six slots of the mode that was up back, asks the Results window again, and only then reads a binding for its own seize; with neither of the two up it asks once, after the Calculator line, and not for an end that did not happen; and a Results window that raises when asked, or is not loaded at all, does not stop the mode from arming (armed; the steps before the first read, both up; armed; the steps, neither up; armed with a Results window that raises; the proc is gone, and armed without it)" \
        [list $rc4 $steps_both $rc5 $steps_none $rc6 $gone $rc7] \
        [list 1 {calc-asked {calc-end cancel} reseat write write write write write write reseat} 1 {calc-asked reseat} 1 0 1]
    tp_life_drop kM kL kprev

    # ---- the slots: seized, and handed back verbatim
    array unset ::tp_slot
    set ::tp_slot($cv,<Double-Button-1>) $TP_EDITOR
    set ::tp_slot($cv,<B1-Motion>) {their drag %x %y}
    set ::tp_slot($cv,<Key-Escape>) {their escape; break}
    set ::tp_slot($cv,<Destroy>) {their destroy %W}
    set before [tp_slots $cv]
    set ::tp_log {}
    set rc [pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0]
    set seized [tp_slots $cv]
    set wrote_in [lsort -unique [lmap e $::tp_log { expr {[lindex $e 0] eq {write} ? [lindex $e 2] : [continue]} }]]
    set pick [tp_press kL]
    check "TPL2 THE SLOTS THE MODE SEIZES, THE DOUBLE CLICK AND THE HELD MOTION AMONG THEM: the press and the double click both run the pick, each after handing the engine the press's own position as a pointer motion; the release and the motion with the button held are swallowed; ESC ends the mode; and the hook for the canvas going away is added BEHIND the handler the canvas already had for it (armed; what the slots hold, in the order press, double click, release, held motion, ESC, destroy; the sequences written)" \
        [list $rc $seized $wrote_in] \
        [list 1 [list $pick $pick break break "ase::ui::sod_end kL; break" "their destroy %W\nase::ui::sod_canvas_gone kL %W"] [lsort $TP_SLOTS]]
    set ::tp_log {}
    set rel [pcall ase::ui::sod_release kL]
    set wrote_out [lsort -unique [lmap e $::tp_log { expr {[lindex $e 0] eq {write} ? [lindex $e 2] : [continue]} }]]
    check "TPL2b ...AND HANDS EACH BACK AS IT WAS: after the release the slots hold what they held before the mode -- nothing on the press and the release, the editor's own double-click script, the canvas's own held-motion, ESC and destroy handlers -- and the release wrote the same sequences the entry did; the slot table and the release spell the same ones (released; the slots after against before; the sequences written; the sequences the table's body and the release's body spell)" \
        [list $rel [expr {[tp_slots $cv] eq $before ? {as before} : [tp_slots $cv]}] $before $wrote_out \
              [tp_seqs ::ase::ui::sod_slots] [tp_seqs ::ase::ui::sod_release]] \
        [list 1 {as before} [list {} $TP_EDITOR {} {their drag %x %y} {their escape; break} {their destroy %W}] [lsort $TP_SLOTS] \
              [lsort $TP_SLOTS] [lsort $TP_SLOTS]]
    tp_life_drop kL

    # ---- a paused mode comes back up on ANOTHER canvas
    array unset ::tp_slot
    set ::tp_slot($cv,<Double-Button-1>) $TP_EDITOR
    set ::tp_slot(.tpd,<Double-Button-1>) {the other canvas's double click}
    set ::tp_slot(.tpd,<Key-Escape>) {the other canvas's escape}
    pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0
    set sus [pcall ase::ui::sod_suspend]
    set paused [tp_slots $cv]
    set res [pcall ase::ui::sod_resume .tpd]
    set up_first [tp_slots $cv]
    set up_second [tp_slots .tpd]
    pcall ase::ui::sod_release kL
    check "TPL3 A PAUSED MODE THAT COMES BACK UP ON ANOTHER CANVAS takes what THAT canvas holds as its previous bindings: pausing hands the first canvas its own back; resuming on the second seizes the second and leaves the first alone; and the release gives the second its own double-click and ESC scripts back, not the first canvas's (paused, and the first canvas then; resumed, the first and the second canvas then; the second after the release)" \
        [list $sus $paused $res $up_first $up_second [tp_slots .tpd]] \
        [list 1 [list {} $TP_EDITOR {} {} {} {}] 1 [list {} $TP_EDITOR {} {} {} {}] \
              [list $pick $pick break break "ase::ui::sod_end kL; break" "ase::ui::sod_canvas_gone kL %W"] \
              [list {} {the other canvas's double click} {} {} {the other canvas's escape} {}]]
    tp_life_drop kL

    # ---- the mode's own scripts are never kept as the previous bindings
    array unset ::tp_slot
    set ::tp_slot($cv,<Double-Button-1>) $TP_EDITOR
    pcall ase::ui::sod_seize kL $cv
    pcall ase::ui::sod_seize kL $cv
    set twice [pcall ase::ui::sod_release kL]
    set after_twice [tp_slots $cv]
    tp_life_drop kL
    array unset ::tp_slot
    set ::tp_slot(.tpd,<ButtonPress-1>) {ase::ui::sod_click dead; break}
    set ::tp_slot(.tpd,<ButtonRelease-1>) break
    set ::tp_slot(.tpd,<B1-Motion>) break
    set ::tp_slot(.tpd,<Key-Escape>) {ase::ui::sod_end dead; break}
    set ::tp_slot(.tpd,<Destroy>) {ase::ui::sod_canvas_gone dead %W}
    set ::tp_slot(.tpd,<Double-Button-1>) $TP_EDITOR
    pcall ase::ui::sod_seize kL .tpd
    set over_dead [tp_slots .tpd]
    pcall ase::ui::sod_release kL
    set after_dead [tp_slots .tpd]
    tp_life_drop kL
    array unset ::tp_slot
    set ::tp_slot(.tpd,<ButtonPress-1>) {their press}
    set ::tp_slot(.tpd,<ButtonRelease-1>) break
    set ::tp_slot(.tpd,<B1-Motion>) break
    pcall ase::ui::sod_seize kL .tpd
    pcall ase::ui::sod_release kL
    set after_theirs [tp_slots .tpd]
    tp_life_drop kL
    check "TPL4 A SLOT THAT ALREADY HOLDS THE MODE'S OWN SCRIPT IS NEVER KEPT AS THE PREVIOUS BINDING: a canvas seized twice for one session is handed back what it had before the first; a canvas carrying the scripts of a mode that is no longer there -- the press as an earlier build spelled it, the bare `break` on the release and on the held motion -- is seized over them and left with none of them, its own double-click script kept; and a `break` that somebody else bound on the release and on the held motion, beside a press of their own, is theirs and is handed back (released; the slots after a double seize; the slots seized over dead scripts, and after; the slots after the foreign three)" \
        [list $twice $after_twice $over_dead $after_dead $after_theirs] \
        [list 1 [list {} $TP_EDITOR {} {} {} {}] \
              [list $pick $pick break break "ase::ui::sod_end kL; break" "ase::ui::sod_canvas_gone kL %W"] \
              [list {} $TP_EDITOR {} {} {} {}] [list {their press} {} break break {} {}]]

    # ---- the double click, with no record of what the slot held
    array unset ::tp_slot
    foreach {s scr} [list <ButtonPress-1> [tp_press dead] <Double-Button-1> [tp_press dead] <ButtonRelease-1> break \
                          <B1-Motion> break <Key-Escape> {ase::ui::sod_end dead; break} <Double-Button-2> $TP_EDITOR] {
        set ::tp_slot(.tpd,$s) $scr
    }
    pcall ase::ui::sod_seize kL .tpd
    set lost_rec [pcall set ase::ui::sod(kL,prevdbl)]
    pcall ase::ui::sod_release kL
    set lost_after [tp_slots .tpd]
    tp_life_drop kL
    array unset ::tp_slot
    set ::tp_slot(.tpd,<ButtonPress-1>) [tp_press dead]
    set ::tp_slot(.tpd,<Double-Button-1>) [tp_press dead]
    pcall ase::ui::sod_seize kL .tpd
    pcall ase::ui::sod_release kL
    set lost_bare [tp_slots .tpd]
    tp_life_drop kL
    array unset ::tp_slot
    set ::tp_slot(.tpd,<Double-Button-1>) {their double click}
    set ::tp_slot(.tpd,<Double-Button-2>) $TP_EDITOR
    pcall ase::ui::sod_seize kL .tpd
    pcall ase::ui::sod_seize kL .tpd
    pcall ase::ui::sod_release kL
    set kept_rec [tp_slots .tpd]
    tp_life_drop kL
    check "TPL4b A LOST RECORD DOES NOT TAKE THE EDITOR'S DOUBLE CLICK AWAY: a canvas whose double-click slot holds the script of a mode that is no longer there, seized with nothing on record for it, is handed back the editor's own double-click script -- read off the middle button's double click, which no click mode takes -- and nothing on the other slots; where that cannot be read the slot is left empty; and a record that IS there wins over it (what the seize put on record; the slots after the release; with no middle-button script; seized twice over somebody else's double click)" \
        [list $lost_rec $lost_after $lost_bare $kept_rec] \
        [list $TP_EDITOR [list {} $TP_EDITOR {} {} {} {}] [list {} {} {} {} {} {}] [list {} {their double click} {} {} {} {}]]

    # ---- the canvas going away under the mode
    array unset ::tp_slot
    set ::tp_dp 0
    tp_stub ::ase::ui::dp_finish {key queue {qcolors {}}} { incr ::tp_dp }
    pcall xschem pin_marker clear -fast
    pcall xschem pin_marker add -fast -tag save R9 P
    pcall xschem pin_marker add -fast -tag plot R9 M
    pcall ase::ui::select_on_design kL {save 0 plot 1} plot 0
    set ase::ui::sod(kL,queue) {v(a) v(b)} ; set ase::ui::sod(kL,count) 2
    tp_idle_drops
    pcall ase::ui::sod_canvas_gone kL .tpd
    set idle_other [tp_idle_drops]
    pcall ase::ui::sod_canvas_gone kL $cv
    set idle_own [tp_idle_drops]
    check "TPL5 THE CANVAS'S DESTROY HOOK ONLY PUTS THE WORK OFF: for a widget that is not the mode's canvas (a copy of the binding on another canvas) nothing is scheduled; for the mode's canvas one idle call is, to drop the mode once the window is gone -- while a window is torn down the engine has no sheet to ask" \
        [list $idle_other $idle_own] [list {} [list [list ase::ui::sod_drop_gone kL $cv]]]
    set ::notices {} ; set ::ntags {}
    set kept {}
    pcall ase::ui::sod_drop_gone kL $cv
    lappend kept [info exists ase::ui::sod(kL,canvas)]
    set ::tp_there {}
    pcall ase::ui::sod_drop_gone kL .tpd
    lappend kept [info exists ase::ui::sod(kL,canvas)]
    set ase::ui::sod(kL,suspended) 1
    pcall ase::ui::sod_drop_gone kL $cv
    lappend kept [info exists ase::ui::sod(kL,canvas)]
    unset -nocomplain ase::ui::sod(kL,suspended)
    set ase::ui::sod(active) another
    pcall ase::ui::sod_drop_gone kL $cv
    lappend kept [info exists ase::ui::sod(kL,canvas)]
    set ase::ui::sod(active) kL
    set quiet $::notices
    set marks0 [lmap r [pcall xschem pin_marker list] { lrange $r 1 4 }]
    pcall ase::ui::sod_drop_gone kL $cv
    set pumps [lmap id [after info] { expr {[lindex [after info $id] 0 0] eq {ase::ui::sod_prompt_pump} ? 1 : [continue]} }]
    check "TPL6 ...AND THE MODE IS DROPPED ONLY WHEN ITS OWN CANVAS IS REALLY GONE: with the canvas still there, for another canvas, while the mode is paused, and while another session's mode is the one that is up (whose markers a sweep would take), nothing happens and nothing is said; with the canvas gone the mode is no longer up, its records are gone, the row flavours' pin markers are taken away and Direct Plot's is left, one sentence says so as an error -- and, this being Direct Plot with two traces queued, that the two were not plotted and how their colours go from the schematic -- the queued traces are not plotted, and no prompt timer is left (the mode's records still there in the four cases; said in them; the markers before; then: up, records, markers, the sentence, its tag, plots, timers)" \
        [list $kept $quiet $marks0 [info exists ase::ui::sod(active)] [array names ase::ui::sod kL,*] \
              [lmap r [pcall xschem pin_marker list] { lrange $r 1 4 }] $::notices $::ntags $::tp_dp $pumps] \
        [list {1 1 1 1} {} {{R9 0 16 save} {R9 1 16 plot}} 0 {} {{R9 1 16 plot}} [list [tp_gone_plot 2]] error 0 {}]
    # ---- what the drop says, per flavour and queue; no mode is up, the
    # records are armed by hand and the drop is asked directly
    set drops {}
    foreach {mode queue count} {plot {i(r9:n1)} 1  plot {} 0  outputs {} 3  plot {v(a) v(b) i(v1)} 3  outputs {v(a) v(b)} 2} {
        array unset ase::ui::sod kD,*
        array set ase::ui::sod [list kD,flavor {save 1 plot 0} kD,mode $mode kD,count $count kD,queue $queue]
        set ::notices {} ; set ::ntags {}
        pcall ase::ui::sod_drop kD
        lappend drops [list $::notices $::ntags [array names ase::ui::sod kD,*]]
    }
    check "TPL6b WHAT THE DROP SAYS ABOUT A QUEUE THAT WAS NOT PLOTTED: in Direct Plot with ONE trace queued the sentence says one was not plotted, in the singular; with none queued it says nothing of traces; in the outputs flavours, whose rows are in the session already, it says nothing of them either, however many were queued; with three queued it says three; and an outputs flavour whose records hold a queue of two all the same says nothing of traces, the flavour and not the queue deciding -- each time one sentence, an error, and the records gone; and Direct Plot's marker on the sheet is still there, the drop having cleared none (per case: said, tag, records left; the markers)" \
        [list $drops [lmap r [pcall xschem pin_marker list] { lrange $r 1 4 }]] \
        [list [list [list [list [tp_gone_plot 1]] error {}] [list [list $TP_GONE] error {}] \
                    [list [list $TP_GONE] error {}] [list [list [tp_gone_plot 3]] error {}] \
                    [list [list $TP_GONE] error {}]] {{R9 1 16 plot}}]
    # ---- a paused mode whose canvas is gone when it is resumed
    set ::tp_there [list $cv .tpd]
    pcall xschem pin_marker add -fast -tag save R9 P
    pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0
    pcall ase::ui::sod_suspend
    set ::tp_there {}
    set ::notices {} ; set ::ntags {}
    set res [pcall ase::ui::sod_resume .tpd]
    check "TPL7 a paused mode with no canvas left to come back to is dropped the same way when it is resumed: it answers 0, the mode is no longer up, the row flavours' marker is gone, and the same sentence is said" \
        [list $res [info exists ase::ui::sod(active)] [array names ase::ui::sod kL,*] \
              [lmap r [pcall xschem pin_marker list] { lrange $r 1 4 }] $::notices $::ntags] \
        [list 0 0 {} {{R9 1 16 plot}} [list $TP_GONE] error]
    tp_unstub ::ase::ui::dp_finish
    pcall xschem pin_marker clear -fast
    tp_life_drop kL
    # ---- a click refused for the window leaves the mode as it was
    set ::tp_there [list $cv .tpd]
    array unset ::tp_slot
    set rc [pcall ase::ui::select_on_design $GEOKEY {save 1 plot 0} outputs 0]
    set ::queued {} ; set ::notices {}
    pcall ase::ui::sod_click $GEOKEY {*}[tp_pin R9 P]
    check "TPL8 A CLICK REFUSED FOR THE WINDOW LEAVES THE MODE ARMED: the mode entered for the third sheet's session while the window shows the top sheet, and a click on R9's pin there -- nothing is queued, the one sentence names that session's design, the mode is still the one up and the canvas is still seized for it (armed; the queue; the sentence; the mode up; the press slot)" \
        [list $rc $::queued $::notices [pcall set ase::ui::sod(active)] [lindex [tp_slots $cv] 0]] \
        [list 1 {} [list [string map {tplib/tp_top tplib/tp_geo} $TP_ELSEWHERE]] $GEOKEY [tp_press $GEOKEY]]
    tp_life_drop $GEOKEY
    tp_mode $GEOKEY outputs

    # ---- what the mode reports it holds
    array unset ::tp_slot
    set ::tp_slot($cv,<Double-Button-1>) $TP_EDITOR
    set ::tp_slot($cv,<Key-Escape>) {their escape; break}
    set ::tp_slot($cv,<Destroy>) {their destroy %W}
    set held_none [pcall ase::ui::sod_held]
    pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0
    set groups {}
    foreach {c s o p} [pcall ase::ui::sod_held] { lappend groups [list $c $s $o $p] }
    set in_slot [lmap g $groups { expr {[info exists ::tp_slot([lindex $g 0],[lindex $g 1])] && $::tp_slot([lindex $g 0],[lindex $g 1]) eq [lindex $g 2] ? 1 : 0} }]
    set ask {}
    lappend ask [pcall cmdmode::pristine $cv <ButtonPress-1> $pick] [pcall cmdmode::pristine $cv <Double-Button-1> $pick] \
                [pcall cmdmode::pristine $cv <B1-Motion> break] \
                [pcall cmdmode::pristine $cv <Destroy> "their destroy %W\nase::ui::sod_canvas_gone kL %W"] \
                [pcall cmdmode::pristine $cv <Key-Escape> {a script of somebody else}] [pcall cmdmode::pristine .tpd <ButtonPress-1> $pick]
    pcall ase::ui::sod_suspend
    set held_paused [pcall ase::ui::sod_held]
    pcall ase::ui::sod_resume .tpd
    set held_moved [lsort -unique [lmap {c s o p} [pcall ase::ui::sod_held] { set c }]]
    pcall ase::ui::sod_end kL
    set held_ended [pcall ase::ui::sod_held]
    set ask_ended [pcall cmdmode::pristine $cv <ButtonPress-1> $pick]
    check "TPL9 WHAT THE MODE REPORTS IT HOLDS: nothing with no mode up; with the mode up one group per slot -- the canvas, the sequence, the script bound there and the script the slot held before, the destroy group holding the WHOLE bound script with the canvas's own handler as its predecessor -- and each group's script is what that slot holds; nothing while the mode is paused; the other canvas once it has come back up there; nothing after it ended (no mode; the groups; each is in its slot; paused; the canvas after the resume; ended)" \
        [list $held_none $groups $in_slot $held_paused $held_moved $held_ended] \
        [list {} [list [list $cv <ButtonPress-1> $pick {}] [list $cv <Double-Button-1> $pick $TP_EDITOR] \
                       [list $cv <ButtonRelease-1> break {}] [list $cv <B1-Motion> break {}] \
                       [list $cv <Key-Escape> "ase::ui::sod_end kL; break" {their escape; break}] \
                       [list $cv <Destroy> "their destroy %W\nase::ui::sod_canvas_gone kL %W" {their destroy %W}]] \
              {1 1 1 1 1 1} {} .tpd {}]
    check "TPL9b ...AND src/cmdmode.tcl IS GIVEN THAT LIST: the mode is registered with it as its fourth word, and while the mode is up the script a slot holds underneath it is asked for through cmdmode -- nothing under the press and under the held motion, the editor's script under the double click, the canvas's own handler under the destroy hook; a script of somebody else's and the same script on another canvas come back unchanged; and once the mode has ended the press script is nobody's and comes back unchanged (the registration; the six answers; after the end)" \
        [list [lindex [pcall dict get $::cmdmode::modes ase_sod] 2] $ask [expr {$ask_ended eq $pick ? {unchanged} : $ask_ended}]] \
        [list ase::ui::sod_held [list {} $TP_EDITOR {} {their destroy %W} {a script of somebody else} $pick] unchanged]
    tp_life_drop kL

    # ---- another click mode under this one, and over it.  The Results
    # window's pick mode nests with Select On Design.  It is stood in for here
    # by a mode of this file's own, `tpo`, which does what every click mode
    # does: it holds five slots, tells src/cmdmode.tcl what it holds and what
    # each slot held before it, and when it ends it writes those back.
    set TPO_SEQS {<ButtonPress-1> <ButtonRelease-1> <Key-Escape> <B1-Motion> <Double-Button-1>}
    set TPO_OWN {{tpo::click; break} break {tpo::end; break} break break}
    set ::tpo_held {}
    proc tpo_held {} { return $::tpo_held }
    proc tpo_zero {args} { return 0 }
    # the other mode takes canvas `w`: what each of its slots holds goes on
    # its record, its own scripts into the slots
    proc tpo_seize {w} {
        set ::tpo_held {}
        foreach s $::TPO_SEQS o $::TPO_OWN {
            lappend ::tpo_held $w $s $o [expr {[info exists ::tp_slot($w,$s)] ? $::tp_slot($w,$s) : {}}]
            set ::tp_slot($w,$s) $o
        }
    }
    # ...and ends: every slot gets back what the record holds for it
    proc tpo_end {} {
        foreach {w s o p} $::tpo_held { set ::tp_slot($w,$s) $p }
        set ::tpo_held {}
    }
    # the six predecessors Select On Design has on record for `key`, in the
    # order of TP_SLOTS; NOKEY where it has none
    proc tp_prevs {key} {
        return [lmap r {prevpress prevdbl prevrel prevmotion prevesc prevdestroy} {
            expr {[info exists ::ase::ui::sod($key,$r)] ? $::ase::ui::sod($key,$r) : {NOKEY}}
        }]
    }
    # the prompt timers that are waiting, as the scripts they will run
    proc tp_pumps {} {
        return [lmap id [after info] { expr {[lindex [after info $id] 0 0] eq {ase::ui::sod_prompt_pump} ? [lindex [after info $id] 0] : [continue]} }]
    }
    pcall cmdmode::register tpo_mode tpo_zero tpo_zero tpo_held
    proc ::ase::ui::focus {args} { lappend ::tp_log [list focus {*}$args] ; return {} }
    # no prompt timer of an earlier row is waiting when the count below is taken
    foreach id [after info] { if {[lindex [after info $id] 0 0] eq {ase::ui::sod_prompt_pump}} { after cancel $id } }
    array unset ::tp_slot
    set ::tp_slot($cv,<Double-Button-1>) $TP_EDITOR
    set ::tp_slot($cv,<Destroy>) {their destroy %W}
    set free [tp_slots $cv]
    set sodsix [list $pick $pick break break "ase::ui::sod_end kL; break" "their destroy %W\nase::ui::sod_canvas_gone kL %W"]
    set r_none [pcall ase::ui::sod_reseat]
    # the other mode first, Select On Design over it
    tpo_seize $cv
    pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0
    set ase::ui::sod(kL,count) 3
    set ase::ui::sod(kL,queue) {v(a) v(b)}
    pcall xschem pin_marker clear -fast
    pcall xschem pin_marker add -fast -tag save R9 P
    set over_rec [tp_prevs kL]
    set r_top [list [pcall ase::ui::sod_reseat] [expr {[tp_slots $cv] eq $sodsix ? {its six} : [tp_slots $cv]}]]
    set r_bare NOREADER
    if {[llength [info commands ::cmdmode::pristine]]} {
        rename ::cmdmode::pristine ::cmdmode::tp_pristine_kept
        set r_bare [list [pcall ase::ui::sod_reseat] [expr {[tp_prevs kL] eq $over_rec ? {record kept} : [tp_prevs kL]}]]
        rename ::cmdmode::tp_pristine_kept ::cmdmode::pristine
    }
    # the other mode is ended first, from underneath
    tpo_end
    set stranded [list [info exists ase::ui::sod(active)] [lrange [tp_slots $cv] 0 4] [lindex [tp_slots $cv] 5]]
    # the mode's own records, its prompt timers and the markers on the sheet
    proc tp_kept {} {
        return [list [array get ::ase::ui::sod kL,flavor] [array get ::ase::ui::sod kL,mode] [array get ::ase::ui::sod kL,count] \
                     [array get ::ase::ui::sod kL,queue] [array get ::ase::ui::sod kL,prompt] [tp_pumps] \
                     [lmap r [pcall xschem pin_marker list] { lrange $r 1 4 }]]
    }
    set kept0 [tp_kept]
    set ::tp_log {}
    set r_again [pcall ase::ui::sod_reseat]
    set focused [lsearch -all -inline -index 0 $::tp_log focus]
    set again [list $r_again [expr {[tp_slots $cv] eq $sodsix ? {its six} : [tp_slots $cv]}] [tp_prevs kL] $focused \
                    [expr {[tp_kept] eq $kept0 ? {as it was} : [tp_kept]}] \
                    [llength [tp_pumps]] [lrange $kept0 2 3] [lindex $kept0 6]]
    pcall ase::ui::sod_end kL
    set ended [list [info exists ase::ui::sod(active)] [expr {[tp_slots $cv] eq $free ? {as before any mode} : [tp_slots $cv]}]]
    # paused, as a descend pauses it
    pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0
    pcall ase::ui::sod_suspend
    set r_paused [list [pcall ase::ui::sod_reseat] [info exists ase::ui::sod(kL,suspended)] \
                       [expr {[tp_slots $cv] eq $free ? {released} : [tp_slots $cv]}]]
    pcall ase::ui::sod_resume $cv
    # at the BOTTOM: the other mode seizes over Select On Design
    set under_rec [tp_prevs kL]
    tpo_seize $cv
    set r_under [list [pcall ase::ui::sod_reseat] [expr {[lrange [tp_slots $cv] 0 0] eq [list [lindex $TPO_OWN 0]] ? {the other mode's press} : [tp_slots $cv]}] \
                      [expr {[tp_prevs kL] eq $under_rec ? {record kept} : [tp_prevs kL]}]]
    tpo_end
    set r_back [list [pcall ase::ui::sod_reseat] [expr {[tp_slots $cv] eq $sodsix ? {its six} : [tp_slots $cv]}]]
    # its canvas gone
    set ::tp_there {}
    set ::tp_log {}
    set r_gone [list [pcall ase::ui::sod_reseat] [llength $::tp_log]]
    set ::tp_there [list $cv .tpd]
    pcall ase::ui::sod_end kL
    check "TPL13 THE MODE TAKES THE CANVAS AGAIN WHEN ANOTHER CLICK MODE WAS ENDED UNDERNEATH IT, AND ONLY THEN (ase::ui::sod_reseat).  With no mode up it does nothing.  Entered over another mode, whose five scripts it has on record, it does nothing while it holds the canvas itself -- also with cmdmode's reader of what the modes hold taken away, where its own script in the press slot is all there is to go by.  The other mode ended FIRST writes the editor's own over this mode's five scripts: the mode is still recorded up with nothing bound but its destroy hook.  It then seizes again: its six scripts are on the canvas, the destroy hook once, what it has on record is what the canvas holds NOW -- nothing for the press, the release, the held motion and ESC, the editor's script for the double click, the canvas's own destroy handler -- the canvas is given the keyboard, and its flavour, its count, the traces it has queued, its prompt, its ONE prompt timer and the marker on a pin it picked are as they were; ending it leaves every slot as before any mode.  Paused, it does nothing and stays paused.  At the BOTTOM, with the other mode seized over it and up, it leaves the canvas and its record alone; that mode ended in order, there is nothing to do.  And with its canvas no longer a widget it answers 0 and reads no binding (the legs in that order; fixture legs inside them: the predecessors on record over the other mode; the stranded state as up, the five slots, the destroy slot; the count and the queue kept are the ones set, and the marker is the one placed)" \
        [list $r_none $over_rec $r_top $r_bare $stranded $again $ended $r_paused $r_under $r_back $r_gone] \
        [list 0 [list [lindex $TPO_OWN 0] break break break [lindex $TPO_OWN 2] {their destroy %W}] \
              {0 {its six}} {0 {record kept}} \
              [list 1 [list {} $TP_EDITOR {} {} {}] "their destroy %W\nase::ui::sod_canvas_gone kL %W"] \
              [list 1 {its six} [list {} $TP_EDITOR {} {} {} {their destroy %W}] [list [list focus $cv]] {as it was} 1 \
                    {{kL,count 3} {kL,queue {v(a) v(b)}}} {{R9 0 16 save}}] \
              {0 {as before any mode}} {0 1 released} {0 {the other mode's press} {record kept}} {0 {its six}} {0 0}]

    # ---- the prompt timer, with the other mode over this one.  The prompt's
    # widget is stood in for by a recorder; one tick is run by hand and the
    # timer it arms is cancelled again.  Answers {the texts it wrote, it armed
    # the next tick, it raised}.
    proc tp_tick_wrote {key} {
        set ::tp_prompts {}
        set r [pcall ase::ui::sod_prompt_pump $key]
        set id {}
        catch {set id $::ase::ui::sod($key,pump)}
        set armed [expr {$id ne {} && [lsearch -exact [after info] $id] >= 0 ? 1 : 0}]
        catch {after cancel $id}
        return [list [lmap p $::tp_prompts { lindex $p 1 }] $armed [string match ERR:* $r]]
    }
    foreach id [after info] { if {[lindex [after info $id] 0 0] eq {ase::ui::sod_prompt_pump}} { after cancel $id } }
    tp_stub ::ase::ui::sod_prompt_set {cv text} { lappend ::tp_prompts [list $cv $text] }
    # the words alone, wherever the pointer of an earlier row was left: which
    # pin the prompt names is band TPM's subject
    tp_stub ::ase::ui::sod_prompt_now {key} { return [::ase::ui::sod_prompt_words $key] }
    array unset ::tp_slot
    set ::tp_slot($cv,<Double-Button-1>) $TP_EDITOR
    pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0
    foreach id [after info] { if {[lindex [after info $id] 0 0] eq {ase::ui::sod_prompt_pump}} { after cancel $id } }
    set words [pcall ase::ui::sod_prompt_base outputs]
    set t_alone [tp_tick_wrote kL]
    tpo_seize $cv
    set t_under [tp_tick_wrote kL]
    set t_bare NOREADER
    if {[llength [info commands ::cmdmode::pristine]]} {
        rename ::cmdmode::pristine ::cmdmode::tp_pristine_kept
        set t_bare [tp_tick_wrote kL]
        rename ::cmdmode::tp_pristine_kept ::cmdmode::pristine
    }
    # the same scripts in the slots with no mode saying it holds them
    set heldnow $::tpo_held
    set ::tpo_held {}
    set t_nobody [tp_tick_wrote kL]
    set ::tpo_held $heldnow
    tpo_end
    set t_back [tp_tick_wrote kL]
    # the press slot emptied by hand, the mode still on record
    set ::tp_slot($cv,<ButtonPress-1>) {}
    set t_empty [tp_tick_wrote kL]
    set ::tp_slot($cv,<ButtonPress-1>) $pick
    set ::tp_there {}
    set t_gone [tp_tick_wrote kL]
    set ::tp_there [list $cv .tpd]
    tp_unstub ::ase::ui::sod_prompt_now
    tp_unstub ::ase::ui::sod_prompt_set
    pcall ase::ui::sod_end kL
    pcall cmdmode::unregister tpo_mode
    check "TPL14 THE PROMPT TIMER WRITES NOTHING WHILE ANOTHER CLICK MODE SITS ON TOP OF THIS ONE, AND GOES ON TICKING: alone on its canvas a tick writes the mode's words and arms the next; with another mode that is up seized over it the tick writes nothing, still arms the next and raises nothing; that mode ended, the next tick writes the words again.  Everything else is as it was before there was such a test, and the tick writes: cmdmode's reader of what the modes hold taken away, the same scripts in the slots with no mode saying it holds them, a press slot emptied by hand, and a canvas that is no widget (per state: the texts written, the next tick armed, raised -- in the order alone, under the other mode, no reader, nobody's scripts, the other mode ended, the slot emptied, no widget; then: the other mode is gone from cmdmode)" \
        [list $t_alone $t_under $t_bare $t_nobody $t_back $t_empty $t_gone \
              [expr {[lsearch -exact [pcall cmdmode::registered] tpo_mode] >= 0 ? {STILL THERE} : {gone}}]] \
        [list [list [list $words] 1 0] {{} 1 0} [list [list $words] 1 0] [list [list $words] 1 0] [list [list $words] 1 0] \
              [list [list $words] 1 0] [list [list $words] 1 0] gone]
    foreach p {tpo_held tpo_zero tpo_seize tpo_end tp_prevs tp_pumps tp_kept tp_tick_wrote} { catch {rename $p {}} }
    if {[llength [info commands ::cmdmode::tp_pristine_kept]]} { catch {rename ::cmdmode::tp_pristine_kept ::cmdmode::pristine} }
    proc ::ase::ui::focus {args} { return {} }
    tp_life_drop kL

    # ---- a paused mode's release writes nothing.  A descend pauses every
    # click mode, the top of a stack first, and each hands back what the canvas
    # held when it took it.  A mode that is ended while it is paused must not
    # hand that back a second time: for a mode that was entered over another
    # one it is that mode's scripts, and that mode is paused as well.
    #
    # Each of the three modes is entered over five scripts that stand for
    # another mode's, by its own entry or seize, and paused by its own suspend
    # arm.  The pause of the mode underneath is stood in for by writing the
    # canvas as it is with no mode up.  The canvases are this band's table;
    # inside the namespaces of the Calculator and of the Results window `bind`
    # and `focus` are stood in for as well, for the length of the row.
    #
    # the six slots of canvas `w` written by hand, in the order of TP_SLOTS
    proc tp_seed {w scripts} {
        foreach s $::TP_SLOTS o $scripts { set ::tp_slot($w,$s) $o }
    }
    # the binding calls logged since the log was emptied that wrote a slot
    proc tp_writes {} { return [llength [lsearch -all -inline -index 0 $::tp_log write]] }
    # the prompt timers that are waiting
    proc tp_pump_count {} {
        set n 0
        foreach id [after info] { if {[lindex [after info $id] 0 0] eq {ase::ui::sod_prompt_pump}} { incr n } }
        return $n
    }
    set others [list {tpo::click; break} break break break {tpo::end; break} {}]
    set nomode [list {} $TP_EDITOR {} {} {} {}]
    # no prompt timer of an earlier row is waiting when the count below is taken
    foreach id [after info] { if {[lindex [after info $id] 0 0] eq {ase::ui::sod_prompt_pump}} { after cancel $id } }
    tp_stub ::ase::ui::sod_prompt_clear {cv} { lappend ::tp_cleared $cv }
    set ::tp_cleared {}
    array unset ::tp_slot
    tp_seed $cv $others
    pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0
    set ase::ui::sod(kL,count) 2
    pcall xschem pin_marker clear -fast
    pcall xschem pin_marker add -fast -tag save R9 P
    set s_sus [list [pcall ase::ui::sod_suspend] [expr {[tp_slots $cv] eq $others ? {the five handed back} : [tp_slots $cv]}]]
    tp_seed $cv $nomode
    set ::tp_log {} ; set ::tp_cleared {}
    set s_rel [list [pcall ase::ui::sod_release kL] [tp_writes] $::tp_cleared]
    set s_again [list [pcall ase::ui::sod_suspend] [tp_writes] $::tp_cleared]
    set ::notices {} ; set ::ntags {}
    pcall ase::ui::sod_end kL
    set s_end [list [info exists ase::ui::sod(active)] [array names ase::ui::sod kL,*] $::notices \
                    [lmap r [pcall xschem pin_marker list] { lrange $r 1 4 }] [tp_pump_count] [tp_writes] $::tp_cleared \
                    [expr {[tp_slots $cv] eq $nomode ? {as with no mode up} : [tp_slots $cv]}] [pcall ase::ui::sod_resume $cv]]
    tp_life_drop kL
    # the Calculator's pick and the Results window's pick mode, on the second canvas
    set s_two {}
    foreach {ns seize suspend release end resume running} {
        calc calc::_pick_seize calc::pick_suspend calc::pick_release {calc::pick_end cancel} calc::pick_resume calc::pick_running
        rdw  rdw::_pick_seize  rdw::pick_suspend  rdw::pick_release  rdw::pick_end           rdw::pick_resume  rdw::pick_running
    } {
        namespace eval ::$ns {}
        proc ::${ns}::bind [info args ::ase::ui::bind] [info body ::ase::ui::bind]
        proc ::${ns}::focus {args} { return {} }
        set kept [array get ::${ns}::pick]
        array unset ::${ns}::pick
        array unset ::tp_slot
        tp_seed .tpd $others
        pcall $seize .tpd
        set sus1 [list [pcall $suspend] [expr {[tp_slots .tpd] eq $others ? {the five handed back} : [tp_slots .tpd]}]]
        set sus2 [pcall $suspend]
        tp_seed .tpd $nomode
        set ::tp_log {} ; set ::tp_cleared {}
        set rel [list [pcall $release] [tp_writes] $::tp_cleared]
        set ended [pcall {*}$end]
        lappend s_two [list $sus1 $sus2 $rel $ended [pcall $running] [array names ::${ns}::pick] [tp_writes] $::tp_cleared \
                            [expr {[tp_slots .tpd] eq $nomode ? {as with no mode up} : [tp_slots .tpd]}] [pcall $resume .tpd]]
        array unset ::${ns}::pick
        array set ::${ns}::pick $kept
        catch {rename ::${ns}::bind {}}
        catch {rename ::${ns}::focus {}}
    }
    catch {after cancel calc::pick_refocus}
    tp_unstub ::ase::ui::sod_prompt_clear
    pcall xschem pin_marker clear -fast
    check "TPL15 A PAUSED MODE'S RELEASE WRITES NOTHING, for each of the three click modes.  Select On Design is entered over five scripts that stand for another mode's and is paused by its suspend arm, which hands those five back; the canvas is then written as it is with no mode up, as the pause of the mode underneath leaves it.  The release asked of the paused mode answers 1, writes no binding and does not clear the prompt slot; the suspend arm asked a second time answers 0 and writes nothing either; and the mode ended while paused is gone as any ended mode is -- none on record, no record of the session left, one sentence with the count it had queued, its pin marker taken off, no prompt timer waiting -- with no binding written, the prompt slot not cleared and the canvas still as it is with no mode up; its resume arm then answers 0.  The Calculator's pick and the Results window's pick mode, each seized by its own seize over the same five scripts on a second canvas and paused by its own suspend arm, do the same: the first pause answers 1 and hands the five back, a second answers 0, the release answers 1 and writes nothing, the end answers 1, no pick or mode is on record after it and nothing was written, the canvas is as it is with no mode up, and the resume arm answers 0.  The canvases are this band's table of bindings; inside the namespaces of those two modes `bind` and `focus` are stood in for the length of the row (Select On Design: the pause; the release as answer, bindings written, prompt slots cleared; the second pause as answer, bindings written, prompt slots cleared; the end as mode on record, records left, said, markers, timers, bindings written, prompt slots cleared, the canvas, the resume -- then per mode: the first pause, the second, the release, the end, running, records left, bindings written, prompt slots cleared, the canvas, the resume)" \
        [list $s_sus $s_rel $s_again $s_end $s_two] \
        [list {1 {the five handed back}} {1 0 {}} {0 0 {}} \
              [list 0 {} [list "ase: Select On Design ended — 2 output(s) queued"] {} 0 0 {} {as with no mode up} 0] \
              [lrepeat 2 [list {1 {the five handed back}} 0 {1 0 {}} 1 0 {} 0 {} {as with no mode up} 0]]]
    foreach p {tp_seed tp_writes tp_pump_count} { catch {rename $p {}} }

    # ---- the press script hands the engine its own position
    array unset ::tp_slot
    tp_set_radius 6
    pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0
    set script [expr {[info exists ::tp_slot($cv,<ButtonPress-1>)] ? $::tp_slot($cv,<ButtonPress-1>) : {NOT BOUND}}]
    lassign [tp_pin R9 P] rx ry
    set pz [xschem get zoom]
    set ppx [expr {int(round(($rx + [xschem get xorigin]) / $pz))}]
    set ppy [expr {int(round(($ry + [xschem get yorigin]) / $pz))}]
    set d_on [tp_point $rx $ry]
    # the engine is sent a <Configure> of the canvas, as Tk sends it: the
    # canvas's place in its parent where a pointer event has the pointer
    pcall xschem callback .drw 22 0 47 0 900 700 0
    set d_off [tp_dist [pcall xschem get mousex] [pcall xschem get mousey] $rx $ry]
    set ::queued {} ; set ::notices {}
    pcall ase::ui::sod_click kL
    set q_bare $::queued
    set ::queued {} ; set ::notices {}
    set code [catch {uplevel #0 [string map [list %W .drw %x $ppx %y $ppy %s 0] $script]}]
    set q_script $::queued
    set d_back [tp_dist [pcall xschem get mousex] [pcall xschem get mousey] $rx $ry]
    pcall xschem pin_marker clear -fast
    tp_life_drop kL
    check "TPL10 THE PRESS SCRIPT HANDS THE ENGINE ITS OWN POSITION BEFORE THE CLICK: with the pointer moved onto R9's pin and the engine then sent a <Configure> of the canvas -- which leaves the pointer it holds far from the pin -- a click that reads that pointer, as the bare call does, queues nothing; the script the mode bound on the press, run as Tk runs it for a press at the pin's pixel, queues the pin's current, ends in `break`, and leaves the engine's pointer on the pin (the pointer on the pin to half a unit; then farther than 50 units; the bare click's queue; the script's queue; its completion code, 3 being `break`; the pointer back on the pin)" \
        [list [tp_less $d_on 0.5] [tp_less 50 $d_off] $q_bare $q_script $code [tp_less $d_back 0.5]] \
        [list 1 1 {} i(r9:n1) 3 1]

    # ---- the canvas of a design in a tab that is not the first
    # Inside namespace ase::ui, and nowhere else, two questions the lifecycle
    # puts to the engine are answered from a table: the name of the current
    # context and the list of windows.  Every other word goes to the engine.
    set ::tp_ctx {} ; set ::tp_wins {}
    proc ::ase::ui::xschem {args} {
        if {$args eq {get current_win_path} && $::tp_ctx ne {}} { return $::tp_ctx }
        if {$args eq {windows} && [llength $::tp_wins]} { return $::tp_wins }
        return [uplevel 1 [linsert $args 0 ::xschem]]
    }
    array unset ::tp_slot
    set ::tp_there [list $cv .tpd .tpw.drw]
    set ::tp_wins [list [list $cv . . 1 a.sch 0 a.sch] [list .x1.drw . . 1 b.sch 0 b.sch] \
                        [list .x2.drw .tpw .tpw 2 c.sch 0 c.sch] [list .x3.drw .tpgone .tpgone 3 d.sch 0 d.sch]]
    set ::tp_ctx .x1.drw
    set looked [list [pcall ase::ui::sod_canvas $cv] [pcall ase::ui::sod_canvas .x1.drw] [pcall ase::ui::sod_canvas .x2.drw] \
                     [pcall ase::ui::sod_canvas .x3.drw] [pcall ase::ui::sod_canvas .x9.drw] [pcall ase::ui::sod_canvas]]
    check "TPL11 THE CANVAS OF A WINDOW CONTEXT: a name that is a widget is itself; the name of a tab of the main window, which is no widget, is the main window's canvas; a context whose window is another toplevel is that toplevel's canvas; one whose toplevel has no canvas, and one the window list does not hold, have none; and with no name given the current context is the one asked about (a widget; a tab; another toplevel; a toplevel with no canvas; not listed; the current context, a tab)" \
        $looked [list $cv .drw .tpw.drw {} {} .drw]
    set ::notices {} ; set ::ntags {}
    set rc_tab [pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0]
    set on_tab [list [pcall set ase::ui::sod(kL,canvas)] [lindex [tp_slots .drw] 0] [array names ::tp_slot .x1.drw,*]]
    pcall ase::ui::sod_suspend
    set ::tp_ctx .x2.drw
    set res_win [pcall ase::ui::sod_resume .x2.drw]
    set on_win [list [pcall set ase::ui::sod(kL,canvas)] [lindex [tp_slots .drw] 0] [lindex [tp_slots .tpw.drw] 0] [array names ::tp_slot .x2.drw,*]]
    tp_life_drop kL
    set ::tp_ctx .x3.drw
    set ::notices {} ; set ::ntags {}
    set rc_none [pcall ase::ui::select_on_design kL {save 1 plot 0} outputs 0]
    set said_none [list $::notices $::ntags [info exists ase::ui::sod(active)]]
    rename ::ase::ui::xschem {}
    set ::tp_there [list $cv .tpd]
    check "TPL12 THE MODE IS ENTERED WITH THE DESIGN IN A TAB THAT IS NOT THE FIRST, and comes back up in one: with the current context a tab of the main window the mode arms on the main window's canvas and binds nothing under the context's own name; paused and resumed with the current context a window of its own, it comes up on that window's canvas and the main window's press slot is free again; and where the current context has no canvas the entry answers 0, says so as an error naming the context, and no mode is up (armed; the mode's canvas, its press slot, bindings under the tab's name; resumed; the mode's canvas, the main press slot, the window's, bindings under the context's name; the refused entry; what it said)" \
        [list $rc_tab $on_tab $res_win $on_win $rc_none $said_none] \
        [list 1 [list .drw $pick {}] 1 [list .tpw.drw {} $pick {}] 0 \
              [list [list {ase: no design canvas to select on (.x3.drw)}] error 0]]
    tp_life_drop kL
    tp_life_off
    tp_mode k outputs
    tp_home
}
tp_life_off

} err]} {
    puts "FAIL: suite ABORTED -> $err : FAIL"
    puts $::errorInfo
    incr fail
}

# ===========================================================================
# TPZ — the message boxes of the whole run
# ===========================================================================
# Outside the `catch` above, so it is said whatever became of the bands.
set tp_other_boxes {}
set tp_bi 0
foreach b $::tp_boxes {
    if {$tp_bi < [lindex $::tp_box_tpu6 0] || $tp_bi >= [lindex $::tp_box_tpu6 1]} { lappend tp_other_boxes [tp_box_text $b] }
    incr tp_bi
}
check "TPZ1 NO OTHER MESSAGE BOX WAS ASKED FOR IN THE WHOLE RUN: beside what row TPU6 accounts for, nothing in this suite made the engine or the product ask Tk for a modal box -- one that nobody answers would stop the run on a display (the texts of the boxes asked for elsewhere)" \
    $tp_other_boxes {}

# leave nothing behind that a later reader of this process could trip on
catch {rename ::tk_messageBox {}}
if {[llength [info commands ::tp_real_tk_messageBox]]} { catch {rename ::tp_real_tk_messageBox ::tk_messageBox} }
catch {tp_switches_reset}
catch {xschem pin_marker clear -all -fast}
catch {ase::facts_clear}
catch {ase::session_close $TOPKEY}
catch {ase::session_close $BUSKEY}
catch {ase::session_close $REVKEY}
catch {ase::session_close $PFXKEY}
catch {ase::session_close $GEOKEY}
if {[info commands real_ciw_echo] ne {}} { catch {rename ciw_echo {}} ; catch {rename real_ciw_echo ciw_echo} }

if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
