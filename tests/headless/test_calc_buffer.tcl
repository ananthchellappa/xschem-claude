# tests/headless/test_calc_buffer.tcl — the Calculator's BUFFER BEHAVIOUR.
#
# Spec   doc/claude/specs/calculator.md  §8.1 (R501-R509a) and §4 W15-W22, W29-W31
# Plan   doc/claude/calculator_batch/PLAN.md phase 2 steps 2.2, 2.3, 2.4, and the
#        two driver corrections dated 2026-09-30 beneath that table
# Ledger doc/claude/calculator_batch/LEDGER.md (RULING-2: the keypad is operators
#        only, so PLAN 2.2's original "`7` then `.` then `5` gives `7.5`" criterion
#        was unreachable and the driver replaced it)
#
# WHAT THIS FILE IS, AND WHAT IT IS NOT.  It is phase 2's BEHAVIOUR fence: what
# the twelve operator keys, ClrBuf, Undo and Redo DO to the buffer, and what they
# say while doing it.  It is deliberately NOT an inventory — existence, class and
# initial state of every W-row live in tests/headless/test_calc_widgets.tcl, and
# geometry lives in tests/headless/test_calc_skeleton.tcl.  Each of those two
# files has a group that asserted these controls were INERT; phase 2 restates
# those in place rather than deleting them, and this file is where the behaviour
# they used to forbid is measured.
#
#   CB1  PLAN 2.2 — the twelve operator keys insert their token AT THE CARET,
#        whitespace-separated.  The separator is a CORRECTNESS requirement and
#        not a style choice: plot_raw_custom_data() in src/save.c tokenises with
#        `my_strtok_r(ntok_ptr, " \t\n", "", 0, &ntok_save)` — whitespace
#        delimiters and an EMPTY quote set — so `v(out)+` is ONE token, which
#        §3.1 looks up as a VECTOR NAME and the whole expression returns -1,
#        phases later and with no trace of the cause.  The split is reproduced
#        here (engine_tokens) rather than described, and the delimiter set is
#        READ OUT OF src/save.c's own call site and compared with the one
#        src/calculator.tcl separates on, so the two cannot drift apart.
#   CB2  PLAN 2.3 — ClrBuf, and the BUFFER HALF of R505 (undo/redo "are disabled
#        exactly when their history is empty").  R505's full form spans buffer
#        AND stack as one history and is PLAN 4.4; this file owns the buffer
#        half only and says so.  Includes the Tk-8.6-only `edit canundo` /
#        `edit canredo` guard.  What the two branches are measured BY, rather
#        than a claim that they are covered: the 8.6 branch by the rows that run
#        on this interpreter, with one row proving the subcommand really answers
#        here; the 8.5 fallback by SHADOWING the widget command so the
#        subcommand is genuinely absent (CB2/8.5), through the keypad, ClrBuf,
#        undo, redo AND typing routes, with the hint-setting direction of each
#        asserted next to a call that proves the history really was non-empty —
#        which is what catches a hint that UNDER-answers, the direction the
#        fallback's declared contract forbids — and with the SELF-CORRECTION
#        after a refusal measured against the next keystroke, which is what
#        makes "refuses once, not forever" a measurement instead of a claim.
#        ⚠ THE BAND IS LABELLED 8.5 AND NOT 8.4, and the label was wrong until
#        2026-09-30.  src/calculator.tcl cannot run on Tcl 8.4 at all —
#        calc::color's body uses `dict`, a Tcl 8.5 addition, and every widget in
#        the window asks calc::color for a colour — so a band claiming to force
#        8.4 was claiming to measure an interpreter this file dies on.  What the
#        shadow forces is the Tk 8.5 arm: no `edit canundo`/`edit canredo`,
#        everything else present.
#   CB3  PLAN 2.4 — R506: every buffer-changing OPERATION speaks.  The spec's
#        word is "operation", not "keystroke", and R507 already settled the
#        distinction for R413's hover help: recording a per-keystroke line would
#        spend R509's whole 50-entry cap on characters.  So a keypad insert,
#        ClrBuf, undo and redo each write a line — and undo/redo BY EITHER
#        ROUTE, the button and the keyboard's <<Undo>>/<<Redo>>, because the
#        same operation must not depend on how it was invoked.  RAW TEXT ENTRY
#        IS SILENT BY DESIGN, asserted positively with a fixture proving the
#        typing landed.  ⚠ PLAN 2.4's acceptance line reads "no silent mutation
#        path remains", which is STRICTLY TIGHTER than what this group measures
#        and than what the spec asks — it demands MORE, because a keystroke is a
#        mutation and PLAN 2.4 would have it speak.  (An earlier revision of this
#        sentence called that acceptance line LOOSER, which is backwards: the
#        WORD "mutation" names a broader class than R506's "operation", and a
#        requirement quantified over a broader class is a stronger requirement,
#        not a weaker one.)  Under the driver's settled reading of R506 a
#        keystroke, a paste, a cut and a clear-selection are text entry, not
#        operations, and stay silent.  What CB3 measures is: every OPERATION
#        speaks by either route, and the four text-entry virtual events do not.
#        So this group deliberately does NOT meet PLAN 2.4 as written, and the
#        spec is what it answers to.
#   CB4  R508 — with no window every phase-2 entry point is a silent no-op that
#        returns cleanly.  It runs late because it closes the window.  TWO AXES,
#        because "silent no-op" has two halves: nothing RAISES, and nothing is
#        WRITTEN.  The write axis is measured by snapshotting every variable in
#        the `calc` namespace around each call — enumerated from the namespace
#        itself, not from a list kept here — and by the window staying gone.
#   CB5  R508's THIRD case, which the requirement names and CB4 cannot reach:
#        `--nogui`, where the `winfo` COMMAND ITSELF does not exist, so a bare
#        `winfo exists` guard THROWS instead of no-opping.  Forced by renaming
#        ::winfo away, which is how row S13 of test_calc_skeleton.tcl already
#        fences the same clause for calc::status.  Carries the same two axes as
#        CB4.  Runs LAST.
#
# Needs a DISPLAY (Tk widgets).  Standalone from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_calc_buffer.tcl
# or, gated and with a throwaway HOME, which is the armed spelling:
#   tests/headless/run_suites.sh test_calc_buffer

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# ⚠ takes the predicate as a SCRIPT, not an evaluated boolean.  Every predicate
# here is a script over a widget or a proc that may not exist on a tree where
# phase 2 is absent; passing it already-evaluated would make the abort happen at
# the CALL site, outside the group's catch, and delete every check behind it.
# That is the trap CREW_BRIEF.md records from issue 1616: one throwing row
# aborted a suite at 62 of 402 checks and a band written to expose one defect hid
# 340 others.  Same reason test_calc_widgets.tcl carries this helper.
proc check_expr {name cond} {
    if {[catch {uplevel 1 [list expr $cond]} v]} { set v "ERR:$v" }
    check $name [expr {$v eq {1} ? 1 : 0}] 1
}
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        incr ::fail
    }
}
# ⚠ THE LINE ENDS IN `: FAIL` SO THAT A READER COUNTS IT.  A background error
# raised out of an event handler increments the failure count here, but a bare
# `BGERROR: <msg>` line is invisible to BOTH readers: run_suites.sh echoes only
# lines matching `^(FAIL|FATAL)`, and summarize_all in run_regression.tcl counts
# lines ENDING in FAIL.  Measured while sabotaging the 8.6-only accessor: the
# synthesised typing raised them out of <KeyRelease>, run_suites.sh echoed
# fewer FAIL lines than the suite had counted, and the gap took a separate run
# to explain.  (No figure here: it would be a count of one sabotage's output and
# nothing re-measures it -- re-run that sabotage to take it again.)  T1 would
# still have reddened the case — no `OVERALL: ok` is printed when $fail is
# nonzero, so banner_complete says no — but through the wrong diagnosis.
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

# ⚠ WHOLE-FILE gate, and it gets NO completion banner, deliberately.  It ran no
# checks, and a path that announced completion when nothing ran would be a worse
# defect than the one issue 1626 names.  The spelling is test_calc_widgets.tcl's
# `RESULT: SKIP (...)`, which full_audit.sh's is_skip matches and which its
# is_pass therefore refuses — every arm of is_pass that could match this output
# ends in `&& ! is_skip "$out"`, so the skip wins by deferral rather than by
# being tested first (an earlier revision of this sentence said "matches BEFORE
# its is_pass", which is not how those two procs are ordered);
# test_calc_skeleton.tcl's `RESULT: ALL PASS (0 checks)` on the same path is a
# hollow pass that scores PASS having run nothing, and is deliberately not
# copied.  The consequence is intended: this suite is a `dcases` entry and
# nothing else, so T1 never takes this path, and an `hcases` entry would be
# scored a HARNESS failure — the correct answer for a case that measures nothing.
# Row RB6 of tests/headless/test_registered_banner_1626.tcl re-measures that.
if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "RESULT: SKIP (no X: the Calculator buffer behaviour is Tk-only)"
    flush stdout
    exit 0
}

