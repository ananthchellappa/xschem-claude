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
eqcheck PF216f-ase_preflight-0-disables-the-REFUSAL-and-not-the-caution-under-it \
  [list [catch {ase::preflight_gate [mkstate $RD c $TYPO] $NL} e2] \
        [said_count {ase: REFUSED*}] \
        [said_count {*will not run the op analysis at all*}]] {0 0 1}
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
## ⚠ THE UNRENDERABLE TYPE WAS `noise` AND IS NOW `sp`, BECAUSE ISSUE 1432 GAVE
## `noise` AND `disto` REAL ENTRIES. `sp` and `pss` are what is left probe-only,
## and both are #ifdef-gated. Row TF3b of tests/headless/test_ase_core.tcl warned
## that these rows would move the day `noise` became renderable; it did, and they
## moved in the same commit.
set UNREND {{type op enabled 1} {type sp enabled 1 source v1}}
said_clear
set stU [mkstate $RD c $GOOD]
dict set stU analyses $UNREND
set cu1 [catch {ase::preflight_gate $stU $NL} eu1]
eqcheck PF222a-an-unrenderable-analysis-is-refused $cu1 1
eqcheck PF222b-the-refusal-names-the-type \
  [string match "*analysis type 'sp' is not one this simulator backend can render*" $eu1] 1
eqcheck PF222c-and-says-the-run-would-have-said-nothing \
  [string match "*said nothing*" $eu1] 1
