# tests/headless/test_ase_campaign_gui_1464.tcl -- ISSUE 1464: THE CAMPAIGN HAD
# A RUNNER AND NO DOOR, AND THE CAMPAIGN'S OWN NUMBER DID NOT EXIST.
# PLAN.md Stage 11, task 2: the campaign DIALOG (§11a/§11b) and the RESULT
# TABLE (§11c).
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# Issue 1462 shipped 44 core procs, five adapter hooks, a Monte Carlo sampler
# and an `index.tsv` writer -- and built no widget. On that tree the only way to
# put a `sweep` key on a bench was to CLOSE ASE-L AND HAND-EDIT THE `.state`
# FILE, and the only way to read a campaign's answer was to open a directory of
# rawfiles. §11c's whole claim -- "the campaign ends with a NUMBER, not a
# directory" -- had no implementation at all: histogram, mean, sigma, min/max,
# yield against a spec limit and a scatter of any two columns did not exist,
# because ngspice has no sort, no median, no percentile and no histogram to
# borrow them from.
#
# ============================================================================
# ⚠ THE MEASUREMENT THAT RESHAPED THIS TASK: `1k` IS NOT A NUMBER
# ============================================================================
# A campaign's axis column holds the values the USER typed -- `1k 2k 4.7meg` --
# and `string is double` rejects every one of them. MEASURED here, on the first
# scatter that was asked for:
#
#   ase::stat_pairs $rows myres pm       ->  {}            (no suffixes)
#   ase::stat_pairs $rows myres pm $sufs ->  {1000.0 55.0} {2000.0 60.0}
#
# So a histogram of a swept axis had NO BARS and a scatter of axis against
# measurement had NO POINTS -- silently, on the commonest campaign there is, and
# a picture with nothing in it is indistinguishable from a campaign that has not
# run. WHICH suffixes exist is the simulator's fact (D34), so they are an
# argument: `ase::stat_suffixes <sim>` resolves the adapter's `si_suffixes`
# hook, and `{}` means plain numbers only -- which is this suite's non-vacuity
# control, rows ST20/ST20b.
#
# ============================================================================
# ⚠ AND A `-` IS NOT A ZERO
# ============================================================================
# `ase::campaign_index_row` writes `-` for a point that never ran and for a
# measurement that produced nothing -- and measured on both binaries (issue
# 1451), a measurement that finds nothing exits 0, leaves `$sim_status` 0 and
# prints NOTHING. A mean that read `-` as 0 would pull a yield number toward the
# failing side and say nothing about it. Every reader drops non-numeric cells
# and every summary reports `n` beside `rows`, so the panel says "n = 28 of 30".
#
# ============================================================================
# THE TWO DIRECTIONS EVERY READER HERE IS ASKED IN
# ============================================================================
# Issue 1457 shipped a defect past a row that asked only "is everything promised
# present?" -- it would have passed with a MISSING promise. The two shapes that
# matters in here are named in the brief:
#
#   * a result table that renders the columns it knows about will not notice a
#     measurement column it DROPPED. **GT2** asserts the treeview's column list
#     is EQUAL to `ase::campaign_index_header`, both directions, and GT2b adds a
#     second measurement and demands the table grow by exactly that column.
#   * a histogram that bins the samples it was given will not notice a sample
#     that NEVER ARRIVED. **ST14** asserts the bin counts SUM to the count of
#     numbers, and **GT6** asserts that count plus the `-` cells equals one row
#     per point of the odometer -- so a campaign that silently skipped a shard
#     cannot produce a plausible picture.
#
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
#    sections ST EX RD DC RR -- pure Tcl and a /bin/sh stand-in, identical on
#                   both arms, and EVERY ONE of them guarded: a raise becomes a
#                   named red (ST0/EX0/RD0/DC0/RR0), never a missing RESULT line
#    sections GM GC GA GR GT GX -- widgets; DISPLAY only, self-skipping
#    section  EE -- starts BOTH real binaries, self-skips with the path printed
#                   when one is absent
#
# NEW AT 78 headless / 156 on the dev display. The sabotage campaign is in
# doc/claude/ase_analyses_batch/receipts/39-stage-11-gui.md.
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_campaign_gui_1464.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_campaign_gui_1464.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch campgui1464]
catch {test_sim_registry_isolate}

