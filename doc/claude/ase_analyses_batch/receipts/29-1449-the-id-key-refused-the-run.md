# ⚖ R6's tail — naming an analysis stopped the bench running (issue 1449)

**One task, one word, and the rows around it.** `src/ase.tcl` +
`tests/headless/test_ase_core.tcl` + the 1449 issue file + `NUMBERING.md`.
**`src/ase_window.tcl`, `test_ase_dialogs.tcl`, `test_ase_persist.tcl`,
`test_ase_meas_1443.tcl` and `run_regression.tcl` were NOT opened for writing**
(`ase_window.tcl` was read only). No commit, no `git add`, no stash, no restore,
no clean, no push. T1 not run (issue 0990 — the driver's, solo).

**Floor: `test_ase_core` 622 → 624**, both arms. The file's own floor paragraph
and the EK header note are in the same diff.

`src/ase.tcl` +27/−1; **exactly one added line is not a comment**:

```
$ git diff src/ase.tcl | /usr/bin/grep '^+' | /usr/bin/grep -v '^+++' | /usr/bin/grep -v '^+  #'
+  set known [list type enabled x id]
```

---

## 1. THE REPRODUCTION, TAKEN BEFORE ANYTHING WAS CHANGED

`/tmp/id1449/repro.tcl`, against the unfixed tree at `e45a1175`. The bench is one
enabled `dc` row that declares a name: `{type dc enabled 1 id vinsweep source V2
start 0 stop 1.8 step 0.01}`.

```
=== A. the row itself ===
emit_check WITH id : {unknownkey id {has a setting named 'id' that ASE-L cannot emit}}
emit_check NO   id :

=== B. the gate ===
verdict WITH id    : emit_incomplete
--- what the user sees, verbatim: ---
| ase: the dc analysis has a setting named 'id' that ASE-L cannot emit
| ase: it is enabled on this bench, so the run would have started and produced nothing
| for it. Nothing was generated: no deck, no raw, no log. `set ase_preflight 0` does
| NOT disable this check.
verdict NO   id    : ''   (empty = the run proceeds)
said NO id         : 0 line(s)

=== C. `set ase_preflight 0` does not disable it ===
verdict WITH id, preflight off : emit_incomplete

=== D. the deck the refusal withholds ===
render_deck NOID   : rc=0  analysis line = 'dc V2 0 1.8 0.01'
render_deck WITHID : rc=0  analysis line = 'dc V2 0 1.8 0.01'

=== E. ase::analysis_handle, the thing the id is FOR ===
handle WITH id : vinsweep
handle NO   id : dc1
```

(The two refusal lines are wrapped here for the page; they are two `ase::echo`
calls, printed on one line each.)

⚠ **Section D is the sentence worth carrying forward.** The id-ful and id-less
benches render the **same deck, byte for byte**. `id` is a name, not a setting,
and no template was ever going to spend it — so the gate was **withholding a deck
it had no complaint about**. That is a sharper statement than "the refusal fires
too early", and it is what the fix's comment says in place.

The same script after the fix: every line of A, B and C empty, D and E unchanged.

## 2. The change, with its anchor

`src/ase.tcl:4640` (was `:4615`):

```tcl
-  set known [list type enabled x]
+  set known [list type enabled x id]
```

The 26 comment lines above it say three things that are not re-derivable from the
word: what the defect cost, **why `id` is exempt for the OPPOSITE reason to `x`**
(`x` is exempt because it *emits*; `id` because it is the row's *name* and never
was a setting — and `unknownkey`'s job is refusing a key that would **silently**
not emit), and **do not generalise this into "ignore unknown keys"**, naming D4,
1418 and 1401.

## 3. The rows: EK7 and EK7c, in `test_ase_core.tcl` beside the emit checks

Placed after **EK6**, the corpus invariant — which is exactly the row that could
not see this, because **no committed bench carries an `id`** (104 files, 416
analysis rows, zero). EK6's own header note now says so.

**EK7** is not "does `emit_check` accept `id`". It is an **enabled row carrying an
`id` walked to a rendered deck in one expression**, seven terms:

| term | why it is there |
|---|---|
| `emit_check` → `{}` | the allow-list |
| `ek_gate` verdict → `{}` | the gate, which is where it bit |
| the deck's `dc ` line → `dc V2 0 1.8 0.01` | **positive control**: a literal golden, so the row cannot pass on an extraction that returned nothing |
| the two decks `string equal` → 1 | the `id` changes **nothing** in the deck |
| `string length > 100` → 1 | **positive control on the term above** — `string equal` on two empty strings is also 1 |
| `analysis_handles` with the id → `vinsweep` | the fixture really is ⚖ R6's, not a spare key |
| `analysis_handles` without it → `dc1` | **the fixtures DISAGREE**, which is the whole subject |

**EK7c** is the over-width control: the same row plus `nonsense 1` is still
refused (`unknownkey nonsense`), still stops the gate, and **the offence count is
exactly 1** — that fourth term is what says the `id` beside it was not counted.

## 4. Both arms, before and after, from the `RESULT:` line

| suite / arm | before | after |
|---|---|---|
| `test_ase_core` headless | `ALL PASS (622 checks)` | `ALL PASS (624 checks)` |
| `test_ase_core` display (`:99`, Xvfb + openbox) | `ALL PASS (622 checks)` | `ALL PASS (624 checks)` |
| `test_ase_dialogs` headless | `ALL PASS (37 checks)` | `ALL PASS (37 checks)` |
| `test_ase_dialogs` display | `1 FAILED (339 passed)` | **`2 FAILED (338 passed)`** — see §5 |
| `test_ase_preflight` both | — | `ALL PASS (235)` / `ALL PASS (235)` |
| `test_ase_persist` | — | `ALL PASS (49)` / `ALL PASS (153)` |
| `test_ase_meas_1443` | — | `ALL PASS (100)` / `ALL PASS (100)` |
| `test_ase_options_1437` | — | `ALL PASS (75)` / `ALL PASS (75)` |
| `test_ase_window` | — | `ALL PASS (56)` / `ALL PASS (295)` |

Every baseline was **re-measured here** before any edit and matched the dispatch
exactly, including the red's actual value. Five extra suites were run because the
changed proc's consumers are `ase::preflight_gate` and `ase::ui::chana_ok`'s D6
probe; each arm under a hard `timeout` (400 s headless, 600 s display).

## 5. ⚠ CORRECTION TO THE DISPATCH: `GH13b` GOES RED, AND THAT IS THE POINT

The dispatch says *"check that your fix reddens nothing there \[in
`test_ase_dialogs`\] by running it, and say so."* **It reddens exactly one row,
by design.** `GH13b` was written by receipt 28's task to pin this defect, and its
own header says so: *"Fixing it turns that row RED, which is the point."*