# --- readers that answer rather than throw -----------------------------------
proc bufget {} {
    if {![winfo exists .calc.buf]} { return MISSING }
    return [pcall .calc.buf get 1.0 end-1c]
}
proc btnstate {w} {
    if {![winfo exists $w]} { return MISSING }
    return [pcall $w cget -state]
}
proc nsv {name} {
    if {[info exists ::calc::$name]} { return [set ::calc::$name] }
    return NOVAR
}
# ⚠ a RESTORER, not a creator, copied from test_calc_widgets.tcl for the same
# reason: `set ::calc::fbundo 0` on a tree that has no such variable MINTS it,
# and every later check that reads it then passes on a value this file wrote.
proc nsset {name val} {
    if {[info exists ::calc::$name]} { catch {set ::calc::$name $val} }
}
# ⚠ THE WHOLE OF THE `calc` NAMESPACE'S STATE, ENUMERATED FROM THE NAMESPACE
# ITSELF.  R508's "silent no-op that returns cleanly, and records nothing" has
# two halves, and a band that only checks for a raised error measures one of
# them: a proc with no window guard can write anything it likes and still
# "return cleanly".  That is exactly what calc::buf_note_edit did until
# 2026-09-30 — it set fbundo/fbredo with no window at all — while both R508
# bands stayed green.
#
# The enumeration is `info vars ::calc::*` and NOT a list written out here, for
# the reason CLAUDE.md states as limit L9 and row X1 of
# test_snprintf_fmt_1608.tcl exists for: a hand-kept list of state to watch is
# the same defect one level up, and the variable a later phase adds is precisely
# the one nobody would remember to add.  Arrays are read with `array get` and
# SORTED, because element order is not defined; a declared-but-unset variable is
# recorded as UNSET so that becoming set is a difference.
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
proc ns_count {} { return [llength [info vars ::calc::*]] }
# the variables whose value differs, by BARE name so a failing row stays short;
# `+name` is one that appeared, `-name` one that vanished.
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
# Put the buffer into a known state with an EMPTY edit history, so that an
# enablement check measures this row's own edits and not the previous row's.
# `edit reset` is Tk 8.4+, unlike `edit canundo`.
proc bufset {s} {
    if {![winfo exists .calc.buf]} { return MISSING }
    pcall .calc.buf delete 1.0 end
    if {$s ne {}} { pcall .calc.buf insert end $s }
    pcall .calc.buf edit reset
    pcall .calc.buf mark set insert end-1c
    # the 8.5 fallback cannot read Tk's own stack depth, so it keeps a hint;
    # a fixture that edits the widget behind the Calculator's back has to clear
    # that hint too, or an enablement row measures the PREVIOUS row's edit.  On
    # the 8.6 arm these two writes change nothing, because buf_can reads the
    # widget.  nsset only writes a variable that already exists.
    nsset fbundo 0
    nsset fbredo 0
    pcall calc::buf_sync
    return [bufget]
}
# THE ENGINE'S OWN SPLIT, not a description of it.  plot_raw_custom_data() calls
# my_strtok_r(ntok_ptr, " \t\n", "", 0, &ntok_save): the delimiter set is space,
# tab and newline and the QUOTE SET IS EMPTY, so runs of delimiters collapse and
# nothing is grouped.  Verified by reading that call site in src/save.c, which is
# also what PLAN phase 2's driver note cites.
proc engine_tokens {s} { return [regexp -all -inline {[^ \t\n]+} $s] }
# ...and the C source that call site lives in, located the way
# test_calc_widgets.tcl locates the running calculator.tcl: $XSCHEM_SHAREDIR is
# a Tcl GLOBAL the C core sets (xinit.c), and in-tree it is src/, which is where
# save.c is.  A row asserts this resolved before anything is concluded from it.
# ⚠ a readable spelling of a whitespace set, so a FAILING row stays on ONE
# physical line: printing the raw delimiter string puts a real tab and a real
# newline into the verdict, and the `: FAIL` then lands on a later line than the
# row name it belongs to.
proc wsp_show {s} {
    return [string map [list { } {<sp>} "\t" {<tab>} "\n" {<nl>} "\r" {<cr>}] $s]
}
proc engine_src {} {
    if {[info exists ::XSCHEM_SHAREDIR]} {
        set p [file join $::XSCHEM_SHAREDIR save.c]
        if {[file exists $p]} { return $p }
    }
    return src/save.c
}
# The running calculator.tcl, resolved the same way and for the same reason: a
# textual row must read the file the interpreter actually loaded, not a path that
# happens to exist relative to the cwd.
proc calc_src {} {
    if {[info exists ::XSCHEM_SHAREDIR]} {
        set p [file join $::XSCHEM_SHAREDIR calculator.tcl]
        if {[file exists $p]} { return $p }
    }
    return src/calculator.tcl
}
proc calc_src_text {} {
    set p [calc_src]
    if {[catch {open $p r} f]} { return "CALC-SRC-UNREADABLE:$p" }
    set t [read $f] ; close $f ; return $t
}

# ⚠ ONE MECHANISM FOR FORCING THE 8.5 FALLBACK, AND THESE TWO PROCS ARE IT.
# `.calc.buf` is renamed aside and a proxy installed that raises on exactly the
# two 8.6-only subcommands, with the error Tk 8.5 itself raises, and forwards
# everything else; Tk addresses the widget by its WINDOW rather than by its
# command name, so the widget keeps working.  The probe's cache is cleared here
# too, so the next ask re-measures — that pairing is the whole mechanism and
# splitting it is how a band ends up measuring the 8.6 arm while claiming the
# other.  Two bands below force the fallback (CB2's main one and the
# close/reopen one) and both go through here rather than open-coding it twice.
# Why not simply pin ::calc::editcan to 0: that exercises the fallback ARM but
# proves nothing about the probe, and leaves an unguarded `edit canundo` call
# site anywhere else in the path undetected — the shape CLAUDE.md warns about
# under "a fence keyed to a symptom dies quietly".
proc shadow_install {} {
    if {[string match ERR:* [pcall rename .calc.buf ::cb_real_buf]]} { return 0 }
    proc .calc.buf {args} {
        if {[lindex $args 0] eq {edit} && [lindex $args 1] in {canundo canredo}} {
            return -code error \
                "bad edit option \"[lindex $args 1]\": must be modified, redo, reset, separator, or undo"
        }
        return [uplevel 1 [linsert $args 0 ::cb_real_buf]]
    }
    nsset editcan {}
    return 1
}
proc shadow_remove {} {
    if {![llength [info procs .calc.buf]]} { return 0 }
    pcall rename .calc.buf {}
    pcall rename ::cb_real_buf .calc.buf
    nsset editcan {}
    return 1
}

# EVERY PHASE-2 ENTRY POINT, with arguments, declared ONCE and used by three
# rows: CB4 (no window), CB5 (no `winfo` command at all) and CB5's structural
# row, which reads these same procs' live bodies.  Declaring it once is not
# tidiness: three bands that each kept their own list would disagree the moment
# phase 4 adds a proc, and the band that was not updated would go on passing
# while measuring less.  The list is still hand-kept — CLAUDE.md calls that the
# same defect one level up — so CB5's structural row is what notices a proc in
# the list that reaches for `winfo` itself, and the list's LENGTH rides in both
# behavioural rows' expected values so a silently emptied list cannot pass.
set ph2calls [list \
    {calc::token_sep + a b} \
    {calc::engine_space { }} \
    {calc::edit_can_probe} \
    {calc::buf_can undo} \
    {calc::buf_can redo} \
    {calc::buf_sync} \
    {calc::buf_note_edit} \
    {calc::buf_typed} \
    {calc::buf_insert_token +} \
    {calc::pad_click +} \
    {calc::clr_buf} \
    {calc::buf_undo} \
    {calc::buf_redo}]
# the distinct proc names in it, derived rather than written out again
set ph2procs {}
foreach c $ph2calls {
    set p [lindex $c 0]
    if {[lsearch -exact $ph2procs $p] < 0} { lappend ph2procs $p }
}

