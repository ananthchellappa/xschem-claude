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
set P_SKY_PARAMS {{id id 0} {gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2}
                  {cgg cgg 1} {cgso cgso 1} {cgdo cgdo 1}}
set P_SKY_PNAMES {id gm gds vth vdsat cgg cgso cgdo}
# The prototype's exact seven, for the byte-for-byte card diff only.
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
set P_PINEXPR {{vgs {expr(@#1:spice_get_voltage - @#2:spice_get_voltage)}}
               {vds {expr(@#0:spice_get_voltage - @#2:spice_get_voltage)}}}
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
check {P9 sky130 param order, with `id` the prototype never saves (0427)} \
  [rcall {opa_param_names nmos}] [list 0 $P_SKY_PNAMES]

# ⚠ D6, and a MEASURED TRAP FOR S5: with no raw loaded the pin expression
# translates to the literal " - ", which is not a number. S5's formatter must
# test `string is double -strict` and render BLANK (I3) — never that string, and
# never 0.
check {P10 sky130 pinexpr round-trips verbatim and is non-numeric with no raw} \
  [rcall {set e [lindex [lindex [dict get [op_annot::descriptor nmos] pinexpr] 0] 1]
          list [opa_norm [dict get [op_annot::descriptor nmos] pinexpr]] \
               [xschem translate M2 $e] \
               [string is double -strict [xschem translate M2 $e]]}] \
  [list 0 [list [opa_norm $P_PINEXPR] { - } 0]]

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

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
