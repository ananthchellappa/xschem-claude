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
# (S3's save cards, S5's formatter, S9's overlay) builds its names HERE; none of
# them may re-derive the shape.
#
# ⚠ WHAT "HERE" MEANS EXACTLY, since S5 landed: a consumer calls op_annot::vector,
# OR — when it is looping over a descriptor's whole `params` list — it calls
# op_annot::devpath ONCE and op_annot::_wrap per row, which are the two shared
# primitives `vector` itself composes, with the kind still taken from the
# descriptor's own triple. Nothing is retyped either way. That is op_annot::text's
# route and it exists for a measured reason: per-row `vector` on IHP's 13-param
# NPN is 26 NESTED `xschem translate` calls while the outer translate's static
# result buffer (token.c:4604) is live, because the overlay calls this from a
# tcleval. tests/headless/test_op_annot.tcl row S12 asserts the two compositions
# are byte-equal for every params row, so they cannot drift in silence.
#
# ============================================================================
# THE API
# ============================================================================
#   op_annot::register <symbol-type> <dict>    store/override a PDK descriptor
#   op_annot::descriptor <symbol-type>         -> the dict, or {} if unregistered
#   op_annot::type <instname>                  -> the symbol K-record `type=` token
#   op_annot::devpath <instname>               -> "@m.x1.xm1.msky130_fd_pr__nfet_01v8"
#   op_annot::vector <instname> <param> ?kind? -> "i(…[id])" / "…[gm]" / "v(…[vth])"
#   op_annot::raw_or_blank <vector>            -> the value at the annotation
#                                                 point, or {}          (S5)
#   op_annot::eng_or_blank <value>             -> to_eng of it, or {}   (S5)
#   op_annot::text <instname>                  -> the `label = value` block for
#                                                 one device, or {}     (S5)
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

# ============================================================================
# S5 — THE DISPLAY FORMATTER
# ============================================================================
#   op_annot::raw_or_blank <vector-name>  -> the number, or {}
#   op_annot::eng_or_blank <value>        -> to_eng of it, or {}
#   op_annot::text <instname>             -> the `label = value` block, or {}
#
# PORTED FROM ihp-sg13g2/sg13g2_procs.tcl, the single-PDK prototype:
#   * sg13g2_raw_or_double (:436-440) -> op_annot::raw_or_blank, verbatim apart
#     from the name. Each of its three lines is load-bearing; see below.
#   * sg13g2_to_eng_safe   (:443-446) -> op_annot::eng_or_blank, with THE ONE
#     LINE THIS STEP EXISTS TO CHANGE: `return "NaN"` becomes `return {}` (I3).
#   * sg13g2_display_fet_params (:449-505) contributes its SHAPE — read every
#     vector, then compute, then format, `label = value` per line — with its
#     three hand-written parameter lists lifted into the descriptor: its ten
#     hand-written reads (:461-470) become one loop over `params`, its cgg sum
#     (:473-477) and its ft / gm-id blocks (:488-502) become one loop over
#     `derived`.
# DELIBERATELY NOT PORTED:
#   * its own device-path construction (:451-459). That is builder #3, exactly
#     what I1 forbids, and it is already measurably wrong: :453 reads the prefix
#     with `getprop instance … spiceprefix`, which is EMPTY when the token lives
#     only in the symbol template=, so on three shipped sky130 cells it builds
#     `@m.m1.…` against a raw holding `@m.xm1.…` (issue 0430) and every line of
#     sky130_display_fet_params comes out blank with a CORRECT raw loaded.
#   * its hand-spelled i()/v() wrappers (:461-470) — `_wrap` applies the kind
#     from the descriptor, so no call site retypes that decision.
#   * its `[pn]mos` regexp type dispatch (:457) — descriptor lookup replaces it.
#   * `return "NaN"` (:445). A `NaN` painted on a schematic is a fabricated
#     value in the same class as a stale 0. I3, and the one behaviour the step
#     brief names as not-to-carry.
#
# ============================================================================
# ⚠ THREE DISTINCT WAYS A NUMBER CAN BE FABRICATED HERE. NO ONE GUARD CLOSES
#   TWO OF THEM.  (I3, and it is the whole point of this section)
# ============================================================================
#  (a) `xschem raw value <v> -1` RAISES "No raw file loaded" (scheduler.c:10461)
#      when nothing is loaded — it does NOT return empty. An uncaught raise
#      inside the tcleval draw path S6/S9 use breaks rendering outright.
#      -> the catch in raw_or_blank, and it is mandatory, not defensive.
#  (b) A raw READ but never PUBLISHED returns a FABRICATED 0. `xschem raw read
#      <f> op` never calls update_op() (save.c:1988), so cursor_b_val stays
#      my_calloc-zeroed and point -1 reads 0.0 for a vector whose true value is
#      1e-4. `string is double -strict` cannot tell that 0 from a real one.
#      -> the whole-block gate, op_annot::_annotated.
#  (c) `expr {1.0/0.0}` yields `Inf` with NO raise, `string is double -strict
#      Inf` is 1, and `to_eng Inf` is `infT`. Every shipped `derived` row (ft,
#      gm/id, rin) is a division, so a plain catch — which is all a generic
#      loop has, where the prototype had hand-written per-denominator zero
#      tests — is not enough.  -> op_annot::_finite.
#
# ⚠ THE ONE THIS STEP CANNOT CLOSE, AND IT IS IN THE GOLDEN: issue 0446. When
# one pin of a `pinexpr` is GND and the other net is absent from the raw,
# translate builds `expr(- - 0.0 )` (token.c:4364 hardcodes 0.0 for GND, and
# emits a literal `-` for an absent net) and its trailing eval_expr pass reads
# the two `-` as unary minus, yielding a strict-double `0`. Nothing at this
# level can tell that 0 from a real one. Both Tcl-side guards were rejected in
# 0446: blanking pinexpr whenever params are blank breaks the legitimate
# no-save-cards case pinexpr exists FOR, and decomposing the expression here is
# a second evaluator, i.e. the I1 drift shape. The fix is in C.

