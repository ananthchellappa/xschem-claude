# 0318 — resizing the sidebar wipes the sentence drawn inside the empty pane

**Status:** OPEN. Not fixed. Mechanism located and quoted below; no code changed,
no test written.
**Area:** `src/wave_viewer.tcl` — `browser_sea_configure` → `browser_sea_refresh`
(the `set browserseanote($token) {}` line) vs `browser_sea_draw`'s notice arm.
**Found:** by hand, 2026-08-12, by the user, at `EYEBALL_QUEUE` item 5 step 7 —
the eyeball that issue 0312 had been blocking.
**Related:** §F item F5 (the notice this loses), issue 0313 (a refused gesture
emptying the sidebar — same family: a non-navigation event treated as a
navigation), issue 0312 (whose grip is what made this reachable by dragging).

## What happens

Do steps 1-6 of `EYEBALL_QUEUE` item 5 so the sentence

```
showing the digital scope 'TOP' of 'dig.vcd' in the tree, but that scope has no
signals of its own - open one of its sub-scopes to see any
```

is drawn **inside** the empty lower pane. Now drag the sidebar divider
(issue 0312's grip) to make the sidebar really narrow.

**The sentence vanishes from the pane.** Not clipped, not badly wrapped — gone.
The pane goes back to being an unexplained empty box, which is the exact state
§F item F5 exists to abolish. Selecting `a1` in `tb1.sch` and pressing
**Ctrl-Alt-V** again brings it back, because that mints a fresh notice.

Reported verdict on the step it blocked: *"When you drag to make it really
narrow, the sentence vanishes from the signal pane. Doing select of a1 in
tb1.sch and CTRL-ALT-V again displays it again."*

## Why

`browserseanote($token)` holds the sentence. Its whole lifetime is one line in
`browser_sea_refresh`:

```tcl
  # §F item F5: THE NOTICE IS CLEARED BY THE NEXT REFRESH, and this line is
  # where its whole lifetime is decided. A refresh means the user moved — a new
  # node, a new keystroke, a re-scoped tree — and a sentence about the PREVIOUS
  # gesture's refusal would then be a caption on a pane it does not describe.
  set browserseanote($token) {}
```

That reasoning is right about navigation and wrong about geometry, because the
sea canvas's `<Configure>` is wired straight into the same proc:

```tcl
  bind $f.pw.sea.c <Configure> ...        ;# -> browser_sea_configure
proc wviewer::browser_sea_configure {token} {
  return [wviewer::browser_sea_refresh $token]
}
```

So **a resize is treated as "the user moved"**. It is not: the user changed how
wide the pane is and asked for nothing. The pane redraws, `browser_sea_draw`
finds the note empty, and its notice arm is skipped.

`browser_sea_draw`'s own header shows the intent was the opposite — it already
handles a narrow pane deliberately:

```tcl
  # ⚠ `-width` IS THE PANE's WIDTH: the sentence is a whole clause naming a
  # file and a scope, and a canvas text item does not wrap without one. The
  # floor keeps it wrapping rather than vanishing in a sidebar dragged narrow.
```

The floor works. The text never reaches it.

## Reachability — wider than the grip

0312's grip is what made this trivial to hit, but it is **not** the only door.
Any `<Configure>` on that canvas does it: resizing the toplevel, the tab bar
appearing, `Ctrl-B` twice with a different width, a window manager tiling the
window. Before 0312 the sidebar had no draggable edge, which is why the
eyeballing of F5 never caught it.

## Fix, when someone takes it

The clear belongs to **navigation**, not to every refresh. Options, cheapest
first:

* Give `browser_sea_configure` a refresh that redraws without clearing — e.g.
  save and restore `browserseanote($token)` around the call, or split the clear
  out of `browser_sea_refresh` into the callers that really are navigations
  (`<<TreeviewSelect>>`, a search keystroke, a re-scope).
* Splitting is the honest shape, but note the count: `browser_sea_refresh` has
  several callers and each has to be classified as navigation-or-not. A
  save/restore in the `<Configure>` trampoline is one line and closes the
  reported symptom exactly.

⚠ **A check for this must resize the pane and then read the canvas item**, not
the variable — `browserseanote` is what survives; the drawn `seanote` tag is
what the user sees. `bs_wait_mapped` plus a `$c find withtag seanote` is the
shape. A source grep cannot see it: every line involved is already there and
individually correct.
