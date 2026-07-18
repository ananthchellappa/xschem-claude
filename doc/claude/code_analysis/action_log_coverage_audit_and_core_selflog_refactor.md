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

## 29. Refactor B ATOM 9 (2026-07-16): the NINTH per-verb migration — the FIRST NON-transform verb (`break_wires`)

`break_wires` (the wire-surgery verb: `xschem break_wires` breaks wires at the pins of the SELECTED
instances; `xschem break_wires 1` breaks-AND-removes wire pieces that end up entirely inside those
instances) now routes through the `perform_action(verb, argc, argv)` boundary. Atom 9 is the class
boundary AFTER the transform sextet: atoms 1–8 were trim_wires/align + the six transforms (rotate/flip/
flipv × pivot + in-place). break_wires is the **FIRST NON-transform verb**, and it is deliberately the
CLEANEST next atom — the wire-surgery **SIBLING of trim_wires** (atom 1, the template): a bare verb at
the entry level, **NO mid-gesture split** (it is not a transform, so there are no STARTMOVE/STARTCOPY
arms and none of the atom-3..8 gesture wrinkle), and its arg is a **FLAG (0/1), not a coordinate pivot**,
so it is SIMPLER than the pivot atoms 6/7/8 (one flag to thread, no `snprintf` of a mouse coord).

**`run_core` grew a `break_wires` arm** (byte-identical to the old scheduler standalone branch effect):
`int remove = 0; if(argc > 2) remove = atoi(argv[2]); break_wires_at_pins(remove);`. **NO `push_undo()`/
`draw()`** — unlike the earlier atoms whose transform effect owns its undo inside `move_objects(START/
END)`, here the core `break_wires_at_pins()` (check.c:548) OWNS its own undo directly: it calls
`xctx->push_undo()` on first mutation (check.c:575/611/654) and `set_modify(1)` + `draw()` itself
(check.c:668–678). Adding a `push_undo()` in the arm would DOUBLE-push (the atom-1 no-double-push rule,
re-confirmed here). **`core_log_action` grew a `break_wires` branch** that reads `remove` from `argv[2]`
IDENTICALLY to `run_core` and canonicalizes to the two forms the UI emits: `remove` →
`log_action("xschem break_wires 1")`, else `log_action("xschem break_wires")`. `break_wires_at_pins()`
reads `remove` as a BOOLEAN, so any non-zero `argv[2]` (`xschem break_wires 5`) logs the canonical `1`
form — a deterministic, faithful replay.

**FLAG FIDELITY — the atom-9 analogue of pivot fidelity.** The arg-carrying risk is that the flag reaching
the LOG diverges from the flag the EFFECT used. Both halves read `remove` from the SAME `argv[2]` with the
SAME `if(argc > 2)` test, so they cannot diverge — the log form always matches the applied effect (locked
by test (e) + sabotage 5, which swaps `break_wires_at_pins(!remove)` and makes the effect diverge from the
still-correct log). Unlike the pivot verbs there is no mouse-coord fallback to seed, so the effect-then-log
order is not load-bearing here (the flag lives in `argv`, not in `xctx`).

**THE 1:1 TEST — `break_wires_at_pins` IS the verb; `break_wires_at_point` is a SEPARATE gesture.** Grepping
every caller of `break_wires_at_pins()` confirms it is reached ONLY by this verb's own entry points (the
scheduler branch, now via `run_core`, + the two keys, now via `perform_action`). So it is 1:1 with the verb
and the boundary/core_log_action is the correct single log site (contrast trim_wires atom 1, whose shared
`trim_wires()` C fn is ALSO an internal sub-step of align/move-END autotrim and stays below the boundary).
Two DISTINCT functions must NOT be confused with it and are UNTOUCHED: `break_wires_at_point()` (check.c:501
— the mouse-position **Alt-Right `wire_cut` gesture**, a separate verb+gesture, 0069 class) and
`break_wires_at_attach_points()` (check.c:693 — the load/save auto-split). The literal regex
`break_wires_at_pins` distinguishes it from both (an `_` follows). Test (e) drives the `wire_cut` gesture
(`xschem wire_cut 40 0`) and locks that it emits ZERO `xschem break_wires` lines — the separate gesture
stays off the boundary.

**THREE standalone entry points, all funnelled — NO group form, NO mid-gesture split.** (1) the **scheduler
branch** → `return perform_action("break_wires", argc, argv)`, dropping its own `!xctx` guard (the boundary
owns it), its `scheduler_readonly_reject(interp, "break_wires")`, and its inline effect + dual log; reached
by scripted `xschem break_wires [1]`, the Edit/Tools menu, the toolbar and the command palette. (2) the
**`!` key** (callback.c `case '!'`, keysym 33 state 0) → bare → `perform_action("break_wires", 0, NULL)`
(argc≤2 ⇒ `remove` stays 0 in both halves). (3) the **Ctrl-! key** (`case '!'` + `ControlMask`, keysym 33
state 4) → remove → builds `av[3]={"xschem","break_wires","1"}` → `perform_action("break_wires", 3, av)`.
No verb-noun deferred apply, no group form (break_wires is not a transform). Confirmed keysym 33 (`!`) has
ZERO rows in keybindings.csv — no registry double-dispatch, only the legacy `case '!'` runs (like `&` for
trim_wires).

**The read-only decision — the keys KEEP `readonly_block()`, unlike trim_wires atom 1.** The scheduler
branch DROPS its `scheduler_readonly_reject`; the boundary's ONE gate covers the scheduler/menu/script path.
The `!`/Ctrl-! keys KEEP their `semaphore>=2` re-entrancy guard AND their `readonly_block()` (guarding
themselves first, like the transform keys atoms 3–8) — so on a read-only cell the key is blocked at
`readonly_block()` before ever reaching the boundary. This is a DELIBERATE difference from trim_wires atom
1, which dropped `&`'s `readonly_block()` to unify onto the boundary's CIW-note (changing a modal to a CIW
note): break_wires keeps the keys' existing feedback and matches the more-recent transform-key convention,
at the cost of the boundary gate being redundant on the key path. `readonly_block()` is headless-safe (its
`tk_messageBox` only fires when `has_x`; the test stubs it defensively anyway). The S7 grep guard asserts
`scheduler_readonly_reject(...,"break_wires") == 0` in scheduler.c — `readonly_block()` (a different fn, no
`break_wires` literal) does not perturb that count.

**Replay parity.** `break_wires [1]` is a re-executable verb (NOT a coordinate-STORE bypass like
`wire x1 y1 x2 y2`): a direct re-run re-executes AND re-logs; a replay through the `replay_action_log`
suppress seam re-executes (wires split / split-and-remove) but does NOT re-log. Stays IN S2 CVERBS, OUT of
S3 (its log lives in core_log_action reached from the branch, not in a shared core the branch must stay
silent for).

**Grep guard (test_selflog_grep_guard.tcl).** break_wires's two scheduler `log_action("xschem break_wires
[1]")` rows STAY (net scheduler.c count unchanged) — the two pivot-less log forms MOVED from the branch
into `core_log_action` (both still in scheduler.c); the row comments are re-pointed. A new S1 row asserts
the scheduler `return perform_action("break_wires", argc, argv)` boundary arm; the TWO callback.c
`log_action("xschem break_wires[ 1]")` rows are REMOVED and replaced with S1 rows for
`perform_action("break_wires", 0, NULL)` (`!` key) and `perform_action("break_wires", 3, av)` (Ctrl-! key).
**S7 is SUBTLER — like rotate/flip/flipv but with TWO forms:** `core_log_action` legitimately holds BOTH
break_wires log lines, so scheduler.c is asserted **EXACTLY TWO** total, **EXACTLY ONE of each form**, with
the branch carrying none and callback.c ZERO. The literals `break_wires 1"` (space+1 before the quote) and
`break_wires")` (quote then paren) are MUTUALLY EXCLUSIVE and counted independently — a re-scattered branch
log of EITHER form fails closed (sabotage 4 bumps the bare count to 2 and the total to 3 WITHOUT tripping
the remove-form count) — and neither matches `break_wires_at_pins`/`_at_point`/`_at_attach_points`.

**Verified:** `test_perform_action_break_wires.tcl` (29 checks, full_audit logdir_tests): effect oracle a
resistor at the origin (pins 0,−30 & 0,30) + a wire `0 -60 0 60` spanning both pins — `xschem break_wires`
SPLITS at both pins into THREE wires (middle span `{0 -30 0 30}` KEPT), `xschem break_wires 1` splits AND
removes the middle span (entirely inside the resistor, touching both pins) → TWO wires. Wire-count 3-vs-2
AND the presence/absence of `{0 -30 0 30}` distinguish the two forms cleanly — determined empirically on the
pre-migration binary. (a) +1 from EACH of script bare / script `1` / `!` key (keysym 33 state 0) / Ctrl-!
key (state 4) / menu wrapper; (b) read-only reject from the scripted (TCL_ERROR, verb-named message) BOTH
forms + the `!`/Ctrl-! key paths — no log, no mutation; (c) byte-exact `xschem break_wires` AND
`xschem break_wires 1` (the FLAG survives the boundary); (d) replay re-executes with no re-log through the
seam (both forms) vs a control unwrapped `source` that re-logs; (e) the FLAG threads — `break_wires 1`
removes and logs the remove form NOT the bare, `break_wires` splits and logs the bare NOT the remove — plus
the SEPARATE `wire_cut` gesture emits NO `xschem break_wires`. **Sabotage ×5** (each failing exactly its
checks, each restore byte-clean vs the atom-9 scratchpad backup, NOT git checkout): (1) neutralise the
boundary readonly gate → the (b) SCRIPTED read-only checks fail (mutation + log leak; the KEY read-only
checks still pass, blocked at their own `readonly_block()` — proving the key guards itself while the
boundary gates the scripted path); (2) drop the `break_wires` branch in `core_log_action` (falls to the
bare else) → the `1` form's (a)/(c)/(e) logging checks fail, effect intact; (3) bypass the boundary at the
`!` key (raw inline `break_wires_at_pins`+log) → grep S1 boundary-count 1→0 + S7 callback scattered-log
0→1 fail closed WHILE the runtime .tcl still passes (proving the grep guard is the load-bearing lock for
boundary exclusivity); (4) re-add a scattered scheduler branch `log_action("xschem break_wires")` → S7
scheduler EXACTLY-ONE-bare (got 2) + EXACTLY-TWO-total (got 3) fail closed WITHOUT tripping the remove-form
count; (5) swap the remove flag in `run_core` (`break_wires_at_pins(!remove)`) → the (d)/(e) EFFECT oracles
diverge (bare removes, remove splits) while the LOG stays correct — the effect/log divergence caught by the
effect checks. The change-adjacent siblings stay green: the eight `test_perform_action_*` + the grep guard;
`test_selflog_output`'s break_wires + `!`/Ctrl-! key checks pass (its only FAILs are the pre-existing six
transform-KEY checks that fail identically on baseline).

**Full-audit baseline diff clean.** The AFTER run (161 pass / 15 fail / 0 crash / 0 skip) has 14 of its 15
failures on the standing WSLg-env list — the cadence duo (test_cadence_descend_newwin_ro /
test_cadence_drag), the GUI set (test_ciw / test_hi_descend / test_lib_manager_gui / test_reopen_readonly),
test_lib_sweep, test_phase3_mints (g/G snap), test_select_at, test_save_as_cellview,
test_descend_untitled_preserve, test_untitled_reuse, test_wire_split (W7), and test_selflog_output's six
transform-KEY checks (Shift/Alt-F/R/V, which fail identically on baseline). The 15th, `test_fluid_editing`,
is the sole AFTER-only fail and PASSES STANDALONE on the atom-9 binary (26 checks) — a congestion flake (it
ran under the concurrent baseline rebuild + adversarial panel), not a regression. The new
`test_perform_action_break_wires`, the `test_selflog_grep_guard`, and all eight sibling
`test_perform_action_*` are ABSENT from the AFTER fail set = GREEN. The BASELINE run (the 2 C files reverted
to HEAD/atom-8, rebuilt; 159 pass / 16 fail / 1 timeout) reconciles: its BASELINE-only fails are
`test_selflog_grep_guard` (the guard correctly detects the migration ABSENT on the reverted source, proving
it is load-bearing — it passes on atom-9) plus two more congestion flakes (test_pin_name_size_win /
test_pristine_untitled_basename, both pass on atom-9). ZERO new deterministic failures.

**Adversarial review (6-axis refute panel, Workflow, ultracode, against a source snapshot): verdict CLEAN,
zero confirmed defects** — entry-point completeness (all three paths funnel through `perform_action` once,
no double-log, `break_wires_at_point`/`wire_cut` untouched, `break_wires_at_pins` 1:1), readonly gate (no
miss, no over-reject, no double-message, headless-safe), FLAG fidelity (log flag == effect flag for all
forms and entry points; the `(0, NULL)` path never dereferences `argv[2]` because both halves guard
`if(argc > 2)`), output-drift/replay/disambiguation (byte-exact literals, regexes sound, IN S2 / OUT S3),
`run_core` arm fidelity (byte-equivalent effect, `break_wires_at_pins` owns undo+draw so no double-push and
no missing undo, C89-clean), and signature/build/C89 each found no failing scenario after a genuine
refutation. The one observation raised — the `remove` local shadows POSIX `remove()` from `<stdio.h>` — was
explicitly classed NOT-a-defect: legal C89 block-scope shadowing of a file-scope function never called in
scope, matching the pre-existing convention (the old scheduler branch also used `int remove`); the build is
warning-clean at `-O2`.

**Next atom:** the wire-surgery PAIR trim_wires + break_wires is now on the boundary. The remaining
Refactor B direction is more bare non-transform verbs onto the growing `core_log_action` registry —
`create_instance` / `floaters_from_selected_inst` / `check_unique_names` / `change_elem_order` are the
clean 1:1 next candidates — deferring the composite-hazard verbs (delete / cut / copy / save / reload)
whose shared cores are called by abort/merge/teardown paths (the §4 step-1 `delete()`-is-not-1:1 lesson).

## 30. Refactor B ATOM 10 (2026-07-16): the TENTH per-verb migration — the SECOND NON-transform verb, the FIRST after the wire-surgery pair (`floaters_from_selected_inst`)

`floaters_from_selected_inst` (the Symbol-menu verb that flattens each SELECTED instance's visible symbol
texts into standalone *floater* texts — `attach=<instname>` + `hide_texts` on the instance) now routes
through the `perform_action(verb, argc, argv)` boundary. Atom 10 is the FIRST after the wire-surgery PAIR
(trim_wires atom 1 + break_wires atom 9) completed the boundary, and it is deliberately the CLEANEST next
atom: a **BARE no-arg verb** — no coordinate pivot (unlike rotate/flip/flipv atoms 6/7/8), no `0/1` flag
(unlike break_wires atom 9), no mid-gesture split (not a transform). It is even SIMPLER than break_wires.

**The pilot was disqualified from source; the fallback was re-verified, not assumed.** The suggested pilot
`check_unique_names` was assumed "bare, no-arg" — but source shows it takes an `int rename` flag with a
**read-only-SAFE form**: `check_unique_names 0` only HIGHLIGHTs duplicate refdes (a pure ERC query, no
mutation), while `check_unique_names 1` renames. The boundary's readonly gate is **all-or-nothing per verb**
(rejects whenever `xctx->readonly`, regardless of arg), so routing the whole verb would OVER-reject the
legitimate read-only highlight query — a functional regression. A verb with a non-mutating form does not
belong wholesale behind a *mutation* boundary, so `check_unique_names` was rejected (it passes the caller-1:1
test but fails the clean-boundary criterion). Next in the fallback, `change_elem_order` carries two wrinkles:
its branch + Shift-S key both suppress the log when nothing is selected (`if(had_sel) log_action(...)`, "don't
record a phantom edit"), which the boundary's unconditional `core_log_action` would break (a phantom-log
regression needing had_sel state seeded like the pivot `mousex_snap` trick), AND its core `change_elem_order()`
is a shared sub-step of the DIFFERENT verb `instance_number` (scheduler.c). `create_instance` is not an effect
verb at all — it just opens the `ciform::open` Tcl dialog (no `run_core` effect). So `floaters_from_selected_inst`
— the fourth candidate, and the CLEANEST — was migrated: strictly 1:1 (its ONLY caller is its own scheduler
branch), always-mutating (no read-only-safe form), unconditional log (matches the boundary), no key.

**`run_core` grew a `floaters_from_selected_inst` arm** (byte-identical to the old scheduler standalone branch
effect): just `floaters_from_selected_inst(); return TCL_OK;` — it takes no `argc/argv`. **NO `push_undo()`/
`draw()`** — the core `floaters_from_selected_inst()` (select.c) OWNS its own undo (`xctx->push_undo()` on
first mutation), `set_modify(1)`, and `draw()`. Adding a `push_undo()` in the arm would DOUBLE-push (the
atom-1 no-double-push rule, re-confirmed here as with break_wires_at_pins atom 9). **`core_log_action` grew NO
branch** — a bare verb falls to the DEFAULT `log_action("xschem %s", verb)`, emitting `xschem
floaters_from_selected_inst` byte-identically to the pre-migration `log_action` (the header comment's bare-verb
list gained floaters). This is the same shape as trim_wires/align/the in-place trio.

**THE 1:1 TEST — `floaters_from_selected_inst()` IS the verb, and (unlike trim_wires) is not even a sub-step.**
Grepping every caller confirms `floaters_from_selected_inst()` is reached ONLY by this verb's own scheduler
branch — there is NO key, and NO other C caller (contrast trim_wires atom 1, whose shared `trim_wires()` C fn
is ALSO an internal sub-step of align/move-END autotrim and needs a case-(e) sub-step lock; floaters needs
none). So the boundary/core_log_action is unambiguously the single log site.

**Entry-point map — every LIVE path funnels once, verified by grepping the GUI (the atom-16 lesson).** (1) the
**scheduler branch** → `return perform_action("floaters_from_selected_inst", argc, argv)`, dropping its own
`!xctx` guard (the boundary owns it) and its inline effect + log; reached by scripted `xschem
floaters_from_selected_inst`, the **hand-written Symbol menu** item (`xschem.tcl` `add command -command "xschem
floaters_from_selected_inst"`, NOT table-built, so NOT wrapped in `menu_action_logged`), and the command
palette (runs the `actions.csv` `sym.change_selected_inst_texts_to_floaters` command RAW). (2) there is **NO
key** — keysym-free, ABSENT from `keybindings.csv`, no `callback.c` legacy switch. `menu_action_logged` is
dedup-aware anyway (`log_action -reset`/`-emitted`), so even a hypothetical registry-menu path could not
double-log. The single entry point makes the map the simplest of any atom so far.

