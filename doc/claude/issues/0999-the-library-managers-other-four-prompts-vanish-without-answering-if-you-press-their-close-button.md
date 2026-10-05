# 0999 — the Library Manager's other four prompts vanish without answering if you press their close button

**Status:** FIXED 2026-10-05. **Filed 2026-08-31** by the S5 repair pass, while fixing
`[[0998]]` in the sibling window.
**Owner:** `src/library_manager.tcl`.
**Related:** `[[0998]]` (the same defect in **New library…**, fixed there),
`0799` (the synthesis-branch issue S5 closed; see `NUMBERING.md`).

---

## What the user does

Right-click in the Library Manager and pick any of **New cell…**, **Copy cell…**,
**Rename…**, **New view…** or **Copy view…**. A small window opens asking for a
name. Instead of pressing OK or Cancel, press the **X in its title bar**.

The window disappears. Nothing happens after that — no new cell, no error, no
message on the status line. The Library Manager still draws and still responds,
but the press you made is still, invisibly, waiting for an answer it can never
get, and it will keep waiting until you quit.

## Why

All five prompt windows in `src/library_manager.tcl` are built the same way:

```tcl
  bind $d <Return> {set libmgr::dlg_done 1}
  bind $d <Escape> {set libmgr::dlg_done 0}
  set dlg_done -1
  catch {grab $d}; focus $d.name
  vwait libmgr::dlg_done
```

`vwait` returns only when something writes `libmgr::dlg_done`. OK, Cancel, Return
and Escape all write it. **The window manager's close button writes nothing** —
there is no `wm protocol $d WM_DELETE_WINDOW` handler on any of them — and
neither does the window being destroyed from underneath (which is what happens if
the Library Manager itself is closed while a prompt is open). The toplevel goes
away, the `vwait` stays.

The five, by line, after the 0998 fix:

| proc | menu item |
|---|---|
| `libmgr::cell_dialog` | New cell… / Copy cell… |
| `libmgr::simple_prompt` | Rename… (library, cell, view) |
| `libmgr::view_dialog` | Copy view… |
| `libmgr::newview_dialog` | New view… |
| `libmgr::newlib_dialog` | New library… — **fixed**, see `[[0998]]` |

## Why New library… was fixed on its own and these were not

`[[0998]]` is about the same missing handler, but in the one window that **loops**:
since `0799`, a refused New library re-opens its window, and "the window returned
nothing" is that loop's only way out. There, a window that vanishes without
returning is a hang inside a loop rather than a single lost press, and the S5
suite could reproduce it. Widening the fix to the other four in the same pass
would have been four untested changes riding a repair, so they are recorded here
instead.

## The fix

The same two lines each, next to the existing `<Escape>` binding, plus the
`libmgr::newlib_vanished`-style guard so a child widget's `<Destroy>` is not read
as a Cancel:

```tcl
  wm protocol $d WM_DELETE_WINDOW [list set libmgr::dlg_done 0]
  bind $d <Destroy> [list libmgr::dlg_vanished %W $d]
```

`0` already means cancel in all five (`if {$ok == 1}` is the only accepting arm),
so the close button becomes Cancel, which is what a user pressing it means.

Worth doing as one change with one shared helper rather than five copies.

## How to see it

Needs a real window manager (the dev display runs openbox):

```
tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog
```
then in the Library Manager, right-click a library → New cell…, and press the
title-bar X. Nothing further happens; the press never completes.

---

## FIXED, 2026-10-05, in both halves

**The population was DERIVED, and this file's own table was two short.** Asking
the interpreter which `libmgr::` procs park in a wait in COMMAND POSITION gives
**seven**, not five:

```
::libmgr::cell_dialog  ::libmgr::commit_dialog  ::libmgr::maintain_picker
::libmgr::newlib_dialog  ::libmgr::newview_dialog  ::libmgr::simple_prompt
::libmgr::view_dialog
```

`libmgr::commit_dialog` (every check-in's comment box) and
`libmgr::maintain_picker` (Maintain's library picker) have the same gap and are
not in the table above. `libmgr::newlib_dialog` is the one `[[0998]]` already
fixed, so **six** prompts were unguarded.

**Product half.** The two handlers `[[0998]]` gave `newlib_dialog` are now the
shared `libmgr::dlg_way_out`, called by all seven prompts;
`libmgr::newlib_vanished` became `libmgr::dlg_vanished` and is no longer a
private copy. No timeout was armed, for 0998's reason: a window that closes
itself while somebody is typing is a worse defect than the one being fixed.

**Test half.** `tests/headless/test_lib_dialog_wayout_0999.tcl`, registered in
BOTH `hcases` and `dcases` (`banner_complete` sourced from
`tests/banner_rule.tcl` gives 1 on each arm's real captured output, and
`regression_case_failed` 0 on each). The counted arm derives the population and
requires every member to install a way out, so a prompt added later without one
reddens the gate's counted arm with nobody editing a list. The display arm opens
each derived prompt for real, destroys its toplevel without answering it, and
asks whether the press came back.

Measured on the unfixed tree, display arm:

```
RESULT: 16 FAILED (14 passed)
FAIL: LV2a every prompt in the derived set installs a close-button way out
      (without='::libmgr::cell_dialog ::libmgr::commit_dialog
                ::libmgr::maintain_picker ::libmgr::newview_dialog
                ::libmgr::simple_prompt ::libmgr::view_dialog' of 7)
FAIL: LV3a simple_prompt comes back when its window goes away unanswered, with
      nothing poked (rc=0 outcome=gone had-to-poke-it=1 err='')
FAIL: LV3e and no prompt in the sweep had to be poked to let go (pokes=6)
```

`had-to-poke-it=1` is the mechanism measured rather than read: after the
toplevel was destroyed the prompt's `dlg_done` still stood at the `-1` it is set
to just before the wait, so nothing had ended the wait and only the test writing
the variable freed it. `newlib_dialog` passed every row in that same run, which
is what `[[0998]]`'s fix working looks like.

**Same class, elsewhere, NOT fixed here** (so it is on the record rather than in
a reader's head): `src/alt2_toggle_view.tcl` has one `vwait alt2::dlg_done`
behind one toplevel with no close-button handler at all — the same defect in a
different namespace, and its own `dlg_done` variable, so this file's helper does
not reach it.