## Is <v> a FINITE double?  (hazard (c))
##
## Two terms, because neither alone is enough:
##   `string is double -strict`  rejects {}, ` - `, `abc` — but PASSES Inf/NaN.
##   `expr {$v*0.0 == 0.0}`      RAISES for both (measured on 8.6.13: "domain
##                               error: argument not in valid range" for ±Inf,
##                               "can't use non-numeric floating-point value"
##                               for NaN) and is 1 for every finite double,
##                               0.0 included.
## Spelled as a raise-and-catch rather than `$v > -Inf && $v < Inf` on purpose:
## the literal `Inf` is not parsed by every Tcl this file must survive, and a
## regexp on the string would be a third spelling of "is this a number".
proc op_annot::_finite {v} {
  if {![string is double -strict $v]} { return 0 }
  if {[catch {expr {$v*0.0 == 0.0}} ok]} { return 0 }
  return $ok
}

## op_annot::raw_or_blank <vector-name> -> the value at the annotation point, or
## {}. Port of sg13g2_raw_or_double. THREE OUTCOMES IT MUST TELL APART, all
## measured on this tree:
##   no raw loaded    -> `xschem raw value` RAISES (scheduler.c:10461)   -> {}
##   vector absent    -> an EMPTY STRING at rc=0 (idx<0 leaves the interp
##                       result reset). Not a raise, not a 0.            -> {}
##   vector present   -> the number at cursor-B / the OP point.
## Point -1 is THE accessor (scheduler.c:10326): it falls through to
## xctx->raw->cursor_b_val[idx], i.e. whatever update_op() last published.
proc op_annot::raw_or_blank {v} {
  if {$v eq {}} { return {} }
  if {[catch {xschem raw value $v -1} r]} { return {} }
  if {[string is double -strict $r]} { return $r }
  return {}
}

## op_annot::eng_or_blank <value> -> `46.78u`, or {} for anything that is not a
## finite number. Port of sg13g2_to_eng_safe with its `return "NaN"` replaced by
## a blank (I3).
##
## ⚠ THE NUMERIC GATE IS A SAFETY GATE, NOT DECORATION: to_eng (xschem.tcl:1902)
## does `uplevel #0 expr [join $args]`, so it EVALUATES its argument at global
## scope — `to_eng {[file tail /a/b/c]}` really runs `file tail`. Nothing that
## has not already proved itself a finite double reaches it.
##
## A MEASURED 0.0 STILL PRINTS `0`. I3 forbids fabricating a number for a
## MISSING vector; it does not forbid showing a real zero, and blanking every
## zero would hide a genuinely cut-off device.
proc op_annot::eng_or_blank {v} {
  if {![::op_annot::_finite $v]} { return {} }
  if {[catch {to_eng $v} e]} { return {} }
  return $e
}

