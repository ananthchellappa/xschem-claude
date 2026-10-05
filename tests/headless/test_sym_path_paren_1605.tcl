## File: tests/headless/test_sym_path_paren_1605.tcl
##
## A NETLIST'S OWN PROVENANCE COMMENT MUST NAME THE FILE IT CAME FROM, EVEN WHEN
## THAT FILE'S NAME CONTAINS A PARENTHESIS (issue 1605).
##
## `sanitized_abs_sym_path` (src/actions.c) exists to turn a symbol GENERATOR's
## name into a path -- `xxx(a,b)` -> `xxx` -- and it did that with an UNANCHORED
## `regsub {\(.*}`, which ate the first parenthesis and everything after it in
## ANY name.  Measured before the fix: `opamp(rev2).sym` came back as
## `<cwd>/opamp`, a plausible ABSOLUTE path with the parenthesis and the
## extension both gone, and `dir(x)/thing.sym` as `<cwd>/dir`, naming a
## DIRECTORY as the source file.
##
## ⚠ AND IT IS NOT COSMETIC, which is why this file drives a real netlist rather
## than just the string.  Five callers write the result as `sym_path:` /
## `sch_path:` comments, and `op_annot.tcl` READS `** sch_path:` back and
## compares it with `xschem get schname` after every descend -- that file's own
## comment says a mismatch "SUPPRESSES the subtree and warns".  So a schematic
## whose file name carried a parenthesis silently lost operating-point
## annotation for its whole subtree.
##
## THE METHOD, and the row names state it rather than claiming coverage:
##
##   * the behavioural rows NETLIST a fixture that instances a symbol whose FILE
##     NAME contains a parenthesis, and read the `sym_path:` lines back out of
##     the deck.  That is the only door to the C function from a suite -- it has
##     no Tcl command -- and it is also the door the defect actually travelled.
##   * SP5 drives the OLD expression on the same names and requires it to differ,
##     so SP2/SP3 cannot pass against no difference.
##   * SP6 asserts the branch CALLS `is_generator` instead of carrying a third
##     copy of `^[^ \t()]+\([^()]*\)[ \t]*$`.  Two copies already exist and row
##     S8 of test_generator_paren_1604.tcl exists to stop them drifting; a third
##     would need the same treatment, so the fix avoids minting one.
##
## WHY `hcases`: netlisting needs no display.  Registered in `hcases` alone.

source [file join [file dirname [info script]] scratch.tcl]

set npass 0 ; set fail 0
proc check {name got want} {
  global npass fail
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}

set sd  [test_scratch sympath1605]
set lib [file join $sd lib]
file mkdir $lib

