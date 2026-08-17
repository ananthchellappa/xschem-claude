# 06 — ITEM **5b**: one lookup authority + a lazy `ngspice_data` (D3)

⚠ **Numbered 06 by the pipeline; it covers PLAN §3b item `5b`.** Item 6 (`sim()`/`simconf`/`simrc`) untouched. D3, all three properties — **property 3 is
implemented, not deferred.** Spec **extended, not re-cut**: `raw_case_mode.md` **§13** (§4's "keys stay FOLDED" and `DESIGN_REVISION.md` §6 superseded, said
so in place). Base `40b5a83e`, **nothing pushed**. Measurements, **both full per-check mutation tables**, reproducers, the fix round's four confirmed findings
and the reviewers' not-proven list: **`06-…-annex.md`** beside this file.

## 1. Files changed

| file | lines | what |
|---|---|---|
| `src/save.c` | +400 −55 | `get_raw_index_in(Raw*,…)` split out of `get_raw_index()`; the lazy view (`ngspice_data_arm/_forget`, the read/array/unset trace, materialised-key bookkeeping, `nd_view_owned()`, the detached drop, `ngspice_data_nkeys/_armed`); `update_op()` stops looping `Tcl_SetVar2`; `free_rawfile()` disarms; **`ngspice_data_key()`/`ngspice_data_publish()` deleted** |
| `src/xschem.tcl` | +108 −51 | `ngspice::lookup` + its **gated** third-publisher fallback; the **four** procs lose their `string tolower` and hand-rolled `v(...)` rung; three `get_current` classifications case-blind; `get_diff_voltage` fixed; the array **out of** `tctx::global_array_list` |
| `src/xschem.h` · `src/scheduler.c` · `src/callback.c` | +29 −11 · +17 −0 · +9 −18 | five prototypes in, the two interim out · `xschem raw view_keys` / `raw view_armed` (introspection; `view_armed` also gates the fallback) · the cursor-B publisher arms instead of publishing per variable |
| `tests/headless/test_ngspice_data_view.tcl` · `test_ngspice_data_ctx.tcl` | **NEW, 803** · **NEW, 155** | `CS96`–`CS114j2`, **139 checks**, true headless · `CS113*`, **21 checks**, the real two-window road — **needs a display** |
| `test_raw_case_mode.tcl` · `test_backannotate_digital.tcl` · `full_audit.sh` | +66 −28 · +5 −2 · +1 −1 | **five checks RESTATED in place**, same ids, still 277 · one stale comment · the headless suite into `nogui_tests` |
| `specs/raw_case_mode.md` §13 · `issues/0420-*.md` | +285 −0 · new 82 | the spec section §13.1–§13.8 · the one filed residue |

## 2. Decisions taken, and the evidence

- **THE BLAST-RADIUS SWEEP `00a` SAID THIS ITEM OWED, done first.** D3's "nothing enumerates the array, verified by grep" is **false**: six `array names`
  sites in four files plus a whole-array `upvar`. `test_wave_cursor_crossdb` 93/93 and `test_backannotate_digital` 81/81 unchanged, five checks restated — so
  D3's "mitigable" became **mandatory**.
- **MEASURED BEFORE ANY CODE, and it decided the design: unsetting the array DESTROYS the trace** (tcl 8.6.14, annex §1; the manual is not explicit). So the
  **five clear sites needed no edit** (an unset *is* the trace reset), arming re-installs, and the pure-Tcl third publisher's `unset -nocomplain` through its
  `upvar` **disarms this view before it writes** — they cannot interleave, and the driver's "hard one, worse than enumeration" dissolves.
- **Three rulings, all measured, spec §13.6/§13.7:** enumeration is **REBUILT from `names[]`, not accumulated**; the view is **pinned to the PUBLISHING `Raw`,
  never `xctx->raw`** (hence `get_raw_index_in()` — a "current"-resolving view answers out of another database after a switch, `CS103c2/d/h`); and it
  **answers only for a window that OWNS it** (`nd_view_owned()`; a non-owning read *drops* what the owner materialised, without which window B read window A's
  numbers). **`free_rawfile()` disarms and VALGRIND is the evidence a check could not be**: removed → `Invalid read of size 8 at ngspice_data_trace`, in place
  → clean ×3.
- **The third publisher keeps its own fold and is NOT made an authority** — `ngspice::read_raw_dataset` never builds a `Raw`. Its road gets a **gated**
  fallback in `ngspice::lookup`, live only while `raw view_armed` says no; ungated it folds `En` and violates **D2** (sabotage `N20`). Ruling, **spec
  §13.5/§13.7**.
- **WITHDRAWN RULING, and it was ours:** "a materialised element is a cache … a read trace does not fire for an element that already exists" went into
  `save.c`, the spec, this receipt, the annex and the test, and is **false** — the trace fires on every read and re-resolves. Five copies corrected,
  `CS111c`/`CS111d` pin the truth, the silently discarded script write documented not fixed (**§13.6**); the `n\ vars` backslash claim was wrong too
  (**§13.6b**).