## Is there a PUBLISHED annotation point to read?  (hazard (b))
##
## The three terms are COPIED from the C's own read gate (token.c:4318/4339),
## not invented, so op_annot::text shows exactly what the schematic's own
## @spice_get_voltage texts show:
##   live_cursor2_backannotate   the user's own on/off switch. Without this term
##                               the block goes HALF blank when it is off — the
##                               params rows still read while every pinexpr row
##                               returns ` -  ` — which on a schematic reads as
##                               "the save cards are missing", not as
##                               "annotation is off".
##   xschem raw loaded >= 0      sch_waves_loaded(). get_raw_index() is gated on
##                               it (save.c:2259), so below 0 every lookup is -1
##                               anyway; ascending out of the annotated level is
##                               what reaches this (landmine 4).
##   annot_p >= 0                `xschem raw annot` -> {annot_p annot_x
##                               annot_sweep_idx}. -1 means NOTHING was ever
##                               published, i.e. the fabricated-zero state.
##
## ⚠ EVERY TERM IS CATCH-WRAPPED, INCLUDING `xschem raw annot` — measured, it
## RAISES "No raw file loaded" exactly like `raw value`. A gate that can raise
## in a draw path is a second bug, not a guard.
##
## NOT MIRRORED: the C's `&& !raw_is_digital(xctx->raw)`. No Tcl accessor
## exposes it, and it costs nothing here — a digital raw holds no device
## parameter vectors, so every row blanks through raw_or_blank anyway.
proc op_annot::_annotated {} {
  if {[catch {uplevel #0 {set live_cursor2_backannotate}} lv]} { return 0 }
  if {[catch {expr {$lv ? 1 : 0}} b]} { return 0 }
  if {!$b} { return 0 }
  if {[catch {xschem raw loaded} l]} { return 0 }
  if {![string is integer -strict $l] || $l < 0} { return 0 }
  if {[catch {xschem raw annot} a]} { return 0 }
  if {![string is integer -strict [lindex $a 0]] || [lindex $a 0] < 0} { return 0 }
  return 1
}

## Evaluate ONE `derived` expression with <varpairs> bound, or {} if it blows up.
##
## ⚠ A PROC-LOCAL SCOPE, NEVER `uplevel #0`. That is to_eng's defect shape
## (xschem.tcl:1908) and it would let an unrelated global of the same name
## silently satisfy a row the raw never supplied — a fabricated number wearing a
## descriptor's label. Measured both ways: with ::gm set to 999 and the gm row
## unreadable, a local scope blanks and `uplevel #0` prints 999.
##
## ⚠ A MISSING INPUT IS LEFT UNSET, NOT BOUND TO {}. An unset variable makes
## `expr` raise inside this catch ("can't read \"gm\": no such variable"), which
## is how a generic loop reproduces the prototype's per-denominator guards
## without knowing which variable is a denominator. Binding {} raises too;
## binding 0 would NOT, and 0 is the fabricated number I3 forbids.
##
## The locals are `__opa_`-prefixed because a descriptor's own labels are set as
## variables in this scope; only a label spelled `__opa_expr` / `__opa_vars`
## could collide, and that is not a name a display label takes.
proc op_annot::_evalrow {__opa_expr __opa_vars} {
  foreach {__opa_n __opa_v} $__opa_vars { set $__opa_n $__opa_v }
  if {[catch {expr $__opa_expr} __opa_r]} { return {} }
  return $__opa_r
}

## op_annot::text <instname> -> the annotation block for one device:
##
##     id    = 10u
##     gm    = 100u
##     vgs   = 0.9
##     ft    = 15.92G
##     gm/id = 10
##
## or {} when this device is not annotated at all.
##
## ⚠ THE TWO EMPTY OUTCOMES ARE DIFFERENT AND BOTH ARE LOAD-BEARING (D2):
##   a row with NOTHING after the `=`  = "this parameter exists and could not be
##                                       read" — the no-raw case, and the step's
##                                       own acceptance shape.
##   {} , i.e. no block at all         = "this device is not annotated": unknown
##                                       instance, unknown symbol type, no
##                                       descriptor, a `match` miss, or a
##                                       descriptor with no rows to show.
## Collapsing them either way is user-visible: blanks painted on an unrelated
## symbol, or a silently missing parameter list on a real device.
##
## ⚠ SKIP ON A BLANK DEVPATH, NEVER ON A BLANK DESCRIPTOR — this file's own
## consumer contract (the 0425 block above).
##
## ⚠ ROW ORDER IS params, THEN pinexpr, THEN derived, and that order is a
## contract, not an accident: a `derived` expression sees every params LABEL and
## every pinexpr LABEL as a Tcl variable, bound only when the value is a finite
## double (D10; spec §4.2 says LABEL, and op_annot::_kind matches the PARAM, so
## the two are genuinely different fields).
##
## ⚠ I1, AND WHY THIS CALLS devpath ONCE + _wrap PER ROW RATHER THAN vector PER
## ROW (D5): both of vector's shared primitives are the ones called and the kind
## still comes from the descriptor's own triple, so no decision is retyped here.
## Measured: devpath 18.7 us, vector 21.8 us, raw value 0.5 us — per-row
## `vector` on IHP's 13-param NPN is 26 NESTED `xschem translate` calls while
## the outer translate's `static char *result` (token.c:4604) is live, since
## S6/S9 call this from inside a tcleval. tests/headless/test_op_annot.tcl row
## S12 asserts [_wrap [devpath …] $p $kind] eq [vector … $p] for every params
## row, so the two compositions cannot drift silently.
##
## DOES NOT RAISE FOR ANY DATA CONDITION — S6/S9 call it from a draw/tcleval
## path. I4: it reads context and never moves in it.
##
## ⚠ ONE MEASURED EXCEPTION, ISSUE 0447, AND IT IS NOT YET CLOSED. An earlier
## revision of this comment claimed "NEVER RAISES, on any path". That is FALSE
## and was measured false before this file was committed. op_annot::register
## validates only `dict size`, so a descriptor whose `params`, `pinexpr` or
## `derived` value is not a well-formed Tcl LIST is accepted at rc=0 and stored;
## the three `foreach row [dict get $d …]` below then raise `unmatched open
## brace in list` at DRAW time. Reachable via I5 — a user's own register in
## their rc — from a single unbalanced brace. Measured, all three keys:
##     register rc=0  |  text rc=1 'unmatched open brace in list'
## op_annot::_matches already treats exactly this class as a DATA condition for
## the `match` glob list and returns {}; that discipline was not carried here.
## Fix at register (loud, preferred) or with a read-side catch (quiet) — see
## doc/claude/issues/0447. S6 must not land the carrier symbol until it is
## closed or explicitly accepted.
proc op_annot::text {instname} {
  set t [::op_annot::type $instname]
  if {$t eq {}} { return {} }
  set d [::op_annot::descriptor $t]
  if {$d eq {}} { return {} }
  set dev [::op_annot::devpath $instname]
  if {$dev eq {}} { return {} }

  ## Hazard (b): with nothing published, read NOTHING. The rows are still
  ## emitted — blank — because the user is entitled to see which parameters
  ## this device would show.
  set gate [::op_annot::_annotated]
  set rows {}
  set vars {}

  if {[dict exists $d params]} {
    foreach row [dict get $d params] {
      set lbl [lindex $row 0]
      set val {}
      if {$gate} {
        set val [::op_annot::raw_or_blank \
                   [::op_annot::_wrap $dev [lindex $row 1] [lindex $row 2]]]
      }
      if {![::op_annot::_finite $val]} {
        set val {}
      } else {
        lappend vars $lbl $val
      }
      lappend rows [list $lbl $val]
    }
  }

  ## pinexpr needs no save card: it is pin voltages, which `save all` already
  ## carries. `xschem translate` RAISES for an unknown instance, and returns a
  ## non-numeric string (` -  `) whenever a net is missing from the raw.
  if {[dict exists $d pinexpr]} {
    foreach row [dict get $d pinexpr] {
      set lbl [lindex $row 0]
      set val {}
      if {$gate} {
        if {[catch {xschem translate $instname [lindex $row 1]} r]} { set r {} }
        set val $r
      }
      if {![::op_annot::_finite $val]} {
        set val {}
      } else {
        lappend vars $lbl $val
      }
      lappend rows [list $lbl $val]
    }
  }

  if {[dict exists $d derived]} {
    foreach row [dict get $d derived] {
      set lbl [lindex $row 0]
      set val {}
      if {$gate} { set val [::op_annot::_evalrow [lindex $row 1] $vars] }
      ## Hazard (c): the RESULT is tested, not just the operands — a division by
      ## a genuine 0.0 yields Inf with no raise at all.
      if {![::op_annot::_finite $val]} { set val {} }
      lappend rows [list $lbl $val]
    }
  }

  ## A descriptor with a devpath but nothing to show draws no empty frame.
  if {![llength $rows]} { return {} }

  ## The label column pads to the longest label IN THIS BLOCK — the prototypes
  ## hardcode `ids   = ` / `gm    = `, which cannot fit the 5-char `gm/id` or
  ## IHP's 7-char `cgg_tot`. A blank row is `label =` with NOTHING after the
  ## `=`, not even a space; every row ends in exactly one newline.
  set w 0
  foreach r $rows {
    set n [string length [lindex $r 0]]
    if {$n > $w} { set w $n }
  }
  set txt {}
  foreach r $rows {
    set e {}
    if {[lindex $r 1] ne {}} { set e [::op_annot::eng_or_blank [lindex $r 1]] }
    if {$e eq {}} {
      append txt [format "%-*s =" $w [lindex $r 0]] \n
    } else {
      append txt [format "%-*s = %s" $w [lindex $r 0] $e] \n
    }
  }
  return $txt
}

# ============================================================================
# op_annot::place_annotator — S6, the menu item's one moving part
# ============================================================================
# doc/claude/specs/op_annotation.md §4.4 (Carrier 1). Arms an interactive
# placement of the PDK-neutral carrier symbol devices/annotate_params, with its
# `ref` pre-filled from the selection when there is one. Ported from
# ihp-sg13g2/sg13g2_procs.tcl:637-645 ("Add FET param annotator"), de-PDK'd.
#
# ⚠ WHY A PROC AND NOT AN INLINE -command BODY (decision D3). Every neighbouring
# item in the Graphs cascade inlines its body, which matches local style but is
# unreachable from any headless test — the cascade is built under
# `if {[info exists has_x]}`, which --nogui never enters. Everything that can go
# wrong lives here, where tests/headless/test_op_annot.tcl rows K12-K14 drive it
# for real; what stays in src/xschem.tcl is one line carrying a label and a call.
#
# ⚠ THE SYMBOL IS NAMED LIBRARY-QUALIFIED, `devices/annotate_params` (D2), the
# same spelling the IHP menu already uses for devices/code_shown — NOT
# `[find_file_first annotate_params.sym]`, the shipped Graphs-menu precedent at
# src/xschem.tcl:15309. Measured under a registry-only PDK config,
# find_file_first returns a stray tests/test_sweep_diff/… path; filed as issue
# 0449. The qualified form resolves through library.defs, which is what every
# PDK workarea uses, and it reaches the NESTED copy of the symbol under
# xschem_libs_newsym/devices — hence D1's requirement that both copies exist.
#
# ⚠ NO ELEMENT GUARD, AND NO getprop ROUND-TRIP (D4, correcting both shipped
# prototypes). They take `[lindex [xschem selected_set] 0]` and feed it to
# `xschem getprop instance <that> name`. Measured: `xschem selected_set` already
# returns instance NAMES, and returns an EMPTY list when only a wire is
# selected — so the round-trip is redundant and the feared "a wire index gets
# read as an instance" hazard is unreachable. Row K14 pins that fact.
#
# ⚠ INVARIANT I1. Only the instance NAME is passed as `ref`; no path is built
# here. Every raw-vector name still comes from op_annot::devpath / ::vector.
proc op_annot::place_annotator {} {
  set ref [lindex [xschem selected_set] 0]
  if {$ref ne {}} {
    xschem place_symbol devices/annotate_params "name=annot1 ref=$ref"
  } else {
    xschem place_symbol devices/annotate_params
  }
}
