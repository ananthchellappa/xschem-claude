# 0227 — any headless `xschem callback` segfaults: `update_statusbar()` calls `XGetKeyboardControl()` on a NULL / already-closed `Display*`

**STAMP:** `v1 claim=open tree=0eed8a1b stamped=2026-09-20 fix=untried open=3 by=B-docs`

Status: **OPEN**.
**PRE-EXISTING — not caused by merge 4.** Merge `15c600c6` *did* touch `src/callback.c`
(`git diff --stat 2f238fdc 15c600c6 -- src/callback.c` → `308 insertions(+), 36 deletions(-)`),
so this was checked against a binary built at the pre-merge tip rather than assumed; the
proof is in "Not merge 4" below. `git log -L` dates the offending call to `eadfe651`
(2025-03-23, upstream: "further move statusbar code from callback() to update_statusbar()").
Found by: running `tests/headless/test_keybind_snap_grid.tcl` true-headless during the
merge-4 audit, i.e. exactly the invocation `CLAUDE.md` calls the trustworthy signal.
Severity: medium — no user-visible impact under X; it silently truncates any `--nogui`
script that fires a canvas event.
Related: `doc/claude/issues/0228-*.md` (the other harness-shaped finding of the same audit).

## Symptom

```
$ env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_keybind_snap_grid.tcl
ok:   KB1 plain startup binds none of the snap/grid/highlight family (bound: )
ok:   KB3a all five action ids are registered (bindable) (unknown: )
rename dir (null) to /tmp/xschem_emergencysave_nand2_gfbacgggce failed

FATAL: signal 11
while editing: nand2
EXIT=1
```

Deterministic, 3/3. **This is not teardown after success.** Two of the file's six checks
pass, **zero fail**, and it dies inside the `KB3b` block *before that check reports* — so
KB3b, KB2, KB4 and KB5 never run and no `RESULT:` line is ever printed. Exit status is 1,
not 139, because the SIGSEGV handler exits normally.

Under X the same file is fine:

```
$ SUITE_TIMEOUT=400 ./doc/claude/signal_browser_2pane_batch/xarm.sh one test_keybind_snap_grid.tcl
ok:   KB3b bind 'g'->snap_half then firing g halves cadsnap (cadsnap 10 -> 5)
...
RESULT: ALL PASS (6 checks)
```

### The reported framing was wrong in four ways

Recorded because each was checked and each is a different bug than the one filed:

1. **It is not about `--nogui`.** `has_x == 0` is the trigger. Without the flag but with no
   display — `env -u DISPLAY ./src/xschem --pipe -q --nolog --script …` — the same
   `FATAL: signal 11` appears, because `xserver_ok()` (`src/draw.c:65`) returns 0 on an
   empty `DISPLAY` and leaves `display` NULL.
2. **It is not about `DISPLAY` being unset.** `DISPLAY=:0 ./src/xschem --nogui …` crashes
   too, by a *second* mechanism (see "Root cause").
3. **`while editing: nand2` does not implicate the `nand2` fixture.** That is only whatever
   schematic the emergency-save handler found open. The minimal repro below loads nothing
   and prints `while editing: untitled-11`.
4. **It is not in a keybinding, grid or snap path, and not KeyPress-specific.** The minimal
   repro binds nothing; a Motion event (`xschem callback .drw 6 100 100 0 0 0 0`) crashes
   identically. `update_statusbar()` runs at the *top* of `callback()`, before any dispatch.

`test_keybind_snap_grid.tcl` is the messenger, not the site.

## Root cause

`callback()` calls `update_statusbar()` **unconditionally**:

```
$ grep -n 'update_statusbar' src/*.c src/*.h
src/callback.c:8690:static void update_statusbar(int persistent_command, int wire_draw_active)
src/callback.c:8896:  update_statusbar(persistent_command, wire_draw_active);
```

and `update_statusbar()` dereferences the X display with no guard:

```
$ grep -rn 'XGetKeyboardControl' src/
src/callback.c:8721:  XGetKeyboardControl(display, &kbdstate);
```

gdb, on the failing run (the binary carries no debug info, hence no line numbers in the
trace):

