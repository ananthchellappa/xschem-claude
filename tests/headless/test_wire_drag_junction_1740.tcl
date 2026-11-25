# issue 1740 -- the junctions at the two ends of a wire the user drags
# (doc/claude/issues/1740-*.md; fluid_place_wire_junctions() in src/move.c).
#
# A connected drag of a wire used to place every wire attached to its ends by one rule: an L
# whose longer component is laid first. For an attached wire perpendicular to the dragged one
# that compares the DRAG DISTANCE with the attached wire's LENGTH, so one junction gave two
# answers. The user's report: a T (the dragged wire is the pillar, a straight run is the bar).
# A short drag slid the solder dot along the bar; a drag longer than a bar half carried that
# half sideways. And a corner at the pillar's other end followed a long drag but was left
# behind by a short one, with the pillar running past it as a dangling tail.
#
# What the rows hold now, for any drag distance:
#   ANCHOR  a bar under a T stays where it is; the dot slides along it and the pillar
#           stretches or shrinks. The same for a corner wire that cannot move (far end on a pin,
#           something resting on it).
#   CARRY   a corner wire with a clean far end follows the pillar's end; the wire(s) it meets at
#           its far end have that endpoint moved with it.
#   guards  nothing stationary is left off the copper, no new contact with another net.
#
# Bands:
#   A  the user's shape on a NAMED net (a lab_pin names it, a capacitor pin ends the bar):
#      the reported drag, a grid of drag distances against a computed wire set, pushes toward
#      and through the bar, the dot on the bar's ends, the net name and the pin's net.
#   B  the bare T in four orientations (no instance).
#   C  corner wires: far end on a pin, far end free, far end tapping a rail, a label resting
#      on the wire or on the arm it would slide over, a wire between two pin risers, one
#      between a pin riser and a free corner; a T that sits on a device pin; a pillar that ends
#      on a crossing.
#   D  guards: a carried corner wire that would land on another net's wire end, or on
#      another device's pin.
#   F  what the review of the first build found: the pillar laid onto its corner's arm or
#      shrunk to nothing (the 0092 pass then moved the bar), the free end dropped on a pin, two
#      pillars on one bar, a wire of another net crossed, trouble at the corner end, and a wire
#      end resting on a wire inside the plan.
#   E  what is not changed: dragging one HALF of the bar, and any drag with fluid_editing off.
#   G  the real gesture (display arm): click then drag, drag with nothing selected, many
#      motion steps against few, two zoom levels, Escape, one undo. Each prints one
#      lowercase `skip:` line under --nogui.
#
# Bands A to E drive the scripted release, `xschem move_objects dx dy stretch kissing`, the
# form tests/headless/wireedit uses. Band G drives pointer events through `xschem callback`.
#
# MEASURED (2026-11-24, this file against the tree before the repair, both arms):
#   see the issue file, "Rows seen red". Not copied here: a count in a comment is checked
#   by nothing.
#
#   tests/headless/run_suites.sh --nogui test_wire_drag_junction_1740
#   tests/headless/run_suites.sh test_wire_drag_junction_1740

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
set ::abortnames {}
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        lappend ::abortnames $name
        incr ::fail
    }
}

