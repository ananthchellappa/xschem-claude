# test_drag_tclvar_reads.tcl -- a drag frame must not re-read a Tcl variable once per pin or
# per wire, and the C-side cache of ::cadsnap (tclgetcadsnap(), src/scheduler.c) must never
# hand back a value the variable no longer holds.
#
# THE DEFECT (doc/claude/drag_perf_batch/receipts/A-fix.md): the fluid-wiring predicates in
# src/move.c (point_near_pin, fluid_pin_on_seg, fluid_seg_pair_touch*, and the callers
# point_on_fixed_pin / point_on_moving_pin / fluid_moving_pin_net) each began with
# tclgetdoublevar("cadsnap") -- a Tcl_GetVar hash lookup plus an atof_spice() sscanf -- and
# they are called inside instance-pin x wire-segment loops. So every live-commit drag step
# re-read and re-parsed one constant a number of times that grew with the page, and that was
# most of a drag frame on ordinary pages. The fix reads it through tclgetcadsnap(), a cache
# dropped by a Tcl write/unset trace on ::cadsnap and on every entry into the `xschem`
# command.
#
# THE INSTRUMENT: Tcl READ traces on every scalar global. A C read through Tcl_GetVar fires
# them exactly like a script read, so the count per `xschem move_objects step` is the number
# of real Tcl variable reads the drag pipeline made in that step. Nothing in the product is
# instrumented for this suite.
#
# BANDS
#   R  reads per live-commit drag step, on a small and a ten-times larger page:
#        R1/R2  ::cadsnap is read from Tcl at most once per step (one xschem command);
#        R3     the total of ALL global reads made inside the fixture's live `move_objects
#               step` commands is the same on both pages, so no variable is re-read per pin
#               or per wire AT THE SITES THOSE STEP COMMANDS REACH. It counts nothing outside
#               them, so a per-call read coming back elsewhere stays green: in the END-only
#               fluid passes, which run under `move_objects end` and never on a live step
#               (fluid_straighten_reversals' inner read and the per-wire
#               fluid_jog_is_moved_pin_escape_overshoot() it calls, fluid_jog_pin_off_backbone()
#               under fluid_ripup_foreign_pin_short, fluid_manh_route() under
#               fluid_manhattanize_relay_diagonals), and at sites this fixture's steps do not
#               reach at all (the move_objects covered-wire check, check.c, snap_to_grid(), the
#               callback.c rotate/flip and snap-change sites). Which sites the steps reach
#               was measured with copies broken on purpose:
#               doc/claude/drag_perf_batch/receipts/B-verify.md, finding F4;
#        R0     the counted drags ran with drawing off (see the comment above band R);
#        R4-R7  non-vacuity: the instrument sees C-side reads, every step really committed
#               a reroute, a drag of every device DOES grow the count (so R3's equality is a
#               measurement, not a saturated or dead counter), and the fixture is the size
#               it claims.
#   S  the cache is never stale. Observables, both measured on bd14668b9 before the cache
#      existed: (a) with linewidth_follows_snap=1, draw() and set_snap() recompute the dot
#      size from the LIVE snap (`cadhalfdotsize` in `xschem globals`); (b) a stretch drag
#      picks up a wire whose end sits 7 units off a pin only when cadsnap/2 >= 7.
#      Each of the cache's four invalidations, and each half of its read-then-arm order
#      (src/scheduler.c, the comment above tclgetcadsnap), has a row that only it can pass:
#        S1  (the write trace) a Tcl write in the middle of ONE C command, from a read trace
#            on a variable that command reads; S1a/S1b the plain write-then-read of set_snap;
#        S2  a write trace added AFTER the cache's own, whose body re-enters C with a
#            read-only `xschem redraw` (Tcl runs the newest trace first), the write made at
#            top level -- where the previous command's exit drop (invalidation 4) covers it
#            as well as the entry drop does; S2b (the entry invalidation) the same with the
#            write made in the MIDDLE of a C command that has already filled the cache, where
#            only the drop on the nested `xschem` command's entry can make its read fresh;
#        S3  (the trace's re-install) S1 again after an unset took every trace away; S3b a
#            write and read with the variable still missing at the first read;
#        S4  every way the snap can change (plain `set`, `xschem set cadsnap`, an upvar
#            alias, `uplevel #0 set` as restore_ctx does per tab/window, `xschem snap
#            double|half`, the statusbar entry's set-then-xschem-set), each followed by a
#            drag that must use the new value -- after a drag that primed the old one;
#        S5  a non-normalised spelling (1.5e1) reads as the number it spells;
#        S6  (the C writer, tclsetcadsnap) a write made inside another write trace on
#            ::cadsnap fires no trace at all, and is still seen by the C code that made it or
#            that wrote just before it.
#      S7-S9 are the three shapes an independent verification of stage A found stale or
#      changed against base (doc/claude/drag_perf_batch/receipts/B-verify.md, F1-F3). Each
#      needs a user trace on ::cadsnap or an `unset ::cadsnap`, which nothing in the tree
#      makes, so they fence the cache's contract rather than an in-tree path:
#        S7  (the exit invalidation) an OLDER write trace whose body runs `xschem redraw`
#            (refilling the cache) and then rewrites ::cadsnap with every trace off, the
#            outer write made by Tcl in the middle of a stretch drag: the rest of that drag
#            must see the rewrite;
#        S8  (arming after the read) a READ trace on ::cadsnap that unsets and recreates it
#            inside the cache's own read must not leave the value cached with no write trace
#            on it: the S1 mid-command write after it is still seen;
#        S9  (no trace on a missing variable) after `unset ::cadsnap` and a C read,
#            `upvar #0 other cadsnap` succeeds as it does without a cache, and the next drag
#            uses the alias. It is the LAST row: a global upvar link cannot be undone.
#
# Runs headless. From the repo ROOT:
#   tests/headless/run_suites.sh --nogui test_drag_tclvar_reads
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_drag_tclvar_reads.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc ::bgerror {msg} { puts "BGERROR: $msg"; incr ::fail }

