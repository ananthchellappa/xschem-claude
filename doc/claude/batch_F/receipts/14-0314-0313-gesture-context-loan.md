# 14 — issues 0314 and 0313: a gesture cannot borrow the viewer's context

**Both fixed. One root cause, two collaterals, four code changes, ten new checks,
eight sabotages.** Found by hand in the Batch F eyeball round (session 4, item 5),
which is the only reason either was seen: every automated check for item 5 read
the sidebar through a CIW-shaped call, and that is the one route the defect spared.

---

## 1. The root cause, measured

`callback()` (`src/callback.c` ~9098) raises the semaphore for the whole of any
key or button gesture:

```c
  xctx->semaphore++; /* to recognize recursive callback() calls */
```

and `switch_window()` / `switch_tab()` (`src/xinit.c` ~1843 / ~1897) refuse a
context switch outright while it is raised:

```c
  if(xctx->semaphore) return 1; /* some editing operation ongoing. do nothing */
```

So **every viewer context LOAN taken from inside a gesture was refused, 100% of
the time** — and a refused loan answers `{}`, which is indistinguishable from an
empty registry. The identical call typed into the CIW (no callback frame,
semaphore 0) worked. That is why issue 0314 records "three mouse gestures
failed, in the same session, either side of the successful CIW call. It is the
route, not the state."

### The isolation issue 0314 asked for

A wrapper on `wviewer::enter_ctx` **alone**, logging to a file, fresh session,
driven by a real XTEST mouse click on `a1` plus the chord through the canvas
binding's own C entry point:

```
>>> Ctrl-Alt-V ENTRY hit#1 win='' sem=1 cur=.drw
  enter_ctx REFUSED-C(switch_ctx) inwin=1 wp='.x1.drw' prev='.drw' sem=1 ticket='0 {}' caller=wviewer::signal_list
  enter_ctx REFUSED-C(switch_ctx) inwin=1 wp='.x1.drw' prev='.drw' sem=1 ticket='0 {}' caller=wviewer::signal_list_all
<<< ENTRY returned
```

**Refusal C — `switch_ctx` — is the one that fires.** Not "token not in
`windows`" (`inwin=1`), not "`current_win_path` transiently empty"
(`prev='.drw'`). And the controlled experiment, same call, same context, in the
same session:

```
  sem=0 : signal_list_all = 2 entries
  sem=1 : signal_list_all = 0 entries      <- REFUSED-C
  sem=0 : signal_list_all = 2 entries
```