```
FAIL: GH13b KNOWN DEFECT (issue 1448): the emit check has never heard of the id key
 ⚖ R6 added ... -> {{} {} {} {}} (exp {unknownkey id emit_incomplete {}}) : FAIL
```

Nothing else moved: **339 passed → 338 passed**, one row, and the other red is the
standing `G2sens` (issue **1436**, `{1 1 0 1 0 Entry Entry normal}`) — the same
value before and after. Headless is unmoved at 37 because section GH is
display-only. **`GH13b` and its paragraph now describe a fixed defect and must be
rewritten; that file was not mine to touch.** It is §9's first hand-over item.

## 6. The `.state` byte-identity measurement

```
$ git ls-files -- '*.state' | wc -l
104
$ timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/id1449/state_roundtrip.tcl
STATEFILES: 104
MISMATCH:   0
ANALYSIS-ROWS: 416
ANALYSIS-ROWS-WITH-id: 0
CONTROL-DISAGREES: 1
$ git status --porcelain -- '*.state'
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state
```

— untracked, pre-existing at hand-over, not mine. **Zero tracked `.state` files
modified.** `CONTROL-DISAGREES` is the non-vacuity leg: one `id` added to one
committed row must stop round-tripping, or the comparison is measuring nothing.
The suite carries the same measurement as `CP7`/`CP7c`, green in the 624.

**No new state key, no schema version bump, nothing added to
`ase::omit_if_empty`.** `id` already existed; one reader was taught about it.

## 7. Sabotage — six mutations plus one finding, generator `/tmp/id1449/sab.py`

Every arm: `python3 sab.py <id>` writes the mutant **from a pristine copy** → run
the suite under `timeout 500` → `sab.py restore` → md5 against both pristine
files. **No mismatch was printed on any arm.** Final state:

