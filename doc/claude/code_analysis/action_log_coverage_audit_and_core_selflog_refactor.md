# Action-log coverage — 2026-07-14 re-audit + a refactor path to close the class

**Scope:** a code-verified re-audit (at `fluid-editing` HEAD, read from source, not from
commit messages) of how far the *"every user action is logged as a replayable command"*
goal has actually been reached, followed by an analysis of **why complete coverage keeps
slipping** and **what C-side refactoring would make it stop slipping.**

**Companion docs:** `doc/claude/specs/action_logging.md` (spec §2 = the intent),
`doc/claude/specs/action_logging_checklist.md` (status table — now partly stale, see §4),
`doc/claude/issues/0071-action-log-coverage-audit-index.md` (the 2026-07-02 audit + the
"self-log at core" decision), `doc/claude/code_analysis/action_log_ciw_coverage_and_virtuoso_parity.md`
(D1–D4 design). Memory: `[[action-logging]]`.

---

## 1. The goal and the two design eras

Spec §2: *"Every user action is logged,"* each line an executable `xschem …` command that
replays the effect; effects with no faithful Tcl form degrade to a `#` comment marker
(source-able, skipped on replay).

The implementation has passed through two design eras:

1. **Edge-wrapping (Phases 1–3, June 2026).** Logging installed at four **GUI edges**:
   the File menu (`menu_action_logged`), the bound-key dispatcher
   (`dispatch_input_action`, Layer A), the drag-gesture ENDs (Layer C), and the right-click
   context menu (`context_menu_action`, Layer B). Anything reaching an effect by a *fifth*
   path recorded nothing.

2. **Self-log-at-core (issue 0071 §2, from 2026-07-02).** The audit found the edge approach
   structurally leaky: the mutating C subcommands were almost all silent, so coverage meant
   wrapping *every* entry point. The decision (D2) was to make the mutating cores **self-log
   in their own C body**, guarded against replay double-logging. A sweep of slices followed
   (`fe5e7620` → `98885d4d`, `7df1395d`, `fb0b4975`, `0af399f5`, `3dd20c87`, `d4310f11`,
   `5d4b7e7f`, `093c0351`, `725e4575`, plus `cfe5c3f8` `select_at` for click-select).

That sweep is **roughly 70% landed.** The remaining holes are not random — they are all the
same structural shape, described in §3.

---

## 2. Verified coverage at HEAD (14 areas)

Status legend: **CLOSED** = logged as a replayable command from every real user path;
**PARTIAL** = logged from some paths, or only as a non-replayable `#` marker; **OPEN** =
nothing logged, not even a marker.

### CLOSED — replayable from every path
| Area | Evidence | Note |
|---|---|---|
| Single-LMB click-select | core `select_object()` self-logs → `xschem select_at x y [add]` (`callback.c:294`, stash `scheduler.c:8199`) | Only the final click before process exit is not flushed. **Checklist row 17 still says "no" — stale.** |
| Transform / surgery keys (flip, rotate, align, trim, break) — 0068 | inline switch self-logs (`callback.c:4968/5478/5620/6131`); menu/toolbar/ctx/script reach the same verbs via the scheduler; paths disjoint → one line each | during-move rot/flip logged at move END (0069) |
| `xschem set` — change_layer, elem_order, snap, header — 0066 | edit-shaped sets self-log the *resolved* value (`scheduler.c:8653`, `d4310f11`) | pure config/display sets deferred by documented policy; script-only `instance_number` unlogged (no GUI reaches it) |

