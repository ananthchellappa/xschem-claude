# Batch F item 01 — issue 0305: one `node_token_split()` at all six `node=` walkers

## 1. Files changed

`src/draw.c` +344/-153 · `tests/headless/test_node_token_split.tcl` **new, 734 lines** ·
`tests/headless/test_wave_hilight.tcl` +16/-4 (WH9h landmine 40, restated) ·
`tests/headless/full_audit.sh` +5/-1 (pins the new test into `nogui_tests`) ·
`doc/claude/specs/mixed_signal_signal_browser.md` +90/-7 (§D1 rulings) · this receipt ·
`doc/claude/issues/0305-…-six-node-walkers.md` +70/-3 ("The fix, as landed").

## 2. Decisions and their evidence

**The change.** One static `node_token_split()` (`draw.c:3425`) parses the
`%[digits] [rawfile] [sim_type]` half of a `node=` entry; **all six** walkers call it
(`3546` `draw_graph`, `5071` `find_closest_wave`, `6034` `graph_point_at`, `6501`
`wave_hilight_envelope`, `7587` `graph_wave_resolve`, `8396` `graph_fullyzoom`). It
switches nothing — switch and restore stay at the call site, where the unwind point is
known. All four rulings below are in `doc/claude/specs/mixed_signal_signal_browser.md` §D1,
sub-section "`node_token_split()`, the one `%` parser (issue 0305)".

**RULING — the restore is an absolute index, never `extra_rawfile()`'s mode-5 swap.** Mode 5
swaps `extra_idx`↔`extra_prev_idx`, is not a stack pop, and 0305 nests a per-trace switch
*inside* the graph-level `rawfile=` switch, which a swap cannot unwind. Both levels use
`node_db_restore(idx)` = `extra_rawfile(2,"<idx>")`, which composes. Evidence: reverting
either level to mode 5 reddens NDP7/NDP8 (25 red) and NDB4/NDB5 (16 red).

**RULING — a per-trace switch re-resolves the sweep column BY NAME.** The first cut did so
only when the entry had its own `sweep=` token; that list may be shorter than `node=`
(documented carry-forward), so an index resolved in the *previous* DB subscripted the
foreign DB's `values[]` — a **segfault**, and the review blocker. All three walkers now keep
`sweep_name`, re-`get_raw_index()` after the switch, and clamp against the switched-in
`nvars`. Evidence: reverting it at one walker turns NDS1/NDS3/NDS5 into `signal 11`.

**RULING — an unresolvable per-trace database REFUSES the trace**, never falls back: a
fallback plots a different signal under the trace's name. Evidence: NDG5/NDG7/NDG8 are red
at parent `96f7678a`, where such an entry was pickable, boldable *and* markable. **RULING — the helper goes to all six walkers.** The *defects* in `find_closest_wave()`
(unbalanced mode-5 restore) and `graph_fullyzoom()` (two leaking `return 0` exits) are
untouched — item 2 owns them — but their hand-rolled `%` parse moved, because two surviving
copies are the exact drift mechanism 0305 diagnoses. **Structural guard (review finding):**
NDX1–NDX3 read `src/draw.c` and assert the `%` field is parsed in exactly two places, both
in `node_token_split()`, with exactly six call sites. **WH9h restated, not deleted:** two
source-level checks in `test_wave_hilight.tcl` named the old mechanism; both now demand two
switches, two restores, no swap (139 checks kept).

## 3. Tests and verbatim result

`tests/headless/test_node_token_split.tcl` — **91 checks**, true headless, pinned into
`full_audit.sh`'s `nogui_tests`; 19 of the 91 are red at parent `96f7678a`.

```
RESULT: ALL PASS (91 checks)
```

Neighbours, `run_suites.sh --nogui`, DISPLAY unset, GUI_GATE=1: `RESULT: 13/13 runs passed`
— wave_hilight 139, wave_markers 437, wave_crossdb_trace 51, ase_cosim 201, vcd_read 187,
vcd_time_base 124, raw_read_dispatch 51, raw_ascii_point_bounds 90, wave_viewer 57, snap 64,
drag_preview 43, trace_menu 71.

