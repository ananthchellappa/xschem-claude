# tests/headless/test_wave_sigbrowser_0319.tcl — issue 0319.
#
# ============================================================================
# WHAT IS UNDER TEST
# ============================================================================
# Ctrl-Alt-V ("Show in Signal Browser") on a FET selected inside a descended
# instance did not tick `Show device internals` and landed on the PARENT,
# `x1 > x1`, instead of on the device. The issue filed a HYPOTHESIS — that a
# primitive contributes no path segment at all, so "reach the device" is not
# expressible. THE MEASUREMENT REFUTED IT. The literal raw names are
#
#   v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#body)
#   v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#dbody)
#   v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#sbody)
#
# (tb_bandgap_ase.raw; there is no bare `m18` anywhere in its 424 variables).
# The device DOES contribute a segment — `xm18` — and with device internals
# shown the tree really does carry `g:x1.x1.xm18`. What it does not carry is
# `M18`: sky130's FET symbols begin their format `@spiceprefix@name`, so a FET
# DRAWN `M18` is NETLISTED `XM18` (tb_bandgap_ase.spice:110) and ngspice
# lower-cases that to `xm18`.
#
# `ase::show_in_browser_for_current` extended the path with the SCHEMATIC's
# spelling, so it asked for `x1.x1.M18`, which matches the row neither exactly
# nor `-nocase`; `matched` stalled at 2 of 3, item 18's R12 probe answered "no"
# for the right reason, and the gesture fell through to the parent. THE `==`
# IN THAT PROBE IS CORRECT AND IS NOT TOUCHED — `BK43` still owns it, and BN36
# below re-measures the deeper-but-not-full case from this file.
#
# THE FIX is one line at the call site plus two procs in `src/ase.tcl`:
# `ase::inst_path_segment` asks the NETLISTER what this instance is called
# (`xschem translate <inst> {@spiceprefix}`) and `ase::spice_seg_name` is the
# rule. `$selname` keeps the schematic's spelling, because F1's digital probe
# and 6b's "'<name>' has no level" sentence both need it.
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE — READ BEFORE TRUSTING IT
# ============================================================================
# * NO RAW IS READ. `tb_bandgap_ase.raw` is 69 MB of user artifact outside the
#   repo, so BN3x/BN4x SEED the inventory with names copied VERBATIM out of it
#   (the `bx_seed`/`be_seed` precedent) and let the SHIPPED `browser_refresh`
#   build the tree from them. The class filter, the row model, the resolver and
#   the R12 probe are all the shipped code; only the read that fills
#   `browsersigs` is replaced.
# * THE PIXELS ARE NOT MEASURED. That the user sees the box tick and the row
#   highlight is asserted as widget state, not as an image; the receipt says an
#   eyeball is still owed and how to take it.
# * THE DESIGNS ARE THE COMMITTED ONES. BN1x/BN4x load
#   sky130_tests_ase/tb_bandgap and sky130_tests/test_nfet_final out of the
#   tracked sky130A workarea (test_ase_final.tcl's decision D3), so a broken
#   library registry reds BN10/BN20 rather than silently degrading every
#   instance to "symbol not found" — which answers the bare name and would make
#   this whole file pass while measuring nothing.
#
# ============================================================================
# SABOTAGE TABLE — 25 mutations, each applied to src/, the WHOLE file re-run
# under X (35 checks), reverted from a byte copy. MEASURED on the FINAL code,
# not predicted; the run after the last revert is `RESULT: ALL PASS (35)`.
#
# ⚠⚠ NINE ROWS AND SEVEN CHECKS EXIST BECAUSE TWO ADVERSARIAL REVIEWS BROKE THE
# FIRST VERSION OF THIS FILE. It was 30/30 green with 16 rows, and every one of
# these was alive underneath it: `lvs_format` ignored (**wrong**, and a
# regression under LVS netlisting on 54 in-repo symbols), the format read with
# the Tcl-EXECUTING accessor, an all-digit instance name silently resolved as an
# INDEX, the reader free to hand the rule a CONSTANT prefix, `contains`
# indistinguishable from `begins with`, an idempotence guard that re-opens 0319
# for a device named `X1`, and 6b's last-mile retry re-asking the path that just
# failed. Rows S19-S25 and checks BN02(legs 2-4), BN24-BN27, BN44 are those.
# ============================================================================
#  #   mutation                                          reds (measured)
# --- the fix itself ----------------------------------------------------------
#  S1  call site reverts to `lappend segs $selname`      BN22 BN23 BN41 BN42
#      (i.e. issue 0319 restored, exactly)
#  S2  inst_path_segment: `return $nm` on its first      BN11 BN12 BN15 BN16
#      line — the proc exists and does nothing           BN19 BN24 BN27 BN41
#                                                        BN42
#  S3  spice_seg_name: an unconditional return           BN04 BN05 BN14 BN16
#      PREPENDED (the guards bypassed, not deleted)      BN24 BN25
# --- where the prefix comes from ---------------------------------------------
#  S4  the prefix read with `getprop instance $nm        BN15 BN16 BN19 BN21
#      spiceprefix` instead of `xschem translate`.       BN27
#      ⚠ THIS WAS THE FIRST CUT OF THE FIX and it is
#      LIVE-BROKEN: getprop reads inst.prop_ptr only,
#      so a template-inherited prefix answers `{}`.
#      BN15 (the top-level control) is what caught it.
#  S5  translate asked for `{@name}`                     BN11 BN12 BN15 BN16
#                                                        BN19 BN21 BN24 BN27
#                                                        BN41 BN42
# S22  the READER hands the rule a CONSTANT `X`,         BN27
#      ignoring what it just read. ⚠ REVIEW FINDING:
#      every shipped `spiceprefix=` value is `X`, so
#      before BN27 this was invisible.
# --- which format, and how it is read ----------------------------------------
# S19  `lvs_format` never consulted — the FIRST CUT's    BN21 BN24
#      rule, and it was WRONG. ⚠ REVIEW FINDING: the
#      justification swept 3 of this repo's 5 symbol
#      libraries; 54 symbols in the two it missed
#      disagree, and under LVS the prefix must NOT be
#      applied at all.
# S20  `instance_notcl` -> `instance`, i.e. the          BN21 BN25
#      Tcl-EXECUTING accessor. ⚠ REVIEW FINDING.
#  S9  the instance-level format read dropped            BN16 BN21 BN25
#      (symbol only)
# S10  the `cell::` fallback dropped (instance only)     BN11 BN12 BN15 BN16
#                                                        BN19 BN21 BN24 BN27
#                                                        BN41 BN42
# S21  the all-digit refusal deleted. ⚠ REVIEW           BN21 BN26
#      FINDING: `get_instance` reads an all-digit name
#      as an INDEX. (The first cut of BN26 could not see
#      this — see the note at that check.)
# --- the rule's guards, one row each -----------------------------------------
#  S6  a redundant `$prefix eq {}` guard RE-ADDED        BN17
#      ⚠ THE HOLE THE FIRST BATTERY FOUND, AND IT WAS IN
#      THE FIX RATHER THAN IN THE FILE. The first cut
#      carried that guard; dropping it red ONE SOURCE
#      CHECK and no behaviour, because `"$prefix$name"`
#      with an empty prefix IS the name. A line no
#      sabotage could reach, so it was REMOVED and this
#      row now measures the re-add.
#  S7  the `@spiceprefix` format guard dropped           BN04 BN14 BN16 BN17
#                                                        BN24 BN25
#  S8  the `$name eq {}` guard dropped                   BN05 BN17
# S24  the format test becomes `!= 0` — "begins with"    BN02
#      instead of "consumes". ⚠ REVIEW FINDING: every
#      shipped format puts the token first.
# S23  an idempotence guard ADDED (never double-prefix). BN02 BN27
#      ⚠ REVIEW FINDING, and it is the dangerous one:
#      the netlister does NOT dedupe, so this re-opens
#      0319 for a device the user renamed `X1`.
# --- the case decision, and the value that must NOT change -------------------
# S11  spice_seg_name lower-cases its answer             BN02 BN06 BN11 BN12
#                                                        BN15 BN16 BN19 BN24
#                                                        BN27
# S17  spice_seg_name prefixes with a CONSTANT `X`       BN02 BN03 BN06 BN27
# S12  browser_sel_segment returns the prefixed name     BN12 BN20 BN44
#      too ($selname folded into one value)
# S18  the `catch` around `translate` dropped            BN18
# --- the rest of the gesture --------------------------------------------------
# S25  6b's last-mile retry re-asks `$segs` instead of   BN44
#      `$base`. ⚠ REVIEW FINDING: one token, inside the
#      block this fix edits, and nothing drove that arm.
# S14  the segment read MOVED BELOW `wviewer::open`      BN22 BN23
#      ⚠ SOURCE CHECKS ONLY, AND THAT IS HONEST rather
#      than a gap left open: BN4x STUBS `wviewer::open`,
#      so in this fixture the context never moves and the
#      landmine cannot fire. Pinning the source ORDER is
#      the whole protection, which is why BN23 exists.
# --- the two relaxations this fix must NOT be confused with ------------------
# S13  browser_show_path's R12 `==` relaxed              BN36
#      (BK43's own mutation, re-measured from here)
# S16  `browser_node_for` GUESSES an `x` prefix — i.e.   BN32
#      0319 "fixed" in the RESOLVER instead. BN32 is the
#      tombstone for it: the schematic spelling must keep
#      landing on the parent.
# S15  R12's `$bx invoke` (the tick itself) deleted      BN33 BN34 BN35 BN41
#                                                        BN42
#
# ⚠ SIX CHECKS ARE REACHED BY NO MUTATION, AND EACH IS A PRECONDITION OR A
# CONTROL RATHER THAN A CLAIM ABOUT THE RULE — saying so beats inventing a
# triple mutation to colour the table in:
#   BN01 BN10 BN30 BN31  the procs exist / the design loaded / the class filter
#                        really does hide and show the device. These are what
#                        make a FAILURE of the others legible instead of hollow.
#   BN13 BN43            the "must not change" controls (an ammeter, a
#                        parax_cap, a subcircuit). No SINGLE edit reds them:
#                        three things must be wrong at once (the reader's
#                        empty-prefix exit, the format guard, and the prefix
#                        value), because those instances have neither a prefix
#                        nor a format that consumes one. Their job is to catch a
#                        future "prefix everything" rewrite, which is exactly
#                        the shape no one-line mutation produces.
# ============================================================================

