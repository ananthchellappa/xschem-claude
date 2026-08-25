# 0697 — `ase::session_open`'s refresh arm mutates the session state without firing the notify hook

Status: OPEN (filed by the 0695+0696 crew, 2026-08-25; measured, not fixed here)
Area: src/ase.tcl (session model) — surfaced by src/ase_window.tcl's notify consumers
Related: 0695 (the Save All box must follow an external write), 0692, 0679, 0691

## What was measured

`ase::session_update` (ase.tcl:~2716) ends in `ase::session_notify_fire $key`, and
so do `session_save` / `session_load` / `session_revert` / `session_adopt`. Every
GUI consumer of "the session state moved" hangs off that single-slot hook
(`ase::session_notify`, set to `ase::ui::session_changed` at ase_window.tcl:277).

There are exactly TWO places that write `dict set sessions $key ... state` and do
NOT fire it:

* `ase.tcl:2696` — `ase::session_open`'s **re-open refresh arm**. Re-opening a
  session that is NOT dirty replaces the whole in-memory state from disk:
  `dict set sessions $key [dict create path $path state $st saved $st]`, then
  returns. No `session_notify_fire`.
* `ase.tcl:3081` — creates a brand-new session, so there is no window yet and no
  hook to fire. Not a gap.

So `:2696` is the whole gap.

## Why it matters (the 0695 shape)

After 0695 the Save All dialog's checkbuttons follow the live value through
`ase::ui::session_changed` -> `ase::ui::save_all_refresh`. Re-launching ASE-L on
the same cellview while a Save All dialog is open takes the `:2696` arm: the live
blankets are replaced from disk and the checkbuttons do **not** move. Independently
of 0695, the window title's dirty marker and the status bar do not refresh either,
because they are the other two things `session_changed` does.

## Why it was NOT fixed in 0695+0696

Blast radius. Adding the fire is a change to the session model's **notify
contract** for every open/raise path, none of which the 0695+0696 item measured;
the crew's scope fence forbade widening. Recorded here rather than taken silently
(decision D7 of that item).

## Recommended option

Fire `ase::session_notify_fire $key` at the end of the refresh arm ONLY (not on
the dirty early-return, which changes nothing), then measure: re-open with a Save
All dialog up, and re-open with the panes dirty, asserting the title/status/box.

## Acceptance (when it is taken)

1. `ase::session_open` on a clean session with a Save All dialog open moves the
   checkbuttons to the imported values.
2. The dirty marker and status bar refresh on the same gesture.
3. The dirty early-return arm still fires nothing (it mutates only `path`).
