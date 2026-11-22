# Receipt: item 03b, waveform viewer keys when the keyboard is in another window

> **Driver's note, 2026-11-22 06:52.** This receipt was written in the clone before the
> item landed. Since then:
>
> - The commit is in the main tree `/home/analog/dev/xschem-claude` as `454030f5c`
>   (cherry-pick of the clone's `fcdb11585`). Two documents conflicted with item 04,
>   which had landed in between, and were merged by hand keeping both: in
>   `doc/claude/FAQ.md` this item's entry is **Q97** in the main tree (Q96 is the
>   double-click entry), and `doc/claude/TEST_LESSONS.md` keeps both sets of lessons.
>   `src/callback.c` merged by itself with item 04's comment lines. Every other file
>   is the gated one. Not pushed.
> - The main tree is rebuilt (`make -C src`, rc 0); `test_wave_subwindows` (289) and
>   `test_dblclick_connected_grow` (112) pass there without a display. To try section
>   2, start `/home/analog/dev/xschem-claude/src/xschem` (close any xschem of that tree
>   that is open first). The combined tree (items 03, 03b, 04, and 02 when it lands)
>   gets one full regression of its own before the port; the batch's `PLAN.md` logs it.
> - Debts filed from the main tree (`tests/headless/owed.sh show`): look
>   `viewer_keys_focus_elsewhere_real_screen`; rules `viewer_keys_focus_elsewhere`
>   (the item as a whole; it replaces the text filed after item 03),
>   `viewer_read_only_still_reachable`, `viewer_mirror_state_keys`,
>   `viewer_keyboard_after_open_or_raise` (with the search-box case),
>   `viewer_handed_key_details` (the bars, F10/Tab/Alt-letter, the skipped canvas keys,
>   Escape), `viewer_mmb_pan_inset_high_scaling`.
> - The three small things section 5 lists as not fixed (the missing row for the
>   Signal Browser while the viewer's window holds the keyboard, the spec sentence
>   without its condition, the stale comment above `viewer_takes_foreign_key`) are
>   taken up in a follow-up commit; `PLAN.md`'s driver log says how it ended.

Overnight batch of 2026-11-21. Kind: code. Base commit `c78d0f1d3`.

## 1. Verdict

**Done, and something has to be looked at (mark E).**

The item is one commit, `fcdb11585`, on `fluid-editing` in the clone `/home/analog/ob21`, parent `c78d0f1d3`, not pushed.
It is not yet in `/home/analog/dev/xschem-claude` or in the private tree.
The full regression ran green on it: zero counted failures.
The commit changes `src/callback.c`, so a tree that receives it has to be rebuilt.

**What you now have.** With the pointer over a waveform viewer's plot, a key is a viewer key, whichever xschem window holds the keyboard.
Ctrl-Shift-M flips the plot mode, `a` and `b` toggle the cursors, `m` drops a marker, and a schematic editing key does nothing: no "View is Read Only" box.
A viewer that has just opened takes its keys without a click in its plot.

**Why E and not a clean pass.** Four things:

- **The popup you reported is still reachable by another road.** If the viewer was the last drawing area the pointer entered, the keyboard is in the schematic, and the pointer is in no viewer (on a title bar, a menu, the desktop, or still over the schematic right after a viewer opened), an editing key such as `w` still brings up "View is Read Only". Moving the pointer into the schematic's drawing area ends it (out and back in if it never left). This was declared, not cured, and needs your ruling.
- **Nothing here was measured on your Windows X server.** Where the keyboard lands after a viewer opens or is raised depends on the desktop. Every measurement was on Xvfb with openbox.
- **You have not ruled on the item itself.** The lead decided what the keys should do; section 3 lists it.
- **Two small problems the last check found are not fixed** (section 5): one missing test row, and one case after a raise where typed characters now run viewer shortcuts.

## 2. What to try

Use a rebuilt tree that has the commit (today only `/home/analog/ob21/src/xschem`), in the Cadence workarea profile, on your real screen.

