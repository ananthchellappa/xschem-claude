# 0370 — `hi_descend_newwin` still hijacks a full window table and orphans a window on a refused descend

Status: **FILED (measured, not fixed)**
Found by: D4 Verify-C (adversary), 2026-08-10; re-measured by the D4 write-up agent.
Class: descend census. This is **0256 (c1) and 0256 (b) in the sibling proc that D4 did not
touch.** Siblings: 0256 (fixed), 0251, 0371.

## Summary

D4 hardened `open_sub_schematic` with two new guards, `newwin_open_ok` (a slot was really
taken) and `newwin_descend_failed` (tear the window down and report). Its sibling
`hi_descend_newwin` (`src/xschem.tcl:6010-6060`) has the **same two defects** and got
neither. Two procs, one defect, one fixed — and per
`doc/claude/specs/hi_descend.md:243-245` the *unfixed* one is the preferred long-term path.

## (a) Orphan window on a refused descend — measured

`--nogui --pipe -q --nolog`, a `type=label` instance (not descendable):

```
PX| nwin before = 1
PX| hi_descend_newwin(l1 = a type=label) -> 0
PX| nwin after  = 2   windows = {.drw ... lp.sch} {.x1.drw ... lp.sch}
PX| current ctx = .x1.drw schname=lp.sch currsch=0
```

It returns 0 **correctly** — and then leaves a window that should not exist, sitting on the
**parent** sheet, with the active context **switched into it**. The context switch is the
part Verify-C added over the Implement agent's own note C: the user is not merely left with
an extra window, they are left *inside* it.

`open_sub_schematic` on the identical instance now destroys its window and returns 0.

## (b) The window-table-full hijack — measured under real X

Confirmed by Verify-C under `GUI_GATE=0 xvfb-run -a`, so it is not a headless artefact. With
the table filled to `MAX_NEW_WINDOWS` (20) and an instance selected:

- `open_sub_schematic` → `0`, victim `.x19.drw` still shows `fill19.sch`, context stays `.drw`
  (the D4 fix, row R25).
- `hi_descend_newwin` → `0`, but victim `.x19.drw` is **clobbered** from `fill19.sch` to
  `parent.sch` by `copy_hierarchy`, and the active context is left switched to `.x19.drw`.

Cause is the shape 0256 documented: `src/xschem.tcl:6035` still does `if {!$res} {...}` and
then reads `set new_window_path [xschem get last_created_window]`. `last_created_window` is a
static in `src/xinit.c:54`, assigned only on a **successful** create (`:2012`, `:2168`) and
never reset, so on failure it names an unrelated earlier window.

## Suggested fix

Reuse the two procs D4 already wrote — they were factored out for this:

- gate on `newwin_open_ok $res $nwin_before` **before** reading `last_created_window` or
  running `copy_hierarchy`;
- call `newwin_descend_failed $src_win $new_win` when `hi_descend_finish` returns false.

Note `newwin_open_ok` gates on the **window count**, not a `last_created_window` delta —
destroying a window frees its slot, so the next create legitimately reuses the same path.

Fixing 0371 first is advisable, since `newwin_descend_failed` is the proc being reused and it
currently clears the modify flag before an unverified destroy.

## Coverage

None for `hi_descend_newwin`. The equivalent rows for `open_sub_schematic` are R23 (orphan),
R24 (c2) and R25 (c1) in `tests/headless/test_descend_refusal_channel_0251.tcl` and are a
ready-made template — the `hi_descend` family additionally needs the `ciw_echo` recorder
already used by rows R27/R28.
