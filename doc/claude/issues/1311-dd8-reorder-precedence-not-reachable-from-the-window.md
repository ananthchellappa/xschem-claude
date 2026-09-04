# 1311 — DD-8's precedence is FILE ORDER, and the Results window cannot reorder the entries whose order it is

**Filed by item B5 (2026-09-04). Measured, reported on screen, NOT fixed.**
Status: **FILED, NOT FIXED.**

## The gap

Ruling **DD-8** deletes glob ranking and makes precedence **file order**, and its
own justification is:

> *the user already has a reordering UI. The spec's own button column gives
> every list Up and Down. So precedence becomes something the user sets by
> dragging.*

That is true of the **rows inside one list** and false of the **entries** whose
precedence DD-8 is about. The Results window's pane shows one line per
**parameter** of one dumped device; it never shows the settings file's `flavor`
entries, so Up and Down move `gm` above `id` — they cannot move
`flavor mos *nfet*` above `flavor mos *`.

Measured (row **BT10**, third leg, `tests/headless/test_rdw_window_1245.tcl`):
with `flavor {b5cls *} annotation` declared first, a narrow Delete on M1 writes
`flavor {b5cls <cell of M1>} annotation` correctly, and `effective` still
answers the `*` entry, because `*` is earlier in file order. Nothing the window
offers can change that.

## What ships instead

`rdw::_edit` detects the shadow at the one place it can — *what I just wrote is
not what `effective` now answers* — and says so:

> ... but an entry declared earlier in the settings file also matches this cell
> and still wins - precedence is file order, so move this entry above it.

So the button is never silently dead; the user is told the remedy and the remedy
is a text editor.

## Options

* **(a)** a second pane, or a second mode of the existing pane, listing the
  `flavor` entries for the subject's class in file order, with the same Up/Down;
* **(b)** a `reorder` verb on the store plus a small dialog listing the matching
  entries when a shadow is detected;
* **(c)** leave it: the file is the documentation (DD-8's own line) and the
  status line names the fix.

**Recommended: (a)** if the shadow turns out to be common; **(c)** until then.
The measurement to take first is how often two flavor globs match one cell in a
real PDK settings file.
