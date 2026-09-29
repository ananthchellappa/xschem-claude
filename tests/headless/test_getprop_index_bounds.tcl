# Issue 0077 regression: `xschem getprop wire` / `getprop rect` must bounds-check the
# caller-supplied index before subscripting xctx->wire[n] / xctx->rect[c][n]. Before the
# fix an out-of-range index did an OOB heap read -> SIGSEGV -> emergency-save -> editor died
# (crash / memory disclosure). getprop text was already safe (get_text upper-bounds).
#
# Reaching "OVERALL: ok" is itself the core assertion: an OOB read on any form below crashes
# the process before the sentinel and run_regression scores it FAIL.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_getprop_index_bounds.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# Give the happy path real objects to read: one wire (index 0) and one rect on layer 4.
xschem wire 0 0 100 0
xschem rect 4 0 0 50 50
check "wire created"  [expr {[xschem get wires] >= 1}] 1

# Valid in-range reads must still succeed (no regression of the happy path).
check "valid getprop wire 0"      [catch {xschem getprop wire 0 lab}]   0
check "valid getprop rect 4 0"    [catch {xschem getprop rect 4 0 dash}] 0

# Out-of-range indices must ERROR (not OOB-read / crash).
foreach {label cmd} {
  "wire index too big"   {xschem getprop wire 999999 lab}
  "wire index negative"  {xschem getprop wire -1 lab}
  "rect layer negative"  {xschem getprop rect -1 0 dash}
  "rect layer too big"   {xschem getprop rect 9999 0 dash}
  "rect index too big"   {xschem getprop rect 4 999999 dash}
} {
  check "oob errors: $label" [catch $cmd] 1
}

# ============================================================================
# Issue 1618 band -- the object types `getprop` could not read.
#
# Two gaps, one arm chain. Before 1618 the `getprop` else-if chain in
# xschem_cmds_g() had NO arm for line / poly / arc, and the chain has no
# terminating `else`: an unmatched argv[2] fell out of every arm and returned
# TCL_OK with an EMPTY result. `setprop` has had line/arc/poly arms since audit
# 0063, so the defect was an ASYMMETRY -- Tcl could write a line/poly/arc
# property and could not read it back. Separately, rect/text/wire could only be
# read one token at a time: omitting the token was an arity error, so
# `xschem list_tokens` could enumerate an instance's properties and nothing
# else's.
#
# ⚠ A row shaped "it errors today, it must succeed tomorrow" was ALREADY GREEN
# on the broken tree, because `catch` returned 0 before and after. Every row
# below asserts the returned VALUE, or asserts that a bad layer/index now RAISES
# where it used to be silent. (batch DECISIONS.md D3/D4.)
#
# This band was run against the tree BEFORE the fix -- in an isolated
# `git archive HEAD` checkout configured and built from scratch, so no other
# crew's in-flight edits to the shared tree could colour the result -- and scored
# `RESULT: 63 FAILED (40 passed)`. 63 of its rows are therefore demonstrated
# fences and not decoration. A sample of what the broken tree printed:
#   getprop line 4 0 aa      -> {}                      (want L)
#   getprop line 4 0         -> {}                      (want "aa=L bb=2")
#   getprop rect 4 1         -> ERR(xschem getprop rect needs <color> <n> <token>)
#   getprop wire 1           -> ERR(xschem getprop wire needs <n> <token>)
#   getprop text 0           -> ERR(xschem getprop text needs <n> <token>)
#   getprop line 99 0 zz     -> catch rc 0              (want 1)
#   getprop line             -> catch rc 0              (want 1)
#   setprop line 4 0 zz 9 ; getprop line 4 0 zz -> {}   (want 9)
#   catch {xschem getprop}   -> ...|wire|symbol|text|rect   (no line, poly or arc)
#
# The rows that were NOT red, and are here for a different reason: the seven
# "widened arm still range-checks with the token omitted" rows passed on the
# broken tree for the WRONG reason (it rejected them on arity before it could get
# the range wrong), and they earn their place by reddening a sabotage instead --
# see the sabotage note above each block.
# ============================================================================

