# ASE-L stops folding the expressions it ships to the simulator — casemode batch
# item 9 (PLAN.md §3b item 9, §D6 part 1; DECISIONS.md A1).
#
# Until now `ase::ui::sod_expr` lowercased every token unconditionally, and
# `ase::ui::sod_qualify`'s current arm lowercased the hierarchy path and hard-coded
# the branch prefix `v.`.  A net drawn `TopNet` therefore reached the deck as
# `v(topnet)` in EVERY mode — correct under `fold`, and under `distinguish` a card
# that ngspice answers with `rc=1, zero vectors, analysis not run` (PLAN §F2), i.e.
# every trace in the session lost.
#
# What this file pins, in three groups:
#
#   A1 (the safety net).  Under `fold` every composed expression is BYTE-IDENTICAL
#   to the literal the shipped suites already assert — `v(topnet)` (0161 HP4),
#   `i(v9)` (HP5), `v(x1.x2.mid)` (HP10), `i(v.x1.x2.v1)` (HP11), `v(net1)`
#   (unnamed_net AN11), `i(v1)` (interact H1).  Those literals are repeated here
#   deliberately: this file is where a fold regression is supposed to be caught,
#   and a check that only says "the two modes differ" would pass with both of them
#   wrong.
#
#   The two rulings (spec `simulator_profiles.md` §13):
#     * the MODE IS A REQUIRED ARGUMENT of `sod_expr`, never a default — an
#       omitted mode under `distinguish` loses a whole simulation silently, and a
#       default cannot fail loudly (§13.2, SC195);
#     * `sod_qualify` gains NO mode at all.  It produces the SCHEMATIC's own
#       spelling and the branch prefix follows the TOKEN's first character; the
#       whole case mapping lives in `sod_expr` and nowhere else (§13.3, SC201).
#
#   Agreement with item 4.  `hilight.c`'s `send_current_to_graph()` and this path
#   are two roads to the same simulator.  Item 4 MEASURED, on ver_50, that a deck
#   naming the source `Vs` yields `i(V.X1.Vs)` under preserve while a deck naming
#   it `vs` yields `i(v.X1.vs)` — the prefix is the device's own first character,
#   folded along with everything else.  SC203/SC203b reproduce both rows on a
#   mixed-case fixture (`Xm`/`Xl`/`Vs`/`vs2`), byte for byte.
#
# Legs (SC*):
#   SC192-SC196   `sod_expr`: the three modes, the `#` strip, buses, the required
#                 argument, and the purity contract (no engine, nothing loaded).
#   SC197-SC201   the shipped `ase_hier` fixture: A1 literals under `fold`, their
#                 preserve mirrors, and `sod_qualify`'s mode-freedom.
#   SC202-SC204   the mixed-case fixture: item 4's two measured rows, the path that
#                 is no longer folded, buses, and `distinguish` == `preserve` here.
#   SC205-SC207   where the mode comes from: the global floor, a profile row that
#                 beats it, a garbage floor that is not a request, and the click
#                 site resolving it ONCE per gesture.
#   SC208-SC209   (fix round) the resolve is READ-ONLY — a pick makes no
#                 `::set_sim_defaults` call, so it cannot commit an open
#                 Simulation Configuration dialog's unsaved edits; a virgin
#                 `sim()` is still built; a resolver THROW is announced, not
#                 silently folded; and a REAL session stamped at a NON-default
#                 profile row is followed, by `sod_case_mode` and by the pick.
#   SC211         (fix round) the branch prefix on a device renamed away from
#                 v/V — the one place A1 byte-identity does NOT hold, measured.
#
# No simulator is launched and none is needed; nothing here depends on ver_50.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_sod_case.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
## call a possibly-missing proc without aborting the file (RED-first: these procs
## and this arity do not exist before the item, and the later legs must still
## report rather than the file dying with one FATAL).
proc pcall {script} {
  if {[catch {uplevel #0 $script} r]} { return "ERR: $r" }
  return $r
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here   [file normalize [file dirname [info script]]]
set fixdir [file join $here fixtures ase_hier]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_sod_case]

# --- SC192-SC196  sod_expr, with NOTHING loaded --------------------------------
# Purity first, exactly as test_ase_interact H1 and 0161 HP1 do: this whole group
# runs before any `xschem load`.

## A1 column | preserve column | distinguish column, one assertion each so a
## regression names the mode it broke.
check "SC192 (A1) sod_expr voltage folds under fold — 0161 HP1's literal" \
  [pcall {ase::ui::sod_expr voltage MID fold}] {v(mid)}
check "SC192b sod_expr voltage keeps the schematic's case under preserve" \
  [pcall {ase::ui::sod_expr voltage MID preserve}] {v(MID)}
check "SC192c ... and under distinguish" \
  [pcall {ase::ui::sod_expr voltage MID distinguish}] {v(MID)}
## B2b's "absence is unknown" governs a FILE's verdict; for a run there is no such
## thing as emitting an expression in no mode, so an unrecognised mode folds — the
## conservative direction, and the one A1 already makes the default everywhere.
check "SC192d an unrecognised mode folds (conservative, never verbatim)" \
  [pcall {ase::ui::sod_expr voltage MID sideways}] {v(mid)}

check "SC193 (A1) sod_expr current folds under fold — H1/HP2's literal" \
  [pcall {ase::ui::sod_expr current V1 fold}] {i(v1)}
check "SC193b sod_expr current keeps its case under preserve" \
  [pcall {ase::ui::sod_expr current V1 preserve}] {i(V1)}

## issue 0154's `#` strip is mode-independent and must still compose.
check "SC194 (A1) the auto-net marker is stripped and folded — AN11's literal" \
  [pcall {ase::ui::sod_expr voltage {#NET1} fold}] {v(net1)}
check "SC194b the marker is stripped WITHOUT folding under preserve" \
  [pcall {ase::ui::sod_expr voltage {#NET1} preserve}] {v(NET1)}
## AN12's literal and its preserve mirror in ONE assertion: a mutation that fixed
## the fold arm by breaking the preserve arm cannot pass either half.
check "SC194c (A1) a named net: fold gives AN12's literal, preserve keeps it" \
  [list [pcall {ase::ui::sod_expr voltage OUT fold}] \
        [pcall {ase::ui::sod_expr voltage OUT preserve}]] {v(out) v(OUT)}
## issue 0159 hands sod_expr ONE BIT, brackets and all.
check "SC194d a bus BIT keeps its brackets in both modes" \
  [list [pcall {ase::ui::sod_expr voltage {BUS[1]} fold}] \
        [pcall {ase::ui::sod_expr voltage {BUS[1]} preserve}]] \
  [list {v(bus[1])} {v(BUS[1])}]

## RULING (§13.2): the mode is REQUIRED. A defaulted mode is a silent fold, and a
## silent fold under `distinguish` is `rc=1, zero vectors` — the whole session's
## data. This check goes GREEN the moment somebody re-adds `{mode fold}`.
check "SC195 the mode is a REQUIRED argument — a 2-argument call errors" \
  [catch {ase::ui::sod_expr voltage OUT}] 1

## PURITY, with teeth: `xschem` is renamed away, so a sod_expr that reached for the
## engine (for the mode or for anything else) errors instead of answering.
rename xschem ase_sod_case_real_xschem
set ::sc196 [list [pcall {ase::ui::sod_expr voltage MID fold}] \
                  [pcall {ase::ui::sod_expr current Vs preserve}]]
rename ase_sod_case_real_xschem xschem
check "SC196 sod_expr is PURE — it answers with the `xschem` command gone" \
  $::sc196 {v(mid) i(Vs)}

## POSITIVE CONTROL for the §13.2 ruling, added in the fix round. SC196 proves
## sod_expr does not reach for the ENGINE; it says nothing about a GLOBAL. With
## the floor at `preserve` and the ARGUMENT at `fold`, the argument must win — a
## sod_expr that consulted `$::sim_case_mode` in the fold direction would pass
## every other check in this file (only the opposite disagreement, floor fold vs
## resolved preserve, was pinned, by SC207c).
set ::sim_case_mode preserve
check "SC196b the fold arm obeys the ARGUMENT, not the global floor" \
  [pcall {ase::ui::sod_expr voltage MID fold}] {v(mid)}
unset -nocomplain ::sim_case_mode

# --- the pick harness (0160/0161 idiom): stub the queues, no ASE session needed --
set ::queued {}
set ::hilit  {}
proc ase::ui::dp_queue {key ex {kind {}} {token {}}} {
  lappend ::queued $ex ; lappend ::hilit $token
}
proc ase::ui::sod_queue {key ex} { lappend ::queued $ex }
proc ase::ui::bus_dialog {key token bits} { return $::bus_dialog_answer }
set ::bus_dialog_answer {}
set ::notices {}
if {[info commands ciw_echo] ne {}} { rename ciw_echo real_ciw_echo }
proc ciw_echo {msg args} { lappend ::notices $msg }

## one pick, returning what it queued. The default key `k` is not a real session
## key, so the mode resolves through the tool's DEFAULT profile row and the GLOBAL
## FLOOR under it — which is what `casemode` sets below. SC209 repoints `::pickkey`
## at a REAL session so the stamped-row path gets driven too.
set ::pickkey k
proc pick {x y {mode plot} {flavor tobeplotted}} {
  set kk $::pickkey
  array set ase::ui::sod [list $kk,flavor $flavor $kk,mode $mode $kk,count 0]
  xschem unselect_all
  set ::queued {} ; set ::hilit {} ; set ::notices {}
  ase::ui::sod_click $kk $x $y
  return $::queued
}
proc casemode {m} { set ::sim_case_mode $m }

if {[catch {

if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }

# --- the mixed-case fixture -----------------------------------------------------
# A copy of tests/headless/fixtures/ase_hier with CAPITALS where it matters:
# instances `Xm`/`Xl`, net `MidNode`, bus `Bus[1:0]`, sources `Vs` (capital) and
# `vs2` (lowercase) — the two spellings item 4 measured. Cell names are changed too
# so the copies cannot shadow the originals on the library path.
set cdir [file join $scratch casefix]
file mkdir $cdir
proc fixcopy {src dst maps} {
  set f [open $src r] ; set t [read $f] ; close $f
  set f [open $dst w] ; puts -nonewline $f [string map $maps $t] ; close $f
}
fixcopy [file join $fixdir ase_hier_leaf.sym] [file join $cdir sodcase_leaf.sym] {}
fixcopy [file join $fixdir ase_hier_mid.sym]  [file join $cdir sodcase_mid.sym]  {}
fixcopy [file join $fixdir ase_hier_leaf.sch] [file join $cdir sodcase_leaf.sch] \
  [list {name=V1} {name=Vs} {lab=mid} {lab=MidNode} {lab=bus[1:0]} {lab=Bus[1:0]}]
## a SECOND source, named in lower case — item 4's row 2. Unwired on purpose: the
## pick classifies on the instance body, and nothing here netlists.
set f [open [file join $cdir sodcase_leaf.sch] a]
puts $f {C {devices/vsource.sym} 600 30 0 0 {name=vs2 value=0}}
## and a THIRD, named away from v/V entirely (fix round, SC211). Nothing in
## sod_click validates the first letter — it reads `cell::type` and takes the
## instance's `name` verbatim — and `vsource_pwl.sym` ships templated `name=E1`,
## so this is a reachable production spelling, not a contrived one.
puts $f {C {devices/vsource.sym} 700 30 0 0 {name=E1 value=0}}
close $f
fixcopy [file join $fixdir ase_hier_mid.sch] [file join $cdir sodcase_mid.sch] \
  [list {ase_hier_leaf.sym} {sodcase_leaf.sym} {name=x2} {name=Xl}]
fixcopy [file join $fixdir ase_hier_top.sch] [file join $cdir sodcase_top.sch] \
  [list {ase_hier_mid.sym} {sodcase_mid.sym} {name=x1} {name=Xm} {lab=TOPNET} {lab=TopNet}]

set XSCHEM_LIBRARY_PATH "$cdir:$fixdir:$XSCHEM_LIBRARY_PATH"

# --- SC197-SC201  the SHIPPED fixture: A1 literals and their preserve mirrors ----
casemode fold
xschem load [file join $fixdir ase_hier_top.sch]

check "SC197 (A1) top-level net under fold — 0161 HP4's literal" \
  [pick 50 0] {v(topnet)}
casemode preserve
check "SC197b the same pick under preserve keeps the schematic's TOPNET" \
  [pick 50 0] {v(TOPNET)}
casemode distinguish
check "SC197c ... and distinguish spells it the same way" \
  [pick 50 0] {v(TOPNET)}

casemode fold
check "SC198 (A1) top-level source current under fold — HP5's literal" \
  [pick 0 90] {i(v9)}
casemode preserve
check "SC198b the same source under preserve — the case survives the wrap" \
  [pick 0 90] {i(V9)}

casemode fold
xschem unselect_all; xschem select instance x1; xschem descend
xschem unselect_all; xschem select instance x2; xschem descend
check_true "SC199 fixture: descended two levels" \
  [expr {[xschem get currsch] == 2 && [xschem get sch_path] eq {.x1.x2.}}]
check "SC199b (A1) a descended net under fold — HP10's literal" \
  [pick 250 60] {v(x1.x2.mid)}
casemode preserve
## an all-lowercase design carries no case signal at all: the CONTROL that says
## preserve is not uppercasing anything on its own.
check "SC199c an all-lowercase descended net is identical under preserve" \
  [pick 250 60] {v(x1.x2.mid)}

casemode fold
check "SC200 (A1) a descended source current under fold — HP11's literal" \
  [pick 200 30] {i(v.x1.x2.v1)}
casemode preserve
check "SC200b the same current under preserve: prefix and token both capital" \
  [pick 200 30] {i(V.x1.x2.V1)}

## RULING (§13.3): sod_qualify takes NO mode. It answers in the SCHEMATIC's own
## spelling and the same answer in every mode; the case mapping is sod_expr's
## alone. Teeth against re-introducing a mode branch down here.
casemode fold
set sq_fold [pcall {ase::ui::sod_qualify current V1}]
casemode preserve
set sq_pres [pcall {ase::ui::sod_qualify current V1}]
casemode distinguish
set sq_dist [pcall {ase::ui::sod_qualify current V1}]
check "SC201 sod_qualify is MODE-FREE and un-folded — one answer in all 3 modes" \
  [list $sq_fold $sq_pres $sq_dist] {V.x1.x2.V1 V.x1.x2.V1 V.x1.x2.V1}

# --- SC202-SC204  the mixed-case fixture: item 4's measured rows -----------------
casemode fold
xschem load [file join $cdir sodcase_top.sch]
xschem unselect_all; xschem select instance Xm; xschem descend
xschem unselect_all; xschem select instance Xl; xschem descend
check_true "SC202 fixture: descended into .Xm.Xl." \
  [expr {[xschem get sch_path] eq {.Xm.Xl.}}]
check "SC202b (A1) the mixed-case path folds completely under fold" \
  [pick 300 60] {v(xm.xl.midnode)}
casemode preserve
check "SC202c under preserve the PATH keeps its case too, not just the leaf" \
  [pick 300 60] {v(Xm.Xl.MidNode)}

## ITEM 4's MEASUREMENT, reproduced: deck `Vs` -> i(V.<path>.Vs);
##                                   deck `vs` -> i(v.<path>.vs).
check "SC203 preserve, source named Vs: the prefix is the TOKEN's own V" \
  [pick 200 30] {i(V.Xm.Xl.Vs)}
check "SC203b preserve, source named vs2: the same prefix is LOWER case" \
  [pick 600 30] {i(v.Xm.Xl.vs2)}
casemode fold
check "SC203c (A1) under fold both collapse to the shipped v. spelling" \
  [list [pick 200 30] [pick 600 30]] {i(v.xm.xl.vs) i(v.xm.xl.vs2)}

casemode distinguish
check "SC204 distinguish spells an expression exactly as preserve does" \
  [list [pick 300 60] [pick 200 30]] {v(Xm.Xl.MidNode) i(V.Xm.Xl.Vs)}

## a BUS pick fans out per bit (issue 0159) and every bit must carry the mode —
## teeth for the ruling that the mode is resolved ONCE per gesture and used for
## the whole fan-out, not for its first element.
casemode preserve
set ::bus_dialog_answer [list {Bus[1]} {Bus[0]}]
check "SC204b every BIT of a bus pick carries the mode, not just the first" \
  [pick 0 -100] [list {v(Xm.Xl.Bus[1])} {v(Xm.Xl.Bus[0])}]
casemode fold
check "SC204c (A1) the same bus folds completely" \
  [pick 0 -100] [list {v(xm.xl.bus[1])} {v(xm.xl.bus[0])}]
set ::bus_dialog_answer {}

## issue 0153's colour cue still gets the RAW schematic token, never the expression
## and never a case-mapped copy: `xschem hilight_netname` wants the drawn name.
casemode preserve
check "SC204d the 0153 colour cue still gets the RAW token" \
  [list [pick 300 60] $::hilit] [list {v(Xm.Xl.MidNode)} {MidNode}]

# --- SC211  the ONE place A1 byte-identity does NOT hold, and why -------------
# Raised in review: the token-derived prefix changes the FOLD expression for a
# current-pickable instance whose name does not begin with v/V — reachable, since
# `vsource_pwl.sym`/`vsource_arith.sym` are `type=vsource` templated `name=E1`
# and `filesource.sym` `name=A1`, and sod_click validates only `cell::type`.
#
#   HEAD (hard-coded `v.`)  fold: i(v.xm.xl.e1)
#   here (token-derived)    fold: i(e.xm.xl.e1)
#
# MEASURED on ver_50 which of the two the simulator actually has, with a VCVS
# `E1` inside `X1` and render_deck's own deck shape (analyses inside `.control`,
# bare `write`, no vector list):
#   raw Variables:            i(e.x1.e1)   v(n1)  i(v.x1.v1)  i(v2) …
#   `.save i(e.x1.e1)`   ->   rc 0, 1192-byte raw carrying the vector
#   `.save i(v.x1.e1)`   ->   "no data saved for Transient analysis; analysis
#                             not run", 570-byte empty raw — the whole run lost.
# So the old spelling was not "unchanged" for these devices, it was broken; the
# derivation repairs it and agrees with hilight.c's sender_current_prefix()
# (`buf[0] = t[0]`), the other road to the same simulator. Recorded in spec
# §13.3 and in sod_qualify's own comment; this check is so nobody can quietly
# put the literal back.
casemode fold
check "SC211 an E-named vsource: the fold prefix is `e.`, NOT the old `v.`" \
  [pick 700 30] {i(e.xm.xl.e1)}
casemode preserve
check "SC211b ... and under preserve both the prefix and the name keep their case" \
  [pick 700 30] {i(E.Xm.Xl.E1)}

# --- SC205-SC207  where the mode comes from --------------------------------------
## B1's "per simulator, with a global floor", read through
## ase::sim_casemode_requested. Nothing is registered, so the floor answers.
casemode fold
check "SC205 sod_case_mode reads the global floor: fold" \
  [pcall {ase::ui::sod_case_mode k}] fold
casemode preserve
check "SC205b ... preserve" [pcall {ase::ui::sod_case_mode k}] preserve
casemode distinguish
check "SC205c ... distinguish" [pcall {ase::ui::sod_case_mode k}] distinguish
## spec §3: a `set sim_case_mode sideways` in an rc must never become a request.
casemode sideways
check "SC206 a garbage floor is not a request — it folds" \
  [pcall {ase::ui::sod_case_mode k}] fold
check "SC206b ... and the pick that follows it folds too" \
  [pick 300 60] {v(xm.xl.midnode)}
casemode fold

## THE REGISTERED SIMULATOR'S OWN CASEMODE BEATS THE FLOOR (B1). It was a `sim()`
## profile row until the `annotate` merge; B1 is unchanged, the store moved.
pcall {ase::sim_clear}
pcall {ase::sim_register sc207 /bin/sh -casemode preserve}
check_true "SC207 fixture: a simulator really is registered and in force" \
  [expr {[pcall {dict get [ase::sim_status ngspice] entry}] eq {sc207}}]
check "SC207b the registered simulator's casemode beats the floor" \
  [pcall {ase::ui::sod_case_mode k}] preserve
check "SC207c ... and the queued expression follows it, not the floor" \
  [pick 300 60] {v(Xm.Xl.MidNode)}
pcall {ase::sim_clear}
check "SC207d nothing registered, the floor answers again" \
  [pcall {ase::ui::sod_case_mode k}] fold

# --- SC208  the pick is READ-ONLY (fix round) ------------------------------------
# Raised in review, with a reproducer: `ase::sim_profile_resolve` opened with
# `::set_sim_defaults`, and that proc is NOT a read — with the Simulation
# Configuration dialog open it slurps every `.sim…r.$i.cmd` widget straight back
# into `sim($tool,$i,cmd)`. Reached from `sod_case_mode` it therefore COMMITTED
# the user's unsaved dialog edits on every Direct-Plot / Select-On-Design click
# and defeated that dialog's Cancel — a deliberately read-only pick (issue 0204)
# writing unrelated global config. Measured on the shipped tree: `.sim` open,
# `USER-IS-STILL-TYPING` typed into the spice row-0 cmd box, one `sod_click`, and
# the array held that text afterwards — Cancel included.
#
# ⚠ THE CAUSE IS GONE, NOT GUARDED, as of the `annotate` merge: the mode comes
# from the ASE-L registry now, which is built eagerly and has no lazy init, so
# there is nothing on this path that could call `set_sim_defaults`. This row is
# kept anyway and is worth more than it was — it used to assert that a guard was
# in place, and now it asserts that the whole class of write is unreachable, so
# it reddens if anyone re-introduces a `sim()` read here.
#
# The Tk half of this (real dialog, real widget, the string itself) is
# test_ase_dialogs G13, which runs on a display.
casemode fold
rename ::set_sim_defaults ase_sod_case_real_ssd
set ::ssd_calls 0
proc ::set_sim_defaults {args} {
  incr ::ssd_calls
  return [uplevel #0 [linsert $args 0 ase_sod_case_real_ssd]]
}
set ::ssd_calls 0
set ::sc208_ex [pick 300 60]
check "SC208 a pick never calls set_sim_defaults — it cannot commit dialog edits" \
  [list $::ssd_calls $::sc208_ex] {0 v(xm.xl.midnode)}

## ...and with `sim()` NOT THERE AT ALL it still answers correctly, without
## building it. That is the inverse of what this row used to assert: item 6's
## resolver needed a lazily-built array and the fix was to build it ourselves,
## once, guarded (CS163k). The registry needs no array, so the honest claim is
## that a virgin `sim()` is left virgin AND the answer is still right — which is
## also the sharpest possible statement of SC208's read-only property.
set ::ssd_calls 0
catch {unset ::sim}
casemode preserve
set ::sc208b [pcall {ase::ui::sod_case_mode k}]
check "SC208b a virgin sim() is left virgin, and the answer is still right" \
  [list $::ssd_calls [info exists ::sim(tool_list)] $::sc208b] {0 0 preserve}
rename ::set_sim_defaults {}
rename ase_sod_case_real_ssd ::set_sim_defaults

## and the OTHER half of the review finding: a blanket `catch` around the resolve
## turned any resolver failure into a MUTE fold — precisely the silent fold §13.2
## made the mode argument required to prevent. A throw must still fall back to
## fold (we cannot invent a mode) but it must SAY SO.
casemode preserve
rename ase::sim_casemode_requested ase_sod_case_real_spc
proc ase::sim_casemode_requested {backend} { error {resolver exploded} }
set ::notices {}
set ::sc208c [pcall {ase::ui::sod_case_mode k}]
set ::sc208c_said [expr {[llength $::notices] ? 1 : 0}]
rename ase::sim_casemode_requested {}
rename ase_sod_case_real_spc ase::sim_casemode_requested
check "SC208c a resolver THROW folds but is ANNOUNCED, never silent" \
  [list $::sc208c $::sc208c_said] {fold 1}
check "SC208c-sane the real resolver is back" \
  [pcall {ase::ui::sod_case_mode k}] preserve

# --- SC209  a REAL session, and the KEY has to matter -----------------------------
# Raised in review: every SC205-SC207 check passes the literal key `k`, which
# names no session, so `ase::session_state` returns `{}` and the answer always
# came from the same place. A `sod_case_mode` rewritten to ignore its key
# entirely stayed green across all 42 checks. This drives the binding.
#
# ⚠ WHAT THE KEY SELECTS CHANGED AT THE `annotate` MERGE, AND THE ROW IS WEAKER
# FOR IT — said plainly rather than quietly re-scoped. It used to select the
# session's own STAMPED PROFILE ROW, so two sessions could run two different
# simulators at two different case modes. The ASE-L registry has ONE in-force
# entry, so that capability is gone (it is written down in src/ase.tcl, above
# ase::sim_probe_run). What the key still selects is the session's `simulator`
# BACKEND, and that is what these rows now drive: a session naming a backend the
# in-force entry is not for must NOT inherit that entry's case mode.
casemode fold
pcall {ase::sim_clear}
pcall {ase::sim_register sc209 /bin/sh -backend ngspice -casemode distinguish}
dict set ::ase::sessions sc209 state [dict create version 1 simulator ngspice]
## a session on ANOTHER backend: ase::sim_status answers `wrongbackend`, i.e. the
## entry cannot run it, so no mode may be read off that entry. The floor is
## `fold`, so `distinguish` leaking through would be visible here and nowhere
## else.
dict set ::ase::sessions sc209x state [dict create version 1 simulator notngspice]
check "SC209 a REAL session follows the entry in force for ITS backend" \
  [list [pcall {ase::ui::sod_case_mode sc209}] \
        [pcall {ase::ui::sod_case_mode sc209x}] \
        [pcall {ase::ui::sod_case_mode k}]] {distinguish fold distinguish}
set ::pickkey sc209
check "SC209b ... and the QUEUED EXPRESSION follows it" \
  [pick 300 60] {v(Xm.Xl.MidNode)}
set ::pickkey sc209x
check "SC209c ... while a session on another backend, same floor, same click, folds" \
  [pick 300 60] {v(xm.xl.midnode)}
set ::pickkey k
pcall {ase::sim_clear}
catch {dict unset ::ase::sessions sc209}
catch {dict unset ::ase::sessions sc209x}

} err]} { puts "FATAL: $err" ; incr fail }

## restore the real ciw_echo OUTSIDE the catch, so a FATAL cannot leave the stub
if {[info commands real_ciw_echo] ne {}} {
  catch {rename ciw_echo {}}
  catch {rename real_ciw_echo ciw_echo}
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