eqcheck PF222d-it-reaches-the-action-log-too \
  [expr {[said_count "*analysis type 'sp'*"] >= 1}] 1
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
  [list $cu2 [string match "*is not one this simulator backend can render*" $eu2]] {1 1}
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
dict set stD analyses {{type op enabled 1} {type sp enabled 0 source v1}}
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
## ⚠ AND THE SIDECAR RECORD IS INSIDE THAT SAME BRACKET (issue 1430). The plot
## sidecar's whole value is that record N names the row that wrote plot N, so a
## record appended for an analysis that then failed to write would put every
## later position out by one — silently, because a failed run is the one case
## nobody re-reads the file for. The record sits BELOW the guard and IMMEDIATELY
## ABOVE the write it describes, and this row pins both halves at once.
eqcheck PF218f2-the-sidecar-record-is-below-the-guard-and-above-its-own-write \
  [expr {[lsearch -glob $dl {echo "PLOT *}] > [lsearch -exact $dl {  quit 1}] &&
         [lsearch -glob $dl {echo "PLOT *}] > [lsearch -exact $dl {remzerovec}] &&
         [lsearch -glob $dl {echo "PLOT *}] + 1 == [lsearch -glob $dl {write *}]}] 1
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
        [expr {[string match {*_ase.plotmap} $pfmap] ? 1 : 0}] \
        [expr {[string match {*_ase.raw} $pfmap] ? 1 : 0}]] \
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
set ::sim_case_mode fold
set sd21 [pcall ase::preflight_scan [mkstate $RD c {{expr v(TOPNET)-v(nosuchnode) save 1}}] $NL]
eqcheck PF221r-a-derived-row-is-checked-past-its-first-identifier \
  [list [llength [dg $sd21 absent]] [dgn [lindex [dg $sd21 absent] 0] ident]] {1 nosuchnode}
set sdd21 [pcall ase::preflight_scan [mkstate $RD c {{expr v(TOPNET,nosuchnode) save 1}}] $NL]
eqcheck PF221s-a-differential-row-is-checked-on-BOTH-nodes \
  [list [llength [dg $sdd21 absent]] [dgn [lindex [dg $sdd21 absent] 0] ident]] {1 nosuchnode}

## --- the refusal head counts EXPRESSIONS, not identifiers -------------------
## One output row naming two absent nodes is ONE output expression; the head
## counted `[llength $rows]` and worded it as expressions, so it said "2".
## Read off with a regexp so the count, the plural and the verb are all pinned
## without depending on the em dash's byte sequence.
said_clear
set ch21 [catch {ase::preflight_gate [mkstate $RD c {{expr v(nosuchnode)-v(alsonot) save 1}}] $NL} eh21]
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
set sder [pcall ase::preflight_scan [mkstate $RD c {{expr v(outp)-v(outn) save 1}}] $NLD]
eqcheck PF221y-the-offer-repairs-a-derived-row-WHOLE \
  [pcall ase::preflight_fixed_expr [dg $sder absent]] {v(OUTP)-v(OUTN)}
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
 {{expr v(outp,outn) save 1} {expr v(outp)-v(outn) save 1}}"
pcall ase::session_open dfk [file join $RD4 dif.state]
said_clear
set nfx21 [pcall ase::preflight_fix_session dfk]
eqcheck PF221aa-one-call-repairs-EVERY-identifier-of-EVERY-row \
  [list $nfx21 [pcall ase::state_get [ase::session_state dfk] outputs]] \
  {2 {{expr v(OUTP,OUTN) save 1} {expr v(OUTP)-v(OUTN) save 1}}}
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
  set ::ase_preflight 0
  set idb [pcall ase::run_deck [realstate {{expr v(nosuchnode) save 1}}] \
             [file join $RD3 rc.spice]]
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
  {pz_nodes pz_nodes pz_nodes pz_nodes 1 1 1 1 {name nodes that are in the circuit}}

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
eqcheck PF230b-a-current-output-is-refused-as-fatal-because-noise-measures-a-voltage \
  [list [mpn $MPPI noise 0] [mpv $MPPI noise 0] \
        [string match {*measures a VOLTAGE*} [mps $MPPI noise 0]]] \
  {noise_out fatal 1}

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
eqcheck PF230f-ac-sensitivity-under-klu-is-fatal-and-dc-sensitivity-under-klu-is-not \
  [list [mpids $MPSK1 sens] [mpv $MPSK1 sens 0] \
        [string match {*crashes ngspice outright*} [mps $MPSK1 sens 0]] \
        [dict size $MPSK2]] \
  {sens_klu fatal 1 0}

## ⚠ THE SHARPEST DEFECT IN THE WHOLE SURFACE, AND MAKING `disto` RENDERABLE IS
## WHAT PUT IT IN REACH. The trigger is the save list RESOLVING TO NOTHING, not
## a bad entry and not the absence of a save -- `design-C`'s proposed refusal
## ("`disto` enabled AND zero saved outputs") would refuse the deck on the last
## line here, which was measured to run.
set MPDROW {{type disto enabled 1 sweep dec points 2 start 1k stop 10k}}
set MPD_BAD [pcheckx $MPNL $MPDROW {} {outputs {{name a expr v(nosuchnode) save 1 plot 1}}}]
set MPD_TWOBAD [pcheckx $MPNL $MPDROW {} \
  {outputs {{name a expr v(nosuchnode) save 1 plot 1} {name b expr v(alsonone) save 1 plot 1}}}]
set MPD_MIX [pcheckx $MPNL $MPDROW {} \
  {outputs {{name a expr v(nosuchnode) save 1 plot 1} {name b expr v(mid) save 1 plot 1}}}]
set MPD_ALL [pcheckx $MPNL $MPDROW {} \
  {save_all_v 1 outputs {{name a expr v(nosuchnode) save 1 plot 1}}}]
set MPD_NONE [pcheckx $MPNL $MPDROW {} {outputs {}}]
set MPD_UNTICKED [pcheckx $MPNL $MPDROW {} {outputs {{name a expr v(nosuchnode) save 0 plot 1}}}]
eqcheck PF230g-disto-is-refused-only-when-the-WHOLE-save-list-resolves-to-nothing \
  [list [mpv $MPD_BAD disto 0] [mpn $MPD_BAD disto 0] \
        [mpv $MPD_TWOBAD disto 0] \
        [dict size $MPD_MIX] [dict size $MPD_ALL] [dict size $MPD_NONE] \
        [dict size $MPD_UNTICKED]] \
  {fatal disto_saves fatal 0 0 0 0}

## ⚠ AND THE SENTENCE SAYS SEGFAULT IN AS MANY WORDS, because the whole point is
## that there is no exit status and no log to explain it afterwards.
eqcheck PF230h-the-disto-refusal-says-what-happens-and-offers-three-ways-out \
  [list [string match {*SEGFAULT*} [mps $MPD_BAD disto 0]] \
        [string match {*cannot see inside an .include*} [mps $MPD_BAD disto 0]] \
        [string match {*Save all voltages*} [lindex [lindex [dgn $MPD_BAD disto] 0] 3]]] \
  {1 1 1}

## ⚠ A CURRENT SAVE STARVES IT TOO: `.save i(vnope)` is a branch current of a
## source that is not there, and it resolves to nothing exactly as a node does.
set MPD_CUR [pcheckx $MPNL $MPDROW {} {outputs {{name a expr i(Vnope) save 1 plot 1}}}]
set MPD_CUROK [pcheckx $MPNL $MPDROW {} {outputs {{name a expr i(V1) save 1 plot 1}}}]
eqcheck PF230i-a-branch-current-of-a-source-that-is-not-there-starves-it-as-well \
  [list [mpv $MPD_CUR disto 0] [dict size $MPD_CUROK]] {fatal 0}

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
set MPVS_N [pcheckx $MPNL [mprow {*}$MPGOOD] {} $MPSAVED]
set MPVS_T [pcheckx $MPNL {{type tf enabled 1 out {v(mid)} insrc V1}} {} $MPSAVED]
set MPVS_S [pcheckx $MPNL {{type sens enabled 1 out {v(mid)}}} {} $MPSAVED]
set MPVS_P [pcheckx $MPNL {{type pz enabled 1 inp in outp mid}} {} $MPSAVED]
set MPVS_D [pcheckx $MPNL {{type disto enabled 1 sweep dec points 2 start 1k stop 10k}} \
                    {} $MPSAVED]
eqcheck PF230l-noise-tf-sens-AND-pz-report-the-widening-as-a-caution-and-disto-does-not \
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
eqcheck PF230m-only-a-bench-whose-save-list-was-never-narrowed-has-nothing-to-report \
  [list [dict size [pcheckx $MPNL [mprow {*}$MPGOOD] {} $MPBLANKET]] \
        [dict size [pcheckx $MPNL [mprow {*}$MPGOOD] {} {outputs {}}]] \
        [mpv [pcheckx $MPNL [mprow {*}$MPGOOD] {} \
           [dict merge $MPSAVED {save_op_params 1}]] noise 0] \
        [mpv [pcheckx $MPNL [list [concat {type noise enabled 1} $MPGOOD \
                                   {x {{save all}}}]] {} $MPSAVED] noise 0]] \
  {0 0 caution caution}

## ⚠ THE SENTENCE COUNTS, AND A BENCH WITH TWO SAVED OUTPUTS SAYS "ticks".
## A sentence that got the plural wrong would be the one thing a user quotes
## back.
set MPVS_2 [pcheckx $MPNL [mprow {*}$MPGOOD] {} \
  {outputs {{name a expr v(mid) save 1 plot 1} {name b expr v(in) save 1 plot 1}}}]
eqcheck PF230n-the-widening-sentence-counts-the-ticks-names-the-type-and-offers-both-ways-out \
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
set PF32 [pcheckx $MPNL $PF32ROWS {} $PFBAD]
eqcheck PF232a-every-renderable-type-reports-the-starvation-not-only-tran \
  [list [mpids $PF32 op] [mpids $PF32 dc] [mpids $PF32 ac] [mpids $PF32 tran]] \
  [list {saves_resolve} {saves_resolve} {saves_resolve} {saves_resolve}]
## ⚠ `caution`, NOT `fatal`, AND THE TIER IS THE DECISION. This rests on
## ase::netlist_facts, which answers `exact 0`: a hierarchical node inside an
## `.include`d subcircuit is unresolvable here and perfectly resolvable in
## ngspice. `disto` pays that risk because the alternative is a SIGSEGV with no
## log at all; a type that fails honestly at rc 1 must not cost a user their run
## over a blind spot.
eqcheck PF232b-it-is-a-caution-everywhere-and-a-fatal-only-for-disto \
  [list [mpv $PF32 op 0] [mpv $PF32 tran 0] \
        [mpv [pcheckx $MPNL $MPDROW {} $PFBAD] disto 0]] \
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
eqcheck PF232e-a-forced-leader-stands-both-tiers-down \
  [list [dict size [pcheckx $MPNL $PF32ROWS {} [dict merge $PFBAD {save_all_v 1}]]] \
        [mpids [pcheckx $MPNL [concat $PF32ROWS [mprow {*}$MPGOOD]] {} $PFBAD] op] \
        [dict size [pcheckx $MPNL [concat $MPDROW [mprow {*}$MPGOOD]] {} $PFBAD]] \
        [mpv [pcheckx $MPNL $MPDROW {} $PFBAD] disto 0]] \
  [list 0 NO:op 1 fatal]
## ⚠ the third leg above is the one that could go vacuous: `disto` + `noise` on a
## starving bench must report the WIDENING and not the segfault, so the size is 1
## and the id is the noise row's
eqcheck PF232f-and-what-it-reports-instead-is-the-widening \
  [mpids [pcheckx $MPNL [concat $MPDROW [mprow {*}$MPGOOD]] {} $PFBAD] noise] \
  {vecsaves}

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
        [dict size [pcheckx $MPNL {{type sp enabled 1}} {} $PFBAD]]] {0 0}

} pf232err]} { puts "FATAL: PF232 $pf232err" ; incr fail }

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
