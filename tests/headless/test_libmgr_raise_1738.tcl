# tests/headless/test_libmgr_raise_1738.tcl -- Ctrl-Alt-S brings the Library
# Manager forward also when there is nothing to locate (issue 1738).
#
# The user, 2026-11-24: "Ctrl-Alt-S ... locates the current cell that is being
# viewed in the Schematic window in the Library Manager. But, it only works if
# this cell exists - meaning, it doesn't work to just raise the Library Manager
# (which is what the user sometimes wants, because of how things load and
# windows are behind other Windows windows) if the Schematic editor is editing
# untitled.sch or some variant of that. So, in the case that the user is
# looking at a non-existent cell ... ensure that Ctrl-Alt-S WILL raise the
# Library Manager. No need for it to steal focus though. Just raise."
#
# Then, the same day, when keeping the keyboard on the schematic turned out to
# need a hand-back of its own: "I didn't want to make it harder ... go ahead
# and wrap it up WITH handing the Library Manager focus when user does
# Ctrl-Alt-S". So the key raises the window the way it does when it locates.
#
# Spec     doc/claude/specs/library_manager_launch.md, "Ctrl-Alt-S with
#          nothing to locate", rules R-LMR1..R-LMR4
# Issue    doc/claude/issues/1738-*.md
# Code     utils/lib_mgr_helpers.tcl locate_selected_in_libmgr
#          src/library_manager.tcl libmgr::open (its already-open arm keeps
#          what is selected when no cell is asked for)
#
# Bands (counted arm -- no Tk):
#   LH   the key's command on an untitled schematic ends cleanly with no
#        display
# Bands (display arm -- each prints one skip: line under --nogui):
#   LD0  the fixture: a window manager, the Cadence profile's key, an untitled
#        schematic that is in no library, the Library Manager open
#   LD1  the user's case: the Library Manager is behind the schematic window,
#        the key brings it in front and gives it the keyboard, a line in the
#        CIW says why nothing is located, what was selected in the Library
#        Manager stays selected, no window moves
#   LD2  the other selections the key cannot locate: one wire, two objects, a
#        note with no lib/cell, an instance of a symbol in no library
#   LD3  a minimised Library Manager comes back; a closed one is opened
#   LD4  a cell that is in a library is located as before
#
# The key is a generated <Control-Alt-Key-s> on the drawing area with the
# keyboard on it, so the profile's own binding runs; no row calls the command.
# Which window is in front is read from the window manager (wm stackorder).
#
# SABOTAGE, each measured on the display arm:
#   A  locate_selected_in_libmgr without the `xschem library_manager` line of
#      its last two -- the product before the change, plus the new CIW
#      sentence -> LD1 (in front, the keyboard), LD2 (all four), LD3 (both)
#   B  libmgr::open without the line that takes the selection when no cell is
#      asked for -> LD1 (the selection row alone)
# The counted arm stays green under both: with no display there is no window.
#
# REGISTERED IN BOTH LISTS: the LD bands need a display.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_libmgr_raise_1738
#   tests/headless/run_suites.sh test_libmgr_raise_1738

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
set scratch [test_scratch libmgr_raise]
set have_tk [expr {[llength [info commands winfo]] > 0}]

# Only the in-repo registry, as the profile's own suites use it.
set ::XSCHEM_LIBRARY_DEFS [file join $repo xschem_libraries_oa library.defs]
set ::library_registry_defs_only 1

# =============================================================================
# LH -- NO DISPLAY
# =============================================================================
group LH {
    if {!$have_tk} {
        # the key's command itself, as the profile defines it, on the untitled
        # schematic a session starts with
        check "LH with no display the two files that define the key's command load" \
            [list [catch {source [file join $repo utils cadence_nav.tcl]}] \
                  [catch {source [file join $repo utils lib_mgr_helpers.tcl]}]] {0 0}
        check "LH with no display the schematic a session starts with is in no library, and nothing is selected" \
            [list [pcall schematic_cellview [xschem get schname]] [xschem get lastsel]] {{} 0}
        check "LH with no display the key's command ends without an error there, and makes no window" \
            [list [catch {locate_selected_in_libmgr} e] $e [llength [info commands winfo]]] {0 {} 0}
    } else {
        puts "note: LH is the arm with no display; its rows run under --nogui"
    }
}

