# Stage A verify: adversarial check of receipts/A-seed.md

Verifier crew, 2026-11-12. Base e615a1801 plus the uncommitted diff (src/ase.tcl,
src/ase_window.tcl, tests/headless/test_ase_run_seed.tcl, tests/headless/test_ase_optsheet_1441.tcl).
Own Xvfb `:283` plus openbox (both pids killed, confirmed dead). Every command ran with
`unset DISPLAY`. A HEAD worktree under the session scratchpad was used for the HEAD runs and for
the sabotages, then removed. The working tree was not edited: cmp confirms `src/ase.tcl` and
`src/ase_window.tcl` are byte-identical to the state they were in at the start.

**Verdict: two defects, and one of them should block the commit (D1).** The seed rule itself is
sound on every look-alike I built, apart from one narrow false positive (D2).

## Defects

### D1 (should block): the options preview's new reader creates directories and moves a global, against R602e

`ase::ui::optsheet_netlist_text` resolves its file with `ase::rundir`. That helper is not a query:
- For a non-empty `rundir` it runs `file mkdir`.
- For an empty `rundir` it calls `set_netlist_dir 0`, which creates `$USER_CONF_DIR/simulations`
  and rewrites `::netlist_dir`.

The tree has already ruled that a preview may not do this. See R602e, recorded in the comments
above `ase::ui::rsel_resolve_input`, `ase::ui::viewer_rawfile_relative` and the run-directory
dialog. The `rsel_resolve_input` comment names this exact case: "A preview fires on every row
click and (debounced) on typing, so passing `key` would make merely LOOKING at a candidate create
a directory and move a global."

This reader runs on every refill of the options sheet, which includes every keystroke in its
Find box. `ase::rundir` is called before the cache test, so the cache does not prevent it.

Repro (`scratchpad/v/probe3.tcl`, headless):
```
after opt_preview alone:            exists=0      (rundir names a directory that does not exist)
after optsheet_netlist_text:        exists=1      <- the reader created it
empty rundir, after opt_preview:    netlist_dir={} sims=0
empty rundir, after reader:         netlist_dir={/tmp/tmp.../.xschem/simulations} sims=1   <- global moved, dir made
```
So the receipt's claim "It does no netlisting and writes nothing" is **refuted**. RS9's `wrote=0`
leg cannot see this: RS9 runs `file mkdir` on its rundir first, and the leg only compares that
directory's contents.

The precedents `ase::ui::netlist_display_text` and `ase::ui::conv_netlist_text` also call
`ase::rundir`, but both are one-shot reads.

Suggested fix: query, never create.
- Read the state's `rundir` key directly, the way `rsel_resolve_input` does, and use it only if
  `file isdirectory`.
- For an empty key, look at the existing `::netlist_dir`, or `$USER_CONF_DIR/simulations`, without
  `mkdir` and without `set_netlist_dir`.
- Add a row that drives a nonexistent rundir and an empty rundir, and asserts that no directory
  appears and `::netlist_dir` does not move (the SEL355 pattern).

### D2 (narrow; the driver decides): an inline comment after an option card counts as the bench's seed, so the default is dropped and tt_mm becomes unrepeatable

The card regex `^\s*\.opt\w*\s.*\mseed\s*=` matches across ngspice's inline-comment markers.
`.options method=gear $ seed=5 was tried` and `.options method=gear ; seed=5` both make
`ase::run_seed_user` answer `card ...`, so render_deck writes no default.

Measured on stock `/usr/bin/ngspice` (45.2) with an `agauss` resistor:
- Each of those two cards on its own: three runs give three different draws. ngspice treats the
  text after `$ ` or `;` as a comment, so the bench is unseeded.
- A real `seed=5`: 931.2134 three times.

End to end, ASE-L's own render_deck output for a bench with the `$` card
(`scratchpad/v/e2e.sp`, which carries no `.options seed=1`) gave 844.85, 685.54 and 937.96 on three
runs. At HEAD the same bench got `.options seed=1` and was repeatable. That is a regression for
this text and breaks the user's ruling "tt_mm should give same result each time".

It is rare text. The fix is cheap: strip an inline comment (`\s\$\s.*`, `;.*`, `//.*`) before
matching, and add a look-alike to RS6.

## Claims table

