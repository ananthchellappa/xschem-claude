# tests/headless/test_ase_sp_1452.tcl -- ISSUE 1452: S-PARAMETERS, WITH NO
# SCHEMATIC EDIT. doc/claude/ase_analyses_batch/PLAN.md Stage 9, the DECK half.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# FOUR S-PARAMETER BENCHES ARE COMMITTED IN THIS REPOSITORY --
# `ihp-sg13g2/xschem_libs/sg13g2_tests_ase/sp_{mim_cap,rfmim_cap,parasitic_cap,
# svaricap_test}` -- whose sources carry `portnum 1 z0 50` and whose ASE-L state
# says, in full:
#
#     analyses {{type op enabled 0} {type dc enabled 0}
#               {type ac enabled 0} {type tran enabled 0}}
#
# Four seeded rows, none of them the analysis the bench exists for, because
# ASE-L had no way to say `sp`. Somebody built those benches and then drove the
# simulator by hand.
#
# ============================================================================
# ⚠ AND THE OBVIOUS FIX IS THE ONE ASE-L IS NOT ALLOWED TO MAKE
# ============================================================================
# A PORT IS AN ORDINARY VOLTAGE SOURCE CARRYING `portnum` (`vsrc.c:31-37`);
# there is no port device and no port model. ASE-L's founding doctrine is that
# the schematic carries only the circuit, so `portnum 1 z0 50` may not be
# written onto it. `design-B` concluded from this that `sp` was simply
# unsatisfiable [crit §C11].
#
# It is satisfiable. MEASURED 2026-09-13 on apt 45.2 AND on the fork, on two
# ORDINARY V sources that declare no port anywhere in the netlist:
#
#     alter v1 portnum = 1 / alter v1 z0 = 50
#     alter v2 portnum = 2 / alter v2 z0 = 50
#     sp lin 3 100meg 1g
#        -> rc 0, `SP Analysis`, s_1_1[0] = 2.500000e-01,0.000000e+00
#
# ============================================================================
# ⚠ THE FOUR MEASUREMENTS THAT DECIDE THE SHAPE, ALL ON BOTH BINARIES
# ============================================================================
#  1. THE SAME LINES BELOW THE CARD KILL THE PROCESS.
#         `Error: No RF Port is present, cannot run sp analysis`
#         `ERROR: fatal error in ngspice, exit(1)`, rc 1
#     and the `echo` after the card NEVER PRINTED. `span.c:376-386` calls
#     `controlled_exit(EXIT_BAD)`, so every analysis after `sp` dies with it --
#     `op` included, which this batch keeps last in emit order (issue 0964).
#     One port gives `Error: Only one RF Port is found, we need at least two!`
#     and the same death. That is why `two_ports` is FATAL.
#
#  2. PROMOTING A SOURCE TO A PORT CHANGES EVERY OTHER ANALYSIS IN THE RUN.
#         op                       -> v(in) = 1.000000e+00
#         alter v1 portnum = 1 ... sp ...
#         op                       -> v(in) = 6.250000e-01
#     `vsrcset.c:53-79` adds an internal `<name>#res` node per port and
#     `vsrcload.c:51-64` stamps `g0 = 1/z0` across it.
#
#  3. AND IT CANNOT BE UNDONE.
#         alter v1 portnum = 0
#            -> `Internal Error: incomplete CKTunsetup(), this will cause
#               serious problems, please report this issue !`
#               `ERROR: fatal error in ngspice, exit(1)`, rc 1
#     So `sp` is emitted LAST OF ALL, after `op`. Rows SR4/SR5 are that claim
#     and the reason is in the registry's own comment.
#
#  4. A NARROWED SAVE LIST SILENTLY REMOVES THE WHOLE ANSWER.
#         .save v(mid) + sp  -> rc 0, plot `SP Analysis`, vectors `frequency`
#                               and `mid` and NOTHING ELSE. No S, no Y, no Z,
#                               nothing on either stream
#         .save all above it -> S_1_1 present
#     Hence `resultvecs own`.
#
# ============================================================================
# ⚠ THE ONE THE BRIEF ASKED ABOUT, AND THE ANSWER IS NO
# ============================================================================
# `evidence/sp-stage9.md` says the S-parameter vector names are mixed case and
# that "the reconciliation `mislabel` verdict from Stage 6 ... will disagree with
# the results file about what the plot is called -- that is the exact shape
# `mislabel` was written to catch, so it should catch this".
#
# MEASURED, ROWS SM1-SM4: **it does not, and it should not.** `mislabel`
# compares PLOT names, and `Plotname: SP Analysis` is byte-identical on the two
# binaries. Both of its comparisons are case-INSENSITIVE by construction
# (`string equal -nocase` against the results file, `string match -nocase`
# against the registry), so a lowercased `select` is tolerated -- proved here
# with a genuinely different name as the positive control.
#
# The mixed case is real and it lives in the VECTOR names, which `mislabel`
# never looks at. MEASURED 2026-09-13, the same deck written by both binaries
# and read back through `ase::cap_raw_plots`:
#
#     fork      frequency S_1_1 S_1_2 ... Y_1_1 ... Z_1_1 ...
#     apt 45.2  frequency s_1_1 s_1_2 ... y_1_1 ... z_1_1 ...
#
# This stage ships NO reader of those names -- `sp`'s `plots` row routes to the
# viewer and declares no `vectors` proc -- so nothing here can be wrong about
# them. Row SM5 pins the exposure so the surface that DOES read them (Stage 9's
# GUI half, PLAN.md §9b's matrix picker) cannot be written case-sensitively and
# stay green.
#
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
# ============================================================================
#   SR  the registry entry            SL  the emitted lines and their place
#   SN  the preconditions             SK  the `setup` contract as SCHEMA
#   SM  the reconciliation question   SC  the corpus and the round trip
#   SE  the END-TO-END run, on BOTH binaries (guarded legs)
#
# ⚠ SECTION SE IS THE ONLY ONE THAT STARTS A SIMULATOR, AND IT EXISTS BECAUSE
# OF ISSUE 1449: two halves of a feature tested in different suites never meet.
# It takes the deck ASE-L renders, runs it, and reads `S_1_1` back out of the
# results file. Its binaries come from `$env(ASE_SP_NGSPICE)` (colon-separated)
# or from the two CREW_BRIEF names them; a missing one SKIPS with its path
# printed, so the log never confuses "not tested" with "tested and fine".
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_sp_1452.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_sp_1452.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name got} { check $name [expr {$got ? 1 : 0}] 1 }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch sp1452]

