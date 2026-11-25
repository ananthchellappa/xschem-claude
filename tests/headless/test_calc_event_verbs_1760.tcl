# tests/headless/test_calc_event_verbs_1760.tcl -- measurements anchored on an
# event (issue 1760): a NUMBER argument that holds a measurement call, and the
# verbs `integBetween`, `valueWhen`, `ymax`, `ymin`, `xmax`, `xmin`.
#
# The request (a designer's hand-off, 2026-11-21): three numbers off one
# transient -- when a comparator trips, a node's voltage at that instant, the
# charge that flows after it -- which ngspice's WHEN, FIND ... WHEN and
# INTEG FROM TO give.  The Calculator refused `value(w, cross(...))` ("X point
# must be a finite number"), and the only way to write the charge, a gated
# `integ(i*(time>t0)*(time<t1))`, answered half of it.
#
# Spec     doc/claude/specs/calculator.md section 7.2 (the six rows), R423-R426
# Code     src/calculator.tcl: the blocks headed "A NUMBER ARGUMENT MAY BE AN
#          EXPRESSION" and "EVENT-ANCHORED MEASUREMENTS"
# Fixture  tests/headless/data/calc_fixture.raw, written by ngspice from
#          calc_fixture.cir beside it: v(ramp) is 1 V/ms over 10 ms, v(sq) a
#          pulse whose 50 % crossings are at 1.0 / 5.0 / 9.0 ms rising and
#          2.2 / 6.2 ms falling, v(div) is v(ramp)/2 in dataset 0 and /4 in
#          dataset 1, the AC plot is one pole at 1 kHz.  Every expected number
#          below is derived by hand from that deck, never read back from a run.
#          One more file is written here: a DC sweep that runs DOWNWARD.
#
# EVERY NUMBER ROW SAYS WHAT WOULD MAKE IT WRONG.  A window verb that counted
# samples only answers 7.3 where band EVD expects 7.35; a gated integral
# answers 3.0e-3 where band EVB expects 2.9156e-3; a nested anchor rounded to
# the 8 digits `xschem raw value` prints does not reproduce the typed-number
# form to the last digit, which band EVA asks for.
#
# BREAKS MEASURED (2026-11-24, each built in a scratch copy of src/calculator.tcl
# and this suite run on it; the receipt is the issue file's table):
#   the nested text handed to the verb unevaluated; the shape check not asked;
#   the unqualified-signal and the save-list descents removed; the depth bound
#   removed; integBetween's limits not interpolated; its direction check
#   removed; the extremum's limit candidates removed; the rounding hair not
#   forgiven; a short call padded for every verb; a blank limit refused.
#
# REGISTERED IN `hcases`.  Nothing here needs a display; the window's own Eval
# press on a nested call is band PG14E of tests/headless/test_calc_pick.tcl.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_calc_event_verbs_1760

