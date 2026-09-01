# 0846 — `test_altf5_ciw` fails its NEGATIVE leg: un-bound Alt-F5 still raises the CIW

Status: **OPEN — filed, not fixed.** Found 2026-08-26 while running the CIW suites
as neighbours of the CIW-font change. **Pre-existing**, and confirmed so.

## Measured

```
FAIL - un-bound Alt-F5 no longer raises CIW
RESULT: FAIL
```

Dev display `:99`, Xvfb 1920x1080x24, openbox 3.6.1 live, `--pipe -q --logdir`.

**Baselined against HEAD**: `git show HEAD:src/ciw.tcl`, `HEAD:src/xschem.tcl` and
`HEAD:src/cadence_style_rc` restored into the tree gave the **identical single
failure**, so nothing in the CIW-font work (`ciw_font` / `ciw_set_font_size`, the
named `CiwFont`) causes it. Files restored afterwards.

## What the leg asserts

`tests/headless/test_altf5_ciw.tcl` checks the default `Alt-F5 → tools.raise_ciw`
binding is **user-overridable**: after `xschem unbind`, pressing Alt-F5 must leave
the CIW where it was. It does not — the CIW comes up anyway.

## Two candidate causes, neither eliminated

1. **A real unbind defect** — `xschem unbind` not actually clearing
   `tools.raise_ciw`, so the canvas keypress still dispatches.
2. **The test's own settle window.** The file carries a long comment about
   `wm state` being asynchronous: the negative leg deliberately polls for the
   full ~5 s window so a *leaked* raise cannot hide behind the 0–2920 ms lag
   measured on `:0`. If the CIW was already `normal` when the leg started, that
   same window would report a raise that never happened. The suite's own note
   says the false-green it hardens against was **never reproduced**, which is
   exactly the shape of a leg that can also false-RED.

Distinguishing them costs one measurement: record `wm state .ciw` immediately
before the negative leg's keypress. If it is already `normal`, the leg is testing
nothing and (2) is the answer.

## Why it is filed rather than carried

CLAUDE.md: a standing red is a defect, and the one place a real regression hides
in plain sight. This one is named, dated, baselined and attributed — not counted
forward as "a known 1 FAIL".

## Neighbours, all green in the same batch

`test_ciw` (50), `test_ciw_actionlog_output` (25), `test_ciw_autocomplete`,
`test_ciw_interactive_load` (12), `test_ciw_puts_capture`,
`test_ase_log_seam_0207` (48). Note the last three print `PASS: <name>` rather
than a `RESULT:` banner — a `grep -E '^RESULT'` reader scores them as *silent*,
which is how two of them briefly looked dead in this batch.
