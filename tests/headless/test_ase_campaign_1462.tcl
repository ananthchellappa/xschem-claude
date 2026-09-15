# tests/headless/test_ase_campaign_1462.tcl -- ISSUE 1462: ngspice HAS NO
# `.step`, NO CORNER CARD AND NO MONTE CARLO, SO ASE-L RAN EVERY BENCH EXACTLY
# ONCE. PLAN.md Stage 11, task 1: the campaign RUNNER (§11a) and the SAMPLER
# (§11b). The campaign EDITOR is task 2 and `src/ase_window.tcl` is untouched.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# `.step param x 1 3 1` answers `unimplemented dot command '.step'` and ABORTS.
# There is no corner statement, no `.MC` card, no sort, no median, no
# percentile and no histogram. A sweep, a corner set and a Monte Carlo run are
# the GUI's to generate, and ASE-L generated none of them -- the user's own
# `tb_bandgap` bench carries `{name VCCGAUSS value {agauss(1.8, 'ABSVAR', 1)}}`
# in its `variables`, a Monte Carlo distribution written by hand, which ASE-L
# ran ONCE.
#
# ============================================================================
# ⚠ THE MEASUREMENT THAT RESHAPED THE PLAN: `var()` KILLS apt 45.2
# ============================================================================
# PLAN.md §11a's headline mechanism is `.param rv='var(myres)'` in a deck that
# is BYTE-IDENTICAL for every shard, plus `set myres=4700` in the shard's
# `.spiceinit`. MEASURED 2026-09-13 on both binaries:
#
#   fork (46+)    @r1[resistance] = 4.700000e+03
#   apt 45.2      Undefined parameter [var]
#                 Expression err: var(myres)
#                 Formula() error.
#                 ERROR: fatal error in ngspice, exit(1)
#
# `var()` and `vec()` arrived upstream in `aa1242ac7` on 2025-10-16, **50
# commits after ngspice-45.2**, first shipped in ngspice-46. So the
# byte-identical deck is unavailable on the binary a new Ubuntu user has, and
# asking for it does not degrade -- it kills the run. Every axis therefore
# re-renders the shard's own deck, or delivers its point with `alter`.
#
# ============================================================================
# ⚠ AND THE SIXTH ACCEPTED-AND-INERT CASE: `setseed` IN `.spiceinit`
# ============================================================================
# MEASURED, both binaries, rc 0, nothing on either stream, and a DIFFERENT
# number every run -- indistinguishable from no seed at all. `main.c` reads the
# start-up file at `:1266-1330` and calls `initw()` -- `srand(getpid());
# TausSeed();` -- at `:1371`, AFTER it. The same `setseed 12345` inside
# `.control` answers `3.950885e-01` on both binaries on every run.
#
# ⚠ AND THE ONE THE PLAN FORBIDS IS THE RIGHT ONE HERE. APPENDIX §4.4 Trap B
# says never emit `.option seed=<n>` for a statistical campaign, because
# `eval_opt()` re-seeds on EVERY re-parse and a `.control` loop that `reset`s
# draws the same sample every time. A SHARD RUNNER NEVER `reset`s. Measured
# with seeds 7/8/9 on both binaries, one deck carrying a netlist-level `agauss`
# AND an interpreter-level `sgauss`:
#
#   seed=7 -> 9.068280e+02 / -9.31720e-01     identical on a second run
#   seed=8 -> 1.056375e+03 /  5.637512e-01    and identical on the other binary
#   seed=9 -> 1.005625e+03 /  5.625111e-02
#
# while `setseed 12345` in `.control` fixes the interpreter's draw at
# `3.950885e-01` and leaves the NETLIST's `agauss` at 1053.4 / 853.9 / 995.4 on
# three consecutive runs -- because a netlist-level draw happens at PARSE time.
#
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
#    sections SA AX KN SR MD SH DK RF IX RN PD NT -- pure Tcl and a /bin/sh
#                   stand-in, identical on both arms
#    section  EE -- starts BOTH real binaries, self-skips with the path printed
#                   when one is absent
#
# NEW AT 133, both arms, `diff` of the two ok-lists empty. The sabotage campaign
# is in doc/claude/ase_analyses_batch/receipts/38-stage-11-runner.md.
#
# AND RAISED 133 -> 161, both arms (issue 1469 -- a seed ngspice does not honour
# was written into the shard decks and reported as a seed): section SR (20 rows,
# pure Tcl), SR9 and SR10 in section RN (the stand-in), and EE7 EE8 EE9 once per
# binary in section EE. With a binary absent its three EE rows go with the rest
# of its EE block. The sabotage campaign is in
# doc/claude/ase_analyses_batch/receipts/45-1469-campaign-seed-range.md.
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_campaign_1462.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_campaign_1462.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch campaign1462]
catch {test_sim_registry_isolate}

## ⚠ EVERY READER IS TOTAL AND ANSWERS A COMPARABLE VALUE. A row whose extractor
## raises cannot disagree with anything, and `--nogui --pipe` exits 0 on an
## uncaught mid-script error -- so a killed suite looks like a pass.
proc c_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}

proc c_state {args} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create cell rc lib $scratch]
  dict set st rundir [file join $scratch run]
  dict set st simulator ngspice
  dict set st save_all_v 1
  dict set st analyses {{type op enabled 1}}
  foreach {k v} $args { dict set st $k $v }
  return $st
}
proc c_sweep {args} { return [dict create {*}$args] }
proc c_netlist {} { return "* rc\nv1 a 0 1\nr1 a 0 1k\n.end\n" }
proc c_deck {st} { return [c_ans ase::backend::ngspice::render_deck $st [c_netlist]] }
proc c_at {deck pat} {
  set i 0
  foreach l [split $deck "\n"] { if {[regexp $pat $l]} { return $i } ; incr i }
  return -1
}
proc c_ids {refs} { set o {} ; foreach r $refs { lappend o [lindex $r 0] } ; return [lsort $o] }

# ============================================================================
# SECTION SA -- §11b: THE GUI DRAWS THE SAMPLES, AND THEY ARE REPRODUCIBLE
# ============================================================================
# ADE-L cannot show you its samples. Every row here is about the sample set
# being a VALUE -- the same one every time, on any machine -- rather than an
# event that happened inside a simulator once.

check {SA1 the same spec and seed draw the same samples, twice in one process} \
  [expr {[c_ans ase::mc_draw {dist normal mean 1.8 sigma 0.05} 8 12345] eq \
         [c_ans ase::mc_draw {dist normal mean 1.8 sigma 0.05} 8 12345]}] 1

## THE NON-VACUITY CONTROL FOR SA1. A generator that always returned the same
## list would pass SA1 by doing nothing.
check {SA1b a DIFFERENT seed draws a different sample set} \
  [expr {[c_ans ase::mc_draw {dist normal mean 1.8 sigma 0.05} 8 12345] ne \
         [c_ans ase::mc_draw {dist normal mean 1.8 sigma 0.05} 8 12346]}] 1

check {SA2 the sample count is what was asked for} \
  [list [llength [c_ans ase::mc_draw {dist normal mean 0 sigma 1} 1 7]] \
        [llength [c_ans ase::mc_draw {dist normal mean 0 sigma 1} 25 7]] \
        [llength [c_ans ase::mc_draw {dist uniform min 0 max 1} 13 7]]] {1 25 13}

## ⚠ A GOLDEN ON THE EXACT SAMPLE SET. Park-Miller is integer arithmetic, so
## this list is the same on every platform and every Tcl build. If it moves, the
## sampler changed and every committed campaign redraws.
check {SA3 the uniform stream is a golden} \
  [c_ans ase::mc_draw {dist uniform min 0 max 1} 5 1] \
  {0.383502 0.519416 0.830965 0.0345721 0.0534616}

check {SA4 a uniform sample never leaves its bounds} \
  [apply {{} {
    set bad 0
    foreach v [c_ans ase::mc_draw {dist uniform min 3 max 4} 200 99] {
      if {$v < 3 || $v > 4} { incr bad }
    }
    return $bad
  }}] 0

## ⚠ `bounded` IS ngspice's `limit(nom, avar)`: nom PLUS or MINUS avar, never
## between. A sampler that returned the interval would be a different
## distribution wearing the same name.
check {SA5 a bounded sample is only ever nom+delta or nom-delta} \
  [lsort -unique [c_ans ase::mc_draw {dist bounded nom 10 delta 1} 60 4]] {11 9}

## THE WARM-UP, AND WHY IT IS NOT DECORATION. Park-Miller's state IS its output,
## so seed 1 without a warm-up gives a first uniform of 7.8e-6, which Box-Muller
## turns into a 4-sigma opening sample -- every campaign seeded with a small
## number would open with an outlier the user reads as the circuit's tail.
check {SA6 a small seed does not open with an outlier} \
  [apply {{} {
    set bad 0
    foreach s {1 2 3 4 5} {
      set v [lindex [c_ans ase::mc_draw {dist normal mean 0 sigma 1} 1 $s] 0]
      if {abs($v) > 3.0} { incr bad }
    }
    return $bad
  }}] 0

