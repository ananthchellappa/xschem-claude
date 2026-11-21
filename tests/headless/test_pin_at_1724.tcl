# test_pin_at_1724.tcl — the read-only pin probe `xschem pin_at`, and the lookup
# ladder's colon rung.  Issue 1724.
#
# Issue  doc/claude/issues/1724-select-on-design-cannot-queue-a-device-terminal-current-a-click-on-an-instance-pin-queues-the-voltage-of-the-pins-net.md
# Spec   doc/claude/specs/pin_selection.md (the pin pick radius);
#        doc/claude/specs/raw_case_mode.md section 9 (the lookup ladder)
#
# TWO THINGS ARE FENCED HERE, and they share a file because one feature needs
# both: a click on an instance pin must first FIND the pin, and the current it
# then names must RESOLVE in the results.
#
#   PA*  `xschem pin_at <x> <y> [-all]` (scheduler.c) over find_closest_pin() and
#        find_pins_at() (findnet.c).  The two C functions share one walk,
#        pins_in_pick_radius(), so the probe answers by the pin-select click's
#        own rule: the same radius, the same lock and pin-layer behaviour, the
#        same tie-break.  The plain form is the nearest pin; `-all` is every pin
#        in range, nearest first.  IN RANGE is within the radius, or inside the
#        pin's own drawn rectangle (point_in_inst_pin_rect()): the radius is a
#        distance on the screen, so zoomed far in it is smaller than the
#        rectangle.  Band PA9.
#   LR*  rung 5 of get_raw_index_in() (save.c) and its mirror in
#        wviewer::name_rungs (wave_viewer.tcl).  read_dataset() stores every `:`
#        of a variable name as `.`, and ngspice writes a `.probe` terminal
#        current as `i(x1.xm1:d)`; the rung makes the file's spelling resolve to
#        the stored one.  The committed results it is measured on are
#        tests/headless/data/probe_1724_{op,tran}.raw (README.md there).
#
# THE RADIUS IS NEVER A LITERAL.  It is 12 * zoom * tk-scaling schematic units,
# and both factors differ between the two arms: C's cached scaling is 1.0 under
# --nogui and `tk scaling` with a display, and the zoom a sheet opens at follows
# the window.  pa_radius reads it at the moment of use; where a row needs a
# particular radius it SETS the zoom (pa_set_radius) and reads the radius back.
#
# Runs on both arms; nothing here needs a display.  From the repo ROOT:
#   tests/headless/run_suites.sh --nogui test_pin_at_1724
#   AUDIT_DISPLAY=private tests/headless/run_suites.sh test_pin_at_1724

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

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set scratch [test_scratch pin_at_1724]

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
proc wfile {path body} { set f [open $path w]; puts $f $body; close $f }

# find_closest_pin()'s radius in schematic units, read NOW
proc pa_scale {} { return [expr {[info commands tk] ne {} ? [tk scaling] : 1.0}] }
proc pa_radius {} {
    return [expr {12*[xschem get zoom]*([info commands tk] ne {} ? [tk scaling] : 1.0)}]
}
# set the zoom so the radius is (to rounding) r; answers the radius read back
proc pa_set_radius {r} {
    xschem origin - - [expr {$r / (12.0 * [pa_scale])}]
    return [pa_radius]
}
proc pa_near {a b} { return [expr {abs($a - $b) <= 1e-9 * abs($b)}] }
proc pa_dist {x1 y1 x2 y2} { return [expr {sqrt(($x1-$x2)*($x1-$x2) + ($y1-$y2)*($y1-$y2))}] }
# NO ANSWER OF pin_at IS MEASURED BARE: a broken build can hand back an empty
# string, an error text or a row of the wrong length, and arithmetic on that
# would abort the band and take its remaining rows out of the verdict.
# Is `row` a six-element pin row with numeric coordinates?
proc pa_isrow {row} {
    return [expr {[llength $row] == 6 && [string is double -strict [lindex $row 4]]
                  && [string is double -strict [lindex $row 5]] ? 1 : 0}]
}
# the distance from (x,y) to the point a pin row reports, or NOROW
proc pa_dist_row {x y row} {
    if {![pa_isrow $row]} { return NOROW }
    return [pa_dist $x $y [lindex $row 4] [lindex $row 5]]
}
# `a < b` for two numbers, 0 when either is not one
proc pa_less {a b} {
    return [expr {[string is double -strict $a] && [string is double -strict $b] && $a < $b ? 1 : 0}]
}

# EVERY pin of the sheet, from doors that are not pin_at: one row per pin,
#   <inst> <pin> <instname> <pinname> <x> <y> <locked>
# The coordinate comes back through `%g` (instance_pin_coord), so it is exact for
# the integer pins and rounded for a fractional one.
proc pa_pin_table {} {
    set out {}
    set n [xschem get instances]
    for {set i 0} {$i < $n} {incr i} {
        set iname [xschem getprop instance $i name]
        set locked [expr {[xschem getprop instance $i lock] eq {true} ? 1 : 0}]
        set p 0
        foreach pn [xschem instance_pins $i] {
            set c [xschem instance_pin_coord $i name $pn]
            lappend out [list $i $p $iname $pn [lindex $c 1] [lindex $c 2] $locked]
            incr p
        }
    }
    return $out
}
# the six-element row pin_at answers for (instance name, pin name), from the table
proc pa_row {table iname pname} {
    foreach r $table {
        if {[lindex $r 2] eq $iname && [lindex $r 3] eq $pname} { return [lrange $r 0 5] }
    }
    return "NOROW:$iname/$pname"
}
# the `-all` answer the rule predicts at (x,y) for radius r, built from a pin
# list: the pins within r, nearest first, then instance index, then pin index.
# Also counts the pairs too close to the radius to call (see PA4c).
proc pa_expect {pins x y r} {
    set r2 [expr {$r * $r}]
    set keyed {}
    foreach p $pins {
        set px [lindex $p 4]; set py [lindex $p 5]
        set d2 [expr {($x-$px)*($x-$px) + ($y-$py)*($y-$py)}]
        if {abs($d2 - $r2) <= 1e-9 * $r2} { incr ::pa_ambiguous }
        if {$d2 <= $r2} { lappend keyed [linsert $p end $d2] }
    }
    set keyed [lsort -integer -index 1 $keyed]
    set keyed [lsort -integer -index 0 $keyed]
    set keyed [lsort -real -index 6 $keyed]
    set out {}
    foreach k $keyed { lappend out [lrange $k 0 5] }
    return $out
}
# the same prediction when a pin's own rectangle counts too.  `pins` rows are
#   <inst> <pin> <instname> <pinname> <px> <py> <hx> <hy>
# (hx, hy: half the rectangle's width and height on the sheet).  A pin is in
# range when the point is within r of it OR inside its rectangle, edges
# included; the order is still by the distance to the pin's point.  Counts in
# ::pa_rect_only the pins reached by the rectangle alone, in ::pa_disc_only
# those reached by the radius alone, and names the former in ::pa_rect_pins.
proc pa_expect_rect {pins x y r} {
    set r2 [expr {$r * $r}]
    set keyed {}
    foreach p $pins {
        lassign $p i j iname pname px py hx hy
        set d2 [expr {($x-$px)*($x-$px) + ($y-$py)*($y-$py)}]
        if {abs($d2 - $r2) <= 1e-9 * $r2} { incr ::pa_ambiguous }
        set indisc [expr {$d2 <= $r2}]
        set inrect [expr {abs($x - $px) <= $hx && abs($y - $py) <= $hy}]
        if {$inrect && !$indisc} { incr ::pa_rect_only ; dict set ::pa_rect_pins "$iname/$pname" 1 }
        if {$indisc && !$inrect} { incr ::pa_disc_only }
        if {$indisc || $inrect} { lappend keyed [list $i $j $iname $pname $px $py $d2] }
    }
    set keyed [lsort -integer -index 1 $keyed]
    set keyed [lsort -integer -index 0 $keyed]
    set keyed [lsort -real -index 6 $keyed]
    set out {}
    foreach k $keyed { lappend out [lrange $k 0 5] }
    return $out
}
# the point (px + dx, py + dy) of a pin row, as {x y}
proc pa_off {row dx dy} { return [list [expr {[lindex $row 4] + $dx}] [expr {[lindex $row 5] + $dy}]] }
# both forms at one point: {plain all}
proc pa_both {xy} { return [list [pcall xschem pin_at {*}$xy] [pcall xschem pin_at {*}$xy -all]] }

# the body of a C function or of one dispatcher branch, comments stripped, so a
# text row reads code and never the prose above it
proc pa_ccode {path} {
    set f [open $path r]; set s [read $f]; close $f
    regsub -all {/\*.*?\*/} $s {} s
    return $s
}
proc pa_cbody {code head} {
    set i [string first $head $code]
    if {$i < 0} { return "NOHEAD:$head" }
    set i [string first "\{" $code $i]
    set depth 0
    for {set j $i} {$j < [string length $code]} {incr j} {
        set c [string index $code $j]
        if {$c eq "\{"} { incr depth } elseif {$c eq "\}"} {
            incr depth -1
            if {$depth == 0} { return [string range $code $i $j] }
        }
    }
    return "UNBALANCED:$head"
}
proc pa_has {body words} {
    set out {}
    foreach w $words { lappend out [expr {[string first $w $body] >= 0 ? 1 : 0}] }
    return $out
}

