# 03 — mode resolution, four sources in order

`PLAN.md` §3b item 3 · `DECISIONS.md` **B2a/B2b** · spec **extended, not replaced**: `specs/raw_case_mode.md` **§10** ·
annex (all 50 mutations, transcripts): `03-mode-resolution-annex.md`. Base `6b566a68`, `fluid-editing`, nothing pushed;
item round plus a fix round of six confirmed review defects. `xschem raw casemode
[<mode>|-source|-all|-explicit|-header|-schematic|-sniff|-floor]` resolves a **file's** mode: explicit setting →
`Option: casemode=` header → schematic-name comparison → capital sniff (off by default) → **unknown**. It REPORTS;
nothing in it writes `Raw.case_sensitive` (item 1's flag).

## 1. Files changed

`src/save.c` **+411** (parse, four sources, floor) · `src/scheduler.c` **+99 −2** (the verb, re-read carry) ·
`src/xschem.h` **+74** (`RAW_CASE_*`, `Raw` fields, prototypes) · `src/xschem.tcl` **+21** (`sim_case_mode`,
`raw_case_sniff`, MIRRORED IN TCL) · `tests/headless/test_raw_case_mode.tcl` **+617** (186→277 checks) ·
`specs/raw_case_mode.md` **+262 −5** (§10) · `casemode_batch/DESIGN_REVISION.md` **+16** (§9 correction) ·
`doc/xschem_man/developer_info.html` **+21**. Untracked, also committed: this receipt, the annex, 3 audit artifacts.

## 2. Decisions, and the evidence

- **Resolution REPORTS, it does not act** (`CS59e`): the lookup verb's setter
  **re-reads the file**, so coupling them would make merely *recording* a mode
  rebuild the database. The explicit setting **is** carried across that re-read
  (`CS59m`); `hdr_case_mode` is not — the re-read re-parses the header.
- **Header: exact key, case-blind value.** Measured on `build-ver_50` (annex §3):
  `-D CaseMode=`/`-D CASEMODE=` leave `$curcasemode` at `fold` **silently** (a
  different variable) while `=PRESERVE`/`=Preserve` give `preserve`. Hence
  `strcmp` on the key (`CS54`/`b`), `strtolower` on the value (`CS55`/`b`).
- **`Option:` only, both header positions, first line wins.** `Casemode:` is
  refused because ngspice's own reader **aborts the load** on it (`FINDINGS.md`
  §1); `Command: set casemode=` because `Command:` is free-text nothing parses.
  All eleven real upstream `repro/hdr_*.raw` were driven through this binary and
  land exactly there (annex §2); **gitignored**, so the suite inlines the lines.
- **Title injection.** `Title:` is user text, so the parse is anchored at the line
  start: `* casemode=distinguish`, an Option-shaped title and an Option-shaped
  variable row are all refused (`CS53`, `CS53b`, `CS53c`/`d`). **ONE anchor, not
  two** — with the rule in caller *and* parser, deleting either left the suite
  green (measured); the caller's test is now deliberately loose.
- **The loaded dataset owns its line** (fix 3; spec §10 corrected in place): the
  `Option:` branch was the only header branch with no `sim_type` guard, so a
  two-plot raw reported the *other* plot's mode (`CS57c`–`CS57f`). The "one raw,
  one mode" premise was false — ngspice `rawfile.c:204` vs `222/262`.
- **Schematic-owned names = instance/wire `lab=`**, never `xctx->node_table`
  (reaching it means `prepare_netlist_structs()`, which has side effects; a
  third-ranked read-only query may not). Needs ≥2 comparable names and a strict
  majority; a tie, an all-lowercase design, an all-CAPITALS name returned
  unchanged and **two spellings folding to one key** are *no signal* (`CS61`–
  `CS61o`). Source 3 answers only when `raw->schname` matches the current
  schematic (fix 4) — `xschem load` does not clear a loaded raw.