check {SA7 the distributions core knows, and it knows no simulator's spelling} \
  [lsort [dict keys [c_ans ase::mc_dists]]] {bounded normal uniform}

check {SA8 an unknown distribution is refused, not silently drawn} \
  [c_ans ase::mc_draw {dist agauss nom 1 avar 1 sigma 1} 3 1] \
  {RAISED:ase: unknown distribution 'agauss'}

check {SA9 a distribution missing a parameter is refused by name} \
  [list [c_ans ase::mc_draw {dist normal mean 1} 3 1] \
        [c_ans ase::mc_draw {dist uniform min 1} 3 1]] \
  [list {RAISED:ase: distribution 'normal' needs 'sigma'} \
        {RAISED:ase: distribution 'uniform' needs 'max'}]

check {SA10 a non-numeric parameter is refused rather than becoming NaN} \
  [c_ans ase::mc_draw {dist normal mean x sigma 1} 3 1] \
  {RAISED:ase: distribution 'normal' needs a number for 'mean'}

check {SA11 a non-positive sample count is refused} \
  [list [c_ans ase::mc_draw {dist normal mean 0 sigma 1} 0 1] \
        [c_ans ase::mc_draw {dist normal mean 0 sigma 1} -2 1]] \
  [list {RAISED:ase: a distribution needs a positive sample count} \
        {RAISED:ase: a distribution needs a positive sample count}]

## ⚠ SIX DIGITS, AND IT IS A DECISION. A gaussian needs `log` and `sqrt`, whose
## last bits are libm's rather than arithmetic's; a sample printed to 17 digits
## is a golden that can differ between machines while the campaign is identical.
check {SA12 a sample carries six significant digits, so a golden is portable} \
  [apply {{} {
    set bad 0
    foreach v [c_ans ase::mc_draw {dist normal mean 1.23456789 sigma 0.0001} 40 5] {
      if {[string length [string map {- {} . {} e {} + {}} $v]] > 7} { incr bad }
    }
    return $bad
  }}] 0

check {SA13 seed 0 is folded rather than refused, and stays reproducible} \
  [expr {[c_ans ase::mc_draw {dist uniform min 0 max 1} 4 0] eq \
         [c_ans ase::mc_draw {dist uniform min 0 max 1} 4 0]}] 1

# ============================================================================
# SECTION AX -- THE AXES AND THE ODOMETER
# ============================================================================

check {AX1 a bench with no sweep key runs once, and says so by answering 0} \
  [list [c_ans ase::campaign_enabled [c_state]] \
        [c_ans ase::campaign_count   [c_state]] \
        [c_ans ase::campaign_points  [c_state]]] {0 0 {}}

check {AX2 a sweep with no axes is not a campaign} \
  [c_ans ase::campaign_enabled [c_state sweep [c_sweep enabled 1 axes {}]]] 0

check {AX3 `enabled 0` switches a configured campaign off without deleting it} \
  [list [c_ans ase::campaign_enabled \
          [c_state sweep [c_sweep enabled 0 axes {{kind temp values {27 85}}}]]] \
        [c_ans ase::campaign_enabled \
          [c_state sweep [c_sweep enabled 1 axes {{kind temp values {27 85}}}]]]] {0 1}

set AXST [c_state sweep [c_sweep enabled 1 axes {
  {kind var name myres values {1k 2k}}
  {kind temp values {27 85 125}}}]]

## ⚠ THE LAST AXIS MOVES FASTEST, which is the order a person reads a nested
## loop in and the order `index.tsv` sorts in.
check {AX4 the odometer runs the LAST axis fastest} \
  [c_ans ase::campaign_points $AXST] \
  {{1k 27} {1k 85} {1k 125} {2k 27} {2k 85} {2k 125}}

check {AX5 the point count is the product of the axis lengths} \
  [c_ans ase::campaign_count $AXST] 6

check {AX6 an axis names its own column when the state gives it no label} \
  [list [c_ans ase::campaign_axis_label {kind var name myres}] \
        [c_ans ase::campaign_axis_label {kind temp}] \
        [c_ans ase::campaign_axis_label {kind corner index 0}] \
        [c_ans ase::campaign_axis_label {kind inst target r1 param resistance}] \
        [c_ans ase::campaign_axis_label {kind model model nch param vth0}]] \
  {myres temp corner r1.resistance nch.vth0}

check {AX7 an explicit label wins over the derived one} \
  [c_ans ase::campaign_axis_label {kind temp label {Ambient}}] {Ambient}

## A DRAWN AXIS IS A COLUMN LIKE ANY OTHER, and its values come from the
## campaign's own seed offset by the axis position -- so two axes drawing from
## the same distribution do not draw the same numbers.
set AXDR [c_state sweep [c_sweep enabled 1 seed 42 axes {
  {kind var name a draw {dist normal mean 1 sigma 0.1 n 4}}
  {kind var name b draw {dist normal mean 1 sigma 0.1 n 4}}}]]
check {AX8 a drawn axis expands to its samples} \
  [llength [c_ans ase::campaign_points $AXDR]] 16
check {AX8b two axes on one seed draw DIFFERENT samples} \
  [apply {{st} {
    set p [c_ans ase::campaign_points $st]
    set c1 {} ; set c2 {}
    foreach r $p { lappend c1 [lindex $r 0] ; lappend c2 [lindex $r 1] }
    return [expr {[lsort -unique $c1] ne [lsort -unique $c2]}]
  }} $AXDR] 1
check {AX8c and the same campaign redraws the same samples} \
  [expr {[c_ans ase::campaign_points $AXDR] eq [c_ans ase::campaign_points $AXDR]}] 1

check {AX9 an axis with neither values nor a draw contributes no points at all} \
  [c_ans ase::campaign_points \
     [c_state sweep [c_sweep enabled 1 axes {{kind temp values {27}} {kind var name x}}]]] {}

check {AX10 a literal `values` list beats a `draw` on the same axis} \
  [c_ans ase::campaign_axis_values {kind var name x values {5 6} draw {dist normal mean 0 sigma 1 n 9}} 1 0] \
  {5 6}

check {AX11 a seed that is not an integer is no seed at all} \
  [list [c_ans ase::campaign_seed [c_state sweep [c_sweep seed 7 axes {x}]]] \
        [c_ans ase::campaign_seed [c_state sweep [c_sweep seed abc axes {x}]]] \
        [c_ans ase::campaign_seed [c_state sweep [c_sweep axes {x}]]]] {7 {} {}}

# ============================================================================
# SECTION KN -- WHAT THE ADAPTER DECLARES, AND D34
# ============================================================================

check {KN1 ngspice declares the five axis kinds Stage 11 names} \
  [lsort [dict keys [c_ans ase::campaign_axis_kinds ngspice]]] \
  {corner inst model temp var}

## ⚠ WHICH KINDS COST A RE-PARSE IS A FACT ABOUT THE SIMULATOR, and it is the
## whole input to the mode decision. A corner CANNOT be `alter`ed --
## `.lib <file> <section>` is resolved inside `inp_readall()` before any control
## statement runs -- so corners always shard.
check {KN2 the re-parse classes are the measured ones} \
  [apply {{} {
    set o {}
    foreach k {var temp corner inst model} {
      lappend o $k [c_ans ase::campaign_kind_reparse ngspice $k]
    }
    return $o
  }}] {var 1 temp 1 corner 1 inst 0 model 0}

## ⚠ AND THE DEFAULT IS THE EXPENSIVE ANSWER, WHICH KN2 CANNOT SEE. Every kind
## ngspice declares carries `reparse` explicitly, so the default never fires
## through KN2 -- sabotage m13 flipped it to the cheap answer and the suite stayed
## green. `collapsible` is a claim that a CHEAPER mode is available, and an
## unmeasured mechanism has not earned it.
## ⚠ THE HOOK IS A COMMAND PREFIX RESOLVED BY NAME, so a fixture backend needs a
## real proc: `[list apply {...}]` is not callable as `$h ...` and the `catch`
## every hook reader carries would swallow the failure, leaving the row green on
## an empty answer. Measured -- the first version of KN2b passed for exactly that
## reason.
proc kn_bare_kinds {} {
  return [dict create bare [dict create label {Bare} statekey temperature]]
}
proc kn_dual_kinds {} {
  return [dict create dual [dict create label {Dual} statekey temperature reparse 1]]
}
proc kn_other_kinds {} {
  return [dict create other [dict create label {Other} reparse 0]]
}
proc kn_dual_lines {state axis val} { return [list "SHOULD-NOT-BE-EMITTED $val"] }

check {KN2b an undeclared kind, and a declared kind that says nothing about re-parsing, both cost one} \
  [apply {{} {
    ase::register_backend defcamp [dict create \
      render_deck x run_cmd x log_file x result_probe x raw_file x \
      campaign_axis_kinds kn_bare_kinds]
    return [list [c_ans ase::campaign_kind_reparse ngspice nosuchkind] \
                 [llength [dict keys [c_ans ase::campaign_axis_kinds defcamp]]] \
                 [c_ans ase::campaign_kind_reparse defcamp bare] \
                 [c_ans ase::campaign_kind_reparse defcamp nosuchkind]]
  }}] {1 1 1 1}

## ⚠ AN AXIS WITH A `statekey` IS DELIVERED BY THE STATE, FULL STOP -- it is
## never ALSO handed to the control-line hook. Nothing in ngspice's adapter
## declares both, so sabotage m24 removed the guard and no row noticed; a
## synthetic backend that declares both is what makes the contract falsifiable.
## Without it an adapter could deliver one point twice, once as a card and once
## as a command, and the second would silently win.
check {KN9 a kind with a statekey is NOT also delivered as a control line} \
  [apply {{} {
    ase::register_backend dualcamp [dict create \
      render_deck x run_cmd x log_file x result_probe x raw_file x \
      campaign_axis_kinds kn_dual_kinds campaign_control_lines kn_dual_lines]
    set st [dict create sweep [dict create axes {{kind dual}} point {77}]]
    ## the positive control: the SAME backend really does emit for a kind with
    ## no statekey, so an always-empty answer cannot pass this row by doing
    ## nothing.
    set st2 [dict create sweep [dict create axes {{kind other}} point {77}]]
    ase::register_backend dual2 [dict create \
      render_deck x run_cmd x log_file x result_probe x raw_file x \
      campaign_axis_kinds kn_other_kinds campaign_control_lines kn_dual_lines]
    set st3 [dict create sweep [dict create axes {{kind other}} point {77}]]
    return [list [c_ans ase::campaign_point_lines dualcamp $st] \
                 [c_ans ase::campaign_point_lines dual2 $st3]]
  }}] {{} {{SHOULD-NOT-BE-EMITTED 77}}}

## ⚠ D34/D36: A BACKEND WITH NO HOOK GETS NO FALLBACK CONTENT. Not an empty
## string, not a guess, and above all not ngspice's answer.
check {KN3 a backend that declares no campaign hooks gets NOTHING, not ngspice's} \
  [apply {{} {
    ase::register_backend nocamp [dict create \
      render_deck x run_cmd x log_file x result_probe x raw_file x]
    set r [list [c_ans ase::campaign_axis_kinds nocamp] \
                [c_ans ase::campaign_seed_option nocamp] \
                [c_ans ase::campaign_seed_notes nocamp] \
                [c_ans ase::campaign_point_lines nocamp \
                   [dict create sweep [dict create point {1} \
                      axes {{kind inst target r1 param resistance}}]]]]
    return $r
  }}] {{} {} {} {}}

check {KN4 and such a backend refuses a campaign in plain words rather than running one} \
  [c_ids [c_ans ase::campaign_refusals nocamp \
    [c_state simulator nocamp sweep [c_sweep enabled 1 axes {{kind temp values {27}}}]]]] \
  {nokinds}

check {KN5 registering a backend drops the axis-kind memo} \
  [apply {{} {
    set before [llength [dict keys [c_ans ase::campaign_axis_kinds nocamp]]]
    ase::register_backend nocamp [dict create \
      render_deck x run_cmd x log_file x result_probe x raw_file x \
      campaign_axis_kinds ::ase::backend::ngspice::campaign_axis_kinds]
    set after [llength [dict keys [c_ans ase::campaign_axis_kinds nocamp]]]
    return [list $before $after]
  }}] {0 5}

check {KN6 the adapter's declaration survives its own load-time validator} \
  [c_ans ase::campaign_schema_errors ngspice] {}

check {KN7 the seed rides an option this simulator really declares} \
  [list [c_ans ase::campaign_seed_option ngspice] \
        [expr {[ase::sim_option_entry ngspice [c_ans ase::campaign_seed_option ngspice]] ne {}}]] \
  {seed 1}

check {KN8 the seed's caveats are the adapter's, and there are two of them} \
  [llength [c_ans ase::campaign_seed_notes ngspice]] 2

# ============================================================================
# SECTION SR -- ISSUE 1469: A SEED THE SIMULATOR DOES NOT HONOUR IS NEVER
# WRITTEN, AND NEVER REPORTED AS A SEED
# ============================================================================
# MEASURED on both binaries (the driver's table in the issue file; its two
# boundary rows re-measured by the crew, fork first): `.options seed=2147483647`
# repeats with `$rndseed` 2147483647, and `.options seed=2147483648` prints
# `Warning: Cannot convert 'option seed=2147483648' to seed value, skipped!`,
# answers `$rndseed` 1 and draws differently on every run, rc 0. ngspice's
# `eval_opt()` does `int sr = atoi(token); if (sr <= 0) <warn>`, so only
# 1 ... 2147483647 is honoured as typed. ASE-L took 0 ... 4294967295 and wrote
# seed+N per shard -- MEASURED THROUGH THIS RUNNER before the fix, both binaries:
# a campaign seeded 2147483647 wrote `seed=2147483648` into its second shard,
# that shard's log carried the warning, and its measurement differed between two
# runs of the same campaign.
#
# ⚠ THE RANGE IS THE ADAPTER'S (`campaign_seed_range`), and a backend with no
# hook gets NO range: no refusal, no fold, its typed whole number as before.
#
# ⚠ AND A SHARD PAST THE TOP IS FOLDED, NOT REFUSED. seed+N past the top counts
# on from the bottom: deterministic, so Re-run Point reproduces it; collision
# free while the campaign has no more points than the range has seeds, and
# refused (`seedspan`) when it has. Refusing instead would turn a seed that was
# valid into a refused one because an axis was ADDED.

## Fixture backends. `norange` has ngspice's axes and seed option and NO range
## hook. `tinyrange` declares 10..12 -- ngspice's range is two billion seeds and
## a campaign is at most 2000 points, so without a tiny range neither the fold's
## arithmetic nor `seedspan` could be made to disagree. The two `badrange`s
## declare what no range may be.
proc ::sr_tiny_range {} { return {10 12} }
proc ::sr_bad_range_order {} { return {5 1} }
proc ::sr_bad_range_word {} { return {one 9} }
proc sr_backend {name args} {
  set hooks [dict create render_deck x run_cmd x log_file x result_probe x raw_file x \
    campaign_axis_kinds    ::ase::backend::ngspice::campaign_axis_kinds \
    campaign_control_lines ::ase::backend::ngspice::campaign_control_lines \
    campaign_seed_option   ::ase::backend::ngspice::campaign_seed_option]
  foreach {k v} $args { dict set hooks $k $v }
  ase::register_backend $name $hooks
}
sr_backend norange
sr_backend tinyrange campaign_seed_range ::sr_tiny_range
sr_backend badrange1 campaign_seed_range ::sr_bad_range_order
sr_backend badrange2 campaign_seed_range ::sr_bad_range_word
## A one-axis temperature campaign under `sim`; `-` means "no seed key at all".
proc sr_st {seed {sim ngspice} {vals {27}}} {
  set sw [c_sweep enabled 1 axes [list [list kind temp values $vals]]]
  if {$seed ne {-}} { dict set sw seed $seed }
  return [c_state simulator $sim sweep $sw]
}

check {SR1 the range a seed is honoured in is the adapter's declaration, and a\
 backend with no hook gets none} \
  [list [c_ans ase::campaign_seed_range ngspice] [c_ans ase::campaign_seed_range norange] \
        [c_ans ase::campaign_seed_range tinyrange]] \
  {{1 2147483647} {} {10 12}}

check {SR2 under ngspice the campaign's seed is a seed only where ngspice honours\
 it -- both ends in; zero, a negative, every refused and every wrapped value out} \
  [apply {{} {
    set o {}
    foreach s {1 2147483647 0 -5 2147483648 3000000000 4294967295 4294967296 5000000000 abc 1.5} {
      lappend o [c_ans ase::campaign_seed [sr_st $s]]
    }
    return $o
  }}] {1 2147483647 {} {} {} {} {} {} {} {} {}}

## ⚠ THE `entier` LESSON (issue 1468) IS THE SECOND ELEMENT'S NEIGHBOUR: under the
## old `integer` test 5000000000 read as NO seed while 4294967295 read as one.
check {SR2b a backend with no range hook gets NO range, not ngspice's: its seed is\
 the typed whole number, of any size and any sign} \
  [list [c_ans ase::campaign_seed [sr_st 0 norange]] \
        [c_ans ase::campaign_seed [sr_st -5 norange]] \
        [c_ans ase::campaign_seed [sr_st 5000000000 norange]] \
        [c_ans ase::campaign_seed [sr_st abc norange]]] \
  {0 -5 5000000000 {}}

check {SR2c the simulator argument decides the range when it is given, the state's\
 own simulator when it is not, and the default simulator when the state names none} \
  [list [c_ans ase::campaign_seed [sr_st 0 norange] ngspice] \
        [c_ans ase::campaign_seed [sr_st 0 ngspice] norange] \
        [c_ans ase::campaign_seed [dict remove [sr_st 0] simulator]]] \
  {{} 0 {}}

check {SR3 a campaign seed outside the range is refused -- zero, a negative, one\
 past the top, a wrapped value, a word and a fraction alike} \
  [apply {{} {
    set o {}
    foreach s {0 -5 2147483648 5000000000 abc 1.5} {
      lappend o [c_ids [c_ans ase::campaign_refusals ngspice [sr_st $s]]]
    }
    return $o
  }}] {badseed badseed badseed badseed badseed badseed}

check {SR3b in one sentence that names the range, with its fix} \
  [lrange [lindex [c_ans ase::campaign_seed_refusals ngspice [sr_st 2147483648]] 0] 0 3] \
  {badseed refuse {the seed must be a whole number from 1 to 2147483647, the only seeds this simulator honours} {type a seed in that range, or leave it empty}}

## THE CONTROL FOR SR3: a refusal that always fired would pass SR3 by itself.
check {SR3c and the control: both ends of the range and no seed at all are\
 refused nothing} \
  [list [c_ids [c_ans ase::campaign_refusals ngspice [sr_st 1]]] \
        [c_ids [c_ans ase::campaign_refusals ngspice [sr_st 2147483647]]] \
        [c_ids [c_ans ase::campaign_refusals ngspice [sr_st -]]] \
        [c_ans ase::campaign_seed_refusals ngspice [sr_st 2147483647]]] \
  {{} {} {} {}}

## ⚠ THE FORM ASKS BEFORE THERE IS A CAMPAIGN. `campaign_refusals` is silent for a
## bench with no axes -- there is nothing to run -- but a seed typed into the
## dialog before its first axis is still a seed, so the seed refusal is its own
## reader and does not wait for one.
check {SR3d a backend with no range refuses no seed; and a seed with no campaign\
 around it is still judged by its own reader while the campaign refuser stays\
 silent} \
  [list [c_ids [c_ans ase::campaign_refusals norange [sr_st 0 norange]]] \
        [c_ids [c_ans ase::campaign_seed_refusals ngspice [c_state sweep [c_sweep seed 0]]]] \
        [c_ids [c_ans ase::campaign_refusals ngspice [c_state sweep [c_sweep seed 0]]]]] \
  {{} badseed {}}

check {SR4 every shard's seed stays inside the range: base+N up to the top, then on\
 from the bottom} \
  [apply {{} {
    set st [sr_st 2147483645 ngspice {1 2 3 4 5}]
    set o {}
    for {set i 0} {$i < 5} {incr i} {
      set s [c_ans ase::campaign_shard_state ngspice $st $i]
      if {[catch {ase::state_get [lindex [dict get $s options] 0] value} v]} { set v RAISED }
      lappend o $v
    }
    return $o
  }}] {2147483645 2147483646 2147483647 1 2}