**The read-only decision — the boundary ADDS a gate the branch NEVER HAD (a 0041/0051 close).** Unlike every
prior atom (which had an existing `scheduler_readonly_reject` to unify), the floaters branch had NO readonly
gate at all: on a read-only cell it would flatten texts, `push_undo`, `set_modify` — a scattered
0041/0051-class mutation-on-a-read-only-cell gap. The boundary's ONE gate now CLOSES it: `xschem
floaters_from_selected_inst` correctly REFUSES on a read-only cell (`TCL_ERROR`, verb-named message, no
mutation, no log). This is the ONE deliberate user-facing behaviour delta of this atom — a bug fix, and
exactly the read-only unification §4 designed the boundary for. The WRITABLE effect + log are byte-identical
to pre-migration. This is safe precisely BECAUSE floaters has no read-only-safe form (the reason
check_unique_names could NOT be migrated this way).

**Unconditional-log preservation.** Pre-migration the branch logged `xschem floaters_from_selected_inst`
UNCONDITIONALLY — even a nothing-selected no-op logged. The boundary's `core_log_action` also logs
unconditionally, so this is byte-identical (contrast change_elem_order, whose branch deliberately suppresses
the no-op log — the reason it was NOT a clean candidate). Case (e) of the test locks this: a nothing-selected
floaters is a no-op (no texts created) but STILL emits exactly one line.

**Replay parity.** `floaters_from_selected_inst` is a bare, re-executable verb (like `save`/`netlist`, NOT a
coordinate-STORE bypass): a direct re-run re-executes AND re-logs; a replay through the `replay_action_log`
suppress seam re-executes (texts flatten) but does NOT re-log. Stays IN S2 CVERBS, OUT of S3.

**Grep guard (test_selflog_grep_guard.tcl).** floaters's single scheduler `log_action("xschem
floaters_from_selected_inst")` S1 row was MOVED onto the boundary row (`return
perform_action("floaters_from_selected_inst", argc, argv)`). A new **S7 block MIRRORS trim_wires** (the
bare-verb shape, NOT the EXACTLY-N pivot/flag shape): scheduler.c AND callback.c must have ZERO scattered
`log_action("xschem floaters_from_selected_inst")` (its log is the shared `%s` default, so NO per-verb literal
exists anywhere) + scheduler.c ZERO scattered `scheduler_readonly_reject(...,"floaters_from_selected_inst")`
(the branch never had one; a re-scatter fails closed). The callback.c ZERO check guards against a future key
re-adding a scattered log. floaters stays in S2 CVERBS, OUT of S3.

**Effect oracle (byte-identical before/after atom 10 — atom 10 only MOVES the log site):** a `devices/res.sym`
resistor selected at the origin. res.sym has 8 symbol texts, 2 of them `:net_name` (skipped by floaters), so
`xschem floaters_from_selected_inst` flattens the other 6 into standalone floater texts → **text count 0 → 6**,
a clean deterministic oracle determined empirically on the pre-migration binary. NB `xschem select instance`
sets the sel flag but does NOT rebuild `xctx->sel_array`; floaters reads `lastsel`/`sel_array` directly, so
the fixture forces a rebuild via `xschem get lastsel` before the verb (else it silently no-ops — the "rebuild
selection/spatial state headless" gotcha). Undo ownership is proved by depth: floaters's ONE `push_undo` +
the instance-place snapshot means TWO undos wind back to empty (R1 gone); a double-push would insert an
identical third snapshot so R1 would SURVIVE two undos (the discriminator that caught sabotage 5).

**Verified:** `test_perform_action_floaters_from_selected_inst.tcl` (17 checks, full_audit logdir_tests):
(a) +1 from EACH of scripted / menu wrapper, and the WRITABLE effect applies (texts 0 → 6); (b) read-only
reject from the scripted path (TCL_ERROR, verb-named message, NO mutation, NO log — the 0041/0051 close);
(c) byte-exact `xschem floaters_from_selected_inst` (no format drift); (d) replay re-executes with no re-log
through the seam vs a control unwrapped `source` that re-logs; (e) the UNCONDITIONAL-log lock — a
nothing-selected floaters is a no-op but STILL logs +1 (the floaters analogue of the atom-1 sub-step lock,
since floaters has no sub-step); (f) undo ownership — ONE undo restores texts, a SECOND undo removes the
instance, proving the single push_undo (no double-push). **Sabotage ×6** (each failing exactly its checks,
each restore byte-clean vs the atom-10 scratchpad backup, NOT git checkout): (1) neutralise the boundary
readonly gate → the (b) read-only checks fail (scripted floaters mutates + logs on a read-only cell); (2)
revert the branch to an inline form that KEEPS a gate → the runtime `.tcl` STILL passes while the grep guard's
S1 boundary-row + S7 scattered-log + S7 scattered-readonly-reject all fail closed (proving the grep guard is
the load-bearing lock for boundary exclusivity); (3) re-add a scattered scheduler `log_action("xschem
floaters_from_selected_inst")` in the branch → the (a) exactly-+1 checks fail (double-log) and S7
scheduler-scattered fails closed; (4) neutralise the effect in `run_core` → the (a)/(d)/(f) effect oracles
diverge (texts stay 0), log intact; (5) add a spurious `xctx->push_undo()` to the `run_core` arm → the (f)
second-undo depth check fails (R1 survives two undos) — the no-double-push discriminator; (6) add a wrong
`core_log_action` branch logging `xschem floaters` → (c) byte-exact + (a) exact-count fail (log-form drift).
The change-adjacent siblings stay green: the nine other `test_perform_action_*` + `test_selflog_grep_guard` +
`test_actionlog_suppress_gate`; `test_selflog_output`'s floaters self-log check passes (its only FAILs are the
pre-existing six transform-KEY checks that fail identically on baseline).

**Adversarial review (7-agent refute panel — 6 axes + a completeness critic, Workflow, ultracode, against a
source snapshot): verdict CLEAN, zero confirmed defects, zero plausible.** Each axis independently tried and
FAILED to refute: entry-point completeness (every live path — scheduler branch, hand-written Symbol menu,
`actions.csv` command palette / table-menu builder — funnels through `perform_action` once and logs once;
`floaters_from_selected_inst()` is strictly 1:1); readonly gate (no over-reject — floaters has no read-only-safe
form — and no miss/bypass; the message names the verb); bare-log-form fidelity (byte-identical
`xschem floaters_from_selected_inst`, re-executable, replay-suppressed); output-drift / grep-guard (S1 boundary
row matches the branch text; IN S2, OUT S3; all three S7 `==0` assertions hold live and fail closed on every
realistic re-scatter); run_core arm + undo ownership (byte-equivalent to the old branch; the core alone owns
push_undo/set_modify/draw — no double-push, no missed undo, no-op still logs unconditionally); and
signature/build/C89 (the snapshot builds exit-0 under both `-O2 -Wall -Wextra` AND `-std=c89 -pedantic`, with a
warning multiset byte-identical to HEAD). The completeness critic confirmed the one un-grepped surface (the
`actions.csv` palette/table-menu) inherits the same single funnel + new readonly gate. Nothing to fix.

**Full-audit baseline diff clean.** The AFTER run (atom-10 binary: 162 pass / 15 fail / 0 crash) vs the
BASELINE run (scheduler.c + callback.c reverted to HEAD, rebuilt: 161 pass / 16 fail / 0 crash) reconciles
exactly. The BASELINE-only fails are PRECISELY the two load-bearing atom-10 tests —
`test_perform_action_floaters_from_selected_inst` (its (b) readonly-reject fails when the migration is absent —
the boundary gate the branch never had) and `test_selflog_grep_guard` (the S1 boundary row is absent on the
reverted source) — proving both are load-bearing (they PASS on atom-10). The sole AFTER-only fail,
`test_fluid_editing`, is the standing WSLg congestion flake (it ran under the concurrent GUI batch) and PASSES
STANDALONE on the restored atom-10 binary (26 checks). The remaining 14 are the COMMON pre-existing set (fail
identically on BOTH: the cadence duo, the GUI set test_ciw/test_hi_descend/test_lib_manager_gui/
test_reopen_readonly, test_lib_sweep, test_phase3_mints, test_wire_split, test_select_at, test_save_as_cellview,
test_descend_untitled_preserve, test_untitled_reuse, and test_selflog_output's six transform-KEY checks). The
nine sibling `test_perform_action_*` + `test_selflog_grep_guard` are ABSENT from the AFTER fail set = GREEN.
**ZERO new deterministic failures.**

**Next atom:** the wire-surgery pair + the first bare non-transform verb are now on the boundary. The remaining
Refactor B direction is more bare/effect verbs onto the `core_log_action` registry — but the atom-10 lesson is
that the old "clean 1:1 candidate" shortlist was WRONG and each candidate must be RE-VERIFIED from source: a
verb qualifies only if it is always-mutating (no read-only-safe form the all-or-nothing gate would over-reject,
which killed `check_unique_names`), logs unconditionally (no had_sel-style suppression to break, which — plus a
shared-core sub-step of `instance_number` — deferred `change_elem_order`), is a real effect verb (not a dialog
opener like `create_instance`), and whose core does not route OTHER verbs through the boundary. Defer the
composite-hazard verbs (delete / cut / copy / save / reload) whose shared cores are called by abort/merge/
teardown paths (the §4 step-1 `delete()`-is-NOT-1:1 lesson).

## 31. Refactor B ATOM 11 (2026-07-16): the ELEVENTH per-verb migration — the THIRD non-transform verb, the FIRST with a SHARED (sub-step) core (`attach_labels`)

`attach_labels` (the Symbol-menu verb: `xschem attach_labels [interactive]` attaches net-name labels to the
pins of the SELECTED component instances) now routes through the `perform_action(verb, argc, argv)` boundary.
Atom 11 is deliberately a LOWER-friction atom than the suggested `reset_inst_prop`/`check_unique_names`
class: it has a REAL 1:1-ish core fn (`attach_labels_to_inst(int interactive)`, actions.c:2167 — NO inline-
effect extraction) and it was ALREADY logged (a currently-logged MOVE, not a new log site). It combines two
patterns from earlier atoms: it is an **arg-carrying FLAG verb like break_wires (atom 9)** AND its core is a
**SHARED sub-step like trim_wires (atom 1)** — the first atom to be both at once.

**`run_core` grew an `attach_labels` arm** (byte-identical to the old scheduler standalone branch effect):
`int interactive = 0; if(argc > 2) interactive = atoi(argv[2]); attach_labels_to_inst(interactive);`. **NO
`push_undo()`/`draw()`** — the core `attach_labels_to_inst()` OWNS its own undo (it calls `place_symbol(...,
1 /*to_push_undo*/)` which pushes on the first placed label), `set_modify(1)` (actions.c:2316) and `draw()`
(actions.c:2322–2326). Adding one would DOUBLE-push (the atom-1 no-double-push rule, re-confirmed — locked by
test (f), the undo-DEPTH discriminator: ONE undo removes the labels, a SECOND removes the instance).

**FLAG FIDELITY with a PRESERVED value (the break_wires §29 template, extended).** `core_log_action` grew an
`attach_labels` branch that reads `interactive` from `argv[2]` IDENTICALLY to `run_core`. UNLIKE break_wires
(whose `break_wires_at_pins()` reads `remove` as a BOOLEAN, so any nonzero canonicalizes to `1`),
attach_labels's `interactive` is **0/1/2 with DISTINCT meanings** (0 = place `lab_pin`, 1 = interactive
dialog, 2 = the netlisting `lab_show` mode), so the actual value is **PRESERVED with `%d`**, not collapsed:
`if(argc > 2) log_action("xschem attach_labels %d", atoi(argv[2])); else log_action("xschem attach_labels");`.
For the canonical decimal-integer arg every live path emits (the menu/palette `xschem attach_labels`, scripted
`xschem attach_labels <n>`), this is byte-identical to the old `log_action_argv(argc, argv)` (a `Tcl_Merge` of
the verbatim argv); for a non-canonical or multi-token argv (`007` → `7`, `+2` → `2`, `2 foo` → `2`) the `%d`
form is STRICTLY MORE faithful, because it logs exactly the value the effect's `atoi(argv[2])` consumed, so the
logged line can never diverge from the applied effect (the atom-9 flag-fidelity rule — not a regression, since
no menu/palette/key path ever emits a non-canonical or extra arg, and replay re-executes to the identical
interactive value regardless). The adversarial panel classed this canonicalization a nit/not-a-defect on all
three axes that raised it. Test (c) locks byte-exact `xschem attach_labels` AND `xschem attach_labels 2`; test (a) locks
that the `2` form logs the `2` line and NOT the bare, and vice-versa (mutually exclusive counts).

**THE SHARED-CORE SUB-STEP LOCK — `attach_labels_to_inst()` IS the verb, but is ALSO a raw sub-step (the
trim_wires §21 template).** Grepping every caller shows `attach_labels_to_inst()` is NOT strictly 1:1 (unlike
break_wires/floaters): besides this verb's scheduler branch it is called RAW by (1) `show_unconnected_pins()`
(netlist.c:1608, `attach_labels_to_inst(2)` — the netlisting-adjacent "Show unconnected pins" sub-step,
reached by `xschem show_unconnected_pins`; NB the raw caller is `show_unconnected_pins`, NOT the main `xschem
netlist` flow — the candidate list said "netlist", source said `show_unconnected_pins`, the atom-10 re-verify-
from-source lesson applied) and (2) the **Shift+H interactive-DIALOG key** (`act_attach_labels`, callback.c:3418
→ `attach_labels_to_inst(1)`, a registered action, `actions.csv:125` marked `nolog=1` because the dialog
variant is behaviourally NON-equivalent to the scheduler `xschem attach_labels` = interactive 0 form). Both
callers stay BELOW the boundary — raw core, no `perform_action`, no self-log — exactly the trim_wires-is-a-sub-
step-of-align pattern (the boundary wraps the VERB DISPATCH, not the C fn). Test (e) drives BOTH raw paths
(`xschem show_unconnected_pins` and the Shift+H key via `xschem callback .drw 2 … 72 0 0 0` with the modal
dialog proc stubbed) and locks that each MUTATES (proving it ran) yet emits ZERO `xschem attach_labels` lines.

**Three entry points — the scheduler branch crosses, the key + netlist sub-step stay off.** (1) the **scheduler
branch** → `return perform_action("attach_labels", argc, argv)`, dropping its own `!xctx` guard (the boundary
owns it), its inline `attach_labels_to_inst()` call, and its `log_action_argv(argc, argv)` self-log; reached by
the hand-written Symbol menu (`xschem.tcl:14341` `-command "xschem attach_labels"`, interactive=0, NOT
`menu_action_logged`-wrapped) and the command palette (runs the `actions.csv` command raw). (2) the **Shift+H
key** stays OFF the boundary (registered csv-nolog dialog path — a separate pre-existing concern; its own
read-only behaviour is UNCHANGED by this atom, deliberately, since it is a registered-action dialog path, not
an inline legacy-switch key like break_wires's `!`/Ctrl-!). (3) the **`show_unconnected_pins` netlist sub-step**
stays BELOW the boundary. Confirmed keysym `'H'` (`set_input_binding(DEV_KEY, 'H', 0, …)`) — the old `case 'H'`
is fully migrated to the binding table; no legacy-switch double-dispatch.

**The read-only decision — the boundary ADDS a gate the branch NEVER HAD (the floaters §30 template).** The
old branch had NO `scheduler_readonly_reject`: on a read-only cell `xschem attach_labels` would place label
instances, `push_undo`, `set_modify` — a scattered 0041/0051-class mutation-on-a-read-only-cell gap. The
boundary's ONE gate now CLOSES it (`xschem attach_labels` / `xschem attach_labels 2` REFUSE on a read-only
cell: `TCL_ERROR`, verb-named message, no mutation, no log). This is safe precisely BECAUSE attach_labels has
NO read-only-safe form — **every** `interactive` value MUTATES (0/1/2 all reach `place_symbol`; none is a
query-only path like `check_unique_names 0` that the all-or-nothing gate would OVER-reject, §30). Verified by
reading `attach_labels_to_inst()` end-to-end: there is no highlight/ERC-only branch. This is the one deliberate
user-facing delta of the atom — a bug fix. The WRITABLE effect + log are byte-identical to pre-migration.

**Grep guard (test_selflog_grep_guard.tcl).** attach_labels had NO dedicated S1 row before (its self-log was
`log_action_argv(argc, argv)`, a literal shared by several verbs). This atom ADDED three S1 rows (the boundary
branch row + the two `core_log_action` VALUE/BARE form rows) and an **S7 block MIRRORING break_wires** (arg-
carrying, TWO forms): scheduler.c EXACTLY ONE `log_action("xschem attach_labels %` (value form) + EXACTLY ONE
`log_action("xschem attach_labels")` (bare form) + EXACTLY TWO total, callback.c ZERO, scheduler.c ZERO
scattered `scheduler_readonly_reject(...,"attach_labels")`. The literals `attach_labels %` (space+%) and
`attach_labels")` (quote+paren) are mutually exclusive and counted independently (a re-scatter of EITHER fails
closed); neither matches `attach_labels_to_inst` (an `_` follows). attach_labels was ALREADY in S2 CVERBS
(kept), stays OUT of S3.

**Effect oracle (byte-identical before/after atom 11 — atom 11 only MOVES the log site + ADDS the gate):** a
`devices/res.sym` resistor selected at the origin has TWO pins (P 0,−30, M 0,30), both unconnected (no wires),
so `xschem attach_labels` places TWO `lab_pin` instances → **instance count 1 → 3**; `xschem attach_labels 2`
places TWO `lab_show` instances → same +2. Determined empirically on the pre-migration binary. `attach_labels_
to_inst()` rebuilds the selected array itself (`rebuild_selected_array()`, actions.c:2197), so a bare `xschem
select instance` suffices, but the fixture still forces a `redraw` so the pin-vs-wire skip test's spatial hash
is populated headless.

**Verified:** `test_perform_action_attach_labels.tcl` (27 checks, full_audit logdir_tests): (a) +1 from EACH of
script bare / script `2` / menu wrapper + the effect applies (+2 label instances); (b) read-only reject from
the scripted path (TCL_ERROR, verb-named message, NO mutation, NO log — the 0041/0051 close) for BOTH forms;
(c) byte-exact `xschem attach_labels` / `xschem attach_labels 2` (the VALUE is PRESERVED); (d) replay re-
executes with no re-log through the seam vs a control unwrapped `source` that re-logs; (e) the SHARED-CORE
SUB-STEP lock — `xschem show_unconnected_pins` (raw `attach_labels_to_inst(2)`) AND the Shift+H interactive key
(raw `attach_labels_to_inst(1)`, dialog stubbed) each MUTATE but emit ZERO `xschem attach_labels`; (f) undo
DEPTH — ONE undo removes the labels, a SECOND removes the instance (single push_undo, no double). **Sabotage
×5** (each failing exactly its checks, each restore byte-clean vs the atom-11 scratchpad backup, NOT git
checkout): (1) neutralise the boundary readonly gate → the (b) read-only checks fail (scripted attach mutates +
logs on a read-only cell); (2) bypass the boundary at the branch with an inline form that KEEPS a gate + effect
+ log → the runtime `.tcl` STILL passes while the grep guard's S1 boundary row + S7 EXACTLY-ONE/TWO all fail
closed (proving the grep guard is the load-bearing lock for boundary exclusivity); (3) re-add a scattered
scheduler `log_action("xschem attach_labels")` → the (a) exactly-+1 checks fail (double-log) and S7 EXACTLY-TWO
(got 3) fails closed; (4) drop the `core_log_action` attach_labels branch (falls to the bare `%s` default) →
the `2` form's (a)/(c) FLAG-fidelity checks diverge (`xschem attach_labels 2` logs bare `xschem attach_labels`)
and the S1/S7 `%`-form rows fail closed; (5) route the netlist.c raw sub-step through the boundary verb
(`Tcl_GlobalEval(interp, "xschem attach_labels 2")` in `show_unconnected_pins`) → the (e) sub-step lock fails
(`xschem show_unconnected_pins` now emits `xschem attach_labels 2`). The change-adjacent siblings stay green:
the ten other `test_perform_action_*` + `test_selflog_grep_guard`; `test_selflog_output`'s attach_labels
self-log check passes (its only FAILs are the pre-existing six transform-KEY checks that fail identically on
baseline).

## 32. Refactor B ATOM 12 (2026-07-16): the TWELFTH per-verb migration — the FIRST FRICTION-FREE-SCOUTED verb, a PURELY ADDITIVE boundary (`toggle_ignore`)

`toggle_ignore` (`xschem toggle_ignore` — cycles the per-mode `*_ignore` attribute
none → `"true"` → `"short"` → none on the SELECTED instances AND wires, where `*` ∈
{spice,verilog,vhdl,tedax,spectre} per `xctx->netlist_type`) now routes through the
`perform_action(verb, argc, argv)` boundary. Atom 12 is the FIRST atom whose pilot was
chosen NOT off a hand-carried shortlist but by an EXHAUSTIVE scout: the companion
`perform_action_boundary_migration_friction_analysis.md` classified ALL 243 mutating
scheduler verbs against 6 friction-free criteria and found exactly THREE friction-free
(`toggle_ignore`, `show_unconnected_pins`, `redo`); `toggle_ignore` was the cleanest. It
is a **BARE no-arg verb** like `floaters_from_selected_inst` (atom 10) — even simpler
than the arg-carrying `break_wires`/`attach_labels`.

**`run_core` grew a bare `toggle_ignore` arm** — `toggle_ignore(); return TCL_OK;` (no
`argc/argv`). **NO `push_undo()`/`draw()`** — `toggle_ignore()` (actions.c:2997) OWNS its
own undo (`xctx->push_undo()` on the FIRST selected element, gated by `first`),
`set_modify(1)` and `draw()` (all inside `if(attr)`); adding one would DOUBLE-push (the
atom-1 no-double-push rule, locked by test (f)). **`core_log_action` grew NO branch** — a
bare verb rides the DEFAULT `log_action("xschem %s", verb)`, emitting `xschem
toggle_ignore` (the header-comment bare-verb list gained `toggle_ignore`).

**THE PURELY-ADDITIVE BOUNDARY.** Unlike every prior atom, the branch had NEITHER a
readonly gate NOR a log before this atom — verified at runtime on the pre-migration
binary: scripted `xschem toggle_ignore` logged 0 lines and MUTATED a read-only cell
(`rc=0`, attribute changed). So the boundary ADDS **both**: the ONE
`scheduler_readonly_reject` now REFUSES on a read-only cell (`TCL_ERROR`, verb-named
message, no mutation, no log — a scattered 0041/0051 mutation-on-a-read-only-cell gap
CLOSED) AND the ONE `core_log_action` DEFAULT `%s` log line (a coverage gain, not a
byte-identical move — contrast attach_labels, which only MOVED an existing log). The
WRITABLE effect is byte-identical (the migration adds only the gate + log).

**THE NO-OP-STILL-LOGS PROPERTY (§30 floaters analogue).** In a netlist mode where the
ignore attribute is undefined (`attr == NULL` — `xctx->netlist_type` is none of
spice/verilog/vhdl/tedax/spectre, e.g. `set netlist_type symbol` = `CAD_SYMBOL_ATTRS`),
`toggle_ignore()` is a harmless no-op: the whole body is inside `if(attr)`, so nothing
mutates, NO `push_undo`, no `draw`. Under the boundary's unconditional log it STILL emits
one `xschem toggle_ignore` line — idempotent + replayable, the CORRECT behaviour (§30),
locked by test (e).

**THE KEY-EQUIVALENCE INVERSION — and the scout premise it OVERTURNED.** attach_labels
(§31) kept its Shift+H key OFF the boundary because that key ran a NON-equivalent
interactive dialog (csv-`nolog`). toggle_ignore INVERTS that: its Shift+T key
(`act_toggle_ignore`, callback.c) calls the SAME core with the SAME effect and its
registry row is NOT `nolog`, so it is EQUIVALENT and routes THROUGH the boundary —
`{ (void)e; perform_action("toggle_ignore", 0, NULL); return 1; }`. **But re-verifying
from source (the atom-10 discipline) overturned the friction doc's premise that the key
was a "coverage hole."** It was NOT:

- **Already readonly-gated.** The registry `ActionDef` row carries `mutates=1`, and
  `dispatch_input_action()` (callback.c ~4108) runs
  `if(action_id_mutates(id) && readonly_block()) return 1;` BEFORE calling the handler.
  So on a read-only cell the key was — and still is — blocked at DISPATCH (via
  `readonly_block`, which pops a modal `tk_messageBox` when `has_x`), *before* reaching
  `perform_action`.
- **Already logged.** dispatch ~4117 runs
  `if(ret && d->log_cmd && !actionlog_cmd_logged) log_action("%s", d->log_cmd);`, and
  `d->log_cmd` is `"xschem toggle_ignore"` (pushed from actions.csv:113, not-`nolog`).
  So the key already emitted `xschem toggle_ignore` via **Layer A** — verified at runtime
  (the key logged +1 on the pre-migration binary; the branch logged +0).

So the true coverage gap was the **branch only**; routing the key is a **CONSISTENCY**
move (unify the log onto `core_log_action`), not a coverage add. Its correctness rests on
the **`actionlog_cmd_logged` DEDUP**: the boundary's `log_action` sets the flag (util.c),
so dispatch's Layer A copy at 4117 is skipped → EXACTLY ONE line (verified: the key logs
+1, NOT +2). `mutates=1` is KEPT on the registry row — so the key's read-only safety
remains the dispatch gate (`readonly_block`), and `perform_action`'s gate is redundant
belt for the key while being load-bearing for the branch. `return 1` (not
`return perform_action(...)`) preserves the ActionEvent handler contract:
`perform_action` returns `TCL_OK`(0)/`TCL_ERROR`(1), the OPPOSITE of the handler's
"1 = handled", so returning it would tell the dispatcher the event was unhandled.

**Why `mutates=1` must stay (the phantom-log trap).** If `mutates=1` were removed to make
`perform_action` the sole key gate, then on a read-only cell dispatch would NOT block, the
handler would call `perform_action` → reject (no log, `actionlog_cmd_logged` stays 0) →
return, and dispatch 4117 would then log a PHANTOM `xschem toggle_ignore` line for a
refused edit. Keeping `mutates=1` blocks the key before the handler, so no phantom.

**THE 1:1 TEST.** `toggle_ignore()` is called by ONLY two sites (grep-verified): the
scheduler branch and `act_toggle_ignore` — BOTH on the boundary. So it is strictly 1:1
with the verb; there is NO shared sub-step to lock (unlike attach_labels'
`attach_labels_to_inst`, also called raw by `show_unconnected_pins`).

**Entry-point map — every LIVE path funnels once.** (1) the **scheduler branch** →
`return perform_action("toggle_ignore", argc, argv)`, reached by scripted `xschem
toggle_ignore`, the hand-written Prop menu item (xschem.tcl:14278 `-command "xschem
toggle_ignore"`, NOT `menu_action_logged`-wrapped) and the command palette
(actions.csv:113 raw). (2) the **Shift+T key** (`act_toggle_ignore`) →
`perform_action("toggle_ignore", 0, NULL)`. The key binding lives in `input_bindings[]`
(seeded by `set_input_binding(DEV_KEY,'T',0,…)`, callback.c:3960) and its keybindings.csv
mirror (row 34) — the SAME binding in two mirrored places, ONE handler dispatch, no
legacy `case 'T'` switch, so no double-dispatch of the effect.

**Replay parity.** `toggle_ignore` is a bare, re-executable verb (like `save`/`floaters`,
not a coordinate-STORE bypass): a direct re-run re-executes AND re-logs; a replay through
the `replay_action_log` suppress seam re-executes but does NOT re-log. Stays IN S2
CVERBS, OUT of S3.

**Grep guard (test_selflog_grep_guard.tcl).** ADDED: the S1 scheduler boundary row
(`return perform_action("toggle_ignore", argc, argv)`), the S1 callback key row
(`perform_action("toggle_ignore", 0, NULL)`), `toggle_ignore` in the S2 CVERBS set, the
bare-verb `%s` label update, and an S7 block MIRRORING floaters (scheduler.c AND
callback.c ZERO scattered `log_action("xschem toggle_ignore")` — the log is the shared
`%s` default, so NO per-verb literal exists — plus scheduler.c ZERO scattered
`scheduler_readonly_reject(...,"toggle_ignore")`). UNLIKE floaters, toggle_ignore HAS a
key, so the callback.c ZERO check locks that the key routes through the boundary and never
self-logs a C literal (its Layer A log is from actions.csv, deduped). The S1 key row is
the **load-bearing lock** for the key routing: the runtime output is identical whether the
key uses Layer A or `core_log_action`, so ONLY this grep row catches a raw-core key
regression (sabotage 3 proves it).

**Effect oracle (byte-identical before/after atom 12).** A `devices/res.sym` resistor
selected at the origin in SPICE mode: `xschem toggle_ignore` cycles its `spice_ignore`
attribute `""` → `"true"` → `"short"` → `""` on successive calls (actions.c flag
0→1→2→0), observed via `xschem getprop instance 0 spice_ignore`. A selected WIRE cycles
identically (`xschem getprop wire 0 spice_ignore`). `toggle_ignore()` rebuilds the
selected array itself, so a bare `xschem select instance` suffices (the fixture still
`redraw`s so the KEY/callback path has spatial state). Undo DEPTH proves single push:
after one toggle, ONE undo restores the prior value and a SECOND undo removes the
instance — a double-push would leave the value alive past one undo.

**Verified:** `test_perform_action_toggle_ignore.tcl` (26 checks, full_audit logdir_tests):
(a) +1 from EACH of scripted / Shift+T key / menu wrapper — the KEY logging ONE not TWO is
the load-bearing dedup proof — and the WRITABLE effect cycles (instance + wire); (b)
readonly reject — SCRIPTED branch (the coverage add) TCL_ERROR + verb-named message + no
mutation + no log, AND the Shift+T key on a read-only cell mutates/logs nothing (gated at
dispatch by `mutates=1`, tk_messageBox stubbed); (c) byte-exact `xschem toggle_ignore`;
(d) replay re-executes with no re-log through the seam vs a control unwrapped `source` that
re-logs; (e) the NO-OP-STILL-LOGS lock (symbol mode `attr==NULL` → no mutation but +1
line); (f) undo DEPTH (ONE undo restores the prior value, a SECOND removes the instance —
single push_undo). **Sabotage ×6** (each failing exactly its checks, each restore
byte-clean vs the atom-12 scratchpad backup, NOT git checkout): (1) neutralise the boundary
readonly gate → the (b) scripted-readonly checks fail (mutates + logs) + grep S1 gate row;
(2) bypass the boundary at the BRANCH with an inline gate+effect+log → the runtime `.tcl`
STILL PASSES while the grep guard's S1 boundary row + S7 scattered-log + S7
scattered-readonly-reject all fail closed (the grep guard is the load-bearing exclusivity
lock); (3) bypass the boundary at the KEY (raw `toggle_ignore()`+`return 1`) → the runtime
`.tcl` STILL PASSES (the raw key still logs via Layer A + is gated via `mutates=1`) while
ONLY the grep guard's S1 key row fails closed (proving the key routes through the boundary
and the grep row is load-bearing — the corrected-model finding); (4) re-add a scattered
branch `log_action("xschem toggle_ignore")` → the (a) exactly-+1 checks double-log + S7
scheduler scattered-log fails closed; (5) add a spurious `xctx->push_undo()` to the
run_core arm → the (f) undo-DEPTH check fails (the instance survives the second undo) —
the no-double-push discriminator; (6) neutralise the effect in run_core → the (a)/(d)/(f)
effect oracles diverge (spice_ignore stays `""`), log intact. One change-adjacent test
needed a deliberate UPDATE: `test_toggle_editmode_log`'s (f) "pure-view toggles log
NOTHING" check listed `xschem toggle_ignore` among the silent verbs — but atom 12 makes the
branch log UNCONDITIONALLY (the coverage add), so `toggle_ignore` was DROPPED from that
group (it is a real MUTATOR, silent before only because its branch lacked a log; its
logging is covered by its own test). The change-adjacent siblings stay green: the eleven
`test_perform_action_*` + `test_selflog_grep_guard` + `test_actionlog_suppress_gate` +
`test_action_log_dispatch` + `test_accelerators`; `test_selflog_output`'s only FAILs are
the pre-existing SIX transform-KEY checks (fail identically on baseline).

**Adversarial review (7-axis refute panel + a completeness critic, Workflow, ultracode,
against an atom-12 source snapshot): verdict CLEAN, zero confirmed defects, zero findings.**
Each axis independently tried and FAILED to refute: entry-point completeness / double-log
(every live path funnels once; the key logs EXACTLY ONE line via the `actionlog_cmd_logged`
dedup; `toggle_ignore()` is strictly 1:1); readonly gate (no over-reject — the `attr==NULL`
path is a no-op, not a read-only-safe query, so nothing legitimate is refused — no
miss/bypass, message verb-named + headless-safe on the branch, the key still gated via
`mutates=1`); bare-log-form fidelity (byte-exact `xschem toggle_ignore`, replay-suppressed,
IN S2 / OUT S3); output-drift / grep-guard (S1 branch + key rows, S7 zero-scatter, all fail
closed on realistic re-scatter); run_core arm + undo (byte-equivalent effect; the core
alone owns push_undo/set_modify/draw — no double-push, no missing draw, no-op still logs);
the KEY decision (routing the equivalent registered key is correct, the `return 1` handler
contract is preserved — `perform_action`'s rc is NOT returned — and `mutates=1` MUST stay to
avoid a Layer-A phantom-log-on-read-only); and signature/build/C89 (the added code is C89,
compiles, no unused vars). The completeness critic confirmed the un-attacked surfaces (the
command palette, the menu-wrapper dedup, the keybindings.csv-vs-`set_input_binding` single
dispatch, mixed wire+instance selection, the `CAD_SYMBOL_ATTRS` no-op logging) inherit the
single funnel. Nothing to fix.

**Full-audit baseline diff clean.** The AFTER run (atom-12 binary: 151 pass / 19 fail /
0 crash) vs the BASELINE run (scheduler.c + callback.c reverted to HEAD, rebuilt: 150 pass /
22 fail / 0 crash) reconciles exactly. The load-bearing BASELINE-only fails are PRECISELY
the two atom-12 tests — `test_perform_action_toggle_ignore` (its readonly-reject + branch-log
checks fail when the migration is absent) and `test_selflog_grep_guard` (the S1 boundary
rows are absent on reverted source) — proving both load-bearing (they PASS on atom-12). The
sole real change-adjacent fail, `test_toggle_editmode_log`, was the stale silent-verb
assertion above, now UPDATED (passes). The remaining AFTER fails are the COMMON pre-existing
set (the cadence trio test_altf5_ciw/test_cadence_descend_newwin_ro/test_cadence_drag, the
GUI set test_ciw/test_hi_descend/test_lib_manager_gui/test_reopen_readonly,
test_lib_sweep/test_phase3_mints/test_wire_split/test_select_at/test_save_as_cellview/
test_descend_untitled_preserve/test_untitled_reuse, and test_selflog_output's six
transform-KEY checks) plus the standing WSLg flakes (test_fluid_editing/test_hover_highlight/
test_palette — each PASSES standalone on the restored atom-12 binary). The eleven sibling
`test_perform_action_*` + `test_selflog_grep_guard` are ABSENT from the AFTER fail set =
GREEN. **ZERO new deterministic failures.**

