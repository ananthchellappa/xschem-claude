# tests/headless/test_op_dump_altshow.tcl — the blanket operating-point dump.
#
# ============================================================================
# WHAT IS UNDER TEST
# ============================================================================
# Two halves of one road, and they must agree on a spelling neither of them
# owns alone:
#
#   ASKING   ase.tcl's render_deck shape `d`, which puts two lines inside
#            `.control` and NAMES NO DEVICE ANYWHERE:
#                op
#                set altshow
#                show all > <rawroot>.opinfo
#   READING  op_annot::opdump_read, which parses that file and MERGES it into
#            the already-loaded results database with `xschem raw add`, then
#            republishes with `xschem update_op`.
#
# ⚠ THE ORDER IS THE POINT, AND IT IS THE ONE THING A REFACTOR WILL BREAK.
# `show` reports whatever CKT state is CURRENT — it is not a stored plot. The
# dump must therefore follow `op` and precede every other analysis. The other
# shapes' `save` requests must PRECEDE their analysis, so the two travel in
# different carriers (optier_ctl vs optier_post) and land in different places.
# Row D3 is what stops someone merging them back into one and silently dumping
# an unsolved circuit at exit 0.
#
# ⚠ THE PATH IS LOWERCASED ON PURPOSE. ngspice case-folds a `show >` redirect
# target, directory component included, and exits 0 when the folded directory
# does not exist. Asking side and reading side therefore derive the path from
# ONE proc, op_annot::opdump_path. Row P2 pins that; delete the fold and a
# mixed-case simulation directory produces a green run and no data.
# ============================================================================

set fail 0
set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch op_dump_altshow]

## ⚠ THIS SUITE REGISTERS SIMULATORS, AND REGISTRATION NOW REACHES THE DISK
## (2026-09-08). ase::sim_register persists the registry into
## $::USER_CONF_DIR/ase_simulators at the moment it changes, which is the
## developer's own ~/.xschem/ase_simulators here. The stubs below are /bin/sh
## and deliberately broken files; writing them over the user's real list would
## take away the build they actually use. This suite is not ABOUT the saving,
## so it opts out of it -- the one test seam ase::sim_touch honours.
catch {set ::ase::sim_autosave 0}
set T_OLDPWD [pwd]

## H1's untitled* BASELINE (issues 0609, 1480 §5) -- the twin of test_ase_core's
## C11, and 0609 §2.1 names the two rows as a pair. H1 used to glob $repo alone and
## assert the count was 0, which made it a probe of FOREIGN machine state: inside
## full_audit.sh (`cd "$REPO"`, :64) whichever of the ~80 leaking suites sorts first
## hands this one a red it had no part in. Measured 2026-09-17: with a foreign
## untitled~.sch + untitled~.sym planted in the repo root, the otherwise-clean suite
## reported `FAIL: H1 ... -> {0} (exp {1})` while leaking nothing itself.
##
## ⚠ THE CWD IS WATCHED TOO, NOT JUST $repo, and the list is FIXED HERE. xschem
## names the untitled buffer under $env(PWD) when set (src/save.c:6492-6497,
## src/xinit.c:3917-3919) and otherwise under the STARTUP getcwd (src/xinit.c:3175);
## a Tcl `cd` moves neither (src/xinit.c:174, issue 0323), so the :938 `cd $T_OLDPWD`
## cannot change where litter lands and re-deriving the list at the row would only
## score pre-existing files in a new directory as new.
set h1_dirs {}
foreach d [list $repo [expr {[info exists ::env(PWD)] ? $::env(PWD) : {}}] $T_OLDPWD] {
  if {$d eq {}} continue
  set n [file normalize $d]
  if {[lsearch -exact $h1_dirs $n] < 0} { lappend h1_dirs $n }
}
proc h1_litter_snap {} {
  global h1_dirs
  set out {}
  foreach d $h1_dirs {
    foreach f [glob -nocomplain -directory $d -tails untitled*] {
      lappend out [file join $d $f]
    }
  }
  return [lsort $out]
}
set h1_pre [h1_litter_snap]

# ============================================================================
# P — THE PATH, DERIVED ONCE
# ============================================================================
check {P1 opdump_path replaces the raw's extension with .opinfo} \
  [::op_annot::opdump_path /a/b/CellName_ase.raw] {/a/b/cellname_ase.opinfo}

check {P2 opdump_path LOWERCASES the whole path, directory included, because ngspice case-folds the redirect target and then exits 0 having written nothing} \
  [::op_annot::opdump_path /Sim/RunDir/Cell.raw] {/sim/rundir/cell.opinfo}

check {P3 the request is exactly two lines, names no device, and asks the wide question so resistors and capacitors are not silently dropped} \
  [::op_annot::opdump_request /x/y/z.raw] \
  {{set altshow} {show all > /x/y/z.opinfo}}

# ============================================================================
# D — THE DECK SHAPE
# ============================================================================
set NL "** sch_path: /zz.sch\n**.subckt zzcell\nV1 a 0 1\n**.ends\n.end\n"
set BLK ".save all\n.save @m.xz1.mzmod\[id\]\n.save @m.xz1.mzmod\[gm\]\n"

proc d_state {} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create lib zzlib cell zzcell view schematic]
  dict set st rundir [file join $scratch orun]
  dict set st analyses {{type op enabled 1} {type dc enabled 0}
                        {type ac enabled 0} {type tran enabled 1 step 1n stop 5n}}
  dict set st save_op_params 1
  return $st
}
proc d_control {deck} {
  set out {} ; set inb 0
  foreach l [split $deck "\n"] {
    set t [string trim $l]
    if {$t eq {.control}} { set inb 1 ; continue }
    if {$t eq {.endc}} { break }
    if {$inb && $t ne {}} { lappend out $t }
  }
  return $out
}
ase::op_cards_put $NL $BLK
set RENDER [ase::backend_hook ngspice render_deck]
ase::op_tier_force_set d
set DECK [$RENDER [d_state] $NL]
set CTL  [d_control $DECK]

check {D1 shape d puts NO per-device .save card in the deck at all} \
  [regexp -all -line {^\.save @} $DECK] 0

check {D2 shape d emits the deck-level `.save all` that carries the node half for free} \
  [regexp -all -line {^\.save all$} $DECK] 1

set i_op   [lsearch -exact $CTL {op}]
set i_alt  [lsearch -exact $CTL {set altshow}]
set i_show [lsearch -glob  $CTL {show all > *}]
check_true {D3 the dump follows `op` IMMEDIATELY -- show reads live CKT state, so anything between the solve and the dump silently reports the wrong analysis} \
  [expr {$i_op >= 0 && $i_alt == $i_op + 1 && $i_show == $i_op + 2}]

check_true {D4 the requested path is the one opdump_read will look in} \
  [string match "show all > [::op_annot::opdump_path [file join $scratch orun zzcell_ase.raw]]" \
                [lindex $CTL $i_show]]

