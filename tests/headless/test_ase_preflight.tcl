# The three defences against a run that produces a RESULT-SHAPED NON-RESULT —
# casemode batch item 10 (PLAN.md §3b item 10 and §D5; DECISIONS.md C3, C4, D1).
#
# THE DEFECT IS LIVE AND MODE-INDEPENDENT. A `.save` of a node the circuit does
# not have does not fail usefully. Measured 2026-08-17 in render_deck's own deck
# shape, on BOTH /usr/local/bin/ngspice (46) and build-ver_50 — they are
# identical here, and upstream has withdrawn the fix three times:
#
#   rc=1, ZERO mentions of the bad token on either stream, and a 569-byte raw
#   file IS WRITTEN: Title: Constant values / Plotname: constants /
#   No. Variables: 12 / Date: == the simulator's own build stamp.
#
# Downstream that file exists, parses and attaches, so the session shows twelve
# mathematical constants where its waveforms should be.
#
# Three defences, none redundant (C4's table):
#   (a) the PRE-FLIGHT names the specific bad expression before any simulator
#       starts — blind to a name that only an .include'd PDK file defines;
#   (b) the $sim_status GUARD catches any failed analysis and leaves NO ARTEFACT
#       AT ALL — blind to a file we did not generate;
#   (c) the CONTENT CHECK catches a bad file from anywhere, old or foreign —
#       but cannot say why it is bad.
#
# Legs (PF*):
#   PF212      the identifier extractor: derived exprs, `-i(v1)`, `v(a,b)`
#   PF213      the netlist map: scopes, ports, globals, k=v params, X masters
#   PF214      resolution, and THE TRAP spec §13.6 names — under `fold` the
#              expression is already folded and the map is NOT, so both sides
#              must fold or every mixed-case net reads as absent
#   PF215      the scan: which rows are checked, and where the mode comes from
#   PF216      the gate: it refuses, it names every offender, it writes NOTHING,
#              and `ase_preflight 0` is a real lever
#   PF217      D1 — the corrections are OFFERED and applied only on an explicit
#              call, never silently; and issue 0503's stale folded row
#   PF218      defence (b): C4's guard shape, after EVERY analysis
#   PF219      defence (c): the constants raw, the appendwrite shape, and a
#              rejection that does not disturb the database already loaded
#   PF221      THE FIX ROUND — ten reproduced defects and five coverage holes
#              raised by three reviewers of the first cut
#   PF220      the real simulator, when there is one (skipped, never failed)
#   PF222      issue 1401 -- an ENABLED analysis this backend cannot render is
#              refused here, ahead of the deck write, and `ase_preflight 0`
#              does NOT defeat that clause (PF221 is a 54-row family above)
#   PF223-226  issues 1422-1425 -- netlist_facts, preconditions as filters, a
#              fatal precondition as a refusal, and the remedy said before the run
#   PF227      issue 1426 -- the transfer function's two preconditions, and the
#              measured asymmetry between them: ngspice checks the INPUT source
#              and aborts, and does NOT check the OUTPUT at all
#   PF228      issue 1427 -- the pole-zero analysis's four preconditions, where
#              every failure is a hard rc 1 abort and only three of the four are
#              `fatal`, because the severity tracks what the STATIC PASS CAN KNOW
#   PF229      issue 1428 -- DC sensitivity's two preconditions: an output
#              ngspice does not validate and fills a ~90-row table of zeros for,
#              and a parameter filter that matches nothing and leaves the run
#              with NO PLOT AT ALL at rc 0
#   PF1723     issue 1723 -- a renamed instance: the stale-instance correction
#              (unique / several / partial, a deeper segment), the measurement
#              fields and include files it strands, the closing remedy per kind
#              of correction, and the ASE-L button's pure decision
#              (ase::ui::repair_offer). Placed ABOVE PF233, so the last row of
#              this file is still `PF233f`; it moved no existing row. The
#              button's display half is test_ase_window.tcl's FX1723 band.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_preflight.tcl
#
# ⚠ FLOOR: 192 checks, and it only ever goes up. This file had declared none
# until issue 1401 added section PF222, which is the moment a floor becomes worth
# having: 115 before those rows, 122 after -- measured, both by running it and by
# name-diffing the `ok:` lines -- then 125 when an adversarial review found the
# rundir clause dropped and the rank table unscoped. RAISED 115 -> 122 -> 125. If a run reports fewer,
# a row went missing; do not edit this number down to match it. RAISED 125 -> 135
# when section PF223 landed ase::netlist_facts, 135 -> 144 with PF224, 144 -> 149 with PF225, 149 -> 152 with PF226,
# and 152 -> 164 with PF227 (Stage 5, issue 1426 -- the transfer function's two
# preconditions). ⚠ PF227 is the section where the static demotion is measured
# to be RIGHT for one finding and WRONG for another in the same predicate: a
# missing node is `blocked`->`caution` with the `.include` caveat, and a
# malformed output is `fatal` and carries none, because no include can make
# `v mid` legal.
# 164 -> 177 with PF228 (Stage 5, issue 1427 -- the pole-zero analysis's four
# preconditions). ⚠ PF228m IS THERE BECAUSE A SABOTAGE SURVIVED WITHOUT IT: the
# `$n eq {0}` ground skip can be deleted and every other PF228 row stays green,
# because every deck they use writes node `0` on a card. ⚠ PF228 carries the demotion rule's THIRD case, which neither
# PF227 nor issue 1423 had a name for: a finding of the form "this deck CONTAINS
# X" is PROVED by the static pass, because an `.include` can only ADD devices and
# never remove the card just read. Such a finding needs no caveat in either
# direction, and row PF228h is that sentence as an assertion.
# 210 -> 217 with PF231 (Stage 6f, issue 1433 -- the checkpoint block, as deck
# text: `stop after` and never `stop when`, the threshold through a `set`
# variable and never `$&`, the counters above the first analysis, the loop
# between the transient and its own guard, no `PLOT` record from a checkpoint,
# and the completion marker last inside `.control`). ⚠ NO ROW MOVED: `deck_of`'s
# own fixture is `tran 1n 1u`, a thousand estimated points against
# `ase::ckpt_floor`'s 100,000, so every PF218 row still describes a deck with no
# checkpoint block in it -- and PF231a is what says so rather than assuming it.
# 192 -> 194 with PF218f2/PF218f3 (Stage 6a, issue 1430 -- the plot sidecar's
# record sits below the $sim_status guard and immediately above its own write,
# and goes to the sidecar rather than to the results file). ⚠ NO ROW MOVED:
# PF218f's own ordering claim is untouched, and PF222a-e / PF222h-j still rest
# on `noise` being UNRENDERABLE, which this issue does not change.
# ⚠ AND THEY MOVED AGAIN AT STAGE 9 (issue 1452), from `sp` to `pss`, for the
# third time and the last one available: `sp` earned a real entry and `pss` is
# now the only probe-only type in the shipped registry. PF232j moved with them.
# No row was added and no verdict changed -- only the fixture's spelling.
# 177 -> 192 with PF229 (Stage 5, issue 1428 -- DC sensitivity's two
# preconditions). ⚠ `sens_filters` IS THE FIRST FINDING IN THIS FILE WHOSE
# FAILURE MODE IS AN EMPTY RESULT RATHER THAN A WRONG ONE: measured on both
# binaries, a filter that matches nothing leaves `$plots` = `const` and
# `$curplotname` = `constants` at rc 0, so ASE-L's own append-write deck then
# writes the CONSTANTS plot -- the exact artifact the top of this file is about,
# reached from a new direction. ⚠ AND PF229j REFUTES APPENDIX §2.10's NAMING
# TABLE: a subcircuit device's sens vector is `<letter>.<instance path>.<name>`,
# so the check is keyed on the TOP scope and a filter naming a device that
# exists only inside a subcircuit IS reported.
#
# 194 -> 210 with PF230 (Stage 6d, issue 1432 -- the seven preconditions the
# three multi-plot types bring). ⚠ NO ROW MOVED, but PF222a-e / PF222h-j changed
# their UNRENDERABLE FIXTURE from `noise` to `sp`, because this issue gave
# `noise` and `disto` real entries. Row TF3b of tests/headless/test_ase_core.tcl
# warned in as many words that these rows would move the day that happened.
# ⚠ PF230g IS THE SHARPEST OF THE SEVEN: `disto` SEGFAULTS -- rc 139, no exit
# status, no log, no results file -- when the save list resolves to NOTHING, and
# making `disto` renderable is what put that in a user's reach. The trigger is
# the WHOLE list resolving to nothing, so `design-C`'s proposed refusal (`disto`
# enabled AND zero saved outputs) would have refused a deck that runs.
# ⚠ AND PF230l REACHES BACK INTO TWO STAGE-5 ENTRIES. APPENDIX §7.5.2's
# starvation -- an analysis whose result vectors are not netlist names cannot run
# under a save list made of netlist names -- is assigned there to "Stage 6's
# precondition" by name, and it hits `tf` and `sens` exactly as it hits `noise`.
# One ticked output is enough, which is the shape of every committed bench.
#
# 218 -> 229 with PF232 and the repointing of PF216f / PF230l / PF230m / PF230n
# (Stage 6g, issue 1434 -- the emission rule that replaces a refusal).
# ⚠ FOUR ROWS MOVED RATHER THAN BEING ADDED, and every one of them because
# `vecsaves` stopped refusing:
#   PF230l  `noise`/`tf`/`sens` answer `caution`, not `fatal`, and **`pz` joined
#           them** while **`disto` left** -- both by measurement, both against
#           what PLAN.md 6g-1, APPENDIX 7.5.2 and PLAN.md 0.13.7 say
#   PF230m  its stand-downs went from three to one, because there is no longer a
#           false refusal to avoid -- which also deletes the MISSED refusal that
#           issue 1432's own comment named
#   PF230n  the sentence is about the widening, not about a refusal
#   PF216f  `set ase_preflight 0` turns off the REFUSAL and not the advice under
#           it -- the gate has said so in a comment since issue 1425 and until
#           `saves_resolve` reached `op` nothing exercised it on this fixture.
#           PF216f2 is its new discriminator.
# 229 -> 235 with section PF233 (Stage 6, issue 1435 -- the precondition banner
# under the Choose Analyses form). ⚠ THE ROWS ARE HERE RATHER THAN WITH THE REST
# OF 1435 BECAUSE THIS FILE IS THE HAZARD: every `deck_of`/`pcheckx` call below
# passes a hand-written netlist string that nobody netlisted, and the gate's new
# optional third argument exists precisely so those donate nothing to the slot a
# dialog reads.
# 235 -> 238 with section PF234 (⚖ R9 ruling A1, 2026-09-15 -- the shouted words
# in user-facing sentences, and the TWO EXCEPTIONS the user kept). ⚠ PF230b MOVED
# rather than being added: its clause read `measures a VOLTAGE` and now reads
# `measures a voltage`, with a new term asserting nothing in it is shouted at all.
# ⚠ THE SECTION'S SUBJECT IS AN EXCEPTION, WHICH IS UNUSUAL AND DELIBERATE: A1
# leaves the interface looking inconsistent on purpose, so `SEGFAULTS` and the
# options sheet's two row prefixes are pinned BY NAME lest a later consistency
# pass tidy them away in good faith and reverse a user ruling in silence.
# 238 -> 242 with section PF235 (⚖ R9 ruling A8, 2026-09-16 -- sibling sentences
# that had drifted apart). Five places tell a user to name a node and they said it
# FOUR ways; PF235a/c converge them and PF235c's third term is the sharp one --
# the four remedies de-duplicate to a list of length ONE, so a later edit to any
# single site reds with the count going to 2. PF235b is §A8's named exception in
# the other direction: R9-119's `v(out)` / `v(out,ref)` example is INFORMATION,
# not drift, so the template took it along instead of replacing it. PF235d is the
# gate pair end to end, where §A8's other ruling lands.
# ⚠ THREE ROWS MOVED RATHER THAN BEING ADDED and are NOT in the +4: PF222b and
# PF222e (`this simulator backend` -> `this simulator`, ⚖ R9 A6) and PF228b (the
# pz remedy losing its plural). ⚠ AND PF234b MOVED THE FURTHEST: it used to scan
# `ase::preflight_gate` for the closing sentence FOUR times, because four
# refusals inside that one proc each spelled it out. A8 collapsed the tail into
# `ase::preflight_refusal`, so it now scans that proc for ONE and requires the
# gate to keep NONE -- term 4 is the load-bearing one, and it reds if a fifth
# refusal ever spells its own tail again.
# 242 UNMOVED for ⚖ R9 rulings A9 and A10 and §A3's remainder (2026-09-16), and
# this paragraph exists because its ABSENCE was itself the finding. A9 reworded
# the two distortion preconditions (`distof1 <mag> <phase>` -> a sentence with no
# angle brackets in it), and PF234c -- the row over that precondition -- MOVED
# rather than being added, so the count does not rise. The floor is right and
# nothing was lowered; what was missing was anybody being able to SEE that from
# the floor block. The only note this file carried about A9 was an inline comment
# at the PF234c row itself, ~2,350 lines below here, which is not where a reader
# auditing a floor looks -- every other "moved rather than added" note in this
# batch (PF222b, PF222e, PF228b, PF234b above) lives in this block.
# ⚠ AND A ROW COUNT DOES NOT PROVE A SUITE RAN TO THE END. A9's first edit put an
# explanatory `#` INSIDE a `[list blocked ...]` command substitution, where `#` is
# NOT a comment: the remedy string was parsed as a command name, the precondition
# raised, and THIS SUITE stopped at 232 rows -- while still printing a plausible
# `RESULT:` line. 242 is therefore checked by NAME as well as by number: the last
# row of this file is `PF233f`, and `OVERALL: ok` is the banner that says the tail
# was reached. A file that stops early prints neither.
# AND RAISED 238 -> 242.
# AND RAISED 235 -> 238.
# AND RAISED 229 -> 235.
# AND RAISED 218 -> 229.
# ⚠ AND THIS SUITE IS FINALLY IN T1 (issue 1421). It printed `RESULT:` and no
# `OVERALL:` and called `exit 0` unconditionally, so `run_regression.tcl` could
# not read it and never named it -- 125 checks of the refusal standing between a
# user and a raw file of twelve mathematical constants, run by nothing but
# `full_audit.sh`. Both are fixed at the tail of this file. **Twenty-one other
# `test_ase_*` suites still have the same defect**; the list is in issue 1421.

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}
## ⚖ R-OUT8 (ruling 2026-10-13): a save ADDS to what ngspice keeps and never
## narrows it, so every deck with an output card carries `.save all` and NO
## bench is narrowed any more (ase::saves_narrowed answers 0, and
## ase::saves_all_forced is 1 whenever there is a card). The class A widening,
## its `vecsaves` caution, `saves_resolve` and `disto_saves` therefore stand
## down on every real bench -- rows marked REAL below say so.  Their code and
## their sentences are KEPT for a future "narrow on purpose" switch, and the
## rows that pin them run in the DORMANT world: `pf_narrowed` puts the two
## pre-R-OUT8 bodies back for the length of one script, and restores the real
## ones after it whatever the script does.
proc pf_narrowed {script} {
  rename ::ase::saves_narrowed ::pf_real_saves_narrowed
  rename ::ase::saves_all_forced ::pf_real_saves_all_forced
  proc ::ase::saves_narrowed {state} {
    if {$state eq {}} { return 0 }
    if {[ase::state_get $state save_all_v 0] eq {1}} { return 0 }
    return [expr {[llength [ase::output_save_cards $state]] > 0}]
  }
  proc ::ase::saves_all_forced {sim state} {
    if {$state eq {}} { return 0 }
    if {[ase::state_get $state save_all_v 0] eq {1}} { return 1 }
    if {[ase::saves_widen_types $sim $state] ne {}} { return 1 }
    return 0
  }
  set rc [catch {uplevel 1 $script} r]
  rename ::ase::saves_narrowed {}
  rename ::ase::saves_all_forced {}
  rename ::pf_real_saves_narrowed ::ase::saves_narrowed
  rename ::pf_real_saves_all_forced ::ase::saves_all_forced
  return -code $rc $r
}
# ABORT-PROOFING (the LEDGER carry-forward from items 1, 2, 5b, 6, 7 and 8): a
# proc sabotaged away must FAIL a check, never abort the file with no RESULT
# line — under which every sabotage reads as "nothing went red".
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
proc dg {d k} {
  if {[catch {dict get $d $k} v]} { return "NO:$k" }
  return $v
}
## the same abort-proofing for the NESTED reads: `dict exists`/`dict keys` on a
## proc that has been sabotaged away receive an error STRING, and they throw on
## it — which would abort the file with no RESULT line and make every later
## sabotage read as "nothing went red".
proc dex {d args} {
  if {[catch {dict exists $d {*}$args} v]} { return 0 }
  return [expr {$v ? 1 : 0}]
}
proc dkeys {d args} {
  if {[catch {dict keys [dict get $d {*}$args]} v]} { return "NOKEYS" }
  return [lsort $v]
}
proc dgn {d args} {
  if {[catch {dict get $d {*}$args} v]} { return "NO:$args" }
  return $v
}
proc putfile {p txt} { set f [open $p w] ; puts -nonewline $f $txt ; close $f }
proc readfile {p} {
  if {[catch {open $p r} f]} { return "NOFILE" }
  set t [read $f] ; close $f ; return $t
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean
set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set tmp [test_scratch ase_preflight]
set ::USER_CONF_DIR [file join $tmp conf]
file mkdir $::USER_CONF_DIR

## ISOLATION FROM WHOEVER'S ~/.xschem/ase_simulators IS LIVE (issue 1377).
test_sim_registry_isolate     ;# issue 1377: the registry below is OURS, not ~/.xschem's
## PF215c reads the case mode off the entry in force. Before the fix it read
## `preserve` from the developer's registry and went red -- and went GREEN for
## the wrong reason under a registry whose entry happened to say `distinguish`,
## which is the shape of an unisolated suite that a count can never catch.
eqcheck ISO1377-the-suite-runs-against-an-empty-simulator-registry \
  [test_sim_registry_state] {0 {} {} path}

# the CIW spy: ase::echo resolves ::ciw_echo BY NAME at call time. The TAG is
# recorded as well as the text — item 14's finding is that a channel can be
# correct and still reach nobody.
set ::said {}
if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::ciw_echo_orig }
proc ::ciw_echo {line {tag {}}} { lappend ::said [list $tag $line] }
proc said_clear {} { set ::said {} }
proc said_count {pat} {
  set n 0
  foreach e $::said { if {[string match $pat [lindex $e 1]]} { incr n } }
  return $n
}
proc said_tag_count {want} {
  set n 0
  foreach e $::said { if {[lindex $e 0] eq $want} { incr n } }
  return $n
}

proc reset_sim {} {
  if {[info exists ::sim]} { unset ::sim }
  set ::sim_case_mode fold
  set_sim_defaults
}
reset_sim
set ::ase_preflight 1

# --- the netlist under test ---------------------------------------------------
# The shape xschem's netlister really emits (verified by netlisting
# tests/headless/fixtures/ase_hier/ase_hier_top.sch): the top-level body between
# `**.subckt`/`**.ends` COMMENT markers, real `.subckt`/`.ends` bodies below it,
# and X-cards whose LAST token is the master. Capitals where they matter, so the
# fold-both-sides trap has something to trip over.
set NL {** sch_path: /fixture/pf_top.sch
**.subckt pf_top
x1 TOPNET pf_mid
V9 TOPNET 0 1
XM1 TOPNET G GND GND sky130_fd_pr__nfet_01v8 L=0.15 W=1 mult=1
XPDK TOPNET 0 pdk_from_an_include
* R99 commentnode 0 1k
**.ends
.GLOBAL GND
.subckt pf_mid A
x2 A net1 pf_leaf
.ends
.subckt pf_leaf A B
V1 A MidNode 0
R1 MidNode 0 1k
.ends
.end
}

if {[catch {

# ===========================================================================
# PF212 — the identifier extractor
# ===========================================================================
eqcheck PF212-a-negated-current-expr [pcall ase::preflight_idents {-i(v1)}] {{current v1}}
eqcheck PF212b-a-derived-expr-names-two-nodes \
  [pcall ase::preflight_idents {v(a)-v(b)}] {{voltage a} {voltage b}}
## `v(a,b)` is ngspice's DIFFERENTIAL voltage and names TWO real nodes
## (ase::bus_expr_bits' comment records that `.save v(d,e)` saves both), so a
## pre-flight that treated `a,b` as one identifier would refuse every one of them
eqcheck PF212c-a-differential-expr-names-two-nodes \
  [pcall ase::preflight_idents {v(a,b)}] {{voltage a} {voltage b}}
eqcheck PF212d-uppercase-V-and-I-count \
  [pcall ase::preflight_idents {V(A)+I(R1)}] {{voltage A} {current R1}}
eqcheck PF212e-an-expr-naming-nothing-yields-nothing \
  [pcall ase::preflight_idents {1.5}] {}

# ===========================================================================
# PF213 — the netlist map
# ===========================================================================
set MAP [pcall ase::netlist_map $NL]
eqcheck PF213-the-three-scopes-are-found [dkeys $MAP scopes] {{} pf_leaf pf_mid}
eqcheck PF213b-top-level-nodes-and-instances \
  [list [dex [dg $MAP scopes] {} nodes TOPNET] \
        [dgn $MAP scopes {} insts x1]] {1 pf_mid}
## a .subckt's PORTS are nodes of that subcircuit
eqcheck PF213c-subckt-ports-are-nodes \
  [list [dex [dg $MAP scopes] pf_leaf nodes A] \
        [dex [dg $MAP scopes] pf_leaf nodes B]] {1 1}
## `.global GND` is visible in every scope, so v(GND) must not read as absent
## from inside a subcircuit that never mentions it
eqcheck PF213d-globals-are-visible-everywhere \
  [dg [pcall ase::netlist_map_resolve $MAP voltage x1.x2.GND 1] status] present
## a `k=v` PARAMETER is not a node: without the filter `L`, `W` and `mult` would
## all become node names of the top level and mask a real typo
eqcheck PF213e-kv-params-are-not-nodes \
  [list [dex [dg $MAP scopes] {} nodes L] \
        [llength [lsearch -all -glob [dkeys [dg $MAP scopes] {} nodes] {*=*}]] \
        [dex [dg $MAP scopes] {} nodes TOPNET]] {0 0 1}
## a COMMENTED-OUT card contributes nothing. Without the comment skip the map
## silently grows every word of every `**.subckt` / `* expanding symbol:` line
## the netlister emits, and a real typo can hide behind one of them.
eqcheck PF213g-a-commented-out-card-contributes-no-names \
  [list [dex [dg $MAP scopes] {} nodes commentnode] \
        [dex [dg $MAP scopes] {} devs R99] \
        [dex [dg $MAP scopes] {} devs V9]] {0 0 1}
## an X-card's MASTER is the subcircuit name, not a node -- it is the INSTANCE's
## master, and both halves are asserted together so the negative half cannot
## pass by the map not existing at all
eqcheck PF213f-an-X-master-is-an-instances-master-not-a-node \
  [list [dex [dg $MAP scopes] {} nodes pf_mid] [dgn $MAP scopes {} insts x1]] \
  {0 pf_mid}

# ===========================================================================
# PF214 — resolution, and the fold-both-sides trap (spec §13.6)
# ===========================================================================
## THE TRAP. Under `fold` item 9 emits `v(topnet)` and the netlist says
## `TOPNET`; a case-SENSITIVE pre-flight would report every mixed-case net in
## the design as absent and refuse the DEFAULT mode's every run.
eqcheck PF214-fold-folds-BOTH-sides \
  [dg [pcall ase::netlist_map_resolve $MAP voltage topnet 0] status] present
eqcheck PF214b-distinguish-compares-case-sensitively-and-OFFERS-the-fix \
  [list [dg [pcall ase::netlist_map_resolve $MAP voltage topnet 1] status] \
        [dg [pcall ase::netlist_map_resolve $MAP voltage topnet 1] real]] \
  {absent TOPNET}
eqcheck PF214c-the-schematics-own-spelling-resolves-under-distinguish \
  [dg [pcall ase::netlist_map_resolve $MAP voltage TOPNET 1] status] present
## a hierarchical name walks the X-cards, and the correction carries EVERY
## segment's real spelling, not only the leaf's
eqcheck PF214d-a-hierarchical-node-under-fold \
  [dg [pcall ase::netlist_map_resolve $MAP voltage x1.x2.midnode 0] status] present
eqcheck PF214e-a-hierarchical-node-under-distinguish \
  [list [dg [pcall ase::netlist_map_resolve $MAP voltage x1.x2.midnode 1] status] \
        [dg [pcall ase::netlist_map_resolve $MAP voltage x1.x2.midnode 1] real]] \
  {absent x1.x2.MidNode}
## a hierarchical CURRENT: the leading segment is the branch prefix letter, and
## the corrected spelling re-derives it from the DEVICE's own first character —
## item 9 §13.3, hilight.c's sender_current_prefix(), measured on ver_50
eqcheck PF214f-a-hierarchical-current-under-fold \
  [dg [pcall ase::netlist_map_resolve $MAP current v.x1.x2.v1 0] status] present
eqcheck PF214g-the-current-correction-re-derives-the-prefix-from-the-device \
  [list [dg [pcall ase::netlist_map_resolve $MAP current v.x1.x2.v1 1] status] \
        [dg [pcall ase::netlist_map_resolve $MAP current v.x1.x2.v1 1] real]] \
  {absent V.x1.x2.V1}
## a current names a DEVICE, not a node: `i(midnode)` is nonsense even though
## `v(midnode)` is fine, and the two name spaces are kept apart
eqcheck PF214h-currents-and-voltages-are-separate-name-spaces \
  [list [dg [pcall ase::netlist_map_resolve $MAP voltage x1.x2.midnode 0] status] \
        [dg [pcall ase::netlist_map_resolve $MAP current x1.x2.midnode 0] status]] \
  {present absent}
## a genuine typo is absent in BOTH modes and has no correction to offer
eqcheck PF214i-a-real-typo-is-absent-in-both-modes \
  [list [dg [pcall ase::netlist_map_resolve $MAP voltage nosuchnode 0] status] \
        [dg [pcall ase::netlist_map_resolve $MAP voltage nosuchnode 1] status] \
        [dg [pcall ase::netlist_map_resolve $MAP voltage nosuchnode 1] real]] \
  {absent absent {}}
## an instance path segment naming nothing in a scope we DID parse is provably
## absent — that is not the .include case
eqcheck PF214j-an-unknown-instance-segment-is-absent-not-unknown \
  [dg [pcall ase::netlist_map_resolve $MAP voltage x9.mid 0] status] absent
## C4's named blind spot, and the one place the pre-flight must STAND DOWN: the
## master is defined in an .include'd PDK file, so this netlist cannot judge it
eqcheck PF214k-a-master-this-netlist-does-not-define-is-UNKNOWN \
  [dg [pcall ase::netlist_map_resolve $MAP voltage xpdk.internal 0] status] unknown
eqcheck PF214l-an-at-dev-param-name-is-UNKNOWN \
  [dg [pcall ase::netlist_map_resolve $MAP current {@r.x1.rq[i]} 0] status] unknown
## a bus BIT is a whole sub-language (issue 0159) and the base name of `bus[1]`
## is not itself a node, so a base-name test would refuse every bus
eqcheck PF214m-a-bracketed-name-that-is-not-an-exact-hit-is-UNKNOWN \
  [dg [pcall ase::netlist_map_resolve $MAP voltage {bus[1]} 0] status] unknown
## D2's rule, one layer up: two stored names folding together leave nothing to
## offer, so the row says so instead of guessing
set MAPC [pcall ase::netlist_map "* t\nV1 Out 0 1\nR1 OUT 0 1k\n.end\n"]
eqcheck PF214n-two-netlist-names-differing-only-in-case-are-AMBIGUOUS \
  [list [dg [pcall ase::netlist_map_resolve $MAPC voltage out 1] status] \
        [dg [pcall ase::netlist_map_resolve $MAPC voltage out 1] real] \
        [dg [pcall ase::netlist_map_resolve $MAPC voltage out 1] ambiguous]] \
  {absent {} 1}

# ===========================================================================
# PF215 — the scan
# ===========================================================================
proc mkstate {rundir cell outs} {
  set s [ase::state_default]
  dict set s design [dict create lib dlib cell $cell view schematic]
  dict set s rundir $rundir
  dict set s outputs $outs
  return $s
}
set RD [file join $tmp run]
file mkdir $RD
set GOOD {{expr v(TOPNET) save 1} {expr -i(V9) save 1}}
set STALE {{expr v(topnet) save 1} {expr -i(v.x1.x2.v1) save 1}}
set TYPO {{expr v(nosuchnode) save 1}}

set ::sim_case_mode fold
eqcheck PF215-a-clean-state-has-nothing-absent \
  [dg [pcall ase::preflight_scan [mkstate $RD c $GOOD] $NL] absent] {}
eqcheck PF215b-under-fold-a-folded-row-is-fine \
  [dg [pcall ase::preflight_scan [mkstate $RD c $STALE] $NL] absent] {}
set ::sim_case_mode distinguish
set sc [pcall ase::preflight_scan [mkstate $RD c $STALE] $NL]
eqcheck PF215c-the-mode-comes-from-the-run-request [dg $sc mode] distinguish
eqcheck PF215d-both-stale-rows-are-named [llength [dg $sc absent]] 2
## a row that is not SAVED is not in the deck, so it is not the pre-flight's
eqcheck PF215e-an-unsaved-row-is-not-checked \
  [llength [dg [pcall ase::preflight_scan \
     [mkstate $RD c {{expr v(nosuchnode) save 0}}] $NL] absent]] 0
## THE SIMULATOR'S OWN MODE BEATS THE FLOOR: with the floor at `fold`, a
## registered simulator carrying `distinguish` must still refuse — a scan that
## read $::sim_case_mode raw would pass this state.
##
## ⚠ IT WAS A STAMPED `sim()` PROFILE ROW UNTIL THE `annotate` MERGE, and B1's
## "per simulator, with a global floor" is unchanged; only where the per-
## simulator half is stored moved, onto the ASE-L registry entry. The `entry=`
## term replaces the old `altidx >= 0` guard for the same reason it was there:
## without it a fixture that silently registered nothing would leave this row
## comparing the floor against itself and passing.
set ::sim_case_mode fold
pcall ase::sim_clear
pcall ase::sim_register pf215f /bin/sh -casemode distinguish
set stampd [mkstate $RD c $STALE]
eqcheck PF215f-a-registered-simulators-mode-beats-the-global-floor \
  [list [expr {[dg [pcall ase::sim_status ngspice] entry] ne {}}] \
        [dg [pcall ase::preflight_scan $stampd $NL] mode] \
        [llength [dg [pcall ase::preflight_scan $stampd $NL] absent]]] {1 distinguish 2}
pcall ase::sim_clear
set ::sim_case_mode fold
## and the blind spot is reported as `unknown`, never counted as absent
set unk [pcall ase::preflight_scan [mkstate $RD c {{expr v(xpdk.internal) save 1}}] $NL]
eqcheck PF215g-an-unadjudicable-name-is-unknown-not-absent \
  [list [llength [dg $unk absent]] [llength [dg $unk unknown]]] {0 1}

# ===========================================================================
# PF216 — the gate
# ===========================================================================
said_clear
eqcheck PF216-a-clean-state-passes-the-gate \
  [list [catch {ase::preflight_gate [mkstate $RD c $GOOD] $NL} e0] [said_count {ase: REFUSED*}]] \
  {0 0}
said_clear
set c1 [catch {ase::preflight_gate [mkstate $RD c $TYPO] $NL} e1]
eqcheck PF216b-a-typo-REFUSES-and-raises \
  [list $c1 [string match {ase: REFUSED*} $e1]] {1 1}
## the refusal NAMES the expression. Item 14's lesson: a one-line summary of
## twelve corrections is a summary nobody can act on, so every offender gets its
## own CIW line, at tag `error`
eqcheck PF216c-the-offending-expression-is-named-on-the-CIW \
  [list [said_count {*v(nosuchnode)*}] [said_tag_count note]] {1 0}
eqcheck PF216d-the-refusal-names-the-constants-raw-so-the-user-can-recognise-it \
  [string match {*Plotname: constants*} $e1] 1
## the same clause item 8's gate carries: nothing here was generated, and what is
## in the rundir is from an earlier run
eqcheck PF216e-the-refusal-says-what-is-on-disk \
  [string match "*$RD*earlier run*" $e1] 1
## `ase_preflight 0` is a REAL lever, not decoration: the map has a blind spot
## (a top-level node only an .include defines), and a user who is right must not
## be locked out of their own simulator
set ::ase_preflight 0
said_clear
## ⚠ THE ESCAPE TURNS OFF THE REFUSAL AND NOT THE ADVICE, and this row MOVED at
## issue 1434 to say so. The gate's own comment above the early return is the
## ruling -- *"`set ase_preflight 0` turns off a REFUSAL; it is not a request to
## be told less about a circuit"* -- and until 6g-1 added `saves_resolve` to
## `op`, `dc`, `ac` and `tran` there was no precondition on this fixture's own
## analysis rows to exercise it with. There is now: every ticked output on the
## TYPO bench resolves to nothing, which is measured to stop ngspice running ANY
## analysis (`no data saved for D.C. Operating point analysis`, rc 1,
## `$sim_status` 1, on the fork and on apt 45.2 alike). Turning the save-name
## refusal off does not make that stop being true.
## ⚖ R-OUT8: that caution is DORMANT (see pf_narrowed): the row pins it in the
## narrowed world, and PF216f0 says the real world is quiet.
eqcheck PF216f0-REAL-no-save-list-is-narrowed-so-the-op-caution-is-not-said \
  [list [catch {ase::preflight_gate [mkstate $RD c $TYPO] $NL} e2] \
        [said_count {ase: REFUSED*}] \
        [said_count {*will not run the op analysis at all*}]] {0 0 0}
said_clear
eqcheck PF216f-DORMANT-ase_preflight-0-disables-the-REFUSAL-and-not-the-caution-under-it \
  [pf_narrowed {
     list [catch {ase::preflight_gate [mkstate $RD c $TYPO] $NL} e2] \
          [said_count {ase: REFUSED*}] \
          [said_count {*will not run the op analysis at all*}]}] {0 0 1}
## and the caution is gone the moment the bench has one output that resolves,
## so it is the save list it is about and not the escape
said_clear
eqcheck PF216f2-and-one-resolving-output-silences-it \
  [list [catch {ase::preflight_gate [mkstate $RD c $GOOD] $NL} e2b] [llength $::said]] {0 0}
set ::ase_preflight 1
## --- PF222: AN ENABLED ANALYSIS THIS BACKEND CANNOT RENDER (issue 1401) -----
## (PF221 is taken -- that id is a 54-row family already in this file.)
## The gate's second refusal, and the one that is NOT defeasible. Until 1401 a
## state row whose `type` was none of op/dc/ac/tran was skipped by render_deck's
## emit loop in silence: the run completed, produced no result for it, and the
## Analyses pane went on showing it ticked. The gate checks it too, and checks it
## FIRST, because the gate runs before the deck is written -- so nothing in the
## run directory is touched -- and because a `.state` is a text file a person can
## hand-edit.
## ⚠ THE UNRENDERABLE TYPE WAS `noise`, THEN `sp`, AND IS NOW `pss`. Issue 1432
## gave `noise` and `disto` real entries and Stage 9 (issue 1452) gave `sp` one,
## so **`pss` is the only probe-only type left in the shipped registry** and this
## fixture cannot move again without a fixture backend. Row TF3b of
## tests/headless/test_ase_core.tcl warned in as many words that these rows would
## move; they have now done so twice, in the commit that caused it each time.
set UNREND {{type op enabled 1} {type pss enabled 1 source v1}}
said_clear
set stU [mkstate $RD c $GOOD]
dict set stU analyses $UNREND
set cu1 [catch {ase::preflight_gate $stU $NL} eu1]
eqcheck PF222a-an-unrenderable-analysis-is-refused $cu1 1
eqcheck PF222b-the-refusal-names-the-type \
  [string match "*analysis type 'pss' is not one this simulator can render*" $eu1] 1
eqcheck PF222c-and-says-the-run-would-have-said-nothing \
  [string match "*said nothing*" $eu1] 1
eqcheck PF222d-it-reaches-the-action-log-too \
  [expr {[said_count "*analysis type 'pss'*"] >= 1}] 1
## ⚠ THE ROW THIS SUB-ITEM EXISTS FOR. `ase_preflight 0` is a real lever for the
## save-name check above -- a user who knows their netlist better than the map
## does must not be locked out -- and there is nothing for it to be right about
## here: a deck that emits no analysis at all is not a run anyone can usefully
## force. If this row ever goes green with a 0 in the first slot, the clause has
## drifted BELOW the early return and the silence is back.
set ::ase_preflight 0
said_clear
set cu2 [catch {ase::preflight_gate $stU $NL} eu2]
eqcheck PF222e-ase_preflight-0-does-NOT-defeat-it \
  [list $cu2 [string match "*is not one this simulator can render*" $eu2]] {1 1}
set ::ase_preflight 1
## Non-vacuity: the SAME state with every analysis renderable passes the gate, so
## PF222a is measuring the analysis rows and not something else about this state.
said_clear
set stR [mkstate $RD c $GOOD]
dict set stR analyses {{type op enabled 1} {type tran enabled 1 step 1n stop 1u}}
eqcheck PF222f-a-renderable-state-still-passes \
  [list [catch {ase::preflight_gate $stR $NL} eur] [said_count "*render*"]] {0 0}
## ... and a DISABLED unrenderable row is not refused either: it emits nothing
## today and emitted nothing before, so refusing it would break a bench that
## merely carries a row somebody unticked.
set stD [mkstate $RD c $GOOD]
dict set stD analyses {{type op enabled 1} {type pss enabled 0 source v1}}
eqcheck PF222g-a-disabled-unrenderable-row-is-not-refused \
  [catch {ase::preflight_gate $stD $NL} eud] 0
## ⚠ A REFUSAL NAMES THE RUNDIR'S LEFTOVERS when there are any -- the ruling is
## doc/claude/specs/simulator_profiles.md, "where the gate sits, and what REFUSE
## means here", and every other refusal in ase.tcl carries this clause. The gate
## runs ABOVE run_deck's delete of the previous raw, so a prior run's artifacts
## really are still on disk when it fires.
set stU2 [mkstate $RD c $GOOD]
dict set stU2 analyses $UNREND
set cu3 [catch {ase::preflight_gate $stU2 $NL} eu3]
eqcheck PF222h-the-refusal-names-the-rundirs-earlier-files \
  [list $cu3 [string match "*are from an earlier run*" $eu3] \
        [string match "*[file normalize $RD]*" $eu3]] {1 1 1}
## ... and it does NOT create the directory in order to name it. ase::rundir does
## `file mkdir`, so the sibling refusals CREATE a rundir from inside a message
## whose whole claim is that nothing was written. This one names it only when it
## is already there -- non-vacuity for the row above.
set RDGONE [file join $tmp never_created]
set stU3 [mkstate $RDGONE c $GOOD]
dict set stU3 analyses $UNREND
set cu4 [catch {ase::preflight_gate $stU3 $NL} eu4]
eqcheck PF222i-and-does-not-CREATE-a-rundir-to-name-it \
  [list $cu4 [string match "*earlier run*" $eu4] [file isdirectory $RDGONE]] {1 0 0}
## A backend core does not describe is not refused on ngspice's rank table.
set stU4 [mkstate $RD c $GOOD]
dict set stU4 analyses $UNREND
dict set stU4 simulator someoneelsesim
eqcheck PF222j-another-backends-state-passes-this-gate \
  [catch {ase::preflight_gate $stU4 $NL} eu5] 0

## THE REFUSAL WRITES NOTHING — the CS181 shape, and it matters more here than
## anywhere: a half-written artefact is literally the defect class this item
## exists to kill
set RD2 [file join $tmp run_gate]
file mkdir $RD2
putfile [file join $RD2 c2.spice] $NL
putfile [file join $RD2 c2_ase.raw] "PREVIOUS RUN\n"
said_clear
set c3 [catch {ase::run_deck [mkstate $RD2 c2 $TYPO] [file join $RD2 c2.spice]} e3]
eqcheck PF216g-a-refused-run_deck-leaves-no-artefact \
  "raised=<$c3> refused=<[string match {ase: REFUSED*} $e3]>\
 deck=<[file exists [file join $RD2 c2_ase.spice]]>\
 log=<[file exists [file join $RD2 c2_ase.log]]>\
 prev=<[string trim [readfile [file join $RD2 c2_ase.raw]]]>" \
  {raised=<1> refused=<1> deck=<0> log=<0> prev=<PREVIOUS RUN>}

# ===========================================================================
# PF217 — D1: the corrections are OFFERED, and issue 0503's stale row
# ===========================================================================
## The 0503 mitigation, end to end: a row picked under a `fold` profile stores
## the folded spelling forever, and nothing between the pick and render_deck
## re-cases it. Run it under `distinguish` and the deck would be `.save
## v(topnet)` against a case-kept netlist — rc=1, zero vectors, analysis not
## run, every trace in the session lost. The pre-flight REFUSES it and says so.
set ::sim_case_mode distinguish
said_clear
set c4 [catch {ase::preflight_gate [mkstate $RD c $STALE] $NL} e4]
eqcheck PF217-a-stale-fold-picked-row-REFUSES-under-distinguish \
  [list $c4 [said_count {*issue 0503*}]] {1 1}
eqcheck PF217b-the-correction-is-OFFERED-for-both-rows \
  [list [said_count {*'v(topnet)' -> 'v(TOPNET)'*}] \
        [said_count {*'-i(v.x1.x2.v1)' -> '-i(V.x1.x2.V1)'*}]] {1 1}
## the correction rewrites the IDENTIFIER, not the expression: the leading `-`
## of a derived row survives (above), and a row with nothing to offer says so
said_clear
set c3b [catch {ase::preflight_gate [mkstate $RD c $TYPO] $NL}]
eqcheck PF217c-a-row-with-no-correction-offers-none \
  [list $c3b [said_count {*v(nosuchnode)*is not in the netlist}] \
        [said_count {*Same name in another case*}] [said_count {*issue 0503*}]] \
  {1 1 0 0}
## D1: NEVER A SILENT REWRITE. The gate alone changes no stored row — if our map
## is wrong about something, a silent pass corrupts saved work with no trace.
putfile [file join $RD stale.state] \
  "design {lib dlib cell pf_top view schematic} rundir [list $RD] outputs [list $STALE]"
putfile [file join $RD pf_top.spice] $NL
pcall ase::session_open pfk [file join $RD stale.state]
set c4b [catch {ase::preflight_gate [ase::session_state pfk] $NL} e4b]
eqcheck PF217d-the-gate-REFUSES-and-rewrites-NOTHING \
  [list [string match {ase: REFUSED*} $e4b] \
        [pcall ase::state_get [ase::session_state pfk] outputs]] \
  [list 1 $STALE]
## ...and the apply half, which is an explicit call and says what it changed
said_clear
set nfix [pcall ase::preflight_fix_session pfk]
eqcheck PF217e-the-apply-rewrites-the-rows-on-an-explicit-call \
  [list $nfix [ase::state_get [ase::session_state pfk] outputs]] \
  {2 {{expr v(TOPNET) save 1} {expr -i(V.x1.x2.V1) save 1}}}
eqcheck PF217f-the-apply-says-what-it-changed-and-that-the-session-is-unsaved \
  [list [said_count {*rewritten to*}] [pcall ase::session_dirty pfk]] {2 1}
## and the corrected session now passes the gate it just failed
eqcheck PF217g-the-corrected-session-passes-the-gate \
  [catch {ase::preflight_gate [ase::session_state pfk] $NL}] 0
pcall ase::session_close pfk
set ::sim_case_mode fold

# ===========================================================================
# PF218 — defence (b), the $sim_status guard
# ===========================================================================
## C4's shape, byte for byte, measured on both binaries.
eqcheck PF218-the-guard-is-C4s-measured-shape \
  [pcall ase::backend::ngspice::sim_status_guard] \
  [list {if $?sim_status = 0} {  echo NO-SIM-STATUS} {end} {if $sim_status ne 0} \
        {  echo RUN-FAILED} {  quit 1} {end}]
proc deck_of {analyses {outs {}}} {
  set s [ase::state_default]
  dict set s design [dict create lib dlib cell dcell view schematic]
  dict set s rundir $::RD
  dict set s analyses $analyses
  dict set s outputs $outs
  return [pcall ase::backend::ngspice::render_deck $s "* t\nv1 in 0 1\nr1 in out 1k\n.end\n"]
}
set d2 [deck_of {{type op enabled 1} {type tran enabled 1 step 1n stop 1u}}]
set dl [split [string trimright $d2 "\n"] "\n"]
## AFTER EVERY ANALYSIS, never once at the end. Measured: a failing `dc`
## followed by a good `tran` exits 0 and writes a 2198-byte raw with one guard at
## the end (the failure completely masked, because $sim_status is
## last-writer-wins per analysis) and exits 1 writing nothing with a guard after
## each. A single trailing guard is the defect, not the fix.
set nguard 0
foreach l $dl { if {$l eq {if $sim_status ne 0}} { incr nguard } }
eqcheck PF218b-one-guard-per-ENABLED-analysis $nguard 2
## and each guard IMMEDIATELY follows its own analysis line
set iop [lsearch -exact $dl {op}]
set itr [lsearch -exact $dl {tran 1n 1u}]
eqcheck PF218c-each-guard-immediately-follows-its-analysis \
  [list [lindex $dl [expr {$iop+1}]] [lindex $dl [expr {$itr+1}]]] \
  {{if $?sim_status = 0} {if $?sim_status = 0}}
## the `$?` existence test comes FIRST, and it is a MARKER, not an error
## suppressor. Re-measured 2026-08-17 (fix round): with the full guard alone in
## a .control block and no analysis before it, ngspice-46 prints `Error:
## sim_status: no such variable.` at PARSE time with the `$?` block present
## exactly as without it — the two logs differ only by the `NO-SIM-STATUS` line.
## What that line is for is telling a reader of the log that THIS build has no
## `$sim_status`, i.e. that defence (b) was inert on this run. render_deck never
## emits a guard with no analysis in front of it (PF218e).
eqcheck PF218d-the-existence-test-comes-first \
  [expr {[lsearch -exact $dl {if $?sim_status = 0}] <
         [lsearch -exact $dl {if $sim_status ne 0}]}] 1
## no analysis, no guard — and no `$sim_status` reference anywhere. Asserted
## against the ENABLED case in the same breath, so "no guard anywhere, ever"
## cannot satisfy it
eqcheck PF218e-a-deck-with-no-analysis-carries-no-guard \
  [list [string first {sim_status} [deck_of {{type op enabled 0}}]] \
        [expr {[string first {sim_status} [deck_of {{type op enabled 1}}]] > 0}]] \
  {-1 1}
## the guard is BEFORE remzerovec/write, so a failed analysis quits before the
## artefact is written — that is the whole point of defence (b)
eqcheck PF218f-the-guard-precedes-remzerovec-and-write \
  [expr {[lsearch -exact $dl {  quit 1}] > 0 &&
         [lsearch -exact $dl {  quit 1}] < [lsearch -exact $dl {remzerovec}] &&
         [lsearch -exact $dl {remzerovec}] < [lsearch -glob $dl {write *}]}] 1
## The file a control-line word really names: the word itself, or -- when it is
## a `$var` handed over by a `setcs` line because ngspice could not take the path
## literally (issues 1484/1490) -- that line's value, quotes off.
proc pf_resolve {word lines} {
  if {![string match {$*} $word]} { return $word }
  set v [string range $word 1 end]
  foreach l $lines {
    if {[regexp "^setcs +$v += +(.*)\$" [string trim $l] -> pv]} {
      return [string trim $pv " '\""]
    }
  }
  return $word
}
## ⚠ AND THE SIDECAR RECORD IS INSIDE THAT SAME BRACKET (issue 1430). The plot
## sidecar's whole value is that record N names the row that wrote plot N, so a
## record appended for an analysis that then failed to write would put every
## later position out by one — silently, because a failed run is the one case
## nobody re-reads the file for. The record sits BELOW the guard and IMMEDIATELY
## ABOVE the write it describes, and this row pins both halves at once.
## ⚠ "IMMEDIATELY ABOVE" ALLOWS THE ONE ESCAPE LINE THAT MAY SIT BETWEEN THEM.
## Since issues 1484/1490 a path ngspice cannot take literally -- a run directory
## with a capital or a space -- is handed to the `write` through a `setcs`
## variable defined on the line above it, so on such a tester's machine the gap
## is one line and not zero. Anything ELSE between the two is still a red: the
## span is computed and every line in it must be a `setcs`.
set pfspan {}
foreach pfi [list [expr {[lsearch -glob $dl {echo "PLOT *}] + 1}]] {
  for {set pfj $pfi} {$pfj < [lsearch -glob $dl {write *}]} {incr pfj} {
    lappend pfspan [lindex $dl $pfj]
  }
}
set pfspanok 1
foreach pfl $pfspan { if {![string match {setcs *} $pfl]} { set pfspanok 0 } }
eqcheck PF218f2-the-sidecar-record-is-below-the-guard-and-above-its-own-write \
  [expr {[lsearch -glob $dl {echo "PLOT *}] > [lsearch -exact $dl {  quit 1}] &&
         [lsearch -glob $dl {echo "PLOT *}] > [lsearch -exact $dl {remzerovec}] &&
         [lsearch -glob $dl {echo "PLOT *}] < [lsearch -glob $dl {write *}] &&
         $pfspanok && [llength $pfspan] <= 1}] 1
## ...and it goes to the sidecar, never to the results file: two artefacts, two
## paths, and an `echo` that landed on the raw would corrupt it beyond reading.
## ⚠ `pfmap` IS SEEDED BEFORE THE REGEXP, AND A SABOTAGE IS WHY. Respelling
## ase::plotmap_record without its `|` delimiters made this regexp miss, left
## `pfmap` unset, and the `string match` below then RAISED -- which this file's
## outer catch turns into `FATAL: can't read "pfmap"` and `1 FAILED (65 passed)`:
## an UNNAMED failure that costs 129 of the 194 checks and reads, in a sabotage
## log, as though almost nothing went red. Issue 1429's S31 is the same lesson
## one file over. The seed makes the miss a NAMED red.
set pfmap {NO-RECORD-LINE}
eqcheck PF218f3-the-record-goes-to-the-sidecar-and-not-to-the-results-file \
  [list [regexp {^echo "PLOT op 0 \|\$curplotname\|" >> (.*)$} \
          [lindex $dl [lsearch -glob $dl {echo "PLOT *}]] -> pfmap] \
        [expr {[string match {*_ase.plotmap} [pf_resolve $pfmap $dl]] ? 1 : 0}] \
        [expr {[string match {*_ase.raw} [pf_resolve $pfmap $dl]] ? 1 : 0}]] \
  {1 1 0}
## CREW_BRIEF §4: the deck SHAPE is unchanged otherwise — no dot card for the
## analyses, no `run`, and the `write` line still names NO VECTORS (upstream
## 0073, unfixed: naming them writes two identical columns with byte-identical
## names that no filter can separate)
set wl [lindex $dl [lsearch -glob $dl {write *}]]
eqcheck PF218g-the-write-line-still-names-no-vectors \
  [list [llength $wl] $nguard] {2 2}
eqcheck PF218h-no-dot-card-and-no-bare-run-were-added \
  [list [lsearch -exact $dl {run}] [lsearch -exact $dl {.tran 1n 1u}] $nguard] \
  {-1 -1 2}

# ===========================================================================
# PF219 — defence (c), content-based rejection
# ===========================================================================
## The measured signature, verbatim from a 569-byte raw ngspice-46 wrote when
## the only fault in the deck was one `.save` of a node that does not exist.
set CONSTHDR {Title: Constant values
Date: Sun Aug  2 23:29:26 UTC 2026
Command: ngspice-46, Build Sun Aug  2 23:29:26 UTC 2026
Plotname: constants
Flags: complex
No. Variables: 12
No. Points: 1
Variables:
	0	yes	notype
	1	false	notype
Binary:
}
set craw [file join $tmp constants.raw]
putfile $craw $CONSTHDR
set cv [pcall ase::raw_content_verdict $craw]
eqcheck PF219-the-constants-raw-is-REJECTED \
  [list [dg $cv ok] [dg $cv constants] [dg $cv plotname] [dg $cv nvars]] \
  {0 1 constants 12}
## all four of C3's markers fire on the real file, and the message shows its work
eqcheck PF219b-all-four-markers-are-recorded [llength [dg $cv signature]] 4
eqcheck PF219c-the-Date-is-recognised-as-the-BUILD-stamp \
  [expr {[lsearch -glob [dg $cv signature] {Date:*build stamp*}] >= 0}] 1
## a REAL raw is not rejected, and carries no constants signature at all — a
## variable-count floor on its own would fire on this file (2 variables)
set graw [file join $tmp good.raw]
putfile $graw "Title: * a real run\nDate: Mon Aug 17 19:40:28  2026\nCommand: ngspice-46, Build Sun Aug  2 23:29:26 UTC 2026\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 59\nVariables:\n\t0\ttime\ttime\nBinary:\n"
set gv [pcall ase::raw_content_verdict $graw]
eqcheck PF219d-a-real-raw-is-accepted-and-carries-no-signature \
  [list [dg $gv ok] [dg $gv signature]] {1 {}}
## C3's `set appendwrite` shape: a constants plot hiding BEHIND real data. Not
## rejected — plot 1 is genuine and the C reader selects by sim_type, which
## `constants` never matches — but reported, because it is not simulation data.
## OVER 64 KB on purpose: the appended plot is reachable only through the TAIL
## read, which is the whole reason the scan is head+tail and not head alone.
set araw [file join $tmp append.raw]
putfile $araw "Title: * a real run\nDate: Mon Aug 17 19:40:28  2026\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 59\nVariables:\n\t0\ttime\ttime\nBinary:\n[string repeat x 70000]\n$CONSTHDR"
set av [pcall ase::raw_content_verdict $araw]
eqcheck PF219e-the-appendwrite-shape-is-reported-not-rejected \
  [list [dg $av ok] [dg $av appended] [expr {[file size $araw] > 65536}]] {1 1 1}
## and the attach REPORTS it rather than refusing: plot 1 is genuine data, and
## the C reader selects a plot by sim_type, which `constants` never matches
said_clear
pcall ase::attach_dbs $araw tran
eqcheck PF219e2-the-attach-reports-the-appended-plot-and-does-not-reject-it \
  [list [said_count {*appended behind the real data*}] [said_tag_count note] \
        [said_count {*NOT ATTACHED*}]] {1 1 0}
## a file that merely QUOTES the header is not a raw and must not be judged --
## our own refusal message quotes `Plotname: constants`, and so does any run log
## that captured it
set qraw [file join $tmp quotes.log]
putfile $qraw "ase: REFUSED -- ... a raw file holding TWELVE MATHEMATICAL CONSTANTS (Plotname: constants) ...\n"
set qv [pcall ase::raw_content_verdict $qraw]
eqcheck PF219e3-a-file-that-merely-quotes-the-header-is-not-judged \
  [list [dg $qv ok] [dg $qv appended] [dg $qv plotname]] {1 0 {}}
## a file this check cannot parse as a spice raw is NOT judged: judging a format
## we did not parse is how a content check becomes a false rejection
set vraw [file join $tmp notaraw.vcd]
putfile $vraw "\$date today \$end\n\$var wire 1 ! clk \$end\n"
eqcheck PF219f-a-file-that-is-not-a-spice-raw-is-not-judged \
  [list [dg [pcall ase::raw_content_verdict $vraw] ok] \
        [dg [pcall ase::raw_content_verdict $vraw] plotname]] {1 {}}
eqcheck PF219g-an-absent-file-is-not-judged \
  [dg [pcall ase::raw_content_verdict [file join $tmp nope.raw]] ok] 1
## an empty result — zero points — is the other shape an analysis that did not
## run leaves behind
set eraw [file join $tmp empty.raw]
putfile $eraw "Title: * t\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 0\nNo. Points: 0\nVariables:\nBinary:\n"
eqcheck PF219h-a-zero-point-raw-is-rejected \
  [dg [pcall ase::raw_content_verdict $eraw] ok] 0
## AND THE ATTACH REFUSES IT WITHOUT DISTURBING THE DATABASE ALREADY LOADED.
## "A stale-but-loaded DB beats an empty viewer" is attach_dbs' stated policy;
## a rejection that cleared the registry first would trade one wrong answer for
## another.
set fixraw [file join $here .. .. doc claude casemode_batch fixtures tr_fold.raw]
pcall xschem raw read $fixraw tran
set before [pcall xschem raw list]
## the control this check needs: a `before` that is an error string would make
## PF219k compare one failure against another and pass on both
eqcheck PF219h2-the-control-database-really-did-load \
  [expr {[llength $before] == 4 && [lsearch -exact $before {v(in)}] >= 0}] 1
said_clear
set att [pcall ase::attach_dbs $craw tran]
eqcheck PF219i-a-constants-raw-is-NOT-attached \
  [list [dg $att n] [dg $att current] \
        [string match {*twelve built-in mathematical constants*} [dg $att rejected]]] \
  {0 -1 1}
eqcheck PF219j-the-rejection-is-loud-and-red \
  [list [said_count {*NOT ATTACHED*}] [said_tag_count error]] {1 1}
eqcheck PF219k-the-previously-loaded-database-is-untouched \
  [list [expr {[pcall xschem raw list] eq $before}] [said_count {*NOT ATTACHED*}]] \
  {1 1}
pcall xschem raw clear

# ===========================================================================
# PF221 — THE FIX ROUND. Ten reproduced defects and five coverage holes, raised
# by three independent reviewers of item 10's first cut. Every check below names
# the one it pins, and every one of them was RED before its fix.
# ===========================================================================

## --- the AC output forms are not v()/i() identifiers ------------------------
## `vi(...)` is ngspice's AC imaginary part; unanchored, `([vi])\(` matched the
## `i(` inside it, so `vi(out)` was read as a CURRENT named `out`, looked up in
## the device table, found absent, and the WHOLE RUN REFUSED with a nonsense
## diagnosis. `deriv(time)` was read as `v(time)` the same way. Both are
## reachable straight from the free-text Expression entry of the output editor.
eqcheck PF221-vi-is-not-an-i-identifier [pcall ase::preflight_idents {vi(out)}] {}
eqcheck PF221b-deriv-is-not-a-v-identifier [pcall ase::preflight_idents {deriv(time)}] {}
## the hole was ASYMMETRIC — vdb/vm/vp/vr already passed — which is exactly why
## no family-level test could see it
eqcheck PF221c-the-whole-AC-family-is-left-alone \
  [list [pcall ase::preflight_idents {vdb(out)}] [pcall ase::preflight_idents {vm(out)}] \
        [pcall ase::preflight_idents {vp(out)}] [pcall ase::preflight_idents {vr(out)}] \
        [pcall ase::preflight_idents {group_delay(out)}]] {{} {} {} {} {}}
## and the anchor cost no real identifier its extraction, in any position
eqcheck PF221d-a-real-identifier-still-extracts-in-every-position \
  [list [pcall ase::preflight_idents {v(a)}] [pcall ase::preflight_idents {2*v(a)+i(r1)}] \
        [pcall ase::preflight_idents {-i(v1)}] [pcall ase::preflight_idents {deriv(v(TOPNET))}]] \
  {{{voltage a}} {{voltage a} {current r1}} {{current v1}} {{voltage TOPNET}}}
## THE POINT OF ALL FOUR: a legitimate AC row must not be refused
set ::sim_case_mode fold
said_clear
eqcheck PF221e-an-AC-output-row-is-NOT-refused \
  [list [catch {ase::preflight_gate [mkstate $RD c \
           {{expr vi(TOPNET) save 1} {expr 2*vdb(TOPNET) save 1} \
            {expr deriv(v(TOPNET)) save 1}}] $NL} e21] \
        [said_count {ase: REFUSED*}]] {0 0}

## --- a mis-cased HIERARCHY SEGMENT is as fatal as a mis-cased leaf ----------
## The leaf's verdict is not the identifier's verdict. With the netlist spelling
## the instance `X1`, a stale fold-picked `v(x1.out)` under `distinguish`
## resolved `present` on the strength of its correctly-cased leaf — the exact
## 0503 row defence (a) exists to catch, passed through in silence, while the
## case-keeping binary aborts the analysis (rc=1, RUN-FAILED, no raw).
set NLI "* seg\nX1 in out sub\nV1 in 0 1\n.subckt sub a out\nR1 a out 1k\n.ends\n.end\n"
set MI [pcall ase::netlist_map $NLI]
eqcheck PF221f-a-mis-cased-INSTANCE-segment-is-absent-under-distinguish \
  [list [dg [pcall ase::netlist_map_resolve $MI voltage x1.out 1] status] \
        [dg [pcall ase::netlist_map_resolve $MI voltage x1.out 1] real]] \
  {absent X1.out}
## asserted against the correctly-cased path in the same breath, so "absent for
## everything hierarchical" cannot satisfy it
eqcheck PF221g-the-correctly-cased-path-still-resolves-present \
  [dg [pcall ase::netlist_map_resolve $MI voltage X1.out 1] status] present
eqcheck PF221h-and-under-fold-it-is-present-either-way \
  [dg [pcall ase::netlist_map_resolve $MI voltage x1.out 0] status] present
## end to end: the gate refuses it and offers the WHOLE-PATH correction
set ::sim_case_mode distinguish
said_clear
set ci21 [catch {ase::preflight_gate [mkstate $RD c {{expr v(x1.out) save 1}}] $NLI} ei21]
eqcheck PF221i-the-gate-refuses-the-mis-cased-instance-and-offers-the-path \
  [list $ci21 [said_count {*'v(x1.out)' -> 'v(X1.out)'*}]] {1 1}
set ::sim_case_mode fold

## --- an .include-bearing scope STANDS DOWN, but only where it is blind ------
## A design whose stimulus cards live in an `.include`d file was REFUSED for a
## run the simulator completes perfectly (measured: rc=0, a 2071-byte transient
## raw). C4 says the pre-flight is BLIND there, and blind means stand down, not
## refuse — the expensive direction every ruling in this file leans away from.
set NLX "* tb\n.include stim.sp\nR1 in out 1k\nC1 out 0 1n\n.end\n"
set MX [pcall ase::netlist_map $NLX]
eqcheck PF221j-an-include-bearing-scope-records-itself [dex $MX includes {}] 1
eqcheck PF221k-a-name-only-an-include-could-define-is-UNKNOWN-not-absent \
  [dg [pcall ase::netlist_map_resolve $MX current V1 0] status] unknown
said_clear
eqcheck PF221l-and-that-run-is-NOT-refused \
  [list [catch {ase::preflight_gate [mkstate $RD c \
           {{expr v(out) save 1} {expr i(V1) save 1}}] $NLX} ex21] \
        [said_count {ase: REFUSED*}]] {0 0}
## ...and the stand-down is NARROW ON PURPOSE. A FOLD HIT is a proof about THIS
## netlist — it is D1's correction and issue 0503's whole subject — so an
## include-bearing netlist still refuses it. Downgrading every miss would leave
## defence (a) inert on every real design, all of which .include a PDK.
set NLY "* tb\n.include models.lib\nV1 IN 0 1\nR1 IN OUT 1k\n.end\n"
set MY [pcall ase::netlist_map $NLY]
eqcheck PF221m-a-fold-hit-still-refuses-in-an-include-bearing-netlist \
  [list [dg [pcall ase::netlist_map_resolve $MY voltage out 1] status] \
        [dg [pcall ase::netlist_map_resolve $MY voltage out 1] real]] {absent OUT}
eqcheck PF221n-a-netlist-with-NO-include-still-refuses-a-plain-typo \
  [dg [pcall ase::netlist_map_resolve $MAP voltage nosuchnode 1] status] absent

## --- a `+` continuation is FOLDED onto its card, not skipped ----------------
## Skipping it was a false refusal: a node declared only on a continuation was
## missing from the map. The premise that xschem never emits them for element
## cards is false — the user's own ~/.xschem/simulations/tb_bandgap.spice
## carries 46 and 0_examples_top.spice 439.
set NLP ".subckt amp inp inn\n+ outp\nR1 inp inn 1k\n.ends\nX1 IN1 IN2 O1 amp\n.end\n"
set MP [pcall ase::netlist_map $NLP]
eqcheck PF221o-a-port-on-a-continuation-line-is-a-node \
  [dex [dg $MP scopes] amp nodes outp] 1
eqcheck PF221p-and-the-run-that-names-it-is-not-refused \
  [dg [pcall ase::netlist_map_resolve $MP voltage x1.outp 0] status] present
## and the X-card master survives a wrap between the last node and the master,
## which the old skip got wrong in the other direction too
set MQ [pcall ase::netlist_map "* t\nXM4 net7 EN_N VCC\n+ VCC sky130_pfet L=6\n+ mult=1\n.subckt sky130_pfet d g s b\n.ends\n.end\n"]
eqcheck PF221q-an-X-card-wrapped-before-its-master-still-names-the-master \
  [list [dgn $MQ scopes {} insts XM4] [dex [dg $MQ scopes] {} nodes sky130_pfet] \
        [dex [dg $MQ scopes] {} nodes mult]] {sky130_pfet 0 0}

## --- a MULTI-IDENTIFIER output row, which no state in the first cut had -----
## Nothing proved the scan looked past the FIRST identifier of a row: truncating
## the ident loop to `lrange ... 0 0` left all 74 checks green, and a
## `.save v(a)-v(typo)` sailing through would have been invisible.
## ⚠ RESTATED 2026-10-11 (ase_l.md R-OUT3a): an output expression no longer
## reaches the deck, so the scan reads the CARDS (ase::output_card_sources). A
## multi-identifier row is now a Calculator expression whose signals become cards
## once a ticked plain row narrows the deck -- the v(TOPNET) row here.
## ⚠ RESTATED AGAIN, second fix round 2026-10-11: an output EXPRESSION can never
## block or refuse a run, so its read cards are not checked at all (the absent
## one is ignored by ngspice, measured, and named in the row's Value after the
## run).  The past-the-first-identifier property lives on in PF221s's
## differential PLAIN row, and in PF221t/u below.
set ::sim_case_mode fold
set sd21 [pcall ase::preflight_scan [mkstate $RD c {{expr v(TOPNET) save 1} {expr {v(TOPNET) v(nosuchnode) -} save 1}}] $NL]
eqcheck PF221r-an-expression-rows-absent-read-is-NOT-checked \
  [list [llength [dg $sd21 absent]] [llength [dg $sd21 unknown]]] {0 0}
set sdd21 [pcall ase::preflight_scan [mkstate $RD c {{expr v(TOPNET,nosuchnode) save 1}}] $NL]
eqcheck PF221s-a-differential-row-is-checked-on-BOTH-nodes \
  [list [llength [dg $sdd21 absent]] [dgn [lindex [dg $sdd21 absent] 0] ident]] {1 nosuchnode}

## --- the refusal head counts EXPRESSIONS, not identifiers -------------------
## One output row naming two absent nodes is ONE output expression; the head
## counted `[llength $rows]` and worded it as expressions, so it said "2".
## Read off with a regexp so the count, the plural and the verb are all pinned
## without depending on the em dash's byte sequence.
said_clear
set ch21 [catch {ase::preflight_gate [mkstate $RD c {{expr v(TOPNET) save 1} {expr v(nosuchnode,alsonot) save 1}}] $NL} eh21]
set n21 {} ; set p21 X ; set v21 {}
catch {regexp {REFUSED[^0-9]*([0-9]+) output expression(s?) (names?) } $eh21 -> n21 p21 v21}
eqcheck PF221t-the-refusal-head-counts-EXPRESSIONS-not-identifiers \
  [list $ch21 $n21 $p21 $v21] {1 1 {} names}
## and BOTH identifiers still get their own line: the head is a count, the
## detail lines are the thing a user can act on
eqcheck PF221u-but-both-identifiers-still-get-their-own-line \
  [list [said_count {*'nosuchnode' is not in the netlist*}] \
        [said_count {*'alsonot' is not in the netlist*}]] {1 1}
## two DIFFERENT rows still read as two, so "always say 1" cannot satisfy PF221t
said_clear
set ch21b [catch {ase::preflight_gate [mkstate $RD c \
             {{expr v(nosuchnode) save 1} {expr v(alsonot) save 1}}] $NL} eh21b]
set n21b {} ; set p21b X ; set v21b {}
catch {regexp {REFUSED[^0-9]*([0-9]+) output expression(s?) (names?) } $eh21b -> n21b p21b v21b}
eqcheck PF221v-two-rows-read-as-two-expressions [list $n21b $p21b $v21b] {2 s name}

## --- D1's OFFER is composed, and repairs a row WHOLE ------------------------
## The old builder was a literal `string map` of `v(<ident>)`. It matched
## NOTHING inside `v(a,b)` — so the refusal named a remedy command that silently
## did nothing and the row was a permanent dead end — and for a derived row it
## could apply only the FIRST correction, because the second no longer matched
## the string the first had already rewritten.
set NLD "* d\nV1 OUTP 0 1\nV2 OUTN 0 1\nR1 OUTP OUTN 1k\n.end\n"
set ::sim_case_mode distinguish
set sdif [pcall ase::preflight_scan [mkstate $RD c {{expr v(outp,outn) save 1}}] $NLD]
eqcheck PF221w-both-halves-of-a-differential-row-are-absent-WITH-corrections \
  [list [llength [dg $sdif absent]] [dgn [lindex [dg $sdif absent] 0] correction] \
        [dgn [lindex [dg $sdif absent] 1] correction]] {2 OUTP OUTN}
eqcheck PF221x-the-offer-repairs-a-differential-row-WHOLE \
  [pcall ase::preflight_fixed_expr [dg $sdif absent]] {v(OUTP,OUTN)}
## The builder is a pure function of the absent rows, so a derived row is
## driven with the rows the scan would build for it -- the scan no longer reads
## an expression row (R-OUT3a), but the builder's whole-row repair is still the
## property worth pinning.
set sder [list [dict create expr {v(outp) v(outn) -} kind voltage ident outp correction OUTP ambiguous 0 why {}] \
               [dict create expr {v(outp) v(outn) -} kind voltage ident outn correction OUTN ambiguous 0 why {}]]
eqcheck PF221y-the-offer-repairs-a-derived-row-WHOLE \
  [pcall ase::preflight_fixed_expr $sder] {v(OUTP) v(OUTN) -}
## ONE offer per expression on the CIW, not two mutually exclusive halves
said_clear
set cd21 [catch {ase::preflight_gate [mkstate $RD c {{expr v(outp,outn) save 1}}] $NLD} ed21]
eqcheck PF221z-the-gate-offers-ONE-whole-correction-per-expression \
  [list $cd21 [said_count {*'v(outp,outn)' -> 'v(OUTP,OUTN)'*}] \
        [said_count {*Same name in another case*}]] {1 1 1}

## --- ...and so does the APPLY ----------------------------------------------
## One call must leave the row RUNNABLE. The old one rewrote at most one
## identifier per row, reported success with a non-zero count, and the only
## signal that the repair was partial was the next run refusing again.
set RD4 [file join $tmp run_fix]
file mkdir $RD4
putfile [file join $RD4 dcell.spice] $NLD
putfile [file join $RD4 dif.state] \
  "design {lib dlib cell dcell view schematic} rundir [list $RD4] outputs\
 {{expr v(outp,outn) save 1} {expr v(outn) save 1} {expr {v(outp) v(outn) -} save 1}}"
pcall ase::session_open dfk [file join $RD4 dif.state]
said_clear
set nfx21 [pcall ase::preflight_fix_session dfk]
## The EXPRESSION row is left as typed: it is not the pre-flight's to check or
## rewrite (R-OUT3a); its Value names any miss after the run.
eqcheck PF221aa-one-call-repairs-EVERY-identifier-of-EVERY-plain-row \
  [list $nfx21 [pcall ase::state_get [ase::session_state dfk] outputs]] \
  {2 {{expr v(OUTP,OUTN) save 1} {expr v(OUTN) save 1} {expr {v(outp) v(outn) -} save 1}}}
## the property the partial rewrite silently destroyed
eqcheck PF221ab-and-the-repaired-session-passes-the-gate-it-just-failed \
  [catch {ase::preflight_gate [ase::session_state dfk] $NLD}] 0
## an apply that changes nothing SAYS so: a silent 0 from the command the
## refusal itself told the user to run reads as "it worked"
said_clear
set nfx21b [pcall ase::preflight_fix_session dfk]
eqcheck PF221ac-an-apply-that-changes-nothing-says-so \
  [list $nfx21b [said_count {*nothing was rewritten*}]] {0 1}
pcall ase::session_close dfk
set ::sim_case_mode fold

## --- `preserve` is a real mode and D1 rules on it ---------------------------
## Nothing exercised it: `$mode ne {fold}` in place of `$mode eq {distinguish}`
## left all 74 checks green while turning preserve case-SENSITIVE. Under
## preserve a folded `.save` resolves (upstream 0056), so D1's scope ruling —
## "this is distinguish-only" — is what this pins.
set ::sim_case_mode preserve
set sp21 [pcall ase::preflight_scan [mkstate $RD c $STALE] $NL]
eqcheck PF221ad-preserve-compares-case-INSENSITIVELY \
  [list [dg $sp21 mode] [dg $sp21 cs] [llength [dg $sp21 absent]]] {preserve 0 0}
set ::sim_case_mode fold

## --- the `.ends` stack pop --------------------------------------------------
## $NL has only sibling subcircuits with nothing at top level after them, so the
## stack never had to unwind: `if {0}` in place of the pop stayed green while
## every top-level card of a hand-written or .include-style deck got filed into
## the last subcircuit's scope and every top-level probe read absent.
## ase::run_existing runs exactly such user-supplied artifacts.
set MT [pcall ase::netlist_map ".subckt s a b\nR1 a b 1k\n.ends\n* now the top level\nV9 TOPAFTER 0 1\n.end\n"]
eqcheck PF221ae-a-top-level-card-AFTER-a-subckt-lands-at-the-TOP \
  [list [dex [dg $MT scopes] {} nodes TOPAFTER] [dex [dg $MT scopes] s nodes TOPAFTER]] {1 0}
eqcheck PF221af-and-it-resolves-present-from-the-top \
  [dg [pcall ase::netlist_map_resolve $MT voltage TOPAFTER 1] status] present

## --- the empty-result test is about VARIABLES, not points -------------------
## PF219h's fixture sets BOTH counters to 0, so `&&` in place of `||` stayed
## green there. This pair still separates them; what INVERTED at the `annotate`
## merge is which half rejects.
##
## ⚠ PF221ag WAS `...-is-rejected` AND IS NOW `...-is-ACCEPTED`, and the comment
## it carried -- "real variables over zero points is the actual shape of an
## analysis that started and produced nothing" -- was half the truth. It is
## equally the shape of an analysis that started and HAS NOT GOT THERE YET:
## MEASURED on `annotate` (issue 0896), ngspice writes `No. Points: 0` at the
## START of a run and backfills the count at the end, so every simulation leaves
## exactly these bytes on disk for its whole duration. Nothing in the file tells
## the two apart -- only time does.
##
## SO THE TIE IS BROKEN ON CONSEQUENCE, not on which reading is likelier.
## Rejecting makes the waveform window unable to attach a run until the run is
## over, which is the feature 0896 is about. Accepting costs nothing: the
## downstream guards already treat a zero-point database as the ordinary path --
## update_op()'s zero-point guard (save.c, issue 0836) exists precisely because
## it is, and it used to SIGSEGV there -- and update_op publishes nothing from it
## anyway. A guard here calling it malformed contradicted a guard there calling
## it normal.
##
## PF221ah below is untouched and is what keeps this pair honest: NO VARIABLES is
## still a rejection, because a file with no vectors holds nothing and never will.
set zraw [file join $tmp zeropoints.raw]
putfile $zraw "Title: * t\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 0\nVariables:\nBinary:\n"
eqcheck PF221ag-variables-but-ZERO-POINTS-is-ACCEPTED-a-run-that-has-not-got-there-yet \
  [dg [pcall ase::raw_content_verdict $zraw] ok] 1
set zvraw [file join $tmp zerovars.raw]
putfile $zvraw "Title: * t\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 0\nNo. Points: 59\nVariables:\nBinary:\n"
eqcheck PF221ah-points-but-ZERO-VARIABLES-is-rejected \
  [dg [pcall ase::raw_content_verdict $zvraw] ok] 0

## --- the COUNT may CONTRADICT the plot name, not only corroborate it --------
## `let`-created vectors written from the constants plot give a file headed
## `Plotname: constants` that holds real data — the tree's own
## ngspice_upstream/.../repro/letonly.raw is 14 variables over 5 points, whose
## header this fixture copies. Rejecting it threw the data away while asserting
## the file "holds ngspice's twelve built-in mathematical constants".
set lraw [file join $tmp letonly.raw]
putfile $lraw "Title: Constant values\nDate: Thu Aug 13 17:41:58 UTC 2026\nCommand: ngspice-46+, Build Thu Aug 13 17:41:58 UTC 2026\nPlotname: constants\nFlags: complex\nNo. Variables: 14\nNo. Points: 5\nVariables:\n\t0\tyes\tnotype\nBinary:\n"
set lv21 [pcall ase::raw_content_verdict $lraw]
eqcheck PF221ai-a-constants-plot-carrying-REAL-VECTORS-is-reported-not-rejected \
  [list [dg $lv21 ok] [dg $lv21 constants] [string match {*holds real vectors*} [dg $lv21 why]]] \
  {1 1 1}
## asserted in the same breath as the REAL 12-over-1 constants raw, so "never
## reject anything" cannot satisfy it
eqcheck PF221aj-and-the-real-12-over-1-constants-raw-is-still-rejected \
  [dg [pcall ase::raw_content_verdict $craw] ok] 0
## and the attach REPORTS it, at tag `note`, instead of refusing
said_clear
pcall ase::attach_dbs $lraw tran
eqcheck PF221ak-the-attach-reports-it-and-does-not-reject-it \
  [list [said_count {*holds real vectors*}] [said_tag_count note] \
        [said_count {*NOT ATTACHED*}]] {1 1 0}
pcall xschem raw clear

## --- the guard was only ever driven for `op` and `tran` ---------------------
## Restricting the emission to those two left FIVE suites and 336 checks green
## with `dc` and `ac` completely unguarded — and C4's masking measurement is
## built on exactly a failing `dc`: `dc v9 0 1 0.1` on a source the circuit does
## not have, followed by a good `tran`, with one trailing guard -> rc=0 and a
## 1175-byte raw written, the failure masked.
set d21 [deck_of {{type op enabled 1} {type dc enabled 1 source v1 start 0 stop 1 step 0.1} \
                  {type ac enabled 1 points 10 start 1 stop 1k} \
                  {type tran enabled 1 step 1n stop 1u}}]
set dl21 [split [string trimright $d21 "\n"] "\n"]
set ng21 [llength [lsearch -all -exact $dl21 {if $sim_status ne 0}]]
set iop21 [lsearch -exact $dl21 {op}]
set idc21 [lsearch -exact $dl21 {dc v1 0 1 0.1}]
set iac21 [lsearch -exact $dl21 {ac dec 10 1 1k}]
set itr21 [lsearch -exact $dl21 {tran 1n 1u}]
eqcheck PF221al-EVERY-analysis-type-carries-its-own-guard \
  [list $ng21 [expr {$iop21 >= 0 && $idc21 >= 0 && $iac21 >= 0 && $itr21 >= 0}] \
        [lindex $dl21 [expr {$iop21+1}]] [lindex $dl21 [expr {$idc21+1}]] \
        [lindex $dl21 [expr {$iac21+1}]] [lindex $dl21 [expr {$itr21+1}]]] \
  [list 4 1 {if $?sim_status = 0} {if $?sim_status = 0} {if $?sim_status = 0} \
        {if $?sim_status = 0}]
eqcheck PF221am-a-dc-only-deck-is-guarded \
  [llength [lsearch -all -exact \
     [split [deck_of {{type dc enabled 1 source v1 start 0 stop 1 step 0.1}}] "\n"] \
     {if $sim_status ne 0}]] 1
eqcheck PF221an-an-ac-only-deck-is-guarded \
  [llength [lsearch -all -exact \
     [split [deck_of {{type ac enabled 1 points 10 start 1 stop 1k}}] "\n"] \
     {if $sim_status ne 0}]] 1

# ===========================================================================
# PF220 — the real simulator, when there is one
# ===========================================================================
# Everything above is a pure function. This leg is the end-to-end measurement
# defence (b) exists for, and it is the only thing that can notice if ngspice
# ever stops honouring `quit 1` inside .control. SKIPPED, never failed, when no
# ngspice is on PATH, and it prints no substring full_audit.sh scores a file on.
if {[auto_execok ngspice] eq {}} {
  puts "SKIPPED: PF220 real-simulator legs (no ngspice on PATH)"
} else {
  set RD3 [file join $tmp run_real]
  file mkdir $RD3
  putfile [file join $RD3 rc.spice] "* pf real\nv1 in 0 dc 1\nr1 in out 1k\nc1 out 0 1n\n.end\n"
  proc realstate {outs} {
    set s [ase::state_default]
    dict set s design [dict create lib dlib cell rc view schematic]
    dict set s rundir $::RD3
    dict set s analyses {{type tran enabled 1 step 1n stop 10n}}
    dict set s outputs $outs
    return $s
  }
  file delete -force [file join $RD3 rc_ase.raw]
  set idg [pcall ase::run_deck [realstate {{expr v(out) save 1}}] [file join $RD3 rc.spice]]
  set ecg [pcall ase::wait $idg]
  ## A1's direction: the guard must not cost a good run anything. The deck it
  ## ran is read back, so "exit 0" cannot be satisfied by a deck with no guard
  ## in it.
  eqcheck PF220-a-guarded-good-run-still-exits-0-and-writes-its-raw \
    [list $ecg [expr {[file isfile [file join $RD3 rc_ase.raw]] &&
                      [file size [file join $RD3 rc_ase.raw]] > 0}] \
          [string match {*RUN-FAILED*} [readfile [file join $RD3 rc_ase.spice]]]] {0 1 1}
  ## the same deck with ONE absent .save. The pre-flight is disabled on purpose:
  ## this leg is defence (b)'s own measurement, and defence (a) would otherwise
  ## refuse before the simulator ever started.
  file delete -force [file join $RD3 rc_ase.raw]
  ## ⚖ R-OUT8: an Outputs save no longer narrows the deck (it brings `.save
  ## all`), so the starving save is the NETLIST's own card here -- text ASE-L
  ## did not write and does not widen -- which keeps this leg measuring the
  ## guard rather than the leader.
  putfile [file join $RD3 rcbad.spice] \
    "* pf real\nv1 in 0 dc 1\nr1 in out 1k\nc1 out 0 1n\n.save v(nosuchnode)\n.end\n"
  set ::ase_preflight 0
  set idb [pcall ase::run_deck [realstate {}] [file join $RD3 rcbad.spice]]
  set ecb [pcall ase::wait $idb]
  set ::ase_preflight 1
  eqcheck PF220b-a-failed-analysis-leaves-NO-ARTEFACT-AT-ALL \
    [list [expr {$ecb != 0}] [file exists [file join $RD3 rc_ase.raw]]] {1 0}
  eqcheck PF220c-and-the-log-says-RUN-FAILED-in-so-many-words \
    [string match {*RUN-FAILED*} [readfile [file join $RD3 rc_ase.log]]] 1
  ## the log must NOT carry the $? complaint: a bare $sim_status before the first
  ## analysis prints `Error: sim_status: no such variable.` into this same file
  eqcheck PF220d-no-no-such-variable-complaint-in-the-log \
    [list [string match {*sim_status: no such variable*} \
             [readfile [file join $RD3 rc_ase.log]]] \
          [string match {*NO-SIM-STATUS*} [readfile [file join $RD3 rc_ase.log]]] \
          [string match {*RUN-FAILED*} [readfile [file join $RD3 rc_ase.log]]]] {0 0 1}
  ## and defence (c) would have caught the file defence (b) prevented: the same
  ## deck WITHOUT the guard writes the twelve-constants raw. Rendered by hand so
  ## the shipped renderer is not the thing under test here.
  set hand [file join $RD3 hand.cir]
  putfile $hand "* pf real, unguarded\nv1 in 0 dc 1\nr1 in out 1k\nc1 out 0 1n\n.save v(nosuchnode)\n.control\ntran 1n 10n\nremzerovec\nwrite [file join $RD3 hand.raw]\n.endc\n.end\n"
  file delete -force [file join $RD3 hand.raw]
  catch {exec ngspice -b $hand 2>@1}
  set hv [pcall ase::raw_content_verdict [file join $RD3 hand.raw]]
  eqcheck PF220e-the-unguarded-deck-really-does-write-a-constants-raw \
    [list [file exists [file join $RD3 hand.raw]] [dg $hv ok] [dg $hv constants]] {1 0 1}
}


# ===========================================================================
# PF223 — ase::netlist_facts: the tokens netlist_map throws away (issue 1422)
# ===========================================================================
## ⚠ THIS PASS EXISTS BECAUSE netlist_map IS STRUCTURALLY UNABLE TO ANSWER THE
## QUESTION. It drops every token containing an `=` -- on element cards and on
## `.subckt` parameter defaults -- and skips every dot-card but `.subckt`,
## `.ends`, `.global` and the includes. That is right for its own job ("does this
## node exist") and it means the answers a precondition needs -- does this source
## carry an AC magnitude, a `distof1`, a `portnum`, a `trnoise` -- are exactly the
## tokens it discarded.
set FNL {** sch_path: /fixture/facts.sch
x1 TOPNET fmid
V9 TOPNET 0 1
V1 in 0 DC 0 AC 1 SIN(0 1 1k)
I7 a b ac
V2 p n 0 ac 2 distof1 0.5 distof2
V3 q r portnum=1 z0=50
+ ac 1
R1 a b 1k
QZ c d e somepnp
A1 [dig_in] dig_out d_and_inst
.model d_and_inst d_and
.model nch nmos level=54
.subckt fmid A
VSUB A 0 dc 5
.ends
.end
}
set FF [pcall ase::netlist_facts $FNL]

## ⚠ THE ROW THE PASS EXISTS FOR. `portnum=1` and `z0=50` are written as k=v,
## which is precisely the form netlist_map discards -- so this row also asserts
## that netlist_map still does NOT have them, or the two passes would be
## redundant and one of them should be deleted.
eqcheck PF223a-the-k-v-tokens-netlist-map-discards-are-kept \
  [list [dgn $FF sources V3 portnum] [dgn $FF sources V3 z0] \
        [dex [ase::netlist_map $FNL] scopes {} nodes portnum=1]] \
  {1 50 0}

## ⚠ A BARE `ac` WITH NO MAGNITUDE IS STILL `acGiven` TO ngspice, and its
## magnitude is 1. A reader that required a number would report "no AC source"
## for a deck that has one -- a FALSE REFUSAL, which is the failure this whole
## pass is written to avoid. `I7 a b ac` is that card.
eqcheck PF223b-a-bare-ac-keyword-is-an-ac-source-with-magnitude-one \
  [list [dgn $FF sources I7 ac] [dgn $FF sources I7 letter] \
        [dgn $FF sources V2 distof2]] \
  {1 i 1}

## ⚠ THE SAME CONTINUATION FOLD AS netlist_map, AND IT HAS TO BE THE SAME. A
## source's `ac 1` most often lives on a continuation -- xschem's netlister wraps
## long device cards -- so a pass that folded differently would answer
## differently about the same deck than the pass the refusals are aligned with.
## V3's `ac 1` is on its `+` line.
eqcheck PF223c-an-ac-value-on-a-continuation-line-is-found \
  [dgn $FF sources V3 ac] 1

## ⚠ AND A SOURCE CARRIES ITS SCOPE, because "this deck has an AC source" and
## "the subckt three levels down has one" are different answers to the question
## a noise analysis asks.
eqcheck PF223d-a-source-inside-a-subckt-carries-its-scope \
  [list [dgn $FF sources VSUB scope] [dgn $FF sources VSUB dc] \
        [dgn $FF sources V9 scope]] \
  {fmid 5 {}}

## ⚠ A BARE VALUE IN THE THIRD POSITION IS A DC VALUE. `V9 TOPNET 0 1` means
## `dc 1`, and a precondition refusing it for "no DC value" would be wrong about
## the commonest card in every bench in this repository.
eqcheck PF223e-a-bare-third-position-value-is-a-dc-value \
  [list [dgn $FF sources V9 dc] [dgn $FF sources V1 dc] [dgn $FF sources V1 ac]] \
  {1 0 1}

## ⚠ AN UNKNOWN DEVICE LETTER IS RECORDED, NOT DISCARDED, and under its own
## letter. Stage 2's OSDI rule applies here too: a family nothing recognises is a
## CAUTION and never a block -- and a caller cannot caution about a family this
## pass silently dropped. `QZ` is a bjt; there is no `z`-prefixed card here, so
## the unknown arm is exercised by its absence being provable.
eqcheck PF223f-families-come-from-the-device-letter \
  [list [dex $FF families resistor] [dex $FF families vsource] \
        [dex $FF families isource] [dex $FF families bjt] \
        [dex $FF families subckt] [dex $FF families xspice] \
        [dex $FF families diode]] \
  {1 1 1 1 1 1 0}
eqcheck PF223g-an-unrecognised-device-letter-is-recorded-under-its-own-letter \
  [dex [pcall ase::netlist_facts "* t\n§1 a b 1\n.end\n"] families {unknown:§}] 1

## ⚠ `events` HOLDS NODES. An XSPICE event MODEL is a fact about the deck, not
## about a node; putting its name in `events` would make "is this node an event
## node" answer yes for a string that is not a node at all. The model is in
## `models` with its type, which is where a caller asks "does this deck have a
## digital island".
eqcheck PF223h-event-nodes-come-from-a-cards-and-models-stay-in-models \
  [list [dex $FF events dig_out] [dex $FF events d_and_inst] \
        [dgn $FF models d_and_inst type] [dgn $FF models nch level]] \
  {1 0 d_and 54}

## ⚠ AND THE PASS SAYS IT IS STATIC. `exact 0` is part of the answer, not a
## footnote: this pass cannot see inside an `.include`, so "no AC source" from a
## deck that includes a stimulus file is a GUESS. A caller that turns a static
## fact into a refusal refuses decks that work. Static warns; only an exact leg
## blocks -- the same stand-down netlist_map_resolve already makes for includes.
eqcheck PF223i-the-pass-declares-itself-static \
  [list [dgn $FF exact] \
        [dgn [pcall ase::netlist_facts $NLX] exact] \
        [dict size [dgn [pcall ase::netlist_facts $NLX] sources]]] \
  {0 0 0}

## ⚠ AND THE TWO PASSES AGREE ABOUT THE SHAPE OF THE DECK. They are separate
## walks over the same text; if their scope stacks ever diverged, a refusal
## aligned with one would be wrong about the other, and nothing would say so.
eqcheck PF223j-both-passes-see-the-same-scopes \
  [list [lsort [dict keys [dgn $FF nodes]]] \
        [lsort [dict keys [dict get [ase::netlist_map $FNL] scopes]]]] \
  [list {{} fmid} {{} fmid}]


# ===========================================================================
# PF224 — preconditions become filters, not error messages (issue 1423)
# ===========================================================================
## ⚠ THE GOVERNING RULE OF THIS SECTION IS THAT A FALSE REFUSAL IS WORSE THAN A
## MISSED ONE. `ase::netlist_facts` answers `exact 0`: it cannot see inside an
## `.include`, so "this deck has no AC source" from a deck that includes a
## stimulus file is a GUESS. A refusal built on a guess stops work that would
## have succeeded and gives the user no way to tell the tool it is wrong.
set NOAC "* t\nV1 in 0 1\nR1 in out 1k\n.end\n"
set WITHAC "* t\nV1 in 0 dc 1 ac 1\nR1 in out 1k\n.end\n"
set CIDERNL "* t\nV1 in 0 dc 1 ac 1\nD1 in out dmod\n.model dmod numd\n.end\n"
proc pcheck {nl analyses {opts {}}} {
  set st [ase::state_default]
  dict set st analyses $analyses
  dict set st options $opts
  return [ase::analysis_precheck ngspice $st [ase::netlist_facts $nl]]
}
set ACROW {{type ac enabled 1 points 10 start 1 stop 1k}}
set PC1 [pcheck $NOAC $ACROW]

eqcheck PF224a-a-deck-with-no-ac-source-warns-an-enabled-ac-analysis \
  [list [dict exists $PC1 ac] [lindex [lindex [dgn $PC1 ac] 0] 0] \
        [lindex [lindex [dgn $PC1 ac] 0] 3]] \
  {1 ac_source {put `ac 1` on the input source (any magnitude will do)}}

## ⚠ A `blocked` VERDICT ON A STATIC PASS IS DEMOTED TO `caution`, AND THE
## SENTENCE SAYS WHY. The demotion lives in ONE place so that no predicate can
## forget it -- a predicate author writes the honest verdict and the evaluator
## lowers it, rather than thirteen authors each remembering the same caveat.
eqcheck PF224b-a-static-block-is-demoted-to-a-caution-and-says-so \
  [list [lindex [lindex [dgn $PC1 ac] 0] 1] \
        [expr {[string first {cannot see inside an .include} \
                 [lindex [lindex [dgn $PC1 ac] 0] 2]] >= 0}]] \
  {caution 1}

eqcheck PF224c-a-deck-that-has-what-the-analysis-needs-says-nothing \
  [list [dict size [pcheck $WITHAC $ACROW]] \
        [dict size [pcheck $WITHAC {{type dc enabled 1 source V1 start 0 stop 1 step 0.1}}]]] \
  {0 0}

## ⚠ ENABLED ONLY, exactly as the Arguments column decided in issue 1420. A
## switched-off analysis makes no claim about a run, and a bench opening with
## three disabled rows must not open wearing three warnings about a circuit
## nobody has asked it to simulate.
eqcheck PF224d-a-switched-off-analysis-is-not-prechecked \
  [dict size [pcheck $NOAC {{type ac enabled 0 points 10 start 1 stop 1k}}]] 0

## ⚠ `temp` IS A LEGAL SWEEP TARGET AND NAMES NO INSTANCE. A predicate that
## required the target to be in the deck would refuse `dc v1 0 1 0.5 temp -40 60
## 50`, which is the cheapest genuine ADE-beater in this whole design.
set PCD [pcheck $WITHAC {{type dc enabled 1 source Vnope start 0 stop 1 step 0.1}}]
eqcheck PF224e-the-sweep-target-must-be-in-the-deck-unless-it-is-temp \
  [list [lindex [lindex [dgn $PCD dc] 0] 0] \
        [expr {[string first {'Vnope'} [lindex [lindex [dgn $PCD dc] 0] 2]] >= 0}] \
        [dict size [pcheck $WITHAC {{type dc enabled 1 source temp start 0 stop 1 step 0.1}}]]] \
  {sweep_target 1 0}

## ⚠ THE CIDER/KLU PAIR NEEDS **BOTH** HALVES OR IT IS A FALSE REFUSAL. A CIDER
## device is perfectly fine under the default solver, and CIDER decks are the
## only reason anyone builds ngspice with it -- a predicate firing on the device
## alone would refuse every deck the feature exists for.
eqcheck PF224f-a-cider-device-alone-is-not-a-problem \
  [dict size [pcheck $CIDERNL $ACROW]] 0

## ⚠ AND THE PAIR IS `fatal`, NOT `blocked`, SO IT IS **NOT** DEMOTED BY THE
## STATIC RULE. ngspice `exit(1)`s on it -- not an error return, an EXIT -- so
## the rest of `.control` never runs and nothing after this analysis happens
## either. A caution would let the user start a run that cannot produce anything
## and cannot say why.
set PCK [pcheck $CIDERNL $ACROW {{name klu value 1}}]
eqcheck PF224g-cider-under-klu-is-fatal-and-survives-the-static-demotion \
  [list [lindex [lindex [dgn $PCK ac] 0] 1] \
        [expr {[string first {cannot see inside} \
                 [lindex [lindex [dgn $PCK ac] 0] 2]] >= 0}] \
        [lindex [lindex [dgn $PCK ac] 0] 3]] \
  {fatal 0 {select the `sparse` solver for this run}}

## ⚠ AN UNIMPLEMENTED PRECONDITION ID IS **SATISFIED**, AND THAT IS THE SAFE
## DIRECTION. A registry naming a precondition nobody has written yet must not
## block a run; an unimplemented id is a fact about the registry, reported when
## somebody asks about the registry, not at the moment a user presses Run.
eqcheck PF224h-an-unimplemented-precondition-id-does-not-block-a-run \
  [pcall ase::needs_eval ngspice ac zz_no_such_precondition {} \
    {sources {} families {} events {} models {} nodes {} exact 0} {}] {}

## ⚠ ONE ORDERING, IN ONE PLACE. The grid cell and the gate both need "how bad is
## the worst of these" and neither may re-derive it, or they will disagree about
## a bench in front of the user.
##
## ⚠ AND THE FIXTURE HAS TO CONTAIN A CONFLICT, WHICH THE FIRST DRAFT DID NOT.
## Every precheck above yields findings of exactly ONE severity, so a sabotage
## that swapped `fatal` and `blocked` in the ordering PASSED this row: with a
## lone fatal, any ordering returns fatal. An ordering row whose fixtures never
## disagree is a row that cannot fail. This one forces `exact 1` -- so the AC
## finding stays `blocked` instead of being demoted -- on a CIDER deck under KLU,
## which is `fatal`, and the two arrive in that order.
set NOACCIDER "* t\nV1 in 0 1\nD1 in out dmod\n.model dmod numd\n.end\n"
set PCX [ase::analysis_precheck ngspice \
  [dict replace [dict replace [ase::state_default] analyses $ACROW] \
     options {{name klu value 1}}] \
  [dict replace [ase::netlist_facts $NOACCIDER] exact 1]]
eqcheck PF224i-the-worst-verdict-is-ordered-once-and-the-fixture-disagrees \
  [list [llength [dgn $PCX ac]] \
        [lindex [lindex [dgn $PCX ac] 0] 1] \
        [lindex [lindex [dgn $PCX ac] 1] 1] \
        [ase::precheck_worst $PCX] \
        [ase::precheck_worst $PC1] \
        [ase::precheck_worst [pcheck $WITHAC $ACROW]]] \
  {2 blocked fatal fatal caution {}}


# ===========================================================================
# PF225 — a precondition that DESTROYS the run is a refusal (issue 1424)
# ===========================================================================
## ⚠ `fatal` IS NOT "this run will be less useful". It is "ngspice will not
## reach the end of `.control`". The measured case: a CIDER numerical device
## under the KLU solver makes ngspice call `exit(1)` -- not an error return, an
## EXIT -- so every analysis after it in the deck silently does not happen, and
## the run directory is left holding a partial raw file that reads back as a
## perfectly valid result.
set KNL "* t\nV1 in 0 dc 1 ac 1\nR1 in out 1k\nD1 out 0 dmod\n.model dmod numd\n.end\n"
proc kstate {opts} {
  set st [mkstate $::RD kcell {}]
  dict set st analyses {{type op enabled 1} \
                        {type ac enabled 1 points 10 start 1 stop 1k}}
  dict set st options $opts
  return $st
}
set KBAD  [kstate {{name klu value 1}}]
set KGOOD [kstate {}]

said_clear
set KR [pcall ase::preflight_gate $KBAD $KNL]
eqcheck PF225a-a-fatal-precondition-is-refused-at-the-gate \
  [list [string range $KR 0 3] \
        [expr {[said_count {*CIDER*}] >= 1}] \
        [expr {[said_count {*sparse*}] >= 1}] \
        [expr {[said_count {*exit part-way*}] >= 1}]] \
  {ERR: 1 1 1}

## ⚠ AND IT IS NOT DEFEASIBLE. `set ase_preflight 0` exists so a user can run a
## deck whose save list this tree cannot resolve -- a judgement call about a
## warning. It may not be a way past a simulator that will not reach the end of
## its own control block: that would be letting the user past a SILENT WRONG
## ANSWER, not past an inconvenience. The block sits above the escape, exactly as
## issues 1401 and 1415 do.
set ::ase_preflight 0
said_clear
set KR0 [pcall ase::preflight_gate $KBAD $KNL]
set ::ase_preflight 1
eqcheck PF225b-the-preflight-escape-does-not-defeat-a-fatal-precondition \
  [list [string range $KR0 0 3] [expr {[said_count {*CIDER*}] >= 1}]] {ERR: 1}

## ⚠ THE THIRD TIER: render_deck RE-CHECKS. A `.state` can be hand-edited and a
## netlist can change under a saved analysis, so the dialog having been happy
## once is not evidence about THIS deck -- and a caller reaching render_deck
## directly passes through no other tier at all.
eqcheck PF225c-render-deck-refuses-the-same-deck-and-renders-nothing \
  [string range [pcall ase::backend::ngspice::render_deck $KBAD $KNL] 0 3] {ERR:}

## ⚠ AND THE SAME DECK WITHOUT THE SOLVER OPTION RENDERS NORMALLY. Without this
## row, "refuses correctly" and "refuses everything" look identical -- and a
## CIDER device is perfectly fine under the default solver, which is the only
## reason anyone builds ngspice with CIDER at all.
set KOK [pcall ase::backend::ngspice::render_deck $KGOOD $KNL]
set KNOAC "* t\nV1 in 0 1\nR1 in out 1k\n.end\n"
## ⚠ AND A `caution` MUST STILL RENDER. The first draft of this row used a deck
## with NO finding at all, so a sabotage making render_deck refuse on ANY verdict
## passed it -- the fixture could not tell "refuses fatal" from "refuses
## anything". `$KNOAC` has no AC source, which is a real `ac_source` caution, and
## a deck carrying one has to reach the file: a warning the user can act on is
## not a reason to refuse to write their deck.
set KOKC [pcall ase::backend::ngspice::render_deck [kstate {}] $KNOAC]
eqcheck PF225d-the-same-deck-without-klu-renders-and-so-does-one-with-a-caution \
  [list [expr {[string range $KOK 0 3] ne {ERR:}}] \
        [expr {[string first {ac dec 10 1 1k} $KOK] >= 0}] \
        [string range [pcall ase::preflight_gate $KGOOD $KNL] 0 3] \
        [expr {[string range $KOKC 0 3] ne {ERR:}}] \
        [expr {[string first {ac dec 10 1 1k} $KOKC] >= 0}]] \
  {1 1 {} 1 1}

## ⚠ THE GATE MAY ONLY SLAM FOR `fatal`. A `caution` or a `blocked` belongs in
## the window, next to the control that causes it, where the user can see it and
## decide -- that is the four-state grid's job. This deck has no AC source, which
## is an `ac_source` finding, and the gate must let it through.
said_clear
eqcheck PF225e-a-caution-does-not-slam-the-gate \
  [list [pcall ase::preflight_gate [kstate {}] $KNOAC] \
        [lindex [lindex [dgn [ase::analysis_precheck ngspice [kstate {}] \
                   [ase::netlist_facts $KNOAC]] ac] 0] 1]] \
  {{} caution}


# ===========================================================================
# PF226 — the precondition is said BEFORE the run, with its remedy (issue 1425)
# ===========================================================================
## ⚠ THIS IS THE WHOLE POINT OF STAGE 4, IN FOUR LINES OF OUTPUT. ngspice's own
## answer to a noise analysis with no AC input source is `E_NOACINPUT`, AFTER the
## run, in a log the user has to go and read. The same fact is knowable from the
## netlist text before anything starts -- and it comes with the remedy attached.
said_clear
set KADV [pcall ase::preflight_gate [kstate {}] $KNOAC]
eqcheck PF226a-a-caution-is-said-before-the-run-with-its-fix \
  [list $KADV \
        [expr {[said_count {*has no AC source*}] >= 1}] \
        [expr {[said_count {*Fix: put `ac 1`*}] >= 1}] \
        [expr {[said_count {*the ac analysis*}] >= 1}]] \
  {{} 1 1 1}

## ⚠ ADVICE, NOT A REFUSAL. Nothing here stops the run -- the gate returned {}
## above. A `caution` is the user's call by definition: they may know something
## the netlist text cannot show, which is exactly why a static pass demotes
## `blocked` to `caution` in the first place.
said_clear
eqcheck PF226b-a-deck-with-nothing-to-say-says-nothing \
  [list [pcall ase::preflight_gate [kstate {}] $WITHAC] \
        [said_count {*has no AC source*}]] \
  {{} 0}

## ⚠ AND IT SITS ABOVE THE ESCAPE. `set ase_preflight 0` turns off a REFUSAL; it
## is not a request to be told less about a circuit. A user who has switched off
## the save-list check has said "let me run this anyway", not "stop telling me
## things I can act on".
set ::ase_preflight 0
said_clear
set KADV0 [pcall ase::preflight_gate [kstate {}] $KNOAC]
set ::ase_preflight 1
eqcheck PF226c-the-escape-turns-off-a-refusal-not-the-advice \
  [list $KADV0 [expr {[said_count {*has no AC source*}] >= 1}]] {{} 1}


# ===========================================================================
# PF227 — the transfer function's two preconditions (Stage 5, issue 1426)
# ===========================================================================
## ⚠ ngspice CHECKS THE INPUT AND DOES NOT CHECK THE OUTPUT, AND THE TWO
## PREDICATES EXIST BECAUSE OF THAT ASYMMETRY. MEASURED 2026-09-12 on the fork
## (`build-ver_50`) and on apt 45.2 alike, one `-b` deck per line:
##
##   tf v(mid) Rnope     -> rc 1, `Warning: Transfer function source rnope not
##                                 in circuit`
##   tf v(mid) R1        -> rc 1, `Warning: Transfer function source r1 not of
##                                 proper type`
##   tf v(nosuchnode) V1 -> rc 0, Transfer_function = 0.000000e+00
##   tf v(in,nosuch)  V1 -> rc 0, Transfer_function = 1.000000e+00
##   tf i(R1)         V1 -> rc 0, r1#Output_impedance = 1.000000e+20
##   tf i(nosuchsrc)  V1 -> rc 0, nosuchsrc#Output_impedance = 1.000000e+20
##   tf x(mid)        V1 -> rc 1, `Error: Syntax error: voltage or current
##                                 expected.`
##
## Four of those seven are a run that SUCCEEDED, with a vector named after the
## thing that does not exist and three plausible numbers in it. Nothing on
## either stream. `tfanal.c:112-157` solves against the already-factored
## Jacobian with a unit excitation, so an unmatched name excites nothing and the
## 1e20 is the `|rhs| < 1e-20` clamp.
set TFNL "* t\nV1 in 0 dc 1 ac 1\nVsense mid out 0\nR1 in mid 1k\nR2 out 0 2k\n.end\n"
proc tfrow {args} { return [list [concat {type tf enabled 1} $args]] }
proc tfn {pc n} { return [lindex [lindex [dgn $pc tf] $n] 0] }
proc tfv {pc n} { return [lindex [lindex [dgn $pc tf] $n] 1] }
proc tfs {pc n} { return [lindex [lindex [dgn $pc tf] $n] 2] }
proc tff {pc n} { return [lindex [lindex [dgn $pc tf] $n] 3] }

eqcheck PF227a-a-tf-row-this-circuit-can-run-says-nothing \
  [list [dict size [pcheck $TFNL [tfrow out {v(mid)} insrc V1]]] \
        [dict size [pcheck $TFNL [tfrow out {v(mid,out)} insrc V1]]] \
        [dict size [pcheck $TFNL [tfrow out {i(Vsense)} insrc V1]]]] \
  {0 0 0}

## ⚠ THE SHARPER OF THE TWO. ngspice reports three numbers for an output node
## that is not there, so ASE-L is the only place this can be said at all.
set TFPB [pcheck $TFNL [tfrow out {v(nosuchnode)} insrc V1]]
eqcheck PF227b-an-output-node-that-is-not-in-the-circuit-is-reported \
  [list [tfn $TFPB 0] [tfv $TFPB 0] \
        [expr {[string first {'nosuchnode'} [tfs $TFPB 0]] >= 0}] \
        [expr {[string first {three numbers} [tfs $TFPB 0]] >= 0}] \
        [tff $TFPB 0]] \
  {tf_out caution 1 1 {name a node that is in the circuit}}

## ⚠ AND IT IS DEMOTED TO `caution` WITH THE `.include` CAVEAT, because an
## included file really could define that node. This half is the one the static
## rule is right about.
eqcheck PF227c-the-missing-node-carries-the-static-caveat \
  [expr {[string first {cannot see inside an .include} [tfs $TFPB 0]] >= 0}] 1

## ⚠ THE SYNTAX ERROR IS `fatal`, AND THAT IS WHAT KEEPS THE CAVEAT OFF IT. No
## `.include` can make `v mid` a legal output -- the finding does not rest on the
## netlist at all -- so a sentence saying the pass "cannot see inside an
## .include" would be a lie about why ASE-L is unsure. `fatal` is exempt from
## the demotion and is also the honest severity. MEASURED 2026-09-12 with this
## tree's own `sim_status` guard wrapped around the analysis:
##
##   tf x(mid) V1        -> rc 1, `RUN-FAILED`, the guard's `quit 1` fires and
##                                NOTHING after it in `.control` runs
##   tf v(nosuchnode) V1 -> rc 0, `REACHED-THE-END`
set TFPM [pcheck $TFNL [tfrow out {v mid} insrc V1]]
eqcheck PF227d-an-output-this-simulator-cannot-read-is-fatal-and-carries-no-include-caveat \
  [list [tfn $TFPM 0] [tfv $TFPM 0] \
        [string first {cannot see inside} [tfs $TFPM 0]] \
        [expr {[string first {parentheses are not optional} [tff $TFPM 0]] >= 0}]] \
  {tf_out fatal -1 1}

## ⚠ NON-VACUITY FOR PF227d, AND IT IS THE ROW THE MEASUREMENT DEMANDS. The
## missing parenthesis is the mistake a user actually makes, and ngspice blames
## it on the SOURCE: `tf v mid V1` fails with `Warning: Transfer function source
## not in circuit` -- the EMPTY name -- because the `v` branch with no `(`
## consumes nothing and the insrc slot is never filled. A user reading that goes
## and looks at their source. So the gate has to refuse it, and refuse it saying
## something about the OUTPUT.
said_clear
set TFG [pcall ase::preflight_gate \
  [dict replace [mkstate $RD c $TFNL] analyses [tfrow out {v mid} insrc V1]] $TFNL]
eqcheck PF227e-the-gate-refuses-the-malformed-output-and-names-the-output \
  [list [string range $TFG 0 3] \
        [expr {[said_count {*v mid*}] >= 1}] \
        [expr {[said_count {*parentheses*}] >= 1}]] \
  {ERR: 1 1}

## ⚠ AND A DECK THE ANALYSIS CAN RUN STILL PASSES THE GATE, so PF227e is
## measuring the malformed output and not something else about this state.
eqcheck PF227f-a-runnable-tf-row-passes-the-same-gate \
  [pcall ase::preflight_gate \
    [dict replace [mkstate $RD c $TFNL] analyses [tfrow out {v(mid)} insrc V1]] $TFNL] \
  {}

## ⚠ `i(...)` IS A VOLTAGE SOURCE AND ONLY A VOLTAGE SOURCE, AND THAT WAS
## MEASURED ACROSS FOUR DEVICE CLASSES RATHER THAN REASONED. `i(L1)` IS a real
## branch current elsewhere in ngspice -- `op` then `print i(L1)` answers
## `5.000000e-04` while `print i(R1)` answers `Error: no such function as i, or
## i(r1) is not available.` -- so "an inductor has no branch current" would have
## been a FALSE REFUSAL had anyone stopped at the argument. It is not the
## reason. MEASURED 2026-09-12, `tf i(X) V1` on a divider, reading
## `Transfer_function`:
##
##   i(Vsense)  3.333333e-04   <- correct; 1/3k A/V
##   i(L1)      0.000000e+00   <- WRONG, and rc 0
##   i(I1)      0.000000e+00   <- WRONG, and rc 0
##   i(R1)      0.000000e+00   <- WRONG, and rc 0
##
## `tf`'s own `i()` form resolves to a VSOURCE branch equation and nothing else.
## ⚠ AND THE CURRENT SOURCE IS THE ROW THAT MATTERS: `I1` IS in `facts sources`,
## so a predicate that asked "is this an independent source" instead of "is this
## a voltage source" would pass it, silently, at rc 0.
set TFNLI "* t\nV1 in 0 dc 1 ac 1\nVsense mid out 0\nI1 mid 0 dc 0\nR1 in mid 1k\nR2 out 0 2k\n.end\n"
set TFPI [pcheck $TFNL [tfrow out {i(R1)} insrc V1]]
set TFPI2 [pcheck $TFNLI [tfrow out {i(I1)} insrc V1]]
eqcheck PF227g-a-current-output-that-names-no-voltage-source-is-reported \
  [list [tfn $TFPI 0] [tfv $TFPI 0] \
        [expr {[string first {'i(R1)'} [tfs $TFPI 0]] >= 0}] \
        [tfn $TFPI2 0] \
        [expr {[string first {'i(I1)'} [tfs $TFPI2 0]] >= 0}] \
        [dict size [pcheck $TFNL [tfrow out {i(Vsense)} insrc V1]]] \
        [dict size [pcheck $TFNLI [tfrow out {i(Vsense)} insrc V1]]]] \
  {tf_out caution 1 tf_out 1 0 0}

## ⚠ TWO SENTENCES, NOT ONE, FOR THE INPUT SOURCE. ngspice has two errors here
## and they send a user to two different places: "you named something that is
## not there" and "you named the wrong kind of thing". A predicate answering one
## sentence for both would make the second look like a typo.
set TFPN [pcheck $TFNL [tfrow out {v(mid)} insrc Vnope]]
set TFPT [pcheck $TFNL [tfrow out {v(mid)} insrc R1]]
## ⚠ AND THE TWO SENTENCES ARE COMPARED CLAUSE BY CLAUSE, NOT JUST FOR BEING
## DIFFERENT STRINGS. Both carry the name the user typed, so a predicate
## answering ONE sentence for both conditions still produces two different
## strings -- and a row asserting only `$a ne $b` passes it. Each clause is
## asserted present in its own sentence and ABSENT from the other.
eqcheck PF227h-the-input-source-must-exist-and-must-be-an-independent-source \
  [list [tfn $TFPN 0] [expr {[string first {'Vnope'} [tfs $TFPN 0]] >= 0}] \
        [tfn $TFPT 0] [expr {[string first {'R1'} [tfs $TFPT 0]] >= 0}] \
        [expr {[string first {not an independent source} [tfs $TFPT 0]] >= 0}] \
        [expr {[string first {not an independent source} [tfs $TFPN 0]] >= 0}] \
        [expr {[string first {this circuit has no} [tfs $TFPN 0]] >= 0}] \
        [expr {[string first {this circuit has no} [tfs $TFPT 0]] >= 0}]] \
  {tf_insrc 1 tf_insrc 1 1 0 1 0}

## ⚠ BOTH INPUT-SOURCE FINDINGS STAY `caution`, AND THAT IS THE ASYMMETRY WITH
## PF227d STATED AS A ROW. An `.include`d stimulus file really can supply `V1`,
## so a refusal here would be the false refusal the whole pass is written to
## avoid -- even though ngspice's own answer to both is a hard rc 1 abort. The
## severity tracks WHAT THE STATIC PASS CAN KNOW, never how loudly the simulator
## complains.
eqcheck PF227i-a-missing-input-source-is-a-caution-however-hard-ngspice-fails \
  [list [tfv $TFPN 0] [tfv $TFPT 0] \
        [expr {[string first {cannot see inside an .include} [tfs $TFPN 0]] >= 0}] \
        [pcall ase::preflight_gate \
          [dict replace [mkstate $RD c $TFNL] analyses [tfrow out {v(mid)} insrc Vnope]] \
          $TFNL]] \
  {caution caution 1 {}}

## ⚠ EACH NODE OF A TWO-NODE OUTPUT IS CHECKED, AND ONLY THE MISSING ONE IS
## NAMED. `tf v(in,nosuch) V1` is rc 0 with `Transfer_function = 1.0`; a
## predicate that stopped at the first node would pass it.
set TFP2 [pcheck $TFNL [tfrow out {v(mid,nosuch)} insrc V1]]
eqcheck PF227j-the-reference-node-of-a-two-node-output-is-checked-too \
  [list [tfn $TFP2 0] \
        [expr {[string first {'nosuch'} [tfs $TFP2 0]] >= 0}] \
        [expr {[string first {'mid'} [tfs $TFP2 0]] >= 0}]] \
  {tf_out 1 0}

## ⚠ A SWITCHED-OFF tf ROW MAKES NO CLAIM ABOUT A RUN, and a bench that opens
## carrying a disabled transfer function must not open wearing a warning about a
## circuit nobody has asked it to simulate.
eqcheck PF227k-a-disabled-tf-row-is-not-prechecked \
  [dict size [pcheck $TFNL {{type tf enabled 0 out {v mid} insrc Rnope}}]] 0

## ⚠ AND A ROW WITH NOTHING FILLED IN IS THE COMMIT DOOR'S BUSINESS, NOT THIS
## PASS'S. `ase::analysis_emit_check` already refuses an empty required field by
## name; reporting it here as well would show the user two sentences about one
## mistake, and reporting an ABSENT `out` as BAD SYNTAX would be the wrong one
## of the two. That is why `out_decompose` answers `malformed` and the predicate
## returns early on an empty field rather than folding the two into one answer.
eqcheck PF227l-an-empty-tf-row-is-left-to-the-commit-door \
  [list [dict size [pcheck $TFNL {{type tf enabled 1}}]] \
        [lindex [lindex [ase::analysis_emit_check ngspice {type tf enabled 1}] 0] 0]] \
  {0 missing}

# ===========================================================================
# PF228 — the pole-zero analysis's four preconditions (Stage 5, issue 1427)
# ===========================================================================
## ⚠ FOUR PREDICATES, AND THEY SPLIT ON **WHAT THE STATIC PASS CAN KNOW** RATHER
## THAN ON HOW LOUDLY ngspice COMPLAINS. Every one of the failures below is a
## hard rc 1 abort; only three of the four are `fatal`. MEASURED 2026-09-12 on
## the fork (`build-ver_50`) and on apt 45.2 alike, one `-b` deck per line, each
## wrapped in this tree's own `sim_status` guard:
##
##   pz in 0     out 0   vol pz  -> rc 0, REACHED-THE-END
##   pz nosuch 0 out 0   vol pz  -> rc 1, `doAnalyses: The input signal is
##                                        shorted on the way to the output`
##   pz in 0     nosuch 0 vol pz -> rc 1, the SAME sentence
##   pz in in    out 0   vol pz  -> rc 1, `doAnalyses: Input is shorted`
##   pz 0  0     out 0   vol pz  -> rc 1, `doAnalyses: Input is shorted`
##   pz in 0     out out vol pz  -> rc 1, `doAnalyses: Output is shorted`
##   pz in 0     in  0   vol pz  -> rc 1, `doAnalyses: Transfer function is unity`
##   pz 0  in    in  0   vol pz  -> rc 1, `doAnalyses: Transfer function is -1`
##   pz in 0     in  0   cur pz  -> rc 0, REACHED-THE-END, four roots
##
## ⚠ THE MISSING-NODE MESSAGE IS `cktpzstr.c:213` -- the root finder reporting
## that the transfer function came out identically zero -- and it names neither
## the node nor the fact that one was invented. ⚠ AND THE LAST LINE IS WHY THE
## in==out ARM IS `vol`-ONLY: `pzan.c:117-125` guards both unity arms with
## `PZinput_type == PZ_IN_VOL`, and refusing the current-input case would refuse
## a real analysis.
set PZNL "* t\nV1 in 0 dc 1 ac 1\nR1 in mid 1k\nC1 mid 0 1n\nR2 mid out 1k\nC2 out 0 1n\n.end\n"
proc pzrow {args} { return [list [concat {type pz enabled 1} $args]] }
proc pzn {pc n} { return [lindex [lindex [dgn $pc pz] $n] 0] }
proc pzv {pc n} { return [lindex [lindex [dgn $pc pz] $n] 1] }
proc pzs {pc n} { return [lindex [lindex [dgn $pc pz] $n] 2] }
proc pzf {pc n} { return [lindex [lindex [dgn $pc pz] $n] 3] }

## ⚠ THE DISCRIMINATOR FOR EVERY ROW BELOW. Without a row asserting that a
## runnable pz row says NOTHING, every one of them is satisfied by a predicate
## that reports on every deck -- the lesson section PF227 paid for as sabotage
## S19 and Stage 3 paid for before that.
eqcheck PF228a-a-pz-row-this-circuit-can-run-says-nothing \
  [list [dict size [pcheck $PZNL [pzrow inp in outp out]]] \
        [dict size [pcheck $PZNL [pzrow inp in inn 0 outp out outn 0 transfer vol mode pz]]] \
        [dict size [pcheck $PZNL [pzrow inp mid outp out transfer cur mode zer]]]] \
  {0 0 0}

## ⚠ ALL FOUR NODE SLOTS ARE CHECKED, AND GROUND IS NEVER ONE OF THEM. `0` is
## the reference every deck has and no deck writes a card for -- AND it is the
## declared default of both reference fields -- so a predicate that looked it up
## would report "this circuit has no node '0'" for the commonest row there is.
set PZB1 [pcheck $PZNL [pzrow inp nosuch outp out]]
set PZB3 [pcheck $PZNL [pzrow inp in outp nosuch]]
set PZB2 [pcheck $PZNL [pzrow inp in inn nosuchref outp out]]
set PZB4 [pcheck $PZNL [pzrow inp in outp out outn nosuchref]]
eqcheck PF228b-a-node-that-is-not-in-the-circuit-is-reported-whichever-of-the-four-it-is \
  [list [pzn $PZB1 0] [pzn $PZB2 0] [pzn $PZB3 0] [pzn $PZB4 0] \
        [expr {[string first {'nosuch'} [pzs $PZB1 0]] >= 0}] \
        [expr {[string first {'nosuchref'} [pzs $PZB2 0]] >= 0}] \
        [expr {[string first {'nosuch'} [pzs $PZB3 0]] >= 0}] \
        [expr {[string first {'nosuchref'} [pzs $PZB4 0]] >= 0}] \
        [pzf $PZB1 0]] \
  {pz_nodes pz_nodes pz_nodes pz_nodes 1 1 1 1 {name a node that is in the circuit}}

## ⚠ AND IT IS DEMOTED TO `caution` WITH THE `.include` CAVEAT, because an
## included stimulus or PDK file really could define that node. This is the half
## the static rule is RIGHT about, and PF228e is the half it is wrong about.
eqcheck PF228c-the-missing-node-is-a-caution-and-carries-the-static-caveat \
  [list [pzv $PZB1 0] \
        [expr {[string first {cannot see inside an .include} [pzs $PZB1 0]] >= 0}] \
        [expr {[string first {shorted} [pzs $PZB1 0]] >= 0}]] \
  {caution 1 1}

## ⚠ THE REFERENCE NODES ARE READ THROUGH THEIR DECLARED DEFAULT, NOT OFF THE
## ROW, and this row is the only thing in the tree that would notice if they
## stopped being. A bench that stores neither reference emits `pz in 0 out 0 vol
## pz`; `ase::state_get $row inn` answers the EMPTY STRING for exactly that
## bench. A predicate reading the row directly would compare `in` against `{}`,
## never fire, and let ngspice answer `doAnalyses: Input is shorted` -- which
## names no field at all. ⚠ THE SECOND HALF IS THE NON-VACUITY: with the default
## resolved, an INPUT of `0` IS shorted, and ngspice agrees (measured above).
eqcheck PF228d-the-unstored-reference-nodes-are-the-declared-default \
  [list [dict size [pcheck $PZNL [pzrow inp in outp out]]] \
        [pzn [pcheck $PZNL [pzrow inp 0 outp out]] 0] \
        [pzv [pcheck $PZNL [pzrow inp 0 outp out]] 0] \
        [expr {[string first {'0'} [pzs [pcheck $PZNL [pzrow inp 0 outp out]] 0]] >= 0}]] \
  {0 pz_shorted fatal 1}

## ⚠ A SHORTED INPUT OR OUTPUT IS `fatal` AND CARRIES NO CAVEAT, AND THAT IS THE
## ASYMMETRY WITH PF228c STATED AS A ROW. The finding rests on NOTHING BUT THE
## ROW -- no included file can make the user's own two node boxes stop holding
## the same word -- so a sentence saying the pass "cannot see inside an .include"
## would be a lie about why ASE-L is unsure. `fatal` is exempt from the demotion
## and is independently the honest severity: the guard's `quit 1` fires and
## nothing after it in `.control` runs.
## ⚠ AND THE COMPARISON FOLDS CASE, WHICH IS MEASURED RATHER THAN ASSUMED.
## `pz IN 0 in 0 vol pz` -> rc 1, `doAnalyses: Transfer function is unity`, on
## the fork AND on apt 45.2: ngspice reads a pz node name folded, so `IN` and
## `in` ARE the same node. A case-sensitive predicate would let that row through
## to an abort that names no field.
set PZSI [pcheck $PZNL [pzrow inp in inn in outp out]]
set PZSO [pcheck $PZNL [pzrow inp in outp out outn out]]
set PZSC [pcheck $PZNL [pzrow inp IN inn in outp out]]
set PZSU [pcheck $PZNL [pzrow inp IN outp in]]
eqcheck PF228e-a-shorted-input-or-output-is-fatal-and-carries-no-include-caveat \
  [list [pzn $PZSI 0] [pzv $PZSI 0] \
        [string first {cannot see inside} [pzs $PZSI 0]] \
        [expr {[string first {the input} [pzs $PZSI 0]] >= 0}] \
        [pzn $PZSO 0] [pzv $PZSO 0] \
        [expr {[string first {the output} [pzs $PZSO 0]] >= 0}] \
        [expr {[string first {the input} [pzs $PZSO 0]] >= 0}] \
        [pzn $PZSC 0] [pzn $PZSU 0]] \
  {pz_shorted fatal -1 1 pz_shorted fatal 1 0 pz_shorted pz_shorted}

## ⚠ INPUT-IS-OUTPUT IS TWO SENTENCES AND IS `vol`-ONLY, AND BOTH HALVES ARE
## MEASURED. ngspice says `Transfer function is unity` for the same pair and
## `Transfer function is -1` for the swapped pair -- and RUNS the same row under
## `cur`, because `pzan.c:117-125` guards both with `PZinput_type == PZ_IN_VOL`.
## A predicate that refused the current-input case would refuse the input
## admittance of a node, which is the reason `cur` exists.
set PZU1 [pcheck $PZNL [pzrow inp in outp in]]
set PZU2 [pcheck $PZNL [pzrow inp in inn 0 outp 0 outn in]]
eqcheck PF228f-input-is-output-is-refused-for-a-voltage-input-and-allowed-for-a-current-one \
  [list [pzn $PZU1 0] [pzv $PZU1 0] \
        [expr {[string first {transfer function is 1} [pzs $PZU1 0]] >= 0}] \
        [expr {[string first {transfer function is -1} [pzs $PZU2 0]] >= 0}] \
        [expr {[string first {transfer function is 1} [pzs $PZU2 0]] >= 0}] \
        [dict size [pcheck $PZNL [pzrow inp in outp in transfer cur]]] \
        [dict size [pcheck $PZNL [pzrow inp in inn 0 outp 0 outn in transfer cur]]]] \
  {pz_shorted fatal 1 1 0 0 0}

## ⚠ THE DEVICE RULE HAS TWO CLASSES AND THE SECOND IS THE ONE NOBODY WOULD
## GUESS. A device whose model has no `DEVpzLoad` is SKIPPED by `cktpzld.c:29` --
## it contributes nothing and nothing at all is said. MEASURED 2026-09-12 on both
## binaries, the same two-pole RC with a line hung off a node, against the same
## deck with the line deleted:
##
##   no line at all   -> pole(1) -2.61803e+06  pole(2) -3.81966e+05
##   + Y1 (TransLine) -> pole(1) -2.61803e+06  pole(2) -3.81966e+05   rc 0
##   + P1 (CplLines)  -> pole(1) -2.61803e+06  pole(2) -3.81966e+05   rc 0
##   + T1 (Tranline)  -> rc 1 `doAnalyses: Transmission lines not supported`
##   + O1 (LTRA)      -> rc 1 `doAnalyses: The input signal is shorted on the
##                             way to the output`
##   + U1 (URC)       -> rc 1 `doAnalyses: device already exists, existing one
##                             being used`
##
## ⚠ AND PLAN.md's `pzan.c:92-128` CITATION IS WHERE THE REFUTATION LIVES.
## `PZinit` looks up `"transmission line"`, then `"Tranline"`, then `"LTRA"`, and
## STOPS AT THE FIRST NAME THAT IS A COMPILED-IN DEVICE TYPE rather than the
## first with instances -- so on any build with `tra` compiled in, the LTRA arm
## is never reached. MEASURED: an O-card deck does NOT print "Transmission lines
## not supported"; a deck with a T card AND an O card does.
set PZNLT "* t\nV1 in 0 dc 1 ac 1\nR1 in mid 1k\nR3 out 0 1k\nT1 mid 0 out 0 Z0=50 TD=1n\n.end\n"
set PZNLO "* t\nV1 in 0 dc 1 ac 1\nR1 in mid 1k\nR3 out 0 1k\nO1 mid 0 out 0 om\n.model om ltra rel=1 r=1 l=1u g=0 c=1p len=1\n.end\n"
set PZNLY "* t\nV1 in 0 dc 1 ac 1\nR1 in mid 1k\nR3 out 0 1k\nY1 mid 0 out 0 ym len=1\n.model ym txl R=1 L=1u G=0 C=1p length=1\n.end\n"
set PZDT [pcheck $PZNLT [pzrow inp in outp out]]
set PZDO [pcheck $PZNLO [pzrow inp in outp out]]
set PZDY [pcheck $PZNLY [pzrow inp in outp out]]
eqcheck PF228g-a-line-that-stops-the-run-is-fatal-and-one-that-is-silently-dropped-is-a-caution \
  [list [pzn $PZDT 0] [pzv $PZDT 0] \
        [expr {[string first {`T` card} [pzs $PZDT 0]] >= 0}] \
        [pzv $PZDO 0] \
        [expr {[string first {`O` card} [pzs $PZDO 0]] >= 0}] \
        [pzn $PZDY 0] [pzv $PZDY 0] \
        [expr {[string first {`Y` card} [pzs $PZDY 0]] >= 0}] \
        [expr {[string first {without saying so} [pzs $PZDY 0]] >= 0}] \
        [dict size [pcheck $PZNL [pzrow inp in outp out]]]] \
  {pz_devices fatal 1 fatal 1 pz_devices caution 1 1 0}

## ⚠ THE SILENT CLASS IS A `caution` AND THE STATIC DEMOTION NEVER TOUCHES IT,
## WHICH IS NOT AN ACCIDENT OF THE ORDERING. A finding of the form "this deck
## CONTAINS X" is PROVED by the static pass -- an `.include` can only add more
## devices, never remove the card we just read -- so the caveat the demotion
## appends would be wrong about it in the opposite direction from PF228e. The
## demotion only reaches `blocked`, and neither class is `blocked`.
eqcheck PF228h-a-positive-device-finding-carries-no-include-caveat-either \
  [list [string first {cannot see inside} [pzs $PZDY 0]] \
        [string first {cannot see inside} [pzs $PZDT 0]]] \
  {-1 -1}

## ⚠ ngspice REFUSES ITSELF UNDER KLU, AND SAYS SO -- so ASE-L says the same
## words. `pzan.c:29-34` returns `E_UNSUPP` under `CKTkluMODE`. MEASURED on both
## binaries with `.options klu`: `Error: Pole/zero analysis is not (yet)
## supported with 'option KLU'. / Use 'option sparse' instead.`, rc 1.
## ⚠ IT RESTS ON THE BENCH'S OPTIONS, NOT THE NETLIST, so `exact 0` never reaches
## it and the second half of this row is the non-vacuity: the same deck without
## the option says nothing.
set PZK [pcheck $PZNL [pzrow inp in outp out] {{name klu value 1}}]
eqcheck PF228i-pole-zero-under-the-klu-solver-is-fatal-and-names-sparse \
  [list [pzn $PZK 0] [pzv $PZK 0] \
        [expr {[string first {KLU} [pzs $PZK 0]] >= 0}] \
        [expr {[string first {sparse} [pzf $PZK 0]] >= 0}] \
        [dict size [pcheck $PZNL [pzrow inp in outp out] {{name klu value 0}}]]] \
  {pz_klu fatal 1 1 0}

## ⚠ AND A `fatal` REACHES THE GATE, WHERE IT IS NOT DEFEASIBLE. `set
## ase_preflight 0` turns off a REFUSAL about a save list; it may not be a way
## past a simulator that will not reach the end of its own control block.
said_clear
set PZG [pcall ase::preflight_gate \
  [dict replace [mkstate $RD c $PZNL] analyses [pzrow inp in inn in outp out]] $PZNL]
eqcheck PF228j-the-gate-refuses-a-shorted-pz-row-and-names-the-node \
  [list [string range $PZG 0 3] \
        [expr {[said_count {*'in'*}] >= 1}] \
        [expr {[said_count {*shorted*}] >= 1}]] \
  {ERR: 1 1}

## ⚠ AND A DECK THE ANALYSIS CAN RUN STILL PASSES THE SAME GATE, so PF228j is
## measuring the shorted input and not something else about this state.
eqcheck PF228k-a-runnable-pz-row-passes-the-same-gate \
  [pcall ase::preflight_gate \
    [dict replace [mkstate $RD c $PZNL] analyses [pzrow inp in outp out]] $PZNL] \
  {}

## ⚠ A SWITCHED-OFF pz ROW MAKES NO CLAIM ABOUT A RUN, and an empty one is the
## commit door's business -- `ase::analysis_emit_check` already refuses an empty
## required field by name, and two sentences about one mistake is the shape issue
## 1420 deleted from the Arguments column.
## ⚠ GROUND IS NEVER LOOKED UP, AND THIS ROW EXISTS BECAUSE THE OBVIOUS SABOTAGE
## SURVIVED WITHOUT IT. Deleting the `$n eq {0}` skip left PF228a-PF228l ALL PASS
## (sabotage S22), because every deck those rows use writes node `0` on a card
## and `ase::netlist_map` therefore has it. A deck that spells its reference
## `gnd` does not -- MEASURED, `ase::netlist_facts` on `V1 in gnd dc 1 / R1 in
## out 1k / R2 out gnd 1k` answers a node set with no `0` in it -- and the two
## reference fields DEFAULT to `0`, so without the skip the commonest pz row
## there is would be reported as naming a node the circuit has not got.
set PZNLG "* t\nV1 in gnd dc 1\nR1 in out 1k\nR2 out gnd 1k\n.end\n"
eqcheck PF228m-ground-is-never-looked-up-even-in-a-deck-that-never-writes-node-0 \
  [list [dict size [pcheck $PZNLG [pzrow inp in outp out]]] \
        [dict size [pcheck $PZNLG [pzrow inp in inn gnd outp out outn gnd]]] \
        [pzn [pcheck $PZNLG [pzrow inp in inn 0 outp out]] 0]] \
  {0 0 NO:pz}

eqcheck PF228l-a-disabled-or-empty-pz-row-is-left-alone \
  [list [dict size [pcheck $PZNL {{type pz enabled 0 inp in inn in outp out}}]] \
        [dict size [pcheck $PZNL {{type pz enabled 1}}]] \
        [dict size [pcheck $PZNL {{type pz enabled 1 inp in}}]] \
        [lindex [lindex [ase::analysis_emit_check ngspice {type pz enabled 1}] 0] 0]] \
  {0 0 0 missing}

# ===========================================================================
# PF229 — DC sensitivity's two preconditions (Stage 5, issue 1428)
# ===========================================================================
## ⚠ TWO PREDICATES, AND THE SECOND HAS NO ANALOGUE ANYWHERE ELSE IN THE
## REGISTRY. `sens_out` is the third analysis in a row whose output ngspice does
## not validate; `sens_filters` is about a mistake that leaves the run with NO
## PLOT AT ALL and still reports success. MEASURED 2026-09-12 on the fork
## (`build-ver_50`) and on apt 45.2 alike, each `-b` deck wrapped in this tree's
## own `sim_status` guard, reading four of the ~90 vectors a four-device deck
## produces:
##
##   sens v(mid) dc        -> rc 0  r1 -1.38889e-04  r2 2.777775e-05
##                                  r3  2.777775e-05  v1 8.333333e-01 (right)
##   sens v(nosuchnode) dc -> rc 0  EVERY vector -0.000000e+00
##   sens v(in,nosuch) dc  -> rc 0  v1 1.000000e+00 and the rest 0 -- the
##                                  missing REFERENCE is silently ground
##   sens i(Vsense) dc     -> rc 0  r1 -2.77778e-08 … v1 1.666667e-04 (right)
##   sens i(R1) dc         -> rc 0  every vector 0.000000e+00
##   sens i(C1) dc         -> rc 0  every vector 0.000000e+00
##   sens i(L1) dc         -> rc 0  every vector 0.000000e+00
##   sens i(I1) dc         -> rc 0  every vector 0.000000e+00
##   sens i(nosuchsrc) dc  -> rc 0  every vector 0.000000e+00
##   sens x(mid) dc        -> rc 1  `Error: Syntax error: voltage or current
##                                   expected.`                -> RUN-FAILED
##   sens v mid dc         -> rc 1  `Error: Syntax error: '(' expected after
##                                   'v'`                      -> RUN-FAILED
##
##   sens v(mid) r1 dc        -> $plots `const sens1`, one vector: r1
##   sens v(mid) r1 nosuch dc -> $plots `const sens1`, one vector: r1 -- the bad
##                               filter is DROPPED IN SILENCE
##   sens v(mid) nosuch dc    -> $plots `const`, $curplotname `constants`, rc 0,
##                               REACHED-THE-END: NO SENSITIVITY PLOT AT ALL
##   sens v(mid) zzz* dc      -> the same
##
## ⚠ THE LAST BLOCK IS WHY `sens_filters` EXISTS, AND IT WAS FOLLOWED ALL THE
## WAY THROUGH THIS TREE'S OWN RENDERER RATHER THAN REASONED ABOUT. MEASURED
## 2026-09-12: `ase::backend::ngspice::render_deck` against a scratch library
## with an explicit `rundir`, one enabled row
## `{type sens enabled 1 out v(mid) filters nosuchdev}`, run on BOTH binaries --
##
##   rc 0, and the only record in <cell>_ase.raw is
##     Title: Constant values / Plotname: constants / No. Variables: 12
##   ase::raw_content_verdict -> ok 0  constants 1  plotname constants
##
## -- which is the artifact the top of this file is about, reached from a
## direction nobody had walked: not a `.save` of a missing node, a FILTER that
## matched nothing. ⚠ AND DEFENCE (c) CATCHES IT AND GUESSES THE CAUSE WRONG:
## its sentence says *"the analysis did not run (typically a .save of a node the
## circuit does not have)"*. That is what makes defence (a) worth having here --
## `sens_filters` is the only place the real cause can be said.
set SENL "* t\nV1 in 0 dc 1 ac 1\nR1 in mid 1k\nR2 mid out 2k\nR3 out sns 3k\nVsense sns 0 dc 0\nC1 mid 0 1n\nL1 mid lx 1u\nRL lx 0 10k\nI1 0 mid dc 0\n.end\n"
proc serow {args} { return [list [concat {type sens enabled 1} $args]] }
proc sen {pc n} { return [lindex [lindex [dgn $pc sens] $n] 0] }
proc sev {pc n} { return [lindex [lindex [dgn $pc sens] $n] 1] }
proc ses {pc n} { return [lindex [lindex [dgn $pc sens] $n] 2] }
proc sef {pc n} { return [lindex [lindex [dgn $pc sens] $n] 3] }

## ⚠ THE DISCRIMINATOR FOR EVERY ROW BELOW, inherited rather than re-learned:
## without a row asserting that a runnable sens row says NOTHING, every row here
## is satisfied by a predicate that reports on every deck (PF227a, PF228a).
eqcheck PF229a-a-sens-row-this-circuit-can-run-says-nothing \
  [list [dict size [pcheck $SENL [serow out {v(mid)}]]] \
        [dict size [pcheck $SENL [serow out {v(mid,out)}]]] \
        [dict size [pcheck $SENL [serow out {i(Vsense)}]]] \
        [dict size [pcheck $SENL [serow out {v(mid)} filters {r1 r2}]]]] \
  {0 0 0 0}

## ⚠ THE SHARPER HALF OF `sens_out`, AND SHARPER THAN `tf`'s. ngspice reports
## THREE numbers for a `tf` output that is not there; it reports a table of ~90
## zeros for a `sens` one, which a user reads as a result.
set SEPB [pcheck $SENL [serow out {v(nosuchnode)}]]
eqcheck PF229b-an-output-node-that-is-not-in-the-circuit-is-reported \
  [list [sen $SEPB 0] [sev $SEPB 0] \
        [expr {[string first {'nosuchnode'} [ses $SEPB 0]] >= 0}] \
        [expr {[string first {fills in a table} [ses $SEPB 0]] >= 0}] \
        [sef $SEPB 0]] \
  {sens_out caution 1 1 {name a node that is in the circuit}}

## ⚠ AND IT CARRIES THE `.include` CAVEAT, because an included file really could
## define that node. This is the half the static rule is right about.
eqcheck PF229c-the-missing-node-carries-the-static-caveat \
  [expr {[string first {cannot see inside an .include} [ses $SEPB 0]] >= 0}] 1

## ⚠ THE SYNTAX ERROR IS `fatal` AND CARRIES NO CAVEAT -- no `.include` can make
## `v mid` a legal output. ⚠ AND THE REASON IS **NOT** `tf`'s. `tf v mid V1`
## blames the SOURCE with an EMPTY name (`Warning: Transfer function source  not
## in circuit`); `sens v mid dc` answers `Error: Syntax error: '(' expected
## after 'v'`, which names the output and the missing parenthesis. ngspice is
## honest here. The verdict is `fatal` for one reason only: MEASURED, the
## guard's `quit 1` fires and nothing after it in `.control` runs.
set SEPM [pcheck $SENL [serow out {v mid}]]
eqcheck PF229d-an-output-this-simulator-cannot-read-is-fatal-and-carries-no-include-caveat \
  [list [sen $SEPM 0] [sev $SEPM 0] \
        [string first {cannot see inside} [ses $SEPM 0]] \
        [expr {[string first {parentheses are not optional} [sef $SEPM 0]] >= 0}]] \
  {sens_out fatal -1 1}

## ⚠ AND THE GATE REFUSES IT, WHILE A RUNNABLE ROW STILL PASSES -- so PF229d is
## measuring the malformed output and not something else about this state.
said_clear
set SEG [pcall ase::preflight_gate \
  [dict replace [mkstate $RD c $SENL] analyses [serow out {v mid}]] $SENL]
eqcheck PF229e-the-gate-refuses-the-malformed-output-and-a-runnable-row-passes \
  [list [string range $SEG 0 3] \
        [expr {[said_count {*v mid*}] >= 1}] \
        [pcall ase::preflight_gate \
          [dict replace [mkstate $RD c $SENL] analyses [serow out {v(mid)}]] $SENL]] \
  {ERR: 1 {}}

## ⚠ `i(...)` IS A VOLTAGE SOURCE AND ONLY A VOLTAGE SOURCE, MEASURED ACROSS
## FIVE DEVICE CLASSES. The INDUCTOR and the CURRENT SOURCE are the two that
## discriminate: `i(L1)` is a real branch current elsewhere in ngspice, so
## "nothing else has a branch current" would have been a right answer resting on
## a wrong reason; and `I1` IS in `facts sources`, so a predicate asking "is this
## an independent source" instead of "is this a voltage source" passes it in
## silence at rc 0.
set SEI1 [pcheck $SENL [serow out {i(R1)}]]
set SEI2 [pcheck $SENL [serow out {i(I1)}]]
set SEI3 [pcheck $SENL [serow out {i(L1)}]]
set SEI4 [pcheck $SENL [serow out {i(C1)}]]
eqcheck PF229f-a-current-output-that-names-no-voltage-source-is-reported \
  [list [sen $SEI1 0] [sev $SEI1 0] [sen $SEI2 0] [sen $SEI3 0] [sen $SEI4 0] \
        [expr {[string first {'i(I1)'} [ses $SEI2 0]] >= 0}] \
        [expr {[string first {table of zeros} [ses $SEI2 0]] >= 0}] \
        [dict size [pcheck $SENL [serow out {i(Vsense)}]]]] \
  {sens_out caution sens_out sens_out sens_out 1 1 0}

## ⚠ EACH NODE OF A TWO-NODE OUTPUT IS CHECKED, AND ONLY THE MISSING ONE IS
## NAMED. MEASURED: `sens v(in,nosuch) dc` is rc 0 with `v1 = 1.000000e+00` --
## the missing reference is silently taken as ground -- so a predicate that
## stopped at the first node would pass it.
set SEP2 [pcheck $SENL [serow out {v(mid,nosuch)}]]
eqcheck PF229g-the-reference-node-of-a-two-node-output-is-checked-too \
  [list [sen $SEP2 0] \
        [expr {[string first {'nosuch'} [ses $SEP2 0]] >= 0}] \
        [expr {[string first {'mid'} [ses $SEP2 0]] >= 0}]] \
  {sens_out 1 0}

## ⚠ `sens_filters`: THE ONE FINDING IN THIS BATCH WHOSE FAILURE MODE IS AN
## EMPTY RESULT RATHER THAN A WRONG ONE. The sentence has to say so, because
## "no results at all" is the thing a user cannot diagnose from a run that
## printed nothing and exited 0.
set SEF1 [pcheck $SENL [serow out {v(mid)} filters {nosuchdev}]]
eqcheck PF229h-a-filter-that-names-nothing-in-the-circuit-is-reported \
  [list [sen $SEF1 0] [sev $SEF1 0] \
        [expr {[string first {'nosuchdev'} [ses $SEF1 0]] >= 0}] \
        [expr {[string first {no results at all} [ses $SEF1 0]] >= 0}] \
        [expr {[string first {subcircuit} [sef $SEF1 0]] >= 0}]] \
  {sens_filters caution 1 1 1}

## ⚠ AND IT IS `caution` WITH THE CAVEAT AND THE GATE DOES **NOT** REFUSE IT.
## An `.include`d file really can add a top-level device with that name, so a
## refusal here would be the false refusal this whole pass avoids -- even though
## the consequence of being right is a run with nothing in it. ⚠ THE SEVERITY
## TRACKS WHAT THE STATIC PASS CAN KNOW, NEVER HOW BAD THE OUTCOME IS.
eqcheck PF229i-the-filter-finding-is-a-caution-and-does-not-refuse-the-run \
  [list [expr {[string first {cannot see inside an .include} [ses $SEF1 0]] >= 0}] \
        [pcall ase::preflight_gate \
          [dict replace [mkstate $RD c $SENL] analyses \
             [serow out {v(mid)} filters {nosuchdev}]] $SENL]] \
  {1 {}}

## ⚠ THE HIERARCHY ROW, AND IT IS WHAT REFUTES APPENDIX §2.10's NAMING TABLE.
## That table -- `<inst>`, `<inst>:<param>`, `<inst>_<param>` -- is measured on a
## FLAT deck, and every xschem bench has subcircuits. MEASURED 2026-09-12 on both
## binaries, `V1 / X1 / R9` at top level with `Ra` and `Rb` inside
## `.subckt divider`, the COMPLETE bare-name set of the sens plot:
##
##     r.x1.ra   r.x1.rb   r9   v1
##
## A subcircuit device is `<letter>.<instance path>.<name>` and the subckt CALL
## `x1` produces nothing at all. So filtering on `ra` -- the name the user sees
## inside their own subcircuit -- matches NOTHING, and a check that searched
## every scope would find `ra` and say nothing. The predicate is keyed on the
## TOP scope for exactly that reason.
set SEHNL "* t\nV1 in 0 dc 1\nX1 in mid divider\nR9 mid 0 5k\n.subckt divider a b\nRa a b 1k\nRb b 0 2k\n.ends\n.end\n"
set SEH1 [pcheck $SEHNL [serow out {v(mid)} filters {ra}]]
eqcheck PF229j-a-device-that-exists-only-inside-a-subcircuit-is-reported-and-a-top-level-one-is-not \
  [list [sen $SEH1 0] \
        [expr {[string first {'ra'} [ses $SEH1 0]] >= 0}] \
        [dict size [pcheck $SEHNL [serow out {v(mid)} filters {r9}]]] \
        [dict size [pcheck $SEHNL [serow out {v(mid)} filters {v1}]]] \
        [dict size [pcheck $SEHNL [serow out {v(mid)} filters {r.x1.ra}]]]] \
  {sens_filters 1 0 0 0}

## ⚠ A GLOB AND A DOTTED NAME GET NO OPINION, AND BOTH SILENCES ARE DELIBERATE.
## The candidate vector set is `<inst>`, `<inst>:<param>` and `<inst>_<param>`
## over a parameter list ASE-L cannot enumerate without a run, so whether `r*`
## matches something is NOT decidable from the netlist -- MEASURED, `sens v(mid)
## zzz* dc` also produces no plot, and ASE-L still may not say so, because the
## same reasoning that would catch `zzz*` would refuse `m*:vth0` on a deck whose
## MOS devices are in an `.include`d PDK. A dotted name is the user spelling a
## hierarchical vector themselves, which this pass cannot flatten.
eqcheck PF229k-a-glob-and-a-dotted-name-are-left-alone \
  [list [dict size [pcheck $SENL [serow out {v(mid)} filters {zzz*}]]] \
        [dict size [pcheck $SENL [serow out {v(mid)} filters {r?}]]] \
        [dict size [pcheck $SENL [serow out {v(mid)} filters {r.x9.nope}]]] \
        [dict size [pcheck $SENL [serow out {v(mid)} filters {r1 zzz*}]]]] \
  {0 0 0 0}

## ⚠ AND AN EXACT NAME IS ACCEPTED IN ALL THREE OF ngspice's SPELLINGS, AND
## CASE-INSENSITIVELY. `r1` is the principal, `r1:r` a model parameter, `r1_temp`
## an instance parameter; all three are vectors `R1` produces. A predicate that
## only compared the bare name would report every parameter-qualified filter a
## user actually writes.
eqcheck PF229l-the-three-vector-spellings-of-a-device-that-IS-there-are-accepted \
  [list [dict size [pcheck $SENL [serow out {v(mid)} filters {r1}]]] \
        [dict size [pcheck $SENL [serow out {v(mid)} filters {r1:r}]]] \
        [dict size [pcheck $SENL [serow out {v(mid)} filters {r1_temp}]]] \
        [dict size [pcheck $SENL [serow out {v(mid)} filters {R1:TC1}]]] \
        [dict size [pcheck $SENL [serow out {v(mid)} filters {vsense i1 l1}]]] \
        [sen [pcheck $SENL [serow out {v(mid)} filters {r1 r9:r}]] 0]] \
  {0 0 0 0 0 sens_filters}

## ⚠ THERE ARE NOW **THREE** COPIES OF THE "DOES THIS CIRCUIT HAVE THIS NODE"
## WALK -- `tf_out`, `pz_nodes` AND `sens_out` -- AND NOTHING WOULD NOTICE IF ONE
## DRIFTED. They were written one stage-commit apart and they must agree about
## exactly one thing: that the comparison FOLDS. `ase::netlist_map`'s scope table
## stores the netlist's own spelling, so a case-sensitive copy reports "this
## circuit has no node 'MID'" for a deck that has `mid` -- issue 1401's PF214
## trap, one layer up. This row is not a refactor and does not pretend to be one:
## it makes the drift VISIBLE, by asking all three the same two questions.
## ⚠ THE COPIES ARE DELIBERATELY LEFT IN PLACE. Collapsing them into one core
## reader is the right change and it is NOT this commit's -- `tf_out` and
## `pz_nodes` belong to issues 1426 and 1427, and a refactor of two shipped
## predicates in the last commit of a stage buys tidiness at the price of a
## regression nobody asked for. The next crew that touches any of the three
## inherits this row and the reason.
set SE3W "* t\nV1 IN 0 dc 1\nR1 IN Mid 1k\nR2 Mid 0 2k\nVsense Mid mm 0\n.end\n"
eqcheck PF229o-the-three-copies-of-the-node-walk-agree-about-folding \
  [list [dict size [pcheck $SE3W [list {type tf enabled 1 out v(mid) insrc v1}]]] \
        [dict size [pcheck $SE3W [list {type pz enabled 1 inp in outp mid}]]] \
        [dict size [pcheck $SE3W [serow out {v(mid,MID)}]]] \
        [lindex [lindex [dgn [pcheck $SE3W \
           [list {type tf enabled 1 out v(nope) insrc v1}]] tf] 0] 0] \
        [lindex [lindex [dgn [pcheck $SE3W \
           [list {type pz enabled 1 inp nope outp mid}]] pz] 0] 0] \
        [lindex [lindex [dgn [pcheck $SE3W [serow out {v(nope)}]] sens] 0] 0]] \
  {0 0 0 tf_out pz_nodes sens_out}

## ⚠ `sens` INHERITS THE CIDER/KLU PAIR, AND THIS ROW EXISTS BECAUSE A SABOTAGE
## SURVIVED WITHOUT IT (S38). Measured, `cider_klu` can be deleted from this
## entry's `needs` and `test_ase_core` AND `test_ase_preflight` both stay green:
## PF224f/PF224g pin the PREDICATE, and nothing pinned which types SUBSCRIBE to
## it. That matters here more than it looks -- `cider_klu` is `fatal` because a
## CIDER device under KLU makes ngspice `exit(1)` rather than return an error, so
## a `sens` row that did not declare it would let the user start a run in which
## every analysis after the CIDER one silently does not happen.
## ⚠ AND BOTH HALVES ARE ASSERTED, because a predicate that fired on the device
## alone would refuse every deck the CIDER build exists for.
eqcheck PF229n-a-sens-row-inherits-the-cider-klu-pair-and-needs-both-halves-of-it \
  [list [dict size [pcheck $CIDERNL [serow out {v(out)}]]] \
        [lindex [lindex [dgn [pcheck $CIDERNL [serow out {v(out)}] \
                          {{name klu value 1}}] sens] 0] 0] \
        [lindex [lindex [dgn [pcheck $CIDERNL [serow out {v(out)}] \
                          {{name klu value 1}}] sens] 0] 1] \
        [lindex [lindex [dgn [pcheck $CIDERNL [serow out {v(out)}] \
                          {{name klu value 1}}] sens] 0] 3]] \
  {0 cider_klu fatal {select the `sparse` solver for this run}}

## ⚠ A SWITCHED-OFF OR EMPTY ROW IS LEFT ALONE, and an UNREADABLE filter value
## answers nothing rather than raising. The box is free text, so an unbalanced
## brace is a value a user can type -- and this predicate runs on the Run path,
## where a raise would abort a deck write instead of saying something.
## ⚠ THE UNREADABLE LEG GOES THROUGH `pcall` AND ITS ANSWER IS COMPARED AS AN
## ORDINARY VALUE, AND THAT IS NOT DEFENSIVE PADDING. A bare
## `[dict size [pcheck …]]` here is only legal while the predicate catches the
## raise -- and dropping that catch is the exact change this leg exists to
## catch, so it would abort the whole file inside this suite's outer `catch` and
## print `FATAL:` instead of reddening a row. A suite that dies names the defect
## with a line number; a row that reds names it with a sentence.
eqcheck PF229m-a-disabled-or-empty-or-unreadable-sens-row-is-left-alone \
  [list [dict size [pcheck $SENL {{type sens enabled 0 out {v mid}}}]] \
        [dict size [pcheck $SENL {{type sens enabled 1}}]] \
        [pcall pcheck $SENL [serow out {v(mid)} filters "r1 \{"]] \
        [lindex [lindex [ase::analysis_emit_check ngspice {type sens enabled 1}] 0] 0]] \
  {0 0 {} missing}

# ---------------------------------------------------------------------------
# PF230 — the SEVEN preconditions Stage 6d's three multi-plot types bring with
# them (issue 1432), and the one that reaches back to two Stage 5 entries.
#
# ⚠ THE MEASUREMENTS, all 2026-09-12, on the fork (`ngspice-46+`) AND on
# `/usr/bin/ngspice` (`ngspice-45.2`), identical on both:
#
#   noise v(mid) v1 dec 2 1k 10k         -> rc 0, right
#   noise v(nosuchnode) v1 dec 2 1k 10k  -> rc 0, A FULL TWO-PLOT RESULT, silent
#   noise i(v1) v1 dec 2 1k 10k          -> rc 1, `Error: bad syntax [.noise
#                                           v(OUT) SRC {DEC OCT LIN} …]`
#   noise v(mid) vnope   …               -> rc 1, `Noise input source vnope not
#                                           in circuit`
#   noise v(mid) r1      …               -> rc 1, `… r1 is not of proper type`
#   noise v(mid) v2      …               -> rc 1, `… v2 has no AC value`
#   .options klu + noise …               -> rc 1, `Noise simulation is not (yet)
#                                           supported with 'option KLU'`
#   .options klu + sens … ac dec 1 1k 10k-> rc 139, SIGSEGV
#   .options klu + sens … dc             -> rc 0, byte-identical to sparse
#   .save v(nosuchnode) + disto          -> rc 139, SIGSEGV
#   .save v(mid) / .save v(nosuchnode)
#                        + disto         -> rc 0
#   no save card         + disto         -> rc 0
#   .save v(mid)         + noise/tf/sens -> rc 1, `Error: no data saved for
#                                           <analysis>; analysis not run`
#   .save all            + noise/tf/sens -> rc 0
#   disto, no source carrying `distof1`  -> rc 0, three rows of meaningless
#                                           numbers, NOTHING on either stream
#   disto … 0.9, no source with `distof2`-> rc 1, `incomplete or empty netlist`
#
# ⚠ `disto_saves` AND `vecsaves` ARE THE FIRST PREDICATES IN THIS FILE THAT READ
# THE BENCH'S **OUTPUT ROWS** rather than the analysis row they are asked about,
# which is why `ase::needs_eval` takes the state at all. `pcheck` builds a
# default state, so these rows use `pcheckx`, which merges extra keys in.
proc pcheckx {nl analyses opts extra} {
  set st [ase::state_default]
  dict set st analyses $analyses
  dict set st options $opts
  dict for {k v} $extra { dict set st $k $v }
  return [ase::analysis_precheck ngspice $st [ase::netlist_facts $nl]]
}
set MPNL "* t\nV1 in 0 dc 0 ac 1 distof1 1 0 distof2 1 0\nV2 bias 0 dc 2\nR1 in mid 1k\nC1 mid 0 1n\nR2 mid 0 2k\n.end\n"
set MPNLNOD "* t\nV1 in 0 dc 0 ac 1\nV2 bias 0 dc 2\nR1 in mid 1k\nC1 mid 0 1n\n.end\n"
proc mprow {args} { return [list [concat {type noise enabled 1} $args]] }
proc mpn {pc ty n} { return [lindex [lindex [dgn $pc $ty] $n] 0] }
proc mpv {pc ty n} { return [lindex [lindex [dgn $pc $ty] $n] 1] }
proc mps {pc ty n} { return [lindex [lindex [dgn $pc $ty] $n] 2] }
proc mpids {pc ty} {
  set o {}
  foreach r [dgn $pc $ty] { lappend o [lindex $r 0] }
  return $o
}
set MPGOOD {out {v(mid)} insrc V1 sweep dec points 4 start 1k stop 100k}
set MPSAVED {outputs {{name m expr v(mid) save 1 plot 1}}}
set MPBLANKET {save_all_v 1 outputs {{name m expr v(mid) save 1 plot 1}}}

## ⚠ THE DISCRIMINATOR, inherited from PF227a/PF228a/PF229a: without a row
## asserting that a runnable noise row says NOTHING, every row below is satisfied
## by a predicate that reports on every deck.
eqcheck PF230a-a-noise-row-this-circuit-can-run-says-nothing \
  [list [dict size [pcheckx $MPNL [mprow {*}$MPGOOD] {} $MPBLANKET]] \
        [dict size [pcheckx $MPNL [mprow {*}[dict merge $MPGOOD {out {v(mid,in)}}]] {} $MPBLANKET]] \
        [dict size [pcheckx $MPNL [mprow {*}$MPGOOD] {} {save_all_v 1}]]] \
  {0 0 0}

## ⚠ THE OUTPUT IS A VOLTAGE AND ONLY A VOLTAGE, which is where `noise` differs
## from `tf` and `sens`: both of those take `i(<vsrc>)`.
set MPPI [pcheckx $MPNL [mprow {*}[dict merge $MPGOOD {out {i(V1)}}]] {} $MPBLANKET]
## ⚠ THE LAST TERM IS ⚖ R9 A1 part 2's: `VOLTAGE` was shouted mid-sentence here
## and is now lowercase, and nothing else in the clause is shouted either.
eqcheck PF230b-a-current-output-is-refused-as-fatal-because-noise-measures-a-voltage \
  [list [mpn $MPPI noise 0] [mpv $MPPI noise 0] \
        [string match {*measures a voltage*} [mps $MPPI noise 0]] \
        [regexp {[A-Z]{2,}} [mps $MPPI noise 0]]] \
  {noise_out fatal 1 0}

## ⚠ AND A MISSING NODE IS THE SILENT ONE: rc 0 and a whole spectrum of numbers.
## It is `blocked`, so the static demotion turns it into a `caution` carrying the
## `.include` caveat -- a node the netlist text cannot see may still exist.
set MPPN [pcheckx $MPNLNOD [mprow {*}[dict merge $MPGOOD {out {v(nosuchnode)}}]] {} $MPBLANKET]
eqcheck PF230c-a-missing-output-node-is-reported-and-demoted-with-its-caveat \
  [list [mpn $MPPN noise 0] [mpv $MPPN noise 0] \
        [string match {*nosuchnode*} [mps $MPPN noise 0]] \
        [string match {*cannot see inside an .include*} [mps $MPPN noise 0]]] \
  {noise_out caution 1 1}

## ⚠ THREE SENTENCES FOR THREE DIFFERENT THINGS, and the third is the one
## `ac_source` cannot say: V2 IS a source and the deck HAS an AC source, so
## `ac_source` is satisfied and the run still dies.
set MPS1 [pcheckx $MPNL [mprow {*}[dict merge $MPGOOD {insrc Vnope}]] {} $MPBLANKET]
set MPS2 [pcheckx $MPNL [mprow {*}[dict merge $MPGOOD {insrc R1}]] {} $MPBLANKET]
set MPS3 [pcheckx $MPNL [mprow {*}[dict merge $MPGOOD {insrc V2}]] {} $MPBLANKET]
eqcheck PF230d-the-input-source-is-refused-three-different-ways \
  [list [mpn $MPS1 noise 0] [string match {*has no 'Vnope'*} [mps $MPS1 noise 0]] \
        [mpn $MPS2 noise 0] [string match {*not an independent source*} [mps $MPS2 noise 0]] \
        [mpn $MPS3 noise 0] [string match {*carries no AC value*} [mps $MPS3 noise 0]]] \
  {noise_insrc 1 noise_insrc 1 noise_insrc 1}

## ⚠ EXACTLY ONE PREDICATE SPEAKS FOR EACH, AND THAT IS THE NON-VACUITY HALF.
## `noise_out` is silent for all three because `v(mid)` is a perfectly good
## output in every one of them -- so these rows measure `noise_insrc` and not
## "some predicate said something".
eqcheck PF230d2-only-the-input-source-predicate-speaks-and-the-output-one-stays-silent \
  [list [mpids $MPS1 noise] [mpids $MPS3 noise] \
        [llength [dgn $MPS1 noise]] [llength [dgn $MPS3 noise]]] \
  {noise_insrc noise_insrc 1 1}

## ⚠ ngspice REFUSES ITSELF UNDER KLU AND NAMES THE FIX, so ASE-L says the same
## words earlier. `fatal`, for `pz_klu`'s reason: the guard's `quit 1` fires and
## every analysis after this one in the deck silently does not happen.
set MPK [pcheckx $MPNL [mprow {*}$MPGOOD] {{name klu value 1}} $MPBLANKET]
eqcheck PF230e-noise-under-klu-is-fatal-and-offers-the-sparse-solver \
  [list [mpn $MPK noise 0] [mpv $MPK noise 0] [mps $MPK noise 0] \
        [lindex [lindex [dgn $MPK noise] 0] 3]] \
  {noise_klu fatal {ngspice does not support noise analysis under the KLU solver} {select the `sparse` solver for this run}}

## ⚠ SENS IS THE ONE CROSS-RULE THAT IS MODE-DEPENDENT, and the mode is the
## difference between rc 0 and a SIGSEGV. `cktsens.c:97-105`'s guard is commented
## out -- and note what the commented guard would have refused: ALL sensitivity
## under KLU, DC included. DC under KLU is measurably safe, so refusing it would
## refuse a run that works. It is only expressible because the mode is a modelled
## field rather than free text.
set MPSK1 [pcheckx $MPNL {{type sens enabled 1 out {v(mid)} mode ac sweep dec points 2 start 1k stop 10k}} \
                         {{name klu value 1}} $MPBLANKET]
set MPSK2 [pcheckx $MPNL {{type sens enabled 1 out {v(mid)}}} {{name klu value 1}} $MPBLANKET]
## ⚠ RE-BASELINED BY ISSUE 1442: `fatal` -> `caution`, AND IT IS A DECISION
## RATHER THAN A DRIFT. Stage 6's 6g-1 settled the principle -- a refusal where
## the emitter can make the run correct is a FALSE refusal, and a false refusal
## is worse than a missed one -- and issue 1442 measured that the emitter CAN,
## on both binaries, on the deck shape ASE-L actually writes:
##
##   .options klu + tran + AC sens + tran, no suppression   -> rc 139, SIGSEGV
##   the same deck with `option klu=0` before the sens and
##   `option klu` after it                                  -> rc 0, and the
##       solver reads KLU / sparse / KLU across the three jobs
##
## and the sens numbers are BYTE-IDENTICAL to the same analysis on a deck that
## never asked for KLU. So the user keeps KLU for every analysis that can use
## it and loses it only for the one that cannot.
##
## ⚠ THE REFUSAL IS NOT DELETED, IT IS DEMOTED TO THE CASE THE EMITTER CANNOT
## FIX -- a backend with no `analysis_suppress` hook, or one whose speller
## cannot write the off-line, still gets `fatal`, because the alternative there
## is the SIGSEGV. Row RU2 of `test_ase_effective_1442` is that half.
eqcheck PF230f-ac-sensitivity-under-klu-is-suppressed-and-dc-sensitivity-under-klu-is-untouched \
  [list [mpids $MPSK1 sens] [mpv $MPSK1 sens 0] \
        [string match {*crashes ngspice outright*} [mps $MPSK1 sens 0]] \
        [dict size $MPSK2]] \
  {sens_klu caution 1 0}

## ⚠ THE SHARPEST DEFECT IN THE WHOLE SURFACE, AND MAKING `disto` RENDERABLE IS
## WHAT PUT IT IN REACH. The trigger is the save list RESOLVING TO NOTHING, not
## a bad entry and not the absence of a save -- `design-C`'s proposed refusal
## ("`disto` enabled AND zero saved outputs") would refuse the deck on the last
## line here, which was measured to run.
set MPDROW {{type disto enabled 1 sweep dec points 2 start 1k stop 10k}}
## REAL: R-OUT8's leader rides with the card, and `.save all` + `.save
## v(nosuchnode)` + disto is the measured rc 0 above -- so nothing is refused.
eqcheck PF230g0-REAL-disto-is-not-refused-the-leader-rescues-it \
  [dict size [pcheckx $MPNL $MPDROW {} {outputs {{name a expr v(nosuchnode) save 1 plot 1}}}]] 0
pf_narrowed {
set MPD_BAD [pcheckx $MPNL $MPDROW {} {outputs {{name a expr v(nosuchnode) save 1 plot 1}}}]
set MPD_TWOBAD [pcheckx $MPNL $MPDROW {} \
  {outputs {{name a expr v(nosuchnode) save 1 plot 1} {name b expr v(alsonone) save 1 plot 1}}}]
set MPD_MIX [pcheckx $MPNL $MPDROW {} \
  {outputs {{name a expr v(nosuchnode) save 1 plot 1} {name b expr v(mid) save 1 plot 1}}}]
set MPD_ALL [pcheckx $MPNL $MPDROW {} \
  {save_all_v 1 outputs {{name a expr v(nosuchnode) save 1 plot 1}}}]
set MPD_NONE [pcheckx $MPNL $MPDROW {} {outputs {}}]
set MPD_UNTICKED [pcheckx $MPNL $MPDROW {} {outputs {{name a expr v(nosuchnode) save 0 plot 1}}}]
set MPD_CUR [pcheckx $MPNL $MPDROW {} {outputs {{name a expr i(Vnope) save 1 plot 1}}}]
set MPD_CUROK [pcheckx $MPNL $MPDROW {} {outputs {{name a expr i(V1) save 1 plot 1}}}]
}
eqcheck PF230g-DORMANT-disto-is-refused-only-when-the-WHOLE-save-list-resolves-to-nothing \
  [list [mpv $MPD_BAD disto 0] [mpn $MPD_BAD disto 0] \
        [mpv $MPD_TWOBAD disto 0] \
        [dict size $MPD_MIX] [dict size $MPD_ALL] [dict size $MPD_NONE] \
        [dict size $MPD_UNTICKED]] \
  {fatal disto_saves fatal 0 0 0 0}

## ⚠ AND THE SENTENCE SAYS SEGFAULT IN AS MANY WORDS, because the whole point is
## that there is no exit status and no log to explain it afterwards.
eqcheck PF230h-DORMANT-the-disto-refusal-says-what-happens-and-offers-three-ways-out \
  [list [string match {*SEGFAULT*} [mps $MPD_BAD disto 0]] \
        [string match {*cannot see inside an .include*} [mps $MPD_BAD disto 0]] \
        [string match {*Save all voltages*} [lindex [lindex [dgn $MPD_BAD disto] 0] 3]]] \
  {1 1 1}

## ⚠ A CURRENT SAVE STARVES IT TOO: `.save i(vnope)` is a branch current of a
## source that is not there, and it resolves to nothing exactly as a node does.
eqcheck PF230i-DORMANT-a-branch-current-of-a-source-that-is-not-there-starves-it-as-well \
  [list [mpv $MPD_CUR disto 0] [dict size $MPD_CUROK]] {fatal 0}

# ===========================================================================
# PF234 -- ⚖ R9 RULING A1: THE WORDS, AND THE TWO EXCEPTIONS IT KEPT
# ===========================================================================
## The user ruled on 2026-09-15 that capitals survive in a user-facing sentence
## ONLY where a word names a catastrophic OUTCOME or marks a CLASS OF ROW;
## everywhere else emphasis inside a sentence loses them, and a field label
## carries no arithmetic.
##
## ⚠ THIS SECTION EXISTS BECAUSE THE RULING DELIBERATELY LEAVES THE INTERFACE
## LOOKING INCONSISTENT, and the user was told so before ruling: four sentences
## lost their capitals while one word and eleven row prefixes kept theirs. The
## distinction is STRUCTURAL -- prefix and outcome versus emphasis -- and
## structural distinctions are the ones a reader does not notice. Without these
## rows a later consistency pass tidies the exceptions away in good faith and
## nobody ever learns that a user ruling was reversed.

## ⚠ `SEGFAULTS` IS THE ONE SHOUTED WORD A1 KEPT, AND IT IS NOT EMPHASIS. It
## names a category of outcome: ngspice dies and leaves NO exit status, NO log
## and NO results file, so there is nothing afterwards to explain it. Every
## other shouted word in this batch stressed a word the reader would hit anyway.
## The third term is the non-vacuity half -- it is the ONLY all-caps run in the
## sentence, so a pass that lowercased it reds, and so does one that shouts
## something new beside it.
eqcheck PF234a-DORMANT-SEGFAULTS-is-the-one-shouted-word-ruling-A1-deliberately-kept \
  [list [string match {*ngspice SEGFAULTS,*} [mps $MPD_BAD disto 0]] \
        [string match {*segfaults*} [mps $MPD_BAD disto 0]] \
        [lsort -unique [regexp -all -inline {[A-Z]{2,}} [mps $MPD_BAD disto 0]]]] \
  {1 0 SEGFAULTS}

## ⚠ AND THE GATE'S CLOSING SENTENCE IS NOW POSITIVE, IN ALL FOUR PLACES IT IS
## SAID. It read "`set ase_preflight 0` does NOT disable this check."; A1 part 2
## asked for the rewrite rather than a bare lowercasing. The second term is the
## absence half -- a guard against a shout coming back must itself be tested
## against the shout, or it passes on a tree that never had one.
##
## ⚠ THIS ROW MOVED UNDER ⚖ R9 A8, 2026-09-16, AND THE COUNT MOVED WITH IT.
## It used to scan `ase::preflight_gate` and require the fragment FOUR times,
## because four refusals inside that one procedure each spelled the closing
## sentence out -- which is precisely why A1 had to rewrite it in four places at
## once, and how the two "it is enabled on this bench" refusals came to diverge
## mid-sentence while their tails stayed identical. §A8 collapsed the tail into
## `ase::preflight_refusal`, so the fragment now lives ONCE and the gate names
## that proc four times. ⚠ TERM 4 IS THE LOAD-BEARING ONE NOW: it requires the
## gate to keep NO copy of the sentence at all, so a fifth refusal that spelled
## its own tail again reds here instead of quietly restoring the old shape.
eqcheck PF234b-the-gate-closes-every-refusal-positively-from-ONE-body \
  [list [regexp -all {leaves this check in force} [info body ase::preflight_refusal]] \
        [regexp -all {does NOT disable} [info body ase::preflight_refusal]] \
        [regexp -all {ase::preflight_refusal} [info body ase::preflight_gate]] \
        [regexp -all {leaves this check in force} [info body ase::preflight_gate]]] \
  {1 0 4 0}

## ⚠ AND `DEGREES` LOST ITS CAPITALS IN THE distof1 ADVICE. `<mag>` and `<phase>`
## stay as they are: they are literal placeholder text the user is meant to type
## over, which is §A9's business and not A1's -- so the shout test is deliberately
## for a RUN of capitals, which those two placeholders do not contain.
set MPD_F1 [pcheckx $MPNLNOD $MPDROW {} \
  {save_all_v 1 outputs {{name a expr v(mid) save 1 plot 1}}}]
set MPD_F1ROW [lindex [dgn $MPD_F1 disto] \
  [lsearch -index 0 -exact [dgn $MPD_F1 disto] disto_f1src]]
# ⚠ MOVED BY ⚖ R9 A9 (2026-09-16) AND STRENGTHENED WHILE IT MOVED. Term 2 used
# to match the literal `(phase is in degrees)`; A9 respelled the remedy because
# `<mag>` and `<phase>` were LITERAL placeholder text sitting on the same screen
# as `<outv>`/`<node>`/`<name>`, which are substituted values. Term 2 now matches
# the surviving words, and TERM 4 IS THE NEW ONE AND THE REASON THE ROW IS
# STRONGER: it demands no `<` anywhere in the remedy, which is A9's actual
# ruling -- the invariant that any `<...>` still on screen is a substitution
# that failed. A1's lowercase `degrees` (term 3) is unaffected and still pinned.
eqcheck PF234c-the-distof1-advice-says-degrees-in-lower-case-shouts-nothing-and-carries-no-literal-placeholder \
  [list [lindex $MPD_F1ROW 0] \
        [string match {*a magnitude and a phase in degrees*} [lindex $MPD_F1ROW 3]] \
        [regexp {[A-Z]{2,}} [lindex $MPD_F1ROW 3]] \
        [string first {<} [lindex $MPD_F1ROW 3]]] \
  {disto_f1src 1 0 -1}

# ---------------------------------------------------------------------------
# PF235 -- ⚖ R9 RULING A8: SIBLING SENTENCES THAT HAD DRIFTED APART
# ---------------------------------------------------------------------------
#
# Five places tell a user to name a node, and before this ruling they said it
# FOUR different ways: `name a node that is in the circuit` (tf, sens),
# `name nodes that are in the circuit` (pz), `name a node, as \`v(out)\` or
# \`v(out,ref)\`` (noise, current output) and `name a node this netlist has`
# (noise, missing node). Nothing distinguished them -- the same remedy, for the
# same mistake, in one dialog -- so they read as typos.
#
# ⚠ THE PLURAL WAS NOT A REAL PLURAL, AND THAT IS WHY IT COULD GO. §A8 says a
# genuinely plural site STAYS plural, because flattening a true plural makes the
# sentence false. `pz_nodes` looked plural because it walks FOUR node slots
# (`inp inn outp outn`) and may find more than one missing -- but no FIELD of it
# accepts a list: each box holds exactly one node, and the remedy is what to type
# in one box. `tf_out` has the same shape (it decomposes `v(out,ref)` into two
# nodes) and was always singular. So the plural was drift, not meaning.
#
# ⚠ AND R9-119's EXAMPLE SYNTAX IS INFORMATION, NOT DRIFT -- PF235b. Converging
# that sentence onto the template would have DELETED the one place the noise form
# tells a user how a node voltage is spelled. §A8 says move it, do not delete it,
# so the template took the example with it rather than replacing it.
proc mpf {pc ty n} { return [lindex [lindex [dgn $pc $ty] $n] 3] }
set PF235TF [pcheck $TFNL [tfrow out {v(nosuchnode)} insrc V1]]
set PF235PZ [pcheck $PZNL [pzrow inp nosuch outp out]]
set PF235SE [pcheck $SENL [serow out {v(nosuchnode)}]]
set PF235NI [pcheckx $MPNL [mprow {*}[dict merge $MPGOOD {out {i(V1)}}]] {} $MPBLANKET]
set PF235NN [pcheckx $MPNLNOD [mprow {*}[dict merge $MPGOOD {out {v(nosuchnode)}}]] {} $MPBLANKET]

eqcheck PF235a-the-four-missing-node-remedies-are-now-one-singular-sentence \
  [list [tff $PF235TF 0] [pzf $PF235PZ 0] [sef $PF235SE 0] [mpf $PF235NN noise 0]] \
  [list {name a node that is in the circuit} {name a node that is in the circuit} \
        {name a node that is in the circuit} {name a node that is in the circuit}]

## ⚠ THE `v(out,ref)` TERM IS THE ACCEPTANCE CRITERION OF THIS HALF. A row that
## only asserted the template would pass on a tree where the example had been
## quietly dropped, which is the one outcome §A8 explicitly forbids.
eqcheck PF235b-the-noise-current-remedy-joined-the-template-and-KEPT-its-example \
  [list [mpf $PF235NI noise 0] \
        [string match {*v(out)*} [mpf $PF235NI noise 0]] \
        [string match {*v(out,ref)*} [mpf $PF235NI noise 0]]] \
  [list {name a node that is in the circuit, as `v(out)` or `v(out,ref)`} 1 1]

## ⚠ THE NON-VACUITY HALF, AND TERM 3 IS THE SHARPEST THING IN THIS SECTION:
## the four remedies are not merely "similar", they are ONE string, so a list of
## them de-duplicates to length 1. A future edit to any single site reds here
## with the count going to 2 -- which is the drift itself, caught as it happens.
eqcheck PF235c-the-plural-and-the-two-other-spellings-are-gone-and-the-four-are-ONE-string \
  [list [string match {*name nodes*} [pzf $PF235PZ 0]] \
        [string match {*this netlist has*} [mpf $PF235NN noise 0]] \
        [llength [lsort -unique [list [tff $PF235TF 0] [pzf $PF235PZ 0] \
                                      [sef $PF235SE 0] [mpf $PF235NN noise 0]]]]] \
  {0 0 1}

## ⚠ AND THE GATE PAIR, END TO END THROUGH THE REAL GATE -- not through the
## composer, which is test_ase_core row SN7. §A8's other pair: two refusals that
## open with the same nine words and diverge mid-sentence. The tail is now ONE
## string (ase::preflight_refusal) and the LEAD is the only thing that differs,
## because the lead genuinely differs -- MEASURED 2026-09-16: an incomplete row
## and an unrenderable type fail the deck writer at two different points, and
## issue 1401's measured pre-guard behaviour was a run that COMPLETED in silence,
## which the other's never was. Flattening that would make one sentence FALSE,
## which §A8 ranks as worse than the drift.
said_clear
set PF235S1 [mkstate $RD c $GOOD]
dict set PF235S1 analyses {{type op enabled 1} {type tran enabled 1 step 1n}}
ase::preflight_gate $PF235S1 $NL
set PF235L1 [lindex [lindex $::said end] 1]
said_clear
set PF235S2 [mkstate $RD c $GOOD]
dict set PF235S2 analyses {{type op enabled 1} {type pss enabled 1 source v1}}
catch {ase::preflight_gate $PF235S2 $NL}
set PF235L2 [lindex [lindex $::said end] 1]
set PF235T {Nothing was generated: no deck, no raw, no log.}
eqcheck PF235d-the-two-gate-refusals-share-one-tail-and-differ-only-in-the-lead \
  [list [string match "*$PF235T*" $PF235L1] \
        [string match "*$PF235T*" $PF235L2] \
        [string match {*leaves this check in force.} $PF235L1] \
        [string match {*leaves this check in force.} $PF235L2] \
        [string match {*would have started and produced nothing for it.*} $PF235L1] \
        [string match {*would have completed, produced no result for it, and said nothing.*} $PF235L2]] \
  {1 1 1 1 1 1}

## ⚠ THE SILENT ZEROS. `CKTdisto`'s `D_RHSF1` walk looks for a source carrying
## `distof1`; with none it stamps nothing and the analysis runs to completion.
## `distof1` is `IP` -- input-only, "unquestionable" (`vsrc.c:50-51`) -- so
## `show` cannot read it back and the netlist card is the only place it is
## visible, which is why this rests on ase::netlist_facts.
set MPD_NOF1 [pcheckx $MPNLNOD $MPDROW {} $MPBLANKET]
set MPD_NOF2 [pcheckx $MPNLNOD {{type disto enabled 1 sweep dec points 2 start 1k stop 10k f2overf1 0.9}} \
                      {} $MPBLANKET]
eqcheck PF230j-a-disto-row-with-no-distof1-source-is-reported-and-the-IM-mode-also-wants-a-distof2 \
  [list [mpids $MPD_NOF1 disto] [mpv $MPD_NOF1 disto 0] \
        [mpids $MPD_NOF2 disto] \
        [string match {*distof2*} [mps $MPD_NOF2 disto 1]]] \
  {disto_f1src caution {disto_f1src disto_f2src} 1}

## ⚠ AND THE DECK THAT HAS BOTH SAYS NOTHING, which is the non-vacuity half.
eqcheck PF230k-a-deck-carrying-both-excitations-is-not-reported \
  [list [dict size [pcheckx $MPNL $MPDROW {} $MPBLANKET]] \
        [dict size [pcheckx $MPNL {{type disto enabled 1 sweep dec points 2 start 1k stop 10k f2overf1 0.9}} \
                           {} $MPBLANKET]]] \
  {0 0}

## ⚠ THE STARVATION, AND AT ISSUE 1434 IT STOPPED BEING A REFUSAL. APPENDIX
## §7.5.2 assigns it to "Stage 6's precondition" by name, and issue 1432 shipped
## it as `fatal`: a bench with one ticked output and a `noise` row was REFUSED,
## and the user was told to go and tick Save all voltages themselves. 6g-1 is
## the emission rule that makes the run WORK instead -- measured on the fork and
## on apt 45.2, a `.save all` leader above the narrowed cards runs every one of
## these decks at rc 0 -- so the refusal became a FALSE one and this file's own
## rule is that a false refusal is worse than a missed one. What is left is the
## thing only ASE-L can say: the save list was widened and the Save ticks will
## not narrow it.
##
## ⚠ AND `pz` JOINED THE CLASS WHILE `disto` LEFT IT, both by measurement and
## both against what three documents say. `.save v(mid)` + `pz` prints
## `Error: no data saved for pole-zero analysis; analysis not run` -- AT rc 0 AND
## `$sim_status` 0, so the deck's guard never fires and `RUN-FAILED` never
## appears; it is the one type whose starvation is silent end to end. `disto`'s
## own plot Variables block is `frequency v(in) v(mid) v(out) i(v1)`, netlist
## names every one, and `.save v(mid)` + `disto` is rc 0 on both binaries.
## REAL: R-OUT8 -- nothing is narrowed, so there is no widening to report.
eqcheck PF230l0-REAL-no-type-reports-a-widening \
  [list [dict size [pcheckx $MPNL [mprow {*}$MPGOOD] {} $MPSAVED]] \
        [dict size [pcheckx $MPNL {{type pz enabled 1 inp in outp mid}} {} $MPSAVED]]] {0 0}
pf_narrowed {
set MPVS_N [pcheckx $MPNL [mprow {*}$MPGOOD] {} $MPSAVED]
set MPVS_T [pcheckx $MPNL {{type tf enabled 1 out {v(mid)} insrc V1}} {} $MPSAVED]
set MPVS_S [pcheckx $MPNL {{type sens enabled 1 out {v(mid)}}} {} $MPSAVED]
set MPVS_P [pcheckx $MPNL {{type pz enabled 1 inp in outp mid}} {} $MPSAVED]
set MPVS_D [pcheckx $MPNL {{type disto enabled 1 sweep dec points 2 start 1k stop 10k}} \
                    {} $MPSAVED]
set MPVS_2 [pcheckx $MPNL [mprow {*}$MPGOOD] {} \
  {outputs {{name a expr v(mid) save 1 plot 1} {name b expr v(in) save 1 plot 1}}}]
set MPVS_M [list [dict size [pcheckx $MPNL [mprow {*}$MPGOOD] {} $MPBLANKET]] \
        [dict size [pcheckx $MPNL [mprow {*}$MPGOOD] {} {outputs {}}]] \
        [mpv [pcheckx $MPNL [mprow {*}$MPGOOD] {} \
           [dict merge $MPSAVED {save_op_params 1}]] noise 0] \
        [mpv [pcheckx $MPNL [list [concat {type noise enabled 1} $MPGOOD \
                                   {x {{save all}}}]] {} $MPSAVED] noise 0]]
}
eqcheck PF230l-DORMANT-noise-tf-sens-AND-pz-report-the-widening-as-a-caution-and-disto-does-not \
  [list [mpids $MPVS_N noise] [mpv $MPVS_N noise 0] \
        [mpids $MPVS_T tf] [mpids $MPVS_S sens] \
        [mpids $MPVS_P pz] [mpv $MPVS_P pz 0] \
        [dict size $MPVS_D]] \
  {vecsaves caution vecsaves vecsaves vecsaves caution 0}

## ⚠ AND ITS STAND-DOWNS WENT FROM THREE TO ONE, WHICH IS 6g-1 DELETING A MISSED
## REFUSAL RATHER THAN LOSING A GUARD. Issue 1432 stood down for `save_op_params`
## and for a `save all` in issue 1419's verbatim hatch, because both were
## measured to rescue the run and refusing them would have been false -- and its
## own comment named the `save_op_params` arm as a MISSED refusal, since the
## operating-point tier emits its leader only when its captured block is
## non-empty. There is nothing left to be false about: the leader is emitted
## deterministically, so the only benches with nothing to report are the ones
## whose save list was never narrowed.
eqcheck PF230m-DORMANT-only-a-bench-whose-save-list-was-never-narrowed-has-nothing-to-report \
  $MPVS_M {0 0 caution caution}

## ⚠ THE SENTENCE COUNTS, AND A BENCH WITH TWO SAVED OUTPUTS SAYS "ticks".
## A sentence that got the plural wrong would be the one thing a user quotes
## back.
eqcheck PF230n-DORMANT-the-widening-sentence-counts-the-ticks-names-the-type-and-offers-both-ways-out \
  [list [string match {*the 1 per-output Save tick on this bench*} [mps $MPVS_N noise 0]] \
        [string match {*the 2 per-output Save ticks on this bench*} [mps $MPVS_2 noise 0]] \
        [string match {*a noise analysis answers in vectors that are not netlist names*} \
           [mps $MPVS_N noise 0]] \
        [string match {*this run saves everything*} [mps $MPVS_N noise 0]] \
        [string match {*Save all voltages*} [lindex [lindex [dgn $MPVS_N noise] 0] 3]] \
        [string match {*switch the noise analysis off*} \
           [lindex [lindex [dgn $MPVS_N noise] 0] 3]]] \
  {1 1 1 1 1 1}

## ⚠ A DISABLED ROW, AN EMPTY ROW AND AN UNREADABLE ONE ARE LEFT ALONE. PF229m's
## rule, applied to the seven new predicates: none of them may raise, because a
## raise here does not redden a row -- it prints `FATAL:` and the file dies.
eqcheck PF230o-a-disabled-or-empty-or-unreadable-row-is-left-alone-by-all-seven \
  [list [dict size [pcheckx $MPNL {{type noise enabled 0 out {v(nosuchnode)}}} {} $MPSAVED]] \
        [dict size [pcheckx $MPNL {{type disto enabled 0}} {} \
                      {outputs {{name a expr v(nosuchnode) save 1 plot 1}}}]] \
        [pcall pcheckx $MPNL {{type noise enabled 1}} {} $MPBLANKET] \
        [pcall pcheckx $MPNL {{type disto enabled 1 f2overf1 {}}} {} $MPBLANKET] \
        [string match {ERR:*} \
          [pcall pcheckx $MPNL [list [concat {type noise enabled 1} $MPGOOD {x "a \{"}]] {} $MPSAVED]]] \
  {0 0 {} {} 0}

} err]} { puts "FATAL: $err" ; incr fail }


# --- PF231: THE CHECKPOINT BLOCK, AS DECK TEXT (Stage 6f, issue 1433) --------
#
# ⚖ R1's always-salvage requirement. This file's subject is the deck a state
# renders, and 6f adds lines to it, so the DECK-SHAPE half of the claim belongs
# here beside PF218's guard/remzerovec/record ordering. The plan half, the
# verdict half and the reporting half are section CK of test_ase_core.tcl.
#
# ⚠ THE ORDERING ROWS ABOVE MUST NOT HAVE MOVED, and that is asserted rather
# than hoped: `deck_of`'s own fixture is `tran 1n 1u`, a thousand estimated
# points, which is a hundredth of ase::ckpt_floor. PF218a-PF218h therefore
# describe a deck with no checkpoint block in it at all, exactly as they did
# before this issue -- and PF231a is what says so out loud.
#
# ⚠ THIS BLOCK CARRIES ITS OWN `catch`. This file's outer one closes at the
# `} err]}` above and turns a raise into `FATAL:` with the rest of its checks
# lost -- which in a sabotage log reads as "almost nothing went red".
if {[catch {

set PFCKSMALL {{type op enabled 1} {type tran enabled 1 step 1n stop 1u}}
set PFCKBIG   {{type op enabled 1} {type tran enabled 1 step 10n stop 8m}}
set PFDS [deck_of $PFCKSMALL]
set PFDB [deck_of $PFCKBIG]
eqcheck PF231a-a-transient-under-the-eligibility-floor-renders-exactly-as-it-did \
  [list [regexp -all {ckstep|cktgt|stop after|ASE-CKPT|ASE-RUN-COMPLETE} $PFDS] \
        [expr {[regexp -all {ckstep|cktgt|stop after|ASE-CKPT|ASE-RUN-COMPLETE} $PFDB] > 0}]] \
  {0 1}

## ⚠ `stop after`, NEVER `stop when`. MEASURED on both binaries: `stop when
## time > X` hands the integrator a breakpoint through CKTsetBreak() and forces a
## timepoint -- 8,011 rows against `stop after`'s 8,008 for the same
## `tran 10n 80u`, and a different timestep grid from that point on. A checkpoint
## that changes the answer is not a checkpoint. And a `stop when` is not disarmed
## when it fires, so it re-fires on the next point and `resume` advances ONE
## point: a deck written that way covers 12.5 % of its run at rc 0.
eqcheck PF231b-the-primitive-is-stop-after-and-stop-when-appears-nowhere \
  [list [regexp -all -line {^stop after \$cktgt$} $PFDB] \
        [regexp -all -line {^ +stop after \$cktgt$} $PFDB] \
        [regexp -all {stop when} $PFDB]] {1 1 0}

## ⚠ THE THRESHOLD GOES THROUGH A `set` VARIABLE, NEVER `$&`. MEASURED, both
## binaries: `$&` formats 1500000 as `1.5E+06` and com_stop() parses digits only,
## so `stop after $&cknext` prints "Syntax error parsing breakpoint
## specification.", arms NOTHING, and the run finishes unchecked at rc 0. It
## bites only above 1,000,000 points -- exactly the regime checkpointing exists
## for -- so a loop tested on short runs passes and stops working when it matters.
eqcheck PF231c-every-threshold-reaches-stop-after-through-the-set-variable \
  [list [regexp -all {stop after \$&} $PFDB] \
        [regexp -all -line {^set cktgt = \$&cknext$} $PFDB] \
        [regexp -all -line {^ +set cktgt = \$&cknext$} $PFDB]] {0 1 1}

## ⚠ THE COUNTERS ARE CREATED BEFORE THE FIRST ANALYSIS. A `let` made while
## `op1` is current lands in `op1` and is invisible from `tran1`; one made after
## the `tran` is a vector OF `tran1` and every `write` from then on emits it
## (measured: `No. Variables: 5`, a `ckdone notype dims=1` column in the
## checkpoint AND in <cell>_ase.raw). The fixture's `op` runs first precisely so
## a declaration that drifted would land in the wrong plot and this row see it.
set PFDBL [split [string trimright $PFDB "\n"] "\n"]
eqcheck PF231d-the-counters-are-declared-above-the-first-analysis \
  [list [expr {[lsearch -exact $PFDBL {let ckstep = 0}] <
               [lsearch -exact $PFDBL {op}]}] \
        [expr {[lsearch -exact $PFDBL {let ckstep = 0}] >
               [lsearch -exact $PFDBL {set appendwrite}]}] \
        [llength [lsearch -all -exact $PFDBL {let ckstep = 0}]]] {1 1 1}

## ⚠ THE GUARD AND THE RECORD DID NOT MOVE, AND THE LOOP SITS ABOVE BOTH. The
## guard's job is to `quit 1` before a failed analysis can put a plot in the
## results file, so a checkpoint loop below it would never run for the analysis
## it belongs to. This is PF218f's claim re-stated for the one analysis whose
## deck text this issue changed.
eqcheck PF231e-the-loop-sits-between-the-transient-and-its-own-guard \
  [expr {[lsearch -exact $PFDBL {tran 10n 8m}] <
         [lsearch -exact $PFDBL {while ckdone = 0}] &&
         [lsearch -exact $PFDBL {while ckdone = 0}] <
         [lsearch -exact $PFDBL {delete all}] &&
         [lsearch -exact $PFDBL {delete all}] <
         [lsearch -start [lsearch -exact $PFDBL {tran 10n 8m}] -exact $PFDBL {remzerovec}]}] 1

## ⚠ THE LOOP'S EXIT IS THE FALSE BRANCH, AND AN INFINITE LOOP IS WHY. This
## file's own `run_real` fixture saves `v(nosuchnode)` and nothing else, which
## MEASURED on both binaries makes ngspice answer `Error: no data saved for
## Transient analysis; analysis not run` -- no `tran1` plot at all. `length(time)`
## is then unevaluable, `.control`'s `if` takes the FALSE branch for a condition
## it cannot evaluate (the trap table's string `eq`/`ne` shape, met on a number),
## and a loop whose EXIT was the true branch checkpointed, re-armed and
## `resume`d forever at rc 0. The eligibility floor keeps that deck out of reach
## in the shipped configuration; the polarity is what makes it harmless if it is
## ever reached.
eqcheck PF231h-the-loop-exits-on-the-false-branch-so-an-unevaluable-condition-stops-checkpointing \
  [list [regexp -all -line {^ +if length\(time\) >= \$cktgt$} $PFDB] \
        [regexp -all -line {^ +let ckdone = 1$} $PFDB] \
        [expr {[lsearch -exact $PFDBL {    let ckdone = 1}] >
               [lsearch -exact $PFDBL {    resume}]}]] {1 1 1}

## ⚠ AND THE CHECKPOINT WRITE EMITS NO `PLOT` RECORD. The sidecar is 1:1 and in
## write order with the RESULTS file (issue 1430); one record per checkpoint
## would put that identity out by one for every run. Counted against the results
## writes rather than asserted in the abstract.
eqcheck PF231f-the-plotmap-gains-nothing-from-the-checkpoints \
  [list [regexp -all -line {^echo "PLOT } $PFDB] \
        [regexp -all -line {^write } $PFDB] \
        [regexp -all -line {^ +write } $PFDB]] {2 2 1}

## ⚠ THE COMPLETION MARKER IS THE ONLY THING THAT CAN SEE A STOP. MEASURED on
## both binaries: after `stop after 2000` fires, `$?sim_status` is 1 and
## `$sim_status` is 0, so the guard PF218 pins prints nothing, the write succeeds,
## a valid 2000-point plot lands in the file and the process exits **rc 0**.
eqcheck PF231g-the-completion-marker-is-the-last-line-inside-control \
  [list [regexp -all -line {^echo ASE-RUN-COMPLETE$} $PFDB] \
        [expr {[string match "*echo ASE-RUN-COMPLETE\n.endc\n.end\n" $PFDB] ? 1 : 0}]] {1 1}

} pf231err]} { puts "FATAL: PF231 $pf231err" ; incr fail }

# ===========================================================================
# PF232 — class B: a save list that resolves to NOTHING (issue 1434, 6g-1)
#
# Issue 1433 found that `tran` is starved the way `disto` is and handed it on as
# "a FIFTH type". MEASURED 2026-09-12 on the fork (`ngspice-46+`) and on apt 45.2
# (`ngspice-45.2`), one analysis per deck, `.save v(nosuchnode)` as the only save
# card above `.control`:
#
#   op   -> rc 1, $sim_status 1, `no data saved for D.C. Operating point analysis`
#   dc   -> rc 1, `no data saved for D.C. Transfer curve analysis`
#   ac   -> rc 1, `no data saved for A.C. Small signal analysis`
#   tran -> rc 1, `no data saved for Transient analysis`
#   pz   -> the same message at rc 0
#   disto-> rc 139, SIGSEGV
#   and every one of those decks with `.save v(mid)` instead -> rc 0
#
# It is not a fifth type. It is EVERY type, and `disto` is the only one that
# cannot be allowed to reach the simulator.
#
# ⚠ ITS OWN `catch`: PF231's closes immediately above.
# ===========================================================================
if {[catch {

set PFBAD {outputs {{name m expr v(nosuchnode) save 1 plot 1}}}
set PF32ROWS {{type op enabled 1} \
              {type dc enabled 1 source V1 start 0 stop 1 step 0.1} \
              {type ac enabled 1 sweep dec points 5 start 1k stop 100k} \
              {type tran enabled 1 step 1n stop 1u}}
## REAL: R-OUT8's leader rescues every type (measured: `.save all` + `.save
## v(nosuchnode)` runs op/dc/ac/tran/pz/disto at rc 0), so none reports it.
eqcheck PF232a0-REAL-no-type-reports-the-starvation \
  [list [dict size [pcheckx $MPNL $PF32ROWS {} $PFBAD]] \
        [dict size [pcheckx $MPNL $MPDROW {} $PFBAD]]] {0 0}
pf_narrowed {
set PF32 [pcheckx $MPNL $PF32ROWS {} $PFBAD]
set PF32B [pcheckx $MPNL $MPDROW {} $PFBAD]
set PF32E [list [dict size [pcheckx $MPNL $PF32ROWS {} [dict merge $PFBAD {save_all_v 1}]]] \
        [mpids [pcheckx $MPNL [concat $PF32ROWS [mprow {*}$MPGOOD]] {} $PFBAD] op] \
        [dict size [pcheckx $MPNL [concat $MPDROW [mprow {*}$MPGOOD]] {} $PFBAD]] \
        [mpv [pcheckx $MPNL $MPDROW {} $PFBAD] disto 0]]
set PF32F [mpids [pcheckx $MPNL [concat $MPDROW [mprow {*}$MPGOOD]] {} $PFBAD] noise]
}
eqcheck PF232a-DORMANT-every-renderable-type-reports-the-starvation-not-only-tran \
  [list [mpids $PF32 op] [mpids $PF32 dc] [mpids $PF32 ac] [mpids $PF32 tran]] \
  [list {saves_resolve} {saves_resolve} {saves_resolve} {saves_resolve}]
## ⚠ `caution`, NOT `fatal`, AND THE TIER IS THE DECISION. This rests on
## ase::netlist_facts, which answers `exact 0`: a hierarchical node inside an
## `.include`d subcircuit is unresolvable here and perfectly resolvable in
## ngspice. `disto` pays that risk because the alternative is a SIGSEGV with no
## log at all; a type that fails honestly at rc 1 must not cost a user their run
## over a blind spot.
eqcheck PF232b-DORMANT-it-is-a-caution-everywhere-and-a-fatal-only-for-disto \
  [list [mpv $PF32 op 0] [mpv $PF32 tran 0] [mpv $PF32B disto 0]] \
  {caution caution fatal}
## the discriminator: a bench whose saves resolve says nothing at all
eqcheck PF232c-a-bench-whose-saved-outputs-exist-says-nothing \
  [list [dict size [pcheckx $MPNL $PF32ROWS {} $MPSAVED]] \
        [dict size [pcheckx $MPNL $PF32ROWS {} {outputs {}}]]] {0 0}
## ...and ONE resolving output among several is enough, which is the measured
## rule (`.save v(mid)` beside `.save v(nosuchnode)` runs at rc 0 on both
## binaries) and NOT "every save must resolve"
eqcheck PF232d-one-resolving-output-among-several-is-enough \
  [dict size [pcheckx $MPNL $PF32ROWS {} \
     {outputs {{name a expr v(nosuchnode) save 1 plot 1} \
               {name b expr v(mid) save 1 plot 1}}}]] 0

## ⚠ AND BOTH TIERS STAND DOWN WHEN THE LEADER IS FORCED, because the leader is
## MEASURED to rescue them: `.save all` + `.save v(nosuchnode)` + disto -> rc 0,
## + op/dc/ac/tran/pz -> rc 0, on both binaries. Without this a bench carrying a
## `noise` row beside a stale Outputs entry would be refused for a crash 6g-1 has
## already prevented.
eqcheck PF232e-DORMANT-a-forced-leader-stands-both-tiers-down \
  $PF32E [list 0 NO:op 1 fatal]
## ⚠ the third leg above is the one that could go vacuous: `disto` + `noise` on a
## starving bench must report the WIDENING and not the segfault, so the size is 1
## and the id is the noise row's
eqcheck PF232f-DORMANT-and-what-it-reports-instead-is-the-widening \
  $PF32F {vecsaves}

## ⚠ ONE BODY, TWO TIERS. `ase::saves_unresolved` is what both arms read, so they
## cannot disagree about the FACT while disagreeing about the verdict -- and
## before it existed the only copy of the walk lived inside `disto_saves`.
set PF32ST [ase::state_default]
dict set PF32ST outputs {{name a expr v(nosuchnode) save 1 plot 1} \
                         {name b expr v(mid) save 1 plot 1} \
                         {name c expr {} save 1} \
                         {name d expr v(in) save 0}}
eqcheck PF232g-the-shared-reader-counts-ticked-and-resolved-and-ignores-the-rest \
  [pcall ase::saves_unresolved ngspice $PF32ST [ase::netlist_facts $MPNL]] {2 1}
## ⚠ ANYTHING IT CANNOT TAKE APART COUNTS AS RESOLVING, because one of its two
## callers is FATAL: every doubt falls on the side of letting the run start.
set PF32ST2 [ase::state_default]
dict set PF32ST2 outputs {{name a expr {@m.x1.m1[id]} save 1 plot 1}}
set PF32ST3 [ase::state_default]
dict set PF32ST3 outputs {{name a expr {v(mid)*2+1} save 1 plot 1}}
eqcheck PF232h-an-op-parameter-request-and-an-expression-both-count-as-resolving \
  [list [pcall ase::saves_unresolved ngspice $PF32ST2 [ase::netlist_facts $MPNL]] \
        [pcall ase::saves_unresolved ngspice $PF32ST3 [ase::netlist_facts $MPNL]]] \
  {{1 1} {1 1}}
## and a missing state or missing facts answers nothing rather than raising --
## PF229m's rule, which this file pays for in `FATAL:` lines when it is broken
eqcheck PF232i-no-state-and-no-facts-answer-zero-rather-than-raising \
  [list [pcall ase::saves_unresolved ngspice {} [ase::netlist_facts $MPNL]] \
        [pcall ase::saves_unresolved ngspice $PF32ST {}]] {{0 0} {0 0}}

## ⚠ A DISABLED ROW IS LEFT ALONE, and so is a bench whose only enabled row is
## one this backend cannot render. PF230o's rule extended to the two new ids.
eqcheck PF232j-a-disabled-row-and-an-unrenderable-one-are-left-alone \
  [list [dict size [pcheckx $MPNL {{type tran enabled 0 step 1n stop 1u}} {} $PFBAD]] \
        [dict size [pcheckx $MPNL {{type pss enabled 1}} {} $PFBAD]]] {0 0}

} pf232err]} { puts "FATAL: PF232 $pf232err" ; incr fail }

## ===========================================================================
## PF1723 -- A RENAMED INSTANCE: THE STALE-INSTANCE CORRECTION, THE MEASUREMENTS
## AND INCLUDE FILES IT STRANDS, AND THE ASE-L BUTTON'S DECISION. Issue 1723.
## ===========================================================================
## The user renamed a DUT `x1` -> `xdut`; the session's outputs, measurement
## targets and nodeset include still spelled `x1.`, the run was refused, and
## the refusal offered no way out (only a case mismatch had a correction).
##
## ⚠ THE FIXTURE IS BUILT SO EVERY RULE HAS SOMETHING TO TRIP OVER: `xa` and
## `xb` are two instances of one master (two candidates), `xother` holds `b1`
## and `xdut` holds `a1` (a partial match), `XM1`'s master is undefined (a PDK
## card must never be a candidate), and `rn_amp` holds an `x7` so a renamed
## DEEPER segment has a scope to be searched in.
## ⚠ ITS OWN `catch`, like the sections around it.
if {[catch {

set NLR {** sch_path: /fixture/rn_top.sch
**.subckt rn_top
xdut IN OUT rn_amp
xother IN OUT2 rn_amp2
xa IN rn_twin
xb IN rn_twin
V1 IN 0 1
R9 OUT 0 1k
XM1 OUT G 0 0 sky130_fd_pr__nfet_01v8 L=0.15 W=1
**.ends
.subckt rn_amp INP OUTP
x7 INP mid rn_leaf
R1 INP a1 1k
R2 a1 OUTP 1k
vs a1 tail 0
.ends
.subckt rn_amp2 INP OUTP
R1 INP b1 1k
.ends
.subckt rn_twin P
R1 P n1 1k
R2 n1 0 1k
.ends
.subckt rn_leaf A B
R1 A B 1k
.ends
.end
}
set RDR [file join $tmp run_1723]
file mkdir $RDR
set ::sim_case_mode fold
proc rn_state {outs {meas {}} {incs {}}} {
  set s [mkstate $::RDR rn_top $outs]
  if {[llength $meas]} { dict set s measurements $meas }
  if {[llength $incs]} { dict set s includes $incs }
  return $s
}
## {ident correction} of every row of one scan list, in order
proc rn_fixes {sc key} {
  set out {}
  foreach r [dg $sc $key] { lappend out [list [dgn $r ident] [dgn $r correction]] }
  return $out
}
proc rn_gate {st} {
  said_clear
  set rc [catch {ase::preflight_gate $st $::NLR} e]
  return [list $rc $e]
}
set MAPR [pcall ase::netlist_map $NLR]

## --- item 1: where the path stops, and who could stand in its place ---------
eqcheck PF1723a-the-resolver-records-where-a-path-stops-at-a-missing-instance \
  [list [dgn [pcall ase::netlist_map_resolve $MAPR voltage x1.a1 0] miss] \
        [dgn [pcall ase::netlist_map_resolve $MAPR current v.x1.vs 0] miss] \
        [dgn [pcall ase::netlist_map_resolve $MAPR voltage xdut.x8.a 0] miss] \
        [dex [pcall ase::netlist_map_resolve $MAPR voltage xdut.nosuch 0] miss]] \
  {{index 0 scope {} prefix x1} {index 1 scope {} prefix x1} {index 1 scope rn_amp prefix xdut.x8} 0}
## the PDK card XM1 and the instances whose master lacks the rest are not
## candidates; only the instance under which the rest resolves is
eqcheck PF1723b-the-search-names-only-instances-of-the-same-scope-under-which-the-rest-resolves \
  [list [pcall ase::preflight_rename_try $MAPR voltage x1.a1 0 {index 0 scope {} prefix x1}] \
        [pcall ase::preflight_rename_try $MAPR voltage x9.n1 0 {index 0 scope {} prefix x9}] \
        [pcall ase::preflight_rename_try $MAPR voltage x1.nothing 0 {index 0 scope {} prefix x1}]] \
  {{{xdut xdut.a1}} {{xa xa.n1} {xb xb.n1}} {}}

## --- item 1: a unique top-level rename is OFFERED for every refused row -----
set RNOUT {{expr v(x1.a1) save 1} {expr v(x1.tail) save 1} {expr -i(v.x1.vs) save 1}}
set scr [pcall ase::preflight_scan [rn_state $RNOUT] $NLR]
eqcheck PF1723c-a-unique-rename-fills-the-rows-existing-correction-field \
  [list [rn_fixes $scr absent] [lsort -unique [lmap r [dg $scr absent] {dgn $r fixkind}]] \
        [dg $scr renames]] \
  [list {{x1.a1 xdut.a1} {x1.tail xdut.tail} {v.x1.vs v.xdut.vs}} rename \
        {{prefix x1 to xdut fit unique candidates xdut outputs 3 measurements 0 includes 0}}]
## ...so ase::preflight_fixed_expr applies it unchanged, the leading `-` kept
eqcheck PF1723c2-and-the-existing-composer-applies-it-unchanged \
  [lmap {ex g} [pcall ase::preflight_group_rows [dg $scr absent]] {pcall ase::preflight_fixed_expr $g}] \
  {v(xdut.a1) v(xdut.tail) -i(v.xdut.vs)}
lassign [rn_gate [rn_state $RNOUT]] rcr er
eqcheck PF1723d-the-refusal-prints-the-rename-correction-per-expression \
  [list $rcr [said_count {*'v(x1.a1)' -> 'v(xdut.a1)'*}] \
        [said_count {*'-i(v.x1.vs)' -> '-i(v.xdut.vs)'*}] \
        [said_count {*Same name in another case*}]] {1 1 1 0}
## THE CLOSING REMEDY SAYS THE RIGHT THING FOR THE KIND: a rename is not issue
## 0503, and the button and the console command are both named
eqcheck PF1723e-the-closing-remedy-of-a-rename-speaks-of-a-rename-and-names-both-doors \
  [list [said_count {*issue 0503*}] \
        [said_count {*so it looks like 'x1' was renamed 'xdut'.}] \
        [said_count "*'[pcall ase::ui::lbl_repair_apply]'*ase::preflight_fix_session <key>*"]] \
  {0 1 1}
set ::sim_case_mode distinguish
lassign [rn_gate [rn_state {{expr v(in) save 1}}]] rcc ec
set scc [pcall ase::preflight_scan [rn_state {{expr v(in) save 1}}] $NLR]
eqcheck PF1723f-a-case-only-refusal-still-speaks-of-the-case-mismatch-and-of-no-rename \
  [list $rcc [said_count {*issue 0503*}] [said_count {*renamed*}] \
        [said_count "*'[pcall ase::ui::lbl_repair_apply]'*ase::preflight_fix_session <key>*"] \
        [dgn [lindex [dg $scc absent] 0] fixkind] [dg $scc renames]] \
  {1 1 0 1 case {}}
## a segment two instances fold to (`xA`, `xa`) is a CASE question with no
## answer, never a rename: no `miss`, no search, no rename record
set NLAMB "* amb\nxA IN rn_twin\nxa IN rn_twin\nV1 IN 0 1\n.subckt rn_twin P\nR1 P n1 1k\n.ends\n.end\n"
set scq [pcall ase::preflight_scan [rn_state {{expr v(XA.n1) save 1}}] $NLAMB]
eqcheck PF1723q-a-fold-ambiguous-segment-is-not-searched-for-a-rename \
  [list [llength [dg $scq absent]] [dgn [lindex [dg $scq absent] 0] ambiguous] \
        [dex [lindex [dg $scq absent] 0] miss] [dg $scq renames]] {1 1 0 {}}
set ::sim_case_mode fold

## --- item 1: TWO candidates, and a PARTIAL one, offer nothing ---------------
set sc2 [pcall ase::preflight_scan [rn_state {{expr v(x9.n1) save 1}}] $NLR]
lassign [rn_gate [rn_state {{expr v(x9.n1) save 1}}]] rc2 e2
eqcheck PF1723g-two-candidates-offer-nothing-and-the-refusal-names-both \
  [list [rn_fixes $sc2 absent] [dgn [lindex [dg $sc2 renames] 0] fit] \
        [dgn [lindex [dg $sc2 renames] 0] candidates] $rc2 \
        [said_count {*no instance 'x9', and 'xa' and 'xb' each have everything*no single correction*}] \
        [said_count {* -> *}] [said_count {*Nothing is rewritten automatically*}]] \
  {{{x9.n1 {}}} several {xa xb} 1 1 0 0}
## `xdut` holds a1 and nothing holds zz: one candidate resolving SOME rows
set RNPART {{expr v(x5.a1) save 1} {expr v(x5.zz) save 1}}
set sc3 [pcall ase::preflight_scan [rn_state $RNPART] $NLR]
lassign [rn_gate [rn_state $RNPART]] rc3 e3
eqcheck PF1723h-a-partial-match-offers-nothing-and-names-the-candidate \
  [list [rn_fixes $sc3 absent] [dgn [lindex [dg $sc3 renames] 0] fit] \
        [dgn [lindex [dg $sc3 renames] 0] candidates] $rc3 \
        [said_count {*no instance 'x5', and 'xdut' has some of what*no correction to offer*}] \
        [said_count {* -> *}]] \
  {{{x5.a1 {}} {x5.zz {}}} partial xdut 1 1 0}
## and two candidates EACH resolving a different row is partial too: xdut has
## a1, xother has b1, and neither has both
set sc3b [pcall ase::preflight_scan [rn_state {{expr v(x5.a1) save 1} {expr v(x5.b1) save 1}}] $NLR]
eqcheck PF1723h2-two-candidates-each-resolving-a-different-row-are-a-partial-match \
  [list [rn_fixes $sc3b absent] [dgn [lindex [dg $sc3b renames] 0] fit] \
        [dgn [lindex [dg $sc3b renames] 0] candidates]] \
  {{{x5.a1 {}} {x5.b1 {}}} partial {xdut xother}}
## a renamed DEEPER segment falls out of the same code: x8 inside xdut -> x7
set sc4 [pcall ase::preflight_scan [rn_state {{expr v(xdut.x8.a) save 1}}] $NLR]
eqcheck PF1723p-a-renamed-deeper-segment-falls-out-of-the-same-search \
  [list [rn_fixes $sc4 absent] [dg $sc4 renames]] \
  {{{xdut.x8.a xdut.x7.A}} {{prefix xdut.x8 to xdut.x7 fit unique candidates x7 outputs 1 measurements 0 includes 0}}}

## --- item 3: measurements -------------------------------------------------
set RNMEAS {{name m1 analysis tran kind find target v(x1.tail) at 1u}
            {name d1 analysis tran kind trigtarg trig v(x1.a1) targ v(x1.tail)}
            {name mt analysis tran kind find target v(x1.typo) at 1u}
            {name ok analysis tran kind find target v(OUT) at 1u}}
set sc5 [pcall ase::preflight_scan [rn_state {{expr v(x1.a1) save 1}} $RNMEAS] $NLR]
## THE OUTPUT ROWS DECIDE: a measurement leaf nothing has (`typo`) must not cost
## the refused outputs their correction; it stays uncorrected, and named
eqcheck PF1723i-measurement-fields-with-the-stale-prefix-are-corrected-and-a-typo-among-them-does-not-block-the-outputs \
  [list [rn_fixes $sc5 absent] \
        [lmap r [dg $sc5 measurements] {list [dgn $r meas] [dgn $r field] [dgn $r correction]}] \
        [dgn [lindex [dg $sc5 renames] 0] fit]] \
  {{{x1.a1 xdut.a1}} {{m1 target xdut.tail} {d1 trig xdut.a1} {d1 targ xdut.tail} {mt target {}}} unique}
lassign [rn_gate [rn_state {{expr v(x1.a1) save 1}} $RNMEAS]] rc5 e5
eqcheck PF1723j-the-refusal-lists-the-measurements-with-their-corrections \
  [list $rc5 \
        [said_count {*measurement 'm1' — its target 'v(x1.tail)' names instance 'x1'*: 'v(x1.tail)' -> 'v(xdut.tail)'}] \
        [said_count {*measurement 'd1' — its trig 'v(x1.a1)'*-> 'v(xdut.a1)'}] \
        [said_count {*measurement 'mt' — its target 'v(x1.typo)'*not have}] \
        [said_count {*measurement 'ok'*}] \
        [said_count {*output rows and measurements; then save.}]] {1 1 1 1 0 1}
## ⚠ A STALE MEASUREMENT ALONE NEVER REFUSES A RUN (unruled behaviour change),
## and says nothing; the scan still carries it for the explicit command
set RNMONLY [rn_state {{expr v(OUT) save 1}} {{name m1 analysis tran kind find target v(x1.a1) at 1u}}]
lassign [rn_gate $RNMONLY] rc6 e6
set sc6 [pcall ase::preflight_scan $RNMONLY $NLR]
eqcheck PF1723k-a-stale-measurement-alone-does-not-refuse-and-is-not-said \
  [list $rc6 $e6 [llength $::said] [dg $sc6 absent] \
        [lmap r [dg $sc6 measurements] {dgn $r correction}]] {0 {} 0 {} xdut.a1}

## --- item 3: include files, LISTED and never edited -------------------------
set INCF [file join $RDR rn_nodeset.spice]
## three hits: `x1.a1`, `x1.tail`, and `X1.tail` (fold compares without case);
## NOT the bare `x1` axis key, and NOT `xdut.x1.q`, a deeper path
set INCTXT ".nodeset v(x1.a1)=1 v(x1.tail)=0\n* graph keys x1 0 x2 9\n.ic v(xdut.x1.q)=0\n+ V(X1.tail)=0\n"
putfile $INCF $INCTXT
set INCQ [file join $RDR rn_quiet.spice]
putfile $INCQ "* nothing to see\n.nodeset v(out)=0\n"
set RNINC [rn_state $RNOUT {} [list [list file $INCF] [list file $INCQ]]]
eqcheck PF1723l-an-include-file-is-listed-by-path-and-count-with-the-dot-required \
  [lmap h [pcall ase::preflight_include_hits $RNINC [dg $scr renames] 0 $RDR] \
     {list [file tail [dgn $h path]] [dgn $h prefix] [dgn $h to] [dgn $h count]}] \
  {{rn_nodeset.spice x1 xdut 3}}
lassign [rn_gate $RNINC] rc7 e7
## ⚠ MOVED, 2026-11-21 (issue 1723 item 6): the line used to end "ASE-L does not
## edit your files, so change 'x1.' to 'xdut.' there yourself"; the ruling made
## Apply Corrections rewrite the resolved `.nodeset`/`.ic` names after asking,
## and all three `x1.` hits here are in such cards (`X1.tail` too: `fold`). The
## gate still writes nothing, and no line says the old sentence.
eqcheck PF1723l2-the-refusal-names-it-says-what-the-press-will-rewrite-and-the-file-is-left-byte-identical \
  [list $rc7 \
        [said_count "*include file '[file normalize $INCF]' names 'x1.' 3 times, all in .nodeset/.ic cards: '[pcall ase::ui::lbl_repair_apply]' rewrites them to 'xdut.' after asking"] \
        [said_count {*rn_quiet*}] [expr {[readfile $INCF] eq $INCTXT}] \
        [said_count {*does not edit your files*}]] {1 1 0 1 0}

## --- the predicate the window's offer is keyed on ---------------------------
lassign [rn_gate [rn_state {{expr v(x1.a1) save 1}}]] rc8 e8
set emit_err "ase: the tran analysis has no stop time\nase: it is enabled on this bench"
eqcheck PF1723m-the-offer-predicate-reads-the-gates-own-refusal-head \
  [list [pcall ase::preflight_is_name_refusal $er] [pcall ase::preflight_is_name_refusal $e8] \
        [pcall ase::preflight_is_name_refusal $emit_err] [pcall ase::preflight_is_name_refusal {}]] \
  {1 1 0 0}

## --- item 2's apply, through the console command ---------------------------
set RD9 [file join $tmp run_1723s]
file mkdir $RD9
putfile [file join $RD9 rn_top.spice] $NLR
set INC9 [file join $RD9 rn_nodeset9.spice]
putfile $INC9 $INCTXT
putfile [file join $RD9 rn.state] \
  "design {lib dlib cell rn_top view schematic} rundir [list $RD9] outputs [list $RNOUT]\
 measurements [list $RNMEAS] includes [list [list [list file $INC9]]]"
pcall ase::session_open rnk [file join $RD9 rn.state]
set st9 [ase::session_state rnk]
set sc9 [pcall ase::preflight_session_scan rnk]
lassign [rn_gate $st9] rc9 e9
## ⚠ THE BUTTON'S DECISION, PURE: on the refusal the user just saw, for this
## session's state and its scan against the netlist artifact
set off9 [pcall ase::ui::repair_offer $e9 $st9 $sc9 \
            [ase::preflight_include_hits $st9 [dg $sc9 renames] 0 $RD9]]
eqcheck PF1723o-the-buttons-decision-offers-every-rewrite-of-both-lists-and-names-the-include \
  [list [dgn $off9 label] [dgn $off9 rows] [dgn $off9 outputs] [dgn $off9 measurements] \
        [dgn $off9 rename] [dgn $off9 case] [dgn $off9 includes]] \
  [list [pcall ase::ui::lbl_repair_apply] 5 3 2 3 0 1]
## `2 measurements`, not 3: d1's trig AND targ are one measurement rewritten.
## ⚠ MOVED, 2026-11-21 (issue 1723 items 5-6): the include clause said "ASE-L
## does not edit your files, and the refusal lists them"; it now names the door
## that shows the file. No plan is passed here, so the offer promises no file
## rewrite -- PF1723ae drives the plan.
eqcheck PF1723o2-and-its-sentence-says-what-the-press-does-and-that-saving-is-the-users \
  [list [string match "*no instance 'x1'; it looks renamed 'xdut'.*rewrites 3 output rows and 2 measurements in this session; Session > Save State keeps them.*1 include file names the old instance; [pcall ase::ui::menu_path_include_files] shows it.*" [dgn $off9 text]] \
        [string match {*does not edit your files*} [dgn $off9 text]]] {1 0}
## the three arms where there is nothing to offer
lassign [rn_gate [rn_state {{expr v(nosuch) save 1}}]] rct ett
eqcheck PF1723o3-no-offer-for-another-error-for-a-refusal-with-nothing-to-apply-or-for-a-pass \
  [list [pcall ase::ui::repair_offer $emit_err $st9 $sc9] \
        [pcall ase::ui::repair_offer $ett [rn_state {{expr v(nosuch) save 1}}] \
           [pcall ase::preflight_scan [rn_state {{expr v(nosuch) save 1}}] $NLR]] \
        [pcall ase::ui::repair_offer {} $st9 $sc9]] {{} {} {}}
## BOTH KINDS: a case-only refusal is offered too
set ::sim_case_mode distinguish
set stc [rn_state {{expr v(in) save 1} {expr v(out) save 1}}]
lassign [rn_gate $stc] rcc2 ecc2
set offc [pcall ase::ui::repair_offer $ecc2 $stc [pcall ase::preflight_scan $stc $NLR]]
eqcheck PF1723o4-a-case-mismatch-is-offered-by-the-same-button \
  [list [dgn $offc rows] [dgn $offc case] [dgn $offc rename] \
        [string match {*2 output rows differ from the netlist's own names only in case.*} [dgn $offc text]]] \
  {2 2 0 1}
set ::sim_case_mode fold
## ...and the press's command does exactly what the offer counted
said_clear
set n9 [pcall ase::preflight_fix_session rnk]
set st9b [ase::session_state rnk]
eqcheck PF1723n-fix-session-rewrites-outputs-and-measurements-and-marks-the-session-dirty \
  [list $n9 [dgn $off9 rows] [lmap o [dg $st9b outputs] {dgn $o expr}] \
        [lmap m [dg $st9b measurements] {list [ase::state_get $m target] [ase::state_get $m trig] [ase::state_get $m targ]}] \
        [pcall ase::session_dirty rnk] [said_count {*rewritten to*instance 'x1' is now 'xdut'*}]] \
  [list 5 5 {v(xdut.a1) v(xdut.tail) -i(v.xdut.vs)} \
        {{v(xdut.tail) {} {}} {{} v(xdut.a1) v(xdut.tail)} {v(x1.typo) {} {}} {v(OUT) {} {}}} 1 6]
## ⚠ MOVED, 2026-11-21 (issue 1723 item 7): the session-only repair used to pass
## the gate while the include still named `x1.` -- the user's exact state, whose
## next Run then died inside ngspice. It is refused now, by the include alone,
## and the console command still did not touch the file.
eqcheck PF1723n2-the-session-only-repair-is-still-refused-by-the-stale-include-which-it-left-untouched \
  [list [lindex [rn_gate $st9b] 0] [expr {[readfile $INC9] eq $INCTXT}] \
        [pcall ase::preflight_is_name_refusal [lindex [rn_gate $st9b] 1]] \
        [string match {ase: REFUSED — * .nodeset/.ic names in 1 include file stop at*} [lindex [rn_gate $st9b] 1]]] {1 1 1 1}
## nothing on disk moved: the state file still holds the user's text until Save
eqcheck PF1723n3-nothing-is-saved-until-the-user-saves \
  [string match {*v(x1.a1)*} [readfile [file join $RD9 rn.state]]] 1
pcall ase::session_close rnk

} pf1723err]} { puts "FATAL: PF1723 $pf1723err" ; incr fail }
set ::sim_case_mode fold
## ===========================================================================
## PF1723 items 5-7 (ruled by the user 2026-11-21) -- THE INCLUDE FILES. A
## `.nodeset`/`.ic` name in one that stops at a missing instance refuses the Run
## before ngspice (item 7); Apply Corrections rewrites the resolved ones AFTER
## ASKING, backing each file up first (item 6); Setup > Include Files… lists
## them (item 5; its window is test_ase_window.tcl's FX1723 bands).
## ===========================================================================
## The user's report: the session's outputs were corrected by Apply
## Corrections, the next Run reached ngspice, and ngspice died on
## `.nodeset v(x1.d1)={vsup-1.35}` in the bench's nodeset include -- a file no
## ASE-L window showed. MEASURED 2026-11-21 on /usr/bin/ngspice (45.2): a plain
## value on a node that is not there is dropped with `Warning : Nodeset on
## non-existent node`; a `{...}` value draws `Error: .nodeset syntax error.`,
## rc 1, no raw. PF1723ah drives exactly that, end to end.
##
## ⚠ ITS OWN `catch`, and every global it moves (the PDK roots, the default
## models, the simulator registry) is put back at its foot.
if {[catch {
set ::sim_case_mode fold
proc readbin {p} {
  if {[catch {open $p r} f]} { return "NOFILE" }
  fconfigure $f -translation binary
  set t [read $f] ; close $f ; return $t
}
proc writebin {p bytes} {
  set f [open $p w] ; fconfigure $f -translation binary
  puts -nonewline $f $bytes ; close $f
}
foreach v {::PDK_ROOT ::ASE_DEFAULT_MODELS ::env(PDK_ROOT)} {
  if {[info exists $v]} { set ::pfi_saved($v) [set $v] ; unset $v }
}

## --- item 7's reader: the names a card gives a value to ---------------------
## line 2: three names, a {...} value whole; 3-4: a comment and a blank line do
## not end the card, so line 5's `+` continues it, and its `;` comment hides
## `x1.zz`; 6-8: a `.subckt` body names its own nodes; 9: `.IC`, and ` $` is an
## inline comment; 10-11: `+` continues a `.param`, not a card; 12: `i(v1)` is
## not a node.
set CTXT "* bench\n.nodeset v(out)=1.2 v(x1.a1)=1.5 v(x1.d1)={vsup-1.35}\n* between\n\n+ v(x1.tail)=0.30 ; v(x1.zz)=0\n.subckt inner a b\n.nodeset v(a)=0\n.ends\n.IC V(x1.q)=0 \$ v(x1.yy)=1\n.param p=1\n+ v(x1.notacard)=1\n.nodeset i(v1)=0 v(x1.cur)=2\n"
set cid [pcall ase::include_card_idents $CTXT]
eqcheck PF1723r-the-card-reader-takes-top-level-nodeset-and-ic-names-through-continuations-and-past-comments \
  [lmap c $cid {list [dgn $c line] [dgn $c card] [dgn $c ident] [dgn $c value]}] \
  [list {2 nodeset out 1.2} {2 nodeset x1.a1 1.5} [list 2 nodeset x1.d1 "{vsup-1.35}"] \
        {5 nodeset x1.tail 0.30} {9 ic x1.q 0} {12 nodeset x1.cur 2}]
eqcheck PF1723r2-each-names-offsets-read-back-the-name-and-a-file-with-no-card-gives-nothing \
  [list [lmap c $cid {expr {[pcall string range $CTXT [dgn $c start] [dgn $c end]] eq [dgn $c ident]}}] \
        [pcall ase::include_card_idents "* none\nR1 a b 1k\n.print v(x1.a1)\n"]] \
  {{1 1 1 1 1 1} {}}
## THE KEYWORD ALONE ON ITS LINE, every name on `+` lines (fix round, finding
## 1): a valid layout ngspice joins and dies on exactly as on the user's card.
## LF line ends are the shape that was never read; the trailing blank and the
## CRLF forms are the controls that always were.
set kw_lf [pcall ase::include_card_idents ".nodeset\n+ v(x1.a1)=1.5\n+ v(x1.d1)={vsup}\n"]
set kw_ic [pcall ase::include_card_idents "* hdr\n.IC\n+ v(x1.q)=1\n"]
set kw_bl [pcall ase::include_card_idents ".nodeset \n+ v(x1.t)=2\n"]
set kw_cr [pcall ase::include_card_idents ".nodeset\r\n+ v(x1.c)=3\r\n"]
eqcheck PF1723r3-a-keyword-alone-on-its-line-with-every-name-on-continuations-is-read-with-LF-ends-too \
  [list [lmap c $kw_lf {list [dgn $c line] [dgn $c card] [dgn $c ident] [dgn $c value]}] \
        [lmap c $kw_ic {list [dgn $c line] [dgn $c card] [dgn $c ident]}] \
        [lmap c $kw_bl {dgn $c ident}] [lmap c $kw_cr {dgn $c ident}]] \
  [list [list {2 nodeset x1.a1 1.5} [list 3 nodeset x1.d1 "{vsup}"]] {{3 ic x1.q}} x1.t x1.c]
## `//` IS AN INLINE COMMENT TO NGSPICE (fix round, finding 3; MEASURED
## 2026-11-21: `.nodeset v(b)=0.5 // v(x1.q)={0.4}` runs at rc 0 with no
## warning, on 45.2 and ver_53, with or without the blank before `//`). A name
## behind one is not read, a line that is only a `//` comment is as transparent
## as a `*` line, and a comment character inside a quoted value is not one
## (ngspice's inp_stripcomments_line skips quoted strings).
set CMT ".nodeset v(xdut.a1)=1.5 // was v(x1.a1)=2\n.nodeset v(b)=0.5//v(x1.q)={0.4}\n.nodeset v(a)=1\n   // a note between\n+ v(x1.b)=2\n.ic v(q)='a//b' v(x1.r)=1\n"
eqcheck PF1723r4-a-name-behind-a-double-slash-comment-is-not-read-and-a-comment-only-line-is-transparent \
  [list [lmap c [pcall ase::include_card_idents $CMT] {list [dgn $c line] [dgn $c ident] [dgn $c value]}] \
        [dex [pcall ase::include_top_words [list [dict create text "R1 a b 1k // x5 q\n"]]] x5] \
        [dex [pcall ase::include_top_words [list [dict create text "R1 a b 1k // x5 q\n"]]] r1]] \
  [list {{1 xdut.a1 1.5} {2 b 0.5} {3 a 1} {5 x1.b 2} {6 q 'a//b'} {6 x1.r 1}} 0 1]
## A `#` LINE IS A COMMENT LINE TO NGSPICE, indented or not (found in the fix
## round; MEASURED 2026-11-21 on 45.2: `.nodeset v(b)=0.5`, `  # a note`, then
## `+ v(xdut.nosuch)={0.4}` is joined across the `#` line and dies on the
## syntax error). So it is transparent to the reader, and its words are not an
## element card's.
eqcheck PF1723r5-a-hash-line-is-a-comment-line-the-card-continues-across-it \
  [list [lmap c [pcall ase::include_card_idents ".nodeset v(a)=1\n  # the a1 note\n+ v(x1.h)=2\n"] {dgn $c ident}] \
        [dex [pcall ase::include_top_words [list [dict create text "# the a1 note\nR1 p q 1k\n"]]] a1] \
        [dex [pcall ase::include_top_words [list [dict create text "# the a1 note\nR1 p q 1k\n"]]] r1]] \
  {{a x1.h} 0 1}

## --- the scan: every absent include name is a row ---------------------------
set RDI [file join $tmp run_1723i]
file mkdir $RDI
set NSA [file normalize [file join $RDI ns_a.spice]]
set NSB [file normalize [file join $RDI ns_b.spice]]
## the user's shape: correct outputs, two files, a {...} value, a continuation
set NSATXT "* nodeset_enabled\n.nodeset v(OUT)=1.2 v(x1.a1)=1.5 v(x1.tail)={vsup-1.35}\n+ v(x1.mid)=0.3\n"
set NSBTXT "* nodeset_disabled\n.nodeset v(x1.a1)=0\n+ v(xdut.nosuch)=1\n.ic v(nosuchtop)={vsup}\n"
putfile $NSA $NSATXT
putfile $NSB $NSBTXT
proc ri_state {incs {outs {{expr v(OUT) save 1}}}} {
  set s [mkstate $::RDI rn_top $outs]
  dict set s models {}
  dict set s includes $incs
  return $s
}
set STI [ri_state [list [list file $NSA] [list file $NSB]]]
set ITI [pcall ase::include_texts $STI $RDI]
set SCI [pcall ase::preflight_scan $STI $NLR $ITI]
eqcheck PF1723s-the-scan-makes-a-row-of-every-absent-include-name-and-corrects-the-stale-ones \
  [lmap r [dg $SCI incrows] {list [file tail [dgn $r path]] [dgn $r line] [dgn $r ident] [dex $r miss] [dgn $r correction]}] \
  {{ns_a.spice 2 x1.a1 1 xdut.a1} {ns_a.spice 2 x1.tail 1 xdut.tail} {ns_a.spice 3 x1.mid 1 xdut.mid} {ns_b.spice 2 x1.a1 1 xdut.a1} {ns_b.spice 3 xdut.nosuch 0 {}} {ns_b.spice 4 nosuchtop 0 {}}}
eqcheck PF1723s2-with-every-output-row-correct-the-rename-is-decided-by-the-include-rows \
  [list [llength [dg $SCI absent]] [dg $SCI renames]] \
  {0 {{prefix x1 to xdut fit unique candidates xdut outputs 0 measurements 0 includes 4}}}
## ⚠ THE RULING: "these rows join the rename search like output rows". `x1.a1`
## resolves only under xdut and `x1.b1` only under xother, so an output row and
## an include row that disagree are a PARTIAL match and nothing is offered --
## where a measurement disagreeing would not cost the outputs their correction.
set NSP [file join $RDI ns_p.spice]
putfile $NSP ".nodeset v(x1.b1)=1\n"
set stp [ri_state [list [list file $NSP]] {{expr v(x1.a1) save 1}}]
set scp [pcall ase::preflight_scan $stp $NLR [pcall ase::include_texts $stp $RDI]]
eqcheck PF1723s3-an-include-row-decides-the-rename-as-an-output-row-does \
  [lmap g [dg $scp renames] {list [dgn $g fit] [dgn $g candidates] [dgn $g outputs] [dgn $g includes]}] \
  {{partial {xdut xother} 1 1}}
## the two stand-downs, each beside the control that makes it count: an
## instance an include ADDS (`x5 ...`) and a top-level node only an include
## connects (`V5 vsup5 0 1.8`). ⚠ MOVED in the fix round (finding 2): this row
## also asserted a THIRD stand-down, a case-only spelling under `distinguish`,
## on the claim that ngspice folds a card's names to lower case. MEASURED
## 2026-11-21 on ver_53 with `-D casemode=distinguish -D casemodewrite` (the
## flags ASE-L passes): it does not -- `v(XDUT.mid)={0.4}` with `xdut` in the
## netlist is `Nodeset on non-existent node`, then `.nodeset syntax error`,
## rc 1. That leg is PF1723s4b now, and it asserts the caution.
proc ri_rows {txt} {
  set f [file join $::RDI ns_sd.spice]
  putfile $f $txt
  set st [ri_state [list [list file $f]]]
  return [llength [dg [pcall ase::preflight_scan $st $::NLR [pcall ase::include_texts $st $::RDI]] incrows]]
}
set sd_a [ri_rows "x5 IN OUT rn_amp\n.nodeset v(x5.a1)=1\n"]
set sd_ac [ri_rows ".nodeset v(x5.a1)=1\n"]
set sd_b [ri_rows "V5 vsup5 0 1.8\n.nodeset v(vsup5)=1.8\n"]
set sd_bc [ri_rows ".nodeset v(vsup5)=1.8\n"]
eqcheck PF1723s4-what-the-circuit-netlist-cannot-show-stands-down \
  [list $sd_a $sd_ac $sd_b $sd_bc] {0 1 0 1}
## A CASE-ONLY SPELLING UNDER `distinguish` IS A CAUTION NAMING THE NETLIST'S
## SPELLING (finding 2): not a refusal (it has no `miss`, and the ruling refuses
## only on a missing instance), never silent, never rewritten.
set ::sim_case_mode distinguish
set NSCS [file join $RDI ns_case.spice]
putfile $NSCS ".nodeset v(XDUT.a1)={0.4} v(xdut.A1)=0.4\n"
set stcs [ri_state [list [list file $NSCS]]]
set sccs [pcall ase::preflight_scan $stcs $NLR [pcall ase::include_texts $stcs $RDI]]
lassign [rn_gate $stcs] rccs ecs
set ::sim_case_mode fold
eqcheck PF1723s4b-a-case-only-spelling-under-distinguish-is-a-caution-naming-the-netlists-spelling \
  [list [lmap r [dg $sccs incrows] {list [dgn $r ident] [dex $r miss] [dgn $r spelled] [dgn $r correction]}] \
        $rccs [said_count {ase: caution:*}] \
        [said_count "ase: caution: include file '[file normalize $NSCS]' line 1: .nodeset names 'XDUT.a1', which the netlist spells 'xdut.a1': under case mode distinguish ngspice does not fold case, so ngspice stops the run with '.nodeset syntax error', because such a name's value must be a plain number and this one is '{0.4}'."] \
        [said_count "ase: caution: include file '[file normalize $NSCS]' line 1: .nodeset names 'xdut.A1', which the netlist spells 'xdut.a1': under case mode distinguish ngspice does not fold case, so ngspice drops it with a 'non-existent node' warning, so that guess is lost."]] \
  {{{XDUT.a1 0 xdut.a1 {}} {xdut.A1 0 xdut.a1 {}}} 0 2 1 1}
## A NESTED `.include` AT AN INCLUDE FILE'S TOP LEVEL (fix round, finding 10).
## The nested file is not followed (a carried-over limit), so what it adds at
## the top level cannot be seen -- the include-bearing-scope ruling of
## ase::netlist_map_resolve applied to the top scope: a missing TOP-LEVEL
## instance or node is `unknown` and stands down. MEASURED 2026-11-21:
## /usr/bin/ngspice runs `x5` added by a nested include, with `.nodeset
## v(x5.a1)=1`, at rc 0 and no warning. The control is the same pair with the
## `.include` line removed, and a missing instance DEEPER than the top level
## still refuses, nesting or not.
proc ri_rows2 {txts} {
  set incs {}
  set i 0
  foreach t $txts {
    set f [file join $::RDI ns_sd2_[incr i].spice]
    putfile $f $t
    lappend incs [list file $f]
  }
  set st [ri_state $incs]
  set sc [pcall ase::preflight_scan $st $::NLR [pcall ase::include_texts $st $::RDI]]
  lassign [rn_gate $st] rc e
  return [list [llength [dg $sc incrows]] $rc]
}
putfile [file join $RDI stim_more.spice] "x5 IN OUT2 rn_amp\n"
eqcheck PF1723s5-a-nested-include-at-an-include-files-top-level-makes-a-missing-top-level-name-unknown \
  [list [ri_rows2 [list ".include stim_more.spice\n" ".nodeset v(x5.a1)=1\n"]] \
        [ri_rows2 [list "* no nested include\n" ".nodeset v(x5.a1)=1\n"]] \
        [ri_rows2 [list ".INC stim_more.spice\n" ".nodeset v(vsup9)=1\n"]] \
        [ri_rows2 [list ".include stim_more.spice\n" ".nodeset v(xdut.x9.a)=1\n"]] \
        [ri_rows2 [list ".subckt inner a\n.include stim_more.spice\n.ends\n" ".nodeset v(x5.a1)=1\n"]]] \
  {{0 0} {1 1} {0 0} {1 1} {1 1}}
## THE USER'S INCLUDE LIST, AS IT REALLY IS (fix round, finding 12): a PDK
## stdcell deck first -- `.subckt` bodies full of `X1 ...` element cards, some
## spelled `.SUBCKT`/`.ENDS` -- then the stale nodeset file, both by a portable
## `$::VAR` path the scan must expand. Those `X1` cards name each subcircuit's
## OWN instance, so they must never stand the top-level `x1.` rows down.
set ::PF1723LIB [file join $RDI lib1723]
file mkdir $::PF1723LIB
putfile [file join $::PF1723LIB stdcells.spice] "* a stdcell library\n.subckt lib_buf_1 A X VGND VPWR\nX1 A n1 VGND VPWR lib_inv_1\nX2 n1 X VGND VPWR lib_inv_1\n.ends\n.SUBCKT lib_inv_1 A Y VGND VPWR\nX1 A Y VGND VPWR lib_res\n.ENDS\n.subckt lib_res a b VGND VPWR\nR1 a b 1k\n.ends\n"
putfile [file join $::PF1723LIB nodeset_enabled.spice] ".nodeset v(out)=1.2 v(x1.a1)=1.5 v(x1.tail)={vsup-1.35}\n+ v(x1.mid)=0\n"
set stlib [ri_state [list {file {$::PF1723LIB/stdcells.spice}} {file {$::PF1723LIB/nodeset_enabled.spice}}]]
set itlib [pcall ase::include_texts $stlib $RDI]
set sclib [pcall ase::preflight_scan $stlib $NLR $itlib]
lassign [rn_gate $stlib] rclib elib
eqcheck PF1723s6-a-stdcell-deck-of-subckt-bodies-with-X1-cards-by-a-portable-path-stands-nothing-down \
  [list [llength $itlib] [dex [pcall ase::include_top_words $itlib] x1] \
        [lmap r [dg $sclib incrows] {list [dgn $r ident] [dex $r miss] [dgn $r correction]}] $rclib] \
  {2 0 {{x1.a1 1 xdut.a1} {x1.tail 1 xdut.tail} {x1.mid 1 xdut.mid}} 1}
## and the reader's two fix-round shapes reach the scan and the gate: the
## keyword-alone card refuses, the name behind `//` does not
eqcheck PF1723s7-the-keyword-alone-card-refuses-and-a-name-behind-a-double-slash-does-not \
  [list [ri_rows2 [list ".nodeset\n+ v(x1.a1)=1.5\n+ v(x1.tail)={vsup}\n"]] \
        [ri_rows2 [list ".nodeset v(xdut.a1)=1.5 // was v(x1.a1)=2\n"]]] \
  {{2 1} {0 0}}

## --- fix round 2: three more ways ngspice reads a card the reader did not ----
## Each is a row of the pure reader beside the scan and the gate it feeds
## (ri_rows2: {include rows, gate rc}), so a stale name read the new way both
## refuses the Run and reaches the rename search. MEASURED 2026-11-21 on
## /usr/bin/ngspice 45.2, a hand deck whose `xdut` has an internal node `m`:
## every refusing shape below dies with `.nodeset syntax error`, rc 1.
##
## A `$` LINE IS A COMMENT LINE (finding 1). `.nodeset v(b)=0.5`, `$ a note
## about x1`, `+ v(x1.q)={0.4}` is joined across the `$` line ("Please check
## line .nodeset v(b)=0.5 v(x1.q)=...") and dies; a card behind `$ x1 was the
## dut before the rename` dies the same way, after "Unusual leading characters
## like '$'". ngspice's inp_stitch_continuation_lines skips every line whose
## first non-blank character is `#`, `$` or `*`, and inp_stripcomments_line
## never cuts a `$` at column 0 (its rule wants a blank, a comma or a tab before
## it). So the line is transparent to the card reader, and its words are no
## element card's -- which is what stood the `x1.a1` row down. The indented `$`
## line is the control the comment cut always handled.
set dl_a ".nodeset v(out)=1.2\n\$ the enabled-state guesses\n+ v(x1.a1)={vsup-1.35}\n"
set dl_i ".nodeset v(out)=1.2\n   \$ an indented note\n+ v(x1.a1)=1\n"
set dl_b "\$ x1 was the dut before the rename\n.nodeset v(x1.a1)={0.4}\n"
eqcheck PF1723r6-a-dollar-line-at-column-0-is-a-comment-line-the-card-continues-across-it-and-its-words-are-no-element-cards \
  [list [lmap c [pcall ase::include_card_idents $dl_a] {list [dgn $c line] [dgn $c ident]}] \
        [lmap c [pcall ase::include_card_idents $dl_i] {dgn $c ident}] \
        [dex [pcall ase::include_top_words [list [dict create text $dl_b]]] x1] \
        [dex [pcall ase::include_top_words [list [dict create text "\$ a note\nR1 p q 1k\n"]]] r1] \
        [ri_rows2 [list $dl_a]] [ri_rows2 [list $dl_b]]] \
  {{{1 out} {3 x1.a1}} {out x1.a1} 0 1 {1 1} {1 1}}
## A BLANK BETWEEN `v` AND ITS PAREN (finding 2). ngspice's INPpas3 reads a
## card as tokens split on blanks, `=`, `(`, `)` and `,`, so `v (x1.q)` and
## `v ( x1.b ) = 2` name `x1.q` and `x1.b` (measured: `.nodeset v (x1.q)={0.4}`
## warns "Nodeset on non-existent node - x1.q", then dies; `v ( x1.q ) = 0.4`
## warns and drops it, rc 0; `v (xdut.m)={0.4}` runs clean). Each name's
## offsets still read back the name, so Apply can rewrite it. The last leg is
## the scope of the change: an OUTPUT expression keeps its old reading, because
## nothing measured says the frontend reads `v (out)` as a vector.
set BLT ".nodeset v(x1.a) = 1 v ( x1.b ) = 2\n.ic v (x1.q)={0.4}\n.nodeset\n+ v\t(x1.t)={vsup-1.35}\n"
set bl [pcall ase::include_card_idents $BLT]
eqcheck PF1723r7-a-blank-between-v-and-its-paren-is-read-as-ngspice-reads-it \
  [list [lmap c $bl {list [dgn $c line] [dgn $c card] [dgn $c ident] [dgn $c value]}] \
        [lmap c $bl {expr {[string range $BLT [dgn $c start] [dgn $c end]] eq [dgn $c ident]}}] \
        [ri_rows2 [list ".nodeset v (x1.q)={0.4}\n"]] \
        [pcall ase::preflight_idents {v (out)}]] \
  [list [list {1 nodeset x1.a 1} {1 nodeset x1.b 2} [list 2 ic x1.q "{0.4}"] \
              [list 4 nodeset x1.t "{vsup-1.35}"]] \
        {1 1 1 1} {1 1} {}]
## A TRAILING `\\` CONTINUES THE CARD ON THE NEXT LINE (finding 3). ngspice's
## inp_read blanks a line's last two non-blank characters when they are two
## backslashes (chk_for_line_continuation; not on a line whose COLUMN 0 is `*`
## or `$`) and prefixes `+` to the next physical line, before comments are cut.
## MEASURED: `.nodeset v(b)=0.5 \\` then `v(x1.q)={0.4}` is joined and dies;
## the same with `; a note` before the backslashes, with blanks after them,
## and across a `#` line that ends in them, all join; `* a note \\` does not
## continue anything. Line numbers and offsets are the file's own.
set BST ".nodeset v(out)=1 \\\\\nv(x1.a)={vsup}\n.nodeset v(b)=0.5 ; a note \\\\  \n  v(x1.q)={0.4} \\\\\nv(x1.r)=1\n.nodeset v(c)=1\n# a hash note \\\\\nv(x1.h)=2\n* a star note \\\\\n.ic v(x1.z)=1\n"
set bs [pcall ase::include_card_idents $BST]
eqcheck PF1723r8-a-trailing-double-backslash-continues-the-card-as-ngspice-joins-it \
  [list [lmap c $bs {list [dgn $c line] [dgn $c card] [dgn $c ident] [dgn $c value]}] \
        [lmap c $bs {expr {[string range $BST [dgn $c start] [dgn $c end]] eq [dgn $c ident]}}] \
        [ri_rows2 [list ".nodeset v(out)=1.2 \\\\\nv(x1.a1)={vsup-1.35}\n"]] \
        [dex [pcall ase::include_top_words [list [dict create text "R5 p \\\\\nqq 1k\n"]]] qq]] \
  [list [list {1 nodeset out 1} [list 2 nodeset x1.a "{vsup}"] {3 nodeset b 0.5} \
              [list 4 nodeset x1.q "{0.4}"] {5 nodeset x1.r 1} {6 nodeset c 1} \
              {8 nodeset x1.h 2} {10 ic x1.z 1}] \
        {1 1 1 1 1 1 1 1} {1 1} 1]

## A NODE WHOSE OWN NAME HOLDS A DOT (fix round 2, finding 6). xschem allows a
## `.` in a net name (parselabel.l's ID class), and ngspice keeps it: MEASURED
## 2026-11-21 on 45.2, `xdut in out.p amp`, `R2 out.p 0 1k` and `.nodeset
## v(out.p)=0.5` (or `={0.5}`) applies the guess with no warning, rc 0. The
## resolver walked `out` as an instance, so item 7 refused that bench, and the
## rename search offered `xdut` (it has a node `p`), so Apply would have
## rewritten the correct card to `v(xdut.p)`, which ngspice then drops (a port
## takes the outer net's name). The controls: a dotted name that is no node
## still refuses and is still offered its rename (`out.m` -> `xdut.m`), and an
## output row naming the node is not refused either.
set NLD {** sch_path: /fixture/dot_top.sch
**.subckt dot_top
V1 in 0 1
xdut in out.p dot_amp
R2 out.p 0 1k
**.ends
.subckt dot_amp a p
R1 a m 1k
R2 m p 1k
.ends
.end
}
set MAPD [pcall ase::netlist_map $NLD]
proc dot_case {txt {outs {{expr v(out.p) save 1}}}} {
  set f [file join $::RDI ns_dot.spice]
  putfile $f $txt
  set st [ri_state [list [list file $f]] $outs]
  set it [pcall ase::include_texts $st $::RDI]
  set sc [pcall ase::preflight_scan $st $::NLD $it]
  said_clear
  set rc [catch {ase::preflight_gate $st $::NLD} e]
  return [list [lmap r [dg $sc incrows] {list [dgn $r ident] [dex $r miss] [dgn $r correction]}] \
               [llength [dg $sc absent]] $rc \
               [llength [pcall ase::preflight_include_edits $sc]]]
}
eqcheck PF1723s8-a-node-whose-own-name-holds-a-dot-is-found-and-never-refused-or-rewritten-as-a-rename \
  [list [dgn [pcall ase::netlist_map_resolve $MAPD voltage out.p 0] status] \
        [dgn [pcall ase::netlist_map_resolve $MAPD voltage OUT.P 0] real] \
        [dgn [pcall ase::netlist_map_resolve $MAPD voltage xdut.m 0] status] \
        [dot_case ".nodeset v(out.p)=0.5\n"] \
        [dot_case ".nodeset v(out.m)={0.5}\n" {}]] \
  {present out.p present {{} 0 0 0} {{{out.m 1 xdut.m}} 0 1 1}}

## UNDER `distinguish`, A STALE NAME WHOSE LEAF CASE IS WRONG TOO IS REWRITTEN TO
## THE NETLIST'S WHOLE SPELLING (fix round 2, finding 4). `x1.A1` beside
## `xdut`'s `a1`: the rename search accepts `xdut` because `xdut.A1` resolves
## with a case correction, so the row's correction is `xdut.a1`; the press
## wrote only the prefix, `v(xdut.A1)`, and the case-keeping fork dies on that
## exactly as on the stale name (MEASURED 2026-11-21, ver_53 with `-D
## casemode=distinguish -D casemodewrite`: `v(xdut.M)={0.4}` and
## `v(XDUT.m)={0.4}` are `Nodeset on non-existent node`, then the syntax error,
## rc 1; `v(xdut.m)={0.4}` runs clean). The edit is now the whole name, written
## as the row's correction; the refusal offers that spelling, the confirmation
## says it, and a scan of the rewritten text finds nothing left. The control is
## `x1.tail`, whose leaf case is right: only its prefix moves, as before.
set ::sim_case_mode distinguish
set NSDI [file normalize [file join $RDI ns_dist.spice]]
putfile $NSDI ".nodeset v(x1.A1)={vsup-1.35} v(x1.tail)=0.3\n"
set stdi [ri_state [list [list file $NSDI]]]
set itdi [pcall ase::include_texts $stdi $RDI]
set scdi [pcall ase::preflight_scan $stdi $NLR $itdi]
set pldi [pcall ase::preflight_include_plan $stdi $scdi $itdi $RDI]
lassign [rn_gate $stdi] rcdi edi
set rwdi [pcall ase::include_rewrite_text [dgn [lindex $pldi 0] text] [dgn [lindex $pldi 0] edits]]
set NSDI2 [file normalize [file join $RDI ns_dist2.spice]]
putfile $NSDI2 $rwdi
set stdi2 [ri_state [list [list file $NSDI2]]]
set ndi2 [llength [dg [pcall ase::preflight_scan $stdi2 $NLR [pcall ase::include_texts $stdi2 $RDI]] incrows]]
set ::sim_case_mode fold
eqcheck PF1723s9-under-distinguish-a-stale-name-whose-leaf-case-is-wrong-too-is-rewritten-to-the-netlists-whole-spelling \
  [list [lmap r [dg $scdi incrows] {list [dgn $r ident] [dgn $r correction]}] \
        $rwdi [pcall ase::include_change_words [lindex $pldi 0]] $rcdi \
        [said_count "ase:   include file '$NSDI' line 1: .nodeset names 'x1.A1', and the netlist has no instance 'x1'. Instance 'x1' looks renamed to 'xdut': 'x1.A1' -> 'xdut.a1'"] \
        [said_count "ase:   include file '$NSDI' line 1: .nodeset names 'x1.tail', and the netlist has no instance 'x1'. Instance 'x1' looks renamed to 'xdut': 'x1.tail' -> 'xdut.tail'"] \
        $ndi2] \
  [list {{x1.A1 xdut.a1} {x1.tail xdut.tail}} ".nodeset v(xdut.a1)={vsup-1.35} v(xdut.tail)=0.3\n" \
        "1 × x1.A1 → xdut.a1, 1 × x1. → xdut." 1 1 1 0]

## UNDER `fold`, TWO SPELLINGS OF ONE STALE PREFIX ARE DECIDED APART, AS THEY
## WERE BEFORE ITEMS 5-7 (fix round 2, finding 7). The ruling kept
## ase::preflight_fix_session "working exactly as before"; the first cut of
## items 5-7 put `x1` and `X1` in one rename group under `fold`, which changed
## what the command does for a session with NO include file. Two output rows:
## `v(x1.a1)` (only xdut has a1) and `v(X1.b1)` (only xother has b1) were two
## unique renames at a464b7f6b and are again, two rows rewritten; `v(x1.a1)` and
## `v(X1.n1)` (xa and xb both have n1) leave `X1.n1` uncorrected (`several`) and
## still correct `x1.a1`.
proc fold_two {outs} {
  set st [rn_state $outs]
  set sc [pcall ase::preflight_scan $st $::NLR]
  return [list [rn_fixes $sc absent] \
               [lmap g [dg $sc renames] {list [dgn $g prefix] [dgn $g to] [dgn $g fit]}] \
               [dgn [pcall ase::preflight_apply $st $sc] n]]
}
eqcheck PF1723s10-under-fold-two-spellings-of-a-stale-prefix-are-decided-apart-as-before-items-5-7 \
  [list [fold_two {{expr v(x1.a1) save 1} {expr v(X1.b1) save 1}}] \
        [fold_two {{expr v(x1.a1) save 1} {expr v(X1.n1) save 1}}]] \
  [list [list {{x1.a1 xdut.a1} {X1.b1 xother.b1}} {{x1 xdut unique} {X1 xother unique}} 2] \
        [list {{x1.a1 xdut.a1} {X1.n1 {}}} {{x1 xdut unique} {X1 {} several}} 1]]

## --- the gate: refused before ngspice, by the include alone ------------------
lassign [rn_gate $STI] rct1 et1
eqcheck PF1723t-correct-outputs-and-a-stale-include-are-refused-by-the-include-alone \
  [list $rct1 \
        [string match {ase: REFUSED — 4 .nodeset/.ic names in 2 include files stop at an instance this circuit does not have. ngspice drops each such name with a warning when its value is a plain number, and stops the run with a syntax error when it is anything else (a {...} or '...' expression, or a parameter name). Nothing was generated*} $et1] \
        [said_count {ase: REFUSED — * output expression*}] \
        [llength [glob -nocomplain -directory $RDI *_ase.*]]] {1 1 0 0}
eqcheck PF1723t2-each-refused-name-gets-its-own-line-with-file-line-name-and-correction \
  [list [said_count "ase:   include file '$NSA' line 2: .nodeset names 'x1.a1', and the netlist has no instance 'x1'. Instance 'x1' looks renamed to 'xdut': 'x1.a1' -> 'xdut.a1'"] \
        [said_count "ase:   include file '$NSA' line 3: .nodeset names 'x1.mid', and the netlist has no instance 'x1'. Instance 'x1' looks renamed to 'xdut': 'x1.mid' -> 'xdut.mid'"] \
        [said_count "ase:   include file '$NSB' line 2: .nodeset names 'x1.a1'*"] \
        [said_count {ase:   include file * names 'xdut.nosuch'*}] \
        [said_count {ase:   include file * names 'nosuchtop'*}]] {1 1 1 0 0}
eqcheck PF1723t3-the-refusal-names-the-button-the-console-command-and-the-door-and-never-the-old-sentence \
  [list [said_count "ase: Nothing is rewritten automatically: '[pcall ase::ui::lbl_repair_apply]' * rewrites the 4 .nodeset/.ic names above in 2 include files, after asking: each file is backed up beside itself first and written at once, not at Save State. `ase::preflight_fix_includes <key>` does the same from the console, and [pcall ase::ui::menu_path_include_files] shows the files."] \
        [said_count {*does not edit your files*}] [said_count {*there yourself*}]] {1 0 0}
eqcheck PF1723u-an-absent-node-in-an-instance-that-exists-is-a-caution-saying-what-ngspice-will-do \
  [list [said_count "ase: caution: include file '$NSB' line 3: .nodeset names 'xdut.nosuch', which instance 'xdut' does not have; ngspice drops it with a 'non-existent node' warning, so that guess is lost."] \
        [said_count "ase: caution: include file '$NSB' line 4: .ic names 'nosuchtop', which the netlist does not have; ngspice stops the run with '.ic syntax error', because such a name's value must be a plain number and this one is '{vsup}'."] \
        [said_count {ase: caution:*}]] {1 1 2}
set NSC [file join $RDI ns_c.spice]
putfile $NSC ".nodeset v(xdut.nosuch)=1\n"
lassign [rn_gate [ri_state [list [list file $NSC]]]] rcu eu
eqcheck PF1723u2-and-alone-it-does-not-refuse-the-run-is-let-through-with-the-one-caution \
  [list $rcu [said_count {ase: caution:*}] [said_count {ase: REFUSED*}]] {0 1 0}
## WHAT NGSPICE DOES, BY THE VALUE'S SHAPE (fix round, finding 4). MEASURED
## 2026-11-21, identically on /usr/bin/ngspice 45.2 and ver_53, a `.nodeset`
## (and `.ic`) name on a node an existing instance does not have: a plain
## number -- `1.5`, `-0.1`, `1.5m`, `1e-3`, `1.5V`, blanks around the `=` or
## not -- is dropped with the warning at rc 0; ANYTHING ELSE -- `{0.4}`,
## `{vsup-0.1}`, `'vsup-0.1'`, `'1.5'`, the bare parameter `vsup` -- draws the
## warning and then the syntax error, rc 1. The table is the receipt's.
eqcheck PF1723u3-the-caution-says-the-run-stops-for-every-value-but-a-plain-number \
  [list [lmap v [list 1.5 -0.1 1.5m 1e-3 1.5V "{0.4}" "{vsup-0.1}" 'vsup-0.1' '1.5' vsup {}] \
           {pcall ase::include_value_plain $v}] \
        [pcall ase::include_ngspice_clause nodeset vsup] \
        [pcall ase::include_ngspice_clause ic 'vsup'] \
        [pcall ase::include_ngspice_clause ic 1e-3]] \
  [list {1 1 1 1 1 0 0 0 0 0 0} \
        "ngspice stops the run with '.nodeset syntax error', because such a name's value must be a plain number and this one is 'vsup'" \
        "ngspice stops the run with '.ic syntax error', because such a name's value must be a plain number and this one is ''vsup''" \
        "ngspice drops it with a 'non-existent node' warning, so that initial condition is lost"]
set NSD [file join $RDI ns_d.spice]
putfile $NSD ".nodeset v(x1.a1)=1\n"
lassign [rn_gate [ri_state [list [list file $NSD]]]] rcx ex1
eqcheck PF1723x-the-offer-predicate-reads-the-include-head-in-both-numbers \
  [list [pcall ase::preflight_is_name_refusal $et1] [pcall ase::preflight_is_name_refusal $ex1] \
        [string match {ase: REFUSED — 1 .nodeset/.ic name in 1 include file stops at an instance*} $ex1]] \
  {1 1 1}

## --- the engine's literals are the window's ---------------------------------
## src/ase.tcl may not depend on src/ase_window.tcl, so the label and the door
## are typed twice; with the window's procs renamed away the fallbacks speak.
set wlab [pcall ase::ui::lbl_repair_apply]
set wdoor [pcall ase::ui::menu_path_include_files]
set flab NORENAME
set fdoor NORENAME
if {![catch {rename ::ase::ui::lbl_repair_apply ::pfi_saved_lra}]} {
  set flab [pcall ase::preflight_apply_label]
  rename ::pfi_saved_lra ::ase::ui::lbl_repair_apply
}
if {![catch {rename ::ase::ui::menu_path_include_files ::pfi_saved_mpif}]} {
  set fdoor [pcall ase::preflight_include_door]
  rename ::pfi_saved_mpif ::ase::ui::menu_path_include_files
}
eqcheck PF1723w-the-engines-literal-label-and-door-equal-the-windows-own \
  [list [expr {$flab eq $wlab}] [expr {$fdoor eq $wdoor}] \
        [expr {[pcall ase::preflight_apply_label] eq $wlab}] \
        [expr {[pcall ase::preflight_include_door] eq $wdoor}] $wlab $wdoor] \
  [list 1 1 1 1 {Apply Corrections} "Setup > Include Files…"]

## --- item 6: which files may be rewritten (a pure rule, stated in its header) -
proc vf {path args} {
  return [dict merge [dict create isfile 1 writable 1 dirwritable 1 real $path] $args]
}
set ROOTS {{dir /p/sky why pdk} {dir /m/lib why models}}
eqcheck PF1723y-the-editable-predicate-follows-its-stated-rule \
  [list [pcall ase::include_edit_verdict /w/ns.spice [vf /w/ns.spice] $ROOTS] \
        [pcall ase::include_edit_verdict /p/sky/a.spice [vf /p/sky/a.spice] $ROOTS] \
        [pcall ase::include_edit_verdict /p/sky2/a.spice [vf /p/sky2/a.spice] $ROOTS] \
        [pcall ase::include_edit_verdict /m/lib/sub/x.spice [vf /m/lib/sub/x.spice] $ROOTS] \
        [pcall ase::include_edit_verdict /w/link.spice [vf /w/link.spice real /p/sky/b.spice] $ROOTS] \
        [pcall ase::include_edit_verdict /w/ns.spice [vf /w/ns.spice isfile 0] $ROOTS] \
        [pcall ase::include_edit_verdict /w/ns.spice [vf /w/ns.spice writable 0] $ROOTS] \
        [pcall ase::include_edit_verdict /w/ns.spice [vf /w/ns.spice dirwritable 0] $ROOTS]] \
  [list {} {it is under the PDK (/p/sky)} {} {it is in a model file's folder (/m/lib)} \
        {it is under the PDK (/p/sky)} {it is not a file ASE-L can read} {it is read-only} \
        {its folder is read-only, so no backup can be written beside it}]
set ::PDK_ROOT /p/sky
set rst [ri_state {}]
dict set rst models [list {file /m/lib/models.lib section tt} {file {$::NOSUCHVAR1723/x.lib} section tt}]
eqcheck PF1723y2-the-protected-folders-are-the-pdk-and-every-model-entrys-folder \
  [lmap r [pcall ase::include_protected_roots $rst $RDI] {list [dgn $r dir] [dgn $r why]}] \
  {{/p/sky pdk} {/m/lib models}}
unset ::PDK_ROOT
## ...and the facts are read off the disk, a link judged by where it points
set PDKD [file normalize [file join $tmp pdk1723]]
file mkdir [file join $PDKD models]
putfile [file join $PDKD models ns_pdk.spice] ".nodeset v(x1.a1)=1\n"
set LNK [file join $RDI ns_link.spice]
catch {file delete $LNK}
file link -symbolic $LNK [file join $PDKD models ns_pdk.spice]
set ROF [file join $RDI ns_ro.spice]
putfile $ROF ".nodeset v(x1.a1)=1\n"
file attributes $ROF -permissions 0444
set droots [list [dict create dir $PDKD why pdk]]
set ro_measurable [expr {![file writable $ROF]}]
eqcheck PF1723y3-on-disk-a-plain-file-is-editable-a-link-into-the-pdk-and-a-read-only-file-are-not \
  [list [pcall ase::include_edit_verdict $NSA [pcall ase::include_edit_facts $NSA] $droots] \
        [pcall ase::include_edit_verdict $LNK [pcall ase::include_edit_facts $LNK] $droots] \
        [expr {$ro_measurable ? [pcall ase::include_edit_verdict $ROF [pcall ase::include_edit_facts $ROF] $droots] : {it is read-only}}]] \
  [list {} "it is under the PDK ($PDKD)" {it is read-only}]
if {!$ro_measurable} { puts "skip: PF1723y3 read-only leg (this user can write a 0444 file)" }
file attributes $ROF -permissions 0644
## A PDK ROOT THAT IS ITSELF A SYMBOLIC LINK (fix round, findings 9 and 13).
## The include path resolves through the link (`file normalize` resolves every
## component but the last), so the root must be compared resolved too, or every
## file under a linked PDK_ROOT reads as editable and opens with Save. Both
## spellings of the root are kept: a root's own name and where it points.
set RPDK [file normalize [file join $tmp real_pdk1723]]
file mkdir [file join $RPDK libs]
putfile [file join $RPDK libs x.spice] ".nodeset v(x1.a1)=1\n"
set LPDK [file join $tmp pdk_link1723]
catch {file delete $LPDK}
file link -symbolic $LPDK $RPDK
set ::PDK_ROOT $LPDK
set lpinc [dgn [pcall ase::include_resolve {$::PDK_ROOT/libs/x.spice} $RDI] path]
set lpv1 [pcall ase::include_edit_verdict $lpinc [pcall ase::include_edit_facts $lpinc] \
            [pcall ase::include_protected_roots [ri_state {}] $RDI]]
unset ::PDK_ROOT
set ::env(PDK_ROOT) $LPDK/
set lpv2 [pcall ase::include_edit_verdict $lpinc [pcall ase::include_edit_facts $lpinc] \
            [pcall ase::include_protected_roots [ri_state {}] $RDI]]
unset ::env(PDK_ROOT)
eqcheck PF1723y4-a-file-under-a-symlinked-pdk-root-is-not-editable-by-either-variable \
  [list [expr {$lpinc eq [file join $RPDK libs x.spice]}] $lpv1 $lpv2] \
  [list 1 "it is under the PDK ($RPDK)" "it is under the PDK ($RPDK)"]

## --- the backup's name -------------------------------------------------------
set BKF [file join $RDI bk.spice]
putfile $BKF x
putfile $BKF.bak x
catch {file delete $BKF.bak2}
## `file link` refuses a target that does not exist, so ln(1) makes the
## dangling link
exec ln -s [file join $RDI no_such_target] $BKF.bak2
eqcheck PF1723z-the-backup-is-bak-then-bak2-bak3-and-a-dangling-link-counts-as-taken \
  [list [pcall ase::include_backup_pick /w/a.spice {}] \
        [pcall ase::include_backup_pick /w/a.spice {/w/a.spice.bak}] \
        [pcall ase::include_backup_pick /w/a.spice {/w/a.spice.bak /w/a.spice.bak2}] \
        [file tail [pcall ase::include_backup_name $BKF]]] \
  {/w/a.spice.bak /w/a.spice.bak2 /w/a.spice.bak3 bk.spice.bak3}

## --- the rewrite: only the resolved card names, every other byte kept --------
## CRLF line ends, a tab, a non-ASCII byte pair, `X1.tail` (fold), an inline
## comment hiding `x1.keep`, a comment line and a `.print` card naming `x1.a1`:
## only the three card names move, and only their stale prefix.
set RWF [file normalize [file join $RDI ns_rw.spice]]
set RWORIG [encoding convertto utf-8 "* hdr é\r\n.nodeset v(x1.a1)=1\tv(X1.tail)={vsup-1.35}\r\n+ v(x1.mid)=0 ; v(x1.keep)=9\r\n* x1.a1 in a comment stays\r\n.print v(x1.a1)\r\n"]
set RWWANT [encoding convertto utf-8 "* hdr é\r\n.nodeset v(xdut.a1)=1\tv(xdut.tail)={vsup-1.35}\r\n+ v(xdut.mid)=0 ; v(x1.keep)=9\r\n* x1.a1 in a comment stays\r\n.print v(x1.a1)\r\n"]
writebin $RWF $RWORIG
set MODD [file normalize [file join $RDI models]]
file mkdir $MODD
putfile [file join $MODD fx.lib] "* models\n"
set NSM [file join $MODD ns_m.spice]
set NSMTXT ".nodeset v(x1.a1)=1\n"
putfile $NSM $NSMTXT
proc rw_state {} {
  set s [ri_state [list [list file $::RWF] [list file $::NSM]]]
  dict set s models [list [list file [file join $::MODD fx.lib] section {}]]
  return $s
}
set STRW [rw_state]
set ITRW [pcall ase::include_texts $STRW $RDI]
set SCRW [pcall ase::preflight_scan $STRW $NLR $ITRW]
set PLAN [pcall ase::preflight_include_plan $STRW $SCRW $ITRW $RDI]
set prw [lindex $PLAN 0]
eqcheck PF1723aa-the-rewrite-moves-only-the-resolved-card-names-and-keeps-every-other-byte \
  [list [expr {[pcall ase::include_rewrite_text [dgn $prw text] [dgn $prw edits]] eq $RWWANT}] \
        [pcall ase::include_change_words $prw] \
        [pcall ase::include_rewrite_text abc {{start 0 end 1 old zz new q}}]] \
  [list 1 "2 × x1. → xdut., 1 × X1. → xdut." {ERR:the text at byte 0 is not 'zz'}]
eqcheck PF1723ab-the-plan-says-per-file-what-changes-whether-it-may-and-where-its-backup-goes \
  [lmap f $PLAN {list [file tail [dgn $f path]] [dgn $f n] [dgn $f editable] [dgn $f why] [file tail [dgn $f backup]]}] \
  [list [list ns_rw.spice 3 1 {} ns_rw.spice.bak] \
        [list ns_m.spice 1 0 "it is in a model file's folder ($MODD)" {}]]

## --- the button's decision and the confirmation's text, both pure -----------
lassign [rn_gate $STRW] rce erw
set offrw [pcall ase::ui::repair_offer $erw $STRW $SCRW \
             [pcall ase::preflight_include_hits $STRW [dg $SCRW renames] 0 $RDI $ITRW] $PLAN]
eqcheck PF1723ae-the-offer-counts-what-the-press-rewrites-in-the-files-and-which-it-may-not \
  [list $rce [dgn $offrw rows] [dgn $offrw incnames] [dgn $offrw incfiles] [dgn $offrw incblocked] [dgn $offrw includes] \
        [string match "The run was refused. The netlist has no instance 'x1'; it looks renamed 'xdut'. Apply Corrections rewrites 3 .nodeset/.ic names in 1 include file, after asking; each file is backed up first and written at once. 2 include files name the old instance; [pcall ase::ui::menu_path_include_files] shows them. 1 of them is not editable and left as it is." [dgn $offrw text]]] \
  {1 0 3 1 1 2 1}
eqcheck PF1723ae2-without-a-plan-there-is-nothing-to-press-for \
  [pcall ase::ui::repair_offer $erw $STRW $SCRW {} {}] {}
eqcheck PF1723ae3-the-confirmation-names-each-file-its-change-its-backup-and-that-files-are-written-now \
  [pcall ase::ui::repair_confirm_lines $PLAN {}] \
  [list "Apply Corrections writes these include files now, not at Session > Save State, and backs each one up first:" \
        "  ns_rw.spice: 2 × x1. → xdut., 1 × X1. → xdut. Backup: $RWF.bak" \
        "  ns_m.spice: not editable, because it is in a model file's folder ($MODD); left as it is." \
        "Cancel changes nothing."]

## THE REFUSAL'S OTHER INCLUDE ARMS, EACH BY ITS WHOLE LINE (fix round 2,
## finding 9). The ruling: neither the refusal nor the banner may still say
## "ASE-L does not edit your files", and the refusal names the door. The rows
## above assert both only where the press reaches every hit; these are the
## arms where the door is the only remedy: a file the press may not touch (in a
## model file's folder; read-only), a file whose hits sit partly outside a
## card (the mixed arm), a file with no card name at all, and the closing line
## when nothing at all is editable. Each run's lines are kept whole, so the
## banned sentence is looked for in every one of them.
proc t4_gate {st} {
  said_clear
  catch {ase::preflight_gate $st $::NLR}
  return [lmap e $::said {lindex $e 1}]
}
proc t4_has {lines want} { return [expr {[lsearch -exact $lines $want] >= 0}] }
set t4door [pcall ase::ui::menu_path_include_files]
set t4a [t4_gate $STRW]
set st4m [ri_state [list [list file $NSM]]]
dict set st4m models [list [list file [file join $MODD fx.lib] section {}]]
set t4b [t4_gate $st4m]
set NS4P [file normalize [file join $RDI ns_print4.spice]]
putfile $NS4P ".print v(x1.a1)\n"
set t4c [t4_gate [ri_state [list [list file $NS4P]] {{expr v(x1.a1) save 1}}]]
set t4banned 0
foreach ls [list $t4a $t4b $t4c] {
  foreach l $ls {
    if {[string match -nocase {*edit your files*} $l] || [string match {*there yourself*} $l]} {
      incr t4banned
    }
  }
}
eqcheck PF1723t4-the-refusals-not-editable-mixed-and-door-only-arms-name-the-door-and-never-the-old-sentence \
  [list [t4_has $t4a "ase:   include file '$RWF' names 'x1.' 6 times; 'Apply Corrections' rewrites the 3 in .nodeset/.ic cards to 'xdut.' after asking and leaves the other 3 for you to change ($t4door)"] \
        [t4_has $t4a "ase:   include file '$NSM' names 'x1.' 1 time; 'Apply Corrections' will not rewrite it, because it is in a model file's folder ($MODD): change it by hand ($t4door)"] \
        [t4_has $t4b "ase:   include file '$NSM' names 'x1.' 1 time; 'Apply Corrections' will not rewrite it, because it is in a model file's folder ($MODD): change it by hand ($t4door)"] \
        [t4_has $t4b "ase: $t4door opens the include files, to change the names above by hand."] \
        [t4_has $t4c "ase:   include file '$NS4P' names 'x1.' 1 time; 'Apply Corrections' rewrites only resolved .nodeset/.ic names, so change it by hand ($t4door)"] \
        [t4_has $t4c "ase: $t4door opens the include files, to change the names above by hand."] \
        $t4banned] {1 1 1 1 1 1 0}
## a READ-ONLY file: the door opens it read-only too (ase::ui::incdlg_open), so
## the line says what has to come first instead of naming a door that cannot
## save what it asks for
set NS4R [file normalize [file join $RDI ns_ro4.spice]]
putfile $NS4R ".nodeset v(x1.a1)=1\n"
file attributes $NS4R -permissions 0444
if {[file writable $NS4R]} {
  puts "skip: PF1723t5 (this user can write a 0444 file, so no include is read-only)"
} else {
  set t4r [t4_gate [ri_state [list [list file $NS4R]]]]
  eqcheck PF1723t5-a-read-only-include-is-said-to-need-making-writable-before-the-door-can-change-it \
    [list [t4_has $t4r "ase:   include file '$NS4R' names 'x1.' 1 time; 'Apply Corrections' will not rewrite it, because it is read-only: make it writable, then change it by hand ($t4door)"] \
          [t4_has $t4r "ase: $t4door opens the include files, to change the names above by hand."]] {1 1}
}
file attributes $NS4R -permissions 0644

## --- the press's file half: all or nothing ----------------------------------
set ar [pcall ase::include_apply_plan $PLAN]
eqcheck PF1723ac-OK-backs-each-editable-file-up-then-rewrites-it-and-never-opens-the-other \
  [list [dgn $ar ok] [dgn $ar n] [expr {[readbin $RWF] eq $RWWANT}] \
        [expr {[readbin $RWF.bak] eq $RWORIG}] [expr {[readfile $NSM] eq $NSMTXT}] \
        [file exists $NSM.bak]] {1 3 1 1 1 0}
eqcheck PF1723ac2-and-says-so-once-per-file-naming-the-backup \
  [pcall ase::include_apply_said $ar] \
  [list "ase: include file '$RWF' rewritten: 2 × x1. → xdut., 1 × X1. → xdut. The original is in '$RWF.bak'."]
## the undo the window's OK takes when its session half raises afterwards
set un [pcall ase::include_unapply $PLAN $ar]
eqcheck PF1723ac3-unapply-puts-every-written-file-back-and-drops-its-backup \
  [list $un [expr {[readbin $RWF] eq $RWORIG}] [file exists $RWF.bak] \
        [expr {[readfile $NSM] eq $NSMTXT}]] {{} 1 0 1}
## a file edited after the scan: refused, nothing written, no backup
writebin $RWF $RWORIG
catch {file delete $RWF.bak}
set PLAN2 [pcall ase::preflight_include_plan $STRW $SCRW $ITRW $RDI]
writebin $RWF "$RWORIG* edited\r\n"
set ar2 [pcall ase::include_apply_plan $PLAN2]
eqcheck PF1723ad-a-file-changed-since-the-check-is-refused-and-nothing-is-written \
  [list [dgn $ar2 ok] \
        [string match "'ns_rw.spice' changed after ASE-L checked it, so nothing was changed. Press Apply Corrections again*" [dgn $ar2 why]] \
        [expr {[readbin $RWF] eq "$RWORIG* edited\r\n"}] [file exists $RWF.bak]] {0 1 1 0}
## two editable files, the second made read-only after the plan: the first is
## put back and both backups go
writebin $RWF $RWORIG
set F2 [file normalize [file join $RDI ns_two.spice]]
putfile $F2 ".nodeset v(x1.tail)=0\n"
set st2f [ri_state [list [list file $RWF] [list file $F2]]]
set it2f [pcall ase::include_texts $st2f $RDI]
set sc2f [pcall ase::preflight_scan $st2f $NLR $it2f]
set PLAN3 [pcall ase::preflight_include_plan $st2f $sc2f $it2f $RDI]
file attributes $F2 -permissions 0444
if {[file writable $F2]} {
  puts "skip: PF1723ad2 (this user can write a 0444 file, so no write can be made to fail)"
} else {
  set ar3 [pcall ase::include_apply_plan $PLAN3]
  eqcheck PF1723ad2-a-write-that-fails-puts-back-every-file-and-drops-every-backup \
    [list [llength $PLAN3] [dgn $ar3 ok] \
          [string match "'ns_two.spice' could not be written*so every file was put back as it was and nothing was changed." [dgn $ar3 why]] \
          [expr {[readbin $RWF] eq $RWORIG}] [file exists $RWF.bak] [file exists $F2.bak] \
          [readfile $F2]] [list 2 0 1 1 0 0 ".nodeset v(x1.tail)=0\n"]
}
file attributes $F2 -permissions 0644

## --- the press's failure arms, driven by a write that fails AFTER its open ---
## (fix round, findings 5, 7 and 8). PF1723ad2's 0444 file fails at `open`,
## before anything is truncated; a full disk fails at `puts`/`close`, after
## `open w` has already truncated the file. `::ase::open` shadows the global
## `open` for the procs of the ase namespace only, so each leg routes the
## writes it names to /dev/full (every write: ENOSPC) and passes every other
## open through; it is deleted at the leg's foot.
proc fo_plan {texts} {
  set incs {}
  set ps {}
  set i 0
  foreach t $texts {
    set f [file normalize [file join $::RDI ns_fo[incr i].spice]]
    foreach b [glob -nocomplain $f.bak*] { file delete $b }
    writebin $f $t
    lappend incs [list file $f]
    lappend ps $f
  }
  set st [ri_state $incs]
  set it [pcall ase::include_texts $st $::RDI]
  set sc [pcall ase::preflight_scan $st $::NLR $it]
  return [list $ps [pcall ase::preflight_include_plan $st $sc $it $::RDI]]
}
if {![file writable /dev/full]} {
  puts "skip: PF1723ad3 PF1723ad4 (no /dev/full to make a write fail after its open)"
} else {
  set FOA ".nodeset v(x1.a1)=1\n"
  set FOB ".nodeset v(x1.tail)=0\n[string repeat "* padding past one channel buffer\n" 400]"
  ## B's write fails after the truncation; A's put-back succeeds (leg 1) or
  ## fails too (leg 2). A backup is deleted only when its file was put back:
  ## otherwise it is the only copy, and the sentence names it. B is larger than
  ## a channel buffer, so its writes fail at `puts` itself and a channel left
  ## open there shows in the riding count.
  foreach leg {1 2} {
    lassign [fo_plan [list $FOA $FOB]] fops foplan
    lassign $fops ::FOPA ::FOPB
    set ::fo_aw 0
    set ::fo_afail [expr {$leg == 2}]
    proc ::ase::open {args} {
      set p [lindex $args 0]
      set m [lindex $args 1]
      if {$m eq {w} && $p eq $::FOPB} {
        close [::open $p w]
        return [::open /dev/full w]
      }
      if {$m eq {w} && $p eq $::FOPA && [incr ::fo_aw] >= 2 && $::fo_afail} {
        return -code error "simulated EIO putting a back"
      }
      return [::open {*}$args]
    }
    set foch [llength [file channels]]
    set fo($leg) [pcall ase::include_apply_plan $foplan]
    rename ::ase::open {}
    set fo($leg,state) [list [llength $foplan] [dgn $fo($leg) ok] \
      [expr {[readbin $::FOPA] eq $FOA}] [file exists $::FOPA.bak] \
      [expr {[readbin $::FOPA.bak] eq $FOA}] \
      [file exists $::FOPB.bak] [expr {[readbin $::FOPB.bak] eq $FOB}] \
      [expr {[llength [file channels]] - $foch}]]
  }
  eqcheck PF1723ad3-a-file-that-cannot-be-put-back-keeps-its-backup-and-the-sentence-names-it \
    [list $fo(1,state) \
          [string match "'ns_fo2.spice' could not be written (*no space left on device*). These include files could not be put back, so their backups are kept as the only copy of what they held: 'ns_fo2.spice' (*; its original is in '$::FOPB.bak')." [dgn $fo(1) why]] \
          $fo(2,state) \
          [string match "*could not be put back, so their backups are kept*'ns_fo1.spice' (simulated EIO putting a back; its original is in '$::FOPA.bak'), 'ns_fo2.spice' (*; its original is in '$::FOPB.bak')." [dgn $fo(2) why]] \
          [string match {*every file was put back*} "[dgn $fo(1) why][dgn $fo(2) why]"]] \
    [list {2 0 1 0 0 1 1 0} 1 {2 0 0 1 1 1 1 0} 1 0]
  ## a BACKUP whose open succeeds and whose write then fails: removed, its
  ## channel closed, and "nothing was changed" is then true. A's text is larger
  ## than a channel buffer, so the failure is at `puts` itself (the leak) and
  ## not only at `close`.
  set FOBIG ".nodeset v(x1.a1)=1\n[string repeat "* padding past one channel buffer\n" 400]"
  lassign [fo_plan [list $FOBIG]] fops foplan
  set ::FOPA [lindex $fops 0]
  proc ::ase::open {args} {
    set p [lindex $args 0]
    if {[string match $::FOPA.bak* $p] && [string first CREAT [lindex $args 1]] >= 0} {
      close [::open {*}$args]
      return [::open /dev/full w]
    }
    return [::open {*}$args]
  }
  set foch [llength [file channels]]
  set fo4 [pcall ase::include_apply_plan $foplan]
  rename ::ase::open {}
  eqcheck PF1723ad4-a-backup-that-fails-after-its-open-is-removed-and-its-channel-closed \
    [list [dgn $fo4 ok] \
          [string match "the backup '$::FOPA.bak' could not be written (*), so nothing was changed." [dgn $fo4 why]] \
          [glob -nocomplain $::FOPA.bak*] [expr {[llength [file channels]] - $foch}] \
          [expr {[readbin $::FOPA] eq $FOBIG}]] \
    {0 1 {} 0 1}
}
## THE BACKUP KEEPS THE ORIGINAL'S MODE (fix round, finding 6): a private
## include (0640, 0600) must not get a world-readable `.bak` beside it.
lassign [fo_plan [list ".nodeset v(x1.a1)=1\n" ".nodeset v(x1.tail)=0\n"]] fops foplan
file attributes [lindex $fops 0] -permissions 0640
file attributes [lindex $fops 1] -permissions 0600
set fo5 [pcall ase::include_apply_plan $foplan]
eqcheck PF1723ac4-each-backup-has-its-originals-mode-and-the-rewritten-file-keeps-it \
  [list [dgn $fo5 ok] \
        [lmap f $fops {list [file attributes $f -permissions] [file attributes $f.bak -permissions]}]] \
  {1 {{00640 00640} {00600 00600}}}
foreach f $fops { catch {file attributes $f -permissions 0644} }

## --- the console command for the file half, beside the session one -----------
set RDF [file join $tmp run_1723f]
file mkdir $RDF
putfile [file join $RDF rn_top.spice] $NLR
set INCF2 [file normalize [file join $RDF ns_f.spice]]
set INCF2TXT ".nodeset v(x1.a1)=1 v(x1.tail)=0\n"
putfile $INCF2 $INCF2TXT
putfile [file join $RDF rn.state] \
  "design {lib dlib cell rn_top view schematic} rundir [list $RDF] models {} outputs [list {{expr v(x1.a1) save 1}}]\
 includes [list [list [list file $INCF2]]]"
pcall ase::session_open rnf [file join $RDF rn.state]
said_clear
set nfi [pcall ase::preflight_fix_includes rnf]
eqcheck PF1723af-fix-includes-rewrites-the-files-alone-and-leaves-the-session-as-it-was \
  [list $nfi [readfile $INCF2] [expr {[readfile $INCF2.bak] eq $INCF2TXT}] \
        [lmap o [dg [ase::session_state rnf] outputs] {dgn $o expr}] [pcall ase::session_dirty rnf] \
        [said_count "ase: include file '$INCF2' rewritten: 2 × x1. → xdut. The original is in '$INCF2.bak'."]] \
  [list 2 ".nodeset v(xdut.a1)=1 v(xdut.tail)=0\n" 1 v(x1.a1) 0 1]
lassign [rn_gate [ase::session_state rnf]] rcf1 ef1
set nfs [pcall ase::preflight_fix_session rnf]
lassign [rn_gate [ase::session_state rnf]] rcf2 ef2
eqcheck PF1723af2-then-the-session-command-fixes-the-outputs-and-the-gate-passes \
  [list $rcf1 [string match {ase: REFUSED — 1 output expression*} $ef1] $nfs $rcf2 \
        [pcall ase::preflight_fix_includes rnf]] {1 1 1 0 0}
pcall ase::session_close rnf
## THE FILE HALF ON A FILE IT MAY NOT EDIT SAYS SO, AND NEVER THAT THERE IS NO
## CORRECTION (fix round 2, findings 8 and 10). Its only stale include sits in a
## model file's folder: the command names the correction to make by hand, then
## used to add "no .nodeset/.ic name in them has a correction to offer", which
## the line before it had just contradicted.
set RDF3 [file join $tmp run_1723f3]
set MODF3 [file normalize [file join $RDF3 models]]
file mkdir $MODF3
putfile [file join $RDF3 rn_top.spice] $NLR
putfile [file join $MODF3 fx.lib] "* models\n"
set INCF3 [file join $MODF3 ns_f3.spice]
set INCF3TXT ".nodeset v(x1.a1)=1 v(x1.tail)=0\n"
putfile $INCF3 $INCF3TXT
putfile [file join $RDF3 rn.state] \
  "design {lib dlib cell rn_top view schematic} rundir [list $RDF3]\
 models [list [list [list file [file join $MODF3 fx.lib] section {}]]]\
 outputs [list {{expr v(OUT) save 1}}] includes [list [list [list file $INCF3]]]"
pcall ase::session_open rnf3 [file join $RDF3 rn.state]
said_clear
set nf3 [pcall ase::preflight_fix_includes rnf3]
eqcheck PF1723af3-fix-includes-on-a-file-it-may-not-edit-names-the-correction-and-never-says-there-is-none \
  [list $nf3 \
        [said_count "ase: include file '$INCF3' is not edited: it is in a model file's folder ($MODF3). Change 2 × x1. → xdut. there by hand ([pcall ase::ui::menu_path_include_files])."] \
        [said_count {*no .nodeset/.ic name in them has a correction*}] \
        [said_count "ase: pre-flight — nothing was rewritten in the include files of session 'rnf3': the 2 .nodeset/.ic names with a correction are in 1 include file ASE-L may not edit, named above."] \
        [expr {[readfile $INCF3] eq $INCF3TXT}] [file exists $INCF3.bak]] {0 1 0 1 1 0}
pcall ase::session_close rnf3

## --- item 5's pure halves: the rows, Add, Remove -----------------------------
set ::PF1723DIR $RDI
set sti5 [ri_state [list {file ns_a.spice} {file {$::PF1723DIR/ns_b.spice}} {file nosuch.spice} \
                         {file {$::NOSUCHVAR1723/x.spice}}]]
set rows5 [pcall ase::include_rows $sti5 $RDI]
eqcheck PF1723ag-the-rows-say-as-stored-where-it-resolves-and-whether-it-exists \
  [lmap r $rows5 {list [dgn $r stored] [dgn $r path] [dgn $r exists] [expr {[dgn $r why] ne {}}]}] \
  [list [list ns_a.spice $NSA 1 0] [list {$::PF1723DIR/ns_b.spice} $NSB 1 0] \
        [list nosuch.spice [file join [file normalize $RDI] nosuch.spice] 0 0] \
        [list {$::NOSUCHVAR1723/x.spice} {} 0 1]]
set sta5 [pcall ase::include_add $sti5 "  \$::PF1723DIR/new.spice "]
set str5 [pcall ase::include_remove $sta5 {0 2 99 x}]
eqcheck PF1723ag2-add-keeps-the-portable-path-as-typed-and-remove-takes-the-rows-named \
  [list [lindex [pcall ase::state_get $sta5 includes] end] [pcall ase::include_add $sti5 {   }] \
        [lmap i [pcall ase::state_get $str5 includes] {pcall ase::include_entry_file $i}]] \
  [list {file {$::PF1723DIR/new.spice}} {ERR:a path is needed} {{$::PF1723DIR/ns_b.spice} {$::NOSUCHVAR1723/x.spice} {$::PF1723DIR/new.spice}}]
## THE FOLDER SHOWN IS ONLY PEEKED. ⚠ REWRITTEN in fix round 2 (finding 11):
## the old legs used a run directory that existed and a ::netlist_dir that
## existed, so a peek that called ase::rundir -- which CREATES the first, and
## for an empty `rundir` runs set_netlist_dir 0, which creates the second --
## answered the same paths and stayed green. Now both folders are missing
## before the peek and must still be missing after it, and ::netlist_dir must
## not have moved.
set nd_had [info exists ::netlist_dir]
if {$nd_had} { set nd_saved $::netlist_dir }
set RDNX [file join $tmp run_1723_peek_nx]
set NDNX [file join $tmp netlist_dir_peek_nx]
set ::netlist_dir $NDNX
set pk1 [pcall ase::include_rundir_peek [dict replace $sti5 rundir $RDNX]]
set pk2 [pcall ase::include_rundir_peek [dict replace $sti5 rundir {}]]
set pkleg [list [expr {$pk1 eq [file normalize $RDNX]}] [file exists $RDNX] \
               [expr {$::netlist_dir eq $NDNX}] [file exists $NDNX] \
               [expr {$pk2 eq [pcall ase::rundir_default_preview]}]]
if {$nd_had} { set ::netlist_dir $nd_saved } else { unset ::netlist_dir }
eqcheck PF1723ag3-the-folder-shown-is-only-peeked-a-missing-run-directory-and-netlist-dir-stay-missing-and-netlist-dir-unmoved \
  [list [pcall ase::include_rundir_peek $sti5] $pkleg] [list [file normalize $RDI] {1 0 1 0 1}]
## THE TEXT WINDOW'S SAVE ASKS BEFORE IT WRITES OVER A FILE THAT CHANGED SINCE
## IT READ IT (fix round 2, finding 13): Apply Corrections rewrote the file an
## open Include Files… window was showing, and that window's Save then put the
## stale text back with no word -- the backup holding the same stale text. The
## decision is textwindow_disk_changed (src/xschem.tcl), against what the
## window read: unchanged, changed, deleted, and a file that did not exist then
## and does not now, or does now. The press is test_ase_window.tcl's FX1723Ih.
set TWF [file join $tmp tw_changed.txt]
putfile $TWF "abc\n"
set twd0 [pcall textwindow_disk_changed $TWF [list 1 "abc\n"]]
putfile $TWF "abd\n"
set twd1 [pcall textwindow_disk_changed $TWF [list 1 "abc\n"]]
file delete $TWF
set twd2 [pcall textwindow_disk_changed $TWF [list 1 "abc\n"]]
set twd3 [pcall textwindow_disk_changed $TWF [list 0 {}]]
putfile $TWF "new\n"
set twd4 [pcall textwindow_disk_changed $TWF [list 0 {}]]
eqcheck PF1723ai-the-text-windows-save-sees-a-file-that-changed-since-it-read-it \
  [list $twd0 $twd1 $twd2 $twd3 $twd4] {0 1 1 0 1}

## === FIX ROUND 3 (2026-11-21): the third review's confirmed findings =======
## Each row was written first and watched red on the fix-round-2 code. The
## shapes were MEASURED 2026-11-21 on /usr/bin/ngspice 45.2 and on the fork
## (ver_53), with the flags ASE-L passes, on a deck holding `xdut` and no `x1`;
## the table is the issue file's.
##
## FINDING 1: ngspice's readline() DROPS A LINE'S LEADING BLANKS AND TABS
## before any pass sees it, so `  ; note` reaches the comment stripper as
## `; note`, whose `;` at column 0 is never cut: a regular card, which ends the
## `.nodeset` card and swallows the `+` line after it (inp_check_syntax later
## makes it a `*` comment). Measured: `  ; note`, a tab before it, ` ;note`:
## rc 0, no warning; `  * note` in its place: the warning, then the syntax
## error. And an indented `* note \\` or `$ note \\` continues nothing, because
## its column 0 is `*` or `$` once the blanks are gone (measured: the next line,
## an element card, is not joined; a real `\\` joins it, rc 1).
set r9 {}
foreach mid [list "  ; note" "\t; note" " ;note" "; note" "  * note"] {
  lappend r9 [lmap c [pcall ase::include_card_idents ".nodeset v(b)=0.3\n$mid\n+ v(x1.r)={2}\n"] {dgn $c ident}]
}
eqcheck PF1723r9-an-indented-semicolon-line-ends-the-card-because-ngspice-drops-its-leading-blanks-first \
  $r9 {b b b b {b x1.r}}
set r10 {}
foreach mid [list "  * note \\\\" "  \$ note \\\\" "\t* note \\\\"] {
  lappend r10 [lmap c [pcall ase::include_card_idents ".nodeset v(b)=0.3\n$mid\nv(x1.r)={2}\n"] {dgn $c ident}]
}
lappend r10 [lmap c [pcall ase::include_card_idents ".nodeset v(b)=0.3 \\\\\nv(x1.r)={2}\n"] {dgn $c ident}]
eqcheck PF1723r10-an-indented-star-or-dollar-line-ending-in-a-double-backslash-continues-nothing \
  $r10 {b b b {b x1.r}}
eqcheck PF1723r11-a-semicolon-led-line-at-column-0-or-indented-adds-no-element-word \
  [list [dex [pcall ase::include_top_words [list [dict create text "; x5 was the dut\nR1 p q 1k\n"]]] x5] \
        [dex [pcall ase::include_top_words [list [dict create text "  ; x5 was the dut\nR1 p q 1k\n"]]] x5] \
        [dex [pcall ase::include_top_words [list [dict create text "  ; x5 was the dut\nR1 p q 1k\n"]]] r1]] \
  {0 0 1}
## the finding's own bench: the gate let it through and Apply had a name to
## rewrite in a card ngspice reads as a comment
set NSSEMI [file normalize [file join $RDI ns_semi.spice]]
putfile $NSSEMI ".nodeset v(OUT)=0.3\n  ; x1 was the dut before the rename\n+ v(x1.a1)={2}\n"
set stsemi [ri_state [list [list file $NSSEMI]]]
set scsemi [pcall ase::preflight_scan $stsemi $NLR [pcall ase::include_texts $stsemi $RDI]]
lassign [rn_gate $stsemi] rcsemi esemi
eqcheck PF1723s11-the-name-behind-an-indented-semicolon-line-is-neither-refused-nor-offered-for-rewriting \
  [list [llength [dg $scsemi incrows]] [llength [dg $scsemi renames]] \
        [llength [pcall ase::preflight_include_edits $scsemi]] $rcsemi [said_count {ase: REFUSED*}]] \
  {0 0 0 0 0}
## FINDING 5: A UTF-8 BYTE ORDER MARK. The fork's inp_read strips EF BB BF from
## a file's first line (measured: ver_53 says "encoding: UTF-8 with BOM", then
## the warning and the syntax error on a stale `{2}`, rc 1; 45.2 dies on
## "unknown device type", rc 1, so a refusal is right on both). The reader
## strips it too, and keeps every offset the file's own.
set BOMT "\xef\xbb\xbf.nodeset v(b)=0.3 v(x1.r)={2}\n"
set bomc [pcall ase::include_card_idents $BOMT]
set NSBOM [file normalize [file join $RDI ns_bom.spice]]
writebin $NSBOM "\xef\xbb\xbf.nodeset v(OUT)=0.3 v(x1.a1)={2}\n"
lassign [rn_gate [ri_state [list [list file $NSBOM]]]] rcbom ebom
eqcheck PF1723r12-a-utf8-byte-order-mark-before-a-first-line-card-is-stripped-as-the-fork-strips-it \
  [list [lmap c $bomc {list [dgn $c line] [dgn $c ident]}] \
        [lmap c $bomc {expr {[string range $BOMT [dgn $c start] [dgn $c end]] eq [dgn $c ident]}}] \
        [lmap c [pcall ase::include_card_idents "\xef\xbb\xbf* hdr\n.nodeset v(x1.r)={2}\n"] {dgn $c ident}] \
        $rcbom [said_count "ase:   include file '$NSBOM' line 1: .nodeset names 'x1.a1'*'x1.a1' -> 'xdut.a1'"]] \
  {{{1 b} {1 x1.r}} {1 1} x1.r 1 1}
## FINDING 2: `.nodeset all=<v>` ENDS WHAT NGSPICE READS OF ITS CARD. INPpas3's
## `all` branch sets every node and BREAKS out of the card's token loop, so no
## name after it -- on that line or a `+` line -- is read. Measured:
## `.nodeset all=0.5 v(x1.q)={vsup}` and the same with the name on a `+` line,
## rc 0 and no warning; the name alone, the syntax error. `.ic` has no `all`
## branch (`.ic all=0.5` is itself a syntax error, rc 1), so it is unchanged. A
## node or a value that is called `all` is not the keyword, and a later card is
## read as ever.
set r13 {}
foreach t [list ".nodeset all=0.5 v(x1.q)={vsup}\n" \
                ".nodeset all=0.5\n+ v(x1.q)={vsup} v(xdut.q)=0.2\n" \
                ".nodeset v(x1.a)=1 ALL = 0.5 v(x1.b)=2\n" \
                ".ic all=0.5 v(x1.q)=1\n" \
                ".nodeset v(all)=1 v(a)={all} v(x1.q)=2\n.nodeset all=0.5\n.nodeset v(x1.z)=1\n"] {
  lappend r13 [lmap c [pcall ase::include_card_idents $t] {dgn $c ident}]
}
eqcheck PF1723r13-nodeset-all-ends-what-ngspice-reads-of-its-card-continuations-included \
  $r13 {{} {} x1.a x1.q {all a x1.q x1.z}}
set NSALL [file normalize [file join $RDI ns_all.spice]]
putfile $NSALL ".nodeset all=0.5 v(x1.a1)={2}\n+ v(x1.tail)={vsup}\n"
set stall [ri_state [list [list file $NSALL]]]
set scall [pcall ase::preflight_scan $stall $NLR [pcall ase::include_texts $stall $RDI]]
lassign [rn_gate $stall] rcall eall
eqcheck PF1723s12-names-after-nodeset-all-are-neither-refused-nor-offered-for-rewriting \
  [list [llength [dg $scall incrows]] [llength [pcall ase::preflight_include_edits $scall]] \
        $rcall [said_count {ase: REFUSED*}]] {0 0 0 0}
## FINDING 4: A VALUE ON THE NEXT `+` LINE IS THE NAME'S VALUE. ngspice joins
## the card before INPpas3 reads it (measured: `v(xdut.nosuch)=` then `+ 1.5`,
## and `v(xdut.nosuch)` then `+ =1.5`: the warning naming the joined
## `v(xdut.nosuch)=1.5`, rc 0), so the caution must say the name is dropped,
## not that the run stops.
set r14 {}
foreach t [list ".nodeset v(b)=0.3 v(xdut.nosuch)=\n+ 1.5\n" ".nodeset v(b)=0.3 v(xdut.nosuch)\n+ =1.5\n" \
                ".nodeset v(xdut.nosuch)=\n\n* a note\n+ {vsup}\n"] {
  lappend r14 [lmap c [pcall ase::include_card_idents $t] {list [dgn $c line] [dgn $c ident] [dgn $c value]}]
}
set NSVAL [file normalize [file join $RDI ns_val.spice]]
putfile $NSVAL ".nodeset v(OUT)=0.3 v(xdut.nosuch)=\n+ 1.5\n"
lassign [rn_gate [ri_state [list [list file $NSVAL]]]] rcval eval
eqcheck PF1723r14-a-value-on-the-next-continuation-line-is-the-names-value-as-ngspice-joins-it \
  [list {*}$r14 $rcval \
        [said_count "ase: caution: include file '$NSVAL' line 1: .nodeset names 'xdut.nosuch', which instance 'xdut' does not have; ngspice drops it with a 'non-existent node' warning, so that guess is lost."] \
        [said_count {*this one has none*}]] \
  [list {{1 b 0.3} {1 xdut.nosuch 1.5}} {{1 b 0.3} {1 xdut.nosuch 1.5}} [list [list 1 xdut.nosuch "{vsup}"]] 0 1 0]
## FINDING 6: A CARD INSIDE A `.if` BLOCK. ngspice evaluates the condition and
## comments out the branches not taken (inp.c recifeval), which ASE-L cannot
## do: a stale-looking name in a branch not taken refused a bench that runs
## (measured: `.if (sel == 1)` with sel=0, rc 0, no warning; sel=1, the syntax
## error), and Apply offered to rewrite the other variant's own nodeset. A card
## inside any `.if` ... `.endif` is marked `cond`; its names neither refuse,
## nor join the rename search, nor are rewritten; each absent one is a caution.
set IFT ".if (sel == 1)\n.nodeset v(xalt.a1)={vs-0.1}\n.ELSEIF(sel==2)\n.if (deep)\n.endif\n.nodeset v(x1.p)=1\n.else\n.nodeset v(xdut.a1)={vs-0.1}\n.endif\n.nodeset v(x9.q)=1\n"
eqcheck PF1723r15-a-card-inside-an-if-block-is-marked-conditional-nested-blocks-included \
  [lmap c [pcall ase::include_card_idents $IFT] {list [dgn $c line] [dgn $c ident] [dgn $c cond]}] \
  {{2 xalt.a1 1} {6 x1.p 1} {8 xdut.a1 1} {10 x9.q 0}}
set NSIF [file normalize [file join $RDI ns_if.spice]]
putfile $NSIF ".if (sel == 1)\n.nodeset v(xalt.a1)={vs-0.1}\n.else\n.nodeset v(xdut.a1)={vs-0.1}\n.endif\n"
set stif [ri_state [list [list file $NSIF]]]
set scif [pcall ase::preflight_scan $stif $NLR [pcall ase::include_texts $stif $RDI]]
lassign [rn_gate $stif] rcif eif
eqcheck PF1723s13-a-stale-looking-name-in-a-if-branch-is-one-caution-never-a-refusal-or-a-rewrite \
  [list $rcif [said_count {ase: REFUSED*}] [llength [dg $scif renames]] \
        [llength [pcall ase::preflight_include_edits $scif]] \
        [said_count "ase: caution: include file '$NSIF' line 2: .nodeset names 'xalt.a1' inside a .if block, which ASE-L does not evaluate, and the netlist has no instance 'xalt': if that branch is taken, ngspice stops the run with '.nodeset syntax error', because such a name's value must be a plain number and this one is '{vs-0.1}'."] \
        [said_count {ase: caution:*}]] {0 0 0 0 1 1}
## FINDING 9: UNDER `fold`, THE PER-FILE LINE QUOTES THE FILE'S OWN SPELLING AND
## ITS OWN TARGET. `X1` (an output, `several`) and `x1` (the include, `unique`)
## are two rename records; the hit line took the first record's spelling and
## its empty target: "names 'X1.' 1 time, ... rewrites them to '.'".
set NSF9 [file normalize [file join $RDI ns_fold9.spice]]
putfile $NSF9 ".nodeset v(x1.a1)=1\n"
lassign [rn_gate [ri_state [list [list file $NSF9]] {{expr v(X1.n1) save 1}}]] rcf9 ef9
eqcheck PF1723t7-under-fold-the-per-file-line-quotes-the-files-own-spelling-and-its-own-target \
  [list $rcf9 \
        [said_count "ase:   include file '$NSF9' names 'x1.' 1 time, all in .nodeset/.ic cards: '[pcall ase::ui::lbl_repair_apply]' rewrites them to 'xdut.' after asking"] \
        [said_count "*rewrites them to '.'*"] [said_count "*names 'X1.'*"]] {1 1 0 0}
## ...and two spellings with DIFFERENT targets are a line each, each counting
## only the names its own target rewrites: `x1.a1` (xdut) in a card and once in
## a comment, `X1.b1` (xother) in a card.
set NSF8 [file normalize [file join $RDI ns_fold8.spice]]
putfile $NSF8 ".nodeset v(x1.a1)=1 v(X1.b1)=2
* x1.tail was the old guess
"
lassign [rn_gate [ri_state [list [list file $NSF8]]]] rcf8 ef8
set lab8 [pcall ase::ui::lbl_repair_apply]
eqcheck PF1723t8-under-fold-two-spellings-with-different-targets-are-a-line-each-counting-their-own-names \
  [list $rcf8 \
        [said_count "ase:   include file '$NSF8' names 'x1.' 2 times; '$lab8' rewrites the 1 in .nodeset/.ic cards to 'xdut.' after asking and leaves the other 1 for you to change ([pcall ase::ui::menu_path_include_files])"] \
        [said_count "ase:   include file '$NSF8' names 'X1.' 1 time, all in .nodeset/.ic cards: '$lab8' rewrites them to 'xother.' after asking"]] \
  {1 1 1}
## FINDING 7: A SYMLINKED MODEL FILE PROTECTS THE FOLDER IT REALLY LIVES IN.
## `file normalize` resolves every component but the last, so a models entry
## that is itself a link protected only the link's folder, and a file beside
## the real model file was editable.
set SLD [file normalize [file join $tmp sym1723]]
file mkdir [file join $SLD pdk models] [file join $SLD proj models]
putfile [file join $SLD pdk models real.lib] "* real models\n"
putfile [file join $SLD pdk models nodeset.spice] ".nodeset v(x1.a1)=1\n"
if {[catch {file link -symbolic [file join $SLD proj models m.lib] [file join $SLD pdk models real.lib]} slerr]} {
  puts "skip: PF1723y5 (no symbolic link could be made: $slerr)"
} else {
  set stsl [ri_state {}]
  dict set stsl models [list [list file [file join $SLD proj models m.lib] section tt]]
  set rsl [pcall ase::include_protected_roots $stsl $RDI]
  set nsl [file join $SLD pdk models nodeset.spice]
  eqcheck PF1723y5-a-symlinked-model-file-protects-the-folder-it-really-lives-in-too \
    [list [lsort [lmap r $rsl {dgn $r dir}]] \
          [pcall ase::include_edit_verdict $nsl [pcall ase::include_edit_facts $nsl] $rsl]] \
    [list [lsort [list [file join $SLD pdk models] [file join $SLD proj models]]] \
          "it is in a model file's folder ([file join $SLD pdk models])"]
}
## FINDINGS 3 AND 8: THE TWO CONSOLE HALVES MUST NOT DEPEND ON THEIR ORDER.
## Output rows and include rows decide one rename together; each half re-scans,
## and once one half is applied its rows no longer decide. Bench B: the output
## `v(x1.OUTP)` alone fits xdut AND xother (both have OUTP); the include's
## `x1.a1` makes it unique. Bench A is the reverse. So the file half applied
## first strands B's outputs, and the session half applied first strands A's
## include names. `ase::preflight_fix_all <key>` applies both from ONE scan,
## as the window's OK does; the file half refuses to strand the session half;
## the session half writes exactly what it always wrote (the ruling) and names
## every include correction it costs, with fix_all.
proc strand_bench {name outs inctxt} {
  set d [file join $::tmp run_1723_$name]
  file mkdir $d
  putfile [file join $d rn_top.spice] $::NLR
  set inc [file normalize [file join $d ns.spice]]
  putfile $inc $inctxt
  putfile [file join $d rn.state] \
    "design {lib dlib cell rn_top view schematic} rundir [list $d] models {} outputs [list $outs]\
 includes [list [list [list file $inc]]]"
  pcall ase::session_open $name [file join $d rn.state]
  return $inc
}
set SBTXT ".nodeset v(x1.a1)=1\n"
set SATXT ".nodeset v(x1.OUTP)=1\n"
set incB [strand_bench sbB {{expr v(x1.OUTP) save 1}} $SBTXT]
set incA [strand_bench sbA {{expr v(x1.a1) save 1}} $SATXT]
set scB [pcall ase::preflight_session_scan sbB]
set scA [pcall ase::preflight_session_scan sbA]
eqcheck PF1723aj-the-strand-check-sees-which-half-applied-alone-loses-the-others-correction \
  [list [lmap g [dg $scB renames] {list [dgn $g prefix] [dgn $g to] [dgn $g fit]}] \
        [llength [dgn [pcall ase::preflight_strand [ase::session_state sbB] $scB files] lost]] \
        [llength [dgn [pcall ase::preflight_strand [ase::session_state sbB] $scB session] lost]] \
        [lmap g [dg $scA renames] {list [dgn $g prefix] [dgn $g to] [dgn $g fit]}] \
        [llength [dgn [pcall ase::preflight_strand [ase::session_state sbA] $scA files] lost]] \
        [llength [dgn [pcall ase::preflight_strand [ase::session_state sbA] $scA session] lost]]] \
  {{{x1 xdut unique}} 1 0 {{x1 xdut unique}} 0 1}
said_clear
set njB [pcall ase::preflight_fix_includes sbB]
eqcheck PF1723aj2-the-file-half-refuses-to-strand-the-session-half-and-names-fix-all \
  [list $njB [expr {[readfile $incB] eq $SBTXT}] [file exists $incB.bak] \
        [lmap o [dg [ase::session_state sbB] outputs] {dgn $o expr}] \
        [said_count "ase: pre-flight — nothing was rewritten in the include files of session 'sbB': applied alone, they would cost this session's output rows their correction ('v(x1.OUTP)' -> 'v(xdut.OUTP)'), which only the two halves together decide. `ase::preflight_fix_all sbB` applies both from one scan, as '[pcall ase::ui::lbl_repair_apply]' does."]] \
  {0 1 0 v(x1.OUTP) 1}
said_clear
set nallB [pcall ase::preflight_fix_all sbB]
lassign [rn_gate [ase::session_state sbB]] rcallB eallB
eqcheck PF1723aj3-fix-all-applies-both-halves-from-one-scan-and-the-gate-passes \
  [list $nallB [readfile $incB] [expr {[readfile $incB.bak] eq $SBTXT}] \
        [lmap o [dg [ase::session_state sbB] outputs] {dgn $o expr}] [pcall ase::session_dirty sbB] $rcallB] \
  [list 2 ".nodeset v(xdut.a1)=1\n" 1 v(xdut.OUTP) 1 0]
said_clear
set nsA [pcall ase::preflight_fix_session sbA]
eqcheck PF1723aj4-the-session-half-writes-what-it-always-wrote-and-names-every-include-correction-it-costs \
  [list $nsA [lmap o [dg [ase::session_state sbA] outputs] {dgn $o expr}] [expr {[readfile $incA] eq $SATXT}] \
        [said_count "ase: pre-flight — note: the include files' .nodeset/.ic names below lose their correction now, because with this session's output rows corrected they no longer decide 'x1' -> 'xdut' on their own; change them by hand ([pcall ase::ui::menu_path_include_files]). Next time `ase::preflight_fix_all sbA` applies both halves from one scan."] \
        [said_count "ase:   include file '$incA' line 1: 'x1.OUTP' -> 'xdut.OUTP'"]] \
  {1 v(xdut.a1) 1 1 1}
pcall ase::session_close sbA
pcall ase::session_close sbB
file delete -force [file join $tmp run_1723_sbA]
set incA [strand_bench sbA {{expr v(x1.a1) save 1}} $SATXT]
said_clear
set nallA [pcall ase::preflight_fix_all sbA]
lassign [rn_gate [ase::session_state sbA]] rcallA eallA
eqcheck PF1723aj5-fix-all-on-the-reverse-bench-too \
  [list $nallA [readfile $incA] [lmap o [dg [ase::session_state sbA] outputs] {dgn $o expr}] $rcallA] \
  [list 2 ".nodeset v(xdut.OUTP)=1\n" v(xdut.a1) 0]
pcall ase::session_close sbA
## the refusal names fix_all when both halves have corrections, and keeps the
## file half's own sentence when only the files do (PF1723t3)
file delete -force [file join $tmp run_1723_sbB]
set incB [strand_bench sbB {{expr v(x1.OUTP) save 1}} $SBTXT]
lassign [rn_gate [ase::session_state sbB]] rct6 et6
eqcheck PF1723t6-a-refusal-with-both-halves-names-fix-all-first \
  [list $rct6 [said_count "ase: '[pcall ase::ui::lbl_repair_apply]' also rewrites the 1 .nodeset/.ic name above in 1 include file, after asking: each file is backed up beside itself first and written at once, not at Save State. `ase::preflight_fix_all <key>` does both halves from the console from one scan, as the button does; `ase::preflight_fix_session <key>` and `ase::preflight_fix_includes <key>` are each half alone. [pcall ase::ui::menu_path_include_files] shows the files."]] \
  {1 1}
pcall ase::session_close sbB
## FIX ROUND 4, FINDING 1: A DECIDING INCLUDE ROW IN A FILE ASE-L MAY NOT EDIT.
## Bench A with its include read-only. The window's press finds no editable
## plan record and takes the session-only arm (ase::preflight_fix_session), and
## ase::preflight_fix_all skips the file as the press does: neither keeps that
## row's correction. The note sent the user to fix_all ("Next time ... applies
## both halves"), and named the door with no "make it writable, then", though
## the door opens a read-only file without Save.
set RO4 [file join $tmp ro4_probe.spice]
putfile $RO4 "* probe\n"
file attributes $RO4 -permissions 0444
set ro4_measurable [expr {![file writable $RO4]}]
file attributes $RO4 -permissions 0644
if {!$ro4_measurable} {
  puts "skip: PF1723aj6 PF1723aj7 PF1723aj8 (this user can write a 0444 file, so no include is read-only)"
} else {
  set DOOR4 [pcall ase::ui::menu_path_include_files]
  file delete -force [file join $tmp run_1723_sbA]
  set incA [strand_bench sbA {{expr v(x1.a1) save 1}} $SATXT]
  file attributes $incA -permissions 0444
  set scRO [pcall ase::preflight_session_scan sbA]
  set plRO [pcall ase::preflight_include_plan [ase::session_state sbA] $scRO [dg $scRO itexts] [dg $scRO rundir]]
  said_clear
  set nsRO [pcall ase::preflight_fix_session sbA]
  eqcheck PF1723aj6-the-session-half-on-a-read-only-include-names-no-fix-all-and-says-make-it-writable \
    [list [lmap f $plRO {list [dgn $f editable] [dgn $f writable] [dgn $f n]}] \
          $nsRO [lmap o [dg [ase::session_state sbA] outputs] {dgn $o expr}] [expr {[readfile $incA] eq $SATXT}] \
          [said_count "ase: pre-flight — note: the include files' .nodeset/.ic names below lose their correction now, because with this session's output rows corrected they no longer decide 'x1' -> 'xdut' on their own. `ase::preflight_fix_all sbA` would not have kept them either: ASE-L may not edit the include file they are in, so change them by hand as the line below says."] \
          [said_count "ase:   include file '$incA' line 1: 'x1.OUTP' -> 'xdut.OUTP'; ASE-L may not edit it, because it is read-only: make it writable, then change it by hand ($DOOR4)."] \
          [said_count {*Next time*}]] \
    {{{0 0 1}} 1 v(xdut.a1) 1 1 1 0}
  pcall ase::session_close sbA
  ## ...and fix_all on the same fresh bench costs the include the same correction:
  ## it may not write the file. It says what to change there (the blocked line,
  ## unchanged) and now also that the pre-flight will not offer it again.
  file delete -force [file join $tmp run_1723_sbA]
  set incA [strand_bench sbA {{expr v(x1.a1) save 1}} $SATXT]
  file attributes $incA -permissions 0444
  said_clear
  set naRO [pcall ase::preflight_fix_all sbA]
  set rsRO [pcall ase::preflight_session_scan sbA]
  eqcheck PF1723aj7-fix-all-on-a-read-only-include-says-the-correction-the-pre-flight-will-not-offer-again \
    [list $naRO [expr {[readfile $incA] eq $SATXT}] [file exists $incA.bak] \
          [lmap o [dg [ase::session_state sbA] outputs] {dgn $o expr}] \
          [llength [pcall ase::preflight_include_edits $rsRO]] \
          [said_count "ase: include file '$incA' is not edited: it is read-only. Make it writable, then change 1 × x1. → xdut. there by hand ($DOOR4)."] \
          [said_count "ase: pre-flight — note: the include files' .nodeset/.ic names below were not rewritten, because ASE-L may not edit the include file they are in, and with this session's output rows corrected they no longer decide 'x1' -> 'xdut' on their own, so the pre-flight will not offer them again; change them by hand as the line below says."] \
          [said_count "ase:   include file '$incA' line 1: 'x1.OUTP' -> 'xdut.OUTP'; ASE-L may not edit it, because it is read-only: make it writable, then change it by hand ($DOOR4)."] \
          [said_count {*fix_all*}]] \
    {1 1 0 v(xdut.a1) 0 1 1 1 0}
  pcall ase::session_close sbA
  ## ...and the window's OK on a MIXED plan: ns_e.spice (editable, `x1.a1`) and
  ## ns_r.spice (read-only, `x1.OUTP`). Before the press the three rows decide
  ## xdut together, so the session half alone strands nothing; but OK writes
  ## ns_e.spice AND corrects the session, after which ns_r.spice's `x1.OUTP` fits
  ## xdut and xother: lost, silently. The strand check's `both` half sees it, the
  ## confirmation says so before OK (ase::ui::repair_confirm_text, what the
  ## dialog shows), and ase::preflight_commit_both after it.
  proc strand_bench2 {name outs incs} {
    set d [file join $::tmp run_1723_$name]
    file mkdir $d
    putfile [file join $d rn_top.spice] $::NLR
    set paths {}
    set ents {}
    foreach {fn txt} $incs {
      set p [file normalize [file join $d $fn]]
      putfile $p $txt
      lappend paths $p
      lappend ents [list file $p]
    }
    putfile [file join $d rn.state] \
      "design {lib dlib cell rn_top view schematic} rundir [list $d] models {} outputs [list $outs]\
   includes [list $ents]"
    pcall ase::session_open $name [file join $d rn.state]
    return $paths
  }
  set SETXT ".nodeset v(x1.a1)=1\n"
  lassign [strand_bench2 sbM {{expr v(x1.a1) save 1}} [list ns_e.spice $SETXT ns_r.spice $SATXT]] incME incMR
  file attributes $incMR -permissions 0444
  set stM [ase::session_state sbM]
  set scM [pcall ase::preflight_session_scan sbM]
  set plM [pcall ase::preflight_include_plan $stM $scM [dg $scM itexts] [dg $scM rundir]]
  set lostM [dgn [pcall ase::preflight_strand $stM $scM both $plM] lost]
  set confM [pcall ase::ui::repair_confirm_text sbM $scM $plM]
  said_clear
  set cM [pcall ase::preflight_commit_both sbM $scM $plM]
  eqcheck PF1723aj8-the-press-on-a-mixed-plan-says-before-and-after-ok-what-the-read-only-file-loses \
    [list [lmap f $plM {list [file tail [dgn $f path]] [dgn $f editable] [dgn $f n]}] \
          [llength [dgn [pcall ase::preflight_strand $stM $scM session] lost]] \
          [lmap x $lostM {list [file tail [dgn $x path]] [dgn $x ident] [dgn $x fixed]}] \
          [lsearch -exact $confM "  ns_r.spice: not editable, because it is read-only; left as it is."] \
          [lsearch -exact $confM "    With this session corrected, the pre-flight no longer offers this correction here, so after OK make it writable, then change it by hand ($DOOR4): line 1 'x1.OUTP' -> 'xdut.OUTP'. Cancel keeps it offered."] \
          [dgn $cM ok] [dgn $cM files] [dgn $cM rows] [readfile $incME] [expr {[readfile $incMR] eq $SATXT}] \
          [lmap o [dg [ase::session_state sbM] outputs] {dgn $o expr}] \
          [said_count "ase: pre-flight — note: the include files' .nodeset/.ic names below were not rewritten, because ASE-L may not edit the include file they are in, and with this session's output rows corrected they no longer decide 'x1' -> 'xdut' on their own, so the pre-flight will not offer them again; change them by hand as the line below says."] \
          [said_count "ase:   include file '$incMR' line 1: 'x1.OUTP' -> 'xdut.OUTP'; ASE-L may not edit it, because it is read-only: make it writable, then change it by hand ($DOOR4)."]] \
    [list {{ns_e.spice 1 1} {ns_r.spice 0 1}} 0 {{ns_r.spice x1.OUTP xdut.OUTP}} 2 3 \
          1 1 1 ".nodeset v(xdut.a1)=1\n" 1 v(xdut.a1) 1 1]
  pcall ase::session_close sbM
  foreach p [list $incA $incMR] { catch {file attributes $p -permissions 0644} }
}
## FINDING 10: A SHARED INCLUDE FILE. The user's own tree has one nodeset file
## in the includes of seven states across three benches; rewriting it for one
## bench changes what every other bench reads, and the confirmation said
## nothing. ase::include_sharers names the other states of the same library
## whose includes resolve to the same file, by any spelling; the confirmation
## names them.
set SHL [file normalize [file join $tmp shlib1723 libx]]
foreach cv {bench_a/ngspice_state1 bench_b/ngspice_state1 bench_b/ngspice_state2 bench_c/ngspice_state1} {
  file mkdir [file join $SHL $cv]
}
set SHINC [file join $SHL bench_a includes ns.spice]
file mkdir [file dirname $SHINC]
putfile $SHINC ".nodeset v(x1.a1)=1\n"
putfile [file join $SHL bench_a other.spice] "* other\n"
set ::PF1723SHL $SHL
proc shstate {cell incs} {
  return "design {lib libx cell $cell view schematic} rundir [list [file join $::tmp run_sh_$cell]] includes [list $incs]"
}
set SHA [file join $SHL bench_a ngspice_state1 bench_a.state]
putfile $SHA [shstate bench_a [list [list file $SHINC]]]
putfile [file join $SHL bench_b ngspice_state1 bench_b.state] [shstate bench_b [list {file {$::PF1723SHL/bench_a/includes/ns.spice}}]]
putfile [file join $SHL bench_b ngspice_state2 bench_b.state] [shstate bench_b [list [list file [file join $SHL bench_a includes .. includes ns.spice]]]]
putfile [file join $SHL bench_c ngspice_state1 bench_c.state] [shstate bench_c [list [list file [file join $SHL bench_a other.spice]]]]
## and one through a link TO THE FILE: the same file only once the last link
## is followed too (`file normalize` already follows a linked folder, so the
## sabotage that compared paths as spelled stayed green on a linked folder)
set shlinked {}
file mkdir [file join $SHL bench_d ngspice_state1]
if {![catch {file link -symbolic [file join $SHL bench_d ns_link.spice] $SHINC}]} {
  putfile [file join $SHL bench_d ngspice_state1 bench_d.state] [shstate bench_d [list [list file [file join $SHL bench_d ns_link.spice]]]]
  set shlinked bench_d/ngspice_state1
} else {
  puts "skip: PF1723ak's linked-file leg (no symbolic link could be made)"
}
set shp [list [dict create path $SHINC file $SHINC editable 1 n 1 why {} writable 1 \
                 backup $SHINC.bak edits {} changes [list [dict create from x1 to xdut n 1 whole 0 prefix x1]]]]
set shp2 [pcall ase::include_plan_shared $shp $SHA]
eqcheck PF1723ak-the-other-states-of-the-library-that-include-the-same-file-are-found-by-any-spelling \
  [list [pcall ase::include_sharers $SHA $SHINC] [pcall ase::include_sharers $SHA [file join $SHL bench_a other.spice]] \
        [pcall ase::include_sharers [file join $tmp run_1723i rn.state] $SHINC] \
        [dgn [lindex $shp2 0] shared]] \
  [list [list bench_b/ngspice_state1 bench_b/ngspice_state2 {*}$shlinked] bench_c/ngspice_state1 {} \
        [list bench_b/ngspice_state1 bench_b/ngspice_state2 {*}$shlinked]]
eqcheck PF1723ak2-the-confirmation-names-the-other-states-a-shared-file-is-rewritten-for \
  [lrange [pcall ase::ui::repair_confirm_lines $shp2 {}] 1 2] \
  [list "  ns.spice: 1 × x1. → xdut. Backup: $SHINC.bak" \
        "    Shared: [expr {$shlinked eq {} ? 2 : 3}] other states of this library include it too ([join [list bench_b/ngspice_state1 bench_b/ngspice_state2 {*}$shlinked] {, }]), and they will read the new names."]

## --- PF1723ah: the user's shape, end to end, on /usr/bin/ngspice ------------
## Two nodeset include files, `{vsup-1.35}` values, a `+` continuation,
## `.nodeset` only, correct outputs, and (fix round) a stdcell deck ahead of
## them, every entry by a portable `$::VAR` path. Stale: refused before ngspice, nothing generated. The
## CONTROL (the check switched off) reaches ngspice and dies on the syntax
## error, which is what makes the refusal worth having. Fixed through the
## console command: the run completes with no nodeset warning in its log.
set NG /usr/bin/ngspice
if {![file executable $NG]} {
  puts "skip: PF1723ah end to end (no $NG)"
} else {
  set RDE [file normalize [file join $tmp run_1723e]]
  file mkdir $RDE
  set NLE "** sch_path: /fixture/e2e_tb.sch\n**.subckt e2e_tb\nxdut vsupn out e2e_buf\nVS vsupn 0 {vsup}\n.param vsup=1.8\n**.ends\n.subckt e2e_buf VDD OUT\nR1 VDD a1 1k\nR2 a1 d1 1k\nR3 d1 tail 1k\nR4 tail tailb 1k\nR5 tailb enb 1k\nR6 enb enbuf 1k\nR7 enbuf net1 1k\nR8 net1 OUT 1k\nR9 OUT 0 1k\n.ends\n.end\n"
  set NLEF [file join $RDE e2e_tb.spice]
  putfile $NLEF $NLE
  set ENF [file join $RDE nodeset_enabled.spice]
  set DISF [file join $RDE nodeset_disabled.spice]
  putfile $ENF "* e2e bench, enabled state\n* a first guess for the dc solver\n.nodeset v(out)=1.2 v(x1.a1)=1.5 v(x1.d1)={vsup-1.35} v(x1.tail)=0.30 v(x1.tailb)=0.025\n+ v(x1.enb)=0 v(x1.enbuf)={vsup} v(x1.net1)={vsup-0.01}\n"
  putfile $DISF "* e2e bench, disabled state\n.nodeset v(out)=0 v(x1.a1)=1.1 v(x1.d1)={vsup} v(x1.tail)=0.87 v(x1.tailb)=0.87\n+ v(x1.enb)={vsup} v(x1.enbuf)=0 v(x1.net1)={vsup}\n"
  ## the user's list really starts with the PDK stdcell deck, and every entry is
  ## a portable `$::VAR` path (fix round, finding 12): `X1` element cards inside
  ## its `.subckt` bodies must not stand the stale top-level `x1.` rows down
  set ::PF1723E $RDE
  putfile [file join $RDE stdcells.spice] "* a stdcell library\n.subckt lib_buf_1 A X VGND VPWR\nX1 A n1 VGND VPWR lib_inv_1\nX2 n1 X VGND VPWR lib_inv_1\n.ends\n.SUBCKT lib_inv_1 A Y VGND VPWR\nX1 A Y VGND VPWR lib_res\n.ENDS\n.subckt lib_res a b VGND VPWR\nR1 a b 1k\n.ends\n"
  pcall ase::sim_clear
  pcall ase::sim_register pf1723e $NG
  pcall ase::sim_select pf1723e
  putfile [file join $RDE e2e.state] \
    "design {lib aselib cell e2e_tb view schematic} rundir [list $RDE] models {}\
 analyses {{type op enabled 1}} outputs {{expr v(out) save 1 plot 0}}\
 includes [list [list {file {$::PF1723E/stdcells.spice}} {file {$::PF1723E/nodeset_enabled.spice}}\
                      {file {$::PF1723E/nodeset_disabled.spice}}]]"
  pcall ase::session_open e2ek [file join $RDE e2e.state]
  proc e2e_st {} { return [ase::sim_choice_set [ase::session_state e2ek] entry pf1723e] }
  proc e2e_log {} { return [readfile [file join $::RDE e2e_tb_ase.log]] }
  said_clear
  set e1rc [catch {ase::run_deck [e2e_st] $NLEF} e1]
  set e1files [glob -nocomplain -tails -directory $RDE *_ase.*]
  set ::ase_preflight 0
  set ecid -1
  catch {set ecid [ase::run_deck [e2e_st] $NLEF]}
  set ecex [ase::wait $ecid]
  set ::ase_preflight 1
  set eclog [e2e_log]
  eqcheck PF1723ah-stale-the-run-is-refused-before-ngspice-which-would-have-died-on-the-syntax-error \
    [list $e1rc [string match {ase: REFUSED — 14 .nodeset/.ic names in 2 include files stop at*} $e1] \
          $e1files $ecex [string match "*Error: .nodeset syntax error.*" $eclog]] {1 1 {} 1 1}
  foreach f [glob -nocomplain -directory $RDE *_ase.*] { file delete $f }
  set e2n [pcall ase::preflight_fix_includes e2ek]
  set e2id -1
  set e2rc [catch {set e2id [ase::run_deck [e2e_st] $NLEF]} e2err]
  set e2ex [ase::wait $e2id]
  set e2log [e2e_log]
  eqcheck PF1723ah2-fixed-the-run-reaches-ngspice-and-finishes-with-no-nodeset-warning \
    [list $e2n $e2rc $e2ex [file exists [file join $RDE e2e_tb_ase.raw]] \
          [string match -nocase {*nodeset*} [string range $e2log [string first {--- simulator output ---} $e2log] end]] \
          [string match {*non-existent*} $e2log] [string match {*x1.*} [readfile $ENF][readfile $DISF]]] \
    {14 0 0 1 0 0 0}
  pcall ase::session_close e2ek
  ## FIX ROUND 2's THREE READINGS, END TO END: a `$` comment line inside the
  ## card, `v (x1.d1)` with a blank, and a `\\` continuation. Stale: refused
  ## before ngspice; with the check off ngspice dies on the syntax error; after
  ## the file half every one is rewritten and the run finishes with no nodeset
  ## warning.
  set ENF3 [file join $RDE nodeset_r2.spice]
  set ENF3TXT "* fix round 2 shapes\n.nodeset v(out)=1.2\n\$ the enabled-state guesses\n+ v(x1.a1)={vsup-1.35}\n.nodeset v (x1.d1)={vsup-0.1} \\\\\n  v(x1.tail)=0.30\n"
  putfile $ENF3 $ENF3TXT
  foreach f [glob -nocomplain -directory $RDE *_ase.*] { file delete $f }
  putfile [file join $RDE e2e3.state] \
    "design {lib aselib cell e2e_tb view schematic} rundir [list $RDE] models {}\
 analyses {{type op enabled 1}} outputs {{expr v(out) save 1 plot 0}}\
 includes [list [list {file {$::PF1723E/stdcells.spice}} {file {$::PF1723E/nodeset_r2.spice}}]]"
  pcall ase::session_open e2ek3 [file join $RDE e2e3.state]
  proc e2e3_st {} { return [ase::sim_choice_set [ase::session_state e2ek3] entry pf1723e] }
  set e3rc [catch {ase::run_deck [e2e3_st] $NLEF} e3]
  set e3files [glob -nocomplain -tails -directory $RDE *_ase.*]
  set ::ase_preflight 0
  set e3cid -1
  catch {set e3cid [ase::run_deck [e2e3_st] $NLEF]}
  set e3cex [ase::wait $e3cid]
  set ::ase_preflight 1
  set e3clog [e2e_log]
  foreach f [glob -nocomplain -directory $RDE *_ase.*] { file delete $f }
  set e3n [pcall ase::preflight_fix_includes e2ek3]
  set e3id -1
  set e3rc2 [catch {set e3id [ase::run_deck [e2e3_st] $NLEF]} e3err]
  set e3ex [ase::wait $e3id]
  set e3log [e2e_log]
  eqcheck PF1723ah3-a-dollar-line-a-blank-before-the-paren-and-a-backslash-continuation-are-refused-then-fixed-end-to-end \
    [list $e3rc [string match {ase: REFUSED — 3 .nodeset/.ic names in 1 include file stop at*} $e3] $e3files \
          $e3cex [string match "*Error: .nodeset syntax error.*" $e3clog] \
          $e3n $e3rc2 $e3ex \
          [string match -nocase {*nodeset*} [string range $e3log [string first {--- simulator output ---} $e3log] end]] \
          [readfile $ENF3]] \
    [list 1 1 {} 1 1 3 0 0 0 \
          "* fix round 2 shapes\n.nodeset v(out)=1.2\n\$ the enabled-state guesses\n+ v(xdut.a1)={vsup-1.35}\n.nodeset v (xdut.d1)={vsup-0.1} \\\\\n  v(xdut.tail)=0.30\n"]
  pcall ase::session_close e2ek3
  ## FIX ROUND 3, END TO END: three shapes ngspice RUNS although each names
  ## `x1.` with a `{...}` value -- an indented `;` line ending the card before
  ## its `+` line (finding 1), a name after `.nodeset all=` (finding 2), and a
  ## card in a `.if` branch not taken (finding 6). The gate refused this bench;
  ## now, with the check ON, it reaches ngspice and finishes at exit 0 with no
  ## nodeset warning, the `.if` card is one caution, and the file is untouched.
  set ENF4 [file join $RDE nodeset_r3.spice]
  set ENF4TXT "* fix round 3 shapes\n.nodeset v(out)=1.2\n  ; x1 was the dut before the rename\n+ v(x1.a1)={vsup-1.35}\n.nodeset all=0.5 v(x1.d1)={vsup}\n.if (0)\n.nodeset v(x1.tail)={vsup}\n.endif\n"
  putfile $ENF4 $ENF4TXT
  foreach f [glob -nocomplain -directory $RDE *_ase.*] { file delete $f }
  putfile [file join $RDE e2e4.state] \
    "design {lib aselib cell e2e_tb view schematic} rundir [list $RDE] models {}\
 analyses {{type op enabled 1}} outputs {{expr v(out) save 1 plot 0}}\
 includes [list [list {file {$::PF1723E/stdcells.spice}} {file {$::PF1723E/nodeset_r3.spice}}]]"
  pcall ase::session_open e2ek4 [file join $RDE e2e4.state]
  proc e2e4_st {} { return [ase::sim_choice_set [ase::session_state e2ek4] entry pf1723e] }
  said_clear
  set e4id -1
  set e4rc [catch {set e4id [ase::run_deck [e2e4_st] $NLEF]} e4err]
  set e4ex [ase::wait $e4id]
  set e4log [e2e_log]
  eqcheck PF1723ah4-a-semicolon-line-a-nodeset-all-and-a-branch-not-taken-reach-ngspice-which-runs-them-clean \
    [list $e4rc $e4ex [file exists [file join $RDE e2e_tb_ase.raw]] \
          [string match -nocase {*nodeset*} [string range $e4log [string first {--- simulator output ---} $e4log] end]] \
          [string match {*non-existent*} $e4log] [said_count {ase: REFUSED*}] \
          [said_count "ase: caution: include file '*nodeset_r3.spice' line 7: .nodeset names 'x1.tail' inside a .if block*"] \
          [expr {[readfile $ENF4] eq $ENF4TXT}]] \
    {0 0 1 0 0 0 1 1}
  pcall ase::session_close e2ek4
  pcall ase::sim_clear
}

} pf1723ierr]} { puts "FATAL: PF1723 items 5-7 $pf1723ierr" ; incr fail }
catch {file attributes [file join $tmp run_1723i ns_ro.spice] -permissions 0644}
catch {file attributes [file join $tmp run_1723i ns_two.spice] -permissions 0644}
foreach v {::PDK_ROOT ::ASE_DEFAULT_MODELS ::env(PDK_ROOT)} {
  catch {unset $v}
  if {[info exists ::pfi_saved($v)]} { set $v $::pfi_saved($v) }
}
set ::ase_preflight 1
set ::sim_case_mode fold

## ===========================================================================
## PF233 -- THE GATE'S THIRD ARGUMENT IS OPTIONAL, AND A FIXTURE STRING DONATES
## NOTHING. Stage 6, issue 1435.
## ===========================================================================
## `ase::preflight_gate` gained `{netlistpath {}}` so that the ONE caller which
## knows which file the text came from -- `ase::run_deck`, which is handed the
## path -- can hand the facts it has already computed to the peek slot the
## precondition banner reads. Everything else omits it.
##
## ⚠ THAT DEFAULT IS LOAD-BEARING AND THIS FILE IS THE PLACE TO PIN IT. Every
## `deck_of`/`pcheckx` call in this suite passes a HAND-WRITTEN netlist string
## that nobody netlisted. If the gate donated for those, the dialog would start
## reporting on a circuit that exists only inside a test fixture -- and on a
## user's machine, on whatever string the last script happened to pass.
if {[catch {

ase::facts_clear
set PF233ST [dict create design {lib aselib cell pf233 view schematic} \
               rundir /tmp analyses {{type op enabled 1}} outputs {}]
catch {ase::preflight_gate $PF233ST $MPNL}
eqcheck PF233a-a-two-argument-gate-call-donates-nothing \
  [ase::facts_status $PF233ST] {state cold}
eqcheck PF233b-and-the-gate-still-takes-two-arguments \
  [expr {[llength [info args ase::preflight_gate]] == 3 \
         && [info default ase::preflight_gate netlistpath _pf233d] == 1 \
         && $_pf233d eq {}}] 1
## PF233c -- AND A DONATE INTO A SLOT THIS SESSION DID NOT OPEN IS REFUSED. That
## is `ase::run_existing`'s shape: ADE-L's Run reaches ase::run_deck without ever
## re-netlisting, so the path it passes names an artifact nobody captured.
eqcheck PF233c-a-donate-with-no-slot-open-is-refused \
  [list [ase::facts_donate $PF233ST /tmp/pf233_nobody_wrote_this.spice \
           {sources {} exact 1}] [ase::facts_status $PF233ST]] {0 {state cold}}
## PF233d -- THE NON-VACUITY CONTROL. The same donate IS taken once a slot names
## that deck, so PF233a/c are refusals and not a proc that never works.
set ::ase::netlist_facts_slot [dict create sch /pf233/x.sch cell a/b/c \
  path [file normalize /tmp/pf233_nobody_wrote_this.spice] schstamp {} \
  deckstamp {} schcur 0 schmod 0 when 0]
eqcheck PF233d-the-same-donate-is-taken-when-a-slot-names-that-deck \
  [ase::facts_donate $PF233ST /tmp/pf233_nobody_wrote_this.spice \
     {sources {} exact 1}] 1
## PF233e -- ⚠ THE `$netlistpath ne {}` HALF OF THE GATE'S GUARD, PINNED WITH A
## CONSTRUCTED FIXTURE AND SAID TO BE CONSTRUCTED. MEASURED, and the measurement
## is the interesting part: `file normalize {}` answers the EMPTY STRING, not the
## cwd -- so a path-less caller and a slot that `ase::netlist_in_place` opened can
## never collide, the guard is defence in depth, and the sabotage that removed it
## SURVIVED. The only fixture that can tell the two spellings apart is a slot
## whose `path` is itself empty, which `ase::facts_capture` cannot produce. The
## row exists so the line cannot be deleted as dead. Same shape as issue 1434's
## S50, which earned a fixture rather than a deletion for the same reason.
set ::ase::netlist_facts_slot [dict create sch /pf233/x.sch cell a/b/c \
  path {} schstamp {} deckstamp {} schcur 0 schmod 0 when 0]
catch {ase::preflight_gate $PF233ST $MPNL}
eqcheck PF233e-a-path-less-gate-call-donates-nothing-even-into-an-open-slot \
  [list [file normalize {}] [dict exists $::ase::netlist_facts_slot facts]] {{} 0}
## PF233f -- THE NON-VACUITY CONTROL, on a slot of the shape the product really
## opens: the same gate call, given the path, DOES donate.
set ::ase::netlist_facts_slot [dict create sch /pf233/x.sch cell a/b/c \
  path [file normalize /tmp/pf233_gate_donation.spice] schstamp {} deckstamp {} \
  schcur 0 schmod 0 when 0]
catch {ase::preflight_gate $PF233ST $MPNL /tmp/pf233_gate_donation.spice}
eqcheck PF233f-and-the-same-call-WITH-the-path-does-donate-non-vacuity \
  [dict exists $::ase::netlist_facts_slot facts] 1
ase::facts_clear

} pf233err]} { puts "FATAL: PF233 $pf233err" ; incr fail }

## restore the real ciw_echo OUTSIDE the catch, so a FATAL cannot leave the stub
if {[info commands ::ciw_echo_orig] ne {}} {
  catch {rename ::ciw_echo {}}
  catch {rename ::ciw_echo_orig ::ciw_echo}
}

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else        { puts "RESULT: ALL PASS ($npass checks)" }
# ⚠ THE SECOND SENTINEL, AND IT IS WHAT LETS run_regression.tcl READ THIS FILE
# AT ALL. Issue 1421, and it is issue 1413's defect found a second time.
#
# There are TWO completion banners in this tree: `run_suites.sh` accepts either
# `RESULT: ALL PASS` or `OVERALL: ok` (issue 0228), while `tests/banner_rule.tcl`
# -- the rule `run_regression.tcl` consumes -- accepts ONLY a whole-line
# `OVERALL: ok`. A suite printing `RESULT:` alone is scored a HARNESS FAILURE by
# T1 however many of its own checks passed.
#
# MEASURED: this suite printed `RESULT:` alone AND `exit 0` unconditionally, and
# it appears in NO list in run_regression.tcl. So 125 checks of preflight
# behaviour -- the refusal that stands between a user and a raw file holding
# twelve mathematical constants -- had never been run by the regression driver
# at all, on either arm. It was in `full_audit.sh`'s nogui list and nowhere else.
#
# ⚠ AND `exit 0` UNCONDITIONALLY IS THE SECOND HALF OF THE SAME DEFECT. A case
# passes only on exit 0 AND a completion banner AND no death marker; a suite that
# always exits 0 has thrown away one of the three, so a FATAL in its own catch
# arm could print, be counted, and still leave the process claiming success.
if {$fail} {
  puts "OVERALL: notok"
} else {
  puts "OVERALL: ok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
