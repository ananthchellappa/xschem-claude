# 1492 — four `xschem` verbs kill the process when there is no display, and `catch` cannot catch it

**STAMP:** `v1 claim=open tree=0eed8a1b stamped=2026-09-20 fix=none open=4 by=B-docs`

**Status: OPEN — filed 2026-09-20** by the stranger-reds batch, from item B's fix round
(`receipts/B-verify.md` §4.4, finding 10 of 14), under batch decision **D6**: a finding
outside the item being worked is written down and filed, never fixed on the way past.
**Class** product crash, reachable from Tcl, uncounted by any suite.
**Related: 0834**, which asks for exactly the contract these four verbs break, measured on
`xschem callback`; **0227** (the same contract broken at `update_statusbar()`); **1483**
(the same contract broken at `xschem globals`, fixed in `2288d437`). See "Why this is not
filed into 0834".

---

## What happens

With no X display, four `xschem` subcommands do not return an error — they end the
process. **MEASURED** by item B's fix round on its own build of the **fixed** tree
(`2fb377de` plus item B's two files), one process per verb, the script being

```tcl
catch {xschem <verb>} r
puts SURVIVED
```

run as `env -u DISPLAY HOME=<scratch> ./src/xschem --nogui --pipe -q --nolog --script <f>`:

| verb | rc | output |
|---|---|---|
| `xschem fill_reset` | 1 | `FATAL: signal 11` — `SURVIVED` never printed |
| `xschem fullscreen` | 1 | `FATAL: signal 11` |
| `xschem copy_hilights` | 1 | `FATAL: signal 11` |
| `xschem compare_schematics` | **139** | died before the handler could print anything |

`catch` cannot catch a SIGSEGV, **so a script that guards itself correctly still dies.**
That is the whole severity of this file: the Tcl idiom the product itself uses for
"this may fail" — `if {[catch {xschem …} g]} …`, as `src/op_annot.tcl` does around
`xschem globals` — is not a defence against these four.

`compare_schematics` is the odd one: rc **139** rather than 1 means it did not even reach
xschem's own SIGSEGV handler, which exits 1 after printing `FATAL: signal 11`.

## It is not new, and it is not headless-only

**MEASURED** by the same round: the same four crash on the **base** binary (before item
B's `xschem globals` guard) **and** with `DISPLAY` set under `--nogui`. So this is
pre-existing, it is not a side effect of 1483's fix, and it is reachable on a developer
desktop — `--nogui` alone is enough, because `--nogui` sets `has_x = 0` while leaving the
`display` global pointing at the connection `xserver_ok()` already closed (issue **1493**).

## Where they land

**MEASURED** by the `completeness` verifier and **recorded here at second hand** — the
fixer reproduced the four crashes but not the backtraces, and says so
(`receipts/B-verify.md` §4.4). The verifier's backtraces put them at:

| verb | crash site as reported |
|---|---|
| `fill_reset` | `free_gc()` → `XFreeGC()` |
| `fullscreen` | `toggle_fullscreen()` → `XQueryTree()` |
| `copy_hilights` | `create_gc()` → `XCreateBitmapFromData()` |
| `compare_schematics` | inside `copy_hilights()` |

⚠ **The last two rows are as the receipt records them and they do not obviously fit.**
`copy_hilights` attributed to `create_gc()` and `compare_schematics` attributed to
`copy_hilights()` may be a transcription slip between two adjacent rows, or may be real —
the verbs do share callees. **Re-take the backtraces before trusting the pairing**; the
per-verb crash *itself* is measured three ways and is not in doubt.

## The branches, READ at `0eed8a1b`

All four already know how to refuse. Each guards `!xctx` and returns a proper Tcl error:

```c
if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
```

and then walks straight into the X call with no `has_x` guard. READ in `src/scheduler.c`:
the `"compare_schematics"` branch, the `"copy_hilights"` branch (which calls
`copy_hilights()`, `src/hilight.c`), the `"fill_reset"` branch (which calls `free_gc()`
then `create_gc()`, both `src/xinit.c`) and the `"fullscreen"` branch (which calls
`toggle_fullscreen()`, `src/xinit.c`).

**The refusal idiom is present and refuses on the wrong condition.** That is the shape of
the fix: one more clause, not a new mechanism. It is the same shape item B applied to
`xschem globals` in `2288d437`, and the same shape `xschem get gc_line_style` and
`resolve_hilight_style_rgb()` already carry.

## Why nothing counts them

**MEASURED, READ at `0eed8a1b`:** no suite drives these four verbs with `has_x == 0`.
The four were found by hand, by a verifier poking at the verb table while measuring
something else. A green T1 — including the first headless ZERO this tree has ever had,
`cases=87 blocks=86 counted_failures=0` with `DISPLAY` unset — says nothing about them.

## Why this is not filed into 0834

0834's title, its measurement and its whole subject are **`xschem callback`**. These are
four different verbs, in three different files, at (as reported) three different Xlib
calls. Filing them into 0834 would bury four verbs inside a file whose name says
"callback", which is the reasoning issue **1490** already gives for not folding itself
into **1484**.

What 0834 *does* own is the **contract**, and it states it in its own §4: *"reject the
verb when `has_x` is false with a proper Tcl error … a clear error is strictly better
than a signal 11 plus an emergency-save directory."* This file is that contract broken at
four more verbs. **If a sweep (step 1 below) shows one cause rather than four, close this
into 0834 then, with the evidence in hand** — do not assume it by filing them as one
number.

## Fix direction

1. **Enumerate before fixing.** Sweep `scheduler.c`'s verb table for branches that reach
   an Xlib call, a GC or a window handle with no `has_x` guard. Four were found by
   accident; nobody has asked how many there are. ⚠ Do **not** sweep with a textual
   `X…(display` pattern — issue **1493** records three passes producing three different
   counts with it, and it cannot see a dereference whose callee does not begin with a
   capital `X`.
2. **Refuse, do not repair.** The minimum is 0834's contract: with `has_x == 0` the verb
   returns a Tcl error and the process is still alive afterwards. Repairing the verbs to
   *work* headlessly is a larger and separate question, and only `fill_reset` plausibly
   has a headless meaning at all.
3. **Give it a counted row.** `tests/headless/test_callback_argc.tcl` is the existing home
   for "a Tcl-reachable `xschem` subcommand must ERROR, never crash" (issue **0076**), it
   is a T1 case, and item B has just added three rows to it for the same class. A row per
   verb — `catch {xschem <verb>}` under `--nogui`, then assert the interpreter is still
   alive — is where this stops being invisible.
4. **Red-first fixture.** The repro at the top is deterministic and takes one process per
   verb. Use it before and after.

## Still open (4)

1. All four verbs are unguarded; nothing is fixed.
2. The rest of the verb table is not enumerated — four verbs were found by hand while
   measuring something else.
3. Nothing counts them: no suite drives any of the four with `has_x == 0`.
4. Whether this is one cause or four is unsettled, and the reported per-verb crash sites
   have a suspect pairing (see the ⚠ above) that nobody has re-taken.

## Evidence

`doc/claude/stranger_reds_batch/receipts/B-verify.md` §4.4 (the measurement, and finding
10 of the 14 the two verifiers returned); `receipts/B-impl.md` §5 (the surrounding class
argument); `doc/claude/stranger_reds_batch/DECISIONS.md` **D6**. Source READ at
`0eed8a1b`: the four branches in `src/scheduler.c`, `free_gc()` / `create_gc()` /
`toggle_fullscreen()` in `src/xinit.c`, `copy_hilights()` in `src/hilight.c`.