| # | receipt claim | verdict | evidence |
|---|---|---|---|
| 1 | The default steps aside for `reset` / `mc_source` / `option seed=` in pre-commands, verbatim lines and the netlist's `.control` | CONFIRMED | probe1: `MC_SOURCE`, `option seed = 5`, `.option seed=5` and `options seed=5` in control text, plus an uppercase `.CONTROL`/`RESET` netlist, all give 0 default lines |
| 2 | Look-alikes keep the default | CONFIRMED, with the D2 exception | Keep it (1 line): `* .options seed=5`, `*.options seed=5`, `*reset`, `* option seed=5`, `# reset`, a node named `seed`, `.param s="seed=5"`, `.csparam seed=5`, `.options rseed=5`, `plot v(reset)`, `let reset=1`, `reset_count`, `optran ...`, `option reltol=`, `echo option seed=5`, `source other.cir`, `set rndseed=42`, bare `setseed 42`, `.include /x/seed.inc`. The only false positives are the two inline-comment cards (D2). |
| 3 | A card case: `.OPTIONS SEED = 5` | CONFIRMED | answers `card` |
| 4 | Seed in an `.include`d / `.lib` file not seen (declared) | CONFIRMED as declared (A-seed §5) | The cost is the "Multiple seed" warning only (the netlist reads first). |
| 5 | (not claimed) a `+ seed=5` continuation line | not seen: a false negative | The default is added. Per the receipt's own measurement, the cost is the warning only. Undeclared; worth one sentence. |
| 6 | RS6–RS9 red without the fix | CONFIRMED | HEAD's `src/ase.tcl` and `src/ase_window.tcl` with the new suite: `5 FAILED (5 passed)` (RS6, RS6b, RS7, RS8, RS9). |
| 7 | The receipt's sabotages redden | UNVERIFIED individually | The red-first run above covers S8. I did not re-run S1–S9 or W1–W4; I ran my own instead (below). |
| 8 | Suite counts | CONFIRMED | Below. |
| 9 | The reader never netlists | CONFIRMED | The code only opens and reads `<rundir>/<cell>.spice`; there is no `ase::netlist` call. |
| 10 | The reader writes nothing | **REFUTED** | D1 |
| 11 | The cache limit (same size, same second) is declared | CONFIRMED, reproduced | probe4: a same-size rewrite in the same second gave preview 0 against the truth 1, and healed once the mtime moved. The limit is preview-only and declared. It is easy to hit in a scripted sequence: my first uppercase-`.CONTROL` probe gave a false mismatch for this reason. |
| 12 | The reduced reader agrees with the deck on an uppercase `.CONTROL` | CONFIRMED | probe4: preview 0, deck 0, with a fresh file |
| 13 | test_ase_dialogs display-arm G2sens red is pre-existing | CONFIRMED | Display arm on :283. HEAD worktree: `1 FAILED (388 passed)`, G2sens `{1 1 0 1 0 Entry Entry normal}`. The working tree gives the identical result. |

## Suites (own Xvfb :283; counted = `run_suites.sh --nogui`, display = `GUI_GATE=0 run_suites.sh`)

| suite | counted | display | receipt |
|---|---|---|---|
| test_ase_run_seed | ALL PASS (10) | ALL PASS (10) | 10 / 10 ✓ (no `skip:`, so ngspice was found) |
| test_ase_optsheet_1441 | ALL PASS (64) | ALL PASS (90) | 64 / 90 ✓ |
| test_ase_netlist_display | ALL PASS (5) | ALL PASS (6) | 5 / 6 ✓ |
| test_ase_core | ALL PASS (674) | ALL PASS (674) | 674 / 674 ✓ |
| test_ase_dialogs (HEAD and working tree) | not run | 1 FAILED (388), G2sens | ✓ pre-existing |

## My own sabotages (HEAD worktree carrying the new files; each restored by cp, cmp ok)

| # | sabotage | result | meaning |
|---|---|---|---|
| X1 | the control regex drops its word end `(\s\|$)` | **survives** (ALL PASS 10) | No `resetx`-style look-alike in RS6. Low product impact. |
| X2 | the card regex loses `-nocase` | **survives** | Every RS6 card is lowercase, so an uppercase `.OPTIONS SEED=5` (common in SPICE decks) is unfenced. |
| X3 | the card regex drops `\m` | **survives** | `.options rseed=5` is unfenced. |
| X4 | the control `option` regex requires a leading dot | reddens RS6 (`pre-option=1`) | fenced |
| X5 | the reader's `.control` test becomes case-sensitive | **survives** RS9 | An uppercase `.CONTROL` would make the preview show a default the deck lacks. UI17d was not run under this sabotage. |

These are fence gaps, not product defects. Suggested fix: add `RESETX`-style, `.OPTIONS SEED=5` and
`.options rseed=5` cases to RS6, and an uppercase `.CONTROL` netlist to RS9.

## Not checked

- I did not re-run the receipt's S1–S9 or W1–W4 individually.
- I did not run UI17d under my own sabotages.
- I ran no suites beyond the four named plus test_ase_dialogs.
- I measured nothing on the fork ngspice. All my ngspice measurements are stock 45.2.
- `source` in `.control` as a re-parse, unmeasured (declared by the receipt).
- My first probes ran with cwd at the repo root and briefly created `rd/`, `rd2/` and `e2e.sp`
  there. They were moved or removed immediately, and `git status` shows nothing of mine.

## Re-verify (after the fixes, commit 5f88a7c65; base 5f88a7c65^ = e615a1801)

Setup:
- A worktree at 5f88a7c65 under the scratchpad, built and then removed.
- My own Xvfb `:286` plus openbox; both pids were killed and confirmed dead.
- `unset DISPLAY` on every command. No tracked file was edited, and ~/gc26 was not touched.
- Headless probes ran on the main tree's `src/`, which `git diff --quiet HEAD -- src` confirms is
  at HEAD.