```
Thread 1 "xschem" received signal SIGSEGV, Segmentation fault.
0x00007ffff7c670a2 in XGetKeyboardControl () from /lib/x86_64-linux-gnu/libX11.so.6
#1  0x000055555555fb40 in update_statusbar ()
#2  0x0000555555571c90 in callback ()
```

Breaking on the function and reading the first argument confirms the pointer:

```
Breakpoint 1, XGetKeyboardControl ()
$1 = 0x0
```

**Where the NULL comes from.** `display` is `NULL` at `src/globals.c:29`
(`Display *display = NULL;`) and is only ever assigned inside `xserver_ok()`
(`src/draw.c:63`). `main.c:94` runs `has_x = xserver_ok();` *before* `process_options`, and
`--nogui` (`src/options.c:194-196`) sets `has_x = 0` without touching `display`.

**Where the dangling pointer comes from** — the sharper of the two, and a latent trap for
any future `!has_x` code: `xserver_ok()` opens and immediately closes the display without
nulling the global (`src/draw.c:68-75`):

```c
    display = XOpenDisplay(NULL);
    if(!display) {
      has_x=0;
      …
    } else XCloseDisplay(display);
```

So with `DISPLAY` set *and* `--nogui` given, `has_x` is 0 while `display` points at freed
memory. Same crash, worse failure mode.

The file already knows the idiom — there are roughly twenty `if(has_x)` guards in it, e.g.
`src/callback.c:350` (`if(has_x) statusmsg(" ", 1);`), `:579`
(`if(has_x && tclgetintvar("snap_cursor")) draw_snap_cursor(1);`), `:3359`
(`if(!has_x) return;`). The statusbar path is the one that never got one, and every widget
it touches (`.statusbar.8`, `.statusbar.10`, …) is Tk-only anyway.

## Why it was invisible

**`tests/headless/` is a directory name, not a promise.** `full_audit.sh` passes `--nogui`
only for the six names in `nogui_tests` (`tests/headless/full_audit.sh:69`, consumed at
`:178`); everything else takes the default arm at `:182` —
`--pipe -q --nolog --script` — under a real `:0` or `xvfb-run`, where `has_x == 1` and
`display` is a live Tk connection. `test_keybind_snap_grid.tcl`'s own header comment
prescribes `DISPLAY=:0 ./src/xschem --pipe -q --nolog --script …`. It was authored as an X
test that happens to live in `tests/headless/`.

The trap is sprung only by `CLAUDE.md`'s own documented trustworthy-signal line,
`./src/xschem --nogui --pipe -q --script tests/headless/<t>.tcl`. Note that
`full_audit.sh:187` (`*"FATAL: signal"*` → CRASH) *would* classify it correctly if it ever
ran the file that way.

Blast radius, stated as measured and no further: 101 of the 305 files in `tests/headless/`
contain `xschem callback`. How many of those actually reach one under `--nogui` was **not**
measured — an initial 8-file sample showed 0/8 segfaulting, but inspecting the output showed
all eight had deferred earlier for unrelated reasons (`deferred (no --logdir; …)`,
`RESULT: SKIP (no X)`) and none reached a callback. That sample is inconclusive, not
exculpatory.

## Repro

Minimal — no schematic, no binding, one bare callback:

```tcl
puts "A: about to fire one canvas callback"
xschem callback .drw 2 100 100 103 0 0 0
puts "B: survived"
```

```
$ env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script min_repro.tcl
A: about to fire one canvas callback
FATAL: signal 11
while editing: untitled-11
```

`B: survived` never prints. Three further variants all reproduce: `--nogui` with
`DISPLAY=:0` set; no `--nogui` with `DISPLAY` unset; and event type `6` (Motion) instead of
`2` (KeyPress).

### Not merge 4

A detached worktree at `pre-open-pdk-merge-4` (`2f238fdc`), built with the three generated
files copied in (`Makefile.conf`, `src/Makefile`, `config.h`), fails identically at the same
point:

```
ok:   KB3a all five action ids are registered (bindable) (unknown: )
FATAL: signal 11
while editing: nand2
```

And the call is in the same place on that side of the merge:

```
$ git show 2f238fdc:src/callback.c | grep -n XGetKeyboardControl
8458:  XGetKeyboardControl(display, &kbdstate);
```