### PARTIAL — some paths, or marker-only
| Area | Gap | Evidence |
|---|---|---|
| Non-File menu mutators — 0061 | self-log sits in the scheduler **wrappers, not the cores**, so each keyboard gesture was patched by hand and **two were missed: Ctrl-X (cut) and the Delete key call `delete()` directly and log nothing.** Interactive setprop = marker. | silent: `callback.c:5785` (cut), `callback.c:5953` (delete) |
| Toolbar + recent-component bar — 0062 | buttons inherit the core's logging, so most now mint real commands — but **File Save, File Reload, Edit Copy are completely silent**; Netlist / toggle-colors / descend_symbol / go_back silent; Paste = marker | silent: `scheduler.c:7845` (save), `:7526` (reload), `:1247` (copy) |
| Property-edit dialogs — 0063 | the silent-commit gap is closed (core `edit_property()` self-logs, `093c0351`), but for wire/rect/line/arc/poly/text + global attrs the line is only a non-replayable `# property-edit` marker; only the instance slick form emits replayable `apply_properties`; cancel logs nothing | marker `editprop.c:1321`; replayable `property_form.tcl:594` |
| Raw Tk hilight binds (0/9/8) — 0067 | immediate-effect hilight/unhilight self-log; but 9/8 with nothing selected enter an interactive click-mode whose per-click highlights are deferred (0005/0069) | `5d4b7e7f` |
| Gesture drops — 0069 | place-symbol/text/plain-move mint real commands; paste-merge + sympin drops stay `#` markers; rot-flip-during-move deferred | `callback.c:1591/1594` (markers), `:1611/1630` (replayable) |
| Command output → CIW + file — 0070 | the `#=`/`#!` output sink works but is fed only by typed-CIW commands and menu picks; key/context results and the netlist/ERC/check/print-hilight report sinks are unrouted | `fe5e7620` |
| Descend / return / navigation | descend-to-schematic is a closed replayable core self-log `xschem descend -inst` (`actions.c:3591`, `8f7e621b`), but **go_back (Ctrl-E) and descend_symbol (`i`) self-log from no core** — logged only via the right-click menu, silent on the keyboard | |

