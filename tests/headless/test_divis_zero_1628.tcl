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
