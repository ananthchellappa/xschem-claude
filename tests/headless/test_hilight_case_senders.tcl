# test_hilight_case_senders.tcl — the cross-probe senders spell their query in
# the case the loaded database actually uses.
# Casemode batch item 4 (PLAN.md §3b). Spec: doc/claude/specs/raw_case_mode.md
# §11, which also carries the site map and the rulings this file drives.
#
# WHAT CHANGED. Ctrl-K (hilight.send_to_waveform -> hilight_net()) and
# Ctrl-Shift-X (xschem create_plot_cmd) build a query out of the SCHEMATIC's own
# spelling and hand it to a plotter. Every one of those queries used to be
# strtolower()ed unconditionally, which was right only while read_dataset()
# folded every stored name too. Item 1 deleted that fold; item 2 made the lookup
# case-insensitive but SUPPRESSES that rung under `distinguish`. So a lowercased
# cross-probe into a `preserve`/`distinguish` database is a query that resolves
# by luck or not at all. The fold is now gated on the mode item 3 resolves, with
# `Raw.case_sensitive` under it and the global floor (`sim_case_mode`) under
# that.
#
# THE LOAD-BEARING CHECKS, and why:
#   CS72..CS75  BOTH HALVES of every sender are gated -- the hierarchy PATH as
#               well as the token. A gate on the token alone looks green on a
#               flat schematic and misses the moment anything is hierarchical,
#               so all four senders are driven one level down (.X1.) as well as
#               at the top (CS66, CS68, CS69), and CS87/CS88 do the same for the
#               fifth sender, create_plot_cmd().
#   CS72b/75b   ngspice's hierarchical-current prefix is NOT a fixed lowercase
#               `v.`: it is the DEVICE'S OWN first character, folded with
#               everything else. Measured on ver_50 -- deck `Vs` gives
#               i(V.X1.Vs) under preserve, deck `vs` gives i(v.X1.vs). Both
#               spellings are driven, on both current senders.
#   CS70        the input states, one at a time: fold / preserve+distinguish /
#               unknown-so-ask-the-floor (DECISIONS.md B2b). CS66b is the floor
#               again with nothing loaded at all -- gaw reading a file we never
#               opened is the case the global exists for.
#   CS82/CS83   `Raw.case_sensitive` -- the flag that switches get_raw_index()'s
#               folded rung OFF -- is positive evidence and BEATS the floor
#               (CS82), but evidence about the file's actual bytes beats IT
#               (CS83, where the folded query is the only one that resolves).
#               Both assert that the emitted query RESOLVES, not merely that it
#               is spelled a certain way.
#   CS84        the gate must survive a DESCEND reached through source 3 alone
#               -- no `xschem raw casemode` verb anywhere, which is all a real
#               user gets for free.
#   CS85/CS86   Ctrl-K on a WIRE, the most common way a net is highlighted.
#   CS67        the Xyce arm's strtoupper stays as the NO-EVIDENCE fallback and
#               loses to positive evidence, which is how it stops contradicting
#               spec §5's "no Xyce-specific fold".
#   CS77/CS78   the receiver-side parse (hilight_graph_node) is CASE-BLIND: a
#               mixed `i(V.X1.Vs)` used to fall through to the `i(` arm and
#               advance 2 instead of 4, yielding path `.V.X1.` -- and that
#               spelling is exactly what CS75 now makes the sender emit.
#   CS81        ...and ANCHORED: `zi(vs)` must stay one bare token, not be
#               sliced at a fixed offset from position 0 because the prefix
#               matched at position 1.
#
# Most checks compare a PAIR (what the sender emits under `fold` and under
# `preserve`) in one assertion, so "never fold" fails as loudly as "always
# fold" and no half of it can pass vacuously.
#
# NEEDS A DISPLAY (unlike test_raw_case_mode.tcl, which is true headless): the
# four hilight_net() senders are reachable only through the action registry, and
# `xschem callback .drw ...` segfaults with no window. Run it as
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog \
#       --script tests/headless/test_hilight_case_senders.tcl

source [file join [file dirname [info script]] scratch.tcl]

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
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}

set here [file normalize [file dirname [info script]]]
set fixdir [file normalize [file join $here .. .. doc claude casemode_batch fixtures]]
set presraw [file join $fixdir tr_preserve.raw]
set foldraw [file join $fixdir tr_fold.raw]