set no_recent_files 1
set ::update_recent_files 0
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set have_tk [expr {[llength [info commands winfo]] > 0}]
set ::XSCHEM_LIBRARY_DEFS [file join $repo xschem_libs_newsym library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

# ----------------------------------------------------------------------------- helpers
proc fresh {{fluid 1}} {
    xschem clear force
    uplevel #0 {set cadence_compat 1}
    uplevel #0 [list set fluid_editing $fluid]
    uplevel #0 {set orthogonal_wiring 1}
    uplevel #0 {set autotrim_wires 1}
    uplevel #0 {set enable_stretch 1}
    uplevel #0 {set unselect_partial_sel_wires 0}
    uplevel #0 {set cadsnap 10}
}
proc norm {c} {
    lassign $c x1 y1 x2 y2
    foreach v {x1 y1 x2 y2} { set $v [expr {int(round([set $v]))}] }
    if {$x1 < $x2 || ($x1 == $x2 && $y1 <= $y2)} { return [list $x1 $y1 $x2 $y2] }
    return [list $x2 $y2 $x1 $y1]
}
proc segset {} {
    set s {}
    set nw [xschem get wires]
    for {set i 0} {$i < $nw} {incr i} { lappend s [norm [xschem wire_coord $i]] }
    return [lsort $s]
}
proc want {args} { set s {}; foreach w $args { lappend s [norm $w] }; return [lsort $s] }
proc sel_wire {ax ay bx by} {
    xschem unselect_all
    set t [norm [list $ax $ay $bx $by]]
    set nw [xschem get wires]
    for {set i 0} {$i < $nw} {incr i} {
        if {[norm [xschem wire_coord $i]] eq $t} { xschem select wire $i; return $i }
    }
    return -1
}
# add a second wire to the selection (sel_wire starts a new one)
proc sel_wire_add {ax ay bx by} {
    set t [norm [list $ax $ay $bx $by]]
    set nw [xschem get wires]
    for {set i 0} {$i < $nw} {incr i} {
        if {[norm [xschem wire_coord $i]] eq $t} { xschem select wire $i; return $i }
    }
    return -1
}
proc stretch {dx dy} { xschem move_objects $dx $dy stretch kissing }
proc diagonals {} {
    set n 0
    foreach w [segset] { lassign $w a b c d; if {$a != $c && $b != $d} { incr n } }
    return $n
}
proc on_seg {x y w} {
    lassign $w a b c d
    if {$a == $c} { return [expr {$x == $a && $y >= min($b,$d) && $y <= max($b,$d)}] }
    if {$b == $d} { return [expr {$y == $b && $x >= min($a,$c) && $x <= max($a,$c)}] }
    return 0
}
# endpoints that touch no other wire (pins are not asked: the rows name the points they expect)
proc dangling {} {
    set ss [segset]; set out {}
    set k 0
    foreach w $ss {
        lassign $w a b c d
        foreach {x y} [list $a $b $c $d] {
            set hit 0; set j 0
            foreach v $ss { if {$j != $k && [on_seg $x $y $v]} { set hit 1; break }; incr j }
            if {!$hit} { lappend out [list $x $y] }
        }
        incr k
    }
    return [lsort -unique $out]
}
proc wire_net {ax ay bx by} {
    xschem resolved_net 0
    set t [norm [list $ax $ay $bx $by]]
    set nw [xschem get wires]
    for {set i 0} {$i < $nw} {incr i} {
        if {[norm [xschem wire_coord $i]] eq $t} { return [xschem getprop wire $i lab] }
    }
    return "<no such wire>"
}
proc nets_of_all_wires {} {
    xschem resolved_net 0
    set s {}
    set nw [xschem get wires]
    for {set i 0} {$i < $nw} {incr i} { lappend s [xschem getprop wire $i lab] }
    return [lsort -unique $s]
}
proc inst_by_name {n} {
    set ni [xschem get instances]
    for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
    return -1
}
proc inst_nets {name} {
    xschem resolved_net 0
    set m [xschem instance_nodemap [inst_by_name $name]]; set out {}
    foreach {p nn} [lrange $m 1 end] { if {$nn ne {}} { lappend out $nn } }
    return $out
}

# The user's shape. Pillar (780,-190)-(880,-190). Bar x=880 from -230 to -130, split at the T.
# Corner wire (riser) at the pillar's other end, x=780 up to -240, and its arm to x=550.
# The bar's top turns right to x=1040 where a lab_pin names the net a1; its bottom is the top
# pin of a capacitor at (880,-100).
proc build_T {} {
    fresh
    xschem instance devices/capa    880 -100 0 0 {name=Cc m=1 value=1p}
    xschem instance devices/lab_pin 1040 -230 0 1 {name=l1 lab=a1}
    foreach w {
        {880 -230 880 -190} {880 -190 880 -130} {780 -190 880 -190}
        {780 -240 780 -190} {550 -240 780 -240} {880 -230 1040 -230}
    } { xschem wire {*}$w }
}
# what the T must be after the pillar was dragged by (dx,dy), while the dot stays inside the
# bar and the corner inside its arm
proc T_after {dx dy} {
    set cx [expr {780 + $dx}]; set y [expr {-190 + $dy}]
    return [want [list 550 -240 $cx -240] [list $cx -240 $cx $y] [list $cx $y 880 $y] \
                 [list 880 -230 880 $y] [list 880 $y 880 -130] {880 -230 1040 -230}]
}

# ============================================================================= A
group A {
    build_T
    check "A0 the fixture is the six wires of the report's shape, all on net a1, and the capacitor's top pin is on it" \
        [list [segset] [nets_of_all_wires] [expr {[lsearch -exact [inst_nets Cc] a1] >= 0}]] \
        [list [want {880 -230 880 -190} {880 -190 880 -130} {780 -190 880 -190} {780 -240 780 -190} \
                    {550 -240 780 -240} {880 -230 1040 -230}] a1 1]

    build_T
    sel_wire 780 -190 880 -190
    stretch -70 20
    check "A1 the reported drag (-70,+20): the bar stays on x=880 from -230 to -130, the dot slides to -170, the pillar reaches from the bar to x=710, and the corner follows it" \
        [segset] [T_after -70 20]
    check "A1b ...with no diagonal, no wire end in the air but the three the fixture has (the label, the arm's far end, the capacitor pin), and every wire still on a1" \
        [list [diagonals] [dangling] [nets_of_all_wires] [expr {[lsearch -exact [inst_nets Cc] a1] >= 0}]] \
        [list 0 {{1040 -230} {550 -240} {880 -130}} a1 1]

    # the grid: one row, the cases that differ are named
    set bad {}
    set n 0
    foreach dx {-10 -40 -50 -60 -70 -150 20 60} {
        foreach dy {-30 0 20 50} {
            build_T
            sel_wire 780 -190 880 -190
            stretch $dx $dy
            incr n
            if {[segset] ne [T_after $dx $dy]} { lappend bad [list $dx $dy [segset]] }
        }
    }
    check "A2 the same holds for 32 drags, shorter and longer than each bar half and than the corner wire: the wire set is the computed one every time" \
        [list $n $bad] {32 {}}

    build_T
    sel_wire 780 -190 880 -190
    stretch 100 0
    check "A3 pushed its whole length into the bar, the pillar is gone and the corner wire now ends on the bar itself; nothing sticks out on the other side" \
        [list [segset] [dangling]] \
        [list [want {550 -240 880 -240} {880 -240 880 -230} {880 -230 880 -130} {880 -230 1040 -230}] \
              {{1040 -230} {550 -240} {880 -130}}]

    build_T
    sel_wire 780 -190 880 -190
    stretch 0 60
    check "A4 slid down to the bar's end, the dot is on the capacitor's pin and the bar is one wire again" \
        [list [segset] [expr {[lsearch -exact [inst_nets Cc] a1] >= 0}]] \
        [list [want {550 -240 780 -240} {780 -240 780 -130} {780 -130 880 -130} {880 -230 880 -130} \
                    {880 -230 1040 -230}] 1]

    build_T
    sel_wire 780 -190 880 -190
    stretch 0 -40
    check "A5 slid up to the bar's other end, the dot is on the corner there" \
        [segset] [want {550 -240 780 -240} {780 -240 780 -230} {780 -230 880 -230} {880 -230 880 -130} \
                       {880 -230 1040 -230}]

    build_T
    sel_wire 780 -190 880 -190
    stretch -70 20
    xschem undo
    check "A6 one undo puts the six wires back" \
        [segset] [want {880 -230 880 -190} {880 -190 880 -130} {780 -190 880 -190} {780 -240 780 -190} \
                       {550 -240 780 -240} {880 -230 1040 -230}]
}

# ============================================================================= B
# The bare T (bar from -40 to 60 on the axis through 0, pillar 100 long), in four orientations.
# tf maps the canonical T (pillar along -x, ending on a vertical bar at x=0) to each of them.
proc tf {o x y} {
    switch -- $o {
        left  { return [list $x $y] }
        right { return [list [expr {-$x}] $y] }
        up    { return [list $y $x] }
        down  { return [list $y [expr {-$x}]] }
    }
}
proc tfw {o w} {
    lassign $w a b c d
    return [concat [tf $o $a $b] [tf $o $c $d]]
}
group B {
    set bad {}
    set n 0
    foreach o {left right up down} {
        foreach d {{-70 20} {-30 0} {-150 -30} {40 10} {0 30}} {
            lassign $d dx dy
            fresh
            foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0}} { xschem wire {*}[tfw $o $w] }
            sel_wire {*}[tfw $o {-100 0 0 0}]
            stretch {*}[tf $o $dx $dy]
            set exp {}
            foreach w [list [list [expr {-100 + $dx}] $dy 0 $dy] [list 0 -40 0 $dy] [list 0 $dy 0 60]] {
                lappend exp [tfw $o $w]
            }
            incr n
            if {[segset] ne [want {*}$exp]} { lappend bad [list $o $dx $dy [segset]] }
        }
    }
    check "B1 the bare T in four orientations, five drags each: the bar keeps its line and its two far ends, the dot slides, the pillar's free end goes where it was dragged" \
        [list $n $bad] {20 {}}

    fresh
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0}} { xschem wire {*}$w }
    sel_wire -100 0 0 0
    stretch -30 90
    check "B2 slid past the bar's free end, the bar grows to the dot and nothing else moves" \
        [segset] [want {-130 90 0 90} {0 -40 0 90}]
}

