# 02 — one lookup ladder in `get_raw_index` (+ the VCD sub-step)

`PLAN.md` §3b item 2 · `DESIGN_REVISION.md` §4/§10.3/§10.4 · `DECISIONS.md` **D2**
· spec **extended, not replaced**: `specs/raw_case_mode.md` **§9**. Base
`d9b48798`, `fluid-editing`, nothing pushed.

## 1. Files changed

```
 src/save.c 207 +- (the ladder + the alias index) · src/xschem.h 17 + (Raw.fold_table)
 src/vcd_read.c 28 +- (apology retired as the RULE) · src/wave_viewer.tcl 69 +- (gate)
 tests/headless/: test_raw_case_mode.tcl 409 +- (81 -> 186) · test_backannotate_digital.tcl 17 +-
 doc/claude/specs/: raw_case_mode.md 254 +- (§9) · mixed_signal_signal_browser.md 18 +-
 doc/claude/: casemode_batch/DESIGN_REVISION.md 42 + · code_analysis/ngspice_case_sensitivity.md 11 + · doc/xschem_man/developer_info.html 17 +-
 11 files changed, 1012 insertions(+), 77 deletions(-)
```

One ladder that **never mutates the query**: exact → case-folded alias → both
`v()`-wrapped → both with an anchored, case-blind `i(v.x` prefix rewritten to
`i(x`; the folded rungs served by a lazy alias index over `names[]`.

## 2. Decisions, and the evidence for each (all written into spec §9)

- **The alias index is a SEPARATE table, not entries in `raw->table`**,
  overriding the *mechanism* `DESIGN_REVISION.md` §4 proposed (its rule stands; a
  CORRECTION says so in place). Three fatal reasons: D2's poison would land on a
  **real stored name** (the fold of `v(EN)` where `v(en)` also exists), breaking
  the exact lookup D2 leaves alone; `raw_add_vector()` tests that table for
  existence, so an alias makes `raw add v(en)` a silent no-op; and rename/delete
  go by `entry->token`, so they would delete the alias.
- **Lazy, and dropped on every `names[]` move**, because `raw_deletevar()`
  **re-indexes**: a stale alias returns the *wrong column*, silently wrong data.
  Measured — with invalidation disabled the stale lookup still answered
  *correctly* off an out-of-bounds `names[nvars]`, so `raw_lookup_name()` bounds
  `idx < nvars`, which is what makes `CS46d` able to fail at all.
- **D2 as ruled: two DIFFERENT stored names folding to one key poison it and
  NEITHER resolves fuzzily**, exact lookups untouched. First-wins is explicitly
  *not* the rule; **byte-identical duplicates are NOT a collision** (`0073`).
- **Rung 4 is anchored as well as case-blind** (the old `strstr` matched anywhere
  but rewrote `inode[2..3]` regardless, so any other offset probed garbage), and
  its history now reads the right way round everywhere: an uppercase query *did*
  reach the old rung; item 1 keeping the **stored** capitals broke it.
  **`get_raw_index` returns the REAL name's entry**; **`@dev[param]` needs no rung.**
- **The viewer's RPN gate mirrors the ladder** (`wviewer::validate_rpn`), D2 and
  `distinguish` included — not item 5's to defer: at the **default `fold`** mode
  on a `Count`/`count` raw, `xschem raw index COUNT` → -1 while the gate said
  valid, `raw add` returned 1, and the user got a silent all-zero trace.
- **Item 1's three carry-forwards, discharged:** `vcd_read.c:139` retired *as a
  statement of D2*; `table_read` driven (`CS48`–`CS48l`); Tcl `raw list`
  consumers swept — none could miss under a more forgiving lookup.

## 3. Test, check count, RESULT

`tests/headless/test_raw_case_mode.tcl` — **186 checks, 105 of them new**
(`CS37`–`CS49o`; item 1 owns `CS0`–`CS36f`). Verbatim: `RESULT: ALL PASS (186
checks)`. Sixteen more suites through `GUI_GATE=1 run_suites.sh` on `:99`, 17/17
PASS, each count identical to item 1's receipt: raw_read_dispatch 51, ..._failure_0306 63, raw_ascii_point_bounds 90, vcd_read 187, vcd_time_base 124, node_token_split 168, wave_cursor_crossdb 93, backannotate_digital 81, wave_viewer 400, ase_cosim 342, cosim_golden_e2e 46, ase_plot 150, calc_skeleton 503, wave_axis_zoom 370, wave_sigbrowser_2pane 108, wave_sigsearch 233.
**Master red-before-green:** the four sources replaced by `git show HEAD:` copies
and rebuilt → `RESULT: 41 FAILED (145 passed)`; restored from byte-exact backups
(`md5sum` equal) → ALL PASS. **Audit** (`GUI_GATE=1 full_audit.sh`, `:99`,
`audit_item02_closer_2026-08-16.txt`): 317 pass / 15 fail / 0 crash-timeout /
0 skip of 332; diffed by NAME and STATUS against
`audit_item01_closer_2026-08-16.txt` it is **EMPTY** — no row moved, none added.

## 4. Sabotage table

Each mutation was applied to a copy of a byte-exact backup, rebuilt, run,
restored, re-run green. **All 105 new checks are below; none is unsabotaged.**

