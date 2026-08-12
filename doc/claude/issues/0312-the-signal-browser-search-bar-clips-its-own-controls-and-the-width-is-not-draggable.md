# 0312 — the Signal Browser's search bar clips its own controls, and the sidebar width cannot be dragged

**Status:** FIXED, pending the user's eyes (a width deliverable is pixels).
Receipt: `doc/claude/batch_F/receipts/15-issue-0312-sidebar-grip-and-searchbar-wrap.md`.
Evidence: `tests/headless/test_wave_sigbrowser_0312.tcl` (57 checks, 35 sabotages).
**Filed:** 2026-08-11, from the Batch F eyeball queue (session 3, item 6 step 5).
**Found by:** hand, at the shipped default window size. Every headless check
passes, because a clipped Tk widget still exists, still holds its variable and
still answers `invoke`.
**Related:** signal-browser item 14 (the `All DBs` scope box), item 9 (the
two-pane sash), item 15 (restored sidebar width).

## What happens

Open a waveform viewer with the Signal Browser docked (`F6` /
`wviewer::browser_toggle`). At the default toplevel size the sidebar's top
search bar shows

```
[All ▾] [pattern________] [Shell ▾] [ ] Match case
```

and simply stops. `All DBs` and `Search` are built, packed and functional — they
are off the right-hand edge of a frame that is narrower than they are. There is
nothing on screen to say a control was dropped: no ellipsis, no scrollbar, no
overflow chevron.

The user cannot reach them without resizing the toplevel, and **maximising is
the only resize that works** — the sidebar has no draggable edge, so widening
the window by a normal drag does not necessarily widen the sidebar past the
threshold.

An eyeball step that says "tick `All DBs`" therefore reads as "there is no such
checkbox".

## Why

Two independent facts, both in `src/wave_viewer.tcl`:

1. **The width is computed and capped, not negotiated.** `browser_width`
   (`:11500`) derives its base from the search bar's own `reqwidth` minus the
   error label's, then applies `cap = 0.45 * [winfo width $top]` and a 240 px
   floor. On a default-sized toplevel the cap wins, so the frame is set
   *narrower than the bar's natural width* — and `pack propagate $f 0` on the
   line above means the frame does not grow back. The packer drops whatever no
   longer fits, right to left: the error label first, then `Search`, then
   `All DBs`. `$w.pat` is packed `-fill x -expand 1`, so the entry keeps its
   space while its neighbours vanish.

2. **There is no horizontal sash.** The only `ttk::panedwindow` in the sidebar
   is `$f.pw`, built `-orient vertical` (`:7923`) — it splits the instance tree
   from the sea of names. The sidebar itself is a plain frame packed
   `-side left -fill y -before $top.drw` (`browser_show`, `:11565`). Its width
   is whatever `browser_width` last wrote. Nothing in the UI exposes it.

The 45 % cap is deliberate and correct in intent (item 15: a restored width must
not exceed 45 % of a smaller toplevel). The defect is that when the cap bites,
the bar is silently truncated instead of adapting.

## Reproduce

```sh
DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s3_browser.tcl
```

(or any viewer with `F6`). Do not maximise. Look at the top search bar: the row
ends after `Match case`. Maximise the window — `All DBs` and `Search` appear.

Programmatic confirmation, from the CIW:

```tcl
set f [wviewer::window_for $::eye_tok].wvbrowser
winfo width $f                      ;# the capped width
winfo reqwidth $f.wvsearch          ;# what the bar actually needs — larger
winfo ismapped $f.wvsearch.alldb    ;# 0 while clipped, 1 when maximised
```

## Candidate fixes

In rough order of effort. Not ruled on — this needs a decision.

* **Wrap the bar** below a width threshold: pack `Match case` / `All DBs` /
  `Search` onto a second row instead of dropping them. Cheapest thing that
  removes the silent loss, costs one row of sidebar height.
* **Overflow chevron.** A `▾` button at the right edge, appearing only when a
  child is unmapped, listing the dropped controls as menu entries. Keeps the
  one-row bar. More code, and the checkbutton state has to be mirrored into the
  menu entry.
* **Make the sidebar width draggable** — a horizontal `ttk::panedwindow`
  between the sidebar and `$top.drw`, with `browser_width` seeding the initial
  sashpos. Fixes the general complaint ("I cannot make this pane wider"), not
  just this bar. Biggest change: `browser_show`'s `-before $top.drw` packing is
  explicitly load-bearing (see the ⚠ comment at `:11543`) and would have to be
  re-established inside the pane.
* **Horizontal scrollbar on the bar.** Cheap, but a scrollbar under a six-widget
  row reads badly and hides the controls just as effectively until scrolled.

### THE RULING (user, 2026-08-11): candidates 1 AND 3, both

Neither half is redundant, and the arithmetic is why. The bar needs **651 px**
(the 583 above predates item 14's `All DBs` box); the cap gives **450** on the
shipped 1000 px window; and a live drag goes through **that same cap**, because
lifting it would mean changing `browser_width`'s `want` semantics and `BP07`
pins those. So the grip alone can never reach 651 px on a 1000 px window, and
the wrap alone leaves EYEBALL_QUEUE item 5 step 7 (a judgement **at ~250 px**)
with no gesture that reaches it. Grip = the narrow end plus the general
complaint; wrap = every control on screen at the wide end.

**Candidate 3's literal form was not buildable.** A horizontal
`ttk::panedwindow` owns its panes, so `.wvbrowser` stops being a pack slave of
the toplevel — and the FROZEN `test_wave_sigbrowser.tcl` asserts that it is one,
on a live tree (BS24, BS41, BT21) as well as by source grep (BS01, BS02). Removing
just `-before` from that one line reds **16 checks in the frozen file**, measured.
What shipped is a 6 px grip frame packed BETWEEN the sidebar and the canvas, which
leaves the slave order — and every frozen literal — intact.

⚠ **Constraint on any fix that touches `browser_width`:** its body is grepped
for four literals by `test_wave_sigbrowser.tcl`'s BT08, and that file is FROZEN
(ruling 30). The cap/floor arithmetic must stay inline in that proc — do not
factor it into a helper.

## Not affected

The behaviour of the controls themselves. Once visible, `All DBs` ticks, the
tree grows its three database headers, and the search fires normally — Batch F
items 6 and 7 were eyeballed through this and passed. This is purely a matter of
reaching the control.