set ::wvbs_tag  wvsigbrowser_0319
set ::wvbs_name test_wave_sigbrowser_0319
source [file join [file dirname [info script]] wvbs_common.tcl]

set asrc {}
catch {
  set fh [open [file join $repo src ase.tcl] r]
  set asrc [read $fh]
  close $fh
}

# ---------------------------------------------------------------------------
# BN0x — THE RULE, PURE. No design, no raw, no Tk: these run on every arm.
# ---------------------------------------------------------------------------
set bn_fmt {@spiceprefix@name @pinlist sky130_fd_pr__@model L=@L W=@W}

check {BN01 both halves of the fix exist} \
  [list [expr {[info commands ::ase::spice_seg_name] ne {}}] \
        [expr {[info commands ::ase::inst_path_segment] ne {}}]] {1 1}

# ⚠ THE WHOLE ISSUE IN ONE VALUE. `M18` + the sky130 FET's own format string.
#
# ⚠⚠ LEGS 2-4 ARE REVIEW FINDINGS, and each closes a mutation MEASURED green on
# the first version of this file:
#   leg 2  a NON-`X` prefix. Every shipped `spiceprefix=` value is `X`, so with
#          only leg 1 the reader could hand the rule a CONSTANT `X` and nothing
#          would notice. BN27 is the same closure on a real placed instance.
#   leg 3  `@spiceprefix` NOT at index 0. Every shipped format puts it first, so
#          `[string first …] < 0` and `!= 0` are indistinguishable on any real
#          fixture — and this check's name says "consumes", not "begins with".
#   leg 4  NO IDEMPOTENCE DEDUPE. The plausible later "hardening" is a guard
#          that refuses to double-prefix a name already starting with the
#          prefix. It passed all 30 checks and BREAKS a real case: the netlister
#          does not dedupe, so a sky130 FET the user renamed `X1` is netlisted
#          `XX1` and the raw says `xx1`. MEASURED on a placed instance.
check {BN02 the rule prefixes with the prefix it was GIVEN, wherever the token\
       sits in the format, and never dedupes} \
  [list [pcall ::ase::spice_seg_name M18 X $bn_fmt] \
        [pcall ::ase::spice_seg_name R7 QQ $bn_fmt] \
        [pcall ::ase::spice_seg_name R7 QQ {tcleval(zz @spiceprefix@name)}] \
        [pcall ::ase::spice_seg_name X1 X $bn_fmt]] {XM18 QQR7 QQR7 XX1}

