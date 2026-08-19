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
# ⚠ NO NGSPICE RUNS HERE. IHP cannot be simulated on this box at all — measured:
# ngspice-42 supports OSDI v0.3 while ihp-sg13g2/osdi/psp103.osdi targets v0.4,
# so `ngspice -b` aborts with "Simulation interrupted due to error". The
# raw-header assertions (the names are real, the values are not all zero, no
# `unrecognized variable` on stderr) are S4's and must be built on sky130/gf180.
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
set P_SKY_PARAMS {{id id 0} {gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2}
                  {cgg cgg 1}}
set P_SKY_PNAMES {id gm gds vth vdsat cgg}
# The prototype's exact seven, for the byte-for-byte card diff only. ⚠ NOT
# touched by D8: row P3 temporarily overrides `params` with this list to diff
# against sky130_save_fet_params, and the PROTOTYPE still emits cgso/cgdo. When
# S5 deletes the prototype this list goes with it.
set P_SKY_P7     {{gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2}
                  {cgg cgg 1} {cgso cgso 1} {cgdo cgdo 1}}
set P_GF_PARAMS  {{id id 0} {gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2}}
# D4: sg13g2_write_save_lines:310-319 and :331-339, in that ORDER. Kinds are
# sg13g2_display_fet_params:461-470 and _bip_params:524-536, the only authority
# for kind in the tree — a wrong kind makes the save card succeed and the read
# silently miss.
set P_IHP_FET_PARAMS {{ids ids 0} {gm gm 1} {gds gds 1} {vth vth 2} {vgs vgs 2}
                      {vdss vdss 2} {vds vds 2} {cgg cgg 1} {cgsol cgsol 1}
                      {cgdol cgdol 1}}
set P_IHP_NPN_PARAMS {{gm gm 1} {go go 1} {gmu gmu 1} {gpi gpi 1} {gx gx 1}
                      {vbe vbe 2} {vbc vbc 2} {ib ib 0} {ic ic 0} {cbe cbe 1}
                      {cbc cbc 1} {cbep cbep 1} {cbcp cbcp 1}}
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
set P_DERIVEDACC [list [list sky130:nmos      {ft gm/id}         {}] \
                       [list sky130:pmos      {ft gm/id}         {}] \
                       [list gf180:nmos       {gm/id}            {}] \
                       [list gf180:pmos       {gm/id}            {}] \
                       [list ihp:nmos         {cgg_tot ft gm/id} {}] \
                       [list ihp:pmos         {cgg_tot ft gm/id} {}] \
                       [list ihp:vertical_npn {rin vce ft}       {}]]

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
check {P10 sky130 pinexpr round-trips verbatim and is non-numeric with no raw} \
  [rcall {set e [lindex [lindex [dict get [op_annot::descriptor nmos] pinexpr] 0] 1]
          list [opa_norm [dict get [op_annot::descriptor nmos] pinexpr]] \
               [xschem translate M2 $e] \
               [string is double -strict [xschem translate M2 $e]]}] \
  [list 0 [list [opa_norm $P_PINEXPR] { -  } 0]]

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

# ⚠ THE STEP'S HEADLINE ACCEPTANCE: byte-for-byte against
# sg13g2_write_save_lines. An empty diff here is the proof the generalization
# lost nothing. Counts are in the golden so an empty-vs-empty run cannot pass.
xschem load [file join $repo ihp-sg13g2 xschem_libs sg13g2_tests dc_lv_nmos \
                       schematic dc_lv_nmos.sch]
check {P19 ACCEPTANCE IHP dc_lv_nmos: 10 bare cards == sg13g2_save_params} \
  [rcall {opa_card_diff [sg13g2_save_params]}] {0 {10 10 1 {}}}

xschem load [file join $repo ihp-sg13g2 xschem_libs sg13g2_tests dc_lv_pmos \
                       schematic dc_lv_pmos.sch]
check {P20 ACCEPTANCE IHP dc_lv_pmos: 10 bare cards == sg13g2_save_params} \
  [rcall {opa_card_diff [sg13g2_save_params]}] {0 {10 10 1 {}}}