# a schematic of N two-pin resistors, each with three wires on its pins, on a 10 x N/10 grid
proc build_page {N} {
    xschem clear force
    set ::enable_stretch 1; set ::orthogonal_wiring 1; set ::cadence_compat 1
    set ::autotrim_wires 1; set ::fluid_editing 1; set ::unselect_partial_sel_wires 0
    xschem set cadsnap 10
    for {set i 0} {$i < $N} {incr i} {
        set x [expr {($i % 10) * 200}]; set y [expr {($i / 10) * 300}]
        xschem instance devices/res $x $y 0 0 "name=R$i m=1 value=1k"
        xschem wire $x [expr {$y+30}] $x [expr {$y+130}]
        xschem wire $x [expr {$y+130}] [expr {$x+60}] [expr {$y+130}]
        xschem wire $x [expr {$y-30}] $x [expr {$y-90}]
    }
}
proc segs {} {
    set s {}
    for {set i 0} {$i < [xschem get wires]} {incr i} { lappend s [xschem wire_coord $i] }
    return [lsort $s]
}

# --- the read counter ------------------------------------------------------------------
set ::RD_ON 0
proc rd_hit {v args} { if {$::RD_ON} { incr ::RD($v) } }
set ::RD_TRACED {}
proc rd_arm {} {
    foreach v [info globals] {
        if {[array exists ::$v] || $v in {RD_ON RD RD_TRACED}} continue
        trace add variable ::$v read [list rd_hit $v]
        lappend ::RD_TRACED $v
    }
}
proc rd_disarm {} {
    foreach v $::RD_TRACED { catch {trace remove variable ::$v read [list rd_hit $v]} }
    set ::RD_TRACED {}
}
# run one script with counting on; returns a dict {var count ...} of the reads it made
proc rd_count {script} {
    array unset ::RD
    set ::RD_ON 1
    uplevel #0 $script
    set ::RD_ON 0
    set d {}
    foreach n [lsort [array names ::RD]] { dict set d $n $::RD($n) }
    return $d
}
proc dsum {d} { set t 0; dict for {k v} $d { incr t $v }; return $t }
proc dget {d k} { if {[dict exists $d $k]} { return [dict get $d $k] }; return 0 }

