# Issue 0065 — net-hilight-style editor commit is not logged

**Opened:** 2026-07-02
**Status:** FIXED 2026-07-14 (issue 0071 atom 8) — the editor's live-commit points
self-log replayable lines (see §4); locked by `test_selflog_grep_guard` S1 rows;
tested by `tests/headless/test_nhse_mutation_log.tcl`. One documented residual:
the `apply_hilight` CLICK-to-apply arm (see §4 end).
**Severity:** LOW — changes highlight *style* (color/width/dash/blink/march), not
schematic content; still a user config action absent from the log / CIW.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/xschem.tcl` `nhse_ok`/`nhse_apply`/`nhse_flush`/`nhse_commit`
(:1408/:1405/:803), `xschem update_net_hilight_style` (`scheduler.c:8915`).
**Related:** [[action-logging]], [[net-hilight-styles]]; issues 0044/0050/0059
(other net-hilight-style bugs); umbrella 0071.

---

## 1. Symptom

Applying or OK-ing the Net Highlight Style editor changes the active highlight
style (and, on Save, writes a config file) but logs nothing to the action file or
CIW — only a `ciw_echo` status line appears on Save. Re-typing the equivalent
command is not possible from the record.

## 2. Root cause

The whole chain is silent: `nhse_ok`/`nhse_apply` → `nhse_flush` → `nhse_commit`
(`xschem.tcl:803`) updates the Tcl `net_hilight_style` var and calls
`xschem update_net_hilight_style`, whose C body (`scheduler.c:8915`) has no
`log_action`. Neither the Tcl nor the C side reaches the log bridge.

## 3. Fix sketch

Have the editor's Apply/OK emit a replayable `xschem update_net_hilight_style
<args>` (or a dedicated style-set subcommand) through `xschem log_action`, or add
a guarded `log_action` in the C `update_net_hilight_style` branch. Keep the
existing `ciw_echo` status line; add the replayable command line alongside it.

## 4. Resolution (2026-07-14, issue 0071 atom 8)

NOT the C branch (it is a shared mechanism — startup conf source, every scripting
helper, the editor — logging there floods and a bare line is not self-contained).
The editor's **live-commit points** log instead:

- **`nhse_apply_live`** (the single staged→live point: Apply / OK / Cancel-revert)
  logs the SELF-CONTAINED table line `net_hilight_style_set_live {<full table>}`.
  `set_live` is a new scripting helper that replays the value **verbatim** — a
  normalizing form (`net_hilight_style_replace`) would coerce sloppy hand-set
  fields differently than the C parser did in-session (review-confirmed: width
  `2.5` → C `2` vs norm `1`) and diverge.
- **`nhse_reset`** commits live outside that seam → logs bare
  `net_hilight_style_reset` at the button proc.
- **`nhse_save`** (success arm only) logs the STAGED table
  (`set ::net_hilight_style {…}` — Save writes the staged var, which is otherwise
  unlogged unless Apply preceded; review-confirmed divergence) then the resolved
  `write_net_hilight_style_conf {path}`. Dialog-Cancel and write-fail arms silent.
- **Delete-last-row** (review find): emptying the table makes `nhse_rebuild`'s
  `net_hilight_style_current` re-materialize the layer default LIVE, outside the
  seam — `nhse_op_delete` logs the materialized table, gated on the
  materialization actually happening (window-less call leaves no line and no live
  change). Non-last deletes stay staged and silent.

Machinery stays silent (startup conf source; scripting helpers; `set_live` itself
— typed calls are channel-recorded). Locked by 4 `test_selflog_grep_guard` S1 rows
(line-anchored, `\M`-bounded) + `update_net_hilight_style` in the S3
no-scheduler-log list. Test: `tests/headless/test_nhse_mutation_log.tcl`
(30 checks, full_audit logdir_tests; raw-fidelity, staged-Save divergence,
delete-last, `--nogui` child replay, no-Tk self-skip).

**Documented residual (out of scope, 0067 §5 class):** the `apply_hilight`
CLICK-to-apply arm (`utils/apply_hilight.tcl`, cadence-rc mouse binding) appends a
style row via `net_hilight_apply` from a raw Tk ButtonRelease — a click-position
gesture (0005/0069 class); its noun-verb form (select first, then type
`apply_hilight …`) IS recorded by the typing channel. Closing the click arm needs
gesture logging, not editor logging.
