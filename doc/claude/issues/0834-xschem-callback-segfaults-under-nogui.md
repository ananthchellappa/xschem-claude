# 0834 — `xschem callback` segfaults under `--nogui`

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