## ⚠ THE COLLISION ROW, AT THE CEILING. A fold that collided would give two
## shards one stream and a campaign two identical points it believed different.
check {SR4b a folded seed never collides with another shard's: the ceiling's 2000\
 shards, crossing the top at shard 1000, get 2000 different seeds, every one in\
 the range} \
  [apply {{} {
    set st [sr_st 2147482648]
    set seen {}
    set out 0
    for {set i 0} {$i < [c_ans ase::campaign_max_points]} {incr i} {
      set s [c_ans ase::campaign_shard_seed ngspice $st $i]
      if {![string is entier -strict $s] || $s < 1 || $s > 2147483647} { incr out }
      lappend seen $s
    }
    return [list [llength $seen] [llength [lsort -unique $seen]] $out \
                 [lindex $seen 999] [lindex $seen 1000]]
  }}] {2000 2000 0 2147483647 1}

check {SR4c the same shard asked twice gets the same seed -- which is what lets\
 Re-run Point reproduce it -- a backend with no range is not folded, and an\
 unseeded campaign has no shard seed} \
  [list [expr {[c_ans ase::campaign_shard_seed ngspice [sr_st 2147483647] 1] eq \
               [c_ans ase::campaign_shard_seed ngspice [sr_st 2147483647] 1]}] \
        [c_ans ase::campaign_shard_seed ngspice [sr_st 2147483647] 1] \
        [c_ans ase::campaign_shard_seed norange [sr_st 2147483647 norange] 1] \
        [c_ans ase::campaign_shard_seed ngspice [sr_st -] 1]] \
  {1 1 2147483648 {}}

check {SR5 the fold and the refusal read the RANGE, not ngspice: a range of 10..12\
 seeded 11 gives 11 12 10, and 9 and 13 are refused while 10 is not} \
  [list [apply {{} {
          set st [sr_st 11 tinyrange {1 2 3}]
          set o {}
          foreach i {0 1 2} { lappend o [c_ans ase::campaign_shard_seed tinyrange $st $i] }
          return $o
        }}] \
        [c_ids [c_ans ase::campaign_refusals tinyrange [sr_st 9 tinyrange]]] \
        [c_ids [c_ans ase::campaign_refusals tinyrange [sr_st 13 tinyrange]]] \
        [c_ids [c_ans ase::campaign_refusals tinyrange [sr_st 10 tinyrange {1 2 3}]]]] \
  {{11 12 10} badseed badseed {}}

check {SR5b a seeded campaign with more points than the range has seeds is\
 refused, because two of its points would have to share one -- and an unseeded\
 one is not} \
  [list [c_ids [c_ans ase::campaign_refusals tinyrange [sr_st 10 tinyrange {1 2 3 4}]]] \
        [lindex [lindex [c_ans ase::campaign_refusals tinyrange [sr_st 10 tinyrange {1 2 3 4}]] 0] 2] \
        [c_ids [c_ans ase::campaign_refusals tinyrange [sr_st - tinyrange {1 2 3 4}]]]] \
  {seedspan {this campaign has 4 points and the simulator honours only 3 seeds, so two points would share one} {}}

## ⚠ THE PER-SHARD RULE IS A PROMISE ("shard N is seeded S+N"), SO A CAMPAIGN THAT
## WRAPS IS TOLD SO IN THAT SENTENCE -- and one that ends exactly at the top gets
## the sentence it always had, byte for byte.
check {SR6 a campaign that crosses the top is told it wraps, in the per-shard\
 rule's own sentence; one that ends exactly at the top is told nothing new} \
  [list [lindex [c_ans ase::campaign_notes ngspice [sr_st 2147483647 ngspice {27 85}]] 1] \
        [lindex [c_ans ase::campaign_notes ngspice [sr_st 2147483646 ngspice {27 85}]] 1]] \
  [list {campaign: seeded from 2147483647; shard N is seeded 2147483647+N, wrapping to 1 after 2147483647, so a single point can be re-run on its own and give the same answer} \
        {campaign: seeded from 2147483646; shard N is seeded 2147483646+N, so a single point can be re-run on its own and give the same answer}]

check {SR6b and a seed the simulator would throw away is not reported as a seed:\
 the campaign is told it has none} \
  [lindex [c_ans ase::campaign_notes ngspice [sr_st 0]] 1] \
  {campaign: this campaign has no seed, so anything the simulator draws for itself will differ the next time it is run}

## ⚠ THE NOISE SEED SENTENCE READS THE SAME ANSWER. `ase::stimuli_seed_report` is
## what the Tran form's noise section prints under its table; before the fix a
## campaign seeded 0 and an options row `seed 0` both made it say RTS noise
## "repeats exactly under the seed", on a run ngspice would leave unseeded.
set SR7ROW {type tran enabled 1 step 1u stop 2m noise {{src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u}}}
proc sr_report {args} {
  global SR7ROW
  return [c_ans ase::stimuli_seed_report ngspice [c_state {*}$args] $SR7ROW]
}
proc sr_seeded {args} {
  set r [sr_report {*}$args]
  if {[catch {dict get $r seeded} v]} { return "NOREPORT:$r" }
  return $v
}
check {SR7 the noise seed report says seeded only where the simulator will be: a\
 campaign seed or an options seed row outside the range is no seed, and one\
 inside it still is} \
  [list [sr_seeded sweep [c_sweep enabled 1 seed 7 axes {{kind temp values {27}}}]] \
        [sr_seeded sweep [c_sweep enabled 1 seed 0 axes {{kind temp values {27}}}]] \
        [sr_seeded sweep [c_sweep enabled 1 seed 2147483648 axes {{kind temp values {27}}}]] \
        [sr_seeded options {{name seed value 5}}] \
        [sr_seeded options {{name seed value 0}}] \
        [sr_seeded options {{name seed value 2147483648}}] \
        [sr_seeded options {{name seed value random}}]] \
  {1 0 0 1 0 0 0}

check {SR7b and the sentence the Tran form shows follows it} \
  [apply {{r} {
    if {[catch {dict get $r sentences} v]} { return "NOREPORT:$r" }
    return $v
  }} [sr_report sweep [c_sweep enabled 1 seed 2147483648 axes {{kind temp values {27}}}]]] \
  {{RTS noise repeats only when a seed is set.}}

check {SR7c a backend with no range keeps the answer it had: an options row of its\
 seed option's name counts, whatever it holds} \
  [c_ans ase::stimuli_seeded norange [c_state simulator norange options {{name seed value 0}}]] 1

check {SR8 a malformed range is no range, and the load-time validator names it\
 rather than letting the declaration go silent} \
  [list [c_ans ase::campaign_seed_range badrange1] [c_ans ase::campaign_seed_range badrange2] \
        [llength [c_ans ase::campaign_schema_errors badrange1]] \
        [llength [c_ans ase::campaign_schema_errors badrange2]] \
        [llength [c_ans ase::campaign_schema_errors tinyrange]] \
        [llength [c_ans ase::campaign_schema_errors norange]]] \
  {{} {} 1 1 0 0}

## ⚠ REFUSED AT THE FORM AND AT RUN -- NEVER REPAIRED IN THE FILE. A `.state`
## written before this fix can carry a seed ngspice does not honour. It must still
## load, and save byte for byte with the seed it was written with, so the user
## meets the refusal and repairs it themselves; a loader that "fixed" the number
## would change their file behind their back. Written and re-written through
## `ase::state_save` and read through `ase::state_load`, the pair
## `state_roundtrip.tcl` measures the 104 committed files with -- and a mutated
## save must DISAGREE, or "identical" measured nothing.
check {SR11 a .state carrying a seed outside the range loads and saves byte for\
 byte, keeps the seed it was written with, and is refused rather than repaired} \
  [apply {{} {
    global scratch
    if {[catch {
      set o {}
      foreach s {0 2147483648 5000000000 abc} {
        set p [file join $scratch sr11_$s.state]
        ase::state_save $p [c_state sweep [c_sweep enabled 1 seed $s axes {{kind temp values {27 85}}}]]
        set fh [::open $p rb] ; set orig [read $fh] ; ::close $fh
        set ld [ase::state_load $p]
        set p2 [file join $scratch sr11_${s}_again.state]
        ase::state_save $p2 $ld
        set fh [::open $p2 rb] ; set again [read $fh] ; ::close $fh
        lappend o [list [expr {$orig eq $again}] [ase::campaign_get $ld seed] \
                        [c_ans ase::campaign_seed $ld] \
                        [c_ids [c_ans ase::campaign_refusals ngspice $ld]]]
      }
      ## THE CONTROL: the same load with its seed repaired saves DIFFERENTLY.
      set sw [ase::state_get $ld sweep]
      dict set sw seed 7
      dict set ld sweep $sw
      ase::state_save $p2 $ld
      set fh [::open $p2 rb] ; set fixed [read $fh] ; ::close $fh
      lappend o [expr {$fixed ne $orig ? {differs} : {SAME}}]
    } err]} { return "RAISED:$err" }
    return $o
  }}] {{1 0 {} badseed} {1 2147483648 {} badseed} {1 5000000000 {} badseed} {1 abc {} badseed} differs}

# ============================================================================
# SECTION MD -- THE MODE, AND SAYING WHICH ONE WAS CHOSEN
# ============================================================================
# §11a: "the runner SAYS which mode it chose". `collapsible` is computed from the
# adapter's measured re-parse classes and REPORTED; taking it would mean a second
# emitter for `render_deck`'s .control body, which is the ninth copy of "what a
# dc analysis is" this batch exists to remove.

check {MD1 an alter-only campaign is collapsible} \
  [c_ans ase::campaign_mode ngspice \
     [c_state sweep [c_sweep enabled 1 axes {
        {kind inst target r1 param resistance values {1k 2k}}
        {kind model model nch param vth0 values {0.4 0.5}}}]]] \
  {mode shard collapsible 1 why {}}

check {MD2 one re-parsing axis makes the whole campaign un-collapsible, and names it} \
  [list [c_ans ase::campaign_mode ngspice \
          [c_state sweep [c_sweep enabled 1 axes {
             {kind inst target r1 param resistance values {1k}}
             {kind corner index 0 values {tt ff}}}]]] \
        [c_ans ase::campaign_mode ngspice \
          [c_state sweep [c_sweep enabled 1 axes {{kind temp values {27 85}}}]]]] \
  {{mode shard collapsible 0 why corner} {mode shard collapsible 0 why temp}}

check {MD3 the chosen mode is one process per point, whatever the verdict} \
  [apply {{} {
    set o {}
    foreach ax {{{kind inst target r1 param resistance values {1k 2k}}} \
                {{kind temp values {27 85}}}} {
      lappend o [dict get [c_ans ase::campaign_mode ngspice \
        [c_state sweep [c_sweep enabled 1 axes $ax]]] mode]
    }
    return $o
  }}] {shard shard}

check {MD4 a campaign with no axes is not collapsible either} \
  [c_ans ase::campaign_mode ngspice [c_state]] {mode shard collapsible 0 why {}}

# ============================================================================
# SECTION SH -- A SHARD IS A STATE
# ============================================================================

set SHST [c_state \
  variables {{name myres value 9k} {name other value 5}} \
  models {{file /m/lib.spice section tt}} \
  temperature 27 \
  sweep [c_sweep enabled 1 seed 100 axes {
    {kind var name myres values {1k 2k}}
    {kind temp values {40 85}}
    {kind corner index 0 values {ff ss}}}]]

check {SH1 the shard's rundir is the shard directory, so every sidecar follows} \
  [apply {{st} {
    set s [c_ans ase::campaign_shard_state ngspice $st 5]
    return [list [file tail [dict get $s rundir]] \
                 [file tail [file dirname [dict get $s rundir]]]]
  }} $SHST] {shard-0006 campaign}

check {SH2 a design variable OVERWRITES its row and leaves the others alone} \
  [dict get [c_ans ase::campaign_shard_state ngspice $SHST 4] variables] \
  {{name myres value 2k} {name other value 5}}

check {SH2b a variable the bench never declared is ADDED, because that is the commonest first campaign} \
  [dict get [c_ans ase::campaign_shard_state ngspice \
     [c_state sweep [c_sweep enabled 1 axes {{kind var name brandnew values {3}}}]] 0] variables] \
  {{name brandnew value 3}}

## ⚠ AND ADDING ONE KEEPS THE OTHERS. Sabotage m16 replaced the whole list with
## the new row and SH2b passed, because SH2b's bench declares no other variable.
## A bench that declares two and sweeps a third is the ordinary case, and losing
## the other two is a silently different circuit.
check {SH2c adding a new variable keeps every variable the bench already had} \
  [dict get [c_ans ase::campaign_shard_state ngspice \
     [c_state variables {{name vsup value 1.8} {name rload value 10k}} \
       sweep [c_sweep enabled 1 axes {{kind var name brandnew values {3}}}]] 0] variables] \
  {{name vsup value 1.8} {name rload value 10k} {name brandnew value 3}}

check {SH3 a temperature axis writes the temperature key} \
  [list [dict get [c_ans ase::campaign_shard_state ngspice $SHST 0] temperature] \
        [dict get [c_ans ase::campaign_shard_state ngspice $SHST 2] temperature]] {40 85}

