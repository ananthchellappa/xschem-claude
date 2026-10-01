# tests/headless/test_calc_engine.tcl — the Calculator's ENGINE STEP.
#
# Spec   doc/claude/specs/calculator.md §0 (the engine already exists), §3
#        (the RPN contract, L1-L4), §7.3 R402 (temp-vector discipline),
#        §9 R603-R605, §11.1 (this file's row in the test table), §11.2
#        (the fixture contract)
# Plan   doc/claude/calculator_batch/PLAN.md phase 3 steps 3.1 and 3.2
# Fixture tests/headless/data/calc_fixture.raw + .cir, contract and HAND
#        DERIVATIONS in tests/headless/data/README.md
#
# ⚠ EVERY EXPECTED NUMBER IN THIS FILE IS HAND-DERIVED FROM THE DECK, not read
# back out of the fixture.  The derivations are in that README and each band
# repeats the one-line arithmetic beside its rows, so a row that disagrees is
# either a product change or a fixture change and never "the number drifted".
#
# ⚠⚠ AND THE TOLERANCE IS SET BY THE ACCESSOR, NOT BY THE FIXTURE.  The README's
# per-quantity table (1e-11 … 1e-12 relative) is the agreement between the
# committed .raw and the hand value, measurable through `xschem raw values`,
# which prints "%.16g" (src/scheduler.c, the `values` arm).  Everything in this
# file reads ONE scalar through `xschem raw value`, which prints through
# `dtoa()` — `"%.8g"`, src/util.c — so EIGHT significant digits is the most any
# row here can see and a 1e-11 tolerance would be red on a correct fixture.
# Row CE0 reads that format string out of src/util.c so the two cannot drift.
#
# WHAT THIS FILE IS.  Phase 3's engine fence: `calc::rpn_of_text`,
# `calc::rpn_of_buffer`, `calc::tmpvec` and `calc::eval_rpn` — the part of
# Evaluate that has no window.  It is deliberately HEADLESS: none of those four
# touches a widget, which is why this suite can be an `hcases` entry and gate on
# the arm the Calculator's three other suites cannot run on.  The buffer, the
# keypad and the window belong to test_calc_buffer / test_calc_widgets /
# test_calc_skeleton; the L2 re-use race belongs to
# test_calc_scratch_reuse.tcl, which exists because that defect is invisible
# without it.
#
#   CE0  Fixture and accessor contract: the committed .raw is the one §11.2
#        describes (sim_type, datasets, points, the ten vector names, the
#        op-parameter naming asymmetry R207 is about), and dtoa's format is what
#        the tolerances above assume.
#   CE1  PLAN 3.1 — `calc::rpn_of_text` is the identity in RPN mode and is the
#        ONE site phase 8 replaces; `calc::rpn_of_buffer` is the window read in
#        front of it and answers {} with no window (R508).
#   CE2  R402 — `calc::tmpvec` mints `__calc_tmp<N>`: never empty, never the
#        same name twice, never a name the loaded raw already has.
#   CE3  §3 — the engine answers the HAND-COMPUTED numbers over the fixture, at
#        the last point of each dataset, through `calc::eval_rpn`.  Both
#        datasets, so §11.2's ">1 dataset" requirement is exercised.
#   CE4  R604 — cursor or last point, and WHICH is reported.  The cursor arm is
#        forced through `calc::eval_cursor_point`, because `raw->annot_p` is set
#        only by a graph's cursor-B publisher (backannotate, src/callback.c) and
#        NO headless route sets it: `xschem raw annot` answers `-1 0 -1` after
#        every spelling of `xschem raw read` (measured).  The forced point is an
#        ABSOLUTE index into all datasets, which is what annot_p is, and one row
#        proves that by putting the cursor on dataset 1's copy of the sample.
#   CE5  §3.1 / L1 — the two rejections: an unresolvable vector name, and more
#        than STACKMAX tokens.  Both yield a defined all-zero column, and
#        `xschem raw add` reports SUCCESS for both, which is why R607 (PLAN 3.4)
#        cannot be built on the engine's -1.
#   CE6  §3.1 / §3.2 — lexing and operators the Calculator's own keys produce:
#        the SPICE engineering suffix, a single-token expression (L3), the
#        three-operand `?`, and the ac dataset's complex accessors.
#   CE7  R402 — nothing is left behind, on the success path AND on a refusal.
#   CE8  R508 — with no window `calc::eval_click` is a silent no-op that records
#        nothing, both axes: it raises nothing and it writes no `calc::`
#        namespace variable.  It must not reach the engine either, because U6
#        says the Calculator never evaluates against this window's own raw.
#   CE9  R604 again, against the REAL `raw->annot_p` rather than a renamed-aside
#        `calc::eval_cursor_point`.  TWO headless routes publish that field and
#        only one of them is a cursor: `xschem annotate_at <t>` (the graph's own
#        cursor-B publisher, reached with a requested time) and
#        `xschem update_op` (the operating-point path, which sets annot_p = 0
#        for ANY op/dc database and is not a cursor at all).  The band drives
#        both for real.
#   CE10 R603/R607 — a NON-FINITE result is refused rather than reported.
#        `string is double -strict` accepts every IEEE non-finite spelling, so
#        the numeric check eval_rpn ends on does not vouch for what it passes on.
#   CE11 The engine's three-operand `?` arm must not print one line per
#        evaluated point.  The count is taken in-process through the `xschem
#        log` verb, with a control leg proving the capture works.
#   CE12 Two DECLARED limits, pinned as rows rather than left as prose: Evaluate
#        always reports dataset 0 because `calc::eval_click` passes no dataset
#        (the `Family` pick scope is PLAN phase 6), and the documented `%<n>`
#        dataset spelling reads as a silent zero from the Calculator.  Neither
#        is fixed; a later phase that closes either reds a row here.
#
# ⚠ BANDS CE9 AND CE11 WRITE A FIXTURE, so this file sources
# `tests/headless/scratch.tcl` for `test_scratch` rather than inventing a
# directory discipline of its own: it sweeps corpses, cleans up on the failing
# exit as well as the passing one, and keeps every write under
# `tests/headless/.scratch/`, which is gitignored.  CE9 needs a MULTI-POINT
# op/dc database (the first step and the last point must be different numbers,
# or no row can say which was read) and nothing committed in the tree is one.
# Everything else here still reads the committed fixture and writes nothing.
#
# Standalone from the repo ROOT, headless (NOT a bare `./src/xschem`, which
# inherits $DISPLAY):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_calc_engine.tcl
# or, gated and with a throwaway HOME, which is the armed spelling:
#   tests/headless/run_suites.sh --nogui test_calc_engine

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# ⚠ takes the predicate as a SCRIPT, not an evaluated boolean, so a command
# that does not exist on an unfixed tree fails the ROW instead of aborting the
# file.  CREW_BRIEF.md records issue 1616: one throwing row aborted a suite at
# 62 of 402 checks and hid 340 unrelated ones.
proc check_expr {name cond} {
    if {[catch {uplevel 1 [list expr $cond]} v]} { set v "ERR:$v" }
    check $name [expr {$v eq {1} ? 1 : 0}] 1
}
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }

# ⚠ CODE, NOT PROSE.  A row that asserts what a proc DOES must read what it
# executes, or a comment becomes a counterexample and a registered T1 fence goes
# red on an edit that changed no behaviour.  Row CE12 did exactly that until
# 2026-10-01; the same defect made RB5 of test_registered_banner_1626 red on a
# tail comment, and is why rb_decomment exists in that file.  This is that logic,
# in the smallest form CE12 needs: whole-line comments dropped, tail comments cut
# at a `#` that is in COMMAND POSITION -- the previous non-blank character is a
# `;` or an open brace -- with quote state and backslash escapes respected, since
# a `#` inside a string is not a comment.  Its own non-vacuity is a row, not a
# claim: see the leg beside CE12's limit-1 check.
proc ce_decomment {ln} {
    set n [string length $ln] ; set q 0 ; set ob [format %c 123]
    for {set i 0} {$i < $n} {incr i} {
        set c [string index $ln $i]
        if {$c eq "\\"} { incr i ; continue }
        if {$c eq "\""} { set q [expr {!$q}] ; continue }
        if {$q} continue
        if {$c ne "#"} continue
        set j [expr {$i - 1}]
        while {$j >= 0 && [string first [string index $ln $j] " \t"] >= 0} { incr j -1 }
        if {$j < 0} { return [string range $ln 0 [expr {$i-1}]] }
        set prev [string index $ln $j]
        if {$prev eq ";" || $prev eq $ob} { return [string range $ln 0 [expr {$i-1}]] }
    }
    return $ln
}
proc ce_code {txt} {
    set out {}
    foreach ln [split $txt \n] {
        if {[regexp {^[ \t]*#} $ln]} continue
        lappend out [ce_decomment $ln]
    }
    return [join $out \n]
}
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        incr ::fail
    }
}
# ⚠ THE LINE ENDS IN `: FAIL` SO THAT A READER COUNTS IT.  A bare `BGERROR:`
# line is invisible to both readers — run_suites.sh echoes `^(FAIL|FATAL)` and
# summarize_all counts lines ENDING in FAIL — and without a handler at all the
# error would not touch $fail, so the suite would print `OVERALL: ok` over a
# real failure.  That hollow-pass shape is live in test_calc_skeleton.tcl
# (receipts/B3-final.md §3 D8b measured it); this file does not copy it.
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

# --- agreement with a HAND-DERIVED value -------------------------------------
# NEVER equality, for two independent reasons that stack: the fixture agrees
# with the hand value only to the headroom §11.2's table measured, and this
# file's accessor shows eight significant digits (see the header).  A failing
# row prints the value AND the relative error, so the next reader does not have
# to re-run anything to see how far off it was.
proc near {got exp tol} {
    if {![string is double -strict $got]} { return "NOTANUMBER:{$got}" }
    if {$exp == 0.0} {
        if {abs($got) <= $tol} { return ok }
        return "off:{$got} abs=[expr {abs($got)}]"
    }
    set r [expr {abs(($got - $exp) / double($exp))}]
    if {$r <= $tol} { return ok }
    return "off:{$got} rel=$r"
}
# the whole `calc` namespace's state, enumerated FROM THE NAMESPACE and not
# from a list written here -- CLAUDE.md's limit L9: a hand-kept list of state to
# watch is the same defect one level up, and the variable a later phase adds is
# exactly the one nobody remembers to add.  Copied in substance from
# test_calc_buffer.tcl's ns_state, which exists for the same R508 band.
proc ns_state {} {
    set d {}
    foreach v [lsort [info vars ::calc::*]] {
        if {[array exists $v]} {
            lappend d $v [list ARRAY [lsort [array get $v]]]
        } elseif {[info exists $v]} {
            lappend d $v [set $v]
        } else {
            lappend d $v UNSET
        }
    }
    return $d
}
proc ns_diff {before after} {
    array set b $before
    array set a $after
    set out {}
    foreach k [lsort [array names a]] {
        if {![info exists b($k)]} { lappend out "+[namespace tail $k]" ; continue }
        if {$a($k) ne $b($k)} { lappend out [namespace tail $k] }
    }
    foreach k [lsort [array names b]] {
        if {![info exists a($k)]} { lappend out "-[namespace tail $k]" }
    }
    return $out
}
# the fixture, and the C file whose format string CE0 reads.  $XSCHEM_SHAREDIR
# is a Tcl GLOBAL the C core sets (xinit.c); in-tree it is src/.  Located the
# way test_calc_widgets.tcl and test_calc_buffer.tcl locate their sources.
proc srcfile {name} {
    if {[info exists ::XSCHEM_SHAREDIR]} {
        set p [file join $::XSCHEM_SHAREDIR $name]
        if {[file exists $p]} { return $p }
    }
    if {[file exists src/$name]} { return src/$name }
    return {}
}
# one C function's body, with every comment LINE dropped.  Lifted by the shape
# CLAUDE.md prescribes for a Tcl proc -- from the definition line to the first
# following line that is exactly `}` -- rather than by line number, because a
# coordinate rots and an identity does not.  Comments go because the whole point
# of a row like CE9's is that prose mentioning a field must not count as code
# writing it; that is the limit CLAUDE.md records three shipped comments failing.
proc ce9_cfun {path name} {
    if {$path eq {}} { return {} }
    if {[catch {open $path r} fp]} { return {} }
    set body [read $fp] ; close $fp
    set out {} ; set in 0
    foreach ln [split $body \n] {
        if {!$in} {
            if {[regexp "^\[A-Za-z_\].*\\m$name\\M\\s*\\(" $ln]} { set in 1 }
            continue
        }
        if {$ln eq "\}"} { break }
        set t [string trim $ln]
        if {[string index $t 0] eq {*} || [string range $t 0 1] eq {/*}} { continue }
        append out $ln "\n"
    }
    return $out
}
set fixture {}
foreach cand {tests/headless/data/calc_fixture.raw} {
    if {[file exists $cand]} { set fixture [file normalize $cand] }
}
if {$fixture eq {} && [info exists ::XSCHEM_SHAREDIR]} {
    set cand [file join [file dirname $::XSCHEM_SHAREDIR] tests headless data calc_fixture.raw]
    if {[file exists $cand]} { set fixture [file normalize $cand] }
}
# read one of the fixture's four plots.  ALWAYS WITH AN EXPLICIT TYPE: measured
# 2026-10-01, a second bare `xschem raw read <f>` after the file has also been
# read as `op` lands back on the OP slot (1 point), so `raw value <v> 30 0`
# answers EMPTY and a row reads that as a wrong number rather than as a wrong
# database.  With the type given every switch is deterministic.
proc fread {ty} {
    if {$::fixture eq {}} { return NOFIXTURE }
    if {[catch {xschem raw read $::fixture $ty} r]} { return "ERR:$r" }
    return [list $r [pcall xschem raw sim_type]]
}
proc rawnames {} {
    set l {}
    if {[catch {xschem raw list} l]} { return {} }
    return [split [string trim $l] "\n"]
}
# ⚠ COMPARED AS ONE COMMA-JOINED STRING, not as a Tcl list.  `i(@m1[id])`
# contains brackets, so Tcl's canonical list representation braces it and a
# `$got eq $exp` against a hand-typed list literal fails on the BRACES rather
# than on the names -- which is a failing row that says nothing about the tree.
proc names_csv {} { return [join [rawnames] ,] }
proc leaked {} {
    set out {}
    foreach n [rawnames] { if {[string match __calc_tmp* $n]} { lappend out $n } }
    return $out
}
# the dict keys every band reads, so a missing key fails ONE row by name
# instead of raising inside twenty.
proc dg {d k} {
    if {[catch {dict get $d $k} v]} { return "NOKEY:$k" }
    return $v
}
# one evaluation, answered as {value at} or as an error string.
proc ev {rpn {ds 0}} {
    set d [pcall calc::eval_rpn $rpn $ds]
    if {[string match ERR:* $d]} { return $d }
    if {[dg $d ok] ne {1}} { return "REFUSED:[dg $d msg]" }
    return [list [dg $d value] [dg $d at]]
}
proc evval {rpn {ds 0}} {
    set r [ev $rpn $ds]
    if {[llength $r] != 2} { return $r }
    return [lindex $r 0]
}

if {[catch {

# =============================================================================
# CE0 — the fixture is the one §11.2 describes, and the accessor is "%.8g"
# =============================================================================
group CE0 {
    check_expr "CE0 fixture: tests/headless/data/calc_fixture.raw was located" \
        {$::fixture ne {}}
    check "CE0 fixture: a bare read selects tran and sees TWO datasets (§11.2's '>1 dataset')" \
        [list [pcall xschem raw read $::fixture] [pcall xschem raw sim_type] \
              [pcall xschem raw datasets]] {1 tran 2}
    check "CE0 fixture: 101 points per transient dataset, 202 combined" \
        [list [pcall xschem raw points 0] [pcall xschem raw points 1] \
              [pcall xschem raw points]] {101 101 202}
    # The inventory, in file order.  §11.2's fourth requirement is the
    # op-parameter vector, and the NAMING ASYMMETRY is what R207/R204 are about:
    # ngspice wrapped three of the four `@dev[param]` saves in `i(...)` and left
    # the admittance-typed one bare.
    check "CE0 fixture: the ten vector names, in file order" [names_csv] \
        {time,@m1[gm],i(@m1[id]),i(@rdc1[i]),i(@rtop[i]),v(dcmid),v(div),v(lp),v(ramp),v(sq)}
    check {CE0 fixture: R207's naming asymmetry -- the bare @m1[gm] resolves and a bare @rtop[i] does NOT} \
        [list [expr {[pcall xschem raw index {@m1[gm]}] >= 0}] \
              [pcall xschem raw index {@rtop[i]}] \
              [expr {[pcall xschem raw index {i(@rtop[i])}] >= 0}]] {1 -1 1}
    # ⚠ THE TOLERANCE THIS FILE USES IS THE ACCESSOR'S, SO THE ACCESSOR'S OWN
    # FORMAT STRING IS READ OUT OF THE C RATHER THAN DESCRIBED.  If dtoa ever
    # widens, this row says so and the header's reasoning can be revisited;
    # if a row's tolerance is tightened without it, the row goes red instead.
    set util [srcfile util.c]
    check_expr "CE0 the C file holding dtoa() was located" {$util ne {}}
    set fmt {}
    if {$util ne {}} {
        set fp [open $util r] ; set body [read $fp] ; close $fp
        if {[regexp {dtoa\(double i\)\s*\{.*?my_snprintf\(s, S\(s\), "([^"]*)", i\)} $body -> m]} {
            set fmt $m
        }
    }
    check "CE0 dtoa() -- the one `xschem raw value` prints through -- formats with %.8g" $fmt {%.8g}
    # ⚠ THIS ROW MEASURES STATE AFTER A READ, AND NOTHING WIDER.  It used to be
    # named "no cursor is published after a headless read", which read as
    # support for the much stronger claim `calc::eval_cursor_point`'s comment
    # was making -- that NO headless route publishes annot_p.  That claim was
    # FALSE: `xschem annotate_at <t>` and `xschem update_op` both write the
    # field, and band CE9 drives both.  The row is kept, renamed to its actual
    # scope, and widened to all three fields, because "a read leaves the
    # annotation cleared" is the premise CE4 and CE9 both start from.
    check "CE0 a READ leaves all three annotation fields cleared -- annot_p -1, annot_sweep_idx -1 (this says nothing about other publishers: see CE9)" \
        [pcall xschem raw annot] {-1 0 -1}
}

# =============================================================================
# CE1 — PLAN 3.1: calc::rpn_of_text is the identity, and the ONE phase-8 site
# =============================================================================
group CE1 {
    check "CE1 the two procs exist" \
        [list [llength [pcall info procs ::calc::rpn_of_text]] \
              [llength [pcall info procs ::calc::rpn_of_buffer]]] {1 1}
    # Identity means BYTE identity, including the whitespace the engine's own
    # tokeniser cares about: `my_strtok_r(ntok_ptr, " \t\n", "", 0, ...)` splits
    # on space, tab and newline with an EMPTY quote set, and the buffer is a
    # multi-line text widget, so a newline inside an expression is a legal
    # delimiter and must survive the translation untouched.
    foreach {label s} {
        empty           {}
        one-token       {v(ramp)}
        an-expression   {v(out) v(in) - db20()}
        leading-space   { v(a) v(b) +}
        trailing-space  {v(a) v(b) + }
        inner-tab       "v(a)\tv(b)\t+"
        inner-newline   "v(a)\nv(b)\n+"
        a-bare-number   {1u}
        the-?-operator  {1 v(a) 0 ?}
        not-rpn-at-all  {abs(v(a)) + 3}
    } {
        check "CE1 rpn_of_text is the identity in RPN mode ($label)" \
            [pcall calc::rpn_of_text $s] $s
    }
    # R508 HAS THREE CASES AND THIS FILE MEASURES TWO OF THEM ON EVERY ARM.
    # The window was never built here, so case 1 (".calc was never built") is in
    # force whichever arm this is; case 3 ("--nogui, where the `winfo` COMMAND
    # does not exist and a bare `winfo exists` RAISES") is in force by itself
    # only on the `--nogui` arm, so it is FORCED for the row below rather than
    # assumed.  ⚠ An earlier revision asserted `info commands winfo` eq {}
    # outright, which made this suite a standing RED under `full_audit.sh` --
    # that driver globs every test_*.tcl and runs it on the DISPLAY arm, where
    # Tk is loaded.  A false red there becomes a standing red, which is the one
    # thing a new fence must never be.
    set arm [expr {[pcall info commands winfo] eq {} ? {no-tk} : {tk-no-window}}]
    check "CE1 R508 this arm is one of the two no-window worlds, and it is named" \
        [expr {$arm in {no-tk tk-no-window}}] 1
    check "CE1 R508 ...and .calc really is absent, which is the premise of both" \
        [expr {$arm eq {no-tk} || ![winfo exists .calc]}] 1
    check "CE1 R508 rpn_of_buffer with no window answers {} and does not raise" \
        [pcall calc::rpn_of_buffer] {}
    # ...and R508's THIRD case, forced: the `winfo` command itself taken away,
    # which is how row S13 of test_calc_skeleton.tcl and band CB5 of
    # test_calc_buffer.tcl fence the same clause.  On the --nogui arm there is
    # nothing to rename and the row measures the same thing unforced.
    set had [expr {[pcall info commands winfo] ne {}}]
    if {$had} { pcall rename ::winfo ::ce1_real_winfo }
    set r3 [pcall calc::rpn_of_buffer]
    set gone [pcall info commands winfo]
    if {$had} { pcall rename ::ce1_real_winfo ::winfo }
    check "CE1 R508 third case FORCED: with the `winfo` command gone, rpn_of_buffer still answers {} and does not raise" \
        [list $gone $r3] {{} {}}
    # ...and it is the WINDOW READ in front of the translation, not a second
    # translator: its body must reach the buffer and then hand off, so phase 8
    # has one site to replace.  Asserted on the body rather than claimed.
    set b [pcall info body ::calc::rpn_of_buffer]
    check "CE1 rpn_of_buffer reads .calc.buf, guards with calc::has_win, and delegates to rpn_of_text" \
        [list [regexp {\.calc\.buf} $b] [regexp {calc::has_win} $b] \
              [regexp {calc::rpn_of_text} $b]] {1 1 1}
    # and nothing ELSE in the file translates the buffer into RPN.  Derived
    # from the file's own text: exactly one proc body may name rpn_of_text
    # besides the two above, namely nobody.
    set src [srcfile calculator.tcl]
    check_expr "CE1 the running calculator.tcl was located" {$src ne {}}
    set callers {}
    if {$src ne {}} {
        foreach p [lsort [pcall info procs ::calc::*]] {
            if {$p eq {::calc::rpn_of_text}} { continue }
            set pb [pcall info body $p]
            if {[string match ERR:* $pb]} { continue }
            if {[regexp {calc::rpn_of_text} $pb]} { lappend callers [namespace tail $p] }
        }
    }
    check "CE1 rpn_of_text has exactly ONE caller in the file, so phase 8 has ONE place to change" \
        $callers {rpn_of_buffer}
}

# =============================================================================
# CE2 — R402: calc::tmpvec mints __calc_tmp<N>
# =============================================================================
group CE2 {
    check "CE2 the proc exists" [llength [pcall info procs ::calc::tmpvec]] 1
    set a [pcall calc::tmpvec]
    set b [pcall calc::tmpvec]
    set c [pcall calc::tmpvec]
    check "CE2 R402 the name matches the __calc_tmp<N> spelling §7.3 fixes" \
        [list [regexp {^__calc_tmp[0-9]+$} $a] [regexp {^__calc_tmp[0-9]+$} $b]] {1 1}
    check "CE2 three mints give three DIFFERENT names -- a re-used destination is landmine L2" \
        [llength [lsort -unique [list $a $b $c]]] 3
    check "CE2 and none of them is empty -- an empty destination name is not inert" \
        [list [expr {$a ne {}}] [expr {$b ne {}}] [expr {$c ne {}}]] {1 1 1}
    # ⚠ WHY THE EMPTY CASE HAS A ROW OF ITS OWN.  Measured 2026-10-01:
    # `xschem raw add {} {v(ramp) 2 /}` is NOT refused -- it registers a vector
    # whose name is the empty string and evaluates into it.  A minting proc that
    # could answer {} would therefore mutate the user's loaded raw with a column
    # nothing can name, delete or find again.
    # ...and a name the raw ALREADY HAS is skipped, because `xschem raw add`
    # answers 0 for an existing vector and evaluates into it anyway -- the stale
    # column test_calc_scratch_reuse.tcl is about.
    # ⚠ THE NAME PLANTED IS THE ONE THE COUNTER WILL PRODUCE NEXT, and that is
    # the whole content of the row.  An earlier revision planted the name tmpvec
    # had JUST returned and then asserted the next answer differed and was free
    # -- which the counter guarantees on its own, so deleting the skip logic
    # entirely left the row GREEN.  Found by sabotage, not by reading.  Reading
    # ::calc::tmpn and planting tmpn+1 puts the collision exactly where the
    # minting proc has to notice it.
    set serial [pcall set ::calc::tmpn]
    check_expr "CE2 fixture: the mint's serial is readable, so the collision can be aimed" \
        {[string is integer -strict $serial]}
    set inway "__calc_tmp[expr {$serial + 1}]"
    pcall xschem raw add $inway {v(ramp)}
    check "CE2 fixture: the next name the counter would produce is now TAKEN" \
        [expr {[pcall xschem raw index $inway] >= 0}] 1
    set n2 [pcall calc::tmpvec]
    check "CE2 a name the loaded raw already holds is SKIPPED, not handed back" \
        [list [expr {$n2 ne $inway}] [expr {[pcall xschem raw index $n2] < 0}] \
              [regexp {^__calc_tmp[0-9]+$} $n2]] {1 1 1}
    pcall xschem raw del $inway
    # ⚠ AND THE MINT IS INTERPRETER-SCOPED, NOT WINDOW-SCOPED.  `calc::close`
    # clears the three `fb*` hints because they describe THIS window's buffer;
    # the serial must NOT go with them, or a name minted before a close comes
    # back after one and lands on a column a previous evaluation may still own.
    # `editcan` is the precedent -- it measures the interpreter, and close leaves
    # it alone.
    # ⚠ THE SERIALS ARE COMPARED, NOT THE STRINGS, and the first wording of this
    # row compared the strings -- which the very defect it is for also
    # satisfies: a mint reset to 0 hands back a name that DIFFERS from the last
    # one too.  SAB-S (calc::close resetting the serial) went GREEN on that
    # wording.  "The serial only ever goes up" is the property.
    set pre [pcall calc::tmpvec]
    pcall calc::close
    set post [pcall calc::tmpvec]
    set np {} ; set nq {}
    regexp {([0-9]+)$} $pre -> np
    regexp {([0-9]+)$} $post -> nq
    check "CE2 calc::close does not reset the mint -- the serial only ever goes UP, so a name cannot come back after a close" \
        [list [expr {[string is integer -strict $np] && [string is integer -strict $nq]}] \
              [expr {[string is integer -strict $nq] && [string is integer -strict $np] && $nq > $np}]] {1 1}
}

# =============================================================================
# CE3 — §3: the HAND-COMPUTED numbers, through calc::eval_rpn, both datasets
# =============================================================================
# The derivations, from tests/headless/data/README.md, at the LAST transient
# sample (k = 100, t = 10 ms), which is where eval_rpn reads when no cursor is
# published:
#   v(ramp)       PWL(0 0 10m 10) is 1 V/ms exactly, so k/10 V          -> 10
#   v(sq)         the third rising edge finished at 9.1 ms and the run
#                 ends before the next fall at 10.1 ms                  -> 1
#   v(div)        resistive divider: v(ramp)/2 (ds0), v(ramp)/4 (ds1)   -> 5, 2.5
#   i(@rtop[i])   v(ramp)/(rtop+rbot) = /2000 (ds0), /4000 (ds1)        -> 5m, 2.5m
#   v(dcmid)      5 * 3k/(2k+3k)                                        -> 3
#   i(@rdc1[i])   (5-3)/2k                                              -> 1m
#   @m1[gm]       KP*W/L*(Vgs-Vt)*(1+lambda*Vds) = 1m*1.3*1.03          -> 1.339m
#   i(@m1[id])    (beta/2)(Vgs-Vt)^2(1+lambda Vds) = 0.5m*1.69*1.03     -> 870.35u
# =============================================================================
group CE3 {
    check "CE3 fixture: the transient read" [fread tran] {1 tran}
    check "CE3 calc::eval_rpn exists" [llength [pcall info procs ::calc::eval_rpn]] 1
    # a plain vector reference first, so a failing expression row cannot be
    # confused with a failing READ.
    foreach {ds rpn exp tol label} {
        0 {v(ramp)}       10      1e-7  {v(ramp) = k/10 at k=100}
        1 {v(ramp)}       10      1e-7  {v(ramp) is the same in both datasets}
        0 {v(sq)}         1       1e-7  {v(sq) = 1 at t=10ms}
        0 {v(div)}        5       1e-7  {v(div) = v(ramp)/2 in dataset 0}
        1 {v(div)}        2.5     1e-7  {v(div) = v(ramp)/4 in dataset 1}
        0 {v(dcmid)}      3       1e-7  {the dc divider, 5*3k/5k}
        0 {i(@rdc1[i])}   0.001   1e-7  {(5-3)/2k, the exactly-known op-parameter value}
        0 {@m1[gm]}       0.001339 1e-7 {level-1 gm = 1m*1.3*1.03}
        0 {i(@rtop[i])}   0.005   1e-7  {v(ramp)/2000 in dataset 0}
        1 {i(@rtop[i])}   0.0025  1e-7  {v(ramp)/4000 in dataset 1}
    } {
        check "CE3 ds$ds  $rpn  -> $label" [near [evval $rpn $ds] $exp $tol] ok
    }
    # ⚠ i(@m1[id]) IS THE ONE VALUE THE README GIVES A LOOSE TOLERANCE, AND
    # THROUGH THIS FILE'S ACCESSOR IT NEEDS NONE -- which is the header's
    # "the tolerance belongs to the instrument" sentence arriving as a number.
    # The fixture holds 870.3500030 uA where the pure level-1 formula gives
    # 870.35, a 3.5e-9 relative disagreement, so the hand value is an
    # approximation OF THE SIMULATOR here rather than a restatement of the deck.
    # `%.8g` rounds that away completely: the scalar reader answers 0.00087035,
    # which is the hand value BIT FOR BIT.  So this row runs at its neighbours'
    # 1e-7 and the two rows below assert BOTH halves instead of a comment
    # claiming them -- an earlier revision's row name said "loosened per the
    # README" while running at exactly the neighbours' tolerance, and its
    # comment said a row using that tolerance "would be red on a correct
    # fixture", which this row was disproving every time it passed.
    check {CE3 ds0  i(@m1[id])  -> level-1 id = 0.5m*1.69*1.03, at its neighbours' 1e-7} \
        [near [evval {i(@m1[id])} 0] 870.35e-6 1e-7] ok
    check {CE3 ...and through `xschem raw value` (%.8g) it is EXACT -- equality holds, so no tolerance is being spent here} \
        [near [evval {i(@m1[id])} 0] 870.35e-6 0.0] ok
    # the README's 3.5e-9 is real and visible through the SIXTEEN-digit reader,
    # which is the one the README's table was measured with.  Both legs, so
    # neither "the disagreement is imaginary" nor "the tolerance is doing work
    # here" can be read off this file.
    set id16 [lindex [split [string trim [pcall xschem raw values {i(@m1[id])} 0]]] end]
    check {CE3 ...while `xschem raw values` (%.16g) DOES see the README's ~3.5e-9 disagreement, which is why the two readers need different tolerances} \
        [list [near $id16 870.35e-6 1e-7] [expr {[near $id16 870.35e-6 1e-9] eq {ok} ? 1 : 0}]] {ok 0}
    # now the expressions -- which is the thing the Calculator actually sends.
    foreach {ds rpn exp label} {
        0 {v(ramp) 2 /}            5      {the engine's own divide}
        0 {v(div) v(ramp) /}       0.5    {ds0's divider ratio}
        1 {v(div) v(ramp) /}       0.25   {ds1's divider ratio}
        0 {v(ramp) v(div) -}       5      {10 - 5}
        0 {v(dcmid) v(ramp) *}     30     {3 * 10}
        0 {v(ramp) 2 **}           100    {10 squared}
        0 {v(div) abs()}           5      {a one-operand function}
        0 {v(ramp) 1u *}           1e-05  {the SPICE engineering suffix §3.1}
        0 {v(ramp) 1 >}            1      {a comparison yields 1.0/0.0}
        0 {v(ramp) 100 >}          0      {...and 0 when false}
    } {
        check "CE3 ds$ds  $rpn  -> $label" [near [evval $rpn $ds] $exp 1e-7] ok
    }
    check "CE3 every answer above was reported as coming from the LAST point, there being no cursor" \
        [lindex [ev {v(ramp)} 0] 1] last
    # the dict's own shape, once, by name -- so a later phase that adds a key
    # cannot quietly rename one of these.
    set d [pcall calc::eval_rpn {v(ramp) 2 /} 0]
    check "CE3 the answer dict names its ok, value, at, point, dataset, dest and msg" \
        [lsort [pcall dict keys $d]] {at dataset dest msg ok point value}
    check "CE3 ...and reports the point it read and the dataset it read it from" \
        [list [dg $d point] [dg $d dataset] [dg $d ok] [dg $d msg]] {100 0 1 {}}
    # an empty expression is refused by NAME, not evaluated to nothing.
    set e [pcall calc::eval_rpn {   } 0]
    check "CE3 an empty expression is refused, with a message and no destination minted" \
        [list [dg $e ok] [expr {[dg $e msg] ne {}}] [dg $e dest]] {0 1 {}}
    # a dataset the loaded raw does not have is refused rather than read as 0.
    set o [pcall calc::eval_rpn {v(ramp)} 7]
    check "CE3 a dataset the raw does not have is refused and the message names it" \
        [list [dg $o ok] [expr {[string match *7* [dg $o msg]]}]] {0 1}
}

# =============================================================================
# CE4 — R604: the cursor, or the last point, and WHICH
# =============================================================================
# R604's exact words: "Evaluate on a wave-valued expression reports the value at
# the current cursor if one exists, else at the last point, and SAYS WHICH in the
# message."  So the band asks three things: the right value on each arm, the
# right word, and -- the one that is easy to get wrong -- that the cursor's index
# is read as an ABSOLUTE position across all datasets, which is what
# `raw->annot_p` is (src/callback.c sets it to `p`, an index into
# `raw->values[...]`, after adding the dataset offset `ofs`).
#
# The cursor arm is FORCED, and the forcing is the point rather than a
# convenience: nothing headless publishes a cursor (CE0 measures annot_p = -1
# after a read), so without a seam this requirement would have no row at all on
# the arm that gates.  `calc::eval_cursor_point` exists as its own one-line proc
# for exactly that, and its comment in src/calculator.tcl says so.
# =============================================================================
group CE4 {
    check "CE4 fixture: the transient read" [fread tran] {1 tran}
    check "CE4 calc::eval_cursor_point exists and is the only cursor reader" \
        [list [llength [pcall info procs ::calc::eval_cursor_point]] \
              [regexp {raw annot} [pcall info body ::calc::eval_cursor_point]]] {1 1}
    check "CE4 with no cursor it answers -1, which is what `xschem raw annot` says" \
        [pcall calc::eval_cursor_point] -1
    set r [ev {v(div)} 0]
    check "CE4 no cursor -> the LAST point of the asked-for dataset, and it says `last`" \
        [list [near [lindex $r 0] 5 1e-7] [lindex $r 1]] {ok last}
    # --- force a cursor at absolute sample 30 (dataset 0, t = 3 ms) ----------
    pcall rename ::calc::eval_cursor_point ::ce4_real_cursor
    proc ::calc::eval_cursor_point {} { return $::ce4_point }
    set ::ce4_point 30
    set r [ev {v(div)} 0]
    check "CE4 a cursor at absolute 30 -> v(div) = v(ramp)/2 = 1.5, and it says `cursor`" \
        [list [near [lindex $r 0] 1.5 1e-7] [lindex $r 1]] {ok cursor}
    set r [ev {v(ramp) 2 /}]
    check "CE4 ...and an EXPRESSION is read at the cursor too, not only a vector" \
        [list [near [lindex $r 0] 1.5 1e-7] [lindex $r 1]] {ok cursor}
    # --- THE ABSOLUTE-INDEX ROW.  Dataset 1's sample 30 is absolute 131
    # (101 + 30), and on that dataset v(div) is v(ramp)/4 = 0.75.  An
    # implementation that passed the dataset alongside the cursor's index would
    # answer 1.5 here; one that passed dataset -1, as annot_p requires, answers
    # 0.75.  This is the row that separates the two.
    set ::ce4_point 131
    set r [ev {v(div)} 0]
    check "CE4 a cursor at absolute 131 reads DATASET 1's sample 30 (0.75), not dataset 0's (1.5)" \
        [list [near [lindex $r 0] 0.75 1e-7] [lindex $r 1]] {ok cursor}
    set d [pcall calc::eval_rpn {v(div)} 0]
    check "CE4 ...and the dict reports the absolute point and dataset -1, naming how it read" \
        [list [dg $d point] [dg $d dataset] [dg $d at]] {131 -1 cursor}
    # --- a cursor index the loaded raw cannot answer must not become a value.
    # ⚠⚠ THIS ROW ASSERTS WHICH REFUSAL, NOT MERELY THAT THERE WAS ONE, AND THE
    # SABOTAGE ROUND IS WHY.  It used to read `[dg $d msg] ne {}`, and when band
    # CE10's non-finite guard was added one statement later that version went
    # GREEN against the numeric check being deleted outright -- an empty read
    # fails the finite test too, so the product still refused and still deleted,
    # with a message about a non-finite number instead of one about a point it
    # cannot read.  That is CLAUDE.md's "a fence keyed to a symptom dies quietly
    # when something else cures the symptom", caught by re-running the previous
    # stage's sabotages rather than by reading.  The row now pins the SENTENCE
    # the user would get, which is the thing the two guards disagree about.
    set ::ce4_point 99999
    set d [pcall calc::eval_rpn {v(div)} 0]
    check "CE4 a cursor index past the end of the data is refused with the NO-DATA-AT-THAT-POINT sentence, which names the point -- not read as 0, and not mistaken for a non-finite result" \
        [list [dg $d ok] [dg $d msg]] [list 0 [pcall calc::eval_msg point 99999]]
    pcall rename ::calc::eval_cursor_point {}
    pcall rename ::ce4_real_cursor ::calc::eval_cursor_point
    check "CE4 the real cursor reader is back" [pcall calc::eval_cursor_point] -1
    # --- the status sentence R603/R604 puts on screen, which is the ONLY place
    # the user learns which point was read.  Read from the minting proc rather
    # than from the widget, because this arm has no widget.
    check "CE4 calc::eval_fmt exists" [llength [pcall info procs ::calc::eval_fmt]] 1
    set s [pcall calc::eval_fmt [pcall calc::eval_rpn {v(div)} 0]]
    check "CE4 R603/R604 the sentence carries the value AND says which point it came from" \
        [list [string match {*5*} $s] [string match {*last point*} $s]] {1 1}
    set sr [pcall calc::eval_fmt [pcall calc::eval_rpn {} 0]]
    check "CE4 ...and a refusal's sentence is the refusal's own message, not a value" \
        [list [expr {$sr ne {}}] [string match {*=*} $sr]] {1 0}
}

# =============================================================================
# CE5 — §3.1 and L1: the two rejections, and why R607 cannot use the engine's -1
# =============================================================================
group CE5 {
    check "CE5 fixture: the transient read" [fread tran] {1 tran}
    # §3.1: "Unknown vector => the whole evaluation returns -1 and the scratch
    # column is not touched."  Since issue 0325 raw_add_vector() zeroes a
    # freshly created column BEFORE evaluating, so what a caller sees through a
    # NEW destination is a defined all-zero trace.
    check "CE5 an unresolvable vector name yields a defined ZERO, not uninitialised heap" \
        [near [evval {v(nosuch) v(div) +} 0] 0 1e-30] ok
    check "CE5 ...and the token really does not resolve, so the premise holds" \
        [pcall xschem raw index v(nosuch)] -1
    # ⚠⚠ THE FINDING THIS ROW EXISTS TO RE-MEASURE EVERY RUN, and the reason
    # PLAN 3.4 cannot be written as "on engine -1, name the token":
    # raw_add_vector() (src/save.c) DISCARDS plot_raw_custom_data()'s return
    # value, so `xschem raw add` answers the same thing for a good expression
    # and a rejected one -- 1 if it created the vector, 0 if it already existed.
    # There is no -1 to read from Tcl at all.  R607 therefore has to validate
    # every vector-looking token with `xschem raw index` BEFORE calling the
    # engine, or the return has to be plumbed out of the C first.
    set good [pcall xschem raw add __calc_t_ce5a {v(div) 2 /}]
    set bad  [pcall xschem raw add __calc_t_ce5b {v(nosuch) v(div) +}]
    check "CE5 `xschem raw add` reports SUCCESS for a REJECTED expression, exactly as for a good one" \
        [list $good $bad] {1 1}
    pcall xschem raw del __calc_t_ce5a
    pcall xschem raw del __calc_t_ce5b
    # L1: STACKMAX is 200 and overflow is caught at STACKMAX-2.  210 tokens
    # overflows; the C prints "stack overflow in graph expression parsing" and
    # returns -1, which again reaches Tcl as a zero column rather than an error.
    set long {}
    for {set i 0} {$i < 210} {incr i} { append long "v(ramp) " }
    check "CE5 L1 more than STACKMAX tokens yields a zero column, not a wrong number" \
        [near [evval $long 0] 0 1e-30] ok
    # ...and the bound is a BOUND, not "long is bad": 50 copies of v(ramp) with
    # 49 `+` is 99 tokens, under STACKMAX-2, and sums to 50 x 10 V at k=100.
    set sum "[string repeat {v(ramp) } 50][string trim [string repeat {+ } 49]]"
    check "CE5 L1 ...and a 99-token expression still evaluates, so the bound is not simply 'long is bad'" \
        [list [llength $sum] [near [evval $sum 0] 500 1e-7]] {99 ok}
    # §3.1's negative del() rejection (issue 0325) reaches the Calculator
    # through the same door, and is the other way a caller gets a zero.
    check "CE5 a negative del() delay is rejected the same way an unknown name is" \
        [near [evval {v(ramp) -1 del()} 0] 0 1e-30] ok
    # L5's sibling, measured while verifying the fixture: `xschem raw index`
    # does NOT parse the %<dataset> suffix -- that grammar belongs to
    # node_token_split() on the trace path.  A later phase that builds
    # `v(div)%1` and validates it with `raw index` would reject every one.
    check "CE5 `xschem raw index` does not parse the %<dataset> suffix (it is node_token_split's)" \
        [list [pcall xschem raw index v(div)%0] [pcall xschem raw index v(div)%1]] {-1 -1}
}

# =============================================================================
# CE6 — the other two analyses: the ac dataset's complex accessors, and the op
#       dataset, which is where the three-operand `?` is measured
# =============================================================================
# Derivations, with no simulator in them.  H = 1/(1 + jwRC); clp = 1/(2.pi.rac.fp)
# with rac = 1k and fp = 1k, so the pole is at exactly 1 kHz and `ac lin 20 100
# 2k` steps by exactly 100 Hz:
#   index 19, f = 2000: wRC = 2, H = 1/(1+2j) = 0.2 - 0.4j
#                       |H| = 1/sqrt(5) = 0.447213595499958
#                       db20 = -6.989700043360187, ph = -atan(2) = -63.43494882292201 deg
#   index  9, f = 1000: wRC = 1, H = (1-j)/2
#                       |H| = 1/sqrt(2) = 0.7071067811865475
#                       db20 = -10*log10(2) = -3.010299956639812, ph = -45 deg exactly
# v(sq) is the `AC 1` drive, so it is 1 + 0j at every frequency and v(lp)/v(sq)
# is H itself.  ⚠ In an ac read `v(lp)` is the MAGNITUDE column and the derived
# three drop the v(...) wrapper: ph(lp), re(lp), im(lp).  `ph()` is in DEGREES.
# =============================================================================
group CE6 {
    check "CE6 fixture: the ac read" [fread ac] {1 ac}
    check "CE6 fixture: one dataset, twenty points, and 1000 Hz is index 9" \
        [list [pcall xschem raw datasets] [pcall xschem raw points 0] \
              [pcall xschem raw value frequency 9 0]] {1 20 1000}
    foreach {rpn exp label} {
        {v(lp) v(sq) /}          0.447213595499958   {|H| at 2 kHz = 1/sqrt(5)}
        {v(lp) v(sq) / db20()}  -6.989700043360187   {20log10(1/sqrt 5)}
        {ph(lp)}                -63.43494882292201   {-atan(2) in DEGREES}
        {re(lp)}                 0.2                 {Re H at 2 kHz}
        {im(lp)}                -0.4                 {Im H at 2 kHz}
    } {
        check "CE6 ac last point (index 19, f=2000): $rpn -> $label" \
            [near [evval $rpn 0] $exp 1e-7] ok
    }
    # ...and the -3 dB point itself, at the cursor, because it is index 9 and
    # not the last point.  This is spec §11.2's "exact -3 dB point".
    pcall rename ::calc::eval_cursor_point ::ce6_real_cursor
    proc ::calc::eval_cursor_point {} { return 9 }
    foreach {rpn exp label} {
        {v(lp) v(sq) /}          0.7071067811865475  {|H| at the pole = 1/sqrt(2)}
        {v(lp) v(sq) / db20()}  -3.010299956639812   {-10log10(2) -- THE -3 dB POINT}
        {ph(lp)}                -45                  {-45 degrees exactly}
    } {
        check "CE6 ac at the cursor (index 9, f=1000): $rpn -> $label" \
            [near [evval $rpn 0] $exp 1e-7] ok
    }
    pcall rename ::calc::eval_cursor_point {}
    pcall rename ::ce6_real_cursor ::calc::eval_cursor_point
    # ⚠ THE UNDRIVEN-COLUMN TRAP, re-measured here because it is the one most
    # likely to cost a later row an afternoon: read_raw_data_block() substitutes
    # a float 1e-35 floor into the MAGNITUDE column of a complex sample that is
    # exactly 0 + 0j ("avoid 0 for dB calculations", its own comment), while
    # re/im/ph stay exactly 0.  So "an undriven ac node reads 0" is FALSE through
    # the magnitude name and true through the other three.
    check "CE6 an undriven ac column reads a 1e-35 FLOOR through the magnitude name" \
        [expr {[evval {v(ramp)} 0] < 1e-30 && [evval {v(ramp)} 0] > 0}] 1
    check "CE6 ...and exactly zero through re/im/ph" \
        [list [near [evval {re(ramp)} 0] 0 0.0] [near [evval {im(ramp)} 0] 0 0.0] \
              [near [evval {ph(ramp)} 0] 0 0.0]] {ok ok ok}
    # --- the op dataset: §11.2's reason for it is that at t=0 the pulse and the
    # ramp are both zero, so the dc divider is the only non-zero thing there.
    check "CE6 fixture: the op read" [fread op] {1 op}
    check "CE6 fixture: one dataset, ONE point" \
        [list [pcall xschem raw datasets] [pcall xschem raw points 0]] {1 1}
    check {CE6 op v(dcmid) is bit-exactly 3 and i(@rdc1[i]) bit-exactly 1 mA} \
        [list [evval {v(dcmid)} 0] [evval {i(@rdc1[i])} 0]] {3 0.001}
    # §3.2's `?` is the one operator that consumes THREE operands (phase 1d
    # found W30 had called it binary), and §11.1 asks for its truth table.  It
    # is measured on the op dataset ON PURPOSE: `case COND` in src/save.c
    # carries a `dbg(0, ...)` that prints one line PER EVALUATED POINT on every
    # path, so the same table over the transient arm emits 101 lines of product
    # chatter per evaluation.  One point, one line.
    foreach {rpn exp} {
        {7 1 9 ?}   7
        {7 0 9 ?}   9
        {7 2 9 ?}   7
        {7 -1 9 ?}  7
    } {
        check "CE6 §3.2 `X cond Y ?` truth table: $rpn -> $exp" [near [evval $rpn 0] $exp 1e-7] ok
    }
    check "CE6 ...and the condition can be a wave: v(dcmid) is 3, so >2 takes X and >4 takes Y" \
        [list [near [evval {7 v(dcmid) 2 > 9 ?} 0] 7 1e-7] \
              [near [evval {7 v(dcmid) 4 > 9 ?} 0] 9 1e-7]] {ok ok}
    # L3: a SINGLE-token formula is not detected as an expression by the graph
    # path's `strpbrk(express, " \n\t")`.  It reaches the engine fine through
    # `xschem raw add`, which is the door this phase uses -- asserted so that a
    # later phase moving to the graph path finds out here rather than there.
    check "CE6 L3 a single-token expression still evaluates through `raw add`" \
        [near [evval {v(dcmid)} 0] 3 1e-7] ok
}

# =============================================================================
# CE7 — R402: nothing is left behind, success path AND refusal
# =============================================================================
group CE7 {
    check "CE7 fixture: the transient read" [fread tran] {1 tran}
    check "CE7 nothing is leaked before the band starts" [leaked] {}
    set d [pcall calc::eval_rpn {v(div) 2 /} 0]
    check "CE7 a successful evaluation leaves no __calc_tmp* vector behind" \
        [list [dg $d ok] [leaked]] {1 {}}
    check "CE7 ...and the destination it names is gone from the raw" \
        [pcall xschem raw index [dg $d dest]] -1
    check "CE7 a REJECTED expression leaves nothing behind either" \
        [list [expr {[dg [pcall calc::eval_rpn {v(nosuch) v(div) +} 0] ok] eq {1}}] [leaked]] {1 {}}
    # R402's words are "on every exit path INCLUDING ERROR".  The reachable
    # error path here is a cursor index the data cannot answer, which refuses
    # AFTER the destination has been minted and evaluated.
    pcall rename ::calc::eval_cursor_point ::ce7_real_cursor
    proc ::calc::eval_cursor_point {} { return 99999 }
    set d [pcall calc::eval_rpn {v(div)} 0]
    pcall rename ::calc::eval_cursor_point {}
    pcall rename ::ce7_real_cursor ::calc::eval_cursor_point
    # ...and WHICH refusal, for the reason CE4's out-of-range row records: the
    # non-finite guard one statement later also refuses an unreadable value, so
    # a row that asked only "did it refuse" stopped discriminating.
    check "CE7 a refusal taken AFTER the destination was minted still deletes it, and it is the no-data-at-that-point refusal" \
        [list [dg $d ok] [dg $d msg] [leaked]] [list 0 [pcall calc::eval_msg point 99999] {}]
    check "CE7 ...and the ten fixture vectors are all still there, none renamed or dropped" \
        [names_csv] \
        {time,@m1[gm],i(@m1[id]),i(@rdc1[i]),i(@rtop[i]),v(dcmid),v(div),v(lp),v(ramp),v(sq)}
}

# =============================================================================
# CE8 — R508: with no window, Evaluate records nothing and never reaches the
#       engine.  TWO AXES, because "silent no-op" has two halves.
# =============================================================================
# This band runs after every engine band because it drives the whole Evaluate
# entry point; CE9-CE11 follow it and none of them reads anything it leaves
# behind (each clears and re-reads the database it needs).  Which
# of R508's three cases is in force depends on the ARM: on `--nogui` the `winfo`
# command itself is absent, so a bare `winfo exists` guard would THROW -- the
# regression receipts/B3-final.md item D1 records nine procs having shipped --
# and on a display arm (which `full_audit.sh` uses for every test_*.tcl) Tk is
# loaded and the case is simply "the window was never built".  Band CE1 names
# the arm and forces the third case explicitly; this band asserts the two axes
# on whichever arm it is running, which is why no row here asserts the absence
# of `winfo`.
# =============================================================================
group CE8 {
    check "CE8 fixture: the transient read, so a reachable engine would HAVE something to read" \
        [fread tran] {1 tran}
    check_expr "CE8 the namespace enumeration is not vacuous" {[llength [info vars ::calc::*]] >= 17}
    set before [ns_state]
    set raised {}
    foreach step {{calc::eval_click} {calc::rpn_of_buffer} {calc::rpn_of_text {v(a) v(b) +}}} {
        if {[catch {eval $step} e]} { lappend raised "[lindex $step 0]:$e" }
    }
    set after [ns_state]
    check "CE8 none of the three raises with no window (R508's third case)" $raised {}
    check "CE8 ...and none of them WRITES a calc:: namespace variable -- 'records nothing' is about state, not only about raising" \
        [ns_diff $before $after] {}
    check "CE8 ...and .calc was not created -- an entry point must not build a window to refuse" \
        [expr {[pcall info commands winfo] eq {} || ![winfo exists .calc]}] 1
    # ⚠ THIS IS MEASURED WITH A COUNTING SHIM, NOT INFERRED FROM AN ABSENT
    # COLUMN.  The row used to assert `[leaked] eq {}` alone, and a product that
    # DID reach the engine and succeeded would satisfy that too -- `eval_rpn`
    # deletes its destination on the success path (R402), so the absence of a
    # `__calc_tmp*` vector cannot tell "never ran" from "ran and tidied up".
    # Shimming `calc::eval_rpn` asserts something the success path cannot: that
    # the proc was never entered.  The mint's serial is a second axis on the
    # same question, because `calc::tmpvec` increments it before the engine call
    # and nothing puts it back.
    set n0 [pcall set ::calc::tmpn]
    set ::ce8_calls 0
    pcall rename ::calc::eval_rpn ::ce8_real_eval_rpn
    proc ::calc::eval_rpn {rpn {dataset 0}} {
        incr ::ce8_calls
        return [calc::eval_refusal {shimmed by CE8} $dataset]
    }
    pcall calc::eval_click
    set seen $::ce8_calls
    # ⚠ THE SERIAL IS SNAPSHOT HERE, before the control leg and before the
    # non-vacuity row below re-runs the real proc -- both of which mint.  An
    # earlier revision read it after them and the row was red on a correct
    # tree, which is a false red and the one thing a registered fence must
    # never be.
    set n1 [pcall set ::calc::tmpn]
    set ctrl [pcall calc::eval_rpn {v(ramp)} 0]
    set seen2 $::ce8_calls
    pcall rename ::calc::eval_rpn {}
    pcall rename ::ce8_real_eval_rpn ::calc::eval_rpn
    check "CE8 eval_click never entered calc::eval_rpn -- U6 says the Calculator never evaluates against THIS window's raw" \
        $seen 0
    check "CE8 non-vacuity: the shim DOES count a call, so the 0 above is a measurement and not a broken instrument" \
        [list $seen2 [pcall dict get $ctrl msg]] {1 {shimmed by CE8}}
    check "CE8 ...and the real calc::eval_rpn is back, answering over the loaded fixture" \
        [near [evval {v(ramp)} 0] 10 1e-7] ok
    check "CE8 ...and the destination mint's serial never moved, which a reached engine cannot avoid" \
        [list [expr {[string is integer -strict $n0] ? 1 : 0}] \
              [expr {$n1 eq $n0 ? 1 : 0}]] {1 1}
    check "CE8 ...and no __calc_tmp* column was left behind either (the weaker axis, kept because it is free)" \
        [leaked] {}
    # ...and the structural half: every phase-3 proc that names a .calc widget
    # path also names calc::has_win.  Derived from the bodies, with the
    # window-free procs listed by what they are rather than by name, so a guard
    # silently dropped cannot be excused by a body that stopped naming widgets.
    # ⚠ DERIVED FROM THE NAMESPACE, NOT LISTED HERE.  CLAUDE.md's limit L9 and
    # row X1 of test_snprintf_fmt_1608.tcl: a hand-kept list is the same defect
    # one level up, and the proc a later step adds is exactly the one nobody
    # would remember to add.  Phase 3's procs are the `eval_*` and `rpn_of_*`
    # families plus the destination minter; the count leg is the non-vacuity
    # control, so a pattern that stopped matching reddens instead of passing.
    set ph3 {}
    foreach p [lsort [pcall info procs ::calc::*]] {
        set t [namespace tail $p]
        if {[string match eval_* $t] || [string match rpn_of_* $t] || $t eq {tmpvec}} {
            lappend ph3 $t
        }
    }
    check_expr "CE8 the phase-3 proc set was derived from the namespace, not listed" \
        {[llength $ph3] >= 10}
    set unguarded {}
    set pure {}
    foreach p $ph3 {
        set b [pcall info body ::calc::$p]
        if {[string match ERR:* $b]} { lappend unguarded "$p:NO-BODY" ; continue }
        if {![regexp {\.calc} $b]} { lappend pure $p ; continue }
        if {![regexp {calc::has_win} $b]} { lappend unguarded $p }
    }
    check "CE8 every phase-3 proc whose body names a .calc widget path also names calc::has_win" \
        $unguarded {}
    # ⚠ THE EXACT EXPECTED LIST IS WHAT MAKES THIS ROW NON-VACUOUS.  Both
    # `calc::rpn_of_buffer` and `calc::eval_click` name a `.calc` path -- the
    # buffer and the Eval button -- so both must be in the GUARDED half; if the
    # `.calc` regexp ever matched nothing, every proc would land here instead
    # and this row reddens rather than passing over a measurement it did not
    # make.  That is the hole receipts/B3-final.md item D4 records the phase-2
    # version of this row having had.
    check "CE8 ...and the ones that name no widget path are the engine-side procs, which is why this file can run headless" \
        [lsort $pure] \
        {eval_cursor_point eval_finite eval_fmt eval_in_token eval_msg eval_refusal eval_rpn rpn_of_text tmpvec}
}

# =============================================================================
# CE9 — R604's CURSOR CLAUSE AGAINST THE REAL `raw->annot_p`
# =============================================================================
# ⚠⚠ BAND CE4 ABOVE REACHES THE CURSOR ARM BY RENAMING `calc::eval_cursor_point`
# ASIDE, SO NO ROW IN IT EVER DROVE THE PRODUCT'S REAL STATE -- and that is
# exactly how the defect this band exists for shipped.  The proc's own comment
# asserted, as measured fact, that "no headless route sets annot_p".  TWO DO:
#
#   `xschem annotate_at <t>`  -> backannotate_at_time() -> backannot_pos_at() ->
#       backannotate_cursor_b_in_db() (src/callback.c), the SAME publisher the
#       graph's cursor B uses.  This is a GENUINE cursor and the Calculator
#       should read it.
#   `xschem update_op`        -> update_op() (src/save.c) sets
#       `xctx->raw->annot_p = 0` for ANY op/dc database.  That is the shipped
#       operating-point annotation path -- the verb src/op_annot.tcl calls --
#       and it is NOT a cursor.  The guard in front of it tests the sim_type
#       ONLY (its own comment says so, issue 0862), so a genuine MULTI-POINT
#       .dc sweep publishes its FIRST STEP as the operating point.
#
# THE DISCRIMINATOR IS ALREADY IN THE ANSWER STRING.  `xschem raw annot` answers
# "<annot_p> <annot_x> <annot_sweep_idx>" (src/scheduler.c).  The cursor
# publisher sets all three, and `sweep_idx` is clamped to >= 0 before the stamp;
# update_op() never touches `annot_sweep_idx` at all, so it stays at the -1 the
# read paths leave.  `calc::eval_cursor_point` tests that third field, and the
# rows below drive both publishers for real.
#
# ⚠ A `raw read` WITHOUT a `raw clear` does NOT reset the annotation (measured:
# annot survives a second read of the same file), so every band here clears
# first and this one clears on the way out.
# =============================================================================
group CE9 {
    set tmp [test_scratch calceng]
    # a THREE-point "Operating Point", the shape row T26 of
    # tests/headless/test_op_annot.tcl uses: read_dataset() rewrites a
    # multi-point Operating Point to sim_type `dc`, which is why update_op()'s
    # op/dc guard accepts it.  v(d) = 6.5 / 6.6 / 6.7, so the first step and the
    # last point are different numbers and a row can tell which was read.
    set dcraw [file join $tmp opn.raw]
    set fh [open $dcraw w]
    puts -nonewline $fh "Title: CE9 multi-point operating point
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 3
Variables:
\t0\ttime\ttime
\t1\tv(d)\tvoltage
Values:
0\t0.0
\t6.5
1\t1.0
\t6.6
2\t2.0
\t6.7
"
    close $fh
    # --- the premise: a fresh read publishes NOTHING, all three fields --------
    pcall xschem raw clear
    check "CE9 fixture: the 3-point Operating Point arrives as sim_type `dc` with 3 points, which is what makes update_op accept it" \
        [list [pcall xschem raw read $dcraw op] [pcall xschem raw sim_type] \
              [pcall xschem raw points]] {1 dc 3}
    check "CE9 premise: a fresh read publishes no annotation at all -- annot_p AND annot_sweep_idx are both -1" \
        [pcall xschem raw annot] {-1 0 -1}
    set d [pcall calc::eval_rpn {v(d)} 0]
    check "CE9 R604 with nothing published: the LAST point (6.7), and it says `last`" \
        [list [near [dg $d value] 6.7 1e-7] [dg $d at] [dg $d point]] {ok last 2}
    # --- `xschem update_op` IS NOT A CURSOR ----------------------------------
    # This is the whole defect.  update_op() publishes point 0 as "the operating
    # point"; R604's cursor clause must not read it as a cursor, because there
    # is no cursor -- and on this database point 0 is 6.5 where the honest
    # answer is 6.7.
    check "CE9 `xschem update_op` publishes this op/dc database" [pcall xschem update_op] 1
    set a [pcall xschem raw annot]
    check "CE9 ...and it moved annot_p to 0 while leaving annot_sweep_idx at -1 -- the discriminator, in the verb's own answer" \
        [list [lindex $a 0] [lindex $a 2]] {0 -1}
    check "CE9 ⚠ THE DEFECT: an operating-point publish is NOT a cursor, so eval_cursor_point must still answer -1" \
        [pcall calc::eval_cursor_point] -1
    set d [pcall calc::eval_rpn {v(d)} 0]
    check "CE9 ⚠ THE DEFECT, AS A NUMBER: the answer is still 6.7 at the LAST point, not 6.5 at a cursor nobody put there" \
        [list [near [dg $d value] 6.7 1e-7] [dg $d at] [dg $d point]] {ok last 2}
    set d [pcall calc::eval_rpn {v(d) 2 *} 0]
    check "CE9 ...and an EXPRESSION reports 13.4, not 13" \
        [list [near [dg $d value] 13.4 1e-7] [dg $d at]] {ok last}
    check "CE9 ...and the sentence says `at the last point`, which is the half of R604 the user reads" \
        [list [string match {*last point*} [pcall calc::eval_fmt $d]] \
              [string match {*cursor*} [pcall calc::eval_fmt $d]]] {1 0}
    # --- `xschem annotate_at <t>` IS a cursor, and must still be read ---------
    # ⚠ THE NON-VACUITY LEG, and it is the one that stops the fix from being
    # "ignore annot_p".  This publisher is the graph's own cursor-B code reached
    # with a requested time instead of a pointer position, so what it stamps is
    # a real cursor and R604's first clause applies to it.  Without this leg a
    # product that answered -1 unconditionally would pass every row above.
    pcall xschem raw clear
    check "CE9 fixture: the committed transient, for the real cursor publisher" [fread tran] {1 tran}
    check "CE9 premise: still nothing published" [pcall xschem raw annot] {-1 0 -1}
    check "CE9 `xschem annotate_at 0.003` is a HEADLESS publisher of a REAL cursor" \
        [pcall xschem annotate_at 0.003] 1
    set a [pcall xschem raw annot]
    check "CE9 ...and it stamps all three fields: point 30 (t = 3 ms on the 0.1 ms grid) and a sweep index that is NOT -1" \
        [list [lindex $a 0] [expr {[string is integer -strict [lindex $a 2]] && [lindex $a 2] >= 0}]] {30 1}
    check "CE9 eval_cursor_point reads the REAL annot_p -- no proc was renamed to reach this row" \
        [pcall calc::eval_cursor_point] 30
    set d [pcall calc::eval_rpn {v(div)} 0]
    check "CE9 R604 with a REAL cursor: v(div) = v(ramp)/2 = 1.5 at absolute point 30, and it says `cursor`" \
        [list [near [dg $d value] 1.5 1e-7] [dg $d at] [dg $d point] [dg $d dataset]] {ok cursor 30 -1}
    check "CE9 ...and the sentence says `at the cursor`" \
        [list [string match {*cursor*} [pcall calc::eval_fmt $d]] \
              [string match {*last point*} [pcall calc::eval_fmt $d]]] {1 0}
    # --- the structural half: ONE site in the C publishes a sweep index ------
    # The discriminator is only sound while `annot_sweep_idx` has exactly one
    # writer that sets it to anything but -1.  Asserted over the two C files
    # that write the field, with comment lines dropped, so a second publisher
    # added without a cursor reddens here instead of silently making the test
    # above meaningless.  Row names cite by SYMBOL; the count is re-measured
    # every run rather than quoted in a comment.
    set wr {}
    foreach cf {callback.c save.c scheduler.c draw.c} {
        set p [srcfile $cf]
        if {$p eq {}} { lappend wr "$cf:NOFILE" ; continue }
        set fp [open $p r] ; set body [read $fp] ; close $fp
        foreach ln [split $body \n] {
            set t [string trim $ln]
            if {[string index $t 0] eq {*} || [string range $t 0 1] eq {/*}} { continue }
            if {![regexp {annot_sweep_idx\s*=} $t]} { continue }
            if {[regexp {annot_sweep_idx\s*=\s*-1\s*;} $t]} { continue }
            lappend wr "$cf:[string range $t 0 60]"
        }
    }
    check "CE9 exactly ONE site in the C sets annot_sweep_idx to anything but -1, and it is the cursor-B publisher in callback.c" \
        [list [llength $wr] [expr {[llength $wr] == 1 ? [lindex [split [lindex $wr 0] :] 0] : $wr}]] {1 callback.c}
    check "CE9 ...and update_op() publishes annot_p without naming annot_sweep_idx at all, which is why the third field discriminates" \
        [list [regexp {annot_p\s*=\s*0\s*;} [ce9_cfun [srcfile save.c] update_op]] \
              [regexp {annot_sweep_idx} [ce9_cfun [srcfile save.c] update_op]]] {1 0}
    pcall xschem raw clear
    test_scratch_drop $tmp
}

# =============================================================================
# CE10 — A NON-FINITE RESULT IS NOT A VALUE TO SHOW
# =============================================================================
# `string is double -strict` ACCEPTS every IEEE non-finite spelling, so the
# numeric check eval_rpn ends on does not vouch for what it passes on: measured,
# `v(ramp) -1 * sqrt()` reported `= -nan  (at the last point)` with ok=1.
#
# The ENGINE returning NaN for the square root of a negative is defensible --
# that is what the C library does and plot_raw_custom_data() does not police it.
# REPORTING it as a value is not: R603's answer is "a scalar", and `-nan` read
# off a status line beside a confident "(at the last point)" is the Cadence
# failure mode R607 exists to forbid, one step further along.  So the refusal is
# the Calculator's, taken where it already refuses for a point it cannot read,
# and it NAMES the spelling rather than saying "expression error".
#
# ⚠ NOT A DIVISION-BY-ZERO BAND.  `1 0 /` answered a garbage number until issue
# 1628 fixed `case DIVIS` in the engine, and
# tests/headless/test_divis_zero_1628.tcl owns that ground; nothing here
# duplicates it.  This band is only about a non-finite value REACHING THE REPORT.
# =============================================================================
group CE10 {
    pcall xschem raw clear
    check "CE10 fixture: the transient read" [fread tran] {1 tran}
    # the premise, re-measured rather than described: this is WHY the guard is
    # needed, and a reader tempted to delete it as redundant sees it here.
    check "CE10 premise: `string is double -strict` accepts every non-finite spelling, so the numeric check alone vouches for nothing" \
        [list [string is double -strict nan] [string is double -strict -nan] \
              [string is double -strict Inf] [string is double -strict -Inf]] {1 1 1 1}
    # --- the predicate, driven DIRECTLY, with spellings THIS machine cannot
    #     produce.  `%g` names a non-finite differently per C library: glibc
    #     gives inf/-inf/nan/-nan, the MSVC runtime XSchemWin/ targets gives
    #     1.#INF / -1.#IND / 1.#QNAN.  Only a direct call can fence the Windows
    #     half, and without these rows a denylist written on this machine would
    #     pass every behavioural row below while shipping the defect to the
    #     other platform.  THIS IS THE REASON calc::eval_finite IS A PROC.
    check "CE10 calc::eval_finite exists and is the one site that knows which spellings are numbers to show" \
        [list [llength [pcall info procs ::calc::eval_finite]] \
              [regexp {calc::eval_finite} [pcall info body ::calc::eval_rpn]]] {1 1}
    foreach s {nan -nan NaN inf -inf Inf -Inf INF Infinity -Infinity
               1.#INF -1.#INF -1.#IND 1.#QNAN -1.#QNAN} {
        check "CE10 eval_finite REFUSES the non-finite spelling {$s}" [pcall calc::eval_finite $s] 0
    }
    foreach s {0 -0 10 -10 0.5 -0.5 .5 -.5 3.1622777 1e-05 1E-05 1e+300 -6.9897
               0.00087035 870.35 100 2000} {
        check "CE10 eval_finite ACCEPTS the finite spelling {$s}, so it is not 'refuse anything unusual'" \
            [pcall calc::eval_finite $s] 1
    }
    foreach {rpn label} {
        {v(ramp) -1 * sqrt()}        {sqrt of a negative -> NaN}
        {1e300 1e300 *}              {overflow -> +Inf}
        {1e300 1e300 * -1 *}         {overflow negated -> -Inf}
        {710 exp()}                  {exp past DBL_MAX -> +Inf}
    } {
        set d [pcall calc::eval_rpn $rpn 0]
        check "CE10 $label: refused, not reported as a value ($rpn)" [dg $d ok] 0
        check "CE10 ...and the refusal NAMES what it saw rather than saying 'expression error' ($rpn)" \
            [list [expr {[dg $d msg] ne {}}] \
                  [expr {[regexp -nocase {nan|inf} [dg $d msg]] ? 1 : 0}]] {1 1}
        check "CE10 ...and eval_fmt prints the refusal, with no `=` to read as an answer ($rpn)" \
            [list [expr {[pcall calc::eval_fmt $d] ne {}}] \
                  [string match {*=*} [pcall calc::eval_fmt $d]]] {1 0}
        check "CE10 ...and R402 holds on this exit path too -- the destination is gone ($rpn)" [leaked] {}
    }
    # non-vacuity: the SAME shape with a finite answer is still answered, so the
    # guard refuses non-finite values and not square roots.
    check "CE10 non-vacuity: sqrt of a POSITIVE is still answered -- the guard is about the VALUE, not the operator" \
        [list [near [evval {v(ramp) sqrt()} 0] 3.1622776601683795 1e-7] [lindex [ev {v(ramp) sqrt()} 0] 1]] {ok last}
    check "CE10 ...and a finite negative is still answered, so the guard is not 'refuse anything odd'" \
        [near [evval {v(ramp) -1 *} 0] -10 1e-7] ok
    # ⚠ THE TWO REFUSALS MUST NOT BE THE SAME SENTENCE, and this row is here
    # because the sabotage round found the alternative.  `eval_finite` refuses
    # an EMPTY read too (the string does not look like a decimal), so with the
    # numeric check above it deleted the product still refuses an out-of-range
    # point -- just with the wrong explanation.  A user reading "the result is
    # not a finite number ()" about a cursor past the end of the data has been
    # told something false about their expression.  Rows CE4 and CE7 pin the
    # out-of-range sentence; this one pins that the two are distinguishable at
    # all, which is the property that makes those two rows capable of failing.
    check "CE10 the non-finite refusal and the no-data-at-that-point refusal are DIFFERENT sentences, so neither can stand in for the other" \
        [expr {[pcall calc::eval_msg nonfinite -nan] ne [pcall calc::eval_msg point 99999] ? 1 : 0}] 1
    check "CE10 ...and the numeric check in front of it still has its own job: an EMPTY read is a point problem, not a finiteness one" \
        [list [pcall calc::eval_finite {}] [regexp {not a finite number} [pcall calc::eval_msg point 99999]]] {0 0}
}

# =============================================================================
# CE11 — THE ENGINE'S `?` ARM MUST NOT PRINT ONE LINE PER EVALUATED POINT
# =============================================================================
# `plot_raw_custom_data()`'s three-operand `?` arm (src/save.c, the
# `stack1[i].i == COND` branch) carried `dbg(0, "%g %g %g\n", ...)`.  `dbg(0)`
# prints whenever `debug_var >= 0`, which is every ordinary run (xinit.c sets it
# to 0), and `raw_add_vector()` evaluates over `0 .. raw->allpoints - 1` -- ALL
# datasets -- so one Evaluate of an expression containing `?` wrote one line per
# point of the whole file.  `?` is one of RULING-2's twelve keypad tokens, so
# this is user-reachable noise on the path PLAN phase 2 made live, and a
# 20000-point transient prints 20000 lines.  Every other dbg() in that function
# is level 1; this one is now too.
#
# ⚠ THE ROW COUNTS THE LINES, it does not quote a number in a comment.  The
# capture is in-process: `xschem log <file>` points the C `errfp` at a file and
# `xschem log` with no argument puts it back (src/scheduler.c, the `log` verb),
# which is what `dbg()` writes through (src/util.c).  The control leg below
# proves the capture really sees a dbg(0) line, so a zero count is a measurement
# and not a broken instrument.
# =============================================================================
group CE11 {
    set tmp [test_scratch calceng]
    set lf [file join $tmp cond.log]
    pcall xschem raw clear
    check "CE11 fixture: the transient read -- 202 points over both datasets, which is the window raw_add_vector evaluates" \
        [list [lindex [fread tran] 0] [pcall xschem raw points]] {1 202}
    proc ce11_cap {lf script} {
        pcall xschem log $lf
        set r [uplevel 1 $script]
        pcall xschem log
        set body {}
        if {[file exists $lf]} { set fp [open $lf r] ; set body [read $fp] ; close $fp }
        catch {file delete -force $lf}
        set lines {}
        foreach l [split [string trimright $body \n] \n] { if {[string trim $l] ne {}} { lappend lines $l } }
        return [list $r $lines]
    }
    # --- the control: the capture really does see a dbg(0) line --------------
    # update_op() refusing a transient is a dbg(0) one-liner on a path with no
    # other output, so it is the cheapest proof the instrument works.
    set c [ce11_cap $lf {pcall xschem update_op}]
    check "CE11 control: `xschem log <f>` really captures dbg(0) -- update_op refusing a transient lands exactly one line in it" \
        [list [lindex $c 0] [llength [lindex $c 1]] \
              [regexp {not an operating point database} [lindex [lindex $c 1] 0]]] {0 1 1}
    # --- the measurement ----------------------------------------------------
    set c [ce11_cap $lf {pcall calc::eval_rpn {7 1 9 ?} 0}]
    set lines [lindex $c 1]
    set cond 0
    foreach l $lines { if {[regexp {^7 1 9$} [string trim $l]] } { incr cond } }
    check "CE11 the `?` operand trace is GONE: evaluating a ternary over 202 points writes ZERO lines of it" $cond 0
    # ⚠ THE FAILURE MESSAGE IS CAPPED AT THREE DISTINCT LINES ON PURPOSE.  A
    # regression here prints one line per point, and a row that echoed them all
    # would put 202 lines of product chatter into T1's verdict file -- which is
    # the same noise this band exists to remove, arriving through the fence.
    check "CE11 ...and nothing else per-point either: the whole captured debug stream is empty for one Evaluate" \
        [list [llength $lines] [lrange [lsort -unique $lines] 0 2]] {0 {}}
    check "CE11 non-vacuity: the ternary really was evaluated -- `7 1 9 ?` answers 7" \
        [near [dg [lindex $c 0] value] 7 1e-7] ok
    # ...and the arm's own dbg level, read out of the C, so a future reader who
    # restores the level reddens here as well as in the counting row above.
    set sv [srcfile save.c]
    check_expr "CE11 src/save.c was located" {$sv ne {}}
    set cb {}
    if {$sv ne {}} {
        set fp [open $sv r] ; set body [read $fp] ; close $fp
        set keep 0
        foreach ln [split $body \n] {
            set t [string trim $ln]
            # comment LINES dropped before anything is matched: the arm now
            # carries a block comment explaining the level, and a scanner that
            # read prose as code would be satisfied by a sentence.  Same reason
            # ce9_cfun strips them.
            if {[string index $t 0] eq {*} || [string range $t 0 1] eq {/*}} { continue }
            if {[regexp {stack1\[i\]\.i\s*==\s*COND} $t]} { set keep 1 ; continue }
            if {$keep && [regexp {^dbg\(([0-9]+)} $t -> lvl]} { set cb $lvl ; set keep 0 }
            if {$keep && [regexp {stack2\[stackptr2 - 3\]\s*=} $t]} { set keep 0 }
        }
    }
    check "CE11 the COND arm's own dbg() is level 1 -- this row reads THAT ARM ONLY, so it says nothing about the rest of plot_raw_custom_data(), which still has one deliberate dbg(0) for the stack-overflow error" $cb 1
    pcall xschem raw clear
    test_scratch_drop $tmp
}

# =============================================================================
# CE12 — TWO DECLARED LIMITS, ASSERTED AS THEY STAND
# =============================================================================
# Neither is fixed here and both are stated in `calc::eval_click`'s own comment.
# They are ROWS and not only prose for the reason CLAUDE.md gives: a declared
# limit nothing re-measures is the one artefact that can go false while every
# suite stays green.  A later phase that CLOSES either of these reds a row here
# and has to come back and correct the declaration, which is the behaviour
# wanted -- these rows are not defending the limits, they are pinning them.
# =============================================================================
group CE12 {
    pcall xschem raw clear
    check "CE12 fixture: the transient read, whose two datasets differ on purpose" \
        [list [lindex [fread tran] 0] [pcall xschem raw datasets]] {1 2}
    # --- LIMIT 1: Evaluate always reports DATASET 0 -------------------------
    # The seam exists (eval_rpn takes the argument and answers correctly for
    # either dataset); what is missing is the control that chooses, which is the
    # `Family` pick scope and PLAN phase 6.
    # ⚠ DECOMMENTED FIRST, AND THAT IS NOT FUSSINESS.  This row scanned the RAW
    # `info body`, so ANY in-body comment mentioning a dataset turned a
    # REGISTERED T1 fence red with zero behaviour change -- the identical defect
    # this suite's own receipt names elsewhere, and the one that made RB5 of
    # test_registered_banner_1626 red on a tail comment.  A row about what code
    # DOES must read code.  Whole-line and tail comments both go: a `#` opens a
    # comment only in command position, so the test is that the previous
    # non-blank character is a semicolon or an open brace.
    # ⚠ SPELLED IN WORDS, NEVER AS THE CHARACTER.  A literal open brace in a
    # comment inside a braced block is still counted by Tcl's brace matcher, so
    # it silently unbalances the file -- the driver wrote one here, `info
    # complete` on the whole suite went 1 -> 0, and the suite would not parse.
    # ⚠ AND THEN DID IT AGAIN IN THIS VERY PARAGRAPH, quoting the character while
    # warning against quoting it.  Two edits, same trap, the second one inside
    # the explanation of the first.  That is why the rule is mechanical -- never
    # type the character in a comment -- rather than a thing to be careful about.
    # test_registered_banner_1626 records the same trap (its procs spell every
    # literal brace as [format %c 123] for this reason) and the driver repeated
    # it anyway, which is the argument for spelling it out in both files.
    check "CE12 limit: calc::eval_click's CODE (comments stripped) passes NO dataset, so eval_rpn's {dataset 0} default decides" \
        [regexp {dataset} [ce_code [pcall info body ::calc::eval_click]]] 0
    check "CE12 ...and the stripper is not vacuous: it keeps the code it is scanning (eval_click still calls eval_in_token) and really drops prose" \
        [list [regexp {eval_in_token} [ce_code [pcall info body ::calc::eval_click]]] \
              [regexp {dataset} [ce_code "set x 1 ;# a dataset mention\n"]] \
              [regexp {dataset} [ce_code "# a dataset mention\nset x 1\n"]] \
              [regexp {dataset} [ce_code "set dataset 1\n"]]] {1 0 0 1}
    check "CE12 ...and the two datasets really do differ, so the limit is not academic: v(div) is 5 in ds0 and 2.5 in ds1" \
        [list [near [evval {v(div)} 0] 5 1e-7] [near [evval {v(div)} 1] 2.5 1e-7]] {ok ok}
    check "CE12 ...and the control that would choose is still inert, owned by PLAN phase 6" \
        [regexp {calc::inert "pick scope \$label" 6} [pcall info body ::calc::build_mode]] 1
    # ...and the cursor arm is NOT subject to it, because annot_p is absolute.
    # Stated here because "Evaluate only ever sees dataset 0" would be the wrong
    # generalisation to carry forward.
    pcall rename ::calc::eval_cursor_point ::ce12_real_cursor
    proc ::calc::eval_cursor_point {} { return 131 }
    check "CE12 ...but the CURSOR arm is not limited this way: an absolute index reads whichever dataset it sits in (131 = ds1 sample 30 = 0.75)" \
        [list [near [evval {v(div)} 0] 0.75 1e-7] [lindex [ev {v(div)} 0] 1]] {ok cursor}
    pcall rename ::calc::eval_cursor_point {}
    pcall rename ::ce12_real_cursor ::calc::eval_cursor_point
    # --- LIMIT 2: the `%<n>` spelling is a silent zero ----------------------
    # `xschem raw index` does not parse the suffix (band CE5 measures that from
    # the verb's side); what this band adds is what the CALCULATOR does with it,
    # which is answer 0 with ok=1 and no message at all.
    foreach spelling {{v(div)%0} {v(div)%1}} {
        set d [pcall calc::eval_rpn $spelling 0]
        check "CE12 limit: the documented %<n> dataset spelling reads as a SILENT ZERO from the Calculator ($spelling)" \
            [list [dg $d ok] [near [dg $d value] 0 1e-30] [dg $d msg]] {1 ok {}}
    }
    check "CE12 ...and the bare name it is built from answers a real number, so the zero is the SUFFIX and not the node" \
        [near [evval {v(div)} 0] 5 1e-7] ok
    check "CE12 ...and the Tcl-side per-dataset reader that DOES take a dataset is `xschem raw values <name> <ds>`" \
        [list [llength [split [string trim [pcall xschem raw values v(div) 1]]]] \
              [near [lindex [split [string trim [pcall xschem raw values v(div) 1]]] end] 2.5 1e-12]] {101 ok}
    # ⚠ WHY IT IS A LIMIT AND NOT A BUG TO FIX HERE: naming the token that did
    # not resolve is R607, PLAN 3.4.  Band CE5 holds the measurement that makes
    # 3.4 buildable at all -- the engine's -1 never reaches Tcl -- so the fix
    # for the SILENCE is the same work, and splitting it would mean two
    # validators.  Asserted rather than claimed:
    check "CE12 ...and the reason it is silent is 3.4's, not a missing check here: `raw add` reports success for a rejected expression" \
        [list [pcall xschem raw add __calc_t_ce12 {v(div)%1}] [pcall xschem raw index v(div)%1]] {1 -1}
    pcall xschem raw del __calc_t_ce12
    check "CE12 ...and that probe column is gone again" [pcall xschem raw index __calc_t_ce12] -1
    pcall xschem raw clear
}

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

## ⚠⚠ THE `OVERALL: ok` SENTINEL IS WHAT T1 CAN SCORE.  `banner_complete` in
## tests/banner_rule.tcl -- the ONLY Tcl reader of the rule, and the one
## tests/run_regression.tcl sources -- is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$`
## and accepts NO `RESULT: ALL PASS` spelling, while run_suites.sh and
## full_audit.sh carry their own EREs which DO accept it.  So passing standalone
## is no evidence a suite can be registered: that is how both sibling calculator
## suites gated nothing for a month (issue 1626).
##
## ⚠ `RESULT:` MUST BE THE LAST `RESULT:` LINE.  summarize_all publishes a
## case's last `^RESULT:` line into the verdict and run_suites.sh does
## `grep -E '^RESULT' | tail -1`; both are order-independent, because
## banner_complete is `regexp -line` over the whole captured body.  What DOES
## cost something is a SECOND `RESULT:` line -- the published check count
## silently becomes whatever the last one says, with counted_failures and skips
## both still 0 and nothing reddening (issue **1627**, OPEN and unfenced).  This
## file has ONE exit path on purpose: there is no no-X gate, because nothing
## here needs a display.  A second exit path must print its verdict INSTEAD of
## this one, never as well.
##
## ⚠ ONLY THE SUCCESS PATH CLAIMS COMPLETION.
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