### OPEN — nothing logged
| Area | Evidence |
|---|---|
| **Double-click connected-select** (this session's trigger) | core `select_grow_connected_step()` `select.c:263` silent; `handle_double_click()` `callback.c:6943` calls it directly; the self-logging wrapper `xschem select_grow_connected` `scheduler.c:8246` is bypassed; escalation-reset `callback.c:6671` unlogged |
| Library Manager mutations (git/create/rename/delete/copy) — 0064 | `library_defs.tcl` (`:407/481/536/579`) and `library_git.tcl` (`:211/276`) mutate directly with zero `log_action`; not even a marker |
| Net-hilight-style editor commit — 0065 | Apply/OK → `update_net_hilight_style` writes nothing from any layer (LOW) |
| stdin REPL + TCP command server — 0003 | both channels `eval` into the same interpreter with no `log_action`; a session driven through them yields a header-only log |

---

## 3. What makes complete coverage genuinely hard

Every OPEN/PARTIAL row above is the same failure, plus two data-model constraints. Naming
them precisely is what makes the refactoring obvious.

### 3.1 The core problem: no single choke point, and the log lives one layer too high

A given *effect* — "delete the selection", "grow the connected set", "flip" — is reachable
from **four or more disjoint code paths**, each of which calls the **same shared C core
function** directly:

```
menu item  ─┐
toolbar    ─┤
context    ─┼─► xschem <verb> ──► scheduler.c branch ──►┐
script     ─┘                                            ├──► core C fn (delete(),
key press  ──► callback.c legacy switch ────────────────┤     select_grow_connected_step(),
gesture END ─► callback.c funnel ───────────────────────┘     move_objects(), …)
Tcl dialog ──► apply_* / library_* proc ────────────────────► (its own mutation)
```

The self-log was installed on the **scheduler branch** (the `xschem <verb>` layer), not on
the core function. So the *only* paths that log are the ones that go through the Tcl
dispatcher. **Keys and gestures that call the core C function directly skip it.** That is
exactly the double-click bug (`handle_double_click` → `select_grow_connected_step`, never
the `select_grow_connected` branch), and exactly Ctrl-X / Delete (`callback.c` → `delete()`
directly), and go_back / descend_symbol on the keyboard.

The recurring symptom — "we logged verb X, but only from the menu, not the key" — is not a
sequence of independent oversights. It is one architectural fact: **the logged unit is the
command string, but the shared unit is the C function, and they are not the same layer.**
The audit found this missed three more times (Ctrl-X, Delete, go_back) *after* 0071
explicitly identified it, which is the tell that a human "remember to also log the keyboard
path" discipline does not hold.

### 3.2 The replay re-entrancy hazard forces a guard

If you log at the core, then *replaying* a logged command re-enters the core and re-logs it.
Worse, some effects are composites: `align` calls `trim_wires`; a gesture-END logs one
`move_objects` line but internally touches several cores; the coordinate-form subcommands
(`wire x1 y1 x2 y2`) ARE the replay form and must not re-log. So core logging is only safe
with a **suppress flag** that is set during (a) log replay, (b) any internal call where the
effect is a sub-step of an already-logged operation. The plumbing exists
(`actionlog_suppress`, `actionlog_cmd_logged` dedup) but `actionlog_suppress` is "not yet
wired to a Tcl setter", and the dedup is applied per-recorder by hand. Every new core has to
opt into the guard correctly or it double-logs on replay.

### 3.3 Two effects have no replayable form yet (a data-model constraint, not plumbing)

- **Selection targets live objects** (array indices / pointers), not stable names. A faithful
  `select_at` / `select_grow_connected` needs to address the seed by something that survives a
  reload. This was issue 0005's blocker.
- **Whole-string property edits of a multi-object selection** have no token-level subcommand
  (`setprop` is per-token; line/arc/poly have no `setprop` case at all), so 0063 can only emit
  a `#` marker.

Note: the **stable-handle layer now exists** (session-stable ids on all 7 object types + nets,
`xschem object(s)` API — see `[[stable-object-handles]]`). That substantially lifts the 0005
blocker for *selection* logging: the seed of a connected-select can now be addressed by id.
This constraint is therefore *shrinking*, and the double-click case is now closable with a
replayable command, not just a marker.

### 3.4 Some mutations never touch C, and some never touch the GUI

- **Tcl-only mutations** (Library Manager git/create/rename/delete/copy `0064`, NHSE editor
  `0065`) have **no C core to self-log in** — the mutation happens entirely in Tcl procs.
- **stdin REPL and TCP** (`0003`) feed the interpreter directly and never pass any GUI edge.

These two classes cannot be fixed by the C-core refactor alone; they need their own logging
hooks (§4, Refactor A steps 4–5).

---

## 4. The refactor: collapse the entry paths onto one logging boundary

The fix is not "log harder at more edges" — that is the treadmill that produced the current
partial state. It is to **make the shared core the single logging site** and, ideally, to make
the entry paths route through one boundary so the site cannot be bypassed.

### Refactor A — log at the core, everywhere (incremental, low-risk, do this now)

This is the already-blessed D2 pattern, applied to completion. For each mutating/selecting
core function:

1. **Move the `log_action(...)` call out of the scheduler branch and into the core C
   function** — *when that core is 1:1 with the user verb* — formatting the canonical
   `xschem <verb> <args>` from the core's *own* parameters (not the caller's argv). Because
   menu/toolbar/context/script/key/gesture all funnel through the core, one site covers them
   all. This is precisely what slice-6 did for `make_symbol` (moved branch → `save.c` core) and
   reported as "strictly better", and what the `select_grow_connected` atom (`e3764a07`) did —
   it closed the double-click gesture, whose only bypass path was the direct core call.

   **The 1:1 test matters — verified the hard way on `delete()` (atom 2).** `delete()` is *not*
   a clean core: it is a shared primitive called by ~three abort/merge/preview-teardown paths
   (`abort_operation` tears down a placement or merge with `delete(1)`) and by the two cut paths,
   in addition to the real user delete. Logging inside it would spuriously emit `xschem delete`
   on an ESC-abort and mislabel a cut as a delete — the composite-operation hazard of §3.2. And
   unlike the double-click, `delete` has **no hidden bypass**: its user verbs already live at the
   scheduler `delete`/`cut` branches (which self-log) plus two inline legacy-switch keys
   (`XK_Delete`, `Ctrl-X`) that were the *entire* gap. So the correct fix logged those two keys at
   the handler (the 0068 keyboard pattern), leaving `delete()` silent — zero suppression, no risk
   to the abort paths. **Rule of thumb: log at the core when the core *is* the verb; log at the
   verb's entry sites when the core is a shared mechanism the verb is only one caller of.** Apply
   the 1:1 test to each candidate (`go_back`, `descend_symbol` next) before choosing the site.
2. **Wire the suppress guard properly.** Give `actionlog_suppress` a real setter, set it
   around the replay driver and inside composite operations, and have every core log through a
   single helper (`core_log_action(verb, argv…)`) that early-returns when suppressed. This
   replaces the per-recorder hand-dedup with one gate.
3. **Address objects by stable id** where the effect targets a selection (now possible via the
   stable-handle API), so selection/connected-select emit replayable commands instead of `#`
   markers.
4. **Add a Tcl-side `log_mutation {cmd}`** helper that honors the same suppress flag, and call
   it from the Tcl-only mutators (`library_defs.tcl`, `library_git.tcl`, NHSE editor) — or,
   better, route those ops through new `xschem` subcommands that self-log in C.
