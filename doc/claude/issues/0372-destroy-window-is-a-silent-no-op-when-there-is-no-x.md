# 0372 — `destroy_window()` is a SILENT no-op when there is no X

Status: **FILED (measured, not fixed)**
Found by: D4 Implement agent (note A), 2026-08-10; confirmed by the write-up agent.
Class: window/tab teardown. **Same class as 0363** (`xschem exit` non-tabbed arm has no
`has_x` guard). Directly causes 0371.

## Summary

`src/xinit.c:2336` gates the entire teardown on `tkwin`:

```c
      if(tkwin && n >= 1 && n < MAX_NEW_WINDOWS) {
        ...
        log_action("xschem new_schematic destroy %s", win_path);
        tclvareval("delete_ctx ", win_path, NULL);
        xctx = save_xctx[n];
        ... delete_schematic_data ... save_xctx[n] = NULL ... window_count-- ...
      }
```

`tkwin` is only ever assigned inside an `if(has_x)` block, so with `has_x == 0` the whole
body — `delete_schematic_data()`, `save_xctx[n] = NULL`, `window_count--` — is skipped while
the function still **returns normally**. The caller cannot tell: `new_schematic()` returns
`window_count` either way (0373).

The `n == -1` case two lines above *does* `dbg(0)` about a window it cannot find; the silent
path is the one where the window was found and simply not destroyed.

## Why it has stayed invisible

`--nogui` defaults to `tabbed_interface=1` and takes `destroy_tab()` instead, which works.
Only a script that explicitly sets `tabbed_interface 0` while running headless reaches this
arm. Measured via `newwin_descend_failed` in that configuration (0371):

```
P14| open_sub_schematic(l1) -> 0  nwin=2      <- destroy silently declined
P14|   SURVIVOR .x1.drw schname=lp.sch modified=0 instances=2
```

The same script under `GUI_GATE=0 xvfb-run -a`: `nwin=1`, the destroy takes.

Repro probes: `scratch_D4/impl/destroy_probe.tcl`, `destroy2.tcl` (throwaway; recreate from
the transcript above).

## Suggested fix

The teardown is not inherently graphical — `delete_schematic_data()`, the `save_xctx` slot and
`window_count` are all context bookkeeping. Split the condition: keep the Tk-specific parts
(`toplevel` destruction, `delete_ctx`) under `has_x`, and run the context bookkeeping
unconditionally. At minimum, `dbg(0)` on the declined path so it is not silent, and let
`new_schematic()` report failure (0373) so `catch {}` callers can react.

Cross-check 0363 while here — it is the same missing `has_x` reasoning in `xschem exit`.

## Coverage

None. No suite closes a window with `tabbed_interface=0` headless.
