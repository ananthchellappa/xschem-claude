# op_annot.tcl — the ONE raw-vector name builder for operating-point annotation.
#
# doc/claude/specs/op_annotation.md  (§3 R3, §4.2, §5 I1/I3, §6)
# doc/claude/issues/0422-op-annot-spec-devpath-templates-do-not-survive-translate.md
#
# ============================================================================
# WHY THIS FILE EXISTS
# ============================================================================
# To read `gm` off a schematic you need the exact string ngspice wrote into the
# raw file for that device, e.g.
#
#     @m.x1.xm1.msky130_fd_pr__nfet_01v8[gm]
#
# Three builders of that string already exist in this tree:
#
#   1. C, generic — get_fqdevice() (token.c:4514). Takes the element letter from
#      instname[0], so it answers `x` for every sky130/gf180/IHP device (they all
#      netlist as subcircuit-wrapped `X…`). Unusable for a PDK device.
#   2. C, duplicated — the bare @spice_get_current_/modelparam_/modelvoltage_
#      branch (token.c:5163-5290) is a near-verbatim second copy of (1)'s body.
#   3. Symbol text, per PDK, by hand — sky130's nfet_01v8.sym spells the name out
#      as an escaped `translate` template; IHP's sg13g2_procs.tcl builds it with
#      Tcl string concatenation. These two already disagree about where
#      `spiceprefix` comes from.
#
# This file is the fourth, and it exists to REPLACE (3). Invariant I1: the
# save-card emitter and the on-screen display must call the SAME builder. When
# two builders drift the failure is silent — you save vectors nobody displays and
# display `-` for vectors you saved, with no error anywhere. So every consumer
# (S3's save cards, S5's formatter, S9's overlay) calls op_annot::vector; none of
# them may re-derive the shape.
#
# ============================================================================
# THE API
# ============================================================================
#   op_annot::register <symbol-type> <dict>    store/override a PDK descriptor
#   op_annot::descriptor <symbol-type>         -> the dict, or {} if unregistered
#   op_annot::type <instname>                  -> the symbol K-record `type=` token
#   op_annot::devpath <instname>               -> "@m.x1.xm1.msky130_fd_pr__nfet_01v8"
#   op_annot::vector <instname> <param> ?kind? -> "i(…[id])" / "…[gm]" / "v(…[vth])"
#
# ============================================================================
# ⚠ A SAVE CARD IS BARE. `vector` IS THE READ SHAPE ONLY.  (spec §3 rule R4)
# ============================================================================
# Read this before adding op_annot::save_cards (S3) to this file. Measured on
# ngspice-42, one card per throwaway deck so no card could mask another:
#
#     .save @m.xm1.m1[id]      -> raw contains  i(@m.xm1.m1[id])
#     .save i(@m.xm1.m1[id])   -> raw contains  NOTHING. no vector, no message.
#     .save @m.xm1.m1[vdsat]   -> raw contains  v(@m.xm1.m1[vdsat])
#     .save @m.xm1.m1[gm]      -> raw contains  @m.xm1.m1[gm]
#
# ngspice applies the i()/v() wrapper ITSELF, from the parameter's own type. The
# bare card is the only form that works for all three kinds. So:
#
#     save card  =  [op_annot::devpath $inst][param]     <- always bare
#     read name  =  [op_annot::vector  $inst $param]     <- kind wrapper applied
#
# I1 is unaffected in substance — `devpath` is the one builder both sides share —
# but an emitter that writes `vector`'s output into a .save line produces a deck
# whose device parameters silently never appear in the raw.
#
# Second measured trap for that emitter: a card naming a device that is NOT in
# the netlist still writes a full column under exactly the requested name,
# holding 0.0, with only `Warning: unrecognized variable` on stderr. A wrong
# descriptor therefore surfaces as zeros, not as blanks, which I3 cannot catch.
#
# The descriptor dict keys (spec §4.2). S1 stores all of them; it only READS
# `devpath`, `devproc` and `params`. `derived` and `pinexpr` are carried verbatim
# for S5's formatter — storing them here is what keeps a later key addition from
# being an edit to this file.
#
#   devpath  template for the device path INCLUDING the element-letter prefix,
#            expanded with `xschem translate <inst> …`
#   devproc  alternative to devpath: a Tcl proc, called as
#              <proc> <instname> <model> <path> <spiceprefix>
#            returning the finished device path. The escape hatch for PDKs that
#            mangle the model name (IHP strips a `_5t` suffix —
#            sg13g2_procs.tcl:321-324 is the entire justification for this key).
#            devproc WINS when a descriptor carries both.
#   params   ordered {label param kind} triples. `label` is what the display
#            prints, `param` is the raw-file parameter name, `kind` is the
#            wrapper (below). The lookup in `vector` matches `param`, not `label`.
#   derived  ordered {label expr} — computed from params after they are read (S5)
#   pinexpr  ordered {label expr-over-pin-voltages} — needs no save card (S5)
#   match    OPTIONAL list of globs tested against the instance's CELL NAME
#            (`getprop instance <n> cell::name`, e.g. `sky130_fd_pr/nfet_01v8.sym`).
#            Absent or empty = permissive, i.e. exactly the behaviour before this
#            key existed. See the 0425 block below.
#
# ============================================================================
# ⚠ `match` — ISSUE 0425, RATIFIED BY S2. AND ITS CONSUMER CONTRACT
# ============================================================================
# The lookup key is the symbol K-record `type=` token, and it is NOT UNIQUE:
# sky130, gf180, IHP *and* xschem_library/devices/{nmos,nmos3,nmos4,…}.sym all
# spell `type=nmos`. Two consequences, both measured before this key existed:
#
#   (1) register sky130's nmos, then ask for a generic devices/nmos instance:
#         devpath M2 -> @m.m2.msky130_fd_pr__cmosn      <- a sky130 name on a
#                                                          non-sky130 device
#   (2) register sky130's nmos then IHP's in one interpreter (which is exactly
#       what spec §8's cross-PDK test does — `register` REPLACES, see below):
#         devpath M1 -> @n.xm1.nnfet_01v8               <- an IHP name on a
#                                                          sky130 device
#
# Neither is blank, and per spec landmine 9 neither blanks at READ time either:
# ngspice writes a full column of 0.0 under exactly the name it was asked for,
# with only `Warning: unrecognized variable` on stderr. So a wrong descriptor is
# indistinguishable from a real zero on the schematic. I3 (blank, never a
# fabricated number) therefore forces the fix, and `match` is it: a device whose
# cell name matches no glob in the list gets NO devpath.
#
# REJECTED: qualified keys (`sky130:nmos`) plus an "active PDK" concept — a new
# user-facing concept and a rewrite of every lookup; and "document it and move
# on", which leaves (1) fabricating numbers on an ordinary mixed schematic.
#
# ⚠ ACCEPTED RESIDUAL: case (2) still LOSES the sky130 registration — the second
# `register nmos` replaces the first. What `match` buys is that the loss degrades
# to BLANK rather than to a confidently wrong name. One interpreter per PDK
# (spec §8) still stands.
#
# ⚠ CONSUMER CONTRACT, and it is a CHANGE: A NON-EMPTY DESCRIPTOR NO LONGER
# IMPLIES A NON-EMPTY DEVPATH. S3's walk and S5's formatter must skip on a blank
# `devpath`, never on a blank `descriptor`.
#
# ============================================================================
# ⚠ THE TEMPLATE MUST BE ESCAPED — MEASURED, AND SPEC §4.2 GETS IT WRONG
# ============================================================================
# `xschem translate` tokenises on SPACE(c) = {\n, space, \t, \0, ;} only
# (token.c:24), so `.` does NOT terminate an @-token, and an @-token that misses
# get_tok_value() appends NOTHING (token.c:5351-5366). The spec's literal
#
#     @m.$path@spiceprefix@name.msky130_fd_pr__@model
#
# therefore expands to `Xnfet_01v8` — no error, no warning, a plausible-looking
# wrong string, i.e. precisely the silent drift I1 exists to prevent. Escape the
# leading `@` and the `.` that must terminate a token, as the SHIPPED sky130
# symbol already does (nfet_01v8.sym:63-64):
#
#     \@m.@path@spiceprefix@name\.msky130_fd_pr__@model
#
# Both `@path` (translate-native, token.c:4719) and `$path` (substituted here
# with `string map`) are accepted; `@path` is canonical because C resolves it for
# free. The Tcl pass is `string map` and NEVER `subst` — a template is user data
# and `subst` would execute any `[...]` inside it. Two documented consequences of
# that choice: `string map` also rewrites a literal `$pathological`, and
# translate runs a trailing expr()/expr_eng()/tcleval() pass (token.c:5424-5432,
# measured: `translate M1 {expr(1+1)}` -> `2`). A devpath template is restricted
# to plain @-token text.
#
# ============================================================================
# THE ERROR DISCIPLINE: DATA CONDITIONS ARE BLANK, CALLER BUGS ARE LOUD
# ============================================================================
# I3 — a missing vector renders BLANK, never 0, never a fabricated number, never
# the previous run's value. S6/S9 call devpath/vector from inside a draw /
# tcleval path where a raise breaks rendering outright. So every DATA condition
# (no descriptor, unknown instance, unknown symbol, translate failure, a devproc
# that blows up) returns {}.
#
# A CALLER BUG is the opposite and must be loud:
#   * `register` with an odd-length dict raises, naming the type — an rc typo is
#     caught at registration instead of yielding blanks at draw time, which is
#     indistinguishable from "this PDK is not supported";
#   * `vector` with the kind omitted for a param that is not in `params` raises,
#     naming the param. Defaulting it to kind 1 would emit a silently unwrapped
#     current, which is the I1 failure mode wearing a different hat.
#
# ============================================================================
# SOURCE-TIME RULE
# ============================================================================
# Definitions ONLY (the ase_window.tcl / cmdmode.tcl precedent): no `xschem`
# command, no file I/O, no Tk. A Tcl error while this file is being sourced is a
# QUIET catastrophe — under --pipe/--nogui source_tcl_file (xinit.c:1508-1539)
# only prints to stderr and returns TCL_ERROR, and Tcl_EvalFile has ALREADY
# abandoned the rest of xschem.tcl, so load_input_bindings, the action-log
# registry, ciw.tcl and build_widgets silently never run.
#
# ⚠ MEASURED, and worse than that: it does not stay quiet, it SEGFAULTS.
# Tcl_AppInit() continues into alloc_xschem_data(), whose first act is
# strcmp(tclgetvar("undo_type"), "disk") on a variable xschem.tcl never got to
# set -- exit 139, core dumped, no test row runs at all. Issue 0423. So row A3
# of tests/headless/test_op_annot.tcl (the stdin_repl_setup canary) CANNOT fire
# for a source-time error in this file; the detector is the nonzero exit code.
# A3 still covers the genuinely quiet variant -- a helper that raises after
# alloc_xschem_data()'s dependencies are already set.

