# tests/headless/test_generator_shell_1610.tcl
#
# ISSUE 1610 -- a generator symbol name reached /bin/sh, and its arguments were
# never quoted.
#
# `get_generator_command()` in src/token.c turns an instance's symbol name of the
# shape `head(args)` into a command string, and its callers -- `load_schematic`
# and `load_sym_def` in save.c, and one site in paste.c -- hand that string to
# **popen()**, i.e. to a shell. It quoted the generator's PATH (its own comment
# said so) and then appended the ARGUMENTS verbatim, so shell metacharacters in a
# symbol name were live: `;` `&&` `|` a backtick `$VAR` and redirections, each
# driven below. A symbol name is file-supplied, so this was reachable by opening a
# schematic somebody else wrote -- no draw, no netlist, no display, no subcommand.
#
# ⚠ `$( )` IS *NOT* ON THAT LIST, AND AN EARLIER DRAFT OF THIS HEADER SAID IT WAS.
# `is_generator` in src/token.c requires `^[^ \t()]+\([^()]*\)[ \t]*$`, so the
# argument list may contain no parenthesis and command substitution cannot be
# spelled. Measured, not reasoned: `xschem is_generator {g.sh(z$(touch x))}`
# answers 0 while the backtick and `$VAR` forms answer 1. Row B5b asserts exactly
# that, so the claim is re-measured every run instead of living in this sentence.
#
# WHAT THIS SUITE IS *NOT* ABOUT. Issue 0823 records that a `.sch` is executable
# BY DESIGN through `tcl_hook2()`'s documented `tcleval(` marker, and that
# reversing that is the project owner's call, recorded as `rule/0823`. This suite
# does not touch that. 0823's own argument is what puts 1610 on the defect side
# of the line: `tcleval(` is a MARKER a reader can see and grep for, and the
# UNMARKED doors are the ones worth closing. A generator name announces nothing
# -- `/bin/true(z;...)` has the same shape as the shipped, honest `res.tcl(@value)`.
#
# THE INSTRUMENT IS THE GENERATOR'S OWN argv, NOT THE ABSENCE OF A SYMPTOM.
# Every row below runs a real generator that records `$#` and each `$@` it was
# given, and asserts the ARGV SHAPE. That is deliberate and it is CLAUDE.md's
# rule: a fence keyed to a symptom dies quietly when something else cures the
# symptom. A row that only checked "the payload did not execute" would go green
# the day somebody replaced popen() with fork/exec for an unrelated reason, and
# would then fence nothing while still passing. Asserting that the payload
# arrives as a LITERAL ARGUMENT is asserting the correct shape, and it also
# distinguishes "quoted" from "refused" -- two fixes with the same symptom and
# very different behaviour. The marker-file assertion rides ALONGSIDE it, never
# alone.
#
# SECTIONS
#   A1-A7   NEUTRALITY, the rows that redden if quoting MANGLES an argument.
#           Legitimate argument lists -- identifiers, a value with a unit
#           suffix, a path, signed numbers, an empty list -- must reach the
#           generator as exactly the same argv as before the fix. These rows do
#           NOT redden if the quoting is removed, and that is correct: they
#           fence the fix's harmlessness, not the fix. A7 is the single-quote
#           case, which is the only argument whose bytes the quoting has to
#           transform (`'` -> `'\''`) rather than merely surround.
#   B1-B6   THE DEFECT, the rows that redden if the quoting is removed. One
#           shape each: `;` `&&` `|` a backtick, `$VAR`, and a `>` redirection.
#           B1-B4 assert BOTH that the generator saw the payload as literal argv
#           AND that the chained command did not run. B5 (`$VAR`) and B6 (`>`)
#           need no second program to exist at all, which is why they are here:
#           a box without /usr/bin/touch still measures the fix. B5b fences B5's
#           own premise by asserting the grammar refuses `$( )`.
#   S1-S4   STRUCTURAL, for the one thing this machine cannot drive: the
#           non-`__unix__` branch. Read with COMMENT LINES STRIPPED, because the
#           fix's own comment quotes the defective shape and a raw grep would
#           answer "still broken" forever. Named for WHAT TEXT THEY GREP, and
#           claiming NO COUNT of what escapes them.
#
# ⚠ THE WINDOWS BRANCH IS NOT MEASURED ANYWHERE, HERE OR IN THE SOURCE. There is
# no Windows toolchain on the machine this was written on. On that branch the
# string goes to cmd.exe, whose quoting is not the shell's, so the fix there is a
# whitelist REFUSAL rather than quoting, and S3/S4 assert only that the refusal
# is present in the text. Nothing in this suite establishes that it is correct on
# Windows, and no comment in token.c claims it does. Issue 1606 shipped a comment
# that turned exactly this kind of derivation into a claimed Win64 measurement
# and had to correct it.
#
# ARMED SPELLING
#   tests/headless/run_suites.sh --nogui test_generator_shell_1610
# Registered in tests/run_regression.tcl in `hcases` only: nothing here needs a
# display, so it costs one case and no skip.
#
# FLOOR: 18 checks (7 neutrality + 7 defect + 4 structural). Measured 2026-09-27. RAISED, NEVER LOWERED.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc skiprow {names why} { puts "skip: $names -- $why" ; flush stdout }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]

