# recon:sites

**zero_call_call_sites_confirmed**: placeholder

**zero_call_sites_confirmed**: CONFIRMED — `calc::wave_dest` has exactly ONE non-comment occurrence in the product, and it is its own `proc` line.

Command (run from /home/analog/dev/xschem-claude):

  /usr/bin/grep -rn 'calc::wave_dest\([^A-Za-z0-9_:]\|$\)' src/ | awk -F: '{l=$0;sub(/^[^:]*:[0-9]*:/,"",l);t=l;sub(/^[ \t]*/,"",t); if(t ~ /^#/) next; print $1":"$2"  "t}'

Output (one line, nothing else):

  src/calculator.tcl:3511  proc calc::wave_dest {xs ys {xname calcx} {yname calcy}} {

Same for the dropper:

  /usr/bin/grep -rn 'calc::wave_dest_drop\([^A-Za-z0-9_:]\|$\)' src/ | (same awk)
  -> src/calculator.tcl:3607  proc calc::wave_dest_drop {answer} {

Bucketed census of the bare token `wave_dest` over the whole tree (excluding .git):
  53 in src/, 49 in tests/, 46 in doc/, 5 in CLAUDE.md.
Of the 53 in src/, 34 are COMMENT lines and 19 are CODE lines; every one of the 19 is inside the
definition block src/calculator.tcl:3452-3621 (the six `wave_dest*` procs calling each other).
Non-definition callers in src/: ZERO.

Tests (counted separately, as asked): 4 lines in tests/headless/test_calc_wave_dest.tcl reference it,
all through that suite's `pcall`/`wd_nowidget` probes (rows WD2, WD10) — i.e. the fence exercises it,
nothing in the product does. Docs: 15 prose mentions across DESTINATION_CONTRACT.md, CROSS_CONTRACT.md,
TIMING_CONTRACT.md, receipts H-destination-{recon,impl}.md, I1-1639.md and issue 1639.

⚠ SECOND ZERO-CALL-SITE HALF, which the stage description does not mention. The CONSUMER side was
shipped with the producer and is also unarmed:

  /usr/bin/grep -rn 'wviewer::plot_sweeps_arm' src/ tests/   (non-comment lines only)
  -> src/wave_viewer.tcl:7743  proc wviewer::plot_sweeps_arm {token sweeps} {
  (tests: 0)

`wviewer::plot_sweeps_take` IS consumed, at src/wave_viewer.tcl:7783 inside `wviewer::plot_signals`,
so the take side is live and only the arm side has no caller. Its own banner says so in code:
"⚠ DECLARED: NOTHING ARMS IT YET. … `calc::wave_dest`'s own caller will be the first armer."
By contrast `wviewer::plot_dbs_arm` IS already armed, at src/wave_viewer.tcl:10184 and :11626.
`wviewer::add_trace`'s 7th parameter `sweep` is reachable directly today.

**wave_dest_signature**: Read from src/calculator.tcl (symbols, not line numbers) and confirmed behaviourally with
`info args` / `info default` under `env -u DISPLAY ./src/xschem --nogui --pipe -q --script`.

=== calc::wave_dest {xs ys {xname calcx} {yname calcy}} ===
Formals, exactly: xs (required), ys (required), xname (default `calcx`), yname (default `calcy`).

CONTRACT. Takes TWO PARALLEL LISTS OF VALUES — not an RPN, not a column name, not a dataset. It sends
the engine no expression at all. It builds a freshly registered database holding exactly two columns
(the X column named `$xname`, created by `xschem raw new`; the Y column named `$yname`, created by
`xschem raw add $yname {}`), fills both with `xschem raw set` point by point, then restores the user's
previously-current slot. The database name is MINTED, not supplied: `__calc_dest<N>` from the
namespace variable `wdestn`, retried up to 1000 times because `xschem raw new` answers 0 on an
already-registered name (hazard 3). Its sim_type is the literal `table`.

The database is sized EXACTLY to the result: `xschem raw new $cand table $xname 0 [expr {$n - 1}] 1`
where `n = [llength $xs]`. So the caller supplies NO sample count and NO dataset — n is implied by the
list length, and the destination is single-dataset. Confirmed against `xschem raw points 0` inside the
proc, which is the only honest test of allocation (hazard 3 again).

Answer: a dict built at ONE site, `calc::wave_dest_answer {ok msg db type xname yname n prev prevtype}`,
so the key set cannot drift. Success = `ok 1`, `msg {}`, `db __calc_dest<N>`, `type table`, `xname`,
`yname`, `n`, `prev`/`prevtype` = the user's slot captured BEFORE anything moved. Refusal =
`calc::wave_dest_refusal` → `ok 0` plus a sentence in `msg`, everything else empty/0, and NOTHING
registered. There is deliberately no `absent` disposition.

Refusal conditions, in order, ALL before the registry is touched (D7 first):
  `llength $xs` raises            -> cross_msg destvalue
  `llength $ys` raises            -> cross_msg destvalue
  nx != ny                        -> cross_msg destlen
  nx == 0 (EMPTY IS A REFUSAL)    -> cross_msg destempty
  xname or yname empty, or equal  -> cross_msg destname
  any x or y not eval_finite      -> cross_msg destvalue
then, after the registry is touched: `raw new` throws -> destengine; no name allocated in 1000 tries
-> destalloc; `raw points 0` != n -> destalloc (and the db is cleared); the fill throws -> destengine
(db cleared). Every post-touch exit path calls `calc::wave_dest_restore $uname $utype` first.

⚠ The EMPTY-LIST refusal is load-bearing for stage J: `calc::cross` with nth 0 at a level nothing
reaches answers SUCCESS WITH AN EMPTY LIST (CROSS_CONTRACT T5), so an empty series really does arrive
at a wave-producing caller, and `wave_dest` will refuse it with `destempty`. Each wiring site has to
decide whether that is the right user-facing disposition or whether it should answer
`calc::cross_absent` instead.

State discipline the caller inherits: the user's current slot is captured by
`calc::wave_dest_cur` (ONE `xschem raw info` snapshot, regexp-parsed, returning `{name type}` or `{}`)
and restored by `calc::wave_dest_restore {name type}` (always `xschem raw switch $name $type`, by name
AND type — never `switch_back`, never a bare `switch <name>`, because a one-argument `switch` falls
through to "next database"). There is a MID-LIFE restore at the end of the success path, because
`raw new` made the destination current and `raw set` only writes the current database; skipping it
would make `results::current` answer `{}` for the life of the destination.

=== calc::wave_dest_drop {answer} ===
One formal: `answer` — the dict `calc::wave_dest` returned. Returns 0 if `dict get $answer db` raises
or is empty, else 1.

CONTRACT. Reads `db` and `type` out of the answer (type defaulting to `table`), re-reads the CURRENT
slot with `calc::wave_dest_cur`, and — if the caller left the destination itself current — substitutes
the answer's own `prev`/`prevtype` so a forgetful caller cannot be stranded on a database about to be
freed. Then `xschem raw clear $db $type` and `calc::wave_dest_restore`. TWO switches, not one, because
`xschem raw clear` forces the current slot to 0 unconditionally (issue 1636, load-bearing for
`ase::attach_dbs`, so it cannot be fixed at source).

DECLARED UNFENCED by its own banner: leak hygiene across a THROW out of `wave_dest` between the create
and the restore (suite hole H8).

**derivation_command**: TWO INDEPENDENT METHODS, same population. I did not reproduce your numbers; I ran both and they agree.

--- METHOD 1 (textual): enclosing proc of every `calc::cross_msg listdefer` call site ---

  cd /home/analog/dev/xschem-claude && awk '/^proc /{p=$2} {t=$0; sub(/^[ \t]*/,"",t); if (t ~ /^#/) next; if (t ~ /calc::cross_msg listdefer/) print FILENAME":"FNR"  "p}' src/*.tcl

Output:

  src/calculator.tcl:2896  calc::cross_scalar
  src/calculator.tcl:3050  calc::riseTime
  src/calculator.tcl:3126  calc::delay
  src/calculator.tcl:3327  calc::dutyCycle_scalar

(A wider scan on the bare token `listdefer` returns the same four plus
src/calculator.tcl:2461 `calc::cross_msg`, which is the switch arm DEFINING the sentence, not a
deferral. Command:
  awk '/^proc /{p=$2} {t=$0;sub(/^[ \t]*/,"",t); if(t ~ /^#/) next; if($0 ~ /listdefer/) printf "%s:%d proc=%s\n",FILENAME,FNR,p}' src/*.tcl )

--- METHOD 2 (behavioural, independent): every proc in the live ::calc:: namespace whose BODY
contains the literal, derived at runtime rather than over the file's text ---

  env -u DISPLAY ./src/xschem --nogui --pipe -q --script <probe>
  with: foreach p [lsort [info procs ::calc::*]] { if {[string match {*listdefer*} [info body $p]]} { lappend defer $p } }

Output:

  DEFER-BODY-SET: ::calc::cross_msg ::calc::cross_scalar ::calc::delay ::calc::dutyCycle_scalar ::calc::riseTime

Minus the definition site `cross_msg`: the same four procs. FOUR deferral sites, not three and not two.

--- METHOD 3 (behavioural, the refusals themselves) --- same probe, with NO result loaded; each call
returns the deferral dict, so all four guards are live and all four sit BEFORE the no-data check:

  cross_scalar {v(sq) 1 +} 0.5 0 rising 0        -> ok 0 absent 0 value {} dataset 0 dest {} msg {Cross: nth 0 answers every crossing and the buffer takes one number (R404), so a destination that can hold more than one has to come first.}
  riseTime {v(sq)} 0 1 10 90 0 0                 -> (identical msg)
  delay {v(sq)} 0.5 rising 0 {v(sq)} 0.5 rising 1 0 -> (identical msg)
  dutyCycle_scalar {v(sq)} 0.5 0 0 start         -> (identical msg)
  riseTime {v(sq)} 0 1 10 90 1 0                 -> msg {Cross: that result has no simulation data loaded.}   (control: nth 1 reaches the DB check)

The sentence is shared by identity: `calc::cross_msg listdefer` ==
"Cross: nth 0 answers every crossing and the buffer takes one number (R404), so a destination that can
hold more than one has to come first." MT7/MT8 of test_calc_measure and WD9 of test_calc_wave_dest
compare it by identity, and WD9's row names all four callers, so a FIFTH caller reddens there.

--- the split by DESTINATION (3 wave + 1 list), derived from each site's own code, not from prose ---
  wave: calc::riseTime, calc::delay, calc::dutyCycle_scalar
  list: calc::cross_scalar  (cross's nth 0 answers a plain list of X values, no Y — R419)

### sites
  - 
    **proc**: calc::cross_scalar

    **condition**: `[calc::eval_finite $nth] && [expr {double($nth) == 0.0}]` — integer-VALUED zero, so `0`, `0.0`, `-0` and `0e0` all defer; a non-finite `nth` deliberately falls through to `calc::cross`'s own `badnth` refusal. The guard is the FIRST statement of the wrapper, so nothing reaches the database.

    **formals_available**: `rpn level nth edge {dataset 0}`. All five are in scope at the guard. Nothing has been read from the database yet: no sweep name, no sim_type, no sample count, no crossing list.

    **what_it_would_need**: NOT a wave — this is the one LIST caller (R419). It needs a LIST destination, which does not exist (see list_destination field). If it were wrongly wired to `calc::wave_dest` it would have to invent a Y axis, which R419 explicitly forbids ('No Y axis is invented — not the threshold level, not the ordinal, not the sample index'). What it has available if wired: `calc::cross $rpn $level 0 $edge $dataset` already returns `ok 1` with `value` = the plain list of crossing X values and `dest` = the temporary it already cleaned up. Sample count = `llength` of that list. No name is needed for a list.

    **exists_yet**: YES, fully. `info procs ::calc::cross_scalar` -> 1 and `info procs ::calc::cross` -> 1. The verb is in the catalogue as `{cross {Special Functions} T scalar/list {} {The X value at the Nth crossing of a threshold}}` — note `returns` is already `scalar/list`, widened for R419. `calc::fn_argspec cross` returns 3 fields (level/nth/edge) and `calc::arg_surface cross` -> `cross_scalar`, so the click path reaches the wrapper and not the raw proc.

  - 
    **proc**: calc::riseTime

    **condition**: `[calc::eval_finite $nth] && [expr {double($nth) == 0.0}]`. Placed AFTER every request-level check (lo/hi supplied, both finite, pctlo/pcthi finite, swing != 0) and BEFORE any threshold arithmetic — the order is a deliberate decision recorded in the proc's banner: a malformed request must be refused as malformed, not deferred, because a deferral promises an answer once a destination lands. Issue 1639 added this guard; before it, nth 0 RAISED.

    **formals_available**: `rpn {lo {}} {hi {}} {pctlo 10} {pcthi 90} {nth 1} {dataset 0}`, plus the local `swing` = double(hi)-double(lo). Nothing read from the database yet. `llo`/`lhi` (the two absolute thresholds) are computed on the two lines immediately AFTER the guard.

    **what_it_would_need**: X = the list of LOW crossings: `calc::cross $rpn $llo 0 rising $dataset` (nth 0), whose `value` is the full list. Y = one rise time per low crossing: for each `xlo` in that list, the first element of `calc::cross $rpn $lhi 0 rising $dataset`'s `value` strictly greater than it, minus `xlo`. Both reads ALREADY EXIST in the nth!=0 path — the high-crossing read is already issued with a LITERAL 0 (`set b [calc::cross $rpn $lhi 0 rising $dataset]`), so the full high list is already materialised; only the low read currently uses `$nth`. Sweep/X column: NONE needs reading — `calc::wave_dest` creates its own X column named `$xname`. Dataset: the existing `dataset` formal is passed to `cross`, not to `wave_dest` (the destination is single-dataset). Sample count: `llength` of the low-crossing list, implied. NAME: UNDECIDED — there is no ruling and no convention; `wave_dest`'s defaults are `calcx`/`calcy` and the db is `__calc_dest<N>`. DISPOSITIONS TO DECIDE: (a) a low-crossing list that is EMPTY (cross nth 0 succeeds with `{}`) would hit `wave_dest`'s `destempty` refusal — `cross_absent` with `nohigh`/`absent` is probably the right answer instead; (b) a low crossing with NO high crossing after it — today that is `cross_msg nohigh` as a whole-request absence, but for a series it is a per-point hole and the proc must choose to drop the point or refuse the series.

    **exists_yet**: YES. `info procs ::calc::riseTime` -> 1. Catalogue row: `{riseTime {Special Functions} T scalar {} {Time of a transition from a low % level to a high % level}}`. `calc::fn_argspec riseTime` returns 6 fields; `calc::arg_surface riseTime` -> `riseTime` (NO `_scalar` wrapper exists). ⚠ `returns` is `scalar`, not `scalar/wave` — see surprises.

  - 
    **proc**: calc::delay

    **condition**: `foreach n [list $nthA $nthB] { if {[calc::eval_finite $n] && [expr {double($n) == 0.0}]} {...} }` — nth 0 on EITHER side defers, including both. First statement of the proc, before any database read. Its banner records why it is a deferral and not a raise: `cross` answers nth 0 with SUCCESS AND A LIST, so a verb that subtracted would reach `can't use non-numeric string as operand of "-"`.

    **formals_available**: `rpnA levelA edgeA nthA rpnB levelB edgeB nthB {dataset 0}`. All nine in scope. Nothing read; no crossing lists computed anywhere in this proc for the deferred case.

    **what_it_would_need**: THE ONLY SITE WHERE THE WAVE IS NOT ALREADY COMPUTED SOMEWHERE, and the only one needing a semantic decision before code. Per its own banner, 'a `delay` asked for `nth = 0` on a side is asking for one difference per crossing'. Three sub-cases, none of them ruled: (1) nthA=0, nthB fixed -> X = side A's crossing list, Y = (fixed B crossing) - (each A crossing); (2) nthA fixed, nthB=0 -> X = side B's crossing list, Y = (each B crossing) - (fixed A crossing); (3) BOTH 0 -> the two lists need PAIRING, and nothing in the tree pairs them (lengths can differ; `wave_dest` refuses on `destlen`). Reads needed: `calc::cross $rpnA $levelA 0 $edgeA $dataset` and/or the B equivalent. Sweep/X column: none read — `wave_dest` names its own. Dataset: existing formal, passed to `cross` only. Sample count: implied by list length, and for case (3) the mismatch is a REFUSAL unless the proc pairs or truncates deliberately. NAME: undecided, as above. ⚠ R417's negative delay is legitimate and must stay un-absolute-valued per band MT6, which carries into the series.

    **exists_yet**: YES. `info procs ::calc::delay` -> 1. Catalogue row: `{delay {Special Functions} T scalar {} {Time from an edge on one signal to an edge on another}}`. `calc::fn_argspec delay` returns 8 fields (rpnA levelA edgeA nthA rpnB levelB edgeB nthB — the ONLY spec offering an `rpn` field, because side B is a second operand). `calc::arg_surface delay` -> `delay` (no `_scalar` wrapper). ⚠ `returns` is `scalar`.

  - 
    **proc**: calc::dutyCycle_scalar

    **condition**: `[calc::eval_finite $cycle] && [expr {double($cycle) == 0.0}]` — the DEFAULT `cycle` is 0, so this is the default-argument path and the deferral is what a bare `dutyCycle` click hits. First statement of the wrapper. ⚠ The deferral is on the CYCLE ordinal, NOT on the X axis — see surprises.

    **formals_available**: `rpn level {cycle 0} {dataset 0} {xaxis start}`. All five in scope, `xaxis` included — the formal arrived with PLAN 5.4 and is currently pass-through only.

    **what_it_would_need**: THE CHEAPEST WIRING OF THE FOUR, because the wave is ALREADY FULLY COMPUTED one call away. `calc::dutyCycle $rpn $level 0 $dataset $xaxis` returns, for cycle 0, `ok 1` with `value` = the per-cycle fraction series (the Y) and `sweep` = the PARALLEL X series already selected by R420's `xaxis` (`start` -> each period's opening rising crossing, `number` -> the 1-based ordinal, `mid` -> the midpoint of the two rising crossings). So the wiring is: call it, take `[dict get $r sweep]` as xs and `[dict get $r value]` as ys, hand them to `calc::wave_dest`. Sweep/X column: NOT read from the database at all — the X series IS the measurement's own output, which is exactly the case `wave_dest` exists for. Dataset: existing formal, already forwarded. Sample count: `llength` of either list (they are built in the same loop, so equal by construction — `destlen` is unreachable here). NAME: undecided. Note `calc::dutyCycle`'s absences already fire before the series exists (`nocycle` when fewer than 2 rising crossings, `nofall` when a period has no falling crossing), so `destempty` is not reachable from this site.

    **exists_yet**: YES, both halves. `info procs ::calc::dutyCycle` -> 1 and `::calc::dutyCycle_scalar` -> 1. Catalogue row: `{dutyCycle {Special Functions} T scalar/wave {} {Fraction of a period the signal spends high}}` — `returns` is ALREADY `scalar/wave`. `calc::fn_argspec dutyCycle` returns 4 fields (level, xaxis, cycle, dataset — display order, deliberately NOT the formal order) and `calc::arg_surface dutyCycle` -> `dutyCycle_scalar`.


**list_destination**: THE SITE: `calc::cross_scalar` with `nth` integer-valued 0 (R419). CONFIRMED: there is no
`calc::list_dest`, and no proc of any name that is a list destination.

Derivation (two methods, both run):
  1. Over proc names in the file:
     /usr/bin/grep -oE '^proc +calc::[A-Za-z0-9_]*dest[A-Za-z0-9_]*' src/*.tcl
     -> plot_dest_req, plot_dest_offered, plot_dest_dropped, wave_dest_answer, wave_dest_refusal,
        wave_dest_cur, wave_dest_restore, wave_dest, wave_dest_drop, dest_changed.  Ten procs,
        none of them a list destination.
  2. Behaviourally, in the live namespace:
     `info procs ::calc::list_dest` -> 0 (empty).
     `lsort [info procs ::calc::*dest*]` -> ::calc::dest_changed ::calc::plot_dest_dropped
        ::calc::plot_dest_offered ::calc::plot_dest_req ::calc::wave_dest ::calc::wave_dest_answer
        ::calc::wave_dest_cur ::calc::wave_dest_drop ::calc::wave_dest_refusal
        ::calc::wave_dest_restore.
  (`calc::dest_changed` is W13's plot-destination combobox handler; `plot_dest_*` read that same
  combobox. None of the three is a destination for a result.)

WHAT EXISTS TODAY
 * The MEASUREMENT is complete. `calc::cross $rpn $level 0 $edge $dataset` answers `ok 1` with
   `value` = a plain Tcl list of crossing X values, `dest` = the temporary it already deleted
   (R402), `dataset`, `absent 0`, `msg {}`. Verified in code (`calc::cross_scan`'s `nth == 0` arm
   returns `[list 1 $out]` where `$out` is the appended crossing list).
 * The CATALOGUE already spells it apart: `cross` carries `returns scalar/list`, the term S24's
   closed vocabulary `{scalar wave bool scalar/wave scalar/list}` was widened by exactly one for.
   So the dispatch field the surface would read is in place.
 * The DEFERRAL is in place and shares the one sentence with the three wave callers.
 * The SURFACE CONTROL exists as a widget and is deliberately dead: `button .calc.mode.table
   -text {Table} … -command [list calc::inert {Table} 10]`, where
   `proc calc::inert {what phase}` returns `calc::status "$what: not implemented (phase $phase)"`.
   The enclosing comment says, in code: "W14 (Table) IS THE ONLY ACTION BUTTON ON THIS STRIP STILL
   INERT … Table is PLAN phase 10's."
 * The SPEC ruling exists: calculator.md R606 — "**Table** shows X/Y pairs of the evaluated
   expression in a scrollable dialog" — and R419 names the list as the shape, with the surface
   "a list, not a plot".

WHAT IS MISSING
 1. A destination proc. No `calc::list_dest`, no table dialog, no scrollable list widget anywhere
    in `calc::`. Nothing to call.
 2. ⚠ R606 AND R419 DO NOT DESCRIBE THE SAME THING, and this is the gap that matters most. R606
    says Table shows **X/Y pairs of the evaluated expression** — i.e. the Table control's own job is
    to tabulate the buffer's expression against the sweep, two columns. R419 says `cross` nth 0
    answers **a plain list of crossing times with no Y axis invented**, one column. So routing
    `cross_scalar`'s list into "the Table surface" means either (a) the Table dialog takes a
    one-column mode, or (b) Table is the expression tabulator and the crossing list needs its own
    surface. Nothing in the tree decides this; the three source comments that say `cross_scalar`
    "waits on the `Table` surface (spec R606)" are COMMENTS asserting an equivalence the two
    rulings do not establish. Flagging per the standing constraint: that claim rests on comments
    at src/calculator.tcl:2419, :2872 and :3303, not on code and not on either ruling's words.
 3. No disposition for the EMPTY list. `cross` nth 0 at a level nothing reaches answers SUCCESS
    with `value {}` (CROSS_CONTRACT T5). A list surface has to decide whether that is an empty
    table or an absence sentence; `wave_dest`'s answer (`destempty`, a refusal) is not available
    here because there is no destination.
 4. No path out of `calc::fn_measure`. That proc's success arm is unconditionally
    `set v [dict get $d value]; set num [calc::buf_set_number $v]` — and `calc::buf_set_number`
    does `.calc.buf delete 1.0 end; .calc.buf insert end $n` with no numeric validation, so a list
    answer would be pasted into the RPN buffer verbatim. Read from code, not comment.
 5. The Table button is currently reached by a click with no verb context at all — it reads
    nothing, takes no argument, and has no connection to `fn_measure`'s answer. Whatever R419's
    list lands in has to be reachable from the verb click path, not only from the strip button.

### surprises
  - ⚠ THE STAGE DESCRIPTION'S LIST OF DEFERRING SITES IS STALE IN BOTH DIRECTIONS, and so is the source comment it came from. You wrote: 'dutyCycle's default X axis, delay with nth = 0, and the unbuilt frequency all still DEFER'. Derived truth: the three WAVE callers are `calc::riseTime`, `calc::delay` and `calc::dutyCycle_scalar`. (a) `riseTime` IS a deferring wave caller — issue 1639 added that guard, and src/calculator.tcl's own comments at the `cross_scalar` banner, the `delay` banner, the `cross_msg` banner and the catalogue banner ALL still enumerate 'delay, dutyCycle_scalar and the unbuilt frequency', omitting it. FOUR stale prose copies. WD9's test row has the right set (it names 'cross_scalar's nth 0, delay's nth 0 on a side, dutyCycle_scalar's default cycle and riseTime's nth 0'), so the fence is correct and only the comments rotted. (b) `frequency` does NOT defer, because it does not exist — it cannot be in a population derived over `listdefer` call sites. The count '3 wave + 1 list' happens to be right; the MEMBERSHIP is not.
  - ⚠ 'dutyCycle's default X axis' is the wrong axis of the deferral. `calc::dutyCycle_scalar` defers on `cycle == 0` (the default CYCLE ordinal, meaning 'all cycles'), not on the X axis. R420's `xaxis` formal LANDED with PLAN 5.4 — it is a real formal with default `start`, it is offered by `calc::fn_argspec dutyCycle` as `{xaxis {X axis} {enum start number mid} 0 start}`, and `calc::dutyCycle` validates it with `lsearch -exact {start number mid}` and refuses an unknown token with `cross_msg badxaxis`. It is fully wired and fully forwarded. Nothing about the X axis defers.
  - ⚠ `frequency`/`freq` ARE IN THE CATALOGUE — 'unbuilt' is half stale. Evidence, quoted from `calc::catalogue`:
    {frequency {Special Functions} T scalar/wave {} {Frequency measured from the wave's crossings}}
    {freq {Special Functions} T scalar/wave {} {Frequency measured from the wave's crossings}}
Both are route T, both already carry `returns scalar/wave`. What does NOT exist: `info procs ::calc::frequency` -> 0, `info procs ::calc::freq` -> 0, `llength [calc::fn_argspec frequency]` -> 0, same for `freq`. A derived grep over every proc name in src/calculator.tcl (`/usr/bin/grep -oE '^proc +[A-Za-z0-9_:]+'`, 143 procs) finds ZERO whose name matches `freq` case-insensitively. So: catalogued and clickable-in-principle, no implementation, no argspec. Clicking it today reaches `calc::fn_measure` -> `fn_argspec` returns empty -> `calc::inert "function frequency" 5`, i.e. 'function frequency: not implemented (phase 5)'. That is a DIFFERENT refusal from the shared `listdefer` sentence, and MT11's row 2402 depends on route T having no `fn_reason` entry, so the 30-verb fall-through is already fenced.
  - ⚠ `riseTime` AND `delay` HAVE NO `_scalar` WRAPPER, AND MINTING ONE IS A SILENT REDIRECT. `calc::arg_surface {name}` is literally `if {[info procs ::calc::${name}_scalar] ne {}} { return ${name}_scalar }; return $name`. Measured: `arg_surface cross` -> cross_scalar, `arg_surface dutyCycle` -> dutyCycle_scalar, `arg_surface riseTime` -> riseTime, `arg_surface delay` -> delay. So the moment stage J creates `calc::riseTime_scalar`, every click on riseTime silently routes there, and MT11's surface-formals row (test_calc_measure, 'every key is also a formal of the SURFACE proc the click must call') starts asserting against the NEW proc. ⚠ AND THE FORMAL ORDER IS LOAD-BEARING: `calc::arg_values` walks `info args` of the surface proc in FORMAL order and `break`s at the first formal not present in `have` (= `rpn` plus the dialog's answers), then `calc::arg_invoke` appends the values POSITIONALLY. So a new wrapper must carry `rpn lo hi pctlo pcthi nth dataset` (riseTime) / the eight delay keys, in that order, or the call is silently TRUNCATED at the first unknown formal and everything after it falls back to defaults. A destination-naming argument is safe only as a TRAILING formal with a default.
  - ⚠ THE DESTINATION IS USER-VISIBLE IN THE RESULTS PICKER, AND ITS NAME IS UNRULED. Verified from code, not comment: `results::list` iterates every db out of `xschem raw info` and filters by nothing — no type test anywhere in the proc — so `__calc_dest<N>` typed `table` appears in the picker for as long as it lives. The column names a trace will show are `calcx`/`calcy` (the `wave_dest` defaults), and NOTHING in spec §7.2ac, DESTINATION_CONTRACT.md or the catalogue rules what a measured wave should be called. The only `calcx`/`calcy` mentions outside the proc's own signature are test fixtures and recon pixel tables. Your schema asks 'what the resulting wave should be NAMED' — the answer is that nobody has decided, and because the string lands in the Results picker and in a graph's trace label it is user-visible, so it is a `rule` candidate rather than an internal choice.
  - ⚠ `calc::fn_measure` IS A REQUIRED CHANGE SITE AND IS NOT A DEFERRAL SITE, so no `listdefer` derivation finds it. Its success arm is unconditional: `set v {}; catch {set v [dict get $d value]}; set num [calc::buf_set_number $v]; return [calc::status [calc::arg_provenance $name $vals $num]]`. There is no branch on the answer's shape, and `calc::buf_set_number` performs `.calc.buf delete 1.0 end; .calc.buf insert end $n` with no numeric check. So if a verb starts answering `ok 1` with a LIST in `value`, the list is pasted into the RPN buffer and R404/R421 are both violated silently. Any wiring that makes a wave answer `ok 1` must add the branch here, or route the wave through a key other than `value`.
  - ⚠ A RETURNS RE-SPELLING IS NEEDED FOR TWO VERBS AND IT IS CHEAPER THAN THE USUAL FOUR-SITE EDIT. `riseTime` and `delay` both carry `returns scalar`, and `calc::catalogue`'s own banner argues for it: 'riseTime and delay stay scalar: both answer one number, and R417's negative delay is still one number.' If stage J makes their nth-0 case answer a WAVE, that sentence becomes false and both rows want `scalar/wave`. GOOD NEWS, measured rather than assumed: `scalar/wave` is ALREADY in S24's closed vocabulary, so the vocabulary does NOT widen and the three prose copies in src/calculator.tcl plus spec §7.2ab's R416 note do NOT move. And S24's `{56 26 12 4 3 3 4 108}` arm counts rows PER §7.1 CATEGORY (`calc::fn_entries $cat`), not per `returns` value — I read the loop — so a returns re-spelling moves NO count there either. The only S24 arm that reads `returns` is the closed-vocabulary `lsearch`, which already permits the new value. Contrast R419's own widening, which cost four sites.
  - ⚠ THE CONSUMER SIDE HAS ITS OWN ZERO-CALL-SITE HALF AND THE STAGE DESCRIPTION DOES NOT MENTION IT. `wviewer::plot_sweeps_arm {token sweeps}` has zero callers in src/ and zero in tests/; only its definition line matches. Its take partner IS consumed, inside `wviewer::plot_signals`. Its own banner says: 'DECLARED: NOTHING ARMS IT YET. The Calculator's click wiring (R410/R412) is phase 5's, and calc::wave_dest's own caller will be the first armer.' So a stage that only wires the producer still leaves the user with a registered two-column database and no trace on screen. The alternative door, `wviewer::add_trace`'s 7th parameter `sweep`, IS reachable today (the banner says so and the signature confirms it: `proc wviewer::add_trace {token gi rpn {name {}} {color {}} {db {}} {sweep {}}}`). Note the arity pins: row BM05 of test_wave_sigbrowser asserts `plot_signals`' four parameters as a LITERAL SOURCE STRING and row GT8 of test_wave_grid pins graph_props' three, which is why the arm/take shape was chosen over a fifth parameter — so do not 'simplify' it to one.
  - ⚠ `destempty` MEANS EACH WAVE CALLER OWES A DISPOSITION DECISION, and only one of the three is already covered. `calc::wave_dest` refuses an empty list with `cross_msg destempty` ('Destination: an empty result has nothing to put in a destination, so none was built.'), and `calc::cross` with nth 0 at an unreached level answers SUCCESS WITH AN EMPTY LIST. So: `dutyCycle_scalar` is safe (its `[llength $rs] < 2` -> `nocycle` and the per-period `nofall` fire before any series exists); `riseTime` nth 0 with no low crossing WILL hand `wave_dest` an empty list and the user will read a 'Destination:' sentence where an absence sentence is the true answer; `delay` the same, plus the both-sides-zero case where the two crossing lists can differ in length and `destlen` fires. These are three choices, not one, and none is ruled.
  - ⚠ ONE PIECE OF GOOD NEWS WORTH STATING PLAINLY, because it changes the stage's shape: `calc::dutyCycle` ALREADY COMPUTES AND RETURNS THE COMPLETE WAVE for cycle 0 — `dict set r value $series; dict set r sweep $xseries; return $r` — with `xseries` already selected per R420's three axes in the same loop. So the dutyCycle wiring is a handful of lines in `calc::dutyCycle_scalar` with nothing to derive and nothing to decide except the name. `riseTime` needs one extra `cross` call (it already issues the high read with a literal 0). `delay` is the only one needing new semantics. The three wave sites are NOT equal work, and `delay`'s both-sides-zero pairing is the only genuinely open design question among them.