namespace eval op_annot {
  # symbol type -> descriptor dict. Populated only by op_annot::register, never
  # at source time here. Registration comes from a PDK procs file, or from a
  # user file sourced AFTER startup (I5). ⚠ NOT from ~/.xschem/xschemrc:
  # measured, xschemrc is sourced at xinit.c:3234-3292 and xschem.tcl only at
  # :3401, so op_annot::register there dies with `invalid command name`. A
  # --script rc such as the PDK workareas' cadence_style_rc works.
  variable desc
  if {![array exists desc]} { array set desc {} }
}

## op_annot::register <symbol-type> <dict>
##
## <symbol-type> is the symbol K-record `type=` token (`nmos`, `pmos`,
## `vertical_npn`, `res`, …) — NOT the cell name. The cell name differs per .sch
## spelling (`sky130_fd_pr/nfet_01v8` vs `…/nfet_01v8.sym`) and `xschem getprop
## symbol` RAISES on the unsuffixed form, so keying on it would push a catch into
## every caller.
##
## ⚠ REPLACE, NOT MERGE. A dict-merge reads better for spec §4.2's "the user
## edits one line in their own rc" story, but it lets sky130's pinexpr/derived
## leak into a later-registered IHP `nmos` in the same interpreter — which is
## exactly what spec §8's cross-PDK test does. A user tweaking one key round-trips
## through `op_annot::descriptor`:
##     set d [op_annot::descriptor nmos]
##     dict set d params {{id id 0} {gm gm 1}}
##     op_annot::register nmos $d
proc op_annot::register {type descriptor} {
  variable desc
  if {[string trim $type] eq {}} {
    return -code error "op_annot::register: empty symbol type"
  }
  ## The one loud failure in storage: an odd-length dict is an rc typo.
  if {[catch {dict size $descriptor} err]} {
    return -code error \
      "op_annot::register: descriptor for symbol type \"$type\" is not a\
 well-formed dict ($err)"
  }
  set desc($type) $descriptor
  return $type
}

