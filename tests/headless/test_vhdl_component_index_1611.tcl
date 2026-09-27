# tests/headless/test_vhdl_component_index_1611.tcl
#
# ISSUE 1611 -- the VHDL component-declaration loop tested the PARENT symbol, so
# `xschem_libs` was honoured at the top level and silently dropped one level down.
#
# `vhdl_block_netlist()` in src/vhdl_netlist.c takes the block being expanded as
# its parameter **`i`**, and its component-declaration loop walks the CANDIDATE
# components as **`j`**. Every access in that loop is about a candidate, so every
# access must be `j`, and row P6 asserts there is not one `xctx->sym[i]` left in
# it. Two used to be -- they read the parent while claiming to filter the
# candidate:
#
#   * the `default_schematic` read. This half was DEAD CODE: the function tests
#     the parent's own `default_schematic` near its top and returns early, so
#     the in-loop copy could only re-read a value already checked. The visible
#     consequence was that `default_schematic=ignore` on a COMPONENT had no
#     effect -- the component was declared anyway.
#   * the `abs_path` handed to `check_lib(1, abs_path)`. This is the half a user
#     sees. `check_lib()` (src/netlist.c) is what makes `xschem_libs` -- the list
#     of libraries NOT to netlist or export -- exclude anything. Handed the
#     PARENT's path it always passed, because the parent had already passed the
#     identical test in the caller.
#
# Both are symbol-index-for-symbol-index, so neither could leave the array: a
# logic defect, not a memory defect.
#
# A THREE-LEVEL FIXTURE IS MANDATORY, AND THAT IS THIS SUITE'S CENTRAL LIMIT.
# With a two-level fixture the block being expanded IS the only candidate the
# loop ever reaches, `i` and `j` coincide, and the suite measures NOTHING: every
# row below would pass on the defective code. So the fixture authored in
# `test_scratch` is `top` -> `midl`/`midd` -> `plug`/`keep`/`dsi`/`dsn`, and row
# L7 asserts the depth is really there by reading the emitted entity list. If
# L7 ever reddens, believe it before believing any other row in this file: it
# means the fixture collapsed and the rest of the suite went blind rather than
# red.
#
# THE INSTRUMENT ASSERTS THE CORRECT SHAPE, NOT THE ABSENCE OF A STRING.
# Every driven row states the WHOLE ordered component list of the architecture
# it is about -- what must be declared as well as what must not. CLAUDE.md's
# rule is the reason: a fence keyed to the absence of one symptom dies quietly
# when something else cures the symptom, and here the something else is cheap --
# an empty netlist, a fixture that failed to load, a netlist run that errored
# out before the mid level. A row spelled "`component plug` is absent" would go
# green for all three. "`arch_midl` declares exactly {keep}" cannot.
#
# WHAT THIS SUITE DELIBERATELY PINS AS A RESIDUAL, NOT AS THE FIX (row L5).
# Suppressing a component DECLARATION does not suppress the INSTANTIATION: the
# instance loop lives in the static `vhdl_netlist()` and never consults
# `check_lib()`. So an excluded child is still written `xplug1 : plug port map
# (...)`, naming an entity the file does not emit. That is NOT a regression and
# NOT this fix: it is exactly what the top level has always done for a child
# excluded there (row L6 measures the top level doing it), and the fix makes the
# two levels agree. It is written as a row so that the day somebody changes it,
# a test says so instead of a reader guessing. Whether the emitted file is
# REJECTED by a VHDL analyser is **derived, never driven**: there is no `ghdl`
# and no `nvc` on the machine this was written on. What is driven is that the
# file names an entity it does not emit.
#
# SECTIONS
#   L1-L8   THE check_lib HALF, driven. L1/L2 are the subject and its control:
#           the same three-level fixture with and without an `xschem_libs`
#           entry matching the leaf's directory. L3/L4 pin that the leaf really
#           is netlisted when nothing excludes it, so L2 cannot pass vacuously.
#           L5 is the residual described above. L6 is the TOP-LEVEL reference:
#           the loop in `global_vhdl_netlist()` that always spelled this `j`.
#           L7 is the three-level guard and L8 the two-level limit it exists
#           to prevent.
#   D1-D4   THE default_schematic HALF, driven. `dsi` and `dsn` are the same
#           symbol except that `dsi` carries `default_schematic=ignore`, and
#           both are instanced in the same architecture, so ONE netlist run
#           answers both the subject and its control. D3 proves the instance
#           was there to be declared. D4 fences the parent-level early return
#           the in-loop read was shadowing, which must keep working.
#   P1-P6   STRUCTURAL, the PATTERN TRAP. `global_vhdl_netlist()`'s descent loop
#           makes the same `check_lib(1, abs_path)` call and `i` is CORRECT
#           there -- commit 242523cb, titled "typo fix", changed that one from
#           `j` to `i`. The two loops need OPPOSITE answers. A reader who greps
#           for the pattern and "fixes" both reintroduces a different defect, so
#           P1 states the spelling of EVERY `abs_sym_path(xctx->sym[..].name`
#           site in the file together with the `for(` header it sits under, P5
#           does the same for every `default_schematic` read, and P2 requires the
#           warning naming 242523cb to still stand above the site it defends.
#           P3/P4 are the peer back ends, and P6 is the whole-loop invariant:
#           NOT ONE `xctx->sym[i]` inside the component loop, which is the one
#           structural row both halves of the fix redden. Each P row is named for
#           THE TEXT IT GREPS and claims no count of what escapes it.
#
# ⚠ P6 ASSERTS ZERO, NOT A TOTAL, AND THAT IS ON PURPOSE. Issue 1611 and the
# shipped comment at the fixed site both say the loop has "sixteen accesses,
# fourteen of them `j`". Counted on the comment-stripped loop region while
# writing this suite, it is FIFTEEN accesses, thirteen of which were `j` -- the
# hand count drifted by one, and `grep -c` answers 13 because it counts LINES,
# not occurrences. A row that quoted any of those three numbers would redden the
# next time somebody adds an unrelated line to the loop. Zero `sym[i]` is the
# real invariant: exact, unaffected by innocent edits, and reddened by either
# revert.
#
# WHICH ROWS REDDEN, AND WHICH ARE CONTROLS THAT MUST NOT. Measured 2026-09-27 by
# reverting each fixed access to `sym[i]` ALONE, rebuilding, and rerunning:
#
#   revert the `abs_path` read           -> L2  L4  P1  P2  P6   redden
#   revert the `default_schematic` read  -> L4  D1  P5  P6       redden
#
# L4 and P6 are the two rows both sabotages reach: L4 because it states both
# mid-level component lists in one answer, P6 because it is the whole-loop
# invariant. L1, L3, L5, L6, L7, L8, D2, D3, D4, P3 and P4 redden under NEITHER,
# and that is correct: they are the fixture's depth guard, the controls that stop
# the subject rows passing vacuously, the residual, the two-level limit and the
# peer back ends. Reading their greenness as evidence about the fix would be
# reading the wrong rows -- test_generator_shell_1610's section A says the same
# thing about its neutrality rows. L8 is the extreme case: its answer was
# measured to be IDENTICAL on the fixed tree and on both reverts, which is the
# whole argument for the three-level fixture.
#
# ARMED SPELLING
#   tests/headless/run_suites.sh --nogui test_vhdl_component_index_1611
# Nothing here needs a display: the whole suite is a netlist run and a read of
# src/vhdl_netlist.c. It belongs in `hcases` only, which costs one case and no
# skip. Registering it is the driver's job, not this file's.
#
# FLOOR: 18 checks (12 driven -- L1-L8 and D1-D4 -- plus 6 structural). The same
# 18 on both display arms; nothing in this file asks for a widget. Measured
# 2026-09-27. RAISED, NEVER LOWERED.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc skiprow {names why} { puts "skip: $names -- $why" ; flush stdout }

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]

