# Stage A receipt: the default seed steps aside for a bench that seeds itself

Crew: stage A task crew, 2026-11-12. Base e615a1801. Uncommitted; changed files:
`src/ase.tcl`, `tests/headless/test_ase_run_seed.tcl`. Nothing else touched.

## 1. Measurement: the gap is real

Hand-built decks laid out the way render_deck orders them (the netlist body first, then ASE-L's
`.options seed=1`, then a `.control` block), drawing `.param rv=agauss(1000,100,1)` into
`r1` and printing `@r1[resistance]`. Each deck was run twice with `env -u DISPLAY HOME=/tmp/nohome
<ng> -b`. Two binaries:
- **stock** `/usr/bin/ngspice` (ngspice-45.2). This is what RS5/RS7/RS8 use: `auto_execok ngspice`
  on PATH under run_suites.sh.
- **fork** `/home/analog/dev/ngspice-ver_53/build-ver_53/src/ngspice` (ngspice-46+, the registry's
  `ng_w_stb`).

Reference values (both binaries): seed 1 -> 886.0342, seed 5 -> 931.2134, seed 42 -> 992.9800.
Unseeded: stock differs run to run; the fork repeats 886.0342 (the fork's start-up seed is
fixed, so on the fork no unseeded/seeded difference is visible).

| bench's own text | without ASE-L's line | with ASE-L's `.options seed=1` |
|---|---|---|
| netlist card `.options seed=5` | 931.21 | 931.21, plus `Warning: Multiple 'option seed=val\|random' found!` (both binaries) |
| netlist card `.option method=gear seed=5` | 931.21 | 931.21, plus the same warning |
| `.control`: `setseed 42`, `reset` | **992.98** (seed 42) | **886.03** (seed 1); the fork also warns that `.option seed` overrides `setseed` |
| netlist's own `.control`: `setseed 42`, `reset` | 992.98 | 886.03, same fork warning |
| `.control`: `setseed 42`, `mc_source` | 992.98 | 886.03 |
| `.control`: `option seed=5`, `reset` | fork 931.21 / stock varies | 886.03, with the fork warning |
| `.control` loop: `op`, print, `reset`, `op`, print | two different draws per run (both binaries) | **the same draw on both passes** |
| `.control`: `setseed 42` only (no re-parse) | stock netlist draw varies; `sgauss(0)` = -0.0701997 | netlist draw 886.03; `sgauss(0)` = -0.0701997, **unchanged** |
| `.control`: `option seed=5` only | no effect on the draw | 886.03 |
| `.control`: `set rndseed=42` only | stock varies; fork 886.03 | 886.03 |

Conclusions:
- The netlist **card** case: the netlist's card governs, because it is read first. The only cost is
  ngspice's "Multiple option seed" warning. It is now handled too, because that fix is cheap.
- **Control text that re-parses (`reset`, `mc_source`) after the bench's own seeding is the real
  gap.** ASE-L's line wins, so the bench's `setseed 42` silently draws seed 1's silicon. A
  hand-written reset loop collapses to one sample on every pass. This shows on both binaries, so
  the new rows discriminate on the fork as well as on stock.
- A bare `setseed` with no re-parse after it does **not** conflict. It seeds the interpreter's
  draws, and those are identical with and without the default. The netlist draw at load time is
  untouched by it either way.

## 2. The fix (src/ase.tcl)

- `ase::backend::ngspice::user_seed_line {kind line}`: a new adapter hook, registered in the
  ngspice backend dict next to `campaign_seed_option`.
  - For `control` lines it answers 1 on a line that starts with `reset` or `mc_source`, or on an
    `option`/`.options` line with `seed=`.
  - For `card` lines (netlist text outside `.control`) it answers 1 only on a `.opt*` card with
    `seed=`.