`8458` pre-merge, `8721` merged — the merge moved the line, not the defect.

## Suggested fix

One line, at the call site. This matches the guard idiom already used throughout the file
and is C89-clean, which an early `return` inside the callee would not be without care
(`XKeyboardState kbdstate;` is declared first in that block):

```c
/* src/callback.c:8896 */
-  update_statusbar(persistent_command, wire_draw_active);
+  /* headless (has_x==0): every widget this touches is Tk-only, and `display` is NULL
+   * (no DISPLAY) or already XCloseDisplay()d by xserver_ok() (draw.c:63) when --nogui
+   * is given with DISPLAY set. XGetKeyboardControl() on either segfaults.
+   * See doc/claude/issues/0227-headless-callback-segfaults-in-update-statusbar.md */
+  if(has_x) update_statusbar(persistent_command, wire_draw_active);
```

Equivalent if the guard is preferred inside the callee: `if(!has_x) return;` immediately
after the `int rect_draw_active = …;` initialiser (≈`src/callback.c:8710`) and before the
`#ifndef __unix__` caps-lock block.

**Worth fixing separately** (a latent trap, not this crash): add `display = NULL;` right
after the `XCloseDisplay(display)` at `src/draw.c:75`. That turns the dangling case into the
NULL case, so a guard missed anywhere else faults loudly and consistently instead of reading
freed memory.

### Verification this fix would need

None of it was run — the tree was built and `make` was out of scope for the audit.

1. `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_keybind_snap_grid.tcl`
   → expect `RESULT: ALL PASS (6 checks)`, **or an honest FAIL**. Guarding
   `update_statusbar` clears the *first* headless landmine in `callback()`; the rest of that
   function is unproven headless and later checks may expose more.
2. `xarm.sh one test_keybind_snap_grid.tcl` must still report `RESULT: ALL PASS (6 checks)`
   — the guard must not change the X path.
3. Sabotage-verify the guard actually runs (flip it to `if(1)` and confirm the segfault
   returns), per the green-but-hollow discipline.
4. Decide whether `test_keybind_snap_grid` should join `full_audit.sh`'s `nogui_tests` list
   (`tests/headless/full_audit.sh:69`) once it survives headless, so this class cannot
   silently return.

## Noted, not investigated

Unrelated `/tmp/xschem_emergencysave_{tb_test_evaluated_param,wvhier_leaf,dlatch}_*` dirs
dated the same day were present from other sessions. Whether they share this cause was not
checked, so no claim is made about them.

---

# 2026-09-20 — still live at `0eed8a1b`, four witnesses instead of one, and issue 0467 is this defect

Appended by the stranger-reds batch, from item B's out-of-scope findings
(`doc/claude/stranger_reds_batch/receipts/B-impl.md` §1.4 and §5,
`receipts/B-verify.md` §4.3, batch decision **D6**). Nothing above is edited; this
section is the newer word, and the stamp at the head is the newest.

## Still live, measured on a tree that fixed a sibling defect

Issue **1483** was a different statement of the same class — `xschem globals`
dereferencing `display` with no `has_x` guard — and it was fixed in `2288d437`. **This
one is untouched by that fix and was re-measured on the fixed binary.** The minimal
repro in "Repro" above, `env -u DISPLAY`, `--nogui`:

```
A: about to fire one canvas callback
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled_fccgcdbgff
FATAL: signal 11
```

`B: survived` never prints. **MEASURED** by item B's implementer.

The site is unchanged and is cited by identity because 0227's own `:8721` has already
rotted: `XGetKeyboardControl(display, &kbdstate);` is the single occurrence in `src/`,
inside `update_statusbar()`, which `callback()` calls unconditionally with no `has_x`
guard anywhere between. READ at `0eed8a1b` (where the line happens to be `callback.c:9891`
— re-grep rather than requoting that number).

## Four suites, not one