- **The sniff can never answer `fold`** (`CS63e`): an all-lowercase file is what a
  lowercase design under `preserve` writes. **The floor (`sim_case_mode`, default
  `fold`) may never leak into a file's verdict** (`CS64f`) — a request about a
  *run* is the only place `fold` is asserted without evidence. Absence stays
  **unknown** (B2b, `CS58b`/`CS62b`), permanently.

## 3. Test, checks, RESULT

`tests/headless/test_raw_case_mode.tcl` §V–AA, **91 new checks** `CS50`–`CS64f`
(75 item round + 16 fix round), **277 in the file** (item 1 owns `CS0`–`CS36f`,
item 2 `CS37`–`CS49o`; band grepped, not quoted). Verbatim, from the closer's own
run via `devdisplay.sh exec`: `RESULT: ALL PASS (277 checks)`. **Master
red-before-green:** the four sources replaced by `git show HEAD:` copies and
rebuilt → `RESULT: 61 FAILED (200 passed)`, **not one of the 186 pre-existing
checks moved**. **13 suites** via `GUI_GATE=1 run_suites.sh` on `:99`:
`RESULT: 13/13 runs passed`, counts identical to item 2's receipt except this one.

**Closer audit** (`GUI_GATE=1 full_audit.sh`, `:99`, `audit_item03_closer_2026-08-16.txt`):
`SUMMARY: 317 pass  15 fail  0 crash/timeout  0 skip  (total 332)`. Diffed by test NAME and STATUS against
`audit_item01_closer_2026-08-16.txt` the diff is **EMPTY** — 332 rows on both sides, **no row moved in either
direction**, none added, none lost, so the batch's empty-diff contract (`receipts/00a-suite-sweep.md`) is met.
The 15 reds are the documented ones: `ase_window` (W7), the four libmgr/SANDBOX environment failures
(`gf180mcud`, `ihp_sg13g2`, `sky130a`, `lib_manager_gui`/`_locate`), `cadence_drag`, `ciw`, `lib_sweep`,
`reopen_readonly`, `rotate_stretch_short_0104`, `selflog_output`, `wave_markers`, `wave_sigbrowser_0312`,
`wave_sigbrowser_keys`. Count rows with `grep -cE '^FAIL +\| +test_'` (**15**), never `grep -c '^FAIL'`
(**49** — both files carry within-file `FAIL - key …` and `FAIL:` detail lines).

## 4. Sabotage

Each mutation applied to a copy of a byte-exact backup, rebuilt, run, restored (`md5sum -c` clean), re-run green —
restores never `git checkout`, the item being uncommitted. Ids are the annex's; **every one of the 91 new checks
appears in exactly one row** (the annex lists the other mutations that redden each).