## op_annot::descriptor <symbol-type> -> the stored dict, or {} when unregistered.
## Blank, never a raise: "this type is not annotated" is a data condition and
## every consumer tests it with a plain string compare.
proc op_annot::descriptor {type} {
  variable desc
  if {[info exists desc($type)]} { return $desc($type) }
  return {}
}

## op_annot::type <instname> -> the instance's symbol K-record `type=` token, or
## {} if the instance or the token is missing.
##
## Public although devpath is its only caller inside this file: S3's hierarchy
## walk and S5's formatter live in other files and would otherwise each re-copy
## the lookup plus its catch. One copy, per I1's spirit.
##
## `getprop instance <n> cell::<attr>` reads the SYMBOL's prop_ptr
## (scheduler.c:5549-5551), so this is one call and cannot hit the `Symbol not
## found` raise that `getprop symbol <cell> type` throws for an unsuffixed cell
## name. It RAISES for an unknown instance (scheduler.c:5539), hence the catch.
proc op_annot::type {instname} {
  if {[catch {xschem getprop instance $instname cell::type} t]} { return {} }
  return $t
}

## The hierarchy prefix, read LIVE on every call — never cached and never
## memoised. `xschem get sim_sch_path` is the .sch path minus the leading `.`
## with the raw-load levels stripped (scheduler.c:5150): `` at the top of the
## loaded cell, `x1.` one level down. The trailing dot is included, which is what
## makes `@m.` + path + prefix + name + `.` + inner-device concatenate correctly.
##
## Caching it would pass every golden and silently produce the wrong device path
## the moment the user descends — the same context-drift class as landmine 4.
proc op_annot::_simpath {} {
  if {[catch {xschem get sim_sch_path} p]} { return {} }
  return $p
}