**MEASURED** by item B's fix round, `env -u DISPLAY HOME=<scratch> ./src/xschem --nogui
--pipe -q --nolog --script tests/headless/<t>.tcl`, on the **fixed** binary:

| suite | rc | verdict | a T1 case? |
|---|---|---|---|
| `test_keybind_snap_grid` | 1 | `FATAL: signal 11` | **no** |
| `test_undo_selection` | 1 | `FATAL: signal 11` | **no** |
| `test_hilight_case_senders` | 1 | `FATAL: signal 11` | **no** |
| `test_window_switch_bogus_enter` | 1 | `FATAL: signal 11` | **no** |

`test_keybind_snap_grid` is the messenger this file was filed from.
`test_hilight_case_senders` and `test_window_switch_bogus_enter` **appear in no issue
file at all** — they are new witnesses, added here rather than filed separately because
they are this defect at this site.

T1 membership re-checked by READ at `0eed8a1b`: none of the four is named in
`tests/run_regression.tcl`, and none is in `full_audit.sh`'s `nogui_tests` list either —
so `full_audit.sh` runs all four on its X arm, where they pass. **Nothing in this project
counts this crash**, which is why a green T1 at `counted_failures=0` — including the first
headless ZERO this tree has ever had — says nothing about it. That is the standing answer
to step 4 of "Verification this fix would need" above, and the answer is still "no".

## Issue 0467 is this defect, newly diagnosed

**0467 says `test_undo_selection` segfaults "at teardown, after every one of its checks
has passed", and says nobody has diagnosed it. Both halves are wrong.** MEASURED twice
independently — by item B's implementer and by its `reproduce` verifier — on the fixed
binary, `env -u DISPLAY`:

```
#0  XGetKeyboardControl () from libX11.so.6
#1  update_statusbar (persistent_command=0, wire_draw_active=0) at callback.c:9891
#2  callback (win_path=".drw", event=2, mx=100, my=100, key=117, …) at callback.c:10093
#3  xschem_cmds_c (… argc=10 …) at scheduler.c:2765
```

It dies **mid-suite**, on an `xschem callback` row, after 20 `ok:` rows — in
`update_statusbar()`. That is this file's defect exactly, and it means 0467's 20 passing
rows are the rows *before* the crash rather than the whole suite. **0467 is proposed for
closure as a duplicate of 0227**; the proposal, the measurement and the reason it is a
proposal rather than a closure are written into 0467 itself. Do not close it from here.

Read 0227's severity accordingly. The header above says *"no user-visible impact under X;
it silently truncates any `--nogui` script that fires a canvas event"* — four suites are
now known to be truncated by it, and one of them has been reported for a month as a
different bug.

## What has moved out of this file

* **The `display = NULL;` follow-up** that "Suggested fix" recommends in its last
  paragraph is now filed on its own as issue **1493**, with the measurement that justifies
  it (`xschem globals` reading `XMaxRequestSize=4` out of freed memory on the
  `--nogui`-with-`DISPLAY` arm, against a real `65535`) and with the reason it needs a
  sweep before it lands. It is **not** counted in this file's `open=`; follow the link
  rather than mirroring its status here.
* **Four `xschem` verbs that crash headless at other sites** — `fill_reset`,
  `fullscreen`, `copy_hilights`, `compare_schematics` — are filed as issue **1492**. Same
  contract, different verbs; 0834 is their stated parent.

## Why it was not fixed by the batch that measured it

Item B was scoped to issue 1483 and capped at one fix round, and this file's own
"Verification this fix would need" warns that guarding `update_statusbar()` *"clears the
FIRST headless landmine in `callback()`; the rest of that function is unproven headless
and later checks may expose more."* Four suites that nothing counts would start running
further than they ever have. **That is a new item, not a drive-by** — with
`test_undo_selection` as the red-first fixture, since it is deterministic (20 `ok:` rows,
then the crash) and the four give four independent confirmations of a fix.

## Still open (3)

1. `update_statusbar()` is still called unconditionally; the one-line guard in "Suggested
   fix" is unapplied and unverified.
2. The blast radius is still unmeasured beyond the four suites named above — "Blast
   radius" reports 101 of 305 files containing `xschem callback`, and how many reach one
   under `has_x == 0` is still not known.
3. Nothing counts this class: none of the four suites is a T1 case or in
   `full_audit.sh`'s `nogui_tests`, so every arm anyone runs is an arm where they pass.
