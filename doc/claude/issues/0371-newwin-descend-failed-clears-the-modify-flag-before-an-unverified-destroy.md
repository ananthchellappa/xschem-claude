# 0371 — `newwin_descend_failed` clears the modify flag before an UNVERIFIED destroy

Status: **FILED (measured, not fixed)**
Found by: D4 Verify-C (adversary), 2026-08-10; scoped by the D4 write-up agent.
Class: descend census / teardown. **This is the one defect NEWLY INTRODUCED by D4.**
Root causes: 0372 (`destroy_window` no-op without X), 0373 (`destroy_tab` refuses silently).
Siblings: 0256, 0244/0267/0270 (the "must not lie about the modify flag" family).

## Summary

`newwin_descend_failed` (`src/xschem.tcl:5688`), added by D4 to tear down a new window whose
descend was refused, runs

```tcl
  catch { xschem new_schematic switch $new_win }
  xschem set_modify 0
  catch { xschem new_schematic destroy $new_win }
```

The `set_modify 0` is unconditional and the destroy is **unchecked**. Whenever the destroy
does not take, the survivor claims *unmodified* while holding the source's restored unsaved
edits — the exact shape the ratified rule "an aborted gesture must not lie about the modify
flag" (0244/0267/0270) forbids.

## Measured

`--nogui`, `set ::tabbed_interface 0`, source window carries a real unsaved edit:

```
P14| tabbed_interface=0
P14| source modified=1 nwin=1
P14| open_sub_schematic(l1) -> 0  nwin=2 ctx=.drw
P14|   win .drw -> lp.sch
P14|   win .x1.drw -> lp.sch
P14| source(.drw) modified=1
P14|   SURVIVOR .x1.drw schname=lp.sch modified=0 instances=2
```

The refusal is reported correctly (`-> 0`) and the **source is fine** (`modified=1`, edits
intact). The lie is on the orphan `.x1.drw`: `modified=0` while holding 2 instances including
the moved one.

## Scope — narrow, and this is why D4 shipped

Re-measured by the write-up agent across all three configurations:

| configuration | result |
|---|---|
| `--nogui`, `tabbed_interface=1` (**the `--nogui` default**) | `nwin=1`, source `modified=1` — **correct** |
| real X via `GUI_GATE=0 xvfb-run -a`, `tabbed_interface=0` | `nwin=1`, source `modified=1` — **correct** |
| `--nogui`, `tabbed_interface=0` (explicit opt-out) | **defect as above** |

So it is unreachable for any interactive user and unreachable in the default headless mode.
It requires a script that explicitly sets `tabbed_interface 0` *and* runs without X.

## Cause

Not the Tcl. `destroy_window()` is a silent no-op when there is no X (0372), and
`destroy_tab()` refuses from outside the tab while `new_schematic()` returns `window_count`
either way (0373) — so `catch {...}` cannot distinguish "closed" from "declined". D4's own
`newwin_descend_failed` comment records why it must switch **into** the doomed tab first;
what it does not do is check that the close happened.

## Suggested fix

Verify the destroy, and only then drop the flag — or better, do not drop it at all and let a
verified destroy take the context with it:

```tcl
  set n_before [llength [xschem windows]]
  catch { xschem new_schematic switch $new_win }
  xschem set_modify 0
  catch { xschem new_schematic destroy $new_win }
  if {[llength [xschem windows]] >= $n_before} {
    # destroy declined (0372/0373): do NOT leave a survivor claiming unmodified
    ...restore the flag / report...
  }
```

The count test is the same honest signal `newwin_open_ok` already uses. Fixing 0372 removes
the headless half outright and is the smaller change.

## Coverage

Thin, and Verify-B said so. Sabotage **S8** (`newwin_descend_failed` → `return 1`) turned only
**R23** red; rows R22 and R26 were predicted to cover this proc but both select a lone wire,
which refuses *earlier* at the target-derivation step and never reaches the teardown. One
covering row for a proc whose failure mode is a leaked window plus a bogus modify flag is not
enough — a row in the `tabbed_interface=0` configuration is needed.