check {SH4 a corner axis re-sections the models row it names, keeping the file} \
  [list [dict get [c_ans ase::campaign_shard_state ngspice $SHST 0] models] \
        [dict get [c_ans ase::campaign_shard_state ngspice $SHST 1] models]] \
  {{{file /m/lib.spice section ff}} {{file /m/lib.spice section ss}}}

check {SH4b a corner axis naming a models row that is not there changes nothing} \
  [dict get [c_ans ase::campaign_shard_state ngspice \
     [c_state models {{file /m/lib.spice section tt}} \
       sweep [c_sweep enabled 1 axes {{kind corner index 7 values {ff}}}]] 0] models] \
  {{file /m/lib.spice section tt}}

## ⚠ THE PER-SHARD SEED IS base+N AND IT RIDES THE OPTIONS SHEET. That is what
## makes "re-run just point 17" give the same answer as point 17 did.
check {SH5 each shard gets its own seed, base plus its index} \
  [apply {{st} {
    set o {}
    foreach i {0 1 7} {
      lappend o [dict get [c_ans ase::campaign_shard_state ngspice $st $i] options]
    }
    return $o
  }} $SHST] {{{name seed value 100}} {{name seed value 101}} {{name seed value 107}}}

check {SH5b a campaign with no seed sets no seed option at all} \
  [dict get [c_ans ase::campaign_shard_state ngspice \
     [c_state sweep [c_sweep enabled 1 axes {{kind temp values {27}}}]] 0] options] {}

check {SH5c an existing seed row is REPLACED, not duplicated} \
  [dict get [c_ans ase::campaign_shard_state ngspice \
     [c_state options {{name seed value 5} {name reltol value 1e-4}} \
       sweep [c_sweep enabled 1 seed 900 axes {{kind temp values {27}}}]] 0] options] \
  {{name seed value 900} {name reltol value 1e-4}}

check {SH6 the shard carries its own coordinates and index} \
  [apply {{st} {
    set s [c_ans ase::campaign_shard_state ngspice $st 3]
    return [list [dict get $s sweep point] [dict get $s sweep index]]
  }} $SHST] {{1k 85 ss} 3}

check {SH7 asking for a point that does not exist raises rather than inventing one} \
  [list [c_ans ase::campaign_shard_state ngspice $SHST 8] \
        [c_ans ase::campaign_shard_state ngspice $SHST -1]] \
  {{RAISED:ase: campaign has no point 8} {RAISED:ase: campaign has no point -1}}

check {SH8 shard ids are zero-padded so `ls` sorts the way the odometer counts} \
  [list [c_ans ase::campaign_shard_id 0] [c_ans ase::campaign_shard_id 9] \
        [c_ans ase::campaign_shard_id 99]] {shard-0001 shard-0010 shard-0100}

# ============================================================================
# SECTION DK -- THE DECK
# ============================================================================

## ⚠ THE NULL RESULT FIRST. Every state in this tree and all 104 committed
## `.state` files carry no `sweep`, so not one byte of any deck may move.
check {DK1 a bench with no campaign renders byte-identically to one whose sweep key is absent} \
  [apply {{} {
    set a [c_deck [c_state]]
    set b [c_deck [dict remove [c_state] sweep]]
    return [string equal $a $b]
  }}] 1

check {DK1b and a CONFIGURED campaign changes nothing in the bench's own deck either} \
  [apply {{} {
    set a [c_deck [c_state]]
    set b [c_deck [c_state sweep [c_sweep enabled 1 axes {
             {kind inst target r1 param resistance values {1k 2k}}}]]]
    return [string equal $a $b]
  }}] 1

## ...because the `alter` lines come from the POINT, not from the campaign, and
## only a SHARD state names a point.
set DKSH [c_ans ase::campaign_shard_state ngspice \
  [c_state sweep [c_sweep enabled 1 axes {
     {kind inst target r1 param resistance values {1k 2k}}
     {kind model model nch param vth0 values {0.4}}}]] 1]

check {DK2 a shard's deck carries the alter lines its point names} \
  [apply {{st} {
    set o {}
    foreach l [split [c_deck $st] "\n"] {
      if {[regexp {^(alter|altermod)} $l]} { lappend o $l }
    }
    return $o
  }} $DKSH] {{alter r1 resistance=2k} {altermod @nch[vth0]=0.4}}

## ⚠ POSITION, INVERTED DELIBERATELY, because `alter` is last-writer-wins and a
## command in a `.control` block governs what FOLLOWS it and nothing before.
check {DK3 the alter lines sit INSIDE .control, ABOVE every analysis} \
  [apply {{st} {
    set d [c_deck $st]
    set c  [c_at $d {^\.control$}]
    set al [c_at $d {^alter r1}]
    set an [c_at $d {^op$}]
    set e  [c_at $d {^\.endc$}]
    return [list [expr {$c >= 0 && $al > $c}] [expr {$al < $an}] [expr {$al < $e}]]
  }} $DKSH] {1 1 1}

check {DK3b and ABOVE the operating-point strategy, which is about the circuit they just changed} \
  [apply {{} {
    set st [c_ans ase::campaign_shard_state ngspice \
      [c_state opstrategy {gmin 1 source 1 transient 0 newton 1} \
        sweep [c_sweep enabled 1 axes {{kind inst target r1 param resistance values {2k}}}]] 0]
    set d [c_deck $st]
    set al [c_at $d {^alter r1}]
    set ot [c_at $d {^optran }]
    return [list [expr {$al >= 0}] [expr {$ot >= 0}] [expr {$al < $ot}]]
  }}] {1 1 1}

check {DK4 a design variable reaches the deck as a .param, not as an alter} \
  [apply {{} {
    set st [c_ans ase::campaign_shard_state ngspice \
      [c_state sweep [c_sweep enabled 1 axes {{kind var name myres values {7k}}}]] 0]
    set d [c_deck $st]
    return [list [c_at $d {^\.param myres=7k$}] \
                 [expr {[c_at $d {^alter}] < 0}]]
  }}] {3 1}

check {DK5 a temperature axis reaches the deck as .temp, and NEVER as `set temp`} \
  [apply {{} {
    set st [c_ans ase::campaign_shard_state ngspice \
      [c_state sweep [c_sweep enabled 1 axes {{kind temp values {125}}}]] 0]
    set d [c_deck $st]
    return [list [expr {[c_at $d {^\.temp 125$}] >= 0}] \
                 [expr {[c_at $d {^set temp}] < 0}]]
  }}] {1 1}

check {DK6 a corner axis reaches the deck as a .lib row with the new section} \
  [apply {{} {
    set st [c_ans ase::campaign_shard_state ngspice \
      [c_state models {{file /m/lib.spice section tt}} \
        sweep [c_sweep enabled 1 axes {{kind corner index 0 values {ff}}}]] 0]
    return [expr {[c_at [c_deck $st] {^\.lib /m/lib\.spice ff$}] >= 0}]
  }}] 1

check {DK7 the per-shard seed reaches the deck as a .options card} \
  [apply {{} {
    set st [c_ans ase::campaign_shard_state ngspice \
      [c_state sweep [c_sweep enabled 1 seed 500 axes {{kind temp values {27}}}]] 0]
    return [expr {[c_at [c_deck $st] {^\.options .*seed=500} ] >= 0}]
  }}] 1

## ⚠ AND NOTHING THE RUNNER EMITS CAN EVER PRODUCE A THIRD `.dc` SWEEP LEVEL.
## MEASURED on both binaries: three nested sweeps give the same NINE rows as
## two, values byte-identical, rc 0, empty stderr -- a user who asks for 27
## operating points gets 9 and is told nothing. A campaign shards its
## temperatures instead of collapsing them onto the `dc` card, so the card it
## renders is the one the analysis row already describes.
check {DK8 a temperature campaign over a two-level dc sweep still emits a TWO-level dc card} \
  [apply {{} {
    set st [c_state analyses {{type dc enabled 1 source v1 start 0 stop 1 step 0.5 \
                               source2 v2 start2 0 stop2 1 step2 0.5}} \
                   sweep [c_sweep enabled 1 axes {{kind temp values {27 125}}}]]
    set sh [c_ans ase::campaign_shard_state ngspice $st 1]
    set o {}
    foreach l [split [c_deck $sh] "\n"] { if {[regexp {^dc } $l]} { lappend o $l } }
    return $o
  }}] {{dc v1 0 1 0.5 v2 0 1 0.5}}

check {DK9 no campaign line ever escapes the .control block} \
  [apply {{st} {
    set d [c_deck $st]
    set e [c_at $d {^\.endc$}]
    set bad 0 ; set i 0
    foreach l [split $d "\n"] {
      if {$i > $e && [regexp {^(alter|altermod)} $l]} { incr bad }
      incr i
    }
    return $bad
  }} $DKSH] 0

# ============================================================================
# SECTION RF -- THE REFUSALS
# ============================================================================
# A campaign that cannot run must say so BEFORE it makes a directory: the whole
# cost of getting this wrong is a tree of half-written shards.

check {RF1 a bench with no campaign is refused nothing at all} \
  [c_ans ase::campaign_refusals ngspice [c_state]] {}

## ⚠ ⚖ R2 CONDITION 4, AND THE STANDING RULE BEHIND IT. With no run directory
## `ase::rundir` answers the ONE directory every cell of every library shares,
## and a campaign would build a tree in it and write a `.spiceinit` there.
check {RF2 a bench with no run directory is refused, and told what to do} \
  [apply {{} {
    set st [c_state rundir {} sweep [c_sweep enabled 1 axes {{kind temp values {27}}}]]
    set r [c_ans ase::campaign_refusals ngspice $st]
    set hit {}
    foreach e $r { if {[lindex $e 0] eq {sharedrundir}} { set hit $e } }
    return $hit
  }}] {sharedrundir refuse {this bench names no run directory, so a campaign would build its shards in the directory every other cell shares} {set a run directory for this bench first}}

check {RF3 a campaign with no enabled analysis is refused} \
  [c_ids [c_ans ase::campaign_refusals ngspice \
     [c_state analyses {{type op enabled 0}} \
       sweep [c_sweep enabled 1 axes {{kind temp values {27}}}]]]] {noanalysis}

check {RF4 an axis kind this simulator cannot deliver is refused by name} \
  [apply {{} {
    set r [c_ans ase::campaign_refusals ngspice \
      [c_state sweep [c_sweep enabled 1 axes {{kind supply values {1.8}}}]]]
    foreach e $r { if {[lindex $e 0] eq {badkind}} { return [lrange $e 2 3] } }
    return NONE
  }}] {{'supply' is not a campaign axis this simulator can deliver} {choose one of: corner, inst, model, temp, var}}

check {RF5 two axes with one name are refused, because one column would hide the other} \
  [c_ids [c_ans ase::campaign_refusals ngspice \
     [c_state sweep [c_sweep enabled 1 axes {
        {kind var name x values {1}} {kind var name x values {2}}}]]]] {dupname}

check {RF6 an axis with no values is refused} \
  [c_ids [c_ans ase::campaign_refusals ngspice \
     [c_state sweep [c_sweep enabled 1 axes {{kind temp values {}}}]]]] {novalues}

check {RF7 a distribution that cannot be sampled is refused with the sampler's own reason} \
  [apply {{} {
    set r [c_ans ase::campaign_refusals ngspice \
      [c_state sweep [c_sweep enabled 1 axes {
         {kind var name x draw {dist normal mean 1 n 3}}}]]]
    foreach e $r { if {[lindex $e 0] eq {baddraw}} { return [lindex $e 2] } }
    return NONE
  }}] {axis 'x' cannot be sampled: distribution 'normal' needs 'sigma'}

## ⚠ A CEILING, NOT A CLAMP. Silently running the first 2000 of 50000 points
## would be this batch's own accepted-and-inert defect wearing a progress bar.
check {RF8 a campaign over the ceiling is refused with both numbers} \
  [apply {{} {
    set v {}
    for {set i 0} {$i < 2001} {incr i} { lappend v $i }
    set r [c_ans ase::campaign_refusals ngspice \
      [c_state sweep [c_sweep enabled 1 axes [list [list kind temp values $v]]]]]
    foreach e $r { if {[lindex $e 0] eq {toomany}} { return [lindex $e 2] } }
    return NONE
  }}] {this campaign has 2001 points, and ASE-L runs at most 2000}
check {RF8b and one point under the ceiling is not refused} \
  [apply {{} {
    set v {}
    for {set i 0} {$i < 2000} {incr i} { lappend v $i }
    return [c_ids [c_ans ase::campaign_refusals ngspice \
      [c_state sweep [c_sweep enabled 1 axes [list [list kind temp values $v]]]]]]
  }}] {}

## ⚠ THE `temp` TRAP, AND IT IS THE ADAPTER'S REFUSAL BECAUSE IT IS AN NGSPICE
## FACT. `temp` is a `US_SIMVAR`, not a `.param`, so a design variable called
## `temp` renders as `.param temp=125` -- a parameter the temperature machinery
## never reads. The deck runs, every number is a 27 degC number, and nothing
## says so.
check {RF9 a design variable called `temp` is refused, with the temperature axis offered instead} \
  [apply {{} {
    set r [c_ans ase::campaign_refusals ngspice \
      [c_state sweep [c_sweep enabled 1 axes {{kind var name temp values {27 125}}}]]]
    foreach e $r { if {[lindex $e 0] eq {temp_not_param}} { return [lrange $e 2 3] } }
    return NONE
  }}] {{'temp' is not a parameter in this simulator, so sweeping it as a design variable would run every point at the same temperature and say nothing} {use a Temperature axis instead}}

check {RF9b a design variable called anything else is not refused} \
  [c_ids [c_ans ase::campaign_refusals ngspice \
     [c_state sweep [c_sweep enabled 1 axes {{kind var name vsup values {1.8}}}]]]] {}

check {RF10 a name a generated command would split is refused} \
  [c_ids [c_ans ase::campaign_refusals ngspice \
     [c_state sweep [c_sweep enabled 1 axes {
        {kind inst target {r1 x} param resistance values {1k}}}]]]] {badname}

