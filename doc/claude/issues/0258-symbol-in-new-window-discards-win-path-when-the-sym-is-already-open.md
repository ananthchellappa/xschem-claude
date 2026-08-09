# 0258 — symbol_in_new_window silently does nothing when the target .sym is already open

Status: **OPEN** — reproduced headlessly in both tabbed and windowed mode (transcripts below). The
GUI-only half — that the suppressed feedback is a `tk_messageBox` under `has_x` rather than the
stderr line the headless run prints — is read from the source, not measured under X.
Area: `src/actions.c` `symbol_in_new_window()` (`:2793-2815`, the else arm `:2808-2814`);
`check_loaded()` (`src/xinit.c:1812-1834`); the feedback it pre-empts in `create_new_tab()`
(`src/xinit.c:2120-2140`) and `create_new_window()` (`src/xinit.c:1971-1989`); the slot-limit mute
at `src/xinit.c:2149-2152` / `:1999-2002`
Tests: none — `grep -rl symbol_in_new_window tests/` is empty, and no headless test exercises the
"already open" branch of `check_loaded` at all. Proposed `tests/headless/test_symbol_in_new_window_0258.tcl`
Found: 2026-08-08, in the descend silent-refusal census (`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: **0249** (`descend_symbol` refuses a multi-object selection silently — the same function's
sibling refusal, and the reason the `lastsel != 1` arm below matters), **0251** (a refused descend
has no return channel; `symbol_in_new_window` is `void`, so it has none by construction), **0256**
(`open_sub_schematic` discards the descend result), **0261** (descend reports success on a blank
page — the nothing-selected arm here manufactures exactly such a page), and
[0053](0053-descend-new-window-return-should-navigate-window-chain.md),
[0035](0035-descended-new-window-spuriously-modified.md),
[0037](0037-newwin-descend-desync-and-exit-confusion.md) for the new-window family.
[0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md) is why "just
add a statusmsg" is not by itself a fix.

## The defect

`symbol_in_new_window()` guards against opening a second view of a symbol that is already open, by
asking `check_loaded()` where it is open — and then throws that answer away:

```c
src/actions.c:2793-2815
void symbol_in_new_window(int new_process)
{
  char filename[PATH_MAX];
  char win_path[WINDOW_PATH_SIZE];
  rebuild_selected_array();

  if(xctx->lastsel !=1 || xctx->sel_array[0].type!=ELEMENT) {
    if(tclgetboolvar("search_schematic")) {
      my_strncpy(filename, abs_sym_path(xctx->current_name, ".sym"), S(filename));
    } else {
      my_strncpy(filename, add_ext(xctx->sch[xctx->currsch], ".sym"), S(filename));
    }
    if(new_process) new_xschem_process(filename, 1);
    else new_schematic("create", NULL, filename, 1);
  }
  else {
    my_strncpy(filename, abs_sym_path(tcl_hook2(xctx->inst[xctx->sel_array[0].n].name), ""), S(filename));
    if(!check_loaded(filename, win_path)) {
      if(new_process) new_xschem_process(filename, 1);
      else new_schematic("create", NULL, filename, 1);
    }
  }
}
```

`win_path` is a live out-parameter, not a scratch buffer: `check_loaded()` writes into it the window
path of the context that already holds the file, and its header comment exists solely to tell the
caller so.

```c
src/xinit.c:1807-1834
/* check if filename is already loaded into a tab or window */
/* caller should supply a win_path string for storing matching window path */
...
      if(!strcmp(ctx->sch[ctx->currsch], f)) {
        dbg(1, "check_loaded(): f=%s, sch=%s\n", f, ctx->sch[ctx->currsch]);
        found = 1;
        my_strncpy(win_path, wp, S(window_path[i]));
        break;
      }
```

The else arm consumes only the boolean. Nothing raises, focuses, or switches to `win_path`; nothing
is printed; the function is `void`, so the caller cannot tell either. `xctx->semaphore` is not
touched, no undo slot is spent — the whole operation evaporates.

**What the user perceives.** With an instance selected whose `.sym` happens to be open one tab over,
Alt+i (or File → *Open selected symbol in new window*) does nothing at all: no new tab, no switch,
no dialog, no status line, no title change. The usual reading is that the key did not register, so
it gets pressed again, with the same non-result. The symbol the user asked for is sitting in a tab
they are not looking at.

**The guard also eats the feedback the callee would have given.** `new_schematic("create", NULL, ...)`
passes `NULL` for the parameter both back ends use as their *noconfirm* sentinel
(`if(win_path && win_path[0]) confirm = 0;` at `src/xinit.c:1971`; `if(noconfirm && noconfirm[0]) confirm = 0;`
at `src/xinit.c:2119`), so `confirm` stays 1 and the duplicate-open path is fully armed. It just
never runs. **The two modes differ in what is lost:**

- **Tabbed** (`create_new_tab`, `src/xinit.c:2120-2140`): a `tk_messageBox -type okcancel` warning
  `{Warning: %s already open.}` and — on Cancel, or with no X — `switch_tab(window_count, open_path, 1)`
  (`:2130` and `:2136`). The pre-check therefore suppresses a message *and* the very navigation the
  user wanted.
- **Non-tabbed** (`create_new_window`, `src/xinit.c:1973-1989`): the same warning, then a bare
  `return` at `:1982` / `:1987`. Only the message is lost, because windowed mode has no
  raise-the-existing-window behaviour anywhere — `switch_window()` swaps the C context and sets the
  title (`src/xinit.c:1874-1881`) but never raises or focuses the X toplevel.

Note the asymmetry inside the one function: the `lastsel != 1` arm (`:2799-2807`) has **no**
`check_loaded` guard, so it warns (or duplicates) normally. The noisy branch is the one nobody aims
for; the branch that names an explicit target is the silent one. That arm is also a wrong-target
hazard in its own right — with two objects selected it does not refuse, it opens the *current
cell's* `.sym` instead of the selected instance's (cf. **0249**), and if that `.sym` does not exist
it opens a blank buffer named after it (cf. **0261**; measured below).

**Entry points**, all live:

| entry | call | site |
|---|---|---|
| Alt+i | `symbol_in_new_window(0)` — new tab/window, same process | `src/callback.c:6601-6606` |
| Alt+Shift+I | `symbol_in_new_window(1)` — new xschem process | `src/callback.c:6620-6625` |
| File → *Open selected symbol in new window* | `xschem symbol_in_new_window` | `src/actions.csv:48`, rendered by `build_menu_from_table` (`src/action_registry.tcl:106`) |
| any script | `xschem symbol_in_new_window [new_process]` | `src/scheduler.c:12353-12360` |

`EQUAL_MODMASK` is `(rstate == Mod1Mask) || (rstate == Mod4Mask)` (`src/callback.c:27`), i.e. Alt or
Super with no other modifier. `src/keybindings.csv` has no row for keysym 105/73, so the hardcoded C
cases still own both chords. The menu row's `Alt+I` is a display accelerator only: it runs the
*in-process* variant, which the C handler binds to lowercase Alt+i; Alt+Shift+I is the different,
new-process action. The scheduler's own doc comment already states the behaviour as intended —
"edit it in a new tab/window **if not already open**" (`src/scheduler.c:12350`) — which is the point:
the not-already-open case was specified, and the already-open case was left as a hole.

`new_process = 1` is short-circuited by the same guard even though `check_loaded()` can only see
*this* process's windows (`src/xinit.c:1818-1820`, a loop over `get_window_ctx(i, &wp)` across the
20 local slots). So Alt+Shift+I —
an explicit request for a **separate process** — is refused because the file is open in a tab of the
current one. That is wrong independently of the silence.

**Secondary mute, same neighbourhood.** When every window slot is taken, the create back ends print
a `dbg(0, ...)` and return:

```c
src/xinit.c:2149-2152          (create_new_tab; the windowed twin is src/xinit.c:1999-2002)
  if(*window_count + 1 >= MAX_NEW_WINDOWS) {
    dbg(0, "new_schematic(\"new_tab\"...): no more free slots\n");
    return; /* no more free slots */
  }
```

`MAX_NEW_WINDOWS` is 20 (`src/xschem.h:158`), slot 0 being the main window, so the ceiling is 19
extra tabs/windows. Both back ends are `static void`; `new_schematic()` returns `window_count`, which
`symbol_in_new_window()` ignores; `symbol_in_new_window()` is itself `void`; and the scheduler ends
with `Tcl_ResetResult(interp)` (`src/scheduler.c:12359`). At the limit, Alt+i is a GUI no-op whose
only trace is one stderr line — visible to a terminal-launched user, invisible to a desktop-launched
one. There are second, equivalent guards after the free-slot scan (`src/xinit.c:2164-2167` and
`:2016-2019`) with the same properties.

## Reproduce

Reproduced headlessly. Fixture: one `lab_pin` instance, the same `.sym` already open in a second
tab, then the Alt+i equivalent, then the same `new_schematic create` call the guard suppresses.
(`--nogui` runs with `tabbed_interface=1`, `has_x=0`.)

```
$ ./src/xschem --nogui --pipe -q --script .../repro0258.tcl
tabbed_interface=1 has_x=0
sym = /home/analog/dev/xschem-claude/xschem_library/devices/lab_pin.sym
start: ntabs=0 cur=.drw file=/home/analog/dev/xschem-claude/untitled-39.sch
after explicit create: ntabs=1 cur=.x1.drw file=/home/analog/dev/xschem-claude/xschem_library/devices/lab_pin.sym
back on parent: ntabs=1 cur=.drw file=/home/analog/dev/xschem-claude/untitled-39.sch
lastsel=1
--- calling symbol_in_new_window ---
--- returned: '.drw' ---
after symbol_in_new_window: ntabs=1 cur=.drw file=/home/analog/dev/xschem-claude/untitled-39.sch
--- calling new_schematic create on the same file directly ---
create_new_tab: /home/analog/dev/xschem-claude/xschem_library/devices/lab_pin.sym already open: .x1.drw
after direct create: ntabs=1 cur=.x1.drw file=/home/analog/dev/xschem-claude/xschem_library/devices/lab_pin.sym
```

Line by line: `symbol_in_new_window` emitted **nothing** and left `ntabs` and the current window
untouched. The identical request made one level lower both *said* something and **switched to
`.x1.drw`** — the tab the user was asking for. That switch is the feedback the pre-check deletes.

Windowed mode (`set ::tabbed_interface 0`), same fixture, plus the nothing-selected arm:

```
tabbed_interface=0
after explicit create: ntabs=1 cur=.x1.drw
--- symbol_in_new_window (windowed mode) ---
after: ntabs=1 cur=.drw file=/home/analog/dev/xschem-claude/untitled-39.sch
--- direct create, same file ---
create_new_window: /home/analog/dev/xschem-claude/xschem_library/devices/lab_pin.sym already open: .x1.drw
after: ntabs=1 cur=.drw file=/home/analog/dev/xschem-claude/untitled-39.sch
--- nothing selected: the OTHER arm ---
load_schematic(): unable to open file: /home/analog/dev/xschem-claude/untitled-39.sym, ffname=...untitled-39.sym
after: ntabs=2 cur=.x2.drw file=/home/analog/dev/xschem-claude/untitled-39.sym
```

Silent again, and the unguarded arm cheerfully opened a window on a `.sym` that does not exist.
Under X the two `already open:` lines are instead an okcancel `tk_messageBox`; that substitution is
read from `src/xinit.c:1980-1987` / `:2127-2133`, not measured.

Slot limit, 19 extra tabs then Alt+i on a target that is **not** open:

```
i=18 ntabs=19 cur=.x19.drw
new_schematic("new_tab"...): no more free slots
i=19 ntabs=19 cur=.x19.drw
...
lastsel=1 ntabs=19
--- symbol_in_new_window at the slot limit (target NOT already open) ---
new_schematic("new_tab"...): no more free slots
after: ntabs=19 cur=.drw file=/home/analog/dev/xschem-claude/untitled-39.sch
```

One stderr line, nothing else, no return value.

## Fix, if it is to be closed

**Do not delete the pre-check.** It exists to stop a second editable view of one symbol file from
existing — two contexts holding the same `.sym`, either of which can save over the other, which is a
real corruption path (and is exactly what the callee does if the user answers *ok* to the
duplicate-open warning). The bug is that the guard discards its own output. Consume it:

```c
    else {
      my_strncpy(filename, abs_sym_path(tcl_hook2(xctx->inst[xctx->sel_array[0].n].name), ""), S(filename));
      if(!check_loaded(filename, win_path)) {
        if(new_process) new_xschem_process(filename, 1);
        else new_schematic("create", NULL, filename, 1);
      } else if(!new_process && win_path[0] &&
                xctx->current_win_path && strcmp(win_path, xctx->current_win_path)) {
        /* already open here: go to it -- that is what the user asked for (issue 0258) */
        new_schematic("switch", win_path, "", 1);
      }
    }
```

`new_schematic("switch", ...)` already routes correctly for both modes — `is_window_context()`
(`src/xinit.c:2583-2591`) sends real toplevels to `switch_window` and tabs to `switch_tab`
(`src/xinit.c:2634-2646`) — so one call covers tabbed, non-tabbed and the detached-window mix.
Three riders:

1. **Windowed mode also needs a raise.** `switch_window()` swaps the context and retitles but never
   touches the X window; the user's monitor does not change. Follow the pattern
   `create_new_window()` uses on its own new toplevel — `tclvareval("focus -force ", window_path[n], NULL)`
   at `src/xinit.c:2098-2102`, preceded by a `raise`/`wm deiconify` on `[winfo toplevel ...]`.
2. **The semaphore is already arranged for this.** Both key sites decrement before calling
   (`src/callback.c:6602-6605`, `:6621-6624`, comment: *"so semaphore for current context wll be
   saved correctly"*), and both `switch_window` (`src/xinit.c:1843`) and `switch_tab`
   (`src/xinit.c:1897`) bail on a nonzero `xctx->semaphore`. The decrement makes the switch legal
   from the key path; from the menu/scheduler path the semaphore is 0 anyway. Do not add the switch
   without checking this, and do not remove the decrement.
3. **`new_process` must not be short-circuited by a local hit.** Alt+Shift+I explicitly asks for a
   separate process; `check_loaded()` only knows this process. Either let `new_process` through the
   guard unconditionally, or keep the guard and *say* why it refused. Silently doing nothing is the
   one option to drop.

If a message is added alongside the switch, note that a plain `statusmsg` on this path is wiped by
the coordinate readout ([0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md));
use the hold variant or `ciw_echo`.

Worth doing in the same pass: give `symbol_in_new_window()` an `int` return (0 = nothing done,
1 = opened, 2 = switched) so the scheduler branch can set a Tcl result instead of
`Tcl_ResetResult(interp)`. That is the **0251** shape and makes the behaviour testable at all — today
a headless test can only infer the outcome from `ntabs` and `current_win_path`, as the transcript
above does.

## Risks

- **`check_loaded()` is an exact `strcmp` on the front cell only** (`src/xinit.c:1822-1824`): it
  compares `ctx->sch[ctx->currsch]`, so a window that has descended below the symbol, or that spells
  the same file by a different path, is not found — the guard misses and a duplicate opens today,
  and would keep doing so after the fix. Making the switch behaviour depend on this predicate does
  not make the predicate worse, but it does make its blind spots more visible to users.
- **Switching context under a key handler.** `switch_tab`/`switch_window` do `save_ctx` /
  `restore_ctx` / `housekeeping_ctx` and reassign the global `xctx`. Returning from `callback()`
  into a *different* `xctx` than it entered with is the failure mode behind
  [0054](0054-descend-return-context-pointer-desync.md). The ground is trodden — Alt+e runs
  `tcleval("open_sub_schematic")` under the identical semaphore save/decrement/restore wrapper
  (`src/callback.c:6459-6465`; note `schematic_in_new_window(0, 1, 0)` is commented out at `:6462`,
  and the C function is reached only from Alt+Shift+E at `:6468-6474`, with `new_process = 1`), and
  `open_sub_schematic` does `xschem new_schematic create` and then descends — but the semaphore
  save/restore around the call at `:6602-6605` must stay exactly as written.
- **Behaviour change for scripts.** `xschem symbol_in_new_window` currently guarantees "never
  changes the current window when the target is open". Anything driving it in a loop would start
  hopping windows. Nothing in `tests/` or `src/*.tcl` calls it (repo-wide grep: only `actions.c`,
  `callback.c`, `scheduler.c`, `xschem.h`, `actions.csv`, `xschem_subcommands.txt` and docs), so the
  exposure is user scripts and action logs.
- **`schematic_in_new_window()` has the same shape and must not be "fixed" by copy-paste**
  (`src/actions.c:2896-2942`, `check_loaded` at `:2936`). It also discards `win_path`, but it passes
  `"noalert"` to `new_schematic` (`:2908`, `:2938`), i.e. it deliberately suppresses the duplicate
  warning, and its `force` argument exists so a caller can demand a second view. Whether the same
  switch-instead-of-nothing rule applies there is a separate decision — see **0256**.
- **No coverage.** Nothing in `tests/headless/` touches `symbol_in_new_window` or the already-open
  branch of `check_loaded`, so any change here lands unguarded until
  `test_symbol_in_new_window_0258.tcl` exists. The transcripts above are directly reusable as its
  body: assert `ntabs` unchanged **and** `current_win_path` moved to the pre-existing window.