set scratch [test_scratch vhdlcompidx]
set VHDLC [file join $repo src vhdl_netlist.c]

proc slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
proc wfile {path text} {
  set fp [open $path w] ; puts $fp $text ; close $fp
  return $path
}

#############################################################################
## Readers over the EMITTED netlist. Each one answers a ZZ... sentinel rather
## than an empty list when the thing it was asked for is not in the file, so
## no row can pass by finding nothing.
#############################################################################

## Ordered entity names, in the order the file declares them.
proc entities {txt} {
  if {$txt eq "ZZNOFILE"} { return ZZNOFILE }
  set out {}
  foreach l [split $txt "\n"] {
    if {[regexp {^entity[ \t]+(\S+)[ \t]+is[ \t]*$} $l -> n]} { lappend out $n }
  }
  return $out
}

## The ordered `component <name>` list declared inside the architecture of
## entity <ent>, i.e. between `architecture arch_<ent> of <ent> is` and the
## `begin` that closes the declarative part. ZZNOARCH if that architecture is
## not in the file at all.
proc comps_of {txt ent} {
  if {$txt eq "ZZNOFILE"} { return ZZNOFILE }
  set in 0 ; set out {} ; set seen 0
  foreach l [split $txt "\n"] {
    if {[regexp {^architecture[ \t]+\S+[ \t]+of[ \t]+(\S+)[ \t]+is} $l -> e]} {
      set in [expr {$e eq $ent}]
      if {$in} { set seen 1 }
      continue
    }
    if {!$in} { continue }
    if {[regexp {^begin[ \t]*$} $l]} { set in 0 ; continue }
    if {[regexp {^component[ \t]+(\S+)} $l -> c]} { lappend out $c }
  }
  if {!$seen} { return ZZNOARCH }
  return $out
}

