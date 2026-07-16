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

## 11. Atom 8 outcome (2026-07-14): NHSE editor commits record (issue 0065 CLOSED — §2's last OPEN row)

Same Tcl-only class as atom 7 (§3.4). The C `update_net_hilight_style` branch fails the
1:1 test (shared mechanism: startup conf source, every scripting helper, the editor) —
so the **editor's live-commit points** log, each a self-contained form:

- **`nhse_apply_live`** (single staged→live point: Apply / OK / Cancel-revert) logs
  `net_hilight_style_set_live {<full table>}` after the C recompile (empty staged var
  re-materialized first). `set_live` is a new raw-preserving helper: adversarial review
  proved the first-cut normalizing form (`net_hilight_style_replace`) replay-diverges on
  sloppy hand-set tables (documented workflow, hilight.c:418) because Tcl norm and the C
  parser coerce differently — width `2.5` → C `2` vs norm `1`. Cancel logs the restored
  snapshot (idempotent no-op when nothing applied, slice-1 norm).
- **`nhse_reset`** (live immediately, outside the seam) logs bare
  `net_hilight_style_reset` at the button proc (atom-2 entry-site pattern).
- **`nhse_save`** success arm logs the **staged table** `set ::net_hilight_style {…}`
  then `write_net_hilight_style_conf {path}` — review proved path-only logging rewrites
  the wrong table on replay whenever Save wasn't immediately preceded by Apply (Save
  writes the STAGED var, which no other line records). Plain `set` matches Save's
  semantics: staged, no live push. Dialog-Cancel/write-fail silent.
- **Delete-last-row** (review find): emptying the table makes `nhse_rebuild`'s
  `net_hilight_style_current` re-materialize the layer default LIVE outside the seam —
  `nhse_op_delete` logs the materialized table, gated on the materialization actually
  happening (a window-less call early-returns in rebuild: no live change, no line).

Also review-driven: both atom-7/8 mutation tests gained a **no-Tk self-skip** (on a
display-less box the tk_* renames / `winfo` were invalid-command CRASHES that failed the
whole audit, not skips). **Documented residual:** the `apply_hilight` CLICK-to-apply arm
(cadence-rc mouse bind) appends a style row unlogged — click-position gesture, 0067 §5 /
0005/0069 class, recorded in issue 0065 §4.

Notable accepted form: the C-materialized default table is a MULTILINE Tcl value, so its
logged line spans physical lines inside balanced braces — the §9/§10 accepted class.

Verified: `test_nhse_mutation_log.tcl` (30 checks, full_audit logdir_tests — per-commit
exactly-once, machinery-silent sweep, counting-stub Save arms, raw-fidelity lock,
staged-Save divergence lock, delete-last lock with fake table-body frames, in-process
replay, `--nogui` child). Sabotage ×6 (3 original sites, then save set-line /
op_delete line / normalizing-form regression — each fails exactly its checks + its
guard rows). Full audit ×2: no new failures (test_fluid_editing 4× standalone pass both
sides = congestion flake; the rest = the known WSLg set).

## 12. Atom 9 outcome (2026-07-14): the paste/merge drop records a replayable line (0069's largest marker closed)

The §2 "Gesture drops" row's biggest hole — `end_move_copy_logged`'s STARTMERGE arm wrote a
dead `# paste/merge drop at delta …` marker, so a replayed session silently skipped every
pasted or merged object. The drop now logs the scheduler's own coordinate replay form:

```
xschem paste <dx> <dy> [<rot> <flip> [local]] [-anchor ax ay] [-file {f}]
```

- **Log site = the drop funnel (Layer-C pattern), not the cores.** `merge_file()` and
  `move_objects()` both fail the 1:1 test (shared by the scheduler replay arms and multiple
  key/menu paths). `paste_from` and `rotatelocal` are captured BEFORE `move_objects(END)`
  (which resets both, move.c END/ABORT). The line is built with `log_action_argv`
  (Tcl_Merge) so a brace-y filename stays replayable.
- **Source-distinguished, self-contained (§6 rule):** clipboard (`paste_from == 2`) logs the
  bare form and replays against the **replay-time clipboard file** (faithful-to-op accepted
  delta, same class as `do_checkin_lib`'s re-sweep, §10). File merges (`b` key dialog,
  File→Merge, `xschem merge f`) ride the recorded source via `-file {f}`, stashed per-window
  in the new `xctx->merge_source` by `merge_file()` at open success. The cross-window
  selection transfer (`paste_from == 1`) logs its transient `.selection.sch` path — usually
  gone at replay, so the line no-ops; accepted, the source has no durable referent.
