# 0902 — the transient annotation gate unloads databases it never attached

**Status:** FIXED in the same commit as issue 0900's repair (item A14).
**Filed:** 2026-08-28, by item A14's sabotage pass, reproduced in place on the
shipped tree by the repair pass.

## What the user sees

A design window is holding more than one results database — the ordinary
mixed-signal case is one analog transient plus one co-simulation VCD, the shape
`doc/claude/specs/mixed_signal_signal_browser.md` D5 is written about. The user
presses `Alt-Shift-6`. The waveform window has moved on to a newer run, so the
press correctly decides the numbers on the sheet cannot be believed and goes and
gets the run on screen.

On its way it takes **every** database off the window, including the VCD nobody
asked it about. The digital back-annotation the user had on their sheet goes
blank, and nothing says why.

## Measured

`cadence::_annot_tran_unwind` (utils/annot_mode.tcl) opened with a bare
`catch {xschem raw clear}`. `src/scheduler.c` documents that spelling verbatim:
*"if no file is given unload all raw files."*

Probe on the shipped tree, 2026-08-28, one window, two databases:

```
slots_after_both   = 2
free_rawfile(): clearing data
free_rawfile(): clearing data
slots_after_unwind = 0
xschem raw loaded  : 0  ->  -1
```

Before item A14 that call was reachable only on a press that had itself attached
the one database it then took off, so it could only ever destroy its own. A14's
new gate preamble calls it whenever **anything** is attached, so from that item
on it destroys other people's.

## The fix

`cadence::_annot_tran_unwind` now goes through `cadence::_annot_db_release`,
which

* takes off **one** database, by name — `xschem raw clear <file> <type>`, the
  spelling `ase::attach_dbs` (src/ase.tcl) already uses; and
* never takes off a **digital** one. RULING D5-3: a digital database publishes
  nothing to a schematic, `xschem annotate_op` refuses one before it loads
  anything, so this surface can never have attached a VCD and has nothing of its
  own to put back.

`cadence::_annot_tran_supply`'s "did my own read work" test moved from
`xschem raw loaded` to `cadence::_annot_db_analog_loaded` at the same time. With
a VCD legitimately left attached, `xschem raw loaded` answers 0 whether the
supplier's read worked or not, and the user would be told the file is "from a
different simulation run" when the truth is that it could not be read — a wrong
reason, which is the same defect class as a wrong number.

Rows: V72 and V73 (behavioural, both arms), V74 (structural).

## Boundary, stated rather than left to be discovered

`_annot_db_release` takes off the **current** database. A design window holding a
second, non-current *analog* database would keep it. No shipped path puts one
there — every VCD attach in the tree runs inside the waveform window's own
context, and `xschem annotate_op` replaces rather than appends — so this is the
edge of the claim, not a known defect.

The same bare `xschem raw clear` is still in the operating-point surface's 0872
unwind (utils/annot_mode.tcl, in `cadence::annot_mode`). It is **not** changed
here and it is not the same defect: that arm is reachable only when
`xschem raw loaded` was < 0 on entry, so it can only ever take off the database
that press attached itself.
