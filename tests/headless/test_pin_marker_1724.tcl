# test_pin_marker_1724.tcl — the pin marker: `xschem pin_marker` and the ellipse
# it draws.  Issue 1724, phase 2.
#
# Issue  doc/claude/issues/1724-select-on-design-cannot-queue-a-device-terminal-current-a-click-on-an-instance-pin-queues-the-voltage-of-the-pins-net.md
#
# WHAT IS FENCED.  A marker is the cue on an instance pin a caller has chosen: a
# thin upright ellipse round the pin, in a layer's colour.  The engine keeps one
# list per window/tab context, keyed by (hierarchy path, instance NAME, pin
# index), draws it from draw(), and clears it on `xschem unhilight_all` -- in
# the context the command is given in and in those linked to it by a descend --
# and when another document fills the context.  The code is the block above
# pin_marker_add() in src/draw.c and the `pin_marker` branch of xschem_cmds_p()
# in src/scheduler.c.
#
# THE CALLER is ASE-L's Select On Design (src/ase_window.tcl): a click on a
# device pin that queues its terminal current marks that pin -- on layer 16
# with the tag `save` in the flavours that write session rows, cleared when the
# mode ends; in the trace's layer with the tag `plot` in Direct Plot, kept past
# the mode's end like its other colours.  Band G, and groups P5, P6, PC, PN, PD,
# PS, PW, PT, PE, PF and P8 of band P.
#
# BANDS
#   E   the command and the list: add, replace, remove, tag clear, clear, the
#       refusals, the row shape, which verbs redraw
#   U   `xschem unhilight_all`, with no net highlight and with one
#   H   the list survives descend and return, undo and redo, and follows a moved,
#       rotated, flipped, deleted and restored instance; an instance whose NAME
#       is a number is found by name
#   C   a second context: its own list; `clear -all`; `unhilight_all` reaches
#       a context linked to this one by a descend, window or tab, and no other
#   F   derived state: the saved file, the modified flag, the undo stack
#   L   the doors that put another document in the context empty the list;
#       reload does not
#   T   (text) where the calls sit in the C sources, for the claims with no
#       cheap drive
#   G   ASE-L: the marker a pin pick leaves, through the real
#       ase::ui::sod_click -- which picks mark and which do not, the layer and
#       tag of each flavour, the mode's end, Direct Plot's markers and the
#       colours the viewer is handed
#   P   DISPLAY ONLY: the pixels (geometry, colour, the window and the pixmap,
#       redraw, expose, pan, zoom, rotation, the clears), the doors that need
#       Tk (File > Open's dialog arm, a -gui open routed to another context, a
#       detached window repainted by `clear -all`), ASE-L on the screen (a
#       real click through the canvas binding the mode seizes, the real ESC,
#       the real waveform viewer), two windows linked by a descend, the window
#       the mode is on being closed, the mode's prompt naming the pin under
#       the pointer, a pick whose hand moves with the button down, a press made
#       after the engine's pointer was overwritten, a window made while the
#       mode is up, the clear-all given while a wire is being drawn in a linked
#       window, the mode entered with the design in a tab that is not the
#       first, the prompt with the pointer in another window of the design,
#       Direct Plot's window closed with traces queued, and the keys that
#       clear highlights, pressed -- the band's last group, which must stay
#       last: it sources the Cadence-style profile into the session
#
# Bands E to G run on both arms.  Band P needs a display; on the counted arm it
# is announced by ONE `skip:` line and nothing else.
#
# NO GEOMETRY IS A LITERAL.  The ellipse's size in pixels follows the zoom and
# the Tk scaling (half-width: the larger of 5 units and 3 scaled pixels;
# half-height: twice that), and both differ between displays.  pm_a_px reads
# them at the moment of use.
#
# From the repo ROOT:
#   tests/headless/run_suites.sh --nogui test_pin_marker_1724
#   AUDIT_DISPLAY=private tests/headless/run_suites.sh test_pin_marker_1724
# scratch.tcl arms the in-suite stall watchdog: band P pumps the event loop.

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
set scratch [test_scratch pin_marker_1724]
set has_display [expr {[info commands winfo] ne {} ? 1 : 0}]

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
proc wfile {path body} { set f [open $path w]; puts $f $body; close $f }
proc rfile {path} { set f [open $path r]; fconfigure $f -translation binary; set s [read $f]; close $f; return $s }
proc pm_list {} { return [pcall xschem pin_marker list] }
# the pin's point through a door that is not pin_marker: {x y}
proc pm_coord {inst pin} { return [lrange [pcall xschem instance_pin_coord $inst name $pin] 1 2] }
# the {x y} a list row reports, or NOROW
proc pm_xy {row} { return [expr {[llength $row] == 7 ? [lrange $row 5 6] : "NOROW:$row"}] }
# the row of the list whose instance name and pin index are given, or {}
proc pm_row {iname pin} {
    foreach r [pm_list] { if {[lindex $r 1] eq $iname && [lindex $r 2] eq $pin} { return $r } }
    return {}
}
proc pm_fresh {} {
    pcall xschem unselect_all
    pcall xschem set modified 0
    pcall xschem load $::pm_top
    pcall xschem pin_marker clear -fast
}
# an error answer as {catch code, the message is ONE line, the message}
proc pm_err {args} {
    set c [catch {uplevel 1 $args} m]
    return [list $c [expr {[string first "\n" $m] < 0 ? 1 : 0}] $m]
}
# one `xschem pin_marker` command as {its answer, the draws it made}
proc pm_drawn {args} {
    set d0 [pcall xschem get drawcount]
    set a [pcall xschem pin_marker {*}$args]
    set d1 [pcall xschem get drawcount]
    if {![string is integer -strict $d0] || ![string is integer -strict $d1]} { return [list $a "NODRAWCOUNT:$d0/$d1"] }
    return [list $a [expr {$d1 - $d0}]]
}
# the window/tab contexts that are open, by their paths
proc pm_wins {} { return [lmap w [pcall xschem windows] { lindex $w 0 }] }
# close the context `path`, made by a row, and come back to `first`.  With no
# Tk, `new_schematic destroy` leaves the context of a detached window in
# place; what is then still open beside `first` is closed in one go.
proc pm_close_ctx {path first} {
    if {[lsearch -exact [pm_wins] $path] >= 0} {
        pcall xschem new_schematic switch $path
        pcall xschem set modified 0
        pcall xschem new_schematic destroy $path {}
    }
    pcall xschem new_schematic switch $first
    if {[info commands winfo] eq {} && [lsearch -exact [pm_wins] $path] >= 0} {
        pcall xschem new_schematic destroy_all {}
        pcall xschem new_schematic switch $first
    }
}

