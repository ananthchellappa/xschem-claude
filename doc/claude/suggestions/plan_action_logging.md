# Plan — Action Logging (replayable Tcl command log)

**Status:** Phase 0 IMPLEMENTED on branch `feature/action-logging` (off
`refactor/dispatcher-decomposition`). Phases 1–3 not started.
**Author of intent:** user (ananth.ch). **Analysis:** this session, 2026-06-10.

## Progress

- **Phase 0 — DONE.** Log file + `--logdir` + the `log_action()` sink.
  - `--logdir <dir>` option (`options.c`); global `cli_opt_logdir` (`globals.c`,
    `xschem.h`).
  - Sink in `util.c`: `init_action_log()` opens the rotating
    `Xschem.log` / `Xschem.log.1` / … (first free name, untitled-namer idiom) on
    its own `FILE*` `actionlog_fp` (separate from `errfp`); `log_action(fmt,…)`
    writes one line. Header line is a Tcl comment (`# xschem action log`) so the
    log stays source-able. Resolved path kept in `actionlog_filename`.
  - Wired in `main.c` right after `process_options()` (cwd + stderr still intact,
    before any detach redirect).
  - **Phase-0 policy decision (mine):** the log is opened only for an interactive
    session (`has_x`) OR when `--logdir` is given explicitly — so headless
    script/netlist/test runs don't litter the cwd, while automation can opt in.
  - `--logdir` dir is created if absent; **fatal** (exit 1 + stderr message) if it
    cannot be created or is not a directory. File-open failure is non-fatal
    (logging disabled), since the spec makes only dir-creation fatal.
  - `xschem.help` documents the option; `.gitignore` ignores `Xschem.log*`.
  - Smoke: `tests/headless/test_action_log.sh` (creation, header, rotation,
    fatal-on-bad-dir, no-litter). Full suite (engine 6/6 + all binding smokes)
    still green.
  - NOTE: `mkdir` is single-level (matches `create_tmpdir`); a `--logdir` with
    missing *intermediate* dirs would fail. Acceptable for now; revisit if needed.
- **CIW — DONE** (2026-06-10, user-requested insert before Phase 1; spec in
  `doc/claude/specs/action_logging.md` §3). Virtuoso-style Command Interpreter Window:
  `src/ciw.tcl` — toplevel, vertical `panedwindow` (user-adjustable sash),
  read-only log pane + one-line command entry; auto-opened at startup for
  interactive sessions from `xschem.tcl`. `log_action()` (`util.c`) mirrors
  every file line to the pane via a guarded `tcleval` (text passed through a
  Tcl var, never substituted — brace/bracket/$ safe). Typed commands: echoed
  input-tagged, evaluated `uplevel #0`, result/error pane-only; recorded in
  the file AFTER eval (raw on success, `# failed: <cmd>` comment on error, so
  the file stays source-able). New subcommands: `xschem log_action [-noecho]
  <text>` (scheduler `l` block; -noecho = file-only, used by the CIW entry
  which echoes itself) and `xschem get actionlog_filename`. Smoke:
  `tests/headless/test_ciw.tcl` (24 checks incl. record→source round-trip of
  the produced file). Suite green (headless harness + all 12 GUI smokes +
  Phase-0 smoke). NOTE: `tests/run_regression.tcl` is NOT runnable in this
  environment (resolves XSCHEM_SHAREDIR to the non-existent install dir) —
  pre-existing, unrelated.
- **Next: Phase 1** — Layer A (`dispatch_input_action`) + context menu, emitting
  real `xschem …` lines via `log_action()`. The CIW makes these visible live;
  `xschem get actionlog_filename` gives tests the file path.

---

## 1. Intention (what the user asked for)

A logging feature with two parts.

**Easy part — the log file:**
- Write to a file `Xschem.log` in the current working directory. If it already
  exists, use `Xschem.log.1`, then `Xschem.log.2`, … — i.e. the first free name
  in the increment sequence (same idiom as the `untitled.sch` / `untitled-1.sch`
  namer at `save.c:3696`).
- A `--logdir <dir>` command-line option overrides the directory. The directory
  is created if it does not exist; if it cannot be created, xschem exits with an
  error message.

**Hard part — log every user action:**
- *Every* action the user takes is logged.
- Crucially, each logged line MUST be a command the user can **execute in Tcl**
  (i.e. a real `xschem …` command), so the log is replayable — not a prose audit.
- Gestures are logged by their *effect*, as a single action:
  - RMB click + release without moving → a context-menu pick → the chosen action's
    command.
  - RMB press + drag + release → one zoom-rectangle action →
    `xschem zoom_box x1 y1 x2 y2`.

---

## 2. Decisions (locked by the user)

1. **Log-line format = whatever is a valid `xschem …` Tcl command.** The
   `verb(point1, point2)` notation in the original spec was conceptual; the actual
   log lines are real Tcl (e.g. `xschem zoom_box 100 200 400 500`).