## Lowercase, on EVERY path out of devpath — template and devproc alike.
## Mirrors get_fqdevice's `strtolower(fqdev)` (token.c:4572). Measured necessity:
## `xschem translate` preserves the schematic's case and answers
## `@m.x1.XM1.msky130_fd_pr__nfet_01v8`. get_raw_index() (save.c:2251-2285) would
## retry case variants at READ time, but the save cards S3 writes would still be
## mixed-case, so the lowercasing has to happen at BUILD time. Trusting a
## devproc's own casing is exactly the per-PDK duplication I1 forbids.
proc op_annot::_lower {s} {
  return [string tolower $s]
}

## Does <instname>'s CELL belong to the PDK that registered <d>?  (issue 0425)
##
## 1 when the descriptor carries no `match` key, or an empty one — permissive,
## which is what keeps every descriptor written before this key existed, and a
## user's own `op_annot::register` in their rc (I5), working unchanged.
## Otherwise `string match -nocase` each glob against
## `getprop instance <n> cell::name` (`sky130_fd_pr/nfet_01v8.sym`, `nmos.sym`),
## 1 on the first hit and 0 if none.
##
## ⚠ NEVER RAISES. This runs inside devpath, which S6/S9 call from a draw /
## tcleval path — a raise there breaks rendering outright (I3). An unreadable
## instance and a malformed glob list are both DATA conditions: 0, i.e. this
## descriptor does not claim the device, i.e. blank.
proc op_annot::_matches {instname d} {
  if {![dict exists $d match]} { return 1 }
  if {[catch {dict get $d match} globs]} { return 1 }
  if {[string trim $globs] eq {}} { return 1 }
  if {[catch {xschem getprop instance $instname cell::name} cell]} { return 0 }
  set hit 0
  if {[catch {
    foreach g $globs {
      if {[string match -nocase $g $cell]} { set hit 1 ; break }
    }
  }]} { return 0 }
  return $hit
}

## The R3 / get_fqdevice kind wrapper. THE AUTHORITY IS token.c:4524-4525:
##   iprefix  = modelparam == 0 ? "i(" : modelparam == 1 ? "" : "v("
##   ipostfix = modelparam == 1 ? ""   : ")"
## i.e. 0 -> i(<dev>[p]), 1 -> <dev>[p], 2 -> v(<dev>[p]), and anything that is
## neither 0 nor 1 falls into the v( branch. That last clause is deliberately
## copied rather than "fixed" into a raise: diverging from the C is how the two
## builders start to drift.
proc op_annot::_wrap {dev param kind} {
  switch -- $kind {
    0       { return "i(${dev}\[${param}\])" }
    1       { return "${dev}\[${param}\]" }
    default { return "v(${dev}\[${param}\])" }
  }
}