1. Open a viewer from ASE-L (Tools > Waveform Viewer) or with a Direct Plot. Move the pointer into the plot and do not click. Press Ctrl-Shift-M. The status bar's plot mode (single/multi) must flip, with no box. Press `a` and `b` over a strip: the cursors toggle.
2. Right after an open, with the pointer still over the schematic, press `u` and `e`. Nothing may change in the viewer.
3. Click the schematic window's title bar, move the pointer back over the plot without clicking, and press Ctrl-Shift-M, then `w`. The mode flips; `w` does nothing. If you use Alt-Tab and it lands in the ASE-L window, the key belongs to ASE-L and nothing happens; click the schematic's title bar first.
4. Move the pointer back into the schematic's drawing area and press `w`. A wire starts.
5. Start a run with auto-plot on and keep the pointer over the schematic. When the run ends the viewer comes forward. Keys typed over the schematic must do nothing until you click in the schematic, and no trace or strip may be lost.
6. Finish a Direct Plot from the schematic and leave the pointer over the schematic. Click in the schematic and type `w`. If "View is Read Only" comes up, move the pointer out of the drawing area and back in, and type `w` again: a wire must start. Please say which of the two happened after the click.

**What to look at, since no test can see it:**

- Where your desktop puts the keyboard after an open and after a raise (the viewer, the schematic, or ASE-L). Steps 1, 2 and 5 depend on it.
- Whether a click in the schematic ends the leftover state in step 6. It did under openbox and did not on a display with no window manager.
- The feel: with the pointer parked over the viewer, typing in the schematic acts on the viewer silently. Nothing on screen says which window a key will go to.

## 3. Decisions taken for you

**Rulings of 2026-11-21, one line each.** None of yours covers this item. The lead, not you, decided the item as a whole: a key typed in a schematic window while the pointer is in a viewer is the viewer's; a release follows its press; keys typed in ASE-L, the Calculator or the Signal Browser's search box stay there; no new chord. The lead also withdrew item 03's point that the chord need only work with the focus on the plot.

**Holes the crews filled.**

- **Where the key is caught.** The work order named the engine as the only place. The crew measured a second one: a schematic canvas has key bindings of its own that never reach the engine (in the Cadence profile `i` gave the read-only box and `q` a modal property dialog). They chose to catch the key on every schematic canvas first, and keep a guard in the engine for keys that arrive another way. Rejected: the engine guard alone.
- **Where a viewer open leaves the keyboard.** The first build put it on the plot. That made keys typed over the schematic act on the viewer every time a finished run raised it (`e` deleted empty strips, Ctrl-d cleared the traces). The repair took that back: the keyboard is left on the viewer's window exactly as before the item, and a key arriving there is the viewer's only while the pointer is over the plot. Rejected: focus on the plot in either case; focus on the plot unless the pointer is over a schematic; giving the plot the focus when the pointer enters.
- **How much of the viewer counts as "the pointer is in the viewer".** For a key typed in a schematic window: the whole viewer window (plot, status bar, tab row, Signal Browser), once the pointer has been over the plot. For a key that arrives on the viewer's own window: the plot only, so that a character meant for the Signal Browser's search box does not run a shortcut. Rejected: the plot only in the first case; the whole window in the second.
- **The pointer goes from the schematic straight onto the viewer's Signal Browser or bars, without crossing the plot.** The key stays the schematic's and runs in the schematic. The product was left as it is and the texts that promised otherwise were corrected. Rejected: asking where the pointer is before asking which window xschem is working in, because that changes behaviour for users who turn `mouse_follows_focus` off.
- **The leftover popup (section 1).** Declared in the guide, the spec and the FAQ; not cured. Rejected: dropping the key (dead schematic keys instead of a box); switching the working window to the one the key was typed in, which touches the engine's most delicate path.
- **The mirror state.** With the keyboard on a viewer's plot, a key stays with that viewer wherever the pointer is, including over a schematic or over a second viewer. The lead left the schematic case as it was; the crew extended that to two viewers. Rejected: routing by pointer.
- **F10, Tab and Alt-letter.** While a key typed in a schematic is handed to the viewer, these do nothing in either window. With the keyboard on the viewer's own window they work as before (F10 posts the viewer's menu). Rejected: running the remaining bindings, which would move the focus.
- **Which viewer binding runs.** The code reads the viewer's live binding table and applies Tk 8.6's rules as measured: a binding naming the key beats one that does not, then more modifiers win, then the later bound. Rejected: an older Tk order, and a second hand-kept list of chords.
- **What is not read.** Multi-key sequences, double presses, virtual events and Meta bindings of your own on the viewer are not chosen for a handed-over key. Alt is read as the engine reads it.
- **An error in a binding.** The handed-over key stops there, as Tk stops. Rejected: correcting the comment and letting the walk go on.
- **The middle-button pan (a rider from item 03).** The press must clear 8 pixels inside a strip up to a Tk scaling of 1.6, and more above (11 at 2.0, 16 at 3.0). Rejected: a formula that moved the inset already at 1.4.
- **Windows.** The guard is compiled on every platform, not only Unix. This was read in the Tk headers, not built.
- **No issue number was minted.** The open states are returned as debts.