```
fff39afcb1e24ab9a928a5a5b88ae2cc  src/ase.tcl
6bfed793f18b7820e2c8d83efd252232  tests/headless/test_ase_core.tcl
```

| # | what I broke | `RESULT:` | what reddened, and on which term |
|---|---|---|---|
| **s1** | the one word reverted — **the defect, back** | `2 FAILED (622)` | **EK7** got `{{{unknownkey id …}} emit_incomplete …}`; **EK7c** got count **2**, not 1 |
| **s2** | the allow-list accepts **everything** (the over-wide fix) | `2 FAILED (622)` | **EK7c** (`{{} {} {} 0}`) **and GR9**, the 1418 row in a section this change did not write |
| **s3** | CONTROL — EK7's fixture loses its `id` | `1 FAILED (623)` | **EK7**, handle terms `dc1 dc1` — the fixtures stop disagreeing |
| **s4** | POSITIVE CONTROL — the deck-line extractor never matches | `1 FAILED (623)` | **EK7**, third term empty |
| **s4b** | POSITIVE CONTROL — both decks replaced by `{}` | `1 FAILED (623)` | **EK7**, on the **length floor**: `1 0`. Two empty strings *are* `string equal` |
| **s5** | CONTROL — EK7c's nonsense key is not nonsense | `1 FAILED (623)` | **EK7c** |

⚠ **`s4x` IS A FINDING, NOT A WITNESS.** Making `ase::analysis_line` return `{}`
— no analysis card reaches any deck — does **not** redden EK7. It **kills the
suite at check 41**, line 5649, `ase: analysis type 'op' is not one this
simulator backend can render`, **no `RESULT:` line, rc 0** (`--nogui --pipe`
exits 0 on an uncaught mid-script Tcl error — CLAUDE.md's own note). G2tf's
failure shape, met again by a fourth route. Kept in the generator so nobody
re-derives it, and it is why s4/s4b are narrow.

### The four ways a row fails to fail, answered

1. **Fixtures that never disagree — THIS DEFECT IS THAT FAILURE**, for the
   eleventh time in this batch and the first across two files. Answered by
   construction: EK7's last two terms make `$EK7ROW` and `$EK7BARE` **disagree
   about their own handle** (`vinsweep` vs `dc1`), and s3 is that control's own
   sabotage. Without them every other term is satisfied by code that ignores `id`
   completely.
2. **Position asked where the mechanism is last-writer-wins.** Nothing here
   asserts an ordering. The deck term asks for **byte equality of two whole
   decks** plus a literal golden line.
3. **An extractor that returns nothing.** Two positive controls, both sabotaged:
   the literal `dc V2 0 1.8 0.01` (s4) and the length floor that stops
   `string equal` passing on two empties (s4b).
4. **A sabotage missing from the generator.** s3 and s5 sabotage the two
   **controls**; s2 is the one that guards the fix from being *too wide* and is
   the only way a one-word fix can be wrong — and it is the one that reddens a row
   in a section this change did not write.

## 8. Does anything else read that allow-list? — ⚠ YES, AND IT IS A SECOND DEFECT

**Measured, not asserted** (`/tmp/id1449/otherreaders.tcl`). Two sites in
`src/ase_window.tcl` enumerate a row's legal keys independently of
`ase::analysis_emit_check`:

* **`:5824`** — `chana_options`, seeding `anextra` from the stored row;
* **`:5973`** — `chana_x_ok`, stripping the row before write-back.

Both are `set skip [concat {type enabled} [ase::ui::chana_fields $type $_sim]]`,
and `chana_fields` is the declared field names only:

```
skip                                  : type enabled source start stop step source2 start2 stop2 step2
anextra seeded from a row with both   : id vinsweep x {{echo hi}}
chana_x_ok's OK loop would refuse     : id x
```

So opening `Options…` on a row carrying **either** D4 key shows it as a free-text
pair and then **refuses to save** — `chana_x_ok` returns before writing, so the row
is not damaged but the editor cannot be used on it at all. ⚠ **`x` has been in
this state since issue 1419**: this is not a 1447 regression, it is the third
instance of one class (`emit_check`, and these two sites). It needs its own issue
number and a fix in `src/ase_window.tcl`, which was not my file. Recorded in
1449's *What is still owed* and in `NUMBERING.md`'s entry.

**Nothing else does.** `/usr/bin/grep -n 'dict keys \$\(row\|arow\|cprow\|r\)\b'`
over `src/ase.tcl` and `src/ase_window.tcl` returns **exactly two** sites:
`ase.tcl:4644` (the one I fixed) and `ase_window.tcl:5974` (the one above).
`ase::schema_keys` / `omit_if_empty` are the **top-level** state keys and `id` is
per-row, which is 1447's own argument and what `CP7` measures.

⚠ **One near-miss, measured rather than reasoned about.** `ase::ui::arg_summary`
has a fall-through loop (`ase_window.tcl:1619`) that skips `type`, `enabled` and
`x` **and not `id`** — so a row declaring one looked like it would render
`id=vinsweep` into the Arguments column, a word the deck does not carry. It does
not: the proc returns the rendered analysis line before reaching that loop.

```
arg_summary enabled+id  : 'dc V2 0 1.8 0.01'
arg_summary disabled+id : 'dc V2 0 1.8 0.01'
arg_summary enabled bare: 'dc V2 0 1.8 0.01'
```

**Identical on both sides of the fix** (taken again under sabotage `s1`), so this
change moves nothing in that column. Recorded because the loop reads like a defect
and the next person to look will re-derive it.

## 9. For the driver

1. ⚠ **`test_ase_dialogs.tcl` row `GH13b` is now RED and must be rewritten** — a
   known-defect row whose defect is fixed. §5 has the exact line and the
   before/after counts. **The display arm of that suite is at 2 FAILED (338
   passed) until it is**, and one of those two is the standing 1436. That file was
   outside my scope.
2. **A second issue is owed** for `src/ase_window.tcl:5824`/`:5973` (§8). I did not
   mint a number for it: the driver verified only 1449 against the clones and the
   bands.
3. **`NUMBERING.md`'s pointer advanced 1449 → 1450.** Both mint checks were run at
   the moment of minting: the reserved-band scan over this clone's head table
   (**silent** for 1449) and `ls ~/dev/*/doc/claude/issues/1449-*` plus
   `/usr/bin/grep -lw 1449` across every clone's `NUMBERING.md` (only this clone's
   own pointer line).
