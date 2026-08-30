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
#   op_annot::devpath <instname> ?basis? ?root?
#                                              -> "@m.x1.xm1.msky130_fd_pr__nfet_01v8"
#                                                 basis `read` (default, the
#                                                 raw-relative DISPLAY name) or
#                                                 `deck` (the entry-relative
#                                                 SAVE-CARD name)          (S3)
#   op_annot::vector <instname> <param> ?kind? -> "i(…[id])" / "…[gm]" / "v(…[vth])"
#   op_annot::raw_or_blank <vector>            -> the value at the annotation
#                                                 point, or {}          (S5)
#   op_annot::eng_or_blank <value>             -> to_eng of it, or {}   (S5)
#   op_annot::text <instname>                  -> the `label = value` block for
#                                                 one device, or {}     (S5)
#   op_annot::save_cards {}                    -> the `.save` block for the
#                                                 hierarchy below the current
#                                                 cell, or {}           (S3)
#   op_annot::write_save_file {}               -> writes it to
#                                                 $netlist_dir/<cell>.save (S3)
#   op_annot::last_warnings {}                 -> what the last walk could not
#                                                 do, as a list         (S3)
#   op_annot::last_counts {}                   -> {dropped_by_rule N not_found N
#                                                  name_failed N}       (S3)
#
# ============================================================================
# ⚠ A SAVE CARD IS BARE. `vector` IS THE READ SHAPE ONLY.  (spec §3 rule R4)
# ============================================================================
# op_annot::save_cards (S3, at the bottom of this file) writes the BARE form and
# has its own guardian rows. Measured on ngspice-42, one card per throwaway deck
# so no card could mask another, and re-measured on 46+ when S3 landed:
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
  ## S9 / invariant I5: "a user's op_annot::register in their own rc overrides
  ## the PDK's, and takes effect ON REDRAW -- no restart, no rebuild". The C
  ## overlay caches one rendered block per instance and can observe nothing about
  ## this namespace, so `register` publishes a generation counter that
  ## annot_overlay_sync() (actions.c) folds into its epoch. Two lines, and
  ## without them a cross-frame cache silently defeats I5.
  variable gen
  if {![info exists gen]} { set gen 0 }

  ## RULING D9b (the user, 2026-08-22) — THE SIX-ROW CAP, spec §4.2b.
  ## "For ANY PDK, ANY device, only display max of six parameters UNLESS there
  ## is a setting to do otherwise. We can't have BJT (NPN,PNP) causing clutter."
  ##
  ## The cap is enforced HERE, in the one formatter, rather than by trimming
  ## each descriptor: a descriptor is data a PDK or a user writes, and there
  ## will always be one more PDK than there are descriptors we have edited.
  ## IHP's vertical_npn shipped SIXTEEN rows, which is the case that prompted it.
  ##
  ## 0 (or any non-integer) means NO LIMIT — that is the "setting to do
  ## otherwise", available today from any --script rc or the console:
  ##     set ::op_annot_max_rows 0      ;# show everything a descriptor carries
  ##     set ::op_annot_max_rows 10     ;# or any other ceiling
  ## Issue 0603 is the friendlier means; this is the mechanism it will drive.
  if {![info exists ::op_annot_max_rows]} { set ::op_annot_max_rows 6 }

  ## The seam for invariant I8 / issue 0604: how many rows the LAST op_annot::text
  ## dropped to honour the cap. Without it "the cap works" and "the formatter
  ## returned nothing" are the same observation, and a silent truncation is
  ## exactly the class of thing I8 exists to make audible.
  variable dropped
  if {![info exists dropped]} { set dropped 0 }

  ## S3's hierarchy walk. All of these are namespace state and not proc locals
  ## because the walk RECURSES and its restore runs from a sibling proc.
  ##   _acc        the accumulating card list
  ##   warnings    what the walk could not do, read back by op_annot::last_warnings
  ##   _busy       the re-entrancy latch (issue 0438); cleared in _restore, which
  ##               runs on the error path too, so a raise cannot wedge the feature
  ##   _c_rule     issue 0497 counter: the NETLISTER dropped it. Expected.
  ##   _c_notfound issue 0497 counter: the deck HAS it and the walk could not
  ##               reach it. THE 0496 CLASS. Never normal.
  ##   _c_name     issue 0497 counter: no name could be built for it.
  variable _acc
  if {![info exists _acc]} { set _acc {} }
  variable warnings
  if {![info exists warnings]} { set warnings {} }
  variable _busy
  if {![info exists _busy]} { set _busy 0 }
  variable _c_rule
  if {![info exists _c_rule]} { set _c_rule 0 }
  variable _c_notfound
  if {![info exists _c_notfound]} { set _c_notfound 0 }
  variable _c_name
  if {![info exists _c_name]} { set _c_name 0 }
}

## The effective row cap: a positive integer, or 0 for no limit. Anything the
## user set that is not a non-negative integer is treated as NO LIMIT rather
## than as the default — a typo must not silently hide rows.
proc op_annot::max_rows {} {
  if {![info exists ::op_annot_max_rows]} { return 6 }
  set v $::op_annot_max_rows
  if {![string is integer -strict $v] || $v < 0} { return 0 }
  return $v
}

