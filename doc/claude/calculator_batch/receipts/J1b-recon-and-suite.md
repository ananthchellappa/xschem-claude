# Unit J1b -- the recon and the red-first suite
⚠ The `recon:j1b` **contradictions** section overturns `WIRING_CONTRACT.md` §7.4 and a shipped
source comment, and names a REAL DEFECT in the tree J1 shipped. The `suite:j1b`
**for_the_implementer** section is the specification.


## recon:j1b

**viewer_door**

EVERY CLAIM HERE WAS RUN, NOT READ. Probes under /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J1b/recon/.

== THE CHANNEL, MEASURED ==
`info args` on the live namespace: `::wviewer::plot_sweeps_arm` 2 formals `{token sweeps}`, `plot_sweeps_take` 1 `{token}`, `plot_dbs_arm` 2 `{token dbs}`, `plot_dbs_take` 1 `{token}`.

ZERO ARMERS CONFIRMED TWO WAYS. (a) Derived over 517 `::wviewer::*` bodies plus every `::calc::*`, `::ase::*`, `::results::*` body, both raw and DECOMMENTED: `plot_sweeps_arm` armers = {} (empty), `plot_sweeps_take` consumers = `{::wviewer::plot_signals}`. (b) Over the file text, non-comment lines only: `src/wave_viewer.tcl` names `plot_sweeps_arm` on exactly 1 line (its own `proc` line), `plot_sweeps_take` on 2, and `src/calculator.tcl`/`xschem.tcl`/`ase.tcl` on 0.

`wviewer::plot_signals` takes BOTH channels on its first two lines, before `dict exists $windows $token` -- measured: `plot_signals` against a dead token returns the unknown-window pair AND the arm is gone afterwards. It then pads both lists to `[llength $exprs]` (an empty arm gives every signal `{}`; a short arm cannot hand the tail somebody else's axis) and ends in `wviewer::add_trace $token $gi $ex {} $col $db $sw` -- so ONE `plot_signals` call carries database and X column together.

`add_trace`'s 7th formal only records: `if {[string trim $sweep] ne {}} { dict set trd sweep [string trim $sweep] }` -- absent means absent. `graph_props` is what turns the dict key into the rect token, via `wviewer::sweep_token` (refuses whitespace/quote/backslash) and `wviewer::sweep_default` (the CURRENT database's first raw vector). Emission rule, measured on the committed fixture: 1-trace calc strip -> `sweep="calcx"`; 3-trace mixed with calc in the middle -> `sweep="time calcx time"`; 3 plain traces -> NO TOKEN; calc X name containing a space -> NO TOKEN (the whole list is dropped, never shortened); no database loaded -> NO TOKEN.

== WHICH DOOR J1b CALLS: `plot_dbs_arm` + `plot_sweeps_arm` + `plot_signals`, then `take` BOTH ==
The idiom to copy verbatim is `wviewer::browser_plot_ids`:
    wviewer::plot_dbs_arm $token $dbs
    set rc [catch {wviewer::plot_signals $token $names {} $destover} errs]
    wviewer::plot_dbs_take $token          ;# no-op after a real call; clears after a stub
DECOMMENTED derivation: `plot_dbs_arm` has EXACTLY TWO armers, `browser_plot_ids` and `browser_sea_plot_idx` -- the source comment is right (see `contradictions` for the mistake I made and corrected here).

THREE MEASURED REASONS, in order of force:

1. `plot_dbs_arm` IS MANDATORY, NOT OPTIONAL, AND THIS IS THE FINDING THE CONTRACT DOES NOT HAVE. J1 never drops a destination, so several coexist. Measured: two `calc::wave_dest` calls gave `__calc_dest1` and `__calc_dest2`, and `xschem raw list` on EACH answers the identical `calcx calcy`. An unarmed `add_trace` resolves a bare `calcy` through `wviewer::resolve_signal_db`, which returns the FIRST slot in `signal_list_all` order that has the name (current DB first, then registry order) -- so every measurement after the first silently draws `__calc_dest1`'s curve. That is DEFECT 2's wrong answer one gesture on, and no row anywhere would see it.

2. ONLY `plot_signals` CAN GIVE THE DESTINATION ITS OWN STRIP, and after the `graph_fullxzoom` measurement below it must have one. `plot_signals` runs `plan_plot` (creates strips), `plan_colors`, `dest_prepare`/the window destination policy, and the ONE batch `capture_live_view_state`. `add_trace` creates nothing and clamps an out-of-range `gi` to the LAST strip -- so a direct `add_trace calcy {} {} <dbidx> calcx` stacks the measured trace onto whatever is already there, i.e. builds the mixed-axis strip that auto-X-zoom cannot frame.

3. WHY AN ARM AND NOT A FIFTH PARAMETER -- measured, not argued: `plot_signals` really is 4 formals, BM05 pins the signature as a literal source string, and SIX 4-parameter spy stubs redefine it in `tests/` (derived: test_ase_current_repair, test_calc_plot, test_wave_sigbrowser x2, test_wave_sigbrowser_digital, test_wave_sigbrowser_sea). A 5-arg call raises "too many arguments" into `browser_plot_ids`' own catch, so every gesture check reads as "the gesture did nothing".

== AND THE `take` IS NOT TIDINESS ==
Measured: `plot_sweeps_arm __nope2 {calcx}` with no following `plot_signals` -> `plot_sweeps_take __nope2` still answers `calcx`. An arm whose caller refuses earlier (an empty buffer, `calc::rpn_bad_token`, a `require_result` refusal, a raise) PERSISTS for that token and silently re-axes the NEXT plot in that window. `calc::plot_rpn` has exactly that shape: three refusal returns before its `plot_signals` call.

**sr5_cost**

== THE ROWS, QUOTED (tests/headless/test_calc_scratch_reuse.tcl, band SR5) ==
The derivation, over `$pbody` = the DECOMMENTED body of every `::calc::*` proc (measured: 144 procs):

    set viaviewer {}
    dict for {nm b} $pbody {
        if {[regexp {wviewer::(add_trace|plot_signals)} $b]} { lappend viaviewer $nm }
    }
    check "SR5 ...and the procs that reach the engine through the VIEWER's door instead are Plot's, which is why no R402 delete belongs there" \
        $viaviewer {plot_rpn}

TWO ROWS CARRY IT, NOT ONE. The disjointness row beside it also pins the COUNT as a literal:

    check "SR5 ...and no proc uses BOTH doors -- derived from the two sets, with both counts riding along" \
        [list [llength $adders] [llength $viaviewer] $bothdoors] \
        [list [llength $adders] 1 {}]

Measured today (`ALL PASS (54 checks)`, re-run at HEAD): `adders = {cross wave_dest eval_rpn}`, `readers = {cross eval_rpn}`, `minters = {cross eval_rpn}`, `deleters = {cross eval_rpn}`, `viaviewer = {plot_rpn}`, `persistent = {wave_dest}`, `bothdoors = {}`, disjointness actual `{3 1 {}}`. So a second viewer-door name reddens TWO rows: the one-name literal AND the `1` in the count leg.

== WHAT IT DERIVES, EXACTLY ==
It derives "which `calc::` procs reach the waveform engine through the viewer instead of through `xschem raw add` directly", and it does that so the R402 mint/read/delete equality above it stays honest: `add_trace`'s destination is a PERSISTENT vector minted by `wviewer::auto_expr_name` that the trace keeps reading, so there is nothing to delete and no shared scratch column. The row's job is to say that exemption belongs to exactly one proc and that no proc holds both obligations.

== THE HONEST MOVE ==
The expectation is a one-name literal, but the DERIVATION is itself a hand-kept list of two names -- `wviewer::(add_trace|plot_signals)` -- and that is the defect one level up, which is what must be fixed rather than the expectation bumped to two names.

MEASURED REPLACEMENT, available today: the `wviewer::` procs that DIRECTLY issue `xschem raw add` are `{paste_traces restore add_trace}` -- THREE, and `plot_signals` is NOT one of them (it reaches `add_trace`). A transitive closure over `wviewer::` bodies gives strictly more than two procs that reach one of those three doors; the shipped alternation sees two of them. So:

 * derive the DOOR SET from the tree -- the `wviewer::` procs whose own decommented body reaches `xschem raw add` -- and match ANY member, instead of naming two;
 * assert the resulting `calc::` set with a FLOOR and a non-vacuity leg (`atleast 1` plus `has plot_rpn` plus the door-set count), so J1 b's new name enters by MEASUREMENT and units after it move a name between sets rather than lowering a floor. That is exactly the treatment WD9's keystone got when J1 landed: RE-DERIVED, not decremented.
 * the count leg's literal `1` becomes `[llength $viaviewer]` against the derived set, so it stops being a number to edit.

== AND THE ONE MOVE THAT MUST BE REFUSED ==
MEASURED: `regexp {wviewer::(add_trace|plot_signals)} wviewer::plot_sweeps_arm` answers 0. So a J1b that armed the sweep channel and then plotted through a third route -- `browser_plot_ids`, a new `wviewer::` helper, anything not literally named `add_trace` or `plot_signals` -- leaves SR5 GREEN at `{plot_rpn}` while a second Calculator-to-viewer route exists. Also measured: placing the armer in `::wviewer::` instead of `::calc::` dodges the row entirely, because `$pbody` is built over `[info procs ::calc::*]` only. Both dodges give a row that reads as coverage and is not. Widen the derivation; do not route around the regexp.

Unaffected either way: the `persistent {wave_dest}` row, provided J1b's armer issues no `xschem raw add` of its own -- it must not, `add_trace` does it.

**sweep_carryforward**

== THE MECHANISM, VERIFIED IN THE C SOURCE ==
In `draw_graph` (src/draw.c): `sweep_idx` is initialised to 0 and `sweep_name` to NULL; `my_strdup2` copies the WHOLE `sweep=` value; per node `stok = my_strtok_r(sptr, "\t\n ", "\"", 0, &saves)` and then

    if(stok && stok[0]) sweep_name = stok;
    if(sweep_name && sweep_name[0]) {
      sweep_idx = get_raw_index(sweep_name, NULL);
      if( sweep_idx == -1) sweep_idx = 0;
    }

`my_strtok_r` answers NULL once the list is exhausted, the guard means `sweep_name` KEEPS the previous name, and the index is re-resolved from it. Never reset. An ABSENT list leaves `sweep_name` NULL and every trace on column 0 of its own per-node database -- a different and louder failure, exactly as claimed.

== THE WALKER LIST, DERIVED -- AND IT IS SIX, NOT SEVEN ==
One awk pass over `src/*.c` mapping every line that reads the `sweep=` token (or names `sweep_name`) to its enclosing symbol, then each site read:

 SIX carry forward, with the guarded `sweep_name = stok` idiom (every one guarded; I checked each after an earlier scan made four look bare):
   `graph_fullyzoom`, `find_closest_wave`, `graph_point_at`, `wave_hilight_envelope`, `graph_wave_resolve`, `draw_graph`.

 `graph_fullxzoom` DOES NOT. It reads `find_nth(get_tok_value(r->prop_ptr, "sweep", 0), ", ", "\"", 0, 1)` -- the FIRST token, once -- and passes that single name to `graph_x_union_rect`/`graph_x_extent` for the whole rect AND the whole shared-X group. Its own comment says so: "ONE x quantity for the whole union, and it is the TARGET rect's".

 TWO MORE READERS ARE IN NEITHER LIST, both in src/callback.c, both first-token-only with a silent `if(idx < 0) idx = 0`: `backannotate_cursor_b_in_db` (the cursor-B backannotation to the schematic) and `waves_callback`'s Button2 drag-to-position arm. Population of `sweep=` readers: NINE, in three families -- 6 carry-forward, 3 first-token-only.

== BEHAVIOURAL CONFIRMATION, HEADLESS, NO PIXELS ==
Fixture `tests/headless/data/calc_fixture.raw` read as `tran`, plus one added column `tshift = {time 1e-3 +}`; a 3-trace graph rect `node="v(sq)\nv(ramp)\nv(div)"`; the X read back through `xschem graph_marker add_at 0 <wave> 0 5` + `xschem graph_marker list 0` field 5, i.e. `graph_marker_sample` -> `graph_wave_resolve`:

    sweep="time tshift time"   ->  x(w0,w1,w2) = 0.0005  0.0015  0.0005    CORRECT
    sweep="time tshift"        ->  x(w0,w1,w2) = 0.0005  0.0015  0.0015    <-- w2 SILENTLY RE-AXED
    sweep absent               ->  0.0005  0.0005  0.0005                  (column 0)
    sweep="tshift tshift"      ->  0.0015  0.0015  0.0015
    sweep="tshift"             ->  0.0015  0.0015  0.0015