**Audit diff** vs `doc/claude/batch_F/baseline_status.txt`, re-run by this closer under the
identical DISPLAY-unset condition: `diff baseline(sorted) after(sorted)` → `179a180 >
test_node_token_split PASS`. **One row, one direction — the new test's own.** No other test
changed status either way, so there is no red→green to explain. Buckets 220P/14F/62C/0T/68S
over 364 vs the baseline's 219/14/62/0/68 over 363; the 62 CRASHes are Tk-without-DISPLAY
startup deaths, identical by name. `WIREEDIT: ALL PASS`, 0 leaked dirs.

## 4. Sabotage table

Grouped by sabotage; **all 91 new checks appear, none unsabotaged** (a row per check is 93 lines,
over cap). Each was restored from a byte-exact backup, `md5sum -c` clean, and re-run green.

| Checks | What was broken | Red? | Green after restore? |
|---|---|---|---|
| NDF1 NDF2 NDF9 NDF3 NDF4 NDF5 NDF6 NDF7 NDG1 NDF8 NDF10 | fixture: `mkraw` header claims 41 points but writes 0 `Values` rows (NDF1); VCD written empty (NDF2 NDF9); `raw switch 0`→`switch 9`, out of range (NDF3); →`switch 1`, stay on the VCD (NDF4 NDF5); `mkraw` declares `TOP.m.siga` not `v(anlg)` (NDF6 NDF7 NDG1); `mkvcd` emits `module mm` (NDF8); all VCD edges collapsed onto `#0` (NDF10) | yes | yes |
| NDF2b NDF2c NDF10b NDF10c NDF10d NDF10e NDF11 NDF12 NDF13 | fixture: `wide.raw`/`other.raw` written empty (NDF2b NDF2c); `mkraw_wide`'s last column renamed `v(wsw2)` (NDF10b); `nd_vcd_vars` forced to 99, killing the out-of-bounds premise (NDF10c); session raw's column declared `v(wtwo)` / `v(other)` (NDF10d NDF10e); a fifth `flags=graph` rect added (NDF11); `nd_setnode` emptied so `node=` is never set (NDF12 NDF13) | yes | yes |
| NDF14 NDF15 NDF16 NDF17 NDZ1 NDZ2 | fixture: `nd_box` returns `{}`, blinding the plot-box locator (NDF14–NDF17); the NDG11 block deleted (NDZ1); `error SABOTAGE_BOOM` before `set ::nd_body_completed 1` (NDZ2) | yes | yes |
| NDP1 NDP3 NDP4 NDP5 NDP6 NDB2 NDB3 NDM2 NDM4 NDM5 NDM6 NDM7 NDM8 NDM11 NDM12 NDG3 NDG5 NDG7 NDY2 NDS6 | `node_token_split()`: `my_strdup2(…, rawfile, tclresult())` → `…, ""` — the one parser stops reporting the per-trace DB | yes | yes |
| NDP2 NDB1 NDM1 NDM3 NDG9 NDG10 NDG11 | `node_token_split()`: unsuffixed branch `expr` ← `"zz_nope"` | yes | yes |
| NDG2 NDG4 NDT1 NDT2 NDT3 NDT4 NDP7 NDP8 NDP9 NDP10 | `node_token_split()`: dataset digits dropped, `ds = -1` (NDG2 NDG4); `node_dflt_sim_type()` gutted to `return "";` (NDT1–NDT4).  `graph_point_at()`: graph-level `node_db_restore(entry_extra_idx)` → mode-5 swap (NDP7 NDP8); `&& nd_min <= tol` dropped from the best-wave gate (NDP9); `node_valid = valid_rawfile` → `= 1` (NDP10) | yes | yes |
| NDP11 NDP12 NDS9 NDS10 NDT5 NDS1 NDS2 | `graph_point_at()`, four sabotages: per-node `node_db_restore(node_saved_idx)` deleted (NDP11 NDP12 NDS9 NDS10 NDT5); that unwind retargeted to `entry_extra_idx`, the wrong nesting level and ruling 1's own failure mode (NDS1 NDS2); sweep re-resolve reverted to "own token only", clamp deleted → **`FATAL: signal 11`** (NDS1); `node_sweep_idx = 1`, an in-range foreign column (NDS2) | yes | yes |
| NDB4 NDB5 NDB8 NDB9 NDB6 NDB7 NDS3 NDS4 (+WH9h ×2) | `wave_hilight_envelope()`, five sabotages: graph-level restore → mode-5 swap (NDB4 NDB5 +WH9h); per-node `node_db_restore` deleted (NDB8 NDB9 +WH9h); `if(wcnt != ni) continue` → `if(0)` (NDB6); `node_valid` forced to 1 (NDB7); sweep re-resolve reverted → **`signal 11`** (NDS3); graph-level `extra_rawfile(autoload,…)` removed (NDS4) | yes | yes |
| NDS5 NDS7 NDG8 NDM9 NDM10 NDM13 NDG6 NDS8 | `graph_wave_resolve()`: sweep re-resolve reverted → **`signal 11`** (NDS5); `sw = 1`, the VCD's signal column read as time (NDS7); refusal `== 0` → `== 99` (NDG8). `graph_marker_sample()`: `node_db_restore(node_restore_idx)` deleted (NDM9 NDM10 NDM13 NDG6); graph-level switch → `if(0)` (NDS8) | yes | yes |
| NDY1 NDY2 NDY3 NDX1 NDX2 NDX3 | `graph_fullyzoom()`: `if(1) return 0;` at the top, walker is a no-op (NDY1 NDY2); per-node restore guard → `if(0)` (NDY3). `find_closest_wave()`: its `node_token_split()` call replaced by a **seventh hand-rolled `%` parse** — every behavioural check in every waveform suite stayed green (NDX1–NDX3) | yes | yes |