# the variable names a raw file's own header lists, in file order (the names
# BEFORE read_dataset() rewrites them)
proc lr_file_names {path} {
    set f [open $path r]; fconfigure $f -translation binary
    set out {}; set invars 0
    while {[gets $f line] >= 0} {
        if {[string match Variables:* $line]} { set invars 1; continue }
        if {[string match Binary:* $line] || [string match Values:* $line]} break
        if {$invars} { lappend out [lindex [split [string trim $line] "\t"] 1] }
    }
    close $f
    return $out
}
proc lr_dotted {name} { return [string map {: .} $name] }
# the engine's verdict and the Tcl mirror's on ONE token, as 0/1
proc lr_engine {tok} {
    set e [pcall xschem raw index $tok]
    return [expr {[string is integer -strict $e] && $e >= 0 ? 1 : 0}]
}
proc lr_mirror {stored tok} {
    set v [pcall wviewer::name_lookup [pcall wviewer::name_index $stored] $tok [pcall wviewer::db_fuzzy]]
    return [expr {$v eq {ok} ? 1 : 0}]
}
# the candidate list name_rungs gave a token before rung 5: rungs 1 to 4 only
proc lr_rungs_1_4 {tok} {
    set out [list $tok "v($tok)"]
    if {[string match -nocase {i(v.x*} $tok]} { lappend out "i([string range $tok 4 end]" }
    return $out
}

# ===========================================================================
# the fixture: one sheet and one symbol, written as text into scratch
# ===========================================================================
# Instance ORDER is part of the fixture -- the tie rows read it:
#   0 l0        a net label whose pin sits on R1.M / R2.P   (label BELOW the devices' indexes)
#   1 R1        P (0,-30)   M (0,30)
#   2 R2        P (0,30)    M (0,90)       R2.P abuts R1.M
#   3 l3        a net label whose pin sits on R1.P          (label ABOVE the device's index)
#   4 R3        lock=true
#   5 x17[1:0]  a bus instance of pa_blk.sym: pins `A[3:0]`, `Y`, `odd name`
#   6 R9        alone, unlocked: the control for R3 and the radius rows' pin
#   7 R8        at a fractional x, for the coordinate format
wfile [file join $scratch pa_blk.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
F {}
E {}
L 4 -40 -20 40 -20 {}
L 4 -40 20 40 20 {}
L 4 -40 -20 -40 20 {}
L 4 40 -20 40 20 {}
B 5 -42.5 -2.5 -37.5 2.5 {name=A[3:0] dir=in}
B 5 37.5 -2.5 42.5 2.5 {name=Y dir=out}
B 5 -2.5 17.5 2.5 22.5 {name="odd name" dir=inout}}
set pa_sch [file join $scratch pa_fix.sch]
wfile $pa_sch "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {lab_pin.sym} 0 30 0 0 {name=l0 sig_type=std_logic lab=mid}
C {res.sym} 0 0 0 0 {name=R1 value=1k}
C {res.sym} 0 60 0 0 {name=R2 value=1k}
C {lab_pin.sym} 0 -30 0 0 {name=l3 sig_type=std_logic lab=top}
C {res.sym} 200 0 0 0 {name=R3 value=1k lock=true}
C {[file join $scratch pa_blk.sym]} 400 0 0 0 {name=x17\[1:0\]}
C {res.sym} 600 0 0 0 {name=R9 value=1k}
C {res.sym} 800.123456789 0 0 0 {name=R8 value=1k}"

# The PA8 fixture: a symbol whose SECOND pin rectangle is not a number, beside one
# good pin, and a sheet holding one instance of it at (300,0) with a resistor far
# away as the control.  The body lines keep the instance's box finite: IN is at
# (260,0) and the box reaches x=340, so (300,10) is inside the box and 41 units
# from the only real pin.
wfile [file join $scratch pa_nan.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
F {}
E {}
L 4 -40 -30 40 -30 {}
L 4 -40 30 40 30 {}
L 4 -40 -30 -40 30 {}
L 4 40 -30 40 30 {}
B 5 -42.5 -2.5 -37.5 2.5 {name=IN dir=in}
B 5 nan nan nan nan {name=OUT dir=out}}
set pa_nan_sch [file join $scratch pa_nan.sch]
wfile $pa_nan_sch "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {[file join $scratch pa_nan.sym]} 300 0 0 0 {name=xn}
C {res.sym} 0 300 0 0 {name=R1 value=1k}"

# The PA9 fixture.  pa_wide.sym has ONE pin, W, whose rectangle is 12 units wide
# and 2 tall round the point (-40,0): a quarter turn makes it 2 wide and 12
# tall, so a rotated instance is told from an unrotated one by WHICH points the
# rectangle holds.  A flip moves the pin and leaves the rectangle's shape.  The
# sheet is DATA -- name, symbol, x, y, rot, flip, lock -- and both the .sch
# text and the rows' expectations are built from it:
#   R1        res.sym, unrotated: two square pins, 5 units a side
#   xw0, xo   pa_wide unrotated, 8 units apart: their two rectangles OVERLAP
#   xw1..xw3  pa_wide at one, two and three quarter turns
#   xf0..xf3  pa_wide flipped, at none to three quarter turns
#   RL        res.sym with lock=true
set PA9_INST {
    {R1  res  0    0   0 0 0}
    {xw0 wide 300  0   0 0 0}
    {xo  wide 308  0   0 0 0}
    {xw1 wide 600  0   1 0 0}
    {xw2 wide 900  0   2 0 0}
    {xw3 wide 1200 0   3 0 0}
    {xf0 wide 300  300 0 1 0}
    {xf1 wide 600  300 1 1 0}
    {xf2 wide 900  300 2 1 0}
    {xf3 wide 1200 300 3 1 0}
    {RL  res  0    300 0 0 1}
}
# half the width and height of each symbol's pin rectangles, unrotated
set PA9_HALF {res {2.5 2.5} wide {6.0 1.0}}
wfile [file join $scratch pa_wide.sym] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
F {}
E {}
L 4 -30 -20 30 -20 {}
L 4 -30 20 30 20 {}
L 4 -30 -20 -30 20 {}
L 4 30 -20 30 20 {}
B 5 -46 -1 -34 1 {name=W dir=in}}
set pa_rect_sch [file join $scratch pa_rect.sch]
set pa9_body "v {xschem version=3.4.8RC file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nF {}\nE {}"
foreach row $PA9_INST {
    lassign $row name sym x y rot flip lock
    if {$sym eq {res}} {
        append pa9_body "\nC {res.sym} $x $y $rot $flip {name=$name value=1k[expr {$lock ? { lock=true} : {}}]}"
    } else {
        append pa9_body "\nC {[file join $scratch pa_wide.sym]} $x $y $rot $flip {name=$name}"
    }
}
wfile $pa_rect_sch $pa9_body