| checks | what was broken | red? | green? |
|---|---|---|---|
| CS37 CS37f CS38 CS38c CS39 CS39b CS39h CS41 CS42 CS42b CS43 CS44c CS49b | `read_dataset()`: `exit_status` forced 0 (spice reader fails) | yes | yes |
| CS40 CS40b | `vcd_read()`: `my_fopen` → NULL | yes | yes |
| CS48 CS48b CS48c CS48i | `table_read()`: `my_fopen` → NULL | yes | yes |
| CS40c CS40d CS40e CS41c CS41d CS43c CS48l | rung 1 deleted (exact `int_hash_lookup` → NULL) | yes | yes |
| CS37c CS37d CS37g CS37h CS37i CS37j CS38d CS38e CS38f CS38g CS39c CS39e CS40g CS40h CS41i CS43i CS45 CS45d CS45e CS45g CS45h CS46 CS47c CS48d CS48e CS48f | rung 2 deleted (`raw_lookup_name()`'s folded result forced −1) | yes | yes |
| CS37b CS37e CS41f CS41g CS43d | rung 3 deleted (`v()` wrap disabled) | yes | yes |
| CS39d CS39f | rung 4's anchored `my_strncasecmp` reverted to the old unanchored `strstr` (needs the new bait column `i(.x1.vp)`) | yes | yes |
| CS37k CS37l CS38h CS47 | `raw_fold_index()`: a fold-table MISS answers column 0 | yes | yes |
| CS40f CS41e CS41h | D2's poison `entry->value = -1` made a no-op (= first-wins) | yes | yes |
| CS42c CS42d | byte-identical duplicate names treated as a D2 collision | yes | yes |
| CS43e CS43f CS43g CS48k | the `distinguish` suppression `if(raw->case_sensitive) return -1` removed | yes | yes |
| CS45c CS46d CS46e | `raw_fold_table_clear()` body disabled (index survives every `names[]` move) | yes | yes |
| CS38b CS39g CS44 CS44b CS44c CS45f CS46c CS47d | the alias index appended to `names[]`/`nvars`/`values` as a **real** variable (non-crashing) | yes | yes |
| CS41b CS43b CS48j CS49c | `xschem raw case` query returns `!case_sensitive` | yes | yes |
| CS43h CS48h CS49k CS49n | `xschem raw case <mode>` setter returns 0 | yes | yes |
| CS45b CS48g | `raw_renamevar()` returns 0 | yes | yes |
| CS46b | `raw_deletevar()` returns 0 | yes | yes |
| CS47b | `raw_add_vector()` returns 0 | yes | yes |
| CS49d CS49e | the viewer gate's D2 handling removed (flat `tolower`, the pre-fix rule) | yes | yes |
| CS49i CS49o | the gate's `set fuzzy 1` forced to 0 (never folds) | yes | yes |
| CS49l | the gate's `if {[xschem raw case]}` line deleted (ignores `distinguish`) | yes | yes |
| CS49f CS49g CS49h CS49m | the gate's two exact rungs deleted | yes | yes |
| CS49j | the gate's final `unknown token` return replaced by `continue` | yes | yes |
| CS49 | DATA DRIVE: `$wvsrc` pointed at an absent file. No code mutation can drive it — xschem sources `wave_viewer.tcl` at startup, so a syntax error SIGSEGVs before any check prints (measured) | yes | yes |
| *(no check — a leak)* | `free_rawfile()`'s `cursor_b_val` free moved back inside `if(raw->names)`: valgrind `32 bytes definitely lost` → `0` with the fix | yes | yes |

Two abort-proofing guards changed no assertion: item 1's `CS36f` and the `$tend /
2.0` cursor-B setup did arithmetic on a value a broken reader empties, raising a
Tcl error that **aborted the file with no RESULT line** — under which a sabotage
read as "nothing went red".

## 5. What was NOT verified

- **No real mixed-case simulator run:** every fixture is committed or written
  inline, no ngspice invoked; nothing here changes what is *stored*. **Reviewer
  findings raised but not confirmed: none** — all eight confirmed ones are fixed
  and recorded in §2/§4.
- **Not-proven, per the reviewers:** the verifier's `:99` pixel drive (mixed-case `node=` → 20666/20355/3623 trace-coloured pixels) was not re-rendered and its RSS probe not re-run (an independent valgrind pass did find 0 definitely-lost on the fuzzy/rename/delete paths); 31 sabotage rows went un-re-driven — of the two a reviewer *did* re-drive, one (`CS39f`) failed, which is why the bait column exists.
- **Named, not fixed.** `raw_add_vector()` still swallows
  `plot_raw_custom_data()`'s `-1`, so `xschem raw add x {BADTOK 2 *}` registers an
  all-zero vector and returns 1 (engine semantics two suites lean on).
  `wviewer::resolve_signal_db` (`:2538`) is a second folding matcher still
  ignoring D2 — harmless, it never calls `raw add`, and **item 5** deletes both
  mirrors. `hilight.c:329`'s `strstr(n, "i(v.")` has the same 4-vs-5-char and case
  bug on the *sender* side (**item 4's**); item 1's `CS23c` string-compares
  `ERR:No raw file loaded` against `>= 0` and prints `ok:` under a reader
  sabotage.
- **No eyeball owed:** the payload is a lookup rule, not pixels.