# ============================================================================= C
group C {
    # C1: the corner wire's far end is a resistor pin (R1 at (-100,-60): pins (-100,-90), (-100,-30))
    fresh
    xschem instance devices/res -100 -60 0 0 {name=R1 m=1 value=1k}
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0} {-100 -30 -100 0}} { xschem wire {*}$w }
    sel_wire -100 0 0 0
    stretch -40 20
    check "C1 a corner wire that ends on a pin stays on the pin: the pillar keeps both its ends' columns and only moves with the dot" \
        [segset] [want {-100 20 0 20} {-100 -30 -100 20} {0 -40 0 20} {0 20 0 60}]

    # C2: the corner wire's far end is free
    fresh
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0} {-100 -50 -100 0}} { xschem wire {*}$w }
    sel_wire -100 0 0 0
    stretch -40 20
    check "C2 a corner wire with a free far end follows the pillar's end as it is" \
        [segset] [want {-140 20 0 20} {-140 -50 -140 20} {0 -40 0 20} {0 20 0 60}]

    # C3: the corner wire's far end taps a rail (two wires meeting it there)
    fresh
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0} {-100 -50 -100 0}
               {-200 -50 -100 -50} {-100 -50 -20 -50}} { xschem wire {*}$w }
    sel_wire -100 0 0 0
    stretch -40 20
    check "C3 a corner wire that taps a rail follows, and its tap slides along the rail" \
        [segset] [want {-140 20 0 20} {-140 -50 -140 20} {-200 -50 -140 -50} {-140 -50 -20 -50} \
                       {0 -40 0 20} {0 20 0 60}]
    fresh
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0} {-100 -50 -100 0}
               {-200 -50 -100 -50} {-100 -50 -20 -50}} { xschem wire {*}$w }
    sel_wire -100 0 0 0
    stretch 40 20
    check "C3b ...in the other direction too (the pillar pushed toward the bar)" \
        [segset] [want {-60 20 0 20} {-60 -50 -60 20} {-200 -50 -60 -50} {-60 -50 -20 -50} \
                       {0 -40 0 20} {0 20 0 60}]

    # C4: a label rests on the corner wire: carrying the wire would leave it in the air
    fresh
    xschem instance devices/lab_pin -100 -20 0 0 {name=l1 lab=sig}
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0} {-100 -50 -100 0} {-200 -50 -100 -50}} { xschem wire {*}$w }
    sel_wire -100 0 0 0
    stretch -40 20
    check "C4 a corner wire with a label resting on it is not carried: it keeps its column, the label is still on it, and the net keeps the label's name" \
        [list [segset] [nets_of_all_wires]] \
        [list [want {-100 20 0 20} {-100 -50 -100 20} {-200 -50 -100 -50} {0 -40 0 20} {0 20 0 60}] sig]

    # C5: a wire between two pin risers moves across them only
    fresh
    xschem instance devices/res -100 -60 0 0 {name=R1 m=1 value=1k}
    xschem instance devices/res    0 -60 0 0 {name=R2 m=1 value=1k}
    foreach w {{-100 -30 -100 20} {0 -30 0 20} {-100 20 0 20}} { xschem wire {*}$w }
    sel_wire -100 20 0 20
    stretch 30 20
    check "C5 a wire between two risers that end on pins moves across them only: the drag along it is not applied" \
        [list [segset] [diagonals]] \
        [list [want {-100 -30 -100 40} {0 -30 0 40} {-100 40 0 40}] 0]
    check "C5b ...and the two resistors' bottom pins are still on one net, their top pins on two others" \
        [list [expr {[lindex [inst_nets R1] end] eq [lindex [inst_nets R2] end]}] \
              [expr {[lindex [inst_nets R1] 0] ne [lindex [inst_nets R2] 0]}] \
              [expr {[lindex [inst_nets R1] 0] ne [lindex [inst_nets R1] end]}]] {1 1 1}

    # C8: one end on a pin riser, the other a corner with a free far end
    fresh
    xschem instance devices/res -100 -60 0 0 {name=R1 m=1 value=1k}
    foreach w {{-100 -30 -100 20} {-100 20 0 20} {0 -40 0 20}} { xschem wire {*}$w }
    sel_wire -100 20 0 20
    stretch 40 20
    check "C8 a wire between a pin riser and a free corner wire: the pin riser keeps its column and the free corner still follows the drag" \
        [segset] [want {-100 -30 -100 40} {-100 40 40 40} {40 -40 40 40}]

    # C9: a label rests on the arm the corner would slide over
    fresh
    xschem instance devices/lab_pin -120 -50 0 0 {name=l1 lab=sig}
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0} {-100 -50 -100 0} {-200 -50 -100 -50}} { xschem wire {*}$w }
    sel_wire -100 0 0 0
    stretch -40 20
    check "C9 a label on the arm, in the stretch the corner would give up: the corner wire is not carried past it, the arm keeps its length and the label its net" \
        [list [segset] [nets_of_all_wires]] \
        [list [want {-100 20 0 20} {-100 -50 -100 20} {-200 -50 -100 -50} {0 -40 0 20} {0 20 0 60}] sig]

    # C6: the T sits on a device pin (R3 rotated: its pin M is at (0,0), on the bar)
    set bad {}
    foreach d {{-30 20} {-150 20} {-150 -30} {40 0}} {
        lassign $d dx dy
        fresh
        xschem instance devices/res 30 0 1 0 {name=R3 m=1 value=1k}
        foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0}} { xschem wire {*}$w }
        sel_wire -100 0 0 0
        stretch $dx $dy
        set exp [list [list [expr {-100 + $dx}] $dy 0 $dy]]
        # the bar is cut at the pin and at the dot (one cut when the dot is on the pin)
        set cuts [lsort -integer -unique [list -40 0 $dy 60]]
        for {set i 0} {$i < [llength $cuts] - 1} {incr i} {
            lappend exp [list 0 [lindex $cuts $i] 0 [lindex $cuts [expr {$i + 1}]]]
        }
        if {[segset] ne [want {*}$exp]} { lappend bad [list $dx $dy [segset]] }
    }
    check "C6 a T that sits on a device pin: the bar stays on the pin for four drags, the dot slides, and no second wire is left between the pin and the pillar" \
        $bad {}

    # C7: the pillar ends on a crossing (the bar, and a wire that continues the pillar)
    set bad {}
    foreach d {{-30 20} {-150 20} {-150 -30}} {
        lassign $d dx dy
        fresh
        foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0} {0 0 80 0}} { xschem wire {*}$w }
        sel_wire -100 0 0 0
        stretch $dx $dy
        set exp [list [list [expr {-100 + $dx}] $dy 0 $dy] {0 0 80 0}]
        set cuts [lsort -integer -unique [list -40 0 $dy 60]]
        for {set i 0} {$i < [llength $cuts] - 1} {incr i} {
            lappend exp [list 0 [lindex $cuts $i] 0 [lindex $cuts [expr {$i + 1}]]]
        }
        if {[segset] ne [want {*}$exp]} { lappend bad [list $dx $dy [segset]] }
    }
    check "C7 a pillar that ends on a crossing: the bar and the wire across stay, the crossing becomes two T junctions" \
        $bad {}
}

