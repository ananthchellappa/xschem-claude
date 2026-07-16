# Issue 0067 — raw Tk key/mouse binds bypass the action-registry logger

**Opened:** 2026-07-02
**Status:** RESOLVED 2026-07-02 — the deterministic/immediate-effect subcommands
now self-log at their C cores (unhilight_all, hilight/unhilight_net_interactive
noun-verb); +/- bus-index was already covered via the slice-5 setprop self-log;
the click-position / gesture-launch binds are deferred to 0005/0069 (see §5).
Tests: `test_selflog_output.tcl` §3k.
**Severity:** MED — these are bound keys the user presses expecting parity with
other shortcuts, but they run mutating/highlight commands directly, outside
`dispatch_input_action`, so nothing is logged.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/change_index.tcl:19–20`, `src/cadence_style_rc` (:103–105,
:233, :140, :166), `utils/apply_hilight.tcl:130–131`,
`utils/lib_mgr_helpers.tcl:9`, `utils/cadence_nav.tcl:354`.
**Related:** [[action-logging]], [[action-registry]], [[bus-transpose]],
[[cadence-bindkeys]]; 0068 (legacy C switch keys — sibling); umbrella 0071.

---

## 1. Symptom

Several keys/buttons are wired with raw `bind <widget> <key> {…}` in Tcl and call
`xschem <sub>` (or a Tcl proc that does) directly. Because they never reach the C
input-binding table / `dispatch_input_action`, the Layer A logger never fires and
the action is unrecorded — unlike registry-dispatched shortcuts.

## 2. Root cause

`dispatch_input_action` (`callback.c:3409`) logs only chords that arrive via
`xschem callback` and match the registered binding table. A raw `bind … {xschem
…; break}` in a Tcl rc runs the command itself and (with `break`) may even
suppress the dispatch path, so no log line is emitted. The invoked subcommands
(`setprop`, `hilight*`, `place_symbol`, …) also don't self-log.

## 3. Scope — mutating / highlight raw binds

- `+` / `-` → `change_index 1|-1` → `xschem setprop instance $i lab …` (bus index
  ±1) — `change_index.tcl:19–20`. **Schematic mutation, fully unlogged.**
- `9` / `8` / `0` → `xschem hilight_net_interactive` /
  `unhilight_net_interactive` / `unhilight_all` — `cadence_style_rc:103–105`.
- `F5` → `apply_hilight {…}`; transient `<ButtonRelease>`/`<KeyPress>` →
  `aphl::on_release`/`on_key` apply highlight to the clicked net —
  `cadence_style_rc:233`, `apply_hilight.tcl:130–131`.
- `Ctrl-Alt-N` → `place_libmgr_selection` → `xschem place_symbol $f`
  (`lib_mgr_helpers.tcl:9`) — launch unlogged (drop later logs a `#` stub, 0069).
- `Ctrl-Alt-D` → `cadence::deeploc_note` → places a text note
  (`cadence_nav.tcl:354`) — launch unlogged.

(Borderline, view-state only: Alt-minus prev-hilight-style cursor; Ctrl-2 /
Ctrl-Shift-2 make-editable/readonly toggles.)

## 4. Fix sketch

Migrate these chords into the action registry (`xschem bind key … <action_id>`)
so `dispatch_input_action` logs them — the same route `cadence_style_rc` already
uses for its wheel/`Ctrl-G` binds. For the `+`/`-` bus-index case, either register
a `change_index` action or have `setprop` self-log (guarded). The interactive
hilight click binds need a replayable command form (relates to 0005 stable
referents for click position).

---

## 5. Resolution — RESOLVED 2026-07-02 (branch `fluid-editing`)

**Chosen route: self-log at the C core**, not registry migration. This is the
same mechanism every other coverage slice converged on, and it covers a raw
`bind .drw <Key> {xschem <sub>}` for free (the sub self-logs regardless of the
entry path), without rewriting the Cadence rc. It also lands correctly for the
menu/mouse callers of the same subcommands. Split by what is faithfully
replayable:

1. **Deterministic → log the real command.**
   - `unhilight_all` (key `0`, mouse binding, menu Shift+K) → self-logs
     `xschem unhilight_all` at its `scheduler.c` core. The registered Shift+K
     action carries the same csv command, so its Layer A copy is deduped by
     `actionlog_cmd_logged`.

2. **Immediate-effect but selection-dependent → log the real command (accepted
   0005 delta).** This matches the established norm: the `K` key's registered
   `xschem hilight` already logs and replays against the replay-time selection.
   - `hilight_net_interactive` (key `9`) / `unhilight_net_interactive` (key `8`)
     → self-log `xschem hilight_net_interactive` / `xschem unhilight_net_interactive`
     **inside the noun-verb branch of `net_hilight_interactive()` only** (a
     net/element is selected, so it acts at once). The **verb-noun branch**
     (nothing selected → *enter* interactive click-mode) is a gesture START and
     stays silent — its per-click effects are click-position-dependent (0005/0069),
     matching the Phase-3 log-the-effect-not-the-start rule.

3. **Already covered — no code.**
   - `+` / `-` bus-index (`change_index.tcl`) mutates only via
     `xschem setprop instance $i lab …` (non-fast), which self-logs since slice 5.
     Verified: change_index iterates `xschem selected_set` (instance *names*), so
     the logged line addresses the instance by name, e.g.
     `xschem setprop instance p1 lab {foo[4]}`.

**Deferred (documented, not oversight) — need stable click/selection referents
(0005) or gesture-end hooks (0069):**
- **F5** `apply_hilight {…}` and the transient `<ButtonRelease>` / `<KeyPress>`
  binds (`aphl::on_release`/`on_key`) apply a highlight *style to the clicked
  net* — click-position-dependent (0005), and they live in the separate
  `utils/apply_hilight.tcl` machinery. **CLOSED 2026-07-15 (issue 0071 atom 15):**
  both apply arms now log `net_hilight_apply {resolved-row}` at the entry sites; the
  CLICK arm's selection is already covered by the atom-1 `select_at` self-log (single
  click) and the IMMEDIATE arm is the F5 raw bind's sole record (typed path dedups via
  ciw_exec `-emitted`). Accepted 0005 residuals: rubber-band drag-select-several, the
  ambient-table-dependent applied index. Test `test_apply_hilight_log.tcl`; report §18.
- **Ctrl-Alt-N** `place_libmgr_selection` → `xschem place_symbol` launches a
  place gesture; the drop already logs a `#` stub (0069).
- **Ctrl-Alt-D** `cadence::deeploc_note` places a text note at a chosen point
  (text-placement gesture, 0069).
- Borderline view-state only (explicitly out): Alt-minus prev-hilight-style
  cursor; Ctrl-2 / Ctrl-Shift-2 make-editable/readonly toggles.

**Tests:** `tests/headless/test_selflog_output.tcl` §3k (5 checks, 82 total) —
unhilight_all logs; hilight/unhilight_net_interactive noun-verb log; the
no-selection interactive-mode call logs nothing (gating); change_index routes
through the logged name-addressed setprop. Verified the gate directly: two
`hilight_net_interactive` calls (noun-verb + enter-mode) yield exactly one log
line. Golden regression clean.