- `ase::run_seed_user {sim state {netlist_text {}}}`: new. It returns the first matching line as
  `{where line}`. It judges the lines `ase::preflight_lint_sources` collects (pre-commands, the
  verbatim lines of enabled rows, the netlist's own `.control`) as `control`, and the netlist's
  lines outside `.control` as `card`. With no hook it returns `{}`, and it never raises.
- `ase::run_seed_line` takes an optional `netlist_text` and returns `{}` when `run_seed_user`
  finds a line. The comment above it replaces the old sentence "A seed in the user's own netlist
  needs no test here". That sentence was true for the draw, but not for the warning or for
  re-parses.
- render_deck (ngspice backend) passes `$netlist_text` to `run_seed_line`.
- `ase::opt_preview` takes an optional 4th argument `netlist_text` and passes it through.

Ported from private 7843e17e7, which was read for its seed logic only: the `run_seed_user` shape
and the hook idea. **Deliberate divergence:** private counts a bare `setseed` as self-seeding. This
tree does not, because of the measurement above: stepping aside there would make the netlist's
`tt_mm` mismatch draw unrepeatable on stock 45.2 and gain the user's `setseed` nothing. A
`setseed` followed by `reset` or `mc_source` still steps aside, through the re-parse word.

Not ported: the `mc_render`/campaign-nominal marks (this tree has neither), the window's
netlist-reading preview, the noise-form change (`ase::stimuli_seeded`), and the FAQ and issue
edits.

## 3. Rows (test_ase_run_seed: 5 checks -> 9 on stock ngspice; floor 4 -> 6)

- **RS6** renders 13 cases and counts the default lines in each.
  - Six cases must get **no** default: `reset` in the pre-commands, `mc_source` in the
    pre-commands, `option seed=5` in the pre-commands, an enabled row's verbatim `reset`, the
    netlist's own `.control` with `reset`, and a netlist `.option method=gear seed=5` card.
  - Six look-alikes must **keep** it: a bare `setseed 42`, `echo no reset here`, a device named
    `reset`, `.param seed=5`, a disabled row's verbatim `reset`, and a plain bench.
  - One more must get no default: a seed card inside `.control`, which is judged as control text.
- **RS6b**: the options preview given a plain netlist shows the default, and given a netlist that
  resets in its `.control` shows none. The first leg was added after the first version passed
  vacuously on the old code: the 4-argument call raised and its count was 0.
- **RS7** (needs ngspice): ASE-L's real render, with pre-commands `setseed 42` and `reset`, prints
  seed 42's value. Its distinctness leg checks that seed 42's value is not the default's.
- **RS8** (needs ngspice): ASE-L's real render, with a hand-written `op`/`reset`/`op` loop in the
  pre-commands, prints two different values.

**Red first, on the original src/ase.tcl** (copied back, run, restored, `cmp` ok): RS6, RS6b, RS7
and RS8 fail, giving `4 FAILED (5 passed)`. RS1 to RS5 pass.

**Sabotages, one at a time on the fixed file** (restored by `cp`, `cmp` ok after the loop):

| # | sabotage | reddens |
|---|---|---|
| S1 | render_deck does not pass the netlist | RS6 |
| S2 | opt_preview does not pass the netlist | RS6b |
| S3 | the card scan is skipped | RS6 |
| S4 | `mc_source` is dropped from the list | RS6 |
| S5 | the control match is unanchored | RS6 |
| S6 | cards are judged as control text | RS6 |
| S7 | `setseed` is added to the list (private's rule) | RS6 |
| S8 | the `run_seed_user` test in run_seed_line is removed | RS6, RS6b, RS7, RS8 |
| S9 | `option seed=` in control is not counted | RS6 |

## 4. Suites run

Counted arm, `AUDIT_DISPLAY=:271 SUITE_TIMEOUT=600 tests/headless/run_suites.sh --nogui <t>`, on my
own Xvfb `:271`. It was killed by pid after each batch; no openbox was started.

| suite | checks |
|---|---|
| test_ase_run_seed | ALL PASS (9) |
| test_ase_netlist_display | ALL PASS (5); `skip: ND6 needs a display`, as before |
| test_ase_core | ALL PASS (674) |
| test_ase_campaign_1462 | ALL PASS (161) |
| test_ase_effective_1442 | ALL PASS (97) |
| test_ase_optsheet_1441 | ALL PASS (64) |
| test_ase_predeck_1439 | ALL PASS (78) |
| test_ase_optier_0963 | ALL PASS (110) |

The last five were added because they reference `opt_preview`, `campaign_seed_option` or
`run_seed_line`. The suite was already registered in `hcases`, so `tests/run_regression.tcl` is
unchanged.

## 4b. Follow-up (driver's request): the window's options preview reads the run's netlist

Changed: `src/ase_window.tcl`, `tests/headless/test_ase_run_seed.tcl`,
`tests/headless/test_ase_optsheet_1441.tcl`.

- New `ase::ui::optsheet_netlist_text {key}` reads `<rundir>/<cell>.spice` the way
  `ase::ui::netlist_display_text` does. It does no netlisting and writes nothing.
  - It returns `{}` when there is no netlist yet or the read fails, and it never raises.
  - It keeps only the lines the seed rule reads: dot cards, and `.control` blocks whole.
  - It caches its answer per file, keyed on size and mtime, because the sheet refills on every
    keystroke in its Find box.
  - **Declared limit:** a rewrite with the same size inside the same second as the cached copy is
    not seen until the next change.
- `ase::ui::optsheet_preview` passes that text as `ase::opt_preview`'s new 4th argument. The pane
  now drops the default seed line exactly when the deck does.

Rows:
- **RS9** (test_ase_run_seed, counted and display arms): drives a real session through
  `ase::session_open`. Expected answers: `none=1 resets=0 wrote=0 card=0 plain=1`.
  - `none=1`: no netlist yet, so the default shows.
  - `resets=0`: the netlist's `.control` resets, so the default is dropped.
  - `wrote=0`: the read wrote nothing to the rundir.
  - `card=0`: a `.option method=gear seed=5` card drops it.
  - `plain=1`: a plain replacement file shows it again, so the cache follows the file.
- **UI17d** (test_ase_optsheet_1441, display arm, real sheet): `.options seed=1` is in the pane
  beside a plain `nfet_ui.spice` and absent beside one whose `.control` resets. A file that already
  existed is restored afterwards.

**Red first** with the original `src/ase_window.tcl` (copied back, run, restored, `cmp` ok):
- RS9 fails: `1 FAILED (9 passed)`.
- UI17d fails: `1 FAILED (89 passed)`.

**Sabotages, one at a time** (restored, `cmp` ok):

| # | sabotage | RS9 | UI17d |
|---|---|---|---|
| W1 | the cache ignores the stamp | red | red |
| W2 | the reduced read drops dot cards | red | red |
| W3 | the reduced read drops `.control` text | red | green |
| W4 | the preview does not pass the netlist | green | red |

W4 can only be seen on the display arm, because RS9 calls the reader directly.

**Suites on both arms**, run on my own Xvfb `:271` plus openbox (pids killed afterwards, both
confirmed dead). Counted arm: `run_suites.sh --nogui`. Display arm: `run_suites.sh` with
`GUI_GATE=0`.

| suite | counted | display |
|---|---|---|
| test_ase_run_seed | 10 | 10 |
| test_ase_optsheet_1441 | 64 | 90 |
| test_ase_netlist_display | 5 | 6 |
| test_ase_core | 674 | 674 |
| test_ase_effective_1442 | 97 | 97 |
| test_ase_conv_gui_1460 | 45 | 105 |
| test_ase_window | 71 | 349 |
| test_ase_predeck_1439 | 78 | 78 |
| test_ase_campaign_1462 | 161 | 161 |
| test_ase_dialogs | 37 | 1 FAILED (388 passed) |

Every cell is ALL PASS except the test_ase_dialogs display arm. That one failure is row
**G2sens**, and it is **pre-existing**: the same row fails identically with both original files
restored. test_ase_dialogs is registered in `hcases` only, and private 7843e17e7 lists the same
G2sens display-arm failure as it was at BASE.

## 5. Not done, and limits

- ~~The window's options preview passed no netlist~~: closed in §4b.
- `ase::stimuli_seeded` (the noise form's "repeats under the seed" sentence) does not count the
  default in this tree, before or after this change. Unchanged.
- The `source` command in `.control` also re-parses, but it parses another file whose own options
  govern. It is not in the list and was not measured.
- Seed cards inside `.include`d or `.lib` files are not seen, because only the netlist text is
  scanned.
- `set rndseed=` alone was measured to have no effect on stock either way, so it is not in the
  list.
- No issue file was minted and no FAQ entry was written. FAQ Q93 still describes the old "netlist
  needs no test" reasoning only implicitly; the driver may want a short Q94-style note.

## 6. Engineering decision (the driver confirmed it is not a ruling)

A bare `setseed` does not stand the default aside. Measured: the default does not touch the draws
`setseed` controls (the interpreter's `sgauss` was identical with and without it). Stepping aside
would only make the netlist's mismatch draw unrepeatable on stock 45.2, against the user's ruling
"tt_mm should give same result each time". This differs from private 7843e17e7 on purpose, and
row RS6's `bare-setseed=1` leg (sabotage S7) fences it.

## 7. Verifier findings (receipts/A-verify.md) and what was done

**D1 (blocking): the preview reader created directories and moved a global.** Fixed.

The cause: `ase::ui::optsheet_netlist_text` called `ase::rundir`. That helper runs `file mkdir`,
and for a bench with no run directory it runs `set_netlist_dir 0`, which creates
`$USER_CONF_DIR/simulations` and sets `::netlist_dir`. The preview runs on every Find keystroke,
so this broke the R602e rule.

The fix: the reader now only reads.
- It takes the state's `rundir` key as it is, the way `ase::ui::rsel_resolve_input` does.
- For a bench with no run directory it falls back to the existing `::netlist_dir`, else
  `$USER_CONF_DIR/simulations`.
- It uses a directory only if `file isdirectory` says it exists, and creates nothing.
- **Declared limit** (in the proc's comment): with `local_netlist_dir` set, it does not look in the
  schematic-local directory that `simuldir` would choose.

New row **RS10**: previews a bench whose run directory is missing, then one that names none.
- It first sets `::netlist_dir` to `{}`, because xschemrc presets it and the leg would otherwise
  be vacuous.
- Expected `missing_made=0 nd_moved=0 sims_made=0`. On the previous window file it gives
  `missing_made=1 nd_moved=1 sims_made=1`, which is red.
- Restoring the `ase::rundir` call (sabotage D1) reddens RS10.

**D2: an inline comment was taken as the bench's seed.** Fixed.

Measured on stock 45.2: each of these cards leaves the bench unseeded (different draws on each
run):
- `.options method=gear $ seed=5`
- `.options method=gear $seed=5`
- `.options method=gear ; seed=5`
- `.options method=gear // seed=5`

The pre-command `option reltol=1e-3 ; seed=5` followed by `reset` is unseeded on stock as well.
By contrast, `.options seed=5 $ note` seeds (931.2134 on both runs). The fork's unseeded draw is
fixed, so it cannot show these cases.

`ase::backend::ngspice::user_seed_line` now cuts the line at `;`, at `//`, or at a `$` that
follows white space, before it matches. New RS6 cases: `card-dollar`, `card-semi`, `card-slash`
and `pre-semi` keep the default, and `card-note` drops it.

**D3: a `+` continuation was not read.** Handled, because joining the lines was cheap.

Measured: `.options method=gear` followed by `+ seed=5` seeds, giving 931.2134 on both binaries.
With ASE-L's line added it also prints the "Multiple 'option seed'" warning.
- `ase::run_seed_user` now joins `+` lines onto the card above them before it judges a card.
- The window reader keeps a `+` line only if it follows a line it kept, so a device's
  continuation is not glued onto an option card.

New RS6 cases: `card-plus` drops the default, and `device-plus` (`+ seed=5` after a resistor)
keeps it. RS9's card file is now the two-line form.

The `.include`/`.lib` limit is now declared in the comment above `ase::run_seed_user`.

**D4: fence gaps.** All of them are closed. New RS6 cases:
- `reset-word` (`resetx 1` keeps the default)
- `card-upper` (`.OPTIONS SEED=5` drops it)
- `card-rseed` (`.options rseed=5` keeps it)

RS9's resetting netlist is now `.CONTROL`/`RESET`/`.ENDC`.

Sabotages on the final files (each restored by `cp`, `cmp` ok after the loop):

| # | sabotage | reddens |
|---|---|---|
| X1 | the word end after `reset` is dropped | RS6 |
| X2 | the card regex loses `-nocase` | RS6 |
| X3 | `\m` before `seed` is dropped | RS6 |
| X5 | the reader's `.control` test is case-sensitive | RS9 |
| D2 | no comment strip | RS6 |
| D2b | the strip forgets `//` | RS6 |
| D3 | no continuation join | RS6, RS9 |
| D3r | the reader drops `+` lines | RS9 |
| D1 | the reader goes back to `ase::rundir` | RS10 |

The full previous code (both files as they were before this round) gives `3 FAILED (8 passed)`:
RS6, RS9 and RS10 are red. test_ase_run_seed now has 11 checks, with the floor at 8.

Suites on both arms, run on my own Xvfb `:272` plus openbox: see §7a.

### 7a. Suites after the verifier fixes

Both arms ran on my own Xvfb `:272` plus openbox, with both pids killed and confirmed dead
afterwards. Counted arm: `run_suites.sh --nogui`. Display arm: `GUI_GATE=0 run_suites.sh`. Both
used `SUITE_TIMEOUT=600`.

| suite | counted | display |
|---|---|---|
| test_ase_run_seed | 11 | 11 |
| test_ase_optsheet_1441 | 64 | 90 |
| test_ase_netlist_display | 5 | 6 |
| test_ase_core | 674 | 674 |
| test_ase_effective_1442 | 97 | 97 |
| test_ase_conv_gui_1460 | 45 | 105 |
| test_ase_dialogs | 37 | 1 FAILED (388 passed), G2sens |
| test_ase_window | 71 | 349 |
| test_ase_predeck_1439 | 78 | 78 |
| test_ase_campaign_1462 | 161 | 161 |
| test_ase_optier_0963 | 110 | TIMEOUT after 600 s |

Every cell is ALL PASS except the two display-arm entries named in the table.

Both display-arm failures are **pre-existing**, and both suites are registered in `hcases` only:
- **G2sens** was confirmed in §4b and by the verifier.
- **The test_ase_optier_0963 TIMEOUT** happens identically on the BASE files. I copied the original
  `src/ase.tcl` and `src/ase_window.tcl` back, ran on a separate Xvfb `:273`, got
  `TIMEOUT after 600s`, then restored the files (`cmp` ok). Private 7843e17e7 records the same
  display-arm TIMEOUT for this suite (an Ask Save dialog).
