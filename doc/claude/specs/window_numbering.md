# Cadence-style window numbering + activation logging to the CIW

Status: **IMPLEMENTED** (branch `fluid-editing`). Tests
`tests/headless/test_window_numbering.tcl` WN1-WN8 green + both sabotage passes;
`test_multi_window.tcl` 15/15 (6th `windows` field is additive); nand2 netlist smoke
unchanged. Decisions D1 (per-context) and D3 (number sticks to the window) confirmed
by the user. The number also shows in the **title bar** (`xschem [3] - cell`).
Related: `doc/claude/specs/multi_window_detach.md` (the window/context model this builds on),
`doc/claude/specs/cadence_new_blank_window.md`, `doc/claude/specs/library_manager_launch.md`,
memories [[multi-window-detach]], [[ciw-feedback-channels]], [[user-run-config]].
Source anchors: `src/xinit.c` (`alloc_xschem_data`, `create_new_window`, `create_new_tab`,
`detach_tab`, `switch_tab`, `switch_window`, `new_schematic`), `src/scheduler.c`
(`get`, `windows`), `src/xschem.tcl` (`switch_window` proc), `src/ciw.tcl` (`ciw_create`,
`ciw_echo`), `src/library_manager.tcl` (`libmgr::open`).

## 1. Goal

Give every window a **stable, Cadence-like number**, and echo window **activation** into
the CIW log, exactly like Virtuoso's CIW tracks its windows.

- **Window 1 = CIW** (Command Interpreter Window) — always.
- **Window 2 = Library Manager** — always.
- **Windows 3, 4, 5, … = editor windows/contexts**, assigned in creation order and
  **kept incrementing** (never reused, never renumbered when one closes).
- The blank `untitled.sch` present at startup is **window 3**.
- **Clicking a window to activate it prints a line in the CIW log** (window 1..N).

## 2. What already exists

XSCHEM already models each open schematic as an `Xschem_ctx` in `save_xctx[]`
(slot 0 = the live `xctx`), each with a `top_path` (`""`/`.x1`…) and
`current_win_path` (`.drw`/`.x1.drw`…). See [[multi-window-detach]]. The read-only
introspection seam `xschem windows` lists one sublist per context. FocusIn on an editor
toplevel is already routed to the Tcl `switch_window` proc (`xschem.tcl:12924`), which
calls `xschem callback … <FocusIn> …` to switch the C context. The CIW
(`.ciw`, `src/ciw.tcl`) and Library Manager (`.libmgr`, `src/library_manager.tcl`) are
plain Tk toplevels; `ciw_echo {line ?tag?}` writes the CIW log pane `.ciw.l.t`.

**What is missing:** slot indices are **not** a usable number — `destroy_window`/
`destroy_tab` compact survivors into lower slots, so slot 2 can become slot 1 on a close.
There is **no** persistent per-context serial, and neither the CIW nor the Library
Manager has any number or activation binding.

## 3. Design

### 3.1 Persistent per-context number (C)

- New field `int window_number;` on `Xschem_ctx` (near `top_path`/`current_win_path`,
  `xschem.h`). `my_calloc` zeroes it, so **0 = "not a numbered editor window"** (the
  sentinel for scratch/preview/compare contexts — see D8).
- New file-scope counter in `xinit.c`: `static int window_number_counter = 3;` — reserving
  1 (CIW) and 2 (Library Manager). A helper `static void assign_window_number(void)` sets
  `xctx->window_number = window_number_counter++`.
- `assign_window_number()` is called at exactly the **three editor-context birth sites**,
  immediately after the `alloc_xschem_data(...)` that creates the new `xctx`:
  1. `xinit.c:3199` — startup main context → **3** (the launch `untitled.sch`).
  2. `create_new_window()` (`xinit.c:~1839`) — a new real window.
  3. `create_new_tab()` (`xinit.c:~1991`) — a new tab.
- **Not** called inside `alloc_xschem_data` itself (it is shared by the schematic-compare
  buffer at `xinit.c:900` and the symbol-preview contexts at `xinit.c:1413`, which must
  stay `0`), and **not** in `detach_tab()` (it moves an existing context between a
  tab and a window — the number rides along on the struct, D5).

### 3.2 Query seam (the test anchor)

- `xschem get window_number` → the current context's `window_number` (int as string).
- `xschem windows` gains a **6th trailing field** per sublist:
  `{win_path top_path group xwindow current_name number}`. Additive — existing callers
  index fields 0..4 (MW1 etc.), so the extra tail element is safe (issue 0022 already made
  each entry a proper sublist).

### 3.3 Activation logging (Tcl only)

Clean split: **C owns the numbers, Tcl owns the CIW logging.** One proc, deduped:

```tcl
# ciw.tcl
proc notify_window_active {num name} {
  global last_active_window
  if {[info exists last_active_window] && $last_active_window eq $num} return  ;# no spam
  set last_active_window $num
  ciw_echo "window $num activated: $name" result
}
```

Dedupe on `::last_active_window` is essential: FocusIn fires repeatedly (and WSLg thrashes
focus — [[keybind-raise-test-gotchas]]); we log only on an actual change of active window.

Wired at every activation edge:

| Edge | Hook | Call |
|---|---|---|
| Editor window gains focus (main `.` or detached `.xN`), incl. **re-activation after a CIW/LibMgr visit** | Tcl `switch_window` proc (`xschem.tcl:12924`), after the `xschem callback` | `notify_window_active [xschem get window_number] [file tail [xschem get schname]]` |
| Tab switch (same toplevel, no toplevel FocusIn) | the tab-switch path (`new_schematic switch … dr` funnel / tab-button command) | same |
| Click on the **CIW** | new `bind .ciw <FocusIn>` in `ciw_create` | `notify_window_active 1 CIW` |
| Click on the **Library Manager** | new `bind .libmgr <FocusIn>` in `libmgr::open` | `notify_window_active 2 {Library Manager}` |

