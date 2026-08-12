# 0318 — resizing the sidebar wipes the sentence drawn inside the empty pane

**Status:** **FIXED pending an eyeball** — `f6e3b20a` (branch
`fluid-editing`, unpushed). Candidate 1 below, spelled as an explicit
`keepnote` argument on `browser_sea_refresh` whose DEFAULT is "navigation": the
`<Configure>` trampoline is the one caller that passes 1, and a kept notice also
keeps the pane's caption. Regression test
`tests/headless/test_wave_sigbrowser_0318.tcl` (17 checks under X, 19 measured
sabotage mutations); reasoning, the caller classification and the review triage
are in `doc/claude/batch_F/receipts/18-issue-0318-resize-wipes-the-notice.md`.

**The eyeball that is still owed** — the checks prove the sentence is drawn, in
`#8b0000`, inside the pane, and re-wrapped to the pane's width at two widths.
They cannot judge whether it READS well, which is what
`EYEBALL_QUEUE.md` item 5 step 7 was blocked on. Exact steps:

1. `make -C src` is NOT needed (Tcl only). Build the fixtures if they are gone:
   `sh doc/claude/batch_F/eyeball_fixtures.sh` (do **not** `rm -rf`
   `/tmp/xschem_eyeball_F`).
2. `DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s4_item5.tcl`
3. Do `EYEBALL_QUEUE.md` item 5 steps 1-6 (select `a1` in `tb1.sch`,
   **Ctrl-Alt-V**, hands off, count to three) so the sentence
   `showing the digital scope 'TOP' of 'dig.vcd' in the tree, but that scope has
   no signals of its own - open one of its sub-scopes to see any` is drawn
   **inside** the empty lower pane.
4. **The fix:** drag the divider between sidebar and waveform canvas until the
   sidebar is roughly 250 px wide. **PASS:** the sentence is still there, in dark
   red, re-wrapped to the narrow pane, and the caption strip under the pane still
   reads the same sentence. **FAIL:** it vanishes (the reported bug), or it is
   there but clipped / illegible / overlapping the caption.
5. Then answer step 7's actual question, which is a verdict and not a pass/fail:
   at ~250 px, do the two single-line surfaces (pane caption, sidebar header's
   second line) CLIP the sentence — i.e. does F5 need a short form for them?
6. **Two things deliberately NOT fixed, which will still happen:** press
   `Ctrl-B` twice and the sentence goes (hide/show re-reads the raw — a
   navigation); and select signals in the lower pane, then drag the divider, and
   the selection is dropped (**issue 0320**).
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

## What was taken (2026-08-12)

Candidate 1, as an explicit `{keepnote 0}` argument rather than a save/restore
around the call — the clear happens BEFORE the draw, so a restore afterwards
would need a second draw and would still let the caption be overwritten. The
DEFAULT stays "navigation" on purpose: this file's own ruling is that a stale
reason is worse than none, and splitting the clear into the navigation callers
(candidate 2) would have inverted that default for every future caller — and
would not have fixed the CAPTION surface at all, since `browser_sea_say` runs at
the tail either way. All three callers are classified in the receipt. Two things
of the same family were deliberately left: `Ctrl-B` twice (a repopulate, not a
geometry event) and the pane's **selection**, which the same `<Configure>` still
drops — filed as **issue 0320** rather than widening this one.