# ============================================================================= D
group D {
    # Another net's wire ends exactly where the carried corner wire would land: at (-140,-20),
    # coming from the left, named by a label. Carrying the corner wire to x=-140 would weld the
    # two nets, and no instance pin is on the other one for the pin partition to see.
    fresh
    xschem instance devices/lab_pin -300 -20 0 0 {name=l2 lab=other}
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0} {-100 -50 -100 0} {-300 -20 -140 -20}} { xschem wire {*}$w }
    sel_wire -100 0 0 0
    stretch -40 20
    check "D1 a corner wire that would land on another net's wire end is not carried there: the two nets stay two, and that wire is untouched" \
        [list [wire_net -300 -20 -140 -20] [llength [nets_of_all_wires]] \
              [expr {[lsearch -exact [segset] [norm {-140 -50 -140 20}]] >= 0}]] \
        {other 2 0}
    check "D1b ...the pillar still keeps the bar: bar on x=0 from -40 to 60, dot at 20" \
        [list [expr {[lsearch -exact [segset] [norm {0 -40 0 20}]] >= 0}] \
              [expr {[lsearch -exact [segset] [norm {0 20 0 60}]] >= 0}] [diagonals]] {1 1 0}

    # The pin of another device lies where the carried corner wire would land: R2 at (-140,-60)
    # has its lower pin at (-140,-30), on the column x=-140 between -50 and 0. R1 holds the bar's
    # lower end so that the dragged net has a pin of its own.
    fresh
    xschem instance devices/res    0   90 0 0 {name=R1 m=1 value=1k}
    xschem instance devices/res -140  -60 0 0 {name=R2 m=1 value=1k}
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0} {-100 -50 -100 0}} { xschem wire {*}$w }
    set r2before [inst_nets R2]
    sel_wire -100 0 0 0
    stretch -40 20
    check "D2 a corner wire that would land on another device's pin is not carried there: it keeps its column, the pillar stops at it, and that pin is on no wire" \
        [list [segset] [expr {[lsearch -exact [inst_nets R1] [lindex [inst_nets R2] end]] < 0}] [diagonals]] \
        [list [want {-100 20 0 20} {-100 -50 -100 20} {0 -40 0 20} {0 20 0 60}] 1 0]
}