## A call that never blows the suite up: an absent proc is NOPROC and a raise is
## RAISED:<message>, so a row reports a defect instead of a stack trace.
proc s_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}

## ⚠ A TOTAL `dict get`, AND A SABOTAGE IS WHY IT IS HERE. `--nogui --pipe`
## EXITS 0 ON AN UNCAUGHT MID-SCRIPT TCL ERROR, so a row that reads a key a
## sabotage has just removed does not fail -- it kills the suite silently, at rc
## 0, with no RESULT line. Measured while sabotaging the `setup` contract's
## `fields` declaration: one `dict get` took the whole file down and only the
## missing banner said so. Every row below that reads an optional key reads it
## through this.
proc s_dget {d k} {
  if {[catch {dict get $d $k} v]} { return MISSING }
  return $v
}

set SPPORTS {ports {{src v1 num 1 z0 50} {src v2 num 2 z0 50}}}
proc sp_row {args} {
  return [concat {type sp enabled 1 points 3 start 100meg stop 1g} $::SPPORTS $args]
}
proc sp_netlist {} {
  return "* spbench\nv1 in 0 dc 1 ac 1\nv2 out 0 dc 0 ac 0\nr1 in mid 50\nr2 mid 0 50\nr3 mid out 50\n.end\n"
}
proc sp_state {ans {rundir {}}} {
  global scratch
  if {$rundir eq {}} { set rundir $scratch }
  set st [ase::state_default]
  dict set st design [dict create cell spbench lib $scratch]
  dict set st rundir $rundir
  dict set st simulator ngspice
  dict set st analyses $ans
  return $st
}
proc sp_deck {st} { return [ase::backend::ngspice::render_deck $st [sp_netlist]] }
## The deck's own lines, trimmed, so a row can talk about ORDER.
proc sp_lines {st} { return [split [string trimright [sp_deck $st] "\n"] "\n"] }
proc sp_at {st pat} {
  set i -1
  foreach l [sp_lines $st] { incr i ; if {[string match $pat $l]} { return $i } }
  return -1
}
set SPFACTS [dict create exact 1 sources {} nodes {}]