2. **Default location = the current working directory** xschem was launched from
   (only overridden by `--logdir`).
3. **Granularity = log the *effect*, when that effect is achievable through Tcl.**
   A multi-event gesture collapses to its single resulting command (the whole
   RMB-press→drag→release is logged as one `xschem zoom_box …` line).
4. **Object-reference gap is accepted for v1.** Selecting an object by *clicking*
   resolves a screen coordinate to the nearest object via `find_closest_obj()`
   (`findnet.c:506`), which has **no Tcl entry point**; and `xschem select`
   addresses instances only by name/number and wires by index — pins and text have
   no stable Tcl referent. So a click-select cannot be faithfully replayed yet.
   For v1:
   - Log a non-replayable marker for actions with no Tcl form, e.g.
     `# <action not reproducible through TCL>`.
   - For the specific click-select case, log a richer marker recording *what* and
     *where*, e.g. `# selected instance at <x_click> <y_click>` — enough to
     reconstruct intent, upgradeable once a Tcl referent exists (see §6, future).
5. **Minimal scope for the first pass.** Land the smallest useful slice first;
   defer breadth.

---

## 3. Analysis — how the codebase produces actions

(Verified by reading the source this session; file:line are current on
`refactor/dispatcher-decomposition`.)

### 3.1 What already exists in our favor
- **Single dispatch chokepoint for bound keys/buttons/wheel:**
  `dispatch_input_action()` at `callback.c:2640`. It resolves a binding to an
  `ActionDef { const char *id; action_fn fn; const char *tcl; const char *help; }`
  (`callback.c:2327`, registry at `:2329`) and runs **either** a C function
  (`d->fn`) **or** a Tcl string (`d->tcl`, `tcleval`). Tcl-backed actions already
  carry their exact replayable command.
- **`actions.csv`** column 6 is the action's Tcl command
  (`view.zoom_full → xschem zoom_full`, `view.zoom_in → xschem zoom_in`). It is a
  ready-made `action_id → replayable command` map — but only for actions that have
  one; it is **empty** for the pure-C viewport actions. Loaded Tcl-side via
  `load_action_table` (`xschem.tcl:10178`); the C `ActionDef` does not currently
  carry this column.
- **Most edit operations already have replayable subcommands:** `zoom_box`,
  `move_objects dx dy`, `copy_objects`, `wire`/`line`/`rect`/`polygon`/`arc`,
  `place_symbol`, `place_text`, `rotate`/`flip`/`flipv`,
  `select`/`select_inside`/`select_all`, `delete`/`cut`/`paste`, `hilight` family.
- **Clean precedents:** `--log` / `-l` option parsing (`options.c:120`);
  `create_tmpdir()` `stat()`+`mkdir()`+error idiom (`save.c:2448`); the untitled
  increment loop (`save.c:3696`). NOTE: `--log`/`errfp` is the **debug/stderr**
  stream — the action log must be a *separate* `FILE*` so replayable commands are
  never mixed with debug output.

### 3.2 The core tension — three layers, only one speaks Tcl
There is **no single point where every action is already a replayable command.**
Actions originate at three layers:

| Layer | Where | Emits a Tcl command today? |
|---|---|---|
| **A. Bound keys/buttons/wheel** | `dispatch_input_action()` `callback.c:2640` | Tcl-backed: **yes** (`d->tcl`). C-backed (`d->fn`): **no** — calls C directly; Tcl form only in `actions.csv` col 6, empty for some. |
| **B. Right-click context menu** | `context_menu_action()` `callback.c:2070` | **No.** Tcl `context_menu` proc returns an int 1–21; a C `switch` maps each to a **direct C call** (`start_wire`, `move_objects`, `delete`, …), bypassing the `xschem …` surface. |
| **C. Multi-phase drag gestures** | `zoom_rectangle()` `actions.c:3124`, `pan()` `actions.c:3933`, move/copy/wire/line/rect/poly draw | **No.** Only the gesture START is bound; RUBBER (motion) + END (release) are hardcoded state machines. `zoom_rectangle(END)` recomputes zoom and mutates `xctx` directly — it does **not** call `zoom_box()` nor emit `xschem zoom_box …`, though that command sits right beside it (`actions.c:3108`). |

The user's two examples land in the two hardest layers (B and C).

### 3.3 Genuine command-coverage gaps (no Tcl subcommand at all)
- **Pan** (`view.pan_*`), **Scroll** (`view.scroll_*`), **Snap** halve/double
  (`view.snap_half`/`view.snap_double`) — `actions.csv` command column empty, no
  scheduler branch.
- **Middle-button pan** — not even in the binding table; hardcoded in the button
  handler.

Because "replayable" is mandatory, making these loggable means **minting the
subcommands** (thin wrappers over existing `pan()` / scroll / snap C code as
branches in `xschem_cmds_{p,s,v}` + rows in `actions.csv`). They are out of scope
for the first pass (§5) but on the roadmap (§6).