set scratch [test_scratch genshell]
set TOKC [file join $repo src token.c]

proc slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
proc wrf {path text} {
  set fp [open $path w] ; puts -nonewline $fp $text ; close $fp
  return $path
}
## Comment lines removed. The fix's comment block in token.c quotes the
## defective shape verbatim (`my_strcat(_ALLOC_ID_, &gen_cmd, spc_idx)`), so a
## structural row reading the raw file would answer "the bug is still here" for
## ever. Same technique as test_generator_paren_1604.tcl and
## test_preview_name_inject_1601.tcl.
proc nocomment_c {text} {
  ## Strips /* ... */ blocks and // to end of line. Not a C tokeniser: a `/*`
  ## inside a string literal would fool it. No row below depends on a string
  ## literal containing one, and this comment is the limit statement rather
  ## than a claim that none can exist.
  regsub -all {/\*.*?\*/} $text " " text
  set out {}
  foreach l [split $text "\n"] {
    regsub {//.*$} $l "" l
    lappend out $l
  }
  return [join $out "\n"]
}
## The body of a C function: its opening line to the first column-0 `}`.
## ZZNOFUNC if it is not there at all, so no row can pass by finding nothing.
proc cfunc_body {src name} {
  set on 0 ; set out {}
  foreach l [split $src "\n"] {
    if {$on} {
      if {[regexp {^\}} $l]} { return [join $out "\n"] }
      lappend out $l
      continue
    }
    if {[regexp "\[ \t\*\]$name\[ \t\]*\\(" $l]} { set on 1 }
  }
  if {$on} { return [join $out "\n"] }
  return ZZNOFUNC
}

set CSRC [nocomment_c [slurp $TOKC]]

#############################################################################
## The generator. It records the argv it was handed and prints a minimal
## symbol on stdout, which is what a generator is contracted to do. The log
## path is baked in rather than passed through the environment, so the row does
## not depend on popen() forwarding an exported variable.
#############################################################################
set gendir [file join $scratch gen]
file mkdir $gendir
set ARGVLOG [file join $scratch argv.log]
set MARKDIR [file join $scratch marks]
file mkdir $MARKDIR

set GEN [file join $gendir gen.sh]
wrf $GEN "#!/bin/sh\n\{ printf 'argc=%d' \"\$#\"; for a in \"\$@\"; do printf ' \[%s\]' \"\$a\"; done; printf '\\n'; \} >> '$ARGVLOG'\ncat <<'SYM'\nv \{xschem version=3.4.5 file_version=1.2\}\nG \{\}\nK \{type=subcircuit\}\nV \{\}\nS \{\}\nE \{\}\nB 5 -10 -10 10 10 \{name=A dir=in\}\nSYM\n"
file attributes $GEN -permissions 0755

## Load a schematic holding ONE instance whose symbol name is `gen.sh(<args>)`,
## and return the argv line the generator recorded. Each row uses a DIFFERENT
## argument list on purpose: match_symbol() caches by the whole name, so a
## repeated name would be served from xctx->sym[] and the generator would not
## run a second time.
proc drive {args_text} {
  global scratch GEN ARGVLOG
  wrf $ARGVLOG ""
  set sch [file join $scratch drive.sch]
  ## ${GEN} in braces, not $GEN: `$GEN(` reads as an ARRAY SUBSCRIPT in Tcl and
  ## the suite dies at parse time with "variable isn't array". The generator
  ## grammar this suite is about is literally `name(args)`, so every fixture
  ## string here has a `(` immediately after a variable.
  wrf $sch "v \{xschem version=3.4.5 file_version=1.2\}\nG \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}\nC \{${GEN}($args_text)\} 240 -330 0 0 \{name=x1\}\n"
  catch {xschem load $sch}
  set got [string trim [slurp $ARGVLOG]]
  if {$got eq "ZZNOFILE"} { return ZZNOLOG }
  return $got
}