# ============================================================================
# SECTION IX -- index.tsv
# ============================================================================

set IXST [c_state \
  measurements {{name vmax analysis tran kind max target v(a)}} \
  analyses {{type tran enabled 1 step 1u stop 10u}} \
  sweep [c_sweep enabled 1 axes {
    {kind var name myres values {1k 2k}}
    {kind temp values {27 125}}}]]

check {IX1 the header is shard, one column per axis, exit, raw, one per measurement} \
  [c_ans ase::campaign_index_header ngspice $IXST] \
  {shard myres temp exit raw vmax}

check {IX1b a measurement that is switched OFF gets no column} \
  [c_ans ase::campaign_index_header ngspice \
     [dict replace $IXST measurements {{name vmax analysis tran kind max target v(a) enabled 0}}]] \
  {shard myres temp exit raw}

## ⚠ ONE ROW PER POINT, ALWAYS, RUN OR NOT. Issue 1457's lesson: a check that
## asks "is everything promised present?" passes with a MISSING promise in. The
## index is built from the ODOMETER, so a point that never ran is a VISIBLE `-`
## rather than an absent row nobody counts.
check {IX2 a point that has not run still gets a row, with `-` for exit and raw} \
  [c_ans ase::campaign_index_row ngspice $IXST 2 {}] \
  {shard-0003 2k 27 - - -}

