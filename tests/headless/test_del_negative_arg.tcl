# test_del_negative_arg.tcl — del() with a NEGATIVE delay must be rejected, not
# walked off the end of the window.  Issue 0325.
#
# THE BUG (confirmed under valgrind before the fix, receipt
# doc/claude/calculator_batch/receipts/12-del-negative-arg.md):
# in plot_raw_custom_data() (src/save.c:2381) the DEL arm searched forward with
#     while(stack1[i].prevp <= last && delta > tmp) { prevp++; delta = fabs(x[p] - x[prevp]); }
# and `delta` is a fabs(), so for a negative `tmp` the test is true at EVERY
# point: the walk ran to prevp == last + 1 and read x[last + 1], one element
# past the sweep column, and could then hand last + 1 to ravg_store(), which
# indexes an array my_calloc()ed with last + 1 doubles.  On top of that
# stack1[] is an uninitialised local and the only thing that seeded
# stack1[i].prevp was the `fabs(x[p] - x[first]) <= tmp` arm, which a negative
# tmp never takes — so the very first search started from a garbage index.
#     valgrind, before: "Invalid read of size 8 ... 0 bytes after a block of
#     size 64 alloc'd (read_raw_data_block)" plus 7 uninitialised-value
#     contexts, all inside plot_raw_custom_data.  After: none.
#
# THE REACHABLE PATH: no Calculator needed.  `node=` on a graph and
# `xschem raw add <name> <rpn>` both land in the same evaluator
# (src/draw.c:5432,5449,5653,6704,7142,8298,9171,9221 and src/save.c:1207).
# Spec doc/claude/specs/calculator.md §3.1/§3.2/§7.2.
#
# THE CONTRACT NOW: a negative (or NaN) delay rejects the WHOLE evaluation the
# way an unresolvable vector name does — plot_raw_custom_data() returns -1 and,
# because the argument is a constant and the rejection therefore happens at
# p == first (before the first y[p] store), the destination column is left
# exactly as it was.  A POSITIVE del() is byte-for-byte what it always was;
# DN2/DN10 pin its values so a "fix" that moved them would be caught.  And
# "left as it was" is only a safety property if the column has defined contents
# to begin with: for a vector `raw add` has just created, raw_add_vector() now
# zeroes it BEFORE evaluating (DN13), or the caller would be handed a
# registered, plottable vector made of uninitialised heap.
#
# BANDS.  DN1–DN10 and DN13 run in this process.  DN11 and DN12 drive
# tests/headless/del_negative_arg_child.tcl — a HELPER, deliberately not named
# test_*.tcl — as a separate process, because neither obligation can be met
# from inside:
#   DN11  "must not read out of bounds" is a MEMORY property; valgrind has to
#         wrap a whole process.  Both doors are driven: `xschem raw add` and a
#         graph `node=` redraw (the latter is what caught draw_graph_points()
#         loading values[-1] before its own idx == -1 guard).
#   DN12  del()'s backwards window widening is invisible from `raw add`, which
#         hardcodes first = 0; only the graph redraw passes a first > 0.
# Each is conditional on its tool/resource (valgrind, a DISPLAY): missing, and
# the leg is not run — 24 checks here, 21 with no DISPLAY, 19 with neither.
# A missing leg is NEVER reported with a self-skip banner: full_audit.sh would
# score the whole file SKIP and discard every check that did run.
#
# Runs headless (no DISPLAY needed for DN1–DN10/DN13).  From the repo ROOT:
#   tests/headless/run_suites.sh test_del_negative_arg          # all 24
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_del_negative_arg.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
proc ::bgerror {msg} { puts "BGERROR: $msg"; incr ::fail }