- **Mid-gesture rotate/flip replays.** The scheduler `paste` branch grew `rot flip [local]`
  args (backward-compatible argc checks) that set `move_rot`/`move_flip`/`rotatelocal`
  before the END. `local` distinguishes the per-object in-place variant (Alt-R
  mid-gesture, or Shift-R via `connected_drag_group_transform()==0`) from the group
  rotate about the shared anchor. **The shared pivot rides the line as `-anchor ax ay`
  (adversarial-review MAJOR, confirmed empirically):** the drop's pivot is `x1/y1` from
  the merged file's `G` record, but a *whole-log* replay regenerates the clipboard via the
  replayed `xschem copy`, whose pointer position is not in the log — so with identical
  content the replayed `G` differs and a rot/flip drop landed rotated about the wrong
  point (final = R_pivot(coords)+delta; only translation-only and `local` drops are
  pivot-independent). The replay arm overrides `x1/y1` with the recorded anchor after the
  merge, making the replay G-record-independent (locked by T6b, which poisons the
  clipboard's `G` record and requires identical geometry).
- **The replay arm completes a pending merge instead of stacking a second one.** New gate:
  with `STARTMERGE` already pending, `paste dx dy` skips the `merge_file` call and just sets
  the deltas + END. This makes the 2-line record of a CIW-typed interactive `xschem paste`
  followed by the drop replay to exactly one paste (previously a latent double-merge), and
  keeps old logs (interactive line + skipped marker) harmless. A **failed** merge (missing
  clipboard/`-file` file) now also skips the END — the old unconditional
  `move_objects(END)` would translate whatever selection happened to exist by the delta.
- **The ctx-menu pick-8 table line (`"xschem paste"`) is removed.** The pick only STARTS the
  gesture (Layer-C class, like the place-symbol/text picks); keeping it would replay a
  second merge on top of the drop line's. Every entry path — Edit menu, toolbar, Ctrl-V
  legacy key, ctx pick 8, palette — now records exactly one line: the drop's.
- **Deliberately unchanged (0069 siblings, later atoms):** the sympin drop marker, the
  rot/flip-during-plain-move marker, shape point-edit (0005).

**Adversarial-review round (28-agent refute workflow; 46 findings, the confirmed ones
fixed in-tree):**
1. *Dangling STARTMERGE mislogged the next move as a paste (MAJOR).* `merge_file()` sets
   `STARTMERGE` before knowing whether anything was merged; an empty file / empty
   clipboard leaves `move_objects(START)` early-returning at `lastsel==0`, and neither
   clearing site (move END tail, ESC abort) ever runs — the next real move drop then took
   the STARTMERGE branch and logged `xschem paste dx dy [-file]` while the true
   `move_objects` line was suppressed (pre-change this dangler produced the dead marker;
   the new code upgraded it to an actively wrong replayable line — and a dangling flag
   also made a later ESC `delete(1)` the current selection). Fixed in `merge_file`: clear
   `STARTMERGE` when nothing got selected. Locked by T11 (sabotage reproduces the exact
   mislogged line).
2. *G-record pivot divergence (MAJOR)* — the `-anchor` rider above.
3. *`paste_from` poisoning (minor).* Any failed/cancelled mid-gesture `merge_file()` call
   (e.g. CIW-typed `xschem merge missing.sch` during a pending clipboard paste) resets
   `paste_from` without touching the pending gesture, degrading the bare clipboard form to
   `-file {clipboard path}`. Fixed: the logger's source test is now
   `merge_source == clip_file` (merge_source is written only on a successful open, so it
   stays owned by the pending merge). T8 locks the bare 4-element form.
4. *Replay-arm hardening (minor).* rot/flip masked (`&3`/`&1`, out-of-domain flip used to
   persist into the .sch); `rotatelocal` set unconditionally from the line (a pending
   gesture's interactive local flag must not leak into a no-local completion); named
   options parsed by scan, so `-file` is honored regardless of position.
5. *Stale `paste_from` header comment* (values 1/2 swapped vs paste.c) corrected.

**Documented residuals (accepted, not coded):**
- An ESC-abort of a *channel-typed* interactive `xschem paste` is unrecorded (gesture-abort
  class, 0005/0069): typed-bare + ESC + retry replays with the first pending merge's
  objects left at their load position. Same class: a session ending with an un-dropped
  typed paste replays into a live pending merge.
- `-file` lines referencing mutable/transient sources replay whatever exists at replay time:
  the cross-window selection transfer's `.selection.sch` (usually deleted → line no-ops; a
  recreated one merges foreign content), and generator sources re-run the generator. Same
  faithful-to-op class as the clipboard re-read.
- Hand-written degenerate grammars degrade silently (`paste x y rot` without flip drops the
  transform; bare `-file` without a name falls back to clipboard). Logger output is always
  well-formed.

Guard ratchet: S1 rows pin the drop-log argv build (incl. the `-anchor` rider) + the
line-anchored `log_action_argv` emit call (an `if(0)`/line-comment counts as removed; a
block comment still evades — the behavioral test is the real lock), the `merge_source`
stash + the empty-merge dangling-flag clear (paste.c), and the scheduler arm's completion
gate + `-file` merge form + `-anchor` parse; new **S1c** must-NOT-reappear scans lock the
old marker and the ctx pick-8 literal out; `paste` joined S2 and S3 (the branch IS the
replay form and must never log).

Verified: `test_paste_at_log.tcl` (40 checks, full_audit logdir_tests — drop exactly-once
with delta == displacement via `instance_coord`, replay-bypass invariant (log count
unchanged) for bare/rot/local/group/file forms, T6b G-record-poisoned replay still exact,
T10 pending-merge completion (one paste, no extra line), T11 no dangling STARTMERGE +
correct move line after an empty merge, ESC-abort logs nothing, no-motion drop still logs,
ctx-menu single-line + bare form, whole-log marker sweep; dependent checks guarded so a
dead logger fails 13 checks instead of killing the script; clipboard re-primed per section
to narrow the shared-`~/.xschem/.clipboard.sch` concurrency window). Sabotage ×5 (drop-log
`if(0)` → 13 test FAILs; replay-arm rot zeroing → exactly the two orientation-replay
checks; ctx pick-8 literal re-add → T8 double-line + guard S1c; anchor-override `if(0)` →
exactly T6b; dangling-clear `if(0)` → exactly the T11 pair, reproducing the reviewer's
mislogged line verbatim).

## 13. Atom 10 outcome (2026-07-15): property-edit dialogs record a REPLAYABLE line (0063 shape setprop-allprops)

The §2 "Property-edit dialogs — 0063" PARTIAL row closed. `edit_property()` logged a
dead `# property-edit <type>` marker for wire/rect/line/arc/poly/text + global attrs +
instance-via-vi (only the slick instance form was replayable). It now records the
scheduler's own replay form, one logical line per selected object:

```
xschem setprop <wire|rect|line|arc|poly> <ref> allprops {prop}   (shapes)
xschem setprop instance <name> allprops {prop}                   (instance via vi editor)
xschem set sch<X>prop {str}                                       (global schematic attrs)
xschem setprop text n txt_ptr {t} / size {h} {v} / allprops {p}  (text: 3 facets)
```

**The data-model constraint of §3.3 is dissolved, not merely shrunk.**
- **The `allprops` arms.** `setprop` gained a whole-prop-string `allprops` form on
  wire/rect/text, and **three entirely new arms — line/arc/poly — which had no `setprop`
  case at all** (the audit's specific 0063 blocker). Each new arm sets `prop_ptr` then
  recomputes the cached derived fields (bus/dash/fill) exactly as the matching
  `edit_{line,arc,polygon}_property()` commit does, so a replayed edit renders identically.
- **Read-back, not `tctx::retval`.** A multi-object edit forces `preserve_unchanged_attrs`,
  so `set_different_token` gives each object its own distinct tokens — logging the dialog's
  single `retval` would clobber them on replay. `edit_property()` reads **each committed
  `prop_ptr` back** and logs that (`log_prop_edit_one`/`log_prop_edit_replayable`,
  editprop.c), iterating `sel_array` for the dispatched type (prop edits never reindex, so
  the array is still valid; `apply_symbol_prop` mutates `prop_ptr` in place without
  unselecting).
- **Reference form: index, deliberately not stable-id.** Instances address by their
  persistent name (`get_instance`); shapes by type + layer(`col`) + array index. **Stable
  ids are session-only and re-minted on reload**, so an id recorded before a reload never
  resolves after one; the array index is deterministic under the fixture-load + ordered-replay
  model (the replay model the tests and `test_action_replay.sh` use). This is the opposite of
  what a naive "use the new handles" reading of §3.3 would do, and it is the correct call for
  *replay* (as opposed to a live-session query, where an id is better).
- **The bypass split (S3).** The shape `allprops` arms **must not self-log** — `editprop.c`
  emits the line, and the scheduler branch is the replay form. The setprop branch-tail
  self-log gate stays exactly `fast != 1 && argv[2] == "instance"` (slice 5): the instance
  arm self-logs (covering scripted token edits and re-emitting the dialog line identically on
  replay), every shape subtype is excluded. Broadening that gate is what a future refactor
  would get wrong, so the grep guard pins the gate literal.
- **Global attrs** map `netlist_type` → `sch{,symbol,vhdl,verilog,spectre,tedax}prop` and log
  `xschem set <var> {str}` — a form that already existed (scheduler `set` branch) and does
  **not** overlap `set header_text` (a different field). Those `set sch*prop` arms don't
  self-log, so the emitted line replays without re-logging.
- **Text** carries three independent facets (string / independent xscale-yscale / attribute
  props) that no single prop string holds, so it emits a small bundle; `setprop text ... size`
  was extended to an optional second value so the dialog's independent h/v sizes round-trip.
- **Exclusions preserved** by the existing `if(modified && x != 2 && !(type==ELEMENT && x==0))`
  gate: `x==2` view-only (`view_prop`), the slick instance form (self-logs `apply_properties` —
  logging both would double), and a cancelled dialog (`rcode` empty → `modified==0`).

**Adversarial-review round (6-dimension refute workflow, 2 independent verifiers per finding):**
1. **MAJOR — instance rename broke replay (fixed in-tree).** An instance edit via the external
   editor that changes the `name=` token renames the live instance (`new_prop_string`), so the
   emit's read-back `instname` is the NEW name — `setprop instance <newname> allprops {..}` fails
   `get_instance` against the reloaded fixture (still the old name), silently dropping the edit.
   Fixed by snapshotting each selected instance's **pre-edit** name before the commit and
   addressing the line by that old name; the arm's `new_prop_string` re-applies the rename from
   the new prop's `name=` token. Locked by test T9b (a renaming edit), sabotage-reproduced (revert
   to the post-edit name → T9b + the byte-identical replay both fail). The original T9 stub only
   appended a token, so it never exercised a rename — the gap was real and untested.
2. **rect `allprops` cached-field staleness — already fixed (verifiers refuted).** Flagged from the
   pre-fix diff; the shipping rect arm already recomputes `dash/ellipse/fill/bus` from the new prop.
3. **Refuted: a slick-form navigation type-flip emitting a spurious shape line** — reachable only
   via the dead legacy `edit_prop` dialog; the shipping non-blocking slick form never sets
   `edit_symbol_prop_new_sel`, so `type` stays `ELEMENT` and the `ELEMENT && x==0` exclusion holds.

**Documented residuals (accepted, not coded):**
- **Text collateral pin-rename (minor).** `edit_text_property` has a legacy heuristic: an ordinary
  (non-owned) text label whose `txt_ptr` matches a nearby PINLAYER rect's `name=` token, when
  edited, also renames that pin rect (editprop `~770`). The text bundle records only the text's
  own facets, so a replay in a symbol-like buffer leaves the pin's old name — a divergence. Narrow
  (symbol view, proximity + exact name match) and superseded by the modern owner_pin_id mechanism;
  the D1 residual call is to document rather than re-derive the match at emit time.
- A pin-name-view text edit is retargeted to its PINLAYER rect (editprop `~1495`), so the line
  is `setprop rect PINLAYER n allprops {..}`; replay restores the rect's prop + `set_rect_flags`
  but not the name-view side effects (`pin_view_apply`/`pin_reorient`). Symbol-editor corner,
  0005/pin-name class.
- The `set sch*prop` arms have no read-only guard (pre-existing 0041-class); a replayed global
  line on a read-only view mutates it. The important replay-safety path — `setprop … allprops`
  on a read-only view — **is** rejected (the branch-head `scheduler_readonly_reject`).
- Instance-of-a-different-master lines in a multi-instance selection are idempotent no-ops on
  replay (faithful-to-the-final-state, slightly noisy).

**Guard ratchet:** S1 rows pin the editprop per-object emit tail (line-anchored) and the global
`set sch<X>prop` emit; **a new S1 row pins the setprop self-log gate literal** so broadening it
past instance-only fails; S1c locks the old `# property-edit` marker out of editprop.c.
`test_selflog_output` §3h was rewritten (marker → replayable line) and its §5 whole-log
source-ability check was made **multi-line-aware** (a braced prop value spans physical lines —
accumulate to `info complete`; the atom-8/9 accepted class).

Verified: `test_shape_setprop_log.tcl` (35 checks, full_audit logdir_tests — every type +
multi-object + global + instance-vi + **instance rename (T9b)**, faithful replay via **source**
(byte-identical save), shape replay-bypass = zero extra log, `info complete` multi-line lock,
cancel/viewdata/read-only no-line, slick-form-not-double); sabotage ×5 (tail-emit neutralized →
17 FAIL; self-log-gate broadened → exactly the 5 shape-bypass checks + the grep gate row; global
emit neutralized → exactly T8; text `size` second value dropped → exactly the T6 independent-scale
replay; ELEMENT emit reverted to the post-edit name → exactly the T9b rename pair). Full audit: no
new failures beyond the known WSLg/env set (`test_selflog_output` transform-keys,
`test_action_replay.sh` "log missing placed instance" — both baseline-confirmed; `test_palette`
emits no `RESULT: ALL PASS` banner so full_audit classifies it FAIL regardless, `test_remap`
passes standalone — both pre-existing, unrelated).

## 14. Atom 11 outcome (2026-07-15): the Add-Pin drop records a REPLAYABLE line (0069's sympin marker closed)

The §2 "Gesture drops — 0069" row's sympin hole closed. `end_move_copy_logged`'s
`START_SYMPIN` arm wrote a dead `# place symbol pin (no replayable subcommand yet)`
marker, so a replayed session silently skipped every pin placed with the Add-Pin form.
ONE marker covered TWO drops that share `START_SYMPIN` + the `sympin_preview` move
machinery, now told apart in the funnel by the dropped object's TYPE:

- **(a) SYMBOL pin** — a `PINLAYER` (`col==5`) `xRECT` placed by `add_symbol_pin -place`.
  Logs `xschem add_symbol_pin <x> <y> <name> <dir> 0 1` (x,y = rect center; name/dir read
  from the rect prop, copied out because `get_tok_value` shares one static buffer).
- **(b) SCHEMATIC pin** — an ipin/opin/iopin ELEMENT placed by `add_sch_pin -place`. Logs
  the SAME `xschem instance {sym} x y rot flip {prop}` read-back a normal symbol placement
  uses, via a new shared helper `log_placed_instance()` (refactored out of the
  `PLACE_SYMBOL` arm — the sch-pin drop IS an instance placement).

**Log site = the drop funnel (Layer-C), not the cores.** `add_symbol_pin`, `place_symbol`
and `place_sch_pin` are shared by the `-place` gesture start, the direct replay form, and
tests — the 1:1 test fails, so the funnel is the sole logger (atom-9 pattern). Both replay
forms are coordinate commands that never reach `end_move_copy_logged` and never self-log,
so a replay never re-logs (coordinate-form-bypass invariant). Grep guard S3 pins
`add_symbol_pin`/`add_sch_pin` silent in the scheduler; S2 pins no Tcl literal-log.

**The central question (Q3): the faithful SYMBOL-pin replay form.** `add_symbol_pin x y
name dir` was NOT byte-equivalent to a `-place` drop, for two reasons: (i) it stored a
20-unit stub LEG LINE the `-place` drop never does, and (ii) the drop MOVES the pin, and in
a symbol view the move syncs the name view's geometry back into the rect's `name_*` tokens
(`pin_view_writeback` appends `name_rot`/`name_flip`), which bare `create_pin` does not.
**Resolution: a new trailing `noline` arg** to the direct form that (a) skips the leg line
AND (b) reproduces the move-time writeback under the SAME `netlist_type==CAD_SYMBOL_ATTRS`
gate the move loop uses (actions.c pin-view writeback loop) — so `add_symbol_pin x y name
dir 0 1` saves byte-identically to the drop **by construction** (it runs the drop's own
writeback code, not a re-derivation). Rejected alternatives: making `-place` store the leg
(a behavior change to every dialog-placed pin), and reading back the raw rect + owned name
view (the view is regenerated on load, not saved, and a plain `xschem text`/`rect` would not
restore the `owner_pin_id` linkage — the Q3 (iii) fragility).

**Reference forms.** Symbol pin = coords + name + dir, rebuilt via `create_pin` (byte-
identical incl. the writeback tokens for in/out/inout, where `name_rot` appends after
`name_flip` deterministically because both drop and replay run the same `subst_token`
sequence). Schematic pin = the instance read-back (name-addressed, deterministic under the
fixture-load + ordered-replay model; the atom-10 precedent — deliberately NOT stable-id).

**Multi-name queue (Q5).** Each click drops ONE pin and the funnel logs exactly one line;
the intuitive release then clears `START_SYMPIN` + `sympin_preview` (callback.c) so the next
arm starts a fresh gesture. N names → N lines (locked by the test's 3→3 sym and sch cases).

**Exclusions preserved (Q6).** ESC-abort tears down the preview undo-free (callback.c
abort path) with no drop → no line; an `add_sch_pin` that placed nothing clears
`sympin_preview` so `START_SYMPIN` is never set → the funnel arm is never reached; and
`add_sch_pin` refuses in a symbol view (a schematic pin is an instance).

**Adversarial-review round (4-dimension refute workflow, 2 verifiers/finding): 3 findings,
0 confirmed** — both non-empty findings were the same accepted-class residuals, refuted
after empirical repro:
1. *Mid-gesture rotate/flip of a symbol-pin preview* (Alt-R/Shift-R during the drag) replays
   the name label at rot/flip 0 — the pin rect is symmetric so its geometry is unaffected,
   but the label orientation diverges. Reachable (START_SYMPIN implies STARTMOVE, so the
   'R'/'F' keys route into `move_objects(ROTATE|FLIP)`), but the SAME class as the still-open
   rotate/flip-during-plain-move marker (0069) and the atom-9 deferred sibling; the Add-Pin
   dialog cycles type via Ctrl+MMB, not rotate. Documented, not coded.
2. *A pin NAME containing a literal backslash* read-back-diverges (`a\b` → `ab`) because
   `get_tok_value` unescapes and `create_pin` stores `name=` raw. Every legitimate identifier
   round-trips byte-identically (verified: plain, bus `A[3:0]`, angle `DATA<7>`, `VDD!`,
   `net.a`, `a_b`), and the dialog splits names on whitespace so a space in a name is
   impossible. Same accepted read-back class as the atom-9/10 name-addressed forms.

Verified: `test_sympin_drop_log.tcl` (42 checks, full_audit logdir_tests — in/out/inout for
BOTH sym & sch pins, byte-identical replay via saveas oracle, replay-logs-nothing bypass,
ESC no-line for both, multi-name 3→3 for both, `add_sch_pin` symbol-view refusal, direct
`add_symbol_pin` form not self-logged); sabotage ×3 (remove the noline writeback → exactly
the 3 sym-pin byte-identical checks; emit `noline=0` → the 3 no-line-form + byte-identical
checks; break the PINLAYER rect detection → sym-pins fall to the fallback marker, exactly
the sym-pin + queue + sweep checks — sch pins untouched in all three). Full audit: no new
failures beyond the known WSLg/env set (`test_sympin_drop_log` PASS; `test_selflog_output`
transform-keys + `test_action_replay.sh` "log missing placed instance" baseline-confirmed;
`test_verb_noun_copy_move`/`test_deselect_mode`/`test_fluid_editing` pass standalone =
audit-congestion flakes). The `PLACE_SYMBOL` refactor (shared `log_placed_instance`) left
`test_gesture_end_log` + the byte-identical `test_action_replay` checks green.

## 15. Atom 12 outcome (2026-07-15): the Cadence Ctrl-E parent-window hop records a replayable line (0053-class)

The gap named in §6 (atom-3 review): `cadence_style_rc:180` binds Ctrl-E as a **raw Tk
bind** (`bind .drw <Control-Key-e> {cadence::return_one_level; break}`) that never reaches
`dispatch_input_action`, so the sub must self-log. `cadence::return_one_level` has three
branches; two are in-place `xschem go_back` (already logged by the atom-3 `go_back` core) and
the third is the **parent-window hop** `cadence::focus_window $parent`, which called
`xschem new_schematic switch $win` and logged **nothing** — so a replayed session drifted to
the wrong window and every subsequent edit landed in the wrong context.

**FIX (pure Tcl, ~12 lines, no rebuild):** `cadence::focus_window` now logs
`xschem log_action "xschem new_schematic switch $win"` immediately after the switch, **after**
the `if {$win eq $cur} return` same-window early-out (so a no-op hop records nothing).

**The 1:1 test → log at the entry seam, NOT the core (§4 step 1).** `new_schematic switch`
FAILS the 1:1 test: the C core is a shared mechanism, called by the tab-strip click machinery
(`xschem.tcl` ~12316/12328/12331/… all `… switch $w {} 0`, no-draw UI plumbing), `alt2_toggle_view.tcl:122`,
and the window-open paths (`xschem.tcl` 5584/5826). Logging in the scheduler `new_schematic`
branch (scheduler.c ~5922) would flood every tab redraw and machinery switch. `focus_window`
is reached **only** by the cadence return chain (`return_one_level` :154, and `return_to_top`
via it — verified by grep, the two sole callers), so the seam covers exactly the real user
window-hops. This is the atom-2/4 entry-site rule applied to a Tcl-only class (cf. atoms 7/8).

**Q2 — the replay referent (the central question). Decision: log the raw Tk win_path.**
`new_schematic switch` resolves its argument via `get_tab_or_window_number` (xinit.c:1555):
an exact `window_path[]` match, else a cell-name fallback. The **monotonic window number**
(window-numbering.md) was evaluated and **rejected**: `switch` has no number resolver today
(it would need new C surface — a number→path lookup + a scheduler arm), and in the **ordered
whole-log replay model** a number is *no more* replayable than a path — both encode
window-creation order, and replay reconstructs windows by replaying the logged `create_window`
/ `load_new_window` lines in the same order, so both line up under the same precondition and
both fail under the same precondition (a mid-session close+compact that reuses a slot path,
or a divergent creation order). The path is simpler, lower-risk, natively resolved, and the
common parent is `.drw` (always exists, always that path — maximally stable). The cell-name
referent was rejected as ambiguous when two windows show the same cell. **Residual (accepted,
0053-class, D1):** whole-log replay assumes window-creation order is preserved — the same
assumption the already-shipped `create_window {}` lines make; a mid-session close+compact can
reuse a `.xN.drw` path. Documented, same class as atom-9's mutable `-file` referents.

**Q3 dedup / Q4 bypass / Q6 exclusions.** Ctrl-E is a raw bind with no dispatcher wrapper →
`focus_window` is the **sole logger** (no `-emitted` gate); the scheduler `new_schematic`
branch does not self-log. A replayed `xschem new_schematic switch <path>` hits the C branch →
`new_schematic()` → `switch_window`/`switch_tab`, and **never re-enters** the Tcl
`focus_window` proc → replay never re-logs (bypass invariant, like every coordinate-form
replay). Preserved exclusions: the same-window early-out (no line); the two `return_one_level`
`go_back` branches (logged by the atom-3 core — a second line here would double); a
stale/gone parent (`forget_window`, no switch → no line).

**Test `tests/headless/test_cadence_window_hop_log.tcl` (22 checks, full_audit logdir_tests).**
Live-Tk (`--pipe --logdir`, NOT `--nogui` — it drives the raw Ctrl-E bind end-to-end and reads
the log file), with the no-Tk / no-log self-skips + pid workdir of atoms 9–11, and
`mouse_follows_focus 0` pinned so the explicit context switch is not undone by the pointer-warp
EnterNotify under WSLg (the issue-0054 desync). Scenarios: H1 parent hop logs exactly one
`switch .drw` (child kept open); H2 same-window no-op logs nothing (early-out); H3 the in-place
branch logs `xschem go_back` (atom-3 core) and NO switch; H4 replay oracle — the just-recorded
switch line, re-evaluated, resolves to the recorded window in BOTH referent directions (parent
`.drw` and a child `.xN.drw`); H5 end-to-end via the verbatim `cadence_style_rc:180` binding
(real `<Control-Key-e>` event → real bind → one switch line; the recorded line then replayed
deterministically resolves to the parent, avoiding the flaky post-event live context); H6 a
scripted/replayed switch line does not itself log (bypass); H7 a direct core
`new_schematic switch … {} 0` (the tab-strip machinery form) logs nothing (scope). SABOTAGE
×3 (neutralize the emit → H1/H4/H5 + grep-guard S1/S6 fail; hard-code the referent → H4b fails;
log before the early-out → H2 fails), each failing exactly its checks.

**Grep-guard extension (test_selflog_grep_guard.tcl):** S1 row for the `focus_window` emit
(`utils/cadence_nav.tcl`, line-anchored so the prose comment does not count) + a new **S6
SEAM-EXCLUSIVITY** block — exactly one Tcl `new_schematic switch` log line exists, it is
`cadence_nav.tcl`, and **no C core** self-logs the `new_schematic switch` form. The C-core
scan covers all three machinery files the switch path lives in (`scheduler.c` dispatch,
`xinit.c` `switch_window`/`new_schematic`, `callback.c` EnterNotify/FocusIn), matching the
`switch` verb SPECIFICALLY so the legitimate `new_schematic destroy` window-close self-logs
(`xinit.c:2240/2331`) are not false-positives (this widening was the one actionable note from
the review — the original scan grepped `scheduler.c` alone). `new_schematic` is deliberately
NOT added to the S2 CVERBS set: it is Tcl-seam-logged, not C-self-logged, so the Tcl literal
log is legitimate.

**Adversarial review (6-lens refute workflow, 2 verifiers/finding): 0 confirmed, 4 dismissed
(all minor, real=false on verification).** Every lens verdict SOUND: the referent lens
confirmed the window number is minted by the *same* per-creation counter as the slot path, so
every de-sync scenario perturbs path and number identically — no reachable case where a path
misresolves while a number would be correct (Q2 vindicated). The edgecases lens confirmed the
unconditional log-after-switch never diverges: Ctrl-E/Alt-E are raw Tk binds that bypass
`callback()`'s semaphore bump, so `focus_window` runs at `semaphore==0` and the switch always
actually happens (the "log a switch that did not occur" hazard is unreachable). Dismissed
residuals (documented, not fixed): the S6 C-core blind spot (now closed by the widening above);
H5 hand-installs the verbatim binding rather than sourcing the rc (sourcing clobbers the test's
library fixtures; `clone_canvas_bindings` propagation already has dedicated coverage in
`test_clone_canvas_bindings.tcl` CB3).

Full audit: no new failures beyond the known WSLg/env baseline (`test_selflog_output`
transform-keys, stash-confirmed identical with the impl removed; the cadence duo
`test_cadence_descend_newwin_ro`/`test_cadence_drag`). `test_descend_newwin_return` and
`test_descend_readonly` (both source `cadence_nav.tcl`) stay green.

## 16. Atom 13 outcome (2026-07-15): a mid-move/copy rotate/flip drop records a REPLAYABLE line (0069 FULLY CLOSED)

The §2 "Gesture drops — 0069" row's last hole closed. `end_move_copy_logged`'s
`else if(rot || flip)` arm wrote a dead `# move/duplicate selection with rotate/flip (…):
no single-command replay` marker, so when the user pressed Alt-R / Shift-R / Shift-V / Alt-F
mid-drag the replay dropped the object at the WRONG orientation (the translation replayed via
the plain arm's twin, the ROTATION was lost). The drop now logs the scheduler's own coordinate
replay form, one line per drop:

```
xschem move_objects <dx> <dy> <rot> <flip> [local] [-anchor ax ay] [kissing]
xschem copy_objects <dx> <dy> <rot> <flip> [local] [-anchor ax ay] [kissing]
```

This is atom 9's paste treatment applied to move/copy — same pivot problem, same two riders.

- **Log site = the drop funnel (Layer-C), not the cores.** `move_objects`/`copy_objects` fail
  the 1:1 test (shared by the scheduler replay arms + many key/menu paths); the funnel is the
  sole logger (atom-9/11 pattern). `dx/dy/rot/flip/rotatelocal/kissing/x1/y1` are captured
  BEFORE the END that resets them (the capture already grabbed `ax=x1/ay=y1`, added for the
  paste atom).
- **The pivot (Q1, the central axis, = atom-9's G-record lesson).** The mid-move rotate has two
  pivot modes, told apart by `xctx->rotatelocal`: **`local`** (per-object center, Alt-R/F on a
  SINGLE object — `move_objects(ROTATE|ROTATELOCAL)`) is pivot-independent, no rider;
  **shared-pivot** (Shift-R/F/V, or Alt-R/F on a MULTI-object connected drag —
  `connected_drag_group_transform()!=0` drops ROTATELOCAL) rotates about `x1/y1` = the grab
  cursor, which rides as **`-anchor ax ay`**. It MUST ride because a whole-log replay's
  `move_objects(START)` seeds `x1/y1` from the replay-time cursor (`mousex_snap`), not the
  recorded grab point → a shared-pivot rotate would land about the wrong point. **Gesture
  gotcha, verified in source:** mid-move **Shift-R is ALWAYS the group rotate about the anchor,
  even on a single object** (`case 'R'` STARTMOVE → `move_objects(ROTATE)` with no ROTATELOCAL),
  so a one-object Shift-R drop correctly logs `-anchor`, not `local`.
- **The replay arms bypass the funnel (Q2).** The scheduler `move_objects` final-else and
  `copy_objects` arm parse `rot flip [local] [-anchor ax ay]` (mirroring the paste arm), set
  `move_rot`/`move_flip`/`rotatelocal` (+ `x1/y1` when `-anchor`) UNCONDITIONALLY from the line
  (a stale interactive `rotatelocal` must not leak), then call `(START)`+`(END,dx,dy)` directly
  — never `end_move_copy_logged`, so a replay never re-logs (coordinate-form-bypass invariant).
  `move_objects`/`copy_objects` joined the S3 branch-must-not-log set. The parse is guarded vs
  the `kissing`/`stretch` flag words and only runs when a delta is present (`argc>3+nparam`), so
  a plain `move_objects dx dy [kissing]` line parses byte-identically to before (the sub-verb
  `start/step/end/abort` forms are dispatched in earlier branches, untouched).
- **Byte-identical BY CONSTRUCTION.** The fluid diagonal-decomposition is gated
  `move_rot==0 && move_flip==0` (move.c), so a rot/flip drop always takes the single-pass
  rotation-aware commit `ROTATION(move_rot,move_flip,pivot,obj)+delta`; the replay runs the same
  commit with the same recorded `rot/flip/pivot/delta`. move/copy START re-zeros the transform
  fields, so the replay arm's field-sets cannot leak into the next gesture.
- **Scope / exclusions (Q3–Q5).** The new arm is reached only after the STARTMERGE / START_SYMPIN
  / PLACE_SYMBOL / PLACE_TEXT arms return and after `if(nothing) return` (the mouse-drag no-motion
  path). Preserved: ESC-abort never reaches the funnel (no line); the genuine `nothing`
  early-return (a `drag_elements` press-release with zero delta) logs nothing. **Q4 fluid:** a
  rotate during a fluid connected move is the SAME drop funnel (in scope) — the new arm covers it,
  mirroring the plain-translation arm's issue-0005-bounded fidelity (no `stretch` flag; a
  connected reroute inherits the same bound the plain arm already has). The separate WIRING.md
  risk-8 "zero-delta ALT-R silently discarded during a fluid hold" is a fluid GEOMETRY bug
  orthogonal to logging (the transform is discarded before any log point) — documented there, not
  touched here.

**Adversarial review (5-lens refute workflow — pivot-anchor / parse-robustness / scope-double-log
/ exclusions-state / byte-identical-gaps — each lens a source-reading refuter): 0 findings, all
five empty** after substantial investigation. Every self-identified risk (fluid mid-gesture
`x1/y1` mutation vs the capture; negative anchor coords vs the exact-`strcmp("-anchor")` parse;
`argv[4]/argv[5]` OOB vs the `argc>5` short-circuit; the plain-path zero-field-sets vs START's own
zeroing; non-instance object types under the anchor; state leak into a subsequent gesture) was
examined and refuted.

**Guard ratchet:** S1 rows pin the callback emit head (`av[ac++] = "xschem"; av[ac++] = is_copy ?
"copy_objects" : "move_objects";`), the shared `-anchor` rider + `log_action_argv(ac,av)` call
(count bumped 1→2, now paste + rotmove), and the two scheduler replay-arm parses (the
kissing/stretch-guarded transform parse, count 2). New **S1c** locks the dead `no single-command
replay` marker out of callback.c. `move_objects`/`copy_objects` added to S3 (branch IS the replay
form → must not self-log); already in the S2 CVERBS set.

Verified: `test_rotmove_drop_log.tcl` (57 checks, full_audit logdir_tests — move+copy ×
Alt-R(local)/Shift-R(anchor,single & group)/Shift-V(rot=2 flip=1)/Alt-F(local flip), byte-
identical saveas oracle per case, the **poisoned-cursor replay** (`motion 950 730` before eval)
proving `-anchor` overrides START's seed [the move/copy analog of paste's T6b G-record poison],
plain-translation regression, replay-bypass zero-log, the genuine `nothing` mouse-drag exclusion,
ESC-abort no-line + geometry unchanged, whole-log marker sweep, scripted-replay no-self-log for
both riders). Sabotage ×3 (kill the `rot` parse → all rot-case byte-identical replays fail; kill
the `-anchor` override → exactly the anchor cases fail, `local`/plain survive; neutralize the emit
verb → the rot/flip drop-log checks + the grep S1 emit-head row fail), each failing exactly its
own checks. Full audit: no new failures beyond the known WSLg/env baseline set
(`test_selflog_output` transform-keys, `test_action_replay.sh` "log missing placed instance",
`test_phase3_mints` g/G snap keys, `test_lib_sweep` migration, `test_wire_split` W7 netlist
node-order — all stash+rebuild-confirmed byte-identical on baseline; the cadence duo + GUI set).

**0069 is now FULLY CLOSED** (paste/merge = atom 9, sympin = atom 11, rot/flip-during-move =
atom 13). The §2 "Gesture drops" row has no remaining marker; shape point-edit (0005) is a
separate selection-addressing issue, not a 0069 sibling.

## 17. Atom 14 outcome (2026-07-15): the Netlist command records a REPLAYABLE line (0062's last silent toolbar/menu row CLOSED)

The §2 "Toolbar + recent-component bar — 0062" PARTIAL row's **Netlist** gap closed. The
`netlist` scheduler branch logged nothing; the toolbar button (`toolbar_add Netlist
{xschem netlist -erc}`) and the menu item both eval `xschem netlist -erc`, so the real
"make a netlist" user action recorded no line at all. It now records the branch's own
resolved replay form:

```
xschem netlist [-erc] [-nohier] [{fname}]
```

- **Log site = the SCHEDULER BRANCH (the atom-3/4 branch-self-log shape, NOT a
  coordinate-bypass verb).** The branch is 1:1 with the user verb `xschem netlist` — reached
  by the toolbar, the menu, the plain `n` key (bound to `toolbar.netlist` → the dispatch
  after-eval dedup skips the wrapper copy because the branch sets `actionlog_cmd_logged` via
  `log_action_argv`→`log_action`), and scripted calls. It logs the resolved *output-affecting*
  form via `log_action_argv` (Tcl_Merge → a brace-y/space filename stays replayable),
  reconstructed from the parsed flags (`erc`, `!hier_netlist`, `fname`). netlist is a real
  re-executable action (like `save`), so it correctly **re-logs on replay** — this is the
  OPPOSITE of the coordinate-bypass verbs (paste/move_objects/wire), so `netlist` is
  deliberately **NOT** in the grep-guard S3 branch-must-not-log set; the S1 branch-emit row IS
  the lock (it is in S2 CVERBS so no Tcl file may hand-log a literal `xschem netlist` line).
- **The `global_*_netlist()` cores are SHARED** (this branch + the Shift-N key + the CLI `-n`
  batch), so they do NOT self-log — logging there would double the branch and flood the batch.
- **The Shift-N current-level key (callback.c `case 'N'` rstate==0) bypasses the branch**
  (direct `global_*_netlist(0,1)`), so it logs its equivalent at the entry site (the atom-4
  Ctrl-S/Alt-S keyboard-bypass pattern). The faithful form is **`xschem netlist -erc -nohier`,
  NOT bare `-nohier`** — an adversarial-review MAJOR (2 independent verifiers): the key runs
  `global_*_netlist(0,1)` and touches nothing else, in particular it does NOT clear
  `xctx->netlist_name`, but the branch's **erc==0** arm DOES clear it after netlisting
  (scheduler.c). So a bare `-nohier` line (erc=0) would, on replay, clear a custom
  `netlist_name` the key had preserved → a *later* replayed netlist writes the default file
  instead. `-erc` (erc=1) is the **state-preserving** flag here (it is not separate ERC work —
  ERC runs inside `global_*_netlist` regardless); erc=1 skips both the `netlist_name` clear and
  the infowindow suppression, so `-erc -nohier` reproduces the key's output AND its state
  (`hier_netlist=0` → the same `global_*_netlist(0,1)`). There is no `'N'`/ShiftMask netlist
  binding, so the legacy switch runs → the two paths are disjoint → one action = one line.
  (The key's extra `unselect_all(1)` and the branch's `eval_netlist_postprocess` are non-file
  side effects — netlisting ignores selection — so the netlist FILE round-trips byte-identically.)
- **MACHINERY GATE (the atom-4 `save fast` axis): `-keep_symbols` stays SILENT.** `-keep_symbols`
  is passed ONLY by the cellview/reroute machinery (`xschem.tcl:3278/3355`
  `xschem netlist -keep_symbols -noalert`, which netlist a temporarily-loaded file between
  unlogged `load -keep_symbols` calls) — a replayed line would fire against the wrong file /
  flood — so the branch gates its emit on `!keep_symbols`. Verified in source: `-keep_symbols`
  has no real-user caller, and `-messages`/`-noalert`/`-nohier` have no non-machinery caller, so
  `keep_symbols` is the clean, sole discriminator.
- **Policy (atom-4 `save` precedent): netlist IS a replayable user action** despite writing a
  file (Virtuoso echoes it); logged unconditionally on success. The **dir-unwritable early
  return** (`done_netlist == 0`) logs nothing (the emit sits inside that gate).
- **Out of scope, DEFERRED (user-confirmed, not silently expanded):** the toggle-colors /
  `toggle_*` family — pure-view toggles (`toggle_colorscheme`/`toggle_draw_pixmap`/
  `toggle_show_netlist`/`toggle_ignore`) per the 0066 display policy; the two edit-mode toggles
  (`toggle_stretch`/`toggle_orthogonal_wiring`) flagged as a candidate follow-up needing
  absolute-value (`set`-class) logging, not a replay-fragile relative flip. `simulate` does NOT
  netlist (`proc simulate` has no `xschem netlist`; the scheduler `simulate` branch calls the
  Tcl proc, which assumes the netlist exists). The CLI `-n` batch (`xinit.c:3629` direct
  `global_*_netlist(1,1)`) is left silent — it is the whole program's purpose (one program = one
  record, atom-6 policy) and runs at startup before the interactive log matters.

**Adversarial review (5-lens refute workflow — machinery-gate-completeness / key-branch-double-log /
nohier-byte-equivalence / scope-missed-callers / replay-fname-reentrancy, each a source-reading
refuter with a second independent verifier per surviving finding): 1 CONFIRMED (fixed in-tree), the
rest refuted/accepted.**
1. **MAJOR — the `netlist_name`-clear asymmetry (fixed).** The first cut logged the Shift-N key as
   bare `xschem netlist -nohier`. Two independent lenses confirmed a real reachable divergence: the
   branch's `erc==0` arm clears `xctx->netlist_name` after netlisting, but the key never does — so a
   replayed bare `-nohier` line would clear a custom `netlist_name` (set via `-N foo.spice` launch or
   `xschem set netlist_name`), and a *later* replayed netlist would then write the default file
   instead of the custom one. Fixed by logging **`xschem netlist -erc -nohier`** — erc=1 is the
   state-preserving flag (skips the clear + the infowindow suppression), matching the key exactly.
   Locked by test 4b (key preserves a custom name; the replayed `-erc -nohier` line preserves it; a
   control bare `-nohier` line is shown to CLEAR it — the divergence avoided).
2. *Refuted/accepted (did not survive verification):* the mirror machinery-clear (a silent
   `-keep_symbols` op clears `netlist_name`; the clear isn't logged so a later replayed bare netlist
   could write the custom file) is an inherent property of the silent-machinery gate over a shared
   session global — the SAME accepted class as atom-4's cellview temp-file machinery, not fixable
   without logging machinery (which would be wrong); the `unselect_all(1)` and `eval_netlist_postprocess`
   differences are non-file side effects; the `done_netlist==1`-without-a-write no-op log is the
   slice-1 norm (replay-consistent no-op). Documented, not coded.

Verified: `test_netlist_log.tcl` (26 checks, full_audit logdir_tests — every branch form (`-erc`,
bare, `-nohier`, `fname`) records exactly its line and the RECORDED line replayed regenerates the
netlist BYTE-IDENTICALLY (netlisting is deterministic — a double-netlist proof underpins the
oracle); `-keep_symbols` machinery silent both with and without `-noalert`; dir-unwritable logs
nothing (a regular-file path component makes mkdir fail root-proof); Shift-N key logs `-erc -nohier`,
its recorded line replays byte-identically, and it preserves a custom `netlist_name` (with a control
proving bare `-nohier` clears it — the fixed divergence); plain `n` key dispatch dedup exactly-once;
fname form replays to the custom path; no `ask_save` prompt). Sabotage ×3 (neutralize the branch
emit → exactly the 9 branch-form checks; drop the `!keep_symbols` gate → exactly the 2 machinery
checks; neutralize the Shift-N key log → exactly the 1 Shift-N log-count check, while its two
netlist-OUTPUT checks stay green). Grep guard: S1 rows for the branch gate (`if(done_netlist &&
!keep_symbols)`) + emit (`av[ac++] = "netlist";`) + the Shift-N key emit; `netlist` added to the S2
CVERBS set; deliberately NOT added to S3 (the branch IS the self-log site — the atom-3/4 shape).
Full audit: no new failures beyond the known WSLg/env baseline (the cadence duo, test_ciw /
test_hi_descend / test_lib_manager_gui / test_reopen_readonly / test_altf5_ciw GUI set,
test_selflog_output transform-keys, test_phase3_mints g/G snap keys, test_lib_sweep migration,
test_wire_split W7 netlist node-order, test_select_at pending-stash, test_verb_noun / test_fluid_editing /
test_wire_vertex_grab congestion flakes — none touches netlisting); test_netlist_log passes standalone
and reports ALL PASS headless (its keyboard sections defer without the `skipped: no X` token so the
non-X branch/machinery/dir/fname core still validates in a windowless audit; the Shift-N emit is
statically locked by the grep-guard S1 row regardless).

**0062's last silent toolbar/menu row (Netlist) is CLOSED.** The 0062 remainder now has only the
`toggle_*` display/edit-mode toggles left, deferred by documented policy above.

## 18. Atom 15 outcome (2026-07-15): the apply_hilight click/immediate arms record a REPLAYABLE line (0065 §4 / 0067 §5 residual CLOSED)

The last live click-gesture hole named in issue 0065 §4 and issue 0067 §5 closed. `apply_hilight`
(`utils/apply_hilight.tcl`) applied a favourite net-highlight style but recorded nothing; both of
its arms now log the resolved positional row, one line per apply: `net_hilight_apply {<8-column
resolved style row>}`.

- **Two entry sites, not the shared proc (the atom-8 rule).** `net_hilight_apply` is a shared Tcl
  proc (immediate arm + click arm + typed channel + direct scripting/replay), so — exactly as
  atom 8 did for the NHSE editor — logging goes at the **live entry sites**, never in the proc
  (which would flood the typed channel and re-log on replay). The click arm (`aphl::try_apply`,
  fired by the raw `.drw <ButtonRelease>` bind → `after idle`) and the immediate arm
  (`apply_hilight`, reached with a selection) each emit `xschem log_action [list net_hilight_apply
  <row>]` right after the C apply. The two arms are DISJOINT per gesture (the immediate branch
  applies to an existing selection and never stages a pending prompt, so `try_apply` is not reached
  for the same invocation).

- **The click arm owes only the STYLE half (atom-1 select_at).** A single-CLICK selection is
  already recorded: `select_object()` self-logs `xschem select_at x y` (stashed by the C core), and
  that stash is FLUSHED by try_apply's own `log_action` — so the recorded pair is `select_at x y`
  THEN `net_hilight_apply {row}`, verified in order by driving the FULL Tk ButtonPress/Release
  sequence (the gesture-test-full-sequence lesson; a lone synthetic event would have passed against
  a broken feature). On replay the select_at re-selects the net and the apply line re-styles it.

- **net_hilight_apply is faithful for the COERCION axis by construction — no raw-preserving twin.**
  This is the atom-8 `set_live` divergence axis, and it does NOT recur: `net_hilight_apply` runs
  `net_hilight_style_norm` on its arg *identically* at record and replay, so a sloppy row (width
  `2.5` → `1`) round-trips to the same coerced style both times. The recorded row is the RESOLVED
  positional row (`aphl::parse` output), NOT the raw named `$style` (`net_hilight_apply` reads a
  POSITIONAL row). The test's E-section locks this: the logged line carries `2.5` verbatim and
  replaying it reproduces the same width-1 style.

- **The immediate arm covers the F5 raw bind AND the typed channel, exactly-once.** The
  `cadence_style_rc` F5 bind bypasses `dispatch_input_action` (the 0067 class) — the immediate arm
  is its SOLE record. A CIW-typed `apply_hilight {..}` runs through `ciw_exec`, whose `-emitted`
  dedup sees `actionlog_cmd_logged` set by the arm's `log_action` and skips its own `apply_hilight
  {..}` copy → one line (the more self-contained resolved-row form). Sabotage-proved: with the
  arm's log removed, `ciw_exec` records the raw `apply_hilight {..}` copy — the double the fix
  prevents.

- **Scope / no phantom.** Esc-cancel (`aphl::on_key`) logs nothing; a non-net / empty click hits
  the `sel_has_net` gate in `try_apply` and logs nothing (the prompt stays pending); the trailing
  `xschem unselect_all`/`redraw` are UI cleanup, not logged. A direct scripted `net_hilight_apply
  {row}` (the replay form, or any other-proc caller — grep confirms only the two entry sites and a
  prose mention exist) does NOT self-log, so a replayed line never re-logs (bypass invariant).

**Adversarial review (5-axis refute+verify workflow — raw-row-divergence / double-log /
missing-log-phantom / selection-referent / machinery-leak-and-guard): 0 CONFIRMED.** Every surviving
finding was verified as an accepted pre-existing / 0005-class residual, not a regression introduced
by the two added log lines (the axis-4 refuter aborted on a schema cap and was self-checked clean:
only two statement-position callers, the proc self-logs nothing, S1d closure sound). The findings,
now documented residuals:

- **The drag-select-several variant (0005 class).** A *rubber-band* multi-net selection is not a
  replayable referent: `select_object()` (select.c) stashes `select_at` only for a single-CLICK
  hit; a rectangle select reaches `select_rect(END)` → `select_inside` → `select_wire` directly and
  stashes nothing (there is NO area-select action-log command anywhere). So a drag-then-apply
  records a lone `net_hilight_apply` line that replays against the replay-time selection. The
  single-click click-to-apply IS fully replayable; the drag variant collapses to the SAME accepted
  bare-line form the immediate arm already emits on ambient selection. Same class as the K-key
  `xschem hilight` and every selection-dependent verb.
- **The applied INDEX is ambient-table-dependent (0005/config class).** `net_hilight_apply`'s
  selection form does `xschem set hilight_color $idx; xschem hilight`, and `set hilight_color`
  CLAMPS `if(c >= cadlayers) c = 4` (scheduler.c). The COERCION axis is closed, but the resolved
  index depends on the ambient `net_hilight_style` table, which the log deliberately does not
  snapshot. So if the table differs between record and replay AND straddles `cadlayers` (=22 here),
  the same logged row can apply a different live style (idx 22 → clamp → style 4 vs idx 15 → the
  appended style). This is the VERB's own documented limitation (net_hilight_apply docstring:
  "reliable only while the table has fewer than cadlayers rows") — the live interactive apply
  already shows the clamped style regardless of logging. Snapshotting the whole table (nhse's
  set_live) would change the "apply one favourite style" semantics by overwriting the replay env's
  table, so it is deliberately NOT done. Same faithful-to-op class as atom-9's mutable referents.
- **The snapped-coordinate select_at (pre-existing, 0005).** The click selects on the RAW mouse
  point but `select_at` logs the SNAP-rounded coordinate; a click in the snap-crossing zone between
  two nearby unconnected nets can re-select a different net on replay. This is the select_at core's
  contract (commit fd83c0f5, predates apply_hilight), inherited by every click-select atom — not
  touched here.
- **The stale-pending double-apply (pre-existing UI wart, faithfully logged).** The immediate arm
  never clears `::aphl::pending`, so a prompt staged by an earlier nothing-selected F5, followed by
  a non-click select (Ctrl+A) + a second F5 (immediate log #1) + a net click (try_apply log #2),
  records two `net_hilight_apply` lines. Verified pre-existing in committed HEAD; the two lines are
  a FAITHFUL 1:1 record of two real applies on two selections, not a spurious duplicate — out of
  scope for a logging atom, left unchanged.

**Guard ratchet:** `test_selflog_grep_guard` gained a `utils/apply_hilight.tcl` S1 block (two
line-anchored emit rows — S2-INVISIBLE, like the atom-7/8 libmgr/nhse rows) plus a new **S1d
closure**: it counts statement-position `net_hilight_apply` invocations == 2, so a NEW unlogged
apply arm fails closed until it logs. NOT added to S2 CVERBS or S3 (Tcl-seam log, atom-7/8 shape,
no C scheduler branch).

Verified: `tests/headless/test_apply_hilight_log.tcl` (33 checks, full_audit logdir_tests — typed
channel exactly-once + no apply_hilight double; raw-bind immediate arm +1 + style installed; the
CLICK arm as a full Tk gesture asserting select_at-BEFORE-net_hilight_apply then replaying the pair
to re-highlight the net; Esc + non-net click no-line; raw-fidelity 2.5→1 replay lock; direct-call
machinery silent; `--nogui` child records + replays with no Tk). Sabotage ×3 (neutralize the
try_apply emit → 5 C-section FAILs + grep S1 try_apply row; neutralize the immediate emit → 8 FAILs
incl. the ciw_exec double + grep S1 immediate row; inject a 3rd unlogged apply site → S1d count 3),
each failing exactly its checks, each restore `git diff`-clean. Full audit: no new failures beyond
the known WSLg/env baseline (`test_apply_hilight_log` PASS; the 12 fails — cadence duo, test_ciw /
test_hi_descend / test_lib_manager_gui / test_reopen_readonly GUI set, test_selflog_output
transform-keys, test_phase3_mints g/G, test_lib_sweep migration, test_wire_split W7, test_select_at
pending-stash, test_fluid_editing congestion flake — all pre-existing, none touches apply_hilight).

**0065 §4 / 0067 §5 residual CLOSED.** Remaining action-log direction of travel: Refactor B
(`perform_action()` single mutation/log/readonly boundary); the two edit-mode toggles
(`toggle_stretch`/`toggle_orthogonal_wiring`) remain an optional set-class atom; shape point-edit
stays a 0005 selection-addressing issue.

## 19. Atom 16 outcome (2026-07-15): the two edit-mode toggles record a REPLAYABLE ABSOLUTE line (0062 tail CLOSED)

The §17 candidate follow-up landed. `toggle_stretch` and `toggle_orthogonal_wiring` logged a
**relative flip** (`xschem toggle_stretch`), which **replays wrong**: replayed against a start
state that differs from record time it lands on the *opposite* value. Both now self-log the
**resolved ABSOLUTE state read back after the flip** — the set-class form, same rule as atom-10's
read-back, atom-14's `-erc` state-preservation, and the 0066 `set cadsnap` resolved-value policy:

```
xschem set enable_stretch <0|1>
xschem set orthogonal_wiring <0|1>
```

- **Log site = the CORE `toggle_*_cmd` (1:1 with the verb).** Grep confirms each `toggle_*_cmd`
  (callback.c) is reached by exactly two callers — its scheduler branch (`xschem toggle_*`) and its
  registered `act_toggle_*` (the key/menu dispatch) — both *are* the toggle verb, so one self-log
  covers key + script. The key's csv `log_cmd` copy (`xschem toggle_stretch`, actions.csv:204) is
  the relative form; it **dedups** via the dispatch after-eval `actionlog_cmd_logged` gate
  (`callback.c` — `log_action()` sets the flag, dispatch skips the copy) → exactly one absolute
  line, the atom-14 `n`-key pattern.
- **The `set <var>` scheduler arms are the REPLAY form and must NOT self-log.** New arms
  `set enable_stretch` (just the mirrored tcl var, all `toggle_stretch_cmd` does) and
  `set orthogonal_wiring` (reproduces the FULL cmd effect: `manhattan_lines=0` on OFF + the
  rubber-layer redraw, exactly `toggle_orthogonal_wiring_cmd`) apply the effect on replay without
  a `log_action` — a log there would double every replayed line (coordinate/replay-form-bypass).
  Edit-mode session config, not saved content → **no read-only guard** (0066 policy b, like
  `cadsnap`; a replayed `set enable_stretch` on a read-only view changes an editor mode, not the
  cell). The pure-VIEW toggles (`toggle_colorscheme`/`draw_pixmap`/`show_netlist`/`ignore`) stay
  UNLOGGED (0066 display policy) — untouched.
- **The divergence lock (the whole point).** `test_toggle_editmode_log.tcl` records a toggle from
  `start=0` (logs `set …1`), sets the live state to 1, replays the logged line → **HOLDS at 1**; a
  control replay of the relative `xschem toggle_stretch` from state 1 → **FLIPS to 0**, proving the
  exact divergence the absolute form avoids (the test_netlist_log 4b template).

**Adversarial review (5-axis refute + independent verify + completeness critic): 0 code defects
confirmed, but the critic surfaced a real UNCOVERED ENTRY POINT — the menu — which the C-only
design missed.** The Options-menu checkbuttons *"Enable stretch"* (`-variable enable_stretch`) and
*"Enable orthogonal wiring"* (`-variable orthogonal_wiring`, xschem.tcl ~13972/13979) had **no
`-command`**: a bare `-variable` checkbutton flips the tcl var directly and **never calls
`toggle_*_cmd`**, so the menu click recorded nothing — and for `orthogonal_wiring`, whose verb has
**no key** (the old `L`/76 was rebound to `tools.insert_line`), that menu is the *only* interactive
control, so the new self-log was interactively dead *and* the click skipped the `manhattan_lines`
/redraw side effect entirely. The "1:1 caller" property was the smoking gun, not reassurance. Fixed
by giving both checkbuttons a `-command` that routes through the self-logging cmd (the sibling
*"Enable pin selection"* precedent, `-command {xschem set en_pin_select $en_pin_select}`): since Tk
pre-flips the `-variable` before running `-command`, the body **undoes the pre-flip** (`set var
[expr {!$var}]`) then calls `xschem toggle_*`, so the net effect is exactly one flip to the shown
value + one absolute log line + (for orthogonal) the C side effects. Verified by invoking the real
menu checkbuttons headless (`$menu invoke`).

Verified: `tests/headless/test_toggle_editmode_log.tcl` (23 checks, full_audit logdir_tests —
absolute-not-relative per verb, the divergence lock + orthogonal twin, the `set`-arm side-effect
replay, the bypass invariant, pure-view toggles silent, key-'y' dispatch dedup exactly-once under X,
**the two menu checkbuttons each a real `$menu invoke` → one net flip + one absolute line**).
Sabotage ×4, each failing exactly its checks, each restore `git diff`-clean: (1) revert the core to
the relative form → the divergence lock FAILS (`HOLDS-at-1` → got 0, plus 6 content checks; the
exactly-one-line dedup stays green — correct discrimination); (2) make the `set enable_stretch` arm
self-log → grep S3 (got=1) + the bypass check (delta=2); (3) drop the orthogonal arm's
`manhattan_lines` line → grep S1 (got=0); (4) strip a checkbutton's `-command` → grep S1 (got=0) +
the menu-log check (added empty). `test_phase3_mints` key-'y' updated (now asserts the absolute line,
searching the added tail — the absolute form recurs earlier in the log, so a whole-log `lsearch`
false-matches; the relative form is absent). Grep guard: S1 rows for both cores (callback.c), both
`set` replay arms (scheduler.c), and both menu `-command` routes (xschem.tcl, line-anchored);
`{set enable_stretch}`/`{set orthogonal_wiring}` added to S2 CVERBS; both toggle verbs **and** both
`set` arms added to S3 branch-must-not-log. Full audit: `test_toggle_editmode_log` PASS, no new
failures beyond the documented WSLg/env baseline (cadence duo, test_ciw / test_hi_descend /
test_lib_manager_gui / test_reopen_readonly GUI set, test_selflog_output transform-keys,
test_phase3_mints g/G snap keys, test_lib_sweep migration, test_wire_split W7, test_select_at
pending-stash, test_fluid_editing congestion flake — none touches the toggles).

**0062's toggle tail is CLOSED — every remaining §2 PARTIAL/OPEN row is now accounted for.** The
action-log direction of travel is Refactor B (`perform_action()` single mutation/log/readonly
boundary, §4) as its own multi-atom track — the menu-bypass finding here is a concrete argument for
it: a single boundary would have made "did the menu log it?" a structural invariant, not a
per-entry-point checklist item. Shape point-edit (0005) stays a selection-addressing issue.

## 20. Refactor B FOUNDATION (2026-07-15): actionlog_suppress gets a real setter + the two seams

Not a coverage atom — the structural groundwork Refactor B (§4, the `perform_action()` north
star) rides on. Atom 16 proved a per-entry-point self-log discipline still leaks (a bare
`-variable` menu checkbutton bypassed the core entirely); the cure the audit prescribes (§3.1)
is ONE choke point where "did we log it?" is a structural invariant. That choke point needs a
suppress/log gate that is safe under the two re-entrancy hazards of §3.2 — this atom builds
exactly that gate and **changes no observable log output.**

**What was actually missing (verified in source, not from the audit prose).** `actionlog_suppress`
already existed as an `int` (globals.c) and already gated all four writers —
`log_action`/`log_action_noecho`/`log_output`/`log_action_stash_select_at` each early-return on
`if(!actionlog_fp || actionlog_suppress)` (util.c). The gate was complete; it had **zero write
sites** — nothing ever set it (its sibling `actionlog_suppress_echo` did have a setter, `xschem
log_action -suppressecho`). So the whole atom is the SETTER + the WIRING, no new gate and no new
formatting.

**(1) The setter — a re-entrant DEPTH COUNTER, not a boolean.** The two hazards NEST (a replay
re-executes a logged line that is itself a composite calling several self-logging cores), so an
inner scope's exit must not re-open logging while an outer scope is live. `actionlog_suppress_push()`
(`++`) / `actionlog_suppress_pop()` (`if(>0) --`, underflow-clamped) are the safe surface
(util.c); `xschem log_action -suppress push|pop` exposes them to Tcl (scheduler.c log_action
subcommand); `xschem set actionlog_suppress N` is the absolute (hard-reset, `<0`-clamped) form the
task required (scheduler.c set branch, first arm of the `argv[2][0] < 'n'` block). The counter is a
pure C int, NOT tcl-mirrored — no reader needs a mirror. **Orthogonality to `actionlog_cmd_logged`
is by construction:** the writers early-return on `actionlog_suppress` BEFORE the
`actionlog_cmd_logged = 1` line, so a suppressed scope never leaves the wrapper-dedup flag dirty
for the next real action (locked by test case f).

**(2a) The REPLAY seam — `proc replay_action_log {file}` (xschem.tcl).** The ONE place an
in-session replay enters: `push; catch{uplevel #0 source $file}; pop; rethrow`. Sourcing a recorded
log while the log is still OPEN would re-enter the self-logging cores (undo/copy/flip/`set cadsnap`
/…) and DOUBLE every re-executable verb; the scope makes the lines re-EXECUTE but not re-LOG. The
`catch` keeps push/pop balanced across a mid-file error. **The hazard is latent-not-active in the
existing cross-process acceptance test** (`test_action_replay.sh` replays into a `--nolog` process
where `actionlog_fp == NULL`, so every writer is already a no-op) — this seam is what makes an
IN-session replay safe, exactly the §3.2 case the audit flagged and could not yet close.

**(2b) The COMPOSITE seam — the primitive, NOT a production wrap (a review-corrected decision).**
The first cut wrapped `abort_operation()` (the canonical audit teardown, "`abort_operation`
delete(1) teardown") in `push; do; pop`, on the premise that it "emits zero log lines today." **The
adversarial review refuted that premise (CONFIRMED MAJOR, 3 of 4 axes + 2 verifiers):
`abort_operation` is NOT a pure teardown.** Its `STARTPOLYGON` arm (callback.c:226) calls
`new_polygon(END)`, which COMPLETES the polygon — `push_undo` + `store_poly` (a real persisting
object) + `log_action("xschem polygon …")` (actions.c:4677). ESC-to-close-a-polygon is a first-
class completion gesture (symmetric with the Return-key close), so wrapping the whole function
SILENCES that real logged edit → the polygon persists but its replay line is dropped → replay
diverges. **Empirically confirmed:** driving the polygon gesture + ESC on the wrapped binary logged
0 `xschem polygon` lines; on the unwrapped binary, 1. So `abort_operation` is left UNWRAPPED (a
comment at its head records why, to stop a future re-add). The lesson generalizes: **there is no
genuinely zero-drift production composite to wrap today** — `abort_operation` completes+logs the
ESC-polygon, and `hier_traversal`'s walk logs faithful `descend`/`go_back` lines by §6's deliberate
choice; wrapping either is real output drift. So the composite hazard is closed **structurally by
the replay seam + the general `push/pop` primitive**, not by a production teardown wrap. The
composite MECHANISM is proven by a synthetic composite in the test (case e: three self-logging
sub-ops → +3 unwrapped, +0 inside a suppress scope), and the ESC-close-polygon-still-logs behavior
is now LOCKED (case g) so no future teardown wrap can silently reintroduce the drift.

**Deliberately NOT collapsed — `hier_traversal` (xschem.tcl).** §6 named this as the other real
composite: its all-hierarchy walk logs a faithful `descend -inst` / `go_back 2` pair per subcircuit
(≈28 lines on greycnt.sch). It is a NET-ZERO read-only dialog refresh (descend then return), so
wrapping the top-level `hier_traversal 0 …` call in `push/pop` would be replay-equivalent and drop
the noise — BUT §6 kept those lines by a deliberate "faithful by design" decision, and collapsing
them WOULD change a currently-shipped log's output. Per the atom's "changes no observable output"
constraint + DQ3 "do not silence a real multi-effect op / do not change a currently-correct
granularity," this atom provides the setter that makes the collapse a **one-line opt-in follow-up**
(the §6 remedy is now available) but does not take it. The composite-collapse MECHANISM is instead
locked by a synthetic composite in the test (case e: three self-logging sub-ops → +3 unwrapped, +0
inside a suppress scope).

**Verified:** `tests/headless/test_actionlog_suppress_gate.tcl` (19 checks, full_audit
logdir_tests — (a)–(f) X-independent, (g) drives a gesture): (a) baseline mutator +1; (b)
absolute-set scope +0 then resumes; (c) push/pop NESTS at depth 2, one pop stays suppressed, outer
pop restores, extra pop underflow-clamped; (d) the replay seam re-executes without re-logging
(`copy`/`set cadsnap 5` counts unchanged) AND the cadsnap effect applies, with a CONTROL unwrapped
`source` that DOES re-log — proving the wrap is load-bearing; (e) the composite granularity lock;
(f) `cmd_logged` clean after a suppressed scope (`-emitted==0` inside, `==1` after); (g) the
review-driven regression lock — a polygon gesture + ESC still logs `xschem polygon` (deferred, not
failed, if the gesture makes no polygon in a windowless env). **Sabotage ×3 on the shipped design,
each failing exactly its checks, each restore `git diff`-clean:** (1) push body → no-op:
(c)/(d)/(e suppressed→+3)/(f) fail while (b) absolute-set stays green (the two surfaces are
independent); (2) drop the replay wrap: (d) re-logs + grep S1/S4 xschem.tcl rows fail; (3) drop the
pop `>0` clamp: an extra pop drives the counter negative (still truthy) and logging sticks OFF —
case (c) extra-pop fails. Plus the empirical A/B that drove the review fix: wrapped binary logs 0
`xschem polygon` on ESC-close, unwrapped logs 1. **Grep guard extended:** S1 rows for the two
util.c definitions, the scheduler `-suppress`/`set actionlog_suppress` arms, and the two
`replay_action_log` seam lines (line-anchored); a new **S4 suppress-scope block** locks the three
wiring points so a future edit that removes any one fails closed.

**Adversarial review (4-axis refute + independent verify — nesting-leak / replay-completeness /
output-drift / flag-separation): 1 CONFIRMED MAJOR, FIXED in-tree.** Three axes (nesting,
replay, flag-separation) independently traced the same real defect — the `abort_operation`
suppress-wrap silences the ESC-close-polygon `new_polygon(END)` self-log — and a second verifier
confirmed each; it was fixed by removing the wrap (see 2b above), and locked by case (g). Notably my
OWN output-drift axis MISSED it (it checked `delete`/`move`/`new_wire` under abort but not
`new_polygon(END)`) — the multi-axis panel is what caught the hole a single reviewer's blind spot
left, the point of the exercise. The setter counter (balanced push/pop, safe underflow clamp,
correct nesting), the replay seam (all writes route through the honored gate; cross-process replay
`--nolog`-safe), and the flag separation (suppress early-returns before `cmd_logged=1`; the two
flags never corrupt each other) were all verified SOUND with no surviving findings.

**Next atom:** the FIRST per-verb migration onto `perform_action` — pick one clean 1:1 mutator,
route its key/menu/scheduler/gesture entry points through the one boundary, and prove one readonly
gate + one log site (the suppress gate is now the safety net that makes the log site re-entrant-
safe). Optional bounded pick: the atom-16 menu-bypass CLASS sweep (other edit-geometry `-variable`
checkbuttons). Optional one-liner: collapse `hier_traversal`'s walk with the new setter if the ≈28
navigation lines are judged noise.

## 21. Refactor B ATOM 1 (2026-07-15): the FIRST per-verb migration onto perform_action (trim_wires)

The north star of §4 gets its first real vertebra. `perform_action(verb, argc, argv)` now
EXISTS as the single mutation/command boundary (scheduler.c, right after
`scheduler_readonly_reject`), and exactly ONE verb — `trim_wires` — is routed through it,
proving the pattern end-to-end with **byte-identical output preserved.** Scope was held tight:
one verb, no global `core_log_action` registry, no rewrite of the ~40 existing `log_action`
sites (that churns every S1 anchor + replay test — its own future atom).

**The boundary, as built.**
```c
static int run_core(const char *verb, int argc, const char *argv[]) {   /* the EFFECT */
  if(!strcmp(verb, "trim_wires")) { xctx->push_undo(); trim_wires(); draw(); return TCL_OK; }
  return TCL_ERROR;                       /* unreachable this atom */
}
int perform_action(const char *verb, int argc, const char *argv[]) {
  if(!xctx) { Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR; }
  if(scheduler_readonly_reject(interp, verb)) return TCL_ERROR;   /* ONE readonly gate  */
  int rc = run_core(verb, argc, argv);                           /* ONE effect         */
  if(!actionlog_suppress) log_action("xschem %s", verb);         /* ONE log site        */
  Tcl_ResetResult(interp); return rc;
}
```
The two disjoint entry sites collapse onto it: the scheduler `trim_wires` branch becomes
`return perform_action("trim_wires", argc, argv);` (was: `!xctx` check + `scheduler_readonly_reject`
+ `push_undo` + `trim_wires()` + `draw()` + `log_action("xschem trim_wires")` + `Tcl_ResetResult` —
all now inside the boundary), and the inline `&` key (callback.c legacy switch) becomes
`perform_action("trim_wires", 0, NULL)` (its key-specific `semaphore>=2` guard stays before the
call; its old `readonly_block()` is subsumed). `perform_action` is `extern` in xschem.h; the key
handler and the branch call it uniformly via the global `interp` (no interp param needed) — the
key passes `(0, NULL)`, the branch passes `(argc, argv)`, and for a bare no-arg verb `run_core`
`(void)`-casts them.

**Why `trim_wires` — and the 1:1 rule applied precisely.** The verb is bare (no pivot/args/
gesture complications) and clean at the VERB level. But the *shared C function* `trim_wires()`
is ALSO an internal sub-step of `align()`, move/rotate/flip-END autotrim (move.c), the
wire-break edit (check.c), `maintain_wire_segments`, and `select_connected_nets` (select.c) —
those call it RAW and legitimately DO NOT route through `perform_action` (the boundary wraps the
verb DISPATCH, not the C function). Locked by test case (e): `xschem align` still logs only
`xschem align`, never `xschem trim_wires`. This is the §4-step-1 rule ("log at the core when the
core IS the verb; log at the entry sites when the core is a shared mechanism") re-cast for the
boundary: the boundary wraps the verb, the shared mechanism stays below it.

**Entry-point map, verified by grepping the GUI (the atom-16 lesson), not just C callers.** Every
LIVE user path to the verb funnels through `perform_action` exactly once: Tools menu
(hand-written `-command "xschem trim_wires"`), toolbar `ToolJoinTrim`, the *Auto Join/Trim Wires*
checkbutton on turn-ON (evaluates `xschem trim_wires`), the command palette, and scripted
`xschem trim_wires` → all reach the scheduler branch; the `&` key → the callback legacy switch.
No double-dispatch: `&` (keysym 38) is ABSENT from keybindings.csv, so `handle_key_press`'s
registry pre-dispatch is skipped and only the legacy `case '&'` runs; the menu `-accelerator {&}`
is display-only. No wrapper double-log: the Tools menu is hand-written, NOT table-built, so
`trim_wires` is never wrapped in `menu_action_logged` (and the palette runs the command raw) —
the core's log is the sole line. There is no `trace` on `autotrim_wires` that could hide a fifth
trim path.

**The read-only unification (0041/0051), realized.** The boundary's ONE `scheduler_readonly_reject`
replaces the branch's identical call AND the `&` key's `readonly_block()` — both gated on the exact
same predicate `if(!xctx || !xctx->readonly)`, so the decision is unchanged from every path. The
one deliberate user-facing delta: the `&` key on a read-only cell now emits a CIW note (has_x) /
interp error (headless) instead of a `tk_messageBox` MODAL — which makes the key CONSISTENT with
its own Tools-menu item (already CIW-note via the scheduler path). A welcome side effect: the
`&`-on-readonly path no longer HANGS headless (the modal was un-stubbable), so the test drives it
directly. **Accepted residual (review-confirmed, not a defect):** in a GUI session where `ciw_echo`
is somehow not loaded, the `&` key on a read-only cell gives no visible feedback — but the mutation
is still blocked and nothing is logged; it is a feedback-quality tradeoff of the intended
unification. NOT patched, because a per-key fallback would re-diverge the key from its menu item.

**Replay parity.** `trim_wires` is a bare, RE-executable verb (like `save`/`netlist`), NOT a
coordinate-form bypass (`wire x1 y1 x2 y2`): a direct re-run re-executes AND re-logs (correct); a
replay through the `replay_action_log` suppress seam re-executes but does NOT re-log (the log site
rides `!actionlog_suppress`, the atom-20 foundation). So it stays IN S2 CVERBS and correctly OUT
of S3 branch-must-not-log.

**Grep guard (test_selflog_grep_guard.tcl).** The two `trim_wires` S1 log rows (scheduler branch +
`&` key) were MOVED onto the boundary rows: the branch `return perform_action(...)`, the `&` key
call, the `int perform_action(...)` definition, the ONE `scheduler_readonly_reject(interp, verb)`
gate, and the ONE `log_action("xschem %s", verb)` site. A new **S7 BOUNDARY EXCLUSIVITY** block
fails closed if a future edit re-adds a SCATTERED `log_action("xschem trim_wires")` or a scattered
`scheduler_readonly_reject(...,"trim_wires")` at any entry point (the exact per-path-checklist
regression the boundary abolishes), and pins `perform_action` as defined exactly once.

**Verified:** `test_perform_action_trim_wires.tcl` (16 checks, full_audit logdir_tests):
(a) exactly +1 from EACH of script / `&` key / menu wrapper; (b) read-only reject from the scripted
(TCL_ERROR, verb-named message) and `&`-key paths — no log, no mutation; (c) the logged line is
byte-exact `xschem trim_wires` (no format drift); (d) replay re-executes with the effect applied
(wires 2→1) but no re-log through the seam, vs a control unwrapped `source` that re-executes AND
re-logs; (e) the `align` sub-step logs only `align`, never `trim_wires`. A pre/post-migration 5-axis
behavioral probe (read-only scripted + `&` reject, writable `&` trim, `align`, menu dedup) diffs
**IDENTICAL.** Grep guard + suppress-gate stay green; `test_selflog_output`'s trim_wires lines pass
(its only FAILs are the pre-existing transform-key set). **Sabotage ×4** (each failing exactly its
checks, each restore `git diff`-clean): (1) neutralize the boundary's readonly gate → the (b)
read-only-mutation checks fail (scripted trim on a read-only cell now mutates + logs); (2)
neutralize the log site → (a)/(c) + grep S1-log-site + S5-canary fail (and the menu wrapper's
dedup safety-net correctly still logs once — proving the boundary is not the ONLY guard); (3)
bypass the boundary on the `&` key (raw core, no gate) → the read-only-`&` mutation leak + grep S1
`&` row fail; (4) re-add a scattered scheduler `log_action("xschem trim_wires")` → grep **S7** fails
closed. **Full-audit baseline diff clean** (git stash + rebuild + rerun: the FAIL set is unchanged —
the known GUI/cadence/keybind/congestion pre-existing failures, with `test_perform_action_trim_wires`
added GREEN). **Adversarial review (6-axis refute panel, ultracode): verdict CLEAN, zero confirmed
defects** — bypass-entrypoint, readonly-gate, output-drift, substep-misroute, replay-parity, and
signature-build each independently found no failing scenario; the sole observation (the
`&`-on-readonly feedback-quality note above) was explicitly classed not-a-defect.

**Next atom:** the SECOND per-verb migration — `align` or a bare in-place transform
(`flip_in_place`/`rotate_in_place`) onto the same boundary (same shape, `run_core` grows one arm).
The end-state remains the full funnel of §4; each verb that moves onto `perform_action` deletes its
scattered readonly+log pair and gains an S7-locked structural invariant.

## 22. Refactor B ATOM 2 (2026-07-15): the SECOND per-verb migration onto perform_action (align)

The pattern proves it generalizes. A second verb — `align` — now routes through the same
`perform_action(verb, argc, argv)` boundary; `run_core` grew exactly ONE arm; output stays
byte-identical. Scope held as tight as atom 1: one verb, no global `core_log_action` registry,
no rewrite of the ~40 existing `log_action` sites.

**Why `align` — and the wrinkle it carries that `trim_wires` didn't.** align is a bare no-arg
verb (`xschem align`), clean 1:1 at the VERB level, adjacent to `trim_wires` in the scheduler. Two
differences from atom 1 shaped the work:
1. **align operates on the SELECTION.** Its effect is `round_schematic_to_grid(cadsnap)`, which
   `rebuild_selected_array()`s and snaps each *selected* object's coords to the grid — unlike
   `trim_wires`, which works on all wires. With nothing selected it is a silent no-op (but still
   logs from the boundary). So the effect oracle SELECTS an off-grid wire `(3,7)-(103,7)` and
   asserts it snaps to `(0,0)-(100,0)` at `cadsnap=20` — verified empirically that `xschem wire`
   stores raw off-grid coords and the migrated verb snaps them through every path.
2. **The effect body is richer** than trim_wires' three lines: `push_undo` +
   `round_schematic_to_grid(tclgetdoublevar("cadsnap"))` + (autotrim-gated)
   `maintain_wire_segments()` + `set_modify(1)` + the four `prep_*` hash-invalidations + `draw()`.
   `run_core`'s align arm replicates the **scheduler branch's** body byte-for-byte (the branch is
   the canonical reference, as atom 1 established). This also **retired a latent divergence:** the
   old Alt-U key body ran `set_modify(1)` *before* `maintain_wire_segments()` and read `c_snap`
   (its local) rather than `tclgetdoublevar("cadsnap")`; both now converge on the branch order and
   the same cadsnap read. That read is provably identical — `c_snap` is initialised to
   `tclgetdoublevar("cadsnap")` at `handle_key_press`'s caller (`callback.c:7400`), so no snap drift.

**The 1:1 rule, re-applied.** There is **no `align()` C function** — the verb inlines
`round_schematic_to_grid` + `maintain_wire_segments`. `round_schematic_to_grid` is **exclusive to
the align verb** (its only two callers were the two align entry points), so it has no sub-step
caller to leak from. `maintain_wire_segments` IS shared (move-END autotrim, place-symbol, the wire
cmd, the trim_wires branch, …) and internally calls `trim_wires()`, but none of those log `xschem
align`, and align's own `maintain → trim_wires` sub-step must NOT emit `xschem trim_wires` — the
shared C functions are not user verbs. Locked by test case (e): `xschem align` logs exactly one
`xschem align`, zero `xschem trim_wires`.

**Entry-point map, grepped from the GUI (the atom-16 lesson), not just C callers.** Every LIVE user
path funnels through `perform_action` once: the hand-written Tools menu item (`xschem.tcl:14394`,
`-command "xschem align"`, raw — NOT `menu_action_logged`-wrapped), the command palette
(`uplevel #0` raw), the `actions.csv` `tools.align_to_grid` row (feeds palette + cheat-sheet), and
scripted `xschem align` all reach the scheduler branch; the **Alt-U key** → the callback legacy
switch. No double-dispatch: keysym `u` has **zero rows in keybindings.csv**, so the registry
pre-dispatch is skipped and only the legacy `case 'u'` `EQUAL_MODMASK` arm runs; the menu's
`-accelerator Alt+U` is display-only. Shape is identical to `trim_wires`/`tools.join_trim_wires`.

**The read-only unification (0041/0051), again.** The boundary's ONE `scheduler_readonly_reject`
replaces the branch's identical call AND the Alt-U key's `readonly_block()` — both gated on
`!xctx->readonly`, so the decision is unchanged from every path. Same deliberate delta atom 1 made
for `&`: the Alt-U key on a read-only cell now emits a CIW note / interp error instead of a
`tk_messageBox` MODAL, making it consistent with its own Tools-menu item and no longer hangs
headless. Same accepted residual (no `ciw_echo` → no visible feedback, but the mutation is still
blocked and nothing logged) — not patched, for the same reason.

**Replay parity.** align is a bare, RE-executable verb (like `trim_wires`/`save`), NOT a
coordinate-form bypass: a direct re-run re-executes AND re-logs; a replay through the
`replay_action_log` suppress seam re-executes (the selected off-grid wire snaps) but does NOT re-log
(the log site rides `!actionlog_suppress`). Stays IN S2 CVERBS, OUT of S3.

**Grep guard (test_selflog_grep_guard.tcl).** The two `align` S1 log rows (scheduler branch + Alt-U
key) were MOVED onto boundary rows (branch `return perform_action("align", argc, argv);`, Alt-U key
`perform_action("align", 0, NULL);`); the boundary's generic gate + log-site rows already exist from
atom 1. The **S7 BOUNDARY EXCLUSIVITY** block was extended to align: it fails closed if a future edit
re-adds a scattered `log_action("xschem align")` (scheduler OR callback) or a scattered
`scheduler_readonly_reject(..., "align")` at any entry point.

**Verified:** `test_perform_action_align.tcl` (17 checks, full_audit logdir_tests): (a) exactly +1
from EACH of script / Alt-U key / menu wrapper; (b) read-only reject from the scripted (TCL_ERROR,
verb-named message) and Alt-U paths — no log, no mutation (wire stays off-grid); (c) byte-exact
`xschem align`; (d) replay re-executes with the effect applied (off-grid wire → `0 0 100 0`) but no
re-log through the seam, vs a control unwrapped `source` that re-executes AND re-logs; (e) the
`maintain → trim_wires` sub-step logs only `align`, never `trim_wires`. `test_selflog_output`'s
align/Alt-U lines stay green (its only FAILs are the pre-existing transform-key set). **Sabotage ×4**
(each failing exactly its checks, each restore `git diff`-clean): (1) neutralize the boundary's
readonly gate → the (b) read-only checks fail (scripted+Alt-U align mutate + log on a read-only
cell); (2) neutralize the log site → (a) scripted/Alt-U + grep S1-log-site + S5-canary fail, while
the menu wrapper's dedup safety-net correctly still logs once (so (a) menu + (c) stay green —
proving the boundary is not the ONLY guard); (3) bypass the boundary on the Alt-U key (raw
`round_schematic_to_grid`, no gate) → the read-only-Alt-U mutation leak + grep S1 Alt-U row fail;
(4) re-add a scattered scheduler `log_action("xschem align")` → grep **S7** fails closed (and the
scattered log fires *before* the boundary's gate, so it even logs on a read-only cell — the exact
per-path bug the boundary abolishes). **Full-audit baseline diff clean** (git stash + rebuild +
rerun: the deterministic FAIL set is unchanged — the known GUI/cadence/keybind/congestion
pre-existing failures — with `test_perform_action_align` added GREEN). **Adversarial review (refute
panel, ultracode): verdict CLEAN** — bypass-entrypoint, readonly-gate, output-drift,
substep-misroute, replay-parity, and effect-body-fidelity each found no failing scenario.

**Next atom:** a THIRD per-verb migration (a bare in-place transform —
`flip_in_place`/`rotate_in_place`/`flipv_in_place` — is the cleanest next candidate: bare, no pivot
args, same shape, `run_core` grows one arm), or the bounded atom-16 menu-bypass CLASS sweep. The
global `core_log_action` registry (§4 Refactor A step 2, rewriting all ~40 log sites) remains its
own future atom.

## 23. Refactor B ATOM 3 (2026-07-15): the THIRD per-verb migration — the FIRST with a mid-gesture split (`rotate_in_place`)

`rotate_in_place` now routes through the same `perform_action(verb, argc, argv)` boundary; `run_core`
grew exactly ONE arm; output stays byte-identical. Scope held as tight as atoms 1–2: one verb, no
global `core_log_action` registry, no rewrite of the ~40 existing `log_action` sites. What makes
atom 3 ≠ atoms 1–2 is a **`ui_state` SPLIT** that `trim_wires`/`align` did not carry.

**The wrinkle: only the STANDALONE verb crosses the boundary; the gesture arms stay raw.** The
scheduler `rotate_in_place` branch and the callback.c Alt-R key each have three arms:
`if(STARTMOVE) move_objects(ROTATE|ROTATELOCAL)` / `else if(STARTCOPY) copy_objects(ROTATE|ROTATELOCAL)`
/ `else <standalone>`. The during-move / during-copy arms are the **mid-gesture transform**,
DELIBERATELY silent at the verb level — they are logged once at the move/copy END as the
`move_objects`/`copy_objects` replay line (issue 0069, atom 13). Only the STANDALONE `else` is the
real user verb. So the boundary wraps ONLY the standalone case; the gesture arms stay **raw and
unlogged**. Routing a gesture arm through `perform_action` would spuriously emit
`xschem rotate_in_place` mid-drag and double-count the move-END line (locked by test case (e), and
by sabotage 5). `run_core`'s arm is byte-identical to the scheduler standalone body —
`rebuild_selected_array()` + `move_objects(START)` + `move_objects(ROTATE|ROTATELOCAL)` +
`move_objects(END)` — with **NO `push_undo()`/`draw()`**: `move_objects(START/END)` owns the undo push
(move.c) and the redraw, exactly as the pre-migration standalone body did. `ROTATELOCAL` pivots each
object about its own origin (`move.c:5325` `pvx = rotatelocal ? inst[i].x0 : x1`; wires
`move.c:7009` `wire[n].x1/y1`), so no pivot/`mousex_snap` seeding is needed.

**THREE standalone entry points, not two — the callback side has an extra.** Grepping the GUI (the
atom-16 lesson) surfaced that `rotate_in_place`'s standalone verb is reachable from THREE places, all
now funnelled through `perform_action` exactly once: (1) the **scheduler branch** `else` (`return
perform_action("rotate_in_place", argc, argv)`), reached by scripted `xschem rotate_in_place`, the
Edit menu (`xschem.tcl:14141`), the context menu (`xschem.tcl:12161`), and the `actions.csv`
`edit.rotate_in_place_selected_objects` row; (2) the **Alt-R key** → `standalone_group_transform`'s
single-object arm (`callback.c`); (3) the **verb-noun deferred apply** — Alt-R on an empty selection
arms `MENUSTARTROTATE` + `PENDING_TR_ROTATE_IP`, and the next click selects+applies it. Path (3) sat
inside a shared `move_objects(START) … switch … move_objects(END)` block with the flip/flipv cases;
migrating it meant **pulling `PENDING_TR_ROTATE_IP` OUT of the shared switch** (its own
`if(t == PENDING_TR_ROTATE_IP) perform_action(...)` before the shared START/END), because
`perform_action`→`run_core` owns its own START/END and must not nest inside the outer one. The other
five transform cases keep their exact bodies. No double-dispatch: keysym `r` has **zero rows in
keybindings.csv**, so the registry pre-dispatch is skipped and only the legacy `case 'r'`
`EQUAL_MODMASK` arm runs; the menu's `-accelerator Alt-R` is display-only.

**The read-only decision, and the one deliberate residual.** The boundary's ONE
`scheduler_readonly_reject` covers the standalone verb from every path. The scheduler branch **drops**
its top `scheduler_readonly_reject(interp, "rotate_in_place")` (S7 requires it gone); the Alt-R key
**keeps** its `readonly_block()` (it still guards the raw gesture arms + the arming path, and is not
S7-forbidden). Dropping the scheduler top-gate leaves the branch's STARTMOVE/STARTCOPY arms without a
readonly check — the adversarial panel refuted the naive premise "STARTMOVE ⟹ !readonly" (a script or
Ctrl-2 can toggle `readonly=1` mid-gesture without aborting the move). **But the panel then dismissed
it as unreachable-in-effect:** the raw mid-gesture ROTATE transform is *preview only* — `push_undo`
and `set_modify(1)` fire **only** in `move_objects(END)` (move.c:6814/7776), never in the
RUBBER/transform step — and the *only* commit path, `xschem move_objects end`, is itself refused under
readonly at the `move_objects` command's top gate (`scheduler.c:5369`, covering start/step/end/abort).
So a readonly-toggled-mid-gesture rotate **cannot persist or even dirty the buffer**. The transient
"flip_in_place still guards, rotate_in_place doesn't" asymmetry is cosmetic and closes when
`flip_in_place`/`flipv_in_place` migrate next. Accepted as a documented residual, not patched — a
targeted gesture-arm gate would be cosmetic (the base move-END gate already closes the window) and
would re-scatter a readonly check the boundary exists to abolish.

**Replay parity.** `rotate_in_place` is a bare, RE-executable verb (like `trim_wires`/`align`): a
direct re-run re-executes AND re-logs; a replay through the `replay_action_log` suppress seam
re-executes (a selected horizontal wire rotates to vertical) but does NOT re-log (the boundary log
site rides `!actionlog_suppress`). Stays IN S2 CVERBS, OUT of S3.

**Grep guard (test_selflog_grep_guard.tcl).** The `rotate_in_place` S1 rows MOVED onto boundary rows:
the scheduler branch `return perform_action("rotate_in_place", argc, argv);` and a callback.c row with
count **2** on `perform_action("rotate_in_place", 0, NULL);` (the Alt-R single-object standalone AND
the verb-noun apply — the verb-noun path is thus structurally locked without a runtime driver, which
would need a real arm-then-click on the wire's screen pixel). The **S7 BOUNDARY EXCLUSIVITY** block was
extended to `rotate_in_place`: it fails closed on a scattered `log_action("xschem rotate_in_place")`
(scheduler OR callback) or a scattered `scheduler_readonly_reject(..., "rotate_in_place")`.

**Verified:** `test_perform_action_rotate_in_place.tcl` (22 checks, full_audit logdir_tests): (a) +1
from EACH of script / Alt-R key / menu wrapper; (b) read-only reject from the scripted (TCL_ERROR,
verb-named message) and Alt-R paths — no log, no mutation; (c) byte-exact `xschem rotate_in_place`;
(d) replay re-executes (horizontal wire `0 0 100 0` → vertical `0 0 0 100`) with no re-log through the
seam, vs a control unwrapped `source` that re-executes AND re-logs; (e) **the wrinkle lock** — a
`rotate_in_place` issued with `STARTMOVE` active (headless `move_objects start` seam) is NOT logged
(+0). The effect oracle is a lone horizontal wire whose first endpoint is at the origin, so
`ROTATELOCAL` (pivot = its own `x1,y1`) rotates it to a clean vertical wire. `test_selflog_output`'s
`rotate_in_place`/read-only lines stay green; its `key Alt-R logs rotate_in_place` FAIL is
PRE-EXISTING (its `select_all` on a churned multi-object schematic makes Alt-R a *group* rotate
logging `rotate x y`, issue-0116 semantics, unchanged here — one of the known transform-key fails).
**Sabotage ×5** (each failing exactly its checks, each restore `git diff`-clean): (1) neutralise the
boundary readonly gate → (b) scripted read-only mutates + logs; (2) neutralise the log site → (a)
scripted/Alt-R + (c) byte-exact fail while the menu wrapper's dedup safety-net still logs once (so (a)
menu stays green — the boundary is not the ONLY guard); (3) bypass the boundary at the Alt-R
standalone (raw inline log) → grep **S1** count 2→1 + **S7** callback scattered-log both fail closed;
(4) re-add a scattered scheduler `log_action("xschem rotate_in_place")` → grep **S7** fails closed;
(5) route the STARTMOVE arm through `perform_action` → case **(e)** fails (mid-gesture double-logs).
**Full-audit baseline diff clean:** every AFTER failure reconciled as pre-existing — the known
GUI/cadence/keybind/congestion set, plus `test_remap`/`test_select_at` confirmed FAIL identically on
baseline standalone — with `test_perform_action_rotate_in_place` added GREEN; every change-adjacent
test (`test_rotate_prompt_object` = the verb-noun path restructured here, `test_alt_transform_group_0116`
= `standalone_group_transform`, `test_gesture_end_log` + `test_rotmove_drop_log` = the move-END
counterpart) PASSES. **Adversarial review (6-way refute panel, ultracode): verdict CLEAN, no must-fix**
— entry-point coverage, byte-identical effect, mid-gesture double-log, output-drift/replay, and
build/C89 each found no failing scenario; the one flagged readonly-gate item was dismissed as
unreachable-in-effect (preview-only transform + readonly-gated move-END, above).

## 24. Refactor B ATOM 4 (2026-07-15): the FOURTH per-verb migration — the MIRROR of atom 3 (`flip_in_place`)

`flip_in_place` now routes through the same `perform_action(verb, argc, argv)` boundary; `run_core`
grew exactly ONE arm; output stays byte-identical. Scope held as tight as atoms 1–3: one verb, no
global `core_log_action` registry, no rewrite of the existing `log_action` sites. atom 4 is the exact
**mirror** of atom 3: `flip_in_place` is bare (no pivot args), a single `move_objects(FLIP|ROTATELOCAL)`,
reached from the same THREE standalone entry points via the same code atom 3 restructured, and it
carries the same **`ui_state` SPLIT**. `flipv_in_place` (three `move_objects` calls:
`ROTATE|ROTATELOCAL`×2 + `FLIP|ROTATELOCAL`, and NOT handled by `standalone_group_transform`) is
deliberately its own atom 5 and was left untouched.

**The wrinkle (identical to atom 3): only the STANDALONE verb crosses the boundary.** The scheduler
`flip_in_place` branch and the callback.c Alt-F key each have three arms:
`if(STARTMOVE) move_objects(FLIP|ROTATELOCAL)` / `else if(STARTCOPY) copy_objects(FLIP|ROTATELOCAL)`
/ `else <standalone>`. The during-move/during-copy arms are the mid-gesture transform, deliberately
silent at the verb level — logged once at the move/copy END (issue 0069, atom 13). Only the standalone
`else` is the real user verb, so the boundary wraps ONLY it; the gesture arms stay **raw and unlogged**.
`run_core`'s arm is byte-identical to the scheduler standalone body —
`rebuild_selected_array()` + `move_objects(START)` + `move_objects(FLIP|ROTATELOCAL)` +
`move_objects(END)` — with **NO `push_undo()`/`draw()`** (`move_objects(START/END)` owns the undo push).
`FLIP|ROTATELOCAL` mirrors each object's x about its own origin (`ROTATION()` `xxtmp = 2*x0 - x`, pivot
= the wire's own `x1,y1` / inst `x0,y0`), so no pivot/`mousex_snap` seeding is needed.

**THREE standalone entry points, all funnelled once.** (1) the **scheduler branch** `else` (`return
perform_action("flip_in_place", argc, argv)`), reached by scripted `xschem flip_in_place`, the Edit
menu (`xschem.tcl:14137`), the context menu (`xschem.tcl:12164`), the `actions.csv`
`edit.horizontal_flip_in_place_selected_objects` row, and the command palette; (2) the **Alt-F key** →
`standalone_group_transform`'s single-object arm (`callback.c`); (3) the **verb-noun deferred apply** —
Alt-F on an empty selection arms `MENUSTARTROTATE` + `PENDING_TR_FLIP_IP`, and the next click
selects+applies it. Path (3) sat inside the shared `move_objects(START) … switch … move_objects(END)`
block; migrating it meant **pulling `PENDING_TR_FLIP_IP` OUT of the shared switch** (its own
`else if(t == PENDING_TR_FLIP_IP) perform_action(...)` after the ROTATE_IP one), because
`perform_action`→`run_core` owns its own START/END and must not nest inside the outer one. The other
four transform cases keep their exact bodies. In `standalone_group_transform` the single-object arm's
ROTATE and FLIP branches were **kept as two explicit `perform_action("rotate_in_place"|"flip_in_place",
0, NULL)` calls** rather than collapsed to one `perform_action(ternary_verb, …)` line — a ternary verb
string would erase both greppable self-log sites and break the grep guard's literal S1 count-2 rows.
No double-dispatch: keysym `f` has **zero rows in keybindings.csv**, so only the legacy `case 'f'`
`EQUAL_MODMASK` arm runs; the menu's `-accelerator Alt-F` is display-only.

**The read-only decision, same residual as atom 3.** The boundary's ONE `scheduler_readonly_reject`
covers the standalone verb from every path. The scheduler branch **drops** its top
`scheduler_readonly_reject(interp, "flip_in_place")` (S7 requires it gone); the Alt-F key **keeps** its
`readonly_block()` (it still guards the raw gesture arms + the arming path). The gesture arms are again
left without a readonly check, and again this is **unreachable-in-effect**: the raw mid-gesture FLIP is
preview only — `push_undo`/`set_modify(1)` fire only in `move_objects(END)`, and the only commit path,
`xschem move_objects end`, is itself refused under readonly at the `move_objects` command gate. So a
readonly-toggled-mid-gesture flip cannot persist or dirty the buffer. Atom 4 also **closes** the
cosmetic asymmetry atom 3 flagged (both `rotate_in_place` and `flip_in_place` now behave identically);
`flipv_in_place` remains the last un-migrated in-place transform (atom 5).

**Replay parity.** `flip_in_place` is a bare, RE-executable verb: a direct re-run re-executes AND
re-logs; a replay through the `replay_action_log` suppress seam re-executes but does NOT re-log. Stays
IN S2 CVERBS, OUT of S3.

**Grep guard (test_selflog_grep_guard.tcl).** The `flip_in_place` S1 scheduler row MOVED onto the
boundary row `return perform_action("flip_in_place", argc, argv);`, plus a callback.c row with count
**2** on `perform_action("flip_in_place", 0, NULL);` (the Alt-F single-object standalone + the verb-noun
apply). The **S7 BOUNDARY EXCLUSIVITY** block was extended to `flip_in_place`: it fails closed on a
scattered `log_action("xschem flip_in_place")` (scheduler OR callback) or a scattered
`scheduler_readonly_reject(..., "flip_in_place")`. The literal-`flip_in_place` regexes do not match the
un-migrated `flipv_in_place`, whose scheduler self-log row is untouched.

**Verified:** `test_perform_action_flip_in_place.tcl` (22 checks, full_audit logdir_tests): (a) +1 from
EACH of script / Alt-F key (keysym 102 state 8, single-object path) / menu wrapper; (b) read-only reject
from the scripted (TCL_ERROR, verb-named message) and Alt-F paths — no log, no mutation; (c) byte-exact
`xschem flip_in_place`; (d) replay re-executes with no re-log through the seam, vs a control unwrapped
`source` that re-executes AND re-logs; (e) **the wrinkle lock** — a `flip_in_place` issued with STARTMOVE
active is NOT logged (+0). The effect oracle is a lone **diagonal** wire `0 0 100 40`: a horizontal wire
flips to the mirror side but STAYS horizontal (an orientation oracle like atom 3's `is_vertical` cannot
see it), whereas the diagonal wire flips to `-100 40 0 0` — observable and deterministic from a fresh
state (verified empirically before writing the oracle). **Sabotage ×5** (each failing exactly its
checks, each restore byte-clean vs the atom-4 backup): (1) neutralise the boundary readonly gate → (b)
scripted read-only mutates + logs (4 fails); (2) neutralise the log site → (a) scripted/Alt-F +0 while
the menu wrapper's dedup safety-net still logs once (menu stays green); (3) bypass the boundary at the
Alt-F standalone (raw inline log) → grep **S1** count 2→1 + **S7** callback scattered-log both fail
closed; (4) re-add a scattered scheduler `log_action("xschem flip_in_place")` → grep **S7** fails closed;
(5) route the STARTMOVE arm through `perform_action` → case **(e)** fails (mid-gesture double-logs).
**Full-audit baseline diff:** every AFTER failure reconciled as pre-existing (the known
GUI/cadence/keybind/congestion set), with `test_perform_action_flip_in_place` added GREEN; every
change-adjacent test (`test_alt_transform_group_0116` = `standalone_group_transform`,
`test_rotate_prompt_object` = the MENUSTARTROTATE verb-noun handler, `test_gesture_end_log` +
`test_rotmove_drop_log` = the move-END counterpart, and the three `test_perform_action_*` siblings)
PASSES. **Adversarial review (refute panel, ultracode): verdict CLEAN, no must-fix** — the flagged
readonly-gate item was again dismissed as unreachable-in-effect (preview-only transform + readonly-gated
move-END, above).

## 25. Atom 5 outcome (2026-07-15): the FIFTH per-verb migration — the LAST in-place transform (`flipv_in_place`)

`flipv_in_place` now routes through the same `perform_action(verb, argc, argv)` boundary; `run_core`
grew exactly ONE arm; output stays byte-identical. Scope held as tight as atoms 1–4: one verb, no
global `core_log_action` registry, no rewrite of the existing `log_action` sites. Atom 5 completes the
in-place transform QUARTET — after it, `rotate_in_place` (atom 3), `flip_in_place` (atom 4), and
`flipv_in_place` are all on the boundary (`align`/`trim_wires` are atoms 2/1). Two structural
differences from atom 4 shaped the work:

**(1) SHAPE — three `move_objects` calls, not one.** A net vertical mirror = a 180° rotate + a
horizontal flip, so the standalone effect is `rebuild_selected_array()` + `move_objects(START)` +
`move_objects(ROTATE|ROTATELOCAL)` + `move_objects(ROTATE|ROTATELOCAL)` + `move_objects(FLIP|ROTATELOCAL)`
+ `move_objects(END)` — byte-identical to the old scheduler standalone `else` body, with **NO
`push_undo()`/`draw()`** (`move_objects(START/END)` owns the undo push). The ROTATE, ROTATE, FLIP
ORDER matters — a transposition (FLIP-first, or a dropped `ROTATELOCAL` bit) is the atom-5 copy-paste
hazard the review axis 3 targeted; the arm was copied verbatim from the pre-atom-5 standalone body.

**(2) ENTRY MAP — Alt-V is NOT `standalone_group_transform`.** That helper (issue 0116) serves only
Alt-R/Alt-F, splitting a multi-object connected-drag selection into a GROUP transform (shared pivot,
logs `rotate`/`flip x y`) vs a single-object in-place form. **Alt-V (`case 'v'` `EQUAL_MODMASK`,
callback.c) has NO group form** — its standalone apply is always the per-object in-place flip, so the
WHOLE standalone apply (`lastsel != 0`) crosses the boundary via one
`perform_action("flipv_in_place", 0, NULL)`. The `mx/my_double_save` seeded there previously was
immaterial (ROTATELOCAL pivots each object about its own origin) and was dropped.

**The wrinkle (identical to atoms 3/4): only the STANDALONE verb crosses the boundary.** The scheduler
`flipv_in_place` branch and the Alt-V key each have three arms: `if(STARTMOVE)` (raw `move_objects`
triple) / `else if(STARTCOPY)` (raw `copy_objects` triple) / `else <standalone>`. The during-move/
during-copy arms are mid-gesture sub-steps logged once at the move/copy END (issue 0069), so they stay
**raw and unlogged**; only the standalone `else` is wrapped. Routing a gesture arm through
`perform_action` would spuriously emit `xschem flipv_in_place` mid-drag and double-count the move-END
line (locked by test case (e) + sabotage 5). The gesture arms need no readonly gate — same finding as
atoms 3/4: the transform is preview-only (`push_undo`/`set_modify` fire only in `move_objects(END)`),
and the only commit path `xschem move_objects end` is itself readonly-refused at the `move_objects`
command gate, so a readonly-toggled-mid-gesture flip cannot persist or dirty the buffer.

**THREE standalone entry points, all funnelled once.** (1) the **scheduler branch** `else` (`return
perform_action("flipv_in_place", argc, argv)`), reached by scripted `xschem flipv_in_place`, the Edit
menu, the context menu, and the command palette; (2) the **Alt-V key** (`case 'v'` `EQUAL_MODMASK`
standalone apply); (3) the **verb-noun deferred apply** — Alt-V on an empty selection arms
`MENUSTART`/`MENUSTARTROTATE`/`PENDING_TR_FLIPV_IP`, and the next click selects+applies it; path (3)
was **pulled OUT of the shared `move_objects(START) … switch … move_objects(END)` block** into its own
`else if(t == PENDING_TR_FLIPV_IP) perform_action("flipv_in_place", 0, NULL)` (after the
`PENDING_TR_FLIP_IP` arm), because `perform_action`→`run_core` owns its own START/END and must not
nest. The remaining switch cases keep their exact bodies. No double-dispatch: keysym `v` (118) has
**zero rows in keybindings.csv**, so only the legacy `case 'v'` runs; the menu accelerator is display-
only. The two callback.c `perform_action("flipv_in_place", 0, NULL)` sites were kept as explicit
separate calls (S1 count 2), never a ternary verb string.

**The read-only decision, same residual as atoms 3/4.** The boundary's ONE `scheduler_readonly_reject`
covers the standalone verb from every path. The scheduler branch **drops** its top
`scheduler_readonly_reject(interp, "flipv_in_place")` (S7 requires it gone); the Alt-V key **keeps** its
`readonly_block()` (it still guards the raw gesture arms + the arming path).

**Replay parity.** `flipv_in_place` is a bare, RE-executable verb: a direct re-run re-executes AND
re-logs; a replay through the `replay_action_log` suppress seam re-executes but does NOT re-log. Stays
IN S2 CVERBS, OUT of S3.

**Grep guard (test_selflog_grep_guard.tcl).** The `flipv_in_place` S1 scheduler row MOVED from
`log_action("xschem flipv_in_place")` onto the boundary row `return perform_action("flipv_in_place",
argc, argv);`, plus a callback.c row with count **2** on `perform_action("flipv_in_place", 0, NULL);`
(the Alt-V standalone apply + the verb-noun apply). The **S7 BOUNDARY EXCLUSIVITY** block was extended
to `flipv_in_place`: it fails closed on a scattered `log_action("xschem flipv_in_place")` (scheduler OR
callback) or a scattered `scheduler_readonly_reject(..., "flipv_in_place")`. The literal
`flipv_in_place"` regex is distinct from `flip_in_place"`/`rotate_in_place"` (a `v` intervenes) — after
atom 5 all four in-place transforms are migrated and no stray `log_action` for any of them remains.

**Verified:** `test_perform_action_flipv_in_place.tcl` (22 checks, full_audit logdir_tests): (a) +1 from
EACH of script / Alt-V key (keysym 118 state 8, single object) / menu wrapper; (b) read-only reject from
the scripted (TCL_ERROR, verb-named message) and Alt-V paths — no log, no mutation; (c) byte-exact
`xschem flipv_in_place`; (d) replay re-executes with no re-log through the seam, vs a control unwrapped
`source` that re-executes AND re-logs; (e) **the wrinkle lock** — a `flipv_in_place` issued with
STARTMOVE active is NOT logged (+0). The effect oracle is a lone **diagonal** wire `0 0 100 40`: a
horizontal wire flips vertically to the mirror side but STAYS horizontal (an orientation oracle cannot
see it), whereas the diagonal wire flips to `0 0 100 -40` — observable, involutive, and distinct from
the horizontal flip `-100 40 0 0` (verified empirically before writing the oracle). **Sabotage ×5**
(each failing exactly its checks, each restore byte-clean vs the atom-5 scratchpad backup, NOT git
checkout): (1) neutralise the boundary readonly gate → (b) scripted read-only mutates + logs (4 fails);
(2) neutralise the log site → (a) scripted/Alt-V +0 while the menu wrapper's dedup safety-net still logs
once (menu stays green); (3) bypass the boundary at the Alt-V standalone (raw inline log) → grep **S1**
count 2→1 + **S7** callback scattered-log both fail closed; (4) re-add a scattered scheduler
`log_action("xschem flipv_in_place")` → grep **S7** fails closed; (5) route the STARTMOVE arm through
`perform_action` → case **(e)** fails (mid-gesture double-logs).
**Full-audit baseline diff clean:** the AFTER FAIL set (160 pass / 12 fail) reconciles to the pre-atom-5
BASELINE — every common failure is a known pre-existing WSLg-env fail (cadence duo, GUI set —
test_ciw/test_hi_descend/test_lib_manager_gui/test_reopen_readonly, test_lib_sweep, test_phase3_mints
g/G, test_wire_split W7, test_select_at, and test_selflog_output's six transform-KEY checks, which fire
identically on baseline including `key Alt-V logs flipv_in_place`). The only set-diff deltas are
reconciled: `test_selflog_grep_guard` fails ONLY on the reverted baseline source (the atom-5 guard test
correctly detects the migration absent — proving the guard is load-bearing; it passes on atom-5), and
`test_fluid_editing` (AFTER-only) passes 3/3 standalone on the atom-5 binary (the known FE8 WSLg-
congestion flake). `test_perform_action_flipv_in_place` is added GREEN and every change-adjacent test
(the four `test_perform_action_*` siblings, `test_rotate_prompt_object` = the MENUSTARTROTATE verb-noun
handler, `test_gesture_end_log` + `test_rotmove_drop_log` = the move-END counterpart,
`test_selflog_output`'s flipv self-log + readonly checks) PASSES. **Adversarial review (6-axis refute
panel, ultracode): verdict CLEAN, no must-fix** — bypass-entrypoint, readonly-gate, run_core arm
fidelity (the three-call order/opcode hazard), output-drift/replay, mid-gesture double-log, and
signature/build/C89 each found no failing scenario (all six `defect_found:false`, high confidence); the
readonly-gate item was again dismissed as unreachable-in-effect (preview-only transform + readonly-gated
move-END, above).

**Next atom:** the in-place transform quartet is DONE. The next candidate class is a **bare pivot-form
transform** (`flip`/`flipv`/`rotate x0 y0`) — same boundary shape but with two coordinate args threaded
through `run_core`/`perform_action` — or the global `core_log_action` registry (§4 Refactor A step 2,
rewriting all ~40 `log_action` sites), which remains its own future atom.

---

## 26. Refactor B ATOM 6 (2026-07-15): the SIXTH per-verb migration — the FIRST ARG-CARRYING verb (`rotate`, the pivot form)

`rotate` (the pivot form `xschem rotate x0 y0` — spin the SELECTION 90° about the shared point x0,y0)
now routes through the same `perform_action(verb, argc, argv)` boundary. Atom 6 is the class boundary:
atoms 1–5 migrated **bare no-arg** verbs (trim_wires/align + the in-place transform QUARTET
rotate_in_place/flip_in_place/flipv_in_place); `rotate` is the **FIRST ARG-CARRYING** verb, so its two
coordinate args must thread through BOTH halves of the boundary and reach the log site and the effect
**from the same source** or they diverge. That fidelity — not the effect — is the new risk.

**The new mechanism: `core_log_action`, the §4 "log at the core" registry SEED.** The bare-verb
boundary logged `log_action("xschem %s", verb)` inline in `perform_action`. A pivot verb needs a
per-verb log FORM, so the ONE log site now delegates:
`if(!actionlog_suppress) core_log_action(verb, argc, argv)`. `core_log_action` switches on the verb —
default `log_action("xschem %s", verb)` (bare verbs, **byte-identical** output) and `rotate` →
`log_action("xschem rotate %.16g %.16g", x0, y0)`. This is the minimal first form of the Refactor A
step-2 registry the audit anticipated; flip/flipv pivot forms add a branch here in their own atoms.
`run_core` grew a `rotate` arm that resolves the shared pivot from `argv[2]/argv[3]` (else the mouse
coords `xctx->mousex_snap`), seeds `mx_double_save/mousex_snap = x0,y0`, then
`rebuild_selected_array()` + `move_objects(START)` + `move_objects(ROTATE)` + `move_objects(END)` —
byte-identical to the old scheduler standalone `else` body. **NO `ROTATELOCAL`** (unlike
`rotate_in_place`): the pivot is the single shared point x0,y0, so the whole selection spins rigidly;
`ROTATELOCAL` would pivot each object about its own origin (a real bug). **NO `push_undo()`/`draw()`**
(`move_objects(START/END)` owns them).

**PIVOT FIDELITY — the atom-6-specific invariant.** `perform_action` runs the effect **then** the
log; `run_core` seeds `xctx->mousex_snap = x0` before returning, so `core_log_action`'s mouse-fallback
path reads back the exact pivot the effect used, and the argv path reads the same `argv[2]/argv[3]` in
both halves. The logged pivot therefore can never diverge from the applied pivot. Locked by test (f):
a non-trivial scripted pivot AND the Shift-R mouse pivot each replay their EXACT logged line onto a
fresh wire and must reproduce the live coords (a swapped/dropped pivot diverges — sabotage 2 + 6).

**FOUR standalone entry points, all funnelled — three carry a computed pivot.** (1) the **scheduler
branch** `else` → `return perform_action("rotate", argc, argv)` (bare `xschem rotate` from the Edit
menu / context menu / command palette resolves its pivot from the mouse inside `run_core`; a scripted
`xschem rotate x y` passes argv straight through — the latent pre-atom-6 order bug `double x0 =
xctx->mousex_snap;` **before** the `!xctx` guard is fixed by hoisting the resolution behind
`perform_action`'s guard). (2) the **Shift-R key** (callback.c `case 'R'`, keysym 82) — its standalone
`else` builds `av[4]` from `mousex/y_snap` → `perform_action("rotate", 4, av)`. (3) the **Alt-R GROUP
transform** (`standalone_group_transform`, issue 0116 — the multi-object rigid-body rotate about the
grid-snapped bbox centre px,py): the helper was **split** so `(what & ROTATE)` →
`perform_action("rotate", 4, av)` while the `(what == FLIP)` else-branch stays RAW (its own atom; kept
the `%s` log form so flip's grep-guard counts are untouched). NB the group arm's single-object arm
already routed `rotate_in_place` (atom 3) — the group `rotate x y` pivot arm is a **different** entry
point and now crosses too. (4) the **verb-noun deferred apply** (MENUSTARTROTATE `PENDING_TR_ROTATE`)
— **pulled OUT** of the shared `move_objects(START) … switch … move_objects(END)` block into its own
`else if(t == PENDING_TR_ROTATE)` (same surgery as atoms 3/4/5), because `run_core` owns its own
START/END and must not nest; the flip/flipv pivot cases stay in the shared block (their own atom).

**The mid-gesture split (identical to atoms 3/4/5).** The scheduler `rotate` branch and the Shift-R
key each have STARTMOVE / STARTCOPY / standalone arms. Only the standalone crosses the boundary; the
during-move/during-copy arms stay **raw and unlogged** (`move_objects`/`copy_objects(ROTATE)`) — they
are mid-gesture sub-steps logged once at the move/copy END as a `move_objects`/`copy_objects` drop line
(issue 0069, atom 13), **NOT** as `xschem rotate`. Routing a gesture arm through `perform_action` would
spuriously emit `xschem rotate` mid-drag and double-count the move-END line (locked by test (e) +
sabotage 5). The gesture arms need no readonly gate (preview-only: `push_undo`/`set_modify` fire only
in `move_objects(END)`, itself readonly-refused at the `move_objects` command gate).

**The read-only decision, same residual as atoms 3/4/5.** The scheduler branch **drops** its top
`scheduler_readonly_reject(interp, "rotate")` (S7 requires it gone); the boundary's ONE gate covers the
standalone from every path. The Shift-R key **keeps** its `readonly_block()` (it also guards the raw
gesture arms + the arming path).

**Replay parity.** `rotate` is a re-executable pivot verb (NOT a coordinate-STORE bypass like `wire x1
y1 x2 y2`): a direct re-run re-executes AND re-logs; a replay through the `replay_action_log` suppress
seam re-executes (the wire rotates about the recorded pivot) but does NOT re-log. Stays IN S2 CVERBS,
OUT of S3.

**Grep guard (test_selflog_grep_guard.tcl).** The ONE log site row changed from `log_action("xschem
%s", verb)` to `core_log_action(verb, argc, argv)`, plus two new S1 rows (the `core_log_action`
definition + its bare-verb `log_action("xschem %s", verb)` form). rotate's S1 rows MOVED onto boundary
rows: the scheduler `return perform_action("rotate", argc, argv)` and a callback.c row with count **3**
on `perform_action("rotate", 4, av)` (Shift-R + Alt-R group + verb-noun). The `log_action("xschem
rotate %` scheduler row is RE-POINTED to `core_log_action` (still count 1) and the callback.c rotate
log row is REMOVED (count 0). **S7 is SUBTLER than the bare verbs:** `core_log_action` legitimately
contains one `log_action("xschem rotate %...")`, so scheduler.c cannot forbid ALL of them — the S7
block asserts scheduler.c has **EXACTLY ONE** (a re-scattered branch log bumps to 2 → fails, sabotage
4) and callback.c has **ZERO** (sabotage 3). The literal `rotate %` (rotate+space+%) does NOT match
`rotate_in_place`; `"rotate"` (rotate+quote) does NOT match `"rotate_in_place"` — the two verbs are
counted independently.

**Verified:** `test_perform_action_rotate.tcl` (26 checks, full_audit logdir_tests): effect oracle a
lone **diagonal** wire `0 0 100 40` (cadsnap=20, select_all), `xschem rotate 0 0` → `-40 100 0 0`
(90° about the origin), pivot-SENSITIVE (`rotate 100 40` → `100 40 140 -60`) and involutive×4 — all
empirically confirmed before writing the oracle. (a) +1 from EACH of script / Shift-R key (keysym 82) /
menu wrapper (the Alt-R group + verb-noun apply are grep-guard-locked — they need a real arm-then-click
pixel); (b) read-only reject from the scripted (TCL_ERROR, verb-named message) + Shift-R paths — no
log, no mutation; (c) byte-exact `xschem rotate 0 0` (the `%.16g` pivot form — the NEW drift risk); (d)
replay re-executes with no re-log through the seam, vs a control unwrapped `source` that re-logs; (e)
**the wrinkle lock** — a rotate issued with STARTMOVE active is NOT logged (+0); (f) **pivot fidelity**
— the logged pivot reproduces the live effect for a scripted `rotate 40 20` AND the Shift-R mouse pivot.
**Sabotage ×6** (each failing exactly its checks, each restore byte-clean vs the atom-6 scratchpad
backup, NOT git checkout): (1) neutralise the boundary readonly gate → (b) scripted read-only mutates +
logs; (2) drop the pivot in `core_log_action` → (a)/(c)/(f) fail; (3) bypass the boundary at the
Shift-R standalone (raw inline log) → grep **S1** count 3→2 + **S7** callback scattered-log both fail
closed; (4) re-add a scattered scheduler `log_action("xschem rotate %...")` → **S7** scheduler
`== 1` fails closed (got 2) **without tripping on the legit `core_log_action` line** — proving the
`== 1` scoping; (5) route the STARTMOVE arm through `perform_action` → case **(e)** fails (mid-gesture
double-logs); (6) **the atom-6-specific coord check** — swap x0/y0 in the log → (f) pivot-fidelity
diverges (logged `20 40` vs effect `40 20`; replay lands the wrong coords).
**Full-audit baseline diff clean:** the AFTER set (153 pass / 16 fail / 1 timeout) reconciles to the
pre-atom-6 BASELINE (145 pass / 18 fail — the count wobble is WSLg-congestion pass/fail/skip flips, not
signal). The ONLY AFTER-only fail is `test_key_graph_context`, which **passes standalone on the atom-6
binary** (a 120 s WSLg timeout under the concurrent GUI load, not a regression). Every other AFTER fail
is a known pre-existing WSLg-env fail that also fails on the reverted baseline: the cadence duo
(test_cadence_descend_newwin_ro / test_cadence_drag), the GUI set (test_ciw / test_hi_descend /
test_lib_manager_gui / test_reopen_readonly), test_lib_sweep, test_phase3_mints (g/G), test_wire_split
(W7), test_select_at, test_launch_context, test_save_as_cellview, test_descend_untitled_preserve,
test_untitled_reuse, and test_selflog_output's six transform-KEY checks (Shift-F/R/V + Alt-F/R/V, which
fail identically on baseline). The BASELINE-only fails reconcile too: `test_selflog_grep_guard` fails
ONLY on the reverted baseline source (the atom-6 guard correctly detects the migration ABSENT — proving
it is load-bearing; it passes on atom-6), and test_verb_noun_copy_move / test_wire_vertex_grab are the
known congestion flakes (fail on the baseline run, pass on AFTER). Every change-adjacent test stays green: the five
`test_perform_action_*` siblings, `test_selflog_grep_guard`, `test_gesture_end_log` +
`test_rotmove_drop_log` (the move-END counterpart — its `move_objects`/`copy_objects` drop line is
untouched), `test_rotate_prompt_object` (the MENUSTARTROTATE verb-noun handler restructured here), and
`test_alt_transform_group_0116` (`standalone_group_transform`). `test_selflog_output`'s `rotate
self-logs with pivot` / `menu wrapper logs rotate once` / read-only checks PASS; its six transform-KEY
checks (Shift-F/R/V + Alt-F/R/V) FAIL **identically on the pre-atom-6 baseline** — the `.drw`/multi-
object-fixture pre-existing fails, NOT introduced here.
**Adversarial review (7-axis refute panel, ultracode): verdict CLEAN, no must-fix** (all 7 axes
`defect_found:false`, high confidence) — bypass-entrypoint (incl. the group arm + verb-noun), readonly
gate (incl. gesture arms after the split), pivot fidelity (argv/mouse/group-bbox pivots reaching the
log = the effect), output-drift/replay (pivot-form byte-exactness), move-END line unchanged, run_core
byte-identical (ROTATE not ROTATE|ROTATELOCAL, seed order, no push_undo — and the group-arm's added
`rebuild_selected_array` dismissed as benign, corroborated by test_alt_transform_group_0116), and
signature/build/C89 each found no failing scenario after a genuine refutation attempt.

**Next atom:** the arg-carrying design now exists, so the remaining pivot forms `flip x0 y0` / `flipv
x0 y0` are near-clones — each adds one `run_core` arm + one `core_log_action` branch + routes its
scheduler branch / Shift-key / group-FLIP arm / verb-noun case (the group FLIP arm + the verb-noun
flip/flipv cases were deliberately left raw here). The other open direction is the full
`core_log_action` registry (§4 Refactor A step 2, rewriting all ~40 `log_action` sites).

## 27. Refactor B ATOM 7 (2026-07-16): the SEVENTH per-verb migration — the SECOND arg-carrying verb (`flip`, the pivot form)

`flip` (the pivot form `xschem flip x0 y0` — horizontal-mirror the SELECTION about the vertical line
x=x0) now routes through the `perform_action(verb, argc, argv)` boundary. Atom 7 is a NEAR-CLONE of
atom 6 (rotate): the arg-carrying machinery — `core_log_action` + the `run_core` pivot arm — already
existed, so flip reuses it wholesale. It adds exactly one `run_core` arm + one `core_log_action` branch
and routes its four standalone entry points onto the boundary, mirroring rotate line-for-line.

**`run_core` grew a `flip` arm** (byte-identical to the old scheduler standalone `else` body): resolve
the shared pivot from `argv[2]/argv[3]` (else the mouse coords `mousex_snap/mousey_snap`),
`rebuild_selected_array()`, seed `mx_double_save/mousex_snap = x0` and `my_double_save/mousey_snap = y0`,
then `move_objects(START)` + `move_objects(FLIP)` + `move_objects(END)`. **NO `ROTATELOCAL`** (the pivot
is the single shared point, so the whole selection mirrors rigidly about x=x0, not each object about its
own origin — `ROTATELOCAL` would be a real bug). **NO `push_undo()`/`draw()`** (`move_objects(START/END)`
own them). **`core_log_action` grew a `flip` branch** → `log_action("xschem flip %.16g %.16g", x0, y0)`
with the SAME pivot resolution — so, with `perform_action`'s effect-then-log order and `run_core`'s
`mousex_snap = x0` seed, the logged pivot can never diverge from the applied one (the atom-6 pivot-
fidelity pattern, unchanged; move.c never writes `mousex_snap`, corroborated by the refute panel).

**FOUR standalone entry points, all funnelled** (mirroring rotate): (1) the **scheduler branch** `flip`
standalone `else` → `return perform_action("flip", argc, argv)`, dropping its own
`scheduler_readonly_reject(interp, "flip")` and its inline pivot/log; (2) the **Shift-F key** (callback.c
`case 'F'`, keysym 70) → builds `av[4]` from `mousex/y_snap` → `perform_action("flip", 4, av)`; (3) the
**Alt-F GROUP transform** (`standalone_group_transform`, issue 0116): the `else`/FLIP branch — deliberately
left RAW by atom 6 with a `%s` log form — now → `perform_action("flip", 4, av)` with the grid-snapped bbox
centre px,py; after atom 7 BOTH group arms (ROTATE + FLIP) cross the boundary; (4) the **verb-noun deferred
apply** (MENUSTARTROTATE `PENDING_TR_FLIP`) — **pulled OUT** of the shared `move_objects(START) … switch …
move_objects(END)` block into its own `else if(t == PENDING_TR_FLIP)`. After the pull, `PENDING_TR_FLIPV`
is the only case remaining in the shared switch (it stays until atom 8) and is made the `default`.

**The mid-gesture split (identical to atoms 3/4/5/6).** The scheduler `flip` branch and the Shift-F key
each keep STARTMOVE / STARTCOPY / standalone arms. Only the standalone crosses; the during-move/during-copy
arms stay **raw and unlogged** (`move_objects`/`copy_objects(FLIP)`) — logged once at the move/copy END as
a `move_objects`/`copy_objects` drop line (issue 0069, atom 13), never as `xschem flip`. Routing a gesture
arm through `perform_action` would spuriously emit `xschem flip` mid-drag and double-count the move-END line
(test (e) + sabotage 5). The gesture arms need no readonly gate (preview-only: for `what==FLIP`,
`move_objects` only toggles `move_flip` + a preview redraw; `push_undo`/`set_modify` fire only in the
`move_objects(END)` block, itself readonly-refused at the `move_objects` command gate). The scheduler branch
**drops** its top `scheduler_readonly_reject`; the Shift-F key **keeps** its `readonly_block()`.

**Grep guard.** flip's scheduler `log_action("xschem flip %` row STAYS count 1 — the pivot-format log MOVED
from the scheduler branch into `core_log_action` (net scheduler.c count unchanged). A new S1 row asserts the
scheduler `return perform_action("flip", argc, argv)` boundary arm; the callback.c `perform_action("flip",
4, av)` row is asserted count **3** (Shift-F + group FLIP + verb-noun); the callback.c `log_action("xschem
flip %` row is REMOVED (now 0). **S7 is the same subtlety as rotate:** `core_log_action` legitimately holds
one `log_action("xschem flip %...")`, so scheduler.c is asserted **EXACTLY ONE** (a re-scattered branch log
bumps to 2 → fails, sabotage 4) and callback.c **ZERO** (sabotage 3). The literal `flip %` (flip+space+%)
does NOT match `flipv %` (a `v` intervenes) nor `flip_in_place`; `"flip"` (flip+quote) does NOT match
`"flipv"`/`"flip_in_place"` — flip and flipv are counted independently, and flipv is UNTOUCHED (its scheduler
branch + Alt-V key + verb-noun `PENDING_TR_FLIPV` stay raw for atom 8).

**Verified:** `test_perform_action_flip.tcl` (27 checks, full_audit logdir_tests): effect oracle a lone
**diagonal** wire `0 0 100 40` (cadsnap=20, select_all), `xschem flip 0 0` → `-100 40 0 0` (horizontal mirror
about x=0), pivot-SENSITIVE (`flip 50 0` → `0 40 100 0`) and involutive×2 — all empirically confirmed before
writing the oracle. A DIAGONAL wire is the oracle because a horizontal wire flips to the mirror side but STAYS
horizontal (an orientation check would falsely pass), and `-100 40 0 0` is also DISTINCT from the vertical-
flip result (discriminates flip from flipv). (a) +1 from each of script / Shift-F key (keysym 70) / menu
wrapper (the Alt-F group + verb-noun apply are grep-guard-locked); (b) read-only reject from the scripted
(TCL_ERROR, verb-named message) + Shift-F paths — no log, no mutation; (c) byte-exact `xschem flip 0 0`; (d)
replay re-executes with no re-log through the seam, vs a control unwrapped `source` that re-logs; (e) the
wrinkle lock — a flip issued with STARTMOVE active is NOT logged (+0); (f) pivot fidelity — the logged pivot
reproduces the live effect for a scripted `flip 40 20` AND the Shift-F mouse pivot.
**Sabotage ×6** (each failing exactly its checks, each restore byte-clean vs the atom-7 scratchpad backup):
(1) neutralise the boundary readonly gate → (b) scripted read-only mutates + logs; (2) drop the pivot in
`core_log_action` (flip falls to the bare else) → (a)/(c)/(f) fail; (3) bypass the boundary at the Shift-F
standalone (raw inline log) → grep **S1** `perform_action("flip",4,av)` 3→2 + **S7** callback scattered-log
both fail closed; (4) re-add a scattered scheduler `log_action("xschem flip %...")` → **S7** scheduler `== 1`
fails (got 2) WITHOUT tripping the legit `core_log_action` line; (5) route the STARTMOVE arm through
`perform_action` → case (e) fails (mid-gesture double-logs); (6) swap x0/y0 in the log → (f) pivot-fidelity
diverges (logged `20 40` vs effect `40 20`; replay lands the wrong coords).
**Full-audit baseline diff clean:** the AFTER set (143 pass / 19 fail / 1 timeout / 11 skip) reconciles to
the pre-atom-7 BASELINE (159 pass / 15 fail / 0 skip) — the count wobble is WSLg congestion (the AFTER run's
11 skips vs baseline 0 = it ran under the concurrent adversarial panel + baseline rebuild). The sole
BASELINE-only fail is `test_selflog_grep_guard` (the guard correctly detects the migration ABSENT on baseline
— proving it is load-bearing; it passes on atom-7). The six AFTER-only fails (`test_altf5_ciw`,
`test_deselect_mode`, `test_fluid_editing`, `test_lib_manager_ctx`, `test_verb_noun_copy_move`,
`test_wire_complete_with_selection`) ALL pass STANDALONE on the atom-7 binary = congestion/ordering flakes.
Every other AFTER fail is a known pre-existing WSLg-env fail common to both sets (the cadence duo, the GUI set
test_ciw / test_hi_descend / test_lib_manager_gui / test_reopen_readonly / test_altf5_ciw, test_lib_sweep,
test_phase3_mints g/G, test_wire_split, test_select_at, test_save_as_cellview, test_descend_untitled_preserve,
test_untitled_reuse) and `test_selflog_output`'s six transform-KEY checks (Shift-F/R/V + Alt-F/R/V), which
fail **IDENTICALLY on baseline** — its NON-key checks incl. `flip self-logs with pivot` PASS on atom-7,
confirming the migrated Shift-F flip keeps its pivot-form self-log. Every change-adjacent test stays green:
the six `test_perform_action_*` siblings, `test_selflog_grep_guard`, `test_gesture_end_log` +
`test_rotmove_drop_log` (the move-END counterpart, its `move_objects`/`copy_objects` drop line untouched),
`test_rotate_prompt_object` (verb-noun handler restructured here) and `test_alt_transform_group_0116`
(`standalone_group_transform`). ZERO new deterministic failures.
**Adversarial review (7-axis refute panel, ultracode): verdict CLEAN, no must-fix** (all 7 axes
`defect_found:false`, high confidence) — entry-point completeness (incl. the newly-routed group FLIP arm +
verb-noun `PENDING_TR_FLIP`), readonly gate (incl. the mid-gesture arms proven preview-only), pivot fidelity
across all four entry points, output-drift + flip/flipv disambiguation (flipv untouched), the move-END line
unchanged (move.c untouched), `run_core` arm fidelity (FLIP not FLIP|ROTATELOCAL, seed-before-START, no
push_undo) and signature/build/C89 each found no failing scenario after a genuine refutation. The one
non-blocking doc nit it raised (the `run_core` header example not naming flip) was fixed.

**Next atom:** the LAST pivot form `flipv x0 y0` (atom 8, the mirror of atom 7 exactly as atom 5 mirrored
atom 4): one `run_core` arm (the THREE-`move_objects` vertical-mirror shape ROTATE + ROTATE + FLIP) + one
`core_log_action` branch + routing its scheduler branch / Alt-V key / verb-noun `PENDING_TR_FLIPV` (the last
case in the shared switch). After atom 8 the whole transform sextet is on the boundary. The other open
direction remains the full `core_log_action` registry (§4 Refactor A step 2, rewriting all ~40 `log_action`
sites).

## 28. Refactor B ATOM 8 (2026-07-16): the EIGHTH per-verb migration — the THIRD and LAST arg-carrying pivot verb (`flipv`, the pivot form)

`flipv` (the pivot form `xschem flipv x0 y0` — vertical-mirror the SELECTION about the horizontal line
y=y0) now routes through the `perform_action(verb, argc, argv)` boundary. Atom 8 is the MIRROR of atom 7
(flip) exactly as atom 5 (flipv_in_place) mirrored atom 4 (flip_in_place): the arg-carrying machinery —
`core_log_action` + the `run_core` pivot arm — already existed (atom 6), so flipv reuses it wholesale,
adding one `run_core` arm + one `core_log_action` branch and routing its **three** standalone entry
points onto the boundary. **After atom 8 the whole transform SEXTET (rotate/flip/flipv × pivot + in-place)
is on the boundary**, and the shared verb-noun `move_objects(START) … switch … move_objects(END)` block
is GONE.

**`run_core` grew a `flipv` arm** (byte-identical to the old scheduler standalone `else` body): resolve
the shared pivot from `argv[2]/argv[3]` (else the mouse coords), `rebuild_selected_array()`, seed
`mx_double_save/mousex_snap = x0` and `my_double_save/mousey_snap = y0`, then **THREE** `move_objects`
transform calls in the order `move_objects(ROTATE)` + `move_objects(ROTATE)` + `move_objects(FLIP)` (a net
vertical mirror = 180° rotate + horizontal flip), NOT one. **NO `ROTATELOCAL`** (unlike `flipv_in_place`,
atom 5): the pivot is the single shared point x0,y0, so the whole selection mirrors rigidly about y=y0,
not each object about its own origin (`ROTATELOCAL` would be a real bug). The **ROTATE, ROTATE, FLIP
order** matters — a transpose or a dropped call is the atom-5-class copy-paste hazard (sabotage 6a
reproduces it: dropping one ROTATE turns the oracle `0 0 100 -40` into `-40 -100 0 0`). **NO
`push_undo()`/`draw()`** (`move_objects(START/END)` own them). **`core_log_action` grew a `flipv` branch**
→ `log_action("xschem flipv %.16g %.16g", x0, y0)` with the SAME pivot resolution — so, with
`perform_action`'s effect-then-log order and `run_core`'s `mousex_snap = x0` seed, the logged pivot can
never diverge from the applied one (the atom-6 pivot-fidelity pattern; sabotage 6b swaps x0/y0 in the log
and case (f) diverges).

**THREE standalone entry points, NOT four — flipv has NO group form** (like `flipv_in_place`, atom 5;
unlike rotate/flip): (1) the **scheduler branch** `flipv` standalone `else` → `return
perform_action("flipv", argc, argv)`, dropping its own `scheduler_readonly_reject(interp, "flipv")` and
inline pivot/log — reached by scripted `xschem flipv [x y]`, the Edit menu, the context menu and the
command palette; (2) the **Shift-V key** (callback.c `case 'V'`, `rstate==0`, keysym 86) standalone apply
→ builds `av[4]` from `mousex/y_snap` → `perform_action("flipv", 4, av)`; (3) the **verb-noun deferred
apply** (MENUSTARTROTATE `PENDING_TR_FLIPV`) — **pulled OUT** of the shared `move_objects(START) … switch
… move_objects(END)` block into its own `else if(t == PENDING_TR_FLIPV)` arm. Because `PENDING_TR_FLIPV`
was the LAST case in that shared block, after the pull the block is **empty and REMOVED**: the whole
verb-noun transform chain is now **six `else if` boundary arms**, one `perform_action` each
(rotate_in_place/flip_in_place/flipv_in_place/rotate/flip/flipv). An unexpected `t` simply no-ops off the
end of the chain — the chain is armed only for those six `PENDING_TR_*` values, so **no spurious
`default` catch-all was re-added** (this is the structural end-state cleanup unique to the last pivot
atom). callback.c therefore carries **TWO** `perform_action("flipv", 4, av)` sites (Shift-V + verb-noun),
not three.

**An anchor-drift correction (the §6-class landmine).** The session prompt named the pivot-flipv key
"Alt-V (case 'v' EQUAL_MODMASK, keysym 118)". Verified in source, that is FALSE: `case 'v'`+`EQUAL_MODMASK`
(Alt-V, keysym 118, state 8) is **`flipv_in_place`** (atom 5, the per-object ROTATELOCAL form); the PIVOT
flipv is **Shift-V** = `case 'V'`, `rstate==0` (keysym 86, state 1, since `rstate` strips `ShiftMask`,
callback.c) — the exact mirror of Shift-F/Shift-R (the pivot flip/rotate keys, atoms 6/7). The migration
and the test drive **Shift-V (keysym 86, state 1)**, not Alt-V. Confirmed by keysym→char mapping (the
callback passes the ASCII code of the resulting char: 86='V', 118='v') and by keybindings.csv having
**zero** rows for keysyms 70/82/86/102/114/118 relevant here (no registry double-dispatch — same as atom
5's finding for `v`).

**The mid-gesture split (identical to atoms 3/4/5/6/7).** The scheduler `flipv` branch and the Shift-V
key each keep STARTMOVE / STARTCOPY / standalone arms. Only the standalone crosses; the during-move/
during-copy arms stay **raw and unlogged** (`move_objects`/`copy_objects(ROTATE,ROTATE,FLIP)`) — logged
once at the move/copy END as a `move_objects`/`copy_objects` drop line (issue 0069, atom 13), never as
`xschem flipv`. Routing a gesture arm through `perform_action` would spuriously emit `xschem flipv`
mid-drag and double-count the move-END line (test (e) + sabotage 5). The gesture arms need no readonly
gate (preview-only: `push_undo`/`set_modify` fire only in `move_objects(END)`, itself readonly-refused at
the `move_objects` command gate). The scheduler branch **drops** its top `scheduler_readonly_reject`; the
Shift-V key **keeps** its `readonly_block()`. move.c is UNTOUCHED.

**Grep guard.** flipv's scheduler `log_action("xschem flipv %` row STAYS count 1 — the pivot-format log
MOVED from the scheduler branch into `core_log_action` (both live in scheduler.c, net count unchanged;
the row comment updated from "flipv branch (still raw — atom 8)" to "now lives in core_log_action"). A new
S1 row asserts the scheduler `return perform_action("flipv", argc, argv)` boundary arm; a new callback.c
row asserts `perform_action("flipv", 4, av)` count **2** (Shift-V + verb-noun — NOT 3, no group arm); the
callback.c `log_action("xschem flipv %` row is REMOVED (now 0). **S7 is the same subtlety as rotate/flip:**
`core_log_action` legitimately holds one `log_action("xschem flipv %...")`, so scheduler.c is asserted
**EXACTLY ONE** (a re-scattered branch log bumps to 2 → fails, sabotage 4) and callback.c **ZERO**
(sabotage 3). The literal `flipv %` (flipv+space+%) does NOT match `flip %` (a `v` intervenes) nor
`flipv_in_place`; `"flipv"` does NOT match `"flip"`/`"flipv_in_place"`. Two new **flip-unperturbed** guards
assert flip's counts (scheduler `flip %` == 1, callback == 0) stay EXACTLY as atom 7 left them. flipv stays
IN S2 CVERBS, OUT of S3.

**Verified:** `test_perform_action_flipv.tcl` (29 checks, full_audit logdir_tests): effect oracle a lone
**diagonal** wire `0 0 100 40` (cadsnap=20, select_all), `xschem flipv 0 0` → `0 0 100 -40` (vertical
mirror about y=0), pivot-SENSITIVE (`flipv 0 50` → `0 100 100 60`), involutive×2, and DISTINCT from
`flip 0 0` = `-100 40 0 0` (discriminates flipv from flip) — all empirically confirmed on the current
binary before writing the oracle. (a) +1 from each of script / Shift-V key (keysym 86 state 1) / menu
wrapper (the verb-noun apply is grep-guard-locked); (b) read-only reject from the scripted (TCL_ERROR,
verb-named message) + Shift-V paths — no log, no mutation; (c) byte-exact `xschem flipv 0 0`; (d) replay
re-executes with no re-log through the seam, vs a control unwrapped `source` that re-logs; (e) the wrinkle
lock — a flipv issued with STARTMOVE active is NOT logged (+0); (f) pivot fidelity — the logged pivot
reproduces the live effect for a scripted `flipv 40 20` AND the Shift-V mouse pivot.
**Sabotage ×7** (each failing exactly its checks, each restore byte-clean vs the atom-8 scratchpad
backup, NOT git checkout): (1) neutralise the boundary readonly gate → (b) scripted read-only mutates +
logs (4 fails); (2) drop the pivot in `core_log_action` (flipv falls to the bare else → `xschem flipv`
with no pivot, which the `xschem flipv *` glob misses) → (a)/(c)/(d-control)/(f) fail; (3) bypass the
boundary at the Shift-V standalone (raw inline log) → grep **S1** `perform_action("flipv",4,av)` 2→1 +
**S7** callback scattered-log both fail closed; (4) re-add a scattered scheduler `log_action("xschem flipv
%...")` → **S7** scheduler `== 1` fails (got 2) WITHOUT tripping the legit `core_log_action` line and
WITHOUT perturbing flip; (5) route the STARTMOVE arm through `perform_action` → case (e) fails (mid-gesture
double-logs); (6a) drop one ROTATE from the run_core arm → the oracle mirror check fails (`-40 -100 0 0`,
the atom-5-class shape guard); (6b) swap x0/y0 in the log → (f) pivot-fidelity diverges (logged
`flipv 20 40` vs effect `40 20`).
**Full-audit baseline diff clean:** the AFTER FAIL set reconciles to the pre-atom-8 BASELINE — every
common failure is a known pre-existing WSLg-env fail (the cadence duo, the GUI set test_ciw / test_hi_descend /
test_lib_manager_gui / test_reopen_readonly / test_altf5_ciw / test_lib_manager_ctx, test_lib_sweep,
test_phase3_mints g/G, test_wire_split, test_select_at, test_save_as_cellview, test_descend_untitled_preserve,
test_untitled_reuse, test_deselect_mode, test_wire_complete_with_selection, test_fluid_editing FE8, and
`test_selflog_output`'s six transform-KEY checks Shift-F/R/V + Alt-F/R/V, which fail IDENTICALLY on baseline
— its NON-key checks incl. `flipv self-logs with pivot` + `read-only rejects flipv` PASS on atom-8,
confirming the migrated Shift-V flipv keeps its pivot-form self-log). `test_selflog_grep_guard` fails ONLY on
the reverted baseline (it detects the migration ABSENT = load-bearing; passes on atom-8). Every change-adjacent
test stays green: the seven `test_perform_action_*` siblings, `test_selflog_grep_guard`, `test_gesture_end_log`
+ `test_rotmove_drop_log` (the move-END counterpart untouched), `test_rotate_prompt_object` (the verb-noun
handler whose shared block was removed here) and `test_alt_transform_group_0116`. ZERO new deterministic
failures.
**Adversarial review (7-axis refute panel, ultracode, against a source snapshot):** entry-point
completeness (incl. the Shift-V standalone + verb-noun `PENDING_TR_FLIPV` + the removed shared-block cleanup
— no case left unreachable/mis-handled), readonly gate (incl. the mid-gesture arms proven preview-only),
pivot fidelity across all entry points, output-drift + flip/flipv/flipv_in_place disambiguation (flip counts
unchanged), the move-END line unchanged (move.c untouched), `run_core` arm fidelity (ROTATE,ROTATE,FLIP not
transposed, NO ROTATELOCAL, seed-before-START, no push_undo) and signature/build/C89.

**Next atom:** the transform sextet is DONE. The remaining Refactor B direction is the full
`core_log_action` registry (§4 Refactor A step 2, rewriting all ~40 `log_action` sites), migrating the
non-transform mutating verbs onto the boundary one by one.

---

*Prepared 2026-07-14, `fluid-editing`. §1–5 analysis only — no code changed. §6 added after
atom 3 landed; §7 after atom 4; §8 after atom 5; §9 after atom 6; §10 after atom 7; §11 after
atom 8; §12 after atom 9; §13 after atom 10; §14 after atom 11;
§15 after atom 12; §16 after atom 13; §17 after atom 14; §18 after atom 15; §19 after atom 16;
§20 after the Refactor B foundation (actionlog_suppress setter + the replay/composite seams);
§21 after the FIRST per-verb migration onto perform_action (trim_wires); §22 after the SECOND
(align); §23 after the THIRD (rotate_in_place — the first with a mid-gesture split); §24 after the
FOURTH (flip_in_place — the mirror of rotate_in_place); §25 after the FIFTH (flipv_in_place — the last
in-place transform; the in-place quartet rotate/flip/flipv is now fully on the boundary); §26 after the
SIXTH (rotate — the FIRST ARG-CARRYING verb, the pivot form `rotate x0 y0`; introduces core_log_action,
the per-verb log-form registry seed); §27 after the SEVENTH (flip — the SECOND arg-carrying verb, the pivot
form `flip x0 y0`, a near-clone of rotate reusing core_log_action + the run_core pivot arm); §28 after the
EIGHTH (flipv — the THIRD and LAST arg-carrying pivot verb, the pivot form `flipv x0 y0`, the mirror of
flip; the transform sextet rotate/flip/flipv × pivot + in-place is now fully on the boundary and the shared
verb-noun START/switch/END block is gone).
Coverage verified in source at HEAD by a 14-way parallel read; do not trust the status table
without re-checking the cited `file:line` anchors, which drift as the tree moves.*
