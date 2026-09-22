# tests/headless/test_generator_paren_1604.tcl
#
# ISSUE 1604 -- a parenthesis in a file name made xschem say it is not an
# xschem file.
#
# `proc is_xschem_file` in src/xschem.tcl has to take a GENERATOR's argument
# list off a name before it can test the name for existence, because a
# generator is referenced as `gen.tcl(a,b)` and only `gen.tcl` is on disk.
# It did that with an UNANCHORED regsub of {\(.*}, which eats the FIRST open
# parenthesis and everything after it, ANYWHERE in the string:
#
#     /lib/bandgap(rev2).sch     was tested as  /lib/bandgap
#     /lib/foo (1).sch           was tested as  /lib/foo            (and a space)
#     /lib/opamp(v3)_final.sym   was tested as  /lib/opamp
#
# None of those exist, so the proc answered 0, and its five call sites read
# that as "not an xschem file": the Insert dialog would not place the file and
# drew no preview, and the Open dialog accused a schematic the user had saved
# themselves. `foo (1).sch` is the name a browser or a file manager gives a
# duplicate and a parenthesised revision tag is ordinary practice, so this is
# not an exotic input.
#
# THE GRAMMAR. The authority is NOT this suite and NOT the issue: it is
# `is_generator` in src/token.c, which is what save.c `load_schematic` and
# paste.c ask before they popen a name. Its ERE is
#
#     ^[^ \t()]+\([^()]*\)[ \t]*$
#
# -- head admits no space, tab or parenthesis; the argument list never nests
# and may be empty; nothing but optional whitespace may follow the closing
# parenthesis. Section G measures the shipped Tcl strip against that C entry
# point directly, through `xschem is_generator`, on a table of names. Anchoring
# to the tail alone is NOT the same thing and would put the two out of step for
# a generator under a directory whose name has a space -- a name is opened as a
# pipe or as a plain file on is_generator's answer, so a name this proc calls
# GENERATOR while is_generator refuses it is opened as a file and fails.
#
# SECTIONS
#   S1-S8   STRUCTURAL, both arms. The proc is there, the unanchored spelling
#           is gone from it, every occurrence left in the file sits behind an
#           `xschem is_generator` guard, the anchored strip is there exactly
#           once, and the pattern it carries is still character-for-character
#           the C ERE in token.c. The source is read with COMMENT LINES
#           STRIPPED, because the fix's own comment quotes the defective
#           pattern verbatim and a raw grep would answer "still broken" for
#           ever.
#   G1-G18  GRAMMAR, both arms. The strip taken OUT OF THE SHIPPED FILE -- not
#           a copy kept here -- is run over a table of names and must agree,
#           name for name, with `xschem is_generator`. G16 shows the OLD
#           unanchored pattern failing that same table, so nobody can mistake
#           the agreement for something any pattern would satisfy.
#   F1-F13  FUNCTIONAL, both arms. Real files on disk with real parenthesised
#           names, through the real `is_xschem_file`: a schematic, a symbol, a
#           generator with arguments, with an empty list, and with no list at
#           all. This is the defect itself. F12/F13 pin the residual limit.
#   D1-D5   DIALOG, DISPLAY ARM ONLY. The Insert dialog's own procs --
#           `file_chooser_symbol_or_schematic` and `file_chooser_preview` --
#           reached with a real `bandgap(rev2).sch`, proving the file is placed
#           and previewed rather than silently ignored. These need Tk widgets
#           (`toplevel`, `listbox`), which do not exist under --nogui.
#
# ARMED SPELLINGS
#   tests/headless/run_suites.sh test_generator_paren_1604            (all)
#   tests/headless/run_suites.sh --nogui test_generator_paren_1604    (S+G+F)
# Registered in tests/run_regression.tcl in BOTH `hcases` and `dcases`, for the
# same reason test_preview_name_inject_1601 is.
#
# FLOOR: 41 checks headless (S+G+F), 46 on the display arm. Measured 2026-09-22.
# RAISED, NEVER LOWERED.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
proc skiprow {names why} { puts "skip: $names -- $why" ; flush stdout }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]

