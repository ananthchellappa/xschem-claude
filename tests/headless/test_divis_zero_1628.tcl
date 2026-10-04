# test_divis_zero_1628.tcl — x/0 in the RPN engine must HOLD the previous output
# of THIS pass, and where there is no previous point it must answer 0.  Nothing
# may be read from before the destination window.  Issue 1628.
#
# Spec   doc/claude/specs/calculator.md §3 (the RPN contract), §3.1 (rejection),
#        landmine L2 (the shared scratch column)
# Issue  doc/claude/issues/1628-divis-by-zero-reads-before-the-destination-window.md
# Twin   doc/claude/issues/0325-del-with-a-negative-delay-reads-past-the-end-of-the-window.md
#        and tests/headless/test_del_negative_arg.tcl — the SAME defect class in
#        the SAME function, fixed once already; this file is built on its shape.
#
# THE BUG.  In plot_raw_custom_data() (src/save.c), `case DIVIS`:
#
#     if(stack2[stackptr2 - 1])                  { ordinary divide }
#     else if(stack2[stackptr2 - 2] == 0.0)      { 0/0 -> 0 }
#     else                                       { stack2[stackptr2 - 2] = y[p - 1]; }
#
# That `else` is NOT nonsense and was not deleted: it is a deliberate
# hold-the-previous-output heuristic, so a transient zero crossing in a divisor
# does not destroy a whole trace.  The defect was the INDEX.  `y` is the
# destination column base and the point loop is `for(p = first; p <= last; p++)`,
# so at `p == first` there is no previous point in this pass and `y[p - 1]` is
# the wrong element in two different ways:
#
#   (1) p == 0, which is what raw_add_vector() passes (first = 0): `y[-1]` is an
#       OUT-OF-BOUNDS READ one SPICE_DATA before the column.  Undefined
#       behaviour, and the user-visible consequence was a confident garbage
#       number — `1 0 /` through the Calculator's Evaluate answered
#       `= 8.068092e-321` with ok=1.  Measured three ways and it gave three
#       different values (8.068092e-321 through the Calculator, 4.0019317e-322
#       through `raw add`, 8.8210093e+252 under valgrind), which is why NO ROW
#       HERE ASSERTS A GARBAGE VALUE: every row asserts the DEFENSIBLE value.
#       valgrind, before the fix, on `v(a) 0 /` through `xschem raw add`:
#         Invalid read of size 8 at plot_raw_custom_data
#          Address 0x687ac38 is 8 bytes before a block of size 64 alloc'd
#            by my_realloc / read_raw_data_block
#       After: 0 errors.  Band DZ5.
#   (2) p == first > 0, which the graph door passes (`plot_raw_custom_data(
#       sweep_idx, ofs, ofs_end - 1, express, NULL)` — ofs is the offset of the
#       dataset the point lives in).  `y[first - 1]` is IN BOUNDS and so invisible
#       to valgrind, but it was never written by this pass: it is stale data from
#       whatever last used the shared scratch column.  That is landmine L2
#       arriving from INSIDE the engine.  Measured before the fix, on a
#       two-dataset raw whose divisor is zero at dataset 1's first point: the
#       marker answered **4** — dataset 0's last quotient — and then **400**
#       after the previous pass's expression was changed to `v(a) 100 * v(m) /`.
#       The same point, two "answers", neither of them about dataset 1.
#       Band DZ2.
#
# THE CONTRACT NOW.  `p > first` keeps `y[p - 1]`, which genuinely is the
# previous point THIS pass computed; `p == first` answers 0.  0 because it is
# the choice this very switch already makes for 0/0 two lines up, so it is the
# function's own convention rather than a new one, and it is the minimum
# behavioural change.  A rejection (`return -1`) was considered and rejected: it
# would turn a cosmetic first-point glitch into a vanished trace for every
# existing graph that currently survives a transient zero divisor.
#
# BANDS.  DZ0–DZ4 and DZ6 run in this process.  DZ2's premise leg and DZ5 drive
# tests/headless/divis_zero_child.tcl — a HELPER, deliberately not named
# test_*.tcl — as a separate process, because neither obligation can be met from
# inside: the caller's `first` is only visible in a `-d 1` line, and "must not
# read out of bounds" needs valgrind around a whole process.  DZ5 is conditional
# on valgrind being installed; missing, and the leg is not run.  A missing leg is
# NEVER reported with a self-skip banner — full_audit.sh would score the whole
# file SKIP and discard every check that did run.
#
# ⚠ NO DISPLAY IS NEEDED, including by DZ2.  The graph door is reached through
# `xschem graph_marker add_at` -> graph_marker_create_at -> graph_marker_sample,
# which evaluates the expression and returns the sample through
# `xschem graph_marker list`; none of that touches X.  That is what lets the
# first > 0 half of this defect be fenced on the `--nogui` arm, where issue
# 0325's equivalent (DN12) needed a DISPLAY.
#
# Runs headless.  From the repo ROOT:
#   tests/headless/run_suites.sh --nogui test_divis_zero_1628
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_divis_zero_1628.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
# ⚠ A ROW MUST FAIL, NOT THROW (issue 1616): a row that raises on the broken
# tree hits the file-scope catch below, prints one UNEXPECTED ERROR and aborts
# every remaining check.  Everything that can raise goes through pcall.
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
proc ::bgerror {msg} { puts "BGERROR: $msg"; incr ::fail }