check_true {D5 no `save` REQUEST line rides along -- shape d asks for nothing per device} \
  [expr {[lsearch -glob $CTL {save all @*}] < 0}]

# The contrast row: the same state on the shipped per-device shape.
ase::op_tier_force_set c
set CTLC [d_control [$RENDER [d_state] $NL]]
check_true {D6 CONTRAST shape c names devices in a `save` request BEFORE op, which is why the two shapes cannot share one carrier} \
  [expr {[lsearch -glob $CTLC {save all @m.xz1.mzmod*}] >= 0 &&
         [lsearch -glob $CTLC {save all @m.xz1.mzmod*}] < [lsearch -exact $CTLC {op}]}]
ase::op_tier_force_set {}

# ============================================================================
# R — THE READER, AND THE THREE SILENT FAILURES IT REFUSES TO PASS ON
# ============================================================================
set DUMP [file join $scratch d.opinfo]
set fh [open $DUMP w]
puts $fh "m.x1.xm1.mnfet:"
puts $fh "    model              = x1.xm1:nshort_model.42"
puts $fh "    id                 = 5.33333e-05"
puts $fh "    gm                 = 0.000266667"
puts $fh "    vdsat              = -"
puts $fh "q.x1.xq1.qpnp:"
puts $fh "    vbe                = 0.773303"
puts $fh "v5:"
puts $fh "    pulse              = 1.81071"
puts $fh "    pulse              = 0"
puts $fh "    pulse              = 2.5e-05"
close $fh

check_true {R1 G1 a MISSING dump raises rather than returning empty -- ngspice exits 0 when `show >` cannot write, so a green run proves nothing} \
  [catch {::op_annot::opdump_read [file join $scratch nosuch.opinfo]}]

set EMPTY [file join $scratch e.opinfo]
close [open $EMPTY w]
check_true {R2 an EMPTY dump raises} [catch {::op_annot::opdump_read $EMPTY}]

set LEG [file join $scratch legacy.opinfo]
set fh [open $LEG w]
puts $fh "     device m.x1.x23.xm2.msky130_ m.x1.x23.xm1.msky130_"
puts $fh "         id       2.1e-12       3.4e-12"
close $fh
set legrc [catch {::op_annot::opdump_read $LEG} legmsg]
check_true {R3 G3 the LEGACY (non-altshow) layout is detected and refused -- its names are truncated to 21 chars and unusable} $legrc
check_true {R4 and the refusal names the remedy, including that `set altshow=1` does NOT work because the variable is read as CP_BOOL} \
  [expr {[string match {*set altshow*} $legmsg] && [string match {*altshow=1*} $legmsg]}]

# The happy path needs a database to merge into. A one-point op raw is enough.
set RAW [file join $scratch n.raw]
set fh [open $RAW w]
puts $fh "Title: t"
puts $fh "Plotname: Operating Point"
puts $fh "Flags: real"
puts $fh "No. Variables: 2"
puts $fh "No. Points: 1"
puts $fh "Variables:"
puts $fh "\t0\tv(vbg)\tvoltage"
puts $fh "\t1\tv(vcc)\tvoltage"
puts $fh "Values:"
puts $fh "0\t1.2"
puts $fh "\t1.8"
close $fh
set readrc [catch {xschem raw read $RAW} rr]
check_true {R5 the node-only raw loads as an operating point} \
  [expr {$readrc == 0 && [xschem raw sim_type] eq {op}}]
set nbefore [xschem raw vars]
set D [::op_annot::opdump_read $DUMP]

check {R6 every device block is counted} [dict get $D devices] 3
check {R7 only NUMERIC bodies are injected -- the model string and the `-` placeholder are declined, not stored} \
  [dict get $D params] 4
check {R8 and the declined lines are COUNTED rather than silently dropped, which is what a throwaway parser does} \
  [dict get $D skipped] 2
check {R9 a vector parameter repeats ONE key per coefficient; FIRST wins and the rest are counted, so a coefficient is never stored as if it were the parameter} \
  [dict get $D dups] 2

check_true {R10 the merge ADDS to the loaded database rather than replacing it -- the node half must survive} \
  [expr {[xschem raw vars] == $nbefore + 4}]

check {R11 a device parameter now resolves through the UNCHANGED op_annot accessor, via _wrap_alts' bare spelling (issue 0963)} \
  [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[id]}] {5.33333e-05}
check {R12 a BIPOLAR resolves too -- a class the per-device shape never emitted a single card for} \
  [::op_annot::raw_or_blank {@q.x1.xq1.qpnp[vbe]}] {0.773303}
check {R13 and the node voltages that were already there are untouched} \
  [::op_annot::raw_or_blank {v(vbg)}] {1.2}
check {R14 a declined parameter is BLANK, never a fabricated zero} \
  [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[vdsat]}] {}

catch {xschem raw clear}

# ============================================================================
# V — THE VERDICT, AS A PURE FUNCTION
# ============================================================================
# ⚠ THE QUESTION IS THE DEFECT, NOT THE FEATURE. Every ngspice since ng-37 /
# ngspice-22 has `altshow`, the distro package included, so asking "is it
# there" separates nothing. What decides whether the dump is READABLE is the
# printer fix 10276f993, which `git tag --contains` places in NO release -- so
# no version string can answer it either. Given a source declared `pwl`, an
# unfixed printer replays that source's coefficients under eight names.
set V_FIXED "vpw:\n    dc                 = 0\n    pulse              =         -\n    sin                =         -\n    pwl                = 0\n    pwl                = 1e-06\n"
set V_BROKEN "vpw:\n    dc                 = 0\n    pulse              = 0\n    pulse              = 1e-06\n    sin                = 0\n    sin                = 1e-06\n    pwl                = 0\n"
set V_LEGACY "     device m.x1.x23.xm2.msky130_\n         id       2.1e-12\n"

check {V1 a SOUND printer -- only the declared `pwl` carries numbers, the other seven waveform keywords are placeholders} \
  [ase::cap_altshow_verdict $V_FIXED] 1
