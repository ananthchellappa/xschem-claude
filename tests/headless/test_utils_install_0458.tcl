## File: tests/headless/test_utils_install_0458.tcl
##
## THE CADENCE PROFILE'S HELPERS MUST BE INSTALLED, AND `cadence_style_rc` MUST
## FIND THEM IN BOTH LAYOUTS (issue 0458).
##
## `src/cadence_style_rc` sources every file in `utils/`.  `make install` shipped
## NONE of them, and the rc resolved the directory as `<its own dir>/../utils` --
## correct in a source checkout, where the rc is `src/cadence_style_rc` and the
## helpers are `<repo>/utils`, and wrong once installed, where the rc lands in
## $XSCHEM_SHAREDIR and `..` points at `share/utils`, outside the share tree.
##
## ⚠ THE DEFECT WAS INVISIBLE FROM A CHECKOUT AND ONLY EVER HURT RECIPIENTS.
## Anyone running `./src/xschem` from the source tree gets the working path, so
## the profile loads; anyone who installs gets an error at the FIRST of the rc's
## fourteen `source` lines and loses the whole profile with it -- Find Navigator,
## Instance Update, bus resize and transpose, the Cadence clip operations,
## apply-highlight, the net-highlight style navigator, select-same-cell, toggle
## pins/netlabels and the Annotate entries.  That asymmetry is the reason this
## file exists rather than a note: nothing anybody runs day to day can see it.
##
## THE METHOD, and the row names state it rather than claiming coverage:
##
##   * the helper population is read from `utils/` ITSELF, and the sourced set is
##     derived from the rc's OWN TEXT.  A hand-kept list here would be the same
##     defect one level up -- and a hand-kept list in `install_shares` is
##     precisely what let 0458 happen, which is why the repair installs the
##     directory rather than naming its members.
##   * the resolution rows do not COPY the rc's expression.  They LIFT the three
##     lines out of its text and evaluate them with one documented substitution
##     (`[info script]` -> the path under test), so a change to the product's
##     expression is measured rather than mirrored.  A copied shape drifts
##     silently; that is the whole of issue 0689.
##   * `src/Makefile` is GENERATED and gitignored, so it may legitimately be
##     absent in a fresh clone.  The install rows assert `src/Makefile.in`, which
##     is checked in and always there, and add the generated file as an extra leg
##     of the SAME row when it exists, reporting which legs ran.  No row is ever
##     skipped, so this file cannot move the gate's `skips=` figure.
##
## WHY `hcases`: nothing here needs Tk or a display -- it is text and file
## existence.  Registered in `hcases` alone.

source [file join [file dirname [info script]] scratch.tcl]

set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
set rc   [file join $repo src cadence_style_rc]
set utd  [file join $repo utils]
set mkin [file join $repo src Makefile.in]
set mkgen [file join $repo src Makefile]

set npass 0 ; set fail 0
proc check {name got want} {
  global npass fail
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}
proc slurp {f} {
  if {![file exists $f]} { return {} }
  set h [open $f] ; set t [read $h] ; close $h ; return $t
}

# ---------------------------------------------------------------------------
# UI1 -- the population, read from the directory rather than from a list here.
# ---------------------------------------------------------------------------
set helpers {}
foreach f [lsort [glob -nocomplain -directory $utd *.tcl]] {
  lappend helpers [file tail $f]
}
check "UI1 utils/ holds helper .tcl files, read from the directory itself" \
      [expr {[llength $helpers] >= 1}] 1

# ---------------------------------------------------------------------------
# UI2 -- the sourced set, derived from the rc's own text, all present.
# The rc sources through `[file join $_ut <name>]`, so that is the shape scanned.
# ---------------------------------------------------------------------------
set rctxt [slurp $rc]
check "UI2a the rc is readable at all, so the rows below are measuring something" \
      [expr {[string length $rctxt] > 0}] 1

set sourced {}
foreach line [split $rctxt \n] {
  if {[regexp {^[ \t]*source[ \t]+\[file join[ \t]+\$_ut[ \t]+([^\]]+)\]} $line -> n]} {
    lappend sourced [string trim $n]
  }
}
check "UI2b the rc really does source helpers out of \$_ut, so UI2c is not an empty claim" \
      [expr {[llength $sourced] >= 1}] 1

set absent {}
foreach n $sourced {
  if {[lsearch -exact $helpers $n] < 0} { lappend absent $n }
}
check "UI2c every file the rc sources out of \$_ut is present in utils/, by name" \
      $absent {}

# UI2d -- NON-VACUITY, built rather than claimed. A name the rc does NOT source
# must not appear in the derived set, and a name it DOES source must. Without
# this leg a scanner that returned the whole directory listing would pass UI2c.
check "UI2d the scan answers about the rc's own source lines and not about the directory listing: a planted absent name is not in the derived set" \
      [lsearch -exact $sourced __no_such_helper_0458.tcl] -1

# ---------------------------------------------------------------------------
# UI3/UI4 -- the install and uninstall really name utils/, in the CHECKED-IN
# template, and also in the generated Makefile when `./configure` has been run.
# ---------------------------------------------------------------------------
set intxt   [slurp $mkin]
set gentxt  [slurp $mkgen]

