## File: tests/headless/test_registered_banner_1626.tcl
##
## EVERY SUITE tests/run_regression.tcl REGISTERS MUST BE SCORABLE BY THE RULE
## THE DRIVER ITSELF USES (issue 1626).
##
## `banner_complete` in tests/banner_rule.tcl is the ONLY Tcl reader of the
## completion-banner rule and the only one run_regression.tcl sources. A suite
## that never emits a line it accepts is scored
##   HARNESS: ... did not complete cleanly (exit=0, OVERALL_ok=0, died=0)
## with every one of its own checks PASSING. Both calculator suites were in that
## state when this file was written: every one of their checks green under
## tests/headless/run_suites.sh and tests/headless/full_audit.sh -- which carry
## their own EREs and DO accept the `RESULT: ALL PASS` spelling -- and
## unregisterable, because the two readers that could see them are the two that
## are not the gate. Issue 1615 cost a red gate at 809c03d1 proving the same
## thing for the `test_wave_sigbrowser*` family. So "it passes standalone" is not
## evidence that a suite can be registered.
## ⚠ AND NOTHING FOUND IN THE TREE CHECKED THE CONVERSE -- stated as the
## negative-existence claim it is, with what was actually looked at, because NO
## ROW RE-MEASURES IT: section K of tests/headless/test_audit_classifier.tcl
## locks the three banner READERS together and never mentions `hcases` or
## `dcases` at all, and row V57 of tests/headless/test_op_annot.tcl asserts that
## its own two entries are listed without asking whether either can be SCORED.
## If a fence over the registered set does exist somewhere, this file is the
## duplicate and that is worth knowing.
##
## WHY NOT section K of tests/headless/test_audit_classifier.tcl, which is where
## the three banner readers are locked together and the obvious home: THAT SUITE
## IS IN NEITHER `hcases` NOR `dcases`. A fence placed there would gate nothing,
## which is issue 1626's own defect one level up. This file is registered in
## `hcases`, so it also checks ITSELF.
##
## THE METHOD, and the row names say it rather than claiming coverage:
##
##   * the suite list is LIFTED FROM run_regression.tcl's own text at runtime.
##     A hand-kept copy here would be the same defect one level up (CLAUDE.md,
##     and row X1 of test_snprintf_fmt_1608.tcl).
##   * the verdict is banner_rule.tcl's OWN `banner_complete`, sourced, never a
##     fourth spelling of the pattern. A copied shape drifts silently; that is
##     the whole of issue 0689.
##   * a suite "emits" the banner when a `puts` to STDOUT OR STDERR has an
##     argument whose RENDERED text banner_complete accepts, following the
##     `source` chain transitively, a command-substitution word, and one level of
##     `set`/`append` assignment.
##     ⚠ WHY BOTH CHANNELS, stated as narrowly as it is true: the two arms whose
##     output `regression_case_failed` ever reads are the `hcases` and `dcases`
##     loops -- the only two call sites of that proc in run_regression.tcl -- and
##     both are exec'd `> $log 2>@1`, so a banner written to stderr lands in the
##     body the predicate reads. It is NOT true of every arm: the `tcases` arm is
##     `eval exec $tccmd > $tcout` with no stderr redirect, and it is scored by
##     golden-file comparison rather than by the banner. An earlier revision of
##     this bullet said "every arm" and was wrong.
##     All the mechanisms the tree actually uses are reached that way, and RB4
##     re-measures every run that a one-file text scan would NOT reach them:
##       - a literal:            puts "OVERALL: ok"             (most suites)
##       - a counted literal:    puts "OVERALL: ok (N checks)"  (test_pdk_launcher)
##       - computed by expr:     puts "OVERALL: [expr ...ok...]" -- the shape SOME
##         registered test_ase_* suites use, NOT all of them. No count here: RB4
##         prints the real set at runtime, and an earlier revision of this bullet
##         said "the 13 test_ase_* suites", whose definite article reads as all
##         the registered `test_ase_*` suites when the shape belongs to only
##         some of them.
##       - from a sourced file:  wvbs_finish in wvbs_common.tcl
##       - from a variable:      tests/hilight_hier_oracle.tcl and two siblings
##     and two idiomatic spellings nothing registered uses TODAY, accepted so
##     that the next crew to write one does not inherit a standing red (this
##     file's own first revision dropped both, and both really do print a line
##     banner_complete accepts -- fixtures a6 and a7):
##       - a command substitution: puts [format "OVERALL: ok (%d checks)" $n]
##       - assembled by append:    set b "OVERALL:" ; append b " ok" ; puts $b
##
## NAMED LIMITS, because a text predicate that claims more than it does is worse
## than none (and RB3 is the control battery that stops this file going green by
## answering "accepted" to everything):
##
## ⚠ THE LIMITS RUN IN BOTH DIRECTIONS AND THE TWO DIRECTIONS COST DIFFERENT
## THINGS. Most of what follows is generosity in the ACCEPTING direction, where
## the cost is a defect this file fails to notice and T1's own `HARNESS:` line
## reports instead. But **L2 and L4 are REJECTING-direction limits**: a suite
## that genuinely prints a line `banner_complete` accepts is reported by RB2 as
## having no emitter, so RB2 FAILS and the fence becomes the standing red in T1
## that L1's own rationale says must never happen. Measured, built and run rather
## than reasoned: a banner spelled `puts [format "OVERALL: ok (%d checks)" \`
## + continuation + `$n]` really prints `OVERALL: ok (7 checks)` under `tclsh`
## and the predicate answers "no emitter" (L4); so does a `puts $summary` whose
## `$summary` is assigned in a sourced file (L2). Neither shape is used by any
## registered suite today, which is the only reason the fence is green -- not a
## property of the predicate. **Anyone who hits one of these has found a fence
## defect, not a suite defect**, and the fix is to widen the predicate, never to
## re-spell the suite.
##
##   L1  a substitution renders as the word `ok`, so `puts "OVERALL: $v"` is
##       ACCEPTED without anyone knowing what $v holds. Conservative in the
##       accepting direction on purpose: the alternative is evaluating suite
##       source, and a false red here is a standing red in T1.
##   L2  ⚠ REJECTING DIRECTION -- see the warning above. Variable resolution is
##       ONE level and same-file, over `set` and `append`. The candidates are
##       each quoted literal on those lines and their in-order concatenation.
##       `puts $v` where $v is assigned in a SOURCED FILE, or from another
##       variable, is not followed -- so such a suite is REPORTED AS NO EMITTER
##       while really printing an acceptable line. Note the asymmetry with the
##       source chain: a `puts` of a LITERAL in a sourced file IS found
##       (rb_source_closure, fixture for RB3b), a `puts` of a VARIABLE assigned
##       there is not.
##   L3  a `puts` whose CHANNEL word is a variable is treated as a write to that
##       channel and ignored, so `puts $fd "OVERALL: ok"` is not an emitter --
##       correct, since it does not reach the log -- AND IT STAYS REJECTED EVEN
##       WHEN $fd HOLDS stdout OR stderr, which the predicate cannot know. A
##       literal `stdout` or `stderr` channel word IS followed (fixture a8);
##       only the variable spelling is dropped. ⚠ A ONE-ARGUMENT `puts $v` IS A
##       MESSAGE AND NOT A CHANNEL whatever follows it on the line: the channel
##       arm requires another word after the candidate, and the command is first
##       truncated at its own terminating semicolon. Before stage A3 it did not,
##       so `puts $v ` with trailing whitespace -- and, worse, the everyday
##       `puts $v ;# comment`, which rb_decomment leaves as `puts $v ;` -- were
##       both eaten as channel words and reported as no emitter at all. No
##       registered suite was affected, which is exactly why it had to be
##       fixed rather than left to be discovered by a false red. Fixtures a9
##       and a10.
##   L4  ⚠ REJECTING DIRECTION -- see the warning above. The scan is
##       line-oriented, so a `puts` split across a continuation line, or a banner
##       assembled from two `puts -nonewline` calls, is REPORTED AS NO EMITTER
##       even though the suite really prints an acceptable line. "Missed" would
##       be the wrong word and an earlier revision used it: this does not fail to
##       notice a defect, it MANUFACTURES one.
##   L5  dead code is not detected: a `puts` of the banner inside an `if 0`
##       block, or in a proc nothing calls, is accepted. RB2 answers "could this
##       suite ever emit it", not "does this run emit it". The run-level answer
##       is T1 itself, which is what this file exists to let T1 give.
##   L6  ⚠ RB2 IS ARM-BLIND. It unions `hcases` and `dcases` and asks one
##       question of a suite's whole text, so it cannot say that a banner is
##       reachable on the HEADLESS arm and unreachable on the display one, or
##       the reverse. A fully general answer needs per-arm reachability
##       analysis, which L5 says this file does not do and which it deliberately
##       does not attempt: the cost of guessing wrong in the rejecting direction
##       is a standing red in T1. What IS fenced is the one arm-dependent shape
##       that can be read off the text -- the whole-file no-X early exit both
##       Calculator suites use -- and RB6 asserts no `hcases` entry has it. A
##       suite made unreachable-on-headless by any OTHER means (a `return` at
##       file scope, a gate spelled some third way, a banner inside a proc only
##       the display arm calls) is NOT detected, and T1's own HARNESS line is
##       still the backstop. RB6's controls say which shape it reads.
##       ⚠ WITHIN that one shape the question is answered by the SAME machinery
##       as the whole-file question: a banner reached from the gate body through
##       a proc call or a sourced file counts as reachable (rb_frag_emitters).
##       Before stage A3 the gate body was scanned as plain text, which is a
##       FALSE RED in the rejecting direction the moment anyone factors a gate's
##       banner into a helper -- measured on a real suite, fixture g5.
##   L7  ⚠ A COMMAND-SUBSTITUTION WORD IS JUDGED PER QUOTED LITERAL, AND THAT IS
##       DELIBERATELY TOO GENEROUS. `puts [format "OVERALL: ok (%d checks)" $n]`
##       is accepted because one of the bracket body's literals renders to a
##       line banner_complete accepts; so is
##       `puts [concat "ok: note" "OVERALL: ok"]`, whose printed line is
##       `ok: note OVERALL: ok`, which banner_complete REJECTS. Measured.
##       Judging the bracket body as a whole would need the command's semantics
##       -- `format`, `concat`, `join`, `string cat` and `subst` all compose
##       their arguments differently -- so the rule is L1's rule one level in:
##       look at the text the spelling carries. The error is in the ACCEPTING
##       direction, which costs a missed defect that T1's own HARNESS line still
##       catches on the next run, where the rejecting direction would cost a
##       standing red in T1. That is why it is not narrowed.
##
## AUTHORING CONSTRAINT, inherited from test_audit_classifier.tcl's section K:
## no check NAME and no printed value below may carry the banner or death text
## at column 0 of this suite's own stdout, or this suite forges its own verdict.
## Fixture bodies are therefore composed from $RB_OK and friends and are never
## printed.
##
## ⚠ NO LITERAL BRACE MAY APPEAR IN A COMMENT INSIDE A PROC BODY in this file.
## Tcl's brace counter reads comments, so one unbalanced brace in a comment
## aborts the parse of the whole proc -- measured while writing this file.
##
## Standalone (armed):  tests/headless/run_suites.sh --nogui test_registered_banner_1626
## Bare:  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_registered_banner_1626.tcl