## The ordered `<inst> : <cell>` instantiations inside that architecture's
## statement part, i.e. after its `begin`. ZZNOARCH as above.
proc insts_of {txt ent} {
  if {$txt eq "ZZNOFILE"} { return ZZNOFILE }
  set in 0 ; set body 0 ; set out {} ; set seen 0
  foreach l [split $txt "\n"] {
    if {[regexp {^architecture[ \t]+\S+[ \t]+of[ \t]+(\S+)[ \t]+is} $l -> e]} {
      set in [expr {$e eq $ent}] ; set body 0
      if {$in} { set seen 1 }
      continue
    }
    if {!$in} { continue }
    if {[regexp {^begin[ \t]*$} $l]} { set body 1 ; continue }
    if {[regexp {^end[ \t]+arch_} $l]} { set in 0 ; set body 0 ; continue }
    if {!$body} { continue }
    if {[regexp {^(\S+)[ \t]+:[ \t]+(\S+)[ \t]*$} $l -> a b]} { lappend out $a:$b }
  }
  if {!$seen} { return ZZNOARCH }
  return $out
}

#############################################################################
## THE FIXTURE. Three levels, authored here at run time -- nothing about it
## lives in the repository.
##
##   top.sch                     (the design)
##     x1611mids/midl.sym|.sch   parent of the check_lib pair
##       x1611excl/plug.sym      the EXCLUDED leaf   (subject)
##       x1611lib/keep.sym       the kept leaf       (control)
##     x1611mids/midd.sym|.sch   parent of the default_schematic pair
##       x1611lib/dsi.sym        carries default_schematic=ignore (subject)
##       x1611lib/dsn.sym        byte-identical but for that line (control)
##   top2.sch                    the TWO-level design, used by row L8 alone
##     x1611excl/plug.sym        the same excludable leaf, one level up
##
## The three directory names are deliberately unmistakable strings: the
## `xschem_libs` entries below are Tcl REGEXPS matched by check_lib() against
## the whole absolute symbol path, so a short pattern like `lib` would also
## match the scratch path, the repository path or a user's own tree.
#############################################################################
set EX   [file join $scratch x1611excl]
set LIB  [file join $scratch x1611lib]
set MIDS [file join $scratch x1611mids]
set OUT  [file join $scratch out]
foreach d [list $EX $LIB $MIDS $OUT] { file mkdir $d }

