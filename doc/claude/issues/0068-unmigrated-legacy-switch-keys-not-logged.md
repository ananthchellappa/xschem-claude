# Issue 0068 — un-migrated keyboard shortcuts (legacy C `switch`) are not logged

**Opened:** 2026-07-02
**Status:** OPEN — narrowed to 5 rows by the 2026-07-19 definitive inventory (below):
3 unlogged schematic-state mutations + 2 unlogged semantic-config toggles; 0
readonly-ungated arms. Everything else in the legacy switch is funnel-logged,
key-site-logged, boundary-routed, non-mutating, or migrated.
**Partially fixed 2026-07-02:** the legacy clipboard/edit keys that
resolve to `cut`/`delete`/`undo`/`redo` now record because those cores self-log
(issue 0071 §4b), independent of key migration.
**2026-07-18 (Refactor B atom 26, audit §46):** the `#`/Ctrl+# duplicate-refdes
keys — exactly this class (`actions.csv:100/101` accels with no `keybindings.csv`
row → the legacy `case '#'` was the only handler, unlogged AND ungated) — now
route/log via the atom-26 migration: Ctrl+# through `perform_action`
("check_unique_names", av[2]="1" — gains the readonly gate that closed a silent
read-only RENAME + the one `xschem check_unique_names 1` log), `#` stays raw with
its own `xschem check_unique_names 0` log. A PARTIAL close of the class.
**Severity:** MED→LOW after the inventory — the surviving unlogged mutations are
logic-level annotation, hilight-driven label generation, window clear, and two
netlist-mode toggles; all common clipboard/orient/property/placement edits DO log.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/callback.c` legacy `handle_key_press` switch (:4903-:6529 as of
9febeaa6). `src/actions.csv` rows whose `accel` is absent from
`src/keybindings.csv`.
**Related:** [[action-logging]], [[action-registry]]; 0067 (raw Tcl binds —
sibling); spec Phase 3 "resume key migration"; umbrella 0071; Refactor B batch
receipts 01-30.

---

## 1. Symptom

Keys that have an `actions.csv` row but were never migrated into
`keybindings.csv` fall through to the legacy `switch(key)` in `handle_key_press`.
That path edits directly; unless the case arm, its callee core, or the gesture-drop
funnel logs, the shortcut leaves no action-log / CIW line — even though the same
command from a migrated key would be logged.

## 2. Root cause

Only chords present in the C binding table (mirrored by `keybindings.csv`) reach
`dispatch_input_action` and get logged by the dispatch layer. Un-migrated chords hit
the legacy switch. Since this issue was opened, most of that surface gained coverage
anyway — core self-logs (0071/0062/0063), the gesture-drop funnel (0069), and the
Refactor B `perform_action` boundary (atoms 1-29) — which is why §3's original list
went stale.

## 3. Scope — 2026-07-19 definitive inventory (batch item 8)

The original §3 list (written 2026-07-02) was BADLY STALE — clipboard, orient-in-place,
property, net-label-placement, and symbol/tool keys have all since gained logging
(funnel, key-site, or boundary). It is replaced by a full sweep of every case arm and
every `state`/`rstate` branch of the legacy switch (:4903-:6529, 82 labels), classified
5 ways, with per-row evidence:

**Full table:** `doc/claude/code_analysis/legacy_switch_key_inventory_0068.md`
(130 rows + migrated-comment list + csv cross-ref + completeness check).

### 3a. Class (iv) — genuinely unlogged mutations (N = 5)

Schematic-state (3):

1. **`0`..`4` (plain) → `logic_set()`** (callback.c:4904-4913; hilight.c:2309) —
   sets/toggles net logic-level annotation (bus-hilight hash + propagate; drives
   redraw and gaw sync). `readonly_block()` at :4911. No `log_action` anywhere in
   hilight.c; the scheduler twin `xschem logic_set_net` (scheduler.c:6412) is silent
   too. Recommendation: self-log inside `logic_set` (one site covers key + verb).
2. **`Alt+Shift+J` → `print_hilight_net(2)`** (callback.c:5313-5318; hilight.c:4060)
   — creates i-prefixed net labels from highlighted nets. `readonly_block()` at
   :5316. Partial-funnel: the routed inner `xschem merge` DROP logs, the initiating
   verb line does not (receipt 21 has the anatomy). Blocked on the interp-visible
   suppress-scope pattern (Refactor B defer note).
3. **`Ctrl+Shift+N` → `tcleval("xschem clear symbol")`** (callback.c:5560-5564) —
   empties the window to a blank symbol. `readonly_block()` at :5562. The scheduler
   `clear` branch (scheduler.c:2481-2492 → `clear_schematic()`) has NO log for ANY
   caller — key or File menu. **NEW find of this sweep.** Recommendation: branch
   self-log at the scheduler `clear` branch (covers the menu too).

Semantic-config (2) — change netlist OUTPUT semantics, not the drawing; not
readonly-relevant; candidates `stay-raw-document`:

4. **`Ctrl+Shift+V`** netlist_type cycle (callback.c:6005-6010).
5. **`:`** flat_netlist toggle (callback.c:6456-6465).

### 3b. Class (v) — readonly-ungated mutations (M = 0)

None survive. Every sch-mutating arm has `readonly_block()` in the arm or a gate in
the callee/boundary (`scheduler_readonly_reject` via `perform_action`, editprop
viewer-on-readonly, funnel gestures gated at START). The last known (v) — Ctrl+`#`
silent read-only rename — was closed by Refactor B atom 26. The two cfg toggles
above are not (v): they never write the read-only file. No new issue files needed.

### 3c. Notable non-gaps established by the sweep (so nobody re-opens them)

- **Reopen shortcuts log:** Ctrl+O / Ctrl+T route `xschem load -gui -lastopened/
  -lastclosed` → scheduler.c:6128 (or `load_new_window` :6256) logs the resolved
  file. Dialog opens log via `ask_new_file` (actions.c:728/:740).
- **Layer keys log their mutating case:** Ctrl+0..9 route `xschem set rectcolor N`;
  bare cursor pick is deliberately nolog (issue 0066), a selection recolor logs +
  readonly-rejects (scheduler.c:10103-10119).
- **All gesture keys** (c/C/m/M/t/r/w/W/s-cadence/l/I/Insert/b/Ctrl+V paste,
  mid-gesture Alt/Shift transforms, Return polygon-close) funnel-log at drop
  (`end_move_copy_logged` callback.c:1604 / `log_placed_instance` :1572 / actions.c
  new_* drop logs :4313-:4700).
- **Exactly one dormant-shadowed arm:** case `l` plain start-line (shadowed by
  `key,108,0,canvas,edit.add_wire_label`); Space's case is a designed
  decline-fallback, not dormant.
- **Family chords (Alt-or-Super)** stay in C by design — the exact-chord binding
  table cannot express them (callback.c:4044-4048, :5302-5307).

NOT in scope (already captured): gesture-completing inserts (W/L/R/… → `xschem
wire/line/rect/arc …` self-log at drop in `actions.c`) and keyboard move/copy
drops (callback.c:1604) log via the gesture path regardless of migration.

## 4. Fix sketch (updated)

For the 3 schematic-state rows: per-row recommendations in §3a (core self-log for
`logic_set`; suppress-scope-blocked for `print_hilight_net(2)`; scheduler-branch
self-log for `clear`). For the 2 cfg toggles: document, don't log (pure-mode sets
follow the issue-0066 nolog convention unless replay divergence is shown). The old
"migrate everything into keybindings.csv" sketch remains the long-term direction but
is no longer needed for log coverage — the boundary/funnel/core-self-log layers
carry it.
