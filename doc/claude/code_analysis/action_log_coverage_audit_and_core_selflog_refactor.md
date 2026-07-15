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

---

*Prepared 2026-07-14, `fluid-editing`. §1–5 analysis only — no code changed. §6 added after
atom 3 landed; §7 after atom 4; §8 after atom 5; §9 after atom 6; §10 after atom 7; §11 after
atom 8; §12 after atom 9; §13 after atom 10; §14 after atom 11;
§15 after atom 12. Coverage verified in source at
HEAD by a 14-way parallel read; do not trust the status table without re-checking the cited
`file:line` anchors, which drift as the tree moves.*
