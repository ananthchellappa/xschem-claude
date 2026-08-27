# 0849 — the "context is left on the viewer" rule was never implemented; 0848 removed the accident that hid it

Status: **OPEN — a real defect, filed not fixed.** Found 2026-08-26 as fallout from
issue 0848. Owner: whoever owns the signal-browser item (this is not the waveform
placement work that surfaced it).

## The standing red

`tests/headless/test_wave_sigbrowser_i12.tcl`:

```
FAIL: BX42 (DECLARED) the context is LEFT ON THE VIEWER, the raised window -> {0} (exp {1})
RESULT: 1 FAILED (125 passed)
```

**Baselined.** `git show HEAD~1` of `xinit.c` / `callback.c` / `wave_viewer.tcl`,
rebuilt: `ALL PASS (126 checks)`. With 0848's fix in: 1 FAILED. So this red arrived with
0848 and is not pre-existing — but 0848 is not what broke it.

## It was green for the wrong reason

The check asserts a contract the test states explicitly, and even anticipates the
failure mode:

```tcl
# THE DECLARED CONTEXT RULE (item 11's mirror): the viewer was raised, so
# the context is left there. Asserted, not accidental.
```

It was accidental. Measured with a context probe at three points in one run:

```
CTXPROBE open-REUSE            ctx=.x1.drw  top=.x1     <- the opener leaves it on the viewer
CTXPROBE end-of-show_in_browser ctx=.drw                 <- and it is back on the design window
```

`ase::show_in_browser_for_current` ends with the context on the **design** window. What
made BX42 pass before 0848 was a *defect*: `new_schematic("switch_no_tcl_ctx", ...)`
silently no-opped for the main window under the tabbed interface, so the redraw-only
switch an Expose triggers during the call never restored — and the context was left on
the viewer because the code failed to bring it back.

Fixing that no-op (0848, which is what stopped the user's schematic canvas keeping the
waveform viewer's pixels) removed the accident and exposed that the declared rule has no
implementation on this path.

## Two things tried and reverted, deliberately

1. **Asserting the rule at the end of `ase::show_in_browser_for_current`** — reverted: it
   reds `BX10`, which forbids that proc from re-implementing an opener
   (`regexp {load_new_window|window_for \$key}` must be 0). The architecture says
   `wviewer::open` is the only opener, and that rule is right.
2. **Switching the context in `wviewer::open`'s REUSE arm** (the arm that raises an
   already-open viewer and, unlike the FRESH arm, never moved the context) — reverted:
   it makes the opener match its own documented behaviour, but it does **not** fix BX42,
   because something later in the browser flow puts the context back on the design
   window. Shipping an unproven behaviour change into another feature to chase a red is
   how the next person inherits a mystery.

## What has to be decided, and by whom

Either the rule is real and `show_in_browser_for_current` must end on the viewer — in
which case the flow between `wviewer::open` and its return needs the owner to say which
step is moving the context back and why — or the rule is not real and BX42 should be
retired with an explanation. **Not to be settled by rewriting the check to match whatever
the code currently does**: the test states a contract, and the code failing a contract is
the normal case, not evidence the contract is wrong.

## Why it is filed rather than carried

CLAUDE.md: a standing red is a defect, and never a count carried forward. This one is
named, dated, baselined against HEAD~1, attributed to the exact mechanism, and has its
two dead ends written down so nobody re-walks them.
