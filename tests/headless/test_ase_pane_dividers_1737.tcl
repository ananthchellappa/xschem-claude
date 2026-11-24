# tests/headless/test_ase_pane_dividers_1737.tcl -- the dividers between the
# ASE-L window's three panes can be dragged (issue 1737).
#
# The user, 2026-11-24: "The dividers (or separators, whatever the technical
# name is) in ASE-L - between the various panes - variables, analyses, outputs,
# are not moveable as they are in Cadence ADE-L. We'd like to be able to adjust
# - sometimes, you'd like to trade size of the analyses pane (vertically) to
# see more outputs (measures), etc."
#
# Spec     doc/claude/specs/ase_l.md, section "Panes", rules R-PANE1..R-PANE8
# Issue    doc/claude/issues/1737-*.md
# Code     src/ase_window.tcl ase::ui::pane_layout, ase::ui::pane_add,
#          ase::ui::pane_sizes, ase::ui::pane_reseed, ase::ui::pane_frac_of,
#          ase::ui::pane_pos_of, ase::ui::pane_drop, ase::ui::pane_min,
#          ase::ui::pane_bounds, ase::ui::pane_restore, ase::ui::pane_place,
#          and the Panedwindow arm of ase::ui::_theme_widget
#
# Bands (counted arm -- pure procs, no Tk):
#   PF   the arithmetic of a split: a divider's place as a fraction of the room
#        and back, the bounds, and what is refused
# Bands (display arm -- each prints one skip: line under --nogui):
#   PD0  before any drag the window is laid out as the grid laid it out: every
#        pane the size it asks for, the gaps twice the margin, the panes above
#        the paned windows that manage them
#   PD1  the Analyses/Outputs divider dragged up: Analyses shorter and Outputs
#        taller by the drag, and that many more Outputs rows in view
#   PD2  the left/right divider dragged: Design Variables wider, the two panes
#        at its right narrower and moved
#   PD3  the pointer over a divider is the double arrow of its direction
#   PD4  a press and release with no motion moves nothing, stores nothing and
#        changes no selection
#   PD5  what the user does next leaves the dividers where they are: rows added,
#        the Saves tab and back, the theme applied again, a state loaded and
#        reverted; a window resize keeps the proportions; a font-size change
#        keeps them and moves the bounds
#   PD6  a drag far past a bound stops where the pane still shows its title, its
#        headings and its first row whole; the drag back; nothing keeps moving
#   PD7  many drag cycles leave every column of the three tables at its width
#   PD8  the split is remembered for the session: the window closed and opened
#        again comes back with it; another session has the default; only the
#        divider that was dragged is remembered; the records of a closed window
#        are gone
#   PD9  the theme walk paints the paned windows from the palette
#   PD10 an untouched window still follows a font-size change, as the grid did:
#        every pane again the size it asks for
#   PD11 the Saves tab's tree takes the Outputs pane's size
#
# Every drag is a generated button-1 press, pointer motion and release at the
# divider's own coordinates on the paned window, so the class bindings of Tk do
# the moving; no row calls the product's handlers. Every size is read off the
# widgets after the event loop has settled.
#
# SABOTAGE, each measured on the display arm (the bands whose rows went red):
#   A  ase::ui::pane_layout without the two `lower` lines
#        -> PD0, the stacking row alone. The drags stay green: a generated
#        event addresses the paned window by name, hidden panes or not
#   B  the four panes added with `-stretch never` in ase::ui::pane_add
#        -> PD5 (both window resizes, both font rows), PD8 (the reopened window)
#   C  the sash made wider than twice the pad in ase::ui::pane_layout
#        -> PD0 (the gaps)
#   D  ase::ui::pane_bounds without its four -minsize lines
#        -> PD6 (every stop and the drag back), PD5 (the bounds after a font
#        change)
#   E  ase::ui::pane_drop without its "moved nothing" return
#        -> PD4 (two clicks in a window nobody dragged in stored a split)
#   F  ase::ui::pane_drop storing the pixel position, not the fraction
#        -> PD1 (what is remembered), PD5 (the resizes, the font rows), PD8
#        (both reopened windows: a pixel count is refused as a fraction, so
#        nothing is put back)
#   G  the remembered split dropped in ase::ui::close
#        -> PD8 (after the close, and both reopened windows)
#   H  the Panedwindow arm of ase::ui::_theme_widget without its configure
#        -> PD9
#   I  -sashcursor left out of ase::ui::pane_layout
#        -> PD3, the option row alone. Tk shows a double arrow over a sash by
#        itself, so the pointer row cannot tell the two apart
#   J  ase::ui::pane_reseed returning at once
#        -> PD10 (the window no longer follows the font), PD5 (the bounds
#        after a font change)
#   K  ase::ui::pane_pos_of without its two clamps -> PF, on both arms
#   L  ase::ui::pane_sizes ignoring the remembered split
#        -> PD5 (both font rows)
# Against the product without the change the suite is red on both arms: every
# PF row, and every PD band abandoned.
#
# REGISTERED IN BOTH LISTS: the PD bands need a display.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_pane_dividers_1737
#   tests/headless/run_suites.sh test_ase_pane_dividers_1737

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:[string map [list \{ ( \} )] $r]" }
    return $r
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
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set scratch [test_scratch ase_pane_dividers]