# A missing fixture must FAIL, never skip: full_audit.sh scores a whole file
# SKIP on that substring and silently discards every check that did run.
check CS65-fixtures-present \
  [expr {[file exists $presraw] && [file exists $foldraw]}] "($fixdir)"
if {$fail} {
  puts "RESULT: $fail FAILED (0 passed)"
  flush stdout
  exit 1
}

set tmp [test_scratch hilightcase]
proc wr {path body} { set fp [open $path w]; puts -nonewline $fp $body; close $fp }

# ---------------------------------------------------------------------------
# Fixtures: a flat design and a one-deep hierarchy, both with MIXED-CASE names.
# `In` / `MidNode` match the committed raw fixtures' nets; `X1` and `Vs` are the
# capitals that make a folded PATH and a folded device token visible.
#
# flat.sch is deliberately WEAK for source 3: `MidNode` is the only capitalised
# name the schematic OWNS (`lab=`), and the comparison needs two, so it answers
# `unknown`. That is what makes CS82 a real test of `Raw.case_sensitive` rather
# than of the schematic comparison. strong.sch is the same design plus `In`, so
# source 3 CAN answer there -- which is what CS83 needs.
#
# `vsx` in subx.sch is a vsource whose name starts LOWERCASE, the second half of
# the measured prefix rule (CS72b/CS75b).
# ---------------------------------------------------------------------------
wr $tmp/flat.sch "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 200 -100 400 -100 {}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=MidNode}
C {devices/vsource} 200 100 0 0 {name=Vs value=1}
"
wr $tmp/strong.sch "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=MidNode}
C {devices/lab_pin} 200 -200 0 0 {name=l2 lab=In}
C {devices/vsource} 200 100 0 0 {name=Vs value=1}
"
wr $tmp/subx.sym "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
V {}
S {}
F {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 -20 20 20 20 {}
L 4 -20 -20 -20 20 {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
"
wr $tmp/subx.sch "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 200 0 400 0 {}
C {devices/iopin} 0 0 0 0 {name=p1 lab=A}
C {devices/vsource} 100 0 0 0 {name=Vs value=1}
C {devices/lab_pin} 200 0 0 0 {name=l9 lab=MidNode}
C {devices/vsource} 100 100 0 0 {name=vsx value=1}
"
# hier.sch owns `MidNode` and `In` at the TOP so source 3 can answer there --
# CS84 needs a hierarchy the resolver can speak about with no explicit verb.
wr $tmp/hier.sch "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {$tmp/subx.sym} 0 0 0 0 {name=X1}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=MidNode}
C {devices/lab_pin} 200 -200 0 0 {name=l2 lab=In}
C {$tmp/subx.sym} 0 300 0 0 {name=Xa1}
"

# ---------------------------------------------------------------------------
# The capture harness.
#
# gaw is an external program and there is none here, so the socket is faked:
# `setup_tcp_gaw` is shadowed to succeed and `gaw_fd` is a plain file. `vwait`
# is renamed away because the real handshake blocks on a variable only the
# absent gaw writes -- with no gaw, the suite would hang forever, which is the
# one failure mode worse than a red check. Nothing here prints the string
# "SKIP": a gaw-less machine is the NORMAL case for this suite, not a skip.
# ---------------------------------------------------------------------------
proc setup_tcp_gaw {} { return 1 }
rename vwait _real_vwait
proc vwait {n} { return }
proc sim_is_xyce {} { return $::xyce }
set xyce 0
set sim(spicewave,default) 0
set sim(spicewave,0,name) {Gaw viewer}
set netlist_dir $tmp
set ::auto_hilight_graph_nodes 1

# Ctrl-K: bound to a throwaway key so the whole action -- tool selection
# included -- runs, not just the C function under it.
xschem clear force
xschem load $tmp/flat.sch
update
xschem bind key 107 0 canvas hilight.send_to_waveform

# The captured gaw traffic, one line per copyvar, colours normalised to #C:
# xctx->hilight_color advances per gesture and this suite is about spelling.
proc gawtext {} {
  global tmp
  catch {close $::gaw_fd}
  set f [open $tmp/gaw.txt r]; set d [read $f]; close $f
  regsub -all {#[0-9a-fA-F]{6}} [string trim $d] {#C} d
  return [string map {"\n" " | "} $d]
}
# Fire Ctrl-K with a fresh capture file. Returns what reached "gaw".
proc ctrlk_gaw {} {
  global tmp
  catch {close $::gaw_fd}
  set ::gaw_fd [open $tmp/gaw.txt w]
  xschem callback .drw 2 100 100 107 0 0 0
  update
  return [gawtext]
}
# Fire Ctrl-Shift-X (create_plot_cmd) with a fresh capture file.
proc plotcmd_gaw {} {
  global tmp
  catch {close $::gaw_fd}
  set ::gaw_fd [open $tmp/gaw.txt w]
  xschem create_plot_cmd
  update
  return [gawtext]
}
# The bare query out of a `copyvar <query> sel #C` line, so a check can ask the
# lookup whether it actually RESOLVES -- the point of the whole item.
proc copyvar_arg {line} {
  if {[regexp {copyvar (\S+) sel} $line -> a]} { return $a }
  return "?"
}
# Select exactly one object again (highlighting consumes nothing, but the
# senders only fire for a net that was NOT already highlighted).
proc reselect {kind n} {
  xschem unhilight_all
  xschem unselect_all
  xschem select $kind $n
}
# Set the mode the senders must resolve. `explicit` needs a database to hang
# off, so a raw is loaded first; `floor` deliberately has none loaded, which is
# the "gaw is reading a file we never opened" case.
proc set_mode {how mode} {
  global presraw
  if {$how eq "explicit"} {
    xschem raw clear
    xschem raw read $presraw tran
    xschem raw casemode $mode
  } else {
    xschem raw clear
    set ::sim_case_mode $mode
  }
}

# ---------------------------------------------------------------------------
# AB. create_plot_cmd -> gaw, spice arm  (hilight.c, the fifth sender the plan
#     never named). BOTH halves folded on one line: strtolower(p), strtolower(t)
# ---------------------------------------------------------------------------
set_mode explicit fold
xschem unhilight_all
xschem unselect_all
xschem select instance 0        ;# the MidNode lab_pin
xschem hilight
set cf [plotcmd_gaw]
set_mode explicit preserve
set cp [plotcmd_gaw]
eqcheck CS66-plotcmd-spice-token \
  [list $cf $cp] \
  [list {copyvar v(midnode) sel #C} {copyvar v(MidNode) sel #C}]

# and the request is a claim about a RUN, so with nothing loaded the GLOBAL
# floor answers -- the only answer available when gaw reads a file we never did
set_mode floor fold
set ff [plotcmd_gaw]
set_mode floor preserve
set fp [plotcmd_gaw]
eqcheck CS66b-plotcmd-spice-floor \
  [list $ff $fp] \
  [list {copyvar v(midnode) sel #C} {copyvar v(MidNode) sel #C}]
set ::sim_case_mode fold

# ---------------------------------------------------------------------------
# AC. create_plot_cmd -> gaw, XYCE arm. This arm strtoupper()s, i.e. it asserts
#     in code the premise spec §5 declined to assert about a FILE. The two are
#     reconciled: the uppercase survives as the no-evidence FALLBACK (the
#     simulator's identity here comes from the configured command, not from
#     sniffing a file), and positive evidence of a case-keeping database beats
#     it. So `fold`/`unknown` are byte-for-byte what they were.
# ---------------------------------------------------------------------------
set xyce 1
set_mode explicit fold
set xf [plotcmd_gaw]
set_mode explicit preserve
set xp [plotcmd_gaw]
eqcheck CS67-plotcmd-xyce-upper-is-a-fallback \
  [list $xf $xp] \
  [list {copyvar MIDNODE sel #C} {copyvar MidNode sel #C}]
# `distinguish` is the mode where a wrong-case query cannot be rescued by the
# lookup at all, so it must not uppercase either
set_mode explicit distinguish
eqcheck CS67b-plotcmd-xyce-distinguish [plotcmd_gaw] {copyvar MidNode sel #C}
# nothing known -> unchanged from before item 4
set_mode floor fold
eqcheck CS67c-plotcmd-xyce-unknown-unchanged [plotcmd_gaw] {copyvar MIDNODE sel #C}
set xyce 0

# ---------------------------------------------------------------------------
# AD. hilight_net -> gaw: send_net_to_gaw and send_current_to_gaw, FLAT.
# ---------------------------------------------------------------------------
set_mode explicit fold
reselect instance 0
set nf [ctrlk_gaw]
set_mode explicit preserve
reselect instance 0
set np [ctrlk_gaw]
eqcheck CS68-gaw-net-flat \
  [list $nf $np] \
  [list {copyvar v(midnode) sel #C} {copyvar v(MidNode) sel #C}]

set_mode explicit fold
reselect instance 1             ;# the vsource Vs -> send_current_to_gaw
set if_ [ctrlk_gaw]
set_mode explicit preserve
reselect instance 1
set ip [ctrlk_gaw]
eqcheck CS69-gaw-current-flat \
  [list $if_ $ip] \
  [list {copyvar i(vs) sel #C} {copyvar i(Vs) sel #C}]

# THE INPUT STATES, on one sender, one at a time. `distinguish` is not a
# synonym for `preserve` anywhere else in this batch, so it is driven, not
# assumed; `unknown` must reach the floor and not be read as `fold`.
set_mode explicit distinguish
reselect instance 1
set idist [ctrlk_gaw]
set_mode floor preserve
reselect instance 1
set ifloor [ctrlk_gaw]
set ::sim_case_mode fold
reselect instance 1
set ifold [ctrlk_gaw]
eqcheck CS70-three-input-states \
  [list $idist $ifloor $ifold] \
  [list {copyvar i(Vs) sel #C} {copyvar i(Vs) sel #C} \
        {copyvar i(vs) sel #C}]

# ---------------------------------------------------------------------------
# AD2. Ctrl-K ON A WIRE. `case WIRE:` in hilight_net() is a separate pair of
#      call sites from the instance arm, and it is how a person actually
#      highlights a net: click the wire, press the key.
# ---------------------------------------------------------------------------
set_mode explicit fold
reselect wire 0
set wf [ctrlk_gaw]
set_mode explicit preserve
reselect wire 0
set wp [ctrlk_gaw]
eqcheck CS85-gaw-wire-flat \
  [list $wf $wp] \
  [list {copyvar v(midnode) sel #C} {copyvar v(MidNode) sel #C}]

# ---------------------------------------------------------------------------
# AD3. `Raw.case_sensitive` -- the ONE flag that makes a folded query
#      unrescuable, because it switches get_raw_index()'s folded rung OFF.
#      Both checks assert that the emitted query RESOLVES, which is the actual
#      user-visible outcome (a miss becomes a silent all-zero column, 0418).
# ---------------------------------------------------------------------------
# flat.sch owns ONE capitalised name, so source 3 cannot answer and the floor
# says fold -- yet the database was loaded the documented `distinguish` way.
# Folding here is the silent-miss the item exists to prevent.
xschem clear force
xschem load $tmp/flat.sch
update
xschem raw clear
xschem raw read $presraw tran -case distinguish
set ::sim_case_mode fold
reselect instance 0
set csq [ctrlk_gaw]
eqcheck CS82-case-sensitive-beats-the-floor \
  [list [pcall xschem raw casemode -all] $csq \
        [expr {[pcall xschem raw index [copyvar_arg $csq]] >= 0}]] \
  [list {unknown none} {copyvar v(MidNode) sel #C} 1]

# ...but evidence about the FILE'S BYTES beats the flag. tr_fold.raw really does
# hold folded names; with a case-sensitive lookup on top of that, the FOLDED
# query is the only one that can resolve, so `case_sensitive` must not veto it.
xschem clear force
xschem load $tmp/strong.sch
update
xschem raw clear
xschem raw read $foldraw tran -case distinguish
set ::sim_case_mode fold
reselect instance 0
set csf [ctrlk_gaw]
eqcheck CS83-bytes-beat-case-sensitive \
  [list [pcall xschem raw casemode -all] $csf \
        [expr {[pcall xschem raw index [copyvar_arg $csf]] >= 0}]] \
  [list {fold schematic} {copyvar v(midnode) sel #C} 1]
xschem raw clear

# ---------------------------------------------------------------------------
# AE. hilight_net -> gaw, ONE LEVEL DOWN. The PATH half of the gate: without it
#     `X1.` folds to `x1.` and the token's case is cosmetic.
# ---------------------------------------------------------------------------
xschem clear force
xschem load $tmp/hier.sch
update
xschem unselect_all
xschem select instance 0        ;# X1
xschem descend
update
eqcheck CS71-descended [pcall xschem get sch_path] {.X1.}

set_mode explicit fold
reselect instance 1             ;# the vsource Vs inside X1
set hf [ctrlk_gaw]
set_mode explicit preserve
reselect instance 1
set hp [ctrlk_gaw]
eqcheck CS72-gaw-current-hierarchical-path \
  [list $hf $hp] \
  [list {copyvar i(v.x1.vs) sel #C} {copyvar i(V.X1.Vs) sel #C}]

# NGSPICE'S PREFIX IS THE DEVICE'S OWN FIRST CHARACTER, not a fixed `v.`.
# Measured on ver_50 (see sender_current_prefix() in hilight.c):
#   deck `Vs`  preserve -> i(V.X1.Vs)      deck `vs`  preserve -> i(v.X1.vs)
# so a lowercase-named vsource must still get a lowercase prefix. Driving only
# `Vs` would pass with a hard-coded "V." and ship a query that resolves to -1.
set_mode explicit fold
reselect instance 3             ;# the vsource `vsx` inside X1
set lf [ctrlk_gaw]
set_mode explicit preserve
reselect instance 3
set lp [ctrlk_gaw]
eqcheck CS72b-gaw-current-prefix-follows-the-token \
  [list $lf $lp] \
  [list {copyvar i(v.x1.vsx) sel #C} {copyvar i(v.X1.vsx) sel #C}]

set_mode explicit fold
reselect instance 2             ;# the MidNode lab_pin inside X1
set hnf [ctrlk_gaw]
set_mode explicit preserve
reselect instance 2
set hnp [ctrlk_gaw]
eqcheck CS73-gaw-net-hierarchical-path \
  [list $hnf $hnp] \
  [list {copyvar v(x1.midnode) sel #C} {copyvar v(X1.MidNode) sel #C}]

# the WIRE arm, one level down: both halves again
set_mode explicit fold
reselect wire 0
set hwf [ctrlk_gaw]
set_mode explicit preserve
reselect wire 0
set hwp [ctrlk_gaw]
eqcheck CS86-gaw-wire-hierarchical-path \
  [list $hwf $hwp] \
  [list {copyvar v(x1.midnode) sel #C} {copyvar v(X1.MidNode) sel #C}]

# ---------------------------------------------------------------------------
# AE2. create_plot_cmd, ONE LEVEL DOWN -- the fifth sender's PATH half. Every
#      other create_plot_cmd check above runs flat, where `p` is the empty
#      string and the path gate cannot be observed at all.
# ---------------------------------------------------------------------------
proc plotcmd_descended {mode} {
  global tmp presraw
  xschem raw clear
  xschem raw read $presraw tran
  xschem raw casemode $mode
  xschem unhilight_all
  xschem unselect_all
  xschem select instance 2        ;# the MidNode lab_pin inside X1
  xschem hilight
  return [plotcmd_gaw]
}
set pdf [plotcmd_descended fold]
set pdp [plotcmd_descended preserve]
eqcheck CS87-plotcmd-spice-hierarchical-path \
  [list $pdf $pdp] \
  [list {copyvar v(x1.midnode) sel #C} {copyvar v(X1.MidNode) sel #C}]

# The XYCE arm UPPERCASES, so its path half is invisible unless the path has a
# lowercase character in it: with the instance named `X1` the two spellings of
# `X1:` are identical and an ungated strtoupper(p) passes green (measured --
# mutation M9 of the item 4 fix round survived 30/30 on an `X1.` path). `Xa1` is
# the fixture that can tell them apart.
xschem go_back
update
xschem unselect_all
xschem select instance 3            ;# the second subx instance, named Xa1
xschem descend
update
set xyce 1
set xdf [plotcmd_descended fold]
set xdp [plotcmd_descended preserve]
eqcheck CS88-plotcmd-xyce-hierarchical-path \
  [list [pcall xschem get sch_path] $xdf $xdp] \
  [list {.Xa1.} {copyvar XA1:MIDNODE sel #C} {copyvar Xa1:MidNode sel #C}]
set xyce 0

# ---------------------------------------------------------------------------
# AE3. THE GATE MUST SURVIVE A DESCEND, reached through SOURCE 3 ALONE -- no
#      `xschem raw casemode` verb (which is documented as reporting, never
#      acting) and no `-case`. That is all a real user gets for free, and it is
#      exactly the hierarchical case the path gate exists for.
#
#      raw_case_mode_schematic() compares against the CURRENT schematic's
#      labels, so one level down it used to fall silent and the sender dropped
#      to the fold floor -- both halves refolded. The verdict is now stamped on
#      the Raw at read time and replayed while we are inside that hierarchy.
# ---------------------------------------------------------------------------
xschem clear force
xschem load $tmp/hier.sch
update
xschem raw clear
xschem raw read $presraw tran        ;# no -case, no casemode verb
set ::sim_case_mode fold             ;# and the floor says fold
reselect instance 1                  ;# top-level MidNode lab_pin
set s3top [ctrlk_gaw]
xschem unselect_all
xschem select instance 0
xschem descend
update
reselect instance 2                  ;# MidNode lab_pin inside X1
set s3net [ctrlk_gaw]
reselect instance 1                  ;# the vsource Vs inside X1
set s3cur [ctrlk_gaw]
eqcheck CS84-source3-survives-descend \
  [list [pcall xschem raw casemode -all] $s3top $s3net $s3cur] \
  [list {preserve schematic} {copyvar v(MidNode) sel #C} \
        {copyvar v(X1.MidNode) sel #C} {copyvar i(V.X1.Vs) sel #C}]

# ...and it must not depend on the user having HAPPENED to do something at the
# top level first. Read the raw, descend straight away, cross-probe: the verdict
# is stamped on the Raw at READ time, when its own schematic is guaranteed to be
# the current one, so there is nothing left for the descend to un-resolve.
xschem clear force
xschem load $tmp/hier.sch
update
xschem raw clear
xschem raw read $presraw tran        ;# no -case, no casemode verb, no top gesture
set ::sim_case_mode fold
xschem unselect_all
xschem select instance 0
xschem descend
update
reselect instance 2
set s3imm [ctrlk_gaw]
eqcheck CS84b-source3-primed-at-read-time \
  [list [pcall xschem get sch_path] $s3imm] \
  [list {.X1.} {copyvar v(X1.MidNode) sel #C}]

# ---------------------------------------------------------------------------
# AF. hilight_net -> the BUILT-IN graph: send_net_to_graph, send_current_to_graph.
#     A live .graphdialog is what act_highlight_send_waveform reads as
#     "XSCHEM_GRAPH"; graph_add_nodes_from_list is where the query lands.
# ---------------------------------------------------------------------------
proc graph_add_nodes_from_list {nodelist} { set ::captured $nodelist }
toplevel .graphdialog
update
# the node tokens the graph was handed; the colour that follows each one is
# xctx->hilight_color and is not what this suite is about
proc ctrlk_graph {} {
  set ::captured {}
  xschem callback .drw 2 100 100 107 0 0 0
  update
  set r {}
  foreach {n c} [string trim $::captured] { lappend r $n }
  return $r
}

# send_current_to_graph() drops the path components ABOVE the level the raw was
# read at, so the hierarchy is only in the query when the raw belongs to the
# TOP. Read it there, then descend -- otherwise the path half of this sender is
# never exercised and the check would be a token-only check wearing a
# hierarchy's clothes.
proc hier_with_top_raw {mode} {
  global tmp presraw
  xschem clear force
  xschem load $tmp/hier.sch
  update
  xschem raw clear
  xschem raw read $presraw tran      ;# level 0: the raw belongs to hier.sch
  xschem raw casemode $mode
  xschem unselect_all
  xschem select instance 0
  xschem descend
  update
}
hier_with_top_raw fold
reselect instance 2
set gnf [ctrlk_graph]
hier_with_top_raw preserve
reselect instance 2
set gnp [ctrlk_graph]
eqcheck CS74-graph-net-hierarchical [list $gnf $gnp] [list {x1.midnode} {X1.MidNode}]

hier_with_top_raw fold
reselect instance 1
set gif [ctrlk_graph]
hier_with_top_raw preserve
reselect instance 1
set gip [ctrlk_graph]
eqcheck CS75-graph-current-hierarchical \
  [list $gif $gip] [list {i(v.x1.vs)} {i(V.X1.Vs)}]

# the same measured prefix rule on the graph sender: a lowercase device name
# keeps a lowercase prefix under `preserve`
hier_with_top_raw fold
reselect instance 3
set glf [ctrlk_graph]
hier_with_top_raw preserve
reselect instance 3
set glp [ctrlk_graph]
eqcheck CS75b-graph-current-prefix-follows-the-token \
  [list $glf $glp] [list {i(v.x1.vsx)} {i(v.X1.vsx)}]

destroy .graphdialog
update

# ---------------------------------------------------------------------------
# AG. THE RECEIVER SIDE: hilight_graph_node() (hilight.c), reached per graph
#     node per REDRAW from draw.c's auto_hilight_graph_nodes path. It turns a
#     simulator name back into a (path, token) pair; `xschem list_hilights all`
#     prints exactly that pair, so the parse is observed directly rather than
#     through whatever the highlight happens to look like.
#
#     It takes NO mode, deliberately: it is on a redraw path and the mode
#     resolution has no cache (147 ms at 2000 instances, item 3 receipt §5).
#     A parse is the same in every mode.
# ---------------------------------------------------------------------------
proc mkgraph {nodes} {
  global tmp
  wr $tmp/gr.sch "v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=MidNode}
B 2 -400 -200 400 200 {flags=graph
y1=0
y2=2
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=0
x2=2e-05
divx=5
subdivx=1
node=\"$nodes\"
color=4
dataset=-1
unitx=1
logx=0
logy=0}
"
}
# the parsed (path, token) pairs the redraw produced, sorted so the hash order
# of the highlight table cannot make this flaky
proc parsed {nodes} {
  global tmp presraw
  mkgraph $nodes
  xschem clear force
  xschem load $tmp/gr.sch
  xschem raw clear
  xschem raw read $presraw tran
  xschem unhilight_all
  xschem redraw
  update
  set out {}
  foreach line [split [xschem list_hilights all] "\n"] {
    if {[string trim $line] eq ""} continue
    # "<path>  <token>  <value>". The token may carry the leading uglyfication
    # space that marks a device current (hilight.c), and a propagated label
    # entry carries two, so it cannot be split on whitespace -- anchor on the
    # two-space separators instead.
    if {[regexp {^(\S+)  (.*)  (-?[0-9]+)$} $line -> pth tokn val]} {
      lappend out [list $pth $tokn]
    } else {
      lappend out [list UNPARSED $line]
    }
  }
  return [lsort $out]
}

# the shape send_current_to_graph writes, in the two spellings item 4 makes it
# write. They must parse to the SAME structure, differing only in case.
eqcheck CS76-parse-lowercase-current [parsed {i(v.x1.vs)}] {{.x1. { vs}}}
eqcheck CS77-parse-mixed-current     [parsed {i(V.X1.Vs)}] {{.X1. { Vs}}}
# and the enumeration really was an enumeration: I(v...) / i(V...) were never
# both listed, so a mixed prefix fell through to the 2-character `i(` arm and
# split a bogus `.V.X1.` path off the front
eqcheck CS78-parse-mixed-prefix-both-ways [parsed {I(v.X1.vS)}] {{.X1. { vS}}}
# a flat current keeps working in either case
eqcheck CS79-parse-flat-current [list [parsed {i(vs)}] [parsed {i(Vs)}]] \
  {{{. { vs}}} {{. { Vs}}}}
# voltages: the `v(`/`V(` pair was already enumerated, so these are regression
# guards -- and the name resolves against the schematic, which propagates a
# second (label) entry
eqcheck CS80-parse-voltage-both-cases \
  [list [parsed {v(MidNode)}] [parsed {V(MidNode)}]] \
  {{{. MidNode} {. {  l1}}} {{. MidNode} {. {  l1}}}}
# ANCHORED. `zi(vs)` matches "i(" at offset 1; the old code advanced a fixed 2
# from position 0 regardless and produced the token " (vs" -- a device current
# named "(vs". Anchored it stays one bare token.
eqcheck CS81-parse-is-anchored [parsed {zi(vs)}] {{. zi(vs}}

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_hilight_case_senders: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