4. **No new user-facing sentence, so no `owed.sh add rule 1449`.** The diff's only
   non-comment added line is the allow-list; `ase::analysis_emit_msg` is untouched.
   The user-visible change is that a sentence **stops** being shown. No `look`
   debt either — nothing draws pixels. No `suite` debt: the covering suite runs
   headless and was run on both arms anyway. **The ledger was not touched at all.**
5. **T1 was NOT run by this crew.** `run_regression.tcl` runs `test_ase_core` on
   both arms, so T1's number **does** move — its baseline is zero failures and
   this change takes `test_ase_core` from 622 to 624 checks with no new failures
   on either arm, measured directly.
6. **HEAD did not move under this task.** Handed over at `e45a1175`; still there.
   Working tree: **three modified** (`src/ase.tcl`,
   `tests/headless/test_ase_core.tcl`, `doc/claude/issues/NUMBERING.md`) and **one
   new** (`doc/claude/issues/1449-naming-an-analysis-stopped-the-bench-running.md`,
   plus this receipt). The four untracked paths inherited at hand-over are
   untouched.
7. **The binary was not rebuilt and did not need to be** — checked rather than
   assumed: `find src -name '*.c' -newer src/xschem` and the same for `*.h` both
   print **nothing**, so the Sep 5 binary is current for C; only `.tcl` files are
   newer, and those are read from `XSCHEM_SHAREDIR` at run time.

## 10. Commands, for the driver to re-run

```sh
cd /home/analog/dev/xschem-claude
timeout 200 ./src/xschem --nogui --pipe -q --nolog --script /tmp/id1449/repro.tcl
timeout 400 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl
timeout 600 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_core.tcl
timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/id1449/state_roundtrip.tcl
timeout 200 ./src/xschem --nogui --pipe -q --nolog --script /tmp/id1449/otherreaders.tcl
/tmp/id1449/runsab.sh s1 s2 s3 s4 s4b s5
```
