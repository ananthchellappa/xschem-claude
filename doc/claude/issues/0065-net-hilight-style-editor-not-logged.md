# Issue 0065 — net-hilight-style editor commit is not logged

**Opened:** 2026-07-02
**Status:** OPEN — identified by the action-log coverage audit; not yet fixed.
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
