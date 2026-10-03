# H — the destination for a wave with its own X axis: IMPLEMENTATION

Stage: R419/R420/R421, `doc/claude/calculator_batch/DESTINATION_CONTRACT.md`.
Role: implementation crew. **Nothing is committed** — the work is left in the tree for the driver,
who owns the gate, the identity and the commit message. **No full T1 was run.**

---

## 1. What changed, by symbol

### `src/calculator.tcl`

| symbol | change |
|---|---|
| namespace header | new `variable wdestn 0` — the destination serial, INTERPRETER-scoped for the reason `tmpn` is, plus one measured reason of its own (reuse freezes the geometry) |
| `calc::cross_msg` | the **`listdefer`** sentence reworded (see §4); **seven new arms** added — `badxaxis`, `destempty`, `destlen`, `destvalue`, `destname`, `destalloc`, `destengine`. No comment between any two patterns. |
| `calc::cross_scalar` | header prose: the refuted Cadence/`table_read` claim removed, superseded-with-correction |
| `calc::delay` | header prose: it is a **waveform**-destination caller and `cross_scalar` is not |
| `calc::dutyCycle` | **R420** — new 5th parameter `{xaxis start}`; builds a parallel `xseries` in the existing period loop; the answer carries a new **`sweep`** key, a LIST for `cycle` 0 and a SCALAR for a named cycle. Refuses an uninterpretable token (and `{}`) before any read. |
| `calc::dutyCycle_scalar` | header prose only; **deliberately does not forward `xaxis`** (declared, §5) |
| `calc::wave_dest_answer` | NEW — the ONE site that names the answer dict's keys |
| `calc::wave_dest_refusal` | NEW — every refusal, through that one site |
| `calc::wave_dest_cur` | NEW — the current slot as `{name type}` out of ONE `xschem raw info` snapshot (see §6, this is the stage's biggest correction) |
| `calc::wave_dest_restore` | NEW — restore by name **AND** type, never `switch_back`, never a bare `switch <name>` |
| `calc::wave_dest` | NEW — the producer |
| `calc::wave_dest_drop` | NEW — removes the destination and puts the user's slot back |
| `calc::fn_fields` | schema comment: the `returns` vocabulary gains `scalar/list` |
| `calc::catalogue` | the stale paragraph removed (§4); the **`cross` row becomes `scalar/list`** |

### `src/wave_viewer.tcl`

| symbol | change |
|---|---|
| `wviewer::add_trace` | new **7th and last** parameter `{sweep {}}`, put on `trd` only when non-empty (absent-means-absent, like `rawfile`/`sim_type`) |
| `wviewer::graph_props` | emits one `sweep=` token **per trace, in node order**; arity unchanged at 3 |
| `wviewer::sweep_default` | NEW — the current database's own X name (first raw vector), `{}` when unreadable |
| `wviewer::sweep_token` | NEW — one token, `{}` for a name the whitespace grammar cannot carry |
| `wviewer::plot_sweeps_arm` / `plot_sweeps_take` | NEW — the out-of-band one-shot channel, `plot_dbs_*`' shape verbatim |
| `wviewer::plot_signals` | takes the sweep list FIRST THING, pads it to `exprs`' length, passes it to `add_trace`. **Signature byte-identical** (BM05 pins it as a literal string) |
| `wviewer::forget` | `variable plotsweeps` declared and unset with the window |

### Tests (the three changes outside the new code)

| file | change |
|---|---|
| `tests/headless/test_calc_scratch_reuse.tcl` row **SR5** | WIDENED as a derivation: the four-way equality is **anchored on the READERS** instead of on the adders, the pre-flight subset moved with it, and a new ONE-NAME-LITERAL row fences the add-without-read door. 53 → **54 checks**, green. |
| `tests/headless/test_calc_skeleton.tcl` row **S24** | closed vocabulary widened by exactly one term to `{scalar wave bool scalar/wave scalar/list}` |
| `tests/run_regression.tcl` | `"headless/test_calc_wave_dest"` added to **`hcases`** |
| `tests/headless/test_calc_measure.tcl` | comment only (the MT8 identity row's prose) — no row touched |
| `tests/headless/test_calc_wave_dest.tcl` band **WD4** | **S15's hole CLOSED** on the driver's ruling: new helper `wd_load1ac` and a new last row in WD4 driven on the **AC** analysis. 88 → **89 checks**, both arms. See §9. |

---

## 2. The red, verbatim

`test_calc_wave_dest` against the tree with none of the destination present:

```
RESULT: 39 FAILED (49 passed)        exit=1
```

Zero `UNEXPECTED ERROR`, zero `RAISED:`, WD0 and WD1 fully green — which is what distinguishes
"the feature is absent" from "the suite is broken". The failures named what was missing rather than
printing a Tcl error, e.g.

```
FAIL: WD2 calc::wave_dest exists and MEASURES ... -> {NOPROC:calc::wave_dest ...}
FAIL: WD4 wviewer::add_trace takes a SWEEP argument ... -> {6 {} db} (exp {7 sweep db})
FAIL: WD8 R420 the CYCLE-NUMBER axis answers the ordinals 1..N ...
      -> {{NOTADICT:NOARITY:calc::dutyCycle takes {rpn level cycle dataset} and was given 5} ...}
FAIL: WD10 ...and calc::wave_dest exists under a name NEITHER of those two globs matches
      -> {0 0 0 0} (exp {1 1 0 0})
```

And `test_calc_scratch_reuse`, after the producer landed and **before** SR5 was widened — the red
the contract predicted, naming `wave_dest`:

```
RESULT: 2 FAILED (51 passed)
FAIL: SR5 R402 DERIVED: ... -> {{cross eval_rpn wave_dest} {cross eval_rpn} {cross eval_rpn} {cross eval_rpn}}
                              (exp {{cross eval_rpn wave_dest} x4})
FAIL: SR5 ...and EVERY member of that derived set runs calc::rpn_bad_token ... -> {3 wave_dest} (exp {3 {}})
```

---

## 3. The green

| suite | arm | result |
|---|---|---|
| `test_calc_wave_dest` | `--nogui` | `ALL PASS (88 checks)` → **`89`** once S15's hole was closed (§9) |
| `test_calc_wave_dest` | display `:99` | `ALL PASS (88 checks)` → **`89`** (§9) |
| `test_calc_scratch_reuse` | `--nogui` | `ALL PASS (54 checks)` (was 53) |
| `test_calc_engine` | `--nogui` | `ALL PASS (265 checks)` |
| `test_calc_cross` | `--nogui` | `ALL PASS (187 checks)` |
| `test_calc_measure` | `--nogui` | `ALL PASS (125 checks)` (MT7/MT8 green) |
| `test_calc_plot` | display | `ALL PASS (105 checks)` |
| `test_calc_skeleton` | display | `ALL PASS (548 checks)` |
| `test_calc_widgets` | display | `ALL PASS (246 checks)` |
| `test_wave_viewer` | display / `--nogui` | `ALL PASS (437)` / `ALL PASS (59)` |
| `test_wave_grid` `test_wave_modes` `test_wave_legend` | display | 400 / 488 / 77 |
| `test_wave_crossdb_trace` `test_wave_cursor_crossdb` `test_node_token_split` | display | 130 / 93 / 174 |
| `test_wave_axis_zoom` `test_wave_trace_menu` `test_wave_drag_preview` | display | 370 / 397 / 94 |
| `test_wave_sigbrowser` `_digital` `_panes` | display | 353 / 82 / 88 |
| `test_ase_current_repair` `test_results_select` | display | 54 / 375 |
| `test_wave_markers` | `--nogui` | `ALL PASS (437 checks)` |
| `test_registered_banner_1626` `test_scratch_home_note` | `--nogui` | 10 / 22 |
| `tclsh tests/headless/issue_stamp.tcl` | — | `ISSUE-STAMP: ok (0 problems)` |

⚠ `test_wave_markers` **TIMEOUT** on the display arm (`after 200s`). **Pre-existing and declared in
CLAUDE.md**: *"`test_wave_markers` times out when `run_suites.sh` attaches to a dev display (issue
1488, pre-existing): with `:99` up that TIMEOUT is not your change."* It passes at 437 checks on the
`--nogui` arm, which is the arm the dev display cannot affect.

### Registration, derived not predicted — both arms measured with `banner_complete` itself

`tests/banner_rule.tcl` sourced and run over the suite's **real captured output**:

```
--nogui  arm : banner_complete=1 banner_died=0 regression_case_failed(0)=0
               lowercase ^skip: = 0   uppercase ^SKIP = 0   ^RESULT: lines = 1
display  arm : banner_complete=1 banner_died=0 regression_case_failed(0)=0
               lowercase ^skip: = 0   uppercase ^SKIP = 0   ^RESULT: lines = 1
```

So `hcases` **alone** is right: both arms measure the identical check set, nothing in the suite is
display-only, and a `dcases` entry would measure the same thing twice. `hcases` is now **96**
entries, every one resolving to a file on disk (`tests/<entry>.tcl`), checked mechanically.
⚠ The capture above was taken at **88**; it was **re-derived from scratch at 89** after S15's hole was
closed, with the same instruments and the same verdict on both arms — **§9 carries the live figure,
and this one is the earlier measurement, kept dated rather than hand-edited.**

⚠ **No `skips=` figure is predicted here.** The two zeros above are a measurement of this suite's
output under `summarize_all`'s own two regexp arms, not a claim about the trailer. **Read the
trailer.**

### The behavioural proof that no comment landed between two `switch` patterns

`info complete` on `calc::cross_msg`'s body answers **1** either way, so the only confirmation is
behavioural. Every arm **derived from the proc's own body** (not listed) and exercised:

```
derived arms (n=31): absent allpoints badcycle badedge badlevel badnth badpct badref badtoken
  badxaxis dataset destalloc destempty destengine destlen destname destvalue empty engine
  intdataset listdefer nocycle nocycleat nodata nofall nohigh noname nosweep noswing stale zeroswing
ok=31  raised=0  empty=0  bad={}
unknown-kind -> rc=0 value={}          (the fall-through is still the empty string)
house-shape bad={}                      (capital + colon-space + full stop, every arm)
shared-identity: 1 1 1                  (cross_scalar / delay / dutyCycle_scalar, by identity)
```

### S24's own predicate, lifted and run on the real catalogue

That suite self-skips to 0 checks under `--nogui`, so lifting is the only headless method:

```
rows=108   fn_fields = name category route returns insert help
badrow (WIDENED vocabulary)   = {}
badrow (OLD vocabulary)       = {cross=returnsscalar/list}     <- the widening is NECESSARY
catcounts = 56 26 12 4 3 3 4 108                               <- UNMOVED
default-category = 56     badcat = {}
cross=scalar/list  intersect=scalar/wave  dutyCycle=scalar/wave
frequency=scalar/wave  freq=scalar/wave  riseTime=scalar  delay=scalar
```

The display arm then confirmed it for real: `test_calc_skeleton ALL PASS (548 checks)`.

---

## 4. The prose corrections — ENUMERATED

Re-derived by grepping `src/`, `doc/claude/` and `tests/` for the refuted claims rather than by
searching for a phrase: *(a)* the reference tool returns a waveform for `nth = 0`, *(b)* the verb
count / "critical path", *(c)* "a destination that can hold a **wave**" said of the LIST case,
*(d)* the stale "deliberate one-word disagreement with §7.2".

**Live sites corrected — 14:**

| # | site | changed to |
|---|---|---|
| 1 | `calc::cross_msg`'s **`listdefer`** arm — ⚠ **USER-VISIBLE** | *"so a destination that can hold **a wave**"* → *"so a destination that can hold **more than one** has to come first."* **ONE SHARED SENTENCE** — identity across all three callers re-measured (`1 1 1`) |
| 2 | `calc::cross_msg` header | *"the wave destination landing retires one string and not seven"* → *"a landing destination retires one string rather than one per caller"*, plus the two-destinations / mechanically-enumerated-callers note |
| 3 | `calc::cross_scalar` header | the whole *"waits for a destination that can hold a wave — which is what the reference tool returns here, plausibly through `xschem raw table_read`"* clause → *"waits for a surface that can hold a LIST"*, with the refutation and its origin recorded beside it |
| 4 | `calc::delay` header | *"one deferral string for every verb waiting on the wave destination … one string and not seven"* → per-caller wording + an explicit note that **this** caller wants a wave and `cross_scalar` does not |
| 5 | `calc::dutyCycle_scalar` header | *"the list waits for a destination that can hold a wave"* → the destination now exists; what it waits on is the **click**. *"three verbs waiting on one missing destination"* → two destinations |
| 6 | `calc::fn_fields` schema comment | `returns` vocabulary + `scalar/list`, and the four sites that move together named |
| 7 | `calc::catalogue` comment, ¶1 | *"§7.2 spells `cross` `scalar/list`, which is that row's one violation"* → the vocabulary is now five words and the conflict does not exist |
| 8 | `calc::catalogue` comment, ¶2 | the three reasons for `scalar/wave`, incl. *"the reference tool returns a WAVEFORM for `nth = 0`"* → **removed**, with R419 and the `grep -c '#pragma'` lesson recorded |
| 9 | `calc::catalogue` comment, ¶3 | *"this row and spec §7.2 DISAGREE BY ONE WORD … deliberate"* → **removed**; and why the spelling is now load-bearing |
| 10 | `calc::catalogue` comment, `dutyCycle` ¶ | *"the permitted set is `scalar`, `wave`, `bool`, `scalar/wave` and nothing else"* and *"§7.2's row still reads `scalar`"* → both stale, dropped |
| 11 | `calc::catalogue` **`cross` row** | `scalar/wave` → **`scalar/list`** (code, not prose) |
| 12 | `test_calc_skeleton.tcl` S24 | vocabulary + `scalar/list`, with why `intersect` is left alone |
| 13 | `test_calc_measure.tcl` MT8 comment | *"every verb waiting on the wave destination … one string and not seven"* → per-caller, plus the two-destinations note |
| 14 | `test_calc_scratch_reuse.tcl` SR5 comment | the four-way-equality paragraph rewritten for the READERS anchor |

**Contracts corrected — 4 (superseded, never deleted):**

| # | site | changed to |
|---|---|---|
| 15 | `CROSS_CONTRACT.md` **D8** | the **origin** parenthetical kept verbatim with a new ⚠⚠ block beside it naming R419, the propagation path, the independent precision kill of `table_read` (issue 1633), and D9's mis-attribution |
| 16 | `TIMING_CONTRACT.md` **R416** | both sentences kept with a blockquote correction: the clause, the count wrong **twice** (incl. the driver's own first correction), `riseTime` raising (1639), and "critical path" no longer describing anything; plus R420 |
| 17 | `DESTINATION_CONTRACT.md` §intro | *"three verbs … `calc::cross` with `nth = 0`, `calc::dutyCycle`'s default, and the unbuilt `frequency`"* → the corrected four callers over two destinations, naming all three ways the original was wrong |
| 18 | `DESTINATION_CONTRACT.md` §1 | *"must be corrected to **two verbs**"* → replaced, and the dated-record policy stated. ⚠⚠ **This is the THIRD NESTING of the same failure in one stage**, and the driver has adopted it in those terms: a wrong correction surviving **inside the paragraph that demands corrections be made**. The first was the catalogue comment's dead Cadence reason (#8); the second was the contract reproducing that dead claim in the document written to correct dead claims (§4 of the contract records it); this is the third. The pattern is CLAUDE.md's `grep -c '#pragma'` failure every time — **a correcting sentence becoming its own counterexample** — and the only method that has not produced one is enumerating the sites mechanically instead of searching for the phrase |

**One more, and it is a dated record given a note rather than an edit:**

| # | site | what was done |
|---|---|---|
| 19 | `doc/claude/issues/1639-*.md` "## Measured" block | the transcript quotes the OLD product sentence. **Not edited** — it is a dated capture. A note beside it records the rewording, that nothing about the issue changes, and that MT7/MT8 compare by identity. `issue_stamp.tcl` re-run: `ok (0 problems)` |

**Deliberately left alone — dated records, superseded not deleted** (per the brief; the correction
now stands beside them in the contracts): `doc/claude/calculator_batch/LEDGER.md` (¶ at *"And the
verb count was wrong twice"* and the `scalar/list` items), `receipts/G-timing-verbs-recon.md`
(*"Three verbs behind one missing piece makes that destination the measurement layer's critical
path"*), `receipts/F2-cross-suite-and-implementation.md` (*"the reference tool returns a waveform
for `nth = 0`"*), `receipts/G2-timing-verbs-suite-and-implementation.md`,
`receipts/H-destination-recon.md`. ⚠ `DESTINATION_CONTRACT.md` §1's own obligation sentence asked
for *"the two receipts"* to be corrected; the driver's brief overrides that with the
superseded-not-deleted rule, and this receipt is where the correction lives instead.

Also checked and found **already correct** (the driver had done them): `doc/claude/specs/calculator.md`
— §7.2's `cross` row is `scalar/list`, R416's note carries both corrections, and §7.2ab's vocabulary
already lists five terms. Nothing was changed there.

---

## 5. What I sabotaged, and what caught it

Every mutation applied to the real tree, run, then reverted; `md5sum -c` confirms all three touched
files came back **byte-identical**.

| # | the plausible wrong implementation | caught by |
|---|---|---|
| S1 | **one** restore instead of two (no post-clear switch) | WD3 ×2 (post-clear, field-by-field), WD5/WD7 hygiene — `4 FAILED` |
| S2 | name-only `xschem raw switch <name>` (the round-robin trap) | WD3 ×4 + WD5/WD7 — `6 FAILED` |
| S3 | one FIXED destination name (reuse) | WD7's second-evaluation row — `1 FAILED`, narrow to exactly one |
| S4 | trust `raw new`'s rc; no empty-list refusal | WD7 ×5 — `5 FAILED` |
| S5 | over-allocate **and** zero-pad together | WD5 ×3 + WD2 ×2 + WD7 + WD8 — `7 FAILED` |
| S6 | store through the lossy `%.8g` door | WD6 ×2 (1e-12 and bit-exact) — `2 FAILED`, nothing else |
| S7 | default `xaxis` = `mid` instead of `start` | WD8 ×4 — `4 FAILED` |
| S8 | `number` axis 0-based instead of 1-based | WD8 ×2 — `2 FAILED` |
| S9 | `graph_props` emits a **SHORT** sweep list | WD4 ×5 — `5 FAILED` (the silent-re-axing defect) |
| S10 | `graph_props` never emits the token | WD4 ×5 — `5 FAILED` |
| S11 | `sweep` as `add_trace`'s **6th** parameter | WD4's arity/position row — `1 FAILED` |
| S12 | `cross` forgets its R402 delete | **widened SR5**'s equality row — `1 FAILED` (the widening did not weaken it) |
| S13 | a **second** add-without-read door in the namespace | **widened SR5**'s new one-name-literal row — `1 FAILED` |
| S14 | the helper named **`calc::dest_new`** | WD10 ×4 (+20 collateral) **and `test_calc_engine` CE8**, which is `hcases` and gates — the measured naming trap confirmed |

### S15 — ONE SABOTAGE SURVIVED. ⚠ **CLOSED IN §9 ON THE DRIVER'S RULING** — the section below is the finding as first reported, kept because the reasoning that overruled it is worth having beside it.

`set swdflt time` — hardcoding the ordinary trace's X name instead of reading it — gives
`ALL PASS (88 checks)`. WD4 only ever drives `graph_props` with the **`tran`** fixture current, where
the database's own X name *is* `time`, so the two implementations are indistinguishable there. The
suite declares H1–H9 and **this is not one of them** (H5 is adjacent — it says an `ac`/`op`-SOURCED
destination is unfenced — but this is about the ordinary traces' token on an `ac`-CURRENT database).

Measured, so the shipped behaviour is not in doubt:

```
tran current : first vector = time       sweep_default = time
ac   current : first vector = frequency  sweep_default = frequency
ac-current sweep tokens = {frequency calcx frequency}      <- a hardcoded `time` would be wrong here
no database  : sweep_default = {}  and graph_props emits NO sweep= token (the declared fallback)
```

**Not fixed, and deliberately so**: closing it means adding a row, which moves the suite's published
check count off the **88** that this stage's registration derivation, both-arm measurement and
`RESULT:` line all quote — and silently moving a published figure is the exact failure mode this
batch keeps catching. The one-line row for whoever wants it, in WD4, after a `xschem raw read
$::fixture ac` + `xschem raw switch $::fixture ac`:

```tcl
check "WD4 the ordinary traces' token is READ from the current database and not hardcoded: with an ac
       database current the same strip names frequency, so a producer that wrote `time` reddens here" \
    [list [wd_at $tmac 0] [wd_at $tmac 1] [wd_at $tmac 2]] {frequency calcx frequency}
```

---

## 6. What I got wrong, and what corrected me

**The first implementation used `xschem raw rawfile` + `xschem raw sim_type` to capture the user's
slot, and row S27 of `test_calc_skeleton` caught it** — `1 FAILED (547 passed)`:

```
FAIL: S27 U6 and the self-arm reader is gone from the source too -> {2} (exp {0}) : FAIL
```

That row greps the decommented `src/calculator.tcl` and requires `raw rawfile` to appear **zero**
times, because **U6 is a user ruling** (`results_selection.md` §17 decision 6): the Calculator's
`self` arm was removed entirely and it must never resolve a result out of the raw its own context
happens to hold. A textual grep cannot tell *"resolve a result"* from *"remember which slot to put
back"* — so the row looked wrong and it was not. **The row is right.**

The fix dissolved the conflict instead of widening the fence: `calc::wave_dest_cur` reads
`xschem raw info`, which is **not** the self-arm reader, and that turned out to be better engineering
on its own merits — ONE snapshot answering the name and the type **together**, where two accessors
are two reads that could disagree, and both halves are needed because the fixture's three slots share
one path and differ only in type. `raw rawfile` now appears **0** times in the decommented file and
S27 is back to `ALL PASS (548 checks)`.

Two smaller ones. A multi-line `{braced}` message string was written before checking whether
backslash-newline substitution applies inside braces; switched to the file's existing `"..."`
continuation idiom rather than relying on a rule I was not sure of. And a `perl -0pi` sabotage of
`graph_props` silently did not apply (`\"`/`\n` escaping) and the suite read `ALL PASS` — caught only
because the post-patch `grep -c` control said the line was still there. **A sabotage needs a control
proving it landed**, or a surviving mutation and a failed patch are indistinguishable.

---

## 7. What I did NOT do

* **No commit, no push, no stash.** Everything is uncommitted. **No full T1** — the driver's job.
* **Issue 1639** (`calc::riseTime` raising on `nth = 0`) untouched, as scoped. WD9 **derives** the
  deferral-caller set, so fixing 1639 by making `riseTime` defer will redden that row **naming the
  undriven caller** — correct behaviour, and a legible instruction for whoever does it.
* **`wviewer::interp_value` untouched** — contract §8's third change site, issue **1637**, suite hole
  H1. The Tcl cursor readout on an own-X trace is still computed against column 0. The C-side
  in-graph measurement is already correct; only the readout bar is not. Needs a viewer window and a
  mixed strip, i.e. a `dcases` viewer suite.
* **`intersect` untouched** (stays `scalar/wave`) — deliberate, per the contract: no proc yet, and
  respelling drags its user-visible help text. **One `rule` debt when `intersect` is built.** I did
  not file it; ledger writes are the driver's.
* **`calc::dutyCycle_scalar` does not forward `xaxis`.** Its wave case defers and its scalar case
  lands a number in the buffer (R404) where an X has nowhere to be shown. Declared in the source so
  it is not read as an omission.
* **Phase 5's click wiring, `frequency`, and the Table/list surface** — out of scope. ⚠ **A green
  destination is not a feature**: `calc::fn_click` dispatches on `calc::fn_reason`, empty for route
  `T`, and falls through to `calc::inert … 5`. `cross`, `riseTime`, `delay` and `dutyCycle` are still
  **not clickable**. Phase 5 owns R410/R411/R412.
* **`wviewer::plot_sweeps_arm` has no armer yet** — shipped with the destination because the
  alternative shape (a fifth `plot_signals` parameter) is the one three test pins forbid, and
  discovering that from a gate is what it exists to prevent. Declared in the source comment.
* **Nothing verified by eye.** No `look` debt filed — the one thing worth eyes is already recorded as
  the contract's own H2 debt (that the engine *draws* the token; the fence asserts the positive shape
  upstream of all seven walkers).

### Declared unfenced

Suite hole **H8**, restated because it is this proc's: leak hygiene across a **throw** between
`raw new` and the restore. Every exit path restores and the fill sits inside one `catch`, so the
window is narrow — but it is narrow, not closed, and nothing drives it.

---

## 8. Things the next stage must know

1. ~~**S15 above.** The `sweep_default` read is unfenced on an `ac`-current database.~~ **CLOSED, §9**
   — the row is in band WD4, the published count is **89** on both arms, and the registration delta is
   unchanged. The lesson generalises and is the one worth carrying: **a published check count is not a
   baseline, it is an instrument's output** — every site that carries it re-measures it — so it must
   never be weighed against coverage you know to be fake.
2. **`xschem raw info` is the accessor for the current slot inside `calculator.tcl`**, not
   `raw rawfile`. Row S27 is a user ruling expressed as a grep — do not reach for the obvious pair.
3. **The `listdefer` sentence must stay ONE shared string.** MT7/MT8 compare it by identity.
   Rewording is free; splitting per caller reddens both, and WD9 now fails first with a name.
4. **`calc::dest_*` is a forbidden prefix in `::calc::`** — re-confirmed by mutation: `calc::dest_new`
   reddens `test_calc_engine` CE8 (`hcases`, gating) as well as WD10.
5. **The producer sizes the database exactly**, which retires the contract's hold-pad requirement and
   its `raw pos_at` note. WD5's two tail rows are vacuous against an exactly-sized producer and say so.
6. **Three shipped-verb defects are load-bearing here and are filed**: 1635 (`raw new` lies about
   allocation), 1636 (`raw clear` forces slot 0), 1633 (`table_read`'s float parser). The producer is
   built around all three; fixing any of them should not change its behaviour, but it would make part
   of it redundant.
7. ⚠ **Do not predict the T1 trailer.** `hcases` is 96 entries, 124 cases by arithmetic, and the
   suite emits no skip announcement of either case on either arm — that is a measurement of this
   suite, not a prediction of `skips=`. **Read the trailer.**

---

## 9. S15 CLOSED — the row added, and the figure RE-DERIVED rather than preserved

**The driver overruled §5's decision on the merits, and the reasoning is adopted here as written**
because it corrects a real error of judgement on my part:

> *A surviving sabotage is a hole in the fence, and this one has a live failure mode … A fence that
> passes against its own defect is worse than no fence, because it reads as coverage. That judgement
> outranks the cost of moving a published number.*
>
> *And the cost is smaller than it looks.* `cases`, `blocks`, `counted_failures` and `skips` are all
> independent of a suite's check count, and `wc -l` moves with the **number** of `RESULT:` lines, not
> with their contents. The 88 appeared in exactly three places and **all three re-measure it every
> run** — the suite's own `OVERALL:` and `RESULT:` lines, and the both-arm `banner_rule` capture.

**What I got wrong**: I treated a published figure as if it were a committed baseline. It is not —
every site that carries it is an instrument that re-derives it. Weighing "coverage I know is fake"
against "a number three instruments recompute" was the wrong trade, and the tell was available: I had
already *measured* the live failure mode (`ac` → `frequency`) before deciding not to fence it.

### What was added

`wd_load1ac` — the fixture read as the **AC** analysis — and **one row, last in band WD4**:

```tcl
    set tmac {} ; set acsw {}
    if {[pcall wd_load1ac] eq {1}} {
        set acsw [wd_at [wd_rawnames] 0]
        set tmac [wd_sweeptoks [wd_wv graph_props [wd_graph $mixed]]]
    }
    check "WD4 the ordinary traces' token is READ out of the current database and never hardcoded: …" \
        [list $acsw [wd_len $tmac] [wd_at $tmac 0] [wd_at $tmac 1] [wd_at $tmac 2] \
              [string equal [wd_at $tmac 0] $sw]] \
        [list frequency 3 frequency calcx frequency 0]
    pcall wd_load1
```

The last leg is the discrimination stated **positively as a difference**: the token must not be the
`tran` sweep name, which is exactly the hardcoded answer. `$acsw` rides along so the row cannot pass
on a database that is not actually AC. The band's hygiene row was extended to assert the restore
(`sim_type tran` and `xschem raw index $sw == 0`), and the suite header, WD4's description and hole
**H5** were all updated so the file's own prose matches what it now measures.

### Both directions, with a control proving each patch landed

```
--- S15 re-applied ---
patch-control: 1 occurrence of the mutation, 0 of the correct line
FAIL: WD4 the ordinary traces' token is READ out of the current database and never hardcoded: …
      -> {frequency 3 time calcx time 1} (exp {frequency 3 frequency calcx frequency 0}) : FAIL
RESULT: 1 FAILED (88 passed)        <- NARROW TO EXACTLY ONE ROW, and it names the defect:
                                       `time` where `frequency` belongs, and the `$sw` leg answering
                                       1 (it IS the tran name) where it must answer 0

--- reverted ---
revert-control: 0 mutation, 1 correct      md5sum -c src/wave_viewer.tcl: OK
OVERALL: ok (89 checks)
RESULT: ALL PASS (89 checks)
```

### ⚠ And the OTHER direction the driver named — that an `ac`-current band could make its own
### neighbours vacuous. Both hazards are fenced, measured:

| mutation of the suite | what reddens |
|---|---|
| **V1** — drop the `pcall wd_load1` restore, leaving `ac` current at band exit | WD4's hygiene row, **exactly one**, naming the current database — `RESULT: 1 FAILED (88 passed)` |
| **V2** — the obvious WRONG PLACEMENT: do the `ac` read **before** the band's checks | `WD4 …the ordinary traces' token names a REAL column of the loaded database…`, **exactly one** — `RESULT: 1 FAILED (88 passed)` |

So the placement is not a convention: V2 proves the three rows that resolve a column name against the
**current** database at check time really would fail if the `ac` read moved above them, and V1 proves
a missing restore is caught rather than inherited by the next band. `md5sum -c` after each revert: OK.

### The figure, RE-DERIVED from scratch on both arms — never hand-edited

`tests/banner_rule.tcl` sourced, and `summarize_all`'s own counted-shape and `^skip:` arms lifted and
run over each arm's real captured output:

```
--nogui arm : banner_complete=1  banner_died=0  regression_case_failed(0)=0
              ok:-lines=89  FAIL-lines=0  counted-shapes=0
              lowercase ^skip: =0  uppercase ^SKIP =0  ^RESULT: lines=1  ^OVERALL: lines=1
              OVERALL: ok (89 checks)        RESULT: ALL PASS (89 checks)

display arm : banner_complete=1  banner_died=0  regression_case_failed(0)=0
              ok:-lines=89  FAIL-lines=0  counted-shapes=0
              lowercase ^skip: =0  uppercase ^SKIP =0  ^RESULT: lines=1  ^OVERALL: lines=1
              OVERALL: ok (89 checks)        RESULT: ALL PASS (89 checks)
```

**The published count is 89, identical on both arms, and the delta is exactly +1 on each** — which is
what the driver asked to be told either way. Derived three independent ways that agree: the suite's
own `npass`, the `OVERALL:`/`RESULT:` lines, and a count of `^ok: ` lines by the probe.

⚠ **The registration delta is UNCHANGED**: still **cases +1, blocks +1, counted_failures +0,
skips +0, `wc -l` +3**. The check count is not a term in any of them, and `wc -l` moves with the
**number** of `RESULT:` lines — still exactly one. `hcases` remains 96 entries. **No `skips=` figure
is predicted here; read the trailer.**

### Re-runs after this round

No **product** code changed in this round — `src/calculator.tcl` and `src/wave_viewer.tcl` are
byte-identical to the state every sibling above was verified against, confirmed by `md5sum`
(`f8407c02…` and `8259c7f4…`). So no sibling can be affected by construction. Re-run anyway rather
than reasoned, since it is cheap and a claim that is checked beats one that is argued:

| suite | arm | result |
|---|---|---|
| `test_calc_wave_dest` | `--nogui` / display / armed display | `ALL PASS (89)` ×3 |
| `test_calc_scratch_reuse` | `--nogui` | `ALL PASS (54 checks)` |
| `test_calc_engine` | `--nogui` | `ALL PASS (265 checks)` |
| `test_calc_cross` | `--nogui` | `ALL PASS (187 checks)` |
| `test_calc_measure` | `--nogui` | `ALL PASS (125 checks)` |
| `test_registered_banner_1626` | `--nogui` | `ALL PASS (10 checks)` — the registered set's banners re-measured after the count moved |

### §5's S15 entry, superseded

The sabotage table's S15 row stands as the finding; **the decision attached to it is reversed**, and
the mutation is now caught by exactly one row that names it. **15 of 15 sabotages are fenced.**