set XTCL [file join $repo src xschem.tcl]
set TOKC [file join $repo src token.c]

proc slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
## Comment lines removed. The fix's own comment block QUOTES the defective
## pattern verbatim, so a structural row reading the raw file would answer
## "the bug is still here" forever. Same technique as
## tests/headless/test_input_line_inject_1352.tcl and
## tests/headless/test_preview_name_inject_1601.tcl.
proc nocomment {text} {
  set out {}
  foreach l [split $text "\n"] {
    if {[regexp {^[ \t]*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
proc scount {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
## The body of `proc <name>` only: its `proc` line to the first column-0 close
## brace. ZZNOPROC if the proc is not there at all, so no row can pass by
## finding nothing.
proc proc_body {src name} {
  set on 0 ; set out {}
  foreach l [split $src "\n"] {
    if {$on} {
      if {[regexp {^\}} $l]} { return [join $out "\n"] }
      lappend out $l
      continue
    }
    if {[regexp "^proc\[ \t\]+$name\[ \t\]" $l]} { set on 1 }
  }
  if {$on} { return [join $out "\n"] }
  return ZZNOPROC
}

set SRC  [slurp $XTCL]
set FILE [nocomment $SRC]
set BODY [proc_body $FILE is_xschem_file]
set RAW  [proc_body $SRC is_xschem_file]

# ===========================================================================
# SECTION S -- STRUCTURAL. Both arms. This reddens if the fix is edited away
# textually, without anybody opening a dialog.
# ===========================================================================
check_true {S1 proc is_xschem_file is still in src/xschem.tcl} \
  [expr {$BODY ne {ZZNOPROC} && $BODY ne {}}]

## Comments are stripped, so the fix's own quotation of the defective pattern
## does not count.
check {S2 the unanchored generator strip is gone from is_xschem_file} \
  [scount $BODY {regsub {\(.*}}] 0

## ⚠ S3 IS NOT "THE PATTERN IS GONE EVERYWHERE". The survey for issue 1604
## found the same unanchored spelling at two more places in src/xschem.tcl --
## in `cellview_edit_item` and in the cell-view list that builds its balloon --
## and BOTH are already correct, because both sit inside an
## `xschem is_generator` guard. Once C has answered 1 the whole string is known
## to be head-then-parenthesised-list with no parenthesis in the head, so the
## unanchored strip and the anchored one give the same answer. What must hold
## is the GUARD, not the pattern: an unguarded occurrence is the 1604 defect
## again. This row counts occurrences that have no `xschem is_generator` within
## the three lines above them.
proc unguarded_strips {src} {
  set lines [split $src "\n"]
  set n [llength $lines] ; set bad 0
  for {set i 0} {$i < $n} {incr i} {
    if {[string first {regsub {\(.*}} [lindex $lines $i]] < 0} { continue }
    set guarded 0
    for {set j [expr {$i - 3}]} {$j < $i} {incr j} {
      if {$j < 0} { continue }
      if {[string first {xschem is_generator} [lindex $lines $j]] >= 0} { set guarded 1 }
    }
    if {!$guarded} { incr bad }
  }
  return $bad
}
check {S3 every remaining unanchored strip sits behind an is_generator guard} \
  [unguarded_strips $FILE] 0
check {S3b the two guarded occurrences are still there, so S3 is not vacuous} \
  [scount $FILE {regsub {\(.*}}] 2

## Exactly one strip, and it is the anchored one.
check {S4 is_xschem_file carries exactly one regsub} \
  [llength [lsearch -all -regexp [split $BODY "\n"] {^[ \t]*regsub[ \t]}] ] 1
check {S5 that regsub is anchored to a trailing parenthesised argument list} \
  [scount $BODY {regsub {^([^ \t()]+)\([^()]*\)[ \t]*$} $f {\1} f}] 1

## ⚠ S6 EXISTS BECAUSE A COMMENT INSIDE A PROC BODY IS INSIDE A BRACE-QUOTED
## WORD, and Tcl counts braces before it ever notices a `#`. The 1601 crew broke
## this product twice that way -- once making every call raise, once aborting
## startup. This row reads the RAW body, comments included.
##
## ⚠ IT COUNTS ONLY THE DOUBLE-HASH LINES, and that is not laziness. The proc
## already carried a commented-out `if` block, on single-hash lines, whose open
## brace and close brace are on DIFFERENT lines -- balanced as a block, not per
## line. A per-line rule over every comment would redden on shipped code that is
## fine. Double-hash is this tree's prose-comment spelling and is what a fix
## writes, so scoping the per-line rule to it measures exactly the hazard: a new
## explanatory line that quotes one brace. S6b then measures the block property
## the single-hash lines actually have to satisfy.
proc comment_brace_faults {body pfx} {
  set bad 0
  foreach l [split $body "\n"] {
    if {![regexp "^\[ \t\]*$pfx" $l]} { continue }
    set d 0 ; set ok 1
    foreach c [split $l {}] {
      if {$c eq "\{"} { incr d } elseif {$c eq "\}"} { incr d -1 }
      if {$d < 0} { set ok 0 }
    }
    if {!$ok || $d != 0} { incr bad }
  }
  return $bad
}
check {S6 every prose comment line inside is_xschem_file is brace-balanced} \
  [comment_brace_faults $RAW {##}] 0
## Net balance over ALL the proc's comment lines taken together: this is the
## property that actually has to hold for the proc to parse.
proc comment_block_balance {body} {
  set d 0
  foreach l [split $body "\n"] {
    if {![regexp {^[ \t]*#} $l]} { continue }
    foreach c [split $l {}] {
      if {$c eq "\{"} { incr d } elseif {$c eq "\}"} { incr d -1 }
    }
  }
  return $d
}
check {S6b the comment lines of is_xschem_file are brace-balanced as a block} \
  [comment_block_balance $RAW] 0

## ⚠ S7/S8 ARE THE ROWS THAT MAKE THE ANCHOR CORRECT RATHER THAN MERELY
## ANCHORED. The Tcl strip must be the SAME GRAMMAR as `is_generator` in
## src/token.c -- the function save.c and paste.c consult before they popen a
## name. If somebody widens or narrows the C ERE and leaves the Tcl alone, the
## two fall out of step and a name is opened by the wrong mechanism. Both
## literals are read out of their own file.
set TOKSRC [slurp $TOKC]
set CERE {}
foreach l [split $TOKSRC "\n"] {
  if {[regexp {regcomp\(re, "([^"]*)"} $l -> m]} { set CERE $m ; break }
}
check_true {S7 the is_generator ERE was found in src/token.c} [expr {$CERE ne {}}]
## C string literal -> regex source: a doubled backslash is one backslash.
set CERE_RX [string map {\\\\ \\} $CERE]
## The Tcl pattern with its capture group taken off the head is the same string.
set TCLPAT {}
foreach l [split $BODY "\n"] {
  if {[regexp {^[ \t]*regsub[ \t]+\{(.*)\}[ \t]+\$f[ \t]} $l -> m]} { set TCLPAT $m ; break }
}
set TCLPAT_NOCAP [string map {([^\ \\t()]+) [^\ \\t()]+} $TCLPAT]
check {S8 the shipped Tcl strip is token.c is_generator character for character} \
  $TCLPAT_NOCAP $CERE_RX

# ===========================================================================
# SECTION G -- GRAMMAR. Both arms. The strip is taken OUT OF THE SHIPPED FILE
# and run over a table of names; `xschem is_generator` is the oracle.
# ===========================================================================
## ⚠ NOT A COPY OF THE PATTERN. A row carrying its own copy of the regsub would
## stay green while the product stayed broken. This builds a proc whose body is
## the shipped line, lifted verbatim out of is_xschem_file.
set STRIPLINE {}
foreach l [split $BODY "\n"] {
  if {[regexp {^[ \t]*regsub[ \t]} $l]} { set STRIPLINE [string trim $l] ; break }
}
check_true {G1 the strip line was lifted out of the shipped is_xschem_file} \
  [expr {$STRIPLINE ne {}}]
## `format` does no Tcl substitution, so `$f` in the body survives to call time.
proc shipped_strip {f} [format {%s ; return $f} $STRIPLINE]
## The OLD spelling, for G16. Kept here deliberately: it is the thing that must
## NOT be in the product, so a copy in the test is the right place for it.
proc old_strip {f} { regsub {\(.*} $f {} f ; return $f }

## Column 2 is what `xschem is_generator` answers; measured, not assumed.
set GTAB {
  {G2  {gen.tcl(a,b)}            1}
  {G3  {gen.tcl()}               1}
  {G4  {gen.tcl(inv,1200)}       1}
  {G5  {gen.tcl(a,b) }           1}
  {G6  {bandgap(rev2).sch}       0}
  {G7  {foo (1).sch}             0}
  {G8  {opamp(v3)_final.sym}     0}
  {G9  {plain.sch}               0}
  {G10 {gen.tcl}                 0}
  {G11 {gen.tcl((a))}            0}
  {G12 {a(b)c(d)}                0}
  {G13 {gen.tcl(a,b)x}           0}
  {G14 {foo.sym)}                0}
}
set disagree 0
foreach row $GTAB {
  foreach {rid nm exp} $row break
  set cg [xschem is_generator $nm]
  check "$rid xschem is_generator |$nm|" $cg $exp
  ## The strip must fire exactly when C calls it a generator, and not otherwise.
  set stripped [shipped_strip $nm]
  set fired [expr {$stripped ne $nm}]
  if {$fired != $cg} { incr disagree }
}
check {G15 the shipped strip fires exactly when xschem is_generator says so} \
  $disagree 0
## ⚠ WITHOUT G16 THE ROW ABOVE LOOKS LIKE SOMETHING ANY PATTERN WOULD PASS.
set olddisagree 0
foreach row $GTAB {
  foreach {rid nm exp} $row break
  set fired [expr {[old_strip $nm] ne $nm}]
  if {$fired != [xschem is_generator $nm]} { incr olddisagree }
}
check_true {G16 the OLD unanchored pattern does NOT agree with xschem is_generator} \
  [expr {$olddisagree > 0}]
## The head of a real generator invocation survives the strip intact.
check {G17 the strip leaves the generator path itself alone} \
  [shipped_strip {/lib/gen.tcl(inv,1200)}] {/lib/gen.tcl}
check {G18 the strip takes trailing whitespace off with the argument list} \
  [shipped_strip "/lib/gen.tcl(a,b) "] {/lib/gen.tcl}

# ===========================================================================
# SECTION F -- FUNCTIONAL. Both arms. Real files with real names on disk,
# through the real is_xschem_file. THIS IS THE DEFECT.
# ===========================================================================
set scratch [test_scratch genparen]
set proto_sch [file join $repo xschem_library generators my_inv.sch]
set proto_sym [file join $repo xschem_library generators my_inv.sym]
set proto_gen [file join $repo xschem_library generators symbolgen.tcl]
check_true {F1 the shipped fixtures used by this section are present} \
  [expr {[file exists $proto_sch] && [file exists $proto_sym]
      && [file exists $proto_gen]}]

set V_PAREN  [file join $scratch {bandgap(rev2).sch}]
set V_SPACE  [file join $scratch {foo (1).sch}]
set V_MID    [file join $scratch {opamp(v3)_final.sym}]
set V_PLAIN  [file join $scratch {plain.sch}]
set V_GEN    [file join $scratch gen.tcl]
file copy -force $proto_sch $V_PAREN
file copy -force $proto_sch $V_SPACE
file copy -force $proto_sch $V_PLAIN
file copy -force $proto_sym $V_MID
file copy -force $proto_gen $V_GEN

## ⚠ WITHOUT F2 THE ROWS BELOW COULD PASS BY NOT HAPPENING: a missing file is
## answered 0 by design, and "0" is also what the defect produced.
check_true {F2 every fixture really landed on disk under its parenthesised name} \
  [expr {[file exists $V_PAREN] && [file exists $V_SPACE]
      && [file exists $V_MID]   && [file exists $V_PLAIN]
      && [file exists $V_GEN]}]

## The three names from the issue's own measured table.
check {F3 a schematic named bandgap(rev2).sch is a SCHEMATIC} \
  [is_xschem_file $V_PAREN] SCHEMATIC
check {F4 a schematic named foo (1).sch is a SCHEMATIC} \
  [is_xschem_file $V_SPACE] SCHEMATIC
check {F5 a symbol named opamp(v3)_final.sym is a SYMBOL} \
  [is_xschem_file $V_MID] SYMBOL
check {F6 an ordinary name is unaffected} [is_xschem_file $V_PLAIN] SCHEMATIC

## The case the strip is FOR. All three generator spellings still work, or the
## fix has traded one defect for a worse one.
## ⚠ THE BRACES ROUND THE VARIABLE NAME ARE LOAD-BEARING: a bare $V_GEN(a,b)
## is an ARRAY REFERENCE to Tcl, not a name with an argument list after it.
check {F7 a generator with arguments is still a GENERATOR} \
  [is_xschem_file "${V_GEN}(inv,1200)"] GENERATOR
check {F8 a generator with an empty argument list is still a GENERATOR} \
  [is_xschem_file "${V_GEN}()"] GENERATOR
## save.c load_schematic and actions.c place_symbol call this proc on a BARE
## generator path and append the empty argument list themselves once the answer
## comes back GENERATOR, so the absent list must be left alone.
check {F9 a generator with NO argument list at all is still a GENERATOR} \
  [is_xschem_file $V_GEN] GENERATOR

## Failing closed still has to work.
check {F10 a name that resolves nowhere is still 0} \
  [is_xschem_file [file join $scratch {nothere(x).sch}]] 0
check {F11 a directory is still 0} [is_xschem_file $scratch] 0
## ⚠ F12/F13 ARE THE RESIDUAL LIMIT, AND THEY ARE HERE SO NOBODY DISCOVERS IT
## AS A SURPRISE. A name that is ENTIRELY head-then-parenthesised-list, with
## NOTHING after the closing parenthesis -- `rev(2)`, no extension -- is a
## generator invocation to token.c is_generator, and the two cases are not
## distinguishable by spelling. It is answered as a generator, so a FILE by
## that exact name is still reported 0. This is not the 1604 defect: an
## extension, or any other character after the closing parenthesis, takes the
## name out of the grammar, which is why F3, F4 and F5 pass. Widening this
## would mean changing the C ERE, and then the Tcl and the C would have to move
## together -- see S8.
set V_TAIL [file join $scratch {rev(2)}]
file copy -force $proto_sch $V_TAIL
check {F12 a name that is entirely head-then-arguments IS a generator to token.c} \
  [xschem is_generator $V_TAIL] 1
check {F13 is_xschem_file agrees with token.c on that name rather than guessing} \
  [is_xschem_file $V_TAIL] 0

# ===========================================================================
# SECTION D -- THE INSERT DIALOG. DISPLAY ARM ONLY.
# ===========================================================================
set DROWS {D1/D2/D3/D4/D5}
if {![info exists ::has_x] || !$::has_x} {
  skiprow $DROWS "these rows build a real Tk listbox and call the Insert\
 dialog's own procs on it; toplevel and listbox do not exist under --nogui, so\
 the arm that measures them is the display one, spelled\
 tests/headless/run_suites.sh test_generator_paren_1604"
} else {

## The same fake `.ins` tree test_preview_name_inject_1601.tcl builds: the real
## procs read these widget paths, and building them is cheaper and far less
## likely to wedge than driving the shipped modal.
catch {destroy .ins}
toplevel .ins
frame .ins.center
frame .ins.center.right -width 200 -height 200
frame .ins.center.left
listbox .ins.center.left.l
pack .ins.center ; pack .ins.center.left ; pack .ins.center.left.l
pack .ins.center.right
update idletasks

set ::file_chooser(fullpathlist) [list $V_PAREN $V_MID]
.ins.center.left.l insert end [file tail $V_PAREN] [file tail $V_MID]

## Spy on file_chooser_place: the issue's first named cost is that it never
## runs. Placing for real would mutate the loaded schematic, and the branch is
## what is under test, so the call is recorded instead.
rename file_chooser_place __fcp_real_1604
proc file_chooser_place {action} { lappend ::D_PLACED $action }

set ::D_PLACED {}
.ins.center.left.l activate 0
## ⚠ THE CODE, NOT THE MESSAGE. `catch` stores the proc's RETURN VALUE in the
## variable when nothing was raised, so comparing that variable to the empty
## string tests nothing useful -- it reddened on the perfectly good value
## `load`. The return code is the thing that says whether it threw.
set D_RC1 [catch {file_chooser_symbol_or_schematic 0} D_ERR1]
check {D1 selecting bandgap(rev2).sch in the Insert dialog places it} \
  $::D_PLACED {load}
check {D2 no error was raised getting there} [list $D_RC1 $D_ERR1] [list 0 {load}]

set ::D_PLACED {}
catch {file_chooser_symbol_or_schematic 1}
check {D3 shift-selecting bandgap(rev2).sch opens it in a new window} \
  $::D_PLACED {load_new_win}

## The symbol branch: a .sym with a parenthesis mid-name reaches the SYMBOL arm.
set ::D_PLACED {}
catch {unset ::file_chooser(action)}
.ins.center.left.l activate 1
catch {file_chooser_symbol_or_schematic 0}
check {D4 selecting opamp(v3)_final.sym reaches the symbol branch} \
  [expr {[info exists ::file_chooser(action)] ? $::file_chooser(action) : {NONE}}] \
  {symbol1}

## The issue's second named cost: the preview is gated on the type not being 0,
## and abs_filename is set only inside that gate.
rename file_chooser_preview __fcprev_real_1604
proc file_chooser_preview {} { __fcprev_real_1604 }
catch {unset ::file_chooser(abs_filename)}
catch {unset ::file_chooser(f)}
.ins.center.left.l selection clear 0 end
.ins.center.left.l selection set 0
catch {__fcprev_real_1604}
## Cancel the 200 ms preview redraw this schedules, so nothing draws after the
## widgets below are destroyed.
catch {after cancel [list file_chooser_draw_preview $V_PAREN]}
catch {after cancel {.ins.center.right configure -bg white}}
check {D5 the Insert preview gate opens for bandgap(rev2).sch} \
  [expr {[info exists ::file_chooser(abs_filename)]
         ? $::file_chooser(abs_filename) : {NOTSET}}] $V_PAREN

catch {rename file_chooser_place {}}
catch {rename __fcp_real_1604 file_chooser_place}
catch {rename file_chooser_preview {}}
catch {rename __fcprev_real_1604 file_chooser_preview}
catch {destroy .ins}

}
# --- verdict ---------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
## Both sentinels: run_suites.sh scores `RESULT: ALL PASS`, tests/banner_rule.tcl
## -- the rule run_regression.tcl consumes -- scores ONLY a whole-line
## `OVERALL: ok`. A suite printing one of them is scored a HARNESS FAILURE by
## the other however many of its own checks passed.
if {$fail == 0} {
  puts "OVERALL: ok"
} else {
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