And `graph_fullxzoom`, measured separately with `xschem setprop rect 2 0 fullxzoom`:

    sweep={}                   ->  x1,x2 = 0, 0.01        (time)
    sweep={tshift time time}   ->  x1,x2 = 0.001, 0.011   (FIRST token wins for the whole rect)
    sweep={time tshift time}   ->  x1,x2 = 0, 0.01        (the tshift trace's extent never enters)

== CAN J1b TRIP IT?  MEASURED: NOT THROUGH THE PRODUCT, AND THE CONTRACT'S FRAMING IS OVERSTATED ==
Two independent reasons, both measured:
 (a) `graph_props` emits the list IN FULL OR NOT AT ALL -- `if {$swany && [llength $swtoks] && [lsearch -exact $swtoks {}] < 0}`. Re-measured: mixed strip -> 3 tokens for 3 traces; plain strip -> none; unsafe X name -> none. WD4 pins that, and a short list cannot come out of the generator.
 (b) THE DESTINATION MAKES IT MOOT. `calc::wave_dest` builds its database with `xschem raw new <name> table $xname 0 [expr {$n-1}] 1`, so `calcx` is COLUMN 0 (measured `col0-is-xname = 1` for both destinations). Since `sweep_idx` starts at 0, the calc trace draws against its own X even with NO `sweep=` token at all. The token is belt-and-braces for this destination shape; what is load-bearing is the `%<db> table` suffix `wviewer::db_suffix` emits.
J1b trips the carry-forward only if it writes a rect token itself with `xschem setprop rect 2 <i> sweep ...` instead of going through `graph_props`. It must not.

THE THREE DEFECTS THAT ARE ACTUALLY LIVE FOR J1b, all measured, none of them this one: (1) no `plot_dbs_arm` -> the wrong destination drawn through the `calcy` name collision; (2) `graph_fullxzoom` on a mixed strip ignoring the destination's extent, which is why the destination needs its OWN strip; (3) an unconsumed arm leaking the calc X axis into the next plot in that window.

== WHAT A FENCE WOULD HAVE TO DO ==
A pixel fence reaches only `draw_graph`. But a fence over the other five is not available either -- I measured each door with no display:
   `graph_wave_resolve`      `xschem graph_marker add_at` + `graph_marker list`   -> WORKS AND DISCRIMINATES (table above)
   `find_closest_wave`       `xschem get graph_closest_wave <gi> <px> <py>`       -> answered `{-1 -1}` (no window transform)
   `graph_point_at`          `xschem get graph_wave_at <gi> <px> <py> <tol>`      -> answered `{}`
   `wave_hilight_envelope`   `xschem get wave_hilight_points <gi> <ni>`           -> answered 0 (needs a real canvas despite its own build-under-nogui note)
   `graph_fullyzoom`         `xschem setprop rect 2 <i> fullyzoom`                -> runs; the sweep reaches only its custom-data arm
   `draw_graph`              needs a canvas
So the fence shape is: KEEP WD4's positive-shape assertion upstream of all nine readers -- one token per emitted trace, in node order, never short, and the ordinary token READ out of the current database rather than hardcoded (that is WD4's `ac` row, which exists because `set swdflt time` passed every other row on the `tran` fixture) -- and ADD ONE behavioural witness through the single door that is both headless and discriminating, the marker readback above, with a mixed strip whose special trace is NOT LAST (in last position there is no later trace for the carried token to re-axe). That turns WD4 from a claim about a string into a measured claim about an axis. The three first-token-only readers are a DIFFERENT defect that no carry-forward fence touches, and `graph_fullxzoom`'s is user-visible: see `traps`.

**arity_pins**

RUN, with `info args` against the live namespace inside `./src/xschem --nogui --pipe`:

    ::wviewer::plot_signals     4 formals  {token exprs colors destover}
    ::wviewer::graph_props      3 formals  {G active grid}
    ::wviewer::add_trace        7 formals  {token gi rpn name color db sweep}
    ::wviewer::plot_sweeps_arm  2 formals  {token sweeps}
    ::wviewer::plot_sweeps_take 1 formal   {token}
    ::wviewer::plot_dbs_arm     2 formals  {token dbs}
    ::wviewer::plot_dbs_take    1 formal   {token}

The three gate-relevant legs, computed exactly as the rows compute them:
    GT8 leg (test_wave_grid)          -> `3 grid`
    WD4 add_trace leg                 -> `7 sweep db`
    WD4 three-proc leg                -> `{3 grid 4 1 1}`
All three pass at HEAD.

PLOT_SIGNALS' 4 IS PINNED THREE WAYS, and the third is the one that bites. (a) BM05 of test_wave_sigbrowser.tcl matches a LITERAL SOURCE STRING: `[string first "proc wviewer::plot_signals {token exprs {colors {}} {destover {}}}" $wsrc] >= 0`. (b) BM05 also pins `browser_plot_ids`' call as `wviewer::plot_signals $token $names {} $destover` exactly once. (c) SIX 4-PARAMETER SPY STUBS redefine it, derived over `tests/` rather than counted from the comment: `test_ase_current_repair.tcl`, `test_calc_plot.tcl`, `test_wave_sigbrowser.tcl` (TWO, in different bands), `test_wave_sigbrowser_digital.tcl`, `test_wave_sigbrowser_sea.tcl` -- six stubs across five files. A 5-arg call raises "too many arguments" into `browser_plot_ids`' own `catch`, which SWALLOWS it, so every browser gesture check reads as "the gesture did nothing" rather than as an error.

GRAPH_PROPS' 3 is pinned by GT8 of test_wave_grid.tcl (`[llength [info args wviewer::graph_props]] == 3 && [lindex ... 2] eq {grid}`, with GT9 pinning `grid`'s default of 1) and re-measured by WD4.

DOES J1b MOVE ANY?  NO -- and not moving them is the entire reason the armed one-shot channel exists. The route is `plot_dbs_arm` + `plot_sweeps_arm` + the existing 4-formal `plot_signals` + the existing 7-formal `add_trace`; zero signature changes, zero new formals anywhere.