# ============================================================================= F
# What the review of the first build found (wf_0298fc55-832), one band row each.
group F {
    # F1: a drag that lays the pillar onto the arm of its own corner (the corner wire shrinks to
    # nothing). The pass's result has a tail above the bar; the overshoot pass of issue 0092 took
    # that tail for an overshoot and moved the BAR to its tip. That pass needs a START pin
    # snapshot, so one instance that touches nothing is in the sheet, and the net is auto-named.
    fresh
    xschem instance devices/lab_pin -300 -300 0 0 {name=l9 lab=far}
    foreach w {{-40 0 20 0} {20 0 30 0} {20 -20 20 0} {20 -20 50 -20} {50 -20 50 100}} { xschem wire {*}$w }
    sel_wire 20 -20 20 0
    stretch 30 -60
    check "F1 the pillar dragged onto the line of its corner's arm: the bar stays on its line (it grows to the arm), nothing is moved to the tip of what is left of the pillar" \
        [segset] [want {-40 0 50 0} {50 -80 50 0} {50 0 50 100}]

    fresh
    xschem instance devices/lab_pin -300 -300 0 0 {name=l9 lab=far}
    foreach w {{-180 -30 -50 -30} {-50 -30 0 -30} {-50 -70 -50 -30} {-110 -70 -50 -70} {-110 -110 -110 -70}} { xschem wire {*}$w }
    sel_wire -50 -70 -50 -30
    stretch 60 40
    check "F1b the pillar shrunk to nothing on the bar: the corner wire lies on the bar and its arm keeps its column" \
        [segset] [want {-180 -30 -110 -30} {-110 -30 10 -30} {-110 -110 -110 -30}]

    # F2: the drag drops the pillar's free end on a device pin. Every route changes which pins
    # are connected, so the safety ladder rolled the junction placement back and kept the old
    # route, with the bar carried. R6 holds the bar's end, R5's pin is where the free end lands.
    fresh
    xschem instance devices/res    0  90 0 0 {name=R6 m=1 value=1k}
    xschem instance devices/res -170  50 0 0 {name=R5 m=1 value=1k}
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0}} { xschem wire {*}$w }
    sel_wire -100 0 0 0
    stretch -70 20
    check "F2 the pillar's free end dropped on a device pin: the pin is connected, and the bar still stays" \
        [list [segset] [expr {[lindex [inst_nets R5] 0] eq [lindex [inst_nets R6] 0]}]] \
        [list [want {-170 20 0 20} {0 -40 0 20} {0 20 0 60}] 1]

    # F3: two pillars on one bar, dragged together. The piece of the bar between them is grabbed
    # at both ends, which made it a whole-selected wire that moved with the drag.
    set bad {}
    foreach d {{-30 20} {-30 0} {-10 0} {-120 20} {0 20}} {
        lassign $d dx dy
        fresh
        foreach w {{0 -100 0 -50} {0 -50 0 50} {0 50 0 100} {-100 -50 0 -50} {-100 50 0 50}} { xschem wire {*}$w }
        sel_wire -100 -50 0 -50
        set second [sel_wire_add -100 50 0 50]
        stretch $dx $dy
        set exp [want [list [expr {-100 + $dx}] [expr {-50 + $dy}] 0 [expr {-50 + $dy}]] \
                      [list [expr {-100 + $dx}] [expr {50 + $dy}] 0 [expr {50 + $dy}]] \
                      [list 0 -100 0 [expr {-50 + $dy}]] [list 0 [expr {-50 + $dy}] 0 [expr {50 + $dy}]] \
                      [list 0 [expr {50 + $dy}] 0 100]]
        if {[segset] ne $exp} { lappend bad [list $dx $dy [segset]] }
    }
    check "F3 two pillars on one bar dragged together, five drags: the whole bar stays on its line, the piece between the two dots included" \
        $bad {}

    # F4: the stretched pillar only CROSSES a wire of another net. The first build's contact check
    # counted that as a contact and dropped the whole plan, so the bar was carried as in the report.
    build_T
    xschem instance devices/lab_pin 830 -150 3 0 {name=l3 lab=other}
    xschem wire 830 -180 830 -150
    sel_wire 780 -190 880 -190
    stretch -70 20
    check "F4 the reported drag with a wire of another net across the pillar's new place: the bar stays, the other wire is untouched and still on its own net" \
        [list [segset] [wire_net 830 -180 830 -150] [llength [nets_of_all_wires]]] \
        [list [lsort [concat [T_after -70 20] [list [norm {830 -180 830 -150}]]]] other 2]

    # F5: trouble at the CORNER end must not cost the bar its place. A label rests on the corner
    # wire where the drag sweeps past it, so the corner can be neither carried nor anchored.
    fresh
    xschem instance devices/lab_pin -90 70 0 0 {name=l1 lab=sig}
    foreach w {{-50 0 -50 10} {-50 10 -50 90} {-90 10 -50 10} {-90 10 -90 120}} { xschem wire {*}$w }
    sel_wire -90 10 -50 10
    stretch -30 180
    set onbar {}
    foreach w [segset] { lassign $w a b c d; if {$a == $c && $a == -50} { lappend onbar $w } }
    set off 0
    foreach w [segset] { lassign $w a b c d; if {$a == $c && $a > -90 && $a < -50} { incr off } }
    check "F5 a corner that can be neither carried nor anchored (a label in the drag's way): the bar is still anchored, on x=-50 from 0 past the dot, and no piece of it has moved toward the corner" \
        [list [expr {[llength $onbar] >= 1}] [lindex [lindex $onbar 0] 1] [expr {[lindex [lindex $onbar end] 3] >= 190}] $off \
              [diagonals] [nets_of_all_wires]] {1 0 1 0 0 sig}

    # F6: with autotrim off, the far end of an ANCHORED corner wire can rest on the middle of a
    # wire another junction reshapes. The left-off-the-copper check did not look at the ends of
    # wires that are themselves in the plan.
    fresh
    uplevel #0 {set autotrim_wires 0}
    xschem instance devices/lab_pin 300 -100 0 1 {name=l1 lab=sig}
    foreach w {{0 0 100 0} {0 -100 0 0} {0 -100 300 -100} {30 -200 30 -100} {30 -200 130 -200}} { xschem wire {*}$w }
    sel_wire 0 0 100 0
    sel_wire_add 30 -200 130 -200
    stretch 60 0
    check "F6 autotrim off, two dragged wires, one's corner wire resting on the middle of a wire the other's corner would shorten: all five wires stay on one net" \
        [list [nets_of_all_wires] [diagonals]] {sig 0}
    uplevel #0 {set autotrim_wires 1}
}