Review found NDY1/NDY2 **vacuous** in round 1 (`if(1) return 0;` left the file ALL PASS); NDY1
now demands the window MOVED off its seed. NDX1–NDX3 and the NDS/NDT legs are fix-round work.

## 5. What was NOT verified

**Eyeball owed — the GUI arm did not run.** DISPLAY `:0` is wedged (known WSLg Xwayland
abort); every suite and the audit ran `env -u DISPLAY GUI_GATE=1` — no Xvfb, no hidden
display, GUI_GATE never 0, the gate never asked, all GUI tests self-SKIPped (68 SKIP, as
baseline). **No on-screen pick, bold or marker behaviour was seen by eye**: nobody watched a
VCD trace go bold under a real click, or a marker callout render — only the engine answers
behind those pixels. **`find_closest_wave()` is not exercised behaviourally** either (only
`callback.c`'s motion handler reaches it); compile-verified, NDX3-pinned. **Left broken
deliberately for item 2/8:** its unbalanced mode-5 restore; `graph_fullyzoom()`'s two
leaking `return 0` exits; `graph_fullxzoom()` never parses `%` at all.

**Pre-existing, NOT fixed, wants an issue number from the driver:** `draw_graph()`, the
reference walker, has the SAME carried-sweep-column shape (`draw.c:~8385`: `sweep_idx`
resolved after its per-node switch and carried when an entry has no `sweep=` token, then
used to index `values[]`). Unchanged here (only its parse moved) and present at `96f7678a`;
unreachable headlessly, so it is a live SIGSEGV on a real display with a short `sweep=` list.

**Raised by review, NOT confirmed, no code changed:** (a) `node_dflt_sim_type()` is
evaluated as an *argument*, so `xctx->raw->sim_type` is read before the helper's two
`subst` calls where the pre-fix code read it after — no reachable differing input exists
(`db_path_safe` rejects `$ [ ] { } \`); (b) `wave_hilight_envelope()`'s cache key is
stamped with the per-trace DB current while the lookup compares the session raw, so a
cross-DB envelope can only miss — read, not measured, pre-dates this item, perf only;
(c) a non-reproducing `graph_point_at` session-DB leak seen once by a reviewer (six re-runs
clean). The one **confirmed** scope finding — an unrelated "Ten→Nine sabotages" edit in the
spec's §B — is **reverted**: that paragraph is byte-identical to `HEAD`, spec diff now one
hunk at §D1. **Reviewer "not proven":** none ran `full_audit.sh` (this closer did); none rebuilt the parent
control (implementer and verifier each did — 19 red at `96f7678a`); none re-ran their sabotages. The tree was concurrently mutated during the review
window, so §3's numbers were re-measured here on the final tree, which carries zero
`SABOTAGE` markers in any source file. **Not measured:** no leak run (`-d 3 -l log`).
**Uncovered by any check:** `graph_marker_sample()`'s bounds-check reorder (`point >=
allpoints` moved below the resolve) — hand-verified end to end instead (point 20 on a
9-sample VCD refused, points 8 and 20 on the 41-sample analog accepted).
