# Item 2 — `src/results.tcl`: the pure resolver and the registry readers (R201-R204, R304, R305)

## 1. Files changed

| file | lines |
|---|---|
| **`src/results.tcl`** | **NEW, 379.** `results::resolve`, `results::list`, `results::current` + five private helpers (`_get`, `_isfile`, `_readable`, `_unterminated`, `_is_result_type`). Nothing else. |
| `src/xschem.tcl` | +8 — one `source $XSCHEM_SHAREDIR/results.tcl` after `wave_viewer.tcl`, with the ordering reason |
| `src/Makefile.in` | 1 changed — `results.tcl` in `/local/install_shares` |
| `src/Makefile` (generated, untracked, **not committed**) | `./configure` re-run; diff is exactly the install (`:225`) and uninstall (`:286`) lines. `Makefile.conf`/`config.h` byte-identical. |
| `tests/headless/test_results_select.tcl` | +457 (groups J..N) |
| `doc/claude/specs/results_selection.md` | +153/-3 — §4.1 (R201a-e), §5.1 (R304a/b, R305a/b), R803a, R805a, and the line-citation rule next to L9 |
| `results_batch/PLAN.md`, `specs/hierarchy_editor.md`, `specs/typed_signal_accessors.md`, `hierarchy_editor_batch/PLAN.md`, `issues/0508-*.md` | **14** `xschem.tcl:<line>` citations staled by the +8 insertion, each re-derived from its symbol; the closer found two still stale in `results_batch/PLAN.md` (the Waves cascade range `:17128-17149`, and `Clear` at `:17131` in two places) and fixed them |

**No C. No `results::select`.** `grep -nE 'raw (read|switch|select|clear)' src/results.tcl` returns three **comment** lines and no code — the scope fence held.

## 2. Decisions taken, and the evidence

All written into `doc/claude/specs/results_selection.md`; none re-opens `DECISIONS.md`.

- **R201a — `state` is a dict of resolution INPUTS** (`rawfile rundir derived key netlist`), not an ASE session state. An ASE state forces the
  resolver into `ase::` for its own inputs (kills R204 purity; untestable without a live session + backend hook, `src/ase.tcl:1952-1961`), and "the
  state" was already ambiguous: the saved `rawfile` lives in the
**viewer** sub-dict (`src/wave_viewer.tcl:3995`), which is why `ase::ui::viewer_restore` reads `$vd` for the path and
`$st` for the rundir. **R201b** — key set fixed (`status path named derived why reason msg`); `named` survives a
missing file, because R804-class sentences name it.
- **R201c — an existing but UNREADABLE file is `invalid`, not `stale`.** R202 makes `stale` selectable; an unreadable file cannot be selected, so
  calling it stale offers a choice that cannot be honoured. **R201d** — the derived path is existence-gated wherever returned, which is what makes T-H's
  *"derived when one exists on disk, `{}` otherwise"* true for an explicit `derived` too (SEL87, SEL103). **R201e** — `default` is a statement about the
  STATE: no content/mtime verdict on a derived default, which describes a choice the user did not make.
- **R304a — `results::list` lists EVERY slot, VCD and table included.** R102's filter is the dialog's job (item 7); `results::select` must see every
  slot to answer *"is this path already loaded?"*. **R304b** — `cur` marks, it does not reorder: R301(1)/L10 hand `idx` straight back to `xschem raw
  switch`.
