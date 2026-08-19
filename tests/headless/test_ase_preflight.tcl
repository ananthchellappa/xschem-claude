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
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_preflight.tcl

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
## the PROFILE ROW beats the floor: with the floor at `fold`, a stamped row
## carrying `distinguish` must still refuse — a scan that read $::sim_case_mode
## raw would pass this state
set ::sim_case_mode fold
set nrows 0 ; catch {set nrows $::sim(spice,n)}
set didx [pcall ::sim_profile_default_index spice]
set altidx -1
for {set i 0} {$i < $nrows} {incr i} { if {$i != $didx} { set altidx $i ; break } }
pcall ::sim_profile_set spice $altidx casemode distinguish
set stampd [pcall ase::sim_profile_stamp [mkstate $RD c $STALE] spice $altidx]
eqcheck PF215f-a-stamped-profile-row-beats-the-global-floor \
  [list [expr {$altidx >= 0}] [dg [pcall ase::preflight_scan $stampd $NL] mode] \
        [llength [dg [pcall ase::preflight_scan $stampd $NL] absent]]] {1 distinguish 2}
pcall ::sim_profile_set spice $altidx casemode {}
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
eqcheck PF216f-ase_preflight-0-disables-the-refusal \
  [list [catch {ase::preflight_gate [mkstate $RD c $TYPO] $NL} e2] [llength $::said]] {0 0}
set ::ase_preflight 1
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

## --- the empty-result DISJUNCTION -------------------------------------------
## PF219h's fixture sets BOTH counters to 0, so `&&` in place of `||` stayed
## green. Real variables over zero points is the actual shape of an analysis
## that started and produced nothing.
set zraw [file join $tmp zeropoints.raw]
putfile $zraw "Title: * t\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 0\nVariables:\nBinary:\n"
eqcheck PF221ag-variables-but-ZERO-POINTS-is-rejected \
  [dg [pcall ase::raw_content_verdict $zraw] ok] 0
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

} err]} { puts "FATAL: $err" ; incr fail }

## restore the real ciw_echo OUTSIDE the catch, so a FATAL cannot leave the stub
if {[info commands ::ciw_echo_orig] ne {}} {
  catch {rename ::ciw_echo {}}
  catch {rename ::ciw_echo_orig ::ciw_echo}
}

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else        { puts "RESULT: ALL PASS ($npass checks)" }
exit 0