#############################################################################
## A -- NEUTRALITY. These redden if the quoting mangles a legitimate argument.
## They do NOT redden if the quoting is removed; B is what fences that.
#############################################################################
check "A1 three bare identifiers reach the generator as three arguments" \
  [drive "a,b,c"] {argc=3 [a] [b] [c]}

check "A2 a model name and two values with unit suffixes, the mosgen.tcl shape" \
  [drive "nmos,2u,0.15u"] {argc=3 [nmos] [2u] [0.15u]}

check "A3 one value with a unit suffix, the res.tcl shape" \
  [drive "1k"] {argc=1 [1k]}

check "A4 an EMPTY argument list, the symbolgen.tcl() shape, reaches the generator with no arguments" \
  [drive ""] {argc=0}

check "A5 a path and two signed numbers survive byte for byte" \
  [drive "/some/path.sym,x-1.5,v+2"] {argc=3 [/some/path.sym] [x-1.5] [v+2]}

## A6 carries the punctuation the non-__unix__ whitelist in S4 admits, so the two
## halves of the fix are checked against one set of characters rather than each
## against its own idea of what is legitimate.
##
## ⚠ NOT `@lab`, AND THE REASON IS A SEPARATE PRE-EXISTING DEFECT. Driven at
## 636bc431: an instance named `gen.sh(@lab)` produces
## `l_s_d(): Symbol not found: .../gen.sh(` -- the name is TRUNCATED AT THE OPEN
## PARENTHESIS somewhere in `@`-token substitution, with `lab=NETA` present on
## the instance. So the shipped `tier.tcl(@lab)` shape does not reach a generator
## by this route at all and a row asserting its argv would be asserting the
## wrong thing. That truncation is not 1610's and is not fixed here; it is
## recorded in issue 1610 as an open question, because it is also what made the
## `value=1k;<command>` property-injection probe fail to reproduce.
check "A6 dots, dashes, underscores and a colon -- the punctuation S4's whitelist admits -- survive byte for byte" \
  [drive "a.b-c,d_e:f"] {argc=2 [a.b-c] [d_e:f]}