## ⚠ EVERY READER IS TOTAL AND ANSWERS A COMPARABLE VALUE. A row whose extractor
## raises cannot disagree with anything, and `--nogui --pipe` exits 0 on an
## uncaught mid-script Tcl error -- so a killed suite looks like a pass.
proc q_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc q_w {w args} {
  if {![winfo exists $w]} { return NOWIDGET }
  set rc [catch {uplevel #0 [linsert $args 0 $w]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc q_cfg {w opt} {
  if {![winfo exists $w]} { return NOWIDGET }
  set rc [catch {$w cget $opt} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
## A total file reader. ⚠ `::open` / `::close`, because `src/ase_window.tcl`
## shadows both and this suite runs after it is sourced (issue 1461).
proc q_slurp {p} {
  if {![file isfile $p]} { return "NOFILE:[file tail $p]" }
  set f {}
  if {[catch {::open $p r} f]} { return "NOOPEN:[file tail $p]" }
  set t [read $f]
  catch {::close $f}
  return $t
}
proc q_round {v {d 6}} {
  set n [ase::stat_numbers [list $v]]
  if {[llength $n] != 1} { return - }
  return [format %.${d}g [lindex $n 0]]
}

# ============================================================================
# SECTION ST -- §11c's ARITHMETIC, WHICH THE SIMULATOR CANNOT DO
# ============================================================================

if {[catch {

check {ST1 the mean of a column skips the cells that are not numbers, because a\
 `-` is a point that never ran and not a zero} \
  [q_ans ase::stat_mean {1 2 - 3 {}}] 2.0

## ⚠ THE CONTROL, AND THE FIRST VERSION OF IT WAS CALIBRATED AGAINST ONE WRONG
## IMPLEMENTATION AND MISSED ANOTHER. It compared the answer against 1.2 -- what
## you get if BOTH the `-` and the empty cell are read as zeros -- and sabotage
## s2, which reads only `-` as a zero and answers 1.5, walked straight past it
## while ST1 caught it. So the row now asks the question the other way round:
## the mean over a column carrying `-` must EQUAL the mean over the same column
## with those cells physically removed, and must equal NEITHER read-as-zero
## answer. A control calibrated against one wrong implementation is a control
## that only catches that one.
check {ST1b and the control -- the mean with the `-` cells present equals the\
 mean with them REMOVED, and equals neither read-as-zero answer} \
  [list [expr {[q_ans ase::stat_mean {1 2 - 3 {}}] == [q_ans ase::stat_mean {1 2 3}]}] \
        [expr {[q_ans ase::stat_mean {1 2 - 3 {}}] == [q_ans ase::stat_mean {1 2 0 3 0}]}] \
        [expr {[q_ans ase::stat_mean {1 2 - 3 {}}] == [q_ans ase::stat_mean {1 2 0 3}]}]] \
  {1 0 0}

## ⚠ THE **SAMPLE** SIGMA, n-1. Understating sigma OVERSTATES yield, which is
## the one direction an error in this number must not go.
check {ST2 sigma divides by n-1, not by n -- a Monte Carlo column is a sample\
 and the population form overstates yield} \
  [q_round [q_ans ase::stat_sigma {2 4 4 4 5 5 7 9}]] 2.13809
check {ST2b and the population form, which is what a first implementation\
 writes, would answer 2 -- so the row can tell them apart} \
  [expr {abs([q_ans ase::stat_sigma {2 4 4 4 5 5 7 9}] - 2.0) < 1e-9 \
           ? {population} : {sample}}] {sample}
check {ST3 one number has no spread, and `{}` says so where a `0` would read as\
 perfectly repeatable} [q_ans ase::stat_sigma {5}] {}

check {ST4 the median of an even count averages the middle pair, which is what\
 every spreadsheet does and what ngspice has no command for} \
  [q_ans ase::stat_median {4 1 3 2}] 2.5
## ⚠ THE ANSWER IS A DOUBLE, NOT THE CELL'S OWN STRING. Every reader converts
## first, so `3` comes back as `3.0` -- pinned because a panel that printed the
## raw cell would be showing the file rather than the arithmetic.
check {ST5 and of an odd count it is the middle one} \
  [q_ans ase::stat_median {4 1 3}] 3.0

check {ST6 the summary reports how many NUMBERS it had beside how many CELLS,\
 so a panel can say `n = 3 of 5` instead of implying 5} \
  [list [dict get [q_ans ase::stat_summary {1 2 - 3 -}] n] \
        [dict get [q_ans ase::stat_summary {1 2 - 3 -}] rows]] {3 5}
check {ST6b an all-`-` column answers every statistic as `{}` and n 0, and never\
 as a zero} \
  [q_ans ase::stat_summary {- -}] {n 0 rows 2 min {} max {} mean {} sigma {} median {}}

## ⚠ MEASURED IN tclsh: `string is double` answers 1 for `nan` and `inf`,
## `double("nan")` RAISES and `double("1e400")` quietly answers `Inf`. Any one
## reaching a mean makes every number in the panel `NaN` with nothing saying
## which point did it.
check {ST7 nan, inf and an overflowing literal are dropped, because one of them\
 in a column turns every number in the panel into NaN} \
  [q_ans ase::stat_numbers {nan inf 1e400 -inf 2.5 abc {}}] 2.5

check {ST8 a histogram of nine values into three bins puts three in each, and\
 the last bin is CLOSED so the maximum is inside the picture} \
  [q_ans ase::stat_histogram {1 2 3 4 5 6 7 8 9} 3] \
  {{1.0 3.6666666666666665 3} {3.6666666666666665 6.333333333333333 3} {6.333333333333333 9.0 3}}
## ⚠ A CONSTANT COLUMN IS ONE BIN, NOT A DIVISION BY ZERO -- and it is the
## answer a corner sweep most wants to show.
check {ST9 a column with no spread is one bin holding everything, which is the\
 truthful picture of a corner sweep that moved nothing} \
  [q_ans ase::stat_histogram {5 5 5}] {{5.0 5.0 3}}
check {ST10 a column with no numbers has no bins at all, so the canvas can say\
 so rather than draw an empty axis} [q_ans ase::stat_histogram {- -}] {}
check {ST11 the default bin count is bounded at both ends -- three points in\
 eleven bins is a picture of nothing and forty bins over thirty samples is a\
 comb} [list [q_ans ase::stat_bins 9] [q_ans ase::stat_bins 1] \
             [q_ans ase::stat_bins 10000] [q_ans ase::stat_bins 0]] {4 1 24 1}

check {ST12 yield counts INCLUSIVELY against a two-sided spec, because a design\
 centred on its own limit must not fail its nominal corner} \
  [q_ans ase::stat_yield {1 2 3 4 5} {min 2 max 4}] \
  {n 5 pass 3 fail 2 pct 60.0 specified 1}
check {ST12b a ONE-sided spec is a real spec -- `phase margin at least 45` has\
 no upper bound and inventing one would fail points that pass} \
  [dict get [q_ans ase::stat_yield {1 2 3} {min 2}] pass] 2
check {ST13 no spec is not a 100 % yield: `specified 0` and a `{}` percentage,\
 because a number nobody asked for is worse than no number} \
  [q_ans ase::stat_yield {1 2 3} {}] {n 3 pass 0 fail 0 pct {} specified 0}

## ⚠ THE OTHER DIRECTION (issue 1457's blind spot). A histogram that bins what
## it was given cannot notice a sample that never arrived -- so the bins must
## SUM to the count of numbers, and nothing may be dropped between them.
set ST_V {3 1 4 1 5 9 2 6 - 5 3 5}
set ST_SUM 0
foreach b [q_ans ase::stat_histogram $ST_V] { incr ST_SUM [lindex $b 2] }
check {ST14 every number lands in exactly one bin -- the bin counts SUM to n, so\
 a sample silently dropped between the column and the picture reds here} \
  [list $ST_SUM [llength [q_ans ase::stat_numbers $ST_V]] [llength $ST_V]] \
  {11 11 12}

set ST_ROWS {{shard myres exit raw pm} {shard-0001 1k 0 a.raw 55}
             {shard-0002 2k 0 b.raw 60} {shard-0003 4k - - -}}
check {ST15 a column is found BY NAME, never by position -- an axis added to a\
 campaign moves every measurement column to the right} \
  [q_ans ase::stat_column $ST_ROWS pm] {55 60 -}
check {ST15b a name the header does not carry answers `{}` rather than the\
 wrong column} [q_ans ase::stat_column $ST_ROWS nosuch] {}
check {ST16 the header is the first row} \
  [q_ans ase::stat_columns $ST_ROWS] {shard myres exit raw pm}
check {ST16b an empty table has no header and no column} \
  [list [q_ans ase::stat_columns {}] [q_ans ase::stat_column {} pm]] {{} {}}

## A short row -- a hand-truncated `index.tsv` -- must answer `-` for the
## missing cell rather than shortening the column and mis-pairing the scatter.
check {ST17 a row shorter than the header answers `-` for what it does not\
 carry, so the column stays one cell per point} \
  [q_ans ase::stat_column {{shard a b} {shard-0001 1}} b] {-}

check {ST18 a scatter drops a pair WHOLE when either coordinate is missing --\
 keeping the other would pair point 7's x with point 8's y and draw a\
 correlation that does not exist} \
  [llength [q_ans ase::stat_pairs $ST_ROWS myres pm [q_ans ase::stat_suffixes ngspice]]] 2

check {ST19 six significant digits, the same decision and the same reason as the\
 sampler's: log and sqrt put their last bits in libm's hands} \
  [list [q_ans ase::stat_fmt 1.23456789] [q_ans ase::stat_fmt -] \
        [q_ans ase::stat_fmt abc]] {1.23457 - -}

# --- the SI suffix argument, and its control -------------------------------
set ST_SUF [q_ans ase::stat_suffixes ngspice]
check_true {ST20 the simulator's own suffix set reaches the statistics, so `1k`\
 in a swept axis column is a number} \
  [expr {[q_ans ase::stat_mean {1k 2k 3k} $ST_SUF] == 2000.0}]
## ⚠ THE NON-VACUITY CONTROL, AND IT IS THE DEFECT ITSELF. Without the suffixes
## the same column is EMPTY -- which is what a histogram of a swept axis drew
## before this argument existed.
check {ST20b and WITHOUT them the same column is empty, which is exactly what\
 the scatter and the histogram silently drew before} \
  [q_ans ase::stat_numbers {1k 2k 3k}] {}
## ⚠ `meg` BEFORE `m`, OR A MEGAHERTZ BECOMES A MILLIHERTZ. `ase::si_parse`
## already carries the longest-match rule; this row is why a second reader was
## not written here.
check {ST21 `meg` is not read as `m` -- nine orders of magnitude, and the one\
 suffix reader in the tree is what stops it} \
  [q_ans ase::stat_numbers {1meg 1m} $ST_SUF] {1000000.0 0.001}
check {ST22 a spec limit may itself carry a suffix, because a user who typed\
 `1k` on the axis will type `1.5k` in the spec} \
  [dict get [q_ans ase::stat_yield {1k 2k 3k} {min 1.5k} $ST_SUF] pass] 2
check {ST23 an unknown suffix is not a number, so a typo is dropped rather than\
 read as its numeric prefix} [q_ans ase::stat_numbers {5zz} $ST_SUF] {}


} sterr]} { check {ST0 section ST ran to the end} "RAISED:$sterr" {} }
# ============================================================================
# SECTION EX -- THE SAMPLES LEAVE THE PROGRAM (§11b)
# ============================================================================

if {[catch {
check {EX1 TSV is the table verbatim, header row included} \
  [string map [list \t <T> \n <N>] [q_ans ase::campaign_export_text $ST_ROWS tsv]] \
  {shard<T>myres<T>exit<T>raw<T>pm<N>shard-0001<T>1k<T>0<T>a.raw<T>55<N>shard-0002<T>2k<T>0<T>b.raw<T>60<N>shard-0003<T>4k<T>-<T>-<T>-<N>}
## ⚠ ONE UNQUOTED COMMA SHIFTS EVERY COLUMN TO ITS RIGHT and nothing downstream
## can tell -- the same defect `ase::campaign_index_cell` maps tabs out of the
## TSV for. A corner section name may carry one.
check {EX2 CSV quotes a cell that carries a comma or a quote, and doubles the\
 quote, because one unquoted comma shifts every column to its right} \
  [q_ans ase::campaign_export_text {{a b} {x,y {he said "hi"}}} csv] \
  "a,b\n\"x,y\",\"he said \"\"hi\"\"\"\n"
check {EX3 a tab inside a cell never reaches the TSV} \
  [string map [list \t <T>] [q_ans ase::campaign_export_text [list [list "a\tb" c]] tsv]] \
  {a b<T>c
}
check {EX4 an unknown format is refused rather than silently written as TSV} \
  [string match {RAISED:*} [q_ans ase::campaign_export_text $ST_ROWS xlsx]] 1
check {EX5 the formats are declared, so the file dialog and the writer cannot\
 disagree about what exists} [q_ans ase::campaign_export_formats] {tsv csv}
check {EX6 the extension picks the format and an unknown one falls back to TSV,\
 which is what `index.tsv` already is} \
  [list [q_ans ase::ui::campres_export_fmt /x/y.CSV] \
        [q_ans ase::ui::campres_export_fmt /x/y.tsv] \
        [q_ans ase::ui::campres_export_fmt /x/y]] {csv tsv tsv}


} exerr]} { check {EX0 section EX ran to the end} "RAISED:$exerr" {} }
# ============================================================================
# SECTION RD -- THE WINDOW'S TOTAL READERS, WITH NO WIDGET IN SIGHT
# ============================================================================

if {[catch {
## ⚠ THE DISTRIBUTIONS COME FROM CORE, NOT FROM A LIST TYPED IN THE FORM. A
## fourth distribution added to `ase::mc_dists` grows a picker entry and a set of
## parameter fields with nothing edited in `ase_window.tcl`.
check {RD1 the distribution picker offers exactly what core declares} \
  [q_ans ase::ui::camp_dist_kinds] [lsort [dict keys [q_ans ase::mc_dists]]]
check {RD2 and each one's parameter fields are core's required keys, so a form\
 cannot ask for a parameter the sampler does not read} \
  [list [q_ans ase::ui::camp_dist_keys normal] \
        [q_ans ase::ui::camp_dist_keys uniform] \
        [q_ans ase::ui::camp_dist_keys bounded] \
        [q_ans ase::ui::camp_dist_keys nosuch]] \
  {{mean sigma} {min max} {nom delta} {}}

## ⚠ THE VALUES COLUMN SHOWS THE DISTRIBUTION, NEVER THE DRAWN SAMPLES. Two
## hundred of them would fill the column and hide every other axis, and the
## samples have a table of their own.
check {RD3 a literal axis shows its list} \
  [q_ans ase::ui::camp_axis_values_text {kind var name r values {1k 2k 4k}}] \
  {1k 2k 4k}
check {RD4 a drawn axis shows the distribution the user asked for and not the\
 two hundred samples it expands to} \
  [q_ans ase::ui::camp_axis_values_text \
    {kind var name r draw {dist normal mean 1 sigma 0.1 n 200}}] \
  {normal(mean=1, sigma=0.1) x200}
check {RD5 an axis with neither shows nothing rather than a stale or invented\
 list} [q_ans ase::ui::camp_axis_values_text {kind temp}] {}

check {RD6 every progress sentence is composed, so `k/N` cannot disagree with\
 the odometer} \
  [list [q_ans ase::ui::lbl_camp_at 3 12 {myres=2k}] \
        [q_ans ase::ui::lbl_camp_at 1 1 {}] \
        [q_ans ase::ui::lbl_camp_done 12 11 1] \
        [q_ans ase::ui::lbl_camp_stopped 4 12]] \
  [list "point 3 of 12 — running   (myres=2k)" "point 1 of 1 — running" \
        "12 of 12 done — 11 ran, 1 failed" \
        "stopped after 4 of 12 — every completed point is kept"]

check {RD7 the statistics line says n AND rows every time, so the gap between\
 them is visible without the user having to know to look for it} \
  [q_ans ase::ui::lbl_campres_stats [q_ans ase::stat_summary {1 2 3 -}]] \
  {n = 3 of 4      mean 2 sigma 1 min 1 max 3 median 2}
check {RD8 a yield with no spec says what to do instead of printing a\
 percentage nobody asked for} \
  [list [q_ans ase::ui::lbl_campres_yield [q_ans ase::stat_yield {1 2 3} {}]] \
        [q_ans ase::ui::lbl_campres_yield [q_ans ase::stat_yield {1 2 3} {max 2}]]] \
  {{Yield: give a spec limit} {Yield: 2 of 3 (66.7 %)}}

## The window readers are total: asked about a session that does not exist they
## answer `{}` and never raise.
## ⚠ A STRUCTURAL ROW, AND IT IS THE ONE A BEHAVIOURAL ROW CANNOT SEE. The
## design routing used to live INLINE in `ase::ui::do_run`, and `Run Campaign`
## -- which netlists exactly as that door does -- could only copy it or go
## without it. Going without it was MEASURED on the dev display: the campaign
## died on `ase: design <lib>/<cell> is not open in this window`, from a window
## where `Netlist and Run` works. Two procs each deciding what "reachable" means
## is what invariant I1 forbids, so there is ONE and both doors call it.
proc rd_body {p} {
  if {![llength [info commands $p]]} { return NOPROC }
  return [info body $p]
}
check {RD10 both run doors route the design through the ONE proc that decides\
 what reachable means, and neither re-inlines it} \
  [list [string match {*ase::ui::route_design $key*} [rd_body ase::ui::do_run]] \
        [string match {*ase::ui::route_design $key*} [rd_body ase::ui::camp_run]] \
        [string match {*ase::stack_level*} [rd_body ase::ui::route_design]] \
        [string match {*ase::stack_level*} [rd_body ase::ui::do_run]] \
        [string match {*ase::stack_level*} [rd_body ase::ui::camp_run]]] \
  {1 1 1 0 0}

check {RD9 every window reader is total for a key with no window} \
  [list [q_ans ase::ui::camp_win nosuchkey] \
        [q_ans ase::ui::campres_win nosuchkey] \
        [q_ans ase::ui::camp_axis_win nosuchkey] \
        [q_ans ase::ui::camp_axes nosuchkey] \
        [q_ans ase::ui::camp_selected nosuchkey] \
        [q_ans ase::ui::campres_selected nosuchkey]] {{} {} {} {} {} {}}


} rderr]} { check {RD0 section RD ran to the end} "RAISED:$rderr" {} }
# ============================================================================
# SECTION DC -- THE THIRD `.dc` SWEEP LEVEL CANNOT BE ASKED FOR
# ============================================================================

if {[catch {
# ⚠ PLAN.md §11 opens with it: a THIRD `.dc` sweep level is **accepted and
# discarded** -- three nested sweeps produce the same 9 rows as two,
# byte-identical values, rc 0 and nothing on stderr, on BOTH binaries
# (`evidence/sweep-nesting.md`). A user who asks for 27 operating points gets 9
# and is told nothing, so ASE-L must REFUSE a third level **at the form**.
#
# ⚠ AND THE REFUSAL IS STRUCTURAL, WHICH IS BETTER THAN A REFUSAL. Issue 1462's
# receipt (C7) handed this to task 2 because the only place a third level can be
# ASKED for is the `dc` analysis form. Measured: the registry declares exactly
# TWO sweep levels and the emit template spends exactly those, so the form
# cannot express a third and there is nothing to refuse. These rows pin that, so
# the day somebody adds a `source3` field they meet this instead of shipping the
# silent drop.

set DC_E [q_ans ase::analysis_entry ngspice dc]
set DC_F {}
foreach fd [q_ans ase::state_get $DC_E fields] { lappend DC_F [q_ans ase::state_get $fd name] }
check {DC1 the `dc` analysis declares exactly TWO sweep levels, so a form built\
 from the registry cannot ask for the third one ngspice accepts and discards} \
  $DC_F {source start stop step source2 start2 stop2 step2}
## ⚠ THE OTHER DIRECTION: the EMIT template must spend exactly those slots. A
## registry with two levels and a template that concatenated a third would put
## one on the card without any field ever showing it.
check {DC2 and the emit template spends exactly those eight slots and no more --\
 a template carrying a third level would reach the deck with no field to show it} \
  [q_ans ase::analysis_slots [q_ans ase::state_get \
    [lindex [q_ans ase::state_get $DC_E emit] 0] tmpl]] \
  {source start stop step source2 start2 stop2 step2}
## And the form really builds from that list rather than from one typed in the
## dialog -- the eighth copy of "what a dc analysis is" is the defect Stage 1
## exists to have removed.
## ⚠ `ase::ui::chana_fields` ANSWERS THE NAMES, NOT THE DESCRIPTORS -- it is a
## one-line wrapper over `ase::analysis_field_names`. The first version of this
## row walked the answer as though it were a list of dicts and compared eight
## empty strings against eight names; it FAILED, which is the row working, but
## it was measuring my assumption about the reader rather than the reader.
check {DC3 the Choose Analyses form offers those same eight field names, from\
 the registry and not from a list typed in the dialog} \
  [q_ans ase::ui::chana_fields dc ngspice] $DC_F


} dcerr]} { check {DC0 section DC ran to the end} "RAISED:$dcerr" {} }
# ============================================================================
# SECTION RR -- RE-RUNNING ONE POINT, AGAINST A STAND-IN SIMULATOR
# ============================================================================

if {[catch {
# A few-line /bin/sh script that reads the deck it was handed, takes the results
# path off the deck's own `write` line and writes a canned raw there. Nothing
# here needs a real ngspice, so every row is deterministic on both arms.
#
# ⚠ AND THE STAND-IN IS PROVEN TO BE REACHED BEFORE ANYTHING RESTS ON IT. Issue
# 1462 measured two of its own stand-in BACKENDS going vacuous -- a
# `[list apply {...}]` hook is not callable and every hook reader's `catch`
# swallowed it -- so RR0 below asserts the script really ran by looking for the
# marker it prints, and RR0b is its negative control.

set RRBIN [file join $scratch bin]
file mkdir $RRBIN
set RRRAW "Title: campaign stand-in\nDate: Sat Sep 13 00:00:00  2026\nPlotname: Operating Point\nFlags: real\nNo. Variables: 1\nNo. Points: 1\nVariables:\n\t0\tv(a)\tvoltage\nValues:\n 0\t1.000000e+00\n"
proc rr_wr {path text {perm 0644}} {
  set f [::open $path w] ; puts -nonewline $f $text ; ::close $f
  file attributes $path -permissions $perm
  return $path
}
## The stand-in counts its own invocations into a file, so "was it reached" is a
## measurement rather than an assumption.
set RRSTUB {#!/bin/sh
deck=
for a in "$@"; do
  if [ -f "$a" ]; then deck="$a"; fi
done
[ -z "$deck" ] && exit 0
echo "$deck" >> @TALLY@
out=`grep -E '^[ 	]*write[ 	]' "$deck" | head -1 | sed -e 's/^[ 	]*write[ 	][ 	]*//' -e 's/[ 	]*$//'`
if [ -n "$out" ]; then cat @RAW@ > "$out"; fi
echo CAMPGUI-STUB-RAN
exit 0
}
set RRRAWF [rr_wr [file join $scratch stub.raw] $RRRAW]
set RRTALLY [file join $scratch tally.txt]
rr_wr [file join $RRBIN campsim] \
  [string map [list @RAW@ $RRRAWF @TALLY@ $RRTALLY] $RRSTUB] 0755
catch {ase::sim_register campgui [file join $RRBIN campsim]}
catch {ase::sim_select campgui}

proc rr_state {sweep {extra {}}} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create cell rc lib $scratch]
  dict set st rundir [file join $scratch rr]
  dict set st simulator ngspice
  dict set st sim_entry {name campgui}
  dict set st save_all_v 1
  dict set st analyses {{type op enabled 1}}
  dict set st sweep $sweep
  foreach {k v} $extra { dict set st $k $v }
  return $st
}
proc rr_netlist {} { return "* rc\nv1 a 0 1\nr1 a 0 1k\n.end\n" }
proc rr_fresh {} {
  global scratch RRTALLY
  file delete -force [file join $scratch rr]
  file mkdir [file join $scratch rr]
  catch {file delete $RRTALLY}
}
## ⚠ ONLY THE CAMPAIGN DECKS ARE COUNTED, AND FINDING OUT WHY IS ITS OWN
## MEASUREMENT: a three-point campaign invoked this stand-in TEN times, because
## `ase::run_deck` asks `ase::cap_report` on every run and the probe runs the
## binary too. That is issue 1463's cost seen from the other side -- harmless
## here at 0.014 s, thirty seconds per shard against a binary that never answers.
proc rr_tally {} {
  global RRTALLY
  if {![file isfile $RRTALLY]} { return 0 }
  set n 0
  foreach l [split [string trim [q_slurp $RRTALLY]] "\n"] {
    if {[string match {*/campaign/*} $l]} { incr n }
  }
  return $n
}
## Shorten the per-shard budget: every stand-in finishes in milliseconds, so a
## broken wake-up becomes a fast NAMED failure instead of a suite that sits at
## the real budget until an external `timeout` cuts it off. The shipped value is
## asserted either side of the section -- a NORESULT is not a result.
check {RR0 the shipped per-shard budget is thirty minutes, pinned before this\
 section shortens it} [q_ans ase::campaign_shard_timeout] 1800
rename ::ase::campaign_shard_timeout ::rr_production_tmo
proc ::ase::campaign_shard_timeout {} { return 10 }

rr_fresh
set RRST [rr_state [dict create enabled 1 seed 5 axes \
  {{kind var name myres values {1k 2k 3k}}}]]
set RRRES [q_ans ase::campaign_run ngspice $RRST [rr_netlist]]
check {RR1 the campaign ran every point} \
  [list [dict get $RRRES status] [dict get $RRRES ran] [dict get $RRRES of]] {done 3 3}
check {RR1b and the stand-in really ran, once per point -- a hook that was never\
 called would leave every row below reading a file nobody wrote} [rr_tally] 3

set RRIDX [q_ans ase::campaign_index_read $RRST]
check {RR2 the index carries the header and one row per point, run or not} \
  [list [llength $RRIDX] [lindex $RRIDX 0]] \
  [list 4 [list shard myres exit raw]]
check {RR3 the exit codes are readable back by shard id} \
  [q_ans ase::campaign_index_exits ngspice $RRST] \
  {shard-0001 0 shard-0002 0 shard-0003 0}

## ⚠ THE HEADER IS THE TEST OF WHETHER THE OLD EXITS STILL MEAN ANYTHING. A user
## who re-runs point 2 after adding an axis would otherwise get an index whose
## surviving rows are the OLD campaign's coordinates wearing the NEW campaign's
## column headings, and nothing would say so.
set RRST2 [rr_state [dict create enabled 1 seed 5 axes \
  {{kind var name myres values {1k 2k 3k}} {kind temp values {27 85}}}]]
check {RR4 an index written for a DIFFERENT campaign is not carried across --\
 the header names every axis and every measurement, so any edit that changes\
 what a shard id MEANS discards the old exit codes} \
  [q_ans ase::campaign_index_exits ngspice $RRST2] {}

set RRT0 [rr_tally]
set RRRR [q_ans ase::campaign_rerun ngspice $RRST [rr_netlist] 1]
check {RR5 re-running one point runs exactly one shard} \
  [list [dict get $RRRR status] [dict get $RRRR idx] [dict get $RRRR exit] \
        [expr {[rr_tally] - $RRT0}]] {done 1 0 1}
check {RR6 and the index still describes every point afterwards, with the other\
 two exit codes carried across rather than blanked} \
  [q_ans ase::campaign_index_exits ngspice $RRST] \
  {shard-0001 0 shard-0002 0 shard-0003 0}
check {RR7 a point outside the odometer is refused by name, not clamped to\
 point 0} [string match {RAISED:*no point*} \
  [q_ans ase::campaign_rerun ngspice $RRST [rr_netlist] 9]] 1

## ⚠ IT REFUSES BEFORE IT RUNS, so a re-run against a campaign the bench can no
## longer honour leaves the index it already had rather than a half-rewritten
## one.
set RRBAD [rr_state [dict create enabled 1 axes {{kind var name temp values {1 2}}}]]
set RRBADR [q_ans ase::campaign_rerun ngspice $RRBAD [rr_netlist] 0]
check {RR8 a campaign the simulator refuses is refused here too, with core's own\
 sentence and before anything is run} \
  [list [dict get $RRBADR status] \
        [lindex [lindex [dict get $RRBADR refusals] 0] 0]] {refused temp_not_param}

proc ::ase::campaign_shard_timeout {} { return [::rr_production_tmo] }
check {RR9 and the shipped budget is back in force for everything below} \
  [q_ans ase::campaign_shard_timeout] 1800


} rrerr]} { check {RR0 section RR ran to the end} "RAISED:$rrerr" {} }
# ============================================================================
# THE WIDGET LEGS (DISPLAY only, self-skipping)
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {
if {[catch {

## A real schematic, so `ase::netlist` resolves and a campaign started from the
## DIALOG reaches a deck on disk -- which is the whole of failure mode 5, "two
## halves of a feature tested in different suites never meet". Task 1 shipped the
## runner and this task is its other half.
set GSCH {v {xschem version=3.4.8 file_version=1.3}
G {}
K {}
V {}
S {}
E {}
N 400 -300 500 -300 {lab=A}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 450 -330 0 0 {name=lA lab=A}
}
file mkdir [file join $scratch glib bench schematic]
set f [::open [file join $scratch glib bench schematic bench.sch] w]
puts -nonewline $f $GSCH
::close $f
set f [::open [file join $scratch library.defs] w]
puts $f "DEFINE glib [file join $scratch glib]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
::close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

library_new_view glib bench ngspice_state1 ngspice_state1
set gpath [xschem cellview_path glib/bench ngspice_state1]
if {$gpath eq {}} { error "fixture: state view did not resolve" }
set gkey [ase::session_key glib bench ngspice_state1]
ase::session_open $gkey [file normalize $gpath]
set gst [ase::session_state $gkey]
dict set gst rundir [file join $scratch grun]
dict set gst analyses {{type op enabled 1}}
dict set gst sim_entry {name campgui}
ase::session_update $gkey $gst
check {GC0 open_state -> 1} [ase::open_state glib bench ngspice_state1] 1
update
set gtop [ase::ui::window_for $gkey]
check_true {GC0b session window up} [expr {$gtop ne {} && [winfo exists $gtop]}]

# ---------------------------------------------------------------------------
# GM -- THE DOOR
# ---------------------------------------------------------------------------
set gm_sim {}
for {set i 0} {$i <= [$gtop.mb.sim index end]} {incr i} {
  lappend gm_sim [$gtop.mb.sim entrycget $i -label]
}
check {GM1 `Campaign…` is on the Simulation menu, directly below `Convergence…`\
 -- everything above it configures ONE run of this bench and this is the entry\
 that turns it into many} \
  [list [expr {[lsearch -exact $gm_sim [ase::ui::lbl_camp_menu]] >= 0}] \
        [expr {[lsearch -exact $gm_sim [ase::ui::lbl_camp_menu]] - \
               [lsearch -exact $gm_sim [ase::ui::lbl_conv_menu]]}]] {1 1}
check {GM1b and it is wired to the dialog, not merely present} \
  [$gtop.mb.sim entrycget [ase::ui::lbl_camp_menu] -command] \
  [list ase::ui::campaign_dialog $gkey]

# ---------------------------------------------------------------------------
# GC -- THE CAMPAIGN DIALOG
# ---------------------------------------------------------------------------
$gtop.mb.sim invoke [ase::ui::lbl_camp_menu]
update
set gw $gtop.camp
check_true {GC1 the Campaign dialog opens} [winfo exists $gw]
check {GC2 it carries the enable switch, the seed, the axis table and the three\
 axis buttons -- and the progress readout, which is what makes a campaign\
 against a slow simulator distinguishable from a wedged one} \
  [list [winfo exists $gw.on] [winfo exists $gw.sd.e] [winfo exists $gw.ax.tv] \
        [winfo exists $gw.ax.b.add] [winfo exists $gw.ax.b.edit] \
        [winfo exists $gw.ax.b.del] [winfo exists $gw.btns2.run] \
        [winfo exists $gw.btns2.stop] [winfo exists $gw.btns2.prog] \
        [winfo exists $gw.btns2.res]] {1 1 1 1 1 1 1 1 1 1}
check {GC2b the seed entry has ONE canonical path, so three readers cannot each\
 spell a different one} \
  [list [ase::ui::camp_seed_entry $gkey] [winfo exists [ase::ui::camp_seed_entry $gkey]]] \
  [list $gw.sd.e 1]
check {GC3 a bench with no campaign opens on an empty table, a cleared switch\
 and the sentence that says what that means} \
  [list [llength [$gw.ax.tv children {}]] [ase::ui::camp_axes $gkey] \
        [q_cfg $gw.note -text]] \
  [list 0 {} [ase::ui::lbl_camp_noaxes]]
check {GC4 Run is disabled and Stop is disabled before anything is configured --\
 a Run that started a campaign core would refuse is a button that lies} \
  [list [q_cfg $gw.btns2.run -state] [q_cfg $gw.btns2.stop -state]] {disabled disabled}

## ⚠ THE BYTE-IDENTITY ROW, AND IT IS THE ONE THE 104 COMMITTED `.state` FILES
## REST ON. `sweep` is the ninth member of `ase::omit_if_empty` (⚖ R8's single
## named exception to D3), so a dialog opened and OK'd on a bench that never had
## a campaign must serialize to exactly the same bytes.
set GC_BEFORE [ase::state_serialize [ase::session_state $gkey]]
ase::ui::camp_ok $gkey
update
set GC_AFTER [ase::state_serialize [ase::session_state $gkey]]
check {GC5 opening the dialog and pressing OK on a bench with no campaign\
 changes NOT ONE BYTE of the state -- `sweep` is omitted when empty and the 104\
 committed files depend on it} \
  [expr {$GC_BEFORE eq $GC_AFTER ? {identical} : {MOVED}}] {identical}
## THE NON-VACUITY CONTROL: the same comparison with a campaign really present
## must say MOVED, or GC5 is agreeing with itself.
set GC_ST2 [ase::session_state $gkey]
dict set GC_ST2 sweep [dict create enabled 1 axes {{kind temp values {27 85}}}]
check {GC5b and the control -- a state that really carries a campaign\
 serializes DIFFERENTLY, so GC5 is comparing rather than agreeing with itself} \
  [expr {[ase::state_serialize $GC_ST2] eq $GC_AFTER ? {SAME} : {differs}}] {differs}

## ⚠ A SEED TYPED BEFORE THE FIRST AXIS IS NOT SILENTLY DROPPED. "Accepted and
## inert" is this batch's most-met defect and a form that threw away what the
## user typed because it had not finished being typed would be a new member.
ase::ui::campaign_dialog $gkey
update
set gw $gtop.camp
$gw.sd.e delete 0 end
$gw.sd.e insert 0 4242
ase::ui::camp_sync $gkey
check {GC6 a seed typed before any axis exists survives OK -- a setting accepted\
 and then discarded is this batch's most-met defect} \
  [ase::campaign_get [ase::ui::camp_form_state $gkey] seed] 4242
$gw.sd.e delete 0 end
ase::ui::camp_sync $gkey
check {GC6b and clearing it goes back to a `{}` sweep, so the file is clean\
 again rather than carrying an empty campaign for ever} \
  [ase::state_get [ase::ui::camp_form_state $gkey] sweep] {}

# ---------------------------------------------------------------------------
# GA -- THE AXIS EDITOR, BUILT ENTIRELY FROM DECLARATIONS
# ---------------------------------------------------------------------------
$gw.ax.b.add invoke
update
set ga $gtop.campax
check_true {GA1 the axis editor opens} [winfo exists $ga]

## ⚠ ONE PICKER ENTRY PER KIND THE ADAPTER DECLARES, WEARING THAT KIND'S OWN
## LABEL. A form that typed the five labels here would be the second copy, and
## the second copy is the one that drifts.
set ga_lbls {}
foreach k [lsort [dict keys [ase::campaign_axis_kinds ngspice]]] {
  lappend ga_lbls [dict get [ase::campaign_kind_entry ngspice $k] label]
}
check {GA2 the kind picker offers exactly the adapter's kinds, each wearing the\
 adapter's own label} [q_cfg $ga.kind -values] $ga_lbls
check {GA2b and the list is not a literal: it is derived from the same hook the\
 runner reads, so a simulator that declares four gets four} \
  [llength [q_cfg $ga.kind -values]] [dict size [ase::campaign_axis_kinds ngspice]]

## ⚠ THE PER-KIND FIELDS ARE THE ADAPTER'S `fields` DECLARATION, NOT A SWITCH.
## `inst` declares two (Instance, Parameter), `var` one (Variable) and `temp`
## NONE -- and a kind with no fields is a real answer that must still look like
## a complete form.
proc ga_fields {key lbl} {
  set ::ase::ui::dlg($key,campax,kind) $lbl
  ase::ui::camp_axis_kind_changed $key
  update
  return [ase::ui::camp_axis_fields $key]
}
set ga_got {}
foreach k {var temp corner inst model} {
  set ent [ase::campaign_kind_entry ngspice $k]
  lappend ga_got [ga_fields $gkey [dict get $ent label]]
}
set ga_exp {}
foreach k {var temp corner inst model} {
  set ns {}
  foreach fd [dict get [ase::campaign_kind_entry ngspice $k] fields] {
    lappend ns [dict get $fd name]
  }
  lappend ga_exp $ns
}
check {GA3 every kind's fields come from its own declaration -- two for an\
 instance parameter, one for a design variable, NONE for temperature} \
  $ga_got $ga_exp
check {GA3b and they are the fields the adapter really declares, not a plausible\
 set typed here} $ga_exp {name {} index {target param} {model param}}
## ⚠ BACK TO `inst` FIRST -- the loop above left the form on the LAST kind, and
## a row that read whatever happened to be on screen would pass or fail by
## accident.
ga_fields $gkey [dict get [ase::campaign_kind_entry ngspice inst] label]
check {GA4 each field's LABEL is the adapter's too} \
  [list [q_cfg $ga.f.ltarget -text] [q_cfg $ga.f.lparam -text]] \
  [list [dict get [lindex [dict get [ase::campaign_kind_entry ngspice inst] fields] 0] label] \
        [dict get [lindex [dict get [ase::campaign_kind_entry ngspice inst] fields] 1] label]]

## A kind with NO fields still says what it is, because an empty frame with
## nothing in it is indistinguishable from a form that failed to build.
ga_fields $gkey [dict get [ase::campaign_kind_entry ngspice temp] label]
check {GA5 a kind with no fields shows its unit rather than an empty frame --\
 nothing said is indistinguishable from a form that failed to build} \
  [q_cfg $ga.f.only -text] \
  "[dict get [ase::campaign_kind_entry ngspice temp] label]\
 ([dict get [ase::campaign_kind_entry ngspice temp] unit])"

## The distribution half: the picker and its parameters come from CORE.
set ::ase::ui::dlg($gkey,campax,src) draw
ase::ui::camp_axis_sync $gkey
update
check {GA6 the distribution picker offers core's three neutral names, not the\
 simulator's five netlist spellings -- D34 keeps an ngspice word out of core} \
  [q_cfg $ga.src.d.dist -values] {bounded normal uniform}
set ::ase::ui::dlg($gkey,campax,dist) uniform
ase::ui::camp_axis_dist_changed $gkey
update
check {GA7 changing the distribution rebuilds its parameter fields from core's\
 own required-key list} \
  [list [ase::ui::camp_axis_params $gkey] [winfo exists $ga.src.p.emin] \
        [winfo exists $ga.src.p.emax] [winfo exists $ga.src.p.esigma]] \
  {{min max} 1 1 0}

## ⚠ THE LIST AND THE DISTRIBUTION ARE MUTUALLY EXCLUSIVE ON SCREEN AS WELL AS
## IN THE STATE. A form that left both live would let a user fill in a
## distribution that `ase::campaign_axis_values` silently ignores, because a
## literal `values` list wins.
set ::ase::ui::dlg($gkey,campax,src) list
ase::ui::camp_axis_sync $gkey
update
check {GA8 choosing List disables the whole distribution half, because a literal\
 `values` list WINS in core and a live field that is ignored is a lie} \
  [list [q_cfg $ga.src.values -state] [q_cfg $ga.src.d.n -state] \
        [q_cfg $ga.src.p.emin -state]] {normal disabled disabled}
set ::ase::ui::dlg($gkey,campax,src) draw
ase::ui::camp_axis_sync $gkey
update
check {GA8b and choosing Distribution disables the list} \
  [list [q_cfg $ga.src.values -state] [q_cfg $ga.src.d.n -state]] {disabled normal}

## ⚠ OK IS A COMMIT DOOR AND IT ASKS CORE. An axis that cannot be sampled would
## otherwise land in the table with a `-` in its Points column and stop the
## campaign from the note line of the OTHER dialog, where the user is not looking.
set ::ase::ui::dlg($gkey,campax,dist) normal
ase::ui::camp_axis_dist_changed $gkey
$ga.src.p.emean delete 0 end
$ga.src.p.emean insert 0 abc
$ga.src.p.esigma delete 0 end
$ga.src.p.esigma insert 0 1
$ga.src.d.n delete 0 end
$ga.src.d.n insert 0 5
set ::ase::ui::dlg($gkey,campax,kind) [dict get [ase::campaign_kind_entry ngspice var] label]
ase::ui::camp_axis_kind_changed $gkey
$ga.f.ename delete 0 end
$ga.f.ename insert 0 myres
ase::ui::camp_axis_ok $gkey
update
check {GA9 an axis whose distribution cannot be sampled is refused AT THIS form,\
 with core's own sentence, and the editor stays up} \
  [list [winfo exists $gtop.campax] [llength [ase::ui::camp_axes $gkey]]] {1 0}
$ga.src.p.emean delete 0 end
$ga.src.p.emean insert 0 1000
ase::ui::camp_axis_ok $gkey
update
check {GA10 and with the parameter repaired the axis is added, the editor closes\
 and the table shows it} \
  [list [winfo exists $gtop.campax] [llength [ase::ui::camp_axes $gkey]] \
        [llength [$gw.ax.tv children {}]]] {0 1 1}
check {GA11 the table shows the adapter's KIND label, the axis's column name and\
 the distribution -- never the five samples it expands to} \
  [$gw.ax.tv item 0 -values] \
  [list [dict get [ase::campaign_kind_entry ngspice var] label] myres \
        {normal(mean=1000, sigma=1) x5} 5]

# ---------------------------------------------------------------------------
# GR -- RUNNING A CAMPAIGN FROM THE DIALOG
# ---------------------------------------------------------------------------
# ⚠ THIS IS FAILURE MODE 5: "two halves of a feature tested in different suites
# never meet". Task 1's runner is committed and this task is its other half, so
# at least one row must go from a CLICK in this dialog through to a real
# `index.tsv` on disk. It does.

## A fresh, small campaign: two literal points, so the whole leg is milliseconds.
set ::ase::ui::dlg($gkey,camp,axes) {{kind var name myres values {1k 2k}}}
set ::ase::ui::dlg($gkey,camp,enabled) 1
$gw.sd.e delete 0 end
$gw.sd.e insert 0 11
ase::ui::camp_sync $gkey
update
check {GR1 with an axis configured the note line reports the campaign core would\
 run -- the count, the axes and the mode, in core's own words} \
  [expr {[string match {campaign: 2 points over 1 axis (myres)*} \
           [q_cfg $gw.note -text]] ? {said} : [q_cfg $gw.note -text]}] {said}
## ⚠ A REFUSAL DISPLACES THE NOTES, NOT THE OTHER WAY ROUND. The notes describe
## a campaign that is going to run; printed under a refusal they would describe
## one that cannot, and the user would read the count as a promise.
set ::ase::ui::dlg($gkey,camp,axes) {{kind var name temp values {27 85}}}
ase::ui::camp_sync $gkey
check {GR1b a refused campaign shows the REFUSAL in the note line, in core's own\
 words, and NOT the point count -- a count under a refusal reads as a promise} \
  [list [q_cfg $gw.note -text] \
        [string match {campaign:*} [q_cfg $gw.note -text]]] \
  [list [lindex [lindex [ase::ui::camp_refusals $gkey] 0] 2] 0]
check {GR1c and Run is dead while it stands} [q_cfg $gw.btns2.run -state] disabled
set ::ase::ui::dlg($gkey,camp,axes) {{kind var name myres values {1k 2k}}}
ase::ui::camp_sync $gkey
update

check {GR2 and Run is now enabled while Stop is still not} \
  [list [q_cfg $gw.btns2.run -state] [q_cfg $gw.btns2.stop -state]] {normal disabled}
check {GR3 the progress readout starts at `not running`, never at `0/N`} \
  [q_cfg $gw.btns2.prog -text] [ase::ui::lbl_camp_idle]

file delete -force [file join $scratch grun]
file mkdir [file join $scratch grun]
set GR_RES [q_ans ase::ui::camp_run $gkey]
update
check {GR4 pressing Run ran every point through `ase::campaign_run`} \
  [list [dict get $GR_RES status] [dict get $GR_RES ran] [dict get $GR_RES of]] \
  {done 2 2}
## ⚠ AND THE FILES ARE ON DISK. This is the row that makes the two halves meet.
set GR_DIR [file join $scratch grun campaign]
check {GR5 a real campaign directory exists, with the nominal deck, an\
 index.tsv and one shard directory per point} \
  [list [file isfile [file join $GR_DIR deck.spice]] \
        [file isfile [file join $GR_DIR index.tsv]] \
        [lsort [glob -nocomplain -tails -directory $GR_DIR -type d *]]] \
  {1 1 {shard-0001 shard-0002}}
## ⚠ AND THE OTHER DIRECTION (issue 1457's blind spot): the set of directories on
## disk, the set of shard ids in the index and the odometer must be ONE SET. A
## run that wrote N rows proves nothing about the shard it silently skipped.
set GR_IDX [q_ans ase::campaign_index_read [ase::session_state $gkey]]
set GR_IDS {}
foreach r [lrange $GR_IDX 1 end] { lappend GR_IDS [lindex $r 0] }
check {GR5b the shard ids in the index, the directories on disk and the odometer\
 are ONE set, asked in both directions} \
  [list [lsort $GR_IDS] \
        [lsort [glob -nocomplain -tails -directory $GR_DIR -type d *]] \
        [llength [ase::campaign_points [ase::session_state $gkey]]]] \
  {{shard-0001 shard-0002} {shard-0001 shard-0002} 2}
check {GR6 the campaign that ran is the one the form was showing, and it is also\
 the one now in the session state} \
  [ase::campaign_axes [ase::session_state $gkey]] \
  {{kind var name myres values {1k 2k}}}
check {GR7 the readout ends on the finished sentence with the run/failed split,\
 not on a stale `k of N`} \
  [q_cfg $gw.btns2.prog -text] [ase::ui::lbl_camp_done 2 2 0]
check {GR8 and the buttons come back: Run live again, Stop dead} \
  [list [q_cfg $gw.btns2.run -state] [q_cfg $gw.btns2.stop -state]] {normal disabled}

## ⚠ THE READOUT NAMES THE POINT THAT IS RUNNING, NOT THE ONE THAT FINISHED, AND
## THAT IS ISSUE 1463 REACHING THE SCREEN: a registered binary that never answers
## the capability probe costs 30 s PER SHARD, so a readout reporting the finished
## point would sit on `1 of 2` through the whole of point 2 and on `0 of N` for
## the whole of point 1. The callback is driven directly here, which is what makes
## the claim measurable without a slow simulator.
set GR_ST [ase::session_state $gkey]
check {GR9 the step callback paints the point that is ABOUT TO START -- issue\
 1463 means a shard can be silent for thirty seconds, and `0 of N` for fifty\
 minutes would be a second defect on top of it} \
  [q_ans ase::ui::camp_step $gkey $GR_ST 0 2 {exit 0}] {}
check {GR9b and it names that point's COORDINATES, so `k/N` says what is running\
 rather than only how far along it is} \
  [q_cfg $gw.btns2.prog -text] [ase::ui::lbl_camp_at 2 2 {myres=2k}]
check {GR9c the last point leaves the readout alone, because there is no next\
 one to name} \
  [list [q_ans ase::ui::camp_step $gkey $GR_ST 1 2 {exit 0}] \
        [q_cfg $gw.btns2.prog -text]] \
  [list {} [ase::ui::lbl_camp_at 2 2 {myres=2k}]]

## ⚠ THE STOP SEAM. The callback answers `stop` once the flag is set, and that is
## the whole of "a Stop that keeps every completed point": `ase::campaign_run`
## returns at the point boundary with every finished shard on disk and an index
## that says which points never ran.
set ::ase::ui::dlg($gkey,camp,running) 1
set ::ase::ui::dlg($gkey,camp,stop) 0
check {GR10 the step callback answers nothing while the campaign is live} \
  [q_ans ase::ui::camp_step $gkey $GR_ST 0 4 {exit 0}] {}
set ::ase::ui::dlg($gkey,camp,stop) 1
check {GR10b and answers `stop` once Stop has been pressed, which is the seam\
 `ase::campaign_run` ends the campaign on} \
  [q_ans ase::ui::camp_step $gkey $GR_ST 1 4 {exit 0}] {stop}
set ::ase::ui::dlg($gkey,camp,running) 0
set ::ase::ui::dlg($gkey,camp,stop) 0
check {GR11 Stop pressed with no campaign running says so rather than killing\
 something else} \
  [list [q_ans ase::ui::camp_stop $gkey] [q_ans ase::ui::lbl_camp_norun]] \
  [list {} {ase: no campaign is running}]
## ⚠ AND WITH ONE RUNNING IT REALLY SETS THE FLAG THE LOOP READS. The kill is the
## second half and needs a live shard; the flag is what makes "every completed
## point is kept" true, because the loop ends at a POINT BOUNDARY rather than
## wherever the process happened to be.
set ::ase::ui::dlg($gkey,camp,running) 1
set ::ase::ui::dlg($gkey,camp,stop) 0
set ::ase::ui::dlg($gkey,camp,state) $GR_ST
set ::ase::ui::dlg($gkey,camp,at) 0
set GR_STOPID [q_ans ase::ui::camp_stop $gkey]
check {GR11b Stop with a campaign running sets the flag the step callback reads,\
 and names no process when no shard is in flight} \
  [list $::ase::ui::dlg($gkey,camp,stop) $GR_STOPID] {1 {}}
set ::ase::ui::dlg($gkey,camp,running) 0
set ::ase::ui::dlg($gkey,camp,stop) 0

## A FAILING point is a real state, not a hypothesis: the campaign carries on and
## the readout counts it.
set ::ase::ui::dlg($gkey,camp,ok) 0
set ::ase::ui::dlg($gkey,camp,bad) 0
q_ans ase::ui::camp_step $gkey $GR_ST 0 2 {exit 3}
check {GR12 a point that exited non-zero is counted as failed, so the finished\
 sentence cannot claim a clean campaign over a shard that died} \
  [list $::ase::ui::dlg($gkey,camp,bad) $::ase::ui::dlg($gkey,camp,ok)] {1 0}

## ⚠ EVERY PATH OUT OF `camp_run` ANSWERS A DICT WITH A `status`, AND THIS ROW
## EXISTS BECAUSE THE FIRST VERSION DID NOT. Its five early paths returned `{}`,
## so `dict get $res status` in GR4 RAISED -- and `--nogui --pipe` exits 0 on an
## uncaught mid-script error, so the suite DIED after GR3 and printed no
## `RESULT:` line at all. A door whose refusal is indistinguishable from its
## success is hard to test because it is hard to use.
set GR_STATUSES {}
foreach {tag mk} [list nopoints {set ::ase::ui::dlg($gkey,camp,axes) {}} \
                       refused  {set ::ase::ui::dlg($gkey,camp,axes) {{kind var name temp values {1 2}}}}] {
  uplevel #0 $mk
  ase::ui::camp_sync $gkey
  set r [q_ans ase::ui::camp_run $gkey]
  if {[catch {dict get $r status} st]} { set st "RAISED-OR-EMPTY:$r" }
  lappend GR_STATUSES $st
}
## ⚠ AND THE SESSION STATE IS PUT BACK, NOT ONLY THE DIALOG VARIABLE. `camp_run`
## COMMITS the form before it evaluates the refusals -- deliberately, so that the
## campaign that runs is the one on screen and the one saved is the one that ran
## -- so a probe that gets itself refused leaves its own axis in the state. Two
## later rows (GT2c, GT3) read `ase::campaign_index_header` from that state and
## reported a column named `temp`. Measured here, not reasoned.
set ::ase::ui::dlg($gkey,camp,axes) {{kind var name myres values {1k 2k}}}
ase::ui::camp_sync $gkey
ase::session_update $gkey [ase::ui::camp_form_state $gkey]
check {GR13 every refusing path out of Run answers a dict with a `status`, so a\
 caller that reads one cannot be killed by a refusal} \
  $GR_STATUSES {nopoints refused}
## ⚠ THE `dict get` IS INSIDE THE TOTAL READER, NOT OUTSIDE IT. The first version
## wrote `[dict get [q_ans ...] status]`, so the very failure the row exists to
## catch -- `camp_run` answering `{}` -- made `dict get` RAISE, and the raise was
## swallowed by the widget block's guard and reported as `GX0`. The row that
## should have named the defect named nothing. Measured: sabotage w28 reddened
## `GX0` instead of `GR13b`. Every extractor total, this one included.
check {GR13b and the one that cannot even find its window answers the same\
 shape rather than an empty string} \
  [apply {{r} {
    if {[catch {dict get $r status} v]} { return "NOSTATUS:$r" }
    return $v
  }} [q_ans ase::ui::camp_run nosuchkey]] nowindow

# ---------------------------------------------------------------------------
# GT -- §11c's RESULT TABLE
# ---------------------------------------------------------------------------
ase::ui::campaign_results $gkey
update
set gr $gtop.campres
check_true {GT1 the result table opens on a bench whose campaign has run} \
  [winfo exists $gr]

## ⚠ ISSUE 1457's BLIND SPOT, ASKED THE OTHER WAY. A table that renders the
## columns it knows about cannot notice a measurement column it DROPPED, so the
## assertion is EQUALITY with the index's own header, both directions.
## ⚠ THE TABLE RENDERS THE INDEX FILE'S OWN HEADER, NOT THE HEADER THE BENCH
## WOULD WRITE TODAY, and the difference is not pedantry: a bench that gains a
## measurement AFTER a campaign ran has a column `index.tsv` does not carry, and
## a table that showed it would be showing a column with no data in it as
## though the campaign had produced one.
check {GT2 the table's columns are EQUAL to the index file's own header, asked\
 as equality -- a table that renders what it knows cannot notice a column it\
 dropped} \
  [q_cfg $gr.tv -columns] [lindex $GR_IDX 0]
check {GT2b one table row per index row, header excluded} \
  [llength [$gr.tv children {}]] [expr {[llength $GR_IDX] - 1}]
check {GT2c and the index this campaign wrote is the header core would write\
 for the state that wrote it, so the two ends of the chain agree} \
  [lindex $GR_IDX 0] \
  [ase::campaign_index_header ngspice [ase::session_state $gkey]]

## ⚠ AND NOW GROW THE INDEX BY A MEASUREMENT AND DEMAND THE TABLE GROW WITH IT.
## This is the direction that would pass with the defect in: a column silently
## dropped is invisible to "are the columns I render present?".
set GT_ST [ase::session_state $gkey]
dict set GT_ST measurements {{name pm kind max enabled 1 analysis tran target v(a)}}
ase::session_update $gkey $GT_ST
set GT_H1 [ase::campaign_index_header ngspice [ase::session_state $gkey]]
set GT_COLS0 [q_cfg $gr.tv -columns]
q_ans ase::ui::camp_run $gkey
update
ase::ui::campaign_results $gkey
update
set gr $gtop.campres
check {GT3 a bench that gains an enabled measurement gains EXACTLY that column\
 -- the whole chain walked, from the state through `campaign_index_header`\
 through `index.tsv` on disk to the table} \
  [list [q_cfg $gr.tv -columns] \
        [lindex [ase::ui::campres_rows $gkey] 0] \
        [lindex $GT_H1 end] \
        [expr {[llength $GT_H1] - [llength $GT_COLS0]}]] \
  [list $GT_H1 $GT_H1 pm 1]
dict set GT_ST measurements {}
ase::session_update $gkey $GT_ST
q_ans ase::ui::camp_run $gkey
update
ase::ui::campaign_results $gkey
update
set gr $gtop.campres
check {GT3b and losing it loses exactly that column, so the table follows the\
 index in BOTH directions rather than only growing} \
  [list [q_cfg $gr.tv -columns] \
        [ase::campaign_index_header ngspice [ase::session_state $gkey]]] \
  [list $GT_COLS0 $GT_COLS0]

check {GT4 the distribution panel, the spec entries, the yield line and BOTH\
 canvases exist -- the histogram with mean/sigma/yield beside it is §11c's own\
 deliverable} \
  [list [winfo exists $gr.hist.col] [winfo exists $gr.hist.c] \
        [winfo exists $gr.hist.s.stats] [winfo exists $gr.hist.s.sp.min] \
        [winfo exists $gr.hist.s.sp.max] [winfo exists $gr.hist.s.yield] \
        [winfo exists $gr.sc.x] [winfo exists $gr.sc.y] [winfo exists $gr.sc.c] \
        [winfo exists $gr.btns.export] [winfo exists $gr.btns.rerun]] \
  {1 1 1 1 1 1 1 1 1 1 1}
check {GT4b the column, X and Y pickers all offer the index's own columns, so a\
 picker cannot name a column the table does not have} \
  [list [q_cfg $gr.hist.col -values] [q_cfg $gr.sc.x -values] \
        [q_cfg $gr.sc.y -values]] \
  [list [q_cfg $gr.tv -columns] [q_cfg $gr.tv -columns] [q_cfg $gr.tv -columns]]

## ⚠ THE CANVAS IS THEMED. It is the first canvas ASE-L has ever drawn and
## `_theme_widget` had no arm for the class, so both were left at stock Tk grey
## inside a window this walk had painted -- and under xschem's shipped dark
## scheme, a light grey panel in a dark window.
check {GT5 both canvases are painted from the locked palette, not left at stock\
 Tk grey inside a themed window} \
  [list [q_cfg $gr.hist.c -background] [q_cfg $gr.sc.c -background]] \
  [list [ase::palette table] [ase::palette table]]

## ⚠ THE PANEL OPENS ON THE BENCH'S OWN DATA, AND A SURVIVING SABOTAGE IS WHY.
## The first version took the LAST column of `index.tsv`, which is the last
## MEASUREMENT when the bench has one -- and `raw`, a column of FILE PATHS, when
## it has none. So the table opened on "This column holds no numbers." with a
## perfectly good swept axis one place to its left, and the scatter defaulted to
## that axis against `raw`, which is EMPTY. Sabotage **w24** (drop the
## simulator's suffixes from the scatter) SURVIVED because of it: zero points
## with the suffixes and zero without them are the same picture.
set GT_DATA [ase::ui::campres_data_cols $gkey]
set GT_NUM  [ase::ui::campres_numeric_cols $gkey]
set GT_PREF [ase::ui::campres_pref_cols $gkey]
check {GT5b the data columns are the bench's own -- its axis labels and its\
 enabled measurement names -- derived from the state, with none of the index's\
 three bookkeeping names spelled in this file} \
  [list $GT_DATA [lsearch -exact $GT_DATA shard] [lsearch -exact $GT_DATA exit] \
        [lsearch -exact $GT_DATA raw]] \
  {myres -1 -1 -1}
## ⚠ `exit` HOLDS NUMBERS AND IS STILL NOT A DEFAULT. That is the whole point of
## preferring the DATA columns: a column can be perfectly numeric and still be
## bookkeeping, and opening a yield panel on a column of exit codes is not an
## answer to any question the user asked.
check {GT5c `exit` is numeric and `raw` is not, and NEITHER is preferred -- a\
 numeric bookkeeping column is still bookkeeping} \
  [list [expr {[lsearch -exact $GT_NUM exit] >= 0}] \
        [expr {[lsearch -exact $GT_NUM raw] >= 0}] \
        $GT_PREF] {1 0 myres}
check {GT5d so the panel opens on the last data column that holds numbers,\
 which on a bench with no measurement is the swept axis and NOT the column of\
 file paths it used to be} \
  [ase::ui::campres_default_col $gkey] myres
## ⚠ AND THE SCATTER NEVER OPENS ON A COLUMN AGAINST ITSELF, nor on an empty
## pair. Y is what the histogram opened on; X is the first OTHER column with
## numbers in it.
set GT_XY [ase::ui::campres_default_xy $gkey]
check {GT5e the scatter opens on two DIFFERENT columns that both hold numbers,\
 so the default picture has points in it -- an empty default is a default that\
 hides every defect behind it} \
  [list [expr {[lindex $GT_XY 0] ne [lindex $GT_XY 1]}] \
        [lindex $GT_XY 1] \
        [llength [ase::stat_pairs [ase::ui::campres_rows $gkey] \
                   [lindex $GT_XY 0] [lindex $GT_XY 1] \
                   [ase::ui::campres_suffixes $gkey]]]] \
  {1 myres 2}

## ⚠ THE HISTOGRAM'S OTHER DIRECTION: the numbers it drew plus the cells it could
## not read must equal ONE ROW PER POINT. A picture that bins what it was given
## cannot notice a sample that never arrived.
set GT_ROWS [ase::ui::campres_rows $gkey]
set GT_SUF [ase::ui::campres_suffixes $gkey]
set GT_COL [ase::ui::campres_default_col $gkey]
set GT_VALS [ase::stat_column $GT_ROWS myres]
set GT_BINSUM 0
foreach b [ase::stat_histogram $GT_VALS {} $GT_SUF] { incr GT_BINSUM [lindex $b 2] }
check {GT6 the histogram's bars account for every point -- bins sum to the\
 numbers read, and the numbers read plus the unreadable cells are one row per\
 point of the odometer} \
  [list $GT_BINSUM [llength [ase::stat_numbers $GT_VALS $GT_SUF]] \
        [llength $GT_VALS] \
        [llength [ase::campaign_points [ase::session_state $gkey]]]] {2 2 2 2}

## The drawing itself: bars on the canvas, and NOTHING when the column holds no
## numbers -- an empty axis drawn over no data is a picture of a campaign that
## has not run.
set ::ase::ui::dlg($gkey,campres,col) myres
ase::ui::campres_refresh $gkey
update
check_true {GT7 a swept axis column really draws bars, because the simulator's\
 own suffixes reach the statistics} \
  [expr {[llength [$gr.hist.c find withtag all]] > 2}]
## ⚠ AND A COLUMN WITH NO NUMBERS DRAWS NOTHING AND SAYS SO. `shard` holds
## `shard-0001` -- a real column of a real index that no arithmetic can touch --
## so the panel must say that rather than draw an empty axis over no data, which
## is indistinguishable from a campaign that has not run.
set ::ase::ui::dlg($gkey,campres,col) shard
ase::ui::campres_refresh $gkey
update
check {GT7b a column with no numbers draws no bars and says so, rather than an\
 empty axis over no data} \
  [list [ase::ui::campres_hist_draw $gkey \
           [ase::stat_column $GT_ROWS shard] {} $GT_SUF] \
        [q_cfg $gr.hist.s.stats -text] \
        [q_cfg $gr.hist.s.yield -text]] \
  [list 0 [ase::ui::lbl_campres_nostat] [ase::ui::lbl_campres_yield_none]]
set ::ase::ui::dlg($gkey,campres,col) myres
ase::ui::campres_refresh $gkey
## ⚠ AN EMPTY BIN IS DRAWN AS NOTHING, NOT AS A ONE-PIXEL BAR. A floor under the
## height would make a GAP in the distribution look like a sample -- which is the
## same defect as a `-` read as a zero, one layer out in the picture.
set GT_GAP {1 1 1 9 9 9}
ase::ui::campres_hist_draw $gkey $GT_GAP 4 {}
set GT_BARS 0
foreach it [$gr.hist.c find withtag all] {
  if {[$gr.hist.c type $it] eq {rectangle}} { incr GT_BARS }
}
check {GT7c a distribution with a GAP draws fewer bars than bins -- an empty bin\
 drawn as a one-pixel bar would make a hole in the data look like a sample} \
  [list $GT_BARS [llength [ase::stat_histogram $GT_GAP 4]] \
        [apply {{v n} {
          set z 0
          foreach b [ase::stat_histogram $v $n] { if {[lindex $b 2] == 0} { incr z } }
          return $z
        }} $GT_GAP 4]] {2 4 2}
ase::ui::campres_refresh $gkey

## ⚠ THE RETURN VALUE ALONE WOULD BE AGREEING WITH ITSELF -- the draw proc
## computes its pairs with `ase::stat_pairs` and an expectation that calls
## `ase::stat_pairs` again is the same arithmetic twice. So the row counts the
## MARKS ON THE CANVAS as well, which is the thing the user sees and the only
## half a drawing bug can break.
set GT_NPAIR [ase::stat_pairs $GT_ROWS $::ase::ui::dlg($gkey,campres,x) \
                $::ase::ui::dlg($gkey,campres,y) $GT_SUF]
set GT_SCN [ase::ui::campres_scatter_draw $gkey $GT_ROWS $GT_SUF]
set GT_OVALS 0
foreach it [$gr.sc.c find withtag all] {
  if {[$gr.sc.c type $it] eq {oval}} { incr GT_OVALS }
}
check {GT8 the scatter of two real columns draws one MARK ON THE CANVAS per\
 pair, and there is at least one} \
  [list $GT_SCN $GT_OVALS [llength $GT_NPAIR] [expr {$GT_OVALS > 0}]] \
  [list [llength $GT_NPAIR] [llength $GT_NPAIR] [llength $GT_NPAIR] 1]

## The yield line, driven from the spec entries.
set ::ase::ui::dlg($gkey,campres,col) myres
$gr.hist.s.sp.min delete 0 end
$gr.hist.s.sp.max delete 0 end
ase::ui::campres_refresh $gkey
check {GT9 with no spec the panel asks for one instead of printing a percentage\
 nobody asked for} [q_cfg $gr.hist.s.yield -text] \
  [ase::ui::lbl_campres_yield_none]
$gr.hist.s.sp.max insert 0 1.5k
ase::ui::campres_refresh $gkey
check {GT10 a spec limit typed WITH the simulator's own suffix yields against\
 the same column the histogram drew} \
  [list [ase::ui::campres_spec $gkey] [q_cfg $gr.hist.s.yield -text]] \
  [list {max 1.5k} [ase::ui::lbl_campres_yield \
    [ase::stat_yield $GT_VALS {max 1.5k} $GT_SUF]]]
## ⚠ THE SPEC LIMIT IS DRAWN ON THE HISTOGRAM, and the row counts the DIFFERENCE
## rather than a total. An earlier version of it compared a total item count
## against the bin count plus a constant and passed whether or not the line was
## there -- vacuous, and found by trying to make it fail. Drawing the same data
## with and without the spec must differ by EXACTLY one item, and that item must
## be the dashed line.
ase::ui::campres_hist_draw $gkey $GT_VALS {} $GT_SUF
set GT_NOSPEC [llength [$gr.hist.c find withtag all]]
ase::ui::campres_hist_draw $gkey $GT_VALS {max 1.5k} $GT_SUF
set GT_WITHSPEC [llength [$gr.hist.c find withtag all]]
set GT_DASHED 0
foreach it [$gr.hist.c find withtag all] {
  if {[$gr.hist.c type $it] ne {line}} { continue }
  if {[$gr.hist.c itemcget $it -dash] ne {}} { incr GT_DASHED }
}
check {GT10b the spec limit is DRAWN on the histogram, as exactly one more\
 dashed line -- a yield number is about where that line falls and a user who\
 cannot see it has to take it on trust} \
  [list [expr {$GT_WITHSPEC - $GT_NOSPEC}] $GT_DASHED] {1 1}
## And a limit OUTSIDE the data is not drawn, because a line pinned to the edge
## would say the spec is met at the edge when it is nowhere near it.
ase::ui::campres_hist_draw $gkey $GT_VALS {max 99meg} $GT_SUF
check {GT10c a spec limit outside the range is not drawn at all, rather than\
 clamped to the edge where it would claim a limit the data never reaches} \
  [llength [$gr.hist.c find withtag all]] $GT_NOSPEC
$gr.hist.s.sp.max delete 0 end
ase::ui::campres_refresh $gkey

## ⚠ EXPORT: "ADE-L cannot show you its samples" is this stage's whole claim, so
## the table must leave in a format a spreadsheet opens.
set GT_EXP [file join $scratch out.csv]
check {GT11 Export writes one line per index row plus the header, in the format\
 the extension names} \
  [list [ase::ui::campres_export_to $gkey $GT_EXP] \
        [llength [split [string trimright [q_slurp $GT_EXP] "\n"] "\n"]]] \
  [list [expr {[llength $GT_ROWS] - 1}] [llength $GT_ROWS]]
check {GT11b and the exported file really carries the samples, comma separated\
 because the extension said so} \
  [lindex [split [string trimright [q_slurp $GT_EXP] "\n"] "\n"] 1] \
  [string trim [ase::campaign_export_text [list [lindex $GT_ROWS 1]] csv]]

## Re-run one point, from the table, through core.
check {GT12 Re-run with nothing selected says which gesture is missing rather\
 than silently re-running point 0} \
  [q_ans ase::ui::campres_rerun $gkey] {}
$gr.tv selection set 1
set GT_T0 [rr_tally]
set GT_RR [q_ans ase::ui::campres_rerun $gkey]
check {GT13 Re-run runs exactly the selected point, through\
 `ase::campaign_rerun` -> `ase::campaign_step` -> `ase::run_deck`, and there is\
 no second runner in this file} \
  [list [dict get $GT_RR status] [dict get $GT_RR idx] \
        [expr {[rr_tally] - $GT_T0}]] {done 1 1}

# ---------------------------------------------------------------------------
# GX -- THE EMPTY CASES, WHICH MUST LOOK LIKE ANSWERS
# ---------------------------------------------------------------------------
set gk2 [ase::session_key glib bench ngspice_state2]
library_new_view glib bench ngspice_state2 ngspice_state2
set gp2 [xschem cellview_path glib/bench ngspice_state2]
ase::session_open $gk2 [file normalize $gp2]
set g2 [ase::session_state $gk2]
dict set g2 rundir [file join $scratch grun2]
ase::session_update $gk2 $g2
ase::open_state glib bench ngspice_state2
update
check {GX1 a bench whose run directory holds no campaign gets a window that says\
 so, not an empty table} \
  [list [winfo exists [ase::ui::campaign_results $gk2]] \
        [q_cfg [ase::ui::campres_win $gk2].none -text]] \
  [list 1 [ase::ui::lbl_campres_none]]
catch {destroy [ase::ui::campres_win $gk2]}

## ⚠ A BACKEND WITH NO HOOK GETS NO FALLBACK CONTENT (D34/D36). A simulator that
## declares no campaign axes must be told so in CORE's words -- the axis editor
## refuses to open rather than showing an empty picker.
proc ::gx_nokinds_render {state nl} { return $nl }
proc ::gx_nokinds_cmd {state} { return {/bin/true} }
catch {ase::register_backend gxnone [dict create \
  render_deck ::gx_nokinds_render run_cmd ::gx_nokinds_cmd \
  log_file ::gx_nokinds_render result_probe ::gx_nokinds_render \
  raw_file ::gx_nokinds_render]}
set GX_ST [ase::session_state $gkey]
set GX_SIMSAVE [ase::state_get $GX_ST simulator]
dict set GX_ST simulator gxnone
ase::session_update $gkey $GX_ST
check {GX2 a simulator that declares no campaign axes gets core's own refusal\
 and no axis editor at all -- never an empty picker} \
  [list [ase::ui::camp_axis_editor $gkey -1] [winfo exists $gtop.campax] \
        [ase::ui::camp_kind_labels $gkey]] {{} 0 {}}
dict set GX_ST simulator $GX_SIMSAVE
ase::session_update $gkey $GX_ST

## ⚠ THE DIALOG MAY BE CLOSED WHILE THE CAMPAIGN IS RUNNING. `camp_cancel` sets
## the stop flag and destroys the window; the loop then finishes its current
## point and returns to a `camp_run` with nothing to paint. Every write on that
## path goes through readers that answer `{}` for a window that is gone -- and a
## raise there would kill the campaign AFTER its shards were on disk, which is
## the one moment losing the return value costs something.
ase::ui::campaign_dialog $gkey
update
set ::ase::ui::dlg($gkey,camp,running) 1
ase::ui::camp_cancel $gkey
update
check {GX3 closing the dialog mid-campaign sets the stop flag and leaves every\
 painter total, so the loop can return to a window that is gone} \
  [list $::ase::ui::dlg($gkey,camp,running) $::ase::ui::dlg($gkey,camp,stop) \
        [winfo exists $gtop.camp] \
        [q_ans ase::ui::camp_progress $gkey {anything}] \
        [q_ans ase::ui::camp_sync $gkey] \
        [q_ans ase::ui::camp_note $gkey]] \
  {1 1 0 {} {} {}}
set ::ase::ui::dlg($gkey,camp,running) 0

} gerr]} { check {GX0 the widget sections ran to the end} "RAISED:$gerr" {} }
}

# ============================================================================
# SECTION EE -- THE REAL SIMULATORS, BOTH OF THEM, AND §11c's NUMBER
# ============================================================================
# Task 1's own EE section proved the campaign's axes reach the deck. This one
# asks the question task 2 exists for: does the TABLE's arithmetic describe the
# campaign that really ran? The measurement column is checked against PHYSICS --
# a resistive divider whose answer every reader can compute by hand -- and then
# the mean, the sigma, the histogram and the yield are checked against that
# column rather than against a fixture.

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
  dict set eest design [dict create cell div lib $eedir]
  dict set eest rundir $eedir
  dict set eest simulator ngspice
  dict set eest sim_entry [list name ee$eetag]
  dict set eest save_all_v 1
  dict set eest analyses {{type tran enabled 1 step 1u stop 20u}}
  dict set eest outputs {{expr v(out) plot 1 save 1}}
  dict set eest measurements {{name vout analysis tran kind max target v(out)}}
  ## An INSTANCE-parameter axis: `alter r1 resistance=<v>` at the top of
  ## `.control`, which needs a live circuit and costs no re-parse (measured on
  ## both binaries, issue 1462).
  dict set eest sweep [dict create enabled 1 axes {
    {kind inst target r1 param resistance label rtop values {1k 3k 9k}}}]
  set eenl "* div\nv1 in 0 dc 1\nr1 in out 1k\nr2 out 0 1k\n.end\n"
  set eeres [q_ans ase::campaign_run ngspice $eest $eenl]

  check "EE1/$eetag three real shards, three zero exit codes, one row per point" \
    [list [dict get $eeres status] [dict get $eeres ran] \
          [apply {{st} {
            set o {}
            foreach r [lrange [ase::campaign_index_read $st] 1 end] { lappend o [lindex $r 2] }
            return $o
          }} $eest]] {done 3 {0 0 0}}

  ## ⚠ PHYSICS, NOT A FIXTURE. v(out) = 1k / (rtop + 1k): 0.5, 0.25, 0.1. A
  ## campaign whose axis silently failed to reach the deck gives three identical
  ## numbers and passes any "did it run" row.
  set eerows [q_ans ase::campaign_index_read $eest]
  set eevals [q_ans ase::stat_column $eerows vout]
  set eesuf  [q_ans ase::stat_suffixes ngspice]
  check "EE2/$eetag the measurement column is the divider ASE-L really emitted --\
 0.5 / 0.25 / 0.1, computed from the axis and checked against physics" \
    [apply {{v s} {
      set n [ase::stat_numbers $v $s]
      if {[llength $n] != 3} { return "BADCOL:$v" }
      set o {}
      foreach x $n e {0.5 0.25 0.1} { lappend o [expr {abs($x - $e) < 1e-3}] }
      return $o
    }} $eevals $eesuf] {1 1 1}

  ## ⚠ AND THE PANEL'S ARITHMETIC OVER THAT COLUMN. Every number here is Tcl's,
  ## because ngspice has no sort, no median, no percentile and no histogram.
  check "EE3/$eetag the summary over a REAL measurement column -- n, mean,\
 sigma, min, max and median, none of which the simulator can compute" \
    [apply {{v s} {
      set d [ase::stat_summary $v $s]
      return [list [dict get $d n] [dict get $d rows] \
        [expr {abs([dict get $d mean] - 0.283333) < 1e-4}] \
        [expr {abs([dict get $d sigma] - 0.2021088) < 1e-4}] \
        [expr {abs([dict get $d median] - 0.25) < 1e-4}] \
        [expr {abs([dict get $d min] - 0.1) < 1e-4}] \
        [expr {abs([dict get $d max] - 0.5) < 1e-4}]]
    }} $eevals $eesuf] {3 3 1 1 1 1 1}

  ## ⚠ THE HISTOGRAM ACCOUNTS FOR EVERY POINT, ASKED IN BOTH DIRECTIONS. A
  ## picture that bins what it was given cannot notice a sample that never
  ## arrived, so the bins must SUM to the numbers read and the numbers read plus
  ## the unreadable cells must be one row per point of the odometer.
  check "EE4/$eetag the histogram over the real column accounts for every point,\
 and the odometer agrees with the table" \
    [apply {{st v s} {
      set sum 0
      foreach b [ase::stat_histogram $v {} $s] { incr sum [lindex $b 2] }
      return [list $sum [llength [ase::stat_numbers $v $s]] [llength $v] \
                   [llength [ase::campaign_points $st]]]
    }} $eest $eevals $eesuf] {3 3 3 3}

  ## A yield against a spec the divider really meets twice.
  check "EE5/$eetag yield against a real spec limit, inclusive at the limit" \
    [apply {{v s} {
      set y [ase::stat_yield $v {min 0.25} $s]
      return [list [dict get $y n] [dict get $y pass] [dict get $y fail] \
                   [expr {abs([dict get $y pct] - 66.666667) < 1e-3}]]
    }} $eevals $eesuf] {3 2 1 1}

  ## ⚠ THE EXPORT IS THE SAMPLES LEAVING THE PROGRAM, and on a real run it must
  ## carry the numbers the panel just described. "ADE-L cannot show you its
  ## samples" is the claim; this is it on disk.
  set eeexp [file join $eedir exported.tsv]
  set eetxt [q_ans ase::campaign_export_text $eerows tsv]
  set f [::open $eeexp w] ; puts -nonewline $f $eetxt ; ::close $f
  check "EE6/$eetag the exported table has one line per point plus the header,\
 and the measurement column survives the round trip byte for byte" \
    [apply {{p rows} {
      set t [q_slurp $p]
      set ls [split [string trimright $t "\n"] "\n"]
      set back {}
      foreach l $ls { lappend back [split $l "\t"] }
      return [list [llength $ls] [expr {$back eq $rows ? {same} : {DIFFERS}}]]
    }} $eeexp $eerows] {4 same}

  ## ⚠ AND RE-RUNNING ONE POINT ON A REAL BINARY LEAVES THE OTHER TWO ALONE.
  ## §11b's "re-runnable point by point" is the half of the claim a directory of
  ## rawfiles cannot deliver.
  set eerr [q_ans ase::campaign_rerun ngspice $eest $eenl 1]
  check "EE7/$eetag re-running one point re-runs that point and carries the\
 other two exit codes across, so the index still describes the whole campaign" \
    [list [dict get $eerr status] [dict get $eerr exit] \
          [q_ans ase::campaign_index_exits ngspice $eest] \
          [apply {{st} {
            set o {}
            foreach r [lrange [ase::campaign_index_read $st] 1 end] { lappend o [lindex $r 3] }
            return $o
          }} $eest]] \
    [list done 0 {shard-0001 0 shard-0002 0 shard-0003 0} \
          {shard-0001/div_ase.raw shard-0002/div_ase.raw shard-0003/div_ase.raw}]
}

} eeerr]} { check {EE0 section EE ran to the end} "RAISED:$eeerr" {} }

# ============================================================================
# SECTION HY -- THIS SUITE'S OWN HYGIENE, AND WHY IT ENDS WITH AN EXPLICIT exit
# ============================================================================
# ⚠ T1 CAUGHT THIS SUITE EXITING **10** ON THE DISPLAY ARM WITH EVERY CHECK
# GREEN AND THE BANNER PRINTED. `regression_case_failed`'s first arm is
# `childcode != 0`, so a green suite that does not exit cleanly is still a
# failure -- the harness doing its job.
#
# ⚠ AND THE CAUSE IS NOT A LEAK IN THIS SUITE. That was measured before the
# `exit` below was written, because an `exit` added first would have papered
# over whatever it was. Bisected to ONE LINE, with two scripts that differ by
# nothing else:
#
#     ase::ui::route_design $gkey                        -> rc 0
#     ase::ui::route_design $gkey ; xschem netlist       -> rc 10
#
# **A netlist flips the `-q` fall-through to 10 on the display arm** (headless
# stays 0, measured on the same suite). It is the ATTEMPT, not the success: the
# second script's `xschem netlist` raised and the exit code moved anyway. Every
# other candidate was excluded by measurement, not by argument -- `execute` of
# the same stand-in alone is rc 0, route+execute is rc 0, `ase::run_deck` is not
# required (removing it leaves rc 10), and stubbing `cap_report`,
# `sim_casemode_selectable`, `sim_apply_choice` and `preflight_gate` changes
# nothing.
#
# ⚠ SO THIS SUITE IS THE FIRST GUI SUITE TO NETLIST, because it is the first to
# drive a real run door from a dialog. `test_ase_conv_gui_1460` never calls
# `ase::run`, `ase::run_deck` or `ase::ui::do_run` -- its only match is a
# comment -- and its EE section uses a plain `exec`. It exits 0 by CONSTRUCTION
# ONLY IN THAT IT NEVER NETLISTS; the day it grows a row that does, it becomes
# rc 10 too. The four established `dcases` suites all end with an explicit
# `exit`, which is why none of them has ever met this.
#
# The rows below are the ones that WOULD have caught a real leak, and they are
# kept because the `exit` cannot: once a suite exits explicitly, its exit code
# stops carrying any information about what it left behind.

## Close what this suite opened, so the assertions below mean something.
catch {ase::ui::close glib/bench/ngspice_state1}
catch {ase::ui::close glib/bench/ngspice_state2}
catch {update}

## ⚠ NO **FILE** CHANNEL OF MINE IS STILL OPEN, AND THE WORD `FILE` IS THE WHOLE
## OF THIS ROW'S CORRECTION. `src/ase_window.tcl` shadows `open` and `close` and
## every proc in it runs in that namespace (issue 1461), and this suite reads
## five files of its own, so a leaked FILE channel is a real defect invisible to
## every other row here.
##
## ⚠ THE FIRST VERSION OF THIS ROW ASSERTED `file channels` HELD ONLY THE THREE
## STANDARD ONES, AND IT WAS WRONG TWICE. T1 caught it red on the display arm
## with `{file6}`. Measured, under T1's own invocation
## (`--logdir`, from `tests/`, through `devdisplay.sh`):
##
##     DIAG extra chan=file6 path=pipe:[19098259]
##
## **It is a PIPE, not a file, and not the action log.** The log was the obvious
## suspect and it is not one: measured separately, a session under `--logdir`
## writes `Xschem.log` and `file channels` still holds exactly the three standard
## channels, because the action log is a C-level `FILE*` (`src/util.c`) and never
## a Tcl channel at all.
##
## What it really is: an `execute` pipe in ASYNCHRONOUS CLOSE.
## `execute_fileevent` (src/xschem.tcl) reaches EOF, finds the child not yet a
## zombie (`$finished` 0), and therefore closes the pipe WITHOUT setting it
## blocking -- a deliberate choice with its own comment, so a simulator that
## closes stdout early cannot freeze the program. Tcl keeps an asynchronously
## closing channel in `file channels` until the child is reaped, while
## `execute(pipe,$id)` is already unset -- which is exactly why `HY2` and `HY4`
## stayed green while this one went red.
##
## ⚠ SO IT IS A RACE, AND THE ROW WAS ALSO FLAKY: the same suite passed this
## check on one run and failed it on the next, with only the real simulators in
## section EE between them. A flaky row is worse than no row.
##
## The corrected row classifies each extra channel BY IDENTITY -- `/proc/self/fd`
## for a Tcl `fileN` channel, whose N is its descriptor -- and asserts that none
## of them is a REGULAR FILE. A pipe belongs to `execute`'s own lifecycle and is
## covered by `HY4` while it is still a run; a file can only be this suite's.
proc hy_chan_path {c} {
  if {![regexp {^file([0-9]+)$} $c -> fd]} { return {} }
  set p {}
  if {[catch {file readlink /proc/self/fd/$fd} p]} { return {} }
  return $p
}
proc hy_leaked_files {} {
  set out {}
  foreach c [file channels] {
    if {[lsearch -exact {stdin stdout stderr} $c] >= 0} { continue }
    set p [hy_chan_path $c]
    ## A pipe or a socket is `execute`'s, not this suite's file I/O. Anything
    ## else -- including a path this reader could not resolve -- is counted,
    ## because the control below proves resolution works here.
    if {[string match {pipe:*} $p] || [string match {socket:*} $p]} { continue }
    lappend out [list $c $p]
  }
  return $out
}
## ⚠ THE POSITIVE CONTROL IS IN THE ROW, not in a comment. A detector that could
## not see a file channel at all would pass this section for ever, and that is
## precisely the shape issue 1461 hid in. So: open one, demand it is SEEN, close
## it, demand it is GONE.
set HY_CTL_BEFORE [llength [hy_leaked_files]]
set HY_CTL_CH [::open [info script] r]
set HY_CTL_SEEN [llength [hy_leaked_files]]
set HY_CTL_PATH [hy_chan_path $HY_CTL_CH]
::close $HY_CTL_CH
set HY_CTL_AFTER [llength [hy_leaked_files]]
check {HY1a the leak detector demonstrably SEES a real file channel while it is\
 open and stops seeing it once closed -- a detector that saw nothing would pass\
 this section for ever, which is the shape issue 1461 hid in} \
  [list [expr {$HY_CTL_SEEN - $HY_CTL_BEFORE}] [expr {$HY_CTL_AFTER - $HY_CTL_BEFORE}] \
        [expr {$HY_CTL_PATH eq [file normalize [info script]]}]] {1 0 1}

check {HY1 no REGULAR FILE channel beyond the three standard ones is open at the\
 end -- this suite reads five files of its own and issue 1461 is a leaked\
 channel from a shadowed `close`. An `execute` pipe in asynchronous close is\
 NOT one: it is xschem's own lifecycle, it is covered by HY4 while it is still a\
 run, and asserting on it made this row environment-dependent and flaky} \
  [hy_leaked_files] {}

## ⚠ NO TIMER OF MINE IS PENDING. The ONE that is expected is the in-suite
## watchdog every suite sourcing `scratch.tcl` arms (issue 1403); anything else
## is a repaint or a poll this suite armed and never cancelled, which would keep
## the event loop live after the banner.
set HY_AF {}
foreach a [after info] {
  set what {}
  catch {set what [lindex [after info $a] 0]}
  if {$what ne {::__wd_fire}} { lappend HY_AF [list $a $what] }
}
check {HY2 the only pending timer is the shared suite watchdog -- any other is\
 one this suite armed and never cancelled} $HY_AF {}

## ⚠ AND NO WINDOW OF MINE SURVIVES ITS SESSION. Display arm only: there is no
## `winfo` headless.
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  set HY_TL {}
  foreach w [winfo children .] { if {[string match {.ase*} $w]} { lappend HY_TL $w } }
  check {HY3 closing the sessions closes their windows -- no ASE-L toplevel of\
 this suite is left behind} $HY_TL {}
}

## ⚠ AND NO SIMULATOR PROCESS OF MINE IS STILL IN FLIGHT. `ase::run_deck` takes
## a lock keyed on the results file and `run_done` clears it on EOF; a shard
## killed at the wrong moment strands one (issue 1462's own repair), and the
## next campaign over that directory is then refused by a run nobody is waiting
## for.
set HY_PIPES {}
foreach n [array names ::execute pipe,*] { lappend HY_PIPES $n }
check {HY4 no run of this suite is still in flight at the end} $HY_PIPES {}

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
# THE COMPLETION BANNER (issue 1456). `tests/banner_rule.tcl`'s `banner_complete`
# requires a WHOLE-LINE `OVERALL: ok`, and `run_regression.tcl` counts a case with
# no banner as a HARNESS failure however green its own checks are.
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
# ⚠ AND AN EXPLICIT EXIT, WHICH IS THE HOUSE CONVENTION AND NOT A PATCH OVER A
# LEAK -- section HY above measures what a leak would look like, and there is
# none. Without it the `-q` fall-through carries whatever `xschem netlist` left
# behind (rc 10, measured), and `regression_case_failed` counts a non-zero child
# code as a failure however green the checks are. The four established `dcases`
# suites all end this way; this one now does too.
exit [expr {$fail ? 1 : 0}]