# ===========================================================================
# SR -- THE REGISTRY ENTRY
# ===========================================================================
check {SR1 sp is a registered, renderable analysis and its line is the one speller's} \
  [list [s_ans ase::analysis_renderable ngspice sp] \
        [s_ans ase::analysis_line ngspice [sp_row]] \
        [s_ans ase::analysis_schema_errors ngspice]] \
  {1 {sp dec 3 100meg 1g} {}}

## ⚠ ALL THREE SWEEP SPELLINGS, MEASURED RATHER THAN COPIED FROM `ac`.
## 2026-09-13, both binaries, `let np = length(frequency)` after the card:
##     sp lin 2 -> 1     sp lin 3 -> 3     sp lin 1 -> 1
##     sp dec 2 -> 3     sp oct 2 -> 7
## `dec` is the field's declared default, so a row that stores nothing still
## emits a word -- issue 1414's skipped-slot defect is what makes that matter.
check {SR2 sp takes dec, oct and lin, and an unstored sweep emits its default} \
  [list [s_ans ase::analysis_line ngspice [sp_row sweep dec]] \
        [s_ans ase::analysis_line ngspice [sp_row sweep oct]] \
        [s_ans ase::analysis_line ngspice [sp_row sweep lin]] \
        [s_ans ase::field_value ngspice sp [sp_row] sweep]] \
  {{sp dec 3 100meg 1g} {sp oct 3 100meg 1g} {sp lin 3 100meg 1g} dec}

## ⚠ THE NOISE FLAG IS A TRAILING `1` AND NEVER A `0`. `spsetp.c:80-82` reads
## `value->iValue` and tests `== 1` EXACTLY, so `donoise 2` is false and an
## emitted `0` would be read as a positional argument. `ase::field_emits`'
## bool arm is what guarantees the token's PRESENCE is the truth.
check {SR3 the noise flag emits the adapter's word when on and NOTHING when off} \
  [list [s_ans ase::analysis_line ngspice [sp_row donoise 1]] \
        [s_ans ase::analysis_line ngspice [sp_row donoise 0]] \
        [s_ans ase::analysis_line ngspice [sp_row]]] \
  {{sp dec 3 100meg 1g 1} {sp dec 3 100meg 1g} {sp dec 3 100meg 1g}}

## ⚠ SR4 IS THE ONE THAT WOULD COST A USER A WRONG NUMBER. Promoting a source to
## a port adds a `z0` series resistance to the circuit and CANNOT BE UNDONE in
## the same run (measurements 2 and 3 at the top of this file), so `sp` must be
## the LAST analysis emitted -- after `op`, which issue 0964 otherwise keeps
## last. 0964's rule is about which vectors land in which plot; this is about
## whether a printed operating point is true.
set SR4 {}
foreach sr4 [s_ans ase::analysis_emit_order \
               [sp_state [list {type op enabled 1} \
                               {type ac enabled 1 points 10 start 1 stop 1meg} \
                               [sp_row]]] 1 ngspice] {
  lappend SR4 [lindex $sr4 2]
}
set SR4B {}
foreach sr4 [s_ans ase::analysis_emit_order \
               [sp_state [list {type op enabled 1} \
                               {type ac enabled 1 points 10 start 1 stop 1meg} \
                               [sp_row]]] 0 ngspice] {
  lappend SR4B [lindex $sr4 2]
}
check {SR4 sp emits AFTER op under BOTH emit-order variants, because the ports it\
 adds change every analysis that follows and cannot be taken away again} \
  [list $SR4 $SR4B] {{ac op sp} {op ac sp}}
check {SR4b ... and that is a rank above op-last's own 90, not a change to the rule} \
  [list [s_ans ase::analysis_emit_rank sp 1 ngspice] \
        [s_ans ase::analysis_emit_rank sp 0 ngspice] \
        [s_ans ase::analysis_emit_rank op 1 ngspice] \
        [s_ans ase::analysis_emit_rank op 0 ngspice]] {95 95 90 0}

## ⚠ SR5: `sp` DECLARES A `viewrank` WHERE `tf` AND `pz` DO NOT, AND THE
## DIFFERENCE IS IN THIS REPOSITORY'S OWN C. `src/save.c:889` reads
## `else if(!my_strcasecmp(type, "sp")) type = "ac";`, so `xschem raw read
## <file> sp` really does find the plot -- measured, rc 0, `sim_type=ac`, 3
## points. Withholding the key would make `plot_sim_type_reason` answer
## `no-viewer-mapping` for an sp-only bench, which is issue 1401's defect.
## BELOW `ac` because when both are enabled the reader loads the FIRST matching
## plot and refuses the second, and `ac` emits at 20 while `sp` emits at 95.
check {SR5 an sp-only bench has a viewer mapping and says so, and an ac+sp bench\
 is labelled by the plot the reader will actually load} \
  [list [s_ans ase::plot_sim_type [sp_state [list [sp_row]]]] \
        [s_ans ase::plot_sim_type_reason [sp_state [list [sp_row]]]] \
        [s_ans ase::plot_sim_type [sp_state [list {type ac enabled 1 points 10 start 1 stop 1meg} [sp_row]]]] \
        [s_ans ase::plot_sim_type [sp_state [list {type op enabled 1} [sp_row]]]]] \
  {sp {} ac sp}

## ⚠ BOTH PLOTS ARE DECLARED AND THE COMPANION ONE IS ROUTED NOWHERE. Under
## `keepopinfo` an `sp` run writes a second plot called **`AC Operating Point`**
## -- ngspice reuses the AC string. MEASURED 2026-09-13, `setplot` on both
## binaries: `sp1 (SP Analysis)` and `op1 (AC Operating Point)`. Every plot whose
## name contains `Operating Point` reads back as the OP and would replace the
## real one, so it is `results none` and the walk declines it (issue 1430).
set SR6 {}
foreach sr6 [s_dget [s_ans ase::analysis_entry ngspice sp] plots] {
  lappend SR6 [list [ase::plot_select $sr6] [ase::plot_results $sr6] \
                    [ase::plot_capturable $sr6]]
}
check {SR6 sp declares its two plots and the keepopinfo companion goes nowhere} \
  $SR6 {{{SP Analysis} viewer 1} {{AC Operating Point} none 0}}

# ===========================================================================
# SL -- THE EMITTED LINES, AND WHERE THEY SIT
# ===========================================================================
check {SL1 the promotion is two lines per port, in table order, and the source\
 name is the table's} \
  [s_ans ase::analysis_setup_emit ngspice [sp_row] lines] \
  {{alter v1 portnum = 1} {alter v1 z0 = 50} {alter v2 portnum = 2} {alter v2 z0 = 50}}

## ⚠ A BLANK Z0 EMITS NO LINE AT ALL, AND THAT IS MEASURED RATHER THAN TIDY:
## two ports with `portnum` and no `z0` run at rc 0 and answer
## `s_1_1[0] = 1.515152e-01,0.000000e+00` -- `vsrctemp.c:76-77`'s 50 ohm default
## applied silently. Writing the 50 ourselves would be ASE-L inventing a number
## the user never typed.
check {SL2 a port that leaves Z0 blank gets no z0 line, because the simulator's\
 own default is not ASE-L's to spell} \
  [s_ans ase::analysis_setup_emit ngspice \
     [concat {type sp enabled 1 points 3 start 1g stop 2g} \
             {ports {{src v1 num 1} {src v2 num 2 z0 75}}}] lines] \
  {{alter v1 portnum = 1} {alter v2 portnum = 2} {alter v2 z0 = 75}}

## ⚠ THE ORDER IN THE DECK IS THE WHOLE FEATURE. The same lines BELOW the card
## are `Error: No RF Port is present` + `exit(1)` on both binaries.
## ⚠ AND THE VERBATIM HATCH IS STILL IMMEDIATELY ABOVE THE CARD -- issue 1419's
## rows VB1/VB2, which issue 1433 paid a sabotage to learn. The hatch is the
## user's own last word and must be able to override a port.
set SL3ST [sp_state [list [sp_row x {{alter v1 z0 = 75}}]]]
## ⚠ EVERY TERM CARRIES ITS OWN "AND IT IS REALLY THERE", AND A SABOTAGE IS WHY.
## `sp_at` answers -1 for a line that is not in the deck, and `-1 < 12` is TRUE:
## the first cut of this row went GREEN with the promotion lines removed
## altogether. That is failure mode 3 -- an extractor that returns nothing -- and
## it is the one this batch has hit eleven times.
check {SL3 the ports are above the card, the hatch is immediately above the card,\
 the ports are above the hatch, and every one of the three is really in the deck} \
  [list [expr {[sp_at $SL3ST {alter v1 portnum = 1}] >= 0}] \
        [expr {[sp_at $SL3ST {alter v1 z0 = 75}] >= 0}] \
        [expr {[sp_at $SL3ST {sp dec*}] >= 0}] \
        [expr {[sp_at $SL3ST {alter v1 portnum = 1}] < [sp_at $SL3ST {sp dec*}]}] \
        [expr {[sp_at $SL3ST {sp dec*}] - [sp_at $SL3ST {alter v1 z0 = 75}]}] \
        [expr {[sp_at $SL3ST {alter v1 portnum = 1}] < [sp_at $SL3ST {alter v1 z0 = 75}]}]] \
  {1 1 1 1 1 1}

## ⚠ NON-VACUITY FOR SL3: the deck really does carry all four promotion lines and
## the card, in one expression, from a state. A reader that found nothing would
## report `-1 < -1` as false and could pass SL3 by accident in the other
## direction.
check {SL3b ... and all four promotion lines and the card are really there} \
  [list [llength [sp_lines $SL3ST]] \
        [regexp -all -line {^alter v[12] (portnum|z0) = } [sp_deck $SL3ST]] \
        [regexp -all -line {^sp dec 3 100meg 1g$} [sp_deck $SL3ST]]] \
  [list [llength [sp_lines $SL3ST]] 5 1]

## THE TOUCHSTONE EXPORT. ⚠ `let Rbase` / `unlet Rbase`, NOT the documented
## `.csparam Rbase=50`. MEASURED 2026-09-13 on both binaries: with nothing,
## `wrs2p` writes NO FILE and says `Error: No Rbase vector given`; `set Rbase`
## is the same (a shell variable is not a vector); `.csparam` and `let` both
## produce the SAME 8-line Touchstone file. Without the `unlet` the results file
## grows a `16 rbase notype dims=1` column -- `No. Variables: 21` against 20 --
## because `let` writes into the plot that is about to be written.
check {SL4 the Touchstone export is off unless asked for, and when asked for it\
 creates its reference vector and takes it away again} \
  [list [s_ans ase::analysis_setup_emit ngspice [sp_row] post [sp_state {}] 1] \
        [s_ans ase::analysis_setup_emit ngspice [sp_row s2p 1] post [sp_state {}] 1]] \
  [list {} [list {let Rbase = 50} \
                 "wrs2p [file join $scratch spbench_ase_sp1.s2p]" \
                 {unlet Rbase}]]

## ⚠ `Rbase` IS PORT 1's IMPEDANCE AND NOT THE FIRST ROW'S. The Touchstone header
## is `# Hz S RI R <Rbase>` and `span.c:74-178` refers the whole file to port 1,
## so a table that lists port 2 first must still write port 1's number.
check {SL4b the reference impedance is port 1's wherever port 1 sits in the table} \
  [lindex [s_ans ase::analysis_setup_emit ngspice \
     [concat {type sp enabled 1 points 3 start 1g stop 2g s2p 1} \
             {ports {{src v2 num 2 z0 50} {src v1 num 1 z0 75}}}] post [sp_state {}] 0] 0] \
  {let Rbase = 75}

## ⚠ WHERE THE EXPORT SITS IS THREE DECISIONS. BELOW the `$sim_status` guard so
## an analysis that failed exports nothing; ABOVE the `write` because `wrs2p`
## writes THE CURRENT PLOT and the `setplot previous` walk moves it; ABOVE
## `remzerovec` so the plot is not read while `Rbase` is still in it.
set SL5ST [sp_state [list [sp_row s2p 1]]]
check {SL5 the export sits below the guard and above the write} \
  [list [expr {[sp_at $SL5ST {wrs2p *}] > [sp_at $SL5ST {  quit 1}]}] \
        [expr {[sp_at $SL5ST {wrs2p *}] < [sp_at $SL5ST {write *}]}] \
        [expr {[sp_at $SL5ST {wrs2p *}] < [sp_at $SL5ST {remzerovec}]}]] \
  {1 1 1}

## ⚠ EVERY ANALYSIS STILL GETS THE GUARD AND `remzerovec`, `sp` INCLUDED. The
## rule is not "most analyses"; a type that skipped it would ship a results file
## for a run that failed.
check {SL6 the sp row gets a $sim_status guard, a remzerovec, a plotmap record\
 and a write, like every other analysis} \
  [list [regexp -all -line {^if \$sim_status ne 0$} [sp_deck [sp_state [list [sp_row]]]]] \
        [regexp -all -line {^remzerovec$} [sp_deck [sp_state [list [sp_row]]]]] \
        [regexp -all -line {^echo "PLOT sp 0 } [sp_deck [sp_state [list [sp_row]]]]] \
        [regexp -all -line {^write } [sp_deck [sp_state [list [sp_row]]]]]] \
  {1 1 1 1}

## ⚠ AND THE SAVE LIST IS WIDENED, WHICH IS MEASUREMENT 4. A bench with one
## ticked output and an `sp` row would otherwise run at rc 0 with no S, no Y and
## no Z in the results file and nothing said.
set SL7ST [sp_state [list [sp_row]]]
dict set SL7ST outputs {{name m expr v(mid) save 1 plot 1}}
check {SL7 an sp row forces the save-everything leader, and says which type did it} \
  [list [s_ans ase::saves_widen_types ngspice $SL7ST] \
        [s_ans ase::saves_all_forced ngspice $SL7ST] \
        [regexp -all -line {^\.save all$} [sp_deck $SL7ST]]] \
  {sp 1 1}

# ===========================================================================
# SN -- THE PRECONDITIONS
# ===========================================================================
## ⚠ THE TABLE IS WHAT SATISFIES IT, ON A NETLIST THAT DECLARES NO PORT AT ALL.
## That is the whole of Stage 9: `sp_netlist` has two ORDINARY sources.
check {SN1 two ports in the table satisfy the precondition on a netlist that\
 declares none, and fewer than two is FATAL} \
  [list [s_ans ase::analysis_needs ngspice [sp_row] $SPFACTS] \
        [lrange [lindex [s_ans ase::analysis_needs ngspice \
           [concat {type sp enabled 1 points 3 start 1g stop 2g} \
                   {ports {{src v1 num 1 z0 50}}}] $SPFACTS] 0] 0 2] \
        [lrange [lindex [s_ans ase::analysis_needs ngspice \
           {type sp enabled 1 points 3 start 1g stop 2g} $SPFACTS] 0] 0 2]] \
  [list {} \
        {two_ports fatal {this analysis needs at least 2 ports and names 1}} \
        {two_ports fatal {this analysis needs at least 2 ports and names 0}}]

## ⚠ `fatal` AND NOT `blocked`, AND THE DIFFERENCE IS A SENTENCE THAT WOULD BE A
## LIE. A `blocked` verdict is demoted to `caution` with "(read from the netlist
## text, which cannot see inside an .include)" appended whenever the facts are
## not exact -- and the ports table is ASE-L's OWN state. `portnum` cannot be
## read back from a netlist at all (`vsrcask.c:160-162` answers `rValue` for an
## `IF_INTEGER`), so no `.include` could ever supply it.
check {SN2 the fatal survives inexact netlist facts with its sentence unchanged,\
 because the finding does not come from the netlist} \
  [lrange [lindex [s_ans ase::analysis_needs ngspice \
     {type sp enabled 1 points 3 start 1g stop 2g} \
     [dict create exact 0 sources {} nodes {}]] 0] 0 2] \
  {two_ports fatal {this analysis needs at least 2 ports and names 0}}

## ⚠ AND THE GATE AND render_deck BOTH REFUSE IT -- issue 1424's third tier. A
## `.state` is a text file a person can hand-edit, so the dialog having been
## happy once is not evidence about this deck.
check {SN3 a deck with too few ports is refused before a line is built} \
  [list [catch {sp_deck [sp_state [list {type op enabled 1} \
                                        {type sp enabled 1 points 3 start 1g stop 2g}]]} sn3e] \
        [expr {[string first {nothing was rendered} $sn3e] >= 0}] \
        [catch {sp_deck [sp_state [list {type op enabled 1} [sp_row]]]} sn3f]] \
  {1 1 0}

## ngspice's OWN rules over the table, every one of them a 2026-09-13 transcript
## on both binaries -- and every one of them `fatal` because this tree's deck
## puts a `$sim_status` guard after each analysis and the guard's `quit 1` fires:
##   portnum 1,3 / 2,3 -> `Fatal error: v2: incorrect port ordering`
##   portnum 1,1       -> `Fatal error: v1: duplicate port Index`
##   z0 = 0 / -50      -> `Fatal error: v2: incorrect port ordering` -- the WRONG
##                        source and the WRONG problem, because a non-positive
##                        z0 silently demotes v1 (`vsrctemp.c:74-82`)
proc sn_verdict {ports} {
  set v [s_ans ase::analysis_needs ngspice \
           [concat {type sp enabled 1 points 3 start 1g stop 2g} [list ports $ports]] \
           $::SPFACTS]
  if {![llength $v]} { return ok }
  return [lrange [lindex $v 0] 0 1]
}
check {SN4 a duplicate index, a gap, a nameless port and a non-positive Z0 are\
 each refused, and a clean table is not} \
  [list [sn_verdict {{src v1 num 1} {src v2 num 1}}] \
        [sn_verdict {{src v1 num 1} {src v2 num 3}}] \
        [sn_verdict {{src v1 num 1} {src {} num 2}}] \
        [sn_verdict {{src v1 num 1 z0 0} {src v2 num 2}}] \
        [sn_verdict {{src v1 num 1 z0 -50} {src v2 num 2}}] \
        [sn_verdict {{src v1 num 0} {src v2 num 2}}] \
        [sn_verdict {{src v1 num 1 z0 50} {src v2 num 2 z0 50}}]] \
  [list {setup_check fatal} {setup_check fatal} {setup_check fatal} \
        {setup_check fatal} {setup_check fatal} {setup_check fatal} ok]

## ⚠ THE Z0 SENTENCE NAMES THE TRAP AND NOT THE SYMPTOM, because the symptom
## blames the wrong port.
check {SN4b the Z0 refusal says which port is wrong and why the simulator will\
 blame a different one} \
  [lindex [lindex [s_ans ase::analysis_needs ngspice \
     [concat {type sp enabled 1 points 3 start 1g stop 2g} \
             {ports {{src v1 num 1 z0 0} {src v2 num 2}}}] $SPFACTS] 0] 2] \
  {port 'v1' has Z0 '0'. A Z0 of 0 or less turns that source back into an ordinary source, and the simulator then blames a DIFFERENT port for 'incorrect port ordering'}

## ⚠ THE TWO CAUTIONS ARE "EXACTLY TWO PORTS", AND NEITHER MAY REFUSE: the run
## still produces S-parameters. `span.c:74-178` computes the noise parameters
## only for N == 2 and `rawfile.c:934-1022` prints `Note: only 2 ports 1 and 2
## are supported by wrs2p` on every call.
proc sn_three {args} {
  return [sn_verdict_row [concat {type sp enabled 1 points 3 start 1g stop 2g} \
    {ports {{src v1 num 1} {src v2 num 2} {src v3 num 3}}} $args]]
}
proc sn_verdict_row {row} {
  set v [s_ans ase::analysis_needs ngspice $row $::SPFACTS]
  if {![llength $v]} { return ok }
  return [lrange [lindex $v 0] 0 1]
}
check {SN5 three ports with the noise figure or the Touchstone box on is a\
 caution, not a refusal, and three plain ports is neither} \
  [list [sn_three donoise 1] [sn_three s2p 1] [sn_three]] \
  {{setup_check caution} {setup_check caution} ok}

## ⚠ `lin 2` IS **`lin_points`**, WHICH ALREADY EXISTED. PLAN.md Stage 9 writes
## this as a NEW rule called `lin_two` with verdict `refuse`; the tree shipped
## `lin_points` as a CAUTION at issue 1442 under ⚖ D47 ("refusing removes a
## number the user typed into a form"), and its own comment says in as many
## words that it "covers `sp` the day `sp` gets a sweep". Today is that day. A
## second rule with a different verdict over the same condition would be exactly
## the drift this batch keeps deleting.
check {SN6 sp lin 2 is the one warning ac already had, from the same predicate,\
 and lin 3 and dec 2 are silent} \
  [list [lrange [lindex [s_ans ase::analysis_needs ngspice [sp_row sweep lin points 2] $SPFACTS] 0] 0 1] \
        [s_ans ase::analysis_needs ngspice [sp_row sweep lin points 3] $SPFACTS] \
        [s_ans ase::analysis_needs ngspice [sp_row sweep dec points 2] $SPFACTS]] \
  {{lin_points caution} {} {}}

# ===========================================================================
# SK -- THE `setup` CONTRACT IS SCHEMA, AND IT IS CHECKED
# ===========================================================================
## ⚠ `ports` IS A LEGAL ROW KEY ON AN `sp` ROW AND AN UNKNOWN ONE EVERYWHERE
## ELSE. It is deliberately NOT a third entry in `ase::analysis_nonsetting_keys`
## -- `DECISIONS.md` D4 licenses `id` and `x` on EVERY row of EVERY type, and
## row NS1 of test_ase_core.tcl asserts that list literally. One registry entry
## declares that ONE type carries a table; a simulator that wants a different
## word gets one without touching core.
check {SK1 the ports table is a legal key on an sp row and a refused one on a\
 tran row, and core learns the name from the registry} \
  [list [s_ans ase::analysis_emit_check ngspice [sp_row]] \
        [lrange [lindex [s_ans ase::analysis_emit_check ngspice \
           {type tran enabled 1 step 1n stop 1u ports {{src v1 num 1}}}] 0] 0 1] \
        [s_ans ase::analysis_setup_key ngspice sp] \
        [s_ans ase::analysis_setup_key ngspice tran] \
        [s_ans ase::analysis_nonsetting_keys]] \
  {{} {unknownkey ports} ports {} {type enabled x id}}

## ⚠ AND THE READERS NEVER LOOK INSIDE AN ENTRY. `z0` is an ngspice keyword
## (D34-D37); core may count the entries and no more. A malformed table answers
## empty rather than raising, because the callers are on the Run path.
check {SK2 core counts the table and never reads a field of it, and a malformed\
 one answers empty instead of raising} \
  [list [llength [s_ans ase::analysis_setup_rows ngspice sp [sp_row]]] \
        [s_ans ase::analysis_setup_rows ngspice sp {type sp enabled 1}] \
        [s_ans ase::analysis_setup_rows ngspice sp {type sp enabled 1 ports "\{unbalanced"}] \
        [s_ans ase::analysis_setup_rows ngspice tran {type tran enabled 1 ports {{src v1}}}]] \
  {2 {} {} {}}

## ⚠ A KEY READ BY NOTHING IS A KEY CHECKED BY NOTHING (issue 1428's S35), so the
## contract is validated the way `salvage` and `resultvecs` are -- and its
## failure mode is the same silence: a `lines` proc that is not a command answers
## `{}`, the ports never reach the deck, and ngspice kills the whole run.
proc sk_types {setup} {
  return [dict create zz [dict create label zz baseline 1 registered 1 emitorder 10 \
    setup $setup \
    fields {{name ff kind bool advanced 1 when_true 1 label {Ff}}} \
    emit {{role analysis tmpl {zz}}} \
    results {viewer {kind sweep}} \
    plots {{select {ZZ Analysis} role sweep results viewer label zz}}]]
}
## ⚠ THE HOOK IS A COMMAND NAME, NOT A SCRIPT. `ase::analysis_types` calls it as
## `[$h]`, so a `apply {{} ...}` list would be looked up as one command name and
## the catch around it would swallow the failure into an EMPTY registry -- a
## fixture that validates nothing and passes every row. Hence a named proc and a
## global, and SK3's first term is a well-formed contract precisely so an empty
## registry cannot be mistaken for a clean one.
set ::SKSETUP {}
proc sk_hook {} { return [sk_types $::SKSETUP] }
proc sk_errs {setup} {
  set save $::ase::backends
  set ::SKSETUP $setup
  ase::register_backend zzsp [dict create render_deck x run_cmd x log_file x \
    result_probe x raw_file x analysis_types sk_hook]
  ase::analysis_cache_clear zzsp
  set e [s_ans ase::analysis_schema_errors zzsp]
  set ::ase::backends $save
  ase::analysis_cache_clear zzsp
  return $e
}
set SKGOOD {key pp noun port min 2 fields {ff} \
            lines ::ase::backend::ngspice::sp_alter_lines \
            post ::ase::backend::ngspice::sp_export_lines \
            check ::ase::backend::ngspice::sp_row_check}
## ⚠ NON-VACUITY FOR SK3 ITSELF: the fixture registry is really read, and the
## contract really reaches core through it. Without this, an `analysis_types`
## hook that failed would give an EMPTY registry, every `sk_errs` call would
## answer `{}`, and the first term of SK3 would be the only one that could ever
## be right.
proc sk_probe {setup script} {
  set save $::ase::backends
  set ::SKSETUP $setup
  ase::register_backend zzsp [dict create render_deck x run_cmd x log_file x \
    result_probe x raw_file x analysis_types sk_hook]
  ase::analysis_cache_clear zzsp
  set r [uplevel 1 $script]
  set ::ase::backends $save
  ase::analysis_cache_clear zzsp
  return $r
}
check {SK3a the fixture backend really is read, and the contract reaches core\
 through it} \
  [sk_probe $SKGOOD {
     list [dict keys [ase::analysis_types zzsp]] \
          [ase::analysis_setup_key zzsp zz] \
          [s_dget [ase::analysis_setup zzsp zz] min] \
          [ase::analysis_setup_rows zzsp zz {type zz enabled 1 pp {a b c}}]}] \
  {zz pp 2 {a b c}}
check {SK3 a well-formed contract is clean and each of the seven ways of getting\
 it wrong is named} \
  [list [sk_errs $SKGOOD] \
        [sk_errs [dict remove $SKGOOD key]] \
        [sk_errs [dict remove $SKGOOD lines]] \
        [sk_errs [dict replace $SKGOOD lines ::no::such::proc]] \
        [sk_errs [dict replace $SKGOOD check ::no::such::proc]] \
        [sk_errs [dict replace $SKGOOD key ff]] \
        [sk_errs [dict replace $SKGOOD key id]] \
        [sk_errs [dict replace $SKGOOD min twelve]] \
        [sk_errs [dict replace $SKGOOD fields {nosuchfield}]]] \
  [list {} {{zz nosetupkey {}}} {{zz nosetuplines {}}} \
        {{zz badsetuplines ::no::such::proc}} {{zz badsetuphook ::no::such::proc}} \
        {{zz setupkeyclash ff}} {{zz setupkeyclash id}} \
        {{zz badsetupmin twelve}} \
        {{zz badsetupfield nosuchfield} {zz fieldunused ff}}]

## ⚠ AND A FIELD THE CONTRACT CONSUMES IS CONSUMED. `donoise` and `s2p` are spent
## by the setup legs, which build lines the slot grammar cannot produce, so no
## template names them. Without the `fields` declaration the shipped registry
## would answer `fieldunused` for both -- and dropping the check for them would
## delete the guard that caught Stage 3's whole defect.
check {SK4 the shipped registry is self-consistent, and the two fields the setup\
 legs read are declared as consumed rather than exempted} \
  [list [s_ans ase::analysis_schema_errors ngspice] \
        [s_dget [s_ans ase::analysis_setup ngspice sp] fields]] \
  {{} {donoise s2p}}

## ⚠ TEN OF THE ELEVEN SHIPPED TYPES DECLARE NO CONTRACT AT ALL, so every reader
## answers empty for them and no committed deck moves. Non-vacuity for SK1-SK4.
set SKNONE {}
foreach skt [dict keys [s_ans ase::analysis_types ngspice]] {
  if {[s_ans ase::analysis_setup ngspice $skt] eq {}} { lappend SKNONE $skt }
}
check {SK5 exactly one shipped type declares a setup contract} \
  [list $SKNONE \
        [s_ans ase::analysis_setup_emit ngspice {type tran enabled 1 step 1n stop 1u} lines] \
        [s_ans ase::analysis_setup_emit ngspice {type op enabled 1} post]] \
  {{op dc ac tran noise tf pz sens disto pss} {} {}}

# ===========================================================================
# SM -- THE RECONCILIATION QUESTION THE BRIEF ASKED
# ===========================================================================
## Two canned results files, written by hand so this section starts no
## simulator. The plot NAME is what `mislabel` compares; the VECTOR names are
## what differs between the binaries, and the two files below differ in exactly
## that way and in nothing else.
proc sm_raw {path vecs} {
  set f [open $path w]
  puts $f "Title: * spbench"
  puts $f "Date: Sun Sep 13 00:00:00  2026"
  puts $f "Plotname: SP Analysis"
  puts $f "Flags: complex"
  puts $f "No. Variables: [expr {[llength $vecs] + 1}]"
  puts $f "No. Points: 1"
  puts $f "Variables:"
  puts $f "\t0\tfrequency\tfrequency"
  set i 0
  foreach v $vecs { incr i ; puts $f "\t$i\t$v\ts-param" }
  puts $f "Values:"
  set row "0\t1.000000000000000e+08,0.000000000000000e+00"
  foreach v $vecs { append row "\n\t2.500000000000000e-01,0.000000000000000e+00" }
  puts $f $row
  close $f
}
set SMFORK [file join $scratch fork.raw]
set SMAPT  [file join $scratch apt.raw]
sm_raw $SMFORK {S_1_1 S_1_2 S_2_1 S_2_2}
sm_raw $SMAPT  {s_1_1 s_1_2 s_2_1 s_2_2}
set SMMAP [file join $scratch sm.plotmap]
set smf [open $SMMAP w] ; puts $smf [ase::plotmap_record sp 0 {SP Analysis}] ; close $smf
set SMST [sp_state [list [sp_row]]]
proc sm_verdict {raw} {
  return [dict get [s_ans ase::reconcile_plots ngspice $::SMST $raw $::SMMAP] verdict]
}
check {SM1 the reconciliation is happy with both binaries' results files, because\
 the PLOT name is identical on both} \
  [list [sm_verdict $SMFORK] [sm_verdict $SMAPT]] {ok ok}

## ⚠ THE POSITIVE CONTROL. `mislabel` is not asleep: a registry that named a
## DIFFERENT plot reddens immediately, and it says which row and both names.
proc sm_with_select {sel script} {
  set save [info body ::ase::backend::ngspice::analysis_types]
  proc ::ase::backend::ngspice::analysis_types {} \
    [string map [list {select {SP Analysis} role sweep} "select {$sel} role sweep"] $save]
  ase::analysis_cache_clear
  set r [uplevel 1 $script]
  proc ::ase::backend::ngspice::analysis_types {} $save
  ase::analysis_cache_clear
  return $r
}
check {SM2 a registry that names a different plot IS caught, by row and by both\
 names -- so SM1 is not measuring an evaluator that never fires} \
  [sm_with_select {Scattering Parameters} {
     list [sm_verdict $SMFORK] \
          [dict get [ase::reconcile_plots ngspice $SMST $SMFORK $SMMAP] mislabelled]}] \
  {mislabel {{sp 0 {SP Analysis} {Scattering Parameters} registry}}}

## ⚠ AND THE ANSWER TO THE BRIEF'S QUESTION IS **NO**. A lowercased plot name is
## TOLERATED: both comparisons are case-insensitive by construction
## (`string equal -nocase` against the results file, `string match -nocase`
## against the registry). `mislabel` is about IDENTITY, not spelling, and the
## plot name does not differ between the binaries anyway.
check {SM3 a case-only difference in the plot name is deliberately NOT a\
 mislabel, on either binary's results file} \
  [sm_with_select {sp analysis} {list [sm_verdict $SMFORK] [sm_verdict $SMAPT]}] \
  {ok ok}

## ⚠ SM4: THE SIDECAR SIDE OF THE SAME COMPARISON, so the claim covers both of
## `mislabel`'s terms and not just the registry one.
set SMMAP2 [file join $scratch sm2.plotmap]
set smf [open $SMMAP2 w] ; puts $smf [ase::plotmap_record sp 0 {sp analysis}] ; close $smf
set SMMAP3 [file join $scratch sm3.plotmap]
set smf [open $SMMAP3 w] ; puts $smf [ase::plotmap_record sp 0 {Noise Spectral Density Curves}] ; close $smf
check {SM4 the same is true of the sidecar's own record: case is tolerated and a\
 different name is not} \
  [list [dict get [s_ans ase::reconcile_plots ngspice $SMST $SMFORK $SMMAP2] verdict] \
        [dict get [s_ans ase::reconcile_plots ngspice $SMST $SMFORK $SMMAP3] verdict]] \
  {ok mislabel}

## ⚠ SM5 IS THE EXPOSURE THIS STAGE LEAVES BEHIND, PINNED SO IT CANNOT BE
## FORGOTTEN. The mixed case is in the VECTOR names, and it is real: the same
## deck written by the two binaries gives `S_1_1` and `s_1_1`. Nothing in the
## deck half reads them -- `sp`'s plots row routes to the viewer and declares no
## `vectors` proc -- so this row asserts the ABSENCE. The day PLAN.md §9b's
## matrix picker adds one, this row is what makes the author choose between
## declaring a case-insensitive reader and reddening a suite.
check {SM5 the deck half declares no reader of the S-parameter vector names, so\
 nothing here can be case-sensitive about them} \
  [list [dict exists [lindex [s_dget [s_ans ase::analysis_entry ngspice sp] plots] 0] vectors] \
        [s_ans ase::analysis_resultvecs ngspice sp] \
        [lsort [dict keys [s_dget [s_ans ase::analysis_entry ngspice sp] results]]]] \
  {0 own viewer}

# ===========================================================================
# SC -- THE CORPUS, AND THE ROUND TRIP WITH A TABLE IN IT
# ===========================================================================
## ⚠ THE FOUR COMMITTED S-PARAMETER BENCHES ARE NOT TOUCHED, AND THIS ROW IS
## WHAT SAYS SO. They are inside the 104 that must round-trip byte-identically
## (test_ase_core CP7), and enabling `sp` on one of them is a USER GESTURE, not
## a migration: `sp` declares no `seed_enabled`, so `ase::state_default` still
## seeds exactly four rows.
set SCF {}
if {![catch {exec git -C $repo ls-files -- *.state} scout]} {
  foreach screl [split $scout "\n"] {
    if {[string trim $screl] ne {}} { lappend SCF [file join $repo $screl] }
  }
}
set SCBAD {} ; set SCN 0 ; set SCSP 0 ; set SCPORTS 0
foreach scf $SCF {
  if {![file exists $scf]} { continue }
  incr SCN
  set scfh [open $scf rb] ; set scorig [read $scfh] ; close $scfh
  set scst [ase::state_load $scf]
  if {"[ase::state_serialize $scst]\n" ne $scorig} { lappend SCBAD [file tail $scf] }
  foreach scr [ase::state_get $scst analyses] {
    if {[ase::state_get $scr type] eq {sp}} { incr SCSP }
    if {[dict exists $scr ports]} { incr SCPORTS }
  }
}
check {SC1 every tracked state file still round-trips byte-identically, not one\
 committed analysis row is an sp row, and not one carries a ports table} \
  [list [expr {$SCN >= 104}] $SCBAD $SCSP $SCPORTS \
        [ase::state_get [ase::state_default] analyses]] \
  [list 1 {} 0 0 \
        {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}]

## ⚠ AND A STATE THAT DOES CARRY ONE SURVIVES THE TRIP UNCHANGED, WITH THE
## DECLARED DEFAULT STILL UNWRITTEN. `sweep` defaults to `dec`, so a serializer
## that back-filled defaults on load would write `sweep dec` into the file and
## every committed bench would move the next time anything touched it. The row
## therefore targets a type WITH a declared default on purpose.
set SCPATH [file join $scratch sp_roundtrip.state]
set SCST [sp_state [list {type op enabled 1} [sp_row s2p 1 id spmain]]]
ase::state_save $SCPATH $SCST
set scfh [open $SCPATH rb] ; set SCTXT1 [read $scfh] ; close $scfh
set SCST2 [ase::state_load $SCPATH]
ase::state_save $SCPATH $SCST2
set scfh [open $SCPATH rb] ; set SCTXT2 [read $scfh] ; close $scfh
check {SC2 a bench carrying a ports table saves, loads and saves again byte for\
 byte, and no declared default is written into the file} \
  [list [expr {$SCTXT1 eq $SCTXT2}] \
        [ase::analysis_setup_rows ngspice sp [lindex [ase::state_get $SCST2 analyses] 1]] \
        [regexp {sweep} $SCTXT1] \
        [regexp {ports \{\{src v1 num 1 z0 50\} \{src v2 num 2 z0 50\}\}} $SCTXT1]] \
  [list 1 {{src v1 num 1 z0 50} {src v2 num 2 z0 50}} 0 1]

## ⚠ NON-VACUITY FOR SC2: the comparison can disagree. One byte changed in the
## table and the two serializations differ.
set SCST3 [dict replace $SCST2 analyses \
  [lreplace [ase::state_get $SCST2 analyses] 1 1 [sp_row s2p 1 id spmain ports {{src v9 num 1}}]]]
check {SC2b ... and the comparison really can disagree} \
  [expr {"[ase::state_serialize $SCST3]\n" ne $SCTXT1}] 1

# ===========================================================================
# SE -- THE END TO END RUN, ON BOTH BINARIES
# ===========================================================================
## ⚠ THIS SECTION EXISTS BECAUSE OF ISSUE 1449: two halves of a feature tested in
## different suites never meet. Everything above is Tcl reasoning about what the
## deck SAYS. This takes the deck ASE-L renders, runs it, and reads `S_1_1` back
## out of the results file -- bench with two ordinary sources, through the
## emitted `alter` lines, to a rendered deck, to a run that answers.
proc se_binaries {} {
  set out {}
  if {[info exists ::env(ASE_SP_NGSPICE)] && $::env(ASE_SP_NGSPICE) ne {}} {
    set i 0
    foreach b [split $::env(ASE_SP_NGSPICE) ":"] {
      incr i
      lappend out [list env$i $b]
    }
    return $out
  }
  set home {}
  if {[info exists ::env(HOME)]} { set home $::env(HOME) }
  return [list [list apt /usr/bin/ngspice] \
               [list fork [file join $home dev ngspice build-ver_50 src ngspice]] \
               [list fork2 /home/analog/dev/ngspice/build-ver_50/src/ngspice]]
}
set SERUN [file join $scratch serun]
file mkdir $SERUN
set SEST [sp_state [list {type op enabled 1} [sp_row s2p 1]] $SERUN]
set SEDECK [file join $SERUN spbench_ase.spice]
set sef [open $SEDECK w] ; puts -nonewline $sef [sp_deck $SEST] ; close $sef
set SESEEN {}
foreach sepair [se_binaries] {
  lassign $sepair setag sebin
  if {$sebin eq {} || ![file executable $sebin]} {
    puts "SKIPPED: SE $setag end-to-end leg (no executable at '$sebin')"
    continue
  }
  if {[lsearch -exact $SESEEN [file normalize $sebin]] >= 0} { continue }
  lappend SESEEN [file normalize $sebin]
  foreach sef2 [list spbench_ase.raw spbench_ase.plotmap spbench_ase_sp1.s2p] {
    file delete -force [file join $SERUN $sef2]
  }
  set serc [catch {exec $sebin -b $SEDECK 2>@1} seout]
  set semap {}
  if {[file isfile [file join $SERUN spbench_ase.plotmap]]} {
    set sefh [open [file join $SERUN spbench_ase.plotmap] r]
    set semap [string trim [read $sefh]] ; close $sefh
  }
  set ses2p {}
  if {[file isfile [file join $SERUN spbench_ase_sp1.s2p]]} {
    set sefh [open [file join $SERUN spbench_ase_sp1.s2p] r]
    set ses2p [split [string trim [read $sefh]] "\n"] ; close $sefh
  }
  set sevecs {}
  foreach sep [s_ans ase::cap_raw_plots [file join $SERUN spbench_ase.raw]] {
    if {[string equal -nocase [lindex $sep 0] {SP Analysis}]} { set sevecs [lindex $sep 2] }
  }
  set seS {}
  foreach sev $sevecs {
    if {[string equal -nocase $sev {S_1_1}]} { set seS $sev }
  }
  ## ⚠ THE VECTOR IS MATCHED CASE-INSENSITIVELY AND THE SPELLING IS REPORTED,
  ## because the two binaries disagree about it: the fork writes `S_1_1` and apt
  ## 45.2 writes `s_1_1`. A case-sensitive row here would be green on the
  ## development reference and red on the binary a downloading user has.
  check "SE1/$setag the deck ASE-L renders runs, records both plots in the\
 sidecar and puts an S-parameter matrix in the results file" \
    [list $serc \
          $semap \
          [expr {$seS ne {}}] \
          [llength $sevecs] \
          [lindex $ses2p 3]] \
    [list 0 "PLOT op 0 |Operating Point|\nPLOT sp 1 |SP Analysis|" 1 20 {# Hz S RI R 50}]
  if {$serc} { puts "  SE1/$setag output: $seout" }
  ## ⚠ AND THE OPERATING POINT IS MEASURED ON THE UNPROMOTED CIRCUIT. `v1` is a
  ## 1 V source into a 50/50/50 attenuator: `v(in)` is 1.0 before the promotion
  ## and 6.25e-01 after it. This is SR4's reason, end to end -- if `sp` ever
  ## emitted before `op`, the number in the OP plot would silently change.
  set seop {}
  foreach sep [s_ans ase::cap_raw_plots [file join $SERUN spbench_ase.raw]] {
    if {[string equal -nocase [lindex $sep 0] {Operating Point}]} { set seop [lindex $sep 2] }
  }
  check "SE2/$setag the operating point plot holds the un-promoted circuit --\
 no port node in it, which is what emitting sp last buys" \
    [list [lsort $seop] [llength $seop]] \
    [list {i(v1) i(v2) v(in) v(mid) v(out)} 5]
}

puts "RESULT: [expr {$fail ? "$fail FAILED ($npass passed)" : "ALL PASS ($npass checks)"}]"
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
exit [expr {$fail ? 1 : 0}]
