# Item 9 — `raw_is_loaded`'s by-word parser dies (R304, T-K) — closes 0507

Batch base `226302f9`; branch HEAD at start `c36efeea`. Nothing pushed.

## 1. Files changed

`git diff --numstat` (+/-), plus this receipt. All four `src/*.tcl` are `wc -l`
identical to HEAD (19046/18671/4929/940); no C, no rebuild.

| file | +/- | what |
|---|---|---|
| `src/xschem.tcl` | 18/18 | `proc raw_is_loaded` **deleted**; an 18-line tombstone comment in its place — LINE-NEUTRAL |
| `src/wave_viewer.tcl`, `src/ase.tcl`, `src/results.tcl` | 10/10, 2/2, 3/3 | four rotted citations re-grepped (`save.c:1456-1465`→`2264-2277`, `1469-1477`→`2264-2277`, `1417-1421`→`2207-2211`), the now-false "xschem.tcl:4801 reads it BY WORD" paragraph rewritten, and the dangling pointer at the removed proc's line number deleted |
| `tests/headless/test_results_select.tcl` | 371/1 | group **AP**, SEL459–SEL474 (16 checks) + detector and fixtures |
| `tests/headless/test_wave_sigbrowser_i14.tcl` | 9/6 | item 14's file: two comments this change made FALSE |
| `doc/claude/specs/results_selection.md` | 112/5 | §5.1 R304c/R304d; §11 L9; §12 T-K row |
| `doc/claude/issues/0507-…` | 88/15 | closed **FIXED**, with the "the proc is GONE" callout |
| `0508-…`, `0509-…`, `PLAN.md` | 2/1, 2/1, 2/2 | one cross-reference / item-9 row each |

## 2. Decisions, and the evidence