5. **Log at the interp-eval boundary** of the stdin REPL and TCP handler (one line each, the
   way `ciw_exec` already does), closing `0003`.

The immediate high-value slice is step 1 on four cores —
`select_grow_connected_step`, `delete`, `go_back`, `descend_symbol` — which closes the
double-click gap **and** Ctrl-X, the Delete key, and Ctrl-E return in a single consistent
pass, with no new per-call-site code.

### Refactor B — a single mutation/command boundary (structural end-state, optional)

The deeper cure removes the *possibility* of the bug: funnel every mutating operation through
one dispatcher, e.g.

```c
int perform_action(const char *verb, int argc, const char *const *argv) {
    if (readonly_reject(verb)) return TCL_ERROR;   /* one readonly gate */
    int rc = run_core(verb, argc, argv);           /* the effect */
    if (!actionlog_suppress) core_log_action(verb, argc, argv);  /* one log site */
    return rc;
}
```

Every entry point — key handler, menu, gesture END, scheduler branch, Tcl dialog — calls
`perform_action` instead of the raw core. That collapses the four-edge problem to **one
edge**, and it simultaneously fixes a sibling problem: the scattered read-only guards. The
0041/0051 series (menu path mutates a read-only cell because *that specific path* lacked a
`readonly_reject`) has the **same root cause** — no single choke point — and the same cure. A
`perform_action` boundary makes "did we log it?" and "did we readonly-check it?" structural
invariants instead of per-path checklist items.

Refactor B is a larger change and does not need to be done at once: adopt `core_log_action` +
the suppress gate from Refactor A first, then migrate entry points onto `perform_action`
verb-by-verb. A is the pragmatic path to closing today's gaps; B is the north star that keeps
them closed.

### Is the C refactor strictly necessary?

For the concrete open gaps: **no — Refactor A alone closes them**, and it is low-risk (the
mutator slices already proved the pattern and were sabotage-tested). Refactor B is what you
would design if starting over; its value is preventing the *class* from recurring and unifying
read-only enforcement, not fixing any single gap. Recommendation: **ship Refactor A now,
treat Refactor B as the direction of travel.**

---

## 5. Documentation drift found by this audit

The status records have fallen behind the code and should be re-verified against source before
the next slice:

- `action_logging_checklist.md` **row 17** (click-select marker) still reads "no", but
  single-click select is now logged as a replayable `xschem select_at`.
- Issue headers **0061 / 0063 / 0068** still read OPEN, but verified subsets are closed.
- The audit surfaced gaps **not listed anywhere** in the checklist: Ctrl-X (cut), the Delete
  key, and File Save are silent. These deserve their own rows (or fold into a refreshed 0061 /
  0062).

A live dashboard of this audit (same data, visual matrix) is published at
`https://claude.ai/code/artifact/78f92646-b60b-4350-8180-0e3d51ffcb90`.

---

## 6. Atom 3 outcome (2026-07-14): go_back + descend_symbol — and a second wrinkle in the rule

Both cores passed the 1:1 test and now self-log (closing the "Descend / return / navigation"
PARTIAL row of §2): `go_back()` (actions.c) → `xschem go_back` / `xschem go_back <what>` when
`what != 1`; `descend_symbol()` (save.c) → `xschem descend_symbol -inst <name>` (scheduler
grew a matching `-inst` arm mirroring `descend -inst`; `log_action_descend` generalized with
a verb argument). Verified: 36-check test (`test_descend_goback_selflog.tcl`), sabotage ×3,
full-audit baseline diff clean.