# A row must FAIL, not THROW. Every value row goes through xv, which turns a
# raised error into a legible sentinel instead of aborting the suite at file
# scope and hiding every row after it. xrc is the deliberate opposite: it IS the
# assertion for the bounds and arity rows.
proc xv  {args} { if {[catch {uplevel 1 [list xschem {*}$args]} r]} { return "ERR($r)" }; return $r }
proc xrc {args} { return [catch {uplevel 1 [list xschem {*}$args]}] }

# --- fixture -------------------------------------------------------------
# The layer is `rectcolor` (4) for line/polygon/rect/wire but an explicit 6th
# DATA argument for arc: `xschem arc 200 200 25 0 360` with no layer silently
# creates nothing and returns 1. `xschem text`'s order is
# <x> <y> <rot> <flip> <txt> <props> <scale> <layer>, not the .sch record order.
# An appended object (pos -1) lands at the index equal to the count BEFORE the
# call, so every index below is captured that way rather than assumed -- a
# fixture that failed to create then shows up as its own F row instead of as a
# wrong read. The 0077 rect/wire above are NOT reused: this band makes its own
# prop-less pair, so it does not depend on whether those two carry attributes.
proc nobj {ty args} { return [llength [xv objects -type $ty {*}$args]] }
proc mk {idxvar ty args} {
  upvar 1 $idxvar v
  if {$ty eq "text"} { set v [nobj text] } \
  elseif {$ty eq "wire"} { set v [nobj wire] } \
  else { set v [nobj $ty -layer 4] }
  uplevel 1 $args
}
# Every type carries a DISTINCT value for `aa`, so a copy-paste slip that reads
# the wrong xctx array -- the poly arm subscripting xctx->line, say -- reddens
# instead of agreeing with its sibling. An earlier draft of this band gave all
# three the same attribute string and would have passed that sabotage.
mk g_line line  xschem line    0    0 100   0 -1 {aa=L bb=2}
mk g_lnul line  xschem line    0  200 100 200 -1 {}
mk g_poly poly  xschem polygon 0 100 50 150 100 100 {aa=P bb=2}
mk g_arc  arc   xschem arc     200 200 25 0 360 4 {aa=A bb=2}
mk g_rect rect  xschem rect    300 0 350 50 -1 {aa=R bb=2}
mk g_rnul rect  xschem rect    600 0 650 50 -1 {}
mk g_wire wire  xschem wire    400 0 400 100 -1 {aa=W bb=2}
mk g_wnul wire  xschem wire    700 0 700 100 -1 {}
mk g_text text  xschem text    500 500 0 0 {hello} {aa=T bb=2} 0.4 0
mk g_tnul text  xschem text    500 600 0 0 {bare}  {}          0.4 0