if {[catch {

set tmp [test_scratch delneg]

# ---------------------------------------------------------------------------
# fixture: 8-point transient raw, time = 0..7 ns, v(a) = 0..7, and three extra
# columns used as non-constant del() arguments.
#   v(dly)  = +2.6 ns at every point            (a legal delay, from a VECTOR)
#   v(mix)  = +2.6 ns for p < 4, then -1 ns     (goes negative MID-WAVE)
#   v(neg)  = -2.6 ns at every point            (illegal from the first point)
# read_dataset takes Plotname then the ascii Values: block (src/save.c:622,406).
# 2.6 ns, NOT 2 ns: the ascii reader keeps the sweep column to full double
# precision but rounds the other columns to about seven digits (measured:
# `2e-09` comes back as 1.9999999e-09), so a delay sitting exactly on a sample
# spacing makes the `fabs(x[p] - x[first]) <= tmp` test decide on rounding
# noise and the literal and the vector-valued form of the SAME delay disagree.
# 2.6 ns is 0.4 ns clear of the nearest sample either way.
# ---------------------------------------------------------------------------
set np 8
set body "Title: del negative arg\nDate: Thu Jan  1 00:00:00 2026\n"
append body "Plotname: Transient Analysis\nFlags: real\n"
append body "No. Variables: 5\nNo. Points: $np\nVariables:\n"
append body "\t0\ttime\ttime\n\t1\tv(a)\tvoltage\n\t2\tv(dly)\tvoltage\n"
append body "\t3\tv(mix)\tvoltage\n\t4\tv(neg)\tvoltage\n"
append body "Values:\n"
for {set i 0} {$i < $np} {incr i} {
    append body "$i\t[expr {$i * 1e-9}]\n\t[expr {double($i)}]\n"
    append body "\t2.6e-09\n\t[expr {$i < 4 ? 2.6e-09 : -1e-09}]\n\t-2.6e-09\n\n"
}
set fp [open $tmp/del.raw w] ; puts -nonewline $fp $body ; close $fp

# read a whole column back as a list, formatted so exact comparison is safe
proc col {name} {
    global np
    set out {}
    for {set i 0} {$i < $np} {incr i} { lappend out [format %g [xschem raw value $name $i]] }
    return $out
}

xschem raw clear
check "DN1 fixture loads"        [pcall xschem raw_read $tmp/del.raw tran] 1
check "DN1 fixture points/vars"  [list [pcall xschem raw points] [pcall xschem raw vars]] {8 5}

# ---------------------------------------------------------------------------
# DN2 — the CONTROL.  A positive del() is the behaviour under protection: these
# eight numbers are the pre-fix output of `v(a) 2.6e-09 del()`, measured on the
# unmodified binary, and nothing in issue 0325 may move them.
# ---------------------------------------------------------------------------
check "DN2 positive del() created a vector"  [pcall xschem raw add k {v(a) 2.6e-09 del()}] 1
set positive [col k]
# a 2.6 ns delay on a 1 ns grid: the sample nearest t - 2.6 ns, i.e. three
# points back from p = 3 on, and clamped to the window start before that.
check "DN2 positive del() values are unchanged by the fix" $positive {0 1 2 0 1 2 3 4}

# ---------------------------------------------------------------------------
# DN3-DN5 — the defect itself.  Re-evaluating into the EXISTING vector k (so
# `raw add` allocates nothing and the column has known contents) with a
# negative constant delay must leave every one of those eight values alone.
# Before the fix this wrote {0 0 0 0 0 0 0 7} — the arr[] scratch read through
# a runaway index — after reading one element past the sweep column.
# ---------------------------------------------------------------------------
check "DN3 negative del() does not throw"  [pcall xschem raw add k {v(a) -2.6e-09 del()}] 0
check "DN3 negative del() left the column untouched" [col k] $positive

# a negative delay large enough to sweep the whole window, and a tiny one
check "DN4 -1p del() left the column untouched" \
    [list [pcall xschem raw add k {v(a) -1e-12 del()}] [col k]] [list 0 $positive]
check "DN4 -1 s del() left the column untouched" \
    [list [pcall xschem raw add k {v(a) -1 del()}] [col k]] [list 0 $positive]

# the argument does not have to be a literal: a VECTOR that is negative at the
# first point is rejected at the first point, same contract.
check "DN5 vector-valued negative delay left the column untouched" \
    [list [pcall xschem raw add k {v(a) v(neg) del()}] [col k]] [list 0 $positive]

# ---------------------------------------------------------------------------
# DN6 — a vector argument that only goes negative MID-WAVE.  The evaluation
# aborts AT that point, so the prefix already written stays written and the
# tail keeps whatever was in the column.  Seed the column with the identity
# (delay 0) first so prefix and tail are distinguishable from each other AND
# from the DN2 values.
# ---------------------------------------------------------------------------
check "DN6 zero delay is legal and is the identity" \
    [list [pcall xschem raw add k {v(a) 0 del()}] [col k]] [list 0 {0 1 2 3 4 5 6 7}]
check "DN6 mid-wave negative: prefix evaluated, tail untouched" \
    [list [pcall xschem raw add k {v(a) v(mix) del()}] [col k]] [list 0 {0 1 2 0 4 5 6 7}]

# ---------------------------------------------------------------------------
# DN7 — a legal vector-valued delay still evaluates fully (the guard rejects
# negatives, not vector arguments).
# ---------------------------------------------------------------------------
check "DN7 vector-valued positive delay still evaluates" \
    [list [pcall xschem raw add k {v(a) v(dly) del()}] [col k]] [list 0 $positive]

# ---------------------------------------------------------------------------
# DN8 — the rejection must not be a one-way door.  NOTE what these two legs do
# and do not pin: they show the NEXT expression still evaluates correctly.  The
# mechanism behind that — the guard's `ravg_store(0, …)` releasing the static
# scratch — is NOT visible from Tcl at this raw size (deleting that call leaves
# both legs green; measured).  What pins it is DN11's `mem` child, which
# rejects a del() after a ravg() on an 8-point raw and then runs a plain
# ravg() over a 64-point one: with the scratch still alive, arr[] rows sized
# for the old window are written past their end and valgrind fails the child.
# ---------------------------------------------------------------------------
pcall xschem raw add k {v(a) -2.6e-09 del()}
check "DN8 a positive del() after a rejected one is still correct" \
    [list [pcall xschem raw add k {v(a) 2.6e-09 del()}] [col k]] [list 0 $positive]
check "DN8 an unrelated expression after a rejected one is still correct" \
    [list [pcall xschem raw add s {v(a) 10 *}] [col s]] [list 1 {0 10 20 30 40 50 60 70}]

# ---------------------------------------------------------------------------
# DN9 — del() inside a bigger expression: the whole evaluation is rejected,
# not just the operator (§3.1 — one bad token poisons the expression).
# ---------------------------------------------------------------------------
check "DN9 a composed expression with a negative del() is rejected whole" \
    [list [pcall xschem raw add k {v(a) -2.6e-09 del() 100 *}] [col k]] [list 0 $positive]

# ---------------------------------------------------------------------------
# DN10 — the OTHER window-widening operators the negative guard must not have
# touched (§3.2: integ/deriv/prev/del each decrement `first`).
# ---------------------------------------------------------------------------
check "DN10 prev() is unchanged" \
    [list [pcall xschem raw add p1 {v(a) prev()}] [col p1]] [list 1 {0 0 1 2 3 4 5 6}]
# NOT an endorsement of these eight numbers — ravg() is the neighbouring arm
# this item was told not to touch, and it has the same runaway search (no
# fabs(), so a POSITIVE window is bounded by p and safe; a negative one is the
# sibling defect recorded in issue 0325 and deliberately left alone). The pin
# is here so that a later, wider fix cannot move ravg() without saying so.
check "DN10 ravg() over a positive window is unchanged" \
    [list [pcall xschem raw add r1 {v(a) 2e-09 ravg()}] [col r1]] \
    [list 1 {0 0.25 1 1.25 3 4 2.75 3.25}]
check "DN10 idx() is unchanged" \
    [list [pcall xschem raw add i1 {v(a) idx() +}] [col i1]] [list 1 {0 2 4 6 8 10 12 14}]

# ---------------------------------------------------------------------------
# DN13 — the destination column of a REJECTED expression must be DEFINED, not
# merely "not written".  `raw add` with a name that does not exist yet has
# already created the column by the time the evaluator refuses (the column it
# gets is the previous scratch column, never zeroed), so before issue 0325's
# raw_add_vector() change this handed the caller a registered, plottable,
# Tcl-readable vector made of uninitialised heap — and that is the door
# wviewer::add_trace takes (src/wave_viewer.tcl:3785 passes an auto-generated
# NEW name, and wviewer::validate_rpn accepts both `-2.6e-09` and `del()`).
# ---------------------------------------------------------------------------
check "DN13 a rejected expression into a NEW vector yields a zeroed column" \
    [list [pcall xschem raw add brandnew {v(a) -2.6e-09 del()}] [col brandnew]] \
    [list 1 {0 0 0 0 0 0 0 0}]
# the pre-existing §3.1 rejection (an unresolvable vector name) takes the same
# door and must land the same way
check "DN13 an unresolvable name into a NEW vector yields a zeroed column" \
    [list [pcall xschem raw add brandnew2 {v(nosuchnode) 1 +}] [col brandnew2]] \
    [list 1 {0 0 0 0 0 0 0 0}]

xschem raw clear

# ===========================================================================
# DN11 / DN12 — the two obligations that cannot be met inside this process.
#
# DN11: "must not read out of bounds" is a MEMORY property.  valgrind is the
# only witness in this tree and it has to wrap a whole process, so the work is
# done by tests/headless/del_negative_arg_child.tcl (a HELPER, deliberately not
# named test_*.tcl) under `valgrind -q --error-exitcode=42`.  Without this the
# suite pins only the visible half of the contract: restoring the entire
# original runaway walk BEHIND the guard, so the return value and the column
# still look right, left all the value checks green while valgrind went from 0
# errors to 80.
#
# DN12: del() widens the evaluation window backwards to the start of the
# dataset (spec §3.2).  `xschem raw add` hardcodes first = 0 (src/save.c), so
# the widening is invisible from that door; the ONLY caller that passes a
# first > 0 is the graph redraw (src/draw.c:9171, :9221).  DN12 drives a graph
# whose x1 clips the first samples off and reads both window lines out of the
# `-d 1` log.
#
# Both are conditional on a tool/resource: no valgrind, or no DISPLAY, and the
# leg is simply not run (and NOT reported with any of the self-skip banners —
# full_audit.sh would score the whole file SKIP and discard every check above).
# ===========================================================================
set xbin [info nameofexecutable]
set have_vg [expr {[auto_execok valgrind] ne ""}]
set have_disp [expr {[info exists ::env(DISPLAY)] && $::env(DISPLAY) ne ""}]
set ::env(DN_DIR) $tmp
set child [file join [file dirname [info script]] del_negative_arg_child.tcl]

# run a child, return its exit status (or -1 if it could not be started)
proc run_child {cmdline logf} {
    if {[catch {exec sh -c "$cmdline >$logf 2>&1 ; echo RC=\$?"} out]} {
        return -1
    }
    foreach l [split $out \n] { if {[string match RC=* $l]} { return [string range $l 3 end] } }
    return -1
}

if {!$have_vg} {
    puts "note: valgrind is not installed here; the DN11 memory legs were not run"
} else {
    set ::env(DN_MODE) mem
    set rc [run_child "timeout 120 valgrind -q --error-exitcode=42 $xbin --nogui\
                       --pipe -q --nolog --script $child" $tmp/dn11a.log]
    check "DN11 valgrind: the raw add door is memory-clean" $rc 0
    if {$rc != 0} { puts "  --- dn11a.log ---" ; catch {puts [exec tail -40 $tmp/dn11a.log]} }

    if {!$have_disp} {
        puts "note: no DISPLAY here; the DN11 graph-door leg was not run"
    } else {
        set ::env(DN_MODE) node
        set ::env(DN_EXPR) {v(a) -2.6e-09 del()}
        set ::env(DN_X1) 0
        set rc [run_child "timeout 180 valgrind -q --error-exitcode=42 $xbin\
                           --pipe -q --nolog --script $child" $tmp/dn11b.log]
        check "DN11 valgrind: the graph node= door is memory-clean" $rc 0
        if {$rc != 0} { puts "  --- dn11b.log ---" ; catch {puts [exec tail -40 $tmp/dn11b.log]} }
    }
}

if {!$have_disp} {
    puts "note: no DISPLAY here; the DN12 window-widening legs were not run"
} else {
    set ::env(DN_MODE) node
    set ::env(DN_EXPR) {v(a) 2.6e-09 del()}
    set ::env(DN_X1) 3.5e-09
    run_child "timeout 120 $xbin --pipe -q --nolog -d 1 --script $child" $tmp/dn12.log
    set called {} ; set evaluated {}
    set fp [open $tmp/dn12.log r] ; set log [read $fp] ; close $fp
    foreach l [split $log \n] {
        if {[regexp {plot_raw_custom_data\(\): expr=.*, first=(-?\d+), last=} $l -> f]} {
            lappend called $f
        } elseif {[regexp {plot_raw_custom_data\(\): evaluated window: first=(-?\d+),} $l -> f]} {
            lappend evaluated $f
        }
    }
    # the premise: the graph really did hand the evaluator a window that starts
    # part-way into the wave (x1 = 3.5 ns of an 8 ns sweep)
    check "DN12 the graph door passes a first > 0" \
        [expr {[llength $called] > 0 && [lindex [lsort -integer $called] 0] > 0}] 1
    # and del() pulled it back to the dataset start, so a delayed trace reads
    # samples from BEFORE the visible window instead of clamping to its edge
    check "DN12 del() widens the window back to the dataset start" \
        [lsort -unique $evaluated] {0}
}

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else            { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