# A SUBCIRCUIT hierarchy, because `** sym_path:` / `** sch_path:` are written by
# spice_block_netlist() -- the arm that emits a `.subckt` -- and not for a
# primitive device.  That is also the shape the defect really mattered in:
# op_annot reads `** sch_path:` back per block.
proc sp_prim {path nm} {
  set f [open $path w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "K \{type=nmos\nformat=\"@name @pinlist @model\"\ntemplate=\"name=$nm model=spdev\"\}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  puts $f "L 4 0 0 0 10 {}"
  close $f
}
proc sp_subsym {path} {
  set f [open $path w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "K \{type=subcircuit\nformat=\"@name @pinlist @symname\"\ntemplate=\"name=x1\"\}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  puts $f "L 4 -20 -20 20 -20 {}"
  close $f
}
proc sp_sheet {path recs} {
  set f [open $path w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  foreach r $recs { puts $f $r }
  close $f
}

# The two subcircuits differ ONLY in whether the file name carries a parenthesis,
# so any difference in their provenance lines is attributable to that alone.
sp_prim   [file join $lib zzfet.sym] MZZ1
sp_subsym [file join $lib "par(en).sym"]
sp_subsym [file join $lib plain.sym]
sp_sheet  [file join $lib "par(en).sch"] [list "C \{[file join $lib zzfet.sym]\} 0 0 0 0 \{name=MZZ1\}"]
sp_sheet  [file join $lib plain.sch]     [list "C \{[file join $lib zzfet.sym]\} 0 0 0 0 \{name=MZZ2\}"]
sp_sheet  [file join $lib top.sch] \
  [list "C \{[file join $lib {par(en).sym}]\} 0 0 0 0 \{name=x1\}" \
        "C \{[file join $lib plain.sym]\} 0 200 0 0 \{name=x2\}"]

check "SP1a the fixture symbol whose FILE NAME carries a parenthesis really exists on disk, so the rows below are about a real file" \
      [file exists [file join $lib "par(en).sym"]] 1

set ::netlist_dir  $sd
set ::netlist_type spice
set loaded [catch {xschem load [file join $lib top.sch]} lerr]
check "SP1b the sheet instancing it LOADS -- which it only does since issue 1604 stopped the parenthesis being refused, and is why this defect was never seen before" \
      $loaded 0

set nl [catch {xschem netlist} nerr]
check "SP1c and it NETLISTS, so the provenance comments below were really written by the netlister" \
      $nl 0

set deck [file join $sd top.spice]
check "SP1d the deck was produced where netlist_dir says" [file exists $deck] 1

set txt {}
if {[file exists $deck]} { set h [open $deck] ; set txt [read $h] ; close $h }
set paths {}
foreach line [split $txt \n] {
  if {[regexp {^\*\* sym_path:[ \t]*(.*)$} $line -> p]} { lappend paths [string trim $p] }
}
check "SP1e the deck carries sym_path: provenance comments at all, so SP2/SP3 are not empty claims" \
      [expr {[llength $paths] >= 1}] 1

# ---------------------------------------------------------------------------
# SP2/SP3 -- what the line SAYS.
# ---------------------------------------------------------------------------
set named 0 ; set truncated {}
foreach p $paths {
  if {[file tail $p] eq "par(en).sym"} { set named 1 }
  # the pre-fix shape: the name cut at its first parenthesis, so the tail is the
  # head of the real name with no parenthesis and no extension left on it
  if {[file tail $p] eq "par"} { lappend truncated $p }
}
check "SP2 a sym_path: line names the parenthesised symbol by its REAL file name, parenthesis and extension intact" \
      $named 1
check "SP3 and no sym_path: line was cut at the first parenthesis, which is the shape that made a wrong-but-plausible absolute path out of a real one" \
      $truncated {}

set plain 0
foreach p $paths { if {[file tail $p] eq "plain.sym"} { set plain 1 } }
check "SP4 control: the symbol WITHOUT a parenthesis is named the same way, so SP2 is about the parenthesis and not about provenance comments in general" \
      $plain 1

# ---------------------------------------------------------------------------
# SP5 -- THE DISCRIMINATING ROW. The expression the function used to carry, built
# here and driven on the same names. It must mangle the parenthesised one and
# leave the plain one alone; if it ever stopped differing, SP2/SP3 would be
# passing against no difference at all.
# ---------------------------------------------------------------------------
proc sp_old {name} { return [regsub {\(.*} $name {}] }
check "SP5 control: the UNANCHORED expression the function used to carry truncates the parenthesised name and leaves the plain one untouched, which is the difference SP2/SP3 measure" \
      [list [sp_old "par(en).sym"] [sp_old "plain.sym"]] {par plain.sym}

# ---------------------------------------------------------------------------
# SP6 -- the branch calls the shared predicate rather than minting a third copy
# of its grammar, and the null guard that must come before it is still there
# (`is_generator(NULL)` is that function's CACHE-FREE call, not a predicate).
# ---------------------------------------------------------------------------
set ac [file join [file dirname [info script]] .. .. src actions.c]
set atxt {}
if {[file exists $ac]} { set h [open $ac] ; set atxt [read $h] ; close $h }
set body {}
if {[regexp {const char \*sanitized_abs_sym_path\(const char \*s, const char \*ext\)\s*\{(.*?)\n\}} $atxt -> body]} {}
check "SP6a sanitized_abs_sym_path's body was found in src/actions.c, so SP6b/SP6c are measuring it" \
      [expr {[string length $body] > 0}] 1
check "SP6b it CALLS is_generator with the null guard ahead of it, rather than re-spelling that predicate's grammar a third time" \
      [regexp {if\(s && is_generator\(s\)\)} $body] 1
check "SP6c and it carries no copy of is_generator's own ERE, which would be the third in the tree and would drift" \
      [regexp {\[\^ \\t\(\)\]} $body] 0

# SP6d -- both branches are reachable, asserted through the predicate the branch
# uses. A generator name and a parenthesised FILE name must answer differently,
# or the gate added by this fix would be decorative.
check "SP6d the predicate the branch gates on separates a GENERATOR from a file whose name merely contains a parenthesis, so both arms are real" \
      [list [xschem is_generator {gen(a,b)}] [xschem is_generator "par(en).sym"]] {1 0}

test_scratch_drop $sd

if {$fail == 0} { puts "OVERALL: ok ($npass checks)" } else { puts "OVERALL: notok" }
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
