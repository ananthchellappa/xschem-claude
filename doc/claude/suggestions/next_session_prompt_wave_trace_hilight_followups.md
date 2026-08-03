# Session prompt — wave-trace-highlight follow-ups

*Written 2026-08-02, after `a5026c32` landed. Paste the block below into a fresh session.*

---

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

**Net-highlight styles on waveform traces is DONE and committed** as `a5026c32`
(unpushed). Do not re-implement it. Read, in this order, before touching
anything on this path:

- `doc/claude/specs/wave_trace_hilight.md` — **§13 "As shipped" is the
  authority**; it records every delta from the original text and the known
  limits, so §4-§8 above it must be read *through* §13.
- `doc/claude/code_analysis/waveform_subsystem_reference.md` — the map and the
  landmines (11, 16, 17, 19, 33, 34, 37, 38, 40, 43, 44, 46, 50 are all live on
  this path).
- `tests/headless/test_wave_hilight.tcl` — its header carries the four test
  groups AND the eight-sabotage protocol with measured kill counts.

The feature in one line: `9`/`8`/`0` on the `WaveViewer` bindtag highlight the
selected trace(s) with a `net_hilight_style` row, stroked as a window-only
overlay over a cached per-screen-column min/max envelope, animated without ever
calling `draw()`.

Suites as committed: `test_wave_hilight` 139 checks `--nogui`, 196 under a
DISPLAY; `test_wave_grid` 213; `test_wave_markers` 979; `test_wave_viewer` 368.
All green at `a5026c32`.

## Work items, in the order I would do them

### 1. The reference doc owes a landmine entry (do this first — it is the cheap one)

Every feature on this path since 0188 added its lesson to
`doc/claude/code_analysis/waveform_subsystem_reference.md` §11 (landmines 45,
46, 47, 48, 49, 50 were each written by the work that discovered them). This one
did not, and it discovered five things worth the next person's time:

- **`net_hilight_anim_update()` clobbers the interp result.** It runs
  `tclvareval("net_hilight_anim_update {<win>}")` per open window, so any verb
  that sets its result *before* calling it returns the tick proc's empty answer
  instead. It is the landmine-24 class, second instance — and it is
  **DISPLAY-only**, because the fan-out opens with `if(!has_x) return;`, so the
  headless arm cannot see it. Measured here.
- **A window-only overlay painted at the tail of `draw()` has NO clip.** The
  real trace is confined by `draw_graph`'s `bbox(SET)`; anything drawn after
  that bracket is not, so it smears across neighbouring strips — and if the
  erase is box-clamped while the stroke is not, the smear is permanent.
- **A copy-back erase must be a whole PASS before the paint pass.** Interleaved
  per entry, entry k+1's erase wipes entry k wherever the bboxes overlap, i.e.
  whenever two traces of one strip carry the state.
- **`draw_hilight_net()` returns early on `!xctx->hilight_nets`, so a VIEWER
  never reaches anything it does** — including its `net_hilight_anim_sig = 0`
  invalidation. Any new animated thing in a viewer owes its own copy. This is
  the same shape as the two gate terms, and it is the third place that shape has
  bitten.
- **A cache key that is a FIELD LIST outgrows itself; the rect's whole
  `prop_ptr` does not.** `node`, `sweep`, `%N`, `rawfile`, `sim_type`,
  `digital`, `logx`, `logy` and `dataset` all steer a graph walk and all live in
  one string that is rewritten in place by paths a cache never hears about.

Also add `test_wave_hilight.tcl` to the suite inventory in §13 of that file, and
add the `xschem wave_hilight` / `get wave_hilight*` / `get hilight_color` verbs
to §9's subcommand surface.

### 2. Measure (and if needed fix) the re-arm cost of `wave_hilight_push`

`wviewer::wave_hilight_push` calls `xschem wave_hilight` once per entry, and
that verb calls `net_hilight_anim_update()`, which fans out over
`MAX_NEW_WINDOWS` with a Tcl round trip each. `regenerate` calls the push, and a
plain window RESIZE calls `regenerate`. With 16 highlights and an ANIMATING
style installed that is up to 16 × (open windows) `tclvareval`s per resize.

It short-circuits on `!net_hilight_has_anim_style`, so the default table costs
one boolean read per entry and this may well be nothing. **Measure it before
changing it** — drag a viewer window edge with 16 marching highlights up and
time the resize, e.g. with a `trace add execution xschem enter` counter, or
`-d 1` on a child process. If it is real, the fix that stays inside the shipped
surface is a trailing-pairs arm on the verb (the `xschem set graph_preview`
precedent, issue 0192) so a push is one call and one re-arm.