check {IX2b and the index has exactly as many rows as the odometer has points} \
  [apply {{st} {
    set rows {}
    for {set i 0} {$i < [c_ans ase::campaign_count $st]} {incr i} {
      lappend rows [c_ans ase::campaign_index_row ngspice $st $i {}]
    }
    set txt [c_ans ase::campaign_index_text ngspice $st $rows]
    set data {}
    foreach l [split [string trimright $txt "\n"] "\n"] {
      if {[string index $l 0] ne {#}} { lappend data $l }
    }
    ## one header line plus one row per point
    return [list [llength $data] [c_ans ase::campaign_count $st]]
  }} $IXST] {5 4}

check {IX3 an exit code that is not zero lands in the row as itself} \
  [lindex [c_ans ase::campaign_index_row ngspice $IXST 0 124] 3] 124

## ⚠ ONE EMBEDDED TAB SHIFTS EVERY COLUMN TO ITS RIGHT AND NOTHING DOWNSTREAM
## CAN TELL. A value never carries one.
check {IX4 a tab or a newline in a value becomes a space} \
  [c_ans ase::campaign_index_cell "a\tb\nc\rd"] {a b c d}

check {IX5 the comment block is `#` and the header is the first line that is not} \
  [apply {{st} {
    set txt [c_ans ase::campaign_index_text ngspice $st {}]
    set lines [split [string trimright $txt "\n"] "\n"]
    set first {}
    foreach l $lines { if {[string index $l 0] ne {#}} { set first $l ; break } }
    return [list [string index [lindex $lines 0] 0] [split $first \t]]
  }} $IXST] [list "#" {shard myres temp exit raw vmax}]

check {IX6 what is written is what is read back, `#` lines dropped} \
  [apply {{st} {
    set rows {}
    for {set i 0} {$i < 4} {incr i} {
      lappend rows [c_ans ase::campaign_index_row ngspice $st $i $i]
    }
    c_ans ase::campaign_index_write ngspice $st $rows
    set back [c_ans ase::campaign_index_read $st]
    file delete -force [c_ans ase::campaign_dir $st]
    return [list [lindex $back 0] [lrange $back 1 end]]
  }} $IXST] \
  [list {shard myres temp exit raw vmax} \
        [list {shard-0001 1k 27 0 - -} {shard-0002 1k 125 1 - -} \
              {shard-0003 2k 27 2 - -} {shard-0004 2k 125 3 - -}]]

check {IX6b reading an index that was never written answers empty, not an error} \
  [c_ans ase::campaign_index_read [c_state rundir [file join $scratch nowhere]]] {}

# ============================================================================
# SECTION RN -- THE RUNNER, AGAINST A STAND-IN SIMULATOR
# ============================================================================
# A few-line /bin/sh script that reads the deck it was handed, takes the results
# path off the deck's own `write` line and writes a canned raw there. Nothing
# here needs a real ngspice, so every row is deterministic on both arms.

set RNBIN [file join $scratch bin]
file mkdir $RNBIN
set RNRAW "Title: campaign stand-in\nDate: Sat Sep 13 00:00:00  2026\nPlotname: Operating Point\nFlags: real\nNo. Variables: 1\nNo. Points: 1\nVariables:\n\t0\tv(a)\tvoltage\nValues:\n 0\t1.000000e+00\n"
proc rn_wr {path text {perm 0644}} {
  set f [open $path w] ; puts -nonewline $f $text ; close $f
  file attributes $path -permissions $perm
  return $path
}
## Arm 1: always succeeds. Arm 2: exits 3 for the point whose deck names a
## marker, so a FAILING shard is a real, reachable state and not a hypothesis.
set RNSTUB {#!/bin/sh
deck=
for a in "$@"; do
  if [ -f "$a" ]; then deck="$a"; fi
done
[ -z "$deck" ] && exit 0
if grep -q '@FAILMARK@' "$deck"; then echo CAMPAIGN-STUB-FAIL; exit 3; fi
out=`grep -E '^[ 	]*write[ 	]' "$deck" | head -1 | sed -e 's/^[ 	]*write[ 	][ 	]*//' -e 's/[ 	]*$//'`
if [ -n "$out" ]; then cat @RAW@ > "$out"; fi
echo CAMPAIGN-STUB-RAN
exit 0
}
## The HANGING stand-in, braced so the shell's `[ -f ... ]` is not read as Tcl
## command substitution. It answers anything that is not a campaign deck
## instantly -- which is what keeps the capability probe out of the clock -- and
## becomes a thirty-second sleeper for a shard.
set RNSLOWSTUB {#!/bin/sh
deck=
for a in "$@"; do
  if [ -f "$a" ]; then deck="$a"; fi
done
case "$deck" in
  */campaign/*) exec sleep @SECS@ ;;
esac
exit 0
}
## ⚠ THE SLEEP DURATION IS UNIQUE TO THIS PROCESS, AND THAT IS NOT FUSSINESS.
## RN11b scans the whole process table, so it needs an identifier that belongs to
## THIS run: a fixed `sleep 37` also matches a sleeper left by an earlier run of
## this same suite that the kernel has not reaped yet, and the row then reports a
## survivor the kill had already despatched. Measured -- it failed twice and
## passed once on identical code, which is a flake, and a flaky row is worse than
## no row. Derived from the pid, so two suites running at once cannot collide
## either.
## ⚠ AND IT IS SHORT, WHICH IS THE OTHER HALF. The first version slept for up to
## eighty minutes to buy uniqueness, and RN11c's stand-in is the GRANDCHILD shape
## whose sleeper is deliberately NOT killed -- so every run of this suite left two
## processes lying about for the rest of the hour, and a sabotage that removes the
## kill left four. Measured: ten of them were still running when this was found. A
## FRACTIONAL second buys the same uniqueness and is gone in under a minute.
set RNSLEEP  "47.[expr {[pid] % 1000}]"
set RNSLEEP2 "48.[expr {[pid] % 1000}]"
## ⚠ THE SAME STAND-IN WITHOUT THE `exec`, WHICH IS A DIFFERENT PROCESS TREE AND
## A DIFFERENT DEFECT. Here the SHELL is what `execute` knows about and the
## sleeper is its child, so `kill -9` on the id closes nothing: the grandchild
## holds the pipe, EOF never arrives, `ase::run_done` never fires and the
## in-flight LOCK is never cleared. That is the shape that cost two red rows
## before it was understood, and it is not hypothetical -- a simulator that
## spawns a helper (a co-simulation shim, a wrapper script) has exactly it.
set RNSLOWSTUB2 {#!/bin/sh
deck=
for a in "$@"; do
  if [ -f "$a" ]; then deck="$a"; fi
done
case "$deck" in
  */campaign/*) sleep @SECS2@ ;;
esac
exit 0
}
set RNRAWF [rn_wr [file join $scratch stub.raw] $RNRAW]
rn_wr [file join $RNBIN campsim] \
  [string map [list @RAW@ $RNRAWF @FAILMARK@ {seed=9911}] $RNSTUB] 0755
catch {ase::sim_register campstub [file join $RNBIN campsim]}
catch {ase::sim_select campstub}

proc rn_state {sweep {extra {}}} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create cell rc lib $scratch]
  dict set st rundir [file join $scratch rn]
  dict set st simulator ngspice
  dict set st sim_entry {name campstub}
  dict set st save_all_v 1
  dict set st analyses {{type op enabled 1}}
  dict set st sweep $sweep
  foreach {k v} $extra { dict set st $k $v }
  return $st
}
proc rn_fresh {} {
  global scratch
  file delete -force [file join $scratch rn]
  file mkdir [file join $scratch rn]
}

## ⚠ THE PRODUCTION BUDGET IS PINNED BEFORE THE SECTION SHORTENS IT. Every
## stand-in below finishes in milliseconds, so a ten-second budget is generous
## and makes a BROKEN WAKE-UP a fast, NAMED failure instead of a suite that sits
## at the real budget until an external `timeout` cuts it off -- which is a
## NORESULT, and a NORESULT is not a result. The line under test is the wait, not
## the number, and the number itself is asserted here.
check {RN0 the shipped per-shard budget is thirty minutes, and the section below shortens it deliberately} \
  [c_ans ase::campaign_shard_timeout] 1800
rename ::ase::campaign_shard_timeout ::rn_production_tmo
proc ::ase::campaign_shard_timeout {} { return 10 }

rn_fresh
set RNST [rn_state [c_sweep enabled 1 seed 10 axes {
  {kind var name myres values {1k 2k}}
  {kind inst target r1 param resistance values {3k 4k}}}]]
set RNRES [c_ans ase::campaign_run ngspice $RNST [c_netlist]]

check {RN1 the campaign ran every point and says so} \
  [list [dict get $RNRES status] [dict get $RNRES ran] [dict get $RNRES of]] \
  {done 4 4}

check {RN2 the tree is campaign/deck.spice, campaign/index.tsv and one directory per point} \
  [apply {{st} {
    set d [c_ans ase::campaign_dir $st]
    set o {}
    foreach p [lsort [glob -nocomplain -directory $d *]] { lappend o [file tail $p] }
    return $o
  }} $RNST] {deck.spice index.tsv shard-0001 shard-0002 shard-0003 shard-0004}

## ⚠ A SHARD DIRECTORY IS A RUN DIRECTORY, produced by the same code -- which is
## the visible consequence of routing every shard through `ase::run_deck` instead
## of composing the command here. The netlist, the deck, the log, the results
## file and the plot sidecar all carry the names a SINGLE run gives them.
check {RN3 a shard directory holds exactly what a single run's directory holds} \
  [apply {{st} {
    set o {}
    foreach f {rc.spice rc_ase.spice rc_ase.log rc_ase.raw} {
      lappend o [file exists [file join [c_ans ase::campaign_shard_dir $st 0] $f]]
    }
    return $o
  }} $RNST] {1 1 1 1}
## ⚠ THE PLOT SIDECAR IS NOT IN THAT LIST, AND ITS ABSENCE IS CORRECT HERE: it
## is written by the SIMULATOR executing the deck's own `echo ... >> <path>`
## line, not by ASE-L, so a stand-in that only copies a rawfile produces none.
## Row EE3b asserts it on the real binaries, where the deck really runs.

## ⚠ THE SURPLUS DIRECTION. RN2 asks "is every promised directory there?" and
## would pass with an EXTRA one, or with an index row for a shard nobody made.
## This asks the other way: the set of shard directories on disk and the set of
## shard ids in the index must be THE SAME SET, and both must equal the odometer.
check {RN4 the directories on disk, the index rows and the odometer are one set} \
  [apply {{st} {
    set d [c_ans ase::campaign_dir $st]
    set ondisk {}
    foreach p [glob -nocomplain -directory $d shard-*] { lappend ondisk [file tail $p] }
    set inindex {}
    foreach r [lrange [c_ans ase::campaign_index_read $st] 1 end] { lappend inindex [lindex $r 0] }
    set odo {}
    for {set i 0} {$i < [c_ans ase::campaign_count $st]} {incr i} {
      lappend odo [c_ans ase::campaign_shard_id $i]
    }
    return [list [expr {[lsort $ondisk] eq [lsort $odo]}] \
                 [expr {[lsort $inindex] eq [lsort $odo]}] \
                 [llength $odo]]
  }} $RNST] {1 1 4}

## ⚠ TOTAL, AND IT HAD TO BE MADE SO. This row read the shard decks with a bare
## `open` inside an `apply`; when the deck's NAME changed the read raised, and
## `--nogui --pipe` exits 0 on an uncaught mid-script error -- so the suite DIED
## after RN4 and printed no `RESULT:` line at all. Measured. Every read below
## answers a comparable value instead.
proc rn_slurp {path} {
  if {![file isfile $path]} { return "NOFILE:[file tail $path]" }
  if {[catch {::open $path r} f]} { return "NOOPEN:[file tail $path]" }
  set t [read $f]
  catch {::close $f}
  return $t
}
proc rn_shard_deck {st i} {
  return [rn_slurp [file join [ase::campaign_shard_dir $st $i] rc_ase.spice]]
}
check {RN5 every shard's deck is the NOMINAL deck plus this point's own lines} \
  [apply {{st} {
    set n [rn_slurp [c_ans ase::campaign_deck_path $st]]
    set a [c_ans rn_shard_deck $st 0]
    set b [c_ans rn_shard_deck $st 3]
    return [list [expr {![string match NOFILE:* $n]}] \
                 [expr {![string match NOFILE:* $a]}] \
                 [expr {$a ne $n}] [expr {$b ne $n}] [expr {$a ne $b}]]
  }} $RNST] {1 1 1 1 1}

check {RN6 the index carries the coordinates, a zero exit and a real raw path} \
  [lrange [c_ans ase::campaign_index_read $RNST] 1 end] \
  [list {shard-0001 1k 3k 0 shard-0001/rc_ase.raw} {shard-0002 1k 4k 0 shard-0002/rc_ase.raw} \
        {shard-0003 2k 3k 0 shard-0003/rc_ase.raw} {shard-0004 2k 4k 0 shard-0004/rc_ase.raw}]

## A SHARD THAT FAILS IS A ROW, NOT A GAP. The stand-in exits 3 for the point
## seeded 9911; every other point is untouched.
rn_fresh
set RNFST [rn_state [c_sweep enabled 1 seed 9910 axes {{kind temp values {27 85 125}}}]]
set RNFRES [c_ans ase::campaign_run ngspice $RNFST [c_netlist]]
check {RN7 one failing shard does not stop the campaign and lands in the index as its own exit code} \
  [list [dict get $RNFRES status] [dict get $RNFRES ran] \
        [lrange [c_ans ase::campaign_index_read $RNFST] 1 end]] \
  [list done 3 [list {shard-0001 27 0 shard-0001/rc_ase.raw} {shard-0002 85 3 -} \
                      {shard-0003 125 0 shard-0003/rc_ase.raw}]]

## ⚠ STOP KEEPS EVERY COMPLETED SHARD, AND THE INDEX SAYS WHICH POINTS NEVER
## RAN. That is the whole case for one process per point: a `.control` loop
## leaves `sim_status = 0`, indistinguishable from success.
rn_fresh
set RNSST [rn_state [c_sweep enabled 1 seed 10 axes {{kind temp values {27 85 125 150}}}]]
set RNSRES [c_ans ase::campaign_run ngspice $RNSST [c_netlist] \
  [list apply {{i n r} { return [expr {$i >= 1 ? {stop} : {}}] }}]]
check {RN8 a Stop after point 2 keeps both completed shards and marks the rest as never run} \
  [list [dict get $RNSRES status] [dict get $RNSRES ran] [dict get $RNSRES of] \
        [lrange [c_ans ase::campaign_index_read $RNSST] 1 end]] \
  [list stopped 2 4 [list {shard-0001 27 0 shard-0001/rc_ase.raw} \
                           {shard-0002 85 0 shard-0002/rc_ase.raw} \
                           {shard-0003 125 - -} {shard-0004 150 - -}]]

check {RN8b and the stopped campaign really made only the directories it ran} \
  [apply {{st} {
    set o {}
    foreach p [lsort [glob -nocomplain -directory [c_ans ase::campaign_dir $st] shard-*]] {
      lappend o [file tail $p]
    }
    return $o
  }} $RNSST] {shard-0001 shard-0002}

## ⚠ A REFUSED CAMPAIGN LEAVES NOTHING BEHIND. The refusal tier is re-evaluated
## in the runner, not only where the campaign was configured -- a `.state` can be
## hand-edited and a run directory can be cleared between the dialog and the
## button.
rn_fresh
check {RN9 a refused campaign makes no directory and runs nothing} \
  [apply {{} {
    global scratch
    set st [rn_state [c_sweep enabled 1 axes {{kind var name temp values {27 125}}}]]
    set r [c_ans ase::campaign_run ngspice $st [c_netlist]]
    return [list [dict get $r status] [dict get $r ran] \
                 [c_ids [dict get $r refusals]] \
                 [file exists [c_ans ase::campaign_dir $st]]]
  }}] {refused 0 temp_not_param 0}

## ⚠ AND A CAMPAIGN WHOSE NOMINAL DECK CANNOT BE RENDERED LEAVES NOTHING BEHIND
## EITHER. `render_deck` has a refusal tier of its own -- a hand-edited `.state`
## reaches it directly -- and it RAISES; with the directory made first, such a
## bench left a `campaign/` directory with no index and no shards in it, which is
## indistinguishable from a campaign that ran and produced nothing. The bench
## below asks for two models of the operating-point ladder at once, which is one
## of the three things that tier refuses.
check {RN9b a campaign whose nominal deck cannot be rendered makes no directory either} \
  [apply {{} {
    rn_fresh
    set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27 85}}}] \
             [list opstrategy {newton 1 gmin 0 source 0 transient 0} \
                   options {{name noopiter value 1}}]]
    set raised [catch {ase::campaign_prepare ngspice $st [c_netlist]}]
    return [list $raised [file exists [c_ans ase::campaign_dir $st]]]
  }}] {1 0}

## ⚠ 1469: A SEED ONE PAST THE TOP IS REFUSED BEFORE ANYTHING EXISTS -- through
## the runner AND through Re-run Point, because a `.state` can be hand-edited and
## neither door goes through the dialog.
check {SR9 a campaign seeded one past the top is refused by the runner and by\
 Re-run Point, and makes no directory} \
  [apply {{} {
    rn_fresh
    set st [rn_state [c_sweep enabled 1 seed 2147483648 axes {{kind temp values {27 85}}}]]
    set r  [c_ans ase::campaign_run ngspice $st [c_netlist]]
    set rr [c_ans ase::campaign_rerun ngspice $st [c_netlist] 1]
    set o {}
    foreach x [list $r $rr] {
      if {[catch {list [dict get $x status] [c_ids [dict get $x refusals]]} v]} { set v "BAD:$x" }
      lappend o $v
    }
    lappend o [file exists [c_ans ase::campaign_dir $st]]
    return $o
  }}] {{refused badseed} {refused badseed} 0}

## ⚠ AND A CAMPAIGN THAT CROSSES THE TOP RUNS, WITH THE FOLDED SEED IN THE SHARD'S
## OWN DECK -- so the adapter's promise that a point re-run by hand from its own
## directory reproduces it still holds -- and Re-run Point writes that deck again,
## byte for byte. The deck is DELETED before the re-run, so "identical" cannot be
## a file nobody touched.
check {SR10 a campaign seeded at the top writes seed 2147483647 and then 1 into its\
 shard decks, never 2147483648, and Re-run Point rewrites the folded deck byte for\
 byte} \
  [apply {{} {
    rn_fresh
    set st [rn_state [c_sweep enabled 1 seed 2147483647 axes {{kind temp values {27 85}}}]]
    set r [c_ans ase::campaign_run ngspice $st [c_netlist]]
    set seeds {}
    foreach i {0 1} {
      lappend seeds {*}[regexp -all -inline {seed=-?[0-9]+} [c_ans rn_shard_deck $st $i]]
    }
    set before [c_ans rn_shard_deck $st 1]
    file delete [file join [ase::campaign_shard_dir $st 1] rc_ase.spice]
    set rr [c_ans ase::campaign_rerun ngspice $st [c_netlist] 1]
    set after [c_ans rn_shard_deck $st 1]
    set s0 {} ; catch {set s0 [dict get $r status]}
    set s1 {} ; catch {set s1 [dict get $rr status]}
    return [list $s0 $seeds $s1 \
                 [expr {$before eq $after && ![string match NOFILE:* $after]}]]
  }}] {done {seed=2147483647 seed=1} done 1}

## ⚠ THE INDEX IS WRITTEN AFTER EVERY SHARD, NOT ONCE AT THE END. An index
## written only on success never describes the run anyone needs it for -- and it
## is COMPLETE from the first step, so a campaign killed at its second point
## still names its fourth.
check {RN10 after every step the file on disk has a row for every point, and one more of them has run} \
  [apply {{} {
    global __rows scratch
    set __rows {}
    rn_fresh
    set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27 85 125}}}]]
    c_ans ase::campaign_run ngspice $st [c_netlist] \
      [list apply {{st i n r} {
        global __rows
        set back [lrange [ase::campaign_index_read $st] 1 end]
        set done 0
        foreach row $back { if {[lindex $row 2] ne {-}} { incr done } }
        lappend __rows [list [llength $back] $done]
        return {}
      }} $st]
    return $__rows
  }}] {{3 1} {3 2} {3 3}}

## ⚠ A STALL MUST BE A NAMED OUTCOME, NEVER THE ABSENCE OF ONE. `ase::wait` is an
## UNBOUNDED `vwait`: a single run's is bounded by the user's own Stop button, a
## campaign's is not, and one wedged shard costs every point behind it. So the
## wait is raced against an `after`, the overrunning process is killed by the id
## this campaign started, and the point lands in the index as exit **124** -- the
## code `timeout` and `run_suites.sh` already read as TIMEOUT.
##
## Driven by a stand-in that sleeps for thirty seconds against a ONE-SECOND
## budget, so the row measures the bound rather than asserting that a number is
## positive.
proc rn_timeout_run {secs} {
  global scratch RNBIN
  rn_fresh
  set slow [file join $RNBIN slowsim]
  ## ⚠ `exec sleep`, NOT `sleep`. A plain `sleep 30` leaves the SHELL as the
  ## process `execute` knows about and the sleeper as its child -- killing the
  ## shell then leaves a grandchild holding the pipe open, so EOF never arrives
  ## and the run looks alive long after it was stopped. `exec` makes the sleeper
  ## the process itself, which is the shape a real simulator has.
  ##
  ## ⚠ AND IT HANGS ONLY ON A CAMPAIGN DECK. `ase::run_deck` asks
  ## `ase::cap_report` on every run, and a binary that never answers the
  ## capability probe burns `ase::cap_budget_ms` -- **30 seconds** -- on EVERY
  ## shard, because a probe that times out is not cached. Measured: 31,296 ms for
  ## the probe and 64,420 ms for a two-point campaign whose shard budget was ONE
  ## second. That is ASE-L's existing behaviour and not this timeout's, and a
  ## stand-in that answers the probe instantly is what lets the row below measure
  ## the shard bound instead of the probe's.
  rn_wr $slow [string map [list @SECS@ $::RNSLEEP] $::RNSLOWSTUB] 0755
  catch {ase::sim_register slowstub $slow}
  set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27 85}}}] \
           [list sim_entry {name slowstub}]]
  ## ⚠ THE CAPABILITY PROBE IS PAID FIRST, OUTSIDE THE CLOCK, and finding out
  ## why cost a red. `ase::run_deck` asks `ase::cap_report`, which probes the
  ## registered program once per session against `ase::cap_budget_ms` -- **30
  ## seconds** -- so a binary that never answers burns the whole budget on the
  ## first shard and the campaign's wall time says nothing about the shard bound.
  ## That is ASE-L's existing behaviour and not this timeout's; warming it here
  ## makes the number below measure the thing it claims to.
  catch {ase::sim_apply_choice $st}
  catch {ase::sim_capabilities ngspice}
  rename ::ase::campaign_shard_timeout ::rn_saved_tmo
  proc ::ase::campaign_shard_timeout {} [list return $secs]  ;# one second
  set t0 [clock milliseconds]
  set r [c_ans ase::campaign_run ngspice $st [c_netlist]]
  set dt [expr {[clock milliseconds] - $t0}]
  rename ::ase::campaign_shard_timeout {}
  rename ::rn_saved_tmo ::ase::campaign_shard_timeout
  catch {ase::sim_select campstub}
  return [list $r $dt $st]
}
check {RN11 a shard that never finishes is stopped, lands in the index as 124, and the campaign carries on} \
  [apply {{} {
    lassign [rn_timeout_run 1] r dt st
    if {$r eq {NOPROC} || [string match RAISED:* $r]} { return "RUNNER:$r" }
    set exits {}
    foreach row [lrange [c_ans ase::campaign_index_read $st] 1 end] {
      lappend exits [lindex $row 2]
    }
    ## both points time out, both are named, and the whole two-point campaign
    ## finished in a few seconds against the SIXTY that two unbounded 30-second
    ## shards would have cost. The budget under test is one second per shard.
    return [list [dict get $r status] [dict get $r ran] $exits \
                 [expr {$dt < 15000}]]
  }}] {done 2 {124 124} 1}

## ⚠ THIS ROW WAS VACUOUS AND SABOTAGE FOUND IT. It asked `ps -C sh` for a
## process that had `exec`ed away -- `sh` is exactly what is NOT there any more --
## so it answered 0 whether or not the kill happened, and mutation n5 (remove the
## kill entirely) sailed past it. The sleeper is now given a duration nothing else
## on this machine uses, and the row looks for THAT.
## ⚠ AND IT WAITS FOR THE REAP, WHICH IS NOT THE SAME AS WAITING FOR THE KILL.
## `exec kill -9` returns as soon as the signal is delivered; the process leaves
## the table a moment later. Measured: this row read the table microseconds after
## the campaign returned and found **2** survivors that the kill had already
## despatched -- a row that would have flaked about one run in some. The claim is
## "nothing is left running", so it is given two seconds to become true and fails
## only if it does not.
check {RN11b and the stopped shards left no simulator process behind} \
  [apply {{} {
    set n 99
    for {set i 0} {$i < 20} {incr i} {
      set out {}
      catch {exec ps -e -o args=} out
      set n 0
      foreach l [split $out "\n"] {
        if {[string match "*sleep $::RNSLEEP*" $l]} { incr n }
      }
      if {$n == 0} { break }
      after 100
    }
    return $n
  }}] 0

## ⚠ AND THE LOCK GOES WITH THE KILL. `ase::run_done` is what normally clears the
## in-flight lock and it fires on EOF, which a killed process does not always
## deliver -- see RNSLOWSTUB2's header. Without the campaign clearing it, the NEXT
## campaign over the same run directory is refused "something is already writing
## that file", by a run nobody is waiting for. Measured: it cost rows RN15b and
## PD1 before it was understood, and mutations n5 and n6 both live here.
check {RN11c a shard killed on its deadline releases its lock, so the next campaign over the same directory is not refused by a dead run} \
  [apply {{} {
    global scratch RNBIN RNSLOWSTUB2
    rn_fresh
    set slow2 [file join $RNBIN slowsim2]
    rn_wr $slow2 [string map [list @SECS2@ $::RNSLEEP2] $RNSLOWSTUB2] 0755
    catch {ase::sim_register slowstub2 $slow2}
    set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27}}}] \
             [list sim_entry {name slowstub2}]]
    catch {ase::sim_apply_choice $st}
    catch {ase::sim_capabilities ngspice}
    rename ::ase::campaign_shard_timeout ::rn_saved_tmo2
    proc ::ase::campaign_shard_timeout {} { return 1 }
    set r [c_ans ase::campaign_run ngspice $st [c_netlist]]
    set sst [c_ans ase::campaign_shard_state ngspice $st 0]
    set key [c_ans ase::run_lock_key $sst]
    set held [c_ans ase::run_in_flight $key]
    ## and a second campaign over the SAME directory is not refused by it
    set r2 [c_ans ase::campaign_run ngspice $st [c_netlist]]
    rename ::ase::campaign_shard_timeout {}
    rename ::rn_saved_tmo2 ::ase::campaign_shard_timeout
    catch {ase::sim_select campstub}
    set e1 {} ; set e2 {}
    catch {set e1 [lindex [lindex [dict get $r rows] 0] 2]}
    catch {set e2 [lindex [lindex [dict get $r2 rows] 0] 2]}
    return [list $e1 $held $e2]
  }}] {124 {} 124}

## ⚠ AND A SHARD THAT CANNOT START IS A ROW, NOT A CRASH -- measured, not
## asserted. `ase::run_deck` RAISES for an unrunnable binary, a refused
## pre-flight and a failed co-simulation build; `ase::campaign_step` catches that
## because the alternative is losing every point behind the first bad one. The
## coordinator's question was whether the sentence really is said PER SHARD, and
## it is: three points, three refusals, three sentences, each naming the entry.
proc rn_echoes {script} {
  set ::rn_said {}
  rename ::ase::echo ::rn_saved_echo
  proc ::ase::echo {msg {tag {}}} { lappend ::rn_said $msg ; return 1 }
  catch {uplevel #0 $script}
  rename ::ase::echo {}
  rename ::rn_saved_echo ::ase::echo
  return $::rn_said
}
check {RN15 a campaign whose simulator entry points at nothing records every point as failed and says so once per shard} \
  [apply {{} {
    global scratch
    rn_fresh
    catch {ase::sim_register deadstub [file join $scratch bin nosuchsimulator]}
    set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27 85 125}}}] \
             [list sim_entry {name deadstub}]]
    set said [rn_echoes [list ase::campaign_run ngspice $st [c_netlist]]]
    set exits {}
    foreach row [lrange [c_ans ase::campaign_index_read $st] 1 end] {
      lappend exits [lindex $row 2]
    }
    set named 0
    foreach m $said { if {[string first {did not start} $m] >= 0} { incr named } }
    catch {ase::sim_select campstub}
    return [list $exits $named]
  }}] {{-1 -1 -1} 3}

check {RN15b and a campaign whose simulator IS runnable says that sentence not once} \
  [apply {{} {
    rn_fresh
    set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27 85}}}]]
    set said [rn_echoes [list ase::campaign_run ngspice $st [c_netlist]]]
    set named 0
    foreach m $said { if {[string first {did not start} $m] >= 0} { incr named } }
    return $named
  }}] 0

## ⚠ THE BENCH BEING RUN DECIDES WHICH PROGRAM STARTS -- the 2026-09-08 ruling,
## and it is a defect this suite FOUND rather than one it was written for. Every
## shard resolves its simulator through `run_cmd`, which asks the PROCESS-GLOBAL
## selection; with two ASE-L windows open that cache can hold the other bench's
## answer. Measured before the fix: a campaign whose state named `campstub` ran
## whichever entry was last selected, and wrote the results into this bench's
## shards under this bench's coordinates.
check {RN12 a campaign runs the simulator the BENCH names, not the one last selected} \
  [apply {{} {
    global scratch RNBIN RNSTUB RNRAWF
    rn_fresh
    ## a SECOND stand-in that writes a raw with a different marker in its title
    set other [file join $RNBIN othersim]
    set oraw [file join $scratch other.raw]
    rn_wr $oraw "Title: OTHER stand-in\nDate: x\nPlotname: Operating Point\nFlags: real\nNo. Variables: 1\nNo. Points: 1\nVariables:\n\t0\tv(a)\tvoltage\nValues:\n 0\t2.000000e+00\n"
    rn_wr $other [string map [list @RAW@ $oraw @FAILMARK@ {zzz-never}] $RNSTUB] 0755
    catch {ase::sim_register othersim $other}
    ## select the OTHER one, then run a bench that names campstub
    catch {ase::sim_select othersim}
    set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27}}}]]
    c_ans ase::campaign_run ngspice $st [c_netlist]
    set rp [file join [c_ans ase::campaign_shard_dir $st 0] rc_ase.raw]
    set txt {}
    if {[file isfile $rp]} { set f [open $rp r] ; set txt [read $f] ; close $f }
    catch {ase::sim_select campstub}
    return [list [expr {[string first {campaign stand-in} $txt] >= 0}] \
                 [expr {[string first {OTHER stand-in} $txt] >= 0}]]
  }}] {1 0}

## A SHARD THAT RAN BUT PRODUCED NOTHING IS NOT THE SAME AS ONE THAT NEVER RAN,
## and the index must be able to say both. Here the directory exists and the
## exit code is real; only the results file is missing.
check {RN13 a shard that ran and wrote no results file has an exit code and a `-` raw} \
  [apply {{} {
    rn_fresh
    set st [rn_state [c_sweep enabled 1 seed 9911 axes {{kind temp values {27}}}]]
    c_ans ase::campaign_run ngspice $st [c_netlist]
    set r [lindex [lrange [c_ans ase::campaign_index_read $st] 1 end] 0]
    return [list $r [file isdirectory [c_ans ase::campaign_shard_dir $st 0]]]
  }}] {{shard-0001 27 3 -} 1}

## ⚠ AND A CAMPAIGN LEAVES THE BENCH'S OWN STATE ALONE. `campaign_shard_state`
## builds a COPY; a campaign that mutated the session's state would leave the
## user's bench holding the last point's coordinates after the run.
check {RN14 running a campaign does not move one key of the bench's own state} \
  [apply {{} {
    rn_fresh
    set st [rn_state [c_sweep enabled 1 seed 10 axes {
      {kind var name myres values {1k 2k}} {kind temp values {40 85}}}] \
      [list variables {{name myres value 9k}} temperature 27]]
    set before [ase::state_serialize $st]
    c_ans ase::campaign_run ngspice $st [c_netlist]
    return [string equal $before [ase::state_serialize $st]]
  }}] 1

## The section's shortened budget ends here; everything below runs with the
## shipped one, so nothing outside section RN is measured against a stub.
rename ::ase::campaign_shard_timeout {}
rename ::rn_production_tmo ::ase::campaign_shard_timeout
check {RN16 and the shipped budget is back in force for everything below} \
  [c_ans ase::campaign_shard_timeout] 1800

# ============================================================================
# SECTION PD -- ⚖ R2: THE PER-SHARD PRE-DECK FILE
# ============================================================================
# ⚠ THE FILE GOES IN THE SHARD, NEVER IN $HOME AND NEVER IN THE SHARED RUNDIR.
# Issues 1453 and 1458 are both about ASE-L writing where it should not, and a
# task whose subject is writing `.spiceinit` files is the one that must not.

rn_fresh
check {PD1 a bench with a pre-deck option gets a .spiceinit in ITS OWN SHARD} \
  [apply {{} {
    global scratch
    set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27 85}}}] \
             [list options {{name ps_global_hash_table value 1}}]]
    c_ans ase::campaign_run ngspice $st [c_netlist]
    set a [file join [c_ans ase::campaign_shard_dir $st 0] .spiceinit]
    set b [file join [c_ans ase::campaign_shard_dir $st 1] .spiceinit]
    set c [file join [dict get $st rundir] .spiceinit]
    set txt {}
    if {[file isfile $a]} { set f [open $a r] ; set txt [read $f] ; close $f }
    return [list [file isfile $a] [file isfile $b] [file exists $c] \
                 [expr {[string first {ps_global_hash_table} $txt] >= 0}]]
  }}] {1 1 0 1}

check {PD1b a bench with NO pre-deck option gets no file at all} \
  [apply {{} {
    rn_fresh
    set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27}}}]]
    c_ans ase::campaign_run ngspice $st [c_netlist]
    return [file exists [file join [c_ans ase::campaign_shard_dir $st 0] .spiceinit]]
  }}] 0

check {PD2 the file ASE-L writes is marked as ASE-L's, so a foreign one is left alone} \
  [apply {{} {
    rn_fresh
    set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27}}}] \
             [list options {{name ps_global_hash_table value 1}}]]
    set d [c_ans ase::campaign_shard_dir $st 0]
    file mkdir $d
    set p [file join $d .spiceinit]
    rn_wr $p "* not ours\nset mine=1\n"
    c_ans ase::campaign_run ngspice $st [c_netlist]
    set f [open $p r] ; set txt [read $f] ; close $f
    return [string trim $txt]
  }}] "* not ours\nset mine=1"

check {PD3 nothing under \$HOME is opened for writing by a campaign} \
  [apply {{} {
    ## The one path the campaign can compose for a pre-deck file is the shard's,
    ## and the shard's rundir is under the bench's own run directory. This row
    ## pins that relationship rather than trusting it.
    global scratch
    set st [rn_state [c_sweep enabled 1 axes {{kind temp values {27}}}]]
    set p [ase::backend::ngspice::predeck_file \
             [c_ans ase::campaign_shard_state ngspice $st 0]]
    return [list [string match [file join $scratch rn campaign shard-0001 .spiceinit] $p] \
                 [expr {[string first $::env(HOME) $p] == 0 && \
                        [string first $scratch $p] != 0}]]
  }}] {1 0}

# ============================================================================
# SECTION NT -- WHAT THE RUN SAYS, ONCE, BEFORE IT STARTS
# ============================================================================

check {NT1 a bench with no campaign says nothing} \
  [c_ans ase::campaign_notes ngspice [c_state]] {}

check {NT2 the first sentence names the point count, the axes and the mode} \
  [lindex [c_ans ase::campaign_notes ngspice \
    [c_state sweep [c_sweep enabled 1 axes {
       {kind var name myres values {1k 2k}}
       {kind temp values {27 125}}}]]] 0] \
  {campaign: 4 points over 2 axes (myres, temp), one simulator process per point}

check {NT2b and it uses the singular for one of each} \
  [lindex [c_ans ase::campaign_notes ngspice \
    [c_state sweep [c_sweep enabled 1 axes {{kind temp values {27}}}]]] 0] \
  {campaign: 1 point over 1 axis (temp), one simulator process per point}

## §11a: "the runner SAYS which mode it chose". This is that sentence.
check {NT3 an alter-only campaign is told that a cheaper mode existed and was not taken} \
  [lindex [c_ans ase::campaign_notes ngspice \
    [c_state sweep [c_sweep enabled 1 axes {
       {kind inst target r1 param resistance values {1k 2k}}}]]] 1] \
  {campaign: every axis in this campaign avoids a re-parse, so one process could run all 2 points; ASE-L runs one process per point, which keeps every completed point when a campaign is stopped}

check {NT3b and a re-parsing campaign is NOT told that, because it would be untrue} \
  [apply {{} {
    set n [c_ans ase::campaign_notes ngspice \
      [c_state sweep [c_sweep enabled 1 axes {{kind temp values {27 85}}}]]]
    set hit 0
    foreach s $n { if {[string first {could run all} $s] >= 0} { incr hit } }
    return $hit
  }}] 0

check {NT4 an unseeded campaign is told what that costs} \
  [lindex [c_ans ase::campaign_notes ngspice \
    [c_state sweep [c_sweep enabled 1 axes {{kind temp values {27}}}]]] 1] \
  {campaign: this campaign has no seed, so anything the simulator draws for itself will differ the next time it is run}

check {NT5 a seeded campaign is told the per-shard rule, and both of the seed's caveats} \
  [lrange [c_ans ase::campaign_notes ngspice \
    [c_state sweep [c_sweep enabled 1 seed 500 axes {{kind temp values {27}}}]]] 1 end] \
  [list {campaign: seeded from 500; shard N is seeded 500+N, so a single point can be re-run on its own and give the same answer} \
        {campaign: transient white and 1/f noise sources are not covered by it: their generator is seeded from the process id, so a `trnoise` source draws differently on every run whatever the seed says} \
        {campaign: it is set as a deck option, so re-running a single point by hand from its own directory reproduces that point exactly}]

# ============================================================================
# SECTION EE -- THE REAL SIMULATORS, BOTH OF THEM
# ============================================================================
# Two halves of a feature tested in different suites never meet. Here the deck
# ASE-L renders is RUN, its results are read back through ASE-L's own readers,
# and the campaign's claim -- that each axis reaches the answer -- is checked
# against physics rather than against a fixture.

if {[catch {
set EEBINS [list apt /usr/bin/ngspice \
                 fork /home/analog/dev/ngspice/build-ver_50/src/ngspice]
foreach {eetag eebin} $EEBINS {
  if {![file executable $eebin]} {
    puts "ok:   EE0/$eetag SKIPPED -- no binary at $eebin"
    incr npass
    continue
  }
  catch {ase::sim_register ee$eetag $eebin}
  set eedir [file join $scratch ee$eetag]
  file delete -force $eedir
  file mkdir $eedir
  set eest [ase::state_default]
  dict set eest design [dict create cell rc lib $eedir]
  dict set eest rundir $eedir
  dict set eest simulator ngspice
  dict set eest sim_entry [list name ee$eetag]
  dict set eest save_all_v 1
  dict set eest analyses {{type tran enabled 1 step 1u stop 40u}}
  dict set eest variables {{name myres value 1k}}
  dict set eest outputs {{expr v(out) plot 1 save 1}}
  dict set eest measurements {{name vmax analysis tran kind max target v(out)}}
  dict set eest sweep [dict create enabled 1 seed 100 axes {
    {kind var name myres values {1k 4k}}
    {kind inst target c1 param capacitance values {1n 4n}}}]
  set eenl "* rc\nv1 in 0 pulse(0 1 0 1n 1n 100u 200u)\nr1 in out {myres}\nc1 out 0 1n\n.end\n"
  set eeres [c_ans ase::campaign_run ngspice $eest $eenl]

  check "EE1/$eetag four real shards, four zero exit codes" \
    [list [dict get $eeres status] [dict get $eeres ran] \
          [apply {{st} {
            set o {}
            foreach r [lrange [ase::campaign_index_read $st] 1 end] { lappend o [lindex $r 3] }
            return $o
          }} $eest]] {done 4 {0 0 0 0}}

  ## ⚠ PHYSICS, NOT A FIXTURE. The RC product of point 2 (1k x 4n) equals that
  ## of point 3 (4k x 1n), so those two measurements MUST agree -- and points 1
  ## and 4 must not. A campaign whose axes silently failed to reach the deck
  ## would give four identical numbers and pass a "did it run" row.
  check "EE2/$eetag each axis really reached the deck, and the two equal-RC points agree" \
    [apply {{st} {
      set v {}
      foreach r [lrange [ase::campaign_index_read $st] 1 end] { lappend v [lindex $r 5] }
      if {[llength $v] != 4} { return "BADROWS:$v" }
      foreach x $v { if {![string is double -strict $x]} { return "NOTNUM:$v" } }
      return [list [expr {abs([lindex $v 1] - [lindex $v 2]) < 1e-6}] \
                   [expr {abs([lindex $v 0] - [lindex $v 3]) > 1e-3}] \
                   [expr {[lindex $v 0] > [lindex $v 3]}]]
    }} $eest] {1 1 1}

  ## THE SURPLUS DIRECTION AGAIN, ON A REAL RUN: nothing on disk that the index
  ## does not name, and nothing in the index that is not on disk.
  check "EE3/$eetag the directory and the index name exactly the same shards" \
    [apply {{st} {
      set d [ase::campaign_dir $st]
      set ondisk {}
      foreach p [glob -nocomplain -directory $d shard-*] { lappend ondisk [file tail $p] }
      set idx {}
      foreach r [lrange [ase::campaign_index_read $st] 1 end] { lappend idx [lindex $r 0] }
      return [expr {[lsort $ondisk] eq [lsort $idx]}]
    }} $eest] 1

  ## ⚠ AND ON A REAL BINARY THE SHARD DIRECTORY IS COMPLETE. The plot sidecar is
  ## written by the simulator executing the deck's own `echo ... >> <path>`, so
  ## it is the one artifact a stand-in cannot produce and the one that proves the
  ## deck ASE-L rendered really ran, in this shard's own directory.
  check "EE3b/$eetag every shard holds the netlist, the deck, the log, the results and the plot sidecar" \
    [apply {{st} {
      set o {}
      foreach i {0 3} {
        set d [ase::campaign_shard_dir $st $i]
        set n 0
        foreach f {rc.spice rc_ase.spice rc_ase.log rc_ase.raw rc_ase.plotmap} {
          if {[file exists [file join $d $f]]} { incr n }
        }
        lappend o $n
      }
      return $o
    }} $eest] {5 5}

  ## ⚠ THE SEED REALLY IS PER SHARD AND REALLY DOES REACH THE SIMULATOR. This
  ## deck's resistor is drawn by the simulator's own `agauss`, so two shards must
  ## disagree and a re-run of the SAME shard must agree -- which is what
  ## `.options seed=<base+N>` buys and what `setseed` in `.spiceinit` does not.
  check "EE4/$eetag a seeded campaign gives each point its own draw, and repeats it exactly" \
    [apply {{bin dir} {
      proc ee_draw {bin dir seed} {
        set p [file join $dir s$seed.cir]
        set f [open $p w]
        puts $f "* seeded draw"
        puts $f ".param rv=agauss(1000,100,1)"
        puts $f "r1 a 0 {rv}"
        puts $f "v1 a 0 1"
        puts $f ".options seed=$seed"
        puts $f ".control"
        puts $f "op"
        puts $f "print @r1\[resistance\]"
        puts $f ".endc"
        puts $f ".end"
        close $f
        set out {}
        catch {exec $bin -b $p 2>@1} out
        foreach l [split $out "\n"] {
          if {[regexp {^@r1\[resistance\] *= *(\S+)} $l -> v]} { return $v }
        }
        return NODRAW
      }
      set a1 [ee_draw $bin $dir 101]
      set a2 [ee_draw $bin $dir 101]
      set b1 [ee_draw $bin $dir 102]
      return [list [expr {$a1 eq $a2}] [expr {$a1 ne $b1}] \
                   [expr {[string is double -strict $a1]}]]
    }} $eebin $eedir] {1 1 1}

  ## ⚠ AND THE MECHANISM THE PLAN RANKED FIRST IS FATAL ON ONE OF THESE TWO.
  ## `var()` arrived in ngspice-46; on 45.2 the deck does not degrade, it dies.
  ## This row is why no axis in this block emits `var()`.
  check "EE5/$eetag `var()` is measured, never assumed -- and its failure is fatal, not silent" \
    [apply {{bin dir tag} {
      set p [file join $dir varprobe.cir]
      set f [open $p w]
      puts $f "* var probe"
      puts $f ".param rv='var(myres)'"
      puts $f "r1 a 0 {rv}"
      puts $f "v1 a 0 1"
      puts $f ".control"
      puts $f "op"
      puts $f "print @r1\[resistance\]"
      puts $f ".endc"
      puts $f ".end"
      close $f
      set ini [file join $dir .spiceinit]
      set f [open $ini w] ; puts $f "set myres=4700" ; close $f
      set out {}
      set save [pwd]
      cd $dir
      catch {exec $bin -b $p 2>@1} out
      cd $save
      file delete -force $ini
      set fatal [expr {[string first {Undefined parameter [var]} $out] >= 0}]
      set worked 0
      foreach l [split $out "\n"] {
        if {[regexp {^@r1\[resistance\] *= *4\.700000e\+03} $l]} { set worked 1 }
      }
      ## apt 45.2 must be FATAL and must not work; the fork must work and must
      ## not be fatal. Either answer flipping is a finding, not a flake.
      if {$tag eq {apt}} { return [list $fatal $worked] }
      return [list $fatal $worked]
    }} $eebin $eedir $eetag] \
    [expr {$eetag eq {apt} ? {1 0} : {0 1}}]

  ## ⚠ AND THE SIXTH ACCEPTED-AND-INERT CASE, ON THE REAL BINARY: `setseed` in
  ## `<rundir>/.spiceinit` is accepted, says nothing, and seeds nothing.
  check "EE6/$eetag `setseed` in .spiceinit is accepted and does nothing, while the same line in .control works" \
    [apply {{bin dir} {
      proc ee_tr {bin dir where} {
        set p [file join $dir seed.cir]
        set f [open $p w]
        puts $f "* seed probe"
        puts $f "v1 1 0 trrandom(2 1m 0 1)"
        puts $f "r1 1 0 1k"
        puts $f ".control"
        if {$where eq {control}} { puts $f "setseed 12345" }
        puts $f "tran 1m 5m"
        puts $f "print v(1)\[1\]"
        puts $f ".endc"
        puts $f ".end"
        close $f
        set ini [file join $dir .spiceinit]
        file delete -force $ini
        if {$where eq {init}} {
          set f [open $ini w] ; puts $f "setseed 12345" ; close $f
        }
        set out {}
        set save [pwd] ; cd $dir
        catch {exec $bin -b $p 2>@1} out
        cd $save
        file delete -force $ini
        foreach l [split $out "\n"] {
          if {[regexp {^v\(1\)\[1\] *= *(\S+)} $l -> v]} { return $v }
        }
        return NOVAL
      }
      set i1 [ee_tr $bin $dir init]
      set i2 [ee_tr $bin $dir init]
      set c1 [ee_tr $bin $dir control]
      set c2 [ee_tr $bin $dir control]
      return [list [expr {$i1 ne $i2}] [expr {$c1 eq $c2}] \
                   [expr {[string is double -strict $c1]}]]
    }} $eebin $eedir] {1 1 1}

  ## ⚠ 1469 ON THE REAL BINARY. A campaign seeded at the TOP of the range whose two
  ## points differ ONLY by their seed (the resistor is the simulator's own
  ## `agauss`), so its second shard folds to seed 1. MEASURED BEFORE THE FIX on both
  ## binaries through this very runner, fork first: the second shard was written
  ## `seed=2147483648`, its log carried `Cannot convert ... to seed value`, and its
  ## measurement differed between two runs of the same campaign (fork 5.13913e-01
  ## then 4.75481e-01; apt 5.257042e-01 then 4.713302e-01), while the first shard
  ## repeated exactly.
  set sr_nl "* seed\n.param rv=agauss(1000,100,1)\nv1 in 0 dc 1\nr1 in out {rv}\nr2 out 0 1k\n.end\n"
  proc ee_seedcamp {tag dir sweep opts nl} {
    file delete -force $dir
    file mkdir $dir
    set st [ase::state_default]
    dict set st design [dict create cell rc lib $dir]
    dict set st rundir $dir
    dict set st simulator ngspice
    dict set st sim_entry [list name ee$tag]
    dict set st save_all_v 1
    dict set st analyses {{type tran enabled 1 step 1u stop 10u}}
    dict set st outputs {{expr v(out) plot 1 save 1}}
    dict set st measurements {{name vmax analysis tran kind max target v(out)}}
    dict set st options $opts
    dict set st sweep $sweep
    set r [c_ans ase::campaign_run ngspice $st $nl]
    set status {} ; catch {set status [dict get $r status]}
    set vals {}
    foreach row [lrange [ase::campaign_index_read $st] 1 end] {
      lappend vals [lindex $row 2] [lindex $row 4]
    }
    set warn 0 ; set logs 0 ; set seeds {}
    foreach sd [lsort [glob -nocomplain -type d [file join [ase::campaign_dir $st] shard-*]]] {
      set lg [file join $sd rc_ase.log]
      if {[file isfile $lg]} {
        incr logs
        incr warn [regexp -all {Cannot convert[^\n]*seed value} [rn_slurp $lg]]
      }
      lappend seeds {*}[regexp -all -inline {seed=-?[0-9]+} [rn_slurp [file join $sd rc_ase.spice]]]
    }
    return [dict create status $status vals $vals warn $warn logs $logs seeds $seeds]
  }
  set sr_top {enabled 1 seed 2147483647 axes {{kind temp values {27 27}}}}
  set sr_a [ee_seedcamp $eetag [file join $eedir srtop1] $sr_top {} $sr_nl]
  set sr_b [ee_seedcamp $eetag [file join $eedir srtop2] $sr_top {} $sr_nl]
  check "EE7/$eetag a campaign seeded at the top of the range reproduces EVERY shard\
 across two runs -- the one past the top included -- and its two shards draw\
 differently" \
    [apply {{a b} {
      set va [dict get $a vals] ; set vb [dict get $b vals]
      if {[llength $va] != 4} { return "BADROWS:$va" }
      foreach {e v} $va {
        if {$e ne {0} || ![string is double -strict $v]} { return "NOTRUN:$va" }
      }
      return [list [dict get $a status] [dict get $b status] [dict get $a seeds] \
                   [expr {$va eq $vb}] [expr {[lindex $va 1] ne [lindex $va 3]}]]
    }} $sr_a $sr_b] {done done {seed=2147483647 seed=1} 1 1}

  ## ⚠ AND NO SHARD LOG SAYS THE SEED WAS THROWN AWAY -- with the control that lets
  ## the grep disagree: an OPTIONS row `seed 0` (the options sheet is not this
  ## issue's form) reaches a shard log through the same runner, and there the
  ## warning IS found. Measured before the fix: `rc_ase.log` carries the simulator's
  ## stderr on both binaries. EE1's own campaign (seeded 100, four shards) is read
  ## too, so the claim covers every seeded campaign this section renders.
  set sr_z [ee_seedcamp $eetag [file join $eedir srzero] \
              {enabled 1 axes {{kind temp values {27}}}} {{name seed value 0}} $sr_nl]
  set sr_e1 {0 0}
  catch {
    set l 0 ; set w 0
    foreach sd [glob -nocomplain -type d [file join [ase::campaign_dir $eest] shard-*]] {
      set lg [file join $sd rc_ase.log]
      if {![file isfile $lg]} { continue }
      incr l
      incr w [regexp -all {Cannot convert[^\n]*seed value} [rn_slurp $lg]]
    }
    set sr_e1 [list $l $w]
  }
  check "EE8/$eetag no shard log of a seeded campaign says `Cannot convert ... seed\
 value`, and the same grep finds it in the one log whose deck really carries seed 0" \
    [list [expr {[dict get $sr_a logs] + [dict get $sr_b logs]}] \
          [expr {[dict get $sr_a warn] + [dict get $sr_b warn]}] \
          $sr_e1 \
          [dict get $sr_z logs] [dict get $sr_z warn] [dict get $sr_z seeds]] \
    {4 0 {4 0} 1 1 seed=0}

  check "EE9/$eetag on this binary's own entry a seed one past the top is refused\
 before any campaign directory or deck exists" \
    [apply {{tag dir} {
      file delete -force $dir
      file mkdir $dir
      set st [ase::state_default]
      dict set st design [dict create cell rc lib $dir]
      dict set st rundir $dir
      dict set st simulator ngspice
      dict set st sim_entry [list name ee$tag]
      dict set st analyses {{type op enabled 1}}
      dict set st sweep {enabled 1 seed 2147483648 axes {{kind temp values {27 85}}}}
      set r [c_ans ase::campaign_run ngspice $st "* r\nr1 a 0 1k\n.end\n"]
      set s {} ; set ids {}
      catch {set s [dict get $r status]}
      catch {set ids [c_ids [dict get $r refusals]]}
      return [list $s $ids [file exists [ase::campaign_dir $st]] \
                   [llength [glob -nocomplain -directory $dir *.spice]]]
    }} $eetag [file join $eedir srpast]] {refused badseed 0 0}
}
} eeerr]} { check {EE0 section EE ran to the end} "RAISED:$eeerr" {} }

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
# THE COMPLETION BANNER (issue 1456). `tests/banner_rule.tcl`'s `banner_complete`
# requires a WHOLE-LINE `OVERALL: ok`, and `run_regression.tcl` counts a case with
# no banner as a HARNESS failure however green its own checks are.
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
# AND AN EXPLICIT EXIT CODE. Measured 2026-09-15 by the driver, sabotaging issue
# 1469: `RESULT: 9 FAILED (152 passed)` exited rc 0, because the only `exit` lines
# in this file are inside the `/bin/sh` stand-in scripts it writes as TEXT. T1 reads
# the banner too; a reader of the exit code alone scored this suite green.
exit [expr {$fail ? 1 : 0}]