source [file join [file dirname [info script]] scratch.tcl]
set scratch [test_scratch calcev1760]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:[pcall_listable $r]" }
    return $r
}
proc pcall_listable {s} {
    if {![catch {llength $s}]} { return $s }
    set m [string map [list \{ ( \} ) \" '] $s]
    if {![catch {llength $m}]} { return $m }
    return [regsub -all {[^A-Za-z0-9 ._:,/()=+*<>?!-]} $s ?]
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
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

proc fld {d k} {
    if {[string match ERR:* $d]} { return $d }
    if {[catch {dict get $d $k} v]} { return "NOKEY:$k" }
    return $v
}
# `ok` when a and b agree to a part in 1e9 (1e-12 absolute against zero), else
# a word that shows both
proc close9 {a b} {
    if {![string is double -strict $a] || ![string is double -strict $b]} { return "NAN:$a/$b" }
    set tol [expr {$b == 0 ? 1e-12 : abs($b) * 1e-9}]
    return [expr {abs($a - $b) <= $tol ? {ok} : "FAR:$a/$b"}]
}
# 1 when lo < x < hi, 0 when not, and a word when x is not a number -- so a
# refusal in x's place reddens the row instead of raising out of its band
proc between {x lo hi} {
    if {![string is double -strict $x]} { return "NAN:$x" }
    return [expr {$x > $lo && $x < $hi}]
}
# |a - b| / |b|, or a word
proc reldiff {a b} {
    if {![string is double -strict $a] || ![string is double -strict $b] || $b == 0} { return "NAN:$a/$b" }
    return [expr {abs($a - $b) / abs($b)}]
}
# 1 when a and b differ by more than a part in 1e6: the distinctness leg
proc apart {a b} {
    if {![string is double -strict $a] || ![string is double -strict $b]} { return 0 }
    return [expr {abs($a - $b) > 1e-6 * (abs($a) > abs($b) ? abs($a) : abs($b))}]
}

set fixture {}
foreach cand [list tests/headless/data/calc_fixture.raw \
                   [file join [file dirname [info script]] data calc_fixture.raw]] {
    if {$fixture eq {} && [file exists $cand]} { set fixture [file normalize $cand] }
}
# One text through the pure evaluator, on a file (the committed one unless given)
proc ev {text {file {}}} {
    if {$file eq {}} { set file $::fixture }
    return [pcall calc::eval_text $text $file {}]
}
# ...its number, or a word that carries the refusal
proc val {text {file {}}} {
    set d [ev $text $file]
    if {[fld $d ok] ne {1}} { return "REFUSED:[fld $d msg]" }
    return [fld $d value]
}
proc msg {text {file {}}} { return [fld [ev $text $file] msg] }
proc ev_load {type {file {}}} {
    if {$file eq {}} { set file $::fixture }
    catch {xschem raw clear}
    if {[catch {xschem raw read $file $type} r]} { return "ERR:$r" }
    return $r
}
proc ev_info {} { return [pcall xschem raw info] }
proc ev_leaked {} {
    set out {}
    if {[catch {xschem raw list} l]} { return {} }
    foreach n $l { if {[string match __calc_tmp* $n]} { lappend out $n } }
    return $out
}
# A DC sweep that runs DOWNWARD, 5 to 0 in steps of 0.5 (a load-current sweep
# written `start 1.01m stop 0 step -10u` is what a designer's bench does):
# v(a) = 2x, v(p) = x(5-x).
proc ev_dc_raw {path} {
    set f [open $path w]
    fconfigure $f -translation binary
    set np 11
    puts -nonewline $f "Title: event verbs dc fixture\nDate: Tue Nov 24 00:00:00  2026\nPlotname: DC transfer characteristic\nFlags: real\nNo. Variables: 3\nNo. Points: $np\nVariables:\n\t0\tv-sweep\tvoltage\n\t1\tv(a)\tvoltage\n\t2\tv(p)\tvoltage\nBinary:\n"
    for {set i 0} {$i < $np} {incr i} {
        set x [expr {5.0 - 0.5 * $i}]
        puts -nonewline $f [binary format q3 [list $x [expr {2.0 * $x}] [expr {$x * (5.0 - $x)}]]]
    }
    close $f
}
set dcraw [file join $scratch ev_dc.raw]
ev_dc_raw $dcraw

set SIX {valueWhen integBetween ymax ymin xmax xmin}
set RISE {cross(vt(sq), 0.5, 1, rising)}
set FALL {cross(vt(sq), 0.5, 1, falling)}

# =============================================================================
# EV0 -- the fixture, and the six verbs are really there
# =============================================================================
group EV0 {
    check {EV0 fixture: the committed raw was located and the registry starts empty} \
        [list [expr {$::fixture ne {}}] [ev_info]] {1 {}}
    set rows {} ; set verbs {} ; set sigs {}
    foreach v $SIX {
        lappend rows [lrange [pcall calc::fn_row $v] 1 3]
        lappend verbs [pcall calc::meas_verb $v]
        lappend sigs [pcall info args ::calc::$v]
    }
    check {EV0 each of the six is a catalogue row in Special Functions, route T, returning a scalar, and a verb a call can be composed for} \
        [list $rows $verbs] \
        [list [lrepeat 6 {{Special Functions} T scalar}] {1 1 1 1 1 1}]
    check {EV0 their formals, read from the interpreter: the wave first, then what the call carries} \
        $sigs {{rpn rpnTrig level edge nth dataset} {rpn t0 t1 dataset} {rpn from to dataset} {rpn from to dataset} {rpn from to dataset} {rpn from to dataset}}
    # the hand-derived references are only worth anything if the fixture is
    # what its deck says: three samples of the ramp and of the pulse
    ev_load tran
    set t [pcall xschem raw values time 0]
    set r [pcall xschem raw values v(ramp) 0]
    set q [pcall xschem raw values v(sq) 0]
    check {EV0 fixture: 101 samples on a 0.1 ms grid, the ramp at 1 V/ms (samples 10, 50), the pulse at half height on samples 10 and 22 and at 0 and 1 on either side} \
        [list [llength $t] [close9 [lindex $t 10] 1e-3] [close9 [lindex $r 10] 1.0] [close9 [lindex $r 50] 5.0] \
              [close9 [lindex $q 10] 0.5] [close9 [lindex $q 22] 0.5] [close9 [lindex $q 9] 0.0] [close9 [lindex $q 11] 1.0]] \
        {101 ok ok ok ok ok ok ok}
    set ::X0 [lindex $t 0]
    set ::X1 [lindex $t end]
    check {EV0 fixture: the sweep ends a rounding hair short of 10 ms, which is the case the forgiven hair of band EVB is about} \
        [list [expr {$::X1 < 0.01}] [expr {0.01 - $::X1 < 1e-15}]] {1 1}
    catch {xschem raw clear}
}

# =============================================================================
# EVA -- A NUMBER ARGUMENT MAY HOLD A MEASUREMENT
# =============================================================================
group EVA {
    check {EVA1 value(wave, cross(...)) reads the wave AT the crossing: the ramp is 1 V/ms, so at the first and second rising and the first falling 50 % crossing of the pulse it reads 1.0, 5.0 and 2.2} \
        [list [close9 [val "value(vt(ramp), $RISE)"] 1.0] \
              [close9 [val {value(vt(ramp), cross(vt(sq), 0.5, 2, rising))}] 5.0] \
              [close9 [val "value(vt(ramp), $FALL)"] 2.2]] {ok ok ok}
    # the nested anchor is the crossing's own full-precision number: typing that
    # number in gives the identical answer, on a wave that is NOT a straight line
    set n [val $RISE]
    set a [val "value(vt(lp), $RISE)"]
    set b [val "value(vt(lp), $n)"]
    set c [val "value(vt(lp), $FALL)"]
    set z [val "value(vt(lp), $RISE + 0)"]
    check {EVA2 the nested form answers the SAME number, to the last digit, as the crossing's own number typed in its place -- on the filtered wave, where a rounded anchor would show -- and so does the crossing plus nothing, which goes through the engine; that number differs from the value at the other edge} \
        [list [string is double -strict $a] [expr {$a eq $b}] [expr {$a eq $z}] [apart $a $c]] {1 1 1 1}
    check {EVA3 a wave read at its own crossing of a level IS that level (0.3 and 0.7 of the filtered pulse)} \
        [list [close9 [val {value(vt(lp), cross(vt(lp), 0.3, 1, rising))}] 0.3] \
              [close9 [val {value(vt(lp), cross(vt(lp), 0.7, 1, falling))}] 0.7]] {ok ok}
    check {EVA4 ARITHMETIC around a measurement: a quarter of a millisecond after the crossing the ramp reads 1.25, at twice the crossing 2.0, and at the pulse's own width (falling minus rising, 1.2 ms) 1.2} \
        [list [close9 [val "value(vt(ramp), $RISE + 0.25m)"] 1.25] \
              [close9 [val "value(vt(ramp), 2*$RISE)"] 2.0] \
              [close9 [val "value(vt(ramp), $FALL - $RISE)"] 1.2]] {ok ok ok}
    check {EVA5 the number slot of EVERY verb takes it, at two levels, with an infix wave inside: a crossing level read off another wave (2 ms), a level that is half a value (1.5), a difference of two waves (2.0), overshoot against a value read at 5 ms (100 %), and a rise time whose high level is the value at the end of the sweep (8 ms)} \
        [list [close9 [val {cross(vt(ramp), value(vt(div), 4m), 1, rising)}] 0.002] \
              [close9 [val {value(vt(ramp), cross(vt(ramp), value(vt(ramp), 3m)*0.5, 1, rising))}] 1.5] \
              [close9 [val {value(vt(ramp), cross(vt(ramp)-vt(div), 1, 1, rising))}] 2.0] \
              [close9 [val {overshoot(vt(ramp), 0, value(vt(ramp), 5m), 0)}] 100.0] \
              [close9 [val {riseTime(vt(ramp), 0, value(vt(ramp), 10m), 10, 90, 1, 0)}] 0.008]] \
        {ok ok ok ok ok}
    # --- refusals BEFORE any read: the sentence names the outer verb and field
    set t1 {value(vt(ramp), cross(vt(sq), 0.5, 1))}
    set t2 {value(vt(ramp), cross(vt(sq), abc, 1, rising))}
    set t3 {value(vt(ramp), crss(vt(sq), 0.5, 1, rising))}
    check {EVA6 a malformed call inside is refused before any read, and the sentence names the outer verb, its field and the fault: the literals a user reads for a short call and for a misspelt name, and the product's own builders for a bad field} \
        [list [msg $t1] [msg $t3] \
              [expr {[msg $t2] eq [calc::meas_msg fields value [calc::arg_msg nested {X point} [calc::meas_msg fields cross [calc::arg_msg real Level abc]]]]}] \
              [fld [pcall calc::et_check $t1] ok] [fld [pcall calc::et_check $t2] ok] [fld [pcall calc::et_check $t3] ok]] \
        [list {value: X point: cross takes 4 arguments.} {value: X point: unknown function 'crss'.} 1 0 0 0]
    set same {} ; set n 0
    foreach t {abc vt(sq) +3u (1u+2u) 1u+ 1e nan 2*3 {1 2 +}} {
        incr n
        if {[pcall calc::arg_field_bad {X point} real $t] ne [calc::arg_msg real {X point} $t]} { lappend same $t }
    }
    check {EVA7 what was never a number stays refused in the words it always had: a word, a bare signal, a signed or bracketed figure, arithmetic with no measurement in it -- and M is still milli, a number still a number} \
        [list $n $same \
              [expr {[pcall calc::arg_field_bad {X point} real 1M] eq [calc::arg_msg capM {X point} 1M]}] \
              [pcall calc::arg_field_bad {X point} real 100u] [pcall calc::arg_field_bad {X point} real -2.5e-3] \
              [pcall calc::arg_field_bad {X point} real $RISE]] \
        {9 {} 1 {} {} {}}
    # --- refusals AFTER a read: the inner verb's own sentence, carried
    set w [msg {value(vt(ramp), riseTime(vt(sq), 0, 1, 10, 90, 0, 0))}]
    set l [msg {value(vt(ramp), cross(vt(sq), 0.5, 0, rising))}]
    set a [msg {value(vt(ramp), cross(vt(sq), 5, 1, rising))}]
    set z [msg "value(vt(ramp), $RISE/0)"]
    check {EVA8 a call inside that answers a waveform, a list, or nothing, and arithmetic that divides by zero, are each refused in the inner sentence behind the outer verb and field -- and the registry is left empty} \
        [list [expr {$w eq [calc::meas_msg fields value [calc::arg_msg nested {X point} [calc::nest_say [calc::ix_msg nestwave riseTime]]]]}] \
              [expr {$l eq [calc::meas_msg fields value [calc::arg_msg nested {X point} [calc::cross_msg listdefer]]]}] \
              [expr {$a eq [calc::meas_msg fields value [calc::arg_msg nested {X point} [calc::cross_msg absent 1st rising]]]}] \
              [expr {$z eq [calc::meas_msg fields value [calc::arg_msg nested {X point} [calc::nest_say [calc::et_msg divzero]]]]}] \
              [ev_info]] {1 1 1 1 {}}
    check {EVA9 a signal with no analysis is refused naming it although it sits inside the nested call, and two analyses in one text are refused} \
        [list [string match {Cannot evaluate: v(sq) names no analysis; write vt(sq)*} [msg {value(vt(ramp), cross(v(sq), 0.5, 1, rising))}]] \
              [expr {[msg {value(vt(ramp), cross(vf(lp), 0.5, 1, falling))}] eq [calc::aq_msg mixed vt vf]}]] {1 1}
    check {EVA10 the save list reads the signals of the nested calls too -- one level, two levels with arithmetic, and inside an operand of an expression -- so a run saves what the row will read} \
        [list [pcall calc::eval_text_signals "value(vt(ramp), $RISE)"] \
              [pcall calc::eval_text_signals {value(vt(ramp), cross(vt(lp), value(vt(div), 3m), 1, rising)+1u)}] \
              [pcall calc::eval_text_signals "2*value(vt(ramp), $RISE)"]] \
        {{v(ramp) v(sq)} {v(ramp) v(lp) v(div)} {v(ramp) v(sq)}}
    # --- the bound: each crossing of the ramp at level L is L milliseconds
    set deep 5
    for {set k 0} {$k < 8} {incr k} { set deep "cross(vt(ramp), $deep, 1, rising)" }
    set deep8 "cross(vt(ramp), $deep, 1, rising)"
    set deep9 "cross(vt(ramp), $deep8, 1, rising)"
    check {EVA11 nesting is bounded: eight calls inside one another evaluate (the ramp's crossing of L is L ms, nine times over), the ninth is refused by name, and the depth count is back at zero} \
        [list [close9 [val $deep8] 5e-27] \
              [string match "*[calc::nest_say [calc::ix_msg deep [calc::nest_maxdepth]]]" [msg $deep9]] \
              [pcall calc::nest_maxdepth] $::calc::nest_depth] {ok 1 8 0}
    # --- the window's own body, without a window: calc::meas_in_ctx
    ev_load tran
    set vals [pcall calc::meas_numeric value [list rpn vt(ramp) x $RISE]]
    set d1 [pcall calc::meas_in_ctx value $vals tran]
    ev_load ac
    set before [ev_info]
    set d2 [pcall calc::meas_in_ctx value $vals tran]
    check {EVA12 the measurement body the window's Eval runs (calc::meas_in_ctx) answers the same 1.0, with the transient loaded and with the AC analysis loaded -- there it reads the transient for the call and puts the registry back as it was -- and leaves no temporary} \
        [list [close9 [fld $d1 value] 1.0] [close9 [fld $d2 value] 1.0] \
              [expr {[ev_info] eq $before}] [ev_leaked]] {ok ok 1 {}}
    catch {xschem raw clear}
    # --- the dialog's decision and the composed call (no Tk)
    set ::calc::argval(x) $RISE
    set ok1 [pcall calc::arg_trouble [calc::fn_argspec value]]
    set ::calc::argval(x) {cross(vt(sq), 0.5, 1)}
    set bad1 [pcall calc::arg_trouble [calc::fn_argspec value]]
    set call [pcall calc::meas_compose value [list rpn vt(ramp) x $RISE]]
    set back [pcall calc::meas_vals value [fld [pcall calc::meas_split $call] args]]
    check {EVA13 the argument dialog takes the call in its number field and names a malformed one; the composed call carries it whole and splits back to the same arguments; a top-level comma in a number field, and any comma in a wave field, still cannot be composed} \
        [list $ok1 $bad1 $call $back \
              [pcall calc::meas_compose value {rpn vt(ramp) x 1,5}] \
              [pcall calc::meas_compose value {rpn v(a,b) x 1}]] \
        [list {} {{X point: cross takes 4 arguments.}} "value(vt(ramp), $RISE)" [list rpn vt(ramp) x $RISE] {} {}]
    unset -nocomplain ::calc::argval(x)
}

# =============================================================================
# EVB -- integBetween: THE AREA BETWEEN TWO X VALUES, ENDS INTERPOLATED
# =============================================================================
group EVB {
    # the ramp is 1000 t, so its area from a to b is 500 (b^2 - a^2), exactly,
    # for limits on the grid or off it
    check {EVB1 the area under the 1 V/ms ramp from 1 to 3 ms is 4.0e-3, and between two limits that fall BETWEEN samples (1.23 and 2.71 ms) 2.9156e-3} \
        [list [close9 [val {integBetween(vt(ramp), 1m, 3m)}] 0.004] \
              [close9 [val {integBetween(vt(ramp), 1.23m, 2.71m)}] 0.0029156]] {ok ok}
    # the gate keeps the samples 1.3 .. 2.7 ms and counts 1.2-1.3 and 2.7-2.8 as
    # triangles from zero: 0.065e-3 + 2.8e-3 + 0.135e-3
    set g [fld [ev {integ(vt(ramp)*(time>1.23m)*(time<2.71m))}] value]
    set b [val {integBetween(vt(ramp), 1.23m, 2.71m)}]
    check {EVB2 A GATE IS NOT A LIMIT: the gated integ() of the same wave over the same window is still what it was, 3.0e-3 -- the samples inside plus a triangle down to zero at each end -- and is NOT the area between the limits, from which it differs by 2.9 %} \
        [list [close9 $g 0.003] [between [reldiff $g $b] 0.028 0.030]] {ok 1}
    check {EVB3 the limits may be events: from the pulse's rising 50 % crossing to its falling one the ramp's area is 1.92e-3, and from the crossing to 0.5 ms after it 0.625e-3} \
        [list [close9 [val "integBetween(vt(ramp), $RISE, $FALL)"] 0.00192] \
              [close9 [val "integBetween(vt(ramp), $RISE, $RISE + 0.5m)"] 0.000625]] {ok ok}
    check {EVB4 a wave that is not a line: the whole pulse is 1.2e-3 V s (two half-area edges and a 1 ms top), and cut at its own half-height points 1.15e-3} \
        [list [close9 [val {integBetween(vt(sq), 0, 4m)}] 0.0012] \
              [close9 [val {integBetween(vt(sq), 1m, 2.2m)}] 0.00115]] {ok ok}
    check {EVB5 the dataset: the divider is half the ramp in dataset 0 and a quarter in dataset 1, so its whole area is 25e-3 and 12.5e-3 -- and a call that leaves the dataset out reads dataset 0} \
        [list [close9 [val {integBetween(vt(div), 0, 10m, 0)}] 0.025] \
              [close9 [val {integBetween(vt(div), 0, 10m, 1)}] 0.0125] \
              [close9 [val {integBetween(vt(div), 0, 10m)}] 0.025]] {ok ok ok}
    check {EVB6 A LIMIT A ROUNDING HAIR PAST THE END IS THE END: this sweep stops just short of the 10 ms it was asked for and 10m is taken (the row above), also by value() and by a window verb; a limit a real distance past either end is refused naming the limit and the sweep} \
        [list [close9 [val {value(vt(ramp), 10m)}] 10.0] [close9 [val {ymax(vt(ramp), 9m, 10m)}] 10.0] \
              [expr {[msg {integBetween(vt(ramp), 0, 20m)}] eq [calc::cross_msg ibrange 20e-3 "$::X0 to $::X1"]}] \
              [expr {[msg {integBetween(vt(ramp), -1m, 2m)}] eq [calc::cross_msg ibrange -1e-3 "$::X0 to $::X1"]}] \
              [expr {[msg {value(vt(ramp), 10.0001m)}] eq [calc::cross_msg valrange 10.0001e-3 "$::X0 to $::X1"]}]] \
        {ok ok 1 1 1}
    check {EVB7 on the AC analysis the X is the frequency: the source's flat magnitude of 1 from 100 Hz to 2 kHz has an area of 1900, and the filtered one less} \
        [list [close9 [val {integBetween(vf(sq), 100, 2k)}] 1900.0] \
              [between [val {integBetween(vf(lp), 100, 2k)}] [expr {0.4472 * 1900.0}] 1900.0]] {ok 1}
    check {EVB8 refusals in the text door, each by the product's own sentence: limits out of order, an operating point (no sweep), a short call, a fifth argument} \
        [list [expr {[msg {integBetween(vt(ramp), 3m, 2m)}] eq [calc::cross_msg iborder 3e-3 2e-3]}] \
              [expr {[msg {integBetween(vdc(dcmid), 0, 1)}] eq [calc::cross_msg spannosweep integBetween op]}] \
              [msg {integBetween(vt(ramp), 1m)}] [msg {integBetween(vt(ramp), 1m, 2m, 0, 0)}]] \
        [list 1 1 {integBetween takes 3 to 4 arguments.} {integBetween takes 3 to 4 arguments.}]
    # the REQUEST is judged before anything is read: nothing is loaded here
    catch {xschem raw clear}
    check {EVB9 with NO results loaded a request that cannot be read is refused for what is wrong with it, not for the missing data: a missing limit, a limit that is not a number, limits out of order, an empty expression -- and a sound request then says there is no data} \
        [list [expr {[fld [pcall calc::integBetween v(ramp) {} 1e-3] msg] eq [calc::cross_msg ibnolim {} 1e-3]}] \
              [expr {[fld [pcall calc::integBetween v(ramp) nan 1e-3] msg] eq [calc::cross_msg ibbadlim nan]}] \
              [expr {[fld [pcall calc::integBetween v(ramp) 2e-3 2e-3] msg] eq [calc::cross_msg iborder 2e-3 2e-3]}] \
              [expr {[fld [pcall calc::integBetween {} 1e-3 2e-3] msg] eq [calc::cross_msg spanempty integBetween]}] \
              [expr {[fld [pcall calc::integBetween v(ramp) 1e-3 2e-3] msg] eq [calc::cross_msg nodata]}]] \
        {1 1 1 1 1}
    ev_load tran
    set bt [pcall calc::integBetween v(nosuch) 1e-3 2e-3]
    check {EVB10 with the transient loaded: an unknown signal is refused naming it, a dataset the result does not have, all-points and a fractional dataset each in the family's own words -- and no temporary is left behind by any of them} \
        [list [fld $bt ok] [string match {*v(nosuch)*} [fld $bt msg]] \
              [expr {[fld [pcall calc::integBetween v(ramp) 1e-3 2e-3 2] msg] eq [calc::cross_msg dataset 2 2]}] \
              [expr {[fld [pcall calc::integBetween v(ramp) 1e-3 2e-3 -1] msg] eq [calc::cross_msg allpoints -1]}] \
              [expr {[fld [pcall calc::integBetween v(ramp) 1e-3 2e-3 1.5] msg] eq [calc::cross_msg intdataset 1.5]}] \
              [ev_leaked]] {0 1 1 1 1 {}}
    catch {xschem raw clear}
    # --- the arithmetic alone, on four samples: 0,0  1,2  2,2  3,0
    check {EVB11 the pure area: from 0.5 to 2.5 over the samples (0,0) (1,2) (2,2) (3,0) it is 3.5; the same wave handed over in DESCENDING X gives the same 3.5; a sweep that turns back is refused with the turning X; a sample that is not a number inside the limits is no answer, and outside them does not matter} \
        [list [pcall calc::area_between {0 1 2 3} {0 2 2 0} 0.5 2.5] \
              [pcall calc::area_between {3 2 1 0} {0 2 2 0} 0.5 2.5] \
              [pcall calc::area_between {0 1 2 1 0} {0 2 2 2 0} 0.5 1.5] \
              [pcall calc::area_between {0 1 2 3} {0 nan 2 0} 0.5 2.5] \
              [pcall calc::area_between {0 1 2 3} {0 2 2 nan} 0.5 1.5]] \
        {{ok 3.5} {ok 3.5} {fold 2.0} nan {ok 1.75}}
    # --- a simulator-shaped DC sweep, running downward: v(a) = 2x
    check {EVB12 a DC sweep that runs DOWNWARD (5 to 0): the area of v(a) = 2x from 1 to 4 is 15, the same number an upward sweep gives, and value() reads 4.5 at 2.25 on it} \
        [list [close9 [val {integBetween(vs(a), 1, 4)} $dcraw] 15.0] \
              [close9 [val {value(vs(a), 2.25)} $dcraw] 4.5] [ev_info]] {ok ok {}}
}

# =============================================================================
# EVC -- valueWhen: THE WAVE'S VALUE AT A CROSSING OF A TRIGGER WAVE
# =============================================================================
group EVC {
    check {EVC1 the ramp at the pulse's crossings of 0.5: first rising 1.0, second rising 5.0, first falling 2.2, second of either direction 2.2, last rising 9.0} \
        [list [close9 [val {valueWhen(vt(ramp), vt(sq), 0.5, rising, 1)}] 1.0] \
              [close9 [val {valueWhen(vt(ramp), vt(sq), 0.5, rising, 2)}] 5.0] \
              [close9 [val {valueWhen(vt(ramp), vt(sq), 0.5, falling, 1)}] 2.2] \
              [close9 [val {valueWhen(vt(ramp), vt(sq), 0.5, either, 2)}] 2.2] \
              [close9 [val {valueWhen(vt(ramp), vt(sq), 0.5, rising, -1)}] 9.0]] {ok ok ok ok ok}
    set a [val {valueWhen(vt(lp), vt(sq), 0.5, falling, 1)}]
    set b [val "value(vt(lp), $FALL)"]
    check {EVC2 it is the same number as value(wave, cross(trigger ...)), to the last digit, on the filtered wave} \
        [list [string is double -strict $a] [expr {$a eq $b}]] {1 1}
    check {EVC3 the dataset: the divider at the first rising crossing is 0.5 in dataset 0 and 0.25 in dataset 1, and a call without one reads dataset 0} \
        [list [close9 [val {valueWhen(vt(div), vt(sq), 0.5, rising, 1, 0)}] 0.5] \
              [close9 [val {valueWhen(vt(div), vt(sq), 0.5, rising, 1, 1)}] 0.25] \
              [close9 [val {valueWhen(vt(div), vt(sq), 0.5, rising, 1)}] 0.5]] {ok ok ok}
    check {EVC4 on the AC analysis: the frequency at which the one-pole response falls through 1/sqrt(2) is the pole, 1 kHz} \
        [close9 [val {valueWhen(frequency, vf(lp), 0.70710678118, falling, 1)}] 1000.0] ok
    set ab [ev {valueWhen(vt(ramp), vt(sq), 5, rising, 1)}]
    check {EVC5 refusals: every crossing at once (nth 0) in its own words; a level the trigger never reaches in cross's own sentence; a misspelt edge and a short call before any read; an operating point by cross's sentence} \
        [list [expr {[msg {valueWhen(vt(ramp), vt(sq), 0.5, rising, 0)}] eq [calc::cross_msg vwnth0 0]}] \
              [expr {[fld $ab msg] eq [calc::cross_msg absent 1st rising]}] \
              [msg {valueWhen(vt(ramp), vt(sq), 0.5, sideways, 1)}] \
              [msg {valueWhen(vt(ramp), vt(sq), 0.5, rising)}] \
              [expr {[msg {valueWhen(vdc(dcmid), vdc(dcmid), 0.5, rising, 1)}] eq [calc::cross_msg nosweep op]}]] \
        [list 1 1 {valueWhen: Edge must be one of rising, falling, either.} {valueWhen takes 5 to 6 arguments.} 1]
    catch {xschem raw clear}
    check {EVC6 with NO results loaded: an empty wave, an empty trigger and nth 0 are refused for themselves; with the transient loaded an unknown signal is named and nothing is left behind} \
        [list [expr {[fld [pcall calc::valueWhen {} v(sq) 0.5 rising 1] msg] eq [calc::cross_msg spanempty valueWhen]}] \
              [expr {[fld [pcall calc::valueWhen v(ramp) {} 0.5 rising 1] msg] eq [calc::cross_msg vwnotrig]}] \
              [expr {[fld [pcall calc::valueWhen v(ramp) v(sq) 0.5 rising 0] msg] eq [calc::cross_msg vwnth0 0]}] \
              [ev_load tran] \
              [string match {*v(nosuch)*} [fld [pcall calc::valueWhen v(nosuch) v(sq) 0.5 rising 1] msg]] \
              [ev_leaked]] {1 1 1 1 1 {}}
    catch {xschem raw clear}
    check {EVC7 a DC sweep has no crossing to read (cross's own declared limit): valueWhen says so in cross's sentence instead of answering} \
        [expr {[msg {valueWhen(vs(a), vs(p), 4, rising, 1)} $dcraw] eq [calc::cross_msg nosweep dc]}] 1
}

# =============================================================================
# EVD -- ymax / ymin / xmax / xmin
# =============================================================================
group EVD {
    check {EVD1 over the whole sweep the ramp's largest value is 10 at the last sample and its smallest 0 at the first} \
        [list [close9 [val {ymax(vt(ramp))}] 10.0] [expr {[val {xmax(vt(ramp))}] eq $::X1}] \
              [close9 [val {ymin(vt(ramp))}] 0.0] [close9 [val {xmin(vt(ramp))}] 0.0]] {ok 1 ok ok}
    check {EVD2 THE WINDOW'S OWN LIMITS COUNT, interpolated: between 2.25 and 7.35 ms, both between samples, the largest value is 7.35 at 7.35 ms and the smallest 2.25 at 2.25 ms -- the samples inside alone would say 7.3 and 2.3} \
        [list [close9 [val {ymax(vt(ramp), 2.25m, 7.35m)}] 7.35] [close9 [val {xmax(vt(ramp), 2.25m, 7.35m)}] 0.00735] \
              [close9 [val {ymin(vt(ramp), 2.25m, 7.35m)}] 2.25] [close9 [val {xmin(vt(ramp), 2.25m, 7.35m)}] 0.00225]] \
        {ok ok ok ok}
    check {EVD3 an extremum inside the window, at a sample: the pulse's top is 1 and its floor 0; the difference of two waves is read as one wave (ramp minus divider, 5 at the end)} \
        [list [close9 [val {ymax(vt(sq))}] 1.0] [close9 [val {ymin(vt(sq), 1.5m, 4m)}] 0.0] \
              [close9 [val {ymax(vt(ramp)-vt(div))}] 5.0]] {ok ok ok}
    check {EVD4 one limit alone: From only runs to the end of the sweep (10), To only -- an empty first argument -- runs from its start (3.33 at 3.33 ms); a window of one point is the value there} \
        [list [close9 [val {ymax(vt(ramp), 4m)}] 10.0] [close9 [val {ymin(vt(ramp), 4m)}] 4.0] \
              [close9 [val {ymax(vt(ramp), , 3.33m)}] 3.33] [close9 [val {xmax(vt(ramp), , 3.33m)}] 0.00333] \
              [close9 [val {ymax(vt(ramp), 2.5m, 2.5m)}] 2.5]] {ok ok ok ok ok}
    check {EVD5 the limits may be events: the ramp's largest value between the pulse's two 50 % crossings is 2.2, at the falling one} \
        [list [close9 [val "ymax(vt(ramp), $RISE, $FALL)"] 2.2] [close9 [val "xmax(vt(ramp), $RISE, $FALL)"] 0.0022]] {ok ok}
    ev_load tran
    set d0 [pcall calc::ymax v(div)]
    set d1 [pcall calc::ymax v(div) {} {} 1]
    check {EVD6 the dataset, through the verb itself: the divider peaks at 5 in dataset 0 and 2.5 in dataset 1, and nothing is left behind} \
        [list [close9 [fld $d0 value] 5.0] [close9 [fld $d1 value] 2.5] [ev_leaked]] {ok ok {}}
    catch {xschem raw clear}
    check {EVD7 on the AC analysis: the one-pole magnitude is largest at the first frequency (1/sqrt(1.01) at 100 Hz) and smallest at the last (1/sqrt(5) at 2 kHz)} \
        [list [close9 [val {ymax(vf(lp))}] [expr {1.0 / sqrt(1.01)}]] [close9 [val {xmax(vf(lp))}] 100.0] \
              [close9 [val {ymin(vf(lp))}] [expr {1.0 / sqrt(5.0)}]] [close9 [val {xmin(vf(lp))}] 2000.0]] {ok ok ok ok}
    check {EVD8 on the DC sweep that runs downward: v(p) = x(5-x) peaks at 6.25 where x is 2.5; between 1 and 4 its smallest value is 4, at the limit met first; and its largest between 3.2 and 4.6 is at the limit: 5.7 at 3.2, on the straight line between the samples at 3 and 3.5 (the parabola itself would be 5.76)} \
        [list [close9 [val {ymax(vs(p))} $dcraw] 6.25] [close9 [val {xmax(vs(p))} $dcraw] 2.5] \
              [close9 [val {ymin(vs(p), 1, 4)} $dcraw] 4.0] [close9 [val {xmin(vs(p), 1, 4)} $dcraw] 1.0] \
              [close9 [val {ymax(vs(p), 3.2, 4.6)} $dcraw] 5.7] [close9 [val {xmax(vs(p), 3.2, 4.6)} $dcraw] 3.2]] \
        {ok ok ok ok ok ok}
    check {EVD9 refusals, each by the product's own sentence: limits out of order, a limit outside the sweep at either end, an operating point, a fourth argument, a limit that is a word} \
        [list [expr {[msg {ymax(vt(ramp), 3m, 2m)}] eq [calc::cross_msg exorder 3e-3 2e-3]}] \
              [expr {[msg {ymin(vt(ramp), 3m, 20m)}] eq [calc::cross_msg exrange 20e-3 "$::X0 to $::X1"]}] \
              [expr {[msg {ymin(vt(ramp), -1m, 2m)}] eq [calc::cross_msg exrange -1e-3 "$::X0 to $::X1"]}] \
              [expr {[msg {xmax(vdc(dcmid))}] eq [calc::cross_msg spannosweep xmax op]}] \
              [msg {xmin(vt(ramp), 1m, 2m, 3m)}] \
              [expr {[msg {ymax(vt(ramp), soon)}] eq [calc::meas_msg fields ymax [calc::arg_msg real {From (X)} soon]]}]] \
        [list 1 1 1 1 {xmin takes 1 to 3 arguments.} 1]
    catch {xschem raw clear}
    check {EVD10 with NO results loaded a limit that is not a number, limits out of order and an empty expression are refused for themselves, and a sound request says there is no data} \
        [list [expr {[fld [pcall calc::ymax v(ramp) nan] msg] eq [calc::cross_msg exbadlim nan]}] \
              [expr {[fld [pcall calc::xmin v(ramp) 2 1] msg] eq [calc::cross_msg exorder 2 1]}] \
              [expr {[fld [pcall calc::ymin {}] msg] eq [calc::cross_msg spanempty ymin]}] \
              [expr {[fld [pcall calc::xmax v(ramp)] msg] eq [calc::cross_msg nodata]}]] {1 1 1 1}
    check {EVD11 the pure extremum: among equal values the first one met wins (x 1, not 2); a sample that is not a number is passed over; a window holding none is no answer; the limits are candidates, a sample outside them is not} \
        [list [pcall calc::extremum_in {0 1 2 3} {0 5 5 1} max {} {}] \
              [pcall calc::extremum_in {0 1 2 3} {0 nan 7 1} max {} {}] \
              [pcall calc::extremum_in {0 1 2 3} {nan nan nan nan} max {} {}] \
              [pcall calc::extremum_in {0 1 2 3} {0 2 4 100} max 0.5 2.5] \
              [pcall calc::extremum_in {0 1 2 3} {0 2 4 100} min 0.5 2.5]] \
        {{1.0 5.0} {2.0 7.0} {} {2.5 52.0} {0.5 1.0}}
}

# =============================================================================
# EVE -- THE CALL'S GRAMMAR: what may be left out, and what may be left blank
# =============================================================================
group EVE {
    check {EVE1 the argument counts as the refusal says them: a dataset may be left off the two verbs that take one, the window off the four extremum verbs} \
        [list [pcall calc::meas_arity integBetween] [pcall calc::meas_arity valueWhen] \
              [pcall calc::meas_arity ymax] [pcall calc::meas_arity xmin] [pcall calc::meas_arity cross]] \
        {{3 to 4} {5 to 6} {1 to 3} {1 to 3} 4}
    # every OTHER verb keeps its one arity: derived over the catalogue
    set one {} ; set n 0
    foreach row [pcall calc::catalogue] {
        set v [lindex $row 0]
        if {![pcall calc::meas_verb $v] || $v in $SIX} continue
        incr n
        if {[llength [pcall calc::meas_optional $v]] \
            || [pcall calc::meas_arity $v] ne [llength [pcall calc::meas_formals $v]]} { lappend one $v }
    }
    check {EVE2 NO OTHER VERB grew an optional argument: for every other verb a call can be composed for, the fewest arguments is all of them -- so a short cross() is still refused instead of being handed a default nobody saw; the count rides along} \
        [list [expr {$n >= 14}] $one [msg {cross(vt(sq), 0.5)}] [msg {value(vt(ramp))}]] \
        [list 1 {} {cross takes 4 arguments.} {value takes 2 arguments.}]
    check {EVE3 what a short call is filled with (calc::meas_typed_defaults): dataset 0, and a blank for a window limit, which the verb reads as that end of the sweep; the table holds the six verbs' trailing formals and nothing for a verb it does not name} \
        [list [pcall calc::meas_vals integBetween {w 1 2}] [pcall calc::meas_vals ymax {w}] \
              [pcall calc::meas_vals ymax {w 1}] [pcall calc::meas_vals valueWhen {w t 0.5 rising 1}] \
              [pcall calc::meas_vals ymax {}] [pcall calc::meas_vals integBetween {w 1}] \
              [pcall calc::meas_optional integBetween] [pcall calc::meas_optional xmin] [pcall calc::meas_optional value]] \
        [list {rpn w t0 1 t1 2 dataset 0} {rpn w from {} to {}} {rpn w from 1 to {}} \
              {rpn w rpnTrig t level 0.5 edge rising nth 1 dataset 0} {} {} \
              {dataset 0} {from {} to {}} {}]
    check {EVE4 the dialog's composed call: both limits blank is the bare call, From alone stops there, To alone keeps the empty place, and the two verbs with a dataset carry it} \
        [list [pcall calc::meas_compose ymax {rpn vt(a) from {} to {}}] \
              [pcall calc::meas_compose ymax {rpn vt(a) from 1m to {}}] \
              [pcall calc::meas_compose ymax {rpn vt(a) from {} to 3m}] \
              [pcall calc::meas_compose ymax {rpn vt(a) from 1m to 3m}] \
              [pcall calc::meas_compose integBetween {rpn vt(a) t0 1m t1 2m dataset 0}] \
              [pcall calc::meas_compose integBetween {rpn vt(a) t0 1m t1 {} dataset 0}]] \
        [list {ymax(vt(a))} {ymax(vt(a), 1m)} {ymax(vt(a), , 3m)} {ymax(vt(a), 1m, 3m)} \
              {integBetween(vt(a), 1m, 2m, 0)} {}]
    set ::calc::argval(from) {} ; set ::calc::argval(to) {}
    set blank [pcall calc::arg_trouble [calc::fn_argspec ymax]]
    set ::calc::argval(from) soon
    set word [pcall calc::arg_trouble [calc::fn_argspec ymax]]
    array unset ::calc::argval
    set ::calc::argval(lo) 0 ; set ::calc::argval(hi) 1 ; set ::calc::argval(pctlo) {}
    set ::calc::argval(pcthi) 90 ; set ::calc::argval(nth) 1 ; set ::calc::argval(dataset) 0
    set fill [pcall calc::arg_trouble [calc::fn_argspec riseTime]]
    check {EVE5 in the dialog a window limit may be left blank and a word in it is refused; the CONTROL is an optional field that HAS a default, which is still filled with it (riseTime's low threshold, 10) and not left blank} \
        [list $blank $word $fill [expr {[info exists ::calc::argval(pctlo)] ? $::calc::argval(pctlo) : {UNSET}}]] \
        [list {} [list [calc::arg_msg real {From (X)} soon]] {} 10]
    array unset ::calc::argval
    check {EVE6 a blank where the spec gives a default or requires a value is still refused in a typed call: an empty dataset, an empty required limit} \
        [list [msg {integBetween(vt(ramp), 1m, 2m, )}] \
              [expr {[msg {integBetween(vt(ramp), , 2m)}] eq [calc::meas_msg fields integBetween [calc::arg_msg real {From (X)} {}]]}]] \
        [list {integBetween: Dataset must be a whole number ().} 1]
}

# =============================================================================
# EVZ -- nothing is left behind
# =============================================================================
group EVZ {
    check {EVZ the registry is empty after every band, the depth count is zero, and no band was abandoned} \
        [list [ev_info] $::calc::nest_depth $::abortnames] {{} 0 {}}
}

catch {test_scratch_drop $scratch}
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