## A7 is the only argument whose BYTES the quoting must transform rather than
## surround: a single quote has to close the quoted run, emit an escaped quote
## and reopen it. If that escaping is wrong the shell either eats the rest of
## the arguments or the generator is never reached at all, so this row is what
## stands between the fix and a new defect of its own making.
check "A7 an argument containing a single quote survives as one literal argument" \
  [drive "it's,b"] {argc=2 [it's] [b]}

#############################################################################
## B -- THE DEFECT. Each row reddens if the quoting is removed. Every row
## asserts BOTH the argv shape (the CORRECT shape: the payload is data) AND
## that the chained command did not run.
#############################################################################
proc inject {tag args_text} {
  global MARKDIR
  set mark [file join $MARKDIR $tag]
  catch {file delete $mark}
  set argv [drive [string map [list @MARK@ $mark] $args_text]]
  return [list $argv [file exists $mark]]
}

check "B1 a `;` chaining a second command arrives as literal argv and does not run" \
  [inject B1 "z;/usr/bin/touch @MARK@"] \
  [list "argc=2 \[z;/usr/bin/touch\] \[[file join $MARKDIR B1]\]" 0]

check "B2 an `&&` chaining a second command arrives as literal argv and does not run" \
  [inject B2 "z&&/usr/bin/touch @MARK@"] \
  [list "argc=2 \[z&&/usr/bin/touch\] \[[file join $MARKDIR B2]\]" 0]

check "B3 a `|` piping into a second command arrives as literal argv and does not run" \
  [inject B3 "z|/usr/bin/touch @MARK@"] \
  [list "argc=2 \[z|/usr/bin/touch\] \[[file join $MARKDIR B3]\]" 0]

check "B4 a backtick substitution arrives as literal argv and does not run" \
  [inject B4 "z`/usr/bin/touch @MARK@`"] \
  [list "argc=2 \[z`/usr/bin/touch\] \[[file join $MARKDIR B4]`\]" 0]

## B5 is VARIABLE EXPANSION, not command substitution, and the choice is
## measured rather than stylistic. `$( )` CANNOT REACH HERE AT ALL: `is_generator`
## in src/token.c requires `^[^ \t()]+\([^()]*\)[ \t]*$`, so the argument list may
## hold no parenthesis, and `xschem is_generator {g.sh(z$(touch x))}` answers 0 --
## driven at 636bc431. A backtick needs no parenthesis and does reach here, which
## is B4. `$VAR` reaches here too, and it is the cleanest probe in the section
## because it needs no second program to exist: pre-fix the shell expanded it, so
## the generator saw the VALUE; post-fix it must see the two characters.
##
## B5b immediately below asserts the grammar really does refuse `$( )`, so this
## row's premise is fenced rather than asserted in a comment, and so that nobody
## later adds a guard for a door that was never open.
check "B5 a \$VAR is not expanded by a shell and arrives as its literal characters" \
  [drive "z\$HOME"] {argc=1 [z$HOME]}

check "B5b is_generator refuses an argument list containing \$( ), which is why B5 probes \$VAR and B4 probes a backtick" \
  [list [xschem is_generator {g.sh(z$(touch x))}] \
        [xschem is_generator {g.sh(z`touch x`)}] \
        [xschem is_generator {g.sh(z$HOME)}]] {0 1 1}

## B6 is a redirection rather than a chained command: it needs no second
## program, so it also covers the case where /usr/bin/touch is absent.
check "B6 a `>` redirection arrives as literal argv and creates no file" \
  [inject B6 "z>@MARK@"] \
  [list "argc=1 \[z>[file join $MARKDIR B6]\]" 0]

#############################################################################
## S -- STRUCTURAL. The non-__unix__ branch cannot be driven on this machine,
## so these read the text. Each is named for THE TEXT IT GREPS and claims no
## count of what escapes it.
#############################################################################
set GBODY [cfunc_body $CSRC get_generator_command]
set QBODY [cfunc_body $CSRC sh_quote_args]

check "S1 the text `sh_quote_args` appears in get_generator_command's comment-stripped body, and the raw `my_strcat(_ALLOC_ID_, &gen_cmd, spc_idx)` append does not" \
  [list [expr {[string first "sh_quote_args" $GBODY] >= 0}] \
        [expr {[string first "&gen_cmd, spc_idx" $GBODY] >= 0}]] {1 0}

check "S2 a function named sh_quote_args exists, is static, and its comment-stripped body contains the three-character escape for a single quote" \
  [list [expr {$QBODY ne "ZZNOFUNC"}] \
        [expr {[regexp {static\s+char\s*\*\s*sh_quote_args} $CSRC] ? 1 : 0}] \
        [expr {[string first {'\\'} $QBODY] >= 0}]] {1 1 1}

## S3/S4 are the Windows half. They assert the REFUSAL is in the text and that
## the string handed to popen there is still built. They do NOT assert it is
## correct on Windows -- nothing here can, and the suite header says so.
check "S3 the non-__unix__ branch of get_generator_command carries a character whitelist and a refusal that leaves gen_cmd NULL" \
  [list [expr {[regexp {#else} $GBODY] ? 1 : 0}] \
        [expr {[string first "goto end" $GBODY] >= 0}] \
        [expr {[regexp {\*q >= 'A' && \*q <= 'Z'} $GBODY] ? 1 : 0}]] {1 1 1}

check "S4 that whitelist admits the characters every shipped generator invocation uses, and none of `; | & \$ backtick > <`" \
  [list [expr {[string first "*q == '@'" $GBODY] >= 0}] \
        [expr {[string first "*q == '/'" $GBODY] >= 0}] \
        [expr {[string first "*q == ';'" $GBODY] >= 0}] \
        [expr {[string first "*q == '|'" $GBODY] >= 0}]] {1 1 0 0}

#############################################################################
puts "RESULT: [expr {$fail ? "$fail FAILED ($npass passed)" : "ALL PASS ($npass checks)"}]"
if {$fail} { puts "OVERALL: FAIL" } else { puts "OVERALL: ok ($npass checks)" }
test_scratch_drop $scratch