if {[catch {

# ===========================================================================
# PA0 — the binary and the fixture
# ===========================================================================
check "PA0a this binary has the subcommand: `xschem pin_at 0 0` does not raise (a stale build answers `invalid command` here and every row below would be about it)" \
    [catch {xschem pin_at 0 0}] 0
check "PA0b fixture: the sheet loads and reads back its eight instances in file order, so a `.sch` format change reddens a row that names the fixture" \
    [list [expr {[pcall xschem load $pa_sch] ne {} ? 1 : 0}] [pcall xschem get instances] \
          [lmap i {0 1 2 3 4 5 6 7} { pcall xschem getprop instance $i name }]] \
    [list 1 8 {l0 R1 R2 l3 R3 {x17[1:0]} R9 R8}]

set pa_zoom_open [pcall xschem get zoom]

# cold-sheet legs of PA6, taken HERE: every row after this one uses
# `xschem instance_pins`, which prepares the netlist structures itself
set pa_prep_cold [regexp -all -inline -line {^prep_(?:net|hi)_structs=.*$} [pcall xschem globals]]
foreach {x y} {0 30 600 -30 0 -30 12345 12345} { pcall xschem pin_at $x $y; pcall xschem pin_at $x $y -all }
set pa_prep_after [regexp -all -inline -line {^prep_(?:net|hi)_structs=.*$} [pcall xschem globals]]

set TABLE [pcall pa_pin_table]
set pa_prep_control [regexp -all -inline -line {^prep_(?:net|hi)_structs=.*$} [pcall xschem globals]]
set pa_locked {}
foreach r $TABLE { if {[lindex $r 6] == 1 && [lsearch -exact $pa_locked [lindex $r 2]] < 0} { lappend pa_locked [lindex $r 2] } }
check "PA0c fixture: the pin table read through instance_pins / instance_pin_coord has one row per pin, and R3 is the only locked instance" \
    [list [llength $TABLE] $pa_locked] {15 R3}

# ===========================================================================
# PA1 — the answer's shape
# ===========================================================================
group PA1 {
    # a radius small enough that each probe point of this band has ONE pin in
    # range, so the rows are about the answer's shape alone
    pa_set_radius 10
    set r9p [pa_row $TABLE R9 P]
    check "PA1a a hit answers ONE flat row <inst> <pin> <instname> <pinname> <px> <py>, equal to the row built from instance_pins / instance_pin_coord for R9's P pin" \
        [list [pcall xschem pin_at 600 -30] [llength [pcall xschem pin_at 600 -30]]] [list $r9p 6]
    check "PA1b -all at the same point answers a LIST holding that one row" \
        [pcall xschem pin_at 600 -30 -all] [list $r9p]
    check "PA1c a miss is the empty string and not an error, in both forms (catch code, then the answer)" \
        [list [catch {xschem pin_at 12345 12345} a] $a [catch {xschem pin_at 12345 12345 -all} b] $b] \
        {0 {} 0 {}}
    set usage {usage: xschem pin_at x y [-all]}
    check "PA1d too few words, an unknown fifth word, a sixth word and `-all` anywhere but last are refused with the usage line (catch code and message per spelling)" \
        [list [catch {xschem pin_at} m] $m [catch {xschem pin_at 600} m] $m \
              [catch {xschem pin_at 600 -30 -al} m] $m [catch {xschem pin_at 600 -30 -all x} m] $m \
              [catch {xschem pin_at -all 600 -30} m] $m] \
        [list 1 $usage 1 $usage 1 $usage 1 $usage 1 $usage]
    # PA1d2 -- a coordinate must be a number and nothing else.  Each spelling
    # below used to be read as 0 (or as its numeric prefix) and answer a pin:
    # the plain form with `-all` or the typo `-al` in the y slot (a forgotten
    # y), two words that are not numbers, an empty word, and a number with a
    # tail.  R9's M pin sits at (600,30) and its P pin at (600,-30), so with a
    # radius of 10 the old reading of `600 -all` -- the point (600,0) -- is a
    # miss and `600x -30` would have been a hit; both must be the usage line.
    set bad {}
    foreach words {{600 -all} {600 -al} {foo bar} {600 bar} {foo -30} {{} -30} {600 {}}
                   {600x -30} {600 -30x} {600 -30x -all} {6e -30} {600 - -all}} {
        lappend bad [list [catch {xschem pin_at {*}$words} m] $m]
    }
    check "PA1d2 a coordinate that is not a number, whole word, is refused with the usage line: `-all` or `-al` where y belongs, a word, an empty word, a number with a tail, in the plain and the -all form (catch code and message of the twelve spellings, as the set of distinct answers; then how many were tried)" \
        [list [lsort -unique $bad] [llength $bad]] [list [list [list 1 $usage]] 12]
    check "PA1d3 CONTROL for PA1d2: the same pin answers for every spelling Tcl itself takes as that number -- a decimal point, an exponent, a leading plus -- so the refusal is about non-numbers and not about a format" \
        [list [pcall xschem pin_at 600.0 -30.0] [pcall xschem pin_at 6e2 -3e1] [pcall xschem pin_at +600 -30] \
              [pcall xschem pin_at 6e2 -3e1 -all]] \
        [list $r9p $r9p $r9p [list $r9p]]
    set bus [pcall xschem pin_at 360 0]
    check "PA1e a bus instance and a bus pin stay ONE list element each: the row has six elements and elements 2 and 3 are the names verbatim" \
        [list [llength $bus] [lindex $bus 2] [lindex $bus 3] [pcall xschem pin_at 360 0 -all]] \
        [list 6 {x17[1:0]} {A[3:0]} [list [pa_row $TABLE {x17[1:0]} {A[3:0]}]]]
    set odd [pcall xschem pin_at 400 20]
    check "PA1f a pin name holding a SPACE is one element too (a bracket alone cannot show quoting: Tcl's list parser does not split on it), plain and -all" \
        [list [llength $odd] [lindex $odd 3] [llength [lindex [pcall xschem pin_at 400 20 -all] 0]]] \
        {6 {odd name} 6}
    set r8 [pcall xschem pin_at 800.123456789 -30]
    check "PA1g coordinates keep every digit: R8 sits at x=800.123456789 and the row's px is that string (instance_pin_coord's own answer for the same pin is rounded, shown beside it)" \
        [list [lindex $r8 4] [lindex $r8 5] [lindex [pa_row $TABLE R8 P] 4]] {800.123456789 -30 800.123}
}

# ===========================================================================
# PA2 — the radius, read at run time
# ===========================================================================
# R9's P pin is the probe: the points sit straight above it, so it is the
# nearest pin to each of them at ANY radius and no neighbour can answer instead.
group PA2 {
    lassign [lrange [pa_row $TABLE R9 P] 4 5] px py
    set r9p [pa_row $TABLE R9 P]
    xschem origin - - $pa_zoom_open
    set z0 [xschem get zoom]
    set r0 [pa_radius]
    set yhit  [expr {$py - 0.5 * $r0}]
    set ymiss [expr {$py - 2.0 * $r0}]
    check "PA2a at the zoom the sheet opened with, a point HALF the radius from the pin answers it and a point TWICE the radius away answers nothing" \
        [list [pcall xschem pin_at $px $yhit] [pcall xschem pin_at $px $ymiss] [pcall xschem pin_at $px $ymiss -all]] \
        [list $r9p {} {}]
    set hit [pcall xschem pin_at $px $yhit]
    check "PA2b those two points straddle the radius: measured from the point the hit row reports, one distance is below 12*zoom*scaling and the other above" \
        [list [pa_less [pa_dist_row $px $yhit $hit] $r0] [pa_less $r0 [pa_dist_row $px $ymiss $hit]] \
              [pa_less 0 $r0]] \
        {1 1 1}
    xschem origin - - [expr {4.0 * $z0}]
    check "PA2c the radius FOLLOWS the zoom: at four times the zoom the same far point is inside (it is now half a radius away)" \
        [list [pa_near [pa_radius] [expr {4.0 * $r0}]] [pcall xschem pin_at $px $ymiss]] [list 1 $r9p]
    xschem origin - - [expr {$z0 / 4.0}]
    check "PA2d ...and at a quarter of the zoom the same near point is outside (it is now two radii away)" \
        [list [pa_near [pa_radius] [expr {$r0 / 4.0}]] [pcall xschem pin_at $px $yhit] [pcall xschem pin_at $px $yhit -all]] \
        {1 {} {}}
    # the edge itself.  It needs a radius the arithmetic hits EXACTLY, so the zoom
    # is searched for one that makes 12*zoom*scaling an integer k; the probe point
    # k units above the pin is then exactly one radius away.  The product is
    # formed from the zoom that is SET, in find_closest_pin()'s own order.
    set edge {}
    for {set k 40} {$k <= 80} {incr k} {
        set z [expr {$k / (12.0 * [pa_scale])}]
        if {12*$z*[pa_scale] == $k} { set edge [list $k $z]; break }
    }
    if {$edge ne {}} {
        lassign $edge k z
        xschem origin - - $z
        check "PA2e the radius is INCLUSIVE: a point exactly one radius from the pin answers it, in both forms, and a point one unit farther answers nothing" \
            [list [pcall xschem pin_at $px [expr {$py - $k}]] [pcall xschem pin_at $px [expr {$py - $k}] -all] \
                  [pcall xschem pin_at $px [expr {$py - $k - 1}]]] \
            [list $r9p [list $r9p] {}]
    } else {
        puts "skip: PA2e -- no zoom makes 12*zoom*scaling an exact integer between 40 and 80 at tk scaling [pa_scale], so the exact-edge leg did not run"
    }
}

# ===========================================================================
# PA3 — ties: lowest instance index, then lowest pin index
# ===========================================================================
group PA3 {
    set r [pa_set_radius 30.5]
    check "PA3 fixture: the radius was set to 30.5 and reads back as that" [pa_near $r 30.5] 1
    set l0 [pa_row $TABLE l0 p];  set l3 [pa_row $TABLE l3 p]
    set r1p [pa_row $TABLE R1 P]; set r1m [pa_row $TABLE R1 M]; set r2p [pa_row $TABLE R2 P]
    check "PA3a three pins on ONE point (0,30): the plain form answers the lowest instance index -- here the LABEL l0, so the rule is the index and not the kind of symbol -- and -all lists all three in index order" \
        [list [pcall xschem pin_at 0 30] [pcall xschem pin_at 0 30 -all]] \
        [list $l0 [list $l0 $r1m $r2p]]
    check "PA3b two pins on one point (0,-30) with the device first: the plain form answers R1.P and -all lists the label after it" \
        [list [pcall xschem pin_at 0 -30] [pcall xschem pin_at 0 -30 -all]] \
        [list $r1p [list $r1p $l3]]
    check "PA3c a point equidistant from FIVE pins, (5,0): within one instance the lower pin index comes first (R1's P before its M), and the plain form is the first row" \
        [list [pcall xschem pin_at 5 0 -all] [pcall xschem pin_at 5 0]] \
        [list [list $l0 $r1p $r1m $r2p $l3] $l0]
}

# ===========================================================================
# PA4 — `-all`: membership and order, against the rule re-derived in Tcl
# ===========================================================================
group PA4 {
    set r [pa_set_radius 50.5]
    set l0 [pa_row $TABLE l0 p];  set l3 [pa_row $TABLE l3 p]
    set r1p [pa_row $TABLE R1 P]; set r1m [pa_row $TABLE R1 M]; set r2p [pa_row $TABLE R2 P]
    check "PA4a nearest first beats index order: from (0,10) the three pins at (0,30) come before the two at (0,-30), so R1's M (pin 1) precedes R1's P (pin 0)" \
        [list [pa_near $r 50.5] [pcall xschem pin_at 0 10 -all]] \
        [list 1 [list $l0 $r1m $r2p $r1p $l3]]

    # every pin the walk can answer, in one call: a radius far wider than the sheet
    pa_set_radius 4000
    set ALL [pcall xschem pin_at 400 0 -all]
    set want {}
    foreach t $TABLE { if {![lindex $t 6]} { lappend want [lrange $t 0 5] } }
    set wellformed 1
    foreach a $ALL { if {![pa_isrow $a]} { set wellformed 0 } }
    set bad {}
    if {$wellformed && [llength $ALL] == [llength $want]} {
        foreach a [lsort -integer -index 0 [lsort -integer -index 1 $ALL]] w $want {
            if {[lrange $a 0 3] ne [lrange $w 0 3]
                || abs([lindex $a 4] - [lindex $w 4]) > 1e-3 || abs([lindex $a 5] - [lindex $w 5]) > 1e-3} {
                lappend bad [list $a $w]
            }
        }
    }
    check "PA4b at a radius wider than the sheet, -all is EXACTLY the pin table's unlocked pins -- every pin but R3's two -- each a well-formed row with indexes and names equal and coordinates within the table's %g rounding (well formed, rows answered, rows wanted, locked rows left out, the pairs that differ)" \
        [list $wellformed [llength $ALL] [llength $want] [expr {[llength $TABLE] - [llength $want]}] $bad] \
        {1 13 13 2 {}}

    # the sweep: at every point of a grid over the sheet, -all must be the pins
    # of ALL within the radius, nearest first then instance then pin, and the
    # plain form must be its first row.  The radius is 50.5 so that no integer
    # squared distance can sit on it; pa_ambiguous counts any pair that does.
    set r [pa_set_radius 50.5]
    set ::pa_ambiguous 0
    set npts 0; set nhit 0; set nmulti 0; set nmiss 0
    set bad_all {}; set bad_plain {}
    if {!$wellformed} {
        # nothing to predict from: the three rows below fail on this marker
        set bad_all [list ALL-IS-MALFORMED]; set bad_plain [list ALL-IS-MALFORMED]
    } else {
        for {set x -60} {$x <= 860} {incr x 5} {
            for {set y -70} {$y <= 130} {incr y 5} {
                incr npts
                set exp [pa_expect $ALL $x $y $r]
                set got [pcall xschem pin_at $x $y -all]
                set one [pcall xschem pin_at $x $y]
                if {$got ne $exp} { lappend bad_all [list $x $y] }
                if {$one ne [lindex $exp 0]} { lappend bad_plain [list $x $y] }
                switch [llength $exp] { 0 { incr nmiss } 1 { incr nhit } default { incr nmulti } }
            }
        }
    }
    check "PA4c the sweep is not vacuous and not on an edge: it visited every grid point, some with no pin, some with one and some with several in range, and no (point, pin) pair lies within 1e-9 of the radius" \
        [list $npts [expr {$nmiss > 0}] [expr {$nhit > 0}] [expr {$nmulti > 0}] $::pa_ambiguous] \
        {7585 1 1 1 0}
    check "PA4d over that grid, -all equals the pins within the radius sorted by (distance, instance, pin) at EVERY point (the points that differ)" \
        [lrange $bad_all 0 9] {}
    check "PA4e over that grid, the plain form equals the first row of -all at EVERY point, and the empty string where -all is empty (the points that differ)" \
        [lrange $bad_plain 0 9] {}
}

# ===========================================================================
# PA5 — lock, the pin layer, and independence from en_pin_select
# ===========================================================================
group PA5 {
    pa_set_radius 30.5
    lassign [lrange [pa_row $TABLE R3 P] 4 5] lx ly
    set r9p [pa_row $TABLE R9 P]
    check "PA5a a lock=true instance's pins do not answer at their own coordinates, in either form, while the same symbol unlocked (R9) does" \
        [list [pcall xschem pin_at $lx $ly] [pcall xschem pin_at $lx $ly -all] [pcall xschem pin_at 600 -30]] \
        [list {} {} $r9p]
    set ::enable_layer(5) 0 ; pcall xschem enable_layers
    set off [list [pcall xschem pin_at 600 -30] [pcall xschem pin_at 600 -30 -all]]
    set ::enable_layer(5) 1 ; pcall xschem enable_layers
    check "PA5b with the pin layer disabled no pin answers, in either form; enabled again, the same point answers (off pair, then on)" \
        [list $off [pcall xschem pin_at 600 -30]] [list {{} {}} $r9p]
    set saved_eps [expr {[info exists ::en_pin_select] ? $::en_pin_select : {}}]
    set ::en_pin_select 0 ; set a0 [pcall xschem pin_at 600 -30]
    set ::en_pin_select 1 ; set a1 [pcall xschem pin_at 600 -30]
    if {$saved_eps eq {}} { unset ::en_pin_select } else { set ::en_pin_select $saved_eps }
    check "PA5c the probe does not depend on en_pin_select: the same answer with the toggle 0 and 1" \
        [list $a0 $a1] [list $r9p $r9p]
}

# ===========================================================================
# PA6 — read-only
# ===========================================================================
group PA6 {
    check "PA6a on a COLD sheet the probe prepares no netlist structures: the two prep flags `xschem globals` prints are 0 before and after the calls, and `xschem instance_pins` -- which does prepare them -- moves the same witness" \
        [list $pa_prep_cold $pa_prep_after $pa_prep_control] \
        [list {prep_net_structs=0 prep_hi_structs=0} {prep_net_structs=0 prep_hi_structs=0} \
              {prep_net_structs=0 prep_hi_structs=1}]
    pa_set_radius 30.5
    set before [list [pcall xschem selection] [pcall xschem get lastsel] [pcall xschem get modified] \
                     [pcall xschem get ui_state]]
    set dump0 [pcall xschem globals]
    set n 0
    foreach {x y} {0 30 0 -30 5 0 360 0 400 20 600 -30 200 -30 12345 12345} {
        if {[pcall xschem pin_at $x $y] ne {}} { incr n }
        pcall xschem pin_at $x $y -all
    }
    set dump1 [pcall xschem globals]
    check "PA6b the probe selects nothing and modifies nothing: the selection, lastsel, the modified flag and ui_state are {} 0 0 0 before and after probing eight points (six of them hits)" \
        [list $before [list [pcall xschem selection] [pcall xschem get lastsel] [pcall xschem get modified] \
                            [pcall xschem get ui_state]] $n] \
        [list {{} 0 0 0} {{} 0 0 0} 6]
    check "PA6c ...and the whole `xschem globals` dump is byte-identical across those calls" \
        [list [expr {$dump0 eq $dump1}] [expr {[string length $dump0] > 1000}]] {1 1}

    # the undo stack, by what ONE undo restores.  A probe that pushed a slot
    # would make the undo below step back over its own push and leave R9 deleted.
    pcall xschem select instance R9
    pcall xschem delete
    set after_delete [pcall xschem get instances]
    for {set i 0} {$i < 4} {incr i} { pcall xschem pin_at 0 30 ; pcall xschem pin_at 0 30 -all }
    pcall xschem undo
    check "PA6d the probe leaves the undo stack alone: delete R9, probe eight times, and ONE undo brings R9 back (instance count after the delete, after the undo, and the name back at its index)" \
        [list $after_delete [pcall xschem get instances] [pcall xschem getprop instance 6 name]] {7 8 R9}

    # the lock control, last because it edits the sheet: with the attribute
    # cleared, the point PA5a found silent answers
    pcall xschem setprop instance 4 lock false
    check "PA6e CONTROL for PA5a: with R3's lock cleared its P pin answers at the same point, so it was the lock that silenced it" \
        [list [pcall xschem getprop instance 4 name] [pcall xschem pin_at 200 -30]] [list R3 [pa_row $TABLE R3 P]]
}

# ===========================================================================
# PA7 — one walk, read off the source (comments stripped)
# ===========================================================================
group PA7 {
    set fc [pa_ccode [file join $repo src findnet.c]]
    set rule {get_inst_pin_coord CADWIREMINDIST {"lock"} {enable_layer[PINLAYER]} point_in_inst_pin_rect(}
    check "PA7a (text) pins_in_pick_radius() holds the hit rule -- the pin coordinate, the radius, the lock test, the pin-layer test and the pin-rectangle test -- and the bodies of find_closest_pin() and find_pins_at() call it and spell none of the five themselves" \
        [list [pa_has [pa_cbody $fc {static int pins_in_pick_radius(}] $rule] \
              [pa_has [pa_cbody $fc {int find_closest_pin(}] [linsert $rule 0 pins_in_pick_radius(]] \
              [pa_has [pa_cbody $fc {int find_pins_at(}] [linsert $rule 0 pins_in_pick_radius(]]] \
        {{1 1 1 1 1} {1 0 0 0 0 0} {1 0 0 0 0 0}}
    set sc [pa_ccode [file join $repo src scheduler.c]]
    set i [string first {else if(!strcmp(argv[1], "pin_at"))} $sc]
    set branch [expr {$i < 0 ? {NOBRANCH} : [pa_cbody [string range $sc $i end] {else if(}]}]
    check "PA7b (text) the pin_at branch of the dispatcher asks find_closest_pin() and find_pins_at(), resets the result, and holds no rule or side effect of its own: no radius, no lock test, no en_pin_select, no netlist preparation, no log line, no undo push, no modify, no redraw" \
        [pa_has $branch {find_closest_pin( find_pins_at( Tcl_ResetResult( CADWIREMINDIST {"lock"} en_pin_select
                         prepare_netlist_structs log_action push_undo set_modify draw(}] \
        {1 1 1 0 0 0 0 0 0 0 0}
}

# ===========================================================================
# PA8 — a pin whose coordinate is not a number is never in range
# ===========================================================================
# A symbol file can hold `nan` in a pin rectangle; the pin's point is then NaN,
# its squared distance from any point is NaN, and every comparison with a NaN
# is false.  A walk that skips a pin only when `d > threshold` therefore COUNTS
# that pin, although it can never become the nearest: the plain form then
# answered a row for instance -1 (or died reading before the instance array),
# and -all listed the NaN pin.  The band loads its own sheet; nothing after it
# needs the PA fixture.
group PA8 {
    check "PA8 fixture: the sheet with the NaN-pinned instance loads, its second pin's point reads back as not-a-number through instance_pin_coord, and its first pin is at (260,0)" \
        [list [expr {[pcall xschem load $pa_nan_sch] ne {} ? 1 : 0}] [pcall xschem get instances] \
              [lmap c [lrange [pcall xschem instance_pin_coord xn name OUT] 1 2] { string map {- {}} [string tolower $c] }] \
              [lrange [pcall xschem instance_pin_coord xn name IN] 1 2]] \
        {1 2 {nan nan} {260 0}}
    set r [pa_set_radius 12]
    set box [lrange [lindex [split [pcall xschem instance_bbox xn] "\n"] 0] 1 4]
    set inbox 0
    if {[llength $box] == 4} {
        lassign $box bx1 by1 bx2 by2
        set inbox [expr {$bx1 < 300 && 300 < $bx2 && $by1 < 10 && 10 < $by2 ? 1 : 0}]
    }
    check "PA8 fixture: the probe point (300,10) is INSIDE the instance's box -- so the walk does reach this instance's pins -- and farther than the radius from its one real pin" \
        [list [pa_near $r 12] $inbox [pa_less $r [pa_dist 300 10 260 0]]] {1 1 1}
    set in [list 0 0 xn IN 260 0]
    check "PA8a inside that instance's box, away from the good pin, the plain form is the EMPTY STRING and -all the empty list (catch code first: a build that counts the NaN pin answers a row for instance -1 here, or dies)" \
        [list [catch {xschem pin_at 300 10} a] $a [catch {xschem pin_at 300 10 -all} b] $b] {0 {} 0 {}}
    check "PA8b at the good pin, -all is exactly ONE row and it is the plain form's answer: the NaN pin is not listed beside it" \
        [list [pcall xschem pin_at 260 0] [pcall xschem pin_at 260 0 -all]] [list $in [list $in]]
    check "PA8d a QUERY point that is not a number -- strtod reads `nan` and `inf` as numbers, so they pass the coordinate check -- answers nothing either, in both forms, at the radius that reaches the good pin from its own point (catch code and answer of four spellings, as the set of distinct answers; how many; then the control: the good pin does answer)" \
        [list [lsort -unique [lmap w {{nan nan} {260 nan} {inf 0} {-inf 0}} {
                  list [catch {xschem pin_at {*}$w} a] $a [catch {xschem pin_at {*}$w -all} b] $b }]] \
              [pcall xschem pin_at 260 0]] \
        [list [list {0 {} 0 {}}] $in]
    pa_set_radius 4000
    check "PA8c at a radius wider than the sheet, -all from inside the box lists the sheet's three real pins, nearest first, and no fourth (the instance name and pin name of each row)" \
        [lmap row [pcall xschem pin_at 300 10 -all] { expr {[pa_isrow $row] ? [lrange $row 2 3] : "MALFORMED:$row"} }] \
        {{xn IN} {R1 P} {R1 M}}
}

# ===========================================================================
# PA9 — a pin's own rectangle is the pin at any zoom
# ===========================================================================
# The radius is a distance on the SCREEN.  Zoomed far in it is smaller than the
# pin's drawn rectangle, and a point on the rectangle's corner is then farther
# from the pin's point than the radius.  Such a point still answers that pin,
# and the distance that orders the answers stays the one to the pin's point.
# The band loads its own sheet (the PA9 fixture above) and sets the radius to
# 1.6 units: less than the 2.5 from a resistor pin's point to the side of its
# square, more than the 1 from the wide pin's point to its long side, and a
# distance no point of the sweep's half-unit grid sits on.
group PA9 {
    set loaded [expr {[pcall xschem load $pa_rect_sch] ne {} ? 1 : 0}]
    set T9 [pcall pa_pin_table]
    set r [pa_set_radius 1.6]
    # every pin with half the size of its rectangle ON THE SHEET -- the symbol's,
    # swapped at an odd number of quarter turns -- the locked ones apart
    set PINS {} ; set PLAIN {} ; set lockednames {}
    foreach t $T9 {
        if {[llength $t] != 7} continue
        lassign $t i p iname pname px py locked
        set spec [lindex $PA9_INST $i]
        if {![dict exists $PA9_HALF [lindex $spec 1]]} continue
        lassign [dict get $PA9_HALF [lindex $spec 1]] hx hy
        if {[lindex $spec 4] % 2} { lassign [list $hy $hx] hx hy }
        if {$locked} { if {[lsearch -exact $lockednames $iname] < 0} { lappend lockednames $iname } ; continue }
        lappend PINS [list $i $p $iname $pname $px $py $hx $hy]
        lappend PLAIN [list $i $p $iname $pname $px $py]
    }
    set want_pins [list {R1 P 0 -30} {R1 M 0 30} {xw0 W 260 0} {xo W 268 0} {xw1 W 600 -40} {xw2 W 940 0} \
                        {xw3 W 1200 40} {xf0 W 340 300} {xf1 W 600 340} {xf2 W 860 300} {xf3 W 1200 260} \
                        {RL P 0 270} {RL M 0 330}]
    set have_pins [lmap t $T9 { lrange $t 2 5 }]
    set fixture_ok [expr {$loaded && $have_pins eq $want_pins ? 1 : 0}]
    check "PA9 fixture: the sheet loads; its pins sit where the fixture's arithmetic puts them -- the wide pin at (-40,0) of its symbol carried through none to three quarter turns, unflipped and flipped; RL is the only locked instance; and the radius reads back as 1.6, less than the 2.5 from a resistor pin's point to the side of its square" \
        [list $loaded $have_pins $lockednames [pa_near $r 1.6] [pa_less $r 2.5]] \
        [list 1 $want_pins RL 1 1]

    if {!$fixture_ok} {
        check "PA9a to PA9g did not run: the fixture is not as its own row expects, so no point of theirs can be placed" 0 1
    } else {
        set r1p [pa_row $T9 R1 P]
        set in [pa_off $r1p 2 2]
        set corner [pa_off $r1p 2.5 2.5]
        check "PA9a UNROTATED: a point INSIDE the square of R1's P pin and farther from the pin's point than the radius answers that pin, in both forms; so does the square's very corner, its edges being part of it (the inside point is farther than the radius; the two forms there; the two forms at the corner)" \
            [list [pa_less $r [pa_dist_row {*}$in $r1p]] [pa_both $in] [pa_both $corner]] \
            [list 1 [list $r1p [list $r1p]] [list $r1p [list $r1p]]]
        check "PA9b a point OUTSIDE the square and outside the radius answers nothing, in both forms: half a unit beyond the square's side, and half a unit beyond its corner both ways (the nearer of the two is farther than the radius; the two forms at each)" \
            [list [pa_less $r [pa_dist_row {*}[pa_off $r1p 3 0] $r1p]] [pa_both [pa_off $r1p 3 0]] [pa_both [pa_off $r1p 3 3]]] \
            {1 {{} {}} {{} {}}}

        set w0 [pa_row $T9 xw0 W]
        check "PA9c the WIDE pin unrotated, 12 wide and 2 tall: five units to the LEFT of its point is inside the rectangle and answers it; five units BELOW is outside both the rectangle and the radius and answers nothing; one and a half units below is outside the rectangle and inside the radius and answers it -- the radius still reaches where the rectangle is narrower than it" \
            [list [pa_both [pa_off $w0 -5 0]] [pa_both [pa_off $w0 0 5]] [pa_both [pa_off $w0 0 1.5]]] \
            [list [list $w0 [list $w0]] {{} {}} [list $w0 [list $w0]]]
        set w1 [pa_row $T9 xw1 W]
        check "PA9d ROTATED a quarter turn the rectangle is 2 wide and 12 tall: five units BELOW the pin's point is inside it and answers the pin, five units to the RIGHT is outside it and answers nothing -- PA9c's two answers the other way round" \
            [list [pa_both [pa_off $w1 0 5]] [pa_both [pa_off $w1 5 0]]] \
            [list [list $w1 [list $w1]] {{} {}}]
        set f0 [pa_row $T9 xf0 W]
        check "PA9e FLIPPED, the pin is on the other side of its instance and the rectangle goes with it: five units to the right of the pin's point answers it, five units below answers nothing, and the place the rectangle would hold without the flip -- five units right of (260,300) -- answers nothing (the flipped pin's point; then the three pairs)" \
            [list [lrange $f0 4 5] [pa_both [pa_off $f0 5 0]] [pa_both [pa_off $f0 0 5]] [pa_both {265 300}]] \
            [list {340 300} [list $f0 [list $f0]] {{} {}} {{} {}}]

        set wo [pa_row $T9 xo W]
        check "PA9f THE ORDER IS STILL BY THE DISTANCE TO THE PIN'S POINT: (265,0) is inside the rectangles of two pins and outside the radius of both; -all lists the pin three units away before the one five units away, although the farther one has the lower instance index, and the plain form is the nearer (the nearer is farther than the radius; it is nearer than the other; the two forms)" \
            [list [pa_less $r [pa_dist_row 265 0 $wo]] [pa_less [pa_dist_row 265 0 $wo] [pa_dist_row 265 0 $w0]] \
                  [pa_both {265 0}]] \
            [list 1 1 [list $wo [list $wo $w0]]]

        set rlp [pa_row $T9 RL P]
        set ::enable_layer(5) 0 ; pcall xschem enable_layers
        set off [pa_both $in]
        set ::enable_layer(5) 1 ; pcall xschem enable_layers
        check "PA9g the rectangle does not get round the lock or the pin layer: the offset that answers R1's P pin answers nothing on the locked RL, and nothing on R1 while the pin layer is disabled (the locked pin's two forms; R1's with the layer off; R1's with it on again)" \
            [list [pa_both [pa_off $rlp 2 2]] $off [pa_both $in]] \
            [list {{} {}} {{} {}} [list $r1p [list $r1p]]]
    }

    # THE SWEEP: a half-unit grid over the 16-unit window round every pin of the
    # sheet, the locked ones included.  At every point -all must be the unlocked
    # pins within the radius OR whose rectangle holds the point, nearest first
    # then instance then pin, and the plain form its first row.
    set GRID {}
    if {$fixture_ok} {
        foreach t $T9 {
            for {set dx -16} {$dx <= 16} {incr dx} {
                for {set dy -16} {$dy <= 16} {incr dy} {
                    lappend GRID [list [expr {[lindex $t 4] + $dx / 2.0}] [expr {[lindex $t 5] + $dy / 2.0}]]
                }
            }
        }
        set GRID [lsort -unique $GRID]
    }
    set ::pa_ambiguous 0 ; set ::pa_rect_only 0 ; set ::pa_disc_only 0 ; set ::pa_rect_pins {}
    set bad_all {} ; set bad_plain {} ; set nmiss 0 ; set nmulti 0
    if {!$fixture_ok} { set bad_all [list FIXTURE-NOT-AS-EXPECTED] ; set bad_plain [list FIXTURE-NOT-AS-EXPECTED] }
    foreach xy $GRID {
        lassign $xy x y
        set exp [pa_expect_rect $PINS $x $y $r]
        if {[pcall xschem pin_at $x $y -all] ne $exp} { lappend bad_all $xy }
        if {[pcall xschem pin_at $x $y] ne [lindex $exp 0]} { lappend bad_plain $xy }
        switch [llength $exp] { 0 { incr nmiss } 1 {} default { incr nmulti } }
    }
    check "PA9h the sweep at this zoom is not vacuous and not on an edge of the radius: the grid has points; some are reached by a rectangle alone, some by the radius alone, some reach nothing and some reach two pins; EVERY unlocked pin of the sheet -- each turn, flipped and not -- is reached by its rectangle alone somewhere; and no (point, pin) pair lies within 1e-9 of the radius" \
        [list [expr {[llength $GRID] > 0}] [expr {$::pa_rect_only > 0}] [expr {$::pa_disc_only > 0}] [expr {$nmiss > 0}] \
              [expr {$nmulti > 0}] [expr {[llength [dict keys $::pa_rect_pins]] == [llength $PINS] && [llength $PINS] > 0}] \
              $::pa_ambiguous] \
        {1 1 1 1 1 1 0}
    check "PA9i over that grid, -all equals the unlocked pins within the radius OR whose rectangle holds the point, edges included, sorted by (distance to the pin's point, instance, pin) at EVERY point (the points that differ)" \
        [lrange $bad_all 0 9] {}
    check "PA9j over that grid, the plain form equals the first row of -all at EVERY point, and the empty string where -all is empty (the points that differ)" \
        [lrange $bad_plain 0 9] {}

    # AN ORDINARY ZOOM: once the radius is wider than every rectangle, the
    # rectangle adds nothing and the answers are the radius rule's alone -- the
    # prediction band PA4 uses, which knows no rectangle
    set r2 [pa_set_radius 12.3]
    set widest 0.0
    foreach p $PINS { set widest [expr {max($widest, hypot([lindex $p 6], [lindex $p 7]))}] }
    set ::pa_ambiguous 0
    set bad_all {} ; set bad_plain {} ; set nhit 0 ; set nmiss 0
    if {!$fixture_ok} { set bad_all [list FIXTURE-NOT-AS-EXPECTED] ; set bad_plain [list FIXTURE-NOT-AS-EXPECTED] }
    foreach xy $GRID {
        lassign $xy x y
        set exp [pa_expect $PLAIN $x $y $r2]
        if {[pcall xschem pin_at $x $y -all] ne $exp} { lappend bad_all $xy }
        if {[pcall xschem pin_at $x $y] ne [lindex $exp 0]} { lappend bad_plain $xy }
        if {[llength $exp]} { incr nhit } else { incr nmiss }
    }
    check "PA9k AT AN ORDINARY ZOOM THE ANSWERS ARE THE RADIUS RULE'S, UNCHANGED: with the radius at 12.3 units -- wider than the farthest corner of every pin rectangle on the sheet -- the same grid answers, at every point and in both forms, exactly the pins within the radius, by the prediction that knows no rectangle (the radius read back; it exceeds the farthest corner; some points hit and some miss; no pair on the edge; the points that differ in -all; in the plain form)" \
        [list [pa_near $r2 12.3] [pa_less $widest $r2] [expr {$widest > 0}] [expr {$nhit > 0}] [expr {$nmiss > 0}] \
              $::pa_ambiguous [lrange $bad_all 0 9] [lrange $bad_plain 0 9]] \
        {1 1 1 1 1 0 {} {}}
}

# ===========================================================================
# LR — the lookup ladder's colon rung, on the committed probe results
# ===========================================================================
set data [file join $here data]
set LRFIX [list op [file join $data probe_1724_op.raw] tran [file join $data probe_1724_tran.raw]]

group LR0 {
    check "LR0 the committed fixtures are the files README.md describes: sizes in bytes, and the vector names each header lists" \
        [list [file size [dict get $LRFIX op]] [file size [dict get $LRFIX tran]] \
              [lr_file_names [dict get $LRFIX op]] [lr_file_names [dict get $LRFIX tran]]] \
        [list 435 4636 \
              {i(r9:n1) v(out) i(v1) i(x1.r1:n1) i(x1.xm1:d) i(x1.xm1:g) i(x1.xm1:s) i(x1:in)} \
              {time v(out) i(r9:n1) i(v1) i(x1.r1:n1) i(x1.xm1:d) i(x1.xm1:g) i(x1.xm1:s) i(x1:in)}]
    # the other side of the transform, which README.md states: ASE-L's Tcl readers
    # of a results file take the names as the file spells them, so a caller asking
    # one of them about a terminal current must ask in the colon spelling
    set sc [lindex [lindex [pcall ase::raw_scalars [dict get $LRFIX op]] 0] 1]
    check "LR0b ASE-L's own readers of the file's header see the COLON spelling and not the dotted one: ase::raw_vectors_present on both fixtures, and the name/value pairs ase::raw_scalars reads from the operating point" \
        [list [pcall ase::raw_vectors_present [dict get $LRFIX op] {i(x1.xm1:d) i(x1.xm1.d)}] \
              [pcall ase::raw_vectors_present [dict get $LRFIX tran] {i(x1.xm1:d) i(x1.xm1.d)}] \
              [expr {[lsearch -exact $sc {i(x1.xm1:d)}] >= 0}] [expr {[lsearch -exact $sc {i(x1.xm1.d)}] >= 0}]] \
        {i(x1.xm1:d) i(x1.xm1:d) 1 0}
}

# the tokens no file lists, with the verdict each must get from the engine AND
# the mirror: {token fold distinguish}.  `fold` is the default database,
# `distinguish` is `xschem raw case 1`.
set LRDECOYS {
    {x1.xm1:d        0 0}
    {X1.XM1:D        0 0}
    {I(X1.XM1:D)     1 0}
    {i(v.x1:in)      1 1}
    {I(V.X1:IN)      1 0}
    {i(x1:xm1:d)     1 1}
    {i(x1.xm1:zz)    0 0}
    {i(x1.nope:d)    0 0}
    {i(x1.xm1:d):    0 0}
    {out:            0 0}
    {i(x1.xm1.d)     1 1}
    {out             1 1}
    {nosuch          0 0}
}

foreach {tag path} $LRFIX {
    group LR-$tag {
        set F [lr_file_names $path]
        pcall xschem raw clear
        check "LR1a/$tag the fixture reads as `$tag`" [pcall xschem raw read $path $tag] 1
        set S [split [pcall xschem raw list] "\n"]
        set ncolon 0
        foreach f $F { if {[string first : $f] >= 0} { incr ncolon } }
        check "LR1b/$tag `xschem raw list` still shows the DOTTED stored names: the file's names with every `:` written `.`, none holding a `:`, and six of the file's names do hold one" \
            [list [expr {$S eq [lmap f $F { lr_dotted $f }]}] [lsearch -glob $S *:*] $ncolon] {1 -1 6}

        foreach {mode cs} {fold 0 distinguish 1} {
            pcall xschem raw case $cs
            set S [split [pcall xschem raw list] "\n"]
            # (a) each name spelled as the FILE spells it resolves to the index of
            #     its dotted stored name -- the right column, not merely some column
            set wrong {}
            foreach f $F {
                set e [pcall xschem raw index $f]
                if {$e ne [lsearch -exact $S [lr_dotted $f]]} { lappend wrong [list $f $e] }
            }
            check "LR2/$tag/$mode every vector name, spelled as the file spells it, resolves through `xschem raw index` to the index of its dotted stored name (the names that do not)" \
                [list [pcall xschem raw case] $wrong] [list $cs {}]

            # (b) agreement, both directions, over the file's names, their upper
            #     case, the stored names and the decoys
            set toks $F
            foreach f $F { lappend toks [string toupper $f] }
            foreach s $S { lappend toks $s }
            foreach d $LRDECOYS { lappend toks [lindex $d 0] }
            set disagree {}; set nres 0; set nref 0
            foreach t $toks {
                set e [lr_engine $t]; set m [lr_mirror $S $t]
                if {$e != $m} { lappend disagree [list $t engine $e mirror $m] }
                if {$e} { incr nres } else { incr nref }
            }
            check "LR3/$tag/$mode the Tcl mirror AGREES with the engine on every token: `xschem raw index` >= 0 exactly where wviewer::name_lookup says ok, neither resolving what the other refuses (the tokens that differ; then that some resolved and some were refused)" \
                [list $disagree [expr {$nres > 0}] [expr {$nref > 0}]] {{} 1 1}

            # (c) the decoys' verdicts, stated: agreement alone would pass if
            #     both sides refused, or resolved, everything
            set got {}; set want {}
            foreach d $LRDECOYS {
                lappend got [list [lindex $d 0] [lr_engine [lindex $d 0]]]
                lappend want [list [lindex $d 0] [lindex $d [expr {$cs ? 2 : 1}]]]
            }
            check "LR4a/$tag/$mode the decoys get their stated verdicts from the engine: a bare `x1.xm1:d` and a colon name the file does not hold still miss, upper case resolves only where folding is on, and `i(v.x1:in)` resolves through rung 4 of the dotted spelling" \
                $got $want
            check "LR4b/$tag/$mode ...and the two decoys that resolve by a rewrite land on the right columns: `i(v.x1:in)` on i(x1.in)'s index and `i(x1:xm1:d)` -- every colon mapped -- on i(x1.xm1.d)'s" \
                [list [pcall xschem raw index {i(v.x1:in)}] [pcall xschem raw index {i(x1:xm1:d)}]] \
                [list [lsearch -exact $S {i(x1.in)}] [lsearch -exact $S {i(x1.xm1.d)}]]
            # upper case: the mode is what decides, on every colon name
            set up {}
            foreach f $F { if {[string first : $f] >= 0} { lappend up [lr_engine [string toupper $f]] } }
            check "LR4c/$tag/$mode every colon name in UPPER case [expr {$cs ? {is refused (no folding)} : {resolves (folding)}}], so the dotted retry goes through the same exact-then-folded lookup as the caller's spelling" \
                [lsort -unique $up] [expr {$cs ? 0 : 1}]
        }
        pcall xschem raw case 0
    }
}

# ---------------------------------------------------------------------------
# LR5 — wviewer::name_rungs: untouched for a colon-free token
# ---------------------------------------------------------------------------
group LR5 {
    check "LR5a wviewer::name_rungs takes one formal, tok (info args)" [pcall info args ::wviewer::name_rungs] tok
    check "LR5b a colon-free token's candidates are the lists rungs 1 to 4 give: MidNode and i(v.x1.vp)" \
        [list [pcall wviewer::name_rungs MidNode] [pcall wviewer::name_rungs {i(v.x1.vp)}]] \
        [list {MidNode v(MidNode)} {i(v.x1.vp) v(i(v.x1.vp)) i(x1.vp)}]
    check "LR5c a token holding a colon gets its own candidates FIRST and then the dotted spelling's: i(x1.xm1:d), and i(v.x1:in) whose dotted spelling earns rung 4" \
        [list [pcall wviewer::name_rungs {i(x1.xm1:d)}] [pcall wviewer::name_rungs {i(v.x1:in)}]] \
        [list {i(x1.xm1:d) v(i(x1.xm1:d)) i(x1.xm1.d) v(i(x1.xm1.d))} \
              {i(v.x1:in) v(i(v.x1:in)) i(x1:in) i(v.x1.in) v(i(v.x1.in)) i(x1.in)}]
    # the whole population: both fixtures' file names and stored names, their
    # upper case, and the decoys
    set pop {}
    foreach {tag path} $LRFIX {
        foreach f [lr_file_names $path] { lappend pop $f [string toupper $f] [lr_dotted $f] }
    }
    foreach d $LRDECOYS { lappend pop [lindex $d 0] }
    set pop [lsort -unique $pop]
    set bad_plain {}; set bad_colon {}; set nplain 0; set ncolon 0
    foreach t $pop {
        set got [pcall wviewer::name_rungs $t]
        if {[string first : $t] < 0} {
            incr nplain
            if {$got ne [lr_rungs_1_4 $t]} { lappend bad_plain $t }
        } else {
            incr ncolon
            set want [lr_rungs_1_4 $t]
            foreach cand [lr_rungs_1_4 [lr_dotted $t]] { lappend want $cand }
            if {$got ne $want} { lappend bad_colon $t }
        }
    }
    check "LR5d over every token of this suite, a colon-free one gets exactly rungs 1 to 4 and a colon one gets those followed by rungs 1 to 4 of its dotted spelling (the tokens that differ in each class; then that both classes were populated)" \
        [list $bad_plain $bad_colon [expr {$nplain > 0}] [expr {$ncolon > 0}]] {{} {} 1 1}
}

# ---------------------------------------------------------------------------
# LR7 — the consumers the rung exists for
# ---------------------------------------------------------------------------
group LR7 {
    set tran [dict get $LRFIX tran]
    set op [dict get $LRFIX op]
    pcall xschem raw clear
    pcall xschem raw read $tran tran
    set S [split [pcall xschem raw list] "\n"]
    set np [pcall xschem raw points]
    set c {i(x1.xm1:d)}; set d {i(x1.xm1.d)}
    set vc [pcall xschem raw values $c]; set vd [pcall xschem raw values $d]
    check "LR7a `xschem raw value` and `raw values` answer for the file spelling what they answer for the stored one: the same first sample, and the same list of one value per point" \
        [list [expr {[pcall xschem raw value $c 0] eq [pcall xschem raw value $d 0]}] \
              [expr {[pcall xschem raw value $c 0] ne {}}] [expr {$vc eq $vd}] [expr {[llength $vc] == $np}] $np] \
        {1 1 1 1 59}
    # which column: the four probe currents that are not zero in this run differ
    # from each other, so equal values mean the same column
    set cols {}
    foreach f {i(x1.xm1:d) i(x1.xm1:s) i(x1.r1:n1) i(r9:n1)} {
        set v [pcall xschem raw values $f]
        lappend cols [list [expr {$v eq [pcall xschem raw values [lr_dotted $f]]}] \
                           [expr {[lindex $v 0] != 0}] [lindex $v 0]]
    }
    check "LR7b for four colon names, each reads its OWN column: equal to the dotted name's values, non-zero, and the four first samples pairwise distinct" \
        [list [lmap r $cols { lrange $r 0 1 }] [llength [lsort -unique [lmap r $cols { lindex $r 2 }]]]] \
        {{{1 1} {1 1} {1 1} {1 1}} 4}
    # README.md's two statements about this plot: it is at rest, and three of its
    # currents are zero
    set flat {}; set zero {}
    foreach s $S {
        if {$s eq {time}} continue
        set u [lsort -unique [pcall xschem raw values $s]]
        if {[llength $u] != 1} { lappend flat $s }
        if {[llength $u] == 1 && [lindex $u 0] == 0} { lappend zero $s }
    }
    check "LR7b2 the transient fixture is a circuit at rest: every column but time holds ONE value over all its points (the columns that do not), and exactly three currents are zero" \
        [list $flat $zero] {{} {i(v1) i(x1.xm1.g) i(x1.in)}}
    check "LR7c CONTROL a colon name the file does not hold still answers nothing through `raw value` and `raw values`" \
        [list [pcall xschem raw value {i(x1.xm1:zz)} 0] [pcall xschem raw values {i(x1.xm1:zz)}]] {{} {}}

    set added [pcall xschem raw add pa_neg "$c -1 *"]
    set vn [pcall xschem raw values pa_neg]
    set neg 1; set nonzero 1
    foreach a $vn b $vd {
        if {![string is double -strict $a] || ![string is double -strict $b]} { set neg 0; set nonzero 0; break }
        if {$a != -$b} { set neg 0 }
        if {$b == 0} { set nonzero 0 }
    }
    check "LR7d `xschem raw add n {i(x1.xm1:d) -1 *}` computes on the vector's DATA: every sample of the new column is the negation of the stored column's, which is non-zero at every point -- so neither a column of zeros nor a copy" \
        [list $added [llength $vn] $neg $nonzero] {1 59 1 1}
    pcall xschem raw add pa_miss {i(x1.xm1:zz) -1 *}
    set vm [pcall xschem raw values pa_miss]
    check "LR7e CONTROL the same expression over a colon name the file does not hold does NOT produce that data, so LR7d is the rung and not the engine accepting any name" \
        [expr {$vm eq $vn}] 0

    check "LR7f wviewer::validate_rpn passes an expression over the file spelling against the stored names, and refuses one over a colon name the file does not hold with a message naming the token" \
        [list [pcall wviewer::validate_rpn "$c 2 *" $S] \
              [string match {*i(x1.xm1:zz)*} [pcall wviewer::validate_rpn {i(x1.xm1:zz) 2 *} $S]]] \
        {{} 1}

    # the post-load current repair asks the same mirror, so it inherits the rung:
    # it runs only on a token the ladder has declined, and offers the stored names
    # the ladder's own candidates fold to
    set fold [list [dict create names $S case 0]]
    set dist [list [dict create names $S case 1]]
    check "LR7g wviewer::repair_current_token leaves the file spelling alone where it resolves (either mode, and upper case where folding is on), repairs an upper-case colon name on a `distinguish` database to the DOTTED stored spelling, and finds nothing for a colon name the file does not hold" \
        [list [pcall wviewer::repair_current_token $c $fold] [pcall wviewer::repair_current_token $c $dist] \
              [pcall wviewer::repair_current_token {I(X1.XM1:D)} $fold] \
              [pcall wviewer::repair_current_token {I(X1.XM1:D)} $dist] \
              [pcall wviewer::repair_current_token {i(x1.xm1:zz)} $dist]] \
        [list [list keep $c {}] [list keep $c {}] {keep I(X1.XM1:D) {}} \
              [list repaired $d [list $d]] {none i(x1.xm1:zz) {}}]

    pcall xschem raw clear
    set et [pcall calc::eval_text {it(x1.xm1:d)} $tran {}]
    set ed [pcall calc::eval_text {it(x1.xm1.d)} $tran {}]
    set eo [pcall calc::eval_text {idc(x1.xm1:d)} $op {}]
    set em [pcall calc::eval_text {it(x1.xm1:zz)} $tran {}]
    check "LR7h calc::eval_text evaluates `it(x1.xm1:d)` on the tran results to the wave the dotted spelling gives, and `idc(x1.xm1:d)` on the op results to a non-zero scalar; a colon name the file does not hold is refused ({ok kind points} of each, then the equalities)" \
        [list [lmap e [list $et $eo $em] { list [pcall dict get $e ok] [pcall dict get $e kind] }] \
              [pcall dict get $et points] [expr {$et eq $ed}] \
              [expr {[pcall dict get $eo value] != 0}]] \
        {{{1 wave} {1 scalar} {0 {}}} 59 1 1}
    pcall xschem raw clear
}

# ---------------------------------------------------------------------------
# LR8 — rung 5 acts ONLY ON A MISS
# ---------------------------------------------------------------------------
# The ladder tries the caller's own spelling through rungs 1 to 4 FIRST and the
# dotted spelling only when that found nothing.  No committed results can show
# the order: read_dataset() stores every `:` as `.`, so no stored name holds a
# colon and both orders answer alike.  A database that holds BOTH is made here
# with `xschem raw add`, which stores the name it is given verbatim: beside the
# stored `i(x1.r1.n1)` (the twin) a column NAMED `i(x1.r1:n1)`, computed from a
# third column.  A ladder that tried the dotted spelling first would answer the
# twin for the colon name, and `raw add` to the colon name would overwrite a
# column the simulator wrote.
proc lr_times {vals k} {
    set out {}
    foreach v $vals {
        if {![string is double -strict $v]} { return "NOTNUMERIC:$v" }
        lappend out [expr {$k * $v}]
    }
    return $out
}
# are two equally long lists of numbers equal, sample by sample, to a relative
# 1e-12?  (`raw values` prints %.16g, so a product formed in Tcl from the
# printed operand can differ from the stored product in the last place)
proc lr_same {a b} {
    if {[llength $a] != [llength $b] || [llength $a] == 0} { return 0 }
    foreach x $a y $b {
        if {![string is double -strict $x] || ![string is double -strict $y]} { return 0 }
        if {abs($x - $y) > 1e-12 * abs($y)} { return 0 }
    }
    return 1
}
group LR8 {
    set tran [dict get $LRFIX tran]
    pcall xschem raw clear
    pcall xschem raw read $tran tran
    set twin {i(x1.r1.n1)}; set colon {i(x1.r1:n1)}; set src {i(x1.xm1.d)}
    set S0 [split [pcall xschem raw list] "\n"]
    set i_twin [lsearch -exact $S0 $twin]
    set v_twin0 [pcall xschem raw values $twin]
    set v_src [pcall xschem raw values $src]
    set want3 [lr_times $v_src 3]; set want5 [lr_times $v_src 5]
    check "LR8 fixture: before the add no stored name holds a colon, the colon spelling resolves to the TWIN's index (rung 5, on a miss), and three times the source column differs from the twin at every point by far more than the comparison's tolerance -- so the columns below cannot be mistaken for one another" \
        [list [lsearch -glob $S0 *:*] [expr {$i_twin >= 0}] [expr {[pcall xschem raw index $colon] eq $i_twin}] \
              [llength $v_twin0] [lr_same $want3 $v_twin0] [lr_same $want5 $want3] \
              [expr {[llength $v_twin0] > 0 && [string is double -strict [lindex $v_twin0 0]]
                     && [string is double -strict [lindex $want3 0]]
                     && abs([lindex $want3 0] - [lindex $v_twin0 0]) > 1e-3 * abs([lindex $v_twin0 0]) ? 1 : 0}]] \
        {-1 1 1 59 0 0 1}

    set add1 [pcall xschem raw add $colon "$src 3 *"]
    set S1 [split [pcall xschem raw list] "\n"]
    set i_colon [pcall xschem raw index $colon]
    check "LR8a `xschem raw add` of the colon name makes a NEW column, stored under that name verbatim as the last one, and `xschem raw index` of the colon spelling is now THAT column and no longer the twin's, whose own index has not moved (add's answer; the stored names gained; the last name; the colon index is the last and differs from the twin's; the twin's index)" \
        [list $add1 [expr {[llength $S1] - [llength $S0]}] [lindex $S1 end] \
              [expr {$i_colon eq [expr {[llength $S1] - 1}]}] [expr {$i_colon ne $i_twin}] \
              [expr {[pcall xschem raw index $twin] eq $i_twin}]] \
        [list 1 1 $colon 1 1 1]
    set v_twin1 [pcall xschem raw values $twin]
    set v_colon1 [pcall xschem raw values $colon]
    set add2 [pcall xschem raw add $colon "$src 5 *"]
    set v_twin2 [pcall xschem raw values $twin]
    set v_colon2 [pcall xschem raw values $colon]
    check "LR8b the twin's values are BYTE-IDENTICAL before the add, after it, and after a second `raw add` to the same colon name (which answers 0: the column exists and is recomputed), so the simulator's column is never the one written" \
        [list [expr {$v_twin1 eq $v_twin0}] [expr {$v_twin2 eq $v_twin0}] $add2 \
              [llength [split [pcall xschem raw list] "\n"]]] \
        [list 1 1 0 [llength $S1]]
    check "LR8c the colon column holds the EXPRESSION's values: three times the source column after the first add and five times after the second, at every point, and never the twin's" \
        [list [lr_same $v_colon1 $want3] [lr_same $v_colon2 $want5] \
              [lr_same $v_colon1 $v_twin0] [lr_same $v_colon2 $v_twin0]] \
        {1 1 0 0}
    pcall xschem raw clear
}

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr : FAIL"; puts $::errorInfo; incr fail }

# The completion sentinel tests/banner_rule.tcl's banner_complete reads is the
# whole line `OVERALL: ok (...)`; `RESULT:` goes last because the regression
# driver publishes a case's last RESULT line.  Only the success path prints the
# sentinel.
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