## 4. How it was checked

**Rows added or restated.** In `tests/headless/test_wave_viewer.tcl` (display only): KM14 and G1f restated; KM16 to KM23 new. In `tests/headless/test_wave_subwindows.tcl` (both arms): SWK30 to SWK35 new, and a new leg in SWK19. What they hold, in plain terms:

- KM14: the chord, its release, Caps Lock, the status bar, F10, a nameless key and a binding that errors, all typed with the keyboard on the main canvas and the pointer in the viewer.
- KM16: editor keys do nothing there. KM17: graph keys act, in both profiles, by both routes. KM18 and G1f: after an open and after a raise the keyboard is on the viewer's window, the chord works without a click, and `u`, `e`, Ctrl-d typed over the schematic leave the viewer alone.
- KM19: the choice of binding is compared with Tk's own answer on the live table in every run. KM20: two viewers. KM21: an ordinary second schematic window. KM22: the Signal Browser's search box. KM23: a key arriving on the viewer's own window.
- SWK30 to SWK34: the parts of the mechanism, without a display too. SWK35: the pan inset across scalings. SWK19: the chord with no cursor, one cursor, both.

**Red before the change.** On the product of `c78d0f1d3`: G1f, every check of KM14 except its control, KM16 to KM20, two checks of KM21, KM23, and SWK30 to SWK35. Green there by construction: the controls (KM14 "the pointer decides", half of KM20, KM22) and KM21's fence. The SWK19 leg is a row only; the product was already right.

**Breaks of the product.** The build made 35 deliberate breaks, the repair 39 (against the rows as they stand now); each reddened at least one row. A third crew rebuilt 12 of them and got the predicted rows, then tried 6 breaks of its own: 5 caught, **1 not caught** (section 5). Five breaks that the review found uncaught after the build are now caught: catching the key on the main canvas only (KM21), running every binding (KM14, F10), counting the guard as a nested engine call (KM17), forcing the focus at an open (KM18), an error that does not stop (KM14). Two of the build's breaks stall the suite until its timeout and were not rebuilt after the repair.

**Suites and arms at the committed tree**, on a private Xvfb with openbox:

| suite | display | display with action log | no display |
|---|---|---|---|
| `test_wave_viewer` | 535 pass | 538 pass | 59 pass |
| `test_wave_subwindows` | 585 pass | 585 pass | 289 pass |

`test_wave_viewer` gives 535 when run alone and 538 inside the regression; the three extra checks need an action log and are older than this item. Sixteen neighbouring viewer and ASE suites also passed on the display arm. Real keys from the X server (not Tk-generated) were sent by hand-run probes only, under openbox and once with no window manager.

**The gate.** Full regression in the clone, detached, private display, binary `/home/analog/ob21/src/xschem`, throwaway home, no other run live in the clone.

```
T1-RUN-END pid=598977 cases=225 blocks=224 counted_failures=0 skips=13 elapsed=1375s end=2026-11-22 06:43:57
```

Verdict file: `/home/analog/ob21/tests/results.598977.log` (I read its last line; it matches). The 13 skips are the same lines as at item 03's gate, all rows that need a display or an action log on an arm that has none; none is from this item's suites.

**Not checked.**

- Your Windows X server, in any respect: where the keyboard lands, physical keys, whether a click sends the crossing events.
- `:0` (Xwayland). The new rows move the real pointer by a warp, which Xwayland may not honour.
- The tabbed interface: no row runs under it.
- `mouse_follows_focus` off: read in the code, not run.
- Auto-plot's real chain after a real run followed by typed keys; the rows call the viewer's open directly.
- The Windows build. A reviewer recalls that Tk's keysym-name call may return nothing there, which would affect only a script that calls the engine directly; unverified.
- A Tk scaling other than the test display's, with a real button or key.
- Pixels. Nothing new is drawn; the status bar is read as text.

## 5. Left open

**Not fixed.**

