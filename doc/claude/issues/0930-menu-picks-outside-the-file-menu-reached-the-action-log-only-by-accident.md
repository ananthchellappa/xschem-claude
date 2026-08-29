# 0930 — menu picks outside the File menu reached the action log only by accident

**Status:** **FIXED 2026-08-29.** Reported by the user the same day, on a
standing requirement they first stated three months ago.

**Spec:** [action_logging.md](../specs/action_logging.md) §2 — *"Every user
action is logged."*

---

## 1. What the user reported

> *"I just now did ASE-L > Tools > Waveform viewer. It launched a window which
> disappeared soon. But, why was the action of opening that tool not logged to
> CIW and logfile? We want to log everything! I said that 3 months ago!"*

Their log confirms the asymmetry precisely: `wviewer::close` appears as a
replayable line, the matching **open does not appear at all**.

## 2. The measurement

`menu_action_logged` (`src/action_registry.tcl`) is a correct per-entry wrapper
and has been there all along. It is attached in **exactly one place** —
`build_menu_from_table`, which is called for the single menu key `file`.

| | logged |
|---|---|
| main-window menu entries carrying a command | **6 of 238** |
| ASE-L menubar (24 live entries) | 4 replayable, 4 comment-only, **15 silent** |
| `src/calculator.tcl` | **0** `log_action` sites in 2256 lines |

The other 232 main-window entries log only **by accident** — when the command
happens to be an `xschem` verb whose C core self-logs. `ase::echo` is reached 68
times in `ase_window.tcl` and emits `#= ` **comments**, which are not replayable
actions. `wviewer::open` has no log call on any of its four call sites (Tools
menu, the `~` strip button, Direct Plot, state restore), while the viewer's other
controls log because someone hand-added `wviewer::log_action` to 24 individual
procs.

**This is an unclosed spec gap, not a regression.** The spec's three-layer table
names bound keys, the canvas right-click menu and drag gestures. It never names
**Tk menu items** in the ASE-L / viewer / calculator windows as a layer at all,
and §5 defers "non-File menus" explicitly. Hand-attaching a wrapper per entry is
what produced the state above.

## 3. The fix — log by construction

An interceptor on the `menu` command (`src/action_registry.tcl`). Every menu
widget it creates has its widget command renamed aside and replaced by an alias
onto `::menu_invoke_logged`, which records the picked entry's own `-command`.

It catches a real pick because Tk's `::tk::MenuInvoke` ends in
`uplevel #0 [list $w invoke active]` (`/usr/share/tcltk/tk8.6/menu.tcl:652-665`,
read on this machine) — so mouse picks, keyboard traversal and a test's
`$m invoke N` all arrive at the same place.

**Why `invoke` and not a `-command` rewrite.** Rewriting the entry's `-command`
at build time costs **19 exact-equality test rows across 11 files** that read the
string back with `entrycget -command` — including `test_ase_window` W1m, which
pins the Waveform Viewer entry's command verbatim. Wrapping the widget command
leaves every `-command` byte-identical, and W1m still passes untouched.

Dedup is `menu_action_logged`'s own discipline — reset the emitted flag, run the
pick, write the command only if nothing underneath already self-logged it.
Measured on three entries in one process:

| entry | lines written |
|---|---|
| `-command [list menu_action_logged {puts {hi-wrapped}}]` | 1 |
| `-command {xschem zoom_full}` (C core self-logs) | 1 |
| `-command {puts {hi-plain}}` (nothing self-logs) | 1 |

A pick that **raises** is recorded as `# failed: <cmd>`, so the log file stays
source-able — the same rule as CIW-typed commands. Cascades and separators carry
no command and are recorded as nothing; they are navigation, not actions.
`::menu_action_log 0` disables the whole thing.

## 4. ⚠ A DEFECT THIS FIX INTRODUCED AND THEN GUARDED

The first version installed the interceptor with a bare `rename ::menu`. Under
`--nogui` **there is no Tk**, so `::menu` does not exist and the rename raised at
source time — which does not skip the feature, it **aborts startup**:

```
can't rename "::menu": command doesn't exist
xschem: STARTUP ABORTED: ... action_registry.tcl ... See issue 0663.
```

That is every headless run of the binary, including the whole regression suite.
It is guarded now (`[info commands ::menu] ne {}`).

Worth recording *how it was nearly missed*: the suite was re-run under `--nogui`
and its output contained no `FAIL` lines, which was read as a pass. There were no
FAIL lines because **the script never ran at all**. Silence is not a pass — the
same lesson `run_regression.tcl`'s banner rule exists to enforce, met from the
other side.

## 5. The second half of the report — the vanishing window

`ase::ui::open_viewer` was, in its entirety, `catch {wviewer::open $key}`. One
line that discarded both halves of what the user needed: no log line, and **any
raise inside a 288-line proc that builds a real toplevel silently swallowed** —
which is exactly the shape of "it launched a window which disappeared soon". It
now reports the failure through `ase::echo` and returns 0/1. Still caught: a
viewer failure must not take the ASE-L window down with it.

**The vanish itself did not reproduce** — ~50 fresh opens across 20 processes,
80 raise/reuse cycles, two levels descended, zero vanishes, and the bare `catch`
was measured to be swallowing nothing. That ran on Xvfb; the user is on VcXsrv
over TCP. The only mechanism in the path that can unmap a visible window is the
re-open arm's `raise_activate_toplevel`, which does `wm withdraw` + `wm
deiconify`; this tree already carries an evidence file recording VcXsrv
21.1.16.1 `-multiwindow` failing that ~1-in-3 while X still reports the window
viewable. Two agents disagreed on the supporting argument, so **no cause is
claimed**. With the pick now logged, the log itself says which arm ran.

## 6. Acceptance

* `test_ase_window` **W1m2** — the interceptor is installed **and** a real ASE-L
  menubar pick routes through it carrying the entry's own command. The
  installed-ness term is first so the row cannot pass vacuously. It drives a
  throwaway entry rather than `Waveform Viewer`, because picking the real one
  would open the viewer and disturb every row below; W1m already pins that
  entry's command verbatim, so command-string × mechanism is the whole claim.
* `test_ase_window` **W1m** and the other 18 `entrycget -command` rows are
  unchanged and still pass — the evidence that this did not rewrite commands.

## 7. Not fixed

* **Menubar clones.** A Tk menubar clone is created by C `CloneMenu`, not by the
  `menu` command, so it is unwrapped. On this Tk the menubar posts the original
  widget path and picks are caught; a platform that clones would lose the line,
  not the action.
* **Checkbutton replay fidelity.** Tk toggles the `-variable` before running
  `-command`, so a logged checkbutton command replays against whatever the
  variable holds at replay time. Honest, and better than the silence it replaces.
* **`xschem raw read` returns 0 when it finds nothing** (from 0929 §5) — still
  open.
