# Unit J1b -- the implementation, and an independent verification that found a hole
⚠ `verify:j1b` reports GREEN AND HONEST **with one unfenced hole the implementer did not
declare**: nothing asserted that `calc::wave_in_token` gives the viewer context back. The
verifier held the sabotage (delete the `leave_ctx` call) and said red-first was satisfiable, so
the driver closed it rather than accepting a declared hole.


## impl:j1b

**wave_show**

`calc::wave_show {tok d}` in /home/analog/dev/xschem-claude/src/calculator.tcl (2 formals, cited by symbol).

HOW IT RESOLVES THE REGISTRY INDEX. It does not use a column name anywhere. It reads `db`, `xname`, `yname` and `type` off the answer dict (each under `catch`, `type` defaulting to `table`), refuses with `calc::cross_msg destunnamed` if `db`/`xname`/`yname` is missing or empty, and then calls a new sibling `calc::wave_slot {db type}`, which parses ONE `xschem raw info` snapshot and returns the index of the slot whose PATH **and** TYPE both match:

    if {![regexp {^[ \t]*([0-9]+)[ \t]+(.+)[ \t]+(\S+)[ \t]*$} $ln -> i nm ty]} { continue }
    if {[string trim $nm] eq $db && $ty eq $type} { return $i }

That is `calc::wave_dest_cur`'s own idiom in the same file, chosen over `lindex` because the per-line regexp survives a raw path carrying whitespace or a brace, and because the trailing `N current` line cannot match it (only one field after the index). A slot that does not resolve refuses with `calc::cross_msg destnoslot $db` — BEFORE anything is armed.

THE ARM/CALL/TAKE ORDER, exactly as shipped:

    wviewer::plot_dbs_arm $tok [list $idx]
    wviewer::plot_sweeps_arm $tok [list $xn]
    set errs {}
    set rc [catch {wviewer::plot_signals $tok [list $yn] {} \
                       [wviewer::dest_norm {New Strip}]} errs]
    catch {wviewer::plot_dbs_take $tok}
    catch {wviewer::plot_sweeps_take $tok}
    if {$rc} { ... }        ;# the branch is AFTER both takes

The fourth argument is the EXISTING `destover` formal and the new-strip code is READ out of `wviewer::dest_norm {New Strip}` rather than written down — measured in my own probe as `newstrip`.

WHY BOTH TAKES ARE UNCONDITIONAL AND COME FIRST. This is `wviewer::browser_plot_ids`' shape verbatim, including the reason its own comment gives — *no-op after a real call; clears after a stub*. `plot_signals` consumes both channels on its first two lines, before it even refuses an unknown window, so after a real call the takes are no-ops; but an arm whose caller refuses or raises earlier PERSISTS for that token and silently re-axes the NEXT plot in that window. I measured that the takes are load-bearing rather than tidy: deleting the two lines (sabotage c) gave `test_calc_wave_dest` **3 FAILED (112 passed)**, including `-> {refused long {} refused long {dbs sweeps}}` — the arm survived a refused hand-off — plus the band's hygiene row at `{dbs sweeps}`. `calc::plot_rpn` has three refusal returns ahead of its own plot call and this proc has as many, which is why the discipline is copied and not re-reasoned.

A FOURTH PATH, guarded the honest way: `plot_signals` answers a list of `{expr error}` pairs and never throws for a signal that failed, so the length is taken under `catch` into `set nerr -1` and anything that cannot be measured REFUSES rather than defaulting to zero/success.

NOT TOUCHED, and band WD12 derives all of it over the decommented body: no `.calc` widget path, no `calc::buf_set_number`, no `calc::buf_note_edit`, no `xschem raw add`, no `xschem setprop rect … sweep …`, no `xschem raw switch_back`. Verified by sabotage d — adding one `calc::buf_note_edit` call gave **1 FAILED (114 passed)** -> `{1 wave_show {} 1}`.

**token_bracket**

`calc::wave_in_token {tok d}`, shaped on `calc::plot_in_token` line for line:

    if {$tok eq {}} { return [calc::wave_refusal [calc::cross_msg destnoview]] }
    set ticket {}
    if {[catch {wviewer::enter_ctx $tok} ticket]} { return ...destbusy... }
    if {![lindex $ticket 0]}                      { return ...destbusy... }
    set h {}
    if {[catch {calc::wave_show $tok $d} h]} { set h [calc::wave_refusal [calc::cross_msg destplot $h]] }
    catch {wviewer::leave_ctx $tok $ticket}
    return $h

HOW IT MATCHES `calc::plot_in_token`'s SHAPE, point by point: refuse on an empty token before any context is taken; `wviewer::enter_ctx` with NO `borrow` (the issue-0314 borrow door is open only to callers that run no `update`/`after`, only READ and always restore — this one WRITES: it mutates the layout, creates a strip and ends in a redraw, so it must not lower somebody else's semaphore); the two-leg refusal (a raise from `enter_ctx`, and a ticket whose first element is 0); the inner call inside `catch`; and `wviewer::leave_ctx` UNCONDITIONALLY on the way out, under `catch`, on every path including the raise path.

Both refusal arms were driven behaviourally in an armed headless probe:

    empty token          -> ok 0 ... msg {Destination: no waveform viewer holds this result, ...}
    token with no window -> ok 0 ... msg {Destination: the waveform viewer is busy, ...}
       armed after (a)/(b): dbs=0 sweeps=0

Note `destbusy` conflates *no window holds this token* with *the switch was refused*, because `wviewer::enter_ctx` answers `{0 {}}` for both — that is `calc::plot_in_token`'s own conflation (`calc::plot_msg busy`) and matching it was deliberate rather than overlooked.

I also added `calc::wave_refusal {msg}` — ONE site for the refusal answer dict (`ok 0 db {} sweep {} vec {} msg $msg`), so the key set cannot drift between the five refusing paths and the one success path. That is `calc::cross_refusal`/`calc::plot_refusal`'s precedent. It names neither channel, so band WD12's armer derivation still answers exactly `{wave_show}`.

**fn_measure**

HOW IT IS WIRED. The destination arm of `calc::fn_measure` in src/calculator.tcl was a single `return [calc::status [calc::arg_msg destination $name $db]]`. It is now:

    set tok {}
    catch {set tok [dict get $g token]}
    set h [calc::wave_in_token $tok $d]
    set m [calc::arg_msg destination $name $db]
    set hok 0
    catch {set hok [dict get $h ok]}
    if {$hok ne {1}} {
        set hm {}
        catch {set hm [dict get $h msg]}
        if {$hm ne {}} { append m " " $hm }
    }
    return [calc::status $m]

The token comes from `[dict get $g token]`, the `calc::require_result` dict the proc already holds — not re-fetched, not re-derived. The destination sentence is KEPT unchanged and the hand-off's own `msg` is APPENDED only when it refuses, which is exactly what `calc::plot_rpn` already does with its `$drop`. Nothing in the arm reaches `calc::buf_set_number`; the three `catch {dict get …}` spellings match every other read in the proc.

WHAT THE USER SEES ON SUCCESS — one sentence, unchanged from unit J1: *"Measured wave: dutyCycle went to __calc_dest2 instead of the buffer."* — and now the curve actually appears, on its own strip, against its own X. Measured on the display arm (band S28/7, `ALL PASS (579 checks)`): the click's return value and `.calc.status.msg get` AGREE, the sentence names the verb and the database, the status history records it, and the RPN buffer, `edit modified`, `calc::buf_can undo`/`redo`, the Stack size and both Tk-8.4 fallback hints are all unmoved (`wv_moved {}`), with one `calc::buf_undo`/`buf_redo` leaving the buffer on its capture.

