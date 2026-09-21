# 0834 — `xschem callback` segfaults under `--nogui`

**STAMP:** `v1 claim=open tree=0eed8a1b stamped=2026-09-20 fix=untried open=3 by=B-docs`

Status: **measured LIVE, NOT FIXED.** Pre-existing; hit by 0831's scout and
0831's Implement agent while trying to drive `callback.c:559` headlessly.
Severity: **medium** — a crash, not a corruption, and only on a path a GUI
session does not take. Its real cost is to *testing*: it is why the
`start_place_symbol()` door (0831, `callback.c:559`) needs an X server and a real
`event generate` to drive at all.

## 1. Measured — 2026-08-26, on the 0831 tree

```tcl
catch {xschem callback . KeyPress 100 100 0 73 0 0 0} r
puts "rc=|$r|"
```

```
$ ./src/xschem --nogui --pipe -q --nolog --script cb.tcl
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled_fcfgccabee
FATAL: signal 11
while editing: untitled
```

Exit 1, SIGSEGV, emergency save fired. Deterministic. Reproduced independently
by two agents.

## 2. Why it matters even though nobody calls it that way

`xschem callback <win> <event> ...` is the documented funnel from GUI events into
`callback()` (see CLAUDE.md, "The `xschem` Tcl command"). It is the obvious way
for a headless suite to drive a keyboard route, and every such attempt crashes
instead of erroring. The workaround 0831 used — a real `event generate` on the
persistent dev display `:99`, with `load_file_dialog` stubbed so the modal
chooser does not hang the script — works, but it forces an X dependency onto
suites that would otherwise be `--nogui`.

## 3. Not diagnosed

No bisect, no backtrace, no minimal event set was taken; the crash was in the way
of 0831's work, not its subject. Likely candidates to check first, in order: the
`has_x`-conditional GC / window fields that `callback()` dereferences without a
guard, and the window-name lookup for `.` when no toplevel was ever created.

## 4. The fix, when someone takes it

At minimum, **reject the verb when `has_x` is false** with a proper Tcl error, the
way the other display-dependent branches in `scheduler.c` do — a clear error is
strictly better than a signal 11 plus an emergency-save directory. Better still,
find the null and let the verb work headlessly, which would let the
`start_place_symbol()` / key-`I` family be tested without X.

Either way it needs a driven row: `catch {xschem callback ...}` under `--nogui`
must return a Tcl error and the process must still be alive afterwards.

---

# 2026-09-20 — §3 "Not diagnosed" is answered, and the contract in §4 is broken at four more verbs

Appended by the stranger-reds batch from item B's out-of-scope findings
(`doc/claude/stranger_reds_batch/receipts/B-impl.md` §1.4,
`receipts/B-verify.md` §4.3 and §4.4, batch decision **D6**). Nothing above is edited.

## The backtrace §3 asks for

**MEASURED** on a build of 2026-09-20, `env -u DISPLAY`, `--nogui`:

```
#0  XGetKeyboardControl () from libX11.so.6
#1  update_statusbar (persistent_command=0, wire_draw_active=0) at callback.c:9891
#2  callback (win_path=".drw", event=2, mx=100, my=100, key=117, …) at callback.c:10093
#3  xschem_cmds_c (… argc=10 …) at scheduler.c:2765
```

`update_statusbar()` is called unconditionally at the top of `callback()` and
dereferences the `display` global with no `has_x` guard. That is **issue 0227**, filed
2026-08 and still live, and it is the first of §3's own two candidates — *"the
`has_x`-conditional GC / window fields that `callback()` dereferences without a guard"*.

⚠ **This does not yet prove 0834 and 0227 are one bug, and the difference is the second
candidate.** The receipt's words are that *"0834 is the same defect (both are `xschem
callback` under `--nogui`); nothing measured here distinguishes them"* — which is the
absence of a distinction, not a demonstration of identity. **0834's repro uses window
`.`; 0227's uses `.drw`.** §3's other candidate — *"the window-name lookup for `.` when
no toplevel was ever created"* — has **not** been ruled out, and `update_statusbar()`
runs before any dispatch, so a crash there would mask a later one. Guard
`update_statusbar()` first, then re-run **this file's** repro verbatim: if `.` still
dies, the second candidate is real and this file is not a duplicate.

## §4's contract, broken at four more verbs

§4 asks for the general rule — *"reject the verb when `has_x` is false with a proper Tcl
error … a clear error is strictly better than a signal 11 plus an emergency-save
directory."* Four more `xschem` verbs break it, at sites that have nothing to do with
`callback()`: `fill_reset`, `fullscreen`, `copy_hilights` and `compare_schematics`, the
last exiting **139** rather than reaching xschem's own handler. Filed as issue **1492**,
which names this file as the parent of the contract and says what would have to be
measured before the two are merged.

A related global that makes the whole class quieter than it should be —
`xserver_ok()` closing the display without nulling the pointer, so a missed guard reads
freed memory instead of faulting — is filed as issue **1493**.

## Still open (3)

1. `xschem callback` still crashes with `has_x == 0`; §4's contract is unimplemented.
2. Whether this is issue 0227 or a second defect at the `.` window lookup is **not
   settled** — see the ⚠ above for the one experiment that settles it.
3. Nothing counts it: `tests/headless/test_callback_argc.tcl` is the T1 case for "a
   Tcl-reachable subcommand must ERROR, never crash" (issue 0076) and has rows for
   `xschem globals` since `2288d437`, but none for this verb.