# =============================================================================
# PF -- THE ARITHMETIC OF A SPLIT
# =============================================================================
group PF {
    check "PF a divider's place is its share of the room" \
        [list [pcall ase::ui::pane_frac_of 100 400] [pcall ase::ui::pane_frac_of 300 400]] {0.25 0.75}
    check "PF a place that leaves a pane with nothing, no room, and text are no split: 0" \
        [lmap {p r} {0 400 400 400 -3 400 500 400 10 1 10 0 abc 400 10 {}} {pcall ase::ui::pane_frac_of $p $r}] \
        {0 0 0 0 0 0 0 0}
    check "PF a fraction puts the divider back at its place" \
        [list [pcall ase::ui::pane_pos_of 0.25 400] [pcall ase::ui::pane_pos_of 0.75 400] \
              [pcall ase::ui::pane_pos_of 0.5 401]] {100 300 201}
    set bad {}
    set walked 0
    foreach room {2 3 37 422 709 1915} {
        for {set p 1} {$p < $room} {incr p} {
            incr walked
            set f [pcall ase::ui::pane_frac_of $p $room]
            if {[pcall ase::ui::pane_pos_of $f $room] ne $p} { lappend bad "$p/$room" }
        }
    }
    check "PF every place of every room walked survives the round trip through its fraction (places walked, first that did not)" \
        [list [expr {$walked > 0}] [lrange $bad 0 4]] {1 {}}
    check "PF the pane before the divider is not put under its smallest size, nor the pane after it" \
        [list [pcall ase::ui::pane_pos_of 0.01 400 60 80] [pcall ase::ui::pane_pos_of 0.99 400 60 80] \
              [pcall ase::ui::pane_pos_of 0.5 400 60 80]] {60 320 200}
    check "PF a room too small for both smallest sizes: the pane before the divider keeps its own" \
        [pcall ase::ui::pane_pos_of 0.5 100 80 80] 80
    check "PF what is not a fraction strictly between 0 and 1, and a room that is none, answer -1" \
        [lmap {f r} {0 400 1 400 1.5 400 -0.2 400 abc 400 {} 400 0.5 1 0.5 0 0.5 abc 141 400} {pcall ase::ui::pane_pos_of $f $r}] \
        {-1 -1 -1 -1 -1 -1 -1 -1 -1 -1}
    check "PF a session nobody dragged a divider in remembers nothing" \
        [pcall ase::ui::pane_split {no/such/session}] {}
}