# ============================================================================= E
group E {
    # The dragged wire is one HALF of the bar (the pillar hangs on the joint): no plan. The row
    # holds the wire set the tree before this issue gives for the same drag (measured there with
    # this script), which is the old length rule: the other half, 40 long, stays for a drag of 30.
    fresh
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0}} { xschem wire {*}$w }
    sel_wire 0 0 0 60
    stretch 30 20
    check "E1 dragging one half of the bar is placed as before this issue (no plan for that shape)" \
        [segset] [want {-100 0 30 0} {0 -40 0 20} {0 20 30 20} {30 0 30 20} {30 20 30 80}]

    # fluid_editing off: the pass does not run; the old length rule carries a short bar half
    fresh 0
    foreach w {{0 -40 0 0} {0 0 0 60} {-100 0 0 0}} { xschem wire {*}$w }
    sel_wire -100 0 0 0
    stretch -70 0
    check "E2 with fluid_editing off the pass does not run (the bar half shorter than the drag is carried, as before)" \
        [expr {[lsearch -exact [segset] [norm {-70 -40 -70 0}]] >= 0}] 1
}

# ============================================================================= G
group G {
    if {!$have_tk} {
        puts "skip: G1-G6 need a display (the click and the drag are pointer events on the schematic window)"
    } else {
        set WIN .drw
        catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
        for {set i 0} {$i < 40} {incr i} {
            if {![catch {winfo viewable $WIN} vv] && $vv} break
            update idletasks; after 100; update
        }
        update idletasks; catch { focus -force $WIN }; update idletasks
        proc scr {sx sy} {
            set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
            return [list [expr {int(round(($sx+$xo)/$z))}] [expr {int(round(($sy+$yo)/$z))}]]
        }
        proc g_press {x y} { lassign [scr $x $y] a b; xschem callback $::WIN 4 $a $b 0 1 0 0 }
        proc g_move {x y}  { lassign [scr $x $y] a b; xschem callback $::WIN 6 $a $b 0 0 0 256 }
        proc g_rel {x y}   { lassign [scr $x $y] a b; xschem callback $::WIN 5 $a $b 0 1 0 256 }
        # press at (px,py), move in `steps` equal parts to (px+dx,py+dy), release
        proc g_drag {px py dx dy steps} {
            g_press $px $py
            for {set k 1} {$k <= $steps} {incr k} {
                g_move [expr {$px + double($dx) * $k / $steps}] [expr {$py + double($dy) * $k / $steps}]
                update idletasks
            }
            g_rel [expr {$px + $dx}] [expr {$py + $dy}]
            update
        }
        proc g_view {zoomin} {
            xschem zoom_full
            for {set i 0} {$i < $zoomin} {incr i} { xschem zoom_in }
            update
        }
        uplevel #0 {set intuitive_interface 1}

        build_T; g_view 0
        xschem unselect_all
        g_press 820 -190; g_rel 820 -190; update
        g_drag 820 -190 -70 20 8
        check "G1 click on the pillar, then drag it by (-70,+20) with the pointer: the same wire set as the scripted release" \
            [segset] [T_after -70 20]

        build_T; g_view 0
        xschem unselect_all
        g_drag 820 -190 -70 20 8
        check "G2 the same drag with nothing selected before the press" \
            [segset] [T_after -70 20]

        build_T; g_view 0
        xschem unselect_all
        g_drag 820 -190 -70 20 40
        set many [segset]
        build_T; g_view 0
        xschem unselect_all
        g_drag 820 -190 -70 20 1
        check "G3 forty motion steps and one give the same wires" \
            [list $many [segset]] [list [T_after -70 20] [T_after -70 20]]

        build_T; g_view 3
        xschem unselect_all
        g_drag 820 -190 -70 20 8
        check "G4 zoomed in three steps, the same drag in schematic units gives the same wires" \
            [segset] [T_after -70 20]

        build_T; g_view 0
        xschem unselect_all
        g_press 820 -190
        g_move 790 -180; update idletasks
        g_move 750 -170; update idletasks
        set mid [segset]
        xschem callback $WIN 2 0 0 65307 0 0 0   ;# Escape
        update
        check "G5 mid-drag the bar is already where it will stay, and Escape puts the six wires back" \
            [list [expr {[lsearch -exact $mid [norm {880 -230 880 -170}]] >= 0}] \
                  [expr {[lsearch -exact $mid [norm {880 -170 880 -130}]] >= 0}] [segset]] \
            [list 1 1 [want {880 -230 880 -190} {880 -190 880 -130} {780 -190 880 -190} \
                            {780 -240 780 -190} {550 -240 780 -240} {880 -230 1040 -230}]]
        catch { g_rel 750 -170 }
        update

        build_T; g_view 0
        xschem unselect_all
        g_drag 820 -190 -70 20 8
        xschem undo
        check "G6 one undo after the pointer drag puts the six wires back" \
            [segset] [want {880 -230 880 -190} {880 -190 880 -130} {780 -190 880 -190} \
                           {780 -240 780 -190} {550 -240 780 -240} {880 -230 1040 -230}]
        xschem set modified 0
    }
}

check "EVERY band above this one RAN TO ITS END (names of any abandoned band)" \
    [list [llength $::abortnames] $::abortnames] {0 {}}

xschem set modified 0
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