# 26 = 13 params x two HBTs, npn13G2 and npn13G2_5t, both collapsing to qnpn13g2.
xschem load [file join $repo ihp-sg13g2 xschem_libs sg13g2_tests dc_hbt_13g2_5t \
                       schematic dc_hbt_13g2_5t.sch]
check {P21 ACCEPTANCE IHP dc_hbt_13g2_5t: 26 bare cards == sg13g2_save_params} \
  [rcall {opa_card_diff [sg13g2_save_params]}] {0 {26 26 1 {}}}

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

# ===========================================================================
# S28 — ISSUE 0444, THE STORED STRINGS (before any fixture, both PDKs)
# ===========================================================================
# Asserted on what `op_annot::register` actually stored, so a later
# re-tightening of the spelling reds here rather than silently blanking two
# rows on two of the three PDKs.
set XSCHEM_LIBRARY_PATH $P_GF_LIBS
opa_clear_store
opa_source [file join $repo gf180mcuD gf180_procs.tcl]
set s_gf_pin [opa_norm [dict get [op_annot::descriptor nmos] pinexpr]]
set XSCHEM_LIBRARY_PATH $P_SKY_LIBS
opa_clear_store
opa_source [file join $repo sky130A sky130_procs.tcl]
set s_sky_pin [opa_norm [dict get [op_annot::descriptor nmos] pinexpr]]
check {S28 0444 sky130 AND gf180 pinexpr carry the space token.c:24 needs} \
  [list $s_sky_pin $s_gf_pin] [list [opa_norm $P_PINEXPR] [opa_norm $P_PINEXPR]]

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
# (save.c:1988), so cursor_b_val stays my_calloc-zeroed and EVERY point -1 read
# returns a fabricated 0.0 while point 0 holds the true value. In a process
# where an annotate_op has already published, cursor_b_val survives a later
# `xschem load` and this row passes vacuously.
#
# The gate is copied from the C's own read gate (token.c:4318/4339), not
# invented: live_cursor2_backannotate && sch_waves_loaded() >= 0 && annot_p >= 0.
# `xschem raw annot`'s first field IS annot_p, and -1 means nothing published.
set s14_read [rcall {xschem raw read [file join $scratch s5_op.raw] op}]
set s14_annot [rcall {xschem raw annot}]
set s14_p0 [rcall {xschem raw value {@m.xm1.msky130_fd_pr__nfet_01v8[gm]} 0}]
set s14_pm1 [rcall {xschem raw value {@m.xm1.msky130_fd_pr__nfet_01v8[gm]} -1}]
check {S14 a raw READ but never PUBLISHED fabricates 0 — and the block stays blank} \
  [list $s14_read $s14_annot $s14_p0 $s14_pm1 \
        [rcall {op_annot::text M1}] \
        [rcall {opa_s5_fabricated [op_annot::text M1]}]] \
  [list {0 1} {0 {-1 0 -1}} {0 9.9999997e-05} {0 0} [list 0 $S_BLANK] {0 {}}]

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

# ⚠ THE THIRD GATE TERM, AND IT MUST BLANK THE WHOLE BLOCK. token.c:4318
# applies live_cursor2_backannotate to every @spice_get_* branch but NOT to
# `xschem raw value`, so a gate built on annot_p alone leaves the block HALF
# populated — six real params and two pinexpr rows reading ` -  ` — which on a
# schematic reads as "the save cards are missing", not as "annotation is off".
set live_cursor2_backannotate 0
set s16_block [rcall {op_annot::text M1}]
set s16_read [rcall {xschem raw value {@m.xm1.msky130_fd_pr__nfet_01v8[gm]} -1}]
set live_cursor2_backannotate 1
check {S16 live_cursor2_backannotate 0 blanks the WHOLE block, not just pinexpr} \
  [list $s16_block $s16_read] [list [list 0 $S_BLANK] {0 9.9999997e-05}]

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

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