# ⚠ THE HALF THAT ALREADY WORKED, AND IT MUST STAY UNTOUCHED. Every subcircuit
# instance in the shipped libraries has no spiceprefix at all, which is why
# selecting `x1` behaved correctly before this fix and has to keep doing so.
# ⚠ THE RULE HAS NO `$prefix eq {}` GUARD and does not need one: leg 2 is the
# state such a guard would cover, and the concatenation answers it. The
# sabotage battery measured that — dropping the guard red one SOURCE check and
# no behaviour at all — so the guard was removed rather than left as a line
# nothing could reach. Both legs are still asserted because the ANSWER is what
# protects the subcircuit case, however it is produced.
check {BN03 no prefix -> the name, unchanged (the subcircuit case)} \
  [list [pcall ::ase::spice_seg_name x1 {} {@name @pinlist @symname}] \
        [pcall ::ase::spice_seg_name x1 {} $bn_fmt]] {x1 x1}

# ⚠⚠ NOT A HYPOTHETICAL GUARD. `devices/netlist_options` carries
# `spiceprefix=true` in its template and has NO format at all — it configures
# the netlister rather than being netlisted — so without this condition
# selecting one would ask the browser for `trueNETLIST_OPTIONS`. BN14 is the
# same claim driven through the real reader on a real placed instance.
check {BN04 a prefix the format never consumes is NOT applied} \
  [list [pcall ::ase::spice_seg_name NOPT true {}] \
        [pcall ::ase::spice_seg_name M18 X {@name @pinlist zz}]] {NOPT M18}

# an empty name is `browser_sel_segment`'s `none` shape and must not become a
# bare prefix, which would match the ROOT rather than nothing.
check {BN05 an empty name stays empty (never becomes the bare prefix)} \
  [pcall ::ase::spice_seg_name {} X $bn_fmt] {}

# ⚠⚠ THE CASE IS NOT FOLDED, and that is `browser_sel_segment`'s decision kept
# rather than a new one. `browser_node_for` matches each level exact-FIRST with
# a `-nocase` fallback, which is how a schematic `X1.X2` lands on the raw's
# `g:x1.x2` (BX42); folding here would be a SECOND answer to that one question
# and a design carrying both `M18` and `m18` would lose the exact hit.
check {BN06 the prefix is prepended verbatim - the case is NOT folded here} \
  [list [pcall ::ase::spice_seg_name M18 X $bn_fmt] \
        [pcall ::ase::spice_seg_name m18 x $bn_fmt]] {XM18 xm18}

# ---------------------------------------------------------------------------
# BN1x — THE READER, on the REAL committed designs. `--nogui` reaches all of
# this: no viewer, no raw, no Tk is involved in asking the netlister what an
# instance is called.
# ---------------------------------------------------------------------------
# the scratch registry pointing at the REAL committed trees (test_ase_final's
# decision D3). `no_recent_files` is already set by the common prelude (0119).
set fdefs [open [file join $scratch library.defs] w]
puts $fdefs "DEFINE sky130_tests_ase [file join $repo sky130A xschem_libs sky130_tests_ase]"
puts $fdefs "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $fdefs "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
# gf180 is here for BN24: it is the library whose devices DISAGREE between
# `format` and `lvs_format` about `@spiceprefix`, which sky130's do not.
puts $fdefs "DEFINE gf180mcu_pr [file join $repo gf180mcuD xschem_libs gf180mcu_pr]"
puts $fdefs "DEFINE gf180mcu_tests [file join $repo gf180mcuD xschem_libs gf180mcu_tests]"
puts $fdefs "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $fdefs
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
# ⚠ UNQUALIFIED, and that is a review finding rather than a style preference.
# The write trace that calls `set_paths` compares `$varname eq
# {XSCHEM_LIBRARY_PATH}` (src/xschem.tcl:15219, armed at :16327), and a
# QUALIFIED `set ::XSCHEM_LIBRARY_PATH` delivers `::XSCHEM_LIBRARY_PATH` — so
# the qualified spelling every neighbouring test uses is INERT and leaves the
# ambient 13-directory path in place. Measured both ways.
set XSCHEM_LIBRARY_PATH {}
set ::SKYWATER_MODELS [file join $repo sky130A models libs.tech combined]

set bn_tb [file join $repo sky130A xschem_libs sky130_tests_ase tb_bandgap \
             schematic tb_bandgap.sch]

