# tests/headless/test_op_annot.tcl — S1 of doc/claude/specs/op_annotation.md.
#
# ============================================================================
# WHAT IS UNDER TEST
# ============================================================================
# `op_annot`, the ONE raw-vector name builder that invariant I1 requires:
#
#   op_annot::register <symbol-type> <dict>   stores/overrides a descriptor
#   op_annot::descriptor <symbol-type>        -> dict or {}
#   op_annot::type <instname>                 -> the symbol K-record `type=`
#   op_annot::devpath <instname>              -> "@m.x1.xm1.msky130_fd_pr__nfet_01v8"
#   op_annot::vector <instname> <param> ?kind?-> "i(...)" / bare / "v(...)"
#
# Three name builders already exist in C (`get_fqdevice()` token.c:4514, its
# near-verbatim duplicate at token.c:5163, and each PDK's hand-written symbol
# text). op_annot is the fourth and is meant to REPLACE the third. I1's failure
# mode is silent: if the save-card emitter and the display build names
# independently they drift, you save vectors nobody shows and show `-` for
# vectors you saved. So the goldens below are exact strings, not shapes.
#
# ============================================================================
# THE GOLDENS, AND WHERE THEY COME FROM
# ============================================================================
# sky130 nfet_01v8, instance M1 (spiceprefix X from the SYMBOL template) at
# sim_sch_path `x1.`:
#
#   gm    -> @m.x1.xm1.msky130_fd_pr__nfet_01v8[gm]        (kind 1, bare)
#   id    -> i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])     (kind 0, current)
#   vdsat -> v(@m.x1.xm1.msky130_fd_pr__nfet_01v8[vdsat])  (kind 2, voltage)
#
# The kind wrapper is NOT this file's invention. token.c:4524-4525 reads
#   iprefix  = modelparam == 0 ? "i(" : modelparam == 1 ? "" : "v("
#   ipostfix = modelparam == 1 ? ""   : ")"
# and token.c:4572 is `strtolower(fqdev);`. Spec §3 R3 is the same rule stated
# from the ngspice side. D8 closes the loop against a SHIPPED symbol.
#
# ============================================================================
# ⚠ THE DESCRIPTOR TEMPLATE IN SPEC §4.2 IS BROKEN AS WRITTEN — MEASURED
# ============================================================================
# `xschem translate` tokenises on SPACE(c) = {\n, space, \t, \0, ;} only
# (token.c:24), so `.` does NOT terminate an @-token, and an unknown @-token
# appends NOTHING (token.c:5351-5366). Feeding the spec's literal
#
#     @m.$path@spiceprefix@name.msky130_fd_pr__@model
#
# to translate yields `Xnfet_01v8` — no error, no warning, a plausible-looking
# wrong string, i.e. exactly the silent drift I1 exists to prevent. The form
# used throughout this file is the one the SHIPPED sky130 symbol already uses,
# with the leading `@` and the terminating `.` escaped:
#
#     \@m.@path@spiceprefix@name\.msky130_fd_pr__@model
#
# See doc/claude/issues/0422-*.md.
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE — READ BEFORE TRUSTING IT
# ============================================================================
# * NO RAW IS READ and no simulator runs. S1 builds NAMES; whether ngspice
#   wrote a vector under that name is S2's cross-PDK diff and S5's read path.
#   D8 is the strongest available substitute: it asserts the built name equals
#   what the shipped, working sky130 symbol has been printing for years.
# * NO PIXELS. Nothing here draws. The overlay is S9 and owes an eyeball.
# * X1/X2/A3 ARE CONTROLS, not claims about S1. They are green before the
#   feature exists and are here so that a broken fixture or an abandoned
#   xschem.tcl reds ONE legible row instead of degrading every other row into
#   a hollow pass. A3 detects an ABANDONED xschem.tcl: xinit.c:1508-1539 prints
#   to stderr and returns TCL_ERROR under --pipe/--nogui, and Tcl_EvalFile has
#   already dropped the rest of the file. ⚠ It does NOT detect a source-time
#   error in op_annot.tcl itself — measured (issue 0423), that path segfaults in
#   alloc_xschem_data() with exit 139 and no row runs at all, so the detector
#   there is the exit code. Do not read a green A3 as "the helper sourced fine".
#
# ============================================================================
# FIXTURE NOTES (both measured on this tree, both contradict the step plan)
# ============================================================================
# * `set ::XSCHEM_LIBRARY_PATH ...` IS INERT. The write trace armed at
#   src/xschem.tcl:16527 compares `$varname eq {XSCHEM_LIBRARY_PATH}` and a
#   QUALIFIED set delivers `::XSCHEM_LIBRARY_PATH`, so `set_paths` never runs
#   and the ambient 13-directory path stays. Measured: `Symbol not found:
#   leaf.sym`. The UNQUALIFIED spelling below is load-bearing — the same
#   finding test_wave_sigbrowser_0319.tcl:271 records.
# * THE ACCEPTANCE GOLDENS NEED A REAL LOADED INSTANCE. `xschem translate`
#   raises on a missing instance, and `xschem translate -1 <tmpl>` substitutes
#   each token with its own NAME (`@spiceprefix` -> `spiceprefix`). The plan's
#   "with no schematic loaded, with a stubbed instance" is not reachable.
#
# True headless (no X). Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_annot.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

## ⚠ EVERY op_annot CALL GOES THROUGH `rcall`, AND THAT IS THE POINT.
## It returns {rc result}, so a row that expects a BLANK asserts {0 {}} and a
## row that expects a raise asserts rc 1. A bare `catch`-and-discard would let
## `invalid command name "op_annot::devpath"` satisfy an expects-blank row —
## i.e. the whole file would pass green against an absent namespace.
proc rcall {script} {
  set rc [catch {uplevel #0 $script} res]
  return [list $rc $res]
}
## A raise is only the RIGHT raise if it names the thing the caller got wrong.
# =============================================================================
# THE PLAIN-ENGLISH GOLDENS — issue 0886, item A11
# =============================================================================
# The user's ruling, verbatim: "wording too cryptic. Give it in plain english
# with context, 9th grade level." Every sentence the annotation surface shows
# is minted ONCE in utils/annot_mode.tcl (RULING D5-4) and asserted here as a
# WHOLE SENTENCE, never as a substring: a row that only looked for the word
# "cursor" cannot tell a good sentence from a bad one.
#
# The eight mask sentences say what is on the schematic right now. They are
# worded off the user's own ratified menu labels — "Operating Point info",
# "DC Node Voltages", "Transient Node Voltages (at cursor)" — so the status
# line and the menu agree about what the three switches do.
set A11_M0 {Annotation is off. The schematic is not showing simulation numbers.}
set A11_M1 {Showing device operating-point values on the schematic.}
set A11_M2 {Showing DC node voltages on the schematic.}
set A11_M3 {Showing device operating-point values and DC node voltages on the schematic.}
set A11_M4 {Showing node voltages at the waveform cursor on the schematic.}
set A11_M5 {Showing device operating-point values, and node voltages at the waveform cursor, on the schematic.}
set A11_M6 {Showing DC node voltages, and node voltages at the waveform cursor, on the schematic.}
set A11_M7 {Showing device operating-point values, DC node voltages, and node voltages at the waveform cursor, on the schematic.}

# The state clauses, each appended to a mask sentence after ONE space. Every
# clause that the user can act on ends with what to do; the two that report a
# completed action do not, because there is nothing to do.
set A11_LIVE   { These results were already loaded.}
set A11_NOOP   { The loaded results do not include an operating point, so there are no device values to show. Load a different results file from Waves > Op Annotate, then press again.}
set A11_NOPATH { No results file has been found for this cell. Run a simulation first.}
# The three clauses that paste the user's own results-file path into the
# sentence, and the one that pastes its file name. @P@ is the full path, @T@ the
# tail; row A11-12 substitutes and compares byte for byte.
#
# ⚠ WHY THEY ARE HERE AT ALL. A11_NOPATH sat in this file unreferenced from the
# day it was written, so the sentence a user reads on a freshly drawn cell that
# has never been simulated -- the FIRST annotation sentence most people will
# ever see -- was the one sentence in the whole surface with no byte-exact
# golden behind it in this suite. It was measured 2026-08-28 that the state
# clause could be replaced wholesale with internal jargon and every row here
# still passed. A11-12 is what closes that, and the other four clauses join it
# so the set is complete rather than patched.
set A11_OFFC   {}
set A11_LOADED { Loaded results from @P@.}
set A11_FAILED { Could not read the results file @P@, so nothing was placed on the schematic.}
set A11_NORAW  { There is no results file at @P@ yet. Run a simulation first.}
set A11_STALE  { The results file @T@ is older than the circuit it describes, so it was not used - it is from an earlier run. Run the simulation again.}

# ISSUE 0909 — THE CLAUSE THAT DESCRIBES WHAT IS INSIDE THE RESULTS FILE.
#
# ⚠ EVERY OTHER CLAUSE ABOVE IS ABOUT THE FILE; THESE THREE ARE ABOUT ITS
# CONTENTS, AND THAT IS WHY THEY ARE A SEPARATE AXIS RATHER THAN THREE MORE
# STATES. The block was drawn, the press succeeded, and the values in it are
# blank — a fact that can be true under `live` and under `loaded` alike, so a
# state would have to be duplicated per state or would delete the sentence that
# names the file. It is appended as a clause, and rows A11-10 and A11-12b are
# what hold it to the same standards as the eight states.
#
# ⚠ THREE SENTENCES BECAUSE THE REMEDIES DIFFER, and src/ase.tcl:765's own rule
# governs the split: a wrong direction printed with authority is worse than
# printing none. The wording is this crew's and is NOT YET RATIFIED — recorded
# as an owed rule against issue 0909.
set A11_CAUSE_NOCARDS {Some values are blank because this simulation did not save the device operating-point numbers. The results file has node voltages, but no per-device values like gm, gds and vth. Turn on saving them, then run the simulation again.}
set A11_CAUSE_NOPARAMS {Some values are blank because the results file has no per-device operating-point numbers in it, such as gm, gds and vth. Run the simulation again with device parameter saving turned on.}
set A11_CAUSE_SOMEDEV {Some values are blank. The results file does have device operating-point numbers, but not for every device on this sheet. Run the simulation again, and check that these devices are included in what it saves.}

# ⚠ AND EACH HAS A SHORT FORM, BECAUSE THE STATUS LINE IS 255 BYTES AND THE
# LONG ONE DOES NOT FIT. Measured: the mask sentence is 55 bytes and the
# save-cards sentence is 229, so 285 arrived at the wall before a results-file
# path was added, cadence::_annot_fit cut inside the sentence, and the bar read
# "... Turn on saving..." — the remedy's verb without its object, on the one
# sink RULING 0857 put there for a user with no ASE-L window. The CIW pane
# keeps the long form; the bar gets these. Both come out of the SAME proc
# (RULING D5-4), which is why the rows below sweep the forms rather than the
# call sites. Also unratified.
set A11_CAUSE_NOCARDS_S {Some values are blank because this run did not save device values like gm and vth. Turn on saving them, then run again.}
set A11_CAUSE_NOPARAMS_S {Some values are blank because the results file has no device values like gm and vth in it. Run the simulation again with them saved.}
set A11_CAUSE_SOMEDEV_S {Some values are blank because the results file has no numbers for some of the devices here. Run the simulation again and save them.}

proc check_raises {name script needle} {
  global fail npass
  set rc [catch {uplevel #0 $script} res]
  if {$rc == 1 && [string match "*$needle*" $res]} {
    puts "ok:   $name"; incr npass
  } else {
    puts "FAIL: $name -> rc=$rc msg={$res} (exp rc=1 naming {$needle}) : FAIL"
    incr fail
  }
}

# --- locations (cwd-independent) --------------------------------------------
set here [file normalize [file dirname [info script]]]      ;# tests/headless
set repo [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch op_annot]
set lib [file join $scratch lib]
file mkdir $lib

# --- the fixture, written fresh (nothing committed, no untitled*.sch) --------
# leaf.sym is a 12-line type=subcircuit box; leaf.sch holds the sky130 FET.
set f [open [file join $lib leaf.sym] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}
close $f
set f [open [file join $lib top.sch] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {leaf.sym} 120 0 0 0 {name=x1}}
close $f
set f [open [file join $lib leaf.sch] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {sky130_fd_pr/nfet_01v8.sym} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}}
close $f

# ⚠ UNQUALIFIED. See the fixture note in the header: the qualified spelling is
# inert and would leave every symbol unresolved while this file still "ran".
set XSCHEM_LIBRARY_PATH ":[file join $repo sky130A xschem_libs]:[file join $repo xschem_library devices]:$lib"

# --- the goldens -------------------------------------------------------------
set G_DEV   {@m.x1.xm1.msky130_fd_pr__nfet_01v8}
set G_GM    "${G_DEV}\[gm\]"
set G_ID    "i(${G_DEV}\[id\])"
set G_VDSAT "v(${G_DEV}\[vdsat\])"
set G_DEVTOP {@m.xm1.msky130_fd_pr__nfet_01v8}

set TMPL_AT     {\@m.@path@spiceprefix@name\.msky130_fd_pr__@model}
set TMPL_DOLLAR {\@m.$path@spiceprefix@name\.msky130_fd_pr__@model}
set PINEXPR {{vgs {@#1 - @#2}} {vds {@#0 - @#2}}}
set DERIVED {{gm/id {$gm/$id}}}
set PARAMS  {{id id 0} {gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2} {Ids ids 0}}

if {[catch {

# ===========================================================================
# A — the namespace is REACHABLE, and xschem.tcl survived sourcing it
# ===========================================================================
check {A1 the op_annot namespace exists (the new source line in xschem.tcl ran)} \
  [namespace exists ::op_annot] 1

check {A2 all five deliverables exist} \
  [lsort [list [expr {[info commands ::op_annot::register]   ne {}}] \
               [expr {[info commands ::op_annot::descriptor] ne {}}] \
               [expr {[info commands ::op_annot::type]       ne {}}] \
               [expr {[info commands ::op_annot::devpath]    ne {}}] \
               [expr {[info commands ::op_annot::vector]     ne {}}]]] \
  {1 1 1 1 1}

# ⚠ CONTROL, GREEN BEFORE AND AFTER. `stdin_repl_setup` is defined AND called
# on the LAST line of src/xschem.tcl, so its presence proves the file was
# evaluated to the end — i.e. op_annot.tcl did not raise at source time and
# silently abandon load_input_bindings, the action-log registry, ciw.tcl and
# build_widgets.
#
# ⚠ SCOPE, measured (issue 0423): A3 does NOT detect a source-time error in
# op_annot.tcl itself. That case segfaults in alloc_xschem_data() before any
# script runs -- exit 139, no RESULT banner, no rows -- and the detector is the
# nonzero exit code, not this check. A3 covers the genuinely quiet variant: a
# helper sourced late enough that startup completes with xschem.tcl abandoned.
check_true {A3 CANARY xschem.tcl was sourced to its last line} \
  [expr {[info procs ::stdin_repl_setup] ne {}}]

# ===========================================================================
# B — descriptor storage
# ===========================================================================
check {B1 descriptor of a never-registered type is BLANK, not a raise} \
  [rcall {op_annot::descriptor opa_never_registered}] {0 {}}

catch {op_annot::register opa_t1 [list devpath {\@m.A} params $PARAMS \
                                      pinexpr $PINEXPR derived $DERIVED]}
check {B2 descriptor round-trips devpath/params/derived/pinexpr verbatim} \
  [rcall {list [dict get [op_annot::descriptor opa_t1] devpath] \
               [dict get [op_annot::descriptor opa_t1] params] \
               [dict get [op_annot::descriptor opa_t1] derived] \
               [dict get [op_annot::descriptor opa_t1] pinexpr]}] \
  [list 0 [list {\@m.A} $PARAMS $DERIVED $PINEXPR]]

# ⚠ REPLACE, NOT MERGE. A dict-merge reads better for "the user edits one
# line", but it lets sky130's pinexpr/derived leak into a later-registered IHP
# `nmos` in the same interpreter — which is exactly what spec §8's cross-PDK
# test does. This row is the sole guardian of that decision.
catch {op_annot::register opa_t1 [list devpath {\@m.B} params $PARAMS]}
check {B3 a second register REPLACES: the first dict's pinexpr is gone} \
  [rcall {list [dict exists [op_annot::descriptor opa_t1] pinexpr] \
               [dict get    [op_annot::descriptor opa_t1] devpath]}] \
  [list 0 [list 0 {\@m.B}]]

catch {op_annot::register opa_t2 [list devpath {\@q.C} params $PARAMS]}
check {B4 registering a second type leaves the first untouched} \
  [rcall {dict get [op_annot::descriptor opa_t1] devpath}] [list 0 {\@m.B}]

# ⚠ THE ONE LOUD FAILURE IN STORAGE. An rc typo must be caught at registration
# time; the alternative is a descriptor that silently yields blanks at draw
# time, which is indistinguishable from "this PDK is not supported".
check_raises {B5 register with an odd-length dict raises, naming the type} \
  {op_annot::register opa_odd {devpath}} opa_odd

# ===========================================================================
# FIXTURE — asserted, not assumed
# ===========================================================================
xschem load [file join $lib top.sch]
check {X1 FIXTURE top.sch loaded with x1 resolving to the subcircuit symbol} \
  [list [xschem get instances] [xschem getprop instance x1 cell::type]] \
  {1 subcircuit}

# ===========================================================================
# C(top) — the blank-not-raise discipline, at top level
# ===========================================================================
# ⚠ I3: every DATA condition is blank. x1's symbol type `subcircuit` has no
# registration, so there is nothing to build and nothing to guess.
check {C5 devpath for an unregistered symbol type is BLANK, not a raise} \
  [rcall {op_annot::devpath x1}] {0 {}}

# ⚠ `xschem translate NOPE ...` and `xschem getprop instance NOPE ...` BOTH
# raise (measured). S6/S9 call devpath from inside a draw/tcleval path where a
# raise breaks rendering, so the catch discipline is not optional.
check {C6 devpath for a nonexistent instance is BLANK, not a raise} \
  [rcall {op_annot::devpath NOPE}] {0 {}}

check {D6 vector returns BLANK when devpath is blank — no i() around nothing} \
  [rcall {op_annot::vector NOPE gm 0}] {0 {}}

# ===========================================================================
# FIXTURE — descend to sim_sch_path `x1.`
# ===========================================================================
xschem select instance 0
xschem descend 1 2
check {X2 FIXTURE descended: sim_sch_path x1., M1 is the sky130 nfet} \
  [list [xschem get sim_sch_path] [xschem getprop instance M1 cell::type] \
        [xschem translate M1 @model]] \
  {x1. nmos nfet_01v8}

catch {op_annot::register nmos [list devpath $TMPL_AT params $PARAMS \
                                    pinexpr $PINEXPR derived $DERIVED]}

# ===========================================================================
# B(cont) — the lookup key
# ===========================================================================
# ⚠ The key is the symbol K-record `type=` token, NOT the cell name. Measured:
# `getprop symbol {sky130_fd_pr/nfet_01v8} type` RAISES (`Symbol not found`)
# while the `.sym`-suffixed spelling answers `nmos`, so a cell-name key would
# need its own catch in every caller and would differ per .sch spelling.
check {B6 lookup key is the symbol type: nfet_01v8.sym -> nmos} \
  [rcall {op_annot::type M1}] {0 nmos}

# ===========================================================================
# C — devpath
# ===========================================================================
check {C1 GOLDEN devpath M1 at path x1.} [rcall {op_annot::devpath M1}] \
  [list 0 $G_DEV]

# ⚠ `xschem translate` preserves the schematic's case and answers
# `@m.x1.XM1.msky130_fd_pr__nfet_01v8`. get_fqdevice lowercases (token.c:4572)
# and so must this, or the save cards S3 writes are mixed-case.
check {C2 the result is lowercased: xm1 not XM1, and is its own tolower} \
  [rcall {list [string match {*.xm1.*} [op_annot::devpath M1]] \
               [expr {[op_annot::devpath M1] eq \
                      [string tolower [op_annot::devpath M1]]}]}] \
  {0 {1 1}}

# ⚠ `$path` is spec §4.2's spelling; `@path` (token.c:4719) is translate-native
# and needs no Tcl pass. Both must land on the same string. The Tcl pass must
# be `string map`, NEVER `subst` — a template is user data and subst would
# execute any [...] in it.
catch {op_annot::register nmos [list devpath $TMPL_DOLLAR params $PARAMS]}
check {C3 a \$path-spelled template equals the @path-spelled one} \
  [rcall {op_annot::devpath M1}] [list 0 $G_DEV]
catch {op_annot::register nmos [list devpath $TMPL_AT params $PARAMS \
                                    pinexpr $PINEXPR derived $DERIVED]}

# ⚠ THE DEVPROC CALLING CONVENTION, PINNED NOW. No PDK uses it until S2, but
# the IHP `_5t` model-suffix strip (sg13g2_procs.tcl:321-324) is the whole
# reason the key exists, and a convention nobody wrote down is a convention
# S2 will guess at.
proc opa_probe_devproc {instname model path spiceprefix} {
  set ::opa_devproc_args [list $instname $model $path $spiceprefix]
  return "@z.${path}${spiceprefix}${instname}.z${model}"
}
set ::opa_devproc_args {}
catch {op_annot::register nmos [list devproc opa_probe_devproc params $PARAMS]}
check {C7 devproc is called as <proc> <inst> <model> <path> <spiceprefix>} \
  [rcall {list [op_annot::devpath M1] $::opa_devproc_args}] \
  {0 {@z.x1.xm1.znfet_01v8 {M1 nfet_01v8 x1. X}}}

# ⚠ ADDED ROW (not in the step plan). The decision "devpath lowercases on BOTH
# paths" is otherwise unguarded: a devproc that returns mixed case would write
# mixed-case save cards while the display lowercased them — I1 drift, silent.
proc opa_upper_devproc {instname model path spiceprefix} { return {@Z.X1.XM1.ZFOO} }
catch {op_annot::register nmos [list devproc opa_upper_devproc params $PARAMS]}
check {C11 a devproc's mixed-case answer is lowercased too (token.c:4572)} \
  [rcall {op_annot::devpath M1}] {0 @z.x1.xm1.zfoo}

catch {op_annot::register nmos [list devproc opa_probe_devproc devpath $TMPL_AT \
                                    params $PARAMS]}
check {C8 devproc wins when a descriptor carries devproc AND devpath} \
  [rcall {op_annot::devpath M1}] {0 @z.x1.xm1.znfet_01v8}
catch {op_annot::register nmos [list devpath $TMPL_AT params $PARAMS \
                                    pinexpr $PINEXPR derived $DERIVED]}

# ⚠ ANTI-REGRESSION for the IHP prototype's one unportable line. sg13g2_procs
# reads `xschem getprop instance $inst spiceprefix` (:374,:453,:512), which
# works ONLY because IHP test schematics spell spiceprefix= on the instance.
# On sky130 it answers EMPTY and the device path silently loses its `x`.
check {C9 spiceprefix comes from the SYMBOL template, not the instance line} \
  [list [xschem getprop instance M1 spiceprefix] \
        [rcall {string match {*.xm1.*} [op_annot::devpath M1]}]] \
  {{} {0 1}}

# ⚠ I4: the builder reads context, it never moves in it. If devpath ever
# descends to resolve a path it must come back, and it must not dirty the cell.
# ⚠⚠ THE rc LIST IS NOT DECORATION. Without it this row passes against an
# ABSENT namespace — three raised calls move nothing, so "unchanged" is
# trivially true and the check measures the fixture instead of the builder.
# Asserting the three calls SUCCEEDED is what makes the invariance a claim.
set c10_before [list [xschem get sch_path] [xschem get modified]]
set c10_rc [list [lindex [rcall {op_annot::devpath M1}]    0] \
                 [lindex [rcall {op_annot::vector M1 gm 1}] 0] \
                 [lindex [rcall {op_annot::vector M1 id 0}] 0]]
check {C10 devpath/vector succeed AND leave sch_path and modified untouched} \
  [list $c10_before $c10_rc [xschem get sch_path] [xschem get modified]] \
  [list {.x1. 0} {0 0 0} {.x1.} 0]

# ===========================================================================
# D — vector: the R3 / get_fqdevice kind wrapper
# ===========================================================================
check {D1 GOLDEN vector M1 gm 1 — kind 1, bare} \
  [rcall {op_annot::vector M1 gm 1}] [list 0 $G_GM]
check {D2 GOLDEN vector M1 id 0 — kind 0, i(...)} \
  [rcall {op_annot::vector M1 id 0}] [list 0 $G_ID]
check {D3 GOLDEN vector M1 vdsat 2 — kind 2, v(...)} \
  [rcall {op_annot::vector M1 vdsat 2}] [list 0 $G_VDSAT]

# ⚠ I1 AGAIN, ONE LEVEL DOWN. The kind is descriptor DATA. A consumer that
# retypes `0` at its call site is a second builder of the same decision, and
# when the descriptor changes only one of them moves.
check {D4 kind OMITTED comes from the descriptor's params triple (gm)} \
  [rcall {op_annot::vector M1 gm}] [list 0 $G_GM]
check {D5 kind omitted for id and vdsat reproduce the 0 and 2 wrappers} \
  [rcall {list [op_annot::vector M1 id] [op_annot::vector M1 vdsat]}] \
  [list 0 [list $G_ID $G_VDSAT]]

# ⚠ THE SPLIT RULE: data conditions are blank, CALLER BUGS are loud. Defaulting
# a missing param to kind 1 would emit a silently unwrapped current.
check_raises {D7 kind omitted for a param absent from params raises, naming it} \
  {op_annot::vector M1 nosuchparam} nosuchparam

# ⚠ THE HIGHEST-VALUE ROW IN THE FILE. The shipped sky130 symbol has been
# printing `id=` through @spice_get_node for years; its text IS the third name
# builder op_annot replaces. Unescape the `.sym` file's `\\` to `\`, run it
# through the same translate, and it must equal what op_annot builds. If these
# two ever disagree, I1 has already failed.
set symf [file join $repo sky130A xschem_libs sky130_fd_pr nfet_01v8 symbol nfet_01v8.sym]
set symtext {}
if {[file isfile $symf]} { set fh [open $symf r]; set symtext [read $fh]; close $fh }
if {[regexp {T \{id=@spice_get_node ([^\}]*)\}} $symtext -> d8raw]} {
  set d8tmpl [string map [list "\\\\" "\\"] $d8raw]
  set d8built [string tolower [xschem translate M1 $d8tmpl]]
  check {D8 I1 CROSS-CHECK: the SHIPPED nfet_01v8.sym id= text == vector M1 id 0} \
    [rcall {op_annot::vector M1 id 0}] [list 0 $d8built]
  check {D8b control: the shipped symbol's own id= text IS the golden} \
    $d8built $G_ID
} else {
  # ⚠ NEVER A SKIP. A regexp that stops matching means the symbol changed and
  # the cross-check is gone — that is a FAIL, not a quiet pass.
  check {D8 I1 CROSS-CHECK: id= text not found in the shipped symbol} \
    "no id=@spice_get_node text in $symf" {found}
  check {D8b control: the shipped symbol's own id= text IS the golden} \
    "unreachable: D8 regexp missed" $G_ID
}

# ⚠ The kind lookup must match the params triple's PARAM field (index 1), not
# the LABEL (index 0). `{Ids ids 0}` is the shape S5's formatter needs — a
# display label that differs from the raw parameter name.
check {D9 kind lookup matches the params triple's PARAM field, not the label} \
  [rcall {op_annot::vector M1 ids}] [list 0 "i(${G_DEV}\[ids\])"]

# ===========================================================================
# C4 — sim_sch_path is read LIVE, per call
# ===========================================================================
# ⚠ Same registration, same instance name, different context: at the top of
# leaf.sch there is no hierarchy prefix at all. A devpath that cached the path
# at registration time (or memoised the built name) passes every row above and
# reds only this one. Note M1 does NOT exist in top.sch, so `go_back` cannot
# express this — the second load is deliberate.
xschem load [file join $lib leaf.sch]
check {C4 at top level the hierarchy prefix vanishes (no caching)} \
  [list [xschem get sim_sch_path] [rcall {op_annot::devpath M1}]] \
  [list {} [list 0 $G_DEVTOP]]

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# =============================================================================
# SECTION P — S2 of doc/claude/specs/op_annotation.md: THE THREE PDK DESCRIPTORS
# =============================================================================
# S1 built the name builder and left its descriptor store EMPTY. S2 fills it:
# sky130A/sky130_procs.tcl, gf180mcuD/gf180_procs.tcl and
# ihp-sg13g2/sg13g2_procs.tcl each register descriptors for the symbol types they
# own, and from then on op_annot::devpath answers for a real PDK device.
#
# THE ACCEPTANCE, AND WHY IT IS A STRING DIFF AND NOT A SIMULATION
# ---------------------------------------------------------------
# Two prototypes already emit `.save` cards for these devices —
# sg13g2_write_save_lines (sg13g2_procs.tcl:304-341) and sky130_write_save_lines
# (sky130_procs.tcl:72-89). They are the ORACLE: the generalization is lossless
# only if the generic emitter reproduces their output byte for byte. Rows P3,
# P19, P20 and P21 are that diff.
#
# ⚠ THE CARDS ARE BARE — the diff MUST NOT go through op_annot::vector. Measured
# on ngspice-42 and recorded at src/op_annot.tcl:43-61 (spec §3 R4):
# `.save i(@m.xm1.m1[id])` puts NOTHING in the raw, while `.save @m.xm1.m1[id]`
# yields `i(@m.xm1.m1[id])` — ngspice applies the i()/v() wrapper itself. The
# prototypes emit bare cards, so a vector-based diff would mismatch every kind-0
# and kind-2 row by construction (30 of the 46 IHP cards). opa_gen_cards below
# builds `[devpath][param]`, and I1 still holds because devpath is the one shared
# builder.
#
# ⚠ NO NGSPICE RUNS HERE — a suite-design choice, NOT a platform limit, and an
# earlier revision of this comment claimed the latter. It said "IHP cannot be
# simulated on this box at all", generalising from /usr/bin/ngspice (42), which
# supports OSDI v0.3 while ihp-sg13g2/osdi/psp103.osdi targets v0.4. The box also
# has /usr/local/bin/ngspice (46+), which loads that .osdi and runs the bench:
# measured 2026-08-22, sg13g2_tests/dc_lv_nmos with the D9 six as its .save file
# gives rc=0, zero checkvalid warnings, all six vectors present, and annotates to
# ids 259.1u / gm 464u / gds 17.78u / vgs 1.2 / vth 0.2966 / vds 1.5.
#
# What is true is that an IHP bench needs 46+, and that S4's raw-header
# assertions (the names are real, the values are not all zero, no `unrecognized
# variable` on stderr) still have to decide which binary they pin.
#
# ⚠ SPEC §4.2's WORKED DESCRIPTORS ARE INCOMPLETE — three measured departures,
# each pinned by a row here so a later "simplify back to the spec text" edit reds
# instead of silently shipping wrong names:
#   1. sky130 needs a DEVPROC, not §4.2's single template. sky130_procs.tcl:76-78
#      has FOUR inner-device spellings; the single template mismatches 35 of the
#      119 prototype cards on the shipped sky130_tests/test_nmos (the g5v0d16v0
#      and 20v0 families). Rows P3, P4, P5, P6, P7.
#   2. §4.2 registers only `nmos`. All three PDKs carry `type=pmos` too, and
#      op_annot's key is an exact array index, not the prototypes' `[pn]mos`
#      regexp — so a verbatim copy leaves every PMOS unannotated, with no
#      diagnostic. Rows P2, P13, P15, P20, P26.
#   3. §4.2's vertical_npn descriptor has SIX params; the acceptance demands the
#      prototype's THIRTEEN (sg13g2_procs.tcl:327-339). Rows P21, P23.
#
# ⚠ ISSUE 0425 IS RATIFIED HERE (S2 owns that decision). All three PDKs *and*
# xschem_library/devices/nmos.sym share the descriptor key `type=nmos`, so the
# second `register nmos` in one interpreter silently overwrites the first, and a
# generic devices/nmos wears whichever PDK's name is registered. Measured
# before-state, unchanged by S1:
#     register sky130's nmos ; devpath M2 (devices/nmos.sym) -> @m.m2.msky130_fd_pr__cmosn
#     register IHP's  nmos   ; devpath M1 (sky130 nfet_01v8) -> @n.xm1.nnfet_01v8
# Neither is blank — and per landmine 9 a wrong name does not blank at READ time
# either: ngspice writes a full 0.0 column under exactly the name asked for. I3
# (blank, never a fabricated number) therefore forces the fix: an optional
# `match` glob list on the descriptor, tested against
# `getprop instance <n> cell::name`, so a non-matching device gets NO devpath.
# Rows P27-P30. A descriptor with no `match` key stays permissive, which is what
# keeps S1's 32 rows above and a user's own registration (I5) working unchanged.
#
# HOUSE RULES FOR THIS SECTION
# ----------------------------
# * ONE PDK PER SUBSECTION, in one interpreter. Each subsection CLEARS the store
#   for nmos/pmos/vertical_npn, re-sets the UNQUALIFIED XSCHEM_LIBRARY_PATH, and
#   sources its own procs file immediately before its own assertions. The clear
#   is load-bearing: S1's rows above leave a sky130-shaped `nmos` registered, and
#   without it "the procs file registered this" cannot be told from "S1 left it".
# * Descriptor list values are compared through opa_norm (a list round-trip), so
#   a registration written across several indented lines still matches a one-line
#   golden. Template STRINGS are compared EXACTLY — issue 0422 is precisely about
#   escaping, and normalizing that away would defeat the row.

proc opa_norm {l} { if {[catch {lrange $l 0 end} r]} { return $l } ; return $r }

proc opa_source {path} {
  if {![file isfile $path]} { return [list 1 "no such file: $path"] }
  if {[catch {uplevel #0 [list source $path]} e]} { return [list 1 $e] }
  return [list 0 {}]
}

## Clear the three keys S2 owns, so "the procs file registered it" is provable.
proc opa_clear_store {} {
  foreach t {nmos pmos vertical_npn} { catch {op_annot::register $t {}} }
  return [list [op_annot::descriptor nmos] [op_annot::descriptor pmos] \
               [op_annot::descriptor vertical_npn]]
}

## The ordered raw-parameter names of a descriptor (the params triple's field 1).
proc opa_param_names {type} {
  set d [op_annot::descriptor $type]
  if {![dict exists $d params]} { return {} }
  set out {}
  foreach r [dict get $d params] { lappend out [lindex $r 1] }
  return $out
}

## ⚠ A STAND-IN FOR S3's op_annot::save_cards, deliberately FLAT — the hierarchy
## walk is S3's step and is not simulated here. It is NOT a second name builder:
## every card goes through op_annot::devpath, which is the whole of I1.
proc opa_gen_cards {} {
  set out {}
  set n [xschem get instances]
  for {set i 0} {$i < $n} {incr i} {
    if {[catch {xschem getprop instance $i name} nm]} { continue }
    set d [op_annot::descriptor [op_annot::type $nm]]
    if {$d eq {}} { continue }
    if {![dict exists $d params]} { continue }
    set dev [op_annot::devpath $nm]
    if {$dev eq {}} { continue }
    foreach row [dict get $d params] { lappend out ".save ${dev}\[[lindex $row 1]\]" }
  }
  return $out
}

## ⚠ THE ORACLE'S FIRST TWO LINES ARE A COMMENT AND A BLANK — sg13g2_save_params
## returns 12 lines for a 10-card cell. Filter on the card prefix, or every count
## is off by two.
proc opa_proto_cards {txt} {
  set out {}
  foreach l [split $txt \n] { if {[string match ".save *" $l]} { lappend out $l } }
  return $out
}

## -> {nproto ngen equal firstdiff}. The counts are in the golden on purpose:
## without them an empty-vs-empty run passes green.
proc opa_card_diff {prototext} {
  set p [opa_proto_cards $prototext]
  set g [opa_gen_cards]
  if {$p eq $g} { return [list [llength $p] [llength $g] 1 {}] }
  set max [expr {[llength $p] > [llength $g] ? [llength $p] : [llength $g]}]
  set first {}
  for {set i 0} {$i < $max} {incr i} {
    if {[lindex $p $i] ne [lindex $g $i]} {
      set first [list at $i proto=[lindex $p $i] gen=[lindex $g $i]]
      break
    }
  }
  return [list [llength $p] [llength $g] 0 $first]
}

## -> {nproto ngen nmissing missing}. The D9 counterpart of opa_card_diff: the
## generated block is now a SUBSET of the prototype's cards, not an equal set,
## because the descriptor carries six of the prototype's ten parameters. Byte
## equality was the right acceptance for a NAME BUILDER (that is what it proved:
## the generalized builder spells every device exactly as the prototype does);
## it stopped being the right acceptance the moment a ruling deliberately
## changed WHICH parameters are asked for. Membership still proves the names,
## and the counts are in the golden so an empty-vs-empty run cannot pass green.
proc opa_card_subset {prototext} {
  set p [opa_proto_cards $prototext]
  set g [opa_gen_cards]
  set missing {}
  foreach c $g { if {[lsearch -exact $p $c] < 0} { lappend missing $c } }
  return [list [llength $p] [llength $g] [llength $missing] $missing]
}

## ⚠ THE I1 CROSS-CHECK AGAINST 40 SHIPPED SYMBOLS. Every sky130 FET symbol
## already spells its own inner device in a `gm=@spice_get_node …` text, and that
## text IS the third name builder op_annot replaces. This walks all of them and
## compares against what the REGISTERED devproc builds for that symbol's own
## `model=`. -> {ncompared {disagreeing-symbols}}.
proc opa_sky_symscan {} {
  global repo
  set d [op_annot::descriptor nmos]
  if {![dict exists $d devproc] || [dict get $d devproc] eq {}} {
    return {SKY130-NMOS-DESCRIPTOR-HAS-NO-DEVPROC}
  }
  set p [dict get $d devproc]
  set n 0 ; set bad {}
  foreach sf [lsort [glob -nocomplain [file join $repo sky130A xschem_libs \
                                        sky130_fd_pr *fet* symbol *.sym]]] {
    set fh [open $sf r] ; set txt [read $fh] ; close $fh
    if {![regexp {gm=@spice_get_node ([^\}]*)} $txt -> raw]} { continue }
    if {![regexp {model=([A-Za-z0-9_]+)} $txt -> model]} {
      lappend bad "[file tail $sf](no-model)" ; continue
    }
    set t [string trimright [string map [list "\\\\" "\\"] $raw]]
    set idx [string first {@name\.} $t]
    if {$idx < 0} { lappend bad "[file tail $sf](no-anchor)" ; continue }
    set inner [string range $t [expr {$idx + 7}] end]
    regsub {\\?\[gm\]$} $inner {} inner
    set inner [string tolower [string map [list "\\" "" @model $model] $inner]]
    incr n
    if {[catch {uplevel #0 [list $p M1 $model {} X]} built]} {
      lappend bad "[file tail $sf](devproc-raised)" ; continue
    }
    set btail [string range [string tolower $built] [string length {@m.xm1.}] end]
    if {$inner ne $btail} { lappend bad [file tail $sf] }
  }
  return [list $n [lsort $bad]]
}

## gf180 has NO prototype proc to diff against — the 19 shipped FET symbols' own
## `gm=[ngspice::get_node …]` texts are the only oracle for its inner device.
## -> {nscanned {distinct-spellings}}.
proc opa_gf_symscan {} {
  global repo
  set n 0 ; set spell {}
  foreach sf [lsort [glob -nocomplain [file join $repo gf180mcuD xschem_libs \
                                        gf180mcu_pr *fet* symbol *.sym]]] {
    set fh [open $sf r] ; set txt [read $fh] ; close $fh
    if {![regexp {gm=\[ngspice::get_node[^\n]*} $txt frag]} { continue }
    set u [string map [list "\\\\" "\\" "\\{" "\{" "\\}" "\}"] $frag]
    if {![regexp {@name\\\.([A-Za-z0-9_]+)\\\[gm\]} $u -> inner]} {
      lappend spell "[file tail $sf](no-anchor)" ; continue
    }
    incr n
    if {[lsearch -exact $spell $inner] < 0} { lappend spell $inner }
  }
  return [list $n [lsort $spell]]
}

## -> {tag {derived-labels} {problems}}. A `derived` expr references params by
## LABEL as a Tcl variable, so a derived label that shadows a params label makes
## `$cgg` ambiguous, and a derived expr referencing another DERIVED label imposes
## an evaluation-order contract S5 would have to discover. Both are decision D5;
## this proves the shipped descriptors need neither.
proc opa_derived_scan {tag type} {
  set d [op_annot::descriptor $type]
  if {$d eq {}} { return [list $tag NO-DESCRIPTOR NO-DESCRIPTOR] }
  set plabels {}
  if {[dict exists $d params]} {
    foreach r [dict get $d params] { lappend plabels [lindex $r 0] }
  }
  ## ⚠ S5 DECISION D10 WIDENED THIS, AND ONLY THIS. `derived` sees each
  ## params label AND each pinexpr label as a Tcl variable, because pinexpr is
  ## computed first and vgs/vds are the two most natural derived inputs on
  ## sky130 and gf180 (row S27). No SHIPPED descriptor uses one today, so this
  ## line changes no golden — it stops a future `{gm_over_vgs {$gm/$vgs}}` row
  ## from reding P25 as `not-a-param`. The shadowing test below is unchanged and
  ## still catches a derived label that collides with a params label.
  if {[dict exists $d pinexpr]} {
    foreach r [dict get $d pinexpr] { lappend plabels [lindex $r 0] }
  }
  set labels {} ; set bad {}
  if {[dict exists $d derived]} {
    foreach r [dict get $d derived] {
      set lbl [lindex $r 0]
      lappend labels $lbl
      if {[lsearch -exact $plabels $lbl] >= 0} { lappend bad "shadows-a-param:$lbl" }
      foreach v [regexp -all -inline {\$[A-Za-z_][A-Za-z0-9_]*} [lindex $r 1]] {
        set v [string range $v 1 end]
        if {[lsearch -exact $plabels $v] < 0} { lappend bad "not-a-param:$lbl:$v" }
      }
    }
  }
  return [list $tag $labels [lsort -unique $bad]]
}

## Every registration this section sees is recorded, and the two accumulators are
## asserted ONCE at the end (rows P25/P26). Accumulating is what lets a
## one-PDK-at-a-time file still make an all-seven-registrations claim.
proc opa_record {tag type} {
  set d [op_annot::descriptor $type]
  if {[catch {dict get $d match} m]} { set m {} }
  lappend ::opa_matchacc [list $tag [opa_norm $m]]
  lappend ::opa_derivedacc [opa_derived_scan $tag $type]
}
set ::opa_matchacc {}
set ::opa_derivedacc {}

## The 0425 probe devproc: sky130's four-way switch, defined HERE so rows P27-P30
## measure op_annot's match guard and nothing else.
proc opa_sky_probe_devpath {instname model path spiceprefix} {
  set m msky130_fd_pr__$model
  if {[regexp {g5v0d16} $model]} {
    set m xsky130_fd_pr__$model.msky130_fd_pr__${model}_base
  } elseif {[regexp {20v0_(iso|nvt)} $model]} { set m msky130_fd_pr__${model}_base
  } elseif {[regexp {20v0} $model]} { set m m1 }
  return "@m.$path$spiceprefix$instname.$m"
}

# --- the S2 goldens ----------------------------------------------------------
# D7: the prototype's seven PLUS `id`. sky130_write_save_lines never saves `id`
# although every shipped sky130 FET symbol displays it — issue 0427.
#
# ============================================================================
# ⚠ S3b / DECISION D8 — cgso AND cgdo ARE GONE, AND THIS IS THEIR GUARDIAN
# ============================================================================
# ISSUE 0429, RE-MEASURED FOR S3b ON BOTH ngspice BINARIES INSTALLED HERE, one
# parameter per throwaway deck, real sky130 tt models, under the
# `.control … write … .endc` idiom every shipped PDK bench uses:
#
#   /usr/bin/ngspice (42)         gm cgg cgs cgd -> raw written, 0 warnings
#                                 cgso cgdo      -> exit 0, ONE `checkvalid`
#                                                   line, and NO RAW FILE AT ALL
#   /usr/local/bin/ngspice (46+)  cgso cgdo      -> raw written, real values
#                                                   (2.463135e-16 each)
#
# So on 42 a single unknown model parameter suppresses the WHOLE raw while the
# exit status stays 0 — silent total waveform loss. S3b ships the first
# PDK-neutral `Create device OP .save file` menu item, i.e. the first time this
# descriptor is handed to every PDK's users as a generated deck, and a feature
# that destroys the data it exists to display is not shippable. The rows drop.
# ft becomes gm/(2*pi*cgg). A 46+ user who wants them back does one
# `op_annot::register` round-trip in their own rc (I5) — no rebuild, no restart.
#
# REJECTED, and issue 0429's OWN fix sketch is the one refuted by arithmetic:
# relabelling to `cgs`/`cgd` keeps two display rows but cgs measures NEGATIVE
# (-5.52e-16) and cgd is three orders down (6.04e-19), so ft's denominator goes
# from cgg+cgdo+cgso = 1.254e-15 to cgg+cgd+cgs = 2.097e-16 — a silently ~6x
# wrong fT on every sky130 FET on EVERY ngspice. That is exactly I3's
# plausible-wrong-number, arriving from a "fix".
#
# ⚠ TWO GOLDENS GUARD THIS, NOT ONE: P2 asserts the params list itself and P9
# asserts its order and membership. P25's `not-a-param:` scan is the third
# guard and needs no edit — it goes red on its own if `ft` is left referencing
# a $cgso that params no longer carries.
## ⚠ RULING D9 (2026-08-22) — THE DEFAULT SIX. Spec §4.2a. Every SHIPPED MOS
## descriptor is now exactly `id gm gds vgs vth vds` and carries no `derived` and
## no `pinexpr`: "too many parameters displayed is just clutter". vgs/vds became
## ordinary params because they are real BSIM4 instance parameters — measured
## savable on ngspice-42 AND 46+, on sky130 AND gf180, one card per parameter,
## checkvalid=0 and a raw written every time. That measurement is also the
## ngspice-side check issue 0429 said was owed and missing.
set P_SKY_PARAMS {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2}
                  {vds vds 2}}
set P_SKY_PNAMES {id gm gds vgs vth vds}
# The prototype's exact seven, for the byte-for-byte card diff only. ⚠ NOT
# touched by D8: row P3 temporarily overrides `params` with this list to diff
# against sky130_save_fet_params, and the PROTOTYPE still emits cgso/cgdo. When
# S5 deletes the prototype this list goes with it.
set P_SKY_P7     {{gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2}
                  {cgg cgg 1} {cgso cgso 1} {cgdo cgdo 1}}
set P_GF_PARAMS  {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2}
                  {vds vds 2}}
# D4: sg13g2_write_save_lines:310-319 and :331-339, in that ORDER. Kinds are
# sg13g2_display_fet_params:461-470 and _bip_params:524-536, the only authority
# for kind in the tree — a wrong kind makes the save card succeed and the read
# silently miss.
## ⚠ THE LABEL IS `id`, THE PARAMETER IS STILL `ids` — IHP spells the current
## `ids` where BSIM4 spells it `id`, and D9 keeps ONE display vocabulary across
## all three PDKs. The {label param kind} triple exists for exactly this.
set P_IHP_FET_PARAMS {{id ids 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2}
                      {vds vds 2}}
## ⚠ RULING D9b — the HBT is capped at six too, and REORDERED, not merely cut.
## It shipped sixteen rows; the cap alone would have kept the first six in
## declared order, `gm go gmu gpi gx vbe` — five internal conductances and no
## current. A cap chooses how many, a descriptor still chooses which. These six
## mirror the MOS six: ic/ib currents, gm/go conductances, vbe/vbc junctions.
## `vce` is gone because it was DERIVED over vbe and vbc and a derived row can
## only reference DISPLAYED labels — showing it costs three rows for one number.
set P_IHP_NPN_PARAMS {{ic ic 0} {ib ib 0} {gm gm 1} {go go 1} {vbe vbe 2}
                      {vbc vbc 2}}
# D6: the SHIPPED spelling (nfet_01v8.sym:65-66), not §4.2's `{@#1 - @#2}`
# shorthand — the shorthand has no evaluator anywhere in the tree and would force
# S5 to invent a second expansion convention, which is the I1 drift shape.
# `register` stores verbatim, so whatever lands here is what S5 inherits.
#
# ⚠⚠ RE-BASELINED BY S5 / ISSUE 0444 — NOTE THE SPACE BEFORE EACH `)`.
# token.c:24's SPACE(c) = {\n, space, \t, \0, ;} does NOT include `)`, so the
# spelling that shipped here made the second token `@#2:spice_get_voltage)`,
# which misses get_tok_value() and appends NOTHING. Measured live on an
# annotated raw, same instance, same call:
#     without the space -> `0.9 - `   string is double -strict = 0
#     with    the space -> `0.9`      string is double -strict = 1
# Every SHIPPED symbol in the tree already carries the space (nfet_01v8.sym:65-66,
# xschem_library/devices/nmos4.sym:56-57). Rows S28/S29 are the direct guards;
# row P10's translate golden moves with it, from `{ - }` to `{ -  }`.
set P_PINEXPR {{vgs {expr(@#1:spice_get_voltage - @#2:spice_get_voltage )}}
               {vds {expr(@#0:spice_get_voltage - @#2:spice_get_voltage )}}}
# D1: the three match globs. A deliberate change is a one-line edit here; an
# accidental one is a red row.
set P_MATCHACC [list [list sky130:nmos      {*sky130_fd_pr/*}] \
                     [list sky130:pmos      {*sky130_fd_pr/*}] \
                     [list gf180:nmos       {*gf180mcu_pr/*}] \
                     [list gf180:pmos       {*gf180mcu_pr/*}] \
                     [list ihp:nmos         {*sg13g2_pr/*}] \
                     [list ihp:pmos         {*sg13g2_pr/*}] \
                     [list ihp:vertical_npn {*sg13g2_pr/*}]]
# D5: `cgg_tot`, NOT a second `cgg` — the prototype prints the summed capacitance
# under the label `cgg` while also reading the raw param `cgg`, which makes
# `$cgg` ambiguous inside a derived expr. Empty third field = no shadowed label
# and no derived-on-derived reference.
## ⚠ D9: the six MOS descriptors have NO derived rows at all. ft and gm/id are
## gone from every PDK — and note WHAT that means: no simulator computes either
## one. `show <dev> : all` on ngspice-46+ publishes 50 BSIM4 instance parameters
## and neither `ft` nor `gm/id` is among them; both were Tcl arithmetic in the
## PDK procs files, twice, with two different formulas. vertical_npn is
## untouched by D9 — the six are MOS quantities and an HBT has no vgs.
set P_DERIVEDACC [list [list sky130:nmos      {}           {}] \
                       [list sky130:pmos      {}           {}] \
                       [list gf180:nmos       {}           {}] \
                       [list gf180:pmos       {}           {}] \
                       [list ihp:nmos         {}           {}] \
                       [list ihp:pmos         {}           {}] \
                       [list ihp:vertical_npn {}           {}]]

set P_SKY_LIBS ":[file join $repo sky130A xschem_libs]:[file join $repo xschem_library devices]"
set P_GF_LIBS  ":[file join $repo gf180mcuD xschem_libs]:[file join $repo xschem_library devices]"
set P_IHP_LIBS ":[file join $repo ihp-sg13g2 xschem_libs]:[file join $repo xschem_library devices]"

if {[catch {

# ===========================================================================
# P — sky130
# ===========================================================================
# ⚠ UNQUALIFIED, per the fixture note in this file's header: the qualified
# spelling never reaches set_paths and would leave every symbol unresolved.
set XSCHEM_LIBRARY_PATH $P_SKY_LIBS

# ⚠ FIXTURE ROW, green before and after. S1's rows above leave a sky130-shaped
# `nmos` in the store; without this clear, "sourcing the procs file registered
# it" cannot be told apart from "S1 left it there".
check {P0 FIXTURE the store is cleared for nmos/pmos/vertical_npn} \
  [rcall {opa_clear_store}] {0 {{} {} {}}}

# ⚠ CONTROL, green before and after — but not decoration. Measured: a raise
# inside a PDK procs file prints `Tcl_AppInit() error: can not execute <rc>` and
# ABANDONS the rest of the workarea rc (the PDK menu, user_startup_commands, the
# library-manager autostart) while still exiting 0. Issue 0424 makes
# `invalid command name "op_annot::register"` a live possibility in an installed
# tree, so the registrations have to be guarded, not merely appended.
check {P1 CONTROL sourcing sky130_procs.tcl does not raise} \
  [opa_source [file join $repo sky130A sky130_procs.tcl]] {0 {}}

opa_record sky130:nmos nmos
opa_record sky130:pmos pmos

# ⚠ D2: a DEVPROC, not spec §4.2's single template. `xschem translate` cannot
# express sky130_procs.tcl:76-78's four-way switch, and §4.2's one template is
# wrong for the g5v0d16v0 and 20v0 families — 35 of 119 cards, row P3.
check {P2 sky130 registers nmos AND pmos, both with devproc sky130_op_devpath} \
  [rcall {list [dict get [op_annot::descriptor nmos] devproc] \
               [dict get [op_annot::descriptor pmos] devproc] \
               [opa_norm [dict get [op_annot::descriptor nmos] params]] \
               [opa_norm [dict get [op_annot::descriptor pmos] params]]}] \
  [list 0 [list sky130_op_devpath sky130_op_devpath \
                [opa_norm $P_SKY_PARAMS] [opa_norm $P_SKY_PARAMS]]]

xschem load [file join $repo sky130A xschem_libs sky130_tests test_nmos \
                       schematic test_nmos.sch]
check {X3 FIXTURE sky130_tests/test_nmos loaded, M2 is an nfet_01v8 at top level} \
  [list [op_annot::type M2] [xschem translate M2 @model] \
        [xschem get sim_sch_path]] \
  {nmos nfet_01v8 {}}

# ⚠ THE sky130 ACCEPTANCE ROW. The descriptor carries eight params (D7) and the
# prototype saves seven, so the diff runs with params temporarily reduced to the
# prototype's exact seven; the descriptors are restored immediately after.
set p3_nd [op_annot::descriptor nmos]
set p3_pd [op_annot::descriptor pmos]
set p3_n $p3_nd ; catch {dict set p3_n params $P_SKY_P7}
set p3_p $p3_pd ; catch {dict set p3_p params $P_SKY_P7}
catch {op_annot::register nmos $p3_n}
catch {op_annot::register pmos $p3_p}
check {P3 ACCEPTANCE sky130 test_nmos: 119 bare cards == sky130_save_fet_params} \
  [rcall {opa_card_diff [sky130_save_fet_params]}] {0 {119 119 1 {}}}
catch {op_annot::register nmos $p3_nd}
catch {op_annot::register pmos $p3_pd}

# ⚠ THE THREE FAMILIES §4.2's TEMPLATE GETS WRONG. Landmine 9: a wrong device
# name does NOT blank at read time — ngspice writes a full 0.0 column under
# exactly the name asked for — so these are the rows that stop a plausible zero.
check {P4 sky130 g5v0d16v0 devpath is the nested xsky130…/…_base spelling} \
  [rcall {op_annot::devpath M6}] \
  {0 @m.xm6.xsky130_fd_pr__nfet_g5v0d16v0.msky130_fd_pr__nfet_g5v0d16v0_base}
check {P5 sky130 20v0 and 20v0_zvt devpaths collapse to the bare m1} \
  [rcall {list [op_annot::devpath M7] [op_annot::devpath M8]}] \
  {0 {@m.xm7.m1 @m.xm8.m1}}
# ⚠ The `20v0_(iso|nvt)` arm is instantiated by NO shipped test cell, so it is
# unreachable through devpath. Calling the REGISTERED devproc directly is the
# only way to cover the fourth arm at all.
check {P6 sky130 the 20v0_(iso|nvt) arm appends _base (no cell instantiates it)} \
  [rcall {string tolower [uplevel #0 [list \
      [dict get [op_annot::descriptor nmos] devproc] M1 nfet_20v0_nvt {} X]]}] \
  {0 @m.xm1.msky130_fd_pr__nfet_20v0_nvt_base}

# ⚠ I1 AGAINST 40 SHIPPED SYMBOLS. Each sky130 FET symbol's own
# `gm=@spice_get_node …` text is a name builder op_annot replaces; they must
# agree. The ONE named exception is measured and filed as issue 0428:
# pfet_g5v0d16v0_nf.sym spells `msky130_fd_pr__pfet_g5v0d16v0_base` where its own
# non-_nf sibling and its nfet twin both spell the nested `xsky130_fd_pr__…`
# form. NOT a skip and NOT a loosened comparison — the golden NAMES the outlier,
# so the other 39 stay guarded and fixing 0428 flips this row to {40 {}}.
check {P7 I1 CROSS-CHECK: 40 shipped sky130 FET symbols, 1 known outlier (0428)} \
  [rcall {opa_sky_symscan}] {0 {40 pfet_g5v0d16v0_nf.sym}}

# ⚠ KIND COMES FROM THE DESCRIPTOR — the call sites below omit it deliberately.
# A consumer that retypes `0` has become a second builder of the same decision,
# and when the descriptor changes only one of them moves.
check {P8 sky130 kinds come from params: gm bare, id i(), vth v()} \
  [rcall {list [op_annot::vector M2 gm] [op_annot::vector M2 id] \
               [op_annot::vector M2 vth]}] \
  [list 0 [list {@m.xm2.msky130_fd_pr__nfet_01v8[gm]} \
                {i(@m.xm2.msky130_fd_pr__nfet_01v8[id])} \
                {v(@m.xm2.msky130_fd_pr__nfet_01v8[vth])}]]

# ⚠ D7 / issue 0427. sky130_write_save_lines saves seven params and never `id`,
# yet every shipped sky130 FET symbol displays `id=@spice_get_node i(…[id])`.
# The descriptor carries `id`; this row is what stops a later "align with the
# prototype" edit from silently deleting a parameter users already see.
#
# ⚠ AND SINCE S3b, THE GUARDIAN OF DECISION D8 IN THE OTHER DIRECTION: cgso and
# cgdo are NOT here, and an edit that puts them back — "align with the
# prototype" is exactly how they would come back — reds this row. See the D8
# block above P_SKY_PARAMS for the two-binary measurement.
check {P9 sky130 param order: `id` the prototype never saves (0427), no cgso/cgdo (0429)} \
  [rcall {opa_param_names nmos}] [list 0 $P_SKY_PNAMES]

# ⚠ D6, and a MEASURED TRAP FOR S5: with no raw loaded the pin expression
# translates to the literal " -  ", which is not a number. S5's formatter must
# test `string is double -strict` and render BLANK (I3) — never that string, and
# never 0.
#
# ⚠ THE EXPECTED TRANSLATE OUTPUT IS ` -  ` WITH TWO TRAILING SPACES SINCE S5
# ADDED THE 0444 SPACE. One space is the expression's own separator before the
# `)`, the other is what the unresolved `@#2:spice_get_voltage ` token leaves
# behind. Before 0444 this was ` - `, and the difference is precisely the token
# that used to be swallowed — so a revert of the space reds here as well as at
# S28/S29.
# ⚠ INVERTED BY RULING D9, AND THE INVERSION IS THE SUBSTANCE OF THE RULING.
# This row used to assert that sky130 shipped the two pinexpr strings. It now
# asserts that it ships NONE — vgs and vds are ordinary `params` of kind 2,
# read from the raw like every other number — and it keeps measuring the
# tokeniser fact on a LITERAL string, so issue 0444 stays a live measurement
# even though no shipped descriptor can reach it any more. That literal really
# does translate to ` -  ` with two trailing spaces (one from the expression's
# own separator before `)`, one left by the unresolved `@#2:spice_get_voltage `
# token), and it really is not a double — which is why a user who writes a
# pinexpr still needs §4.2a's warning about the space.
check {P10 D9 sky130 ships NO pinexpr; vgs/vds are kind-2 params, and 0444 is still live} \
  [rcall {set e [lindex [lindex $::P_PINEXPR 0] 1]
          list [dict exists [op_annot::descriptor nmos] pinexpr] \
               [dict exists [op_annot::descriptor nmos] derived] \
               [op_annot::vector M2 vgs 2] \
               [op_annot::vector M2 vds 2] \
               [xschem translate M2 $e] \
               [string is double -strict [xschem translate M2 $e]]}] \
  [list 0 [list 0 0 \
                "v(@m.xm2.msky130_fd_pr__nfet_01v8\[vgs\])" \
                "v(@m.xm2.msky130_fd_pr__nfet_01v8\[vds\])" \
                { -  } 0]]

# ===========================================================================
# P — gf180mcu
# ===========================================================================
set XSCHEM_LIBRARY_PATH $P_GF_LIBS
check {P11 FIXTURE the store is cleared again before gf180} \
  [rcall {opa_clear_store}] {0 {{} {} {}}}
check {P12 CONTROL sourcing gf180_procs.tcl does not raise} \
  [opa_source [file join $repo gf180mcuD gf180_procs.tcl]] {0 {}}
opa_record gf180:nmos nmos
opa_record gf180:pmos pmos

# ⚠ THE TEMPLATE IS COMPARED EXACTLY, escaping and all — that is issue 0422's
# subject. `xschem translate` tokenises on whitespace only (token.c:24), so an
# unescaped `.` does not terminate an @-token and an unknown @-token appends
# NOTHING: the unescaped spelling yields a plausible wrong string with no error.
check {P13 gf180 registers nmos AND pmos with the escaped m0 template} \
  [rcall {list [dict get [op_annot::descriptor nmos] devpath] \
               [dict get [op_annot::descriptor pmos] devpath] \
               [opa_norm [dict get [op_annot::descriptor nmos] params]]}] \
  [list 0 [list {\@m.@path@spiceprefix@name\.m0} \
                {\@m.@path@spiceprefix@name\.m0} [opa_norm $P_GF_PARAMS]]]

xschem load [file join $repo gf180mcuD xschem_libs gf180mcu_tests \
                       test_nfet_06v0 schematic test_nfet_06v0.sch]
# ⚠ gf180 has NO prototype proc — the 19 shipped FET symbols' own
# `gm=[ngspice::get_node …]` texts are its only oracle for the inner device, and
# they are uniformly `m0`. Scanning them, rather than hard-coding `m0` twice, is
# what makes this a cross-check instead of a restatement.
check {P14 gf180 nfet_06v0 devpath == the inner device all 19 symbols spell} \
  [list [opa_gf_symscan] [rcall {op_annot::devpath M1}]] \
  {{19 m0} {0 @m.xm1.m0}}

xschem load [file join $repo gf180mcuD xschem_libs gf180mcu_tests \
                       test_pfet_06v0 schematic test_pfet_06v0.sch]
# ⚠ Proves `pmos` was registered, not just `nmos` — §4.2's verbatim copy would
# leave this instance with no descriptor and no diagnostic.
check {P15 gf180 pfet_06v0 (type=pmos) builds its devpath too} \
  [list [op_annot::type M1] [rcall {op_annot::devpath M1}]] {pmos {0 @m.xm1.m0}}

# ===========================================================================
# P — IHP sg13g2
# ===========================================================================
set XSCHEM_LIBRARY_PATH $P_IHP_LIBS
check {P16 FIXTURE the store is cleared again before IHP} \
  [rcall {opa_clear_store}] {0 {{} {} {}}}
check {P17 CONTROL sourcing sg13g2_procs.tcl does not raise} \
  [opa_source [file join $repo ihp-sg13g2 sg13g2_procs.tcl]] {0 {}}
opa_record ihp:nmos nmos
opa_record ihp:pmos pmos
opa_record ihp:vertical_npn vertical_npn

check {P18 IHP registers nmos, pmos AND vertical_npn} \
  [rcall {list [dict get [op_annot::descriptor nmos] devpath] \
               [dict get [op_annot::descriptor pmos] devpath] \
               [dict get [op_annot::descriptor vertical_npn] devproc]}] \
  [list 0 [list {\@n.@path@spiceprefix@name\.n@model} \
                {\@n.@path@spiceprefix@name\.n@model} sg13g2_op_npn_devpath]]

# ⚠ WAS BYTE-FOR-BYTE AGAINST sg13g2_write_save_lines; IS NOW A SUBSET, BY
# RULING D9. The prototype saves ten parameters per FET and the descriptor now
# asks for six, so an equal-set assertion would red for the one reason that is
# not a defect. What the row still proves is the thing the byte diff existed to
# prove — that the generalized builder spells each device EXACTLY as the
# prototype does — plus the counts, so an empty-vs-empty run cannot pass green.
# The six-of-ten shape is asserted in the golden, so a descriptor that silently
# grew or shrank reds here.
xschem load [file join $repo ihp-sg13g2 xschem_libs sg13g2_tests dc_lv_nmos \
                       schematic dc_lv_nmos.sch]
check {P19 ACCEPTANCE IHP dc_lv_nmos: the 6 generated cards are a subset of the prototype's 10} \
  [rcall {opa_card_subset [sg13g2_save_params]}] {0 {10 6 0 {}}}

xschem load [file join $repo ihp-sg13g2 xschem_libs sg13g2_tests dc_lv_pmos \
                       schematic dc_lv_pmos.sch]
check {P20 ACCEPTANCE IHP dc_lv_pmos: the 6 generated cards are a subset of the prototype's 10} \
  [rcall {opa_card_subset [sg13g2_save_params]}] {0 {10 6 0 {}}}

# The prototype still writes 26 (13 params x two HBTs); the descriptor asks for 12.
xschem load [file join $repo ihp-sg13g2 xschem_libs sg13g2_tests dc_hbt_13g2_5t \
                       schematic dc_hbt_13g2_5t.sch]
# ⚠ 12 = 6 params x two HBTs, npn13G2 and npn13G2_5t, both collapsing to
# qnpn13g2. Was 26 (13 x 2) before ruling D9b trimmed the descriptor to six.
check {P21 ACCEPTANCE IHP dc_hbt_13g2_5t: the 12 generated cards are a subset of the prototype's 26} \
  [rcall {opa_card_subset [sg13g2_save_params]}] {0 {26 12 0 {}}}

# ⚠ THE ENTIRE JUSTIFICATION FOR THE `devproc` KEY, isolated from the card diff.
# `xschem translate` has no regsub, so sg13g2_procs.tcl:321-324's `_5t` strip
# cannot be expressed as a template at all.
check {P22 IHP the _5t model suffix is stripped: Q2 (npn13G2_5t) -> qnpn13g2} \
  [rcall {list [xschem translate Q2 @model] [op_annot::devpath Q2] \
               [op_annot::devpath Q1]}] \
  {0 {npn13G2_5t @q.xq2.qnpn13g2 @q.xq1.qnpn13g2}}

# ⚠ ORDER IS PART OF THE GOLDEN: the params list IS the save-card order, and the
# card diff above is ordered. §4.2's six-row NPN list would silently drop
# gmu gpi gx cbe cbc cbep cbcp — and with them the prototype's rin and ft.
check {P23 IHP params are the prototype's ten and thirteen, in its order} \
  [rcall {list [opa_norm [dict get [op_annot::descriptor nmos] params]] \
               [opa_norm [dict get [op_annot::descriptor vertical_npn] params]]}] \
  [list 0 [list [opa_norm $P_IHP_FET_PARAMS] [opa_norm $P_IHP_NPN_PARAMS]]]

xschem load [file join $repo ihp-sg13g2 xschem_libs sg13g2_tests dc_lv_nmos \
                       schematic dc_lv_nmos.sch]
check {P24 IHP kinds come from params: ids i(), gm bare, vth v()} \
  [rcall {list [op_annot::vector M1 ids] [op_annot::vector M1 gm] \
               [op_annot::vector M1 vth]}] \
  [list 0 [list {i(@n.xm1.nsg13_lv_nmos[ids])} {@n.xm1.nsg13_lv_nmos[gm]} \
                {v(@n.xm1.nsg13_lv_nmos[vth])}]]

# ===========================================================================
# P — the two claims that span all three PDKs
# ===========================================================================
# ⚠ Asserted from the accumulators, so these rows cover all SEVEN registrations
# even though only one PDK is registered at a time. The label lists pin D5's
# naming (`cgg_tot`, not a second `cgg`); the empty third field is the structural
# claim that no derived label shadows a params label and no derived expr
# references another derived label — which is what lets S5 evaluate them in any
# order with no contract to discover.
check {P25 derived labels are D5's, and none shadows a param or another derived} \
  [opa_norm $::opa_derivedacc] [opa_norm $P_DERIVEDACC]

check {P26 all seven registrations carry their PDK's match glob (0425 / D1)} \
  [opa_norm $::opa_matchacc] [opa_norm $P_MATCHACC]

# ===========================================================================
# P — issue 0425: the shared `type=nmos` key
# ===========================================================================
# ⚠ A DELIBERATELY MIXED CELL: one sky130 nfet_01v8 and one generic
# xschem_library/devices/nmos.sym. Both report `type=nmos`, which is the whole of
# 0425. No sky130A/, gf180mcuD/ or ihp-sg13g2/ schematic instantiates a generic
# devices/[np]mos today (measured: grep -rl for a devices/nmos instance line ->
# 0 files),
# so this is a plausible-user cell rather than a present-tree one — but landmine
# 9 means the consequence is a fabricated 0.0, not a blank, so it does not stay
# hypothetical.
set f [open [file join $lib mix.sch] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {sky130_fd_pr/nfet_01v8.sym} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}
C {nmos.sym} 600 -300 0 0 {name=M2 model=cmosn}}
close $f
set XSCHEM_LIBRARY_PATH "${P_SKY_LIBS}:$lib"
xschem load [file join $lib mix.sch]
check {X4 FIXTURE mix.sch: two instances, BOTH type=nmos, different cells} \
  [list [xschem get instances] [op_annot::type M1] [op_annot::type M2] \
        [xschem getprop instance M1 cell::name] \
        [xschem getprop instance M2 cell::name]] \
  {2 nmos nmos sky130_fd_pr/nfet_01v8.sym nmos.sym}

# ⚠ CONTROL, GREEN BEFORE AND AFTER, AND IT IS THE POINT OF THE WHOLE DESIGN. A
# descriptor with no `match` key must keep annotating every instance of its type
# — that is what leaves S1's 32 rows above, and a user's own
# `op_annot::register` in their rc (I5), working unchanged. If this row ever goes
# red the 0425 fix has stopped being backward compatible.
catch {op_annot::register nmos [list devproc opa_sky_probe_devpath \
                                     params {{gm gm 1}}]}
check {P27 CONTROL a descriptor with NO match key still annotates everything} \
  [rcall {list [op_annot::devpath M1] [op_annot::devpath M2]}] \
  {0 {@m.xm1.msky130_fd_pr__nfet_01v8 @m.m2.msky130_fd_pr__cmosn}}

# ⚠ 0425 FAILURE (1). Before: the generic device wears sky130's inner-device
# name, `@m.m2.msky130_fd_pr__cmosn`, and ngspice answers 0.0 for it rather than
# nothing. I3 says BLANK, so blank is what a non-matching instance must get.
catch {op_annot::register nmos [list devproc opa_sky_probe_devpath \
                                     params {{gm gm 1}} match {*sky130_fd_pr/*}]}
check {P28 0425(1) a generic devices/nmos gets NO devpath under a match glob} \
  [rcall {list [op_annot::devpath M1] [op_annot::devpath M2]}] \
  {0 {@m.xm1.msky130_fd_pr__nfet_01v8 {}}}

# ⚠ vector must short-circuit on the blank devpath BEFORE _kind's deliberate
# raise, or every non-matching instance turns a data condition into an error in a
# draw path (S6/S9), which I3 forbids. The rc in the golden is the claim.
check {P29 0425 vector on a non-matching instance is BLANK, not a raise} \
  [rcall {op_annot::vector M2 gm}] {0 {}}

# ⚠ 0425 FAILURE (2). Two PDKs sourced into one interpreter — exactly what spec
# §8's cross-PDK test does — and the second `register nmos` REPLACES the first
# (S1 row B3 guards that replacement deliberately). The ACCEPTED RESIDUAL is that
# the sky130 registration is still lost; what this row demands is that the loss
# degrades to BLANK rather than to `@n.xm1.nnfet_01v8`, a confidently wrong
# IHP-shaped name for a sky130 device.
catch {op_annot::register nmos [list devpath {\@n.@path@spiceprefix@name\.n@model} \
                                     params {{gm gm 1}} match {*sg13g2_pr/*}]}
check {P30 0425(2) a cross-PDK overwrite degrades to BLANK, not a wrong name} \
  [rcall {op_annot::devpath M1}] {0 {}}

# ===========================================================================
# P31 — RULING D9 END TO END: THE SHIPPED SIX, READ OUT OF A REAL RAW
# ===========================================================================
# ⚠ THE ONE ROW THAT TESTS WHAT D9 ACTUALLY CHANGED FOR A USER. Every other row
# in this section compares our strings against our strings; this one puts the
# six vectors into a raw in the R3 shapes ngspice really writes and asserts the
# block a schematic shows.
#
# The decisive half is `vgs` and `vds`. Before D9 they were `pinexpr` rows
# computed from pin voltages, which is why issue 0446 could fabricate `vgs = 0`
# on a GND source. Here they come from the raw like every other number — a wrong
# raw blanks them instead of inventing them — and the vector names are exactly
# what ngspice emits: measured `v(@m.xm1.msky130_fd_pr__nfet_01v8[vgs])`, kind 2.
#
# ⚠ THE LABEL COLUMN IS 3 WIDE, not 5. The block pads to its longest label and
# the six top out at three characters, so `id  = ` has TWO spaces. A golden
# copied from the pre-D9 block would be wrong in every line.
set XSCHEM_LIBRARY_PATH $P_SKY_LIBS
opa_clear_store
opa_source [file join $repo sky130A sky130_procs.tcl]
xschem load [file join $repo sky130A xschem_libs sky130_tests test_nmos \
                       schematic test_nmos.sch]
set P_D9_DEV {@m.xm2.msky130_fd_pr__nfet_01v8}
set f [open [file join $scratch p_d9.raw] w]
puts -nonewline $f "Title: D9 six-parameter fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 6
No. Points: 1
Variables:
\t0\ti(${P_D9_DEV}\[id\])\tcurrent
\t1\t${P_D9_DEV}\[gm\]\tadmittance
\t2\t${P_D9_DEV}\[gds\]\tadmittance
\t3\tv(${P_D9_DEV}\[vgs\])\tvoltage
\t4\tv(${P_D9_DEV}\[vth\])\tvoltage
\t5\tv(${P_D9_DEV}\[vds\])\tvoltage
Values:
0\t1e-05
\t1e-04
\t1e-06
\t0.9
\t0.7
\t1.8
"
close $f
set p31_ann [rcall {xschem annotate_op [file join $scratch p_d9.raw] 0}]
check {P31 D9 the shipped six render REAL numbers from a raw, vgs and vds included} \
  [list [lindex $p31_ann 0] [rcall {op_annot::text M2}]] \
  [list 0 [list 0 "id  = 10u\ngm  = 100u\ngds = 1u\nvgs = 0.9\nvth = 0.7\nvds = 1.8\n"]]

# ⚠ NON-VACUITY FOR P31, AND FOR I3 ON THE TWO ROWS THAT USED TO BE pinexpr.
# The same instance against a raw that carries only `id` must blank the other
# five — including vgs and vds, which BEFORE D9 would have printed a fabricated
# `0` here (issue 0446: the source is GND, token.c:4364 hardcodes it to 0.0, and
# translate's eval_expr pass reads `expr(- - 0.0 )` as 0). A green P31 with this
# row red would mean the formatter is echoing the descriptor, not reading a raw.
set f [open [file join $scratch p_d9_thin.raw] w]
puts -nonewline $f "Title: D9 one-parameter fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 1
No. Points: 1
Variables:
\t0\ti(${P_D9_DEV}\[id\])\tcurrent
Values:
0\t1e-05
"
close $f
set p32_ann [rcall {xschem annotate_op [file join $scratch p_d9_thin.raw] 0}]
check {P32 I3 with only id in the raw the other five BLANK — vgs/vds no longer fabricate 0} \
  [list [lindex $p32_ann 0] [rcall {op_annot::text M2}]] \
  [list 0 [list 0 "id  = 10u\ngm  =\ngds =\nvgs =\nvth =\nvds =\n"]]

} perr]} {
  puts "UNEXPECTED ERROR (section P): $perr"
  incr fail
}


# =============================================================================
# SECTION S — S5 of doc/claude/specs/op_annotation.md: THE DISPLAY FORMATTER
# =============================================================================
# S1 built the name builder, S2 filled the descriptor store. S5 is the READ
# side: `op_annot::text <instname>` turns a descriptor plus a loaded raw into
# the block of `label = <to_eng value>` lines a schematic shows.
#
#   op_annot::raw_or_blank <vecname>  -> the number, or {}    (port of
#                                        sg13g2_raw_or_double, :436-440)
#   op_annot::eng_or_blank <value>    -> to_eng, or {}        (port of
#                                        sg13g2_to_eng_safe,  :443-446, with
#                                        the ONE line this step exists to
#                                        change: NaN becomes BLANK)
#   op_annot::text <instname>         -> the formatted block, or {}
#
# ============================================================================
# ⚠ I3 IS THE WHOLE STEP: BLANK, NEVER A FABRICATED NUMBER
# ============================================================================
# The IHP prototype prints the literal string `NaN` for a vector it could not
# read (sg13g2_procs.tcl:445) and that is the single behaviour the port must
# not carry. Three DISTINCT ways a number can be fabricated here, all measured
# on this tree, and each has its own row because no one guard closes two:
#
#   (a) `xschem raw value <v> -1` RAISES "No raw file loaded" (scheduler.c:10461)
#       when nothing is loaded — an uncaught raise inside a tcleval draw path
#       (S6/S9) breaks rendering outright.               -> rows S1, S8, S9
#   (b) A raw READ but never PUBLISHED returns a FABRICATED 0. `xschem raw read
#       <f> op` does not call update_op() (save.c:1988), so cursor_b_val stays
#       my_calloc-zeroed and point -1 reads 0.0 for a vector whose true value
#       is 9.9999997e-05. Measured in a FRESH process:
#           raw read  -> `xschem raw annot` = `-1 0 -1`, `raw value …[gm] -1` = 0
#           annotate_op -> `xschem raw annot` = `0 0 -1`, the same read = 1e-4
#       ⚠ THIS REPRODUCES ONLY IN A FRESH PROCESS. Once an annotate_op has
#       published, cursor_b_val survives a later `xschem load` and the same
#       sequence returns the TRUE value — so row S14 must be the FIRST raw
#       operation in this file or it passes vacuously. Nothing above section S
#       touches a raw; keep it that way.               -> rows S14, S15, S16
#   (c) `expr {1.0/0.0}` yields `Inf` with NO raise, `string is double -strict
#       Inf` is 1, and `to_eng Inf` is `infT`. Every shipped derived row (ft,
#       gm/id, rin) is a division, so a plain catch is NOT enough — a
#       finiteness test is what stops `infT` reaching a schematic.
#                                                        -> rows S6, S24
#
# ============================================================================
# ⚠ ISSUE 0444 — THE REGISTERED pinexpr STRINGS COULD NEVER PRODUCE A NUMBER
# ============================================================================
# token.c:24's SPACE(c) = {\n, space, \t, \0, ;} does NOT include `)`, so in
#     expr(@#1:spice_get_voltage - @#2:spice_get_voltage)
# the SECOND token is `@#2:spice_get_voltage)`, misses get_tok_value() and
# appends NOTHING. Measured live on an annotated raw:
#     registered spelling          -> `0.9 - `   string is double -strict = 0
#     with ONE SPACE before the `)` -> `0.9`      string is double -strict = 1
# Every SHIPPED symbol in the tree already carries that space
# (nfet_01v8.sym:65-66, xschem_library/devices/nmos4.sym:56-57). Without the
# fix an S5 block on sky130 and gf180 renders all six params and both derived
# rows and leaves vgs/vds PERMANENTLY BLANK, and this file's acceptance golden
# would quietly bless it. Rows S28 (the stored strings) and S29 (the live
# translate, both spellings in one call so the space is proven to be the
# cause). $P_PINEXPR and row P10 move with it — P10's translate golden goes
# from `{ - }` to `{ -  }`.
#
# ============================================================================
# THE FIXTURE: AN ASCII OPERATING-POINT RAW, NO NGSPICE
# ============================================================================
# `xschem annotate_op` reads a hand-written ASCII raw exactly as it reads
# ngspice's (the technique test_raw_ascii_point_bounds.tcl already uses), and
# it publishes: `xschem raw annot` goes to `0 0 -1`. Round values make the
# golden exact and deterministic. The six vector names are the R3 shapes S1
# builds — i(…[id]) for kind 0, bare for kind 1, v(…) for kind 2 — so the
# fixture is itself an I1 cross-check: if op_annot::vector ever changed shape,
# every read below would miss.
#
# ⚠ THE READ-BACK IS SINGLE PRECISION. `1e-04` in the file comes back as
# 9.9999997e-05 and `0.7` as 0.69999999. The goldens are the to_eng
# renderings (100u, 0.7) precisely because they are stable across that.

set S_LIBS "${P_SKY_LIBS}:$lib"

# --- the goldens -------------------------------------------------------------
# Labels: id gm gds vth vdsat cgg (params) vgs vds (pinexpr) ft gm/id (derived).
# Longest is 5 (`vdsat`, `gm/id`), so the label column is 5 wide.
# ⚠ A BLANK ROW IS `label =` WITH NOTHING AFTER THE `=` — not `label = ` and
# not `label = 0`. The step's acceptance names that exact shape.
set S_BLANK "id    =
gm    =
gds   =
vth   =
vdsat =
cgg   =
vgs   =
vds   =
ft    =
gm/id =
"
# ft = gm/(2*pi*cgg) = 1e-4/(2*3.141592654*1e-15) = 1.5915e10 -> 15.92G
# gm/id = 1e-4/1e-5 = 10.  vgs = v(g)-v(s) = 0.9-0, vds = v(d)-v(s) = 1.8-0.
set S_GOLD "id    = 10u
gm    = 100u
gds   = 1u
vth   = 0.7
vdsat = 0.1
cgg   = 1f
vgs   = 0.9
vds   = 1.8
ft    = 15.92G
gm/id = 10
"

## The SHIPPED spelling, with the space token.c:24 requires. Written out here
## rather than read from the store so rows S27/S11 keep working even if the
## descriptor is later re-registered.
set S_VGS_OK {expr(@#1:spice_get_voltage - @#2:spice_get_voltage )}
set S_VGS_NO {expr(@#1:spice_get_voltage - @#2:spice_get_voltage)}
set S_VDS_OK {expr(@#0:spice_get_voltage - @#2:spice_get_voltage )}

# ============================================================================
# ⚠ RULING D9 (2026-08-22) — WHY THIS SECTION REGISTERS ITS OWN DESCRIPTOR
# ============================================================================
# D9 cut every SHIPPED descriptor to six params — id gm gds vgs vth vds — and
# removed every `pinexpr`, because vgs/vds are real BSIM4 instance parameters
# and were only ever computed from pin voltages because the prototypes did it
# that way. Spec §4.2a.
#
# Section S is the FORMATTER's test, not the PDKs'. Its goldens are counted on a
# ten-row block that exercises params AND pinexpr AND derived together, the
# label-column padding across a 5-char label, a derived row over a division, and
# — decisively — rows S17b and S29, the guardians for issues 0446 (a pinexpr
# fabricates `vgs = 0` when the source is GND and the other net is absent) and
# 0444 (the load-bearing space before `)`). BOTH C defects are STILL OPEN and are
# now reachable only through a user-written pinexpr. Deleting their guardians
# because no shipped descriptor triggers them any more would be the exact move
# issue 0499 is about: a test that cannot fail is not a test.
#
# So this section registers the PRE-D9 sky130 shape itself and owns it. Rows
# that assert what the PDKs SHIP live in sections P, O and Q, and those goldens
# moved to the six.
set S_NMOS_LEGACY [list \
  devproc sky130_op_devpath \
  match   {*sky130_fd_pr/*} \
  params  {{id id 0} {gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2} {cgg cgg 1}} \
  pinexpr [list [list vgs $S_VGS_OK] [list vds $S_VDS_OK]] \
  derived {{ft {$gm/(2*3.141592654*$cgg)}} {gm/id {$gm/$id}}}]

## Every line of a block, with the trailing empty element dropped.
proc opa_s5_lines {b} {
  set l [split $b \n]
  if {[llength $l] && [lindex $l end] eq {}} { set l [lrange $l 0 end-1] }
  return $l
}
## -> {nlines {offenders}}. An offender is any line that is not exactly
## `<label> =` — anything at all after the `=` counts, a lone space included.
proc opa_s5_allblank {b} {
  set bad {}
  set n 0
  foreach ln [opa_s5_lines $b] {
    incr n
    if {![regexp {^[^ ].* =$} $ln]} { lappend bad $ln }
  }
  return [list $n $bad]
}
## -> the list of forbidden tokens actually present anywhere in the block.
## None of the ten sky130 labels contains any of them, so a hit is a value.
proc opa_s5_fabricated {b} {
  set hits {}
  foreach t {0 NaN Inf infT -} {
    if {[string first $t $b] >= 0} { lappend hits $t }
  }
  return $hits
}
## -> {nlines nvalued}. The counting twin of opa_s5_allblank, for the rows that
## claim a block IS populated — `allblank` reports the offending lines, which
## is useless as a golden when every line is meant to carry a value.
proc opa_s5_populated {b} {
  set n 0 ; set v 0
  foreach ln [opa_s5_lines $b] {
    incr n
    if {![regexp {^[^ ].* =$} $ln]} { incr v }
  }
  return [list $n $v]
}
## The value rendered for <label>, or MISSING-ROW. Splits at the FIRST ` =`,
## so a blank row yields {} and `id    = 10u` yields `10u`.
proc opa_s5_rowval {b lbl} {
  foreach ln [opa_s5_lines $b] {
    set i [string first { =} $ln]
    if {$i < 0} continue
    if {[string trimright [string range $ln 0 [expr {$i - 1}]]] ne $lbl} continue
    set v [string range $ln [expr {$i + 2}] end]
    if {$v eq {}} { return {} }
    return [string range $v 1 end]
  }
  return MISSING-ROW
}
## Read every params row of the LIVE descriptor two ways and report the rows
## where the two compositions disagree (row S12).
proc opa_s5_wrap_vs_vector {inst type} {
  set d [op_annot::descriptor $type]
  if {![dict exists $d params]} { return NO-PARAMS }
  set dev [op_annot::devpath $inst]
  if {$dev eq {}} { return NO-DEVPATH }
  set n 0 ; set bad {}
  foreach row [dict get $d params] {
    incr n
    set a [op_annot::_wrap $dev [lindex $row 1] [lindex $row 2]]
    if {[catch {op_annot::vector $inst [lindex $row 1]} b]} { set b RAISED:$b }
    if {$a ne $b} { lappend bad [list [lindex $row 1] $a $b] }
  }
  return [list $n $bad]
}
## Every params row's rendered value against a DIRECT read through
## op_annot::vector + op_annot::eng_or_blank (row S13). -> {nrows {mismatches}}
proc opa_s5_values_vs_direct {inst type block} {
  set d [op_annot::descriptor $type]
  if {![dict exists $d params]} { return NO-PARAMS }
  set n 0 ; set bad {}
  foreach row [dict get $d params] {
    set lbl [lindex $row 0]
    set want {}
    if {![catch {op_annot::vector $inst [lindex $row 1]} v]} {
      if {[catch {op_annot::eng_or_blank [op_annot::raw_or_blank $v]} want]} {
        set want RAISED
      }
    }
    set got [opa_s5_rowval $block $lbl]
    incr n
    if {$got ne $want} { lappend bad [list $lbl got=$got want=$want] }
  }
  return [list $n $bad]
}
## A tripwire body: if to_eng ever evaluates its argument this fires (row S7).
set ::opa_s5_tripped 0
proc opa_s5_tripwire {} { set ::opa_s5_tripped 1 ; return 1e-6 }

if {[catch {

# ⚠ RULING D9b — SECTIONS S AND K RUN WITH THE CAP LIFTED, DELIBERATELY.
# op_annot::text now shows at most six rows (spec §4.2b, `::op_annot_max_rows`).
# These two sections are the FORMATTER's and the CARRIER's tests: their goldens
# are the ten-row block that exercises params AND pinexpr AND derived together,
# the label column padding to a 5-char label, and — decisively — the 0446/0444
# guardians, whose rows are the 7th and 8th in declared order and would be the
# first the cap discards. Capping them would not test the cap; it would delete
# the only coverage two open C defects have.
#
# The cap itself is tested on its own terms in section R, and the DEFAULT is
# what sections P, O, Q and T measure. Restored immediately after section K.
set ::op_annot_max_rows 0


# ===========================================================================
# S28 — ISSUE 0444, THE STORED STRINGS (before any fixture, both PDKs)
# ===========================================================================
# Asserted on what `op_annot::register` actually stored, so a later
# re-tightening of the spelling reds here rather than silently blanking two
# rows on two of the three PDKs.
set XSCHEM_LIBRARY_PATH $P_GF_LIBS
opa_clear_store
opa_source [file join $repo gf180mcuD gf180_procs.tcl]
set s_gf_pin [dict exists [op_annot::descriptor nmos] pinexpr]
set XSCHEM_LIBRARY_PATH $P_SKY_LIBS
opa_clear_store
opa_source [file join $repo sky130A sky130_procs.tcl]
set s_sky_pin [dict exists [op_annot::descriptor nmos] pinexpr]

# ⚠ INVERTED BY D9, AND THE INVERSION IS THE POINT. This row used to assert that
# the two shipped pinexpr strings carried the space token.c:24 needs. Under D9
# there IS no shipped pinexpr on any PDK — vgs/vds are ordinary `params` read
# from the raw — which is what takes issues 0444 and 0446 off the shipped path
# without either C defect being fixed. The row now asserts THAT, so re-adding a
# pinexpr to a PDK file (the "align with the prototype" move) reds here and the
# author is sent to §4.2a before their users meet the tokeniser.
check {S28 D9 NO shipped descriptor carries a pinexpr — 0444/0446 are off the stock path} \
  [list $s_sky_pin $s_gf_pin] [list 0 0]

# The rest of section S runs on the pre-D9 shape, registered here and owned here.
# ⚠ THE SPELLING GUARD MOVES WITH IT: this asserts that what `register` STORED
# is the spelling with the space, so a later tidy-up of S_VGS_OK reds here
# rather than silently blanking two rows for every user who writes a pinexpr.
op_annot::register nmos $S_NMOS_LEGACY
check {S28b the section's own descriptor stored the 0444 spelling verbatim} \
  [list [opa_norm [dict get [op_annot::descriptor nmos] pinexpr]] \
        [llength [dict get [op_annot::descriptor nmos] params]]] \
  [list [opa_norm [list [list vgs $S_VGS_OK] [list vds $S_VDS_OK]]] 6]

# ===========================================================================
# FIXTURE — a flat sky130 nfet with its three terminals on named nets
# ===========================================================================
# ⚠ UNQUALIFIED, per this file's header note: the qualified spelling never
# reaches set_paths and would leave every symbol unresolved.
set XSCHEM_LIBRARY_PATH $S_LIBS
set f [open [file join $lib s5_flat.sch] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {sky130_fd_pr/nfet_01v8.sym} 0 0 0 0 {name=M1 W=1 L=0.15 nf=1}
C {lab_pin.sym} 20 -30 0 0 {name=p1 lab=d}
C {lab_pin.sym} -20 0 0 0 {name=p2 lab=g}
C {lab_pin.sym} 20 30 0 0 {name=p3 lab=0}
C {lab_pin.sym} 20 0 0 0 {name=p4 lab=0}}
close $f
## The hierarchy fixture for the landmine-4 rows: s5_top.sch instantiates
## s5_leaf.sym, whose schematic s5_leaf.sch is the same FET one level down.
set f [open [file join $lib s5_leaf.sym] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}
close $f
set f [open [file join $lib s5_top.sch] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {s5_leaf.sym} 120 0 0 0 {name=x1}}
close $f
file copy -force [file join $lib s5_flat.sch] [file join $lib s5_leaf.sch]

## The raw. Six device vectors in the R3 shapes, the two node voltages the
## pinexpr rows need, and one deliberately ZERO vector for row S24.
set f [open [file join $scratch s5_op.raw] w]
puts -nonewline $f "Title: op fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 9
No. Points: 1
Variables:
\t0\ti(@m.xm1.msky130_fd_pr__nfet_01v8\[id\])\tcurrent
\t1\t@m.xm1.msky130_fd_pr__nfet_01v8\[gm\]\tadmittance
\t2\t@m.xm1.msky130_fd_pr__nfet_01v8\[gds\]\tadmittance
\t3\tv(@m.xm1.msky130_fd_pr__nfet_01v8\[vth\])\tvoltage
\t4\tv(@m.xm1.msky130_fd_pr__nfet_01v8\[vdsat\])\tvoltage
\t5\t@m.xm1.msky130_fd_pr__nfet_01v8\[cgg\]\tcapacitance
\t6\t@m.xm1.msky130_fd_pr__nfet_01v8\[zerop\]\tadmittance
\t7\tv(d)\tvoltage
\t8\tv(g)\tvoltage
Values:
0\t1e-05
\t1e-04
\t1e-06
\t0.7
\t0.1
\t1e-15
\t0.0
\t1.8
\t0.9
"
close $f
## The same raw one hierarchy level up: the device is x1.xm1 and the nets are
## x1.d / x1.g. This is what a TOP-LEVEL simulation of s5_top.sch writes.
set f [open [file join $scratch s5_hier.raw] w]
puts -nonewline $f "Title: hier op fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 8
No. Points: 1
Variables:
\t0\ti(@m.x1.xm1.msky130_fd_pr__nfet_01v8\[id\])\tcurrent
\t1\t@m.x1.xm1.msky130_fd_pr__nfet_01v8\[gm\]\tadmittance
\t2\t@m.x1.xm1.msky130_fd_pr__nfet_01v8\[gds\]\tadmittance
\t3\tv(@m.x1.xm1.msky130_fd_pr__nfet_01v8\[vth\])\tvoltage
\t4\tv(@m.x1.xm1.msky130_fd_pr__nfet_01v8\[vdsat\])\tvoltage
\t5\t@m.x1.xm1.msky130_fd_pr__nfet_01v8\[cgg\]\tcapacitance
\t6\tv(x1.d)\tvoltage
\t7\tv(x1.g)\tvoltage
Values:
0\t1e-05
\t1e-04
\t1e-06
\t0.7
\t0.1
\t1e-15
\t1.8
\t0.9
"
close $f

xschem load [file join $lib s5_flat.sch]
check {X5 FIXTURE s5_flat.sch: M1 is a sky130 nfet at top level, 5 instances} \
  [list [xschem get instances] [op_annot::type M1] [xschem get sim_sch_path] \
        [rcall {op_annot::devpath M1}]] \
  [list 5 nmos {} {0 @m.xm1.msky130_fd_pr__nfet_01v8}]

# ===========================================================================
# S — the two ported primitives, WITH NO RAW LOADED
# ===========================================================================
# ⚠ ROWS S1-S7 RUN BEFORE ANY RAW EXISTS IN THIS PROCESS, AND THAT IS
# DELIBERATE. They are UNIT rows on the primitives, deliberately OUTSIDE the
# whole-block gate op_annot::text applies — a gate that returns early would
# otherwise hide a missing catch in raw_or_blank entirely.
check {S1 raw_or_blank with NO raw loaded is BLANK at rc=0, not the raise} \
  [rcall {op_annot::raw_or_blank {@m.xm1.msky130_fd_pr__nfet_01v8[gm]}}] {0 {}}

# ⚠ THE ONE LINE THIS STEP EXISTS TO CHANGE. sg13g2_to_eng_safe returns the
# literal string `NaN`; I3 says a missing vector renders BLANK, and a `NaN`
# painted on a schematic is a fabricated value in the same class as a stale 0.
check {S3 eng_or_blank of {} and of a non-number is BLANK, NOT the string NaN} \
  [rcall {list [op_annot::eng_or_blank {}] [op_annot::eng_or_blank abc] \
               [op_annot::eng_or_blank { - }]}] \
  {0 {{} {} {}}}

# ⚠ CONTROL, GREEN BEFORE AND AFTER. Proof S5 PORTED the prototype rather
# than editing it: ihp-sg13g2/sg13g2_procs.tcl:445 is untouched, so the three
# shipped IHP annotator symbols keep behaving exactly as they do today until
# the step that deletes them lands.
check {S4 CONTROL the IHP prototype still returns NaN — it was ported, not edited} \
  [rcall {list [sg13g2_to_eng_safe {}] [sg13g2_to_eng_safe abc]}] {0 {NaN NaN}}

# ⚠ I3 READ PRECISELY: it forbids fabricating a number for a MISSING vector.
# It does not forbid showing a REAL zero — blanking every zero would hide a
# genuinely cut-off device. Both halves are pinned here so a later edit cannot
# conflate the acceptance's "no line is 0" (about the NO-RAW block) with
# "never print 0".
check {S5 eng_or_blank formats through to_eng, and a MEASURED 0.0 still prints 0} \
  [rcall {list [op_annot::eng_or_blank 4.6777828e-05] \
               [op_annot::eng_or_blank 0.0] \
               [op_annot::eng_or_blank 1e-15]}] \
  {0 {46.78u 0 1f}}

# ⚠ `catch` DOES NOT CATCH THIS. `expr {1.0/0.0}` -> Inf with NO raise,
# `string is double -strict Inf` -> 1, `to_eng Inf` -> `infT`. The string test
# the prototype uses passes Inf straight through; only a finiteness test blanks
# it, and every shipped derived row (ft, gm/id, rin) is a division.
check {S6 eng_or_blank of Inf and NaN is BLANK — a string test is not enough} \
  [rcall {list [op_annot::eng_or_blank [expr {1.0/0.0}]] \
               [op_annot::eng_or_blank [expr {-1.0/0.0}]] \
               [op_annot::eng_or_blank Inf]}] \
  {0 {{} {} {}}}

# ⚠ to_eng RUNS ITS ARGUMENT: `uplevel #0 expr [join $args]` (xschem.tcl:1908),
# so `to_eng {[some_proc]}` really calls some_proc at global scope. The
# `string is double -strict` gate inherited from the prototype is therefore a
# SAFETY gate, not decoration, and this row is what says so.
set ::opa_s5_tripped 0
check {S7 eng_or_blank never lets to_eng evaluate an embedded command} \
  [list [rcall {op_annot::eng_or_blank {[opa_s5_tripwire]}}] $::opa_s5_tripped] \
  {{0 {}} 0}

# ===========================================================================
# S — `{}` MEANS NO BLOCK AT ALL: the four not-annotated conditions
# ===========================================================================
# ⚠ THE TWO OUTCOMES ARE DIFFERENT AND BOTH ARE LOAD-BEARING. A row with an
# empty value says "this parameter exists and could not be read"; `{}` says
# "this device is not annotated at all" and draws nothing. Collapsing them
# either way is a user-visible defect: blanks everywhere on an unrelated
# symbol, or a silently missing parameter list on a real device.
check {S19 text for a nonexistent instance is {} at rc=0, not the translate raise} \
  [rcall {op_annot::text NOPE}] {0 {}}
check {S20 text for an unregistered symbol type (lab_pin) is {} at rc=0} \
  [rcall {op_annot::text p1}] {0 {}}
# ⚠ THE RESTORE IS OUTSIDE THE rcall ON PURPOSE. Inside it, a raise from
# op_annot::text (which is exactly what an absent implementation does) would
# abort the script before the re-source and leave every later row measuring a
# params-less descriptor — S12 would then read `NO-PARAMS` and S2 the `_kind`
# raise, neither of which names the real defect.
set s22_saved [op_annot::descriptor nmos]
catch {op_annot::register nmos [list devproc sky130_op_devpath \
                                     match {*sky130_fd_pr/*}]}
set s22 [rcall {op_annot::text M1}]
catch {op_annot::register nmos $s22_saved}
check {S22 text for a descriptor with no params/pinexpr/derived is {} — no empty frame} \
  [list $s22 [rcall {llength [dict get [op_annot::descriptor nmos] params]}]] \
  {{0 {}} {0 6}}

# ⚠ SKIP ON A BLANK DEVPATH, NEVER ON A BLANK DESCRIPTOR — op_annot.tcl's own
# consumer contract (issue 0425 / S2 finding 6). mix.sch's M2 is a generic
# xschem_library/devices/nmos.sym: `type=nmos` finds sky130's descriptor, and
# only the `match` glob stops it wearing a sky130 device name.
xschem load [file join $lib mix.sch]
check {S21 text for a cell the descriptor's match glob does not claim is {}} \
  [list [op_annot::type M2] [rcall {op_annot::text M2}] \
        [rcall {expr {[op_annot::text M1] ne {}}}]] \
  {nmos {0 {}} {0 1}}
xschem load [file join $lib s5_flat.sch]

# ===========================================================================
# S8/S9 — ACCEPTANCE, HALF 1: NO RAW AT ALL
# ===========================================================================
# The step's own acceptance: "on a run without them, every line is `label =`
# with nothing after it, and no line is 0".
check {S8 ACCEPTANCE with no raw: the exact ten-row all-blank block} \
  [rcall {op_annot::text M1}] [list 0 $S_BLANK]
check {S9 ACCEPTANCE the no-raw block has 10 rows, none with anything after the =} \
  [rcall {opa_s5_allblank [op_annot::text M1]}] {0 {10 {}}}
# ⚠ THE NEGATIVE HALF, AND IT IS NOT REDUNDANT WITH S8: it names every
# fabrication this step is about, so a formatter that regresses to any one of
# them reds a row whose message says which. None of the ten labels contains
# `0`, `NaN`, `Inf`, `infT` or `-`, so every hit is a value.
check {S9b ACCEPTANCE no 0, NaN, Inf, infT or bare - anywhere in the no-raw block} \
  [rcall {opa_s5_fabricated [op_annot::text M1]}] {0 {}}

# ===========================================================================
# S14/S15/S16 — THE WHOLE-BLOCK GATE
# ===========================================================================
# ⚠⚠ S14 IS THE FIRST RAW OPERATION IN THIS PROCESS AND MUST STAY THAT WAY.
# `xschem raw read <f> op` loads the data but never calls update_op()
# (save.c:1988), so cursor_b_val stays my_calloc-zeroed: nothing has been
# published. In a process where an annotate_op has already published,
# cursor_b_val survives a later `xschem load` and this row passes vacuously.
#
# ⚠ THE point -1 GOLDEN MOVED WITH ISSUE 0861, AND THE OLD ONE WAS THE DEFECT.
# It used to be `0` -- with a comment calling that a fabricated 0.0 and pinning
# it anyway. That zero was the same calloc zero the device block correctly
# refuses to print, one accessor over, and it was reaching the user: a
# @spice_get_node text on a schematic (the shipped devices/scope_ammeter.sym
# among them) painted it as a measured value. `xschem raw value <node> -1` asks
# "what does this node say where the annotation is", and with no annotation
# published the honest answer is nothing. Point 0 still reads the true value,
# because inspecting a numbered data point is not annotating it.
#
# The gate is copied from the C's own read gate (token.c), not invented. Since
# 0864 it is `!raw_is_digital(raw) && sch_waves_loaded() >= 0 && annot_p >= 0`:
# the live-cursor switch was a fourth term until 0864 took it out of every
# render path, in both languages. The two terms this row leans on are unchanged.
# `xschem raw annot`'s first field IS annot_p, and -1 means nothing published.
set s14_read [rcall {xschem raw read [file join $scratch s5_op.raw] op}]
set s14_annot [rcall {xschem raw annot}]
set s14_p0 [rcall {xschem raw value {@m.xm1.msky130_fd_pr__nfet_01v8[gm]} 0}]
set s14_pm1 [rcall {xschem raw value {@m.xm1.msky130_fd_pr__nfet_01v8[gm]} -1}]
check {S14 a raw READ but never PUBLISHED says nothing at the annotation point — and the block stays blank} \
  [list $s14_read $s14_annot $s14_p0 $s14_pm1 \
        [rcall {op_annot::text M1}] \
        [rcall {opa_s5_fabricated [op_annot::text M1]}]] \
  [list {0 1} {0 {-1 0 -1}} {0 9.9999997e-05} {0 {}} [list 0 $S_BLANK] {0 {}}]

# ⚠ THE POSITIVE CONTROL FOR THE SAME GATE. Without it S14 could be satisfied
# by a formatter that never reads anything at all. The count is 10 AND 10, not
# just 10 rows: with the 0444 space missing, vgs and vds blank and this reads
# {10 8}, so the row guards that fix too.
set s15_ann [rcall {xschem annotate_op [file join $scratch s5_op.raw]}]
check {S15 after annotate_op annot_p is 0 and ALL TEN rows carry a value} \
  [list [lindex $s15_ann 0] [rcall {xschem raw annot}] \
        [rcall {opa_s5_populated [op_annot::text M1]}]] \
  {0 {0 {0 0 -1}} {0 {10 10}}}

# ===========================================================================
# S10/S12/S13/S2 — ACCEPTANCE, HALF 2: THE GOLDEN BLOCK
# ===========================================================================
check {S10 ACCEPTANCE GOLDEN the annotated sky130 FET block, exact string} \
  [rcall {op_annot::text M1}] [list 0 $S_GOLD]

# ⚠ GREEN BEFORE AND AFTER, AND SAID OUT LOUD: `_wrap` and `vector` both ship
# from S1, so this row passes against an absent op_annot::text and proves
# nothing about S5 on the day it is written. It is a STANDING guard — the one
# thing that keeps S5's chosen composition honest for every later edit — and
# row S13, which reads the values out of the rendered block, is the half that
# actually reds today.
#
# ⚠ I1, AND IT IS THE ROW THAT MAKES THE ONE-devpath COMPOSITION SAFE.
# op_annot::text calls devpath ONCE and _wrap per row rather than vector per
# row (measured: devpath 18.7 us, vector 21.8 us, raw value 0.5 us — per-row
# `vector` on IHP's 13-param NPN is 26 NESTED `xschem translate` calls while
# the outer translate's `static char *result` at token.c:4604 is live). That is
# safe only while the two compositions are byte-equal, and this is what asserts
# it: the instant they drift, I1 has silently failed.
check {S12 I1 every params row: _wrap(devpath) == op_annot::vector, all 6} \
  [rcall {opa_s5_wrap_vs_vector M1 nmos}] {0 {6 {}}}

# ⚠ I1 ONE LEVEL UP: the value in the block is what a DIRECT read through the
# shared builder returns. A formatter that grew a private name would still
# render numbers — they would just be the wrong device's.
check {S13 I1 every params value equals a direct read through vector + eng_or_blank} \
  [rcall {opa_s5_values_vs_direct M1 nmos [op_annot::text M1]}] {0 {6 {}}}

# ⚠ THE THREE OUTCOMES raw_or_blank MUST TELL APART, all measured on this tree:
# present -> the number; absent -> an EMPTY STRING at rc=0 (not a raise, not a
# 0); blank name -> {} without asking the raw anything.
check {S2 raw_or_blank on a loaded raw: present, ABSENT (empty at rc=0), blank name} \
  [rcall {list [op_annot::raw_or_blank [op_annot::vector M1 gm]] \
               [op_annot::raw_or_blank {@m.xm1.msky130_fd_pr__nfet_01v8[nosuchp]}] \
               [op_annot::raw_or_blank {}]}] \
  {0 {9.9999997e-05 {} {}}}

# ⚠ ISSUE 0864 — THE SWITCH IS NOT A RENDER GATE, AND THIS ONE GOLDEN PINS
# BOTH HALVES OF THAT. `Simulation > Graphs > Live annotate probes with 'b'
# cursor` means "follow the cursor and re-annotate as it moves". It used to be
# the FIRST term of op_annot::_annotated as well, and the first term of all six
# cursor_b_val[] gates in token.c, so unticking a box about the cursor blanked
# the device operating-point block that `6` draws while every number sat
# untouched in the database (measured: the block reads blank, `raw value` still
# reads 9.9999997e-05).
#
# ⚠ $S_GOLD IS THE SAME STRING ROW S10 ASSERTS WITH THE SWITCH ON, and that is
# what makes this row see a half-done fix. Its six params rows come through the
# Tcl gate; its vgs/vds rows come through token.c's get_pin_attr gate. Decouple
# only one of the two languages and this row reds with a HALF-blank block —
# exactly the shape the deleted "the save cards are missing" comment described.
set s16_lv $::live_cursor2_backannotate
set ::live_cursor2_backannotate 0
set s16_block [rcall {op_annot::text M1}]
set s16_read [rcall {xschem raw value {@m.xm1.msky130_fd_pr__nfet_01v8[gm]} -1}]
set ::live_cursor2_backannotate $s16_lv
check {S16 the live-cursor switch OFF no longer blanks the block: every row renders, params AND pinexpr} \
  [list $s16_block $s16_read] [list [list 0 $S_GOLD] {0 9.9999997e-05}]

# ===========================================================================
# S29 — ISSUE 0444 LIVE
# ===========================================================================
# ⚠ THE FIRST SPELLING IS READ BACK FROM THE STORE, THE SECOND IS A LITERAL,
# AND BOTH ARE TRANSLATED IN ONE CALL ON THE SAME INSTANCE AND THE SAME RAW.
# That is what makes this a guard rather than a restatement: the registered
# string has to be the one that yields a number, and the no-space twin beside
# it proves the single space is the cause and not a coincidence of this
# fixture. S28 asserts the stored bytes; this asserts what they DO.
check {S29 0444 LIVE the REGISTERED vgs translates to a number; its no-space twin does not} \
  [rcall {set e [lindex [lindex [dict get [op_annot::descriptor nmos] pinexpr] 0] 1]
          list [xschem translate M1 $e] \
               [string is double -strict [xschem translate M1 $e]] \
               [xschem translate M1 $S_VGS_NO] \
               [string is double -strict [xschem translate M1 $S_VGS_NO]]}] \
  {0 {0.9 1 {0.9 - } 0}}

# ===========================================================================
# S11/S23-S27 — THE FORMATTER'S CONTRACTS, on synthetic descriptors
# ===========================================================================
# ⚠ SYNTHETIC ON PURPOSE. No shipped descriptor exercises an 8-char label, a
# genuine zero, a label that differs from its param, or a derived row over a
# pinexpr label — and every one of those is a decision this step makes that
# nothing else in the tree would red.
set S_NMOS_D [op_annot::descriptor nmos]

## ORDER + PADDING: params, then pinexpr, then derived; the column pads to the
## longest label IN THIS BLOCK. `wide_lbl` is 8 characters, so every row is.
catch {op_annot::register nmos [list devproc sky130_op_devpath \
  match {*sky130_fd_pr/*} \
  params  {{wide_lbl cgg 1} {gm nosuchp 1}} \
  pinexpr [list [list pv $S_VGS_OK]] \
  derived {{dv {$wide_lbl*2}}}]}
check {S11 row order is params, pinexpr, derived and the column pads to 8} \
  [rcall {op_annot::text M1}] \
  [list 0 "wide_lbl = 1f\ngm       =\npv       = 0.9\ndv       = 2f\n"]

## ⚠ A DERIVED ROW OVER A MISSING INPUT MUST BLANK, NOT COMPUTE 0. Leaving the
## variable UNSET (rather than binding it to {}) is what makes `expr` raise
## inside the catch — measured: `can't read "gm": no such variable`. Binding {}
## raises too ("can't use empty string as operand") but binding 0 would not,
## and 0 is exactly the fabricated number I3 forbids.
catch {unset ::gm}
catch {op_annot::register nmos [list devproc sky130_op_devpath \
  match {*sky130_fd_pr/*} \
  params  {{gm nosuchp 1}} derived {{q {$gm*2}}}]}
check {S23 a derived expr over a BLANK params value renders blank, not 0} \
  [rcall {op_annot::text M1}] [list 0 "gm =\nq  =\n"]

## ⚠ THE Inf HOLE, IN THE PLACE IT ACTUALLY BITES. `zerop` is a REAL vector
## holding a REAL 0.0, so the params row prints `0` (S5's other half) while the
## derived row that divides by it must blank: `expr {1.0/0.0}` is Inf with NO
## raise, and to_eng renders it `infT`. A plain catch cannot see this.
catch {op_annot::register nmos [list devproc sky130_op_devpath \
  match {*sky130_fd_pr/*} \
  params  {{z zerop 1}} derived {{q {1.0/$z}}}]}
check {S24 a derived dividing by a MEASURED 0.0 blanks; the 0 itself still prints} \
  [rcall {op_annot::text M1}] [list 0 "z = 0\nq =\n"]

## ⚠ LABEL, NOT PARAM. Spec §4.2 says a derived expr sees each `label` from
## `params` as a Tcl variable, while op_annot::_kind (op_annot.tcl:324) matches
## the PARAM field — every shipped descriptor has label == param, so nothing
## else in the tree distinguishes them. `{Ids gm 1}` does: a derived over $Ids
## renders, a derived over $gm blanks.
catch {op_annot::register nmos [list devproc sky130_op_devpath \
  match {*sky130_fd_pr/*} \
  params  {{Ids gm 1}} derived {{x {$Ids}}}]}
set s25_a [rcall {op_annot::text M1}]
catch {op_annot::register nmos [list devproc sky130_op_devpath \
  match {*sky130_fd_pr/*} \
  params  {{Ids gm 1}} derived {{x {$gm}}}]}
set s25_b [rcall {op_annot::text M1}]
check {S25 derived variables are the params LABEL, not the raw param name} \
  [list $s25_a $s25_b] \
  [list [list 0 "Ids = 100u\nx   = 100u\n"] [list 0 "Ids = 100u\nx   =\n"]]

## ⚠ A PROC-LOCAL SCOPE, NEVER `uplevel #0`. That is the to_eng defect shape
## (xschem.tcl:1908) and it lets a descriptor read — and a global clobber
## silently satisfy — a variable the raw never supplied. Measured both ways:
## local blanks, `uplevel #0` prints 999.
set ::gm 999
catch {op_annot::register nmos [list devproc sky130_op_devpath \
  match {*sky130_fd_pr/*} \
  params  {{gm nosuchp 1}} derived {{leak {$gm}}}]}
set s26 [rcall {op_annot::text M1}]
catch {unset ::gm}
check {S26 derived is evaluated in a LOCAL scope: a same-named global cannot leak in} \
  $s26 [list 0 "gm   =\nleak =\n"]

## ⚠ pinexpr IS COMPUTED BEFORE derived, SO A DERIVED ROW MAY USE IT. vgs and
## vds are the two most natural derived inputs on sky130 and gf180; the order
## is deterministic and no shipped descriptor collides. 0.9/1e-05 = 90000.
catch {op_annot::register nmos [list devproc sky130_op_devpath \
  match {*sky130_fd_pr/*} \
  params  {{id id 0}} pinexpr [list [list vgs $S_VGS_OK]] \
  derived {{r {$vgs/$id}}}]}
check {S27 a derived row may reference a pinexpr LABEL — pinexpr runs first} \
  [rcall {op_annot::text M1}] [list 0 "id  = 10u\nvgs = 0.9\nr   = 90k\n"]

catch {op_annot::register nmos $S_NMOS_D}

# ===========================================================================
# S17/S18 — THE MANDATED ROW: A RAW LOADED AT A NON-ZERO LEVEL (landmine 4)
# ===========================================================================
# `xschem get sim_sch_path` (scheduler.c:5150) strips one path component per
# raw load LEVEL, and op_annot::_simpath reads it LIVE on every devpath call.
# So a raw whose vectors are named for the TOP of the hierarchy, loaded while
# the user is one level down, shifts every built name out from under the read.
# The fixture is s5_top.sch -> x1 -> s5_leaf.sch, and s5_hier.raw names the
# device `@m.x1.xm1.…` and the nets `v(x1.d)` / `v(x1.g)` — i.e. exactly what a
# TOP-LEVEL simulation writes.
#
# ⚠⚠ ISSUE 0446, MEASURED HERE AND DELIBERATELY IN THE GOLDEN. Landmine 4 does
# NOT cost total blanking, which is what the step plan predicted from a
# pin-less fixture. Every params and derived row blanks correctly, but the two
# pinexpr rows FABRICATE `0`:
#     @#0/@#1:spice_get_voltage  ->  `- `    (net absent from the raw,
#                                             token.c:4364)
#     @#2:spice_get_voltage      ->  `0.0 `  (source is GND — HARDCODED,
#                                             token.c:4364, raw or no raw)
#     expr(- - 0.0 )             ->  `0`     (translate's trailing eval_expr
#                                             pass, token.c:5441, reads the two
#                                             `-` as unary minus)
# and `0` is a strict double, so no test S5 can apply rejects it. The
# fabrication needs exactly ONE operand to be a hardcoded GND, which is the
# common case for a FET source; with both nets absent the expression stays
# `{ -  }` and blanks correctly (that is row S8).
#
# THIS GOLDEN RECORDS THE DEFECT, IT DOES NOT BLESS IT. The row title names
# 0446, and when 0446 is fixed those two lines become blank and this row reds —
# which is the intended signal, not a regression. S5 does not fix it: the fault
# is in C, outside this step's Files cell, and both Tcl-level guards were
# rejected in the issue (blanking pinexpr when params are blank breaks the
# legitimate no-save-cards case that pinexpr exists FOR; decomposing the
# expression in Tcl is a second evaluator, the I1 drift shape).
#
# ⚠ THE LEVEL-0 CONTROL IN THE SAME GOLDEN IS LOAD-BEARING. Without it
# "everything shifted" would be satisfied by a formatter that reads nothing at
# all — at level 0 the SAME raw and the SAME instance must produce the full
# golden block.
set S_LVLSHIFT "id    =
gm    =
gds   =
vth   =
vdsat =
cgg   =
vgs   = 0
vds   = 0
ft    =
gm/id =
"
xschem load [file join $lib s5_top.sch]
xschem select instance 0
xschem descend 1 2
set s17_ctl_ann [rcall {xschem annotate_op [file join $scratch s5_hier.raw] 0}]
set s17_ctl [list [xschem get sim_sch_path] [rcall {op_annot::devpath M1}] \
                  [rcall {op_annot::text M1}]]
set s17_bad_ann [rcall {xschem annotate_op [file join $scratch s5_hier.raw]}]
set s17_bad [list [xschem raw loaded] [xschem get sim_sch_path] \
                  [rcall {op_annot::devpath M1}] \
                  [rcall {op_annot::raw_or_blank [op_annot::vector M1 gm]}] \
                  [rcall {op_annot::text M1}]]
check {S17 landmine 4: at level 0 the full block; one level down every read blanks} \
  [list [lindex $s17_ctl_ann 0] $s17_ctl [lindex $s17_bad_ann 0] \
        [lrange $s17_bad 0 3]] \
  [list 0 [list {x1.} {0 @m.x1.xm1.msky130_fd_pr__nfet_01v8} [list 0 $S_GOLD]] \
       0 [list 1 {} {0 @m.xm1.msky130_fd_pr__nfet_01v8} {0 {}}]]

# ⚠ THE HALF THE PLAN GOT WRONG, AND THE REASON 0446 EXISTS. Split from S17 so
# the two claims fail separately: S17 says the READS blank, S17b says the
# pinexpr rows do NOT — they print 0.
check {S17b 0446 the level-shifted block fabricates vgs=0 / vds=0, everything else blank} \
  [list [lindex $s17_bad 4] \
        [rcall {list [opa_s5_rowval [op_annot::text M1] vgs] \
                     [opa_s5_rowval [op_annot::text M1] vds] \
                     [opa_s5_rowval [op_annot::text M1] gm] \
                     [opa_s5_rowval [op_annot::text M1] ft]}]] \
  [list [list 0 $S_LVLSHIFT] {0 {0 0 {} {}}}]

# ⚠ THE SECOND HALF OF LANDMINE 4, AND IT IS A DIFFERENT GATE TERM. Ascending
# leaves `xschem raw loaded` at -1 while `xschem raw annot` STILL reports
# annot_p 0 (measured), and get_raw_index() is gated on sch_waves_loaded() >= 0
# (save.c:2259) so even the TRUE vector name reads empty. A gate built on
# annot_p alone would sail through this; `raw loaded >= 0` is the term that
# catches it. Back on the flat cell both nets are absent again, so the pinexpr
# rows blank too and the block is the full all-blank one.
xschem go_back
set s18_up [list [xschem raw loaded] [rcall {xschem raw annot}] \
                 [rcall {xschem raw value {@m.x1.xm1.msky130_fd_pr__nfet_01v8[gm]} -1}]]
xschem load [file join $lib s5_flat.sch]
check {S18 after go_back raw loaded is -1, annot_p is STILL 0, and the block is all blank} \
  [list $s18_up [xschem raw loaded] [rcall {op_annot::text M1}] \
        [rcall {opa_s5_fabricated [op_annot::text M1]}]] \
  [list [list -1 {0 {0 0 -1}} {0 {}}] -1 [list 0 $S_BLANK] {0 {}}]

} serr]} {
  puts "UNEXPECTED ERROR (section S): $serr"
  incr fail
}

# =============================================================================
# SECTION K — S6 of doc/claude/specs/op_annotation.md: THE PDK-NEUTRAL CARRIER
# =============================================================================
# S1 built the name builder, S2 filled the descriptor store, S5 built the
# formatter — and NOTHING CALLED IT. Measured at 9fe40128: `op_annot::text` has
# zero callers tree-wide outside src/op_annot.tcl and this file, so 97 green
# checks stood around a proc no schematic could reach. S6 is the consumer: one
# PDK-neutral symbol whose single tcleval text is `op_annot::text @ref`, plus
# the menu item that places it pre-filled from the selection.
#
#   xschem_library/devices/annotate_params.sym                  (flat tree)
#   xschem_libs_newsym/devices/annotate_params/symbol/<same>.sym      (nested tree)
#   op_annot::place_annotator                                    (src/op_annot.tcl)
#   one `add command` in Simulation > Graphs                     (src/xschem.tcl)
#
# ============================================================================
# ⚠ WHY THE SYMBOL IS WRITTEN TWICE — DECISION D1, AND ROW K1 IS ITS ONLY GUARD
# ============================================================================
# The step's Files cell names only the flat copy. Measured, that copy is
# INVISIBLE in all three PDK workareas: each cadence_style_rc sets
# `XSCHEM_LIBRARY_PATH {}` with `library_registry_defs_only 1`, and each
# library.defs resolves `DEFINE devices` to ../../xschem_libs_newsym/devices.
# Live proof, with this file's own sky130 path set:
#     abs_sym_path devices/lab_pin .sym
#       -> …/xschem_libs_newsym/devices/lab_pin/symbol/lab_pin.sym   (nested)
#     abs_sym_path lab_pin .sym
#       -> …/xschem_library/devices/lab_pin.sym                      (flat)
# So the `devices/`-qualified spelling the menu item uses reaches the NESTED
# tree only. Both copies must exist and must not drift; K1 is what says so.
#
# ============================================================================
# ⚠ THE ONE SPACE THE BRIEF, THE PLAN AND SPEC §4.4 ALL OMIT — ISSUE 0444
# ============================================================================
# The carrier's text must be exactly
#     tcleval([op_annot::text @ref ])
# with a SPACE before the `]`. token.c:24's SPACE(c) = {\n, space, \t, \0, ;}
# does not contain `]`, so without it the token is `@ref]`, misses
# get_tok_value() and appends NOTHING (token.c:5351-5366); the tcleval body is
# left unbalanced, tclpropeval2's catch turns it into `?`, and every row of the
# block becomes a question mark. Measured side by side in one process:
#     tcleval([op_annot::text @ref ])  -> the ten-row block
#     tcleval([op_annot::text @ref])   -> `?`
# All three shipped PDK prototypes already carry that space. K3 asserts the
# literal, and K11 proves the causation MECHANICALLY — it takes the file's own
# text, deletes that one space, and renders both.
#
# ============================================================================
# ⚠ THE ROWS READ THE .sym BYTES, NOT A LOADED SYMBOL
# ============================================================================
# Section K claims things about the FILE that ships. Going through the loader
# would let a normalisation hide exactly the spelling 0444 is about, so K2-K5
# regexp the raw bytes and K8/K10/K11/K16/K17 feed THAT extracted string to
# `xschem translate` — the real render path (translate() ends in
# `spice_get_node(tcl_hook2(result))`, token.c:5437). A row that hand-typed the
# text would stay green against a wrong symbol on disk.
#
# ============================================================================
# ⚠ TWO DEFECTS ARE ACCEPTED HERE, NOT FIXED — DECISIONS D5 AND D6
# ============================================================================
# K16 (issue 0446) and K17 (issue 0447) assert the CURRENT WRONG behaviour, for
# the same reason S17b does: both faults are outside this step's Files cell,
# both are bounded (a fabricated 0; a `?` block), and pinning them means the
# fix reds a named row instead of silently changing what a schematic shows.
#
# ============================================================================
# ⚠ WHAT SECTION K CANNOT SEE
# ============================================================================
# * NO PIXELS. Nothing here draws, and `xschem print svg` under --nogui yields
#   an empty 3 kB canvas (measured) — it is not an oracle. The carrier is the
#   first user-visible deliverable of the whole plan and it owes an eyeball;
#   the debt is recorded with tests/headless/owed.sh add look.
# * THE MENU ITEM ITSELF. The Graphs cascade is built under `if {[info exists
#   has_x]}` and never runs with --nogui, so K15 is a SOURCE GREP. What it
#   guards is one line carrying a label and a call; everything that can go
#   wrong lives in op_annot::place_annotator, which K12-K14 drive for real.
# * WHAT hide=op MEANS IS SECTION L's SUBJECT, NOT K's. When S6 shipped, the
#   token was INERT: measured on scratch symbols differing only in the hide
#   token (instance_bbox width at both show_hidden_texts states) hide=none and
#   hide=op were byte-identical while hide=true collapsed, because
#   set_text_flags (actions.c:1121) tests exact `instance` then
#   strboolcmp(str,"true") and strboolcmp (util.c:72) classifies `op` as s=-1
#   and falls through to strcmp, setting no bit. K4 still pins that the token is
#   IN the shipped file — that is a claim about the .sym bytes and it stays here
#   — but a green K4 has never proved the token DOES anything. S7 (section L)
#   carries that half: L26 is K4's successor and asserts hide=op and hide=true
#   now land on OPPOSITE answers, and L23-L25 drive THIS symbol end to end.

set K_FLATSYM [file join $repo xschem_library devices annotate_params.sym]
set K_NEWSYM  [file join $repo xschem_libs_newsym devices annotate_params \
                         symbol annotate_params.sym]
set K_QMARK   "?\n"

## The bytes of a .sym, or the literal NO-FILE. NEVER raises: an absent symbol
## must red section K row by row, not abort it at the first read and leave the
## remaining claims unmade.
proc opa_k_slurp {p} {
  if {![file isfile $p]} { return NO-FILE }
  set f [open $p r] ; set d [read $f] ; close $f
  return $d
}
## Every T record of a .sym as {body attrs}, or NO-FILE. `-lineanchor` and NOT
## `-line`: the attribute block spans newlines, and `-line` would also set
## -linestop, which stops a bracket expression at a newline and truncates it.
proc opa_k_texts {p} {
  set d [opa_k_slurp $p]
  if {$d eq {NO-FILE}} { return NO-FILE }
  set out {}
  foreach {all body attrs} [regexp -all -inline -lineanchor \
        {^T \{([^{}]*)\}[- 0-9.]+\{([^{}]*)\}} $d] {
    lappend out [list $body $attrs]
  }
  return $out
}
proc opa_k_text_at {p i} {
  set t [opa_k_texts $p]
  if {$t eq {NO-FILE}} { return NO-FILE }
  if {[llength $t] <= $i} { return NO-SUCH-T-RECORD }
  return [lindex $t $i]
}
## The K record's lines, or a marker. This is the `type=` the whole registry
## dispatches on plus the template the menu item relies on for its default.
proc opa_k_krec {p} {
  set d [opa_k_slurp $p]
  if {$d eq {NO-FILE}} { return NO-FILE }
  if {![regexp -lineanchor {^K \{([^{}]*)\}} $d -> k]} { return NO-K-RECORD }
  return [split $k \n]
}
## The body of the first tcleval T record, or a marker.
proc opa_k_tcleval {p} {
  set t [opa_k_texts $p]
  if {$t eq {NO-FILE}} { return NO-FILE }
  foreach r $t {
    if {[string match tcleval* [lindex $r 0]]} { return [lindex $r 0] }
  }
  return NO-TCLEVAL-TEXT
}
## Which of <wanted> the tcleval text's attribute block carries, as 0/1 in the
## order asked, or a marker. Presence rather than an exact golden so a later
## legitimate attribute does not red the row that guards hide=op.
proc opa_k_haveattrs {p wanted} {
  set t [opa_k_texts $p]
  if {$t eq {NO-FILE}} { return NO-FILE }
  set a {}
  foreach r $t {
    if {[string match tcleval* [lindex $r 0]]} { set a [split [lindex $r 1] \n] ; break }
  }
  if {$a eq {}} { return NO-TCLEVAL-TEXT }
  set out {}
  foreach w $wanted { lappend out [expr {[lsearch -exact $a $w] >= 0 ? 1 : 0}] }
  return $out
}
## Render <txt> on instance <inst> through the REAL translate path, or a marker.
## `xschem translate` raises on an unknown instance; a marker keeps the row red
## rather than aborting the section.
proc opa_k_render {inst txt} {
  if {[catch {xschem translate $inst $txt} r]} { return RAISED:$r }
  return $r
}
## -> {ncalls in-the-graph-cascade}. The only headless detector for the menu
## line: `add command` runs under `if {[info exists has_x]}`, which --nogui
## never enters. A call is "in the cascade" if the .menubar.simulation.graph
## widget path appears on its own line or the three above it (the shipped items
## are written as a `\`-continued two-liner).
proc opa_k_menugrep {p} {
  if {![file isfile $p]} { return NO-FILE }
  set f [open $p r] ; set lines [split [read $f] \n] ; close $f
  set n 0 ; set inmenu 0
  for {set i 0} {$i < [llength $lines]} {incr i} {
    if {![string match {*op_annot::place_annotator*} [lindex $lines $i]]} continue
    incr n
    for {set j [expr {$i - 3}]} {$j <= $i} {incr j} {
      if {$j < 0} continue
      if {[string match {*menubar.simulation.graph*} [lindex $lines $j]]} { set inmenu 1 }
    }
  }
  return [list $n $inmenu]
}
## Drive op_annot::place_annotator once and report everything the placement rows
## care about, leaving NO instance behind:
##   {rc delta symbol-resolves ref count-restored modified}
## ⚠ "the instance count went up" IS NOT EVIDENCE, AND NEITHER IS abs_sym_path.
## Two measured traps, and the second one is why this helper asks the LOADER:
##  (a) `xschem place_symbol` returns rc=0 for a MISSING symbol, printing only
##      `l_s_d(): Symbol not found` on stderr, and leaves a live instance whose
##      cell::name points at nothing.
##  (b) `abs_sym_path` AND THE C LOADER DISAGREE ON A LIBRARY-QUALIFIED NAME.
##      Measured: with a scratch directory holding `devices/annotate_params.sym`
##      on XSCHEM_LIBRARY_PATH, `abs_sym_path devices/annotate_params .sym`
##      returns that scratch file while the loader still prints
##      `l_s_d(): Symbol not found: devices/annotate_params` — the C side
##      resolves a `<lib>/<cell>` name through library.defs only, and every PDK
##      workarea's library.defs points `devices` at xschem_libs_newsym. So a
##      file-existence test would pass on a flat-only write and this helper
##      would bless a carrier that cannot load. `cell::type` is the loader's own
##      verdict: `missing` when it failed, the symbol's K-record `type=`
##      otherwise — the identical accessor op_annot::type uses.
proc opa_k_place {} {
  set n0 [xschem get instances]
  set rc [lindex [rcall {op_annot::place_annotator}] 0]
  set n1 [xschem get instances]
  if {$n1 == $n0 + 1} {
    set i [expr {$n1 - 1}]
    set ok NO-TYPE ; set ref {}
    catch {set ok  [xschem getprop instance $i cell::type]}
    catch {set ref [xschem getprop instance $i ref]}
  } else {
    set ok NO-PLACEMENT ; set ref NO-PLACEMENT
  }
  catch {xschem abort_operation}
  return [list $rc [expr {$n1 - $n0}] $ok $ref \
               [expr {[xschem get instances] == $n0 ? 1 : 0}] [xschem get modified]]
}

if {[catch {

# ⚠ UNQUALIFIED, per this file's header note: the qualified spelling never
# reaches set_paths and would leave every symbol unresolved.
set XSCHEM_LIBRARY_PATH $S_LIBS

# ===========================================================================
# FIXTURE — section S's flat cell PLUS the carrier and one wire
# ===========================================================================
# ⚠ ITS OWN CELL, NOT s5_flat.sch. X5 pins `instances = 5` and S14 must stay the
# FIRST raw operation in this process or it passes vacuously (the fabricated-0
# reproduction survives only until an annotate_op has published). The wire is
# here for K14 alone: it is the object the pre-fill was feared to mis-read.
set f [open [file join $lib k_flat.sch] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {sky130_fd_pr/nfet_01v8.sym} 0 0 0 0 {name=M1 W=1 L=0.15 nf=1}
C {lab_pin.sym} 20 -30 0 0 {name=p1 lab=d}
C {lab_pin.sym} -20 0 0 0 {name=p2 lab=g}
C {lab_pin.sym} 20 30 0 0 {name=p3 lab=0}
C {lab_pin.sym} 20 0 0 0 {name=p4 lab=0}
C {devices/annotate_params} 200 0 0 0 {name=annot1 ref=M1}
N 300 -100 340 -100 {lab=w1}}
close $f

## The 0446 raw for row K16: a well-formed operating point that contains NEITHER
## the device vectors NOR v(d)/v(g) — the ordinary "first wrong .raw" case.
set f [open [file join $scratch k_bad.raw] w]
puts -nonewline $f "Title: bad op fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\tv(zzz)\tvoltage
\t1\tv(yyy)\tvoltage
Values:
0\t1.0
\t2.0
"
close $f

xschem load [file join $lib k_flat.sch]
# ⚠ FIXTURE ROW, green before and after — and load-bearing for exactly that
# reason. `xschem load` does NOT fail on a missing symbol (measured: rc=0, the
# instance is created, only `l_s_d(): Symbol not found` on stderr), so without
# this row a broken fixture would degrade every claim below into a hollow pass
# instead of reding one legible line.
check {X6 FIXTURE k_flat.sch: 6 instances, 1 wire, M1 an nmos, annot1 present} \
  [list [xschem get instances] [xschem get wires] [op_annot::type M1] \
        [xschem getprop instance annot1 ref] [xschem get sch_path]] \
  {6 1 nmos M1 .}

# ===========================================================================
# K — THE SYMBOL FILE ITSELF
# ===========================================================================
# ⚠ D1. Both copies, and the same bytes. The equality is guarded by both
# existence tests inside one expr on purpose: two absent files are trivially
# equal, and a row that reported {0 0 1} would be telling a comforting lie.
check {K1 D1 both copies of annotate_params.sym exist and are byte-identical} \
  [list [expr {[file isfile $K_FLATSYM] ? 1 : 0}] \
        [expr {[file isfile $K_NEWSYM] ? 1 : 0}] \
        [expr {[file isfile $K_FLATSYM] && [file isfile $K_NEWSYM] &&
               [opa_k_slurp $K_FLATSYM] eq [opa_k_slurp $K_NEWSYM] ? 1 : 0}]] \
  {1 1 1}

# ⚠ `type=annotator` is what op_annot::type reports and therefore what keeps the
# carrier OUT of the registry (row K7); the template is the menu item's default
# when nothing is selected (row K12).
check {K2 the K record is type=annotator plus template="name=annot1 ref=M1"} \
  [opa_k_krec $K_FLATSYM] \
  [list type=annotator {template="name=annot1 ref=M1"}]

# ⚠ ISSUE 0444, ASSERTED AS A LITERAL INCLUDING THE SPACE BEFORE THE `]`. The
# brief's Files cell, the plan's §S6 and spec §4.4 all write `@ref])`, which
# renders `?` on every row. See this section's header for the mechanism.
check {K3 0444 the tcleval body is EXACTLY `tcleval([op_annot::text @ref ])`} \
  [opa_k_tcleval $K_FLATSYM] {tcleval([op_annot::text @ref ])}

# ⚠ THE ONLY ROW THAT CAN SEE hide=op WHILE IT IS INERT. Measured: the token
# sets no flag bit today (bbox 186/186 at both show_hidden_texts states,
# byte-identical to carrying no hide token at all). It is written now so S7 has
# something to give meaning to; until then this row is the whole guard.
check {K4 the tcleval text carries layer=15, font=Monospace AND hide=op} \
  [opa_k_haveattrs $K_FLATSYM {layer=15 font=Monospace hide=op}] {1 1 1}

# ⚠ THE SECOND TEXT IS THE LABEL, and it is what makes the block identifiable on
# a schematic that carries several carriers. The translate half is green before
# the symbol exists (`@ref` is an instance property, not a symbol one) — the
# file half is the claim.
check {K5 the label text is `T {@ref} … {layer=4}` and renders the ref} \
  [list [opa_k_text_at $K_FLATSYM 1] [opa_k_render annot1 {@ref}]] \
  [list {@ref layer=4} M1]

# ⚠ D2, AND THE ROW THAT CATCHES A FLAT-ONLY WRITE. `devices/annotate_params` is
# the spelling place_annotator uses — the same library-qualified form the IHP
# menu already uses for devices/code_shown. Measured, the C loader resolves that
# `<lib>/<cell>` form through library.defs ALONE, and every workarea's
# library.defs points `devices` at ../../xschem_libs_newsym/devices. So this row
# is red until the NESTED copy exists, whatever the flat tree holds.
#
# ⚠ IT ASKS THE LOADER, NOT abs_sym_path, AND THE DIFFERENCE IS NOT COSMETIC.
# Measured with a scratch `devices/annotate_params.sym` on the path:
#     abs_sym_path devices/annotate_params .sym -> the scratch file
#     the C loader                              -> Symbol not found
# A file-existence row would have gone green on a symbol that cannot load. The
# second element keeps the resolver in view without letting it decide the row.
# REJECTED as the resolver: `[find_file_first annotate_params.sym]`, the shipped
# Graphs-menu precedent — under a registry-only PDK config it returns a stray
# tests/test_sweep_diff/… path (issue 0449).
check {K6 D2 the `devices/annotate_params` spelling LOADS: cell::type is annotator} \
  [list [rcall {xschem getprop symbol devices/annotate_params type}] \
        [file tail [abs_sym_path devices/annotate_params .sym]]] \
  {{0 annotator} annotate_params.sym}

# ⚠ NO SELF-ANNOTATION, NO RECURSION. The carrier's own type is `annotator`,
# which no descriptor claims, so op_annot::text returns {} at rc 0 rather than
# raising or rendering an empty frame around itself.
check {K7 the carrier does not annotate itself: type annotator, text {} at rc 0} \
  [list [op_annot::type annot1] [rcall {op_annot::text annot1}]] \
  {annotator {0 {}}}

# ===========================================================================
# K — END TO END: THE FILE'S OWN TEXT THROUGH THE REAL RENDER PATH
# ===========================================================================
# ⚠ NO RAW IS LOADED HERE. Section S left `xschem raw loaded` at -1 (row S18),
# so this is I3's headline case: the carrier a user places before simulating.
set k_txt [opa_k_tcleval $K_FLATSYM]
check {K8 I3 END-TO-END no raw: the FILE's own text renders ten BLANK rows} \
  [list [opa_k_render annot1 $k_txt] [rcall {op_annot::text M1}]] \
  [list $S_BLANK [list 0 $S_BLANK]]

# ⚠ I4. The overlay is a READ. Rendering it must not modify the schematic and
# must not move the hierarchy — the render is folded into the golden so a row
# that rendered nothing at all cannot satisfy the "nothing moved" half.
set k9_before [list [xschem get modified] [xschem get sch_path]]
check {K9 I4 rendering the carrier modifies nothing and moves no sch_path} \
  [list [opa_k_render annot1 $k_txt] [xschem get modified] [xschem get sch_path] \
        [expr {$k9_before eq [list [xschem get modified] [xschem get sch_path]] ? 1 : 0}]] \
  [list $S_BLANK 0 . 1]

# ⚠ THE STEP'S ACCEPTANCE ROW. Same raw section S uses, so the numbers are
# S5's audited golden; what is new is that they arrive through the SHIPPED
# SYMBOL's text rather than a call this file typed.
set k10_ann [rcall {xschem annotate_op [file join $scratch s5_op.raw]}]
check {K10 ACCEPTANCE END-TO-END annotated: the FILE's own text renders the numbers} \
  [list [lindex $k10_ann 0] [opa_k_render annot1 $k_txt] [rcall {op_annot::text M1}]] \
  [list 0 $S_GOLD [list 0 $S_GOLD]]

# ⚠ 0444 PROVED MECHANICALLY, NOT BY A HAND-TYPED LITERAL. The no-space variant
# is DERIVED from the file's own text by deleting exactly one character, so this
# row cannot drift away from what ships. The two must render differently and the
# stripped one must be `?`.
set k11_ns [string map {{ ])} {])}} $k_txt]
check {K11 0444 CONTROL: deleting the FILE's own space before `]` renders `?`} \
  [list [opa_k_render annot1 $k_txt] [opa_k_render annot1 $k11_ns] \
        [expr {[opa_k_render annot1 $k_txt] eq [opa_k_render annot1 $k11_ns] ? 1 : 0}]] \
  [list $S_GOLD $K_QMARK 0]

# ===========================================================================
# K — THE MENU ITEM'S ONE MOVING PART: op_annot::place_annotator
# ===========================================================================
# ⚠ D4, CORRECTING THE PROTOTYPES. Both shipped pre-fill idioms take
# `[lindex [xschem selected_set] 0]` and then feed it to `xschem getprop
# instance <that> name`, guarding nothing. Measured, the round-trip is
# redundant and the feared hazard is unreachable: selected_set returns instance
# NAMES (select_all -> `{M1} {p1} {p2} {p3} {p4} {annot1}`) and never a wire or
# an index. K14 pins that; a defensive element check would be dead code.
xschem unselect_all
check {K12 place_annotator with nothing selected: the symbol LOADS, ref=M1 from the template} \
  [opa_k_place] {0 1 annotator M1 1 0}

# ⚠ NON-VACUOUS AGAINST K12 BY CONSTRUCTION: the template default is M1, so
# `p1` can only come from a live read of the selection.
xschem unselect_all
xschem select instance 1
## ⚠ `[lindex … 0]` AND NOT THE WHOLE SET: that is the exact expression
## place_annotator reads, and `xschem selected_set` returns a LIST, so asserting
## the set itself would compare `{p1}` against `p1` and stay red after the fix.
check {K13 place_annotator with p1 selected pre-fills ref=p1 from the selection} \
  [list [lindex [xschem selected_set] 0] [opa_k_place]] [list p1 {0 1 annotator p1 1 0}]

# ⚠ THE WIRE CASE. selected_set is EMPTY with only a wire selected, so the
# placement takes the nothing-selected branch and the template supplies ref=M1.
xschem unselect_all
xschem select wire 0
check {K14 D4 a selected WIRE gives an empty selected_set; placement falls back} \
  [list [xschem selected_set] [opa_k_place]] [list {} {0 1 annotator M1 1 0}]
xschem unselect_all

# ⚠ A SOURCE GREP, AND DECLARED AS ONE. The cascade is built under
# `if {[info exists has_x]}`, which --nogui never enters, so no headless row can
# click it. What this guards is one line carrying a label and a call; the risky
# half is op_annot::place_annotator and K12-K14 drive it for real. The remaining
# gap is a pixel gap and is recorded as a look debt, not as a check.
check {K15 exactly ONE op_annot::place_annotator call, in the Graphs cascade} \
  [opa_k_menugrep [file join $repo src xschem.tcl]] {1 1}

# ===========================================================================
# K — THE TWO ACCEPTED DEFECTS (D5, D6): PINNED, NOT PAPERED OVER
# ===========================================================================
# ⚠ ISSUE 0446, NOW MEASURED THROUGH THE CARRIER. A flat sky130 FET with its
# source on GND, plus a raw containing neither v(d) nor v(g): eight rows blank
# correctly and TWO FABRICATE A ZERO. `@#2:spice_get_voltage` is hardcoded to
# `0.0 ` for a GND pin (token.c:4364) whether or not a raw is loaded, the absent
# gate token appends nothing, and translate's trailing eval_expr pass
# (token.c:5441) reads `expr(- - 0.0 )` as 0 — a strict double, so no test S5
# can apply rejects it.
#
# THIS GOLDEN RECORDS THE DEFECT, IT DOES NOT BLESS IT. The fix is in C, outside
# this step's Files cell, and belongs to 0446/S12; when it lands these two rows
# blank and K16 reds, which is the intended signal. It is the same fault S17b
# pins one hierarchy level down, and it is reached here by the ordinary route a
# user takes: place the carrier, annotate the first raw to hand.
set k16_ann [rcall {xschem annotate_op [file join $scratch k_bad.raw]}]
check {K16 0446 ACCEPTED: a raw with no v(d)/v(g) makes the carrier print vgs=0 / vds=0} \
  [list [lindex $k16_ann 0] [opa_k_render annot1 $k_txt] \
        [rcall {list [opa_s5_rowval [op_annot::text M1] vgs] \
                     [opa_s5_rowval [op_annot::text M1] vds] \
                     [opa_s5_rowval [op_annot::text M1] gm] \
                     [opa_s5_rowval [op_annot::text M1] ft]}]] \
  [list 0 $S_LVLSHIFT {0 {0 0 {} {}}}]

# ⚠ ISSUE 0447, AND IT MUST RUN LAST IN SECTION K — it leaves the nmos
# descriptor malformed on purpose. op_annot::register validates only `dict
# size`, so a user's own rc (invariant I5) can store a params/pinexpr/derived
# value that is not a well-formed Tcl list; the three uncaught `foreach row
# [dict get …]` in op_annot::text then raise. Through the carrier that is
# CAUGHT by tclpropeval2 and rendered `?` — degraded, never fatal, and the same
# failure mode the three shipped PDK carriers already have. Accepted (D6):
# tightening register changes a shipped proc's rc contract so a malformed rc
# would raise at STARTUP instead of degrading at draw.
set k17_good [op_annot::descriptor nmos]
set k17_bad $k17_good
## The malformed value is an unmatched OPEN BRACE, and it is BUILT rather than
## typed: a literal one inside this braced `catch` script would unbalance the
## whole section at parse time (Tcl counts braces before it recognises
## anything else, comments included). \x7b carries no brace for the scanner
## to see and becomes one only after substitution.
set k17_ob "\x7b"
dict set k17_bad params "{id id 0} {gm gm 1} ${k17_ob}broken"
set k17_reg [rcall {op_annot::register nmos $k17_bad}]
check {K17 0447 ACCEPTED: a malformed descriptor degrades the carrier to `?`, no crash} \
  [list [lindex $k17_reg 0] [rcall {op_annot::text M1}] \
        [opa_k_render annot1 $k_txt]] \
  [list 0 {1 {unmatched open brace in list}} $K_QMARK]
## Put the good descriptor back, so a later section added to this file does not
## inherit K17's wreckage.
catch {op_annot::register nmos $k17_good}

} kerr]} {
  puts "UNEXPECTED ERROR (section K): $kerr"
  incr fail
}

## ⚠ RESTORE THE D9b DEFAULT. Everything after this point — L, N, O, Q, T — must
## see what a user sees. A stray `0` here would make every later row measure an
## uncapped formatter and the cap would be untested from row L1 onward.
set ::op_annot_max_rows 6
check {R1 D9b the cap is back to its shipped default after the two lifted sections} \
  [list $::op_annot_max_rows [op_annot::max_rows]] {6 6}


# =============================================================================
# SECTION R — RULING D9b: THE SIX-ROW CAP, spec §4.2b
# =============================================================================
# "For ANY PDK, ANY device, only display max of six parameters UNLESS there is a
# setting to do otherwise. We can't have BJT (NPN,PNP) causing clutter."
#
# ⚠ WHY THE CAP IS IN THE FORMATTER AND NOT IN THE DESCRIPTORS, stated as the
# thing this section can actually prove: a descriptor is data a PDK or a user
# writes, and there will always be one more PDK than there are descriptor files
# anybody has edited. So the rows below register a TEN-row descriptor of their
# own — the shape of a PDK nobody here has met — and assert it renders six.
#
# All rows run with NO raw loaded. Every value is blank, which is exactly right:
# the claims here are about HOW MANY rows exist, in WHAT order, and how wide the
# label column is. Values are section S's subject.
if {[catch {

set XSCHEM_LIBRARY_PATH $S_LIBS
xschem load [file join $lib s5_flat.sch]

## Ten rows across all three classes, with a deliberately LONG label in the part
## that will be dropped (`gm/id_long`, 10 chars) so row R5 can prove the width
## pass runs on the survivors.
set R_TEN [list \
  devproc sky130_op_devpath \
  match   {*sky130_fd_pr/*} \
  params  {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}
           {vdsat vdsat 2} {cgg cgg 1}} \
  derived {{ft {$gm/(2*3.141592654*$cgg)}} {gm/id_long {$gm/$id}}}]
proc opa_r_labels {b} {
  set o {}
  foreach l [opa_s5_lines $b] { lappend o [string trim [lindex [split $l =] 0]] }
  return $o
}

op_annot::register nmos $R_TEN
check {R2 a ten-row descriptor renders SIX rows — the first six in declared order} \
  [rcall {opa_r_labels [op_annot::text M1]}] \
  {0 {id gm gds vgs vth vds}}

# ⚠ THE SEAM, AND THE REASON IT EXISTS. Without op_annot::dropped, "the cap
# works" and "the formatter returned fewer rows for some other reason" are the
# same observation, and a silent truncation is the class of thing invariant I8
# exists to make audible. Issue 0604's reporter reads exactly this.
check {R3 op_annot::dropped reports the four rows the cap discarded} \
  [rcall {list [op_annot::text M1] [op_annot::dropped]}] \
  [list 0 [list "id  =\ngm  =\ngds =\nvgs =\nvth =\nvds =\n" 4]]

# ⚠ THE SETTING THE RULING NAMES. Live on the next call, no restart, no rebuild
# — invariant I5's property, kept.
set ::op_annot_max_rows 0
check {R4 the setting: 0 means NO LIMIT and all ten rows come back} \
  [rcall {list [llength [opa_r_labels [op_annot::text M1]]] \
               [op_annot::dropped] \
               [lindex [opa_r_labels [op_annot::text M1]] end]}] \
  {0 {10 0 gm/id_long}}

# ⚠ THE WIDTH PASS RUNS ON THE SURVIVORS, NOT ON THE DECLARED LIST. Uncapped,
# the longest label is `gm/id_long` (10) and every row pads to 10. Capped, the
# longest SHOWN label is 3 and the rows pad to 3. A cap applied after the width
# pass would leave six rows in a ten-wide column — legal, and ugly on a
# schematic, and invisible to any row that only counts lines.
set r5_wide [rcall {lindex [opa_s5_lines [op_annot::text M1]] 0}]
set ::op_annot_max_rows 6
set r5_narrow [rcall {lindex [opa_s5_lines [op_annot::text M1]] 0}]
check {R5 the label column pads to the longest SHOWN label, not the dropped one} \
  [list $r5_wide $r5_narrow] {{0 {id         =}} {0 {id  =}}}

# ⚠ A TYPO MUST NOT SILENTLY HIDE ROWS. Anything that is not a non-negative
# integer means NO LIMIT, deliberately — falling back to the default 6 would
# make `set ::op_annot_max_rows twelve` quietly do the opposite of what the user
# asked for, and they would have no way to tell.
set ::op_annot_max_rows twelve
set r6_a [op_annot::max_rows]
set ::op_annot_max_rows -3
set r6_b [op_annot::max_rows]
set ::op_annot_max_rows 2
set r6_c [rcall {opa_r_labels [op_annot::text M1]}]
set ::op_annot_max_rows 6
check {R6 a non-integer or negative setting means NO LIMIT; a small one is honoured} \
  [list $r6_a $r6_b $r6_c] {0 0 {0 {id gm}}}

# ⚠ THE DEVICE CLASS THAT PROMPTED THE RULING. IHP's vertical_npn shipped
# SIXTEEN rows. The cap alone would have kept the first six in declared order —
# `gm go gmu gpi gx vbe`, five internal conductances and no current at all — so
# the descriptor was reordered and trimmed too. This row asserts BOTH halves:
# six rows, and dropped == 0, i.e. the descriptor fits the budget on its own and
# is not being silently rescued by the cap.
set XSCHEM_LIBRARY_PATH $P_IHP_LIBS
opa_clear_store
opa_source [file join $repo ihp-sg13g2 sg13g2_procs.tcl]
xschem load [file join $repo ihp-sg13g2 xschem_libs sg13g2_tests dc_hbt_13g2_5t \
                       schematic dc_hbt_13g2_5t.sch]
check {R7 D9b the HBT is six rows BY DESCRIPTOR — reordered, not merely truncated} \
  [rcall {list [opa_r_labels [op_annot::text Q1]] [op_annot::dropped]}] \
  {0 {{ic ib gm go vbe vbc} 0}}

# ⚠ AND THE SAME CLAIM FOR EVERY SHIPPED DESCRIPTOR, counted rather than spot
# checked: no registration in any of the three PDK files may exceed six rows.
# This is the row a fourth PDK, or a fifth device class, has to pass.
set r8 {}
foreach _pdk [list [list sky130A sky130_procs.tcl $P_SKY_LIBS] \
                   [list gf180mcuD gf180_procs.tcl $P_GF_LIBS] \
                   [list ihp-sg13g2 sg13g2_procs.tcl $P_IHP_LIBS]] {
  set XSCHEM_LIBRARY_PATH [lindex $_pdk 2]
  opa_clear_store
  opa_source [file join $repo [lindex $_pdk 0] [lindex $_pdk 1]]
  foreach _t {nmos pmos vertical_npn} {
    set _d [op_annot::descriptor $_t]
    if {$_d eq {}} { continue }
    set _n 0
    foreach _k {params pinexpr derived} {
      if {[dict exists $_d $_k]} { incr _n [llength [dict get $_d $_k]] }
    }
    if {$_n > 6} { lappend r8 [list [lindex $_pdk 0] $_t $_n] }
  }
}
check {R8 D9b NO shipped descriptor on ANY PDK declares more than six rows} \
  [list $r8 [llength $r8]] {{} 0}

} rerr]} {
  puts "UNEXPECTED ERROR (section R): $rerr"
  incr fail
}


# =============================================================================
# SECTION L — S7 of doc/claude/specs/op_annotation.md: ANNOTATION CLASSES
# =============================================================================
# S6 shipped a carrier symbol whose one tcleval text carries `hide=op`, and that
# token does NOTHING: set_text_flags (actions.c:1121) tests an exact `instance`
# and then strboolcmp(str,"true"); strboolcmp (util.c:72) classifies `op` as
# s=-1 and degenerates to strcmp, so no flag bit is set and the block ships
# ALWAYS-ON with no off switch. S7 gives the token teeth:
#
#   hide=op       -> HIDE_TEXT_OP       shown iff annot_show bit0 (device OP info)
#   hide=voltage  -> HIDE_TEXT_VOLTAGE  shown iff annot_show bit1 (node voltages)
#   annot_show    -> a new per-context int, MIRRORED IN TCL (xschem.h convention)
#
# and does it by collapsing the copy-pasted visibility tests into ONE predicate.
#
# ============================================================================
# ⚠ IT IS TEN SITES, NOT NINE — AND THEY ARE TWO DIFFERENT TESTS
# ============================================================================
# The brief, the plan and spec §2.4 all say "nine" and then enumerate ten.
# `grep -n HIDE_TEXT src/*.c` minus set_text_flags returns exactly ten, and they
# do not all say the same thing:
#
#   SIX iterate a SYMBOL's text (symptr->text[j]) and mask
#     (HIDE_TEXT | HIDE_TEXT_INSTANTIATED):
#     draw.c:868, draw.c:1131, draw.c:10266, svgdraw.c:923, psprint.c:1205,
#     select.c:709
#   FOUR iterate the SCHEMATIC's own text (xctx->text[i]) and mask HIDE_TEXT
#     alone -- actions.c:4422 even carries `/* | HIDE_TEXT_INSTANTIATED */`
#     commented out IN PLACE, so the split is deliberate:
#     draw.c:10556, svgdraw.c:1290, psprint.c:1664, actions.c:4422
#
# That split IS the meaning of `hide=instance`: hidden when the symbol is
# instantiated, visible while you are editing the symbol itself. Measured end to
# end through the real export path at show_hidden_texts 0, symbol texts visible
# are {none op voltage} while top-level texts visible are {none op voltage
# INSTANCE}. A single-mask `text_hidden(flags)` -- the literal reading of the
# brief's "collapse into ONE helper" -- silently flips `hide=instance` for 630
# occurrences across 244 tracked files and breaches I7 on the first line
# written. Rows L13/L14 are that asymmetry's only guard in the whole tree; they
# are GREEN before S7 and must STAY green.
#
# ============================================================================
# ⚠ WHICH ROWS ARE RED BEFORE S7 AND WHICH ARE CONTROLS — SAY IT OUT LOUD
# ============================================================================
# RED before (18): L1 L2 L3 L4 L5 L7 L8 L9 L15 L16 L17 L18 L23 L24 L25 L26
#                  L27 L28   (+ M1 under a display)
# GREEN before and after, i.e. I7 guards and controls, NOT evidence that S7
# happened: L6 L10 L11 L12 L13 L14 L19 L20 L21 L22 L29 (+ M2), and X7-X9.
# A run in which only the green set passes has measured nothing.
#
# ============================================================================
# ⚠ THE MIRROR IS A PULL CACHE AND THE EXPORTS DO NOT REFRESH IT
# ============================================================================
# `show_hidden_texts` is refreshed at exactly three places (actions.c:4324,
# draw.c:10414, xinit.c:3666); symbol_bbox(), svg_draw() and create_ps() all
# READ the cache and none refresh it. Measured on this tree: the FIRST svg or ps
# export after any Tcl-side change renders with the OLD value, in both
# directions and for both formats (three svg in a row give 0 1 1; reversed,
# 1 0), and `update_all_sym_bboxes; redraw` is one toggle behind (0/0/0/161).
# annot_show must NOT inherit that -- rows L17 and L18 are the ones that say so.
# The in-tree pattern to copy is pin_names_sync_cache (actions.c:1167, called at
# draw.c:10394, scheduler.c:9786, xinit.c:3797 under the tag "P6").
# show_hidden_texts' own staleness is issue 0453 and is deliberately NOT fixed
# by S7 -- that would be a behaviour change, which this commit must not carry.
#
# ============================================================================
# ⚠ `xschem print` UNDER --nogui: THE VIEWPORT FORM IS AN ORACLE
# ============================================================================
# Section K's header says `xschem print svg` under --nogui yields an empty 3 kB
# canvas. That is true only of the NO-VIEWPORT form. The 10-argument form
# `xschem print svg|ps <f> <w> <h> <x1> <y1> <x2> <y2>` (scheduler.c:9829)
# renders properly headless -- the same form test_nh_export_custom_color.tcl:29
# already uses -- so four of the ten sites (svgdraw.c:923/1290,
# psprint.c:1205/1664), the ones the brief calls "the ones nobody looks at",
# need no display. The ONE site that does is actions.c:4422, whose whole text
# loop sits inside `if(has_x && selected != 2)` at actions.c:4416: that is
# section M, and it self-skips under --nogui.
#
# ============================================================================
# ⚠ PS EXPORT CARRIES ONE VOLATILE LINE — ISSUE 0454, MEASURED HERE
# ============================================================================
# The last colour command before `showpage` is an UNINITIALISED RGB triple:
# `4.06641 0 77.25 RGB` on one export and `0.316406 0 7.50066e+06 RGB` on the
# next in the SAME process, values far outside PostScript's 0..1 range, and it
# moves whenever an svg export runs in between. So two PS exports of identical
# content are NOT byte-equal, and rows L20/L22 compare a normalised copy with
# every `<r> <g> <b> RGB` line dropped. Nothing those rows claim lives in a
# colour: a hidden text loses its `(MARKER) show` line too, and L21 keeps the
# comparison non-vacuous. SVG needs no such treatment -- it IS byte-stable.
#
# ============================================================================
# ⚠ THE CARRIER'S GOLDEN IS A TWIN, NOT A NUMBER
# ============================================================================
# L23 needs "the carrier's bbox with its numbers hidden". Hard-coding a width
# would pin a FONT METRIC: the same symbol with the same text measured 68 wide
# in one process and 66 in another. The oracle is instead a TWIN of the shipped
# file, byte-identical but for `hide=op` -> `hide=true`, whose bbox at
# show_hidden_texts 0 IS "numbers hidden" and at 1 IS "numbers shown". The row
# also asserts the two differ, so a twin that rendered nothing cannot satisfy it.

set L_LIBDIR   $lib
set L_CORPUSDIR [file join $repo xschem_library devices]
set L_GF_SCH   [file join $repo gf180mcuD xschem_libs gf180mcu_tests \
                          test_nfet_06v0 schematic test_nfet_06v0.sch]
## Viewports for the 10-argument `xschem print` form: {w h x1 y1 x2 y2}.
set L_VP_MAIN   {1600 1000 -200 -200 2400 1600}
set L_VP_CORPUS {1400  900 -100 -100 3000 2000}
set L_VP_E2E    { 900  500  -60  -60  400  200}
set L_VP_GF     {1800 1400 -100 -750 1300  100}

## Instance bbox as {width height}, ints, or a marker. NEVER raises: a fixture
## that lost an instance must red one row, not abort the section.
proc opa_l_wh {inst} {
  if {[catch {xschem instance_bbox $inst} r]} { return RAISED }
  if {![regexp {Instance: (\S+) (\S+) (\S+) (\S+)} $r -> a b c d]} { return NO-BBOX }
  return [list [expr {int($c - $a)}] [expr {int($d - $b)}]]
}
proc opa_l_w {inst} { set r [opa_l_wh $inst] ; if {[llength $r] != 2} { return $r } ; return [lindex $r 0] }

## Set BOTH halves of the show_hidden_texts mirror and recompute the bboxes.
## `xschem set` writes the C cache, the Tcl var keeps a later pull agreeing with
## it; setting only one is the B2 trap the scout measured.
proc opa_l_sht {v} {
  catch {xschem set show_hidden_texts $v} ; set ::show_hidden_texts $v
  xschem update_all_sym_bboxes
}
## Set annot_show THROUGH THE SURFACE UNDER TEST and recompute the bboxes.
## Deliberately does NOT touch ::annot_show: a setter that only wrote the Tcl
## var would then be indistinguishable from one that wrote the C field, and L4
## exists to tell them apart. Before S7 this whole proc is a silent no-op --
## `xschem set` splits on argv[2][0] < 'n' (scheduler.c:11685) and only the
## >='n' half carries the `*cmd_found = 0` fall-through, so an unknown name
## beginning with 'a' returns rc=0 and an empty result. That is why L29 is here.
proc opa_l_annot {v} { catch {xschem set annot_show $v} ; xschem update_all_sym_bboxes }

## One export through the 10-argument form; the file's bytes, or a marker.
proc opa_l_print {fmt out vp} {
  catch {file delete $out}
  if {[catch {eval [linsert $vp 0 xschem print $fmt $out]} r]} { return RAISED:$r }
  if {![file isfile $out]} { return NO-FILE }
  set fd [open $out r] ; set d [read $fd] ; close $fd ; return $d
}
## A WARMED export: one throwaway of the same format first. Every row EXCEPT
## L17 uses this, because L17 is the row whose whole subject is the first
## export. The warm-up also settles issue 0454's volatile PS colour into the
## same slot for both sides of a comparison.
proc opa_l_print2 {fmt out vp} { opa_l_print $fmt $out.warm $vp ; return [opa_l_print $fmt $out $vp] }

## Drop PostScript colour-set lines — issue 0454; see this section's header.
proc opa_l_normps {s} {
  set o {}
  foreach x [split $s \n] {
    if {[regexp {^[-0-9.e+]+ [-0-9.e+]+ [-0-9.e+]+ RGB$} $x]} continue
    lappend o $x
  }
  return [join $o \n]
}
## 0/1 per marker, in the order asked. Presence, not position: the claim is
## "this string was drawn", and both back ends spell it plainly (`>MARK<` in
## SVG, `(MARK)` before `show` in PS).
proc opa_l_seen {s markers} {
  set o {}
  foreach m $markers { lappend o [expr {[regexp -- $m $s] ? 1 : 0}] }
  return $o
}
## Basenames of src/*.c containing <pat>, sorted. A FILE-set answer, not a line
## count: "the ten copy-pasted tests are gone" is exactly "no .c outside
## actions.c still spells HIDE_TEXT", and a count moves when someone reflows.
proc opa_l_cfiles {dir pat} {
  set out {}
  foreach f [lsort [glob -nocomplain [file join $dir *.c]]] {
    set fd [open $f r] ; set d [read $fd] ; close $fd
    if {[string first $pat $d] >= 0} { lappend out [file tail $f] }
  }
  return $out
}
## -> {n_set_ne n_in_global_list} for src/xschem.tcl. The second half is the
## per-tab hole NO headless row can otherwise see: save_ctx/restore_ctx
## (xschem.tcl:14041/14071) walk tctx::global_list, and a mask left out of it
## silently reverts when the user opens a second tab.
proc opa_l_tclmirror {p} {
  if {![file isfile $p]} { return NO-FILE }
  set fd [open $p r] ; set lines [split [read $fd] \n] ; close $fd
  set ndef 0 ; set nlist 0 ; set in 0
  foreach l $lines {
    if {[regexp {^\s*set_ne\s+annot_show\s} $l]} { incr ndef }
    if {[regexp {^\s*set\s+tctx::global_list\s+\{} $l]} { set in 1 ; continue }
    if {$in && [string trim $l] eq "\}"} { set in 0 ; continue }
    if {$in} { incr nlist [llength [lsearch -all -exact [split [string trim $l]] annot_show]] }
  }
  return [list $ndef $nlist]
}
## Write one `type=zzs7probe` symbol: a 10-unit stroke plus ONE layer-15 text.
## The five bbox probes all carry the SAME string so a visible width is
## comparable across them; the four export probes carry distinct markers.
proc opa_l_mkprobe {dir name hide text} {
  set f [open [file join $dir $name] w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "K \{type=zzs7probe\ntemplate=\"name=zp1\"\}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  puts $f "L 4 0 0 0 10 {}"
  if {$hide eq {}} {
    puts $f "T \{$text\} 5 5 0 0 0.2 0.2 \{layer=15\}"
  } else {
    puts $f "T \{$text\} 5 5 0 0 0.2 0.2 \{layer=15\nhide=$hide\}"
  }
  close $f
}

if {[catch {

# ⚠ UNQUALIFIED, per this file's header note.
set XSCHEM_LIBRARY_PATH $S_LIBS

# ===========================================================================
# L — THE SURFACE. Run FIRST, before anything sets the mask.
# ===========================================================================
# ⚠ ABSENCE HERE IS SILENT, NOT AN ERROR. `xschem set annot_show 1` returns
# rc=0 with an empty result today (the argv[2][0] < 'n' half of the dispatcher
# has no fall-through), and `xschem get <unknown>` likewise answers empty. So
# these rows assert the VALUE, never a raise; L29 is the control that keeps
# "the branch exists" from being a hollow claim.
check {L1 D2 a fresh session reports annot_show 0 — the default resting state} \
  [rcall {xschem get annot_show}] {0 0}

check {L2 the Tcl mirror exists and defaults to 0 (set_ne annot_show 0)} \
  [list [info exists ::annot_show] \
        [expr {[info exists ::annot_show] ? $::annot_show : {NO-VAR}}]] \
  {1 0}

catch {xschem set annot_show 3}
check {L3 `xschem set annot_show 3` reaches the C field: get answers 3} \
  [rcall {xschem get annot_show}] {0 3}

# ⚠ D4. show_hidden_texts' own setter (scheduler.c:12063) writes ONLY the C
# field, and the next pull at draw.c:10414 silently discards it — which is why
# the GUI never calls it. annot_show's setter must push both ways or every row
# below becomes order-dependent.
check {L4 D4 the setter pushes to Tcl too — no later pull can undo it} \
  [list [info exists ::annot_show] \
        [expr {[info exists ::annot_show] ? $::annot_show : {NO-VAR}}]] \
  {1 3}

# ===========================================================================
# FIXTURE — nine probe symbols and four top-level texts in one schematic
# ===========================================================================
foreach {n h} {l_hid_none {} l_hid_op op l_hid_voltage voltage
               l_hid_true true l_hid_instance instance} {
  opa_l_mkprobe $L_LIBDIR $n.sym $h ZZS7_TEXT
}
foreach {n h m} {l_exp_none {} ZZSYMDNONE  l_exp_op op ZZSYMAOP
                 l_exp_inst instance ZZSYMBINST  l_exp_true true ZZSYMCTRUE} {
  opa_l_mkprobe $L_LIBDIR $n.sym $h $m
}
set f [open [file join $L_LIBDIR l_main.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
set l_i 0
foreach h {none op voltage true instance} {
  puts $f "C \{l_hid_$h.sym\} [expr {$l_i * 120}] 0 0 0 \{name=i_$h\}" ; incr l_i
}
set l_i 0
foreach {n m} {l_exp_none ZZSYMDNONE l_exp_op ZZSYMAOP
               l_exp_inst ZZSYMBINST l_exp_true ZZSYMCTRUE} {
  puts $f "C \{$n.sym\} [expr {$l_i * 120}] 100 0 0 \{name=e_$l_i\}" ; incr l_i
}
set l_i 0
foreach {m h} {ZZTOPDNONE {} ZZTOPAOP op ZZTOPBINST instance ZZTOPCTRUE true} {
  if {$h eq {}} {
    puts $f "T \{$m\} 0 [expr {200 + $l_i * 30}] 0 0 0.4 0.4 \{layer=4\}"
  } else {
    puts $f "T \{$m\} 0 [expr {200 + $l_i * 30}] 0 0 0.4 0.4 \{layer=4\nhide=$h\}"
  }
  incr l_i
}
close $f
xschem load [file join $L_LIBDIR l_main.sch]
opa_l_annot 0 ; opa_l_sht 0

## ⚠ THE VISIBLE WIDTH IS A FONT METRIC AND MOVES WITH THE DISPLAY — MEASURED.
## The identical symbol measures 63 wide under --nogui and 64 under DISPLAY=:99,
## because text_bbox goes through cairo's font metrics when a display exists.
## So NO row below hard-codes a width: they all compare against $L_W, the
## untokened control measured in THIS process, and X7 is what stops $L_W from
## being 0 and turning every "hidden" row into a hollow pass.
set L_W [opa_l_w i_none]

# ⚠ FIXTURE ROW, green before and after. `xschem load` does NOT fail on a
# missing symbol, so without this every claim below would degrade into a hollow
# pass. The two widths pin that the probes really carry a text and that the
# hide=true control really hides one.
check {X7 FIXTURE l_main.sch: 9 probe instances, 4 top texts, a text that shows and one that hides} \
  [list [xschem get instances] [xschem get texts] \
        [xschem getprop instance i_op cell::type] \
        [expr {$L_W > 40 ? 1 : 0}] [opa_l_w i_true]] \
  {9 4 zzs7probe 1 0}

# ===========================================================================
# L — THE MASK, ON THE SYMBOL-TEXT PATH (select.c:709)
# ===========================================================================
# ⚠ The control width is folded into every row on purpose: a fixture whose text
# vanished would answer {0 0} and satisfy a row that asked only for 0.
opa_l_annot 0
check {L5 hide=op is HIDDEN at annot_show 0 — bit0 clear} \
  [list [opa_l_w i_op] [opa_l_w i_none]] [list 0 $L_W]

opa_l_annot 1
check {L6 hide=op is VISIBLE at annot_show 1, at the untokened control's exact width} \
  [list [opa_l_w i_op] [opa_l_w i_none]] [list $L_W $L_W]

# ⚠ THE MASK IS A MASK, NOT A FLAG. `annot_show 2` is bit1 only; a `!= 0` test
# in text_hidden would show OP info whenever voltages are on.
opa_l_annot 2
check {L7 hide=op is HIDDEN at annot_show 2 — bit0 is the gate, not "any bit set"} \
  [list [opa_l_w i_op] [opa_l_w i_none]] [list 0 $L_W]

opa_l_annot 1 ; set l8a [opa_l_w i_voltage]
opa_l_annot 2 ; set l8b [opa_l_w i_voltage]
check {L8 hide=voltage follows bit1: hidden at annot_show 1, visible at annot_show 2} \
  [list $l8a $l8b [opa_l_w i_none]] [list 0 $L_W $L_W]

# ⚠ D3 — THE DECISION THAT MAKES S8's `Ctrl-6 -> none` WORK. Annotation classes
# are gated SOLELY by annot_show. The rejected alternative (show_hidden_texts as
# a master override for the new classes) reads naturally, but the two shipped
# "Annotate Operating Point" menu items (xschem.tcl:14941 and :15318) BOTH do
# `set show_hidden_texts 1`, and that is the exact flow a user reaches this
# feature through — so the override would make the off switch a silent no-op
# precisely when it is needed.
opa_l_annot 0 ; opa_l_sht 1
check {L9 D3 hide=op stays HIDDEN at annot_show 0 even with show_hidden_texts 1} \
  [list [opa_l_w i_op] [opa_l_w i_true]] [list 0 $L_W]

opa_l_annot 1 ; opa_l_sht 0
check {L10 D3 hide=op is VISIBLE at annot_show 1 even with show_hidden_texts 0} \
  [list [opa_l_w i_op] [opa_l_w i_true]] [list $L_W 0]

# ===========================================================================
# L — I7: hide=true / hide=instance ARE UNTOUCHED
# ===========================================================================
# ⚠ NOTHING ELSE IN tests/ ASSERTS THIS. A grep over the whole suite for
# show_hidden_texts finds only this file's comments, so before these rows I7 was
# guarded by nothing at all while 630 `hide=instance` and 47 `hide=true`
# occurrences across 244 tracked files depended on it.
set l11 {}
foreach a {0 3} { foreach sh {0 1} { opa_l_annot $a ; opa_l_sht $sh
  lappend l11 [opa_l_w i_true] } }
check {L11 I7 hide=true tracks show_hidden_texts ONLY, identically at annot_show 0 and 3} \
  $l11 [list 0 $L_W 0 $L_W]

set l12 {}
foreach a {0 3} { foreach sh {0 1} { opa_l_annot $a ; opa_l_sht $sh
  lappend l12 [opa_l_w i_instance] } }
check {L12 I7 hide=instance tracks show_hidden_texts ONLY, identically at annot_show 0 and 3} \
  $l12 [list 0 $L_W 0 $L_W]

# ===========================================================================
# L — THE FOUR EXPORT SITES (svgdraw.c:923/1290, psprint.c:1205/1664)
# ===========================================================================
# ⚠ THE ASYMMETRY, AND IT IS THE WHOLE REASON text_hidden() TAKES A CONTEXT.
# At show_hidden_texts 0 a `hide=instance` text is HIDDEN on a symbol and
# VISIBLE at top level. Rows L13/L14 are green before AND after S7 — they are
# not evidence the feature landed, they are the tripwire on the one-argument
# helper the brief literally asked for.
opa_l_annot 0 ; opa_l_sht 0
set l_svg0 [opa_l_print2 svg [file join $scratch l_main.svg] $L_VP_MAIN]
set l_ps0  [opa_l_print2 ps  [file join $scratch l_main.ps]  $L_VP_MAIN]

check {L13 I7 ASYMMETRY SVG: top-level hide=instance is VISIBLE where the same token on a symbol is HIDDEN} \
  [list [opa_l_seen $l_svg0 {ZZSYMBINST ZZSYMDNONE}] \
        [opa_l_seen $l_svg0 {ZZTOPBINST ZZTOPDNONE}]] \
  {{0 1} {1 1}}

check {L14 I7 ASYMMETRY PS: the identical claim through psprint.c:1664 vs :1205} \
  [list [opa_l_seen $l_ps0 {ZZSYMBINST ZZSYMDNONE}] \
        [opa_l_seen $l_ps0 {ZZTOPBINST ZZTOPDNONE}]] \
  {{0 1} {1 1}}

opa_l_annot 1
set l_svg1 [opa_l_print2 svg [file join $scratch l_main1.svg] $L_VP_MAIN]
set l_ps1  [opa_l_print2 ps  [file join $scratch l_main1.ps]  $L_VP_MAIN]

check {L15 top-level hide=op follows annot_show bit0 in SVG (svgdraw.c:1290) AND PS (psprint.c:1664)} \
  [list [opa_l_seen $l_svg0 {ZZTOPAOP ZZTOPDNONE}] [opa_l_seen $l_ps0 {ZZTOPAOP ZZTOPDNONE}] \
        [opa_l_seen $l_svg1 {ZZTOPAOP ZZTOPDNONE}] [opa_l_seen $l_ps1 {ZZTOPAOP ZZTOPDNONE}]] \
  {{0 1} {0 1} {1 1} {1 1}}

check {L16 symbol hide=op follows annot_show bit0 in SVG (svgdraw.c:923) AND PS (psprint.c:1205)} \
  [list [opa_l_seen $l_svg0 {ZZSYMAOP ZZSYMDNONE}] [opa_l_seen $l_ps0 {ZZSYMAOP ZZSYMDNONE}] \
        [opa_l_seen $l_svg1 {ZZSYMAOP ZZSYMDNONE}] [opa_l_seen $l_ps1 {ZZSYMAOP ZZSYMDNONE}]] \
  {{0 1} {0 1} {1 1} {1 1}}

# ⚠ THE STALENESS ROW. `set ::annot_show` alone, never `xschem set`, and the
# FIRST export is the measurement — no warm-up. show_hidden_texts fails this
# today in both directions and for both formats (issue 0453); annot_show must
# not, or the brief's own "test the SVG/PS export paths" acceptance becomes
# order-dependent and flaky.
opa_l_annot 0
set ::annot_show 1
set l17a [opa_l_seen [opa_l_print svg [file join $scratch l_first.svg] $L_VP_MAIN] {ZZTOPAOP}]
opa_l_annot 1
set ::annot_show 0
set l17b [opa_l_seen [opa_l_print ps [file join $scratch l_first.ps] $L_VP_MAIN] {ZZTOPAOP}]
check {L17 NO STALE FIRST EXPORT: the mirror is synced at the export entry, not one export late} \
  [list $l17a $l17b] {1 0}

# ⚠ THE BBOX HALF OF THE SAME DEFECT. xschem.tcl:15036's shipped idiom is
# `xschem update_all_sym_bboxes; xschem redraw`, and spec §4.6 step 3 tells S8's
# annot mode to copy it. Measured for show_hidden_texts: 0 / 0 / 0 / 161 across
# those four steps, i.e. only the SECOND update is right. One update must do.
opa_l_annot 0
set l18a [opa_l_w i_op]
set ::annot_show 1
xschem update_all_sym_bboxes
set l18b [opa_l_w i_op]
xschem update_all_sym_bboxes
set l18c [opa_l_w i_op]
check {L18 NO STALE BBOX: ONE update_all_sym_bboxes picks up a Tcl-side annot_show change} \
  [list $l18a $l18b $l18c] [list 0 $L_W $L_W]

# ===========================================================================
# L — I7 ON THE SHIPPED CORPUS
# ===========================================================================
# ⚠ EXHAUSTIVE, NOT A SPOT CHECK, BECAUSE THE BLAST RADIUS IS COUNTABLE. Across
# every tracked .sym/.sch: hide=instance 630 occurrences / 244 files, hide=true
# 47 / 22, hide=op 2 (the twin annotate_params.sym), hide=voltage 0. No other
# hide= value exists anywhere. So "every existing library symbol renders
# identically with annot_show 0 and 3" is a bounded claim, and these rows make
# it for all 57 shipped devices/*.sym that carry hide=instance at once.
set l_corp {}
foreach s [lsort [glob -nocomplain [file join $L_CORPUSDIR *.sym]]] {
  set fd [open $s r] ; set d [read $fd] ; close $fd
  if {[string first "hide=instance" $d] >= 0} { lappend l_corp [file tail $s] }
}
set f [open [file join $L_LIBDIR l_corpus.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
set l_i 0
foreach c $l_corp {
  puts $f "C \{$c\} [expr {($l_i % 8) * 300}] [expr {($l_i / 8) * 200}] 0 0 \{name=zz$l_i\}"
  incr l_i
}
close $f
xschem load [file join $L_LIBDIR l_corpus.sch]
check {X8 FIXTURE l_corpus.sch: every shipped devices/*.sym carrying hide=instance, all loaded} \
  [list [llength $l_corp] [xschem get instances] \
        [expr {[xschem getprop instance zz0 cell::type] eq {missing} ? {MISSING} : {OK}}]] \
  {57 57 OK}

foreach a {0 3} {
  foreach sh {0 1} {
    opa_l_annot $a ; opa_l_sht $sh
    set l_cs($a,$sh) [opa_l_print2 svg [file join $scratch l_c_$a$sh.svg] $L_VP_CORPUS]
    set l_cp($a,$sh) [opa_l_normps [opa_l_print2 ps [file join $scratch l_c_$a$sh.ps] $L_VP_CORPUS]]
  }
}
check {L19 I7 CORPUS SVG: 57 shipped hide=instance symbols export byte-identically at annot_show 0 vs 3} \
  [list [expr {$l_cs(0,0) eq $l_cs(3,0)}] [expr {$l_cs(0,1) eq $l_cs(3,1)}] \
        [expr {[string length $l_cs(0,0)] > 10000}]] {1 1 1}

check {L20 I7 CORPUS PS: the same 57 symbols, colour-normalised, identical at annot_show 0 vs 3} \
  [list [expr {$l_cp(0,0) eq $l_cp(3,0)}] [expr {$l_cp(0,1) eq $l_cp(3,1)}] \
        [expr {[string length $l_cp(0,0)] > 10000}]] {1 1 1}

# ⚠ WITHOUT THIS ROW L19/L20 WOULD PASS ON AN EXPORTER THAT DREW NOTHING.
check {L21 NON-VACUITY: the same corpus DOES differ between show_hidden_texts 0 and 1, in both formats} \
  [list [expr {$l_cs(0,0) ne $l_cs(0,1)}] [expr {$l_cp(0,0) ne $l_cp(0,1)}]] {1 1}

# ⚠ THE hide=true HALF OF I7, ON A SHIPPED SCHEMATIC. gf180's 19 FET symbols are
# the tree's only hide=true TEXT records that render something without a raw
# (`tcleval(gm=[ngspice::get_node …] )` leaves the `gm=` prefix), which is what
# makes this row non-vacuous. REJECTED as the fixture:
# xschem_library/pcb/pcb_current_protection_embed.sch, the file the plan names —
# measured, its three hide=true texts are bare `@spice_get_voltage` /
# `@spice_get_current` tokens that render to the EMPTY STRING with no raw
# loaded, so its export is byte-identical at show_hidden_texts 0 and 1 and the
# row would have been vacuous in exactly the way L21 exists to prevent.
set XSCHEM_LIBRARY_PATH $P_GF_LIBS
xschem load $L_GF_SCH
foreach a {0 3} {
  foreach sh {0 1} {
    opa_l_annot $a ; opa_l_sht $sh
    set l_gs($a,$sh) [opa_l_print2 svg [file join $scratch l_g_$a$sh.svg] $L_VP_GF]
  }
}
check {L22 I7 SHIPPED hide=true: a gf180 FET schematic exports identically at annot_show 0 vs 3, and DOES move with show_hidden_texts} \
  [list [expr {$l_gs(0,0) eq $l_gs(3,0)}] [expr {$l_gs(0,1) eq $l_gs(3,1)}] \
        [expr {$l_gs(0,0) ne $l_gs(0,1)}] \
        [opa_l_seen $l_gs(0,0) {gm=}] [opa_l_seen $l_gs(0,1) {gm=}]] {1 1 1 0 1}
set XSCHEM_LIBRARY_PATH $S_LIBS

# ===========================================================================
# L — END TO END: THE SHIPPED CARRIER devices/annotate_params
# ===========================================================================
# ⚠ THE SHARPEST CHECK IN THE STEP. This is the one symbol in the whole tree
# whose visible behaviour S7 changes: S6 shipped it ALWAYS-ON (measured: bbox
# and both exports identical at BOTH show_hidden_texts states) because the token
# was inert. After S7 it must follow annot_show bit0 and ignore
# show_hidden_texts entirely. Its own type is `annotator`, which no descriptor
# claims, so it cannot annotate itself (row K7).
set f [open [file join $L_LIBDIR l_zzfet.sym] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=zzs7fet\nformat=\"@name @pinlist @model\"\ntemplate=\"name=MZZ1 model=zzdev\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "L 4 -10 -10 10 -10 {}"
puts $f "L 4 10 -10 10 10 {}"
puts $f "L 4 10 10 -10 10 {}"
puts $f "L 4 -10 10 -10 -10 {}"
close $f
## The twin: the SHIPPED file byte-for-byte with hide=op rewritten to hide=true.
## Built from the bytes on disk, never hand-typed, so it cannot drift away from
## what ships. See this section's header for why it is the oracle.
set l_carrier [opa_k_slurp $K_FLATSYM]
set f [open [file join $L_LIBDIR l_twin.sym] w]
puts -nonewline $f [string map {hide=op hide=true} $l_carrier]
close $f
## A three-vector operating point, same technique section S uses.
set f [open [file join $scratch l_op.raw] w]
puts -nonewline $f "Title: S7 carrier fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 3
No. Points: 1
Variables:
\t0\ti(@m.xmzz1.mzz\[id\])\tcurrent
\t1\t@m.xmzz1.mzz\[gm\]\tadmittance
\t2\t@m.xmzz1.mzz\[gds\]\tadmittance
Values:
0\t1e-05
\t1e-04
\t1e-06
"
close $f
## ⚠ ITS OWN SYMBOL TYPE. Registering `nmos` here would clobber the sky130
## descriptor sections P and S left in the store; `zzs7fet` collides with
## nothing, and the devproc convention is the one row C7 pinned.
proc opa_l_devproc {instname model path spiceprefix} { return {@m.xmzz1.mzz} }
catch {op_annot::register zzs7fet \
  [list devproc opa_l_devproc params {{id id 0} {gm gm 1} {gds gds 1}}]}
set f [open [file join $L_LIBDIR l_e2e.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "C \{l_zzfet.sym\} 0 0 0 0 \{name=MZZ1\}"
puts $f "C \{devices/annotate_params\} 80 0 0 0 \{name=annot1 ref=MZZ1\}"
puts $f "C \{l_twin.sym\} 200 0 0 0 \{name=annot2 ref=MZZ1\}"
close $f
xschem load [file join $L_LIBDIR l_e2e.sch]
set l_ann [rcall {xschem annotate_op [file join $scratch l_op.raw]}]
check {X9 FIXTURE l_e2e.sch: the SHIPPED carrier plus its hide=true twin, both pointed at an annotated device} \
  [list [lindex $l_ann 0] [xschem get instances] \
        [xschem getprop instance annot1 cell::type] \
        [xschem getprop instance annot2 cell::type] \
        [rcall {op_annot::text MZZ1}]] \
  [list 0 3 annotator annotator [list 0 "id  = 10u\ngm  = 100u\ngds = 1u\n"]]

## The oracle pair, measured from the twin in this same process.
opa_l_annot 0 ; opa_l_sht 0 ; set l_ref_hidden [opa_l_wh annot2]
opa_l_sht 1                 ; set l_ref_shown  [opa_l_wh annot2]
opa_l_sht 0
opa_l_annot 0 ; set l23a [opa_l_wh annot1]
opa_l_annot 1 ; set l23b [opa_l_wh annot1]
check {L23 the SHIPPED carrier's bbox follows annot_show bit0: numbers-hidden at 0, full at 1} \
  [list [expr {$l23a eq $l_ref_hidden}] [expr {$l23b eq $l_ref_shown}] \
        [expr {$l_ref_hidden ne $l_ref_shown}]] {1 1 1}

opa_l_annot 0
set l_es0 [opa_l_print2 svg [file join $scratch l_e2e0.svg] $L_VP_E2E]
set l_ep0 [opa_l_print2 ps  [file join $scratch l_e2e0.ps]  $L_VP_E2E]
opa_l_annot 1
set l_es1 [opa_l_print2 svg [file join $scratch l_e2e1.svg] $L_VP_E2E]
set l_ep1 [opa_l_print2 ps  [file join $scratch l_e2e1.ps]  $L_VP_E2E]
## `100u` is the gm row's value and appears nowhere else in either export;
## `MZZ1` is the carrier's OWN `T {@ref}` label, which carries no hide token and
## must keep rendering at both states — that is what makes "hidden" mean "the
## numbers went away", not "the symbol went away".
check {L24 the carrier's numbers are ABSENT from both exports at annot_show 0 and PRESENT at 1} \
  [list [opa_l_seen $l_es0 {100u}] [opa_l_seen $l_ep0 {100u}] \
        [opa_l_seen $l_es1 {100u}] [opa_l_seen $l_ep1 {100u}]] \
  {0 0 1 1}

## ⚠ L25 NEEDS THE TWIN OUT OF FRAME, AND THE FIRST DRAFT OF THIS ROW DID NOT.
## The row's marker is `100u`, and its comment claimed the string "appears nowhere
## else in either export". In l_e2e.sch it does: annot2 is the hide=true twin, and
## L23's oracle REQUIRES the twin to become visible at show_hidden_texts 1, which
## puts `100u` in the export no matter what the carrier does. As written the row was
## unsatisfiable by any I7-correct implementation — measured, with the carrier alone
## it answers {{0 1} {0 1}} exactly as claimed, and it is the twin that supplies the
## single `100u` at show_hidden_texts 1. So L25 gets its own two-instance schematic:
## the device plus the SHIPPED carrier, no twin. Everything else about the row is
## unchanged, including that it drives the shipped file and not a copy.
set f [open [file join $L_LIBDIR l_e2e_solo.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "C \{l_zzfet.sym\} 0 0 0 0 \{name=MZZ1\}"
puts $f "C \{devices/annotate_params\} 80 0 0 0 \{name=annot1 ref=MZZ1\}"
close $f
xschem load [file join $L_LIBDIR l_e2e_solo.sch]
## The raw is per-context and `xschem load` drops it, so re-annotate before exporting.
set l_ann_solo [rcall {xschem annotate_op [file join $scratch l_op.raw]}]
opa_l_annot 0 ; opa_l_sht 0
set l_a [opa_l_print2 svg [file join $scratch l_e2e_s0.svg] $L_VP_E2E]
opa_l_sht 1
set l_b [opa_l_print2 svg [file join $scratch l_e2e_s1.svg] $L_VP_E2E]
opa_l_sht 0
## ⚠ THE PRE-S7 BEHAVIOUR IS GONE ON PURPOSE (decision D2, status E). S6 shipped
## this symbol always-on one day earlier; with annot_show defaulting to 0 it now
## renders dark until `xschem set annot_show 1` or S8's `6` key. The off-ramp
## that needs no rebuild is `set annot_show 1` in ~/.xschem/xschemrc, which
## survives the `set_ne`.
check {L25 D3 the carrier ignores show_hidden_texts entirely, and its @ref label still renders} \
  [list [lindex $l_ann_solo 0] \
        [opa_l_seen $l_a {100u MZZ1}] [opa_l_seen $l_b {100u MZZ1}]] \
  {0 {0 1} {0 1}}

# ===========================================================================
# L — K4's SUCCESSOR, THE REFACTOR, AND THE CONTROLS
# ===========================================================================
# ⚠ K4 pins only that the token is IN the shipped file. Until S7 that was the
# whole guard, and it stayed green while the token did nothing. This is the row
# that says the token now DOES something: at annot_show 0 with show_hidden_texts
# 1, `hide=op` and `hide=true` must land on OPPOSITE answers.
xschem load [file join $L_LIBDIR l_main.sch]
opa_l_annot 0 ; opa_l_sht 1
check {L26 K4's successor: hide=op and hide=true now differ at annot_show 0 / show_hidden_texts 1} \
  [list [opa_l_w i_op] [opa_l_w i_true] \
        [expr {[opa_l_w i_op] eq [opa_l_w i_true]}]] [list 0 $L_W 0]
opa_l_sht 0

# ⚠ THE REFACTOR IS THE SUBSTANCE OF S7; THE FEATURE IS A FEW LINES. Before the
# change five .c files spell HIDE_TEXT and none calls a predicate. After it the
# flag lives in ONE file — set_text_flags parses it, text_hidden interprets it —
# and the four render/geometry files ask instead of testing. The second element
# keeps a "delete the tests" reading from passing.
check {L27 THE REFACTOR HAPPENED: HIDE_TEXT survives in ONE .c, and five .c files call text_hidden} \
  [list [opa_l_cfiles [file join $repo src] HIDE_TEXT] \
        [opa_l_cfiles [file join $repo src] text_hidden]] \
  {actions.c {actions.c draw.c psprint.c select.c svgdraw.c}}

# ⚠ THE PER-TAB HOLE. src/xschem.tcl is NOT in the step's Files cell but must
# change twice: a `set_ne annot_show 0` default (without it every sync logs a
# dbg(0) stderr line) and an entry in tctx::global_list (without it the mask
# silently reverts when the user opens a second tab — and no headless row can
# ever see that, which is why this one is a source grep).
check {L28 the Tcl mirror is declared once and is per-tab (tctx::global_list)} \
  [opa_l_tclmirror [file join $repo src xschem.tcl]] {1 1}

# ⚠ CONTROL, GREEN BEFORE AND AFTER. `xschem set` splits on argv[2][0] < 'n'
# (scheduler.c:11685) and only the >='n' half has the `*cmd_found = 0`
# fall-through (scheduler.c:12073). `annot_show` starts with 'a', so it lands in
# the half that silently accepts ANY name: today `xschem set annot_show 1`
# returns rc=0 with an empty result. Without this row, L3 could be satisfied by
# that fall-through rather than by a real branch.
check {L29 CONTROL `xschem set` still rejects an unknown name, and accepts annot_show} \
  [list [lindex [rcall {xschem set zzz_garbage 1}] 0] \
        [lindex [rcall {xschem set annot_show 1}] 0]] {1 0}
opa_l_annot 0

} lerr]} {
  puts "UNEXPECTED ERROR (section L): $lerr"
  incr fail
}

# =============================================================================
# SECTION M — THE TENTH SITE, actions.c:4422, WHICH NEEDS A DISPLAY
# =============================================================================
# calc_drawing_bbox's text loop sits inside `if(has_x && selected != 2)`
# (actions.c:4416), so under --nogui it never inspects a top-level text and
# `xschem get bbox` is identical at every visibility state. These two rows
# therefore SELF-SKIP headless and are the only part of S7 that owes a display:
#
#   DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog \
#       --script tests/headless/test_op_annot.tcl
#
# ⚠ `--pipe` IS MANDATORY THERE AND ITS ABSENCE IS SILENT. main.c:111 sets
# cli_opt_detach whenever stdin is not a fifo and getpgrp() != tcgetpgrp(1) --
# true of every non-interactive tool shell -- and main.c:133 then freopens BOTH
# stdout and stderr to /dev/null. Measured: without --pipe the whole suite runs,
# exits 1, and prints NOTHING AT ALL, so a reader sees an empty terminal rather
# than a result. (tests/headless/devdisplay.sh start brings :99 up.)
if {![info exists has_x]} {
  puts "skip: M1/M2 need a display — actions.c:4422's text loop is inside `if(has_x && selected != 2)`"
} else {
 if {[catch {

set XSCHEM_LIBRARY_PATH $S_LIBS
## Two schematics, not one: with both texts in the same file the bbox is their
## union and hiding one need not move it.
foreach {fn hide} {l_m_op op l_m_true true} {
  set f [open [file join $L_LIBDIR $fn.sch] w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  puts $f "L 4 0 0 10 0 {}"
  puts $f "T \{ZZBBOXWIDE\} 400 0 0 0 0.4 0.4 \{layer=4\nhide=$hide\}"
  close $f
}
proc opa_m_bbox {} { return [xschem get bbox] }

xschem load [file join $L_LIBDIR l_m_op.sch]
opa_l_sht 0
opa_l_annot 0 ; set m1a [opa_m_bbox]
opa_l_annot 1 ; set m1b [opa_m_bbox]
check {M1 actions.c:4422 a top-level hide=op text enters `xschem get bbox` only at annot_show 1} \
  [expr {$m1a ne $m1b}] 1

xschem load [file join $L_LIBDIR l_m_true.sch]
opa_l_sht 0
opa_l_annot 0 ; set m2a [opa_m_bbox]
opa_l_annot 3 ; set m2b [opa_m_bbox]
opa_l_sht 1   ; set m2c [opa_m_bbox]
check {M2 I7 actions.c:4422 a top-level hide=true text is unmoved by annot_show and moved by show_hidden_texts} \
  [list [expr {$m2a eq $m2b}] [expr {$m2a ne $m2c}]] {1 1}
opa_l_annot 0 ; opa_l_sht 0

} merr]} {
   puts "UNEXPECTED ERROR (section M): $merr"
   incr fail
 }
}


# =============================================================================
# SECTION N — S8 of doc/claude/specs/op_annotation.md: THE THREE KEYS
# =============================================================================
# S7 gave `hide=op` teeth and left the mask at 0 with NOTHING in a running
# session able to write it: measured on this tree, a freshly started xschem
# reports `annot_show` 0, and replaying what the shipped **Annotate Operating
# Point** menu item does (src/xschem.tcl:15315 — `set show_hidden_texts 1`
# then `xschem annotate_op`) leaves it at 0 too, so the user gets a loaded raw
# and a still-dark annotator. S8 is the writer of that mask:
#
#   6        -> cadence::annot_mode op       annot_show |= 1  (device OP info)
#   Ctrl-6   -> cadence::annot_mode none     annot_show  = 0
#   Alt-6    -> cadence::annot_mode opvolt   annot_show |= 2  (node voltages)
#
# ⚠ THE TABLE ABOVE WAS REWRITTEN BY THE USER'S RULING OF 2026-08-22 (issue
# 0614) AND THE NEW READING IS NOT THE OBVIOUS ONE. The three chords are TWO
# ADDITIVE SETTERS AND ONE CLEAR-ALL, not a three-state cascade: `6` never
# turns anything off and is not a toggle, `Alt-6` leaves bit0 exactly as it
# found it (so from a clean start it gives mask 2 — voltages ALONE, a state the
# old cascade could not reach), and `Ctrl-6` is the only off switch. Rows N1
# (the table as a pure function), N1b (the sequence the user pressed) and N23
# (the status line, re-keyed off the RESULTING MASK because a mode-worded line
# now lies) are that ruling; the six key-press rows live in
# tests/headless/test_launch_context.tcl.
#
# ============================================================================
# WHAT IS UNDER TEST HERE, AND WHAT IS UNDER TEST UNDER X
# ============================================================================
# `bind` and `winfo` do NOT exist under --nogui (measured: `info commands` is
# empty for both), so src/cadence_style_rc cannot even be sourced here and the
# three chords can only be pressed under a display. This section therefore
# tests the whole of `cadence::annot_mode` — every moving part of the feature —
# plus a SOURCE GREP of the rc's three bind lines, and the six rows that press
# real keys live in tests/headless/test_launch_context.tcl (G1-G6, DISPLAY=:99).
# Same split S6 decision D3 used.
#
# ============================================================================
# ⚠ THE STATUS LINE IS THE DELIVERABLE, NOT A COURTESY — AND IT MUST BE HELD
# ============================================================================
# The step's requirement 4 is "SAY WHAT HAPPENED", because the two first-run
# confusions (no raw file; no descriptor for this symbol type) are today
# SILENT: measured, `xschem annotate_op /nonexistent.raw` returns rc=0, sets
# the interp result to the FILE PATH, writes nothing to the status line and
# only prints `raw_read(): failed to open file` to stderr.
#
# `xschem statusmsg` alone does not satisfy it. Measured under :99: a plain
# statusmsg is erased by ONE `<Motion>` event (the field reverts to
# `mouse = -70 -80 - selected: 0 path: .`), and a key press is always followed
# by pointer motion in real use — while a naive headless check, which never
# generates motion, still passes. `-hold` (issue 0248, STATUSMSG_HOLD_MS) is
# what survives it, and `xschem get statusmsg_hold` is its only headless seam.
# That is row N7, and sabotage SB3 exists to prove N7 earns its place.
#
# ============================================================================
# ⚠ A FAILED annotate_op DESTROYS A GOOD ANNOTATION, SILENTLY
# ============================================================================
# scheduler.c:2409-2411 deletes the previously loaded OP and unsets
# `ngspice::ngspice_data` BEFORE it tries to open the new file. Measured: from
# `raw loaded` 0 with a populated block, `xschem annotate_op <missing>` leaves
# `raw loaded` -1 and every row blank, returns rc=0 and says nothing. So the
# key must (a) not reload while an annotation is LIVE (row N5) and (b) `file
# exists` the candidate before handing it over (rows N6/N10). Neither guard is
# visible in a message string, which is why both rows assert `raw loaded` and
# the rendered block rather than the text alone.
#
# ============================================================================
# ⚠ THE SCAN PASSES INSTANCE NAMES, NEVER INDICES
# ============================================================================
# get_instance() (scheduler.c:187) takes an all-digit string as an INDEX, so
# `op_annot::devpath 0` answers `@m.x0.mzz` — a plausible WRONG device path
# rather than an error. The scan resolves each index to its NAME first; row
# N14's `{0 zzs8probe}` half is what catches a loop that skipped that step,
# since an index-fed devpath is never empty and the sheet would always look
# annotatable.
#
# ============================================================================
# ROWS THAT ARE GREEN BEFORE THE CHANGE — CONTROLS, NOT EVIDENCE
# ============================================================================
# N20 (the three PDK rcs delegate to src/cadence_style_rc) is TRUE TODAY. It is
# here because the step plan's Files cell says to edit sky130A/ and ihp-sg13g2/
# cadence_style_rc and omits gf180mcuD — and measured, all three merely
# `source [file join $_ws .. src cadence_style_rc]`, so ONE bind block covers
# the whole three-PDK acceptance and the two named per-PDK edits are wrong. A
# run in which only N20 passes has measured nothing.

## Count the lines of <path> matching <re>; -1 when the file is absent, so a
## missing file reds one row instead of raising out of the section.
proc opa_n_grep {path re} {
  if {![file isfile $path]} { return -1 }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set n 0
  foreach l [split $d \n] { if {[regexp -- $re $l]} { incr n } }
  return $n
}
## The source text of ONE proc: from its `proc <name> {` header (column 0) up to
## the next such header, or end of file. {} when the proc is absent.
##
## ⚠ WHY THE SLICE. Rows N22b/N22c used to match `proc <name> \{.*?<needle>`
## against the WHOLE file and claimed in their own comments that this made a
## renamed-to-`..._real` no-op shim unsatisfiable. MEASURED FALSE 2026-08-25
## (issue 0682 sabotage variants S1 and S5): `.` matches a newline in Tcl, so the
## `.*?` ran from the shim's header into the real body below it and both rows
## stayed green over dead code. Cut the body out first.
proc opa_proc_src {src name} {
  set s "\n$src"
  set i [string first "\nproc $name \{" $s]
  if {$i < 0} { return {} }
  set rest [string range $s [expr {$i + 1}] end]
  set j [string first "\nproc " $rest]
  if {$j < 0} { return $rest }
  return [string range $rest 0 $j]
}

## ------------------------------------------------------------- issue 0864 --
## The whole text of <path>, or {} when it is absent — so a missing file reds
## the one row that reads it rather than raising out of the section.
proc opa_slurp {path} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  return $d
}

## The <n> lines of <path> ENDING at (and including) the first line matching
## <re>, joined — i.e. the comment paragraph that documents one rc option.
## {} when the file or the line is absent.
##
## ⚠ A WHOLE-FILE GREP CANNOT DO THIS JOB, measured: `Default: disabled` already
## appears four times in src/xschemrc, on crosshairs, the endpoint cursor and
## two netlister options. Row A64-5 asking the whole file whether it says
## "disabled" was green before a single byte changed. The claim is about ONE
## paragraph, so the row must read one paragraph.
proc opa_rc_para {path re n} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set lines [split $d \n]
  set i -1 ; set k 0
  foreach l $lines {
    if {[regexp -- $re $l]} { set i $k ; break }
    incr k
  }
  if {$i < 0} { return {} }
  set lo [expr {$i - $n + 1}]
  if {$lo < 0} { set lo 0 }
  return [join [lrange $lines $lo $i] \n]
}

## Count the CODE lines of <path> matching <re>. A line whose first non-blank
## character is `#` does not count; -1 when the file is absent.
##
## ⚠ WHY NOT opa_n_grep. Row N10c claims a name is GONE from
## utils/annot_mode.tcl. A plain line grep would also count the explanatory
## comment saying why it went, so the row would oblige the implementer to
## explain a removal without naming the thing removed -- a rule that buys no
## teeth, because a comment cannot restore a branch, and costs the file its
## prose. The teeth are entirely in the code lines: the `notlive` arm of the
## message builder and the selector that reaches for it are both code.
proc opa_n_grep_code {path re} {
  if {![file isfile $path]} { return -1 }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set n 0
  foreach l [split $d \n] {
    if {[string index [string trimleft $l] 0] eq "#"} continue
    if {[regexp -- $re $l]} { incr n }
  }
  return $n
}

## The body of ONE C function or ONE `else if` arm: from the first line matching
## <startre> down to the first following line that is EXACTLY that line's own
## indent followed by `}`. C comments are stripped LINE-WISE. {} when the start
## line is absent, so a renamed arm reds its row instead of passing vacuously.
##
## ⚠ THE COMMENTS MUST GO, AND THAT IS NOT TIDINESS. Both rows that use this
## (A64-2, O29b) look for a variable NAME, and both of the arms they slice carry
## paragraphs about that same variable. Grepping the raw text would match the
## prose and the row could never go green however correct the code was. Same
## loop shape as test_backannotate_digital.tcl's BA87, for the same reason.
##
## ⚠ THE START LINE IS RETURNED TOO, and the closing brace with it, so a row
## can name a positive control that lives in the arm's own body and prove the
## slice is not empty. A slicer that returns {} must never satisfy a
## "0 occurrences" claim.
proc opa_c_slice {path startre} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set lines [split $d \n]
  set i -1 ; set k 0
  foreach l $lines {
    if {[regexp -- $startre $l]} { set i $k ; break }
    incr k
  }
  if {$i < 0} { return {} }
  set ind {}
  regexp -- {^[ \t]*} [lindex $lines $i] ind
  set endl "$ind\}"
  set out {} ; set k $i ; set len [llength $lines]
  while {$k < $len} {
    set l [lindex $lines $k]
    if {$k > $i && $l eq $endl} { lappend out $l ; break }
    set t [string trimleft $l]
    if {[string index $t 0] ne "*" && [string range $t 0 1] ne "/*"} {
      regsub -all -- {/\*.*?\*/} $l {} l
      lappend out $l
    }
    incr k
  }
  return [join $out \n]
}
## -> {mode has-trailing-break} for one `bind .drw <chord>` line of the rc.
## The `break` half is not decoration: measured with `event generate`, Ctrl-6
## without it still reaches callback.c:7272 and selects drawing layer 6.
proc opa_n_rcbind {path chord} {
  if {![file isfile $path]} { return {NO-FILE 0} }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  foreach l [split $d \n] {
    if {[string first "bind .drw $chord" $l] < 0} continue
    set mode NO-MODE
    ## issue 0868: the fourth chord's body is `cadence::annot_tran`, not
    ## `cadence::annot_mode <word>`, so the shipped regexp answers NO-MODE for it
    ## and row V20 could never say WHICH mode the new bind reaches. The transient
    ## mode reports itself as `tran`; the three shipped chords are unaffected,
    ## because the annot_mode form is tried first.
    if {![regexp {cadence::annot_mode\s+(\w+)} $l -> mode]} {
      if {[regexp {cadence::annot_tran} $l]} { set mode tran }
    }
    return [list $mode [expr {[regexp {break\s*\}\s*$} $l] ? 1 : 0}]]
  }
  return {NO-BIND 0}
}
## 1 when <path> delegates to src/cadence_style_rc rather than copying it.
proc opa_n_delegates {path} {
  if {![file isfile $path]} { return NO-FILE }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  foreach l [split $d \n] {
    if {[regexp {source\s+\[file join .*\.\.\s+src\s+cadence_style_rc\]} $l]} { return 1 }
  }
  return 0
}
## The rendered value of <label> in a block, or MISSING-ROW — section S's
## reader, restated here so N5/N8 can say "the numbers are still there" without
## pinning the whole block.
proc opa_n_row {blk label} {
  foreach l [split $blk \n] {
    set i [string first " =" $l]
    if {$i < 0} continue
    if {[string trim [string range $l 0 [expr {$i - 1}]]] ne $label} continue
    return [string trim [string range $l [expr {$i + 2}] end]]
  }
  return MISSING-ROW
}

## Press ONE key. Returns {} on success, or the raise text — and NEVER lets the
## raise out. An absent or broken `cadence::annot_mode` must red every row that
## depends on it, one legible row each, instead of collapsing the whole section
## into a single UNEXPECTED ERROR line naming one missing command. Every row
## below carries this result as an element of its golden, so the reason is in
## the failure line rather than inferred from a stale status message.
proc opa_n_mode {m} {
  if {[catch {cadence::annot_mode $m} e]} { return "RAISED: $e" }
  return {}
}
## The non-empty results of several presses, for the rows that press more than
## once. {} when all of them worked.
proc opa_n_errs {l} {
  set o {}
  foreach e $l { if {$e ne {}} { lappend o $e } }
  return $o
}

if {[catch {

set N_SRC   [file join $repo utils annot_mode.tcl]
set N_RC    [file join $repo src cadence_style_rc]
set N_TCL   [file join $repo src xschem.tcl]
## issue 0682: the mask's THIRD writer moved OUT of src/xschem.tcl and into
## src/ase_window.tcl, so the "where does each writer live" guard now needs
## both files. Keeping only $N_TCL would let the ASE-L writer be deleted
## without a single row noticing.
set N_ASE   [file join $repo src ase_window.tcl]
## issue 0457(b): rows N22b/N22c assert WHERE each writer lives, not merely how
## many there are, so the guard survives a legitimate fourth writer being added.
set N_TCL_SRC {}
if {![catch {open $N_TCL r} _nfh]} { set N_TCL_SRC [read $_nfh] ; close $_nfh }
set N_ASE_SRC {}
if {![catch {open $N_ASE r} _afh]} { set N_ASE_SRC [read $_afh] ; close $_afh }

# ===========================================================================
# N — THE SURFACE, AND THE THREE SOURCE GREPS. No fixture, nothing loaded.
# ===========================================================================
set n_srcrc [rcall [list source $N_SRC]]
check {N0 utils/annot_mode.tcl sources cleanly under --nogui and defines the five procs} \
  [list [lindex $n_srcrc 0] \
        [expr {[llength [info commands ::cadence::annot_mode]]         ? 1 : 0}] \
        [expr {[llength [info commands ::cadence::_annot_mask]]        ? 1 : 0}] \
        [expr {[llength [info commands ::cadence::_annot_raw_candidate]] ? 1 : 0}] \
        [expr {[llength [info commands ::cadence::_annot_scan]]        ? 1 : 0}] \
        [expr {[llength [info commands ::cadence::_annot_msg]]         ? 1 : 0}]] \
  {0 1 1 1 1 1}

# ⚠ THE RULING REWROTE THIS TABLE (issue 0614). `_annot_mask` stops being three
# constants and becomes a pure function of {mode, current mask}:
#     none   -> 0            the ONLY off switch
#     op     -> cur | 1      bit1 UNTOUCHED
#     opvolt -> cur | 2      bit0 UNTOUCHED
# The sharpest element is `opvolt` FROM A CLEAN START: it is 2, NOT 3 — node
# voltages alone, no OP blocks. Today it is a hard 3, which is exactly the
# "lazy implementation" the acceptance was written to catch. `op 1 -> 1` says
# `6` is not a toggle, and `none 3 -> 0` says Ctrl-6 clears BOTH bits.
# ⚠ INTEGERS, NOT BOOLEAN WORDS. annot_show is an int and S7 measured that
# `true`/`on`/`yes` all atoi to 0, i.e. silently OFF. Sabotage SB2 flips the
# opvolt entry to 2 (bit1 only) — the exact drift this table forbids.
# ⚠ IT MUST STAY A PURE FUNCTION. The live mask arrives as an ARGUMENT (default
# 0) and is never read inside; `cadence::annot_mode` does the `xschem get`
# (row N22c's pull discipline) and hands it over. A `_annot_mask` that read the
# mask itself would make this row depend on session state, and N1b — which is
# about the session — would then be the only guard the table had.
check {N1 the mask table is ADDITIVE (issue 0614): `6` and `Alt-6` OR their bit in, `Ctrl-6` alone clears} \
  [list [rcall {cadence::_annot_mask none}] [rcall {cadence::_annot_mask op}] \
        [rcall {cadence::_annot_mask opvolt}] \
        [rcall {cadence::_annot_mask op 2}] [rcall {cadence::_annot_mask opvolt 1}] \
        [rcall {cadence::_annot_mask op 1}] [rcall {cadence::_annot_mask opvolt 3}] \
        [rcall {cadence::_annot_mask none 3}]] \
  {{0 0} {0 1} {0 2} {0 3} {0 3} {0 1} {0 3} {0 0}}

# ⚠ UNDER ADDITIVE SEMANTICS A MODE-WORDED STATUS LINE LIES, MEASURED.
# `cadence::_annot_msg` is keyed on the MODE today, so `Alt-6` from a clean
# start would announce "device OP info + node voltages" while showing voltages
# ALONE — and it has no wording at all for mask 2, the state the ruling just
# created. Re-keying it on the RESULTING MASK fixes both. This row pins the
# table itself, so a drift shows up here instead of as five unrelated
# statusmsg failures in N3/N5/N6/N8/N9/N10/N10b/N15.
# ⚠ THE WORDING IS DELIBERATELY TERSER THAN THE View MENU'S. The checkbutton is
# the discoverable surface and names bit1's whole domain ("node voltage /
# branch current annotation"); the status line is transient and says "node
# voltages", which keeps every committed golden string above unchanged.
check {N23 `_annot_msg` is worded off the RESULTING MASK, and mask 2 has a wording of its own} \
  [list [rcall {cadence::_annot_msg 0 off {} {}}] \
        [rcall {cadence::_annot_msg 1 off {} {}}] \
        [rcall {cadence::_annot_msg 2 off {} {}}] \
        [rcall {cadence::_annot_msg 3 off {} {}}]] \
  [list [list 0 $A11_M0] \
        [list 0 $A11_M1] \
        [list 0 $A11_M2] \
        [list 0 $A11_M3]]

# ⚠ A BIND-BODY TYPO IS A CALLER BUG, SO IT IS LOUD. op_annot's own discipline
# is the opposite for DATA (a missing vector blanks, I3); a mode spelling is
# not data.
check_raises {N2 an unknown mode RAISES, and the message names the accepted spelling `opvolt`} \
  {cadence::annot_mode zzs8garbage} {opvolt}

# ⚠ THE ONE FILE, THE THREE CHORDS. `break` is the whole override: measured,
# Ctrl-6 reaches callback.c:7272 and selects drawing layer 6 without it, and a
# chord TYPO is worse than a missing bind — Tk matches a pattern whose
# modifiers are a subset of the event's, so with only <Key-6> bound BOTH Ctrl-6
# and Alt-6 fire it and the OFF key silently means ON (sabotage SB8).
check {N19 src/cadence_style_rc binds all three chords to the right mode, each ending in `break`} \
  [list [opa_n_rcbind $N_RC {<Key-6>}] [opa_n_rcbind $N_RC {<Control-Key-6>}] \
        [opa_n_rcbind $N_RC {<Alt-Key-6>}]] \
  {{op 1} {none 1} {opvolt 1}}

# ⚠ CONTROL, GREEN BEFORE AND AFTER — see this section's header. It is the row
# that says the step plan's two per-PDK edits are unnecessary and that
# gf180mcuD, which the plan omits, is covered anyway.
check {N20 CONTROL all three acceptance PDKs delegate to src/cadence_style_rc, so ONE bind block reaches them} \
  [list [opa_n_delegates [file join $repo sky130A cadence_style_rc]] \
        [opa_n_delegates [file join $repo gf180mcuD cadence_style_rc]] \
        [opa_n_delegates [file join $repo ihp-sg13g2 cadence_style_rc]]] \
  {1 1 1}

# ⚠ A SOURCE GREP BECAUSE NO RUNTIME ROW CAN SEE IT. A bare `set ::annot_show N`
# leaves the C field stale (S7 item 3) but the very next
# `xschem update_all_sym_bboxes` syncs the cache — so every behavioural row
# below would stay green over the wrong spelling. D4 says use the setter.
check {N21 the mask is written through `xschem set annot_show`, never a bare `set ::annot_show`} \
  [list [expr {[opa_n_grep $N_SRC {xschem set annot_show}] >= 1 ? 1 : 0}] \
        [opa_n_grep $N_SRC {^\s*set\s+::annot_show}]] \
  {1 0}

# ⚠ THE ONE REPAIR A NON-CADENCE USER GETS (decision D8). Both shipped
# **Annotate Operating Point** bodies (Waves > Op Annotate at :14938 and
# Simulation > Graphs at :15315) set `show_hidden_texts 1` and call
# annotate_op, and S7 made the class bits ignore show_hidden_texts entirely —
# measured, that path yields a loaded raw and a carrier bbox of 29x22, i.e. a
# still-dark annotator. The cascade never runs headless, so this is a K15-style
# source guard.
# ⚠ THE COUNT MOVED 2 -> 3 ON 2026-08-22 (issue 0457(b)) AND 3 -> 2+1 ON
# 2026-08-24 (issue 0682). The user REVERSED 0457(b) on a real sky130 bench:
# annotation visibility belongs ONLY in ASE-L `Results > Annotate`, never in the
# schematic's `View > Show / Hide` ("We want to be like Cadence"). So the third
# writer -- `annot_show_menu_apply`, the View pair's push half -- is DELETED
# from src/xschem.tcl, and its successor `ase::ui::annot_apply` lives in
# src/ase_window.tcl. This is a REVERSAL, not a repair: 0457(b) answered the
# question it was asked.
#
# A bare whole-file count is a fragile shape -- it reds for every legitimate
# writer -- so the row names every writer, IN BOTH FILES, and asserts them
# STRUCTURALLY as well as by count. Adding a fourth writer anywhere without
# listing it here still reds, which is the guard this row exists to be.
# ⚠ THE SECOND ELEMENT IS THE ANTI-HOLLOW HALF: without it, deleting the
# View pair and building NOTHING in its place would satisfy this row.
check {N22 the shipped writers of the mask, by count and by file} \
  [list [opa_n_grep $N_TCL {xschem set annot_show}] \
        [opa_n_grep $N_ASE {xschem set annot_show}]] \
  {2 1}
# ⚠ THE TWO Op-Annotate BODIES MOVED 1 -> 3 ON 2026-08-22 (issue 0614). Under
# the ruling, mask 1 shows device OP blocks and HIDES node voltages; these two
# shipped menu items exist to show the classic OP back-annotation, so leaving
# them at 1 would make them hide the very numbers they are named after. Their
# own in-place comment named this moment ("deliberately NOT 3 … the moment bit1
# gets producers"), and 0614 is that moment. The third element was
# `proc annot_show_menu_apply` until 0682 and is now the ASE-L push half; it is
# matched inside the SLICED body of ase::ui::annot_apply (opa_proc_src), because
# the anchored-regexp form this row used to carry was measured to match straight
# through a no-op shim into a renamed `..._real` body.
# ⚠ RE-POINTED BY ITEM A3 (issue 1246), AND THE FOURTH ELEMENT IS WHY. Both
# menu bodies used to HARD SET the mask, which silently cleared the declutter
# bit that item A1 added at src/xschem.h — so `Waves > Op Annotate` and the
# Ctrl-Alt-6 chord disagreed about ruling D-8. They now merge bit-wise, in
# src/ase_window.tcl's shipped idiom, reading `xschem get annot_show` and never
# `$::annot_show` (row N22c's mirror trap). ⚠ THE FIRST TWO ELEMENTS CANNOT TELL
# THE TWO SITES APART — `.` matches a newline in Tcl, so both are satisfied by
# whichever writer comes first in the file, and fixing only ONE site would leave
# them both green. The fourth element is what closes that: ZERO hard sets of the
# mask survive anywhere in src/xschem.tcl. Row A29 of
# tests/headless/test_annot_declutter_1244.tcl is the seam between the files.
check {N22b ...and each one is where it is supposed to be} \
  [list [regexp {Op Annotate.*?xschem set annot_show \[expr} $N_TCL_SRC] \
        [regexp {Annotate Operating Point into schematic.*?xschem set annot_show \[expr} $N_TCL_SRC] \
        [regexp {xschem set annot_show} [opa_proc_src $N_ASE_SRC ase::ui::annot_apply]] \
        [opa_n_grep $N_TCL {^\s*xschem set annot_show 3\s*$}]] \
  {1 1 1 0}
# ⚠ RE-POINTED BY 0682. The PULL half is no longer `annot_show_menu_sync`
# reading `xschem get annot_show` in its own context -- the ASE-L window is a
# plain Tk toplevel, not an xschem drawing context, so the menu must read the
# DESIGN's mask. The three elements are: the postcommand delegates to the one
# mask reader; that reader uses `xschem get annot_show` for the current-context
# case; and it uses the `tctx::` per-window snapshot for the foreign-context
# case. Reading $::annot_show instead would report whichever context wrote last
# (measured: after a bare `set ::annot_show 0` the C field still read 3 until
# the next bulk eval).
check {N22c the ASE-L PULL half reads the DESIGN's mask, never the Tcl mirror} \
  [list [regexp {ase::ui::annot_mask} [opa_proc_src $N_ASE_SRC ase::ui::annot_menu_sync]] \
        [regexp {xschem get annot_show} [opa_proc_src $N_ASE_SRC ase::ui::annot_mask]] \
        [regexp {tctx::} [opa_proc_src $N_ASE_SRC ase::ui::annot_mask]]] \
  {1 1 1}

# ===========================================================================
# FIXTURE — one annotatable device, the SHIPPED carrier, its hide=true twin
# ===========================================================================
# ⚠ UNQUALIFIED, per this file's header note.
set XSCHEM_LIBRARY_PATH $S_LIBS

set f [open [file join $lib n_zzfet.sym] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=zzs8fet\nformat=\"@name @pinlist @model\"\ntemplate=\"name=MZZ1 model=zzdev\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "L 4 -10 -10 10 -10 {}"
puts $f "L 4 10 -10 10 10 {}"
puts $f "L 4 10 10 -10 10 {}"
puts $f "L 4 -10 10 -10 -10 {}"
close $f
## A type NO descriptor claims — the second first-run confusion's fixture.
set f [open [file join $lib n_probe.sym] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=zzs8probe\ntemplate=\"name=zp1\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "L 4 0 0 0 10 {}"
close $f
## The twin oracle, built from the SHIPPED bytes exactly as section L's L23
## builds it: byte-identical but for hide=op -> hide=true, so N17 pins a
## RELATION and never a font metric.
set n_carrier [opa_k_slurp $K_FLATSYM]
set f [open [file join $lib n_twin.sym] w]
puts -nonewline $f [string map {hide=op hide=true} $n_carrier]
close $f
## Three vectors in the R3 shapes, one Operating Point point.
proc opa_n_mkraw {path} {
  set f [open $path w]
  puts -nonewline $f "Title: S8 key fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 3
No. Points: 1
Variables:
\t0\ti(@m.xmzz1.mzz\[id\])\tcurrent
\t1\t@m.xmzz1.mzz\[gm\]\tadmittance
\t2\t@m.xmzz1.mzz\[gds\]\tadmittance
Values:
0\t1e-05
\t1e-04
\t1e-06
"
  close $f
}
set N_RAW [file join $scratch n_op.raw]
opa_n_mkraw $N_RAW
## Its own symbol type, so nothing sections P/S/L left in the store is clobbered.
proc opa_n_devproc {instname model path spiceprefix} { return {@m.xmzz1.mzz} }
catch {op_annot::register zzs8fet \
  [list devproc opa_n_devproc params {{id id 0} {gm gm 1} {gds gds 1}}]}

## Three sheets, because the three claims need three different populations:
##   n_dev     device + SHIPPED carrier + twin   (the acceptance, N17/N18)
##   n_devonly device alone                      (the scan's positive half)
##   n_probe   one type nothing can annotate     (the scan's negative half)
foreach {fn body} [list \
  n_dev.sch     "C \{n_zzfet.sym\} 0 0 0 0 \{name=MZZ1\}\nC \{devices/annotate_params\} 80 0 0 0 \{name=annot1 ref=MZZ1\}\nC \{n_twin.sym\} 220 0 0 0 \{name=annot2 ref=MZZ1\}" \
  n_devonly.sch "C \{n_zzfet.sym\} 0 0 0 0 \{name=MZZ1\}" \
  n_probe.sch   "C \{n_probe.sym\} 0 0 0 0 \{name=ZP1\}"] {
  set f [open [file join $lib $fn] w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  puts $f $body
  close $f
}
## Three netlist_dir candidates: one with a GOOD <cell>.raw, one with an
## UNPARSEABLE one, one empty. The key's behaviour differs in all three.
set N_ND_GOOD  [file join $scratch n_nd_good]
set N_ND_BAD   [file join $scratch n_nd_bad]
set N_ND_EMPTY [file join $scratch n_nd_empty]
foreach d [list $N_ND_GOOD $N_ND_BAD $N_ND_EMPTY] { file mkdir $d }
opa_n_mkraw [file join $N_ND_GOOD n_dev.raw]
set f [open [file join $N_ND_BAD n_dev.raw] w] ; puts $f "not a raw file at all" ; close $f

set n_nd_saved   $::netlist_dir
set n_live_saved $::live_cursor2_backannotate

xschem load [file join $lib n_dev.sch]
set n_ann [rcall [list xschem annotate_op $N_RAW]]
check {X10 FIXTURE n_dev.sch: an annotatable device, the SHIPPED carrier and its hide=true twin, raw live} \
  [list [lindex $n_ann 0] [xschem get instances] [xschem get modified] \
        [xschem getprop instance annot1 cell::type] \
        [op_annot::_annotated] [rcall {op_annot::text MZZ1}]] \
  [list 0 3 0 annotator 1 [list 0 "id  = 10u\ngm  = 100u\ngds = 1u\n"]]

# ===========================================================================
# N — THE MASK, THROUGH THE SURFACE THE KEYS PRESS
# ===========================================================================
set ::netlist_dir $N_ND_EMPTY
check {N3 `none` writes mask 0 through BOTH halves of the mirror and says so, plainly} \
  [list [opa_n_mode none] [rcall {xschem get annot_show}] \
        [expr {[info exists ::annot_show] ? $::annot_show : {NO-VAR}}] \
        [xschem get statusmsg]] \
  [list {} {0 0} 0 $A11_M0]

# ⚠ BOTH HALVES IN ONE ROW (S7 D4). A setter that wrote only the Tcl var would
# be healed by the `update_all_sym_bboxes` that follows it, so reading them
# apart proves nothing; sabotage SB1 routes the mask through a proc that always
# answers 0 and this is the row that sees it.
set n4e [list [opa_n_mode op]]
set n4a [list [rcall {xschem get annot_show}] \
              [expr {[info exists ::annot_show] ? $::annot_show : {NO-VAR}}]]
lappend n4e [opa_n_mode opvolt]
set n4b [list [rcall {xschem get annot_show}] \
              [expr {[info exists ::annot_show] ? $::annot_show : {NO-VAR}}]]
check {N4 `op` -> mask 1 and `opvolt` -> mask 3, C field and Tcl mirror agreeing} \
  [list [opa_n_errs $n4e] $n4a $n4b] {{} {{0 1} 1} {{0 3} 3}}

# ⚠ THE GUARD THAT PROTECTS A GOOD ANNOTATION. netlist_dir points at an
# UNPARSEABLE n_dev.raw here on purpose: an unguarded reload would hand it to
# annotate_op, which clears the live OP BEFORE it fails (scheduler.c:2409-2411)
# and returns rc=0. Sabotage SB5 deletes the short-circuit and this row is what
# catches it — the message alone would not.
# ⚠ THE EXPECTED WORDING MOVED TO MASK 3 WITH THE RULING (issue 0614), AND THE
# ROW'S CLAIM DID NOT. N4 leaves the mask at 3; under the ruling `6` ORs bit0
# in and CANNOT clear bit1, so the mask is still 3 here and the line — now
# worded off the resulting mask, row N23 — says so. Before the ruling `6` was a
# hard set to 1 and this row read "(device OP info)". A red here that reports
# `(device OP info)` is `6` still behaving as a three-state cascade.
set ::netlist_dir $N_ND_BAD
check {N5 a LIVE annotation is never reloaded: the numbers survive and the line says so} \
  [list [opa_n_mode op] [xschem raw loaded] [op_annot::_annotated] \
        [opa_n_row [op_annot::text MZZ1] gm] [xschem get statusmsg]] \
  [list {} 0 1 100u "$A11_M3$A11_LIVE"]

# ===========================================================================
# N1b — THE RULING AS THE SEQUENCE THE USER ACTUALLY PRESSES
# ===========================================================================
# ⚠ N1 IS THE TABLE; THIS IS THE SEQUENCE, AND THE SEQUENCE IS 0614's
# ACCEPTANCE VERBATIM. Seven presses, every one of them a row of the ruling:
#   Ctrl-6 -> 0   the only off switch
#   6      -> 1   ORs bit0 in
#   6      -> 1   NOT a toggle — pressing it twice leaves the mask unchanged
#   Alt-6  -> 3   ORs bit1 in, and bit0 SURVIVES
#   Ctrl-6 -> 0   clears BOTH
#   Alt-6  -> 2   voltages ALONE — the state the old cascade could not reach
#   6      -> 3   ADDS blocks without removing the voltages
# Measured on this tree BEFORE the change the same seven presses answer
# {0 1 1 3 0 3 1}: element 6 is a hard 3 (Alt-6 force-setting bit0) and element
# 7 is 1 (`6` REMOVING the voltages), the two halves the ruling forbids.
# ⚠ READ THROUGH `xschem get`, NEVER ::annot_show. N3 and N4 already pin that
# both halves of the mirror agree; reading the C field keeps this row about the
# ruling rather than about the mirror.
# ⚠ IT RUNS ON THE LIVE ANNOTATION N5 LEFT BEHIND, so every press takes the
# `live` short-circuit and the unparseable n_dev.raw is never handed over — the
# mask is the only thing moving.
set n1b_e {} ; set n1b {}
foreach n1b_m {none op op opvolt none opvolt op} {
  lappend n1b_e [opa_n_mode $n1b_m]
  lappend n1b [lindex [rcall {xschem get annot_show}] 1]
}
check {N1b THE RULING as a sequence: `6` only ADDS, `Alt-6` only ADDS, `Ctrl-6` is the one off switch} \
  [list [opa_n_errs $n1b_e] $n1b] {{} {0 1 1 3 0 2 3}}
opa_n_mode none

# ⚠ I4: THE OVERLAY NEVER MODIFIES THE SCHEMATIC. Three keys, all three modes,
# and the .sch must be untouched — no instance placed, no modify flag.
set n16_i [xschem get instances]
set n16e {}
foreach m {none op opvolt none} { lappend n16e [opa_n_mode $m] }
check {N16 I4 a full none/op/opvolt/none cycle leaves `modified` 0 and the instance count unchanged} \
  [list [opa_n_errs $n16e] [xschem get modified] [xschem get instances]] \
  [list {} 0 $n16_i]

# ===========================================================================
# N — THE ACCEPTANCE: THE SHIPPED CARRIER, DRIVEN BY THE KEY
# ===========================================================================
# ⚠ THE ORACLE IS THE TWIN, NOT A NUMBER (section L's L23 reasoning): the same
# symbol with the same text measured 68 wide in one process and 66 in another,
# so a hard-coded width would pin a FONT METRIC. annot2 is byte-identical to
# the shipped carrier but for hide=true, so its bbox at show_hidden_texts 0 IS
# "numbers hidden" and at 1 IS "numbers shown". The third element keeps a twin
# that rendered nothing from satisfying the row.
set n17e [list [opa_n_mode none]]
opa_l_sht 0 ; set n_ref_hidden [opa_l_wh annot2]
opa_l_sht 1 ; set n_ref_shown  [opa_l_wh annot2]
opa_l_sht 0
lappend n17e [opa_n_mode none] ; set n17a [opa_l_wh annot1]
lappend n17e [opa_n_mode op]   ; set n17b [opa_l_wh annot1]
check {N17 ACCEPTANCE the SHIPPED carrier follows the key: Ctrl-6 hides the numbers, 6 shows them} \
  [list [opa_n_errs $n17e] [expr {$n17a eq $n_ref_hidden}] \
        [expr {$n17b eq $n_ref_shown}] [expr {$n_ref_hidden ne $n_ref_shown}]] \
  {{} 1 1 1}

# ⚠ Alt-6 IS A SUPERSET OF 6, NOT A REPLACEMENT. Mask 3 keeps bit0, so every
# device block a `6` shows an `Alt-6` shows too; SB2's opvolt=2 drops bit0 and
# this row goes red with the carrier back at its numbers-hidden width.
set n18e [opa_n_mode opvolt] ; set n18 [opa_l_wh annot1]
check {N18 `opvolt` is a SUPERSET of `op`: mask 3 keeps bit0 and the carrier stays full} \
  [list $n18e [expr {$n18 eq $n17b}] [expr {$n18 eq $n_ref_hidden}]] {{} 1 0}
opa_n_mode none

# ===========================================================================
# N — THE FIVE RAW STATES, EACH SAID OUT LOUD
# ===========================================================================
# ⚠ REQUIREMENT 4 IS THE POINT OF THESE ROWS. Today the same three presses
# produce an EMPTY status line in every one of these states.
## ⚠ `xschem load` OF THE FILE ALREADY LOADED KEEPS THE RAW — measured, and it
## is the difference between "no raw loaded" and "the same raw still loaded".
## `raw_clear` is the Waves menu's own verb (xschem.tcl:14936) and the only
## reliable way to reach the state these three rows are about; each asserts it
## as its FIRST element so a precondition that silently failed reds legibly.
xschem load [file join $lib n_dev.sch] ; xschem raw_clear
set n6_pre [xschem raw loaded]
set ::netlist_dir $N_ND_EMPTY
check {N6 no raw loaded and none on disk: the mask still moves, the missing file is NAMED} \
  [list $n6_pre [opa_n_mode op] [xschem raw loaded] [rcall {xschem get annot_show}] \
        [xschem get statusmsg]] \
  [list -1 {} -1 {0 1} "$A11_M1 There is no results file at [file join $N_ND_EMPTY n_dev.raw] yet. Run a simulation first."]

# ⚠ WITHOUT THE HOLD THIS WHOLE SECTION IS A NO-OP IN REAL USE — see the
# header. Sabotage SB3 drops `-hold` and ONLY this row reds.
check {N7 that report is HELD (issue 0248), so the first pointer motion cannot eat it} \
  [rcall {xschem get statusmsg_hold}] {0 1}

xschem load [file join $lib n_dev.sch] ; xschem raw_clear
set n8_pre [xschem raw loaded]
set ::netlist_dir $N_ND_GOOD
check {N8 no raw loaded but one on disk: it is loaded, the block populates, the path is NAMED} \
  [list $n8_pre [opa_n_mode op] [xschem raw loaded] [op_annot::_annotated] \
        [opa_n_row [op_annot::text MZZ1] gm] [xschem get statusmsg]] \
  [list -1 {} 0 1 100u "$A11_M1 Loaded results from [file join $N_ND_GOOD n_dev.raw]."]

# ⚠ SUCCESS IS RE-ASKED, NEVER TAKEN FROM annotate_op. Measured: on a garbage
# file it returns rc=0 with the PATH as its result and `raw loaded` -1. A key
# that reported "loaded" from that rc would be the prototype's one sin —
# claiming a success it cannot prove.
xschem load [file join $lib n_dev.sch] ; xschem raw_clear
set n9_pre [xschem raw loaded]
set ::netlist_dir $N_ND_BAD
check {N9 a candidate that will not parse is reported as a FAILURE, not as a load} \
  [list $n9_pre [opa_n_mode op] [xschem raw loaded] [xschem get statusmsg]] \
  [list -1 {} -1 "$A11_M1 Could not read the results file [file join $N_ND_BAD n_dev.raw], so nothing was placed on the schematic."]

# ⚠ ISSUE 0864 — THIS ROW IS REVERSED, AND THE REVERSAL IS THE POINT. It used
# to assert issue 0451's "fourth indistinguishable cause": a database attached,
# every row blank, because the live-cursor switch was off. That cause is gone —
# the switch means "follow the cursor", not "render" — so the honest claim is
# its opposite, and this row is the BEHAVIOURAL death certificate of the
# sentence that named the switch. With the switch OFF and a database attached,
# pressing `6` reports the raw as already loaded and the block still carries its
# numbers. The row also still asserts the loaded raw was not thrown away on the
# way to saying so.
xschem load [file join $lib n_dev.sch]
xschem annotate_op $N_RAW
set ::netlist_dir $N_ND_EMPTY
set n10_lv $::live_cursor2_backannotate
set ::live_cursor2_backannotate 0
check {N10 with the live-cursor switch OFF the `6` chord reports the raw as LIVE and the block still renders} \
  [list [opa_n_mode op] [xschem raw loaded] [op_annot::_annotated] \
        [rcall {op_annot::text MZZ1}] [xschem get statusmsg]] \
  [list {} 0 1 [list 0 "id  = 10u\ngm  = 100u\ngds = 1u\n"] \
        "$A11_M1$A11_LIVE"]
set ::live_cursor2_backannotate $n10_lv

# ⚠ WHICH TERM FAILED IS NO LONGER A QUESTION (issue 0459 closes here). The
# route a user actually takes — `Waves > Op`, i.e. `xschem raw_read` — leaves
# `raw loaded` 0 and `raw annot` -1, and after 0864 that is the ONLY way the
# gate can fail with a database attached. The old wording accused the
# live-cursor switch, which is save.c ruling D5-1's plausible wrong NUMBER
# wearing a reason's clothes. The branch is also a dead end (the guard blocks
# the auto-load), so the row pins that the way out is named.
#
# ⚠ THE FIRST ELEMENT IS 0, AND IT IS AN A2 ROW RIDING ALONG. Nothing in this
# section sets the switch by now — N10 restores what it found — so what is read
# here is the SHIPPED default surviving every annotate_op the file has already
# done. Today it reads 1 for two reasons at once: the shipped default is 1, and
# `xschem annotate_op` force-sets it. Both must go.
xschem load [file join $lib n_dev.sch] ; xschem raw_clear
catch {xschem raw_read $N_RAW}
## ⚠ THIS ROW INVERTED ON 2026-09-01, AND THE SENTENCE IT USED TO PIN WAS FALSE.
## It asserted `$A11_M1$A11_NOOP` -- "The loaded results do not include an
## operating point, so there are no device values to show. Load a different
## results file from Waves > Op Annotate, then press again." $N_RAW IS AN
## OPERATING POINT: `Plotname: Operating Point`, one point, three device
## parameters (opa_n_mkraw above). The tool was telling the user to go and find
## a file it already had open.
##
## What was actually true is that `xschem raw_read` -- the `Waves > Op` route --
## does not PUBLISH, so `annot_p` was -1 and nothing could render. Pressing `6`
## did not publish either, so the press produced a sentence instead of numbers.
## It now publishes. MEASURED on this fixture's own bytes: before the press
## `annot_p` is -1 with an empty array; after it, `annot_p` is 0, the array holds
## 5 entries and `@m.xmzz1.mzz[gm]` reads 0.0001 -- the value in the file.
##
## So the row keeps its id and its subject (WHICH sentence a press mints) and
## changes the answer, in the direction the user reported from a real bench:
## a tool that says there is nothing there while the numbers sit in the file it
## has open is the defect, not the message wording. `_annotated` stays 0 and is
## still asserted: this sheet's device is not one the overlay renders here, so
## the row is about the sentence and does not quietly become an overlay row.
check {N10b a loaded operating point is PUBLISHED by the press, not refused with a false sentence} \
  [list $::live_cursor2_backannotate [xschem raw loaded] [op_annot::_annotated] \
        [opa_n_mode op] [xschem get statusmsg]] \
  [list 0 0 0 {} "$A11_M1$A11_LIVE"]
## THE HALF THAT MAKES IT NON-VACUOUS: the press really did publish. Without
## this the row above is satisfied by any change of wording.
## ⚠ READ THROUGH `array get`, NOT `$arr(key)`. The published keys carry square
## brackets (`@m.xmzz1.mzz[gm]`), and a Tcl array index is parsed as a script
## word -- so the obvious spelling asks the interpreter to run a command called
## `gm`. Measured while writing this row.
set n10b2_pairs {}
catch {set n10b2_pairs [array get ::ngspice::ngspice_data]}
set n10b2_i [lsearch -exact $n10b2_pairs {@m.xmzz1.mzz[gm]}]
check {N10b2 ...and the numbers from that file are now readable} \
  [list [expr {[lindex [xschem raw annot] 0] >= 0}] \
        [expr {$n10b2_i >= 0 ? [lindex $n10b2_pairs [expr {$n10b2_i + 1}]] : {absent}}]] \
  {1 0.0001}
xschem raw_clear

# ⚠ N10c — MANDATORY, NOT BELT-AND-BRACES, and the reason is this branch's own
# recorded lesson. After 0864 a database WITH a published point makes
# `op_annot::_annotated` answer 1, so cadence::annot_mode takes its `live` arm
# FIRST and a restored `notlive` arm below it is UNREACHABLE from there — N10,
# whose fixture is exactly that, cannot see the arm come back. That path is
# every real user's, and this row is the only cover it has.
#
# ⚠ CORRECTED 2026-08-27, BY MEASUREMENT. The first wording of this paragraph
# said "no behavioural row in the tree — N10 included — could ever see it come
# back". The sabotage run disproved that: restoring the arm (variant SAB-8)
# reddened N10b, whose fixture is the annot_p < 0 case that falls THROUGH the
# `live` arm into the selector. The row stays mandatory for the reason above;
# the stronger claim was false, and on this branch an unchecked coverage claim
# left in a comment is exactly how a guard rots.
#
# ⚠ CODE LINES ONLY (opa_n_grep_code). The prose explaining the removal may name
# both freely; what must not come back is the arm and the selector that reaches
# for it, and both of those are code.
check {N10c the sentence that named the live-cursor switch is gone from the chord status builder, arm and selector both} \
  [list [opa_n_grep_code [file join $repo utils annot_mode.tcl] {live_cursor2_backannotate}] \
        [opa_n_grep_code [file join $repo utils annot_mode.tcl] {notlive}] \
        [expr {[opa_n_grep_code [file join $repo utils annot_mode.tcl] {noop}] >= 1 ? 1 : 0}]] \
  {0 0 1}

# ===========================================================================
# A64 — ISSUE 0864: `MUST ONLY HAPPEN WHEN USER REQUESTS IT!!`
# ===========================================================================
# The user unticks `Simulation > Graphs > Live annotate probes with 'b' cursor`,
# presses `6`, and finds it ticked again. Measured on this tree, through the
# chord and through the menu item alike. Two mechanisms, and BOTH are pinned
# below because each is invisible to the other's rows:
#   * the shipped default is on          -> A64-5 (source; with 0864's render
#                                           gate gone nothing PAINTS differently
#                                           for it, so no pixel/export row can
#                                           see it. Corrected 2026-08-27: N10b
#                                           does — it reads the variable itself,
#                                           and sabotage variant SAB-6 reddened
#                                           it. The source row stays anyway: it
#                                           is the only one that also pins the
#                                           shipped rc paragraph, and the only
#                                           one a user xschemrc setting the
#                                           variable cannot falsely redden)
#   * `xschem annotate_op` force-sets it -> A64-1 / A64-3 behaviourally,
#                                           A64-2 structurally
# and the render gate that made the force-set look necessary is A64-4 / S16.
set a64_nd  $::netlist_dir
set a64_lv  $::live_cursor2_backannotate

# ⚠ THE SECOND HALF OF THE GOLDEN IS THE POSITIVE CONTROL. "The switch stayed
# off" is worth nothing next to an annotation that never happened; a build that
# refused the file outright would satisfy the first element alone.
xschem load [file join $lib n_dev.sch] ; xschem raw_clear
set ::live_cursor2_backannotate 0
set a641 [rcall [list xschem annotate_op $N_RAW]]
check {A64-1 Annotate Operating Point does not re-tick the box the user unticked} \
  [list $::live_cursor2_backannotate [lindex $a641 0] [xschem raw loaded] \
        [lindex [xschem raw annot] 0] [rcall {op_annot::text MZZ1}]] \
  [list 0 0 0 0 [list 0 "id  = 10u\ngm  = 100u\ngds = 1u\n"]]

# ⚠ THE STRUCTURAL HALF, AND IT IS THE HONEST FORM FOR A DELETED LINE. The
# force-set is ONE statement in the `annotate_op` arm of scheduler(); a row that
# only watched behaviour would go green again the moment someone re-added it
# beside a compensating read. The slice strips C comments, so the arm may
# explain at length why the line is gone. The second and third elements are the
# positive control: an arm that was renamed, or a slicer that returned nothing,
# must not satisfy the first.
set a642 [opa_c_slice [file join $repo src scheduler.c] \
            {else if\(!strcmp\(argv\[1\], "annotate_op"\)\)}]
check {A64-2 the force-set is not back in the annotate_op arm} \
  [list [regexp -all -- {live_cursor2_backannotate} $a642] \
        [expr {[string first {extra_rawfile} $a642] >= 0 ? 1 : 0}] \
        [expr {[string first {update_op} $a642] >= 0 ? 1 : 0}]] \
  {0 1 1}

# ⚠ THROUGH THE SURFACE THE USER PRESSES, not through the internal command.
# This is measurement B3 verbatim: box off, no database attached, press `6`, and
# the key finds and loads `<netlist_dir>/<cell>.raw`. It must load it, say so,
# and leave the box exactly as the user left it.
xschem load [file join $lib n_dev.sch] ; xschem raw_clear
set ::netlist_dir $N_ND_GOOD
set ::live_cursor2_backannotate 0
check {A64-3 the `6` chord loads a database without re-ticking the box} \
  [list [opa_n_mode op] [xschem raw loaded] $::live_cursor2_backannotate \
        [opa_n_row [op_annot::text MZZ1] gm] [xschem get statusmsg]] \
  [list {} 0 0 100u "$A11_M1 Loaded results from [file join $N_ND_GOOD n_dev.raw]."]

# ⚠ BEHAVIOURALLY COVERED BY S16 ALREADY, and kept anyway for one reason: S16
# reads a rendered block, so a term re-added in a shape this fixture happens to
# satisfy would leave S16 green. The two remaining terms are asserted PRESENT in
# the same row, so deleting the gate wholesale does not pass either.
set a644 [opa_proc_src [opa_slurp [file join $repo src op_annot.tcl]] op_annot::_annotated]
check {A64-4 the render gate is two terms and the live-cursor switch is not one of them} \
  [list [regexp -all -- {live_cursor2_backannotate} $a644] \
        [expr {[string first {raw loaded} $a644] >= 0 ? 1 : 0}] \
        [expr {[string first {raw annot} $a644] >= 0 ? 1 : 0}]] \
  {0 1 1}

# ⚠ SOURCE-ONLY, DELIBERATELY, AND SAID OUT LOUD. Reading the live
# `$::live_cursor2_backannotate` here would red on a developer whose own
# ~/.xschem/xschemrc sets it — a true statement about their machine, not about
# the shipped tree. And after A1 the default changes nothing that RENDERS, so
# no export or pixel row can see this half at all.
#
# ⚠ CORRECTED 2026-08-27: an earlier wording said no behavioural row in the tree
# could see it. Sabotage variant SAB-6 (default back to 1) reddened N10b, which
# reads the variable itself. The source row stays for the two reasons above —
# a user rc cannot falsely redden it, and it is the only row that also pins the
# shipped rc paragraph below.
#
# ⚠ THE VALUE IS MATCHED AS A WHOLE WORD, NOT TO END OF LINE, so the shipped
# line may carry the trailing comment naming the issue.
#
# ⚠ ELEMENTS 3-5 READ THE OPTION'S OWN PARAGRAPH IN src/xschemrc, not the file.
# The shipped rc documents this switch as "Default: enabled (1)", which the
# moment the default flips becomes a shipped contradiction — and the user is
# told to read that file. It also asserts the option is still THERE: 0864 keeps
# the feature and makes it opt-in, it does not remove it.
set a645_rc [file join $repo src xschemrc]
set a645_p  [opa_rc_para $a645_rc {^#\s*set live_cursor2_backannotate} 6]
check {A64-5 the shipped default is OFF, and the option's own rc paragraph says so} \
  [list [opa_n_grep [file join $repo src xschem.tcl] {^set_ne live_cursor2_backannotate 0(\M|$)}] \
        [opa_n_grep [file join $repo src xschem.tcl] {^set_ne live_cursor2_backannotate 1(\M|$)}] \
        [expr {[string length $a645_p] > 0 ? 1 : 0}] \
        [expr {[regexp -nocase -- {default:\s*disabled} $a645_p] ? 1 : 0}] \
        [expr {[regexp -nocase -- {default:\s*enabled} $a645_p] ? 1 : 0}]] \
  {1 0 1 1 0}

set ::netlist_dir $a64_nd
set ::live_cursor2_backannotate $a64_lv
xschem raw_clear

# ===========================================================================
# N — THE CANDIDATE BUILDER (decision D7)
# ===========================================================================
# ⚠ THE ASE SESSION CARRIES ITS LEVEL. Passing the path alone binds the raw to
# the CURRENT level and reproduces landmine 4's silent device-path collapse
# when the user has descended. The stubs are renamed in and out so the real
# ase:: procs are back before the next row.
set n_have_sfc [expr {[llength [info commands ::ase::session_for_current]] ? 1 : 0}]
set n_have_lrf [expr {[llength [info commands ::ase::last_rawfile]] ? 1 : 0}]
if {$n_have_sfc} { rename ::ase::session_for_current ::ase::_n_sfc_saved }
if {$n_have_lrf} { rename ::ase::last_rawfile        ::ase::_n_lrf_saved }
namespace eval ase {}
set ::n_ase_raw $N_RAW
proc ::ase::session_for_current {} { return [list zzs8key 2 zzlib zzcell schematic] }
proc ::ase::last_rawfile {key} { return [expr {$key eq {zzs8key} ? $::n_ase_raw : {}}] }
xschem load [file join $lib n_dev.sch]
set ::netlist_dir $N_ND_GOOD
set n11 [rcall {cadence::_annot_raw_candidate}]
catch {rename ::ase::session_for_current {}}
catch {rename ::ase::last_rawfile        {}}
if {$n_have_sfc} { rename ::ase::_n_sfc_saved ::ase::session_for_current }
if {$n_have_lrf} { rename ::ase::_n_lrf_saved ::ase::last_rawfile }
check {N11 an ASE session wins, and its LEVEL travels with the path} \
  $n11 [list 0 [list $N_RAW 2 ase]]

# ⚠ THE SHIPPED SPELLING, NOT A NEW ONE. select_raw (xschem.tcl:14763, the path
# built on :14766) is what both Annotate-OP menu items already resolve through;
# a second spelling here would be an I1-shaped drift in the path rather than in
# the vector name.
#
# ⚠ THE LEVEL IS 0, NOT {} (issue 0911). This sheet is FLAT -- the reason the
# gold reads 0 is not that the fallback learned about this sheet, it is that
# the fallback now always answers from the TOP of the hierarchy stack and
# carries that level back, so `op_annot::db_attach` binds the raw to
# xctx->sch[0] instead of letting raw_read default it to whatever sheet the
# user happens to be standing on. On a flat sheet the two are the same file, so
# NOTHING about this row's behaviour moved; only the level the answer now
# spells out loud. tests/headless/test_annot_hier_0911.tcl row H8 measures that
# equality on a live attach, and rows H2/H3 show what it buys once descended.
check {N12 with no ASE session it falls back to select_raw's `$netlist_dir/<cell>.raw`, at the top of the hierarchy} \
  [rcall {cadence::_annot_raw_candidate}] \
  [list 0 [list [file join $N_ND_GOOD n_dev.raw] 0 netlist_dir]]

# ⚠ select_raw ITSELF MUTATES THE USER'S GLOBAL — `regsub {/$} $netlist_dir {}
# netlist_dir` under `global`. A key pressed forty times must not rewrite a
# preference it only READ, so the trailing slash is stripped from a LOCAL copy.
set ::netlist_dir "$N_ND_GOOD/"
set n13 [rcall {cadence::_annot_raw_candidate}]
check {N13 a trailing slash is handled in a LOCAL copy: single-slash path, ::netlist_dir untouched} \
  [list $n13 $::netlist_dir] \
  [list [list 0 [list [file join $N_ND_GOOD n_dev.raw] 0 netlist_dir]] "$N_ND_GOOD/"]
set ::netlist_dir $N_ND_EMPTY

# ===========================================================================
# N — "NOTHING HERE IS ANNOTATABLE", THE SECOND FIRST-RUN CONFUSION
# ===========================================================================
# ⚠ CURRENT LEVEL ONLY (decision D6, invariant I6). S3's hierarchy walk is
# deferred (issues 0436/0442/0443) and its restore discipline is a known breach
# (0431); answering "is anything on THIS sheet annotatable" needs none of it.
xschem load [file join $lib n_devonly.sch]
set n14a [rcall {cadence::_annot_scan}]
xschem load [file join $lib n_probe.sch]
set n14b [rcall {cadence::_annot_scan}]
## ⚠ ISSUE 0909 ADDED A THIRD ELEMENT, AND `-1` IS THE POINT OF IT. The blank
## row probe rides this same one-pass loop rather than walking the sheet a
## second time, and it is OPTIONAL: `opvolt` draws no device block, so asking
## whether any device row is blank would be work done for a question nobody
## asked. Called with no argument the scan does not ask, and it says so with
## -1 rather than with a 0 that reads as "nothing is blank". A probe that
## answered 0 when it had not looked is the shape of defect this whole file
## exists to catch.
check {N14 the scan answers {n-annotatable types-with-no-devpath blank-row-probe}, current level only} \
  [list $n14a $n14b] {{0 {1 {} -1}} {0 {0 zzs8probe -1}}}

# ⚠ THE OTHER SILENT FIRST RUN. A user whose PDK symbol type nobody registered
# gets a blank block and no reason (issue 0451, four indistinguishable causes).
# Both confusions are reported in ONE line (decision D5): fixing the raw only to
# meet the descriptor problem on the next press is the shape D5 rejects.
## ⚠ ISSUE 0886 MOVED THIS ROW'S CLAIM OFF THE STATUS LINE, DELIBERATELY. In
## plain English this combination runs past the 255 characters the schematic's
## status bar can hold, so the status line shows the FRONT of the sentence with
## an elided tail while the sentence itself is complete. The claim -- that the
## symbol type nobody registered is NAMED -- therefore has to be asserted where
## the sentence is minted. Of the status line the row asserts only that it fits,
## and that it is either the whole sentence or a properly marked elision of its
## front, so it can never disagree with the sentence about what it says.
set n15_msg  [lindex [rcall [list cadence::_annot_msg 1 noraw [file join $N_ND_EMPTY n_probe.raw] zzs8probe]] 1]
set n15_mode [opa_n_mode op]
set n15_line [xschem get statusmsg]
check {N15 with nothing annotatable on the sheet the missing descriptor is NAMED, alongside the results file} \
  [list $n15_mode $n15_msg \
        [expr {[string length $n15_line] <= 255 ? 1 : 0}] \
        [expr {($n15_line eq $n15_msg) ||
               ([string range $n15_line end-2 end] eq {...} &&
                [string first [string range $n15_line 0 end-3] $n15_msg] == 0) ? 1 : 0}]] \
  [list {} "$A11_M1 There is no results file at [file join $N_ND_EMPTY n_probe.raw] yet. Run a simulation first. These symbol types have no operating-point values to show: zzs8probe." \
        1 1]

opa_n_mode none
set ::netlist_dir $n_nd_saved
set ::live_cursor2_backannotate $n_live_saved

} nerr]} {
  puts "UNEXPECTED ERROR (section N): $nerr"
  incr fail
}
# =============================================================================
# SECTION O — S9 of doc/claude/specs/op_annotation.md: THE DRAW-TIME OVERLAY
# =============================================================================
# S6 shipped a CARRIER: the user places one devices/annotate_params per device
# and types the device name into its `ref=`. S7 gave that carrier's `hide=op`
# text an off switch and S8 gave the switch three keys. S9 removes the placed
# symbol entirely: draw.c, svgdraw.c and psprint.c render op_annot::text on the
# DEVICE ITSELF, anchored to the instance bounding box, gated by the annot_show
# mask alone — there is no text record, so text_hidden() has no flags word to
# read and the gate is `xctx->annot_show & ANNOT_SHOW_OP` (through the shared
# reader, plan decision D2).
#
# ============================================================================
# ⚠ THE FIXTURE CARRIES NO CARRIER SYMBOL, AND THAT IS THE SHARPEST TRAP HERE
# ============================================================================
# Measured on this tree BEFORE S9: a schematic holding one `zzs9fet` instance
# and one devices/annotate_params pointed at it exports `ZZOA = 10u` today, at
# annot_show 1, from S6's carrier and S7's `hide=op` — no S9 code involved. Put
# that carrier in these fixtures and EVERY row below goes green against an
# unmodified binary while measuring nothing about the overlay. So o_main.sch,
# o_solo.sch, o_row.sch and o_hide.sch hold DEVICE INSTANCES ONLY; row X11
# greps the fixture for `annotate_params` and pins that it is absent.
#
# ============================================================================
# ⚠ THE GATE IS A NON-BLANK op_annot::text, NOT "the type has a descriptor"
# ============================================================================
# The step brief says "every instance whose symbol type has a REGISTERED
# DESCRIPTOR". Spec §4.2 (issue 0425) and §4.3 both rule the other way: skip on
# a blank DEVPATH, never on a blank descriptor, because the `type=` key is
# shared by every PDK and by the generic xschem_library/devices/*.sym.
# Measured: with only sky130 registered, devices/nmos.sym answers descriptor?=1
# and devpath {}. The descriptor gate would paint a block on 13 generic symbols
# and RED rows L19/L20/L21 (the 57-symbol shipped corpus) and L22 (a gf180 FET
# under a sky130-only registration) on the first run. O5 is the row that states
# the corrected gate; L19-L22 are its regression guard and must stay green.
#
# ============================================================================
# ⚠ THE FIXTURE SYMBOL CARRIES NO T RECORD, DELIBERATELY
# ============================================================================
# draw.c:10564 and hilight.c:4198 guard the layer `cadlayers-1` text pass with
# `((c == cadlayers-1) && symptr->texts)`; svgdraw.c:1239 and psprint.c:1612
# have no such guard. An overlay hung inside draw_symbol() therefore renders in
# SVG and PS and NOT on screen for a texts-free symbol — a silent screen/export
# divergence that no export row can see. Plan decision D3 puts the call in each
# back end's INSTANCE LOOP instead. O14 is the only row in the tree that can
# catch the guarded position, and only under a display.
#
# ============================================================================
# ⚠ THE SCREEN CALL SITE NEEDS A SEAM OR IT HAS NO POSSIBLE RED
# ============================================================================
# draw()'s entire body is inside `if(has_x)` (draw.c:10377), so under --nogui
# nothing on the screen path executes at all. Plan decision D6 adds
# `xschem get annot_overlay_count`, a monotonic counter bumped once per block
# rendered, mirroring `drawcount` (scheduler.c:4283). Rows O13/O14 are that
# seam. ⚠ ITS ABSENCE IS SILENT: measured, `xschem get annot_overlay_count`
# today returns rc=0 with the EMPTY STRING (the `get` dispatcher's unknown-name
# fall-through), exactly as `xschem set annot_show` did before S7 — which is
# why opa_o_count reports NO-SEAM rather than trusting a catch.
#
# ============================================================================
# ⚠ I4 IS MEASURED AS BYTES, NOT AS `git diff`
# ============================================================================
# The acceptance cell says "save the file and git diff is EMPTY". A headless
# row cannot run git against a fixture it just wrote, and `xschem save` may
# legitimately normalise a hand-written .sch. O4 therefore saves ONCE before
# measuring (canonical bytes), exports at all three mask values, saves again,
# and compares the two byte strings plus `xschem get modified` plus the
# instance count. ⚠ O4 IS GREEN BEFORE S9 — no overlay, no modification. It is
# an invariant guard, not evidence the feature landed; the sabotage variant it
# exists for is a `set_modify(1)` ADDED inside the shared reader.
#
# ============================================================================
# ⚠ THE PLAN'S ACCEPTANCE CELL IS THE WRONG CELL — MEASURED TWICE
# ============================================================================
# `sky130_tests_ase/bandgap` has 115 instances and ZERO with a non-blank
# op_annot devpath (its FETs are one level down; the census is 53 lab_pin, 14
# not, 11 res_xhigh_po, 8 spice_probe, 6 ammeter, 5 passgate, 4 cap_mim, 2
# pnp_05v5 …). Pressing `6` there correctly shows nothing even after S9 lands.
# The acceptance cell is `sky130_tests_ase/bandgap_opamp` (13 devices) — row
# O17 — and O18 pins bandgap's zero so the correction cannot be lost again.
#
# ============================================================================
# ⚠ POSITIONS ARE ASSERTED AS SIGNS, NOT AS PIXELS
# ============================================================================
# annot_dx / annot_dy are RELATIVE offsets in schematic units (plan D7, the
# P6 name_dx/name_dy precedent). The pixel delta they produce depends on the
# print viewport's scale, which is not part of anybody's contract, so O6/O7/O8
# assert direction (`+`/`0`/`-`, with a 1-pixel dead band) and the axis that
# must NOT move. A pixel golden here would pin the viewport instead.
#
# ============================================================================
# ⚠ PS EXPORT CARRIES ONE VOLATILE LINE — ISSUE 0454
# ============================================================================
# Section L's header records it: two PS exports of identical content are not
# byte-equal because the last colour command before `showpage` is an
# uninitialised RGB triple. O3 compares through opa_l_normps, the same
# normaliser L20/L22 use, and keeps a label assertion alongside so the row
# cannot pass on an exporter that drew nothing.
#
# ============================================================================
# ⚠ WHICH ROWS ARE RED BEFORE S9 AND WHICH ARE CONTROLS — SAY IT OUT LOUD
# ============================================================================
# RED before (16): O1 O2 O3 O5 O6 O7 O8 O9 O10 O11 O12 O13 O15 O16 O17 O20
#                  (+ O14 under a display; O18 reds on its seam element alone)
# O19 IS NOT A ROW. The plan's O19 is a regression guard on rows that already
# exist — L19/L20/L21/L22, the 57 shipped devices/*.sym and the gf180 FET under
# a sky130-only registration. They are what decision D1's gate rests on and
# they must stay GREEN; nothing new is written for them.
# GREEN before and after, i.e. invariant guards and fixture controls, NOT
# evidence that S9 happened: O4, X11, X12, and the three quiet halves of
# O5/O10/O18. A run in which only the green set passes has measured nothing.
#
# ============================================================================
# ⚠ THE GOLDENS WERE PROVED SATISFIABLE BEFORE THEY WERE COMMITTED
# ============================================================================
# L25 records what happens when they are not: a row whose marker could not be
# absent under ANY correct implementation, which no amount of green would have
# revealed. So each of O1 O2 O3 O5 O6 O7 O8 O9 O10 O11 O12 O15 O16 was replayed
# against a rendering back end BEFORE S9 existed, by standing S6's carrier
# where S9's overlay will be: the same fixtures with one
# devices/annotate_params per device at the device's own coordinates, driven
# through these same helpers. All thirteen answered their golden exactly
# (13 satisfiable, 0 unsatisfiable). The four claims that could NOT be replayed
# that way are the ones that need new C and nothing else: O13, O14, and the
# count element of O17/O18 — the `annot_overlay_count` seam.

## The fixture devproc. One device path per instance NAME, so two instances of
## one symbol get two different raw vectors and O8 can tell their blocks apart.
## I1: the test never composes a vector itself — the raw below is written from
## op_annot::_wrap's own shapes (kind 0 -> i(…), kind 1 -> bare).
proc opa_o_devproc {instname model path spiceprefix} {
  return "@m.zz[string tolower $instname]"
}

## One `type=<type>` device symbol: four strokes and NO T RECORD — see this
## section's header for why the absence is load-bearing.
proc opa_o_mkfet {dir name type} {
  set f [open [file join $dir $name] w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "K \{type=$type\nformat=\"@name @pinlist @model\"\ntemplate=\"name=MZZA model=zzdev\"\}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  puts $f "L 4 -10 -10 10 -10 {}"
  puts $f "L 4 10 -10 10 10 {}"
  puts $f "L 4 10 10 -10 10 {}"
  puts $f "L 4 -10 10 -10 -10 {}"
  close $f
}
## One schematic from {symbol x y props} quadruples.
proc opa_o_mksch {path insts} {
  set f [open $path w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  foreach {sym x y props} $insts {
    puts $f "C \{$sym\} $x $y 0 0 \{$props\}"
  }
  close $f
}
## How many instances of the CURRENT sheet op_annot would annotate. The scan
## resolves each index to its NAME first: get_instance() (scheduler.c:187)
## reads an all-digit string as an INDEX, so a devpath fed an index answers a
## plausible WRONG path and every sheet would look annotatable (N14's finding).
proc opa_o_annotatable {} {
  set n 0
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[catch {xschem getprop instance $i name} nm]} continue
    if {[catch {op_annot::devpath $nm} d]} continue
    if {$d ne {}} { incr n }
  }
  return $n
}
## The first annotatable instance NAME of the current sheet, or {}.
proc opa_o_first_annot {} {
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[catch {xschem getprop instance $i name} nm]} continue
    if {[catch {op_annot::devpath $nm} d]} continue
    if {$d ne {}} { return $nm }
  }
  return {}
}
## How many SVG/PS lines carry <marker>. One line per rendered row — measured:
## every back end's draw_string splits the block on \n (draw.c:485,
## svgdraw.c:527, psprint.c:861), so a three-row block is three elements.
proc opa_o_nseen {s marker} {
  set n 0
  foreach l [split $s \n] { if {[string first $marker $l] >= 0} { incr n } }
  return $n
}
## The {x y} of every SVG <text> element carrying <marker>, sorted by x. The
## element is one line and its position is a transform, not x=/y= — measured:
##   <text fill="#ff7777" … transform="translate(240.385, 258.545)" >ZZOA = 10u</text>
## Floats, NOT rounded: every consumer below compares with a dead band, and an
## int would make a 0.5-pixel difference look like a move.
proc opa_o_blocks {svg marker} {
  set o {}
  foreach l [split $svg \n] {
    if {[string first $marker $l] < 0} continue
    if {![regexp {translate\(([-0-9.e+]+), *([-0-9.e+]+)\)} $l -> x y]} continue
    lappend o [list $x $y]
  }
  return [lsort -real -index 0 $o]
}
## The text CONTENT of every SVG <text> element carrying <marker>, in document
## order — what the user reads, which is what I3 makes a claim about.
proc opa_o_rowtexts {svg marker} {
  set o {}
  foreach l [split $svg \n] {
    if {[string first $marker $l] < 0} continue
    if {[regexp {>([^<]*)</text>} $l -> t]} { lappend o $t }
  }
  return $o
}
## `+` / `-` / `0` with a one-pixel dead band. See the header: the viewport
## scale is not part of the contract, the DIRECTION is.
proc opa_o_sign {v} {
  if {$v > 1.0} { return + }
  if {$v < -1.0} { return - }
  return 0
}
## {x-direction y-direction} of the single ZZOA block between two exports, or a
## NO-BLOCK marker naming how many blocks each export actually had. The marker
## matters: before S9 both are 0, and a bare `lindex {} 0` fed to expr would
## raise and collapse the whole section into one UNEXPECTED ERROR line.
proc opa_o_shift {svgA svgB} {
  set a [opa_o_blocks $svgA ZZOA]
  set b [opa_o_blocks $svgB ZZOA]
  if {[llength $a] != 1 || [llength $b] != 1} {
    return "NO-BLOCK:[llength $a]/[llength $b]"
  }
  return [list [opa_o_sign [expr {[lindex $b 0 0] - [lindex $a 0 0]}]] \
               [opa_o_sign [expr {[lindex $b 0 1] - [lindex $a 0 1]}]]]
}
## {left-to-right even-spacing same-row} for a three-instance sheet, or a
## marker. "Even spacing" IS "each block follows its own instance": the three
## instances are 200 units apart, so blocks anchored per-instance are evenly
## spaced at any scale, and blocks anchored to the origin would pile up.
proc opa_o_row3 {svg} {
  set b [opa_o_blocks $svg ZZOA]
  if {[llength $b] != 3} { return "NBLOCKS:[llength $b]" }
  set x0 [lindex $b 0 0] ; set x1 [lindex $b 1 0] ; set x2 [lindex $b 2 0]
  set y0 [lindex $b 0 1] ; set y1 [lindex $b 1 1] ; set y2 [lindex $b 2 1]
  return [list [opa_o_sign [expr {$x1 - $x0}]] \
               [expr {abs(($x2 - $x1) - ($x1 - $x0)) < 1.0 ? 1 : 0}] \
               [expr {abs($y1 - $y0) < 1.0 && abs($y2 - $y1) < 1.0 ? 1 : 0}]]
}
## {fill font-family font-size} of every SVG <text> element carrying <marker>.
## Read off the element rather than hardcoded, because O20's oracle is a TWIN
## rendered in the same process, not a palette constant — L23's technique.
proc opa_o_style {svg marker} {
  set o {}
  foreach l [split $svg \n] {
    if {[string first $marker $l] < 0} continue
    set fill NO-FILL ; set fam NO-FONT ; set size NO-SIZE
    regexp {fill="([^"]*)"} $l -> fill
    regexp {font-family:([^;"]*)} $l -> fam
    regexp {font-size="([^"]*)"} $l -> size
    lappend o [list $fill $fam $size]
  }
  return $o
}
## The S9 test seam as an int, or NO-SEAM:{<what it said>}. NEVER a bare catch:
## `xschem get <unknown>` answers rc=0 and the empty string, so a catch-only
## reader would report 0 and a deleted call site would look like an idle frame.
proc opa_o_count {} {
  if {[catch {xschem get annot_overlay_count} r]} { return "RAISED:$r" }
  if {![string is integer -strict $r]} { return "NO-SEAM:\{$r\}" }
  return $r
}
## HOW MANY OVERLAY PASSES ONE `xschem print` RUNS HERE.
## ⚠ WITHOUT THIS THE COUNT ROWS ARE SATISFIABLE IN ONE ENVIRONMENT ONLY. The
## print path exports AND THEN REDRAWS THE SCREEN to restore the viewport, so
## under a display the same two-device sheet bumps the seam twice — measured on
## this tree: one `xschem print svg` of the 13-device bandgap_opamp moves the
## seam by 26 on :99 and by 13 headless. draw()'s whole body is inside
## `if(has_x)` (draw.c:10377), so headless the second pass does not exist.
## ⚠ AND `xschem get drawcount` CANNOT TELL THE TWO APART — measured,
## `draw_count++` sits ABOVE that if(has_x) guard (draw.c:10393), so it moves by
## 1 in BOTH modes and a factor derived from it reads 2 headless. The one honest
## discriminator is has_x itself, the same flag O14 and M1/M2 self-skip on.
proc opa_o_printpasses {} { return [expr {[info exists ::has_x] ? 2 : 1}] }
## The seam's delta across <script>, or the endpoint marker that broke it.
proc opa_o_delta {script} {
  set a [opa_o_count]
  uplevel #0 $script
  set b [opa_o_count]
  if {![string is integer -strict $a]} { return $a }
  if {![string is integer -strict $b]} { return $b }
  return [expr {$b - $a}]
}

if {[catch {

# ⚠ UNQUALIFIED, per this file's header note.
set XSCHEM_LIBRARY_PATH $S_LIBS

set O_VP      {1600  900 -100 -150  700 300}   ;# o_main / o_row / o_hide
set O_VP_SOLO {1000  800 -200 -300  500 400}   ;# o_solo: room for dx/dy 200
set O_VP_BG   {2000 1400 -100 -1400 2400 200}  ;# the two sky130_tests_ase cells
set O_BGOPAMP [file join $repo sky130A xschem_libs sky130_tests_ase \
                         bandgap_opamp schematic bandgap_opamp.sch]
set O_BANDGAP [file join $repo sky130A xschem_libs sky130_tests_ase \
                         bandgap schematic bandgap.sch]

# --- the fixtures ------------------------------------------------------------
opa_o_mkfet $lib o_fet.sym  zzs9fet
opa_o_mkfet $lib o_skip.sym zzs9skip
opa_o_mksch [file join $lib o_main.sch] \
  {o_fet.sym 0 0 {name=MZZA}  o_fet.sym 200 0 {name=MZZB}}
opa_o_mksch [file join $lib o_solo.sch] {o_fet.sym 0 0 {name=MZZA}}
opa_o_mksch [file join $lib o_row.sch] \
  {o_fet.sym 0 0 {name=MZZA}  o_fet.sym 200 0 {name=MZZB}  o_fet.sym 400 0 {name=MZZC}}
## hide=true -> HIDE_INST, hide_texts=true -> HIDE_SYMBOL_TEXTS (actions.c:1051-1053).
opa_o_mksch [file join $lib o_hide.sch] \
  {o_fet.sym 0 0 {name=MZZA}  o_fet.sym 200 0 {name=MZZC hide=true}
   o_fet.sym 400 0 {name=MZZD hide_texts=true}}
opa_o_mksch [file join $lib o_skip.sch] {o_skip.sym 0 0 {name=MZZS}}
## ⚠ THE ONE FIXTURE THAT DOES CARRY THE CARRIER, AND ONLY O20 USES IT. O20
## compares S9's overlay AGAINST S6's carrier, so it needs both blocks in one
## frame and asserts there are TWO — which is exactly what an absent overlay
## cannot supply. Every other fixture in this section is carrier-free for the
## reason the header gives.
opa_o_mksch [file join $lib o_twin.sch] \
  {o_fet.sym 0 0 {name=MZZA}  devices/annotate_params 300 0 {name=an1 ref=MZZA}}

## Three params, three kinds' worth of shapes, labels that appear nowhere else
## in an SVG or a PS file. ⚠ ZZOA/ZZOB/ZZOC are the LABELS; zzid/zzgm/zzgds are
## the raw parameter names. S5's formatter keys the two apart (rows S12/S13) and
## a fixture that spelled them the same would hide a swap.
set O_PARAMS {{ZZOA zzid 0} {ZZOB zzgm 1} {ZZOC zzgds 1}}
catch {op_annot::register zzs9fet [list devproc opa_o_devproc params $O_PARAMS]}

## An operating point for MZZA only, written from op_annot::_wrap's own shapes.
set O_RAW [file join $scratch o_op.raw]
set f [open $O_RAW w]
puts -nonewline $f "Title: S9 overlay fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 3
No. Points: 1
Variables:
\t0\ti(@m.zzmzza\[zzid\])\tcurrent
\t1\t@m.zzmzza\[zzgm\]\tadmittance
\t2\t@m.zzmzza\[zzgds\]\tadmittance
Values:
0\t1e-05
\t1e-04
\t1e-06
"
close $f

## The two goldens the whole section rests on: what op_annot::text returns with
## no raw (I3: `label =`, nothing after the `=`) and with the raw above.
set O_BLANK {{ZZOA =} {ZZOB =} {ZZOC =}}
set O_VALUED {{ZZOA = 10u} {ZZOB = 100u} {ZZOC = 1u}}

xschem load [file join $lib o_main.sch]
check {X11 FIXTURE o_main.sch: two annotatable devices, three rows each, and NO carrier symbol in the file} \
  [list [xschem get instances] \
        [list [op_annot::devpath MZZA] [op_annot::devpath MZZB]] \
        [opa_s5_lines [op_annot::text MZZA]] \
        [string first annotate_params [opa_k_slurp [file join $lib o_main.sch]]]] \
  [list 2 {@m.zzmzza @m.zzmzzb} $O_BLANK -1]

check {X12 CONTROL the fixture symbol carries NO T record — the texts-free case draw.c:10500 guards away} \
  [list [llength [opa_k_texts [file join $lib o_fet.sym]]] \
        [xschem getprop instance MZZA cell::type]] \
  {0 zzs9fet}

# ===========================================================================
# O — THE THREE BACK ENDS
# ===========================================================================
opa_l_annot 0
set o_svg0 [opa_l_print2 svg [file join $scratch o_m0.svg] $O_VP]
set o_ps0  [opa_l_normps [opa_l_print2 ps [file join $scratch o_m0.ps] $O_VP]]
opa_l_annot 1
set o_svg1 [opa_l_print2 svg [file join $scratch o_m1.svg] $O_VP]
set o_ps1  [opa_l_normps [opa_l_print2 ps [file join $scratch o_m1.ps] $O_VP]]

check {O1 the overlay RENDERS, and only with annot_show bit0: the two SVG exports differ} \
  [list [expr {$o_svg0 ne $o_svg1}] [expr {[string length $o_svg0] > 1000}]] {1 1}

check {O2 I1 every label op_annot::text returns is in the annot_show 1 SVG and in none of the 0 SVG} \
  [list [opa_l_seen $o_svg1 {ZZOA ZZOB ZZOC}] [opa_l_seen $o_svg0 {ZZOA ZZOB ZZOC}]] \
  {{1 1 1} {0 0 0}}

## ⚠ psprint.c IS A SEPARATE CALL SITE AND THIS IS ITS ONLY ROW — the brief
## calls SVG and PS "the ones nobody looks at". Colour-normalised per 0454.
check {O3 the SAME claim through psprint.c: normalised PS differs, and carries the labels} \
  [list [expr {$o_ps0 ne $o_ps1}] \
        [opa_l_seen $o_ps1 {ZZOA ZZOB ZZOC}] [opa_l_seen $o_ps0 {ZZOA ZZOB ZZOC}]] \
  {1 {1 1 1} {0 0 0}}

# ===========================================================================
# O — I4: THE SCHEMATIC IS NEVER MODIFIED
# ===========================================================================
# ⚠ GREEN BEFORE AND AFTER. Its sabotage variant is a `set_modify(1)` added
# inside the shared reader, not a removed line — see the header for why the
# claim is bytes plus `modified` plus the instance count rather than `git diff`.
xschem load [file join $lib o_main.sch]
catch {xschem save}
set o4_before [opa_k_slurp [file join $lib o_main.sch]]
foreach a {0 1 3} {
  opa_l_annot $a
  opa_l_print svg [file join $scratch o_i4_$a.svg] $O_VP
  opa_l_print ps  [file join $scratch o_i4_$a.ps]  $O_VP
}
## ⚠ THE FLAG IS READ BEFORE THE TRAILING SAVE, NOT AFTER — issue 0466's own
## named test defect. `xschem save` ends in set_modify(0), so an element read
## after it is 0 whether or not I4 was breached: this row stayed GREEN on :99
## with a live set_modify(1) planted inside the shared reader. The byte compare
## still needs the second save (a hand-written .sch may legitimately normalise),
## so the two measurements are taken in the order that makes each one mean
## something.
set o4_mod [xschem get modified]
catch {xschem save}
set o4_after [opa_k_slurp [file join $lib o_main.sch]]
check {O4 I4 exporting at every mask value places nothing, sets no modify flag and writes no byte} \
  [list [expr {$o4_before eq $o4_after}] $o4_mod [xschem get instances] \
        [expr {[string length $o4_before] > 50}]] \
  {1 0 2 1}

# ===========================================================================
# O — D1: THE GATE IS A BLANK DEVPATH, NEVER A BLANK DESCRIPTOR
# ===========================================================================
# ⚠ TWO HALVES ON PURPOSE. The first is TRUE TODAY and stays true — it is the
# same claim rows L19-L22 make on 57 shipped symbols. The second is the one
# that reds before S9, and without it the row would pass on an exporter that
# renders nothing at all.
xschem load [file join $lib o_skip.sch]
catch {op_annot::register zzs9skip \
  [list devproc opa_o_devproc params $O_PARAMS match {*sky130_fd_pr/*}]}
set o5_desc [expr {[op_annot::descriptor zzs9skip] ne {} ? 1 : 0}]
set o5_dev  [op_annot::devpath MZZS]
opa_l_annot 0 ; set o5a [opa_l_print2 svg [file join $scratch o_skip0.svg] $O_VP]
opa_l_annot 1 ; set o5b [opa_l_print2 svg [file join $scratch o_skip1.svg] $O_VP]
catch {op_annot::register zzs9skip [list devproc opa_o_devproc params $O_PARAMS]}
opa_l_annot 0 ; set o5c [opa_l_print2 svg [file join $scratch o_skip2.svg] $O_VP]
opa_l_annot 1 ; set o5d [opa_l_print2 svg [file join $scratch o_skip3.svg] $O_VP]
check {O5 D1 a non-matching `match` glob blanks the DEVPATH and the overlay, though the descriptor is registered} \
  [list $o5_desc $o5_dev [expr {$o5a eq $o5b}] [expr {$o5c ne $o5d}]] \
  {1 {} 1 1}

# ===========================================================================
# O — THE ANCHOR AND THE annot_dx / annot_dy OVERRIDE
# ===========================================================================
# ⚠ `xschem setprop` MARKS THE SCHEMATIC MODIFIED — that is the SETTER's doing,
# not the overlay's, and every row here reloads afterwards so O4's claim is
# never measured through it. Setting the token also bumps `modify_seq`, which
# is the epoch field the plan's cache invalidation reads (decision D4), so
# these two rows double as the cache-staleness rows.
xschem load [file join $lib o_solo.sch]
opa_l_annot 1
set o6a [opa_l_print2 svg [file join $scratch o_dx0.svg] $O_VP_SOLO]
xschem setprop instance MZZA annot_dx 200
xschem update_all_sym_bboxes
set o6b [opa_l_print2 svg [file join $scratch o_dx1.svg] $O_VP_SOLO]
check {O6 annot_dx moves the block RIGHT and leaves its row unchanged} \
  [opa_o_shift $o6a $o6b] {+ 0}

xschem load [file join $lib o_solo.sch]
opa_l_annot 1
set o7a [opa_l_print2 svg [file join $scratch o_dy0.svg] $O_VP_SOLO]
xschem setprop instance MZZA annot_dy 200
xschem update_all_sym_bboxes
set o7b [opa_l_print2 svg [file join $scratch o_dy1.svg] $O_VP_SOLO]
check {O7 annot_dy moves the block DOWN and leaves its column unchanged — dx and dy are not swapped} \
  [opa_o_shift $o7a $o7b] {0 +}

## ⚠ THE ANCHOR IS THE INSTANCE, NOT THE ORIGIN. Three identical devices 200
## units apart: blocks anchored per-instance are evenly spaced at any viewport
## scale, blocks anchored to the sheet origin pile up on top of each other.
xschem load [file join $lib o_row.sch]
opa_l_annot 1
set o8 [opa_l_print2 svg [file join $scratch o_row1.svg] $O_VP]
check {O8 three instances give three blocks, left to right, evenly spaced and on one row} \
  [opa_o_row3 $o8] {+ 1 1}

# ===========================================================================
# O — I3: A MISSING VECTOR RENDERS BLANK, AND THAT IS WHAT REACHES THE SVG
# ===========================================================================
# ⚠ THE ROW COMPARES THE EXPORT AGAINST THE FORMATTER, BOTH WAYS. Element 2 is
# op_annot::text's own answer and is GREEN today: if S9 ever re-derives the
# rows in C (an I1 breach) or prints 0 / NaN / the previous run's number
# (save.c ruling D5-1), element 1 moves and element 2 does not.
xschem load [file join $lib o_solo.sch]
opa_l_annot 1
set o9 [opa_l_print2 svg [file join $scratch o_i3.svg] $O_VP_SOLO]
check {O9 I3 with no raw loaded the exported rows are `label =` verbatim — no 0, no NaN, no digit} \
  [list [opa_o_rowtexts $o9 ZZO] [opa_s5_lines [op_annot::text MZZA]]] \
  [list $O_BLANK $O_BLANK]

# ===========================================================================
# O — THE MASK ROUND TRIP AND THE DESCRIPTOR GENERATION (I5)
# ===========================================================================
xschem load [file join $lib o_main.sch]
opa_l_annot 1 ; set o10a [opa_l_print2 svg [file join $scratch o_rt1a.svg] $O_VP]
opa_l_annot 0 ; set o10b [opa_l_print2 svg [file join $scratch o_rt0.svg]  $O_VP]
opa_l_annot 1 ; set o10c [opa_l_print2 svg [file join $scratch o_rt1b.svg] $O_VP]
check {O10 mask round trip 1 -> 0 -> 1: the two ON exports are byte-identical and the OFF one differs} \
  [list [expr {$o10a eq $o10c}] [expr {$o10a ne $o10b}]] {1 1}

## ⚠ I5: "a user's op_annot::register in their own rc overrides the PDK's, and
## takes effect ON REDRAW — no restart, no rebuild". Nothing in C can see a Tcl
## re-registration today, so a cross-frame cache defeats I5 unless op_annot
## publishes a generation the sync reads (plan decision D5). Element 2 is
## op_annot::text's own answer, green today, so a red element 1 names the cache
## rather than the formatter.
catch {op_annot::register zzs9fet [list devproc opa_o_devproc params {{ZZQA zzid 0}}]}
set o11 [opa_l_print2 svg [file join $scratch o_i5.svg] $O_VP]
check {O11 I5 a re-registered descriptor changes the block on the NEXT export, with no restart} \
  [list [opa_l_seen $o11 {ZZQA ZZOA}] [opa_s5_lines [op_annot::text MZZA]]] \
  [list {1 0} {{ZZQA =}}]
catch {op_annot::register zzs9fet [list devproc opa_o_devproc params $O_PARAMS]}

# ===========================================================================
# O — I3's OTHER HALF: A NEW OPERATING POINT MUST REACH THE OVERLAY
# ===========================================================================
# ⚠ THE STALE-PREVIOUS-RUN CASE IS THIS ROW'S WHOLE POINT. Re-simulating and
# re-annotating the SAME file reuses the Raw allocation with identical
# nvars/level, so a cache epoch built only from fields already in xctx does not
# move and the overlay keeps showing the previous run's numbers — the literal
# wording I3 forbids. Plan decision D4 adds an explicit bump in update_op()
# (save.c:1988) and backannotate_at_cursor_b_pos() (callback.c:1531).
xschem load [file join $lib o_solo.sch]
opa_l_annot 1
set o12a [opa_l_print2 svg [file join $scratch o_op0.svg] $O_VP_SOLO]
set o12r [rcall {xschem annotate_op $O_RAW}]
set o12b [opa_l_print2 svg [file join $scratch o_op1.svg] $O_VP_SOLO]
check {O12 a raw published between two exports CHANGES the rendered numbers} \
  [list [lindex $o12r 0] [opa_o_rowtexts $o12a ZZO] [opa_o_rowtexts $o12b ZZO] \
        [opa_s5_lines [op_annot::text MZZA]]] \
  [list 0 $O_BLANK $O_VALUED $O_VALUED]

# ===========================================================================
# O — THE SEAM (decision D6)
# ===========================================================================
# ⚠ opa_l_print, NOT opa_l_print2: the warmed form exports TWICE and would
# double every delta measured through it.
xschem load [file join $lib o_main.sch]
opa_l_annot 1
set o_pp [opa_o_printpasses]
set o13a [opa_o_delta {opa_l_print svg [file join $scratch o_cnt1.svg] $O_VP}]
opa_l_annot 0
set o13b [opa_o_delta {opa_l_print svg [file join $scratch o_cnt0.svg] $O_VP}]
check {O13 `xschem get annot_overlay_count` counts one bump per block per export, and none at mask 0} \
  [list $o13a $o13b] [list [expr {2 * $o_pp}] 0]

# ===========================================================================
# O — sym_txt, hide=true AND hide_texts=true (decision D9)
# ===========================================================================
# ⚠ ONE READER DECIDES, THREE BACK ENDS OBEY. A user who switched symbol text
# off, or hid one instance's texts, must not still get a block of numbers
# pinned to that instance — and the screen and the two exports must not be able
# to disagree about it, which is what putting the test in the shared reader buys.
opa_l_annot 1
set o15a [opa_l_print2 svg [file join $scratch o_st1.svg] $O_VP]
catch {xschem set sym_txt 0}
set o15b [opa_l_print2 svg [file join $scratch o_st0.svg] $O_VP]
catch {xschem set sym_txt 1}
set o15c [opa_l_print2 svg [file join $scratch o_st1b.svg] $O_VP]
check {O15 D9 sym_txt 0 removes the overlay and sym_txt 1 restores it} \
  [list [opa_o_nseen $o15a ZZOA] [opa_o_nseen $o15b ZZOA] [opa_o_nseen $o15c ZZOA]] \
  {2 0 2}

xschem load [file join $lib o_row.sch]
opa_l_annot 1
set o16a [opa_l_print2 svg [file join $scratch o_h3.svg] $O_VP]
xschem load [file join $lib o_hide.sch]
opa_l_annot 1
set o16b [opa_l_print2 svg [file join $scratch o_h1.svg] $O_VP]
check {O16 D9 hide=true and hide_texts=true each suppress the block, and the neighbour keeps its own} \
  [list [opa_o_nseen $o16a ZZOA] [opa_o_nseen $o16b ZZOA]] {3 1}

# ===========================================================================
# O — THE RENDER CONSTANTS, AS A TWIN AND NOT AS A PALETTE (decision D7)
# ===========================================================================
# ⚠ D7 lifts layer 15, font Monospace and size 0.2 VERBATIM from the shipped
# devices/annotate_params so that "carrier 1 and carrier 2 look identical side
# by side" — that sentence is the whole reason the constants are not freshly
# invented. Asserting `fill="#ff7777"` would pin the PALETTE instead, and the
# next person to edit a colour table would red a row about fonts. So the oracle
# is L23's: the SHIPPED carrier rendering the SAME block in the SAME frame, and
# the claim is that the two blocks are indistinguishable in fill, family and
# size. ⚠ ELEMENT 1 IS WHAT KEEPS IT HONEST — with no overlay there is ONE
# block and one style, which would otherwise satisfy "all styles agree".
xschem load [file join $lib o_twin.sch]
opa_l_annot 1
set o20 [opa_l_print2 svg [file join $scratch o_twin.svg] $O_VP]
set o20s [opa_o_style $o20 ZZOA]
check {O20 D7 the overlay and the shipped carrier render the same block in the same fill, family and size} \
  [list [llength $o20s] [llength [lsort -unique $o20s]]] {2 1}

# ===========================================================================
# O — ACCEPTANCE ON SHIPPED DATA
# ===========================================================================
# ⚠ EVERY ROW RENDERS BLANK HERE AND THAT IS THE HONEST RESULT. No save-card
# generator exists (S3/S4 deferred, issues 0436/0442/0443), so a real bandgap
# raw carries no device vectors and I3 blanks all ten rows. The row asserts the
# blankness rather than hunting for a raw that makes the demo look good.
set XSCHEM_LIBRARY_PATH $P_SKY_LIBS
opa_source [file join $repo sky130A sky130_procs.tcl]
xschem load $O_BGOPAMP
set o17n [opa_o_annotatable]
set o17i [opa_o_first_annot]
opa_l_annot 0
set o17a [opa_l_print2 svg [file join $scratch o_bg0.svg] $O_VP_BG]
opa_l_annot 1
set o17d [opa_o_delta {set o17b [opa_l_print svg [file join $scratch o_bg1.svg] $O_VP_BG]}]
# ⚠ THE OVERLAY-ONLY PROBE MOVED FROM `vdsat` TO `gds` — RULING D9. The probe
# has to be a label the OVERLAY paints and the shipped symbol texts do NOT, or
# the row cannot tell the two apart. sky130's FET symbols print id/gm/vgs/vds;
# under D9 the overlay's six are id gm gds vgs vth vds, so `gds` (and `vth`) are
# what remains overlay-only. `vdsat` is no longer painted by anything, which
# would have left this row asserting 0-then-0 — green, and hollow.
check {O17 ACCEPTANCE sky130_tests_ase/bandgap_opamp: 13 devices annotate, all rows blank, nothing modified} \
  [list $o17n [opa_l_seen $o17a {gds}] [opa_l_seen $o17b {gds}] $o17d \
        [xschem get modified] [opa_s5_allblank [op_annot::text $o17i]]] \
  [list 13 0 1 [expr {13 * $o_pp}] 0 {6 {}}]

# ⚠ THE PLAN'S OWN ACCEPTANCE CELL, PINNED AS THE COUNTEREXAMPLE. Its FETs are
# one level down; `6` here correctly shows nothing even after S9 lands. Without
# this row the wrong cell comes back the next time somebody reads the plan.
xschem load $O_BANDGAP
set o18n [opa_o_annotatable]
opa_l_annot 0
set o18a [opa_l_print2 svg [file join $scratch o_bgp0.svg] $O_VP_BG]
opa_l_annot 1
set o18d [opa_o_delta {set o18b [opa_l_print svg [file join $scratch o_bgp1.svg] $O_VP_BG]}]
check {O18 sky130_tests_ase/bandgap has 115 instances and ZERO annotatable — the plan named the wrong cell} \
  [list [xschem get instances] $o18n [expr {$o18a eq $o18b}] $o18d] \
  {115 0 1 0}

set XSCHEM_LIBRARY_PATH $S_LIBS
opa_l_annot 0

} oerr]} {
  puts "UNEXPECTED ERROR (section O): $oerr"
  incr fail
}

# =============================================================================
# SECTION O (cont) — INVALIDATION: EVERY WAY A NAME OR A VALUE CHANGES
# =============================================================================
# Attempt 1 of S9 was BUILT, went green on 192 of these checks and on nine
# sabotage variants, and was then REVERTED by its own write-up agent (issue
# 0466). Nothing above this line was wrong. What was wrong is that the
# per-instance cache the overlay carries is invalidated by a 13-field EPOCH,
# and `xschem reload` moves none of those fields:
#
#   * load_schematic's set_modify(0) does not bump modify_seq — actions.c:200
#     is `if((mod == 1 || mod == 3) && !ro_suppress) ++xctx->modify_seq;`
#   * the same path hashes the same
#   * the Raw allocation, its nvars and its level are untouched
#
# so a device RENAMED ON DISK keeps rendering its PREDECESSOR'S number on every
# later frame and every later export. That is literally invariant I3's
# forbidden "the previous run's number", it is one click from the FileReload
# toolbar button, and it was silent to all 192 checks because the four `reload`
# hits in this file never re-load a schematic.
#
# ⚠ MEASURED ON THIS TREE, WITH NO OVERLAY COMPILED IN, so the defect statement
# survives a rebuild: after `xschem load` the sheet holds instances=1
# inst0.name=MZZA modified=0; after rewriting the file on disk and `xschem
# reload` it holds instances=1 inst0.name=MZZB modified=0. The device's NAME
# changed while the instance count and the dirtiness signal both stood still.
#
# ============================================================================
# ⚠ THE ONE-LINE FIX 0466 NAMED IS NOT ENOUGH, AND EACH GAP HAS ITS OWN ROW
# ============================================================================
# 0466 proposes one annot_data_changed() in load_schematic(). Measured, eight
# more ways exist to change what a device is CALLED or what it is WORTH without
# moving any epoch field. Each gets a row, because an enumeration that is not
# tested is an enumeration that leaks — which is exactly how attempt 1 died:
#
#   O21 same-path `xschem reload` after a rename      the 0466 repro, user path
#   O22 `xschem load -keep_symbols` same path         isolates the load hook
#   O23 same path, same NAME, `model=` rewritten      the half a name guard
#                                                     cannot see
#   O24 same-path reload with NOTHING changed         a flush must not fabricate
#   O25 two SIBLING instances of one subcircuit       sim_sch_path, not sch[]
#   O26 setprop rename, undo, redo                    the restore paths
#   O27 the SAME raw path rewritten and re-annotated  same alloc, same nvars
#   O28 `xschem setprop instance … name`              the scripted rename
#   O29 `live_cursor2_backannotate` toggled           a SHIPPED menu checkbutton
#   O30 `xschem raw rename` under a static schematic  nvars/ptr/level unmoved
#   O31 `xschem reload_symbols` after a type= change  zero set_modify calls
#   O37 two OP raws loaded, `raw switch` between them  the xctx->raw pointer
#
# and one more on the screen back end, in section O2 beside O14:
#
#   O38 two consecutive steady-state redraws            the cache must SURVIVE
#
# ============================================================================
# ⚠ MECHANISM ISOLATION — WHY THREE ROWS SAY ALMOST THE SAME THING
# ============================================================================
# `xschem reload` (scheduler.c:10804) calls remove_symbols() BEFORE
# load_schematic (:10808/:10809), so the FileReload button is covered three
# times over and O21 alone can never red for a cache reason. O22 drives the
# identical rename through `xschem load -keep_symbols <same absolute path>`,
# which measurably does NOT reload symbols — verified on this tree: with the
# .sym's `type=` rewritten on disk, `load -keep_symbols` still answers the OLD
# type and a plain `load` answers the new one. O23 then removes the NAME from
# the picture entirely. O21 is the user path; O22 and O23 are the isolators.
#
# ============================================================================
# ⚠ THE SEAM ROWS ARE NOT DECORATION: WITHOUT THEM THE CACHE CAN BE DELETED
# ============================================================================
# Every staleness row above is satisfied by an implementation that flushes the
# cache on every single frame — i.e. by deleting the cache, which is precisely
# what the measured redraw cost says must not happen. `xschem get
# annot_overlay_flushes` (a monotonic count of WHOLESALE flushes, beside D6's
# per-block annot_overlay_count) is the only handle that can tell "invalidated"
# from "never cached": O34 asserts the second of two identical exports flushes
# ZERO times. It is also the only headless handle on editprop.c:1263's
# `set_modify(-2); draw();` — the property form's Apply button paints one frame
# BEFORE its caller's set_modify(1) at editprop.c:1289, and mod -2 does not move
# modify_seq (O33).
#
# ============================================================================
# ⚠ THE SEAM DELTAS ARE MEASURED WITH THE INVALIDATION INSIDE THE SCRIPT
# ============================================================================
# `xschem load` DRAWS under a display and does not headless (draw()'s body is
# inside `if(has_x)`, draw.c:10377). Measuring "load, then export" as two steps
# therefore gives {0,…} on :99 and {1,…} headless for the same correct code.
# Wrapping the invalidating call AND the export in one opa_o_fdelta makes every
# golden below arm-independent — no opa_o_printpasses factor, unlike O13/O17.
#
# ============================================================================
# ⚠ WHICH ROWS ARE RED BEFORE S9 AND WHICH ARE GREEN CONTROLS — OUT LOUD
# ============================================================================
# RED before (16): O21 O22 O23 O24 O25 O26 O27 O28 O29 O30 O31 O32 O33 O34 O35
#                  O37  (+ O36 and O38 under a display)
# GREEN before and after (1): X13. It is a FIXTURE control and it measures
# nothing about the overlay — its job is to prove that two sibling instances
# really do present an identical (currsch, file, instance count, modified)
# tuple with DIFFERENT devpaths, which is what makes O25 non-vacuous. A run in
# which only X13 passes has measured nothing.
#
# ============================================================================
# ⚠ THE GOLDENS WERE PROVED SATISFIABLE BEFORE THEY WERE COMMITTED (L25)
# ============================================================================
# Eleven of these rows — O21 O22 O23 O24 O25 O26 O27 O28 O29 O30 O31, plus O36
# in section O2 — were replayed against a rendering back end BEFORE S9 existed,
# by standing S6's carrier where S9's overlay will be: the same fixtures with
# one devices/annotate_params per device, driven through these same helpers.
# All twelve answered their golden exactly (12 satisfiable, 0 unsatisfiable).
# The rows that could NOT be replayed that way are the ones that need new C and
# nothing else: O32 O33 O34 O35 and O38, the annot_overlay_flushes seam. O37 is
# a later addition and was not in that replay either; what WAS measured for it,
# on this tree with no overlay compiled in, is every leg of its sequence read
# through op_annot::text — 10u/100u/1u, then blank after `raw read`, then
# 70u/700u/7u after `raw switch`, then 10u/100u/1u back — so its goldens are
# observed behaviour of the formatter, not a guess about it.

## The SECOND S9 seam, read exactly like opa_o_count and for the same reason:
## `xschem get <unknown>` answers rc=0 and the EMPTY STRING, so a catch-only
## reader would report 0 and a never-flushing cache would look correct.
proc opa_o_flushes {} {
  if {[catch {xschem get annot_overlay_flushes} r]} { return "RAISED:$r" }
  if {![string is integer -strict $r]} { return "NO-SEAM:\{$r\}" }
  return $r
}
proc opa_o_fdelta {script} {
  set a [opa_o_flushes]
  uplevel #0 $script
  set b [opa_o_flushes]
  if {![string is integer -strict $a]} { return $a }
  if {![string is integer -strict $b]} { return $b }
  return [expr {$b - $a}]
}
## BOTH seams across ONE script, as {count-delta flush-delta}, or the first
## endpoint marker that broke — the same never-a-bare-catch discipline as
## opa_o_count and opa_o_flushes, and the same reason the arithmetic is guarded:
## an expr on `NO-SEAM:{}` raises and collapses the whole section into a single
## UNEXPECTED ERROR line instead of reddening one legible row.
##
## ⚠ NOT two separate opa_o_delta / opa_o_fdelta wrappers around two DIFFERENT
## frames. The claim row O38 makes is about ONE frame — blocks were RENDERED and
## the cache was NOT flushed — and measuring the two halves on different frames
## is exactly the "well, it flushed on the other one" hole. One script, both
## endpoints, read either side of it.
proc opa_o_bfdelta {script} {
  set ca [opa_o_count] ; set fa [opa_o_flushes]
  uplevel #0 $script
  set cb [opa_o_count] ; set fb [opa_o_flushes]
  foreach __v [list $ca $fa $cb $fb] {
    if {![string is integer -strict $__v]} { return $__v }
  }
  return [list [expr {$cb - $ca}] [expr {$fb - $fa}]]
}

## This section's devproc folds in the model AND the hierarchy path as well as
## the instance name — unlike opa_o_devproc, which sees the name only. The three
## things these rows must tell apart are exactly (a) the instance NAME, (b) the
## `model=` token and (c) sim_sch_path, and a devproc blind to any one of them
## cannot produce a row that reds when that input is missed. ⚠ At top level
## `$path` is empty, so this is not a second name builder: it is I1's single one
## (op_annot::devpath -> _lower) fed one more descriptor-supplied input.
proc opa_o_rldevproc {instname model path spiceprefix} {
  return "@m.zz${path}[string tolower $model]_[string tolower $instname]"
}
## Rewrite the ONE reload fixture in place — same absolute path, every time.
## The path never changing is the whole point: a path hash cannot see this.
proc opa_o_mkrl {name model} {
  global lib
  opa_o_mksch [file join $lib o_rl.sch] \
    [list o_rl.sym 0 0 "name=$name model=$model"]
}
## The five-device raw. Device 1's triple is a parameter because O27 rewrites
## the SAME FILE with new numbers and re-annotates: same allocation, same nvars,
## same level, annot_p 0 -> 0.
proc opa_o_mkrlraw {path {a {1e-05 1e-04 1e-06}}} {
  set devs [list [concat {@m.zzzzda_mzza} $a] \
                 {@m.zzzzda_mzzb    2e-05 2e-04 2e-06} \
                 {@m.zzzzdb_mzza    3e-05 3e-04 3e-06} \
                 {@m.zzx1.zzda_mzza 4e-05 4e-04 4e-06} \
                 {@m.zzx2.zzda_mzza 5e-05 5e-04 5e-06}]
  set vecs {} ; set vals {}
  foreach d $devs {
    set nm [lindex $d 0]
    lappend vecs [list "i(${nm}\[zzid\])" current] \
                 [list "${nm}\[zzgm\]"    admittance] \
                 [list "${nm}\[zzgds\]"   admittance]
    lappend vals [lindex $d 1] [lindex $d 2] [lindex $d 3]
  }
  set f [open $path w]
  puts -nonewline $f "Title: S9b invalidation fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: [llength $vecs]
No. Points: 1
Variables:
"
  set k 0
  foreach v $vecs { puts -nonewline $f "\t$k\t[lindex $v 0]\t[lindex $v 1]\n" ; incr k }
  puts -nonewline $f "Values:\n"
  ## ⚠ NOT `puts [expr {$k == 0 ? "0\t$v\n" : "\t$v\n"}]`. Measured: expr does
  ## its OWN substitution pass over a quoted operand, so the \t and \n survive
  ## as literal backslashes AND `1e-04` comes back as `0.0001` — the whole
  ## values block collapses onto one line and ngspice's reader answers
  ## "ascii block is not of correct size", i.e. every row of every check below
  ## blanks for a FIXTURE reason wearing the defect's clothes.
  set k 0
  foreach v $vals {
    if {$k == 0} { puts -nonewline $f "0\t$v\n" } else { puts -nonewline $f "\t$v\n" }
    incr k
  }
  close $f
}

if {[catch {

# ⚠ UNQUALIFIED, per this file's header note.
set XSCHEM_LIBRARY_PATH $S_LIBS

set O_RLRAW [file join $scratch o_rl.raw]
opa_o_mkrlraw $O_RLRAW
opa_o_mkfet $lib o_rl.sym zzs9rl
opa_o_mkrl MZZA zzda
## A 12-line type=subcircuit box, the same shape as this file's own leaf.sym.
## Its schematic is o_leaf.sch, which holds ONE annotatable device — the two
## sibling instances in o_htop.sch therefore differ in nothing a per-file epoch
## can see.
set f [open [file join $lib o_leaf.sym] w]
puts $f {v {xschem version=3.4.6 file_version=1.2}
G {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}}
close $f
opa_o_mksch [file join $lib o_leaf.sch] {o_rl.sym 0 0 {name=MZZA model=zzda}}
opa_o_mksch [file join $lib o_htop.sch] \
  {o_leaf.sym 0 0 {name=x1}  o_leaf.sym 300 0 {name=x2}}

catch {op_annot::register zzs9rl [list devproc opa_o_rldevproc params $O_PARAMS]}

## The six blocks this section's raw can produce. Written out rather than
## computed so a formatter drift reds here instead of agreeing with itself.
set O_RL_A     {{ZZOA = 10u} {ZZOB = 100u} {ZZOC = 1u}}   ;# zzda_mzza
set O_RL_B     {{ZZOA = 20u} {ZZOB = 200u} {ZZOC = 2u}}   ;# zzda_mzzb
set O_RL_C     {{ZZOA = 30u} {ZZOB = 300u} {ZZOC = 3u}}   ;# zzdb_mzza
set O_RL_X1    {{ZZOA = 40u} {ZZOB = 400u} {ZZOC = 4u}}   ;# x1.zzda_mzza
set O_RL_X2    {{ZZOA = 50u} {ZZOB = 500u} {ZZOC = 5u}}   ;# x2.zzda_mzza
set O_RL_NEW   {{ZZOA = 70u} {ZZOB = 700u} {ZZOC = 7u}}   ;# O27's rewrite

# ===========================================================================
# X13 — THE SIBLING FIXTURE. GREEN BEFORE AND AFTER; IT MAKES O25 NON-VACUOUS
# ===========================================================================
# ⚠ THIS ROW MEASURES NOTHING ABOUT THE OVERLAY and must not be read as
# evidence S9 happened. It states the precondition O25 rests on, and it is the
# reason the epoch needs sch_path[currsch] and not just sch[currsch]: descending
# into two SIBLING instances of ONE subcircuit leaves currsch, the loaded FILE,
# the instance count and `modified` bit-identical, while sim_sch_path moves
# `x1.` -> `x2.` and the device path moves @m.zzx1.… -> @m.zzx2.…  Measured on
# this tree today. op_annot::_simpath (op_annot.tcl:278) reads sim_sch_path LIVE
# and its comment says caching it "would pass every golden and silently produce
# the wrong device path the moment the user descends"; a C cache one level up
# re-freezes exactly that.
xschem load [file join $lib o_htop.sch]
set x13r  [rcall {xschem annotate_op $O_RLRAW 0}]
set x13ks $::keep_symbols
set ::keep_symbols 1
xschem select instance 0 ; xschem descend 1 2
set x13a [list [xschem get currsch] [file tail [xschem get schname]] \
               [xschem get instances] [xschem get modified] [op_annot::devpath MZZA]]
xschem go_back
xschem select instance 1 ; xschem descend 1 2
set x13b [list [xschem get currsch] [file tail [xschem get schname]] \
               [xschem get instances] [xschem get modified] [op_annot::devpath MZZA]]
xschem go_back
set ::keep_symbols $x13ks
check {X13 FIXTURE two SIBLING instances of one subcircuit: same currsch/file/count/modified, DIFFERENT devpath} \
  [list [lindex $x13r 0] $x13a $x13b] \
  [list 0 {1 o_leaf.sch 1 0 @m.zzx1.zzda_mzza} {1 o_leaf.sch 1 0 @m.zzx2.zzda_mzza}]

# ===========================================================================
# O21 — ISSUE 0466's LITERAL REPRO, THROUGH THE USER'S OWN BUTTON
# ===========================================================================
# ⚠ COVERED THREE TIMES OVER ON PURPOSE (remove_symbols, then clear_drawing,
# then the per-entry name guard), because this is the PATH A USER TAKES, not a
# mechanism isolator: File > Reload, the FileReload toolbar button and Alt-S all
# end here. Element 4 is op_annot::text's own answer — I1's single formatter —
# so a red element 3 names the CACHE and never the formatter.
opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
set o21r [rcall {xschem annotate_op $O_RLRAW}]
opa_l_annot 1
set o21a [opa_l_print2 svg [file join $scratch o_rl21a.svg] $O_VP]
opa_o_mkrl MZZB zzda
xschem reload
set o21b [opa_l_print2 svg [file join $scratch o_rl21b.svg] $O_VP]
check {O21 issue 0466: a device RENAMED on disk and reloaded renders its OWN number, not its predecessor's} \
  [list [lindex $o21r 0] [opa_o_rowtexts $o21a ZZO] [opa_o_rowtexts $o21b ZZO] \
        [opa_s5_lines [op_annot::text MZZB]]] \
  [list 0 $O_RL_A $O_RL_B $O_RL_B]

# ===========================================================================
# O22 — THE SAME RENAME WITH remove_symbols() OUT OF THE PICTURE
# ===========================================================================
# ⚠ THE ISOLATOR. `xschem reload` purges symbols first, so O21 cannot fail for a
# cache reason alone. `load -keep_symbols` measurably does not: verified on this
# tree with the .sym's type= rewritten on disk, `load -keep_symbols` answers the
# OLD type and a plain `load` answers the new one. Element 4 is the formatter.
opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o22a [opa_l_print2 svg [file join $scratch o_rl22a.svg] $O_VP]
opa_o_mkrl MZZB zzda
xschem load -keep_symbols [file join $lib o_rl.sch]
set o22b [opa_l_print2 svg [file join $scratch o_rl22b.svg] $O_VP]
check {O22 the same rename through `load -keep_symbols`, where remove_symbols never runs} \
  [list [opa_o_rowtexts $o22a ZZO] [opa_o_rowtexts $o22b ZZO] \
        [opa_s5_lines [op_annot::text MZZB]]] \
  [list $O_RL_A $O_RL_B $O_RL_B]

# ===========================================================================
# O23 — THE HALF A PER-INSTANCE NAME GUARD CANNOT SEE
# ===========================================================================
# ⚠ THE ROW THAT SAYS "COMPARE THE NAME" IS NOT THE WHOLE FIX. Same file, same
# path, same instance NAME, same instance COUNT — only `model=` moves, and the
# device path moves with it because it is the descriptor that composes the
# vector. An implementation whose only new guard is `strcmp(cached_name,
# inst.instname)` passes O22 and reds here.
opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o23a [opa_l_print2 svg [file join $scratch o_rl23a.svg] $O_VP]
opa_o_mkrl MZZA zzdb
xschem load -keep_symbols [file join $lib o_rl.sch]
set o23b [opa_l_print2 svg [file join $scratch o_rl23b.svg] $O_VP]
check {O23 the instance NAME unchanged and `model=` rewritten: the value follows the model} \
  [list [opa_o_rowtexts $o23a ZZO] [opa_o_rowtexts $o23b ZZO] \
        [op_annot::devpath MZZA] [opa_s5_lines [op_annot::text MZZA]]] \
  [list $O_RL_A $O_RL_C {@m.zzzzdb_mzza} $O_RL_C]

# ===========================================================================
# O24 — THE CONTROL: A FLUSH MUST NOT FABRICATE A DIFFERENCE
# ===========================================================================
# ⚠ THE OTHER HALF OF EVERY ROW ABOVE. "Invalidate more" is trivially achieved
# by making the render non-deterministic; this row pins that a same-path reload
# with NOTHING changed leaves two exports BYTE-IDENTICAL. Measured: `xschem
# reload` is byte-stable through opa_l_print2, while `load -keep_symbols` is NOT
# (it re-zooms and moves stroke-width), which is why this row reloads and O22/23
# compare row TEXTS rather than bytes.
opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o24a [opa_l_print2 svg [file join $scratch o_rl24a.svg] $O_VP]
xschem reload
set o24b [opa_l_print2 svg [file join $scratch o_rl24b.svg] $O_VP]
check {O24 CONTROL a same-path reload with nothing changed leaves the two exports byte-identical} \
  [list [expr {$o24a eq $o24b}] [opa_o_rowtexts $o24a ZZO]] \
  [list 1 $O_RL_A]

# ===========================================================================
# O25 — TWO SIBLINGS OF ONE SUBCIRCUIT (the sch_path / sch_waves_loaded terms)
# ===========================================================================
# ⚠ NO TOP-LEVEL EXPORT BETWEEN THE TWO DESCENTS, DELIBERATELY. On screen this
# case is correct BY ACCIDENT: go_back runs its own draw() at the top level and
# that intermediate frame is what flushes. Headless there is no intervening
# draw, so this row measures the epoch and not the luck. X13 above states the
# precondition: the two contexts are identical in currsch, file, instance count
# and `modified`.
xschem load [file join $lib o_htop.sch]
rcall {xschem annotate_op $O_RLRAW 0}
set o25ks $::keep_symbols
set ::keep_symbols 1
opa_l_annot 1
xschem select instance 0 ; xschem descend 1 2
set o25a [opa_l_print2 svg [file join $scratch o_rl25a.svg] $O_VP_SOLO]
xschem go_back
xschem select instance 1 ; xschem descend 1 2
set o25b [opa_l_print2 svg [file join $scratch o_rl25b.svg] $O_VP_SOLO]
xschem go_back
set ::keep_symbols $o25ks
check {O25 each SIBLING carries its own number: x1. and x2. are different devices in one file} \
  [list [opa_o_rowtexts $o25a ZZO] [opa_o_rowtexts $o25b ZZO]] \
  [list $O_RL_X1 $O_RL_X2]

# ===========================================================================
# O26 / O28 — THE PROPERTY-SETTER RENAME, AND THE RESTORE PATHS
# ===========================================================================
# ⚠ GREEN UNDER 0466's EPOCH TOO, AND STILL WORTH A ROW. `xschem setprop
# instance` bumps modify_seq at scheduler.c:12377, and `xschem undo` / `redo`
# reach it through in_memory_undo.c:587 / save.c:4868 only because the default
# set_modify argument is 1 — `xschem undo 0 0` and the netlisters'
# pop_undo(2|4|0, 0) do not, and they replace the WHOLE instance array. These
# two rows are the regression guard on the paths that are currently correct for
# a reason nobody wrote down.
opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o28a [opa_l_print2 svg [file join $scratch o_rl28a.svg] $O_VP]
xschem setprop instance MZZA name MZZB
set o28b [opa_l_print2 svg [file join $scratch o_rl28b.svg] $O_VP]
check {O28 `xschem setprop instance … name` moves the block to the new device between two exports} \
  [list [opa_o_rowtexts $o28a ZZO] [opa_o_rowtexts $o28b ZZO] \
        [xschem getprop instance 0 name]] \
  [list $O_RL_A $O_RL_B MZZB]

opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o26a [opa_l_print2 svg [file join $scratch o_rl26a.svg] $O_VP]
xschem setprop instance MZZA name MZZB
set o26b [opa_l_print2 svg [file join $scratch o_rl26b.svg] $O_VP]
xschem undo
set o26c [opa_l_print2 svg [file join $scratch o_rl26c.svg] $O_VP]
xschem redo
set o26d [opa_l_print2 svg [file join $scratch o_rl26d.svg] $O_VP]
check {O26 undo reverts the block to the old device and redo restores the new one} \
  [list [opa_o_rowtexts $o26a ZZO] [opa_o_rowtexts $o26b ZZO] \
        [opa_o_rowtexts $o26c ZZO] [opa_o_rowtexts $o26d ZZO]] \
  [list $O_RL_A $O_RL_B $O_RL_A $O_RL_B]

# ===========================================================================
# O27 — THE SAME RAW FILE, RE-SIMULATED. D4's REAL TEST
# ===========================================================================
# ⚠ O12 ABOVE ONLY COVERS blank -> valued. This is the case D4 was written for
# and the one the user actually hits: re-run the simulator, re-annotate the SAME
# path, and the numbers must move. Same Raw allocation, same nvars, same level,
# annot_p 0 -> 0 — nothing an epoch built from xctx fields alone can see.
opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o27a [opa_l_print2 svg [file join $scratch o_rl27a.svg] $O_VP]
opa_o_mkrlraw $O_RLRAW {7e-05 7e-04 7e-06}
set o27r [rcall {xschem annotate_op $O_RLRAW}]
set o27b [opa_l_print2 svg [file join $scratch o_rl27b.svg] $O_VP]
opa_o_mkrlraw $O_RLRAW
check {O27 the SAME raw path rewritten and re-annotated between two exports CHANGES the numbers} \
  [list [lindex $o27r 0] [opa_o_rowtexts $o27a ZZO] [opa_o_rowtexts $o27b ZZO] \
        [opa_s5_lines [op_annot::text MZZA]]] \
  [list 0 $O_RL_A $O_RL_NEW $O_RL_NEW]

# ===========================================================================
# O29 — THE SHIPPED MENU CHECKBUTTON (hole A, invariant I3)
# ===========================================================================
# ⚠ ISSUE 0864 — THE SAME CHECKBUTTON, THE OPPOSITE CLAIM, AND STILL A CACHE
# ROW. `Live annotate probes with 'b' cursor` (Simulation > Graphs) is a shipped
# checkbutton on `live_cursor2_backannotate` with NO -command. It used to be the
# FIRST gate of op_annot::_annotated, so one click blanked every row of every
# block on the sheet; this row used to assert that the draw-time cache SAW that
# click, because nothing in a 13-field xctx epoch can see a Tcl variable. After
# 0864 the switch means "follow the cursor" and nothing else, so the claim
# inverts: three exports, before / with the box off / with it back on, must be
# BYTE-IDENTICAL and populated.
#
# ⚠ IT IS THE CACHE-LEVEL PIN OF A1, which is why it is not redundant with S16.
# S16 asks op_annot::text; this asks what was PAINTED, through the overlay cache
# and its epoch. A first term restored in either language blanks leg b here
# whether or not the epoch's own live-annotate term comes back with it.
#
# ⚠ NON-VACUOUS BY CONSTRUCTION: the golden is the POPULATED $O_RL_A, so a
# printer that emitted nothing at all fails all four elements.
opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o29lv $::live_cursor2_backannotate
set o29a [opa_l_print2 svg [file join $scratch o_rl29a.svg] $O_VP]
set ::live_cursor2_backannotate 0
set o29b [opa_l_print2 svg [file join $scratch o_rl29b.svg] $O_VP]
set o29t [opa_s5_lines [op_annot::text MZZA]]
set ::live_cursor2_backannotate 1
set o29c [opa_l_print2 svg [file join $scratch o_rl29c.svg] $O_VP]
set ::live_cursor2_backannotate $o29lv
check {O29 toggling the shipped Live-annotate checkbutton no longer changes a single painted row} \
  [list [opa_o_rowtexts $o29a ZZO] [opa_o_rowtexts $o29b ZZO] \
        [opa_o_rowtexts $o29c ZZO] $o29t] \
  [list $O_RL_A $O_RL_A $O_RL_A $O_RL_A]

# ⚠ O29b — MANDATORY, AND INVISIBLE TO EVERY BEHAVIOURAL ROW IN THE TREE. The
# overlay epoch carried a 14th term, `e.live_annot`, for one reason: the switch
# changed what was rendered, so the cache had to flush when it moved. After 0864
# nothing rendered reads the switch, so the term can no longer tell two frames
# apart — it is a flush trigger keyed to an irrelevant variable, and O29 above
# would stay green with it left in. Standing furniture is the defect this branch
# has been warned about twice; this row is the only thing that can see it.
#
# ⚠ THE SLICE STRIPS C COMMENTS, so annot_overlay_sync() may explain at length
# why the term went. Elements 2 and 3 are the positive control: a renamed
# function, or a slicer that returned nothing, must not satisfy element 1.
set o29b_src [opa_c_slice [file join $repo src actions.c] {^void annot_overlay_sync}]
check {O29b the overlay epoch carries no live-annotate term} \
  [list [regexp -all -- {live_cursor2_backannotate} $o29b_src] \
        [expr {[string first {annot_epoch.desc_gen} $o29b_src] >= 0 ? 1 : 0}] \
        [expr {[string first {annot_overlay_flush} $o29b_src] >= 0 ? 1 : 0}]] \
  {0 1 1}

# ===========================================================================
# O30 — A VECTOR RENAMED UNDER A STATIC SCHEMATIC (hole B, invariant I3)
# ===========================================================================
# ⚠ ONE VECTOR, NOT THE WHOLE BLOCK, AND THAT IS THE DISCRIMINATOR. raw_renamevar
# (save.c:1306, `xschem raw rename`) leaves nvars, the Raw pointer, the level and
# annot_p all unmoved. The renamed row must go BLANK — never 0, never NaN, never
# the previous number (I3, save.c RULING D5-1) — while the two untouched rows
# KEEP their values, which is what separates a correct invalidation from a
# cache that simply blanked everything.
opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o30a [opa_l_print2 svg [file join $scratch o_rl30a.svg] $O_VP]
set o30r [rcall {xschem raw rename {i(@m.zzzzda_mzza[zzid])} {i(@m.zzzzda_zzgone[zzid])}}]
set o30b [opa_l_print2 svg [file join $scratch o_rl30b.svg] $O_VP]
check {O30 I3 a raw vector renamed under a static schematic blanks ONLY its own row} \
  [list [lindex $o30r 0] [opa_o_rowtexts $o30a ZZO] [opa_o_rowtexts $o30b ZZO] \
        [opa_s5_lines [op_annot::text MZZA]]] \
  [list 0 $O_RL_A {{ZZOA =} {ZZOB = 100u} {ZZOC = 1u}} {{ZZOA =} {ZZOB = 100u} {ZZOC = 1u}}]

# ===========================================================================
# O37 — TWO OP DATABASES LOADED AT ONCE, SWITCHED UNDER A STATIC SCHEMATIC
# ===========================================================================
# ⚠ THE STEP BRIEF NAMED THIS PATH BY HAND — "a raw switched under a static
# schematic" — and no row above reaches it. O27 re-reads the SAME file into the
# SAME registry slot; this one holds TWO databases at once and moves the CURRENT
# pointer between them, which is what `xschem raw switch` and the Waves menu do.
# Nothing about the schematic moves: same file, same instance, same instance
# count, same `modified`, same sim_sch_path, same descriptor.
#
# ⚠ IT CANNOT BE DRIVEN WITH annotate_op, AND THAT IS NOT A FIXTURE QUIRK.
# `xschem annotate_op` DELETES the currently loaded operating point before it
# reads (scheduler.c:2409, extra_rawfile(3, ...)), so two OP raws can never be
# resident at once through that door. `xschem raw read <f> op` is the door that
# leaves both — measured on this tree, `xschem raw info` afterwards lists both
# files with the second marked current.
#
# ⚠ AND `raw read` DELIBERATELY LEAVES A BLANK LEG IN THE MIDDLE, WHICH IS I3.
# Measured: extra_rawfile(what=1) makes the new database CURRENT but publishes
# no annotation point, so `xschem raw annot` answers -1 and op_annot::_annotated
# (op_annot.tcl:561) gates every row to blank. `raw switch` then calls update_op()
# (scheduler.c:10266) and the numbers appear. That middle export is the sharpest
# leg of the row: the truth there is BLANK while the cache is holding the FIRST
# database's numbers, so an overlay that misses it prints the previous run's
# number — I3's forbidden case, arriving from the Waves menu instead of from a
# reload.
#
# ⚠ WHAT ACTUALLY CATCHES THIS, SAID HONESTLY: the epoch's `xctx->raw` POINTER
# term, not the update_op() bump. Every leg here swaps xctx->raw to a different
# allocation. O27 is the row that covers the bump (same allocation, new numbers)
# and this row is the regression guard on the pointer term and on the
# `allpoints == 1 && op|dc` condition the switch arm's update_op() call carries.
# Element 5 is op_annot::text's own answer, so a red element 4 names the CACHE.
opa_o_mkrl MZZA zzda
set O_RLRAW2 [file join $scratch o_rl37.raw]
opa_o_mkrlraw $O_RLRAW2 {7e-05 7e-04 7e-06}
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o37a [opa_l_print2 svg [file join $scratch o_rl37a.svg] $O_VP]
set o37r1 [rcall {xschem raw read $O_RLRAW2 op}]
set o37b [opa_l_print2 svg [file join $scratch o_rl37b.svg] $O_VP]
set o37r2 [rcall {xschem raw switch $O_RLRAW2 op}]
set o37c [opa_l_print2 svg [file join $scratch o_rl37c.svg] $O_VP]
set o37r3 [rcall {xschem raw switch $O_RLRAW op}]
set o37d [opa_l_print2 svg [file join $scratch o_rl37d.svg] $O_VP]
set o37t [opa_s5_lines [op_annot::text MZZA]]
## The second database must not outlive the row: every later row reaches its
## raw through `annotate_op`, which deletes only the CURRENT database, and a
## stranded entry would make a later read find-and-switch instead of read.
rcall {xschem raw clear}
check {O37 two OP databases loaded at once: `raw switch` under a STATIC schematic moves the numbers BOTH ways} \
  [list [lindex $o37r1 1] [lindex $o37r2 1] [lindex $o37r3 1] \
        [opa_o_rowtexts $o37a ZZO] [opa_o_rowtexts $o37b ZZO] \
        [opa_o_rowtexts $o37c ZZO] [opa_o_rowtexts $o37d ZZO] $o37t] \
  [list 1 1 1 $O_RL_A {{ZZOA =} {ZZOB =} {ZZOC =}} $O_RL_NEW $O_RL_A $O_RL_A]

# ===========================================================================
# O31 — `xschem reload_symbols` AFTER A type= CHANGE (hole C)
# ===========================================================================
# ⚠ ZERO set_modify CALLS ON THIS PATH. scheduler.c:10827 is remove_symbols() +
# link_symbols_to_instances(-1), and actions.c's remove_symbols contains no
# set_modify at all. Rewrite the .sym's `type=` to something no descriptor
# claims and the whole block must DISAPPEAR — op_annot::text returns {} (not a
# blank block: the two empty outcomes are different and both load-bearing, see
# op_annot.tcl's contract) — so the count of ZZO lines goes to zero.
opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o31a [opa_l_print2 svg [file join $scratch o_rl31a.svg] $O_VP]
opa_o_mkfet $lib o_rl.sym zzs9nobodyclaims
xschem reload_symbols
set o31b [opa_l_print2 svg [file join $scratch o_rl31b.svg] $O_VP]
set o31t [op_annot::text MZZA]
opa_o_mkfet $lib o_rl.sym zzs9rl
xschem reload_symbols
set o31c [opa_l_print2 svg [file join $scratch o_rl31c.svg] $O_VP]
check {O31 a symbol `type=` changed on disk and reload_symbols'd removes the block entirely} \
  [list [opa_o_nseen $o31a ZZO] [opa_o_nseen $o31b ZZO] [opa_o_nseen $o31c ZZO] $o31t] \
  [list 3 0 3 {}]

# ===========================================================================
# O32..O35 — THE FLUSH SEAM. THE ONLY THING THAT CAN SEE A DELETED CACHE
# ===========================================================================
# ⚠ EVERY DELTA HERE WRAPS ITS OWN INVALIDATING CALL, so the goldens are the
# same headless and on a display — see this section's header. And ⚠ ONE DEVICE
# PER SHEET, so a per-block counter and a per-frame counter cannot be confused.
opa_o_mkrl MZZA zzda
opa_l_annot 1
set o32 [opa_o_fdelta {
  xschem load -keep_symbols [file join $lib o_rl.sch]
  opa_l_print svg [file join $scratch o_rl32.svg] $O_VP
}]
check {O32 SEAM `load -keep_symbols` of the same path flushes the cache exactly ONCE} $o32 1

## ⚠ THE ONLY HEADLESS HANDLE ON editprop.c:1263. apply_symbol_prop does
## `set_modify(-2); draw();` and its caller apply_instance_properties bumps at
## editprop.c:1289 — AFTER that draw — so the property form's Apply button
## paints one frame from the stale cache and nothing redraws again. mod -2 does
## not move modify_seq (actions.c:200) but IS in set_modify's floater-cache
## block (actions.c:238), which is the codebase's own "my rendered caches are
## stale" signal and the contract this cache should always have had.
set o33 [opa_o_fdelta {
  xschem set_modify -2
  opa_l_print svg [file join $scratch o_rl33.svg] $O_VP
}]
check {O33 SEAM `set_modify -2`, the mode modify_seq cannot see, still flushes the cache} $o33 1

## ⚠ THE ROW THAT PROVES A CACHE STILL EXISTS. Without it every staleness row in
## this section is satisfied by flushing on every frame — i.e. by deleting the
## cache, which is exactly the per-frame cost the cache was added to avoid.
set o34a [opa_o_fdelta {
  xschem load -keep_symbols [file join $lib o_rl.sch]
  opa_l_print svg [file join $scratch o_rl34a.svg] $O_VP
}]
set o34b [opa_o_fdelta {opa_l_print svg [file join $scratch o_rl34b.svg] $O_VP}]
check {O34 SEAM CONTROL two identical consecutive exports flush ONCE and then NOT AT ALL} \
  [list $o34a $o34b] {1 0}

## ⚠ THE MASK-CLOSED COST CLAIM, ON BOTH SEAMS AT ONCE. With annot_show 0 a
## repeated export must build no block and flush no cache: the feature costs
## nothing when it is off.
opa_l_annot 0
opa_l_print svg [file join $scratch o_rl35s.svg] $O_VP
set o35c [opa_o_delta  {opa_l_print svg [file join $scratch o_rl35a.svg] $O_VP}]
set o35f [opa_o_fdelta {opa_l_print svg [file join $scratch o_rl35b.svg] $O_VP}]
check {O35 SEAM CONTROL at mask 0 a repeated export moves NEITHER seam} \
  [list $o35c $o35f] {0 0}

set XSCHEM_LIBRARY_PATH $S_LIBS
opa_l_annot 0

} ocerr]} {
  puts "UNEXPECTED ERROR (section O cont): $ocerr"
  incr fail
}

# =============================================================================
# SECTION O2 — THE SCREEN CALL SITE, WHICH NEEDS A DISPLAY
# =============================================================================
# draw()'s entire body is inside `if(has_x)` (draw.c:10377) and `xschem redraw`
# is a no-op under --nogui, so this is the ONLY automated proof that the draw.c
# call site exists at all: sabotage could delete it and every row above would
# stay green. O38 adds the second screen claim — that between two frames the
# cache is not thrown away — which is likewise unreachable headless. Both
# self-skip, exactly like M1/M2:
#
#   DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog \
#       --script tests/headless/test_op_annot.tcl
#
# ⚠ `--pipe` IS MANDATORY THERE AND ITS ABSENCE IS SILENT — see section M.
if {![info exists has_x]} {
  puts "skip: O14/O36/O38 need a display — draw()'s whole body is inside `if(has_x)` (draw.c:10377), and `new_schematic create_window` is a Tk call"
} else {
 if {[catch {

set XSCHEM_LIBRARY_PATH $S_LIBS
xschem load [file join $lib o_main.sch]
opa_l_annot 1
set o14a [opa_o_delta {xschem redraw}]
opa_l_annot 0
set o14b [opa_o_delta {xschem redraw}]
## ⚠ THE TEXTS-FREE SYMBOL IS THE POINT. o_fet.sym carries no T record, so an
## overlay hung inside draw_symbol() under draw.c:10500's
## `((c == cadlayers-1) && symptr->texts)` guard renders in SVG and PS (O1/O3
## green) and NOT here. Decision D3 puts the call in the instance loop instead.
## ⚠ AND THE GOLDEN IS EXACTLY 2, NOT "at least 2", ON PURPOSE. Two devices,
## one frame, one block each. A 4 here is not a harmless surplus: hilight.c:4200
## calls the same layer `cadlayers-1` text pass a SECOND time for every
## highlighted instance, so a block built twice per frame is the named
## PERFORMANCE risk arriving quietly — the uncached sweep already costs
## +20..35% of a frame with the annotation gate closed and +66..100% with a raw
## loaded. Read a 4 as "the overlay is on two code paths", not as a test nit.
check {O14 one screen redraw bumps the seam once per block at mask 1 and not at all at mask 0} \
  [list $o14a $o14b] {2 0}
opa_l_annot 0

# ===========================================================================
# O38 — THE STEADY-STATE SCREEN FRAME: THE CACHE MUST SURVIVE A REDRAW
# ===========================================================================
# ⚠ O34's COUNTERPART ON THE ONLY BACK END A USER LOOKS AT. O34 proves a cache
# still exists across two identical EXPORTS; nothing above proves it across two
# consecutive SCREEN FRAMES, and the screen is where the cost is paid — a
# redraw runs on every pan, zoom, selection and cursor drag, while an export
# runs when the user asks for one.
#
# ⚠ WITHOUT THIS ROW THE PERF CLAIM IS UNGUARDED ON EXACTLY THE PATH IT IS
# ABOUT. Every staleness row in section O (cont) is satisfied by an
# implementation that flushes on every frame — i.e. by deleting the cache —
# and the measured price of that is the whole reason the cache exists: an
# uncached sweep costs +20..35% of a frame with the annotation gate CLOSED and
# +66..100% with a raw loaded. A flush-every-frame overlay reds O34 and O35 on
# the export path only; this row is the screen half, and draw()'s whole body is
# inside `if(has_x)` (draw.c:10377), so no headless row can reach it.
#
# ⚠ BOTH SEAMS ON THE SAME FRAME, NOT ONE SEAM ON EACH — see opa_o_bfdelta.
# `{1 0}` is the whole claim in two numbers: the block WAS rendered (count +1,
# one device on this sheet) and the cache was NOT thrown away (flushes +0). The
# count half is the non-vacuity guard: a `{0 0}` would also satisfy "nothing
# flushed", and it is what an overlay whose screen call site was deleted
# answers — which is precisely the sabotage attempt 1 shipped past.
#
# ⚠ THE FIRST FRAME IS DELIBERATELY THROWN AWAY. The load and the annotate_op
# ahead of it legitimately invalidate, so the frame that absorbs their flush is
# not the frame this row is about. Both MEASURED frames are steady-state.
#
# ⚠ NOT REPLAYABLE AGAINST S6's CARRIER, unlike O21-O31/O36. Like O32-O35 it
# reads a seam that does not exist yet, so it was reasoned from the counter's
# contract (one bump per rendered block per frame, actions.c get_annot_overlay)
# rather than measured green in advance. Say so rather than implying it was.
opa_o_mkrl MZZA zzda
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
xschem redraw
set o38a [opa_o_bfdelta {xschem redraw}]
set o38b [opa_o_bfdelta {xschem redraw}]
check {O38 two consecutive steady-state screen redraws each RENDER the block and flush the cache NEITHER time} \
  [list $o38a $o38b] {{1 0} {1 0}}
opa_l_annot 0

# ===========================================================================
# O36 — A TAB / WINDOW SWITCH, IN BOTH DIRECTIONS (issue 0464 residuals 3+4)
# ===========================================================================
# ⚠ THE EPOCH'S `ctx` FIELD IS A FREED POINTER COMPARED BY VALUE. Each open
# window/tab owns its own Xschem_ctx and `xctx = save_xctx[i]` (xinit.c:1731)
# moves the pointer, so a switch is seen today only because the ADDRESS
# happens to differ — a destroyed-and-recreated context can land on the same
# address, and nothing frees the final cache at teardown. Hence: both
# directions, and each export must carry its OWN sheet's numbers.
# ⚠ NEEDS A DISPLAY, which is why it lives here: `new_schematic create_window`
# is a Tk operation. Measured satisfiable under xvfb with S6's carrier standing
# where S9's overlay will be — all four legs, mask 1 surviving every switch.
set o36ks $::keep_symbols
opa_o_mkrl MZZA zzda
opa_o_mksch [file join $lib o_rl2.sch] {o_rl.sym 0 0 {name=MZZB model=zzda}}
xschem load [file join $lib o_rl.sch]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o36a [opa_o_rowtexts [opa_l_print2 svg [file join $scratch o_w36a.svg] $O_VP] ZZO]
set o36r [rcall {xschem new_schematic create_window .xo9 [file join $lib o_rl2.sch]}]
rcall {xschem annotate_op $O_RLRAW}
opa_l_annot 1
set o36b [opa_o_rowtexts [opa_l_print2 svg [file join $scratch o_w36b.svg] $O_VP] ZZO]
rcall {xschem new_schematic switch .drw}
set o36c [opa_o_rowtexts [opa_l_print2 svg [file join $scratch o_w36c.svg] $O_VP] ZZO]
rcall {xschem new_schematic switch .xo9.drw}
set o36d [opa_o_rowtexts [opa_l_print2 svg [file join $scratch o_w36d.svg] $O_VP] ZZO]
rcall {xschem new_schematic switch .drw}
catch {xschem new_schematic destroy .xo9.drw}
set ::keep_symbols $o36ks
check {O36 a window switch renders each sheet's OWN block, in both directions} \
  [list [lindex $o36r 0] $o36a $o36b $o36c $o36d] \
  [list 0 $O_RL_A $O_RL_B $O_RL_A $O_RL_B]
opa_l_annot 0

} o2err]} {
   puts "UNEXPECTED ERROR (section O2): $o2err"
   incr fail
 }
}

# =============================================================================
# SECTION Q — S10 of doc/claude/specs/op_annotation.md: THE PER-PDK SYMBOL
#             TEXT CLEANUP (sky130), AND THE DEDUPLICATION IT OWES
# =============================================================================
# S10 marks the annotation texts the 40 shipped sky130_fd_pr FET symbols have
# always carried — `id=`, `gm=` and the ONE two-line record holding `vgs=` and
# `vds=` — `hide=true`, so that the S9b draw-time overlay becomes the single
# source of those numbers and the double-printing measured at annot_show 1 goes
# away. The plan asked for the S7 class token `hide=op`; it was implemented,
# measured, and refuted — see the ruling table below.
#
# THE MEASURED INVENTORY (this tree, today). It is not the one the step brief
# assumed, so the goldens below are counted, not quoted:
#   * 40 files under sky130A/xschem_libs/sky130_fd_pr/*/symbol/*.sym, out of 77
#     in that library and 724 .sym in all of sky130A.
#   * 119 T records, NOT 160: `vgs=` and `vds=` share ONE record that spans two
#     lines, with its attribute group at the end of the SECOND line. 39 files
#     carry 3 records; nfet_20v0_iso carries 2 (it has no vgs/vds record).
#   * their attribute tails are exactly 40 x {layer=17} (the id records) and
#     79 x {layer=15} (40 gm + 39 vgs/vds) — summing to 119, which is what makes
#     an attribute-tail anchor provably unambiguous in that tree.
#   * the ONLY pre-existing hide= token in all 724 sky130A .sym files is one
#     unrelated `hide=instance` in sky130_tests/diff_amp/symbol/diff_amp.sym:35.
#   * gf180 is untouched by S10: 19 files x 2 texts = 38 records, ALL already
#     `hide=true`. Row Q8 is the file-level tripwire for that, and row L22 is its
#     render-level companion — L22 is the tree's ONLY non-vacuous fixture for the
#     hide=true half of invariant I7, so converting those 38 records would
#     destroy the guard and the thing it guards in one edit.
#
# ============================================================================
# ⚠ THE TOKEN IS `hide=true`, NOT `hide=op`, AND THAT RULING IS THIS TABLE
# ============================================================================
# The step plan asked for the S7 class token `hide=op`. It was implemented,
# measured on all 40 shipped files, and REFUTED -- it does not deduplicate.
# text_hidden() (actions.c:1194) gates a hide=op TEXT on annot_show bit0:
#     if(flags & HIDE_TEXT_OP) return (xctx->annot_show & ANNOT_SHOW_OP) ? 0 : 1;
# and get_annot_overlay() (actions.c:1475) gates the WHOLE overlay on the SAME
# bit:
#     if(text_hidden(HIDE_TEXT_OP, TEXT_CTX_INSTANCE)) return 0;  /* D2 */
# So a symbol text tokened `hide=op` becomes visible EXACTLY when the overlay
# that is supposed to replace it becomes visible. Measured on this tree, on the
# real 40 files, 10 FETs in Q_VP, sky130_procs.tcl sourced (sym = the four
# symbol spellings, ovl = the overlay's rows):
#
#   token       mask0 sht0    mask1 sht0        mask3 sht0      mask0 sht1     mask1 sht1
#   ---------   -----------   ---------------   -------------   ------------   -------------
#   (shipped)   sym10 ovl 0   sym10 ovl10 (!)   sym10 ovl10     sym10 ovl 0    sym10 ovl10
#   hide=op     sym 0 ovl 0   sym10 ovl10 (!)   sym10 ovl10     sym 0 ovl 0    sym10 ovl10
#   hide=true   sym 0 ovl 0   sym 0 ovl10       sym 0 ovl10     sym10 ovl 0    sym10 ovl10
#
# i.e. hide=op removes the double-printing ONLY at the mask where NOTHING is
# drawn at all, and leaves it intact at exactly the two masks where the step
# says it must go away. hide=true removes it at both.
#
# THE RULING (ladder L1, invariant I1 -- "ONE name builder, TWO consumers; never
# two independent builders, because when they drift the failure is SILENT"). The
# symbol's own text is a THIRD, independent builder of the same vector names --
# D8's own header says so, and issue 0428 is that drift already realised, one
# shipped symbol whose builder disagrees with the other 39 and has always
# rendered blank. I1 is satisfied only by the row of this table in which the two
# builders are never both painting: `hide=true`.
#
# SECOND GROUND (ladder L2, least surprising / smallest blast radius): hide=true
# is the spelling gf180 ALREADY SHIPS for exactly this content
# (gf180mcu_pr/nfet_03v3/symbol/nfet_03v3.sym:64-70, `{layer=15\nhide=true}`), so
# after S10 the two PDKs behave alike instead of three ways; it is data-only, so
# no C moves and section L's S7/S9b goldens stay put; and it leaves the legacy
# numbers one stock menu item away (View > Show hidden texts, xschem.tcl:15050)
# for the user whose rc never sources sky130_procs.tcl and who therefore gets no
# overlay at any mask. That escape hatch is row Q7, and it materially softens the
# ledger's E question rather than answering it.
#
# REJECTED: (a) `hide=op` as planned -- measured above, does not deliver the step.
# (b) changing text_hidden()/get_annot_overlay() so the class means "superseded BY
# the overlay" -- that is real C surgery outside a step declared ZERO LOGIC, it
# would move section L's goldens, and S7 decision D3 (classes ahead of
# show_hidden_texts) was ratified deliberately. Q1/Q2/Q7 below are the rows that
# MOVED to record this ruling; none was silenced, and Q7 still discriminates the
# two tokens -- it simply now reds if someone writes hide=op.
#
# ⚠ KNOWN GAP, MEASURED AND NOT COVERED BY ANY ROW BELOW: the bottom-right cell
# of the table above. At annot_show 1 WITH show_hidden_texts 1 the duplication
# returns in full -- measured with a real raw, `id=12.34u` AND `id    = 12.34u`
# on the same device -- so the ruling's phrase "the two builders are never both
# painting" is false in that one state. hide=true is still strictly better than
# hide=op, which double-paints in the COMMON case (mask 1, sht 0), and Q7 below
# exercises mask 0 + sht 1 only. Whoever closes this should ADD the mask1+sht1
# cell, not re-litigate the token. Issue 0475 section 11 item 1.
#
# ⚠ SECOND KNOWN GAP: every row below uses ONE fixture at ONE viewport. Nothing
# here exercises a cell name that does NOT match the descriptor's
# `match {*sky130_fd_pr/*}` -- and op_annot::_matches tests that against
# cell::name, not the file's location, so a vendored or aliased copy of an edited
# symbol is silent at EVERY mask even with sky130_procs.tcl sourced. That is the
# widened form of the ledger's E question. Issue 0475 section 11 item 2.
#
# ⚠ THE VIEWPORT COUNT 10 IS A GOLDEN, NOT A SHAPE. The shipped 17-FET
# sky130_tests_ase/test_nmos schematic puts exactly 10 sky130_fd_pr FETs inside
# Q_VP, and each carries all four texts. A count that drifts off 10 means the
# fixture moved or the overlay stopped covering every device — both worth a red.

set Q_SCH  [file join $repo sky130A xschem_libs sky130_tests_ase test_nmos \
                      schematic test_nmos.sch]
set Q_SKYROOT [file join $repo sky130A]
set Q_FDPR    [file join $repo sky130A xschem_libs sky130_fd_pr]
set Q_GFPR    [file join $repo gf180mcuD xschem_libs gf180mcu_pr]
## Viewport for the 10-argument `xschem print` form: {w h x1 y1 x2 y2}.
set Q_VP   {1800 1200 100 -700 1800 -100}

## The three annotation records, matched WHOLE and anchored on BOTH the text
## group's prefix and the record's attribute group. `[^\}]*` crosses newlines,
## which is what lets the ONE two-line vgs/vds record be matched as one record;
## `[^\{]*` is the geometry, which never contains a brace. The capture is the
## ATTRIBUTE group, so this scanner reads the same bytes before and after the
## edit — a per-line pass could not (issue: the vgs record's attribute group
## lives at the end of its SECOND line).
set ::Q_RE(id)  {\nT \{id=@spice_get_node[^\}]*\}[^\{]*\{([^\}]*)\}}
set ::Q_RE(gm)  {\nT \{gm=@spice_get_node[^\}]*\}[^\{]*\{([^\}]*)\}}
set ::Q_RE(vgs) {\nT \{vgs=expr\([^\}]*\}[^\{]*\{([^\}]*)\}}

## -> flat list of {basename kind attrgroup} for every annotation record in the
## sky130_fd_pr symbol tree. NEVER raises: a tree that lost its symbols must red
## one row, not abort the section.
proc opa_q_records {} {
  global Q_FDPR
  set out {}
  foreach f [lsort [glob -nocomplain [file join $Q_FDPR * symbol *.sym]]] {
    if {[catch {open $f r} fd]} continue
    set t \n[read $fd] ; close $fd
    foreach k {id gm vgs} {
      foreach {whole attr} [regexp -all -inline $::Q_RE($k) $t] {
        lappend out [list [file tail $f] $k $attr]
      }
    }
  }
  return $out
}
## An attribute group is a whitespace/newline separated token list — `get_tok_value`
## treats `{layer=17 hide=op}` and `{layer=17\nhide=op}` alike, so the scan must too.
proc opa_q_attrtok {attr} { return [split [string map [list \n { } \t { }] $attr] { }] }

## -> {nid ngm nvgs total} counting only records whose ATTRIBUTE group carries
## the token asked for.
proc opa_q_class {tok} {
  array set n {id 0 gm 0 vgs 0}
  foreach r [opa_q_records] {
    lassign $r f k attr
    if {[lsearch -exact [opa_q_attrtok $attr] $tok] >= 0} { incr n($k) }
  }
  return [list $n(id) $n(gm) $n(vgs) [expr {$n(id) + $n(gm) + $n(vgs)}]]
}
## The busiest attribute group: how many hide= tokens the most-decorated
## annotation record carries. 0 before S10, 1 after, 2 if the editing script ran
## twice or was not idempotent.
proc opa_q_maxhide {} {
  set mx 0
  foreach r [opa_q_records] {
    set c 0
    foreach t [opa_q_attrtok [lindex $r 2]] { if {[string match hide=* $t]} { incr c } }
    if {$c > $mx} { set mx $c }
  }
  return $mx
}
## Every *.sym under <root>, recursively.
proc opa_q_symfiles {root} {
  set out {}
  foreach f [lsort [glob -nocomplain -directory $root *]] {
    if {[file isdirectory $f]} {
      foreach g [opa_q_symfiles $f] { lappend out $g }
    } elseif {[string match *.sym $f]} { lappend out $f }
  }
  return $out
}
## -> {nop ninstance ntrue nvoltage nother} over every *.sym below <root>.
## A FULL census, not a spot check: a stray token landing on an unrelated record
## has to show up somewhere, and this is the somewhere.
proc opa_q_hideinv {root} {
  array set n {op 0 instance 0 true 0 voltage 0 other 0}
  foreach f [opa_q_symfiles $root] {
    if {[catch {open $f r} fd]} continue
    set d [read $fd] ; close $fd
    foreach m [regexp -all -inline {hide=[A-Za-z0-9_]+} $d] {
      set v [string range $m 5 end]
      if {[info exists n($v)]} { incr n($v) } else { incr n(other) }
    }
  }
  return [list $n(op) $n(instance) $n(true) $n(voltage) $n(other)]
}

## The RENDERED text of an SVG export, as a list of strings. Both the symbol
## texts and the overlay rows are plain `>...</text>` nodes and xschem writes no
## structural `id="..."` attribute, so a prefix match on a text NODE is exact
## where a raw `regexp id=` on the file would not be.
proc opa_q_texts {s} {
  set o {}
  foreach m [regexp -all -inline {>[^<]*</text>} $s] { lappend o [string range $m 1 end-7] }
  return $o
}
proc opa_q_n {s pfx} {
  set n 0
  foreach t [opa_q_texts $s] { if {[string first $pfx $t] == 0} { incr n } }
  return $n
}
## The four SYMBOL spellings, in order. `id=` cannot match the overlay's
## `id    =`, and `gm=` cannot match either `gm    =` or `gm/id =`, because the
## match is anchored at the start of the text node.
proc opa_q_sym {s} {
  set o {} ; foreach p {id= gm= vgs= vds=} { lappend o [opa_q_n $s $p] } ; return $o
}
## The OVERLAY spellings, padded to the 5-wide label column S5 builds.
## ⚠ THE PADDING CHANGED WITH RULING D9 AND IT IS PART OF THE PROBE. The label
## column pads to the longest label IN THE BLOCK: pre-D9 that was 5 (`vdsat`,
## `gm/id`) and the probes read `id    =`; the six are id gm gds vgs vth vds, so
## the longest is 3 and the probes read `id  =`. A probe left at the old width
## matches nothing and the rows below go silently green at zero.
proc opa_q_ovl {s} {
  set o {}
  foreach p [list {id  =} {gm  =} {gds =} {vgs =} {vth =} {vds =}] {
    lappend o [opa_q_n $s $p]
  }
  return $o
}

if {[catch {

set XSCHEM_LIBRARY_PATH $P_SKY_LIBS
opa_source [file join $repo sky130A sky130_procs.tcl]
xschem load $Q_SCH

# ===========================================================================
# Q0 — CONTROL: the fixture is the one the goldens were counted on
# ===========================================================================
# ⚠ WITHOUT THIS ROW EVERY ROW BELOW DEGRADES INTO A HOLLOW PASS. A schematic
# that failed to load, or a sky130 descriptor an earlier section left overridden
# with a probe, would make the overlay counts 0 and the symbol counts 0 — which
# is precisely the shape Q3/Q4/Q6/Q7 are asking for. This row is green before
# and after S10 by design; it exists so a broken fixture reds ONE legible row.
set q_ndev [llength [opa_q_records]]
check {Q0 CONTROL the fixture loads, the sky130 nmos descriptor is live, and the 40-symbol corpus is present} \
  [list [expr {[file tail [xschem get schname]] eq {test_nmos.sch}}] \
        [expr {[op_annot::descriptor nmos] ne {}}] \
        $q_ndev] {1 1 119}

# ===========================================================================
# Q1 — THE INVENTORY: 119 records, every one of them classed
# ===========================================================================
# ⚠ THE SPLIT {40 40 39} IS THE ASSERTION, NOT THE TOTAL. A script that walked
# lines instead of records would either double-add on the vgs/vds pair (giving
# 40/40/78) or miss it entirely (40/40/0); a script that assumed 3 records in
# every file would trip over nfet_20v0_iso, which has 2.
# The trailing 0 is the REJECTED token, pinned: the plan asked for hide=op and
# the table above refutes it, so a later pass that "restores the plan" reds here
# as well as at Q4/Q6.
check {Q1 S10 INVENTORY: all 119 sky130_fd_pr annotation records carry hide=true, split 40 id / 40 gm / 39 vgs+vds, and none carries hide=op} \
  [concat [opa_q_class hide=true] [lindex [opa_q_class hide=op] 3]] {40 40 39 119 0}

# ===========================================================================
# Q2 — NO COLLATERAL, NO DOUBLE-ADD: the whole sky130A hide= census
# ===========================================================================
# The last term is the busiest attribute group. It is 0 today, must be 1 after
# S10, and is 2 if the editing script is not idempotent — which is the one
# failure mode a per-file record count cannot see.
check {Q2 NO COLLATERAL: the sky130A hide= census is 0 op / 1 instance / 119 true / 0 voltage, at most one token per record} \
  [concat [opa_q_hideinv $Q_SKYROOT] [list [opa_q_maxhide]]] {0 1 119 0 0 1}

# ===========================================================================
# Q8 — gf180 UNTOUCHED: the file-level half of invariant I7
# ===========================================================================
# ⚠ GREEN BEFORE S10 AND IT MUST STAY GREEN. This is a tripwire, not a claim
# about S10: the step plan's own S10 section asks for gf180's 19 symbols to be
# converted too, and I7 forbids it. Its render-level companion is L22.
set q_gf [opa_q_hideinv $Q_GFPR]
set q_gfn 0
foreach f [opa_q_symfiles $Q_GFPR] {
  set fd [open $f r] ; set d [read $fd] ; close $fd
  if {[string first hide=true $d] >= 0} { incr q_gfn }
}
check {Q8 I7 TRIPWIRE: gf180mcu_pr still holds 38 hide=true records in 19 files and no hide=op} \
  [list [lindex $q_gf 2] [lindex $q_gf 0] $q_gfn] {38 0 19}

# ===========================================================================
# Q3 — MASK 0: THE RESTING SCHEMATIC
# ===========================================================================
# ⚠ THIS ROW IS THE STEP'S USER-VISIBLE CHANGE, STATED AS A NUMBER. Today the
# four texts render at EVERY mask (measured: byte-identical exports at
# annot_show 0, 1 and 3 as far as they are concerned) because they carry no
# hide= token at all and answer to no knob. After S10 they are hidden, and a
# stock schematic gets emptier — that is decision D9 and the ledger's E
# question, not a regression to hide. What the user keeps is row Q7's escape
# hatch; what the user gains, once the PDK procs are sourced, is Q4's superset.
opa_l_annot 0 ; opa_l_sht 0
set q_s0 [opa_l_print2 svg [file join $scratch q_00.svg] $Q_VP]
check {Q3 MASK 0: the four shipped sky130 symbol texts are gone from a resting export} \
  [opa_q_sym $q_s0] {0 0 0 0}

# ===========================================================================
# Q4 — MASK 1: THE DEDUPLICATION, WHICH IS THE WHOLE POINT OF S10
# ===========================================================================
# ⚠ THE ROW THE STEP EXISTS FOR, AND THE ONE THIS FILE PREDICTS hide=op CANNOT
# SATISFY — see this section's header table. Today each of id/gm/vgs/vds is
# painted TWICE on every FET: once by the symbol's own text and once by the
# overlay row. The overlay's rows are a strict SUPERSET of the shipped four —
# still true under ruling D9, whose six are id gm gds vgs vth vds against the
# symbols' id/gm/vgs/vds — so the symbol's copy is the one that must go.
opa_l_annot 1
set q_s1 [opa_l_print2 svg [file join $scratch q_10.svg] $Q_VP]
check {Q4 MASK 1: each label is painted ONCE per FET -- the symbol texts are gone and the overlay covers all 10 devices} \
  [concat [list [opa_q_sym $q_s1]] [lrange [opa_q_ovl $q_s1] 0 2]] \
  {{0 0 0 0} 10 10 10}

# ===========================================================================
# Q5 — NON-VACUITY
# ===========================================================================
# ⚠ WITHOUT THIS ROW Q3/Q4/Q6/Q7 WOULD ALL PASS ON AN EXPORTER THAT DREW
# NOTHING. Green before and after S10, deliberately.
check {Q5 NON-VACUITY: the mask-1 export is strictly longer than the mask-0 one and carries the overlay-only rows} \
  [concat [list [expr {[string length $q_s1] > [string length $q_s0]}]] \
          [lrange [opa_q_ovl $q_s1] 3 5]] {1 10 10 10}

# ===========================================================================
# Q6 — MASK 3: THE hide=voltage TRAP, MADE EXECUTABLE
# ===========================================================================
# ⚠ WHY A SEPARATE MASK. `vgs` and `vds` ARE node voltages, so hide=voltage
# looks like the tidier token for that one record — but get_annot_overlay gates
# the WHOLE block, vgs and vds rows included, on bit0 alone (actions.c:1475,
# decision D2). Tokening them hide=voltage therefore restores the duplication at
# mask 3 and nowhere else, i.e. at exactly the state nobody would think to test.
opa_l_annot 3
set q_s3 [opa_l_print2 svg [file join $scratch q_30.svg] $Q_VP]
check {Q6 MASK 3: turning the voltage class on as well does not bring the symbol texts back} \
  [opa_q_sym $q_s3] {0 0 0 0}

# ===========================================================================
# Q7 — THE ESCAPE HATCH, AND THE hide=op / hide=true DISCRIMINATOR
# ===========================================================================
# ⚠ THIS IS THE ROW THAT MOVED, AND IT IS THE RULING. It was written to assert
# that show_hidden_texts CANNOT resurrect the four texts — true of hide=op, and
# the counterpart of Q4/Q6, which hide=op cannot satisfy (header table). The step
# ruled for hide=true, so this row now asserts the behaviour that token actually
# has, and it still discriminates the two: under hide=op the four counts here are
# {0 0 0 0} and this row reds.
#
# WHY THE MOVE IS A GAIN AND NOT A CONCESSION. S10 makes 40 shipped sky130 FET
# symbols annotation-silent at the DEFAULT mask, and for a user whose rc never
# sources sky130_procs.tcl no overlay ever fires to replace them (decision D9,
# the ledger's E question). With hide=true those numbers are one stock menu item
# away — View > Show hidden texts, xschem.tcl:15050 — instead of unreachable, and
# sky130 now behaves exactly as gf180's 19 already-hide=true symbols do, which is
# what row L22 pins.
#
# THE SECOND HALF IS THE ONE THAT MATTERS: the overlay stays OFF here. The two
# sources are never both painted at the default mask, so revealing the legacy
# texts cannot re-create the double-printing S10 exists to remove. (At mask 1 AND
# show_hidden_texts 1 both do appear — that state is the explicit "show me
# everything, including what is hidden" debug mode, and it is what gf180 has
# always done too.)
opa_l_annot 0 ; opa_l_sht 1
set q_s0h [opa_l_print2 svg [file join $scratch q_01.svg] $Q_VP]
check {Q7 ESCAPE HATCH: show_hidden_texts 1 at mask 0 returns the four legacy texts and leaves the overlay off} \
  [concat [opa_q_sym $q_s0h] [lrange [opa_q_ovl $q_s0h] 0 1]] {10 10 10 10 0 0}

opa_l_sht 0 ; opa_l_annot 0
set XSCHEM_LIBRARY_PATH $S_LIBS

} qerr]} {
  puts "UNEXPECTED ERROR (section Q): $qerr"
  incr fail
}

# =============================================================================
# SECTION T — S11 of doc/claude/specs/op_annotation.md: TIMEPOINT ANNOTATION
#             WITH NO GRAPH OBJECT ON THE SCHEMATIC
# =============================================================================
# S5 made the block readable, S9b made it drawable and cacheable, S10b cleared
# the duplicate symbol texts out of the way. All three read ONE array —
# `xctx->raw->cursor_b_val[]`, reached as `xschem raw value <v> -1`
# (scheduler.c:10358) — and until S11 the only thing that could ever move that
# array off `update_op()`'s point 0 was a GRAPH.
#
#   `xschem set cursor2_x <t>`   scheduler.c:11847 (⚠ NOT :11802, which is the
#                                `cadgrid` self-log — the step brief's anchor is
#                                45 lines off and the arm is the one below)
#
#      11847  else if(!strcmp(argv[2], "cursor2_x")) {
#      11848    int floaters = there_are_floaters();
#      11849    xctx->graph_cursor2_x = atof_spice(argv[3]);
#      11851    if(xctx->rects[GRIDLAYER] > 0) {          <- gate 1
#      11852      Graph_ctx *gr = &xctx->graph_struct;
#      11853      xRect *r = &xctx->rect[GRIDLAYER][0];
#      11854      if(r->flags & 1) {                      <- gate 2 (rect ZERO)
#      11855        if(xctx->graph_flags & 4) {           <- gate 3
#      11856          backannotate_at_cursor_b_pos(r, gr);
#      11857          if(floaters) set_modify(-2);
#
# With any gate false the call moves a global NOBODY READS: measured on this
# tree, `xschem raw annot` stays `0 0 -1` (annot_p is still update_op's point 0,
# annot_x was never written, sweep_idx was never resolved) and every
# `xschem raw value <v> -1` still answers point 0. S11 adds the direct arm:
# with no graph OBJECT anywhere, resolve the cursor against `xctx->raw` itself.
#
# ============================================================================
# WHAT THIS SECTION IS FOR, IN ONE SENTENCE
# ============================================================================
# A user who presses 6 / Alt-6 on a schematic with nothing plotted gets a raw
# and a mask; before S11 every annotated number on that sheet is frozen at
# t = the first timestep, forever, and no key or command can move it.
#
# ============================================================================
# ⚠ THE BLAST RADIUS IS WIDER THAN op_annot, AND ROW T22 IS WHY IT IS PINNED
# ============================================================================
# `@spice_get_voltage` (token.c, the `@#n:` form and the bare one) reads
# `xctx->raw->cursor_b_val[]` DIRECTLY under `!raw_is_digital(raw) &&
# sch_waves_loaded() >= 0 && annot_p >= 0` — the live-cursor switch was a fourth
# term there until 0864 removed it from every render path. So the
# same seam moves every lab_pin / ipin / opin / iopin / vdd / ngspice_probe /
# scope text on the sheet, and every `pinexpr` row of every block. That is the
# feature, not a side effect — but it means the graph-path regression rows
# below (T12-T15) and the four shipped cursor suites
# (test_wave_cursor_crossdb 93, test_backannotate_digital 81,
# test_wave_viewer 57, test_wave_crossdb_trace 56 — all green today) are the
# real regression oracle, not this section alone.
#
# ============================================================================
# ⚠ WHICH ROWS ARE RED BEFORE S11 AND WHICH ARE GREEN CONTROLS — OUT LOUD
# ============================================================================
# RED before (14): T1 T2 T3 T4 T5 T6 T8 T9 T10 T16 T17 T18 T21 T22
# GREEN before AND after (9), every one of them load-bearing and NONE of them
# evidence that S11 happened:
#   T0  the fixture control. Without it every row below degrades into a hollow
#       pass — a raw that failed to load answers 0 for everything, which is
#       exactly the shape T1-T8 are asking about.
#   T7  the I3 rider. `gds` is deliberately ABSENT from the fixture raw, so a
#       new value source that fabricates a 0 for a missing vector reds here and
#       nowhere else. Green today because nothing reads at all.
#   T11 invariant I4. Read BEFORE any save — the S9 lesson: the row that named
#       itself the I4 row saved first and was vacuous.
#   T12 T13 T14 T15  THE GRAPH-PATH REGRESSION. The step brief says this matters
#       MORE than the new path. T13 and T14/T15 pin behaviour that is WRONG
#       today (issues 0480 / 0477 / 0478) precisely so that a later change to
#       the graph arm reds a NAMED line instead of passing unnoticed.
#   T19 T20  the helper's own `sch_waves_loaded() >= 0` self-gate. Green before
#       (nothing happens) and green after (nothing may happen). They exist to
#       red the variant that drops the gate and starts firing the user's
#       `$cursor_2_hook` and the S9b flush counter on sheets with no data.
#
# ============================================================================
# ⚠ THE TWO GRAPH-PRESENT STATES ARE DIFFERENT AND BOTH ARE PINNED (T12/T13)
# ============================================================================
# Headless, `xctx->graph_struct` is never populated by a draw — draw()'s whole
# body is inside `if(has_x)` (draw.c:10377) — so a graph rect that has never
# been `fullyzoom`'d leaves the shared ctx at the degenerate window [0,0].
# Measured on this tree: the SAME `xschem set cursor2_x 3e-9` yields
#   fullyzoom'd  -> annot_p 2, v(d) 3      (correct)
#   never zoomed -> annot_p 0, v(d) 1      (a PLAUSIBLE WRONG NUMBER)
# A section that covered only the first could not see the second move. T13
# asserts the wrong one deliberately; issue 0480 carries the finding.
#
# ============================================================================
# ⚠ THE FIXTURE: A HAND-WRITTEN ASCII TRANSIENT RAW, NO NGSPICE
# ============================================================================
# The same technique this file already uses for the operating-point fixtures
# (:1377 / :1408), extended to transient verbatim: `Plotname: Transient
# Analysis`, `No. Points: 5`, one value block per point, point index first.
# Five points at 0/1/2/3/4 ns with ROUND values, so every golden below is an
# exact string and an interpolation at 2.5 ns is exactly 2.5:
#
#   time                                     0     1n    2n    3n    4n
#   i(@m.xm1.msky130_fd_pr__nfet_01v8[id])   0     10u   20u   30u   40u
#   @m.xm1.msky130_fd_pr__nfet_01v8[gm]      0     100u  200u  300u  400u
#   v(@m.xm1.msky130_fd_pr__nfet_01v8[vth])  0.7   0.7   0.7   0.7   0.7
#   v(d)                                     0     1     2     3     4
#   v(g)                                     0.9   0.9   0.9   0.9   0.9
#
# ⚠ `[gds]` IS DELIBERATELY ABSENT. The descriptor asks for it, so every block
# below carries a `gds =` row with NOTHING after the `=` — invariant I3 riding
# along on every single golden, not just row T7's.
#
# ⚠ THE THREE VECTOR SHAPES ARE THE R3 / get_fqdevice CONVENTION (spec §3),
# re-measured on /usr/local/bin/ngspice against a `.tran` deck for this step:
# with `.save all` + `.save @m1[gm]` + `.save v(@m1[vth])` the header carries
# `@m1[gm]` BARE (kind 1) and `v(@m1[vth])` v()-wrapped (kind 2), sampled at
# every timestep — so a transient raw really is a valid carrier for device
# parameters, and this 5-point file is a faithful miniature of one.
#
# ============================================================================
# ⚠ TWO PIECES OF PROCESS STATE SURVIVE `xschem load` AND WILL CONTAMINATE
#    EVERY SCENARIO BELOW IF THEY ARE NOT RESET. MEASURED, NOT ASSUMED.
# ============================================================================
# (a) THE PUBLISHED ANNOTATION. `xschem annotate_op <same-file>` does NOT
#     re-publish if that raw is already loaded, so a `cursor2_x` written by an
#     EARLIER scenario is still sitting in annot_x when the next one starts —
#     measured: a gate-2 scenario that should read `0 0 -1` read `0 3e-09 0`
#     because the scenario before it had annotated at 3 ns. `xschem raw clear`
#     (scheduler.c) before every `annotate_op` is what makes each scenario
#     start from `0 0 -1`, and opa_t_arm below is the only way in.
# (b) `graph_flags`. `xschem load` does NOT clear it — measured, bit 4 survives
#     a load — so a scenario that means "cursor B was never enabled" (T15) has
#     to say `xschem cursor 2 0` out loud. And ⚠ its only setter,
#     `xschem cursor 2 1` (scheduler.c:3103), RESETS graph_cursor2_x to 0.0 as
#     a side effect (scheduler.c:3108): in every graph row below it therefore
#     comes BEFORE `xschem set cursor2_x`, never after.
#
# ============================================================================
# ⚠ WHAT THIS SECTION DOES NOT MEASURE
# ============================================================================
# * NO PIXELS. T10 and T22 read SVG exports, which is the same back end the
#   screen uses for the overlay text but is not the screen. The `6` / `Alt-6`
#   keys are NOT exercised: utils/annot_mode.tcl contains no `xschem cursor`
#   and no `set cursor2_x` at all, so after S11 those keys still land the user
#   on point 0 until something moves cursor B. That gap is the step's, not this
#   file's, and it is recorded in the spec rather than papered over here.
# * NOTHING HERE RUNS ngspice.
# * ⚠ ONE GOLDEN IS ARM-DEPENDENT — row T13 leg 2, and deliberately so; see that
#   row. Every other row here answers the same headless and under a display, so
#   the section moves this file by the SAME delta on both legs.

set T_DEV   {@m.xm1.msky130_fd_pr__nfet_01v8}
set T_GM    "${T_DEV}\[gm\]"
set T_ID    "i(${T_DEV}\[id\])"
set T_GDS   "${T_DEV}\[gds\]"
set T_RAW   [file join $scratch s11_tran.raw]
set T_PARAMS {{id id 0} {gm gm 1} {gds gds 1} {vth vth 2}}
## Viewport for the 10-argument `xschem print` form: {w h x1 y1 x2 y2}. Wide
## enough for M1, its four lab_pins and the overlay block at 0,0.
set T_VP    {1200 900 -300 -400 400 400}

## The block op_annot::text builds from that descriptor, at each timepoint. The
## label column is 3 wide (`gds` / `vth`), and the `gds` row is BLANK — the
## vector is not in the raw. Written out rather than computed: a formatter drift
## must red here, not agree with itself.
set T_TXT_P0  "id  = 0\ngm  = 0\ngds =\nvth = 0.7\n"
set T_TXT_P1  "id  = 10u\ngm  = 100u\ngds =\nvth = 0.7\n"
set T_TXT_P3  "id  = 30u\ngm  = 300u\ngds =\nvth = 0.7\n"
set T_TXT_P4  "id  = 40u\ngm  = 400u\ngds =\nvth = 0.7\n"
set T_TXT_P25 "id  = 25u\ngm  = 250u\ngds =\nvth = 0.7\n"
## The same four rows as the RENDERED overlay reads back out of an SVG export.
set T_ROWS_P0 {{id  = 0} {gm  = 0} {gds =} {vth = 0.7}}
## ⚠ THE REFUSED STATE, WHICH IS NOW THE RESTING STATE OF AN ATTACHED TRANSIENT.
## Issue 0856, ruled by the user 2026-08-26: only an operating point publishes an
## operating point, so a freshly attached .tran raw rests at annot_p == -1 with
## NOTHING published, instead of showing its t=0 sample wearing the label
## "operating point". Move a cursor and the real values at that time appear,
## exactly as before -- that is what every row from T1 down still measures.
## MEASURED on this binary, both arms, and written out for the same reason the
## P0/P1/P3 goldens are: a formatter drift must red here, not agree with itself.
set T_TXT_NONE  "id  =\ngm  =\ngds =\nvth =\n"
set T_ROWS_P1 {{id  = 10u} {gm  = 100u} {gds =} {vth = 0.7}}
set T_ROWS_P3 {{id  = 30u} {gm  = 300u} {gds =} {vth = 0.7}}
## ...and the same four rows in the 0856 REFUSED state, as the RENDERED overlay
## reads back out of an SVG export. All four blank, including `vth`: in this
## fixture vth is a raw VECTOR (`v(@m.xm1...[vth])`, variable 3 of the header
## written below), not a symbol property, so nothing published means nothing to
## print. MEASURED on this binary; it agrees row-for-row with T_TXT_NONE, and
## that agreement is itself worth having -- the C overlay back end and
## op_annot::text are two separate formatters over one state (invariant I1), and
## a divergence here would be a real defect rather than a golden to tidy.
set T_ROWS_NONE {{id  =} {gm  =} {gds =} {vth =}}
## Row T22's two shapes: the lab_pin text tail of an SVG export, from the `d`
## label onwards. MEASURED, byte-identical headless and under a display.
set T_PINS_NONE {d g 0 0}
set T_PINS_P3   {d 3 g 0.9 0 0.0 0 0.0}

## `xschem raw annot` -> {annot_p annot_x annot_sweep_idx}, or a marker. NEVER a
## bare catch: with no raw loaded it RAISES "No raw file loaded", and a caught
## raise reported as {} would make "nothing was published" and "the accessor is
## broken" the same answer.
proc opa_t_annot {} {
  set r [rcall {xschem raw annot}]
  if {[lindex $r 0] != 0} { return "RAISED:[lindex $r 1]" }
  return [lindex $r 1]
}
## THE value accessor under test, read exactly as op_annot::raw_or_blank and the
## IHP prototype's sg13g2_raw_or_double (:436) read it: point -1, which falls
## through to xctx->raw->cursor_b_val[idx] (scheduler.c:10358).
proc opa_t_v {v} {
  set r [rcall [list xschem raw value $v -1]]
  if {[lindex $r 0] != 0} { return "RAISED:[lindex $r 1]" }
  return [lindex $r 1]
}
## ...and the same value as the user SEES it. The read-back is single precision
## (`3e-4` returns 0.00030000001), so the to_eng rendering is the stable golden —
## the same reason section S's goldens are `100u` and not a float literal.
proc opa_t_eng {v} { return [op_annot::eng_or_blank [op_annot::raw_or_blank $v]] }
## {annot_p v(d) gm} — the triple row T18 compares between the two paths.
proc opa_t_trip {} {
  set a [opa_t_annot]
  if {[llength $a] != 3} { return $a }
  return [list [lindex $a 0] [opa_t_v {v(d)}] [opa_t_eng $::T_GM]]
}
## THE ONLY WAY A SCENARIO BELOW STARTS. See trap (a) in this section's header:
## without the `raw clear` the previous scenario's annot_x is still published.
## Returns the annotate_op rc so a broken fixture reds its own row.
proc opa_t_arm {sch} {
  catch {xschem raw clear}
  xschem load $sch
  catch {xschem cursor 2 0}
  return [lindex [rcall [list xschem annotate_op $::T_RAW]] 0]
}
## One graph rect on GRIDLAYER plotting v(d), optionally given a real window.
## ⚠ WITHOUT `fullyzoom` THE SHARED Graph_ctx STAYS AT [0,0] HEADLESS — that is
## row T13's whole subject, not an oversight.
proc opa_t_graph {zoom} {
  xschem set rectcolor 2
  xschem rect 0 -400 800 0 -1 {flags=graph} 0
  xschem setprop rect 2 0 node {v(d)}
  if {$zoom} {
    foreach {k v} [list x1 0 x2 5e-9 y1 -1 y2 5] { xschem setprop rect 2 0 $k $v }
    xschem setprop rect 2 0 fullyzoom
  }
}
## The four OVERLAY rows of an SVG export, in document order. Anchored on
## `<label><spaces>=` so it cannot match the sky130 symbol's own `id=` /`gm=`
## texts (no space before the `=`), which S10b hid but which show_hidden_texts
## can still bring back.
proc opa_t_rows {svg} {
  set o {}
  foreach t [opa_q_texts $svg] { if {[regexp {^(id|gm|gds|vth) +=} $t]} { lappend o $t } }
  return $o
}
## The lab_pin TAIL of an export: every text node from the `d` label onwards.
## lab_pin.sym carries `T {@lab}` then `T {@spice_get_voltage}` (lab_pin.sym:32)
## and the export preserves that order, so a rendered voltage appears BETWEEN two
## pin labels and a refused one leaves the labels back to back.
## ⚠ THE WHOLE TAIL, NOT THE ONE NODE AFTER `d`, AND THAT CHANGED WITH 0856.
## The old accessor returned `lindex $t [expr {$i+1}]` alone. With nothing
## published there is no voltage text at all, so that lone node is the NEXT PIN'S
## LABEL (`g`) -- a golden of `g` would pin a neighbouring symbol's label and call
## it evidence about the subject. Reading the tail says the true thing directly:
## either the labels run back to back, or a value sits between them.
proc opa_t_pins {svg} {
  set t [opa_q_texts $svg]
  set i [lsearch -exact $t d]
  if {$i < 0} { return "NO-LABEL" }
  return [lrange $t $i end]
}

if {[catch {

set XSCHEM_LIBRARY_PATH $S_LIBS

# --- the transient fixture, written fresh ------------------------------------
set f [open $T_RAW w]
puts -nonewline $f "Title: s11 tran fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 6
No. Points: 5
Variables:
\t0\ttime\ttime
\t1\t${T_ID}\tcurrent
\t2\t${T_GM}\tadmittance
\t3\tv(${T_DEV}\[vth\])\tvoltage
\t4\tv(d)\tvoltage
\t5\tv(g)\tvoltage
Values:
0\t0
\t0.0
\t0.0
\t0.7
\t0.0
\t0.9
1\t1e-09
\t10e-6
\t100e-6
\t0.7
\t1.0
\t0.9
2\t2e-09
\t20e-6
\t200e-6
\t0.7
\t2.0
\t0.9
3\t3e-09
\t30e-6
\t300e-6
\t0.7
\t3.0
\t0.9
4\t4e-09
\t40e-6
\t400e-6
\t0.7
\t4.0
\t0.9
"
close $f

## Section Q left sky130_procs.tcl's own `nmos` descriptor live. Replace it with
## the four-parameter one this section's goldens are counted on (B3: register
## REPLACES, it does not merge), so no row here depends on what a PDK file
## happens to ship today.
catch {op_annot::register nmos [list devpath $TMPL_AT params $T_PARAMS]}

# ===========================================================================
# T0 — CONTROL: THE PREMISE. GREEN BEFORE AND AFTER, AND LOAD-BEARING
# ===========================================================================
# ⚠ WITHOUT THIS ROW EVERY ROW BELOW DEGRADES INTO A HOLLOW PASS. A raw that
# failed to load, a descriptor an earlier section left overridden, or a
# schematic that did not resolve all answer `0` / `{}` — which is precisely the
# shape T1-T8 ask about. Four separate claims, all measured today:
#   * there is NO graph object on the canvas (`xschem get rects 2` == 0), so the
#     new arm's own trigger condition genuinely holds;
#   * cursor B was never enabled (graph_flags == 0) — decision D5 says the
#     direct path must neither REQUIRE nor SET bit 4, and this is the state that
#     makes T1's claim the strong one;
#   * the raw ATTACHED (rc 0) but published NOTHING -- `-1 0 -1`: annot_p -1,
#     annot_x never written, sweep_idx never resolved;
#   * and the block really does read that refusal, blank rather than zero.
#
# ⚠ THE FOURTH CLAIM INVERTED WITH ISSUE 0856, AND THE ROW GOT STRONGER RATHER
# THAN WEAKER. It used to assert `0 0 -1` and a block full of point-0 numbers,
# i.e. that a 5-point TRANSIENT put its t=0 sample on the schematic labelled as
# the operating point. The user ruled that out on 2026-08-26, verbatim: "We
# haven't yet built anything for annotating from TRAN results, so it should do
# nothing silently."
# ⚠ annot_p == -1 IS THE GATE'S SIGNATURE AND IS THIS ROW'S REAL EVIDENCE.
# Delete the guard in update_op() and this row reads `0 0 -1` with the block
# filled -- so it still catches the gate being removed, which is the whole
# reason it was rewritten instead of deleted.
# ⚠ AND IT STILL CANNOT GO HOLLOW: rc 0 says the raw really attached (a failed
# load also publishes nothing), `nmos` says the descriptor really resolved, and
# T1 immediately below moves a cursor and gets real numbers out of the SAME
# database -- so "nothing is published" here is a refusal, not an empty tree.
set t0_rc [opa_t_arm [file join $lib s5_flat.sch]]
check {T0 CONTROL: a tran raw annotated on a sheet with NO graph object and cursor B never enabled ATTACHES and publishes NOTHING (0856)} \
  [list $t0_rc [xschem get rects 2] [xschem get graph_flags] [opa_t_annot] \
        [op_annot::type M1] [rcall {op_annot::text M1}]] \
  [list 0 0 0 {-1 0 -1} nmos [list 0 $T_TXT_NONE]]

# ===========================================================================
# T1 — THE STEP: THE CURSOR IS RESOLVED WITH NO GRAPH IN THE PICTURE
# ===========================================================================
# ⚠ ALL THREE FIELDS MOVE, AND EACH ONE NAMES A DIFFERENT HALF OF THE FAILURE.
# Today the answer is `0 0 -1` and every field is wrong for its own reason:
# annot_p is still update_op()'s point 0, annot_x was NEVER WRITTEN (the
# requested time is not even recorded), and annot_sweep_idx was never resolved
# to a sweep column. A partial implementation that wrote annot_x and stopped
# would still read point 0 everywhere, and this row is what says so.
# annot_p 2 (not 3) is the LEFT index of the segment the cursor lands in; the
# value is interpolated within it, which is why t = 3 ns returns exactly point
# 3's data. It is the same number the graph path returns for the same t (T12).
xschem set cursor2_x 3e-9
check {T1 with NO graph object, `set cursor2_x 3e-9` resolves annot_p, records the requested annot_x and resolves the sweep} \
  [opa_t_annot] {2 3e-09 0}

# ===========================================================================
# T2 — ...AND THE ONE VALUE ACCESSOR MOVED WITH IT
# ===========================================================================
# `xschem raw value <v> -1` (scheduler.c:10343, the `point < 0` fall-through at
# :10358) is THE read seam: op_annot::raw_or_blank (op_annot.tcl:522), the S9b
# overlay, every `@spice_get_voltage` text, and the IHP prototype's own
# sg13g2_raw_or_double (sg13g2_procs.tcl:436) are all the same call. S11 must
# move what it reads WITHOUT changing what `-1` means. v(d) is exactly 3.0 at
# point 3, so this golden is exact in single precision and needs no to_eng.
check {T2 the -1 accessor now answers the value AT THE CURSOR, not at point 0} \
  [opa_t_v {v(d)}] 3

# ===========================================================================
# T3 — A DEVICE PARAMETER VECTOR MOVED TOO, NOT JUST A NODE VOLTAGE
# ===========================================================================
# ⚠ THE NODE-VOLTAGE HALF IS THE EASY HALF. `v(d)` is a plain sweep column; the
# device vectors are the ones this whole feature exists for, and they are the
# ones spec §3 R1 says only exist because the deck saved them explicitly. Both
# shapes are read here: kind 1 (bare) for gm and kind 0 (`i(...)`) for id.
check {T3 the DEVICE vectors follow the cursor as well -- kind 1 bare and kind 0 i() alike} \
  [list [opa_t_eng $T_GM] [opa_t_eng $T_ID]] {300u 30u}

# ===========================================================================
# T4 — THE WINDOW DISCRIMINATOR: THE ONE ROW A ZEROED Graph_ctx CANNOT PASS
# ===========================================================================
# ⚠ THIS IS THE STEP'S SHARPEST IMPLEMENTATION TRAP AND IT LOOKS LIKE A
# NON-ISSUE. The direct path has to hand the shipped cursor arithmetic a local
# Graph_ctx (save.c:1279-1288's rule: NEVER xctx->graph_struct, it is live
# inside draw_graph()). A `memset(&gr, 0, sizeof(gr))` one is the obvious
# choice, and RULING D4-7's `rescan_no_window` (callback.c:1454) looks like it
# makes that safe. It does not: a zeroed ctx is the window [0,0], EVERY
# transient raw has a sample at exactly t=0, that sample PASSES the window
# filter, so `first` comes back 0 instead of -1, the D4-7 rescan never fires,
# and interpolate_yval's frac clamp (callback.c:1305, RULING D4-4) then walks
# ONE segment forward and returns POINT 1's value for every t past the second
# sample. Measured on the graph path today with an un-zoomed rect: v(d) = 1 at
# t = 3 ns where the truth is 3.0 (row T13 pins that state deliberately).
# So: a whole-sweep window, and this row — two timepoints that a [0,0] window
# collapses onto the SAME wrong answer {1 0} — is the only thing between the
# feature and a plausible wrong number on a schematic (I3 / save.c RULING D5-1).
xschem set cursor2_x 3e-9
set t4a [list [opa_t_v {v(d)}] [lindex [opa_t_annot] 0]]
xschem set cursor2_x 4e-9
set t4b [list [opa_t_v {v(d)}] [lindex [opa_t_annot] 0]]
check {T4 two timepoints a degenerate [0,0] window would collapse onto point 1 both answer their OWN sample} \
  [list $t4a $t4b] {{3 2} {4 3}}

# ===========================================================================
# T5 — NOT A ONE-SHOT: THE CURSOR MOVES, REPEATEDLY, IN BOTH DIRECTIONS
# ===========================================================================
# ⚠ A ONE-SHOT IS A REAL FAILURE SHAPE HERE, not a paranoid one: the arm resolves
# a point index and writes it into raw->annot_p, and an implementation that
# resolved once and then short-circuited on "annot_p is already set" would pass
# T1-T4 and freeze on the second move. Forward, then backward, then forward.
set t5 {}
foreach t {1e-9 4e-9 1e-9} {
  xschem set cursor2_x $t
  lappend t5 [list [opa_t_v {v(d)}] [opa_t_eng $T_GM]]
}
check {T5 three consecutive moves, forward and back, each land on their own timepoint} \
  $t5 {{1 100u} {4 400u} {1 100u}}

# ===========================================================================
# T6 — BETWEEN SAMPLES: THE SHIPPED INTERPOLATION, NOT A NEAREST-SAMPLE SNAP
# ===========================================================================
# ⚠ THE ROW THAT SAYS THE ARITHMETIC WAS REACHED, NOT REWRITTEN. 2.5 ns is
# exactly half way between two round samples, so a nearest-sample or
# floor-to-sample implementation answers 2 or 3 and reds here while passing
# every row above. The numbers are the ones the GRAPH path returns for the same
# t on the same raw (measured), which is invariant I1 stated as a value.
xschem set cursor2_x 2.5e-9
check {T6 a cursor BETWEEN two samples interpolates -- 2.5 ns is 2.5 V and 250u, not a snap to 2 or 3} \
  [list [opa_t_v {v(d)}] [opa_t_eng $T_GM] [rcall {op_annot::text M1}]] \
  [list 2.5 250u [list 0 $T_TXT_P25]]

# ===========================================================================
# T7 — I3 RIDER: A MISSING VECTOR STAYS BLANK AT EVERY TIMEPOINT
# ===========================================================================
# ⚠ GREEN BEFORE THE CHANGE TOO — SAY SO. Today nothing reads at all, so of
# course `gds` is blank. This row is not evidence the feature works; it is the
# tripwire for the way a NEW value source breaks I3: `[gds]` is absent from the
# fixture raw, and an arm that seeded cursor_b_val for every index, or that
# treated "vector not found" as index 0, would print a number here — a
# fabricated value wearing a real device's label, which is the one thing
# invariant I3 and save.c RULING D5-1 forbid outright.
set t7 {}
foreach t {1e-9 3e-9 99e-9} {
  xschem set cursor2_x $t
  lappend t7 [rcall {op_annot::raw_or_blank $::T_GDS}]
}
check {T7 I3 the vector ABSENT from the raw renders BLANK at every timepoint, in range and out} \
  $t7 {{0 {}} {0 {}} {0 {}}}

# ===========================================================================
# T8 — THE USER-VISIBLE POINT, AS THE FORMATTED BLOCK
# ===========================================================================
# ⚠ THE ROW THE STEP EXISTS FOR. Measured before the change: these three calls
# returned the IDENTICAL `id  = 0 / gm  = 0 / gds = / vth = 0.7` block at every
# timepoint, while the same three calls WITH a graph on the canvas already
# returned 100u / 300u / 400u. This row closes exactly that gap, and it is the
# whole block rather than one row so that a value source which moved `gm` while
# leaving `id` frozen cannot pass.
set t8 {}
foreach t {3e-9 1e-9 4e-9} {
  xschem set cursor2_x $t
  lappend t8 [rcall {op_annot::text M1}]
}
check {T8 op_annot::text on a GRAPHLESS sheet is a different, correct block at each of three timepoints} \
  $t8 [list [list 0 $T_TXT_P3] [list 0 $T_TXT_P1] [list 0 $T_TXT_P4]]

# ===========================================================================
# T9 — S9b INVALIDATION: THE CACHE IS TOLD, AND ONLY WHEN THERE IS NEWS
# ===========================================================================
# ⚠ THIS IS THE ROW A REFACTOR ONE STEP AWAY WOULD DEFEAT SILENTLY. The S9b
# epoch (actions.c:1283, 14 fields) sees a cursor move ONLY through `data_seq`
# — a move WITHIN one segment changes cursor_b_val and nothing else, not
# modify_seq, not the raw pointer, not annot_p. `data_seq` is bumped by
# annot_data_changed() at callback.c:1533, which sits inside
# backannotate_at_cursor_b_pos() and NOT inside the static
# backannotate_cursor_b_in_db() that holds the arithmetic. An implementation
# that de-statics the inner function and calls it directly moves every value in
# T1-T8 and leaves the overlay rendering the PREVIOUS timepoint — the exact I3
# breach that got S9 attempt 1 reverted.
# ⚠ BOTH HALVES. `{1 0}`: the cursor move invalidates exactly once, and a
# following redraw with no news invalidates NOT AT ALL. Without the second half
# the row is satisfied by flushing every frame, i.e. by deleting the cache.
# ⚠ HEADLESS-VALID: annot_overlay_sync() sits ABOVE draw()'s `if(has_x)`.
# ⚠ NOT annot_overlay_count — it stays 0 headless (S9b lesson 5); T10 is the
# row that reads what was actually rendered.
opa_t_arm [file join $lib s5_flat.sch]
xschem set cursor2_x 1e-9
xschem redraw ; xschem redraw
set t9a [opa_o_fdelta {xschem set cursor2_x 3e-9 ; xschem redraw}]
set t9b [opa_o_fdelta {xschem redraw}]
check {T9 SEAM a graphless cursor move invalidates the overlay cache exactly ONCE, and a quiet redraw not at all} \
  [list $t9a $t9b] {1 0}

# ===========================================================================
# T10 — ...AND WHAT IS RENDERED AFTERWARDS IS THE NEW TIMEPOINT
# ===========================================================================
# ⚠ T9 AND T10 ARE NOT THE SAME ROW. T9 reads the flush COUNTER; T10 reads the
# BYTES the overlay back end produced, through get_annot_overlay()'s cache
# (actions.c:1456) rather than through op_annot::text — which is the only way a
# stale C cache can be told apart from a correct formatter. The three exports
# are one sequence in one process: the resting state (which fills the cache),
# then 3 ns, then back to 1 ns.
# ⚠ THE FIRST FRAME IS NOW THE 0856 REFUSED STATE, AND THAT MAKES THE ROW A
# STRONGER I3 STATEMENT THAN IT WAS. The cache is filled from a state in which
# NOTHING was published, then the cursor moves and real numbers must appear. A
# stale C cache can no longer satisfy the sequence by accident: the first frame's
# content genuinely DIFFERS IN KIND from the second, where before 0856 the
# difference was only between two sets of numbers.
# ⚠ AND THE FIRST FRAME IS GATE-SENSITIVE: delete the guard in update_op() and
# t10a fills with the point-0 numbers again.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 1
set t10a [opa_t_rows [opa_l_print2 svg [file join $scratch t_ovl0.svg] $T_VP]]
xschem set cursor2_x 3e-9
set t10b [opa_t_rows [opa_l_print2 svg [file join $scratch t_ovl3.svg] $T_VP]]
xschem set cursor2_x 1e-9
set t10c [opa_t_rows [opa_l_print2 svg [file join $scratch t_ovl1.svg] $T_VP]]
opa_l_annot 0
check {T10 the RENDERED overlay block follows the graphless cursor -- refused at rest, then 3 ns, then back to 1 ns} \
  [list $t10a $t10b $t10c] [list $T_ROWS_NONE $T_ROWS_P3 $T_ROWS_P1]

# ===========================================================================
# T11 — INVARIANT I4: THE SHEET IS READ, NEVER WRITTEN
# ===========================================================================
# ⚠ GREEN BEFORE AND AFTER, AND READ BEFORE ANY SAVE. The S9 lesson: the row
# that named itself the I4 row saved the schematic first and was therefore
# vacuous. `set_modify(-2)` (which the new arm carries into its branch, so the
# floaters of row T22 refresh) is in set_modify's derived-cache block but NOT
# in its modify_seq/dirty block (actions.c:200/238-256) — so five cursor moves
# and a redraw must leave `modified` at 0 and the instance count untouched. An
# arm that reached for `set_modify(1)` to force a repaint reds here.
opa_t_arm [file join $lib s5_flat.sch]
set t11n [xschem get instances]
foreach t {1e-9 2e-9 3e-9 4e-9 2.5e-9} { xschem set cursor2_x $t }
xschem redraw
check {T11 I4 five graphless cursor moves and a redraw leave the schematic UNmodified and unchanged} \
  [list [xschem get modified] [xschem get instances] $t11n] {0 5 5}

# ===========================================================================
# T12 — REGRESSION: A GRAPH THAT HAS BEEN DRAWN. BYTE-FOR-BYTE AS TODAY
# ===========================================================================
# ⚠ THE STEP BRIEF SAYS THIS MATTERS MORE THAN THE NEW PATH, and it is green
# before AND after by construction. `xschem cursor 2 1` comes first because it
# RESETS graph_cursor2_x (trap (b) in this section's header); `fullyzoom` comes
# before that because without it the shared Graph_ctx is the degenerate window
# T13 pins.
opa_t_arm [file join $lib s5_flat.sch]
opa_t_graph 1
xschem cursor 2 1
xschem set cursor2_x 3e-9
check {T12 REGRESSION a fullyzoom'd graph with cursor B on answers exactly what it answers today} \
  [list [xschem get rects 2] [opa_t_annot] [opa_t_v {v(d)}] [opa_t_eng $T_GM]] \
  {1 {2 3e-09 0} 3 300u}

# ===========================================================================
# T13 — REGRESSION: THE UN-DRAWN GRAPH, AND WHOSE WINDOW IT ACTUALLY USES
#       (issue 0480)
# ===========================================================================
# ⚠ THIS ROW ASSERTS TODAY'S BEHAVIOUR ON PURPOSE, AND TODAY'S BEHAVIOUR IS A
# STALE READ. scheduler.c:11852 hands the cursor the SHARED
# `xctx->graph_struct`, which only `setup_graph_data()` (draw.c:4571) ever
# fills — from `draw_graph()`, whose whole body is inside `if(has_x)`
# (draw.c:10377), or from a `fullyzoom`. So a graph rect that has never been
# drawn does NOT resolve against its own `x1`/`x2` tokens at all. The three legs
# below are one measured sequence and each is a different claim:
#
#   leg 1  a FULL-SWEEP graph, fullyzoom'd     -> annot_p 2, v(d) 3   (correct)
#   leg 2  a NEW sheet, a NEW graph rect whose OWN window is [0, 1e-9],
#          never zoomed                        -> ⚠ THE ARM DECIDES, see below
#   leg 3  the SAME rect, now fullyzoom'd into the shared struct
#                                              -> annot_p 1, v(d) 2
#          i.e. the narrow window really does change the answer, once it is the
#          one being read. Without leg 3, leg 2 would be satisfied by a window
#          that simply never matters.
#
# ⚠ LEG 2 IS THE ONLY ARM-DEPENDENT GOLDEN IN THIS SECTION, AND ITS BEING SO IS
# THE FINDING. Measured on this tree, same script, same schematic, same command:
#     --nogui        annot_p 2, v(d) 3   the rect's window is IGNORED and leg 1's
#                                        window — belonging to a schematic that
#                                        is no longer loaded — is what answers
#     DISPLAY=:99    annot_p 1, v(d) 2   a frame got painted, draw_graph() ran
#                                        setup_graph_data() on THIS rect, and the
#                                        rect's own window answers
# and in a FRESH process where nothing has ever painted or zoomed, the same leg
# reads the degenerate window [0,0] and answers v(d) = 1 — a third number. One
# `set cursor2_x`, one schematic, three answers, selected by whether and when a
# frame was drawn. That is issue 0480 stated as completely as this file can state
# it, and it is the reason the S11 direct arm carries its own stack-local
# whole-sweep window (row T4) instead of borrowing this global. NOT S11's to fix:
# repairing it would move graph-present behaviour, which the acceptance forbids.
# The discriminator is `has_x`, the same flag rows M1/M2/O14 self-skip on and the
# same one opa_o_printpasses uses — not an environment guess.
opa_t_arm [file join $lib s5_flat.sch]
opa_t_graph 1
xschem cursor 2 1
xschem set cursor2_x 3e-9
set t13a [list [opa_t_annot] [opa_t_v {v(d)}]]
opa_t_arm [file join $lib s5_flat.sch]
xschem set rectcolor 2
xschem rect 0 -400 800 0 -1 {flags=graph} 0
xschem setprop rect 2 0 node {v(d)}
foreach {k v} [list x1 0 x2 1e-9 y1 -1 y2 5] { xschem setprop rect 2 0 $k $v }
xschem cursor 2 1
xschem set cursor2_x 3e-9
set t13b [list [opa_t_annot] [opa_t_v {v(d)}] [xschem getprop rect 2 0 x2]]
xschem setprop rect 2 0 fullyzoom
xschem set cursor2_x 3e-9
set t13c [list [opa_t_annot] [opa_t_v {v(d)}]]
if {[info exists ::has_x]} {
  set t13b_exp {{1 3e-09 0} 2 1e-9}
} else {
  set t13b_exp {{2 3e-09 0} 3 1e-9}
}
check {T13 REGRESSION 0480 which window an un-drawn graph rect resolves against depends on whether a frame was painted} \
  [list $t13a $t13b $t13c] \
  [list {{2 3e-09 0} 3} $t13b_exp {{1 3e-09 0} 2}]

# ===========================================================================
# T14 — REGRESSION: GATE 2, THE RECT-ZERO HARD-CODE (issue 0477)
# ===========================================================================
# ⚠ THE DIRECT PATH MUST NOT RESCUE THIS. scheduler.c:11853 indexes
# `xctx->rect[GRIDLAYER][0]` specifically, so a plain non-graph rectangle
# sitting at index 0 blocks annotation outright even with a real, windowed,
# cursor-B-enabled graph at index 1 — measured, `xschem raw annot` stays
# `0 0 -1`. Decision D1 keys the new arm on "no rect on GRIDLAYER carries
# flags&1", i.e. this sheet HAS a graph and takes the old path unchanged; a
# fallback keyed on "any of the three gates false" would silently repair 0477
# as a side effect and change graph-present behaviour, which the acceptance
# forbids. Filed, not fixed.
opa_t_arm [file join $lib s5_flat.sch]
xschem set rectcolor 2
xschem rect 0 -900 100 -800 -1 {} 0
xschem rect 0 -400 800 0 -1 {flags=graph} 0
xschem setprop rect 2 1 node {v(d)}
foreach {k v} [list x1 0 x2 5e-9 y1 -1 y2 5] { xschem setprop rect 2 1 $k $v }
xschem setprop rect 2 1 fullyzoom
xschem cursor 2 1
xschem set cursor2_x 3e-9
# ⚠ THE ANNOT TRIPLE IS THIS ROW'S EVIDENCE, AND THE TRAILING FIELD IS NOW A
# BLANK -- ISSUE 0861. Since issue 0856 an attached transient rests at annot_p -1
# rather than 0, so the triple moved from `0 0 -1` to `-1 0 -1`, and the row still
# catches a 0477 "rescue", which would read annot_p 2.
#
# The trailing field used to be gold'd as `0`, with a comment judging that zero
# inert. IT WAS NOT INERT. Nothing had been published, so the value accessor was
# reading an array that was never written and is zero only because it was
# allocated zeroed -- the same fabricated number a `@spice_get_node` text was
# painting on the schematic, one accessor over, which is issue 0861 and RULING
# D5-1. The accessor now answers NOTHING when nothing was published, so the
# golden is the empty string. The field still says the accessor did not RAISE;
# it just no longer says it by quoting a number the results file never contained.
check {T14 REGRESSION 0477 a plain rect at GRIDLAYER index 0 still blocks a real graph at index 1 -- the direct path does NOT rescue it} \
  [list [xschem get rects 2] [xschem getprop rect 2 0 flags] \
        [xschem getprop rect 2 1 flags] [opa_t_annot] [opa_t_v {v(d)}]] \
  [list 2 {} graph {-1 0 -1} {}]

# ===========================================================================
# T15 — REGRESSION: GATE 3, `graph_flags & 4` (issue 0478)
# ===========================================================================
# ⚠ A GRAPH MAKES TIMEPOINT ANNOTATION HARDER THAN NO GRAPH, AND THAT STAYS
# TRUE AFTER S11. A real, windowed graph whose cursor B was never enabled
# annotates nothing — bit 4 is a DRAWING flag and its only setter,
# `xschem cursor 2 1`, resets the cursor position as a side effect. Decision D5
# says the direct arm neither requires nor sets that bit; this row says the
# direct arm must not fire BEHIND a graph either.
opa_t_arm [file join $lib s5_flat.sch]
opa_t_graph 1
xschem set cursor2_x 3e-9
# ⚠ SAME SHAPE AND SAME CORRECTION AS T14: the annot triple is the evidence, and
# the trailing field is a BLANK since issue 0861. `-1 0 -1` rather than `0 0 -1`
# since issue 0856 -- an attached transient publishes nothing at rest -- and the
# row still catches the direct arm firing behind a graph, which would read
# annot_p 2. The old `0` there was the un-published, allocated-zero read that
# 0861 is about, not a measurement of this fixture.
check {T15 REGRESSION 0478 a fullyzoom'd graph with cursor B never enabled still annotates nothing} \
  [list [xschem get graph_flags] [opa_t_annot] [opa_t_v {v(d)}]] {0 {-1 0 -1} {}}

# ===========================================================================
# T16 — OUT OF RANGE, PAST THE END: THE ENDPOINT IS HELD, AND SAID SO
# ===========================================================================
# ⚠ THE STEP'S ONE OPEN DESIGN QUESTION, PINNED AS BEHAVIOUR (issue 0479).
# The brief asks for an out-of-range t to be "handled honestly rather than
# clamping silently". Measured on the GRAPH path today, on this binary: t = 99 ns
# against a raw ending at 4 ns gives annot_p 4 and v(d) = 4 — the last sample
# HELD, never extrapolated. That is RULING D4-4 (callback.c:1305-1306), ratified
# and pinned by rows XCW4/XCW5/XCW6 of test_wave_cursor_crossdb, which
# explicitly REJECTED resetting annot_p to -1.
# Reading the invariants in order: I3 forbids fabricating a number for a MISSING
# vector (that is row T7, and it still blanks); an endpoint hold is a REAL
# measured sample of a PRESENT vector, so I3 does not reach it. I1 then settles
# it: two behaviours for one cursor is exactly the silent drift I1 exists to
# prevent, so the direct path must clamp identically — which row T18 is the
# proof of.
# ⚠ THE THIRD ELEMENT IS THE HONEST HALF THAT ALREADY EXISTS: annot_x reports
# the REQUESTED 9.9e-08 beside the clamped annot_p 4, so a caller can detect the
# condition. Nothing says so on a status line, and there is no "cursor is outside
# the data" seam — that is 0479's question, for BOTH paths or neither.
opa_t_arm [file join $lib s5_flat.sch]
xschem set cursor2_x 99e-9
check {T16 0479 a graphless cursor PAST THE END holds the last sample and still reports the requested time} \
  [list [opa_t_annot] [opa_t_v {v(d)}] [opa_t_eng $T_GM]] \
  {{4 9.9e-08 0} 4 400u}

# ===========================================================================
# T17 — OUT OF RANGE, BEFORE THE START
# ===========================================================================
# ⚠ A WEAK ROW, NAMED AS ONE. It is green under a degenerate [0,0] window too
# (frac clamps to 0 at that end as well), so it cannot substitute for T4 and
# must not be read as covering the window choice. Its only element that moves
# today is annot_x — the requested time being recorded at all.
xschem set cursor2_x -5e-9
check {T17 a graphless cursor BEFORE THE START holds the first sample -- weak, see T4 for the window claim} \
  [list [opa_t_annot] [opa_t_v {v(d)}] [opa_t_eng $T_GM]] \
  {{0 -5e-09 0} 0 0}

# ===========================================================================
# T18 — INVARIANT I1: THE TWO PATHS ARE ONE BEHAVIOUR, NOT TWO
# ===========================================================================
# ⚠ THE ANTI-DRIFT ROW, AND NOTHING ELSE IN THE TREE MEASURES IT. No existing
# suite compares the graphless answer with the graph answer, so a direct arm
# that blanked out of range, or snapped instead of interpolating, or resolved a
# different annot_p, would red NOTHING today. Same process, same raw, same
# instance: read the {annot_p, v(d), gm} triple with no graph, then add a real
# windowed graph with cursor B on and read it again at the same two times. One
# of them is out of range and one is between samples — the two places the paths
# could most plausibly disagree.
opa_t_arm [file join $lib s5_flat.sch]
xschem set cursor2_x 99e-9
set t18d1 [opa_t_trip]
xschem set cursor2_x 2.5e-9
set t18d2 [opa_t_trip]
opa_t_graph 1
xschem cursor 2 1
xschem set cursor2_x 99e-9
set t18g1 [opa_t_trip]
xschem set cursor2_x 2.5e-9
set t18g2 [opa_t_trip]
check {T18 I1 the graphless path and the graph path return the IDENTICAL triple, out of range and between samples} \
  [list [expr {$t18d1 eq $t18g1}] [expr {$t18d2 eq $t18g2}] $t18g1 $t18g2] \
  {1 1 {4 4 400u} {2 2.5 250u}}

# ===========================================================================
# T19 — NO DATA: A BYTE-EXACT NO-OP, INCLUDING THE USER'S OWN HOOK
# ===========================================================================
# ⚠ GREEN BEFORE AND AFTER; IT GUARDS THE HELPER'S SELF-GATE, NOT THE FEATURE.
# backannotate_at_cursor_b_pos() fires annot_data_changed() AND
# `catch {eval $cursor_2_hook}` (callback.c:1533/1537) BEFORE its own
# sch_waves_loaded() test — so a direct arm that called it unconditionally would
# start firing a user hook that has been graph-only since it was written, and
# would move the very S9b flush counter that exists to detect over-flushing, on
# every sheet with no data. Decision D6 puts the gate in the helper. Both seams,
# one script.
opa_t_arm [file join $lib s5_flat.sch]
catch {xschem raw clear}
set ::t19hook 0
set ::cursor_2_hook {incr ::t19hook}
xschem redraw ; xschem redraw
set t19f [opa_o_fdelta {xschem set cursor2_x 3e-9 ; xschem redraw}]
set ::cursor_2_hook {}
check {T19 with NO raw loaded a graphless `set cursor2_x` flushes nothing and fires no cursor_2_hook} \
  [list [rcall {xschem raw loaded}] $t19f $::t19hook] {{0 -1} 0 0}

# ===========================================================================
# T20 — LANDMINE 4: ABOVE THE LEVEL THE WAVES WERE LOADED AT
# ===========================================================================
# ⚠ THE DEGRADATION MUST BE THE SAME ONE THE GRAPH PATH HAS. sch_waves_loaded()
# (draw.c:2825) binds the data to `raw->schname` and walks currsch DOWNWARDS, so
# DESCENDING keeps the annotation alive (measured: `raw loaded` is still 0 one
# level down) and ASCENDING out of the annotated level is what loses it — the
# same asymmetry rows S17/S18 record. Annotate INSIDE x1, go back up, and the
# direct path must be as silent as the graph path is.
opa_t_arm [file join $lib s5_flat.sch]
catch {xschem raw clear}
xschem load [file join $lib s5_top.sch]
xschem select instance 0
xschem descend 1 2
set t20rc [lindex [rcall [list xschem annotate_op $T_RAW]] 0]
set t20in [rcall {xschem raw loaded}]
xschem go_back
set ::t20hook 0
set ::cursor_2_hook {incr ::t20hook}
xschem redraw ; xschem redraw
set t20f [opa_o_fdelta {xschem set cursor2_x 3e-9 ; xschem redraw}]
set ::cursor_2_hook {}
check {T20 landmine 4 after ascending ABOVE the annotated level a graphless cursor move is a no-op, hook included} \
  [list $t20rc $t20in [rcall {xschem raw loaded}] $t20f $::t20hook] \
  {0 {0 1} {0 -1} 0 0}

# ===========================================================================
# T21 — THE TRIGGER IS A SCAN FOR A GRAPH, NOT A RECT COUNT (decision D1)
# ===========================================================================
# ⚠ THE ONE ROW THAT SEPARATES D1 FROM THE OBVIOUS `rects[GRIDLAYER] == 0`.
# GRIDLAYER carries ordinary rectangles too — layer 2 is a normal drawing layer
# — so a schematic with a plain box on it and NOTHING plotted is exactly the
# situation S11 exists for, and a count-based trigger would refuse it while
# looking correct on every other row in this section.
opa_t_arm [file join $lib s5_flat.sch]
xschem set rectcolor 2
xschem rect 0 -900 100 -800 -1 {} 0
xschem set cursor2_x 3e-9
check {T21 D1 a plain non-graph rect on GRIDLAYER with no graph anywhere still reaches the direct path} \
  [list [xschem get rects 2] [xschem getprop rect 2 0 flags] [opa_t_annot] \
        [opa_t_v {v(d)}]] \
  [list 1 {} {2 3e-09 0} 3]

# ===========================================================================
# T22 — THE BLAST RADIUS, AND THE ONLY ROW `set_modify(-2)` ANSWERS TO
# ===========================================================================
# ⚠ NOT AN op_annot ROW AT ALL, AND THAT IS THE POINT. lab_pin.sym:32 carries
# `T {@spice_get_voltage}`; translate expands it out of cursor_b_val[]
# (token.c:4821) and the RESULT IS CACHED as a floater string. So the arm's
# `if(floaters) set_modify(-2);` is load-bearing: without it the values move in
# the raw and the schematic keeps painting the previous timepoint. Measured
# today, graphless, at the DEFAULT mask: the two exports are byte-identical and
# both print `d 0`; with a graph the same pair moves `d 1` -> `d 3`.
#
# ⚠ ISSUE 0856 MOVED THE FIRST EXPORT AND FORCED A BETTER ACCESSOR.
# At rest an attached transient now publishes nothing, so NO `@spice_get_voltage`
# text is emitted at all -- and the old accessor, which returned the single text
# node after the `d` label, then returned `g`: THE NEXT PIN'S LABEL. A golden of
# `g` would be pinning a neighbouring symbol's label and calling it evidence
# about this row's subject. opa_t_pins reads the whole tail instead and says the
# true thing directly.
# ⚠ SO READ THE TWO ELEMENTS AS SHAPES, NOT AS VALUES.
#   first  -- the four lab_pin labels BACK TO BACK with nothing between them:
#             no voltage text was emitted anywhere on the sheet.
#   second -- THE NON-VACUITY GUARD, and it does more work than the old `0` did:
#             at 3 ns all four floaters render, each value sitting between its
#             own label and the next. Without it, "the two exports differ" is
#             satisfied by a fixture whose text never appeared at all.
# ⚠ GATE-SENSITIVE: delete the guard in update_op() and the first element fills
# with point-0 values, i.e. it stops being labels-back-to-back.
#
# ⚠ THE MASK IS SET TO 2 HERE, AND THAT IS A REPAIR, NOT A WEAKENING (0614).
# This row ran at the DEFAULT mask because at the time nothing gated a node
# voltage. Under 0614 the three chords own them: bit1 clear means no
# `@spice_get_voltage` text is drawn at all, and this row's subject — the
# graphless cursor arm and its `if(floaters) set_modify(-2)` — would then be
# measured through an exporter that draws nothing, i.e. the row would go
# vacuous rather than red. Mask 2 is node voltages ON with device OP info off,
# which is exactly the state this row has always been measuring. The mask is
# restored to 0 immediately below, as it was before.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 2
set t22a [opa_t_pins [opa_l_print2 svg [file join $scratch t_flt0.svg] $T_VP]]
xschem set cursor2_x 3e-9
set t22b [opa_t_pins [opa_l_print2 svg [file join $scratch t_flt3.svg] $T_VP]]
check {T22 the lab_pin @spice_get_voltage floater follows a GRAPHLESS cursor -- the wider blast radius, and set_modify(-2)} \
  [list $t22a $t22b] [list $T_PINS_NONE $T_PINS_P3]

opa_l_annot 0

# ===========================================================================
# T23-T28 — ISSUE 0856's OWN TRUTH TABLE, ONE ROW PER TERM
# ===========================================================================
# ⚠ EVERY ROW ABOVE MEASURES THE GATE THROUGH THE `tran` TERM ALONE. The guard
# in update_op() has four more terms and until these rows NOTHING IN THE TREE
# saw three of them: `dc` accepted, a multi-point Operating Point accepted after
# read_dataset rewrites it, and a NULL sim_type refused. A guard whose accepting
# half is untested is a guard that can be tightened into refusing everything
# without a single row noticing -- and "publishes nothing, ever" passes T0, T10,
# T14, T15 and T22 exactly as the correct behaviour does.
#
# THE FIVE TERMS, and the row that owns each:
#   T23  tran      REFUSED   -- the ruling itself, in one row
#   T24  op        ACCEPTED  -- the control; the feature that must not break
#   T25  dc        ACCEPTED  -- Xyce spells its operating point this way
#   T26  op, N>1   ACCEPTED  -- read_dataset rewrites it to `dc`; the gate
#                              comment's own stated justification
#   T27  table     REFUSED   -- THE WIDENING, pinned as behaviour (issue 0860)
#   T28  <none>    REFUSED   -- the NULL-safety term, no database loaded at all
#
# ⚠ THE VALUE HALF IS WHAT MAKES T24-T26 REAL. `update_op` answering 1 says a
# publish was attempted; the number out of ngspice::ngspice_data says one
# arrived. Each fixture carries a DIFFERENT, exactly-representable voltage
# (7.5 / 8.5 / 6.5 / 5.5) so no row can be satisfied by another row's leftovers
# -- and update_op unsets the array on entry, so a stale value would have to
# have been republished to appear.
proc opa_t_pub {} {
  return [list [xschem raw sim_type] [xschem raw points] [xschem update_op]]
}
proc opa_t_nv {k} {
  if {[info exists ::ngspice::ngspice_data($k)]} { return [set ::ngspice::ngspice_data($k)] }
  return {}
}
proc opa_t_hdr {plot npts sweep} {
  return "Title: 0856 truth table
Date: Mon Jan 1 00:00:00 2026
Plotname: $plot
Flags: real
No. Variables: 2
No. Points: $npts
Variables:
\t0\t$sweep\t$sweep
\t1\tv(d)\tvoltage
Values:
"
}
proc opa_t_wr {path text} {
  set f [open $path w] ; puts -nonewline $f $text ; close $f
}

set T_OPRAW   [file join $scratch t_op1.raw]
set T_DCRAW   [file join $scratch t_dc1.raw]
set T_OPMULTI [file join $scratch t_opn.raw]
set T_TBL     [file join $scratch t_tbl.dat]
opa_t_wr $T_OPRAW   "[opa_t_hdr {Operating Point} 1 time]0\t0.0\n\t7.5\n"
opa_t_wr $T_DCRAW   "[opa_t_hdr {DC transfer characteristic} 1 v-sweep]0\t0.0\n\t8.5\n"
opa_t_wr $T_OPMULTI "[opa_t_hdr {Operating Point} 3 time]0\t0.0\n\t6.5\n1\t1.0\n\t6.6\n2\t2.0\n\t6.7\n"
opa_t_wr $T_TBL     "v-sweep\tv(d)\n0.0\t5.5\n1.0\t5.6\n2.0\t5.7\n"

# ---------------------------------------------------------------------------
# T23 — THE RULING, IN ONE ROW
# ---------------------------------------------------------------------------
# The user's words, 2026-08-26: "if OP is part of the run, then plot from OP. We
# haven't yet built anything for annotating from TRAN results, so it should do
# nothing silently. Why complicate things?" This is that sentence as an
# assertion: a 5-point transient is loaded and current, and the point-0
# publisher declines it and leaves the array EMPTY.
# Without the guard this row reads `tran 5 1` with 2 entries in the array.
catch {xschem raw clear}
xschem raw read $T_RAW tran
check {T23 issue 0856: a TRANSIENT is loaded and current, and the point-0 publisher refuses it -- nothing published, nothing said} \
  [list [opa_t_pub] [array size ::ngspice::ngspice_data]] {{tran 5 0} 0}

# ---------------------------------------------------------------------------
# T24 — THE CONTROL: THE OPERATING POINT PATH IS UNTOUCHED
# ---------------------------------------------------------------------------
# ⚠ THE ROW THE WHOLE FEATURE IS PROTECTED BY. Backannotation exists to put an
# operating point on a schematic; a guard that also silenced `op` would be a far
# worse defect than the one it fixes, and every refusal row in this file would
# still be green. 7.5 is exactly representable in single precision, so the
# golden is exact and needs no to_eng.
catch {xschem raw clear}
xschem raw read $T_OPRAW op
check {T24 CONTROL: a 1-point OPERATING POINT still publishes, and a real number reaches the schematic} \
  [list [opa_t_pub] [opa_t_nv {v(d)}]] {{op 1 1} 7.5}

# ---------------------------------------------------------------------------
# T25 — THE `dc` TERM, WHICH NOTHING IN THE TREE SAW BEFORE THIS ROW
# ---------------------------------------------------------------------------
# Xyce writes its operating point as a 1-point DC TRANSFER CHARACTERISTIC, and
# both `raw switch` gates already spell the op/dc pair the same way. Drop the
# `dc` half of the guard and every Xyce user's operating point silently stops
# annotating -- with no error, because the refusal is deliberately silent.
# ⚠ READ AS `dc`, NOT AS `op`: measured, `xschem raw read <dc-plotname> op`
# answers 0 and leaves nothing loaded, so a row written the other way would be
# green against a broken guard for the wrong reason.
catch {xschem raw clear}
xschem raw read $T_DCRAW dc
check {T25 a 1-point DC TRANSFER CHARACTERISTIC -- how Xyce spells an operating point -- still publishes} \
  [list [opa_t_pub] [opa_t_nv {v(d)}]] {{dc 1 1} 8.5}

# ---------------------------------------------------------------------------
# T26 — THE OTHER ROAD TO `dc`, AND THE GATE COMMENT'S OWN JUSTIFICATION
# ---------------------------------------------------------------------------
# read_dataset() rewrites a MULTI-POINT "Operating Point" to sim_type `dc`
# (save.c, the `npoints > 1 && !strcmp(sim_type, "op")` arms). So a file whose
# header says Operating Point can arrive at the guard calling itself `dc`, which
# is exactly why the guard accepts both spellings. The gate's comment says so;
# this row is what makes the claim checkable.
catch {xschem raw clear}
xschem raw read $T_OPMULTI op
check {T26 a MULTI-POINT Operating Point arrives as `dc` -- the rewrite read_dataset performs -- and still publishes its point 0} \
  [list [opa_t_pub] [opa_t_nv {v(d)}]] {{dc 3 1} 6.5}

# ---------------------------------------------------------------------------
# T27 — THE WIDENING, TURNED FROM A SILENT DECISION INTO A VISIBLE ONE
# ---------------------------------------------------------------------------
# ⚠ THE USER RULED ABOUT TRANSIENTS. THE GUARD REFUSES EVERYTHING THAT IS NOT
# op/dc, an ascii TABLE database included -- and a table is not a logic database,
# it is columns of real numbers, so nothing about the digital ruling covers it
# either. That is a deliberate widening (issue 0860): one rule and one answer,
# because nothing but op/dc has ever held a meaningful operating point, and the
# narrow alternative would leave ac, noise and table publishing a fabricated
# point 0 -- ruling D5-1's exact failure. It is recorded as an unratified
# decision rather than hidden. If the user later rules that tables SHOULD
# publish, THIS ROW REDS and forces the conversation instead of letting the
# behaviour drift.
catch {xschem raw clear}
xschem raw table_read $T_TBL
check {T27 issue 0860 THE WIDENING: an ascii TABLE database publishes nothing either -- the guard is op/dc only, not `not tran`} \
  [list [opa_t_pub] [opa_t_nv {v(d)}]] {{table 3 0} {}}

# ---------------------------------------------------------------------------
# T28 — THE NULL-SAFETY TERM
# ---------------------------------------------------------------------------
# The guard reads xctx->raw->sim_type, so it must survive there being no
# database at all -- `xschem update_op` is a public verb any script can call at
# any moment, and the Op Annotate menu entries reach it after a `raw clear`.
# Drop the null test from the condition and this row does not fail politely: it
# SIGSEGVs, the file dies with no RESULT banner, and run_regression scores the
# whole case as a harness failure. That is the honest shape -- the row is only
# crash-prone under sabotage, and at HEAD it answers safely.
# ⚠ `xschem raw loaded`, NEVER `xschem raw sim_type`: with nothing loaded the
# latter RAISES, which would abort the file rather than answer it.
catch {xschem raw clear}
check {T28 with NO database loaded at all the publisher answers 0 and touches nothing -- the guard's NULL term} \
  [list [xschem raw loaded] [xschem update_op] [array size ::ngspice::ngspice_data]] {-1 0 0}

catch {xschem raw clear}
catch {xschem cursor 2 0}
set XSCHEM_LIBRARY_PATH $S_LIBS

} terr]} {
  puts "UNEXPECTED ERROR (section T): $terr"
  incr fail
}

# =============================================================================
# SECTION U — issues 0614 + 0615: THE THREE CHORDS OWN THE NODE VOLTAGES,
#             AND THE NODE VOLTAGES STOP WEARING THE OP BLOCK'S COLOUR
# =============================================================================
# Two issues, ONE pass, because they need ONE predicate — "is this text a
# node-voltage / branch-current annotation" — and building it twice is invariant
# I1's failure mode (0615's own first landmine says so).
#
#   0614  `6` -> device OP blocks ONLY, node voltages OFF
#         `Alt-6` -> blocks AND voltages
#         `Ctrl-6` -> neither
#   0615  the voltages get their own layer (annot_voltage_layer, default 9),
#         reaching draw.c AND svgdraw.c AND psprint.c
#
# ============================================================================
# ⚠ WHY bit1 HAS NOTHING TO GATE TODAY — MEASURED, AND IT IS THE WHOLE DEFECT
# ============================================================================
# `hide=voltage` appears in ZERO tracked files (row Q2's census says so out
# loud: `0 1 119 0 0`). text_hidden() (actions.c:1195) is a pure function of
# `flags`, and `flags` comes from the `hide=` token ALONE (set_text_flags,
# actions.c:1119). Node voltages arrive by a COMPLETELY DIFFERENT road — the
# symbol text `T {@spice_get_voltage} … {layer=15}` on lab_pin.sym:32,
# ipin/opin/iopin.sym:36, vdd.sym:35, lab_wire.sym:32, ngspice_probe.sym:34,
# bus_tap.sym:37 — expanded by translate() out of `xctx->raw->cursor_b_val[]`
# (token.c:4315 for the `@#n:` form, :4821 for the bare one). Nothing on that
# road consults annot_show. Measured on this section's own fixture, with a raw:
#
#     mask 0 (Ctrl-6)  6798 bytes   voltages 1  currents 1  OP block 0
#     mask 1 (6)       7693 bytes   voltages 1  currents 1  OP block 1
#     mask 2           6798 bytes   BYTE-IDENTICAL TO MASK 0
#     mask 3 (Alt-6)   7693 bytes   BYTE-IDENTICAL TO MASK 1
#
# i.e. two distinct renders where the ruling needs three, and `Ctrl-6 -> nothing`
# is false. Same shape the user measured on bandgap_opamp (169897 == 169897).
#
# ⚠ THOSE COUNTS ARE FILE-LOCAL, NOT FIXTURE-LOCAL, AND THE DIFFERENCE IS
# INSTRUCTIVE. The same fixture in a bare interpreter measures 6990 / 7293: this
# file has a live `nmos` descriptor (sections P and Q) and the sheet carries a
# shipped devices/nmos4.sym whose K type IS `nmos`, so a SECOND S9b block paints
# on it at masks 1 and 3. Every row below is written against markers and against
# references measured in the same export, never against a literal length — U1
# asserts distinctness and ordering only — precisely so that a later section
# registering one more descriptor cannot silently red this one.
#
# ============================================================================
# ⚠ WHOLE-STRING, NOT SUBSTRING — ROWS U12 AND U13 ARE THAT DECISION
# ============================================================================
# 0614's option B says a text "whose unresolved token IS" one of the annotation
# spellings. IS, not CONTAINS, and the difference is 158 shipped records:
# sky130's 119 `hide=true` `@spice_get_node` annotations at layers 15/17, its 39
# `vgs=expr(@#1:spice_get_voltage - @#2:spice_get_voltage )` records, and
# devices/nmos4.sym:56-57 / pmos4.sym:60-61's `tcleval(vgs=[to_eng
# {@#1:spice_get_voltage …}])` at layer 15 with NO hide token. Those are DEVICE
# OP INFO, not node voltages: a substring classifier both re-gates and
# re-colours them. U12 drives the nmos4 record and U13 the shipped
# `Power: @spice_get_voltage(power)\W` floater (xschem_library/examples/
# cmos_example.sch:194); both are GREEN before and after and neither is evidence
# the feature landed.
#
# ============================================================================
# ⚠ THE LIST IS SIX SPELLINGS, NOT THE FIVE 0614 PRINTS
# ============================================================================
# ADDED: `@#<pin>:spice_get_voltage` (get_pin_attr, token.c:4315) — 0615's own
# example, bus_tap.sym:37, carries exactly that and the literal five-item list
# leaves it unfixed; and `@spice_get_diff_voltage` (token.c:5094, 8 records).
# DROPPED: `@spice_get_current<n>`, which exists nowhere in the tree and has no
# branch in token.c — a mis-transcription of `@spice_get_current_<param>`.
#
# ============================================================================
# ⚠ INVARIANT I7, AND THE NINE RECORDS THAT CARRY BOTH TOKENS
# ============================================================================
# Nine tracked records — xschem_library/pcb/pcb_current_protection_embed.sch:
# 174,441,456 and its xschem_libraries_oa/ and xschem_libs_newsym/ mirrors —
# carry `hide=true` AND a bare `@spice_get_voltage` / `@spice_get_current`.
# text_hidden() tests the CLASS bits BEFORE show_hidden_texts, so an implicit
# class set unconditionally flips all nine from show_hidden_texts-gated to
# annot_show-gated. U10 is that collision as an executable row, on a probe with
# a raw so it is not vacuous; U9 is the shipped file itself.
#
# ⚠ U9 IS DELIBERATELY ONE-SIDED, AND SAYING SO IS THE HONEST THING. Measured:
# that shipped sheet exports IDENTICALLY at show_hidden_texts 0 and 1, because
# its three hide=true texts are bare tokens that resolve to the EMPTY STRING
# with no raw loaded — the same finding row L22's header records. So U9 can only
# claim the annot_show half; U10 supplies the non-vacuity on a probe of the same
# shape with a raw behind it.
#
# ============================================================================
# ⚠ THE I7 NO-RAW BASELINE IS MEASURED, AND IT IS THE GOOD NEWS (U7 / U8)
# ============================================================================
# 0614's landmine asks what `@spice_get_voltage` renders as with no raw loaded,
# because a content class that blanks it would regress every non-annotating
# user. Measured, on u_nr.sch: it renders NOTHING — not the literal token, not
# an empty element, no element at all. The four masks are byte-identical in SVG
# and, colour-normalised (issue 0454/0619), in PS. Rows U7/U8 are GREEN before
# and MUST STAY GREEN; they are the I7 regression guard, not evidence.
#
# ============================================================================
# ⚠ USE SVG FOR BYTE COUNTS. PS BYTE COUNTS LIE — ISSUE 0619
# ============================================================================
# Every PS export containing symbol text over-reads `ps_colors[cadlayers]`
# (psprint.c:1391 allocates cadlayers, :1650 calls ps_draw_symbol with c+1 ==
# cadlayers, :1257's pop is therefore always taken). The garbage float's text
# WIDTH changes the file length: masks 0/2 measured 5638 vs 5613 and 1/3 6186 vs
# 6211 while being byte-IDENTICAL once `… RGB` lines are stripped. A PS byte
# delta is NOT evidence. U8 normalises; U18 reads the RGB line deliberately and
# is unaffected because it compares two lines inside ONE export.
#
# ============================================================================
# ⚠ WHICH ROWS ARE RED BEFORE AND WHICH ARE CONTROLS — SAY IT OUT LOUD
# ============================================================================
# RED before (18): U1 U2 U3 U6 U14 U15 U16 U17 U18 U19 U20 U21 U22 U23
#                  U25 U26 U28 U30
#
# ⚠ AND RED AGAIN, AFTER ISSUE 0678 REVERSED DECISION D4 (4): U31 U34 U35 — and
# U6, WHOSE GOLDEN FLIPPED, {0 0 1 1} -> {0 1 0 1}. U6 was green against the
# shipped D4 code and is red against it now, deliberately: that flip IS 0678,
# not a fixture drift. See the branch-current block below for the reversal, and
# rows U31/U32 for the user's own sheet.
#
# GREEN before AND after (14), every one load-bearing and NONE of them evidence
# that 0614/0615/0678 happened:
#   U4  bit0 already works (S7). It is here so a fix that moved the OP block
#       instead of the voltages reds a named row.
#   U5  non-vacuity: without it U3 passes on an exporter that draws nothing.
#   U7 U8   invariant I7, no raw, SVG and PS.
#   U9 U10  invariant I7, the explicit hide=true + bare-token collision.
#   U11 an explicit hide=voltage keeps its OWN layer= colour (decision: the
#       class bit and the colour bit are separate).
#   U12 U13 the whole-string classifier's two negatives.
#   U24 invariant I4, read BEFORE any save.
#   U27 invariant I7's ONE real exposure — a SCHEMATIC-OWN NON-FLOATER bare
#       token, which renders the LITERAL string today and must keep doing so.
#   U29 an EXPLICIT hide=voltage on that same non-floater context still follows
#       bit1: the floater guard U27 demands must apply to the IMPLICIT class
#       only, never to the class an author typed.
#   U32 0678's acceptance row 3, on the USER'S OWN SHEET: `Ctrl-6` still clears
#       the voltage source's branch current AND the node voltage, and mask 3
#       still shows both. Green before and after — bit0 and bit1 are both 0 at
#       mask 0 whichever bit owns the currents — and it is here so that a
#       reversal which re-pointed the gate at NOTHING reds a NAMED row instead
#       of leaving `Ctrl-6 -> nothing` quietly false again.
#   U33 invariant I7 for the CURRENT spelling — THE GAP U27 LEAVES. U27 covers
#       `@spice_get_voltage` only. 0678 splits one gate into two answers, and
#       the `ctx == TEXT_CTX_INSTANCE || (flags & TEXT_FLOATER)` term has to be
#       carried into BOTH; a dropped copy silently deletes a literal string the
#       user typed. Measured before the change: a schematic-own NON-FLOATER
#       `T {@spice_get_current} … {layer=17}` renders the LITERAL token at all
#       four masks, exactly as the voltage spelling does.
#
# ⚠ TWO OF THE FOUR NEW ROWS ARE ABOUT THE PRIOR ART'S TWO KNOWN HOLES. U30
# counts the EXACT call in each back end because a stopped crew's partial patch
# claimed six colour sites and delivered four (psprint.c untouched), which U19's
# file-set answer cannot see; U28 drives the two spellings 0614's five-item list
# omits, which a literal reading of that list leaves unfixed.
#
# ============================================================================
# ⚠ BRANCH CURRENTS: DECISION D4 WAS RULED THE OTHER WAY, AND ISSUE 0678
#   REVERSED IT. THE VISIBILITY HALF MOVED; THE COLOUR HALF DID NOT.
# ============================================================================
# WHAT D4 SAID (and what rows U6/U17 were first written against):
#   `@spice_get_current*` JOINS the voltage class for VISIBILITY (bit1) — 0613
#   lists branch currents among what survives Ctrl-6, so `Ctrl-6 -> nothing` is
#   false without them — and KEEPS ITS OWN LAYER for COLOUR (17 in both
#   palettes, `#00ffcc`; 84 shipped records rely on it).
#
# WHAT THE USER MEASURED ON A REAL sky130 BENCH, 2026-08-24 (issue 0678):
#   "ALT-6 is doing its job for node voltages - but it's also displaying OP info
#    of voltage sources - namely their current. That should be controlled by 6
#    key, not Alt-6. Otherwise, Alt-6 and 6 and Ctrl-6 behave as expected."
#
# So D4 grouped the two classes by WHERE THE NUMBER COMES FROM in the raw. The
# user groups them by WHAT THE NUMBER IS ABOUT: a source's branch current is
# that DEVICE's terminal current — device OP info, like a FET's id — while a
# node voltage is a property of the NET. They answer to different chords.
#
# WHAT MOVED, AND WHAT DID NOT:
#   VISIBILITY  TEXT_ANNOT_CURRENT is gated by ANNOT_SHOW_OP (bit0, `6`).
#               Rows U6 and U31. `Ctrl-6 -> nothing` is STILL true — mask 0
#               clears bit0 too — and U32 is that half as its own row.
#   COLOUR      unchanged. annot_text_layer() tests TEXT_ANNOT_VOLTAGE only, so
#               currents keep layer 17. U17 is untouched and stays GREEN: its
#               third element still holds because mask 3 sets BOTH bits.
#
# STILL REJECTED, for the same reasons: a third mask bit (Alt-6 would become 7,
# a fourth state, against a ruling table with three rows that the bench has now
# CONFIRMED correct) and folding currents into annot_voltage_layer (which erases
# the 15-vs-17 distinction the user already has). ALSO REJECTED: merging
# TEXT_ANNOT_VOLTAGE and TEXT_ANNOT_CURRENT into one bit — they are two bits
# precisely so that a re-pointing like this one is a one-line change. Row U35
# is that sentence made executable.

set U_VP  {1200 900 -200 -300 700 200}
set U_PVP {1600 1000 400 -700 1400 100}
set U_PCB [file join $repo xschem_library pcb pcb_current_protection_embed.sch]

## The fill of the FIRST SVG <text> whose rendered content is EXACTLY <marker>,
## or NO-TEXT. Exact, not a substring: `1.8` as a substring would also match a
## hypothetical `11.8`, and the whole point of these rows is which of two texts
## carries which colour.
proc opa_u_fill {svg marker} {
  foreach l [split $svg \n] {
    if {[string first "<text" $l] < 0} continue
    set tx {}
    if {![regexp {>([^<]*)</text>} $l -> tx]} continue
    if {$tx ne $marker} continue
    set fl NO-FILL ; regexp {fill="([^"]*)"} $l -> fl
    return $fl
  }
  return NO-TEXT
}
## The same, keyed on a PREFIX — for the two classifier negatives, whose
## rendered tails (`vgs=- - - `, `Power: 3.3W`) move with the raw.
proc opa_u_pfill {svg pfx} {
  foreach l [split $svg \n] {
    if {[string first "<text" $l] < 0} continue
    set tx {}
    if {![regexp {>([^<]*)</text>} $l -> tx]} continue
    if {[string first $pfx $tx] != 0} continue
    set fl NO-FILL ; regexp {fill="([^"]*)"} $l -> fl
    return $fl
  }
  return NO-TEXT
}
## 0/1 per marker, EXACT content match, in the order asked.
proc opa_u_has {svg markers} {
  set t [opa_q_texts $svg]
  set o {}
  foreach m $markers { lappend o [expr {[lsearch -exact $t $m] >= 0 ? 1 : 0}] }
  return $o
}
## The PostScript colour in effect when `(<marker>)` is `show`n, or NO-SHOW.
## ⚠ THIS IS THE ONLY WAY TO SEE A COLOUR IN A PS EXPORT. psprint.c emits
## `<r> <g> <b> RGB` as a separate statement and the string as `(text)` +
## `show` two lines later (measured, c3.ps:265-270), so the colour of a given
## string is the last RGB line before it — which is exactly what 0615's "an
## override in draw.c alone means screen and exported PDF disagree" needs.
proc opa_u_psrgb {ps marker} {
  set cur NO-RGB
  set lines [split $ps \n]
  set n [llength $lines]
  for {set i 0} {$i < $n} {incr i} {
    set l [lindex $lines $i]
    if {[regexp {^[-0-9.e+]+ [-0-9.e+]+ [-0-9.e+]+ RGB$} $l]} { set cur $l ; continue }
    if {$l eq "($marker)" && [lindex $lines [expr {$i + 1}]] eq {show}} { return $cur }
  }
  return NO-SHOW
}
## Set the mask through the surface under test and export, warmed. The mask
## write goes through opa_l_annot (`xschem set` + update_all_sym_bboxes), never
## through ::annot_show — U20 is the row that tells the two apart.
proc opa_u_pr {fmt mask out} {
  global U_VP scratch
  opa_l_annot $mask
  return [opa_l_print2 $fmt [file join $scratch $out] $U_VP]
}
## Push a candidate annot_voltage_layer through `xschem set` and re-export.
## ⚠ NEVER A BARE catch-and-discard: before 0615 `xschem set annot_voltage_layer
## N` returns rc=0 with an empty result (scheduler.c:11685 splits on argv[2][0]
## and only the >='n' half carries the `*cmd_found = 0` fall-through), so a
## catch-only writer and a real setter are indistinguishable. Row U21 is the
## control that separates them.
proc opa_u_lay {n} { catch {xschem set annot_voltage_layer $n} ; xschem update_all_sym_bboxes }
## -> 1 if SOME set_text_flags() call in src/editprop.c is guarded by a
## condition naming `text_changed`.
## ⚠ A SOURCE GREP BECAUSE THE SEAM IS UNREACHABLE HEADLESS. edit_property()
## reads its new text out of the Tk dialog (`tclgetvar("tctx::retval")`), so no
## headless row can drive it. Measured on HEAD: txt_ptr is replaced at
## editprop.c:777 under `if(text_changed)` while set_text_flags runs at :786
## under `if(props_changed)` — so a class computed from the CONTENT is stale
## after a content-only edit until the file is reloaded. U22's first element is
## the same claim on the one path a script CAN drive (`xschem setprop text n
## txt_ptr`, scheduler.c:12640, which already re-runs set_text_flags).
## Occurrences of the EXACT call `<name>(` in one .c file, or NO-FILE.
## ⚠ SHARPER THAN opa_l_cfiles, WHICH ANSWERS A FILE SET. A back end that got
## ONE of its two colour sites, or that was pointed at a private
## `annot_text_layer_ps` wrapper, still contains the substring and still
## satisfies U19; only a count of the exact call sees it.
proc opa_u_ccalls {path name} {
  if {![file isfile $path]} { return NO-FILE }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  return [llength [regexp -all -inline -- "${name}\\(" $d]]
}
## Occurrences of a LITERAL substring in one file, or NO-FILE. opa_u_ccalls's
## sibling for a claim that is about an EXPRESSION rather than a call — U35
## asserts that the FOLDED `TEXT_ANNOT_VOLTAGE | TEXT_ANNOT_CURRENT` test is
## gone from actions.c, and there is no `(` to hang opa_u_ccalls on.
## ⚠ A COMMENT COUNTS TOO, and that is the cheap direction to be wrong in: a
## comment can only make this row FAIL while the code is right, never pass
## while the code is wrong.
proc opa_u_ctext {path needle} {
  if {![file isfile $path]} { return NO-FILE }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set n 0 ; set i 0
  while {[set i [string first $needle $d $i]] >= 0} { incr n ; incr i }
  return $n
}
## -> {n_set_ne n_in_global_list} for <var> in src/xschem.tcl. opa_l_tclmirror
## with the variable name lifted out; L28 keeps its own copy so a change here
## cannot silently move what that row measures.
proc opa_u_tclmirror {p var} {
  if {![file isfile $p]} { return NO-FILE }
  set fd [open $p r] ; set lines [split [read $fd] \n] ; close $fd
  set ndef 0 ; set nlist 0 ; set in 0
  foreach l $lines {
    if {[regexp "^\\s*set_ne\\s+${var}\\s" $l]} { incr ndef }
    if {[regexp {^\s*set\s+tctx::global_list\s+\{} $l]} { set in 1 ; continue }
    if {$in && [string trim $l] eq "\}"} { set in 0 ; continue }
    if {$in} { incr nlist [llength [lsearch -all -exact [split [string trim $l]] $var]] }
  }
  return [list $ndef $nlist]
}
proc opa_u_editprop_guard {p} {
  if {![file isfile $p]} { return NO-FILE }
  set fd [open $p r] ; set lines [split [read $fd] \n] ; close $fd
  set n [llength $lines]
  for {set i 0} {$i < $n} {incr i} {
    if {[string first set_text_flags [lindex $lines $i]] < 0} continue
    for {set j [expr {$i - 1}]} {$j >= 0 && $j > $i - 12} {incr j -1} {
      set l [lindex $lines $j]
      if {[regexp {^\s*(\}\s*else\s*)?if\s*\(} $l]} {
        if {[string first text_changed $l] >= 0} { return 1 }
        break
      }
    }
  }
  return 0
}

if {[catch {

# ⚠ UNQUALIFIED, per this file's header note.
set XSCHEM_LIBRARY_PATH $S_LIBS

# ⚠ READ THE DEFAULT FIRST, BEFORE ANY ROW WRITES IT. U21 asserts it, and every
# colour row below assumes the resting value.
set U_DEFLAY [rcall {xschem get annot_voltage_layer}]

# ===========================================================================
# FIXTURE — four sheets, because the four claims cannot share one
# ===========================================================================
# u_acc.sch  the ACCEPTANCE sheet: one annotatable device (the S9b overlay is
#            the OP block), one lab_pin node voltage, one capa branch current,
#            one plain layer-15 text as the colour reference, and the two
#            classifier negatives. Carries NO hide=voltage — an explicit one
#            would give bit1 something to gate and mask 1 would stop being
#            byte-identical to mask 3, i.e. the defect U1/U2 measure would be
#            hidden by the fixture itself.
# u_nr.sch   the same MINUS the annotatable device, for the no-raw I7 rows: the
#            overlay renders label-only rows (`id =`) even with no raw (measured,
#            invariant I3), so a sheet carrying it cannot make the all-four-masks
#            claim U7 needs.
# u_hv.sch   an EXPLICIT hide=voltage text at layer 4, plus a layer-4 reference.
# u_ht.sch   the I7 collision: hide=true AND a bare @spice_get_voltage.
# u_edit.sch one top-level floater whose CONTENT U22 rewrites.
# u_own.sch  the two SCHEMATIC-OWN texts, U27 and U29: a NON-FLOATER bare
#            `@spice_get_voltage` (renders the LITERAL token today, measured)
#            and an explicit `hide=voltage`, with a layer-4 and a layer-15
#            reference beside them.
# u_vs.sch   ISSUE 0678's SHEET, and it is the USER'S CASE LITERALLY: one
#            shipped devices/vsource.sym V1 (whose `T {@spice_get_current} …
#            {layer=17}` at vsource.sym:42 is the exact record the user was
#            looking at), one lab_pin node voltage on the same sheet so the two
#            content classes can be told apart in ONE export, and the layer-15
#            reference. ⚠ NOT ADDED TO u_acc.sch: a sixth instance there reds
#            row X14 (`[xschem get instances]` 5 -> 6) and shifts every byte
#            length U1/U2/U26 measure. The branch current u_acc.sch already
#            carries is a `capa.sym` — 0678 is about a SOURCE, so the sheet
#            carries a source.
# u_pv.sch   the two spellings 0614's list omits, U28: `@#0:spice_get_voltage`
#            (bus_tap.sym:37's form, token.c:4315) and `@spice_get_diff_voltage`
#            (token.c:5094). Its nets are named by u_lab.sym — lab_pin.sym MINUS
#            its own `@spice_get_voltage` text — so `1.8` and `-1.5` belong to
#            the probe alone and cannot be satisfied by a lab_pin that happens
#            to sit on the same net.
set f [open [file join $lib u_fet.sym] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=zzu614\nformat=\"@name @pinlist @model\"\ntemplate=\"name=MU1 model=zzdev\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "L 4 -10 -10 10 -10 {}"
puts $f "L 4 10 -10 10 10 {}"
puts $f "L 4 10 10 -10 10 {}"
puts $f "L 4 -10 10 -10 -10 {}"
close $f
## ONE layer-15 text, no @ token at all: the colour reference every 0615 row
## measures against. It cannot be classified by any content rule, so it holds
## layer 15 no matter what the predicate does.
set f [open [file join $lib u_l15.sym] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=zzu614probe\ntemplate=\"name=ul15\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "L 4 0 0 0 10 {}"
puts $f "T \{ZZU15MARK\} 5 5 0 0 0.2 0.2 \{layer=15\}"
close $f
set f [open [file join $lib u_hv.sym] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=zzu614probe\ntemplate=\"name=uhv\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "L 4 0 0 0 10 {}"
puts $f "T \{ZZUHVMARK\} 5 5 0 0 0.2 0.2 \{layer=4\nhide=voltage\}"
close $f
## The nine tracked records' shape, in one probe: a label symbol whose
## @spice_get_voltage text carries hide=true. Byte-for-byte the embedded record
## at pcb_current_protection_embed.sch:456 but for the vcenter token.
set f [open [file join $lib u_ht.sym] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=label\nformat=\"*.alias @lab\"\ntemplate=\"name=up3 lab=xxx\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "B 5 -1.25 -1.25 1.25 1.25 \{name=p dir=in\}"
puts $f "T \{@lab\} -7.5 -8.125 0 1 0.33 0.33 {}"
puts $f "T \{@spice_get_voltage\} 1.875 3.90625 0 0 0.2 0.2 \{layer=15\nhide=true\}"
close $f

## ⚠ THE FLOATER SPELLING IS LOAD-BEARING ON THE TWO @-CARRYING TOP-LEVEL TEXTS.
## get_text_floater() translates ONLY floaters, so a plain top-level text
## containing `@spice_get_voltage` renders the LITERAL token. The shipped
## example (cmos_example.sch:194) is `floater=true`, and U13 and U22 copy it.
set f [open [file join $lib u_acc.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "C \{u_fet.sym\} 0 0 0 0 \{name=MU1\}"
puts $f "C \{lab_pin.sym\} 0 -60 0 0 \{name=up1 lab=d\}"
puts $f "C \{capa.sym\} 200 0 0 0 \{name=C1 value=1p\}"
puts $f "C \{u_l15.sym\} 300 -100 0 0 \{name=ul15\}"
puts $f "C \{nmos4.sym\} 420 0 0 0 \{name=MN4\}"
puts $f "T \{Power: @spice_get_voltage(power)\\\\W\} 0 -160 0 0 0.4 0.4 \{floater=true layer=15\}"
close $f
set f [open [file join $lib u_nr.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "C \{lab_pin.sym\} 0 -60 0 0 \{name=up1 lab=d\}"
puts $f "C \{capa.sym\} 200 0 0 0 \{name=C1 value=1p\}"
puts $f "C \{u_l15.sym\} 300 -100 0 0 \{name=ul15\}"
puts $f "C \{nmos4.sym\} 420 0 0 0 \{name=MN4\}"
puts $f "T \{Power: @spice_get_voltage(power)\\\\W\} 0 -160 0 0 0.4 0.4 \{floater=true layer=15\}"
close $f
set f [open [file join $lib u_hv.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "C \{u_hv.sym\} 0 -100 0 0 \{name=uhv\}"
puts $f "C \{u_l15.sym\} 200 -100 0 0 \{name=ul15\}"
puts $f "T \{ZZU4MARK\} 0 -160 0 0 0.4 0.4 \{layer=4\}"
close $f
set f [open [file join $lib u_ht.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "C \{u_ht.sym\} 0 -100 0 0 \{name=up3 lab=d\}"
puts $f "C \{u_l15.sym\} 200 -100 0 0 \{name=ul15\}"
close $f
set f [open [file join $lib u_edit.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "C \{u_l15.sym\} 200 -100 0 0 \{name=ul15\}"
puts $f "T \{ZZUEDITMARK\} 0 -160 0 0 0.4 0.4 \{floater=true layer=4\}"
close $f

## U27/U29/U33's sheet: SCHEMATIC-OWN texts, which is a different context from
## every other sheet here. Measured on this tree, with a raw loaded or without:
## a NON-FLOATER `T {@spice_get_voltage}` renders the LITERAL STRING
## `@spice_get_voltage` (get_text_floater() translates only floaters), while the
## SAME token in a SYMBOL emits no element at all. The layer-4 reference sits
## beside the explicit hide=voltage so U29 can say "kept its own colour" without
## naming a palette constant.
## ⚠ THE CURRENT SPELLING AND ITS LAYER-17 REFERENCE ARE ISSUE 0678's (U33).
## Before 0678 both content classes left this predicate through ONE `if`, so
## U27 guarded both by accident. 0678 splits it in two and the ctx term has to
## be carried into BOTH branches; a dropped copy blanks a literal string the
## user typed, and nothing in the tree would have seen it. Measured before the
## change: this record renders `@spice_get_current` at all four masks, in
## layer 17.
set f [open [file join $lib u_own.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "C \{u_l15.sym\} 300 -100 0 0 \{name=ul15\}"
puts $f "T \{@spice_get_voltage\} 0 -200 0 0 0.4 0.4 \{layer=15\}"
puts $f "T \{ZZUOWNHV\} 0 -240 0 0 0.4 0.4 \{layer=4\nhide=voltage\}"
puts $f "T \{ZZUOWN4\} 0 -280 0 0 0.4 0.4 \{layer=4\}"
puts $f "T \{@spice_get_current\} 0 -160 0 0 0.4 0.4 \{layer=17\}"
puts $f "T \{ZZUOWN17\} 0 -120 0 0 0.4 0.4 \{layer=17\}"
close $f

## U28's fixture. u_lab.sym is devices/lab_pin.sym MINUS its own
## `@spice_get_voltage` text, so the two nets get NAMES without any second
## producer of a voltage string: `1.8` and `-1.5` on the exported sheet belong
## to the probe alone. With a real lab_pin there the row would still pass on an
## implementation that classified the BARE token and missed both of the
## spellings under test.
set f [open [file join $lib u_lab.sym] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=label\nformat=\"*.alias @lab\"\ntemplate=\"name=p1 lab=xxx\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "B 5 -1.25 -1.25 1.25 1.25 \{name=p dir=in\}"
puts $f "T \{@lab\} -7.5 -8.125 0 1 0.33 0.33 {}"
close $f
## TWO pins, because @spice_get_diff_voltage answers only on a 2-pin symbol
## (token.c:5102, `no_of_pins == 2`). Pin 0 sits on `d` (1.8) and pin 1 on
## `power` (3.3), so the diff is a clean -1.5 that nothing else can render.
set f [open [file join $lib u_pv.sym] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=zzu614probe\ntemplate=\"name=upv\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "L 4 0 0 0 40 {}"
puts $f "B 5 -2.5 -2.5 2.5 2.5 \{name=A dir=inout\}"
puts $f "B 5 -2.5 37.5 2.5 42.5 \{name=B dir=inout\}"
puts $f "T \{@#0:spice_get_voltage\} 8 -6 0 0 0.2 0.2 \{layer=15\}"
puts $f "T \{@spice_get_diff_voltage\} 8 44 0 0 0.2 0.2 \{layer=15\}"
close $f
set f [open [file join $lib u_pv.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "N 0 0 100 0 \{lab=d\}"
puts $f "N 0 40 100 40 \{lab=power\}"
puts $f "C \{u_lab.sym\} 0 0 0 0 \{name=up1 lab=d\}"
puts $f "C \{u_lab.sym\} 0 40 0 0 \{name=up2 lab=power\}"
puts $f "C \{u_pv.sym\} 100 0 0 0 \{name=upv\}"
puts $f "C \{u_l15.sym\} 300 -100 0 0 \{name=ul15\}"
close $f

## The raw. Four device/branch vectors in the R3 shapes plus the two node
## voltages. `i(@c1[i])` is the shape get_fqdevice() builds for a top-level
## 2-terminal non-model device (token.c:4565, the `else` arm), NOT a guess:
## measured, the capa's `@spice_get_current` renders `12.5u` from it.
set f [open [file join $scratch u_op.raw] w]
puts -nonewline $f "Title: 0614/0615 fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 5
No. Points: 1
Variables:
\t0\ti(@m.xmu1.mu\[id\])\tcurrent
\t1\t@m.xmu1.mu\[gm\]\tadmittance
\t2\tv(d)\tvoltage
\t3\ti(@c1\[i\])\tcurrent
\t4\tv(power)\tvoltage
Values:
0\t1e-05
\t1e-04
\t1.8
\t1.25e-05
\t3.3
"
close $f
set U_RAW [file join $scratch u_op.raw]

## ===========================================================================
## ISSUE 0678's FIXTURE — THE USER'S CASE, LITERALLY
## ===========================================================================
## One SHIPPED devices/vsource.sym. Its `T {@spice_get_current} 20 -6.25 0 0
## 0.2 0.2 {layer=17}` (vsource.sym:42) is the exact record the user was looking
## at when they reported that `Alt-6` was showing a source's current. One
## lab_pin on net `d` puts a NODE VOLTAGE on the same sheet, so one export tells
## the two content classes apart; the layer-15 reference keeps a colour claim
## available without naming a palette constant.
set f [open [file join $lib u_vs.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "N 0 -60 0 -30 \{lab=d\}"
puts $f "N 0 30 0 60 \{lab=GND\}"
puts $f "C \{vsource.sym\} 0 0 0 0 \{name=V1 value=5\}"
puts $f "C \{lab_pin.sym\} 0 -60 0 0 \{name=up1 lab=d\}"
puts $f "C \{gnd.sym\} 0 60 0 0 \{name=l1 lab=GND\}"
puts $f "C \{u_l15.sym\} 300 -100 0 0 \{name=ul15\}"
close $f
## `i(v1)` is the shape get_fqdevice() builds for a TOP-LEVEL v-prefixed device
## (token.c:4553), not a guess: measured on this tree, the vsource's
## `@spice_get_current` renders `-321u` out of exactly this vector.
set f [open [file join $scratch u_vs.raw] w]
puts -nonewline $f "Title: 0678 fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\ti(v1)\tcurrent
\t1\tv(d)\tvoltage
Values:
0\t-3.21e-04
\t1.8
"
close $f
## The SAME raw MINUS the branch-current vector — invariant I3's raw, for U34.
set f [open [file join $scratch u_vs2.raw] w]
puts -nonewline $f "Title: 0678 fixture, no i(v1)
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 1
No. Points: 1
Variables:
\t0\tv(d)\tvoltage
Values:
0\t1.8
"
close $f
set U_VSRAW  [file join $scratch u_vs.raw]
set U_VSRAW2 [file join $scratch u_vs2.raw]
## ⚠ ITS OWN SYMBOL TYPE. `nmos` would clobber the sky130 descriptor sections P,
## S and Q left in the store; `zzu614` collides with nothing.
proc opa_u_devproc {instname model path spiceprefix} { return {@m.xmu1.mu} }
catch {op_annot::register zzu614 \
  [list devproc opa_u_devproc params {{id id 0} {gm gm 1}}]}

opa_l_sht 0
catch {xschem raw clear}
xschem load [file join $lib u_acc.sch]
opa_l_annot 0
set U_W_NORAW [opa_l_w up1]
set u_ann [rcall [list xschem annotate_op $U_RAW]]

check {X14 FIXTURE u_acc.sch: five instances, the raw annotates, and the block reads back} \
  [list [lindex $u_ann 0] [xschem get instances] [xschem get texts] \
        [xschem getprop instance MU1 cell::type] \
        [rcall {op_annot::text MU1}] [opa_t_v {v(d)}]] \
  [list 0 5 1 zzu614 [list 0 "id = 10u\ngm = 100u\n"] 1.8]

foreach m {0 1 2 3} { set u_s($m) [opa_u_pr svg $m u_m$m.svg] }

# ===========================================================================
# U1 / U2 — THE 0614 ACCEPTANCE, STATED TWICE ON PURPOSE
# ===========================================================================
# ⚠ SVG, NEVER PS — see this section's header (issue 0619). Strictly increasing
# is part of the claim: mask 0 is the emptiest sheet, mask 1 adds the block,
# mask 3 adds the voltages on top. A fix that merely made the three DIFFER
# without that order would mean the mask bits do not compose.
check {U1 0614 ACCEPTANCE: masks 0 / 1 / 3 are THREE distinct SVG renders, strictly increasing} \
  [list [llength [lsort -unique [list [string length $u_s(0)] \
                                     [string length $u_s(1)] \
                                     [string length $u_s(3)]]]] \
        [expr {[string length $u_s(0)] < [string length $u_s(1)]}] \
        [expr {[string length $u_s(1)] < [string length $u_s(3)]}]] \
  {3 1 1}

# ⚠ THE DEFECT AS ITS OWN ROW, so a partial fix cannot hide behind U1's
# ordering. This is the byte-identity the user measured (169897 == 169897).
check {U2 `6` and `Alt-6` are no longer the same picture (mask 1 != mask 3)} \
  [list [expr {$u_s(1) ne $u_s(3)}] [expr {$u_s(0) ne $u_s(2)}]] {1 1}

# ⚠ THE ACCEPTANCE SENTENCE LITERALLY — "FOUR renders with FOUR distinct byte
# counts" — AND NEITHER U1 NOR U2 IS IT. U1 claims three (0/1/3) and U2 claims
# two inequalities; an implementation that gave bit1 teeth but left `Alt-6`
# force-setting bit0 satisfies both and still reaches only THREE pictures,
# because mask 2 would be unreachable from the chords. Measured before the
# change: 0 == 2 and 1 == 3, so this answers 2.
check {U26 0614 ACCEPTANCE: the four masks are FOUR pairwise-distinct SVG renders} \
  [llength [lsort -unique [list $u_s(0) $u_s(1) $u_s(2) $u_s(3)]]] 4

# ===========================================================================
# U3 / U4 / U6 — WHAT EACH CHORD ACTUALLY SHOWS
# ===========================================================================
# ⚠ `6` GETS STRICTER, NOT JUST `Ctrl-6`. The ruling's table needs mask 1 to
# ACTIVELY turn the voltages off; otherwise Alt-6 still cannot be told from 6.
set u_v {} ; foreach m {0 1 2 3} { lappend u_v [lindex [opa_u_has $u_s($m) 1.8] 0] }
check {U3 0614 the node voltage follows bit1: OFF at masks 0 and 1, ON at 2 and 3} \
  $u_v {0 0 1 1}

# ⚠ GREEN BEFORE AND AFTER. bit0 already works (S7); this row is here so that a
# fix which moved the OP BLOCK instead of the voltages reds a NAMED row rather
# than passing as "three distinct renders".
## ⚠ `[list {id = 10u}]`, NOT `{id = 10u}`: opa_u_has takes a LIST of markers and
## the bare braces would be three markers (`id`, `=`, `10u`), every one of which
## matches nothing, so the row would answer {0 0 0 0} and look like a red.
set u_o {} ; foreach m {0 1 2 3} { lappend u_o [lindex [opa_u_has $u_s($m) [list {id = 10u}]] 0] }
check {U4 the OP block keeps bit0 and ONLY bit0: ON at masks 1 and 3, OFF at 0 and 2} \
  $u_o {0 1 0 1}

# ⚠ NON-VACUITY FOR U3. Without it an exporter that drew nothing at all would
# satisfy "absent at masks 0 and 1". The second element proves the number on the
# sheet is the raw's, not a leftover.
check {U5 NON-VACUITY at mask 3 the voltage really is the raw's v(d), rendered} \
  [list [opa_t_v {v(d)}] [lindex [opa_u_has $u_s(3) 1.8] 0] \
        [expr {[opa_u_fill $u_s(3) 1.8] ne {NO-TEXT}}]] \
  {1.8 1 1}

# ⚠ THE HALF THAT MAKES `Ctrl-6 -> nothing` TRUE. 0613's surviving list is
# `1.8 VCC … and branch currents 4.854u 2.43u …` — the currents are in it, so a
# fix that classified only voltages leaves Ctrl-6 still painting. That is still
# true and mask 0 is still the row that says so; what CHANGED is which of the
# two ADDITIVE bits brings them back.
#
# ⚠ THE GOLDEN FLIPPED WITH ISSUE 0678, {0 0 1 1} -> {0 1 0 1}, AND THAT IS THE
# WHOLE STEP. 0614's decision D4 put TEXT_ANNOT_CURRENT on the voltage switch
# because both numbers come out of the same raw. The user drove a real sky130
# bench on 2026-08-24 and ruled the other way: a source's branch current is that
# DEVICE's terminal current, i.e. device OP info, so it belongs to `6` (bit0)
# beside the id=/gm= block, not to `Alt-6`. `Ctrl-6 -> nothing` survives the move
# untouched — mask 0 clears bit0 as well — and rows U31/U32 make both halves of
# that on the user's own sheet, with a SOURCE rather than this fixture's capa.
# This row is the same claim on the capa: whatever bit the currents follow, they
# must follow it for EVERY device that carries the token.
set u_c {} ; foreach m {0 1 2 3} { lappend u_c [lindex [opa_u_has $u_s($m) 12.5u] 0] }
check {U6 0678 the branch current follows bit0 (device OP info): OFF at masks 0 and 2, ON at 1 and 3} \
  $u_c {0 1 0 1}

# ===========================================================================
# U35 — 0678's `DO NOT FOLD THE TWO FLAGS TOGETHER`, MADE EXECUTABLE
# ===========================================================================
# ⚠ THE ONE ROW THAT SURVIVES A RENDER-LEVEL COINCIDENCE. Every other 0678 row
# reads pixels; this one reads the source, because the issue's own landmine is
# structural: TEXT_ANNOT_VOLTAGE (bit 8) and TEXT_ANNOT_CURRENT (bit 9) are two
# separate bits (xschem.h:422-423) PRECISELY so that re-pointing one class is a
# one-line change, and the defect 0678 fixes is a single `if` that folded them
# back into one test:
#
#     if(flags & (TEXT_ANNOT_VOLTAGE | TEXT_ANNOT_CURRENT)) { … ANNOT_SHOW_VOLTAGE … }
#
# So: the folded expression must be GONE from actions.c, and the answer to
# "which annot_show bit owns this content class" must live in exactly ONE named
# place — `annot_class_mask()`, defined once and called once, shaped like its
# colour twin annot_text_layer(flags, ctx) so the two cannot drift (invariant
# I1). The `ctx` term rides INSIDE it, which is what makes invariant I7's
# exemption structurally undroppable rather than a line someone must remember
# to copy — U33 is the render-level half of that.
# Measured before the change: {0 1}.
check {U35 0678 the grouping lives in ONE named place and the folded flag test is gone} \
  [list [opa_u_ccalls [file join $repo src actions.c] annot_class_mask] \
        [opa_u_ctext  [file join $repo src actions.c] {TEXT_ANNOT_VOLTAGE | TEXT_ANNOT_CURRENT}]] \
  {2 0}

# ===========================================================================
# U7 / U8 — INVARIANT I7: WITH NO RAW LOADED, NOTHING MOVES
# ===========================================================================
# ⚠ GREEN BEFORE AND AFTER; THIS IS 0614's NAMED REGRESSION GUARD, NOT EVIDENCE.
# The claim the acceptance asks for is cross-process ("byte-identically to
# before the change"), which no in-process row can make. Its exact in-process
# proxy is the pair 0 vs 2 and 1 vs 3: with no raw, TOGGLING bit1 — the bit that
# gains a whole new population of texts — must change nothing at all, in either
# format. Non-vacuous because the sheet is not empty: the two classifier
# negatives and the layer-15 reference all render, and a substring classifier
# would take them away and red this row.
#
# ⚠ IT IS THE bit1 PAIRS, NOT ALL FOUR MASKS, AND THAT IS NOT A WEAKENING. This
# file registers descriptors for `nmos` (sections P and Q) and the sheet carries
# a shipped devices/nmos4.sym, whose K type IS `nmos` — so the S9b overlay fires
# on it and paints label-only rows (`id  =`, invariant I3) even with no raw.
# That is bit0's business and S7/S9's, measured green by rows L23/O2/Q4; folding
# it into this row would make an I7 guard fail for a reason I7 says nothing
# about. 0 vs 2 and 1 vs 3 hold bit0 fixed and vary exactly the bit under test.
catch {xschem raw clear}
xschem load [file join $lib u_nr.sch]
foreach m {0 1 2 3} { set u_nrs($m) [opa_u_pr svg $m u_nr$m.svg] }
check {U7 I7 NO RAW: toggling bit1 changes nothing in SVG, and the sheet is not empty} \
  [list [expr {$u_nrs(0) eq $u_nrs(2)}] [expr {$u_nrs(1) eq $u_nrs(3)}] \
        [expr {$u_nrs(0) ne $u_nrs(1)}] \
        [opa_u_has $u_nrs(0) {ZZU15MARK 1.8 12.5u}]] \
  {1 1 1 {1 0 0}}

foreach m {0 1 2 3} { set u_nrp($m) [opa_l_normps [opa_u_pr ps $m u_nr$m.ps]] }
check {U8 I7 NO RAW, PS: the identical claim through psprint.c, colour-normalised (issue 0454/0619)} \
  [list [expr {$u_nrp(0) eq $u_nrp(2)}] [expr {$u_nrp(1) eq $u_nrp(3)}] \
        [expr {$u_nrp(0) ne $u_nrp(1)}] \
        [expr {[string length $u_nrp(0)] > 3000}]] \
  {1 1 1 1}

# ===========================================================================
# U9 / U10 — INVARIANT I7: hide=true AND A BARE TOKEN ON THE SAME RECORD
# ===========================================================================
# ⚠ THE SHIPPED FILE, AND IT IS DELIBERATELY ONE-SIDED. See this section's
# header: its three hide=true bare tokens resolve to the EMPTY STRING with no
# raw, so show_hidden_texts cannot move it and only the annot_show half is
# claimable here. U10 supplies the other half.
# ⚠ 0 vs 2, for the same reason U7 uses the bit1 pairs: that sheet carries a
# devices/nmos.sym whose type this file has a live descriptor for, so bit0 moves
# its render legitimately.
set u_savepath $XSCHEM_LIBRARY_PATH
set XSCHEM_LIBRARY_PATH ":[file join $repo xschem_library]:[file join $repo xschem_library devices]"
xschem load $U_PCB
foreach a {0 2} {
  foreach sh {0 1} {
    opa_l_annot $a ; opa_l_sht $sh
    set u_pcb($a,$sh) [opa_l_print2 svg [file join $scratch u_pcb$a$sh.svg] $U_PVP]
  }
}
opa_l_sht 0
check {U9 I7 SHIPPED: pcb_current_protection_embed.sch is identical with bit1 off and on, at both show_hidden_texts} \
  [list [expr {$u_pcb(0,0) eq $u_pcb(2,0)}] [expr {$u_pcb(0,1) eq $u_pcb(2,1)}] \
        [expr {[string length $u_pcb(0,0)] > 10000}]] {1 1 1}
set XSCHEM_LIBRARY_PATH $u_savepath

# ⚠ THE ROW THAT KILLS THE UNCONDITIONAL IMPLICIT CLASS. text_hidden() tests the
# CLASS bits before show_hidden_texts, so a class set on top of an explicit
# hide=true silently re-gates the nine tracked records this probe copies. Here
# the raw IS loaded, so the text renders `1.8` at show_hidden_texts 1 and the
# row is not vacuous in the way U9 is.
catch {xschem raw clear}
xschem load [file join $lib u_ht.sch]
set u_ht_ann [lindex [rcall [list xschem annotate_op $U_RAW]] 0]
foreach a {0 3} {
  foreach sh {0 1} {
    opa_l_annot $a ; opa_l_sht $sh
    set u_hts($a,$sh) [opa_u_has [opa_l_print2 svg \
      [file join $scratch u_ht$a$sh.svg] $U_VP] {1.8 ZZU15MARK}]
  }
}
opa_l_sht 0
check {U10 I7 an EXPLICIT hide=true on a bare @spice_get_voltage still answers show_hidden_texts ONLY} \
  [list $u_ht_ann $u_hts(0,0) $u_hts(0,1) $u_hts(3,0) $u_hts(3,1)] \
  {0 {0 1} {1 1} {0 1} {1 1}}

# ===========================================================================
# U11 — AN EXPLICIT hide=voltage GETS THE CLASS, NOT THE COLOUR
# ===========================================================================
# ⚠ GREEN BEFORE AND AFTER, AND IT IS A DECISION WRITTEN AS A ROW. An author who
# typed `hide=voltage` declared a VISIBILITY class and chose their own `layer=`;
# 0615's colour is for the texts the tree classifies IMPLICITLY by content. So
# the two must be separate bits, and this row is what says so: ZZUHVMARK follows
# bit1 exactly as L8 says, and paints in layer 4 — the same fill as the plain
# layer-4 reference on the same sheet — at every mask where it is visible.
xschem load [file join $lib u_hv.sch]
foreach m {0 1 2 3} { set u_hvs($m) [opa_u_pr svg $m u_hv$m.svg] }
check {U11 an explicit hide=voltage follows bit1 AND keeps its own layer= colour} \
  [list [lindex [opa_u_has $u_hvs(0) ZZUHVMARK] 0] \
        [lindex [opa_u_has $u_hvs(1) ZZUHVMARK] 0] \
        [lindex [opa_u_has $u_hvs(2) ZZUHVMARK] 0] \
        [lindex [opa_u_has $u_hvs(3) ZZUHVMARK] 0] \
        [expr {[opa_u_fill $u_hvs(3) ZZUHVMARK] eq [opa_u_fill $u_hvs(3) ZZU4MARK]}] \
        [expr {[opa_u_fill $u_hvs(3) ZZUHVMARK] ne [opa_u_fill $u_hvs(3) ZZU15MARK]}]] \
  {0 0 1 1 1 1}

# ===========================================================================
# U12 / U13 — THE CLASSIFIER'S TWO NEGATIVES (whole-string, not substring)
# ===========================================================================
# ⚠ GREEN BEFORE AND AFTER. devices/nmos4.sym:56-57 carries
# `tcleval(vgs=[to_eng {@#1:spice_get_voltage - @#2:spice_get_voltage }] …)` at
# layer 15 with NO hide token — DEVICE OP info, and 158 shipped records share
# its shape. A substring classifier hides it at mask 0 and repaints it at mask 3.
xschem load [file join $lib u_acc.sch]
set u_ann2 [lindex [rcall [list xschem annotate_op $U_RAW]] 0]
foreach m {0 1 2 3} { set u_s($m) [opa_u_pr svg $m u_m$m.svg] }
check {U12 CLASSIFIER NEGATIVE nmos4's tcleval vgs= record still renders at mask 0 and keeps layer 15} \
  [list $u_ann2 \
        [expr {[opa_u_pfill $u_s(0) {vgs=}] ne {NO-TEXT}}] \
        [expr {[opa_u_pfill $u_s(0) {vgs=}] eq [opa_u_fill $u_s(0) ZZU15MARK]}] \
        [expr {[opa_u_pfill $u_s(3) {vgs=}] eq [opa_u_fill $u_s(3) ZZU15MARK]}]] \
  {0 1 1 1}

# ⚠ THE SHIPPED PROSE FORM. `Power: @spice_get_voltage(power)\W` is
# xschem_library/examples/cmos_example.sch:194 (and three mirrors) verbatim — a
# floater whose token is EMBEDDED in a sentence. "IS the token" keeps it;
# "CONTAINS the token" deletes a label the user typed on purpose.
check {U13 CLASSIFIER NEGATIVE the shipped `Power: @spice_get_voltage(power)\W` floater still renders at mask 0} \
  [list [expr {[opa_u_pfill $u_s(0) {Power:}] ne {NO-TEXT}}] \
        [expr {[opa_u_pfill $u_s(0) {Power:}] eq [opa_u_fill $u_s(0) ZZU15MARK]}] \
        [lindex [opa_u_has $u_s(0) [list {Power: 3.3W}]] 0]] \
  {1 1 1}

# ===========================================================================
# U14 — 0615's ACCEPTANCE: THE TWO ANNOTATIONS STOP SHARING A COLOUR
# ===========================================================================
# ⚠ MEASURED AGAINST TWO REFERENCES IN THE SAME EXPORT, NEVER A PALETTE
# CONSTANT — L23/O20's technique. The OP block is ANNOT_OVERLAY_LAYER
# (actions.c:1256) = 15 and ZZU15MARK is a plain layer-15 text; today all three
# render `#ff7777` on the dark palette (`#aa2222` on light), which is exactly
# the collision the user reported. The third element keeps the row honest: the
# two references must still agree with each other, or "differs from both" could
# be satisfied by an export in which everything differs from everything.
check {U14 0615 ACCEPTANCE: at mask 3 the node voltage's fill differs from the OP block's AND from layer 15} \
  [list [expr {[opa_u_fill $u_s(3) 1.8] ne [opa_u_fill $u_s(3) {id = 10u}]}] \
        [expr {[opa_u_fill $u_s(3) 1.8] ne [opa_u_fill $u_s(3) ZZU15MARK]}] \
        [expr {[opa_u_fill $u_s(3) {id = 10u}] eq [opa_u_fill $u_s(3) ZZU15MARK]}]] \
  {1 1 1}

# ===========================================================================
# U15 / U16 — THE OVERRIDE IS A LAYER INDEX, AND IT HAS AN OFF SWITCH
# ===========================================================================
# ⚠ WITHOUT U15, U14 WOULD PASS ON ANY IMPLEMENTATION THAT MADE THE VOLTAGE
# *SOME* OTHER COLOUR. Pointing annot_voltage_layer at 15 must put it back
# exactly where it was — that is what proves the row is measuring the override
# and not two unrelated layers.
opa_u_lay 15
set u_l15s [opa_u_pr svg 3 u_lay15.svg]
check {U15 NON-VACUITY `xschem set annot_voltage_layer 15` puts the voltage back on the OP block's colour} \
  [list [expr {[opa_u_fill $u_s(3) 1.8] ne [opa_u_fill $u_s(3) ZZU15MARK]}] \
        [expr {[opa_u_fill $u_l15s 1.8] eq [opa_u_fill $u_l15s ZZU15MARK]}] \
        [lindex [opa_u_has $u_l15s 1.8] 0]] \
  {1 1 1}

# ⚠ THE REBUILD-FREE OFF RAMP. 0615 ships a default (9) that is white only on
# the DEFAULT dark palette — it is `#00aaaa` on the default light one and
# `#6000e0` under rainbow_colors (xschem.tcl:16413-16434). A user who wants the
# pre-change look must be able to say so in one line of xschemrc, and an
# out-of-range index is the documented way: the override simply does not apply
# and the symbol's own `layer=` wins again.
opa_u_lay -1
set u_loffs [opa_u_pr svg 3 u_layoff.svg]
check {U16 OFF SWITCH an out-of-range annot_voltage_layer restores the text's own layer=} \
  [list [expr {[opa_u_fill $u_loffs 1.8] eq [opa_u_fill $u_loffs ZZU15MARK]}] \
        [expr {[opa_u_fill $u_s(3) 1.8] ne [opa_u_fill $u_s(3) ZZU15MARK]}] \
        [lindex [opa_u_has $u_loffs 1.8] 0]] \
  {1 1 1}

# ===========================================================================
# U17 — THE BRANCH-CURRENT DECISION, WRITTEN AS A CHECK (0615 demands it)
# ===========================================================================
# DECIDED: currents follow bit0 for VISIBILITY (U6, and issue 0678 reversed D4
# to put them there) and keep their own COLOUR. ⚠ THIS ROW IS UNAFFECTED BY THAT
# REVERSAL and stays GREEN: annot_text_layer() tests TEXT_ANNOT_VOLTAGE alone,
# so the colour half of D4 was never in question, and every element below is
# read at mask 3, where BOTH bits are set and both classes render.
# Layer 17 is `#00ffcc` in BOTH palettes and 84 shipped records rely on it; the
# 15-vs-17 distinction is one the user already has and folding it away would be
# a loss, not a fix. The third element is what discriminates: point
# annot_voltage_layer AT 17 and the voltage must land ON the current's colour —
# which can only happen if the current stayed at 17 while the voltage moved.
opa_u_lay 17
set u_l17s [opa_u_pr svg 3 u_lay17.svg]
opa_u_lay 9
check {U17 D4 branch currents keep layer 17: distinct from the voltage and from layer 15, and the voltage can be moved onto them} \
  [list [expr {[opa_u_fill $u_s(3) 12.5u] ne [opa_u_fill $u_s(3) 1.8]}] \
        [expr {[opa_u_fill $u_s(3) 12.5u] ne [opa_u_fill $u_s(3) ZZU15MARK]}] \
        [expr {[opa_u_fill $u_l17s 12.5u] eq [opa_u_fill $u_l17s 1.8]}]] \
  {1 1 1}

# ===========================================================================
# U18 — ALL THREE BACK ENDS, WHICH IS 0615's SHARPEST LANDMINE
# ===========================================================================
# ⚠ "An override in draw.c alone means the schematic on screen and the exported
# PDF disagree." U14-U17 are svgdraw.c. This row is psprint.c, read through the
# `<r> <g> <b> RGB` statement that precedes the `(text) show` pair — the only
# way a colour is visible in a PS file. draw.c has NO headless execution oracle
# at all (draw()'s body is inside `if(has_x)`, draw.c:10377), so U19's source-set
# row is the only guard it gets and this feature owes an eyeball besides.
set u_ps3 [opa_u_pr ps 3 u_m3.ps]
check {U18 PS BACK END: the voltage's RGB statement differs from layer 15's, and the current's still does too} \
  [list [expr {[opa_u_psrgb $u_ps3 1.8] ne [opa_u_psrgb $u_ps3 ZZU15MARK]}] \
        [expr {[opa_u_psrgb $u_ps3 12.5u] ne [opa_u_psrgb $u_ps3 ZZU15MARK]}] \
        [expr {[opa_u_psrgb $u_ps3 1.8] ne {NO-SHOW}}]] \
  {1 1 1}

# ⚠ THE SOURCE-SET ROW, L27's technique. The colour override has the same
# three-back-end fan-out the visibility test has, and draw.c's site is the ONE
# the user actually looks at and the one no headless row can execute.
check {U19 the colour override reaches all three back ends from ONE helper} \
  [opa_l_cfiles [file join $repo src] annot_text_layer] \
  {actions.c draw.c psprint.c svgdraw.c}

# ⚠ U19 IS A FILE SET AND THAT IS NOT ENOUGH — THE PRIOR ART PROVES IT. A
# stopped crew's partial patch carries the comment "six colour sites (draw.c x2,
# svgdraw.c x2, psprint.c x2)" and its diff touches four: psprint.c is not in
# it at all. One call in psprint.c, or a per-file `annot_text_layer_ps` wrapper,
# satisfies U19 while screen and exported PDF still disagree — 0615's sharpest
# landmine. There are TWO sites per back end (instance text and schematic-own
# text): draw.c:875-886 + :10650, svgdraw.c:931-940 + :1330, psprint.c:1213-1224
# + :1702, so the count is 2 in each.
# ⚠ IT COUNTS THE EXACT CALL `annot_text_layer(`, so a mention in a comment
# would count too. That is the cheap direction to be wrong in: a comment cannot
# make this row pass while the code is missing, only the reverse.
check {U30 the override is CALLED twice in each of the three back ends, psprint.c included} \
  [list [opa_u_ccalls [file join $repo src draw.c]    annot_text_layer] \
        [opa_u_ccalls [file join $repo src svgdraw.c] annot_text_layer] \
        [opa_u_ccalls [file join $repo src psprint.c] annot_text_layer]] \
  {2 2 2}

# ===========================================================================
# U20 / U21 — THE MIRROR: PULLED AT THE EXPORT ENTRY, PUSHED BY THE SETTER
# ===========================================================================
# ⚠ L17's DEFECT SHAPE, ON THE NEW VARIABLE. `show_hidden_texts` is refreshed at
# three sites and none of them is an export entry, so its FIRST export after a
# Tcl-side change renders with the OLD value (issue 0453). annot_show avoided
# that by riding annot_show_sync_cache(), which is already called at all six
# bulk-evaluation entry points; annot_voltage_layer must ride the same pull.
# This row writes ONLY the Tcl variable — never `xschem set`.
set ::annot_voltage_layer 15
set u_t15 [opa_l_print2 svg [file join $scratch u_t15.svg] $U_VP]
set ::annot_voltage_layer 9
set u_t9 [opa_l_print2 svg [file join $scratch u_t9.svg] $U_VP]
check {U20 NO STALE MIRROR: a Tcl-only annot_voltage_layer write reaches the export} \
  [list [expr {[opa_u_fill $u_t15 1.8] eq [opa_u_fill $u_t15 ZZU15MARK]}] \
        [expr {[opa_u_fill $u_t9  1.8] ne [opa_u_fill $u_t9  ZZU15MARK]}]] \
  {1 1}

# ⚠ D4's PUSH HALF, AND THE DEFAULT. `xschem set` splits on argv[2][0] and 'a'
# lands in the half with no `*cmd_found = 0` fall-through, so today
# `xschem set annot_voltage_layer 7` returns rc=0 and does NOTHING — which is
# why this row asserts the VALUE that comes back out, in both directions, and
# never a raise. The first element is 0615's recommended default.
catch {xschem set annot_voltage_layer 7}
check {U21 SETTER/GETTER annot_voltage_layer defaults to 9 and the setter pushes to Tcl too} \
  [list $U_DEFLAY [rcall {xschem get annot_voltage_layer}] \
        [expr {[info exists ::annot_voltage_layer] ? $::annot_voltage_layer : {NO-VAR}}]] \
  {{0 9} {0 7} 7}
opa_u_lay 9

# ===========================================================================
# U25 — THE PER-TAB HOLE, WHICH NO RUNTIME ROW CAN EVER SEE (L28's technique)
# ===========================================================================
# ⚠ TWO EDITS IN src/xschem.tcl, OR THE NEW VARIABLE IS ONLY HALF THERE.
#   (a) a `set_ne annot_voltage_layer 9` default. Without it the C-side pull
#       reads a variable that does not exist — and the pull must NOT use
#       tclgetintvar(), which answers 0 on a missing name and 0 is BACKLAYER,
#       i.e. the annotation would paint in the BACKGROUND COLOUR.
#   (b) an entry in tctx::global_list. Without it save_ctx/restore_ctx
#       (xschem.tcl:14041/14071) do not carry it and the layer silently reverts
#       the moment the user opens a SECOND TAB.
# U20 and U21 both run in one window in one process; neither can see (b) at
# all, and (a) only as a stderr line nothing asserts. Same reasoning as L28,
# which makes the identical claim for annot_show.
check {U25 annot_voltage_layer is declared once in Tcl and is per-tab (tctx::global_list)} \
  [opa_u_tclmirror [file join $repo src xschem.tcl] annot_voltage_layer] {1 1}

# ===========================================================================
# U23 — THE GEOMETRY HALF annot_show HAS NEVER HAD
# ===========================================================================
# ⚠ MEASURED: today `xschem instance_bbox up1` is the SAME at masks 0, 1 and 3
# and moves only when a raw is loaded at all (width 20 -> 37 on this fixture).
# Hiding a text must shrink the instance's drawing bbox back to its no-raw
# shape, or `xschem update_all_sym_bboxes; redraw` — the idiom
# utils/annot_mode.tcl:6-8 pairs with every mask write — leaves a stale
# redraw region behind the number it just turned off.
# ⚠ THE CONTROL IS MEASURED IN THIS PROCESS, NEVER HARD-CODED: the same symbol
# measures 63 wide under --nogui and 64 under DISPLAY=:99 (section L's header).
opa_l_annot 0 ; set u_w0 [opa_l_w up1]
opa_l_annot 3 ; set u_w3 [opa_l_w up1]
opa_l_annot 1 ; set u_w1 [opa_l_w up1]
check {U23 BBOX at masks 0 and 1 the lab_pin is back to its no-raw width, at mask 3 it is wider} \
  [list [expr {$u_w0 == $U_W_NORAW}] [expr {$u_w1 == $U_W_NORAW}] \
        [expr {$u_w3 > $u_w0}] [expr {$U_W_NORAW > 10}]] \
  {1 1 1 1}

# ===========================================================================
# U24 — INVARIANT I4: THE OVERLAY NEVER MODIFIES THE SCHEMATIC
# ===========================================================================
# ⚠ READ BEFORE ANY SAVE AND BEFORE U22's EDIT, which is the S9 lesson: the row
# that named itself the I4 row saved first and was vacuous. Everything above
# this line has changed the mask five times, changed annot_voltage_layer four
# times and run a dozen exports.
check {U24 I4 none of it modified the schematic} [xschem get modified] 0

# ===========================================================================
# U27 / U29 — THE SCHEMATIC-OWN CONTEXT, WHICH ANSWERS DIFFERENTLY
# ===========================================================================
# ⚠ BOTH GREEN BEFORE AND AFTER, AND U27 IS THE ONE WAY THIS FEATURE CAN
# REGRESS A USER WHO NEVER ANNOTATES ANYTHING. 0614's I7 landmine says to
# measure what `@spice_get_voltage` renders as with no raw loaded and preserve
# it. Measured on this tree, the answer depends on the CONTEXT and rows U7/U8
# only cover the friendly half:
#   * a SYMBOL text emits NO <text> element at all — classifying it costs
#     literally nothing;
#   * a SCHEMATIC-OWN NON-FLOATER `T {@spice_get_voltage} … {layer=15}` renders
#     the LITERAL STRING `@spice_get_voltage`, at every mask, in its own layer,
#     with or without a raw. get_text_floater() translates only floaters, so
#     that literal is a string the user typed and is not an annotation at all.
# A classifier that ignores TEXT_FLOATER blanks it at mask 0 — a text that has
# sat on their sheet for years vanishing because of a mask they never touched.
# ⚠ NOTHING ELSE IN THE TREE GUARDS IT. Census of the shipped libraries: 20
# schematic-own T records carry a bare token, 6 with hide=true and the other 14
# real `name=` floaters that resolve to empty — so no shipped sheet has this
# shape and U7/U8's symbol sheet cannot grow one.
catch {xschem raw clear}
xschem load [file join $lib u_own.sch]
set u_own_ann [lindex [rcall [list xschem annotate_op $U_RAW]] 0]
foreach m {0 1 2 3} { set u_owns($m) [opa_u_pr svg $m u_own$m.svg] }
check {U27 I7 a schematic-own NON-floater bare token still renders LITERALLY, at mask 0 and at mask 3, in its own layer} \
  [list $u_own_ann \
        [opa_u_has $u_owns(0) [list @spice_get_voltage]] \
        [opa_u_has $u_owns(3) [list @spice_get_voltage]] \
        [expr {[opa_u_fill $u_owns(0) @spice_get_voltage] eq [opa_u_fill $u_owns(0) ZZU15MARK]}] \
        [expr {[opa_u_fill $u_owns(3) @spice_get_voltage] eq [opa_u_fill $u_owns(3) ZZU15MARK]}]] \
  {0 1 1 1 1}

# ⚠ THE OTHER SIDE OF U27's GUARD, AND WITHOUT IT THE GUARD IS TOO BLUNT. The
# floater exemption U27 demands must apply to the IMPLICIT, content-derived
# class ONLY. An author who typed `hide=voltage` on a top-level text declared a
# visibility class explicitly and chose their own `layer=`; exempting the whole
# schematic-own context — rather than only the implicit half — would silently
# un-hide it. That is why the two classes need two different bits (U11 is the
# same decision in the SYMBOL context).
check {U29 an EXPLICIT hide=voltage on a schematic-own NON-floater still follows bit1, and keeps its own layer=} \
  [list [lindex [opa_u_has $u_owns(0) ZZUOWNHV] 0] \
        [lindex [opa_u_has $u_owns(1) ZZUOWNHV] 0] \
        [lindex [opa_u_has $u_owns(2) ZZUOWNHV] 0] \
        [lindex [opa_u_has $u_owns(3) ZZUOWNHV] 0] \
        [expr {[opa_u_fill $u_owns(3) ZZUOWNHV] eq [opa_u_fill $u_owns(3) ZZUOWN4]}] \
        [expr {[opa_u_fill $u_owns(3) ZZUOWNHV] ne [opa_u_fill $u_owns(3) ZZU15MARK]}]] \
  {0 0 1 1 1 1}

# ⚠ U33 — THE SAME GUARD FOR THE CURRENT SPELLING, AND IT IS THE GAP U27
# LEAVES. GREEN BEFORE AND AFTER, and it is a REGRESSION guard for issue 0678,
# not evidence of it. Before 0678 both content classes left text_hidden()
# through ONE `if`, so the single `ctx == TEXT_CTX_INSTANCE || (flags &
# TEXT_FLOATER)` term covered both and U27 guarded this record by accident.
# 0678 gives the two classes two different answers; the ctx term has to reach
# BOTH, and a dropped copy blanks — at masks 0 and 2 — a literal string the
# user typed on their sheet years ago. Measured before the change: present at
# all four masks, in layer 17.
#
# ⚠ CORRECTED BY THE 0678 WRITE-UP (issue 0681). AN EARLIER DRAFT OF THIS
# COMMENT CLAIMED the U27 census found "ZERO shipped schematic-own bare
# `@spice_get_current` records, so no shipped sheet would move". BOTH HALVES
# ARE FALSE, and the mistake was re-using U27's sentence for a shape it does
# not cover. U27's census is scoped to the NON-FLOATER, where zero is right.
# The real census of `@spice_get_current` in xschem_library/*.sch is FOUR:
# solar_panel.sch:269 {layer=7 name=L2}, solar_panel.sch:270 {layer=7 name=C1}
# and pv_ngspice.sch:68 {layer=15 name=Rs} are real FLOATERS, and all THREE
# move from `Alt-6` to `6` with 0678 (correctly -- measured, they resolve and
# follow bit0); pcb_current_protection_embed.sch:440 carries hide=true, so
# annot_class_free() is false and it gets no implicit class at all.
# CONSEQUENCE FOR THIS ROW: U33 guards the shape that ships in NO sheet, and
# the shape that ships in THREE -- the schematic-own FLOATER -- has no row at
# all. That gap is issue 0681, with the fixture and the measurement.
set u_ownc {} ; foreach m {0 1 2 3} { lappend u_ownc [lindex [opa_u_has $u_owns($m) [list @spice_get_current]] 0] }
check {U33 I7 a schematic-own NON-floater bare @spice_get_current renders LITERALLY at all four masks, in its own layer} \
  [list $u_ownc \
        [expr {[opa_u_fill $u_owns(0) @spice_get_current] eq [opa_u_fill $u_owns(0) ZZUOWN17] &&
               [opa_u_fill $u_owns(3) @spice_get_current] eq [opa_u_fill $u_owns(3) ZZUOWN17] &&
               [opa_u_fill $u_owns(3) ZZUOWN17] ne [opa_u_fill $u_owns(3) ZZU15MARK]}]] \
  {{1 1 1 1} 1}

# ===========================================================================
# U28 — THE TWO SPELLINGS 0614's FIVE-ITEM LIST OMITS
# ===========================================================================
# ⚠ THE LIST IN THE ISSUE IS WRONG IN BOTH DIRECTIONS AND A LITERAL READING OF
# IT SHIPS A HALF FIX. It names `@spice_get_current<n>`, which has NO branch in
# token.c and appears nowhere in the tree but a stale comment at save.c:5743;
# and it omits `@#<pin>:spice_get_voltage` (get_pin_attr, token.c:4315) — which
# is 0615's OWN example, bus_tap.sym:37 — and `@spice_get_diff_voltage`
# (token.c:5094, 8 shipped records). Both resolve live: measured on this
# fixture they render `1.8` and `-1.5` out of the same raw every other row here
# uses, at all four masks, both in layer 15.
# ⚠ THE NETS ARE NAMED BY u_lab.sym, NOT lab_pin.sym — see the fixture note.
# With a real lab_pin on those nets a `1.8` would also come from the lab_pin's
# own bare token, and this row would pass on an implementation that classified
# the bare spelling and missed both of the ones under test.
# ⚠ THE LAST ELEMENT IS THE 0615 HALF: the two must land on the SAME override,
# not merely somewhere else, or the "one predicate" of invariant I1 has already
# forked.
catch {xschem raw clear}
xschem load [file join $lib u_pv.sch]
set u_pv_ann [lindex [rcall [list xschem annotate_op $U_RAW]] 0]
foreach m {0 1 2 3} { set u_pvs($m) [opa_u_pr svg $m u_pv$m.svg] }
set u_pv_a {} ; foreach m {0 1 2 3} { lappend u_pv_a [lindex [opa_u_has $u_pvs($m) 1.8] 0] }
set u_pv_d {} ; foreach m {0 1 2 3} { lappend u_pv_d [lindex [opa_u_has $u_pvs($m) -1.5] 0] }
check {U28 `@#<pin>:spice_get_voltage` and `@spice_get_diff_voltage` follow bit1 and take the SAME voltage colour} \
  [list $u_pv_ann $u_pv_a $u_pv_d \
        [expr {[opa_u_fill $u_pvs(3) 1.8]  ne [opa_u_fill $u_pvs(3) ZZU15MARK]}] \
        [expr {[opa_u_fill $u_pvs(3) -1.5] ne [opa_u_fill $u_pvs(3) ZZU15MARK]}] \
        [expr {[opa_u_fill $u_pvs(3) 1.8]  eq [opa_u_fill $u_pvs(3) -1.5]}]] \
  {0 {0 0 1 1} {0 0 1 1} 1 1 1}

# ===========================================================================
# U31 / U32 / U34 — ISSUE 0678, ON THE USER'S OWN SHEET
# ===========================================================================
# ⚠ WHY A SEPARATE SHEET AND NOT u_acc.sch. u_acc.sch's only branch current is
# a `capa.sym`, and 0678 is about a SOURCE — the user's words are "it's also
# displaying OP info of voltage sources - namely their current". Adding a sixth
# instance to u_acc.sch reds row X14 (`[xschem get instances]` 5 -> 6) and
# shifts every byte length U1/U2/U26 measure, so u_vs.sch carries the shipped
# devices/vsource.sym instead, with a lab_pin on the same sheet so ONE export
# separates the two content classes.
#
# THE RULING, AS THE USER GAVE IT ON A REAL sky130 BENCH (2026-08-24):
#   `6`      device OP info — the id=/gm= block AND a device's branch current
#   `Alt-6`  node voltages
#   `Ctrl-6` neither
# and the two setters stay ADDITIVE, which the bench CONFIRMED working and
# tests/headless/test_launch_context.tcl owns as key events.
catch {xschem raw clear}
xschem load [file join $lib u_vs.sch]
set u_vs_ann [lindex [rcall [list xschem annotate_op $U_VSRAW]] 0]
foreach m {0 1 2 3} { set u_vss($m) [opa_u_pr svg $m u_vs$m.svg] }
set u_vs_i {} ; foreach m {0 1 2 3} { lappend u_vs_i [lindex [opa_u_has $u_vss($m) -321u] 0] }
set u_vs_v {} ; foreach m {0 1 2 3} { lappend u_vs_v [lindex [opa_u_has $u_vss($m) 1.8] 0] }

# ⚠ THE DEFECT AS THE USER HIT IT, IN ONE ROW, AND IT NEEDS BOTH HALVES. A row
# that only asserted "the current follows bit0" would also pass on a change that
# moved the NODE VOLTAGES to bit0 as well — i.e. on the reversal folded the
# wrong way, which is a worse regression than the defect. So the second element
# is the current and the third is the voltage, read from the SAME four exports.
# Measured before the change: {0 {0 0 1 1} {0 0 1 1}} — the two classes are
# indistinguishable, which is precisely the report.
check {U31 0678 ACCEPTANCE: the source's branch current follows `6` (bit0) while the node voltage on the same sheet follows `Alt-6` (bit1)} \
  [list $u_vs_ann $u_vs_i $u_vs_v] \
  {0 {0 1 0 1} {0 0 1 1}}

# ⚠ GREEN BEFORE AND AFTER, AND THE REVERSAL'S NAMED SAFETY ROW. `Ctrl-6 ->
# nothing` is 0613's finding and 0614's whole reason for existing; moving a
# content class from one additive bit to the other must not put a number back on
# a cleared sheet, and must not take one off a fully-on sheet. Mask 3 is the
# non-vacuity: without it "absent at mask 0" is satisfied by an exporter that
# draws nothing at all. This is the row that reds if the gate is re-pointed at
# NOTHING (a `return 0` where a mask belongs).
check {U32 0678 `Ctrl-6` still clears BOTH classes, and mask 3 still shows both} \
  [list [lindex $u_vs_i 0] [lindex $u_vs_v 0] [lindex $u_vs_i 3] [lindex $u_vs_v 3]] \
  {0 0 1 1}

# ⚠ INVARIANT I3 — A MISSING VECTOR MUST NOT RENDER THE PREVIOUS RUN'S NUMBER.
# 0678's acceptance row 4 asks for this on the chord the currents now answer to.
# Re-annotate the SAME sheet from a raw that carries `v(d)` and no `i(v1)`, and
# export at mask 1 again.
#
# ⚠ WHAT IT ACTUALLY RENDERS, MEASURED ON THIS TREE, BECAUSE THE ACCEPTANCE
# GUESSES AND THE GUESS IS WRONG. 0678 row 4 says the row "renders the current
# row BLANK, not absent". It renders NEITHER: the element is present and its
# content is the LITERAL PLACEHOLDER `-`. That is not op_annot's doing and not
# this step's to change — it is the C token path's long-standing convention
# (`valstr = "-"` at token.c:4366/4478/4866/4968/5072/5140/5279), the same
# string a `@spice_get_current` has printed for a missing vector since long
# before annot_show existed. The part of I3 that MATTERS holds exactly: `-321u`
# is gone, so no stale number survives a re-annotation. The fourth element pins
# the placeholder as a golden rather than leaving it to a comment, so a later
# change that turns it into a blank, a `0` or a `NaN` reds a named row.
# Measured before the change: {0 0 0 0} — the first and last elements are red
# only because mask 1 shows no current at all yet, which is the 0678 defect.
catch {xschem raw clear}
set u_vs2_ann [lindex [rcall [list xschem annotate_op $U_VSRAW2]] 0]
set u_vs2_s [opa_u_pr svg 1 u_vs2_1.svg]
check {U34 I3 0678 re-annotating from a raw with no i(v1) drops the number: `-321u` gone, the C placeholder `-` in its place} \
  [list $u_vs2_ann [lindex $u_vs_i 1] \
        [lindex [opa_u_has $u_vs2_s [list -321u]] 0] \
        [lindex [opa_u_has $u_vs2_s [list -]] 0]] \
  {0 1 0 1}

# ===========================================================================
# U22 — THE CLASS IS A FUNCTION OF THE CONTENT, AND CONTENT CAN CHANGE
# ===========================================================================
# ⚠ RUN LAST: `xschem setprop text` calls set_modify(1) (scheduler.c:12682), so
# it must not precede U24.
# The class cannot be a load-time fact. `xschem setprop text n txt_ptr` already
# re-runs set_text_flags (scheduler.c:12683) so the first element is reachable
# headless; the GUI dialog path is NOT (it reads tctx::retval from a Tk widget),
# and on HEAD it replaces txt_ptr at editprop.c:777 under `text_changed` while
# calling set_text_flags at :786 under `props_changed` — so the second element
# is the only guard that seam has anywhere in the tree.
catch {xschem raw clear}
xschem load [file join $lib u_edit.sch]
set u_e_ann [lindex [rcall [list xschem annotate_op $U_RAW]] 0]
set u_e_before [opa_u_has [opa_u_pr svg 0 u_e0.svg] ZZUEDITMARK]
catch {xschem setprop text 0 txt_ptr {@spice_get_voltage(power)}}
set u_e_m0 [opa_u_has [opa_u_pr svg 0 u_e1.svg] 3.3]
set u_e_m2 [opa_u_has [opa_u_pr svg 2 u_e2.svg] 3.3]
check {U22 a CONTENT-only edit makes the class live at once, and editprop.c's dialog path does the same} \
  [list $u_e_ann $u_e_before $u_e_m0 $u_e_m2 \
        [opa_u_editprop_guard [file join $repo src editprop.c]]] \
  {0 1 0 1 1}

catch {xschem raw clear}
opa_l_annot 0 ; opa_l_sht 0
opa_u_lay 9
set XSCHEM_LIBRARY_PATH $S_LIBS

} uerr]} {
  puts "UNEXPECTED ERROR (section U): $uerr"
  incr fail
}

# =============================================================================
# SECTION W — S3 of doc/claude/specs/op_annotation.md: THE HIERARCHY WALK AND
#             THE SAVE-CARD GENERATOR
# =============================================================================
# S1 built the name builder, S2 filled the descriptor store, S5 built the READ
# side and S9b put it on the canvas. NOTHING PUTS THE DEVICE VECTORS INTO THE
# RAW. On an ordinary bench run every `params` row and every `derived` row that
# depends on one renders BLANK — measured on this tree: 8 of 10 rows blank, only
# the two `pinexpr` rows (`vgs`, `vds`) populate, because pin voltages need no
# save card at all. S3 is the missing half:
#
#   op_annot::save_cards {}      -> the `.save` block for the hierarchy below
#                                   the CURRENT cell, as text; {} when empty
#   op_annot::write_save_file {} -> writes it to $netlist_dir/<cell>.save and
#                                   returns the path
#   op_annot::last_warnings {}   -> what the walk could not do, as a list
#   op_annot::devpath <i> ?basis? ?root?   <- the ONE builder, now with a BASIS
#   op_annot::last_counts {}     -> {dropped_by_rule N not_found N name_failed N}
#
# ============================================================================
# ⚠ ATTEMPT 5. WHAT CHANGED IN THIS SECTION, AND WHY EACH CHANGE EXISTS
# ============================================================================
# Attempt 4 was certified green at 275 checks and was false in the field twice.
# Issue 0499 is the test-side post-mortem; every amendment below is one of its
# rows, and issues 0495/0496/0497/0626 are the field defects.
#
#   W11-W14  grew an ENTERED-LEVELS leg. They asserted "no card under this
#            prefix" and were true for a reason they did not test: aliasing
#            `_descendable` to `_netlisted` (attempt 2's shipped defect) makes
#            the walk ENTER all four dropped cells while their cards stay masked.
#            `opa_w_walk` records `sch_path` after every `xschem descend` with a
#            Tcl execution trace, i.e. from outside the implementation. (0499c)
#   W19a/b   NEW. I4 on a SHIPPED bench. The fixture row W19 runs on a `.sch`
#            this file wrote with no `~` beside it and cannot fail; on
#            sky130_tests_ase/bandgap_opamp the same assertion is measurably
#            false. (0495, 0499a)
#   W28/W28b REWRITTEN. One aggregate ending `- normal for such cells` is what
#            told the user 0496's 12-of-39 under-emission was expected. Three
#            named counters, and only `dropped_by_rule` may ever be called
#            normal. (0497)
#   W30a/W30 NEW. The 0496 bench itself — the only design in the tree with
#            parameter-specialised subcircuits. W30a pins the deck facts AND the
#            measured descend obstacle; W30 is the both-directions claim.
#   W31      NEW. The save gate for issue 0626, filed by this crew.
#   W32      NEW. 0499(c)+(d) in one walk: a shared-`.sch` drop class and a
#            class-1 descend refusal.
#   W33      NEW. 0493 — the memo's invalidation point and a wall-clock bound.
#   XR5      NEW. 0499(b): section X as written cannot tell the two bases apart
#            at all, because it only ever walks from currsch 0.
#
# ============================================================================
# ⚠ THE CONTRACT `op_annot::last_counts` MUST MEET — WRITTEN HERE FIRST
# ============================================================================
# A dict with EXACTLY these three integer keys, describing the LAST walk:
#     dropped_by_rule   the NETLISTER dropped it (spice_ignore, only_toplevel,
#                       lvs_ignore, empty format, default_schematic=ignore,
#                       spice_sym_def, spice_stop). Expected; may be called
#                       "normal for such cells".
#     not_found         the deck DOES contain it and the walk could not
#                       attribute it to a block. THE 0496 CLASS. Never normal.
#     name_failed       devpath/devproc could not build a name: a raising
#                       devproc, a blank template, the 0488 prefix guard.
# `op_annot::last_warnings` keeps returning the human-readable list.
#
# ============================================================================
# ⚠ THE CARD IS BARE, AND `op_annot::vector` MUST NEVER APPEAR IN ONE (rule R4)
# ============================================================================
# Re-measured for this section on /usr/local/bin/ngspice (46+), on the section-X
# deck below:
#
#   .save @m.xmx0.m1[id]      -> raw carries  i(@m.xmx0.m1[id])
#   .save @m.xmx0.m1[gm]      -> raw carries    @m.xmx0.m1[gm]
#   .save @m.xmx0.m1[vdsat]   -> raw carries  v(@m.xmx0.m1[vdsat])
#   .save i(@m.xmx0.m1[id])   -> raw carries  NOTHING, and says nothing
#
# ngspice applies the i()/v() wrapper itself from the parameter's own type. The
# emitter writes [devpath][param]; `vector` is the READ shape and belongs to S5.
# Row W4 is the guardian: the block contains no `(` at all.
#
# ============================================================================
# ⚠ THE TWO BASES. THIS IS WHAT REVERTED ATTEMPT 1 (issue 0436)
# ============================================================================
# `op_annot::devpath`'s hierarchy prefix came from `xschem get sim_sch_path`,
# which is measured from the level the RAW was loaded at — the right basis for
# READING a vector out of a loaded raw and the wrong one for WRITING a card into
# a deck nobody has simulated yet. Reproduced on THIS section's fixture, with a
# raw loaded one level down and the walk run from the top:
#
#     no raw        xok1 -> @m.xok1.mp1.dp     xok2 -> @m.xok2.mp1.dp
#     raw at lvl 1  xok1 -> @m.mp1.dp          xok2 -> @m.mp1.dp     <-- COLLAPSED
#
# Two different instances of one subcell, one device name, no warning anywhere.
# The fix is a BASIS on the one builder — `deck` = `xschem get sch_path` minus
# the walk-entry root, which no loaded raw can perturb — not path arithmetic in
# the walk, which would be the second builder invariant I1 forbids. Rows W5/W6/W7
# are the guardians, and they are non-vacuous ONLY because a raw is loaded: with
# no raw the two bases coincide, which is why 85 green checks missed this.
#
# ⚠ AND `@path` IS A SECOND RAW-RELATIVE SOURCE, IN THE C (token.c:4719 is a
# byte-for-byte copy of sim_sch_path's stripping loop). A fix that only swaps the
# Tcl call passes every sky130 row — sky130 registers a DEVPROC — and leaves
# gf180's and IHP's `@path` TEMPLATES raw-relative. That is why this section
# registers TWO arms, `w_nmos` (a `@path` template) and `w_nmos2` (a devproc),
# and why W5 and W6 assert on DISJOINT subsets of the same block: a variant that
# reds both means the fixture has lost one of the arms.
#
# ============================================================================
# ⚠ THE FILTER IS SEVEN CLASSES. THIS IS WHAT REVERTED ATTEMPT 2 (issue 0442)
# ============================================================================
# A card naming a device that is not in the deck is not a cosmetic defect: under
# the `.control … write … .endc` idiom every shipped PDK bench uses, if EVERY
# device card is bogus ngspice writes NO RAW AT ALL, and if one among good ones
# is bogus it writes a full column marked `dims=0` and prints nothing. Either
# way the generator has damaged the simulation it was generated for.
#
# Attempt 2 hand-mirrored the netlister's rules and implemented three of seven.
# The four it missed are all SYMBOL-level and all reachable on ordinary PDK
# symbols. This fixture carries all seven, in one hierarchical deck, measured on
# this tree with `xschem netlist`:
#
#   class                       instance line   its .subckt block     descend?
#   spice_ignore=true           absent          -                     no
#   spice_ignore=short          absent          -                     no
#   only_toplevel=true (below)  absent          -                     no
#   empty/absent `format`       ABSENT          none at all           no
#   default_schematic=ignore    present         NO BLOCK AT ALL       no
#   spice_sym_def               present         `** sym_path:` only   no
#   spice_stop=true             present         `** sch_path:` EMPTY  no
#
# The last three are why `_netlisted` and `_descendable` cannot be aliases:
# the deck holds the CALL and not the BODY. Attempt 2 aliased them and its
# `filter_skips_cards_but_still_descends` sabotage variant reddened nothing —
# the visible edge of the whole gap, on a FLAT fixture that could not reach it.
# Per spec landmine 11 a predicted red that does not appear is a fixture defect.
#
# ⚠ THE ORACLE IS THE NETLISTER ITSELF, READ AND NOT REIMPLEMENTED. Rows W11-W15
# assert against `xschem netlist` output; W15 cross-checks BOTH directions
# against a deck this file expands ITSELF, so the row cannot be satisfied by the
# implementation agreeing with its own copy of the rules.
#
# ============================================================================
# ⚠ I6 IS THE DESTRUCTIVE HALF, AND THE PROTOTYPES DO NOT SATISFY IT
# ============================================================================
# The walk sets no_draw 1, no_undo 1, keep_symbols 1 and descends the REAL
# design. `sky130_save_fet_params` on `sky130_tests/test_generators` raises and
# returns with no_draw=1 keep_symbols=1 still set, because its restore is on the
# normal path (issue 0431). W19/W20/W21 force a raise below the entry level and
# assert the restore anyway; W21 enters ALREADY DESCENDED, because the unwind is
# bounded by the ENTRY level and `while {[xschem get currsch]} {go_back}` would
# ascend past a caller. `no_undo` has no getter (issue 0432) so W22 probes its
# EFFECT and carries its own non-vacuity control.

# --- section W locations ------------------------------------------------------
set W_LIB  [file join $scratch wlib]
set W_NL   [file join $scratch wnl]      ;# $netlist_dir for write_save_file
set W_TNL  [file join $scratch wtnl]     ;# THIS FILE's own netlist runs
set W_CONF [file join $scratch wconf]    ;# USER_CONF_DIR, so the oracle never
                                         ;# writes into the developer's ~/.xschem
file mkdir $W_LIB $W_NL $W_TNL $W_CONF

## The fixture, written fresh. Two device symbols with the SAME shape and two
## different descriptor ARMS, plus one subcircuit symbol per netlister drop
## class. Nothing here is committed and nothing lands in the repo.
proc opa_w_sym {lib name type extra {pins 4}} {
  set body "v \{xschem version=3.4.4 file_version=1.2\}\nG \{type=$type\n$extra"
  append body "\}\nV \{\}\nS \{\}\nE \{\}\nL 4 -20 -20 20 -20 \{\}\n"
  set y -2.5
  foreach p [lrange {D G S B} 0 [expr {$pins - 1}]] {
    append body "B 5 -22.5 $y -17.5 [expr {$y + 5}] \{name=$p dir=inout\}\n"
    set y [expr {$y + 20}]
  }
  append body "T \{@symname\} -20 -34 0 0 0.2 0.2 \{\}"
  set f [open [file join $lib $name.sym] w] ; puts $f $body ; close $f
}
proc opa_w_sch {lib name insts} {
  set body "v \{xschem version=3.4.4 file_version=1.2\}\nG \{\}\nV \{\}\nS \{\}\nE \{\}"
  set x 0
  foreach i $insts {
    append body "\nC \{[lindex $i 0]\} $x 0 0 0 \{[lindex $i 1]\}"
    incr x 100
  }
  set f [open [file join $lib $name.sch] w] ; puts $f $body ; close $f
}
proc opa_w_fixture {lib} {
  ## ⚠ THE `w_` TYPE NAMES ARE DELIBERATE. `nmos` is registered by sections C/P
  ## above and by three PDKs; a fixture that reused it would be measuring
  ## whichever registration ran last (issue 0425).
  opa_w_sym $lib w_prim  w_nmos  "format=\"@name @pinlist @model\"\ntemplate=\"name=M1 model=nch\"\n"
  opa_w_sym $lib w_prim2 w_nmos2 "format=\"@name @pinlist @model\"\ntemplate=\"name=M1 model=nch2\"\n"
  set F "format=\"@name @pinlist @symname\"\ntemplate=\"name=x1\"\n"
  opa_w_sym $lib w_ok     subcircuit $F 1
  opa_w_sym $lib w_deep   subcircuit $F 1
  opa_w_sym $lib w_vec    subcircuit $F 1
  ## class 4: NO `format` at all — spice_netlist.c:639 returns before anything is
  ## written, so the instance AND its block are absent from the deck entirely.
  opa_w_sym $lib w_nofmt  subcircuit "template=\"name=x1\"\n" 1
  ## class 5: the call survives, the block is never emitted (spice_netlist.c:643)
  opa_w_sym $lib w_dsign  subcircuit "$F default_schematic=ignore\n" 1
  ## class 6: the body is replaced by attribute text — `** sym_path:` and NO
  ## `** sch_path:` (spice_netlist.c:665). ⚠ The .subckt port name MATCHES the
  ## symbol pin on purpose: a mismatch pops has_included_subcircuit's alert_
  ## (src/xschem.tcl:2200), which no netlist flag reaches and which would HANG
  ## the xvfb leg of this suite.
  opa_w_sym $lib w_symdef subcircuit "$F spice_sym_def=\".subckt w_symdef D\nRSD D 0 1k\n.ends\"\n" 1
  ## class 7: the block is emitted EMPTY (spice_netlist.c:635 + :695)
  opa_w_sym $lib w_stop   subcircuit "$F spice_stop=true\n" 1
  ## the spiceprefix'd subcircuit: the deck says XSUB1, every path source says
  ## SUB1 (issue 0488). Its own top, so W2's golden does not depend on the guard.
  opa_w_sym $lib w_pfx    subcircuit "format=\"@spiceprefix@name @pinlist @symname\"\ntemplate=\"name=x1 spiceprefix=X\"\n" 1
  ## level 1: the DEVPROC arm, an only_toplevel device, an lvs_ignore device and
  ## the level-2 subcircuit.
  opa_w_sch $lib w_ok [list \
    {w_prim2.sym {name=MP1 model=nch2}} \
    {w_prim.sym  {name=MONLY model=nch only_toplevel=true}} \
    {w_prim.sym  {name=MLVS model=nch lvs_ignore=true}} \
    {w_deep.sym  {name=xdeep}}]
  ## level 2: the TEMPLATE arm
  opa_w_sch $lib w_deep [list {w_prim.sym {name=MT1 model=nch}}]
  opa_w_sch $lib w_vec  [list {w_prim.sym {name=MV model=nch}}]
  opa_w_sch $lib w_pfx  [list {w_prim.sym {name=MPX model=nch}}]
  foreach n {w_nofmt w_dsign w_symdef w_stop} {
    file copy -force [file join $lib w_ok.sch] [file join $lib $n.sch]
  }
  ## the top: all seven drop classes, TWO instances of one cell, and a vector
  ## instance.
  opa_w_sch $lib w_top [list \
    {w_prim.sym   {name=MT0 model=nch}} \
    {w_prim.sym   {name=MTIGN model=nch spice_ignore=true}} \
    {w_prim.sym   {name=MTSHORT model=nch spice_ignore=short}} \
    {w_ok.sym     {name=xok1}} \
    {w_ok.sym     {name=xok2}} \
    {w_ok.sym     {name=xign spice_ignore=true}} \
    {w_ok.sym     {name=xshort spice_ignore=short}} \
    {w_nofmt.sym  {name=xnofmt}} \
    {w_dsign.sym  {name=xdsign}} \
    {w_symdef.sym {name=xsymdef}} \
    {w_stop.sym   {name=xstop}} \
    {w_vec.sym    {name=x2[1:0]}}]
  ## W18's own top, and W3's empty one.
  opa_w_sch $lib w_pfxtop [list {w_prim.sym {name=MT0 model=nch}} {w_pfx.sym {name=SUB1}}]
  opa_w_sch $lib w_bare   [list {w_stop.sym {name=xstop}}]
  ## W16's cell: a shipped `code_shown` symbol whose text carries BOTH traps —
  ## a line that looks like an element and names a really-ignored instance, and
  ## a .subckt/.ends pair that would close the enclosing block early. MAFTER is
  ## written into the deck AFTER that region and is the only card this cell owes.
  ## ⚠ No braces in the value: they break the .sch record scan (see section X).
  opa_w_sym $lib w_code subcircuit "format=\"@name @pinlist @symname\"\ntemplate=\"name=x1\"\n" 1
  set ghost "value=\"MGHOST net1 net2 net3 net4 nch
.subckt w_ghost D
RG D 0 1k
.ends\""
  set f [open [file join $lib w_code.sch] w]
  puts $f "v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {code_shown.sym} 0 -200 0 0 {name=s1 only_toplevel=false $ghost}
C {w_prim.sym} 0 0 0 0 {name=MGHOST model=nch spice_ignore=true}
C {w_prim.sym} 100 0 0 0 {name=MAFTER model=nch}"
  close $f
  opa_w_sch $lib w_codetop [list {w_code.sym {name=xcode}}]
}

## ⚠ THE DEVPROC ARM. It returns a shape no template could build (`.dp`), so a
## card can be attributed to its arm by inspection — that is what lets W5 and W6
## assert on DISJOINT subsets of one block.
proc opa_w_devproc {instname model path spiceprefix} {
  return "@m.${path}${spiceprefix}${instname}.dp"
}
## Register both arms. `derived` and `pinexpr` are present so W3 can assert that
## neither contributes a card (spec §4.3: there is nothing to save for them).
proc opa_w_register {} {
  op_annot::register w_nmos [list devpath {\@m.@path@spiceprefix@name} \
    params {{id id 0} {gm gm 1}} derived {{gm/id {$gm/$id}}} \
    pinexpr {{vgs {expr(@#1:spice_get_voltage - @#0:spice_get_voltage )}}}]
  op_annot::register w_nmos2 [list devproc opa_w_devproc params {{id id 0} {gm gm 1}}]
}

## Load a fixture cell and sweep the `~.sch` backups the loader drops, so the
## fixture dir stays byte-stable for the rows that compare deck text.
proc opa_w_load {name} {
  global W_LIB
  foreach f [glob -nocomplain [file join $W_LIB *~.sch]] { catch {file delete -force $f} }
  catch {xschem load [file join $W_LIB $name]}
  foreach f [glob -nocomplain [file join $W_LIB *~.sch]] { catch {file delete -force $f} }
  return [list [xschem get instances] [xschem get currsch] [xschem get sch_path]]
}
## The four things I6 must give back. `no_undo` is NOT here: there is no getter
## (issue 0432) and it returns {} whether the flag is 0 or 1 — W22 probes the
## effect instead.
proc opa_w_state {} {
  set kd 0
  if {[info exists ::keep_symbols]} { set kd $::keep_symbols }
  return [list [xschem get no_draw] $kd [xschem get currsch] [xschem get sch_path]]
}
## Every line of a block, the trailing empty element dropped. {} -> {}.
proc opa_w_lines {block} {
  set b [string trimright $block "\n"]
  if {$b eq {}} { return {} }
  return [split $b "\n"]
}
## The DEVICE PATHS a block names: `.save @m.x.y[gm]` -> `@m.x.y`.
proc opa_w_devs {block} {
  set out {}
  foreach l [opa_w_lines $block] {
    if {![regexp {^\.save[ \t]+(.*)\[[^]]*\]$} $l -> d]} { continue }
    lappend out $d
  }
  return $out
}
## The subset of a block's cards whose device path matches a glob.
proc opa_w_pick {block pat} {
  set out {}
  foreach l [opa_w_lines $block] { if {[string match $pat $l]} { lappend out $l } }
  return $out
}
## Does any card name a device under this hierarchy prefix?
proc opa_w_under {block prefix} {
  set n 0
  foreach d [opa_w_devs $block] { if {[string first $prefix $d] == 0} { incr n } }
  return $n
}

# ---------------------------------------------------------------------------
# THIS FILE'S OWN ORACLE — deliberately NOT op_annot's
# ---------------------------------------------------------------------------
# W15 must be able to fail when the implementation and its own deck reader agree
# with each other and both are wrong. So the deck is netlisted, parsed and
# expanded HERE, by code that shares nothing with src/op_annot.tcl.
proc opa_w_netlist {name} {
  global W_LIB W_TNL
  set out [file join $W_TNL [file rootname $name].spice]
  catch {file delete -force $out}
  set keep {}
  foreach v {netlist_dir local_netlist_dir flat_netlist split_files} {
    lappend keep [list $v [expr {[info exists ::$v] ? [set ::$v] : {}}]]
  }
  set ::netlist_dir $W_TNL ; set ::local_netlist_dir 0
  set ::flat_netlist 0 ; set ::split_files 0
  catch {xschem netlist -keep_symbols -noalert $out}
  foreach r $keep { if {[lindex $r 1] ne {}} { set ::[lindex $r 0] [lindex $r 1] } }
  if {![file isfile $out]} { return {} }
  set fh [open $out r] ; set t [read $fh] ; close $fh
  return $t
}
## cell -> list of {element lasttoken}, user-architecture regions excluded.
proc opa_w_blocks {text} {
  set out {} ; set cur {} ; set inuser 0
  foreach line [split $text "\n"] {
    set t [string trim $line]
    if {$t eq {}} continue
    if {[string match {\*\*\*\* begin user architecture*} $t]} { set inuser 1 ; continue }
    if {[string match {\*\*\*\* end user architecture*} $t]}   { set inuser 0 ; continue }
    if {$inuser} continue
    set d $t
    if {[string range $d 0 1] eq {**}} { set d [string trim [string range $d 2 end]] }
    if {[regexp -nocase {^\.subckt[ \t]+([^ \t]+)} $d -> cell]} {
      set cur [string tolower $cell]
      if {![dict exists $out $cur]} { dict set out $cur {} }
      continue
    }
    if {[regexp -nocase {^\.ends} $d]} { set cur {} ; continue }
    if {$cur eq {}} continue
    set c [string index $t 0]
    if {$c eq {*} || $c eq {.} || $c eq {+}} continue
    set toks {}
    foreach w [split $t] { if {$w ne {}} { lappend toks $w } }
    if {[llength $toks] < 1} continue
    dict lappend out $cur [list [string tolower [lindex $toks 0]] \
                                [string tolower [lindex $toks end]]]
  }
  return $out
}
## Expand the deck from <cell>: every DEVICE the simulator will really see,
## as `<hierarchy-prefix><element>`. A call is an element whose last token names
## another block.
proc opa_w_expand {blocks cell prefix} {
  set out {}
  if {![dict exists $blocks $cell]} { return {} }
  foreach e [dict get $blocks $cell] {
    set nm [lindex $e 0] ; set last [lindex $e 1]
    if {[dict exists $blocks $last]} {
      foreach x [opa_w_expand $blocks $last "${prefix}${nm}."] { lappend out $x }
    } else {
      lappend out "${prefix}${nm}"
    }
  }
  return $out
}
## The `m`-lettered devices of an expansion: exactly the ones this section's two
## descriptors claim.
proc opa_w_mdevs {l} {
  set out {}
  foreach d $l {
    set tail [lindex [split $d {.}] end]
    if {[string index $tail 0] eq {m}} { lappend out $d }
  }
  return [lsort $out]
}
## -> {unmatched-cards missing-devices per-device-counts-that-are-not-N}
## Both directions, so neither an orphan card nor a silently dropped device can
## pass. THIS is the row two attempts shipped past.
proc opa_w_xcheck {block expected nparams} {
  set orphan {} ; set counts {}
  foreach e $expected { dict set counts $e 0 }
  foreach d [opa_w_devs $block] {
    if {[string range $d 0 2] ne {@m.}} { lappend orphan $d ; continue }
    set bare [string range $d 3 end]
    set hit {}
    foreach e $expected {
      if {$bare eq $e} { set hit $e ; break }
      if {[string first "${e}." $bare] == 0} { set hit $e ; break }
    }
    if {$hit eq {}} { lappend orphan $d ; continue }
    dict incr counts $hit
  }
  set bad {}
  dict for {k v} $counts { if {$v != $nparams} { lappend bad [list $k $v] } }
  return [list [lsort -unique $orphan] [lsort $bad]]
}
## The no_undo EFFECT probe (issue 0432): push, delete, undo. {n 1-less n} when
## undo is live, {n 1-less 1-less} when no_undo is still set.
proc opa_w_undo_probe {} {
  set n0 [xschem get instances]
  catch {xschem push_undo}
  catch {xschem unselect_all}
  catch {xschem select instance 0 fast nodraw}
  catch {xschem delete}
  set n1 [xschem get instances]
  catch {xschem undo}
  return [list $n0 $n1 [xschem get instances]]
}
## Force a raise BELOW the entry level, through the production proc the walk
## calls. ⚠ The shim forwards all three arguments: a one-argument shim would make
## the walk die on `wrong # args` instead of on the forced failure, and W20/W21
## would go red for a harness bug wearing the right colour.
proc opa_w_shim_on {} {
  set ::opa_w_shim_hits 0
  if {[info commands ::op_annot::devpath_real] eq {}} {
    catch {rename ::op_annot::devpath ::op_annot::devpath_real}
  }
  proc ::op_annot::devpath {instname {basis read} {root {}}} {
    if {[xschem get currsch] > 0} {
      incr ::opa_w_shim_hits
      return -code error "opa forced mid-walk failure"
    }
    return [::op_annot::devpath_real $instname $basis $root]
  }
}
proc opa_w_shim_off {} {
  if {[info commands ::op_annot::devpath_real] ne {}} {
    catch {rename ::op_annot::devpath {}}
    catch {rename ::op_annot::devpath_real ::op_annot::devpath}
  }
}
## A row that only exists under --logdir prints this instead of counting.
proc opa_w_skiprow {name why} { puts "skip: $name  ($why)" ; flush stdout }
proc opa_w_logcount {pat} {
  if {[catch {open [xschem get actionlog_filename] r} fd]} { return -1 }
  set b [read $fd] ; close $fd
  set n 0
  foreach line [split $b "\n"] { if {[string match $pat $line]} { incr n } }
  return $n
}
## The netlist environment a walk must give back untouched, C side included.
proc opa_w_netenv {} {
  set out {}
  foreach v {netlist_dir local_netlist_dir flat_netlist split_files} {
    lappend out [list $v [expr {[info exists ::$v] ? [set ::$v] : {-unset-}}]]
  }
  foreach v {netlist_type netlist_name} {
    lappend out [list $v [expr {[catch {xschem get $v} c] ? {-raised-} : $c}]]
  }
  return $out
}
proc opa_w_dirsig {d} {
  set out {}
  foreach f [lsort [glob -nocomplain -directory $d *]] {
    if {[file isfile $f]} { lappend out [list [file tail $f] [file size $f]] }
  }
  return $out
}
## Cards built by the DEVPROC arm — the `.dp` inner device no template can build.
proc opa_w_dpcards {block} {
  set o {}
  foreach l [opa_w_lines $block] { if {[string match {*.dp\[*} $l]} { lappend o $l } }
  return $o
}
## Cards built by the `@path` TEMPLATE arm: every card that is not a devproc one.
proc opa_w_tmplcards {block} {
  set o {}
  foreach l [opa_w_lines $block] {
    if {$l eq {.save all}} continue
    if {[string match {*.dp\[*} $l]} continue
    lappend o $l
  }
  return $o
}
## Does the `* expanding symbol: <sym>` section carry a sym_path / a sch_path?
## The two answers are what tell spice_sym_def (body replaced by attribute text)
## apart from spice_stop (real block, emitted EMPTY).
proc opa_w_pathkinds {deck symname} {
  set in 0 ; set sym 0 ; set sch 0
  foreach l [split $deck "\n"] {
    set t [string trim $l]
    if {[string match {\* expanding*} $t]} { set in [string match "*$symname*" $t] ; continue }
    if {!$in} continue
    if {[string match {\*\* sym_path:*} $t]} { set sym 1 }
    if {[string match {\*\* sch_path:*} $t]} { set sch 1 }
  }
  return [list $sym $sch]
}


# ---------------------------------------------------------------------------
# S3 ATTEMPT 5 — THE HELPERS THE FOUR NEW ROW FAMILIES NEED
# ---------------------------------------------------------------------------
## LEVELS ENTERED, WITHOUT INVENTING AN API. Rows W11-W14 and W32 must assert
## "no descend", not merely "no card": aliasing `_descendable` to `_netlisted`
## masks the CARDS of a leaked cell while still ENTERING it (issue 0499c), and
## every card-only row stays green. A Tcl execution LEAVE trace on the `xschem`
## command records `sch_path` after each `descend`, from outside the
## implementation, so this row family binds no new proc name and does not depend
## on a predicted descend COUNT (which is a design choice — one descend plus
## `change_sch_path` per vector member, or one descend per member).
##
## Measured on Tcl 8.6.14 against the C-implemented `xschem` command: the
## callback may itself call `xschem` (no recursive firing), and a CLASS-2 refusal
## is recorded too — `xgen` answered `{1 .xgen.}` with descend_error=load-failed,
## which is exactly the "entered a level it should not have" signal.
proc opa_w_trace_leave {cmdstr code result op} {
  if {[lindex $cmdstr 1] ne {descend}} return
  lappend ::opa_w_entered [xschem get sch_path]
}
## Run <script> with the entered-levels recorder live. -> {rc result entered}
proc opa_w_walk {script} {
  set ::opa_w_entered {}
  trace add execution xschem leave ::opa_w_trace_leave
  set rc [catch {uplevel #0 $script} res]
  catch {trace remove execution xschem leave ::opa_w_trace_leave}
  return [list $rc $res $::opa_w_entered]
}
## How many recorded levels match <glob>?
proc opa_w_ent {entered pat} {
  set n 0
  foreach p $entered { if {[string match $pat $p]} { incr n } }
  return $n
}

## A directory's content signature: {name size md5} per file, sorted. I4's row
## on a SHIPPED schematic needs the bytes, not just the `modified` flag —
## `load_backup_as` swaps the buffer's CONTENT for the backup's while leaving the
## file alone, so a flag-only row (and a size-only one) both pass through it.
proc opa_w_filesig {dir {pat *}} {
  set out {}
  foreach f [lsort [glob -nocomplain -directory $dir $pat]] {
    if {![file isfile $f]} continue
    set md5 {}
    if {![catch {exec md5sum $f} r]} { set md5 [lindex $r 0] }
    lappend out [list [file tail $f] [file size $f] $md5]
  }
  return $out
}

## ISSUE 0497's THREE COUNTERS, AS A CONTRACT THE ROWS CAN ASSERT EXACTLY.
##
## ⚠ THE CONTRACT S3 OWES, SPELLED OUT HERE SO THE EMITTER CANNOT GUESS IT:
##
##     op_annot::last_counts  ->  a dict with EXACTLY these three integer keys
##         dropped_by_rule   an instance the NETLISTER dropped (spice_ignore,
##                           only_toplevel, lvs_ignore, an empty format, …).
##                           Expected, and the only one that is ever "normal".
##         not_found         an instance the deck DOES contain that the walk
##                           could not attribute to a block. THE 0496 CLASS.
##                           Non-zero here is a DEFECT, never a normality.
##         name_failed       devpath/devproc could not build a name (a raising
##                           devproc, a blank template, the 0488 prefix guard).
##
## and `op_annot::last_warnings` still returns the human-readable list, in which
## the phrase `normal for such cells` may appear ONLY for dropped_by_rule.
## Issue 0497: one aggregate carrying that phrase is what told the user 0496's
## 12-of-39 under-emission was expected behaviour.
proc opa_w_counts {} {
  if {[catch {op_annot::last_counts} d]} { return [list RAISED $d] }
  if {[catch {dict keys $d} k]} { return [list NOTADICT $d] }
  set out {}
  foreach key {dropped_by_rule not_found name_failed} {
    if {[catch {dict get $d $key} v]} { set v MISSING }
    lappend out $v
  }
  return $out
}

# ---------------------------------------------------------------------------
# THE SECOND ORACLE — for a REAL PDK deck, where the callee is not the last token
# ---------------------------------------------------------------------------
# `opa_w_blocks`/`opa_w_expand` above read the callee as the element line's LAST
# token, which is right for this section's `@name @pinlist @symname` fixture and
# WRONG for every PDK: `XM1 d g s b sky130_fd_pr__nfet_01v8 L=0.15 W=0.5 …` ends
# in a parameter assignment. This second reader implements the documented rule —
# join `+` continuations, then the callee is the last token BEFORE the first
# token containing `=` — and it is what rows W30/W30a use against the shipped
# tb_bandgap_opamp deck. Independent of src/op_annot.tcl by construction.
proc opa_w_join {text} {
  set raw {}
  foreach line [split $text "\n"] {
    set s [string trim $line]
    if {$s eq {}} continue
    if {[string index $s 0] eq {+}} {
      if {[llength $raw]} { lset raw end "[lindex $raw end] [string trim [string range $s 1 end]]" }
      continue
    }
    lappend raw $s
  }
  return $raw
}
## -> {blocks schpaths first} where blocks maps a lowercased .subckt NAME to a
## list of {element callee}, schpaths maps it to its `** sch_path:` comment, and
## first is the deck's first block (the netlister always writes the top first).
proc opa_w_blocks2 {text} {
  set blocks {} ; set schp {} ; set cur {} ; set inuser 0 ; set first {} ; set pend {}
  foreach s [opa_w_join $text] {
    if {[string match {\*\*\*\* begin user architecture*} $s]} { set inuser 1 ; continue }
    if {[string match {\*\*\*\* end user architecture*} $s]}   { set inuser 0 ; continue }
    if {$inuser} continue
    set d $s
    if {[string range $d 0 1] eq {**}} { set d [string trim [string range $d 2 end]] }
    if {[regexp -nocase {^sch_path:[ \t]*(.*)$} $d -> p]} { set pend [string trim $p] ; continue }
    if {[regexp -nocase {^\.subckt[ \t]+([^ \t]+)} $d -> cell]} {
      set cur [string tolower $cell]
      if {$first eq {}} { set first $cur }
      if {![dict exists $blocks $cur]} { dict set blocks $cur {} }
      dict set schp $cur $pend
      continue
    }
    if {[regexp -nocase {^\.ends} $d]} { set cur {} ; continue }
    if {$cur eq {}} continue
    set c [string index $s 0]
    if {$c eq {*} || $c eq {.}} continue
    set toks {} ; foreach w [split $s] { if {$w ne {}} { lappend toks $w } }
    set callee {}
    for {set i 1} {$i < [llength $toks]} {incr i} {
      if {[string first {=} [lindex $toks $i]] >= 0} break
      set callee [lindex $toks $i]
    }
    dict lappend blocks $cur [list [string tolower [lindex $toks 0]] [string tolower $callee]]
  }
  return [list $blocks $schp $first]
}
## Every LEAF the simulator sees, as {hierarchy-path callee}. A call is an
## element whose callee names another block.
proc opa_w_expand2 {blocks cell prefix} {
  set out {}
  if {![dict exists $blocks $cell]} { return {} }
  foreach e [dict get $blocks $cell] {
    lassign $e nm callee
    if {[dict exists $blocks $callee]} {
      foreach x [opa_w_expand2 $blocks $callee "${prefix}${nm}."] { lappend out $x }
    } else {
      lappend out [list "${prefix}${nm}" $callee]
    }
  }
  return $out
}
## The sky130 FET leaves of an expansion, as the DEVICE PATHS op_annot::devpath
## builds for them: `@m.<hierarchy><element>.m<model>` (sky130A/sky130_procs.tcl's
## sky130_op_devpath, verified live against `op_annot::devpath` on this bench).
proc opa_w_sky_fets {leaves} {
  set out {}
  foreach l $leaves {
    lassign $l path model
    if {![regexp {^sky130_fd_pr__[np]fet} $model]} continue
    lappend out "@m.${path}.m${model}"
  }
  return [lsort $out]
}

## The GOLDEN block. Depth-first, parents before children, one card per `params`
## entry per netlisted device, `.save all` first (I2). Derived from the fixture
## by hand and cross-checked against `xschem netlist` by row W15.
##   MT0                 top-level device, template arm
##   xok1/xok2           TWO instances of ONE cell -> two distinct prefixes
##     MP1               devproc arm (`.dp`)
##     MLVS              lvs_ignore, and ::lvs_ignore is 0 here
##     xdeep.MT1         level 2, template arm
##   x2[1] / x2[0]       the two members of one vector instance
## and NOT: MTIGN MTSHORT (spice_ignore), MONLY (only_toplevel below entry),
## xign xshort xnofmt xdsign xsymdef xstop (the six subtree drops).
set W_BLOCK {.save all
.save @m.mt0[id]
.save @m.mt0[gm]
.save @m.xok1.mp1.dp[id]
.save @m.xok1.mp1.dp[gm]
.save @m.xok1.mlvs[id]
.save @m.xok1.mlvs[gm]
.save @m.xok1.xdeep.mt1[id]
.save @m.xok1.xdeep.mt1[gm]
.save @m.xok2.mp1.dp[id]
.save @m.xok2.mp1.dp[gm]
.save @m.xok2.mlvs[id]
.save @m.xok2.mlvs[gm]
.save @m.xok2.xdeep.mt1[id]
.save @m.xok2.xdeep.mt1[gm]
.save @m.x2[1].mv[id]
.save @m.x2[1].mv[gm]
.save @m.x2[0].mv[id]
.save @m.x2[0].mv[gm]
}
## The same walk entered ONE LEVEL DOWN. Rooted THERE (ruling D2), and MONLY is
## now in the deck because only_toplevel is relative to the deck's top — the
## sharpest evidence that the filter is answered by the netlister and not by a
## Tcl mirror.
set W_BLOCK_MID {.save all
.save @m.mp1.dp[id]
.save @m.mp1.dp[gm]
.save @m.monly[id]
.save @m.monly[gm]
.save @m.mlvs[id]
.save @m.mlvs[gm]
.save @m.xdeep.mt1[id]
.save @m.xdeep.mt1[gm]
}

if {[catch {

set W_LIBS ":$W_LIB:[file join $repo xschem_library devices]"
set XSCHEM_LIBRARY_PATH $W_LIBS
opa_w_fixture $W_LIB
opa_w_register
set W_CONF_SAVE $::USER_CONF_DIR
set ::USER_CONF_DIR $W_CONF
set netlist_dir $W_NL

# ===========================================================================
# W0 — FIXTURE, ASSERTED. Green before and after; it makes every row below a
# claim about save_cards instead of a claim about the library path.
# ===========================================================================
opa_w_load w_top.sch
check {W0 FIXTURE w_top.sch: 12 instances, both device arms resolve, no raw} \
  [list [xschem get instances] [rcall {op_annot::type MT0}] [rcall {op_annot::type MP1}] \
        [xschem get sch_path] [xschem raw loaded]] \
  [list 12 {0 w_nmos} {0 {}} {.} -1]

# ===========================================================================
# W1 — THE SURFACE, AND THE BASIS ARGUMENT devpath GREW
# ===========================================================================
# ⚠ `op_annot::devpath MT0` WITH NO BASIS MUST NOT MOVE. Every S5/S6/S9 consumer
# calls it that way from inside a draw path; if the default became `deck` the
# display would silently change and section P's byte-diffs would be the only
# thing left to notice.
check {W1 save_cards / write_save_file / last_warnings exist, devpath takes ?basis? ?root?, and the READ default is unmoved} \
  [list [expr {[info commands ::op_annot::save_cards]      ne {}}] \
        [expr {[info commands ::op_annot::write_save_file] ne {}}] \
        [expr {[info commands ::op_annot::last_warnings]   ne {}}] \
        [rcall {llength [info args ::op_annot::devpath]}] \
        [rcall {op_annot::devpath MT0}]] \
  [list 1 1 1 {0 3} {0 @m.mt0}]

check_raises {W1b an unrecognised basis RAISES, naming `basis`} \
  {op_annot::devpath MT0 sideways} basis
check_raises {W1c a root with basis `read` RAISES, naming `root`} \
  {op_annot::devpath MT0 read .xok1.} root

# ===========================================================================
# W2 — THE ACCEPTANCE GOLDEN: the whole block, exactly
# ===========================================================================
opa_w_load w_top.sch
set w2 [rcall {op_annot::save_cards}]
set W_BLK [lindex $w2 1]
check {W2 GOLDEN the 19-line block: depth-first, one card per params entry per NETLISTED device} \
  $w2 [list 0 $W_BLOCK]

# ===========================================================================
# W3 — THE BLOCK'S SHAPE (invariant I2, rule R2)
# ===========================================================================
# ⚠ THE DOT-CARD. A bare deck-level `save all` is not a spelling nicety: ngspice
# parses it as an `s`-prefixed SWITCH instance and dies with `Unable to find
# definition of model`, writing NO RAW AT ALL — strictly worse than omitting it.
# Re-measured on 46+ for this section. And an empty walk must return {}, not a
# lone `.save all`: a file whose entire content is a header says nothing while
# reporting success.
set w3lines [opa_w_lines $W_BLK]
set w3all 0 ; foreach l $w3lines { if {$l eq {.save all}} { incr w3all } }
opa_w_load w_bare.sch
set w3empty [rcall {op_annot::save_cards}]
opa_w_load w_top.sch
check {W3 I2 `.save all` is the first line and appears once; no BARE `save all`; an empty walk is {}; derived/pinexpr add no card} \
  [list [lindex $w3lines 0] $w3all [llength [opa_w_pick $W_BLK {save all*}]] \
        $w3empty \
        [string first {[gm/id]} $W_BLK] [string first {[vgs]} $W_BLK]] \
  [list {.save all} 1 0 {0 {}} -1 -1]

# ===========================================================================
# W4 — RULE R4: THE CARD IS BARE, AND IT IS [devpath][param]
# ===========================================================================
# `.save i(@m.xm1.m1[id])` puts NOTHING in the raw and says nothing. The block
# must therefore contain no wrapper at all — and the second leg ties the emitted
# text to the ONE builder (I1), so an emitter that grew its own concatenation
# cannot pass by accident.
check {W4 R4/I1 no card carries an i()/v() wrapper, and each card is [devpath][param]} \
  [list [string first {(} $W_BLK] \
        [rcall {list ".save [op_annot::devpath MT0 deck .]\[id\]" \
                     ".save [op_annot::devpath MT0 deck .]\[gm\]"}]] \
  [list -1 [list 0 [list {.save @m.mt0[id]} {.save @m.mt0[gm]}]]]

# ===========================================================================
# W5/W6/W7 — ISSUE 0436: A RAW LOADED ONE LEVEL DOWN MOVES NOTHING
# ===========================================================================
# The raw is loaded while standing in xok1, exactly as the menu item directly
# ABOVE the new one does ("Annotate Operating Point into schematic" loads at the
# current level), then the walk is run from the top. `raw->schname` is bound to
# w_ok.sch (save.c:1269) and sch_waves_loaded() re-matches it AS THE WALK
# DESCENDS, so `sim_sch_path` strips a component at BOTH xok1 and xok2 and the
# read basis answers one name for two devices.
set W_RAW [file join $scratch w_lvl1.raw]
set fd [open $W_RAW w]
puts -nonewline $fd "Title: w level1 fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\t@m.mp1.dp\[gm\]\tadmittance
\t1\tv(net1)\tvoltage
Values:
0\t1e-04
\t1.0
"
close $fd
opa_w_load w_top.sch
xschem unselect_all ; xschem select instance 3 fast nodraw ; xschem descend 1 2
set w5_ann [rcall {xschem annotate_op $W_RAW}]
set w5_lvl [list [xschem raw loaded] [xschem get sim_sch_path]]
xschem go_back 2
set w5 [rcall {op_annot::save_cards}]
set W_BLKR [lindex $w5 1]

## ⚠ W5 AND W6 ASSERT ON DISJOINT SUBSETS ON PURPOSE. The devproc arm and the
## `@path` TEMPLATE arm reach the hierarchy prefix by different routes — the Tcl
## `_pathfor` seam and translate's own copy of the stripping loop (token.c:4719)
## — and a fix to one leaves the other raw-relative. A sabotage variant that reds
## BOTH rows means the fixture has lost one of its two arms.
check {W5 0436 the DEVPROC arm's cards are byte-identical with a raw loaded one level down} \
  [list [lindex $w5_ann 0] $w5_lvl \
        [opa_w_dpcards $W_BLKR]] \
  [list 0 {1 {}} [opa_w_dpcards $W_BLOCK]]

check {W6 0436 the @path TEMPLATE arm's cards are byte-identical too (token.c:4719)} \
  [opa_w_tmplcards $W_BLKR] [opa_w_tmplcards $W_BLOCK]

## ⚠ THE CONTROL LEGS ARE THE NON-VACUITY. With no raw loaded the two bases give
## the same string, so this row can only bite while the raw is resident: the last
## two elements are what the READ basis answers for the SAME instance name in the
## two subcells, measured live.
xschem unselect_all ; xschem select instance 3 fast nodraw ; xschem descend 1 2
set w7r1 [rcall {op_annot::devpath MP1}]
xschem go_back 2
xschem unselect_all ; xschem select instance 4 fast nodraw ; xschem descend 1 2
set w7r2 [rcall {op_annot::devpath MP1}]
xschem go_back 2
## ⚠ 18 CARDS OVER 9 DISTINCT DEVICES — two params each, so the card count and
## the device count are different numbers and both are load-bearing. Under the
## raw-relative basis the block still has 18 cards but only SIX distinct devices:
## xok1's and xok2's three devices collapse pairwise, which is issue 0436's
## measured "8 cards, only 5 unique" on a 3-level fixture.
check {W7 0436 two instances of ONE subcell keep two names -- 18 cards over 9 devices -- while the READ basis collapses them} \
  [list [llength [opa_w_devs $W_BLKR]] \
        [llength [lsort -unique [opa_w_devs $W_BLKR]]] $w7r1 $w7r2] \
  [list 18 9 {0 @m.mp1.dp} {0 @m.mp1.dp}]

catch {xschem raw clear}
opa_w_load w_top.sch

# ===========================================================================
# W8 — RULING D2: THE BASIS IS ENTRY-RELATIVE, NOT LEVEL-0 ABSOLUTE
# ===========================================================================
# `xschem netlist` from a descended cell makes THAT cell the deck top — measured
# on this fixture — so entry-relative is the only basis naming devices the deck
# the user would simulate from here actually contains, and it is what makes
# `<cell>.save` agree with its own body. MONLY appears here and nowhere in W2:
# only_toplevel is answered by the deck, at the level the deck starts from.
xschem unselect_all ; xschem select instance 3 fast nodraw ; xschem descend 1 2
set w8 [rcall {op_annot::save_cards}]
set w8_at [list [xschem get currsch] [xschem get sch_path]]
while {[xschem get currsch] > 0} { catch {xschem go_back 2} }
check {W8 D2 a walk entered one level down is rooted THERE, and only_toplevel changes answer} \
  [list $w8 $w8_at] [list [list 0 $W_BLOCK_MID] {1 .xok1.}]

# ===========================================================================
# W9 — THE THREE INSTANCE-LEVEL DROP CLASSES (issue 0437, invariant I2b)
# ===========================================================================
# One `spice_ignore=true` device anywhere is enough to make a generated .save
# file kill the simulation it was generated for.
opa_w_load w_top.sch
check {W9 0437 spice_ignore=true/short and only_toplevel contribute NO card, while the plain sibling does} \
  [list [opa_w_under $W_BLK {@m.mtign}] [opa_w_under $W_BLK {@m.mtshort}] \
        [string first {monly} $W_BLK] \
        [opa_w_under $W_BLK {@m.xign.}] [opa_w_under $W_BLK {@m.xshort.}] \
        [opa_w_under $W_BLK {@m.mt0}]] \
  [list 0 0 -1 0 0 2]

# ===========================================================================
# W10 — lvs_ignore IS THE USER'S SETTING, INHERITED AND NOT FORCED
# ===========================================================================
# `skip_instance()` consults the `lvs_ignore` Tcl var (spice_netlist.c:178). No
# Tcl mirror of the netlister's rules has ever read it; an oracle that RUNS the
# netlister gets it for free — and must not clobber it.
set w10_before [expr {[info exists ::lvs_ignore] ? $::lvs_ignore : 0}]
set ::lvs_ignore 1
set w10on [rcall {op_annot::save_cards}]
set w10_still $::lvs_ignore
set ::lvs_ignore $w10_before
set w10off [rcall {op_annot::save_cards}]
check {W10 ::lvs_ignore 1 drops the MLVS cards, 0 keeps them, and the walk does not clobber the setting} \
  [list [lindex $w10on 0] [opa_w_under [lindex $w10on 1] {@m.xok1.mlvs}] \
        $w10_still \
        [lindex $w10off 0] [opa_w_under [lindex $w10off 1] {@m.xok1.mlvs}] \
        [lindex $w10off 1]] \
  [list 0 0 1 0 2 $W_BLOCK]

# ===========================================================================
# W11-W14 — THE FOUR SYMBOL-LEVEL DROP CLASSES ATTEMPT 2 MISSED (issue 0442)
# ===========================================================================
# Each row states the DECK fact first and the CARD fact second, so a row that
# reds says which half moved. The deck is netlisted by this file, into this
# file's own directory, by code that shares nothing with src/op_annot.tcl.
opa_w_load w_top.sch
set W_DECK [opa_w_netlist w_top.sch]
set W_DBLK [opa_w_blocks $W_DECK]
opa_w_load w_top.sch
## ⚠ ISSUE 0499(c), AND IT IS WHY EACH OF W11-W14 GREW A LEG. Their predecessors
## asserted "no card under this prefix" and NOTHING ELSE. Aliasing `_descendable`
## to `_netlisted` — attempt 2's shipped defect — makes the walk ENTER every one
## of these four cells; no card comes out only because the leaked child's own
## cell has no block in the index. The rows were true for a reason they did not
## test. `opa_w_walk` records `sch_path` after every `xschem descend` from
## OUTSIDE the implementation, so "did not enter" is now a claim.
set w11_run [opa_w_walk {op_annot::save_cards}]
set W_ENT [lindex $w11_run 2]
opa_w_load w_top.sch

## ⚠ THE LAST LEG OF EACH OF W11-W13 IS THE NON-VACUITY ANCHOR, AND IT IS NOT
## DECORATION. "No card under this prefix" is trivially true of an EMPTY block,
## so without a leg that requires the walk to have emitted the ALLOWED subtree
## these three rows are green against an absent save_cards -- measured, all three
## passed before the anchor was added. w_nofmt.sch, w_dsign.sch, w_symdef.sch and
## w_stop.sch are byte-copies of w_ok.sch, so a leaked class emits exactly the
## six cards the healthy sibling emits.
check {W11 0442 an empty `format` removes the instance AND its block from the deck: no card, no descend} \
  [list [expr {[lsearch -exact [opa_w_expand $W_DBLK w_top {}] xnofmt] >= 0}] \
        [dict exists $W_DBLK w_nofmt] \
        [opa_w_under $W_BLK {@m.xnofmt.}] [opa_w_under $W_BLK {@m.xok1.}] \
        [opa_w_ent $W_ENT {*xnofmt*}] [opa_w_ent $W_ENT {.xok1.}]] \
  {0 0 0 6 0 1}

check {W12 0442 default_schematic=ignore keeps the CALL and emits no block: no card, no descend} \
  [list [expr {[lsearch -exact [opa_w_expand $W_DBLK w_top {}] xdsign] >= 0}] \
        [dict exists $W_DBLK w_dsign] \
        [opa_w_under $W_BLK {@m.xdsign.}] [opa_w_under $W_BLK {@m.xok1.}] \
        [opa_w_ent $W_ENT {*xdsign*}]] \
  {1 0 0 6 0}

check {W13 0442 spice_sym_def emits `** sym_path:` and NO `** sch_path:`: the subtree contributes nothing} \
  [list [opa_w_pathkinds $W_DECK w_symdef.sym] \
        [dict exists $W_DBLK w_symdef] \
        [opa_w_under $W_BLK {@m.xsymdef.}] [opa_w_under $W_BLK {@m.xok1.}] \
        [opa_w_ent $W_ENT {*xsymdef*}]] \
  [list {1 0} 1 0 6 0]

# ⚠ W14 IS THE ROW ATTEMPT 2 COULD NOT HAVE: `_netlisted` and `_descendable`
# must genuinely DIVERGE on one instance. spice_stop emits a real `.subckt`
# block, with a `** sch_path:`, EMPTY — the deck holds the call and not the body.
# Aliasing the two predicates is what attempt 2 shipped, and its own sabotage
# variant reddened nothing because its fixture was flat.
set w14_pred [rcall {
  set idx [op_annot::_deck_index [op_annot::_oracle_deck]]
  set r {}
  set n [xschem get instances]
  for {set i 0} {$i < $n} {incr i} {
    if {[xschem getprop instance $i name] eq {xstop}} {
      set r [list [op_annot::_netlisted $i $idx] [op_annot::_descendable $i $idx]]
    }
  }
  set r
}]
check {W14 0442 spice_stop emits a PRESENT but EMPTY block, and _netlisted / _descendable diverge on it} \
  [list [opa_w_pathkinds $W_DECK w_stop.sym] \
        [dict exists $W_DBLK w_stop] [llength [dict get $W_DBLK w_stop]] \
        [opa_w_under $W_BLK {@m.xstop}] $w14_pred \
        [opa_w_ent $W_ENT {*xstop*}]] \
  [list {1 1} 1 0 0 {0 {1 0}} 0]

# ===========================================================================
# W15 — THE CROSS-CHECK, BOTH DIRECTIONS, ON A HIERARCHICAL FIXTURE
# ===========================================================================
# ⚠ THIS IS THE ROW THAT DECIDES THE STEP, AND ITS PREDECESSOR WAS GREEN WHILE
# BROKEN. Attempt 2's cross-check was the right oracle asked of a FLAT fixture
# whose only variants were the classes it already handled, so it could not fail.
# Here the deck is expanded by opa_w_expand — this file's own recursion over the
# netlister's output — and compared in BOTH directions: an orphan card (a device
# no deck contains, i.e. the raw-destroying card) and a missing device (silent
# under-emission, i.e. blank rows the user will read as "unsupported PDK").
set W_EXP [opa_w_mdevs [opa_w_expand $W_DBLK w_top {}]]
check {W15 0442 the cards name EXACTLY the devices the netlister put in the deck: 9 devices, 2 params, no orphan, none missing} \
  [list [llength $W_EXP] [opa_w_xcheck $W_BLK $W_EXP 2]] \
  [list 9 {{} {}}]

# ===========================================================================
# W16 — THE DECK IS TEXT, AND THE USER-ARCHITECTURE REGION IS NOT ELEMENTS
# ===========================================================================
# Two traps in one cell, both reachable from a shipped `code_shown` symbol:
#   * a line that LOOKS like an element (`MGHOST ...`) inside the user region,
#     naming an instance that is really spice_ignore'd. An index that reads the
#     region would call it netlisted and write a card for a device the deck does
#     not contain.
#   * a `.subckt`/`.ends` pair inside the region. An index that closes the
#     enclosing block at that `.ends` loses every element after it — here
#     MAFTER, whose cards are the only ones this cell owes.
opa_w_load w_codetop.sch
set w16 [rcall {op_annot::save_cards}]
check {W16 a fabricated element line in the user-architecture region adds no card, and its .subckt/.ends does not truncate the block} \
  [list $w16 [opa_w_under [lindex $w16 1] {@m.xcode.mghost}]] \
  [list [list 0 ".save all\n.save @m.xcode.mafter\[id\]\n.save @m.xcode.mafter\[gm\]\n"] 0]

# ===========================================================================
# W17 — A VECTOR INSTANCE IS DESCENDED ONCE AND WALKED PER MEMBER
# ===========================================================================
# `xschem expandlabel x2[1:0]` -> `x2[1],x2[0] 2`. The netlister writes one
# element line per MEMBER while the instance's own name is the bracketed RANGE,
# which appears in the deck nowhere — a membership test that compares the raw
# name answers 0 for every vector instance and the walk then refuses to descend.
opa_w_load w_top.sch
check {W17 both members of x2[1:0] are walked, in order, with distinct cards, and the hierarchy is back at entry} \
  [list [opa_w_pick $W_BLK {*@m.x2*}] [opa_w_state]] \
  [list [list {.save @m.x2[1].mv[id]} {.save @m.x2[1].mv[gm]} \
              {.save @m.x2[0].mv[id]} {.save @m.x2[0].mv[gm]}] \
        {0 0 0 .}]

# ===========================================================================
# W18 — THE HIERARCHY PREFIX DROPS spiceprefix (issue 0488)
# ===========================================================================
# ⚠ MEASURED, AND IT IS THE RAW-DESTROYING SHAPE. `sch_path`, `sim_sch_path` and
# `@path` all carry the instance NAME only, so with `name=SUB1 spiceprefix=X` the
# deck says `XSUB1` while every card below says `@m.sub1.…`. EVERY card in that
# subtree is then bogus, which is the all-bogus case that makes ngspice write no
# raw at all. The walk warns and emits nothing for the subtree (I3: blank beats
# a plausible wrong number). Mitigation, not a fix: zero of the 533 shipped
# type=subcircuit symbols carry spiceprefix, so this is user-reachable and not
# shipped-reachable.
opa_w_load w_pfxtop.sch
set w18 [rcall {op_annot::save_cards}]
set w18w [rcall {op_annot::last_warnings}]
check {W18 0488 a spiceprefix'd subcircuit emits NO cards for its subtree, and says so by name} \
  [list $w18 \
        [regexp -nocase {sub1} [lindex $w18w 1]] \
        [regexp -nocase {xsub1} [lindex $w18w 1]]] \
  [list [list 0 ".save all\n.save @m.mt0\[id\]\n.save @m.mt0\[gm\]\n"] 1 1]

# ===========================================================================
# W19 — INVARIANT I6 (happy path) AND I4
# ===========================================================================
# ⚠ `xschem get modified` IS READ BEFORE ANY SAVE. The S9 crew's own I4 row was
# vacuous because it read `modified` after its own `xschem save`.
opa_w_load w_top.sch
set w19_before [opa_w_state]
set w19_m0 [xschem get modified]
set w19_n0 [xschem get instances]
set w19_rc [lindex [rcall {op_annot::save_cards}] 0]
check {W19 I6/I4 no_draw, keep_symbols, currsch and sch_path are back at entry, and the sheet is untouched} \
  [list $w19_rc $w19_before [opa_w_state] \
        [expr {[opa_w_state] eq $w19_before}] \
        $w19_m0 [xschem get modified] $w19_n0 [xschem get instances]] \
  [list 0 {0 0 0 .} {0 0 0 .} 1 0 0 12 12]

# ===========================================================================
# W20 — INVARIANT I6 ON THE ERROR PATH (issue 0431), AND RE-ENTRANCY (0438)
# ===========================================================================
# The prototypes' restore is straight-line code on the normal path: measured,
# `sky130_save_fet_params` on `sky130_tests/test_generators` raises and leaves
# no_draw=1 keep_symbols=1 set. The shim forces the same shape BELOW the entry
# level. The last leg is 0438: a second call must SUCCEED, or the walk left its
# own busy flag set and the feature is dead for the rest of the session.
opa_w_load w_top.sch
set w20_before [opa_w_state]
opa_w_shim_on
set w20 [rcall {op_annot::save_cards}]
set w20_after [opa_w_state]
set w20_hits $::opa_w_shim_hits
opa_w_shim_off
set w20_again [rcall {op_annot::save_cards}]
check {W20 I6/0431/0438 a forced mid-walk raise propagates, restores everything, and does not wedge the next call} \
  [list [expr {$w20_hits > 0}] [lindex $w20 0] \
        [string match {*opa forced mid-walk failure*} [lindex $w20 1]] \
        $w20_before $w20_after [expr {$w20_after eq $w20_before}] \
        $w20_again] \
  [list 1 1 1 {0 0 0 .} {0 0 0 .} 1 [list 0 $W_BLOCK]]

# ===========================================================================
# W21 — THE UNWIND IS BOUNDED BY THE ENTRY LEVEL, NOT BY 0
# ===========================================================================
# `src/xschem.tcl:3857`'s idiom `while {[xschem get currsch]} {xschem go_back}`
# would ascend past a caller who was already descended — and S4's render_deck is
# exactly such a caller. Issue 0431 never measured this half: its cell raises at
# the top, where sch_path survives by luck.
opa_w_load w_top.sch
xschem unselect_all ; xschem select instance 3 fast nodraw ; xschem descend 1 2
set w21_before [opa_w_state]
opa_w_shim_on
set w21 [rcall {op_annot::save_cards}]
set w21_after [opa_w_state]
set w21_hits $::opa_w_shim_hits
opa_w_shim_off
while {[xschem get currsch] > 0} { catch {xschem go_back 2} }
check {W21 I6 a raise below a DESCENDED entry unwinds to currsch 1, not to 0} \
  [list [expr {$w21_hits > 0}] [lindex $w21 0] $w21_before $w21_after] \
  [list 1 1 {0 0 1 .xok1.} {0 0 1 .xok1.}]

# ===========================================================================
# W22 — no_undo HAS NO GETTER (issue 0432), SO PROBE ITS EFFECT
# ===========================================================================
# `xschem get no_undo` returns {} whether the flag is 0 or 1, so "back to its
# entry value" is unwritable as a flag read: as `== 0` it fails, as "equals the
# entry value" it passes vacuously against {}. The probe pushes, deletes and
# undoes. ⚠ THE SECOND LEG IS THE NON-VACUITY: with no_undo left set the SAME
# probe on the SAME fixture does not come back, so the row provably discriminates
# instead of passing against any binary at all.
opa_w_load w_top.sch
set w22_rc [lindex [rcall {op_annot::save_cards}] 0]
set w22_live [opa_w_undo_probe]
opa_w_load w_top.sch
xschem set no_undo 1
set w22_dead [opa_w_undo_probe]
xschem set no_undo 0
check {W22 0432 undo still works after the walk; control: with no_undo left set it does not} \
  [list $w22_rc $w22_live $w22_dead] [list 0 {12 11 12} {12 11 11}]

# ===========================================================================
# W23 — THE WALK SELF-LOGS, AND MUST SUPPRESS ITSELF (--logdir only)
# ===========================================================================
# `descend`/`go_back` self-log (actions.c:4446, :4602) and the oracle's netlist
# would too but for `-keep_symbols` (scheduler.c:8887). A walk over a real design
# floods a log whose contract is REPLAYABLE USER EDITS. ⚠ MEASURED COVERAGE TRAP:
# under --nolog dropping the `log_action -suppress pop` still gives ALL PASS, so
# this row is DARK unless the suite is also run with --logdir. The second half is
# what makes it a test of the POP: an unpopped scope silences the user's log for
# the rest of the session, which is worse than the flood it prevents.
set W_LOG [xschem get actionlog_filename]
if {$W_LOG eq {}} {
  opa_w_skiprow {W23 the walk adds no descend/go_back/netlist lines, and pops its suppress scope} \
                {no action log -- run with --logdir}
} else {
  opa_w_load w_top.sch
  set w23_0 [list [opa_w_logcount {*descend*}] [opa_w_logcount {*go_back*}] \
                  [opa_w_logcount {*netlist*}]]
  set w23_rc [lindex [rcall {op_annot::save_cards}] 0]
  set w23_1 [list [opa_w_logcount {*descend*}] [opa_w_logcount {*go_back*}] \
                  [opa_w_logcount {*netlist*}]]
  xschem unselect_all ; xschem select instance 3 fast nodraw
  xschem descend 1 2 ; xschem go_back 2
  set w23_2 [opa_w_logcount {*descend*}]
  check {W23 the walk adds no descend/go_back/netlist lines, and a real descend after it STILL logs} \
    [list $w23_rc [expr {$w23_1 eq $w23_0}] \
          [expr {$w23_2 > [lindex $w23_1 0]}]] \
    {0 1 1}
}

# ===========================================================================
# W24 — THE NETLIST ENVIRONMENT IS BORROWED AND GIVEN BACK
# ===========================================================================
# The oracle must force netlist_type=spice (skip_instance branches on it,
# netlist.c:1247), flat_netlist 0 (flatten.awk removes every .subckt, so there
# would be no `** sch_path:` blocks at all), split_files 0 and local_netlist_dir
# 0 (set_netlist_dir discards a requested dir when it is 1). It must give all of
# them back, including the C-side `netlist_name`, which `xschem netlist <file>`
# sets from the filename (scheduler.c:8796) and clears at :8869.
#
# ⚠ AND IT MUST NOT WRITE INTO $netlist_dir. That directory holds the user's
# netlists; the oracle's deck goes to its own place and is deleted. The last leg
# is the pre-check: an unwritable oracle directory must reach the user as a NAMED
# diagnostic, not as set_netlist_dir's modal tk_messageBox (src/xschem.tcl:9001,
# which no -noalert reaches) and not as a Tcl primitive error three frames down.
## ⚠ THE ENVIRONMENT IS DELIBERATELY PUT IN THE *WRONG* STATE FIRST, AND THAT IS
## WHAT MAKES THIS ROW DISCRIMINATE. Measured: with every variable already at the
## value the oracle forces, a restore that does nothing at all is invisible —
## `netlist_dir` is given back by the netlister itself (scheduler.c:8891) and the
## other five never moved. Forcing local/flat/split/name to non-default values
## first is what turns "restored" into a claim.
opa_w_load w_top.sch
set fdz [open [file join $W_NL decoy.spice] w] ; puts $fdz "* decoy, must not move" ; close $fdz
set ::local_netlist_dir 1
set ::flat_netlist 1
set ::split_files 1
catch {xschem set netlist_name w_top_custom.spice}
set w24_env0 [opa_w_netenv]
set w24_sig0 [opa_w_dirsig $W_NL]
set w24_rc [lindex [rcall {op_annot::save_cards}] 0]
set w24_env1 [opa_w_netenv]
set w24_sig1 [opa_w_dirsig $W_NL]
set w24_left [llength [glob -nocomplain -directory [file join $W_CONF op_annot] *]]
set W_NOTDIR [file join $scratch w_notadir]
set fdz [open $W_NOTDIR w] ; puts $fdz x ; close $fdz
set ::USER_CONF_DIR $W_NOTDIR
set w24_bad [rcall {op_annot::save_cards}]
set ::USER_CONF_DIR $W_CONF
check {W24 netlist_dir/local/flat/split/type/name all restored from a NON-DEFAULT state, $netlist_dir untouched, no deck left behind, and an unwritable oracle dir raises BY NAME} \
  [list $w24_rc [expr {$w24_env1 eq $w24_env0}] [expr {$w24_sig1 eq $w24_sig0}] \
        $w24_left [lindex $w24_bad 0] \
        [string match {*op_annot*} [lindex $w24_bad 1]] \
        [expr {[opa_w_netenv] eq $w24_env0}]] \
  [list 0 1 1 0 1 1 1]
set ::local_netlist_dir 0
set ::flat_netlist 0
set ::split_files 0
catch {xschem set netlist_name {}}

# ===========================================================================
# W25 — THE ORACLE RUNS A NETLIST, AND A NETLIST EATS A PENDING GESTURE (0263)
# ===========================================================================
# ⚠ THE SHARPEST SEAM OF THE INVERSION, MEASURED ON THIS FIXTURE: with a
# wire-label placement live (ui_state 16424, 13 instances) a bare `xschem
# netlist` calls leave_placement_for("Netlist") (scheduler.c:8848) whose teardown
# IS a delete() — after it, ui_state 0 and 12 instances. Neither that call nor
# leave_merge_for is suppressible from Tcl. So a read-only annotation menu item
# would silently destroy the symbol the user is carrying on the cursor, or the
# paste they have not dropped. save_cards must REFUSE and leave the gesture where
# it was; the door itself belongs to tests/headless/test_placement_preview_doors.tcl.
opa_w_load w_top.sch
set ::label_new_name FOO
catch {xschem add_wire_label -place}
set w25_p0 [list [expr {([xschem get ui_state] & 16384) ? 1 : 0}] [xschem get instances]]
set w25_p [rcall {op_annot::save_cards}]
set w25_p1 [list [expr {([xschem get ui_state] & 16384) ? 1 : 0}] [xschem get instances]]
xschem abort_operation ; xschem abort_operation ; xschem abort_operation
opa_w_load w_top.sch
set W_MERGE [file join $scratch w_one_wire.sch]
set fdz [open $W_MERGE w]
puts $fdz "v {xschem version=3.4.8RC file_version=1.3}"
puts $fdz "G {}" ; puts $fdz "K {}" ; puts $fdz "V {}" ; puts $fdz "S {}" ; puts $fdz "E {}"
puts $fdz "N 900 900 1000 900 {}"
close $fdz
catch {xschem merge $W_MERGE}
set w25_m0 [list [expr {([xschem get ui_state] & 256) ? 1 : 0}] [xschem get wires]]
set w25_m [rcall {op_annot::save_cards}]
set w25_m1 [list [expr {([xschem get ui_state] & 256) ? 1 : 0}] [xschem get wires]]
xschem abort_operation ; xschem abort_operation ; xschem abort_operation
check {W25 0263 save_cards REFUSES on a pending placement and on a pending paste, and neither gesture is eaten} \
  [list $w25_p0 [lindex $w25_p 0] [regexp -nocase {plac|pending|gesture|paste|merge} [lindex $w25_p 1]] $w25_p1 \
        $w25_m0 [lindex $w25_m 0] [regexp -nocase {plac|pending|gesture|paste|merge} [lindex $w25_m 1]] $w25_m1] \
  [list {1 13} 1 1 {1 13} {1 1} 1 1 {1 1}]

# ===========================================================================
# W26 — THE MENU ITEM'S ONE MOVING PART: write_save_file
# ===========================================================================
# Modelled on IHP's `Create FET and BIP .save file` (sg13g2_procs.tcl:602-606),
# including its `file mkdir $netlist_dir` — which sky130_procs.tcl:235 lacks.
# ⚠ WARNINGS BECOME `* NOTE:` COMMENT LINES, ONE PER LINE. A wrapped continuation
# with no leading `*` in a file a SPICE parser reads would be taken for a card.
# ⚠ AND NOTHING-TO-SAVE WRITES NO FILE: a .save file whose entire content is a
# header says nothing while reporting success.
opa_w_load w_top.sch
catch {file delete -force [file join $W_NL w_top.save]}
catch {file delete -force [file join $W_NL w_bare.save]}
set w26 [rcall {op_annot::write_save_file}]
set w26_txt {}
if {[lindex $w26 0] == 0 && [lindex $w26 1] ne {} && [file isfile [lindex $w26 1]]} {
  set fdz [open [lindex $w26 1] r] ; set w26_txt [read $fdz] ; close $fdz
}
set w26_first {}
foreach l [split $w26_txt "\n"] {
  if {[string trim $l] eq {}} continue
  if {[string index [string trim $l] 0] eq {*}} continue
  set w26_first [string trim $l] ; break
}
opa_w_load w_bare.sch
set w26e [rcall {op_annot::write_save_file}]
## ⚠ 0497(a): the path where NO file is written is the one where the user is
## owed a sentence. A menu item that writes nothing and says nothing is the same
## silence this step exists to delete.
set w26e_w [rcall {op_annot::last_warnings}]
if {[info commands winfo] ne {}} {
  foreach wv [winfo children .] { if {[string match {.win*} $wv]} { catch {destroy $wv} } }
}
check {W26 write_save_file writes $netlist_dir/<cell>.save whose first non-comment line is `.save all`, and writes NO file when there is nothing to save} \
  [list $w26 $w26_first [string first $W_BLOCK $w26_txt] \
        $w26e [file exists [file join $W_NL w_bare.save]] \
        [lindex $w26e_w 0] [expr {[llength [lindex $w26e_w 1]] > 0}]] \
  [list [list 0 [file join $W_NL w_top.save]] {.save all} \
        [expr {[string length $w26_txt] - [string length $W_BLOCK]}] {0 {}} 0 0 1]

# ===========================================================================
# W27 — ISSUE 0433: THE TWO DESCEND FAILURE CLASSES, AS A UNIT
# ===========================================================================
# ⚠ THIS ROW EXISTS BECAUSE A SABOTAGE VARIANT REDDENED NOTHING. Neutralizing
# `op_annot::_descended` to `return 1` — the prototypes' own shape, which reads
# `xschem descend`'s return value and then issues an unconditional `go_back 2`
# — left the suite at ALL PASS. Every descend in this fixture SUCCEEDS, so the
# refusal split was covered by no row at all, and a walk that mistook a class-1
# refusal for a descent would pop a level it never pushed, corrupt sch_path for
# the rest of the walk and re-emit the parent's cards. Per spec landmine 11 a
# predicted red that does not appear is a fixture defect, not a footnote.
#
# The class-1 shape is reproducible without a broken cell: currsch UNCHANGED
# across the attempt is the whole test (`xschem descend` returns 0 for BOTH
# classes, which is why its return value is not consulted). The second leg is
# what makes it a test of the go_back discipline rather than of the return
# value: after a class-1 answer the hierarchy must not have moved.
opa_w_load w_top.sch
set w27_c1  [rcall {op_annot::_descended [xschem get currsch]}]
set w27_at1 [opa_w_state]
xschem unselect_all ; xschem select instance 3 fast nodraw ; xschem descend 1 2
set w27_ok  [rcall {op_annot::_descended 0}]
set w27_at2 [list [xschem get currsch] [xschem get sch_path]]
xschem go_back 2
check {W27 0433 _descended is 0 for a class-1 refusal and issues NO go_back, and 1 for a real descend} \
  [list $w27_c1 $w27_at1 $w27_ok $w27_at2 [opa_w_state]] \
  [list {0 0} {0 0 0 .} {0 1} {1 .xok1.} {0 0 0 .}]

# ===========================================================================
# W28 — WHAT THE WALK DID NOT EMIT, SPLIT INTO THREE NAMED COUNTERS (0497)
# ===========================================================================
# ⚠ THIS ROW REPLACES AN AGGREGATE THAT TOLD THE USER A DEFECT WAS NORMAL.
# Attempt 4 shipped ONE counter whose sentence ended `- normal for such cells`.
# On tb_bandgap_opamp it fired twice, the tool reported success, and 12 of the
# deck's 39 FETs had no card (issue 0496). For a spice_stop or behavioural cell
# that sentence is true; for a parameter specialisation the netlister expanded
# the cell, wrote its block, and the walk simply could not find it — which is a
# DEFECT wearing the word "normal".
#
# So the aggregate splits, and the split is the contract stated at the head of
# this section:
#     dropped_by_rule  the netlister dropped it (spice_ignore, only_toplevel,
#                      lvs_ignore, empty format, default_schematic=ignore,
#                      spice_sym_def, spice_stop). Expected. May say "normal".
#     not_found        the deck HAS it and the walk could not attribute it.
#                      Never normal. This is the 0496 counter.
#     name_failed      devpath/devproc could not build a name — a raising
#                      devproc, a blank template, the 0488 prefix guard.
#
# ⚠ AND IT IS ALSO THE ROW THAT UNDER-REDDENED. Aliasing `_descendable` to
# `_netlisted` reddens W14 and nothing else on a card-only assertion, because the
# leaked child's cards are masked while the WALK is not. W11-W14 now carry the
# entered-levels leg; this row carries the counters, and the two together are
# what make the alias visible from two directions.
#
# THE ARITHMETIC ON THIS FIXTURE, and it is attempt 4's own two measured numbers
# added together (it counted 4 devices and 6 subcircuit instances):
#     4 devices   MTIGN, MTSHORT (spice_ignore at the top) and MONLY ONCE PER
#                 ENTERED COPY of w_ok — xok1 and xok2 — where only_toplevel is
#                 false below the deck's top.
#     6 subckts   xign, xshort (instance-level), xnofmt, xdsign, xsymdef, xstop
#                 (symbol-level). Their INTERIORS are not counted: the walk never
#                 enters them, which is exactly what W11-W14 now assert.
#     = 10 dropped_by_rule, 0 not_found, 0 name_failed.
# Under `descendable_aliases_netlisted` the four leaked cells are entered and the
# device figure moves 4 -> 13, i.e. the triple becomes {19 0 0}. So this row
# discriminates the alias from the counter side while W11-W14 do it from the
# hierarchy side.
opa_w_load w_top.sch
set w28_rc [lindex [rcall {op_annot::save_cards}] 0]
set w28w [lindex [rcall {op_annot::last_warnings}] 1]
set w28c [opa_w_counts]
## The `- normal for such cells` phrase may still appear, but ONLY while the
## other two counters are zero. A sentence that calls an unattributed deck
## element normal is issue 0497 verbatim.
set w28_normal [regexp -nocase {normal for such cells} $w28w]
check {W28 0497 the three counters are named and separate, only dropped_by_rule is non-zero, and the words match the numbers} \
  [list $w28_rc $w28c \
        [expr {[lindex $w28c 1] == 0}] [expr {[lindex $w28c 2] == 0}] \
        [expr {[llength $w28w] > 0}] \
        [regexp -nocase {spice_stop|not expand|dropped} $w28w]] \
  [list 0 {10 0 0} 1 1 1 1]

## ⚠ THE NON-VACUITY: a fixture where `name_failed` is genuinely non-zero. The
## 0488 spiceprefix guard is the shipped one — W18's own top emits no cards below
## SUB1 — and it must land in `name_failed`, not in `dropped_by_rule`, or the
## user reading the report cannot tell a netlister rule from a defect.
opa_w_load w_pfxtop.sch
set w28_rc2 [lindex [rcall {op_annot::save_cards}] 0]
set w28c2 [opa_w_counts]
opa_w_load w_top.sch
check {W28b 0497/0488 a name the walk could not build lands in name_failed, not in dropped_by_rule} \
  [list $w28_rc2 [expr {[lindex $w28c2 2] > 0}] [lindex $w28c2 1]] \
  {0 1 0}

# ===========================================================================
# W29 — THE MENU ITEM ITSELF, WHICH NEEDS A DISPLAY
# ===========================================================================
# `Create device OP .save file` is a THIRD of this step's deliverable and the
# Graphs cascade is built inside `if {[info exists has_x]}`, so --nogui never
# constructs it and every row above would stay green if the item did not exist
# at all. Same self-skip contract as sections M and O2:
#
#   DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog \
#       --script tests/headless/test_op_annot.tcl
#
# ⚠ THE WORKER IS STUBBED AND THE WRAPPER IS WHAT IS MEASURED. write_save_file
# has its own row (W26); what has none is the five lines in src/xschem.tcl that
# decide what the user is TOLD. All three of its outcomes must reach the user as
# text — a menu click that writes nothing and says nothing is the same silence
# this step exists to delete, and here it would be silence about a file the user
# is going to `.include` into a testbench.
set w29i {}
if {![info exists has_x]} {
  opa_w_skiprow {W29 the Graphs-cascade menu item and its three outcomes} \
                {needs a display -- the cascade is built under `if {[info exists has_x]}`}
} else {
  ## ⚠ THIS ROW MUST NOT ABORT THE SECTION. Everything below it — W19a/W19b,
  ## W30/W30a, W31, W32, W33 — runs AFTER it, and a bare `rename` of an absent
  ## proc or an `index end` on an absent menu would raise into section W's own
  ## catch and take all of them with it. Before the change under test both the
  ## item and the worker ARE absent, which is exactly the state that must still
  ## produce ONE legible red instead of eight missing rows.
  set w29m .menubar.simulation.graph
  set w29i {}
  set w29n -1
  catch {set w29n [$w29m index end]}
  for {set i 0} {$i <= $w29n} {incr i} {
    if {[catch {$w29m type $i} ty]} continue
    if {$ty ne {command}} continue
    if {[$w29m entrycget $i -label] eq {Create device OP .save file}} { set w29i $i }
  }
  ## Position is part of the claim: the item belongs beside the other two
  ## op_annot items, not at the end of a cascade that also holds unrelated
  ## checkbuttons.
  set w29_prev {}
  if {$w29i ne {} && $w29i > 0} { catch {set w29_prev [$w29m entrycget [expr {$w29i - 1}] -label]} }
}
if {[info exists has_x] && ($w29i eq {} || [info commands ::op_annot::write_save_file] eq {})} {
  ## The absent case, stated as one row rather than as an aborted section.
  check {W29 the menu item exists beside the annotator, never raises, is SILENT on success and SPEAKS on both failures} \
    [list [expr {$w29i ne {}}] [expr {[info commands ::op_annot::write_save_file] ne {}}]] \
    {1 1}
} elseif {[info exists has_x]} {
  rename ::op_annot::write_save_file ::op_annot::write_save_file_realw29
  rename ::alert_ ::alert_realw29
  proc ::alert_ {txt args} { set ::opa_w29_alert $txt }
  set w29out {}
  foreach leg {ok empty raise} {
    switch -- $leg {
      ok     { proc ::op_annot::write_save_file {} { return /tmp/opa_w29.save } }
      empty  { proc ::op_annot::write_save_file {} { return {} } }
      raise  { proc ::op_annot::write_save_file {} {
                 return -code error "op_annot::save_cards: a PASTE/merge is pending." } }
    }
    set ::opa_w29_alert {}
    set rc [catch {$w29m invoke $w29i}]
    lappend w29out [list $leg $rc [expr {$::opa_w29_alert ne {}}]]
  }
  set w29_emptymsg {}
  proc ::op_annot::write_save_file {} { return {} }
  set ::opa_w29_alert {} ; catch {$w29m invoke $w29i} ; set w29_emptymsg $::opa_w29_alert
  set w29_raisemsg {}
  proc ::op_annot::write_save_file {} {
    return -code error "op_annot::save_cards: a PASTE/merge is pending." }
  set ::opa_w29_alert {} ; catch {$w29m invoke $w29i} ; set w29_raisemsg $::opa_w29_alert
  catch {rename ::op_annot::write_save_file {}}
  rename ::op_annot::write_save_file_realw29 ::op_annot::write_save_file
  catch {rename ::alert_ {}}
  rename ::alert_realw29 ::alert_
  check {W29 the menu item exists beside the annotator, never raises, is SILENT on success and SPEAKS on both failures} \
    [list [expr {$w29i ne {}}] $w29_prev $w29out \
          [regexp -nocase {save card|nothing written} $w29_emptymsg] \
          [regexp -nocase {pending} $w29_raisemsg]] \
    [list 1 {Add device OP annotator} \
          {{ok 0 0} {empty 0 1} {raise 0 1}} 1 1]
}


# ===========================================================================
# W19a/W19b — INVARIANT I4 ON A SHIPPED SCHEMATIC (issues 0495, 0499a)
# ===========================================================================
# ⚠ WHY THE FIXTURE ROW ABOVE IS NOT ENOUGH, MEASURED. W19 runs on a `.sch` this
# file wrote at file_version 1.2 with no autosave backup beside it, and passes
# for a reason that has nothing to do with the walk. On a SHIPPED bench the same
# assertion fails: `go_back` (actions.c:4766) calls `load_backup_as` (save.c:4191)
# whenever a `<cell>~.sch` sits next to the cell, and that function ends in
# `set_modify(1)` (save.c:4207). Re-measured today on
# sky130_tests_ase/bandgap_opamp, which ships with exactly such a `~`:
#
#     descend x1 ; go_back        -> modified 0 -> 1        (autosave_backup 1)
#     descend x1 ; go_back        -> modified 0 -> 0        (autosave_backup 0)
#
# So I4 ("the overlay never modifies the schematic") is violated by any walk over
# that bench, and the only reason nobody saw it is that no guardian ran there.
#
# W19b is the sharper half and it is not about a flag at all. With a `~` whose
# CONTENT differs from the `.sch`, go_back silently swaps the in-memory buffer
# for the backup's content. Measured today on a scratch byte-copy of the same
# bench with a `~` one instance short:
#
#     load .sch (73 inst, clean) ; descend ; go_back  ->  72 instances, modified 1
#
# A clean 73-instance buffer became a 72-instance one, and a `modified`-only row
# passes straight through it. Hence the instance count AND the file signature.
set W_SKY [file join $repo sky130A xschem_libs]
set W_BG  [file join $W_SKY sky130_tests_ase bandgap_opamp schematic bandgap_opamp.sch]
set W_SKYLIBS ":$W_SKY:[file join $repo xschem_library devices]"

if {![file isfile $W_BG]} {
  opa_w_skiprow {W19a/W19b I4 on a shipped schematic} {sky130_tests_ase/bandgap_opamp absent}
  opa_w_skiprow {W30a/W30 0496 on tb_bandgap_opamp} {sky130_tests_ase absent}
} else {
  set XSCHEM_LIBRARY_PATH $W_SKYLIBS
  set w_sky_src [opa_source [file join $repo sky130A sky130_procs.tcl]]

  ## ⚠ THE `~` IS PLANTED, NOT FOUND — ISSUE 0634, THE USER'S RULING (option 2).
  ##
  ## WHAT THIS ROW USED TO DO AND WHY IT WAS WRONG. It walked the SHIPPED
  ## `bandgap_opamp.sch` in place and asserted `file exists bandgap_opamp~.sch`
  ## was 1. That `~` is an AUTOSAVE BACKUP: untracked, and gitignored by
  ## `.gitignore:75  *~.sch`. So a committed check required a file the repository
  ## does not contain and cannot restore — measured on 2026-08-23, an agent
  ## deleted it while probing something else and this row went red with NO diff,
  ## `git status` clean and `git checkout` able to put nothing back. Worse, it
  ## fails in any FRESH CLONE, which is what someone following the project's own
  ## link gets. The row's own comment had warned about exactly this shape ("a row
  ## that did not record its presence would be measuring the developer's
  ## directory, not the code") and then required it anyway.
  ##
  ## THE FIX IS W19b's SHAPE, one row up the file. The cell is byte-copied into
  ## $scratch and the `~` is planted there from the same bytes, so the row is
  ## hermetic and writes nothing into a committed library. `$w19a_bak` therefore
  ## no longer reports a discovery — it asserts the PLANT SUCCEEDED, which is the
  ## fixture-before-verdict discipline the rest of this file uses: a row whose
  ## fixture failed to build must red as a fixture, not as a verdict.
  ##
  ## ⚠ BYTE-IDENTICAL ON PURPOSE, and that is the difference from W19b. The
  ## shipped `~` was byte-identical to its `.sch`, which is why the CONTENT half
  ## of 0495's harm is invisible HERE; W19b plants one that differs by an
  ## instance and catches that half. Copying the same bytes preserves W19a's
  ## exact premise rather than quietly strengthening it.
  ##
  ## WHAT IS LOST, said plainly: the walk is no longer over the file that ships.
  ## The property the row is named for is really about CONTENT — 73 instances,
  ## the real hierarchy, resolved out of the shipped library through
  ## XSCHEM_LIBRARY_PATH below — and a byte-copy keeps all of it. What it also
  ## buys back is that a walk which DID write (issue 0632's hazard) can no longer
  ## write into a committed library directory.
  set w19a_bakdir [file join $scratch wbga]
  file delete -force $w19a_bakdir ; file mkdir $w19a_bakdir
  set w19a_cell [file join $w19a_bakdir bandgap_opamp.sch]
  file copy -force $W_BG $w19a_cell
  file copy -force $W_BG [file join $w19a_bakdir bandgap_opamp~.sch]
  set w19a_bak [file exists [file join $w19a_bakdir bandgap_opamp~.sch]]
  set XSCHEM_LIBRARY_PATH "$W_SKYLIBS:$w19a_bakdir"
  catch {xschem raw clear}
  xschem load $w19a_cell
  set w19a_sig0 [opa_w_filesig $w19a_bakdir *.sch]
  set w19a_st0  [list [xschem get instances] [xschem get modified] [xschem get currsch]]
  set w19a [opa_w_walk {op_annot::save_cards}]
  set w19a_st1  [list [xschem get instances] [xschem get modified] [xschem get currsch]]
  set w19a_sig1 [opa_w_filesig $w19a_bakdir *.sch]
  check {W19a I4/0495 a walk over a byte-copy of the shipped bandgap_opamp, `~` planted beside it, leaves modified 0, the instance count and every byte on disk unchanged} \
    [list [lindex $w19a 0] $w19a_bak $w19a_st0 $w19a_st1 \
          [expr {$w19a_sig1 eq $w19a_sig0}]] \
    [list 0 1 {73 0 0} {73 0 0} 1]

  ## W19b: the same bench, byte-copied, with a PLANTED `~` that differs by one
  ## instance. Deterministically red without the autosave parking — measured.
  set W_BGDIR [file join $scratch wbg]
  file delete -force $W_BGDIR ; file mkdir $W_BGDIR
  file copy -force $W_BG [file join $W_BGDIR bandgap_opamp.sch]
  set fdz [open [file join $W_BGDIR bandgap_opamp.sch] r] ; set w19b_t [read $fdz] ; close $fdz
  set w19b_l [split $w19b_t "\n"] ; set w19b_o {} ; set w19b_cut 0
  for {set i [expr {[llength $w19b_l] - 1}]} {$i >= 0} {incr i -1} {
    set l [lindex $w19b_l $i]
    if {!$w19b_cut && [string range $l 0 1] eq {C }} { set w19b_cut 1 ; continue }
    set w19b_o [linsert $w19b_o 0 $l]
  }
  set fdz [open [file join $W_BGDIR bandgap_opamp~.sch] w]
  puts -nonewline $fdz [join $w19b_o "\n"] ; close $fdz
  set XSCHEM_LIBRARY_PATH ":$W_SKY:[file join $repo xschem_library devices]:$W_BGDIR"
  catch {xschem raw clear}
  xschem load [file join $W_BGDIR bandgap_opamp.sch]
  set w19b_st0 [list [xschem get instances] [xschem get modified]]
  set w19b [opa_w_walk {op_annot::save_cards}]
  set w19b_st1 [list [xschem get instances] [xschem get modified]]
  check {W19b I4/0495 with a DIFFERING `~` beside it, the walk leaves the buffer holding the DISK content, still clean} \
    [list $w19b_cut [lindex $w19b 0] $w19b_st0 $w19b_st1] \
    [list 1 0 {73 0} {73 0}]

  # =========================================================================
  # W31 — THE SAVE GATE (new issue 0626), AND WHY IT IS A REFUSAL
  # =========================================================================
  # Parking `autosave_backup` for the walk (the W19a/W19b fix) is safe only while
  # the entry buffer is CLEAN. Measured today, on the same byte-copy, with
  # autosave_backup 0 and a genuinely modified parent:
  #
  #     73 inst, clean -> delete one -> 72 inst, modified 1
  #     descend ; go_back                -> 73 inst, modified 1
  #
  # The unsaved edit is SILENTLY REVERTED and the buffer still claims to be
  # modified. With autosave_backup 1 the same sequence keeps 72. That is issue
  # 0626 and it is not op_annot's invention — `proc traversal`, both PDK
  # prototypes and hierarchy_close all reach it — but this step's menu item is a
  # new one-click way in, so save_cards REFUSES rather than walking.
  # ⚠ THE NEEDLE: the refusal must name the condition in words the user can act
  # on. `unsaved` or `autosave` — not a bare `cannot`.
  catch {xschem raw clear}
  xschem load [file join $W_BGDIR bandgap_opamp.sch]
  set ::autosave_backup 1
  xschem unselect_all ; xschem select instance [expr {[xschem get instances] - 1}] fast nodraw
  xschem delete
  set w31_a0 [list [xschem get instances] [xschem get modified]]
  set w31_a [rcall {op_annot::save_cards}]
  set w31_a1 [list [xschem get instances] [xschem get modified]]
  xschem load [file join $W_BGDIR bandgap_opamp.sch]
  set ::autosave_backup 0
  xschem unselect_all ; xschem select instance [expr {[xschem get instances] - 1}] fast nodraw
  xschem delete
  set w31_b0 [list [xschem get instances] [xschem get modified] [xschem get currsch]]
  set w31_b [rcall {op_annot::save_cards}]
  set w31_b1 [list [xschem get instances] [xschem get modified] [xschem get currsch]]
  set ::autosave_backup 1
  check {W31 0626 a modified sheet is walked with autosave ON and REFUSED with it OFF, by name, without moving} \
    [list $w31_a0 [lindex $w31_a 0] [lindex $w31_a1 1] \
          $w31_b0 [lindex $w31_b 0] \
          [regexp -nocase {unsaved|autosave} [lindex $w31_b 1]] $w31_b1] \
    [list {72 1} 0 1 {72 1 0} 1 1 {72 1 0}]

  # =========================================================================
  # W30a/W30 — ISSUE 0496 ON THE BENCH THAT REFUTED ATTEMPT 4
  # =========================================================================
  # `sky130_tests_ase/tb_bandgap_opamp` is the design 0496 was measured on, and
  # the only one in the tree carrying parameter-specialised subcircuits. Its deck
  # holds SEVEN blocks, two pairs of which share one `** sch_path:`:
  #
  #     .subckt passgate    <- sch_path .../passgate/schematic/passgate.sch
  #     .subckt passgate_1  <- sch_path .../passgate/schematic/passgate.sch
  #     .subckt gain_stage  <- sch_path .../gain_stage/schematic/gain_stage.sch
  #     .subckt gain_stage2 <- sch_path .../gain_stage/schematic/gain_stage.sch
  #
  # and the top calls `x6 … passgate_1` and `x3 … gain_stage2`. Attempt 4's
  # sch_path key merged each pair, `get_sch_from_sym` answered the synthesised
  # name, and 12 of the deck's FETs got no card while the tool reported success.
  #
  # ⚠ MEASURED TODAY AND NOT IN 0496: THE OBSTACLE IS NOT ONLY THE INDEX. The
  # specialisation is carried by an instance attribute `schematic=passgate_1`,
  # and get_sch_from_sym() (src/actions.c) resolves it to a path that does not
  # exist. This row calls the BARE `xschem descend`, which since issue 0979 is
  # the form that deliberately does NOT offer the cell's own schematic instead —
  # the offer is opt-in, spelled `xschem descend -fallback`, and every scripted
  # caller in the tree was left on the bare form on purpose. So no dialog can
  # appear on EITHER display, this row cannot hang the xvfb leg, and the class-2
  # refusal is the behaviour everywhere. Row A7 of
  # tests/headless/test_descend_doors_1228.tcl pins that bare-form default from
  # the other side, so a later crew cannot quietly flip it and redden this row
  # without meeting an explained assertion first:
  #
  #     x6  descend -> 0  currsch 0->1  err=load-failed  schname=<repo>/passgate_1  inst=0
  #     x3  descend -> 0  currsch 0->1  err=load-failed  schname=<repo>/gain_stage2 inst=0
  #     x1  descend -> 1  currsch 0->1  err={}           zero_opamp.sch  inst=70
  #
  # So re-keying the index is necessary and NOT sufficient: the walk also has to
  # reach the base schematic (the callee block's own `** sch_path:` names it
  # exactly, and `hi_descend_view_path`, consumed by get_sch_from_sym() in
  # src/actions.c, is the one-shot seam for it). W30a pins the obstacle; W30 is
  # the claim.
  set W_TB [file join $W_SKY sky130_tests_ase tb_bandgap_opamp schematic tb_bandgap_opamp.sch]
  set XSCHEM_LIBRARY_PATH $W_SKYLIBS
  catch {xschem raw clear}
  xschem load $W_TB
  set W_TBDECK [opa_w_netlist tb_bandgap_opamp.sch]
  lassign [opa_w_blocks2 $W_TBDECK] W_TBB W_TBP W_TBFIRST
  set W_TBFETS [opa_w_sky_fets [opa_w_expand2 $W_TBB $W_TBFIRST {}]]
  xschem load $W_TB
  set w30a_desc {}
  foreach want {x6 x3 x1} {
    set n [xschem get instances] ; set hit {}
    for {set i 0} {$i < $n} {incr i} { if {[xschem getprop instance $i name] eq $want} { set hit $i } }
    xschem unselect_all ; xschem select instance $hit fast nodraw
    set c0 [xschem get currsch]
    catch {xschem descend 1 2}
    lappend w30a_desc [list $want [expr {[xschem get currsch] - $c0}] [xschem get descend_error]]
    while {[xschem get currsch] > $c0} { catch {xschem go_back 2} }
  }
  ## FIXTURE + OBSTACLE. Green today and after: it states the two deck facts and
  ## the measured descend behaviour, so a W30 failure can be read.
  check {W30a FIXTURE/OBSTACLE tb_bandgap_opamp has 7 blocks, two specialised pairs sharing a sch_path, and a bare descend into both refuses class-2} \
    [list [llength [dict keys $W_TBB]] \
          [expr {[dict exists $W_TBB passgate] && [dict exists $W_TBB passgate_1]}] \
          [expr {[dict get $W_TBP passgate] eq [dict get $W_TBP passgate_1]}] \
          [expr {[dict get $W_TBP gain_stage] eq [dict get $W_TBP gain_stage2]}] \
          [llength $W_TBFETS] $w30a_desc] \
    [list 7 1 1 1 31 {{x6 1 load-failed} {x3 1 load-failed} {x1 1 {}}}]

  ## THE CLAIM. Both directions, on the real bench: no orphan card and none
  ## missing, with the two specialised subtrees present by name.
  catch {xschem raw clear}
  xschem load $W_TB
  set w30 [opa_w_walk {op_annot::save_cards}]
  set W_TBBLK [lindex $w30 1]
  if {[lindex $w30 0] != 0} { set W_TBBLK {} }
  set w30_devs [lsort -unique [opa_w_devs $W_TBBLK]]
  check {W30 0496 the card device set equals the deck's 31 sky130 FETs, x6/x3's specialised subtrees included, and nothing is called normal} \
    [list [lindex $w30 0] [llength $w30_devs] \
          [expr {$w30_devs eq $W_TBFETS}] \
          [opa_w_under $W_TBBLK {@m.x6.}] [opa_w_under $W_TBBLK {@m.x3.x6.}] \
          [opa_w_counts] \
          [regexp -nocase {normal for such cells} [lindex [rcall {op_annot::last_warnings}] 1]]] \
    [list 0 31 1 12 12 {0 0 0} 0]

  set XSCHEM_LIBRARY_PATH $W_LIBS
  opa_w_register
}

# ===========================================================================
# W32 — 0499(c)+(d) END TO END: A SHARED .sch, A CLASS-1 REFUSAL, ONE WALK
# ===========================================================================
# ⚠ WHAT 0499(c) ASKED FOR, AND WHAT IT MEASURES INSTEAD, MEASURED TODAY. It
# asks for a drop-class symbol whose `.sch` is SHARED with a normally netlisted
# instance, so a leaked descend finds a non-empty block and emits orphan cards.
# Built (`w_stopshared.sym`: spice_stop=true AND schematic=w_ok) and netlisted on
# THIS fixture, the deck says:
#
#     MT0 …  /  xsa … w_ok  /  xsb … w_stopshared  /  xsc … w_dsignshared
#     *  xmiss -  nosuch_w  IS MISSING !!!!            <- a comment, no element
#     .subckt w_ok D          MP1 … / MLVS … / xdeep … w_deep   <- 3 elements
#     .subckt w_stopshared D  .ends                             <- PRESENT, EMPTY
#     (no `.subckt w_dsignshared` at all)
#
# THE BLOCK NAME FOLLOWS THE SYMBOL, NOT THE SHARED SCHEMATIC. So a leaked
# descend into xsb still looks up an EMPTY block and emits nothing: the shared
# `.sch` does NOT create an observable over-emission, and 0499(c)'s residual risk
# stays argued rather than measured. Recorded here so the next attempt does not
# spend a day rebuilding this fixture to find that out.
#
# ⚠ AND NOTE WHAT THAT SYMBOL'S OWN `** sch_path:` SAYS — measured:
#     ** sch_path: /home/analog/dev/xschem-claude/w_ok
# a path that does not exist, because `schematic=w_ok` is resolved against the
# process cwd. A sch_path-keyed index (attempt 4's D3) would key this block on a
# string naming nothing — the same fragility 0496 measured from the other side.
# D2's `.subckt`-name key does not care.
#
# What DOES discriminate is the descend itself, which is 0499(c)'s other half:
# this row records it, from outside the implementation, with a Tcl execution
# trace on `xschem`.
#
# 0499(d) rides along: `xmiss` is an instance of a MISSING symbol, and `MT0` a
# plain device — measured, `xschem descend` on either is a CLASS-1 refusal
# (`missing-symbol` / `not-descendable`, currsch UNCHANGED), while x6-style
# specialisation is class-2. A walk that mistook either for a descent would pop a
# level it never pushed and re-emit the parent's cards, so the row asserts the
# card list has no duplicate AND the hierarchy is exactly where it started.
proc opa_w_sharefixture {lib} {
  set F "format=\"@name @pinlist @symname\"\ntemplate=\"name=x1\"\n"
  opa_w_sym $lib w_stopshared  subcircuit "$F schematic=w_ok\nspice_stop=true\n" 1
  opa_w_sym $lib w_dsignshared subcircuit "$F schematic=w_ok\ndefault_schematic=ignore\n" 1
  opa_w_sch $lib w_sharetop [list \
    {w_prim.sym         {name=MT0 model=nch}} \
    {w_ok.sym           {name=xsa}} \
    {w_stopshared.sym   {name=xsb}} \
    {w_dsignshared.sym  {name=xsc}} \
    {nosuch_w.sym       {name=xmiss}}]
}
set XSCHEM_LIBRARY_PATH $W_LIBS
opa_w_sharefixture $W_LIB
opa_w_load w_sharetop.sch
set W_SHDECK [opa_w_netlist w_sharetop.sch]
lassign [opa_w_blocks2 $W_SHDECK] W_SHB W_SHP W_SHFIRST
opa_w_load w_sharetop.sch
set w32 [opa_w_walk {op_annot::save_cards}]
set W_SHBLK [lindex $w32 1]
if {[lindex $w32 0] != 0} { set W_SHBLK {} }
## ⚠ CARDS, NOT DEVICE PATHS. The row's claim is "no card is emitted twice",
## and a re-visited level duplicates whole `.save` LINES. Written over
## `opa_w_devs` the leg is UNSATISFIABLE by construction: this section's
## descriptors carry TWO params, so every device legitimately appears in two
## cards and `llength devs == llength unique devs` is 0 for any correct block.
## It read as green only while save_cards did not exist and the list was empty
## — a vacuous leg, which is exactly what 0499 was filed about. Measured when S3
## landed: 8 cards over 4 devices.
set w32_devs [opa_w_lines $W_SHBLK]
## ⚠ THE DECK LEGS COME FIRST so a red says which half moved: `w_ok` must be a
## real non-empty block (otherwise "no card under xsb" is trivially true) and
## `w_stopshared` must be the present-but-empty one.
check {W32 0499c/0499d one walk: a shared-.sch drop class enters NO level, a class-1 refusal moves nothing, and no card is emitted twice} \
  [list [expr {[dict exists $W_SHB w_ok] ? [llength [dict get $W_SHB w_ok]] : {NOBLOCK}}] \
        [expr {[dict exists $W_SHB w_stopshared] ? [llength [dict get $W_SHB w_stopshared]] : {NOBLOCK}}] \
        [dict exists $W_SHB w_dsignshared] \
        [lindex $w32 0] \
        [opa_w_ent [lindex $w32 2] {.xsa.}] [opa_w_ent [lindex $w32 2] {*xsb*}] \
        [opa_w_ent [lindex $w32 2] {*xsc*}] [opa_w_ent [lindex $w32 2] {*xmiss*}] \
        [opa_w_under $W_SHBLK {@m.mt0}] [opa_w_under $W_SHBLK {@m.xsa.}] \
        [opa_w_under $W_SHBLK {@m.xsb.}] [opa_w_under $W_SHBLK {@m.xsc.}] \
        [opa_w_under $W_SHBLK {@m.xmiss.}] \
        [expr {[llength $w32_devs] == [llength [lsort -unique $w32_devs]]}] \
        [opa_w_state]] \
  [list 3 0 0 0 1 0 0 0 2 6 0 0 0 1 {0 0 0 .}]

# ===========================================================================
# W33 — ISSUE 0493: THE MEMO, ITS INVALIDATION, AND A WALL-CLOCK BOUND
# ===========================================================================
# Measured in 0493 on `xschem_library/examples/0_examples_top.sch` (49 top-level
# instances, 97 `.subckt` blocks, a 1.2 MB deck), with NO descriptor registered
# so the walk emits an EMPTY block:
#
#     oracle_deck 686 ms | deck_index 19 ms | save_cards 5176 ms
#     _normkey calls 34538 | descend/go_back 1712
#
# i.e. a menu click is a six-second freeze that produces nothing, and the cost is
# `_normkey`'s `abs_sym_path` + `file normalize` pair, not the oracle inversion.
# 0493's own suggested fix is a memo cleared at `save_cards` entry, and its own
# suggested guardian is the first leg here: two walks over one design with
# XSCHEM_LIBRARY_PATH CHANGED between them must not serve a stale key.
#
# ⚠ THE BOUND IS A REGRESSION BOUND, NOT A PERFORMANCE TARGET. 3000 ms sits 1.7x
# under the measured defect and ~4x over the oracle floor. A red here on a loaded
# box is worth re-measuring before it is believed — but a red at 5 s is 0493.
set W_EX [file join $repo xschem_library examples 0_examples_top.sch]
if {![file isfile $W_EX]} {
  opa_w_skiprow {W33 0493 the walk's memo is invalidated, and the largest shipped design stays under the bound} \
                {xschem_library/examples/0_examples_top.sch absent}
} else {
  ## Leg 1 — invalidation. Walk w_top, walk a DIFFERENT design, walk w_top again
  ## with the library path rewritten in between. All three answers must be the
  ## design's own, and the two w_top answers must be byte-equal.
  set XSCHEM_LIBRARY_PATH $W_LIBS
  opa_w_load w_top.sch  ; set w33_a [rcall {op_annot::save_cards}]
  opa_w_load w_codetop.sch ; set w33_b [rcall {op_annot::save_cards}]
  set XSCHEM_LIBRARY_PATH ":[file join $repo xschem_library devices]:$W_LIB"
  opa_w_load w_top.sch  ; set w33_c [rcall {op_annot::save_cards}]
  set XSCHEM_LIBRARY_PATH $W_LIBS
  ## Leg 2 — the bound, on the design 0493 profiled. No descriptor claims any of
  ## its cells, so the block is empty and the whole elapsed time is walk overhead.
  set XSCHEM_LIBRARY_PATH ":[file join $repo xschem_library examples]:[file join $repo xschem_library devices]"
  catch {xschem raw clear}
  set w33_load [catch {xschem load $W_EX}]
  set w33_t0 [clock milliseconds]
  set w33_big [rcall {op_annot::save_cards}]
  set w33_ms [expr {[clock milliseconds] - $w33_t0}]
  puts "note: W33 save_cards on 0_examples_top = ${w33_ms} ms (0493 measured 5176 ms; bound 3000 ms)"
  set XSCHEM_LIBRARY_PATH $W_LIBS
  opa_w_register
  check {W33 0493 a library-path change between two walks does not serve a stale key, and the largest shipped design stays under 3000 ms} \
    [list $w33_a $w33_c [expr {$w33_a eq $w33_c}] [expr {$w33_b ne $w33_a}] \
          $w33_load [lindex $w33_big 0] [expr {$w33_ms < 3000}]] \
    [list [list 0 $W_BLOCK] [list 0 $W_BLOCK] 1 1 0 0 1]
}
opa_w_load w_top.sch

set ::USER_CONF_DIR $W_CONF_SAVE
catch {xschem raw clear}

} werr]} {
  puts "UNEXPECTED ERROR (section W): $werr"
  incr fail
}

# =============================================================================
# SECTION X — THE LOOP NOBODY CLOSED: GENERATE, SIMULATE, READ BACK
# =============================================================================
# ⚠ ROW NAMES ARE XR1-XR5, NOT X1-X5. Sections A..U above already use bare `X<n>`
# for their "FIXTURE — asserted, not assumed" rows (X1..X14 are taken), so the
# plan's X1-X5 would collide in results.log and in every grep a reviewer runs.
# Mapping: plan X1->XR1, X2->XR2, X3->XR3, X4->XR4, X5->XR5.
# ⚠ WHY THIS SECTION EXISTS. Every earlier section verifies the READ path against
# a raw THIS FILE HAND-WROTE — section S spells `i(@m.xm1.msky130_fd_pr__nfet_01v8[id])`
# into its own fixture header. So the display has never been exercised against a
# raw that the feature's OWN save cards caused to exist, and a save-card
# generator can be certified green while emitting cards ngspice rejects. That is
# exactly how three attempts shipped: 85 checks, then 96, then a 241-check suite
# that cannot see this at all.
#
# The loop here is the whole feature, end to end and in one direction:
#   op_annot::save_cards  ->  a deck  ->  ngspice  ->  a raw  ->  op_annot::text
#
# ============================================================================
# ⚠ THE DETECTOR IS `dims=0`, NOT STDERR. MEASURED ON /usr/local/bin/ngspice 46+
# ============================================================================
# The step brief says to capture ngspice's stderr and assert the values are not
# all zero. Re-measured on this section's own deck, under the `.control … write
# … .endc` idiom every shipped PDK bench uses:
#
#   good cards + ONE bogus card  -> rc 0, RAW WRITTEN, a column under exactly the
#                                   requested name marked `dims=0`, stderr EMPTY
#   EVERY device card bogus      -> rc 0, NO RAW AT ALL, and then it warns
#                                   (`checkvalid` + `no writable vector found`)
#
# So a stderr-only detector is blind in precisely the realistic case, and a
# raw-header NAME diff cannot see it either — the name is there, holding zeros.
# `dims=0` is present on every bogus vector and absent on every genuine one, and
# it also catches a right-device/wrong-PARAM card (a level-1 MOS has no `vth`).
# Row XR3 carries its own control, so the detector cannot pass by never firing.
#
# ============================================================================
# THE FIXTURE, AND WHY ITS DEVICES ARE SUBCKT-WRAPPED
# ============================================================================
# ngspice names a device inside a subcircuit `@m.<instance-path>.<device>` and a
# TOP-LEVEL one just `@<name>` — measured: every `@m.mx0[…]` card on a bare
# top-level MOS is rejected. Every PDK device is subckt-wrapped, which is why the
# shipped descriptors all read `@m.…`, and the fixture matches that shape: a
# `nmod` wrapper subckt holding the real level-1 MOS `m1`.
#
# The preamble (globals, sources, wrapper, model) is carried by a `code_shown`
# instance, the way a bench carries it — so the deck this section simulates is
# the netlister's own output plus the generated block plus `.control`, and
# nothing else. ⚠ THE BLOCK IS AT DECK LEVEL: inside `.control` the dot form is
# not a command (`save: no such command available`) at rc 0, and the deck then
# silently behaves as if it had no save card at all.

set X_NG {}
foreach c {/usr/local/bin/ngspice /usr/bin/ngspice} {
  if {[file executable $c]} { set X_NG $c ; break }
}
if {$X_NG eq {}} { set X_NG [lindex [auto_execok ngspice] 0] }

set X_LIB [file join $scratch xlib]
set X_NL  [file join $scratch xnl]
file mkdir $X_LIB $X_NL

proc opa_x_fixture {lib} {
  set f [open [file join $lib x_prim.sym] w]
  puts $f {v {xschem version=3.4.4 file_version=1.2}
G {type=x_nmos
format="@spiceprefix@name vdd gbias 0 0 @model"
template="name=M1 model=nmod spiceprefix=X"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=D dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}
  close $f
  foreach s {x_sub x_deep} {
    set f [open [file join $lib $s.sym] w]
    puts $f {v {xschem version=3.4.4 file_version=1.2}
G {type=subcircuit
format="@name @symname"
template="name=x1"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}
    close $f
  }
  ## ⚠ NO BRACES ANYWHERE IN THIS TEXT. A `{`…`}` inside an instance property
  ## breaks the .sch reader's record scan (measured: the value silently reverts
  ## to the template default and the deck loses its model), so the wrapper takes
  ## no parameters.
  set code "value=\".global vdd gbias
Vdd vdd 0 1.8
Vg gbias 0 0.9
.subckt nmod d g s b
M1 d g s b nlevel1 W=2u L=0.15u
.ends
.model nlevel1 nmos level=1 vto=0.5 kp=100u lambda=0.05\""
  set f [open [file join $lib x_top.sch] w]
  puts $f "v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {code_shown.sym} 0 -200 0 0 {name=s1 only_toplevel=true $code}
C {x_prim.sym} 0 0 0 0 {name=MX0}
C {x_prim.sym} 100 0 0 0 {name=MXIGN spice_ignore=true}
C {x_sub.sym} 200 0 0 0 {name=x1}"
  close $f
  set f [open [file join $lib x_sub.sch] w]
  puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {x_prim.sym} 0 0 0 0 {name=MX1}
C {x_deep.sym} 100 0 0 0 {name=x2}}
  close $f
  set f [open [file join $lib x_deep.sch] w]
  puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {x_prim.sym} 0 0 0 0 {name=MX2}}
  close $f
}
## The raw's variable NAMES, exactly as the header spells them, plus the ones
## carrying `dims=0` — a marker ngspice writes for a vector it could not build.
proc opa_x_rawvars {path} {
  if {![file isfile $path]} { return {} }
  set fh [open $path r] ; set t [read $fh] ; close $fh
  set names {} ; set zero {} ; set in 0
  foreach l [split $t "\n"] {
    if {[string match {Variables:*} $l]} { set in 1 ; continue }
    if {[string match {Values:*} $l] || [string match {Binary:*} $l]} { break }
    if {!$in} continue
    set f {}
    foreach p [split $l "\t"] { if {$p ne {}} { lappend f $p } }
    if {[llength $f] < 2} continue
    set nm [lindex $f 1]
    lappend names $nm
    if {[string match {*dims=0*} $l]} { lappend zero $nm }
  }
  return [list $names $zero]
}
## Assemble a runnable deck: the netlister's output with its `.end` removed, the
## generated block AT DECK LEVEL, then `.control`.
proc opa_x_deck {deck block rawpath out {extra {}}} {
  set body {}
  foreach l [split $deck "\n"] {
    if {[string trim $l] eq {.end}} continue
    append body $l "\n"
  }
  set fh [open $out w]
  puts $fh "* op_annot section X"
  puts -nonewline $fh $body
  puts -nonewline $fh $block
  if {$extra ne {}} { puts $fh $extra }
  puts $fh ".control"
  puts $fh "op"
  puts $fh "set filetype=ascii"
  puts $fh "write $rawpath"
  puts $fh ".endc"
  puts $fh ".end"
  close $fh
  return $out
}
proc opa_x_run {ng deck errfile} {
  catch {exec $ng -b $deck 2>$errfile} out
  set e {}
  if {[file isfile $errfile]} { set fh [open $errfile r] ; set e [read $fh] ; close $fh }
  return $e
}
## Every params vector of one instance, THROUGH op_annot::vector — the read shape
## the display uses, so X2 closes I1 against a raw the save cards caused to exist.
proc opa_x_vecs {inst type} {
  set d [op_annot::descriptor $type]
  set out {}
  foreach row [dict get $d params] {
    if {[catch {op_annot::vector $inst [lindex $row 1]} v]} { lappend out RAISED } \
    else { lappend out $v }
  }
  return $out
}

if {[catch {

if {$X_NG eq {}} {
  opa_w_skiprow {XR1 the generated block simulates and a raw is written} {no ngspice on PATH}
  opa_w_skiprow {XR2 every card appears in the raw under op_annot::vector's name} {no ngspice on PATH}
  opa_w_skiprow {XR3 no vector in the raw carries dims=0} {no ngspice on PATH}
  opa_w_skiprow {XR4 the deepest FET renders real numbers through op_annot::text} {no ngspice on PATH}
} else {

set X_LIBS ":$X_LIB:[file join $repo xschem_library devices]"
set XSCHEM_LIBRARY_PATH $X_LIBS
opa_x_fixture $X_LIB
op_annot::register x_nmos [list devpath {\@m.@path@spiceprefix@name\.m1} \
  params {{id id 0} {gm gm 1} {gds gds 1} {vdsat vdsat 2}} \
  derived {{gm/id {$gm/$id}}}]
set X_CONF_SAVE $::USER_CONF_DIR
set ::USER_CONF_DIR $W_CONF
set netlist_dir $X_NL

catch {xschem raw clear}
foreach f [glob -nocomplain [file join $X_LIB *~.sch]] { catch {file delete -force $f} }
xschem load [file join $X_LIB x_top.sch]
foreach f [glob -nocomplain [file join $X_LIB *~.sch]] { catch {file delete -force $f} }
## ⚠ A RAISE MUST NOT REACH THE DECK. Pasting an error string into a .spice file
## makes ngspice die on a syntax error, and every row below would then be red for
## the wrong reason. An absent block is the honest input: the deck still runs,
## and the rows red on what is MISSING from the raw.
set x_sc [rcall {op_annot::save_cards}]
set X_BLOCK {}
if {[lindex $x_sc 0] == 0} { set X_BLOCK [lindex $x_sc 1] }
set X_DECKTXT [opa_w_netlist x_top.sch]
set X_RAW  [file join $X_NL x.raw]
catch {file delete -force $X_RAW}
opa_x_deck $X_DECKTXT $X_BLOCK $X_RAW [file join $X_NL x_run.spice]
set X_ERR [opa_x_run $X_NG [file join $X_NL x_run.spice] [file join $X_NL x_ng.err]]
set X_VARS [opa_x_rawvars $X_RAW]

# ===========================================================================
# X1 — THE GENERATED BLOCK SIMULATES
# ===========================================================================
# 12 cards (3 netlisted devices x 4 params) plus `.save all`. If ANY of them
# named a device the deck does not contain, this row is where the whole raw
# disappears — which is the harm the generator exists not to cause.
check {XR1 the generated block + the netlister's own deck run under ngspice and a raw IS written} \
  [list [llength [opa_w_lines $X_BLOCK]] [file exists $X_RAW] \
        [string match {*no writable vector*} $X_ERR]] \
  [list 13 1 0]

# ===========================================================================
# X2 — INVARIANT I1, CLOSED AGAINST A REAL RAW FOR THE FIRST TIME
# ===========================================================================
# The SAVE shape is bare `[devpath][param]`; the READ shape is
# `op_annot::vector`, i.e. the same devpath under the descriptor's kind wrapper.
# Nothing in this tree has ever checked that the two agree against a raw the
# cards themselves produced: section S reads a raw it wrote by hand, so a drift
# in either shape would leave it green. Here the names are collected by
# descending to each device and asking op_annot::vector, and every one must be a
# vector the simulator actually wrote.
xschem load [file join $X_LIB x_top.sch]
set x2_ann [rcall {xschem annotate_op $X_RAW 0}]
set x2_want [opa_x_vecs MX0 x_nmos]
xschem unselect_all ; xschem select instance 3 fast nodraw ; xschem descend 1 2
foreach v [opa_x_vecs MX1 x_nmos] { lappend x2_want $v }
xschem unselect_all ; xschem select instance 1 fast nodraw ; xschem descend 1 2
set x2_deep [opa_x_vecs MX2 x_nmos]
foreach v $x2_deep { lappend x2_want $v }
set x2_missing {}
foreach v $x2_want { if {[lsearch -exact [lindex $X_VARS 0] $v] < 0} { lappend x2_missing $v } }
check {XR2 I1 every card's READ name (op_annot::vector) is a vector ngspice really wrote} \
  [list [lindex $x2_ann 0] [llength $x2_want] $x2_missing] \
  [list 0 12 {}]

# ===========================================================================
# X3 — THE DETECTOR THAT WORKS, WITH ITS OWN NON-VACUITY CONTROL
# ===========================================================================
# A card for a device that is not in the deck writes a full column under exactly
# the requested name, marked `dims=0`, at rc 0 and in silence. So the second leg
# is not decoration: it adds ONE bogus card to the SAME deck and asserts the
# detector fires. Without it "no dims=0" would be satisfied by a parser that
# never finds anything.
set X_RAW2 [file join $X_NL x_bogus.raw]
catch {file delete -force $X_RAW2}
opa_x_deck $X_DECKTXT "$X_BLOCK.save @m.xnope.m1\[gm\]\n" $X_RAW2 \
           [file join $X_NL x_bogus.spice]
set X_ERR2 [opa_x_run $X_NG [file join $X_NL x_bogus.spice] [file join $X_NL x_ng2.err]]
set X_VARS2 [opa_x_rawvars $X_RAW2]
## ⚠ THE FIRST LEG IS THIS ROW'S OWN NON-VACUITY. "No dims=0 anywhere" is
## trivially true of a deck with no device cards at all, so the card count comes
## first: without it the row is GREEN against an absent save_cards.
check {XR3 no vector in the raw carries dims=0 — and the SAME deck with one bogus card does, at rc 0 and in silence} \
  [list [llength [opa_w_devs $X_BLOCK]] [lindex $X_VARS 1] [string trim $X_ERR] \
        [lindex $X_VARS2 1] [string trim $X_ERR2]] \
  [list 12 {} {} [list {@m.xnope.m1[gm]}] {}]

# ===========================================================================
# X4 — WHAT THE USER SEES: NUMBERS, ON THE DEEPEST DEVICE
# ===========================================================================
# ⚠ A FULL COLUMN OF 0.0 IS A FAIL, NOT A PASS (spec landmine 9). And the node
# voltages must STILL be there: rule R2 says an explicit save cancels the
# implicit save-everything, so a block that forgot `.save all` would not merely
# fail to add the `params` rows — it would DELETE the two `pinexpr` rows that are
# the only ones working today.
set x4_text [rcall {op_annot::text MX2}]
set x4_vals {}
foreach v $x2_deep { lappend x4_vals [rcall {op_annot::raw_or_blank $v}] }
set x4_nodes {}
foreach n {v(vdd) v(gbias) i(vdd) i(vg)} {
  lappend x4_nodes [expr {[lsearch -exact [lindex $X_VARS 0] $n] >= 0}]
}
while {[xschem get currsch] > 0} { catch {xschem go_back 2} }
check {XR4 the deepest FET renders five real rows, the node voltages and source currents survived, and the spice_ignore'd FET got no card} \
  [list $x4_text \
        [expr {[lindex [lindex $x4_vals 0] 1] != 0}] \
        [expr {[lindex [lindex $x4_vals 1] 1] != 0}] \
        $x4_nodes \
        [expr {[string first {mxign} $X_BLOCK] >= 0}]] \
  [list [list 0 "id    = 116.3u\ngm    = 581.3u\ngds   = 5.333u\nvdsat = 0.4\ngm/id = 5\n"] \
        1 1 {1 1 1 1} 0]

# ===========================================================================
# XR5 — ISSUE 0499(b): THE BASIS, CLOSED END TO END INSTEAD OF AGAINST A STRING
# ===========================================================================
# ⚠ WHY XR1-XR4 CANNOT SEE A BASIS DEFECT AT ALL, AND 0499(b) SAYS SO: they clear
# the raw, load the top cell and call save_cards at currsch 0, where the `read`
# and `deck` bases both produce an EMPTY prefix. The two predicted-red variants
# `basis_ignored` and `devproc_gets_read_path` reddened NOTHING in section X, so
# the exact defect that killed attempt 1 — raw-relative names where deck-absolute
# were required — was covered only by the string goldens W5-W8.
#
# The fix 0499(b) prescribes: with the raw the feature's own cards produced still
# LOADED, descend one level and re-run save_cards. Ruling D2 makes that block
# entry-relative, so the claim is not "same as the top-level block" — it is that
# the raw's presence changes NOTHING. The control leg is the non-vacuity: at that
# moment `sim_sch_path` is non-empty while the deck root is not, so the two bases
# genuinely disagree and a `_pathfor` that answers `_simpath` for every basis
# emits `@m.x1.…` where `@m.…` is required.
xschem load [file join $X_LIB x_top.sch]
set x5_ann [rcall {xschem annotate_op $X_RAW 0}]
xschem unselect_all ; xschem select instance 3 fast nodraw ; xschem descend 1 2
set x5_sim [xschem get sim_sch_path]
set x5_with [rcall {op_annot::save_cards}]
catch {xschem raw clear}
set x5_loaded [xschem raw loaded]
set x5_without [rcall {op_annot::save_cards}]
while {[xschem get currsch] > 0} { catch {xschem go_back 2} }
check {XR5 0499b a raw loaded at level 0 changes NOTHING about a walk entered at level 1} \
  [list [lindex $x5_ann 0] $x5_sim $x5_loaded \
        [lindex $x5_with 0] [lindex $x5_without 0] \
        [expr {[lindex $x5_with 1] eq [lindex $x5_without 1]}] \
        [expr {[string first {@m.x1.} [lindex $x5_with 1]] < 0}] \
        [expr {[llength [opa_w_devs [lindex $x5_with 1]]] > 0}]] \
  [list 0 {x1.} -1 0 0 1 1 1]

catch {xschem raw clear}
set ::USER_CONF_DIR $X_CONF_SAVE
set XSCHEM_LIBRARY_PATH $W_LIBS
}

} xerr]} {
  puts "UNEXPECTED ERROR (section X): $xerr"
  incr fail
}

# =============================================================================
# SECTION Y — ISSUE 0688: THE MASK BELONGS TO THE LOADED ROOT SHEET, NOT TO THE
#             WINDOW. THE LIFETIME HALF OF THE 0683 RULING.
# =============================================================================
# ⚠ WHY THIS SECTION EXISTS, AND WHY IT COMES BEFORE THE REFUSAL ROWS IN
# tests/headless/test_annot_show_menu.tcl. The user's 2026-08-25 ruling on 0683
# ("both stock items refuse without a bound session") was ATTEMPTED ONCE AND
# REVERTED, because 0683 is not an ENTRY problem: `annot_show` is per-WINDOW
# (`tctx::global_list`, src/xschem.tcl:14009) while an ASE-L session's only
# handle on its design is a CELLVIEW PATH, so an ordinary `File > Open` in the
# design window leaves the mask at 3 while every session-side reader answers 0.
# Measured on this tree, sanctioned doors only (issue 0688 §2): annotate from
# ASE-L, open another cell, close the session, reopen the first cell -> mask 3,
# real numbers on the sheet, 0 sessions, and 0 of 6 menubar entries able to
# clear it. A producer-side guard does nothing about a mask that is ALREADY on.
#
# The fix under test keys the mask on the window's ROOT sheet (`xctx->sch[0]`):
# one stamp written by the ONE C setter, one checker that clears the mask when
# the root moves. So this section's rows split into two halves that must be read
# together:
#
#   THE KEEP (Y1 Y2 Y3 Y4 Y9) — GREEN BEFORE THE CHANGE, ON PURPOSE. They are
#   the counterweight the 0682 crew's anti-hollow rule demands: a negative claim
#   ("the orphan is unreachable") needs a positive twin, or "cleared the mask on
#   every load and called it fixed" passes the whole section. Y4 in particular is
#   what forbids keying on `sch[currsch]` — 0688 §1 records descend+go_back
#   KEEPING the mask as deliberate, and re-measured here it does.
#
#   THE CLEAR (Y5 Y6 Y7 Y7b Y8 Y10 Y11 Y12) — RED BEFORE THE CHANGE.
#
# ⚠ THE DATA-LOSS FENCE, AND IT IS NOT THEORETICAL. The reverted attempt's
# `annot_drop_stale` cleared op/dc/tran at the session path and RE-READ; when the
# re-read hit a raw ngspice was mid-rewrite (readable but truncated) the user's
# loaded database was destroyed and nothing replaced it. Y7 and Y7b are that
# scenario: the clear must write one int, one Tcl var and one path stamp, and
# must not so much as look at the raw. MEASURED HERE FIRST, so the goldens are
# facts and not hopes: a different-file `xschem load` already de-associates the
# raw from the new sheet (`xschem raw loaded` -> -1) while KEEPING the registry
# entry — `xschem raw rawfile` still names the file and loading the first sheet
# again answers 3.14 from memory. That survival is the thing the attempt broke,
# so Y7/Y7b assert it directly rather than asserting "loaded is unchanged",
# which no implementation could satisfy.
# =============================================================================

if {[catch {

set Y_LIB [file join $scratch ylib]
file delete -force $Y_LIB
file mkdir $Y_LIB

## The annotator under test is a `hide=op` text — the same probe shape section L
## uses (opa_l_mkprobe), rebuilt here so section Y cannot silently depend on
## section L's fixture ordering. Its instance bbox is 0 wide when bit0 is clear
## and ~57 wide when it is set; NO row hardcodes the width (it is a font metric
## and moves between --nogui and a display -- section L measured the identical
## symbol at 63 headless and 64 on :99, because text_bbox goes through cairo's
## font metrics when a display exists).
proc opa_y_mkprobe {dir name} {
  set f [open [file join $dir $name] w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "K \{type=zzs7probe\ntemplate=\"name=zp1\"\}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  puts $f "L 4 0 0 0 10 {}"
  puts $f "T \{ZZY0688TEXT\} 5 5 0 0 0.2 0.2 \{layer=15\nhide=op\}"
  close $f
}
opa_y_mkprobe $Y_LIB y_hid_op.sym
set f [open [file join $Y_LIB y_leaf.sym] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}
close $f
foreach {fn body} [list \
    y_a.sch    "C \{y_hid_op.sym\} 0 0 0 0 \{name=YA1\}" \
    y_b.sch    "C \{y_hid_op.sym\} 0 0 0 0 \{name=YB1\}" \
    y_leaf.sch "C \{y_hid_op.sym\} 0 0 0 0 \{name=YL1\}" \
    y_top.sch  "C \{y_leaf.sym\} 120 0 0 0 \{name=x1\}"] {
  set f [open [file join $Y_LIB $fn] w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  puts $f $body
  close $f
}
## One Operating Point point carrying v(a) = 3.14 — the value issue 0688 §2's
## transcript names, so a reader can line the two up.
set Y_GOLD [file join $scratch y_op_gold.raw]
set f [open $Y_GOLD w]
puts -nonewline $f "Title: Y 0688 fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\tv(a)\tvoltage
\t1\tv(gnd)\tvoltage
Values:
0\t3.14
\t0.0
"
close $f
set Y_RAW [file join $scratch y_op_live.raw]
file copy -force $Y_GOLD $Y_RAW

set Y_A   [file normalize [file join $Y_LIB y_a.sch]]
set Y_B   [file normalize [file join $Y_LIB y_b.sch]]
set Y_TOP [file normalize [file join $Y_LIB y_top.sch]]

# ⚠ UNQUALIFIED, per this file's header note: a `set ::XSCHEM_LIBRARY_PATH` is
# INERT (the write trace at src/xschem.tcl:16527 compares the unqualified name).
set XSCHEM_LIBRARY_PATH $Y_LIB

set Y_TCL [file join $repo src xschem.tcl]

# ---------------------------------------------------------------------------
# Y0 — FIXTURE, asserted and not assumed. Without it every "the mask is off"
# row below would be satisfied by a sheet whose text never rendered at all.
# ---------------------------------------------------------------------------
xschem load $Y_A
opa_l_annot 0 ; set y_w0 [opa_l_w YA1]
opa_l_annot 3 ; set Y_W  [opa_l_w YA1]
opa_l_annot 0
check {Y0 FIXTURE y_a.sch: one hide=op probe, invisible at mask 0 and wide at mask 3} \
  [list [xschem get instances] $y_w0 [expr {$Y_W > 40 ? 1 : 0}] \
        [expr {[string match {*y_a.sch} [xschem get schname 0]] ? 1 : 0}]] \
  {1 0 1 1}

# ===========================================================================
# THE KEEP — GREEN BEFORE THE CHANGE. Read this block as the answer to
# "did you just clear the mask on every load and call it a fix?"
# ===========================================================================

# ⚠ CONTROL. `Session > Design Window` re-loads the SAME cellview through the
# same `xschem load` (src/ase_window.tcl:4366), and rows O22/O23 above depend on
# a same-path reload not disturbing anything. A discriminator that compared
# anything other than the path would red here.
xschem load $Y_A
catch {xschem set annot_show 1}
xschem load $Y_A
check {Y1 KEEP a same-path `xschem load` leaves the mask alone} \
  [rcall {xschem get annot_show}] {0 1}

# The O22 isolator's precondition, promoted from silent to asserted: with
# remove_symbols() out of the picture the mask must still survive.
xschem load -keep_symbols $Y_A
check {Y2 KEEP `xschem load -keep_symbols` on the same path leaves the mask alone} \
  [rcall {xschem get annot_show}] {0 1}

# O20/O21's path.
set y3rc [catch {xschem reload}]
check {Y3 KEEP `xschem reload` leaves the mask alone} \
  [list $y3rc [rcall {xschem get annot_show}]] {0 {0 1}}

# ⚠ THE ROW THAT FORBIDS `sch[currsch]`. 0688 §1 records descend+go_back KEEPING
# the mask as deliberate ("this window is in annotate mode"), and re-measured on
# this tree it does. currsch is folded in so a descend that never happened
# cannot satisfy the row by leaving the mask where it was.
xschem load $Y_TOP
catch {xschem set annot_show 3}
xschem unselect_all
set y4sel [catch {xschem select instance 0 fast nodraw}]
set y4dsc [catch {xschem descend 1 2}]
set y4in  [list [xschem get currsch] [xschem get annot_show]]
catch {xschem go_back 2}
set y4out [list [xschem get currsch] [xschem get annot_show]]
check {Y4 KEEP descend and go_back both keep the mask — the root sheet never moved} \
  [list $y4sel $y4dsc $y4in $y4out] {0 0 {1 3} {0 3}}

# ===========================================================================
# THE CLEAR — RED BEFORE THE CHANGE
# ===========================================================================

# ⚠ THE 0688 DEFECT ITSELF, AND THE SEAM IT PINS. Read with NO bulk eval in
# between: `xschem get annot_show` must already answer 0 the instant the load
# returns. A fix that only rode `annot_show_sync_cache()` would leave the mask
# at 3 for every reader until the next `update_all_sym_bboxes`, and the ASE-L
# menu PULL half (N22c) reads it exactly that way.
xschem load $Y_A
catch {xschem set annot_show 3}
set y5pre [xschem get annot_show]
xschem load $Y_B
check {Y5 0688 `File > Open` of a DIFFERENT cell drops the mask, immediately} \
  [list $y5pre [xschem get annot_show] [file tail [xschem get schname]]] \
  {3 0 y_b.sch}

# ⚠ THE DISCRIMINATOR IS THE ROOT, NOT THE CURRENT SHEET. Both elements are
# needed: the first alone is satisfied by a stamp that merely equals whatever is
# loaded now, and the second alone is satisfied by a stamp that is always empty.
xschem load $Y_TOP
catch {xschem set annot_show 3}
set y6root [rcall {xschem get annot_root}]
set y6a [expr {[lindex $y6root 0] == 0 && [lindex $y6root 1] ne {} \
               && [lindex $y6root 1] eq [xschem get schname 0]}]
xschem unselect_all
catch {xschem select instance 0 fast nodraw}
catch {xschem descend 1 2}
set y6b [expr {[xschem get currsch] == 1 \
               && [rcall {xschem get annot_root}] eq $y6root}]
catch {xschem go_back 2}
check {Y6 the stamp is the ROOT sheet and does not move while descended} \
  [list [expr {$y6a ? 1 : 0}] [expr {$y6b ? 1 : 0}]] {1 1}

# ⚠ THE DATA-LOSS FENCE. The clear touches ONE int, ONE Tcl var and ONE path
# stamp. It must not clear, re-read or re-attach any raw — that is the reverted
# attempt's regression (0683 §7 refutation 3). MEASURED at HEAD and the goldens
# encode the measurement: a different-file load de-associates the raw from the
# NEW sheet (`raw loaded` -> -1) but KEEPS the registry entry, so `raw rawfile`
# is unchanged and loading the first sheet again answers 3.14 out of memory.
file copy -force $Y_GOLD $Y_RAW
xschem load $Y_A
catch {xschem annotate_op $Y_RAW}
set y7l0 [rcall {xschem raw loaded}]
set y7v0 [rcall {xschem raw value v(a) -1}]
set y7f0 [rcall {xschem raw rawfile}]
catch {xschem set annot_show 3}
xschem load $Y_B
set y7mask [xschem get annot_show]
set y7f1 [rcall {xschem raw rawfile}]
xschem load $Y_A
check {Y7 the clear destroys no waveform database: the registry entry and the value survive} \
  [list $y7mask [expr {$y7f0 eq $y7f1 ? 1 : 0}] \
        $y7l0 $y7v0 [rcall {xschem raw loaded}] [rcall {xschem raw value v(a) -1}]] \
  [list 0 1 {0 0} {0 3.14} {0 0} {0 3.14}]

# ⚠ THE TRUNCATED-RAW CASE THE BRIEF DEMANDS BE PROVED, NOT ARGUED. ngspice
# mid-rewrite leaves a file that is readable and short; the reverted attempt
# re-read it, got nothing, and had already thrown the good database away. Here
# the file on disk is mutilated WHILE the database is attached, and the clear
# then runs. Nothing may re-read the file, so the in-memory value must still be
# 3.14 when the first sheet comes back.
file copy -force $Y_GOLD $Y_RAW
xschem load $Y_A
catch {xschem annotate_op $Y_RAW}
catch {xschem set annot_show 3}
set _yfh [open $Y_RAW r] ; set _yd [read $_yfh] ; close $_yfh
set _yfh [open $Y_RAW w] ; puts -nonewline $_yfh [string range $_yd 0 60] ; close $_yfh
xschem load $Y_B
set y7bmask [xschem get annot_show]
xschem load $Y_A
check {Y7b a raw TRUNCATED on disk mid-flight is never re-read by the clear} \
  [list $y7bmask [expr {[file size $Y_RAW] < 120 ? 1 : 0}] \
        [rcall {xschem raw loaded}] [rcall {xschem raw value v(a) -1}]] \
  [list 0 1 {0 0} {0 3.14}]
file copy -force $Y_GOLD $Y_RAW

# ⚠ ANTI-HOLLOW. A checker wedged at 0 — or a setter that stopped writing the C
# field — satisfies Y5 perfectly and breaks the feature. This row re-arms the
# mask on the NEW sheet and reads the annotator's own bbox back.
xschem load $Y_A
catch {xschem set annot_show 3}
xschem load $Y_B
set y8a [xschem get annot_show]
opa_l_annot 3
set y8w [opa_l_w YB1]
check {Y8 ANTI-HOLLOW the mask still ARMS on the new sheet and the annotator paints} \
  [list $y8a [xschem get annot_show] [expr {$y8w > 40 ? 1 : 0}]] {0 3 1}
opa_l_annot 0

# ⚠ PRODUCER (c) IS OUTSIDE THE RULING AND MUST STAY WORKING (decision D2). A
# `set annot_show 1` in the user's xschemrc is honoured at src/xinit.c:3839 and
# never passes through the C setter, so it is never stamped and must never be
# cleared. This row is also the whole argument against an "adopt the current
# root on first sight" sync: at startup `xschem get schname 0` is
# <launchdir>/untitled.sch and the rc sync runs BEFORE the CLI file is loaded, so
# an adopting sync would stamp untitled.sch and silently kill producer (c) at the
# first real load.
catch {xschem set annot_show 0}
xschem load $Y_A
set ::annot_show 1
xschem update_all_sym_bboxes
set y9a [xschem get annot_show]
xschem load $Y_B
check {Y9 KEEP an rc-set mask that never went through the setter is never stamped, so never cleared} \
  [list $y9a [xschem get annot_show]] {1 1}
catch {xschem set annot_show 0} ; set ::annot_show 0

# ---------------------------------------------------------------------------
# SOURCE CONTRACTS — what no runtime row in a --nogui process can see
# ---------------------------------------------------------------------------

# ⚠ THE 0683 HALF, ASSERTED FROM HERE BECAUSE THE MENU ROWS NEED A DISPLAY.
# tests/headless/test_annot_show_menu.tcl owns the behaviour (rows C0-C9); this
# row only pins that BOTH stock producers are guarded and neither was forgotten,
# and that the guard was added by WRAPPING the two existing bodies rather than by
# adding a third writer — N22/N22b and test_annot_show_menu B6/B10 pin the
# writer counts at {2 in xschem.tcl, 1 in ase_window.tcl}.
check {Y10 both stock producers carry the binding guard, and no third mask writer appeared} \
  [list [opa_n_grep $Y_TCL {xschem set annot_show}] \
        [opa_n_grep $Y_TCL {ase::annot_binding_ok}]] \
  {2 2}

# ⚠ INVARIANT I1, IN C. One builder of "the mask and its stamp"
# (annot_show_set), one checker (annot_show_check_root) reached from exactly two
# call sites: the deterministic load seam in save.c and the sync-cache backstop
# in actions.c. Three occurrences = definition + those two calls. A second writer
# of the Tcl mirror, or a third clear site, reds here — which is the drift I1
# exists to forbid and which no behavioural row can see.
set Y_CSRC [lsort [glob -nocomplain [file join $repo src *.c]]]
set y11w 0 ; set y11c 0
foreach _yf $Y_CSRC {
  incr y11w [opa_n_grep $_yf {tclsetintvar\("annot_show"}]
  incr y11c [opa_n_grep $_yf {annot_show_check_root\(}]
}
check {Y11 I1 exactly one C writer of the Tcl mirror, and the root checker has exactly two call sites} \
  [list $y11w $y11c] {1 3}

# ⚠ THE BACKSTOP, ON A ROOT CHANGE THAT NEVER RUNS load_schematic().
# `clear_schematic()` (src/actions.c:4850) frees xctx->sch[currsch] and composes
# a fresh untitled name IN PLACE — measured, it never calls load_schematic, so
# the save.c seam cannot see it and only the pull in annot_show_sync_cache() can.
# `autosave_backup` is parked for the duration (issue 0601): the cleared buffer
# is named <launchdir>/untitled.sch and a set_modify(1) on it would drop a `~`
# file in the repo ROOT, which is what tests/headless/test_no_untitled_litter.tcl
# reds on.
set y12save $::autosave_backup
set ::autosave_backup 0
xschem load $Y_A
catch {xschem set annot_show 3}
set y12pre [xschem get schname 0]
catch {xschem clear force}
set y12moved [expr {[xschem get schname 0] ne $y12pre ? 1 : 0}]
set y12imm [xschem get annot_show]
xschem update_all_sym_bboxes
set y12aft [xschem get annot_show]
xschem load $Y_A
set ::autosave_backup $y12save
check {Y12 a root change that never runs load_schematic is caught by the sync-cache backstop} \
  [list $y12moved $y12aft] {1 0}

# ------------------------------------------------------------------ cleanup --
catch {xschem raw clear}
catch {xschem set annot_show 0}
set ::annot_show 0
set XSCHEM_LIBRARY_PATH $W_LIBS

} yerr]} {
  puts "UNEXPECTED ERROR (section Y): $yerr"
  incr fail
}

# =============================================================================
# SECTION Z — ISSUE 0812: A RAW FILENAME IS DATA, NOT SCRIPT.
# =============================================================================
# `xschem annotate_op` resolves a leading `~/` IN C (scheduler.c, two
# my_snprintf branches) and its comment block says the splice hazard is closed.
# That is true of its own line and FALSE of the path: the `f` those branches
# produce is handed straight to extra_rawfile() (save.c), which resolves it by
# BUILDING THE TCL SCRIPT `subst { <f> }` and evaluating it. Closed one frame
# up, open one frame down.
#   doc/claude/issues/0812-extra-rawfile-substs-the-raw-path-so-a-crafted-filename-executes-tcl.md
#
# ⚠ AINJ2 IS THE ROW THAT KILLS THE "THE USER TYPED THE PATH" DEFENCE. It passes
# NO FILENAME AT ALL -- the shipped menu entry (src/xschem.tcl `Op Annotate`) --
# and the payload lives in the SIMULATION DIRECTORY name, which scheduler.c
# joins with the cell name to build `<netlist_dir>/<cell>.raw`. Nobody typed
# anything; a project checked out with a sim dir named
# `q}; set ::SC_PWNED 1; list {a` is enough.
#
# ⚠ AINJ3/AINJ4 ARE THE ROWS THE FIRST ATTEMPT DID NOT HAVE, AND ARE WHY IT WAS
# REVERTED (0812 §1/§3). It sanitized with `subst -nobackslashes -nocommands`.
# `-nocommands` suppresses only TOP-LEVEL command substitution: a command
# substitution inside a VARIABLE ARRAY INDEX still runs, before the array lookup
# fails, so the array need not exist. AINJ4 asserts the sharpest form of it --
# `[exec touch ...]` inside the index of a path that DOES NOT EXIST ON DISK
# created a host file, because the resolver runs before any stat().
#
# ⚠ THE ASSERTION IS A SIDE EFFECT -- the sentinel ::SC_PWNED or a FILE CREATED
# ON DISK -- NEVER A RETURN CODE. The payload runs BEFORE the read fails, so a
# row that only checks for an error passes over a live arbitrary-code-execution
# defect.
#
# AORD1/AORD2/AORD3 ARE THE COUNTERWEIGHT: the easy wrong fix is to refuse
# anything unusual. `~/` works here TODAY (and only here -- through `xschem raw
# read` it returns 0, which tests/headless/test_raw_read_dispatch.tcl ORD7 pins
# as a fix to deliver); a path with SPACES and a `$netlist_dir/...` spelling work
# here today. All three must still work after. AKEY1 pins the idempotence
# annotate_op needs by construction: it feeds the ALREADY-RESOLVED
# xctx->raw->rawfile back through extra_rawfile()'s clear arm, so resolving
# twice must equal resolving once.
# =============================================================================

if {[catch {

set XSCHEM_LIBRARY_PATH $Y_LIB

set Z_INJ [file join $scratch "q\}; set ::SC_PWNED 1; list \{a.raw"]
file copy -force $Y_GOLD $Z_INJ
set Z_SPACE [file join $scratch "z op with space.raw"]
file copy -force $Y_GOLD $Z_SPACE
# the payload as a SIMULATION DIRECTORY, holding the raw the no-argument form
# will name by itself: <netlist_dir>/<cell>.raw, cell = y_a
set Z_SIMDIR [file join $scratch "q\}; set ::SC_PWNED 1; list \{a"]
file mkdir $Z_SIMDIR
file copy -force $Y_GOLD [file join $Z_SIMDIR y_a.raw]

# The `~/` probe can only live directly under $HOME. Same 0148-class discipline
# as tests/headless/test_perform_action_embed_rawfile.tcl check (d): removed on
# every exit path, and dead-pid corpses of earlier runs swept on the way in,
# because nothing else sweeps $HOME.
set Z_HNAME opannot0812probe_[pid].raw
set Z_HRAW  [file join $::env(HOME) $Z_HNAME]
foreach _zf [glob -nocomplain -directory $::env(HOME) opannot0812probe_*.raw] {
  if {![regexp {^opannot0812probe_([0-9]+)\.raw$} [file tail $_zf] -> _zp]} continue
  if {$_zp eq [pid] || [__scratch_pid_alive $_zp]} continue
  catch {file delete -force $_zf}
}
if {[info commands ::__opa_z_real_exit] eq {}} {
  rename ::exit ::__opa_z_real_exit
  proc ::exit {{code 0}} { catch {file delete -force $::Z_HRAW}; ::__opa_z_real_exit $code }
}
file copy -force $Y_GOLD $Z_HRAW

set Z_NDIR [expr {[info exists ::netlist_dir] ? $::netlist_dir : {}}]

## Drive one annotate_op with the sentinel armed immediately before the call, so
## a 1 can only have been written by the filename.
proc opa_z_probe {script} {
  set ::SC_PWNED 0
  catch {uplevel #0 $script}
  return $::SC_PWNED
}
## ...and one that asserts a HOST FILE, which is the form a reader cannot argue
## with: the process reached out and touched the filesystem.
proc opa_z_owned {path script} {
  catch {file delete -force $path}
  catch {uplevel #0 $script}
  set e [file exists $path]
  catch {file delete -force $path}
  return $e
}

xschem load $Y_A
catch {xschem raw clear}
check {Z0 FIXTURE the payload-named raw, the spaced raw, the ~/ probe and the payload-named SIM DIR all exist on disk} \
  [list [file exists $Z_INJ] [file exists $Z_SPACE] [file exists $Z_HRAW] \
        [file exists [file join $Z_SIMDIR y_a.raw]] \
        [expr {[string match {*y_a.sch} [xschem get schname 0]] ? 1 : 0}]] \
  {1 1 1 1 1}

check {AINJ1 a raw whose FILENAME carries Tcl does not execute it (the issue's own transcript, inverted)} \
  [opa_z_probe {xschem annotate_op $::Z_INJ 0}] 0

# THE SHIPPED MENU ENTRY, WITH NO ARGUMENT AT ALL.
catch {xschem raw clear}
set ::netlist_dir $Z_SIMDIR
set z2 [opa_z_probe {xschem annotate_op}]
set ::netlist_dir $Z_NDIR
check {AINJ2 `xschem annotate_op` with NO ARGUMENT does not execute Tcl living in the SIMULATION DIRECTORY name -- nobody typed a path} \
  $z2 0

# THE ARRAY-INDEX SHAPE, which no `subst` flag suppresses. `noar0812` does not
# exist and does not need to: the index is substituted before the lookup fails.
catch {xschem raw clear}
check {AINJ3 an ARRAY-INDEX payload `$a([set ::SC_PWNED 1]).raw` is not executed by annotate_op -- the shape that refuted the first attempt} \
  [opa_z_probe {xschem annotate_op {$noar0812([set ::SC_PWNED 1]).raw} 0}] 0

# ...and the same shape with `exec`, on a path that EXISTS NOWHERE. The resolver
# runs before any stat(), so non-existence is not a defence.
catch {xschem raw clear}
set Z_OWNED [file join $scratch OWNED_ANNOT]
check {AINJ4 an `[exec touch ...]` inside a variable ARRAY INDEX creates NO host file -- asserted on the FILE, on a path that does not exist on disk} \
  [opa_z_owned $Z_OWNED [list xschem annotate_op "\$noar0812(\[exec touch $Z_OWNED\]).raw" 0]] 0

# --- the counterweight: the ordinary paths must still annotate ---------------
catch {xschem raw clear}
catch {xschem annotate_op ~/$Z_HNAME 0}
check {AORD1 a `~/` path still annotates: the raw is read, registered under the EXPANDED name, and its value is live} \
  [list [rcall {xschem raw rawfile}] [rcall {xschem raw value v(a) -1}]] \
  [list [list 0 $Z_HRAW] {0 3.14}]

catch {xschem raw clear}
catch {xschem annotate_op $Z_SPACE 0}
check {AORD2 a path containing SPACES still annotates, under its own literal name} \
  [list [rcall {xschem raw rawfile}] [rcall {xschem raw value v(a) -1}]] \
  [list [list 0 $Z_SPACE] {0 3.14}]

# the shipped graph-attribute spelling: nine draw.c/callback.c sites hand
# extra_rawfile() a `rawfile=$netlist_dir/...` string unsubstituted
catch {xschem raw clear}
set ::netlist_dir $scratch
catch {xschem annotate_op {$netlist_dir/y_op_gold.raw} 0}
set z_ord3 [list [rcall {xschem raw rawfile}] [rcall {xschem raw value v(a) -1}]]
set ::netlist_dir $Z_NDIR
check {AORD3 a `$netlist_dir/...` spelling -- the one the shipped corpus uses -- still annotates and stores the RESOLVED absolute path} \
  $z_ord3 [list [list 0 $Y_GOLD] {0 3.14}]

# IDEMPOTENCE: annotate_op feeds the already-resolved xctx->raw->rawfile back
# through extra_rawfile()'s clear arm, so a second call on the same file must
# find and clear its own entry rather than miss it.
catch {xschem raw clear}
set z_k1 [rcall {xschem annotate_op $::Z_SPACE 0}]
set z_k2 [rcall {xschem annotate_op $::Z_SPACE 0}]
check {AKEY1 two successive annotate_op on the SAME file both succeed and the value stays live (resolving twice == resolving once)} \
  [list [lindex $z_k1 0] [lindex $z_k2 0] [rcall {xschem raw value v(a) -1}]] \
  [list 0 0 {0 3.14}]

catch {xschem raw clear}
file delete -force $Z_HRAW   ;# early drop; the exit hook above is the backstop
set XSCHEM_LIBRARY_PATH $W_LIBS

} zerr]} {
  puts "UNEXPECTED ERROR (section Z): $zerr"
  incr fail
}

# =============================================================================
# SECTION V — ISSUE 0868: ON-REQUEST TRANSIENT NODE-VOLTAGE ANNOTATION AT THE
#             WAVEFORM CURSOR, AND THE TWO ACQUISITION DOORS OF ISSUE 0865
# =============================================================================
# The user's request, verbatim 2026-08-26:
#
#   "MUST ONLY HAPPEN WHEN USER REQUESTS IT!! Alt-6 and 6 are for OP info and OP
#    node voltages. We can add a menu item in Results > Annotate for annotating
#    TRAN node voltages for time-point given by cursor B, or A - whatever the
#    convention is - if there is only one cursor in the waveform viewer's active
#    tab, use that. If A and B are there, then use cursor-A. Give user a way to
#    enter this mode with a different shortcut through cadence_style_rc - maybe
#    Alt-Shift-6"
#
# Two halves, and they are one item because neither ships alone.
#
# HALF 1 -- THE TWO ACQUISITION DOORS. With the Live-annotate box unticked, a
# transient node voltage lands on the schematic WITHOUT anyone asking, from two
# places that do not ask: raw_read's tail in src/save.c and descend_schematic's
# tail in src/actions.c. Measured on this tree, box off, a sheet carrying a graph
# rect and cursor B on at 4 ns:
#
#     xschem raw read <tran>       ->  raw annot 3 4e-09 0, the sheet paints d 4
#     xschem swap_cursors          ->  cursor B is now at 0, the sheet STILL
#                                      paints d 4  <- RULING D5-1: a number that
#                                      was not measured for the state it is
#                                      shown in
#
# The six re-annotate sites the user can reach by moving a cursor are already
# gated on the box; these two are not. Guards G1 and G2 close them, and rows
# V22 / V23 / V23b / V24 are the measurement.
#
# ⚠ THE 0856 GATE CLOSED ONE ROAD AND LEFT THE OTHER OPEN, so half 1 is
# FINISHING 0856 rather than repairing staleness. `update_op()` already refuses a
# transient (rows T23-T28), so the `6` chord paints nothing on a pure transient.
# The cursor road has no such refusal, so `Alt-6` on the same sheet paints a
# transient node voltage on the operating-point surface, unrequested. That is
# what the user's "we haven't yet built anything for annotating from TRAN
# results, so it should do nothing silently" forbids.
#
# ⚠ AND THE STALE NUMBER IS UNREFRESHABLE, which is why half 1 cannot ship
# alone. Measured with the box off: `s` leaves d 4, Alt-6 again leaves d 4,
# Ctrl-6 then Alt-6 leaves d 4. With the box ticked the same gesture correctly
# repaints d 1. The engine can re-measure; the user has no on-request door.
# Gating the doors without half 2 leaves a user who cannot annotate at all.
#
# HALF 2 -- THE THIRD MODE. A third `annot_show` bit -- bit0 ANNOT_SHOW_OP is
# the `6` chord, bit1 ANNOT_SHOW_VOLTAGE is Alt-6, bit2 ANNOT_SHOW_TRAN is this
# -- a new C verb `xschem annotate_at <time>` that resolves ONE time point
# against xctx->raw, a Tcl cursor rule, a menu entry and a chord.
#
# ============================================================================
# THE PUBLISHER INVENTORY, CORRECTED -- ISSUE 0865 AND THE ITEM BRIEF BOTH GET
# IT WRONG IN BOTH DIRECTIONS
# ============================================================================
# * `src/scheduler.c:12080`, named as an ungated publisher, is inside `#if 0`
#   (:12075 / :12083). It is DEAD CODE. Gating it would look like work and be
#   nothing.
# * `src/scheduler.c:12123`, the `else if(backannotate_at_cursor_b_nograph())`
#   arm of the same `xschem set cursor2_x`, is a FOURTH ungated publisher nobody
#   listed. Measured painting d 3 with the box off and no graph on the sheet.
# So the real ungated set is save.c:1287, actions.c:4819, scheduler.c:12112 and
# scheduler.c:12123.
#
# ============================================================================
# ⚠ THE DELIBERATE NON-GATING OF `xschem set cursor2_x`, AND ROW V25
# ============================================================================
# Both `set cursor2_x` arms are LEFT PUBLISHING, and that is a decision with a
# reason, recorded in issue 0868 and pinned by row V25 so that a later crew which
# tries to "finish the gating" reds a row that explains itself.
#   * `xschem set cursor2_x <t>` is a sentence a user or a script TYPED, naming a
#     time. Loading a raw and descending a hierarchy are things the program does.
#     The user's test is "only when the user requests it", and a typed verb is a
#     request.
#   * It stamps annot_x at exactly the position it was measured at, so it is
#     never stale at the moment it happens.
#   * It is driven 43 times across five suites -- test_op_annot 35,
#     test_wave_cursor_crossdb 4, test_wave_viewer 2, test_wave_crossdb_trace 1,
#     test_backannotate_digital 1 -- and three of those suites never mention the
#     Live-annotate box at all. It is also the scripting verb and the shipped S11
#     feature's only road.
#   * The waveform viewer's own `set cursor2_x` runs inside the VIEWER's context
#     -- `wviewer::cursor_toggle` switches first, src/wave_viewer.tcl:14239 --
#     so it never touches the design sheet's annotation.
#   * Both plans have the IDENTICAL residual: after any on-request annotation the
#     number persists while the cursor moves on. Gating it buys nothing half 2
#     does not already provide, and costs five suites.
# The alternative -- gate everything, per issue 0865's ruling -- is recorded as a
# rejected option in 0868 and is owed to the user as a `rule` debt.
#
# ============================================================================
# ⚠ WHY CURSOR A GETS NO VALUE ARRAY, AND WHY THAT STILL HONOURS THE RULING
# ============================================================================
# The engine has `cursor_b_val` only. Cursor A exists as `graph_cursor1_x`, is
# drawn, is read out -- and is INERT: measured, with both cursors on, A at 1 ns
# and B at 4 ns, the annotation is 3 4e-09 0 and the sheet paints d 4; moving A
# to 2 ns changes nothing at all.
# The mode resolves ONE time point -- cursor A when both are on, otherwise
# whichever one is -- and publishes it through the existing array. The user's
# rule is honoured in full. The deliberate limit is that A and B cannot be
# annotated SIMULTANEOUSLY, which nobody asked for; a real independent
# `cursor_a_val` costs six alloc sites plus eight token.c readers plus new Raw
# fields. Recorded as a limit in 0868.
#
# ============================================================================
# ⚠ THE BIND SPELLING IS THE TRAP, AND ONLY ROW V20 CAN SEE IT
# ============================================================================
# Measured with wish on :99: keycode 15 is `6 asciicircum`, a physical Alt+Shift+6
# arrives as keysym `asciicircum`, and even an event synthesised with keysym `6`
# plus Shift+Alt dispatches to `<Alt-Key-asciicircum>`. `<Alt-Shift-Key-6>` NEVER
# fires. A landing that writes only the Shift-Key-6 form passes every behavioural
# row in this file and is DEAD under the user's fingers. src/cadence_style_rc
# already documents the identical gotcha for Ctrl-Shift-4 -> `dollar` at :275-281;
# this is the same precedent, and V20 is a structural row for the same reason.
#
# ============================================================================
# ROWS THAT ARE GREEN BEFORE THE CHANGE -- CONTROLS, NOT EVIDENCE
# ============================================================================
#   V0   the fixture control. Without it every row below degrades into a hollow
#        pass -- a raw that failed to attach answers nothing for everything,
#        which is the shape half the rows here ask about.
#   V8   the off-ramp. Mask 0 paints no voltage today because nothing is
#        published; it must still paint none when bit2 exists and is clear.
#   V22  leg 2 and V23 leg 2, the POSITIVE CONTROLS of guards G1 and G2. A gate
#        that reds nothing when it is removed is not a gate; a gate that also
#        silences the ticked box is a worse defect than the one it fixes.
#   V25  the recorded decision's pin. See the paragraph above.
#
# ============================================================================
# ⚠ WHAT THIS SECTION DOES NOT MEASURE
# ============================================================================
# * NO PIXELS. Every PAINT row reads an SVG export -- the same back end the
#   screen uses, not the screen. FAQ Q52: `xschem translate` is NOT a paint
#   measurement and an SVG export is. A new menu entry and a new keyboard chord
#   are pixel deliverables and owe an eyeball (`owed.sh add look`).
# * NO VIEWER. Guard G8 -- the mode borrowing the waveform viewer's context so
#   it reads the ACTIVE TAB's cursors -- cannot be seen headless at all, because
#   headless there is no viewer. Rows B12 / B12b of
#   tests/headless/test_annot_show_menu.tcl own it, and that suite must be run on
#   the dev display before this item is called done.
# * NO PHYSICAL KEY PRESS. V20 is a source grep. Nothing automated can press a
#   real Alt+Shift+6.

set V_RAW $T_RAW
set V_VP  $T_VP
## The lab_pin tail of an SVG export in the two states this section keeps
## asking about. MEASURED on this binary, and they are the same shapes section T
## already uses -- the four labels back to back when nothing is published, and a
## value sitting between each label and the next when something is.
set V_PINS_NONE {d g 0 0}
set V_PINS_P1   {d 1 g 0.9 0 0.0 0 0.0}
set V_PINS_P2   {d 2 g 0.9 0 0.0 0 0.0}
set V_PINS_P3   {d 3 g 0.9 0 0.0 0 0.0}
set V_PINS_P4   {d 4 g 0.9 0 0.0 0 0.0}

## THE ONE MINT, as five byte-exact sentences (RULING D5-4). These strings ARE
## the specification: `cadence::_annot_tran_msg` renders exactly them and every
## caller -- the chord, the ASE-L menu entry, the CIW line and the held status
## line -- renders through it rather than composing its own wording.
set V_MSG_OK       {Showing each node's voltage at 1 ns, where cursor A is on the waveform.}
set V_MSG_NOCURSOR {Turn on cursor A or cursor B in the waveform window first. The schematic then shows each node's voltage at the time that cursor marks.}
set V_MSG_NORAW    {No simulation results are loaded, so there are no voltages to show. Run a simulation first, then try again.}
set V_MSG_NOTRAN   {These results are not from a transient run, so there is no time axis to read a voltage at. Run a transient simulation to use this.}
set V_MSG_NODATA   {The results have no values at 3 ns, so nothing was placed on the schematic.}

## `xschem annotate_at <t>` -> the verb's rc, or a marker. NEVER a bare catch:
## the verb does not exist today and `invalid command` reported as 0 would make
## "refused politely" and "was never built" the same answer.
proc opa_v_at {t} {
  set r [rcall [list xschem annotate_at $t]]
  if {[lindex $r 0] != 0} { return "RAISED:[lindex $r 1]" }
  return [lindex $r 1]
}
## `cadence::annot_tran` -> the state name it returns, or a marker. Same
## discipline: an absent proc must not read as a refusal.
proc opa_v_tran {} {
  set r [rcall {cadence::annot_tran}]
  if {[lindex $r 0] != 0} { return "RAISED:[lindex $r 1]" }
  return [lindex $r 1]
}
## Set the mask, refresh the bboxes, export ONCE and return the lab_pin tail.
## ⚠ ONE export, through opa_l_print and not opa_l_print2: opa_l_print2's warm
## pass is itself a draw, and row V10's whole claim is about the FIRST frame
## after a publish with no redraw in between.
proc opa_v_paint {tag {mask -1}} {
  if {$mask >= 0} { opa_l_annot $mask }
  return [opa_t_pins [opa_l_print svg [file join $::scratch v_$tag.svg] $::V_VP]]
}
## Re-arm WITHOUT touching the cursors: `raw clear` then `annotate_op` puts the
## annotation back to the 0856 resting state -1 0 -1 while graph_flags,
## graph_cursor1_x and graph_cursor2_x survive. MEASURED -- opa_t_arm cannot be
## used by the cursor-rule rows because it says `xschem cursor 2 0` out loud.
proc opa_v_rearm {} {
  catch {xschem raw clear}
  return [lindex [rcall [list xschem annotate_op $::V_RAW]] 0]
}
## Count the lines of <path> matching <re>, IGNORING whole-line Tcl comments, so
## a sentence quoted in a header paragraph is not counted as a second mint.
## -1 when the file is absent, so a missing file reds one row.
proc opa_v_ngrep {path re} {
  if {![file isfile $path]} { return -1 }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set n 0
  foreach l [split $d \n] {
    if {[regexp {^\s*#} $l]} continue
    if {[regexp -- $re $l]} { incr n }
  }
  return $n
}

if {[catch {

set XSCHEM_LIBRARY_PATH $S_LIBS
set V_LV $::live_cursor2_backannotate

## ⚠ A KNOWN-EMPTY `netlist_dir`, AND ROWS V15 AND V29 NEED IT (item A10).
## Until issue 0881 those two rows answered `noraw` BY ACCIDENT: nothing was
## attached, and whatever directory an earlier section happened to leave in
## ::netlist_dir happened not to hold a `<cell>.raw`. Once the transient mode
## goes and FINDS the run's results the way `6` already does, `noraw` stops
## meaning "nothing is attached" and starts meaning "nothing is attached AND
## there is no candidate on disk" -- so the second half has to be built by the
## fixture rather than inherited from section W's leftovers.
set V_ND_NONE [file join $scratch v_nd_none]
file mkdir $V_ND_NONE
foreach _vf [glob -nocomplain [file join $V_ND_NONE *]] { catch {file delete -force $_vf} }

# ===========================================================================
# V0 — CONTROL: THE PREMISE. GREEN BEFORE AND AFTER, AND LOAD-BEARING
# ===========================================================================
# ⚠ WITHOUT THIS ROW EVERY ROW BELOW DEGRADES INTO A HOLLOW PASS. Four claims:
# the transient really ATTACHED (rc 0 and sim_type tran, so a row that measures
# "nothing was published" is measuring a refusal and not an empty tree); it rests
# at the 0856 refused state -1 0 -1; there is NO graph object on the canvas, so
# every cursor row below is exercising the graphless arm; and neither cursor is
# on, so the cursor-rule rows say what they turn on out loud.
catch {xschem cursor 1 0}
set v0_rc [opa_t_arm [file join $lib s5_flat.sch]]
check {V0 CONTROL: the transient ATTACHES on a graphless sheet with no cursor on, and rests at the 0856 refused state} \
  [list $v0_rc [rcall {xschem raw sim_type}] [opa_t_annot] \
        [xschem get rects 2] [xschem get graph_flags]] \
  [list 0 {0 tran} {-1 0 -1} 0 0]

# ===========================================================================
# V1 — THE NEW VERB PUBLISHES AT A REQUESTED TIME, WITH NO CURSOR INVOLVED
# ===========================================================================
# ⚠ ALL THREE FIELDS, for the reason row T1 gives: an implementation that wrote
# annot_x and stopped would still read the resting point everywhere.
# `xschem annotate_at <t>` is a top-level sibling of `xschem annotate_op`, it
# returns 1 when it annotated and 0 when there was nothing to annotate against,
# and it does NOT go through a cursor -- half 2's entry points resolve a time
# first and hand it over, so the C verb has exactly one input.
check {V1 `xschem annotate_at 3e-9` returns 1 and stamps annot_p, the requested annot_x and the resolved sweep} \
  [list [opa_v_at 3e-9] [opa_t_annot]] [list 1 {2 3e-09 0}]

# ===========================================================================
# V2 — BETWEEN SAMPLES: THE SHIPPED INTERPOLATION, NOT A NEAREST-SAMPLE SNAP
# ===========================================================================
# 2.5 ns is exactly half way between two round samples, so a nearest-sample or
# floor-to-sample implementation answers 2 or 3 and reds here while passing V1.
# The number is the one the cursor path returns for the same t on the same raw.
opa_v_at 2.5e-9
check {V2 a requested time BETWEEN two samples interpolates -- 2.5 ns is exactly 2.5, not a snap to 2 or 3} \
  [opa_t_v {v(d)}] 2.5

# ===========================================================================
# V3 — THE WINDOW DISCRIMINATOR (guard G5): THE ONE ROW A ZEROED Graph_ctx
#      CANNOT PASS
# ===========================================================================
# ⚠ THE STEP'S SHARPEST TRAP, AND IT LOOKS LIKE A NON-ISSUE. The new verb has to
# hand the shipped cursor arithmetic a LOCAL Graph_ctx -- never
# xctx->graph_struct, which is live inside draw_graph(). A memset-0 one is the
# obvious choice and it is the degenerate window 0,0: every transient raw has a
# sample at exactly t=0, that sample passes the window filter, so `first` comes
# back 0 instead of -1, RULING D4-7's rescan never fires, and interpolate_yval's
# frac clamp walks ONE segment forward and returns POINT 1's value for every t
# past the second sample. Measured on the graph path today with an un-zoomed
# rect: v(d) = 1 at t = 3 ns where the truth is 3.0 -- a plausible wrong number
# on a schematic, which is exactly what invariant I3 and RULING D5-1 forbid.
# callback.c:1637-1648 carries the same reasoning for the graphless arm; the new
# verb needs the same -HUGE_VAL / +HUGE_VAL window, and this row is the only
# thing between the feature and that wrong number.
opa_v_at 3e-9
set v3a [opa_t_v {v(d)}]
opa_v_at 4e-9
set v3b [opa_t_v {v(d)}]
check {V3 guard G5 two times a degenerate 0,0 window would collapse onto point 1 each answer their OWN sample} \
  [list $v3a $v3b] {3 4}

# ===========================================================================
# V4 — RULING D4-4: A BOUNDARY HOLDS, IT NEVER EXTRAPOLATES
# ===========================================================================
# Past the last sample the value HOLDS at the last sample; before the first it
# holds at the first. An arm that extrapolated would answer 99 and -5 here, and
# a fabricated number on a schematic is RULING D5-1's failure.
opa_v_at 99e-9
set v4a [opa_t_v {v(d)}]
opa_v_at -5e-9
set v4b [opa_t_v {v(d)}]
check {V4 RULING D4-4 out of range in both directions HOLDS at the boundary sample, never extrapolates} \
  [list $v4a $v4b] {4 0}

# ===========================================================================
# V5 — GUARD G4: A SHEET WITH NO DATA IS A BYTE-EXACT NO-OP
# ===========================================================================
# ⚠ THE T19/T20 LESSON, RE-EARNED. backannotate_at_cursor_b_pos() fires
# annot_data_changed() and `catch {eval $cursor_2_hook}` BEFORE its own
# sch_waves_loaded() test, so a verb that called it unconditionally would fire a
# user hook and move the S9b overlay flush counter on every sheet with no data.
# The gate belongs AHEAD of the call, exactly as
# backannotate_at_cursor_b_nograph() puts it (callback.c:1657).
# Both halves: the verb answers 0, and the flush counter did not move.
catch {xschem raw clear}
set v5_delta [opa_o_fdelta {opa_v_at 3e-9}]
set v5_rc    [opa_v_at 3e-9]
check {V5 guard G4 with NO raw loaded the verb answers 0 and moves the overlay flush counter by nothing} \
  [list $v5_rc $v5_delta] {0 0}

# ===========================================================================
# V6 — THE VERB READS A TIME, IT DOES NOT MOVE THE USER'S CURSOR
# ===========================================================================
# ⚠ AN IMPLEMENTATION THAT "FIXES" THE at-PARAMETER BY WRITING graph_cursor2_x
# = t INSTEAD PASSES V1-V4 AND FAILS HERE, which is why this row exists next to
# them rather than being folded into one of them. Moving the user's cursor B as a
# side effect of reading a value would be its own defect: the waveform viewer
# would jump under the pointer every time the sheet was annotated.
opa_t_arm [file join $lib s5_flat.sch]
xschem cursor 2 1 ; xschem cursor 1 1
xschem set cursor1_x 1e-9
xschem set cursor2_x 4e-9
set v6_pre [list [xschem get cursor1_x] [xschem get cursor2_x]]
opa_v_at 2e-9
set v6_post [list [xschem get cursor1_x] [xschem get cursor2_x]]
check {V6 `annotate_at` READS a time point and leaves both cursor positions byte-identical} \
  [list $v6_pre $v6_post] {{1e-09 4e-09} {1e-09 4e-09}}

# ===========================================================================
# V7 — PAINT (guard G6): A BARE BIT2 PAINTS
# ===========================================================================
# ⚠ MEASURED TODAY: `xschem set annot_show 4` reads back 4 and paints NOTHING,
# because actions.c gates the node-voltage texts on bit1 alone. A third bit that
# renders nothing is a mode the user can select and not see. The repair is one
# line -- annot_class_mask()'s TEXT_ANNOT_VOLTAGE arm returns
# ANNOT_SHOW_VOLTAGE | ANNOT_SHOW_TRAN, making bit2 a SECOND switch onto the same
# content class rather than a second class.
# ⚠ AN SVG EXPORT, NEVER `xschem translate` -- FAQ Q52: translate is not a paint
# measurement.
opa_t_arm [file join $lib s5_flat.sch]
opa_v_at 3e-9
set v7 [opa_v_paint bit2 4]
check {V7 guard G6 PAINT with the mask at bit2 ALONE the lab_pin floater renders the annotated value} \
  [list [xschem get annot_show] $v7] [list 4 $V_PINS_P3]

# ===========================================================================
# V8 — CONTROL: THE OFF-RAMP STILL EXISTS
# ===========================================================================
# GREEN BEFORE AND AFTER. With every bit clear the labels run back to back and no
# voltage text is emitted anywhere on the sheet. A bit2 arm wired so that it
# rendered regardless of the mask would red here and nowhere else.
check {V8 CONTROL mask 0 paints no voltage at all -- the labels run back to back} \
  [opa_v_paint off 0] $V_PINS_NONE

# ===========================================================================
# V9 — THE TWO VOLTAGE BITS ARE INDEPENDENT SWITCHES ONTO ONE CLASS
# ===========================================================================
# ⚠ THE ROW THAT REDS A bit2 ARM IMPLEMENTED AS AN ALIAS OF bit1. Masks 2, 4 and
# 6 all paint the same annotated value -- bit1 alone, bit2 alone, and both -- and
# mask 1 paints none of it, because bit0 is device OP info and this content is
# node voltages. An arm that made bit2 simply set bit1 would pass V7 and fail the
# mask-4-with-bit1-clear leg here.
opa_t_arm [file join $lib s5_flat.sch]
opa_v_at 3e-9
set v9 {}
foreach m {2 4 6 1} { lappend v9 [opa_v_paint m$m $m] }
opa_l_annot 0
check {V9 masks 2, 4 and 6 each paint the annotated value and mask 1 paints none of it} \
  $v9 [list $V_PINS_P3 $V_PINS_P3 $V_PINS_P3 $V_PINS_NONE]

# ===========================================================================
# V10 — GUARD G10: THE FLOATER CACHE IS REFRESHED, IN THE SAME FRAME
# ===========================================================================
# ⚠ THIS ROW IS NOT THE G10 GUARD'S WITNESS -- ROW V10b BELOW IS. Measured with
# a printf inside the guard: over s5_flat.sch `there_are_floaters()` answers 0
# on all twenty `annotate_at` calls in this file, because that function scans
# the SCHEMATIC's own text records and s5_flat.sch has none. So `if(rc &&
# floaters) set_modify(-2);` never runs here and deleting it leaves this row
# green. What V10 does measure is still worth having and is stated honestly:
# the SYMBOL-text render path -- `@spice_get_voltage` inside lab_pin.sym, drawn
# per instance -- carries the new value in the first frame after the new verb,
# with no redraw in between. That is row T22's blast radius re-measured for
# `annotate_at`, and a verb that left the symbol texts on the previous request
# is the I3 breach that got S9 attempt 1 reverted. The floater CACHE, which is
# the thing G10 refreshes, is a different path and needs a sheet that has one.
# ⚠ ONE EXPORT, NO INTERVENING REDRAW. opa_v_paint uses opa_l_print, not
# opa_l_print2: a warm pass would be a second draw and would hide the defect.
opa_t_arm [file join $lib s5_flat.sch]
opa_v_at 1e-9
set v10a [opa_v_paint fl1 2]
opa_v_at 4e-9
set v10b [opa_v_paint fl4]
opa_l_annot 0
check {V10 guard G10 the FIRST frame after `annotate_at`, with no redraw in between, already carries the new value} \
  [list $v10a $v10b] [list $V_PINS_P1 $V_PINS_P4]

# ===========================================================================
# V10b — GUARD G10 FOR REAL: A SHEET THAT ACTUALLY HAS A FLOATER
# ===========================================================================
# ⚠ V10 ABOVE CANNOT SEE G10, MEASURED, AND THAT IS WHY THIS ROW EXISTS.
# `there_are_floaters()` (src/actions.c) scans the SCHEMATIC's own xctx->text[]
# and nothing else. s5_flat.sch has four lab_pin instances and NO text record
# at all, so the count is 0 on every call and `if(rc && floaters)
# set_modify(-2);` never executes anywhere in this file. Instrumented with a
# printf inside the guard: all twenty `annotate_at` calls report floaters=0.
# Deleting the guard and rebuilding left the whole suite green -- a guard
# shipped untested behind a row named after it. The number V10 measures belongs
# to lab_pin.sym, a SYMBOL text drawn per instance, which is a different render
# path and does not go through the floater cache.
# ⚠ SO THE FIX IS A FIXTURE, NOT A MECHANISM, AND IT IS ITS OWN SHEET. Adding a
# schematic-level text to s5_flat.sch moves fifteen other goldens; v_g10.sch
# carries the same four lab_pins plus ONE schematic-own floater -- a text with
# a `name=` property, which is what sets TEXT_FLOATER (src/actions.c) -- so it
# renders through get_text_floater()'s cache and nothing else in the file moves.
# ⚠ THE COUNTERFACTUAL WAS BUILT, so this row is not a guess about what the
# guard does. With the guard present the sheet reads 1 then 4. With it deleted
# it reads 1 then 1: the sheet keeps displaying the PREVIOUS request's number
# while the database has moved on, which is RULING D5-1 -- a number that was
# not measured for the thing it is displayed next to.
# ⚠ ONE EXPORT, NO INTERVENING REDRAW, for V10's own reason: the second frame
# is the subject, so `opa_l_annot` is not called between the second
# `annotate_at` and its export, and the reader goes through opa_l_print rather
# than opa_l_print2.
set f [open [file join $lib v_g10.sch] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
T {ZZG10=@spice_get_voltage} -200 -200 0 0 0.2 0.2 {name=p1}
C {lab_pin.sym} 20 -30 0 0 {name=p1 lab=d}
C {lab_pin.sym} -20 0 0 0 {name=p2 lab=g}
C {lab_pin.sym} 20 30 0 0 {name=p3 lab=0}
C {lab_pin.sym} 20 0 0 0 {name=p4 lab=0}}
close $f
## The SCHEMATIC-OWN floater texts of one export, in document order. A list, so
## a fixture that lost its floater reads as an empty list and reds this row
## rather than quietly agreeing with a broken export.
proc opa_v_fl {tag} {
  set o {}
  foreach t [opa_q_texts [opa_l_print svg [file join $::scratch v_$tag.svg] $::V_VP]] {
    if {[string first ZZG10= $t] == 0} { lappend o $t }
  }
  return $o
}
catch {xschem raw clear}
xschem load [file join $lib v_g10.sch]
catch {xschem cursor 2 0}
set v10b_arm [lindex [rcall [list xschem annotate_op $V_RAW]] 0]
opa_l_annot 2
set v10b_r1 [opa_v_at 1e-9]
set v10b_f1 [opa_v_fl g10_1]
set v10b_r2 [opa_v_at 4e-9]
set v10b_f2 [opa_v_fl g10_2]
opa_l_annot 0
check {V10b guard G10 on a sheet that HAS a floater the first frame after `annotate_at` already carries the new value} \
  [list $v10b_arm $v10b_r1 $v10b_f1 $v10b_r2 $v10b_f2] \
  [list 0 1 {ZZG10=1} 1 {ZZG10=4}]

# ===========================================================================
# V11 — THE USER'S RULE (guard G7): BOTH CURSORS ON MEANS CURSOR A
# ===========================================================================
# ⚠ THE DISCRIMINATOR ROW. V12 and V13 stay GREEN under a build that always
# prefers cursor B, so they are not evidence for the rule on their own; this is
# the only row that fails when the preference is the wrong way round.
# The user's words: "if there is only one cursor in the waveform viewer's active
# tab, use that. If A and B are there, then use cursor-A."
# ⚠ MEASURED TODAY AND IT IS THE WHOLE DEFECT: with both cursors on, A at 1 ns
# and B at 4 ns, the annotation is 3 4e-09 0 and the sheet paints d 4. Cursor A
# is drawn and read out and has no value path whatever.
# ⚠ `xschem cursor N 1` RESETS that cursor's position, so both positions are
# written AFTER both cursors are enabled. graph_flags 6 is A and B both on --
# measured 0 / 2 / 4 / 6 for none / A / B / both.
# Four claims: the mode says `ok`, it published at CURSOR A's time, it armed bit2
# itself, and the sheet paints cursor A's value.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 1 1 ; xschem cursor 2 1
xschem set cursor1_x 1e-9
xschem set cursor2_x 4e-9
opa_v_rearm
set v11_state [opa_v_tran]
check {V11 guard G7 BOTH cursors on: the mode annotates at CURSOR A, arms bit2 itself and paints A's value} \
  [list $v11_state [xschem get graph_flags] [lindex [opa_t_annot] 1] \
        [xschem get annot_show] [opa_v_paint both]] \
  [list ok 6 1e-09 4 $V_PINS_P1]

# ===========================================================================
# V12 — ONLY CURSOR B ON: USE CURSOR B
# ===========================================================================
# GREEN UNDER A B-PREFERRING BUILD, by construction -- see V11. It is here so
# that a build which honoured the rule by IGNORING cursor B cannot pass.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 4e-9
opa_v_rearm
set v12_state [opa_v_tran]
check {V12 only cursor B on: the mode annotates at cursor B} \
  [list $v12_state [xschem get graph_flags] [lindex [opa_t_annot] 1] [opa_v_paint bonly]] \
  [list ok 4 4e-09 $V_PINS_P4]

# ===========================================================================
# V13 — ONLY CURSOR A ON: USE CURSOR A
# ===========================================================================
# ⚠ THE ROW THAT SAYS CURSOR A HAS A VALUE PATH AT ALL. Today `xschem set
# cursor1_x` writes a global nobody reads -- its would-be publisher at
# scheduler.c:12076 is inside `#if 0` -- so no gesture in the program can put
# cursor A's value on a schematic.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 2 0 ; xschem cursor 1 1
xschem set cursor1_x 2e-9
opa_v_rearm
set v13_state [opa_v_tran]
check {V13 only cursor A on: the mode annotates at cursor A -- the path that does not exist today} \
  [list $v13_state [xschem get graph_flags] [lindex [opa_t_annot] 1] [opa_v_paint aonly]] \
  [list ok 2 2e-09 $V_PINS_P2]

# ===========================================================================
# V14 — NO CURSOR ON: REFUSE, SAY SO, AND ARM NOTHING (guards G7 + G13)
# ===========================================================================
# ⚠ THE MASK IS ARMED ONLY AFTER A SUCCESSFUL PUBLISH, and that ordering is a
# guard, not a style. Arming first would leave the user looking at an armed mode
# over a sheet showing the PREVIOUS request's numbers -- RULING D5-1 with an
# extra step. Three claims: the state name, nothing published, and the mask never
# gained bit2.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 0
check {V14 guards G7 and G13 with NO cursor on the mode refuses by name, publishes nothing and arms no bit} \
  [list [opa_v_tran] [opa_t_annot] [xschem get annot_show] [opa_v_paint nocur]] \
  [list nocursor {-1 0 -1} 0 $V_PINS_NONE]

# ===========================================================================
# V15 — NO DATABASE AT ALL: REFUSE BY A DIFFERENT NAME
# ===========================================================================
# ⚠ ISSUE 0857's CHANNEL, AND THE HALF THIS ITEM OWES IT. The user ruled 2026-08-26
# that when the user asks for annotation and the program cannot deliver it, the
# program says so in the CIW rather than doing nothing silently. The five states
# are distinguishable by NAME so the caller can render one sentence per cause
# rather than one apology for all of them.
## ⚠ THE EMPTY `netlist_dir` IS PART OF THE FIXTURE, NOT TIDINESS (item A10).
## `noraw` here means BOTH halves -- nothing is attached to this sheet and there
## is no results file for this cell on disk either -- and after issue 0881 the
## second half is the one that decides the answer. Left to the ambient value the
## row would be asserting whatever the previous section's directory contained.
set v15_nd $::netlist_dir
set ::netlist_dir $V_ND_NONE
opa_l_annot 0
catch {xschem raw clear}
xschem cursor 2 1
xschem set cursor2_x 4e-9
check {V15 with NO database loaded and NO results file on disk the mode refuses as `noraw`, publishes nothing and arms no bit} \
  [list [opa_v_tran] [rcall {xschem raw loaded}] [xschem get annot_show]] \
  [list noraw {0 -1} 0]
set ::netlist_dir $v15_nd

# ===========================================================================
# V16 — THE WRONG KIND OF DATABASE: 0856's RULE, APPLIED IN THE OTHER DIRECTION
# ===========================================================================
# The user ruled that an operating-point surface must not show a transient's
# numbers. The converse is this row: a TRANSIENT mode must not show an operating
# point's. `xschem raw sim_type` already answers `op`, so the detector exists and
# this is a refusal, not a limitation.
# ⚠ THE OP FIXTURE IS SECTION T's, deliberately: 7.5 is exactly representable and
# no other row's leftovers can satisfy this one.
opa_l_annot 0
catch {xschem raw clear}
xschem raw read $T_OPRAW op
xschem cursor 2 1
check {V16 an OPERATING POINT database in the TRANSIENT mode refuses as `notran` and publishes nothing} \
  [list [rcall {xschem raw sim_type}] [opa_v_tran] [xschem get annot_show]] \
  [list {0 op} notran 0]
catch {xschem raw clear}

# ===========================================================================
# V17 — THE ONE MINT (RULING D5-4), AS FIVE BYTE-EXACT SENTENCES
# ===========================================================================
# ⚠ THE `ok` SENTENCE NAMES THE TIME POINT AND THE CURSOR LETTER, and that is
# the load-bearing part rather than politeness. The mode takes a SNAPSHOT: the
# number stays on the sheet while the cursor moves on, so the only thing keeping
# it honest under RULING D5-1 is that the user was told what it was measured at
# and from which cursor. A sentence that said merely "annotated" would leave the
# user with an undated number.
# ⚠ AN UNKNOWN STATE RAISES. `_annot_msg`'s own discipline (row N2): a mode
# spelling is a caller bug and must be loud, unlike DATA, which blanks (I3).
check {V17 RULING D5-4 the five sentences of the transient mode, byte for byte} \
  [list [rcall {cadence::_annot_tran_msg ok 1e-09 A}] \
        [rcall {cadence::_annot_tran_msg nocursor {} {}}] \
        [rcall {cadence::_annot_tran_msg noraw {} {}}] \
        [rcall {cadence::_annot_tran_msg notran {} {}}] \
        [rcall {cadence::_annot_tran_msg nodata 3e-09 B}]] \
  [list [list 0 $V_MSG_OK] [list 0 $V_MSG_NOCURSOR] [list 0 $V_MSG_NORAW] \
        [list 0 $V_MSG_NOTRAN] [list 0 $V_MSG_NODATA]]

check_raises {V17b an unknown state RAISES rather than rendering a default apology} \
  {cadence::_annot_tran_msg zzv868garbage {} {}} {zzv868garbage}

# ===========================================================================
# V18 — STRUCTURAL, RULING D5-4: THE SENTENCE IS MINTED IN EXACTLY ONE FILE
# ===========================================================================
# ⚠ NO RUNTIME ROW CAN SEE THIS. Two entry points drive this mode -- a menu item
# and a chord -- and the shape a hurried landing reaches for is a second
# `statusmsg` string inside `ase::ui::annot_apply`, which every behavioural row
# above would still pass. D5-4 says a user-facing sentence is minted in ONE place
# and rendered by callers.
# ⚠ WHOLE-LINE COMMENTS ARE STRIPPED FIRST, or this section's own header
# paragraphs would count as mints.
## ⚠ RE-AIMED BY ISSUE 0886, AND STRENGTHENED RATHER THAN WEAKENED. The eight
## transient sentences no longer share a "Transient annotation" stem -- plain
## English does not open every sentence with a category name -- so the row now
## carries THREE fragments, one from a success, one from a refusal the user can
## act on and one from a refusal about the results themselves. The mint leg is
## BEHAVIOURAL: it asks the rendered sentence for the fragment rather than
## grepping the source, because a minted sentence is written across continuation
## lines and a source grep would red on a reflow that changed nothing the user
## sees. The three zero legs are where the teeth are: a second mint anywhere
## else is what D5-4 forbids.
set V_MINT [file join $repo utils annot_mode.tcl]
set V18_FRAGS [list {is on the waveform} \
                    {voltage at the time that cursor marks} \
                    {no time axis to read a voltage at}]
set V18_SENT [list [lindex [rcall {cadence::_annot_tran_msg ok 1e-09 A}] 1] \
                   [lindex [rcall {cadence::_annot_tran_msg nocursor {} {}}] 1] \
                   [lindex [rcall {cadence::_annot_tran_msg notran {} {}}] 1]]
set v18 {}
foreach _v18f $V18_FRAGS _v18s $V18_SENT {
  lappend v18 [expr {[string match "*$_v18f*" $_v18s] ? 1 : 0}] \
              [opa_v_ngrep $N_ASE $_v18f] \
              [opa_v_ngrep $N_RC  $_v18f] \
              [opa_v_ngrep $N_TCL $_v18f]
}
check {V18 RULING D5-4 the transient sentences are minted in utils/annot_mode.tcl and appear in no other file} \
  $v18 {1 0 0 0 1 0 0 0 1 0 0 0}

# ===========================================================================
# V19 — STRUCTURAL: BOTH ENTRY POINTS DRIVE ONE CODE PATH
# ===========================================================================
# The user asked for a menu item AND a chord. Two independent implementations of
# the same mode is the drift invariant I1 exists to prevent, one level up: they
# would arm different bits, resolve different cursors and say different things.
check {V19 the chord and the ASE-L menu entry both call cadence::annot_tran, which is defined once} \
  [list [expr {[opa_v_ngrep $N_RC  {cadence::annot_tran}] >= 1 ? 1 : 0}] \
        [expr {[opa_v_ngrep $N_ASE {cadence::annot_tran}] >= 1 ? 1 : 0}] \
        [opa_v_ngrep $V_MINT {^proc cadence::annot_tran }]] \
  {1 1 1}

# ===========================================================================
# V20 — STRUCTURAL: THE BIND SPELLING, AND THE ONLY ROW THAT CAN SEE THE TRAP
# ===========================================================================
# ⚠ MEASURED WITH wish ON :99, AND IT IS THE WHOLE REASON THIS ROW IS
# STRUCTURAL: keycode 15 is `6 asciicircum`; a physical Alt+Shift+6 arrives as
# keysym `asciicircum`; an event synthesised with keysym `6` plus Shift+Alt still
# dispatches to <Alt-Key-asciicircum>; and <Alt-Shift-Key-6> NEVER fires. A
# landing that writes only the Shift-Key-6 form passes every behavioural row in
# this file and is DEAD under the user's fingers. src/cadence_style_rc:275-281
# already carries the identical finding for Ctrl-Shift-4 -> `dollar`; the
# asciicircum form is THE REAL BIND and the Shift-Key-6 form is kept as the
# documented non-US-layout fallback, exactly as there.
# ⚠ AND THE THREE SHIPPED CHORDS ARE RE-ASSERTED HERE UNCHANGED. Tk matches a
# pattern whose modifiers are a SUBSET of the event's, so a fourth chord added
# carelessly can swallow one of the three -- the same hazard row N19's comment
# records for Ctrl-6.
check {V20 src/cadence_style_rc binds Alt-Shift-6 through `asciicircum` AND keeps the Shift-Key-6 fallback, each ending in `break`} \
  [list [opa_n_rcbind $N_RC {<Alt-Key-asciicircum>}] \
        [opa_n_rcbind $N_RC {<Alt-Shift-Key-6>}]] \
  {{tran 1} {tran 1}}

# ===========================================================================
# V21 — THE STATUS LINE STOPS DESCRIBING A STATE THAT IS NOT THE ONE SHOWN
# ===========================================================================
# ⚠ MEASURED TODAY: `cadence::_annot_msg` switches on `mask & 3`, so mask 4 --
# transient node voltages ON and painted -- lands on the `0` arm and reports "OP
# annotation OFF". That is worse than falling through to the bare default: the
# line does not merely say nothing, it says the opposite of what is on the
# screen. The switch widens to `mask & 7`.
# ⚠ MASKS 0-3 MUST STAY BYTE-IDENTICAL. Row N23's four goldens are re-asserted
# here through the widened switch, so a widening that quietly re-worded the
# shipped four reds in this file rather than in six unrelated statusmsg rows.
set v21 {}
foreach m {0 1 2 3 4 5 6 7} { lappend v21 [rcall [list cadence::_annot_msg $m off {} {}]] }
check {V21 `_annot_msg` keeps its four shipped wordings and gains four that name the transient class} \
  $v21 \
  [list [list 0 $A11_M0] \
        [list 0 $A11_M1] \
        [list 0 $A11_M2] \
        [list 0 $A11_M3] \
        [list 0 $A11_M4] \
        [list 0 $A11_M5] \
        [list 0 $A11_M6] \
        [list 0 $A11_M7]]

# ===========================================================================
# V22 — GUARD G1, BEHAVIOURAL, BOTH LEGS: LOADING WAVES IS NOT A REQUEST
# ===========================================================================
# ⚠ THE 0865 ACQUISITION, IN ONE ROW. raw_read()'s tail (src/save.c:1279) fires
# backannotate_at_cursor_b_pos() on every successful read whenever a graph rect
# with cursor B on happens to be on the sheet -- with the Live-annotate box in
# its shipped UNTICKED state. Nobody asked for that number: the user loaded a
# waveform file.
# ⚠ THE SEQUENCE IS BUILT SO THAT NOTHING ELSE CAN HAVE PUBLISHED. The cursor is
# positioned BEFORE any raw exists, so `xschem set cursor2_x` -- which stays
# ungated on purpose, see this section's header and row V25 -- resolves against
# nothing and publishes nothing. The only publisher left in the sequence is
# raw_read's own tail.
# ⚠ LEG 2 IS THE POSITIVE CONTROL AND IS NOT OPTIONAL. A gate that reds nothing
# when it is removed is not a gate, and a gate that also silenced the TICKED box
# would delete the shipped live-annotate feature while every negative row above
# stayed green.
foreach {v_box v_tag} {0 off 1 on} {
  set ::live_cursor2_backannotate $v_box
  catch {xschem raw clear} ; catch {xschem cursor 1 0} ; catch {xschem cursor 2 0}
  xschem load [file join $lib s5_flat.sch]
  opa_l_annot 0
  opa_t_graph 1
  xschem cursor 2 1
  xschem set cursor2_x 4e-9
  set v22_pre($v_tag) [opa_t_annot]
  set v22_rc($v_tag)  [rcall [list xschem raw read $V_RAW tran]]
  set v22_an($v_tag)  [opa_t_annot]
  set v22_pt($v_tag)  [opa_v_paint g1$v_tag 2]
  opa_l_annot 0
}
set ::live_cursor2_backannotate $V_LV
check {V22 guard G1 FIXTURE: the cursor was positioned before any database existed, so nothing had published} \
  [list $v22_pre(off) $v22_pre(on) $v22_rc(off) $v22_rc(on)] \
  [list {RAISED:No raw file loaded} {RAISED:No raw file loaded} {0 1} {0 1}]
check {V22 guard G1 LOADING a transient publishes NOTHING with the Live-annotate box off, and still publishes with it on} \
  [list $v22_an(off) $v22_pt(off) $v22_an(on) $v22_pt(on)] \
  [list {-1 0 -1} $V_PINS_NONE {3 4e-09 0} $V_PINS_P4]

# ===========================================================================
# V23 — GUARD G2, BEHAVIOURAL, BOTH LEGS: DESCENDING IS NOT A REQUEST EITHER
# ===========================================================================
# descend_schematic()'s tail (src/actions.c:4814) is the second acquisition door:
# walk into a child that happens to carry a graph rect and the child's sheet
# acquires an annotation, box or no box. Measured today, both legs identical:
# annot goes from -1 0 -1 to 0 4e-09 0 at the descend.
# ⚠ THE PARENT CARRIES NO GRAPH, so the raw read at the parent level cannot fire
# guard G1's site and the ONLY publisher in the sequence is the descend.
# ⚠ THE MEASURE IS `raw annot`, NOT PAINT. At the child level the lab_pin `d`
# resolves to the hierarchical node `x1.d`, which is not a vector in this raw, so
# both legs paint a blank either way and paint cannot discriminate. The published
# annotation can.
set f [open [file join $lib v_leaf.sym] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}
close $f
set f [open [file join $lib v_parent.sch] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
C {v_leaf.sym} 120 0 0 0 {name=x1}}
close $f
set f [open [file join $lib v_leaf.sch] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
B 2 0 -400 800 0 {flags=graph
node="v(d)"
x1=0
x2=5e-9
y1=-1
y2=5}
C {sky130_fd_pr/nfet_01v8.sym} 0 0 0 0 {name=M1 W=1 L=0.15 nf=1}
C {lab_pin.sym} 20 -30 0 0 {name=p1 lab=d}}
close $f
foreach {v_box v_tag} {0 off 1 on} {
  set ::live_cursor2_backannotate $v_box
  catch {xschem raw clear} ; catch {xschem cursor 1 0} ; catch {xschem cursor 2 0}
  catch {unset ::ngspice::ngspice_data}
  xschem load [file join $lib v_parent.sch]
  opa_l_annot 0
  xschem cursor 2 1
  xschem set cursor2_x 4e-9
  catch {xschem raw read $V_RAW tran}
  catch {unset ::ngspice::ngspice_data}
  set v23_top($v_tag) [list [xschem get rects 2] [opa_t_annot]]
  xschem unselect_all ; xschem select instance 0 fast nodraw ; xschem descend 1 2
  set v23_kid($v_tag) [list [xschem get rects 2] [opa_t_annot]]
}
set ::live_cursor2_backannotate $V_LV
check {V23 guard G2 FIXTURE: the parent carries no graph and nothing was published there, and the child does carry one} \
  [list $v23_top(off) $v23_top(on) [lindex $v23_kid(off) 0] [lindex $v23_kid(on) 0]] \
  [list {0 {-1 0 -1}} {0 {-1 0 -1}} 1 1]
# ⚠ THE ON LEG PINS annot_x AND THE SWEEP, NOT annot_p, AND THAT IS ISSUE 0480
# RATHER THAN A WEAKENING. The descended graph borrows the SHARED
# xctx->graph_struct, which still holds whatever window the last fullyzoom'd rect
# in this process left there -- measured, the same fixture answers annot_p 0 in a
# standalone process and annot_p 3 here, purely from that leftover. The point
# index is 0480's subject; whether anything was published AT THE REQUESTED TIME
# is this row's, and `>= 0` versus -1 is the whole discrimination.
check {V23 guard G2 DESCENDING into a child that carries a graph publishes NOTHING with the box off, and still publishes with it on} \
  [list [lindex $v23_kid(off) 1] \
        [expr {[lindex $v23_kid(on) 1 0] >= 0 ? 1 : 0}] \
        [lrange [lindex $v23_kid(on) 1] 1 2]] \
  [list {-1 0 -1} 1 {4e-09 0}]

# ===========================================================================
# V23b — GUARD G2, STRUCTURAL, AND IT IS NOT OPTIONAL
# ===========================================================================
# ⚠ V23's BEHAVIOURAL LEG CAN BE SHADOWED. The whole block it measures sits
# behind `tcleval("info exists ngspice::ngspice_data")[0] == '0'`, so a fixture
# that left that array set would make V23 pass over an ungated site. The
# structural row holds the gate whatever the array is doing.
# ⚠ C COMMENTS ARE STRIPPED FIRST -- the guard's own explanatory comment names
# the switch, and a body grep that counted it would be green over a deleted test.
# ⚠ AND THE SPELLING IS PINNED: the six already-gated re-annotate sites all say
# `tclgetboolvar("live_cursor2_backannotate")`, so a grep finds ONE gate shape.
set V_ACT {}
if {![catch {open [file join $repo src actions.c] r} _vfh]} { set V_ACT [read $_vfh] ; close $_vfh }
regsub -all {/\*.*?\*/} $V_ACT {} V_ACT_NC
set V_DESC {}
if {[regexp {\nint descend_schematic\(.*?\n\}\n} "\n$V_ACT_NC" V_DESC]} { }
set v23b 0
foreach _l [split $V_DESC \n] {
  if {[regexp {tclgetboolvar\("live_cursor2_backannotate"\)} $_l]} { incr v23b }
}
check {V23b guard G2 STRUCTURAL descend_schematic's body, C comments stripped, tests the Live-annotate switch exactly once} \
  [list [expr {[string length $V_DESC] > 200 ? 1 : 0}] $v23b] {1 1}

# ===========================================================================
# V24 — THE 0865 REPRODUCER, END TO END. THE ITEM'S ACCEPTANCE
# ===========================================================================
# ⚠ THIS IS THE TRANSCRIPT IN THE ISSUE, AS FOUR PAINTED LISTS. The user's own
# sequence, with the Live-annotate box in its shipped unticked state:
#   1. load the waveform file                     -> measured today: d 4 is
#      ALREADY acquired, before any key is pressed
#   2. Alt-6                                      -> d 4
#   3. move cursor B (swap_cursors puts it at 0)  -> STILL d 4, and v(d) at
#      cursor B is now 0. RULING D5-1.
#   4. Ctrl-6                                     -> cleared
# After guards G1 and G2 nothing paints at any step, because nothing was
# requested at any step. The user's door is the new mode, and rows V11-V13 are
# where that door is measured.
# ⚠ THE FOURTH ELEMENT IS THE ANTI-HOLLOW HALF. "Nothing is painted" is
# satisfied by a fixture whose text never appeared at all; step 4 is the same
# blank as step 1, and rows V22 leg 2 and V9 are what say the exporter can render
# these floaters when something IS published.
# ⚠ AND AFTER THE 0872 FIX, STEP 2 IS BLANK FOR A SECOND REASON — DO NOT READ
# THIS ROW AS EVIDENCE FOR EITHER ONE. The fixture is a TRANSIENT database, so
# `cadence::annot_mode opvolt` now REFUSES it outright (ruling 0856) and returns
# before the mask is written; step 2 would be blank even if something had been
# published. The row still measures what it was written to measure -- nothing
# stale reaches the sheet -- but the discrimination between "nothing was
# published" and "the chord refused" lives in row V31, which plants a held
# sentinel and reads the mask at every press. A future edit that made
# annot_mode a no-op everywhere would leave V24 green.
set ::live_cursor2_backannotate 0
catch {xschem raw clear} ; catch {xschem cursor 1 0} ; catch {xschem cursor 2 0}
xschem load [file join $lib s5_flat.sch]
opa_l_annot 0
opa_t_graph 1
xschem cursor 2 1
xschem set cursor2_x 4e-9
xschem raw read $V_RAW tran
set v24a [opa_v_paint r1]
catch {cadence::annot_mode opvolt}
set v24b [opa_v_paint r2]
xschem swap_cursors
set v24c [opa_v_paint r3]
catch {cadence::annot_mode none}
set v24d [opa_v_paint r4]
set ::live_cursor2_backannotate $V_LV
check {V24 ISSUE 0865 END TO END with the box off: load, Alt-6, move cursor B, Ctrl-6 -- nothing stale is painted at any step} \
  [list $v24a $v24b $v24c $v24d] \
  [list $V_PINS_NONE $V_PINS_NONE $V_PINS_NONE $V_PINS_NONE]

# ===========================================================================
# V25 — THE RECORDED DECISION'S PIN (issue 0868). GREEN BEFORE AND AFTER
# ===========================================================================
# ⚠ READ THIS ROW'S NAME BEFORE "FIXING" IT. Issue 0865's ruling says gate every
# ungated publisher on the Live-annotate box. Two of the four are gated by this
# item -- loading waves and descending. The other two, both arms of `xschem set
# cursor2_x`, are LEFT PUBLISHING ON PURPOSE, and this row is that decision
# written down where a later crew will meet it.
# The reasons are in this section's header; the shortest of them is that
# `xschem set cursor2_x <t>` is a sentence somebody TYPED, naming a time, which
# is what "only when the user requests it" means, and that it is driven 43 times
# across five suites of which three never mention the box.
# ⚠ BOTH ARMS. scheduler.c:12112 is the graph-present arm and :12123 is the
# no-graph arm that neither issue 0865 nor the item brief lists at all.
set ::live_cursor2_backannotate 0
opa_t_arm [file join $lib s5_flat.sch]
xschem cursor 2 1
xschem set cursor2_x 3e-9
set v25_nograph [list [xschem get rects 2] [opa_t_annot]]
opa_t_arm [file join $lib s5_flat.sch]
opa_t_graph 1
xschem cursor 2 1
xschem set cursor2_x 3e-9
set v25_graph [list [xschem get rects 2] [opa_t_annot]]
set ::live_cursor2_backannotate $V_LV
check {V25 issue 0868 DELIBERATE: with the box off `xschem set cursor2_x` still publishes, in BOTH arms -- it is a typed request} \
  [list $v25_nograph $v25_graph] [list {0 {2 3e-09 0}} {1 {2 3e-09 0}}]

# ===========================================================================
# V26 .. V32 — THE A3 HARDENING PASS (issues 0869, 0872, 0873, 0874/0876)
# ===========================================================================
# Everything below is new with the hardening item. Four defects were filed by
# the crew that landed the mode and left unfixed; these are the rows that see
# them. The goldens are MEASURED on the committed binary, and each row's own
# header says whether it is red today or is a control that must never move.
#
# ⚠ THE THREE EXTRA GOLDEN SENTENCES, beside V17's five. V_MSG_CLAMP is NEW
# WORDING the user has not ratified -- it is owed as a `rule` debt against
# issue 0869 and must not be re-worded here without clearing that debt.
set V_MSG_OK2   {Showing each node's voltage at 2 ns, where cursor B is on the waveform.}
set V_MSG_OK3   {Showing each node's voltage at 3 ns, where cursor B is on the waveform.}
set V_MSG_CLAMP {Cursor B is at 4.5 ns, outside the time range of the run. Showing each node's voltage at 4 ns, the closest point that was actually measured.}
## ⚠ ISSUE 0857's SENTENCE, AND THE USER RULED IT ON 2026-08-27, VERBATIM:
## "Yes, 6 does nothing when there is ONLY a TRAN result. But, it's a good idea
## to say 'No OP results available' in the CIW." So the two silent returns of
## `cadence::annot_mode` -- the one at the top and the one inside the 0872
## unwind -- stop being mute. The wording is NEW and the user has not ratified
## it (a `rule` debt); the user's own opening clause is kept and a next step is
## added, per the PLAIN ENGLISH ruling of the same day. Two shapes, ONE arm of
## `cadence::_annot_msg` (RULING D5-4): the analysis type is named when the
## attached database can say what it is, and left out when it cannot.
## ⚠ NO "OP annotation ON/OFF (...)" PREFIX. On both refusal paths the mask is
## never written, or is written and restored, so a prefix would be a sentence
## making a claim about a screen that did not change -- RULING D5-1's shape.
set V_MSG_NOTOP_TRAN {No operating point results are loaded. These are from a 'tran' run instead, so there are no operating-point numbers to show. Run an operating point analysis, or press Alt-Shift-6 for node voltages at the waveform cursor.}
set V_MSG_NOTOP_BARE {No operating point results are loaded. The results loaded here are not an operating point, so there are no operating-point numbers to show. Run an operating point analysis, or press Alt-Shift-6 for node voltages at the waveform cursor.}
## The lab_pin tail over the OPERATING POINT fixture of section T. Measured: the
## `d` node carries 7.5 and `g` is not a vector in that raw, so it renders the
## I3 placeholder rather than a number.
set V_PINS_OP   {d 7.5 g - 0 0.0 0 0.0}

## THE TIME THE PAINTED NUMBER WAS ACTUALLY MEASURED AT, through three shipped
## calls and no C change: `xschem raw annot` names the annotated point and which
## column is the sweep, `xschem raw list` names the columns, and
## `xschem raw value <sweep> -1` reads the sweep's own value at that point.
## ⚠ NEVER A BARE CATCH, for this file's standing reason: with nothing published
## a caught raise reported as an empty string would make "the boundary held" and
## "the accessor is broken" the same answer.
proc opa_v_efft {} {
  set a [opa_t_annot]
  if {[llength $a] != 3} { return "NO-ANNOT:$a" }
  if {![string is integer -strict [lindex $a 0]]} { return "NO-ANNOT:$a" }
  if {[lindex $a 0] < 0} { return "NOT-PUBLISHED" }
  set r [rcall {xschem raw list}]
  if {[lindex $r 0] != 0} { return "RAISED:[lindex $r 1]" }
  set names [split [lindex $r 1] "\n"]
  set sw [lindex $names [lindex $a 2]]
  if {$sw eq {}} { return "NO-SWEEP-NAME" }
  set v [rcall [list xschem raw value $sw -1]]
  if {[lindex $v 0] != 0} { return "RAISED:[lindex $v 1]" }
  return [lindex $v 1]
}

## The CIW sink, spied. Same shape as w_aecho_spy in
## tests/headless/test_ase_window.tcl -- save the shipped emitter, install a
## recorder, restore whatever happens. Returns the list of tag/message pairs.
proc opa_v_spy {script} {
  set ::opa_v_echo {}
  namespace eval ::ase {}
  set had [expr {[info commands ::ase::echo] ne {}}]
  if {$had} { rename ::ase::echo ::opa_v_saved_echo }
  proc ::ase::echo {msg {tag {}}} { lappend ::opa_v_echo [list $tag $msg] ; return 1 }
  catch {uplevel 1 $script}
  catch {rename ::ase::echo {}}
  if {$had} { rename ::opa_v_saved_echo ::ase::echo }
  return $::opa_v_echo
}

## Drive `cadence::_annot_ciw` with BOTH sinks under control, and report
## its rc plus how many times each sink was reached.
proc opa_v_emit {mode} {
  set ::opa_v_ne 0 ; set ::opa_v_nn 0
  namespace eval ::ase {}
  namespace eval ::xschem {}
  set had_e [expr {[info commands ::ase::echo] ne {}}]
  set had_n [expr {[info commands ::xschem::notify] ne {}}]
  if {$had_e} { rename ::ase::echo ::opa_v_sav_e }
  if {$had_n} { rename ::xschem::notify ::opa_v_sav_n }
  switch -exact -- $mode {
    bothok  { proc ::ase::echo {msg {tag {}}} { incr ::opa_v_ne ; return 1 }
              proc ::xschem::notify {msg} { incr ::opa_v_nn ; return 1 } }
    echobad { proc ::ase::echo {msg {tag {}}} { incr ::opa_v_ne ; error ZZBAD }
              proc ::xschem::notify {msg} { incr ::opa_v_nn ; return 1 } }
    bothbad { proc ::ase::echo {msg {tag {}}} { incr ::opa_v_ne ; error ZZBAD }
              proc ::xschem::notify {msg} { incr ::opa_v_nn ; error ZZBAD } }
    default { error "opa_v_emit: unknown mode $mode" }
  }
  set r [rcall {cadence::_annot_ciw ZZ0873PROBE}]
  catch {rename ::ase::echo {}}
  catch {rename ::xschem::notify {}}
  if {$had_e} { rename ::opa_v_sav_e ::ase::echo }
  if {$had_n} { rename ::opa_v_sav_n ::xschem::notify }
  return [list $r $::opa_v_ne $::opa_v_nn]
}

# ===========================================================================
# V26 — ISSUE 0869, THE COMPOSING ROW. RED TODAY
# ===========================================================================
# ⚠ THIS IS THE ROW WHOSE ABSENCE SHIPPED THE DEFECT, and the gap was exact:
# V4 measures the boundary PAINT with no sentence, V17 measures the sentence
# with no data, and NOTHING composed them. So a sentence that named a time the
# number was never measured at passed every row in the file.
# The last sample is 4e-09 and cursor B is parked at 4.5e-09. RULING D4-4 says a
# boundary HOLDS and never extrapolates, so painting 4 is CORRECT; the defect is
# the label. Measured on the committed binary the sheet paints `d 4` beside
# "Transient annotation at t = 4.5e-09 (cursor B)" -- a number presented as
# measured for a time it was not measured at, which is RULING D5-1 in its purest
# form, and worse than a bare wrong number because the sentence lends authority.
# Four claims in one row: the state, the PAINT, the time the number was ACTUALLY
# measured at, and the sentence the user reads.
# ⚠ THE PAINT IS AN SVG EXPORT, NEVER `xschem translate` -- FAQ Q52.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 4.5e-9
opa_v_rearm
set v26_state [opa_v_tran]
set v26_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v26_efft  [opa_v_efft]
set v26_paint [opa_v_paint clamp]
check {V26 issue 0869 RULING D5-1 out of range the sentence names the time the number was MEASURED at, not the cursor's} \
  [list $v26_state $v26_paint $v26_efft $v26_msg] \
  [list ok $V_PINS_P4 4e-09 $V_MSG_CLAMP]

# ===========================================================================
# V26b — THE IN-RANGE CONTROL. GREEN BEFORE AND AFTER, AND NOT OPTIONAL
# ===========================================================================
# ⚠ WITHOUT THIS ROW A FIX THAT APPENDED THE CLAUSE UNCONDITIONALLY PASSES V26,
# and every user with an in-range cursor is told their cursor is outside the
# data. In range the shipped arithmetic genuinely returns the value AT the
# requested time -- row V2 measures exactly that at 2.5 ns -- so the requested
# and the measured time are the same number and the sentence must stay the
# SHIPPED one, byte for byte.
# ⚠ AND IT IS THE ROW THAT REDS ISSUE 0869's OWN RECOMMENDED OPTION 1. That
# option renders the annotated sample's own x unconditionally; measured over
# this fixture it answers 2e-09 for a requested 3e-09 whose painted number is
# genuinely the value at 3e-09 -- a fresh D5-1 breach in the opposite direction.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
opa_v_rearm
set v26b_state [opa_v_tran]
set v26b_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v26b_efft  [opa_v_efft]
set v26b_paint [opa_v_paint inrange]
check {V26b CONTROL in range the requested and the measured time are the same, and the sentence is the SHIPPED one byte for byte} \
  [list $v26b_state $v26b_paint $v26b_efft $v26b_msg] \
  [list ok $V_PINS_P3 3e-09 $V_MSG_OK3]

# ===========================================================================
# V27 — THE SIXTH GOLDEN, BESIDE V17'S FIVE. RED TODAY
# ===========================================================================
# ⚠ V17 IS LEFT UNTOUCHED SO ITS DIFF STAYS CLEAN, and the five shipped
# sentences are RE-ASSERTED here through the widened signature, called with
# three arguments exactly as every shipped caller calls them. That is the half
# that says a new optional parameter did not move the five.
# Measured on the committed binary the four-argument call raises
# `wrong # args: should be "cadence::_annot_tran_msg state t which"`, so this
# row is red for the mint not existing rather than for its wording.
# ⚠ ONE MINT, RULING D5-4. The clamped sentence is a SIXTH state of the same
# emitter, not a second string composed at a call site; row V18's one-file grep
# is what holds that, and it does not move.
check {V27 RULING D5-4 the clamped sentence is a SIXTH state of the one mint, and the five shipped ones do not move} \
  [list [rcall {cadence::_annot_tran_msg okclamped 4e-09 B 4.5e-09}] \
        [rcall {cadence::_annot_tran_msg ok 1e-09 A}] \
        [rcall {cadence::_annot_tran_msg nocursor {} {}}] \
        [rcall {cadence::_annot_tran_msg noraw {} {}}] \
        [rcall {cadence::_annot_tran_msg notran {} {}}] \
        [rcall {cadence::_annot_tran_msg nodata 3e-09 B}]] \
  [list [list 0 $V_MSG_CLAMP] [list 0 $V_MSG_OK] [list 0 $V_MSG_NOCURSOR] \
        [list 0 $V_MSG_NORAW] [list 0 $V_MSG_NOTRAN] [list 0 $V_MSG_NODATA]]

# ===========================================================================
# V28 — ISSUE 0873: THE `ok` SENTENCE IS SPOKEN, ON BOTH SINKS
# ===========================================================================
# ⚠ GREEN TODAY AND THAT IS THE POINT -- the channel works, nothing pins it.
# Measured by the hardening crew: with the CIW emitter neutered AND the held
# status line swallowed, the mode goes COMPLETELY MUTE and all 651 checks across
# test_op_annot, test_annot_show_menu and test_ase_window still pass. So the row
# has to pin BOTH sinks; a row that only spied the CIW would still pass if a
# later edit dropped the status line, and a row that only read the status line
# would still pass if the CIW route were deleted.
# ⚠ THE TAG IS PART OF THE CLAIM. A success carries NO tag; the three refusals
# below carry `warn`. A build that shouted every sentence as a warning would
# pass a row that only compared the text.
# ⚠ THE HOLD FLAG IS PART OF IT TOO. Issue 0248: without the hold, pointer
# motion erases the line before the user has read it, and the number stays on
# the sheet with nothing left saying what it was measured at.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 2e-9
opa_v_rearm
catch {xschem statusmsg -hold ZZ0873SENTINEL}
set v28_spy  [opa_v_spy {set ::v28_state [opa_v_tran]}]
set v28_msg  [lindex [rcall {xschem get statusmsg}] 1]
set v28_hold [lindex [rcall {xschem get statusmsg_hold}] 1]
check {V28 issue 0873 the `ok` sentence reaches the CIW untagged AND the held status line, once each} \
  [list $::v28_state [llength $v28_spy] [lindex $v28_spy 0 0] [lindex $v28_spy 0 1] \
        $v28_msg $v28_hold] \
  [list ok 1 {} $V_MSG_OK2 $V_MSG_OK2 1]

# ===========================================================================
# V29 — ISSUE 0873: THE THREE REACHABLE REFUSALS ARE SPOKEN, TAGGED `warn`
# ===========================================================================
# ⚠ THREE, NOT FOUR, AND THE MISSING ONE IS DELIBERATE. Issue 0871: `nodata` is
# UNREACHABLE, because `xschem raw loaded` and the engine's own gate are the
# same predicate -- so V17 pins a fifth sentence no user can be shown. Covering
# it behaviourally would need a fixture that cannot exist; naming that here is
# the honest alternative to a row that quietly tests four states and can only
# ever exercise three.
# Rows V14, V15 and V16 already assert that each refusal publishes nothing and
# arms no bit. This row asserts the other half the user actually experiences:
# that the program SAYS which of the three happened, in both places, rather than
# doing nothing silently -- issue 0857's ruling, applied to this mode.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 0
catch {xschem statusmsg -hold ZZ0873SENTINEL}
set v29a  [opa_v_spy {set ::v29a_state [opa_v_tran]}]
set v29am [lindex [rcall {xschem get statusmsg}] 1]
set v29ah [lindex [rcall {xschem get statusmsg_hold}] 1]
## The empty `netlist_dir`, for row V15's reason: after issue 0881 this leg's
## `noraw` is only reachable when there is no candidate ON DISK either.
set v29_nd $::netlist_dir
set ::netlist_dir $V_ND_NONE
opa_l_annot 0
catch {xschem raw clear}
xschem cursor 2 1
xschem set cursor2_x 4e-9
catch {xschem statusmsg -hold ZZ0873SENTINEL}
set v29b  [opa_v_spy {set ::v29b_state [opa_v_tran]}]
set v29bm [lindex [rcall {xschem get statusmsg}] 1]
set v29bh [lindex [rcall {xschem get statusmsg_hold}] 1]
set ::netlist_dir $v29_nd
opa_l_annot 0
catch {xschem raw clear}
xschem raw read $T_OPRAW op
xschem cursor 2 1
catch {xschem statusmsg -hold ZZ0873SENTINEL}
set v29c  [opa_v_spy {set ::v29c_state [opa_v_tran]}]
set v29cm [lindex [rcall {xschem get statusmsg}] 1]
set v29ch [lindex [rcall {xschem get statusmsg_hold}] 1]
catch {xschem raw clear}
check {V29 issue 0873 nocursor, noraw and notran each reach the CIW tagged `warn` AND the held status line} \
  [list $::v29a_state $v29a $v29am $v29ah \
        $::v29b_state $v29b $v29bm $v29bh \
        $::v29c_state $v29c $v29cm $v29ch] \
  [list nocursor [list [list warn $V_MSG_NOCURSOR]] $V_MSG_NOCURSOR 1 \
        noraw    [list [list warn $V_MSG_NORAW]]    $V_MSG_NORAW    1 \
        notran   [list [list warn $V_MSG_NOTRAN]]   $V_MSG_NOTRAN   1]

# ===========================================================================
# V30 — ISSUE 0873: THE EMITTER'S OWN CLAIM, MADE FALSIFIABLE
# ===========================================================================
# ⚠ `cadence::_annot_ciw`'s comment says the sinks are tried IN ORDER and the
# last one always works, and nothing in the tree tested that sentence. It is not
# decoration: issue 0857 is about a chord that says nothing when it cannot
# deliver, so a catch-and-discard emitter would reproduce the defect precisely
# on the sessions where the CIW is not up.
# Three legs, and the middle one is the whole subject: when the CIW route
# RAISES, the message must still land, on the fallback.
#   bothok  -> rc 1, the CIW got it, the fallback was never asked
#   echobad -> rc 1, the CIW was tried and failed, the fallback got it
#   bothbad -> rc 0, both were tried, and the emitter does NOT raise at its own
#              caller. The stderr line it writes as a last resort is expected
#              output, not a fault.
check {V30 issue 0873 the emitter tries the sinks in order, falls through when one raises and never raises itself} \
  [list [opa_v_emit bothok] [opa_v_emit echobad] [opa_v_emit bothbad]] \
  [list {{0 1} 1 0} {{0 1} 1 1} {{0 0} 1 1}]

# ===========================================================================
# V31 — ISSUE 0872: RULING 0856 APPLIED TO THE OP CHORDS. RED TODAY
# ===========================================================================
# ⚠ THE USER'S RULING, VERBATIM: "if OP is part of the run, then plot from OP.
# We haven't yet built anything for annotating from TRAN results, so it should
# do nothing silently." Commit e31975e7 made the OPERATING POINT publisher obey
# it. The mode chooser does not: measured on the committed binary, on a
# transient database, Ctrl-6 clears and then Alt-6 puts the transient's `d 3`
# back on the sheet under the status line "OP annotation ON (node voltages)".
# ⚠ AND THE MECHANISM THE ISSUE NAMES IS WRONG. The crew blamed the shared
# render class -- the ANNOT_SHOW_VOLTAGE-or-ANNOT_SHOW_TRAN return in
# annot_class_mask. Measured with the transient mode never invoked and bit2
# never set, Alt-6 ALONE already does it, so that return is not in the chain at
# all in this direction. `cadence::annot_mode` flips a pure visibility switch
# without ever asking the database which analysis it holds, while its sibling
# `cadence::annot_tran` refuses the wrong analysis by name nine lines away.
# ⚠ LEG 5 IS THE FACE NO ISSUE FILE RECORDS AND IT IS THE WORST OF THEM. With a
# transient attached and NOTHING published, Alt-6 paints nothing but still
# SPEAKS, and what it says is impossible: it tells the user to run
# Waves > Op Annotate, which is exactly the operation the 0856 guard refuses on
# a transient. A fix that only gated the PAINT leaves that sentence standing,
# so every leg carries the status line and not just the mask.
# ⚠ LEGS 3, 4 AND 5 NO LONGER ASSERT SILENCE, AND THE USER IS WHY (item A10,
# issue 0857, ruled 2026-08-27): "Yes, 6 does nothing when there is ONLY a TRAN
# result. But, it's a good idea to say 'No OP results available' in the CIW."
# So the press still publishes nothing and still arms no bit -- ruling 0856 is
# untouched, and every mask and every paint below is byte-identical -- but it
# now SAYS why instead of leaving the user with a key that appears dead. The
# held sentinel is replaced by the one sentence rather than deleted: a press
# that wrote nothing at all would leave the sentinel standing and red here,
# exactly as a press that wrote the wrong sentence would.
# ⚠ LEG 2 IS THE OFF SWITCH AND IT IS EXEMPT, ON PURPOSE. Ctrl-6 must always
# clear, and clearing never puts a number on a sheet. A refusal that swallowed
# Ctrl-6 would strand the user with bit2 armed and no way to turn it off, which
# is a worse defect than the one being fixed; this leg is that exemption's only
# guard.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
opa_v_rearm
set v31_1state [opa_v_tran]
set v31_1mask  [xschem get annot_show]
set v31_1paint [opa_v_paint c6arm]
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode none}
set v31_2mask  [xschem get annot_show]
set v31_2msg   [lindex [rcall {xschem get statusmsg}] 1]
set v31_2paint [opa_v_paint c6none]
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode opvolt}
set v31_3mask  [xschem get annot_show]
set v31_3msg   [lindex [rcall {xschem get statusmsg}] 1]
set v31_3paint [opa_v_paint c6alt]
opa_l_annot 0
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode op}
set v31_4mask  [xschem get annot_show]
set v31_4msg   [lindex [rcall {xschem get statusmsg}] 1]
set v31_4paint [opa_v_paint c6op]
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 0
set v31_5pre   [opa_t_annot]
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode opvolt}
set v31_5mask  [xschem get annot_show]
set v31_5msg   [lindex [rcall {xschem get statusmsg}] 1]
set v31_5paint [opa_v_paint c6facec]
check {V31 issue 0872 RULING 0856 on a TRANSIENT sheet Alt-6 and 6 publish nothing and SAY WHY (issue 0857), and Ctrl-6 still clears} \
  [list $v31_1state $v31_1mask $v31_1paint \
        $v31_2mask $v31_2msg $v31_2paint \
        $v31_3mask $v31_3msg $v31_3paint \
        $v31_4mask $v31_4msg $v31_4paint \
        $v31_5pre $v31_5mask $v31_5msg $v31_5paint] \
  [list ok 4 $V_PINS_P3 \
        0 $A11_M0 $V_PINS_NONE \
        0 $V_MSG_NOTOP_TRAN $V_PINS_NONE \
        0 $V_MSG_NOTOP_TRAN $V_PINS_NONE \
        {-1 0 -1} 0 $V_MSG_NOTOP_TRAN $V_PINS_NONE]

# ===========================================================================
# V31b — THE POSITIVE CONTROL. GREEN BEFORE AND AFTER, AND NOT OPTIONAL
# ===========================================================================
# ⚠ WITHOUT THIS ROW A FIX THAT TURNED THE MODE CHOOSER INTO A NO-OP EVERYWHERE
# PASSES V31, and the two shipped OP chords are dead. Both legs are the ones
# that must keep working:
#   leg 1  an OPERATING POINT database is attached -- Alt-6 arms bit1, the
#          operating point's own 7.5 reaches the sheet, and the status line says
#          so. This is the surface the whole feature exists for.
#   leg 2  NOTHING is attached -- `6` still runs the candidate search, still
#          arms bit0 and still speaks. A refusal keyed on "the database is not
#          op" must not swallow the case where there is no database to ask, or
#          the chord stops being able to FIND a raw at all.
# ⚠ THE PATH IN LEG 2's SENTENCE IS SCRATCH-DEPENDENT, so it is matched by shape
# rather than goldened -- the claim is that the chord still names a file, not
# which temporary directory this run used.
opa_l_annot 0
catch {xschem raw clear}
xschem load [file join $lib s5_flat.sch]
catch {xschem annotate_op $T_OPRAW}
set v31b_st [rcall {xschem raw sim_type}]
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode opvolt}
set v31b_mask  [xschem get annot_show]
set v31b_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v31b_paint [opa_v_paint opdb]
opa_l_annot 0
catch {xschem raw clear}
xschem load [file join $lib s5_flat.sch]
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode op}
set v31b2_mask [xschem get annot_show]
set v31b2_ld   [rcall {xschem raw loaded}]
set v31b2_msg  [lindex [rcall {xschem get statusmsg}] 1]
opa_l_annot 0
check {V31b CONTROL an OPERATING POINT database still annotates on Alt-6, and with NO database `6` still searches and still speaks} \
  [list $v31b_st $v31b_mask $v31b_paint $v31b_msg \
        $v31b2_mask $v31b2_ld \
        [string match "$A11_M1 There is no results file at *" $v31b2_msg]] \
  [list {0 op} 2 $V_PINS_OP "$A11_M2$A11_LIVE" \
        1 {0 -1} 1]

# ===========================================================================
# V31c — ISSUE 0872, THE FACE V31 CANNOT REACH. RED BEFORE THIS REPAIR
# ===========================================================================
# ⚠ THE GAP WAS THE SAME SHAPE THE DEFECT ITSELF HAD, ONE LAYER UP. V31
# exercises the refusal only with a database ALREADY ATTACHED -- every leg
# starts from opa_t_arm or a raw clear plus annotate_op. V31b leg 2 exercises
# the candidate search only with NO raw ON DISK. Nothing composed them, and the
# composition is the ordinary desktop state: a `.tran` was just run, so
# `$netlist_dir/<cell>.raw` exists and is a transient, and nothing is attached
# yet because the waveform viewer has not been opened. Measured before the
# repair, ONE Alt-6 from there wrote mask 2, attached the transient and said
# "OP annotation ON -- loaded <that transient>", which is RULING 0856 breached
# from the most ordinary state there is, and the 410-check suite was green.
# ⚠ WHY THE FIRST GATE CANNOT SEE IT. `cadence::_annot_op_db_ok` deliberately
# answers yes with nothing attached, so that `6` can still go and find a file
# -- V31b leg 2 is that decision's guard. The search then runs and loads a
# transient ITSELF, after the one and only ask. The repair asks a SECOND time,
# after the load, and unwinds.
# ⚠ update_op()'s GUARD IS NOT A BACKSTOP FOR THIS, and leg 4 is the proof.
# That guard only declines to PUBLISH the operating point; leg 4 puts a
# waveform strip with cursor B parked on the sheet, and raw_read()'s own tail
# gate then publishes the transient's sample at cursor B on the very load the
# chord performed. Before the repair leg 4 painted `d 3` under a status line
# calling it OP node voltages -- RULING D5-1 with the sentence lending it
# authority.
# ⚠ LEG 3 IS THE `$cur` HALF. The unwind restores the mask the USER had, not a
# bare 0: a press that cannot do its job must not clear bits the press did not
# set. It starts at mask 1 and must end at mask 1.
# ⚠ ONLY THE STATUS LINE MOVED WITH ITEM A10, AND DELIBERATELY SO. The mask,
# the `xschem raw loaded` readback, the paint and leg 4's
# `RAISED:No raw file loaded` are byte-for-byte what they were, so deleting the
# unwind body still reddens this row on all four of them -- that is PART 2 of
# the A10 brief, and sabotage S18 is the check of it. What changed is that the
# unwound press now SAYS what happened (issue 0857, ruled 2026-08-27) instead
# of leaving the planted sentinel standing.
# ⚠ THE UNWIND DETACHES THE DATABASE TOO, and every leg asserts it. Leaving a
# transient attached is not "nothing": the waveform viewer would hold data the
# user never loaded and cursor motion would start publishing from it. We only
# reach the search when nothing was attached, so the clear returns the session
# to exactly the state the key press found.
set V_ND_TRAN [file join $scratch v_nd_tran]
set V_ND_OP   [file join $scratch v_nd_op]
file mkdir $V_ND_TRAN ; file mkdir $V_ND_OP
file copy -force $T_RAW   [file join $V_ND_TRAN v_cand.raw]
file copy -force $T_OPRAW [file join $V_ND_OP   v_cand.raw]
file copy -force [file join $lib s5_flat.sch] [file join $lib v_cand.sch]
set v31c_nd $::netlist_dir
set ::netlist_dir $V_ND_TRAN

catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode opvolt}
set v31c_1 [list [xschem get annot_show] [rcall {xschem raw loaded}] \
                 [lindex [rcall {xschem get statusmsg}] 1] [opa_v_paint cand_alt]]

catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode op}
set v31c_2 [list [xschem get annot_show] [rcall {xschem raw loaded}] \
                 [lindex [rcall {xschem get statusmsg}] 1] [opa_v_paint cand_six]]

catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 1
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode opvolt}
set v31c_3 [list [xschem get annot_show] [rcall {xschem raw loaded}] \
                 [lindex [rcall {xschem get statusmsg}] 1] [opa_v_paint cand_cur]]

catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
opa_t_graph 1
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
## ⚠ THE BOX IS TICKED FOR THIS LEG, AND WITHOUT IT THE LEG IS A DECORATION.
## raw_read()'s tail gate (guard G1, src/save.c) is `live_cursor2_backannotate
## AND graph_flags & 4`, so with the shipped unticked state the load publishes
## nothing and the leg would pass with the repair reverted. Ticked, the chord's
## own load publishes the transient's sample at cursor B and the pre-repair
## sheet paints it -- measured under sabotage S18, this leg reads mask 2, the
## transient attached, `d 3` on the pins and the OP sentence over the top.
set ::live_cursor2_backannotate 1
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode opvolt}
set v31c_4 [list [xschem get annot_show] [rcall {xschem raw loaded}] \
                 [lindex [rcall {xschem get statusmsg}] 1] [opa_v_paint cand_graph] \
                 [opa_t_annot]]
set ::live_cursor2_backannotate $V_LV
catch {xschem cursor 2 0}
opa_l_annot 0
check {V31c issue 0872 RULING 0856 the chord's OWN candidate search must not attach a transient, paint from it or speak about it} \
  [list $v31c_1 $v31c_2 $v31c_3 $v31c_4] \
  [list [list 0 {0 -1} $V_MSG_NOTOP_TRAN $V_PINS_NONE] \
        [list 0 {0 -1} $V_MSG_NOTOP_TRAN $V_PINS_NONE] \
        [list 1 {0 -1} $V_MSG_NOTOP_TRAN $V_PINS_NONE] \
        [list 0 {0 -1} $V_MSG_NOTOP_TRAN $V_PINS_NONE {RAISED:No raw file loaded}]]

# ===========================================================================
# V31d — THE CANDIDATE SEARCH'S OWN POSITIVE CONTROL. GREEN BEFORE AND AFTER
# ===========================================================================
# ⚠ WITHOUT THIS ROW THE CHEAPEST FIX FOR V31c PASSES: refuse the candidate
# branch outright, or make the first gate say no whenever nothing is attached.
# Both leave `6` unable to FIND a raw at all, which is the whole reason the
# `loaded < 0` arm answers yes. V31b leg 2 covers the no-file-on-disk half;
# this covers the half that matters more -- the file IS there, it IS an
# operating point, and the chord must load it, arm the mask, put the operating
# point's own 7.5 on the sheet and NAME the file it loaded.
# The only difference from V31c is the analysis in the candidate file, so a
# refusal that cannot tell them apart reds here.
set ::netlist_dir $V_ND_OP
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
catch {xschem statusmsg -hold ZZ0872SENTINEL}
catch {cadence::annot_mode opvolt}
set v31d_mask [xschem get annot_show]
set v31d_ld   [rcall {xschem raw loaded}]
set v31d_st   [rcall {xschem raw sim_type}]
set v31d_msg  [lindex [rcall {xschem get statusmsg}] 1]
set v31d_paint [opa_v_paint cand_op]
opa_l_annot 0
catch {xschem raw clear}
set ::netlist_dir $v31c_nd
check {V31d CONTROL an OPERATING POINT at the SAME candidate path still loads, still arms, still paints and still names the file} \
  [list $v31d_mask $v31d_ld $v31d_st $v31d_paint \
        [string match "$A11_M2 Loaded results from *[file join $V_ND_OP v_cand.raw]." $v31d_msg]] \
  [list 2 {0 0} {0 op} $V_PINS_OP 1]

# ===========================================================================
# V32 — ISSUE 0874 / GUARD G6b: THE HIDE ARM, MADE VISIBLE
# ===========================================================================
# ⚠ THE GUARD NO ROW COULD SEE. `text_hidden()`'s explicit arm was widened from
# ANNOT_SHOW_VOLTAGE to ANNOT_SHOW_VOLTAGE-or-ANNOT_SHOW_TRAN when bit2 was
# added; the sabotage that put it back reddened NOTHING, so eight masks of
# behaviour rested on an untested line. This row is the discriminator, and it is
# behavioural rather than a source grep.
# The fixture is a SCHEMATIC-OWN text carrying `hide=voltage` -- not a symbol
# floater, and not a text carrying the annotation class -- so it reaches the
# hide arm and not `annot_class_mask`. Masks 4 and 5 are the whole
# discrimination: they are visible ONLY because the arm names bit2 as well.
# Measured on the committed binary: 0 0 1 1 1 1 1 1, exactly.
# ⚠ THE PLAIN TEXT IS THE ANTI-HOLLOW HALF. "Not visible" is satisfied by a
# fixture that never rendered at all, so a second text with no `hide` property
# is asserted VISIBLE at all eight masks. Without it the two leading zeros are
# indistinguishable from a broken export.
set f [open [file join $lib v_g6b.sch] w]
puts $f {v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
T {ZZG6BHIDDEN} 0 -100 0 0 0.2 0.2 {hide=voltage}
T {ZZG6BPLAIN} 0 -60 0 0 0.2 0.2 {}}
close $f
catch {xschem raw clear}
xschem load [file join $lib v_g6b.sch]
set v32h {} ; set v32p {}
foreach v32m {0 1 2 3 4 5 6 7} {
  opa_l_annot $v32m
  set v32svg [opa_l_print svg [file join $::scratch v_g6b_$v32m.svg] $::V_VP]
  lappend v32h [expr {[string first ZZG6BHIDDEN $v32svg] >= 0 ? 1 : 0}]
  lappend v32p [expr {[string first ZZG6BPLAIN  $v32svg] >= 0 ? 1 : 0}]
}
opa_l_annot 0
check {V32 issue 0874 guard G6b a schematic text hidden by `hide=voltage` reappears for bit2 as well as bit1, and a plain text never hides} \
  [list $v32h $v32p] [list {0 0 1 1 1 1 1 1} {1 1 1 1 1 1 1 1}]

# ===========================================================================
# V33 .. V44 — ITEM A10 / ISSUE 0881: THE SUPPLY THE MODE NEVER HAD, AND
#              ISSUE 0857's SENTENCE FOR THE TWO SILENT REFUSALS
# ===========================================================================
# ⚠ THE USER REPRODUCED THIS AT THEIR OWN BENCH, 2026-08-27, VERBATIM:
# "I do a TRAN run and then Alt-Shift-6 and Results > Annotate > Transient
#  Node.. don't annotate anything onto the schematic - yes, there is the
#  'Transient annotation -- NO RAW ..' message.. - bad. Given that results are
#  being loaded and plotted, we have enough info to satisfy user intent. The
#  ultimate goal of any UI is to satisfy user intent."
# and: "The info should already be available - it's been loaded to display
#  waveforms in the waveform viewer."
#
# ⚠ AND THE ROWS ARE WHY IT SHIPPED. Every row that covered the viewer-cursor
# path attached the database to the schematic context IN ITS OWN FIXTURE, so it
# manufactured a state the product never produces -- 413 checks here, 29 in
# tests/headless/test_annot_show_menu.tcl and a zero-failure run_regression.tcl
# were all consistent with the feature never having worked once. So the
# load-bearing rows below -- V33 and V34 -- HAND-ATTACH NOTHING. The results
# file sits where a run leaves it, or is attached to a DIFFERENT window through
# the proc the waveform viewer itself calls, and the annotation is then asked
# for from the schematic window exactly as the user asks for it.
#
# ⚠ HALF OF THE FEATURE ALREADY CROSSES THE WINDOW BOUNDARY CORRECTLY, and that
# is the measurement that says how small the fix is. The schematic window
# already reaches into the waveform viewer's window and reads the cursor
# sitting in its active tab -- row B12 of test_annot_show_menu.tcl is that
# borrow. Only the results lookup is blind. One asymmetry, not a missing
# feature.
#
#   V33   the ordinary post-run desktop: the run's results on disk, nothing
#         attached, and the mode supplies itself                 <- RED before
#   V34   the bench, headless twin: the results are attached to ANOTHER
#         window through ase::attach_dbs and the design window is empty
#                                                                <- RED before
#   V35   the ASE session's own file wins over the netlist_dir arm  <- RED
#   V35b  an OPERATING POINT reached through the same door is refused by name
#                                                                <- RED before
#   V36   stale results are named and NOT used, issue 0838's rule <- RED before
#   V37   a candidate that exists but will not parse is still `noraw` <- RED
#   V38   ORDERING: no cursor refuses BEFORE anything is attached  (green both)
#   V39   STRUCTURAL: one discovery mechanism, not two            <- RED before
#   V40   issue 0857 half 1: a transient already attached, `6` and `Alt-6` say
#         why, `Ctrl-6` still just clears                        <- RED before
#   V41   issue 0857 half 2: the 0872 unwind says why too         <- RED before
#   V42   the two new sentences, byte for byte                    <- RED before
#   V43   STRUCTURAL: RULING D5-4, minted in one file only        <- RED before
#   V44   WITNESS, issue 0882: a consequence of the fix, pinned so a later crew
#         has to confront it rather than discover it              <- RED before

## The session METADATA seam, stubbed for ONE script and always restored --
## section N's rename-in / rename-out technique. Only the three readers
## `cadence::_annot_raw_candidate` consults are replaced: which session owns
## this sheet, which file that session's last run wrote, and whether that file
## still describes the deck. NOTHING here attaches a database; the point of
## these rows is that the PRODUCT does the attaching.
proc opa_v_ase {rawfile stale script} {
  set ::opa_v_ase_raw   $rawfile
  set ::opa_v_ase_stale $stale
  namespace eval ase {}
  set h1 [expr {[info commands ::ase::session_for_current] ne {}}]
  set h2 [expr {[info commands ::ase::last_rawfile] ne {}}]
  set h3 [expr {[info commands ::ase::results_stale] ne {}}]
  if {$h1} { rename ::ase::session_for_current ::opa_v_sav_sfc }
  if {$h2} { rename ::ase::last_rawfile        ::opa_v_sav_lrf }
  if {$h3} { rename ::ase::results_stale       ::opa_v_sav_rst }
  proc ::ase::session_for_current {} { return [list zzA10key 0 zzlib zzcell schematic] }
  proc ::ase::last_rawfile {key} { return [expr {$key eq {zzA10key} ? $::opa_v_ase_raw : {}}] }
  proc ::ase::results_stale {key} { return $::opa_v_ase_stale }
  catch {uplevel 1 $script} r
  catch {rename ::ase::session_for_current {}}
  catch {rename ::ase::last_rawfile {}}
  catch {rename ::ase::results_stale {}}
  if {$h1} { rename ::opa_v_sav_sfc ::ase::session_for_current }
  if {$h2} { rename ::opa_v_sav_lrf ::ase::last_rawfile }
  if {$h3} { rename ::opa_v_sav_rst ::ase::results_stale }
  return $r
}

## Count the CODE lines of a proc body matching <re>, whole-line Tcl comments
## dropped -- so a header paragraph that names a proc is not counted as a call
## to it. Same discipline as opa_v_ngrep, applied to a sliced body.
proc opa_v_pgrep {body re} {
  set n 0
  foreach l [split $body \n] {
    if {[regexp {^\s*#} $l]} continue
    if {[regexp -- $re $l]} { incr n }
  }
  return $n
}

## The item's own fixtures. NONE of them is attached by hand anywhere below.
set V_A10_STALE   [file join $scratch v_a10_stale.raw]
set V_A10_SESS    [file join $scratch v_a10_sess.raw]
set V_A10_VSCH    [file join $lib v_a10_viewer.sch]
set V_ND_JUNK     [file join $scratch v_nd_junk]
file copy -force $T_RAW $V_A10_STALE
file copy -force $T_RAW $V_A10_SESS
file copy -force [file join $lib v_cand.sch] $V_A10_VSCH
file mkdir $V_ND_JUNK
set f [open [file join $V_ND_JUNK v_cand.raw] w]
puts $f {ZZ this file is not a spice raw database and never was}
close $f

## The sixth sentence of the transient mint. NEW WORDING the user has not
## ratified -- a `rule` debt -- and deliberately short, because the plain
## English pass the user ordered on 2026-08-27 is a separate item.
set V_MSG_STALERAW "The results file [file tail $V_A10_STALE] is older than the circuit it describes, so it was not used - it is from an earlier run. Run the simulation again, then try again."

set v33_nd $::netlist_dir

# ===========================================================================
# V33 — THE ORDINARY POST-RUN DESKTOP. NOTHING IS HAND-ATTACHED. RED BEFORE
# ===========================================================================
# ⚠ THIS IS ACCEPTANCE ROW 3 OF ISSUE 0881, HEADLESS HALF. A `.tran` has just
# been run, so the results sit at the shipped location every OP chord already
# resolves -- and NOTHING is attached to the sheet, because the user has not
# opened anything. The precondition is asserted first and separately: without
# it a row that passed because an earlier section left a database attached
# would be the same hollow row that hid this defect for a whole feature.
# Five claims: nothing was attached before the press; the mode published; it
# armed its own bit; the results really are attached afterwards; and the number
# reached the SHEET, measured through an SVG export -- never `xschem translate`,
# FAQ Q52.
set ::netlist_dir $V_ND_TRAN
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
set v33_pre   [rcall {xschem raw loaded}]
set v33_st    [opa_v_tran]
set v33_mask  [xschem get annot_show]
set v33_ld    [rcall {xschem raw loaded}]
set v33_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v33_paint [opa_v_paint a10_desktop]
opa_l_annot 0
catch {xschem raw clear}
check {V33 issue 0881 the ORDINARY POST-RUN DESKTOP nothing is hand-attached, the mode finds the run's own results and paints at the cursor} \
  [list $v33_pre $v33_st $v33_mask $v33_ld $v33_msg $v33_paint] \
  [list {0 -1} ok 4 {0 0} $V_MSG_OK3 $V_PINS_P3]

# ===========================================================================
# V34 — THE USER'S BENCH, HEADLESS TWIN. THE ROW THE ITEM EXISTS FOR. RED
# ===========================================================================
# ⚠ THE RAW IS ATTACHED TO A DIFFERENT WINDOW, THROUGH THE PRODUCT'S OWN PROC.
# `ase::attach_dbs` is exactly what `wviewer::attach_raw` calls after it has
# switched to the viewer's context (src/wave_viewer.tcl:3725), and it is what
# calls `xschem raw read`. So this row reproduces the bench state without Tk:
# the viewer's window holds the run's transient, the DESIGN window holds
# nothing at all, and the annotation is then asked for from the design window.
# ⚠ THE EMPTY DESIGN WINDOW IS ASSERTED, NOT ASSUMED. Two elements say it --
# `xschem raw loaded` is -1 and `xschem raw sim_type` RAISES -- because those
# are precisely the two reads `cadence::annot_tran` refuses on, and a row that
# did not pin them could pass on another row's leftovers.
# ⚠ AND THE CONTEXT COMES BACK. Every switch is deliberate and the last element
# is that the design window is current again at the end -- issue 0173's shape,
# from a path nobody would think to look at.
set ::netlist_dir $V_ND_TRAN
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 2e-9
set v34_wa [xschem get current_win_path]
catch {xschem new_schematic create {} $V_A10_VSCH}
set v34_wb [xschem get current_win_path]
set v34_att [rcall [list ase::attach_dbs [file join $V_ND_TRAN v_cand.raw] tran]]
set v34_vld [rcall {xschem raw loaded}]
set v34_vst [rcall {xschem raw sim_type}]
catch {xschem new_schematic switch $v34_wa}
set v34_back  [expr {[xschem get current_win_path] eq $v34_wa ? 1 : 0}]
set v34_dld   [rcall {xschem raw loaded}]
set v34_dst   [rcall {xschem raw sim_type}]
set v34_st    [opa_v_tran]
set v34_mask  [xschem get annot_show]
set v34_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v34_paint [opa_v_paint a10_viewer]
opa_l_annot 0
catch {xschem raw clear}
catch {xschem new_schematic switch $v34_wb}
catch {xschem new_schematic destroy $v34_wb {}}
catch {xschem new_schematic switch $v34_wa}
set v34_end [expr {[xschem get current_win_path] eq $v34_wa ? 1 : 0}]
check {V34 issue 0881 THE BENCH the run's results are attached to ANOTHER window through ase::attach_dbs, the design window holds nothing, and the annotation still lands} \
  [list [expr {$v34_wb ne $v34_wa ? 1 : 0}] $v34_att $v34_vld $v34_vst \
        $v34_back $v34_dld $v34_dst \
        $v34_st $v34_mask $v34_msg $v34_paint $v34_end] \
  [list 1 {0 {n 1 current 0 vcds {} skipped {}}} {0 0} {0 tran} \
        1 {0 -1} {1 {No raw file loaded}} \
        ok 4 $V_MSG_OK2 $V_PINS_P2 1]

# ===========================================================================
# V35 — THE ASE ARM OF THE SUPPLY: THE SESSION'S OWN FILE WINS. RED BEFORE
# ===========================================================================
# ⚠ ONE DISCOVERY MECHANISM, REUSED. `cadence::_annot_raw_candidate` already
# resolves this for the `6` chord and it already prefers the ASE session's own
# results over the `$netlist_dir/<cell>.raw` fallback -- rows N11 and N12 pin
# that order. This row asserts the transient mode arrives at the same file
# through the same door: the netlist_dir arm is pointed at an EMPTY directory,
# so a supply that had quietly grown its own second lookup answers `noraw`
# here, and the session's file is named in the readback rather than assumed.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 1e-9
opa_v_ase $V_A10_SESS 0 {set ::v35_state [opa_v_tran]}
set v35_rf    [rcall {xschem raw rawfile}]
set v35_mask  [xschem get annot_show]
set v35_paint [opa_v_paint a10_sess]
opa_l_annot 0
catch {xschem raw clear}
check {V35 the ASE session's own results file is what the transient mode reaches, not the netlist_dir fallback} \
  [list $::v35_state $v35_rf $v35_mask $v35_paint] \
  [list ok [list 0 $V_A10_SESS] 4 $V_PINS_P1]

# ===========================================================================
# V35b — THE SAME DOOR, AN OPERATING POINT BEHIND IT. RED BEFORE
# ===========================================================================
# ⚠ THE GATE THIS REACHES HAS BEEN DEAD CODE SINCE THE MODE SHIPPED. The
# `sim_type ne tran` refusal in `cadence::annot_tran` was only ever reachable
# from a fixture that hand-attached an operating point (row V16). Once the mode
# supplies itself, an OP-only session reaches it for real -- and the answer must
# be the honest `notran`, not the misleading `noraw` a supply that demanded a
# transient up front would produce.
# ⚠ THE THIRD ELEMENT WAS INVERTED, AND THE OLD ONE WAS THE DEFECT. It used to
# gold the operating point being LEFT ATTACHED after the refusal, on the reading
# that it had to be attached to find out what it was and is the right database
# for `6` and `Alt-6`. That reading is wrong, and row V46 is the measurement
# that says why: `xschem annotate_op` runs update_op() and draw() on its way in,
# so a session that already had the OP annotation bits on got the operating
# point PAINTED ONTO THE SHEET by the very key press that then said "the loaded
# database is not a transient analysis". A refusal that publishes is RULING
# D5-1, and it is issue 0872's shape arriving through the new door. So the
# refusal now unwinds -- the database this press attached is detached and the
# mask goes back -- and this row golds `xschem raw sim_type` RAISING.
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 1e-9
opa_v_ase $T_OPRAW 0 {set ::v35b_state [opa_v_tran]}
set v35b_mask  [xschem get annot_show]
set v35b_st    [rcall {xschem raw sim_type}]
set v35b_ld    [rcall {xschem raw loaded}]
set v35b_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v35b_paint [opa_v_paint a10_sessop]
opa_l_annot 0
catch {xschem raw clear}
check {V35b an OPERATING POINT reached through the new supply refuses as `notran`, arms nothing, paints nothing and is PUT BACK} \
  [list $::v35b_state $v35b_mask $v35b_st $v35b_ld $v35b_msg $v35b_paint] \
  [list notran 0 {1 {No raw file loaded}} {0 -1} $V_MSG_NOTRAN $V_PINS_NONE]

# ===========================================================================
# V36 — STALE RESULTS ARE NAMED AND NOT USED (issue 0838). RED BEFORE
# ===========================================================================
# ⚠ ISSUE 0838's RULE, CARRIED THROUGH THE NEW DOOR. The session is what knows
# whether its results still describe the deck on disk, and
# `cadence::_annot_raw_candidate` already refuses a stale one for the `6` chord
# rather than falling through to the netlist_dir arm, which is very often the
# same file under another name. A supply that reused the candidate builder but
# ignored its third element would annotate the previous run's numbers onto a
# changed circuit -- RULING D5-1, with an authoritative caption on top.
# The sentence NAMES THE FILE, because "not used" without saying which file is
# not something a user can act on.
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
opa_v_ase $V_A10_STALE 1 {set ::v36_state [opa_v_tran]}
set v36_ld    [rcall {xschem raw loaded}]
set v36_mask  [xschem get annot_show]
set v36_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v36_paint [opa_v_paint a10_stale]
opa_l_annot 0
catch {xschem raw clear}
check {V36 issue 0838 STALE results are refused by name, nothing is attached, nothing is armed and nothing is painted} \
  [list $::v36_state $v36_ld $v36_mask $v36_msg $v36_paint] \
  [list staleraw {0 -1} 0 $V_MSG_STALERAW $V_PINS_NONE]

# ===========================================================================
# V37 — A CANDIDATE THAT EXISTS BUT WILL NOT PARSE. RED BEFORE
# ===========================================================================
# ⚠ THE ONLY ROW THAT CAN SEE THE RE-ASK. `xschem annotate_op` returns the same
# rc for a file it loaded and a file it could not parse -- measured, and it is
# why `cadence::annot_mode`'s own candidate branch re-asks `xschem raw loaded`
# afterwards instead of trusting the rc. A supply that trusted the rc would
# walk on into the analysis check with nothing attached and answer `notran`,
# telling the user their transient is not a transient.
set ::netlist_dir $V_ND_JUNK
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
set v37_state [opa_v_tran]
set v37_ld    [rcall {xschem raw loaded}]
set v37_mask  [xschem get annot_show]
set v37_msg   [lindex [rcall {xschem get statusmsg}] 1]
check {V37 a results file that exists but will not parse still answers `noraw`, attaches nothing and arms nothing} \
  [list $v37_state $v37_ld $v37_mask $v37_msg] \
  [list noraw {0 -1} 0 $V_MSG_NORAW]

# ===========================================================================
# V38 — THE ORDERING GUARD. GREEN BEFORE AND AFTER, AND NOT OPTIONAL
# ===========================================================================
# ⚠ ROW V14 ASSERTS THE STATE AND THE MASK, WHICH IS WHY THIS ROW HAS TO EXIST.
# A supply hoisted above the cursor resolve passes V14 unchanged: the answer is
# still `nocursor` and the mask is still 0, but a key press that REFUSED has
# silently attached a database to the user's session -- exactly the thing the
# 0872 unwind exists to prevent, arriving through the new door. The second
# element is the whole row: with a perfectly good results file sitting on disk,
# `xschem raw loaded` is still -1 afterwards.
set ::netlist_dir $V_ND_TRAN
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 0
set v38_state [opa_v_tran]
set v38_ld    [rcall {xschem raw loaded}]
set v38_mask  [xschem get annot_show]
check {V38 ORDERING with no cursor on the mode refuses BEFORE it attaches anything, even with the run's results on disk} \
  [list $v38_state $v38_ld $v38_mask] \
  [list nocursor {0 -1} 0]

# ===========================================================================
# V39 — STRUCTURAL: ONE DISCOVERY MECHANISM, NOT TWO. RED BEFORE
# ===========================================================================
# ⚠ RULING D5-4's SPIRIT, APPLIED TO A LOOKUP INSTEAD OF A SENTENCE. There is
# already one proc that answers "where are this sheet's results", it already
# knows the ASE session beats the netlist_dir fallback, and it already refuses
# a stale file. A second lookup written out longhand beside it would drift
# silently the first time one of the three learned something the other did not
# -- the same argument invariant I1 makes for op_annot::vector.
# So: the supplier CALLS the candidate builder exactly once and spells none of
# its sources itself, and `cadence::annot_tran` does no loading of its own.
# ⚠ BODIES ARE SLICED, AND WHOLE-LINE COMMENTS DROPPED. Issue 0682's measured
# hole: `.` matches a newline in Tcl, so an unsliced grep runs from one proc
# header into the next body and stays green over dead code.
set V_A10_SRC [opa_slurp [file join $repo utils annot_mode.tcl]]
set V_A10_SUP [opa_proc_src $V_A10_SRC cadence::_annot_tran_supply]
set V_A10_TRN [opa_proc_src $V_A10_SRC cadence::annot_tran]
check {V39 RULING D5-4 the supplier reuses the ONE candidate builder and spells no second lookup, and annot_tran does no loading of its own} \
  [list [expr {[string length $V_A10_SUP] > 0 ? 1 : 0}] \
        [opa_v_pgrep $V_A10_SUP {cadence::_annot_raw_candidate}] \
        [opa_v_pgrep $V_A10_SUP {netlist_dir}] \
        [opa_v_pgrep $V_A10_SUP {ase::last_rawfile}] \
        [opa_v_pgrep $V_A10_SUP {ase::session_for_current}] \
        [expr {[string length $V_A10_TRN] > 0 ? 1 : 0}] \
        [opa_v_pgrep $V_A10_TRN {annotate_op}] \
        [opa_v_pgrep $V_A10_TRN {raw read}]] \
  [list 1 1 0 0 0 1 0 0]

# ===========================================================================
# V40 — ISSUE 0857, HALF 1: A TRANSIENT ALREADY ATTACHED. RED BEFORE
# ===========================================================================
# ⚠ THE USER RULED THIS ON 2026-08-27, VERBATIM: "Yes, 6 does nothing when
# there is ONLY a TRAN result. But, it's a good idea to say 'No OP results
# available' in the CIW." So ruling 0856's "do nothing" stands for the SCREEN
# -- nothing published, no bit armed, no number painted -- and stops standing
# for the user, who was left with a key that looked broken.
# ⚠ AND THE CHANNEL HAD TO BE BUILT, NOT REUSED. Measured before this item, all
# five `cadence::_annot_ciw` call sites in the shipped product were inside
# `cadence::annot_tran`; the `6` / `Alt-6` body had no CIW route at all, only
# one held status line that both silent returns return before reaching. So this
# row asserts BOTH sinks: the CIW is where the user asked for it, and the
# status line is where the three OP chords already speak.
# ⚠ LEG 3 IS THE EXEMPTION AND IT MUST STAY QUIET. Ctrl-6 clears, clearing can
# never put a number on a sheet, and it says what it has always said -- with
# nothing added to the CIW, because a chord people press repeatedly must not
# write a line every press.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 0
catch {xschem statusmsg -hold ZZ0857SENTINEL}
set v40a       [opa_v_spy {catch {cadence::annot_mode op}}]
set v40a_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v40a_mask  [xschem get annot_show]
set v40a_paint [opa_v_paint a10_six]
catch {xschem statusmsg -hold ZZ0857SENTINEL}
set v40b       [opa_v_spy {catch {cadence::annot_mode opvolt}}]
set v40b_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v40b_mask  [xschem get annot_show]
set v40b_paint [opa_v_paint a10_alt6]
catch {xschem statusmsg -hold ZZ0857SENTINEL}
set v40c       [opa_v_spy {catch {cadence::annot_mode none}}]
set v40c_msg   [lindex [rcall {xschem get statusmsg}] 1]
opa_l_annot 0
catch {xschem raw clear}
check {V40 issue 0857 with ONLY a transient loaded `6` and `Alt-6` say so in the CIW and on the status line, arm nothing and paint nothing, and Ctrl-6 stays quiet} \
  [list $v40a $v40a_msg $v40a_mask $v40a_paint \
        $v40b $v40b_msg $v40b_mask $v40b_paint \
        $v40c $v40c_msg] \
  [list [list [list warn $V_MSG_NOTOP_TRAN]] $V_MSG_NOTOP_TRAN 0 $V_PINS_NONE \
        [list [list warn $V_MSG_NOTOP_TRAN]] $V_MSG_NOTOP_TRAN 0 $V_PINS_NONE \
        {} $A11_M0]

# ===========================================================================
# V41 — ISSUE 0857, HALF 2: THE 0872 UNWIND SPEAKS TOO. RED BEFORE
# ===========================================================================
# ⚠ WITHOUT THIS ROW THE SENTENCE AT THE UNWIND IS INVISIBLE TO EVERY OTHER
# ROW. V31c reads the status line and nothing else, so a fix that spoke on the
# status line but never reached the CIW would pass it -- and issue 0873 is on
# record that silencing this channel once left every check in the file green.
# This is the ordinary post-run desktop: the run's transient is on disk,
# nothing is attached, one Alt-6 searches, loads, unwinds and now SAYS why.
# Four claims: the CIW got it exactly once and tagged it a warning; the held
# status line carries the same string; the mask is back where the user had it;
# and the database the chord attached itself is detached again.
set ::netlist_dir $V_ND_TRAN
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
catch {xschem statusmsg -hold ZZ0857SENTINEL}
set v41      [opa_v_spy {catch {cadence::annot_mode opvolt}}]
set v41_msg  [lindex [rcall {xschem get statusmsg}] 1]
set v41_mask [xschem get annot_show]
set v41_ld   [rcall {xschem raw loaded}]
opa_l_annot 0
catch {xschem raw clear}
check {V41 issue 0857 the post-run desktop: Alt-6 searches, loads, unwinds AND says why, once, tagged as a warning} \
  [list $v41 $v41_msg $v41_mask $v41_ld] \
  [list [list [list warn $V_MSG_NOTOP_TRAN]] $V_MSG_NOTOP_TRAN 0 {0 -1}]

# ===========================================================================
# V42 — THE TWO NEW SENTENCES, BYTE FOR BYTE. RED BEFORE
# ===========================================================================
# ⚠ THESE STRINGS ARE THE SPECIFICATION. Both mints render exactly them and
# every caller renders through the mint rather than composing its own wording.
# The `notop` arm has TWO shapes and both are pinned: the analysis type is
# named when the attached database can say what it is, and left out when it
# cannot -- a sentence that said "a '' analysis" would be worse than saying
# nothing, which is the defect this whole row set is about.
# ⚠ AND AN UNKNOWN STATE STILL RAISES, NAMING THE NEW SPELLING. A state name is
# a CALLER bug and must be loud; a caller bug that renders as a polite apology
# is exactly the silence the mode exists to remove.
## ⚠ AND THE THIRD SENTENCE, ADDED BY THE A10 REPAIR. It is the one a user
## meets when the results file changed under the waveform viewer, and it is
## written the way the user asked for on 2026-08-27 -- plain English, saying
## what happened AND what to do about it, with no internal vocabulary in it.
set V_MSG_VDIFF42 "The results file [file tail $V_A10_STALE] on disk is from a different simulation run than the one the waveform window is showing, so nothing was placed on the schematic. Plot the results again in the waveform window, then try again."
## ⚠ AND THE TWO SENTENCES ITEM A13 ADDS, for issues 0895 and 0896. NEW WORDING
## THE USER HAS NOT RATIFIED -- a `look` debt each and a `rule` debt for having
## invented it. Both name the file, both say what happened and both end with
## what the user can do, because a refusal that stops at naming the problem is
## the silence this mode exists to remove.
set V_MSG_VGONE42 "The waveform window is showing the results file [file tail $V_A10_STALE], but that file is no longer on disk, so nothing was placed on the schematic. If a simulation is running, wait for it to finish, then try again."
set V_MSG_VFILL42 "The waveform window is showing the results file [file tail $V_A10_STALE], but the run has not produced any values yet, so nothing was placed on the schematic. Wait for the simulation to finish, then try again."
check {V42 RULING D5-4 the stale-results sentence, the changed-results sentence and BOTH shapes of the no-operating-point sentence, byte for byte} \
  [list [rcall [list cadence::_annot_tran_msg staleraw {} {} $V_A10_STALE]] \
        [rcall [list cadence::_annot_tran_msg viewerdiff {} {} $V_A10_STALE]] \
        [rcall {cadence::_annot_msg 0 notop tran {}}] \
        [rcall {cadence::_annot_msg 0 notop {} {}}]] \
  [list [list 0 $V_MSG_STALERAW] [list 0 $V_MSG_VDIFF42] \
        [list 0 $V_MSG_NOTOP_TRAN] [list 0 $V_MSG_NOTOP_BARE]]
check {V42d issues 0895+0896 the deleted-results-file sentence and the still-filling sentence, byte for byte} \
  [list [rcall [list cadence::_annot_tran_msg viewergone {} {} $V_A10_STALE]] \
        [rcall [list cadence::_annot_tran_msg viewerfilling {} {} $V_A10_STALE]]] \
  [list [list 0 $V_MSG_VGONE42] [list 0 $V_MSG_VFILL42]]
check_raises {V42b an unknown transient state still RAISES, and the message names the new `staleraw` spelling} \
  {cadence::_annot_tran_msg zzbogus {} {}} {staleraw}
## ⚠ THE ROLL-CALL IN THE RAISE IS HAND-MAINTAINED, which is issue 0897, and an
## arm added without its spelling here is an arm the raise cannot name.
check_raises {V42c an unknown transient state names the new `viewerfilling` spelling too} \
  {cadence::_annot_tran_msg zzbogus {} {}} {viewerfilling}
check_raises {V42c2 an unknown transient state names the new `viewergone` spelling too} \
  {cadence::_annot_tran_msg zzbogus {} {}} {viewergone}

# ===========================================================================
# V43 — STRUCTURAL, RULING D5-4: MINTED IN ONE FILE ONLY. RED BEFORE
# ===========================================================================
# ⚠ ROW V18's SET, EXTENDED. A second copy of a user-facing sentence composed
# inside a menu body or an rc file is the shape this ruling forbids, and it is
# the shape that actually happens -- someone needs the wording one call away
# and pastes it. The mint file must carry each fragment; the five files a
# reader would plausibly reach for must carry neither.
# ⚠ AT LEAST ONE, NOT EXACTLY ONE, IN THE MINT. The no-operating-point sentence
# has two shapes and may legitimately be written as two returns of one arm; the
# claim that matters is that no OTHER file has it.
set V_A10_MINT  [file join $repo utils annot_mode.tcl]
set V_A10_OTHER [list [file join $repo src xschem.tcl] \
                      [file join $repo src ase.tcl] \
                      [file join $repo src ase_window.tcl] \
                      [file join $repo src wave_viewer.tcl] \
                      [file join $repo src cadence_style_rc]]
## ⚠ THE FRAGMENT MUST SIT ON ONE SOURCE LINE, because opa_v_ngrep is
## line-based. That is a constraint on how the mint is written, and it is
## cheaper to state it than to have a later reader wrap the sentence and
## silently hollow this row.
## ⚠ ISSUE 0909's THREE BLANK-ROW SENTENCES JOIN THE SET, and each is
## represented by a SHORT distinguishing fragment on purpose: opa_v_ngrep is
## line-based, and a 229-byte sentence cannot be written on one source line
## without a reader wrapping it and silently hollowing this row. The fragment
## is the constraint, not the whole sentence.
## ⚠ AND THE THREE SHORT FORMS ARE IN THE SET TOO. They are user-facing
## sentences in their own right -- the only ones a plain xschem user with no
## ASE-L window ever reads -- so a second copy of one is exactly the drift this
## ruling forbids, and being short makes pasting one somewhere convenient MORE
## likely, not less.
set V43_FRAGS [list {No operating point results are loaded} \
                    {is older than the circuit it describes} \
                    {is from a different simulation run} \
                    {but that file is no longer on disk} \
                    {but the run has not produced any values yet} \
                    {did not save the device operating-point numbers} \
                    {has no per-device operating-point numbers in it} \
                    {but not for every device on this sheet} \
                    {values like gm and vth. Turn on saving them} \
                    {values like gm and vth in it.} \
                    {for some of the devices here.}]
set v43_mint {}
foreach _vf $V43_FRAGS {
  lappend v43_mint [expr {[opa_v_ngrep $V_A10_MINT $_vf] >= 1 ? 1 : 0}]
}
set v43_other {}
foreach _vp $V_A10_OTHER {
  foreach _vf $V43_FRAGS { lappend v43_other [opa_v_ngrep $_vp $_vf] }
}
check {V43 RULING D5-4 the eleven new sentences are minted in utils/annot_mode.tcl and appear in no other file} \
  [list $v43_mint $v43_other] \
  [list [string trim [string repeat {1 } [llength $V43_FRAGS]]] \
        [string trim [string repeat {0 } [expr {[llength $V43_FRAGS] * [llength $V_A10_OTHER]}]]]]

# ===========================================================================
# V44 — WITNESS, ISSUE 0882: A CONSEQUENCE OF THE FIX, PINNED
# ===========================================================================
# ⚠ THIS ROW GUARDS NOTHING -- IT RECORDS. `wviewer::hier_origin_ok`
# (src/wave_viewer.tcl) short-circuits `return 1` whenever the CURRENT context
# holds a database, skipping the base-level check entirely, and its own header
# states the premise in writing: "ASE reads the raw into the VIEWER context
# only ... so in the DESIGN window sch_waves_loaded is -1". Item A10 makes that
# sentence false: after a successful transient annotation the design window
# DOES hold a raw, so a base-level mismatch that refused before now passes.
# Measured, not read: the stub forces a refusing base level and the ONLY thing
# that changes between the two reads is whether the design window holds
# results. Filed as issue 0882; src/wave_viewer.tcl is outside this item's
# blast radius, so this row exists so a later crew has to confront the changed
# premise rather than discover it.
set ::netlist_dir $V_ND_TRAN
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
namespace eval ::ase::ui {}
set v44_had [expr {[info commands ::ase::ui::sod_base_level] ne {}}]
if {$v44_had} { rename ::ase::ui::sod_base_level ::opa_v44_saved_sod }
proc ::ase::ui::sod_base_level {tok} { return 3 }
set v44_before [rcall {wviewer::hier_origin_ok ZZA10TOKEN}]
set v44_state  [opa_v_tran]
set v44_after  [rcall {wviewer::hier_origin_ok ZZA10TOKEN}]
catch {rename ::ase::ui::sod_base_level {}}
if {$v44_had} { rename ::opa_v44_saved_sod ::ase::ui::sod_base_level }
opa_l_annot 0
catch {xschem raw clear}
check {V44 issue 0882 WITNESS a base-level mismatch that REFUSED with an empty design window is ALLOWED once the annotation has attached results there} \
  [list $v44_before $v44_state $v44_after] \
  [list {0 0} ok {0 1}]

# ===========================================================================
# A10 REPAIR — THE FOUR DEFECTS THE VERIFIERS FOUND, AND THE FOUR GUARDS THE
#              SABOTAGE PASS COULD NOT SEE
# ===========================================================================
# Every row below was RED on the first A10 build. Named by what a user would
# say happened, not by the proc that changed:
#
#   V45   the results file holds the deck's operating point AND its transient,
#         which is what a simulator ordinarily writes, and the transient is
#         what gets annotated                                  <- RED before
#   V46   a press that REFUSES must not leave a number on the sheet <- RED
#   V47   STRUCTURAL: the two hand-off choices the sabotage pass found
#         unwitnessed -- the hierarchy level travels with the file, and the
#         file goes through the annotate verb                   <- RED
#   V48   BEHAVIOURAL twin of V47's first half: one sheet DOWN  <- RED
#   V49   the newest refusal reaches the CIW, not the status line alone <- RED
#   V50   the file the WAVEFORM VIEWER is showing beats a stale path rebuilt
#         from the preferences -- issue 0881's own acceptance   <- RED before
#   V51   the viewer and the sheet would disagree, so nothing is annotated and
#         the user is told to re-plot -- RULING D5-1            <- RED before
#
# ⚠ V50 AND V51 ARE THE ROWS ISSUE 0881 ACTUALLY ASKED FOR, and V33/V34 are
# not. V34 attaches the run's results to another window and then passes anyway,
# because the file also sits where the preferences say it does -- so it cannot
# tell a build that consults the viewer from one that does not. These two put
# a DIFFERENT results file at each place and are the only rows in the tree that
# can.

## The waveform viewer, headless. A second schematic window stands in for the
## viewer's window -- it is a real second xschem context with its own results
## registry, which is exactly what the viewer's window is -- and the three
## verbs `cadence::_annot_viewer_db` calls are pointed at it. Restored on the
## way out, window destroyed, design window current again.
## ⚠ THE PRODUCT IS NOT STUBBED, THE WINDOW MANAGER IS. `wviewer::enter_ctx`
## and `wviewer::leave_ctx` exist only when Tk and the viewer are up; headless
## there is no viewer at all, so the borrow has to be spelled out here. What is
## NOT spelled out here is any part of the annotation: the supply, the compare
## and the refusal are the shipped code. Rows B12/B12c/B12g of
## tests/headless/test_annot_show_menu.tcl drive the same path through the REAL
## viewer on a real display.
## ⚠ THE ANALYSIS IS A PARAMETER BECAUSE A WAVEFORM WINDOW IS NOT ALWAYS
## SHOWING A TRANSIENT, and item A13's repair turns on exactly that. Default
## `tran`, so every row written before this reads unchanged; rows V63e/V63f and
## V64 pass `op` or point it at a file that is not there, which is the only way
## to stand up a viewer window that is genuinely IN PLAY while holding nothing
## this mode can use.
proc opa_v_viewer {rawfile script {analysis tran}} {
  set dw [xschem get current_win_path]
  ## ⚠ ISSUE 0891 -- THE STAND-IN IS BUILT ON THE VERB THE REAL VIEWER USES,
  ## AND THAT IS THE WHOLE OF THE ISSUE. A reader would otherwise assume any
  ## second xschem context is a faithful stand-in for the waveform window. It is
  ## not, under Tk: `xschem new_schematic create` with `tabbed_interface` on --
  ## the default -- makes a TAB, whose `.xN.drw` is a C-side name with no Tk
  ## widget behind it, so `winfo exists` on it answers 0. The shipped consult
  ## `cadence::_annot_viewer_db` asks exactly that question before it will borrow,
  ## so against a tab the whole 0881 consult returned nothing and rows V50/V51
  ## were green headless (no `winfo` exists, so the question is never asked) and
  ## red on the arm the user actually has. `wviewer::open` never makes a tab: it
  ## uses `load_new_window -window {}`, which always yields a real toplevel.
  ## ⚠ THE EMPTY FILE ARGUMENT IS LOAD-BEARING. `load_new_window -window <file>`
  ## with a NON-empty name takes scheduler.c's pristine-untitled reuse arm and
  ## loads into the CURRENT window instead, so the schematic is loaded as a
  ## separate step afterwards. Same reasoning as src/wave_viewer.tcl's own open.
  ## ⚠ AND THE CONTEXT SWITCH IS VERIFIED, NOT ASSUMED (landmine 17): `-window`
  ## always creates the toplevel, but the switch to it silently no-ops under a
  ## raised semaphore -- measured in the product at 3 fresh processes in 10.
  if {[llength [info commands ::winfo]]} {
    set tops0 [winfo children .]
    catch {xschem load_new_window -window {}}
    set vw [xschem get current_win_path]
    if {$vw eq $dw} {
      foreach t [winfo children .] {
        if {[lsearch -exact $tops0 $t] >= 0} continue
        if {![winfo exists $t.drw]} continue
        catch {xschem new_schematic switch $t.drw}
        if {[xschem get current_win_path] eq "$t.drw"} { set vw $t.drw ; break }
      }
    }
    if {$vw ne $dw} {
      catch {xschem load $::V_A10_VSCH}
      catch {xschem set readonly 1}
    }
  } else {
    ## Headless there is no Tk at all, so there is no toplevel to make and no
    ## `winfo` to ask about it; the tab IS the whole window model. Both arms set
    ## the same two globals below, so the shape under test is identical.
    catch {xschem new_schematic create {} $::V_A10_VSCH}
    set vw [xschem get current_win_path]
  }
  ## ⚠ TWO KEYS, BECAUSE THE PRODUCT'S REGISTRY HAS TWO. src/wave_viewer.tcl
  ## records `{top .xN win_path .xN.drw}`: `wviewer::window_for` answers the TOP
  ## (and `winfo exists`-checks it), while `wviewer::enter_ctx` switches to the
  ## WIN_PATH. A stub that conflates them cannot see issue 0891's defect, which
  ## is how it survived. Row V54 asserts this split as source text, in both arms.
  ## `string range ... end-4` rather than a regsub, because a regsub of `.drw$`
  ## maps the design window `.drw` to the empty string instead of `.`.
  set ::opa_v_vw_path $vw
  set ::opa_v_vw_top [expr {$vw eq {.drw} ? {.} : [string range $vw 0 end-4]}]
  set ok 0
  ## â  THE VIEWER'S OWN sim_type IS RECORDED HERE AND NOWHERE ELSE, because by
  ## the time <script> runs the context has already been switched back to the
  ## design window -- so a probe written in the script body would silently ask
  ## the WRONG window and answer for the sheet. Row V63 leg f needs to prove the
  ## viewer really is holding an operating point rather than a transient.
  set st {}
  if {$vw ne $dw} {
    catch {set ok [xschem raw read $rawfile $analysis]}
    catch {set st [xschem raw sim_type]}
    catch {xschem new_schematic switch $dw}
  }
  set ::opa_v_vw_ok $ok
  set ::opa_v_vw_st $st
  namespace eval ase {}
  namespace eval wviewer {}
  set h1 [expr {[info commands ::ase::session_for_current] ne {}}]
  set h2 [expr {[info commands ::ase::last_rawfile] ne {}}]
  set h3 [expr {[info commands ::ase::results_stale] ne {}}]
  set h4 [expr {[info commands ::wviewer::window_for] ne {}}]
  set h5 [expr {[info commands ::wviewer::enter_ctx] ne {}}]
  set h6 [expr {[info commands ::wviewer::leave_ctx] ne {}}]
  if {$h1} { rename ::ase::session_for_current ::opa_v_sv1 }
  if {$h2} { rename ::ase::last_rawfile        ::opa_v_sv2 }
  if {$h3} { rename ::ase::results_stale       ::opa_v_sv3 }
  if {$h4} { rename ::wviewer::window_for      ::opa_v_sv4 }
  if {$h5} { rename ::wviewer::enter_ctx       ::opa_v_sv5 }
  if {$h6} { rename ::wviewer::leave_ctx       ::opa_v_sv6 }
  proc ::ase::session_for_current {} { return [list zzA10vw 0 zzlib zzcell schematic] }
  proc ::ase::last_rawfile {key} { return {} }
  proc ::ase::results_stale {key} { return 0 }
  proc ::wviewer::window_for {key} { return $::opa_v_vw_top }
  proc ::wviewer::enter_ctx {key {borrow 0}} {
    set prev [xschem get current_win_path]
    if {$prev eq $::opa_v_vw_path} { return [list 1 {}] }
    if {[catch {xschem new_schematic switch $::opa_v_vw_path}]} { return [list 0 {}] }
    return [list 1 $prev]
  }
  proc ::wviewer::leave_ctx {key ticket} {
    if {[lindex $ticket 1] ne {}} {
      catch {xschem new_schematic switch [lindex $ticket 1]}
    }
  }
  catch {uplevel 1 $script} r
  catch {rename ::ase::session_for_current {}}
  catch {rename ::ase::last_rawfile {}}
  catch {rename ::ase::results_stale {}}
  catch {rename ::wviewer::window_for {}}
  catch {rename ::wviewer::enter_ctx {}}
  catch {rename ::wviewer::leave_ctx {}}
  if {$h1} { rename ::opa_v_sv1 ::ase::session_for_current }
  if {$h2} { rename ::opa_v_sv2 ::ase::last_rawfile }
  if {$h3} { rename ::opa_v_sv3 ::ase::results_stale }
  if {$h4} { rename ::opa_v_sv4 ::wviewer::window_for }
  if {$h5} { rename ::opa_v_sv5 ::wviewer::enter_ctx }
  if {$h6} { rename ::opa_v_sv6 ::wviewer::leave_ctx }
  if {$vw ne $dw} {
    catch {xschem new_schematic switch $vw}
    catch {xschem raw clear}
    catch {xschem new_schematic destroy $vw {}}
    catch {xschem new_schematic switch $dw}
  }
  return $r
}

## THE WAVEFORM WINDOW RE-PLOTS, WHICH IS WHAT A RE-RUN DOES TO IT. Borrows
## into the stand-in window the way the shipped consult does, throws away what
## it was holding and reads the file again -- the shape of
## `wviewer::attach_raw`, which is the call `ase::ui::auto_plot` makes after a
## run. Answers the read's rc and v(d) at the last point, so a row can prove
## the WINDOW really moved to the new run before it asks what the key press
## did. Restores the design window on the way out, opa_v_viewer's discipline.
##
## ⚠ NOTHING HERE TOUCHES THE DESIGN WINDOW'S OWN DATABASE, and that is the
## whole point of the fixture: the state issue 0900 is about is a design window
## still holding what an EARLIER PRESS attached while the waveform window has
## moved on. A fixture that cleared the design window here would rebuild the
## one condition the defect needs and could never see it -- which is exactly
## how row B12d hid this defect from the real-chain rows for a whole item.
proc opa_v_replot {file} {
  set dw [xschem get current_win_path]
  if {[catch {xschem new_schematic switch $::opa_v_vw_path}]} { return [list SWITCH-FAILED {}] }
  if {[xschem get current_win_path] ne $::opa_v_vw_path} { return [list SWITCH-FAILED {}] }
  set rc 0
  catch {xschem raw clear}
  catch {set rc [xschem raw read $file tran]}
  set v {}
  catch {set v [xschem raw value v(d) 4]}
  catch {xschem new_schematic switch $dw}
  return [list $rc $v]
}

## THE ITEM'S REPAIR FIXTURES, all derived from the section's own transient so
## the only thing that differs between them is the thing under test.
set V_T_SRC  [opa_slurp $T_RAW]
set V_T_HDR  [string range $V_T_SRC 0 [expr {[string first "Values:\n" $V_T_SRC] + 7}]]

## The ordinary simulator output: the deck's `.op` and its `.tran` in ONE file.
## The operating point comes first, exactly as a simulator writes it, and its
## node values are deliberately nothing like the transient's so a build that
## took the wrong plot cannot pass by arithmetic accident.
## ⚠ THE BLANK LINE AFTER THE OPERATING POINT'S ONE DATA POINT IS REQUIRED, and
## it is not decoration: skip_raw_ascii_points (src/save.c) walks to a blank
## line to step over a plot it was not asked for, so an ascii fixture without
## one cannot be skipped and the second plot is unreachable. Measured.
set V_OPHDR $V_T_HDR
regsub {Plotname: Transient Analysis} $V_OPHDR {Plotname: Operating Point} V_OPHDR
regsub {No\. Points: 5} $V_OPHDR {No. Points: 1} V_OPHDR
set V_A10_OPTRAN [file join $scratch v_a10_optran.raw]
opa_t_wr $V_A10_OPTRAN "${V_OPHDR}0\t0.0\n\t0.0\n\t0.0\n\t0.7\n\t99.0\n\t88.0\n\n$V_T_SRC"

## A SECOND, DIFFERENT transient: same columns, different numbers. It plays the
## decoy at the preferences path in V50 and the next simulation run in V51.
set V_A10_RUN2 [file join $scratch v_a10_other.raw]
set V_OTHER $V_T_HDR
for {set _vp 0} {$_vp < 5} {incr _vp} {
  append V_OTHER "$_vp\t[expr {$_vp*1.0e-9}]\n\t0.0\n\t0.0\n\t0.7\n\t[expr {$_vp*7.0}]\n\t0.1\n"
}
opa_t_wr $V_A10_RUN2 $V_OTHER
set V_ND_DECOY [file join $scratch v_nd_decoy]
file mkdir $V_ND_DECOY
file copy -force $V_A10_RUN2 [file join $V_ND_DECOY v_cand.raw]
## The file a run leaves behind and the viewer then reads. V51 overwrites it
## in place, which is what re-running the simulator does.
set V_A10_VRUN [file join $scratch v_a10_vrun.raw]
file copy -force $T_RAW $V_A10_VRUN

## ⚠ ISSUE 0902's FIXTURE: THE USER'S CO-SIMULATION VCD, WHICH THIS SURFACE MUST
## NEVER TOUCH. `doc/claude/specs/mixed_signal_signal_browser.md` D5 is written
## about exactly this window state -- one analog run and one digital database
## side by side -- and RULING D5-3 is what it settles: a logic level is not a
## voltage, so a digital database contributes NOTHING to a schematic and
## `xschem annotate_op` refuses one before it loads anything. It follows that
## the annotation surface can never have attached a VCD, and must never take one
## off. Three points, so a fingerprint can be computed for it and it can never
## be mistaken for the 5-point transient beside it.
set V_A14_VCD [file join $scratch v_a14_dig.vcd]
opa_t_wr $V_A14_VCD "\$timescale 1ns \$end\n\$scope module top \$end\n \$scope module m \$end\n  \$var wire 1 ! dsig \$end\n \$upscope \$end\n\$upscope \$end\n\$enddefinitions \$end\n#0\n0!\n#1\n1!\n#4\n"
set V_A14_DIGNODE top.m.dsig

## How many databases THIS window is holding. `xschem raw info` prints a header
## line and then one line per slot, so the count is the number of slots. 0 when
## the window is holding nothing at all.
## ⚠ THE COUNT IS THE POINT, NOT `xschem raw loaded`. `raw loaded` answers a
## hierarchy LEVEL and is 0 both for a window holding one database and for a
## window holding three, so it cannot see a database being destroyed alongside
## the one the press was talking about -- which is the whole of issue 0902.
proc opa_v_slots {} {
  if {[catch {xschem raw info} t] || $t eq {}} { return 0 }
  set n 0
  foreach l [lrange [split [string trimright $t "\n"] "\n"] 1 end] {
    if {[regexp {^[0-9]+ } $l]} { incr n }
  }
  return $n
}

## What the user's digital database still reads for its one signal, WITHOUT
## leaving the window on a different database than it was found on -- a probe
## that changed which database is current would be staging the next row's state
## instead of measuring this one. `NO-VCD` when the database is not there at
## all, which is the failure issue 0902 is about and which must not read as a
## blank value.
proc opa_v_digval {} {
  set f {} ; set t {}
  catch {set f [xschem raw rawfile]}
  catch {set t [xschem raw sim_type]}
  set sw 0
  catch {set sw [xschem raw switch $::V_A14_VCD vcd]}
  set here {}
  catch {set here [xschem raw rawfile]}
  set v {NO-VCD}
  if {$here eq $::V_A14_VCD} {
    set v {}
    catch {set v [xschem raw value $::V_A14_DIGNODE 2]}
  }
  if {$f ne {} && $t ne {}} { catch {xschem raw switch $f $t} }
  return $v
}

set V_PINS_OTHER {d 21 g 0.1 0 0.0 0 0.0}
## ⚠ THE `-` IS INVARIANT I3, NOT A DEFECT. The operating-point fixture carries
## v(d) and no v(g), so node `g` renders the blank placeholder while the two
## grounds read 0.0. That is what "the operating point is on the sheet" looks
## like for this file, and it is what row V46's control leg requires to appear.
set V_PINS_OP75  {d 7.5 g - 0 0.0 0 0.0}
set V_MSG_VDIFF "The results file [file tail $V_A10_VRUN] on disk is from a different simulation run than the one the waveform window is showing, so nothing was placed on the schematic. Plot the results again in the waveform window, then try again."

# ===========================================================================
# V45 — THE ORDINARY RESULTS FILE: AN OPERATING POINT *AND* A TRANSIENT
# ===========================================================================
# ⚠ THIS IS THE COMMONEST FILE A REAL BENCH PRODUCES, AND THE MODE REFUSED IT.
# A deck with a `.op` and a `.tran` puts both plots in one results file. The
# engine's shipped fallback, used when no analysis is named, is op -> dc ->
# tran, so it stopped at the operating point -- and the transient mode then
# refused its own supply with "the loaded database is not a transient
# analysis", about a file whose transient the user could see on screen. The
# sentence was not merely unhelpful, it was FALSE: the same file read with the
# transient named gives 5 points and 3 V at the 3 ns cursor, which is the
# second half of this row.
# ⚠ AND THE OPERATING POINT IN THIS FIXTURE SAYS 99 V, so a build that took the
# wrong plot cannot land on the right number by coincidence.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
opa_v_ase $V_A10_OPTRAN 0 {set ::v45_state [opa_v_tran]}
set v45_st    [rcall {xschem raw sim_type}]
set v45_np    [rcall {xschem raw points}]
set v45_mask  [xschem get annot_show]
set v45_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v45_paint [opa_v_paint a10_optran]
opa_l_annot 0
catch {xschem raw clear}
check {V45 a results file holding the deck's OPERATING POINT and its TRANSIENT annotates the TRANSIENT at the cursor} \
  [list $::v45_state $v45_st $v45_np $v45_mask $v45_msg $v45_paint] \
  [list ok {0 tran} {0 5} 4 $V_MSG_OK3 $V_PINS_P3]

# ===========================================================================
# V46 — A PRESS THAT REFUSES MUST NOT LEAVE A NUMBER ON THE SHEET
# ===========================================================================
# ⚠ RULING D5-1, AND THE OLD BEHAVIOUR PUT AN OPERATING POINT ON A SHEET THE
# USER HAD ASKED FOR TRANSIENT NUMBERS ON. The supply has to attach a database
# to find out what analysis it holds, and `xschem annotate_op` runs update_op()
# and draw() on its way in. So with the node-voltage bit already on -- one
# earlier `Alt-6`, or an `annot_show` line in the user's own xschemrc, which
# src/xinit.c honours -- the operating point was PUBLISHED AND PAINTED by the
# very key press whose status line then read "the loaded database is not a
# transient analysis".
# ⚠ LEG 1 IS THE NON-VACUITY AND IT IS NOT OPTIONAL. It attaches the same file
# by hand under the same mask and requires 7.5 V to appear beside node `d`. A
# row asserting only that nothing was painted would be satisfied by a fixture
# that could not paint at all, which is how this defect survived 427 checks.
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
opa_l_annot 2
catch {xschem annotate_op $T_OPRAW}
set v46_ctl [opa_v_paint a10_pubctl]
catch {xschem raw clear}
opa_l_annot 2
opa_v_ase $T_OPRAW 0 {set ::v46_state [opa_v_tran]}
set v46_mask  [xschem get annot_show]
set v46_ld    [rcall {xschem raw loaded}]
set v46_paint [opa_v_paint a10_pub]
opa_l_annot 0
catch {xschem raw clear}
check {V46 RULING D5-1 the `not a transient` refusal publishes NOTHING: the operating point that would have painted 7.5 V is put back, and the user's own mask survives} \
  [list $v46_ctl $::v46_state $v46_mask $v46_ld $v46_paint] \
  [list $V_PINS_OP75 notran 2 {0 -1} $V_PINS_NONE]

# ===========================================================================
# V47 — STRUCTURAL: THE TWO HAND-OFF CHOICES NO BEHAVIOURAL ROW COULD SEE
# ===========================================================================
# ⚠ THIS ROW EXISTS BECAUSE A SABOTAGE PASS PROVED IT HAD TO. Deleting the
# hierarchy level from the hand-off, and swapping the annotate verb for a bare
# results read, each left the whole tree green -- 427 checks here and 31 on the
# Tk suite -- while silently discarding the level stamp that makes a database
# findable after the user has descended. Row V48 is the behavioural twin of the
# first half; the verb choice has no behavioural witness at all on this
# fixture, so it is pinned here, which is the honest answer.
# The claims: the viewer is consulted exactly once; the level travels on EVERY
# hand-off, not just the first; the transient is asked for by name once; the
# shipped fallback is still there as the second ask; the file is checked to
# exist; and nothing in the supplier reaches for the raw-read verb.
set V_A10_SRC2 [opa_slurp [file join $repo utils annot_mode.tcl]]
set V_A10_SUP2 [opa_proc_src $V_A10_SRC2 cadence::_annot_tran_supply]
check {V47 STRUCTURAL the supplier consults the viewer, carries the hierarchy level on every hand-off, names the transient first and keeps the shipped fallback second} \
  [list [expr {[string length $V_A10_SUP2] > 0 ? 1 : 0}] \
        [opa_v_pgrep $V_A10_SUP2 {cadence::_annot_viewer_db}] \
        [opa_v_pgrep $V_A10_SUP2 {annotate_op}] \
        [opa_v_pgrep $V_A10_SUP2 {annotate_op \$path \$lvl}] \
        [opa_v_pgrep $V_A10_SUP2 {annotate_op \$path \$lvl tran}] \
        [opa_v_pgrep $V_A10_SUP2 {file exists}] \
        [opa_v_pgrep $V_A10_SUP2 {raw read}]] \
  [list 1 1 2 2 1 1 0]

# ===========================================================================
# V48 — BEHAVIOURAL: THE SAME PRESS, ONE SHEET DOWN
# ===========================================================================
# ⚠ THE LEVEL IS NOT DECORATION, AND THIS IS THE ROW THAT SAYS SO. The results
# were written for the WHOLE design, at the top; the user has walked down into
# a sub-sheet and presses the chord there. `sch_waves_loaded()` (src/draw.c)
# answers -1 unless the database was stamped with a hierarchy level that still
# matches somewhere up the stack, and `xschem raw loaded` is what the supplier
# re-asks -- so a hand-off that dropped the level answers "no results file
# loaded" to a user whose results are loaded, one sheet up.
# ⚠ WHY NO ROW SAW THIS BEFORE: every fixture in both suites stood at the top
# sheet, where the level argument is a no-op because it already matches. This
# one descends.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib s5_top.sch]
opa_l_annot 0
xschem unselect_all ; xschem select instance 0 fast nodraw
catch {xschem descend 1 2}
set v48_lvl [xschem get currsch]
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
opa_v_ase $T_RAW 0 {set ::v48_state [opa_v_tran]}
set v48_ld   [rcall {xschem raw loaded}]
set v48_mask [xschem get annot_show]
opa_l_annot 0
catch {xschem raw clear}
catch {xschem go_back 2}
check {V48 the chord pressed ONE SHEET DOWN still finds the run's results, because the hierarchy level travels with the file} \
  [list $v48_lvl $::v48_state $v48_ld $v48_mask] \
  [list 1 ok {0 0} 4]

# ===========================================================================
# V49 — THE NEWEST REFUSAL SPEAKS IN THE CIW, NOT ON THE STATUS LINE ALONE
# ===========================================================================
# ⚠ ROW V29 ENUMERATES THE THREE REFUSALS THAT EXISTED BEFORE THIS ITEM, and a
# sabotage pass proved that deleting the CIW call from the out-of-date-results
# refusal left every check in the file green -- only its status line was
# pinned. The user's ask was explicitly about the CIW ("it's a good idea to say
# ... in the CIW"), and a person running ASE-L is looking there, so half a
# delivery is not a delivery. This row is V29 extended to the fourth state.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
catch {xschem statusmsg -hold ZZA10SENTINEL}
set v49  [opa_v_spy {opa_v_ase $V_A10_STALE 1 {set ::v49_state [opa_v_tran]}}]
set v49m [lindex [rcall {xschem get statusmsg}] 1]
set v49h [lindex [rcall {xschem get statusmsg_hold}] 1]
opa_l_annot 0
catch {xschem raw clear}
check {V49 the out-of-date-results refusal reaches the CIW tagged `warn` AND the held status line, exactly as the three older refusals do} \
  [list $::v49_state $v49 $v49m $v49h] \
  [list staleraw [list [list warn $V_MSG_STALERAW]] $V_MSG_STALERAW 1]

# ===========================================================================
# V50 — ISSUE 0881's OWN ACCEPTANCE: THE FILE ON THE USER'S SCREEN WINS
# ===========================================================================
# ⚠ THE USER'S WORDS, VERBATIM 2026-08-27: "The info should already be
# available - it's been loaded to display waveforms in the waveform viewer."
# The first A10 build did not read what the viewer holds -- it rebuilt a path
# out of the preferences and read THAT file, which is a different thing that
# happens to agree most of the time. This row is the case where they disagree:
# the waveform viewer is showing one results file and the preferences point at
# a different one, and the numbers that land on the sheet must be the ones the
# user is looking at.
# ⚠ THE TWO FILES CARRY DIFFERENT NUMBERS ON PURPOSE. The viewer's says 3 V at
# the 3 ns cursor; the one at the preferences path says 21 V. A build that
# reads the wrong file paints 21 and cannot pass.
# ⚠ AND THE CONTEXT COMES BACK. The borrow into the viewer's window is a loan;
# the last element is the design window being current again afterwards.
set ::netlist_dir $V_ND_DECOY
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
set v50_dw [xschem get current_win_path]
file copy -force $T_RAW $V_A10_VRUN
opa_v_viewer $V_A10_VRUN {set ::v50_state [opa_v_tran]}
set v50_att   $::opa_v_vw_ok
set v50_rf    [rcall {xschem raw rawfile}]
set v50_mask  [xschem get annot_show]
set v50_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v50_paint [opa_v_paint a10_vwfile]
set v50_back  [expr {[xschem get current_win_path] eq $v50_dw ? 1 : 0}]
opa_l_annot 0
catch {xschem raw clear}
## ⚠ THE SECOND PRESS IS THE USER'S OWN BENCH REPORT, AND IT USED TO BE THE
## WHOLE OF IT. Here there is NO candidate anywhere off the viewer -- the
## preferences point at an empty directory and the session names no file -- so
## the only place the results can come from is the window the user is looking
## at. This is the state the first A10 build still answered "NO RAW FILE
## loaded" in, because it keyed on the session metadata rather than on the
## viewer; measured, byte for byte, after that build shipped.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
opa_v_viewer $V_A10_VRUN {set ::v50b_state [opa_v_tran]}
set v50b_rf    [rcall {xschem raw rawfile}]
set v50b_paint [opa_v_paint a10_vwonly]
opa_l_annot 0
catch {xschem raw clear}
check {V50 issue 0881 the results file the WAVEFORM VIEWER is showing is the one that gets annotated, not a different file at the preferences path, and it is annotated even when there is no other candidate at all} \
  [list $v50_att $::v50_state $v50_rf $v50_mask $v50_msg $v50_paint $v50_back \
        $::v50b_state $v50b_rf $v50b_paint] \
  [list 1 ok [list 0 $V_A10_VRUN] 4 $V_MSG_OK3 $V_PINS_P3 1 \
        ok [list 0 $V_A10_VRUN] $V_PINS_P3]

# ===========================================================================
# V51 — THE VIEWER AND THE SHEET WOULD DISAGREE, SO NOTHING IS ANNOTATED
# ===========================================================================
# ⚠ RULING D5-1, MEASURED. The waveform viewer keeps its copy of the results in
# memory; the annotation reads the file again off disk into the schematic's own
# window. Re-running the simulator overwrites that file in place -- so the sheet
# would carry the NEW run's numbers while the traces beside it are still the OLD
# run's, with nothing anywhere saying so. Measured on the first A10 build: the
# waveform screen showing 3 V at the cursor and the schematic painting 30 V, no
# refusal, no warning.
# ⚠ SIX CLAIMS. The state is the named refusal; the CIW got it once, tagged as a
# warning; the held status line carries the same sentence and names the file;
# nothing is attached to the design window afterwards; the user's mask is
# untouched; and the sheet is bare.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
catch {xschem statusmsg -hold ZZA10SENTINEL}
set v51 [opa_v_spy {
  opa_v_viewer $V_A10_VRUN {
    ## the simulator runs again and overwrites the file the viewer read
    file copy -force $::V_A10_RUN2 $::V_A10_VRUN
    set ::v51_state [opa_v_tran]
  }
}]
set v51_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v51_ld    [rcall {xschem raw loaded}]
set v51_mask  [xschem get annot_show]
set v51_paint [opa_v_paint a10_vdiff]
opa_l_annot 0
catch {xschem raw clear}
check {V51 RULING D5-1 the results file changed under the waveform viewer, so the annotation refuses, says which file and why, attaches nothing and paints nothing} \
  [list $::v51_state $v51 $v51_msg $v51_ld $v51_mask $v51_paint] \
  [list viewerdiff [list [list warn $V_MSG_VDIFF]] $V_MSG_VDIFF {0 -1} 0 $V_PINS_NONE]

## The CODE lines of <body> that belong to ONE refusal arm: the lines from the
## `if` that OPENS that arm up to and including `return <state>`. Whole-line
## comments dropped first, so a paragraph naming a proc is never counted as a
## call to it -- issue 0682's measured hole.
##
## ⚠ THE SLICE IS ANCHORED ON THE ARM'S OWN `if`, NOT MERELY ON THE PREVIOUS
## `return`, AND ISSUE 0900 IS WHY. It used to start at the line after the last
## `return` above the arm, which is the same thing only while every statement in
## between belongs to some arm. It stopped being: the item A14 gate in
## `cadence::annot_tran` takes a database an EARLIER key press attached off the
## sheet before the supplier runs, and that `cadence::_annot_tran_unwind` call
## sits between `return nocursor` and `return staleraw` with no `return` in
## between. The old slice therefore handed the `staleraw`, `noraw`,
## `viewerunread`, `viewergone` and `viewerfilling` roll-call entries a call
## made ten lines and one nesting level away from them, and row V52's golden 0
## for each -- the whole "this arm attached nothing, so it must not detach
## anything" invariant -- would have had to be given up. The new anchor is a
## STRICT SUBSET of the old one, so the row can only get sharper: it still sees
## an unwind added inside any arm, and no longer sees one that is not in an arm
## at all. Falls back to the old anchor when no opening `if` is found, so no arm
## can silently come back with a slice LOOSER than it had.
proc opa_v_arm {body state} {
  set out {}
  foreach l [split $body \n] {
    if {[regexp {^\s*#} $l]} continue
    lappend out $l
  }
  set ri -1
  for {set i 0} {$i < [llength $out]} {incr i} {
    if {[string trim [lindex $out $i]] eq "return $state"} { set ri $i }
  }
  if {$ri < 0} { return {} }
  set start 0
  for {set i [expr {$ri - 1}]} {$i >= 0} {incr i -1} {
    if {[regexp {^\s*return\M} [lindex $out $i]]} { set start [expr {$i + 1}] ; break }
  }
  for {set i [expr {$ri - 1}]} {$i >= $start} {incr i -1} {
    if {[regexp {^\s*if\M.*\{\s*$} [lindex $out $i]]} { set start $i ; break }
  }
  return [join [lrange $out $start $ri] \n]
}
proc opa_v_hasunwind {body state} {
  set arm [opa_v_arm $body $state]
  if {$arm eq {}} { return -1 }
  return [expr {[regexp {_annot_tran_unwind} $arm] ? 1 : 0}]
}

# ===========================================================================
# V52 — PUTTING IT BACK: THE UNWIND ITSELF, AND WHICH REFUSALS OWE ONE
# ===========================================================================
# ⚠ ONE REFUSAL'S UNWIND HAS NO BEHAVIOURAL WITNESS AND CANNOT HAVE ONE.
# Issue 0871 measured that `nodata` is unreachable -- "no results loaded" and
# "the engine had nothing to resolve against" are the same predicate -- so a
# fixture that reaches it does not exist. A sabotage pass confirmed the
# consequence: deleting the unwind from that one arm leaves every check in the
# tree green. Deleting the guard is not the answer, because the arm becomes
# reachable the moment those two predicates come apart, and it would then
# publish an operating point out of a refusal exactly as the `notran` arm did.
# So the arm is pinned structurally, and the unwind ITSELF is pinned live.
# ⚠ LEGS 1 AND 2 DRIVE THE UNWIND FOR REAL. A database is attached and a mask
# armed by hand; the unwind must take both back, and must do NOTHING at all
# when told this press attached nothing -- a press that found a database
# already loaded must never detach the user's own results on its way out.
# ⚠ LEGS 3-9 SAY WHICH ARMS OWE ONE AND WHICH MUST NOT HAVE ONE. `nocursor`,
# `noraw`, the out-of-date-results refusal and the unreadable-viewer-file
# refusal all return BEFORE anything has been attached, so an unwind there
# would be a detach of somebody else's database. The three that return after
# the supply has attached one all owe it.
# ⚠ THE ROLL-CALL IS ONLY AS GOOD AS ITS COMPLETENESS, AND ISSUE 0894 IS WHERE
# IT WAS NOT COMPLETE. `viewerunread` (issue 0893) shipped as the ninth refusal
# with no entry here, and a sabotage that gave that arm an unwind it must not
# have -- the shape that, on any later edit moving the arm below `set attached
# 1`, would strip the numbers the user already had off their schematic as part
# of a refusal -- left every check in the tree green in BOTH arms. Every state
# `cadence::annot_tran` can return is now named: ok, nocursor, nodata, noraw,
# notran, staleraw, viewerdiff, viewerunread, viewergone, viewerfilling.
# ⚠ THE LAST TWO ARE ITEM A13's, for issues 0895 and 0896, and they must NOT
# have an unwind: both return above `set attached 1`, so an unwind there would
# detach a database this key press never attached -- somebody else's results,
# taken off the user's session by a refusal.
# ⚠ AND "THIS ARM ATTACHED NOTHING" IS NOT THE SAME SENTENCE AS "THE SHEET
# STILL CARRIES WHATEVER IT CARRIED", which is the distinction issue 0900 drew
# and which a reader of the six zeroes below would otherwise get wrong. Since
# item A14 every press first asks the waveform window whether the database the
# design window is already holding is still the run on screen, and if it is not,
# that database comes off IN THE GATE, before the supplier reads anything. So a
# session that WAS holding numbers has already had them taken off by the time
# any of these six refusals speaks -- which is what makes their shipped clause
# "so nothing was placed on the schematic" true of the sheet the user is
# looking at. Row V67 is the row that proves the numbers really come off, and
# row V69 leg 5 pins the ordering. What the six zeroes here still say, and the
# only thing they say, is that the refusal ARM itself detaches nothing: it is a
# claim about these `if` bodies, and `opa_v_arm` above is anchored on each arm's
# own `if` so that it stays one.
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
catch {xschem annotate_op $T_OPRAW}
opa_l_annot 6
set v52_pre  [list [rcall {xschem raw loaded}] [xschem get annot_show]]
set v52_did  [rcall {cadence::_annot_tran_unwind 1 2}]
set v52_post [list [rcall {xschem raw loaded}] [xschem get annot_show]]
catch {xschem raw clear}
opa_l_annot 0
catch {xschem annotate_op $T_OPRAW}
opa_l_annot 6
set v52_noop [rcall {cadence::_annot_tran_unwind 0 2}]
set v52_kept [list [rcall {xschem raw loaded}] [xschem get annot_show]]
opa_l_annot 0
catch {xschem raw clear}
set V_A10_TRN2 [opa_proc_src [opa_slurp [file join $repo utils annot_mode.tcl]] cadence::annot_tran]
check {V52 a refusal PUTS BACK what the press attached, does nothing when the press attached nothing, and every arm that owes an unwind has one} \
  [list $v52_pre $v52_did $v52_post \
        $v52_noop $v52_kept \
        [opa_v_hasunwind $V_A10_TRN2 notran] \
        [opa_v_hasunwind $V_A10_TRN2 nodata] \
        [opa_v_hasunwind $V_A10_TRN2 viewerdiff] \
        [opa_v_hasunwind $V_A10_TRN2 nocursor] \
        [opa_v_hasunwind $V_A10_TRN2 noraw] \
        [opa_v_hasunwind $V_A10_TRN2 staleraw] \
        [opa_v_hasunwind $V_A10_TRN2 viewerunread] \
        [opa_v_hasunwind $V_A10_TRN2 viewergone] \
        [opa_v_hasunwind $V_A10_TRN2 viewerfilling]] \
  [list {{0 0} 6} {0 1} {{0 -1} 2} \
        {0 0} {{0 0} 6} \
        1 1 1 0 0 0 0 0 0]

# ===========================================================================
# V53 — THE STAND-IN IS A REAL, LIVE Tk TOPLEVEL, WHICH IS WHAT THE PRODUCT
#       CONSULTS  (issue 0891)
# ===========================================================================
# ⚠ THIS IS THE ROW ISSUE 0891 SHOWS THE TREE NEVER HAD, and it is the one that
# reds the instant the waveform stand-in goes back to being a TAB. The shipped
# consult asks two questions of the viewer that only a display can answer --
# `wviewer::window_for` hands back the registry's TOPLEVEL, and
# `cadence::_annot_viewer_db` then asks `winfo exists` of it before it will
# borrow. Under --nogui neither question is even reachable, so V50 and V51 were
# green on the arm nobody uses and red on the arm the user has.
# ⚠ FIVE CLAIMS, and the middle three are the whole point: the viewer's window
# answer is not empty; it is NOT the drawing canvas but the toplevel above it;
# that toplevel really exists as a Tk widget; it is its own toplevel; and the
# shipped consult, asked directly, comes back with the file the WAVEFORM WINDOW
# is showing rather than nothing at all.
if {![info exists has_x]} {
  puts "skip: V53 needs a display - winfo does not exist under --nogui, so the Tk liveness probe in cadence::_annot_viewer_db, which is the thing under test, is never reached"
} else {
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
set ::v53 {}
opa_v_viewer $V_A10_VRUN {
  set v53t {}
  catch {set v53t [::wviewer::window_for zzA10vw]}
  set v53a [expr {$v53t ne {} ? 1 : 0}]
  set v53b [expr {$v53t ne $::opa_v_vw_path ? 1 : 0}]
  set v53c 0
  catch {if {[winfo exists $v53t]} { set v53c 1 }}
  set v53d 0
  catch {if {[winfo toplevel $v53t] eq $v53t} { set v53d 1 }}
  set v53db {}
  catch {set v53db [cadence::_annot_viewer_db]}
  set v53e [expr {[llength $v53db] == 3 && [lindex $v53db 0] eq $::V_A10_VRUN ? 1 : 0}]
  ## ⚠ THE SIXTH LEG IS ITEM A13's, and it reds ONLY on the display arm --
  ## which is a live demonstration of why every A13 row also runs here. The
  ## consult now says WHICH of its answers it is giving, and for a good file
  ## the answer is `ok`; an empty fingerprint and a matching one may never
  ## again read the same (issues 0895, 0896).
  set v53f [expr {[lindex $v53db 2] eq {ok} ? 1 : 0}]
  set ::v53 [list $v53a $v53b $v53c $v53d $v53e $v53f]
}
opa_l_annot 0
catch {xschem raw clear}
check {V53 issue 0891 the waveform window the annotation borrows into is a real live Tk toplevel, not the drawing canvas of a tab, and the shipped consult finds the file it is showing AND says which answer it is giving} \
  $::v53 [list 1 1 1 1 1 1]
}

## The CODE lines of <src>, whole-line Tcl comments dropped, so a paragraph
## quoting a call is never read as the call. Section A11 has the same tool, but
## it is defined 200 lines further down and section V runs first -- the same
## ordering trap that made the first run of these rows raise instead of red.
proc opa_v_code {src} {
  set out {}
  foreach l [split $src \n] {
    if {[regexp {^\s*#} $l]} continue
    lappend out $l
  }
  return [join $out \n]
}

# ===========================================================================
# V54 — STRUCTURAL: THE FIXTURE MODELS THE WINDOW THE PRODUCT ACTUALLY BUILDS
# ===========================================================================
# ⚠ WITHOUT THIS ROW, DELETING V53's SUBJECT REDS NOTHING WHERE ANYONE LOOKS.
# V53 can only run on a display, and the everyday runner is headless -- that
# combination IS issue 0891. So the shape of the stand-in is asserted as source
# text too, in BOTH arms: the fixture must stand its waveform window up on the
# same verb the shipped viewer uses, and must hand back the same registry field
# the shipped `wviewer::window_for` hands back.
# ⚠ THE FIRST THREE LEGS ARE THE PRODUCT'S OWN CONTRACT, read from
# src/wave_viewer.tcl -- window_for answers the TOPLEVEL and checks it is alive,
# while enter_ctx switches to the WIN_PATH. A fixture that conflates the two is
# a fixture that cannot see the defect, which is exactly what happened.
set V54_WV   [opa_v_code [opa_slurp [file join $repo src wave_viewer.tcl]]]
set V54_SELF [opa_v_code [opa_slurp [file join $repo tests headless test_op_annot.tcl]]]
set V54_WFOR [opa_proc_src $V54_WV wviewer::window_for]
set V54_ENT  [opa_proc_src $V54_WV wviewer::enter_ctx]
set V54_FIX  [opa_proc_src $V54_SELF opa_v_viewer]
check {V54 issue 0891 STRUCTURAL the waveform stand-in is built on the verb the real viewer uses and answers the registry field the real viewer answers} \
  [list [regexp {dict get \$windows \$token top}      $V54_WFOR] \
        [regexp {winfo exists}                        $V54_WFOR] \
        [regexp {dict get \$windows \$token win_path} $V54_ENT] \
        [regexp {\$::opa_v_vw_top}                    $V54_FIX] \
        [regexp {load_new_window\s+-window}           $V54_FIX]] \
  [list 1 1 1 1 1]

# ===========================================================================
# V55 — ISSUE 0893: THE REFUSAL MUST NOT BLAME A MISSING RESULTS FILE WHILE
#       THE WAVEFORM WINDOW IS PLOTTING IT
# ===========================================================================
# ⚠ THE USER IS LOOKING AT THE TRACES. The waveform window holds a transient in
# memory and the annotation goes to read that same file off disk again -- and
# cannot, because the simulator is rewriting it or it is truncated. Today the
# user is told "No simulation results are loaded, so there are no voltages to
# show. Run a simulation first, then try again." with the results plainly on
# screen. The refusal is right; the reason is wrong, and a wrong reason is the
# same defect class as a wrong number.
# ⚠ SIX CLAIMS, the same six V51 makes, because this is V51's sibling: the
# state is its own named refusal and NOT the no-results one; the CIW got the
# sentence once, tagged as a warning; the held status line carries it and names
# the file the WAVEFORM WINDOW is showing; nothing is attached afterwards; the
# user's mask is untouched; the sheet is bare.
set V_MSG_VUNREAD "The waveform window is showing the results file [file tail $V_A10_VRUN], but that file could not be read again just now, so nothing was placed on the schematic. Plot the results again in the waveform window, then try again."
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
catch {xschem statusmsg -hold ZZA10SENTINEL}
set v55 [opa_v_spy {
  opa_v_viewer $V_A10_VRUN {
    ## the file goes unreadable under the viewer -- the simulator is rewriting
    ## it, or it was truncated -- while the traces stay on screen
    file copy -force [file join $::V_ND_JUNK v_cand.raw] $::V_A10_VRUN
    set ::v55_state [opa_v_tran]
  }
}]
set v55_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v55_ld    [rcall {xschem raw loaded}]
set v55_mask  [xschem get annot_show]
set v55_paint [opa_v_paint a10_vunread]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V55 issue 0893 the results file the waveform window is showing cannot be read again, so the refusal says THAT and not that no results are loaded} \
  [list $::v55_state $v55 $v55_msg $v55_ld $v55_mask $v55_paint] \
  [list viewerunread [list [list warn $V_MSG_VUNREAD]] $V_MSG_VUNREAD {0 -1} 0 $V_PINS_NONE]

# ===========================================================================
# V56 — STRUCTURAL: THE Tk LIVENESS PROBE IN THE CONSULT
# ===========================================================================
# ⚠ NO BEHAVIOURAL ROW IN THE TREE CAN SEE THIS GUARD, measured. A second guard
# covers the same case from the other side -- `wviewer::enter_ctx` refuses an
# unregistered token on its own -- so deleting the liveness probe leaves every
# behavioural row green. Per this branch's own lesson, a guard no behavioural
# row can see gets a STRUCTURAL row rather than nothing.
# ⚠ AND IT IS THE STATEMENT ISSUE 0891 TURNS ON. It asks a legitimate question
# of a legitimate value; the answer for a dead viewer must be to decline the
# borrow and hand back nothing, never to borrow into a window that is not there.
set V56_DB [opa_v_code [opa_proc_src [opa_slurp [file join $repo utils annot_mode.tcl]] cadence::_annot_viewer_db]]
check {V56 issue 0891 STRUCTURAL the consult asks whether the waveform window is still alive before it borrows, and declines when it is not} \
  [list [regexp {info commands ::winfo} $V56_DB] \
        [regexp {winfo exists \$top}    $V56_DB] \
        [regexp {!\$live[^\n]*return}   $V56_DB]] \
  [list 1 1 1]

# ===========================================================================
# V57 — STRUCTURAL: A DISPLAY ARM OF THIS SUITE IS REACHABLE FROM THE RUNNER
# ===========================================================================
# ⚠ THIS ROW IS THE HALF OF ISSUE 0891 THAT IS ABOUT THE HARNESS, NOT THE
# FEATURE. The red lived for a whole feature because tests/run_regression.tcl
# hard-codes --nogui for every headless case, so the arm the user actually has
# was never run by the everyday runner at all. Restoring the arm and then
# leaving nothing to notice its removal would set the trap again, so the claim
# that the arm EXISTS is asserted here, in the suite, in both arms.
# ⚠ SIX LEGS: the suite is still in the headless list; it is ALSO in a second,
# display list; that list is driven by a loop; the loop's LAUNCH LINE routes
# through the persistent dev display helper rather than a bare screen; the loop
# does not pass --nogui, which would silently make it a duplicate of the
# headless arm; and the summary CLASSIFIER surfaces an unavailable display
# instead of scoring it green.
# ⚠ TWO OF THOSE LEGS WERE DEAD ON ARRIVAL, WHICH IS ISSUE 0894, AND HOW THEY
# DIED IS WORTH THE NEXT READER'S TIME BECAUSE BOTH TRAPS ARE GENERIC.
#   * The routing leg used to grep the WHOLE loop for `devdisplay.sh|$dd`.
#     Measured: strip the routing out entirely -- so the everyday runner opens a
#     real xschem window on whatever screen it was started from, on this box the
#     human's own -- and the leg still answered 1, twice over: the liveness
#     variable is named `$dd_alive`, and the sentence the runner prints when no
#     dev display is up literally contains the words `devdisplay.sh start`. A
#     grep over a whole block matches the PROSE about the thing as readily as
#     the thing. So the leg now isolates the one line that launches the binary
#     and demands the routing be on THAT line.
#   * The classifier leg used to grep `opa_proc_src`'s slice of `summarize_all`
#     for `NODISPLAY`. But run_regression.tcl contains exactly ONE proc, and
#     opa_proc_src ends a proc at the next `\nproc ` -- so the slice ran to end
#     of file and swallowed the display loop, whose own printed message says
#     NODISPLAY. Revert the classifier and the leg still answered 1. The slice
#     is now taken by brace matching, and the leg asserts the ALTERNATION that
#     only the classifier line carries.
proc opa_v_block {src re {op "\{"} {cl "\}"}} {
  set lines [split $src \n]
  set n [llength $lines]
  set start -1
  for {set i 0} {$i < $n} {incr i} {
    if {[regexp -- $re [lindex $lines $i]]} { set start $i ; break }
  }
  if {$start < 0} { return {} }
  set depth 0 ; set seen 0 ; set out {}
  for {set i $start} {$i < $n} {incr i} {
    set l [lindex $lines $i]
    lappend out $l
    foreach ch [split $l {}] {
      if {$ch eq $op} { incr depth ; set seen 1 } elseif {$ch eq $cl} { incr depth -1 }
    }
    if {$seen && $depth <= 0} { break }
  }
  return [join $out \n]
}
set V57_RR   [opa_v_code [opa_slurp [file join $repo tests run_regression.tcl]]]
set V57_LOOP [opa_v_block $V57_RR {foreach\s+\w+\s+\$dcases}]
set V57_SUM  [opa_v_block $V57_RR {proc\s+summarize_all}]
## The ONE line in the loop that starts the binary. Issue 0894: a routing claim
## has to be made about the launch, not about the block the launch sits in.
set V57_LAUNCH {}
foreach _l57 [split $V57_LOOP \n] {
  if {[regexp -- {\$xschem_cmd} $_l57]} { set V57_LAUNCH $_l57 }
}
## ⚠ THE SEVENTH LEG IS ITEM A13's, AND IT IS THE SAME TRAP ONE SUITE ALONG.
## The rows that drive the REAL supply chain -- a waveform window opened by the
## product's own `wviewer::open` and filled by its own `wviewer::attach_raw` --
## live in tests/headless/test_annot_show_menu.tcl and can only run on a
## display. Registering them and leaving nothing to notice the registration
## being removed would put issue 0891's trap straight back: the everyday runner
## would go on saying zero failures while the acceptance rows stopped running.
check {V57 issue 0891 STRUCTURAL the everyday regression runner also runs this suite AND the menu suite on the persistent dev display, and says so when that display is not there} \
  [list [regexp {headless/test_op_annot} [opa_v_block $V57_RR {set\s+hcases} "\[" "\]"]] \
        [regexp {set\s+dcases[^\n]*headless/test_op_annot} $V57_RR] \
        [expr {$V57_LOOP ne {} ? 1 : 0}] \
        [expr {$V57_LAUNCH ne {} && [regexp {(devdisplay\.sh|\$dd)\s+exec} $V57_LAUNCH] ? 1 : 0}] \
        [expr {$V57_LOOP ne {} && ![regexp -- {--nogui} $V57_LOOP] ? 1 : 0}] \
        [regexp {NOGOLD\|NODISPLAY} $V57_SUM] \
        [regexp {set\s+dcases[^\n]*headless/test_annot_show_menu} $V57_RR]] \
  [list 1 1 1 1 1 1 1]

# ===========================================================================
# V58 .. V63 — ITEM A13 / ISSUES 0896 + 0895: ONE CONFLATION, THREE FACES
# ===========================================================================
# ⚠ THE SHARED ROOT, AND IT IS ONE EXPRESSION. `$vprint` -- the fingerprint the
# consult hands back -- is being used to stand in for "the consult succeeded".
# A fingerprint that is EMPTY and a fingerprint that MATCHES are different
# answers, and today's code cannot tell them apart. Everything below is that
# one conflation seen from a different side:
#
#   V58  the waveform window is showing a run that has not produced a point
#        yet, the finished and DIFFERENT run lands at the same path, and the
#        two-window compare is SILENTLY SKIPPED -- so another run's numbers
#        reach the schematic under the caption "Showing each node's voltage
#        at 3 ns". Issue 0896, and a live RULING D5-1 breach     <- RED before
#   V59  the same run still filling with NOTHING overwritten: the caption says
#        the voltages are on the sheet while the sheet is bare   <- RED before
#   V60  the waveform window's results file is DELETED while the traces stay
#        on screen, and the refusal blames a missing results file. Issue 0895,
#        a wrong REASON, which is the same defect class as a wrong number
#                                                                <- RED before
#   V61  0895's sharper face: a perfectly good but DIFFERENT results file sits
#        at the preferences path, so the deleted-file case does not merely say
#        the wrong thing, it annotates the wrong run             <- RED before
#   V62  STRUCTURAL: an empty fingerprint and a matching fingerprint produce
#        DIFFERENT states, and the compare can no longer be skipped
#                                                                <- RED before
#   V63  the consult's answer, asked directly, in BOTH arms      <- RED before
#   V64  a waveform window that is showing an OPERATING POINT, or holding
#        nothing at all, must not hijack the annotation and must not produce a
#        refusal about a file nobody named -- issue 0899   <- RED on A13's fix
#   V65  the run has produced nothing AND its file is gone: the user is told
#        about the deleted file, which is the one they can act on
#                                                          <- RED on A13's fix
#
# ⚠ EVERY ROW HERE RUNS ON BOTH ARMS. Item A12 spent a whole item establishing
# that a row which only runs headless is a row that hides a defect; V53 is the
# display-only row and it is edited rather than copied.

## THE FILE A RUN LEAVES WHILE IT IS STILL GOING. ngspice writes a well-formed
## header with `No. Points: 0` and fills the values in as it goes -- issue 0836
## measured this and its own suite calls it "THE ORDINARY CASE, NOT A CORNER".
## The read SUCCEEDS and the database ATTACHES, which is exactly how the
## waveform window can watch a run fill; what it cannot do is produce a
## fingerprint, because there is no last point to fingerprint.
set V_A13_ZERO [file join $scratch v_a13_zero.raw]
set V_ZHDR $V_T_HDR
regsub {No\. Points: 5} $V_ZHDR {No. Points: 0} V_ZHDR
opa_t_wr $V_A13_ZERO $V_ZHDR

## A PATH THAT IS DELIBERATELY NOT THERE, so a waveform window can be stood up
## that is genuinely in play and yet holds nothing. Deleted rather than assumed
## absent: an earlier section leaving a file at this name would hollow out rows
## V63 leg e and V64's second face without reddening anything.
set V_A13_ABSENT [file join $scratch v_a13_absent.raw]
catch {file delete -force $V_A13_ABSENT}

## THE TWO NEW SENTENCES. NEW WORDING THE USER HAS NOT RATIFIED -- one `look`
## debt each and one `rule` debt, because the wording was invented here. Both
## say WHAT HAPPENED, give the CONTEXT that makes it make sense, and end with
## what the user can do, which is the user's PLAIN ENGLISH ruling made
## mechanical by row A11-11.
set V_MSG_VGONE "The waveform window is showing the results file [file tail $V_A10_VRUN], but that file is no longer on disk, so nothing was placed on the schematic. If a simulation is running, wait for it to finish, then try again."
set V_MSG_VFILL "The waveform window is showing the results file [file tail $V_A10_VRUN], but the run has not produced any values yet, so nothing was placed on the schematic. Wait for the simulation to finish, then try again."

# ===========================================================================
# V58 — ISSUE 0896's ACCEPTANCE: ANOTHER RUN'S NUMBERS MUST NOT LAND
# ===========================================================================
# ⚠ RULING D5-1, MEASURED 2026-08-28 ON BOTH ARMS. The user is watching a
# transient fill in the waveform window. The simulator finishes and writes the
# completed run over the same path. The user presses the chord -- and because
# the file the waveform window is showing has no points yet, its fingerprint is
# empty, the two-window compare never runs, and the FINISHED run's numbers are
# painted on the sheet under "Showing each node's voltage at 3 ns, where cursor
# B is on the waveform." No refusal. No warning. The numbers the caption claims
# to describe are precisely the ones that are NOT on the user's screen, which
# is why the INTENT ruling does not rescue this: its premise is that the
# numbers are already there.
# ⚠ LEG 1 IS THE NON-VACUITY AND IT IS NOT OPTIONAL, in row V46's discipline.
# The same decoy file, the same sheet, the same cursor and the same mask,
# reached through the product's own supply, really does paint 21 V beside node
# `d`. A row asserting only that nothing was painted would be satisfied by a
# fixture that could not paint at all.
# ⚠ AND THE LAST LEG NAMES THE LITERAL. `d 21 g 0.1 0 0.0 0 0.0` is the other
# run, byte for byte, and it must not appear on this sheet.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
opa_v_ase $V_A10_RUN2 0 {set ::v58_ctl_state [opa_v_tran]}
set v58_ctl [opa_v_paint a13_ctl]
opa_l_annot 0
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $V_A13_ZERO $V_A10_VRUN
catch {xschem statusmsg -hold ZZA13SENTINEL}
set v58 [opa_v_spy {
  opa_v_viewer $V_A10_VRUN {
    ## the run finishes and the completed, DIFFERENT run lands at the same path
    file copy -force $::V_A10_RUN2 $::V_A10_VRUN
    set ::v58_state [opa_v_tran]
  }
}]
set v58_att   $::opa_v_vw_ok
set v58_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v58_ld    [rcall {xschem raw loaded}]
set v58_mask  [xschem get annot_show]
set v58_paint [opa_v_paint a13_fill]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V58 issue 0896 RULING D5-1 a run that is still filling cannot be compared with the file on disk, so the finished run's numbers are NOT painted and the user is told the run has not produced values yet} \
  [list $v58_ctl $::v58_ctl_state $v58_att $::v58_state $v58 $v58_msg $v58_ld $v58_mask $v58_paint \
        [expr {$v58_paint ne $V_PINS_OTHER ? 1 : 0}]] \
  [list $V_PINS_OTHER ok 1 viewerfilling [list [list warn $V_MSG_VFILL]] $V_MSG_VFILL {0 -1} 0 \
        $V_PINS_NONE 1]

# ===========================================================================
# V59 — ISSUE 0896's QUIETER FACE: A CONFIDENT CAPTION OVER A BARE SHEET
# ===========================================================================
# ⚠ IN NEITHER ISSUE FILE, AND IT IS A LIVE FALSE SUCCESS ON ITS OWN. Nothing
# has been overwritten here: the waveform window and the disk are holding the
# very same still-filling file. Measured today, both arms -- the state is `ok`,
# the transient bit is armed, and the status line says "Showing each node's
# voltage at 3 ns, where cursor B is on the waveform." over a COMPLETELY BARE
# schematic. Fixing the conflation closes this for free, because the refusal
# now happens before anything is published at all.
# ⚠ THE LAST LEG IS AN INEQUALITY ON PURPOSE. Asserting the sentence is not the
# `ok` one survives a future reword of the `ok` sentence; asserting a literal
# would hollow out the moment somebody edits it.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $V_A13_ZERO $V_A10_VRUN
opa_v_viewer $V_A10_VRUN {set ::v59_state [opa_v_tran]}
set v59_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v59_mask  [xschem get annot_show]
set v59_paint [opa_v_paint a13_still]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V59 issue 0896 a run that has produced no values yet must not report success over a bare schematic} \
  [list $::v59_state $v59_mask $v59_paint [expr {$v59_msg ne $V_MSG_OK3 ? 1 : 0}]] \
  [list viewerfilling 0 $V_PINS_NONE 1]

# ===========================================================================
# V60 — ISSUE 0895: THE REFUSAL MUST NAME WHAT ACTUALLY HAPPENED
# ===========================================================================
# ⚠ ROW V55's SIBLING, AND ITS COMMONEST REAL TRIGGER. Issue 0893 gave the
# annotation a truthful sentence for a results file that cannot be READ again;
# most simulators do not rewrite in place, they unlink and re-create, so the
# file is ABSENT rather than corrupt -- and the consult gives up before 0893's
# guard can see it. The user is looking at the traces drawn from that very
# database and is told "No simulation results are loaded".
# ⚠ SEVEN CLAIMS, V55's six plus one. The seventh asserts the WRONG sentence is
# gone, not merely that some sentence appeared: a wrong reason is the defect,
# so a row that only checked that something was said could not see the fix.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
catch {xschem statusmsg -hold ZZA13SENTINEL}
set v60 [opa_v_spy {
  opa_v_viewer $V_A10_VRUN {
    ## the simulator unlinks the file it is about to re-create, while the
    ## waveform window keeps holding and plotting what it already read
    file delete -force $::V_A10_VRUN
    set ::v60_state [opa_v_tran]
  }
}]
set v60_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v60_ld    [rcall {xschem raw loaded}]
set v60_mask  [xschem get annot_show]
set v60_paint [opa_v_paint a13_gone]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V60 issue 0895 the waveform window's results file was deleted, so the refusal says THAT and names the file, instead of claiming no results are loaded} \
  [list $::v60_state $v60 $v60_msg $v60_ld $v60_mask $v60_paint \
        [expr {$v60_msg ne $V_MSG_NORAW ? 1 : 0}]] \
  [list viewergone [list [list warn $V_MSG_VGONE]] $V_MSG_VGONE {0 -1} 0 $V_PINS_NONE 1]

# ===========================================================================
# V61 — 0895's SHARPER FACE, AND DRIVER RULING 1's ONLY BEHAVIOURAL WITNESS
# ===========================================================================
# ⚠ THE RULING, VERBATIM: "Never fall through to the file on disk when the two
# windows cannot be compared." V60's fixture has nothing at the preferences
# path, so the wrong sentence is all the user gets. Put a perfectly good but
# DIFFERENT results file there -- the ordinary case, a previous run of the same
# cell -- and the fall-through does not merely say the wrong thing: it
# ANNOTATES THE WRONG RUN, with no compare possible, which is issue 0896's
# family reached from 0895's side.
# ⚠ LEG 1 IS THE NON-VACUITY. With no waveform window in play the same decoy at
# the same path paints 21 V, so a fixture that could not paint cannot pass.
set ::netlist_dir $V_ND_DECOY
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
set ::v61_ctl_state [opa_v_tran]
set v61_ctl [opa_v_paint a13_decoyctl]
opa_l_annot 0
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
opa_v_viewer $V_A10_VRUN {
  file delete -force $::V_A10_VRUN
  set ::v61_state [opa_v_tran]
}
set v61_ld    [rcall {xschem raw loaded}]
set v61_mask  [xschem get annot_show]
set v61_paint [opa_v_paint a13_gonedecoy]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V61 issue 0895 with the waveform window's file deleted the annotation must NOT fall through to a different run sitting at the preferences path} \
  [list $v61_ctl $::v61_ctl_state $::v61_state $v61_ld $v61_mask $v61_paint \
        [expr {$v61_paint ne $V_PINS_OTHER ? 1 : 0}]] \
  [list $V_PINS_OTHER ok viewergone {0 -1} 0 $V_PINS_NONE 1]

## The 0-based index of the FIRST code line of <body> matching <re>, whole-line
## Tcl comments dropped so a paragraph naming a call is never read as the call.
## -1 when there is none. Row V62 leg 5 compares two of these, which is how an
## ordering guard becomes a measurement instead of a promise.
proc opa_v_lineidx {body re} {
  set i 0
  foreach l [split $body \n] {
    if {![regexp {^\s*#} $l] && [regexp -- $re $l]} { return $i }
    incr i
  }
  return -1
}

# ===========================================================================
# V62 — STRUCTURAL: AN EMPTY FINGERPRINT AND A MATCHING ONE ARE DIFFERENT
#       ANSWERS
# ===========================================================================
# ⚠ THREE OF THESE FIVE LEGS ARE THINGS NO BEHAVIOURAL ROW IN THE TREE CAN SEE,
# and per this branch's own rule that is exactly why they are here rather than
# nowhere. Legs 2, 3 and 5 stay green under every fixture that exists while the
# guard they name is deleted, because the refusals above them have already
# returned -- that is defence in depth working, and the honest way to pin it is
# structurally.
#   1  the consult CLASSIFIES its answer instead of giving up: it names the
#      deleted-file case, names the no-points-yet case, and has no line that
#      answers a bare {} to an absent file. That last one is the whole of
#      issue 0895 -- "no waveform window in play" and "the window's file is
#      gone" must stop being the same answer.
#   2  the supplier never reads the fingerprint's LENGTH again. That expression
#      is the conflation itself; while it survives anywhere in the supplier the
#      two questions are still being asked as one.
#   3  the two-window compare is gated on whether the CONSULT succeeded, not on
#      whether a fingerprint happened to be computable, so a SKIPPED compare
#      becomes structurally impossible rather than merely unlikely.
#   4  the supplier names each new refusal exactly once.
#   5  both new refusals return BEFORE the supplier ever hands a file to the
#      annotate verb, which is the "nothing was attached, so no unwind is owed"
#      invariant made measurable. Row V52's roll-call cannot catch this: it only
#      asks whether an unwind EXISTS, which is issue 0894's exact shape.
set V62_SRC [opa_slurp [file join $repo utils annot_mode.tcl]]
set V62_DB  [opa_v_code [opa_proc_src $V62_SRC cadence::_annot_viewer_db]]
set V62_SUP [opa_v_code [opa_proc_src $V62_SRC cadence::_annot_tran_supply]]
set v62_cmpgate 0
foreach _l62 [split $V62_SUP \n] {
  if {[regexp {^\s*#} $_l62]} continue
  if {[regexp {_annot_db_print} $_l62]} {
    set v62_cmpgate [expr {[regexp {\$vseen} $_l62] ? 1 : 0}]
  }
}
set v62_iao   [opa_v_lineidx $V62_SUP {annotate_op}]
set v62_igone [opa_v_lineidx $V62_SUP {viewergone}]
set v62_ifill [opa_v_lineidx $V62_SUP {viewerfilling}]
check {V62 issues 0895+0896 STRUCTURAL the consult says WHICH answer it is giving, the supplier stops reading the fingerprint's length, the compare is gated on the consult and both new refusals return before anything is attached} \
  [list [expr {[string length $V62_DB] > 0 ? 1 : 0}] \
        [expr {[opa_v_pgrep $V62_DB {filegone}] >= 1 ? 1 : 0}] \
        [expr {[opa_v_pgrep $V62_DB {nopoints}] >= 1 ? 1 : 0}] \
        [opa_v_pgrep $V62_DB {!\[file exists \$path\][^\n]*return \{\}}] \
        [opa_v_pgrep $V62_SUP {llength \$vprint}] \
        $v62_cmpgate \
        [opa_v_pgrep $V62_SUP {viewergone}] \
        [opa_v_pgrep $V62_SUP {viewerfilling}] \
        [expr {$v62_igone >= 0 && $v62_ifill >= 0 && $v62_iao > $v62_igone \
               && $v62_iao > $v62_ifill ? 1 : 0}]] \
  [list 1 1 1 0 0 1 1 1 1]

# ===========================================================================
# V63 — THE CONSULT'S ANSWER, ASKED DIRECTLY, ON THE ARM V53 CANNOT REACH
# ===========================================================================
# ⚠ V53 IS DISPLAY-ONLY, so the SHAPE of the consult's answer is unwitnessed
# headless -- and issue 0891 is the whole story of what a display-only row
# costs. This asks the shipped consult the same question four times, in both
# arms, and it is the row that shows an empty fingerprint and a matching one
# producing different answers directly rather than through a paint.
#   a  a finished run           -> the path, a fingerprint, and `ok`
#   b  a run with no points yet -> the path, an EMPTY fingerprint, `nopoints`
#   c  the file deleted         -> the path, a fingerprint, `filegone`
#   d  no waveform window at all -> nothing, which is the ONE meaning an empty
#      answer is allowed to have from now on
#   e  a waveform window that IS in play and holds NOTHING -> nothing
#   f  a waveform window that IS in play and is showing an OPERATING POINT
#      rather than a transient -> nothing
#   g  a run with no points yet whose file is then DELETED -> `filegone`, which
#      is the PRECEDENCE and not merely the spelling
#
# â  LEGS e, f AND g ARE ITEM A13's REPAIR, AND THEY EXIST BECAUSE THE SABOTAGE
# PASS COULD NOT SEE TWO OF THE ITEM'S OWN GUARDS (issue 0899). Legs a-d walked
# straight past `if {$path eq {}} { return {} }`: leg d has no waveform window
# at all, so the consult exits at the window guard several lines ABOVE and that
# line is never reached. Delete the line and, measured, a viewer holding an
# operating point answers `{{} {} filegone}` -- a refusal naming NO file, on a
# session whose own results file was sitting readable on disk. Legs e and f are
# the two ways a window can be in play holding nothing this mode can use, and
# row V64 is the same defect seen from the schematic. Leg g is the ORDER: legs
# b and c pin the two spellings but each makes only one of the two tests true,
# so swapping the two lines was invisible to every row in the tree; here both
# are true at once and only the shipped order answers `filegone`. Row V65 is
# that one seen from the schematic.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
file copy -force $T_RAW $V_A10_VRUN
set ::v63a {}
opa_v_viewer $V_A10_VRUN {
  set v63d1 {}
  catch {set v63d1 [cadence::_annot_viewer_db]}
  set ::v63a [list [llength $v63d1] [lindex $v63d1 2] \
                   [expr {[llength [lindex $v63d1 1]] > 0 ? 1 : 0}] \
                   [expr {[lindex $v63d1 0] eq $::V_A10_VRUN ? 1 : 0}]]
}
file copy -force $V_A13_ZERO $V_A10_VRUN
set ::v63b {}
opa_v_viewer $V_A10_VRUN {
  set v63d2 {}
  catch {set v63d2 [cadence::_annot_viewer_db]}
  set ::v63b [list [llength $v63d2] [lindex $v63d2 2] [llength [lindex $v63d2 1]] \
                   [expr {[lindex $v63d2 0] eq $::V_A10_VRUN ? 1 : 0}]]
}
file copy -force $T_RAW $V_A10_VRUN
set ::v63c {}
opa_v_viewer $V_A10_VRUN {
  file delete -force $::V_A10_VRUN
  set v63d3 {}
  catch {set v63d3 [cadence::_annot_viewer_db]}
  set ::v63c [list [llength $v63d3] [lindex $v63d3 2] \
                   [expr {[lindex $v63d3 0] eq $::V_A10_VRUN ? 1 : 0}]]
}
file copy -force $T_RAW $V_A10_VRUN
set v63d {}
catch {set v63d [cadence::_annot_viewer_db]}
## e -- the window is REAL and the borrow SUCCEEDS; it just holds nothing. The
## second element of each pair is the fixture's own honesty check: the viewer
## really did fail to attach anything, so a fixture that quietly attached the
## file anyway cannot pass this leg by accident.
set ::v63e {}
opa_v_viewer $V_A13_ABSENT {
  set v63d5 {}
  catch {set v63d5 [cadence::_annot_viewer_db]}
  set ::v63e [list [llength $v63d5] $::opa_v_vw_ok]
}
## f -- the window holds a DC operating point, which is a database this mode
## must not divert to and must not complain about either.
set ::v63f {}
opa_v_viewer $V_A10_OPTRAN {
  set v63d6 {}
  catch {set v63d6 [cadence::_annot_viewer_db]}
  set ::v63f [list [llength $v63d6] $::opa_v_vw_ok $::opa_v_vw_st]
} op
## g -- BOTH classification tests are true at once: the run has produced no
## point AND its file has been unlinked. The shipped order says the deleted
## file wins, because that is the complaint the user can act on.
file copy -force $V_A13_ZERO $V_A10_VRUN
set ::v63g {}
opa_v_viewer $V_A10_VRUN {
  file delete -force $::V_A10_VRUN
  set v63d7 {}
  catch {set v63d7 [cadence::_annot_viewer_db]}
  set ::v63g [list [llength $v63d7] [lindex $v63d7 2] [llength [lindex $v63d7 1]]]
}
file copy -force $T_RAW $V_A10_VRUN
opa_l_annot 0
catch {xschem raw clear}
check {V63 issues 0895+0896 the consult reports WHICH of its answers it is giving, so an empty fingerprint and a matching fingerprint can never read the same, a window holding nothing usable is still no answer at all, and a deleted file outranks a run with no points yet} \
  [list $::v63a $::v63b $::v63c [llength $v63d] $::v63e $::v63f $::v63g] \
  [list {3 ok 1 1} {3 nopoints 0 1} {3 filegone 1} 0 {0 0} {0 1 op} {3 filegone 0}]

# ===========================================================================
# V64 - A WAVEFORM WINDOW THAT IS NOT SHOWING A TRANSIENT MUST NOT HIJACK THE
#       ANNOTATION, AND MUST NOT PRODUCE A COMPLAINT EITHER
# ===========================================================================
# ⚠ ITEM A13's REPAIR, AND ISSUE 0899's MAJOR HALF SEEN FROM THE SCHEMATIC.
# The user has the waveform window open on a DC operating point -- or has it
# open with nothing plotted in it yet -- and their sheet's own transient results
# are sitting readable where the preferences say they are. Pressing the chord
# must annotate from the sheet's own results file, exactly as it did before
# there was any waveform consult at all.
# ⚠ WHAT GOES WRONG WITHOUT THE GUARD, MEASURED 2026-08-28 THROUGH SHIPPED
# VERBS ONLY. Delete `if {$path eq {}} { return {} }` from the consult and the
# empty path falls into the deleted-file arm -- `file exists {}` is 0 -- so the
# consult answers `filegone` about a file it never named. The user gets
# "The waveform window is showing the results file , but that file is no longer
# on disk", a refusal naming NO file, about a file that was never named, on a
# session whose results were readable, and the sheet stays bare. Every other row
# in the tree stayed green through that.
# ⚠ TWO FACES BECAUSE THERE ARE TWO WAYS TO GET AN EMPTY PATH, and the consult's
# own comment names both: the window holds nothing (`raw loaded` < 0), and the
# window holds something that is not a transient (`sim_type` ne tran). Neither
# is a corner: a viewer opened but not yet plotted into, and a viewer showing
# the operating point, are both ordinary bench states.
# ⚠ THE PAINT IS THE POINT. `d 21 g 0.1 0 0.0 0 0.0` is the decoy at the
# preferences path, and here it is not a decoy at all -- it is the sheet's own
# results file, correctly annotated, which is the whole claim.
set ::netlist_dir $V_ND_DECOY
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
catch {xschem statusmsg -hold ZZA13SENTINEL}
opa_v_viewer $V_A10_OPTRAN {set ::v64_state [opa_v_tran]} op
set v64_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v64_paint [opa_v_paint a13_opview]
opa_l_annot 0
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
catch {xschem statusmsg -hold ZZA13SENTINEL}
opa_v_viewer $V_A13_ABSENT {set ::v64b_state [opa_v_tran]}
set v64b_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v64b_paint [opa_v_paint a13_emptyview]
opa_l_annot 0
catch {xschem raw clear}
check {V64 issue 0899 a waveform window showing an operating point or holding nothing at all still lets the sheet be annotated from its own results file, and never produces a refusal about a file nobody named} \
  [list $::v64_state $v64_paint $v64_msg $::v64b_state $v64b_paint $v64b_msg] \
  [list ok $V_PINS_OTHER $V_MSG_OK3 ok $V_PINS_OTHER $V_MSG_OK3]

# ===========================================================================
# V65 - BOTH COMPLAINTS ARE TRUE AT ONCE, AND THE USER IS TOLD THE ONE THEY
#       CAN ACT ON
# ===========================================================================
# ⚠ ISSUE 0899's SECOND HALF, AND THE ONLY FIXTURE IN THE TREE WHERE THE
# CLASSIFICATION'S ORDER IS DECIDABLE. Rows V58/V59 make the run-has-no-points
# test true and the file-is-gone test false; rows V60/V61 do the reverse. Either
# order of the two lines passes both pairs, so the order shipped on a comment
# and nothing else. Here the simulator has unlinked a file the waveform window
# read while it still had no points in it -- both true -- and the shipped order
# says the deleted file wins, because "that file is no longer on disk" is the
# complaint the user can do something about and "no values yet" would have the
# user waiting for a run whose output has already gone.
# ⚠ THE LAST LEG NAMES THE SENTENCE THAT MUST NOT APPEAR, in row V60's
# discipline: a row that only checked that some refusal was raised would be
# satisfied by the wrong one.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $V_A13_ZERO $V_A10_VRUN
catch {xschem statusmsg -hold ZZA13SENTINEL}
set v65 [opa_v_spy {
  opa_v_viewer $V_A10_VRUN {
    ## the run has produced nothing yet AND the simulator has just unlinked the
    ## file it is about to re-create, while the window keeps plotting what it read
    file delete -force $::V_A10_VRUN
    set ::v65_state [opa_v_tran]
  }
}]
set v65_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v65_mask  [xschem get annot_show]
set v65_paint [opa_v_paint a13_zerogone]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V65 issue 0899 when the run has produced no values yet AND its results file has been deleted the user is told about the deleted file, which is the one they can act on} \
  [list $::v65_state $v65 $v65_msg $v65_mask $v65_paint \
        [expr {$v65_msg ne $V_MSG_VFILL ? 1 : 0}]] \
  [list viewergone [list [list warn $V_MSG_VGONE]] $V_MSG_VGONE 0 $V_PINS_NONE 1]

# ===========================================================================
# V66 - THE SECOND PRESS SHOWS THE SECOND RUN'S NUMBERS
# ===========================================================================
# ⚠ ISSUE 0900, AND IT IS THE ORDINARY SEQUENCE, NOT A CORNER. Press the chord;
# the run's node voltages land on the sheet and they are right. Change the
# circuit, run the simulation again; the waveform window re-plots and is now
# showing the new run. Press the chord again -- and the schematic is repainted
# with the FIRST run's numbers, under the caption "Showing each node's voltage
# at 3 ns, where cursor B is on the waveform.", with no refusal, no warning and
# no compare anywhere. Measured on both arms 2026-08-28. That is RULING D5-1: a
# number displayed next to a thing it was not measured for, with an
# authoritative sentence lending it weight.
# ⚠ WHY EVERY ROW BEFORE THIS ONE IS BLIND TO IT. A successful press never
# unwinds -- it OWNS the database it attached -- and the gate in
# `cadence::annot_tran` asks only "is some database attached", never "is it the
# one the user is looking at". So the second press short-circuits the entire
# supply: the waveform consult, the deleted-file and no-values-yet guards, the
# out-of-date check and the two-window compare are all skipped. Every fixture in
# the tree starts from a design window holding NOTHING, so all of them enter the
# guarded block and none of them can reach this path with a disagreeing window.
# ⚠ THE FIXTURE NEVER HAND-ATTACHES. The state the second press meets is built
# by a real FIRST press through the shipped `cadence::annot_tran`, because a
# fixture that hand-builds the attached state is how this whole class of defect
# reached the user in the first place.
# ⚠ AND THE VIEWER IS ASSERTED TO HAVE MOVED BEFORE THE PRESS IS ASKED
# ANYTHING. Leg 4 is the re-plot's own rc and v(d) at the last point, 28, which
# is the second run. Without it a red here could mean the fixture failed to
# re-plot rather than the feature failed to look.
# ⚠ THE SECOND PAINT IS `d 21 g 0.1 0 0.0 0 0.0`, THE SAME LITERAL ROWS V58 AND
# V61 NAME AS FORBIDDEN. Same string, opposite meaning, and leg 4 is what tells
# them apart: there the waveform window is NOT showing that run and painting it
# is the defect; here the waveform window IS showing it and painting it is the
# whole job -- the user's own 0881 ruling, "The info should already be available
# - it's been loaded to display waveforms in the waveform viewer", applied a
# second time.
# ⚠ LEG 7 IS `paint2 ne paint1` AND IT IS NOT A DUPLICATE OF LEG 6. A later
# re-lettering of the fixture that made both runs paint the same numbers would
# leave leg 6 green over a feature that never looked at anything.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
catch {xschem statusmsg -hold ZZA14SENTINEL}
opa_v_viewer $V_A10_VRUN {
  set ::v66_s1  [opa_v_tran]
  set ::v66_p1  [opa_v_paint a14_2p_1]
  ## the design window now OWNS the database that press left attached -- the
  ## precondition the defect needs, asserted rather than assumed
  set ::v66_pre [rcall {xschem raw loaded}]
  ## the simulator runs again over the same path, and the waveform window
  ## re-plots, exactly as it does after a real re-run
  file copy -force $::V_A10_RUN2 $::V_A10_VRUN
  set ::v66_re  [opa_v_replot $::V_A10_VRUN]
  set ::v66_s2  [opa_v_tran]
}
set v66_rf   [rcall {xschem raw rawfile}]
set v66_mask [xschem get annot_show]
set v66_msg  [lindex [rcall {xschem get statusmsg}] 1]
set v66_p2   [opa_v_paint a14_2p_2]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V66 issue 0900 the simulation was run again and the waveform window is showing the new run, so a second press annotates the NEW run's numbers instead of repainting the first run's under a caption that describes the new one} \
  [list $::v66_s1 $::v66_p1 $::v66_pre $::v66_re $::v66_s2 $v66_p2 \
        [expr {$v66_p2 ne $::v66_p1 ? 1 : 0}] $v66_rf $v66_msg \
        [expr {[string is integer -strict $v66_mask] && ($v66_mask & 4) ? 1 : 0}]] \
  [list ok $V_PINS_P3 {0 0} {1 28} ok $V_PINS_OTHER \
        1 [list 0 $V_A10_VRUN] $V_MSG_OK3 1]

# ===========================================================================
# V67 - A REFUSAL TAKES THE EARLIER PRESS'S NUMBERS OFF THE SHEET
# ===========================================================================
# ⚠ THE DRIVER'S RULING, 2026-08-28, AND IT IS RULING D5-1 AGAIN. Once a press
# has learned that the numbers on the sheet describe a run that is no longer the
# one on screen, leaving them there is a number displayed next to a thing it was
# not measured for. A captioned refusal sitting above a stale number is not an
# improvement on a silent stale number, so the refusal clears what the earlier
# press painted.
# ⚠ THE SCENARIO IS ISSUE 0895's, ONE PRESS LATER. The first press succeeds and
# leaves the run's results attached and its numbers on the sheet. The simulator
# then unlinks the results file to re-create it -- which is what most simulators
# do, so the file is ABSENT rather than corrupt -- while the waveform window
# keeps plotting what it already read. The second press cannot reach the
# viewer's data, which is the one case the 0896 decision leaves a refusal for.
# ⚠ SIX CLAIMS, AND THE FIFTH IS THE ONE THE RULING TURNS ON: the first press
# succeeded and painted the run; the second press refuses BY NAME; the CIW got
# that sentence once, tagged as a warning, and the held status line carries it;
# nothing is attached to the design window afterwards; THE SHEET IS BARE; and
# the user's own annotation settings are exactly where the first press left
# them, because a refusal must never edit them.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
catch {xschem statusmsg -hold ZZA14SENTINEL}
set v67 [opa_v_spy {
  opa_v_viewer $::V_A10_VRUN {
    set ::v67_s1 [opa_v_tran]
    set ::v67_p1 [opa_v_paint a14_gone_1]
    ## the simulator unlinks the file it is about to re-create, while the
    ## waveform window keeps plotting what it read
    file delete -force $::V_A10_VRUN
    set ::v67_s2 [opa_v_tran]
  }
}]
set v67_msg  [lindex [rcall {xschem get statusmsg}] 1]
set v67_ld   [rcall {xschem raw loaded}]
set v67_mask [xschem get annot_show]
set v67_p2   [opa_v_paint a14_gone_2]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V67 issue 0900 RULING D5-1 when the second press cannot reach the waveform window's data it says so AND takes the earlier press's numbers off the schematic, instead of captioning a refusal over them} \
  [list $::v67_s1 $::v67_p1 $::v67_s2 $v67 $v67_msg $v67_ld $v67_p2 $v67_mask] \
  [list ok $V_PINS_P3 viewergone \
        [list [list {} $V_MSG_OK3] [list warn $V_MSG_VGONE]] \
        $V_MSG_VGONE {0 -1} $V_PINS_NONE 4]

# ===========================================================================
# V68 - THE WAVEFORM WINDOW HAS NOT MOVED, SO NOTHING IS RE-READ
# ===========================================================================
# ⚠ THIS IS THE ROW THAT SAYS THE REVALIDATION IS CHEAP, and it is the only
# thing standing between a fix for issue 0900 and a press that re-reads the
# whole results file off disk every time. The waveform window is still showing
# the run it was showing; the sheet still agrees with the traces beside it; so
# the press annotates from what it already holds and touches no file.
# ⚠ AND THE DISK IS DELIBERATELY DIFFERENT FROM BOTH WINDOWS. A second run has
# overwritten the file at that path and NOBODY has re-plotted it, so a press
# that went back to disk would paint 21 V and answer 28 at the last point. Leg 4
# reads v(d) at the last point back out of the design window and requires 4 --
# the run BOTH windows are holding in memory.
# ⚠ LEG 5 IS THE NON-VACUITY AND IT IS NOT OPTIONAL. It reads the same path
# fresh, out of band, and requires 28 -- so leg 4's 4 is a statement about the
# feature and not about a fixture that failed to overwrite anything.
# ⚠ AND THIS ASYMMETRY IS DELIBERATE AND PRE-EXISTING: row V51 puts the same
# changed file on disk with an EMPTY design window and gets a refusal, because
# there the two windows really are about to disagree. Here they agree, and
# agreeing with what the user is looking at is the user's own 0881 ruling.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
catch {xschem statusmsg -hold ZZA14SENTINEL}
opa_v_viewer $V_A10_VRUN {
  set ::v68_s1 [opa_v_tran]
  ## the simulator runs again -- but the user has NOT re-plotted, so the
  ## waveform window is still showing the run the sheet agrees with
  file copy -force $::V_A10_RUN2 $::V_A10_VRUN
  set ::v68_s2 [opa_v_tran]
}
set v68_p2  [opa_v_paint a14_cache]
set v68_val [rcall {xschem raw value v(d) 4}]
opa_l_annot 0
catch {xschem raw clear}
set v68_ctl [rcall {xschem annotate_op $V_A10_VRUN}]
set v68_disk [rcall {xschem raw value v(d) 4}]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V68 issue 0900 the waveform window is still showing the same run, so a second press annotates from what is already loaded and never goes back to disk} \
  [list $::v68_s1 $::v68_s2 $v68_p2 $v68_val $v68_disk] \
  [list ok ok $V_PINS_P3 {0 4} {0 28}]

# ===========================================================================
# V69 - STRUCTURAL: THE CONSULT IS NOT SKIPPABLE WHEN A DATABASE IS ALREADY
#       ATTACHED
# ===========================================================================
# ⚠ THIS ROW EXISTS BECAUSE THE CLAIM IS ABOUT A CONDITION, AND A CONDITION
# CANNOT BE SEEN FROM A SINGLE FIXTURE. Rows V66 and V67 prove the answer
# changes on two staged disagreements; neither can prove that a THIRD kind of
# disagreement nobody has thought to stage is also asked about. What makes that
# true is that the currency question is part of the gate's own condition rather
# than a statement somewhere after it, and that is source text.
# ⚠ LEG 4 IS THE WHOLE CLAIM. The line that asks whether a database is attached
# and the line that asks whether it is the RIGHT one must be the SAME line, so
# no arrangement of the code can reach the guarded block without having asked.
# A build that computed the currency into a variable further up and forgot to
# use it, or tested it in an arm below, passes V66 and V67 on today's fixtures
# and fails here.
# ⚠ LEG 5 IS THE ORDERING: the database the session was holding must come off
# BEFORE the supplier runs, not after, because the supplier finds out whether
# its own read worked by asking the registry. Left attached, the old database is
# still there to be counted, so a viewer-named file that fails to re-parse
# leaves the supplier believing it succeeded and the user is told the file is
# "from a different simulation run" when the truth is that it could not be read.
# ⚠ AN EARLIER REVISION OF THIS PARAGRAPH SAID THAT ORDERING HAD NO BEHAVIOURAL
# WITNESS AND THAT THIS LEG WAS ITS ONLY ONE. FALSE, AND MEASURED: item A14's
# sabotage pass deleted the three lines and reddened V66, V67 and V71 on both
# arms plus B12j and B12k on the display arm -- V66's failure IS the wrong-reason
# corner, the press answering "from a different simulation run" while the disk
# file and the waveform window agree perfectly. This leg is the ordering pinned
# on TOP of those five, not instead of them. Issue 0899's class, in a test file.
# ⚠ AND THE LEG NUMBERS ABOVE ARE THE ROW'S OWN, counted from 1 over the eight
# elements below. An earlier revision numbered them from 0 and named the wrong
# leg twice; measured against the vector, S-A14-1 zeroes 3 and 4, S-A14-2
# zeroes 5, a behaviour-neutral early return in the currency test zeroes 7, and
# deleting the fingerprint compare zeroes 8.
# ⚠ LEGS 6 AND 7 SAY THE CONSULT SITS ABOVE EVERY EXIT. A currency test that
# returned early -- on a cheap check, on a cached answer -- before asking the
# waveform window anything would be a cache that is never revalidated, which is
# the entire mechanism of issue 0900 rebuilt one level down.
set V69_SRC [opa_slurp [file join $repo utils annot_mode.tcl]]
set V69_AT  [opa_proc_src $V69_SRC cadence::annot_tran]
set V69_CUR [opa_proc_src $V69_SRC cadence::_annot_tran_db_current]
set v69_gi [opa_v_lineidx $V69_AT {\$loaded < 0}]
set v69_ci [opa_v_lineidx $V69_AT {_annot_tran_db_current}]
set v69_ui [opa_v_lineidx $V69_AT {_annot_tran_unwind}]
set v69_si [opa_v_lineidx $V69_AT {_annot_tran_supply}]
set v69_vi [opa_v_lineidx $V69_CUR {_annot_viewer_db}]
set v69_ri [opa_v_lineidx $V69_CUR {\mreturn\M}]
check {V69 issue 0900 STRUCTURAL every press asks the waveform window whether the database it already holds is still the run on screen, the question is part of the gate itself so it cannot be short-circuited past, and what the session was holding comes off before the supplier reads anything} \
  [list [expr {[string length $V69_AT] > 0 ? 1 : 0}] \
        [expr {[string length $V69_CUR] > 0 ? 1 : 0}] \
        [opa_v_pgrep $V69_AT {_annot_tran_db_current}] \
        [expr {($v69_gi >= 0 && $v69_gi == $v69_ci) ? 1 : 0}] \
        [expr {($v69_ui >= 0 && $v69_si >= 0 && $v69_ui < $v69_si) ? 1 : 0}] \
        [opa_v_pgrep $V69_CUR {_annot_viewer_db}] \
        [expr {($v69_vi >= 0 && $v69_ri >= 0 && $v69_vi < $v69_ri) ? 1 : 0}] \
        [opa_v_pgrep $V69_CUR {_annot_db_print}]] \
  [list 1 1 1 1 1 1 1 1]

# ===========================================================================
# V70 - NO WAVEFORM WINDOW IN PLAY, SO THE ATTACHED DATABASE IS STILL USED
# ===========================================================================
# ⚠ THE DECISION THIS ROW PINS: nothing on the user's screen contradicts what
# the session is holding, so it is kept. The user pressed the chord, got their
# numbers, and then CLOSED the waveform window. Their numbers must not vanish
# from the schematic on the next press, and the press must not go off and
# rebuild a path out of the preferences either -- answering with a file the user
# may not be looking at is issue 0881's own defect, arriving from the other
# side.
# ⚠ AND THE PREFERENCES POINT AT AN EMPTY DIRECTORY ON PURPOSE. There is no
# candidate anywhere off the closed window, so a build that treated "no waveform
# window" as "the database is stale" would refuse `noraw` here and strip the
# numbers off the sheet. That refusal is the whole content of this row, and it
# is what sabotage variant S-A14-3 produces.
# ⚠ THE WINDOW IS CLOSED THE WAY THE USER CLOSES IT: `opa_v_viewer` destroys the
# stand-in and takes the three verbs the consult calls away with it, so the
# second press meets a session with no viewer at all -- which is what every
# headless row that never opens one meets.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
catch {xschem statusmsg -hold ZZA14SENTINEL}
opa_v_viewer $V_A10_VRUN {set ::v70_s1 [opa_v_tran]}
## the user closes the waveform window; the sheet keeps the numbers it was given
set v70_pre  [rcall {xschem raw loaded}]
set v70_s2   [opa_v_tran]
set v70_p2   [opa_v_paint a14_noview]
set v70_mask [xschem get annot_show]
opa_l_annot 0
catch {xschem raw clear}
check {V70 issue 0900 with the waveform window closed there is nothing on screen to disagree with, so a second press keeps the numbers the first press put on the schematic instead of refusing} \
  [list $::v70_s1 $v70_pre $v70_s2 $v70_p2 \
        [expr {[string is integer -strict $v70_mask] && ($v70_mask & 4) ? 1 : 0}]] \
  [list ok {0 0} ok $V_PINS_P3 1]

# ===========================================================================
# V71 - AN OPERATING POINT ON THE SHEET AND A TRANSIENT IN THE WINDOW
# ===========================================================================
# ⚠ LEG b IS A SECOND 0881-FAMILY REPAIR THE SAME GATE GETS FOR FREE. The user
# has pressed `6` or `Alt-6` at some point, so the design window is holding an
# OPERATING POINT and its 7.5 V is on the sheet. They then run a transient, put
# a cursor on the traces and press the transient chord. Today the press asks
# only "is some database attached", finds the operating point, never looks at
# the waveform window at all, and tells the user "These results are not from a
# transient run" -- about a database nobody is looking at, while the transient
# they asked about is plotted on screen beside it. That sentence is false in the
# only sense a user cares about, and it is the same complaint the user filed
# against this mode in the first place.
# ⚠ LEG a's CONTROL IS NOT OPTIONAL, ROW V46's DISCIPLINE. It attaches the same
# operating point under the same mask by hand and requires 7.5 V to appear
# beside node `d`, so the second leg's `d 3` is a statement about the feature
# and not about a fixture that could not paint.
# ⚠ LEG c IS THE OTHER FACE AND IT NEEDS ITS OWN LEGS: the same operating point
# on the sheet, and the waveform window's file gone. The press must refuse -- it
# cannot reach the data the user is asking about -- and the OPERATING POINT
# NUMBERS COME OFF TOO. That is a decision, not an inevitability: the user ruled
# on clearing "the numbers the earlier press painted" and these were painted by
# a DIFFERENT press. It is done uniformly because a press that has learned the
# held database is not the run on screen must detach it before anything else, or
# every downstream refusal reports the wrong REASON -- see row V69 leg 5.
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
opa_l_annot 2
catch {xschem annotate_op $T_OPRAW}
set v71_ctl [opa_v_paint a14_opctl]
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
opa_l_annot 2
catch {xschem annotate_op $T_OPRAW}
file copy -force $T_RAW $V_A10_VRUN
opa_v_viewer $V_A10_VRUN {set ::v71a_state [opa_v_tran]}
set v71a_paint [opa_v_paint a14_opview]
set v71a_msg   [lindex [rcall {xschem get statusmsg}] 1]
opa_l_annot 0
catch {xschem raw clear}
opa_l_annot 2
catch {xschem annotate_op $T_OPRAW}
catch {xschem statusmsg -hold ZZA14SENTINEL}
opa_v_viewer $V_A10_VRUN {
  file delete -force $::V_A10_VRUN
  set ::v71b_state [opa_v_tran]
}
set v71b_paint [opa_v_paint a14_opgone]
set v71b_ld    [rcall {xschem raw loaded}]
set v71b_mask  [xschem get annot_show]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V71 issue 0900 an operating point left on the schematic by an earlier press no longer blinds the transient chord to the waveform window, and when that window's data cannot be reached the operating-point numbers come off with the refusal} \
  [list $v71_ctl $::v71a_state $v71a_paint $v71a_msg \
        $::v71b_state $v71b_ld $v71b_paint $v71b_mask] \
  [list $V_PINS_OP75 ok $V_PINS_P3 $V_MSG_OK3 \
        viewergone {0 -1} $V_PINS_NONE 2]

# ===========================================================================
# V72 - THE USER'S DIGITAL DATABASE SURVIVES A PRESS THAT WAS NEVER TALKING
#       ABOUT IT
# ===========================================================================
# ⚠ ISSUE 0902, AND IT IS A DEFECT ITEM A14 INTRODUCED, NOT ONE IT INHERITED.
# The user is running a mixed-signal bench: the design window is holding the
# analog transient a previous press attached AND the co-simulation VCD that
# feeds the sheet's digital back-annotation, which is exactly the window state
# spec D5 is written about. The waveform window has moved on to a newer run, so
# the press correctly decides the numbers on the sheet cannot be believed and
# goes and gets the run on screen -- and on its way it took EVERY database off
# the window, the VCD included. The digital values on the sheet went blank and
# nothing said why.
# ⚠ WHY NO ROW COULD SEE IT. `xschem raw clear` with no file named "unloads all
# raw files" (src/scheduler.c); with a file and a type named it takes off one.
# Before item A14 the unwind was reachable only on a press that had itself
# attached the one database it then took off, so the two spellings were
# indistinguishable and every fixture in the tree holds exactly one database.
# ⚠ THE COUNT IS ASSERTED BEFORE AND AFTER, AND THE DIGITAL VALUE ON TOP.
# A row that only counted would pass against a build that took the VCD off and
# left the stale analog on; a row that only read the value would pass against
# one that left BOTH on and never refreshed. Leg 6 is the count and leg 7 is the
# value the digital back-annotation actually reads.
# ⚠ AND LEG 8 IS THE 0900 FIX ITSELF, RE-ASSERTED UNDER THE NEW STATE. The
# second press must still paint the NEW run -- fixing the data loss by declining
# to refresh at all would pass every other leg here.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
catch {xschem statusmsg -hold ZZA14SENTINEL}
opa_v_viewer $V_A10_VRUN {
  set ::v72_s1 [opa_v_tran]
  ## the co-simulation VCD goes on next to the run the press just attached, and
  ## the analog transient is made current again -- which is the order
  ## `ase::attach_dbs` leaves the registry in on a real bench
  set ::v72_vrc [catch {xschem raw read $::V_A14_VCD vcd}]
  catch {xschem raw switch $::V_A10_VRUN tran}
  set ::v72_n1 [opa_v_slots]
  ## the simulator runs again over the same path and the waveform window
  ## re-plots, exactly as it does after a real re-run
  file copy -force $::V_A10_RUN2 $::V_A10_VRUN
  set ::v72_re [opa_v_replot $::V_A10_VRUN]
  set ::v72_s2 [opa_v_tran]
}
set v72_n2   [opa_v_slots]
set v72_dig  [opa_v_digval]
set v72_p2   [opa_v_paint a14_vcdkeep]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V72 issue 0902 a press that goes and gets the newer run takes the run it can no longer believe off the design window and leaves the co-simulation results the user loaded exactly where they were} \
  [list $::v72_s1 $::v72_vrc $::v72_n1 $::v72_re $::v72_s2 $v72_n2 $v72_dig $v72_p2] \
  [list ok 0 2 {1 28} ok 2 1 $V_PINS_OTHER]

# ===========================================================================
# V73 - AND A REFUSAL LEAVES IT ALONE TOO, AS DOES A PRESS THAT FINDS IT
#       CURRENT
# ===========================================================================
# ⚠ TWO FACES, BECAUSE ISSUE 0902 HAS TWO. Face a is the REFUSAL path: the
# waveform window's file has gone, so the press cannot reach the data the user
# is asking about and clears what the earlier press painted -- row V67's
# scenario -- and the co-simulation database must still be there afterwards. A
# refusal that takes away results the user loaded is worse than the stale number
# it was clearing.
# ⚠ FACE b IS RULING D5-3 READ FORWARDS, AND IT IS THE SHARPER OF THE TWO. Here
# the digital database is the CURRENT one in the design window, so a build that
# fixed face a merely by naming the file it clears would name the VCD and take
# it off. There is nothing of this surface's to take off: `xschem annotate_op`
# refuses a digital file before it loads anything, so the surface can never have
# attached one.
# ⚠ AND FACE b STILL HAS TO ANNOTATE. Leg 8 is the paint: leaving the digital
# database alone must not mean giving up on the press. The waveform window is
# showing a transient, so the run on screen goes on the sheet.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
catch {xschem statusmsg -hold ZZA14SENTINEL}
opa_v_viewer $V_A10_VRUN {
  set ::v73a_s1 [opa_v_tran]
  catch {xschem raw read $::V_A14_VCD vcd}
  catch {xschem raw switch $::V_A10_VRUN tran}
  set ::v73a_n1 [opa_v_slots]
  file delete -force $::V_A10_VRUN
  set ::v73a_s2 [opa_v_tran]
}
set v73a_n2    [opa_v_slots]
set v73a_dig   [opa_v_digval]
set v73a_paint [opa_v_paint a14_vcdrefuse]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN

catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
catch {xschem raw read $V_A14_VCD vcd}
set v73b_n1 [opa_v_slots]
catch {xschem statusmsg -hold ZZA14SENTINEL}
opa_v_viewer $V_A10_VRUN {set ::v73b_s2 [opa_v_tran]}
set v73b_n2    [opa_v_slots]
set v73b_dig   [opa_v_digval]
set v73b_paint [opa_v_paint a14_vcdcur]
opa_l_annot 0
catch {xschem raw clear}
check {V73 issue 0902 the co-simulation results the user loaded are still there after a press that had to refuse, and a press that finds them as the window's current database leaves them alone and annotates the run on screen anyway} \
  [list $::v73a_s1 $::v73a_n1 $::v73a_s2 $v73a_n2 $v73a_dig $v73a_paint \
        $v73b_n1 $::v73b_s2 $v73b_n2 $v73b_dig $v73b_paint] \
  [list ok 2 viewergone 1 1 $V_PINS_NONE \
        1 ok 2 1 $V_PINS_P3]

# ===========================================================================
# V75 - THE REFUSAL STILL NAMES THE RIGHT REASON WITH A DIGITAL DATABASE IN
#       THE WINDOW
# ===========================================================================
# ⚠ THIS IS THE BILL FOR ISSUE 0902's FIX, AND IT IS PAID HERE RATHER THAN
# DISCOVERED LATER. Once a press is allowed to leave the user's co-simulation
# database attached -- which is the whole of 0902 -- the design window can be
# holding something while the press's OWN read of the waveform window's file
# fails. `xschem raw loaded` answers 0 either way, so a supplier that asked it
# would believe its read had worked, fall through to the two-window compare, and
# tell the user their results file is "from a different simulation run" when the
# truth is that it could not be read. A wrong reason is the same defect class as
# a wrong number.
# ⚠ THE SCENARIO IS ISSUE 0893's, WITH THE VCD ON. The simulator has replaced
# the results file in place with something that is not a database at all, while
# the waveform window keeps plotting what it already read -- so the file EXISTS,
# which is what separates this from the deleted-file case rows V67 and V73 face
# a stage.
# ⚠ LEG 2 IS THE POINT, NOT LEG 1. A row that only checked that some refusal
# was raised would be satisfied by the wrong one, so the sentence is asserted
# whole and leg 5 names the sentence that must NOT appear.
set ::netlist_dir $V_ND_NONE
catch {xschem raw clear}
xschem load [file join $lib v_cand.sch]
opa_l_annot 0
xschem cursor 1 0 ; xschem cursor 2 1
xschem set cursor2_x 3e-9
file copy -force $T_RAW $V_A10_VRUN
catch {xschem raw read $V_A14_VCD vcd}
catch {xschem statusmsg -hold ZZA14SENTINEL}
opa_v_viewer $V_A10_VRUN {
  opa_t_wr $::V_A10_VRUN "ZZ this file is not a spice raw database and never was\n"
  set ::v75_s [opa_v_tran]
}
set v75_msg   [lindex [rcall {xschem get statusmsg}] 1]
set v75_n     [opa_v_slots]
set v75_dig   [opa_v_digval]
set v75_paint [opa_v_paint a14_vcdunread]
opa_l_annot 0
catch {xschem raw clear}
file copy -force $T_RAW $V_A10_VRUN
check {V75 issue 0902 with the user's co-simulation results still attached a press whose own read of the waveform window's file fails says the file could not be read, not that it is from a different run} \
  [list $::v75_s $v75_msg $v75_n $v75_dig $v75_paint \
        [expr {$v75_msg ne $V_MSG_VDIFF ? 1 : 0}]] \
  [list viewerunread $V_MSG_VUNREAD 1 1 $V_PINS_NONE 1]

# ===========================================================================
# V74 - STRUCTURAL: THE SPELLING THAT TAKES A DATABASE OFF, AND THE CHEAP EXIT
#       NOTHING BEHAVIOURAL CAN SEE
# ===========================================================================
# ⚠ LEGS 3 AND 4 ARE THE ONE-CHARACTER DIFFERENCE ISSUE 0902 IS. `xschem raw
# clear` and `xschem raw clear <file> <type>` read almost the same and do
# something very different -- the first "unloads all raw files"
# (src/scheduler.c), the second takes off one. V72 and V73 see the difference
# behaviourally today; these legs are what stops the bare spelling coming back
# into a proc whose callers have grown, which is precisely how it got in.
# ⚠ LEG 5 IS RULING D5-3's PLACE IN THE ORDER. The digital question must be
# asked BEFORE anything is taken off, or the answer arrives too late to matter.
# ⚠ LEGS 3, 4 AND 5 CHANGED ADDRESS WITH ISSUE 0684, AND THE CLAIM DID NOT.
# The body they read used to be `cadence::_annot_db_release`'s own; it now lives
# at `op_annot::db_detach` (src/op_annot.tcl), because after 0684 BOTH
# operating-point surfaces need to take a database off and utils/annot_mode.tcl
# is loaded only by the cadence profile while src/op_annot.tcl is sourced by
# every session. RULING D5-4 is satisfied by the OLD address becoming a one-line
# delegate, which is what leg 9 requires -- so the spelling has exactly one
# owner, as before, and this row still names it.
# ⚠ LEGS 6 AND 7 ARE THE SUPPLIER'S SUCCESS TEST, AND ROW V75 IS WHAT THEY SIT
# ON TOP OF. Once a refusal is allowed to leave a VCD attached, `xschem raw
# loaded` stops answering "did my own read work" -- it says 0 for a window
# holding nothing but that VCD -- so the supplier must ask whether an ANALOG
# database is loaded, and must not have the shorter spelling anywhere in it.
# V75 sees the answer change; these two see the question.
# ⚠ LEG 8 IS THE ONE ITEM A14's SABOTAGE PASS COULD NOT SEE, AND IT IS PINNED
# HERE RATHER THAN DESCRIBED AS SOMETHING IT IS NOT. The `if` wrapping the
# gate's unwind is a CHEAP EXIT, not a guard: with it deleted all three suites
# stay ALL PASS on both arms, because with nothing attached the unwind finds
# nothing to take off and writes back the mask it just read. Its only effect is
# one fewer redraw on a press that starts from an empty design window, and no
# row in the tree counts redraws. It is kept because a press that decides
# nothing should do nothing, and this leg is the honest witness for it: the test
# must sit on the line immediately above the call.
set V74_SRC [opa_slurp [file join $repo utils annot_mode.tcl]]
set V74_OPA [opa_slurp [file join $repo src op_annot.tcl]]
set V74_REL [opa_proc_src $V74_SRC cadence::_annot_db_release]
set V74_DET [opa_proc_src $V74_OPA op_annot::db_detach]
set V74_UNW [opa_proc_src $V74_SRC cadence::_annot_tran_unwind]
set V74_SUP [opa_proc_src $V74_SRC cadence::_annot_tran_supply]
set V74_AT  [opa_proc_src $V74_SRC cadence::annot_tran]
set v74_di [opa_v_lineidx $V74_DET {is_digital}]
set v74_ci [opa_v_lineidx $V74_DET {xschem raw clear}]
set v74_wi [opa_v_lineidx $V74_AT {\$loaded >= 0}]
set v74_ui [opa_v_lineidx $V74_AT {_annot_tran_unwind}]
check {V74 issue 0902 STRUCTURAL taking a database off names the file it is taking off and never touches a digital one, the supplier asks whether an analog database is loaded rather than whether anything is, and the cheap exit above the gate's detach is pinned because nothing behavioural can see it go} \
  [list [expr {[string length $V74_REL] > 0 ? 1 : 0}] \
        [expr {[string length [opa_proc_src $V74_SRC cadence::_annot_db_analog_loaded]] > 0 ? 1 : 0}] \
        [opa_v_pgrep $V74_DET {xschem raw clear \$f \$t}] \
        [expr {[opa_v_pgrep $V74_DET {xschem raw clear\s*\}}] + [opa_v_pgrep $V74_REL {xschem raw clear}] + [opa_v_pgrep $V74_UNW {xschem raw clear}]}] \
        [expr {($v74_di >= 0 && $v74_ci >= 0 && $v74_di < $v74_ci) ? 1 : 0}] \
        [opa_v_pgrep $V74_SUP {_annot_db_analog_loaded}] \
        [opa_v_pgrep $V74_SUP {xschem raw loaded}] \
        [expr {($v74_wi >= 0 && $v74_ui >= 0 && $v74_wi == $v74_ui - 1) ? 1 : 0}] \
        [opa_v_pgrep $V74_REL {op_annot::db_detach}]] \
  [list 1 1 1 0 1 2 0 1 1]

set ::netlist_dir $v33_nd
catch {xschem raw clear}
catch {xschem cursor 1 0} ; catch {xschem cursor 2 0}
opa_l_annot 0

set ::live_cursor2_backannotate $V_LV
catch {xschem raw clear}
catch {xschem cursor 1 0} ; catch {xschem cursor 2 0}
opa_l_annot 0
set XSCHEM_LIBRARY_PATH $S_LIBS

} verr]} {
  puts "UNEXPECTED ERROR (section V): $verr"
  incr fail
}

# =============================================================================
# SECTION A11 — THE ANNOTATION SURFACE SPEAKS PLAIN ENGLISH (issue 0886)
# =============================================================================
# The user's ruling, verbatim: "wording too cryptic. Give it in plain english
# with context, 9th grade level."
#
# ⚠ THE SUITE COULD NOT SEE THIS DEFECT, BY CONSTRUCTION, AND THAT IS WHY THESE
# ROWS EXIST. Every sentence golden above is a byte-for-byte comparison against
# a string this file itself chose, so a green run proves the bytes match — the
# one thing that cannot tell a good sentence from a bad one. The rows below add
# the three legs that CAN judge a rewrite mechanically: no internal vocabulary
# reaches the user, every number reaches the user in engineering units, and
# every refusal the user can act on says what to do. The fourth leg, whether the
# sentences actually read well, is a look debt and only the user can pay it.
#
# ⚠ AND THE STATUS BAR HOLDS 255 CHARACTERS. Measured on the shipped binary
# before a word was rewritten: mask 7 with the no-operating-point state and five
# symbol types builds a 257-character line, `xschem get statusmsg` reads back
# 255, and the tail dies mid-token. Plain English is longer than jargon, so the
# budget is not optional headroom — it is the reason the "what to do" half of a
# sentence would be the half that gets cut. `cadence::_annot_fit` is the one
# place that decides, and A11-1 / A11-2 / A11-10 are what hold it honest.

## Whole-line Tcl comments stripped, so a sentence quoted in a header paragraph
## is never counted as a mint.
proc opa_a11_code {src} {
  set out {}
  foreach l [split $src \n] {
    if {[regexp {^\s*#} $l]} continue
    lappend out $l
  }
  return [join $out \n]
}

## Count the CODE lines of <path> that match BOTH regexps. -1 when the file is
## absent, so a missing file reds one row instead of raising out of the section.
proc opa_a11_pair {path re1 re2} {
  if {![file isfile $path]} { return -1 }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set n 0
  foreach l [split $d \n] {
    if {[regexp {^\s*#} $l]} continue
    if {[regexp -- $re1 $l] && [regexp -- $re2 $l]} { incr n }
  }
  return $n
}

## Is every character of <s> printable US-ASCII? The character budget the status
## line is trimmed against is a CHARACTER count in Tcl and a BYTE count in C
## (statusmsg_text[256], src/xschem.h), so one smuggled UTF-8 dash puts the two
## out of step and the amputation this pass repairs comes back silently.
proc opa_a11_ascii {s} {
  foreach c [split $s {}] {
    scan $c %c v
    if {$v < 32 || $v > 126} { return 0 }
  }
  return 1
}

## The length the C side will see. MEASURED HERE INDEPENDENTLY, on purpose: the
## mint has a proc of its own for this, and a row that borrowed it could not
## tell a broken ruler from a correct one -- both halves would agree while the
## status line was amputated. `encoding convertto utf-8` is the plain reading of
## the same question and needs nothing from the code under test.
proc opa_a11_bytes {s} { return [string length [encoding convertto utf-8 $s]] }

## Every sentence the two mints can render: eight masks by eight states by three
## symbol-type lists, the two no-operating-point shapes, and all eight transient
## arms. A path with no jargon in it, so a banned word can only come from the
## wording and never from the fixture.
proc opa_a11_sentences {} {
  set out {}
  set p /tmp/zzA11/results.data
  foreach m {0 1 2 3 4 5 6 7} {
    foreach st {off live noop loaded failed noraw nopath stale} {
      foreach ty [list {} {nmos} {nmos pmos res cap ind}] {
        set r [rcall [list cadence::_annot_msg $m $st $p $ty]]
        if {[lindex $r 0] != 0} {
          lappend out "RAISED:[lindex $r 1]"
        } else {
          lappend out [lindex $r 1]
        }
      }
    }
  }
  foreach a [list [list 1 notop tran {}] [list 1 notop {} {}]] {
    set r [rcall [concat [list cadence::_annot_msg] $a]]
    if {[lindex $r 0] != 0} {
      lappend out "RAISED:[lindex $r 1]"
    } else {
      lappend out [lindex $r 1]
    }
  }
  foreach a [list [list ok 1e-09 A {}] [list okclamped 4e-09 B 4.5e-09] \
                  [list nocursor {} {} {}] [list noraw {} {} {}] \
                  [list notran {} {} {}] [list nodata 3e-09 B {}] \
                  [list staleraw {} {} $p] [list viewerdiff {} {} $p] \
                  [list viewerunread {} {} $p] [list viewergone {} {} $p] \
                  [list viewerfilling {} {} $p]] {
    set r [rcall [concat [list cadence::_annot_tran_msg] $a]]
    if {[lindex $r 0] != 0} {
      lappend out "RAISED:[lindex $r 1]"
    } else {
      lappend out [lindex $r 1]
    }
  }
  return $out
}

if {[catch {

set A11_MINT [file join $repo utils annot_mode.tcl]
set A11_ASEW [file join $repo src ase_window.tcl]
set A11_ASE  [file join $repo src ase.tcl]

# ===========================================================================
# A11-1 — THE STATUS-LINE BUDGET, AS A UNIT
# ===========================================================================
# ⚠ THE PROPERTIES, NOT AN IMPLEMENTATION. A line that fits comes back
# untouched, byte for byte -- the common case must not be paraphrased. A line
# that does not fit comes back inside the budget, marked as elided with three
# ASCII dots, and cut at a SPACE that really is in the original: the shipped
# defect this repairs is a sentence that died mid-token, so "never mid-token" is
# the claim, and asserting it against the original string is what makes it one.
set a11_s255     [string repeat x 255]
set a11_fit255   [rcall [list cadence::_annot_fit $a11_s255]]
set a11_short    {a line that fits}
set a11_fitshort [rcall [list cadence::_annot_fit $a11_short]]
set a11_long     [string trim [string repeat {abcdefghij } 30]]
set a11_fitlong  [rcall [list cadence::_annot_fit $a11_long]]
set a11_r        [lindex $a11_fitlong 1]
set a11_pre      [string range $a11_r 0 end-3]
check {A11-1 the status line has ONE budget: a line that fits is untouched, a line that does not is cut at a word boundary and marked} \
  [list [lindex $a11_fit255 1] [lindex $a11_fitshort 1] \
        [lindex $a11_fitlong 0] \
        [expr {[string length $a11_r] <= 255 ? 1 : 0}] \
        [string range $a11_r end-2 end] \
        [expr {[string first $a11_pre $a11_long] == 0 ? 1 : 0}] \
        [string index $a11_long [string length $a11_pre]]] \
  [list $a11_s255 $a11_short 0 1 {...} 1 { }]

# ===========================================================================
# A11-2 — THE AMPUTATION, END TO END: THE CIW KEEPS THE WHOLE SENTENCE
# ===========================================================================
# ⚠ THIS IS THE COMBINATION THAT IS BROKEN ON THE SHIPPED BINARY TODAY. Mask 7,
# the no-operating-point state and five symbol types: 257 characters go out,
# 255 come back, and the two channels the user can read already disagree about
# what the program said. The rule this row pins is that the CIW copy is NEVER
# trimmed -- it is the record -- while the status line is fitted, so the elision
# is visible rather than silent. The structural leg is the half no behavioural
# row can see: every line that writes the status bar must go through the budget,
# or the next sentence added bypasses it and the defect returns.
set a11_full [lindex [rcall {cadence::_annot_msg 7 noop {} {nmos pmos res cap ind}}] 1]
catch {xschem statusmsg -hold ZZA11SENTINEL}
set a11_spy  [opa_v_spy {catch {cadence::_annot_say $::a11_full warn}}]
set a11_line [lindex [rcall {xschem get statusmsg}] 1]
set a11_hold [lindex [rcall {xschem get statusmsg_hold}] 1]
set a11_nhold [opa_v_ngrep $A11_MINT {xschem statusmsg -hold}]
check {A11-2 the whole sentence reaches the CIW while the status line is fitted, and every status-line write goes through the budget} \
  [list [expr {[string length $a11_full] > 255 ? 1 : 0}] \
        [llength $a11_spy] [lindex $a11_spy 0 0] \
        [expr {[lindex $a11_spy 0 1] eq $a11_full ? 1 : 0}] \
        [expr {[string length $a11_line] <= 255 ? 1 : 0}] \
        [string range $a11_line end-2 end] \
        [expr {[string first [string range $a11_line 0 end-3] $a11_full] == 0 ? 1 : 0}] \
        $a11_hold \
        [expr {$a11_nhold >= 1 ? 1 : 0}] \
        [expr {[opa_a11_pair $A11_MINT {xschem statusmsg -hold} {_annot_fit}] == $a11_nhold ? 1 : 0}]] \
  [list 1 1 warn 1 1 {...} 1 1 1 1]

# ===========================================================================
# A11-3 — A TIME REACHES THE USER THE WAY A DESIGNER READS A WAVEFORM
# ===========================================================================
# ⚠ RULING: "NUMBERS ARE PART OF THE WORDING". `4e-09` is not how an analog
# designer reads time off an x-axis; 4 ns is. The row asserts both directions --
# the engineering form is PRESENT and the bare Tcl float is ABSENT -- because a
# sentence that printed both would satisfy a one-sided row while still handing
# the user the float. The zero case is here because it is the one value with no
# SI prefix at all, and a formatter that appends a prefix unconditionally would
# render it as something no designer has ever seen.
set a11_ok [lindex [rcall {cadence::_annot_tran_msg ok 4e-09 A}] 1]
set a11_nd [lindex [rcall {cadence::_annot_tran_msg nodata 3e-05 B}] 1]
set a11_cl [lindex [rcall {cadence::_annot_tran_msg okclamped 0 B 4.5e-09}] 1]
check {A11-3 every time on the annotation path reaches the user in engineering units, never as a bare float} \
  [list [string match {*4 ns*}    $a11_ok] [string match {*4e-09*}   $a11_ok] \
        [string match {*30 us*}   $a11_nd] [string match {*3e-05*}   $a11_nd] \
        [string match {*0 s*}     $a11_cl] [string match {*4.5 ns*}  $a11_cl] \
        [string match {*4.5e-09*} $a11_cl]] \
  {1 0 1 0 1 1 0}

# ===========================================================================
# A11-4 — A CALLER BUG STAYS VISIBLE INSTEAD OF RENDERING A HOLE
# ===========================================================================
# ⚠ op_annot's own discipline, applied one layer up. Invariant I3 blanks a
# MISSING measurement, and blanking is right there: the user is being told a
# number is not available. A time this proc could not parse is a CALLER bug, and
# a caller bug that renders as an empty gap in a sentence is the silence the
# whole mode exists to remove. It is also the only leg of the formatter that no
# other row in this file can reach.
set a11_bad [rcall {cadence::_annot_tran_msg ok zzgarbage A}]
check {A11-4 a time the formatter cannot read is shown as it stands, so a caller bug is visible rather than blank} \
  [list [lindex $a11_bad 0] [string match {*zzgarbage*} [lindex $a11_bad 1]] \
        [lindex $a11_bad 1]] \
  [list 0 1 {Showing each node's voltage at zzgarbage, where cursor A is on the waveform.}]

# ===========================================================================
# A11-5 — RULING D5-4, BEHAVIOURAL: THE MENU PATH IS DERIVED, NOT TYPED
# ===========================================================================
# ⚠ THE REMEDY THE SENTENCE OFFERS IS A MENU ENTRY THE USER HAS TO FIND. The
# labels are already minted once, in src/xschem.tcl, precisely so that renaming
# an entry moves every printed path with it; a second copy typed into the
# sentence drifts the day someone renames the menu and nothing reds. The rename
# below is the only way to tell a derived path from a hardcoded one that happens
# to be spelled correctly today.
set a11_had [expr {[info commands ::annot_menu_path_waves_op] ne {}}]
if {$a11_had} { rename ::annot_menu_path_waves_op ::opa_a11_saved_menu }
proc ::annot_menu_path_waves_op {} { return ZZA11MENU }
set a11_noop [lindex [rcall {cadence::_annot_msg 1 noop {} {}}] 1]
catch {rename ::annot_menu_path_waves_op {}}
if {$a11_had} { rename ::opa_a11_saved_menu ::annot_menu_path_waves_op }
check {A11-5 RULING D5-4 the menu the sentence sends the user to is read from the menu labels, not typed into the sentence} \
  [list $a11_had \
        [string match {*ZZA11MENU*}          $a11_noop] \
        [string match {*Waves > Op Annotate*} $a11_noop]] \
  {1 1 0}

# ===========================================================================
# A11-6 — STRUCTURAL: NO INTERNAL COMMAND IS OFFERED TO THE USER AS A REMEDY
# ===========================================================================
# ⚠ NO BEHAVIOURAL ROW CAN SEE THIS ONE. A11-5 proves the path is derived; it
# cannot prove the typed literal is gone, because a fallback that is never
# reached renders nothing. And the same shipped line that types the menu path
# also tells the user to type `xschem raw_clear` -- an internal command, offered
# as a remedy, in the sentence the user reads when the results they loaded turn
# out to have no operating point in them. The literal survives only as an
# unreachable fallback inside the one proc that derives the path.
set a11_mintsrc [opa_slurp $A11_MINT]
set a11_msgbody [opa_a11_code [opa_proc_src $a11_mintsrc cadence::_annot_msg]]
check {A11-6 RULING D5-4 the menu path appears once at most and no internal command is named to the user} \
  [list [expr {[opa_v_ngrep $A11_MINT {Waves > Op Annotate}] <= 1 ? 1 : 0}] \
        [regexp -all -- {Waves > Op Annotate} $a11_msgbody] \
        [opa_v_ngrep $A11_MINT {raw_clear}]] \
  {1 0 0}

# ===========================================================================
# A11-7 — THE ROW THAT CAN JUDGE THE REWRITE
# ===========================================================================
# ⚠ EVERY SENTENCE THE SURFACE CAN RENDER, AGAINST THE RULING'S OWN BAN LIST.
# 202 sentences: eight masks by eight states by three symbol-type lists, the two
# no-operating-point shapes and all eight transient arms. The user's nouns are
# the schematic, the waveform window, cursor A and cursor B, a simulation run,
# results, node voltages, device operating-point values and the time on the
# x-axis. None of the program's own nouns may appear beside them.
# ⚠ THE SECOND LEG IS NOT TIDINESS. Tcl trims the status line by CHARACTERS and
# C stores it in a 256-BYTE array, so a single UTF-8 dash makes the two budgets
# disagree and puts the amputation back where nothing is looking.
# ⚠ TEN LITERALS ARE NOT A STANDARD, AND FOR A DAY THAT IS ALL THIS ROW HAD.
# The first ten patterns are the legacy spellings the rewrite deleted, and a
# detector made only of those passes any NEW jargon that happens not to be one
# of them. Measured 2026-08-28: replacing the no-results-file sentence with
# " OP annot state=nopath: sim dir unset for this cell. Run netlist first." --
# an unqualified OP, a bare internal state name, an internal variable -- left
# this row green. The patterns after the blank continuation are SHAPES rather
# than spellings, and they are what lets the row judge a sentence nobody wrote a
# golden for: an underscore or an equals sign is an identifier, not English; a
# namespace separator or the program's own command name is the machine talking;
# and the eleven bare state words are names this code calls itself by.
#
# ⚠ THE SHAPES ARE SAFE ONLY BECAUSE THE FIXTURE IS JARGON-FREE, which is the
# same reason the header gives for the path. `opa_a11_sentences` passes a path
# with no underscore in it and symbol types spelled nmos, pmos, res, cap, ind.
# A real symbol type -- sky130_fd_pr__nfet_01v8 -- carries underscores and is
# legitimately shown to the user, so anyone widening the fixture must widen it
# with jargon-free names or this row will red on the fixture instead of the
# wording.
set A11_BANNED [list {*NO RAW*} {*database*} {*sim_type*} {* raw *} {*raw file*} \
                     {*annot_show*} {*raw_clear*} {*COULD NOT LOAD*} \
                     {*STALE RESULTS*} {*NO CURSOR*} \
                     {*_*} {*=*} {*::*} {*xschem *} {*OP *} \
                     {*noop*} {*nopath*} {*noraw*} {*notop*} {*notran*} \
                     {*nocursor*} {*staleraw*} {*viewerdiff*} {*okclamped*} \
                     {*nodata*} {*viewerunread*} {*viewergone*} {*viewerfilling*}]
proc opa_a11_jargon {s} {
  set hits {}
  foreach p $::A11_BANNED { if {[string match $p $s]} { lappend hits $p } }
  return $hits
}
# ⚠ THE CONTROL, AND IT IS THE HALF THAT KEEPS THIS ROW HONEST. A ban list is
# an instrument that reads green whether it is working or unplugged, so three
# sentences that MUST be caught are run through it. The first is the real
# jargon that slipped past the ten literals; the second is the shipped spelling
# the rewrite removed; the third is what a hurried debug line looks like.
set A11_CONTROL [list \
  { OP annot state=nopath: sim dir unset for this cell. Run netlist first.} \
  {Transient annotation -- NO RAW FILE loaded} \
  {annot mask now 3, see cadence::_annot_msg}]
set a11_bad {}
set a11_nonascii {}
set a11_ctlmute {}
foreach _a11s [opa_a11_sentences] {
  foreach _a11h [opa_a11_jargon $_a11s] { lappend a11_bad [list $_a11h $_a11s] }
  if {![opa_a11_ascii $_a11s]} { lappend a11_nonascii $_a11s }
}
foreach _a11s $A11_CONTROL {
  if {![llength [opa_a11_jargon $_a11s]]} { lappend a11_ctlmute $_a11s }
}
check {A11-7 no sentence the user can be shown carries the program's own vocabulary, every one of them is plain ASCII, and the ban list can still catch jargon} \
  [list [llength $a11_bad] [lindex $a11_bad 0] [llength $a11_nonascii] [lindex $a11_nonascii 0] \
        [llength $a11_ctlmute] [lindex $a11_ctlmute 0]] \
  [list 0 {} 0 {} 0 {}]

# ===========================================================================
# A11-8 — THE SWEEP: THE FIVE SENTENCES THAT BYPASS BOTH MINTS
# ===========================================================================
# ⚠ TWO OF THEM ARE ONE SENTENCE AT TWO CALL SITES, which is the D5-4 breach in
# its purest form: one message, two places to edit, and only a reader comparing
# them can tell they are meant to agree. It is minted here as
# `ase::ui::annot_fail_msg` and rendered by both.
# ⚠ THE ase_window STALE SENTENCE DELIBERATELY DOES NOT REUSE THE MINT'S WORDS.
# Row V43 requires "is older than the circuit it describes" to appear in
# utils/annot_mode.tcl and NOWHERE ELSE, so this surface -- which speaks about
# the same situation from ASE-L's own side, with an `ase:` prefix -- gets its
# own sentence rather than a copy of a sentence it does not own.
set A11_SWEEP [list \
  [list $A11_ASEW {could not put the results from}] \
  [list $A11_ASEW {is from an earlier run than the circuit now on screen}] \
  [list $A11_ASEW {so there is nothing to annotate}] \
  [list $A11_ASEW {The helper it needs was not installed}] \
  [list $A11_ASE  {did not put anything on the schematic}]]
set A11_SWEEPF [list $A11_MINT $A11_ASEW $A11_ASE [file join $repo src xschem.tcl] $N_RC]
set a11_sweep {}
foreach _a11r $A11_SWEEP {
  set _a11home [lindex $_a11r 0]
  set _a11f    [lindex $_a11r 1]
  foreach _a11file $A11_SWEEPF {
    set _a11n [opa_v_ngrep $_a11file $_a11f]
    if {$_a11file eq $_a11home} {
      lappend a11_sweep [expr {$_a11n == 1 ? 1 : 0}]
    } else {
      lappend a11_sweep [expr {$_a11n == 0 ? 1 : 0}]
    }
  }
}
check {A11-8 the five sentences that bypass the two mints are plain English, each minted once, and the duplicated one is minted at all} \
  [list $a11_sweep \
        [opa_v_ngrep $A11_ASEW {^proc ase::ui::annot_fail_msg }] \
        [opa_v_ngrep $A11_ASEW {ase: cannot annotate}]] \
  [list {1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1} 1 0]

# ===========================================================================
# A11-9 — THE BUDGET IS THE C SIDE'S BUDGET, AND THE C SIDE COUNTS BYTES
# ===========================================================================
# ⚠ THE AMPUTATION THIS SECTION EXISTS TO REPAIR WAS STILL LIVE AFTER THE
# REPAIR, and no row in this file could see it. `xschem statusmsg` stores the
# line in statusmsg_text[256] (src/xschem.h) and `my_strncpy` fills it in BYTES;
# the budget in utils/annot_mode.tcl counted Tcl CHARACTERS and defended itself
# by saying every sentence minted there is plain printable ASCII. That is true
# of the WORDING and false of the SENTENCE: three of the eight states paste the
# user's own results-file path into it, and a path is whatever the designer
# named their directory.
#
# ⚠ MEASURED, ON THE SHIPPED BINARY, 2026-08-28. A project under a directory of
# accented characters, the cell not yet simulated: 225 characters, 256 bytes.
# The old budget waved it through because 225 <= 255, C cut it at 255 bytes, and
# the sentence died mid-token with no "..." to say it had -- exactly the defect
# the pass was written to remove, wearing the fix as a disguise. Swapping the
# ruler back to characters reds legs 3, 4 and 7 below.
#
# The fixture builds its non-ASCII path with `format %c`, so THIS FILE stays
# plain ASCII and cannot itself be the thing that changes when an editor
# rewrites an encoding.
set a11_e  [format %c 233]
set a11_np "/home/analog/[string repeat $a11_e 31][string repeat a 60]/run.raw"
set a11_nm [lindex [rcall [list cadence::_annot_msg 1 noraw $a11_np {}]] 1]
set a11_nf [lindex [rcall [list cadence::_annot_fit $a11_nm]] 1]
catch {xschem statusmsg -hold ZZA11BYTESENTINEL}
catch {xschem statusmsg -hold $a11_nf}
set a11_nb [lindex [rcall {xschem get statusmsg}] 1]
check {A11-9 the status-line budget is measured in the bytes the C side stores, so a results path that is not plain ASCII is elided rather than amputated} \
  [list [expr {[string length $a11_nm] <= 255 ? 1 : 0}] \
        [expr {[opa_a11_bytes $a11_nm] > 255 ? 1 : 0}] \
        [expr {$a11_nf ne $a11_nm ? 1 : 0}] \
        [expr {[opa_a11_bytes $a11_nf] <= 255 ? 1 : 0}] \
        [string range $a11_nf end-2 end] \
        [expr {[string first [string range $a11_nf 0 end-3] $a11_nm] == 0 ? 1 : 0}] \
        [expr {$a11_nb eq $a11_nf ? 1 : 0}] \
        [lindex [rcall [list cadence::_annot_fit [string repeat x 255]]] 1]] \
  [list 1 1 1 1 {...} 1 1 [string repeat x 255]]

# ===========================================================================
# A11-10 — THE BUDGET STAYS HONEST AS THE SENTENCES DRIFT
# ===========================================================================
# ⚠ ONE ROW, 386 COMBINATIONS, AND IT IS THE ONLY THING STANDING BETWEEN THE
# NEXT WORDING CHANGE AND THE DEFECT THIS PASS REPAIRS. Eight masks by eight
# states by three symbol-type lists by two results-file paths, one of them
# absurdly long, plus the two no-operating-point shapes. A clause that grows by
# a sentence reds HERE, legibly, instead of amputating a status line on a
# combination nobody happened to try.
# ⚠ THREE PATHS, AND THE THIRD ONE IS NOT DECORATION. The sweep used to run two
# ASCII paths and measure the result with `string length`, so all of its
# combinations agreed with the budget about the WRONG UNIT and the row could not
# have caught the byte overflow A11-9 documents. The third path is the one a
# designer with an accented project directory actually has, and the measurement
# below is now the same one the C side makes.
set a11_over {}
set a11_lp "/tmp/[string repeat z 280]/results.data"
set a11_up "/tmp/[string repeat [format %c 233] 90]dir/results.data"
foreach _a11m {0 1 2 3 4 5 6 7} {
  foreach _a11st {off live noop loaded failed noraw nopath stale} {
    foreach _a11ty [list {} {nmos} {nmos pmos res cap ind}] {
      foreach _a11p [list /tmp/a/results.data $a11_lp $a11_up] {
        ## ⚠ ISSUE 0909's CLAUSE JOINS THE SWEEP, AND SO DOES THE MINT'S OWN
        ## RETURN CODE. The row used to measure the FITTED string only, so a
        ## cadence::_annot_msg that RAISED handed its error text to the budget,
        ## got a short string back and passed — which is exactly what a call
        ## with an argument the mint does not accept yet looks like.
        foreach _a11cz [list {} $A11_CAUSE_NOCARDS $A11_CAUSE_NOPARAMS \
                             $A11_CAUSE_SOMEDEV] {
          set _a11r [rcall [list cadence::_annot_msg $_a11m $_a11st $_a11p $_a11ty $_a11cz]]
          set _a11f [rcall [list cadence::_annot_fit [lindex $_a11r 1]]]
          if {[lindex $_a11r 0] != 0 || [lindex $_a11f 0] != 0 \
              || [opa_a11_bytes [lindex $_a11f 1]] > 255} {
            lappend a11_over [list $_a11m $_a11st [llength $_a11ty] [string length $_a11p] \
                                   [string length $_a11cz] [lindex $_a11r 1] \
                                   [opa_a11_bytes [lindex $_a11f 1]]]
          }
        }
      }
    }
  }
}
foreach _a11a [list [list 1 notop tran {}] [list 1 notop {} {}]] {
  set _a11r [rcall [concat [list cadence::_annot_msg] $_a11a]]
  set _a11f [rcall [list cadence::_annot_fit [lindex $_a11r 1]]]
  if {[lindex $_a11f 0] != 0 || [opa_a11_bytes [lindex $_a11f 1]] > 255} {
    lappend a11_over [list notop $_a11a]
  }
}
check {A11-10 every sentence the surface can build fits the status line after the budget, at any results-file path length and in any encoding} \
  [list [llength $a11_over] [lindex $a11_over 0]] \
  [list 0 {}]

# ===========================================================================
# A11-12 — EVERY STATE CLAUSE HAS A BYTE-EXACT GOLDEN, THE FIRST ONE INCLUDED
# ===========================================================================
# ⚠ THE SENTENCE MOST USERS MEET FIRST HAD NO GOLDEN AT ALL. A cell that has
# been drawn but never simulated reports the `nopath` clause, and until now the
# only byte-exact assertion of it in the tree lived in
# tests/headless/test_results_freshness.tcl -- a suite no runner carries. The
# constant for it sat in this file, defined and never referenced, from the day
# it was written. Measured 2026-08-28: the whole clause could be replaced with
# internal jargon and this suite still reported ALL PASS.
#
# All eight states are here rather than the one, because a set with a hole in it
# is how the hole got there. `off` contributes no clause, which is itself the
# claim -- a mask sentence with nothing appended.
set a11_gp /tmp/zzA11/results.data
set a11_got {}
foreach _a11st {off live noop loaded failed noraw nopath stale} {
  lappend a11_got [lindex [rcall [list cadence::_annot_msg 1 $_a11st $a11_gp {}]] 1]
}
set a11_want {}
foreach _a11c [list $A11_OFFC $A11_LIVE $A11_NOOP $A11_LOADED $A11_FAILED \
                    $A11_NORAW $A11_NOPATH $A11_STALE] {
  lappend a11_want "$A11_M1[string map [list @P@ $a11_gp @T@ [file tail $a11_gp]] $_a11c]"
}
check {A11-12 every state the user can land in renders its own sentence, byte for byte, the never-simulated one included} \
  $a11_got $a11_want

# ===========================================================================
# A11-12b — ISSUE 0909: EVERY REASON A DEVICE ROW CAN BE BLANK HAS ITS OWN
#                       SENTENCE, AND THE SENTENCE LANDS WHERE IT WAS PUT
# ===========================================================================
# ⚠ THE PRESS SUCCEEDS AND THE VALUES ARE BLANK, AND UNTIL ISSUE 0909 THE
# SURFACE HAD NO WORDS FOR THAT AT ALL. Measured 2026-08-28: grep -c for
# noparams / nosave / save_op / missing param in utils/annot_mode.tcl answered
# 0, and this suite reported ALL PASS with 472 checks while the user's own
# bench showed six blank rows and a silent CIW.
#
# All three causes are asserted, not one, for the reason A11-12's own header
# gives: a set with a hole in it is how the hole got there. And the three are
# separate sentences rather than one, because the remedies differ and
# src/ase.tcl:765's rule applies — a wrong direction printed with authority is
# worse than printing none.
#
# LEG 2 IS THE PLACEMENT, AND IT IS A DECISION, NOT A DETAIL. The clause goes
# after the mask sentence and BEFORE the results-file clause, so that when
# cadence::_annot_fit has to cut, what it sacrifices is the file path rather
# than the answer to the question the user just asked by pressing the key.
set a11_cgot {}
foreach _a11c {nocards noparams somedev} {
  lappend a11_cgot [lindex [rcall [list cadence::_annot_cause_msg $_a11c]] 1]
}
set a11_cplace [lindex [rcall [list cadence::_annot_msg 1 loaded $a11_gp {} \
                                    $A11_CAUSE_NOCARDS]] 1]
check {A11-12b issue 0909 each blank-row cause renders its own sentence, and the clause sits ahead of the results-file clause} \
  [list $a11_cgot $a11_cplace] \
  [list [list $A11_CAUSE_NOCARDS $A11_CAUSE_NOPARAMS $A11_CAUSE_SOMEDEV] \
        "$A11_M1 $A11_CAUSE_NOCARDS[string map [list @P@ $a11_gp] $A11_LOADED]"]

# ===========================================================================
# A11-12c — THE SHORT FORM, AND THE BUDGET THAT IS THE ONLY REASON IT EXISTS
# ===========================================================================
# ⚠ THE PLACEMENT DECISION IN A11-12b IS WORTHLESS IF THE SENTENCE ITSELF DOES
# NOT FIT, AND FOR THE FIRST SHIPPED DRAFT IT DID NOT. Putting the answer ahead
# of "Loaded results from <path>." is meant to make the FILE NAME the thing the
# elision eats. Measured on the delivered tree: the long save-cards sentence is
# 229 bytes against a 55-byte mask sentence, so the cut landed inside the
# REMEDY and the bar read "... Turn on saving..." with no object. Placement
# right, line useless.
#
# So each cause has a second, shorter rendering for the bar, minted in the same
# proc (RULING D5-4) and asked for by argument. This row holds all three to the
# budget the bar actually has, with the longest state clause attached, and
# requires that cadence::_annot_fit have nothing to do — an elision marker on
# the end of any of them is this row's failure, not its tolerance.
set a11_csgot {}
set a11_csfit {}
foreach _a11c {nocards noparams somedev} {
  set _a11s [lindex [rcall [list cadence::_annot_cause_msg $_a11c short]] 1]
  lappend a11_csgot $_a11s
  set _a11line [lindex [rcall [list cadence::_annot_msg 1 live {} {} $_a11s]] 1]
  set _a11fit  [lindex [rcall [list cadence::_annot_fit $_a11line]] 1]
  lappend a11_csfit [expr {($_a11fit eq $_a11line) && ![string match {*...} $_a11fit] ? 1 : 0}]
}
check {A11-12c issue 0909 the status line gets a short form of each cause, and it survives the 255-byte budget whole} \
  [list $a11_csgot $a11_csfit] \
  [list [list $A11_CAUSE_NOCARDS_S $A11_CAUSE_NOPARAMS_S $A11_CAUSE_SOMEDEV_S] \
        {1 1 1}]

# ===========================================================================
# A11-13 — EVERY REFUSAL THE USER CAN ACT ON ENDS WITH WHAT TO DO
# ===========================================================================
# ⚠ THE THIRD LEG OF THE USER'S STANDARD, AND IT LIVED WHERE NOTHING COULD SEE
# IT. A sentence has to say WHAT HAPPENED, give the CONTEXT that makes it make
# sense, and -- where the user can act -- say WHAT TO DO. The first two are a
# matter of reading; the third is not. Nine states leave the user holding a key
# that did nothing, and every one of them has a next step: run a simulation,
# turn on a cursor, load a different results file, plot the results again.
#
# This is the property tests/headless/test_results_freshness.tcl calls A11-11.
# It is repeated here deliberately: this file is the feature's registered row
# set, and a standard that only a hand-run suite enforces is a standard the next
# wording change can walk past.
set A11_REMEDIES [list {Run } {Turn on } {Load } {Plot } {try again}]
set a11_mute {}
foreach _a11st {noop noraw nopath stale} {
  set _a11m [lindex [rcall [list cadence::_annot_msg 1 $_a11st $a11_gp {}]] 1]
  set _a11ok 0
  foreach _a11r $A11_REMEDIES { if {[string match "*$_a11r*" $_a11m]} { set _a11ok 1 } }
  if {!$_a11ok} { lappend a11_mute [list press-6 $_a11st $_a11m] }
}
foreach _a11st {nocursor noraw notran staleraw viewerdiff viewerunread} {
  set _a11m [lindex [rcall [list cadence::_annot_tran_msg $_a11st 1e-09 A $a11_gp]] 1]
  set _a11ok 0
  foreach _a11r $A11_REMEDIES { if {[string match "*$_a11r*" $_a11m]} { set _a11ok 1 } }
  if {!$_a11ok} { lappend a11_mute [list cursor-annotate $_a11st $_a11m] }
}
check {A11-13 every refusal the user can act on says what to do next} \
  [list [llength $a11_mute] [lindex $a11_mute 0]] \
  [list 0 {}]

# ===========================================================================
# A11-13b — ISSUE 0909: A BLANK BLOCK IS SOMETHING THE USER CAN ACT ON, SO
#                       EVERY CAUSE SENTENCE SAYS WHAT TO DO
# ===========================================================================
# ⚠ ITS OWN ROW, NOT A WIDER LOOP IN A11-13. A11-13 sweeps STATES; these are
# CAUSES, a different axis, and quietly widening that loop would hide a new
# claim inside an old row's name. The standard is identical and the user's
# words are the same ones: if we annotate param = <blank> we need to tell the
# user why — and, where they can act, what to do about it.
#
# ⚠ THE ONE CAUSE WITH NO NEXT STEP IS DELIBERATELY NOT IN THIS SET. A symbol
# type nobody registered a descriptor for cannot be fixed by the user today
# (issue 0906 is documentation only), so it keeps the already-minted "These
# symbol types have no operating-point values to show" clause and no remedy at
# all. Inventing a next step for it would be the wrong-direction defect wearing
# this row's standard as a licence.
#
# ⚠ BOTH FORMS ARE SWEPT, NOT JUST THE LONG ONE. The short form exists BECAUSE
# the long one was losing its remedy to the 255-byte status line, so a short
# form that arrives whole and says nothing about what to do would have made the
# repair cosmetic. A loop over the long form alone would not have noticed.
set a11_cmute {}
foreach _a11c {nocards noparams somedev} {
  foreach _a11f {long short} {
    set _a11m [lindex [rcall [list cadence::_annot_cause_msg $_a11c $_a11f]] 1]
    set _a11ok 0
    foreach _a11r $A11_REMEDIES { if {[string match "*$_a11r*" $_a11m]} { set _a11ok 1 } }
    if {!$_a11ok} { lappend a11_cmute [list blank-cause $_a11c $_a11f $_a11m] }
  }
}
check {A11-13b issue 0909 every blank-row explanation says what to do next, in both forms} \
  [list [llength $a11_cmute] [lindex $a11_cmute 0]] \
  [list 0 {}]

} a11err]} {
  puts "UNEXPECTED ERROR (section A11): $a11err"
  incr fail
}


# ============================================================================
# NM — WHERE THE MODEL NAME COMES FROM (issue 0965)
# ============================================================================
# THE USER-VISIBLE DEFECT. On the shipped sky130_tests_ase/tb_bandgap bench two
# of the 78 transistors annotate as six blank rows each. The names this tree
# asks the simulator for are
#     @m.x1.x5.xm2.msky130_fd_pr__pfet_01v8_lvt
#     @m.x1.x6.xm2.msky130_fd_pr__pfet_01v8_lvt
# and the deck that ran contains neither of them. Nothing says a word.
#
# WHY, MEASURED. Those two are passgates whose SCHEMATIC LINE overrides the
# transistor model - modelp=pfet_01v8_lvt - while passgate.sym's format= string
# never mentions modelp. So the netlister writes ONE .subckt passgate body for
# all five passgates, built from the SYMBOL TEMPLATE default pfet_01v8, and the
# override is not passed down at all. The annotation name builder asks
# `xschem translate <inst> @model`, which on a LIVE DESCEND answers from the
# parent instance's own property and so says pfet_01v8_lvt. The deck follows the
# symbol template; the annotation follows the schematic; they disagree.
#
# The seam is src/token.c:2701-2743, translate's four rounds for an @token:
#   r2  translate3(val,0, inst.prop_ptr, PARENT_PROP_PTR, template, NULL)
#   r4  translate3(val,0, inst.prop_ptr, PARENT_TEMPL,    NULL,     NULL)
# xctx->hier_attr[currsch-1] is filled DIFFERENTLY by the two callers:
#   src/spice_netlist.c:492-495  templ = sym.templ, prop_ptr = sym.parent_prop_ptr
#                                (NULL unless the instance carried schematic=)
#   src/actions.c:4780-4783      templ = sym.templ, prop_ptr = inst.prop_ptr
# so a live descend answers at r2 from the instance override and never reaches
# r4, while the netlister falls through to r4 and answers from the template.
#
# WHAT THESE ROWS REQUIRE. One resolver, op_annot::model_netlist, that answers
# the way the NETLISTER answers, wired into op_annot::devpath - both its devproc
# arm and its devpath-template arm - so the save card and the on-screen row are
# spelled the same way and both match the deck.
#
# THE FIXTURE IS THE BENCH IN MINIATURE, and it was measured against the real
# netlister before these rows were written: one .subckt nmpass body carrying
# sky130_fd_pr__pfet_01v8, reached from two instances one of which overrides
# modelp. NM4 is the netlister's own exception and needs a SEPARATE block.

set NM_LIB [file join $scratch nmlib]
file delete -force $NM_LIB
file mkdir $NM_LIB

## The enclosing cell: format= DROPS @modelp, template= carries the default.
## This is passgate.sym's shape, cut down to one pin.
##
## ⚠ THE template= STRING IS TWO LINES, AND THAT IS DELIBERATE. The shipped
## sky130_tests/passgate/symbol/passgate.sym wraps its template at
## `VSSBPIN=VSS ` and carries `modelp=pfet_01v8` on the SECOND line, and
## `xschem globals` prints the value verbatim, newline and all. A reader of it
## that stopped at the first newline would answer with half the template and
## drop the very key op_annot::model_netlist is looking up. With this fixture
## one line long that guard had no witness at all: sabotaged, NM1-NM6 all
## stayed green and only the 20-second real-bench rows caught it. Two lines
## here and NM2 is its witness. Keep `modelp` on the second line.
set fnm [open [file join $NM_LIB nmpass.sym] w]
puts $fnm {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1
modelp=pfet_01v8"
extra="modelp"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}
close $fnm

## Its body: one shipped sky130 pfet whose model is the parameter, exactly as
## sky130_tests/passgate/schematic/passgate.sch:M2 spells it — plus ONE extra
## property, `modelname=zz9`, which the shipped cell does not carry. It is
## there so row NM8 has a LONGER @-token beginning with the six characters
## `@model` that resolves to something recognisable, and nothing else reads it.
set fnm [open [file join $NM_LIB nmpass.sch] w]
puts $fnm {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {devices/iopin} 200 -300 0 1 {name=p1 lab=A}
C {sky130_fd_pr/pfet_01v8} 400 -300 0 0 {name=M2
L=0.15
W=W_P
nf=1
mult=1
model=@modelp
modelname=zz9
spiceprefix=X
}}
close $fnm

## A byte copy, so the schematic= instance really does reach a DIFFERENT file
## and the netlister really does write a second block for it. Measured: with
## schematic= naming the very file the symbol already points at, no extra block
## is made and NM4 would be vacuous.
file copy -force [file join $NM_LIB nmpass.sch] [file join $NM_LIB nmpass_alt.sch]

## A second enclosing cell whose body spells the model as a LITERAL on the
## device instance. Its template carries a modelp that must NEVER be reached.
set fnm [open [file join $NM_LIB nmlit.sym] w]
puts $fnm {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P"
template="name=x1 W_P=1 modelp=pfet_01v8"
extra="modelp"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}
close $fnm
set fnm [open [file join $NM_LIB nmlit.sch] w]
puts $fnm {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {devices/iopin} 200 -300 0 1 {name=p1 lab=A}
C {sky130_fd_pr/pfet_01v8} 400 -300 0 0 {name=M3
L=0.15
W=W_P
nf=1
mult=1
model=pfet_01v8_hvt
spiceprefix=X
}}
close $fnm

## A third enclosing cell, added by ISSUE 1201, whose SPICE line DOES read the
## setting -- `modelp=@modelp` is in its format=, so the setting is passed down
## as a cell parameter and is not lost. That matters because the netlister now
## writes a copy its own version of a cell whenever the setting would otherwise
## go nowhere AND the cell's drawing uses it. This one does not qualify: the
## setting is on the call line where it belongs, so no separate copy is written
## -- and a SPICE .subckt parameter still cannot carry a model NAME into the
## body, which resolves it from the template. So the deck says one thing and a
## live descend says another, which is issue 0965's own subject, and this cell
## keeps it reachable for good.
set fnm [open [file join $NM_LIB nmfmt.sym] w]
puts $fnm {v {xschem version=3.4.4 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname W_P=@W_P modelp=@modelp"
template="name=x1 W_P=1
modelp=pfet_01v8"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
T {@symname} -20 -34 0 0 0.2 0.2 {}}
close $fnm
file copy -force [file join $NM_LIB nmpass.sch] [file join $NM_LIB nmfmt.sch]

## x3 takes the default; x5 overrides it on its own schematic line. That single
## difference is the whole of issue 0965.
##
## ⚠ x11 IS WHERE THE 0965 ROWS LIVE NOW, ISSUE 1201, AND x5 IS WHY. x5's cell
## drops the setting entirely and its drawing builds the transistor out of it,
## so the netlister now gives x5 a copy of the cell to itself with the setting
## in it -- the deck and the schematic agree about x5 and there is no longer a
## disagreement there to measure. x11's cell passes the setting down as a cell
## parameter instead, which a SPICE .subckt cannot use for a model NAME, so the
## disagreement is permanent there and cannot be repaired away. Row NM9 measures
## what x5 became.
set fnm [open [file join $NM_LIB nmtop.sch] w]
puts $fnm {v {xschem version=3.4.4 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {nmpass.sym} 120 0 0 0 {name=x3 W_P=0.5}
C {nmpass.sym} 320 0 0 0 {name=x5 W_P=0.6 modelp=pfet_01v8_lvt}
C {nmlit.sym} 520 0 0 0 {name=x9 W_P=0.9 modelp=pfet_01v8_lvt}
C {nmpass.sym} 720 0 0 0 {name=x8 W_P=0.8 modelp=pfet_01v8_lvt schematic=nmpass_alt.sch}
C {nmfmt.sym} 920 0 0 0 {name=x11 W_P=0.6 modelp=pfet_01v8_lvt}}
close $fnm

set XSCHEM_LIBRARY_PATH ":[file join $repo sky130A xschem_libs]:[file join $repo xschem_library devices]:$NM_LIB"
opa_source [file join $repo sky130A sky130_procs.tcl]

## Stand inside one instance of the top sheet and answer three questions about
## its one transistor, with everything wrapped so an absent proc says NOPROC
## rather than raising out of the section.
proc nm_ask {idx dev} {
  global NM_LIB
  xschem load [file join $NM_LIB nmtop.sch]
  xschem unselect_all
  xschem select instance $idx
  xschem descend 1 2
  set out {}
  foreach q [list model_netlist translate devpath] {
    switch -- $q {
      model_netlist {
        if {![llength [info commands ::op_annot::model_netlist]]} {
          lappend out NOPROC
        } elseif {[catch {::op_annot::model_netlist $dev} r]} {
          lappend out "RAISED:$r"
        } else { lappend out $r }
      }
      translate {
        if {[catch {xschem translate $dev @model} r]} { lappend out "RAISED:$r" } \
        else { lappend out $r }
      }
      devpath {
        if {[catch {::op_annot::devpath $dev} r]} { lappend out "RAISED:$r" } \
        else { lappend out $r }
      }
    }
  }
  return $out
}

## Drop Tcl comments, so a sentence or a call quoted in a comment cannot satisfy
## a row about where the call is MADE.
proc nm_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] {
    if {[regexp {^\s*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
proc nm_body {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  return [nm_nocomment $b]
}
proc nm_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}

if {[catch {

# --- NM1: the unchanged path, which is 76 of the bench's 78 names -----------
# x3 does not override anything, so the netlister and a live descend agree and
# the resolver must not invent a difference.
check {NM1 issue 0965 with nothing overridden the netlist-basis model lookup\
 gives exactly what the live lookup gives, so the 76 device names on the bench\
 that already resolve keep the answer they have today} \
  [lrange [nm_ask 0 M2] 0 1] {pfet_01v8 pfet_01v8}

# --- NM2: the defect itself, at unit scale (guard GA) -----------------------
# x11's enclosing cell passes modelp down as a cell PARAMETER, which a SPICE
# .subckt cannot use for a model NAME, so the body still builds the transistor
# from the template default. Measured on the real netlister, this build:
#   x11 net3 nmfmt W_P=0.6 modelp=pfet_01v8_lvt
#   .subckt nmfmt A W_P=1 modelp=pfet_01v8
#   XM2 ... sky130_fd_pr__pfet_01v8 ...
# while a live descend answers pfet_01v8_lvt from the instance override. The
# name the user's schematic gets annotated with must be the one the deck holds.
#
# ⚠ THIS ROW WAS ON x5 UNTIL ISSUE 1201 and had to move, because the netlister
# now REPAIRS x5: its cell drops the setting entirely and its drawing builds the
# transistor out of it, so x5 gets a copy of the cell to itself
# (.subckt nmpass__modelp_pfet_01v8_lvt, XM2 sky130_fd_pr__pfet_01v8_lvt) and
# the deck and the schematic agree about it. Row NM9 pins that. Left on x5 this
# row would have gone red on the day the defect it describes was cured, and
# re-pinning it to the new values there would have kept the row's words while
# losing its subject.
check {NM2 issue 0965 the enclosing cell does not pass its model setting into\
 the netlist, so the device is named the way the DECK spells it and not the way\
 the schematic line reads} \
  [nm_ask 4 M2] \
  {pfet_01v8 pfet_01v8_lvt @m.x11.xm2.msky130_fd_pr__pfet_01v8}

# --- NM9: what x5 became, issue 1201 ----------------------------------------
# The copy that used to be the 0965 witness is the 1201 witness now. x5 types
# modelp on itself and nothing else -- no cell name of its own, no attribute of
# any kind -- and the netlister writes it its own version of the cell with that
# device in it. The annotation surface has to follow: it must name the device
# the way the SIMULATOR will, or it asks the results file for a device under a
# name that was never in the deck and the schematic gets no numbers at all.
# Measured on the real netlister, this build: x5 calls
# nmpass__modelp_pfet_01v8_lvt, whose XM2 reads sky130_fd_pr__pfet_01v8_lvt.
check {NM9 issue 1201 the copy that types a setting and nothing else gets its\
 own version of the cell from the netlister, so the deck and the schematic line\
 now AGREE about it -- and the device the annotation asks the results file for\
 is the low-threshold one the deck really built} \
  [nm_ask 1 M2] \
  {pfet_01v8_lvt pfet_01v8_lvt @m.x5.xm2.msky130_fd_pr__pfet_01v8_lvt}

# --- NM3: a literal on the device consults nothing --------------------------
check {NM3 issue 0965 a transistor whose own line spells the model outright\
 keeps that model, whatever the cell around it was set to} \
  [lrange [nm_ask 2 M3] 0 1] {pfet_01v8_hvt pfet_01v8_hvt}

# --- NM4: the netlister's own exception (guard GB) --------------------------
# THIS ROW IS GUARD GB'S ONLY WITNESS. When the instance carries schematic=,
# get_additional_symbols builds a SEPARATE block for it and spice_netlist.c:494
# hands the parent INSTANCE's property to translate - so the override really is
# in the deck and must be kept. Measured on this fixture: the deck holds
# .subckt nmpass_alt whose device line reads sky130_fd_pr__pfet_01v8_lvt.
check {NM4 issue 0965 when the cell was given its own copy of the sheet the\
 model setting DOES reach the netlist, so the override is kept and the device\
 keeps the name the deck really uses} \
  [nm_ask 3 M2] \
  {pfet_01v8_lvt pfet_01v8_lvt @m.x8.xm2.msky130_fd_pr__pfet_01v8_lvt}

# --- NM5: STRUCTURAL, invariant I1 - one lookup, one place ------------------
set NM_DPB [nm_body ::op_annot::devpath]
set NM_MNB [nm_body ::op_annot::model_netlist]
set NM_SRC [nm_nocomment [opa_slurp [file join $repo src op_annot.tcl]]]
## How many CODE lines ask the program to resolve a device model - i.e. carry
## both the verb and the token. Line-based, so a wrapped call still counts once
## and a mention in a comment counts not at all.
proc nm_lookups {t} {
  if {$t eq {NOPROC} || [string match RAISED:* $t]} { return $t }
  set n 0
  foreach l [split $t "\n"] {
    if {[string first {xschem translate} $l] >= 0 && [string first {@model} $l] >= 0} { incr n }
  }
  return $n
}
check {NM5 issue 0965 STRUCTURAL the model a device is named after is looked up\
 in ONE place, the name builder uses that place, and no arm of it asks the\
 question a second way} \
  [list [expr {($NM_DPB ne {NOPROC} && [nm_count $NM_DPB {model_netlist}] >= 1) ? 1 : 0}] \
        [nm_lookups $NM_DPB] \
        [nm_lookups $NM_SRC] \
        [nm_lookups $NM_MNB]] \
  {1 0 1 1}

# --- NM6: the devpath-template arm takes the same answer --------------------
# A descriptor may carry a devpath TEMPLATE instead of a devproc, and spec
# section 4.2's own template interpolates @model. Registering one over the
# sky130 pmos key exercises that arm on the same fixture.
catch {op_annot::register pmos [list devpath $TMPL_AT match {*sky130_fd_pr/*} \
  params {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}]}
set NM6 [nm_ask 4 M2]
opa_source [file join $repo sky130A sky130_procs.tcl]
check {NM6 issue 0965 a PDK that spells its device path with a template rather\
 than a script gets the same model, so the two ways of describing a PDK cannot\
 name the same transistor differently} \
  [lindex $NM6 2] {@m.x11.xm2.msky130_fd_pr__pfet_01v8}

# --- NM7: the token boundary, as a unit ------------------------------------
# NM6 cannot see this: TMPL_AT ends at @model, so every way of substituting it
# gives the same answer. A descriptor is free to spell a LONGER token that
# starts with the same six characters -- @modelname, @modelp, @model_hi -- and
# a plain `string map` would rewrite the front of every one of them, handing
# `translate` a plausible-looking wrong device path with nothing said. That is
# the silent drift invariant I1 exists to prevent, so the boundary gets its own
# row rather than being taken on trust from a comment.
proc nm_sub {t} {
  if {![llength [info commands ::op_annot::_subst_model]]} { return NOPROC }
  if {[catch {::op_annot::_subst_model $t ZZ} r]} { return "RAISED:$r" }
  return $r
}
check {NM7 issue 0965 a device-path template that also spells a LONGER word\
 starting with the same six letters keeps that longer word untouched -- only\
 the model token itself is replaced, wherever it appears and however many\
 times} \
  [list [nm_sub {@model}] \
        [nm_sub {\@m.@name\.m@model}] \
        [nm_sub {@modelname}] \
        [nm_sub {@modelp}] \
        [nm_sub {@model_hi}] \
        [nm_sub {a@model b@modelname c@model}] \
        [nm_sub {}] \
        [nm_sub {no tokens at all}]] \
  [list {ZZ} \
        {\@m.@name\.mZZ} \
        {@modelname} \
        {@modelp} \
        {@model_hi} \
        {aZZ b@modelname cZZ} \
        {} \
        {no tokens at all}]

# --- NM8: the same boundary, end to end through the name builder ------------
# The fixture device carries `modelname=zz9`, so the two halves of the template
# resolve to two visibly different things and a row can tell which one moved.
# With the boundary gone the tail would read `pfet_01v8name` -- a device path
# no deck contains, produced without one word of complaint.
catch {op_annot::register pmos [list \
  devpath {\@m.@path@spiceprefix@name\.msky130_fd_pr__@model\.@modelname} \
  match {*sky130_fd_pr/*} \
  params {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}]}
set NM8 [nm_ask 4 M2]
opa_source [file join $repo sky130A sky130_procs.tcl]
check {NM8 issue 0965 with the model token and a longer word beside it in one\
 device-path template, only the model token is filled in and the longer word is\
 left for the design to answer -- so the built name is the one the deck really\
 spells} \
  [lindex $NM8 2] {@m.x11.xm2.msky130_fd_pr__pfet_01v8.zz9}

} nmerr]} {
  puts "UNEXPECTED ERROR (section NM): $nmerr"
  incr fail
}

# --- verdict -----------------------------------------------------------------
# ⚠ THE DUAL BANNER IS REQUIRED BY tests/run_regression.tcl's hcases list, which
# this file is registered in. banner_complete (tests/banner_rule.tcl) needs a
# WHOLE-LINE "OVERALL: ok" as well as the RESULT line; registering a suite there
# without one reproduces the completion-sentinel false red that has been filed
# four separate times as 0420 / 0492 / 0629 / 0689.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