if {[catch {

set tmp [test_scratch diviszero]
set here [file dirname [info script]]
set child [file join $here divis_zero_child.tcl]

# ---------------------------------------------------------------------------
# fixtures.  dz_plot/dz_mkraw are the same generators the child uses, sourced
# from it rather than copied, so the two processes cannot drift apart.
#   v(a) = i + base   the numerator, never zero
#   v(z) = 0          a divisor that is zero at EVERY point
#   v(m) = 2, 0 at the point named   a divisor that goes to zero THERE
# ---------------------------------------------------------------------------
set ::env(DZ_DIR) $tmp
set ::env(DZ_MODE) none
# the child's generators only; its body is guarded by the mode dispatch, and
# `none` falls into the unknown-mode arm, so source only the proc definitions
set fp [open $child r] ; set childsrc [read $fp] ; close $fp
set gens [string range $childsrc 0 [expr {[string first "set dir \$::env(DZ_DIR)" $childsrc] - 1}]]
eval $gens
check_true "DZ0 the child's fixture generators were lifted, not copied" \
    [expr {[llength [info procs dz_plot]] == 1 && [llength [info procs dz_mkraw]] == 1
           && [llength [info procs dz_graph]] == 1}]

proc col {name np} {
    set out {}
    for {set i 0} {$i < $np} {incr i} { lappend out [format %g [xschem raw value $name $i]] }
    return $out
}

# ===========================================================================
# DZ0 — the premise.  The committed fixture is the artefact
# tests/headless/data/README.md describes; it is read and never written.
# ===========================================================================
set fixture [file join $here data calc_fixture.raw]
check_true "DZ0 the committed fixture exists" [file exists $fixture]
xschem raw clear
check "DZ0 the committed fixture loads as a bare tran read" [pcall xschem raw_read $fixture] 1
check "DZ0 the committed fixture has two datasets of 101 points" \
    [list [pcall xschem raw datasets] [pcall xschem raw points] [pcall xschem raw points 0]] \
    {2 202 101}

# ===========================================================================
# DZ1 — DEFECT (1): p == first == 0, through `xschem raw add`, which hardcodes
# first = 0.  Every row asserts 0, never a measured garbage value.
# ===========================================================================
# `1 0 /` is what the Calculator's Evaluate sends for the expression a user
# types as 1/0 — the report that opened issue 1628.
check "DZ1a a literal x/0 answers 0 at the first point, not a number from before the column" \
    [list [pcall xschem raw add dz_lit {1 0 /}] [pcall xschem raw value dz_lit 0]] {1 0}
check "DZ1b ...and at every one of the fixture's 202 points" \
    [lsort -unique [col dz_lit 202]] {0}
# a VECTOR numerator, which is the shape that reaches the graph.  ⚠ IT MUST BE
# NON-ZERO AT THE FIRST POINT or the defect is unreachable: a zero numerator
# takes the 0/0 arm two lines up and never reaches the hold arm at all.
# v(dcmid) is the fixture's dc divider -- 3 V at every sample of both transient
# datasets (tests/headless/data/README.md), so point 0 is 3/0, not 0/0.
# v(sq) and v(ramp), the obvious picks, are both exactly 0 at point 0 and were
# measured GREEN on the broken tree for that reason; DZ1f keeps one as a control.
check "DZ1c a nonzero vector numerator over a zero divisor answers 0 at the first point" \
    [list [pcall xschem raw add dz_vec {v(dcmid) 0 /}] [pcall xschem raw value dz_vec 0]] {1 0}
check "DZ1c ...and at every point" [lsort -unique [col dz_vec 202]] {0}
# re-using an EXISTING destination: raw_add_vector() does not re-zero one, so
# this is the arm where the engine's own write is the only thing in the column
check "DZ1d re-evaluating x/0 into an EXISTING column answers 0, not that column's old numbers" \
    [list [pcall xschem raw add dz_lit {v(dcmid) 0 /}] [lsort -unique [col dz_lit 202]]] {0 0}
# the CONTROL for the sentence above: a numerator that is 0 at the first point
# takes the 0/0 arm there, so this row is green on BOTH trees -- it is here so
# that a later reading of DZ1c cannot conclude any zero-divisor expression
# exercises the defect.
check "DZ1f a numerator that is zero AT the first point takes the 0/0 arm, not the hold arm" \
    [list [pcall xschem raw add dz_sq {v(sq) 0 /}] [lsort -unique [col dz_sq 202]]] {1 0}

# ⚠ THE ROW THAT ASSERTS NO GARBAGE VALUE WITHOUT NAMING ONE.  The out-of-bounds
# element is the heap bookkeeping immediately before the destination column, so
# its bit pattern is a function of the column's SIZE.  Two raws of different
# point counts therefore disagreed before the fix and must agree after, and the
# row can say so without quoting either number.
dz_mkraw $tmp/small.raw [list [dz_plot 8 1.0 3]]
dz_mkraw $tmp/large.raw [list [dz_plot 64 1.0 3]]
set firsts {}
foreach f {small large} {
    xschem raw clear
    pcall xschem raw_read $tmp/$f.raw tran
    pcall xschem raw add dz_sz {1 0 /}
    lappend firsts [pcall xschem raw value dz_sz 0]
}
check "DZ1e the first-point answer does not move with the destination column's size" \
    [lsort -unique $firsts] {0}

# ===========================================================================
# DZ2 — DEFECT (2): p == first > 0.  The graph door hands the evaluator the
# offset of the dataset the point lives in, so `y[first - 1]` is in bounds and
# belongs to the PREVIOUS pass.  Reached headless through
# `xschem graph_marker add_at` (graph_marker_sample re-evaluates the expression
# over that dataset's window and returns the sample).
# ===========================================================================
# the premise, measured in a child under -d 1 because the caller's `first` is
# visible in nothing else (the same obligation issue 0325's DN12 has)
proc run_child {cmdline logf} {
    if {[catch {exec sh -c "$cmdline >$logf 2>&1 ; echo RC=\$?"} out]} { return -1 }
    foreach l [split $out \n] { if {[string match RC=* $l]} { return [string range $l 3 end] } }
    return -1
}
set xbin [info nameofexecutable]
set ::env(DZ_MODE) win
run_child "timeout 120 $xbin --nogui --pipe -q --nolog -d 1 --script $child" $tmp/dz2.log
set called {}
set fp [open $tmp/dz2.log r] ; set log [read $fp] ; close $fp
foreach l [split $log \n] {
    if {[regexp {plot_raw_custom_data\(\): expr=.*, first=(-?\d+), last=} $l -> f]} {
        lappend called $f
    }
}
check_true "DZ2a premise: the graph-marker door calls the evaluator with a first > 0" \
    [expr {[llength $called] > 0 && [lindex [lsort -integer $called] 0] > 0}]

# now the behaviour, in this process.  dataset 1 starts at absolute point 8 and
# its divisor column is zero at exactly that point.
dz_mkraw $tmp/two.raw [list [dz_plot 8 1.0 3] [dz_plot 8 101.0 0]]
xschem raw clear
pcall xschem raw_read $tmp/two.raw tran
check "DZ2b premise: two datasets of 8 points" \
    [list [pcall xschem raw datasets] [pcall xschem raw points]] {2 16}
pcall dz_graph {v(a) v(m) /} $tmp/two.raw
proc mk {ds pt} {
    set n [pcall xschem graph_marker add_at 0 0 $ds $pt]
    if {[string match ERR:* $n] || $n eq ""} { return "NOMARKER:$n" }
    foreach m [pcall xschem graph_marker list] {
        if {[lindex $m 0] eq $n} { return [format %g [lindex $m 6]] }
    }
    return NOTLISTED
}
# evaluate dataset 0 FIRST, which fills the shared scratch column over y[0..7]
# with {0.5 1 1.5 1.5 2.5 3 3.5 4} — y[7] = 4 is what the broken index read
check "DZ2c premise: a marker inside dataset 0 reads that dataset's own quotient" [mk 0 3] 1.5
check "DZ2d the first point of a first>0 window answers 0, not the previous pass's last output" \
    [mk 1 8] 0
# ...and change what the previous pass leaves behind: before the fix this moved
# from 4 to 400, i.e. the "answer" for dataset 1's first point was a function of
# an unrelated expression
pcall xschem setprop rect 2 0 node {v(a) 100 * v(m) /}
check "DZ2e premise: the previous pass's last output really did change" [mk 0 3] 150
check "DZ2f ...and the first point of the first>0 window still answers 0" [mk 1 8] 0
# the ordinary path inside a first>0 window is untouched: dataset 1's point 9 is
# v(a)=102, v(m)=2 -> 102*100/2 = 5100
check "DZ2g an ordinary quotient inside a first>0 window is unchanged" [mk 1 9] 5100

# ===========================================================================
# DZ3 — THE HEURISTIC IS PRESERVED.  These rows are GREEN BEFORE AND AFTER: they
# are the behaviour under protection, and a fix that deleted the `else` arm or
# turned it into a rejection reddens them.  ⚠ Asserting the correct shape, not
# the absence of a wrong one (CLAUDE.md: a fence keyed to a symptom dies quietly
# when something else cures the symptom).
# ===========================================================================
xschem raw clear
pcall xschem raw_read $tmp/small.raw tran
# v(m) is 0 at point 3 only.  v(a) = 1..8.
#   p=0 1/2=0.5  p=1 2/2=1  p=2 3/2=1.5  p=3 HOLD 1.5  p=4 5/2=2.5 ...
check "DZ3a a divisor that goes to zero MID-window holds the previous output at that point" \
    [list [pcall xschem raw add dz_hold {v(a) v(m) /}] [col dz_hold 8]] \
    {1 {0.5 1 1.5 1.5 2.5 3 3.5 4}}
# the held value is THIS pass's previous output, so scaling the expression
# scales the held point too — which a hold that read a fixed column would not do
check "DZ3b ...and the held value is this pass's own previous output, so it scales with it" \
    [list [pcall xschem raw add dz_hold2 {v(a) 100 * v(m) /}] [col dz_hold2 8]] \
    {1 {50 100 150 150 250 300 350 400}}
# a divisor zero ONLY at the first point: first point 0, every later point the
# TRUE quotient — i.e. the fix did not break the ordinary path after it
dz_mkraw $tmp/firstzero.raw [list [dz_plot 8 1.0 0]]
xschem raw clear
pcall xschem raw_read $tmp/firstzero.raw tran
check "DZ3c a divisor zero only at the FIRST point: 0 there, the true quotient after" \
    [list [pcall xschem raw add dz_fz {v(a) v(m) /}] [col dz_fz 8]] \
    {1 {0 1 1.5 2 2.5 3 3.5 4}}

# ===========================================================================
# DZ4 — 0/0, and the ordinary path.  Controls: green before and after.
# ===========================================================================
xschem raw clear
pcall xschem raw_read $tmp/small.raw tran
check "DZ4a a literal 0/0 answers 0 at every point" \
    [list [pcall xschem raw add dz_00 {0 0 /}] [lsort -unique [col dz_00 8]]] {1 0}
check "DZ4b a zero numerator over an all-zero divisor column answers 0 at every point" \
    [list [pcall xschem raw add dz_zz {v(z) v(z) /}] [lsort -unique [col dz_zz 8]]] {1 0}
# 0/0 AT the mid-window zero, where the hold arm would otherwise have fired:
# v(z) is 0 everywhere and v(m) is 0 at point 3, so point 3 is 0/0 -> 0 and the
# rest is 0/2 -> 0.  The distinguishing form is a numerator that is zero ONLY
# there, so the hold arm's value and 0 are different numbers.
# v(a) is 4 at point 3, so `v(a) 4 -` is zero exactly where v(m) is: the hold
# arm would have answered -0.5 there and the 0/0 arm answers 0.
check "DZ4c 0/0 at a mid-window zero takes the 0/0 arm, not the hold arm" \
    [list [pcall xschem raw add dz_m0 {v(a) 4 - v(m) /}] [col dz_m0 8]] \
    {1 {-1.5 -1 -0.5 0 0.5 1 1.5 2}}
check "DZ4d ordinary division is unchanged" \
    [list [pcall xschem raw add dz_ok {v(a) v(a) /}] [lsort -unique [col dz_ok 8]]] {1 1}
check "DZ4e an unrelated operator is unchanged" \
    [list [pcall xschem raw add dz_mul {v(a) 10 *}] [col dz_mul 8]] \
    {1 {10 20 30 40 50 60 70 80}}
xschem raw clear

# ===========================================================================
# DS — ISSUE 1650.  `xschem raw add` must evaluate EACH DATASET as its own
# sweep, and the token scan's backward widening must never leave the dataset
# the caller's `first` belongs to.
#
# THE DEFECT.  raw_add_vector() called the evaluator ONCE for the whole file
# (`plot_raw_custom_data(sweep_idx, 0, raw->allpoints - 1, ...)`) while the
# graph door passes each dataset's own `(ofs, ofs_end - 1)`.  So every stateful
# opcode — integ() avg() deriv() deriv0() deriv2() deriv20() prev() cph()
# ravg() del() — carried its accumulator across the dataset boundary, where the
# sweep variable jumps BACKWARDS: on this fixture `time` is 0.009999999999999995
# at absolute point 100 and 0 at point 101, a step of -0.01.  integ() therefore
# added one NEGATIVE trapezoid at the seam.
#
# ⚠ THE OBVIOUS FIX IS A REGRESSION ON ITS OWN, AND TWO CREWS MEASURED IT
# INDEPENDENTLY BEFORE ANY CODE LANDED.  The per-dataset loop alone is NOT the
# fix.  plot_raw_custom_data()'s token scan WIDENS `first` backwards before
# evaluating — by one point for integ() and prev(), by TWO for each of the four
# deriv*() — and that scan is dataset-blind.  Handed `first = ofs` for dataset 1
# it pulls the window to `ofs - 1`, i.e. INTO dataset 0, and the point loop's
# `y[p] = stack2[0]` then WRITES there, destroying the answer dataset 0's own
# pass had just computed.  Measured: `v(sq) integ()` at dataset 0's last point
# is 0.0033999999999999989 today (CORRECT) and 0 under the loop alone.  So the
# second half — clamping the widened `first` back to the start of the dataset
# the caller's `first` lived in — is what makes the fix a fix.  Bands DS1/DS6
# are the three-way discrimination; see each row's own comment.
#
# ⚠ AND IT HAD TO BE WRITTEN, because NOTHING in this tree could see any
# version of it.  Over the whole registered population that reads a
# multi-dataset raw through this door, integ(), deriv(), deriv2(), prev(),
# ravg() and avg() were asserted ZERO times, on any dataset; del() only with a
# negative delay (issue 0325's rejection path) or a zero delay, and only on
# dataset 0.  54 suite runs on both arms scored the broken fix byte-identical
# to HEAD — every verdict and every check count.  A change that silently zeroes
# a correct integral was invisible to the entire gate.
#
# WHY THESE COLUMNS, MEASURED AND NOT CHOSEN.  Band DS0 derives it every run.
# The two tran datasets share an IDENTICAL time grid, and `v(div)` is the only
# column in the fixture whose datasets differ at all (dataset 1 is exactly half
# dataset 0); every other column is bit-identical between them.  That cuts both
# ways and both ways are fenced:
#   * a row on v(sq)/v(lp)/v(ramp) cannot tell "evaluated dataset 1" from
#     "copied dataset 0's answer", so DS3 drives v(div), where the two answers
#     differ by a factor of two;
#   * `v(div) integ()` happens to be RIGHT on HEAD at every point of dataset 1
#     — dataset 0's integral (0.025) and the seam trapezoid (-0.025) cancel to
#     the last bit — so v(div) cannot discriminate the fix, and DS1 drives
#     v(sq), where HEAD / loop-alone / loop+clamp read
#     0.0018000000000000008 / -0.0015999999999999968 / 0.0033999999999999989.
# Neither column does both jobs and no single one on this fixture does.  Band
# DS2 is the explicit distinctness leg with a control, so neither choice can go
# vacuous unnoticed if the fixture is ever regenerated (CLAUDE.md, issue 1643).
# ===========================================================================

# A relative comparison, and a failing row prints the relative error so the next
# reader does not have to re-run anything.  Same shape as test_calc_engine.tcl's.
proc ds_near {got exp tol} {
    if {![string is double -strict $got]} { return "NOTANUMBER:{$got}" }
    if {$exp == 0.0} {
        if {abs($got) <= $tol} { return ok }
        return "off:{$got} abs=[expr {abs($got)}]"
    }
    set r [expr {abs(($got - $exp) / double($exp))}]
    if {$r <= $tol} { return ok }
    return "off:{$got} rel=$r exp=$exp"
}
proc ds_near_list {got exp tol} {
    if {[llength $got] != [llength $exp]} { return "LENGTH:[llength $got] exp [llength $exp] got {$got}" }
    for {set i 0} {$i < [llength $exp]} {incr i} {
        set r [ds_near [lindex $got $i] [lindex $exp $i] $tol]
        if {$r ne "ok"} { return "elem$i $r (whole list {$got})" }
    }
    return ok
}
# relative spread of ONE PAIR -- the statistic a two-number row's discriminating
# power actually depends on
# ⚠ `double()` ON BOTH OPERANDS IS LOAD-BEARING, AND LEAVING IT OUT MADE THIS
# STATISTIC ANSWER ZERO ON A PERFECTLY DISTINCT PAIR.  Tcl's `/` is INTEGER
# division when both operands are integers, so the deriv() series {0 3 4 3}
# below -- whose adjacent pair really is a relative 0.25 apart -- reported
# `abs(3-4)/4` as 0 and DS10d read the series as NOT distinct.  A distinctness
# leg that can silently return 0 is worse than no leg at all, which is why
# DS2d exercises this proc on a known pair every run.
proc ds_spread {a b} {
    set a [expr {double($a)}] ; set b [expr {double($b)}]
    set m [expr {abs($a) > abs($b) ? abs($a) : abs($b)}]
    if {$m == 0.0} { return [expr {abs($a - $b)}] }
    return [expr {abs($a - $b) / $m}]
}
# ⚠ THE WORST ADJACENT PAIR, NEVER MAX-MINUS-MIN.  A series whose RANGE is a
# relative 2.4e-3 can have an adjacent pair 2.22e-11 apart, and a producer that
# repeats one element into the next passes a range test (CLAUDE.md).
proc ds_worst_adj {s} {
    set w ""
    for {set i 0} {$i < [llength $s] - 1} {incr i} {
        set d [ds_spread [lindex $s $i] [lindex $s [expr {$i + 1}]]]
        if {$w eq "" || $d < $w} { set w $d }
    }
    return $w
}
# The reference integral, computed in TCL over the fixture's own columns by the
# plain cumulative trapezoid rule -- no window machinery, no engine state.  Two
# arms: one dataset alone (the CORRECT answer) and the whole file as one sweep
# (the DEFECT's arithmetic, seam trapezoid included).
# ⚠ EVERY VALUE ROW READS THROUGH HERE, NOT THROUGH `xschem raw value`.
# `xschem raw value <n> <p>` prints through dtoa() at EIGHT significant digits:
# it answered 9.9378907 for 9.9378907186520919 and reddened DS6b by a relative
# 1.9e-9 on a CORRECT build, i.e. the accessor's own rounding was larger than
# this band's tolerance.  `xschem raw values <n> <ds>` prints %.16g, and its
# point index is dataset-relative, which is what these rows want anyway.
proc ds_at {col ds pt} { return [lindex [xschem raw values $col $ds] $pt] }
proc ds_trapz {col ds} {
    set y [xschem raw values $col $ds]
    set t [xschem raw values time $ds]
    set acc 0.0
    for {set i 1} {$i < [llength $y]} {incr i} {
        set acc [expr {$acc + ([lindex $t $i] - [lindex $t [expr {$i - 1}]]) *
                       ([lindex $y [expr {$i - 1}]] + [lindex $y $i]) * 0.5}]
    }
    return $acc
}

xschem raw clear
pcall xschem raw_read $fixture
set NP0 [pcall xschem raw points 0]
set NALL [pcall xschem raw points]

# ---------------------------------------------------------------------------
# DS0 — the fixture premises, DERIVED over every column the file has rather
# than asserted about a hand-picked few.  If a regenerated fixture broke any of
# these, the column choices DS1 and DS3 rest on would go vacuous silently.
# ---------------------------------------------------------------------------
check "DS0a the two tran datasets share an IDENTICAL time grid (so the seam steps backwards)" \
    [list [expr {[xschem raw values time 0] eq [xschem raw values time 1]}] \
          [expr {[lindex [xschem raw values time 1] 0] <
                 [lindex [xschem raw values time 0] end]}]] {1 1}
set ds_differ {} ; set ds_same {}
foreach v {time @m1[gm] i(@m1[id]) i(@rdc1[i]) i(@rtop[i]) v(dcmid) v(div) v(lp) v(ramp) v(sq)} {
    if {[xschem raw values $v 0] eq [xschem raw values $v 1]} {
        lappend ds_same $v
    } else { lappend ds_differ $v }
}
# ⚠ the expectation is built with `list`, not written as a brace literal: the
# canonical representation of an element containing `[` is itself braced, so a
# literal {i(@rtop[i]) v(div)} never compares equal to the list lappend built.
check "DS0b the columns whose two datasets DIFFER are exactly these -- derived, not listed" \
    $ds_differ [list {i(@rtop[i])} {v(div)}]
check "DS0c v(div)'s dataset 1 is exactly half its dataset 0, which is what DS3 and DS8a lean on" \
    [ds_near_list [xschem raw values v(div) 1] \
         [lmap e [xschem raw values v(div) 0] {expr {$e * 0.5}}] 1e-12] ok
check_true "DS0d v(sq) IS bit-identical between the datasets -- the hazard DS3 exists to cover" \
    [expr {[lsearch -exact $ds_same {v(sq)}] >= 0}]

# ---------------------------------------------------------------------------
# DS1 — THE THREE-WAY ROW.  RED on HEAD (0.0018000000000000008), RED on the
# per-dataset loop alone (-0.0015999999999999968), GREEN only with the widening
# clamped (0.0033999999999999989).  Separations measured against the answer
# this row demands: 0.471 and 1.47 relative, both ~4e8 times the 1e-9 tolerance
# below, so the row cannot pass on either broken build by rounding.
# ---------------------------------------------------------------------------
check "DS1a integ() at dataset 1's LAST point is dataset 1's OWN integral" \
    [list [pcall xschem raw add ds_i_sq {v(sq) integ()}] \
          [ds_near [ds_at ds_i_sq 1 end] [ds_trapz v(sq) 1] 1e-9]] {1 ok}
check "DS1b ...and that reference trapezoid is the hand-computed value, not whatever the engine said" \
    [ds_near [ds_trapz v(sq) 1] 0.0033999999999999989 1e-12] ok

# ---------------------------------------------------------------------------
# DS2 — THE DISTINCTNESS LEG, with a control.  DS1 compares two numbers; this
# measures, from the fixture itself every run, that the RIGHT answer and the
# DEFECT's answer are further apart than DS1's tolerance.  The control drives a
# column measured BLIND to the defect, so a `distinct` verdict here is a
# measurement of the fixture rather than a constant (CLAUDE.md, issue 1643).
# ---------------------------------------------------------------------------
proc ds_carried {col} {
    # the defect's arithmetic: ONE accumulator over the whole file, seam included
    set y [xschem raw values $col -1]
    set t [xschem raw values time -1]
    set acc 0.0
    for {set i 1} {$i < [llength $y]} {incr i} {
        set acc [expr {$acc + ([lindex $t $i] - [lindex $t [expr {$i - 1}]]) *
                       ([lindex $y [expr {$i - 1}]] + [lindex $y $i]) * 0.5}]
    }
    return $acc
}
set ds_sep_sq  [ds_spread [ds_trapz v(sq) 1]  [ds_carried v(sq)]]
set ds_sep_rmp [ds_spread [ds_trapz v(ramp) 1] [ds_carried v(ramp)]]
set ds_sep_div [ds_spread [ds_trapz v(div) 1] [ds_carried v(div)]]
check "DS2a DS1's pair is DISTINCT on this fixture: right vs carried differ by >1e-3 relative" \
    [list [expr {$ds_sep_sq > 1e-3}] [format %.3g $ds_sep_sq]] {1 0.471}
check "DS2b CONTROL v(ramp) is BLIND to the defect, so the leg measures the fixture" \
    [list [expr {$ds_sep_rmp < 1e-9}] [expr {$ds_sep_rmp == 0.0}]] {1 0}
check "DS2c CONTROL v(div) is blind too -- its seam trapezoid cancels dataset 0's integral" \
    [expr {$ds_sep_div < 1e-9}] 1
# the statistic's OWN non-vacuity: two integer operands a quarter apart, which
# is the case that answered 0 before ds_spread coerced to double
check "DS2d the distinctness statistic itself is not blind to an INTEGER pair" \
    [list [ds_spread 3 4] [ds_spread 0 3] [ds_worst_adj {0 3 4 3}]] {0.25 1.0 0.25}

# ---------------------------------------------------------------------------
# DS3 — THE ANTI-COPY ROWS.  v(div) is the one column whose datasets differ, so
# a "fix" that evaluated dataset 0 and copied its answer forward fails here
# while passing every v(sq) row.  DS3a is also the loop-alone regression: the
# unclamped widening writes dataset 1's reset into dataset 0's last point and
# this reads 0.
# ---------------------------------------------------------------------------
check "DS3a integ() at dataset 0's LAST point keeps the answer it already had" \
    [list [pcall xschem raw add ds_i_div {v(div) integ()}] \
          [ds_near [ds_at ds_i_div 0 end] [ds_trapz v(div) 0] 1e-9]] {1 ok}
check "DS3b ...and dataset 1's LAST point is dataset 1's own integral, not dataset 0's" \
    [ds_near [ds_at ds_i_div 1 end] [ds_trapz v(div) 1] 1e-9] ok
check "DS3c the two answers DS3a/DS3b demand are a factor of two apart, so a copy fails" \
    [list [expr {[ds_spread [ds_trapz v(div) 0] [ds_trapz v(div) 1]] > 1e-3}] \
          [format %.3g [ds_spread [ds_trapz v(div) 0] [ds_trapz v(div) 1]]]] {1 0.5}

# ---------------------------------------------------------------------------
# DS4 — EVERY OTHER STATEFUL OPCODE, at a dataset's FIRST point, which is where
# `p == first` now fires once per dataset instead of once per file.  Each
# expected value is the opcode's own documented reset: 0 for the integrators
# and derivatives, the point's own value for prev()/avg().  These were asserted
# ZERO times before this band.
# ---------------------------------------------------------------------------
foreach {row expr_ col want tol} [list \
    DS4a {v(sq) deriv()}        ds_d_sq   0 1e-12 \
    DS4b {v(div) deriv()}       ds_d_div  0 1e-12 \
    DS4c {v(div) deriv2()}      ds_d2_div 0 1e-12 \
    DS4d {v(div) prev()}        ds_p_div  0 1e-12 \
    DS4e {v(div) avg()}         ds_a_div  0 1e-12 \
    DS4f {v(sq) 0.002 ravg()}   ds_r_sq   0 1e-12 \
    DS4h {v(div) deriv0()}      ds_d0_div 0 1e-12 \
    DS4i {v(div) deriv20()}     ds_d20div 0 1e-12 ] {
    check "$row {$expr_} resets at dataset 1's FIRST point instead of carrying across the seam" \
        [list [pcall xschem raw add $col $expr_] \
              [ds_near [ds_at $col 1 0] $want $tol]] {1 ok}
}
# the two-point warm-up of the 3-point derivative runs once per DATASET: at
# dataset 1's SECOND point deriv2() must give the two-point slope of dataset 1's
# own first interval.  v(div) rises 0.05 per 1e-4 s there, i.e. 250 V/s exactly;
# HEAD and the loop-alone build both read 252.5252525252526 (the 3-point formula
# reaching back over the seam), a relative 0.01 away -- 1e7 times this tolerance.
check "DS4g deriv2()'s two-point warm-up runs once per DATASET, not once per file" \
    [ds_near [ds_at ds_d2_div 1 1] 250.0 1e-9] ok

# ---------------------------------------------------------------------------
# DS5 — CONTROLS.  Green before and after: an interior point of dataset 1, far
# from both ends, is untouched by any of this.  A fix that per-dataset-ised the
# window but broke ordinary evaluation reddens here.  ⚠ Asserting the correct
# shape, not the absence of a wrong one.
# ---------------------------------------------------------------------------
set mid [expr {$NP0 + 50}]
check "DS5a an INTERIOR deriv() of dataset 1 is unchanged" \
    [ds_near [ds_at ds_d_div 1 50] 250.00000000014944 1e-9] ok
check "DS5b an INTERIOR deriv2() of dataset 1 is unchanged" \
    [ds_near [ds_at ds_d2_div 1 50] 250.00000000031375 1e-9] ok
check "DS5c an INTERIOR prev() of dataset 1 is unchanged" \
    [ds_near [ds_at ds_p_div 1 50] 1.224999999999985 1e-9] ok
# ⚠ avg() SELF-HEALS ON THIS FIXTURE BY ACCIDENT, and the issue says so: the
# divisor is a carried count, the two datasets share a time grid, and the two
# errors cancel.  Asserted as a control so that a fixture whose grids differed
# would redden here rather than quietly making an `avg` row meaningless.
check "DS5d avg() at dataset 1's last point is unchanged by this fix (the documented accident)" \
    [list [pcall xschem raw add ds_a_sq {v(sq) avg()}] \
          [ds_near [ds_at ds_a_sq 1 end] 0.33999999999999986 1e-9]] {1 ok}

# ---------------------------------------------------------------------------
# DS6 — DATASET 0 MUST KEEP THE ANSWER IT ALREADY HAD.  Every row here is GREEN
# on HEAD and RED on the per-dataset loop ALONE, which is the half of the
# three-way discrimination that a reader checking only "is dataset 1 right now"
# would miss.  The loop-alone values are in each row's comment.
# ---------------------------------------------------------------------------
check "DS6a integ() at dataset 0's last point (loop alone: 0)" \
    [ds_near [ds_at ds_i_sq 0 end] [ds_trapz v(sq) 0] 1e-9] ok
check "DS6b deriv2() at dataset 0's last point (loop alone: 17.000849879930215, rel 0.415 away)" \
    [list [pcall xschem raw add ds_d2_lp {v(lp) deriv2()}] \
          [ds_near [ds_at ds_d2_lp 0 end] 9.9378907186520919 1e-9]] {1 ok}
check "DS6c prev() at dataset 0's last point (loop alone: 5.0000000000000728, rel 0.01 away)" \
    [ds_near [ds_at ds_p_div 0 end] 4.9500000000000099 1e-9] ok
check "DS6d ravg() at dataset 0's last point is unmoved (ravg does not widen `first`)" \
    [ds_near [ds_at ds_r_sq 0 end] 0.49999999999999806 1e-9] ok

# ---------------------------------------------------------------------------
# DS7 — ravg() is cured by the LOOP alone: it never widens `first`, so the
# clamp is a no-op for it.  The datasets share a grid and v(sq) is identical in
# both, so dataset 1's windowed average must equal dataset 0's; HEAD read
# -0.30000000000000099 against 0.49999999999999806, a relative 1.6 apart.
# ---------------------------------------------------------------------------
check "DS7a ravg() at dataset 1's last point equals dataset 0's, as the identical grids require" \
    [ds_near [ds_at ds_r_sq 1 end] [ds_at ds_r_sq 0 end] 1e-12] ok
check "DS7b ...and that value is the hand-computed one" \
    [ds_near [ds_at ds_r_sq 1 end] 0.49999999999999806 1e-9] ok

# ---------------------------------------------------------------------------
# DS8 — del().  Its token-scan arm was ALREADY dataset-aware (it snaps `first`
# to the start of the dataset containing it), which is direct evidence the
# author knew about datasets and fixed only that opcode.  What was broken is
# being FED an already-decremented `first` by a preceding integ(): the snap then
# resolves to the PREVIOUS dataset and the window becomes the whole file.  That
# is DS9f.  Here: the value.
#
# ⚠ Expected WITHOUT reimplementing del()'s forward walk.  DS0c measured that
# dataset 1 of v(div) is exactly half dataset 0 and DS0a that the grids are
# identical; del() is linear in its value argument, so dataset 1's answer must
# be exactly half dataset 0's.  HEAD returned them EQUAL -- dataset 0's answer
# for both points.
# ---------------------------------------------------------------------------
check "DS8a a POSITIVE del() answers each dataset from its OWN samples" \
    [list [pcall xschem raw add ds_del {v(div) 0.003 del()}] \
          [ds_near [ds_at ds_del 1 end] [expr {0.5 * [ds_at ds_del 0 end]}] 1e-12]] {1 ok}
# ⚠ THE DISTINCTNESS LEG FOR DS8a HAS TO MEASURE THE INPUTS, NOT THE OUTPUTS.
# An earlier revision asserted that the two del() answers differ -- and that is
# red on the broken build for the WRONG reason, because the defect is precisely
# what makes them equal.  What makes DS8a a discriminating row is that dataset
# 0's own answer is far from zero, so the factor of two it demands is a
# relative separation of exactly 0.5.
check_true "DS8b ...and DS8a is not vacuous: dataset 0's own del() answer is far from zero" \
    [expr {abs([ds_at ds_del 0 end]) > 1e-6}]
# ISSUE 0325 STILL HOLDS, PER DATASET.  A constant negative delay is rejected at
# `p == first` before the first y[p] store, so the destination column is not
# touched -- and `first` is now every dataset's first point, so the guarantee
# has to hold on each of them.  The column was zeroed at creation, so untouched
# means all zeros across BOTH datasets.
check "DS8c a constant NEGATIVE del() is still rejected with the column untouched on BOTH datasets" \
    [list [pcall xschem raw add ds_delneg {v(div) -1 del()}] \
          [lsort -unique [col ds_delneg 202]]] {1 0}

# ---------------------------------------------------------------------------
# DS9 — THE EVALUATED WINDOW ITSELF, which is the most direct statement of the
# contract and is visible in nothing but plot_raw_custom_data()'s own dbg(1)
# line.  One child process per expression (see divis_zero_child.tcl's header).
# Three-way at the structural level:
#       expression                 HEAD        loop alone        loop+clamp
#   v(sq)                          {0 201}   {0 100} {101 201}  {0 100} {101 201}
#   v(sq) integ()                  {0 201}   {0 100} {100 201}  {0 100} {101 201}
#   v(sq) deriv()                  {0 201}   {0 100} { 99 201}  {0 100} {101 201}
#   v(sq) deriv2()                 {0 201}   {0 100} { 99 201}  {0 100} {101 201}
#   v(sq) prev()                   {0 201}   {0 100} {100 201}  {0 100} {101 201}
#   v(sq) integ() 0.003 del()      {0 201}   {0 100} {  0 201}  {0 100} {101 201}
# The last line is the compound the issue names: del()'s own dataset snap is fed
# integ()'s already-decremented `first` and snaps to the PREVIOUS dataset, so
# the loop is completely defeated for that expression.
# ---------------------------------------------------------------------------
set ds_wexprs [list {v(sq)} {v(sq) integ()} {v(sq) deriv()} {v(sq) deriv2()} \
                    {v(sq) prev()} {v(sq) integ() 0.003 del()}]
set ::env(DZ_MODE) dsw
foreach ds_ri {0 1 2 3 4 5} {
    set ::env(DZ_EXPR) $ds_ri
    run_child "timeout 120 $xbin --nogui --pipe -q --nolog -d 1 --script $child" $tmp/dsw$ds_ri.log
    set fp [open $tmp/dsw$ds_ri.log r] ; set wlog [read $fp] ; close $fp
    set wins {}
    foreach l [split $wlog \n] {
        if {[regexp {evaluated window: first=(-?\d+), last=(-?\d+)} $l -> a b]} {
            lappend wins [list $a $b]
        }
    }
    check "DS9[string index abcdef $ds_ri] {[lindex $ds_wexprs $ds_ri]} evaluates each dataset as its own window" \
        $wins {{0 100} {101 201}}
}
set ::env(DZ_MODE) none
xschem raw clear

# ---------------------------------------------------------------------------
# DS10 — THE MULTI-DATASET OPERATING POINT RAW, which is the regression the
# per-dataset loop CREATES and which nothing in the tree could have caught: a
# census of 1091 raw-read announcements across the test suite found ZERO
# multi-dataset OP reads, so this fixture had to be built.
#
# A parametric .op writes ONE single-point dataset per parameter value.  Per
# dataset, `first == last` in every one of them, so without the coalesce the
# pseudo-sweep this band measures is lost.  ⚠ No figure is quoted for that
# state: the rows below derive the CORRECT series from the generator's own
# lists, and `{0 0 0 0}` -- which an earlier draft of this comment claimed --
# is reachable only on an intermediate build carrying the clamp without the
# multi-OP exemption.  On the tree as it ships with the coalesce removed the
# series is {0 0 0 52.5}, because the exemption prevents the degeneration.
# The product's own intent is recorded at three LIVE sites in src/draw.c --
# graph_x_extent(), graph_fullyzoom() and draw_graph() all coalesce a multi-OP
# database into one sweep for the duration of the call -- and raw_add_vector()
# now does the same, so these numbers are exactly HEAD's.
#
# ⚠ The guard is the three live sites' predicate, NOT the `#if 0` block's: that
# dead block also required `sch_waves_loaded() != -1`, i.e. a raw attached to
# the current schematic, which none of the live sites ask for.  Keeping it would
# have made the Tcl door disagree with the graph door on a bare-read raw --
# the opposite of this fix's purpose, and the shape this band drives.
# ---------------------------------------------------------------------------
proc ds_mkop {path xs ys} {
    set b "Title: issue 1650 -- multi-dataset operating point\nDate: Thu Jan  1 00:00:00 2026\n"
    foreach x $xs y $ys {
        append b "Plotname: Operating Point\nFlags: real\n"
        append b "No. Variables: 2\nNo. Points: 1\nVariables:\n"
        append b "\t0\tsweep\tvoltage\n\t1\tv(out)\tvoltage\n"
        append b "Values:\n0\t$x\n\t$y\n\n"
    }
    set fp [open $path w] ; puts -nonewline $fp $b ; close $fp
}
#  the fixture's four points, named ONCE: the generator call and every
#  reference below read the same two lists, so a regenerated fixture cannot
#  leave a reference behind.
set ds_op_xs {1.0 2.0 4.0 7.0}
set ds_op_ys {2.0 5.0 13.0 22.0}
ds_mkop $tmp/multiop.raw $ds_op_xs $ds_op_ys
# The two reference series, computed in TCL over those lists by the plain rules
# -- cumulative trapezoid and first difference -- with the 0 at the first point
# that every stateful arm's `p == first` reset puts there.  DS10b/DS10c compare
# the engine against THESE, and the legs below compare these against the
# hand-computed numbers, so neither side is a literal nobody re-derives.
proc ds_cumtrapz {xs ys} {
    set out [list 0.0] ; set acc 0.0
    for {set i 1} {$i < [llength $xs]} {incr i} {
        set acc [expr {$acc + ([lindex $xs $i] - [lindex $xs [expr {$i - 1}]]) *
                       ([lindex $ys [expr {$i - 1}]] + [lindex $ys $i]) * 0.5}]
        lappend out $acc
    }
    return $out
}
proc ds_fdiff {xs ys} {
    set out [list 0.0]
    for {set i 1} {$i < [llength $xs]} {incr i} {
        lappend out [expr {([lindex $ys $i] - [lindex $ys [expr {$i - 1}]]) /
                           double([lindex $xs $i] - [lindex $xs [expr {$i - 1}]])}]
    }
    return $out
}
set ds_op_iref [ds_cumtrapz $ds_op_xs $ds_op_ys]
set ds_op_dref [ds_fdiff    $ds_op_xs $ds_op_ys]
xschem raw clear
check "DS10a premise: four single-point Operating Point datasets" \
    [list [pcall xschem raw_read $tmp/multiop.raw] [pcall xschem raw sim_type] \
          [pcall xschem raw datasets] [pcall xschem raw points] [pcall xschem raw points 0]] \
    {1 op 4 4 1}
# hand-computed cumulative trapezoid over the four points as one pseudo-sweep,
# sweep = 1,2,4,7 and v(out) = 2,5,13,22:
#   0 ; (2-1)(2+5)/2 = 3.5 ; +(4-2)(5+13)/2 = 21.5 ; +(7-4)(13+22)/2 = 74
# loop alone reads {0 0 0 52.5}; loop+clamp without this transform reads {0 0 0 0}.
check "DS10a2 the Tcl reference series agree with those hand-computed numbers" \
    [list [ds_near_list $ds_op_iref {0 3.5 21.5 74} 1e-12] \
          [ds_near_list $ds_op_dref {0 3 4 3} 1e-12]] {ok ok}
check "DS10b integ() over a multi-OP raw is the pseudo-sweep trapezoid, as it is today" \
    [list [pcall xschem raw add ds_op_i {v(out) integ()}] \
          [ds_near_list [pcall xschem raw values ds_op_i -1] $ds_op_iref 1e-12]] {1 ok}
# ⚠ THE COALESCE IS APPLIED AND RESTORED AROUND THE LOOP, AND NOTHING ELSE IN
# THIS FILE WOULD NOTICE THE RESTORE GOING MISSING.  `raw values <col> -1` reads
# the whole file and is byte-identical either way; only a DATASET-indexed read
# can tell.  Measured 2026-10-04 on a build with raw_add_vector()'s restore
# block deleted and nothing else changed: `raw datasets` answered 1 (not 4),
# `raw points 0` answered 4 (not 1), and `raw values ds_op_i 2` answered 0
# instead of dataset 2's own 21.5 -- i.e. the dataset table stayed clobbered for
# every later reader of that database.
check "DS10b2 the multi-OP coalesce is RESTORED after the add (restore dropped: 1/4/4)" \
    [list [pcall xschem raw datasets] [pcall xschem raw points] \
          [pcall xschem raw points 0]] {4 4 1}
check "DS10b3 ...so a DATASET-indexed read still reaches dataset 2's own value (dropped: 0)" \
    [ds_near [lindex [pcall xschem raw values ds_op_i 2] 0] [lindex $ds_op_iref 2] 1e-12] ok
# first differences of v(out) against sweep: 0 ; 3/1 ; 8/2 ; 9/3
check "DS10c deriv() over a multi-OP raw likewise" \
    [list [pcall xschem raw add ds_op_d {v(out) deriv()}] \
          [ds_near_list [pcall xschem raw values ds_op_d -1] $ds_op_dref 1e-12]] {1 ok}
check "DS10c2 ...and the dataset table survives that add too" \
    [list [pcall xschem raw datasets] [pcall xschem raw points 0] \
          [ds_near [lindex [pcall xschem raw values ds_op_d 2] 0] \
                   [lindex $ds_op_dref 2] 1e-12]] {4 1 ok}
# ⚠ THE DISTINCTNESS LEG FOR THESE TWO SERIES, and it is the WORST ADJACENT
# PAIR: a series with a healthy range can still have two adjacent elements
# inside the tolerance, and a producer repeating one into the next would pass.
check "DS10d both DS10 series are distinct at the ADJACENT pair, not merely in range" \
    [list [expr {[ds_worst_adj [pcall xschem raw values ds_op_i -1]] > 1e-3}] \
          [expr {[ds_worst_adj [pcall xschem raw values ds_op_d -1]] > 1e-3}] \
          [format %.3g [ds_worst_adj [pcall xschem raw values ds_op_i -1]]] \
          [format %.3g [ds_worst_adj [pcall xschem raw values ds_op_d -1]]]] {1 1 0.709 0.25}
xschem raw clear

# ---------------------------------------------------------------------------
# DS14 — ISSUE 1650's BLOCKING CELL: the multi-OP raw at the MARKER door.
#
# ⚠⚠ THE PER-DATASET LOOP PLUS THE CLAMP REGRESSED THIS AND THE GATE COULD NOT
# SEE IT.  DS10 drives a multi-OP raw through the **Tcl** door only; DS13 drives
# the **marker** door through the **tran** fixture only.  The fourth cell of
# that 2x2 -- a multi-OP raw at the marker door -- was covered by neither, which
# is the same shape of hole that made the per-dataset loop's own regression
# invisible, reproduced one level in.
#
# WHY IT BREAKS.  raw_add_vector() coalesces a multi-OP database into one
# pseudo-sweep for the duration of its loop, and so do graph_x_extent(),
# graph_fullyzoom() and draw_graph().  graph_marker_sample(), find_closest_wave()
# and wave_hilight_envelope() do NOT: they walk the REAL dataset table and pass
# `(ofs, ofs_end - 1)`.  On a parametric .op every dataset is ONE point, so those
# three call the evaluator with `first == last`, where on HEAD the backward
# widening of the token scan RESCUED them -- it reached into the neighbouring
# "datasets", which on this database are the neighbouring sweep points and
# exactly what the opcode wants.  The clamp removes precisely that, and every
# stateful opcode degenerates to its `p == first` reset.
#
# THE REPAIR is one condition at the head of raw_dataset_start(): on a
# multi-dataset single-point `op` database the whole file is treated as one
# dataset, so the clamp has nothing to clamp to.  It goes there, and not as a
# fourth copy of the coalesce, because raw_dataset_start() is the SINGLE place
# the clamp asks "where does this dataset begin" -- `grep -n raw_dataset_start`
# gives one definition and two call sites, asserted by DS12 -- so one condition
# covers the marker door, find_closest_wave(), wave_hilight_envelope() and
# anything added later.
#
# THE REFERENCE IS A CONTRACT, NOT A TABLE OF NUMBERS.  The product's own
# intent is that such a database IS an artificial dc sweep: read the same four
# points back as ONE dataset and read_dataset() even reports `sim_type dc`
# (DS14a).  So DS14b asserts the marker door answers the SAME series on both
# spellings of the same data, for every stateful opcode whose window fits.
# Measured 2026-10-04 on three builds: HEAD agrees, the loop+clamp build
# disagrees on all three stateful opcodes, the repaired build agrees again.
#
# ⚠ `add_at`'s point index is ABSOLUTE.  Dataset d of this file is absolute
# point d; a dataset-relative index returns no marker at all.
# ---------------------------------------------------------------------------
proc ds_mkone {path xs ys} {
    set b "Title: issue 1650 -- the same four points as ONE dataset\nDate: Thu Jan  1 00:00:00 2026\n"
    append b "Plotname: Operating Point\nFlags: real\n"
    append b "No. Variables: 2\nNo. Points: [llength $xs]\nVariables:\n"
    append b "\t0\tsweep\tvoltage\n\t1\tv(out)\tvoltage\n"
    append b "Values:\n"
    set i 0
    foreach x $xs y $ys { append b "$i\t$x\n\t$y\n\n" ; incr i }
    set fp [open $path w] ; puts -nonewline $fp $b ; close $fp
}
ds_mkone $tmp/oneop.raw $ds_op_xs $ds_op_ys
# A graph rect whose index is DERIVED from the engine rather than assumed: every
# `xschem rect` appends one, and a band that keeps configuring rect 0 while
# creating more leaves orphans whose `sweep` token is not the one it set.
proc ds_newgraph {expr_ {sweep_ {}}} {
    xschem set rectcolor 2
    xschem rect 0 0 800 400 -1 {flags=graph} 0
    set ri [expr {[xschem get rects 2] - 1}]
    foreach {t v} [list x1 -1e9 x2 1e9 y1 -1e9 y2 1e9 divx 5 divy 5 \
                        dataset -1] {
        xschem setprop rect 2 $ri $t $v
    }
    if {$sweep_ ne ""} { xschem setprop rect 2 $ri sweep $sweep_ }
    xschem setprop rect 2 $ri node $expr_
    return $ri
}
proc ds_mark_at {ri ds pt} {
    set n [pcall xschem graph_marker add_at $ri 0 $ds $pt]
    if {[string match ERR:* $n] || $n eq ""} { return "NOMARKER:$n" }
    foreach m [pcall xschem graph_marker list] {
        if {[lindex $m 0] eq $n} { return [lindex $m 6] }
    }
    return NOTLISTED
}
xschem raw clear
check "DS14a premise: the same four points as ONE dataset read back as an artificial dc sweep" \
    [list [pcall xschem raw_read $tmp/oneop.raw] [pcall xschem raw sim_type] \
          [pcall xschem raw datasets] [pcall xschem raw points 0]] {1 dc 1 4}
xschem raw clear
# ⚠ THE INTEG LEG IS NOT HERE, AND THAT IS A DECLARED PRE-EXISTING
# DISAGREEMENT, NOT AN OMISSION.  integ() widens `first` by ONE, so on the
# multi-OP spelling the marker evaluates a TWO-point window and answers one
# trapezoid, while on the one-dataset spelling it evaluates the whole dataset
# and answers the CUMULATIVE integral.  Measured on all three builds: multi-OP
# {0 3.5 18 52.5} against one-dataset {0 3.5 21.5 74}, identical on HEAD and on
# the repaired build.  So the marker door and the trace door disagree about
# integ() on a parametric .op, they disagreed before issue 1650 and they still
# do; it is fenced below as today's behaviour (DS14d) rather than quietly left
# out, and it is reported as an open product question.
set ds14_rows {}
foreach {ds14_row ds14_e} [list \
        DS14b {v(out) deriv()}   \
        DS14b {v(out) prev()}    \
        DS14b {v(out) deriv2()}  \
        DS14b {v(out) 2.0 del()} \
        DS14c {v(out) 1 *}       ] {
    xschem raw clear ; pcall xschem raw_read $tmp/multiop.raw
    set ds14_g [ds_newgraph $ds14_e]
    set ds14_mop {}
    foreach d {0 1 2 3} { lappend ds14_mop [ds_mark_at $ds14_g $d $d] }
    xschem raw clear ; pcall xschem raw_read $tmp/oneop.raw
    set ds14_g2 [ds_newgraph $ds14_e]
    set ds14_one {}
    foreach p {0 1 2 3} { lappend ds14_one [ds_mark_at $ds14_g2 0 $p] }
    xschem raw clear
    check "$ds14_row marker door: {$ds14_e} reads a multi-OP raw as the one pseudo-sweep it is" \
        [ds_near_list $ds14_mop $ds14_one 1e-12] ok
    # ⚠ THE DISCRIMINATION LEG, element by element: the broken build answers the
    # all-reset series, and for `prev()` the IDENTITY series, so the question a
    # reader needs answered is how many elements of the row's own comparison can
    # tell those apart.  Derived here from the series the row actually compares.
    set ds14_nz 0 ; set ds14_nid 0
    foreach ds14_v $ds14_one ds14_x $ds_op_ys {
        if {[ds_spread $ds14_v 0.0] > 1e-3} { incr ds14_nz }
        if {[ds_spread $ds14_v $ds14_x] > 1e-3} { incr ds14_nid }
    }
    lappend ds14_rows [list $ds14_e $ds14_nz $ds14_nid]
}
# deriv() {0 3 4 3}, prev() {2 2 5 13}, deriv2() {0 3 4.67 2.4}, del() with a
# 2.0 delay {2 5 5 13} and the control {2 5 13 22}.  Elements that differ from
# the all-reset series {0 0 0 0}: 3, 4, 3, 4 and 4 -- deriv() and deriv2() each
# have a genuine 0 at the first point, so three of four elements carry the
# discrimination there.  Elements that differ from the identity series
# {2 5 13 22}: 4, 3, 4, 2 and 0.  The control is BLIND by construction -- it
# reads v(out) itself, so its identity count is 0 -- which is what makes it a
# control and not a second copy of the same measurement.
# ⚠ EVERY PAIR HERE WAS MEASURED, NEVER PREDICTED.  Two earlier drafts of this
# row quoted counts reasoned out by hand and went RED ON CORRECT CODE; the
# del() pair was likewise read off a run rather than argued.
check "DS14b2 every stateful row has elements that separate it from BOTH broken answers" \
    $ds14_rows [list [list {v(out) deriv()} 3 4] [list {v(out) prev()} 4 3] \
                     [list {v(out) deriv2()} 3 4] [list {v(out) 2.0 del()} 4 2] \
                     [list {v(out) 1 *} 4 0]]
# today's marker-door integ(), with the TWO-point window reference derived from
# the fixture's own four points -- not the cumulative series DS10b uses
xschem raw clear ; pcall xschem raw_read $tmp/multiop.raw
set ds14_gi [ds_newgraph {v(out) integ()}]
set ds14_imop {}
foreach d {0 1 2 3} { lappend ds14_imop [ds_mark_at $ds14_gi $d $d] }
xschem raw clear
set ds14_iref {0.0}
for {set ds14_k 1} {$ds14_k < 4} {incr ds14_k} {
    lappend ds14_iref [expr {([lindex $ds_op_xs $ds14_k] - [lindex $ds_op_xs [expr {$ds14_k - 1}]]) *
                             ([lindex $ds_op_ys [expr {$ds14_k - 1}]] + [lindex $ds_op_ys $ds14_k]) * 0.5}]
}
check "DS14d marker door: integ() is the ONE-trapezoid value of its widened 2-point window" \
    [ds_near_list $ds14_imop $ds14_iref 1e-12] ok
check "DS14d2 ...and that is NOT the cumulative series the Tcl door gives, which is the open item" \
    [list [ds_near_list $ds14_iref {0 3.5 18 52.5} 1e-12] \
          [expr {[ds_near_list $ds14_iref $ds_op_iref 1e-12] eq "ok" ? 1 : 0}]] {ok 0}
# ⚠ THE WIDENING DS14d's REFERENCE DEPENDS ON -- one point for integ() -- is
# DERIVED from the token scan's own text by row DS12d, in the structural band
# below, because that is where the comment-stripped copy of src/save.c lives.
# A change to the widening table moves DS14d's window and reddens DS12d first.
xschem select_all ; xschem delete ; xschem unselect_all
xschem raw clear

# ---------------------------------------------------------------------------
# DS11 — cph(), the LAST stateful opcode, on a fixture built to discriminate it.
#
# ⚠ THE COMMITTED FIXTURE CANNOT SEE THIS ONE, and a row written on it would
# have been vacuous.  cph() unwraps with `ph - 360*floor((ph - prev)/360 + 0.5)`,
# so it is the IDENTITY unless the step from the previous point exceeds 180 --
# and every seam step in calc_fixture.raw is far smaller, which is why that
# fixture reads the same on the broken and the fixed build (checked: v(ramp)
# cph() is 10.00000000000015 at dataset 0's last point either way).  So the
# fixture is built here, with a seam step of 292.
#
# ds0 v(a) = 1..8, ds1 v(a) = 300..307, both on the same 8-point time grid.
# Hand-computed: through dataset 0 every step is 1, so cph() is the identity and
# `prev` reaches 8.  Carried across the seam, dataset 1's first point unwraps:
#   (300 - 8)/360 + 0.5 = 1.3111 -> floor 1 -> 300 - 360 = -60.
# Per dataset, `p == first` fires there and the answer is the point's own 300.
# A relative separation of 1.2, against this row's 1e-12.
# ---------------------------------------------------------------------------
dz_mkraw $tmp/cphseam.raw [list [dz_plot 8 1.0 3] [dz_plot 8 300.0 3]]
xschem raw clear
check "DS11a premise: two datasets of 8 points whose seam step exceeds 180" \
    [list [pcall xschem raw_read $tmp/cphseam.raw tran] [pcall xschem raw datasets] \
          [expr {[lindex [xschem raw values v(a) 1] 0] -
                 [lindex [xschem raw values v(a) 0] end] > 180}]] {1 2 1}
check "DS11b cph() restarts its unwrap anchor per DATASET (broken: -60)" \
    [list [pcall xschem raw add ds_cph {v(a) cph()}] \
          [ds_near [ds_at ds_cph 1 0] 300.0 1e-12]] {1 ok}
check "DS11c ...and the pair that row discriminates is 1.2 relative apart, not a rounding" \
    [list [expr {[ds_spread 300.0 -60.0] > 1e-3}] [format %.3g [ds_spread 300.0 -60.0]]] {1 1.2}
check "DS11d an INTERIOR cph() of dataset 1 is on dataset 1's own scale (broken: -56)" \
    [ds_near [ds_at ds_cph 1 4] 304.0 1e-12] ok
xschem raw clear

# ---------------------------------------------------------------------------
# DS15 — THE VISIBLE-RUN FAMILY, which is the other half of src/draw.c's eight
# evaluator call sites and which band DS13 cannot see.
#
# DS9 drives the four sites that pass a DATASET OFFSET as `first`.  The other
# four pass a VISIBLE-RUN scan variable: `calc_custom_data_yrange()` walks each
# dataset's points, finds the run that falls inside the graph's x window, and
# calls the evaluator with that run's own `(first, last)`.  That `first` is a
# MID-DATASET index, so it is the shape where the clamp must NOT fire -- and
# `xschem setprop rect <l> <n> fullyzoom` reaches it with no DISPLAY at all.
#
# ⚠ ONE ROW, BOTH DIRECTIONS OF THE CLAMP, measured 2026-10-04 on five builds:
#
#   leg                                  HEAD          loop+clamp   over-eager snap
#   {v(sq) integ()} x 0.005..0.01    {49 100}{150 201} same         {0 100}{101 201}
#   {v(sq) integ()} x 0..0.005       {0 50}{100 151}   {0 50}{101 151}  same as clamp
#   {v(div) 0.003 del()} 0.005..0.01 {0 100}{101 201}  same         same
#   {v(sq) integ()} x 0..0.01        {0 100}{100 201}  {0 100}{101 201} same as clamp
#
# So DS15a is RED on a clamp that snaps unconditionally to the dataset start
# (`first = raw_dataset_start(first_in)`, which is the plausible wrong
# implementation and gives `{0 100}{101 201}` where the widening should have
# been left alone), and DS15b/DS15d are RED on HEAD, where the widening crosses
# the boundary.  DS15c is RED only on a build with del()'s own dataset snap
# removed (`{50 100}{151 201}` measured) -- it is the one behavioural witness
# anywhere in the gate that that snap still exists.
#
# EVERY EXPECTATION IS DERIVED, from the fixture's own time column plus the
# widening table row DS12d derives from the engine's token scan.  Nothing here
# is a remembered number.
# ---------------------------------------------------------------------------
# the visible run of a dataset for an x window, by the same `xx >= start &&
# xx <= end` test calc_custom_data_yrange() applies, in ABSOLUTE point indices
proc ds_run {ds ofs lo hi} {
    set t [xschem raw values time $ds]
    set f -1 ; set l -1
    for {set i 0} {$i < [llength $t]} {incr i} {
        set x [lindex $t $i]
        if {$x >= $lo && $x <= $hi} { if {$f < 0} { set f $i } ; set l $i }
    }
    return [list [expr {$f + $ofs}] [expr {$l + $ofs}]]
}
xschem raw clear
pcall xschem raw_read $fixture
# W for integ() is the figure DS12d derives from the token scan; stated here so
# the two rows are visibly the same number
set ds15_w 1
set ds15_exp {}
foreach {ds15_lo ds15_hi ds15_kind} [list 0.005 0.01 integ  0 0.005 integ \
                                          0.005 0.01 del    0 0.01  integ] {
    set ds15_r0 [ds_run 0 0 $ds15_lo $ds15_hi]
    set ds15_r1 [ds_run 1 $NP0 $ds15_lo $ds15_hi]
    set ds15_one {}
    foreach {ds15_r ds15_start} [list $ds15_r0 0 $ds15_r1 $NP0] {
        set ds15_f [lindex $ds15_r 0]
        if {$ds15_kind eq "del"} {
            # del() snaps `first` to the start of the dataset containing it
            set ds15_f $ds15_start
        } else {
            for {set ds15_k 0} {$ds15_k < $ds15_w} {incr ds15_k} {
                if {$ds15_f > 0} { incr ds15_f -1 }
            }
            # ...and the clamp raises it back to that dataset's own start
            if {$ds15_f < $ds15_start} { set ds15_f $ds15_start }
        }
        lappend ds15_one [list $ds15_f [lindex $ds15_r 1]]
    }
    lappend ds15_exp $ds15_one
}
xschem raw clear
# non-vacuity: the derived expectations must not all be the same window, or the
# band would be measuring nothing about the x window at all.  THREE distinct
# pairs out of four, not four: the del() leg and the full-range integ() leg both
# land on `{0 100}{101 201}`, because del() snaps to the dataset start and the
# full-range run already BEGINS at the dataset start.  Measured, not assumed --
# an earlier cut of this row expected 4 and reddened on correct code.
check "DS15 the derived window pairs are three DISTINCT windows across the four legs" \
    [list [llength [lsort -unique $ds15_exp]] \
          [expr {[lindex $ds15_exp 0] ne [lindex $ds15_exp 1]}] \
          [expr {[lindex $ds15_exp 1] ne [lindex $ds15_exp 3]}]] {3 1 1}
# ...and they are the hand-read numbers, so neither side of DS15a-d is a literal
check "DS15 the derived windows are the ones read off the five builds by hand" \
    $ds15_exp {{{49 100} {150 201}} {{0 50} {101 151}} {{0 100} {101 201}} {{0 100} {101 201}}}

set ::env(DZ_MODE) gwin
set ds15_ys {}
foreach ds15_i {0 1 2 3} {
    set ::env(DZ_EXPR) $ds15_i
    set ds15_rc [run_child "timeout 120 $xbin --nogui --pipe -q --nolog -d 1 --script $child" \
                     $tmp/gwin$ds15_i.log]
    set fp [open $tmp/gwin$ds15_i.log r] ; set ds15_log [read $fp] ; close $fp
    set ds15_wins {} ; set ds15_y {}
    foreach l [split $ds15_log \n] {
        if {[regexp {evaluated window: first=(-?\d+), last=(-?\d+)} $l -> a b]} {
            lappend ds15_wins [list $a $b]
        }
        if {[regexp {^CHILD gwin y1=(\S+) y2=(\S+)} $l -> a b]} { set ds15_y [list $a $b] }
    }
    lappend ds15_ys $ds15_y
    check "DS15[string index abcd $ds15_i] the visible-run window stays inside its own dataset" \
        [list $ds15_rc $ds15_wins] [list 0 [lindex $ds15_exp $ds15_i]]
}
set ::env(DZ_MODE) none

# ---------------------------------------------------------------------------
# DS15e/DS15f — THE Y-AUTORANGE DOOR, on the full-range leg.
#
# graph_fullyzoom() evaluates each dataset's visible run and THEN scans
# raw->values[v][p] for the min and max.  On HEAD dataset 1's widened pass wrote
# a seam trapezoid into the shared scratch column at absolute point 100 --
# dataset 0's last point -- BEFORE that scan ran, so dataset 0's contribution to
# the autoscaled Y axis was corrupted.  Measured: `{v(sq) integ()}` over the
# whole x range gave `y1=-0.005 y2=0.0033` on HEAD and `y1=0 y2=0.0034` with the
# clamp.  THAT IS A SIGN CHANGE on the axis a user sees.
#
# ⚠ THE LITERALS ARE NOT ASSERTED AS EXTREMA.  graph_fullyzoom() writes
# floor_to_n_digits(min, 2) and ceil_to_n_digits(max, 2), so y1/y2 are a ROUNDED
# bracket, not the data range.  What is asserted is the bracket property against
# the reference computed in Tcl over the fixture's own columns -- y1 at or below
# the true minimum, y2 at or above the true maximum -- plus the sign, which is
# unambiguous and is the half HEAD fails.
xschem raw clear
pcall xschem raw_read $fixture
set ds15_dmin 0.0
set ds15_dmax [ds_trapz v(sq) 0]
check "DS15e the y-autorange reference is non-vacuous: its two ends are far apart" \
    [list [expr {[ds_spread $ds15_dmax $ds15_dmin] > 1e-3}] \
          [format %.3g $ds15_dmax]] {1 0.0034}
foreach {ds15_y1 ds15_y2} [lindex $ds15_ys 3] break
check "DS15f y1 is NOT negative and brackets the true minimum from below (HEAD: -0.005)" \
    [list [expr {$ds15_y1 >= 0.0}] [expr {$ds15_y1 <= $ds15_dmin + 1e-15}]] {1 1}
check "DS15g y2 brackets the true maximum from above and does not overshoot it (HEAD: 0.0033)" \
    [list [expr {$ds15_y2 >= $ds15_dmax}] [expr {$ds15_y2 <= $ds15_dmax * 1.05}]] {1 1}
# CONTROL: the del() leg's y range is BLIND to the clamp -- identical on HEAD,
# on the loop+clamp build and on the over-eager snap (0.5 / 3.6 measured on all
# three), and it moves only when del()'s own snap goes (1.2 / 4).  So this leg
# measures that the fixture's two legs are not the same measurement twice.
check "DS15h CONTROL the del() leg's y range is a DIFFERENT pair from the integ() leg's" \
    [expr {[lindex $ds15_ys 2] ne [lindex $ds15_ys 3]}] 1
xschem raw clear

# ===========================================================================
# DZ6 — the STRUCTURAL row, and it derives its own site list rather than
# carrying one.  A hand-kept list of sites is the same defect one level up
# (CLAUDE.md, row X1 of test_snprintf_fmt_1608.tcl): what this asserts is that
# every backward subscript of `y` SPELT `y[p-1]` — tolerating whitespace around
# the `p`, the `-` and the `1`, which is what the scan's own regexp accepts —
# sits on a line that also tests `p > first`.  A second site added later in that
# spelling reddens here.
#
# ⚠ ITS LIMIT, NAMED BECAUSE AN EARLIER REVISION OF THIS COMMENT SAID "HOWEVER
# SPELT" AND THAT CLAIMED MORE THAN THE METHOD DELIVERS.  One regexp is one
# spelling family.  These reach the same element and are NOT detected:
# `y[-1 + p]`, `*(y + p - 1)`, `y[q]` where `q` was assigned `p - 1` on an
# earlier line, and the subscript arriving through a `#define`.  That is
# CLAUDE.md's limit L9 exactly — rows named "every write to X" each defeated by
# one whitespace variant or a `#define` alias — so the name states the spelling
# rather than the coverage.  The behavioural bands are what actually fence the
# value; this row's job is narrower: to notice the OBVIOUS reintroduction.
# ===========================================================================
set sv [file join [file dirname $here] .. src save.c]
set sv [file normalize $sv]
check_true "DZ6 src/save.c is where the engine lives" [file exists $sv]
set fp [open $sv r] ; set svsrc [read $fp] ; close $fp

# ⚠ THE ROW MUST SCAN CODE, NOT PROSE.  The first cut of this row reddened on
# the FIXED tree because the fix's own explanatory comment contains the words
# `y[p - 1]` -- the comment became the row's counterexample, which is the trap
# CLAUDE.md records as "a comment must not quote a count a command produces over
# the tree's own text".  So comments and string literals are blanked first,
# newlines preserved so the reported line numbers stay the file's own.
proc strip_c {src} {
    set out {} ; set n [string length $src] ; set i 0
    set state code
    while {$i < $n} {
        set c [string index $src $i]
        set c2 [string range $src $i [expr {$i + 1}]]
        switch -- $state {
          code {
            if {$c2 eq "/*"} { set state comment ; append out "  " ; incr i 2 ; continue }
            if {$c2 eq "//"} { set state line    ; append out "  " ; incr i 2 ; continue }
            if {$c eq "\""}  { set state str     ; append out " "  ; incr i   ; continue }
            if {$c eq "'"}   { set state chr     ; append out " "  ; incr i   ; continue }
            append out $c
          }
          comment {
            if {$c2 eq "*/"} { set state code ; append out "  " ; incr i 2 ; continue }
            append out [expr {$c eq "\n" ? "\n" : " "}]
          }
          line {
            if {$c eq "\n"} { set state code ; append out "\n" ; incr i ; continue }
            append out " "
          }
          str {
            if {$c eq "\\"} { append out "  " ; incr i 2 ; continue }
            if {$c eq "\""} { set state code }
            append out [expr {$c eq "\n" ? "\n" : " "}]
          }
          chr {
            if {$c eq "\\"} { append out "  " ; incr i 2 ; continue }
            if {$c eq "'"}  { set state code }
            append out [expr {$c eq "\n" ? "\n" : " "}]
          }
        }
        incr i
    }
    return $out
}
set svcode [strip_c $svsrc]
proc count_sites {text} {
    set k 0
    foreach l [split $text \n] { if {[regexp {y\[\s*p\s*-\s*1\s*\]} $l]} { incr k } }
    return $k
}
# the stripper's own control rows, so it cannot pass by blanking everything:
# it must keep the same number of lines, it must still hold the DIVIS arm, and
# it must have removed at least the comment mentions the raw text carries.
check "DZ6 the comment stripper preserves the line count" \
    [expr {[llength [split $svcode \n]] == [llength [split $svsrc \n]]}] 1
check_true "DZ6 the stripper kept the code it is scanning (the DIVIS arm survives)" \
    [regexp {case DIVIS} $svcode]
check_true "DZ6 the stripper really removed prose (fewer y\[p - 1\] lines than the raw text)" \
    [expr {[count_sites $svcode] < [count_sites $svsrc]}]

set sites 0 ; set unguarded {}
set ln 0
foreach l [split $svcode \n] {
    incr ln
    if {[regexp {y\[\s*p\s*-\s*1\s*\]} $l]} {
        incr sites
        if {![regexp {p\s*>\s*first} $l]} { lappend unguarded $ln }
    }
}
check_true "DZ6 src/save.c has at least one y\[p - 1\] read to guard" [expr {$sites > 0}]
check "DZ6 every y\[p - 1\] read in src/save.c CODE is on a line that also tests p > first" \
    $unguarded {}

# ===========================================================================
# DS12 — ISSUE 1650's STRUCTURAL ROW.  Every `case` arm of
# plot_raw_custom_data() that tests `p == first` (or `p > first`) is an arm
# whose state is now reset ONCE PER DATASET instead of once per file, so every
# one of them had to be re-read against the per-dataset loop -- and a stateful
# arm added later needs the same treatment.  This derives the arm set from
# src/save.c's own text and asserts it against the set this file fences, so a
# new one reddens here instead of shipping unexamined.
#
# ⚠ A HAND-KEPT LIST OF ARMS WOULD BE THE SAME DEFECT ONE LEVEL UP (CLAUDE.md,
# row X1 of test_snprintf_fmt_1608.tcl).  The list below is the COVERAGE claim,
# which has to be written down somewhere; the POPULATION is derived.  Each name
# is followed by the band that drives it, in a comment, so a reader can check
# the claim rather than take it:
#     AVG      DS4e        DEL      DS8a/DS8b/DS8c      DERIV    DS4a/DS4b
#     CPH      DS11b/DS11d DERIV0   DS4h                DERIV2   DS4c/DS4g
#     DERIV20  DS4i        DIVIS    DZ1/DZ2/DZ3/DZ4     INTEG    DS1a/DS3/DS6a
#     PREV     DS4d/DS6c   RAVG     DS4f/DS7a/DS7b
# ===========================================================================
set ds_fnstart [string first "int plot_raw_custom_data(" $svcode]
check_true "DS12 plot_raw_custom_data() is found in the stripped source" [expr {$ds_fnstart >= 0}]
set ds_fnlines {}
foreach l [split [string range $svcode $ds_fnstart end] \n] {
    lappend ds_fnlines $l
    if {[llength $ds_fnlines] > 1 && [string index $l 0] eq "\}"} break
}
# non-vacuity: the extent really is a FUNCTION, not the whole file and not one line
check_true "DS12 the derived extent is a function body, not the file and not a line" \
    [expr {[llength $ds_fnlines] > 100 &&
           [llength $ds_fnlines] < [llength [split $svcode \n]] / 2}]
set ds_arms {} ; set ds_cur ""
foreach l $ds_fnlines {
    if {[regexp {^ *case ([A-Z0-9_]+):} $l -> ds_lab]} { set ds_cur $ds_lab }
    if {$ds_cur ne "" && [regexp {p *== *first|p *> *first} $l]} {
        if {[lsearch -exact $ds_arms $ds_cur] < 0} { lappend ds_arms $ds_cur }
    }
}
check "DS12 every opcode arm whose state resets at `first` is one this file drives" \
    [lsort $ds_arms] {AVG CPH DEL DERIV DERIV0 DERIV2 DERIV20 DIVIS INTEG PREV RAVG}
# the clamp and the lifted walk are the two sites part 2 added; a revert of
# either one is a silent return of the regression, so both are asserted present
# the clamp and the lifted walk are the two sites part 2 added.  Reverting
# either is a silent return of the regression -- the suite's value rows would
# catch the clamp, but nothing else would notice a SECOND hand-written copy of
# the dataset walk reappearing, which is the drift this asserts against.
set ds_defs  [regexp -all {static int raw_dataset_start\(int} $svcode]
set ds_calls [regexp -all {raw_dataset_start\(} $svcode]
check "DS12 the dataset walk has ONE definition and is CALLED from both sites" \
    [list $ds_defs [expr {$ds_calls - $ds_defs}]] {1 2}

# DS12d -- THE BACKWARD WIDENING TABLE, which band DS14d's reference depends on
# and which nothing else in the tree states.  Derived from the token scan rather
# than remembered: one `if(first > 0) first--;` in the
# `integ()` arm, two in each `deriv*()` arm, one in `prev()`.  A change there
# moves DS14d's window and reddens here first.
# ⚠ THIS ONE SCANS THE RAW SOURCE, NOT $svcode, AND THE REASON IS THE STRIPPER:
# strip_c blanks STRING LITERALS as well as comments, so in $svcode the arm reads
# `!strcmp(n,        )` and the token name -- the only thing that identifies the
# arm -- is gone.  The price of scanning raw text is that a comment carrying the
# same spelling would be counted, so the UNIQUENESS leg below asserts each
# pattern occurs exactly ONCE in the file; a second copy, in a comment or
# anywhere else, reddens rather than silently joining the population.
# ⚠ `split` SPLITS ON EVERY CHARACTER OF ITS SECOND ARGUMENT, not on the string
# -- the first cut of the uniqueness leg used it and reported 228250 occurrences
# of a pattern that appears once.  Count substrings explicitly.
proc ds_substr_count {hay needle} {
    set k 0 ; set at 0
    while {[set at [string first $needle $hay $at]] >= 0} {
        incr k ; incr at [string length $needle]
    }
    return $k
}
set ds14_widen {} ; set ds14_uniq {}
foreach ds14_tok {integ deriv deriv0 deriv2 deriv20 prev} {
    set ds14_pat "!strcmp(n, \"${ds14_tok}()\")"
    lappend ds14_uniq [list $ds14_tok [ds_substr_count $svsrc $ds14_pat]]
    set ds14_at [string first $ds14_pat $svsrc]
    if {$ds14_at < 0} { lappend ds14_widen [list $ds14_tok NOTFOUND] ; continue }
    # the arm runs to the next `!strcmp(n,` after it
    set ds14_rest [string range $svsrc [expr {$ds14_at + [string length $ds14_pat]}] end]
    set ds14_nxt [string first "!strcmp(n," $ds14_rest]
    if {$ds14_nxt < 0} { set ds14_nxt [string length $ds14_rest] }
    lappend ds14_widen [list $ds14_tok \
        [regexp -all {if\(first > 0\) first--;} [string range $ds14_rest 0 $ds14_nxt]]]
}
check "DS12d each opcode's token arm is spelt in exactly ONE place in src/save.c" \
    $ds14_uniq {{integ 1} {deriv 1} {deriv0 1} {deriv2 1} {deriv20 1} {prev 1}}
check "DS12d the backward widening per opcode, derived from the token scan itself" \
    $ds14_widen {{integ 1} {deriv 2} {deriv0 2} {deriv2 2} {deriv20 2} {prev 1}}

# ===========================================================================
# DS13 — THE GRAPH DOOR, which the clamp fixes as a side effect and which no
# test in this tree read on a multi-dataset raw.
#
# The clamp is in the SHARED engine, so it changes every one of draw.c's `ofs`
# call sites, not just `xschem raw add`.  Those sites have ALWAYS passed a
# dataset offset as `first`, so the backward widening has ALWAYS pulled the
# window into the previous dataset there -- i.e. this half of the defect was
# live on the shipped, pre-ASE-L graph surface and nothing measured it.
# Measured here through graph_marker_sample, the one graph door that needs no
# DISPLAY (`xschem graph_marker add_at` -> graph_marker_create_at ->
# graph_marker_sample re-evaluates the expression over that dataset's window
# and returns the sample in `graph_marker list`), which is what lets band DZ2
# fence the first > 0 half of issue 1628 on the --nogui arm too.
#
# Before the clamp, on this fixture:
#     v(sq) integ()  at dataset 1's first point  -0.0049999999999999975
#     v(sq) integ()  at dataset 1's last point   -0.0015999999999999968
#     v(sq) deriv()  at dataset 1's first point   100.00000000000006
#     v(lp) deriv2() at dataset 1's first point   183.49629954639826
#     v(ramp) prev() at dataset 1's first point    10.000000000000146
# ⚠ Note the second line is the SAME number the per-dataset loop WITHOUT the
# clamp produced at the Tcl door, which is the measurement that says the loop
# makes `raw add` issue exactly the call the graph door already issued.
#
# ⚠ Dataset 0's samples are asserted too, and they are UNCHANGED by all of
# this -- the rows that would catch a clamp firing when it should not.
# ===========================================================================
proc ds_graph {expr_} {
    xschem set rectcolor 2
    xschem rect 0 0 800 400 -1 {flags=graph} 0
    foreach {t v} [list x1 0 x2 0.01 y1 -1000 y2 1000 divx 5 divy 5 \
                        dataset -1 sim_type tran] {
        xschem setprop rect 2 0 $t $v
    }
    xschem setprop rect 2 0 node $expr_
}
# ⚠ `add_at`'s point index is ABSOLUTE, not dataset-relative (band DZ2 passes 8
# for the first point of dataset 1 of an 8-point-per-dataset raw).  Passing a
# dataset-relative index returns no marker at all, which reads like a product
# failure and is not.
proc ds_mark {ds pt} {
    set n [pcall xschem graph_marker add_at 0 0 $ds $pt]
    if {[string match ERR:* $n] || $n eq ""} { return "NOMARKER:$n" }
    foreach m [pcall xschem graph_marker list] {
        if {[lindex $m 0] eq $n} { return [lindex $m 6] }
    }
    return NOTLISTED
}
# ⚠⚠ DS13b USED TO DRIVE `{v(sq) deriv()}` AND TWO OF ITS THREE LEGS WERE
# VACUOUS.  v(sq) is flat at 1 over the last points of both datasets, so that
# row's ds1-last and ds0-last expectations were BOTH 0 -- identical on HEAD, on
# the loop-alone build and on the fixed one, and passed by any producer that
# answers 0 everywhere.  Only its ds1-first leg discriminated, 1 of 3.  It now
# drives `{v(div) deriv()}`, whose dataset 1 is exactly half its dataset 0
# (DS0c), so the two tail legs are 250 and 500: non-zero, a factor of two apart,
# and therefore also a fence against a cross-dataset copy.  Row DS13e counts
# the non-zero legs per row from the references themselves, so this cannot rot
# back without reddening.
#
# ⚠ AND THE EXPECTATIONS ARE NOW DERIVED FROM THE FILE'S OWN BYTES.  DS13c used
# to carry the literal 9.9378907186520919 with no derivation anywhere; it is now
# computed by ds_ref_deriv2, a Tcl transcription of the DERIV2 three-point arm,
# over the fixture's own time and v(lp) columns.  Agreement to %.16g was
# measured: 9.937890718652092 against the engine's 9.9378907186520919.
proc ds_ref_deriv1 {xs ys k} {
    return [expr {([lindex $ys $k] - [lindex $ys [expr {$k - 1}]]) /
                  double([lindex $xs $k] - [lindex $xs [expr {$k - 1}]])}]
}
proc ds_ref_deriv2 {xs ys k} {
    set a [expr {[lindex $xs [expr {$k - 2}]] - [lindex $xs $k]}]
    set c [expr {[lindex $xs [expr {$k - 1}]] - [lindex $xs $k]}]
    set b [expr {$a * $a / 2.0}] ; set d [expr {$c * $c / 2.0}]
    set bod [expr {$b / $d}]
    set fa [lindex $ys [expr {$k - 2}]]
    set fb [lindex $ys [expr {$k - 1}]]
    set fc [lindex $ys $k]
    return [expr {($fa - $bod * $fb - (1 - $bod) * $fc) / ($a - $c * $bod)}]
}
xschem raw clear
pcall xschem raw_read $fixture
set ds13_t0  [xschem raw values time 0]     ; set ds13_t1  [xschem raw values time 1]
set ds13_lp0 [xschem raw values v(lp) 0]    ; set ds13_lp1 [xschem raw values v(lp) 1]
set ds13_dv0 [xschem raw values v(div) 0]   ; set ds13_dv1 [xschem raw values v(div) 1]
set ds13_rp0 [xschem raw values v(ramp) 0]  ; set ds13_rp1 [xschem raw values v(ramp) 1]
set ds13_L   [expr {$NP0 - 1}]
set ds13_refs [list \
    DS13a {v(sq) integ()}  [ds_trapz v(sq) 1]                            [ds_trapz v(sq) 0] \
    DS13b {v(div) deriv()} [ds_ref_deriv1 $ds13_t1 $ds13_dv1 $ds13_L]    [ds_ref_deriv1 $ds13_t0 $ds13_dv0 $ds13_L] \
    DS13c {v(lp) deriv2()} [ds_ref_deriv2 $ds13_t1 $ds13_lp1 $ds13_L]    [ds_ref_deriv2 $ds13_t0 $ds13_lp0 $ds13_L] \
    DS13d {v(ramp) prev()} [lindex $ds13_rp1 [expr {$ds13_L - 1}]]       [lindex $ds13_rp0 [expr {$ds13_L - 1}]] ]
xschem raw clear
# the derived references ARE the numbers this band has always published, which
# is the cross-check that the Tcl transcriptions are the engine's own arithmetic
# rather than something near it
check "DS13 the derived references reproduce the published figures to 1e-12" \
    [list [ds_near [lindex $ds13_refs 2]  0.0033999999999999989 1e-12] \
          [ds_near [lindex $ds13_refs 6]  250.00000000031147    1e-12] \
          [ds_near [lindex $ds13_refs 7]  500.00000000063187    1e-12] \
          [ds_near [lindex $ds13_refs 10] 9.9378907186520919    1e-12] \
          [ds_near [lindex $ds13_refs 14] 9.9000000000000199    1e-12]] {ok ok ok ok ok}
# ⚠ HOW MANY OF EACH ROW'S THREE LEGS CAN CATCH AN ALL-ZERO PRODUCER, counted
# from the references rather than claimed.  The ds1-FIRST leg of every row is a
# genuine 0 (the per-dataset reset), so the ceiling is 2 -- and the old DS13b
# scored 0, which is the defect this row exists to prevent returning.
set ds13_nz {}
foreach {ds13_r ds13_x ds13_a ds13_b} $ds13_refs {
    set ds13_k 0
    foreach ds13_v [list $ds13_a $ds13_b] {
        if {[ds_spread $ds13_v 0.0] > 1e-3} { incr ds13_k }
    }
    lappend ds13_nz [list $ds13_r $ds13_k]
}
check "DS13e every row carries TWO legs an all-zero producer fails (old DS13b: 0)" \
    $ds13_nz {{DS13a 2} {DS13b 2} {DS13c 2} {DS13d 2}}
# ⚠ AND THE TWO TAIL LEGS OF DS13b MUST BE DISTINCT FROM EACH OTHER, or a
# producer copying dataset 0's answer into dataset 1 passes both.
check "DS13e2 DS13b's two tail legs are a factor of two apart, so a cross-dataset copy fails" \
    [list [expr {[ds_spread [lindex $ds13_refs 6] [lindex $ds13_refs 7]] > 1e-3}] \
          [format %.3g [ds_spread [lindex $ds13_refs 6] [lindex $ds13_refs 7]]]] {1 0.5}
foreach {ds_row ds_e ds_w1 ds_w0} $ds13_refs {
    xschem raw clear
    pcall xschem raw_read $fixture
    ds_graph $ds_e
    # dataset 1 is sampled FIRST on purpose: if its pass wrote outside its own
    # window, dataset 0's sample taken afterwards would show the damage
    set ds_g1f [ds_mark 1 $NP0]
    set ds_g1l [ds_mark 1 [expr {$NALL - 1}]]
    set ds_g0l [ds_mark 0 [expr {$NP0 - 1}]]
    check "$ds_row graph door: {$ds_e} at dataset 1's FIRST point resets per dataset" \
        [ds_near $ds_g1f 0 1e-12] ok
    check "$ds_row ...and at dataset 1's LAST point is dataset 1's own value" \
        [ds_near $ds_g1l $ds_w1 1e-9] ok
    check "$ds_row ...and dataset 0's last point is UNCHANGED by any of it" \
        [ds_near $ds_g0l $ds_w0 1e-9] ok
    xschem raw clear
}

# ===========================================================================
# DS16 — deriv0() AND deriv20() AT THE GRAPH DOOR, and the band exists because
# they were fenced at the Tcl door (DS4h/DS4i) and NOWHERE at the graph door.
#
# ⚠⚠ A ROW ON THE DEFAULT SWEEP WOULD HAVE BEEN VACUOUS, AND THAT IS MEASURED,
# NOT GUESSED.  deriv() divides by `x[]` = values[sweep_idx], the CALLER's sweep
# column; deriv0() always divides by `sweepx[]` = values[0], the file's own first
# column.  On this fixture column 0 IS `time`, so with no `sweep=` token on the
# rect the two are NUMERICALLY IDENTICAL -- measured 2026-10-04, both read
# 500.00000000063187 at dataset 0's last point and 250.00000000031594 at dataset
# 1's.  A row written that way would pass with deriv0() wired to deriv().
#
# So the rect is driven with `sweep=v(ramp)`, which is 1000*time on this
# fixture, and the pair separates by a factor of 1000: deriv() reads 0.5 / 0.25
# and deriv0() reads 500 / 250.  Same for deriv2()/deriv20() on v(lp):
# 0.00993789 against 9.93789.
#
# ⚠ The `sweep` token is set on a rect whose index is DERIVED (ds_newgraph), not
# on rect 0 -- a band that keeps configuring rect 0 while creating more rects
# leaves the token on the wrong one, which is how the first cut of this
# measurement came back with deriv() and deriv0() agreeing at 0.5.
# ===========================================================================
xschem raw clear
pcall xschem raw_read $fixture
set ds16_t  [xschem raw values time 0]
set ds16_r  [xschem raw values v(ramp) 0]
set ds16_dv [xschem raw values v(div) 0]
set ds16_lp [xschem raw values v(lp) 0]
set ds16_L  [expr {$NP0 - 1}]
# the four references, each computed over the column the opcode really divides by
set ds16_refs [list \
    {v(div) deriv()}   [ds_ref_deriv1 $ds16_r  $ds16_dv $ds16_L] \
    {v(div) deriv0()}  [ds_ref_deriv1 $ds16_t  $ds16_dv $ds16_L] \
    {v(lp) deriv2()}   [ds_ref_deriv2 $ds16_r  $ds16_lp $ds16_L] \
    {v(lp) deriv20()}  [ds_ref_deriv2 $ds16_t  $ds16_lp $ds16_L] ]
xschem raw clear
# NON-VACUITY FIRST: the deriv/deriv0 pair and the deriv2/deriv20 pair must be
# far apart under `sweep=v(ramp)`, or the band proves nothing about which column
# each opcode read.
check "DS16a the two pairs separate by ~1000, which is what makes this band non-vacuous" \
    [list [expr {[ds_spread [lindex $ds16_refs 1] [lindex $ds16_refs 3]] > 1e-3}] \
          [expr {[ds_spread [lindex $ds16_refs 5] [lindex $ds16_refs 7]] > 1e-3}] \
          [format %.4g [expr {[lindex $ds16_refs 3] / [lindex $ds16_refs 1]}]] \
          [format %.4g [expr {[lindex $ds16_refs 7] / [lindex $ds16_refs 5]}]]] {1 1 1000 1000}
foreach {ds16_e ds16_ref} $ds16_refs {
    xschem raw clear ; pcall xschem raw_read $fixture
    set ds16_g [ds_newgraph $ds16_e v(ramp)]
    set ds16_g1f [ds_mark_at $ds16_g 1 $NP0]
    set ds16_g0l [ds_mark_at $ds16_g 0 $ds16_L]
    xschem raw clear
    check "DS16b graph door, sweep=v(ramp): {$ds16_e} resets at dataset 1's FIRST point" \
        [ds_near $ds16_g1f 0 1e-12] ok
    check "DS16b ...and at dataset 0's last point divides by the column it is supposed to" \
        [ds_near $ds16_g0l $ds16_ref 1e-9] ok
}
# CONTROL, and it is the vacuity this band was written to avoid: with NO sweep
# token the rect's sweep_idx is 0, so deriv() and deriv0() MUST agree exactly.
# A tree where they disagree here has broken the default, and a tree where they
# disagree under `sweep=v(ramp)` is the one DS16b measures.
xschem raw clear ; pcall xschem raw_read $fixture
set ds16_ga [ds_newgraph {v(div) deriv()}]
set ds16_a [ds_mark_at $ds16_ga 0 $ds16_L]
set ds16_gb [ds_newgraph {v(div) deriv0()}]
set ds16_b [ds_mark_at $ds16_gb 0 $ds16_L]
xschem raw clear
check "DS16c CONTROL with no sweep token deriv() and deriv0() are the SAME number" \
    [list [ds_near $ds16_a $ds16_b 1e-15] \
          [ds_near $ds16_a [lindex $ds16_refs 3] 1e-9]] {ok ok}
xschem select_all ; xschem delete ; xschem unselect_all
xschem raw clear

# ===========================================================================
# DS17 — DATASET 1's SECOND POINT, where deriv2()/deriv20() are ALSO wrong on
# HEAD and which band DS13c cannot see: it samples only the first and the last.
#
# DERIV2 has a two-point warm-up: `p == first` answers 0 and `p == first + 1`
# answers the FIRST difference.  Per dataset that second point is dataset 1's
# own points 0 and 1, where v(lp) is 0 at both, so the answer is 0.  On HEAD the
# window had already been widened back across the seam, so absolute point 102
# fell in the THREE-point arm and answered 1.0083863074507149 -- measured.
#
# ⚠ THE DISCRIMINATION IS MEASURED HERE, not asserted: the leg computes what the
# three-point arm WOULD answer at that point over the file's absolute columns
# and checks it is far from 0.  A fixture regeneration that made the two agree
# would redden this leg instead of silently emptying the row.
# ===========================================================================
xschem raw clear
pcall xschem raw_read $fixture
set ds17_tall  [xschem raw values time -1]
set ds17_lpall [xschem raw values v(lp) -1]
set ds17_t1    [xschem raw values time 1]
set ds17_lp1   [xschem raw values v(lp) 1]
# the per-dataset answer: the warm-up first difference over dataset 1's own
# points 0 and 1
set ds17_ref [ds_ref_deriv1 $ds17_t1 $ds17_lp1 1]
# the HEAD-shaped answer: the three-point arm over absolute points 100, 101, 102
set ds17_bad [ds_ref_deriv2 $ds17_tall $ds17_lpall [expr {$NP0 + 1}]]
xschem raw clear
check "DS17a the two candidate answers for that point are FAR apart (0 vs ~1.008)" \
    [list [expr {[ds_spread $ds17_ref $ds17_bad] > 1e-3}] \
          [ds_near $ds17_ref 0 1e-12] \
          [ds_near $ds17_bad 1.0083863074507149 1e-9]] {1 ok ok}
foreach ds17_e {{v(lp) deriv2()} {v(lp) deriv20()}} {
    xschem raw clear ; pcall xschem raw_read $fixture
    set ds17_g [ds_newgraph $ds17_e]
    set ds17_g1s [ds_mark_at $ds17_g 1 [expr {$NP0 + 1}]]
    xschem raw clear
    check "DS17b graph door: {$ds17_e} at dataset 1's SECOND point is the warm-up difference" \
        [ds_near $ds17_g1s $ds17_ref 1e-12] ok
}
xschem select_all ; xschem delete ; xschem unselect_all
xschem raw clear

# ===========================================================================
# DS18 — idx() IS FILE-GLOBAL, AND NOTHING ASSERTED IT.
#
# ⚠ THIS ROW PINS TODAY'S BEHAVIOUR AND DOES NOT ENDORSE IT.  Every other
# stateful opcode is now dataset-LOCAL: it resets at each dataset's first point.
# `idx()` pushes `(double)p`, the ABSOLUTE point index, so it is the one
# survivor of the old file-global family -- and the consequence is user-visible.
# Measured 2026-10-04, identical on HEAD, on the loop+clamp build and on the
# repaired one: on this two-dataset fixture `idx()` reads 0..100 on dataset 0 and
# 101..201 on dataset 1, so a per-run mask typed as `idx() 50 >` is 0 for
# dataset 0's first 51 points and 1 for ALL 101 points of dataset 1 -- it masks
# dataset 0 only.  Whether it SHOULD be dataset-local is a product question, not
# this commit's: reported, not changed.  What this row buys is that a future
# change to it is visible instead of silent.
# ===========================================================================
xschem raw clear
pcall xschem raw_read $fixture
check "DS18a idx() is the ABSOLUTE point index, so dataset 1 does not restart at 0" \
    [list [pcall xschem raw add ds_idx {idx()}] \
          [ds_near [ds_at ds_idx 0 0] 0 1e-15] \
          [ds_near [ds_at ds_idx 0 end] [expr {$NP0 - 1}] 1e-15] \
          [ds_near [ds_at ds_idx 1 0] $NP0 1e-15] \
          [ds_near [ds_at ds_idx 1 end] [expr {$NALL - 1}] 1e-15]] {1 ok ok ok ok}
# the consequence, counted rather than described: 50 of dataset 0's 101 points
# pass `idx() 50 >` and 101 of dataset 1's 101 do
proc ds_sum {col ds} {
    set a 0
    foreach v [xschem raw values $col $ds] { set a [expr {$a + $v}] }
    return $a
}
check "DS18b ...so a per-run `idx() 50 >` mask selects dataset 0 only" \
    [list [pcall xschem raw add ds_msk {idx() 50 >}] \
          [ds_sum ds_msk 0] [ds_sum ds_msk 1]] \
    [list 1 [expr {$NP0 - 51}] $NP0]
# CONTROL: a mask built from a DATASET-LOCAL quantity does the same thing on
# both datasets, which is what makes DS18b a statement about idx() and not about
# masks in general.  v(ramp) is the same column in both datasets (DS0b).
check "DS18c CONTROL a dataset-local mask selects the SAME count in both datasets" \
    [list [pcall xschem raw add ds_msk2 {v(ramp) 5.0 >}] \
          [expr {[ds_sum ds_msk2 0] == [ds_sum ds_msk2 1]}] \
          [expr {[ds_sum ds_msk2 0] > 0 && [ds_sum ds_msk2 0] < $NP0}]] {1 1 1}
xschem raw clear

# ===========================================================================
# DZ5 — the MEMORY property.  valgrind is the only witness in this tree and it
# has to wrap a whole process, so the work is done by divis_zero_child.tcl.
# Without this band the suite pins only the visible half of the contract: a
# "fix" that kept the out-of-bounds read and then overwrote its result would
# leave every value row above green.
# ===========================================================================
set have_vg [expr {[auto_execok valgrind] ne ""}]
if {!$have_vg} {
    puts "note: valgrind is not installed here; the DZ5 memory leg was not run"
} else {
    set ::env(DZ_MODE) mem
    set rc [run_child "timeout 300 valgrind -q --error-exitcode=42 $xbin --nogui\
                       --pipe -q --nolog --script $child" $tmp/dz5.log]
    check "DZ5 valgrind: the raw add and graph-marker doors are memory-clean" $rc 0
    if {$rc != 0} { puts "  --- dz5.log ---" ; catch {puts [exec tail -40 $tmp/dz5.log]} }
}

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

# ---------------------------------------------------------------------------
# ⚠ THE COMPLETION SENTINEL IS `OVERALL: ok`, AND IT IS WHAT REGISTRATION NEEDS.
# banner_complete in tests/banner_rule.tcl is the ONLY Tcl reader of the rule
# and the only one tests/run_regression.tcl sources:
#     ^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$
# It accepts NO `RESULT: ALL PASS` spelling, while run_suites.sh and
# full_audit.sh carry their own EREs which DO accept it.  So passing standalone
# is no evidence a suite can be registered: that is how both sibling calculator
# suites gated nothing for a month (issue 1626), and how all fourteen
# test_wave_sigbrowser* suites were structurally unregisterable (issue 1615).
#
# ⚠ `RESULT:` IS LAST, AND THERE IS EXACTLY ONE OF IT.  summarize_all publishes
# a case's last `^RESULT:` line into the verdict; a SECOND one silently becomes
# the published check count with nothing reddening (issue 1627, OPEN).  This
# file has ONE exit path on purpose — there is no no-X gate, because nothing
# here needs a display.
#
# ⚠ ONLY THE SUCCESS PATH CLAIMS COMPLETION.
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