**0313's clearing step is the SAME refusal, one caller over.** Neither of the two
candidates the issue named (6b's last-mile retry, or a tree rebuild) is
responsible: `caller=wviewer::signal_list` in the log above is the browser's own
reader, refused, and `wviewer::browser_reload` then wrote its empty answer over
the model:

```
  TREE(after-a2): top=1 rows=g:/0 sel=g:      <- collapsed to the bare design root
  browsersea(after-a2): 0 entries
  PANE ROWS : 0                              <- was 2 (time, v(anlg))
```

### The rig

`--pipe` with stdin on a FIFO (a live Tcl channel into the running GUI) plus a
16-line XTEST helper for real pointer/keyboard input. Two things it settled that
matter beyond this issue:

* **A generated key event cannot be aimed.** `event generate .drw <Key-f>`
  dispatched *nothing* — Tk routes key events through the focus window, and with
  the viewer holding focus every generated chord was discarded. Real XTEST
  clicks worked; real XTEST *keys* still landed on whichever toplevel the WSLg
  host had made active, and neither `focus -force`, `raise` nor `XSetInputFocus`
  moved it. **Under WSLg, keyboard focus belongs to the Windows host**, so a
  keyboard gesture cannot be aimed at a chosen window from inside X.
* What CAN be driven faithfully is the binding's own command string,
  `xschem callback .drw 2 <x> <y> 118 0 0 12` — the same C entry, the same
  semaphore raise. That is what FD73 uses.

---

## 2. The fix

| # | Where | What |
|---|---|---|
| 1 | `wviewer::enter_ctx` | when `switch_ctx` is refused, the caller **opted in** (`borrow`) and `[xschem get semaphore] == 1` exactly, lower it to 0, retry the switch, and carry the saved value as a **third ticket element** |
| 2 | `wviewer::leave_ctx` | put that semaphore back **unconditionally**, on the context that will receive the frame's decrement |
| 3 | `signal_list` / `signal_list_all` / `browser_reload` | an optional `statusVar` out-var (`ok` \| `refused` \| `unknown`); **both** of the reload's engine reads keep the previous model on a refusal or a throw (0313) |
| 4 | `cosim_db_inventory` / `cosim_scope_for_f1` | the same status, plus a THROW counted as a non-answer; a refused loan no longer falls back to the design window's registry, and mints a new cause `notread` whose sentence never says "run the simulation" (0314) |

**The borrow is opt-in, and that is a review finding, not caution.** `sem == 1`
is necessary but **not sufficient** to mean "a gesture's callback frame": three
other brackets in this tree sit at exactly 1 — `ase::wait` (`src/ase.tcl:646`)
holds it *across a `vwait` that pumps the whole event loop*,
`destroy_all_windows` (`src/xinit.c:2482`) raises it around a `tk_messageBox`
with the comment "to avoid context switches when dialog below is shown", and a
menu-driven `place_symbol` holds it with a placement in flight. Only
`signal_list` and `signal_list_all` — the two read-only readers whose bodies run
no `update`/`after` and always restore — pass `borrow 1`; `in_ctx` (whose body
is caller-supplied and runs at `uplevel #0`) and `readout_refresh` keep the
refusal they have always had. `semaphore >= 2` still refuses for everyone.

**Follow-up, declared:** identifying a gesture frame POSITIVELY would need
`callback.c` to export one (a per-context flag beside the `semaphore++`/`--`
pair, readable as `xschem get ...`). That is the clean form of this gate and it
is C work with its own rebuild and audit; the opt-in door is the narrow version
that is safe to open today. The C side already uses the same lever for the same
job — `int save = xctx->semaphore; xctx->semaphore--; ... = save;` around
`open_sub_schematic` (`callback.c` ~6637).

### What the gesture does now, measured on the real fixture

Real XTEST click on `a1`, then the chord through the C entry:

```
>>> Ctrl-Alt-V ENTRY hit#4 win='' sem=1 cur=.drw
  enter_ctx OK inwin=1 wp='.x1.drw' prev='.drw' sem=1 ticket='1 .drw 1' caller=wviewer::signal_list_all
  TREE(after-a1): top=2 rows=d:0/1 d:1/1 sel=d:1|g:TOP
  PANE CAPTION: showing the digital scope 'TOP' of 'dig.vcd' in the tree, but that
                scope has no signals of its own - open one of its sub-scopes to see any
  CANVAS NOTE : 1 item(s)   ALL-DBS BOX : 1   PANE ROWS : 0
  sem after=0 cur=.drw
```

— item 5 step 6's four PASS conditions, all four, and the semaphore balanced.
`a2` (the 0313 path) keeps `PANE ROWS : 2` with the refusal on caption and
header. `a9` (the control) says nothing digital at all.

And a **genuine** refusal (semaphore forced to 2) now reads:

```
  cosim_db_inventory: 0 entries, status='refused'
  resolver cause : notread
  resolver says  : the waveform viewer's results registry could not be read just now,
                   so 'dig.vcd' could not be confirmed loaded: try the gesture again
                   in a moment (f3)
  browsersigs across a refused reload: 2 -> 2
```

The sentence claims **only what a refusal establishes** (review finding):
`refused` is the union of three unrelated causes — the semaphore said busy, the
window was mid-alloc/teardown, the target window is gone — so an earlier draft's
"(the editor was busy)" and "nothing needs re-running" were the same overreach as
`notloaded`, one step smaller. It does not claim the database IS loaded either;
the refusal is defined as not knowing.

---

## 3. The checks, and the sabotage that makes each one evidence

New: `FD70`, `FD70b`, `FD70c`, `FD70d`, `FD71`, `FD72`, `FD72b`, `FD73`, `FD74`
(`test_wave_sigbrowser_digital.tcl`, Tk/X arm) and `FS51`, `FS51b`-`FS51h`,
`FV10b`, `FV11b`, `FV18` (`test_ase_cosim.tcl`, headless arm).

| sabotage | what it reverts | goes red |
|---|---|---|
| S1 | the loan retry in `enter_ctx` | FD70, FD70d, FD73, FD74 |
| S2 | the semaphore restore in `leave_ctx` | FD70, FD70c, FD73 |
| S2b | that restore gated on `$ok` again (the review's hole) | FD70c |
| S3 | `browser_reload`'s refused-guard | FD72 |
| S3b | the reload's SECOND read unguarded | FD72b |
| S4 | `sem != 1` → `sem < 1` (retry even when busy) | FD71 |
| S4b | the borrow made ambient (every caller borrows) | FD70d, FD71 |
| S5 | `cosim_db_inventory`'s refused return | FS51b/d/e/f, FV10b, FV11b, FV18 |
| S5b | a THROW read as the honest empty again | FS51h |
| S6 | the `notread` arm (refusal minted as `notloaded`) | FS51b/c/d/f, FV10b, FV11b, FV18 |
| S6b | the sentence overclaiming ("editor was busy") | FS51g |
| S7 | **S1+S6 — issue 0314 exactly as shipped** | FD70, FD73, FD74 |
| S8 | `unknown` treated as `refused` | FS50, FS51-unknown, FV32/36/37/41/42/43/45 |

**S1 caught a hollow check, which is the point of running them.** The first cut
of FD73/FD74 kept `fd_drive_on`'s stub over `ase::browser_digital_probe`, so
both routes were handed a pre-decided answer and neither ever read the registry:
with the fix reverted, FD70 went red and FD73/FD74 stayed **green**. They were
rewritten to stub only `ase::cosim_f1` (the design read this file has no
schematic for) and to write a real co-simulation map entry, so the resolver —
step 4's registry read included — runs live on both routes.

`FS51` was also *renamed and re-caused*: it asserted that "a refused viewer
ticket falls back", which is the very behaviour 0314 forbids. It survived the
fix only because its stub had the old one-argument arity, so the status never
reached the caller — a stub can hide this defect by being stale, and FS51b's
comment says so. The same staleness bit a **second** spy that the review found
and the sabotage table did not reach: `bw_spy_on` in
`test_wave_sigbrowser_panes.tcl` wrapped `signal_list` with a one-argument proc,
which the new two-argument call site turns into a throw inside
`browser_refresh`'s `catch`. Measured with the old spy restored: `BW63` FAILS.

## 3b. The adversarial review round

Five independent reviewers (a different agent than the implementer, per the work
order), lenses: semaphore safety, blast radius, the new cause code, whether the
new checks are hollow, and the C side. **Everything in §2 marked "review
finding" came from that round**, and four of the findings changed shipped code:

* the borrow made **opt-in** — `sem == 1` is not proof of a gesture frame
  (`ase::wait`'s `vwait`, the menu-raised `tk_messageBox`, a menu placement);
* `leave_ctx`'s semaphore restore made **unconditional** — gated on `$ok` it
  dropped the value whenever the context restore was refused, and the frame's
  own `xctx->semaphore--` would then take a foreign context to **-1**, i.e. to a
  permanently raised semaphore that refuses every switch it is ever asked for;
* the reload's **second** engine read guarded like the first;
* a **throw** counted as a non-answer, closing the error door onto the
  fall-through;
* plus the sentence trimmed to what a refusal establishes, `FD70`'s tautological
  leg replaced by the context it never asserted, `FD73` given the semaphore and
  context balance on the one route with a real `callback()` frame, and `FD74`
  turned from a negative that could not fail without `FD73` into a **pair** (the
  same gesture against a genuinely unattached VCD must still say `notloaded`).

---

## 3c. One review finding NOT acted on, and why

**The restore leg repaints the design canvas, once per gesture-driven loan.**
`tabbed_interface` defaults to 1 (`src/xschem.tcl:15961`) and `.drw` is slot 0,
so `is_window_context(".drw")` is false and `leave_ctx`'s
`xschem new_schematic switch $prev` goes through `switch_tab`, whose tail is
`if(dr) resetwin(...); if(dr) draw();` (`src/xinit.c` ~1937). The leg going IN
does not draw — the viewer is always a real window, so it takes `switch_window`
— but the leg coming BACK does. Before this fix the whole loan was refused
during a gesture, so this never fired on the gesture path; now it fires on every
one.

It is **not** a correctness defect: the two canvases are separate toplevels, the
design buffer is only read, and the measured gesture is right on all three
surfaces. The available fix is one line — pass `dr 0` on the restore when the
ticket carries a borrowed semaphore (`xschem new_schematic switch $prev {} 0`),
leaving every pre-existing loan byte-identical. It is **not shipped here** for
two reasons: it would need a check of its own (and "a check with no sabotage is
not evidence"), and a repaint is a PIXEL claim, so the honest verifier is the
eyeball this fix was blocking — item 5 step 6 is exactly that gesture. **If the
schematic window visibly flickers when Ctrl-Alt-V is pressed, that is this
finding, and the one-line change above is the fix.**

## 4. Not fixed here

Issue 0312 (the search bar clipping its own controls) is untouched: it needs a
ruling between four candidate fixes, not a chosen one.