# =============================================================================
# PD -- THE WINDOW (display arm)
# =============================================================================
proc pd_settle {} {
    update
    after 200 {set ::pd_go 1}
    vwait ::pd_go
    update
}
proc pd_box {w} { return [list [winfo width $w] [winfo height $w] [winfo x $w] [winfo y $w]] }
proc pd_geom {top} {
    return [list [pd_box $top.body.vars] [pd_box $top.body.ana] [pd_box $top.body.outs]]
}
# where each divider stands, in pixels: {left/right up/down}
proc pd_at {top} {
    return [list [lindex [$top.body.h sash coord 0] 0] [lindex [$top.body.v sash coord 0] 1]]
}
# a real drag of the paned window's divider by `d` pixels along its direction
proc pd_drag {pw d} {
    lassign [$pw sash coord 0] sx sy
    set half [expr {[winfo pixels $pw [$pw cget -sashwidth]] / 2}]
    if {[$pw cget -orient] eq {horizontal}} {
        set px [expr {$sx + $half}]; set py [expr {[winfo height $pw] / 2}]
        set dx $d; set dy 0
    } else {
        set px [expr {[winfo width $pw] / 2}]; set py [expr {$sy + $half}]
        set dx 0; set dy $d
    }
    event generate $pw <Motion> -x $px -y $py
    event generate $pw <ButtonPress-1> -x $px -y $py
    foreach step {0.25 0.5 0.75 1.0} {
        event generate $pw <B1-Motion> -x [expr {int($px + $dx * $step)}] -y [expr {int($py + $dy * $step)}]
        update
    }
    event generate $pw <ButtonRelease-1> -x [expr {$px + $dx}] -y [expr {$py + $dy}]
    pd_settle
}
proc pd_click {pw} {
    lassign [$pw sash coord 0] sx sy
    set half [expr {[winfo pixels $pw [$pw cget -sashwidth]] / 2}]
    if {[$pw cget -orient] eq {horizontal}} {
        set px [expr {$sx + $half}]; set py [expr {[winfo height $pw] / 2}]
    } else {
        set px [expr {[winfo width $pw] / 2}]; set py [expr {$sy + $half}]
    }
    event generate $pw <Motion> -x $px -y $py
    event generate $pw <ButtonPress-1> -x $px -y $py
    event generate $pw <ButtonRelease-1> -x $px -y $py
    pd_settle
}
proc pd_rows_in_view {tv} {
    set n 0
    foreach id [$tv children {}] { if {[$tv bbox $id] ne {}} { incr n } }
    return $n
}
proc pd_cols {top} {
    set out {}
    foreach pane {vars ana outs} {
        set tv $top.body.$pane.tv
        lappend out [lmap c [$tv cget -columns] {$tv column $c -width}]
    }
    return $out
}
proc pd_state_file {tag} {
    set sp [file join $::scratch $tag.state]
    set st [ase::state_default]
    dict set st design [dict create lib pdlib cell $tag view schematic]
    dict set st rundir $::scratch
    dict set st variables {{name Vgs value 1.8} {name Vds value 1.0} {name Ib value 10u}}
    set outs {}
    for {set i 0} {$i < 24} {incr i} { lappend outs [dict create name m$i expr vdc(n$i) save 0 plot 0] }
    lappend outs [dict create expr v(s1) save 1 plot 0] [dict create expr v(s2) save 1 plot 0]
    dict set st outputs $outs
    ase::state_save $sp $st
    return $sp
}
proc pd_open {tag} {
    set key [ase::session_key pdlib $tag pd_state]
    ase::session_open $key [pd_state_file $tag]
    set top [ase::ui::open $key pdlib $tag pd_state]
    pd_settle
    return [list $key $top]
}
# is the divider of `pw` within two pixels of where its remembered fraction
# puts it in the room the paned window has now
# are two pane geometries within two pixels of each other, figure for figure
proc pd_near {a b} {
    foreach p $a q $b { foreach x $p y $q { if {abs($x - $y) > 2} { return 0 } } }
    return 1
}
proc pd_holds {pw frac} {
    set want [ase::ui::pane_pos_of $frac [ase::ui::pane_room $pw]]
    set got [ase::ui::pane_at $pw]
    return [expr {$want > 0 && abs($got - $want) <= 2}]
}