# the body of a C function or of one dispatcher branch, comments stripped, so a
# text row reads code and never the prose above it
proc pm_ccode {path} {
    set f [open $path r]; set s [read $f]; close $f
    regsub -all {/\*.*?\*/} $s {} s
    return $s
}
proc pm_cbody {code head} {
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
proc pm_branch {code verb} {
    set i [string first "else if(!strcmp(argv\[1\], \"$verb\"))" $code]
    if {$i < 0} { return "NOBRANCH:$verb" }
    return [pm_cbody [string range $code $i end] {else if(}]
}
proc pm_has {body words} {
    set out {}
    foreach w $words { lappend out [expr {[string first $w $body] >= 0 ? 1 : 0}] }
    return $out
}
# is `a` found in `body`, and before `b`?  (1 only when both are there, in order)
proc pm_before {body a b} {
    set i [string first $a $body]; set j [string first $b $body]
    return [expr {$i >= 0 && $j >= 0 && $i < $j ? 1 : 0}]
}

# ===========================================================================
# the fixture, written as text into scratch
# ===========================================================================
# pm_blk.sym / pm_blk.sch: a block with two pins whose own sheet holds an R1 --
# the SAME instance name as the top sheet's R1, at another hierarchy path.
# pm_top.sch, instance order (the rows read it):
#   0 x1   the block           pins A (-40,0)  B (40,0)
#   1 R1   res.sym             P (300,-30)     M (300,30)
#   2 R2   res.sym             P (500,-30)     M (500,30)
#   3 `2`  res.sym, an instance whose NAME is the number 2, at index 3
#   one wire on R2.M with the label NETA, for the net-highlight row
# pm_other.sch: another document, whose R1 sits somewhere else.
wfile [file join $scratch pm_blk.sym] {v {xschem version=3.4.8RC file_version=1.3}
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
B 5 -42.5 -2.5 -37.5 2.5 {name=A dir=in}
B 5 37.5 -2.5 42.5 2.5 {name=B dir=out}}
wfile [file join $scratch pm_blk.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {ipin.sym} -100 0 0 0 {name=p1 lab=A}
C {opin.sym} 100 0 0 0 {name=p2 lab=B}
C {res.sym} 0 0 1 0 {name=R1 value=1k}}
set pm_top [file join $scratch pm_top.sch]
wfile $pm_top "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 500 30 500 80 {lab=NETA}
C {[file join $scratch pm_blk.sym]} 0 0 0 0 {name=x1}
C {res.sym} 300 0 0 0 {name=R1 value=1k}
C {res.sym} 500 0 0 0 {name=R2 value=1k}
C {res.sym} 700 0 0 0 {name=2 value=1k}
C {lab_pin.sym} 500 80 0 0 {name=l1 sig_type=std_logic lab=NETA}"
set pm_other [file join $scratch pm_other.sch]
wfile $pm_other "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {res.sym} 700 100 0 0 {name=R1 value=1k}"

if {[catch {

# ===========================================================================
# E — the command and the list
# ===========================================================================
check "E0a this binary has the subcommand: `xschem pin_marker list` does not raise (a build without it answers an unknown-command error here and every row below would be about that)" \
    [catch {xschem pin_marker list}] 0
check "E0b fixture: the top sheet loads and reads back its five instances in file order, at hierarchy path `.`" \
    [list [expr {[pcall xschem load $pm_top] ne {} ? 1 : 0}] \
          [lmap i {0 1 2 3 4} { pcall xschem getprop instance $i name }] [pcall xschem get sch_path]] \
    {1 {x1 R1 R2 2 l1} .}

group E1 {
    pm_fresh
    check "E1a a context with no marker lists nothing" [pm_list] {}
    set a [pcall xschem pin_marker add R1 P]
    check "E1b add answers 1 for a new marker, and the list is ONE row {path instname pin layer tag x y}: the sheet's path, the instance's name, the pin's INDEX, the default layer 16, the default empty tag, and the pin's point as instance_pin_coord gives it" \
        [list $a [pm_list]] [list 1 [list [list . R1 0 16 {} {*}[pm_coord R1 P]]]]
    set b [pcall xschem pin_marker add -layer 7 -tag plot x1 B]
    set c [pcall xschem pin_marker add -tag save -layer 9 2 M]
    check "E1c -layer and -tag are taken in either order, a pin is named by name or by index, an instance by name or by index, and the list is in INSERTION order (the three rows; the third was added as instance index 2, which is R2)" \
        [list $b $c [pm_list]] \
        [list 1 1 [list [list . R1 0 16 {} {*}[pm_coord R1 P]] [list . x1 1 7 plot {*}[pm_coord x1 B]] \
                        [list . R2 1 9 save {*}[pm_coord R2 M]]]]
    set d [pcall xschem pin_marker add -layer 11 -tag again 1 0]
    check "E1d adding a pin that is already marked -- here by index where it was first added by name -- answers 0, does NOT add a row, keeps the row's place, and replaces its layer and tag" \
        [list $d [llength [pm_list]] [lindex [pm_list] 0]] [list 0 3 [list . R1 0 11 again {*}[pm_coord R1 P]]]
    check "E1e the three markers sit on three different points, so the rows above cannot have compared one coordinate with itself" \
        [llength [lsort -unique [lmap r [pm_list] { pm_xy $r }]]] 3
}

group E2 {
    pm_fresh
    foreach {i p t} {R1 P a  R1 M b  R2 P a  R2 M c  x1 A a} { pcall xschem pin_marker add -fast -tag $t $i $p }
    set n0 [llength [pm_list]]
    set r1 [pcall xschem pin_marker remove R1 M]
    set r2 [pcall xschem pin_marker remove R1 M]
    check "E2a remove answers 1 when it removed a marker and 0 when there was none, and the survivors keep their order (rows before; the two answers; then instance and pin of each remaining row)" \
        [list $n0 $r1 $r2 [lmap r [pm_list] { lrange $r 1 2 }]] {5 1 0 {{R1 0} {R2 0} {R2 1} {x1 0}}}
    set c0 [pcall xschem pin_marker clear -tag nosuch]
    set c1 [pcall xschem pin_marker clear -tag a]
    check "E2b clear -tag drops the markers carrying that tag and only those, answering how many: 0 for a tag nothing carries, 3 for tag a, leaving the one tagged c" \
        [list $c0 $c1 [lmap r [pm_list] { lrange $r 1 4 }]] {0 3 {{R2 1 16 c}}}
    pcall xschem pin_marker add -fast R1 P
    set c2 [pcall xschem pin_marker clear]
    set c3 [pcall xschem pin_marker clear]
    check "E2c clear with no tag drops every marker whatever its tag and answers the count; a second clear answers 0" \
        [list $c2 $c3 [pm_list]] {2 0 {}}
    pcall xschem pin_marker add -fast -tag {} R1 P
    pcall xschem pin_marker add -fast -tag z R1 M
    check "E2d the EMPTY tag is a tag like any other: clear -tag {} drops the untagged marker and leaves the tagged one" \
        [list [pcall xschem pin_marker clear -tag {}] [lmap r [pm_list] { lrange $r 1 4 }]] {1 {{R1 1 16 z}}}
}

group E3 {
    pm_fresh
    pcall xschem pin_marker add -fast -tag keep R1 P
    set before [pm_list]
    set nl [pcall xschem get cadlayers]
    set refused {}
    foreach words [list {add nosuch 0} {add 99 0} {add R1 2} {add R1 99} {add R1 ZZ} {add R1 -1} \
                        {add -layer 0 R1 M} [list add -layer $nl R1 M] {add -layer -3 R1 M} \
                        {add -layer x R1 M} {add -layer 7x R1 M}] {
        lappend refused [lrange [pm_err xschem pin_marker {*}$words] 0 1]
    }
    check "E3a an unknown instance (by name and by index), a pin index the symbol does not have, an unknown pin name, a negative pin, and a layer that is 0, the layer count, negative or not a number are each REFUSED: catch code 1 and a one-line message, for all eleven spellings (the distinct answers; how many were tried)" \
        [list [lsort -unique $refused] [llength $refused]] {{{1 1}} 11}
    check "E3b the refusals name what was wrong: the instance word, the pin word with the instance's name, and the layer with the range the binary takes" \
        [list [lindex [pm_err xschem pin_marker add nosuch 0] 2] [lindex [pm_err xschem pin_marker add R1 ZZ] 2] \
              [lindex [pm_err xschem pin_marker add -layer 0 R1 M] 2]] \
        [list {xschem pin_marker: instance not found: nosuch} \
              {xschem pin_marker: instance R1 has no pin ZZ (it has 2)} \
              "xschem pin_marker: layer 0 is not in 1 .. [expr {$nl - 1}]"]
    set usage {}
    foreach words {{} {bogus} {add} {add R1} {remove R1} {add -layer R1 P} {add -tag R1 P} {add -nosuch R1 P}
                   {remove -layer 7 R1 P} {clear -nosuch} {clear -tag} {clear x} {list x}} {
        set e [pm_err xschem pin_marker {*}$words]
        lappend usage [list [lindex $e 0] [string match {usage: xschem pin_marker *} [lindex $e 2]]]
    }
    check "E3c a missing or unknown verb, too few words, an option with its value missing, an unknown option, an option the verb does not take and a stray word are the USAGE line with catch code 1, for all thirteen spellings (the distinct answers; how many were tried)" \
        [list [lsort -unique $usage] [llength $usage]] {{{1 1}} 13}
    check "E3d none of those refusals changed the list" [expr {[pm_list] eq $before}] 1
    check "E3e remove of a pin that was never marked, of an unknown instance and of an unknown pin name is not an error: it answers 0" \
        [list [pcall xschem pin_marker remove R2 P] [pcall xschem pin_marker remove nosuch 0] \
              [pcall xschem pin_marker remove R1 ZZ] [expr {[pm_list] eq $before}]] {0 0 0 1}
}

group E4 {
    pm_fresh
    set got {}
    lappend got [pm_drawn add R1 P]
    lappend got [pm_drawn add -fast R1 M]
    lappend got [pm_drawn remove R1 P]
    lappend got [pm_drawn remove R2 P]
    lappend got [pm_drawn remove -fast R1 M]
    pcall xschem pin_marker add -fast R1 P
    lappend got [pm_drawn clear]
    lappend got [pm_drawn clear]
    pcall xschem pin_marker add -fast R1 P
    lappend got [pm_drawn clear -fast]
    check "E4 WHICH VERBS REDRAW, each as {answer draws} with the draws counted by `xschem get drawcount`: add draws once; add -fast does not draw; remove of a marked pin draws once; remove of a pin that is not marked draws nothing; remove -fast does not draw; a clear that dropped a marker draws once; a clear of an empty list draws nothing; clear -fast does not draw" \
        $got {{1 1} {1 0} {1 1} {0 0} {1 0} {1 1} {0 0} {1 0}}
}

# ===========================================================================
# U — `xschem unhilight_all`
# ===========================================================================
group U {
    pm_fresh
    pcall xschem pin_marker add -fast -tag save R1 P
    pcall xschem pin_marker add -fast -tag plot R2 P
    set nets0 [pcall xschem list_hilights all]
    pcall xschem unhilight_all
    check "U1 with NO net highlighted, `xschem unhilight_all` empties the list, whatever the markers' tags (the highlight table before; rows after)" \
        [list $nets0 [pm_list]] {{} {}}
    pcall xschem pin_marker add -fast -tag save R1 P
    pcall xschem hilight_netname -fast NETA
    set nets1 [pcall xschem list_hilights all]
    pcall xschem unhilight_all
    check "U2 with a net highlighted, the same command clears the net's highlight AND the marker (that a highlight was there before; the highlight table and the list after)" \
        [list [expr {$nets1 ne {} ? 1 : 0}] [pcall xschem list_hilights all] [pm_list]] {1 {} {}}
    pcall xschem pin_marker add -fast R1 P
    set d0 [pcall xschem get drawcount]
    pcall xschem unhilight_all fast
    set d1 [pcall xschem get drawcount]
    pcall xschem pin_marker add -fast R1 P
    pcall xschem unhilight_all
    set d2 [pcall xschem get drawcount]
    check "U3 `unhilight_all fast` empties the list too and does not draw, where the plain form draws once (rows after the fast form; draws across the fast form; draws across the plain form)" \
        [list [pm_list] [expr {$d1 - $d0}] [expr {$d2 - $d1}]] {{} 0 1}
}

# ===========================================================================
# H — hierarchy, undo, and an instance that moves
# ===========================================================================
group H1 {
    pm_fresh
    pcall xschem pin_marker add -fast -tag top R1 P
    pcall xschem pin_marker add -fast -tag top x1 B
    set top0 [pm_list]
    pcall xschem unselect_all
    pcall xschem select instance x1
    pcall xschem descend
    check "H1 fixture: the descend reached the block's own sheet, which holds an instance NAMED R1 as the top sheet does, with a pin 0" \
        [list [pcall xschem get sch_path] [pcall xschem get currsch] \
              [expr {[lsearch -exact [lmap i {0 1 2} { pcall xschem getprop instance $i name }] R1] >= 0}] \
              [llength [pm_coord R1 P]]] {.x1. 1 1 2}
    check "H1a on the sheet below, both markers are still listed, at the TOP sheet's path, and neither has a point: the marker on the top sheet's R1 does not land on this sheet's R1, because the path is part of the key" \
        [lmap r [pm_list] { list [lindex $r 0] [lindex $r 1] [pm_xy $r] }] {{. R1 {{} {}}} {. x1 {{} {}}}}
    set k [pcall xschem pin_marker add -fast -tag kid R1 P]
    check "H1b a marker added down here is keyed by THIS sheet's path and has this sheet's point: a third row, beside the top sheet's R1 marker which it did not replace" \
        [list $k [llength [pm_list]] [lindex [pm_list] 2]] [list 1 3 [list .x1. R1 0 16 kid {*}[pm_coord R1 P]]]
    pcall xschem go_back
    check "H1c back at the top the two markers have their points again, exactly as before the descend, and the one from below is listed without a point (path; the first two rows equal the list before; the third row's path, name and point)" \
        [list [pcall xschem get sch_path] [expr {[lrange [pm_list] 0 1] eq $top0}] \
              [lrange [lindex [pm_list] 2] 0 1] [pm_xy [lindex [pm_list] 2]]] \
        {. 1 {.x1. R1} {{} {}}}
    check "H1d adding and listing markers on the way did not mark either sheet modified (the return up asked nothing)" \
        [pcall xschem get modified] 0
}

group H2 {
    pm_fresh
    pcall xschem pin_marker add -fast -tag save R1 P
    set p0 [pm_xy [pm_row R1 0]]
    pcall xschem unselect_all ; pcall xschem select instance R1
    pcall xschem move_objects 50 20
    set p1 [pm_xy [pm_row R1 0]] ; set c1 [pm_coord R1 P]
    pcall xschem undo
    set p2 [pm_xy [pm_row R1 0]]
    pcall xschem redo
    set p3 [pm_xy [pm_row R1 0]]
    check "H2a the marker's point FOLLOWS a moved instance, goes back with an undo and forward with a redo, and the list is one row throughout (the moved point equals instance_pin_coord's; undo equals the start; redo equals the moved point; rows)" \
        [list [expr {$p1 eq $c1}] [expr {$p2 eq $p0}] [expr {$p3 eq $p1}] [llength [pm_list]]] {1 1 1 1}
    pcall xschem unselect_all ; pcall xschem select instance R1
    pcall xschem rotate 350 20
    set p4 [pm_xy [pm_row R1 0]] ; set c4 [pm_coord R1 P]
    pcall xschem unselect_all ; pcall xschem select instance R1
    pcall xschem flip 350 20
    set p5 [pm_xy [pm_row R1 0]] ; set c5 [pm_coord R1 P]
    check "H2b ...and a rotated and then a flipped one (each point equals instance_pin_coord's at that moment)" \
        [list [expr {$p4 eq $c4}] [expr {$p5 eq $c5}]] {1 1}
    check "H2c the four points -- start, moved, rotated, flipped -- are pairwise different, so the equalities above each compared a point that had really changed" \
        [llength [lsort -unique [list $p0 $p1 $p4 $p5]]] 4
    pcall xschem unselect_all ; pcall xschem select instance R1
    pcall xschem delete
    set gone [pm_row R1 0]
    pcall xschem undo
    check "H2d a marker whose instance is DELETED stays in the list, without a point, and has its point again when an undo brings the instance back (the row while deleted: path, name, pin, layer, tag, then the empty point; the point after the undo)" \
        [list $gone [expr {[pm_xy [pm_row R1 0]] eq $p5}]] [list {. R1 0 16 save {} {}} 1]
}

group H3 {
    pm_fresh
    # the instance at index 3 is NAMED `2`; index 2 is R2
    set a [pcall xschem pin_marker add -fast 3 P]
    check "H3a an instance whose NAME is a number: marked through its index, the row carries the name `2` and the point of THAT instance -- not of R2, which is what the word 2 names as an index (the row; then R2's P for comparison)" \
        [list $a [pm_list] [pm_coord R2 P]] [list 1 [list [list . 2 0 16 {} 700 -30]] {500 -30}]
    check "H3b ...and it is removed through the same index, while removing pin P of index 2 -- R2, which has no marker -- answers 0 and leaves it" \
        [list [pcall xschem pin_marker remove 2 P] [llength [pm_list]] [pcall xschem pin_marker remove 3 P] [pm_list]] \
        {0 1 1 {}}
}

# ===========================================================================
# C — a second context
# ===========================================================================
group C {
    pm_fresh
    pcall xschem pin_marker add -fast -tag save R1 P
    pcall xschem pin_marker add -fast -tag plot R2 P
    set first [pcall xschem get current_win_path]
    set list1 [pm_list]
    pcall xschem new_schematic create {} $pm_other
    set second [pcall xschem get current_win_path]
    check "C1 a NEW window/tab context starts with no marker, while the first holds two (the two contexts are different; rows in the new one; rows the first held)" \
        [list [expr {$second ne $first}] [pm_list] [llength $list1]] {1 {} 2}
    pcall xschem pin_marker add -fast -tag save R1 M
    set list2 [pm_list]
    pcall xschem new_schematic switch $first
    check "C2 a marker added in the second context is listed there and NOT in the first, whose list is what it was" \
        [list [lmap r $list2 { lrange $r 0 4 }] [expr {[pm_list] eq $list1}]] {{{. R1 1 16 save}} 1}
    set c [pcall xschem pin_marker clear -tag save]
    pcall xschem new_schematic switch $second
    check "C3 `clear -tag save` WITHOUT -all is local: it answers 1 (the first context's one), and the second context still holds its own marker tagged save" \
        [list $c [expr {[pm_list] eq $list2}]] {1 1}
    pcall xschem new_schematic switch $first
    pcall xschem pin_marker add -fast -tag save R1 P
    set n [pcall xschem pin_marker clear -tag save -all]
    set left1 [lmap r [pm_list] { lrange $r 1 4 }]
    pcall xschem new_schematic switch $second
    set left2 [pm_list]
    check "C4 `clear -tag save -all` reaches EVERY context: it answers 2, one from each, leaving the first context its marker tagged plot and the second none" \
        [list $n $left1 $left2] {2 {{R2 0 16 plot}} {}}
    pcall xschem pin_marker add -fast R1 P
    pcall xschem new_schematic switch $first
    set n [pcall xschem pin_marker clear -all]
    set left1 [pm_list]
    pcall xschem new_schematic switch $second
    check "C5 `clear -all` with no tag empties every context and answers the total" \
        [list $n $left1 [pm_list]] {2 {} {}}
    pcall xschem pin_marker add -fast R1 P
    pcall xschem new_schematic switch $first
    pcall xschem pin_marker add -fast R1 P
    pcall xschem unhilight_all
    set left1 [pm_list]
    pcall xschem new_schematic switch $second
    check "C6 `xschem unhilight_all` does NOT reach a context that is not linked to this one by a descend: the first is empty, and the second -- another document, opened beside it -- keeps its marker" \
        [list $left1 [llength [pm_list]]] {{} 1}
    pcall xschem new_schematic destroy $second {}
    check "C7 the second context closes with a marker still in it and the first carries on (the context now current; its list still answers)" \
        [list [pcall xschem get current_win_path] [pm_list]] [list $first {}]
}

# ---------------------------------------------------------------------------
# C8, C9 — a context LINKED to this one by a descend
# ---------------------------------------------------------------------------
# A block opened in a new window or a new tab shows a sheet of the SAME
# hierarchy branch as the window it was opened from.  `xschem unhilight_all`
# clears the net colours of both, whichever of the two it is given in, and it
# takes the pin markers of both as well.  A third context, another document
# beside them, is on no branch of theirs and keeps its marker.  C8 makes the
# linked context a detached window, C9 a tab.
foreach {id target} {C8 new_window C9 new_tab} {
    group $id {
        pm_fresh
        set first [pcall xschem get current_win_path]
        pcall xschem new_schematic create {} $pm_other
        set other [pcall xschem get current_win_path]
        pcall xschem pin_marker add -fast -tag plot R1 P
        pcall xschem new_schematic switch $first
        set made [pcall hi_descend inst=x1 target=$target]
        set below [pcall xschem get current_win_path]
        set where [list [pcall xschem get sch_path] [pcall xschem get currsch]]
        pcall xschem pin_marker add -fast -tag plot R1 P
        pcall xschem pin_marker add -fast -tag save R1 M
        set had_below [lmap r [pm_list] { lrange $r 0 4 }]
        pcall xschem new_schematic switch $first
        pcall xschem pin_marker add -fast -tag save R1 P
        set had_first [lmap r [pm_list] { lrange $r 0 4 }]
        pcall xschem unhilight_all
        set left_first [pm_list]
        pcall xschem new_schematic switch $below
        set left_below [pm_list]
        pcall xschem new_schematic switch $other
        set left_other [lmap r [pm_list] { lrange $r 0 4 }]
        check "${id}a GIVEN ON THE SHEET ABOVE, `xschem unhilight_all` EMPTIES THE LIST OF THE CONTEXT BELOW TOO: `hi_descend inst=x1 target=$target` opens the block's sheet in a third context, one level down the same branch; with two markers there, one on the sheet above and one in the unlinked context, the command given above leaves the lists above and below empty and the unlinked one as it was (the descend's answer; three different contexts; the path and level below; the lists below, above and unlinked before; then above, below and unlinked after)" \
            [list $made [llength [lsort -unique [list $first $other $below]]] $where $had_below $had_first \
                  $left_first $left_below $left_other] \
            [list 1 3 {.x1. 1} {{.x1. R1 0 16 plot} {.x1. R1 1 16 save}} {{. R1 0 16 save}} {} {} {{. R1 0 16 plot}}]
        pcall xschem new_schematic switch $first
        pcall xschem pin_marker add -fast -tag plot R2 P
        pcall xschem pin_marker add -fast R2 M
        set had_first [lmap r [pm_list] { lrange $r 1 4 }]
        pcall xschem new_schematic switch $below
        pcall xschem pin_marker add -fast R1 P
        set had_below [llength [pm_list]]
        pcall xschem unhilight_all
        set left_below [pm_list]
        pcall xschem new_schematic switch $first
        set left_first [pm_list]
        pcall xschem new_schematic switch $other
        set left_other [lmap r [pm_list] { lrange $r 0 4 }]
        check "${id}b ...AND THE OTHER WAY ROUND: given on the sheet BELOW, the command empties the list of the sheet above -- two markers, one tagged and one not -- with its own, and still leaves the unlinked context its marker (the list above and the rows below before; then below, above and unlinked after)" \
            [list $had_first $had_below $left_below $left_first $left_other] \
            [list {{R2 0 16 plot} {R2 1 16 {}}} 1 {} {} {{. R1 0 16 plot}}]
        pm_close_ctx $below $first
        pm_close_ctx $other $first
        check "${id}c the two contexts these rows opened are closed again and the first carries on, on its own sheet (the contexts open; the one current; its path)" \
            [list [pm_wins] [pcall xschem get current_win_path] [pcall xschem get sch_path]] \
            [list [list $first] $first .]
        pcall xschem pin_marker clear -fast
    }
}

# ===========================================================================
# F — derived state: the file, the modified flag, the undo stack
# ===========================================================================
group F {
    pm_fresh
    set with [file join $scratch with.sch]; set without [file join $scratch without.sch]
    pcall xschem saveas $without schematic
    set m0 [pcall xschem get modified]
    set wrote [list [pcall xschem pin_marker add -tag save R1 P] [pcall xschem pin_marker add -layer 7 -tag plot x1 B] \
                    [pcall xschem pin_marker add -layer 9 R1 P] [pcall xschem pin_marker remove x1 B] \
                    [llength [pcall xschem pin_marker list]]]
    set m1 [pcall xschem get modified]
    pcall xschem saveas $with schematic
    set held [llength [pm_list]]
    check "F1 a sheet saved WITH a marker in the list is byte-identical to the same sheet saved without one, and saving did not drop the marker (the two files are equal; the file is not empty; rows still listed)" \
        [list [expr {[rfile $with] eq [rfile $without]}] [expr {[string length [rfile $with]] > 100}] $held] {1 1 1}
    set cleared [pcall xschem pin_marker clear]
    check "F2 add, replace, remove, list and clear never set the MODIFIED flag: 0 before, after the first four, and after the clear -- and the writes did happen (their answers: a new marker, another, a replace, a removal, one row listed; then one row cleared)" \
        [list $m0 $m1 [pcall xschem get modified] $wrote $cleared] {0 0 0 {1 1 0 1 1} 1}
    # the undo stack, by what ONE undo restores: a marker write that pushed a slot
    # would make the undo below step back over its own push and leave R2 deleted
    pcall xschem unselect_all ; pcall xschem select instance R2
    pcall xschem delete
    set after_delete [pcall xschem get instances]
    set wrote [list [pcall xschem pin_marker add R1 P] [pcall xschem pin_marker add -layer 7 R1 P] \
                    [pcall xschem pin_marker remove R1 P] [pcall xschem pin_marker add R1 M] [pcall xschem pin_marker clear]]
    pcall xschem undo
    check "F3 marker writes leave the undo stack alone: delete R2, write the list five times, and ONE undo brings R2 back (instances after the delete, after the undo, the name back at its index; then the five writes' answers, so they did happen)" \
        [list $after_delete [pcall xschem get instances] [pcall xschem getprop instance 2 name] $wrote] {4 5 R2 {1 0 1 1 1}}
}

# ===========================================================================
# L — another document in the context empties the list
# ===========================================================================
group L {
    pm_fresh
    pcall xschem pin_marker add -fast R1 P
    set n0 [llength [pm_list]]
    pcall xschem load $pm_other
    check "L1 `xschem load <another file>` in the same context empties the list: the other document has an R1 too, and no marker is carried onto it (rows before; the sheet now shown; rows after)" \
        [list $n0 [file tail [pcall xschem get schname]] [pm_list]] {1 pm_other.sch {}}
    pcall xschem pin_marker add -fast R1 P
    pcall xschem load $pm_other
    check "L2 a load of the SAME file is a load: it empties the list too" [pm_list] {}
    pcall xschem pin_marker add -fast R1 P
    set n0 [llength [pm_list]]
    pcall xschem reload
    check "L3 `xschem reload` -- the same document read again from disk -- KEEPS the list, and the marker still has its point (rows before; the row after)" \
        [list $n0 [pm_list]] [list 1 [list [list . R1 0 16 {} {*}[pm_coord R1 P]]]]
    pcall xschem clear force
    check "L4 `xschem clear force` -- a new, empty document -- empties the list (rows; instances on the new sheet)" \
        [list [pm_list] [pcall xschem get instances]] {{} 0}
    if {!$has_display} {
        # with no Tk a -gui open cannot be routed to another context, so it is one
        # more in-place load; band P holds what it does with a display
        pm_fresh
        pcall xschem pin_marker add -fast R1 P
        pcall xschem load -gui $pm_other
        check "L5 (counted arm) `xschem load -gui <another file>` loads in place here and empties the list like the plain form (the sheet now shown; rows)" \
            [list [file tail [pcall xschem get schname]] [pm_list]] {pm_other.sch {}}
    }
}

# ===========================================================================
# T — (text) where the calls sit, comments stripped
# ===========================================================================
group T {
    set dc [pm_ccode [file join $repo src draw.c]]
    set hc [pm_ccode [file join $repo src hilight.c]]
    set ac [pm_ccode [file join $repo src actions.c]]
    set sc [pm_ccode [file join $repo src scheduler.c]]
    set xc [pm_ccode [file join $repo src xinit.c]]
    set draw [pm_cbody $dc {void draw(void)}]
    check "T1 (text) draw() calls draw_pin_markers() once, after its draw_hilight_net() call and before the copy of the pixmap to the window" \
        [list [regexp -all {draw_pin_markers\(} $draw] \
              [pm_before $draw {draw_hilight_net(xctx->draw_window)} {draw_pin_markers(}] \
              [pm_before $draw {draw_pin_markers(} {MyXCopyArea(}]] {1 1 1}
    check "T2 (text) the three functions that must NOT touch the list do not name it: draw_hilight_net(), which returns early when no net is highlighted; clear_all_hilights(), which runs on borrowed contexts; and clear_drawing(), which descend, return and undo run (three zeros; then, as the control that each body was really read, a word each of them does hold)" \
        [list [pm_has [pm_cbody $hc {void draw_hilight_net(int on_window)}] {pin_marker}] \
              [pm_has [pm_cbody $hc {void clear_all_hilights(void)}] {pin_marker}] \
              [pm_has [pm_cbody $ac {void clear_drawing(void)}] {pin_marker}] \
              [pm_has [pm_cbody $hc {void draw_hilight_net(int on_window)}] {hilight_nets}] \
              [pm_has [pm_cbody $hc {void clear_all_hilights(void)}] {hilight_hash_free(}] \
              [pm_has [pm_cbody $ac {void clear_drawing(void)}] {del_wire_table(}]] \
        {0 0 0 1 1 1}
    set br [pm_branch $sc pin_marker]
    check "T3 (text) the pin_marker branch of the dispatcher works through the four list functions and holds no side effect a derived cue must not have: no action-log line, no modify, no undo push, no netlist preparation" \
        [pm_has $br {pin_marker_add( pin_marker_remove( pin_marker_clear( pin_marker_resolve(
                     log_action set_modify push_undo prepare_netlist_structs}] \
        {1 1 1 1 0 0 0 0}
    set ub [pm_branch $sc unhilight_all]
    check "T4 (text) the unhilight_all branch clears the markers BEFORE its draw(), so the redraw is the one that erases them" \
        [pm_before $ub {pin_marker_clear(} {draw()}] 1
    set dpm [pm_cbody $dc {void draw_pin_markers(void)}]
    set res [pm_cbody $dc {int pin_marker_resolve(}]
    check "T5 (text) draw_pin_markers() returns on an empty list before its loop and allocates nothing, and neither it nor pin_marker_resolve() calls get_instance(), which reads an all-digit name as an index: the instance is found by strcmp" \
        [list [pm_before $dpm {xctx->pin_markers <= 0} {for(}] \
              [pm_has $dpm {my_malloc my_realloc my_calloc my_strdup get_instance(}] \
              [pm_has $res {get_instance( strcmp(}]] \
        {1 {0 0 0 0 0} {0 1}}
    check "T6 (text) free_xschem_data() gives the list back, and the two other doors that replace the document -- ask_new_file() and clear_schematic() -- clear it" \
        [list [pm_has [pm_cbody $xc {static void free_xschem_data()}] {pin_marker_clear(}] \
              [pm_has [pm_cbody $ac {void ask_new_file(}] {pin_marker_clear(}] \
              [pm_has [pm_cbody $ac {void clear_schematic(}] {pin_marker_clear(}]] {1 1 1}
    # the keys that clear highlights, as code and not as the comments beside it.
    # Of the profile's lines that bind key 0 on the design canvas the LAST is
    # judged: in Tk a later binding replaces an earlier one.
    set cc [pm_ccode [file join $repo src callback.c]]
    set key0 {} ; set nkey0 0
    foreach l [split [rfile [file join $repo src cadence_style_rc]] "\n"] {
        if {[regexp {^\s*#} $l]} continue
        if {[regexp {bind\s+\.drw\s+<(?:Key|KeyPress)-0>} $l]} { set key0 $l ; incr nkey0 }
    }
    check "T7 (text) THE KEYS THAT CLEAR HIGHLIGHTS RUN THAT COMMAND, so they clear the markers as the rows of bands U and G show the command does: of the lines of the Cadence-style profile that bind key 0 on the design canvas, comment lines left out, there is at least one and the LAST binds it to `xschem unhilight_all`; and the stock action the Shift+K key runs is that same command (band P presses both keys)" \
        [list [expr {$nkey0 > 0}] \
              [regexp {bind\s+\.drw\s+<(?:Key|KeyPress)-0>\s+\{xschem unhilight_all;\s*break\}\s*$} $key0] \
              [regexp {"hilight\.un_highlight_all_net_pins",\s*NULL,\s*"xschem unhilight_all"} $cc] \
              [regexp {set_input_binding_idle\(DEV_KEY, 'K', 0,\s*ACTX_CANVAS, "hilight\.un_highlight_all_net_pins"\)} $cc]] {1 1 1 1}
}

# ===========================================================================
# G — ASE-L: the marker a pin pick leaves, through the real ase::ui::sod_click
# ===========================================================================
# Select On Design marks the pin a click took (src/ase_window.tcl:
# ase::ui::sod_terminal_pick, ase::ui::dp_hilight, ase::ui::sod_end).  Here the
# mode is entered through its real entry, ase::ui::select_on_design; every
# click is the real ase::ui::sod_click with explicit schematic coordinates; the
# rows are queued by the real ase::ui::sod_queue into a real session that has
# no window, and Direct Plot's traces by the real ase::ui::dp_queue.  What is
# stood in for, and why:
#   - the bit dialog (ase::ui::bus_dialog): it is modal.  Its answer is
#     ::pg_dlg_answer, `all` or `none`;
#   - the notice sink (ciw_echo): recorded, so a row can say what a click said;
#   - in the Direct Plot rows, the three doors of the waveform viewer that
#     ase::ui::dp_finish goes through (wviewer::open, attach_raw, plot_signals):
#     recorded, so the colour list the viewer is handed can be read with no
#     viewer.  Band P opens the real one;
#   - on the counted arm only, the three Tk words select_on_design needs to
#     seize a canvas (winfo, bind, focus), inside namespace ase::ui and nowhere
#     else.  `winfo exists .pg_gone` answers 0 there, as the real one does.
# The real <ButtonPress-1> and <Key-Escape> bindings are driven in band P.
#
# pg_top.sch, instance order:
#   0 R9        res.sym       P (300,-30)  M (300,30)
#   1 R2        res.sym       P (500,-30)  M (500,30), a wire from M down to NETA
#   2 V1        vsource.sym   p (700,-30)  m (700,30)
#   3 RB, a two-bit bus instance of res.sym: two vectors per pin
#   4 l1        the label NETA
#   5 x1        the block of the engine bands (pm_blk), whose own sheet holds an R1
set pg_top [file join $scratch pg_top.sch]
wfile $pg_top "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 500 30 500 80 {lab=NETA}
C {res.sym} 300 0 0 0 {name=R9 value=1k}
C {res.sym} 500 0 0 0 {name=R2 value=1k}
C {vsource.sym} 700 0 0 0 {name=V1 value=1}
C {res.sym} 900 0 0 0 {name=RB\[1:0\] value=1k}
C {lab_pin.sym} 500 80 0 0 {name=l1 sig_type=std_logic lab=NETA}
C {[file join $scratch pm_blk.sym]} 1100 0 0 0 {name=x1}"
set PG_BUS {RB[1:0]}

set ::pg_notices {} ; set ::pg_dlg_asked {} ; set ::pg_dlg_answer all ; set ::pg_plotted {}
if {[info commands ciw_echo] ne {}} { rename ciw_echo pg_real_ciw_echo }
proc ciw_echo {msg args} { lappend ::pg_notices $msg }
rename ::ase::ui::bus_dialog ::ase::ui::pg_real_bus_dialog
proc ::ase::ui::bus_dialog {key token bits} {
    lappend ::pg_dlg_asked [list $token $bits]
    return [expr {$::pg_dlg_answer eq {all} ? $bits : {}}]
}
set pg_fake {}
if {[info commands ::winfo] eq {}} {
    proc ::ase::ui::winfo {sub args} { return [expr {$sub eq {exists} && [lindex $args 0] eq {.pg_gone} ? 0 : 1}] }
    proc ::ase::ui::bind {args} { return {} }
    proc ::ase::ui::focus {args} { return {} }
    set pg_fake {winfo bind focus}
}
# the viewer's three doors, recorded (on) or the real ones again (off)
proc pg_viewer_stub {on} {
    if {$on} {
        foreach p {open attach_raw plot_signals} { rename ::wviewer::$p ::wviewer::pg_real_$p }
        proc ::wviewer::open {args} { return 1 }
        proc ::wviewer::attach_raw {args} { return 0 }
        proc ::wviewer::plot_signals {args} { lappend ::pg_plotted $args ; return {} }
    } else {
        foreach p {open attach_raw plot_signals} { rename ::wviewer::$p {} ; rename ::wviewer::pg_real_$p ::wviewer::$p }
    }
}
# the header of a results file holding the vectors named, one point: all the
# reader of a file's header (ase::raw_vectors_present) needs
proc pg_rawtext {vectors} {
    set t "Title: * marker fixture\nDate: Thu Nov 19 00:00:00  2026\nPlotname: Transient Analysis\nFlags: real\n"
    append t "No. Variables: [expr {[llength $vectors] + 1}]\nNo. Points: 1\nVariables:\n\t0\ttime\ttime\n"
    set k 0
    foreach v $vectors { append t "\t[incr k]\t$v\tcurrent\n" }
    append t "Values:\n 0\t0.0\n"
    foreach v $vectors { append t "\t1.0e-3\n" }
    return $t
}
proc pg_scale {} { return [expr {[info commands tk] ne {} ? [tk scaling] : 1.0}] }
# the pin probe's radius, 12 scaled pixels, in schematic units; set, then read back
proc pg_set_radius {r} {
    pcall xschem origin - - [expr {$r / (12.0 * [pg_scale])}]
    return [expr {12.0 * [xschem get zoom] * [pg_scale]}]
}
# the fixture sheet shown, no mode, no marker, no row in the session
proc pg_fresh {} {
    catch {ase::ui::sod_end $::PGKEY}
    pcall xschem unselect_all
    pcall xschem set modified 0
    pcall xschem load $::pg_top
    pcall xschem pin_marker clear -fast
    set st [ase::session_state $::PGKEY]
    dict set st outputs {}
    ase::session_update $::PGKEY $st
    set ::pg_dlg_answer all
}
# enter the mode through its real entry: `outputs` is To Be Saved's flavour,
# `plot` is Direct Plot.  The design is the window in front already (the last
# argument), as it is for the key pressed on the design window.
proc pg_enter {mode} {
    return [pcall ase::ui::select_on_design $::PGKEY [expr {$mode eq {plot} ? {save 0 plot 1} : {save 1 plot 0}}] $mode 0]
}
# the script the mode binds on the left press and on the double click
proc pg_press {} { return "xschem callback %W 6 %x %y 0 0 0 %s; [list ase::ui::sod_click $::PGKEY]; break" }
# one real click at schematic coordinates; the notices it made are ::pg_notices
proc pg_click {x y} {
    set ::pg_notices {} ; set ::pg_dlg_asked {}
    return [pcall ase::ui::sod_click $::PGKEY $x $y]
}
proc pg_at {inst pin} { return [pg_click {*}[pm_coord $inst $pin]] }
# the list without its points: {instname pin layer tag} per marker
proc pg_marks {} { return [lmap r [pm_list] { lrange $r 1 4 }] }
# the session's rows, by their expressions
proc pg_outputs {} {
    return [lmap o [ase::state_get [ase::session_state $::PGKEY] outputs] { ase::state_get $o expr }]
}
proc pg_mode {} { return [expr {[info exists ::ase::ui::sod(active)] ? 1 : 0}] }

group G0 {
    # the terminal names below fold: not under whoever's simulator registry is live
    test_sim_registry_isolate
    check "G0a the ASE-L rows run against an empty simulator registry, not the one in ~/.xschem" \
        [test_sim_registry_state] {0 {} {} path}
    pcall xschem load $pg_top
    set PGKEY [pcall ase::new_session pmlib pg_top schematic]
    set pg_st [pcall ase::session_state $PGKEY]
    # a run directory of its own, and a transient analysis: Direct Plot has
    # nothing to plot for an operating point
    dict set pg_st rundir [file join $scratch pgrun]
    dict set pg_st analyses {{type op enabled 0} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1}}
    pcall ase::session_update $PGKEY $pg_st
    set pg_raw [pcall [ase::backend_hook ngspice raw_file] [pcall ase::session_state $PGKEY]]
    file mkdir [file dirname $pg_raw]
    check "G0b fixture: the sheet reads back its six instances in file order; the session has no window, no results yet and a transient analysis to plot; and the pin rule finds R9's P pin at its point" \
        [list [lmap i {0 1 2 3 4 5} { pcall xschem getprop instance $i name }] [pcall ase::ui::window_for $PGKEY] \
              [pcall ase::last_rawfile $PGKEY] [pcall ase::plot_sim_type [pcall ase::session_state $PGKEY]] \
              [pcall apply {{key c} { set t [ase::ui::sod_terminal_at $key {*}$c] ; list [dict get $t instname] [dict get $t pinname] [dict get $t inst] [dict get $t pin] }} $PGKEY [pm_coord R9 P]]] \
        [list [list R9 R2 V1 $PG_BUS l1 x1] {} {} tran {R9 P 0 0}]
}

group G1 {
    pg_fresh
    set entered [pg_enter outputs]
    set before [pm_list]
    pg_at R9 P
    set said $::pg_notices
    check "G1a A ROW-FLAVOUR PICK MARKS ITS PIN: with the mode entered through ase::ui::select_on_design in To Be Saved's flavour and no marker listed, ONE click of the real ase::ui::sod_click on R9's P pin queues the terminal's row into the session, says so, and lists one marker -- this sheet's path, the instance's name, the pin's index, layer 16, the tag `save`, the pin's point" \
        [list $entered $before [pg_outputs] $said [pm_list]] \
        [list 1 {} {i(r9:n1)} [list "ase: queued output 'i(r9:n1)' (added)"] [list [list . R9 0 16 save {*}[pm_coord R9 P]]]]
    pg_at R9 P
    set said2 $::pg_notices
    set rows2 [llength [pm_list]]
    pcall xschem pin_marker clear -fast
    set cleared [pm_list]
    pg_at R9 P
    check "G1b ALREADY QUEUED STILL MARKS: the same pin clicked again says `already queued` and adds neither a row nor a second marker; and with the marker taken away in between, the click that queues nothing puts it back (what the second click said; markers after it; markers once cleared; then the rows, what the third click said, and the markers)" \
        [list $said2 $rows2 $cleared [pg_outputs] $::pg_notices [pg_marks]] \
        [list [list "ase: output 'i(r9:n1)' already queued"] 1 {} {i(r9:n1)} [list "ase: output 'i(r9:n1)' already queued"] {{R9 0 16 save}}]
    pg_at R9 M
    check "G1c the OTHER pin of the same instance is its own row and its own marker, listed after the first" \
        [list [pg_outputs] [pg_marks]] {{i(r9:n1) i(r9:n2)} {{R9 0 16 save} {R9 1 16 save}}}
    # To Be Plotted's flavour: the same mode, a row that is also plotted
    pg_fresh
    set entered [pcall ase::ui::select_on_design $PGKEY {save 1 plot 1} outputs 0]
    pg_at R9 P
    set rows [lmap o [ase::state_get [ase::session_state $PGKEY] outputs] { list [ase::state_get $o expr] [ase::state_get $o plot] [ase::state_get $o save] }]
    set marked [pg_marks]
    pcall ase::ui::sod_end $PGKEY
    check "G1d EVERY FLAVOUR THAT WRITES ROWS marks alike: entered in To Be Plotted's flavour, the pick's row is saved AND plotted, its marker is the same as To Be Saved's -- layer 16, the tag `save` -- and the mode's end takes it away" \
        [list $entered $rows $marked [pm_list]] {1 {{i(r9:n1) 1 1}} {{R9 0 16 save}} {}}
}

group G2 {
    pg_fresh
    pg_enter outputs
    set radius [pg_set_radius 8]
    pg_at R9 P
    set base [pm_list]
    # a refused pick
    set ::flat_netlist 1
    pg_at R2 P
    set ::flat_netlist 0
    set refused [list [llength $::pg_notices] \
                      [string match {ase: cannot name the terminal current of R2 pin P — flat netlisting*; place an ammeter (ammeter.sym) in series} [lindex $::pg_notices 0]] \
                      [expr {[pm_list] eq $base}]]
    # the bit dialog, cancelled
    set ::pg_dlg_answer none
    pg_at $PG_BUS P
    set cancelled [list [llength $::pg_dlg_asked] $::pg_notices [expr {[pm_list] eq $base}]]
    set ::pg_dlg_answer all
    # empty canvas
    pg_click 20000 20000
    set empty [list [pcall xschem object_at 20000 20000] $::pg_notices [expr {[pm_list] eq $base}]]
    # the body of a device that is no source
    pg_click 500 0
    set body [list [lindex [pcall xschem object_at 500 0] 0] [llength $::pg_notices] \
                   [string match {ase: nothing to queue there*} [lindex $::pg_notices 0]] [expr {[pm_list] eq $base}]]
    check "G2a NOTHING IS MARKED by a pick that queues nothing: a refused pin (flat netlisting on: one refusal), a bit dialog that is cancelled (asked once, nothing said), a click on empty canvas (nothing there, nothing said) and a click on the body of a resistor (an instance, the one `nothing to queue there` notice) each leave the list exactly as it was, with its one marker" \
        [list [llength $base] $refused $cancelled $empty $body [pg_outputs]] \
        {1 {1 1 1} {1 {} 1} {{} {} 1} {instance 1 1 1} i(r9:n1)}
    # a voltage pick on a wire, beside a pin that is in range
    lassign [pm_coord R2 M] mx my
    set wy [expr {$my + 6}]
    set inrange 0
    foreach r [pcall xschem pin_at $mx $wy -all] { if {[lindex $r 2] eq {R2} && [lindex $r 3] eq {M}} { set inrange 1 } }
    pg_click $mx $wy
    set wire [list [lindex [pcall xschem object_at $mx $wy] 0] [pcall ase::ui::sod_terminal_at $PGKEY $mx $wy] \
                   $::pg_notices [expr {[pm_list] eq $base}]]
    # the body of a source: its branch current
    pg_click 700 0
    set source [list $::pg_notices [expr {[pm_list] eq $base}]]
    check "G2b ...nor by a pick that queues something else than a terminal: a click ON THE WIRE six units below R2's M pin -- the pin is within the probe's radius there, which is set to eight units, and the pin rule still answers that this is the wire -- queues the net's voltage, and a click on the BODY of the source queues its branch current; the list is as it was after both, and the two rows are in the session beside the terminal's" \
        [list [expr {abs($radius - 8.0) < 0.01}] $inrange $wire $source [pg_outputs]] \
        [list 1 1 [list wire {} [list "ase: queued output 'v(neta)' (added)"] 1] [list [list "ase: queued output 'i(v1)' (added)"] 1] {i(r9:n1) v(neta) i(v1)}]
    # ...while on the pin's own square the same pin is the terminal
    pg_click $mx [expr {$my + 2}]
    check "G2c CONTROL for G2b: two units below that pin, inside the pin's own square, the click is the terminal -- its row is queued and the pin is marked, beside the first marker" \
        [list $::pg_notices [pg_marks]] \
        [list [list "ase: queued output 'i(r2:n2)' (added)"] {{R9 0 16 save} {R2 1 16 save}}]
}

group G3 {
    pg_fresh
    pg_enter outputs
    set ::pg_dlg_answer all
    pg_at $PG_BUS P
    check "G3 SEVERAL VECTORS, ONE MARKER: a pin of the two-bit bus instance goes through the bit dialog once, both bits it returns are queued as rows, and the pin on the sheet carries ONE marker" \
        [list [llength $::pg_dlg_asked] [pg_outputs] [pg_marks]] \
        [list 1 {{i(rb[1]:n1)} {i(rb[0]:n1)}} [list [list $PG_BUS 0 16 save]]]
}

group G4 {
    pg_fresh
    set first [pcall xschem get current_win_path]
    pg_enter outputs
    pg_at R9 P
    # two markers that are not the mode's: one as a Direct Plot leaves it, one a
    # script's own
    pcall xschem pin_marker add -fast -layer 7 -tag plot R2 P
    pcall xschem pin_marker add -fast R2 M
    # ...and in a second window context: one as a pick made after the mode had
    # moved there would leave it, and one of Direct Plot's
    pcall xschem new_schematic create {} $pm_other
    set second [pcall xschem get current_win_path]
    pcall xschem pin_marker add -fast -tag save R1 P
    pcall xschem pin_marker add -fast -layer 7 -tag plot R1 M
    set had2 [pg_marks]
    pcall xschem new_schematic switch $first
    set had1 [pg_marks]
    set armed [pg_mode]
    set ::pg_notices {}
    set ended [pcall ase::ui::sod_end $PGKEY]
    set said $::pg_notices
    set left1 [pg_marks]
    pcall xschem new_schematic switch $second
    set left2 [pg_marks]
    pcall xschem new_schematic destroy $second {}
    check "G4 THE MODE ENDING TAKES THE ROW FLAVOUR'S MARKERS AWAY, IN EVERY WINDOW, AND ONLY THOSE: with the mode's marker in this window beside one tagged `plot` and one untagged, and in a second window context one tagged `save` and one tagged `plot`, ase::ui::sod_end ends the mode, says its one sentence, and leaves the `plot` and the untagged markers of both windows and nothing else" \
        [list [expr {$second ne $first}] $had1 $had2 $armed $ended [pg_mode] $said $left1 $left2] \
        [list 1 {{R9 0 16 save} {R2 0 7 plot} {R2 1 16 {}}} {{R1 0 16 save} {R1 1 7 plot}} 1 {} 0 \
              [list "ase: Select On Design ended — 1 output(s) queued"] {{R2 0 7 plot} {R2 1 16 {}}} {{R1 1 7 plot}}]
}

group G4b {
    pg_fresh
    pg_enter outputs
    pg_at R9 P
    # down into the block with the mode up, and a pick there
    pcall xschem unselect_all ; pcall xschem select instance x1
    pcall xschem descend
    set below [pcall xschem get sch_path]
    pg_at R1 P
    set said $::pg_notices
    set there [lmap r [pm_list] { list [lindex $r 0] [lindex $r 1] [lindex $r 2] [lindex $r 4] [pm_xy $r] }]
    set r1 [pm_coord R1 P]
    pcall xschem go_back
    set up [lmap r [pm_list] { list [lindex $r 0] [lindex $r 1] [pm_xy $r] }]
    set r9 [pm_coord R9 P]
    pcall ase::ui::sod_end $PGKEY
    check "G4b A PICK MADE ON A SHEET BELOW, after a descend with the mode up: the row carries the block's path, and the marker is keyed by THAT sheet's path and has its point there while the top sheet's has none; back on top it is the other way round; and the mode ending from the top sheet sweeps both (the path below; what the pick said; the two markers as listed below; as listed on top; the list after the end)" \
        [list $below $said $there $up [pm_list] [expr {$r1 ne $r9}]] \
        [list .x1. [list "ase: queued output 'i(x1.r1:n1)' (added)"] \
              [list [list . R9 0 save {{} {}}] [list .x1. R1 0 save $r1]] \
              [list [list . R9 $r9] [list .x1. R1 {{} {}}]] {} 1]
}

group G5 {
    pg_fresh
    pg_enter outputs
    pg_at R9 P
    set m1 [pg_marks]
    # entering the mode again ends the one that is up
    set again [pg_enter outputs]
    set m2 [pg_marks]
    pg_at R9 M
    set m3 [pg_marks]
    # the mode is suspended (a descend does that) and the window it was on goes
    set suspended [pcall ase::ui::sod_suspend]
    set m4 [pg_marks]
    set ase::ui::sod($PGKEY,canvas) .pg_gone
    set resumed [pcall ase::ui::sod_resume .pg_gone]
    check "G5 THE OTHER WAYS THE MODE ENDS: a second entry ends the mode that is up, and its marker is gone before the new mode's first click; a mode that is only SUSPENDED keeps its marker; and when the window it was on is gone at the resume, the mode is dropped and its marker with it (markers after the first pick; the second entry's answer and the markers after it; after a pick in the new mode; suspended, and the markers then; the resume's answer, the markers, and whether a mode is still up)" \
        [list $m1 $again $m2 $m3 $suspended $m4 $resumed [pg_marks] [pg_mode]] \
        {{{R9 0 16 save}} 1 {} {{R9 1 16 save}} 1 {{R9 1 16 save}} 0 {} 0}
    # the session window closing: it needs a window, so it is read, not driven
    set closecode {}
    foreach l [split [info body ::ase::ui::close] "\n"] { if {![regexp {^\s*#} $l]} { append closecode $l "\n" } }
    check "G5b (text) the session window's close ends the mode through that same proc: the code of ase::ui::close, its comment lines left out, calls ase::ui::sod_end with the session's key" \
        [regexp {ase::ui::sod_end \$key} $closecode] 1
}

group G6 {
    pg_fresh
    wfile $pg_raw [pg_rawtext {i(r9:n1) i(r2:n1) i(v1)}]
    pg_viewer_stub 1
    set ::pg_plotted {}
    set entered [pg_enter plot]
    pg_at R9 P
    set q1 $ase::ui::sod($PGKEY,queue)
    set c1 $ase::ui::sod($PGKEY,qcolors)
    check "G6a A DIRECT PLOT PICK MARKS ITS PIN IN THE TRACE'S LAYER: with results that hold the vector, one click on R9's P pin queues the trace and lists one marker, tagged `plot`, on the layer the plot queue chose for that trace -- a layer number above 0 -- and writes no row into the session" \
        [list $entered [pcall ase::raw_vectors_present $pg_raw {i(r9:n1) i(r9:n2)}] $q1 [llength $c1] \
              [expr {[string is integer -strict [lindex $c1 0]] && [lindex $c1 0] > 0}] [pm_list] [pg_outputs]] \
        [list 1 i(r9:n1) i(r9:n1) 1 1 [list [list . R9 0 [lindex $c1 0] plot {*}[pm_coord R9 P]]] {}]
    # a vector the results do not hold
    pg_at R9 M
    set absent [list [llength $::pg_notices] \
                     [string match {ase: terminal current 'i(r9:n2)' is not in this session's results*} [lindex $::pg_notices 0]] \
                     [llength [pm_list]]]
    # the pin of a source whose terminal the results do not hold: the stand-in
    pg_at V1 p
    set standin [list $ase::ui::sod($PGKEY,queue) [llength [pm_list]]]
    check "G6b nothing is marked by a Direct Plot pick whose vector the results do NOT hold (it says its one sentence), nor by the pin of a source whose terminal they do not hold: there the source's branch current is queued in its place, and no pin is marked" \
        [list $absent $standin] {{1 1 1} {{i(r9:n1) i(v1)} 1}}
    pg_at R2 P
    set c3 $ase::ui::sod($PGKEY,qcolors)
    set want [list [list R9 0 [lindex $c3 0] plot] [list R2 0 [lindex $c3 2] plot]]
    check "G6c a second pin gets ITS trace's layer: three traces are queued, their three layers differ, and each of the two pins carries the layer of its own" \
        [list $ase::ui::sod($PGKEY,queue) [llength $c3] [llength [lsort -unique $c3]] [pg_marks]] \
        [list {i(r9:n1) i(v1) i(r2:n1)} 3 3 $want]
    set ended [pcall ase::ui::sod_end $PGKEY]
    check "G6d DIRECT PLOT'S MARKERS OUTLIVE THE MODE, AND THEIR LAYERS ARE THE TRACES' COLOURS: after ase::ui::sod_end the mode is over and both markers are listed as they were; and what the waveform viewer was handed, once, is the three traces with the colour list of the queue -- the list each marker's layer was taken from" \
        [list $ended [pg_mode] [pg_marks] [llength $::pg_plotted] [lrange [lindex $::pg_plotted 0] 0 3]] \
        [list {} 0 $want 1 [list $PGKEY {i(r9:n1) i(v1) i(r2:n1)} $c3 append]]
    pcall xschem unhilight_all
    check "G6e ...until the highlights are cleared: `xschem unhilight_all` empties the list" [pm_list] {}
    pg_viewer_stub 0
    file delete -force $pg_raw
}

group G7 {
    pg_fresh
    wfile $pg_raw [pg_rawtext {i(r9:n1)}]
    pg_viewer_stub 1
    set ::pg_plotted {}
    set ::pg_refused 0
    rename ::xschem ::pg_xschem_real
    proc ::xschem {args} {
        if {[lindex $args 0] eq {pin_marker}} { incr ::pg_refused ; error {pin_marker: not in this build} }
        return [uplevel 1 [linsert $args 0 ::pg_xschem_real]]
    }
    set got [list [pg_enter outputs] [pg_at R9 P] $::pg_notices [pg_outputs]]
    set asked1 $::pg_refused
    lappend got [pcall ase::ui::sod_end $PGKEY] [pg_mode]
    set asked2 $::pg_refused
    lappend got [pg_enter plot] [pg_at R9 P] $ase::ui::sod($PGKEY,queue)
    set asked3 $::pg_refused
    lappend got [pcall ase::ui::sod_end $PGKEY] [pg_mode] [llength $::pg_plotted]
    rename ::xschem {}
    rename ::pg_xschem_real ::xschem
    pg_viewer_stub 0
    file delete -force $pg_raw
    check "G7 A MARKER NEVER BREAKS THE PICK: with the engine refusing every `pin_marker` command, a row-flavour pick still queues its row and says only that, the mode still ends, a Direct Plot pick still queues its trace and the plot still goes to the viewer -- no call raised -- and the engine WAS asked at each step: for the row's marker, for the sweep at the mode's end, for the trace's marker (the answers in order; then that each step added to the count of refused commands)" \
        [list $got [expr {$asked1 > 0}] [expr {$asked2 > $asked1}] [expr {$asked3 > $asked2}]] \
        [list [list 1 {} [list "ase: queued output 'i(r9:n1)' (added)"] i(r9:n1) {} 0 1 {} i(r9:n1) {} 0 1] 1 1 1]
}

# the stand-ins of band G go; the notice recorder stays for band P's ASE rows
foreach c $pg_fake { rename ::ase::ui::$c {} }
set pg_fake {}

# ===========================================================================
# P — DISPLAY ONLY: the pixels, and the doors that need Tk
# ===========================================================================
if {!$has_display} {
    puts "skip: P -- band P (the marker's pixels, and the doors that need Tk) reads the window: no display on this arm, so none of its rows ran"
} else {

# the window's pixels are read in process through `xschem window_snapshot`
proc pm_settle {} { update ; after 40 ; update }
proc pm_snap {slot} { pm_settle ; return [pcall xschem window_snapshot take $slot] }
# schematic -> window pixel (X_TO_SCREEN in src/xschem.h), unrounded
proc pm_w2s {x y} {
    return [list [expr {($x + [xschem get xorigin]) / [xschem get zoom]}] \
                 [expr {($y + [xschem get yorigin]) / [xschem get zoom]}]]
}
# the engine's size rule, read NOW: half-width in pixels, and the stroke
proc pm_a_px {} { return [expr {max(5.0, 3.0 * [xschem get zoom] * [tk scaling]) / [xschem get zoom]}] }
proc pm_stroke {} { return [expr {[tk scaling] >= 1.25 ? 2 : 1}] }
proc pm_colour {layer} { return [string tolower [lindex $::tctx::colors $layer]] }
# `window_snapshot diff a b` as a dict: n, the box, its centre, width and height
proc pm_diff {a b} {
    set d [pcall xschem window_snapshot diff $a $b]
    if {[llength $d] != 5 || ![string is integer -strict [lindex $d 0]]} { return [dict create n "BAD:$d"] }
    lassign $d n x1 y1 x2 y2
    return [dict create n $n x1 $x1 y1 $y1 x2 $x2 y2 $y2 \
                cx [expr {($x1 + $x2) / 2.0}] cy [expr {($y1 + $y2) / 2.0}] \
                w [expr {$x2 - $x1 + 1}] h [expr {$y2 - $y1 + 1}]]
}
proc pm_get {d k} { return [expr {[dict exists $d $k] ? [dict get $d $k] : "NOKEY:$k"}] }
# |a - b| <= tol for two numbers; 0 when either is not one
proc pm_close {a b tol} {
    return [expr {[string is double -strict $a] && [string is double -strict $b] && abs($a - $b) <= $tol ? 1 : 0}]
}
# does capture `slot` hold `colour` anywhere in the square of half-side r round
# the (unrounded) pixel (x,y)?
proc pm_at {slot x y r colour} {
    set px [pcall xschem window_snapshot pixels $slot [expr {int(floor($x + 0.5)) - $r}] \
                [expr {int(floor($y + 0.5)) - $r}] [expr {2 * $r + 1}] [expr {2 * $r + 1}]]
    foreach row $px { foreach c $row { if {[string tolower $c] eq $colour} { return 1 } } }
    return 0
}
# THE MEASUREMENT every geometry row uses: what the window gains when ONE marker
# is added at the present view.  Slot 0 is the view without it, slot 1 with it.
# Answers a dict: the diff of the two, the colours gained, the pin's pixel, and
# the size the engine's rule predicts.
proc pm_measure {args} {
    pcall xschem pin_marker clear
    pm_snap 0
    set added [pcall xschem pin_marker add {*}$args]
    pm_snap 1
    set row [lindex [pm_list] end]
    set d [pm_diff 0 1]
    if {[llength $row] == 7 && [string is double -strict [lindex $row 5]]} {
        lassign [pm_w2s [lindex $row 5] [lindex $row 6]] px py
    } else { set px NOPOINT; set py NOPOINT }
    dict set d added $added
    dict set d colours [lmap {c n} [pcall xschem window_snapshot colors 0 1] { string tolower $c }]
    dict set d px $px ; dict set d py $py
    dict set d a [pm_a_px] ; dict set d s [pm_stroke]
    return $d
}
# the verdicts of one measurement, as a list of 0/1:
#   something was painted; every painted pixel is the layer's colour; the box is
#   centred on the pin (to 1.5 px); its width is 2a + stroke and its height
#   4a + stroke (each to 2 px); it is at least one and a half times as tall as wide
proc pm_verdict {d layer} {
    set a [pm_get $d a] ; set s [pm_get $d s]
    set w [pm_get $d w] ; set h [pm_get $d h]
    return [list [expr {[string is integer -strict [pm_get $d n]] && [pm_get $d n] > 0 ? 1 : 0}] \
                 [expr {[pm_get $d colours] eq [list [pm_colour $layer]] ? 1 : 0}] \
                 [pm_close [pm_get $d cx] [pm_get $d px] 1.5] [pm_close [pm_get $d cy] [pm_get $d py] 1.5] \
                 [pm_close $w [expr {2 * $a + $s}] 2] [pm_close $h [expr {4 * $a + $s}] 2] \
                 [expr {[string is double -strict $w] && [string is double -strict $h] && $h >= 1.5 * $w ? 1 : 0}]]
}

# the window manager on this display, by the root window's own record of it:
# its name, `none` when the root names no manager, `not read` when xprop gave
# no answer
proc pm_wm_name {} {
    if {[catch {exec timeout 5 xprop -root _NET_SUPPORTING_WM_CHECK 2>@1} r]} { return {not read} }
    if {![regexp {window id # (0x[0-9a-fA-F]+)} $r -> wid]} { return none }
    if {[catch {exec timeout 5 xprop -id $wid _NET_WM_NAME 2>@1} r] || ![regexp {= "(.*)"} $r -> name]} { return unnamed }
    regsub -all {[^A-Za-z0-9 ._-]} $name {} name
    return $name
}
# the toplevels of THIS application that hide part of canvas `cv`: mapped,
# stacked above cv's own toplevel, and their frame meets cv's rectangle.  The
# pixel rows read the window, so a covered canvas reads as a marker that was
# not drawn.  A window of another program is not seen from here.
proc pm_covering {cv} {
    set top [winfo toplevel $cv]
    set order [wm stackorder .]
    set me [lsearch -exact $order $top]
    if {$me < 0} { return "NOT-MAPPED:$top" }
    set ax1 [winfo rootx $cv] ; set ay1 [winfo rooty $cv]
    set ax2 [expr {$ax1 + [winfo width $cv]}] ; set ay2 [expr {$ay1 + [winfo height $cv]}]
    set out {}
    foreach w [lrange $order [expr {$me + 1}] end] {
        # the frame: the decoration's width is the client area's offset in it
        set m [expr {[winfo rootx $w] - [winfo x $w]}]
        set bx1 [winfo x $w] ; set by1 [winfo y $w]
        set bx2 [expr {[winfo rootx $w] + [winfo width $w] + $m}]
        set by2 [expr {[winfo rooty $w] + [winfo height $w] + $m}]
        if {$ax1 < $bx2 && $bx1 < $ax2 && $ay1 < $by2 && $by1 < $ay2} { lappend out $w }
    }
    return $out
}
# bring the context of canvas `cv` in front -- the current one, its window on
# top -- and answer what still covers it.  The switch is asked NOT to redraw
# (its last word): a switch to the main window otherwise repaints it, and a row
# that reads a window after a command given in another one must see what that
# command left on the screen, not what the switch then drew.
proc pm_show {cv} {
    pcall xschem new_schematic switch $cv {} 0
    raise [winfo toplevel $cv]
    pm_settle ; pm_settle
    return [pm_covering $cv]
}

set ::hover_highlight 0
set ::draw_crosshair 0
wm geometry . 900x700+0+0
# The CIW is a toplevel of its own, mapped whenever the action log is on.  A
# window manager stacks it under the design window; with none it lies on top
# of the canvas, over the pins this band measures.  No row here reads it.
catch {wm withdraw .ciw}
update
# the dark scheme, the default, pinned: the colour rows name the scheme they read
if {!$::dark_colorscheme} { xschem toggle_colorscheme }

group P0 {
    pm_fresh ; pm_settle
    set wm [pm_wm_name]
    set cv [pcall xschem get current_win_path]
    check "P0 fixture: NOTHING COVERS THE DESIGN CANVAS (window manager on this display: $wm): the design window is mapped, and no other window of this application lies over its canvas -- every pixel row below reads the window, so a canvas that is covered would show as markers that were not drawn (the canvas is a window; the windows covering it)" \
        [list [winfo exists $cv] [expr {[winfo exists $cv] ? [pm_covering $cv] : {NO-CANVAS}}]] {1 {}}
}

group P1 {
    pm_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 600 100
    pcall xschem redraw ; pm_settle
    set z1 [xschem get zoom]
    set M [pm_measure R1 P]
    check "P1 fixture: at this view the pin's box is a few pixels wide, so the ellipse takes its 5-unit size and not the 3-pixel floor, and the default layer's colour differs from the background's" \
        [list [expr {5.0 > 3.0 * $z1 * [tk scaling]}] [expr {[pm_colour 16] ne [pm_colour 0]}]] {1 1}
    check "P1a adding a marker on R1's P pin paints an ELLIPSE ROUND THE PIN in the default layer's colour and nothing else: pixels were gained; every one is layer 16's colour; the box they span is centred on the pin's pixel, is 2a + stroke wide and 4a + stroke tall, and is taller than wide" \
        [pm_verdict $M 16] {1 1 1 1 1 1 1}
    set px [pm_get $M px] ; set py [pm_get $M py] ; set a [pm_get $M a]
    set col [pm_colour 16]
    check "P1b point by point: the colour is there straight ABOVE and BELOW the pin at the half-height, and to its LEFT and RIGHT at the half-width; it is NOT there left or right at the half-height's distance, nor on the pin itself -- an upright ring, not a disc and not a circle" \
        [list [pm_at 1 $px [expr {$py - 2 * $a}] 2 $col] [pm_at 1 $px [expr {$py + 2 * $a}] 2 $col] \
              [pm_at 1 [expr {$px - $a}] $py 2 $col] [pm_at 1 [expr {$px + $a}] $py 2 $col] \
              [pm_at 1 [expr {$px - 2 * $a}] $py 2 $col] [pm_at 1 [expr {$px + 2 * $a}] $py 2 $col] \
              [pm_at 1 $px $py 1 $col]] \
        {1 1 1 1 0 0 0}
    check "P1c CONTROL for P1b: before the add the same four places held none of that colour" \
        [list [pm_at 0 $px [expr {$py - 2 * $a}] 2 $col] [pm_at 0 $px [expr {$py + 2 * $a}] 2 $col] \
              [pm_at 0 [expr {$px - $a}] $py 2 $col] [pm_at 0 [expr {$px + $a}] $py 2 $col]] {0 0 0 0}

    # the backing pixmap: written to a PNG by the highlight test hook and read
    # back through a Tk photo
    set png [file join $scratch pixmap.png]
    pcall xschem net_hilight_dump_pixmap $png
    set inpix NOPNG
    if {[file exists $png] && ![catch {image create photo pm_img -file $png}]} {
        set inpix 0
        set want [lmap {r g b} [scan $col "#%2x%2x%2x"] { list $r $g $b }]
        set x [expr {int(floor($px + 0.5))}]
        for {set dy -2} {$dy <= 2} {incr dy} {
            set y [expr {int(floor($py - 2 * $a + 0.5)) + $dy}]
            if {[list [pcall pm_img get $x $y]] eq $want} { set inpix 1 }
        }
        image delete pm_img
    }
    check "P1d the marker is in the BACKING PIXMAP as well as in the window: the pixmap, dumped to a file, holds the layer's colour at the top of the ellipse" \
        $inpix 1

    set d0 [pcall xschem get drawcount]
    pcall xschem redraw
    pm_snap 2
    check "P1e it survives a full redraw: the window after `xschem redraw` equals the window after the add, pixel for pixel, and a redraw did run" \
        [list [pm_get [pm_diff 1 2] n] [expr {[pcall xschem get drawcount] > $d0}]] {0 1}

    # an expose: cover the marker with a window of our own, take it away, and let
    # xschem repair the damage -- which it does from the pixmap, with no draw()
    set rx [expr {[winfo rootx .drw] + int($px) - 60}] ; set ry [expr {[winfo rooty .drw] + int($py) - 60}]
    toplevel .pmcover -background #303030
    wm overrideredirect .pmcover 1
    wm geometry .pmcover 120x120+$rx+$ry
    raise .pmcover ; pm_settle
    pm_snap 3
    set d0 [pcall xschem get drawcount]
    destroy .pmcover ; pm_settle
    pm_snap 4
    check "P1f it survives an EXPOSE: while another window covers it the capture differs from the uncovered one, and once that window is gone the canvas is the same as before, pixel for pixel, with NO draw() run in between -- the repair is a copy from the pixmap, which holds the marker (pixels differing while covered are some; differing after; draws)" \
        [list [expr {[string is integer -strict [pm_get [pm_diff 1 3] n]] && [pm_get [pm_diff 1 3] n] > 0}] \
              [pm_get [pm_diff 1 4] n] [expr {[pcall xschem get drawcount] - $d0}]] {1 0 0}

    # a window-only overlay drawn over the marker and taken away again: the
    # styled selection paints on the window and erases itself by copying the
    # pixmap back, which holds the marker
    set d0 [pcall xschem get drawcount]
    pcall xschem select instance R1 ; pm_settle
    pm_snap 7
    pcall xschem unselect_all ; pm_settle
    pm_snap 4
    check "P1h it survives a selection drawn over it and taken away: with R1 selected the window differs from the unselected one, and unselected again it is the window after the add, pixel for pixel (pixels differing while selected are some; differing after)" \
        [list [expr {[string is integer -strict [pm_get [pm_diff 1 7] n]] && [pm_get [pm_diff 1 7] n] > 0}] \
              [pm_get [pm_diff 1 4] n]] {1 0}

    pcall xschem unhilight_all
    pm_snap 5
    check "P1g `xschem unhilight_all` erases it: the window is the one captured BEFORE the add, pixel for pixel, and the list is empty" \
        [list [pm_get [pm_diff 0 5] n] [pm_list]] {0 {}}
}

group P2 {
    pm_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 600 100
    pcall xschem redraw ; pm_settle
    pcall xschem pin_marker add R1 P
    pm_snap 6
    # PAN: the marker stays in the list while the view moves; what the window
    # then shows is measured against the same view with the marker taken away
    pcall xschem origin [expr {[xschem get xorigin] + 70}] [expr {[xschem get yorigin] - 40}]
    pcall xschem redraw
    pm_snap 1
    lassign [pm_w2s {*}[pm_xy [pm_row R1 0]]] px py
    pcall xschem pin_marker clear
    pm_snap 0
    set d [pm_diff 0 1]
    check "P2a after a PAN the marker is drawn at the pin's NEW pixel, the same size: the pixels the panned window owes to it are centred there, and the pin's pixel did move (centre x, centre y; 2a + stroke wide; the pin pixel is not where a marker was drawn before the pan)" \
        [list [pm_close [pm_get $d cx] $px 1.5] [pm_close [pm_get $d cy] $py 1.5] \
              [pm_close [pm_get $d w] [expr {2 * [pm_a_px] + [pm_stroke]}] 2] \
              [pm_at 6 $px [expr {$py - 2 * [pm_a_px]}] 2 [pm_colour 16]]] {1 1 1 0}

    pcall xschem zoom_box 200 -100 600 100
    pcall xschem redraw ; pm_settle
    # a MOVED instance takes its marker along: the marker is added first, the
    # instance moved after, and the moved view is measured against the same view
    # with the marker taken away
    pcall xschem pin_marker add R1 P
    set before_move [pm_xy [pm_row R1 0]]
    pcall xschem unselect_all ; pcall xschem select instance R1
    pcall xschem move_objects 40 30
    pcall xschem unselect_all
    pcall xschem redraw
    pm_snap 1
    set after_move [pm_xy [pm_row R1 0]]
    lassign [pm_w2s {*}$after_move] px py
    pcall xschem pin_marker clear
    pm_snap 0
    set d [pm_diff 0 1]
    check "P2e a MOVED instance takes its marker along on the screen: after the move the marker's pixels are centred on the pin's new pixel, and the pin did move (the point changed; centre x, centre y; only the layer's colour was gained)" \
        [list [expr {$after_move ne $before_move}] [pm_close [pm_get $d cx] $px 1.5] [pm_close [pm_get $d cy] $py 1.5] \
              [lmap {c n} [pcall xschem window_snapshot colors 0 1] { string tolower $c }]] \
        [list 1 1 1 [list [pm_colour 16]]]
    pm_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 600 100
    pcall xschem redraw ; pm_settle
    set mid [pm_measure R1 P]
    # ZOOM IN: the ellipse is a size in schematic units, so it grows in pixels
    pcall xschem zoom_box 250 -80 350 20
    pcall xschem redraw ; pm_settle
    set near [pm_measure R1 P]
    check "P2b zoomed IN, the ellipse keeps its size in schematic units and so grows on the screen: the same verdicts hold with the size re-read at this zoom (painted; colour; centred x, y; width; height; taller than wide)" \
        [pm_verdict $near 16] {1 1 1 1 1 1 1}
    # ZOOM FAR OUT: the 3-pixel floor
    pcall xschem zoom_box -4000 -3000 4500 3000
    pcall xschem redraw ; pm_settle
    set far [pm_measure R1 P]
    check "P2c zoomed FAR OUT, the size is the 3-pixel floor and not 5 units: at this zoom 5 units is under one pixel, the predicted half-width is three scaled pixels, and the same verdicts hold" \
        [list [expr {5.0 / [xschem get zoom] < 1.0}] [pm_close [pm_get $far a] [expr {3.0 * [tk scaling]}] 1e-9] \
              [pm_verdict $far 16]] {1 1 {1 1 1 1 1 1 1}}
    check "P2d the three views really differ in size: measured again at the first view (its verdicts), the box is widest zoomed in and narrowest zoomed far out, by more than the rows' tolerance" \
        [list [pm_verdict $mid 16] [expr {[pm_get $near w] - [pm_get $mid w] > 4}] \
              [expr {[pm_get $mid w] - [pm_get $far w] > 4}]] {{1 1 1 1 1 1 1} 1 1}
}

group P3 {
    pm_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 600 100
    pcall xschem redraw ; pm_settle
    set m7 [pm_measure -layer 7 R1 P]
    check "P3a -layer chooses the colour: a marker on layer 7 is layer 7's colour, which is not layer 16's" \
        [list [pm_verdict $m7 7] [expr {[pm_colour 7] ne [pm_colour 16]}]] {{1 1 1 1 1 1 1} 1}
    # ROTATION: the ellipse is upright on the screen whatever the instance does
    pcall xschem pin_marker clear
    pcall xschem unselect_all ; pcall xschem select instance R1
    pcall xschem rotate 300 0
    pcall xschem unselect_all
    pcall xschem redraw ; pm_settle
    set rot [pm_measure R1 P]
    check "P3b on a ROTATED instance the ellipse is still upright: R1 turned a quarter turn has its P pin beside it instead of above it, and the marker there is centred on the pin and taller than wide (the pin moved off its old point; the verdicts)" \
        [list [expr {[pm_coord R1 P] ne {300 -30}}] [pm_verdict $rot 16]] {1 {1 1 1 1 1 1 1}}
    pcall xschem pin_marker clear
    pcall xschem set modified 0
    # the LIGHT scheme: layer 16 is another colour there, and the marker takes it
    set dark16 [pm_colour 16]
    pm_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 600 100
    pcall xschem toggle_colorscheme ; pm_settle
    set light [pm_measure R1 P]
    set light16 [pm_colour 16]
    # judged NOW, while the light scheme is the one pm_colour reads
    set light_verdict [pm_verdict $light 16]
    pcall xschem pin_marker clear
    pcall xschem toggle_colorscheme ; pm_settle
    check "P3c under the LIGHT colour scheme the marker is that scheme's layer 16, which is another colour than the dark scheme's (the verdicts under the light scheme; the two colours differ; the dark scheme is back)" \
        [list $light_verdict [expr {$light16 ne $dark16}] $::dark_colorscheme] {{1 1 1 1 1 1 1} 1 1}
    check "P3d the colour layer 16 has under each stock scheme, as this binary's Tcl sets it: light green on the dark scheme, a mid green on the light one" \
        [list $dark16 $light16] [list #bfff81 #7ccc40]
}

group P4 {
    # the doors that need Tk
    pm_fresh ; pm_settle
    pcall xschem pin_marker add -tag save R1 P
    set first [pcall xschem get current_win_path]
    set list1 [pm_list]
    # (a) a -gui open over an OCCUPIED window is routed to a new context and
    #     leaves this one alone
    pcall xschem load -gui $pm_other
    pm_settle
    set second [pcall xschem get current_win_path]
    set new_list [pm_list]
    pcall xschem new_schematic switch $first ; pm_settle
    check "P4a `xschem load -gui <another file>` over an occupied window opens ANOTHER context, which has no marker, and the first keeps its own with its point (the context changed; rows in the new one; the first's list is what it was)" \
        [list [expr {$second ne $first}] $new_list [expr {[pm_list] eq $list1}]] {1 {} 1}
    pcall xschem new_schematic switch $second ; pm_settle
    pcall xschem new_schematic destroy $second {} ; pm_settle

    # (b) File > Open's dialog arm, ask_new_file(), with the dialog answered by a
    #     stand-in: an in-place load of another document
    pcall xschem new_schematic switch $first ; pm_settle
    pcall xschem set modified 0
    set ::new_file_browser 0 ; set ::open_in_new_window 0 ; set ::file_dialog_others {}
    rename ::load_file_dialog ::pm_real_load_file_dialog
    proc ::load_file_dialog {args} { set ::file_dialog_others {} ; return $::pm_other }
    set held [llength [pm_list]]
    pcall xschem load
    pm_settle
    rename ::load_file_dialog {}
    rename ::pm_real_load_file_dialog ::load_file_dialog
    check "P4b File > Open's own door -- `xschem load` with no file, its dialog answered with another document -- loads in place and empties the list (rows before; the context is the same; the sheet now shown; rows after)" \
        [list $held [expr {[pcall xschem get current_win_path] eq $first}] [file tail [pcall xschem get schname]] [pm_list]] \
        {1 1 pm_other.sch {}}

    # (c) `clear -all` repaints a DETACHED window: a marker in each of two real
    #     windows, cleared from the first
    pm_fresh ; pm_settle
    pcall xschem pin_marker add R1 P
    pcall xschem new_schematic create_window {} $pm_other
    pm_settle
    set second [pcall xschem get current_win_path]
    pcall xschem pin_marker add R1 P
    pm_settle
    pcall xschem new_schematic switch $first ; pm_settle
    set d0 [pcall xschem get drawcount]
    set n [pcall xschem pin_marker clear -all]
    set d1 [pcall xschem get drawcount]
    # the control: the same two markers, cleared with -fast
    pcall xschem pin_marker add -fast R1 P
    pcall xschem new_schematic switch $second ; pm_settle
    pcall xschem pin_marker add -fast R1 P
    pcall xschem new_schematic switch $first ; pm_settle
    set d2 [pcall xschem get drawcount]
    set nf [pcall xschem pin_marker clear -all -fast]
    set d3 [pcall xschem get drawcount]
    check "P4c `clear -all` from one window, with a marker in a second, DETACHED window: it answers 2 and draws TWICE -- this window and the other -- where the same clear with -fast answers 2 and draws nothing (the two windows differ; count and draws; count and draws with -fast)" \
        [list [expr {$second ne $first}] $n [expr {$d1 - $d0}] $nf [expr {$d3 - $d2}]] {1 2 2 2 0}
    pcall xschem new_schematic switch $second ; pm_settle
    pcall xschem new_schematic destroy $second {} ; pm_settle
    pcall xschem new_schematic switch $first ; pm_settle
}

# ---------------------------------------------------------------------------
# P5, P6 — ASE-L on the screen
# ---------------------------------------------------------------------------
# The mode is entered through its real entry as in band G; here the CLICK and
# the ESC are real events on the design canvas, through the bindings the mode
# seized, and in P6 the plot goes to the real waveform viewer.

# the integer pixel of a schematic point, for a synthetic event
proc pg_px {x y} {
    lassign [pm_w2s $x $y] a b
    return [list [expr {int(floor($a + 0.5))}] [expr {int(floor($b + 0.5))}]]
}
# ONE REAL CLICK at schematic (x,y): a pointer motion first -- it is what tells
# the engine where the pointer is -- then press and release.  The `update` in
# FRONT drains whatever is pending, so the one after the motion delivers the
# motion and nothing else: any <Configure> delivered between the motion and the
# press overwrites the pointer position the click reads (issue 1659).  The
# position is read back, and a click made from another place than asked is
# counted in ::pg_clobber, which the rows assert is 0.
#
# EACH CLICK CARRIES ITS OWN TIME, two seconds after the one before.  A
# synthetic event has no time of its own, so two presses on one pixel are a
# DOUBLE-click to Tk however long the script waits between them, and Tk hands
# the second press of one to the <Double-Button-1> binding.  The mode holds
# that binding as well, so the press would reach the pick either way; these
# rows are about two separate clicks, and say so with their times.
set ::pg_clobber 0
set ::pg_clock 100000
proc pg_real_click {cv x y} {
    lassign [pg_px $x $y] px py
    set ::pg_notices {} ; set ::pg_dlg_asked {}
    incr ::pg_clock 2000
    update
    event generate $cv <Motion> -x $px -y $py
    update
    if {abs([xschem get mousex] - $x) > 1.5 || abs([xschem get mousey] - $y) > 1.5} { incr ::pg_clobber }
    event generate $cv <ButtonPress-1> -x $px -y $py -time $::pg_clock
    event generate $cv <ButtonRelease-1> -x $px -y $py -time $::pg_clock
    update
}
# THE REAL ESC.  A key event goes to the window that has the focus, so the
# canvas is given it and the key is sent only once Tk reports it there; the
# mode is over when the canvas has the <Key-Escape> binding it had before the
# mode (`pre`) back.  1 when that happened, 0 when it never did.
proc pg_real_esc {cv pre} {
    for {set i 0} {$i < 100} {incr i} {
        update
        if {[bind $cv <Key-Escape>] eq $pre} { return 1 }
        focus -force $cv
        update
        if {[focus -displayof $cv] eq $cv} {
            event generate $cv <Key-Escape>
            update
            if {[bind $cv <Key-Escape>] eq $pre} { return 1 }
        }
        after 50
    }
    return 0
}
# what the canvas gained between two captures, judged round the schematic
# point (x,y): the dict pm_verdict reads
proc pg_gain {a b x y} {
    set d [pm_diff $a $b]
    lassign [pm_w2s $x $y] px py
    dict set d colours [lmap {c n} [pcall xschem window_snapshot colors $a $b] { string tolower $c }]
    dict set d px $px ; dict set d py $py
    dict set d a [pm_a_px] ; dict set d s [pm_stroke]
    return $d
}

group P5 {
    pg_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set cv [pcall xschem get current_win_path]
    set pre_esc [bind $cv <Key-Escape>]
    set pre_press [bind $cv <ButtonPress-1>]
    lassign [pm_coord R9 P] rx ry
    set entered [pg_enter outputs]
    pm_settle
    check "P5 fixture: entering the mode seized the design canvas's <ButtonPress-1> for the pick and its <Key-Escape> for ase::ui::sod_end -- the two bindings the rows below drive with real events -- and neither is what the canvas had before" \
        [list $entered [bind $cv <ButtonPress-1>] [bind $cv <Key-Escape>] \
              [expr {[bind $cv <ButtonPress-1>] ne $pre_press}] [expr {[bind $cv <Key-Escape>] ne $pre_esc}]] \
        [list 1 [pg_press] "[list ase::ui::sod_end $PGKEY]; break" 1 1]
    pm_snap 0
    pg_real_click $cv $rx $ry
    pm_snap 1
    check "P5a A REAL CLICK ON A PIN, IN THE MODE, PAINTS THE ELLIPSE: a pointer motion to R9's P pin and a button press through the seized binding queue the terminal's row, list the marker, and the canvas gains an upright ellipse round that pin in layer 16's colour and nothing else (the click was made where asked; what it said; the list; then the verdicts: painted, only that colour, centred x and y, width, height, taller than wide)" \
        [list $::pg_clobber $::pg_notices [pg_marks] [pm_verdict [pg_gain 0 1 $rx $ry] 16]] \
        [list 0 [list "ase: queued output 'i(r9:n1)' (added)"] {{R9 0 16 save}} {1 1 1 1 1 1 1}]
    pcall xschem unhilight_all
    pm_snap 2
    check "P5b `xschem unhilight_all` -- what the key 0 runs -- with the mode still up: the ellipse is gone, the canvas is the one captured before the click, pixel for pixel, and the mode is still armed" \
        [list [pm_get [pm_diff 0 2] n] [pm_list] [pg_mode]] {0 {} 1}
    pg_real_click $cv $rx $ry
    pm_snap 3
    check "P5c the same pin clicked again: its row is queued already, and the ellipse is back -- the canvas is the one captured after the first click, pixel for pixel" \
        [list $::pg_clobber $::pg_notices [pm_get [pm_diff 1 3] n] [pg_marks]] \
        [list 0 [list "ase: output 'i(r9:n1)' already queued"] 0 {{R9 0 16 save}}]
    set esc [pg_real_esc $cv $pre_esc]
    pm_snap 4
    check "P5d THE REAL ESC ENDS THE MODE AND TAKES THE ELLIPSE AWAY: a <Key-Escape> sent to the canvas reaches ase::ui::sod_end through the seized binding -- the mode is over, the canvas has its own bindings back, the list is empty, and the canvas is the one captured before the click, pixel for pixel (while one row stays queued in the session)" \
        [list $esc [pg_mode] [expr {[bind $cv <ButtonPress-1>] eq $pre_press}] [pm_list] [pm_get [pm_diff 0 4] n] [pg_outputs]] \
        {1 0 1 {} 0 i(r9:n1)}
}

group P6 {
    pg_fresh ; pm_settle
    # real results: the committed transient fixture holds i(r9:n1)
    file copy -force -- [file join $here data probe_1724_tran.raw] $pg_raw
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set cv [pcall xschem get current_win_path]
    set pre_esc [bind $cv <Key-Escape>]
    lassign [pm_coord R9 P] rx ry
    set entered [pg_enter plot]
    pm_settle
    pm_snap 0
    pg_real_click $cv $rx $ry
    pm_snap 1
    set qc {}
    catch {set qc $ase::ui::sod($PGKEY,qcolors)}
    set tl [lindex $qc 0]
    check "P6a DIRECT PLOT, A REAL CLICK ON A PIN WHOSE VECTOR THE RESULTS HOLD: the trace is queued with one colour, a layer above 0; the pin's marker is on that layer with the tag `plot`; and the canvas gains the ellipse in THAT layer's colour, which is not layer 16's (the click was made where asked; the queue's colours are one layer number; the list; the verdicts with that layer; the two colours differ)" \
        [list $entered $::pg_clobber [llength $qc] [expr {[string is integer -strict $tl] && $tl > 0}] [pg_marks] \
              [pm_verdict [pg_gain 0 1 $rx $ry] $tl] [expr {[pm_colour $tl] ne [pm_colour 16]}]] \
        [list 1 0 1 1 [list [list R9 0 $tl plot]] {1 1 1 1 1 1 1} 1]
    # the real ESC: the mode ends and the queue is plotted in the real viewer
    set esc [pg_real_esc $cv $pre_esc]
    pm_settle
    set traces {}
    catch {
        foreach g [dict get [wviewer::layout_for $PGKEY] graphs] {
            foreach tr [dict get $g traces] { lappend traces [list [dict get $tr vec] [dict get $tr color]] }
        }
    }
    # the viewer is a window context of its own and stands over the design:
    # close it and come back to the design's before reading the canvas
    catch {wviewer::close $PGKEY}
    pm_settle
    pcall xschem new_schematic switch $cv
    raise . ; pm_settle
    pm_snap 2
    check "P6b THE REAL ESC PLOTS, AND THE ELLIPSE STAYS IN THE WAVEFORM'S COLOUR: the mode is over; the waveform viewer holds one trace, of that vector, whose colour is the layer the marker is on; and back on the design the marker is still listed and still drawn -- the canvas is the one captured after the click, pixel for pixel" \
        [list $esc [pg_mode] $traces [pg_marks] [pm_get [pm_diff 1 2] n]] \
        [list 1 0 [list [list i(r9:n1) $tl]] [list [list R9 0 $tl plot]] 0]
    pcall xschem unhilight_all
    pm_snap 3
    check "P6c ...until the highlights are cleared: after `xschem unhilight_all` the list is empty and the canvas is the one captured before the click, pixel for pixel" \
        [list [pm_list] [pm_get [pm_diff 0 3] n]] {{} 0}
    file delete -force $pg_raw
}

# ---------------------------------------------------------------------------
# P7 — two windows linked by a descend, on the screen
# ---------------------------------------------------------------------------
# The block is opened in a window of its own.  `xschem unhilight_all` -- what
# the clear-all key runs -- given in ONE of the two windows must leave the
# OTHER without its ellipse on the screen as well as in its list: the window
# it is not given in is repainted by the pass that clears its net colours.
# Each window is brought in front before it is captured.  The net colour and
# the marker are on two layers of their own, and a cue counts as shown when its
# colour is among the pixels that CHANGED when it was added.
#
# does capture `b` hold `colour` where it differs from capture `a`?
proc pm_gained {a b colour} {
    foreach {c n} [pcall xschem window_snapshot colors $a $b] { if {[string tolower $c] eq $colour} { return 1 } }
    return 0
}
group P7 {
    pm_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 600 100
    pcall xschem redraw ; pm_settle
    set first [pcall xschem get current_win_path]
    set made [pcall hi_descend inst=x1 target=new_window]
    pm_settle
    set below [pcall xschem get current_win_path]
    set where [list [pcall xschem get sch_path] [pcall xschem get currsch]]
    set two [expr {$made eq {1} && $below ne $first && [winfo exists $below] && [winfo toplevel $below] ne {.} ? 1 : 0}]
    check "P7 fixture: `hi_descend inst=x1 target=new_window` opened the block's sheet, one level down, in a second window with a canvas and a toplevel of its own, and the two layers used below have two colours, neither of them layer 16's" \
        [list $made $two $where [llength [lsort -unique [list [pm_colour 9] [pm_colour 12] [pm_colour 16]]]]] \
        {1 1 {.x1. 1} 3}
    if {$two} {
        wm geometry [winfo toplevel $below] 700x500+0+0
        pm_settle
        pcall xschem zoom_full
        pcall xschem redraw ; pm_settle
        set nc [pm_colour 9] ; set mc [pm_colour 12]

        # (a) a net colour and a marker BELOW, cleared from the window above
        set cov [list [pm_show $below]]
        pm_snap 0
        pcall xschem hilight_netname -layer 9 A
        pcall xschem pin_marker add -layer 12 -tag plot R1 P
        pm_snap 1
        set shown [list [pm_gained 0 1 $nc] [pm_gained 0 1 $mc] [llength [pm_list]]]
        lappend cov [pm_show $first]
        pcall xschem unhilight_all
        lappend cov [pm_show $below]
        pm_snap 2
        check "P7a GIVEN IN THE WINDOW ABOVE, THE CLEAR ERASES THE ELLIPSE IN THE WINDOW BELOW: with a net colour and a marker drawn below -- both colours on its screen, one marker listed -- `xschem unhilight_all` given above leaves the window below with no marker, no highlight, and the screen it had before either was drawn, pixel for pixel (nothing covered a window when it was read; the two colours and the list before; then the list, the highlight table and the differing pixels)" \
            [list $cov $shown [pm_list] [pcall xschem list_hilights all] [pm_get [pm_diff 0 2] n]] \
            [list {{} {} {}} {1 1 1} {} {} 0]

        # (b) a net colour and a marker ABOVE, cleared from the window below
        set cov [list [pm_show $first]]
        pm_snap 3
        pcall xschem hilight_netname -layer 9 NETA
        pcall xschem pin_marker add -layer 12 -tag plot R1 P
        pm_snap 4
        set shown [list [pm_gained 3 4 $nc] [pm_gained 3 4 $mc] [llength [pm_list]]]
        lappend cov [pm_show $below]
        pcall xschem unhilight_all
        lappend cov [pm_show $first]
        pm_snap 5
        check "P7b ...AND GIVEN IN THE WINDOW BELOW IT ERASES THE ELLIPSE ABOVE: the same with the net colour and the marker on the sheet above and the command given below (nothing covered a window when it was read; the two colours and the list before; then the list, the highlight table and the differing pixels)" \
            [list $cov $shown [pm_list] [pcall xschem list_hilights all] [pm_get [pm_diff 3 5] n]] \
            [list {{} {} {}} {1 1 1} {} {} 0]

        # (c) a marker ALONE below: no net is highlighted in either window, so
        #     the clear has no net colour to take away anywhere
        set cov [list [pm_show $below]]
        pm_snap 0
        pcall xschem pin_marker add -layer 12 -tag plot R1 P
        pm_snap 1
        set shown [list [pm_gained 0 1 $mc] [llength [pm_list]] [pcall xschem list_hilights all]]
        lappend cov [pm_show $first]
        lappend shown [pcall xschem list_hilights all]
        pcall xschem unhilight_all
        lappend cov [pm_show $below]
        pm_snap 2
        check "P7c WITH NO NET HIGHLIGHTED ANYWHERE the ellipse below still goes from the screen: a marker alone in the window below, the highlight tables of both windows empty, and the command given above leaves the list below empty and its screen the one captured before the marker, pixel for pixel (nothing covered a window when it was read; the marker's colour on the screen, the list, and the two empty tables before; then the list and the differing pixels)" \
            [list $cov $shown [pm_list] [pm_get [pm_diff 0 2] n]] \
            [list {{} {} {}} {1 1 {} {}} {} 0]

        # (d) ...and a marker alone above, cleared from below
        set cov [list [pm_show $first]]
        pm_snap 3
        pcall xschem pin_marker add -layer 12 -tag plot R1 P
        pm_snap 4
        set shown [list [pm_gained 3 4 $mc] [llength [pm_list]] [pcall xschem list_hilights all]]
        lappend cov [pm_show $below]
        lappend shown [pcall xschem list_hilights all]
        pcall xschem unhilight_all
        lappend cov [pm_show $first]
        pm_snap 5
        check "P7d ...and the other way round: a marker alone in the window above, no net highlighted in either, the command given below (nothing covered a window when it was read; the marker's colour on the screen, the list, and the two empty tables before; then the list and the differing pixels)" \
            [list $cov $shown [pm_list] [pm_get [pm_diff 3 5] n]] \
            [list {{} {} {}} {1 1 {} {}} {} 0]

        pm_close_ctx $below $first
        raise . ; pm_settle
        check "P7e the second window is closed again and the first carries on (the contexts open; the one current; what covers its canvas)" \
            [list [pm_wins] [pcall xschem get current_win_path] [pm_covering $first]] [list [list $first] $first {}]
    }
}

# ---------------------------------------------------------------------------
# PC — the window the mode is on is closed
# ---------------------------------------------------------------------------
# The mode follows a descend into a new window.  Closing that window with the
# mode still up is a way out of the mode that is neither ESC nor a second
# entry: the canvas the mode sits on is destroyed.  The mode must end there --
# the ellipse picked earlier in the FIRST window goes, and no mode is left
# recorded on a canvas nobody can press ESC on.
#
# the slots the mode takes on a canvas, as Tk reports them: the press, the
# double click, the release, the motion with the button held, ESC, the
# canvas's destruction
proc pg_slots {cv} {
    return [lmap s {<ButtonPress-1> <Double-Button-1> <ButtonRelease-1> <B1-Motion> <Key-Escape> <Destroy>} { bind $cv $s }]
}
group PC {
    pg_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set first [pcall xschem get current_win_path]
    raise . ; pm_settle
    set pre [pg_slots $first]
    lassign [pm_coord R9 P] rx ry
    set entered [pg_enter outputs]
    pm_settle
    pm_snap 0
    pg_real_click $first $rx $ry
    set had_first [pg_marks]
    pm_snap 1
    set made [pcall hi_descend inst=x1 target=new_window]
    pm_settle
    set below [pcall xschem get current_win_path]
    set two [expr {$made eq {1} && $below ne $first && [winfo exists $below] && [winfo toplevel $below] ne {.} ? 1 : 0}]
    set moved {}
    set had_below {}
    set said_below {}
    if {$two} {
        wm geometry [winfo toplevel $below] 700x500+0+0
        pm_settle
        pcall xschem zoom_full
        pcall xschem redraw ; pm_settle
        set moved [list [pcall set ::ase::ui::sod($PGKEY,canvas)] [expr {[bind $first <ButtonPress-1>] eq [lindex $pre 0]}] \
                       [bind $below <Destroy>]]
        pg_real_click $below {*}[pm_coord R1 P]
        set had_below [pg_marks]
        set said_below $::pg_notices
    }
    check "PC fixture: the mode is entered on the first window and a real click marks R9's pin there; `hi_descend inst=x1 target=new_window` opens the block in a second window and the mode goes with it -- its canvas is the new one, the first window has its own press binding back, and the new canvas carries the hook for its own destruction; a real click there marks R1's pin and queues its row (entered; the first window's marker; a second window; where the mode is, the first window's press as before, the hook; the marker below; what the click said; the clicks were made where asked)" \
        [list $entered $had_first $two $moved $had_below $said_below $::pg_clobber] \
        [list 1 {{R9 0 16 save}} 1 [list $below 1 [list ase::ui::sod_canvas_gone $PGKEY %W]] {{R1 0 16 save}} \
              [list "ase: queued output 'i(x1.r1:n1)' (added)"] 0]
    if {$two} {
        set ::pg_notices {}
        pcall xschem set modified 0
        # what the window's own close button runs
        pcall xschem exit closewindow force
        update ; pm_settle
        set cov [pm_show $first]
        pm_snap 2
        check "PC1 CLOSING THE WINDOW THE MODE IS ON ENDS THE MODE AND TAKES THE ELLIPSES AWAY: after the second window is closed the first window's marker list is empty, its screen is the one captured before its pin was clicked, pixel for pixel, no mode is up, the one sentence about it was said, and only the first context is left (nothing covered the first window when it was read; its list; the differing pixels against before the click, with the count that the click had changed as the control; the mode; what ASE-L said; the contexts)" \
            [list $cov [pm_list] [pm_get [pm_diff 0 2] n] [expr {[pm_get [pm_diff 0 1] n] > 0 ? 1 : 0}] [pg_mode] \
                  [lsearch -all -inline -glob $::pg_notices {ase:*}] [pm_wins]] \
            [list {} {} 0 1 0 [list "ase: the design window the pick mode was on is gone — mode dropped"] [list $first]]
        check "PC2 ...and the first window is as it was before the mode: its press, double-click, release, held-motion, ESC and destroy bindings are the strings read before the mode was entered, the double click being the editor's own; and the two rows stay queued in the session" \
            [list [expr {[pg_slots $first] eq $pre ? {as before} : [pg_slots $first]}] \
                  [string match {xschem callback %W -3 *} [lindex $pre 1]] [pg_outputs]] \
            [list {as before} 1 {i(r9:n1) i(x1.r1:n1)}]
        # the mode can be entered again, and ESC then ends it the ordinary way
        set pre_esc [bind $first <Key-Escape>]
        set again [pg_enter outputs]
        pm_settle
        pg_real_click $first $rx $ry
        set m [pg_marks]
        set esc [pg_real_esc $first $pre_esc]
        check "PC3 the mode can be entered again on the first window: a real click marks the pin again and a real ESC ends the mode and clears it (entered; the marker; ESC ended it; the list and the mode at the end)" \
            [list $again $m $esc [pm_list] [pg_mode]] {1 {{R9 0 16 save}} 1 {} 0}
    }
    catch {ase::ui::sod_end $PGKEY}
    if {[llength [pm_wins]] > 1} { pm_close_ctx $below $first }
    raise . ; pm_settle
}

# ---------------------------------------------------------------------------
# PN — the prompt names the pin a click would take
# ---------------------------------------------------------------------------
# On a pin with a wire ending on it the editor's hover outline is the wire,
# where the click takes the terminal.  The mode's prompt on the design window
# says which it is, before the press.  The pointer is moved by a real motion
# event; the prompt is written by the mode's own timer, so the row waits for it.
#
# wait until the prompt slot of canvas `cv` shows `text`; the text it shows at
# the end
proc pg_prompt_wait {cv text} {
    set sb [ase::ui::sod_statusbar $cv]
    for {set i 0} {$i < 100} {incr i} {
        update
        if {[$sb cget -text] eq $text} { break }
        after 20
    }
    return [$sb cget -text]
}
# a real motion to schematic (x,y), drained first; the pointer the engine then reads
proc pg_real_motion {cv x y} {
    lassign [pg_px $x $y] px py
    update
    event generate $cv <Motion> -x $px -y $py
    update
    if {abs([xschem get mousex] - $x) > 1.5 || abs([xschem get mousey] - $y) > 1.5} { incr ::pg_clobber }
    return [list $px $py [xschem get mousex] [xschem get mousey]]
}
# a real press and release at a pixel, with NO motion before it: the click is
# made from wherever the engine last read the pointer
proc pg_real_press {cv px py} {
    set ::pg_notices {} ; set ::pg_dlg_asked {}
    incr ::pg_clock 2000
    event generate $cv <ButtonPress-1> -x $px -y $py -time $::pg_clock
    event generate $cv <ButtonRelease-1> -x $px -y $py -time $::pg_clock
    update
}
group PN {
    pg_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set cv [pcall xschem get current_win_path]
    raise . ; pm_settle
    set pre_esc [bind $cv <Key-Escape>]
    lassign [pm_coord R2 M] mx my
    # the pointer starts on empty canvas, away from every pin
    pg_real_motion $cv 400 -80
    set entered [pg_enter outputs]
    set plain {select outputs on design}
    set named "$plain — pin R2:M (terminal current)"
    set t0 [pg_prompt_wait $cv $plain]
    lassign [pg_real_motion $cv $mx $my] px py ax ay
    set t1 [pg_prompt_wait $cv $named]
    # two more periods of the timer with the pointer at rest
    after 200 ; update
    set rest [list [expr {[xschem get mousex] == $ax && [xschem get mousey] == $ay}] [[ase::ui::sod_statusbar $cv] cget -state]]
    pg_real_press $cv $px $py
    set q1 [pg_outputs] ; set m1 [pg_marks]
    check "PN1 THE PROMPT NAMES THE PIN BEFORE THE PRESS: with the mode up the design window's prompt is the mode's words; a real pointer motion onto R2's lower pin, where a wire ends, and the prompt becomes those words and then the instance and the pin, shown as a live mode; the pointer the engine reads is the same after the prompt changed its width as right after the motion; and a press there, with no further motion, queues that terminal and marks that pin (entered; the prompt before, with the pointer on empty canvas; after the motion; pointer unmoved and the slot's state; the motions were made where asked; the rows; the markers)" \
        [list $entered $t0 $t1 $rest $::pg_clobber $q1 $m1] \
        [list 1 $plain $named {1 active} 0 i(r2:n2) {{R2 1 16 save}}]
    lassign [pg_real_motion $cv $mx [expr {$my + 8}]] px py
    set t2 [pg_prompt_wait $cv $plain]
    pg_real_press $cv $px $py
    check "PN2 ...AND ONLY THERE: with the pointer moved 8 units along that wire the prompt is the mode's words alone again, and a press there queues the net's voltage (the prompt; the motion was made where asked; the rows; what the press said)" \
        [list $t2 $::pg_clobber [pg_outputs] $::pg_notices] \
        [list $plain 0 {i(r2:n2) v(neta)} [list "ase: queued output 'v(neta)' (added)"]]
    set esc [pg_real_esc $cv $pre_esc]
    after 200 ; update
    check "PN3 a real ESC ends the mode and the prompt goes with it: the slot is blank and back in its ordinary state, and stays so (ESC ended the mode; the slot's text, trimmed; its state)" \
        [list $esc [string trim [[ase::ui::sod_statusbar $cv] cget -text]] [[ase::ui::sod_statusbar $cv] cget -state]] {1 {} normal}
}

# ---------------------------------------------------------------------------
# PD — a pick whose hand moves with the button down
# ---------------------------------------------------------------------------
# The mode holds the motion with the left button held as well as the press and
# the release.  Left to the editor, that motion starts its selection rectangle
# under the pick: the selection made before the mode is cleared, and the
# rectangle is ended only by the editor's own handling of the release, which
# the mode swallows -- so it outlives the mode's ESC.
#
# ONE REAL KEY on canvas `cv`: a key event goes to the window that has the
# focus, so the canvas is given it and the key is sent only once Tk reports it
# there.  1 when the key was sent.
proc pg_real_key {cv args} {
    for {set i 0} {$i < 60} {incr i} {
        focus -force $cv ; update
        if {[focus -displayof $cv] eq $cv} { event generate $cv {*}$args ; update ; return 1 }
        after 50
    }
    return 0
}
# ONE REAL PRESS, DRAG AND RELEASE on canvas `cv`: a pointer motion to
# schematic (x,y), a press there, `steps` motions with the left button held,
# each `step` pixels further right and down than the one before, and the
# release where the last one ended.  Answers what the editor holds while the
# button is still down: {its state word, the number of objects selected}.
proc pg_real_drag {cv x y steps step} {
    lassign [pg_px $x $y] px py
    set ::pg_notices {} ; set ::pg_dlg_asked {}
    incr ::pg_clock 2000
    update
    event generate $cv <Motion> -x $px -y $py
    update
    if {abs([xschem get mousex] - $x) > 1.5 || abs([xschem get mousey] - $y) > 1.5} { incr ::pg_clobber }
    event generate $cv <ButtonPress-1> -x $px -y $py -time $::pg_clock
    update
    for {set i 1} {$i <= $steps} {incr i} {
        event generate $cv <Motion> -x [expr {$px + $i * $step}] -y [expr {$py + $i * $step}] -state 256 \
            -time [expr {$::pg_clock + 20 * $i}]
        update
    }
    set mid [list [pcall xschem get ui_state] [pcall xschem get lastsel]]
    event generate $cv <ButtonRelease-1> -x [expr {$px + $steps * $step}] -y [expr {$py + $steps * $step}] -state 256 \
        -time [expr {$::pg_clock + 20 * $steps + 20}]
    update
    return $mid
}
# the rows of one drag in the mode on canvas `cv`, which the caller has given
# a selection of one instance and then the mode: a long drag that starts on the
# wire below R2, then a click on R2's upper pin that drifts by two pixels, then
# the real ESC.  `pre` is the canvas's slots before the mode.  Answers the
# list the PD rows and the profile's row in P8 both assert:
#   the motions were made where asked; what the editor held with the button
#   down in the long drag, against before; its state word and selection after
#   that release; what the drag said; the pixels the canvas differs by from
#   before the drag; the same two things for the drifting click; the rows and
#   the markers then; ESC ended the mode; the state word and the selection
#   after it, the markers, the pixels differing from before the drag, and the
#   slots against `pre`
proc pg_drag_rows {cv pre} {
    set ui0 [pcall xschem get ui_state]
    set sel0 [list [pcall xschem get lastsel] [pcall xschem selected_set]]
    set clob0 $::pg_clobber
    pm_snap 0
    set mid [pg_real_drag $cv 500 55 5 8]
    set held [expr {$mid eq [list $ui0 [lindex $sel0 0]] ? {as before} : $mid}]
    set now [list [pcall xschem get ui_state] [pcall xschem get lastsel] [pcall xschem selected_set]]
    set rel [expr {$now eq [list $ui0 {*}$sel0] ? {as before} : $now}]
    set said $::pg_notices
    pm_snap 1
    set px1 [pm_get [pm_diff 0 1] n]
    set mid2 [pg_real_drag $cv {*}[pm_coord R2 P] 2 1]
    set held2 [expr {$mid2 eq [list $ui0 [lindex $sel0 0]] ? {as before} : $mid2}]
    set now [list [pcall xschem get ui_state] [pcall xschem get lastsel] [pcall xschem selected_set]]
    set rel2 [expr {$now eq [list $ui0 {*}$sel0] ? {as before} : $now}]
    set rows [pg_outputs] ; set marks [pg_marks]
    set esc [pg_real_esc $cv [lindex $pre 4]]
    set now [list [pcall xschem get ui_state] [pcall xschem get lastsel] [pcall xschem selected_set]]
    set end [expr {$now eq [list $ui0 {*}$sel0] ? {as before} : $now}]
    pm_snap 2
    return [list [expr {$::pg_clobber - $clob0}] $held $rel $said $px1 $held2 $rel2 $rows $marks $esc [pg_mode] $end [pm_list] \
                 [pm_get [pm_diff 0 2] n] [expr {[pg_slots $cv] eq $pre ? {as before} : [pg_slots $cv]}]]
}
# ...and what those rows are when the mode holds the held motion
set PG_DRAG [list 0 {as before} {as before} [list "ase: queued output 'v(neta)' (added)"] 0 {as before} {as before} \
                  {v(neta) i(r2:n1)} {{R2 0 16 save}} 1 0 {as before} {} 0 {as before}]
group PD {
    pg_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set cv [pcall xschem get current_win_path]
    raise . ; pm_settle
    set pre [pg_slots $cv]
    pcall xschem select instance R9
    pm_settle
    set sel0 [list [pcall xschem get lastsel] [pcall xschem selected_set]]
    set entered [pg_enter outputs]
    pm_settle
    check "PD fixture: an instance is selected before the mode, the mode is entered over it, and the canvas then holds the mode's `break` on the motion with the left button held, where it held nothing before; the editor is in the middle of no selection rectangle (the selection: its count and its set; entered; the held-motion slot before and now; the rectangle bit of the editor's state word)" \
        [list $sel0 $entered [lindex $pre 3] [bind $cv <B1-Motion>] [expr {[pcall xschem get ui_state] & 16}]] \
        {{1 {{R9}}} 1 {} break 0}
    check "PD1 A DRAG IN THE MODE IS A PICK AND NOTHING ELSE: a real press on the wire below R2, the pointer dragged forty pixels away with the button down, and the release -- the net is queued once; while the button is down and after the release the editor's state word and the selection are what they were before the press, and not one pixel of the canvas has changed; a real click on R2's upper pin whose hand drifts by two pixels queues that terminal and marks it, the selection again untouched; and the real ESC ends the mode with the editor as it was before the drag, the marker gone, the canvas pixel for pixel the one captured before the drag, and every slot handed back (the motions were made where asked; the long drag: held, released, said, pixels; the drifting click: held, released; the rows; the markers; ESC ended the mode; the mode; the editor after it; the markers; the pixels; the slots)" \
        [pg_drag_rows $cv $pre] $PG_DRAG
    # whatever a failing build left behind: a rectangle in progress, a selection
    catch {ase::ui::sod_end $PGKEY}
    pg_real_key $cv <Key-Escape>
    pcall xschem unselect_all
    pm_settle
}

# ---------------------------------------------------------------------------
# PS — a press made after the engine's pointer was overwritten
# ---------------------------------------------------------------------------
# The click reads the pointer the engine holds.  The engine takes the position
# of every event it is sent as the pointer, and a <Configure> of the canvas --
# a window resized or laid out again -- carries the canvas's place in its
# parent there.  One that arrives between the last pointer motion and the press
# leaves the engine with a pointer nobody put there (issue 1659).  The script
# the mode binds on the press hands the engine the press's own position first.
#
# THE OVERWRITE: a <Configure> on canvas `cv` with the fields Tk gives one --
# the canvas's place in its parent and its size -- delivered through the
# canvas's own binding.  Answers how far from schematic (x,y) the engine then
# reads the pointer, in units.
proc pg_overwrite {cv x y} {
    update
    event generate $cv <Configure> -x [winfo x $cv] -y [winfo y $cv] -width [winfo width $cv] -height [winfo height $cv]
    update
    return [expr {hypot([xschem get mousex] - $x, [xschem get mousey] - $y)}]
}
group PS {
    pg_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set cv [pcall xschem get current_win_path]
    raise . ; pm_settle
    set pre_esc [bind $cv <Key-Escape>]
    set entered [pg_enter outputs]
    pm_settle
    lassign [pm_coord R9 P] rx ry
    lassign [pg_real_motion $cv $rx $ry] px py
    set off [pg_overwrite $cv $rx $ry]
    check "PS fixture: THE POINTER THE ENGINE HOLDS REALLY IS OVERWRITTEN: with the mode up and the pointer moved onto R9's upper pin by a real motion, a <Configure> delivered to the canvas leaves the engine reading a pointer more than fifty units from the pin, with no motion made; and the canvas has that <Configure> bound to the engine (entered; the motion was made where asked; farther than fifty units now; the binding)" \
        [list $entered $::pg_clobber [expr {$off > 50 ? 1 : $off}] [bind $cv <Configure>]] \
        {1 0 1 {xschem callback %W %T %x %y 0 %w %h 0}}
    pg_real_press $cv $px $py
    set back [expr {hypot([xschem get mousex] - $rx, [xschem get mousey] - $ry)}]
    check "PS1 A PRESS AT THE PIN'S PIXEL, WITH NO MOTION SINCE THE OVERWRITE, TAKES THE PIN: the terminal is queued, the pin is marked, and the engine's pointer is on the pin again (the rows; what the press said; the markers; the pointer within a unit and a half of the pin)" \
        [list [pg_outputs] $::pg_notices [pg_marks] [expr {$back < 1.5 ? 1 : $back}]] \
        [list i(r9:n1) [list "ase: queued output 'i(r9:n1)' (added)"] {{R9 0 16 save}} 1]
    lassign [pg_real_motion $cv 500 55] wx wy
    set off [pg_overwrite $cv 500 55]
    pg_real_press $cv $wx $wy
    check "PS2 ...AND SO DOES A PRESS ON A WIRE: the pointer moved onto the wire below R2, the overwrite, and a press at the wire's pixel queues the net's voltage (the motion was made where asked; farther than fifty units after the overwrite; the rows; what the press said)" \
        [list $::pg_clobber [expr {$off > 50 ? 1 : $off}] [pg_outputs] $::pg_notices] \
        [list 0 1 {i(r9:n1) v(neta)} [list "ase: queued output 'v(neta)' (added)"]]
    # a double click with the overwrite between its two presses.  A tag ahead
    # of the canvas's own counts the double clicks Tk itself sees.  Were the
    # second press to reach the editor it would open a dialog that waits, so
    # the leg is bounded: a timer that re-arms itself destroys any toplevel
    # that appears, and the row lists what it had to close.
    set pg_tops [lmap w [winfo children .] { expr {[winfo toplevel $w] eq $w ? $w : [continue]} }]
    set ::pg_closed {}
    proc pg_dlg_guard {before} {
        foreach w [winfo children .] {
            if {[winfo toplevel $w] eq $w && [lsearch -exact $before $w] < 0} { lappend ::pg_closed $w ; catch {destroy $w} }
        }
        set ::pg_guard_id [after 1500 [list pg_dlg_guard $before]]
    }
    set ::pg_guard_id [after 1500 [list pg_dlg_guard $pg_tops]]
    set ::pg_dbl 0
    bind PgDblSeen <Double-Button-1> { incr ::pg_dbl }
    bindtags $cv [linsert [bindtags $cv] 0 PgDblSeen]
    lassign [pm_coord R2 P] dx dy
    lassign [pg_real_motion $cv $dx $dy] px py
    set ::pg_notices {} ; set ::pg_dlg_asked {}
    incr ::pg_clock 2000
    event generate $cv <ButtonPress-1> -x $px -y $py -time $::pg_clock
    event generate $cv <ButtonRelease-1> -x $px -y $py -time [expr {$::pg_clock + 40}]
    update
    set off [pg_overwrite $cv $dx $dy]
    event generate $cv <ButtonPress-1> -x $px -y $py -time [expr {$::pg_clock + 120}]
    event generate $cv <ButtonRelease-1> -x $px -y $py -time [expr {$::pg_clock + 160}]
    update
    after cancel $::pg_guard_id
    bindtags $cv [lsearch -all -inline -not -exact [bindtags $cv] PgDblSeen]
    bind PgDblSeen <Double-Button-1> {}
    check "PS3 ...AND THE SECOND PRESS OF A DOUBLE CLICK, which no motion precedes: two presses on R2's upper pin 120 ms apart with the overwrite between them -- Tk sees one double click, the first press queues the terminal and the second, made from its own position, finds it queued already; one row, one marker for it, nothing selected and no dialog opened (the motion was made where asked; farther than fifty units between the presses; the double clicks Tk saw; what the two presses said; the rows; the markers; the selection count; the dialogs the guard had to close)" \
        [list $::pg_clobber [expr {$off > 50 ? 1 : $off}] $::pg_dbl $::pg_notices [pg_outputs] [pg_marks] [pcall xschem get lastsel] $::pg_closed] \
        [list 0 1 1 [list "ase: queued output 'i(r2:n1)' (added)" "ase: output 'i(r2:n1)' already queued"] \
              {i(r9:n1) v(neta) i(r2:n1)} {{R9 0 16 save} {R2 0 16 save}} 0 {}]
    set esc [pg_real_esc $cv $pre_esc]
    check "PS4 the real ESC ends that mode (ended; the mode; the markers)" [list $esc [pg_mode] [pm_list]] {1 0 {}}
}

# ---------------------------------------------------------------------------
# PW — a window made while the mode is up
# ---------------------------------------------------------------------------
# A new window's canvas is given a copy of the first canvas's bindings
# (clone_canvas_bindings).  A window opened by a descend is made with the mode
# paused; one made by any other door -- `xschem new_schematic create_window`
# here -- is made with the mode's scripts standing on the first canvas.  The
# copy asks src/cmdmode.tcl what each slot holds underneath the mode, and the
# mode tells it (ase::ui::sod_held), so the new canvas gets the bindings it
# would have got with no mode up.
#
# every binding of canvas `w`, sorted by sequence, with the window's own
# toplevel written as @TOP@ so that two windows can be compared
proc pg_bindmap {w} {
    set top [winfo toplevel $w]
    return [lmap s [lsort [bind $w]] { list $s [string map [list $top @TOP@] [bind $w $s]] }]
}
# does any of the mode's slots of canvas `w` hold a script: a list of 0/1
proc pg_slots_bound {w} { return [lmap s [pg_slots $w] { expr {$s ne {} ? 1 : 0} }] }
group PW {
    pg_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set first [pcall xschem get current_win_path]
    raise . ; pm_settle
    # the same sheet under another file name: a file that is open is not opened twice
    set twin [file join $scratch pg_twin.sch]
    file copy -force -- $pg_top $twin
    # the control: a window made with no mode up
    pcall xschem new_schematic create_window {} $twin
    pm_settle
    set w0 [pcall xschem get current_win_path]
    set ctl [expr {$w0 ne $first && [winfo exists $w0] ? [pg_bindmap $w0] : {NO WINDOW}}]
    set ctl_bound [expr {$w0 ne $first && [winfo exists $w0] ? [pg_slots_bound $w0] : {NO WINDOW}}]
    pm_close_ctx $w0 $first
    raise . ; pm_settle
    set pre [pg_slots $first]
    set entered [pg_enter outputs]
    pm_settle
    set own [pg_slots $first]
    set held [expr {[llength [pcall ase::ui::sod_held]] / 4}]
    pcall xschem new_schematic create_window {} $twin
    pm_settle
    set w1 [pcall xschem get current_win_path]
    set two [expr {$w1 ne $first && [winfo exists $w1] && [winfo toplevel $w1] ne {.} ? 1 : 0}]
    check "PW fixture: a window made with no mode up binds only the editor's double click of the mode's slots; then the mode is entered on the first window, where it holds a script on every one of them and reports them all to cmdmode, and a second window is made by the same door with the mode up (the control window's slots, bound or not, in the order press, double click, release, held motion, ESC, destroy; entered; the first canvas's slots bound; the groups the mode reports; a second window)" \
        [list $ctl_bound $entered [lmap s $own { expr {$s ne {} ? 1 : 0} }] $held $two] \
        {{0 1 0 0 0 0} 1 {1 1 1 1 1 1} 6 1}
    if {$two} {
        check "PW1 THE NEW WINDOW GETS NONE OF THE MODE'S SCRIPTS: every binding of its canvas is the one the window made with no mode up had, sequence for sequence; of the mode's slots it holds the editor's double click and nothing else; and the mode's own canvas holds what it held before the window was made (the bindings against the control's; its slots, bound or not; the mode's canvas)" \
            [list [expr {[pg_bindmap $w1] eq $ctl ? {as the control} : [pg_bindmap $w1]}] [pg_slots_bound $w1] \
                  [expr {[pg_slots $first] eq $own ? {unchanged} : [pg_slots $first]}]] \
            {{as the control} {0 1 0 0 0 0} unchanged}
        wm geometry [winfo toplevel $w1] 700x500+0+0
        pm_settle
        pcall xschem zoom_full
        pcall xschem redraw ; pm_settle
        pcall xschem unselect_all
        pg_real_click $w1 500 55
        set during [list [pcall xschem get lastsel] [lsearch -all -inline -glob $::pg_notices {ase:*}] [pg_outputs] [pg_mode] \
                         [pcall set ::ase::ui::sod($PGKEY,canvas)]]
        pcall xschem unselect_all
        set esc [pg_real_esc $first [lindex $pre 4]]
        pm_show $w1
        pg_real_click $w1 500 55
        set after [list [pcall xschem get lastsel] [lsearch -all -inline -glob $::pg_notices {ase:*}] [pg_slots_bound $w1]]
        pcall xschem unselect_all
        check "PW2 A CLICK ON A WIRE THERE IS THE EDITOR'S, while the mode is up and after its ESC: with the mode up a real click on the wire in the new window selects it, queues nothing and says nothing, and the mode stays armed on the first canvas; the real ESC in the first window ends the mode; and the same click in the new window then selects the wire again (the clicks were made where asked; during the mode: the selection count, what ASE-L said, the rows, the mode, its canvas; ESC ended the mode; after it: the selection count, what ASE-L said, the new canvas's slots)" \
            [list $::pg_clobber $during $esc $after] \
            [list 0 [list 1 {} {} 1 $first] 1 {1 {} {0 1 0 0 0 0}}]
        pm_close_ctx $w1 $first
        raise . ; pm_settle
        check "PW3 the second window is closed again and the first has the slots it had before the mode (the contexts open; the slots against before the mode)" \
            [list [pm_wins] [expr {[pg_slots $first] eq $pre ? {as before} : [pg_slots $first]}]] [list [list $first] {as before}]
    }
    catch {ase::ui::sod_end $PGKEY}
    if {[llength [pm_wins]] > 1} { pm_close_ctx $w1 $first }
    raise . ; pm_settle
}

# ---------------------------------------------------------------------------
# PV — the clear-all given while a wire is being drawn in a linked window
# ---------------------------------------------------------------------------
# `xschem unhilight_all` takes the pin markers of the windows linked to the one
# it is given in, and the pass that clears their net colours repaints them.
# That pass does nothing while the window the command is given in is in the
# middle of a gesture.  So in the middle of a gesture the linked window keeps
# everything -- its list, its ellipse and its net colour -- and the clear-all
# given again once the gesture is over takes all three.
group PV {
    pm_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 600 100
    pcall xschem redraw ; pm_settle
    set first [pcall xschem get current_win_path]
    set made [pcall hi_descend inst=x1 target=new_window]
    pm_settle
    set below [pcall xschem get current_win_path]
    set two [expr {$made eq {1} && $below ne $first && [winfo exists $below] && [winfo toplevel $below] ne {.} ? 1 : 0}]
    check "PV fixture: the block is opened one level down in a second window with a canvas and a toplevel of its own" \
        [list $made $two [pcall xschem get sch_path]] {1 1 .x1.}
    if {$two} {
        wm geometry [winfo toplevel $below] 700x500+0+0
        pm_settle
        pcall xschem zoom_full
        pcall xschem redraw ; pm_settle
        set nc [pm_colour 9] ; set mc [pm_colour 12]
        set cov [list [pm_show $below]]
        pm_snap 0
        pcall xschem hilight_netname -layer 9 A
        pcall xschem pin_marker add -layer 12 -tag plot R1 P
        pm_snap 1
        set shown [list [pm_gained 0 1 $nc] [pm_gained 0 1 $mc] [lmap r [pm_list] { lrange $r 1 4 }] \
                        [expr {[pcall xschem list_hilights all] ne {} ? 1 : 0}]]
        # the window above: a wire begun with the stock key and a pointer motion
        lappend cov [pm_show $first]
        set ui0 [pcall xschem get ui_state]
        event generate $first <Motion> -x 300 -y 300 ; update
        set keyed [pg_real_key $first <KeyPress> -keysym w]
        event generate $first <Motion> -x 350 -y 320 ; update
        set ui1 [pcall xschem get ui_state]
        pcall xschem unhilight_all
        set ui2 [pcall xschem get ui_state]
        lappend cov [pm_show $below]
        pm_snap 2
        set kept [list [lmap r [pm_list] { lrange $r 1 4 }] [expr {[pcall xschem list_hilights all] ne {} ? 1 : 0}] [pm_get [pm_diff 1 2] n]]
        check "PV1 GIVEN WHILE A WIRE IS BEING DRAWN ABOVE, THE CLEAR-ALL LEAVES THE LINKED WINDOW AS IT IS: with a net colour and a marker drawn in the window below -- both colours on its screen, one marker listed, its highlight table filled -- and a wire begun in the window above by the real key and a motion, `xschem unhilight_all` given above leaves the wire in progress, and the window below with its marker listed, its highlight table filled and its screen the one captured before the command, pixel for pixel (nothing covered a window when it was read; below before: the two colours, the list, the table filled; the key was sent; the editor's state word above before the wire, with it begun, and after the command; below after: the list, the table filled, the differing pixels)" \
            [list $cov $shown $keyed [list $ui0 [expr {$ui1 & 1}] [expr {$ui2 & 1}]] $kept] \
            [list {{} {} {}} {1 1 {{R1 0 12 plot}} 1} 1 {0 1 1} {{{R1 0 12 plot}} 1 0}]
        # the gesture ends, and the command is given again
        set cov [list [pm_show $first]]
        set keyed [pg_real_key $first <Key-Escape>]
        set ui3 [pcall xschem get ui_state]
        pcall xschem unhilight_all
        lappend cov [pm_show $below]
        pm_snap 3
        check "PV2 ...AND GIVEN AGAIN ONCE THE WIRE IS ABANDONED IT TAKES ALL THREE: after a real ESC above ends the wire, the same command leaves the window below with no marker, no highlight, and the screen it had before either was drawn, pixel for pixel (nothing covered a window when it was read; ESC was sent; the editor's state word above; below: the list, the highlight table, the differing pixels)" \
            [list $cov $keyed $ui3 [pm_list] [pcall xschem list_hilights all] [pm_get [pm_diff 0 3] n]] \
            [list {{} {}} 1 0 {} {} 0]
        pm_close_ctx $below $first
        raise . ; pm_settle
        check "PV3 the second window is closed again and the first carries on, with no wire left on its sheet (the contexts open; the one current; its wires)" \
            [list [pm_wins] [pcall xschem get current_win_path] [pcall xschem get wires]] [list [list $first] $first 1]
    }
    pcall xschem set modified 0
}

# ---------------------------------------------------------------------------
# PT — the design in a tab that is not the first
# ---------------------------------------------------------------------------
# With the tabbed interface the tabs of the main window share its canvas.  The
# name of the context a tab shows is a widget only for the first tab; for any
# other it is a name no widget has.  The mode is entered on the canvas that
# shows the design (ase::ui::sod_canvas).  Here it is entered as the design
# window's key enters it, with no raise; the session's menu entry and the
# key's own command are driven with a real session window in
# test_ase_interact.
group PT {
    pg_fresh ; pm_settle
    set first [pcall xschem get current_win_path]
    set tabbed $::tabbed_interface
    set ::tabbed_interface 1
    # another document into the first tab, the design's sheet into a second one
    pcall xschem load $pm_other
    pcall xschem new_schematic create {} $pg_top
    pm_settle
    set tab [pcall xschem get current_win_path]
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set pre [pg_slots $first]
    check "PT fixture: the design's sheet is shown by a second context that is a TAB of the main window -- its name is not the first one's and is no widget, while the first one's is (two contexts; the tab's name differs; it is a widget; the first is; the sheet shown)" \
        [list [llength [pm_wins]] [expr {$tab ne $first ? 1 : 0}] [winfo exists $tab] [winfo exists $first] \
              [file tail [pcall xschem get schname]]] \
        {2 1 0 1 pg_top.sch}
    set ::pg_notices {}
    set rc [pg_enter outputs]
    pm_settle
    set state [list [pcall set ::ase::ui::sod($PGKEY,canvas)] [pcall xschem get current_win_path] \
                    [lindex [pg_slots $first] 0] [lsearch -all -inline -glob $::pg_notices {ase: no design canvas*}]]
    pg_real_click $first {*}[pm_coord R9 P]
    set pick [list $::pg_notices [pg_marks] [pg_outputs]]
    set esc [pg_real_esc $first [lindex $pre 4]]
    check "PT1 THE MODE IS ENTERED WITH THE DESIGN IN THE SECOND TAB: the entry answers 1 and says no refusal, the mode is on the main window's canvas with the tab still the current context, a real click on R9's upper pin queues the terminal and marks it, and the real ESC ends the mode and hands every slot back (armed; the mode's canvas, the current context, the press slot, a refusal said; the click was made where asked; what it said, the markers, the rows; ESC ended the mode; the mode; the slots)" \
        [list $rc $state $::pg_clobber $pick $esc [pg_mode] [expr {[pg_slots $first] eq $pre ? {as before} : [pg_slots $first]}]] \
        [list 1 [list $first $tab [pg_press] {}] 0 [list [list "ase: queued output 'i(r9:n1)' (added)"] {{R9 0 16 save}} i(r9:n1)] \
              1 0 {as before}]
    catch {ase::ui::sod_end $PGKEY}
    pcall xschem pin_marker clear -fast
    pm_close_ctx $tab $first
    set ::tabbed_interface $tabbed
    pg_fresh ; pm_settle
    raise . ; pm_settle
    check "PT2 the tab is closed again, the first context shows the design's sheet and no mode is up (the contexts open; the sheet; the mode)" \
        [list [pm_wins] [file tail [pcall xschem get schname]] [pg_mode]] [list [list $first] pg_top.sch 0]
}

# ---------------------------------------------------------------------------
# PE — the prompt, with the pointer in another window of the same design
# ---------------------------------------------------------------------------
# The mode's scripts sit on ONE canvas.  With a block opened in a window of
# its own the mode is on that window, and the sheet above it is still on the
# screen: a click there is the editor's.  The prompt of the window the mode is
# on names a pin only while the pointer is in that window.
#
# a real pointer entry and motion onto PIXEL (px,py) of canvas `cv`, which may
# be another window than the one current.  The entry is what makes that window
# the current context, and the switch brings events of its own (the engine
# takes the position of every event it is sent for the pointer's, issue 1659):
# they are drained before the motion is sent, so the motion is the last thing
# the engine hears.  Answers the context that is current afterwards.
proc pg_real_enter {cv px py} {
    update
    event generate $cv <Enter> -x $px -y $py
    pm_settle
    event generate $cv <Motion> -x $px -y $py
    update
    return [xschem get current_win_path]
}
# is the engine's pointer within a unit and a half of schematic (x,y)?  1/0
proc pg_pointer_on {x y} {
    return [expr {abs([xschem get mousex] - $x) <= 1.5 && abs([xschem get mousey] - $y) <= 1.5 ? 1 : 0}]
}
group PE {
    pg_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set first [pcall xschem get current_win_path]
    raise . ; pm_settle
    set pre [pg_slots $first]
    lassign [pm_coord R9 P] rx ry
    # R9's pin as a pixel of the FIRST window, read while that window is current
    lassign [pg_px $rx $ry] fpx fpy
    set plain {select outputs on design}
    set entered [pg_enter outputs]
    pm_settle
    set made [pcall hi_descend inst=x1 target=new_window]
    pm_settle
    set below [pcall xschem get current_win_path]
    set two [expr {$made eq {1} && $below ne $first && [winfo exists $below] && [winfo toplevel $below] ne {.} ? 1 : 0}]
    set where {}
    if {$two} {
        wm geometry [winfo toplevel $below] 700x500+0+0
        pm_settle
        pcall xschem zoom_full
        pcall xschem redraw ; pm_settle
        set where [list [pcall set ::ase::ui::sod($PGKEY,canvas)] [expr {[bind $first <ButtonPress-1>] eq [lindex $pre 0]}] \
                       [bind $below <ButtonPress-1>]]
    }
    check "PE fixture: the mode is entered on the first window, and `hi_descend inst=x1 target=new_window` opens the block in a second window and takes the mode with it -- the mode's canvas is the new one and carries its press script, and the first window has its own press binding back, so a press there is the editor's (entered; a second window; the mode's canvas, the first window's press as before, the new window's press)" \
        [list $entered $two $where] [list 1 1 [list $below 1 [pg_press]]]
    if {$two} {
        # control: the pointer on a pin INSIDE the block, in the window the mode is on
        lassign [pm_coord R1 P] bx by
        pg_real_motion $below $bx $by
        set tin [pg_prompt_wait $below "$plain — pin R1:P (terminal current)"]
        # ...then into the first window, onto R9's pin
        set ctx [pg_real_enter $first $fpx $fpy]
        set there [list [expr {$ctx eq $first ? {first} : $ctx}] [pg_pointer_on $rx $ry]]
        set tout [pg_prompt_wait $below $plain]
        # two more periods of the timer with the pointer at rest there
        after 200 ; update
        set trest [[ase::ui::sod_statusbar $below] cget -text]
        # the pointer is still on the pin after the timer has run: the prompt
        # above was worked out for a pointer on a pin, not for one moved off it
        lappend there [pg_pointer_on $rx $ry]
        set said_shown [list [pcall ase::ui::sod_design_shown $PGKEY] \
                            [pcall apply {{key x y} { set t [ase::ui::sod_terminal_at $key $x $y] ; list [dict get $t instname] [dict get $t pinname] }} $PGKEY $rx $ry]]
        set rows0 [pg_outputs] ; set marks0 [pg_marks]
        pg_real_press $first $fpx $fpy
        set press [list [expr {[pg_outputs] eq $rows0 ? {no row} : [pg_outputs]}] [expr {[pg_marks] eq $marks0 ? {no marker} : [pg_marks]}] \
                       [lsearch -all -inline -glob $::pg_notices {ase:*}]]
        # the press was the editor's, and the editor made of it what it makes
        # of a press on a pin (it may select, or start a wire there): whatever
        # it began is given up before the next row
        pcall xschem abort_operation
        pcall xschem unselect_all
        # ...and back into the block's window: the pin is named again
        pcall xschem new_schematic switch $below {} 0
        lassign [pg_px $bx $by] qx qy
        set ctx2 [pg_real_enter $below $qx $qy]
        set tback [pg_prompt_wait $below "$plain — pin R1:P (terminal current)"]
        check "PE1 THE PROMPT NAMES NO PIN OF A WINDOW THE MODE IS NOT ON: with the pointer on R1's pin inside the block the new window's prompt names that pin; with the pointer moved into the FIRST window, onto R9's pin -- a window that shows the session's design, where the pin rule finds that pin (fixture legs) -- the prompt of the window the mode is on is the mode's words alone, and stays so with the pointer at rest; a real press there is the editor's: no row, no marker, nothing said; and with the pointer back on R1's pin in the block's window the pin is named again (the prompt inside the block; the first window is the current context, and the pointer is on the pin right after the motion and still after the timer ran; the prompt then, and two periods later; the design is shown there, and the pin the rule finds; the press; the context and the prompt back in the block)" \
            [list $tin $there $tout $trest $said_shown $press [expr {$ctx2 eq $below ? {below} : $ctx2}] $tback] \
            [list "$plain — pin R1:P (terminal current)" {first 1 1} $plain $plain {1 {R9 P}} {{no row} {no marker} {}} below \
                  "$plain — pin R1:P (terminal current)"]
    }
    catch {ase::ui::sod_end $PGKEY}
    if {[llength [pm_wins]] > 1} { pm_close_ctx $below $first }
    pcall xschem abort_operation
    pcall xschem unselect_all
    raise . ; pm_settle
    check "PE2 the second window is closed again, no mode is up, the first window is as it was before the mode and its editor is idle, with nothing selected -- the press made there in PE1 left no gesture of the editor's behind (the contexts open; the mode; the six slots; the editor's state word; the objects selected)" \
        [list [pm_wins] [pg_mode] [expr {[pg_slots $first] eq $pre ? {as before} : [pg_slots $first]}] \
              [pcall xschem get ui_state] [pcall xschem get lastsel]] [list [list $first] 0 {as before} 0 0]
}

# ---------------------------------------------------------------------------
# PF — Direct Plot's window is closed with traces queued
# ---------------------------------------------------------------------------
# Closing the window the mode is on drops the mode (group PC).  In Direct Plot
# the queue is then not plotted, and the colours its picks left on the first
# window -- an ellipse in a trace's colour, a net's colour -- are those of
# traces that were never made.  They are NOT taken away by the drop: clearing
# Direct Plot's markers would take those of earlier plots with them.  What the
# drop does is say so: how many traces were not plotted, and how the colours go.
group PF {
    pg_fresh ; pm_settle
    file copy -force -- [file join $here data probe_1724_tran.raw] $pg_raw
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set first [pcall xschem get current_win_path]
    raise . ; pm_settle
    lassign [pm_coord R9 P] rx ry
    lassign [pm_coord R2 M] mx my
    set entered [pg_enter plot]
    pm_settle
    pg_real_click $first $rx $ry
    pg_real_click $first $mx [expr {$my + 8}]
    set queue {}
    catch {set queue $::ase::ui::sod($PGKEY,queue)}
    set marks_before [pg_marks]
    set hi_before [pcall xschem list_hilights all]
    set made [pcall hi_descend inst=x1 target=new_window]
    pm_settle
    set below [pcall xschem get current_win_path]
    set two [expr {$made eq {1} && $below ne $first && [winfo exists $below] && [winfo toplevel $below] ne {.} ? 1 : 0}]
    check "PF fixture: Direct Plot is entered on the first window and two real clicks queue two traces there -- the terminal of R9's upper pin, which the results hold, and the voltage of the net on R2's lower wire -- leaving one ellipse tagged `plot` and one net colour; then the block is opened in a second window and the mode goes with it (entered; the clicks were made where asked; the queue; one marker with that tag; a net is coloured; a second window; the mode's canvas is the new one)" \
        [list $entered $::pg_clobber $queue [lmap m $marks_before { lindex $m 3 }] [expr {[llength $hi_before] > 0 ? 1 : 0}] $two \
              [expr {$two && [pcall set ::ase::ui::sod($PGKEY,canvas)] eq $below ? 1 : 0}]] \
        {1 0 {i(r9:n1) v(neta)} plot 1 1 1}
    if {$two} {
        set ::pg_notices {}
        pcall xschem set modified 0
        # what the window's own close button runs
        pcall xschem exit closewindow force
        update ; pm_settle
        set said [lsearch -all -inline -glob $::pg_notices {ase:*}]
        set traces {}
        catch {
            foreach g [dict get [wviewer::layout_for $PGKEY] graphs] {
                foreach tr [dict get $g traces] { lappend traces [dict get $tr vec] }
            }
        }
        pcall xschem new_schematic switch $first {} 0
        set left [list [pg_marks] [expr {[pcall xschem list_hilights all] eq $hi_before ? {as before} : [pcall xschem list_hilights all]}]]
        check "PF1 CLOSING THE WINDOW DROPS DIRECT PLOT AND SAYS WHAT BECAME OF THE QUEUE: after the second window is closed no mode is up and only the first context is left -- no viewer was opened and no trace was made -- and the ONE sentence said, beside the mode being dropped, is that 2 queued traces were not plotted and that their colours stay on the schematic until the highlights are cleared; and they do stay: the first window's ellipse and its net colour are as they were before the close (the mode; the contexts; the viewer's traces; what ASE-L said; the markers and the highlights of the first window)" \
            [list [pg_mode] [pm_wins] $traces $said $left] \
            [list 0 [list $first] {} \
                  [list "ase: the design window the pick mode was on is gone — mode dropped; 2 queued traces were not plotted, and the colours their picks left on the schematic stay until the highlights are cleared (Highlight > Un-highlight all net/pins, or its key)"] \
                  [list $marks_before {as before}]]
        pcall xschem unhilight_all
        check "PF2 ...and clearing the highlights, as the sentence says, takes both away (the markers; the highlights)" \
            [list [pm_list] [pcall xschem list_hilights all]] {{} {}}
    }
    catch {ase::ui::sod_end $PGKEY}
    catch {wviewer::close $PGKEY}
    if {[llength [pm_wins]] > 1} { pm_close_ctx $below $first }
    pcall xschem unhilight_all
    file delete -force $pg_raw
    raise . ; pm_settle
}

# ---------------------------------------------------------------------------
# P8 — THE KEYS, pressed.  LAST GROUP OF THE BAND
# ---------------------------------------------------------------------------
# Real key events on the design canvas: the stock Shift+K, then key 0 once the
# Cadence-style profile is sourced into this session, then key 0 with Select
# On Design up.  The binding Tk reports for <Key-0> after the WHOLE profile was
# sourced is what a later rebinding in that file would change.
#
# This group stays last, and loads no sheet once the profile is in: the profile
# empties XSCHEM_LIBRARY_PATH, after which res.sym no longer resolves, and it
# rebinds the canvas's keys for the rest of the process.  The key helper is
# pg_real_key, above group PD.
#
# two markers, one of each tag a pick leaves; answers how many are listed
proc pg_two_marks {} {
    pcall xschem pin_marker clear -fast
    pcall xschem pin_marker add -fast -tag save R9 P
    pcall xschem pin_marker add -fast -tag plot R2 P
    return [llength [pm_list]]
}
group P8 {
    pg_fresh ; pm_settle
    pcall xschem zoom_box 200 -100 800 150
    pcall xschem redraw ; pm_settle
    set cv [pcall xschem get current_win_path]
    raise . ; pm_settle

    set stock [bind $cv <Key-0>]
    set n0 [pg_two_marks]
    set sent0 [pg_real_key $cv <KeyPress> -keysym 0]
    set kept [llength [pm_list]]
    set sentk [pg_real_key $cv <KeyPress> -keysym K -state 1]
    check "P8a THE STOCK SHIFT+K, PRESSED: with two markers listed, a real key 0 on the design canvas -- no clear-all key under the stock bindings, where the canvas binds nothing to it -- leaves both, and a real Shift+K empties the list (the stock binding of key 0; the key was sent; markers before and after it; Shift+K was sent; the list after)" \
        [list $stock $sent0 $n0 $kept $sentk [pm_list]] {{} 1 2 2 1 {}}

    set n1 [pg_two_marks]
    set rcerr [catch {uplevel #0 [list source [file join $repo src cadence_style_rc]]} rcmsg]
    pm_settle
    set bound [bind $cv <Key-0>]
    set n2 [llength [pm_list]]
    set sent [pg_real_key $cv <Key-0>]
    check "P8b THE PROFILE'S KEY 0, PRESSED: the Cadence-style profile sources into this session without an error; the binding Tk then reports for key 0 on the design canvas runs `xschem unhilight_all` and stops there; and a real key 0 empties the two-marker list, which sourcing the profile had left alone (the source's catch code; the binding is that command; markers before the source and after it; the key was sent; the list after)" \
        [list $rcerr [regexp {^\s*xschem unhilight_all;\s*break\s*$} $bound] $n1 $n2 $sent [pm_list]] {0 1 2 2 1 {}}

    pcall xschem pin_marker clear -fast
    set pre_esc [bind $cv <Key-Escape>]
    lassign [pm_coord R9 P] rx ry
    set entered [pg_enter outputs]
    pm_settle
    set seized [list [bind $cv <ButtonPress-1>] [expr {[bind $cv <Key-0>] eq $bound}]]
    pg_real_click $cv $rx $ry
    set said1 $::pg_notices ; set m1 [pg_marks]
    set sent [pg_real_key $cv <Key-0>]
    set m2 [pg_marks] ; set up2 [pg_mode]
    pg_real_click $cv $rx $ry
    set m3 [pg_marks]
    set esc [pg_real_esc $cv $pre_esc]
    check "P8c KEY 0 WITH SELECT ON DESIGN UP: the mode seizes the button press and leaves key 0 to the profile; a real click on R9's P pin queues its row and marks the pin; a real key 0 empties the list and the mode stays armed; the same pin clicked again is marked again; and a real ESC ends the mode and clears the marker (entered; the press binding and key 0's unchanged; the clicks were made where asked; what the first said; the list after it; key 0 was sent; the list and the mode after it; the list after the second click; ESC ended the mode; the list and the mode at the end)" \
        [list $entered $seized $::pg_clobber $said1 $m1 $sent $m2 $up2 $m3 $esc [pg_marks] [pg_mode]] \
        [list 1 [list [pg_press] 1] 0 [list "ase: queued output 'i(r9:n1)' (added)"] \
              {{R9 0 16 save}} 1 {} 1 {{R9 0 16 save}} 1 {} 0]

    # the drag of group PD, with the profile's bindings on the canvas.  The
    # profile switches on a crosshair and a snap cursor, which are drawn where
    # the pointer is; they are switched off so that the pixel legs read the
    # sheet alone.
    set ::draw_crosshair 0 ; set ::snap_cursor 0
    pcall xschem redraw ; pm_settle
    set st [ase::session_state $PGKEY]
    dict set st outputs {}
    ase::session_update $PGKEY $st
    pcall xschem unselect_all
    pcall xschem select instance R9
    pm_settle
    set pre [pg_slots $cv]
    set sel0 [list [pcall xschem get lastsel] [pcall xschem selected_set]]
    set entered [pg_enter outputs]
    pm_settle
    check "P8d A DRAG IN THE MODE, WITH THE PROFILE IN: the rows of group PD's drag hold with the Cadence-style profile sourced -- the long drag from the wire, the click on a pin that drifts by two pixels, the real ESC -- with the selection made before the mode kept throughout and nothing drawn (the selection before the mode; entered; the held-motion slot now; then PD1's list)" \
        [list $sel0 $entered [bind $cv <B1-Motion>] [pg_drag_rows $cv $pre]] \
        [list {1 {{R9}}} 1 break $PG_DRAG]
    catch {ase::ui::sod_end $PGKEY}
    pg_real_key $cv <Key-Escape>
    pcall xschem unselect_all
}

catch {xschem window_snapshot free}
}

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr : FAIL"; puts $::errorInfo; incr fail }

# leave nothing of band G's behind in this process
catch {ase::ui::sod_end $PGKEY}
catch {ase::session_close $PGKEY}
catch {foreach c $pg_fake { rename ::ase::ui::$c {} }}
if {[info commands ::ase::ui::pg_real_bus_dialog] ne {}} {
    catch {rename ::ase::ui::bus_dialog {}} ; catch {rename ::ase::ui::pg_real_bus_dialog ::ase::ui::bus_dialog}
}
if {[info commands pg_real_ciw_echo] ne {}} { catch {rename ciw_echo {}} ; catch {rename pg_real_ciw_echo ciw_echo} }

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