**Next atom:** the friction analysis's headline recommendation — EXTEND the boundary to
log-on-success (`if(rc == TCL_OK && !actionlog_suppress) core_log_action(...)`) — which
unblocks the LARGEST failure family (the validating verbs `reset_inst_prop` /
`replace_symbol` / `load_backup` that fail an argument check before mutating and therefore
cannot ride the current unconditional-log contract). That is a shared-machinery change, so
it is its own deliberately-scoped atom (does any migrated verb rely on the unconditional
log? the bare verbs never fail, so no — but check, don't assume). toggle_ignore was the
last of the three friction-free verbs worth taking (show_unconnected_pins wraps a shared
sub-step; redo already self-gates), so the additive-only phase is now spent; the boundary
extension is the next real step.

## 33. Refactor B ATOM 13 (2026-07-16): the FIRST SHARED-MACHINERY atom — the boundary now LOGS ONLY ON SUCCESS, landing `reset_inst_prop` (the FIRST VALIDATING verb) as its first beneficiary

Atoms 1–12 each migrated ONE verb onto an UNCHANGED `perform_action(verb, argc, argv)`
boundary whose contract was "log unconditionally after the effect." **Atom 13 is
different in kind: it CHANGES THE SHARED BOUNDARY ITSELF** (log-on-success) and migrates
the first verb the change unblocks (`reset_inst_prop`) as its proving beneficiary. One
atom = the boundary change + its first beneficiary together — the boundary change alone
has no observable behaviour without a verb whose `run_core` can FAIL, so they ship as a
pair. This is the friction analysis's headline recommendation
(`perform_action_boundary_migration_friction_analysis.md` §2/§3-crit-3/§7-lesson-2),
executed: the additive-only phase was spent after atom 12, and the LARGEST disqualified
family was the VALIDATING verbs (early `TCL_ERROR` before mutating — `reset_inst_prop`,
`replace_symbol`, `load_backup`, `reset_symbol`, `move_instance`, `apply_properties`, …).

**THE BOUNDARY CHANGE (the heart of the atom).** `perform_action` was:

```c
rc = run_core(verb, argc, argv);
if(!actionlog_suppress) core_log_action(verb, argc, argv);   /* logged REGARDLESS of rc */
Tcl_ResetResult(interp);                                     /* wiped REGARDLESS of rc */
return rc;
```

and is now:

```c
rc = run_core(verb, argc, argv);
if(rc == TCL_OK) {   /* LOG-ON-SUCCESS + success-only reset (Refactor B atom 13) */
  if(!actionlog_suppress) core_log_action(verb, argc, argv);
  Tcl_ResetResult(interp);   /* clear on success ONLY -- preserve error message on TCL_ERROR */
}
return rc;
```

A rejected VALIDATING call now records **no** replayable line (a phantom command that
does nothing / errors on replay was the regression the old contract would have
introduced). This reclaims the entire validating-verb class with one change.

**THE LANDMINE — the guard MUST wrap the `Tcl_ResetResult`, never split from it.** Today
every migrated verb returns `TCL_OK`, so the old unconditional `Tcl_ResetResult` was
harmless. But `reset_inst_prop`'s `run_core` `Tcl_SetResult`s an error ("needs 1 more
argument" / "instance not found") and returns `TCL_ERROR` — and an unconditional
`Tcl_ResetResult` would WIPE that message before returning, so the caller saw an EMPTY
error (a known C-side empty-error bug class). Resetting only on the `TCL_OK` path
preserves the message on failure AND skips the phantom log with ONE guard. The
`scheduler_readonly_reject` early return keeps its own message the same way (it returns
before `rc`/reset). The nested-block form (one `if(rc == TCL_OK)` wrapping BOTH) is used
deliberately over the split inline form (`if(rc==TCL_OK && !suppress)` + a separate
`if(rc==TCL_OK) reset`) precisely so log and reset cannot drift apart.

**THE INVARIANT AUDIT (the load-bearing safety proof for a shared-machinery change).**
Log-on-success must not silently DROP a log any already-migrated verb emits. Every
`run_core` arm was read: the bare verbs (trim_wires/align/rotate_in_place/flip_in_place/
flipv_in_place/floaters/toggle_ignore) never fail → always `TCL_OK`; the arg-carrying
pivot verbs (rotate/flip/flipv) and the flag verbs (break_wires/attach_labels) return
`TCL_OK`; and — the subtle one — **the NO-OP-STILL-LOGS cases (floaters nothing-selected;
toggle_ignore `attr==NULL` symbol mode) return `TCL_OK`, so they STILL log under
log-on-success (a no-op is a SUCCESS, not a failure — the §30/§32 property MUST survive,
and does).** `run_core`'s final `return TCL_ERROR` is the unreachable "unwired verb"
default, unaffected. The test's check (e) drives BOTH no-op verbs and asserts each STILL
emits +1 — the explicit regression assertion that a future "gate the log on did-something-
mutate" change would trip.

**THE FIRST BENEFICIARY: `reset_inst_prop`** (`xschem reset_inst_prop <ref>` — resets an
instance's property string from its symbol template via `set_inst_prop`, editprop.c:214).
It is the FIRST VALIDATING verb on the boundary. Migration:

- **Branch** (`scheduler.c`) → `return perform_action("reset_inst_prop", argc, argv);` —
  dropping the `!xctx` guard, the per-verb `scheduler_readonly_reject`, the inline effect,
  and the success-path `Tcl_SetResult(instname)` result (the boundary owns them).
- **`run_core` arm**: the two validation gates MOVE in — `argc<3 → TCL_ERROR "needs 1 more
  argument"`, then `get_instance(argv[2])<0 → TCL_ERROR "instance not found"` — BEFORE the
  single `xctx->push_undo()`, so a bad arg mutates nothing and (via log-on-success) logs
  nothing. Then the reset effect (`hash_names`/`set_inst_prop`/`translate`/`match_symbol`/
  `delete_inst_node`/`set_inst_flags`/`symbol_bbox`/`set_modify(-2)`/`draw`), `return
  TCL_OK`. There is NO core fn that pushes undo (unlike toggle_ignore/floaters which
  self-undo), so THIS arm owns the single `push_undo` — pushed once, only once (the atom-1
  no-double-push rule, locked by test (f) undo-depth). The dead `char *subst=NULL; … if(subst)
  my_free(&subst)` (never assigned → unreachable) was dropped.
- **`core_log_action` arm**: `log_action("xschem reset_inst_prop %s", argv[2])`.
  `reset_inst_prop` is ARG-CARRYING and SELECTION-INDEPENDENT (it targets an instance BY
  NAME or numeric index via `get_instance`, scheduler.c:86), so the log is the
  SELF-CONTAINED name form — `argv[2]` read IDENTICALLY to `run_core`, so the logged
  referent can never diverge from the reset one; replay re-resolves it. Reached ONLY on
  `TCL_OK` (log-on-success), and `run_core` returns `TCL_OK` only after `argc<3` passed, so
  `argv[2]` is always present here.

**Entry map.** `reset_inst_prop` has **NO key, NO menu, and NO other C caller** — verified
by grepping the live repo (keybindings.csv / mousebindings.csv / actions.csv / callback.c
`act_*` / xschem.tcl `-command` / Tcl procs / C `Tcl_Eval`): it is a PURE SCRIPTED verb,
reached only by its own scheduler branch. So there is NO callback.c edit, NO menu wrapper,
and NO key-equivalence decision (contrast toggle_ignore's Shift+T §32 / attach_labels'
Shift+H §31). Its core is strictly 1:1 (the inline effect had no other caller), so there is
no shared sub-step to lock.

**Behaviour delta (the ONE intentional change beyond the coverage gain).** The old branch
returned the instance's `instname` as the Tcl result on success; the boundary's success-path
`Tcl_ResetResult` now clears it. Verified no caller consumes it (the only repo reference to
the verb is `test_readonly_guard`'s rejection-loop verb list). The read-only gate is NOT new
(the old branch already had one) — the boundary merely UNIFIES it onto the generic gate.

**Grep guard (`test_selflog_grep_guard.tcl`).** (a) the S1 log-site row's regex was UPDATED
to pin the uniquely-commented `if(rc == TCL_OK) {   /* LOG-ON-SUCCESS + success-only reset
(Refactor B atom 13)` outer-guard line — reverting to the unconditional log DELETES that
line → fails closed (sabotage 1) — plus a NEW S1 row pinning the success-only
`Tcl_ResetResult(interp);   /* clear on success ONLY` (the landmine coupling); (b) NEW S1
rows for the boundary branch and the `xschem reset_inst_prop %s` name form; (c)
`reset_inst_prop` ADDED to S2 CVERBS, kept OUT of S3; (d) an S7 block (single arg-carrying
form, like rotate/flip: EXACTLY ONE `log_action("xschem reset_inst_prop %s"` in scheduler.c,
ZERO in callback.c, ZERO scattered `scheduler_readonly_reject(...,"reset_inst_prop")` — the
old branch HAD a per-verb one, now GONE). Maintenance-header note added.

**Effect oracle (byte-identical effect before/after — the migration MOVES validation +
gates the log, it does not change the reset).** A `devices/res.sym` resistor (template
`value=1k`) placed at the origin with a non-template `value=999`; `xschem reset_inst_prop
R1` copies the template back → `xschem getprop instance 0 value` goes 999 → 1k. Determined
empirically on the pre-migration binary. The FAILING cases pinned: `xschem reset_inst_prop`
(no arg) and `xschem reset_inst_prop bogus_name` each `TCL_ERROR` with a NON-EMPTY verb-named
message and, on the migrated binary, log NOTHING — the load-bearing new-capability observable.

**Test `test_perform_action_reset_inst_prop.tcl` (25 checks, full_audit logdir_tests).** (a)
SUCCESS: the ONE script entry → exactly +1 + effect (999→1k) + byte-exact `xschem
reset_inst_prop R1`; (b) THE ATOM-13 HEADLINE — FAILURE IS NOT LOGGED: no-arg + bogus-name
each `TCL_ERROR` + NON-EMPTY verb-named message (the landmine proof: `Tcl_ResetResult` did
not wipe it) + no mutation + +0 log; (c) readonly reject (`TCL_ERROR`, verb-named read-only
message, no mutation, no log); (d) replay — the self-contained name form re-EXECUTES through
the `replay_action_log` suppress seam without re-logging vs a control unwrapped `source` that
DOES re-log; (e) THE INVARIANT REGRESSION — floaters-nothing-selected AND toggle_ignore-
attr==NULL each STILL log +1 under log-on-success (the no-op-still-logs §30/§32 property
survives; the drives are `catch`-wrapped so a regressed verb reports a clean log-count FAIL,
not a script abort); (f) undo DEPTH — one undo restores the prior value (1k→999), a second
removes the instance (single `push_undo`).

**SABOTAGE ×9** (each rebuild-run-restore, each failing EXACTLY its checks; restore from the
post-edit scratchpad backup `scheduler.c.atom13`, NOT git — ~200 dirty files):
(1) revert to the UNCONDITIONAL log + reset → (b) both the phantom-log (`+1` on failure) AND
the empty-error (`msg=><`) checks fail, and both grep guard rows fail closed;
(2) log-on-success but Tcl_ResetResult UNCONDITIONAL (split the guard) → ISOLATES the
landmine: only the (b) message-non-empty checks fail (the +0-log checks PASS, readonly
unaffected — it returns early);
(3) neutralize the boundary readonly gate → (c) all fail (rc=0, mutates+logs, empty msg);
(4) inline the branch with its OWN gate+log (bypass the boundary) → the runtime .tcl PASSES,
only the grep guard fails closed (S1 boundary-branch row missing + S7 EXACTLY-ONE→2 + S7
scattered readonly_reject present) — the grep guard IS the load-bearing structural lock;
(5) scattered branch log → (a) double-log + (b)/(c) phantom-log on failed/readonly calls +
S7 EXACTLY-ONE→2;
(6) spurious second `push_undo` in the arm → (f) undo-depth (instance survives the 2nd undo);
(7) make a MIGRATED BARE verb's `run_core` arm (`floaters`) return `TCL_ERROR` → the (e)
INVARIANT check fails cleanly (floaters no-op logs 0 not 1) AND the floaters sibling fails —
the safety proof that log-on-success did not silently break an existing verb (this sabotage
also drove the (e)-block hardening: `catch`-wrap so the regression is a clean FAIL not an
uncaught-error abort);
(8) raw `%s` referent form (the replay-unsafe pre-review form) → the (a2) arrayed-name checks
fail (logs `x2[3:0]` unbraced; replay errors "invalid command name 3:0"; the reset is not
reproduced) + the S1 `log_action_argv`/`av[...]` rows and the S7 exclusivity fail closed;
(9) DE-NEST the boundary — keep all three pinned lines but close the `if(rc == TCL_OK)` block
early so log+reset run unconditionally → the S7 NESTING-COUPLING regex fails closed (the
finding-2 lock) AND runtime (b) catches the phantom-log + wiped message (the behavioral backstop).

**Full-audit baseline diff clean.** AFTER (atom-13 binary: 153 pass / 17 fail / 0 crash / 10 skip)
vs BASELINE (`scheduler.c` reverted to HEAD, rebuilt: 153 pass / 18 fail / 4 crash / 5 skip),
behind the one-button approval gate. The load-bearing BASELINE-only fails are PRECISELY the two
atom-13 tests — `test_perform_action_reset_inst_prop` (its +1-log / replay / byte-exact checks fail
when the migration is absent — the old branch never logged) and `test_selflog_grep_guard` (the
atom-13 S1/S7 rows are absent on reverted source) — proving both load-bearing (they PASS on
atom-13). The four OTHER BASELINE-only fails (`test_nh_angle_editor` / `test_nh_angle_range` /
`test_nh_editor_rowops` / `test_nh_editor_staged`) are the BASELINE run's WSLg crash/timeout flakes
(BASELINE had 4 crash/timeout vs AFTER 0; all four PASS on atom-13 — NOT an atom-13 fix, a load
artifact). The sole AFTER-only fail, `test_palette`, is a standing WSLg flake (PASSES standalone on
the restored binary). Everything else is the COMMON pre-existing set (the cadence trio, the GUI set
test_ciw/test_hi_descend/test_lib_manager_gui/test_reopen_readonly, test_lib_sweep/test_phase3_mints/
test_wire_split/test_select_at/test_save_as_cellview/test_descend_untitled_preserve/
test_untitled_reuse, test_selflog_output's six transform-KEY checks, test_fluid_editing). The
thirteen sibling `test_perform_action_*` + `test_selflog_grep_guard` are ABSENT from the AFTER fail
set = GREEN. **ZERO new deterministic failures.** (The AFTER run predates the small
adversarial-review log-format fix — `log_action_argv` vs raw `%s` — which touches ONLY
reset_inst_prop's log line and cannot affect any other test; the two affected tests were re-verified
standalone on the fixed binary and PASS, and the extra sabotages 8′/9 were run on the fixed source.)

**Adversarial review (8-axis refute panel + completeness critic, Workflow/ultracode, against a FROZEN
atom-13 snapshot).** Axes 1 (boundary log-on-success / no dropped log / no-op-still-logs), 2 (the landmine —
error message survives on failure, result cleared on success, dropped instname has no consumer), 3
(validation moved into run_core — single push_undo, no dropped step, dead `subst` genuinely dead), 5
(readonly gate — no over/under-reject), 7 (entry-point completeness — no key/menu/other caller) and 8
(build/C89/signature) all SURVIVED (clean, 0 defects). Axes 4 + 6 and the completeness critic returned
MINOR findings — ALL FIXED before commit:
- **Axis 4 (arg fidelity) + critic:** the raw `log_action("xschem reset_inst_prop %s", argv[2])` broke
  replay for an arrayed/bussed instance name carrying Tcl metacharacters — a real shipped case is
  `x2[3:0]` (its instname is literally `x2[3:0]`): the log line `xschem reset_inst_prop x2[3:0]` replays
  `[3:0]` as a Tcl command substitution ("invalid command name 3:0"), so the reset is never reproduced.
  Empirically confirmed. FIXED by emitting the referent via `log_action_argv` (`Tcl_Merge`) — the
  issue-0048 replay-safe name pattern — so it logs `xschem reset_inst_prop {x2[3:0]}` (Tcl_Merge quotes
  MINIMALLY, so a plain refdes still logs the byte-identical `xschem reset_inst_prop R1`). The critic's
  point — that the defect "ships undefended" — is closed by the new test check (a2): it places `x2[3:0]`,
  asserts the logged line is brace-quoted, AND asserts that EXACT line REPLAYS without a Tcl error and
  re-applies the reset. (The sibling `descend -inst %s`, util.c:483, shares the latent raw-%s gap; left
  for its own change — not expanded into this atom's scope.)
- **Axis 6 (grep guard):** the S1 existence rows pinned that the guard/log/reset lines each EXIST but not
  that log+reset stay NESTED inside the `if(rc == TCL_OK)` block — a de-nest that keeps all three lines
  yet moves log+reset out (back to unconditional) would pass every row. FIXED by an S7 nesting-coupling
  regex that requires `core_log_action` AND `Tcl_ResetResult` before the first `}` of the block (a de-nest
  fails closed; runtime (b) also catches it).
0 major/blocker, 0 residual after the fixes.

**Next atom:** the validating-verb class is now UNBLOCKED. The next real step is the next
validating verb — `replace_symbol` / `load_backup` / `reset_symbol` / `move_instance` /
`apply_properties` — each of which now fits the boundary because its early `TCL_ERROR` is no
longer phantom-logged. Re-verify EACH from source (the atom-10 lesson): confirm the single
`push_undo` ownership, the arg-fidelity (the logged arg must equal the arg the effect used),
and whether an equivalent key/menu exists (route it, or leave a non-equivalent dialog off).
The composite-hazard verbs (delete/cut/copy/save/reload) whose shared cores are called by
abort/merge/teardown paths remain deferred (the §4 `delete()`-is-NOT-1:1 lesson);
selection-referent replay (0005) remains the accepted config/selection-dependent class.

## 34. Refactor B ATOM 14 (2026-07-16): the SECOND VALIDATING verb, and the FIRST per-verb migration to carry a FAST-FLAG log gate (`replace_symbol`)

Atom 13 CHANGED the shared boundary to LOG-ON-SUCCESS and landed `reset_inst_prop` as its
first beneficiary. **Atom 14 is a PLAIN per-verb migration back on the now-UNCHANGED
boundary** — it touches NO shared machinery. The log-on-success change atom 13 made handles
`replace_symbol`'s validation-failure paths FOR FREE; atom 14 only migrates the verb the way
atoms 9–12 migrated theirs. Two things make it a slightly richer atom than a bare move: it is
the SECOND VALIDATING verb (proving the atom-13 boundary hosts the class, not just its first
member), and it is the FIRST per-verb migration to carry a **fast-flag log gate** (the atom-4
`save fast` axis, previously only on `save`/`reload`, applied to a `core_log_action` per-verb
form for the first time).

**The verb.** `xschem replace_symbol <inst> <new_symbol> [fast]` swaps an instance's symbol
for another (`delete_inst_node` + `inst.name = rel_sym_path(symbol)` + `match_symbol` +
`new_prop_string`; a prefix change renames the instance, e.g. `R1 → C1` swapping
`devices/res.sym → devices/capa.sym`). The optional `fast` flag is a MULTI-substitution
machinery sub-mode: on the first of many swaps you pass `{}`, on the rest `fast`, and you
`xschem redraw` at the end — it SKIPS the per-call `push_undo` (one bracketing undo for the
whole batch) and the caller redraws. `replace_symbol` was the ONLY viable candidate of the
five validating verbs the atom-13 "Next atom" note listed — a fan-out scout DISQUALIFIED the
other four (see the friction-analysis companion + the §33 note): `reset_symbol` is a low-level
bare-`inst.name` setter with NO undo/set_modify/draw ("caller must delete+reload symbols"),
called inside Tcl composites → NOT 1:1; `load_backup` is a file-buffer load
(backup-recovery/file-IO class, no undo/readonly/set_modify); `move_instance` is a
coordinate-store replay form (criterion 5, `<name> x y rot flip` + noundo/nodraw);
`apply_properties` is property-dialog machinery whose core self-undoes AND is ALREADY logged
via `editprop.c log_prop_edit_replayable`. `replace_symbol` is the one real effect verb:
validating (`argc!=4` + `get_instance`), owns `push_undo` (non-fast) + `set_modify(1)`, 1:1 (a
single branch), readonly-gated, and had NO existing log (a coverage gap).

**Migration.**
- **Branch** (`scheduler.c`, `xschem_cmds_r`) → `return perform_action("replace_symbol", argc,
  argv);` — dropping the `!xctx` guard, the per-verb `scheduler_readonly_reject`, the ~65-line
  inline effect, and the success-path `Tcl_SetResult(instname)` result (the boundary owns them).
- **`run_core` arm**: the fast-flag parse (`if(argc>4){argc=4; if(!strcmp(argv[4],"fast"))
  fast=1;}`) + the two validation gates (`argc!=4 → TCL_ERROR "needs 2 additional arguments"`,
  `get_instance(argv[2])<0 → TCL_ERROR "instance not found"`) MOVE in, ALL before the single
  `if(!fast) push_undo()`, so a bad arg mutates nothing and (via log-on-success) logs nothing.
  Then the byte-identical swap, `set_modify(1)`, `return TCL_OK`. `draw()` stays
  COMMENTED-OUT — `replace_symbol` relies on the CALLER to redraw (the old branch never drew;
  adding a `draw()` would CHANGE behaviour). Like `reset_inst_prop`, there is no core fn that
  pushes undo, so THIS arm owns the single `push_undo` — and gates it on `!fast`.
- **`core_log_action` arm**: `if(argc <= 4 || strcmp(argv[4],"fast")) { av = {"xschem",verb,
  argv[2],argv[3]}; log_action_argv(4, av); }`. TWO referents — the instance `argv[2]` AND the
  symbol path `argv[3]` — BOTH can carry Tcl metacharacters (an arrayed name `x2[3:0]`, a path
  with a space/bracket), so BOTH go through `log_action_argv` (`Tcl_Merge`), NOT a raw `%s`
  (the atom-13 arrayed-name lesson, applied pre-emptively this time rather than after a review
  catch). `Tcl_Merge` quotes MINIMALLY, so a plain refdes+path logs byte-identically to `xschem
  replace_symbol R1 devices/capa.sym`. The FAST-FLAG GATE (`!fast`) is the new element: the
  fast sub-mode skips undo AND must not be logged (a machinery/replay sub-mode is not a user
  edit). The `!fast`/`argv` reads here are IDENTICAL to `run_core`'s, so log iff `!fast` iff
  `push_undo` happened — the logged line can never diverge from the applied swap.

**The argc-clamp subtlety (locked by test (e) + the fast-gate grep row).** `run_core`
reassigns its OWN LOCAL `argc` to 4 for the fast form; `core_log_action` receives the ORIGINAL
`argc` from `perform_action` (a separate stack copy — `perform_action` runs `run_core(verb,
argc, argv)` then `core_log_action(verb, argc, argv)` with the unmutated `argc`). So
`core_log_action`'s `argc<=4` fast test reads the untouched `argv[4]`; the `argv[4]` read is
short-circuit-safe (never reached when `argc<=4`) and always in-bounds when reached (`argc>4`
⇒ argv[0..4] exist). And `core_log_action` runs ONLY on `run_core` `TCL_OK`, which requires the
original `argc>=4` (the pre-undo `argc!=4` gate), so `argv[2]`/`argv[3]` are always valid at
the log site.

**Entry map.** `replace_symbol` has **NO key, NO menu, NO GUI trigger, and NO other C/Tcl
caller** — verified by grepping keybindings/mousebindings/actions.csv, `xschem.tcl` `-command`,
`callback.c` `act_*`, and C `Tcl_Eval` (the interactive change-symbol flow uses the `editprop`
path, NOT this verb). It is a PURE SCRIPTED verb (like `reset_inst_prop` §33, unlike
`toggle_ignore`'s Shift+T §32). So there is NO `callback.c` edit and NO key-equivalence
decision; the migration is purely ADDITIVE coverage — the old branch NEVER logged. The ONE
pre-existing test that DOES exercise the verb, `test_readonly_guard.tcl` (the issue-0041
regression, in full_audit), drives `xschem replace_symbol` on a read-only buffer and requires a
read-only error — it exercises exactly the readonly path this atom RELOCATED (readonly now in
`perform_action`, before `run_core`), and it stays GREEN because that relocation preserves the
readonly-then-argc ordering. (NB `scheduler.c` ~7470 has a PRE-EXISTING copy-paste bug:
`print_spice_element` emits the wrong error string `"xschem replace_symbol: instance not
found"`. NOT a second `replace_symbol` entry, NOT atom 14's to fix — the grep guard's raw-log
scan matches `log_action("xschem replace_symbol`, not the `Tcl_SetResult`, so it is
unperturbed.)

**Behaviour delta (the ONE intentional change beyond the coverage gain).** The old branch
returned the (possibly renamed) `instname` as the Tcl result on success; the boundary's
success-path `Tcl_ResetResult` now clears it. Verified NO caller consumes `xschem
replace_symbol`'s return value (grep of `*.tcl`/`*.c`/`*.csv`: the only references are
`test_readonly_guard`'s rejection-loop list and the grep guard). The read-only gate is NOT new
(the old branch had one) — the boundary UNIFIES it onto the generic gate.

**Grep guard (`test_selflog_grep_guard.tcl`).** NEW S1 rows: the boundary branch `return
perform_action("replace_symbol", argc, argv);`; the two-arg referent build `av[3] = argv[3];`
(UNIQUE to `replace_symbol` — no other verb uses `av[3]`); the emit `log_action_argv(4, av);`
(distinct from `reset_inst_prop`'s `(3, av)`); and the FAST-FLAG GATE `if(argc <= 4 ||
strcmp(argv[4], "fast"))`. `replace_symbol` ADDED to S2 CVERBS, kept OUT of S3. An S7 block:
EXACTLY ONE `av[3]`-build + ONE `log_action_argv(4,av)` + ONE fast-gate in `scheduler.c`, ZERO
scattered raw `log_action("xschem replace_symbol"` / `scheduler_readonly_reject(...,
"replace_symbol")` in `scheduler.c`, ZERO in `callback.c`. **Collision-hardening:** atom 14's
two-arg build line `av[0] = "xschem"; av[1] = verb; av[2] = argv[2]; av[3] = argv[3];` is a
SUPERSTRING of atom-13's `reset_inst_prop` build (which ends at `argv[2];`), so the
`reset_inst_prop` S1 + S7 referent regexes were LINE-ANCHORED (`(?n)...;$`) to stay
collision-proof (reset's line ends at `argv[2];`, replace's continues to `argv[3];`; an
`argv[2]↔argv[3]` swap sabotage drops the `av[3]` count 1→0 and fails S1/S7 closed).

**Effect oracle (byte-identical effect before/after — the migration MOVES validation + gates
the log, it does not change the swap).** A `devices/res.sym` resistor placed at the origin as
R1; `xschem replace_symbol R1 devices/capa.sym` swaps its symbol, so `xschem getprop instance 0
cell::name` goes `res.sym → devices/capa.sym` (and the instance is renamed R1 → C1 by the capa
prefix). Determined empirically on the pre-migration binary. The FAILING cases pinned: `xschem
replace_symbol` / `... R1` (argc<4) each `TCL_ERROR "needs 2 additional arguments"`, `... bogus
other.sym` `TCL_ERROR "instance not found"` — each NON-EMPTY-message and, on the migrated
binary, logs NOTHING. The FAST case: `... R1 devices/capa.sym fast` MUTATES (swaps) but logs
NOTHING and pushes NO undo (one undo removes the instance, not the pre-fast symbol).

**Test `test_perform_action_replace_symbol.tcl` (36 checks, full_audit logdir_tests).** (a)
SUCCESS: +1 + swap (cell::name res.sym → devices/capa.sym) + byte-exact + dropped-result; (a2)
arrayed-name `x2[3:0]` logs BRACE-QUOTED via Tcl_Merge AND replays without a Tcl error; (b)
no-arg + one-arg + bogus each TCL_ERROR + NON-EMPTY verb-named message + no mutation + +0 log;
(c) readonly reject; (d) replay through the suppress seam re-executes without re-logging vs a
control unwrapped `source` that re-logs; (e) THE NEW FAST-GATE LOCK — the fast form swaps but
emits +0 log AND pushes no undo (one undo removes the instance, not the pre-fast symbol); (f)
undo DEPTH (non-fast) — one undo restores the prior symbol with the instance intact, a second
removes it (single `push_undo`).

**SABOTAGE ×7** (each rebuild-run-restore from the scratchpad backup `scheduler.c.atom14`, NOT
git — ~200 dirty files; each failing EXACTLY its checks): (1) inline the branch keeping
gate+log (bypass the boundary) → runtime `.tcl` PASSES, only the grep guard fails closed (S1
boundary-branch missing + S7 scattered readonly_reject present + S7 fast-gate count 2) — the
grep guard IS the structural lock; (2) raw `%s` referent instead of `log_action_argv` → the
(a2) metachar-replay checks fail (logs `x2[3:0]` unbraced; replay errors `invalid command name
"3:0"`; the swap is not reproduced) + the S1 `av[3]`/`log_action_argv(4,av)` rows and the S7
raw-log exclusivity fail closed; (3) drop the `!fast` log gate (log unconditionally) → (e)
fast-form-logs-+1 fails + S7/S1 fast-gate rows fail closed; (4) add `push_undo` in the fast path
→ (e) no-undo fails (one undo leaves the instance); (5) scattered branch log → (a) double-log +
(b)/(c) phantom-log on failed/readonly calls + S7 raw-log ==1; (6) neutralize the boundary
readonly gate → (c) all fail + S1 gate row fails closed; (7) spurious second `push_undo` in the
non-fast arm → (f) undo-depth (the symbol survives the second undo).

**Full-audit baseline diff (behind the one-button approval gate).** AFTER (atom-14 binary: 153
pass / 21 fail / 1 crash / 6 skip) vs BASELINE (`scheduler.c` reverted to HEAD, rebuilt: 152
pass / 18 fail / 0 crash / 11 skip). The load-bearing signal is CLEAN: the ONLY two
BASELINE-only fails are PRECISELY the two atom-14 tests — `test_perform_action_replace_symbol`
(its +1-log / swap / byte-exact / fast-gate checks fail when the migration is absent — the old
branch never logged) and `test_selflog_grep_guard` (the atom-14 S1/S7 rows are absent on
reverted source) — proving both load-bearing (they PASS on atom-14). The six AFTER-only fails
(`test_hover_highlight`, `test_launch_context`, `test_wire_vertex_grab`,
`test_key_graph_context`, `test_nh_anim_rearm`, `test_palette`) are WSLg-congestion flakes from
running two full GUI audits back-to-back — NONE touches the action log or `replace_symbol`
(atom 14 only edits `scheduler.c`'s `replace_symbol` arms), and ALL SIX were re-verified to PASS
standalone on the restored atom-14 binary. Everything else is the COMMON pre-existing set (the
cadence trio, the GUI set `test_ciw`/`test_hi_descend`/`test_lib_manager_gui`/
`test_reopen_readonly`, `test_lib_sweep`/`test_phase3_mints`/`test_wire_split`/`test_select_at`/
`test_save_as_cellview`/`test_untitled_reuse`/`test_descend_untitled_preserve`/
`test_fluid_editing`/`test_verb_noun_copy_move`, `test_selflog_output`'s transform-KEY checks).
ALL fourteen sibling `test_perform_action_*` + `test_selflog_grep_guard` +
`test_actionlog_suppress_gate` + `test_toggle_editmode_log` are GREEN on AFTER. **ZERO new
deterministic failures.**

**Adversarial review (6-axis refute panel + completeness critic, Workflow/ultracode, against a
FROZEN atom-14 snapshot).** All six axes returned CLEAN (0 defects): (1) the fast-flag gate —
`argc<=4 || strcmp(argv[4],"fast")` is the EXACT negation of `run_core`'s `fast` test, both
reading the same untouched original `argc`, `argv[4]` short-circuit-safe, so log iff `!fast` iff
`push_undo`; (2) validation moved into `run_core` — every effect statement present and in order,
a single `!fast`-gated `push_undo` with both gates returning before it, C89 decls hoisted, heap
balanced; (3) referent fidelity — both `argv[2]` and `argv[3]` via `Tcl_Merge` round-trip every
metachar, empty `argv[3]` logs `{}` and replays, the clamp drops only ignored args, and
rename-on-success is the ACCEPTED whole-log mutable-referent model (not a new hazard); (4)
readonly gate + dropped result + boundary unchanged — `perform_action` is ABSENT from the diff,
the readonly-then-argc ordering mirrors the old branch, the dropped instname has no consumer;
(5) grep-guard drift — the `(?n)...;$` anchor genuinely resolves the `reset_inst_prop`
superstring collision (unanchored 2, anchored 1) and an `argv[2]↔argv[3]` swap fails S1/S7
closed; (6) entry-point completeness + build/C89 + test rigor. The COMPLETENESS CRITIC raised
ONE MINOR gap — a VERIFICATION-completeness gap, NOT a code defect: axis 6's "no caller outside
scheduler.c" overlooked that `test_readonly_guard.tcl` (the issue-0041 regression) drives
`xschem replace_symbol` on a read-only buffer, exercising the exact readonly path this atom
RELOCATED; no axis cited it. Closed here: `test_readonly_guard` was re-run and stays GREEN
(`READONLY_GUARD_TEST_PASS`, 31/31 mutating verbs refused incl. `replace_symbol`), the atom's
own check (c) independently locks the readonly reject, and the entry map above now cites it. 0
major/blocker, 0 code findings, 0 residual.

**Next atom:** `reset_symbol`, `load_backup`, `move_instance`, `apply_properties` are all
DISQUALIFIED (above), so the validating-verb shortlist the atom-13 note carried is now
EXHAUSTED. The next atom needs a FRESH grep-scout for a 1:1, always-mutating,
unconditional-log verb (re-verify from source, the atom-10 lesson) — with `log_action_argv` for
any string referent (the arrayed-name rule) and the key/menu-equivalence check. The
composite-hazard verbs (delete/cut/copy/save/reload) whose shared cores are called by
abort/merge/teardown remain deferred (the §4 `delete()`-is-NOT-1:1 lesson); selection-referent
replay (0005) remains the accepted config/selection-dependent class.

## 35. Refactor B ATOM 15 (2026-07-17): the FIFTEENTH per-verb migration — a BARE no-arg friction-free verb, the SECOND to share the attach_labels_to_inst core, adding the read-only gate as a correctness fix (`show_unconnected_pins`)

Atom 14 EXHAUSTED the validating-verb shortlist the atom-13 note carried
(`reset_symbol`/`load_backup`/`move_instance`/`apply_properties` all DISQUALIFIED). **Atom 15 is a
PLAIN per-verb migration back on the now-UNCHANGED atom-13 log-on-success boundary** — it touches NO
shared machinery. A fresh 279-branch fan-out scout classified all 22 dispatch groups and left EXACTLY
TWO candidates: `show_unconnected_pins` (the friction-free winner) and `embed_rawfile` (runner-up,
DEFERRED — it carries a `~` path expansion to relocate, a STRING file-path referent needing
`log_action_argv`/`Tcl_Merge`, and a replay-fidelity risk from re-reading an external file).
`show_unconnected_pins` is the BARE no-arg, always-mutating, 1:1, unconditional-log verb the scout
wanted — the same shape as `floaters_from_selected_inst` (atom 10) / `toggle_ignore` (atom 12).

**The verb.** `xschem show_unconnected_pins` (the hilight-menu "Show labels on unconnected instance
pins") selects every instance and places a `lab_show.sym` label on each pin NOT connected to a wire /
label / other instance's pin. Its core `show_unconnected_pins()` (netlist.c:1594) is
`select_element(all)` + `rebuild_selected_array` + `prepare_netlist_structs(1)` + `traverse_node_hash`
+ `attach_labels_to_inst(2)` + `unselect_all(1)` — the netlisting `lab_show` sub-mode of the atom-11
core.

**Migration.**
- **Branch** (`scheduler.c` ~10021, `xschem_cmds_s`): the old inline body `{ if(!xctx){...}
  show_unconnected_pins(); Tcl_ResetResult(interp); }` becomes `return
  perform_action("show_unconnected_pins", argc, argv);` — dropping the `!xctx` guard and the
  `Tcl_ResetResult` (the boundary owns both; the old branch already returned an EMPTY result, so the
  dropped `Tcl_ResetResult` is a zero success-result delta — nothing to preserve).
- **`run_core` arm**: a BARE arm `show_unconnected_pins(); return TCL_OK;` — NO `argc/argv`, NO
  validation, NO `push_undo()`, NO `draw()`. The core's RAW `attach_labels_to_inst(2)` OWNS the single
  `push_undo` (`place_symbol(..., 1/*to_push_undo*/)` on the first placed label), `set_modify(1)`
  (actions.c:2316) and `draw()` (actions.c:2322–2326); adding one here would DOUBLE-push (the atom-1
  no-double-push rule, locked by test (f) undo-DEPTH).
- **`core_log_action` arm**: NONE. A bare verb falls to the DEFAULT `log_action("xschem %s", verb)`,
  emitting `xschem show_unconnected_pins` byte-identically to `floaters`/`toggle_ignore`. NO per-verb
  branch, NO string referent, NO `log_action_argv`.

**THE SHARED-SUB-STEP LOCK — re-verified from the OTHER side (the atom-11 §31 template).**
`attach_labels_to_inst()` is the core of the `attach_labels` verb (atom 11) AND is called RAW by
`show_unconnected_pins()` (interactive=2). That raw call stays SILENT below the boundary — its log
lives in `core_log_action` under the `attach_labels` verb, NOT inside the C fn — so routing
`show_unconnected_pins` double-logs NOTHING with the `attach_labels` verb (the boundary wraps the VERB
DISPATCH, not the C fn). Atom 11 recorded this lock from the `attach_labels` side ("its core is ALSO
a raw sub-step of show_unconnected_pins"); atom 15 is its INVERSION — the sub-step's OWNER verb now
also rides the boundary, and the lock still holds. Test (g) drives `xschem show_unconnected_pins`,
asserts it MUTATES (2 labels placed) yet emits ZERO `xschem attach_labels` lines; sabotage 6 (a
self-log inside `attach_labels_to_inst`) fails BOTH atom-15 (g) AND the `attach_labels` sibling — the
shared core seen from both verbs.

**The read-only decision — the boundary ADDS a gate the branch NEVER HAD (a CORRECTNESS FIX, the
floaters §30 / toggle_ignore §32 template).** Verified empirically on the pre-migration binary: `xschem
show_unconnected_pins` on a read-only cell PLACED the `lab_show` labels (`place_symbol` ran; only
`set_modify` was read-only-suppressed) and returned `rc=0` — a scattered 0041/0051-class
mutation-on-a-read-only-cell gap. The boundary's ONE gate now CLOSES it: the verb correctly REFUSES on
a read-only cell (`TCL_ERROR`, verb-named message `xschem show_unconnected_pins: schematic is
read-only …`, no placement, no log). This is the ONE deliberate user-facing behaviour delta of the
atom — a bug fix — and it is safe precisely BECAUSE `show_unconnected_pins` has NO read-only-safe form
(every path places labels; there is no ERC-only query the all-or-nothing gate would OVER-reject,
contrast `check_unique_names`, §30). The WRITABLE effect + log are byte-identical to pre-migration.

**THE NO-OP-STILL-LOGS PROPERTY (§30/§32).** A sheet with NO unconnected pins (a resistor whose both
pins are covered by a wire) places NOTHING — `attach_labels_to_inst` calls no `place_symbol`, so no
`push_undo`/`set_modify`/`draw`. But `show_unconnected_pins()` is void and `run_core` returns TCL_OK,
so under log-on-success (atom 13) the boundary STILL emits one `xschem show_unconnected_pins` line —
idempotent + replayable, the CORRECT behaviour. Test (b) locks it.

**Entry map — menu-only, verified by grepping the LIVE repo (the atom-16 lesson).** (1) the **scheduler
branch** → `return perform_action(...)`, reached by scripted `xschem show_unconnected_pins`, the
**hand-written hilight menu** item (`xschem.tcl:14454` `-command "xschem show_unconnected_pins"`, NOT
`menu_action_logged`-wrapped) and the command palette (`actions.csv:109`
`hilight.show_labels_on_unconnected_instance_pins` runs the verb RAW). (2) there is **NO key** — absent
from `keybindings.csv`/`mousebindings.csv`, NO `callback.c` `act_*` handler, NO legacy switch. So there
is NO `callback.c` edit. The **Shift+H** key is `act_attach_labels` → `attach_labels_to_inst(1)` (the
interactive-DIALOG variant), a DIFFERENT path that does NOT pass through `show_unconnected_pins` and is
left untouched.

**Grep guard (`test_selflog_grep_guard.tcl`).** ADDED: the S1 scheduler boundary-branch row (`return
perform_action("show_unconnected_pins", argc, argv);`), `show_unconnected_pins` in the S2 CVERBS set,
and an S7 block MIRRORING floaters/toggle_ignore (scheduler.c AND callback.c ZERO scattered
`log_action("xschem show_unconnected_pins")` — the log is the shared `%s` default, so NO per-verb
literal exists — plus scheduler.c ZERO scattered `scheduler_readonly_reject(...,
"show_unconnected_pins")`, the branch never had one). NO new `core_log_action` S1 row — it uses the
existing DEFAULT `xschem %s` row, whose roster note gained `show_unconnected_pins`. `show_unconnected_pins`
stays IN S2 CVERBS, OUT of S3.

**Effect oracle (byte-identical writable effect before/after — atom 15 MOVES the log site + ADDS the
gate).** A `devices/res.sym` resistor at the origin has TWO pins (0,−30 & 0,30), both unconnected, so
`xschem show_unconnected_pins` places TWO `lab_show.sym` labels (p1,p2) → **instance count 1 → 3**, a
clean deterministic oracle determined empirically on the pre-migration binary. Undo DEPTH proves the
single push: ONE undo removes both labels (3 → 1), a SECOND removes the instance (1 → 0) — a
double-push would insert an identical third snapshot so R1 would SURVIVE two undos (the discriminator
that caught sabotage 3).

**Verified:** `test_perform_action_show_unconnected_pins.tcl` (24 checks, full_audit logdir_tests): (a)
+1 from EACH of scripted / synthetic dedup-wrapper drive, and the WRITABLE effect applies (instances 1 →
3, two lab_show); (b) NO-OP STILL LOGS — a no-unconnected-pins sheet places nothing but STILL logs +1
(catch-wrapped so a regressed TCL_ERROR arm reports a clean FAIL, the atom-13 (e) lesson); (c) readonly
reject (the CORRECTNESS FIX) — TCL_ERROR, verb-named message, no placement, no log; (d) byte-exact
`xschem show_unconnected_pins`; (e) replay re-executes through the suppress seam without re-logging vs a
control unwrapped `source` that re-logs; (f) undo DEPTH (single push_undo, no double); (g) the
SHARED-SUB-STEP LOCK — `xschem show_unconnected_pins` mutates yet emits ZERO `xschem attach_labels`
lines; (h) the menu `-command` is `xschem show_unconnected_pins` verbatim and rides the boundary.
**Sabotage ×6** (each rebuild-run-restore from the scratchpad backup `scheduler.c.atom15`, NOT git —
~200 dirty files; each failing EXACTLY its checks): (1) neutralise the boundary route (inline branch
KEEPING gate+effect+log) → the runtime `.tcl` STILL PASSES while the grep guard's S1 boundary row + S7
scattered-log + S7 scattered-readonly-reject all fail closed (the grep guard is the load-bearing
structural lock); (2) neutralise the boundary readonly gate → the (c) readonly checks all fail
(mutates + logs on a read-only cell); (3) spurious `push_undo` in the run_core arm → the (f)
second-undo depth check fails (R1 survives two undos) — the no-double-push discriminator; (4) make the
arm return TCL_ERROR on the no-op (nothing-placed) path → the (b) no-op-still-logs check fails
(log-on-success drops it); (5) scattered branch `log_action("xschem show_unconnected_pins")` → the (a)
exactly-+1 checks double-log (and (b)/(c)/(e)/(h) log counts drift) + the S7 scattered-log fails
closed; (6) a self-log inside the SHARED `attach_labels_to_inst()` core → the (g) shared-sub-step lock
fails AND the `attach_labels` sibling's (a)/(e) fail (the atom-11 lock seen from BOTH verbs). The
change-adjacent siblings stay green: all fourteen other `test_perform_action_*` +
`test_selflog_grep_guard` + `test_actionlog_suppress_gate` + `test_toggle_editmode_log`, and
ESPECIALLY `test_perform_action_attach_labels` (the SHARED core — stays green + does not double-log).

**Adversarial review (8-axis refute panel + completeness critic, Workflow/ultracode, against a FROZEN
atom-15 snapshot): verdict CLEAN, zero confirmed defects, zero refuted axes.** All 8 axes returned
`refuted=false / severity=none`: (1) bare-verb migration correctness — the arm calls the void core,
returns TCL_OK, uses no argc/argv, relocates no validation, drops no step; the dropped `!xctx` guard +
`Tcl_ResetResult` are byte-identically owned by `perform_action` (same message, same reset-on-success);
(2) push_undo ownership — exactly ONE push per invocation (`place_symbol`'s `first_call &&
to_push_undo`), the arm + boundary add none, and the no-op keeps `first_call=1` so it pushes nothing (no
empty snapshot), sabotage-confirmed; (3) the SHARED sub-step lock — netlist.c + `attach_labels_to_inst()`
carry ZERO `log_action`, so the raw `attach_labels_to_inst(2)` call is silent and routing
`show_unconnected_pins` emits exactly one line and zero `attach_labels` lines; (4) readonly gate additive
AND correct — no read-only-safe form exists (every path reaches `place_symbol`, friction Criterion 1),
so the all-or-nothing gate cannot over-reject (the `check_unique_names` hazard is absent), and the
pre-migration branch genuinely lacked the gate (`place_symbol` ran on a read-only cell — the issue-0074
family); (5) no-op-still-logs — the void core always returns TCL_OK so a zero-unconnected-pins sheet
still logs +1, replay idempotent (a re-run finds the placed lab_show pin covering the pins, so it places
nothing more); (6) grep-guard drift — the S1/S2/S7 rows + `%s` roster note pass and fail closed on
realistic re-scatter, no collision with `attach_labels`/`attach_labels_to_inst` literals; (7)
entry-point completeness — exactly TWO entry points (hilight menu + command palette), both routed, no
key/mouse/callback bypass, the Shift+H `attach_labels` path disjoint; (8) build/C89 — the snapshot is
byte-identical to the live source and compiles clean under `-std=c89 -pedantic -Wall -Wextra` with zero
new warnings. The completeness critic raised ONE informational NIT (not a code defect): check (a)'s
comment called the SYNTHETIC `menu_action_logged` drive "the menu wrapper" path, contradicting check (h)
which correctly notes the real hilight menu is a hand-written raw `-command` (not
`menu_action_logged`-wrapped); FIXED before commit by rewording the comment to describe the drive as a
synthetic dedup-wrapper exercise. 0 blocking, 0 code findings, 0 residual.

**Full-audit baseline diff (behind the one-button approval gate).** AFTER (atom-15 binary: 167 pass /
15 fail / 0 crash / 0 skip, total 182) vs BASELINE (`scheduler.c` reverted to HEAD 5e7469af, rebuilt:
163 pass / 18 fail / 1 crash/timeout / 0 skip). The load-bearing signal is CLEAN: the load-bearing
BASELINE-only fails are PRECISELY the two atom-15 tests — `test_perform_action_show_unconnected_pins`
(its +1-log / effect / readonly-reject / no-op checks fail when the migration is absent — the old
branch never logged and PLACED labels on a read-only cell) and `test_selflog_grep_guard` (the atom-15
S1/S7 rows scan for `scheduler.c` code absent on the reverted source) — proving both load-bearing (they
PASS on atom-15). Two OTHER BASELINE-only fails (`test_action_log_libmgr` FAIL + `test_actionlog_suppress_gate`
TIMEOUT) are WSLg-congestion flakes from the BASELINE run (which ran SECOND, back-to-back after the
AFTER GUI batch) — NEITHER is touched by atom 15 (it only edits `scheduler.c`'s `show_unconnected_pins`
arms) and BOTH were re-verified to PASS STANDALONE on the atom-15 binary. There are ZERO AFTER-only
fails. Everything else is the COMMON pre-existing set (the cadence pair
test_cadence_descend_newwin_ro/test_cadence_drag, the GUI set
test_ciw/test_hi_descend/test_lib_manager_gui/test_reopen_readonly,
test_lib_sweep/test_phase3_mints/test_wire_split/test_select_at/test_save_as_cellview/
test_descend_untitled_preserve/test_untitled_reuse/test_fluid_editing, and test_selflog_output's
transform-KEY checks). ALL fifteen sibling `test_perform_action_*` + `test_selflog_grep_guard` +
`test_actionlog_suppress_gate` + `test_toggle_editmode_log` are GREEN on AFTER. **ZERO new deterministic
failures.**

**Next atom:** `embed_rawfile` is the DEFERRED runner-up — its three wrinkles (the `~` path expansion
to relocate, the STRING file-path referent needing `log_action_argv`/`Tcl_Merge`, the external-file
replay-fidelity risk) make it a richer atom than a bare move. The atom-15 scout left EXACTLY TWO
candidates, so beyond `embed_rawfile` the next atom needs ANOTHER fresh grep-scout for a 1:1,
always-mutating, unconditional-log verb (re-verify from source, the atom-10 lesson). The
composite-hazard verbs (delete/cut/copy/save/reload) whose shared cores are called by
abort/merge/teardown remain deferred (the §4 `delete()`-is-NOT-1:1 lesson); selection-referent replay
(0005) remains the accepted config/selection-dependent class.

## 36. Refactor B ATOM 16 (2026-07-17): the SIXTEENTH per-verb migration — the DEFERRED runner-up from the atom-15 scout, a HYBRID of the reset_inst_prop single-string-referent/argc-gate and the floaters/show_unconnected_pins core-owns-undo templates (`embed_rawfile`)

The atom-15 fan-out scout left EXACTLY TWO friction-free candidates: `show_unconnected_pins` (atom 15,
DONE) and `embed_rawfile` (the DEFERRED runner-up). **Atom 16 lands `embed_rawfile` — a PLAIN per-verb
migration on the now-UNCHANGED atom-13 log-on-success boundary that touches NO shared machinery.** It is
not a bare move: it is a HYBRID of two prior templates — the `reset_inst_prop` (§33) SINGLE-STRING-referent
+ argc-GATE template crossed with the `floaters`/`show_unconnected_pins` (§30/§35) CORE-OWNS-ITS-OWN-UNDO
template — plus a `~` path expansion relocated into `run_core`.

**The verb.** `xschem embed_rawfile <path>` base64-encodes a raw simulation file into the SINGLE selected
element's `spice_data` attribute (read back later by `raw_read_from_attr`, save.c:930). A pure SCRIPTED
verb — the user types it after selecting a component.

**Migration.**
- **Branch** (`scheduler.c` ~2286, `xschem_cmds_e`): the old inline body `{ char f[...]; if(!xctx){...}
  if(argc>2){ regsub ~ expand; embed_rawfile(f); } Tcl_ResetResult(interp); }` becomes `return
  perform_action("embed_rawfile", argc, argv);` — dropping the `!xctx` guard + the `Tcl_ResetResult` (the
  boundary owns both; the old branch returned an EMPTY result, a zero success-result delta) + the local
  `char f[]` (moved into `run_core`).
- **`run_core` arm**: MOVES the `~/` expansion IN verbatim (`my_snprintf(f,S(f),"regsub {^~/} {%s} {%s/}",
  argv[2],home_dir); tcleval(f); my_strncpy(f,tclresult(),S(f));`) — `home_dir` (globals.c:209, extern
  xschem.h) is a global reachable here. It carries a VALIDATING-LITE `argc<3 -> TCL_ERROR "needs a file
  argument"` gate BEFORE any mutation (the reset_inst_prop §33 shape). Then `embed_rawfile(f)` — NO
  `push_undo`/`set_modify`/`draw`: the core `embed_rawfile()` (draw.c:4089) OWNS the SINGLE `push_undo` +
  `set_modify` when it embeds (`lastsel==1 && sel_array[0].type==ELEMENT`) and draws NOTHING; adding one
  here would DOUBLE-push (the atom-1 rule, locked by test (f) undo-DEPTH).
- **`core_log_action` arm**: logs the RAW `argv[2]` (NOT the expanded `f`) via `log_action_argv`/`Tcl_Merge`
  — `const char *ev[3]; ev[0]="xschem"; ev[1]=verb; ev[2]=argv[2]; log_action_argv(3, ev);`. The array is
  named `ev` (NOT `av`) to stay TEXTUALLY DISTINCT from `reset_inst_prop`'s byte-identical `av[...]` build:
  the grep guard line-anchors BOTH `(?n)...;$`, and a shared name would make each verb's count == 2,
  breaking BOTH verbs' exclusivity rows (the collision the migration explicitly hardens against).

**THE ARGC GATE — a VALIDATING-LITE behaviour delta (test (b)).** The old branch SILENTLY no-op'd on a
missing arg (`if(argc>2)` skipped; `rc=0`). The migration makes `argc<3` an early `TCL_ERROR` +
verb-named message, and — via log-on-success (atom 13) — records NO phantom line. It also PREVENTS a
latent crash: the OLD `if(argc>2){...} return TCL_OK` shape, ported naively, would let a no-arg call reach
`core_log_action` and read `argv[2]==NULL` → `Tcl_Merge` crash. The gate returns before that. The one
design choice (vs keeping the silent no-op and letting log-on-success log a useless bare line) is cleaner.

**THE READONLY GATE — a CORRECTNESS FIX (test (c), the floaters §30 / show_unconnected_pins §35 template).**
Verified empirically on the pre-migration binary: `xschem embed_rawfile <path>` on a read-only cell
EMBEDDED (push_undo + set_modify + subst_token ran, spice_data set) and returned `rc=0` — a scattered
0041/0051-class mutation-on-a-read-only-cell gap. The boundary's ONE gate now CLOSES it: the verb REFUSES
(`TCL_ERROR`, `xschem embed_rawfile: schematic is read-only …`, no embed, no log). Safe precisely BECAUSE
embed_rawfile has NO read-only-safe form — every path with a selected element mutates; `argc<3` and
nothing-selected are no-ops, not queries — so the all-or-nothing gate cannot OVER-reject (contrast
`check_unique_names`, §30).

**WRINKLE — external-file replay fidelity (test (e)) — an ACCEPTED caveat, NOT a new hazard.** The log
records the PATH, not the base64 content (too large to inline). Replay RE-READS the file, so a round-trip
where the file is PRESENT replays the SAME `spice_data` (asserted). A file removed between record and
replay replays an empty/cleared attribute — because `base64_from_file` (save.c:900) returns NULL on a
missing/non-regular file and `subst_token` BLANKS `spice_data`, so a missing file is a MUTATION, not a
failure. This property is IDENTICAL pre- and post-migration — the migration introduces no new hazard.
Selection-dependence (embeds into the single selected element; the log does not encode WHICH instance) is
the accepted `floaters`/`attach_labels`/`toggle_ignore` config/selection-dependent model, not a blocker.

**Entry map — a PURE SCRIPTED verb, verified by grepping the LIVE repo (the atom-10/atom-14 lesson).**
NO key (`keybindings.csv`/`mousebindings.csv`), NO menu `-command` (`xschem.tcl`), NO command palette
(`actions.csv`), NO `callback.c` `act_*`/legacy switch, NO Tcl caller anywhere (`embed_rawfile(` is called
ONLY at its own scheduler branch; the only other repo references are the `xschem.h` prototype + the
`xschem_subcommands.txt` completion list). So there is NO `callback.c` edit and NO key-equivalence decision
(like `reset_inst_prop` §33 / `replace_symbol` §34).

**Grep guard (`test_selflog_grep_guard.tcl`).** ADDED to the `src/scheduler.c` S1 MANIFEST: the boundary
branch row (`return perform_action("embed_rawfile", argc, argv);`), the line-anchored referent-build row
(`(?n)ev[0] = "xschem"; ev[1] = verb; ev[2] = argv[2];$`) and the emit row (`log_action_argv(3, ev);`).
ADDED `embed_rawfile` to the S2 CVERBS set (kept OUT of S3). ADDED an S7 block: EXACTLY ONE `ev`-build +
EXACTLY ONE `log_action_argv(3, ev)` + ZERO scattered raw `log_action("xschem embed_rawfile"` (scheduler.c
AND callback.c) + ZERO scattered `scheduler_readonly_reject(..., "embed_rawfile")` — PLUS a COLLISION GUARD
re-asserting `reset_inst_prop`'s `av`-build + `log_action_argv(3, av)` each stay == 1 (a regression that
renamed embed's array back to `av` fails closed here and on reset_inst_prop's own rows).

**Effect oracle (byte-identical WRITABLE effect before/after — atom 16 MOVES the `~` expansion + ADDS the
argc/readonly gates + gates the log).** A `devices/res.sym` resistor at the origin, SELECTED, + a small raw
file on disk. `xschem embed_rawfile <path>` sets `spice_data` empty → a base64 blob (the "hello raw data
12345" fixture logs `aGVsbG8gcmF3IGRhdGEgMTIzNDU=`). Undo DEPTH proves the single push: ONE undo clears the
`spice_data` and a SECOND removes the instance — under a double-push undo#1 ALSO clears the attribute (so
undo#1 is NOT the discriminator), but undo#2 restores an identical extra R1-empty snapshot so the INSTANCE
would SURVIVE (`instances==1`) instead of winding back to empty (`instances==0`) — the second-undo
discriminator that caught sabotage 3. Determined empirically on the pre-migration binary (deltas confirmed
on the migrated binary: no-arg rc 0→TCL_ERROR, readonly rc 0-embedded→TCL_ERROR-no-embed, `~/` + undo-depth
unchanged, missing-file still blanks).

**Verified:** `test_perform_action_embed_rawfile.tcl` (full_audit logdir_tests, self-deferring guard): (a)
+1 log + effect (spice_data → base64) + byte-exact Tcl_Merge form; (a2) a metachar path (space+bracket)
logs BRACE-QUOTED and REPLAYS without a Tcl error + re-embeds; (b) the argc gate — bare `xschem
embed_rawfile` → TCL_ERROR + non-empty message + +0 log + no mutation; (c) readonly reject (the correctness
fix) — TCL_ERROR + verb-named msg + no embed + no log; (d) `~/` expansion — embeds IDENTICALLY to the
absolute path, the log records the RAW `~/` form (not the expanded $HOME), replay re-expands; (e) replay
through the suppress seam applies the effect without re-logging (external file present → SAME spice_data,
wrinkle-3 fidelity) vs a control `source` that re-logs; (f) undo DEPTH (single push_undo). **Sabotage ×6**
(each rebuild-run-restore from the scratchpad backup `scheduler.c.atom16`, NOT git — ~200 dirty files;
each failing EXACTLY its checks): (1) neutralise the boundary route (inline branch KEEPING gate+expansion+
log) → the runtime `.tcl` STILL PASSES while the grep guard's S1 boundary-branch row + S7 emit + S7
scattered-readonly-reject fail closed (the grep guard is the load-bearing structural lock); (2) neutralise
the readonly gate → the (c) checks fail; (3) spurious `push_undo` in the arm → the (f) second-undo depth
check fails (the instance survives) — the no-double-push discriminator; (4) log on the argc<3 failure path →
the (b) validation-not-logged checks fail; (5) raw `%s` referent instead of `log_action_argv` → (a2)
metachar-replay fails + the S1/S7 `ev`-form rows fail closed; (6) move the `~` expansion OUT (embed the
unexpanded `~/` literal) → the (d) expansion/replay checks fail. The change-adjacent siblings stay green:
all fifteen other `test_perform_action_*` + `test_selflog_grep_guard` + `test_actionlog_suppress_gate` +
`test_toggle_editmode_log`, and ESPECIALLY `test_perform_action_reset_inst_prop` (the shared
single-string-referent template — stays green + its `av`-build count does NOT collide with embed's `ev`).

**Adversarial review (10-axis refute panel + completeness critic, Workflow/ultracode, against a FROZEN
atom-16 snapshot): verdict CLEAN — `ship-with-doc-note`, zero code defects.** All ten axes returned
`defect_found=false`: (1) branch→boundary — `perform_action` reproduces the dropped `!xctx` guard (same
`not_avail`, checked before the readonly gate) + the success-path `Tcl_ResetResult`; the direct `return
perform_action(...)` is safe under the `cmd_found` protocol (defaults to 1, an early return leaves it
"found"); no consumer of the old empty success-result exists; (2) the `~/` expansion is behaviourally
byte-faithful (`home_dir` extern-global reachable + populated post-init, same regsub, same buffer, the
`}`/`[` behaviour identical pre/post — the pre-existing injection risk correctly left untouched); (3)
push_undo ownership — the core owns EXACTLY ONE push inside the selection guard, the arm adds none (no
double-push), the no-op pushes zero, and the readonly fix is a strict REDUCTION in spurious pushes; (4) the
argc<3 gate returns before any mutation, log-on-success drops the phantom log, `core_log_action` is reached
only after argc>=3 so its `argv[2]` read is never out-of-bounds, and the error message survives the
success-only `Tcl_ResetResult`; (5) referent fidelity — logging RAW `argv[2]` (not expanded `f`) is
correct; a metachar path round-trips via `Tcl_Merge` and the `~/` form re-expands on replay, no divergence
from the applied effect; (6) readonly gate additive + no over-reject (no read-only-safe form exists); (7)
the external-file replay caveat is IDENTICAL pre/post (no new hazard) and selection-dependence is the
accepted floaters-class model; (8) grep-guard drift + the `reset_inst_prop` COLLISION — the `ev`-vs-`av`
naming holds by substring analysis AND empirically (every cross-match 0, self-match 1), no brace/
substitution trap, no sibling perturbation, the collision-guard rows re-assert `reset_inst_prop`'s
`av`-build/emit stay ==1 (this axis's original panel agent hit a transient 529 Overloaded and was re-run
independently to CLEAN); (9) entry-point completeness — a PURE SCRIPTED verb, no key/menu/palette/callback/
Tcl caller; (10) C89/build — decls at block top, compiles clean. The completeness critic returned
`review_complete=true`, no functional defect missed, raising two NON-code items: (i) the three `§36`
citations (this section, now added, resolves them); (ii) a prose NIT in test check (f) — the double-push
discriminator is the SECOND undo (`instances==0`), not the first (undo#1 clears `spice_data` under BOTH
single- and double-push); the assertion was already correct, the comment was tightened before commit.

**Full-audit baseline diff (behind the one-button approval gate).** AFTER (atom-16 binary: 168 pass / 15
fail / 0 crash / 0 skip, total 183) vs BASELINE (`scheduler.c` reverted to HEAD 98d7cd73, rebuilt: 167 pass
/ 16 fail / 0 crash). The load-bearing signal is CLEAN: the BASELINE-only fails are PRECISELY the two
atom-16 tests — `test_perform_action_embed_rawfile` (its +1-log / effect / argc-gate / readonly-reject
checks fail when the migration is absent — the old branch never logged, silently no-op'd on a missing arg,
and embedded on a read-only cell) and `test_selflog_grep_guard` (the atom-16 S1/S7 rows scan for
`scheduler.c` code absent on the reverted source) — proving both load-bearing (they PASS on atom-16). The
ONE AFTER-only fail, `test_fluid_editing`, is a WSLg-congestion flake (the BASELINE ran SECOND back-to-back
after the AFTER GUI batch, so its transient pass on BASELINE reads as an AFTER-only fail): atom 16 edits
ONLY `scheduler.c`'s `embed_rawfile` arms + the test/doc, touches NOTHING in the fluid-editing path, and
`test_fluid_editing` was re-verified to PASS STANDALONE ×2 (26/26) on the atom-16 binary. Everything else is
the COMMON pre-existing set (14: the cadence pair test_cadence_descend_newwin_ro/test_cadence_drag, the GUI
set test_ciw/test_hi_descend/test_lib_manager_gui/test_reopen_readonly, test_lib_sweep/test_phase3_mints/
test_wire_split/test_select_at/test_save_as_cellview/test_descend_untitled_preserve/test_untitled_reuse,
and test_selflog_output's transform-KEY checks). ALL sixteen sibling `test_perform_action_*` +
`test_selflog_grep_guard` + `test_actionlog_suppress_gate` + `test_toggle_editmode_log` are GREEN on AFTER.
**ZERO new deterministic failures.**

**Next atom:** the friction-free pool from the atom-15 scout is now EXHAUSTED (both candidates spoken for).
The NEXT atom needs ANOTHER fresh grep-scout of the remaining mutating verbs for a 1:1, always-mutating,
unconditional-log verb (re-verify from source, the atom-10 lesson). DEFER the composite-hazard verbs
(delete/cut/copy/save/reload) whose shared cores are called by abort/merge/teardown (the §4
`delete()`-is-NOT-1:1 lesson); selection-referent replay (0005) remains the accepted
config/selection-dependent class.

## 37. Refactor B ATOM 17 (2026-07-17): the SEVENTEENTH per-verb migration — the SILENT-MUTATOR twin of break_wires, the mouse-position wire cut `break_wires_at_point` (`wire_cut`)

The friction-free pool went EMPTY at atom 16. A fresh 22-group grep-scout (the atom-16 fan-out) named
`wire_cut` as the LEAST-friction genuine coverage gain: a **SILENT MUTATOR** (it logged NOTHING before) and
the **direct structural twin of break_wires** (atom 9, §29). break_wires' §29 note already flagged
`break_wires_at_point()` (check.c) as the SEPARATE Alt-Right `wire_cut` gesture core kept OFF break_wires'
boundary; **atom 17 puts THAT core on the boundary.** It is NOT strictly friction-free — it carries TWO
wrinkles: route only the coord form, and decide the interactive-gesture callback sites — both handled by the
accepted rotate/flip/break_wires patterns.

**The verb.** `xschem wire_cut [x y] [noalign]` cuts a wire at a point. The SCRIPTED coord form
(`argc>3`) splits the wire whose body the point touches (via `break_wires_at_point`, check.c:501); the
no-coord form ARMS the interactive Alt-Right cut gesture (ui_state only — no mutation).

**Migration (scheduler.c only — callback.c/check.c UNCHANGED = option A).**
- **Branch** (`xschem_cmds_w`): SPLIT on the coord form. `if(argc > 3) return perform_action("wire_cut",
  argc, argv);` sends the scripted/replay MUTATION through the boundary; the no-coord GESTURE-START `else`
  stays RAW (`ui_state |= MENUSTART; ui_state2 = align ? MENUSTARTWIRECUT : MENUSTARTWIRECUT2`), mutates
  NOTHING and logs NOTHING — exactly the rotate/flip **STARTMOVE-stays-raw** split (§26/§27: the standalone
  form crosses, the during-gesture arm stays raw). The `!xctx` guard STAYS in the branch (the gesture-START
  path dereferences `xctx->ui_state`); the coord form re-checks it inside `perform_action` (harmless
  redundancy). The two Alt-Right menu items (`xschem.tcl` ~14403/14405, `wire_cut` + `wire_cut noalign`) are
  BOTH the no-coord gesture-START form → they reach ONLY this `else`.
- **`run_core` arm**: parse `noalign`, `break_wires_at_point(atof(argv[2]), atof(argv[3]), align)`, `return
  TCL_OK`. **NO `push_undo`/`draw`** — `break_wires_at_point()` OWNS a **CONDITIONAL SINGLE `push_undo`**
  (only on the first actual split, check.c:522) + its own `draw()` + dot (check.c:532–544); adding one here
  would DOUBLE-push (the atom-1 rule, locked by test (f) undo-depth). Returns `void` → the arm ALWAYS
  returns TCL_OK; a **point OFF any wire is a NO-OP** (`changed` stays 0 → no push, no draw) that still
  succeeds → **no-op-still-logs** (§30). Reached only via the branch's `argc>3` guard, so `argv[2]/argv[3]`
  are always present.
- **`core_log_action` arm**: logs the **RAW click coords** `argv[2]/argv[3]` via **`%.16g`** (the rotate/flip
  pivot convention — **NOT `log_action_argv`**: numeric coords carry no Tcl-metacharacter referent to
  brace-quote), in **TWO forms** like break_wires: aligned `xschem wire_cut x y` and `xschem wire_cut x y
  noalign`. `align` is applied INSIDE the core (`closest_point_calculation`), so **raw-coords + the flag
  replay IDENTICALLY** (replay re-snaps). The `align` read here uses the SAME loop as `run_core`'s arm, so
  the logged form can never diverge from the applied cut.

**COORD FIDELITY — the atom-17 analogue of pivot fidelity.** The log records the RAW argv coords, NOT the
snapped point the core computes. Empirically: `wire_cut 47 3` (cadsnap=20) cuts at x=**40** (snapped) and
logs `xschem wire_cut 47 3`; replay re-snaps 47→40 → identical. `wire_cut 47 3 noalign` cuts at x=**47** and
logs `xschem wire_cut 47 3 noalign`; replay → identical. Logging the snapped point instead would still
replay-snap on top of an already-snapped coord (idempotent for the aligned form) but DIVERGES for the noalign
form — so RAW coords are the correct, uniform choice (locked by test (a2) + sabotage 5).

**THE 1:1 TEST (C3).** `break_wires_at_point()` is called ONLY by `wire_cut`'s own entry points: the
scheduler branch (now via `run_core`) + the four callback.c Alt-Right gesture-completion sites
(callback.c:2506/2510/6538/6544, `mousex/y_snap`) — never by another verb (grep-verified). So it is 1:1 with
`wire_cut`, and the boundary/`core_log_action` is the correct single log site. The twin `break_wires_at_pins`
(break_wires, atom 9) and `break_wires_at_attach_points` (load/save auto-split) are UNTOUCHED; the literal
`wire_cut %` distinguishes all three (an `_` follows in the `break_wires_at_*` names).

**BONUS CORRECTNESS FIX — the coord form had NO readonly gate.** Verified empirically on the pre-migration
binary: `xschem wire_cut 50 0` on a read-only cell **CUT the wire** (push_undo + split + draw ran, rc=0) — a
scattered 0041/0051-class mutation-on-a-read-only-cell gap. The boundary's ONE gate now CLOSES it: the
scripted verb REFUSES (`TCL_ERROR`, `xschem wire_cut: schematic is read-only …`, no cut, no log). Safe
precisely BECAUSE `wire_cut` has NO read-only-safe form — every coord-form path attempts a cut; a
point-off-wire is a NO-OP, not a QUERY — so the all-or-nothing gate cannot OVER-reject (the
show_unconnected_pins §35 / floaters §30 template).

**THE (A)/(B) GESTURE-COMPLETION DECISION — option (A) chosen.** The four callback.c interactive Alt-Right
completion sites call `break_wires_at_point(mousex_snap, mousey_snap, align)` RAW at gesture completion and
log NOTHING today. **(A) LEAVE RAW** (the rotate/flip during-gesture pattern, the scout default): migrate the
SCRIPTED coord form ONLY; the interactive cut stays raw+silent — a PRE-EXISTING 0069-class gesture-drop gap
the atom does NOT widen but does NOT close. **(B) ROUTE THE GESTURE TOO** would move the four sites to
`perform_action("wire_cut", 4, av)` (av[2]/av[3] = snapped coords as strings), +4 callback.c S1 rows + a
gesture test. **Chose (A):** the four sites pass DOUBLE `mousex_snap`/`mousey_snap` needing snprintf-to-string
at four sites in two functions (NOT the trivial `av[2]="1"` byte-move break_wires' keys were), they are the
exact rotate/flip STARTMOVE-stays-raw precedent (mid-gesture logged at END, not per-gesture), and two of the
four (callback.c:2505/2509) are ALREADY readonly-gated by the MENUSTART backstop (callback.c:2495–2504), so
(A) is the clean, well-scoped atom with the smaller sabotage surface. (B) is noted as the follow-up
gesture-logging atom. The decision is captured in the branch comment + the test (case g) + this section — a
DELIBERATE, documented choice, not an accident.

**Entry map.** The SCRIPTED coord form has NO key/menu/palette/Tcl-caller (pure scripted + replay). The two
menu items + the Alt-Right/Alt-Shift-Right mouse gesture are the NO-COORD gesture-START form (stay raw).
Under option (A) there is NO callback.c edit and no key-equivalence decision beyond (A).

**Effect oracle (empirical on the pre-migration binary; deltas re-confirmed on the migrated binary).** A
horizontal wire `0 0 100 0` + `redraw` (break_wires_at_point reads the wire spatial hash a redraw populates —
unlike break_wires_at_pins it does not `hash_wires()` itself). `wire_cut 50 0` splits it into `{50 0 100 0}`
+ `{0 0 50 0}` (count 1→2). Deltas after migration: readonly rc 0-cut → TCL_ERROR-no-cut; no-op (`wire_cut
500 500`) rc 0 no-split STILL logs +1; noalign x=47 vs align x=40; gesture no-coord unchanged (ui_state
MENUSTART=65536); byte-exact `xschem wire_cut 50 0`; undo depth 1.

**Verified:** `test_perform_action_wire_cut.tcl` (30 checks, full_audit logdir_tests, self-deferring
"deferred (no --logdir)" guard): (a) SUCCESS +1 aligned log + split + vertex at (50,0) + byte-exact; (a2)
NOALIGN cuts raw x=47 + logs `xschem wire_cut 47 3 noalign` + the ALIGN form snaps to x=40 (the
discriminator) + replaying the logged noalign line re-cuts at x=47 (flag round-trip); (b) NO-OP off-wire
TCL_OK + no split + STILL +1 log (§30, catch-wrapped); (c) readonly reject TCL_ERROR + verb-named message +
no cut + no log (the correctness fix); (d) mid-gesture split — `xschem wire_cut` (no coords) TCL_OK + no
mutation + MENUSTART armed + +0 log (the gesture-START else did NOT cross the boundary), and `wire_cut
noalign` likewise; (e) replay through the suppress seam re-executes without re-logging vs a control
unwrapped `source` that re-logs; (f) undo DEPTH — ONE undo restores the un-split wire (single conditional
push_undo), a SECOND removes the placed wire; (g) NOTE: the interactive completion stays off the boundary
(option A, grep-guard locked). **Sabotage ×6** (each rebuild-run-restore from the scratchpad backup
`scheduler.c.atom17`, NOT git — ~220 dirty files; each failing EXACTLY its checks): (1) neutralise the
boundary route (inline the coord form KEEPING gate+log) → the runtime `.tcl` STILL PASSES while the grep
guard's S1 branch-route row + S7 exclusivity (total 2→4, each form →2) + S7 scattered-readonly-reject (0→1)
fail closed (the grep guard is the load-bearing structural lock); (2) neutralise the boundary readonly gate
→ the (c) checks fail (cut happened, no error); (3) spurious `push_undo` in the arm → the (f) SECOND-undo
depth check fails (the placed wire survives the second undo) — the no-double-push discriminator; (4) make the
gesture-START form cross/log → the (d) +0-log checks fail + S7 total 2→3 fails closed (a LITERAL `argc>=2`
route would instead OOB-crash on `atof(argv[2/3])` for the coordless form — exactly why the `argc>3` guard
exists); (5) log a +1-offset coord instead of the raw argv coords → the (a)/(a2) byte-exact + count + replay
checks diverge (the coord fidelity is load-bearing); (6) drop the noalign branch (always apply/log aligned) →
the (a2) noalign effect+log+replay checks fail + the S1/S7 noalign-form rows fail closed (noalign 1→0, total
2→1). The change-adjacent siblings stay green: all fifteen other `test_perform_action_*` +
`test_selflog_grep_guard` + `test_actionlog_suppress_gate` + `test_toggle_editmode_log`, and ESPECIALLY
`test_perform_action_break_wires` (the twin — its `wire_cut` case (e) still emits ZERO `xschem break_wires`).

**Grep guard (`test_selflog_grep_guard.tcl`).** ADDED to the `src/scheduler.c` S1 MANIFEST: the boundary
branch row (`return perform_action("wire_cut", argc, argv);`) + the aligned form row (`log_action("xschem
wire_cut %.16g %.16g"`) + the noalign form row (`log_action("xschem wire_cut %.16g %.16g noalign"`). ADDED
`wire_cut` to the S2 CVERBS set (kept OUT of S3). ADDED an S7 block MIRRORING break_wires: scheduler.c
EXACTLY TWO `wire_cut %` total (ONE aligned + ONE noalign, counted independently — the aligned literal
`%.16g %.16g"` is quote-terminated, the noalign literal `%.16g %.16g noalign` has a space before the quote,
so they are mutually exclusive), ZERO bare `wire_cut"`, ZERO scattered `log_action("xschem wire_cut` in
callback.c (option A), ZERO scattered `scheduler_readonly_reject(...,"wire_cut")`. All comment references
avoid the `log_action("xschem wire_cut %` literal prefix so no comment perturbs a count.

**Full-audit baseline diff.** AFTER (atom-17 binary, run under concurrent 11-agent refute-panel load: 157
pass / 18 fail-files + 1 timeout / 0 crash) vs BASELINE (`scheduler.c` reverted to HEAD 73c422ac, rebuilt:
154 pass / 19 fail-files). The load-bearing signal is CLEAN: the BASELINE-only file-fails are PRECISELY the
two atom-17 tests — `test_perform_action_wire_cut` (its +1-log / effect / noalign / readonly-reject /
undo-depth checks fail when the migration is absent — the old scripted coord form never logged and CUT on a
read-only cell) and `test_selflog_grep_guard` (its atom-17 S1/S7 rows scan for `scheduler.c` code absent on
the reverted source) — proving BOTH load-bearing (they PASS on atom-17). The other four BASELINE-only
file-fails (`test_context_menu_descend_edit`, `test_multi_window`, `test_palette`,
`test_verb_noun_copy_move`) are WSLg-congestion GUI/gesture flakes on the baseline run — NOT change-adjacent,
and PASS on the AFTER run. The two AFTER-only file-fails (`test_key_graph_context`, `test_wire_vertex_grab`)
are congestion flakes RE-VERIFIED to PASS STANDALONE on the atom-17 binary (the concurrent refute panel
loaded the box during the AFTER run). Everything else is the COMMON pre-existing WSLg standing set (the
cadence pair `test_cadence_descend_newwin_ro`/`test_cadence_drag`, the GUI set `test_ciw`/`test_hi_descend`/
`test_lib_manager_gui`/`test_reopen_readonly`/`test_altf5_ciw`, `test_lib_sweep`/`test_phase3_mints`/
`test_wire_split`(W7 move-netlist invariant)/`test_select_at`/`test_save_as_cellview`/
`test_descend_untitled_preserve`/`test_untitled_reuse`/`test_fluid_editing`, and `test_selflog_output`'s
transform-KEY checks). ALL seventeen `test_perform_action_*` (wire_cut included) + `test_selflog_grep_guard`
+ `test_actionlog_suppress_gate` + `test_toggle_editmode_log` are GREEN on AFTER, ESPECIALLY
`test_perform_action_break_wires` (the twin). **ZERO new deterministic failures.**

**Adversarial review (10-axis refute panel + completeness critic, Workflow/ultracode, against a FROZEN
atom-17 snapshot): verdict SHIP — 10/10 axes `defect_found=false`, zero code defects.** The axes: (1) branch
coord/gesture SPLIT — only `argc>3` crosses, the gesture-START else arms `MENUSTART`/`MENUSTARTWIRECUT[2]`
identically, the coord form is the SOLE `perform_action("wire_cut")` caller, the `return`-early matches all
sixteen siblings and skips no common tail; (2) core-owns-conditional-undo — the arm adds no push/draw, the
core's single `push_undo` (check.c:522) + `draw` (check.c:532) are gated on `changed`, the point-off-wire
no-op pushes nothing, undo-depth-1 holds; (3) coord fidelity — RAW `argv` coords logged (not the snapped
point), `align` applied in-core, replay re-snaps identically; (4) noalign round-trips in BOTH effect and log
(identical parse loops); (5) readonly gate additive + no over-reject (no read-only-safe form); (6)
no-op-still-logs (void core → TCL_OK); (7) 1:1/C3 — `break_wires_at_point` called only by `wire_cut` entry
points, the break_wires twin's `wire_cut %` literals stay independent; (8) the (A) gesture decision sound +
documented; (9) grep-guard drift — the aligned/noalign literals mutually exclusive, no comment false-match;
(10) C89/build clean. The completeness critic returned `review_complete=true`, `SHIP`, and independently
**RAN the pre-existing coord-form consumer `tests/stable_handles/test_body.tcl:152`** (`xschem wire_cut 100
3 noalign`, guarding CH4i/CH4i2) on the migrated binary — BOTH PASS = an independent non-regression proof
(the 2 stable_handles FAILs H7b/H7c are orthogonal disk-undo/handle red tests). It raised THREE coverage
gaps, all resolving to NON-defects: (i) a coord-fidelity NIT — the `r==2` EXACT-ON-SEGMENT case in
`closest_point_calculation` (check.c:496) leaves the point UNSNAPPED even with `align=1`, but replay is
SYMMETRIC (both split halves get the identical replayed coord → no short/disconnect), the drift is sub-ULP,
realistic coords are grid integers that round-trip exactly, and it is the codebase-wide `%.16g` convention
shared with rotate/flip (atoms 6/7); (ii) the `break_wires_at_point` **spatial-hash dependency** — it does
NOT call `hash_wires()` (unlike `break_wires_at_pins`), assuming `wire_spatial_table` is already populated —
a real landmine but PRE-EXISTING and byte-faithful (the old scripted coord form called it identically; the
test/consumers redraw first); (iii) the stable_handles consumer (verified PASS). No concrete input/state
producing wrong output, crash, or replay divergence that atom 17 introduces.

**Next atom:** the SILENT-MUTATOR wire_cut is now on the boundary alongside its twin break_wires. The
friction-free pool remains EMPTY, so the next atom is another HIGHER-FRICTION coverage gain — the atom-16
scout runners-up were `image` (HAS_CAIRO + a help/no-op C1/C2 split), `apply_pin_prop` (inline-body
extraction + 2 Tcl_Merge string referents — HIGHEST value), and `move_instance` (conditional noundo/nodraw
C5 + a name referent) — pick with a fresh source re-verify. DEFER the composite-hazard verbs
(delete/cut/copy/save/reload) whose shared cores are called by abort/merge/teardown (the §4
`delete()`-is-NOT-1:1 lesson).

## 38. Refactor B ATOM 18 (2026-07-17): the EIGHTEENTH per-verb migration — a symbol-editor pin edit with an INLINE two-referent VALIDATING body, purely-additive log + a read-only correctness fix (`apply_pin_prop`)

The friction-free pool has been EMPTY since atom 16. `apply_pin_prop` was the HIGHEST-VALUE runner-up named
by the atom-16/17 scout: a genuine HIGHER-FRICTION coverage gain — a symbol-editor mutation that logged
NOTHING and had NO C-level read-only gate before this atom, carrying an INLINE mutation body (not a shared
core) and TWO string referents. It is the **replace_symbol §34 two-referent VALIDATING template** crossed
with the **reset_inst_prop §33 argc-gate**.

**The verb.** `xschem apply_pin_prop [<scope>] <prop>` applies `<prop>` to the symbol PINLAYER rects named by
`<scope>` (`current` | `selected` | `all`; default `selected`), mirroring the pin branch of
`edit_rect_property` WITHOUT a dialog round-trip so the pin/pinname property forms can offer a live "Apply"
(cadence_pin_name_text.md; symbol_editor_apply_scope.md). Changed-fields-only vs the primary pin's prop
(sel_array[0]), so a fan keeps each pin's distinct `name=`.

**Migration (scheduler.c only — no callback.c edit).**
- **Branch** (`xschem_cmds_a`): the whole inline body is replaced by `return perform_action("apply_pin_prop",
  argc, argv);`. The `!xctx` guard is dropped (perform_action re-checks it) and the old `Tcl_SetResult
  "0"/"1"` leaves the branch. The early-return-from-a-matched-branch is byte-identical in the `*cmd_found`
  protocol to reset_inst_prop/replace_symbol (`cmd_found` inits to 1 before the letter-dispatch switch, a
  matched early return keeps it 1, `if(retcode != TCL_OK) return retcode;` propagates the readonly/argc
  TCL_ERROR).
- **`run_core` arm**: the WHOLE inline body MOVES in verbatim — the `argc<3` "needs: [scope] new_prop"
  VALIDATION (early TCL_ERROR *before* any mutation), the scope/newprop resolution (argc>=4 → argv[2]/argv[3];
  argc==3 → "selected"/argv[2] back-compat), `pin_scope_resolve()` (the SHARED READ-ONLY resolver, stays raw
  below the boundary), the GUARD-PASS no-op (`Tcl_SetResult "0"` + `return TCL_OK` **BEFORE** push_undo — no
  undo slot), else the SINGLE `xctx->push_undo()` + the apply loop (`set_different_token`/`pin_reorient`/
  `pin_view_apply`) + `set_modify(1)` + `draw()` + `Tcl_SetResult "1"`. There is no self-undo core, so THIS
  arm owns the single push (like reset_inst_prop/replace_symbol, unlike the self-undo verbs). A forward decl
  of `static pin_scope_resolve` was added before `run_core` (its definition is later in the file). C89: decls
  at block top.
- **`core_log_action` arm**: TWO forms mirroring the branch's arg resolution — argc>=4 → `xschem
  apply_pin_prop <scope> <prop>` via `log_action_argv(4, pp)`; argc==3 → `xschem apply_pin_prop <prop>` via
  `log_action_argv(3, pp)`. BOTH referents Tcl_Merge-quoted: `<prop>` is a full pin-attribute string with
  spaces + brackets + possibly braces (a raw `%s` would misparse on replay — the §33 arrayed-name lesson);
  `<scope>` is a bareword Tcl_Merge logs unbraced. The array is named **`pp`** (NOT `av`/`ev`/`av[3]`) — the
  §36 collision lesson — so its build/emit lines stay TEXTUALLY DISTINCT.

**THE RESULT-DROPPED WRINKLE (verified, not assumed).** The old branch returned a MEANINGFUL `"0"`/`"1"`
interp result; the boundary's atom-13 success-path `Tcl_ResetResult` BLANKS it (empirically confirmed: a
scripted apply now returns `""`). A repo-wide grep for consumers of the return found: the PRODUCTION consumer
`gfxform::do_apply` (xschem.tcl) DISCARDS it (a bare statement, verified by DRIVING it in test (g)); the ONLY
return-consumers were TWO STANDALONE tests — `tests/symbol_pin_scope.tcl` (6 `[xschem apply_pin_prop …] 1`
sites) and `tests/pin_name_text.tcl` (a `→1` and a no-op `→0`) — which were SWITCHED to assert the EFFECT (a
stronger oracle; idempotence proven by "undo reverts size"). So no caller regresses. This is the
reset_inst_prop/replace_symbol dropped-success-result pattern (§33/§34) but with a genuine — if test-only —
consumer that had to be reworked, so the drop was a DELIBERATE, user-confirmed decision, not a silent one.

**THE READONLY CORRECTNESS FIX.** Verified empirically on the pre-migration binary: a scripted `xschem
apply_pin_prop selected {… name_size=0.9}` on a read-only symbol view MUTATED the pin (name_size changed) — a
scattered 0041/0051-class mutation-on-a-read-only-cell gap (the scripted verb had NO C gate; only the Tcl
form's `gfxform::apply` guarded `[xschem get readonly]`). The boundary's ONE gate now CLOSES it: the scripted
verb REFUSES (TCL_ERROR + `xschem apply_pin_prop: schematic is read-only …`, no apply, no log). Safe because
`apply_pin_prop` has NO read-only-safe form — the guard-pass no-op is a NO-OP, not a QUERY — so the
all-or-nothing gate cannot OVER-reject (the show_unconnected_pins §35 / floaters §30 template).

**THE 1:1 TEST (C3).** The mutation body is INLINE (not a shared C fn), so it is strictly 1:1 with the verb —
there is NO shared mutating core to lock (unlike trim_wires atom 1 / attach_labels atom 11).
`pin_scope_resolve()` is a SHARED READ-ONLY resolver (also used by `pin_scope_prop_uniform` and the SP3
preview) — grep-verified it does NOT mutate, so it stays RAW below the boundary with no self-log.

**Entry map.** TWO Tcl callers reach the branch via `xschem apply_pin_prop`: `gfxform::do_apply` (the pin
editor's live Apply, scope form) + its back-compat prop-form. NO key/menu/palette/keybindings.csv/
mousebindings.csv bind. So there is NO callback.c edit and no key-equivalence decision.

**Effect oracle (empirical, pre- and post-migration).** Two PINLAYER pins A,B via `add_symbol_pin` (each
`name=X dir=in show_pinname=true name_dx=25 name_dy=-5 name_size=0.2`), both selected (A primary). `xschem
apply_pin_prop selected {… name_size=0.9}` changed-fields-diffs vs A, so the ONLY changed token `name_size`
fans to A AND B (B keeps `name=B`). Pinned: the RESULT is now `""` (was `"1"`); a re-apply is a no-op that
returns `""` but STILL logs +1 (§30); the argc gate errors `xschem apply_pin_prop needs: [scope] new_prop`;
readonly now REFUSES (was: mutated); a metachar prop `foo=a[1]` logs BRACE-QUOTED and replays.

**Verified:** `test_perform_action_apply_pin_prop.tcl` (33 checks, full_audit logdir_tests, self-deferring
"deferred (no --logdir)" guard): (a) SUCCESS +1 scope-form log + change on A,B + B keeps name=B + RESULT
BLANK + byte-exact brace-quoted line; (a2) metachar prop logs BRACE-QUOTED + replays without a Tcl error +
re-applies; (b) argc-gate TCL_ERROR + non-empty message + +0 log + no mutation; (b2) NO-OP re-apply returns
BLANK but STILL logs +1 (§30, catch-wrapped); (c) READONLY reject TCL_ERROR + verb-named message + no apply +
no log (the correctness fix); (d) back-compat `xschem apply_pin_prop <prop>` (argc==3) logs the 3-arg form +
applies to the current selection; (e) replay through the suppress seam re-applies without re-logging vs a
control `source` that re-logs; (f) undo DEPTH — TWO applies (0.5 then 0.9), ONE undo → 0.5, a SECOND undo →
the original 0.2 (single push_undo per apply; a double-push would leave 0.5 — the discriminator needs the
second undo, the §33 lesson); (g) RESULT-DROP + no caller regressed — DRIVES the real `gfxform::do_apply`
(which discards the result) and asserts the change still applies. **Sabotage ×6** (each rebuild-run-restore
from the scratchpad backup `scheduler.c.atom18`, NOT git — ~220 dirty files; each failing EXACTLY its
checks): (1) neutralise the boundary route (inline perform_action's body in the branch KEEPING gate+log) →
the runtime `.tcl` STILL PASSES while the grep guard's S1 branch-route row (→0) + S7 scattered-readonly (0→1)
fail closed — the grep guard is the load-bearing structural lock; (2) neutralise the readonly gate (for
apply_pin_prop only) → the (c) checks fail (mutated, no error); (3) spurious double push_undo in the arm →
the (f) SECOND-undo depth check fails (0.5 survives) — the no-double-push discriminator; (4) log on the
argc<3 failure path → the (b) +0-log check fails; (5) raw `%s` referent instead of `log_action_argv` → the
(a2) metachar-replay + byte-exact checks fail + the S1/S7 `pp`-build rows fail closed; (6) drop the
back-compat 3-arg form → the (d) checks fail + the S7 `(3, pp)` + line-anchored 3-arg build rows fail closed.
The change-adjacent siblings stay GREEN: all seventeen other `test_perform_action_*` +
`test_selflog_grep_guard` + `test_actionlog_suppress_gate` + `test_toggle_editmode_log`, and the two rewired
consumer tests (`symbol_pin_scope`/`pin_name_text`) PASS on BOTH the atom-18 AND the reverted-HEAD binary
(they now assert the unchanged EFFECT).

**Grep guard (`test_selflog_grep_guard.tcl`).** ADDED to the `src/scheduler.c` S1 MANIFEST: the boundary
branch row + the scope-form build row (`pp[3] = argv[3];`, UNIQUE to apply_pin_prop) + the line-anchored
back-compat build row (`(?n)pp[0] = "xschem"; pp[1] = verb; pp[2] = argv[2];$` — matches ONLY the 3-arg
line, NOT the 4-arg line that continues past `argv[2];`) + the two emit rows (`(4, pp)` / `(3, pp)`). ADDED
`apply_pin_prop` to S2 CVERBS (kept OUT of S3). ADDED an S7 block: EXACTLY ONE of each build + emit, ZERO
scattered `log_action("xschem apply_pin_prop"` in scheduler.c AND callback.c, ZERO scattered
`scheduler_readonly_reject(…, "apply_pin_prop")`, PLUS a COLLISION GUARD re-asserting reset_inst_prop's `av`,
embed_rawfile's `ev`, and replace_symbol's `av[3]` single-referent sites all stay == 1.

**Full-audit baseline diff.** AFTER (atom-18 binary) vs BASELINE (`scheduler.c` reverted to HEAD c40241b3,
rebuilt), on the change-adjacent set: the ONLY two BASELINE-only fails are `test_perform_action_apply_pin_prop`
(13 checks fail when the migration is absent — the old scripted form never logged, returned `"1"`, and mutated
a read-only cell) and `test_selflog_grep_guard` (its atom-18 S1/S7 rows scan for code absent on the reverted
source) — proving BOTH load-bearing (they PASS on atom-18). All nineteen other change-adjacent tests + the two
consumer tests PASS on BOTH. The FULL headless audit on the atom-18 binary showed ZERO new deterministic
failures — the fail set is the documented WSLg standing set (the cadence pair, the GUI set, `test_lib_sweep`/
`test_phase3_mints`/`test_wire_split`(W7)/`test_select_at`/`test_save_as_cellview`/`test_untitled_reuse`/
`test_fluid_editing`/`test_selflog_output`'s transform-KEY checks); the only two non-standing-set entries
(`test_select_inside_argc`, `test_selflog_grep_guard` TIMEOUT under load) were RE-VERIFIED to PASS STANDALONE
on the atom-18 binary (and `test_select_inside_argc` PASSES on the baseline too — a transient flake, not
change-adjacent). The wireedit 52-test suite is ALL PASS.

**Next atom:** the friction-free pool remains EMPTY. The atom-16/17 scout runners-up now stand at `image`
(HAS_CAIRO + a help/no-op C1/C2 split) and `move_instance` (conditional noundo/nodraw C5 + a name referent) —
pick with a fresh source re-verify. DEFER the composite-hazard verbs (delete/cut/copy/save/reload) whose
shared cores are called by abort/merge/teardown (the §4 `delete()`-is-NOT-1:1 lesson).

## 39. Refactor B ATOM 19 (2026-07-17): the NINETEENTH per-verb migration — a PURE SCRIPTED instance-reposition verb with an INLINE conditional-undo/draw body, the noundo/nodraw C5 handled, readonly CONSOLIDATED (not newly fixed), and the noundo-log decision recorded (`move_instance`)

The friction-free pool has been EMPTY since atom 16. `move_instance` was the atom-18 scout's named runner-up
alongside `image` — a genuine HIGHER-FRICTION coverage gain: a PURE SCRIPTED instance-reposition verb that
logged NOTHING before this atom, carrying an **INLINE mutation body** (not a shared core), a **CONDITIONAL
push_undo/draw** (the noundo/nodraw C5 sub-mode) and an **instance-name referent**. It is the **apply_pin_prop
§38 INLINE-body extraction** + the **reset_inst_prop §33 single-referent + argc-gate** templates, crossed with
a CONDITIONAL single push_undo (the replace_symbol §34 owns-the-push, but the flag GATES ONLY the undo, NOT the
log) and the **wire_cut §37 "log the flag FAITHFULLY" decision** (see below).

**The verb.** `xschem move_instance inst x y rot flip [nodraw] [noundo]` repositions an instance by NAME (a `-`
in any of x/y/rot/flip keeps the existing value); `nodraw` skips the redraw, `noundo` makes it non-undoable. A
pure SCRIPTED verb — the user (or a replay) types it.

**Migration (scheduler.c only — no callback.c edit).**
- **Branch** (`xschem_cmds_m`): the whole inline body (`int undo=1, dr=1; !xctx guard; scheduler_readonly_reject;
  if(argc>7){flag parse} if(argc>6){validate + conditional push + dashed sets + bbox + prep resets + conditional
  draw}`) is replaced by `return perform_action("move_instance", argc, argv);`. The `!xctx` guard is dropped
  (perform_action re-checks it) AND the per-verb `scheduler_readonly_reject` is dropped (the boundary's generic
  gate covers it — a CONSOLIDATION, see below). NB the OLD branch FELL THROUGH (no `return`) and returned TCL_OK
  at the dispatch tail; the new `return perform_action(...)` returns run_core's TCL_OK — byte-identical under the
  `*cmd_found` protocol (`cmd_found` inits to 1, a matched early return leaves it "found").
- **`run_core` arm**: the WHOLE inline body MOVES in verbatim — the `argc<7` VALIDATION (early TCL_ERROR *before*
  any mutation), the nodraw/noundo flag parse, the `get_instance(argv[2])<0` "instance not found" validation, the
  CONDITIONAL single `if(undo) xctx->push_undo()` (owned here — there is no self-undo core, like reset_inst_prop/
  replace_symbol; a normal move pushes once, a `noundo` move pushes NOTHING), the dashed x/y/rot/flip sets (each
  gated on `strcmp(argv[N],"-")`), `symbol_bbox` + the three prep-flag resets, and the CONDITIONAL `if(dr) draw()`.
  There is NO `set_modify` (the old branch had none) and NO success `Tcl_SetResult` (see the RESULT wrinkle). The
  original body declared `int i` TWICE in nested blocks (the flag-loop counter + the instance index); flattened to
  `i` (loop) + `inst` (index) at the block top (C89).
- **`core_log_action` arm**: the FAITHFUL FULL CALL `xschem move_instance <inst> <x> <y> <rot> <flip> [nodraw]
  [noundo]` via `log_action_argv`/`Tcl_Merge` — the instance referent `argv[2]` is metachar-safe (an arrayed name
  `x2[3:0]` brace-quotes), the five positional referents `argv[2..6]` copied into a `mi` array, the nodraw/noundo
  flags appended in CANONICAL order (nodraw before noundo) and emitted via a VARIABLE-count `log_action_argv(k,
  mi)`. The array is named **`mi`** (NOT `av`/`ev`/`pp`/`av[3]` — the §36 collision lesson) AND is a FRESH build
  (NOT the bare `log_action_argv(argc, argv)` form, which recurs at THREE other scheduler.c sites — add_pin_stubs/
  paste/... — so could not be grep-pinned uniquely).

**THE noundo/nodraw LOG DECISION — the load-bearing design call, RESOLVED FROM THE CALLERS.** The KEY question:
is `noundo` a machinery/replay sub-mode that must NOT be logged (like replace_symbol's `fast`, §34) or a faithful
arg to LOG (like wire_cut's `noalign`, §37)? **Answer: LOG it faithfully.** `fast` is gated OUT because
replace_symbol is called as an internal sub-step of a larger logged op (a multi-substitution), so logging each
`fast` call would DOUBLE-log. `move_instance` has NO such internal caller — grep-verified PURE SCRIPTED (no
key/menu/palette/callback/C/Tcl caller anywhere; the only live-repo references are a completion list, docs, and
`test_readonly_guard.tcl`). So nodraw/noundo are just faithful user args a replay must reproduce: a user who
scripts `move_instance ... noundo` wants replay to reproduce it (no undo slot). They are logged, not gated, and
re-emitted in a CANONICAL order (order-independent booleans → the canonical line replays to the identical effect,
the atom-9/-11 "log the value the effect consumed" rule).

**THE ARGC GATE — a VALIDATING behaviour delta (test (b)), AND an OOB-crash guard.** The old branch SILENTLY
no-op'd on a short call (`if(argc>6)` false → nothing, TCL_OK). The migration makes `argc<7` an early TCL_ERROR +
verb-named message, and — via log-on-success (atom 13) — records NO phantom line. Crucially it ALSO prevents a
CRASH: without the gate, a short call (e.g. `xschem move_instance R1`, argc=3) would return TCL_OK and reach
`core_log_action`, which reads `argv[3..6]` → an OUT-OF-BOUNDS read → `Tcl_Merge` crash (the embed_rawfile §36
`argv[2]`-NULL class). The gate returns before both. Verified no caller relies on the silent no-op (pure scripted,
grep-clean).

**THE READONLY GATE — a CONSOLIDATION, not a new fix (test (c)).** UNLIKE apply_pin_prop §38 / embed_rawfile §36 /
wire_cut §37 (where the boundary ADDED a gate the branch never had), the old move_instance branch ALREADY had a
per-verb `scheduler_readonly_reject(interp, "move_instance")`. The migration REMOVES it and the boundary's generic
gate covers it — the reset_inst_prop §33 / replace_symbol §34 consolidation. Verified empirically: `test_readonly_
guard.tcl` (which lists `move_instance` in its read-only-refuse set) PASSES on BOTH the reverted-HEAD baseline AND
the atom-19 binary — SAME refuse behaviour, the per-verb gate just moved onto the boundary. The S7 grep row locks
scheduler.c to ZERO scattered `scheduler_readonly_reject(...,"move_instance")`.

**THE 1:1 TEST (C3).** The mutation body is INLINE (not a shared C fn), so it is strictly 1:1 with the verb —
there is NO shared mutating core to lock (like apply_pin_prop §38, unlike trim_wires atom 1 / attach_labels
atom 11). Routing move_instance double-logs NOTHING with any other verb.

**THE RESULT WRINKLE (verified, not assumed).** The task's premise was "move_instance sets no success interp
result, so the boundary drops NOTHING". Re-verified from source + empirically: the BRANCH sets no result, but the
mutation path leaks an INCIDENTAL `"0"` (from an internal `tcleval` — push_undo/autosave machinery), while the
no-op / short forms leave `""`. The boundary's success-path `Tcl_ResetResult` blanks the leaked `"0"` to `""`
uniformly (empirically confirmed: a scripted move now returns `""`). No caller consumes the return (PURE SCRIPTED —
grep-clean), so the drop is safe — the reset_inst_prop/replace_symbol/apply_pin_prop dropped-result pattern
(§33/§34/§38), here on an INCIDENTAL leak rather than a deliberate `Tcl_SetResult`.

**NO set_modify — byte-faithful.** The old branch had NO `set_modify` (a move on a SAVED sheet leaves `modified`==0
— verified: after `saveas` then `move_instance`, `modified` stays 0). The arm adds none; adding one would change
behaviour. Locked by test (g).

**Entry map — a PURE SCRIPTED verb, verified by grepping the LIVE repo (the atom-10/14/16 lesson).** NO key
(`keybindings.csv`/`mousebindings.csv`), NO menu `-command`, NO command palette (`actions.csv`), NO `callback.c`
`act_*`/legacy switch, NO Tcl caller anywhere. So there is NO `callback.c` edit and NO key-equivalence decision
(like reset_inst_prop §33 / replace_symbol §34 / embed_rawfile §36 / apply_pin_prop §38).

**Effect oracle (empirical, pre- and post-migration).** A `devices/res.sym` resistor placed at the origin
(0 0 0 0). `xschem move_instance R1 100 40 90 0` sets x0=100 y0=40 rot=90 flip=0 (read back via `xschem
instance_coord R1` → `{R1} {res.sym} 100 40 90 0`; note `getprop instance x0` reads PROP-STRING tokens, NOT the
geometric struct fields — `instance_coord` is the correct oracle). Pinned on the pre-migration binary: the
argc<7 SILENT no-op (→ TCL_ERROR post), the incidental `"0"` result leak (→ `""` post), the dashed keep-existing
(`- - 180 -` changes ONLY rot), the noundo undo-depth (a noundo move pushes NOTHING → one undo unwinds the
PLACEMENT, instances→0; a normal move pushes ONCE → one undo restores x0=0 with the instance present), the
metachar name round-trip, and the no-set_modify (modified==0 after saveas+move).

**Verified:** `test_perform_action_move_instance.tcl` (41 checks, full_audit logdir_tests, self-deferring
"deferred (no --logdir)" guard): (a) SUCCESS +1 FAITHFUL log + byte-exact `xschem move_instance R1 100 40 90 0` +
x0/y0/rot/flip applied + RESULT BLANK; (a2) metachar name `x2[3:0]` logs BRACE-QUOTED + replays without a Tcl
error + re-moves; (b) argc gate — `move_instance R1` (argc<7) AND bare `move_instance` (argc==2, the OOB class)
each → TCL_ERROR + non-empty "needs:" message + +0 log + no mutation; `move_instance BOGUS 1 1 0 0` → TCL_ERROR
"instance not found" + +0 log + no mutation; (c) readonly reject (the CONSOLIDATION) — TCL_ERROR + verb-named
message + no move + +0 log; (d) noundo — pushes NOTHING (one undo removes the instance, instances→0) AND the
noundo-log decision (the line is LOGGED WITH the `noundo` flag) + nodraw likewise; (e) replay through the suppress
seam re-executes without re-logging vs a control `source` that re-logs; (f) undo DEPTH normal move — ONE undo
restores x0=0 with the instance PRESENT, a SECOND undo unwinds the placement (single conditional push_undo); (g)
dashed keep-existing (only rot) + nodraw identical + NO set_modify (modified==0 after saveas+move). **Sabotage ×6**
(each rebuild-run-restore from the scratchpad backup `scheduler.c.atom19`, NOT git — ~220 dirty files; each
failing EXACTLY its checks): (1) neutralise the boundary route (inline perform_action's readonly+run_core+log in
the branch, KEEPING the effect+log) → the runtime `.tcl` STILL PASSES while the grep guard's S1 branch-route row
(→0) + the S7 scattered-readonly-reject row (0→1) fail closed — the grep guard is the load-bearing structural
lock; (2) neutralise the readonly gate (for move_instance only) → the (c) checks fail (mutated, no error, +1 log);
(3) make push_undo UNCONDITIONAL (ignore noundo) → the (d) noundo undo-depth check fails (the instance survives
one undo) — the no-double-push / conditional-push discriminator; (4) log on the not-found failure path (return
TCL_OK) → the (b) not-found checks fail (rc=0, empty msg, +1 log); (5) raw `%s` referent instead of
`log_action_argv` → the (a2) metachar-replay ("invalid command name 3:0") + byte-exact + (d) flag-log checks fail
+ the S1/S7 `mi` rows + the scattered-log row fail closed; (6) the noundo-log decision's INVERSE (gate the emit on
`!noundo`, the fast-analogy) → the (d) noundo "+1 log" + "logged WITH noundo flag" checks fail. The change-adjacent
siblings stay GREEN: all eighteen other `test_perform_action_*` + `test_selflog_grep_guard` +
`test_actionlog_suppress_gate` + `test_toggle_editmode_log`, and ESPECIALLY `test_readonly_guard` (the readonly
CONSOLIDATION — move_instance still refuses on BOTH binaries).

**Grep guard (`test_selflog_grep_guard.tcl`).** ADDED to the `src/scheduler.c` S1 MANIFEST: the boundary-branch row
(`return perform_action("move_instance", argc, argv);`), the `const char *mi[9];` decl row, the line-anchored
5-referent build row (`(?n)mi[k++] = argv[2]; … argv[6];$`, UNIQUE to move_instance) and the emit row
(`log_action_argv(k, mi);`, a VARIABLE count distinct from every fixed-count `(N, av/ev/pp)` site and the bare
`(argc, argv)`/`(ac, av)` forms). ADDED `move_instance` to S2 CVERBS (kept OUT of S3). ADDED an S7 block: EXACTLY
ONE decl + ONE build + ONE emit, ZERO scattered raw `log_action("xschem move_instance"` in scheduler.c AND
callback.c, ZERO scattered `scheduler_readonly_reject(…, "move_instance")` (the per-verb gate REMOVED — the
consolidation) — PLUS a COLLISION GUARD re-asserting reset_inst_prop's `av`, embed's `ev`, replace_symbol's `av[3]`
and apply_pin_prop's `pp` single-referent sites each stay == 1.

**Full-audit baseline diff.** AFTER (atom-19 binary) vs BASELINE (`scheduler.c` reverted to HEAD dc57ba83,
rebuilt): the load-bearing signal is CLEAN — the ONLY two BASELINE-only fails are `test_perform_action_move_instance`
(13 checks fail when the migration is absent — the old scripted form never logged, silently no-op'd on a short
call, and leaked a `"0"` result) and `test_selflog_grep_guard` (its atom-19 S1/S7 rows scan for scheduler.c code
absent on the reverted source) — proving BOTH load-bearing (they PASS on atom-19). `test_readonly_guard` PASSES on
BOTH (the readonly consolidation). The FULL headless audit on the atom-19 binary showed **ZERO new deterministic
AFTER-only failures** — the 16 file-fails are the documented WSLg standing set: the cadence pair
(`test_cadence_descend_newwin_ro`/`test_cadence_drag`), the GUI set (`test_ciw`/`test_hi_descend`/
`test_lib_manager_gui`/`test_reopen_readonly`), `test_lib_sweep`/`test_phase3_mints`/`test_wire_split`(W7)/
`test_select_at`/`test_save_as_cellview`/`test_descend_untitled_preserve`/`test_untitled_reuse`/`test_fluid_editing`,
and `test_selflog_output`'s transform-KEY checks (Shift-F/Alt-F/Shift-R/Alt-R/Shift-V/Alt-V — GUI key-dispatch
flakes, all in verbs UNTOUCHED by atom 19). The one non-standing-set entry `test_verb_noun_copy_move` was
RE-VERIFIED to PASS STANDALONE (a WSLg-congestion flake — the audit box was loaded). None is change-adjacent
(atom 19 edits ONLY scheduler.c's move_instance arms + the test/grep-guard/doc). All eighteen sibling
`test_perform_action_*` + `test_selflog_grep_guard` + `test_actionlog_suppress_gate` + `test_toggle_editmode_log` +
`test_readonly_guard` are GREEN on AFTER.

**Adversarial review (10-axis refute panel + completeness critic, Workflow/ultracode, against a FROZEN atom-19
snapshot): verdict SHIP — 10/10 axes `defect_found=false`, zero code defects.** The axes: (1) branch→boundary —
`return perform_action(...)` reproduces the dropped `!xctx` guard + per-verb readonly gate, and the old branch's
fall-through-to-TCL_OK is byte-identical under the `*cmd_found` protocol (no skipped shared tail); (2) inline body
byte-faithful — the conditional push_undo owned once, conditional draw, NO set_modify, the dashed sets + the two
nested `int i` correctly flattened, argc>=7 behaviour identical to the old argc>6 path; (3) readonly consolidation
— same refuse behaviour before/after, no slip-through window, gate order correct; (4) referent fidelity — the
metachar name round-trips, x/y/rot/flip/dashes/flags reproduce exactly, `mi[9]` never overflows; (5) argc gate —
returns before any mutation AND before the `core_log_action` argv[3..6] OOB read, message survives the success-only
reset; (6) the noundo-log decision sound — grep-confirmed NO internal `move_instance … noundo` caller, so faithful
logging (not a fast-style gate) is correct and replay-safe; (7) no-op/result — no consumer of the blanked `"0"`;
(8) 1:1/C3 — inline body, no shared core, no double-log; (9) grep-guard — the `mi` decl/build/emit each count 1,
textually distinct from av/ev/pp/av[3], collision guards hold, no comment false-match; (10) C89/build — decls at
block top, compiles clean. The completeness critic returned `review_complete=true`, `SHIP`, and ran SEVEN of its
own adversarial probes on the built binary, all faithful: (P5) a negative coordinate `-90` is APPLIED (strcmp≠"-")
and logged RAW so replay re-casts identically — the `(unsigned short)atoi` cast is byte-identical to pre-migration;
(P6) a flag-WORD (`nodraw`) sitting in the flip slot at argc==7 is correctly treated as a VALUE, not a flag,
because BOTH run_core and core_log_action start the flag scan at `i=7` (so effect and log never diverge); (P3) a
triple-flag input canonicalizes to `nodraw noundo` with no `mi[9]` overflow; (P1) a trailing junk arg is dropped
from the log but the effect is intact with no replay divergence; (a) the replay suppress-seam × a logged `noundo`
line re-executes with undo skipped, does NOT re-log (rides the actionlog_suppress depth counter), and the follow-up
undo unwinds the PLACEMENT — no double-log, no undo-depth error; (e) `instance_coord` (the test oracle) reads
`inst[].x0/.y0/.rot/.flip` — EXACTLY the fields move_instance writes, so the oracle is not blind/tautological; (f)
every test check discriminates a concrete failure mode (the positive control where an unwrapped `source` re-logs +1
proves the suppress assertion is non-vacuous). No concrete input/state producing wrong output, crash, replay
divergence, undo-depth error, double-log, build failure, or unlocked grep-guard on any axis.

**Next atom:** the friction-free pool remains EMPTY. The atom-18/19 scout runner-up now stands at `image`
(HAS_CAIRO + a help/no-op C1/C2 split — a read-only-safe-query over-reject RISK to weigh). DEFER the
composite-hazard verbs (delete/cut/copy/save/reload) whose shared cores are called by abort/merge/teardown (the §4
`delete()`-is-NOT-1:1 lesson); selection-referent replay (0005) remains the accepted config/selection-dependent
class.

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
verb-noun START/switch/END block is gone); §29 after the NINTH (break_wires — the FIRST NON-transform verb,
the wire-surgery sibling of trim_wires; the arg is a FLAG `0/1` not a coordinate pivot, there is no
mid-gesture split, and `break_wires_at_pins` is 1:1 with the verb while `break_wires_at_point`/`wire_cut`
stays a separate gesture off the boundary); §30 after the TENTH (floaters_from_selected_inst — the SECOND
NON-transform verb, the FIRST after the wire-surgery pair; a BARE no-arg verb whose log is the shared
`xschem %s` default, whose core owns its own undo, and whose boundary gate CLOSES a scattered read-only gap);
§31 after the ELEVENTH (attach_labels — the THIRD non-transform verb, and the FIRST with a SHARED sub-step
core: it combines the break_wires arg-carrying FLAG pattern — but `interactive` 0/1/2 is PRESERVED with `%d`,
not collapsed — with the trim_wires shared-core sub-step lock, since `attach_labels_to_inst()` is ALSO called
raw by `show_unconnected_pins` and the Shift+H dialog key; it was a currently-logged MOVE, and the boundary
ADDED the read-only gate the branch never had); §32 after the TWELFTH (toggle_ignore — the FIRST
FRICTION-FREE-SCOUTED verb, from the 243-verb friction analysis; a BARE no-arg verb whose boundary is PURELY
ADDITIVE, adding BOTH a new log site AND the read-only gate the branch never had; the KEY-EQUIVALENCE
INVERSION of atom 11 — the EQUIVALENT Shift+T key routes THROUGH the boundary, but re-verify OVERTURNED the
scout premise: the key was NOT a coverage hole (already gated via registry `mutates=1`, already logged via
Layer A `d->log_cmd`), so routing it is a consistency move whose single-log rests on the `actionlog_cmd_logged`
dedup and whose `mutates=1` is KEPT to avoid a phantom-log-on-read-only; the no-op-still-logs property is
preserved); §33 after the THIRTEENTH and the FIRST SHARED-MACHINERY atom (reset_inst_prop — the boundary
itself CHANGED to LOG-ON-SUCCESS: log + success-only Tcl_ResetResult fire only on rc==TCL_OK, so the
VALIDATING-verb class (early TCL_ERROR before mutating) no longer phantom-logs a rejected call; reset_inst_prop
is the first beneficiary, its validation moved into run_core before the single push_undo, its referent logged
replay-safe via log_action_argv/Tcl_Merge after an adversarial review caught the raw-%s arrayed-name gap; the
no-op-still-logs property is preserved because a no-op returns TCL_OK); §34 after the FOURTEENTH
(replace_symbol — the SECOND VALIDATING verb, and the FIRST per-verb migration to carry a FAST-FLAG
log gate; a PLAIN migration onto the UNCHANGED atom-13 log-on-success boundary that touches NO shared
machinery: run_core MOVES the fast parse + argc!=4 / "instance not found" validation IN before its
single !fast-gated push_undo, core_log_action logs the two-referent `xschem replace_symbol <inst>
<sym>` via log_action_argv/Tcl_Merge gated on !fast — the fast multi-substitution machinery sub-mode
skips both undo and log; a PURE SCRIPTED verb with no key/menu/other caller, purely additive coverage;
the five validating-verb shortlist is now EXHAUSTED — reset_symbol/load_backup/move_instance/
apply_properties are DISQUALIFIED, so the next atom needs a fresh grep-scout); §35 after the FIFTEENTH
(show_unconnected_pins — a BARE no-arg friction-free verb from a fresh 279-branch scout, the same shape
as floaters/toggle_ignore; a PLAIN migration onto the UNCHANGED atom-13 log-on-success boundary that
touches NO shared machinery: run_core is a bare `show_unconnected_pins(); return TCL_OK;` and the log
falls to core_log_action's DEFAULT `xschem %s`; it is the SECOND verb to share the attach_labels_to_inst
core after atom 11 — the raw attach_labels_to_inst(2) sub-step stays SILENT below the boundary so it
double-logs NOTHING with attach_labels (the §31 lock, INVERTED); the boundary ADDS the read-only gate
the branch NEVER HAD as a CORRECTNESS FIX — the old branch placed lab_show labels on a read-only cell;
menu-only (no key, no callback.c edit; the Shift+H attach_labels dialog path is disjoint); the
no-op-still-logs property preserved; the scout left EXACTLY TWO candidates so beyond the DEFERRED runner-up
embed_rawfile the next atom needs another fresh grep-scout); §36 after the SIXTEENTH (embed_rawfile — the
DEFERRED runner-up from the atom-15 scout, a PLAIN migration onto the UNCHANGED atom-13 log-on-success
boundary that touches NO shared machinery; a HYBRID of the reset_inst_prop §33 SINGLE-STRING-referent +
argc-GATE template and the floaters/show_unconnected_pins §30/§35 CORE-OWNS-ITS-OWN-UNDO template: run_core
MOVES the `~/` expansion IN (via the home_dir global) with a VALIDATING-LITE argc<3 gate, the core
embed_rawfile() owns the single push_undo, and core_log_action logs the RAW argv[2] path via
log_action_argv/Tcl_Merge using an array named `ev` (NOT `av`) to stay collision-distinct from
reset_inst_prop's byte-identical build; the boundary ADDS the read-only gate the branch NEVER HAD as a
CORRECTNESS FIX — the old branch embedded on a read-only cell; the external-file replay caveat is IDENTICAL
pre/post, not a new hazard; a PURE SCRIPTED verb — no key/menu/palette/callback/Tcl caller, so no callback.c
edit; the friction-free pool is now EXHAUSTED so the next atom needs another fresh grep-scout); §37 after the
SEVENTEENTH (wire_cut — the SILENT-MUTATOR twin of break_wires named by the atom-16 22-group scout after the
friction-free pool went empty; the mouse-position wire cut `break_wires_at_point` that §29 kept OFF
break_wires' boundary. NOT friction-free — TWO wrinkles handled by accepted patterns: the core OWNS a
CONDITIONAL single push_undo + draw so run_core adds NEITHER (no double-push; a point-off-wire no-op still
returns TCL_OK → no-op-still-logs); core_log_action logs the RAW click coords via `%.16g` + a bareword
`noalign` flag in TWO forms, NO Tcl_Merge (numeric coords), align applied in-core so raw coords replay
identically; a MID-GESTURE SPLIT routing ONLY the SCRIPTED coord form (branch argc>3) while the no-coord
gesture-START form stays RAW (arms ui_state, no mutation, no log — the rotate/flip STARTMOVE-stays-raw
pattern); the boundary ADDS the read-only gate the coord form NEVER HAD as a CORRECTNESS FIX — the old
scripted form cut on a read-only cell; and the (A)/(B) gesture-completion decision recorded — option (A),
the four interactive Alt-Right callback.c completion sites stay RAW+silent, a pre-existing 0069-class gap
this atom does not widen, (B) deferred to a follow-up gesture-logging atom, so NO callback.c edit); §38 after
the EIGHTEENTH (apply_pin_prop — a HIGHER-FRICTION coverage gain now the friction-free pool is EMPTY, the
HIGHEST-VALUE atom-16/17 runner-up: a symbol-editor pin edit with an INLINE two-referent VALIDATING body, the
replace_symbol §34 two-referent template crossed with the reset_inst_prop §33 argc-gate. run_core MOVES the
whole inline body IN — the argc<3 validation before any mutation, the SHARED read-only pin_scope_resolve
resolver that stays raw below the boundary, the guard-pass no-op returning "0"+TCL_OK before push_undo, and
the SINGLE push_undo + apply loop; core_log_action logs TWO forms — argc>=4 `xschem apply_pin_prop <scope>
<prop>` and the back-compat argc==3 `xschem apply_pin_prop <prop>` — BOTH referents Tcl_Merge-quoted via an
array named `pp` (NOT av/ev/av[3], the §36 collision lesson). The migration is PURELY ADDITIVE (the branch
logged NOTHING) and ADDS the C-level read-only gate the SCRIPTED verb NEVER HAD as a CORRECTNESS FIX — the old
scripted form mutated a read-only symbol view. The RESULT-DROPPED wrinkle was VERIFIED not assumed: the old
branch returned a meaningful "0"/"1" that the boundary now blanks; the production consumer gfxform::do_apply
DISCARDS it, and the ONLY return-consumers (two standalone tests, symbol_pin_scope.tcl / pin_name_text.tcl)
were switched to assert the EFFECT — a user-confirmed deliberate drop. The no-op-still-logs property (§30) is
preserved; the back-compat 3-arg form replays against the current selection, the accepted 0005
selection-dependent class. TWO Tcl callers, NO key — so NO callback.c edit); §39 after the NINETEENTH
(move_instance — a HIGHER-FRICTION coverage gain now the friction-free pool is EMPTY, the atom-18 runner-up
alongside image: a PURE SCRIPTED instance-reposition verb (`move_instance inst x y rot flip [nodraw] [noundo]`)
with an INLINE mutation body, a CONDITIONAL push_undo/draw (the noundo/nodraw C5 sub-mode) and an instance-name
referent. run_core MOVES the whole inline body IN — the argc<7 validation before any mutation (which ALSO
prevents core_log_action reading argv[3..6] OOB on a short call, the embed_rawfile crash class), the flag parse,
the get_instance validation, the CONDITIONAL single `if(undo) push_undo()` owned here, the dashed x/y/rot/flip
sets, and the CONDITIONAL `if(dr) draw()`; core_log_action logs the FAITHFUL FULL CALL `xschem move_instance
<inst> <x> <y> <rot> <flip> [nodraw] [noundo]` via log_action_argv/Tcl_Merge (instance name metachar-safe) using
a FRESH `mi` array (NOT av/ev/pp/av[3], the §36 collision lesson; NOT the bare log_action_argv(argc, argv) form
which recurs at three other scheduler.c sites). THE noundo/nodraw LOG DECISION, resolved from the callers: both
flags are LOGGED FAITHFULLY (the wire_cut noalign approach) NOT gated out like replace_symbol's fast — because
move_instance has NO internal machinery caller (pure scripted); the flags re-emit in a CANONICAL order
(nodraw before noundo). The READONLY gate is a CONSOLIDATION not a new fix (unlike atoms 16/17/18): the old
branch HAD a per-verb scheduler_readonly_reject, now REMOVED, the boundary's generic gate covers it —
test_readonly_guard PASSES on both binaries. NO set_modify (the branch had none); the incidental "0" result the
mutation path leaked is blanked to "" by the boundary, no caller consumes it. A PURE SCRIPTED verb — no
key/menu/palette/callback/Tcl caller — so NO callback.c edit).
Coverage verified in source at HEAD by a 14-way parallel read; do not trust the status table
without re-checking the cited `file:line` anchors, which drift as the tree moves.*

## 40. Refactor B ATOM 20 (2026-07-17): the TWENTIETH per-verb migration — the FIRST HAS_CAIRO-gated verb and the FIRST QUERY/MUTATE SPLIT, a read-only-safe `help` kept RAW in front of the boundary, a FAITHFUL RAW variable-arity log, and the read-only gate added as a correctness fix (`image`)

`image` was the atom-18/19 scout's named runner-up alongside `move_instance`. It is the migration the
atom-19 handoff flagged with a specific RISK: **a read-only-safe QUERY sub-form that the boundary's
unconditional readonly gate would OVER-REJECT.** It is also the FIRST verb whose effect is `#if
HAS_CAIRO==1` (it drives `edit_image`, draw.c), and the FIRST whose log form has a VARIABLE argument
count.

**The verb.** `xschem image [invert|white_transp|black_transp|transp_white|transp_black|blend_white|
blend_black|write_back]` applies pixel transforms (a bitmask `what`) to the SELECTED GRIDLAYER image
rects (`c==GRIDLAYER && r->flags & 1024`) via `edit_image`. `image help` returns a usage string;
`write_back` (256) re-encodes the modified surface into the `image_data=` attribute and is the ONLY
flag that sets `modified`.

**STEP 0 — the fixture scout (the real unknown).** A selected image is NOT creatable by a one-liner
(the GUI `add_image` uses `tk_getOpenFile`; `edit_image` needs REAL decoded pixels — it early-returns
`if(!emb_ptr || !emb_ptr->image)`). Route R-A (chosen): a self-contained fixture `.sch`
(`tests/headless/fixtures/image/image_embedded.sch`) carrying one GRIDLAYER `B 2 …` rect with
`flags=image,unscaled` + an inline base64 4×4 PNG (`gen_tiny_png.py`, reproducible, no PIL). Verified
on the pre-migration binary that `xschem load` + `select_all` yields exactly one selected GRIDLAYER
image rect (flags&1024), that `image invert write_back` MUTATES `image_data` headless (edit_image runs
under cairo at load/draw), and that `image write_back` re-encodes. GOTCHA: `saveas`/`load` CLEAR the
selection, so every image op must `select_all` first (else "No images selected").

**EFFECT ORACLE (pinned on the pre-migration binary FIRST).** (A) `image help` → TCL_OK + usage,
read-only-safe; (B) `image invert` on a read-only cell PRE-migration **MUTATES** (the bug); (C) undo is
a SINGLE push; (D) `set_modify` ONLY on write_back (a plain invert leaves `modified==0`); (F) the verb
logged NOTHING pre-migration (the +1 is the migration delta); (G) an unrecognized flag (`what==0`) is a
TCL_OK no-op that mutates nothing.

**Migration (scheduler.c only — no callback.c edit; a PURE SCRIPTED / menu-via-branch verb).**
- **Branch** (`xschem_cmds_i`, inside the existing `#if HAS_CAIRO==1`): the QUERY/MUTATE SPLIT — the two
  pre-mutation, read-only-SAFE replies stay RAW IN FRONT of the boundary (`!xctx` guard [precedence
  preserved], the `argc<3` "Missing arguments" validation, and `image help` → usage + TCL_OK), then
  `return perform_action("image", argc, argv)`. Routing `help` through the boundary would REFUSE a pure
  query on a read-only cell (the boundary's ONE readonly gate, scheduler.c:1031, is unconditional
  per-verb). This is the wire_cut §37 form-split applied to a query vs a mutation.
- **`run_core` arm** (`#if HAS_CAIRO==1`): the `No images selected` precondition (a MUTATION
  precondition, NOT a query — it stays BELOW the boundary so a read-only cell REFUSES first; accepted
  message change on the readonly+nothing-selected corner), the flag parse, and the `if(what)` block
  (`rebuild_selected_array`; `if(what & 256) set_modify(1)` — the write_back-only modify; the SINGLE
  `push_undo`; the `edit_image` loop over the selected GRIDLAYER rects; `draw()`). Returns TCL_OK on
  BOTH the mutate AND the `what==0` no-op. The branch's `int n,i,c` + `int what` + `xRect *r` move here
  at block top (C89).
- **`core_log_action` arm** (`#if HAS_CAIRO==1`): the FAITHFUL RAW full call `xschem image <flag>…` via
  a fresh HEAP array `im` (`my_malloc(argc*sizeof(char*))`; the `xschem`/verb prefix hardcoded
  `im[0]="xschem"; im[1]=verb;` per the sibling idiom, the flag tail `argv[2..]` copied verbatim;
  `log_action_argv(argc, im)`, `my_free`). Sized to argc because the flag COUNT is variable (1..8) — unlike the
  fixed-arity `mi[9]`/`pp[4]`. **RAW, not canonical-from-`what`:** an unrecognized flag yields
  `what==0`, and a canonical rebuild would collapse that no-op to a bare `xschem image` that REPLAYS as
  "Missing arguments"; the raw echo (`xschem image foo`) round-trips to the SAME no-op. Any
  recognized-flag call replays to the identical `what` regardless of order/dupes. The barewords carry no
  Tcl metacharacter, so Tcl_Merge logs them unbraced == byte-identical. Named `im` (NOT av/ev/pp/mi —
  the §36 collision lesson) and a fresh build (NOT the bare `log_action_argv(argc, argv)` form, which
  recurs at three other scheduler.c sites so could not be grep-pinned uniquely). `log_action_argv` is
  synchronous (Tcl_Merge → log → Tcl_Free), so freeing `im` immediately after is safe.

**HAS_CAIRO gating.** The run_core + core_log_action arms are `#if HAS_CAIRO==1 … #endif` (edit_image is
cairo-only); the whole branch already was, so on a no-cairo build `perform_action("image")` is never
reached and the arms compile out — the else-if chains stay brace-balanced across the `#if` in both
functions. The test self-DEFERS on a no-cairo build (the dispatcher returns `xschem image: invalid
command.` — the defer triggers ONLY on that exact signal, so a broken-`help` regression cannot mask
itself as a defer).

**READONLY = a CORRECTNESS FIX (like atoms 16/17/18, unlike atom 19's consolidation).** The branch
NEVER had a readonly gate; the boundary ADDS it — pre-migration `image invert` MUTATED a read-only cell
(EFFECT ORACLE (B)), now REFUSED. `image help` stays read-only-safe (it returns in the branch, before
the boundary). No read-only-safe MUTATING form exists (every `if(what)` path mutates; help/argc<3 are
the only queries and stay raw).

**Verification.** `tests/headless/test_perform_action_image.tcl` (29 checks, full_audit logdir_tests,
self-deferring on no-cairo/no-logdir): (a) mutate + exactly +1 byte-exact `xschem image invert
write_back` + blank interp result; (a2) multi-flag verbatim; (b) `image help` read-only-safe TCL_OK +
usage + logs NOTHING; (c) read-only REFUSE (the correctness fix) — TCL_ERROR + no mutate + no log; (d)
set_modify only on write_back; (e) undo single-push; (f) `what==0` no-op — TCL_OK, no mutate, no modify,
STILL logs +1 as the RAW replayable `xschem image bogusflag`; (g) nothing-selected TCL_ERROR + no log;
(h) replay round-trip faithful; (i) the OTHER raw-front reply — bare `xschem image` (argc<3) → TCL_ERROR
"Missing arguments" + logs NOTHING (added from the completeness-critic note below). **grep guard:** S1 boundary-branch + `const char **im` decl +
`im[j] = argv[j];` copy + `log_action_argv(argc, im)` emit rows; `image` in S2 CVERBS, OUT of S3; an S7
block (EXACTLY ONE of each build/copy/emit, ZERO scattered raw `log_action("xschem image"` in
scheduler.c AND callback.c, ZERO scattered `scheduler_readonly_reject(…,"image")`) PLUS a COLLISION
GUARD re-asserting av/ev/pp/mi stay ==1. **Sabotage ×6** (rebuild-run-restore from a scratchpad backup,
NOT git — ~200 dirty files), each failing exactly its checks: (1) bypass boundary via `run_core` direct
→ grep S1 branch-row=0 fails closed even though the effect still works (the grep is the structural lock)
+ test (a)/(c); (2) remove the help split → (b) read-only-safe; (3) unconditional set_modify → (d); (4)
faithless hardcoded log → (a)/(a2)/(f) + grep S1/S7 emit + scattered-raw; (5) No-images→TCL_OK → (g); (6)
scattered per-verb readonly gate → (b) + grep S7 scattered-readonly=1. **Baseline diff CLEAN** (AFTER
atom-20 vs HEAD atom-19): the only BASELINE-only fails are my two tests (they detect the migration's
absence — load-bearing); ZERO new deterministic fails (the 5 GUI tests that flipped between the full run
and the subset — graph_context/hover_highlight/key_graph_context/palette — PASS standalone, full-run
WSLg-congestion flakes; test_fluid_editing fails on HEAD too = pre-existing). **10-axis adversarial
refute panel + completeness critic (Workflow, ultracode): unanimous CLEAN, 0 code defects, verdict
SHIP_WITH_NOTE** across split / read-only-safe-query / HAS_CAIRO-gating / faithful-RAW-log /
im-memory-safety / set_modify+undo / precondition-placement / log-on-success / C89 / entry-completeness.
The critic raised four NON-defect notes, all resolved: (1) REVIEW-INTEGRITY — the working tree was not
frozen during the review (the baseline-diff builds flipped scheduler.c HEAD↔atom-20, and ~174 sibling
scratch worktrees churn the shared tree), so citations may drift → resolved by COMMITTING to freeze the
snapshot; (2) test-gap on the argc<3 raw-front reply → closed by check (i); (3) the `im[0]` verbatim
copy diverged from the sibling hardcode idiom → aligned to `im[0]="xschem"; im[1]=verb;`; (4) a
PRE-EXISTING (NOT atom-20) latent quirk — the `#if HAS_CAIRO==1` block in `xschem_cmds_i` also encloses
`incr_hilight_color` + `inst_name_text`, so those two NON-cairo verbs silently vanish on a no-cairo build
(present identically on HEAD, gate@4674) → filed as issue 0120 and **RESOLVED** (fix(scheduler),
2026-07-17): the gate was narrowed to wrap ONLY the `image` branch (`#if` moved down to just before
`else if("image")`, dangling `else` dropped, `#endif` kept after it, and `instance` promoted from a bare
`if` to `else if` so the chain bridges cleanly in BOTH configs). Verified with a REAL HAS_CAIRO==0 build:
compiles+links, `incr_hilight_color`/`inst_name_text` work, `image` reports a graceful `invalid command`
(no crash); sabotage-confirmed the pre-fix no-cairo build LOST both verbs. Locked by
tests/headless/test_noncairo_verbs_ungated.tcl (structural fail-closed grep guard + functional
reachability). See doc/claude/issues/0120-noncairo-verbs-lost-in-image-cairo-gate.md.

RECOMMENDED NEXT (the friction-free pool has been EMPTY since atom 16 → keep taking HIGHER-FRICTION):
re-scout the migrated-verb roster fresh; the remaining unmigrated mutating scheduler verbs are the
higher-friction / composite class. DEFER the composite delete/cut/copy/save/reload (shared cores called
by abort/merge/teardown — the §4 delete()-is-NOT-1:1 lesson); selection-referent replay (0005) is the
accepted config/selection-dependent class.

## 41. Refactor B ATOM 21 (2026-07-17): the TWENTY-FIRST per-verb migration — a value-carrying integer verb with a SECOND live entry point (the Shift-S key), the had_sel §30 LOG-GATE FLIP, and the read-only gate CONSOLIDATED (`change_elem_order`)

`change_elem_order` was drawn fresh from the higher-friction pool (empty since atom 16). It is the FIRST
migrated verb since break_wires (atom 9) to carry **a second LIVE entry point that also mutates+logs** —
the Shift-S legacy-switch key — so, like break_wires' Ctrl-! and the transform keys, BOTH entry points
route through the boundary (the atom-16 "grep the GUI for every entry point" lesson). Its distinguishing
wrinkle is a **logging-policy flip**, not a new plumbing shape.

**The verb.** `xschem change_elem_order <n>` reorders the z-order (array position) of the SELECTED
object (instance / wire / rect / text): `n>=0` sets it to position `n` (clamped in-core to array bounds);
`n==-1` opens the interactive "Object Sequence number" `input_line` dialog (the Shift-S / Prop-menu
form). The core `change_elem_order()` (editprop.c) rebuilds the selection itself, guards on `lastsel==1`
(nothing-selected or multi-selected → a harmless NO-OP), and OWNS its own `push_undo` (on the first
mutation, gated on `modified`) + `set_modify(1)`.

**Two entry points, BOTH funnelled through perform_action.**
- **Scheduler branch** (Prop menu / scripted): drop the inline body → `return perform_action(
  "change_elem_order", argc, argv)`.
- **Shift-S key** (callback.c `case 'S'`, `rstate==0`, HARDCODED -1): drop the inline
  `rebuild_selected_array` + `had_sel` gate + `change_elem_order(-1)` + `log_action` → `perform_action(
  "change_elem_order", 3, av)` with `av[2]="-1"` (the break_wires Ctrl-! FLAG-arg pattern). perform_action's
  rc is DISCARDED and the switch falls through to `break` (the toggle_ignore atom-12 event-handled contract).

**STEP 0 — EFFECT ORACLE (pinned on the pre-migration binary FIRST, `scratchpad/atom21/oracle.tcl`, 26
checks all PASS).** Fixture: two overlapping `res.sym` instances (R1@idx0, R2@idx1, same origin, distinct
names) → z-order == array index, read back via `xschem instance_number <name>`. Pinned: (A) `change_elem_order 0`
on selected R2 swaps R2→idx0/R1→idx1; (B) scripted AND Shift-S both REFUSE on a read-only cell (no mutate,
no log); (C) undo is a SINGLE push; (D) a reorder on a SAVED sheet sets `modified=1`; (E) nothing-selected =
TCL_OK no-op that logs **NOTHING** pre-migration (the `had_sel` gate) — the +1-on-empty is the migration
delta; (E2/E3) invalid `n=-5` and bare `change_elem_order` (argc<3) are pre-migration SILENT no-ops (TCL_OK,
no log); (F) the Shift-S key mutates + logs `xschem change_elem_order -1` IDENTICALLY to the scripted form
(input_line stubbed to a target index); (F2) Shift-S on read-only calls `readonly_block()` and BREAKS
**before** input_line/mutation/log; (G) `change_elem_order 7` logs the RAW `7` byte-exact (value-preserving,
before the in-core clamp).

**THREE DESIGN CALLS (resolved from source).**
1. **READONLY = CONSOLIDATION, not a new fix** (like move_instance §39, unlike embed/wire_cut/apply_pin_prop
   which ADDED a gate). The old branch HAD `scheduler_readonly_reject(interp, "change_elem_order")` AND the
   Shift-S key an inline `readonly_block()`. The scheduler_readonly_reject is REMOVED (the boundary's ONE
   generic gate covers the scheduler/menu/script path). **The Shift-S key KEEPS its `readonly_block()`**
   (belt-and-suspenders, exactly the break_wires Ctrl-! pattern) — a DELIBERATE deviation from the spec's
   literal "remove it", resolved by asking the user: Shift-S is a LEGACY-switch key (NOT registry-dispatched,
   so no `dispatch_input_action` readonly backstop), so dropping `readonly_block()` would silently lose the
   read-only messageBox the key posted (the boundary's TCL_ERROR rc is DISCARDED by the event handler → no
   feedback). Keeping it makes behaviour TRULY identical pre/post on both paths. Grep-guard S7 forbids ZERO
   scattered `scheduler_readonly_reject(…,"change_elem_order")` (which is removed); it does NOT forbid the
   key's `readonly_block()` (break_wires keeps its too).
2. **THE had_sel LOG GATE — PRESERVED, §30 REJECTED (the load-bearing decision, driven by the adversarial
   review).** Both entry points gated the log on `if(had_sel)` — a nothing-selected reorder was a no-op that
   did NOT log. The FIRST cut took the §30 alignment (log-on-success UNCONDITIONALLY, as
   floaters/toggle_ignore) — the 10-axis refute panel (below) found this HARMFUL and it was REVERSED. **Why
   §30 fails here:** `change_elem_order` is SELECTION-DEPENDENT (the 0005 replay class) AND its core keeps the
   reordered object SELECTED — the array swap in `editprop.c` moves the whole struct including the `.sel` bit,
   `need_reb_sel_arr=1`. So a phantom empty-selection log line is NOT a reliable no-op on a WHOLE-LOG replay:
   if an intervening interactive deselect was NOT logged (the accepted 0005 gap), the previously-reordered
   object is STILL selected when the phantom line replays → it REORDERS that object → a silent z-order
   divergence (affecting netlist ordering + draw stacking). Two majors converged: (i) the replay divergence
   above; (ii) an EXISTING registered check `test_selflog_output.tcl:190` (`change_elem_order (no sel) is
   nolog`) — in the same logdir_tests set — asserts the OPPOSITE of §30, so the flip was a NEW deterministic
   audit contradiction. **The fix (the spec's named form-split fallback):** the had_sel gate is PRESERVED,
   moved into `core_log_action` as `if(xctx->lastsel)` — the log authority's natural home (like
   replace_symbol's `fast` gate). `change_elem_order()` rebuilds the selection itself (just run in run_core)
   and its swap does not change the COUNT, so `xctx->lastsel` there == the old `had_sel` EXACTLY (0 → skip the
   log; 1 or >1 → log, matching the branch which logged even the multi-select no-op — `test_selflog_output.tcl
   :184`). Reading xctx state in core_log_action is the rotate/flip `mousex_snap` precedent. A grep-guard S1
   row locks the `if(xctx->lastsel)` gate (revert → count 0, fails closed); test (c) covers empty/single/multi.
3. **LOG FORM = value-preserving `xschem change_elem_order %d`** via core_log_action (the attach_labels
   atom-11 `%d` template — PRESERVES the integer, unlike break_wires which collapses nonzero to 1). It is a
   bare numeric arg (no Tcl metacharacter), so `log_action("xschem change_elem_order %d", atoi(argv[2]))` is
   the right form (NOT log_action_argv — no referent to brace-quote, hence NO av/ev/pp/mi/im array and no §36
   collision). SINGLE form (no bare variant): the arg is REQUIRED (run_core's `argc<3` is an early TCL_ERROR),
   so unlike attach_labels/break_wires there is no argc==2 bare line.

**Migration.**
- **`run_core` arm** (OUTSIDE the `#if HAS_CAIRO` block — change_elem_order is not cairo-gated): TWO
  validation gates move IN and stay BEFORE the effect — the `argc<3` gate (early TCL_ERROR; the old branch
  SILENTLY no-op'd on a missing arg, AND — the move_instance §39 crash class — the gate prevents
  core_log_action reading `argv[2]` OOB → `atoi(NULL)` SIGSEGV, DEMONSTRATED by sabotage 3) and the
  `n >= 0 || n == -1` range gate (a bad `n` was silently ignored; now an early TCL_ERROR so, via
  log-on-success, it mutates nothing AND logs nothing). Then `change_elem_order(n)`; NO push_undo/set_modify/
  draw here (the core OWNS all three — adding one would DOUBLE-push, the atom-1 rule). `n` is read from
  `argv[2]` with the SAME `atoi` as core_log_action, so the logged form can never diverge from the applied
  reorder.
- **`core_log_action` arm** (OUTSIDE the `#if HAS_CAIRO` block): `if(xctx->lastsel) log_action("xschem
  change_elem_order %d", atoi(argv[2]))` — the value-preserving log GATED on the preserved had_sel (design
  call 2 above).
- **NOT strictly 1:1.** `change_elem_order()` is ALSO called RAW as a sub-step by the `instance_number inst
  <n>` scripted verb (scheduler.c) — that caller stays BELOW the boundary (raw core, no perform_action, no
  self-log; it logged nothing before and still does), exactly the attach_labels atom-11 shared-sub-step lock.

**Verification.** `tests/headless/test_perform_action_change_elem_order.tcl` (40 checks, full_audit
logdir_tests, self-deferring on no-logdir): (a) reorder oracle + exactly +1 + VALUE-PRESERVING byte-exact
`change_elem_order 7` + set_modify(1) on a saved sheet; (b) read-only REFUSE from BOTH entry points
(scripted TCL_ERROR + verb-named message + no mutate + no log; Shift-S no mutate + no log, input_line NOT
reached); (c) the had_sel LOG GATE — empty-selection logs +0 (locks `test_selflog_output:190`), a SELECTED
reorder logs +1 (gate not stuck-closed), a multi-select no-op STILL logs +1 (had_sel!=0, locks
`test_selflog_output:184`); (d) invalid `n=-5` + bare argc<3 → TCL_ERROR + +0 log + no mutate; (e) undo
single-push; (f) Shift-S key equivalence via callback injection (keysym 83 state 0) — mutate + byte-exact
`xschem change_elem_order -1` +1; (g) replay round-trip (seam re-executes without re-logging; control
`source` re-logs); (h) the `instance_number inst <n>` raw sub-step logs NO change_elem_order line (the
runtime lock the grep-guard cannot provide — a future editprop.c self-log would escape the scheduler.c/
callback.c scan). **grep guard:** the S1 scheduler branch-row moved onto `return perform_action(...)` + the
`%d` core_log_action row RE-LABELLED (site moved branch→core, count stays 1) + a NEW row locking the
`if(xctx->lastsel)` had_sel gate (revert → count 0, fails closed); the callback.c S1 row moved from the
inline `log_action("xschem change_elem_order -1")` onto `perform_action("change_elem_order", 3, av)`;
`change_elem_order` STAYS in S2 CVERBS (already present), OUT of S3; an S7 block (EXACTLY ONE `log_action(
"xschem change_elem_order %"` + EXACTLY ONE total in scheduler.c, ZERO in callback.c, ZERO scattered
`scheduler_readonly_reject(…,"change_elem_order")`). **Sabotage ×7** (each fails EXACTLY its checks; restore
from `scratchpad/atom21/*.mig`, NOT git — ~200 dirty sibling worktrees): (1) drop the range gate → test (d)
invalid-n (4 checks); (2) drop `%d` → test (a)/(c)/(f) byte-exact value + grep S1/S7 `%d` rows; (3) drop the
argc<3 gate → **`FATAL: signal 11`** on the bare call (atoi(NULL), the §39 OOB class); (4) re-add scattered
`scheduler_readonly_reject` → grep S7 readonly=1; (5) re-add inline callback `log_action` → grep S7
callback=1; (6) drop `change_elem_order(n)` → test (a) reorder oracle + set_modify; (7) revert the
`if(xctx->lastsel)` gate to unconditional → test (c) empty-log + grep S1 gate row (the §30-regression lock).
**Baseline diff CLEAN** (AFTER atom-21 vs HEAD atom-20): all perform_action_* + selflog + grep-guard PASS;
the 10 failing logdir tests are BYTE-IDENTICAL on HEAD and migrated (the standing WSLg/GUI set —
CIW/gesture/context-menu/hi_descend/phase3/shape_setprop/libmgr, none referencing change_elem_order,
confirmed by rebuilding the pre-migration binary and re-running); ZERO new deterministic fails.

**10-axis adversarial refute panel + completeness critic (Workflow, ultracode), against the FROZEN
commit 4ebe9b61.** 7/11 axes CLEAN, 0 critical. TWO MAJORS — both on the had_sel §30 FLIP (the phantom
empty-log line reorders a still-selected object on whole-log replay; and it breaks the registered
`test_selflog_output:190` check) — CONFIRMED against source and FIXED by preserving the had_sel gate (design
call 2, the spec's form-split fallback). TWO MINORS — (i) the `instance_number` shared-sub-step had no
runtime coverage → CLOSED by check (h); (ii) the §30 replay-harmless claim was overclaimed → mooted by the
fix (no phantom line). ONE NIT — the `deferred`-prints-`ALL PASS` hollow-pass on a no-logdir standalone run
→ ACCEPTED (identical to all 15 perform_action_* siblings; mitigated by logdir_tests registration). The fix
was applied and re-verified (40 checks + 314 grep checks + sabotage 7 green) BEFORE re-committing.

RECOMMENDED NEXT (superseded by §42): re-scout the roster for the next atom.

## 42. Refactor B ATOM 22 (2026-07-17): the TWENTY-SECOND per-verb migration — an ADDITIVE-LOG+GATE verb whose run_core arm must NOT push_undo (the load-bearing divergence: `fix_symbols` owns the single undo bracket) (`reset_symbol`)

`reset_symbol` was the top-tier pick from the additive-log pool: **additive-log+gate** (the branch had
NEITHER a self-log NOR a read-only gate, so the migration ADDS both — a replay line AND a closed latent
bug) crossed with the highest tractability (a 1:1 INLINE body, the direct twin of reset_inst_prop = atom
13, a few arms above it). Its only friction — the two early semantic TCL_ERRORs — was already crossed by
the atom-13 log-on-success boundary.

**The verb.** `xschem reset_symbol <inst> <symref>` is a documented LOW-LEVEL batch sub-step: it merely
swaps `xctx->inst[...].name` (a raw `my_strdup`, NO match_symbol / reload / bbox / hash update). The CALLER
is responsible for deleting symbols first and `reload_symbols` afterward. Its SOLE non-branch caller is the
Tcl proc `fix_symbols` (xschem.tcl), which re-maps every instance's symbol reference to N last path
components.

**THE ONE REAL DIVERGENCE from the reset_inst_prop template — no push_undo, no set_modify in the run_core
arm.** reset_inst_prop's arm owns a SINGLE `push_undo` (there is no self-undo core). reset_symbol must NOT:
`fix_symbols` does ONE `xschem push_undo` **before** a `foreach` loop that calls `xschem reset_symbol` per
instance, then `reload_symbols` + `set_modify(1)` + `redraw` **after** the loop. That single push is the
one-Ctrl-Z bracket for the WHOLE remap. If the run_core arm pushed a slot per call, fix_symbols' N calls
would SHATTER it — one undo would revert only the LAST remap. The precedent for a no-undo/no-set_modify
run_core arm is replace_symbol's fast-form (atom 14, which skips both). This is the load-bearing hazard;
sabotage 1 (add `push_undo` to the arm) is caught by the test's fix_symbols single-undo check (checks
(g)/(g2)): `0=devices/res.sym 1=devices/res.sym 2=res.sym` — only the last remap reverted, batch broken.

**TWO REFERENTS, both Tcl_Merge-quoted.** Unlike reset_inst_prop (single referent argv[2]), reset_symbol
logs BOTH argv[2] (instance name/index) AND argv[3] (symbol reference) — the replace_symbol §34 two-referent
shape. Both can carry Tcl metacharacters (an arrayed name `x2[3:0]`, a symref path with a space/bracket), so
BOTH are emitted via `log_action_argv`/Tcl_Merge, NOT a raw `%s` — a raw `x2[3:0]` would replay `[3:0]` as a
command substitution (`invalid command name "3:0"`, DEMONSTRATED by sabotage 4). Tcl_Merge quotes MINIMALLY,
so a plain refdes+path logs byte-identically to `xschem reset_symbol R1 devices/res.sym`. The referent array
is named `rs` (av/ev/pp/mi/im all taken — the §36 collision lesson), unique so its build/emit stay
textually distinct.

**Migration (the direct twin of atom 13, minus the undo).**
- **`run_core` arm** (beside reset_inst_prop's): the TWO gates lift VERBATIM and stay BEFORE the effect —
  `argc != 4` → TCL_ERROR "needs 2 additional arguments"; `get_instance(argv[2]) < 0` → TCL_ERROR "instance
  not found" — so a bad call mutates nothing and (via log-on-success) logs nothing. Effect:
  `my_strdup(_ALLOC_ID_, &xctx->inst[inst].name, argv[3]); return TCL_OK;` — **no push_undo, no
  set_modify, no draw.** (Accuracy note, from the refute panel: unlike reset_inst_prop, the old
  reset_symbol branch NEVER set the interp result to the instname — it already ended in
  `Tcl_ResetResult`, a blank result; the boundary's success-path Tcl_ResetResult PRESERVES that. So
  check (a)'s "result BLANK" is a preservation guard, not a behavior-change delta.)
- **`core_log_action` arm** (beside reset_inst_prop's): a COLLISION-DISTINCT `const char *rs[4]`;
  `rs[0]="xschem"; rs[1]=verb; rs[2]=argv[2]; rs[3]=argv[3]; log_action_argv(4, rs);` — logged ONLY on
  TCL_OK, after the gates passed, so argv[2]/argv[3] are always present.
- **Scheduler branch** → `return perform_action("reset_symbol", argc, argv);` with the doc-comment
  mirroring reset_inst_prop's (adds the "owns NO push_undo/set_modify — fix_symbols brackets the batch"
  note). The old `!xctx` check moves into perform_action.

**fix_symbols BEHAVIOR CHANGES (both stated in the commit body).** (a) It now emits N replay lines (one
per remapped instance) — byte-replayable, matching the replace_symbol fast-form precedent (check (f):
`fix_symbols 1` on a 3-instance sheet emits exactly +3 `xschem reset_symbol` lines). (b) On a READ-ONLY
cell it now THROWS at the first reset_symbol (was: silently mutated) — the intended correctness fix, but a
fix_symbols error-path change worth naming.

**Verification.** `tests/headless/test_perform_action_reset_symbol.tcl` (32 checks, full_audit
logdir_tests, self-deferring on no-logdir): (a) SUCCESS mutates inst.name + exactly +1 byte-exact
`xschem reset_symbol R1 devices/capa.sym` + interp result BLANK; (b) argc!=4 (too-few AND too-many) →
TCL_ERROR + non-empty verb message + no mutation + +0 log; (c) instance-not-found → TCL_ERROR + +0; (d)
READONLY REFUSE (the NEW gate) → TCL_ERROR + verb-named read-only message + inst.name UNCHANGED + +0 log
(pins the pre-migration mutate-on-read-only bug closed); (e) metachar referents (arrayed `x2[3:0]` + a
spaced symref) round-trip via Tcl_Merge — logged brace-quoted, the exact line REPLAYS; (f) fix_symbols
emits +3 replay lines + all remapped; (g)/(g2) ONE undo reverts the WHOLE remap (fix_symbols real proc +
a distilled explicit-bracket variant) — proving the arm pushed no undo. Build cairo (default) OK.
**Sibling + guard PASS:** test_perform_action_reset_inst_prop, test_perform_action_replace_symbol,
test_selflog_grep_guard (331 checks) all green. **Baseline-diff CLEAN:** the pre-edit (HEAD atom-21)
binary fails test_selflog_output with the IDENTICAL 7 transform-key-injection flakes (Shift-F/Alt-R/… —
the standing nondeterministic WSLg key set, count varied 6↔7 across runs; NONE reference reset_symbol),
byte-identical pre/post; ZERO new deterministic fails.

**grep guard (test_selflog_grep_guard.tcl):** S1 rows — the boundary branch row, the run_core arm's two
gate statements + the `my_strdup` effect, the core_log_action line-anchored `rs`-build + the
`log_action_argv(4, rs)` emit; `reset_symbol` ADDED to S2 CVERBS, kept OUT of S3; an S7 exclusivity block
(EXACTLY ONE `rs[3]=argv[3];` build + ONE `log_action_argv(4, rs)`, ZERO raw `log_action("xschem
reset_symbol"` in scheduler.c AND callback.c, ZERO scattered `scheduler_readonly_reject(…,"reset_symbol")`)
PLUS a COLLISION GUARD re-asserting reset_inst_prop's `av`, embed's `ev`, replace_symbol's `av[3]`,
apply_pin_prop's `pp`, move_instance's `mi`, and image's `im` all stay == 1.

**Sabotage ×6** (each fails EXACTLY its checks; restore from `scratchpad/atom22_backup/scheduler.c.golden`,
NOT git — ~200 dirty sibling worktrees): (1) add `push_undo` to the arm → fix_symbols undo-batch checks
(g)/(g2) fail (only the last remap reverts); (2) re-add a scattered `scheduler_readonly_reject` → grep S7
readonly=1; (3) drop `log_action_argv(4, rs)` → grep S1/S7 (rs emit count 0) AND test (a) exactly-+1; (4)
raw `%s` instead of Tcl_Merge → test (e) metachar (logs raw `x2[3:0]`, replay errors `invalid command name
"3:0"`); (5) drop the argc!=4 gate → test (b) (too-few now returns TCL_OK with a corrupt empty name).

**Adversarial refute panel + completeness critic (Workflow, ultracode), against the frozen change.**
Axes = undo-batch integrity / log-on-success / two-referent replay-safety / readonly-gate correctness /
C89 / entry-completeness (incl. the fix_symbols Tcl caller). Verdict `ship`, 0 critical/major. All axes
CLEAN (readonly-gate a NIT: fix_symbols on a read-only cell now throws UNCAUGHT at the first reset_symbol,
after its no-op push_undo — strictly better than the old silent read-only mutation; the residue is a
cosmetic console error in a power-user utility, no state-integrity defect; readonly is per-cell so no
partial remap). Completeness critic found THREE non-blocking gaps, TWO fixed here: (1) the "must NOT
set_modify" half of the divergence was UNTESTED — a set_modify(1) regression would pass all checks (it
pushes no undo slot, and fix_symbols set_modify(1)'s anyway) yet fire N mid-loop autosave write_backup()
of a half-remapped sheet — CLOSED by new check (a3) (standalone reset_symbol on a cleared sheet leaves
`modified` == 0); (2) check (a)'s "result BLANK" rationale + the source/test comments wrongly claimed the
old branch set the instname result — FIXED (the old branch already Tcl_ResetResult'd; it is a preservation
guard). ACCEPTED CAVEAT (3, low-sev, inherent to the verb): reset_symbol's required companion
`reload_symbols` is NOT a logged verb, so an action-log replay of a fix_symbols session swaps inst.name but
leaves inst.ptr/bbox/node-hash STALE until a later relink — the low-level-batch-sub-step replay class
(kin to embed_rawfile's external-file caveat / the 0005 companion-step class). No crash (ptr stays
in-range), and a save writes the correct new name (ptr is not serialized). This is a pre-existing property
of the verb's design (the branch documents "caller must reload_symbols afterward"), not a regression;
logging reload_symbols is out of atom-22 scope (it is a separate, unmigrated verb). The two errored refute
axes (undo-batch, replay-safety — schema-retry cap) were re-run as plain agents and returned CLEAN.

RECOMMENDED NEXT: after reset_symbol the additive-log pool holds only `instance_number` (higher-friction:
needs the C1 query/mutate split + the shared `change_elem_order` core kept silent below the boundary + a
new verb name) then `text` (additive-log, already gated). The §40 deferrals still stand (composite
delete/cut/copy/save/reload; selection-referent replay is the accepted 0005 class).

## 43. Refactor B ATOM 23 (2026-07-17): the TWENTY-THIRD per-verb migration — a QUERY/MUTATE SPLIT whose read-only-safe QUERY stays RAW in front, whose MUTATE calls the shared `change_elem_order` core silently, and whose two-referent log has NO had_sel gate (`instance_number`)

`instance_number` was the sole remaining ADDITIVE-LOG candidate from the §42 shortlist — a **three-way
SYNTHESIS** of already-shipped templates, not new machinery: the image §40 QUERY/MUTATE SPLIT, the
reset_symbol §42 two-referent Tcl_Merge log, and the change_elem_order §41 shared-sub-step lock.

**The verb.** `xschem instance_number <inst> [n]` has TWO forms sharing one branch:
- **QUERY** (`argc == 3`): return the array position (z-order index) of instance `<inst>` — a pure
  read-back, NO mutation / undo / log / readonly gate. Its result IS consumed (the `idx` proc in the
  tests reads it; it is the z-order read-back oracle of the change_elem_order test).
- **MUTATE** (`argc > 3`): `unselect_all + select_element(<inst>) + rebuild + change_elem_order(atoi(n)) +
  draw` — reorder `<inst>` to array position `n`, returning the requested n (pre-migration). Its result is
  consumed by NO caller (grep-verified: the only MUTATE callers are this suite + oracle scripts).

**THE C1 FRICTION — the QUERY/MUTATE SPLIT (the image §40 template).** ONLY the MUTATE form crosses the
boundary. The read-only-safe QUERY stays RAW in the branch IN FRONT of the boundary, for TWO reasons the
boundary would otherwise break: (a) the boundary's ONE unconditional readonly gate would OVER-REJECT a pure
position read-back on a read-only cell (check (b) pins TCL_OK + correct position on a read-only cell); (b)
the success-path `Tcl_ResetResult` would WIPE the position result that `idx` consumes. So the branch keeps
`!xctx`, the `argc<3` gate, `get_instance`, and (argc==3) the `Tcl_SetResult(my_itoa(i))` reply + return;
ONLY `if(argc > 3) return perform_action("instance_number", argc, argv)`.

**THE MUTATE-FORM RESULT (the apply_pin_prop §18 wrinkle).** The old mutate returned
`my_itoa(atoi(argv[3]))`. NO caller consumes it (the QUERY result is what `idx` reads), so the boundary's
success-path `Tcl_ResetResult` DROPS it (accepted, like apply_pin_prop's `0`/`1` drop). The standalone
checks assert the EFFECT (z-order via the QUERY form), not the result.

**THE SHARED-SUB-STEP LOCK (the change_elem_order §41 / attach_labels §11 template).** The MUTATE calls
`change_elem_order()` (editprop.c) RAW — the SAME core already on the boundary under the `change_elem_order`
verb. That core OWNS its push_undo (for n>=0 it calls `xctx->push_undo()` unconditionally) + `set_modify(1)`.
So the run_core arm adds NEITHER (a double-push would regress undo granularity — the atom-1 no-double-push
rule). And the raw `change_elem_order()` sub-step stays SILENT below the boundary: instance_number logs its
OWN `instance_number` line, NOT a `change_elem_order` line. This is a load-bearing lock — sabotage 6 (make
the sub-step self-log a change_elem_order line) is caught BOTH by the grep-guard change_elem_order-unperturbed
S7 rows (count 2) AND the runtime test (h2).

**TWO REFERENTS, both Tcl_Merge-quoted, NO had_sel gate.** core_log_action logs `xschem instance_number
<inst> <n>` via a COLLISION-DISTINCT `const char *ino[4]` (av/ev/pp/mi/im/rs + replace_symbol's av[3] all
taken — §36): `ino[2]=argv[2]` (instance, can be arrayed `x2[3:0]`), `ino[3]=argv[3]` (n, a bareword). Both
via `log_action_argv`/Tcl_Merge, NOT raw `%s` — a raw `x2[3:0]` replays `[3:0]` as a command substitution
(DEMONSTRATED by sabotage 5: `invalid command name "3:0"`). A replay ADVANTAGE over change_elem_order (§41):
instance_number's mutate is SELF-CONTAINED — run_core does `unselect_all + select_element(argv[2])` itself,
so replay does NOT depend on ambient selection (no had_sel/0005 dependence). Hence the log is UNCONDITIONAL
on success — NO `if(xctx->lastsel)` gate.

**THE n >= 0 GATE (a replay-safety divergence, added after the refute/critic pass).** `change_elem_order(n<0)`
opens the interactive "Object Sequence number" input_line DIALOG. change_elem_order's VERB gates `n >= 0 ||
n == -1` — it ALLOWS -1 because -1 is its Shift-S interactive form (whose logged `-1` line is the accepted
interactive-replay class). instance_number is a PURE SCRIPTED verb (no key/menu/interactive entry), so it
must NEVER reach that dialog: a scripted verb that opened a modal would WEDGE a headless action-log replay,
and — now that the mutate is LOGGED — a `xschem instance_number <inst> <neg>` line would replay straight into
that wedge. So the run_core arm REJECTS n<0 with an early TCL_ERROR ("invalid order (need n >= 0)"); via
log-on-success it mutates nothing and logs nothing. This keeps EVERY logged instance_number line a
deterministic, dialog-free, faithfully-replayable reorder — squarely the action-log refactor's core invariant.
This is a DELIBERATE divergence from change_elem_order's `|| n == -1` allowance (that verb has an interactive
form to preserve; this one does not).

**Migration.**
- **Scheduler branch (~5265):** rewritten to the query/mutate split above; doc-comment mirrors image's §40.
- **`run_core` arm (~902):** re-asserts the `argc<3` + `get_instance` gates (early TCL_ERROR before any
  mutation; the argc<3 gate keeps the branch message in parity, and — since run_core is reached ONLY via the
  branch's `if(argc>3)` delegation — argv[3] is always present), then the `n >= 0` gate, then
  `unselect_all(0); select_element(i,SELECTED,1,1); rebuild_selected_array(); change_elem_order(atoi(argv[3]));
  draw();`. NO push_undo / NO set_modify — change_elem_order() owns push_undo (on the mutate path) +
  set_modify(1) (the set_modify gated on its local `modified`). C89: `int i` at block top.
- **`core_log_action` arm (~1222):** the `ino[4]` two-referent Tcl_Merge build, reached only on TCL_OK.

**Verification.** `tests/headless/test_perform_action_instance_number.tcl` (59 checks, full_audit
logdir_tests, self-deferring on no-logdir): (a) MUTATE success reorders (asserted via the QUERY form) +
exactly +1 byte-exact `xschem instance_number R2 0` + interp result BLANK; (a2) QUERY on an editable cell
returns the position + logs NOTHING; (b) QUERY on a READ-ONLY cell stays TCL_OK + correct position + no log
(the headline of the split — NOT over-rejected); (c) MUTATE on a read-only cell REFUSED (TCL_ERROR,
verb-named) + no reorder + no log (the NEW gate); (d) argc<3 → TCL_ERROR + no log; (d2) n<0 REJECTED
(TCL_ERROR "invalid order", both -1 and -5) + no reorder + no log + NO dialog opened (the replay-safety
gate); (e) instance-not-found (BOTH forms) → TCL_ERROR + no log; (f) metachar referent `x2[3:0]` round-trips
via Tcl_Merge (brace-quoted; the exact line REPLAYS + re-applies); (g)/(g2) undo: standalone mutate SETS
modified=1 + ONE undo reverts a single reorder, and a 3-instance / 2-mutation / 2-undo sequence returns to S0
(the DOUBLE-PUSH detector — a single mutate+undo can't distinguish a double-push, so g2 is load-bearing);
(h1)/(h2) the shared-sub-step lock at runtime (a `change_elem_order` verb still logs its OWN line; an
`instance_number` mutate logs ZERO change_elem_order lines + its own `instance_number` line) + the
SELF-CONTAINED replay round-trip (the recorded line re-applies through the suppress seam WITHOUT re-logging
AND without a fixture re-selection; a control unwrapped `source` re-logs); (i) NUMERIC-INDEX referent
(`instance_number 0 1`) applies + logs unbraced + replays; (j) OUT-OF-RANGE n clamps in-core while the log
records the RAW n (value-preserving, replays to the same clamp); (k) NO-OP reorder (n == current index) still
logs +1 + sets modified + one undo restores (consistent with the change_elem_order core). Build cairo
(default) OK.
**Sibling + guard PASS:** test_perform_action_change_elem_order (its (h) shared-sub-step check still green —
instance_number now logs its own line but ZERO change_elem_order lines), test_perform_action_image,
test_perform_action_reset_symbol, test_selflog_grep_guard (all green). **Baseline-diff CLEAN:** the pre-edit
(HEAD atom-22, 0ddc2951) binary fails test_selflog_output with the IDENTICAL 6 transform-key-injection flakes
(Shift-F/Alt-F/Shift-R/Alt-R/Shift-V/Alt-V — the standing nondeterministic WSLg key set; NONE reference
instance_number), byte-identical pre/post; ZERO new deterministic fails.

**grep guard (test_selflog_grep_guard.tcl):** S1 rows — the boundary branch delegation row, the run_core
gate statements (count 2 — BOTH the raw-front query gate AND the run_core defensive re-assert; removing
either drops below 2), the `change_elem_order(atoi(argv[3]))` sub-step, the core_log_action line-anchored
`ino`-build + the `log_action_argv(4, ino)` emit; `instance_number` ADDED to S2 CVERBS, kept OUT of S3; an
S7 exclusivity block (EXACTLY ONE branch delegation + ONE `ino`-build + ONE `log_action_argv(4, ino)` +
ONE `change_elem_order(atoi(argv[3]))`, ZERO raw `log_action("xschem instance_number"` in scheduler.c AND
callback.c, ZERO scattered `scheduler_readonly_reject(…,"instance_number")`) PLUS the CRITICAL
change_elem_order-UNPERTURBED guard (`log_action("xschem change_elem_order %"` + the total stay == 1 — the
raw sub-step added no second) PLUS a COLLISION GUARD re-asserting av / ev / av[3] / pp / mi / im / rs all
stay == 1.

**Sabotage ×7** (each fails EXACTLY its target; restore from `scratchpad/atom23_backup/scheduler.c.golden`,
NOT git — ~200 dirty sibling worktrees): (1) whole verb delegates (query crosses) → SIGSEGV (the query
argc==3 reaches run_core which reads argv[3] OOB — the raw-front split is a crash-safety fix, not just a
readonly one); (2) add push_undo to the arm → test (g2) double-push (2 undos leave S1 not S0); (3) re-add a
scattered `scheduler_readonly_reject` → grep S7 readonly=1; (4) drop `log_action_argv(4, ino)` → grep
S1/S7 (ino emit count 0) AND test (a) exactly-+1; (5) raw `%s` instead of Tcl_Merge → test (f) metachar
(logs raw `x2[3:0]`, replay errors `invalid command name "3:0"`); (6) make the raw change_elem_order(n)
sub-step self-log → grep change_elem_order-unperturbed S7 (count 2) AND test (h2); (7) remove the `n >= 0`
gate → test (d2) (n=-1/-5 no longer TCL_ERROR + the dialog stub fires).

**Adversarial refute panel + completeness critic (Workflow, ultracode), against the frozen change.**
Axes = query/mutate-split correctness (readonly + result-preservation) / shared-core-stays-silent /
two-referent replay-safety / undo (no double-push) / C89 / entry-completeness (incl. every instance_number
Tcl caller + the MUTATE-result consumer question). Verdict: all SIX refute axes returned refuted=FALSE
(severity none) — the query/mutate split refuses nothing it should answer and preserves the consumed QUERY
result; the raw change_elem_order() sub-step is provably silent (editprop.c has no log_action; the
select/unselect/rebuild/draw chain is silent; only `verb` drives core_log_action); the two referents replay
faithfully (identical argv pointers, Tcl_Merge, self-contained re-selection so no 0005 class); exactly ONE
undo slot per mutate (change_elem_order owns it); C89-clean (decls at block top, no set-but-unused, perform_action
prototyped); a full-tree grep confirms NO other entry point and NO MUTATE-result consumer. Completeness critic
verdict = **ship**; it raised FOUR non-blocking gaps, all ADDRESSED here: (1) the dangling §43 audit reference
— this section; (2) the n<0 mutate reaching change_elem_order's interactive DIALOG + logging a replay-unfaithful
line — CLOSED by the new `n >= 0` gate (the load-bearing fix above) + check (d2) + sabotage 7; (3) the imprecise
"push_undo gated on `modified`" comment (push_undo is UNCONDITIONAL on the mutate path; only set_modify is
modified-gated) — REWORDED in the branch/run_core comments + the grep-guard S1 row; (4) untested
numeric-index referent / out-of-range clamp / no-op reorder — CLOSED by new checks (i)/(j)/(k). Re-verified
after the fixes: 59 test checks + 355 grep-guard checks green, all seven sabotages re-confirmed.

RECOMMENDED NEXT: after instance_number the additive-log pool holds `text` (additive-log, already gated).
Then re-scout the roster for the next tractable atom. The §40 deferrals still stand (composite
delete/cut/copy/save/reload stay deferred — shared cores, §4; selection-referent replay is the accepted
0005 class).

## 44. Refactor B ATOM 24 (2026-07-17): the TWENTY-FOURTH per-verb migration — the FRESH-RE-SCOUT winner, a BARE no-arg mutating verb whose core owns its undo, and the §40 delete/cut/copy lumping CORRECTED (`delete`)

**The re-scout, and why it was needed.** The `text` additive-log candidate named above was disqualified on a
source scout (the drop-funnel already logs it; it is a shared sub-step of `create_graph`/`place_sym_pins`),
exhausting the named pool. Rather than guess, we re-ran the atom-12 fan-out method (one reviewer per
`xschem_cmds_[a-z]` dispatch group, re-verify survivors from source) against the CURRENT contract — which is
no longer the atom-12 "always succeeds" boundary but the atom-13 **log-on-success** boundary, extended by the
atom-20/23 **query/mutate split** and the atom-21 **log-gate flip**. Those three pattern-expansions retired the
three biggest atom-12 failure families (validating verbs, read-only-safe query forms, conditional logs), so the
atom-12 taxonomy is stale as a *filter* even though its *method* is not. Full write-up:
`doc/claude/code_analysis/perform_action_atom24_delete_friction_analysis.md`. **303 branches** classified across
all 22 groups; **8** un-migrated mutating candidates; **3** confirmed genuine after a two-lens adversarial
re-verify (`delete` fr 3, `add_pin_stubs` fr 4, `check_unique_names` fr 5); **5** rejected (`cut` D4-composite,
`make_sch_from_sel` D2-dialog, `fluid_pass` D4-router+D2-returns-data, `setprop` D3/D4, `apply_properties`
D3-replay-vehicle whose logging the decision doc forbids at the engine).

**The §40 lumping, corrected.** §40 deferred "composite delete/cut/copy" together as "shared cores." The
re-scout **splits that lump**: `cut` (`save_selection(2)` + `delete(1)`) and `copy` (`save_selection(2)`) ARE
composites of other verbs and stay deferred (D4, fail the 1:1 test); but **`delete` is the PRIMITIVE those
composites call**, not a composite itself. `delete()` (select.c) is a benign SHARED sub-step — the `cut` verb,
three preview teardowns (`delete(0)`), `save.c`, and the callback.c interactive gestures all call it raw — but
it ROUTES NO VERBS through the boundary, so only the `delete` VERB crosses and every shared caller stays raw
below it (the trim_wires atom-1 shared-sub-step rule, the attach_labels atom-11 shared-core rule). Low raw
friction is not fitness (`cut` scored the lowest raw friction, 2, and is still D4); a verb that is a composite
of other verbs fails D4 no matter how short its branch looks.

**The migration.** `delete` is a BARE no-arg mutating verb, the near-twin of `toggle_ignore` (atom 12) /
`floaters` (atom 10): `delete()` OWNS its undo (`push_undo` on the first mutation, select.c:707), `set_modify`
(788) and `draw()` (790), and returns **void** ⇒ the run_core arm is always TCL_OK and adds **no**
push_undo/draw (the atom-1 no-double-push rule). The bare `xschem delete` logs via `core_log_action`'s DEFAULT
`xschem %s` arm (no per-verb branch). The scheduler branch collapses to
`return perform_action("delete", argc, argv);`, dropping the inline `scheduler_readonly_reject` + the
`if(argc==2) log_action("xschem delete")` (the boundary owns both). The two inline legacy-switch KEYS — Ctrl-X
(`callback.c`, logs `xschem cut`) and XK_Delete (`callback.c`, logs `xschem delete`) — call `delete()` directly,
self-log, and NEVER reach this branch, so they stay untouched with **no double-log** (the shipped `cut`
arrangement; F-2ndentry).

**The one friction (F-validate), and the one deliberate behaviour tighten.** The old branch acted only inside
`if(argc==2)`, so a malformed `xschem delete <extra>` was a **silent TCL_OK no-op**. Under log-on-success that
silent no-op would be PHANTOM-logged, so `run_core` validates `argc==2` and returns TCL_ERROR otherwise
(mutating nothing, logging nothing — the reset_inst_prop §33 argc-gate). This is the ONE behaviour change: a
malformed extra-arg call goes from silent-OK to a rejected error — correct (a malformed request is not a
replayable edit) and mainstream. The no-op-still-logs property (§30/§32) is UNTOUCHED: `xschem delete` with
nothing selected bails before push_undo, mutates nothing, returns void ⇒ TCL_OK ⇒ STILL logs one line.

**Test (test_perform_action_delete.tcl, 24 checks, registered in full_audit logdir_tests):** (a) SUCCESS —
a selection deleted, exactly +1 byte-exact `xschem delete`; (b) THE ATOM-24 HEADLINE — `xschem delete extra`
returns TCL_ERROR with a NON-EMPTY verb-named message (the atom-13 landmine: success-only Tcl_ResetResult did
not wipe it), +0 log, no mutation; (c) readonly reject — TCL_ERROR + non-empty read-only message, +0 log, no
mutation; (d) REPLAY — the recorded `xschem delete` re-executes through the replay_action_log suppress seam
(deleting the ambient selection) but does NOT re-log, while a control unwrapped `source` DOES re-log; (e)
NO-OP-STILL-LOGS — nothing-selected `xschem delete` mutates nothing but STILL logs +1; (f) UNDO DEPTH — the
fixture places 3 (each `xschem instance` pushes undo), delete pushes ONE more; one undo restores all 3, a
SECOND undo peels back one placement (3→2) — a spurious run_core double-push would leave an identical extra
snapshot so the second undo would still read 3; (g) SIBLING UNTOUCHED — `xschem cut` still deletes + logs its
OWN `xschem cut` line, +0 `xschem delete`. Build cairo (default) OK.

**Sabotage ×2 (each fails EXACTLY its target):** (A) remove the argc==2 arity gate (extra-arg deletes+logs) →
test (b) all four checks fail (rc=0, empty msg, +1 log, mutation). (B) add a spurious `xctx->push_undo()`
before `delete(1)` → test (f) second-undo fails (reads 3 not 2 — the identical duplicate snapshot). Both
reverted; clean re-run all 24 green. **grep guard (test_selflog_grep_guard.tcl):** the S1 scheduler.c `delete
branch` manifest row was updated from the old `log_action("xschem delete")` (inline, now GONE) to
`return perform_action("delete", argc, argv);`; the callback.c `Delete inline key` row is UNCHANGED (the key
keeps its raw self-log). `core_log_action`'s bare-verb comment list gains `delete`.

RECOMMENDED NEXT: the friction re-scout's runner-ups — `add_pin_stubs` (fr 4: a return-value conditional log
`if(added>0)` the boundary cannot re-derive + `-prefix/-suffix` flag fidelity) and `check_unique_names` (fr 5:
a query/mutate split whose mode-0 highlight is *currently logged*, so an asymmetric split). Both are viable but
carry more friction than `delete`; sequence the cheaper isolated wins first. `text` stays disqualified;
cut/copy/save/reload stay deferred (composites, §4/§40).

## 45. Refactor B ATOM 25 (2026-07-17): the TWENTY-FIFTH per-verb migration — the fr-4 runner-up whose RETURN-VALUE CONDLOG dissolved into OPTION (c) NO-OP-STILL-LOGS (`add_pin_stubs`)

**The decision, and why it dissolved.** `add_pin_stubs` (draw a wire stub + an outward `lab_pin` net-label
out of each selected/unconnected pin) was the atom-24 re-scout's fr-4 runner-up. Its old branch logged
`if(added > 0) log_action_argv(argc, argv)` — a log gated on the core's RETURN VALUE, which the boundary
cannot re-derive in `core_log_action` (unlike atom-21's `had_sel`, still sitting in `xctx`). The decision
(full write-up: `doc/claude/code_analysis/perform_action_atom25_add_pin_stubs_returnvalue_condlog_decision.md`)
weighed three options: (a) `TCL_ERROR` on `added==0` — REJECTED, it mis-classifies a no-op success as a
failure; (b) a side-channel field — REJECTED, new bespoke machinery for one verb; (c) embrace
no-op-still-logs. **(c) won** on the sharp question: `added==0` (nothing unconnected to stub) is a no-op
SUCCESS, not a failure — the SAME shape as floaters-nothing-selected (§30), toggle_ignore-attr==NULL (§32)
and delete-nothing-selected (§44), all of which log their no-op. The boundary's rule is log-on-success and
a no-op is a success, so the `if(added>0)` suppression was a policy the boundary had ALREADY reversed
elsewhere. The fr-4 friction was an artifact of the assumption that the old gate must be preserved; drop
that assumption and the wrinkle disappears — exactly the move atom 24 made for `delete`'s arity gate.

**The migration.** `run_core` parses `-prefix/-suffix/-inst-prefix` (identically to `core_log_action`),
calls `add_pin_stubs()` (which OWNS its single push_undo + set_modify + draw, so the arm adds none — the
no-double-push rule), **DISCARDS the returned count**, and always returns `TCL_OK`. The branch collapses to
`return perform_action("add_pin_stubs", argc, argv)`. `core_log_action` gets a per-verb arm: a fresh heap
array `aps` sized to `argc`, the flag tail copied verbatim, emitted via `log_action_argv` (the image `im[]`
template §40 — NOT the bare `log_action_argv(argc, argv)` form the old branch used, which recurs at
`paste/...` and can't be grep-pinned; `aps` is distinct from av/ev/pp/mi/im/rs/ino, the §36 collision
lesson). A `-prefix a[0]` value brace-quotes and replays (issue-0048). Two benign behaviour changes: (1)
the `added==0` no-op now logs one idempotent line; (2) the success-path count interp-result is dropped —
**grep-verified no consumer** (the Symbol-menu `-command` discards it; the SPACE key reads the C-fn int
return, not the Tcl result — the `apply_pin_prop` §38 precedent). The boundary ADDS the C-level readonly
gate the scripted verb never had (a correctness fix — was a silent `return 0`); the core keeps its OWN
silent `if(readonly) return 0` for the SPACE key's pan-on-decline dual-use. The SPACE key
(`act_add_pin_stubs`, callback.c) stays RAW below the boundary and never reaches the branch → no double-log
(the delete/cut F-2ndentry pattern).

**Test (test_perform_action_add_pin_stubs.tcl, 22 checks, registered in full_audit logdir_tests):** (a)
bare success — 2 stubs (2 wires + 2 lab_pin), exactly +1 byte-exact `xschem add_pin_stubs`; (a2) flag form
— net names reflect `-prefix p_ -suffix _s` (p_P_s/p_M_s) + byte-exact flag-tail log; (b) THE OPTION-(c)
HEADLINE — nothing-selected no-op mutates nothing but STILL logs +1 (old `if(added>0)` suppressed it); (c)
readonly reject — `TCL_ERROR` + non-empty message, no mutation, no log (was a silent `0`); (d) replay
through the suppress seam (re-stubs the selection) not re-logged, control re-logs; (e) FLAG-FIDELITY —
`-prefix a[0]` logs BRACE-QUOTED (`{a[0]}`) and the exact line replays without a Tcl error; (f) undo depth —
one undo removes the stubs (3→1 inst), a SECOND removes the placed instance (1→0), a double-push would
leave the second undo at 1. **Sabotage ×2 (each fails EXACTLY its target):** (A) `TCL_ERROR` on `added==0`
→ test (b) no-op-still-logs fails; (B) spurious `push_undo` → test (f) second-undo fails. Both reverted;
clean re-run all 22 green. **grep guard:** 4 new S1 manifest rows (branch delegation + the `aps` decl/copy/
emit) + a 5-check S7 exclusivity block (EXACTLY ONE `aps` decl / `aps[j]=argv[j]` copy / `log_action_argv(argc,
aps)` emit; ZERO scattered `log_action("xschem add_pin_stubs")` in scheduler.c AND callback.c). Build cairo
(default) OK.

**Filed separately (issue 0121, NOT bundled):** the core pushes undo unconditionally at the top of its loop,
before knowing whether any target will stub — a LATE no-op (targets exist but all are nameless-empty-net
skips → `added==0`) leaves a spurious undo slot. Pre-existing (independent of the migration); the atom-25
test uses the EARLY no-op (nothing selected) to avoid entangling it. Fix = lazy push_undo on the first
actual store.

RECOMMENDED NEXT: `check_unique_names` (fr 5: a query/mutate split whose mode-0 highlight is *currently*
logged, so an asymmetric split — the harder of the two remaining scout runner-ups). Then re-scout again;
`text` stays disqualified; cut/copy/save/reload stay deferred (composites, §4/§40).