| id | what was broken | went red | green again |
|---|---|---|---|
| M1 · M4 · M5 · M6 | parser's line-start anchor · naive parse (key anywhere, value to whitespace) · key matched case-INSENSITIVELY · value case-SENSITIVELY | CS53b · CS52c CS53 CS53c · CS54 CS54b · CS55 CS55b | yes |
| M7 · M8 · M30 · M9 | trim dropped · LAST line wins · bad value defaults `fold` · a `Casemode:` key accepted | CS56 · CS57b · CS57 · CS52b | yes |
| M41 · M10 | the spice reader fails (`exit_status` 0) · the header is never stamped | CS50 CS51b CS52 CS52d CS52e CS53d CS59l · CS50b CS50c CS50d CS50e CS51c CS59d CS59g CS60e | yes |
| M31 · M13 · M22 | **B2b violated** (no casemode line recorded as `fold`) · sniff gate ignored · **the floor leaks into a file's verdict** | CS56b CS56c CS58 · CS58c CS63c · CS58b CS58d CS62 CS64f | yes |
| M42 · M28 · M25 · M32 · M12 | `raw case` getter hardwired · no-database arm answers instead of raising · setter returns 0 · parsed but not stored · EXPLICIT source skipped | CS58e · CS58f · CS59 CS59f CS59k · CS59b · CS59c | yes |
| M24 · M26 · M27 · M23 · M33 | setter also flips the lookup flag · bad mode token accepted · bad `-option` accepted · explicit not carried across the re-read · `raw case` stops stamping | CS59e · CS59h CS59i · CS59j · CS59m · CS59n | yes |
| M34 · M35 · M16 · M17 | fold/preserve votes swapped · the THIRD outcome never counted · `comparable<2` dropped · strict majority dropped | CS60b CS60c CS60f CS61c CS61g · CS60d · CS61 · CS61b | yes |
| M18 · M19 · M20 · M38 · M21 · M21b | all-lowercase skip dropped · all-CAPITALS skip dropped · candidate identifier filter dropped · floor ignores the global · floor answers `unknown` for `unknown` · for garbage | CS61e · CS61f · CS61h · CS64c · CS64e · CS64d | yes |
| M36 · M40 · M14 · M15 · M37 | sniff defaults ON · floor defaults `preserve` · sniff answers `fold` · sniff ranked above the comparison · sniff never answers | CS63 · CS64 CS64b · CS63e CS63f · CS63g · CS63b CS63d CS63h | yes |
| F1 · F2 · F3 · F4 · F5 | first case-insensitive hit wins again (the reported defect) · ambiguity never reported · `raw->schname`/`level` pairing gate removed · the WIRE loop deleted · sniff restricted to `names[0]` | CS61i CS61j **CS61k** · CS61o · CS62d · CS61m CS61n · CS63i CS63j | yes |
| F6 · F7 · F8 · M10 · M14 (re-run) | line attributed to the FILE again · attribution inverted · the file-level position dropped · `Option:` line aborts the read · resolver returns FOLD | CS57d · CS57f · CS51 · CS57c CS57e · CS62b | yes |
| D1 · D2 · D3 | **data drives**: 4th label in `div_case.sch` · 3rd wire in `div_wire.sch` · `CS62b` reads the other raw | CS60 · CS61l · CS62c | yes |

**Unsabotaged, i.e. NOT evidence.** `CS60`, `CS61l`, `CS62c` have **no item-3 code beneath them** — fixture/premise
checks, movable only by the data drives above. `CS61d` has **no single-edit mutation**: it is over-determined
(hierarchy-prefixed names match no schematic net anyway). The verifier drove it red with a two-edit mutation;
`CS61h` is the check holding the candidate filter down.

## 5. What was NOT verified

- **Reviewers: six findings, all confirmed, all fixed** (§2, `F*` rows). Nothing raised-but-unconfirmed, nothing argued down. Two receipt corrections applied in place: base `532b1768`→`6b566a68`, and §3's counting-trap sentence.
- **Reviewer not-proven, carried.** One reviewer worked from an isolated snapshot (another agent was rebuilding this
  tree mid-review) and re-drove no mutation, so the mutation→check map rests on two runs, not three. They could not
  attribute a `test_wave_markers` standalone green (FAIL in both audits) nor a `test_ase_core` failure that
  reproduces on the **HEAD** binary too — neither is item-3 code; named so the next closer does not read them as new.
- **No simulator wrote a raw during the suite**; every header shape is inline, the eleven real spliced files are
  gitignored and were hand-driven. **No binary raw in the suite carries an `Option:` line** — parsing one is
  reasoned, not driven. **No valgrind/allocation tracing** (the new code heap-allocates nothing: four fixed 512-byte
  stack buffers). **No check reads the `dbg(0)`** on a second, disagreeing `Option:` line. **`raw casemode` on a VCD
  or `table_read` database has no committed check** — both hand-driven only (`unknown none` / `preserve schematic`,
  no crash); item 2's carry-forward on untested reader kinds stays open.
- **A measured cost, not a defect.** Fix 1 returns early only on an EXACT match, so a *folded* raw walks the whole
  instance+wire list per candidate: 2000 instances × 500 names — exact-hit 21 ms (unchanged), folded-hit 147 ms (was
  ~20), all-miss 189 ms (was ~135). Source 3 has **no cache**, and `-schematic` and `-all` each recompute it:
  **items 5/13 must not poll it from a redraw.**
- **No eyeball owed.** B2a's control showing the detected mode with an override is items 5 and 13; this ships the
  engine only. `owed.sh` untouched.
