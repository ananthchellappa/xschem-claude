# 1493 — `xserver_ok()` closes the display without nulling the global, so a missed guard reads freed memory instead of faulting

**STAMP:** `v1 claim=open tree=0eed8a1b stamped=2026-09-20 fix=untried open=3 by=B-docs`

**Status: OPEN — filed 2026-09-20** by the stranger-reds batch, from item B's fix round
(`receipts/B-verify.md` §4.5, finding 11 of 14) and its implement round
(`receipts/B-impl.md` §1.2 and §5), under batch decision **D6**.
**Class** product defect — a dangling global that converts a loud failure into a silent
wrong answer. Both receipts call it **the single highest-value follow-up in this area**.
**Related: 0227**, which recommends this one line in a parenthetical and says in its own
words that it is *"worth fixing separately"*; **1483**, the defect this one hid;
**1492**, four more verbs of the same family.

---

## The code, READ at `0eed8a1b`

`src/draw.c`, `xserver_ok()`:

```c
int xserver_ok(void)
{
  int has_x = 1;
  if(!getenv("DISPLAY") || !getenv("DISPLAY")[0]) has_x = 0;
  else {
    display = XOpenDisplay(NULL);
    if(!display) {
      has_x=0;
      ...
    } else XCloseDisplay(display);
  }
  return has_x;
}
```

`display` is the file-scope global (`Display *display = NULL;` in `src/globals.c`,
declared `extern` in `src/xschem.h`). It is assigned in exactly three places: here, and
twice in `src/xinit.c` as `Tk_Display(mainwindow)` **inside `if(has_x)`**. `main.c` runs
`has_x = xserver_ok();` before options are processed, and `--nogui` (`src/options.c`)
then sets `has_x = 0` **without touching `display`**.

**So the probe connection is opened, closed, and the global is left pointing at it.**

## Why that is the interesting half

There are two ways for `has_x` to be 0, and they leave the global in **two different
states** — which means the two arms of every test exercise different pointer states:

| condition | `display` | a missed `has_x` guard then… |
|---|---|---|
| `DISPLAY` unset | `NULL` | **faults**, loudly, every time |
| `DISPLAY` set and `--nogui` given | a pointer `XCloseDisplay()`d already | **reads freed memory**, usually without faulting |

**MEASURED** (`receipts/B-impl.md` §1.2), gdb on the unfixed tree `1f3f5287`, `--nogui`,
`DISPLAY=:151`, breakpoints on the `XCloseDisplay()` line and on the `xschem globals`
statement that then dereferenced it:

```
in xserver_ok, display=0x5555557b2160
at globals call, display=0x5555557b2160, has_x=0
GOT: XMaxRequestSize=4
GOT: XExtendedMaxRequestSize=4194303
```

Same pointer, after `XCloseDisplay()`. **And the number is fabricated**: the same build
against a live display reports `XMaxRequestSize=65535`.

## This is how issue 1483 stayed invisible

That is not an analogy; it is the recorded history of a defect fixed three days ago.
One statement in `xschem globals` dereferenced `display` with no guard. On **every
developer desktop** it printed `XMaxRequestSize=4` out of freed memory and nobody ever
looked twice; on **every headless box** the same statement killed the process, taking
four T1 suites with it. **One statement, two defects, and the harmless-looking one is
what hid the fatal one** (`receipts/B-impl.md` §1.2). Issue **1483** carries the four
suites; `2288d437` carries the guard.

A sharper consequence, **MEASURED by the `completeness` verifier and recorded here at
second hand** (`receipts/B-verify.md` §4.5): on the `--nogui`-with-`DISPLAY` arm,
`test_undo_selection` dies inside libxcb with

```
Assertion !xcb_xlib_extra_reply_data_left failed
```

rather than segfaulting — the freed connection driven far enough to corrupt libxcb's own
state. So the silent mode is not merely "reads a wrong number"; it is undefined
behaviour with a second failure shape of its own.

## The fix, and why it is not a one-line fix

The line itself is one line, and **0227 already prescribes it**: add `display = NULL;`
immediately after the `XCloseDisplay(display)` in `xserver_ok()`. That turns the
dangling case into the NULL case, so a guard missed anywhere faults loudly and
consistently instead of reading freed memory.

**Its value is exactly its risk.** It would make a `DISPLAY`-set arm fail wherever a
headless one does, permanently — which is precisely the property that would have caught
1483 on the first developer who ran `xschem globals`. It would also convert an unknown
number of today's quiet paths into crashes **on the developer's own desktop**, at once.
Both item B rounds declined it for that reason and said so: it is hardening for *other*
call sites, and it belongs with a sweep.

### ⚠ How big the sweep is, is itself unmeasured — and do not believe a count

Three passes over the same files produced **three different answers** with the same kind
of textual pattern (`receipts/B-verify.md` §4.1): 152 / 69 / 13 for `draw.c` / `xinit.c` /
`callback.c` in the implement receipt, 172 / 70 / 7 from one verifier, 182 / 70 / 13 from
the fixer using `/usr/bin/grep -rEc 'X[A-Za-z_]+ *\( *display'`. **Do not quote any of
them forward.** Worse, the pattern is structurally blind: it cannot see a `display`
dereference whose callee does not begin with a capital `X`, and there are **8** such —
`cairo_xlib_surface_create` ×7 and `XGetXCBConnection` ×1 — which the fixer enumerated by
hand.

**The scope being unknown is the finding, not a gap in this file.** Step 1 below is what
closes it, and it must enumerate by identity rather than by that pattern.

## Fix direction

1. **Sweep first, by identity.** Enumerate every dereference of the `display` global and
   classify each as guarded, unguarded-but-unreachable-headless, or unguarded-and-
   reachable. The widened pattern must include the non-`X` callees above. Item B checked
   the three Tcl-reachable ones outside the drawing core by hand and found
   `xschem get gc_line_style` and `resolve_hilight_style_rgb()` correctly guarded; no
   claim was made about the rest, and none should be.
2. **Then land the line**, in `xserver_ok()`.
3. **Expect new reds and read them as findings.** A suite that starts crashing on the
   `DISPLAY`-set arm after this change has been reading freed memory all along. That is
   the change working. Budget for it: do not land this inside a batch capped at one fix
   round, which is why item B did not.
4. **Pin the property.** A row that asserts the two arms agree — that whatever `has_x == 0`
   reports with `DISPLAY` set is what it reports with `DISPLAY` unset — is what stops the
   class returning. Item B's three rows in `tests/headless/test_callback_argc.tcl` are the
   first instance of that shape and the natural home for more.

## Still open (3)

1. The line is not applied; `display` is still left dangling by `xserver_ok()`.
2. The sweep is not done, and **its size is unmeasured** — three conflicting counts and a
   pattern that cannot see eight known sites.
3. No test row asserts that the two `has_x == 0` arms agree, so nothing would catch the
   next statement of this shape before a headless box does.

## Evidence

`doc/claude/stranger_reds_batch/receipts/B-impl.md` §1.2 (the gdb measurement, the
fabricated `4` against the real `65535`) and §5 (why it was not taken);
`receipts/B-verify.md` §4.1 (the count that does not reproduce) and §4.5 (the libxcb
assertion, finding 11); `DECISIONS.md` **D6**. Issue **0227** carries the original
one-line recommendation. Source READ at `0eed8a1b`: `xserver_ok()` in `src/draw.c`, the
`display` global in `src/globals.c` and `src/xschem.h`, `has_x = xserver_ok();` in
`src/main.c`, the `--nogui` assignment in `src/options.c`.