# ⚠ THE FIXTURE IS ASSERTED, NOT ASSUMED. A registry that does not resolve
# `sky130_fd_pr` leaves every FET a missing symbol whose translate answers the
# bare name — i.e. every claim below would pass while measuring nothing.
pcall xschem load $bn_tb
pcall xschem descend -inst x1
pcall xschem descend -inst x1
check {BN10 (FIXTURE) the reported repro's position: two descends into bandgap_opamp} \
  [list [file tail [pcall xschem get schname]] [pcall ::wviewer::hier_now] \
        [pcall xschem getprop instance M18 cell::type]] \
  {bandgap_opamp.sch {x1 x1} nmos}

# ⚠⚠ THE ISSUE, AS A VALUE. The raw says `xm18`; the reducer says `M18`; the
# reader is what closes the gap. Leg 1 pins that the REDUCER's contract did NOT
# change — `$selname` is still the schematic's own spelling, because step 3c's
# digital probe and 6b's sentence both read it.
check {BN11 the FET: the reducer keeps `M18`, the path segment becomes `XM18`} \
  [list [pcall ::ase::browser_sel_segment] \
        [pcall ::ase::inst_path_segment M18]] {none XM18}

pcall xschem select instance M18 fast
check {BN12 with M18 SELECTED: reducer `ok M18`, path segment `XM18`} \
  [list [pcall ::ase::browser_sel_segment] [pcall ::ase::inst_path_segment M18]] \
  {{ok M18} XM18}
pcall xschem unselect_all

# ⚠ THE OTHER INSTANCES ON THE SAME SHEET, so "prefix everything" cannot pass.
# `v1` is an ammeter, `C6` a parax_cap, `x1` a subcircuit — none has a
# spiceprefix and the raw spells all three exactly as the schematic does.
check {BN13 siblings with no spiceprefix are untouched} \
  [list [pcall ::ase::inst_path_segment v1] \
        [pcall ::ase::inst_path_segment C6] \
        [pcall ::ase::inst_path_segment x1]] {v1 C6 x1}

# ⚠ NEVER THROWS. This rides a key binding, where a Tcl error pops bgerror —
# modal under X, which hangs a headless run. `xschem translate` DOES throw on
# an unknown instance ("xschem translate: instance not found", measured).
check {BN18 an unknown instance and an empty name answer, they do not throw} \
  [list [pcall ::ase::inst_path_segment ZZnosuchinstance] \
        [pcall ::ase::inst_path_segment {}]] {ZZnosuchinstance {}}

# ⚠⚠ THE GLOBAL TOGGLE IS HONOURED, and it is a real user-facing switch:
# Simulation > "Use 'spiceprefix' attribute" (xschem.tcl:15148, default 1 at
# :15708). token.c:2676 expands `@spiceprefix` to NOTHING while it is off, so
# the netlist — and the raw — then say `m18` and prefixing would BREAK the
# match this fix exists to make.
set bn_sp_was 1
catch {set bn_sp_was $::spiceprefix}
set ::spiceprefix 0
set bn_off [pcall ::ase::inst_path_segment M18]
set ::spiceprefix 1
set bn_on [pcall ::ase::inst_path_segment M18]
set ::spiceprefix $bn_sp_was
check {BN19 the global spiceprefix switch decides the segment} \
  [list $bn_off $bn_on] {M18 XM18}

# --- the TOP-LEVEL CONTROL the issue asked for, and it is not scenery -------
# ⚠⚠ UNKNOWN 4, ANSWERED, AND THIS CONTROL CAUGHT A REAL DEFECT IN THE FIRST
# CUT OF THE FIX. `test_nfet_final` puts its FET at the TOP level with NO
# descend anywhere, and draws it as plain `name=M1 W=1 L=0.15 nf=1` — no
# spiceprefix token of its own, inherited from the symbol TEMPLATE. Its raw
# says `i(@m.xm1.m0[id])`, so the same mismatch exists with zero descends: the
# descend in the report is scenery. A reader built on `xschem getprop instance
# M1 spiceprefix` (inst.prop_ptr ONLY, scheduler.c:5224) answers `{}` here and
# does nothing — which is why the prefix is asked of `xschem translate`.
pcall xschem load [file join $repo sky130A xschem_libs sky130_tests \
                     test_nfet_final schematic test_nfet_final.sch]
check {BN15 TOP LEVEL, no descend: a template-inherited prefix is applied too} \
  [list [pcall ::wviewer::hier_now] \
        [pcall xschem getprop instance M1 spiceprefix] \
        [pcall ::ase::inst_path_segment M1] \
        [pcall ::ase::inst_path_segment V1]] {{} {} XM1 V1}

# --- the two guards, driven on real placed instances ------------------------
# a hermetic sheet carrying the three shapes the rule distinguishes.
set bn_fx [file join $scratch bn_guards.sch]
set fh [open $bn_fx w]
puts $fh "v \{xschem version=3.4.8RC file_version=1.3\}"
puts $fh "G \{\}"
puts $fh "K \{\}"
puts $fh "V \{\}"
puts $fh "S \{\}"
puts $fh "E \{\}"
puts $fh "C \{devices/netlist_options\} 100 -100 0 0 \{name=NOPT"
puts $fh "spiceprefix=true"
puts $fh "hiersep=.\n\}"
puts $fh "C \{sky130_fd_pr/nfet_01v8\} 300 -100 0 0 \{name=M8 W=1 L=0.15 nf=1\}"
puts $fh "C \{sky130_fd_pr/nfet_01v8\} 500 -100 0 0 \{name=M7 W=1 L=0.15 nf=1"
puts $fh "spiceprefix=X"
puts $fh "format=\"@name @pinlist zz\"\n\}"
close $fh
pcall xschem load $bn_fx

# ⚠ THE `netlist_options` CASE, FOR REAL: the prefix is there (`true`) and the
# format is not, so the segment must be the bare name. Leg 2 is the evidence
# that the guard is what did it rather than the prefix being absent.
check {BN14 netlist_options: prefix `true`, no format -> the bare name} \
  [list [pcall ::ase::inst_path_segment NOPT] \
        [pcall xschem translate NOPT {@spiceprefix}]] {NOPT true}

# ⚠ INSTANCE FORMAT BEFORE THE SYMBOL'S — token.c:2470-2473's own order. `M7`
# and `M8` are the SAME symbol; only M7 overrides `format=` with one that drops
# `@spiceprefix`, and only M7 is netlisted bare.
check {BN16 an instance `format=` override beats the symbol's} \
  [list [pcall ::ase::inst_path_segment M8] [pcall ::ase::inst_path_segment M7]] \
  {XM8 M7}

# ⚠ LEG 2 IS AN ABSENCE ON PURPOSE. A `$prefix eq {}` guard here would be a
# line no sabotage could reach behaviourally (measured: S6 red BN17 alone), so
# the rule does not carry one and this says re-adding it is a regression in
# clarity, not a hardening. Leg 3 is the guard that IS load-bearing.
check {BN17 (SOURCE) the rule keeps its two conditions and no `$prefix eq {}`} \
  [list [regexp -all {\$name eq \{\}} [wvproc_body $asrc ase::spice_seg_name]] \
        [regexp -all {\$prefix eq \{\}} [wvproc_body $asrc ase::spice_seg_name]] \
        [regexp -all {string first \{@spiceprefix\} \$fmt} \
           [wvproc_body $asrc ase::spice_seg_name]]] {1 0 1}

# --- BN24-BN27: three review findings, each driven on a real placed instance --
#
# ⚠⚠ BN24 — `lvs_format`. THE FIRST CUT GOT THIS WRONG on a measurement that
# swept three of this repo's FIVE symbol libraries. 54 symbols disagree about
# `@spiceprefix` between `format` and `lvs_format`: 19 in gf180mcu_pr and 35 in
# sg13g2_pr (where lvs hardcodes `M@name`/`C@name`/`R@name`/`L@name`/`Q@name`).
# With LVS netlisting ON, gf180's `M1` is emitted BARE — so prefixing it is not
# a harmless miss, it BREAKS a segment that used to match. This is the only
# check in the tree that reads a gf180 symbol.
set bn_gf [file join $repo gf180mcuD xschem_libs gf180mcu_tests test_nfet_final \
             schematic test_nfet_final.sch]
pcall xschem load $bn_gf
set bn_lvs_was 0
catch {set bn_lvs_was $::lvs_netlist}
set ::lvs_netlist 0
set bn_l0 [pcall ::ase::inst_path_segment M1]
set ::lvs_netlist 1
set bn_l1 [pcall ::ase::inst_path_segment M1]
set ::lvs_netlist $bn_lvs_was
check {BN24 gf180: the ACTIVE format attribute decides - lvs off XM1, lvs on M1} \
  [list [expr {[string first {@spiceprefix} \
                 [pcall xschem getprop instance_notcl M1 cell::format]] >= 0}] \
        [expr {[string first {@spiceprefix} \
                 [pcall xschem getprop instance_notcl M1 cell::lvs_format]] >= 0}] \
        $bn_l0 $bn_l1] {1 0 XM1 M1}

# ⚠⚠ BN25 — the format is read WITHOUT running the symbol's Tcl. Plain `getprop
# instance` looks the token up with `with_quotes = 0`, which routes through
# `tcl_hook2` and EXECUTES a `tcleval(...)` value; `instance_notcl` uses
# `with_quotes = 2` and does not, which is also what `print_spice_element`
# does. `xschem_library/analyses/command_block.sym`'s format is
# `tcleval([::analyses::netlister spice])` — a read that would run the
# NETLISTER on a key press. `$::bn_boom` is the tripwire.
set bn_tcl [file join $scratch bn_tcleval.sch]
set fh [open $bn_tcl w]
puts $fh "v \{xschem version=3.4.8RC file_version=1.3\}"
puts $fh "G \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}"
puts $fh "C \{sky130_fd_pr/nfet_01v8\} 400 -100 0 0 \{name=M5 W=1 L=0.15 nf=1"
puts $fh "spiceprefix=X"
puts $fh "format=\"tcleval(\[bn_boom\])\"\n\}"
close $fh
set ::bn_boom 0
proc bn_boom {} { incr ::bn_boom ; return {@spiceprefix@name @pinlist} }
pcall xschem load $bn_tcl
set ::bn_boom 0
set bn_tv [pcall ::ase::inst_path_segment M5]
# leg 3 proves the tripwire is armed: the SHIPPED-but-wrong reader does fire it.
set ::bn_boom 0
catch {xschem getprop instance M5 format}
check {BN25 the format read does NOT execute the symbol's tcleval} \
  [list $bn_tv $::bn_boom [expr {$::bn_boom > 0}]] {M5 1 1}
set ::bn_boom 0

# ⚠⚠ BN26 — an ALL-DIGIT instance name. `get_instance` (scheduler.c:187-190)
# reads one as an INDEX, so every by-name read would silently answer about a
# different device. `hier_resolve` guards the MIRROR direction against this same
# rule and says so at wave_viewer.tcl:10725-10732.
#
# ⚠⚠ THE ORDERING OF THIS FIXTURE IS THE CHECK, AND THE FIRST CUT OF IT HAD NO
# TEETH. With the FET named `2` sitting at index 3 and a plain vsource at index
# 2, deleting the refusal changed NOTHING — the wrong instance happened to have
# no prefix, so the answer was `2` either way and the sabotage red only a source
# grep. Here index 2 IS the prefixed FET and the instance NAMED `2` is a
# vsource, so the refusal is the only thing standing between the user and the
# segment `X2` for a device the netlist calls `2`.
set bn_dig [file join $scratch bn_digit.sch]
set fh [open $bn_dig w]
puts $fh "v \{xschem version=3.4.8RC file_version=1.3\}"
puts $fh "G \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}"
puts $fh "C \{devices/vsource\} 100 -100 0 0 \{name=V0 value=1\}"
puts $fh "C \{devices/vsource\} 200 -100 0 0 \{name=V1 value=1\}"
puts $fh "C \{sky130_fd_pr/nfet_01v8\} 300 -100 0 0 \{name=M2 W=1 L=0.15 nf=1\}"
puts $fh "C \{devices/vsource\} 400 -100 0 0 \{name=2 value=1\}"
close $fh
pcall xschem load $bn_dig
check {BN26 an all-digit instance name is REFUSED, not resolved as an index} \
  [list [pcall xschem getprop instance 2 name] \
        [pcall xschem translate 2 {@spiceprefix}] \
        [pcall ::ase::inst_path_segment 2]] {M2 X 2}

# ⚠⚠ BN27 — the prefix is the one that was READ. Every shipped `spiceprefix=`
# value is `X`, so a reader that handed the rule a constant `X` passed every
# other check in this file (measured by review). `M6` carries `spiceprefix=Q`
# in its own property string; `X1` is the no-dedupe case on a real instance.
set bn_q [file join $scratch bn_qpfx.sch]
set fh [open $bn_q w]
puts $fh "v \{xschem version=3.4.8RC file_version=1.3\}"
puts $fh "G \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}"
puts $fh "C \{sky130_fd_pr/nfet_01v8\} 400 -100 0 0 \{name=M6 W=1 L=0.15 nf=1"
puts $fh "spiceprefix=Q\n\}"
puts $fh "C \{sky130_fd_pr/nfet_01v8\} 600 -100 0 0 \{name=X1 W=1 L=0.15 nf=1\}"
close $fh
pcall xschem load $bn_q
check {BN27 a non-X prefix is carried through, and an X-named device is XX1} \
  [list [pcall ::ase::inst_path_segment M6] \
        [pcall ::ase::inst_path_segment X1]] {QM6 XX1}

# ---------------------------------------------------------------------------
# BN2x — SOURCE. The two decisions a behavioural check cannot see: that the
# NETLIST spelling goes into the path while the SCHEMATIC spelling stays in
# `$selname`, and that the read happens in the DESIGN context.
# ---------------------------------------------------------------------------
set bn_sel [wvproc_body $asrc ase::browser_sel_segment]
check {BN20 (SOURCE) the reducer still returns the SCHEMATIC name, unprefixed} \
  [list [regexp -all {return \[list ok \$nm\]} $bn_sel] \
        [regexp -all {inst_path_segment} $bn_sel]] {1 0}

set bn_ip [wvproc_body $asrc ase::inst_path_segment]
# leg 2 forbids the getprop reader the first cut used (BN15 is its behavioural
# twin); leg 3 forbids the Tcl-EVALUATING reader (BN25's twin); legs 4-5 pin
# token.c's own instance-then-symbol chain over the ACTIVE attribute (BN24).
check {BN21 (SOURCE) the prefix comes from the netlister and the format from\
       the non-evaluating reader over the active attribute} \
  [list [regexp -all {xschem translate \$nm \{@spiceprefix\}} $bn_ip] \
        [regexp -all {getprop instance \$nm spiceprefix} $bn_ip] \
        [regexp -all {getprop instance \$nm } $bn_ip] \
        [regexp -all {getprop instance_notcl \$nm \$attr} $bn_ip] \
        [regexp -all {getprop instance_notcl \$nm cell::\$attr} $bn_ip] \
        [regexp -all {set attr lvs_format} $bn_ip] \
        [regexp -all {string is digit -strict \$nm} $bn_ip]] {1 0 0 1 1 1 1}

set bn_fv [wvproc_body $asrc ase::show_in_browser_for_current]
check {BN22 (SOURCE) the PATH gets the netlist spelling} \
  [list [regexp -all {lappend segs \[ase::inst_path_segment \$selname\]} $bn_fv] \
        [regexp -all {lappend segs \$selname} $bn_fv]] {1 0}

# ⚠⚠ STEP 3b's LANDMINE, ONE READ OVER. `wviewer::open` moves the xschem
# context to the VIEWER's own untitled buffer, which has no instances at all —
# so `xschem translate` placed below it throws, is caught, and the prefix
# silently never gets applied while every direct check of the rule stays green.
# The order is pinned as source offsets because a runtime order check would need
# the very context switch that is being forbidden.
set bn_i_sel  [string first {ase::browser_sel_segment} $bn_fv]
set bn_i_seg  [string first {ase::inst_path_segment $selname} $bn_fv]
set bn_i_open [string first {wviewer::open $key} $bn_fv]
set bn_i_dig  [string first {ase::browser_digital_probe} $bn_fv]
check {BN23 (SOURCE) the segment is built in the DESIGN context, above the raise} \
  [list [expr {$bn_i_sel >= 0 && $bn_i_sel < $bn_i_seg}] \
        [expr {$bn_i_seg >= 0 && $bn_i_seg < $bn_i_dig}] \
        [expr {$bn_i_dig >= 0 && $bn_i_dig < $bn_i_open}]] {1 1 1}

# ---------------------------------------------------------------------------
# BN3x/BN4x — THE RESOLVER AND THE GESTURE, on a real browser (X only).
# ---------------------------------------------------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  catch {destroy .wvbn1}
  toplevel .wvbn1
  wm title .wvbn1 {issue 0319 primitive-path fixture}
  wm geometry .wvbn1 900x520+70+70
  canvas .wvbn1.drw -background white -width 700 -height 460
  pack .wvbn1.drw -side right -fill both -expand true
  dict set ::wviewer::windows bg [dict create top .wvbn1 win_path .wvbn1.drw]
  pcall ::wviewer::browser_build bg .wvbn1
  set BNF .wvbn1.wvbrowser
  set BNTV $BNF.pw.tvf.tv
  pack $BNF -side left -fill y -before .wvbn1.drw
  set bn_mapped [bs_wait_mapped .wvbn1.drw]
  catch {bs_wait_mapped $BNTV}
  update

  # ⚠⚠ NAMES COPIED VERBATIM OUT OF tb_bandgap_ase.raw, and the three `xm18`
  # rows are the ones the whole issue is about. The four plain `v(x1.x1.…)`
  # nets are what keeps `x1 > x1` in the tree while device internals are
  # HIDDEN — without them the parent would vanish with the device and the
  # `partial` landing this file measures would have nowhere to land.
  set bn_names {
    v(vbg)
    v(x1.net3)
    v(x1.x1.g1)
    v(x1.x1.g2)
    v(x1.x1.net6)
    v(x1.x2.g1)
    v(m.x1.x1.xm1.msky130_fd_pr__pfet_01v8#body)
    v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#body)
    v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#dbody)
    v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#sbody)
    v(m.x1.x2.xm18.msky130_fd_pr__nfet_01v8_lvt#body)
  }
  # ⚠ THE SHIPPED BUILDER, NOT A HAND-ROLLED ROW MODEL. `bx_seed` calls
  # `browser_rows` directly, which skips the CLASS FILTER — and the class
  # filter is precisely what R12's probe is about. Seeding only the inventory
  # and letting `browser_refresh` (reload 0, so it never re-enters the engine)
  # build the tree is what makes the hidden/shown distinction real here.
  set ::wviewer::browsersigs(bg) $bn_names
  set ::wviewer::browserraw(bg) [file join $scratch tb_bandgap_ase.raw]
  proc bn_reset {{dev 0}} {
    pcall ::wviewer::browser_devint bg $dev
    pcall ::wviewer::browser_refresh bg
    update
  }
  bn_reset 0
  proc bn_ids {} {
    global BNTV
    set out {}
    foreach id [bs_tree_ids $BNTV] { lappend out $id }
    return $out
  }
  proc bn_has {id} { expr {[lsearch -exact [bn_ids] $id] >= 0 ? 1 : 0} }

  check {BN30 (FIXTURE) hidden: the parent is in the tree and the device is NOT} \
    [list $bn_mapped [bn_has g:x1.x1] [bn_has g:x1.x1.xm18] \
          [pcall ::wviewer::browser_devint bg]] {1 1 0 0}

  bn_reset 1
  check {BN31 (FIXTURE) shown: the device IS a node, and it is a GROUP} \
    [list [bn_has g:x1.x1.xm18] [bn_has g:x1.x2.xm18] \
          [pcall ::wviewer::browser_devint bg]] {1 1 1}
  bn_reset 0

  # ⚠⚠ THE BUG ITSELF, PINNED AS A VALUE. This is what the gesture asked for
  # before the fix, and it must keep answering exactly this: the box does NOT
  # tick, and the landing is the PARENT. If someone ever "fixes" 0319 by
  # teaching the RESOLVER to guess an `x` prefix, this check goes red — which is
  # the point, because that guess is the relaxation the issue forbids.
  # ⚠ LEG 5 IS A REVIEW FINDING. A `partial` runs improve-or-restore, which
  # spends a `browser_refresh … 1` -> `browser_reload` -> `signal_list bg`. On
  # this fixture that context loan is refused (`.wvbn1.drw` is not an xschem
  # window) so the seed survives, and the restore arm would save it too — but
  # nothing SAID so, and a change that made the loan succeed would silently
  # replace the seeded inventory with `{}` for every check after this one.
  set bn_old [pcall ::wviewer::browser_show_path bg x1.x1.M18]
  check {BN32 the SCHEMATIC spelling still lands on the parent, ticks nothing,\
         and leaves the seeded inventory intact} \
    [list [lindex $bn_old 0] [lindex $bn_old 2] [lindex $bn_old 3] \
          [pcall ::wviewer::browser_devint bg] \
          [llength $::wviewer::browsersigs(bg)]] {partial x1.x1 x1.x1.M18 0 11}

  # ⚠⚠ AND THE FIX, END TO END THROUGH THE SHIPPED PROBE: the same gesture with
  # the NETLIST spelling ticks the box on the user's behalf, re-resolves, lands
  # ON THE DEVICE and reports the tenth kind. Item 18's whole promise.
  bn_reset 0
  set bn_new [pcall ::wviewer::browser_show_path bg x1.x1.XM18]
  set bn_sel2 {}
  catch {set bn_sel2 [$BNTV selection]}
  check {BN33 the NETLIST spelling ticks the box, reaches the device and says so} \
    [list [lindex $bn_new 0] [lindex $bn_new 1] [lindex $bn_new 2] \
          [pcall ::wviewer::browser_devint bg] $bn_sel2] \
    {unhidden g:x1.x1.xm18 x1.x1.xm18 1 g:x1.x1.xm18}

  # ⚠ THE SENTENCE, THROUGH THE ONE FORMATTER. BK34's oracle is that every kind
  # is phrased in `browser_msg` and nowhere else; this file adds no twelfth kind
  # and asserts the tenth verbatim.
  check {BN34 the sentence is R12's own, verbatim} \
    [pcall ::wviewer::browser_msg $bn_new] \
    {showing device internals to reach x1.x1.xm18}

  # ⚠ THE CASE FALLBACK IS WHAT LANDS IT. `XM18` is not in the tree; `xm18` is.
  bn_reset 0
  set bn_lc [pcall ::wviewer::browser_show_path bg x1.x1.xm18]
  check {BN35 the already-lower-cased spelling lands identically} \
    [list [lindex $bn_lc 0] [lindex $bn_lc 2]] {unhidden x1.x1.xm18}

  # ⚠⚠ THE `==` THE ISSUE FORBIDS RELAXING, RE-MEASURED FROM THIS FILE. A path
  # that resolves DEEPER with internals shown (3 of 4) but not FULLY must leave
  # the box alone and report the shallower `partial`. `BK43` owns this claim;
  # it is repeated here because this file is the one that changes what gets
  # asked, and a future crew reading only this file must find the limit.
  bn_reset 0
  set bn_deep [pcall ::wviewer::browser_show_path bg x1.x1.XM18.zznosuch]
  check {BN36 deeper-but-not-full still does NOT tick the box (BK43's limit)} \
    [list [lindex $bn_deep 0] [lindex $bn_deep 2] \
          [pcall ::wviewer::browser_devint bg]] {partial x1.x1 0}

  # -------------------------------------------------------------------------
  # BN4x — THE REAL GESTURE, on the REAL design. Only the session plumbing is
  # stubbed (`be_drive_on`'s idiom): `hier_now`, `browser_sel_segment`,
  # `inst_path_segment`, `browser_origin_drop`, the digital probe, the
  # resolver, the R12 probe and both echoes are the shipped code, running
  # against the real schematic hierarchy and the seeded tree.
  # -------------------------------------------------------------------------
  set bn_lines {}
  if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::bn_saved_ciw_echo }
  proc ::ciw_echo {msg {tag {}}} {
    if {[string first {ase: signal browser} $msg] == 0} {
      lappend ::bn_lines [list $tag $msg]
    }
    if {[info commands ::bn_saved_ciw_echo] ne {}} {
      catch {::bn_saved_ciw_echo $msg $tag}
    }
  }
  proc bn_drive_on {} {
    foreach p {::ase::session_for_current ::wviewer::open \
               ::wviewer::browser_shown} {
      if {[info commands $p] ne {}} { rename $p ${p}_bnsaved }
    }
    proc ::ase::session_for_current {} { return [list bg 0] }
    proc ::wviewer::open {token} { return 1 }
    proc ::wviewer::browser_shown {{token {}}} { return 1 }
  }
  proc bn_drive_off {} {
    foreach p {::ase::session_for_current ::wviewer::open \
               ::wviewer::browser_shown} {
      if {[info commands ${p}_bnsaved] ne {}} {
        catch {rename $p {}}
        rename ${p}_bnsaved $p
      }
    }
  }

  pcall xschem load $bn_tb
  pcall xschem descend -inst x1
  pcall xschem descend -inst x1
  pcall xschem select instance M18 fast
  bn_reset 0
  set ::bn_lines {}
  bn_drive_on
  set bn_ret [pcall ase::show_in_browser_for_current]
  bn_drive_off
  update
  set bn_sel3 {}
  catch {set bn_sel3 [$BNTV selection]}
  # ⚠ THE NAME SAYS "the gesture's command", NOT "Ctrl-Alt-V": no key event is
  # delivered here. The chord -> `ase::show_in_browser_for_current` binding is a
  # C action-registry row (two-pane item 17 R10) and is not this file's subject.
  check {BN41 THE REPRO, through the gesture's own command: the box ticks and\
         the device is selected} \
    [list $bn_ret [pcall ::wviewer::browser_devint bg] $bn_sel3] \
    {bg 1 g:x1.x1.xm18}

  # ⚠ THE GESTURE'S WHOLE CIW ACCOUNT (issue 0315 ruling 1): one `ase: ` line,
  # not tagged an error, carrying R12's sentence.
  check {BN42 and its account is ONE plain line, R12's sentence} \
    $::bn_lines \
    [list [list {} {ase: signal browser: showing device internals to reach\
 x1.x1.xm18}]]

  # ⚠ THE CONTROL: the half of the gesture that already worked. Selecting the
  # SUBCIRCUIT `x1` one level up must still land on `x1.x1` with the box
  # untouched — a fix that prefixed everything would red this.
  pcall xschem go_back
  pcall xschem select instance x1 fast
  bn_reset 0
  set ::bn_lines {}
  bn_drive_on
  set bn_ret2 [pcall ase::show_in_browser_for_current]
  bn_drive_off
  update
  set bn_sel4 {}
  catch {set bn_sel4 [$BNTV selection]}
  check {BN43 CONTROL: the subcircuit selection is unchanged by this fix} \
    [list $bn_ret2 [pcall ::wviewer::browser_devint bg] $bn_sel4 $::bn_lines] \
    [list bg 0 g:x1.x1 [list [list {} {ase: signal browser: showing x1.x1}]]]

  # ⚠⚠ BN44 — THE FALL-THROUGH, AND IT IS THE FIX'S OWN JUSTIFICATION MADE
  # BEHAVIOURAL. Two review findings meet here:
  #   (a) 6b's last-mile retry (`browser_show_path $key [join $base .]`) was
  #       driven by NOTHING in this file, so swapping `$base` for `$segs` — one
  #       token, inside the block this fix edits — was measured green on all 30
  #       checks while turning the retry into a re-ask of the same failing path
  #       and painting the log red.
  #   (b) the reason `$selname` KEEPS the schematic spelling is that this
  #       sentence names it. That claim had only a source grep behind it.
  # `M8` is a prefixed FET on a sheet whose `XM8` matches nothing in the seeded
  # tree, so `matched` is 0, the answer is `err`, and 6b retries the bare
  # hierarchy position. The sentence must say **'M8'** — what the user pointed
  # at — and not `XM8`, which they never typed.
  pcall xschem load $bn_fx
  pcall xschem select instance M8 fast
  bn_reset 0
  set ::bn_lines {}
  bn_drive_on
  set bn_ret3 [pcall ase::show_in_browser_for_current]
  bn_drive_off
  update
  check {BN44 a segment with no level: 6b retries the BASE and the sentence\
         names the SCHEMATIC's M8, and nothing is red} \
    [list $bn_ret3 [pcall ::wviewer::browser_devint bg] $::bn_lines] \
    [list bg 0 [list [list {} {ase: signal browser: 'M8' has no level in the\
 simulation data; showing the design root instead}] \
                [list {} {ase: signal browser: showing the simulation top level}]]]

  catch {rename ::ciw_echo {}}
  if {[info commands ::bn_saved_ciw_echo] ne {}} {
    rename ::bn_saved_ciw_echo ::ciw_echo
  }
  pcall ::wviewer::forget bg
  catch {destroy .wvbn1}
  catch {dict unset ::wviewer::windows bg}
} else {
  puts "SKIP: BN3x/BN4x need X (no \$has_x)"
}

wvbs_finish