source [file join [file dirname [info script]] scratch.tcl]
source [file join [file dirname [info script]] .. banner_rule.tcl]

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
set scratch [test_scratch regbanner]

set npass 0 ; set fail 0
proc check {name got want} {
  global npass fail
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}
## Error-guarded call: a predicate bug must be a FAILED CHECK with a legible
## value, never a throw that hits a file-scope catch and deletes every row
## behind it (the trap issue 1616 measured, and this file's rows are few enough
## that losing one loses a lot).
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
## one line, for a value that goes in a check message
proc flat {s} { return [string map [list \n { } \r { } \t { }] $s] }

# ---------------------------------------------------------------------------
# rb_* : the predicate. Comments here carry no literal braces -- see the header.
# ---------------------------------------------------------------------------

proc rb_slurp {p} { if {[catch {open $p r} f]} { return {} } ; set t [read $f] ; close $f ; return $t }

## A TRAILING Tcl comment, removed. Dropping whole-line comments is not enough:
## a complete puts statement parked in a tail comment is read as code by any
## line scanner -- reject fixtures r1 and r2 are the two spellings, and they are
## what this proc is held to.
## A hash opens a comment only in command position, so the test is that the
## previous non-blank character is a semicolon or an open brace and that we are
## not inside a double-quoted word.
proc rb_decomment {ln} {
  set n [string length $ln]
  set q 0
  set ob [format %c 123]
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

## code lines only: a whole-line comment is not code, and a tail comment is cut
proc rb_code {txt} {
  set out {}
  foreach ln [split $txt \n] {
    if {[regexp {^[ \t]*#} $ln]} continue
    lappend out [rb_decomment $ln]
  }
  return $out
}

## the quoted entries of the driver's own "set <name> [list ...]" construct
proc rb_list_items {txt name} {
  set i [string first "set $name \[list" $txt]
  if {$i < 0} { return {} }
  set j [string first "\]" $txt $i]
  if {$j < 0} { return {} }
  set out {}
  foreach m [regexp -all -inline {"[^"]*"} [string range $txt $i $j]] { lappend out [string trim $m \"] }
  return $out
}

## balanced body of a GROUP-quoted word starting at index 0 of $s -- braces for
## a brace-quoted word, square brackets for a command substitution; the marker
## RBNONE when the word is not closed on this line
proc rb_group_body {s op cl} {
  set depth 0
  set n [string length $s]
  for {set i 0} {$i < $n} {incr i} {
    set c [string index $s $i]
    if {$c eq "\\"} { incr i ; continue }
    if {$c eq $op} { incr depth ; continue }
    if {$c eq $cl} {
      incr depth -1
      if {$depth == 0} { return [string range $s 1 [expr {$i-1}]] }
    }
  }
  return RBNONE
}
proc rb_brace_body {s} { return [rb_group_body $s [format %c 123] [format %c 125]] }

## Every quoted literal word in a string, in textual order -- double-quoted and
## brace-quoted. Used for the two mechanisms that hide the sentinel inside
## something larger: a command-substitution word, and a variable assembled by
## `set` plus `append`.
proc rb_word_literals {s} {
  set out {}
  foreach m [regexp -all -inline {"(?:[^"\\]|\\.)*"} $s] { lappend out [string range $m 1 end-1] }
  foreach m [regexp -all -inline {\{[^{}]*\}} $s] { lappend out [string range $m 1 end-1] }
  return $out
}

## A code fragment truncated at its first COMMAND-TERMINATING semicolon -- one
## outside quotes, braces and brackets. A Tcl line may carry several commands,
## and rb_decomment leaves a bare terminator behind when it cuts a tail comment,
## so what follows the semicolon is never an argument of the command that
## precedes it. Without this, `puts $v ;# note` parses as a write to the channel
## $v with the message `;`, i.e. as no emitter at all.
proc rb_upto_semi {s} {
  set ob [format %c 123] ; set cb [format %c 125]
  set os [format %c 91]  ; set cs [format %c 93]
  set q 0 ; set d 0
  set n [string length $s]
  for {set i 0} {$i < $n} {incr i} {
    set c [string index $s $i]
    if {$c eq "\\"} { incr i ; continue }
    if {$c eq "\""} { set q [expr {!$q}] ; continue }
    if {$q} continue
    if {$c eq $ob || $c eq $os} { incr d ; continue }
    if {$c eq $cb || $c eq $cs} { incr d -1 ; continue }
    if {$d <= 0 && $c eq ";"} { return [string range $s 0 [expr {$i-1}]] }
  }
  return $s
}

## Every message word of a puts command on this code line, as a triple:
## the channel variable named before it or empty for stdout or stderr, the kind
## (lit, cmd or var), and the text.
##   lit  a quoted or brace-quoted word, text = the word
##   cmd  a command-substitution word, text = the bracket body (its quoted
##        literals are what the caller tests -- see rb_emitters)
##   var  a one-argument puts of a bare variable, text = the variable name
proc rb_puts_args {ln} {
  set out {}
  ## command position: line start, blank, semicolon, open brace, open bracket --
  ## the last two spelled by char code, never as literals, see the header
  set cmdpre "\n \t;[format %c 123][format %c 91]"
  set i 0
  while {1} {
    set k [string first "puts" $ln $i]
    if {$k < 0} break
    set i [expr {$k + 4}]
    set pre [expr {$k == 0 ? "\n" : [string index $ln [expr {$k-1}]]}]
    if {[string first $pre $cmdpre] < 0} continue
    set rest [rb_upto_semi [string range $ln $i end]]
    if {![regexp {^[ \t]} $rest]} continue
    set chan {}
    ## A candidate channel word is consumed ONLY when ANOTHER word follows it:
    ## the last word of a puts is its MESSAGE, never its channel, so a
    ## one-argument `puts $v` stays a message however much whitespace trails it
    ## (limit L3, fixtures a9 and a10).
    while {[regexp {^[ \t]+(-nonewline|stdout|stderr|\$[A-Za-z_:][A-Za-z0-9_:]*)[ \t]+[^ \t]} $rest -> w]} {
      if {[string index $w 0] eq "\$"} { set chan $w }
      regsub {^[ \t]+(-nonewline|stdout|stderr|\$[A-Za-z_:][A-Za-z0-9_:]*)} $rest {} rest
    }
    set rest [string trimleft $rest " \t"]
    set d [string index $rest 0]
    set lit RBNONE
    set kind lit
    if {$d eq "\""} {
      if {![regexp {^"((?:[^"\\]|\\.)*)"} $rest -> lit]} { set lit RBNONE }
    } elseif {$d eq [format %c 123]} {
      set lit [rb_brace_body $rest]
    } elseif {$d eq [format %c 91]} {
      ## a command-substitution word: the value is unknown, so the conservative
      ## answer is the one L1 already gives a substitution -- look at the text
      ## the spelling carries. `puts [format "OVERALL: ok (%d checks)" $n]`
      ## really does print a line banner_complete accepts and was dropped
      ## outright before issue 1626 stage A2.
      set lit [rb_group_body $rest [format %c 91] [format %c 93]]
      set kind cmd
    } elseif {[regexp {^\$([A-Za-z_:][A-Za-z0-9_:]*)[ \t]*$} $rest -> v]} {
      ## a one-argument puts of a bare variable: that is the MESSAGE, never a
      ## channel, so it reaches stdout
      set lit $v ; set kind var
    }
    if {$lit eq {RBNONE}} continue
    lappend out [list $chan $kind $lit]
  }
  return $out
}

## The text a word would PRINT, with every substitution -- a dollar variable or
## a bracketed command -- standing in as the word ok (limit L1). A banner whose
## only spelling is a failure one is therefore still rejected, because the
## rendered text is then not the ok sentinel.
proc rb_render {lit} {
  set s $lit
  while {[regsub {\[[^][]*\]} $s {ok} s]} { }
  regsub -all {\$\{[^\}]*\}} $s {ok} s
  regsub -all {\$[A-Za-z_:][A-Za-z0-9_:]*(\([^)]*\))?} $s {ok} s
  return [string map [list \\n \n \\t \t] $s]
}

## ONE LEVEL of constant propagation, same file, `set` AND `append`, and no more
## (limit L2). Three registered suites build the sentinel into a variable and
## print the variable -- tests/hilight_hier_oracle.tcl and its two siblings --
## so a predicate that reads only the literal word of a puts reports those three
## as defects. A banner assembled ACROSS an append is in no single literal, so
## the candidate set is every literal on those lines AND their in-order
## concatenation.
proc rb_var_literals {txt v} {
  set out {} ; set cat {}
  foreach ln [rb_code $txt] {
    if {![regexp "(^|\[ \t;\])(set|append)\[ \t\]+$v\[ \t\]" $ln]} continue
    foreach l [rb_word_literals $ln] { lappend out $l ; append cat $l }
  }
  if {$cat ne {} && [lsearch -exact $out $cat] < 0} { lappend out $cat }
  return $out
}

## every .tcl file a source command on a code line names, resolved against the
## sourcing file's own directory first and then the tree
proc rb_sourced {path txt repo} {
  set out {}
  foreach ln [rb_code $txt] {
    set flat [string map [list [format %c 123] { } [format %c 91] { } {;} { }] $ln]
    if {![regexp {(^|[ \t])source[ \t]} $flat]} continue
    foreach tok [regexp -all -inline {[A-Za-z0-9_.][A-Za-z0-9_./-]*\.tcl} $ln] {
      foreach cand [list [file join [file dirname $path] $tok] \
                         [file join $repo tests headless $tok] \
                         [file join $repo tests $tok] \
                         [file join $repo src $tok] \
                         [file join $repo $tok]] {
        set cand [file normalize $cand]
        if {[file isfile $cand]} { lappend out $cand ; break }
      }
    }
  }
  return [lsort -unique $out]
}

## The driver spells an entry either as headless/<name>, a file under
## tests/headless, or as a bare <name>, a file in tests -- and it resolves BOTH
## the same way, by launching `--script ${hc}.tcl` with its cwd in tests/. So
## there is nothing to special-case: this is the driver's own construction, and
## it is the only spelling that survives a nested entry. A census regex that
## requires the headless prefix reports the four bare-name entries as
## registered-with-no-file, which is the regex's bug and not a defect
## (CLAUDE.md, Harness rules). Fenced by RB1b.
proc rb_suite_path {repo e} { return [file join $repo tests $e.tcl] }

## Every emitter of a line banner_complete accepts on the code lines of ONE
## text, labelled $label, with $vtxt as the text whose variable assignments may
## be consulted. Each hit is a triple: label, mechanism, text. Taken apart from
## rb_emitters so the same scan can be aimed at a FRAGMENT -- RB6 aims it at the
## body of a no-X early-exit gate.
proc rb_scan_text {label txt vtxt} {
  set hits {}
  foreach ln [rb_code $txt] {
    foreach pa [rb_puts_args $ln] {
      set chan [lindex $pa 0] ; set kind [lindex $pa 1] ; set lit [lindex $pa 2]
      if {$chan ne {}} continue
      if {$kind eq {lit}} {
        if {[banner_complete [rb_render $lit]]} { lappend hits [list $label literal $lit] }
      } elseif {$kind eq {cmd}} {
        foreach l [rb_word_literals $lit] {
          if {[banner_complete [rb_render $l]]} { lappend hits [list $label command $l] }
        }
      } else {
        foreach l [rb_var_literals $vtxt $lit] {
          if {[banner_complete [rb_render $l]]} { lappend hits [list $label variable $lit] }
        }
      }
    }
  }
  return $hits
}

## Every reachable emitter of a line banner_complete accepts, following the
## source chain transitively. Each hit is a triple: file, mechanism, text.
proc rb_emitters {repo path} {
  set seen {} ; set todo [list [file normalize $path]] ; set hits {}
  while {[llength $todo]} {
    set p [lindex $todo 0] ; set todo [lrange $todo 1 end]
    if {[lsearch -exact $seen $p] >= 0} continue
    lappend seen $p
    set txt [rb_slurp $p]
    if {$txt eq {}} continue
    foreach h [rb_scan_text [file tail $p] $txt $txt] { lappend hits $h }
    foreach s [rb_sourced $p $txt $repo] { lappend todo $s }
  }
  return $hits
}

## EVERY `proc` DEFINED in one text, as a flat name/body list, the body taken by
## brace balance so a definition spanning lines comes back whole.
##
## Needed because the WHOLE-FILE question gets proc bodies for free -- they are
## lines of the file rb_emitters walks -- and the FRAGMENT question does not: a
## gate body that calls a helper carries only the call.
proc rb_proc_defs {txt} {
  set ob [format %c 123] ; set cb [format %c 125]
  set out {}
  set code [join [rb_code $txt] \n]
  set i 0
  while {1} {
    set k [string first "proc " $code $i]
    if {$k < 0} break
    set i [expr {$k + 5}]
    if {$k > 0} {
      set p [string index $code [expr {$k-1}]]
      if {[string first $p "\n \t;$ob"] < 0} continue
    }
    set rest [string range $code $i end]
    if {![regexp {^[ \t]*([^ \t]+)} $rest -> nm]} continue
    regsub {^[ \t]*[^ \t]+[ \t]*} $rest {} rest
    ## the ARGUMENT list, which may be a brace-quoted group or a bare word
    if {[string index $rest 0] eq $ob} {
      set a [rb_group_body $rest $ob $cb]
      if {$a eq {RBNONE}} continue
      set rest [string range $rest [expr {[string length $a] + 2}] end]
    } else {
      regsub {^[^ \t]*[ \t]*} $rest {} rest
    }
    set b [string first $ob $rest]
    if {$b < 0} continue
    set body [rb_group_body [string range $rest $b end] $ob $cb]
    if {$body eq {RBNONE}} continue
    lappend out $nm $body
  }
  return $out
}

## The COMMAND WORDS of a code fragment: the first word of each line and the
## first word after each semicolon, open brace or open bracket, skipping the
## inside of a double-quoted word.
##
## Used to ask which procs a fragment CALLS. A regexp over the proc's own name
## would have to escape whatever metacharacters the name carries, and a plain
## substring search would read a word inside a message string as a call.
proc rb_cmd_words {frag} {
  set ob [format %c 123] ; set cb [format %c 125]
  set os [format %c 91]  ; set cs [format %c 93]
  set stop " \t;$ob$cb$os$cs\""
  set out {}
  foreach ln [split $frag \n] {
    set n [string length $ln]
    set want 1 ; set q 0
    for {set i 0} {$i < $n} {incr i} {
      set c [string index $ln $i]
      if {$c eq "\\"} { incr i ; continue }
      if {$c eq "\""} { set q [expr {!$q}] ; set want 0 ; continue }
      if {$q} continue
      if {$c eq ";" || $c eq $ob || $c eq $os} { set want 1 ; continue }
      if {$c eq $cb || $c eq $cs} continue
      if {[string first $c " \t"] >= 0} continue
      if {!$want} continue
      set j $i
      while {$j < $n && [string first [string index $ln $j] $stop] < 0} { incr j }
      if {$j > $i} { lappend out [string range $ln $i [expr {$j-1}]] }
      set want 0
      set i [expr {$j-1}]
    }
  }
  return [lsort -unique $out]
}

## Every .tcl file reachable through $path's `source` chain, transitively,
## excluding $path itself.
proc rb_source_closure {repo path} {
  set seen {} ; set todo [list [file normalize $path]] ; set out {}
  while {[llength $todo]} {
    set p [lindex $todo 0] ; set todo [lrange $todo 1 end]
    if {[lsearch -exact $seen $p] >= 0} continue
    lappend seen $p
    set txt [rb_slurp $p]
    if {$txt eq {}} continue
    foreach s [rb_sourced $p $txt $repo] { lappend todo $s ; lappend out $s }
  }
  return [lsort -unique $out]
}

## Every emitter of a line banner_complete accepts that is REACHABLE FROM A
## FRAGMENT of $path's code, by the SAME machinery rb_emitters uses for a whole
## file: the fragment's own puts commands, every file it `source`s, and --
## transitively -- the body of every proc it calls that is defined in this file
## or anywhere on its source chain.
##
## ⚠ WHY THIS IS NOT rb_scan_text. rb_emitters reads proc bodies for free; a
## fragment carries only the CALL. A fragment scan that stops at the text answers
## "unreachable" for a gate whose banner was factored into a helper, which is a
## FALSE RED in the REJECTING direction -- a standing red in T1 waiting for
## someone to refactor a gate body, and the one thing CLAUDE.md says a fence must
## never become. MEASURED exactly that way, issue 1626 stage A3: the real suite
## test_headless_guards_xarm_1492, with its gate's inline banner replaced by a
## one-line helper proc plus a call, was run headless and printed the banner --
## banner_complete 1, regression_case_failed 0 -- and the text-only predicate
## flagged it anyway. Fixture g5 is that counterexample, g6 the sourced-common
## variant, and g7 the anti-overshoot: a gate that calls a proc printing no
## banner must STILL be flagged, so "it calls something" is not enough.
proc rb_frag_emitters {repo path frag} {
  set txt [rb_slurp $path]
  set defs [rb_proc_defs $txt]
  set vtxt $txt
  foreach s [rb_source_closure $repo $path] {
    set st [rb_slurp $s]
    if {$st eq {}} continue
    foreach {n b} [rb_proc_defs $st] { lappend defs $n $b }
    append vtxt \n $st
  }
  set hits {} ; set todo [list $frag] ; set done {}
  while {[llength $todo]} {
    set f [lindex $todo 0] ; set todo [lrange $todo 1 end]
    foreach h [rb_scan_text gate $f $vtxt] { lappend hits $h }
    foreach s [rb_sourced $path $f $repo] {
      foreach h [rb_emitters $repo $s] { lappend hits $h }
    }
    set words [rb_cmd_words $f]
    foreach {n b} $defs {
      if {[lsearch -exact $done $n] >= 0} continue
      if {[lsearch -exact $words $n] < 0 && [lsearch -exact $words [string trimleft $n :]] < 0} continue
      lappend done $n
      lappend todo $b
    }
  }
  return $hits
}

## THE WHOLE-FILE no-X EARLY EXIT, which is the ONLY thing about per-arm
## reachability this file reads off a suite's text (limit L6). Both Calculator
## suites open with an unconditional file-scope
##   if ... the ABSENCE of a display ... then print something, flush, exit
## so under --nogui they leave before the verdict block and no banner is
## reachable on that arm however good the verdict block is. Returns the gate's
## BODY, so the caller can ask whether a banner is reachable INSIDE it -- a gate
## that prints one before exiting is perfectly scorable, and
## test_headless_guards_xarm_1492 is the in-tree example that it must not flag.
## The condition must test for the ABSENCE of a display: the positive sense
## guards a display-only band, which is a per-row skip and harmless. The body
## must `exit`, which is what separates a whole-file gate from such a band.
proc rb_nogui_gate {txt} {
  set lines [rb_code $txt]
  set n [llength $lines]
  set ob [format %c 123] ; set cb [format %c 125]
  for {set i 0} {$i < $n} {incr i} {
    set l [lindex $lines $i]
    if {![regexp "(^|\[ \t;\])if\[ \t\]*$ob" $l]} continue
    if {![regexp {!\[info exists (::)?has_x\]|!\$::has_x|!\$has_x} $l] &&
        ![regexp {\[info commands (::)?winfo\][ \t]*eq} $l]} continue
    set acc {} ; set depth 0 ; set seen 0
    for {set j $i} {$j < $n} {incr j} {
      set lj [lindex $lines $j]
      lappend acc $lj
      set lk [string length $lj]
      for {set c 0} {$c < $lk} {incr c} {
        set ch [string index $lj $c]
        if {$ch eq "\\"} { incr c ; continue }
        if {$ch eq $ob} { incr depth ; set seen 1 } elseif {$ch eq $cb} { incr depth -1 }
      }
      if {$seen && $depth <= 0} break
    }
    set st [join $acc \n]
    set k [string first $ob $st]
    if {$k < 0} continue
    set cond [rb_group_body [string range $st $k end] $ob $cb]
    if {$cond eq {RBNONE}} continue
    set rest [string range $st [expr {$k + [string length $cond] + 2}] end]
    set k2 [string first $ob $rest]
    if {$k2 < 0} continue
    set body [rb_group_body [string range $rest $k2 end] $ob $cb]
    if {$body eq {RBNONE}} continue
    if {![regexp "(^|\[ \t;\n\])exit(\[ \t\n\]|\$)" $body]} continue
    return $body
  }
  return {}
}

## 1 when this suite's --nogui arm cannot reach a banner AT ALL, by the one
## shape rb_nogui_gate reads. Deliberately narrow: see limit L6. The question
## asked INSIDE the gate is the same one rb_emitters asks of a whole file --
## proc calls and the source chain followed -- see rb_frag_emitters.
proc rb_nogui_dead {repo path} {
  set txt [rb_slurp $path]
  if {$txt eq {}} { return 0 }
  set body [rb_nogui_gate $txt]
  if {$body eq {}} { return 0 }
  if {[llength [rb_frag_emitters $repo $path $body]]} { return 0 }
  return 1
}

# ---------------------------------------------------------------------------
# RB0/RB1: the list really was lifted, and every entry names a file.
# Anti-vacuity first: if the lift silently returns nothing, RB2 passes while
# measuring nothing, which is the shape of defect this whole file is about.
# ---------------------------------------------------------------------------
set RR [file join $repo tests run_regression.tcl]
set rrtxt [pcall rb_slurp $RR]
set hc [pcall rb_list_items $rrtxt hcases]
set dc [pcall rb_list_items $rrtxt dcases]
set reg [lsort -unique [concat $hc $dc]]

check "RB0 the hcases and dcases lists were lifted from the driver's own text and are non-empty" \
      [list [expr {[llength $hc] > 0}] [expr {[llength $dc] > 0}] [expr {[llength $reg] > 0}]] \
      {1 1 1}

set nofile {}
foreach e $reg { if {![file isfile [rb_suite_path $repo $e]]} { lappend nofile $e } }
check "RB1 every one of the [llength $reg] registered entries resolves to a suite file (both spellings: headless/<name> and a bare name in tests/)" \
      [flat $nofile] {}

# ---------------------------------------------------------------------------
# RB1b: RESOLUTION AGREES WITH THE DRIVER'S OWN SPELLING, DIRECTORIES INCLUDED.
# The driver launches `--script ${hc}.tcl` with its cwd in tests/, so an
# entry's directory components are part of the path. Resolving a headless/<name>
# entry with `[file tail]` is right for every entry registered today and a
# SILENT WRONG ANSWER for a nested one -- worse than a declared limit, which is
# why this row exists rather than an L-number. Legs: the two launch lines really
# do spell it that way (lifted, not remembered), and rb_suite_path preserves the
# entry under tests/ for the four spellings in the row's own fixture list -- a
# headless/<name>, a bare name, and two nested ones. No count is restated here:
# the list is three lines below and the row prints what it resolved.
# ---------------------------------------------------------------------------
proc rb_rel_tests {repo p} {
  set pre [file normalize [file join $repo tests]]
  set p [file normalize $p]
  if {[string first "$pre/" $p] != 0} { return OUTSIDE }
  return [string range $p [string length "$pre/"] end]
}
set RB1B_LAUNCH {}
foreach _l1b [rb_code $rrtxt] {
  if {[regexp -- {--script[ \t]+\$\{(hc|dc)\}\.tcl} $_l1b -> _w1b]} { lappend RB1B_LAUNCH $_w1b }
}
set RB1B_REL {}
foreach e [list headless/test_calc_skeleton hilight_hier_oracle headless/sub/foo headless/wireedit/run_x] {
  lappend RB1B_REL [pcall rb_rel_tests $repo [pcall rb_suite_path $repo $e]]
}
check "RB1b the driver's two launch lines spell `--script \${hc}.tcl` / `\${dc}.tcl` against its cwd in tests/, and rb_suite_path preserves an entry's directory components under tests/ -- a NESTED entry included" \
      [list [lsort -unique $RB1B_LAUNCH] [flat $RB1B_REL]] \
      [list [list dc hc] [flat [list headless/test_calc_skeleton.tcl hilight_hier_oracle.tcl \
                                    headless/sub/foo.tcl headless/wireedit/run_x.tcl]]]

# ---------------------------------------------------------------------------
# RB2: THE FENCE. Every registered suite can emit a line the driver's own
# predicate accepts, with the source chain and one assignment level resolved.
# ---------------------------------------------------------------------------
set noemit {} ; set emech {}
foreach e $reg {
  set p [rb_suite_path $repo $e]
  if {![file isfile $p]} continue
  set h [pcall rb_emitters $repo $p]
  if {[string match ERR:* $h]} { lappend noemit "$e ($h)" ; continue }
  if {![llength $h]} { lappend noemit $e ; continue }
  lappend emech [lindex [lindex $h 0] 1]
}
## ⚠ THE NAME SAYS stdout OR stderr BECAUSE THE PREDICATE ACCEPTS BOTH, and
## that is correct rather than sloppy. Stated as narrowly as it is true: the two
## arms this row's answer can reach are the `hcases` and `dcases` loops, which
## are the ONLY TWO call sites of `regression_case_failed` in
## run_regression.tcl, and both exec their child as `> $log 2>@1` -- so a banner
## written to stderr lands in the log banner_complete reads. An earlier revision
## of this comment said "every arm", with "three exec sites": there are FOUR
## exec sites and the `tcases` one is `eval exec $tccmd > $tcout` with NO stderr
## redirect. That arm is golden-file scored and never reaches this predicate,
## which is why the overstatement was harmless and still had to go. Measured:
## a `puts stderr` of the counted banner, captured `> log 2>@1`, gives
## banner_complete 1 and regression_case_failed 0. Fixture a8 holds the claim.
## What IS rejected is a puts whose channel word is a VARIABLE -- limit L3.
check "RB2 every registered suite has a puts to stdout or stderr -- the two channels T1's `hcases` and `dcases` arms capture, being the only two that are banner-scored -- whose rendered argument banner_rule.tcl's own banner_complete accepts, with the source chain, a command-substitution word and one level of set/append assignment resolved. Static text, arm-blind, generous where the spelling is unknowable: limits L1-L7" \
      [flat $noemit] {}

# ---------------------------------------------------------------------------
# RB3: THE CONTROL BATTERY. Without it a predicate that answers "accepted" to
# everything -- the most likely way to break this file -- makes RB2 green.
# Each fixture is a real .tcl file; none is ever printed.
# ---------------------------------------------------------------------------
set RB_OK    "OVERALL:[format %c 32]ok"
set RB_OKC   "$RB_OK (7 checks)"
set RB_NOTOK "OVERALL:[format %c 32]notok"
## the sentinel SPLIT IN TWO, for the fixture that assembles it with `append`:
## neither half is a banner on its own, which is the whole point of that case
set RB_OKH   "OVERALL:"
set RB_OKT   "[format %c 32]ok"
set fixdir [file join $scratch fix]
file mkdir $fixdir
proc rb_fix {dir name body} {
  set p [file join $dir $name]
  set f [open $p w] ; puts -nonewline $f $body ; close $f
  return $p
}
## the fixtures, each a one-line description and a body built from the words
## above so this file's own source never carries a bare puts of the sentinel
set fixtures [list \
  [list a1 "a literal banner printed"                     "puts \"$RB_OK\"\n"                                           1] \
  [list a2 "a counted literal banner printed"             "puts \"$RB_OKC\"\n"                                          1] \
  [list a3 "the banner computed on the success arm"        "puts \"OVERALL: \[expr \{\$fail ? \{notok\} : \{ok\}\}\]\"\n" 1] \
  [list a4 "the banner built into a variable, printed"     "set s \"$RB_OK\"\nputs \$s\n"                                1] \
  [list a6 "the banner built by a command-substitution word" \
                                                           "puts \[format \"$RB_OK (%d checks)\" \$n\]\n"                1] \
  [list a7 "the banner assembled with append, then printed" \
                                        "set b \"$RB_OKH\"\nappend b \"$RB_OKT (\$n checks)\"\nputs \$b\n"              1] \
  [list a8 "the banner printed on stderr, which T1 captures with 2>@1"  "puts stderr \"$RB_OKC\"\n"                       1] \
  [list a9 "a one-argument puts of the banner variable with TRAILING WHITESPACE -- the last word of a puts is its message, never its channel" \
                                                           "set b \"$RB_OKC\"\nputs \$b \n"                              1] \
  [list a10 "the same with a TAIL COMMENT, which rb_decomment leaves as a bare terminator" \
                                                           "set b \"$RB_OKC\"\nputs \$b ;# the verdict\n"                1] \
  [list r1 "the banner only in a whole-line comment"       "# $RB_OK\nputs \"RESULT: ALL PASS (7 checks)\"\n"             0] \
  [list r2 "the banner only in a tail comment, as a whole puts statement" \
                                                           "puts \"RESULT: ALL PASS (7 checks)\" ;# puts \"$RB_OK\"\n"    0] \
  [list r3 "the banner only in a string that is never printed" \
                                                           "set msg \"$RB_OK\"\nputs \"RESULT: ALL PASS (7 checks)\"\n"   0] \
  [list r4 "the banner written to a channel variable, not stdout" \
                                                           "set fd \[open /dev/null w\]\nputs \$fd \"$RB_OK\"\n"          0] \
  [list r5 "only the failure spelling printed"             "puts \"$RB_NOTOK\"\n"                                        0] \
  [list r6 "the banner quoted inside a check's own message" \
                                                           "puts \"ok:   the suite ends by printing $RB_OK  (ok)\"\n"     0] \
]
set ctl {} ; set want {} ; set FIXREC {}
foreach fx $fixtures {
  set id [lindex $fx 0] ; set body [lindex $fx 2] ; set exp [lindex $fx 3]
  set p [rb_fix $fixdir "rb_fix_$id.tcl" $body]
  set h [pcall rb_emitters $repo $p]
  set got [expr {([string match ERR:* $h] || ![llength $h]) ? 0 : 1}]
  lappend ctl "$id=$got" ; lappend want "$id=$exp"
  lappend FIXREC [list $id $exp $p]
}
check "RB3 the predicate's own controls: [llength $fixtures] synthesized suites, [llength [lsearch -all -inline -glob $want {*=1}]] that must be accepted and [llength [lsearch -all -inline -glob $want {*=0}]] that must be rejected" \
      [flat $ctl] [flat $want]

## And the sourced-common mechanism, which needs two files: the main suite's own
## text has no banner at all and must still be accepted. ⚠ AN EARLIER REVISION
## OF THIS COMMENT SAID "as the 14 registered suites that take it from a common
## require", CONFLATING TWO DIFFERENT SETS: the sourced common is the MINORITY
## mechanism in the tree, and that figure was the size of the set a one-file
## text scan would false-red, most of which compute the banner instead. No
## count here:
## RB4 prints that set at runtime and names it. This is a case a one-file scan
## gets wrong, and RB4 re-measures that it is not a hypothetical.
rb_fix $fixdir rb_fix_common.tcl "proc fin {} \{ puts \"$RB_OK\" \}\n"
set p6 [rb_fix $fixdir rb_fix_a5.tcl \
  "source \[file join \[file dirname \[info script\]\] rb_fix_common.tcl\]\nputs \"RESULT: ALL PASS (7 checks)\"\nfin\n"]
set h6 [pcall rb_emitters $repo $p6]
check "RB3b a suite whose own text has no banner and whose sourced common prints one is accepted (the source chain is followed)" \
      [list [expr {[llength $h6] > 0}] [lindex [lindex $h6 0] 0]] {1 rb_fix_common.tcl}
lappend FIXREC [list a5 1 $p6]

# ---------------------------------------------------------------------------
# RB4: WHY THE RESOLVED PREDICATE AND NOT A GREP, asserted as a property that
# holds whether the tree is imperfect or not.
#
# ⚠ THIS ROW USED TO ASSERT `[llength $naive_false] > 0` -- that the one-file
# text scan really does false-red some REGISTERED suite -- and that is a fence
# keyed to the continued existence of the imperfection it documents. The day the
# suites this row NAMES AT RUNTIME start printing a literal sentinel -- no count
# here, and an earlier revision of this block said "the 13 test_ase_* suites",
# repeating the definite-article error the header's method bullet made --
# the tree gets strictly BETTER and this row goes red with nothing
# wrong: a false red waiting on an unrelated improvement, which is a standing
# red in T1 and the one thing CLAUDE.md says a fence must never become. It was
# measured going red exactly that way, on a synthetic tree whose every
# registered suite prints the literal (issue 1626 stage A2).
#
# What is asserted instead, in two legs, neither of which needs the tree to stay
# imperfect:
#   * over the REGISTERED set: naive-rejected is a SUBSET of accepted -- every
#     suite the naive scan would reject is one this predicate accepts. True
#     vacuously when that set is empty, and violated the moment the resolved
#     predicate becomes NARROWER than a plain text scan.
#   * over THIS FILE'S OWN control fixtures: at least one must-be-accepted
#     fixture is rejected by the naive scan, so the gap the resolved predicate
#     exists for is demonstrated on fixtures that cannot be cured by somebody
#     else's commit.
# The registered-suite count and names stay in the check NAME as information --
# the issue warns against quoting its census number anywhere a command cannot
# re-measure it, and here it is re-measured every run.
# ---------------------------------------------------------------------------
proc rb_naive_hit {txt} {
  foreach ln [rb_code $txt] { if {[string first {OVERALL: ok} $ln] >= 0} { return 1 } }
  return 0
}
set naive_false {} ; set naive_rej_unacc {}
foreach e $reg {
  set p [rb_suite_path $repo $e]
  if {![file isfile $p]} continue
  set naive [pcall rb_naive_hit [rb_slurp $p]]
  set real  [expr {[llength [pcall rb_emitters $repo $p]] > 0}]
  if {$naive ne {0}} continue
  if {$real} { lappend naive_false [file tail $e] } else { lappend naive_rej_unacc [file tail $e] }
}
set fix_naive_gap {}
foreach _r4 $FIXREC {
  foreach {_fid _fexp _fpath} $_r4 break
  if {$_fexp ne {1}} continue
  if {[pcall rb_naive_hit [pcall rb_slurp $_fpath]] eq {0}} { lappend fix_naive_gap $_fid }
}
check "RB4 the resolved predicate is not interchangeable with a one-file text scan of the suite's own non-comment lines: every registered suite that scan would REJECT is one this predicate ACCEPTS, and at least one must-be-accepted control fixture is rejected by that scan ([flat $fix_naive_gap]) -- so the gap is demonstrated on this file's own fixtures and not on the tree staying imperfect. Registered suites the scan would false-red, as information and re-measured every run: [llength $naive_false]: [flat $naive_false]" \
      [list [flat $naive_rej_unacc] [expr {[llength $fix_naive_gap] > 0}]] [list {} 1]

# ---------------------------------------------------------------------------
# RB6: RB2 IS ARM-BLIND, AND THIS ROW FENCES THE ONE HAZARD THAT ARM-BLINDNESS
# LETS THROUGH THAT CAN BE READ OFF THE TEXT.
#
# RB2 unions hcases and dcases and asks only whether a suite's TEXT could EVER
# emit the sentinel. Both Calculator suites CAN -- on their display arm -- and
# both take a whole-file no-X early exit on their headless arm that prints no
# banner at all. So adding either to `hcases` as well leaves RB2 green while T1
# scores that case
#   HARNESS: ... did not complete cleanly (exit=0, OVERALL_ok=0, died=0)
# with every one of its own checks passing: the 1615/1626 incident repeated with
# the new fence SILENT. MEASURED that way at issue 1626 stage A2, before this
# row existed -- the fence reported ALL PASS with `headless/test_calc_widgets`
# wrongly in `hcases`, while `regression_case_failed 0` over that suite's real
# --nogui output answered 1. (The check count that run printed is in that
# stage's receipt, dated; it is not restated here, because this row's count
# moves with its own fixtures.)
#
# ⚠ THE ASSERTION IS KEYED TO THE PROPERTY, NOT TO THE TWO NAMES: no `hcases`
# entry may take a whole-file no-X early exit from which no banner is REACHABLE
# -- proc calls and the source chain followed, see rb_frag_emitters, because a
# gate whose banner lives in a helper is perfectly scorable and flagging it
# would be a standing red waiting on a refactor. A third such suite arriving is
# caught without this row being edited. The two names appear only in the
# information the row prints, and what the row does NOT cover is limit L6.
#
# ⚠ ANTI-VACUITY IS KEYED TO THIS FILE'S OWN FIXTURES, not to the tree keeping
# two such suites. That is the mistake RB4 used to make: a fence keyed to the
# continued existence of the thing it documents goes red when somebody else
# improves the tree.
# ---------------------------------------------------------------------------
set RB6_GATE_T "if \{!\[info exists ::has_x\] || \[info commands winfo\] eq \{\}\} \{"
set g_fix [list \
  [list g1 "a whole-file no-X exit gate that prints NO banner -- the Calculator shape" \
       "$RB6_GATE_T\n    puts \"RESULT: ALL PASS (0 checks)\"\n    flush stdout\n    exit 0\n\}\nputs \"$RB_OK\"\n" 1] \
  [list g2 "a whole-file no-X exit gate that DOES print the banner before exiting" \
       "$RB6_GATE_T\n    puts \"RESULT: SKIP (no display)\"\n    puts \"$RB_OK\"\n    exit 0\n\}\nputs \"$RB_OK\"\n" 0] \
  [list g3 "no gate at all" "puts \"$RB_OK\"\n" 0] \
  [list g4 "a no-X guard that does NOT exit -- a per-band skip, not a whole-file gate" \
       "$RB6_GATE_T\n    puts \"skip: the display band\"\n\}\nputs \"$RB_OK\"\n" 0] \
  [list g5 "a gate whose banner is printed by a HELPER PROC it calls -- the real-run counterexample, see rb_frag_emitters" \
       "proc gfin \{\} \{ puts \"$RB_OK\" \}\n$RB6_GATE_T\n    puts \"RESULT: SKIP (no display)\"\n    gfin\n    exit 0\n\}\nputs \"$RB_OK\"\n" 0] \
  [list g6 "a gate that calls a helper defined in a SOURCED common, sourced at file scope" \
       "source \[file join \[file dirname \[info script\]\] rb_gate_common.tcl\]\n$RB6_GATE_T\n    puts \"RESULT: SKIP (no display)\"\n    gcommon_fin\n    exit 0\n\}\nputs \"$RB_OK\"\n" 0] \
  [list g7 "ANTI-OVERSHOOT: a gate that calls a helper printing NO banner must STILL be flagged -- following a call is not the same as accepting one" \
       "proc rfin \{\} \{ puts \"RESULT: ALL PASS (0 checks)\" \}\n$RB6_GATE_T\n    rfin\n    flush stdout\n    exit 0\n\}\nputs \"$RB_OK\"\n" 1] \
  [list g8 "ANTI-OVERSHOOT: a gate that only MENTIONS a banner-printing helper inside a message string must STILL be flagged -- a call is a word in command position, not a substring" \
       "proc gfin \{\} \{ puts \"$RB_OK\" \}\n$RB6_GATE_T\n    puts \"RESULT: ALL PASS (0 checks) -- gfin was not called\"\n    flush stdout\n    exit 0\n\}\nputs \"$RB_OK\"\n" 1] \
]
## g6's common. Written before the battery runs, beside the fixtures, so the
## gate body's call resolves through the sourced file's proc table.
rb_fix $fixdir rb_gate_common.tcl "proc gcommon_fin \{\} \{ puts \"$RB_OK\" \}\n"
set gctl {} ; set gwant {}
foreach fx $g_fix {
  set id [lindex $fx 0] ; set body [lindex $fx 2] ; set exp [lindex $fx 3]
  set p [rb_fix $fixdir "rb_gate_$id.tcl" $body]
  lappend gctl "$id=[pcall rb_nogui_dead $repo $p]" ; lappend gwant "$id=$exp"
}
set hc_dead {} ; set reg_dead {}
foreach e $reg {
  set p [rb_suite_path $repo $e]
  if {![file isfile $p]} continue
  if {[pcall rb_nogui_dead $repo $p] ne {1}} continue
  lappend reg_dead [file tail $e]
  if {[lsearch -exact $hc $e] >= 0} { lappend hc_dead $e }
}
check "RB6 rb_nogui_dead -- find a whole-file no-X early-exit gate in a suite's text, then ask rb_frag_emitters whether a banner-printing `puts` is PRESENT anywhere in it, in the files it sources, or in the body of a proc it names, and call the gate dead when none is -- answers 0 for every `hcases` entry; plus the detector's own [llength $g_fix] controls, [llength [lsearch -all -inline -glob $gwant {*=1}]] that must be flagged and [llength [lsearch -all -inline -glob $gwant {*=0}]] that must not. ⚠ PRESENCE, NOT REACHABILITY, and an earlier revision of this name said \"reachable\", which claimed more than the method delivers: a banner in a proc DEFINED inside the gate and never called, in a sourced file that only DEFINES a printing proc, or behind a false condition in a proc the gate does call, all answer NOT-dead and so are not flagged. Those are missed detections, not false reds. ⚠ ONE unreachability shape, `hcases` only, and only the banner_complete arm of regression_case_failed: limit L6 states what it does not cover, and T1's own HARNESS line is the backstop. Registered suites with the shape, as information and re-measured every run: [llength $reg_dead]: [flat $reg_dead]" \
      [list [flat $hc_dead] [flat $gctl]] [list {} [flat $gwant]]

# ---------------------------------------------------------------------------
# RB7: THE REGISTRATION ITSELF, BY NAME -- the mirror image of RB2.
#
# RB2 asserts "every registered suite can emit the banner". NOTHING asserted
# the registration. MEASURED at issue 1626 stage A2, before this row existed:
# both `dcases` entries deleted from the driver and the fence still reported ALL
# PASS, so issue 1626's headline defect -- both Calculator suites' entire
# passing check totals gating NOTHING for a month, the figures dated in that
# issue's own table -- could come back silently, and the fence built to stop it
# would say nothing. RB1's check name carries an entry COUNT, which asserts
# nothing at all; this row asserts the three entries that matter by name.
#
# The precedent is row V57 of tests/headless/test_op_annot.tcl, which asserts
# its own two entries are in the driver's lists for exactly this reason: a suite
# whose registration is removed goes on passing standalone while the everyday
# runner stops running it, and the verdict goes on saying zero failures.
#
# ⚠ NAMES ARE RIGHT HERE and the property is right in RB6. "Is this suite
# registered" is a claim about these specific entries and cannot be derived from
# any property of the tree -- the whole hazard is that the tree looks fine
# without them. RB6 is the general claim and takes no names.
# ---------------------------------------------------------------------------
check "RB7 look up three entry names in the lists lifted from the driver's own text: `headless/test_calc_skeleton` and `headless/test_calc_widgets` in `dcases`, and this fence itself in `hcases`. THESE THREE ONLY -- no other entry's registration is asserted anywhere in this file (precedent: row V57 of tests/headless/test_op_annot.tcl)" \
      [list [expr {[lsearch -exact $dc headless/test_calc_skeleton] >= 0}] \
            [expr {[lsearch -exact $dc headless/test_calc_widgets] >= 0}] \
            [expr {[lsearch -exact $hc headless/test_registered_banner_1626] >= 0}]] \
      {1 1 1}

# ---------------------------------------------------------------------------
# RB5: ONE BUILDER. This file must CALL banner_rule.tcl's predicate and keep no
# private spelling of the pattern -- the drift that let issue 0689 survive four
# filings, and the lock K17 holds for run_regression.tcl.
# ---------------------------------------------------------------------------
## WARN THIS ROW USED ITS OWN STRIPPER AND IT WAS THE WRONG ONE. It filtered only
## whole-line comments (`regexp {^[ \t]*#}`), while rb_decomment exists in this
## file precisely because, in its own words, "Dropping whole-line comments is not
## enough: a complete puts statement parked in a tail comment is read as code by
## any line scanner". Measured on the shipped text: appending
## `set z 1 ;# regexp -line {^OVERALL: ok} $body` turned this row RED -- a false
## red on a COMMENT, in the file whose whole subject is that a false red here
## becomes a standing red in T1. It now uses rb_code, the same decommenting
## reader every other row in this file uses, so the row's name and the text it
## actually reads are the same text.
set own_code [join [rb_code [rb_slurp [info script]]] \n]
check "RB5 this file's own code text, decommented by rb_code (whole-line AND tail comments, the same reader the other rows use), names banner_rule.tcl, calls banner_complete, and carries no line on which a `regexp` command and the ok-sentinel appear together -- the shape in which a private fourth spelling of the rule would be written. A pattern parked in a variable and used on another line is NOT read: one line, one shape" \
      [list [regexp {banner_rule\.tcl} $own_code] \
            [regexp {banner_complete} $own_code] \
            [regexp "regexp\[^\n\]*$RB_OK" $own_code]] {1 1 0}

catch {test_scratch_drop $scratch}

## THE COMPLETION BANNER, AND `RESULT:` LAST -- which is a claim about being the
## LAST `RESULT:` LINE and NOT a claim about following the banner. THE ORDER OF
## THESE TWO LINES IS FREE, measured: printing `RESULT:` first left all three
## readers green, correctly, because `banner_complete` is `regexp -line` over
## the whole captured body, `summarize_all` keeps a case's last `^RESULT:` line
## of which there is then still one, and run_suites.sh does
## `grep -E '^RESULT' | tail -1`. Nothing in the tree catches a swap and nothing
## should.
## ⚠ AN EARLIER REVISION OF THIS VERY COMMENT CLAIMED THE OPPOSITE -- "so the
## order is not free" -- and cited `wvbs_finish` in tests/headless/wvbs_common.tcl
## as the authority. That comment says, in as many words, "THE ORDER OF THE TWO
## LINES IS NOT load-bearing and this comment does not claim it is". The same
## false clause was removed from both calculator suites by issue 1626 stage A2
## and survived here, in the file doing the editing, until stage A3.
## What DOES cost something is a SECOND `RESULT:` line: the published check count
## silently becomes whatever the last one says, with `counted_failures` and
## `skips` both still 0 and no reader reddening. That is issue **1627**, OPEN and
## unfenced, and its own file carries the dated measurement. This file has ONE
## exit path, so any new one must print its verdict INSTEAD of this one, never as
## well. Only the success path claims completion.
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "OVERALL: $fail FAILED ($npass passed)"
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
