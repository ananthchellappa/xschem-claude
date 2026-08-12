# 0315 — the Signal Browser reports one landing TWICE in the CIW, and on a benign gesture one of the two is red

**Status:** OPEN. **Not fixed: which of the two lines should survive is a
ruling, not a bug fix.**
**Filed:** 2026-08-11, from the Batch F eyeball queue, item 5 step 8 (the re-run
after issue 0314 was fixed).
**Found by:** hand, in the CIW log of a real Ctrl-Alt-V session
(`/tmp/Xschem.log.4`).
**Related:** item 5 step 8 (which asked whether the CIW pair "reads as one
account of one gesture"), RULING 5f-3 and decision 11 (one event, one account),
issue 0314 (the gesture that now reaches this code at all).

## What happens

Every `Show in Signal Browser` gesture writes the landing sentence to the CIW
**twice** — once by the viewer's own reporter, unprefixed, and once by
`ase::show_in_browser_for_current`, prefixed `ase: `. On the success path:

```
#= signal browser: showing TOP
#= ase: signal browser: showing TOP
#= ase: signal browser: showing the digital scope 'TOP' of 'dig.vcd' in the tree,
   but that scope has no signals of its own - open one of its sub-scopes to see any
```

Three lines for one gesture, of which the first two are the same sentence.

On the **a9 control** — a cell with no verilog view, the gesture that is
supposed to be uneventful — the duplicate is worse, because the viewer's copy is
tagged as an **error** while the ASE copy is a plain result:

```
#! signal browser: no signals under 'a9'
#= signal browser: showing the simulation top level
#= ase: signal browser: 'a9' has no level in the simulation data; showing the design root instead
#= ase: signal browser: showing the simulation top level
```

Four lines, one red, for a gesture whose eyeball verdict is PASS. `#!` is the
error tag (red in the CIW pane), so a benign navigation lands a red line in the
log the user is being trained to trust as a failure marker.

## Where it comes from

* `wviewer::browser_say` (`src/wave_viewer.tcl:11590`) sets the sidebar status
  line **and** echoes `signal browser: <msg>` to the CIW, with the `err` arm
  echoing it tagged `error`.
* `ase::show_in_browser_for_current` step 6 (`src/ase.tcl:2731`) then echoes the
  same `wviewer::browser_msg` answer again as `ase: signal browser: <msg>` —
  deliberately, with a ⚠ explaining that it must be the SAME sentence from the
  SAME formatter as the sidebar's status line.

Both are right on their own: the viewer reports its own navigation, and the ASE
command reports what its gesture did. Nobody decided what happens when one
gesture drives both, and the eyeball is where that showed.

## Why it is a ruling and not a fix

Three defensible answers, and they differ in what a *viewer-side* gesture (the
tree's own double-click, `Descend to here`) should still print:

1. **The ASE command owns the CIW account.** `browser_say` stops echoing when it
   was driven from `show_in_browser_for_current` (a flag, or an echo-suppressing
   variant), keeping its status-line write. Viewer-side gestures keep their line.
2. **The viewer owns it** and step 6's echo goes, leaving only F5's notice as the
   ASE-prefixed line. Loses the `ase: ` prefix that ties the line to the command
   the user actually pressed.
3. **Both stay, but the tags are fixed**: a landing that FELL THROUGH (a9, and
   every code block whose own level is not in the analog raw) is not an error,
   so `browser_say`'s `err` arm must not paint it red when the caller went on to
   land somewhere sensible.

(3) is the smallest and fixes the red line; (1) is the one that makes the log
read as one account per gesture. They are not exclusive.

## Reproduce

```sh
DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s4_item5.tcl
```

Click `a1`, Ctrl-Alt-V — three lines, two identical. Click `a9`, Ctrl-Alt-V —
four lines, one red. The CIW log is `/tmp/Xschem.log.<N>`.

## Not affected

Issue 0314's fix, which is what made the a1 gesture reach a landing at all: the
sentences quoted above are the CORRECT ones, on the correct surfaces, and the
duplication predates it on every viewer-side path.