### 3. Spec §11 deferrals, in the order they are worth doing

- **Per-trace style from the RMB context menu** (`wviewer::trace_menu_build`,
  `wave_viewer.tcl`, currently one entry). Cheapest and most discoverable: the
  keys exist and the verbs exist, so this is a menu entry plus a style submenu.
  The plumbing to copy is `wviewer::apply_style_traces` — including its
  `net_hilight_style_index_for` log line, which is what makes an ad-hoc style
  replayable.
- **Digital / bus traces (D8).** Their rendering is a band and a ribbon, not a
  polyline, so this is a *new* overlay shape, not a flag flip. The refusal is
  already per trace (the analog members of a mixed selection still highlight),
  so the user-visible gap is narrow.
- **Cross-probe to the schematic net (D3).** Needs `v(node)` → schematic-token
  resolution, which is landmine 23's problem (`#netN` vs `netN`) plus hierarchy.
  Read `ase-unnamed-net-pick-0154` and landmine 28 before estimating this.
- **Highlights in exports.** Window-only by construction. Wanting them means
  making the overlay `draw_graph` bit-8 content and giving up the
  erasable-by-copy design — a different feature, not a flag.

### 4. Unrelated: the pre-existing red suites

While auditing this work I ran `tests/headless/full_audit.sh` and then re-ran
every failing suite against a **reverted baseline binary** to attribute them.
None is caused by `a5026c32`. These fail at baseline too and are a separate
backlog nobody has claimed:

| suite | baseline result |
|---|---|
| `test_lib_manager_gui` | 2 FAILED (GUI8/GUI9, tab-per-open) |
| `test_lib_sweep` | 5 FAILED (P1-P4, migration + netlist equivalence) |
| `test_reopen_readonly` | 1 FAILED (R10 `-lastopened`) |
| `test_select_at` | 5 FAILED (action log never opened) |
| `test_sky130a_libmgr` | 1 FAILED |
| `test_ciw` | 1 FAILED (needs `--logdir`) |
| `test_phase3_mints` | 2 FAILED (`g`/`G` snap logging) |
| `test_selflog_output` | FAIL |
| `test_wire_vertex_grab` | 2 FAILED at baseline, PASSED with the change — i.e. flaky |

Several of these (`test_select_at`, `test_ciw`, `test_selflog_output`,
`test_phase3_mints`) only make sense under `--logdir`; `full_audit.sh` already
knows that, so a standalone re-run needs the flag or it reports a false red.
The audit run itself also produced ~6 additional failures that PASS standalone
(`test_altf5_ciw`, `test_undo_selection`, `test_verb_noun_copy_move`,
`test_wave_modes` MG17, …) — those are display-contention artefacts of running
272 GUI suites back to back on WSLg, not defects.

## Discipline (unchanged)

- The user runs `src/xschem --script src/cadence_style_rc --logdir /tmp`; the
  surface that matters is the **ASE waveform window**.
- ⚠ **Never** `pkill -f 'src/xschem'` — that pattern matches the user's live
  session. Kill only PIDs you launched, after reading `pgrep -af xschem`.
- Anything under a real `$DISPLAY` goes through the GUI gate: use
  `tests/headless/run_suites.sh` or `gated_xschem.sh`, never a bare loop, and
  press `Allow 30m` / `Allow 2h` once instead of clicking Proceed repeatedly.
- **KNOWN-FLAKY, not yours**: `test_cadence_drag`, `test_wave_trace_menu` TG9,
  `test_ase_plot` P4/P6/P8, `test_hover_highlight`, `test_palette`, and (newly
  observed) `test_wave_markers` MF1 about 1 run in 3.
- **Sabotage before believing a green suite** (memory `green-but-hollow`). The
  eight sabotages for this feature are listed in the test file's header with
  their measured kill counts; re-run the ones that touch whatever you change.
  ⚠ Two of them were WRONG on the first attempt and left the suite green — a
  sabotage that does not actually break the property under test proves nothing.
- **Pixels are eyeball-only.** There is no ImageMagick on this box. The recipe
  that worked: a driver rc that builds the viewer and calls
  `exec xwd -id [winfo id $wp]`, plus the stdlib xwd→PNG converter left at
  `/tmp/.../scratchpad/xwd2png.py` (regenerate it if the scratch dir is gone —
  it is ~60 lines). Frames can then be diffed pixel-wise to prove an animation
  actually moved and that a neighbouring strip did not.
- Git: explicit file list, no `git add -A`, no `git reset --hard`, no
  `git push`. Commit message ends with:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