## Rows the last op_annot::text call dropped to honour the cap. 0 when nothing
## was dropped. Read by tests today, by the I8 reporter when it lands.
proc op_annot::dropped {} {
  variable dropped
  return $dropped
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
  ## I5: tell the draw-time overlay its cached blocks are stale (see the
  ## namespace header). Bumped on EVERY register, including a re-register with
  ## identical content -- a no-op bump costs one cache rebuild, a missed one
  ## leaves the user staring at the descriptor they just replaced.
  incr ::op_annot::gen
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

## ISSUE 0963 — THE SAME NAME, IN EVERY SPELLING A RESULTS FILE MAY USE.
##
## Returns the ordered list of vector names to try for one device parameter:
## the descriptor's own spelling first, then the BARE one. Deduped to a single
## element for kind 1, whose spelling is already bare.
##
## ⚠ WHAT A READER WOULD OTHERWISE ASSUME IS THAT ONE SPELLING IS ENOUGH. It is
## not, and the second spelling is not a guess — it is what a results file
## written by naming devices on the `write` line actually contains. MEASURED,
## ngspice-46+, the same device in two results files from ONE run:
##   per-device `.save` cards -> `i(@dev[id])` current, `v(@dev[vgs])` voltage
##   `write <raw> all @dev`   -> `@dev[id]` notype, `@dev[vgs]` notype
## and get_raw_index (src/save.c:2567-2600) tries exact / upper / lower and then
## ADDS a `v(...)` wrapper — it never STRIPS one. So a `i(@dev[id])` request
## against the second file misses SILENTLY and the schematic paints a blank
## where a real number exists: measured at 4 of the 6 rows this tree shows for
## a sky130 transistor (id, vgs, vth, vds).
##
## ⚠ ORDER IS LOAD-BEARING AND THE WRAPPED SPELLING MUST STAY FIRST. Because
## get_raw_index adds `v(...)` on its own, a BARE request also finds a
## `v(@dev[vgs])` in an ordinary results file — so a bare-first order would
## work, silently, right up until a file held both spellings. First hit wins,
## and on every ordinary results file the first hit is the first spelling, which
## is why row B4 measures the fallback changing nothing at all.
##
## ⚠ BOTH SPELLINGS COME FROM _wrap (invariant I1). Typing `${dev}\[${param}\]`
## out again here would be a second wrapper builder, and when token.c's kind
## table moves only one of them would follow.
proc op_annot::_wrap_alts {dev param kind} {
  set out [list [::op_annot::_wrap $dev $param $kind]]
  set bare [::op_annot::_wrap $dev $param 1]
  if {[lindex $out 0] ne $bare} { lappend out $bare }
  return $out
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

## ============================================================================
## THE TWO BASES — S3, AND WHAT REVERTED ATTEMPT 1 (issue 0436)
## ============================================================================
## `devpath` has TWO consumers and they measure the hierarchy from two different
## places:
##
##   read (default)  `xschem get sim_sch_path` (scheduler.c:5186) — the .sch path
##                   with the RAW-LOAD levels stripped. Correct for READING a
##                   vector out of a raw that is loaded right now, which is what
##                   S5's formatter and S9's overlay do.
##   deck            `xschem get sch_path` minus the WALK-ENTRY root. Correct for
##                   WRITING a save card into a deck nobody has simulated yet.
##
## Attempt 1 built save cards on the `read` basis. Measured on the S3 fixture,
## with a raw loaded one level down and the walk run from the top:
##
##     no raw        xok1 -> @m.xok1.mp1.dp     xok2 -> @m.xok2.mp1.dp
##     raw at lvl 1  xok1 -> @m.mp1.dp          xok2 -> @m.mp1.dp    <- COLLAPSED
##
## Two instances of one subcell, ONE device name, no warning anywhere — and a
## card naming a device the deck does not contain is not cosmetic: under the
## `.control … write … .endc` idiom every shipped PDK bench uses it writes a
## column of zeros marked `dims=0`, and if EVERY device card is bogus ngspice
## writes no raw at all.
##
## The fix is a BASIS on the ONE builder, not path arithmetic in the walk — that
## would be the second name builder invariant I1 forbids.

## Validate the basis/root pair. THE ONLY RAISER in the basis machinery: a
## caller that asked for the wrong shape must hear about it even when the
## instance would have answered blank anyway.
proc op_annot::_check_basis {basis root} {
  if {$basis eq {read}} {
    if {[string trim $root] ne {}} {
      return -code error \
        "op_annot::devpath: a \"root\" argument is meaningless with basis\
 \"read\" — the read name is measured from the level the RAW was loaded at, not\
 from a walk entry. Pass basis \"deck\" to root a name at a walk entry."
    }
    return read
  }
  if {$basis ne {deck}} {
    return -code error \
      "op_annot::devpath: unknown basis \"$basis\" — expected \"read\" (the\
 raw-relative name a LOADED raw uses, for display) or \"deck\" (the\
 entry-relative name an UNSIMULATED deck uses, for save cards)."
  }
  ## deck: the root is the walk's entry `sch_path` and must still be a prefix of
  ## where we now stand. A root from a different walk is a caller bug, and a
  ## blank answer would be worse than a raise: `string range` over a mismatched
  ## prefix yields a plausible truncation, and a wrong device name does NOT
  ## blank at read time — under the dot-card idiom it removes the whole raw.
  if {[catch {xschem get sch_path} p]} { return deck }
  set r [::op_annot::_root $root]
  if {[string first $r $p] != 0} {
    return -code error \
      "op_annot::devpath: root \"$r\" is not a prefix of the current hierarchy\
 path \"$p\" — the root must be the sch_path of the level the walk started from."
  }
  return deck
}

## The walk-entry root, defaulted. `.` is level 0, i.e. `xschem get sch_path` at
## the top, which is what makes `deck` with no root mean "rooted at the top".
proc op_annot::_root {root} {
  if {[string trim $root] eq {}} { return {.} }
  return $root
}

## THE ONE PREFIX SEAM. Every name this file builds — template arm and devproc
## arm alike — takes its hierarchy prefix from here. Both answers include the
## trailing `.`, which is what makes `@m.` + prefix + spiceprefix + name + `.` +
## inner-device concatenate.
##
## Never cached and never memoised — caching would pass every golden and produce
## the wrong path the moment the walk descends (landmine 4).
##
## ⚠ NO RAISE. Validation lives in _check_basis; this proc must stay usable from
## the draw path, so a mismatched root here degrades to a blank prefix.
proc op_annot::_pathfor {basis root} {
  if {$basis ne {deck}} { return [::op_annot::_simpath] }
  if {[catch {xschem get sch_path} p]} { return {} }
  set r [::op_annot::_root $root]
  if {[string first $r $p] != 0} { return {} }
  return [string range $p [string length $r] end]
}

## Substitute the prefix into a devpath TEMPLATE, before `xschem translate` runs.
##
## ⚠ BOTH SPELLINGS ARE MAPPED, AND `@path` IS THE WHOLE POINT. `$path` is spec
## §4.2's spelling; `@path` is translate-native — and translate resolves it with
## a byte-for-byte copy of sim_sch_path's stripping loop (token.c:4719), i.e.
## RAW-RELATIVELY. Leaving `@path` to translate would leave gf180's and IHP's
## descriptors (both `@path` templates) raw-relative in the `deck` basis while
## every sky130 row — sky130 registers a devproc — still passed. Two arms, two
## bugs, one of them in the C.
##
## For basis `read` the two routes are measurably identical (token.c:4719 and
## scheduler.c:5186 are the same loop over the same data), so mapping it here
## costs nothing and keeps ONE code path.
##
## ⚠ `string map`, NEVER `subst`: a template is user data and `subst` would
## execute any `[...]` inside it. Documented consequence, unchanged: a literal
## `$pathological` / `@pathological` is also rewritten.
proc op_annot::_subst_path {tmpl dp} {
  return [string map [list {$path} $dp {@path} $dp] $tmpl]
}

## Call a descriptor's `devproc`, handing it the SAME prefix the template arm
## substitutes. The devproc contract is unchanged:
##     <proc> <instname> <model> <path> <spiceprefix>
## ⚠ `uplevel #0` so a PDK proc that reaches for a global finds one.
proc op_annot::_devproc_call {p instname model dp pfx} {
  return [uplevel #0 [list $p $instname $model $dp $pfx]]
}

## op_annot::devpath <instname> ?basis? ?root? -> the lowercased raw-file device
## path, without the `[param]` suffix; {} for every data condition.
##
##   op_annot::devpath M1            ->  @m.x1.xm1.msky130_fd_pr__nfet_01v8
##   op_annot::devpath M1 deck .     ->  the same string with the hierarchy
##                                       rooted at `.`, and no loaded raw able
##                                       to move a single character of it
##
## `basis` is `read` (the default, the raw-relative DISPLAY name) or `deck` (the
## entry-relative SAVE-CARD name); `root` is the walk-entry `sch_path` and is
## legal only with `deck`. See the two-bases block above.
##
## ⚠ THE DEFAULT MUST STAY `read`. Every S5/S6/S9 consumer calls this from a
## draw path with one argument; if the default became `deck` the on-screen
## display would silently change basis.
##
## I4: this reads context, it never moves in it. No descend, no set_modify, no
## write to the .sch.
proc op_annot::devpath {instname {basis read} {root {}}} {
  ## Loud FIRST: a caller that asked for the wrong shape must hear about it even
  ## when the instance would have answered blank anyway.
  set basis [::op_annot::_check_basis $basis $root]
  set t [::op_annot::type $instname]
  if {$t eq {}} { return {} }
  set d [::op_annot::descriptor $t]
  if {$d eq {}} { return {} }
  ## Issue 0425: the type key is shared by every PDK and by the generic
  ## devices/*.sym. A descriptor only builds a name for a cell it claims.
  if {![::op_annot::_matches $instname $d]} { return {} }

  ## THE ONE PREFIX, for whichever arm follows.
  set dp [::op_annot::_pathfor $basis $root]

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
    if {[catch {::op_annot::_devproc_call $p $instname $model $dp $pfx} r]} {
      return {}
    }
    if {$r eq {}} { return {} }
    return [::op_annot::_lower $r]
  }

  if {![dict exists $d devpath]} { return {} }
  set tmpl [dict get $d devpath]
  if {$tmpl eq {}} { return {} }
  set tmpl [::op_annot::_subst_path $tmpl $dp]
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
## The two terms are COPIED from the C's own read gate (token.c's six
## cursor_b_val[] branches), not invented, so op_annot::text shows exactly what
## the schematic's own @spice_get_voltage texts show:
##   xschem raw loaded >= 0      sch_waves_loaded(). get_raw_index() is gated on
##                               it (save.c:2259), so below 0 every lookup is -1
##                               anyway; ascending out of the annotated level is
##                               what reaches this (landmine 4).
##   annot_p >= 0                `xschem raw annot` -> {annot_p annot_x
##                               annot_sweep_idx}. -1 means NOTHING was ever
##                               published, i.e. the fabricated-zero state.
##
## ⚠ ISSUE 0864 — THERE USED TO BE A THIRD TERM, AND A READER WHO REMEMBERS IT
## WILL ASSUME IT IS STILL LOAD-BEARING. It was the shipped menu checkbutton
## `Simulation > Graphs > Live annotate probes with 'b' cursor`, read FIRST, so
## unticking a box about the cursor blanked the device operating-point block
## that `6` draws while every number sat untouched in the database (measured:
## the block reads blank row by row, `xschem raw value` still reads
## 9.9999997e-05). That switch means "follow cursor B and re-annotate as it
## moves" — a question about WHEN to re-read, never about whether there is
## anything to read — so it is not a term of this gate and must not come back as
## one. The C half of the same split removed it from all six token.c branches;
## the old note here argued the term was needed to stop the block going HALF
## blank, and that argument is answered by removing it from BOTH languages
## rather than by keeping it in either. Rows S16 (behavioural, both halves in
## one golden) and A64-4 (this proc's own source) pin it.
##
## ⚠ EVERY TERM IS CATCH-WRAPPED, INCLUDING `xschem raw annot` — measured, it
## RAISES "No raw file loaded" exactly like `raw value`. A gate that can raise
## in a draw path is a second bug, not a guard.
##
## NOT MIRRORED: the C's `&& !raw_is_digital(xctx->raw)`, which after 0864 is the
## whole of the C gate's extra condition. No Tcl accessor exposes it, and it
## costs nothing here — a digital raw holds no device parameter vectors, so every
## row blanks through raw_or_blank anyway.
proc op_annot::_annotated {} {
  if {[catch {xschem raw loaded} l]} { return 0 }
  if {![string is integer -strict $l] || $l < 0} { return 0 }
  if {[catch {xschem raw annot} a]} { return 0 }
  if {![string is integer -strict [lindex $a 0]] || [lindex $a 0] < 0} { return 0 }
  return 1
}

# ===========================================================================
# ISSUE 0684 -- IS THE DATABASE THIS WINDOW IS PAINTING FROM STILL THE FILE IT
#               WAS READ FROM?  The ONE mint, called by BOTH operating-point
#               surfaces: the `6` / `Alt-6` chords (cadence::annot_mode,
#               utils/annot_mode.tcl) and ASE-L's `Results > Annotate` tick
#               (ase::ui::annot_ensure_loaded, src/ase_window.tcl).
# ===========================================================================
# WHAT THE USER SAW. Press 6. Numbers appear. Change a device, re-run the
# simulation, press 6 again -- the sheet repaints the PREVIOUS run's
# id / gm / gds under a sentence saying the results were already loaded.
# Nothing on screen distinguishes it from a correct annotation. RULING D5-1 and
# invariant I3 in their own words: "A missing vector renders BLANK. Not 0, not
# NaN on screen, not the previous run's number."
#
# ⚠ WHY THIS IS A SECOND PREDICATE AND NOT A CALL TO THE TRANSIENT SURFACE'S.
# A reader who has seen `cadence::_annot_tran_db_current` (issue 0900) will
# assume this is the same question and that RULING D5-4 obliges us to call it.
# MEASURED 2026-08-28, and it is not: that predicate consults
# `cadence::_annot_viewer_db`, which reports a database only when the WAVEFORM
# VIEWER is showing a `tran` (annot_mode.tcl, "ONLY A TRANSIENT IS OFFERED"),
# so with a stale operating point attached it answers 1 = "current" both before
# and after the file on disk becomes a different run. Calling it from here is a
# fix that passes while doing nothing. The two surfaces ask genuinely different
# questions:
#     TRAN -- do two WINDOWS' in-memory copies agree?
#     OP   -- is the database this ONE window is painting from still the file
#             it was read from?  (an operating-point run usually has no
#             waveform window at all, so there is no second window to consult)
# Widening `_annot_viewer_db` past `tran` was rejected: it is issue 0903's line,
# it is scope-fenced away from this item, and it would change the transient
# supply's documented behaviour. So: minted ONCE here, rendered by both
# operating-point callers. Invariant I1 is honoured by the CALLERS, not by
# pretending two different questions are one.
#
# ⚠ THE STAMP IS A PATH + mtime + size, AND THAT IS DELIBERATELY CHEAP.
# `cadence::_annot_db_print` -- the transient surface's fingerprint -- is one
# `xschem raw value` per SAVED VECTOR and costs 28.3 ms on a 40000-vector
# database (issue 0904). The operating-point path reads DEVICE PARAMETER
# vectors, so a `.save all` design is exactly where it would hurt, and this
# predicate runs on every key press. Row F35 of
# tests/headless/test_annot_stale_0684.tcl greps this proc and db_attach for
# `_annot_db_print` and requires ZERO hits; that grep is why the name must not
# appear on a code line here.
#
# ⚠ KNOWN LIMITATION, STATED RATHER THAN HIDDEN: `file mtime` is 1-second
# resolution, so a same-second rewrite of identical size is invisible to this
# stamp. That hole is open on every re-run route and is not closed by anything
# in this file.

## The stamp table. Keyed "<current_win_path>|<normalized raw path>", because
## the mask and xctx->raw are BOTH per-context: under the tabbed interface two
## windows can hold two different databases at once, and a table keyed on the
## path alone would let one window's observation answer for the other. A key
## that goes stale can only ever cause a harmless re-read, never a false
## "current".
namespace eval op_annot {
  variable _db_src
  if {![info exists _db_src]} { array set _db_src {} }
}

proc op_annot::_db_key {np} {
  set w {}
  catch {set w [xschem get current_win_path]}
  return "$w|$np"
}

## {mtime size} for a file, or {} when it cannot be stat'ed. Both terms, not
## just mtime: a simulator that rewrites within the same second usually changes
## the length too, so the pair sees a little more than the clock alone.
proc op_annot::_db_stat {np} {
  set m {}
  set s {}
  if {[catch {file mtime $np} m]} { return {} }
  if {[catch {file size $np} s]} { return {} }
  return [list $m $s]
}

## Forget one path's stamp, or -- with no argument -- every stamp belonging to
## THIS window.
##
## ⚠ THE NO-ARGUMENT FORM IS A GUARD, NOT HOUSEKEEPING (issue 0684). A stamp
## describes a database that is ATTACHED. Once nothing publishable is attached
## -- the user picked `Waves > Clear`, another surface detached, a graph
## replaced it -- the stamp describes an attachment epoch that is over, and
## keeping it would let the NEXT attach of that same path be judged against an
## observation from the previous one: the file would read "changed since I last
## looked" and a perfectly good fresh attach would be thrown away and re-read.
##
## ⚠ ITS BEHAVIOURAL WITNESS IS GONE, AND THAT IS WORTH SAYING OUT LOUD
## (measured 2026-08-28, item B1, by neutralizing the no-argument form and
## re-running the suite: 45/45, nothing moved). Row F7 used to see it -- it
## hand-attached a path this file had stamped before and required the FIRST
## look to answer "current". Since issue 0910 that same first look answers
## "re-read" whether or not a stale stamp survived, so F7 can no longer tell
## the two apart, and every other arm agrees either way. What is left is
## hygiene with teeth in one direction only: a surviving stamp can never make
## a re-attach say "current" that should have said "re-read", it can only cost
## an extra read. Row **F42** is now its only witness and it is a STRUCTURAL
## one -- it reads this proc's caller and requires the no-argument forget to
## sit on the not-attached arm, above every path question. Deleting this and
## watching the suite stay green is exactly the trap 0684 catalogued.
proc op_annot::_db_forget {{np {}}} {
  variable _db_src
  if {$np ne {}} {
    catch {unset _db_src([::op_annot::_db_key $np])}
    return 1
  }
  set pfx [::op_annot::_db_key {}]
  foreach k [array names _db_src] {
    if {[string first $pfx $k] == 0} { unset _db_src($k) }
  }
  return 1
}

## Record the stamp for <np> from the file as it is on disk RIGHT NOW.
proc op_annot::_db_stamp {np} {
  variable _db_src
  set now [::op_annot::_db_stat $np]
  if {![llength $now]} { return 0 }
  set _db_src([::op_annot::_db_key $np]) $now
  return 1
}

## op_annot::db_current <candidate-path> -> 1 when the database attached to
## THIS window is one this surface can paint from AND is still the file it was
## read from; 0 when the caller must RE-ATTACH (or blank). <candidate-path> is
## the path this surface would attach, or {} when it has none.
##
## THE GUARDS, IN ORDER -- and the ORDER IS THE GUARD:
##
##   G1  nothing publishable is attached -> 0. That is defect B of issue 0684:
##       an ordinary waveform graph leaves `xschem raw loaded` at 0 with
##       `xschem raw annot` at -1, and the shipped guard read that as "a
##       database is here, leave it alone", so the tick rendered nothing and
##       said nothing. It is asked FIRST, above every path comparison, because
##       a foreign transient sitting at a foreign path would otherwise read as
##       "not mine, therefore current" and the control would stay dead forever.
##       Rows F6 and F24 own it, and row W1a27 of
##       tests/headless/test_ase_window.tcl owns it on the real menu. NOT row
##       F1, whose title used to claim it: with nothing attached at all G2's
##       catch answers first, so F1 never reaches this line (measured 2026-08-28
##       by deleting it -- F1 stayed green).
##
##   G2  the attached database cannot be named -> 0 = RE-ATTACH.
##       ⚠ EVERY CATCH IN THIS BODY FALLS TO 0, NEVER TO 1 AND NEVER TO A BARE
##       `return`. `xschem raw rawfile` RAISES with nothing attached (measured,
##       not assumed), and an early return on an unanswerable question is the
##       precise mechanism by which the shipped guard paints run 1 forever.
##       No behavioural row can stage this arm -- G1 has already refused every
##       state in which `raw rawfile` blows up -- so row F8 reads this proc's
##       own source and is its only witness.
##
##   G3a no stamp for this window+path -- "first sight". A database attached by
##       some OTHER route -- `Waves > Op Annotate`, `Simulation > Graphs >
##       Annotate Operating Point into schematic`, an xschemrc line, a test
##       fixture -- has nothing to be compared against the first time it is
##       seen. WHICH FILE IT IS decides what happens next, and the split is
##       ISSUE 0910 (fixed 2026-08-28):
##         the attached path IS this surface's own candidate -> 0, RE-ATTACH.
##           Until this was fixed, "trusted once" was "trusted FOREVER"
##           whenever the first sight landed AFTER the file changed: the stamp
##           is minted at this OBSERVATION, not at the attach, so a menu attach
##           followed by a re-run over the same file was blessed against run 2
##           while holding run 1's numbers, and every press of `6` from then on
##           repainted the previous run under "These results were already
##           loaded." Row F7 cannot see it -- F7 asks once BEFORE it rewrites.
##           Rows F36..F39 and F41 stage the user's own order.
##         the attached path is ANYTHING ELSE -> record a stamp and answer 1.
##           This arm is load-bearing: rows N5, N10 and V31b of
##           tests/headless/test_op_annot.tcl hand-attach a database and expect
##           the `live` arm, and `xschem annotate_op` DESTROYS a 1-point op it
##           replaces, so a predicate that answered 0 on EVERY first sight
##           would not merely re-read a good file -- it would delete another
##           corner's operating point out from under the user (issue 0908).
##           Row F40 is that promise on the first press; row F41 leg b on the
##           mint itself.
##
##   G3b the stamp still matches -> 1. This is the cheap path, and it is the
##       reason a press does not re-read the file: row F19 is its guard.
##
##   G4  the stamp DIFFERS. Now the candidate decides:
##         ⚠ ISSUE 0912, MEASURED 2026-08-28 AND OPEN: the no-candidate half of
##           the next line is also what happens when the results file has been
##           DELETED -- `ase::last_rawfile` answers {} for a file that is gone,
##           so ASE-L's tick early-returns above guard G13 and keeps painting
##           numbers whose file no longer exists, while `6` in the identical
##           state blanks and says why. "Nothing to re-attach from" and "these
##           numbers are still your run" are being answered by the same 1.
##         no candidate, or a candidate at a DIFFERENT path -> 1. This surface
##           never destroys a database it did not attach. The user may be
##           looking at another corner's operating point loaded by hand, and
##           `xschem annotate_op` DOES destroy a 1-point op/dc it replaces
##           (scheduler.c's delete-previous-OP branch), so "not mine" must mean
##           "leave it exactly where it is".
##           ⚠ BOTH ARMS NEED A SECOND LOOK TO BE REACHED AT ALL, and until
##           2026-08-28 nothing here took one: a row that stages the situation
##           and then asks ONCE is answered by G3a several lines above, so
##           inverting either arm changed no answer in any suite. The witnesses
##           are row F5 (first sight, then a rewritten foreign file), row F20
##           (the same through the `6` chord, two presses), and row F4 for the
##           no-candidate arm (a rewritten file, then asked with no candidate).
##           Row W1a16 of tests/headless/test_ase_window.tcl states the user's
##           side of the same promise but is a first-sight row and does not
##           reach this line.
##         the candidate IS the attached path -> 0. THE HEADLINE: the file this
##           window is painting from has been rewritten by a re-run. Row F3.
proc op_annot::db_current {cand} {
  variable _db_src
  set ann 0
  catch {set ann [::op_annot::_annotated]}
  if {!$ann} { ::op_annot::_db_forget ; return 0 }
  set f {}
  if {[catch {xschem raw rawfile} f]} { return 0 }
  if {$f eq {}} { return 0 }
  set np {}
  if {[catch {file normalize $f} np]} { return 0 }
  if {$np eq {}} { return 0 }
  set key [::op_annot::_db_key $np]
  set now [::op_annot::_db_stat $np]
  if {![info exists _db_src($key)]} {
    ## G3a-2, ISSUE 0910 -- FIRST SIGHT OF **THIS SURFACE'S OWN CANDIDATE** IS
    ## NOT TRUSTED, IT IS RE-READ.
    ##
    ## What a reader would otherwise assume, and what was shipped until
    ## 2026-08-28: that "no stamp yet" means "nothing has happened since the
    ## attach, so the numbers in memory match the file". It does not. The stamp
    ## is minted HERE, at the first OBSERVATION -- `op_annot::db_attach` is the
    ## only route that stamps at attach time -- so a database put here by
    ## `Simulation > Graphs > Annotate Operating Point into schematic` or the
    ## waveform window's `Waves > Op Annotate` (both a bare `xschem
    ## annotate_op`), followed by a re-run over the same file, was blessed
    ## against RUN 2's file while holding RUN 1's numbers. Guard G3b then
    ## answered "current" forever and the sheet repainted the previous run's
    ## numbers on every press of `6`, saying they were already loaded. That is
    ## RULING D5-1 and invariant I3 -- "not the previous run's number" -- and
    ## driver ruling 0900, every press re-consults the source.
    ##
    ## So: when the attached path IS the path this surface would load itself,
    ## answer NOT CURRENT and let the caller re-attach. One read of a file that
    ## may not have changed is the stated price (issue 0910 section 4); the
    ## stamp written by that re-attach puts every later press back on G3b's
    ## cheap path, so the cost is one read per re-run, not one per press.
    ##
    ## ⚠ THE ARM BELOW THIS ONE IS NOT DECORATION. A database at some OTHER
    ## path is still trusted on first sight, and must be: rows N5, N10 and V31b
    ## of tests/headless/test_op_annot.tcl hand-attach a database and expect
    ## the live arm, and `xschem annotate_op` DESTROYS a 1-point op it
    ## replaces, so re-attaching over another corner's operating point would
    ## not hide it, it would delete it (issue 0908). Distrusting every first
    ## sight looks like a stronger fix and re-opens that defect.
    ##
    ## ⚠ THE TWO EMPTINESS TERMS BELOW ARE NOT LOAD-BEARING ON THIS TCL,
    ## AND AN EARLIER VERSION OF THIS COMMENT CLAIMED OTHERWISE ON A FACT THAT
    ## IS FALSE. It said `$cand ne {}` had to stay above the normalize because
    ## `file normalize {}` answers the current working DIRECTORY. MEASURED in
    ## the interpreter this runs in, Tcl 8.6.14, it answers the EMPTY STRING --
    ## so with no candidate the comparison below is false either way and
    ## control falls through to stamp-and-trust, which is the answer the
    ## no-candidate case wants. That comment also named row F41 leg c as the
    ## witness; F41 stays green with either term deleted, and so does every
    ## other row in the tier list (measured 2026-08-28: 46 here, 475 in
    ## test_op_annot, 27 in test_annot_blank_cause_0909, nothing moved).
    ##
    ## They stay, because deleting a guard nobody can see is how this branch
    ## ships defects: they say out loud what the branch is asking -- "does this
    ## surface have a candidate at all" -- and the empty-string answer is this
    ## Tcl's behaviour, not a contract this file should lean on. What they get
    ## instead of a false witness is a real one: row **F46** of
    ## tests/headless/test_annot_stale_0684.tcl is STRUCTURAL, it requires the
    ## emptiness test to sit on the same line and to the LEFT of the normalize,
    ## and its first leg re-measures `file normalize {}` every run so a Tcl
    ## that behaves differently reddens the suite instead of quietly changing
    ## what this branch means.
    ##
    ## Rows F36 (the headline, through the `6` chord), F37 (ASE-L's
    ## `Results > Annotate` tick), F38 (`ase::ui::annot_refresh_here`),
    ## F39 (the positive twin: nothing re-run, numbers must survive),
    ## F40 (the 0908 twin) and F41 (all four first-sight arms) in
    ## tests/headless/test_annot_stale_0684.tcl own this branch.
    set nc0 {}
    if {$cand ne {} && ![catch {file normalize $cand} nc0]} {
      if {$nc0 ne {} && $nc0 eq $np} { return 0 }
    }
    ::op_annot::_db_stamp $np
    return 1
  }
  if {[llength $now] && $now eq $_db_src($key)} { return 1 }
  if {$cand eq {}} { return 1 }
  set nc {}
  if {[catch {file normalize $cand} nc]} { set nc {} }
  if {$nc eq {} || $nc ne $np} { return 1 }
  return 0
}

## op_annot::db_attach <path> ?<level>? -> {ok errtext}: put <path>'s operating
## point onto THIS window and stamp it, or answer 0 with a sentence fragment
## the caller can render.
##
##   G6  ISSUE 0685'S TARGETED DROP, and ONLY that. `xschem annotate_op` hands
##       back a STALE in-memory database when the path it is asked for is
##       already in the extra-raw registry and something else is current:
##       extra_rawfile()'s dedup loop matches on rawfile+sim_type and takes the
##       "already loaded: switch to it" branch with NO read (save.c). The
##       precondition is exact -- `xschem raw read` ADDS (a waveform graph's own
##       form) while `xschem raw_read` REPLACES -- so the hazard needs a graph
##       open, which is the ordinary bench state.
##       ⚠ ROW F12 DEMONSTRATES THAT HAZARD BUT DOES NOT GUARD THIS DROP: it
##       makes its own bare `annotate_op` call first, which leaves the stale
##       entry CURRENT, and once it is current the attach re-reads with or
##       without a drop (measured 2026-08-28 -- deleting this loop left F12
##       green). The guard is row F12b, which is the same staging with nothing
##       in between.
##       ⚠ ONLY `op` AND `dc`, NEVER A THIRD TYPE, AND NEVER THE BARE
##       `xschem raw clear`. The 2026-08-25 attempt dropped op, dc AND tran at
##       this path; when the re-read then failed -- the ordinary case of a
##       simulator mid-rewrite, file present and readable but truncated -- the
##       user's loaded waveform database was gone and nothing replaced it
##       (issue 0685 section 4). The guard on the never-tran half is row F13b,
##       which puts the user's waveform at the SAME path this call is about --
##       the only place the type list can matter; row F13 stages the same
##       failure with the waveform somewhere else and guards the drop existing
##       at all, not its type list. Row F14 greps this body for the word it
##       must not contain and for the bare spelling that "unloads all raw
##       files".
##       The registry's OWN spelling of the path is handed back to `raw clear`,
##       so a drop cannot silently miss on a path-spelling difference; a miss
##       is a no-op (save.c's what==3 returns 0 and changes nothing).
##
##   G7  VERIFIED BY RE-ASKING, NEVER BY `annotate_op`'s RETURN. Measured on
##       this binary: `xschem annotate_op /nonexistent` returns TCL_OK with the
##       path string and nothing attached, and an unreadable file returns
##       TCL_OK with an empty result AND destroys whatever was attached. So the
##       engine's answer says nothing about whether it worked. Rows F10 and
##       F11 -- F11 golds the engine's OK next to this proc's 0, so a fix that
##       trusts the return cannot pass.
##
##   G8  THE STAMP IS WRITTEN ONLY AFTER THAT VERIFY, and any previous stamp
##       for the path is forgotten on failure. Row F10b, both halves.
##       ⚠ THE HAZARD IS NOT THE ONE THIS COMMENT USED TO NAME. It said a
##       stamp written early would make the next press answer "these results
##       were already loaded" over a BLANK sheet -- and that state cannot be
##       reached: a failed attach leaves nothing publishable attached, so G1
##       refuses the next question before any stamp is read, which is why the
##       2026-08-28 sabotage round could neutralise this guard with every suite
##       staying green. What a leftover stamp really costs is the case F10b
##       walks: the simulator is mid-write, the attach fails, the file is
##       finished a moment later, and the user attaches it from somewhere else.
##       That fresh, good attach is then judged against an observation of the
##       TRUNCATED file, so it is "changed since I last looked" on FIRST SIGHT
##       and is thrown away and re-read -- the needless re-read G3a exists to
##       prevent, which on a 40000-vector operating point is a 58 ms re-read on
##       every press, paid for nothing.
proc op_annot::db_attach {path {level {}}} {
  set np {}
  if {[catch {file normalize $path} np]} { set np {} }
  if {$np eq {}} { return [list 0 "the results file could not be named"] }
  ::op_annot::_db_forget $np
  set inf {}
  catch {set inf [xschem raw info]}
  foreach ln [split $inf "\n"] {
    set ln [string trim $ln]
    if {$ln eq {}} { continue }
    if {![regexp {^([0-9]+)[ \t]+(.*)[ \t]+([A-Za-z0-9_]+)$} $ln -> ei ep et]} { continue }
    if {$et ne {op} && $et ne {dc}} { continue }
    set enp {}
    if {[catch {file normalize $ep} enp]} { continue }
    if {$enp ne $np} { continue }
    catch {xschem raw clear $ep $et}
  }
  set rc 0
  set e {}
  if {$level ne {} && [string is integer -strict $level]} {
    set rc [catch {xschem annotate_op $np $level} e]
  } else {
    set rc [catch {xschem annotate_op $np} e]
  }
  set ann 0
  catch {set ann [::op_annot::_annotated]}
  set got {}
  catch {set got [file normalize [xschem raw rawfile]]}
  if {!$ann || $got ne $np} {
    ::op_annot::_db_forget $np
    if {!$rc || $e eq {}} {
      set e "it could not be read as a results file, or it holds no operating\
             point. If the simulator is still writing it, try again when the\
             run has finished"
    }
    return [list 0 $e]
  }
  ::op_annot::_db_stamp $np
  return [list 1 {}]
}

## op_annot::db_detach -> 1 when a database was taken off this window, 0 when
## there was nothing of this surface's to take off. THE "OR BLANK" HALF of
## issue 0684: a captioned refusal sitting above the previous run's numbers is
## not an improvement on a silent stale number, it is RULING D5-1 with a
## caption, so a surface that has learned the numbers are wrong takes them off
## BEFORE it says anything.
##
## ⚠ THIS BODY WAS `cadence::_annot_db_release`'s (issue 0902) AND IT MOVED
## HERE UNCHANGED. RULING D5-4: after this item BOTH operating-point surfaces
## and the transient surface need to take a database off, and annot_mode.tcl is
## loaded only by the cadence profile while this file is sourced by every
## session (src/xschem.tcl). `cadence::_annot_db_release` is now a one-line
## delegate, so there is still exactly one place that knows how to take numbers
## off a sheet. Row V74 of tests/headless/test_op_annot.tcl moved its spelling
## legs here with the body; row F15 of tests/headless/test_annot_stale_0684.tcl
## is the new home and also requires the old address to be a delegate.
##
## ⚠ THE NAMED SPELLING, NEVER THE BARE ONE (issue 0902). With no file given
## `xschem raw clear` "unloads all raw files" (src/scheduler.c) -- the WHOLE
## registry of the window, not the one database the caller is talking about.
## Measured: a design window holding a transient AND a co-simulation VCD went
## from two databases to none on one key press.
##
## ⚠ AND A DIGITAL DATABASE IS NEVER TAKEN OFF -- RULING D5-3 read forwards.
## `xschem annotate_op` refuses a digital file before it loads anything, so
## this surface can never have attached one; there is nothing of ours to put
## back, and a window whose current database is a VCD must come out of a
## refusal exactly as it went in. The question is asked ABOVE the clear, or the
## answer arrives too late to matter.
proc op_annot::db_detach {} {
  set f {}
  set t {}
  if {[catch {xschem raw rawfile} f]} { return 0 }
  if {[catch {xschem raw sim_type} t]} { return 0 }
  if {$f eq {} || $t eq {}} { return 0 }
  set dig 0
  catch {set dig [xschem raw is_digital]}
  if {$dig eq {1}} { return 0 }
  catch {xschem raw clear $f $t}
  catch {::op_annot::_db_forget [file normalize $f]}
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
        ## ISSUE 0963: EVERY SPELLING THIS PARAMETER MAY CARRY, FIRST HIT WINS.
        ## An ordinary results file answers on the FIRST name, so this loop
        ## costs one extra `xschem raw value` (0.5 us, measured) only for a
        ## parameter that is genuinely absent. The second name is what a file
        ## written by naming devices on the `write` line spells them as; see
        ## op_annot::_wrap_alts for the measurement and for why the order is
        ## load-bearing.
        foreach vn [::op_annot::_wrap_alts $dev [lindex $row 1] [lindex $row 2]] {
          set val [::op_annot::raw_or_blank $vn]
          if {[::op_annot::_finite $val]} { break }
        }
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

  ## RULING D9b — THE CAP. Applied AFTER all three row classes are built, so the
  ## kept rows are the first N in the descriptor's own declared order (params,
  ## then pinexpr, then derived) and a PDK author controls what survives by
  ## ordering the list. Applied BEFORE the width pass, so the label column pads
  ## to the longest label ACTUALLY SHOWN — a dropped 7-char label must not leave
  ## six rows padded to 7.
  variable dropped
  set dropped 0
  set cap [::op_annot::max_rows]
  if {$cap > 0 && [llength $rows] > $cap} {
    set dropped [expr {[llength $rows] - $cap}]
    set rows [lrange $rows 0 [expr {$cap - 1}]]
  }

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

# ============================================================================
# S3 — THE HIERARCHY WALK AND THE SAVE-CARD GENERATOR
# ============================================================================
#   op_annot::save_cards {}       -> the `.save` block for the whole hierarchy
#                                    below the CURRENT cell, as text; {} when
#                                    no device produced a card
#   op_annot::write_save_file {}  -> writes it to $netlist_dir/<cell>.save and
#                                    returns the path; {} when nothing to save
#   op_annot::last_warnings {}    -> what the walk could not do, as a list
#   op_annot::last_counts {}      -> {dropped_by_rule N not_found N name_failed N}
#
# PORTED FROM ihp-sg13g2/sg13g2_procs.tcl, the single-PDK prototype, whose twin
# sky130A/sky130_procs.tcl:72-146 is byte-for-byte the same design:
#   * sg13g2_sch_expand (:345-363) contributes the ENTRY SHAPE — accumulator
#     reset, keep_symbols save/set, unselect_all, no_draw 1, no_undo 1, recurse,
#     restore — and op_annot::save_cards keeps that ordering.
#   * sg13g2_hier_sch_expand (:366-421) contributes the RECURSION — instance
#     loop, emit-before-descend, vector-member count through `xschem
#     expandlabel`, select + descend, change_sch_path for members 2..N, go_back
#     at the last member.
#   * sg13g2_save_params (:425-432) contributes the BLOCK ASSEMBLER, minus its
#     two-pass `{npn}` / `{[pn]mos}` call: one descriptor-driven pass replaces it.
#   * the menu item (:602-606) contributes write_save_file, `file mkdir
#     $netlist_dir` included — which sky130A/sky130_procs.tcl:235 lacks.
#
# DELIBERATELY NOT PORTED, each for a MEASURED reason:
#   * `sg13g2_write_save_lines` (:304-341) itself. Its FET arm is 10 hardcoded
#     `.save` lines and its HBT arm 13, both already lifted into S2's `params`
#     lists; with them die the `[pn]mos`/`vertical_npn` regexp dispatch, the
#     `@n.`/`@q.` element letters and the `_5t` strip (which is the entire
#     justification for the descriptor's `devproc` key).
#   * `startpath` (:350, `[string length [xschem get sch_path]]`, consumed at
#     :369). That is a SECOND name builder, which invariant I1 forbids. The basis
#     lives on op_annot::devpath instead — see the two-bases block above.
#   * `xschem getprop symbol <cell> type` (:377). MEASURED: it RAISES for
#     generator cells — 6 of the 14 instances of
#     xschem_library/generators/test_generators.sch — while `getprop instance
#     <n> cell::type` raises 0 times. op_annot::type is the index form (0431).
#   * `xschem getprop instance $i spiceprefix` (:375). getprop reads
#     inst->prop_ptr only and is EMPTY when the token lives in the symbol
#     `template=`, which is why both prototypes lose the leading `x` on 3 of 45
#     shipped sky130 cells (issue 0430). `xschem translate … @spiceprefix` is
#     the form that answers.
#   * `if {$res} … else {xschem go_back 2}` (:400-408). `xschem descend` returns
#     0 in TWO classes and the unconditional go_back pops a level it never
#     pushed for the class-1 refusal, corrupting sch_path for the rest of the
#     walk (issue 0433). op_annot::_descended is the replacement.
#   * the straight-line restore (:358-362). It is on the NORMAL path with no
#     catch, so a raise below entry — `sky130_save_fet_params` on
#     `sky130_tests/test_generators` is the measured case — returns with
#     no_draw=1 and keep_symbols=1 still set (issue 0431). op_annot::_restore
#     runs unconditionally, on the shape of core `proc traversal`
#     (src/xschem.tcl:3590-3612, issue 0600) plus the log-suppress pop and the
#     autosave park.
#   * the `nolist_libs` regexp skip (:381-387) and the `regexp $pattern $symbol`
#     device filter (:388-390). Neither is the netlister's rule. The descriptor
#     `match` globs answer "is this annotatable" and the DECK answers "is this
#     in the netlist" — see the oracle block below.
#   * NEITHER PROTOTYPE EMITS `.save all` (sky130_procs.tcl:80-87 -> :177,
#     sg13g2_procs.tcl:310-339 -> :425-432). That is a live I2/R2 breach in the
#     tree (plan landmine 7): an explicit save cancels the implicit
#     save-everything and every node voltage disappears from the raw.
#     op_annot::_block carries the leader; the prototypes are left alone
#     because S2 still uses them as its card-NAME oracle.
#
# ============================================================================
# ⚠ THE FILTER IS NOT MIRRORED, IT IS ASKED. (issue 0442)
# ============================================================================
# A save card naming a device that is not in the deck damages the simulation it
# was generated for. Measured on /usr/local/bin/ngspice 46+ under the
# `.control … write … .endc` idiom every shipped PDK bench uses:
#
#   good cards + ONE bogus card  -> rc 0, RAW WRITTEN, a column under exactly the
#                                   requested name marked `dims=0`, stderr EMPTY
#   EVERY device card bogus      -> rc 0, NO RAW AT ALL, and then it warns
#
# So "which instances are in the deck?" must be answered exactly. The SPICE
# netlister drops instances in SEVEN classes, in two different files:
#
#   spice_netlist.c:188/:209  skip_instance(i,1,lvs_ignore)  spice_ignore=true
#   spice_netlist.c:188/:209  skip_instance(i,1,lvs_ignore)  spice_ignore=short
#   spice_netlist.c:216       only_toplevel, gated on netlist_count
#   spice_netlist.c:663       an empty or absent symbol `format`
#   spice_netlist.c:668       default_schematic=ignore
#   spice_netlist.c:689       spice_sym_def
#   spice_netlist.c:659/:695  spice_stop=true
#
# Attempt 2 hand-mirrored these and implemented THREE — the first three, all in
# skip_instance (netlist.c:1277); the four SYMBOL-level ones it missed are
# reachable on ordinary PDK symbols. A hand-maintained mirror of another
# module's rules is wrong by construction and had already drifted twice.
#
# SO THE NETLISTER IS THE ORACLE: run the netlist the design would actually
# simulate, read back which instances appear, emit cards only for those.
# lvs_ignore comes free, because the oracle runs under the user's own setting
# rather than a copy of it.
#
# ============================================================================
# ⚠ THE INDEX IS KEYED ON THE `.subckt` NAME, NOT ON `** sch_path:` (issue 0496)
# ============================================================================
# Attempt 4 keyed the deck index on each block's `** sch_path:` comment and
# resolved an instance's block with `xschem get_sch_from_sym`. MEASURED on
# sky130_tests_ase/tb_bandgap_opamp, the only shipped design with
# parameter-specialised subcircuits: the netlister synthesises `passgate_1` and
# `gain_stage2` (get_additional_symbols, actions.c:3729) and writes them as
# SEPARATE blocks that carry the SAME `** sch_path:` as `passgate` and
# `gain_stage`. The key merged each pair, 12 of the deck's 39 FETs got no card,
# and the tool reported success.
#
# So the key is the block NAME and the instance -> block edge is read off the
# instance's OWN element line in the deck: after joining `+` continuations, the
# callee is the last token BEFORE the first token containing `=`
# (`XM1 d g s b sky130_fd_pr__nfet_01v8 L=0.15 W=1` -> `sky130_fd_pr__nfet_01v8`;
# `x6 a b c passgate_1` -> `passgate_1`). Only the netlister's own call graph
# knows which block an instance calls (invariant I2b).
#
# ⚠ AND THE NAME KEY IS PAID FOR BY A GUARD. The netlister dedups blocks on
# get_cell() (spice_netlist.c:98-104), so two same-basename cells from different
# libraries share one block name. After every descend the callee block's
# recorded `** sch_path:` is compared with `xschem get schname`; a mismatch
# SUPPRESSES the subtree and warns, because over-emission is the raw-destroying
# direction (save.c RULING D5-1: a plausible wrong answer is worse than none).
#
# ⚠ AND IT NEEDS ONE MORE THING, MEASURED: re-keying is NECESSARY AND NOT
# SUFFICIENT. `schematic=passgate_1` makes `xschem descend` a CLASS-2 refusal
# (currsch already incremented, descend_error=load-failed) because the
# synthesised name resolves to a path that does not exist, and the
# "Descend into base schematic?" fallback (actions.c:4176) is gated by
# `has_x && fallback` while the descend VERB passes fallback=0. The deck already
# names the file exactly — the callee block's `** sch_path:` — so the walk hands
# it to the one-shot `hi_descend_view_path` override (actions.c:4139) that
# resolves THIS descend into THAT view without rewriting the instance.
#
# ============================================================================
# ⚠ TWO QUESTIONS, NOT ONE: `_netlisted` AND `_descendable` ARE NOT ALIASES
# ============================================================================
# Three of the seven classes drop the SUBTREE while the instance CALL survives
# in the deck. Measured on the S3 fixture, one deck, all seven visible:
#
#   class                       instance line   its .subckt block     descend?
#   spice_ignore=true           absent          -                     no
#   spice_ignore=short          absent          -                     no
#   only_toplevel=true (below)  absent          -                     no
#   empty/absent `format`       ABSENT          none at all           no
#   default_schematic=ignore    present         NO BLOCK AT ALL       no
#   spice_sym_def               present         a block, but NO
#                                               `** sch_path:`        no
#   spice_stop=true             present         `.subckt`/`.ends`,
#                                               EMPTY                 no
#
# "May I emit a card for this instance?" and "may I walk into it?" therefore
# have different answers on the same instance. Attempt 2 aliased them, and its
# own sabotage variant for that reddened nothing — on a FLAT fixture that could
# not reach the divergence. Per spec landmine 11 a predicted red that does not
# appear is a fixture defect, and that tell was ignored.
#
# ============================================================================
# ⚠ THE ORACLE'S NETLIST HAS SIDE EFFECTS, AND ONE OF THEM DELETES USER WORK
# ============================================================================
# `xschem netlist` calls leave_placement_for("Netlist") and
# leave_merge_for("Netlist") (scheduler.c:8848-8849) whose teardown IS a
# delete() (issue 0263), and neither is suppressible from Tcl. A read-only
# annotation menu item that ran a netlist would destroy the symbol the user is
# carrying on the cursor, or the paste they have not dropped. _assert_idle
# refuses instead.
#
# It also destroys the SELECTION (measured 1 -> 0), which is why the oracle runs
# ONCE at entry and never inside the walk: the walk drives descend by selection.
# And it sets xctx->netlist_name from the filename (scheduler.c:8796) and clears
# it at :8869, so a user's custom netlist name dies in any oracle run unless it
# is snapshotted — which is why _netlist_env covers what the run CHANGES rather
# than what we deliberately force.
#
# ============================================================================
# ⚠ I4, go_back AND THE AUTOSAVE BACKUP (issues 0495, 0626)
# ============================================================================
# `go_back` (actions.c:4766) calls `load_backup_as` (save.c:4191) whenever a
# `<cell>~.sch` sits beside the cell, and that function ends in `set_modify(1)`
# (save.c:4207). MEASURED on the SHIPPED sky130_tests_ase/bandgap_opamp, which
# ships with exactly such a `~`:
#
#     descend x1 ; go_back  ->  modified 0 -> 1     (autosave_backup 1)
#     descend x1 ; go_back  ->  modified 0 -> 0     (autosave_backup 0)
#
# and with a `~` whose CONTENT differs, a clean 73-instance buffer comes back as
# a 72-instance one. A read-only walk may not do that, so a CLEAN entry buffer is
# walked with `::autosave_backup` parked at 0 and the park is given back
# unconditionally in _restore (the same idiom wave_viewer.tcl:1467-1473 uses).
#
# ⚠ AND PARKING IS ONLY SAFE WHILE THE BUFFER IS CLEAN. Measured, same bench:
# with autosave_backup 0 and a genuinely MODIFIED parent, descend + go_back
# silently REVERTS the unsaved edit and still reports modified=1. That is issue
# 0626 — not op_annot's invention (`proc traversal`, both PDK prototypes and
# hierarchy_close all reach it) but this step's menu item is a new one-click way
# in, so save_cards REFUSES that combination rather than walking it.
#
# ============================================================================
# ⚠ I6, AND WHY EVERY EXIT PATH MEANS EVERY EXIT PATH
# ============================================================================
# The walk sets no_draw 1, no_undo 1, keep_symbols 1 and descends the REAL
# design. no_undo has no getter (issue 0432), so 0 is the only restorable value
# and a caller that wrapped this in its own `no_undo 1` is silently disarmed.
# The unwind is bounded by the ENTRY currsch and not by 0: `while {[xschem get
# currsch]} {xschem go_back}` (src/xschem.tcl's own idiom) would ascend past a
# caller who was already descended, and S4's render_deck is exactly such a
# caller.

## op_annot::last_warnings -> what the last save_cards could not do, as a list
## of one-line strings. Empty after a clean walk.
##
## ⚠ IT EXISTS BECAUSE SILENT UNDER-EMISSION IS THE FAILURE THAT SURVIVED 85 AND
## THEN 96 AND THEN 275 GREEN CHECKS. An alert per cell would be intolerable on
## a real sheet — mips_cpu/controller alone would fire twice — so the walk counts
## instead, and write_save_file puts the counts where the user is already looking.
proc op_annot::last_warnings {} {
  variable warnings
  return $warnings
}

## op_annot::last_counts -> what the last walk did NOT emit, as three named
## integers (issue 0497).
##
##   dropped_by_rule  a NETLISTER rule dropped it: spice_ignore, only_toplevel,
##                    lvs_ignore, an empty `format`, default_schematic=ignore,
##                    spice_sym_def, spice_stop. EXPECTED, and the only one of
##                    the three that may ever be called "normal for such cells".
##   not_found        the deck DOES contain the instance and the walk could not
##                    reach its block. THE 0496 CLASS. Never normal.
##   name_failed      devpath/devproc could not build a name: a raising devproc,
##                    a blank template, or the 0488 prefix guard.
##
## ⚠ THE SPLIT IS THE WHOLE POINT. Attempt 4 shipped ONE aggregate whose sentence
## ended `- normal for such cells`; on tb_bandgap_opamp it fired twice, the tool
## reported success, and 12 of 39 FETs had no card. A defect wearing the word
## "normal" is worse than no report at all.
proc op_annot::last_counts {} {
  variable _c_rule
  variable _c_notfound
  variable _c_name
  return [list dropped_by_rule $_c_rule not_found $_c_notfound \
               name_failed $_c_name]
}

## ============================================================================
## THE ORACLE SEAMS. EACH ONE IS A PROC BECAUSE EACH ONE CAN BE WRONG ON ITS OWN.
## ============================================================================

## Where the throwaway deck is written. A NAME, so a test can prove no temp file
## survives and can force the "no deck was written" path without a broken PDK.
##
## op_annot's OWN directory, never `$netlist_dir`: the user's netlist directory
## holds the deck they are about to simulate and a read-only menu item may not
## put a file next to it — nor may it inherit `local_netlist_dir`, which sends
## every write into `<design dir>/simulation/` (src/xschem.tcl:9008, measured).
proc op_annot::_oracle_dir {} {
  if {[info exists ::USER_CONF_DIR] && [string trim $::USER_CONF_DIR] ne {}} {
    return [file join $::USER_CONF_DIR op_annot]
  }
  if {[info exists ::env(HOME)] && [string trim $::env(HOME)] ne {}} {
    return [file join $::env(HOME) .xschem op_annot]
  }
  return [file join [pwd] .op_annot]
}

## Snapshot of every netlist global the oracle forces OR PERTURBS, INCLUDING
## whether it existed at all. Six entries of {name existed value}: four Tcl
## globals, then two pieces of C-side state read and written through
## `xschem get/set`.
##
## ⚠ `netlist_name` IS IN THIS LIST ALTHOUGH THE ORACLE NEVER FORCES IT, AND
## THAT IS THE POINT. `xschem netlist <file>` SETS xctx->netlist_name from the
## filename it was handed (scheduler.c:8796) and then, with erc==0 — which the
## oracle's netlist always is — CLEARS it (scheduler.c:8869). MEASURED: a user
## who typed a custom netlist name lost it to a read-only annotation click. A
## snapshot list covering only what we deliberately force is the wrong list —
## what matters is what the run CHANGES. I4's read-only discipline covers editor
## state and not only the .sch.
proc op_annot::_netlist_env {} {
  set snap {}
  foreach v {netlist_dir local_netlist_dir flat_netlist split_files} {
    if {[info exists ::$v]} {
      lappend snap [list $v 1 [set ::$v]]
    } else {
      lappend snap [list $v 0 {}]
    }
  }
  foreach v {netlist_type netlist_name} {
    if {[catch {xschem get $v} cv]} {
      lappend snap [list $v 0 {}]
    } else {
      lappend snap [list $v 1 $cv]
    }
  }
  return $snap
}

## Force the deck SHAPE the parser can read, and only that.
##
##   netlist_type spice   skip_instance() branches on xctx->netlist_type
##                        (netlist.c:1277) and a verilog/spectre deck has no
##                        `.subckt` blocks at all.
##   flat_netlist 0       flatten.awk (src/xschem.tcl:2274) rewrites the deck
##                        with NO `.subckt` and every device renamed and
##                        UPPERCASED, so a block index of it is meaningless.
##   split_files 0        sub-blocks would go to separate per-cell files.
##   local_netlist_dir 0  otherwise set_netlist_dir(1,dir) throws the requested
##                        directory away and writes into the DESIGN tree.
##
## ⚠ `lvs_ignore` IS DELIBERATELY NOT HERE. It is different in kind: it changes
## which devices the user's OWN run will contain, so forcing it would emit cards
## for devices their deck drops. Read it, never write it — and the oracle reads
## it for free by simply running the netlist under the user's own setting.
proc op_annot::_force_netlist_env {dir} {
  set ::netlist_dir $dir
  set ::local_netlist_dir 0
  set ::flat_netlist 0
  set ::split_files 0
  catch {xschem set netlist_type spice}
  return {}
}

## THE ONE RESTORER of the forced netlist environment, on every path out of the
## oracle — including the one where the netlist could not be written at all.
proc op_annot::_restore_netlist_env {snap} {
  foreach row $snap {
    set v   [lindex $row 0]
    set had [lindex $row 1]
    set val [lindex $row 2]
    ## The C-side pair. `xschem set netlist_name {}` is a real restore, not a
    ## no-op: an EMPTY name is the tree's own "use the default" state and a
    ## restore that skipped it would fabricate a name the user never typed.
    if {$v eq {netlist_type} || $v eq {netlist_name}} {
      if {$had} { catch {xschem set $v $val} }
      continue
    }
    if {$had} {
      catch {set ::$v $val}
    } else {
      catch {unset ::$v}
    }
  }
  return {}
}

## Can this directory hold the throwaway deck at all?  A NAMED SEAM, and it is
## checked BEFORE `xschem netlist` is ever issued.
##
## ⚠ THE REASON IS A MODAL DIALOG NO FLAG REACHES. `xschem netlist <path>` with
## a slash in it goes through set_netlist_dir(1, <dirname>), and a failing
## `file mkdir` THERE pops a raw `tk_messageBox` (src/xschem.tcl:9039, and :9001
## for the what==0 arm) that `-noalert` does not touch and that names a
## directory the USER NEVER CHOSE.
##
## `file writable` on the DIRECTORY, not a probe write: a probe would leave a
## file behind on the path where the whole point is that nothing is left behind.
proc op_annot::_oracle_dir_ready {dir} {
  catch {file mkdir $dir}
  if {![file isdirectory $dir]} { return 0 }
  if {![file writable $dir]}    { return 0 }
  return 1
}

## THE ONE PLACE the oracle's netlist is issued. A proc of its own so the "the
## netlist ran and wrote nothing" branch below stays reachable from a test.
##
## `-keep_symbols` for the same reason xschem.tcl's own machinery passes it:
## this netlist is a READ, not the user's netlist verb. It also keeps the branch
## from self-logging (scheduler.c:8887), a seam this module DEPENDS ON and does
## NOT OWN — its guardians are tests/headless/test_netlist_log.tcl:150-157.
##
## `-noalert` because this netlist is INVISIBLE to the user.
##
## ⚠ NEVER RAISES, AND ITS RETURN VALUE IS NOT A FAILURE SIGNAL. Measured, the
## verb answers 1 for an unconnected net and for a `spice_sym_def` with no
## matching `.subckt`, both of which still write a complete deck. The ONLY
## failure test is whether a deck file exists, which is the caller's.
proc op_annot::_oracle_run {out} {
  if {[catch {xschem netlist -keep_symbols -noalert $out} nres]} {
    set nres "raised: $nres"
  }
  return $nres
}

## Run the netlist the design would actually simulate FROM WHERE WE STAND, and
## return the deck as text. RAISES when no deck was written.
##
## ⚠ IT NEVER RETURNS {} ON FAILURE. An empty answer would build an empty index,
## find no instance in it, emit zero cards and report success — indistinguishable
## from "no PDK descriptor claims anything here".
proc op_annot::_oracle_deck {} {
  set dir [::op_annot::_oracle_dir]
  set out [file join $dir "op_annot_oracle_[pid].spice"]
  set snap [::op_annot::_netlist_env]
  set body {}
  set rc [catch {
    ## ⚠ PRE-CHECKED, NOT ATTEMPTED. An unwritable/unmakeable oracle directory
    ## must reach the user as THIS proc's named diagnostic, not as
    ## `can't create directory …: not a directory` from a Tcl primitive three
    ## frames down and NOT as set_netlist_dir's modal tk_messageBox naming a
    ## directory the user never chose (see _oracle_dir_ready).
    if {![::op_annot::_oracle_dir_ready $dir]} {
      error "op_annot: the netlist ORACLE has nowhere to write. \"$dir\" is not\
 a writable directory. The save block is not generated rather than generated\
 empty: a card for a device the deck does not contain makes ngspice write no\
 raw file at all."
    }
    catch {file delete -force $out}
    ::op_annot::_force_netlist_env $dir
    ## THE NETLIST, through its own named seam (see _oracle_run above).
    set nres [::op_annot::_oracle_run $out]
    if {![file isfile $out]} {
      error "op_annot: the netlist ORACLE wrote no deck to \"$out\"\
 (xschem netlist answered \"$nres\"). The save block is not generated rather\
 than generated empty: a card for a device the deck does not contain makes\
 ngspice write no raw file at all."
    }
    set fh [open $out r]
    set body [read $fh]
    close $fh
  } res opts]
  catch {file delete -force $out}
  ::op_annot::_restore_netlist_env $snap
  if {$rc} { return -options $opts $res }
  return $body
}

## THE ONE PATH NORMALIZER, used on BOTH sides of every comparison.
##
## `regsub {\(.*}` then `abs_sym_path` is the Tcl twin of the C's
## sanitized_abs_sym_path (actions.c:473) — a generator cell is spelled
## `foo(a,b)` and its path is `foo`. `file normalize` on top of it is not
## belt-and-braces: measured, a symbol placed as `../lib/psub.sym` resolves to
## `…/lib/../lib/psub.sch` while the deck's `** sch_path:` says `…/lib/psub.sch`,
## and abs_sym_path alone does NOT collapse the `..`.
##
## ⚠ MEMOISED, AND THE MEMO IS CLEARED AT save_cards ENTRY (issue 0493). The
## memo may NOT outlive one walk: XSCHEM_LIBRARY_PATH is user state and
## abs_sym_path resolves against it, so a memo that survived would serve a stale
## absolute path after a library-path change. Row W33 is the guardian.
proc op_annot::_normkey {p} {
  variable _nkmemo
  if {[string trim $p] eq {}} { return {} }
  if {[info exists _nkmemo($p)]} { return $_nkmemo($p) }
  regsub {\(.*} [string trim $p] {} q
  if {[catch {abs_sym_path $q {}} r]} { set r $q }
  if {[string trim $r] eq {}} { set r $q }
  if {[catch {file normalize $r} n]} { set n $r }
  set _nkmemo($p) $n
  return $n
}

## The parser's ONE hand-written rule, kept in its own proc so it can be named
## in a sabotage variant: is the parser inside the deck's user-architecture
## region after this line?
##
## ⚠ ITS FALSE-POSITIVE DIRECTION IS THE DANGEROUS ONE, AND IT IS MEASURED. A
## `code_shown` / `netlist_commands` symbol puts the user's own literal text
## INSIDE the enclosing block, between `**** begin user architecture code` and
## `**** end user architecture code`. A symbol whose value is the line
## `MGHOST net1 net2 net3 net4 nch` would otherwise be read as proof that an
## instance named MGHOST — carrying `spice_ignore=true` and nowhere in the deck
## — is present, and the walk would emit cards for it.
##
## ⚠ THE PATTERNS ARE ANCHORED AND THE `*`s ARE ESCAPED. Written as
## `string match {****begin*}` every `*` is a WILDCARD, so the pattern means
## "any line containing begin" and the `end` twin then swallows `.ends`, leaving
## the previous block open.
proc op_annot::_deck_user_region {line inside} {
  if {[string match {\*\*\*\* begin user architecture*} $line]} { return 1 }
  if {[string match {\*\*\*\* end user architecture*} $line]}   { return 0 }
  return $inside
}

## The callee of one deck ELEMENT LINE: the last token BEFORE the first token
## containing `=`, after `+` continuations have been joined by the caller.
##
##   x6 a b c passgate_1                       -> passgate_1
##   XM1 d g s b sky130_fd_pr__nfet_01v8 L=1 W=2  -> sky130_fd_pr__nfet_01v8
##   MT0 net1 net2 net3 net4 nch               -> nch
##
## ⚠ IT IS NOT "THE LAST TOKEN". Every PDK element line ends in a parameter
## assignment, which is why attempt 4's oracle could not read a real deck's call
## graph at all and had to ask `get_sch_from_sym` instead — the question that
## issue 0496 answered wrong.
proc op_annot::_line_callee {toks} {
  set callee {}
  for {set i 1} {$i < [llength $toks]} {incr i} {
    if {[string first {=} [lindex $toks $i]] >= 0} { break }
    set callee [lindex $toks $i]
  }
  return [string tolower $callee]
}

## The deck, as a dict with four keys:
##   top      the deck's FIRST `.subckt` name — the netlister always writes the
##            block for the cell you netlisted first (spice_netlist.c:369-372),
##            `**`-prefixed when top_is_subckt is 0
##   elems    block -> list of lowercased element names, in deck order
##   callee   block -> (element -> the block that element calls)
##   schpath  block -> its `** sch_path:` comment, {} when it has none
##
## A block that exists and is EMPTY is a key with an empty list — that is how
## `spice_stop` shows up. A block with elements and NO `** sch_path:` is how
## `spice_sym_def` shows up (the body is attribute TEXT, not an expanded cell).
## Both are "the deck holds the call and not the body".
##
## Line classes, all measured on real decks: `* expanding   symbol:` resets the
## pending sch_path, `**`-prefixed top-block delimiters are the same
## `.subckt`/`.ends` after the marker is stripped, `*` comments and `.` dot-cards
## are not elements, and `+` continuations are JOINED onto the previous line
## before anything else (break.awk splits element lines over 130 chars, and an
## unjoined continuation would hide the `=` that stops _line_callee).
proc op_annot::_deck_index {text} {
  set elems   {}
  set callee  {}
  set schpath {}
  set top     {}
  set cur     {}
  set pending {}
  set inuser  0
  ## Join `+` continuations first — the callee rule reads a whole element line.
  set lines {}
  foreach raw [split $text "\n"] {
    set t [string trim $raw]
    if {$t eq {}} { continue }
    if {[string index $t 0] eq {+} && [llength $lines]} {
      lset lines end "[lindex $lines end] [string trim [string range $t 1 end]]"
      continue
    }
    lappend lines $t
  }
  foreach t $lines {
    set inuser [::op_annot::_deck_user_region $t $inuser]
    ## ⚠ THE REGION TEST RUNS BEFORE THE `.subckt`/`.ends` TESTS, NOT AFTER
    ## THEM. A `code_shown` / `netlist_commands` symbol may put a COMPLETE
    ## `.subckt`/`.ends` pair inside the user-architecture region — a helper
    ## subcircuit is ordinary practice — and with this line below the delimiter
    ## tests that inner `.ends` ran `set cur {}` and EVERY ELEMENT AFTER IT IN
    ## THE ENCLOSING BLOCK was silently dropped.
    ##
    ## REJECTED: a `.subckt` nesting-depth counter. A `.subckt` inside a user
    ## region is not nesting, it is opaque user text the netlister never
    ## expands, so a depth model would be modelling a structure that does not
    ## exist.
    if {$inuser} { continue }
    if {[regexp {^\*\* sch_path:[ \t]*(.*)$} $t -> p]} {
      set pending [string trim $p]
      continue
    }
    if {[string match {\* expanding*} $t]} { set pending {} ; set cur {} ; continue }
    ## the deck top is `**.subckt` / `**.ends`; everything below it is bare.
    set d $t
    if {[string range $d 0 1] eq {**}} { set d [string trim [string range $d 2 end]] }
    if {[regexp -nocase {^\.subckt[ \t]+([^ \t]+)} $d -> nm]} {
      set cur [string tolower $nm]
      if {$top eq {}} { set top $cur }
      if {![dict exists $elems $cur]} { dict set elems $cur {} }
      if {![dict exists $callee $cur]} { dict set callee $cur {} }
      dict set schpath $cur $pending
      set pending {}
      continue
    }
    if {[regexp -nocase {^\.ends} $d]} { set cur {} ; set pending {} ; continue }
    if {$cur eq {}} { continue }
    set c [string index $t 0]
    if {$c eq {*} || $c eq {.}} { continue }
    ## ⚠ split/foreach, NOT `lindex`: a deck line is not a Tcl list and an
    ## unbalanced brace or quote in a parameter would make lindex raise mid-parse.
    set toks {}
    foreach w [split $t] { if {$w ne {}} { lappend toks $w } }
    if {![llength $toks]} { continue }
    set nm [string tolower [lindex $toks 0]]
    dict lappend elems $cur $nm
    set m [dict get $callee $cur]
    dict set m $nm [::op_annot::_line_callee $toks]
    dict set callee $cur $m
  }
  return [dict create top $top elems $elems callee $callee schpath $schpath]
}

## The deck block the walk is standing in when it has not been told — the deck's
## own top. Every recursive call threads the callee block down instead, which is
## what makes the index name-keyed rather than path-keyed (issue 0496).
proc op_annot::_block_or_top {idx block} {
  if {[string trim $block] ne {}} { return $block }
  if {[catch {dict get $idx top} t]} { return {} }
  return $t
}

## The instance's identity IN THE DECK: `@spiceprefix@name`, lowercased.
##
## ⚠ `xschem translate`, NEVER `getprop instance <n> spiceprefix`. getprop reads
## inst->prop_ptr only, so it is EMPTY whenever the token lives in the symbol
## `template=` — issue 0430, and the reason both PDK prototypes lose the leading
## `x` on 3 of 45 shipped sky130 cells.
##
## These are the same two tokens every descriptor's devpath already
## concatenates, which is what makes the membership test and the CARD agree by
## construction.
proc op_annot::_element {instname} {
  if {[catch {xschem translate $instname {@spiceprefix@name}} e]} { return {} }
  return [string tolower [string trim $e]]
}

## Every element name ONE instance can appear under in the deck.
##
## ⚠ A VECTOR INSTANCE IS THE ORACLE'S FIRST TRAP. The netlister writes one
## element line PER MEMBER (`x2[1]`, `x2[0]`) while the instance's own name is
## the bracketed RANGE `x2[1:0]`, which appears in the deck nowhere. A bare
## comparison answers 0 for every vector instance and the walk then refuses to
## descend into it — a plausible-looking short block with nothing to say so.
proc op_annot::_elements {instname} {
  set e [::op_annot::_element $instname]
  if {$e eq {}} { return {} }
  if {[string first {[} $e] < 0} { return [list $e] }
  if {[catch {xschem expandlabel $e} x]} { return [list $e] }
  set names [lindex [split $x { }] 0]
  set out {}
  foreach n [split $names {,}] {
    if {[string trim $n] ne {}} { lappend out [string tolower [string trim $n]] }
  }
  if {[llength $out] == 0} { return [list $e] }
  return $out
}

## Is instance <i> in the deck, i.e. may it have a save card?
## <idx> is op_annot::_deck_index's answer, passed as a VALUE rather than read
## from a hidden armed variable so a test can put the truth table on the page.
## <block> is the deck block the walk is standing in; {} means the deck's top.
proc op_annot::_netlisted {i idx {block {}}} {
  if {[catch {xschem getprop instance $i name} nm]} { return 0 }
  set b [::op_annot::_block_or_top $idx $block]
  if {$b eq {}} { return 0 }
  if {[catch {dict get $idx elems} el]} { return 0 }
  if {![dict exists $el $b]} { return 0 }
  set have [dict get $el $b]
  foreach e [::op_annot::_elements $nm] {
    if {[lsearch -exact $have $e] >= 0} { return 1 }
  }
  return 0
}

## Which deck block does instance <i> CALL?  Read off its own element line, not
## re-derived from the symbol — see the name-key block in this section's header.
## {} when the instance is not in the deck or its callee is not a block.
proc op_annot::_callee {i idx {block {}}} {
  if {[catch {xschem getprop instance $i name} nm]} { return {} }
  set b [::op_annot::_block_or_top $idx $block]
  if {$b eq {}} { return {} }
  if {[catch {dict get $idx callee} cm]} { return {} }
  if {![dict exists $cm $b]} { return {} }
  set m [dict get $cm $b]
  if {[catch {dict get $idx elems} el]} { return {} }
  foreach e [::op_annot::_elements $nm] {
    if {![dict exists $m $e]} { continue }
    set c [dict get $m $e]
    if {$c eq {}} { continue }
    if {[dict exists $el $c]} { return $c }
  }
  return {}
}

## May the walk DESCEND into instance <i>?  NOT an alias of _netlisted — see the
## two-questions block in this section's header.
##
## Three things must all hold: the instance is in the deck, its callee names a
## block, and that block is one the netlister EXPANDED — non-empty AND carrying
## its own `** sch_path:`. `spice_stop` fails the first half (a real block,
## emitted empty) and `spice_sym_def` the second (attribute text, `** sym_path:`
## only), and both are measured in the table above.
proc op_annot::_descendable {i idx {block {}}} {
  if {![::op_annot::_netlisted $i $idx $block]} { return 0 }
  set c [::op_annot::_callee $i $idx $block]
  if {$c eq {}} { return 0 }
  if {[catch {dict get $idx elems} el]} { return 0 }
  if {![dict exists $el $c]} { return 0 }
  if {[llength [dict get $el $c]] == 0} { return 0 }
  if {[catch {dict get $idx schpath} sp]} { return 0 }
  if {![dict exists $sp $c]} { return 0 }
  if {[string trim [dict get $sp $c]] eq {}} { return 0 }
  return 1
}

## The last component of `xschem get sch_path`, lowercased — the string the deck
## basis will really put in front of every card built below this level. Shared
## by _prefix_ok and by its warning so the two cannot disagree about what was
## compared.
proc op_annot::_pathseg {} {
  if {[catch {xschem get sch_path} p]} { return {} }
  set seg [string trimright $p {.}]
  set i [string last {.} $seg]
  if {$i >= 0} { set seg [string range $seg [expr {$i + 1}] end] }
  return [string tolower $seg]
}

## Does the hierarchy path we now stand on still SPELL this instance the way the
## deck does?  (issue 0488)
##
## ⚠ MEASURED, AND IT IS THE RAW-DESTROYING SHAPE. `sch_path`, `sim_sch_path`
## and translate's `@path` all carry the instance NAME ONLY and DROP
## `spiceprefix`. With `name=SUB1 spiceprefix=X` on a subcircuit symbol the deck
## writes `XSUB1` while all three path sources answer `SUB1.`, so every card
## below would say `@m.sub1.<inner>` against a raw holding `@m.xsub1.<inner>` —
## EVERY card in that subtree bogus, which is the all-bogus case that makes
## ngspice write no raw file at all.
##
## So the subtree is SUPPRESSED and named, not emitted and hoped for: save.c
## RULING D5-1 — a plausible wrong number on a schematic is worse than none —
## and a plausible wrong CARD is worse still, because it takes the whole raw
## with it. Mitigation and not a fix, hence issue 0488: zero of the 533 shipped
## `type=subcircuit` symbols carry spiceprefix.
##
## ⚠ IT TAKES THE ELEMENT LIST, IT DOES NOT LOOK IT UP. By the time this runs
## the hierarchy has ALREADY moved, and `xschem translate SUB1 @spiceprefix@name`
## in the CHILD cell has no instance called SUB1 to translate. The caller reads
## `_elements` BEFORE descending and threads it down.
proc op_annot::_prefix_ok {els} {
  if {[llength $els] == 0} { return 1 }
  set seg [::op_annot::_pathseg]
  if {$seg eq {}} { return 1 }
  return [expr {[lsearch -exact $els $seg] >= 0}]
}

## Refuse while a modal gesture is pending (I4).
##
## ⚠ THIS IS THE SHARPEST SEAM OF THE ORACLE INVERSION. `xschem netlist` calls
## leave_placement_for("Netlist") and leave_merge_for("Netlist")
## (scheduler.c:8848-8849) whose teardown IS a delete() (issue 0263), and
## neither is suppressible from Tcl. Masks are
## START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT (25600) and STARTMERGE (256), i.e.
## exactly leave_placement_for()'s and leave_merge_for()'s own tests
## (callback.c:706, :433). Numeric literals are this tree's established Tcl
## idiom for ui_state (src/xschem.tcl:6558/11000/11394, create_instance.tcl:38).
proc op_annot::_assert_idle {} {
  if {[catch {xschem get ui_state} st]} { return {} }
  if {![string is integer -strict $st]} { return {} }
  if {$st & 25600} {
    return -code error "op_annot::save_cards: a symbol/text PLACEMENT is\
 pending. This walk runs a netlist to find out which devices are in the deck,\
 and the netlister tears a pending placement down (issue 0263). Drop or cancel\
 it (Esc) first."
  }
  if {$st & 256} {
    return -code error "op_annot::save_cards: a PASTE/merge is pending. This\
 walk runs a netlist to find out which devices are in the deck, and the\
 netlister tears a pending paste down (issue 0263). Drop or cancel it (Esc)\
 first."
  }
  return {}
}

## Refuse to walk a sheet whose UNSAVED edits the walk would silently revert
## (issue 0626). MEASURED on sky130_tests_ase/bandgap_opamp:
##
##   autosave_backup 1, modified 1 : descend + go_back keeps the edit
##   autosave_backup 0, modified 1 : descend + go_back REVERTS it, and the
##                                   buffer still reports modified 1
##
## The revert is silent and it is data loss, so this is a refusal and not a
## warning: the user can save (or turn autosave_backup back on) and click again,
## and nothing in the annotation feature is worth an unsaved edit.
proc op_annot::_assert_saveable {} {
  if {[catch {xschem get modified} m]} { return {} }
  if {![string is integer -strict $m] || !$m} { return {} }
  set ab 1
  if {[info exists ::autosave_backup]} { set ab $::autosave_backup }
  if {[string is integer -strict $ab] && !$ab} {
    return -code error "op_annot::save_cards: this schematic has UNSAVED edits\
 and `autosave_backup` is off. The walk descends and returns, and with no\
 autosave backup to come back to that round trip silently REVERTS unsaved edits\
 (issue 0626). Save the schematic, or turn Options > Autosave backup on, and\
 click again."
  }
  return {}
}

## Park `::autosave_backup` for the walk and return the snapshot _restore needs.
##
## THE WALK IS READ-ONLY (I4) AND go_back IS NOT. With a `<cell>~.sch` beside the
## cell, go_back loads the BACKUP's content into the parent buffer and flags it
## modified (save.c:4191-4207) — measured on the shipped bandgap_opamp, where a
## clean 73-instance buffer came back as a 72-instance one. Parking the flag at 0
## makes load_backup_as return early (save.c:4197) and the ascent a plain reload
## of the on-disk cell.
##
## ⚠ ONLY WHEN THE ENTRY BUFFER IS CLEAN. On a modified buffer the `~` is where
## the unsaved edits LIVE, and parking would throw them away — which is why
## _assert_saveable refuses that combination outright rather than parking it.
proc op_annot::_park_backup {} {
  set had 0
  set val {}
  if {[info exists ::autosave_backup]} { set had 1 ; set val $::autosave_backup }
  if {[catch {xschem get modified} m]} { set m 1 }
  if {[string is integer -strict $m] && !$m} { set ::autosave_backup 0 }
  return [list $had $val]
}

## Is this instance one a descriptor CLAIMS?  i.e. would a card be owed if the
## netlister had kept it?  Used only to decide whether a drop is worth counting:
## a wire, a pin or an unregistered symbol type is not an under-emission.
proc op_annot::_claims {instname} {
  set t [::op_annot::type $instname]
  if {$t eq {}} { return 0 }
  set d [::op_annot::descriptor $t]
  if {$d eq {}} { return 0 }
  if {![dict exists $d params]} { return 0 }
  if {![llength [dict get $d params]]} { return 0 }
  return [::op_annot::_matches $instname $d]
}

## The cards for ONE instance, or {} when it contributes none.
##
## ⚠ THE 0425 CONSUMER CONTRACT (see the header): skip on a blank DEVPATH, never
## on a blank DESCRIPTOR. A descriptor whose `match` globs do not claim this
## cell is still fully registered; emitting its params against an empty device
## name would write `.save [id]` cards.
##
## ⚠ `deck` BASIS, ALWAYS (issue 0436). The root is threaded from save_cards'
## entry level; nothing here does path arithmetic of its own.
##
## ⚠ THE CARD IS BARE — `[devpath][param]`, never op_annot::vector (rule R4).
## Re-measured on ngspice 46+: `.save i(@m.xm1.m1[id])` puts NOTHING in the raw
## and says nothing, because ngspice applies the i()/v() wrapper ITSELF from the
## parameter's own type. `vector` is the READ shape and belongs to S5.
##
## ⚠ NO CATCH. devpath returns {} for every DATA condition, so anything that
## raises in here is a caller bug or a broken PDK three levels down, and I6's
## whole point is that such a raise reaches save_cards' restore.
##
## ⚠ ALL `params`, NOT THE SIX-ROW DISPLAY CAP (RULING D9b, spec §4.2b). The cap
## is applied inside op_annot::text AFTER the three row classes are assembled,
## i.e. it is a DISPLAY decision; a user who raises ::op_annot_max_rows would
## otherwise get blank rows with no way to re-simulate for them. On every shipped
## descriptor the two sets coincide.
##
## `derived` and `pinexpr` are not iterated: neither has a vector in any raw
## (spec §4.3). `derived` is computed from params after they are read, `pinexpr`
## is an expression over pin voltages, which `save all` already carries.
proc op_annot::_cards_for {instname root} {
  set t [::op_annot::type $instname]
  if {$t eq {}} { return {} }
  set d [::op_annot::descriptor $t]
  if {![dict exists $d params]} { return {} }
  set dev [::op_annot::devpath $instname deck $root]
  if {$dev eq {}} { return {} }
  set out {}
  foreach row [dict get $d params] {
    lappend out ".save ${dev}\[[lindex $row 1]\]"
  }
  return $out
}

## Did the descend just issued actually land us in a USABLE child?
## <c0> is `xschem get currsch` from immediately BEFORE the descend.
##
## THIS IS THE CLASS SPLIT OF ISSUE 0433. The return value of `xschem descend`
## is deliberately not consulted: it is 0 for both classes.
##   currsch unchanged  -> class 1, nothing was pushed. NO go_back — the
##                         prototypes' unconditional one pops a caller's level
##                         and the walk then re-visits levels, emitting
##                         duplicate cards.
##   currsch advanced, descend_error set -> class 2 (`load-failed`,
##                         actions.c:4636, which returns AFTER the increment at
##                         :4628): the hierarchy ALREADY advanced, so this one
##                         DOES owe a go_back before the walk can continue.
##   currsch advanced, descend_error empty -> success.
proc op_annot::_descended {c0} {
  if {[catch {xschem get currsch} c1]} { return 0 }
  if {$c1 <= $c0} { return 0 }
  if {[catch {xschem get descend_error} derr]} { set derr {} }
  if {$derr eq {}} { return 1 }
  catch {xschem go_back 2}
  return 0
}

## Descend into instance <i>, resolving the target from the DECK rather than from
## the symbol's `schematic=` attribute (issue 0496).
##
## ⚠ WHY THE OVERRIDE. `get_additional_symbols` (actions.c:3729) synthesises
## `passgate_1` / `gain_stage2` for parameter-specialised instances and the deck
## block carries the BASE cell's `** sch_path:`. `xschem descend` on such an
## instance is a CLASS-2 refusal — currsch already incremented,
## descend_error=load-failed — because the synthesised name resolves to a file
## that does not exist, and the "Descend into base schematic?" fallback
## (actions.c:4176) is unreachable from the verb (fallback=0). The deck already
## names the file; `hi_descend_view_path` (actions.c:4139) is the tree's own
## one-shot seam for exactly this, and it does NOT rewrite or dirty the instance.
##
## ⚠ ONE-SHOT AND ALWAYS CLEARED. get_sch_from_sym blanks it on use, but a
## descend that never reaches that call would leave it armed for the NEXT one —
## which is a wrong-cell descend with no error anywhere.
proc op_annot::_descend_to {i n view} {
  ## `xschem select instance <i>` TOGGLES, and go_back leaves the instance we
  ## came from selected — so unselect first or the next descend refuses with
  ## `no-selection` / picks the wrong target. `fast nodraw` is
  ## src/xschem.tcl:3717's cheaper form: no status traffic, no selection draw.
  catch {xschem unselect_all}
  catch {xschem select instance $i fast nodraw}
  if {[string trim $view] ne {}} { catch {set ::hi_descend_view_path $view} }
  set rc [catch {xschem descend $n 2} res opts]
  catch {set ::hi_descend_view_path {}}
  if {$rc} { return -options $opts $res }
  return $res
}

## Is the cell we just descended into the one the deck block says it is?  (D2b)
##
## The netlister dedups blocks on get_cell() (spice_netlist.c:98-104), so two
## same-basename cells from different libraries share ONE block name and a
## name-keyed index alone would attribute one cell's devices to the other. This
## is the guard that pays for the name key: both sides normalized through the one
## `_normkey`, and a mismatch suppresses rather than emits.
proc op_annot::_block_is_here {idx callee} {
  if {[catch {dict get $idx schpath} sp]} { return 1 }
  if {![dict exists $sp $callee]} { return 1 }
  set want [string trim [dict get $sp $callee]]
  if {$want eq {}} { return 1 }
  if {[catch {xschem get schname} here]} { return 1 }
  if {[string trim $here] eq {}} { return 1 }
  return [expr {[::op_annot::_normkey $want] eq [::op_annot::_normkey $here]}]
}

## The recursion. Ported from sg13g2_hier_sch_expand (sg13g2_procs.tcl:366-421).
## Appends to the namespace accumulator; a raise anywhere inside it is caught
## exactly once, by save_cards.
##
## <root>  is the walk's ENTRY sch_path, threaded down unchanged: it is the basis
##         every card is rooted at.
## <idx>   is the deck index, built ONCE by save_cards — one netlist per call,
##         never one per instance.
## <block> is the DECK BLOCK this level corresponds to, threaded down from each
##         instance's own element line. That thread is issue 0496's fix: nothing
##         here re-derives a block from a cell path.
proc op_annot::_walk {root idx block} {
  variable _acc
  variable warnings
  variable _c_rule
  variable _c_notfound
  variable _c_name
  set ninstances [xschem get instances]
  for {set i 0} {$i < $ninstances} {incr i} {
    set instname [xschem getprop instance $i name]
    ## ⚠ `getprop instance <n> cell::type`, NOT `getprop symbol <cell> type`.
    ## The symbol form RAISES for generator cells (measured: 6 of the 14
    ## instances of xschem_library/generators/test_generators.sch) and is the
    ## literal trigger of issue 0431. The index form resolves for a vector
    ## instance name too.
    set type [::op_annot::type $i]
    set netl [::op_annot::_netlisted $i $idx $block]

    ## Emit BEFORE descending: depth-first, parents before children. Order is
    ## part of this step's golden. A device the deck does not contain gets no
    ## card and is COUNTED — silence there is how two attempts shipped.
    if {$netl} {
      if {[::op_annot::_claims $instname]} {
        set cards [::op_annot::_cards_for $instname $root]
        if {[llength $cards]} {
          foreach c $cards { lappend _acc $c }
        } else {
          incr _c_name
          ::op_annot::_warn "no device name could be built for $instname (its\
 descriptor claims the cell but devpath/devproc answered nothing); no cards\
 emitted for it"
        }
      }
    } elseif {[::op_annot::_claims $instname]} {
      incr _c_rule
    }

    if {$type ne {subcircuit}} { continue }

    ## The deck may hold the CALL and not the body (spice_stop, spice_sym_def,
    ## default_schematic=ignore), and it may not hold the instance at all
    ## (spice_ignore, only_toplevel, an empty format). Both are "do not walk in",
    ## and both are a NETLISTER RULE, not a defect (issue 0497).
    if {![::op_annot::_descendable $i $idx $block]} { incr _c_rule ; continue }
    set callee [::op_annot::_callee $i $idx $block]

    ## ⚠ READ BEFORE DESCENDING. Once the walk is in the child, `xschem
    ## translate <instname> …` has no such instance to resolve (see _prefix_ok).
    set els [::op_annot::_elements $instname]
    set view {}
    if {![catch {dict get $idx schpath} sp]} {
      if {[dict exists $sp $callee]} { set view [string trim [dict get $sp $callee]] }
    }

    ## Vector instances: `expandlabel x2[1:0]` -> `x2[1],x2[0] 2` (never raises,
    ## answers `x1 1` for a scalar). Descend ONCE, then walk the members with
    ## change_sch_path, then go_back ONCE.
    set ninst [lindex [split [xschem expandlabel $instname] { }] 1]
    for {set n 1} {$n <= $ninst} {incr n} {
      if {$n == 1} {
        set c0 [xschem get currsch]
        ::op_annot::_descend_to $i $n $view
        if {[catch {xschem get descend_error} derr]} { set derr {} }
        if {![::op_annot::_descended $c0]} {
          ## The deck HAS this block and the walk could not reach it. That is
          ## the 0496 class and it is never "normal" (issue 0497).
          incr _c_notfound
          ::op_annot::_warn "the netlist expands $instname into block\
 \"$callee\" but the walk could not descend into it ($derr); no cards emitted\
 below it"
          break
        }
        ## The name key is only safe with this guard — see _block_is_here.
        if {![::op_annot::_block_is_here $idx $callee]} {
          incr _c_notfound
          ::op_annot::_warn "the cell reached through $instname is not the one\
 the deck block \"$callee\" was written from (two same-named cells from\
 different libraries share one .subckt block); no cards emitted below it"
          catch {xschem go_back 2}
          break
        }
      }
      if {$n > 1} { xschem change_sch_path $n }
      ## ⚠ THE PREFIX GUARD (issue 0488) SITS BETWEEN THE DESCEND AND THE
      ## RECURSION, INSIDE THE go_back PAIRING. Suppressing the subtree may not
      ## also suppress the ascent: an early `break` here would leave the walk a
      ## level down for every remaining instance of the parent.
      if {[::op_annot::_prefix_ok $els]} {
        ::op_annot::_walk $root $idx $callee
      } else {
        incr _c_name
        ::op_annot::_warn "cannot name the subtree of $instname: the hierarchy\
 path spells it \"[::op_annot::_pathseg]\" but the netlist element is\
 \"[join $els {, }]\" (sch_path does not carry spiceprefix - issue 0488). No\
 cards emitted below it."
      }
      if {$n == $ninst} { xschem go_back 2 }
    }
  }
  return 1
}

## Append a warning, once. A 500-device block would otherwise repeat one cell's
## sentence per instance and bury the others.
proc op_annot::_warn {w} {
  variable warnings
  if {[lsearch -exact $warnings $w] < 0} { lappend warnings $w }
  return {}
}

## Ascend back to the level the walk started from — and NO FURTHER.
##
## Bounded by the ENTRY currsch, not by 0 (see I6 in this section's header). The
## guards are because this runs on an unattended error path: a go_back that
## refuses to move must break the loop rather than spin it forever.
proc op_annot::_unwind {entry} {
  set target [lindex $entry 0]
  set guard 0
  while {1} {
    if {[catch {xschem get currsch} c]} { break }
    if {$c <= $target} { break }
    if {[catch {xschem go_back 2}]} { break }
    if {[catch {xschem get currsch} c2]} { break }
    if {$c2 >= $c} { break }
    if {[incr guard] > 64} { break }
  }
}

## THE UNCONDITIONAL RESTORE (I6). Every line is individually catch-wrapped so
## one failure cannot skip the rest — the prototypes' straight-line reset is
## simply not reached when the walk raises, which is issue 0431. The shape is
## core `proc traversal`'s (src/xschem.tcl:3590-3612, issue 0600) plus two things
## it does not need: the log-suppress pop and the autosave park.
##
## ⚠ THE UNWIND RUNS FIRST, WHILE THE PARK IS STILL IN FORCE. Restoring
## `autosave_backup` before ascending would put the go_back-loads-the-backup
## behaviour back exactly where the walk still has levels to pop, which is the
## defect the park exists to prevent (issue 0495).
##
## <rc> is the catch code of the walk. It is deliberately NOT branched on: the
## whole point is that this block runs identically on both paths. The netlist
## environment is NOT restored here — the oracle gives it back itself, before
## the walk ever starts, so it is already the user's during the walk.
proc op_annot::_restore {entry rc} {
  variable _busy
  catch {::op_annot::_unwind $entry}
  ## no_undo has no getter (issue 0432), so 0 is the only restorable value.
  catch {xschem set no_undo 0}
  catch {xschem set no_draw [lindex $entry 2]}
  catch {set ::keep_symbols [lindex $entry 3]}
  set park [lindex $entry 4]
  if {[lindex $park 0]} {
    catch {set ::autosave_backup [lindex $park 1]}
  } else {
    catch {unset ::autosave_backup}
  }
  catch {set ::hi_descend_view_path {}}
  catch {xschem log_action -suppress pop}
  set _busy 0
}

## `.save all` first (I2 / rule R2), then the cards.
##
## ⚠ THE DOT-CARD, AND IT IS NOT A SPELLING NICETY. Re-measured on ngspice 46+:
## a bare deck-level `save all` is parsed as an `s`-prefixed SWITCH instance and
## the run dies with `Unable to find definition of model`, writing NO RAW AT ALL
## — strictly worse than omitting it. `.save all` is the form that works. And
## inside a `.control` block it is the other way round: there the dot form is
## `save: no such command available` at rc 0, so this block belongs at DECK
## level, which is where write_save_file's `.include` puts it.
##
## An empty walk returns {} and NOT a lone `.save all`: a file whose entire
## content is a header says nothing while reporting success.
proc op_annot::_block {cards} {
  if {[llength $cards] == 0} { return {} }
  return "[join [linsert $cards 0 {.save all}] \n]\n"
}

## op_annot::save_cards -> the `.save` block for the whole hierarchy below the
## CURRENT cell, as text; {} when no device produced a card.
##
## The block is rooted HERE: every card is `deck`-based with this level's
## `sch_path` as its root, so the file is a save block for a deck of the cell
## you are standing in, and no loaded raw can move a single name (issue 0436).
## It names ONLY devices the netlister itself put in that deck (issue 0442).
##
## ⚠ IT RE-RAISES. A partial block silently returned is the raw-destroying card
## wearing a different hat: the devices the walk never reached are missing, and
## the ones it did reach are not necessarily complete. Callers must call this
## inside a catch.
##
## I4: reads context, never writes it. No instance placed, no set_modify,
## nothing written to the .sch — and it refuses outright rather than let the
## oracle's netlist eat a pending gesture (0263) or let go_back revert an
## unsaved edit (0626).
proc op_annot::save_cards {} {
  variable _acc
  variable warnings
  variable _busy
  variable _c_rule
  variable _c_notfound
  variable _c_name
  variable _nkmemo

  ## FIRST, and before any state is touched: a nested call would overwrite the
  ## outer walk's accumulator and its idea of the user's netlist settings, then
  ## "restore" the forced ones (issue 0438).
  if {[info exists _busy] && $_busy} {
    return -code error "op_annot::save_cards: already running — the walk is not\
 re-entrant (issue 0438). A nested call would overwrite the outer walk's cards\
 and restore the netlist settings it forced."
  }
  ## SECOND: refuse on a pending gesture, before the oracle's netlist can eat it.
  ::op_annot::_assert_idle
  ## THIRD: refuse when the ascent would silently revert unsaved edits (0626).
  ::op_annot::_assert_saveable

  set _acc {}
  set warnings {}
  set _c_rule 0
  set _c_notfound 0
  set _c_name 0
  ## Issue 0493: the path memo may not outlive one walk — abs_sym_path resolves
  ## against XSCHEM_LIBRARY_PATH, which is user state.
  catch {array unset _nkmemo}
  set kd 0
  if {[info exists ::keep_symbols]} { set kd $::keep_symbols }
  ## The park is taken BEFORE the entry list so _restore always has it, even
  ## when the walk raises on its very first line.
  set park [::op_annot::_park_backup]
  set entry [list [xschem get currsch] [xschem get sch_path] \
                  [xschem get no_draw] $kd $park]
  ## THE ROOT OF THIS BLOCK. Read once, before anything moves.
  set root [lindex $entry 1]
  ## ⚠ THE LATCH IS SET AFTER THE ENTRY SNAPSHOT, NOT BEFORE IT. _restore is the
  ## only thing that clears it and it runs only from below this line, so a raise
  ## while READING the entry state would otherwise leave _busy set and wedge the
  ## feature for the rest of the session (issue 0438) with no walk ever having
  ## started. Everything above this line is a read or a reset.
  set _busy 1
  ## Pushed OUTSIDE the catch and popped inside _restore, so the pair survives a
  ## raise. descend and go_back self-log (actions.c:4650-4651, :4806-4807) and
  ## the oracle's netlist would too but for `-keep_symbols` (scheduler.c:8887); a
  ## walk over a real design would otherwise flood a log whose contract is
  ## REPLAYABLE USER EDITS.
  catch {xschem log_action -suppress push}
  set rc [catch {
    ## THE ORACLE, ONCE, FIRST, AND AT THE ENTRY LEVEL — the deck the user would
    ## simulate from here is the one whose devices these cards must name.
    ## Before no_undo/no_draw/keep_symbols: the netlister does its own
    ## push_undo/pop_undo round trip.
    set idx [::op_annot::_deck_index [::op_annot::_oracle_deck]]
    set ::keep_symbols 1
    ## The prototype's entry unselect_all, kept: descend acts on the selection,
    ## so this is a real precondition. The selection is NOT saved and restored —
    ## `xschem selected_set` answers instance NAMES only, so a "restore" would
    ## silently drop every wire and text the user had selected, which is more
    ## surprising than clearing it. (The oracle's own netlist has already
    ## cleared it: global_spice_netlist calls unselect_all.)
    xschem unselect_all
    xschem set no_draw 1
    xschem set no_undo 1
    ::op_annot::_walk $root $idx {}
  } res opts]
  ::op_annot::_restore $entry $rc
  if {$rc} { return -options $opts $res }
  ## The aggregate, appended after the walk's own per-cell sentences and emitted
  ## only when non-zero: a clean walk says nothing.
  ##
  ## ⚠ ONLY `dropped_by_rule` MAY SAY "normal for such cells" (issue 0497).
  ## Attempt 4's single aggregate carried that phrase over BOTH classes and told
  ## the user that 12 missing FETs on tb_bandgap_opamp were expected behaviour.
  if {$_c_rule > 0} {
    lappend warnings "$_c_rule instance(s) were dropped by a netlister rule and\
 got no cards (spice_ignore, only_toplevel, lvs_ignore, an empty format,\
 default_schematic=ignore, spice_sym_def, spice_stop, or a behavioural cell with\
 an empty block) - normal for such cells"
  }
  if {$_c_notfound > 0} {
    lappend warnings "$_c_notfound instance(s) ARE in the netlist and the walk\
 could not reach the block the netlist expanded them into. This is a DEFECT, not\
 a normality: those devices have no save cards and will render blank."
  }
  if {$_c_name > 0} {
    lappend warnings "$_c_name instance(s) got no cards because no raw-file\
 device name could be built for them (a devproc that failed, a blank devpath\
 template, or a spiceprefix'd subcircuit - issue 0488)."
  }
  return [::op_annot::_block $_acc]
}

## op_annot::write_save_file -> writes the block to
## $netlist_dir/<current cell>.save and returns the path; {} when there was
## nothing to save (and then NO file is written — a .save file containing only a
## header says nothing while reporting success).
##
## ⚠ THE FILENAME AGREES WITH THE BODY, and only because the cards are
## entry-relative: `<current cell>.save` describes a deck whose top IS the
## current cell, which is also the cell `xschem netlist` would write from here.
##
## Modelled on IHP's `Create FET and BIP .save file` menu command
## (ihp-sg13g2/sg13g2_procs.tcl:602-606), including its `file mkdir
## $netlist_dir`, which sky130A/sky130_procs.tcl:235 lacks. The textwindow is
## X-only: under --nogui / --pipe there is no Tk and `textwindow` would raise.
proc op_annot::write_save_file {} {
  global netlist_dir
  set block [::op_annot::save_cards]
  if {$block eq {}} { return {} }
  file mkdir $netlist_dir
  set path [file join $netlist_dir \
    "[file rootname [file tail [xschem get current_name]]].save"]
  ## THE WARNINGS REACH THE USER HERE, AND NOWHERE ELSE.
  ##
  ## The three counters and the per-cell sentences exist because a filter that
  ## UNDER-emits IN SILENCE is exactly the failure that survived 85, then 96,
  ## then 275 green checks. The textwindow this proc already opens is the
  ## channel, at zero new UI.
  ##
  ## REJECTED: an `alert_` on success. X-only, untestable headless, and it would
  ## fire on healthy designs. REJECTED also: leaving them computed and discarded,
  ## which reproduces at the UI layer the very silence this step deletes.
  ##
  ## ⚠ ONE LINE PER WARNING, NEWLINES FLATTENED. A note that wrapped would put a
  ## continuation line with no leading `*` into a file a SPICE parser reads, and
  ## the parser would take it for a card.
  set notes {}
  foreach w [::op_annot::last_warnings] {
    append notes "* NOTE: [string map [list \n { } \r { }] $w]\n"
  }
  ## ASCII only: these lines go into a file a SPICE parser reads.
  write_data "* operating-point .save cards - .include this file in your testbench\n$notes\n$block" $path
  if {[info exists ::has_x] && $::has_x} { catch {textwindow $path} }
  return $path
}