**Anchor corrections found in source (the audit's landmine was inverted):**
- The window-close walk-up does NOT call `go_back()` directly from C — it is Tcl
  (`hierarchy_close`, xschem.tcl) issuing `xschem go_back 1` through the scheduler branch. So
  there is no "shared-core" caller to protect; go_back is 1:1 at the C level.
- Those Tcl walk-ups (`hierarchy_close`, `descend_hierarchy`, `probe_net`, `hier_traversal`)
  **must** log: their descends already log via `descend_schematic`'s core self-log, so a
  silent ascend would leave the replayed hierarchy level drifted. Logging go_back at the core
  *fixes* a latent replay-parity hole rather than adding noise.
- `XK_BackSpace` (callback.c) is a second direct-C-caller of `go_back(1)` no audit had
  listed; core-log covered it for free.

**The new wrinkle — the self-contained-line rule.** The first cut logged bare
`xschem descend_symbol`, and adversarial review confirmed a real regression: `log_action()`
sets `actionlog_cmd_logged`, so a composite wrapper that used to be the replayable record
(CIW-typed `hi_descend inst=x1 view=symbol` — its internal `xschem select instance … fast` is
unlogged) now *suppresses its own line* in favor of the core's, and a bare selection-dependent
line silently no-ops on replay → hierarchy diverges. Rule addition to §4 step 1:

> **When a core's replay depends on ambient state (the selection), the core must log a
> SELF-CONTAINED form** (here `-inst <name>`, resolved and re-selected at replay), because
> core-log dedup deliberately suppresses wrapper lines — including composite wrappers whose
> line was previously the only faithful record. Precedent: `log_action_descend`'s
> `descend -inst` absorb.

**Review findings documented, not coded (all pre-existing in kind):**
- *Cadence Ctrl-E window-hop is still silent* — `cadence_style_rc` binds Ctrl-E to
  `cadence::return_one_level`; at the descend-child's entry level the return is a
  parent-window hop (`cadence::focus_window` → `xschem new_schematic switch`) that logs
  nothing. 0053-class multi-window replay gap; candidate follow-up: log the switch inside
  `focus_window`.
- *Traversal-dialog volume* — `hier_traversal` all-hierarchy mode now writes a faithful
  `descend -inst` / `go_back 2` pair per subcircuit per refresh (empirically 28 lines on
  greycnt.sch). Faithful, replayable, by design (see walk-up parity above); if the noise ever
  matters the remedy is an `actionlog_suppress` setter around the walk (the flag exists but
  has no setter today).
- *Bare `go_back` replay can re-prompt* — go_back(1) on a modified level raises Save/No/Cancel
  before the log point and the answer is not recorded; a replay-time Cancel desynchronizes the
  remaining lines. Pre-existing in kind for the ctx-menu/menu Pop line; accepted delta
  (same class as the undo-granularity deltas of Layer C).

---

## 7. Atom 4 outcome (2026-07-14): save + reload + copy — all three FAIL the 1:1 test

The 0062 remainder (File Save / Reload / Edit Copy silent from toolbar & co.) closed. None
of the three has a loggable 1:1 core — `save()` (actions.c) is a shared confirm-wrapper
(entered from go_back, descend-embedded, `load` window-routing prompts, quit/close flows),
and copy/reload's effects (`save_selection(2)`, `load_schematic(...)`) are bare primitives
with inline-key twin callers. So per the atom-2 rule all logs went to the **verbs' entry
sites** — scheduler branch + inline legacy-switch keys:

- **copy** — branch logs `xschem copy` (mirrors cut, slice 1; empty-selection no-op still
  logs, slice-1 norm — clipboard-only, a replayed line is always safe). Ctrl-C
  (`case 'c'` ControlMask) calls `save_selection(2)` directly → logs at the key handler,
  under the selection guard (no phantom). Ctx-menu pick 15 keeps its `ctxmenu_log_cmd`
  table line (its direct-C path never reaches the branch; paths disjoint → one line each).
  `schpins_to_sympins` (Tcl) evals `xschem copy` as machinery → one extra faithful,
  replay-safe line; accepted.
- **save** — logged at the branch's NAMED-file arm only, after `save(0,fast)`. The
  unnamed→`saveas(NULL,SCHEMATIC)` arm stays silent: `saveas()` already logs the resolved
  `xschem saveas {f} schematic` at dialog resolution, and a bare `xschem save` line would
  re-open the dialog on replay. Ctrl-S (`case 's'` ControlMask) saves inline → logs at the
  key handler, gated `!xctx->readonly` (mirrors the branch's read-only reject, which sits
  before its log). **Policy decisions (in the branch comment):** an unmodified no-op save
  still logs (slice-1 norm — and `save()` force-writes when the on-disk mtime changed, so
  a modified-gate would drop real writes); `save fast` stays **silent** — `fast` is passed
  only by internal cellview/attr machinery that saves a temporarily-loaded file between
  unlogged `load -keep_symbols` calls, so a logged line would replay against the wrong
  file (same machinery axis as the setprop `-fast` gate, slice 5).
- **reload** — branch logs `xschem reload` / `xschem reload zoom_full` (arg form
  preserved). `action_reload`'s Tcl-side log line (from the File-menu slice, 105718e1)
  was **removed**: it is not dedup-wired, so branch-log + it double-logged the confirmed
  pick (sabotage-verified: re-adding it makes the count +2). All confirm dialogs live in
  the callers (action_reload `alert_`, toolbar FileReload arm, inline Alt-S
  `tk_messageBox`), so a Cancel never reaches any log site. Alt-S (`case 's'`
  EQUAL_MODMASK) reloads inline via direct `load_schematic()` → logs inside its ok-arm.

**Self-contained-line check (the §6 rule):** all three wrappers' previously-logged lines —
menu verbatim `xschem save`, action_reload's `xschem reload`, ctx-table `xschem copy` —
are *identical* to the new branch/key lines. No wrapper carried extra state, so dedup
suppression loses no replay fidelity; the rule gained no new wrinkle here.

**Deliberately still silent (documented, pre-existing in kind):**
- Incidental confirm-saves inside composite verbs (go_back / descend-embedded /
  `load` window-routing / close prompts answered "yes") — logging inside `save()` is
  exactly the delete()-class mistake; the composite verb's own line re-raises the prompt
  on replay (same accepted class as atom 3's bare go_back).
- The tab-context-menu Save arm routes through the branch and now logs, but its
  surrounding `new_schematic switch` calls are unlogged (0053-class multi-window gap) —
  the line may replay against a different current tab; harmless (unmodified no-op or an
  extra save).
- mouse `button-8` bind (`xschem set_modify 1; xschem save`) now logs the save; the
  set_modify hack is not replayed → replay no-ops. Accepted.
- Two Tcl machinery evals of the plain verb now log a faithful stray line each:
  `reroute_inst` hier processing (`xschem save`, xschem.tcl:3837 — saves the *current*
  file, so a replayed line is a harmless consistent write) and `schpins_to_sympins`
  (`xschem copy`, clipboard-only). Same accepted class as atom 3's traversal-walk lines.
  The temp-file-swapping cellview machinery stays silent via the `fast` gate.

Verified: 36-check `test_save_reload_copy_selflog.tcl` (full_audit logdir_tests; counting
alert_/tk_messageBox/ask_save stubs per the atom-3 finding), sabotage 2 rounds × 7 sites
(each neutralization fails exactly its own checks; the save-gate *flip* catches both the
missing log and a fast-machinery leak in one shot), `test_selflog_output` transform-key
failures confirmed pre-existing on baseline (WSLg env).

---

## 8. Atom 5 outcome (2026-07-14): the grep guard — discipline made structural

The C-mutator self-log migration (atoms 1–4) is complete; atom 5 locks it.
`tests/headless/test_selflog_grep_guard.tcl` (81 checks, full_audit logdir_tests) is an
**executable inventory** of the migration, four static source scans + one runtime canary:

- **S1 manifest** — every landed self-log site (scheduler branches, inline keys, cores in
  actions.c/save.c/select.c/editprop.c, gesture ENDs) still contains its `log_action` call;
  gate-locking rows pin the save `!fast` and Ctrl-S `!readonly` guards themselves.
- **S2 Tcl literal-log conflicts** — no `.tcl` hand-logs a literal `xschem <verb>` line for
  a verb whose C side self-logs, unless dedup-gated on `log_action -emitted`. This is the
  action_reload-double class (atom 4); allowlist: the xschem.tcl `load_new_window`
  dialog-resolution arms (C silent for the with-filename form by design).
- **S3 branch-must-not-log** — core-logged verbs (make_symbol/make_sch/make_sch_from_sel/
  descend/descend_symbol/go_back/select_grow_connected) have NO `log_action` in
  scheduler.c (the slice-6 lesson).
- **S4 recorder wiring** — the four dedup-wired recorders keep their reset/`-emitted`
  plumbing; also locks the new library_manager gated fallback.
- **S5 runtime canary** — exactly-once for cheap no-fixture verbs + a live
  `menu_action_logged` dedup check (catches suppress/dedup breakage text scans can't see).

**Maintenance ratchet (by design):** a new C self-log must add its S1 row and its S2 verb.

**Real bug found while arming S2:** `library_manager.tcl` `open_cellview` logged an
unconditional literal for both open arms; the `load -gui` pristine-window arm ALSO logs
`xschem load {f}` at the scheduler's `-gui` hook → every Library-Manager same-window open
wrote TWO lines, and the `-gui` copy replays interactively (empirically confirmed:
1 open = 2 lines). Fixed with the reset/`-emitted` dedup pattern; the gated fallback still
covers the arms C leaves silent (`load_new_window -window`, the routed new-window `-gui`
open — probed: `emitted=0` there). 0055-adjacent; the guard would have flagged it forever.

Sabotage-verified ×7 (no rebuild needed — scans read source text): reload literal re-add →
S2; branch log for descend_symbol → S3; `-emitted` unwire → S4 *and* S5 (live double);
copy-branch log removal → S1; save-gate drop → S1 gate row; lbm ungating → S2+S4.

---

## 9. Atom 6 outcome (2026-07-14): the stdin REPL and TCP channels record (issue 0003 CLOSED)

The last whole-channel holes (§2 OPEN row "stdin REPL + TCP") closed with the ciw_exec
record-after-evaluation pattern — reset flag → eval → if not `-emitted`, write the command
raw on success / `# failed:` comment on error:

- **TCP** (`xschem_getdata`, xschem.tcl): straight application of the pattern; a failed
  **multi-line** script gets *every* line commented (`regsub` newline → `\n# `) — a bare
  prefix would leave lines 2..n live on replay. Verified in-process with a loopback client
  against `setup_tcp_xschem 0`.
- **stdin** (`stdin_repl_setup`/`stdin_repl_read`, xschem.tcl end): the built-in Tcl/Tk
  stdin loop (`Tk_MainEx` StdinProc / `Tcl_Main`) is C with **no eval hook**, so for
  NON-TTY stdin (pipe/fifo/redirect — the automation channel) with the log open we take
  the channel over *before* `Tk_MainEx` runs: dup fd 0 via `/dev/fd/0`, `close stdin`, and
  immediately park the read end of a never-written `chan pipe` in the freed std-channel
  slot. Two landmines found empirically: (a) Tcl hands the freed slot to the NEXT opened
  channel — without the parked pipe a later schematic-file open becomes "stdin" and
  Tk_MainEx would eval its content; (b) `/dev/null` as the adopter EOFs instantly and
  Tcl_Main's stdin handler **exits the process on EOF**, killing headless `--nogui`
  sessions (e.g. a `--tcp_port` server). The replacement loop keeps native parity: errors
  to stderr, no result echo (non-tty Tk behavior), `info complete` accumulation,
  process still exits at stdin EOF.

**Decisions (issue 0003 §open, now resolved):** log unconditionally; no provenance
marker; `--script` bodies stay unlogged (one program = one record, its own §non-goal).
**Residuals (documented in the issue):** interactive TTY consoles (tclreadline / native
prompt) stay native and unlogged; a stdin command that pumps a nested event loop
(vwait/update) while ANOTHER channel logs sees the shared dedup flag set and suppresses
its own line — rare, and the concurrent command IS recorded.

Verified: `test_stdin_tcp_log.tcl` (16 checks — stdin via a child process since the
test's own stdin belongs to the harness; TCP in-process; dedup exactly-once for
self-logging verbs on both channels; `--script` non-logging; failed-multiline all-lines
commented), sabotage ×5 across both channels (each kill fails exactly its checks; the
dedup break shows n=2), grep-guard gained S1 rows locking the new sites' reset/`-emitted`/
`# failed:` plumbing. Beware the sandbox mirage: cross-process localhost probes of the
TCP server failed for environment reasons — the in-process loopback is the reliable oracle.

---

## 10. Atom 7 outcome (2026-07-14): Library Manager mutations record (issue 0064 CLOSED)

The Tcl-only mutation class of §3.4 closed by its own §4-step-4 route — not a
`log_mutation` helper and not new C subcommands, but the simplest correct form: the
**14 mutating `libmgr::do_*` workers** (the documented dialog-free seam of
`library_manager.tcl`) each log their own call line on the **success arm only**, just
before `return 1`:

```tcl
xschem log_action [list libmgr::do_<op> <args...>]
```

- **Why the do_* seam:** every ctx_* dialog Cancel diverts *before* reaching do_*, and
  every backend error is caught to `return 0` — so success-arm logging needs no
  cancel/error bookkeeping at all. The backends (`library_defs.tcl` / `library_git.tcl`)
  stay silent: they are shared sub-steps (a cross-library rename composes
  `library_copy_cell` + `library_delete_cell`; `lib_git_restore` is cancel-checkout's
  internal step) — logging there is the delete()-class mistake of §4.
- **No dedup wiring needed, but it exists anyway:** the lines never route through a
  self-logging C subcommand; and because `xschem log_action` itself sets
  `actionlog_cmd_logged` (util.c), a CIW-typed `libmgr::do_*` still records exactly once
  (ciw_exec skips its copy), and `actionlog_suppress` gates these lines for free.
- **Line form:** `[list]`-built → brace/backslash/newline-safe. A multiline commit
  message spans physical log lines inside balanced braces — source-able, same accepted
  class as the §9 TCP multi-line records (verified: `info complete` + re-eval commits
  the verbatim message).
- **Replay caveats (faithful-to-the-op, documented at the seam):** `do_checkin_lib`
  re-sweeps whatever is pending under the library at replay time; `do_cancel_checkout`
  discards replay-time uncommitted edits (destructive by contract, confirmed at
  record time only); `do_new_library` logs the path as given — `{}` re-resolves the
  default beside `library.defs` at replay. Replay is headless-safe: the three files are
  sourced unconditionally at startup, `refresh_after` early-returns without `.libmgr`,
  `libmgr::status` is catch-guarded.
- **Out of scope:** `libmgr::place_symbol` (interactive gesture, 0069 class — the drop
  already logs `xschem instance`); read-only viewers (`do_history*`,
  `do_show_checkouts`); the open/locate/read-only trio (already logged, atom 5 / 0055);
  0065 NHSE editor (separate atom).
- **Guard ratchet:** the sites are S2-invisible (lines don't start with `"xschem "`), so
  the lock is double: an **S1 manifest row** pinning ≥14 sites (line-anchored `(?n)^\s*`,
  so a commented-out site does not count) plus a new **S1b closure scan** that enumerates
  every `proc libmgr::do_*` and fails any worker that neither logs its own name
  (`\M`-bounded, so `do_checkin` cannot satisfy `do_checkin_lib`) nor sits on the
  read-only allowlist — a NEW unlogged mutating worker fails closed with no row bump.

**Adversarial-review round (3 confirmed findings, all fixed):**
1. **Headless replay was broken by `refresh_after` itself** — its guard
   `![winfo exists .libmgr]` is an *error*, not a false, in a `--nogui`/display-less
   session (Tk never loads), and it fired AFTER the backend mutation: the do_* worker
   mutated disk, then threw before its own log line (via the atom-6 stdin REPL the
   successful op even recorded as `# failed:`), and re-sourcing a log aborted mid-file
   at the first `libmgr::do_*` line. Fixed:
   `if {[info commands winfo] eq {} || ![winfo exists .libmgr]} return`. Locked by the
   test's new N-section (a `--nogui` child process runs `do_new_cell`: rc 1, cell on
   disk, exactly one seam line in its log).
2. **The ≥14 floor was not a ratchet** — a new unlogged do_* worker tripped nothing.
   Fixed with the S1b closure scan above (sabotage-verified: appending a log-less
   `do_nuke_cell` fails exactly its S1b row).
3. **A commented-out log site still counted** (raw-text regex). Fixed with the
   line-anchored row + S1b (sabotage-verified: commenting the `do_checkin` site fails
   both the count row and its S1b row).
   Plus hardening from an unconfirmed finding: the test's fixed `/tmp` work dir is now
   pid-suffixed (parallel-run collision).

Verified: `test_libmgr_mutation_log.tcl` (75 checks, full_audit logdir_tests — per-site
exactly-once + on-disk effect, backend-error and dialog-Cancel no-line via COUNTING
stubs, multiline-message source-ability, in-process replay of both a plain and a
multiline line, the `--nogui` child N-section; git sections self-skip without git).
Sabotage ×6: 3 seam logs (new_cell, delete_cell, checkin git-op → exactly the 7 owning
checks + the guard S1 row fail) + the 3 review-fix mechanics above. Full audit: no new
failures (test_reopen_readonly fails identically on stashed baseline — recent-files env
pollution; test_wire_vertex_grab passes standalone with the change — audit-congestion
flake).

---

*Prepared 2026-07-14, `fluid-editing`. §1–5 analysis only — no code changed. §6 added after
atom 3 landed; §7 after atom 4; §8 after atom 5; §9 after atom 6; §10 after atom 7. Coverage
verified in source at HEAD by a 14-way parallel read; do not trust the status table without
re-checking the cited `file:line` anchors, which drift as the tree moves.*
