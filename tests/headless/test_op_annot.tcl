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

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