## The kind for <param>, taken from the descriptor's `params` triples.
## ⚠ Matches the PARAM field (index 1), NOT the label (index 0): S5's formatter
## needs `{Ids ids 0}`, a display label that differs from the raw name.
## Raises when the param is absent — see the error discipline in the header.
proc op_annot::_kind {instname param} {
  set t [::op_annot::type $instname]
  set d [::op_annot::descriptor $t]
  if {[dict exists $d params]} {
    foreach row [dict get $d params] {
      if {[lindex $row 1] eq $param} { return [lindex $row 2] }
    }
  }
  return -code error \
    "op_annot::vector: parameter \"$param\" is not in the params list of the\
 descriptor for symbol type \"$t\" (pass an explicit kind, or add it to params)"
}

## op_annot::devpath <instname> -> the lowercased raw-file device path, without
## the `[param]` suffix; {} for every data condition.
##
##   op_annot::devpath M1   ->  @m.x1.xm1.msky130_fd_pr__nfet_01v8
##
## I4: this reads context, it never moves in it. No descend, no set_modify, no
## write to the .sch.
proc op_annot::devpath {instname} {
  set t [::op_annot::type $instname]
  if {$t eq {}} { return {} }
  set d [::op_annot::descriptor $t]
  if {$d eq {}} { return {} }
  ## Issue 0425: the type key is shared by every PDK and by the generic
  ## devices/*.sym. A descriptor only builds a name for a cell it claims.
  if {![::op_annot::_matches $instname $d]} { return {} }

  ## devproc wins over devpath when a descriptor carries both: a PDK that needed
  ## the escape hatch needs it for every device of that type.
  if {[dict exists $d devproc] && [dict get $d devproc] ne {}} {
    set p [dict get $d devproc]
    ## @model / @spiceprefix come from `translate`, NOT from `getprop instance`.
    ## Measured: `getprop instance M1 spiceprefix` is EMPTY on sky130 because the
    ## token lives in the symbol template= string and getprop reads only
    ## inst.prop_ptr (scheduler.c:5554), while `translate M1 @spiceprefix` -> `X`.
    ## The IHP prototype's sg13g2_procs.tcl:374/:453/:512 get this wrong and work
    ## only because IHP's own test schematics spell spiceprefix= on the instance
    ## line; ported verbatim the device path silently loses its `x`.
    if {[catch {xschem translate $instname @model} model]} { return {} }
    if {[catch {xschem translate $instname @spiceprefix} pfx]} { set pfx {} }
    if {[catch {uplevel #0 [list $p $instname $model \
                                 [::op_annot::_simpath] $pfx]} r]} { return {} }
    if {$r eq {}} { return {} }
    return [::op_annot::_lower $r]
  }

  if {![dict exists $d devpath]} { return {} }
  set tmpl [dict get $d devpath]
  if {$tmpl eq {}} { return {} }
  ## `$path` is spec §4.2's spelling and is substituted here; `@path` is
  ## translate-native and costs nothing, so it is the canonical one. NEVER subst.
  if {[string first {$path} $tmpl] >= 0} {
    set tmpl [string map [list {$path} [::op_annot::_simpath]] $tmpl]
  }
  if {[catch {xschem translate $instname $tmpl} r]} { return {} }
  if {$r eq {}} { return {} }
  return [::op_annot::_lower $r]
}

## op_annot::vector <instname> <param> ?kind? -> the full raw-file vector name.
##
##   op_annot::vector M1 gm      ->  @m.x1.xm1.msky130_fd_pr__nfet_01v8[gm]
##   op_annot::vector M1 id      ->  i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])
##   op_annot::vector M1 vdsat   ->  v(@m.x1.xm1.msky130_fd_pr__nfet_01v8[vdsat])
##
## ⚠ THE KIND ARGUMENT IS OPTIONAL AND SHOULD USUALLY BE OMITTED. The kind is
## descriptor DATA; a consumer that retypes `0` at its call site has become a
## second builder of the same decision, and when the descriptor changes only one
## of them moves. The explicit form exists for callers that are not driven by a
## params list at all.
##
## Blank in, blank out: no `i()` is ever wrapped around an empty device name.
proc op_annot::vector {instname param {kind {}}} {
  set dev [::op_annot::devpath $instname]
  if {$dev eq {}} { return {} }
  if {$kind eq {}} { set kind [::op_annot::_kind $instname $param] }
  return [::op_annot::_wrap $dev $param $kind]
}