# one stretch drag of the current selection through six live-commit steps; returns
# {per-step-read-dicts per-step-segsets}
set ::STEPS {10 0 20 0 30 10 40 20 50 20 60 30}
proc drag_counted {} {
    set reads {}; set geo {}
    xschem move_objects start 0 0 kissing stretch
    lappend geo [segs]
    foreach {sx sy} $::STEPS {
        lappend reads [rd_count [list xschem move_objects step $sx $sy]]
        lappend geo [segs]
    }
    xschem move_objects end 60 30
    return [list $reads $geo]
}

if {[catch {

# ======================================================================================
# band R -- Tcl reads per drag step do not grow with the page
# ======================================================================================
# Drawing is OFF for the counted drags, on both arms. With a window, draw() itself reads
# lvs_ignore once per drawn symbol (draw_symbol) and auto_set_wire_bus once per drawn wire, so
# on the display arm those two grow with the page; they are outside this fix and declared in
# A-fix.md. Drawing off makes both arms measure the same pipeline: the drag's own passes.
rd_arm
set R {}
set nd {}
foreach N {4 40} {
    build_page $N
    dict set R $N inst [xschem get instances]
    dict set R $N wires [xschem get wires]
    xschem unselect_all
    xschem select instance 0
    xschem set no_draw 1; lappend nd [xschem get no_draw]
    lassign [drag_counted] reads geo
    xschem set no_draw 0
    dict set R $N reads $reads
    dict set R $N geo $geo
    # control: the same drag with EVERY device selected
    build_page $N
    xschem select_all
    xschem set no_draw 1; lappend nd [xschem get no_draw]
    lassign [drag_counted] reads_all geo_all
    xschem set no_draw 0
    dict set R $N reads_all $reads_all
}
check "R0 the counted drags ran with drawing off ({$nd})" $nd {1 1 1 1}

foreach N {4 40} {
    set cs {}
    foreach d [dict get $R $N reads] { lappend cs [dget $d cadsnap] }
    set over [lmap c $cs { expr {$c > 1} }]
    check "R[expr {$N == 4 ? 1 : 2}] N=$N: each stretch drag step reads ::cadsnap from Tcl at most once\
           (per-step reads: $cs)" [expr {"1" ni $over}] 1
}

set t4  [lmap d [dict get $R 4 reads]  { dsum $d }]
set t40 [lmap d [dict get $R 40 reads] { dsum $d }]
set grew {}
foreach d4 [dict get $R 4 reads] d40 [dict get $R 40 reads] {
    dict for {k v} $d40 { if {$v != [dget $d4 $k]} { lappend grew "$k:[dget $d4 $k]->$v" } }
}
check "R3 total Tcl global reads per step are the same on a 4- and a 40-device page\
       (N=4 {$t4} N=40 {$t40}; vars that moved: [lsort -unique $grew])" [expr {$t4 eq $t40}] 1

set fe {}; set c1 {}
foreach N {4 40} {
    foreach d [dict get $R $N reads] { lappend fe [dget $d fluid_editing]; lappend c1 [dget $d cadsnap] }
}
check "R4 the counter sees C-side Tcl_GetVar reads: fluid_editing and ::cadsnap are each read\
       in every step (fluid_editing {$fe} cadsnap {$c1})" \
    [expr {[lsort -integer $fe] ne {} && [lindex [lsort -integer $fe] 0] > 0 &&
           [lindex [lsort -integer $c1] 0] >= 1}] 1

set moved {}
foreach N {4 40} {
    set g [dict get $R $N geo]
    for {set k 1} {$k < [llength $g]} {incr k} {
        lappend moved [expr {[lindex $g $k] ne [lindex $g [expr {$k-1}]]}]
    }
}
check "R5 every one of the counted steps committed a live reroute (geometry changed per step: $moved)" \
    [expr {"0" ni $moved && [llength $moved] == 2 * [llength $::STEPS] / 2}] 1

set a4  [lmap d [dict get $R 4 reads_all]  { dsum $d }]
set a40 [lmap d [dict get $R 40 reads_all] { dsum $d }]
set allgrew 1
foreach x $a4 y $a40 { if {!($y > $x)} { set allgrew 0 } }
check "R6 control: dragging EVERY device, reads per step do grow from 4 to 40 devices\
       (N=4 {$a4} N=40 {$a40}), so R3's equality is a measurement" $allgrew 1

check "R7 the fixtures are the size they claim (instances/wires at N=4 and N=40)" \
    [list [dict get $R 4 inst] [dict get $R 4 wires] [dict get $R 40 inst] [dict get $R 40 wires]] \
    {4 12 40 120}
rd_disarm

# ======================================================================================
# band S -- the cache is never stale
# ======================================================================================
set ::linewidth_follows_snap 1
proc dot {} {
    if {![regexp {cadhalfdotsize=([^\n]+)} [xschem globals] -> d]} { return ERR }
    return $d
}
proc near {a b} { expr {[string is double -strict $a] && [string is double -strict $b] && abs($a - $b) < 1e-9} }

xschem clear force
xschem set cadsnap 10
set dot10 [dot]
xschem redraw
check "S0 the dot-size observable answers and is the same from set_snap and from draw()" \
    [list [string is double -strict $dot10] [dot]] [list 1 $dot10]
set want16 [expr {$dot10 * 1.6}]
set want14 [expr {$dot10 * 1.4}]
check "S0b distinctness: the dot size at snap 16 ($want16) and 14 ($want14) differ from 10 ($dot10)\
       by far more than the comparison tolerance" \
    [expr {abs($want16 - $dot10) > 1.0 && abs($want14 - $dot10) > 1.0 && abs($want16 - $want14) > 0.5}] 1

# S1a: inside `xschem set cadsnap 16`, set_snap() reads the old value (filling the cache),
# writes 16, then set_dotsize_from_snap() reads again. The trace and tclsetcadsnap() each make
# that second read fresh, so this row is a plain behaviour row, not either one's fence.
xschem set cadsnap 10
xschem set cadsnap 16
check "S1a a write then a read inside ONE xschem command sees the new value (dot [dot], want $want16)" \
    [near [dot] $want16] 1
check "S1b and the Tcl variable holds what was set" $::cadsnap 16

# S1: a Tcl write in the MIDDLE of one C command, which only the write trace can see.
# `xschem align` reads the snap (filling the cache), then reads ::autotrim_wires, then draw()
# reads the snap again for the dot size. A read trace on ::autotrim_wires writes ::cadsnap from
# Tcl right there: no `xschem` entry and no C writer in between.
proc s1_mid {to args} {
    trace remove variable ::autotrim_wires read [list s1_mid $to]
    set ::cadsnap $to
}
proc s1_align {to} {
    xschem set cadsnap 10
    trace add variable ::autotrim_wires read [list s1_mid $to]
    xschem align
    catch {trace remove variable ::autotrim_wires read [list s1_mid $to]}
    return [list $::cadsnap [dot]]
}
set r [s1_align 16]
check "S1 a Tcl write to ::cadsnap from a read trace in the middle of xschem align reaches the dot\
       size draw() computes later in the same command (var [lindex $r 0], dot [lindex $r 1],\
       want $want16)" [list [lindex $r 0] [near [lindex $r 1] $want16]] {16 1}
set r [s1_align 10]
check "S1c control: the same align with no change of snap gives the dot size at 10\
       (dot [lindex $r 1], want $dot10)" [near [lindex $r 1] $dot10] 1

# S2: a write trace added AFTER the cache's own runs FIRST (Tcl runs the newest trace first),
# so when its body enters C the cache's trace has not dropped the cache yet. The body's
# `xschem redraw` reads the snap without writing it. The write here is made at top level, so
# the previous command's exit drop (invalidation 4) has already emptied the cache as well as
# the entry drop (invalidation 2): S2b below is the one only the entry drop can pass.
xschem set cadsnap 10
set ::s2_dot ERR
proc s2_trace {args} { xschem redraw; set ::s2_dot [dot] }
trace add variable ::cadsnap write s2_trace
set ::cadsnap 16
trace remove variable ::cadsnap write s2_trace
check "S2 a later write trace whose body redraws sees the new value (dot $::s2_dot, want $want16)" \
    [near $::s2_dot $want16] 1

# S2b: S2's newer write trace, fired by a Tcl write in the MIDDLE of `xschem align` (S1's read
# trace on ::autotrim_wires), after align's own first snap read has filled the cache at 10.
# Neither the cache's trace (older, so it runs second) nor any exit drop has run when the
# body's nested `xschem redraw` reads the snap: only the drop on that command's entry does.
# Legs: the newer trace fired once, the variable holds 16, the nested redraw saw 16.
xschem set cadsnap 10
set ::s2b_dot ERR; set ::s2b_n 0
proc s2b_trace {args} { incr ::s2b_n; xschem redraw; set ::s2b_dot [dot] }
trace add variable ::cadsnap write s2b_trace
trace add variable ::autotrim_wires read [list s1_mid 16]
xschem align
catch {trace remove variable ::autotrim_wires read [list s1_mid 16]}
trace remove variable ::cadsnap write s2b_trace
check "S2b a later write trace fired in the middle of xschem align, whose body redraws, sees the new\
       value (trace fired $::s2b_n, var $::cadsnap, dot $::s2b_dot, want $want16)" \
    [list $::s2b_n $::cadsnap [near $::s2b_dot $want16]] {1 16 1}

# S3: an unset takes every trace with the variable; the next real read must re-install the
# cache's, or the S1 shape goes stale from then on.
xschem set cadsnap 10
unset ::cadsnap
set ::cadsnap 10
set r [s1_align 16]
check "S3 after unset + recreate, the S1 mid-command write is still seen (var [lindex $r 0],\
       dot [lindex $r 1], want $want16)" [list [lindex $r 0] [near [lindex $r 1] $want16]] {16 1}
# S3b: the first read after the unset finds no variable at all (the uncached path).
xschem set cadsnap 10
unset ::cadsnap
xschem set cadsnap 14
check "S3b with the variable missing at the first read, the later write and read are still fresh\
       (dot [dot], want $want14)" [near [dot] $want14] 1
check "S3c and the variable exists again with the value set" \
    [list [info exists ::cadsnap] [expr {[info exists ::cadsnap] ? $::cadsnap : {}}]] {1 14}

# S4: a drag after every kind of change. Fixture: RA's M pin at (0,30); a wire ending at
# (0,37), 7 units off it. It follows the device only when cadsnap/2 >= 7.
proc s4_page {} {
    xschem clear force
    set ::enable_stretch 1; set ::orthogonal_wiring 1; set ::cadence_compat 1
    set ::autotrim_wires 1; set ::fluid_editing 1; set ::unselect_partial_sel_wires 0
    xschem instance devices/res 0 0 0 0 {name=RA m=1 value=1k}
    xschem wire 0 37 0 100
    xschem wire 0 100 60 100
}
proc s4_drag {} {
    s4_page
    xschem unselect_all
    xschem select instance 0
    xschem move_objects 40 0 stretch kissing
    return [segs]
}
xschem set cadsnap 10
set geo10 [s4_drag]
xschem set cadsnap 20
set geo20 [s4_drag]
check "S4 distinctness: the drag result at snap 10 and at snap 20 differ ({$geo10} vs {$geo20})" \
    [expr {$geo10 ne $geo20}] 1
check "S4a at snap 20 the 7-off wire followed the device" [expr {{40 37 40 100} in $geo20}] 1
check "S4b at snap 10 it stayed put" [expr {{0 37 0 100} in $geo10}] 1

# each path row stands on its own: the wire that tells the two snaps apart must be where
# the NEW snap puts it, and the whole result must equal that snap's reference drag
proc s4_judge {to} {
    set g [s4_drag]
    set mark [expr {$to == 20 ? {40 37 40 100} : {0 37 0 100}}]
    set ref  [expr {$to == 20 ? $::geo20 : $::geo10}]
    if {$mark in $g && $g eq $ref} { return ok }
    return $g
}
proc s4_upvar {v} { upvar #0 cadsnap c; set c $v }
set paths {
    plainset   {set ::cadsnap %V}
    xschemset  {xschem set cadsnap %V}
    upvar      {s4_upvar %V}
    uplevel0   {uplevel #0 {set cadsnap %V}}
    statusbar  {set ::cadsnap %V; xschem set cadsnap $::cadsnap}
}
foreach {name tmpl} $paths {
    foreach {from to} {10 20 20 10} {
        xschem set cadsnap $from
        s4_drag                                   ;# primes any cache at the old value
        uplevel #0 [string map [list %V $to] $tmpl]
        check "S4 $name $from -> $to: the next drag uses the new snap" [s4_judge $to] ok
    }
}
xschem set cadsnap 10
s4_drag
xschem snap double
check "S4 xschem snap double 10 -> 20: the next drag uses the new snap ($::cadsnap)" [s4_judge 20] ok
xschem snap half
check "S4 xschem snap half 20 -> 10: the next drag uses the new snap ($::cadsnap)" [s4_judge 10] ok

# S5: the value is parsed exactly as tclgetdoublevar() parses it, not cached as a string.
set ::cadsnap 15
xschem redraw
set dot15 [dot]
set ::cadsnap 1.5e1
xschem redraw
check "S5 a non-normalised spelling (1.5e1) reads as the number it spells (dot [dot] vs $dot15 at 15)" \
    [list [near [dot] $dot15] [near $dot15 $dot10]] {1 0}
xschem set cadsnap 10

# S6: a write made INSIDE another write trace on ::cadsnap fires no trace at all (Tcl disables
# every trace on a variable while one of them runs), so neither invalidation 1 nor 2 sees it.
# The user's trace is made OLDER than the cache's: unset takes the cache's trace away, the
# user's goes on, and a read-only C read (`xschem align` on the grid-aligned S4 page)
# re-installs the cache's, newest. Then `xschem set cadsnap 16` (set_snap, C) fires: the
# cache's trace drops the cache, the user's runs a nested `xschem set cadsnap 12` (whose own
# write fires nothing) and then rewrites ::cadsnap to 14 (fires nothing). Both set_snap calls
# write and then read the snap back for the dot size, so each must see its own write.
set want12 [expr {$dot10 * 1.2}]
set ::s6_inner ERR
proc s6_trace {args} {
    trace remove variable ::cadsnap write s6_trace
    xschem set cadsnap 12
    set ::s6_inner [dot]
    set ::cadsnap 14
}
unset ::cadsnap
set ::cadsnap 10
trace add variable ::cadsnap write s6_trace
xschem align
xschem set cadsnap 16
check "S6 inside an older write trace, a nested xschem set cadsnap 12 reads its own write back\
       (dot $::s6_inner, want $want12)" [near $::s6_inner $want12] 1
check "S6b after the trace rewrote ::cadsnap to 14 with traces off, the outer set_snap reads 14\
       (var $::cadsnap, dot [dot], want $want14)" [list $::cadsnap [near [dot] $want14]] {14 1}
check "S6c distinctness: the dot size at 12 ($want12), 14 ($want14) and 16 ($want16) differ" \
    [expr {abs($want12-$want14) > 0.5 && abs($want14-$want16) > 0.5 && abs($want12-$want16) > 0.5}] 1
xschem set cadsnap 10

# S7 (invalidation 4, the drop on xschem's way OUT). A user write trace made OLDER than the
# cache's (unset takes the cache's away, the user's is added, and a read re-installs the
# cache's, newest) runs AFTER the cache's trace has dropped the cache. Its body's `xschem
# redraw` reads the snap and so refills the cache, then the body writes 20, which fires no
# trace because one on ::cadsnap is running. The outer write is a Tcl write in the MIDDLE of a
# stretch drag (a read trace on ::fluid_editing, which the drag pipeline reads), so no
# `xschem` entry and no C writer follow before the drag's next snap read. The observable is
# S4's: at 20 the 7-off wire follows the device. Legs: both traces fired once, the variable
# holds the rewrite, and the drag result is S4's snap-20 reference.
set ::s7_user 0; set ::s7_mid 0
proc s7_user {args} { incr ::s7_user; catch {xschem redraw}; set ::cadsnap 20 }
proc s7_mid {args} {
    incr ::s7_mid
    trace remove variable ::fluid_editing read s7_mid
    set ::cadsnap 10
}
xschem set cadsnap 10
s4_page; xschem unselect_all; xschem select instance 0
unset ::cadsnap; set ::cadsnap 10
trace add variable ::cadsnap write s7_user
xschem redraw
trace add variable ::fluid_editing read s7_mid
xschem move_objects 40 0 stretch kissing
catch {trace remove variable ::fluid_editing read s7_mid}
trace remove variable ::cadsnap write s7_user
set g [segs]
check "S7 an older write trace that redraws and then rewrites ::cadsnap to 20, fired by a Tcl write\
       in the middle of a stretch drag: the rest of the drag uses 20 (mid-drag trace fired\
       $::s7_mid, older trace fired $::s7_user, var $::cadsnap, wires {$g}, want {$::geo20})" \
    [list $::s7_mid $::s7_user $::cadsnap [expr {{40 37 40 100} in $g && $g eq $::geo20}]] {1 1 20 1}
xschem set cadsnap 10

# S8 (arm AFTER the read). A READ trace on ::cadsnap that unsets and recreates it at 12 fires
# inside the cache's own Tcl_GetVar, the first snap read of `xschem align`. The unset takes the
# cache's write trace with it; armed before the read, the cache would hold 12 with no trace on
# the variable. S1's mid-command write of 16 (a read trace on ::autotrim_wires) then follows,
# and draw() reads the snap for the dot size later in the same command. Legs: the read trace
# fired once, the variable holds 16, the dot size is 16's (S6c shows 12, 14 and 16 apart).
# ON THE DISPLAY ARM THIS ROW CANNOT SEE ITS DEFECT, and neither can S1: with a window, align's
# draw runs nested `xschem get schname` / `xschem get current_win_path` commands between the
# mid-command write and the dot-size read, and their entry and exit drops make that read fresh
# on any build. Measured with copies broken on purpose: without the read-then-arm order S8 is
# red here headless and passes on a display. The suite is in `hcases` alone, so T1 runs it on
# the arm where it is red.
set ::s8_rd 0
proc s8_rd {args} {
    incr ::s8_rd
    trace remove variable ::cadsnap read s8_rd
    unset ::cadsnap
    set ::cadsnap 12
}
xschem clear force
xschem set cadsnap 10
xschem redraw
trace add variable ::cadsnap read s8_rd
trace add variable ::autotrim_wires read [list s1_mid 16]
xschem align
catch {trace remove variable ::autotrim_wires read [list s1_mid 16]}
catch {trace remove variable ::cadsnap read s8_rd}
check "S8 a read trace on ::cadsnap that unsets and recreates it inside the cache's own read does not\
       leave it cached and untraced: the mid-command write of 16 still reaches the dot size\
       (read trace fired $::s8_rd, var $::cadsnap, dot [dot], want $want16)" \
    [list $::s8_rd $::cadsnap [near [dot] $want16]] {1 16 1}
xschem set cadsnap 10

# S9 (never arm on a missing variable). After `unset ::cadsnap`, `xschem align` makes its
# unconditional snap read of a variable that is not there. Arming the trace on that name would
# leave an undefined-but-traced ::cadsnap, and Tcl refuses a traced name as an upvar alias, so
# `upvar #0 s9_snap cadsnap` -- which succeeds with no cache -- would fail. Legs: align does
# read the snap (counted with it present, so the read under test is not vacuous), the upvar
# succeeds, and the next drag uses the alias's 20.
# THE LAST ROW, ON PURPOSE: a global upvar link cannot be undone, so ::cadsnap stays an alias of
# ::s9_snap for the rest of this interpreter.
set ::s9_reads 0
proc s9_rd {args} { incr ::s9_reads }
xschem clear force
xschem set cadsnap 10
trace add variable ::cadsnap read s9_rd
xschem align
trace remove variable ::cadsnap read s9_rd
unset ::cadsnap
xschem align
set ::s9_snap 20
set s9_rc [catch {uplevel #0 {upvar #0 s9_snap cadsnap}} s9_err]
set s9_judge [s4_judge 20]
check "S9 after unset ::cadsnap and a C read of it, upvar #0 s9_snap cadsnap succeeds and the next\
       drag uses the alias (align read ::cadsnap $::s9_reads time(s) with it present; upvar rc\
       $s9_rc said {$s9_err}; drag {$s9_judge})" \
    [list [expr {$::s9_reads >= 1}] $s9_rc $s9_judge] {1 0 ok}

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

# `OVERALL: ok` is the completion sentinel tests/banner_rule.tcl's banner_complete requires
# (issue 1652); `RESULT:` stays LAST because summarize_all publishes a case's last RESULT line.
if {$fail == 0} { puts "OVERALL: ok ($npass checks)"
                  puts "RESULT: ALL PASS ($npass checks)" } \
else            { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