WHAT THE USER SEES ON A HAND-OFF REFUSAL — the same destination sentence with the reason appended, so the wave is never silently lost. Measured verbatim from the five arms, every one driven:

    Destination: the measurement named no destination, so there is nothing to show.
    Destination: __calc_dest7 is no longer a registered result, so the measured wave could not be shown.
    Destination: no waveform viewer holds this result, so the measured wave was left where it is.
    Destination: the waveform viewer is busy, so the measured wave was not shown.
    Destination: the viewer would not plot the measured wave (<the seam's own text>).

Those five sentences went into `calc::cross_msg` rather than being inlined, because that proc's own header says `dest*` belongs there — *"one place a wording ruling lands"* — and because row WD10 of test_calc_wave_dest.tcl then exercises every one of them as a derivation over the proc's own switch patterns. They are UNRATIFIED user-visible wording covered by the existing `rule` debt against `calc::eval_msg`'s sentences; I did not touch the owed ledger.

AND THE CONTROL: on a SCALAR answer the viewer is handed nothing at all. S28/7's control row asserts `$::WV_HAND` is `{}` while the number is still pasted and one undo still restores the expression — green. Confirmed independently: `calc::fn_sink` on a scalar answers `buffer`, on a wave answers `destination`.

**green_proof**

######## COUNTED ARM -- the command, verbatim ########
$ cd /home/analog/dev/xschem-claude
$ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_scratch_reuse test_calc_measure test_calc_engine test_calc_cross

PASS     | test_calc_wave_dest          run 1/5  RESULT: ALL PASS (115 checks)
PASS     | test_calc_scratch_reuse      run 2/5  RESULT: ALL PASS (56 checks)
PASS     | test_calc_measure            run 3/5  RESULT: ALL PASS (170 checks)
PASS     | test_calc_engine             run 4/5  RESULT: ALL PASS (265 checks)
PASS     | test_calc_cross              run 5/5  RESULT: ALL PASS (187 checks)
RESULT: 5/5 runs passed

######## DISPLAY ARM -- through run_suites.sh, Xvfb :99 via xvfb_arm.sh ########
$ cd /home/analog/dev/xschem-claude
$ tests/headless/run_suites.sh test_calc_skeleton test_calc_plot test_calc_widgets test_calc_buffer
   (the run announced: display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0)

PASS     | test_calc_skeleton           run 1/4  RESULT: ALL PASS (579 checks)
PASS     | test_calc_plot               run 2/4  RESULT: ALL PASS (113 checks)
PASS     | test_calc_widgets            run 3/4  RESULT: ALL PASS (259 checks)
PASS     | test_calc_buffer             run 4/4  RESULT: ALL PASS (130 checks)
RESULT: 4/4 runs passed

######## THE ARITY PINS AND THE WALKER COUNT, display arm ########
$ tests/headless/run_suites.sh test_wave_grid test_wave_sigbrowser test_node_token_split test_wave_viewer

PASS     | test_wave_grid               run 1/4  RESULT: ALL PASS (400 checks)
PASS     | test_wave_sigbrowser         run 2/4  RESULT: ALL PASS (353 checks)
PASS     | test_node_token_split        run 3/4  RESULT: ALL PASS (174 checks)
PASS     | test_wave_viewer             run 4/4  RESULT: ALL PASS (437 checks)
RESULT: 4/4 runs passed

######## ANOMALY COUNT in both final runs ########
grep -cE 'FAIL:|UNEXPECTED ERROR|BGERROR|ABORTED|another regression run is live' -> 0 and 0.
Zero live-peer lines, so both runs were solo.

######## THE RED I MEASURED MYSELF FIRST, src/ byte-identical to HEAD ########
$ git diff --stat -- src/            (no output)
$ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_scratch_reuse
FAIL     | test_calc_wave_dest          run 1/2  RESULT: 5 FAILED (110 passed)
FAIL     | test_calc_scratch_reuse      run 2/2  RESULT: 1 FAILED (55 passed)
RESULT: 0/2 runs passed
$ tests/headless/run_suites.sh test_calc_skeleton test_calc_plot
FAIL     | test_calc_skeleton           run 1/2  RESULT: 3 FAILED (576 passed)
FAIL     | test_calc_plot               run 2/2  RESULT: 4 FAILED (109 passed)
RESULT: 0/2 runs passed

The red rows, verbatim, included `-> {only:0 only:0 0} (exp {atleast atleast 1})` (the row that says J1b happened),
`-> {NOPROC:calc::wave_show long {} NOPROC:calc::wave_show long {}} (exp {refused long {} refused long {}})`,
`-> {only:1 has MISSING:wave_show plot_rpn} (exp {atleast has has plot_rpn})` (SR5), and PL10's
`{{RAISED:ERR:invalid command name "calc::wave_in_token"} NOTRACE {NOKEY:vec ...}}`.

All logs: /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J1b/impl/

**rows_weakened**

NO. Proved three ways, the first by arithmetic over the diffstat.

(1) THE DIFFSTAT. `git diff --numstat` is:

    14   3   doc/claude/calculator_batch/DESTINATION_CONTRACT.md
   217  10   src/calculator.tcl
    23   7   src/wave_viewer.tcl
   202   0   tests/headless/test_calc_plot.tcl
   105   9   tests/headless/test_calc_scratch_reuse.tcl
   242   0   tests/headless/test_calc_skeleton.tcl
   669  14   tests/headless/test_calc_wave_dest.tcl
     1   1   tests/run_regression.tcl

The four suite files are the rowsmith crew's work and NOT mine: their mtimes are 15:00:27, 15:00:27, 15:03:22 and 15:04:50, while my earliest edit to anything is src/wave_viewer.tcl at 15:22:09. I wrote to exactly four files: src/calculator.tcl, src/wave_viewer.tcl, tests/run_regression.tcl and DESTINATION_CONTRACT.md. Zero test rows, zero expectations, zero row names.

(2) EVERY DELETED LINE ACCOUNTED FOR. `git diff -U0 | grep '^-'` over my four files gives 21 removed lines: 9 comment lines in `calc::fn_measure`'s header (the stale `band CW14` cross-reference, replaced by a longer correction naming S28/7 and PL10), 7 comment lines above `wviewer::graph_props` (the wrong "ALL SEVEN WALKERS" count, replaced by prose that carries no number), 3 prose lines in DESTINATION_CONTRACT.md §9 (same wrong count), 1 comment word in run_regression.tcl (`the identical 88 checks` -> `the IDENTICAL set of checks`), and ONE line of code: `return [calc::status [calc::arg_msg destination $name $db]]`, which is the destination arm the wiring replaced. No other code line was removed anywhere.

(3) CONSERVATION OF TOTAL CHECKS, red -> green, per suite, both arms. A weakened, deleted or short-circuited row lowers the total; every total is exactly preserved:
    test_calc_wave_dest       110 passed + 5 failed = 115  ->  ALL PASS (115 checks)   delta 0
    test_calc_scratch_reuse    55 passed + 1 failed =  56  ->  ALL PASS (56 checks)    delta 0
    test_calc_skeleton        576 passed + 3 failed = 579  ->  ALL PASS (579 checks)   delta 0
    test_calc_plot            109 passed + 4 failed = 113  ->  ALL PASS (113 checks)   delta 0
    test_calc_measure / engine / cross / widgets / buffer unmoved at 170 / 265 / 187 / 259 / 130.
13 counted and 14 display rows were red; 13 and 14 are now green, with not one row lost on the way.

(4) AND THE FENCES WERE RE-RUN RATHER THAN RE-READ. Five sabotages against the delivered implementation each reddened between one and three rows (see collision_fixed); the tree was then restored and `cmp` confirmed src/calculator.tcl byte-identical to the pristine implementation before the final runs.

**counts_rederived**

COMMANDS. Counted: `env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_scratch_reuse test_calc_measure test_calc_engine test_calc_cross`. Display: `tests/headless/run_suites.sh test_calc_skeleton test_calc_plot test_calc_widgets test_calc_buffer`. Both run from /home/analog/dev/xschem-claude. Every figure below I measured in this session, twice (an interim green run at 15:22 and a final one at 15:29-15:30, identical both times).

COUNTED ARM
  test_calc_wave_dest        before(red) 5 FAILED (110 passed)  ->  after ALL PASS (115 checks)
  test_calc_scratch_reuse    before(red) 1 FAILED (55 passed)   ->  after ALL PASS (56 checks)
  test_calc_measure          before ALL PASS (170)              ->  after ALL PASS (170 checks)
  test_calc_engine           before ALL PASS (265)              ->  after ALL PASS (265 checks)
  test_calc_cross            before ALL PASS (187)              ->  after ALL PASS (187 checks)

DISPLAY ARM
  test_calc_skeleton         before(red) 3 FAILED (576 passed)  ->  after ALL PASS (579 checks)
  test_calc_plot             before(red) 4 FAILED (109 passed)  ->  after ALL PASS (113 checks)
  test_calc_widgets          before ALL PASS (259)              ->  after ALL PASS (259 checks)
  test_calc_buffer           before ALL PASS (130)              ->  after ALL PASS (130 checks)
  test_wave_grid 400, test_wave_sigbrowser 353, test_node_token_split 174, test_wave_viewer 437 -- all ALL PASS, all unmoved.

PRE-STAGE PUBLISHED FIGURES, attributed to the recon receipt rather than claimed as mine (my red was taken with the rows already in the tree): 102 -> 115 (wave_dest, +13), 54 -> 56 (scratch_reuse, +2), 573 -> 579 (skeleton, +6), 105 -> 113 (plot, +8). Four published check counts move; no other suite's does.

WHICH ONLY A DISPLAY ARM CAN PRODUCE -- ALL FOUR right-hand suites, and the receipt measured it: under `--nogui`, `test_calc_skeleton` reports `ALL PASS (0 checks)` and `test_calc_plot`, `test_calc_widgets` and `test_calc_buffer` self-skip with `no X -- nothing ran`. So **579, 113, 259 and 130 exist ONLY on a display arm**, and a green `--nogui` number says nothing whatever about band S28/7 or band PL10. That is why I ran the display arm for the red AND the green AND two of the five sabotages.

TRAILER TERMS -- NONE MOVES, and I re-derived it rather than predicted it. `tests/run_regression.tcl`'s lists, counted with CLAUDE.md's own method (`set <L> [list` then `grep -o '"[^"]*"' | wc -l`): tcases 3, hcases 96, dcases 25 -> 124 + `xschemtest` = **125 cases, 124 blocks**, identical to the driver's baseline at 30d304a0. No suite is registered or de-registered by this unit; all four edited suites were already registered (wave_dest and scratch_reuse in `hcases`, skeleton and plot in `dcases` alone). My only edit to run_regression.tcl is one comment word, and `info complete` on the file is 1. The recon's census of the four suites' real captured output found `skip:0 SKIP:0 SKIPPED:0 RESULT:1` for each, so no line SHAPE changes either: cases +0, blocks +0, counted_failures +0, skips +0, `wc -l` +0. This is the PLAN 5.4 pattern again -- a stage that moves four published check counts and not one trailer term, because `wc -l` moves with the NUMBER of `RESULT:`/`skip:` lines and not with the counts inside them. **I did not run T1; read the gate trailer.**

**arity_untouched**

NO FORMAL WAS ADDED OR REMOVED ANYWHERE. The whole reason the armed one-shot channel exists is to avoid it.

MEASURED with `info args` against the LIVE namespace inside an armed headless run (`env -u DISPLAY tests/headless/run_suites.sh --nogui <probe>`, the probe since deleted):

    info args wviewer::plot_signals = {token exprs colors destover} (4 formals)
    info args wviewer::graph_props  = {G active grid} (3 formals)
    info args calc::wave_show       = {tok d}
    info args calc::wave_in_token   = {tok d}
    wviewer::dest_norm {New Strip}  = newstrip

`wviewer::add_trace` keeps its 7 and both `*_arm`/`*_take` pairs their 2/1 — none of them is called with a changed shape, and the only new call sites are the five inside `calc::wave_show`.

CROSS-CHECKED BY THE THREE SUITES THAT PIN THEM, all run on the display arm and all green: `test_wave_grid` **ALL PASS (400 checks)** (GT8 pins `graph_props`' three and GT9 its `grid` default), `test_wave_sigbrowser` **ALL PASS (353 checks)** (BM05 matches `proc wviewer::plot_signals {token exprs {colors {}} {destover {}}}` as a LITERAL SOURCE STRING and pins `browser_plot_ids`' call shape), and `test_calc_wave_dest` **ALL PASS (115 checks)**, whose WD4 row is the only one of the three a T1 gate reaches and which re-measures BOTH arities plus `plot_signals`' first two formal names and the existence of all four one-shot channel procs.

The fourth argument I pass is the EXISTING `destover`, not a fifth. The recon's reason is the one that bites and I did not test it the hard way: a 5-arg call raises *"too many arguments"* into `wviewer::browser_plot_ids`' own `catch`, which swallows it, so a whole class of browser gesture checks would read as *"the gesture did nothing"* instead of failing — and `test_wave_grid`/`test_wave_sigbrowser` are in NEITHER `hcases` nor `dcases`, so that mistake would give a green gate and a red `full_audit.sh`.

**switch_comment_check**

YES, I touched a proc containing a `switch`: `calc::cross_msg` in src/calculator.tcl, where I appended five arms (`destunnamed`, `destnoslot`, `destnoview`, `destbusy`, `destplot`) after `destengine`. No comment went between any two patterns — every word of prose about them sits ABOVE the proc, in the existing header.

A BRACE SCAN WAS NOT RELIED ON, AND IT WOULD NOT HAVE BEEN SUFFICIENT. `info complete` answers 1 for both edited files (src/calculator.tcl, src/wave_viewer.tcl), and that is exactly the answer a comment between two patterns also produces — the trap is semantic and parity-dependent, so a green `info complete` proves only that the braces balance.

THE BEHAVIOURAL CONFIRMATION, with the arm set DERIVED FROM THE PROC'S OWN SWITCH ARGUMENT and never listed. An armed headless probe decommented `info body ::calc::cross_msg`, matched `^[ \t]*([a-zA-Z_][a-zA-Z0-9_]*)[ \t]+\{[ \t]*return` over it, invoked every arm it found with `aaa bbb`, and checked each answer for emptiness, a raise and the house shape (leading capital, colon-space, full stop):

    cross_msg arms DERIVED from the proc's own switch patterns: ok=36 raised-or-malformed=0
    the five arms unit J1b added are IN that derived set: missing=
    unknown kind still falls through: {}
    arg_msg arms (UNTOUCHED this stage, swept as the control): ok=10 bad=0

36 arms, every one exercised, zero raises, zero malformed, the new five present in the DERIVED set (so the sweep is not vacuous about my change), and an unknown kind still falling through to the empty string rather than raising. Plus the two shipped sweeps that do the same job every run: row WD10's `cross_msg` arm sweep inside `test_calc_wave_dest` **ALL PASS (115)** (with its non-vacuity leg and `atleast 24` floor), and MT12's `arg_msg` arm sweep inside `test_calc_measure` **ALL PASS (170)**.

A green run still proves only that the word count is even — that limit is unchanged and is why the arm set is derived rather than written down. I also did not add a `switch` anywhere: `calc::fn_measure`'s destination arm, which I rewired, is an if/elseif LADDER by deliberate design (its own comment says so, for this exact reason), so that edit carries no parity risk at all.

**collision_fixed**

PROVED BY DRIVING TWO DESTINATIONS IN A REAL VIEWER WINDOW AND READING THE DRAWN TRACE'S OWN SAMPLES BACK OUT OF THE DATABASE IT CAME FROM. Not a green suite — the numbers.

The probe was a temporary copy of tests/headless/test_calc_plot.tcl (which has a real `wviewer::open` window and a loaded `ac` fixture) with a measurement block inserted in band PL10 and the output written to a scratch file. It was run through `tests/headless/run_suites.sh` on Xvfb :99 and then DELETED (`find . -name '*j1b*'` now returns nothing).

######## ARMED -- the delivered implementation ########
two-destinations, identical column names: {__calc_dest1 {calcx calcy}} {__calc_dest2 {calcx calcy}}
calc::wave_in_token answer: ok 1 db __calc_dest2 sweep calcx vec calcy msg {}
the DRAWN trace dict: vec=calcy sweep=calcx rawfile=__calc_dest2 sim_type=table
WHICH DESTINATION: SECOND (correct)
Y SAMPLES in the drawn trace's own db: 0.91 0.82 0.73 0.64 0.55
   ysA (first destination)  = 0.11 0.22 0.33 0.44 0.55
   ysB (second destination) = 0.91 0.82 0.73 0.64 0.55
strips before=2  after=2 1
sweep= tokens on the new strip: calcx
   (and the suite itself: PASS | RESULT: ALL PASS (113 checks))

######## SABOTAGE a -- the one line `wviewer::plot_dbs_arm $tok [list $idx]` DROPPED ########
two-destinations, identical column names: {__calc_dest1 {calcx calcy}} {__calc_dest2 {calcx calcy}}
calc::wave_in_token answer: ok 1 db __calc_dest2 sweep calcx vec calcy msg {}
the DRAWN trace dict: vec=calcy sweep=calcx rawfile=__calc_dest1 sim_type=table
WHICH DESTINATION: FIRST (the collision defect)
Y SAMPLES in the drawn trace's own db: 0.11 0.22 0.33 0.44 0.55

READ THAT PAIR TOGETHER. In BOTH runs the hand-off ANSWERS `db __calc_dest2`, so the status sentence names the right destination either way — that is why this defect is silent. Unarmed, the trace that gets drawn carries `rawfile=__calc_dest1` and its samples are `0.11 0.22 0.33 0.44 0.55`, i.e. the FIRST measurement's curve under the second measurement's sentence. Armed, the trace carries `rawfile=__calc_dest2` and the samples are `0.91 0.82 0.73 0.64 0.55` — the SECOND destination's own curve, distinct from the first in every sample but the last.

AND THE FENCES CATCH IT, which is the second half of the measurement. Sabotage a reddened `test_calc_wave_dest` at **3 FAILED (112 passed)** -- `{wave_show 0 wave_show atleast}`, `{atleast only:0 1}`, `{... {} calcx calcy ...}` (nothing on the database channel) -- and the display-arm copy at **2 FAILED (111 passed)** with PL10 printing `-> {1 found {calcy calcx __calc_dest1 table}}` and `-> {differ __calc_dest1 FIRST}`.

THE OTHER FOUR SABOTAGES, run and not re-read, src/ restored and `cmp`-verified after each:
  drop `destover`              -> wave_dest 1 FAILED (114 passed) at the strip leg; display copy 2 FAILED with `NOOWNSTRIP` and `sweep= {frequency frequency calcx}` -- the MIXED strip, and `strips before=2 after=3` proves no strip was created
  delete the two `take` calls  -> wave_dest 3 FAILED (112 passed), incl. `{refused long {} refused long {dbs sweeps}}`
  armer calls buf_note_edit    -> wave_dest 1 FAILED (114 passed) -> `{1 wave_show {} 1}`
  `add_trace` not plot_signals -> wave_dest 2 FAILED (113 passed) -> `{wave_show 1 {} atleast}` and `NOTCALLED` throughout
`test_calc_scratch_reuse` stayed at ALL PASS (56) under every one, which is SR5's declared honest limit: it fences the R402 exemption, not the wiring.


### declared_holes

- THE END-TO-END PATH IS NEVER DRIVEN WHOLE. Band S28/7 presses the real button but RENAMES `calc::wave_in_token` aside to a recorder (it has no loaded raw at all), and band PL10 calls `calc::wave_in_token` directly rather than through a click. So `calc::fn_click dutyCycle` -> real `fn_measure` -> real `wave_in_token` -> real viewer -> a trace on screen is exercised by NOTHING in one run. Both halves are fenced; the seam between them is inferred. This is the suite structure the rowsmith crew chose and I did not change a row to alter it.

- PL10 FENCES *WHICH* DESTINATION BUT NOT *WHICH CURVE*. It asserts the drawn trace's `rawfile` is the second destination's name. The sample-level proof -- `0.91 0.82 0.73 0.64 0.55` out of the drawn trace's own database rather than `0.11 ...` -- exists only in my transcript, through a temporary probe that is now deleted. A future change that got the `rawfile` right and the samples wrong would pass PL10. Nothing in the tree closes that; naming it rather than widening a row somebody else wrote.

- `calc::wave_slot` ANSWERS -1 OUTSIDE THE VIEWER'S CONTEXT, measured: with two destinations registered, read from the Calculator's own context it gave `A=-1 B=-1`, and inside the loan it resolves correctly. So `calc::wave_show` is only correct when called inside `calc::wave_in_token`'s context loan, and that dependency is enforced only by convention -- a future direct caller would get `destnoslot` and a refusal sentence, with no row naming the real cause. Band WD12 calls `wave_show` directly and works because the counted suite builds its destinations in its own context.

- `destbusy` CONFLATES TWO CAUSES. `wviewer::enter_ctx` answers `{0 {}}` both for a token no window holds and for a switch it refused, so the user gets *the waveform viewer is busy* in both cases. That is `calc::plot_in_token`'s own conflation (`calc::plot_msg busy`) and matching it was deliberate, but it means an unknown token is reported as busyness.

- THE FIVE NEW SENTENCES ARE UNRATIFIED USER-VISIBLE WORDING and I did not file a debt for them -- the task forbids touching the owed ledger. They join the existing `rule` debt against `calc::eval_msg`'s sentences, which is what every other `calc::cross_msg` arm relies on. The driver owes the ledger entry.

- THE `nerr != 0` GUARD IS UNFENCED. `calc::wave_show` refuses rather than defaults to success when `llength` cannot measure `plot_signals`' answer. No row makes `plot_signals` return a non-list, so that branch is reached by nothing; it is there because defaulting an unmeasurable answer to zero would be a silent success.

- THE SUCCESS ANSWER'S `sweep` AND `vec` KEYS ARE READ BY NOBODY. `calc::wave_show` returns `ok 1 db .. sweep .. vec .. msg {}`; `calc::fn_measure` reads only `ok` and `msg`, and the rows read only `ok`. The two extra keys exist for key-set parity with `calc::wave_refusal` and are unfenced.

- THE OFF-WINDOW CONSEQUENCE IS NEVER RENDERED. That a measured trace on a MIXED strip is drawn outside the window is fenced as a headless HAZARD (band WD12 on the bare verbs) and prevented by the own-strip rows, but no pixel was looked at. A `look` debt stands and I did not file it.

- I DID NOT EDIT `WIRING_CONTRACT.md`. The driver corrected §7.4 and added a §12 in commit c25c4a6e while I was working, so I left that file alone to avoid a concurrent-write conflict; its §5 cost table still reads `test_calc_wave_dest ALL PASS (90)` / `test_calc_measure ALL PASS (160)` against today's 115 and 170. I corrected the two copies that were mine: `src/wave_viewer.tcl` above `wviewer::graph_props` and `DESTINATION_CONTRACT.md` §9, both now carrying a SHAPE and pointing at band WD12's first row instead of a number. One further copy of the old sentence survives in `doc/claude/calculator_batch/receipts/H-destination-impl.md`, which is a dated receipt and should stay unedited.

- NO T1 RUN. I ran nine suites on the counted arm and eight on the display arm; the gate is the driver's. The trailer delta was DERIVED (registration re-counted at tcases 3 / hcases 96 / dcases 25, unchanged), not predicted from a remembered figure, and not measured.

**user_visible**

WHAT A USER CAN NOW DO. Press a measurement button in the Calculator — `dutyCycle` with the default all-cycles setting, `delay` with `nth = 0`, anything whose answer is a waveform rather than a single number — and the measured curve now APPEARS in the waveform viewer by itself, on a strip of its own, plotted against its own X column, with a status line naming the verb and the database it went to. Before this unit the measurement silently built a database and stopped: the user had to go and find it in the Results picker and plot it by hand, which is why the viewer's own sweep-channel hook had never had a single caller.

The second thing they can now do is MEASURE TWICE. Until this unit, every destination's two columns carried the same two names, so a second measurement would have drawn the FIRST one's curve under the second one's caption — no error, no warning, nothing on screen to tell them apart. Measured here with two destinations side by side: the second measurement now draws the second measurement's samples.

And when it cannot be shown, they are told. The sentence still says where the wave went, with the reason appended — no destination named, the result no longer registered, no viewer holding this result, the viewer busy, or the viewer refusing the plot. The wave is never lost silently.

Their typing is untouched. A waveform answer pastes NOTHING into the RPN buffer, moves no undo step, and leaves the Undo and Redo buttons exactly as they were. A SCALAR answer still pastes the number and one Undo still puts the expression back.

WHAT STILL DOES NOT WORK, plainly.
- Nobody has LOOKED at it. Everything above was measured by reading the viewer's own data back out, not by viewing a picture. A `look` debt is owed for one screenshot of a measured curve on its own strip.
- A measured wave stacked onto a strip that already has ordinary traces can still be drawn off-window — that is a pre-existing limitation of the viewer's auto-X-zoom, and this unit avoids it by always giving the measurement its own strip rather than by fixing it.
- The destination's names (`__calc_dest2`, `calcx`, `calcy`) and all five new sentences are wording nobody has ratified. They are deliberately not asserted anywhere, so a ruling on them costs no test changes.
- Destinations are still never dropped: they accumulate for the session. That is unit J1's behaviour and this unit did not change it; it is now harmless rather than wrong, because each measurement is drawn from its own slot.
- The full click-to-pixel path is exercised in two halves rather than once end to end (see the declared holes).



## verify:j1b

**independent_rerun**

I ran both arms twice over, in two different trees, from my own commands. Every figure below is mine; I quote none of the implementer's.

######## RUN 1 -- the main tree /home/analog/dev/xschem-claude ########
$ cd /home/analog/dev/xschem-claude
$ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_scratch_reuse test_calc_measure test_calc_engine test_calc_cross
test home: throwaway /tmp/xschem-test-home.3398395.9otGsW (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
PASS     | test_calc_wave_dest          run 1/5  RESULT: ALL PASS (115 checks)
PASS     | test_calc_scratch_reuse      run 2/5  RESULT: ALL PASS (56 checks)
PASS     | test_calc_measure            run 3/5  RESULT: ALL PASS (170 checks)
PASS     | test_calc_engine             run 4/5  RESULT: ALL PASS (265 checks)
PASS     | test_calc_cross              run 5/5  RESULT: ALL PASS (187 checks)
RESULT: 5/5 runs passed

$ tests/headless/run_suites.sh test_calc_skeleton test_calc_plot test_calc_widgets test_calc_buffer
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_calc_skeleton           run 1/4  RESULT: ALL PASS (579 checks)
PASS     | test_calc_plot               run 2/4  RESULT: ALL PASS (113 checks)
PASS     | test_calc_widgets            run 3/4  RESULT: ALL PASS (259 checks)
PASS     | test_calc_buffer             run 4/4  RESULT: ALL PASS (130 checks)
RESULT: 4/4 runs passed

######## RUN 2 -- my own detached worktree, implemented src/ copied in ########
(worktree at HEAD c25c4a6e + the 5 modified test files + the 2 modified src files, `cmp`-verified byte-identical to the main tree's)
PASS     | test_calc_wave_dest          run 1/2  RESULT: ALL PASS (115 checks)
PASS     | test_calc_scratch_reuse      run 2/2  RESULT: ALL PASS (56 checks)
PASS     | test_calc_plot               run 1/2  RESULT: ALL PASS (113 checks)
PASS     | test_calc_skeleton           run 2/2  RESULT: ALL PASS (579 checks)
Identical to run 1 on every suite -- the figures are deterministic across two trees.

######## THE ARITY PINS, display arm, my own run ########
$ tests/headless/run_suites.sh test_wave_grid test_wave_sigbrowser test_node_token_split test_wave_viewer
PASS     | test_wave_grid               run 1/4  RESULT: ALL PASS (400 checks)
PASS     | test_wave_sigbrowser         run 2/4  RESULT: ALL PASS (353 checks)
PASS     | test_node_token_split        run 3/4  RESULT: ALL PASS (174 checks)
PASS     | test_wave_viewer             run 4/4  RESULT: ALL PASS (437 checks)
RESULT: 4/4 runs passed

######## ANOMALY SWEEP over all five logs I captured ########
`UNEXPECTED ERROR|BGERROR|ABORTED|FATAL|signal 15` = 0 in every log; `another regression run is live` = 0 in every log, so every run was solo.
Binary: `make -C src -q` exits 0, i.e. src/xschem (Oct 1 10:40) is NOT stale against the C sources -- checked before any run, per the no-harness-builds rule.

######## TRAILER TERMS -- re-derived by me, not predicted ########
Registration lists counted by bracket-matching `set <L> [list ... ]` and counting quoted words, comment lines stripped, against BOTH the working tree and `git show HEAD:tests/run_regression.tcl`:
  working tree: tcases 3, hcases 96, dcases 25  -> 125 cases, 124 blocks
  HEAD        : tcases 3, hcases 96, dcases 25  -> 125 cases, 124 blocks
  delta       : 0 / 0 / 0 on every list.
`git diff -- tests/ src/ | grep '^+' | grep -E 'puts.*(skip:|SKIP|RESULT:|note:)'` is EMPTY, so the stage adds no counted and no published line shape: skips +0 and `wc -l` +0 as well. Every trailer term holds. I did not run T1 -- the gate is yours.

**rows_weakened_audit**

NO ROW WAS WEAKENED, and the red reproduces exactly. Audited `git diff -- tests/` hunk by hunk, by enumerating all 24 deleted lines (`git diff -U0 -- tests/ | /usr/bin/grep '^-'`) and classifying each. +1219 / -24 across five files.

A. EIGHTEEN of the 24 are COMMENT lines, every one a correction of prose that carried the wrong "all SEVEN walkers carry the sweep= token forward" count:
   - 1 in test_calc_scratch_reuse.tcl's SR5 header, 3 in SR5's widening comment (the stale `like the viewer-door row below` cross-reference)
   - 2 in test_calc_wave_dest.tcl's band map WD4 entry, 6 in hole H2, 2 in the WD4 band comment
   - 1 in tests/run_regression.tcl (`the identical 88 checks` -> `the IDENTICAL set of checks`; the number dropped, per CLAUDE.md, not updated)
   Nothing asserted changes. Removing a wrong number from prose is the only remedy this tree permits.

B. THREE are row NAMES reworded with the EXPECTATION UNTOUCHED -- I checked each expectation line is absent from the deletion set:
   - SR5 `R402 ...the only direct adder that reads NOTHING back...` : expectation `$persistent {wave_dest}` unchanged
   - WD4 `...the ordinary traces' token names a REAL column...` : expectation `{0 1}` unchanged
   - SR5 `...procs that reach the engine through the VIEWER's door...` : see D below

C. ONE is a STRICT EXTENSION. WD4's two-arity row: `{3 grid 4 1 1}` -> `{3 grid 4 {token exprs} 1 1 1 1}`. The original five legs are intact in order; two new arm/take existence legs and `plot_signals`' first two formal names are added. Strictly more asserted.

D. TWO ARE GENUINE RELAXATIONS, both in SR5, both declared by the suite crew, and I classify them as DELIBERATE WIDENING rather than weakening -- but I say plainly what was lost:
   - `$viaviewer {plot_rpn}` (exact one-name literal) -> `[list [sr_floor [llength $viaviewer] 2] [sr_has $viaviewer plot_rpn] [sr_has $viaviewer wave_show] $viaviewer]` vs `[list atleast has has $viaviewer]`. Exactness is gone; a THIRD Calculator-to-viewer route would now pass. What is paid in exchange is real and I verified it: the derivation behind it was itself a hand-kept alternation `regexp {wviewer::(add_trace|plot_signals)}`, replaced by a transitive closure over the `::wviewer::` procs that issue `xschem raw add`, and the NEW non-vacuity row (floor 3 on the direct set, `has add_trace`, closure strictly wider, `has plot_signals`, floor 100 on the namespace map) is itself a new fence. Plus a new disjointness-against-R402-obligations row. Net +2 checks for -1 exact literal.
   - the BOTH-DOORS row's `[list [llength $adders] 1 {}]` -> `[list [llength $adders] [llength $viaviewer] {}]`. That middle leg is now SELF-REFERENTIAL and asserts nothing. The non-vacuity it used to carry moved to the floor leg above it, which I confirmed is green and does carry it.
   One narrowing I found that the crew did NOT name: `sr_nameref` requires `wviewer::<name>` followed by a non-word char, where the old pattern was a bare substring -- and `src/wave_viewer.tcl` really has five prefix-extensions (`add_trace_dialog|_filter|_forget|_pick|_ok`). I measured it vacuous: `/usr/bin/grep -oE 'wviewer::[A-Za-z0-9_]+' src/calculator.tcl` shows `wviewer::add_trace` (9x) and NO `add_trace_*` reference at all, and `add_trace_ok` reaches `add_trace` so the closure would hold it anyway. Worth one line in the ledger, not a defect.

E. ONE is the single removed line of CODE: `return [calc::status [calc::arg_msg destination $name $db]]`, the destination arm the wiring replaced. No other code line is removed in tests/ or src/.

######## THE RED, REPRODUCED IN MY OWN WORKTREE, src/ AT HEAD ########
`git worktree add --detach <scratch>/J1b/verify/w HEAD`, built binary + config.h copied in, the 5 modified test files copied over, `git diff --stat -- src/` EMPTY.

$ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_scratch_reuse
FAIL     | test_calc_wave_dest          run 1/2  RESULT: 5 FAILED (110 passed)
FAIL     | test_calc_scratch_reuse      run 2/2  RESULT: 1 FAILED (55 passed)
$ tests/headless/run_suites.sh test_calc_skeleton test_calc_plot test_calc_widgets
FAIL     | test_calc_skeleton           run 1/3  RESULT: 3 FAILED (576 passed)
FAIL     | test_calc_plot               run 2/3  RESULT: 4 FAILED (109 passed)
PASS     | test_calc_widgets            run 3/3  RESULT: ALL PASS (259 checks)

FAILING-ROW COUNT: 6 counted + 7 display = 13. Matches the suite crew's record exactly.
THE EXPECTATION LITERALS, machine-extracted from my own logs, every one identical to what the crew recorded:
  -> {{} 1 {} only:0} (exp {{} 1 {} atleast})
  -> {only:0 only:0 0} (exp {atleast atleast 1})
  -> {ok measured named differ NOTCALLED NOTCALLED NOTCALLED NOTCALLED NOTCALLED real} (exp {ok measured named differ 2 calcx calcy __wd_notawindow newstrip real})
  -> {NOPROC:calc::wave_show long {} NOPROC:calc::wave_show long {}} (exp {refused long {} refused long {}})
  -> {0 {} {} 1} (exp {1 {} {} 1})
  -> {only:1 has MISSING:wave_show plot_rpn} (exp {atleast has has plot_rpn})
  -> {1 NOPROC 1 1 {} 1 1} (exp {1 ok 1 1 {} 1 1})
  -> {1 NOPROC 1 agree 1 1 recorded} (exp {1 ok 1 agree 1 1 recorded})
  -> {1 NOPROC args: {} {}} (exp {1 ok called s28tok __s28_dest_fixture})
  -> {{RAISED:ERR:invalid command name "calc::wave_in_token"} NOTRACE {NOKEY:vec NOKEY:sweep NOKEY:rawfile NOKEY:sim_type}} (exp {1 found {calcy calcx __calc_dest2 table}})
  -> {differ NOKEY:rawfile notfirst} (exp {differ __calc_dest2 notfirst})
  -> {0 0 NOOWNSTRIP} (exp {1 1 hasown})
  -> {NOSTRIP NOSTRIP:-1} (exp {found calcx})

######## AND THE ARITHMETIC THAT RULES OUT A ROW TURNED GREEN BY EDITING IT ########
I measured the TRUE baseline myself, which the implementer could not: `git stash push -- tests/` in the worktree, so tests AND src were both at HEAD.
  test_calc_wave_dest     ALL PASS (102 checks)
  test_calc_scratch_reuse ALL PASS (54 checks)
  test_calc_skeleton      ALL PASS (573 checks)
  test_calc_plot          ALL PASS (105 checks)
Then: 102 old + 13 new = 115 = 110 passed + 5 failed. 54 + 2 = 56 = 55 + 1. 573 + 6 = 579 = 576 + 3. 105 + 8 = 113 = 109 + 4. And green after = 115 / 56 / 579 / 113. Every pre-existing row survives into the red AND into the green; no shortfall anywhere. Counted deltas +13 and +2; display deltas +6 and +8 (= the 14 display rows).

**sabotage_resurvey**

SIX sabotages, all against the delivered implementation in my own worktree, all RUN rather than re-read. After each I restored from a pristine copy and `cmp`-verified byte-identity with /home/analog/dev/xschem-claude/src/calculator.tcl before the next. `info complete` checked 1 on the file after every edit.

(a) REQUIRED -- `wviewer::plot_dbs_arm $tok [list $idx]` DELETED (verified: `grep -c plot_dbs_arm src/calculator.tcl` = 0)
  counted: test_calc_wave_dest 3 FAILED (112 passed)
    -> {wave_show 0 wave_show atleast} (exp {wave_show 1 wave_show atleast})
    -> {atleast only:0 1} (exp {atleast atleast 1})
    -> {ok measured named differ {} calcx calcy __wd_notawindow newstrip real} (exp {... 2 calcx ...})   [nothing on the database channel]
  display: test_calc_plot 2 FAILED (111 passed)
    -> {1 found {calcy calcx __calc_dest1 table}} (exp {1 found {calcy calcx __calc_dest2 table}})
    -> {differ __calc_dest1 FIRST} (exp {differ __calc_dest2 notfirst})
  test_calc_scratch_reuse 56 and test_calc_skeleton 579 unmoved -- SR5's declared limit, confirmed.

(b) REQUIRED -- a TAKE SKIPPED ON A REFUSAL PATH. I used a NARROWER shape than the implementer's (they deleted both lines; I MOVED both `catch {wviewer::plot_*_take $tok}` lines to AFTER the `if {$rc}` return, so only the raise path leaks). It still reddens:
  counted: test_calc_wave_dest 2 FAILED (113 passed)
    -> {refused long {} refused long {dbs sweeps}} (exp {refused long {} refused long {}})   [the arm survived a refused hand-off]
    -> {{} {} 1 0 {dbs sweeps} 4 0} (exp {{} {} 1 0 {} 4 0})                                  [the band's own hygiene row]

(c) REQUIRED -- THE DESTINATION STACKED ONTO AN EXISTING STRIP. `[wviewer::dest_norm {New Strip}]` replaced by `{}`, so the window's own Append destination stands:
  counted: test_calc_wave_dest 1 FAILED (114 passed)
    -> {ok measured named differ 2 calcx calcy __wd_notawindow {} real} (exp {... newstrip real})
  display: test_calc_plot 2 FAILED (111 passed)
    -> {0 1 NOOWNSTRIP} (exp {1 1 hasown})
    -> {found {frequency frequency calcx}} (exp {found calcx})   [THE MIXED STRIP -- exactly the shape `graph_fullxzoom` cannot frame, three traces on one rect with two different x quantities]

(d) MINE, past the brief -- THE SUBTLE COLLISION: the database channel is still ARMED, but with `[list 0]` instead of the resolved index, so "something arms each channel" stays green:
  counted: test_calc_wave_dest 1 FAILED (114 passed) -> {... differ 0 calcx ...} (exp {... differ 2 calcx ...})  [the row's "and not zero" claim is real]
  display: test_calc_plot 4 FAILED (109 passed), including `{0 NOTRACE {NOKEY:vec ...}}` and `{1 0 NOOWNSTRIP}` and `{NOSTRIP NOSTRIP:-1}`

(e) MINE -- ⚠⚠ THIS ONE SURVIVED, AND IT IS THE FINDING. `catch {wviewer::leave_ctx $tok $ticket}` DELETED from `calc::wave_in_token`, so the borrowed design context is never given back:
    test_calc_wave_dest ALL PASS (115), test_calc_scratch_reuse ALL PASS (56), test_calc_measure ALL PASS (170),
    test_calc_plot ALL PASS (113), test_calc_skeleton ALL PASS (579).  NOTHING REDDENS.
  I then proved the leak is REAL, not an unobservable path, with a probe band inserted into a copy of test_calc_plot.tcl (run via `tests/headless/run_suites.sh`, now deleted -- `find . -name '*j1b*'` returns nothing):
    delivered:  viewer win_path = .x1.drw ; current_win_path BEFORE = .drw
                enter_ctx TICKET = {1 .drw}      <- element 1 NON-EMPTY, so the bracket DOES switch and leave_ctx DOES have work
                current_win_path AFTER the hand-off = .drw        (correctly restored)
    sabotaged:  current_win_path BEFORE = .x1.drw   <- already stranded in the viewer by an EARLIER band's hand-off
                enter_ctx TICKET = {1 {}}            <- now the fast path, so every later loan silently no-ops
                current_win_path AFTER the hand-off = .x1.drw     (permanently in the viewer)
  (e2) THE CONTROL, which makes this a J1b-specific gap and not a pre-existing class: I applied the SAME sabotage to the precedent `calc::plot_in_token` and it DOES redden --
    test_calc_plot 1 FAILED (112 passed), row PL1: "⚠ U8 a press from ANOTHER window's context PLOTS -- so the loan is TAKEN and not merely attempted -- and the context comes BACK" -> {.drw 1 .x1.drw 1} (exp {.drw 1 .drw 1}).
  So `calc::plot_in_token`'s give-back is fenced by PL1 and `calc::wave_in_token`'s is fenced by nothing. The implementer's `token_bracket` answer explicitly CLAIMS this property ("`wviewer::leave_ctx` UNCONDITIONALLY on the way out ... on every path"); the claim is true of the code and absent from the fences, and it is NOT among their ten declared holes.
  The code is CORRECT. Only the fence is missing, and I hold the sabotage that reddens it.

**collision_confirmed**

YES -- and I drove it to SAMPLE level, which closes the implementer's own declared hole #2 ("PL10 fences WHICH destination but not WHICH curve") in my transcript rather than taking their word for it.

HOW I DROVE IT. I wrote my own probe band into a copy of tests/headless/test_calc_plot.tcl (which has a real `wviewer::open` window and a loaded fixture), inserted after PL10's closing brace, run through `tests/headless/run_suites.sh` on Xvfb :99 and since DELETED. It builds two destinations with DELIBERATELY DIFFERENT Y samples, hands off the SECOND, then finds the drawn trace by its `vec`, switches to the `rawfile` that trace actually carries, and reads the Y column back with `xschem raw values`. The samples are the evidence, not the trace dict.

######## ARMED -- the delivered implementation ########
destination A = __calc_dest3   destination B = __calc_dest4
COLUMN NAMES are identical in both: A={calcx calcy} B={calcx calcy}
hand-off ANSWERED: ok=1 db=__calc_dest4 sweep=calcx vec=calcy
the DRAWN trace: vec=calcy sweep=calcx rawfile=__calc_dest4 sim_type=table
WHICH DESTINATION: SECOND -- correct
Y SAMPLES read out of the DRAWN trace's OWN database (__calc_dest4): 0.91 0.82 0.73 0.64 0.55
   ysA (first destination)  = 0.11 0.22 0.33 0.44 0.55
   ysB (second destination) = 0.91 0.82 0.73 0.64 0.55
SAMPLES MATCH ysB? yes    SAMPLES MATCH ysA? no

######## UNARMED -- the same probe, `plot_dbs_arm` deleted ########
destination A = __calc_dest3   destination B = __calc_dest4
COLUMN NAMES are identical in both: A={calcx calcy} B={calcx calcy}
hand-off ANSWERED: ok=1 db=__calc_dest4 sweep=calcx vec=calcy        <- STILL names the right destination
the DRAWN trace: vec=calcy sweep=calcx rawfile=__calc_dest1 sim_type=table
Y SAMPLES read out of the DRAWN trace's OWN database (__calc_dest1): 0.11 0.22 0.33 0.44 0.55
SAMPLES MATCH ysB? no    SAMPLES MATCH ysA? yes
and my own check row caught it: -> {WRONG:__calc_dest1 no yes} (exp {second yes no})

READ THE PAIR TOGETHER, because this is exactly why the defect is silent: in BOTH runs the hand-off answers `db=__calc_dest4`, so the user's status sentence names the right destination either way. Unarmed, the curve on screen comes out of a different database and its samples are a different measurement's numbers. Armed, the drawn trace carries its own slot and its own samples, distinct from the first in four of five points.

TWO THINGS I OBSERVED THAT THE IMPLEMENTER DID NOT REPORT, neither a defect in J1b:
 * The collision premise is confirmed independently -- two coexisting destinations really do answer the IDENTICAL `calcx calcy` from `xschem raw list`.
 * Unarmed, resolution did not even land on the first of the CURRENT pair: it reached `__calc_dest1`, a destination an EARLIER band had created and dropped. So the bare-name resolution is not bounded to the live pair, which makes the unfixed defect worse than described, and makes the registry-index resolution more clearly the right shape.

**verdict**

GREEN AND HONEST -- with ONE unfenced hole I found that the implementer did not declare, and which I recommend closing before commit.

WHAT HOLDS, all re-measured by me:
 * Both arms green, twice, in two trees, deterministic: 115 / 56 / 170 / 265 / 187 counted and 579 / 113 / 259 / 130 display. Zero anomaly lines, zero live-peer lines in all five logs.
 * The red reproduces EXACTLY in my own worktree with src/ at HEAD: 6 counted + 7 display failing rows, and all thirteen expectation literals byte-identical to what the suite crew recorded.
 * NO ROW WEAKENED. All 24 deleted lines in tests/ classified: 18 comment corrections of a wrong prose count, 3 row-name rewords with untouched expectations, 1 strict extension, 2 declared SR5 relaxations paid for with a new non-vacuity row, 1 line of replaced code. The HEAD-tests baseline I measured myself (102 / 54 / 573 / 105) plus the deltas (+13 / +2 / +6 / +8) equals every red and green total exactly, so no pre-existing row went missing on the way.
 * Five sabotages redden, including all three you named, and the display arm prints the two shapes that matter in English: `__calc_dest1 FIRST` for the collision and `{frequency frequency calcx}` for the mixed strip.
 * The collision is really fixed, confirmed at SAMPLE level by my own probe, both directions.
 * Arities untouched and independently cross-checked: test_wave_grid 400, test_wave_sigbrowser 353, test_node_token_split 174, test_wave_viewer 437, all ALL PASS.
 * No trailer term moves. I re-derived registration (3 / 96 / 25 -> 125 cases, 124 blocks) against both the working tree and HEAD: delta zero on every list, and the diff adds no `skip:`/`SKIP`/`RESULT:` emission at all, so skips and `wc -l` hold too.
 * The binary is not stale (`make -C src -q` exits 0), and `info complete` is 1 on both edited src files -- which, as this file's own warning says, proves only that the braces balance. The behavioural confirmation that matters is that `calc::cross_msg`'s five new arms are exercised by WD10's derived arm sweep, green at 115.

THE ONE THING WRONG -- a missing fence, not a wrong implementation:
`calc::wave_in_token`'s give-back of the borrowed design context is asserted by NOTHING. Deleting `catch {wviewer::leave_ctx $tok $ticket}` from it leaves all five Calculator suites at ALL PASS (115 / 56 / 170 / 113 / 579), and I proved the consequence is real rather than an unobservable path: the bracket genuinely switches here (ticket `{1 .drw}`), and sabotaged, `current_win_path` is stranded at the viewer's `.x1.drw` permanently, after which every later loan silently takes `enter_ctx`'s already-there fast path. The precedent this bracket was copied from, `calc::plot_in_token`, IS fenced -- the same sabotage applied there reddens row PL1 of tests/headless/test_calc_plot.tcl. So this is a J1b-specific gap, not an inherited class, and it is the one property the implementer's receipt asserts in prose and the tree does not assert at all. It is also not in their ten declared holes, which are otherwise honest -- I verified hole #2 (PL10 checks `rawfile`, not samples) by closing it in my own transcript, and it is indeed still open in the tree.

This is the batch's own most expensive lesson arriving on schedule: a green run is not evidence that a fence still fences, and the fence that was never written is the easiest kind to miss.

**for_the_driver**

BEFORE COMMITTING -- one item, and it is cheap:

1. ⚠ ADD THE GIVE-BACK LEG TO BAND PL10, modelled line for line on row PL1 of /home/analog/dev/xschem-claude/tests/headless/test_calc_plot.tcl, which already fences the identical property for `calc::plot_in_token` with the identical `.drw` / `.x1.drw` discriminant. Read `xschem get current_win_path` before and after `calc::wave_in_token` and assert it comes back. Cost: display arm 113 -> 114, so test_calc_plot's published count becomes 114 and nothing else moves (no trailer term, since the suite is already registered in `dcases` alone). I hold the sabotage that reddens it -- delete `catch {wviewer::leave_ctx $tok $ticket}` from `calc::wave_in_token` -- so the row can be shown red first, which is the method this project requires and which the row would otherwise never have demonstrated. Red-first is satisfiable here; it is not a row written after the fact.
   If you would rather land J1b now, the code is correct and the gap is purely in coverage -- but then it is a declared hole, and the implementer's receipt must stop claiming the property in prose, because the tree does not assert it.

2. The implementer owes TWO ledger entries they could not file (the task forbade touching owed.sh). Both are yours:
   - a `rule` debt for the FIVE new unratified user-visible sentences in `calc::cross_msg` (`destunnamed`, `destnoslot`, `destnoview`, `destbusy`, `destplot`); they join the existing debt against `calc::eval_msg`'s wording.
   - a `look` debt for one screenshot of a measured curve on its own strip. Nobody has looked at any of this; everything was measured by reading the viewer's own data back.

3. `doc/claude/calculator_batch/WIRING_CONTRACT.md` section 5's cost table still reads `test_calc_wave_dest ALL PASS (90)` / `test_calc_measure ALL PASS (160)` against today's 115 and 170. The implementer deliberately left that file alone to avoid a concurrent-write conflict with your own c25c4a6e edit. It is yours, and per CLAUDE.md the remedy is to drop the numbers, not refresh them.

4. One line for the ledger that nobody has recorded: SR5's new `sr_nameref` is NARROWER than the alternation it replaced (it requires a word boundary, where the old pattern was a bare substring), and src/wave_viewer.tcl really does carry five `add_trace_*` prefix-extensions. I measured the narrowing VACUOUS -- src/calculator.tcl references `wviewer::add_trace` nine times and no `add_trace_*` even once, and `add_trace_ok` reaches `add_trace` so the transitive closure would hold it anyway. Worth writing down so the next reader does not re-derive it.

EXACT PUBLISHED COUNTS FOR THE COMMIT MESSAGE -- all measured by me, twice, in two trees:
  MOVED (four, and only four):
    test_calc_wave_dest        102 -> 115   (hcases alone, counted arm)
    test_calc_scratch_reuse     54 ->  56   (hcases alone, counted arm)
    test_calc_skeleton         573 -> 579   (dcases alone, DISPLAY ARM ONLY -- reports 0 checks under --nogui)
    test_calc_plot             105 -> 113   (dcases alone, DISPLAY ARM ONLY -- self-skips `no X` under --nogui)
  UNMOVED: test_calc_measure 170, test_calc_engine 265, test_calc_cross 187, test_calc_widgets 259, test_calc_buffer 130,
           test_wave_grid 400, test_wave_sigbrowser 353, test_node_token_split 174, test_wave_viewer 437.
  TRAILER: no term moves. tcases 3 / hcases 96 / dcases 25 -> cases 125, blocks 124, identical to HEAD; counted_failures +0, skips +0, and `wc -l` +0 because the stage adds no `RESULT:` and no `skip:` line. This is the PLAN 5.4 pattern again -- published check counts move, trailer terms do not. Read the gate trailer; I did not run T1.
  ⚠ If you add the PL10 leg in item 1, test_calc_plot becomes 114 and that is the only figure above that changes.

MY ARTEFACTS: /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J1b/verify/ holds counted_green.log, display_green.log, pins.log, red_counted.log, red_display.log, samp_armed.txt, samp_unarmed.txt, ctx.txt, ctx_sab.txt and the pristine/ copies I restored from. My worktree is removed, both probe suites are deleted, and the main tree's `git diff --numstat` and `git status --short` are byte-for-byte what they were when I started -- I changed nothing in /home/analog/dev/xschem-claude.