---

## 4. Recommended design

**A dedicated action-log sink, fed from the action layer, with the action registry
as the single source of the command text.**

1. **One sink**, e.g. `log_action(const char *tcl_cmd)`:
   - Lazily opens the rotating `Xschem.log[.N]` on first write (or at startup),
     line-buffered, on its **own `FILE*`** (NOT `errfp`).
   - `--logdir` resolved and `mkdir`-ed at startup; hard-exit with message if it
     cannot be created.
2. **Feed it at the three layers**, each emitting a real `xschem …` line (or a
   `#`-marker when no Tcl form exists, per decision 4):
   - **Layer A** — at `dispatch_input_action()` after the `ActionDef` is resolved;
     derive the command from the single source (registry / `actions.csv` col 6),
     do not hand-write per call site (the action-registry "one source of truth"
     lesson). Tcl-backed actions log `d->tcl` verbatim.
   - **Layer B** — in `context_menu_action()`, emit the equivalent command per
     case (cleanest: have the menu *invoke the command* so the log records what
     actually ran).
   - **Layer C** — at each gesture's END (where final params are known): e.g.
     `zoom_rectangle(END) → xschem zoom_box x1 y1 x2 y2`; move/copy END →
     `xschem move_objects dx dy` / `xschem copy_objects …`.
3. **Close §3.3 gaps** by minting `pan`/`scroll`/`snap` subcommands (later pass).

**Why not hook the top of `xschem()` (the decomposed dispatcher):** tempting as a
one-line chokepoint, but that function also sees the *plumbing* — `xschem callback
…` fires on every mouse motion, plus constant `xschem get/set/bbox` queries. A
blanket hook would drown the log and need a filter anyway. The action layer fires
only on real actions, so it is the correct altitude.

---

## 5. Plan — phased

**Phase 0 — Log infrastructure + `--logdir` (independent, unblocks everything):**
- `src/options.c` (`check_opt` ~`:27`, `process_options` ~`:188`): add `--logdir`
  (value-taking; mirror `--log`/`-o`).
- `src/globals.c` + `src/xschem.h`: `char cli_opt_logdir[PATH_MAX]` (mirror
  `cli_opt_netlist_dir`).
- New sink (small module, or a section in `util.c`): `log_action()` +
  open-with-rotation + logdir `stat`/`mkdir` + hard-exit on failure. Reuse the
  `create_tmpdir()` idiom and the untitled-increment loop.
- `src/xschem.help`: document the option.
- Smoke: `--logdir` to a temp dir, assert the rotating filename sequence and the
  create-then-error behavior.

**Phase 1 — Layer A (bound discrete actions) + Layer B (context menu):**
- Hook `dispatch_input_action()` (`callback.c:2640`); make the C side able to read
  each action's canonical command (extend `ActionDef`/registry, or expose the csv
  command to C).
- Emit per-case commands in `context_menu_action()` (`callback.c:2070`).
- Non-replayable actions → `#`-marker (decision 4).

**Phase 2 — Layer C (gestures):**
- END hooks in `zoom_rectangle()` (`actions.c:3124`), move/copy completion
  (`end_place_move_copy_zoom()` `callback.c:1421`), wire/line/rect/poly draw.
- Emit `xschem zoom_box …` etc. with computed coords/deltas.

**Phase 3 — close coverage gaps:**
- Mint `pan`/`scroll`/`snap` subcommands in `xschem_cmds_{p,s,v}` + `actions.csv`,
  route the `act_*` C functions through them, so those gestures become replayable.

**Acceptance test (the real one):** record → replay → diff. Drive gestures via
`xschem callback …` (the existing headless smoke mechanism), capture `Xschem.log`,
then `source` it into a fresh instance and compare resulting state. Build this
round-trip as a first-class smoke as soon as Phase 1 lands.

---

## 6. Open / future items (not v1)

- **Click-select replayability (the decision-4 gap).** The clean fix is to expose
  `find_closest_obj()` (`findnet.c:506`) as a Tcl command — e.g.
  `xschem select_at x y` (select the single nearest object at a point) — which
  would make click-select fully replayable in one modest addition. Until then,
  log the `# selected … at x y` marker.
- **Stable referents for pins and text** so they too can be addressed in Tcl.
- **Faithful full-session replay** (logging the causal chain — selections,
  descend/go_back, load — not just the final verb) is explicitly *not* a v1 goal
  (decision 5); v1 is a per-action, replay-where-possible log.

---

## 7. Proposed next minimal step

**Implement Phase 0 only**, on a new `feature/action-logging` branch:
the `--logdir` option, the rotating-file open with hard-exit-on-failure, and the
`log_action()` sink wired to write one literal test line — plus the Phase-0 smoke.
This is self-contained, behavior-neutral until call sites are added, and unblocks
Phases 1–3. Review/adjust the sink's API, then proceed to Phase 1.