## A leaf symbol: one input pin, type=subcircuit, and a `template`. The
## template is NOT decoration -- print_generic() (src/token.c) returns without
## emitting the `component <name>` / `entity <name> is` header line for a
## symbol that has none, and vhdl.awk then prints the whole block verbatim
## because it never sees an `entity ... is` line to switch on. Measured while
## writing this suite: with the template omitted the emitted file carries an
## orphan `port ( ... ); end component ;` with no name on it, and comps_of
## above -- correctly -- reports an empty list for every architecture.
proc leaf_sym {path {extra {}}} {
  wfile $path "v \{xschem version=3.4.8RC file_version=1.3\}
G \{\}
K \{type=subcircuit${extra}
template=\"name=x1\"\}
V \{\}
S \{\}
F \{\}
E \{\}
L 4 -20 -20 20 -20 \{\}
L 4 20 -20 20 20 \{\}
L 4 20 20 -20 20 \{\}
L 4 -20 20 -20 -20 \{\}
B 5 -22.5 -2.5 -17.5 2.5 \{name=A dir=in\}
T \{@symname\} -20 -34 0 0 0.2 0.2 \{\}"
}

## A leaf schematic: the matching input pin and one named internal net, so the
## emitted architecture is non-empty and carries no auto-named signals.
proc leaf_sch {path lab} {
  wfile $path "v \{xschem version=3.4.8RC file_version=1.3\}
G \{\}
K \{\}
V \{\}
S \{\}
F \{\}
E \{\}
N 0 0 100 0 \{\}
C \{devices/ipin\} 0 0 0 0 \{name=pA lab=A\}
C \{devices/lab_wire\} 100 0 0 0 \{name=l0 lab=$lab\}"
}

leaf_sym [file join $EX  plug.sym] ; leaf_sch [file join $EX  plug.sch] PLUGNET
leaf_sym [file join $LIB keep.sym] ; leaf_sch [file join $LIB keep.sch] KEEPNET
## dsi and dsn differ in ONE property and nothing else.
leaf_sym [file join $LIB dsi.sym] "\ndefault_schematic=ignore"
leaf_sym [file join $LIB dsn.sym]
leaf_sch [file join $LIB dsi.sch] DSNET
leaf_sch [file join $LIB dsn.sch] DSNET

leaf_sym [file join $MIDS midl.sym]
leaf_sym [file join $MIDS midd.sym]

## midl: the check_lib pair. `plug` first so that a broken filter shows up as a
## LEADING extra element rather than a trailing one -- an off-by-one in the
## reader above could hide a trailing element, not a leading one.
wfile [file join $MIDS midl.sch] "v \{xschem version=3.4.8RC file_version=1.3\}
G \{\}
K \{\}
V \{\}
S \{\}
F \{\}
E \{\}
N 0 0 200 0 \{\}
N 200 0 200 -60 \{\}
N 200 -140 200 -200 \{\}
N 200 -260 200 -320 \{\}
C \{devices/ipin\} 0 0 0 0 \{name=pA lab=A\}
C \{devices/lab_wire\} 200 -60 0 0 \{name=lp lab=PLUGIN\}
C \{[file join $EX plug.sym]\} 200 -100 0 0 \{name=xplug1\}
C \{devices/lab_wire\} 200 -260 0 0 \{name=lk lab=KEEPIN\}
C \{[file join $LIB keep.sym]\} 200 -300 0 0 \{name=xkeep1\}"

## midd: the default_schematic pair, in the same design and the same run.
wfile [file join $MIDS midd.sch] "v \{xschem version=3.4.8RC file_version=1.3\}
G \{\}
K \{\}
V \{\}
S \{\}
F \{\}
E \{\}
N 0 0 200 0 \{\}
N 200 0 200 -60 \{\}
N 200 -140 200 -200 \{\}
N 200 -260 200 -320 \{\}
C \{devices/ipin\} 0 0 0 0 \{name=pA lab=A\}
C \{devices/lab_wire\} 200 -60 0 0 \{name=li lab=DSIIN\}
C \{[file join $LIB dsi.sym]\} 200 -100 0 0 \{name=xdsi1\}
C \{devices/lab_wire\} 200 -260 0 0 \{name=ln lab=DSNIN\}
C \{[file join $LIB dsn.sym]\} 200 -300 0 0 \{name=xdsn1\}"

## top2: the TWO-LEVEL fixture, kept only so that row L8 can show what a shallow
## fixture measures. It instances the excludable leaf DIRECTLY, so the only
## component loop that ever sees `plug` as a candidate is the top-level one in
## global_vhdl_netlist(), which always spelled the access `j`.
wfile [file join $scratch top2.sch] "v \{xschem version=3.4.8RC file_version=1.3\}
G \{\}
K \{\}
V \{\}
S \{\}
F \{\}
E \{\}
N 0 0 200 0 \{\}
C \{devices/ipin\} 0 0 0 0 \{name=pL lab=INL\}
C \{[file join $EX plug.sym]\} 200 0 0 0 \{name=xplug1\}"

wfile [file join $scratch top.sch] "v \{xschem version=3.4.8RC file_version=1.3\}
G \{\}
K \{\}
V \{\}
S \{\}
F \{\}
E \{\}
N 0 0 200 0 \{\}
N 0 -300 200 -300 \{\}
C \{devices/ipin\} 0 0 0 0 \{name=pL lab=INL\}
C \{[file join $MIDS midl.sym]\} 200 0 0 0 \{name=xmidl1\}
C \{devices/ipin\} 0 -300 0 0 \{name=pD lab=IND\}
C \{[file join $MIDS midd.sym]\} 200 -300 0 0 \{name=xmidd1\}"

#############################################################################
## The driver. One VHDL netlist per (source file, `xschem_libs`) pair. xschem
## writes it to $netlist_dir/<cell>.vhdl, so every run would otherwise overwrite
## the previous one: each is renamed to a per-run name first, which also means a
## run that produced nothing answers ZZNOFILE instead of the run before it.
#############################################################################
set ::netlist_dir $OUT
set ::netlist_show 0
set ::keep_symbols 0

proc netlist_with {libs tag {src top.sch}} {
  global scratch OUT
  set ::xschem_libs $libs
  set dst [file join $OUT out.$tag.vhdl]
  catch {file delete -force $dst}
  catch {xschem load [file join $scratch $src]}
  catch {xschem set netlist_type vhdl}
  catch {xschem netlist}
  set produced [file join $OUT [file rootname $src].vhdl]
  if {[file exists $produced]} { file rename -force $produced $dst }
  return [slurp $dst]
}

## The netlist proc in src/xschem.tcl pipes the C output through
## src/vhdl.awk, so without awk there is no file to read and every driven row
## would compare ZZNOFILE against ZZNOFILE-shaped nothing. Say so instead.
set HAVE_AWK [expr {[auto_execok awk] ne {}}]
if {$HAVE_AWK} {
  set CTL  [netlist_with {}            control]
  set EXCL [netlist_with {x1611excl}   excl]
  set XTOP [netlist_with {x1611mids}   excltop]
  set CTL2  [netlist_with {}          control2 top2.sch]
  set EXCL2 [netlist_with {x1611excl} excl2    top2.sch]
} else {
  set CTL ZZNOFILE ; set EXCL ZZNOFILE ; set XTOP ZZNOFILE
  set CTL2 ZZNOFILE ; set EXCL2 ZZNOFILE
}

#############################################################################
## L -- THE check_lib HALF.
#############################################################################
if {!$HAVE_AWK} {
  skiprow "L1 L2 L3 L4 L5 L6 L7 L8 D1 D2 D3 D4" \
    "no awk on PATH: proc netlist (src/xschem.tcl) pipes the VHDL output through src/vhdl.awk, so no netlist file is produced"
} else {

## L7 FIRST, because every other driven row is meaningless without it: if the
## fixture is not really three levels deep then the block being expanded and
## the candidate component are the same symbol, `i` and `j` coincide, and the
## defective code passes every row below.
check "L7 the fixture really is three levels deep -- top, then midl/midd, then the leaves -- so the block being expanded is never the candidate component" \
  [entities $CTL] {top midl midd plug keep dsn}

check "L1 CONTROL, no exclusion: arch_midl declares exactly the two leaves it instances" \
  [comps_of $CTL midl] {plug keep}

check "L2 an xschem_libs entry matching the leaf's directory drops `plug` from arch_midl and leaves `keep` declared" \
  [comps_of $EXCL midl] {keep}

check "L3 CONTROL: the excludable leaf really is netlisted when nothing excludes it -- its own entity and architecture are emitted" \
  [list [expr {[lsearch -exact [entities $CTL] plug] >= 0}] \
        [comps_of $CTL plug]] {1 {}}

check "L4 with the exclusion the leaf's own entity is gone too, and arch_midl is still a populated architecture rather than an empty one" \
  [list [lsearch -exact [entities $EXCL] plug] \
        [comps_of $EXCL midl] \
        [comps_of $EXCL midd]] {-1 keep dsn}

## L5 -- THE RESIDUAL, pinned on purpose. See the header: the instance loop in
## the static vhdl_netlist() never consults check_lib(), so an excluded child
## is still instantiated. Asserting the shape means a future change to this
## behaviour reddens a row instead of surprising a reader.
check "L5 RESIDUAL, not the fix: the excluded leaf is still INSTANTIATED in arch_midl, so the file names an entity it does not emit -- exactly what the top level does for a child excluded there" \
  [list [insts_of $EXCL midl] [lsearch -exact [entities $EXCL] plug]] \
  {{xplug1:plug xkeep1:keep} -1}

## L6 -- the TOP-LEVEL reference. global_vhdl_netlist()'s own component loop
## has always spelled this access `j`, which is why an exclusion worked there.
## Excluding the mid level exercises that loop, and the shape it produces --
## declaration suppressed, instantiation kept -- is the shape L2 and L5 now
## measure one level down. This row is what makes "the fix makes the two levels
## agree" a measurement rather than a claim.
check "L6 the top-level component loop, which always spelled this `j`, drops both excluded mid blocks from arch_top while still instantiating them" \
  [list [comps_of $XTOP top] [insts_of $XTOP top] [entities $XTOP]] \
  {{} {xmidl1:midl xmidd1:midd} top}

## L8 -- WHY THE THREE-LEVEL FIXTURE IS NOT OPTIONAL. A DOCUMENTATION ROW: it
## reddens under NEITHER sabotage, by construction. The two-level design
## instances the excludable leaf directly, so the only component loop that ever
## sees `plug` as a candidate is global_vhdl_netlist()'s top-level one, which
## always spelled the access `j`. The exclusion therefore appears to work
## whichever way vhdl_block_netlist()'s access is spelled, and the answer below
## was measured to be IDENTICAL on the fixed tree and on both single-access
## reverts. A suite built on this fixture would have reported ALL PASS against
## the defect. L7 is what stops that happening here.
check "L8 LIMIT, not a fence: on a TWO-level fixture the exclusion appears to work regardless, because only the top-level loop ever sees the leaf as a candidate" \
  [list [comps_of $CTL2 top2] [comps_of $EXCL2 top2] \
        [entities $CTL2] [entities $EXCL2] [insts_of $EXCL2 top2]] \
  {plug {} {top2 plug} top2 xplug1:plug}

#############################################################################
## D -- THE default_schematic HALF. dsi and dsn are the same symbol but for
## `default_schematic=ignore`, and both are instanced in arch_midd, so one run
## carries the subject and its control.
#############################################################################
check "D1 a component carrying default_schematic=ignore is not declared, while its otherwise identical sibling is" \
  [comps_of $CTL midd] {dsn}

check "D2 CONTROL: the sibling without the attribute is declared AND expanded, so D1 is a filter and not an empty section" \
  [list [lsearch -exact [entities $CTL] dsn] \
        [expr {[lsearch -exact [entities $CTL] dsi] < 0}]] \
  [list [lsearch -exact [entities $CTL] dsn] 1]

check "D3 the ignored component's instance is present, so there was something to declare" \
  [insts_of $CTL midd] {xdsi1:dsi xdsn1:dsn}

## D4 fences the PARENT-level early return that the in-loop read was
## shadowing. It sits near the top of vhdl_block_netlist() and in
## global_vhdl_netlist()'s descent loop, and it must keep working after the
## in-loop read changed index: a symbol with the attribute is never EXPANDED.
check "D4 the parent-level early return still holds: no entity or architecture is emitted for the symbol carrying the attribute" \
  [list [lsearch -exact [entities $CTL] dsi] [comps_of $CTL dsi]] {-1 ZZNOARCH}
}

#############################################################################
## P -- STRUCTURAL: THE PATTERN TRAP.
##
## Read with COMMENT LINES STRIPPED wherever the row is about code, because the
## fix's own comment block quotes the defective spelling `sym[i]` verbatim and a
## raw grep would answer "still broken" for ever. P2 is the one row that reads
## the RAW text, because a comment is exactly what it is about.
#############################################################################
proc nocomment_c {text} {
  ## Strips /* ... */ blocks and // to end of line. Not a C tokeniser: a `/*`
  ## inside a string literal would fool it. No row below depends on a string
  ## literal containing one, and this sentence is the limit statement rather
  ## than a claim that none can exist.
  regsub -all {/\*.*?\*/} $text " " text
  set out {}
  foreach l [split $text "\n"] {
    regsub {//.*$} $l "" l
    lappend out $l
  }
  return [join $out "\n"]
}

## Every line matching <pat> and carrying an `xctx->sym[<idx>]`, reported as
## {function for-header idx}. The function is the most recent column-0 line that
## looks like a definition head; the for-header is the most recent `for(` line,
## whitespace collapsed, or empty when the site is not inside one. That pairing
## is the whole point: two loops in this file make the same call and need
## OPPOSITE indices, and no row keyed on the call alone can tell them apart.
proc sym_index_sites {src pat} {
  set fn "" ; set forh "" ; set out {}
  foreach l [split $src "\n"] {
    if {[regexp {^[A-Za-z_][A-Za-z0-9_ \t\*]*[ \t\*]([A-Za-z_][A-Za-z0-9_]*)[ \t]*\(} $l -> nm]} {
      set fn $nm ; set forh ""
    }
    if {[regexp {for[ \t]*\(.*\)} $l]} {
      set forh [string trim $l]
      regsub -all {[ \t]+} $forh "" forh
    }
    if {[regexp $pat $l] && [regexp {xctx->sym\[([a-z_]+)\]} $l -> idx]} {
      lappend out [list $fn $forh $idx]
    }
  }
  if {$out eq {}} { return ZZNOSITES }
  return $out
}
proc absym_sites {src} {
  return [sym_index_sites $src {abs_sym_path\(.*xctx->sym\[[a-z_]+\]\.name}]
}

## The body of a C function: its opening line to the first column-0 `}`.
## ZZNOFUNC if it is not there at all, so no row can pass by finding nothing.
##
## The head match is ANCHORED AT COLUMN 0, unlike the copy in
## test_generator_shell_1610.tcl. Measured while writing this suite: an
## unanchored `[ \t*]<name>[ \t]*\(` also matches the indented CALL
## `err |= vhdl_block_netlist(fd, i, alert);` inside global_vhdl_netlist, so the
## extraction silently started at the wrong place and returned a region with no
## loop in it -- which row P6's first element is there to catch.
proc cfunc_body {src name} {
  set on 0 ; set out {}
  foreach l [split $src "\n"] {
    if {$on} {
      if {[regexp {^\}} $l]} { return [join $out "\n"] }
      lappend out $l
      continue
    }
    if {[regexp "^(static +)?\[A-Za-z_\]\[A-Za-z0-9_ \t\\*\]*\[ \t\\*\]$name\[ \t\]*\\(" $l]} { set on 1 }
  }
  if {$on} { return [join $out "\n"] }
  return ZZNOFUNC
}

## The body of the first loop in <body> whose header matches <forpat>, found by
## brace depth from that header. ZZNOLOOP if the header is not there.
proc cloop_body {body forpat} {
  if {$body eq "ZZNOFUNC"} { return ZZNOLOOP }
  set on 0 ; set depth 0 ; set out {}
  foreach l [split $body "\n"] {
    if {!$on} {
      if {![regexp $forpat $l]} { continue }
      set on 1
    }
    lappend out $l
    set o [regexp -all {\{} $l] ; set c [regexp -all {\}} $l]
    incr depth [expr {$o - $c}]
    if {$depth <= 0 && [llength $out] > 1} { return [join $out "\n"] }
  }
  if {$on} { return [join $out "\n"] }
  return ZZNOLOOP
}
proc scount {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}

set CSRC [nocomment_c [slurp $VHDLC]]
set RAW  [slurp $VHDLC]

## P1 is named for what it greps: every line of src/vhdl_netlist.c, comments
## stripped, holding the substring `abs_sym_path(` (which also catches the
## `sanitized_abs_sym_path(` spelling) followed by an `xctx->sym[<idx>].name`
## argument -- each paired with the `for(` header it sits under, or an empty
## header when it is not inside a loop. It claims NO count of anything it does
## not match: a path reached through a helper, a macro, a `base_name` or a
## different spelling escapes it, and so does a loop added in another file.
##
## The two `global_vhdl_netlist` entries are the trap: the `for(j...)` one is
## the TOP-LEVEL component loop and must stay `j`; the `for(i...)` one is the
## DESCENT loop and must stay `i` -- commit 242523cb, titled "typo fix",
## deliberately changed that one from `j` to `i`. A reader who greps for the
## pattern and makes them agree reintroduces a different defect. The
## loop-less `vhdl_block_netlist` entry is the `-- sym_path:` comment the
## netlist carries for the block being expanded, which is about the PARENT and
## so is correctly `i`; it is listed rather than filtered out so that the row
## reports the whole grep instead of a curated subset.
check "P1 every abs_sym_path( line in vhdl_netlist.c taking an xctx->sym\[..\].name, comments stripped, with the `for(` header it sits under: two in global_vhdl_netlist needing OPPOSITE indices, one loop-less `sym_path` print, one in vhdl_block_netlist's component loop" \
  [absym_sites $CSRC] \
  [list {global_vhdl_netlist {for(j=0;j<xctx->symbols;++j)} j} \
        {global_vhdl_netlist {for(i=0;i<xctx->symbols;++i)} i} \
        {vhdl_block_netlist {} i} \
        {vhdl_block_netlist {for(j=0;j<xctx->symbols;++j)} j}]

## P5 is the same instrument turned on the other half. It greps every line of
## src/vhdl_netlist.c, comments stripped, holding
## `get_tok_value(xctx->sym[<idx>].prop_ptr, "default_schematic"`, paired with
## the `for(` header above it. Three sites, and again two of them must NOT
## agree: the loop-less one is `vhdl_block_netlist`'s early return, which is
## about the PARENT and so is `i`, and the descent loop's is about the block it
## is deciding whether to expand, also `i`. Only the component loop's is about
## a candidate, and it is the one that has to be `j`. Named for the text it
## greps; a read through a helper or a different spelling escapes it.
check "P5 every get_tok_value(xctx->sym\[..\].prop_ptr, \"default_schematic\" line in vhdl_netlist.c, comments stripped, with the `for(` header it sits under: `i` at the parent-level early return and in the descent loop, `j` only in the component loop" \
  [sym_index_sites $CSRC {get_tok_value\(xctx->sym\[[a-z_]+\]\.prop_ptr,[ ]*"default_schematic"}] \
  [list {global_vhdl_netlist {for(i=0;i<xctx->symbols;++i)} i} \
        {vhdl_block_netlist {} i} \
        {vhdl_block_netlist {for(j=0;j<xctx->symbols;++j)} j}]

## P2 reads the RAW file on purpose: the thing it is about is a comment. The
## fix's only defence against being "corrected" by pattern is the warning that
## names the sibling commit, and it has to sit ABOVE the site it defends or the
## reader meets the code first.
## Four separate answers on purpose -- function found, warning found, site
## found, warning before site -- because collapsing them would make a missing
## site and a mis-ordered comment produce the same diagnostic.
set BODY_START [string first "int vhdl_block_netlist" $RAW]
set SITE       [string first "xctx->sym\[j\].name, \"\"" $RAW $BODY_START]
set WARN       [string first "242523cb" $RAW $BODY_START]
check "P2 the warning naming commit 242523cb stands inside vhdl_block_netlist and ABOVE the sym\[j\].name site it defends" \
  [list [expr {$BODY_START >= 0}] [expr {$WARN >= 0}] [expr {$SITE >= 0}] \
        [expr {$WARN >= 0 && $SITE > $WARN}]] {1 1 1 1}

## P6 -- THE WHOLE-LOOP INVARIANT, and the one structural row both halves of the
## fix redden. The region is `vhdl_block_netlist()`'s component loop, taken from
## the comment-stripped function body by brace depth from its `for(` header, so
## the fix's own comment (which quotes the defective `sym[i]` spelling) cannot
## make it answer "still broken". Every access in that region is about a
## candidate component, so `xctx->sym[i]` must appear ZERO times. The second and
## third elements stop the row passing on a failed extraction: the region has to
## have been found and it has to contain `sym[j]` accesses.
##
## It asserts ZERO rather than a total for the reason the header gives: the
## totals quoted in issue 1611 and in the shipped comment are off by one, and any
## total would redden on an innocent edit.
set LOOP [cloop_body [cfunc_body $CSRC vhdl_block_netlist] \
                     {for[ \t]*\(j=0;j<xctx->symbols}]
check "P6 vhdl_block_netlist's component loop, comments stripped and delimited by brace depth, holds NOT ONE xctx->sym\[i\] -- `i` is the parent and every access in the loop is about a candidate" \
  [list [expr {$LOOP ne "ZZNOLOOP"}] \
        [scount $LOOP {xctx->sym[i]}] \
        [expr {[scount $LOOP {xctx->sym[j]}] > 0}]] {1 0 1}

## P3/P4 are the peer back ends, and they are here because issue 1611's Scope
## section claims VHDL is the only format with a component-declaration loop.
## P3 greps the four sibling netlisters for `check_lib(1, ` with comments
## stripped; P4 greps the same four files for a `component` declaration
## emitted through print_generic(). Named for the text they grep, claiming no
## count of what escapes them: a site reached through a wrapper, or a format
## added after this was written, is outside both.
set PEERS {spice_netlist.c spectre_netlist.c verilog_netlist.c tedax_netlist.c}
set peer_sites {}
foreach f $PEERS {
  set s [nocomment_c [slurp [file join $repo src $f]]]
  set hits {}
  foreach l [split $s "\n"] {
    if {[regexp {check_lib\(1,} $l]} {
      if {[regexp {xctx->sym\[([a-z_]+)\]} $l -> ix]} { lappend hits $ix } \
      else { lappend hits ? }
    }
  }
  lappend peer_sites [list $f $hits]
}
check "P3 every `check_lib(1,` line in the four sibling netlisters, comments stripped, tests the symbol it is about with `i` -- none needs `j`, because none has a second index in scope" \
  $peer_sites \
  {{spice_netlist.c i} {spectre_netlist.c i} {verilog_netlist.c i} {tedax_netlist.c i}}

set peer_comp {}
foreach f $PEERS {
  set s [nocomment_c [slurp [file join $repo src $f]]]
  lappend peer_comp [list $f [expr {[string first {print_generic(fd, "component"} $s] >= 0 || \
                                    [string first {print_generic(fd,"component"} $s] >= 0}]]
}
lappend peer_comp [list vhdl_netlist.c [expr {[string first {print_generic(fd, "component"} $CSRC] >= 0 || \
                                              [string first {print_generic(fd,"component"} $CSRC] >= 0}]]
check "P4 `print_generic(fd, \"component\"` appears in vhdl_netlist.c and in none of the four siblings, so the defective loop has no peer to compare against outside this file" \
  $peer_comp \
  {{spice_netlist.c 0} {spectre_netlist.c 0} {verilog_netlist.c 0} {tedax_netlist.c 0} {vhdl_netlist.c 1}}

#############################################################################
puts "RESULT: [expr {$fail ? "$fail FAILED ($npass passed)" : "ALL PASS ($npass checks)"}]"
if {$fail} { puts "OVERALL: FAIL" } else { puts "OVERALL: ok ($npass checks)" }
test_scratch_drop $scratch