if {[catch {

# =============================================================================
# CB1 — PLAN 2.2: a key inserts its token at the caret, whitespace-separated
# =============================================================================
group CB1 {
    check "CB1 fixture: calc::open returns the normative path" [pcall calc::open] .calc
    update idletasks
    check "CB1 fixture: the buffer exists and is a Text" \
        [expr {[winfo exists .calc.buf] ? [winfo class .calc.buf] : {MISSING}}] Text
    check "CB1 fixture: the twelve ruled operator keys (RULING-2)" \
        [pcall calc::pad_keys] {+ - * / ** ? == != > < >= <=}

    # (a) the separator decision as a PURE function of what is either side of the
    #     caret.  A widget row can only show one case at a time; these show the
    #     whole rule, and they are the rows a wrong implementation trips first.
    check "CB1 token_sep: after a non-space character, exactly one leading space" \
        [pcall calc::token_sep + {v(out)} {}] { +}
    check "CB1 token_sep: an EMPTY buffer gets no leading space it does not need" \
        [pcall calc::token_sep + {} {}] {+}
    check "CB1 token_sep: a buffer already ending in a space gets no SECOND one" \
        [pcall calc::token_sep + {v(out) } {}] {+}
    check "CB1 token_sep: text after the caret gets a trailing space too" \
        [pcall calc::token_sep / {v(out)} {v(in)}] { / }
    check "CB1 token_sep: a space already after the caret is not doubled" \
        [pcall calc::token_sep / {v(out)} { v(in)}] { /}
    check "CB1 token_sep: a TAB before and after the caret adds nothing" \
        [pcall calc::token_sep + "v(out)\t" "\tv(in)"] {+}
    check "CB1 token_sep: a NEWLINE before and after the caret adds nothing" \
        [pcall calc::token_sep + "v(out)\n" "\nv(in)"] {+}

    # (a2) ⚠ THE SEPARATOR CLASS IS THE ENGINE'S, AND NOTHING WIDER.  The first
    #      implementation of token_sep asked Tcl's `string is space`, whose class
    #      is a STRICT SUPERSET of `" \t\n"` — it also takes CR, VT, FF, NBSP,
    #      NEL, the Unicode space separators from U+2000 up, the line and
    #      paragraph separators and the zero-width characters — so with any of
    #      those at the caret the separator was SUPPRESSED and
    #      plot_raw_custom_data() saw one fused token, precisely the failure the
    #      separator rule exists to prevent, reintroduced by the proc that
    #      implements it.
    #      ⚠ THE ROWS BELOW DRIVE FIVE REPRESENTATIVE CHARACTERS AND NOT THE
    #      WHOLE CLASS, and their names say so.  The five are CR, VT, FF, NBSP
    #      and EN-SPACE, chosen because they are what real input produces: this
    #      project is used over a Windows X server and a paste from Windows
    #      carries CRs, a form feed arrives from printed or generated text, and
    #      NBSP/EN-SPACE come from anything that has been through a word
    #      processor or a web page.  An earlier revision of the first row's name
    #      read as an enumeration of the whole difference, which it is not.
    #      Two kinds of row below.  First the two copies of the delimiter set are
    #      locked to each other by READING the C call site; then each of the five
    #      characters is driven through the widget on both sides of the caret and
    #      the ENGINE'S OWN SPLIT is asserted — not that "a space appeared",
    #      which is a weaker claim a wrong class can still satisfy.
    set csrc [engine_src]
    check_expr "CB1 fixture: the engine's tokeniser source was located" \
        {[file exists $csrc]}
    set cdelim NOT-FOUND
    if {[file exists $csrc]} {
        set cf [open $csrc r] ; set cbody [read $cf] ; close $cf
        if {[regexp {my_strtok_r\(ntok_ptr,[ \t]*"([^"]*)"} $cbody -> cd]} {
            set cdelim [subst -nocommands -novariables $cd]
        }
    }
    check "CB1 calc::engine_wsp, which token_sep's predicate reads, IS the delimiter string in src/save.c's own my_strtok_r(ntok_ptr, ...) call -- read out of that file, not described" \
        [list [wsp_show $cdelim] [wsp_show [nsv engine_wsp]]] \
        {<sp><tab><nl> <sp><tab><nl>}
    check "CB1 ...and engine_space answers 0 for the EMPTY STRING, 1 for a space and 0 for CR -- the empty-string answer is why token_sep's two emptiness guards are not dead code" \
        [list [pcall calc::engine_space {}] [pcall calc::engine_space { }] \
              [pcall calc::engine_space "\r"]] {0 1 0}

    # ⚠ the loop list is built with [list] and NOT braced: inside braces `\r`
    # would stay two characters and every row below would measure a backslash.
    set wide [list CR \r VT \v FF \f NBSP   EN-SPACE  ]
    # ⚠ FOUR LEGS, so the row's NAME is true of its METHOD: Tcl's class really
    # does accept each character, the engine's really does not, and token_sep
    # writes the separator on each side.  The first two legs used to be a claim
    # in the name with nothing behind it.
    set nowrap {}
    set nch 0
    foreach {nm ch} $wide {
        incr nch
        if {![string is space $ch]} { lappend nowrap "tcl-rejects-$nm" }
        if {[pcall calc::engine_space $ch] ne 0} { lappend nowrap "engine-accepts-$nm" }
        if {[pcall calc::token_sep + "v(out)$ch" {}] ne " +"} { lappend nowrap "pre-$nm" }
        if {[pcall calc::token_sep + {} "${ch}v(in)"] ne "+ "} { lappend nowrap "post-$nm" }
    }
    check "CB1 token_sep: FIVE REPRESENTATIVE characters `string is space` accepts and the engine does not -- a Windows paste's CR, a form feed, VT, NBSP, EN-SPACE -- still get a separator, on both sides of the caret" \
        [list $nch $nowrap] {5 {}}

    set fused84 {}
    set nch 0
    foreach {nm ch} $wide {
        incr nch
        bufset "v(out)$ch"
        pcall .calc.buf mark set insert end-1c
        pcall calc::pad_click +
        set tk1 [engine_tokens [bufget]]
        if {[llength $tk1] != 2 || [lsearch -exact $tk1 +] < 0} {
            lappend fused84 "pre-$nm:[llength $tk1]"
        }
        bufset "${ch}v(in)"
        pcall .calc.buf mark set insert 1.0
        pcall calc::pad_click +
        set tk2 [engine_tokens [bufget]]
        if {[llength $tk2] != 2 || [lsearch -exact $tk2 +] < 0} {
            lappend fused84 "post-$nm:[llength $tk2]"
        }
    }
    check "CB1 the ENGINE splits the buffer into exactly two tokens with the operator standing alone, for each of those five REPRESENTATIVE characters on both sides of the caret" \
        [list $nch $fused84] {5 {}}

    # (b) at the end of the buffer
    bufset {v(out) v(in)}
    pcall .calc.buf mark set insert end-1c
    pcall calc::pad_click /
    check "CB1 a press with the caret at the end appends the token, separated" \
        [bufget] {v(out) v(in) /}

    # (c) AT THE CARET, which is the defect this row exists for: appending to the
    #     end instead passes (b) and fails here.
    bufset {v(out) v(in)}
    pcall .calc.buf mark set insert 1.6
    pcall calc::pad_click /
    check "CB1 a press with the caret MID-TEXT inserts THERE, not at the end" \
        [bufget] {v(out) / v(in)}

    # (d) the caret follows the token, so a second press chains instead of
    #     building the expression backwards
    bufset {v(out) v(in)}
    pcall .calc.buf mark set insert 1.6
    pcall calc::pad_click /
    pcall calc::pad_click {**}
    check "CB1 the caret lands after the token, so a second press chains" \
        [bufget] {v(out) / ** v(in)}

    # (d2) the same chain where BOTH sides of the caret need a separator, which
    #      is the only shape that exercises the trailing one through the widget
    bufset {v(out)v(in)}
    pcall .calc.buf mark set insert 1.6
    pcall calc::pad_click /
    check "CB1 a caret INSIDE a token gets a separator on both sides" \
        [bufget] {v(out) / v(in)}
    pcall calc::pad_click {**}
    check "CB1 ...and a second press still chains from there" \
        [list [bufget] [engine_tokens [bufget]]] \
        [list {v(out) / ** v(in)} {v(out) / ** v(in)}]

    # (e) an empty buffer
    bufset {}
    pcall calc::pad_click +
    check "CB1 an empty buffer does not acquire a leading separator" [bufget] {+}

    # (f) already-trailing whitespace
    bufset {v(out) }
    pcall .calc.buf mark set insert end-1c
    pcall calc::pad_click +
    check "CB1 a buffer already ending in whitespace gets no doubled separator" \
        [bufget] {v(out) +}

    # (g) every one of the twelve, each into the same fixture
    set badkey {}
    set n 1
    foreach tok [pcall calc::pad_keys] {
        bufset {v(out)}
        pcall .calc.buf mark set insert end-1c
        pcall .calc.pad.k$n invoke
        if {[bufget] ne "v(out) $tok"} { lappend badkey k$n=[bufget] }
        incr n
    }
    # ⚠ the key COUNT rides along: with no keypad at all the loop is empty and
    # the offender list is empty, so "every key inserts its token" would be green
    # over the feature's total absence.
    check "CB1 all twelve keys insert their OWN token through the button" \
        [list [expr {$n - 1}] $badkey] {12 {}}

    # (g2) ⚠ A PRESS MUST NOT LEAVE A SELECTION ARMED TO EAT ITSELF ONE
    #      KEYSTROKE LATER.  Tk's own `tk::TextInsert` deletes the selection
    #      before inserting whenever the caret lies inside it (its predicate is
    #      `[llength [$w tag ranges sel]] && [$w compare sel.first <= insert] &&
    #      [$w compare sel.last >= insert]`, factored out as
    #      ::tk::TextCursorInSelection on 8.6).  A keypad press inserts at the
    #      caret and leaves the caret there, so with a selection live at the
    #      caret the press ARMS that deletion and the next character the user
    #      types silently removes text they never asked to remove.  Measured on
    #      Tk 8.6.17 before the fix: `v(out) v(in)` with `v(in)` selected and
    #      the caret at its start became `v(out) + v(in)`, and typing one `X`
    #      then left `v(out) + X`.
    #      ⚠ NOT REPLACING the selection is the right answer under R501 — the
    #      buffer is free text and a press is an insertion at the caret, not a
    #      typed character — so the defect is the ARMED STATE and the row below
    #      asserts the consequence (a keystroke adds one character and deletes
    #      nothing) rather than any particular widget state, which is what keeps
    #      it a fence if Tk ever refactors its predicate again.
    bufset {v(out) v(in)}
    pcall .calc.buf tag remove sel 1.0 end
    pcall .calc.buf tag add sel 1.7 1.12
    pcall .calc.buf mark set insert 1.7
    check "CB1 fixture: a live selection holding the text the two rows below must not lose" \
        [list [pcall .calc.buf tag ranges sel] \
              [pcall .calc.buf get sel.first sel.last]] \
        [list {1.7 1.12} {v(in)}]
    pcall calc::pad_click +
    check "CB1 a press does NOT replace the selection — it inserts at the caret (R501)" \
        [bufget] {v(out) + v(in)}
    set eaten {}
    set ncase 0
    foreach where {1.7 1.12 1.9} {
        incr ncase
        bufset {v(out) v(in)}
        pcall .calc.buf tag remove sel 1.0 end
        pcall .calc.buf tag add sel 1.7 1.12
        pcall .calc.buf mark set insert $where
        pcall calc::pad_click +
        set lpress [string length [bufget]]
        pcall focus -force .calc.buf
        pcall event generate .calc.buf <KeyPress> -keysym X
        pcall event generate .calc.buf <KeyRelease> -keysym X
        update
        set ltype [string length [bufget]]
        if {$ltype != $lpress + 1} { lappend eaten "$where:$lpress->$ltype" }
    }
    # ⚠ the CASE COUNT rides along: an empty loop eats nothing.
    check "CB1 the keystroke after a press ADDS one character and deletes nothing, for a selection starting at, ending at, or spanning the caret" \
        [list $ncase $eaten] {3 {}}
    pcall .calc.buf tag remove sel 1.0 end

    # (h) and the result is what the ENGINE tokenises into the tokens intended.
    #     This is the whole reason the separator exists: `v(out)+` is one token,
    #     looked up as a vector name, and the expression returns -1.
    bufset {v(out)}
    pcall .calc.buf mark set insert end-1c
    pcall calc::pad_click +
    check "CB1 the engine's own tokeniser splits one press into two tokens" \
        [engine_tokens [bufget]] {v(out) +}
    set fused {}
    set n 1
    foreach tok [pcall calc::pad_keys] {
        bufset {v(out) v(in)}
        pcall .calc.buf mark set insert 1.6
        pcall calc::pad_click $tok
        foreach t [engine_tokens [bufget]] {
            if {$t ni [list {v(out)} {v(in)} $tok]} { lappend fused k$n=$t }
        }
        incr n
    }
    check "CB1 no token is a fusion of a name and an operator, over all twelve" \
        [list [expr {$n - 1}] $fused] {12 {}}
}

# =============================================================================
# CB2 — PLAN 2.3: ClrBuf, and the BUFFER HALF of R505
# =============================================================================
# ⚠ THE BUFFER HALF ONLY.  R505 says undo/redo cover buffer edits AND stack
# operations as ONE history; the stack does not exist yet (PLAN phase 4.1) and
# the joined history is PLAN 4.4.  Nothing here should be read as closing R505.
group CB2 {
    # the fresh-window baseline.  test_calc_widgets' CW3 asserts this as initial
    # state; it is repeated here as the FIXTURE every enablement row below is
    # measured against, because "enabled when the history is non-empty" is
    # vacuous if they were enabled all along.
    pcall calc::close
    check "CB2 fixture: a fresh window reopens" [pcall calc::open] .calc
    update idletasks
    check "CB2 fixture: undo/redo start disabled on a fresh window (W22)" \
        [list [btnstate .calc.btb.undo] [btnstate .calc.btb.redo]] {disabled disabled}

    # --- ClrBuf ---------------------------------------------------------------
    bufset {v(out) v(in) /}
    check "CB2 fixture: the pre-clear buffer is real text" [bufget] {v(out) v(in) /}
    pcall calc::clr_buf
    check "CB2 ClrBuf empties the buffer" [bufget] {}
    check "CB2 ClrBuf is ONE undoable step, so one Undo restores the whole text" \
        [list [pcall calc::buf_undo] [bufget]] [list {edit undone} {v(out) v(in) /}]
    bufset {}
    pcall calc::clr_buf
    check "CB2 ClrBuf on an empty buffer leaves it empty and does not throw" \
        [bufget] {}

    # --- enablement, the 8.6 branch (this interpreter) ------------------------
    # ⚠ the second leg is what makes the 8.6 BRANCH a measurement rather than an
    # assumption: it shows this interpreter really has the subcommand, so every
    # enablement row below ran the guarded 8.6 arm and not the fallback.  The
    # fallback arm gets its own band, forced.
    bufset {}
    check "CB2 the capability probe answers 1 here, and `edit canundo` really answers" \
        [list [pcall calc::edit_can_probe] \
              [string is boolean -strict [pcall .calc.buf edit canundo]]] {1 1}
    bufset {v(out)}
    check "CB2 fixture: bufset left an EMPTY edit history" \
        [list [btnstate .calc.btb.undo] [btnstate .calc.btb.redo]] {disabled disabled}
    pcall .calc.buf mark set insert end-1c
    pcall calc::pad_click +
    check "CB2 one keypad press enables Undo and leaves Redo disabled" \
        [list [btnstate .calc.btb.undo] [btnstate .calc.btb.redo]] {normal disabled}
    # ⚠ THIS ROW'S NAME USED TO CLAIM THE MECHANISM (`edit separator`) AND IT
    # DOES NOT TEST IT.  With the history reset immediately before the press, the
    # press is the ONLY entry in it, so one Undo reverses it whether a separator
    # was written or not -- measured: removing both `edit separator` calls from
    # calc::buf_insert_token left this suite at ALL PASS.  The row below is the
    # one that needs them, and this one now claims only what it measures.
    check "CB2 one keypad press undoes in one step" \
        [list [pcall calc::buf_undo] [bufget]] [list {edit undone} {v(out)}]
    check "CB2 at the bottom of the history Undo re-disables and Redo enables" \
        [list [btnstate .calc.btb.undo] [btnstate .calc.btb.redo]] {disabled normal}
    check "CB2 Redo re-applies the press" \
        [list [pcall calc::buf_redo] [bufget]] [list {edit redone} {v(out) +}]
    check "CB2 after the Redo, Undo is enabled again and Redo is spent" \
        [list [btnstate .calc.btb.undo] [btnstate .calc.btb.redo]] {normal disabled}

    # ⚠ THE ROW THE `edit separator` BRACKETING EXISTS FOR, and the one the row
    # above cannot be.  Tk's -autoseparators writes a separator only when the
    # EDIT MODE changes, and typing and a keypad insert are both `insert` mode
    # (tk::TextInsert in Tk's own text.tcl writes a separator only for a compound
    # replace-selection), so WITHOUT the explicit brackets the user's last
    # unseparated edit and the press collapse into ONE undo step -- and one Undo
    # then throws away the expression the user had typed as well as the operator
    # they mis-clicked.  Measured on Tk 8.6.17.  The first leg uses a direct
    # widget insert, which is the same edit mode and is deterministic; the second
    # does it with real synthesised keystrokes.
    bufset {}
    pcall .calc.buf insert end {v(out)}
    pcall .calc.buf mark set insert end-1c
    pcall calc::pad_click +
    check "CB2 a press after an UNSEPARATED edit still undoes alone (`edit separator`)" \
        [list [pcall calc::buf_undo] [bufget]] [list {edit undone} {v(out)}]
    bufset {}
    pcall focus -force .calc.buf
    foreach ks {v o u t} {
        pcall event generate .calc.buf <KeyPress> -keysym $ks
        pcall event generate .calc.buf <KeyRelease> -keysym $ks
    }
    update
    check "CB2 fixture: the typed text that the next row must survive" [bufget] {vout}
    pcall .calc.buf mark set insert end-1c
    pcall calc::pad_click +
    check "CB2 ...and one Undo after a press does not swallow the TYPING with it" \
        [list [pcall calc::buf_undo] [bufget]] [list {edit undone} {vout}]

    bufset {}
    check "CB2 a refused Undo says so rather than throwing" \
        [pcall calc::buf_undo] {nothing to undo}
    check "CB2 a refused Redo says so rather than throwing" \
        [pcall calc::buf_redo] {nothing to redo}

    # RAW TYPING also makes the history non-empty, and R505 says "exactly when",
    # so the buttons must notice it even though R506 does not make it speak
    # (CB3 holds the silence).
    bufset {}
    pcall focus -force .calc.buf
    # ⚠ BOTH HALVES OF THE KEYSTROKE, and the first revision of this row sent
    # only <KeyPress>.  The Text class binding for <KeyPress> does the insert, so
    # the buffer changed and the row's fixture passed -- but the Calculator's
    # sync hangs off <KeyRelease> (the only point at which the insert is already
    # done at the WIDGET level), and `event generate <KeyPress>` does not
    # synthesise a release.  So the row reported "typing does not enable Undo"
    # against code that does, which is the same trap PLAN 6.7 records for clicks:
    # "a synthesised click alone does not reach the handler".
    foreach ks {v o u t} {
        pcall event generate .calc.buf <KeyPress> -keysym $ks
        pcall event generate .calc.buf <KeyRelease> -keysym $ks
    }
    update
    check "CB2 fixture: the synthesised typing really reached the buffer" \
        [bufget] {vout}
    check "CB2 typing enables Undo (R505 is about the HISTORY, not about buttons)" \
        [btnstate .calc.btb.undo] normal

    # --- the 8.6-only subcommands live at ONE site ---------------------------
    # ⚠ STRUCTURAL, and it reads the LIVE proc bodies rather than the file's text,
    # so a copy of the subcommand parked in a comment cannot satisfy it and a
    # second real call site cannot hide from it.  CLAUDE.md targets Tcl/Tk
    # 8.4-8.6 and `edit canundo`/`edit canredo` are 8.6-only; this file's own
    # reachable floor is 8.5, because calc::color uses `dict` (see the FORCED
    # 8.5 band below), so every use must sit behind the one guarded accessor and
    # this row is what notices a second one.
    set canre {edit[ \t]+can(undo|redo)}
    set sites {}
    set nproc 0
    foreach p [lsort [pcall info procs ::calc::*]] {
        if {[string match ERR:* $p]} break
        incr nproc
        set b [pcall info body $p]
        if {[string match ERR:* $b]} continue
        if {[regexp -all $canre $b]} { lappend sites $p }
    }
    # ⚠ the PROC COUNT rides along: `info procs` answering nothing would give an
    # empty site list, and "they appear nowhere else" would be green over a
    # namespace this row never read.
    check "CB2 the 8.6-only subcommands name exactly TWO calc:: proc bodies -- the guarded accessor and the probe that measures them -- and no third" \
        [list [expr {$nproc > 20}] $sites] \
        [list 1 [list ::calc::buf_can ::calc::edit_can_probe]]
    # ...and the two are a guard, not two call sites: the probe's own mention is
    # inside a `catch`, and the accessor consults the probe before reaching for
    # the subcommand.  Read off the LIVE bodies, so a copy parked in a comment
    # elsewhere cannot satisfy either leg.
    check "CB2 the probe catches its own mention, the accessor asks the probe first, and the accessor carries both subcommands" \
        [list [regexp "catch\[^\n\]*$canre" [pcall info body ::calc::edit_can_probe]] \
              [regexp {edit_can_probe} [pcall info body ::calc::buf_can]] \
              [regexp -all $canre [pcall info body ::calc::buf_can]]] {1 1 2}

    # --- FORCED 8.5: the subcommand is really ABSENT --------------------------
    # The mechanism, and the reason it is a shadow rather than a pinned
    # variable, is written at shadow_install near the top of this file; it is
    # one proc because two bands force the fallback and a second open-coded copy
    # is how they would drift apart.  As far as src/calculator.tcl can tell,
    # what follows runs on an interpreter without those two subcommands.
    set shadowed [shadow_install]
    check "CB2/8.5 fixture: the widget command was shadowed" $shadowed 1
    check "CB2/8.5 fixture: the shadow really removes the subcommand" \
        [string match {ERR:bad edit option*} [pcall .calc.buf edit canundo]] 1
    set pre84 [bufget]
    pcall .calc.buf insert end {Z}
    check "CB2/8.5 fixture: everything else still reaches the real widget" \
        [bufget] "${pre84}Z"
    # shadow_install cleared the probe's cache, so this re-measures: an
    # unguarded probe raises here instead of answering 0.
    check "CB2/8.5 the probe measures the shadowed interpreter as 0, without raising" \
        [pcall calc::edit_can_probe] 0
    # ⚠ THE MOST DIRECT STATEMENT OF THE WHOLE GUARD, and the row the plausible
    # 8.6-only implementation fails first: with the subcommand absent, the
    # accessor must still ANSWER rather than raise, and so must the sync that
    # calls it.  `string is boolean -strict` is what separates an answer from the
    # `ERR:bad edit option ...` string pcall hands back.
    check "CB2/8.5 calc::buf_can ANSWERS for both directions instead of raising" \
        [list [string is boolean -strict [pcall calc::buf_can undo]] \
              [string is boolean -strict [pcall calc::buf_can redo]]] {1 1}
    check "CB2/8.5 calc::buf_sync completes without raising" [pcall calc::buf_sync] {}
    set e84 {}
    foreach step {
        {bufset {v(out)}}
        {.calc.buf mark set insert end-1c}
        {calc::pad_click +}
    } { set r [pcall {*}$step] ; if {[string match ERR:* $r]} { lappend e84 $r } }
    check "CB2/8.5 a keypad press still inserts, with the separator" [bufget] {v(out) +}
    check "CB2/8.5 ...and still enables Undo, from the fallback's own history" \
        [list [btnstate .calc.btb.undo] [btnstate .calc.btb.redo]] {normal disabled}
    check "CB2/8.5 Undo still works and is still one step" \
        [list [pcall calc::buf_undo] [bufget]] [list {edit undone} {v(out)}]
    # ⚠ THE UNSAFE DIRECTION, AND IT HAD NO ROW.  calc::buf_can's comment
    # declares that the two hints may say "there is something" when there is
    # not, NEVER THE REVERSE — and every row in this band measured the
    # over-answer.  An UNDER-answering hint disables a live button, which is
    # R505 backwards and is silent: the operation still works when called
    # directly, so a band that only ever calls the procs sees nothing.  The
    # shape each pair below uses is the catcher: assert the BUTTON STATE, then
    # immediately prove the history really was non-empty by performing the
    # operation.  A hint that under-answers reddens the first row of the pair
    # while the second still passes, which is exactly the signature.
    check "CB2/8.5 ...and that undo enables the REDO button, through the hint" \
        [btnstate .calc.btb.redo] normal
    check "CB2/8.5 Redo still works — which is also what proves the row above was not an UNDER-answer" \
        [list [pcall calc::buf_redo] [bufget]] [list {edit redone} {v(out) +}]
    check "CB2/8.5 ...and that redo enables the UNDO button, through the hint" \
        [btnstate .calc.btb.undo] normal
    check "CB2/8.5 ...and an undo really is available, so that was not an under-answer either" \
        [list [pcall calc::buf_undo] [bufget]] [list {edit undone} {v(out)}]
    # ⚠ THE ONE HINT THAT IS SET TO 0 BY AN OPERATION, and the row that says the
    # 0 is EXACT rather than an under-answer: calc::buf_note_edit sets fbredo 0
    # because an edit of our own really does empty Tk's redo stack.  Measured on
    # Tk 8.6.17: `edit canredo` answers 1 straight after an undo and 0 after any
    # further insert.  So here the button must go disabled AND the real widget
    # must agree that there is nothing to redo.
    pcall .calc.buf mark set insert end-1c
    pcall calc::pad_click +
    check "CB2/8.5 an edit after an undo really empties Tk's redo stack, so the redo hint's 0 is exact" \
        [list [btnstate .calc.btb.redo] [pcall calc::buf_redo]] \
        {disabled {nothing to redo}}
    # ClrBuf, same pairing
    bufset {v(out) v(in)}
    pcall calc::clr_buf
    check "CB2/8.5 ClrBuf enables Undo through the fallback's hint" \
        [btnstate .calc.btb.undo] normal
    check "CB2/8.5 ...and the clear really is undoable, so that was not an under-answer" \
        [list [pcall calc::buf_undo] [bufget]] [list {edit undone} {v(out) v(in)}]
    # ⚠ THE TYPING LEG OF THE FALLBACK, WHICH NOTHING MEASURED.  Deleting the
    # whole hint update from calc::buf_typed left every check in this stage
    # green: the 8.6 arm reads the widget and does not need the hint, and this
    # band only ever typed on the 8.6 arm.  On an 8.5 interpreter that leaves a
    # user who has typed an expression with a dead Undo button — R505's
    # "disabled exactly when their history is empty", broken in the
    # under-answering direction.  Both halves of the keystroke are generated,
    # for the reason the 8.6 typing band records.
    bufset {}
    check "CB2/8.5 fixture: bufset left both hints down and both buttons disabled" \
        [list [nsv fbundo] [nsv fbredo] \
              [btnstate .calc.btb.undo] [btnstate .calc.btb.redo]] \
        {0 0 disabled disabled}
    pcall focus -force .calc.buf
    foreach ks {v o u t} {
        pcall event generate .calc.buf <KeyPress> -keysym $ks
        pcall event generate .calc.buf <KeyRelease> -keysym $ks
    }
    update
    check "CB2/8.5 fixture: the synthesised typing reached the buffer through the shadow" \
        [bufget] {vout}
    # ⚠ THIS ROW ASSERTED {normal normal} UNTIL 2026-10-01 AND WAS WRONG ABOUT
    # REDO, in the direction that made the fallback DISAGREE with the branch it
    # stands in for. Measured on the real Tk 8.6.17 with a bare text widget --
    # `edit canredo` goes 1 after an undo and back to **0** after any new edit --
    # so a real edit empties Tk's redo stack, the 8.6 branch therefore reports
    # Redo DISABLED after typing, and a fallback answering `normal` is not a
    # conservative over-answer but a contradiction of the thing it approximates.
    # calc::buf_note_edit had always set fbredo 0 for exactly this reason;
    # calc::buf_typed disagreed with its own sibling. The row now asserts the
    # property worth having -- the two branches AGREE -- rather than a literal
    # pair, so it cannot drift from the 8.6 behaviour it is standing in for.
    check "CB2/8.5 typing raises the UNDO hint and clears the REDO hint, and both buttons then read exactly as the 8.6 branch reads them from Tk's own stack -- a real edit empties the redo stack, so a fallback answering `normal` there would contradict the branch it approximates, not conservatively over-answer it" \
        [list [btnstate .calc.btb.undo] [btnstate .calc.btb.redo]] {normal disabled}
    check "CB2/8.5 ...and the typed text really is undoable, so that was not an over-answer standing in for a measurement" \
        [list [pcall calc::buf_undo] [bufget]] [list {edit undone} {}]
    # ⚠ THE FALLBACK'S DECLARED LIMIT, asserted rather than described.  Without
    # `edit canundo` the depth of Tk's own stack cannot be read, so the fallback
    # answers a CONSERVATIVE hint: it may say "undoable" when the real answer is
    # no, never the reverse.  The contract that makes that safe is that a refused
    # undo REPORTS and CORRECTS the hint, so the user is never left with a button
    # that refuses twice in silence.  Both halves are measured here.
    pcall .calc.buf edit reset
    nsset fbundo 1
    pcall calc::buf_sync
    check "CB2/8.5 fixture: the conservative hint can be enabled with an empty stack" \
        [btnstate .calc.btb.undo] normal
    check "CB2/8.5 a refused Undo reports it instead of throwing" \
        [pcall calc::buf_undo] {nothing to undo}
    # ⚠ THIS ROW'S NAME USED TO SAY "so it refuses once, not forever" AND IT
    # MEASURED ONLY THE REFUSAL ITSELF.  The "not forever" half is the next two
    # rows, and until 2026-09-30 it was FALSE: calc::buf_typed raised both hints
    # on every <KeyRelease> unconditionally, so the first keystroke after the
    # refusal put the button straight back to `normal` — including the release
    # of the very Ctrl+Z that had just been refused, which arrives at
    # <KeyRelease> after <<Undo>> has run.  So the keyboard route undid its own
    # self-correction, Ctrl+Z and the Undo button disagreed about an empty
    # history, and R505's "disabled exactly when their history is empty" was
    # broken on this path.  Name now matches method.
    check "CB2/8.5 ...and SELF-CORRECTS the hint on the refusal itself, so the button goes disabled" \
        [btnstate .calc.btb.undo] disabled
    # ⚠ THE "NOT FOREVER" HALF, WHICH NOTHING MEASURED.  A keystroke that
    # changes no text is not an edit and must not raise the hint; the release of
    # a refused Ctrl+Z is exactly such a keystroke, and so is every arrow key,
    # Home, End and bare modifier.  An arrow key is used here because it is
    # deterministic and needs no modifier state.
    pcall focus -force .calc.buf
    foreach ks {Right Left} {
        pcall event generate .calc.buf <KeyPress> -keysym $ks
        pcall event generate .calc.buf <KeyRelease> -keysym $ks
    }
    update
    check "CB2/8.5 ...and a keystroke that CHANGES NO TEXT leaves that correction standing, so the button refuses once and not forever" \
        [list [bufget] [btnstate .calc.btb.undo]] {{} disabled}
    # ⚠ THE POSITIVE CONTROL FOR THE ROW ABOVE, and it is not optional: a
    # calc::buf_typed that NEVER raised the hints would satisfy that row too.
    foreach ks {x} {
        pcall event generate .calc.buf <KeyPress> -keysym $ks
        pcall event generate .calc.buf <KeyRelease> -keysym $ks
    }
    update
    check "CB2/8.5 ...while a keystroke that really DOES change the text still raises the hint, so the row above is not 'never raise'" \
        [list [bufget] [btnstate .calc.btb.undo]] {x normal}
    # ⚠ AND THE SAME PAIR OVER NON-EMPTY TEXT, WHICH IS NOT A REPETITION.  The
    # comparison calc::buf_typed makes is against the buffer text as of the last
    # calc::buf_sync, and a snapshot that is NEVER TAKEN stays at the empty
    # string — which compares equal to an empty buffer, so the pair above passes
    # against a calc::buf_sync that captures nothing at all.  Measured: deleting
    # the snapshot line from calc::buf_sync left this suite at ALL PASS until
    # these three rows existed, while leaving every real user who has typed
    # something back where D3 started.  Same shape as CLAUDE.md's warning that a
    # fence keyed to one symptom dies quietly.
    bufset {v(out)}
    nsset fbundo 1
    pcall calc::buf_sync
    check "CB2/8.5 fixture: NON-EMPTY text, an empty edit history and the conservative hint up" \
        [list [bufget] [btnstate .calc.btb.undo]] {v(out) normal}
    check "CB2/8.5 ...the refusal self-corrects over non-empty text too" \
        [list [pcall calc::buf_undo] [btnstate .calc.btb.undo]] \
        {{nothing to undo} disabled}
    pcall focus -force .calc.buf
    foreach ks {Right Left} {
        pcall event generate .calc.buf <KeyPress> -keysym $ks
        pcall event generate .calc.buf <KeyRelease> -keysym $ks
    }
    update
    check "CB2/8.5 ...and a keystroke that changes NO TEXT leaves it standing over non-empty text -- the row the empty-buffer pair above cannot be" \
        [list [bufget] [btnstate .calc.btb.undo]] {v(out) disabled}
    check "CB2/8.5 nothing raised anywhere in the band while the subcommand was absent" \
        $e84 {}

    # restore the real widget command before anything else reads it
    shadow_remove
    check "CB2 the shadow is gone: the real widget command is back and answers" \
        [list [pcall info procs .calc.buf] \
              [string is boolean -strict [pcall .calc.buf edit canundo]]] {{} 1}

    # --- R705: the fallback's hints belong to the WINDOW ----------------------
    # ⚠ R508's OWN RATIONALE IS THE CLAUSE HERE, not a borrowed one: "The
    # history is a property of the window: a closed-and-reopened Calculator
    # starts with an empty one, matching R705's 'nothing stale is resurrected'."
    # calc::close already clears statusmsg and statushist for that reason.
    # fbundo and fbredo are state of exactly the same kind — "has this window's
    # buffer got an edit history?" — and close did not clear them, so they
    # crossed a close into a window whose Text widget has an empty undo stack.
    # (R705 by itself is about the current raw and stale vector names; the
    # phrase above is the spec's own gloss of it, written into R508.)
    # ⚠ WHAT THIS IS AND IS NOT, measured rather than assumed: it is LATENT, not
    # reachable from the shipped UI today.  Every proc that calls calc::buf_sync
    # writes the hints first (buf_note_edit, buf_typed, buf_undo, buf_redo), and
    # the two buttons are created `disabled` in calc::build_buf, so nothing in
    # the product reads a stale hint before something overwrites it.  What reads
    # buf_sync cold is a test fixture — both sibling suites do
    # `edit reset` + `calc::buf_sync` to arrange an empty history — and PLAN 4.4,
    # which joins the stack's history to the buffer's and will sync from the
    # stack side.  So the first row below is the fence (the state itself) and the
    # second shows what the stale state does when something syncs cold.
    # ⚠ THREE VARIABLES, NOT TWO. `fbtext` -- buf_typed's "did the text really
    # change" baseline, added by this phase's D3 round -- is window-scoped state
    # of exactly the same kind, and BOTH of its lifecycle lines were unfenced
    # when they shipped: deleting `set fbtext {}` from calc::close, or the `{}`
    # default from its `variable` declaration, each left this suite entirely
    # green. A reopened window would then carry the previous window's buffer text
    # as its baseline, so the first keystroke in the new window compares against
    # text that is not there and the hint does not rise -- R505 backwards, by the
    # same mechanism as the two hints above and one round later.
    # The three are poisoned with DISTINCT sentinels so a failure names which one
    # survived, and the count leg means a fourth such variable cannot be added
    # without this row noticing it is unlisted.
    nsset fbundo 1
    nsset fbredo 1
    nsset fbtext {POISON-fbtext}
    pcall calc::close
    check "CB2 calc::close clears ALL THREE of the fallback's window-scoped variables -- the two history hints and buf_typed's text baseline -- like the message history it already clears (R508: the history is a property of the WINDOW)" \
        [list [nsv fbundo] [nsv fbredo] [nsv fbtext]] {0 0 {}}
    check "CB2 ...and those three are still the whole set that calc::close names, so a fourth is not silently unlisted" \
        [llength [lsearch -all -inline -regexp [pcall info vars ::calc::fb*] {::calc::fb}]] 3
    # ⚠ THE OTHER HALF OF fbtext's LIFECYCLE, AND THIS ROW IS TEXTUAL ON PURPOSE
    # -- declared as such because a row that claims to be behavioural and is not
    # is the worse defect.  `variable fbtext {}`'s DEFAULT is load-bearing: with
    # it removed, a fresh interpreter leaves the variable declared-but-unset, and
    # buf_typed's `ne $fbtext` then RAISES "can't read fbtext" on the first
    # keystroke in a window on the 8.5 fallback, before anything has set it.
    # ⚠ AND THE BEHAVIOURAL ROWS ABOVE CANNOT SEE IT, measured rather than
    # assumed: removing the default leaves this whole suite green at its full
    # count, because by the time this band runs an earlier band's calc::buf_sync
    # has already set the variable, so the suite never observes the fresh-
    # interpreter state the default exists for.  One interpreter per suite is why.
    # A row asserting `info exists` here would prove nothing for the same reason,
    # and one that UNSET the variable first would be red on a correct tree too,
    # since the explicit unset recreates exactly the state the default prevents.
    # So this asserts the declaration, which is what the sabotage removes.
    check "CB2 fbtext's `variable` declaration carries its empty default, read out of the calculator.tcl the interpreter really loaded -- no behavioural row in this suite can observe this (one interpreter per suite: an earlier band has already set the variable)" \
        [list [string match {CALC-SRC-UNREADABLE:*} [calc_src_text]] \
              [regexp {\n[ \t]*variable[ \t]+fbtext[ \t]+\{\}[ \t]*\n} [calc_src_text]]] {0 1}
    check "CB2 fixture: the window really went away and comes back" \
        [list [winfo exists .calc] [pcall calc::open]] {0 .calc}
    update idletasks
    check "CB2 fixture: the reopened window's command was shadowed" [shadow_install] 1
    check "CB2 a cold sync on a REOPENED window leaves both buttons disabled on the 8.5 fallback (R505's \"exactly when their history is empty\")" \
        [list [pcall calc::edit_can_probe] [pcall calc::buf_sync] \
              [btnstate .calc.btb.undo] [btnstate .calc.btb.redo]] \
        {0 {} disabled disabled}
    check "CB2 the reopened window's shadow is gone too" [shadow_remove] 1
}

# ⚠ SAFETY NET FOR THE SHADOW, outside the group that installs it.  CB2's
# restore is the last thing in its body, so if any row above it ABORTED the group
# the proxy proc would still be installed and every group after this would be
# measuring a simulated Tk 8.5 without saying so -- a band written to expose one
# defect silently changing the subject for the rest of the file, which is the
# 1616 shape in a new costume.  This is unreachable on a green run and the row
# inside CB2 is what asserts the normal restore; this only stops a failure in one
# band from contaminating the next two.
if {[llength [info procs .calc.buf]]} {
    puts "note: CB2 aborted inside a shadow band; restoring the real widget command"
    shadow_remove
}

# =============================================================================
# CB3 — PLAN 2.4 / R506: every buffer-changing OPERATION speaks; typing does not
# =============================================================================
group CB3 {
    pcall calc::close
    check "CB3 fixture: a fresh window reopens with an empty history" \
        [list [pcall calc::open] [llength [pcall calc::status_history]]] {.calc 0}
    update idletasks

    bufset {v(out)}
    pcall .calc.buf mark set insert end-1c
    pcall calc::status {}
    pcall calc::pad_click +
    check "CB3 a keypad press writes a status line naming the operator" \
        [nsv statusmsg] {operator + inserted}
    check "CB3 ...and records it (R507's default record 1)" \
        [lindex [pcall calc::status_history] 0] {operator + inserted}
    pcall calc::status {}
    pcall calc::clr_buf
    check "CB3 ClrBuf speaks" [nsv statusmsg] {buffer cleared}
    pcall calc::status {}
    pcall calc::clr_buf
    check "CB3 ClrBuf on an ALREADY EMPTY buffer speaks too, and says which" \
        [nsv statusmsg] {buffer already empty}
    pcall calc::status {}
    pcall calc::buf_undo
    check "CB3 Undo speaks" [nsv statusmsg] {edit undone}
    pcall calc::status {}
    pcall calc::buf_redo
    check "CB3 Redo speaks" [nsv statusmsg] {edit redone}
    pcall calc::status {}
    bufset {}
    pcall calc::buf_undo
    check "CB3 a REFUSED Undo speaks too — silence is a bug (R506)" \
        [nsv statusmsg] {nothing to undo}

    # one operation, one history entry
    pcall calc::close
    pcall calc::open
    update idletasks
    bufset {v(out)}
    pcall .calc.buf mark set insert end-1c
    pcall calc::pad_click +
    pcall calc::pad_click "*"
    pcall calc::clr_buf
    pcall calc::buf_undo
    check "CB3 four operations, four history entries, newest first (R509)" \
        [pcall calc::status_history] \
        {{edit undone} {buffer cleared} {operator * inserted} {operator + inserted}}

    # ⚠ CTRL+Z IS THE SAME OPERATION AS THE UNDO BUTTON, and it used to be
    # routed to calc::buf_typed — the proc documented as never writing a status
    # line.  So the keyboard changed the buffer and said nothing, and the
    # previous status line stayed on screen as a now-FALSE statement about a
    # buffer that had moved underneath it, which is worse than silence.  R506's
    # distinction is operation vs raw text entry, not button vs keyboard, so
    # <<Undo>> and <<Redo>> reach the same two procs the buttons do.  The
    # remaining four editing virtual events (paste, cut, clear-selection,
    # middle-click paste) stay on the silent handler on purpose: they are text
    # entry, there is no Calculator control for any of them, and a line per
    # paste is the R507 cap problem again.
    # ⚠ `break` IS LOAD-BEARING: the widget-level binding runs BEFORE the Text
    # class binding, whose own <<Undo>> script performs `%W edit undo`, so
    # without it Ctrl+Z would undo TWICE.  Measured on Tk 8.6.17: a widget-level
    # script ending in `break` cancels the class binding for that event.  The
    # first row below is what notices if that stops being true.
    pcall calc::close
    pcall calc::open
    update idletasks
    bufset {v(out)}
    pcall .calc.buf mark set insert end-1c
    pcall calc::pad_click +
    pcall calc::pad_click {*}
    check "CB3 fixture: two presses, two undoable steps" [bufget] {v(out) + *}
    pcall calc::status {a sentence about the buffer that an undo makes false}
    pcall focus -force .calc.buf
    pcall event generate .calc.buf <<Undo>>
    update
    check "CB3 <<Undo>> undoes exactly ONE step — Tk's class binding does not fire as well" \
        [bufget] {v(out) +}
    check "CB3 ...and it SPEAKS, so the status line is not left making a false claim (R506)" \
        [nsv statusmsg] {edit undone}
    check "CB3 ...and records it, exactly as the button does (R509)" \
        [lindex [pcall calc::status_history] 0] {edit undone}
    pcall calc::status {}
    pcall event generate .calc.buf <<Redo>>
    update
    check "CB3 <<Redo>> re-applies one step and speaks" \
        [list [bufget] [nsv statusmsg]] [list {v(out) + *} {edit redone}]
    bufset {}
    pcall calc::status {}
    pcall event generate .calc.buf <<Undo>>
    update
    check "CB3 a REFUSED <<Undo>> speaks too, and raises nothing into the event loop" \
        [list [bufget] [nsv statusmsg]] [list {} {nothing to undo}]
    # ...and the classification itself, read off the live bindings, so a fifth
    # event wired to the wrong handler is visible without driving it.
    set evmap {}
    foreach ev {<<Undo>> <<Redo>> <<Paste>> <<Cut>> <<Clear>> <<PasteSelection>>} {
        set b [pcall bind .calc.buf $ev]
        set kind unbound
        if {[regexp {calc::buf_typed} $b]} {
            set kind typing
        } elseif {[regexp {calc::buf_undo|calc::buf_redo} $b]} {
            set kind operation
        }
        lappend evmap $ev=$kind
    }
    check "CB3 the six editing virtual events, classified off their live bindings: undo and redo reach the operation procs that speak, the four text-entry ones reach the silent handler" \
        $evmap [list <<Undo>>=operation <<Redo>>=operation <<Paste>>=typing \
                     <<Cut>>=typing <<Clear>>=typing <<PasteSelection>>=typing]

    # ⚠ RAW TYPING IS SILENT, AND THAT IS THE SPEC'S OWN DISTINCTION.  R506 says
    # "every OPERATION that changes the buffer"; R507 records why the word is not
    # "keystroke" — R413's hover help passes `record 0` because "dragging the
    # pointer across the function list crosses fifty entries in a second, and
    # recording them would spend R509's whole 50-entry cap on tooltips for
    # functions the user never clicked".  A status line per keystroke is the same
    # defect with a faster trigger: typing `v(out) v(in) /` would evict every
    # message the history exists to let the user re-read.  PLAN 2.4's word
    # "mutation" names a BROADER class than the spec's "operation", so the
    # acceptance line built on it ("no silent mutation path remains") demands
    # MORE than R506 does, not less -- it would have a keystroke speak.  The
    # spec wins, and this group therefore measures less than PLAN 2.4 asks for,
    # on purpose.
    pcall calc::close
    pcall calc::open
    update idletasks
    bufset {}
    pcall calc::status {}
    set h0 [llength [pcall calc::status_history]]
    pcall focus -force .calc.buf
    foreach ks {v o u t 1 2} {
        pcall event generate .calc.buf <KeyPress> -keysym $ks
        pcall event generate .calc.buf <KeyRelease> -keysym $ks
    }
    update
    # the fixture FIRST: "nothing was typed" and "typing said nothing" are the
    # same green otherwise, and that is the shape this suite's siblings were
    # bitten by (test_calc_skeleton's S16 recall lesson).
    check "CB3 fixture: the synthesised typing really changed the buffer" \
        [bufget] {vout12}
    check "CB3 RAW TYPING writes no status line" [nsv statusmsg] {}
    check "CB3 RAW TYPING records no history entry (R509's cap is for events)" \
        [llength [pcall calc::status_history]] $h0
}

# =============================================================================
# CB6 — calculator_batch PLAN 3.1: what the ENGINE is handed is the buffer,
#       byte for byte
# =============================================================================
# ⚠ THIS BAND IS HERE AND NOT IN tests/headless/test_calc_engine.tcl BECAUSE IT
# NEEDS THE WIDGET.  That suite is an `hcases` entry and owns `calc::rpn_of_text`
# (the translation, which is the identity in RPN mode and is what PLAN phase 8
# replaces) plus the R508 arm where `calc::rpn_of_buffer` answers {} with no
# window.  What it CANNOT measure is the window read itself, and the read has a
# classic way of being wrong: `.calc.buf get 1.0 end` returns the text widget's
# implicit trailing newline, so the engine would be handed an expression with a
# stray delimiter on the end -- harmless to `my_strtok_r`, and NOT harmless to
# anything later that compares, stores or re-displays the buffer.  Nothing in
# either suite saw that until this band existed; it was found by sabotaging
# `end-1c` to `end` and watching every row stay green.
#
# It runs before CB4 on purpose: CB4 closes the window and leaves it closed.
# =============================================================================
group CB6 {
    check "CB6 fixture: the window is still open" [pcall winfo exists .calc] 1
    check "CB6 calc::rpn_of_buffer exists" \
        [llength [pcall info procs ::calc::rpn_of_buffer]] 1
    foreach {label s} {
        empty           {}
        one-token       {v(ramp)}
        an-expression   {v(out) v(in) - db20()}
        trailing-space  {v(a) v(b) + }
        two-lines       "v(a)\nv(b) +"
    } {
        bufset $s
        check "CB6 what the engine is handed is the buffer, byte for byte ($label)" \
            [pcall calc::rpn_of_buffer] $s
    }
    # ...and it is the WIDGET it reads, not a cached copy: a change made behind
    # the Calculator's back shows up immediately (R705's "every read is live"
    # applied to the buffer).
    bufset {v(a)}
    pcall .calc.buf insert end { v(b) +}
    check "CB6 ...and it reads the WIDGET, so an edit made behind its back is visible at once" \
        [pcall calc::rpn_of_buffer] {v(a) v(b) +}
    # the keypad route and the engine route agree, which is what makes PLAN
    # 2.2's separator rule reach the engine at all: CB1 asserts what the key
    # PUTS in the buffer, this asserts that what is handed on is the same thing.
    bufset {v(out) v(in)}
    pcall calc::pad_click /
    check "CB6 a keypad press's result is what the engine would be handed" \
        [list [bufget] [pcall calc::rpn_of_buffer]] {{v(out) v(in) /} {v(out) v(in) /}}
    bufset {}
}

# =============================================================================
# CB4 — R508: with no window, every phase-2 entry point is a silent no-op
# =============================================================================
# ⚠ CLOSES THE CALCULATOR and leaves it closed; CB5 then needs it closed.
group CB4 {
    pcall calc::close
    check "CB4 fixture: the window is gone" [winfo exists .calc] 0
    # ⚠ THE ONE ENTRY POINT THAT WROTE STATE WITH NO WINDOW, named on its own
    # because it is the defect the sweep below was built to generalise and a
    # named row says which proc when it goes again.  calc::buf_note_edit is in
    # $ph2calls, it arrived with no window guard at all, and it set both
    # fallback hints under every one of R508's three cases — so the band header
    # that said "every phase-2 entry point is a silent no-op" was false for
    # exactly it, and the stale hints it left are item C7's defect arriving by a
    # second route (calc::close clears them; this wrote them back after the
    # close).  The fixture pins the hints to a value neither 0 nor the value the
    # unguarded body writes, so a row that passes cannot be reading its own
    # expectation back.
    nsset fbundo 7
    nsset fbredo 7
    set r_note [pcall calc::buf_note_edit]
    check "CB4 calc::buf_note_edit writes NEITHER fallback hint with no window, and returns cleanly (R508)" \
        [list [nsv fbundo] [nsv fbredo] $r_note] {7 7 {}}
    # ⚠ AND THE SWEEP BELOW RE-PINS THEM TO THAT SENTINEL, which is not
    # tidiness: the unguarded body writes `fbundo 1 ; fbredo 0`, and if the
    # variables already held 1 and 0 when the sweep reached that proc the
    # snapshot diff would be EMPTY and the write axis would pass over the very
    # defect it exists for.  Measured: with the hints left at 0/0 after the row
    # above, CB5's identical sweep went green on the broken tree because CB4's
    # sweep had already left them at the values the proc writes.  A value no
    # phase-2 proc ever writes is what makes "no difference" mean "no write".
    nsset fbundo 7
    nsset fbredo 7
    # ⚠ TWO AXES PER STEP, AND THE SECOND ONE IS NEW.  Before 2026-09-30 this
    # band read one piece of state (statusmsg) once, after the whole loop, so
    # twelve of the thirteen entry points could have written anything at all and
    # both R508 bands would have stayed green.  Each step is now bracketed by a
    # full namespace snapshot.
    set raised {}
    set wrote {}
    set resurrected {}
    set nstep 0
    foreach step $ph2calls {
        incr nstep
        set before [ns_state]
        set r [pcall {*}$step]
        set after [ns_state]
        if {[string match ERR:* $r]} { lappend raised "[lindex $step 0]:$r" }
        set d [ns_diff $before $after]
        if {[llength $d]} { lappend wrote "[lindex $step 0]:$d" }
        if {[winfo exists .calc]} { lappend resurrected [lindex $step 0] }
    }
    # ⚠ the STEP COUNT rides along: an empty loop raises nothing, and the list
    # is shared with CB5 so a proc added to one band cannot be missing from the
    # other.
    # ⚠ `>=` and not an equality against [llength $ph2calls]: computing the same
    # expression on both sides of a `check` is vacuous however the loop behaved
    # (Stage B shipped one row of that shape and had to repair it).  A shrunk or
    # emptied list fails this; a list that GROWS is allowed to, which is what a
    # later phase will do.
    check "CB4 no phase-2 entry point raises with no window -- the CLOSED case, which is the same condition the guard sees as never-built (R508)" \
        [list [expr {$nstep >= 13}] $raised] {1 {}}
    # ⚠ THE WRITE AXIS.  The variable count rides along for the same reason the
    # step count does: `info vars` answering nothing would give an empty diff
    # for every step and "nothing was written" would be green over a namespace
    # this row never read.  `>=` and not an equality, so a later phase's new
    # variable does not falsely redden it.
    check "CB4 ...and none of them WRITES any calc:: namespace variable -- R508 says 'records nothing', which is about state and not only about raising" \
        [list [expr {$nstep >= 13}] [expr {[ns_count] >= 17}] $wrote] {1 1 {}}
    check "CB4 ...and none of them wrote a status line" [nsv statusmsg] {}
    check "CB4 ...and the window was not resurrected by any of them -- checked after EVERY step, not only at the end" \
        [list $resurrected [winfo exists .calc]] {{} 0}
}

# =============================================================================
# CB5 — R508's THIRD case: `--nogui`, where the `winfo` COMMAND does not exist
# =============================================================================
# ⚠ R508 NAMES THREE CASES AND CB4 CAN ONLY REACH TWO.  Its own sentence is
# "with no window — `.calc` not built, already closed, or `--nogui` where
# `winfo` does not exist — it is a silent no-op that returns cleanly".  A guard
# written as a bare `winfo exists .calc.buf` satisfies the first two and THROWS
# `invalid command name "winfo"` on the third, which is the opposite of a silent
# no-op: it takes its caller down.  calc::status has always asked
# `[info commands winfo] eq {}` first, and row S13 of test_calc_skeleton.tcl
# fences exactly that clause for it by renaming ::winfo away; this group does
# the same for the phase-2 entry points, which arrived with the bare guard.
# ⚠ RUNS LAST, and with the window already closed: the rename is global, so
# nothing between the rename and the restore may touch Tk.  No `update` here for
# that reason.
group CB5 {
    check "CB5 fixture: no window, so the only thing under test is the missing command" \
        [winfo exists .calc] 0
    # the same sentinel as CB4's sweep, and for the same reason written there.
    nsset fbundo 7
    nsset fbredo 7
    set renamed [expr {![catch {rename ::winfo ::cb_real_winfo}]}]
    set gone [expr {[info commands winfo] eq {}}]
    set raised {}
    set wrote {}
    set resurrected {}
    set nvars 0
    set nstep 0
    foreach step $ph2calls {
        incr nstep
        set before [ns_state]
        set r [pcall {*}$step]
        set after [ns_state]
        set nvars [ns_count]
        if {[string match ERR:* $r]} { lappend raised "[lindex $step 0]:$r" }
        set d [ns_diff $before $after]
        if {[llength $d]} { lappend wrote "[lindex $step 0]:$d" }
        # ⚠ asked through the command that was RENAMED ASIDE, because `winfo`
        # itself is gone for the length of this loop and that is the point of
        # the band.  Without this leg "the window stayed gone" could only be
        # checked after the restore, i.e. once for thirteen calls.
        if {$renamed && [pcall ::cb_real_winfo exists .calc] eq {1}} {
            lappend resurrected [lindex $step 0]
        }
    }
    if {$renamed} { catch {rename ::cb_real_winfo ::winfo} }
    check "CB5 fixture: the winfo command really was removed for the rows above" \
        [list $renamed $gone] {1 1}
    check "CB5 no phase-2 entry point raises when the `winfo` command does not exist (R508's --nogui case)" \
        [list [expr {$nstep >= 13}] $raised] {1 {}}
    check "CB5 ...and none of them WRITES any calc:: namespace variable on that path either, nor brings the window back" \
        [list [expr {$nstep >= 13}] [expr {$nvars >= 17}] $wrote $resurrected] \
        {1 1 {} {}}
    check "CB5 ...and none of them wrote a status line" [nsv statusmsg] {}
    check "CB5 fixture: the winfo command is back" \
        [expr {[info commands winfo] ne {}}] 1
    # ⚠ STRUCTURAL, over the LIVE proc bodies, AND IN TWO DIRECTIONS.  The
    # absence row below says no phase-2 proc reaches for `winfo` itself; the
    # presence row after it says each one that touches a widget asks the one
    # guarded helper.
    #
    # ⚠ THE ABSENCE ROW ALONE IS VACUOUSLY SATISFIABLE BY THE DEFECT IT CATCHES,
    # which is why the second row exists and why this one's name no longer draws
    # a conclusion it cannot support.  Its old name ended "...so none of them can
    # raise R508's third case on its own" — an inference, and a false one: a proc
    # with NO GUARD WHATSOEVER names no `winfo` either and sails through.  Same
    # vacuity defect as row RB4 in the issue-1626 work, which had it twice.
    set direct {}
    foreach p $ph2procs {
        set b [pcall info body ::$p]
        if {[string match ERR:* $b]} { lappend direct "$p:NO-BODY" ; continue }
        if {[regexp {(^|[^:[:alnum:]_])winfo[ \t\n]} $b]} { lappend direct $p }
    }
    check "CB5 no phase-2 proc's BODY names `winfo`, so none of them carries its own copy of the guard" \
        [list [expr {[llength $ph2procs] >= 12}] $direct] {1 {}}
    # ⚠ THE POSITIVE, and "touches a widget" is DERIVED FROM THE BODY rather
    # than from a list here: a body that names a `.calc` widget path is one that
    # needs the guard, and it must also name calc::has_win.  The second leg pins
    # the exceptions by name, so a guard silently dropped cannot be excused by a
    # body that stopped mentioning widgets too — and if the `.calc` regexp ever
    # matched nothing, every proc would land in `pure` and this row reddens
    # instead of passing over a measurement it did not make.  calc::token_sep
    # and calc::engine_space are the two genuine exceptions: pure string
    # functions, no widget, nothing to guard.
    set unguarded {}
    set pure {}
    foreach p $ph2procs {
        set b [pcall info body ::$p]
        if {[string match ERR:* $b]} { lappend unguarded "$p:NO-BODY" ; continue }
        if {![regexp {\.calc} $b]} { lappend pure $p ; continue }
        if {![regexp {calc::has_win} $b]} { lappend unguarded $p }
    }
    check "CB5 every phase-2 proc whose body names a .calc widget path also names calc::has_win, and the only two that name no widget are the pure string functions" \
        [list $unguarded [lsort $pure]] \
        [list {} [list calc::engine_space calc::token_sep]]
    check "CB5 ...and the helper exists and is the one that asks `info commands winfo`" \
        [list [expr {[llength [pcall info procs ::calc::has_win]] == 1}] \
              [regexp {info commands winfo} [pcall info body ::calc::has_win]]] {1 1}
}

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

## ⚠⚠ THE `OVERALL: ok` SENTINEL IS WHAT T1 CAN SCORE, AND WITHOUT IT THIS SUITE
## COULD NOT BE REGISTERED AT ALL (issue 1626).  `banner_complete` in
## tests/banner_rule.tcl — the ONLY Tcl reader of the rule, and the one
## tests/run_regression.tcl sources — accepts `^OVERALL: ok(...)?$` and NO
## `RESULT: ALL PASS` spelling, while run_suites.sh and full_audit.sh carry their
## own EREs which DO accept it.  So a suite passing standalone is no evidence at
## all that it can be registered: that is exactly how both sibling calculator
## suites gated nothing for a month.  Row RB2 of
## tests/headless/test_registered_banner_1626.tcl says so before the gate does.
##
## ⚠ ADDITIVE, AND `RESULT:` MUST BE THE LAST `RESULT:` LINE — which is a claim
## about being LAST and NOT a claim about following the banner.  `summarize_all`
## in run_regression.tcl publishes a case's last `^RESULT:` line into the verdict
## and run_suites.sh does `grep -E '^RESULT' | tail -1`; both are
## order-independent, because banner_complete is `regexp -line` over the whole
## captured body.  What DOES cost something is a SECOND `RESULT:` line: the
## published check count silently becomes whatever the last one says, with
## `counted_failures` and `skips` both still 0 and no reader reddening — issue
## **1627**, OPEN and unfenced, whose own file carries the dated measurement (it
## was taken on a sibling suite whose total moves, so it is not repeated here).
## This file has TWO exit paths — here and the no-X gate near the top — and each
## prints its verdict INSTEAD of the other, never as well.  A third must do the
## same.  Precedent for the ordering: `wvbs_finish` in
## tests/headless/wvbs_common.tcl.
##
## ⚠ ONLY THE SUCCESS PATH CLAIMS COMPLETION, which is why the failure arm emits
## no `OVERALL: ok`.
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