- **"View is Read Only" from the schematic**, as in section 1. Two states: (a) the pointer was last in the viewer and now rests on a title bar, a menu, the desktop or another program; (b) a viewer just opened while the pointer rests over the schematic and the desktop left the keyboard there. Options: leave as declared; drop such a key; make the window the key was typed in the working window.
- **After a raise with the pointer over the plot, typed characters run viewer shortcuts.** If you were typing in the Signal Browser's search box or an ASE-L field when a run ended and the viewer came forward, and the pointer rests over the plot, the next characters act on the viewer (measured: `e` removed an empty strip). Before the item they were dropped. The spec's sentence about this lacks the condition "with the pointer still in the search box", and the debt text did not name the case.
- **One break no row catches.** If the viewer's own window also took keys while the pointer is over the Signal Browser, every suite stays green. The row to write is described in the review: show the browser, pointer over the search box, keyboard on the viewer's window, type `e`, expect nothing.
- **A stale comment.** The comment above `viewer_takes_foreign_key` in `src/callback.c` still says "ONE OF TWO DOORS" and does not name row KM17. The Tcl file and the spec count three.

**Where the facts I was given disagree with the tree.** The build's account describes a proc `wviewer::focus_plot` and an open that focuses the plot, with counts 531 and 584. The tree has no `focus_plot`; the repair replaced it with `wviewer::top_key` and the open is as it was before the item. The build's rule and look debts described the withdrawn design and are replaced by the list below. The build's claim about the status bar, tab row and Signal Browser holds only once the pointer has been over the plot.

**Limits.** Keys in the mirror state; F10, Tab and Alt-letter dead while a key is handed over; a pick armed on the schematic (Calculator, RDW) is not cancelled by Escape in that state, the viewer takes it; Ctrl-Shift-4 typed in the schematic with the pointer in the viewer now does nothing, which the guide does not say; the new rows wait a fixed short time after each pointer warp, a possible flake on a loaded machine.

**Seen outside the work order, not touched.**

- `test_wave_sigbrowser_keys` (rows BK22, BK29, BK31) and `test_wave_sigbrowser_0312` (BF21a, BF24a) fail on the display arm, the same before and after; neither is registered in the regression.
- Under the tabbed interface, the pointer coming back from a viewer into the main canvas makes the first tab the working one whatever tab is showing (one probe, not re-measured).
- "Descend to here" focuses the design window's toplevel after raising it, the pattern this item met in the viewer.
- The gate's own sweep removed the batch's baseline verdict `tests/results.2248040.log` that `PLAN.md` names. Item 03's `results.3819655.log` is still there with the same trailer.
- Crews made scratch clones outside the clone (`/home/analog/ob21r`, `/home/analog/ob21h`), against the batch rule; both are removed.

**Debts to file** (nobody has touched the ledger for this item).

Look:
- Steps 1 to 5 of section 2 on the real screen.
- Step 6 of section 2: does a click in the schematic end the leftover state.

Rule:
- The item as a whole, decided by the lead.
- The mirror state, with the two-viewer case.
- The leftover "View is Read Only" (states a and b above, three options).
- Where an open or a raise leaves the keyboard, and that only the plot counts there; including the search-box case above.
- The pointer going straight onto the viewer's bars or Signal Browser does not make the key the viewer's.
- F10, Tab and Alt-letter dead while a key is handed over, and the schematic's own canvas keys skipped in that state.
- The middle-button pan's deeper inset above a Tk scaling of 1.6.

## 6. Files changed

Eleven files in commit `fcdb11585`, all under `/home/analog/ob21`:

- `src/callback.c`: the guard `viewer_takes_foreign_key` at the top of `callback()`.
- `src/wave_viewer.tcl`: `wviewer::foreign_key`, `key_door`, `top_key`, `tag_key_seq` and helpers; `wviewer::pan_inset_px`.
- `src/xschem.tcl`: `set_bindings` puts the viewer's tag first on every schematic canvas.
- `tests/headless/test_wave_viewer.tcl`, `tests/headless/test_wave_subwindows.tcl`.
- `doc/waveform_viewer_guide.html`: sections 9.1, 9.3 and the troubleshooting rows of section 12.
- `doc/claude/specs/waveform_viewer.md` (new section "A key that came through another window"), `waveform_viewer_modes.md`, `waveform_viewer_subwindows.md`.
- `doc/claude/FAQ.md` (new entry Q96), `doc/claude/TEST_LESSONS.md` (five lessons).

`src/Makefile.in` is untouched and no file was added. Evidence from the crews is under `/tmp/claude-1000/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/scratchpad/` in `ovb03b`, `rep03b` and `chk03b`; that directory does not survive a reboot.
