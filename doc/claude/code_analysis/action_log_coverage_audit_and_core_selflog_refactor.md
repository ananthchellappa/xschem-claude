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

*Prepared 2026-07-14, `fluid-editing`. Analysis only — no code changed. Coverage verified in
source at HEAD by a 14-way parallel read; do not trust the status table without re-checking
the cited `file:line` anchors, which drift as the tree moves.*