**R304c — REMOVED, not re-expressed** (spec §5.1; repeated in 0507's Fix). 0507
recommended (b), re-express on `results::list`; overturned by history. `23092fc9`
added the proc *with* four `if {[raw_is_loaded …]}` guards, all in the graph
dialog; `ad96e222` deleted all four, moving the question into the engine as
`elseif {[xschem raw loaded] != -1}` — live at `src/xschem.tcl:6934`. This batch
asks it in C again: `results::select` calls `xschem raw select`, whose `what == 1`
arm decides read-vs-switch inside `extra_rawfile()`. (b) would ship a proc with
zero callers **and none in prospect** (callerless re-confirmed by two reviewers).

**R304d — a removal from a heavily-cited file is line-neutral or states its cost**
(spec §5.1, with the reproducing grep): **478** `xschem.tcl:<line>` citations across
`doc/`, `src/` and `tests/` sit below the proc, so its 18 lines became an 18-line
tombstone. **SEL471 asserts that RELATIVELY** (fixer ruling): its first draft pinned
`proc waves` at 6373 and one unrelated comment line above that reddened this suite;
it now pins the tombstone's *shape* against `proc set_rect_flags`.

**T-K, precisely** (spec §5.1 + group header). No **by-WORD** parser survives;
*not* "exactly one parser" — five line-wise readers exist, all legitimate. The grep
runs on source stripped of **both** comment forms (whole-line `#`, trailing `;#`):
item 2's SEL82 was satisfied by a comment, item 8 hit the class again, and
stripping only the whole-line form reddened SEL461/462 against innocent files.
**Four** shapes; (d), the index walk, was added after a reviewer's planted parser
carrying 0507's exact defect left the suite 374/374 ALL PASS. Arms (c)/(d) are
**proc-scoped deliberately** (limit 2): a brace-depth tracker measured unusable
(drift at 243 of 4899 `^proc` lines); unscoped, taint on `info`/`txt` reds innocents.

**L9 extended** (spec §11): SEL468/469 extract each `save.c:<a>-<b>` range out of the
comment and assert those lines contain the `what == 4` printer — self-checking
citations. **Prose fixed, no check changed:** a reviewer found a *fifth* legitimate
reader (`src/ase.tcl:3241-3245`) where three blocks said "four" (SEL466 pins four
*named procs*, not a total); and 0507's "`proc waves` is still at 6373 … and a check
asserts it" is false after the SEL471 rewrite, so I corrected it.

## 3. Tests

`test_results_select` (**377**, +16), `test_wave_sigbrowser_i14` (109),
`test_wave_sigbrowser_i1315` (192); band measured by grepping the suites for the
highest id in use (471), never from a doc. Then `full_audit.sh` (`GUI_GATE=1`,
`:99`), joined by NAME and STATUS against `baseline_2026-08-19_226302f9.txt`:

```
PASS | test_results_select  run 1/3  RESULT: ALL PASS (377 checks)   [3/3 runs passed]
SUMMARY: 334 pass  15 fail  0 crash/timeout  0 skip  (total 349)
WIREEDIT: PASS | SCRATCH: 0 leaked dir(s) | TREE: 0 appeared  0 vanished
STATUS CHANGED 0 | ONLY IN BASELINE 0 | ONLY IN NEW 3 — test_results_select,
test_results_dialog, test_waves_gate, all on LEDGER's declared added-suites list.
The 15 reds are the baseline's 15, by name.
```

## 4. Sabotage table — every new check has a row

| check | broken | red? | green after restore? |
|---|---|---|---|
| SEL459 | `proc raw_is_loaded {...} {return 0}` appended to `src/results.tcl` — defines it at RUNTIME from a file SEL460 never reads | only 459 | yes |
| SEL460 | the proc's SOURCE under `if {0} {…}` at `src/xschem.tcl` EOF — present, never executed | only 460 | yes |
| SEL461 | a reviewer's `proc graph_raw_present` — 0507's defect as an **index walk** — appended to `src/xschem.tcl` | only 461, naming `xschem.tcl:2` | yes |
| SEL462 | an index-walk `zz_sab_helper` appended to `test_wave_sigbrowser_i14.tcl` | only 462, naming the file | yes |
| SEL463 | detector arm (a) (`lrange [ … raw info`) deleted | yes (`got 1 want 2`) | yes |
| SEL464 | detector arm (c) (`foreach {a b c} $v`) deleted | yes (+463, declared overlap) | yes |
| SEL465 | whole-line comment skip removed | yes — a by-word parse living only in a comment matched | yes |
| SEL466 | `proc ase::raw_indices` renamed — a legitimate reader deleted | only 466 | yes |
| SEL467 | `results::list` made to truncate the path at the first space | yes (+item 2's SEL118, correct collateral) | yes |
| SEL468 | `wave_viewer.tcl` citation rotted back to `save.c:1456-1465` | yes (+469 by design) | yes |
| SEL469 | `ase.tcl` citation **alone** rotted back to `save.c:1469-1477` | only 469 | yes |
| SEL470 | the dangling `raw_is_loaded (src/xschem.tcl:6980)` pointer restored **wrapped** | only 470 | yes |
| SEL471 | one tombstone line deleted; separately, one **inserted** | only 471, both ways | yes |
| SEL472 | arm (d) reverted to `lrange`-only | only 472 | yes |
| SEL473 | the `^proc` taint reset removed; separately, widened to every line | yes, both ways | yes |
| SEL474 | the `;#` strip removed; separately, widened to a bare `#` | yes, both ways | yes |

Beyond the table: the reviewers' four **innocent** edits gave `3 FAILED (371 passed)` pre-fix
and `ALL PASS (377)` post-fix — three false reds proved present and gone, detection intact.
SEL474's over-strip control was itself unfailable at first (`#` after the idiom); rewritten until it bit.

## 5. What was NOT verified

- **No eyeball owed** — a proc removal plus a grep invariant, not pixels. No lens
  ran `full_audit.sh` (a concurrent lens was mutating the shared tree) and lenses
  2/3 could not mutate the repo, so **no reviewer reproduced any sabotage row**;
  the audit above is mine.
- **Raised, NOT confirmed, not acted on:** `PLAN.md:342` describes the proc in the
  present tense in its §4 *historical* brief (the lens declined to file it); spec
  R304's `wviewer::db_label` `:2401` is really `:2414`, item 2's ruling text; and
  `CREW_BRIEF.md:104` cites `scheduler.c:10776-10793` for `:10850-10889` — a
  driver-owned file, flagged a 3rd time.
- **T-K's two holes**, declared, unmeasured beyond reading: a proc taking the blob
  as a **parameter**; a **file-scope** capture consumed after a `proc` line (spec
  R304c). Latent: `t9_cite` takes the last `save.c` citation above its anchor, so
  one inserted above `ase::raw_indices` changes what SEL469 compares. And SEL468/469
  pin `save.c` lines: when it next gains lines near `extra_rawfile()` they red, and
  the fix is *re-grep and restate*, never delete.
- **Scope:** six files the brief never named — `ase.tcl`/`wave_viewer.tcl`/
  `results.tcl` (citation-only, line-neutral), `test_wave_sigbrowser_i14.tcl`
  (item 14's, **+3 lines, not line-neutral**, comments only), issues 0508/0509.
- **`$HOME`:** only `~/.xschem/geometry` moved (window layout; every GUI xschem
  exit rewrites it). md5'd before/after my audit — `recent_files`(`.bak.*`),
  `raw_history`, `library.defs`, `xschemrc`, `.clipboard.sch`, `pdk_launcher.conf`,
  `net_hilight_editor_seen` all **byte-identical**; the item never sets
  `::update_recent_files`. **Driver: restore `geometry` from `homeguard/pre-item9`.**