set PD_BANDS {PD0 PD1 PD2 PD3 PD4 PD5 PD6 PD7 PD8 PD9 PD10 PD11}
if {![info exists ::has_x] || [info commands winfo] eq {}} {
    foreach b $PD_BANDS { puts "skip: $b needs a display (the window band runs on the display arm)" }
} else {
    set key {}; set top {}
    set PD_KNOB_HAD [info exists ::ase_font_size]
    set PD_KNOB_WAS [expr {$PD_KNOB_HAD ? $::ase_font_size : {}}]
    group PD0 {
        lassign [pd_open bench1] key top
        set h $top.body.h; set v $top.body.v
        set rh [ttk::style lookup Ase.Treeview -rowheight]
        check "PD0 the row height the drags below are counted in is a positive number" [expr {[string is integer -strict $rh] && $rh > 0}] 1
        check "PD0 the three panes and the Saves frame are children of the body under the paths every reader uses" \
            [lmap p {vars ana outs saves} {list [winfo exists $top.body.$p] [winfo parent $top.body.$p]}] \
            [lrepeat 4 [list 1 $top.body]]
        set kids [winfo children $top.body]
        set ih [lsearch -exact $kids $h]; set iv [lsearch -exact $kids $v]
        set above 1
        foreach p {vars ana outs saves} { if {[lsearch -exact $kids $top.body.$p] <= $iv} { set above 0 } }
        check "PD0 stacking: the paned windows are at the bottom, the one that holds the other lowest, every pane above both" \
            [list [expr {$ih >= 0}] [expr {$ih < $iv}] $above] {1 1 1}
        check "PD0 each tree is mapped and viewable" \
            [lmap p {vars ana outs} {list [winfo ismapped $top.body.$p.tv] [winfo viewable $top.body.$p.tv]}] {{1 1} {1 1} {1 1}}
        lassign [pd_geom $top] gv ga go
        set G0 [pd_geom $top]
        set W0 [list [winfo width $top] [winfo height $top]]
        lassign $gv vw vh vx vy; lassign $ga aw ah ax ay; lassign $go ow oh ox oy
        set rightreq [expr {max([winfo reqwidth $top.body.ana], [winfo reqwidth $top.body.outs])}]
        check "PD0 before any drag each pane has the size it asks for, as under the grid: Design Variables its width, Analyses and Outputs their heights and the wider one's width" \
            [list $vw $ah $oh $aw $ow] \
            [list [winfo reqwidth $top.body.vars] [winfo reqheight $top.body.ana] [winfo reqheight $top.body.outs] $rightreq $rightreq]
        set gapx [expr {$ax - ($vx + $vw)}]; set gapy [expr {$oy - ($ay + $ah)}]
        check "PD0 the gap between two panes, across and down, is twice the margin around them, as the grid's pads made it" \
            [list [expr {$vx > 0}] $gapx $gapy] [list 1 [expr {2 * $vx}] [expr {2 * $vy}]]
        check "PD0 Design Variables spans the height of the two panes at its right and their gap" $vh [expr {$ah + $gapy + $oh}]
        check "PD0 the window is the size it asks for" $W0 [list [winfo reqwidth $top] [winfo reqheight $top]]
        check "PD0 no split is remembered for a session nobody dragged in" [ase::ui::pane_split $key] {}
    }
    group PD1 {
        set tv $top.body.outs.tv
        set total [llength [$tv children {}]]
        set n0 [pd_rows_in_view $tv]
        lassign [pd_geom $top] gv ga go
        pd_drag $top.body.v [expr {-3 * $rh}]
        lassign [pd_geom $top] hv ha ho
        check "PD1 the Outputs rows overflow the pane before the drag (rows, rows in view)" [expr {$total > $n0 && $n0 > 0}] 1
        check "PD1 the divider dragged up by three rows: Analyses that much shorter, Outputs that much taller and that much higher up" \
            [list [expr {[lindex $ga 1] - [lindex $ha 1]}] [expr {[lindex $ho 1] - [lindex $go 1]}] [expr {[lindex $go 3] - [lindex $ho 3]}]] \
            [list [expr {3 * $rh}] [expr {3 * $rh}] [expr {3 * $rh}]]
        check "PD1 ...the widths, Analyses' place and Design Variables are as they were" \
            [list [lindex $ha 0] [lindex $ho 0] [lindex $ha 2] [lindex $ha 3] $hv] \
            [list [lindex $ga 0] [lindex $go 0] [lindex $ga 2] [lindex $ga 3] $gv]
        check "PD1 ...and three more Outputs rows are in view" [expr {[pd_rows_in_view $tv] - $n0}] 3
        check "PD1 the session remembers that divider, as a fraction, and not the other" \
            [list [dict keys [ase::ui::pane_split $key]] \
                  [expr {[dict get [ase::ui::pane_split $key] v] > 0 && [dict get [ase::ui::pane_split $key] v] < 1}]] {v 1}
    }
    group PD2 {
        lassign [pd_geom $top] gv ga go
        set d [expr {6 * [font measure AseEntryFont 0]}]
        pd_drag $top.body.h $d
        lassign [pd_geom $top] hv ha ho
        check "PD2 the pixels dragged are a positive number" [expr {$d > 0}] 1
        check "PD2 the left/right divider dragged right: Design Variables that much wider" [expr {[lindex $hv 0] - [lindex $gv 0]}] $d
        check "PD2 ...Analyses and Outputs that much narrower and that much further right" \
            [list [expr {[lindex $ga 0] - [lindex $ha 0]}] [expr {[lindex $go 0] - [lindex $ho 0]}] \
                  [expr {[lindex $ha 2] - [lindex $ga 2]}] [expr {[lindex $ho 2] - [lindex $go 2]}]] [list $d $d $d $d]
        check "PD2 ...every height and vertical place as it was" \
            [list [lindex $hv 1] [lindex $ha 1] [lindex $ho 1] [lindex $ha 3] [lindex $ho 3]] \
            [list [lindex $gv 1] [lindex $ga 1] [lindex $go 1] [lindex $ga 3] [lindex $go 3]]
        check "PD2 the session now remembers both dividers" [lsort [dict keys [ase::ui::pane_split $key]]] {h v}
    }
    group PD3 {
        lassign [$top.body.h sash coord 0] sx sy
        event generate $top.body.h <Motion> -x [expr {$sx + 1}] -y [expr {[winfo height $top.body.h] / 2}]
        update
        set ch [$top.body.h cget -cursor]
        lassign [$top.body.v sash coord 0] sx sy
        event generate $top.body.v <Motion> -x [expr {[winfo width $top.body.v] / 2}] -y [expr {$sy + 1}]
        update
        check "PD3 the pointer over a divider is the double arrow of its direction: across for the left/right one, up and down for the other" \
            [list $ch [$top.body.v cget -cursor]] {sb_h_double_arrow sb_v_double_arrow}
        check "PD3 ...and each paned window names that cursor for its divider itself" \
            [list [$top.body.h cget -sashcursor] [$top.body.v cget -sashcursor]] {sb_h_double_arrow sb_v_double_arrow}
    }
    group PD4 {
        set tv $top.body.vars.tv
        $tv selection set [lindex [$tv children {}] 0]
        pd_settle
        set sel0 [$tv selection]
        set g0 [pd_geom $top]; set s0 [ase::ui::pane_split $key]
        pd_click $top.body.v
        pd_click $top.body.h
        check "PD4 a row is selected before the clicks" [expr {[llength $sel0] > 0}] 1
        check "PD4 a press and release on each divider with no motion: no pane moved, the remembered split is the same, the selection is the same" \
            [list [expr {[pd_geom $top] eq $g0}] [expr {[ase::ui::pane_split $key] eq $s0}] [$tv selection]] [list 1 1 $sel0]
        # the same on a window nobody dragged in: a click must not turn the default into a remembered split
        lassign [pd_open bench4] k4 t4
        pd_click $t4.body.v
        pd_click $t4.body.h
        check "PD4 ...and in a window nobody dragged in, the two clicks leave nothing remembered" [ase::ui::pane_split $k4] {}
        ase::ui::close $k4
        pd_settle
    }
    group PD5 {
        set G [pd_geom $top]
        set fh [dict get [ase::ui::pane_split $key] h]; set fv [dict get [ase::ui::pane_split $key] v]
        # rows added: the model door every dialog ends in, and the repaint
        set st [ase::session_state $key]
        set vars [ase::state_get $st variables]
        for {set i 0} {$i < 40} {incr i} { lappend vars [dict create name extra$i value $i] }
        dict set st variables $vars
        set outs [ase::state_get $st outputs]
        for {set i 0} {$i < 5} {incr i} { lappend outs [dict create name more$i expr vdc(q$i) save 0 plot 0] }
        dict set st outputs $outs
        ase::session_update $key $st
        ase::ui::populate $key
        pd_settle
        check "PD5 rows added to Design Variables and to Outputs (the variables now overflow their pane): no pane moved" \
            [list [expr {[llength [$top.body.vars.tv children {}]] > [pd_rows_in_view $top.body.vars.tv]}] [expr {[pd_geom $top] eq $G}]] {1 1}
        $top.body.outs.tabs.s invoke
        pd_settle
        check "PD5 the Saves tab pressed: it is in front, and no pane moved" \
            [list [ase::ui::outputs_tab $key] [expr {[pd_geom $top] eq $G}]] {saves 1}
        $top.body.outs.tabs.m invoke
        pd_settle
        check "PD5 ...and Measures again: no pane moved" [list [ase::ui::outputs_tab $key] [expr {[pd_geom $top] eq $G}]] {measures 1}
        ase::ui::apply_theme $top
        pd_settle
        check "PD5 the theme applied again: no pane moved" [expr {[pd_geom $top] eq $G}] 1
        ase::session_save $key
        ase::ui::load_state $key
        pd_settle
        check "PD5 the state loaded again: no pane moved" [expr {[pd_geom $top] eq $G}] 1
        ase::ui::revert_state $key
        pd_settle
        check "PD5 ...and reverted: no pane moved" [expr {[pd_geom $top] eq $G}] 1
        # a window resize keeps the proportions
        set w [winfo width $top]; set ht [winfo height $top]
        wm geometry $top [expr {$w + 320}]x[expr {$ht + 210}]
        pd_settle
        check "PD5 the window made larger: it is larger, and each divider is where its fraction puts it in the larger room" \
            [list [expr {[winfo width $top] > $w && [winfo height $top] > $ht}] [pd_holds $top.body.h $fh] [pd_holds $top.body.v $fv]] {1 1 1}
        check "PD5 ...both panes of each divider took part of the growth" \
            [list [expr {[lindex [pd_geom $top] 0 0] > [lindex $G 0 0]}] [expr {[lindex [pd_geom $top] 1 0] > [lindex $G 1 0]}] \
                  [expr {[lindex [pd_geom $top] 1 1] > [lindex $G 1 1]}] [expr {[lindex [pd_geom $top] 2 1] > [lindex $G 2 1]}]] {1 1 1 1}
        wm geometry $top [expr {$w - 150}]x[expr {$ht - 90}]
        pd_settle
        check "PD5 the window made smaller than it was: each divider is where its fraction puts it in the smaller room" \
            [list [expr {[winfo width $top] < $w && [winfo height $top] < $ht}] [pd_holds $top.body.h $fh] [pd_holds $top.body.v $fv]] {1 1 1}
        wm geometry $top ${w}x${ht}
        pd_settle
        check "PD5 the window back at its size: every pane exactly where it was" [expr {[pd_geom $top] eq $G}] 1
        check "PD5 no resize, repaint or load wrote the remembered split: only a drag does" \
            [list [dict get [ase::ui::pane_split $key] h] [dict get [ase::ui::pane_split $key] v]] [list $fh $fv]
        # a font-size change keeps the proportions and moves the bounds
        set min0 [list [$top.body.v panecget $top.body.ana -minsize] [$top.body.h panecget $top.body.vars -minsize]]
        set ::ase_font_size 16
        ase::ui::populate $key
        pd_settle
        set rh16 [ttk::style lookup Ase.Treeview -rowheight]
        check "PD5 the font size raised under the window: the rows are taller, and each divider is where its fraction puts it" \
            [list [expr {$rh16 > $rh}] [pd_holds $top.body.h $fh] [pd_holds $top.body.v $fv]] {1 1 1}
        set min16 [list [$top.body.v panecget $top.body.ana -minsize] [$top.body.h panecget $top.body.vars -minsize]]
        check "PD5 ...and the smallest sizes of the panes grew with the font, to what the panes' own widgets now give" \
            [list [expr {[lindex $min16 0] > [lindex $min0 0]}] [expr {[lindex $min16 1] > [lindex $min0 1]}] $min16] \
            [list 1 1 [list [lindex [ase::ui::pane_min $top ana] 1] [lindex [ase::ui::pane_min $top vars] 0]]]
        set ::ase_font_size 0
        ase::ui::populate $key
        pd_settle
        check "PD5 the font size put back: the rows are as tall as before, the dividers at their fractions, the smallest sizes back" \
            [list [ttk::style lookup Ase.Treeview -rowheight] [pd_holds $top.body.h $fh] [pd_holds $top.body.v $fv] \
                  [list [$top.body.v panecget $top.body.ana -minsize] [$top.body.h panecget $top.body.vars -minsize]]] \
            [list $rh 1 1 $min0]
    }
    if {$PD_KNOB_HAD} { set ::ase_font_size $PD_KNOB_WAS } else { catch {unset ::ase_font_size} }
    group PD6 {
        set h $top.body.h; set v $top.body.v
        set min [ase::ui::pane_bounds $top]
        lassign [dict get $min vars] mvw mvh; lassign [dict get $min ana] maw mah; lassign [dict get $min outs] mow moh
        set mright [expr {max($maw, $mow)}]
        check "PD6 every smallest size is a real bound: above nothing, below what the pane asks for" \
            [list [expr {$mah > 0 && $mah < [winfo reqheight $top.body.ana]}] [expr {$moh > 0 && $moh < [winfo reqheight $top.body.outs]}] \
                  [expr {$mvw > 0 && $mvw < [winfo reqwidth $top.body.vars]}] [expr {$mright > 0 && $mright < [winfo reqwidth $top.body.outs]}]] {1 1 1 1}
        pd_drag $v -3000
        set atv [$top.body.ana.tv children {}]
        lassign [$top.body.ana.tv bbox [lindex $atv 0]] bx by bw bh
        check "PD6 the Analyses/Outputs divider dragged far past the top stops with Analyses at its smallest height" [winfo height $top.body.ana] $mah
        check "PD6 ...where its title, its headings and its first row are still whole inside the pane (rows, first row inside its tree, tree inside the pane)" \
            [list [expr {[llength $atv] > 0}] [expr {$bh > 0 && $by > 0 && $by + $bh <= [winfo height $top.body.ana.tv]}] \
                  [expr {[winfo y $top.body.ana.tv] > 0 && [winfo y $top.body.ana.tv] + [winfo height $top.body.ana.tv] <= [winfo height $top.body.ana]}]] {1 1 1}
        pd_drag $v [expr {2 * $rh}]
        check "PD6 ...and it drags back: two rows down, Analyses two rows taller" [winfo height $top.body.ana] [expr {$mah + 2 * $rh}]
        pd_drag $v 3000
        set otv [$top.body.outs.tv children {}]
        lassign [$top.body.outs.tv bbox [lindex $otv 0]] bx by bw bh
        check "PD6 dragged far past the bottom it stops with Outputs at its smallest height" [winfo height $top.body.outs] $moh
        check "PD6 ...its first row still whole inside the pane" \
            [list [expr {[llength $otv] > 0}] [expr {$bh > 0 && $by > 0 && $by + $bh <= [winfo height $top.body.outs.tv]}]] {1 1}
        pd_drag $h -3000
        check "PD6 the left/right divider dragged far past the left stops with Design Variables at its smallest width" [winfo width $top.body.vars] $mvw
        check "PD6 ...which holds its title and its first column's heading" \
            [list [expr {$mvw >= [font measure [$top.body.vars cget -font] [$top.body.vars cget -text]]}] \
                  [expr {$mvw >= [$top.body.vars.tv column [lindex [$top.body.vars.tv cget -columns] 0] -minwidth]}]] {1 1}
        pd_drag $h 5000
        check "PD6 dragged far past the right it stops with the two panes at the right at their smallest width" \
            [list [winfo width $top.body.ana] [winfo width $top.body.outs]] [list $mright $mright]
        check "PD6 ...which holds the Outputs pane's two tab buttons and the Analyses title" \
            [list [expr {$mright >= [winfo reqwidth $top.body.outs.tabs]}] \
                  [expr {$mright >= [font measure [$top.body.ana cget -font] [$top.body.ana cget -text]]}]] {1 1}
        set a [list [pd_geom $top] [winfo width $top] [winfo height $top]]
        pd_settle; pd_settle
        check "PD6 at that stop nothing keeps moving: the panes and the window read the same a moment later" \
            [expr {[list [pd_geom $top] [winfo width $top] [winfo height $top]] eq $a}] 1
        check "PD6 no drag made the window itself larger or smaller" [list [winfo width $top] [winfo height $top]] $W0
    }
    group PD7 {
        set h $top.body.h
        pd_drag $h [expr {[winfo reqwidth $top.body.vars] - [winfo width $top.body.vars]}]
        set p0 [ase::ui::pane_at $h]
        set c0 [pd_cols $top]
        set cycles 0
        for {set i 0} {$i < 8} {incr i} {
            pd_drag $h -3000
            pd_drag $h 5000
            pd_drag $h [expr {$p0 - [ase::ui::pane_at $h]}]
            incr cycles
        }
        check "PD7 after drag cycles from bound to bound and back to where the divider started, it is there again (cycles made, place)" \
            [list [expr {$cycles > 0}] [ase::ui::pane_at $h]] [list 1 $p0]
        check "PD7 ...and every column of the three tables has the width it started with: nothing ratcheted" [pd_cols $top] $c0
    }
    group PD8 {
        pd_drag $top.body.v [expr {[winfo reqheight $top.body.ana] - [winfo height $top.body.ana] - 2 * $rh}]
        set G [pd_geom $top]
        set S [ase::ui::pane_split $key]
        set dead $top
        ase::ui::close $key
        pd_settle
        check "PD8 the window closed: it is gone, the split the user left is still remembered, the dead window's own records are not" \
            [list [winfo exists $dead] [expr {[ase::ui::pane_split $key] eq $S}] [lsort [dict keys $S]] \
                  [array names ::ase::ui::panearmed $dead.*] [array names ::ase::ui::panepress $dead.*]] {0 1 {h v} {} {}}
        ase::session_open $key [file join $::scratch bench1.state]
        set top [ase::ui::open $key pdlib bench1 pd_state]
        pd_settle
        set R [pd_geom $top]
        check "PD8 opened again, a new window of the same size: every pane within two pixels of where the user left it" \
            [list [expr {$top ne $dead}] [list [winfo width $top] [winfo height $top]] [pd_near $G $R]] [list 1 $W0 1]
        check "PD8 ...and it is not the default look come back" [expr {$R ne $G0}] 1
        lassign [pd_open bench2] k2 t2
        check "PD8 another session's window opens with the default look, pane for pane, and remembers nothing" \
            [list [expr {[pd_geom $t2] eq $G0}] [ase::ui::pane_split $k2]] {1 {}}
        pd_drag $t2.body.v [expr {-2 * $rh}]
        set g2 [pd_geom $t2]
        check "PD8 only the divider dragged there is remembered there, and the first session's split is untouched" \
            [list [dict keys [ase::ui::pane_split $k2]] [expr {[ase::ui::pane_split $key] eq $S}]] {v 1}
        ase::ui::close $k2
        pd_settle
        ase::session_open $k2 [file join $::scratch bench2.state]
        set t2 [ase::ui::open $k2 pdlib bench2 pd_state]
        pd_settle
        check "PD8 ...and its window opened again has that divider where it was left and the other at the default" \
            [list [pd_near [pd_geom $t2] $g2] [expr {[pd_geom $t2] ne $G0}] [lindex [pd_geom $t2] 0 0]] [list 1 1 [lindex $G0 0 0]]
        ase::ui::close $k2
        pd_settle
    }
    group PD9 {
        set panel [dict get [ase::palette] panel]
        $top.body.h configure -background #123456
        $top.body.v configure -background #123456
        ase::ui::apply_theme $top
        check "PD9 the theme walk paints both paned windows, and so the dividers, in the palette's panel colour, whatever they held" \
            [list [expr {$panel ne {#123456}}] [$top.body.h cget -background] [$top.body.v cget -background]] [list 1 $panel $panel]
        check "PD9 ...the colour the body around them has" [$top.body cget -background] $panel
    }
    group PD10 {
        lassign [pd_open bench3] k3 t3
        set before [list [winfo width $t3] [winfo height $t3]]
        set ::ase_font_size 16
        ase::ui::populate $k3
        pd_settle; pd_settle
        set rightreq [expr {max([winfo reqwidth $t3.body.ana], [winfo reqwidth $t3.body.outs])}]
        check "PD10 the font size raised under a window nobody sized or dragged in: the window grew" \
            [list [expr {[winfo width $t3] > [lindex $before 0]}] [expr {[winfo height $t3] > [lindex $before 1]}]] {1 1}
        check "PD10 ...and every pane again has the size it asks for, as the grid gave it: no row lost, no horizontal scrollbar" \
            [list [winfo width $t3.body.vars] [winfo height $t3.body.ana] [winfo height $t3.body.outs] [winfo width $t3.body.ana] \
                  [lmap p {vars ana outs} {expr {[lsearch -exact [grid slaves $t3.body.$p] $t3.body.$p.hsb] >= 0}}]] \
            [list [winfo reqwidth $t3.body.vars] [winfo reqheight $t3.body.ana] [winfo reqheight $t3.body.outs] $rightreq {0 0 0}]
        check "PD10 ...with nothing remembered: the font moved the panes, the user did not" [ase::ui::pane_split $k3] {}
        set ::ase_font_size 0
        ase::ui::populate $k3
        pd_settle
        check "PD10 the font size put back: the panes' heights are what they ask for again" \
            [list [winfo height $t3.body.ana] [winfo height $t3.body.outs]] [list [winfo reqheight $t3.body.ana] [winfo reqheight $t3.body.outs]]
        ase::ui::close $k3
        pd_settle
    }
    if {$PD_KNOB_HAD} { set ::ase_font_size $PD_KNOB_WAS } else { catch {unset ::ase_font_size} }
    group PD11 {
        $top.body.outs.tabs.s invoke
        pd_settle
        set s0 [winfo height $top.body.saves.tv]
        set o0 [winfo height $top.body.outs]
        pd_drag $top.body.v [expr {-2 * $rh}]
        check "PD11 with the Saves tab in front the divider drags the same: Outputs two rows taller, and the Saves tree with it" \
            [list [winfo ismapped $top.body.saves.tv] [expr {[winfo height $top.body.outs] - $o0}] [expr {[winfo height $top.body.saves.tv] - $s0}]] \
            [list 1 [expr {2 * $rh}] [expr {2 * $rh}]]
        $top.body.outs.tabs.m invoke
        pd_settle
        check "PD11 ...and the Measures tree has the same pane when it comes back" [winfo height $top.body.outs] [expr {$o0 + 2 * $rh}]
    }
    group PDclose {
        ase::ui::close $key
        pd_settle
    }
}

check "EVERY band above this one RAN TO ITS END (names of any abandoned band)" \
    [list [llength $::abortnames] $::abortnames] {0 {}}

if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