⚠ A REGISTRATION FINDING THE CONTRACT ONLY HALF-STATES, AND IT MAKES WD4 LOAD-BEARING RATHER THAN A REMARK. I extracted the three case lists from `tests/run_regression.tcl` with a bracket walk (tcases 3, hcases 96, dcases 25 -- which reconciles with CLAUDE.md's `cases=124`): `test_wave_grid` and `test_wave_sigbrowser` are in NEITHER list. So GT8 and BM05 GATE NOTHING -- they are only reachable through `full_audit.sh`. The ONLY gate-visible re-measurement of either arity is WD4's three-proc leg, in `test_calc_wave_dest`, `hcases`. WIRING_CONTRACT section 6's "the one gate-visible arity pin among the three" is correct; what it does not say is that the other two are unregistered, so a J1b that changed a signature would get a green gate and a red `full_audit.sh`.
Same shape for the walker-count fence: `test_node_token_split.tcl`, whose rows NDR2/NDR3 re-measure the seven-walker figure every run, is also in neither list.

Registration of the suites that matter here, measured: hcases (counted) = test_calc_engine, test_calc_scratch_reuse, test_calc_cross, test_calc_measure, test_calc_wave_dest. dcases ALONE = test_calc_skeleton, test_calc_widgets, test_calc_buffer, test_calc_plot, test_wave_viewer, test_wave_sigbrowser_panes.

SUITES RUN AT HEAD, armed spelling, `env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_scratch_reuse test_calc_measure`:
    PASS | test_calc_wave_dest       RESULT: ALL PASS (102 checks)
    PASS | test_calc_scratch_reuse   RESULT: ALL PASS (54 checks)
    PASS | test_calc_measure         RESULT: ALL PASS (170 checks)
    RESULT: 3/3 runs passed
No full T1 run; no display-arm run; the `~/gc26` gate clone untouched.

**display_arm_sites**

== CLAIM 1: THE RPN BUFFER IS REALLY LEFT UNTOUCHED ==
BAND: S28/4 of tests/headless/test_calc_skeleton.tcl (`dcases` alone; the suite reports `ALL PASS (0 checks)` under --nogui).
IDIOM TO COPY: S28/4's whole fixture, and three parts of it are non-negotiable. (a) `rename ::calc::dutyCycle_scalar` to a RECORDER whose formals are DERIVED with `info args` of the real proc, each given a sentinel default -- S28/4's own comment records that a `{args}` stub makes `info args` answer the single word `args`, no formal matches a dialog key, `calc::arg_values` composes NOTHING, and the row then reds against correct code. (b) `rename ::calc::require_result` to answer `ok`, because the gate runs BEFORE the dialog and every dialog row would otherwise measure a refusal. (c) `ad_arm`'s poll, which waits for `[winfo exists .calc.arg] && [grab current] eq {.calc.arg}` -- a bare `grab current` tested for non-emptiness is satisfied by any unrelated grab and fires during the build's own `update` (sabotage S28/B).
CAN OBSERVE: `ad_buf` = `.calc.buf get 1.0 end-1c` before and after; `edit modified`; `edit canundo`/`canredo`; the status history; `.calc.status.msg get`; the Stack size -- i.e. S28/3's five Cancel captures, which is the right shape here because nothing should move.
CANNOT OBSERVE: anything needing a real database. The recorder returns a fabricated dict, so the `db` value is a fixture string and a viewer arm reached from it would try to plot a database that does not exist -- the viewer arm must be stubbed out in this band or it will raise.

== CLAIM 2: THE SENTENCE REALLY REACHES `.calc.status.msg` ==
BAND: S28/4 again, through `[pcall .calc.status.msg get]`.
WHAT IS ALREADY FENCED ELSEWHERE, so J1b need not re-measure it: `.calc.status.msg` is pinned as an `Entry` with `-state readonly` by band W33 of test_calc_widgets.tcl, and R507's rows in the same file drive `calc::status` and read `get` back ("...and the field shows it", "...clears the field"). The generic delivery path is covered. What J1b adds is that the DESTINATION sentence arrives from a real CLICK, which is S28's shape and nobody else's.
EXTRA WITNESS J1b GETS FOR FREE: on the destination arm `calc::fn_measure` ends `return [calc::status [calc::arg_msg destination $name $db]]`, so the sentence IS the click's return value. The row can require the return value and `.calc.status.msg get` to AGREE -- a mismatch is precisely the stale-status-line symptom described below.

== WHY S28/4 RIDES `calc::fn_click`'s OWN RETURN VALUE, AND WHETHER IT APPLIES ==
The leg is `[expr {[string match ERR:* $ad_clickans] ? 0 : 1}]` where `$ad_clickans` is `[pcall calc::fn_click cross]`. Its own comment gives the reason, measured while proving the band could pass: a conforming reference composed R421's provenance as a double-quoted `"$name(...)"`, which in Tcl is an ARRAY ELEMENT reference -- `can't read "name(...)": variable isn't array` -- so the number reached the buffer, the status line kept the PREVIOUS sentence, and the click RAISED into `pcall`. Without the leg the row above would have blamed the sentence rather than the raise. (That is why `calc::arg_provenance` is built with `append`, not interpolation.)
IT APPLIES TO J1b, AND MORE STRONGLY. The viewer arm is NEW code on that path with three things that can raise -- `wviewer::current_token`/`window_for`, the `plot_signals` call, and the `take` -- and the existing `calc::plot_rpn` precedent wraps its seam in `catch` for exactly this reason. So the return-value leg is a raise detector where one is newly needed, and here it doubles as the second independent witness for claim 2.

== CLAIM 3: THE UNDO IS STILL ONE STEP ==
BAND: S28/4's undo witness (`pcall calc::buf_undo` / `pcall calc::buf_redo` around `ad_buf`).
⚠ BUT THE CLAIM INVERTS FOR A WAVE, and writing it as "one undo restores" would be asserting the wrong thing: nothing was pasted, so there is no new undo step to collapse. The correct assertion is that the undo/redo STATE IS UNCHANGED across the click -- `edit canundo` and `edit canredo` through `calc::buf_can` (whose only two sites CB2 of test_calc_buffer.tcl pins as exactly `{::calc::buf_can ::calc::edit_can_probe}`), `edit modified`, and the buffer text. That is S28/3's Cancel idiom, not S28/4's one-undo idiom, and both already exist in the same band.

== ⚠ CORRECTION: CW14 CANNOT HOST ANY OF THE THREE ==
Band CW14 of test_calc_widgets.tcl is a WIDGET INVENTORY band and says so in its own declared holes. WH2: "NOTHING HERE DRIVES THE MODAL. No `grab`, no `tkwait`, no Cancel, no OK: band S28 ... owns all of it ... A green run here says the dialog is BUILT right, not that it BEHAVES right." It deliberately builds through `calc::arg_dialog_build` and never `calc::arg_dialog`, which is exactly why it cannot hang -- and exactly why it cannot see a click, a buffer edit, an undo or a status sentence. CW14 can own only a widget claim, and J1b adds no widget: zero new `-command`, so CW13's control sweep holds unchanged (the J1 verifier measured that mechanically). ALL THREE ACTS ARE S28's. The brief and both J1 receipts name CW14 as a home for one of them; measured, it is not one.

== ⚠ AND THE SITE NOBODY NAMES, WHICH IS THE BEST HOME FOR THE VIEWER HALF ==
tests/headless/test_calc_plot.tcl, `dcases` ALONE. It already opens a REAL viewer window (fixture PL0: `check "PL0 fixture: wviewer::open returns 1" [pcall wviewer::open $::tok] 1`, then `wviewer::window_for`), already carries `ngraphs`, `alltraces` and `tracevecs` readers over the live layout, and already renames `wviewer::plot_signals` for band PL5c. A row there can build a real destination with `calc::wave_dest`, drive the arm, and then read `[dict get $tr sweep]`, `[dict get $tr rawfile]`, `[dict get $tr sim_type]` and `[dict get $tr vec]` off the REAL trace dict, run `wviewer::graph_props` over the real strip, and -- with a window -- take the marker readback.
IT HAS TO BE THERE, because `wviewer::signal_list_all` returns `{}` unless `dict exists $windows $token`, so `wviewer::db_by_index` answers `{}`, so `add_trace`'s named-database arm is UNREACHABLE headless. That is hole H3, and it means "a trace appears against its own X" is observable in exactly one registered suite and it is not one of the two the brief names.

**undo_mechanism**

== WHERE IT IS: `calc::buf_set_number` IN src/calculator.tcl, AND IT IS THE WHOLE OF R421 PART 3 ==

    proc calc::buf_set_number {v} {
        if {![calc::has_win .calc.buf]} { return {} }
        set n [string trim $v]
        set auto 1
        catch {set auto [.calc.buf cget -autoseparators]}
        catch {.calc.buf configure -autoseparators 0}
        .calc.buf edit separator
        .calc.buf delete 1.0 end
        .calc.buf insert end $n
        .calc.buf edit separator
        catch {.calc.buf configure -autoseparators $auto}
        catch {.calc.buf see insert}
        calc::buf_note_edit
        return $n
    }

== WHAT MAKES IT ONE STEP RATHER THAN TWO ==
`-autoseparators` is turned OFF ACROSS THE PAIR. With it on -- Tk's default, and what `calc::build_buf` leaves alone -- Tk inserts a separator of its own whenever the edit MODE changes, so the `delete` and the `insert` land in two different undo steps: one undo leaves the buffer EMPTY and a second is needed to get the expression back. The two EXPLICIT `edit separator` calls either side are what make the pair one step once Tk has stopped adding its own. The proc's own comment records the sabotage that proves it: leaving `-autoseparators` on reddens exactly one row, S28/4's undo witness, with the undone buffer reading empty.
The previous setting is read with `cget` and PUT BACK rather than assumed to be 1, because `calc::buf_undo` branches on it and a window configured otherwise must not be changed by a measurement. (Note the standing constraint: `cget` accepts abbreviations, so a shortened spelling here would still work and would still be wrong to write.)

== WHAT A WAVE ANSWER MUST AVOID TOUCHING ==
All of it, and it already does: `calc::fn_measure`'s destination arm returns before `set num [calc::buf_set_number $v]` is ever reached. Measured structurally today over decommented bodies -- `autoseparators` occurrences: `calc::buf_set_number` 3, `calc::fn_measure` 0, `calc::status` 0, `calc::fn_sink` 0, `calc::fn_click` 0.
Concretely a J1b viewer arm must not call `calc::buf_set_number`, and must not touch `.calc.buf` at all -- no `insert`, no `delete`, no `edit reset`, no `edit separator`, no `configure -autoseparators`, no `edit undo/redo`.
⚠ AND IT MUST NOT CALL `calc::buf_note_edit`, OR ANYTHING THAT REACHES IT, which is the trap a "refresh the buttons after plotting" line would walk into:

    proc calc::buf_note_edit {} {
        variable fbundo
        variable fbredo
        if {![calc::has_win .calc.buf]} return
        set fbundo 1
        set fbredo 0
        calc::buf_sync
    }

Those two variables are the Tk-8.5 fallback hints `calc::buf_can` reads when `calc::edit_can_probe` is false. A wave answer that called it would claim "an undo is available, no redo" after changing nothing -- the user's undo HINTS moved while their undo HISTORY did not. That is R505 backwards, it is INVISIBLE on Tk 8.6 (where `buf_can` reads the real stack), and the band that would catch it is CB2 of test_calc_buffer.tcl -- `dcases` alone.

== WHAT IS ALREADY FENCED ON THE COUNTED ARM ==
MT12 of test_calc_measure.tcl pins the structural half in one walk over the namespace: every `::calc::` proc whose decommented code names `calc::buf_set_number` also names `calc::fn_sink`. Measured on the delivered tree: `pasters = askers = {fn_measure}`. So a second paster added later cannot hide, and the sabotage `R_unasked` (the router written, `fn_measure` still ending unconditionally in the paste) reddens that one row naming `fn_measure`. The ACT -- that the widget's history is really untouched -- stays display-only.


### traps

- ⚠⚠ THE WORST ONE, AND NOBODY HAS NAMED IT: WITHOUT `plot_dbs_arm` THE WRONG DESTINATION IS DRAWN, SILENTLY AND FOREVER. Measured -- two `calc::wave_dest` calls gave `__calc_dest1` and `__calc_dest2`, and `xschem raw list` on EACH answers the identical `calcx calcy`. J1 never drops a destination, so coexistence is the normal case. An unarmed `add_trace` resolves a bare `calcy` through `wviewer::resolve_signal_db`, which returns the FIRST slot in `signal_list_all` order that has the name -- current DB first, then registry order -- so every measurement after the first plots the FIRST one's curve. A J1b that armed only the sweep channel would pass any single-measurement row and be wrong on the second click. Arm BOTH channels.

- ⚠ AN ARM THAT NEVER REACHES `plot_signals` PERSISTS AND RE-AXES THE NEXT PLOT. Measured: `plot_sweeps_arm __nope2 {calcx}` with no following call -> `plot_sweeps_take __nope2` still answers `calcx`. `calc::plot_rpn` has three refusal returns before its `plot_signals` call, and J1b will have at least as many (no window, no token, a `wave_dest` refusal, a raise). Copy `browser_plot_ids` exactly: arm, `catch` the call, then `take`-and-discard UNCONDITIONALLY -- the comment there says why, 'no-op after a real call; clears after a stub'.

- ⚠ AUTO-X-ZOOM CANNOT SIZE A MIXED STRIP, BY DESIGN, SO A MEASURED TRACE STACKED WITH ORDINARY ONES CAN BE DRAWN OFF-WINDOW. Measured: `sweep={time tshift time}` -> fullxzoom frames 0..0.01, the `tshift` extent never entering the union; `sweep={tshift time time}` -> 0.001..0.011. `graph_x_extent` contains `if(idx < 0) return 0;` with the comment 'A database that does not HAVE the target strip's x quantity has no extent IN that quantity, so it contributes nothing' -- so on a mixed strip the destination contributes NOTHING to the X union. Worse, `graph_shares_x` groups rects by matching `sim_type=` tokens and `graph_props` emits NO `sim_type` token at all, so every viewer strip is in one shared-X group and the gesture's master decides the window for all of them. The implication for J1b: the destination wants its OWN strip, which is a reason to go through `plot_signals` (which creates strips) rather than `add_trace` (which does not).

- A ROW THAT PASSES VACUOUSLY, SHAPE 1 -- THE SPECIAL TRACE IN LAST POSITION. WD4's own comment says it: in last position the carry-forward is invisible, because there is no later trace for the carried token to re-axe. Any new behavioural row must put the measured trace in the MIDDLE, and must use a 5-trace strip as well as a 3-trace one, or it is measuring a three-element coincidence.

- A ROW THAT PASSES VACUOUSLY, SHAPE 2 -- EVERY ROW DRIVING THE `tran` FIXTURE. WD4 already carries the scar: `set swdflt time` in `wviewer::graph_props` -- hardcoding the ordinary trace's X name -- gave `ALL PASS` on every row in the band, because the `tran` fixture's own first raw vector IS `time`. `wd_load1ac` exists for exactly one row. Anything J1b asserts about a resolved X name needs the `ac` arm too, where the sweep is `frequency`.

- A ROW THAT PASSES VACUOUSLY, SHAPE 3 -- A `graph_props` ROW ON A DESTINATION-ONLY STRIP. Measured: a 1-trace calc strip emits `sweep="calcx"`, count 1, so 'the count equals the trace count' is trivially true there. The discriminating case is the MIXED strip (`time calcx time`) and the plain strip (NO token), and all three shapes have to be in the row or the count claim says nothing.

- ⚠ THE `sweep=` TOKEN IS BELT-AND-BRACES FOR THIS DESTINATION, SO A ROW THAT ONLY CHECKS THE DRAWN X CANNOT TELL ARMED FROM UNARMED. `calc::wave_dest` builds with `xschem raw new <name> table $xname 0 (n-1) 1`, so `calcx` is COLUMN 0 (measured for both destinations), and `sweep_idx` initialises to 0 -- so the calc trace draws against its own X even with NO token at all. The thing that genuinely has to be right is the `%<db> table` suffix. A J1b row must assert the trace's `sweep`, `rawfile` and `sim_type` keys AND the emitted token, not just the X it ends up on.

- `wviewer::sweep_token` SILENTLY REFUSES a name containing whitespace, a quote or a backslash, and `graph_props` then drops the WHOLE token list (measured: an X name of `my x` -> no `sweep=` at all). `calc::wave_dest` refuses only an empty or duplicate `xname`, never an unsafe one. Harmless today because nobody passes `xname`; a live hazard the moment the destination's unruled user-visible NAME becomes settable.

- S28/4's STUB TRAP, in its own words: a stub declared `{args}` makes `info args` answer the single word `args`, no formal matches a dialog key, `calc::arg_values` composes NOTHING, and the row reds against correct code. A J1b stub of `calc::dutyCycle_scalar` must carry the real proc's formals, derived with `info args`, each with a sentinel default so the recorder reports the arguments ACTUALLY passed.

- A STUBBED S28 WAVE ANSWER CARRIES A FABRICATED `db`, SO AN UNSTUBBED VIEWER ARM WILL CHASE A DATABASE THAT DOES NOT EXIST. S28 has no loaded raw at all (`calc::require_result` is itself stubbed). Either stub the arm in that band, or put the trace-appears claim in `test_calc_plot`, which has a real window and can build a real destination.

- ⚠ `calc::arg_surface` SILENTLY REDIRECTS: it is literally 'if `::calc::${name}_scalar` exists, return it.' `dutyCycle_scalar` already exists, so a J1b stub must rename THAT and not `calc::dutyCycle` -- and MT10's callee-ward closure row reddens with `{{} {} wave_dest}` if the wiring ever moves into the verb (sabotage `W_verbwired`, measured by the J1 implementer at `2 FAILED (100 passed)`).

- DO NOT 'SIMPLIFY' EITHER ARM INTO A PARAMETER. Measured: `plot_signals` is 4 formals pinned as a literal source string by BM05 plus SIX 4-parameter spy stubs; `graph_props` is 3 pinned by GT8. A 5-arg `plot_signals` call raises 'too many arguments' into `browser_plot_ids`' own `catch`, which swallows it, so every browser gesture check reads as 'the gesture did nothing'.

- AND THE PINS THAT WOULD CATCH THAT ARE NOT IN THE GATE. `test_wave_grid` (GT8) and `test_wave_sigbrowser` (BM05) are in neither `hcases` nor `dcases` -- derived, not read. Only WD4 re-measures both arities in a gated suite. A broken signature gives a GREEN gate and a red `full_audit.sh`.

- A FENCE KEYED TO THE CARRY-FORWARD SYMPTOM WILL DIE QUIETLY. `graph_props` already refuses to emit a short list, so a row asserting 'no re-axing happens' is asserting the absence of something the generator cannot produce. Assert the POSITIVE shape (one token per trace, in node order, read out of the current database) plus one behavioural witness, which is what WD4 does and why.

- ⚠ `test_calc_skeleton` reports `ALL PASS (0 checks)` under `--nogui` and `test_calc_widgets` a no-X skip, so a headless number says NOTHING about half (B). And `test_calc_plot` was MEASURED into `dcases` rather than reasoned into it -- `tests/banner_rule.tcl` gives `banner_complete=1` on its display arm and `regression_case_failed(0)=1` on its `--nogui` arm, so an `hcases` entry for it would be a standing red. Any new display-only row goes into a suite that is already `dcases`; do not add an arm.

- ⚠ A `switch` COMMENT IS PARITY-DEPENDENT AND `info complete` CANNOT SEE IT. If J1b touches `calc::arg_msg` again (ten arms today, derived), prose goes ABOVE the proc. MT12's arm sweep is the only behavioural confirmation and it is a DERIVATION over the proc's own switch patterns -- a green run proves only that the word count is even.

- A CHECK NAME IS A DOUBLE-QUOTED WORD. The J1 guard crew wrote a row name quoting the rejected `[llength $value] > 1` spelling and it was COMMAND SUBSTITUTION; they re-spelled it as prose. Keep `[` and `$` out of every row name.

- A ROW MUST FAIL, NOT THROW. Both Calculator suites carry the file-scope `catch ... bigerr` structure; issue 1616's incident aborted a suite at 62 of 402 checks. Route every product call through `pcall`/`wd_wv`-style wrappers that turn a raise into a legible sentinel. `wd_wv` already answers `NOPROC:`/`NOARITY:`/`RAISED:` for a `::wviewer::` verb -- reuse it rather than writing a third one.

- DO NOT ASSERT THE DESTINATION'S NAME, THE COLUMN NAMES OR THE SENTENCE WORDS. `__calc_dest<N>`, `calcx`, `calcy` and all three new `arg_msg` sentences are UNRATIFIED user-visible text with an open `rule` debt. Every existing row reads them OUT of the answer and matches `db` against a GLOB. The serial also advances with earlier bands, so a literal would be order-dependent as well as pre-emptive.

- `calc::wave_dest_restore` PUTS BACK ONE HALF OF A REGISTRY CURSOR THAT IS A PAIR, so `xschem raw switch_back` after a successful destination lands ON THE DESTINATION. Pre-existing, excluded from every key set and every row on purpose. A J1b row that issued `switch_back` or read `prev`/`prevtype` would be RED ON CORRECT CODE.

- A BARE `xschem raw switch <name>` IS ROUND-ROBIN, NOT 'silently slot 0'. Re-measured twice by earlier crews: rc 1 from every slot, landing (cur+1) mod n. A restore fence written from DESTINATION_CONTRACT section 7's account PASSES ON A TWO-SLOT FIXTURE. Use three loads with the user on a non-zero slot (`wd_load3t`).


### contradictions

- ⚠⚠ WIRING_CONTRACT.md section 7.4 -- `'draw_graph`'s local `sweep_name` carries the last non-empty token forward ... and ALL SEVEN walkers do it'` -- IS WRONG, AND SO IS THE SHIPPED COMMENT ABOVE `wviewer::graph_props` THAT IT COPIES (`'⚠ ALL SEVEN WALKERS CARRY THE TOKEN FORWARD, each with its own copy of the idiom -- graph_fullxzoom, graph_fullyzoom, ...'`). Derived over src/*.c and then each site read: SIX carry forward with the guarded `sweep_name = stok` idiom (`graph_fullyzoom`, `find_closest_wave`, `graph_point_at`, `wave_hilight_envelope`, `graph_wave_resolve`, `draw_graph`). `graph_fullxzoom` -- the FIRST name in the list -- does not: it reads `find_nth(get_tok_value(r->prop_ptr, "sweep", 0), ", ", "\"", 0, 1)`, the FIRST token only, once, for the whole rect AND the whole shared-X group, exactly as its own comment says ('ONE x quantity for the whole union'). Measured: `sweep={tshift time time}` -> fullxzoom frames 0.001..0.011; `sweep={time tshift time}` -> 0..0.01. The same wrong sentence is in DESTINATION_CONTRACT.md section 9 and in test_calc_wave_dest.tcl's WD4 band comment -- FOUR copies.

- ⚠⚠ AND THE POPULATION IS NINE, NOT SEVEN. Two more readers of the `sweep=` token are named in NO list anywhere: `backannotate_cursor_b_in_db` and `waves_callback`'s Button2 drag-to-position arm, both in src/callback.c, both `get_raw_index(find_nth(get_tok_value(r->prop_ptr, "sweep", 0), ", ", "\"", 0, 1), NULL)` with a silent `if(idx < 0) idx = 0`. Those are the cursor-B backannotation to the schematic and the strip's mouse-to-X mapping -- two user-visible surfaces missing from the stated blast radius. Three of the nine are first-token-only and are a DIFFERENT defect that no carry-forward fence touches.

- ⚠⚠ AND THIS WAS ALREADY MEASURED AND THE CONTRACT LOST IT. `doc/claude/calculator_batch/receipts/J-wiring-recon-contract.md` states both findings exactly -- nine readers, three first-token-only, six carry-forward, and the mixed-strip fullxzoom consequence -- and calls the contract's sentence 'WRONG TWICE'. WIRING_CONTRACT.md section 10 is the section that exists to record that crew's corrections, and it carries six of them and NOT this one; section 7.4 still reads 'all seven walkers do it' with no correction beside it. A correction that was measured and then dropped out of the contract crews are told to read first is worse than one never made.

- ⚠ THE 'SEVEN' IS RIGHT ABOUT A DIFFERENT PREDICATE, WHICH IS WHY IT SURVIVED. Rows NDR2/NDR3 of tests/headless/test_node_token_split.tcl assert that all SEVEN `node=` walkers that SAMPLE a database resolve the sweep column BY NAME and clamp it against the switched-in `nvars` -- and that IS seven, because `graph_fullxzoom` resolves per contributing database inside `graph_x_extent`. The contract took a correct count attached to 'resolves by name' and reused it for 'carries the token forward'. That is the `grep -c '#pragma'` failure again: a figure that survives because nobody re-derives the predicate behind it.

- ⚠ THE TASK BRIEF AND BOTH J1 RECEIPTS SAY BAND CW14 OF test_calc_widgets.tcl IS A HOME FOR ONE OF HALF (B)'s THREE CLAIMS. It cannot be. CW14's own declared hole WH2 says 'NOTHING HERE DRIVES THE MODAL. No `grab`, no `tkwait`, no Cancel, no OK ... A green run here says the dialog is BUILT right, not that it BEHAVES right' -- it builds through `calc::arg_dialog_build` and never `calc::arg_dialog`, which is exactly why it cannot hang and exactly why it cannot see a click, a buffer edit, an undo or a status sentence. All three acts are S28's, and CW14 owns nothing new because J1b adds no widget and no `-command`.

- ⚠ AND THE SITE THAT CAN ACTUALLY WITNESS THE VIEWER HALF IS NAMED NOWHERE: tests/headless/test_calc_plot.tcl, `dcases` alone, which already opens a real viewer window (fixture PL0), already has `ngraphs`/`alltraces`/`tracevecs` over the live layout, and already renames `wviewer::plot_signals`. It HAS to be there: `wviewer::signal_list_all` returns `{}` unless `dict exists $windows $token`, so `db_by_index` answers `{}` and `add_trace`'s named-database arm is unreachable headless. 'A trace appears against its own X' is observable in exactly one registered suite, and neither of the two the brief names is it.

- ⚠ THE TASK BRIEF'S FRAMING OF THE CARRY-FORWARD AS 'the defect most likely to make J1b silently wrong' IS OVERSTATED, measured two ways. `graph_props` emits the token list in full or not at all (re-measured over three strip shapes; WD4 pins it), so the product cannot produce a short list; and `calc::wave_dest` makes `calcx` COLUMN 0 of its own database (`xschem raw new <name> table $xname 0 (n-1) 1`, measured `col0-is-xname = 1` for both destinations), so with `sweep_idx` initialising to 0 the calc trace draws against its own X even with no token at all. The three defects that ARE live are the missing `plot_dbs_arm` name collision, `graph_fullxzoom` on a mixed strip, and an unconsumed arm -- none of them the carry-forward.

- ⚠ test_node_token_split.tcl's own comment says 'NDU1-NDU5 can only reach four of the six walkers from Tcl (draw_graph needs a canvas, graph_wave_resolve needs a marker drag)'. `graph_wave_resolve` needs no drag: `xschem graph_marker add_at <gi> <wave> <dset> <point>` reaches it through `graph_marker_create_at` -> `graph_marker_sample`, headless, and `xschem graph_marker list <gi>` hands back the resolved X. That is how I measured the carry-forward, and it is the same door test_divis_zero_1628 already uses. The sentence is stale or narrower than it reads.

- ⚠ I MADE THE SAME CLASS OF MISTAKE MYSELF AND AM REPORTING IT BECAUSE IT IS THE LESSON: my first derivation of `plot_dbs_arm`'s armers answered THREE (`browser_sea_send_to_add_trace`, `browser_plot_ids`, `browser_sea_plot_idx`) and I was about to file the source comment's 'EXACTLY TWO CALLERS ARM IT' as a contradiction. It is not. I had scanned RAW `info body` text; `browser_sea_send_to_add_trace` names `plot_dbs_arm` only inside a comment ('exactly as the sibling `Plot` entry arms `plot_dbs_arm`') and actually arms `atd_db_arm`. Re-run DECOMMENTED: two armers, and the source comment is correct. Any J1b derivation over bodies must decomment first -- which is what SR5, WD9 and MT12 all already do.

- STALE PUBLISHED FIGURES, re-measured at HEAD and confirmed stale -- all previously named by the J1 crews and still unedited: WIRING_CONTRACT.md section 2 says `calc::wave_dest` is 'gated at 90 checks' (it is 102); section 5's cost table says `test_calc_wave_dest ALL PASS (90)` and `test_calc_measure ALL PASS (160)` (102 and 170) and never mentions 170 at all; tests/run_regression.tcl's registration comment for test_calc_wave_dest says 'both arms of that suite run the identical 88 checks' (102, and the SHAPE claim is still true). Measured this session: `ALL PASS (102 checks)` / `ALL PASS (54 checks)` / `ALL PASS (170 checks)`. Per CLAUDE.md the fix for the run_regression.tcl one is to DROP the number rather than update it.

- ⚠ WIRING_CONTRACT.md section 6 calls WD4 'the one gate-visible arity pin among the three' and is RIGHT, but does not say why that matters: `test_wave_grid` (GT8) and `test_wave_sigbrowser` (BM05) are registered in NEITHER `hcases` NOR `dcases` -- derived by extracting the three lists from tests/run_regression.tcl (tcases 3, hcases 96, dcases 25, reconciling with CLAUDE.md's `cases=124`). So the two suites that OWN the arity pins gate nothing, and a J1b that changed a signature would get a green gate and a red `full_audit.sh`. `test_node_token_split.tcl`, which re-measures the seven-walker count every run, is also unregistered -- which is part of why the wrong 'seven' persisted.



## suite:j1b

**check_counts**

COMMANDS, run from the repo root. Every figure below was RE-DERIVED in this session, never carried forward, and each was taken at least twice.

COUNTED ARM -- `env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_scratch_reuse test_calc_measure test_calc_engine test_calc_cross`

| suite | before | red now | after J1b | delta |
|---|---|---|---|---|
| test_calc_wave_dest | ALL PASS (102 checks) | 5 FAILED (110 passed) | 115 | +13 (band WD12) |
| test_calc_scratch_reuse | ALL PASS (54 checks) | 1 FAILED (55 passed) | 56 | +2 (SR5 re-derived) |
| test_calc_measure | ALL PASS (170 checks) | ALL PASS (170 checks) | 170 | 0 |
| test_calc_engine | ALL PASS (265 checks) | ALL PASS (265 checks) | 265 | 0 |
| test_calc_cross | ALL PASS (187 checks) | ALL PASS (187 checks) | 187 | 0 |

DISPLAY ARM -- `tests/headless/run_suites.sh test_calc_skeleton test_calc_plot test_calc_widgets` (lands on Xvfb :99 through xvfb_arm.sh; no other spelling was used)

| suite | before | red now | after J1b | delta |
|---|---|---|---|---|
| test_calc_skeleton | ALL PASS (573 checks) | 3 FAILED (576 passed) | 579 | +6 (band S28/7) |
| test_calc_plot | ALL PASS (105 checks) | 4 FAILED (109 passed) | 113 | +8 (band PL10) |
| test_calc_widgets | ALL PASS (259 checks) | ALL PASS (259 checks) | 259 | 0 |

⚠ FIGURES ONLY A DISPLAY ARM CAN PRODUCE -- ALL THREE OF THE RIGHT-HAND SUITES, measured rather than assumed. `env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_skeleton test_calc_plot test_calc_widgets` gives:
    PASS | test_calc_skeleton   RESULT: ALL PASS (0 checks)
    SKIP | test_calc_plot       (self-skipped: no X -- nothing ran)
    SKIP | test_calc_widgets    (self-skipped: no X -- nothing ran)
So 573/579, 105/113 and 259 exist ONLY on a display arm, and a headless number says nothing whatever about band S28/7 or band PL10. `test_calc_skeleton`'s headless arm also emits NO `OVERALL:` sentinel at all (census below), which is pre-existing and harmless because it is a `dcases` entry alone.

GREEN, PROVEN AGAINST A CONFORMING REFERENCE loaded as a probe and never written into src/ (`<scratch>/J1b/rowsmith/ref_j1b.tcl`; the display arm was reached through three temporary `tests/headless/test_j1bdry_*.tcl` wrappers that were run through `run_suites.sh` and then DELETED -- `git status --short` confirms they are gone):
    test_calc_wave_dest ALL PASS (115 checks)   test_calc_scratch_reuse ALL PASS (56 checks)
    test_calc_measure   ALL PASS (170 checks)   test_calc_cross         ALL PASS (187 checks)
    test_calc_engine    ALL PASS (265 checks)
    test_calc_skeleton  ALL PASS (579 checks)   test_calc_plot          ALL PASS (113 checks)
    test_calc_widgets   ALL PASS (259 checks)
That is the measurement that says the five + seven reds are about the MISSING FEATURE and not about a broken row.

T1 TRAILER DELTA, DERIVED and not predicted. `tests/run_regression.tcl` is UNTOUCHED (`git diff --stat` empty) and all four edited suites are already registered -- wave_dest and scratch_reuse in `hcases`, skeleton and plot in `dcases` alone. Census over the real captured headless output of each, with summarize_all's own regexp shapes:
    test_calc_wave_dest     skip:0  SKIP:0  SKIPPED:0  RESULT:1
    test_calc_scratch_reuse skip:0  SKIP:0  SKIPPED:0  RESULT:1
    test_calc_skeleton      skip:0  SKIP:0  SKIPPED:0  RESULT:1
    test_calc_plot          skip:0  SKIP:0  SKIPPED:0  RESULT:1
No suite's line SHAPE changes, so once J1b lands: cases +0, blocks +0, counted_failures +0, skips +0, and `wc -l` +0 -- `wc -l` moves with the NUMBER of `RESULT:`/`skip:` lines, not the counts inside them. This is the PLAN 5.4 pattern again: a stage that moves five published check counts and not one trailer term. I did NOT run T1; read the gate trailer.

⚠ A STALE PUBLISHED COUNT I DID NOT EDIT, named rather than left to rot: `tests/run_regression.tcl` line 140's registration comment for test_calc_wave_dest still says *"both arms of that suite run the identical 88 checks"*. The figure is now 115 and was already 102 before this stage. The SHAPE claim is still true. Per CLAUDE.md the fix is to DROP the number rather than update it, and it is the gate driver's file.


### counted_arm_rows

**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

the `sweep=` reader population is DERIVED over the enclosing C symbol of every line in src/*.c that reads the token, and PARTITIONED by whether the body assigns the token-walk variable out of the walk -- the assignment my_strtok_r never undoes -- so the carry-forward set and the read-it-once set are two measured sets rather than a sentence, the two partitions are disjoint, and a new walker lands in one of them or reddens naming itself

**red_output**

GREEN TODAY and declared as such in the band's own vacuity note: this is the DERIVATION, not the wiring. It answers `carry = {draw_graph find_closest_wave graph_fullyzoom graph_point_at graph_wave_resolve wave_hilight_envelope}` and `once = {backannotate_cursor_b_in_db graph_fullxzoom graph_x_extent graph_x_union_add graph_x_union_rect waves_callback}` with an empty intersection. It REPLACES a prose count that was wrong in four places, including in this file's own band map and hole H2.

**discriminates_how**

A new `sweep=` reader, or an existing one changing which partition it belongs to, reddens naming itself. The old prose said `all seven walkers carry it forward` and named `graph_fullxzoom` FIRST; that symbol reads field one once and carries nothing, and the population is twelve, not seven. The seven is correct about a DIFFERENT predicate (test_node_token_split.tcl's NDR2/NDR3: seven `node=` walkers resolve the sweep column BY NAME) and was reused for this one without re-deriving the set -- the `grep -c '#pragma'` failure exactly.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

...and the scanner the row above leans on is not vacuous: it finds hundreds of C symbols across src/*.c, it found the two walkers this band actually drives, and it found the one in a DIFFERENT file from the other eleven

**red_output**

GREEN TODAY, declared. Answers `{many 1 1 1}`.

**discriminates_how**

`wd_csyms` is a heuristic (declared as hole H14), so an empty or near-empty partition would satisfy the disjointness row above perfectly. This leg forbids that: a floor on the symbol count plus three named members, one of them in src/callback.c rather than src/draw.c.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

the token is LOAD-BEARING and a SHORT list is a DIFFERENT failure from an ABSENT one, measured through the one `sweep=` walker that is both headless and discriminating -- graph_marker add_at reaching graph_wave_resolve -- on a FIVE-trace strip whose own-X trace is THIRD

**red_output**

GREEN TODAY, declared: it is a HAZARD row on the bare verbs, in band WD0's sense. Answers `{ok same same same}`. The three measured shapes, all distinct: FULL `{time time __wd_xsel time time}` puts waves 0,1,3,4 on time[3]=3e-4 and wave 2 on __wd_xsel[3]=8.5; SHORT `{time time __wd_xsel}` leaves waves 3,4 RE-AXED onto 1.3e-3; ABSENT drops wave 2 to its own database's column 0 at 103.

**discriminates_how**

THE DISCRIMINATING INGREDIENT IS THE FIXTURE AND BOTH HALVES OF IT ARE REQUIRED. The probe database's own-X column is COLUMN ONE, because `calc::wave_dest` puts its X at column ZERO and `graph_wave_resolve`'s `sw` initialises to 0 -- so on the product's own shape an absent token still lands on the own-X column and a row driven only there is green whether the token was emitted or not (that is trap 7 of the recon). AND the ordinary database carries a column of the SAME NAME with different samples, because otherwise a carried token fails to resolve there and falls back to column 0, which IS the ordinary sweep -- the right answer for the wrong reason. The special trace is THIRD of five because in LAST position the carry-forward is invisible and three traces make it a coincidence.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

...and the instrument cannot have gone vacuous on a regenerated fixture: the four X values the three rows above tell apart are PAIRWISE DISTINCT at the time tolerance, and the probe's own-X column really is column ONE while the ordinary database's same-named column really is not its sweep

**red_output**

GREEN TODAY, declared. Answers `{distinct {0 1 2} 0 nonzero}`.

**discriminates_how**

This is the distinctness leg the brief asked for. `same` three times above is agreement only if the four comparands differ; a fixture regeneration that flattened them would make the band read as coverage while measuring one number against itself. Every comparand is read out of a COLUMN in the same run -- no interval and no sample value is written down anywhere in the band.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

`graph_fullxzoom` sizes the whole rect from ONE x quantity -- the target rect's FIRST token, read once -- so a MIXED strip frames whichever database that token belongs to and the other one contributes NOTHING

**red_output**

GREEN TODAY, declared HAZARD. Answers `{same same same same 0}`. Measured spans: own-X third -> the loaded sweep's span (the measured trace off-window); own-X first -> the measured trace's span (the ordinary traces off-window); a destination-ONLY strip -> correct; a plain strip -> unaffected.

**discriminates_how**

It is the EVIDENCE for the own-strip requirement, which is otherwise an opinion. `graph_x_extent` carries `if(idx < 0) return 0;`, so a database lacking the target strip's x quantity contributes nothing to the union -- a pixel outcome with a headless cause. It is why the hand-off must go through `wviewer::plot_signals` (which runs plan_plot and CREATES strips) and not straight to `wviewer::add_trace` (which creates nothing and clamps an out-of-range index to the LAST strip, i.e. builds exactly this mixed strip). ⚠ A correction the row carries in its comment: the colliding column has to be REMOVED first, because `graph_x_union_rect` fixes one x NAME and then unions the extent over EVERY contributing database that has a column of that name -- with the collision still in place the own-X-first case framed the union of both spans and the row was measuring a third thing.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

the armer is DERIVED over the `::calc::` namespace and not named: the procs that arm the sweep channel are exactly the procs that arm the DATABASE channel, every one of them also names BOTH take partners and the plot verb between them, and the set is not empty

**red_output**

-> {{} 1 {} only:0} (exp {{} 1 {} atleast}) : FAIL

**discriminates_how**

Arming one channel without the other reddens naming the proc; so does arming without naming both takes. Driven as sabotages against the reference: dropping `plot_dbs_arm` gave `{wave_show 0 wave_show atleast}`; removing the two `take` calls gave `{wave_show 1 {} atleast}`; replacing `plot_signals` with a direct `add_trace` gave `{wave_show 0 {} atleast}`. The emptiness leg is a LEG and not a comment because `$pbody` is built over `[info procs ::calc::*]` only, so an armer placed in `::wviewer::` would dodge SR5 entirely -- it cannot dodge this.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

...and the set really is reached: at least one `::calc::` proc arms each channel, which is the leg that fails on a tree where NOTHING arms them

**red_output**

-> {only:0 only:0 0} (exp {atleast atleast 1}) : FAIL

**discriminates_how**

This is the row that says unit J1b happened at all. `wviewer::plot_sweeps_arm` has ONE non-comment mention in src/ (its own proc line) and ZERO references in tests/ -- re-measured this session -- and its own banner says so.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

the hand-off names the destination by REGISTRY INDEX, the X by COLUMN NAME and the STRIP by `plot_signals`' existing fourth formal, driven with TWO destinations registered whose column names are identical

**red_output**

-> {ok measured named differ NOTCALLED NOTCALLED NOTCALLED NOTCALLED NOTCALLED real} (exp {ok measured named differ 2 calcx calcy __wd_notawindow newstrip real}) : FAIL

**discriminates_how**

THE KEYSTONE, and it catches the defect nobody had named. Measured: two `calc::wave_dest` calls give `__calc_dest1` and `__calc_dest2` and `xschem raw list` on EACH answers the identical `calcx calcy`; unit J1 never drops a destination, so coexistence is the normal case. An unarmed `add_trace` resolves a bare name through `wviewer::resolve_signal_db` -- the FIRST slot in `signal_list_all` order that has it -- so every measurement after the first silently draws the first one's curve. Sabotage, no `plot_dbs_arm`: `... differ {} calcx calcy ...`. Sabotage, no `destover`: `... newstrip` becomes `{}`. The new-strip code is READ out of `wviewer::dest_norm {New Strip}` rather than spelled. `wviewer::plot_signals` is recorded aside because both channels are consumed on its FIRST TWO LINES, before it refuses an unknown window -- a real call eats the evidence and a real window is a display.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

...and the one-shot channels are EMPTY afterwards, read without consuming them: the hand-off takes both back unconditionally, which is `wviewer::browser_plot_ids`' own idiom and its own comment

**red_output**

GREEN TODAY AND VACUOUSLY SO -- declared in the band's vacuity note. `wd_armleft` reads empty on a tree where nothing arms anything.

**discriminates_how**

It becomes a real fence the moment an armer exists; the row beside it is what keeps it honest today. Under sabotage (no `take` after a raising seam) it answers `{dbs sweeps}`.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

...and the INSTRUMENT: an arm that nobody takes PERSISTS for that token, so the empty answer above is a measurement rather than a proc that always answers empty -- and a take clears it again

**red_output**

GREEN TODAY, declared INSTRUMENT row. Answers `{{dbs sweeps} {}}`.

**discriminates_how**

It drives `plot_sweeps_arm`/`plot_dbs_arm` directly and reads the two namespace arrays WITHOUT consuming them, so `{}` in the row above is an observation and not a constant. A `take`-based instrument would have cleared the leak it was measuring.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

a hand-off that REFUSES, and one whose seam RAISES, each leave NO arm behind: an unregistered database is refused in a sentence of its own with nothing armed, and a `plot_signals` that throws is caught and answered as a refusal with both channels still taken back

**red_output**

-> {NOPROC:calc::wave_show long {} NOPROC:calc::wave_show long {}} (exp {refused long {} refused long {}}) : FAIL

**discriminates_how**

`calc::plot_rpn` has three refusal returns AHEAD of its own `plot_signals` call and the hand-off will have at least as many, so a persisted arm silently re-axes the NEXT plot in that window. ⚠ THIS ROW WAS VACUOUS ON ITS FIRST REVISION AND A DRY RUN AGAINST THE REFERENCE CAUGHT IT: the recorder took both channels and then threw, so a hand-off with NO `take` at all read green. The recorder now throws BEFORE consuming, which is what leaves something for the caller to clear; the sabotage then reddens this row AND the hygiene row. The sentence's WORDS are not asserted -- all of this stage's sentences are unratified and carry an open rule debt -- only that there is one and that it is not empty.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

the click's destination arm REACHES the hand-off and the hand-off touches NOTHING the buffer owns -- derived in three walks over the decommented namespace rather than read, AND THE BEHAVIOUR IS NOT MEASURED HERE: it is display-only and it is band S28/7's

**red_output**

-> {0 {} {} 1} (exp {1 {} {} 1}) : FAIL

**discriminates_how**

The row's NAME states that it is wiring and not behaviour, because a name describing coverage rather than method is what rots. It forbids the trap a `refresh the buttons after plotting` line walks into: `calc::buf_note_edit` sets `::calc::fbundo 1` / `fbredo 0`, the Tk-8.4 fallback hints `calc::buf_can` reads, so the user's undo HINTS would move while their undo HISTORY stood still -- and that is INVISIBLE on Tk 8.6. Sabotage (the armer calls `calc::buf_note_edit`): `-> {1 wave_show {} 1}`. The positive-control leg is that `fn_measure` itself DOES name `calc::buf_set_number`, so the empty answers are measurements and not a blind regexp.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD12

**name**

R402 the band left no __calc_tmp*, no __wd_* probe column, no destination slot and no armed channel behind, and `wviewer::plot_signals` is the real four-formal proc again with no rename standing

**red_output**

GREEN TODAY (nothing was armed and nothing was built, so there is nothing to leak). Answers `{{} {} 1 0 {} 4 0}`.

**discriminates_how**

It is the control that nothing below WD12 is measuring a recorder, and it is the SECOND row the missing-take sabotage reddens (`{... {dbs sweeps} 4 0}`). The arity leg re-measures `plot_signals`' four formals after the rename is undone, which is what BM05 pins as a literal source string in a suite that gates nothing.



### declared_holes

- ⚠ HALF (B)'s SIX BUFFER CAPTURES ARE GREEN AGAINST TODAY'S TREE, AND THE RED IN BAND S28/7 IS THE HAND-OFF LEG ONLY. Unit J1's own receipt declared those three claims -- the buffer untouched, the sentence on the status line, the undo state unmoved -- as unobservable on the counted arm, and NOTHING in this tree has ever run them. S28/7 is the first thing to measure them, and because J1 is correct they pass. So the honest statement is: the ACT legs are a new fence over shipped behaviour, and only the `NOPROC` legs are red-first against J1b. Stated in hole SH7 in the suite's own header rather than left for a reader to notice.

- ⚠ ONE `sweep=` CARRY-FORWARD WALKER OF SIX IS REACHED BEHAVIOURALLY AND THE OTHER FIVE ARE NOT, measured door by door rather than assumed (suite hole H13). `graph_wave_resolve` is reached headless through `xschem graph_marker add_at`. The other five were each TRIED: `xschem get graph_closest_wave` answers `{-1 -1}` with no window transform, `xschem get graph_wave_at` answers empty, `xschem get wave_hilight_points` answers 0 because it needs a real canvas, `graph_fullyzoom` runs but the sweep reaches only its custom-data arm, and `draw_graph` needs a canvas outright. The fence over those five is WD4's positive-shape assertion, which is upstream of all of them.

- ⚠ THE THREE FIRST-TOKEN-ONLY READERS ARE A DIFFERENT DEFECT AND NO CARRY-FORWARD FENCE TOUCHES THEM. `graph_fullxzoom` is fenced here as a HAZARD (a mixed strip cannot be framed), but `backannotate_cursor_b_in_db` -- the cursor-B backannotation to the schematic -- and `waves_callback`'s Button-2 drag-to-position arm both read field one with a silent `if(idx < 0) idx = 0`, and both are user-visible surfaces. Nothing in this stage fences either. They are in WD12's derived population, so they cannot be forgotten, but they are not measured.

- ⚠ THAT THE ENGINE DRAWS IT IS STILL A `look` DEBT. Band PL10 reads the REAL trace dict, the REAL strip layout and the REAL generated rect text in a REAL viewer window, and it reads NO pixels. `test_calc_plot`'s own header already says the same of every other row in it. I was forbidden to touch the owed.sh ledger, so the debt is named here and not filed.

- ⚠ `test_wave_grid` (row GT8, graph_props' three formals) and `test_wave_sigbrowser` (row BM05, plot_signals' four formals as a LITERAL SOURCE STRING) are in NEITHER `hcases` NOR `dcases` -- re-measured this session: `grep -c` over tests/run_regression.tcl answers 0. So the two suites that OWN the arity pins gate nothing, and a J1b that changed either signature would get a GREEN gate and a red `full_audit.sh`. WD4's three-proc leg (now also pinning plot_signals' first two formal NAMES) is the only gate-visible re-measurement. `test_node_token_split.tcl`, whose NDR2/NDR3 re-measure the seven-walker figure for the resolves-by-name predicate, is also unregistered -- which is part of why the wrong `seven` persisted.

- ⚠ THE SECOND DODGE SR5 CANNOT CLOSE: `$pbody` is built over `[info procs ::calc::*]` only, so an armer placed in `::wviewer::` instead of `::calc::` escapes SR5 entirely. It is closed from the other side -- WD12's derived-armer row asserts the `::calc::` armer set is NOT EMPTY -- and that cross-suite dependency is stated in both suites' comments. It is not closed inside SR5.

- ⚠ PL10's `no arm left`, `next ordinary press` and hygiene rows PASS TODAY and three of band WD12's rows do too. All six are declared in their suites' own vacuity notes. The instrument that keeps the arm rows honest is WD12's direct-arm row, which drives the two channels and shows they really persist.

- ⚠ THE DESTINATION'S USER-VISIBLE NAME AND ALL THREE SENTENCES REMAIN UNRULED, and no row I wrote asserts any of their words. Every row reads `__calc_dest<N>`, `calcx` and `calcy` OUT of the answer and matches the database against a GLOB (`wd_destname`), and the sentence rows assert agreement plus containment plus non-emptiness. A ruling on the wording reddens nothing. PL10 now puts the destination's NAME in front of a person for the first time, on a trace legend.

- ⚠ I ADDED NO ROW ABOUT `xschem raw switch_back`. `calc::wave_dest_restore` puts back one half of a registry cursor that is a pair, so `switch_back` after a successful destination lands ON THE DESTINATION. It is pre-existing, excluded from every key set, and a row asserting it would be RED ON CORRECT CODE.

- ⚠ BAND WD12 LEAVES ONE GRAPH RECT ON THE EMPTY SCHEMATIC. It is created once (one, deliberately: `graph_shares_x` groups rects by matching `sim_type=` and `graph_props` emits no `sim_type` token, so a second rect would join the first's shared-X group and the fullxzoom row would measure a union of two strips). Band WD10 after it reads only the raw inventory, and the suite then exits; the rect is not removed. Declared rather than swept blind.

- ⚠ I DID NOT EDIT THE THREE REMAINING PROSE COPIES OF THE WRONG WALKER COUNT, because two are in driver-owned contracts that a concurrent writer may hold and one is in src/, which this task forbids me to touch. They are: `src/wave_viewer.tcl` above `wviewer::graph_props` (*"⚠ ALL SEVEN WALKERS CARRY THE TOKEN FORWARD"*), `doc/claude/calculator_batch/DESTINATION_CONTRACT.md` section 9, and `doc/claude/calculator_batch/WIRING_CONTRACT.md` section 7.4 (*"and all seven walkers do it"*). I corrected the two copies inside test_calc_wave_dest.tcl and replaced the number with a row.

- ⚠ I RAN THE DISPLAY ARM AGAINST THE CONFORMING REFERENCE THROUGH THREE TEMPORARY `tests/headless/test_j1bdry_*.tcl` WRAPPERS. They were run only through `run_suites.sh`, they start no xschem of their own, and they are DELETED -- `git status --short` shows only the four intended suite files modified. I report it because creating a file under tests/ to reach the gate's own arm is a departure worth naming at the moment of making it.

- ⚠ I WROTE NO RECEIPT FILE. The harness instruction for this crew forbids writing report `.md` files and says the parent reads this structured answer; CREW_BRIEF.md requires `receipts/<stage>-<role>.md`. I followed the harness. If the ledger needs a receipt on disk, this schema is its content.

- ⚠ NO FULL T1 WAS RUN and the ~/gc26 clone was not touched. The gate that the task said was live had finished before I started -- checked by identity, `/proc/<pid>` for every `~/gc26/tests/results.<pid>.log` and `ps -eo comm=` for tclsh, both empty -- which is why running the display arm on the shared `:99` was safe. Scratch is 176 KB under the session scratchpad; `/tmp` is tmpfs here and nothing of mine is charged to it.


### display_arm_rows

**suite**

tests/headless/test_calc_skeleton.tcl

**band**

S28/7

**name**

R421 on a WAVE answer the RPN BUFFER IS LEFT ALONE and so is its UNDO STATE -- measured on SIX captures and not one: the text, `edit modified`, `calc::buf_can undo` and `redo`, the Stack size and the two Tk-8.4 fallback hints `calc::buf_note_edit` writes. ⚠ THE UNDO CLAIM IS THE OPPOSITE OF S28/4's: nothing was pasted, so there is no step to collapse and the assertion is that the state did not move, not that one undo restores. ONLY A GATE'S DISPLAY ARM VERIFIES THIS -- the suite reports `ALL PASS (0 checks)` under --nogui

**red_output**

`tests/headless/run_suites.sh test_calc_skeleton` -> `FAIL | test_calc_skeleton RESULT: 3 FAILED (576 passed)`, this row printing `-> {1 NOPROC 1 1 {} 1 1} (exp {1 ok 1 1 {} 1 1}) : FAIL`. Under `env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_skeleton` the same suite reports `ALL PASS (0 checks)` and this row does not exist, so a headless number says nothing about it.


**suite**

tests/headless/test_calc_skeleton.tcl

**band**

S28/7

**name**

R421 ...and the DESTINATION SENTENCE really reaches `.calc.status.msg` -- asserted through TWO independent witnesses, because a click that composed the sentence and raised on the way out leaves the number right and the field holding the PREVIOUS sentence. The WORDS are not asserted; the agreement and the containment are. GATE-ONLY: `calc::status` returns early on `calc::has_win .calc.status.msg`

**red_output**

`tests/headless/run_suites.sh test_calc_skeleton` -> `-> {1 NOPROC 1 agree 1 1 recorded} (exp {1 ok 1 agree 1 1 recorded}) : FAIL`. Only a display arm can produce any of those legs; the counted arm runs zero checks in this suite.


**suite**

tests/headless/test_calc_skeleton.tcl

**band**

S28/7

**name**

the click HANDED THE ANSWER TO THE VIEWER, with the destination the verb named and the token the result gate named -- the half unit J1 deliberately did not do. The hand-off is RECORDED rather than driven because this suite has no loaded raw at all; that a trace really appears is band PL10's, which has a real window, and it is gate-only too

**red_output**

`tests/headless/run_suites.sh test_calc_skeleton` -> `-> {1 NOPROC args: {} {}} (exp {1 ok called s28tok __s28_dest_fixture}) : FAIL`. Verified only by a gate: `calc::fn_measure` returns early on `calc::has_win .calc.buf`, so under --nogui the click is a no-op and this row is never reached.


**suite**

tests/headless/test_calc_skeleton.tcl

**band**

S28/7

**name**

...and the SURFACE WRAPPER is what the click reached, with the buffer's own RPN first and the dialog's values in the wrapper's formal order, and the default CYCLE really is the all-cycles zero that makes the answer a wave in the first place

**red_output**

GREEN on today's display arm (`{1 {{v(lp) v(sq) /} 0.5} allcycles}`). It is the row that says the recorder measured the PRODUCT: `calc::arg_surface` is literally *if `::calc::<name>_scalar` exists return it*, so a recorder on `calc::dutyCycle` would have been bypassed. Still display-only -- a --nogui run of this suite reports zero checks and says nothing about it.


**suite**

tests/headless/test_calc_skeleton.tcl

**band**

S28/7

**name**

the CONTROL: with the same recorder answering a SCALAR the click still PASTES the number and ONE undo still puts the expression back, and the viewer is NOT handed anything

**red_output**

GREEN on today's display arm. It exists because a click that had silently done NOTHING at all would pass every row above it; this one separates `the wave arm did nothing` from `the surface is broken for every answer`. Verified by a gate only.


**suite**

tests/headless/test_calc_skeleton.tcl

**band**

S28/7

**name**

CONTROL: both renames are undone and the real procs are back with the formals they had on the way in -- captured before the rename rather than written down

**red_output**

GREEN on today's display arm. The formals are compared against `$wv_formals0`, taken before the rename, so no arity number is written into the suite. Verified by a gate only.


**suite**

tests/headless/test_calc_plot.tcl

**band**

PL10

**name**

⚠ the measured wave APPEARS, and it appears against ITS OWN X and out of ITS OWN database -- read off the REAL trace dict: the trace's vector is the destination's Y column, its `sweep` key is the destination's X column, and its `rawfile`/`sim_type` pair is the destination's own registry entry

**red_output**

`tests/headless/run_suites.sh test_calc_plot` -> `FAIL | test_calc_plot RESULT: 4 FAILED (109 passed)`, this row printing `-> {{RAISED:ERR:invalid command name "calc::wave_in_token"} NOTRACE {NOKEY:vec NOKEY:sweep NOKEY:rawfile NOKEY:sim_type}} (exp {1 found {calcy calcx __calc_dest2 table}}) : FAIL`. ⚠ ONLY A GATE VERIFIES IT, and structurally so: `wviewer::signal_list_all` returns `{}` unless `dict exists $windows $token`, so `db_by_index` answers `{}` and `add_trace`'s named-database arm is UNREACHABLE headless. `env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_plot` reports `SKIP (self-skipped: no X -- nothing ran)`.


**suite**

tests/headless/test_calc_plot.tcl

**band**

PL10

**name**

⚠⚠ ...and it is the SECOND destination's curve and not the FIRST's -- two coexisting destinations answer the IDENTICAL two column names, and an unarmed `add_trace` resolves a bare name through `resolve_signal_db`, the first slot in `signal_list_all` order that has it

**red_output**

`tests/headless/run_suites.sh test_calc_plot` -> `-> {differ NOKEY:rawfile notfirst} (exp {differ __calc_dest2 notfirst}) : FAIL`. Driven as a sabotage against the reference with `plot_dbs_arm` removed, the same command gives `-> {differ __calc_dest1 FIRST} (exp {differ __calc_dest2 notfirst}) : FAIL` -- the wrong curve, in a real window, on a real trace dict. No headless arm exists: the suite self-skips whole under --nogui.


**suite**

tests/headless/test_calc_plot.tcl

**band**

PL10

**name**

...and the destination got its OWN strip: the layout gained exactly one strip, that strip holds exactly the one measured trace, and the strips that were already there are untouched

**red_output**

`tests/headless/run_suites.sh test_calc_plot` -> `-> {0 0 NOOWNSTRIP} (exp {1 1 hasown}) : FAIL`. Against the reference with no `destover` the same command gives `-> {0 1 NOOWNSTRIP}` -- the trace lands on a populated strip, which is the layout `graph_fullxzoom` cannot frame. A gate's display arm is the only thing that reads a layout at all.


**suite**

tests/headless/test_calc_plot.tcl

**band**

PL10

**name**

...and the rect text the strip generates carries ONE `sweep=` token for its one trace, naming the destination's own X column -- WD4's positive shape, asserted over the layout the product actually built

**red_output**

`tests/headless/run_suites.sh test_calc_plot` -> `-> {NOSTRIP NOSTRIP:-1} (exp {found calcx}) : FAIL`. Against the reference with no `destover`: `-> {found {frequency frequency calcx}} (exp {found calcx})` -- the mixed strip, named. ⚠ A correction a dry run forced: `wviewer::graph_props` resolves an ordinary trace's token through `wviewer::sweep_default`, which is `xschem raw list`'s first line in the database CURRENT RIGHT NOW, so called from the Calculator's own context it answered empty and the generator emitted no token at all. The helper now enters the viewer's context. Gate-only.


**suite**

tests/headless/test_calc_plot.tcl

**band**

PL10

**name**

...and NEITHER one-shot channel is left armed on this window, read without consuming them

**red_output**

GREEN today and VACUOUSLY so -- declared in the band's own map entry, because nothing arms anything yet. It becomes a fence the moment the hand-off exists; the instrument that proves the channels really persist is band WD12's direct-arm row on the counted arm. Only a gate runs it.


**suite**

tests/headless/test_calc_plot.tcl

**band**

PL10

**name**

...and the NEXT ordinary Plot press is unaffected: its trace carries NO sweep key, NO rawfile and NO sim_type, so it is on the loaded database's own X exactly as it was before the measured wave arrived

**red_output**

GREEN today (no hand-off has happened, so there is nothing to leak). It asserts the POSITIVE shape of an unaffected trace rather than the absence of a symptom, which is the rule a symptom-keyed fence dies by. Only a gate runs it.


**suite**

tests/headless/test_calc_plot.tcl

**band**

PL10

**name**

fixture: two ORDINARY traces are on the canvas first, through the real Plot button, so the strip the hand-off lands on is a populated one and `its own strip` is a claim about a layout rather than about an empty window

**red_output**

GREEN today (`{1 1 two}`). Without it the own-strip row would be measuring an empty window, where every plot makes a strip. Only a gate runs it.


**suite**

tests/headless/test_calc_plot.tcl

**band**

PL10

**name**

hygiene: both destinations this band built are dropped and the canvas is empty again, so PL8 and PL9 below measure the session rather than this band's leftovers

**red_output**

GREEN today. Only a gate runs it.


**for_the_implementer**

DO THESE IN ORDER. The rows already in the tree define the API; a dry run proved a conforming implementation turns every one of them green, and `<scratch>/J1b/rowsmith/ref_j1b.tcl` IS that conforming reference -- read it rather than guessing, but do not copy its sentences, which are placeholders.

1. ADD `calc::wave_show {tok d}` to src/calculator.tcl. It reads `db`, `xname`, `yname`, `type` off the answer; refuses with a sentence if any is missing; resolves the destination's REGISTRY INDEX by parsing `xschem raw info` for the slot whose path AND type match (a bare column name will not do -- that is the whole of defect 1); then, in this exact order:
       wviewer::plot_dbs_arm    $tok [list $idx]
       wviewer::plot_sweeps_arm $tok [list $xname]
       set rc [catch {wviewer::plot_signals $tok [list $yname] {} \
                          [wviewer::dest_norm {New Strip}]} errs]
       catch {wviewer::plot_dbs_take $tok}
       catch {wviewer::plot_sweeps_take $tok}
   and only then branches on `$rc` and on `[llength $errs]`. Both takes are UNCONDITIONAL and come BEFORE the branch -- copy `wviewer::browser_plot_ids` exactly, including why its own comment says *no-op after a real call; clears after a stub*. The fourth argument is the EXISTING `destover` formal: pass the new-strip code so the destination gets its own strip, and READ that code out of `wviewer::dest_norm` rather than writing `newstrip` down. NO new formal on `plot_signals` and none on `graph_props`.

2. ADD `calc::wave_in_token {tok d}`, the context-loan bracket, shaped exactly like `calc::plot_in_token`: refuse on an empty token, `wviewer::enter_ctx`, `catch` the inner call, `wviewer::leave_ctx` unconditionally.

3. WIRE `calc::fn_measure`'s destination arm. Keep `calc::arg_msg destination $name $db` as the success sentence and APPEND the hand-off's own `msg` when it refuses -- `calc::plot_rpn` already does exactly that with its `$drop`. The token comes from `[dict get $g token]`, the `calc::require_result` dict the proc already holds.

4. WHAT THE ARMER MUST NOT TOUCH. No `.calc` widget path, no `calc::buf_set_number`, no `calc::buf_note_edit`, no `xschem raw add` of its own (`add_trace` does that), no `xschem setprop rect ... sweep ...` (go through `graph_props`), and no `xschem raw switch_back`. Band WD12 asserts the first three as derivations over your decommented body and will name the proc if you reach any of them. `calc::buf_note_edit` is the live trap: it sets `::calc::fbundo 1` / `fbredo 0`, so a *refresh the buttons after plotting* line claims an undo is available after changing nothing -- invisible on Tk 8.6, and a sabotage I ran reddens WD12 for it.

5. PROSE THIS STAGE MUST CORRECT, and all three carry a count a command now produces. `src/wave_viewer.tcl` above `wviewer::graph_props` says *ALL SEVEN WALKERS CARRY THE TOKEN FORWARD* and names `graph_fullxzoom` first; derived over src/*.c, the population is TWELVE and partitions SIX carry-forward / SIX read-it-once, with `graph_fullxzoom` in the second half. Drop the number and point at band WD12's first row, which re-derives it every run. `doc/claude/calculator_batch/DESTINATION_CONTRACT.md` section 9 and `WIRING_CONTRACT.md` section 7.4 carry the same sentence; WIRING_CONTRACT section 10 exists to record exactly this kind of correction and does not have it, although `receipts/J-wiring-recon-contract.md` measured it. I corrected the two copies inside test_calc_wave_dest.tcl and left the rest to you -- a src edit and two driver-owned documents.

6. ALSO STALE, named rather than left to rot: `tests/run_regression.tcl` line 140 says test_calc_wave_dest runs *the identical 88 checks*; it is 115. Per CLAUDE.md DROP the number rather than update it. `WIRING_CONTRACT.md` section 5's cost table still reads `ALL PASS (90)` / `ALL PASS (160)`.

7. GATE IT AND READ THE TRAILER. No suite is being registered, so no trailer term should move; the five published check counts that DO move are 102->115, 54->56, 573->579, 105->113, and nothing else. ⚠ The display-arm figures are reachable only by a gate, so a green `--nogui` run is NOT evidence about bands S28/7 and PL10.

8. BEFORE YOU DECLARE IT DONE, re-run the five sabotages rather than re-reading them: drop `plot_dbs_arm`; drop `destover`; delete the two `take` calls; add a `calc::buf_note_edit`; and call `wviewer::add_trace` directly instead of `plot_signals`. Each one reddens between one and three WD12 rows and the first two also redden PL10 in a real window. A green run is not evidence that a fence still fences.

**red_proof**

######## FINAL RED -- COUNTED ARM ########
$ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_scratch_reuse test_calc_measure test_calc_engine test_calc_cross
FAIL     | test_calc_wave_dest          run 1/5  RESULT: 5 FAILED (110 passed)
FAIL     | test_calc_scratch_reuse      run 2/5  RESULT: 1 FAILED (55 passed)
PASS     | test_calc_measure            run 3/5  RESULT: ALL PASS (170 checks)
PASS     | test_calc_engine             run 4/5  RESULT: ALL PASS (265 checks)
PASS     | test_calc_cross              run 5/5  RESULT: ALL PASS (187 checks)
RESULT: 3/5 runs passed

######## FINAL RED -- DISPLAY ARM ########
$ tests/headless/run_suites.sh test_calc_skeleton test_calc_plot test_calc_widgets
FAIL     | test_calc_skeleton           run 1/3  RESULT: 3 FAILED (576 passed)
FAIL     | test_calc_plot               run 2/3  RESULT: 4 FAILED (109 passed)
PASS     | test_calc_widgets            run 3/3  RESULT: ALL PASS (259 checks)
RESULT: 1/3 runs passed

######## git diff --stat -- src/ ########
(no output -- src/ is byte-for-byte HEAD; tests/run_regression.tcl likewise untouched)

######## THE INDIVIDUAL RED ROWS, VERBATIM ########
COUNTED ARM, test_calc_wave_dest (band WD12):
  -> {{} 1 {} only:0} (exp {{} 1 {} atleast}) : FAIL
  -> {only:0 only:0 0} (exp {atleast atleast 1}) : FAIL
  -> {ok measured named differ NOTCALLED NOTCALLED NOTCALLED NOTCALLED NOTCALLED real} (exp {ok measured named differ 2 calcx calcy __wd_notawindow newstrip real}) : FAIL
  -> {NOPROC:calc::wave_show long {} NOPROC:calc::wave_show long {}} (exp {refused long {} refused long {}}) : FAIL
  -> {0 {} {} 1} (exp {1 {} {} 1}) : FAIL
  RESULT: 5 FAILED (110 passed)

COUNTED ARM, test_calc_scratch_reuse (band SR5):
  -> {only:1 has MISSING:wave_show plot_rpn} (exp {atleast has has plot_rpn}) : FAIL
  RESULT: 1 FAILED (55 passed)

DISPLAY ARM, test_calc_skeleton (sub-band S28/7):
  -> {1 NOPROC 1 1 {} 1 1} (exp {1 ok 1 1 {} 1 1}) : FAIL
  -> {1 NOPROC 1 agree 1 1 recorded} (exp {1 ok 1 agree 1 1 recorded}) : FAIL
  -> {1 NOPROC args: {} {}} (exp {1 ok called s28tok __s28_dest_fixture}) : FAIL

DISPLAY ARM, test_calc_plot (band PL10):
  -> {{RAISED:ERR:invalid command name "calc::wave_in_token"} NOTRACE {NOKEY:vec NOKEY:sweep NOKEY:rawfile NOKEY:sim_type}} (exp {1 found {calcy calcx __calc_dest2 table}}) : FAIL
  -> {differ NOKEY:rawfile notfirst} (exp {differ __calc_dest2 notfirst}) : FAIL
  -> {0 0 NOOWNSTRIP} (exp {1 1 hasown}) : FAIL
  -> {NOSTRIP NOSTRIP:-1} (exp {found calcx}) : FAIL

######## DETERMINISM ########
`-n 2` on the counted pair gives the identical figures on both repeats (5 FAILED (110 passed) / 1 FAILED (55 passed) twice), and test_calc_plot was re-run alone at 4 FAILED (109 passed). Zero `UNEXPECTED ERROR:`, zero `BGERROR:`, zero `ABORTED`, zero live-peer lines in any run.

######## AND THE REDS ARE ABOUT THE FEATURE, NOT ABOUT THE ROWS ########
With a CONFORMING REFERENCE loaded as a probe (never written into src/), every one of the twelve reds goes green and nothing else moves:
  test_calc_wave_dest ALL PASS (115 checks)   test_calc_scratch_reuse ALL PASS (56 checks)
  test_calc_measure   ALL PASS (170 checks)   test_calc_cross         ALL PASS (187 checks)
  test_calc_engine    ALL PASS (265 checks)
  test_calc_skeleton  ALL PASS (579 checks)   test_calc_plot          ALL PASS (113 checks)
  test_calc_widgets   ALL PASS (259 checks)

######## FIVE SABOTAGES AGAINST THAT REFERENCE, AND WHICH ROWS CAUGHT THEM ########
  no `plot_dbs_arm`            -> WD12 3 FAILED (112 passed); PL10 2 red, and the display arm printed `differ __calc_dest1 FIRST` -- the WRONG CURVE on a real trace
  no `destover`                -> WD12 1 FAILED (114 passed) at the strip leg; PL10 `NOOWNSTRIP` and `{frequency frequency calcx}`
  no `take` after a raise      -> WD12 3 FAILED (112 passed), including `{refused long {} refused long {dbs sweeps}}`
  armer calls buf_note_edit    -> WD12 1 FAILED (114 passed) -> `{1 wave_show {} 1}`
  `add_trace` not plot_signals -> WD12 3 FAILED (112 passed) -> `{wave_show 0 {} atleast}` and `NOTCALLED` throughout
`test_calc_scratch_reuse` stayed at `ALL PASS (56 checks)` under all five, which is the honest limit of SR5: it fences the R402 exemption, not the wiring.


### rows_moved

- tests/headless/test_calc_scratch_reuse.tcl band SR5, the viewer-door row. WAS one hand-written alternation `regexp {wviewer::(add_trace|plot_signals)}` against a ONE-NAME literal `{plot_rpn}`. NOW THREE ROWS over a DERIVED door set (+2 checks, 54 -> 56): (a) the door set's own non-vacuity, (b) the `viaviewer` floor plus membership, (c) the R402-obligation disjointness. ⚠ NOT A WEAKENING, AND THE MEASUREMENT IS THE ARGUMENT: the shipped alternation named ONE real door and ONE proxy -- derived over decommented `::wviewer::` bodies, the procs that issue `xschem raw add` THEMSELVES are `{add_trace paste_traces restore}` and `plot_signals` is NOT one of them. The transitive closure over the procs that call them is TWENTY-THREE, so the new predicate reaches `browser_plot_ids`, `paste_traces`, `paste_traces_at`, `browser_sea_plot_idx` and nineteen more that the alternation walked past. Measured on today's tree the widened derivation still answers exactly `{plot_rpn}`, so the predicate is a strict superset with the same answer -- which is what makes it a widening rather than a change of subject.

- SR5's membership expectation: WAS an exact one-name literal, IS NOW a floor (`atleast 2`) plus `has plot_rpn` plus `has wave_show`. ⚠ THE LOSS OF EXACTNESS IS PAID FOR TWICE OVER AND I STATE IT RATHER THAN HIDE IT. First, this is the treatment WD9's keystone got when its caller set moved: the floor is RE-DERIVED when a unit adds a route, never decremented, so J1b's name enters by MEASUREMENT. Second, the exactness is REPLACED BY A REASON: the new obligation row asserts `viaviewer` is disjoint from the mint, read-back and delete sets this band already computes, so a viewer-door proc that acquired an R402 obligation reddens for WHAT IT DID rather than for its name -- and the disjointness row beside it still forbids a proc on both doors. A snapshot literal could only ever say *this is the list I wrote down*.

- SR5's disjointness row: the literal `1` in its count leg became `[llength $viaviewer]`. That leg is now self-referential by construction, so the non-vacuity moved to the floor and `has` legs in the row above it, which is where it can be read. Not a weakening: the leg's job was always to stop an EMPTY set passing the `bothdoors == {}` claim, and an empty set now fails the floor explicitly instead of implicitly.

- SR5's add-without-read row NAME: it said *a literal, like the viewer-door row below*. ⚠ THAT CROSS-REFERENCE WENT STALE THE MOMENT THE VIEWER DOOR BECAME A DERIVED SET, which is this tree's own rule about cross-references being checked rather than trusted -- caught here rather than shipped. Re-spelled to give the REASON the direct door can still be a literal (it is a door a scan over the `::calc::` namespace can see; the viewer's is not). The claim is unchanged.

- tests/headless/test_calc_wave_dest.tcl band WD4, the two-arity row. GAINS two legs and loses none: `plot_signals`' FIRST TWO FORMAL NAMES (`{token exprs}`) and the existence of all four one-shot channel procs. Not a weakening -- it is a premise band WD12 leans on. WD12 renames `plot_signals` aside to a recorder (the only way a counted arm can see what was armed, because both channels are consumed on that proc's first two lines) and the recorder reports under those two names; pinning them here is what keeps a renamed formal from reading as a missing one. The `{3 grid 4 1 1}` leg is intact inside the longer expectation.

- tests/headless/test_calc_wave_dest.tcl, FOUR PROSE SITES CORRECTED AND THE NUMBER REPLACED BY A ROW: the band map's WD4 entry, hole H2, the WD4 band comment, and one WD4 row NAME. All four said or implied *all seven walkers carry the `sweep=` token forward* -- wrong twice over, since the population derived over src/*.c is TWELVE and `graph_fullxzoom`, the first name the old list gave, reads field ONE once and carries nothing. Every sentence now states a SHAPE and points at band WD12's first row, which re-derives the membership every run. ⚠ NOT A WEAKENING: nothing stops asserting anything. A count that only prose carried is now a row, which is the only form CLAUDE.md permits, and hole H2 records what the seven WAS right about (test_node_token_split.tcl's resolves-by-name predicate) so the next reader cannot repeat the reuse.

- tests/headless/test_calc_wave_dest.tcl header: a WD12 entry in the band map, a new paragraph in the declared-vacuity list naming the five rows that pass today and WHY, and two new holes H13 (one carry-forward walker of six is reachable headless, the other five measured door by door and named) and H14 (`wd_csyms` is a heuristic, with its non-vacuity as a row). Additive.

- tests/headless/test_calc_skeleton.tcl header: new hole SH7, stating that S28/7's six buffer captures are GREEN against a tree carrying unit J1 alone -- they are the FIRST thing in this tree to run J1's three declared-unobservable claims -- and that the red in the band is the hand-off leg. ⚠ I also recorded, in S28/7's own comment, that band CW14 of test_calc_widgets.tcl CANNOT host any of the three acts, which contradicts this stage's brief and both J1 receipts: CW14's own hole WH2 says it builds through `calc::arg_dialog_build` and never `calc::arg_dialog`, so it cannot see a click, a buffer edit, an undo or a status sentence. test_calc_widgets is UNCHANGED at 259 checks, and J1b adds no widget and no `-command`, so CW13's control sweep and CW14's inventory both hold.

- tests/headless/test_calc_plot.tcl header: a PL10 entry in the band map, including the three rows in it that pass today and why. Additive; no existing row touched. Its own PL5c rename of `plot_signals` is unaffected -- PL10 runs after PL7b and before PL8, and restores the canvas and both destinations on the way out so PL8 and PL9 measure the session rather than this band's leftovers.

**sr5_moved**

SR5's viewer-door claim was moved by WIDENING THE DERIVATION, never by writing a second name into the pattern, and the derivation's own honesty is now a row of its own.

THE DEFECT. SR5 asserted a one-name literal `{plot_rpn}`, and the real defect was not the expectation -- it was that the DERIVATION behind it was itself a hand-kept list of two names, `regexp {wviewer::(add_trace|plot_signals)}`. That is the same defect one level up, the exact rot that left `test_calc_wave_dest`'s arm sweep measuring 24 of 31 switch arms while staying green for a whole stage. Measured, it was worse than a short list: the `::wviewer::` procs that issue `xschem raw add` THEMSELVES are `{add_trace paste_traces restore}` -- THREE -- and `plot_signals` is not one of them, so the shipped pattern named one real door and one proxy for another, and matched neither `paste_traces`, nor `browser_plot_ids`, nor any other viewer entry point. And `regexp {wviewer::(add_trace|plot_signals)} wviewer::plot_sweeps_arm` answers 0, so a J1b that armed the sweep channel and plotted through a third route would have left the row GREEN at one name while a second Calculator-to-viewer route existed.

THE REPLACEMENT, MEASURED. The DOOR SET is derived out of the viewer's own namespace: the procs whose decommented body issues the direct engine verb, closed TRANSITIVELY over the procs that call them. Run against the live namespace over 517 `::wviewer::` bodies: direct = 3, closure = 23, and it contains BOTH `add_trace` and `plot_signals`. So the new predicate is a strict superset of what the alternation reached, and on today's tree it answers exactly the same `{plot_rpn}` -- which is what makes it a widening and not a change of subject. `$pbody` and `$wbody` are both DECOMMENTED first, which is not optional: my own first pass at a different derivation answered three armers for `plot_dbs_arm` because `browser_sea_send_to_add_trace` names it only inside a comment.

THREE ROWS WHERE THERE WAS ONE (54 -> 56 checks):
  (a) the door set's own NON-VACUITY -- a floor of 3 on the direct set, `has add_trace`, the closure strictly WIDER than the direct set, `has plot_signals`, `has add_trace`, and a floor of 100 on the namespace map. An empty or near-empty door set would otherwise satisfy everything below it.
  (b) the `viaviewer` claim as a FLOOR plus MEMBERSHIP -- `atleast 2`, `has plot_rpn`, `has wave_show`. Red today: `-> {only:1 has MISSING:wave_show plot_rpn} (exp {atleast has has plot_rpn})`. The floor is re-derived when a unit adds a route, never decremented, which is the treatment WD9's keystone got when J1 moved its caller set.
  (c) the REASON the exemption is sound, derived rather than asserted by name: no member of `viaviewer` appears in the mint, read-back or delete sets this band already computes, with the set's own count riding along. A proc on the viewer's door that acquired an R402 delete obligation would own a delete on a column a trace is still reading -- a vanishing trace rather than a stale number -- and this row names it for WHAT IT DID instead of for its name.

AND THE DISJOINTNESS ROW'S LITERAL `1` BECAME `[llength $viaviewer]`, so it stops being a number to edit; the non-vacuity it used to carry now lives in the floor and `has` legs above it, where a reader can find it.

THE ONE MOVE I REFUSED, and the rows refuse it too. The second dodge the recon named -- placing the armer in `::wviewer::` instead of `::calc::` -- escapes SR5 entirely, because `$pbody` is built over `[info procs ::calc::*]` only. SR5 cannot close that from the inside, so it is closed from the other side and the dependency is written into both suites: band WD12 of test_calc_wave_dest.tcl derives the armer set over `::calc::` and asserts it is NOT EMPTY, which is the leg that fails on exactly that dodge.

UNAFFECTED, re-run and confirmed: the `persistent {wave_dest}` one-name literal still holds, because the hand-off issues no `xschem raw add` of its own -- `wviewer::add_trace` does it, inside src/wave_viewer.tcl where no scan over the `::calc::` namespace can see it.

**sweep_fence**

THE FENCE IS THREE LAYERS, AND IT IS NOT PIXELS. A pixel fence reaches only `draw_graph`, which is one reader of twelve.

LAYER 1 -- THE POPULATION, DERIVED, SO THE WALKER SET CANNOT ROT AGAIN. Band WD12's first row scans `src/*.c`, maps every line that reads the `sweep=` token or names `sweep_name` to its ENCLOSING C SYMBOL, and PARTITIONS the result by whether the body assigns the token-walk variable out of the walk (`sweep_name = stok`) -- the assignment `my_strtok_r` never undoes, because it answers NULL once the list is exhausted and the guard then leaves the previous name standing. Measured, and now re-measured every run:
    CARRY FORWARD (6): draw_graph  find_closest_wave  graph_fullyzoom  graph_point_at
                       graph_wave_resolve  wave_hilight_envelope
    READ IT ONCE (6):  backannotate_cursor_b_in_db  graph_fullxzoom  graph_x_extent
                       graph_x_union_add  graph_x_union_rect  waves_callback
with the two partitions asserted DISJOINT and a second row forbidding the scanner from going vacuous (a floor on the symbol count plus three named members, one of them in src/callback.c rather than src/draw.c).
⚠ THIS REPLACES A PROSE COUNT THAT WAS WRONG IN FOUR PLACES AT ONCE. This file's own band map, its hole H2, its WD4 band comment and one WD4 row NAME all said *all seven walkers carry the token forward* and named `graph_fullxzoom` FIRST among them. It reads `find_nth(get_tok_value(r->prop_ptr, "sweep", 0), ", ", "\"", 0, 1)` -- field ONE, once, for the whole rect -- exactly as its own comment says, and the population is twelve, not seven. The SEVEN is right about a DIFFERENT predicate (rows NDR2/NDR3 of test_node_token_split.tcl: seven `node=` walkers resolve the sweep column BY NAME, and `graph_fullxzoom` does resolve per contributing database inside `graph_x_extent`), and the count was reused for a predicate nobody re-derived. That is the `grep -c '#pragma'` failure, and the remedy is the one CLAUDE.md allows: a row asserts it, or the sentence drops the number. All four copies in this suite now state a shape and point at the row. Three copies outside it -- `src/wave_viewer.tcl` above `graph_props`, `DESTINATION_CONTRACT.md` section 9, `WIRING_CONTRACT.md` section 7.4 -- I was not permitted to edit and have named for the implementer.

LAYER 2 -- ONE BEHAVIOURAL WITNESS, THROUGH THE ONLY DOOR THAT IS BOTH HEADLESS AND DISCRIMINATING. `xschem graph_marker add_at` reaches `graph_marker_create_at` -> `graph_marker_sample` -> `graph_wave_resolve`, and `graph_marker list` hands the resolved X back at field 5 ("%.17g"). I TRIED the other five carry-forward doors and each failed for its own reason, recorded as hole H13: `xschem get graph_closest_wave` answers `{-1 -1}` with no window transform, `graph_wave_at` answers empty, `wave_hilight_points` answers 0 because it needs a real canvas, `graph_fullyzoom` runs but the sweep reaches only its custom-data arm, and `draw_graph` needs a canvas outright.
BOTH FAILURES ARE FENCED AND THEY ARE TOLD APART. On a FIVE-trace strip whose own-X trace is THIRD:
    FULL   {time time __wd_xsel time time}  -> w0,w1 = time[3]      w2 = xsel[3]     w3,w4 = time[3]
    SHORT  {time time __wd_xsel}            -> w0,w1 = time[3]      w2 = xsel[3]     w3,w4 = RE-AXED
    ABSENT                                  -> w0,w1 = time[3]      w2 = column 0    w3,w4 = time[3]
Three distinct numbers, read out of their columns in the same run -- no interval and no sample value is written down anywhere in the band -- plus a pairwise-distinctness leg so the row cannot silently go vacuous if the fixture is regenerated.
⚠ THE DISCRIMINATING INGREDIENT IS THE FIXTURE AND BOTH HALVES OF IT ARE LOAD-BEARING, which the recon's trap 7 predicted and which I measured. (i) The probe database's own-X column is COLUMN ONE. `calc::wave_dest` builds with `xschem raw new <name> table <xname> 0 n-1 1`, so its X is column ZERO, and `graph_wave_resolve`'s `sw` initialises to 0 -- so on the product's own database shape the trace draws against its own X with NO token at all, and a row driven only there is green whether the token was emitted or not. (ii) The ORDINARY database carries a column of the SAME NAME with different samples. Without that, a carried token fails to resolve there and falls back to column 0, which IS the ordinary sweep -- the right answer for the wrong reason, and the row would read as coverage. The special trace is THIRD of five because in LAST position there is no later trace for the carried token to re-axe, and three traces make the count a coincidence.

LAYER 3 -- THE POSITIVE SHAPE, UPSTREAM OF ALL TWELVE READERS, KEPT AND EXTENDED. WD4's existing rows assert what `wviewer::graph_props` emits -- one token per trace, in node order, never SHORT, with the ordinary traces' token READ out of the current database rather than assumed to be `time` (its `ac` row exists because `set swdflt time` passed every other row on the `tran` fixture). That is the only layer that covers the five unreachable walkers, and it is asserted POSITIVELY rather than as the absence of a wrong rendering, because a symptom-keyed fence dies quietly when something else cures the symptom. PL10 now asserts the same positive shape over the layout the PRODUCT actually built, in a real window.

AND A FOURTH THING, WHICH IS NOT THE CARRY-FORWARD AT ALL AND IS THE DEFECT THAT WOULD ACTUALLY HAVE SHIPPED. `graph_fullxzoom` fixes ONE x quantity for the whole rect, and `graph_x_extent` returns 0 for a database that lacks it -- so on a MIXED strip the measured wave contributes NOTHING to the X union and is drawn off-window. Measured on the bare verbs: own-X third frames the loaded sweep's span, own-X first frames the measured trace's span and pushes the ordinary traces out, a destination-ONLY strip frames correctly. That is why the hand-off must pass `plot_signals`' EXISTING fourth formal `destover` with the new-strip code, and band WD12's keystone now carries that as a leg -- a sabotage that let the window's own Append destination stand reddens it, and PL10 reddens with `NOOWNSTRIP` and `{frequency frequency calcx}`.
⚠ ONE CORRECTION THE ROWS RECORD BECAUSE IT CHANGES THE PICTURE: `graph_x_union_rect` fixes the x NAME and then unions the extent over EVERY contributing database that HAS a column of that name. With the colliding column still loaded, the own-X-first case framed the union of BOTH spans and the row was measuring a third thing; the band now removes the collision before the fullxzoom rows, and says why. The collision is what layer 2 needs and the opposite of what layer 3's hazard needs, which is why the two halves of the band cannot share one fixture.

NOT FENCED, AND NAMED: the three first-token-only readers that are NOT `graph_fullxzoom` -- `backannotate_cursor_b_in_db` (the cursor-B backannotation to the schematic) and `waves_callback`'s Button-2 drag-to-position arm -- are a DIFFERENT defect that no carry-forward fence touches. Both are user-visible surfaces and both are in WD12's derived population, so they cannot be forgotten, but nothing here measures them.

