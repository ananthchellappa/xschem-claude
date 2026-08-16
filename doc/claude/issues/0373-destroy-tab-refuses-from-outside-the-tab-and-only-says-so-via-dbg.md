# 0373 — `destroy_tab()` refuses from outside the tab and only says so via `dbg(0)`

Status: **FILED (measured, not fixed)**
Found by: D4 Implement agent (note B), 2026-08-10.
Class: window/tab teardown / silent refusal. Sibling of 0372; together they cause 0371.
Thematically identical to the whole D4 batch (0249/0251/0254/0256).

## Summary

`destroy_tab()` refuses to close a tab the caller is not currently inside, and announces it
only on stderr:

```
new_schematic("destroy_tab", .x1.drw): must be in this tab to destroy
```

`new_schematic()` returns `window_count` **either way**, so a Tcl caller cannot distinguish a
refused close from a completed one. `catch { xschem new_schematic destroy $w }` succeeds in
both cases.

This is the D4 defect class exactly — a refusal that is indistinguishable from success at the
caller — in the teardown layer rather than the descend layer, and it was found *because* D4's
`newwin_descend_failed` had to work around it: that proc switches **into** the doomed tab
before closing it precisely because the refusal is otherwise invisible.

## Why it matters now

D4 added a caller that depends on the close actually happening. With the refusal invisible,
`newwin_descend_failed` leaves a survivor window whose modify flag has already been cleared
(0371). The workaround (switch in first) is correct but fragile: nothing enforces it, and any
future caller that forgets will hit the same silent decline.

## Suggested fix

Give `new_schematic()` a real result for the destroy verbs — return `-1` (or leave
`window_count` but set a reason the way D4's `descend_error` does) when the close is declined,
and have the Tcl callers check it. Note 0256's decision **D9** deliberately deferred exactly
this C plumbing (`src/xinit.c:1999/2150`, `src/actions.c:2902-2917`) as too large for that
item and closed the immediate hole in Tcl instead; this issue is where that debt is recorded.

A `statusmsg_hold()` alongside the `dbg(0)` would also match the reporting discipline D4
established, since a desktop-launched user never sees stderr.

## Coverage

None.