proc has_install_utils {t} {
  return [regexp {install[ \t]+-f[ \t]+-d[ \t]+\.\./utils/\*[ \t]+"\$\(XSHAREDIR\)"/utils} $t]
}
proc has_rm_utils_contents {t} { return [regexp {rm[ \t]+"\$\(XSHAREDIR\)"/utils/\*} $t] }
proc has_rm_utils_dir {t}      { return [regexp {rm[ \t]+"\$\(XSHAREDIR\)"/utils[^/*]} $t] }

set legs [list in]
if {[string length $gentxt] > 0} { lappend legs gen }

set i_bad {}
if {![has_install_utils $intxt]} { lappend i_bad Makefile.in }
if {[lsearch -exact $legs gen] >= 0 && ![has_install_utils $gentxt]} { lappend i_bad Makefile }
check "UI3 the install rule ships utils/ as a DIRECTORY into \$(XSHAREDIR)/utils -- asserted in the checked-in template, and in the generated Makefile too when configure has been run (legs=$legs)" \
      $i_bad {}

set u_bad {}
if {![has_rm_utils_contents $intxt]} { lappend u_bad {Makefile.in:contents} }
if {![has_rm_utils_dir $intxt]}      { lappend u_bad {Makefile.in:dir} }
if {[lsearch -exact $legs gen] >= 0} {
  if {![has_rm_utils_contents $gentxt]} { lappend u_bad {Makefile:contents} }
  if {![has_rm_utils_dir $gentxt]}      { lappend u_bad {Makefile:dir} }
}
check "UI4 uninstall removes utils/'s contents AND the directory, so an install is reversible -- the shape systemlib/ already uses (legs=$legs)" \
      $u_bad {}

# UI4b -- the predicates discriminate. Each is asked about text that must NOT
# satisfy it, so a regexp that matched anything could not pass this row.
check "UI4b the three install predicates answer NO on text that does not carry those lines, so UI3/UI4 are measurements rather than constants" \
      [list [has_install_utils {nothing here}] \
            [has_rm_utils_contents {nothing here}] \
            [has_rm_utils_dir {nothing here}]] {0 0 0}

# ---------------------------------------------------------------------------
# UI5 -- THE RESOLUTION, LIFTED FROM THE PRODUCT AND DRIVEN IN BOTH LAYOUTS.
#
# The rc computes the helper directory from its own location. The block is taken
# out of its text and evaluated with ONE substitution -- `[info script]` becomes
# the path under test -- so this row measures the product's expression instead of
# repeating it.
# ---------------------------------------------------------------------------
set blk {}
foreach line [split $rctxt \n] {
  if {[regexp {^[ \t]*set[ \t]+_utd[ \t]} $line]} { lappend blk $line ; continue }
  if {[regexp {^[ \t]*set[ \t]+_ut[ \t]} $line]}  { lappend blk $line ; continue }
  if {[regexp {^[ \t]*if[ \t]*\{!\[file isdirectory[ \t]+\$_ut\]\}} $line]} { lappend blk $line ; continue }
}
check "UI5a the rc's helper-directory resolution was found in its text as three statements, so the rows below evaluate the product rather than a copy" \
      [llength $blk] 3

set body [join $blk \n]
regsub -all {\[info script\]} $body {$rcpath} body
proc ui_resolve {rcpath} "
$body
    return \$_ut
"

# The two layouts, both BUILT in scratch rather than described:
#   installed   -- the rc and a sibling utils/ in one directory, which is what
#                  \$(XSHAREDIR) looks like after make install
#   source tree -- the rc one level DOWN from utils/, i.e. src/cadence_style_rc
set sd [test_scratch utils0458]
file mkdir [file join $sd inst utils]
file mkdir [file join $sd tree src]
file mkdir [file join $sd tree utils]
close [open [file join $sd inst cadence_style_rc] w]
close [open [file join $sd tree src cadence_style_rc] w]

set got_inst [file normalize [ui_resolve [file join $sd inst cadence_style_rc]]]
set got_tree [file normalize [ui_resolve [file join $sd tree src cadence_style_rc]]]

check "UI5b the INSTALLED layout resolves to the SIBLING utils/, which is the case that used to fail and take the whole Cadence profile with it" \
      $got_inst [file normalize [file join $sd inst utils]]
check "UI5c the SOURCE-TREE layout still resolves to the PARENT's utils/, so the repair did not trade one layout for the other" \
      $got_tree [file normalize [file join $sd tree utils]]

# UI5d -- THE DISCRIMINATING ROW. The expression the rc USED to carry, built here
# and driven on the same two layouts. It must get the source tree right and the
# installed layout WRONG; if it ever got both right, UI5b would be passing
# against no difference at all and this file would be measuring nothing.
proc ui_resolve_old {rcpath} {
  return [file join [file dirname [file normalize $rcpath]] .. utils]
}
set old_inst [file normalize [ui_resolve_old [file join $sd inst cadence_style_rc]]]
set old_tree [file normalize [ui_resolve_old [file join $sd tree src cadence_style_rc]]]
check "UI5d control: the UNCONDITIONAL parent expression the rc used to carry gets the source tree right and the installed layout WRONG, which is the difference UI5b measures" \
      [list [string equal $old_tree [file normalize [file join $sd tree utils]]] \
            [string equal $old_inst [file normalize [file join $sd inst utils]]] \
            [file isdirectory $old_inst]] {1 0 0}

# UI5e -- and the real installed tree, if one happens to be reachable, is not
# asserted here at all: this file has no install step and inventing one would
# make a row depend on write access outside the scratch directory. What IS
# asserted is that the shipped rc sources every name it names (UI2c) and that
# the install rule exists to put them beside it (UI3) -- the two halves whose
# ABSENCE was the defect. Declared, so nobody reads UI5b as an end-to-end claim.
check "UI5e the two halves that together close 0458 are both asserted above, and this row names the limit: no row here performs a real install" \
      [list [expr {[llength $absent] == 0}] [has_install_utils $intxt]] {1 1}

test_scratch_drop $sd

if {$fail == 0} { puts "OVERALL: ok ($npass checks)" } else { puts "OVERALL: notok" }
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