foreach {ty sel} [list line #4,$g_line line #4,$g_lnul poly #4,$g_poly \
                       arc #4,$g_arc rect #4,$g_rect rect #4,$g_rnul] {
  check "1618 fixture: $ty $sel was really created" [expr {[xv object $ty $sel] ne {}}] 1
}
check "1618 fixture: both extra wires were really created" \
  [expr {[xv object wire #$g_wire] ne {} && [xv object wire #$g_wnul] ne {}}] 1
check "1618 fixture: both text objects were really created" \
  [expr {[xv object text #$g_text] ne {} && [xv object text #$g_tnul] ne {}}] 1

# --- the whole-property-string form (token omitted) -----------------------
# Runs BEFORE any setprop below, so the expected value is byte-identical to the
# string handed to the creation verb.
foreach {ty ref exp} [list line [list 4 $g_line] {aa=L bb=2} \
                           poly [list 4 $g_poly] {aa=P bb=2} \
                           arc  [list 4 $g_arc]  {aa=A bb=2} \
                           rect [list 4 $g_rect] {aa=R bb=2}] {
  check "1618 token omitted: getprop $ty $ref returns prop_ptr verbatim" \
    [xv getprop $ty {*}$ref] $exp
}
check "1618 token omitted: getprop wire returns prop_ptr verbatim" [xv getprop wire $g_wire] {aa=W bb=2}
check "1618 token omitted: getprop text returns prop_ptr verbatim" [xv getprop text $g_text] {aa=T bb=2}

# The same discrimination in the TOKEN path, which is a separate line of code.
foreach {ty exp} {line L poly P arc A} {
  check "1618 $ty token read comes from the $ty array, not a sibling's" \
    [xv getprop $ty 4 [set g_$ty] aa] $exp
}

# A prop-less object has prop_ptr == NULL (my_strdup maps "" -> NULL), so the
# whole-string form must answer the empty string for it rather than a stale value,
# the literal "(null)", or the previous result left in the interpreter.
#
# ⚠ These are VALUE rows, not crash fences, and the distinction was measured, not
# assumed: sabotaging all four `prop ? prop : ""` guards away -- handing raw NULL
# to Tcl_SetResult(..., TCL_VOLATILE) -- left this suite at ALL PASS with no
# signal 11. Tcl_SetResult tolerates a NULL string and answers {}, which is why
# the shipped instance/symbol arms have always passed prop_ptr straight through.
# The guards are kept for intent, not because Tcl needs them; do not cite these
# rows as proof that a missing guard would be caught, because it would not.
#
# Of the four, three were reds: the broken tree answered an arity error for rect,
# wire and text. The line row was vacuous (the broken tree also answered {}).
check "1618 prop-less line: token omitted answers empty, not a stale value" [xv getprop line 4 $g_lnul] {}
check "1618 prop-less rect: token omitted answers empty, not a stale value" [xv getprop rect 4 $g_rnul] {}
check "1618 prop-less wire: token omitted answers empty, not a stale value" [xv getprop wire $g_wnul] {}
check "1618 prop-less text: token omitted answers empty, not a stale value" [xv getprop text $g_tnul] {}

# --- the payoff: enumeration now reaches more than instance and symbol ----
# The whole-string form exists so `xschem list_tokens` can NAME an object's
# attributes, which is what wish-list item 21 actually asks for. Before 1618 this
# chain answered {} for every type but instance and symbol, because the middle
# step could not be spelled. Placed here, before the setprop rows below mutate
# the attribute strings, so every object still carries exactly `aa` and `bb`.
foreach {ty ref} [list line [list 4 $g_line] poly [list 4 $g_poly] \
                       arc [list 4 $g_arc] rect [list 4 $g_rect]] {
  check "1618 list_tokens enumerates a $ty's attributes through the whole-string form" \
    [lsort [xv list_tokens [xv getprop $ty {*}$ref] 0]] {aa bb}
}
check "1618 list_tokens enumerates a wire's attributes through the whole-string form" \
  [lsort [xv list_tokens [xv getprop wire $g_wire] 0]] {aa bb}
check "1618 list_tokens enumerates a text's attributes through the whole-string form" \
  [lsort [xv list_tokens [xv getprop text $g_text] 0]] {aa bb}

# --- the write-then-read-back round trip (DECISIONS.md D4) ----------------
foreach {ty val} {line 9 poly 8 arc 7} {
  check "1618 $ty: the shipped setprop write path still accepts the token" \
    [xrc setprop $ty 4 [set g_$ty] zz $val] 0
  check "1618 $ty round trip: getprop reads back what setprop wrote" \
    [xv getprop $ty 4 [set g_$ty] zz] $val
}

# --- with_quotes is optional argv[6] defaulting to 0, copying the rect arm --
# Asserted against the rect arm's own answer for the same stored value, so the
# row cannot be wrong about the quoting spelling; the literal control row below
# stops it passing vacuously if the rect arm itself breaks.
foreach ty {line poly arc} { xschem setprop $ty 4 [set g_$ty] fmt {a b} }
xschem setprop rect 4 $g_rect fmt {a b}
check "1618 with_quotes control: the rect arm answers 'a b' unquoted" [xv getprop rect 4 $g_rect fmt] {a b}
foreach ty {line poly arc} {
  check "1618 $ty with_quotes omitted answers as the rect arm does" \
    [xv getprop $ty 4 [set g_$ty] fmt] [xv getprop rect 4 $g_rect fmt]
  check "1618 $ty with_quotes=1 answers as the rect arm does" \
    [xv getprop $ty 4 [set g_$ty] fmt 1] [xv getprop rect 4 $g_rect fmt 1]
}

# --- a bad layer/index must ERROR, not answer silently --------------------
# Consistent with the erroring majority of the shipped arms (instance, symbol,
# rect, text and wire all error; instance_pin's silent {} is the outlier and is
# not the model) and with setprop line/arc/poly. BOTH argument shapes, because a
# bounds check written only inside the token branch leaves the whole-string form
# reading out of range.
foreach ty {line poly arc} {
  foreach {lbl ref} {{layer negative} {-1 0} {layer past cadlayers} {9999 0}
                     {index past the count} {4 999999} {index negative} {4 -1}} {
    check "1618 $ty oob raises with a token: $lbl"   [xrc getprop $ty {*}$ref zz] 1
    check "1618 $ty oob raises, token omitted: $lbl" [xrc getprop $ty {*}$ref]    1
  }
}

# The boundary itself: an index EQUAL to the live count must raise. Layer 4 holds
# a different number of each type, so a count mix-up -- the poly arm range-checking
# against xctx->rects[c] instead of xctx->polygons[c] -- passes every 999999 row
# above and fails only here.
foreach {ty n} [list line [nobj line -layer 4] poly [nobj poly -layer 4] \
                     arc [nobj arc -layer 4] rect [nobj rect -layer 4]] {
  check "1618 $ty: an index equal to the live count raises, not just 999999" [xrc getprop $ty 4 $n] 1
}
check "1618 wire: an index equal to the live count raises" [xrc getprop wire [nobj wire]] 1

# The widening moved the rect/text/wire arity floor down by one, so the issue
# 0077 guard now has a second argument shape to cover. These rows exist because
# the obvious wrong way to add the whole-string form is to put it in an `argc`
# branch ABOVE the range check rather than below it -- the 0077 rows at the top
# of this file only ever pass a token and would all still be green.
foreach {lbl cmd} {
  {rect layer negative}       {getprop rect -1 0}
  {rect layer past cadlayers} {getprop rect 9999 0}
  {rect index past the count} {getprop rect 4 999999}
  {rect index negative}       {getprop rect 4 -1}
  {wire index past the count} {getprop wire 999999}
  {wire index negative}       {getprop wire -1}
  {text index past the count} {getprop text 999999}
} {
  check "1618 widened arm still range-checks with the token omitted: $lbl" [xrc {*}$cmd] 1
}

# --- arity: too few arguments must raise, not answer silently -------------
foreach ty {line poly arc} {
  check "1618 $ty arity: <layer> with no index raises"  [xrc getprop $ty 4] 1
  check "1618 $ty arity: no layer and no index raises"  [xrc getprop $ty]   1
}

# --- the arm list in the no-subcommand message is a promise ---------------
# Adding arms without extending it makes it a lie; it is the only place the
# dispatcher states which types it serves.
set g_armmsg {}; catch {xschem getprop} g_armmsg
foreach ty {instance instance_pin wire symbol text rect line poly arc} {
  check "1618 arm-list message names $ty" [expr {[string first $ty $g_armmsg] >= 0}] 1
}

# --- no regression of the token-only reads the widening touched ----------
check "1618 no regression: getprop text pseudo-token txt_ptr still answers" [xv getprop text $g_text txt_ptr] {hello}
check "1618 no regression: getprop text token read still answers"           [xv getprop text $g_text aa] T
check "1618 no regression: getprop rect token read still answers"           [xv getprop rect 4 $g_rect aa] R
check "1618 no regression: getprop wire token read still answers"           [xv getprop wire $g_wire aa] W

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