- **Property 1 reached a FOURTH proc:** `get_node`, the one the shipped `ngspice_get_value.sym` / `device_param_probe.sym` call, which D3 does not name.
  Folded too, fixed too. **No mode branch exists anywhere in backannotation.** Two defects inside the lines D3 ordered deleted went with them:
  `get_diff_voltage` never returned a difference (`res` assigned only in its failure branch → `can't read "res"`), and `my_snprintf` cannot see `%.*g` here
  (no `HAS_SNPRINTF`) — bare `sprintf`, and `CS106c2` pins the exact string.
- **MANDATORY SCOPE CLOSED, not passed a sixth time:** `xschem raw casemode` on a **VCD** (`CS107`–`CS107m`) and a **`table_read`** database
  (`CS108`–`CS108n`) — `unknown`/`none` per B2b, `-sniff` says what it *would* have said, explicit set/report/clear, names verbatim, `Raw.case_sensitive`
  untouched. **NAMED, NOT FIXED — issue `0420`, spec §13.8:** `token.c`'s six `@spice_get_*` branches fold the query first (13 `strtolower()`), so the roads
  agree under `fold`/`preserve` and diverge under `distinguish`; each fold feeds case-sensitive logic downstream, so it is item-4-shaped work, not a deletion.
- **Five checks RESTATED, none renumbered or deleted.** `CS22 CS23 CS23d CS36d CS36e` asserted `DESIGN_REVISION` §6's interim folded key, which D3 supersedes
  and item 1's own file flagged (*"tolerable UNTIL ITEM 5B"*) — same ids, same code under test, inverted expectation (the label text moved with it), and each
  grown a clause a broken publisher still fails.

## 3. Tests, check counts, verbatim RESULT lines