Why the editor hook lives in the **Tcl** `switch_window` proc, not in C `switch_window`/
`switch_tab`: those bail early on `already there` (`xinit.c:1664/1719`), so returning focus
to the editor after clicking the CIW (which never changed `xctx`) would fire **no** C hook.
The Tcl proc runs on every FocusIn regardless, and the dedupe collapses the redundant ones.

## 4. Scope & decisions

- **D1 — per-context numbering.** Each schematic *context* (tab **or** window) gets its own
  number, not one number per OS toplevel. Rationale: Cadence has no tabs — each cellview is
  a "window"; and it makes "`untitled.sch` is window 3" exact. (The user's own workflow is
  windowed — [[user-run-config]] — where per-context and per-toplevel coincide.)
- **D2 — monotonic, never reused, never renumbered.** Closing window 4 does not renumber 5;
  the next new window is 6. ("keep incrementing.")
- **D3 — the number tracks the window, not the cell.** Loading another file into an existing
  window keeps its number (Cadence: window id stable, cell changes). The untitled-reuse path
  ([[untitled-reuse]]) keeps window 3 when the first real file replaces the launch buffer.
- **D4 — 1 (CIW) and 2 (LibMgr) are reserved unconditionally.** Editor windows start at 3
  even if the CIW or Library Manager is never opened (e.g. `--nolog`, which suppresses the
  CIW). `notify_window_active` is a safe no-op when `.ciw` is closed (`ciw_echo` no-ops).
- **D5 — detach/attach preserve the number** (context is moved, not recreated).
- **D6 — CIW pane only, not the replay action-log.** Activation is a focus event, not a
  replayable edit; writing it to `Xschem.log` would pollute replay. The user asked for the
  "CIW log". (No `log_action`; `ciw_echo` only.)
- **D7 — dedupe on change** (§3.3).
- **D8 — scratch/preview/compare contexts stay `window_number = 0`** and never appear as a
  numbered window (they are not created at the three birth sites).

## 5. Acceptance / tests (RED-first)

`tests/headless/test_window_numbering.tcl` (`check name ok detail` + `fail` counter), run
headless. Numbering is assertable with `--nogui`; the CIW-echo checks drive
`notify_window_active` directly (and assert `.ciw.l.t` content under `DISPLAY`).

- **WN1** startup: `xschem get window_number` == **3**.
- **WN2** `xschem windows` sole entry: `[lindex $e 5]` == **3** (6-field shape).
- **WN3** `xschem new_schematic create_window {}` → the new context's `window_number` == **4**;
  `xschem windows` lists 3 and 4.
- **WN4** monotonic / no-reuse: open (→4), open (→5), **close** window 4, open → **6**.
- **WN5** detach a tab → its number is **unchanged** (moved, not reassigned).
- **WN6** load another file into an existing window → its `window_number` is **unchanged** (D3).
- **WN7** `notify_window_active`: calling twice with the same num logs **one** line; a
  different num logs a new line; `notify_window_active 1 CIW` / `2 {Library Manager}`
  produce the reserved-number lines. (Assert on captured `.ciw.l.t` text or a test stub.)
- Each assertion **sabotage-verified**: neuter `assign_window_number` (→ all numbers 0)
  reddens WN1/WN2/WN3/WN4/WN6 (WN5 vacuously 0==0, WN7 is pure-Tcl); dropping the dedupe
  reddens WN7 (the duplicate `window 3` line reappears). Both confirmed.

**Implementation map (as built):**
- `xschem.h` — `int window_number` on `Xschem_ctx`.
- `xinit.c` — `static int window_number_counter = 3`; `assign_window_number()` helper;
  called after `alloc_xschem_data` at the startup site (former :3199), `create_new_window`,
  `create_new_tab`; dr-gated `notify_window_active` tcleval in `switch_tab` (tab activation).
- `scheduler.c` — `xschem get window_number` in the `'w'` bucket of the `get` switch
  (`argv[2][0]` dispatch — a getter in the wrong first-char case is silently unreachable);
  6th field on `xschem windows`.
- `ciw.tcl` — `notify_window_active {num {name {}}}` proc (dedupe on `::last_active_window`);
  `bind .ciw <FocusIn> {+notify_window_active 1 CIW}` in `ciw_create`.
- `xschem.tcl` — `notify_window_active [xschem get window_number]` after the `xschem callback`
  in the `switch_window` proc (both `.`/`.xN` branches).
- `library_manager.tcl` — `bind .libmgr <FocusIn> {+notify_window_active 2 {Library Manager}}`
  in `libmgr::open`.
- `actions.c` — `set_modify` title build (:249) splices ` \[N\]` between "xschem" and " - cell"
  (WN8). **Brackets MUST be backslash-escaped**: the title is a double-quoted Tcl `wm title`
  argument, so a bare `[N]` is command substitution (Tcl runs command "N" → the title breaks
  to `xschem - ` with no cell). Omitted for `window_number == 0` scratch ctxs.

**Manual eyeball (GUI):** actually clicking between the CIW, the Library Manager, and one or
more editor windows prints `window 1/2/3…` lines in the CIW; no spam on repeated focus; the
number shown for an editor window matches its title cell. Per
`doc/claude/specs/library_manager_launch.md`, scripted toplevels are auto-focused under
WSLg/Xvfb, so real focus arbitration is eyeball-only.

## 6. Out of scope

- Showing the number in the window **title bar** (Cadence does; easy follow-up via
  `set_modify`'s title strings once the field exists).
- Persisting numbers across sessions.
- Numbering other transient toplevels (property dialogs, waveform viewer, bindkey preview).