check {V2 an UNFIXED printer is caught by `sin` carrying the PWL source's own coefficients, which is the uninitialised-value replay} \
  [ase::cap_altshow_verdict $V_BROKEN] 0
check {V3 the LEGACY column format has no block headers at all and is refused, so a lost `set altshow` cannot read as a pass} \
  [ase::cap_altshow_verdict $V_LEGACY] 0
check {V4 an empty dump is not a pass} [ase::cap_altshow_verdict {}] 0

# ============================================================================
# T — THE TIER GUARD, DRIVEN OFF A PRIMED ANSWER (no simulator is started)
# ============================================================================
set STUB [file join $scratch stub_ngspice]
set fh [open $STUB w]; puts $fh "#!/bin/sh\nexit 0"; close $fh
file attributes $STUB -permissions 0755

proc t_tier {caps {dir {}}} {
  global STUB scratch
  if {$dir eq {}} { set dir [file join $scratch orun] }
  catch {ase::sim_caps_clear} ; catch {ase::sim_clear}
  ase::sim_register optier $STUB
  ase::sim_select optier
  set r [dict get [ase::sim_status ngspice] resolved]
  ## ⚠ THE KEY IS ASKED FOR, NEVER SPELLED (issue 1371, and see that file's
  ## tail). The capability store was re-keyed from the resolved PATH to
  ## `ase::cap_key {resolved eargs}`; a hand-spelled key here writes at an
  ## address the reader has left, every primed answer goes invisible, and the
  ## tier falls through to a LIVE probe of whatever ngspice the bench can
  ## resolve. Measured cost when that happened: nine rows of this file
  ## (T1..T5, X5, X6, N1, N3) reporting that binary's `{c nocap}` instead of
  ## the fixture's answer.
  set ::ase::sim_caps [dict create [ase::cap_key $r {}] \
                        [list stamp [ase::cap_stamp $r] caps $caps]]
  set st [ase::state_default]
  dict set st design [dict create lib zzlib cell zzcell view schematic]
  dict set st rundir $dir
  dict set st analyses {{type op enabled 1}}
  dict set st save_op_params 1
  set d [ase::op_save_tier $st]
  return [list [dict get $d tier] [dict get $d reason]]
}
set C_BASE {known 1 usable 1 appendwrite 1 hier_op_names 1 blanket_op_save 0}

check {T1 a measured-SOUND printer selects shape d} \
  [t_tier [dict merge $C_BASE {altshow_op_dump 1}]] {d dump}
## ⚠ `c unsafe`, NOT `c nocap`, AND THAT IS THE POINT. Falling past the new
## guard lands on the EXISTING G4 demotion, because this stand-in also answers
## yes to appendwrite and hier_op_names. Both reach the per-device shape -- the
## one that always works -- and the reason token is what says which guard got
## there. A row expecting `nocap` here would be asserting that the new guard
## had swallowed G4.
## ⚠ MOVED BY ISSUE 1470 (Stage 16d): `c unsafe` -> `c dumpunsound`, THE SHAPE
## UNCHANGED. A printer MEASURED broken now lands on G4a, which is G4's shape
## with the actual reason -- "your simulator was measured printing wrong numbers
## that way" -- where `unsafe` said something true that was not the reason. T3
## below is the control: an ABSENT key still reads `unsafe`, because not looking
## is not the same as looking and finding it broken.
check {T2 a measured-BROKEN printer falls past shape d to the per-device shape, through the EXISTING G4 demotion} \
  [t_tier [dict merge $C_BASE {altshow_op_dump 0}]] {c dumpunsound}
check {T3 an ABSENT key means "not measured", never "yes" -- a leg that ran out of budget must not promote the deck} \
  [t_tier $C_BASE] {c unsafe}
check {T4 nothing measured at all still refuses shape d} \
  [t_tier {known 0 unmeasured timeout}] {c unknown}
check {T5 ORDERING d beats a: shape a's capability is cold code on every released ngspice, so a build answering both must take the shape whose printer was actually watched working} \
  [t_tier [dict merge $C_BASE {blanket_op_save 1 altshow_op_dump 1}]] {d dump}
catch {ase::sim_caps_clear} ; catch {ase::sim_clear}

# ============================================================================
# X — THE PATH THE DUMP CANNOT REACH (issue 1334)
# ============================================================================
# ngspice case-folds the WHOLE `show >` target, directory included, and splits
# it on whitespace -- both silently, at exit 0, with nothing written.
#
# MEASURED END TO END on the ver_50 build that carries the printer fix, same
# cell (sky130_tests/test_nfet_final), only the run directory changed:
#
#   rundir `lower_ok`   -> probe 1, tier d, exit 0, .opinfo written
#   rundir `MixedCase`  -> probe 1, tier d, exit 0, .opinfo *** NOT WRITTEN ***
#                          raw perfect, log clean, annotation five rows blank
#   CONTROL, same rundir, per-device shape on 45.2 -> all five rows annotate
#
# So the fold is not a shared hazard the older shape also has: it is a
# regression this shape introduces, and the probe cannot see it because deck C
# asks with a RELATIVE target (`show all > probe_c.txt`) that has nothing to
# fold. The question therefore gets asked where the answer is known -- before
# the shape is chosen -- and a path the redirect cannot survive takes the
# per-device form, which is the one that always works.
check_true {X1 a lowercase, space-free directory is reachable} \
  [ase::op_dump_reachable_dir /home/u/sim]
check_true {X2 a MIXED-CASE directory is NOT reachable: ngspice folds it, writes nothing, and exits 0} \
  [expr {![ase::op_dump_reachable_dir /home/u/MixedCase]}]
check_true {X3 nor is one containing a SPACE -- the redirect is unquoted and ngspice splits on it} \
  [expr {![ase::op_dump_reachable_dir {/home/u/with space}]}]
check_true {X4 an unknown directory is not reachable: refusing is what lands on the shape that always works} \
  [expr {![ase::op_dump_reachable_dir {}]}]
check {X5 a SOUND printer under a MIXED-CASE run directory does not take shape d, and the reason token says which guard refused} \
  [t_tier [dict merge $C_BASE {altshow_op_dump 1}] [file join $scratch OrunMixed]] {c dumppath}
check {X6 the same printer under a lowercase directory still takes shape d, so the guard is not simply off} \
  [t_tier [dict merge $C_BASE {altshow_op_dump 1}] [file join $scratch orun2]] {d dump}

# ============================================================================
# W — THE WIRING: the dump is MERGED WHEN THE RAW IS ATTACHED (issue 1333)
# ============================================================================
# ⚠ THE FEATURE AS FIRST WRITTEN HAD NO CALLER AT ALL. `opdump_read` was
# defined and tested and nothing in the tree invoked it, so shape d -- which
# emits NO per-device card -- left the raw with no device parameters and every
# annotation row blank. MEASURED on the ver_50 build, same cell, tier d:
# `op_annot::text M1` rendered `id =  gm =  gds =  vgs =  vth =  vds =`, which
# is issue 0617 verbatim, the defect the whole feature exists to remove.
#
# The merge goes in `op_annot::db_attach` rather than in a run callback for two
# reasons that were both measured: `xschem raw add` raises "No raw file loaded"
# unless a database is already on the window, and db_attach is the ONE place
# that puts an operating point onto a window -- ASE-L's surface and the cadence
# profile both come through it, so one call covers both.
set WDIR [file join $scratch wattach]
file mkdir $WDIR
set WRAW [file join $WDIR w.raw]
set fh [open $WRAW w]
puts $fh "Title: t"
puts $fh "Plotname: Operating Point"
puts $fh "Flags: real"
puts $fh "No. Variables: 2"
puts $fh "No. Points: 1"
puts $fh "Variables:"
puts $fh "\t0\tv(vbg)\tvoltage"
puts $fh "\t1\tv(vcc)\tvoltage"
puts $fh "Values:"
puts $fh "0\t1.2"
puts $fh "\t1.8"
close $fh
check {W1 the sidecar is named from the raw by the ONE proc both sides use} \
  [file tail [::op_annot::opdump_path $WRAW]] {w.opinfo}

set WDUMP [::op_annot::opdump_path $WRAW]
set fh [open $WDUMP w]
puts $fh "m.x1.xm1.mnfet:"
puts $fh "    id                 = 5.33333e-05"
puts $fh "    gm                 = 0.000266667"
close $fh
# the dump must not look older than the raw it belongs to
file mtime $WDUMP [expr {[file mtime $WRAW] + 1}]

catch {xschem raw clear}
set watt [::op_annot::db_attach $WRAW]
check_true {W2 the raw attaches} [lindex $watt 0]
check {W3 ATTACHING A RAW MERGES THE SIDECAR DUMP -- without this the row is blank and nothing anywhere says why} \
  [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[id]}] {5.33333e-05}
check {W4 and the node half the deck's own `.save all` supplied is untouched by the merge} \
  [::op_annot::raw_or_blank {v(vbg)}] {1.2}

## ⚠ A STALE SIDECAR IS NOT MERGED, for issue 0838's reason exactly: a number
## painted onto a schematic carries no provenance, so one from an earlier run
## is indistinguishable from a live one. The raw gets a stale-check by
## `ase::results_stale`; the sidecar gets this one, against the raw it claims
## to belong to.
set WRAW2 [file join $WDIR w2.raw]
file copy -force $WRAW $WRAW2
set WD2 [::op_annot::opdump_path $WRAW2]
set fh [open $WD2 w] ; puts $fh "m.x1.xm1.mnfet:" ; puts $fh "    id                 = 9.99e-09" ; close $fh
file mtime $WD2 [expr {[file mtime $WRAW2] - 60}]
catch {xschem raw clear}
set watt2 [::op_annot::db_attach $WRAW2]
check_true {W5 the raw still attaches when its sidecar is stale -- the node half is good and refusing it would be worse} \
  [lindex $watt2 0]
check {W6 but a sidecar OLDER than its raw is NOT merged, so a previous run's device numbers cannot be painted on} \
  [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[id]}] {}
check_true {W7 and a raw with no sidecar at all attaches exactly as it always did} \
  [expr {[lindex [::op_annot::db_attach $RAW] 0] == 1}]
catch {xschem raw clear}

# ============================================================================
# W8 .. W15 — THE SECOND DOOR: `xschem annotate_op`, WHICH NEVER MERGED
#            (issue 1364)
# ============================================================================
# ⚠ ISSUE 1333 WIRED ONE DOOR AND THE COMMENT IT WROTE SAID SO IN WORDS THAT
# WERE FALSE. It put the merge in `op_annot::db_attach` "because db_attach is
# the ONE place that puts an operating point onto a window". It is not.
# `xschem annotate_op` is the general-purpose verb, and NOTHING that reaches it
# directly came through db_attach:
#
#   * 61 committed schematics carry a launcher whose
#     `tclcommand="xschem annotate_op …"` is the button the user presses
#     (xschem_library/examples, sky130A/xschem_libs/sky130_tests, …);
#   * `Simulation > Graphs > Annotate Operating Point into schematic` and the
#     waveform window's `Waves > Op Annotate` are both a bare `xschem
#     annotate_op` -- rows F36-F41 of tests/headless/test_annot_stale_0684.tcl
#     say exactly that in their own header;
#   * `open_sub_schematic` and `hi_descend` carry an annotated raw into a new
#     window/tab with `xschem annotate_op $rawfile` (src/xschem.tcl);
#   * `cadence::_annot_tran_supply`'s second ask (utils/annot_mode.tcl);
#   * `results::select` -> `xschem raw select`, and the cadence Alt-6 rungs,
#     which acquire with `xschem raw read` / `xschem raw switch` and publish
#     with `xschem update_op`.
#
# MEASURED on the user's own registry (ngspice-ver50 -> `ase::op_save_tier`
# answers `tier d reason dump`): after a real run, `xschem annotate_op <raw> 0
# op` rendered `id` and left `gm gds vgs vth vds` BLANK. The one row that
# appeared is the accident -- `.options savecurrents` puts `i(@dev[id])` in the
# raw with no card present (test_ase_final's own F18 trap) -- so the feature's
# own five were exactly the five that vanished. Issue 0617 restored.
#
# THE FIX IS ONE CALL IN THE ONE CHOKE POINT: update_op() (src/save.c) calls
# op_annot::opdump_autofill below its three refusals and above its publish.
# These rows drive the door WITHOUT db_attach anywhere, which is what makes
# them red on a tree that wires only the first door.
## ⚠ EVERY FIXTURE BELOW GETS ITS OWN DIRECTORY, and that is not tidiness.
## Row W10's subject is a raw with NO sidecar; with the fixtures sharing one
## directory, a door that fell back to "any .opinfo next door" would still find
## one and W10 could not tell. One raw per directory is what makes the absence
## real.
proc w_dir {tag} {
  set d [file join $::scratch xdoor $tag]
  file mkdir $d
  return $d
}

## one-point Operating Point raw, node half only — the shape `d` leaves behind
proc w_oppoint {path} {
  set fh [open $path w]
  puts $fh "Title: t"
  puts $fh "Plotname: Operating Point"
  puts $fh "Flags: real"
  puts $fh "No. Variables: 2"
  puts $fh "No. Points: 1"
  puts $fh "Variables:"
  puts $fh "\t0\tv(vbg)\tvoltage"
  puts $fh "\t1\tv(vcc)\tvoltage"
  puts $fh "Values:"
  puts $fh "0\t1.2"
  puts $fh "\t1.8"
  close $fh
}
## a sidecar for <raw>, <age> seconds newer than it (negative = stale)
proc w_sidecar {raw dev age {body {}}} {
  set d [::op_annot::opdump_path $raw]
  set fh [open $d w]
  puts $fh "${dev}:"
  if {$body eq {}} {
    puts $fh "    id                 = 5.33333e-05"
    puts $fh "    gm                 = 0.000266667"
  } else {
    puts $fh $body
  }
  close $fh
  file mtime $d [expr {[file mtime $raw] + $age}]
  return $d
}
## is <name> a column of the CURRENTLY loaded database?  Asked of `raw list`
## rather than of a value, because a transient publishes nothing either way and
## a row built on the value could not tell "refused to merge" from "refused to
## publish".
proc w_hascol {name} {
  set l {}
  if {[catch {xschem raw list} l]} { return -1 }
  return [expr {[lsearch -exact [split $l "\n"] $name] >= 0 ? 1 : 0}]
}

set XRAW [file join [w_dir x] x.raw]
w_oppoint $XRAW
set XDUMP [w_sidecar $XRAW {m.x1.xm1.mnfet} 1]
catch {xschem raw clear}
set x8rc [catch {xschem annotate_op $XRAW}]
check {W8 THE SECOND DOOR: `xschem annotate_op` alone -- no db_attach anywhere -- merges the sidecar, and the node half the deck's own `.save all` supplied survives beside it} \
  [list $x8rc [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[id]}] \
        [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[gm]}] \
        [::op_annot::raw_or_blank {v(vbg)}]] \
  {0 5.33333e-05 0.000266667 1.2}

check {W12 and a SECOND publish over the same database is idempotent: same rows, no column added -- which is what makes one call site in the choke point enough instead of one per door} \
  [list [xschem raw vars] \
        [expr {[catch {xschem update_op}] ? {RAISED} : {ok}}] \
        [xschem raw vars] \
        [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[id]}]] \
  [list 4 ok 4 5.33333e-05]

## W13 -- THE ACQUIRE-THEN-PUBLISH RUNGS. `cadence::_annot_op_db_ok` rung 3
## reads with `xschem raw read` (which deliberately does NOT publish) and then
## publishes with `xschem update_op`; rung 2 does the same through `xschem raw
## switch`, and `results::select` through `xschem raw select`. None of them ever
## calls annotate_op, so the merge has to be where the PUBLISH is, not where the
## read is. The first term is the non-vacuity half: the column must be ABSENT
## after the read, or the row would pass on a tree that merged at read time.
catch {xschem raw clear}
catch {xschem raw read $XRAW op}
set x13a [w_hascol {@m.x1.xm1.mnfet[id]}]
catch {xschem update_op}
check {W13 a raw acquired with `xschem raw read` and published with `xschem update_op` -- the cadence Alt-6 rungs and `results::select`'s road -- gets the merge at the publish, not at the read} \
  [list $x13a [w_hascol {@m.x1.xm1.mnfet[id]}] \
        [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[id]}]] \
  {0 1 5.33333e-05}

## W9 -- ISSUE 0838's RULE MUST SURVIVE THE NEW DOOR. A number painted onto a
## schematic carries no provenance and no timestamp, so a sidecar left behind by
## an EARLIER run is indistinguishable from a live one. `opdump_merge` refuses
## one older than its raw; the second door must not be a way round that.
set X9RAW [file join [w_dir x9] x9.raw]
w_oppoint $X9RAW
w_sidecar $X9RAW {m.x1.xm1.mnfet} -60
catch {xschem raw clear}
set x9rc [catch {xschem annotate_op $X9RAW}]
check {W9 the stale rule holds at the SECOND door too: a sidecar OLDER than its raw is not merged by `xschem annotate_op` either, and the raw still attaches because its node half is good} \
  [list $x9rc [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[id]}] \
        [::op_annot::raw_or_blank {v(vbg)}]] \
  {0 {} 1.2}

## W10 -- ISSUE 0975's SILENCE. A raw with no sidecar beside it is EVERY run of
## every other shape; the door must be a no-op there and must not raise, print
## or refuse. `ase::op_report_missing` is the one surface that speaks about a
## dump that did not arrive.
set X10RAW [file join [w_dir x10] x10.raw]
w_oppoint $X10RAW
catch {xschem raw clear}
set x10rc [catch {xschem annotate_op $X10RAW} x10err]
check {W10 a raw with NO sidecar annotates exactly as it always did -- no raise, no refusal, the node half published and the device column simply absent} \
  [list $x10rc [w_hascol {@m.x1.xm1.mnfet[id]}] \
        [::op_annot::raw_or_blank {v(vbg)}] \
        [expr {[file exists [::op_annot::opdump_path $X10RAW]] ? 1 : 0}]] \
  {0 0 1.2 0}

## W11 -- RULING D5-1: A TRANSIENT IS NEVER MERGED INTO. The dump is ONE
## snapshot; `gm` and `vth` move over a transient, so painting the snapshot flat
## across every time point would put a number nobody measured beside the thing
## it is drawn next to. `cadence::_annot_tran_supply` reaches `xschem
## annotate_op <path> <lvl>` as its SECOND ask and can land on a file that has
## a sidecar, which is why this is a real arm and not a hypothetical.
## Asked of `raw list`, not of a value: a transient publishes nothing either
## way, so a value-based row could not tell the two refusals apart.
##
## ⚠ ONE POINT, DELIBERATELY. A three-point transient is refused by the
## single-point gate before the type is ever consulted, so the row would have
## fenced W14's term twice and the TYPE gate not at all -- measured: removing
## `$ty ne {op} && $ty ne {dc}` left every row in this file green. At one point
## the type is the only thing standing between this raw and the merge.
set X11RAW [file join [w_dir x11] x11.raw]
set fh [open $X11RAW w]
puts $fh "Title: t"
puts $fh "Plotname: Transient Analysis"
puts $fh "Flags: real"
puts $fh "No. Variables: 2"
puts $fh "No. Points: 1"
puts $fh "Variables:"
puts $fh "\t0\ttime\ttime"
puts $fh "\t1\tv(vbg)\tvoltage"
puts $fh "Values:"
puts $fh "0\t0"
puts $fh "\t1.0"
close $fh
w_sidecar $X11RAW {m.x1.xm1.mnfet} 1
catch {xschem raw clear}
set x11rc [catch {xschem annotate_op $X11RAW -1 tran}]
check {W11 a TRANSIENT is never merged into, even with a fresh sidecar sitting beside it: the snapshot would be flat across every time point and RULING D5-1 forbids painting a number nobody measured} \
  [list $x11rc [xschem raw sim_type] [xschem raw points] \
        [w_hascol {@m.x1.xm1.mnfet[id]}]] \
  {0 tran 1 0}

## W14 -- AND NEITHER IS A MULTI-POINT DATABASE. update_op() is deliberately one
## term weaker than the `raw switch` / `raw select` gates (issue 0862: a
## multi-point .dc sweep still publishes its FIRST step), while `show` reports
## the state at the END of the run -- so merging here would paint the last
## step's numbers flat across the sweep and publish them as the first.
set X14RAW [file join [w_dir x14] x14.raw]
set fh [open $X14RAW w]
puts $fh "Title: t"
puts $fh "Plotname: DC transfer characteristic"
puts $fh "Flags: real"
puts $fh "No. Variables: 2"
puts $fh "No. Points: 3"
puts $fh "Variables:"
puts $fh "\t0\tv-sweep\tvoltage"
puts $fh "\t1\tv(vbg)\tvoltage"
puts $fh "Values:"
puts $fh "0\t0"
puts $fh "\t1.0"
puts $fh "1\t0.5"
puts $fh "\t1.1"
puts $fh "2\t1.0"
puts $fh "\t1.2"
close $fh
w_sidecar $X14RAW {m.x1.xm1.mnfet} 1
catch {xschem raw clear}
set x14rc [catch {xschem annotate_op $X14RAW -1 dc}]
check {W14 a MULTI-POINT dc sweep is not merged into either: the dump is one snapshot taken at the END of the run and update_op() publishes point 0, so the merge would label the last step as the first} \
  [list $x14rc [xschem raw sim_type] [xschem raw points] \
        [w_hascol {@m.x1.xm1.mnfet[id]}]] \
  {0 dc 3 0}

## W15 -- NO MERGE INSIDE A MERGE. `op_annot::opdump_read` republishes with
## `xschem update_op`, which is now one of the door's own entrances. Without the
## latch, a caller naming a dump BY HAND would silently get the current raw's
## sidecar pulled in behind it as well -- and the ordinary path would parse its
## own sidecar twice.
set X15RAW [file join [w_dir x15] x15.raw]
w_oppoint $X15RAW
w_sidecar $X15RAW {q.other.qpnp} 1 "    vbe                = 0.77"
catch {xschem raw clear}
catch {xschem raw read $X15RAW op}
set x15rc [catch {::op_annot::opdump_read $XDUMP}]
check {W15 a hand-driven `opdump_read <dump>` merges THAT dump and does not additionally pull in the current raw's own sidecar behind the caller's back} \
  [list $x15rc [w_hascol {@m.x1.xm1.mnfet[id]}] \
        [w_hascol {@q.other.qpnp[vbe]}]] \
  {0 1 0}

catch {xschem raw clear}

# ============================================================================
# Y — THE MISSING-NUMBERS REPORT KNOWS ABOUT SHAPE D (issue 1335)
# ============================================================================
# ⚠ THE GUARD BUILT TO STOP SILENT BLANK ROWS WAS DEFEATED BY THIS SHAPE, and
# measurement is the only reason anyone found out: on the ver_50 run above,
# `ase::op_report_missing` returned <silent> while five of six rows were blank.
# The mechanism is test_ase_final's own F18 trap. `.options savecurrents` puts
#
#     i(@m.xm1.msky130_fd_pr__nfet_01v8[id])
#
# in the raw with NO card present, and the reporter compares DEVICES, so that
# one vector marked the device answered and the sentence never fired.
#
# Shape d does not put its numbers in the raw at all -- they are in the sidecar
# -- so asking the raw about them is the wrong question. The reporter is told
# which shape the deck used and asks the right one.
set YDIR [file join $scratch yreport]
file mkdir $YDIR
set YST [ase::state_default]
dict set YST design [dict create lib zzlib cell yrep view schematic]
dict set YST rundir $YDIR
dict set YST simulator ngspice
set YRAW [ase::backend::ngspice::raw_file $YST]
file copy -force $WRAW $YRAW
set YBLK ".save @m.x1.xm1.mnfet\[id\]\n.save @m.x1.xm1.mnfet\[gm\]\n"

set YMETA_C [list opblock $YBLK optier c]
check_true {Y1 CONTROL on the per-device shape the report is unchanged: cards were asked for, the raw answered none, so it speaks} \
  [expr {[ase::op_report_missing $YST $YMETA_C 0] ne {}}]

set YMETA_D [list opblock $YBLK optier d]
check_true {Y2 on shape d with NO sidecar the report SPEAKS -- this is the folded-path run, whose raw and log are both perfectly clean} \
  [expr {[ase::op_report_missing $YST $YMETA_D 0] ne {}}]
check {Y3 and it says the DUMP is what is missing rather than blaming the simulator log, which has nothing in it to find} \
  [ase::op_report_missing $YST $YMETA_D 0] {op_dump_missing}

set YDUMP [::op_annot::opdump_path $YRAW]
set fh [open $YDUMP w]
puts $fh "m.x1.xm1.mnfet:"
puts $fh "    id                 = 5.33333e-05"
puts $fh "    gm                 = 0.000266667"
close $fh
file mtime $YDUMP [expr {[file mtime $YRAW] + 1}]
check {Y4 with a GOOD sidecar covering the devices the report is silent -- a run that worked must not be told it failed} \
  [ase::op_report_missing $YST $YMETA_D 0] {}

## The savecurrents trap itself, pinned so it cannot come back: a device whose
## ONLY vector is the free `i(@dev[id])` has not answered the question.
set fh [open $YDUMP w] ; puts $fh "q.other.qpnp:" ; puts $fh "    vbe                = 0.77" ; close $fh
file mtime $YDUMP [expr {[file mtime $YRAW] + 1}]
check_true {Y5 a sidecar that does not cover the block's devices is reported, not accepted because SOME file was there} \
  [expr {[ase::op_report_missing $YST $YMETA_D 0] ne {}}]

# ----------------------------------------------------------------------------
# Y6-Y10 -- THE COVERAGE CHECK IS CASE-FOLDED (issue 1390)
# ----------------------------------------------------------------------------
# ⚠ THIS FIRED ON THE USER'S OWN BENCH, AS A RED `#!` LINE, ON A GOOD RUN --
# "only 0 of the 78 devices your schematic asks about are in it, so the rest of
# the rows will be blank", printed over an annotation that was perfect. The two
# sides of the comparison are spelled by different authorities and only one of
# them keeps case: `op_annot::devpath` lowercases every path out, while `show
# all` writes the RUN's own spelling, and the user's ngspice-ver50 is registered
# `-casemode preserve`. Measured on the shipped code, same file, one device,
# spelling the only difference:
#
#     lowercase dump -> verdict = (silence)
#     preserve  dump -> verdict = op_dump_partial
#
# ⚠ AND THE NUMBERS WERE FINE THROUGHOUT, which is what makes it a diagnostic
# that lies rather than a data defect: rung 2 of save.c's get_raw_index ladder
# resolves the schematic's lowercase query against the merged mixed-case column
# (measured, `1.37276e-12`). Rows W1-W15 above are that road; these rows are
# only about what the run SAYS about it.
#
# ⚠ THE ROWS ARE PAIRED ON PURPOSE. Every case-folded row has an all-lowercase
# twin and the two are required to be BYTE-IDENTICAL, because a fold that fixed
# `preserve` by loosening the check for everybody would pass a one-sided row.
# Y10 is the other edge: where folding would have to GUESS, it declines.
proc y_dump {path args} {
  global YRAW
  set fh [open $path w]
  foreach d $args {
    puts $fh "$d:"
    puts $fh "    id                 = 5.33333e-05"
    puts $fh "    gm                 = 0.000266667"
  }
  close $fh
  file mtime $path [expr {[file mtime $YRAW] + 1}]
}
proc y_say {st meta} {
  ase::sim_said_clear
  set k [ase::op_report_missing $st $meta 0]
  return [list $k [ase::sim_said]]
}

y_dump $YDUMP {M.x1.XM1.Mnfet}
set fh [open $YDUMP r] ; set Y6BODY [read $fh] ; close $fh
## The first term is the non-vacuity half: the header must really be in the
## RUN's casing, or the row would pass on a tree that never folds anything.
check {Y6 a `preserve`-cased dump covering the block's devices is SILENT -- the run worked and must not be told it failed, which is the whole of issue 1390} \
  [list [regexp -line {^M\.x1\.XM1\.Mnfet:$} $Y6BODY] \
        [ase::op_report_missing $YST $YMETA_D 0]] \
  {1 {}}

y_dump $YDUMP {Q.other.Qpnp}
check {Y7 and the fold did not make it deaf: a `preserve`-cased dump for a device the block never asked about is still reported} \
  [ase::op_report_missing $YST $YMETA_D 0] {op_dump_partial}

## The count is the half the user actually read off the CIW, so it is asserted
## as a NUMBER IN THE SENTENCE and not merely as a kind: "0 of 78" was the lie.
set YBLK2 "$YBLK.save @q.other.qpnp\[vbe\]\n"
set YMETA_2 [list opblock $YBLK2 optier d]
y_dump $YDUMP {m.x1.xm1.mnfet}
set Y8 [y_say $YST $YMETA_2]
check {Y8 CONTROL, all lower case: a dump covering one of the two devices reports op_dump_partial and counts it as ONE of two} \
  [list [lindex $Y8 0] [regexp {only 1 of the 2 devices} [lindex $Y8 1]]] \
  {op_dump_partial 1}

y_dump $YDUMP {M.x1.XM1.Mnfet}
check {Y9 the same dump in the RUN's own casing says the same thing byte for byte -- case may not move one character of the outcome, in either direction} \
  [y_say $YST $YMETA_2] $Y8

## save.c's raw_build_fold_table stores -1 when two stored names fold onto one
## key and the fuzzy rung then refuses rather than guess (DECISIONS.md D2).
## This table poisons the folded key for the same reason and with the same
## answer: there is no single device to point at, so the device is missing.
y_dump $YDUMP {M.x1.XM1.Mnfet} {M.x1.Xm1.MNFET}
check {Y10 two dump names differing ONLY in case are the ambiguity save.c already declines, so the device counts as missing here too -- no second policy, and no guess} \
  [ase::op_report_missing $YST $YMETA_D 0] {op_dump_partial}

# ============================================================================
# N — WHAT THE RUN SAYS IT DID, AND WHAT THE NETLIST SAYS IT BUILT (issue 1354)
# ============================================================================
# ⚠ THE USER'S OWN LOG CARRIED BOTH HALVES OF THIS WRONG, AND ONE OF THEM SENT
# AN ENTIRE CREW AT THE WRONG HYPOTHESIS. /tmp/Xschem.log.5 says
#
#     ASE: 468 device OP save card(s) added to the deck.
#
# for a rendered deck (~/.xschem/simulations/tb_bandgap_ase.spice) that carries
# ZERO `@` characters -- shape d, no per-device card anywhere in it. And the
# line printed under it was the shape-c nudge, "Your simulator cannot do either
# of the shorter ways, so this is the only one available", about the very build
# that was GIVEN shape d because it can. The crew brief for the RDW list batch
# reasoned from the 468 and concluded the raw should hold six parameters; it
# held 7825.
#
# TWO DECISIONS IN TWO PLACES AND NEITHER CONSULTED THE OTHER:
#
#   * ase::op_cards_capture runs at NETLIST time and counts the block it just
#     built. IT CANNOT KNOW THE SHAPE AND MUST NOT FIND OUT: ase::op_save_tier
#     goes through ase::sim_capabilities, which on a cache MISS makes a scratch
#     folder and STARTS THE USER'S SIMULATOR -- and `Simulation > Netlist >
#     Recreate` (ase::ui::do_netlist_recreate -> ase::netlist ->
#     op_cards_capture, src/ase_window.tcl:6477) is a netlist gesture with no
#     run behind it. So the line stops CLAIMING the deck instead of learning the
#     shape, and the shape is reported by the one surface that already knows it.
#   * ase::op_tier_report DOES know the shape, and its switch had arms for a
#     and b only, so shape d fell through to the per-device kind and got the
#     per-device sentence -- catch-all tail and all.
#
# ⚠ AND FOR SHAPE D A COUNT OF CARDS IS NOT A SMALLER NUMBER, IT IS A CATEGORY
# ERROR (row D1: the deck carries none). The number that still means something
# is how many DEVICES the sheet asks about, so the netlist line carries both and
# row N6 is what stops one of them being dropped again.

set N_NL "** sch_path: /zz.sch\n**.subckt zzcell\nV1 a 0 1\n**.ends\n.end\n"
## three cards over TWO devices, deliberately different numbers: a line that
## printed one count twice would pass a row that only looked for "a number".
set N_BLK ".save all\n.save @m.xz1.mzmod\[id\]\n.save @m.xz1.mzmod\[gm\]\n.save @m.xz2.mzmod\[id\]\n"

proc n_prime {caps} {
  global STUB
  catch {ase::sim_caps_clear} ; catch {ase::sim_clear}
  ase::sim_register optier $STUB
  ase::sim_select optier
  set r [dict get [ase::sim_status ngspice] resolved]
  ## ⚠ THE KEY IS ASKED FOR, NEVER SPELLED (issue 1371, and see that file's
  ## tail). The capability store was re-keyed from the resolved PATH to
  ## `ase::cap_key {resolved eargs}`; a hand-spelled key here writes at an
  ## address the reader has left, every primed answer goes invisible, and the
  ## tier falls through to a LIVE probe of whatever ngspice the bench can
  ## resolve. Measured cost when that happened: nine rows of this file
  ## (T1..T5, X5, X6, N1, N3) reporting that binary's `{c nocap}` instead of
  ## the fixture's answer.
  set ::ase::sim_caps [dict create [ase::cap_key $r {}] \
                        [list stamp [ase::cap_stamp $r] caps $caps]]
  return $r
}
proc n_state {} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create lib zzlib cell zzcell view schematic]
  dict set st rundir [file join $scratch orun]
  dict set st analyses {{type op enabled 1}}
  dict set st save_op_params 1
  dict set st simulator ngspice
  return $st
}
## WHICH sentence a script said, by kind, and the sentences themselves. The
## recorder is intercepted rather than the CIW so a row can name the kind and
## not merely observe that words appeared (test_ase_optier_0963's o_saykinds,
## the same construct, because ruling D5-4 makes the kind the testable fact).
proc n_say {script} {
  set ::n_kinds {}
  set ::n_sent {}
  rename ::ase::sim_say ::n_saved_say
  proc ::ase::sim_say {kind name path {extra {}} {tag error}} {
    lappend ::n_kinds $kind
    set m [::n_saved_say $kind $name $path $extra $tag]
    lappend ::n_sent $m
    return $m
  }
  catch {uplevel 1 $script}
  rename ::ase::sim_say {}
  rename ::n_saved_say ::ase::sim_say
  return $::n_kinds
}

ase::op_cards_clear
ase::op_cards_put $N_NL $N_BLK
ase::op_tier_force_set {}

n_prime [dict merge $C_BASE {altshow_op_dump 1}]
set N_TIER_D [t_tier [dict merge $C_BASE {altshow_op_dump 1}]]
n_prime [dict merge $C_BASE {altshow_op_dump 1}]
set N1 [n_say {ase::op_tier_report ngspice [n_state] $N_NL}]
set N1SENT [lindex $::n_sent 0]
check {N1 a run that took shape d says SHAPE D -- the deck it just rendered\
 names no device anywhere, so the sentence about asking one device at a time is\
 a report of a path this run did not take} \
  [list $N_TIER_D $N1] {{d dump} op_tier_dump}

n_prime [dict merge $C_BASE {altshow_op_dump 0}]
check {N2 CONTROL the per-device shape still says the per-device sentence, so a\
 fix cannot pass this section by renaming every kind} \
  [n_say {ase::op_tier_report ngspice [n_state] $N_NL}] {op_tier_perdevice}

## The two clauses the user actually read, quoted from their own log. Neither
## may appear over a deck that carries no per-device card.
check {N3 and the shape-d sentence says neither of the two things the user's log\
 said: not "one request at a time", and not that their simulator cannot do a\
 shorter way -- it was given this shape BECAUSE it can} \
  [list [expr {[string first {one request at a time} $N1SENT] >= 0}] \
        [expr {[string first {cannot do either of the shorter ways} $N1SENT] >= 0}] \
        [expr {$N1SENT eq "Something is wrong with the simulator named ngspice." ? 1 : 0}] \
        [expr {[string length $N1SENT] > 80}]] \
  {0 0 0 1}

## The override reaches tier d too (ase::op_tier_force_set accepts a b c d), and
## it must land on the same arm: a hand-chosen shape may not smuggle the
## per-device sentence back in over a dump deck.
n_prime [dict merge $C_BASE {altshow_op_dump 0}]
ase::op_tier_force_set d
set N4 [n_say {ase::op_tier_report ngspice [n_state] $N_NL}]
ase::op_tier_force_set {}
check {N4 a shape chosen by hand takes the same arm -- the override says WHICH\
 shape, never which sentence} \
  [lsort $N4] {op_tier_dump op_tier_forced}

# --- the netlist line, which cannot know the shape and must stop pretending ---
proc n_capture {caps} {
  global N_NL N_BLK scratch
  n_prime $caps
  set nlf [file join $scratch ncap.spice]
  set fh [open $nlf w]; puts -nonewline $fh $N_NL; close $fh
  set ::n_echo {}
  rename ::ase::echo ::n_saved_echo
  proc ::ase::echo {msg {tag {}}} { lappend ::n_echo $msg ; return }
  rename ::op_annot::save_cards ::n_saved_cards
  proc ::op_annot::save_cards {args} { return $::N_BLK }
  rename ::op_annot::last_warnings ::n_saved_warn
  proc ::op_annot::last_warnings {args} { return {} }
  rename ::ase::design_is_dirty ::n_saved_dirty
  proc ::ase::design_is_dirty {args} { return 0 }
  catch {ase::op_cards_clear}
  catch {ase::op_cards_capture [n_state] $nlf} err
  rename ::ase::design_is_dirty {} ; rename ::n_saved_dirty ::ase::design_is_dirty
  rename ::op_annot::last_warnings {} ; rename ::n_saved_warn ::op_annot::last_warnings
  rename ::op_annot::save_cards {} ; rename ::n_saved_cards ::op_annot::save_cards
  rename ::ase::echo {} ; rename ::n_saved_echo ::ase::echo
  return [join $::n_echo " "]
}
set N_CAP_D [n_capture [dict merge $C_BASE {altshow_op_dump 1}]]
set N_CAP_C [n_capture [dict merge $C_BASE {altshow_op_dump 0}]]
ase::op_cards_clear
ase::op_cards_put $N_NL $N_BLK

check {N5 the netlist-time line does not tell the user what the deck carries. It\
 is printed before any deck exists, it is the SAME line whichever shape the run\
 later takes, and finding the shape out there would start their simulator on a\
 plain Netlist gesture} \
  [list [expr {$N_CAP_D eq $N_CAP_C}] \
        [expr {[string match {*added to the deck*} $N_CAP_D] ? 1 : 0}] \
        [expr {[string length $N_CAP_D] > 0}]] \
  {1 0 1}

## ⚠ EACH NUMBER IN ITS OWN CLAUSE, BECAUSE THE ROW COULD NOT TELL THEM APART.
## The spelling this replaces asked only that a standalone `3` and a standalone
## `2` appeared SOMEWHERE in the echo, so a line printing the two counts SWAPPED
## -- 2 cards covering 3 devices, which is arithmetically impossible and exactly
## the mistake an edit here would make -- satisfied it. The fixture is built with
## three cards over two devices for that reason (see $N_BLK); the last two legs
## are the swap itself, asserted absent.
check {N6 and it carries BOTH numbers, each in its own clause -- the cards it\
 built and the devices they cover -- because on shape d the card count is a\
 category error and the device count is the one that still means something} \
  [list [regexp {(^|[^0-9])3 device OP save card\(s\) prepared} $N_CAP_D] \
        [regexp {covering 2 device\(s\)} $N_CAP_D] \
        [regexp {(^|[^0-9])2 device OP save card\(s\) prepared} $N_CAP_D] \
        [regexp {covering 3 device\(s\)} $N_CAP_D]] \
  {1 1 0 0}

catch {ase::sim_caps_clear} ; catch {ase::sim_clear}

cd $T_OLDPWD
## ⚠ A SET DIFFERENCE, NOT A COUNT -- baseline and watch dirs at :57. 0609's own
## suggested fix compares `llength`s, so a run that removed `untitled~.sym` and
## added `untitled~.sch` scores clean; 0609 §3 records that both extensions occur.
## Kept as ONE row with two legs (cwd restored, nothing added) so the suite's check
## count stays 70; a failure now prints the offending paths.
set h1_new {}
foreach f [h1_litter_snap] {
  if {[lsearch -exact $h1_pre $f] < 0} { lappend h1_new $f }
}
check {H1 HYGIENE the suite left the cwd where it found it and added no untitled*\
 to the repo root or to the directory it was launched from (issue 0609 -- a DELTA,\
 not an existence test: it must not red on litter another suite left before this\
 one started, which is what made it structurally unpassable inside full_audit.sh)} \
  [list [expr {[pwd] eq $T_OLDPWD}] $h1_new] {1 {}}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