# =============================================================================
# LD -- THE WINDOWS (display arm)
# =============================================================================
proc ld_settle {{ms 700}} {
    update
    after $ms {set ::ld_go 1}
    vwait ::ld_go
    update
}
# the schematic window in front, the keyboard on its drawing area
proc ld_behind {} {
    raise .
    focus -force .drw
    ld_settle 400
}
# the key, as the user presses it
proc ld_key {} {
    event generate .drw <Control-Alt-Key-s>
    ld_settle
}
# {is the Library Manager above the schematic window, which window has the keyboard}
proc ld_now {} {
    set above 0
    catch {set above [wm stackorder .libmgr isabove .]}
    set f {} ; catch {set f [winfo toplevel [focus]]}
    return [list $above $f]
}
# the CIW's text from a place in it to its end; ld_ciw_mark is that place now
proc ld_ciw_mark {} {
    set m 1.0
    catch {set m [.ciw.l.t index {end - 1 chars}]}
    return $m
}
proc ld_ciw_since {mark} {
    set t {}
    catch {set t [.ciw.l.t get $mark end]}
    return $t
}
proc ld_wm_name {} {
    if {[catch {exec timeout 5 xprop -root _NET_SUPPORTING_WM_CHECK 2>@1} r]} { return {not read} }
    if {![regexp {window id # (0x[0-9a-fA-F]+)} $r -> wid]} { return none }
    if {[catch {exec timeout 5 xprop -id $wid _NET_WM_NAME 2>@1} r] || ![regexp {= "(.*)"} $r -> name]} { return unnamed }
    return $name
}

if {!$have_tk} {
    foreach b {LD0 LD1 LD2 LD3 LD4} {
        puts "skip: $b needs a display (the Library Manager window, the window manager's stacking, the keyboard)"
    }
} else {
    group LD0 {
        set wmname [ld_wm_name]
        puts "note: window manager on this display: $wmname"
        check "LD0 a window manager is live on this display (which window is in front is its answer)" \
            [expr {$wmname ni {none {not read}}}] 1
        check "LD0 the Cadence profile loads" [catch {source [file join $repo src cadence_style_rc]} e] 0
        ld_settle
        check "LD0 the profile binds Ctrl-Alt-S on the drawing area to the locate command" \
            [string match {*locate_selected_in_libmgr*} [bind .drw <Control-Alt-Key-s>]] 1
        check "LD0 the schematic of a fresh session is an untitled one, and it is in no library" \
            [list [string match {untitled*} [file tail [xschem get schname]]] \
                  [file exists [xschem get schname]] [schematic_cellview [xschem get schname]]] {1 0 {}}
        catch {ciw_create}
        catch {destroy .libmgr}
        library_manager
        ld_settle
        check "LD0 the Library Manager is open, and the CIW is there to read" \
            [list [winfo ismapped .libmgr] [winfo exists .ciw.l.t]] {1 1}
    }
    group LD1 {
        # something selected in the Library Manager, to see that it survives
        set L0 [lindex [.libmgr.pw.lib.lb children {}] 0]
        .libmgr.pw.lib.lb selection set $L0
        ld_settle 300
        set C0 [lindex [.libmgr.pw.cell.lb children {}] 0]
        .libmgr.pw.cell.lb selection set $C0
        ld_settle 300
        ld_behind
        set g_lm [wm geometry .libmgr]
        set g_top [wm geometry .]
        check "LD1 before the key: the Library Manager is behind the schematic window, the keyboard in the schematic window, nothing selected in the schematic, a library and a cell selected in the Library Manager" \
            [list [ld_now] [xschem get lastsel] [expr {$L0 ne {} && $C0 ne {}}] \
                  [.libmgr.pw.lib.lb selection] [.libmgr.pw.cell.lb selection]] \
            [list {0 .} 0 1 $L0 $C0]
        set mark [ld_ciw_mark]
        ld_key
        check "LD1 Ctrl-Alt-S on the untitled schematic: the Library Manager is in front and has the keyboard" \
            [ld_now] {1 .libmgr}
        check "LD1 ...it is showing" [list [winfo ismapped .libmgr] [wm state .libmgr]] {1 normal}
        check "LD1 ...the CIW says the Library Manager was raised and why nothing is located" \
            [regexp {not in a registered library: Library Manager raised, nothing located} [ld_ciw_since $mark]] 1
        check "LD1 ...the library and the cell that were selected in the Library Manager still are" \
            [list [.libmgr.pw.lib.lb selection] [.libmgr.pw.cell.lb selection]] [list $L0 $C0]
        check "LD1 neither window has moved or changed size" \
            [list [wm geometry .libmgr] [wm geometry .]] [list $g_lm $g_top]
        ld_behind
        ld_key
        ld_behind
        ld_key
        check "LD1 the key pressed again and again does the same each time" [ld_now] {1 .libmgr}
        check "LD1 ...and after three presses the windows are where they were" \
            [list [wm geometry .libmgr] [wm geometry .]] [list $g_lm $g_top]
    }

    group LD2 {
        # a symbol that is in no registered library
        set loose [file join $scratch loose]
        file mkdir $loose
        file copy -force [file join $repo xschem_library devices res.sym] [file join $loose lmr_res.sym]
        xschem wire 0 0 200 0
        xschem wire 0 100 200 100
        xschem text 0 -200 0 0 {a note with no cell in it} {} 0.4 0.4
        xschem instance [file join $loose lmr_res.sym] 400 0 0 0 {name=R1}
        ld_settle 200
        foreach {what sel kind msg} {
            {one wire}        {{wire 0}}            other {select one instance}
            {two wires}       {{wire 0} {wire 1}}   multi {select one instance}
            {a note with no lib/cell in it} {{text 0}} text {no library/cell}
            {an instance of a symbol that is in no library} {{instance 0}} inst {cannot resolve the selected instance}
        } {
            xschem unselect_all
            foreach s $sel { xschem select {*}$s }
            ld_behind
            set k [lindex [cadence::selkind] 0]
            set mark [ld_ciw_mark]
            ld_key
            check "LD2 with $what selected ($kind): the Library Manager is in front with the keyboard, and the CIW says what the key needs and that the window was raised" \
                [list $k [ld_now] [regexp "$msg\[^\n\]*: Library Manager raised, nothing located" [ld_ciw_since $mark]]] \
                [list $kind {1 .libmgr} 1]
        }
        xschem unselect_all
    }

    group LD3 {
        ld_behind
        wm iconify .libmgr
        ld_settle
        check "LD3 fixture: the Library Manager is minimised" [wm state .libmgr] iconic
        ld_key
        check "LD3 the key brings a minimised Library Manager back, in front, with the keyboard" \
            [list [wm state .libmgr] [winfo ismapped .libmgr] [ld_now]] {normal 1 {1 .libmgr}}
        destroy .libmgr
        ld_behind
        ld_key
        check "LD3 with the Library Manager closed the key opens it" \
            [list [winfo exists .libmgr] [pcall winfo ismapped .libmgr]] {1 1}
    }

    group LD4 {
        # a cell of the registry that has a schematic
        set found {}
        foreach L [dict keys [library_defs_registry]] {
            foreach C [xschem lib_cells $L] {
                if {{schematic} ni [xschem cell_views $L $C]} continue
                set f [xschem cellview_path "$L/$C" schematic]
                if {$f eq {} || ![file exists $f]} continue
                if {[lrange [schematic_cellview $f] 0 1] ne [list $L $C]} continue
                set found [list $L $C $f]
                break
            }
            if {$found ne {}} break
        }
        check "LD4 fixture: the registry has a cell with a schematic" [expr {[llength $found] == 3}] 1
        lassign $found L C f
        xschem load $f
        ld_settle 300
        ld_behind
        set mark [ld_ciw_mark]
        ld_key
        check "LD4 on a cell that is in a library the key locates it as before: in front with the keyboard, library and cell selected" \
            [list [ld_now] [.libmgr.pw.lib.lb selection] [.libmgr.pw.cell.lb selection]] \
            [list {1 .libmgr} $L $C]
        check "LD4 ...and the CIW has no 'nothing located' line for it" \
            [regexp {nothing located} [ld_ciw_since $mark]] 0
    }
    catch {destroy .libmgr}
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