Closer's own run on a force-relinked binary (`touch` the four C sources, full `make`, `md5sum xschem` = `a17e692f9af2292414169e793ef8dc80`), `GUI_GATE=1
run_suites.sh`, ATTACHED to dev display `:99`:

```
PASS     | test_ngspice_data_view       run 1/7  RESULT: ALL PASS (139 checks)
PASS     | test_ngspice_data_ctx        run 2/7  RESULT: ALL PASS (21 checks)
PASS     | test_raw_case_mode           run 3/7  RESULT: ALL PASS (277 checks)
PASS     | test_backannotate_digital    run 4/7  RESULT: ALL PASS (81 checks)
PASS     | test_wave_cursor_crossdb     run 5/7  RESULT: ALL PASS (93 checks)
PASS     | test_wave_casemode           run 6/7  RESULT: ALL PASS (134 checks)
PASS     | test_hilight_case_senders    run 7/7  RESULT: ALL PASS (30 checks)
RESULT: 7/7 runs passed
```

**160 new checks** (139 + 21) plus the five restated; band grepped, not quoted — the highest id in use was `CS95y`. `test_ngspice_data_view` gives the same
RESULT line true headless; `test_ngspice_data_ctx` needs real windows and is deliberately **not** in `nogui_tests`. **MASTER RED-BEFORE-GREEN**, pristine
`HEAD` build of the six touched sources, restored `md5sum -c`-clean and rebuilt: `35 FAILED (104 passed)` / `6 FAILED (15 passed)` / `5 FAILED (272 passed)`
(the five restated, no others). ⚠ `CS114c`–`CS114g` are **green** on pristine HEAD, correctly so — their drive is against the item's own pre-fix state
(`N19`), annex §5.

**CLOSER AUDIT** — `GUI_GATE=1 full_audit.sh` on `:99`, on the shipped bytes → `audit_item05b_closer_2026-08-17.txt`, whose last line is verbatim:
**`SUMMARY: 321 pass  15 fail  0 crash/timeout  0 skip  (total 336)`** — 336 rows counted with `grep -cE '^(PASS|FAIL) +\| +test_'` (never `grep -c '^FAIL'`:
six `FAIL | key …` lines are within-file detail). Diffed by **NAME and STATUS**, both directions, against `audit_item05_commit_2026-08-16.txt` (319/15/0/0 of
334 at `9b1394c9`), the **entire** diff
is the two suites this item adds — `> test_ngspice_data_ctx PASS` and `> test_ngspice_data_view PASS`. **ZERO existing statuses moved either way** and the two
red lists are identical name-for-name (`test_wave_markers` among them; `test_ase_core` PASS in both), so the items 1–9 empty-diff contract holds and the
baseline may roll.

## 4. Sabotage

**43 mutations over two rounds — 26 (annex §3, `M*`/`T*`) and 17 (annex §9, `N*`)** — each on a copy of a byte-exact backup, rebuilt, both suites re-run,
restored `md5sum -c`-clean, rebuilt, re-run green. **The annex's two tables are the per-check rows**, naming every reddened id per mutation: one row per check
for 160 checks does not fit a 120-line receipt, so the mapping lives there and the summary here. Highest-yield: `M1`/`M2` (no trace / read arm never resolves)
**25/21** incl. the five restated; `T2` (`lookup` always `?`) **12**; `T11`/`T15` (casemode verb, fold rung) **19/36**; `T13` (the third publisher's `unset
-nocomplain`) **4**; `N16`/`N18` (`TCL_TRACE_READS`/`_ARRAY` dropped) **46/13**; `N1` (array back in `tctx::global_array_list` — the blocker) **10**; `N4`
(record on every read — the growth defect) **1**, `CS111f` `20004` vs `4`; `N20` (the gate removed) **2**, a D2 violation. A verifier round added 29 more
(`M10`–`M29`), reaching seven checks round 1 had listed unsabotaged (`CS100b CS101c CS104f2 CS107b CS108b CS108l CS108n`). **TWO MUTATIONS FAILED TO REDDEN
ANYTHING and are recorded as failures, not silences:** `M7b` (`CS103g`, valgrind carries it instead) and `N7` (a defensive re-check guarding a re-entrant
disarm no reachable script produces; it stays, unpinned and declared). **FOUR VACUOUS CHECKS WERE FOUND BY SABOTAGE, NOT REVIEW, and rebuilt:** `CS99b`,
`CS104g`, `CS110e`, `CS110h` — each passed a mutation that should have killed it (annex §3, §9).

**UNSABOTAGED — NOT EVIDENCE: 44 of the 160**, so 116 carry at least one drive. Round 1, 23 after the verifier's mutations: `CS96 CS96b CS96c CS96d CS99b0
CS99b1 CS101 CS101b CS103 CS103e CS103f CS104e CS104f CS105 CS106 CS106b CS107 CS108 CS109` (premises on items 1–3's verbs and on fixtures), `CS103c` (a
cached element; live twin `CS103c2` carries the pin), `CS104b`/`CS104c` (they pin the **measured Tcl behaviour** the design rests on — no mutation of *ours*
can move them, which is their point), `CS103g` (valgrind). Fix round, 21 of 62, itemised in annex §9: 13 premises, `CS111g`/`CS111j` **declared weak in the
test file itself**, `CS112c`/`CS112h` pinning Tcl's own behaviour, and `CS114`/`CS114h`/`CS114i`/`CS114i2`.

## 5. What was NOT verified

**Reviewer findings raised and NOT confirmed: none** — three lenses raised four defects plus two false doc claims, all six reproduced here and fixed (annex
§7); the receipt/annex numeric contradiction was true too and is closed. **The reviewers' full not-proven list is annex §11**; the load-bearing residue:

- **`info exists ngspice::ngspice_data` still answers 1 in a sibling window that never annotated** — the two sentinels are elements of one global array,
  though the *values* are isolated (`CS113e`–`CS113f`). Cost: `actions.c`'s descend hook skips that window's automatic cursor-B backannotation. Per-window
  means re-creating the array on every context switch from a per-window record — a redesign, deliberately not done. Declared, **spec §13.7**.
- **`CS103g` survives its own sabotage**, valgrind its only evidence; and the verifier's **`M13`** is an open hole — deleting `Tcl_UnsetVar` from
  `ngspice_data_arm()` leaves both suites green, on a line its own comment (spec §13.5) calls load-bearing. Nobody exercised `array unset <pattern>`, a tab
  **close** with an armed publisher, two windows publishing in turn, or item 5's separate viewer `xctx`. A Tcl write into the armed array is still discarded.
- **No real simulator ran in the committed suites** (committed + inline fixtures). The real road was driven out of band twice — the case-capable fork on a
  fresh op deck through three shipped `ngspice_get_value.sym` instances (`2.25`/`2.25`/`?` under `distinguish`), and the third publisher on a real binary op
  raw — neither is a check. **No allocation tracing** beyond two valgrind runs; `nd_view_set`'s `char s[100]` was not bounded; `token.c`'s folds and `0420`'s
  claim are unmeasured by any reviewer.
- **Precision and flag pins are one-sided:** only `update_op`'s `%.4g` is pinned (`CS106c2`) and `%.6g` leaves it green because the fixture's `1.111` renders
  identically; `CS107m`/`CS108k` catch only an *unconditional* `case_sensitive` flip; the cursor-B publisher's rendering is unpinned. **Cost moved rather than
  vanished and was not timed** — two `Tcl_SetVar2` per publish instead of `nvars`, but every missing-element read walks the ladder and enumeration is
  O(nvars); item 4's read-latency pointer stays unmeasured.
- **NO `look` DEBT, AND NONE RECORDED.** Nothing visual changed — no pixel, colour, layout or wording. The new window suite drives real windows but asserts
  values. Nothing here needs the user's eyes.