- **R305a — R103's third part is asked of the ENGINE.** `results::current` returns `{}` unless `xschem raw loaded` (`src/scheduler.c:10448` →
  `sch_waves_loaded()`, `src/draw.c:2825`) is `>= 0`. Read out of the C: an **ancestor** match counts (`draw.c:2831-2838`, R110a's basis) and level 0 is
  legal, so `>= 0`, never `!= 0`. **"Resolves" therefore means**: `raw->schname` is found anywhere on the stack from `xctx->currsch` down to 0 — the
  cell it was read under, or any ancestor of where you now stand. Item 1's R110a guard uses the same predicate, so `results::current` and `raw read`
  agree by construction (SEL121-123).
- **R305b — R102 is applied in `results::current` only**, via `_is_result_type`. R102's authority `raw_type_is_non_spice()` (`src/save.c:1622`) has
  **no Tcl verb**; `xschem raw is_digital <type>` answers the reader table's *other* column and returns 0 for `table` on purpose
  (`test_backannotate_digital` BA12). So the gate asks the engine for the VCD half and writes down exactly one reader token, `table`, in one place with
  its C predicate beside it. A `raw non_spice` verb is C and belongs to item 3.
- **R803a** — the resolver names by `file tail`; the full `db_label` form is unreachable there (R201a carries no `sim_type`; it resolves a path before
  anything is loaded), so it belongs to `results::select` (R302) and the dialog (R404). **R805a** — one terminator: only the composed `msg` is trimmed,
  never the verdict's own `why` (R203).

## 3. Tests

`tests/headless/test_results_select.tcl`, groups **J..N**: **SEL75..SEL137 + SEL119a + SEL125a
= 65 new checks**, total **139**. Band measured free by grepping (highest in use was 74); no
item-1 id renumbered or deleted. J = wired-up-and-installed (75-81), K = T-K's no-by-word-parser
half (82-84), L = T-H's four statuses (85-112, 127-129, 136-137), M = R304 (113-119a),
N = R305/F4/R102 (120-126, 125a, 130-135).

```
test_results_select: 139 passed, 0 failed
RESULT: ALL PASS (139 checks)
PASS     | test_results_select          run 1/1  RESULT: ALL PASS (139 checks)
```
Both arms: X (`run_suites.sh`, dev display `:99`) and `--nogui` (`gated_xschem.sh`).

## 4. Sabotage — one row per drive; every new id has a red except SEL119a

Break, run, record reds, restore from a byte-exact backup (`cmp -s`; never `git checkout --`,
the item is uncommitted), re-run green. All rows went red and all restored green.

| # | what was broken | reds |
|---|---|---|
| S-A/S-L/S-T | pre-feature drive: `source` commented, deleted, then `results.tcl` absent | 38 → 39 (+SEL77) → 41 (+SEL76, 82); the 13 staying green are exactly the file-content/install-list ones |
| S-M / S-Q | dropped from `Makefile.in` + generated `Makefile` / the test's install-list parser neutered | SEL78,80,81 / SEL79 |
| S-B / S-S2 / S-P | by-word idiom reintroduced (0507's defect) / a second per-line parser / the detector neutered | SEL83,118 / SEL82 / SEL84 |
| S-O / S-J / S-U2 | `rawinfo_parse` renamed at the call site / `cur` never marked / `list` MOVES the pointer | SEL114-118,120,122,124 / SEL114-116,120,122,124 / SEL116,119,125 |
| S-H / S-I | derived not existence-gated / relative-vs-`rundir` removed | SEL87,103 / SEL89 |
| S-F / S-G / S-D / S-K | content half of `stale` / mtime half / `stale` falls back / `stale` yields no path | SEL91,93 / SEL95,97 / SEL94 / SEL92,94,96 |
| S-E / S-R / S-V | `invalid` throws / the `last_rawfile` shim never restored / `resolve` mutates (R204) | SEL100-104 / SEL111 / SEL112 |
| S-C | `results::current` drops the stamp gate (R103 part 3) | SEL123 |
| **S-X (C)** | `sch_waves_loaded()` stamp compare forced true, `draw.c:2834`, full rebuild | item 1's S4 set (SEL5,6,17,18,30,31,37,39,45,53,56,60,65) **+ SEL121, SEL123** |
| X1/X2/X3/X6 | R102 gate deleted / gate refuses everything / `table` arm dropped / gate moved into `list` | SEL132,135 / SEL120,124,130,134 / SEL135 / SEL133,135 |
| X5 / X7 / X8 | fixture: the VCD is no longer current / `invalid` reverts to the absolute path (R803) / `_unterminated` disarmed (`..`) | SEL131-133 / SEL137 / SEL136 |
| X9 / X10 | `catch {xschem raw switch 0}` planted in `resolve` (reviewer's reproducer, green at 128) / group L's second read deleted | SEL112 / SEL127 |
| X11 / X12 | the `_readable` arm deleted (R201c) / the fixture's `-permissions 0000` removed | SEL129 / SEL128,129 |
| X13 | `results::current` returns `[lindex [results::list] 0]` (reviewer's reproducer, green at 128) | SEL130,132,135 — SEL120/124 stay green, the hole SEL130 closes |

**Unsabotaged, i.e. not evidence: SEL119a.** Deleting group M's `xschem raw switch $r2_sp tran` preload leaves the
suite green, because SEL118's space-path read already leaves slot 2 current. It is a non-vacuity guard on SEL119, not
an assertion about `results.tcl`; its siblings SEL125a and SEL127 both red under theirs. Three checks were caught
vacuous **by** sabotage and rewritten, not hidden: SEL77 (a commented-out `source` still matched the glob), SEL82 (a
comment naming `rawinfo_parse` satisfied it, so a hand-rolled parser passed), SEL112/119/125 (captured against a
registry that could not show the mutation). The red-id extractor matched `^FAIL: (SEL[0-9]+)`, so it printed `SEL125a`
as `SEL125` — affects the two lettered ids and no conclusion.

## 5. Audit, and what was NOT verified

**Closer's audit:** `full_audit.sh`, `GUI_GATE=1`, dev display `:99` (the harness forces `GUI_GATE=0` for itself
there) — `SUMMARY: 332 pass  15 fail  0 crash/timeout  0 skip  (total 347)`, `WIREEDIT: PASS`,
`SCRATCH: 0 leaked dir(s)`, `TREE: 0 appeared  0 vanished`. Diffed by NAME and STATUS against
`baseline_2026-08-19_226302f9.txt` (331/15/0/0 of 346) with a join on the test name: **0 green→red, 0 red→green
across all 346 shared rows; nothing only in the baseline**. The single difference is `test_results_select` **PASS**,
the suite `LEDGER.md` already records as added by item 1. The 15 reds are the baseline's 15 by name
(`test_ase_window`, `test_cadence_drag`, `test_ciw`, the four libmgr environment reds, `test_lib_sweep`,
`test_reopen_readonly`, `test_rotate_stretch_short_0104`, `test_selflog_output`, `test_wave_markers`,
`test_wave_sigbrowser_0312`, `test_wave_sigbrowser_keys`).

- **No installed-tree run by me.** SEL78/80/81 prove `results.tcl` is *listed* in the install and uninstall rules; the verifier closed it once with a
  real `make -C src install DESTDIR=…`, which no reviewer repeated. SEL80/81 assert the
**generated, gitignored** `src/Makefile`: in a never-`./configure`d tree they would red for a non-regression reason.
- **`ase::last_rawfile` is proved via a SHIM** (SEL108-110), as L1 prescribes for `select_raw`; a live-session leg belongs to item 6 (T-E). SEL111
  only asserts a proc of that name exists, not that the original is back. **`<NULL>` `sim_type` is still unexercised** (the engine infers `tran`; L6's
  slot is reachable only by index), and `netlist` is always an explicit path — deriving `<rundir>/<cell>.spice` is what R201a rejects.
- **Reviewer observations raised but not confirmed as defects, unfiled:** a 0-byte raw and a `.vcd` both resolve `ok` (`ase::raw_content_verdict` says
  nothing on an empty plotname and R203 forbids a second content check here); `named` is not absolute-ised without a `rundir` (doc overstatement); a
  non-existent explicit `derived` blocks the `key` fallback (no caller passes both); `resolve` does not normalize `..` while `list` returns the engine's
  verbatim spelling (pre-existing — the engine dedupes by `strcmp` — but item 4's "already loaded?" sits on top of it); a throwing `raw_content_verdict`
  would be swallowed as `ok` (no reachable case); a whitespace-padded `rawfile` resolves `invalid`; `results::list` shadows Tcl's `list` inside the
  namespace (documented in the header, every construction written `::list` — a hazard for item 4). R201e is suspected-uncovered: no reviewer built the
  sabotage.
- **Not re-derived by me:** the sabotage drives above are the implementer's, verifier's and fixer's. I re-ran the suite on both arms and the audit,
  not the drives.
- **No leak trace, no multi-tab probe, no eyeball owed** — three Tcl procs and their contract; nothing on screen changed, so nothing was added to
  `owed.sh`.
