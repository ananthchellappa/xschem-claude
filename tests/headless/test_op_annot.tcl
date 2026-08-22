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
                       [list ihp:vertical_npn {rin vce ft} {}]]

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
#   6        -> cadence::annot_mode op       annot_show 1  (device OP info)
#   Ctrl-6   -> cadence::annot_mode none     annot_show 0
#   Alt-6    -> cadence::annot_mode opvolt   annot_show 3  (+ node voltages)
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
## -> {mode has-trailing-break} for one `bind .drw <chord>` line of the rc.
## The `break` half is not decoration: measured with `event generate`, Ctrl-6
## without it still reaches callback.c:7272 and selects drawing layer 6.
proc opa_n_rcbind {path chord} {
  if {![file isfile $path]} { return {NO-FILE 0} }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  foreach l [split $d \n] {
    if {[string first "bind .drw $chord" $l] < 0} continue
    set mode NO-MODE
    regexp {cadence::annot_mode\s+(\w+)} $l -> mode
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

# ⚠ INTEGERS, NOT BOOLEAN WORDS. annot_show is an int and S7 measured that
# `true`/`on`/`yes` all atoi to 0, i.e. silently OFF. Sabotage SB2 flips the
# opvolt entry to 2 (bit1 only) — the exact drift this table forbids.
check {N1 the mask table is the spec's three states as INTEGERS: none 0, op 1, opvolt 3} \
  [list [rcall {cadence::_annot_mask none}] [rcall {cadence::_annot_mask op}] \
        [rcall {cadence::_annot_mask opvolt}]] \
  {{0 0} {0 1} {0 3}}

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
check {N22 both shipped Annotate-OP menu bodies now write the mask too (decision D8)} \
  [opa_n_grep $N_TCL {xschem set annot_show}] 2

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
  {{} {0 0} 0 {OP annotation OFF}}

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
set ::netlist_dir $N_ND_BAD
check {N5 a LIVE annotation is never reloaded: the numbers survive and the line says so} \
  [list [opa_n_mode op] [xschem raw loaded] [op_annot::_annotated] \
        [opa_n_row [op_annot::text MZZ1] gm] [xschem get statusmsg]] \
  {{} 0 1 100u {OP annotation ON (device OP info) -- raw already loaded}}

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
  [list -1 {} -1 {0 1} "OP annotation ON (device OP info) -- NO RAW FILE: [file join $N_ND_EMPTY n_dev.raw]"]

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
  [list -1 {} 0 1 100u "OP annotation ON (device OP info) -- loaded [file join $N_ND_GOOD n_dev.raw]"]

# ⚠ SUCCESS IS RE-ASKED, NEVER TAKEN FROM annotate_op. Measured: on a garbage
# file it returns rc=0 with the PATH as its result and `raw loaded` -1. A key
# that reported "loaded" from that rc would be the prototype's one sin —
# claiming a success it cannot prove.
xschem load [file join $lib n_dev.sch] ; xschem raw_clear
set n9_pre [xschem raw loaded]
set ::netlist_dir $N_ND_BAD
check {N9 a candidate that will not parse is reported as a FAILURE, not as a load} \
  [list $n9_pre [opa_n_mode op] [xschem raw loaded] [xschem get statusmsg]] \
  [list -1 {} -1 "OP annotation ON (device OP info) -- COULD NOT LOAD [file join $N_ND_BAD n_dev.raw]"]

# ⚠ THE FOURTH INDISTINGUISHABLE CAUSE (issue 0451). A raw IS loaded and every
# row still renders blank, because live_cursor2_backannotate is off. Naming
# `raw already loaded` here would be a lie about a blank block; the row also
# asserts the loaded raw was not thrown away on the way to saying so.
xschem load [file join $lib n_dev.sch]
xschem annotate_op $N_RAW
set ::netlist_dir $N_ND_EMPTY
set ::live_cursor2_backannotate 0
check {N10 a raw loaded with backannotation OFF is named as such, and is NOT cleared} \
  [list [opa_n_mode op] [xschem raw loaded] [xschem get statusmsg]] \
  {{} 0 {OP annotation ON (device OP info) -- a raw is loaded but backannotation is off (live_cursor2_backannotate 0)}}
set ::live_cursor2_backannotate $n_live_saved

# ⚠ AND *WHICH* TERM FAILED IS ASKED, NOT ASSUMED (issue 0459). N10 sets the
# flag to 0 itself, so it can only ever confirm the wording it was written
# from. The route a user actually takes — `Waves > Op`, i.e. `xschem raw_read`
# — leaves `raw loaded` 0 and `raw annot` -1 with live_cursor2_backannotate
# still 1: the block is blank for the OTHER reason. Naming the flag there
# accused an innocent variable and never named the real cause, which is
# save.c ruling D5-1's plausible-wrong-NUMBER defect wearing a reason's
# clothes. The branch is also a dead end (the guard blocks the auto-load), so
# the row pins that the way out is named.
xschem load [file join $lib n_dev.sch] ; xschem raw_clear
catch {xschem raw_read $N_RAW}
check {N10b a raw that published no OP point names THAT, not the backannotate flag} \
  [list $::live_cursor2_backannotate [xschem raw loaded] [op_annot::_annotated] \
        [opa_n_mode op] [xschem get statusmsg]] \
  [list 1 0 0 {} "OP annotation ON (device OP info) -- a raw is loaded but it\
     published no operating point: use Waves > Op Annotate, or `xschem raw_clear`\
     then press again"]
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

# ⚠ THE SHIPPED SPELLING, NOT A NEW ONE. select_raw (xschem.tcl:14471) is what
# both Annotate-OP menu items already resolve through; a second spelling here
# would be an I1-shaped drift in the path rather than in the vector name.
check {N12 with no ASE session it falls back to select_raw's `$netlist_dir/<cell>.raw`} \
  [rcall {cadence::_annot_raw_candidate}] \
  [list 0 [list [file join $N_ND_GOOD n_dev.raw] {} netlist_dir]]

# ⚠ select_raw ITSELF MUTATES THE USER'S GLOBAL — `regsub {/$} $netlist_dir {}
# netlist_dir` under `global`. A key pressed forty times must not rewrite a
# preference it only READ, so the trailing slash is stripped from a LOCAL copy.
set ::netlist_dir "$N_ND_GOOD/"
set n13 [rcall {cadence::_annot_raw_candidate}]
check {N13 a trailing slash is handled in a LOCAL copy: single-slash path, ::netlist_dir untouched} \
  [list $n13 $::netlist_dir] \
  [list [list 0 [list [file join $N_ND_GOOD n_dev.raw] {} netlist_dir]] "$N_ND_GOOD/"]
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
check {N14 the scan answers {n-annotatable types-with-no-devpath}, current level only} \
  [list $n14a $n14b] {{0 {1 {}}} {0 {0 zzs8probe}}}

# ⚠ THE OTHER SILENT FIRST RUN. A user whose PDK symbol type nobody registered
# gets a blank block and no reason (issue 0451, four indistinguishable causes).
# Both confusions are reported in ONE line (decision D5): fixing the raw only to
# meet the descriptor problem on the next press is the shape D5 rejects.
check {N15 with nothing annotatable on the sheet the missing descriptor is NAMED, alongside the raw} \
  [list [opa_n_mode op] [xschem get statusmsg]] \
  [list {} "OP annotation ON (device OP info) -- NO RAW FILE: [file join $N_ND_EMPTY n_probe.raw] -- no OP descriptor for symbol type(s): zzs8probe"]

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
# ⚠ ONE CLICK, PERMANENTLY STALE. `Live annotate probes with 'b' cursor`
# (src/xschem.tcl:15360, Simulation > Graphs) is a shipped checkbutton on
# `live_cursor2_backannotate` with NO -command, so it does not even redraw, and
# op_annot::_annotated (op_annot.tcl:561) reads it as its FIRST gate. Nothing in
# a 13-field xctx epoch can see a Tcl variable. Off must BLANK every row — I3's
# forbidden previous-run's-number arriving from a different button — and back on
# must restore them. That the checkbutton has no -command is filed separately;
# this row is about the CACHE, and it drives the variable directly so it holds
# whether or not the -command ever lands.
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
check {O29 `live_cursor2_backannotate` 1 -> 0 -> 1 blanks every row and restores it, with no other change} \
  [list [opa_o_rowtexts $o29a ZZO] [opa_o_rowtexts $o29b ZZO] \
        [opa_o_rowtexts $o29c ZZO] $o29t] \
  [list $O_RL_A {{ZZOA =} {ZZOB =} {ZZOC =}} $O_RL_A {{ZZOA =} {ZZOB =} {ZZOC =}}]

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
# `@spice_get_voltage` (token.c:4315 for the `@#n:` form, token.c:4821 for the
# bare one) reads `xctx->raw->cursor_b_val[]` DIRECTLY under
# `live_cursor2_backannotate && sch_waves_loaded() >= 0 && annot_p >= 0`. So the
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
set T_ROWS_P1 {{id  = 10u} {gm  = 100u} {gds =} {vth = 0.7}}
set T_ROWS_P3 {{id  = 30u} {gm  = 300u} {gds =} {vth = 0.7}}

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
## The voltage lab_pin `d` is printing, i.e. the text node immediately after the
## label — lab_pin.sym carries `T {@lab}` then `T {@spice_get_voltage}`
## (lab_pin.sym:32) and the export preserves that order. This is the
## `@spice_get_voltage` half of the blast radius, and it is a CACHED floater
## string, not a live translate: the marker matters because the value alone
## (`0`, `3`) is far too generic to search for.
proc opa_t_vd {svg} {
  set t [opa_q_texts $svg]
  set i [lsearch -exact $t d]
  if {$i < 0} { return "NO-LABEL" }
  return [lindex $t [expr {$i + 1}]]
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
#   * annotate_op published point 0 (`0 0 -1`: annot_p 0, annot_x never written,
#     sweep_idx never resolved);
#   * and the block really does read that point.
set t0_rc [opa_t_arm [file join $lib s5_flat.sch]]
check {T0 CONTROL: a tran raw annotated on a sheet with NO graph object and cursor B never enabled, resting on point 0} \
  [list $t0_rc [xschem get rects 2] [xschem get graph_flags] [opa_t_annot] \
        [op_annot::type M1] [rcall {op_annot::text M1}]] \
  [list 0 0 0 {0 0 -1} nmos [list 0 $T_TXT_P0]]

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
# are one sequence in one process: point 0 (which fills the cache), then 3 ns,
# then back to 1 ns.
opa_t_arm [file join $lib s5_flat.sch]
opa_l_annot 1
set t10a [opa_t_rows [opa_l_print2 svg [file join $scratch t_ovl0.svg] $T_VP]]
xschem set cursor2_x 3e-9
set t10b [opa_t_rows [opa_l_print2 svg [file join $scratch t_ovl3.svg] $T_VP]]
xschem set cursor2_x 1e-9
set t10c [opa_t_rows [opa_l_print2 svg [file join $scratch t_ovl1.svg] $T_VP]]
opa_l_annot 0
check {T10 the RENDERED overlay block follows the graphless cursor -- point 0, then 3 ns, then back to 1 ns} \
  [list $t10a $t10b $t10c] [list $T_ROWS_P0 $T_ROWS_P3 $T_ROWS_P1]

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
check {T14 REGRESSION 0477 a plain rect at GRIDLAYER index 0 still blocks a real graph at index 1 -- the direct path does NOT rescue it} \
  [list [xschem get rects 2] [xschem getprop rect 2 0 flags] \
        [xschem getprop rect 2 1 flags] [opa_t_annot] [opa_t_v {v(d)}]] \
  [list 2 {} graph {0 0 -1} 0]

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
check {T15 REGRESSION 0478 a fullyzoom'd graph with cursor B never enabled still annotates nothing} \
  [list [xschem get graph_flags] [opa_t_annot] [opa_t_v {v(d)}]] {0 {0 0 -1} 0}

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
# ⚠ THE FIRST ELEMENT IS THE NON-VACUITY GUARD. `0` proves the floater renders
# at all at point 0 — without it a fixture where the text never appeared would
# satisfy "the two exports differ" by accident.
opa_t_arm [file join $lib s5_flat.sch]
set t22a [opa_t_vd [opa_l_print2 svg [file join $scratch t_flt0.svg] $T_VP]]
xschem set cursor2_x 3e-9
set t22b [opa_t_vd [opa_l_print2 svg [file join $scratch t_flt3.svg] $T_VP]]
check {T22 the lab_pin @spice_get_voltage floater follows a GRAPHLESS cursor -- the wider blast radius, and set_modify(-2)} \
  [list $t22a $t22b] {0 3}

catch {xschem raw clear}
catch {xschem cursor 2 0}
opa_l_annot 0
set XSCHEM_LIBRARY_PATH $S_LIBS

} terr]} {
  puts "UNEXPECTED ERROR (section T): $terr"
  incr fail
}

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