**Verdict: nothing blocks.** D1–D4 are closed. What is left is warning-only false negatives and one
surviving fence gap (Y1), all below.

| item | verdict | evidence |
|---|---|---|
| D1: the reader makes no directory and leaves `::netlist_dir` alone | **CLOSED** | probe3 at HEAD: a missing rundir stays missing (`exists=0`); with an empty key, `netlist_dir={}` and `sims=0` after the reader, where the previous round gave `1`, the path, and `1`. probe6: with an empty key and an existing `$USER_CONF_DIR/simulations/<cell>.spice`, the reader finds it (`read=1`) and `::netlist_dir` stays `{}`. A relative rundir key resolves against the cwd and creates nothing. That is the same resolution `ase::rundir`'s `file normalize` gives, so it is not new. |
| D1: RS10 is red on the old reader | **CONFIRMED** | The first-round `ase_window.tcl` with the new suite gives `2 FAILED (9 passed)`: `RS10 -> {missing_made=1 nd_moved=1 sims_mad…`, plus RS9 (its card file is now the two-line form). |
| D2: the strip matches ngspice 45.2 | **CLOSED, no false positive left** | Stock ngspice, an agauss draw, three runs per case (table below). Every case that is unseeded in ngspice now keeps the default, and those decks repeat at 886.0342. No legal seed is lost in the dangerous direction: every seed ASE-L now misses leaves the default beside a card that still governs. |
| D3: `+` continuations are joined | **CLOSED** | `.options method=gear` + `+ seed=5` is judged as a card, and a device `+ … seed=5` keeps the default. Sabotaging the join turns RS6 and RS9 red. |
| D4: X1, X2, X3 and X5 redden | **CONFIRMED** | X1, X2 and X3 each give `1 FAILED (10 passed)` on RS6. X5 gives `1 FAILED (10 passed)` on RS9. Each was restored and `cmp` ok. |

D2/D3 measurements: what ngspice 45.2 does, and what ASE-L now decides.

| card text | ngspice 45.2 | ASE-L | cost if they disagree |
|---|---|---|---|
| `.options method=gear $ seed=5` | unseeded | keeps the default | – (correct) |
| `.options method=gear //seed=5` | unseeded (`//` needs no space) | keeps the default | – (correct) |
| `.options method=gear$ seed=5` (no space before `$`) | **seeded** 931.21 | card, drops the default | – (correct) |
| `.options method=gear$seed=5` | seeded | drops the default | – |
| `.options seed=5$note` | seeded | drops the default | – |
| `.options seed=5 ; note` / `// note` | seeded | drops the default | – |
| `.options noinit filetype="a;b" seed=5` (`;` inside a quoted string) | **seeded**: ngspice does not cut inside quotes | **keeps the default** (the strip cuts at `;`) | warning only: the rendered deck gives 931.2134 twice plus the "Multiple" warning |
| `.options method=gear` / `* c` / `+ seed=5` (comment line between) | seeded | keeps the default (`+` joins onto the comment) | warning only, 931.21 ×2 |
| `.options method=gear` / blank line / `+ seed=5` | seeded | keeps the default | warning only, 931.21 ×2 |
| `.options method=gear` / `+ ; x` / `+ seed=5` | seeded (`;` ends only its own physical line) | keeps the default (the join happens before the strip) | warning only, 931.21 ×2 |
| control `option seed = $s` | – | drops the default | correct: the `=` survives the `\s\$` cut |
| control `option reltol=1e-3 ; seed=5` then `reset` | – | drops it via `reset` | correct |

Sabotages beyond D4, on the final files (each restored, `cmp` ok):

| # | sabotage | result |
|---|---|---|
| Y1 | the strip cuts at any `$`, not only one after white space | **survives** (ALL PASS 11). No RS6 case has `$` without a space. Impact: `method=gear$seed=5` would be misjudged unseeded, which is warning only. A non-blocking fence gap; one `card-dollar-nospace` look-alike would close it. |
| Y2 | the strip runs for control lines only | reddens RS6 |
| Y3 | the strip loses the `;` arm | reddens RS6 |
| D3s | the continuation join is replaced by a drop | reddens RS6 and RS9 |

Suites at 5f88a7c65 (own Xvfb :286):

| suite | counted | display | receipt §7a |
|---|---|---|---|
| test_ase_run_seed | ALL PASS (11) | ALL PASS (11) | 11/11 ✓ |
| test_ase_optsheet_1441 | ALL PASS (64) | ALL PASS (90) | ✓ |
| test_ase_netlist_display | ALL PASS (5) | ALL PASS (6) | ✓ |
| test_ase_core | ALL PASS (674) | ALL PASS (674) | ✓ |

Not checked this round:
- The test_ase_optier_0963 display-arm TIMEOUT that §7a calls pre-existing. Not asked, and it costs
  two 600 s runs.
- The other suites in §7a.
- Anything on the fork ngspice.

Optional, cheap follow-ups:
- Y1's look-alike.
- A strip that ignores `;` inside double quotes.
- Comment and blank lines skipped when joining `+` continuations.

All of these are warning-only.
