# Action-registry FAQ

Running Q&A about the input action-registry / binding-table work (branch
`feature/action-registry`). Each entry records the **project state when it was
asked** (branch + HEAD commit + phase), because answers are tied to how much of the
refactor had landed at that moment — a later phase may make an old "no" a "yes."

Newest entries on top.

---

## Q4. So far, how has this work made the code easier to read and maintain?

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `21ea55f4`. We are partway
  through **Phase 3c** (moving keyboard/mouse handling into the lookup table); the
  scroll wheel, the right-drag zoom gesture, the no-modifier `f` and arrow keys, and
  the graph-routing of six more keys are done. **Phase 3d** (deleting the old
  hard-wired code) has not started.

**The honest headline first: the code is currently a bit *longer*, not shorter.**
This phase is an investment. We added the new "controls list" machinery (the lookup
table, the part that reads it, and the commands to edit it) *before* we could start
removing the old hard-wired handling. So the file grew by roughly 425 lines. That
reverses later, in Phase 3d, when the old code gets deleted now that the new system
can replace it. So far we've only begun that removal (about 30 lines gone in the
most recent step).

**What is genuinely easier to read today:**

1. **Commands have names now.** Before, what a key did was spelled out as raw math
   and function calls buried inside one enormous 1,600-line block. Now each behavior
   is a small, clearly named piece (e.g. "zoom full", "scroll up", "hand this to the
   waveform graph"). You can tell what a key does by its name instead of decoding it.

2. **"Which key does what" is now a plain list, separate from "what it does."**
   Previously those two ideas were tangled together in every case. Now there's an
   editable list of "this input → this command," and you can print the whole list
   with one command to see every shortcut at a glance. That single, readable
   overview simply did not exist before.

3. **A copy-pasted block is being deleted.** The exact same five-line check —
   "if the mouse is over a waveform graph, hand the event to the graph" — had been
   pasted into the code about twenty times. We've removed it from the scroll-wheel
   handling entirely and from six keyboard shortcuts so far, each time replacing the
   duplicated code with a single line in the list. More removals are queued.

4. **One shared path instead of three different ones.** The wheel, the mouse-drag
   gestures, and the keyboard now all flow through the same handling, with one clear
   rule for which binding wins. A maintainer learns one mechanism, not three.

5. **The tricky, easy-to-break details are now written down.** The handful of subtle
   rules that used to be invisible traps (why certain shortcuts must stay as-is, why
   one check has to happen before another) are now explained in comments right where
   they matter, plus a short tutorial and these FAQ entries — so the next person
   doesn't have to rediscover them the hard way.

**Bottom line:** any individual shortcut is clearer (named, self-explaining, with its
reasoning attached), and the system as a whole is now navigable through one readable
list instead of a giant undocumented block. The raw line count is temporarily higher;
it drops below where it started once Phase 3d removes the now-replaceable old code.

---

## Q3. In plain language (high-school level): what are the next couple of steps, and what's the end goal?

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `cd5b5c9a` (wheel, zoom-rect
  gesture, and the no-modifier `f` + arrow keys are data-driven; Group B sweep next).

**Next couple of steps**

1. **"Group B" keys sweep.** A handful of keys (`a`, `b`, `s`, Ctrl+tab-switch
   arrows, …) each carry a copy-pasted "if the mouse is hovering over a waveform
   graph, hand this to the graph instead" check buried in a 1600-line block of C.
   The next step lifts just that check out into the lookup table (a plain list of
   "this input → does that"). The keys' normal jobs (open a dialog, save a file)
   stay in C; only the graph-routing part becomes data. This deletes a lot of
   duplicate code. (Caveat found while scoping: some of these keys check an
   "are we busy?" counter *before* the graph check, so they must be migrated
   carefully or deferred — see the semaphore-ordering note in the Phase 3c work.)
2. **Let an action run a Tcl command, not just C.** Today the table can only point a
   key at a built-in C function. Most menu items are written in Tcl (the scripting
   layer). Teaching the table to also say "this key runs *this script command*"
   unlocks migrating dozens more keys.

**End goal (the analogy)**

Think of a TV remote whose buttons are *soldered* to fixed jobs — you can't make the
red button do the green button's thing without rebuilding the remote. That's how
XSCHEM's keyboard/mouse handling works today: every shortcut is hard-wired deep in
the code.

We're replacing it with a **"Controls" settings list**, like the rebind-your-keys
menu in a video game. One master list says *"this key / mouse button / scroll does
this action,"* and:

- **You can edit it** in a config file to remap anything — no recompiling. (Already
  true for the scroll wheel and the arrow keys; see Q2.)
- **The help/cheat-sheet builds itself** from that same list, so it can't drift out
  of sync with what the keys actually do.
- Once everything is moved over, the old hard-wired code is **deleted**, leaving the
  program smaller and easier to maintain.

In one line: **turn soldered buttons into a remappable controls menu — for every
key, mouse button, and scroll — and let the help screen generate itself from it**,
done one small, fully-tested batch at a time so nothing breaks.

---

## Q2. Can a user remap the mouse wheel — **Ctrl+wheel = zoom, plain wheel = vertical pan, Shift+wheel = horizontal pan** — via `.xschemrc` / `--script`? (And why didn't the original author's `replace_key` snippet work?)

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `bfec8793` (Phase 3a wheel
  fully data-driven; 3b gestures; 3c c4/c5 first key `f`). Wheel dispatch goes
  through the in-C binding table (`xschem bind wheel ...`).

**Answer: Yes — fully supported and verified.** Put these in `~/.xschem/xschemrc`
(or `./.xschemrc`, or a `--script` file):

```tcl
# zoom with Ctrl+wheel
xschem bind wheel up   ctrl canvas view.zoom_in
xschem bind wheel down ctrl canvas view.zoom_out
# vertical pan with plain wheel
xschem bind wheel up   0    canvas view.pan_up
xschem bind wheel down 0    canvas view.pan_down
# Shift+wheel already pans horizontally (view.pan_left / view.pan_right) by default
```

Verified against observable state after firing synthetic wheel events
(`xschem callback .drw 4 <mx> <my> 0 <4|5> 0 <state>`; state 0/1/4 = plain/Shift/Ctrl):

| Input | Result | Verdict |
|---|---|---|
| plain wheel | `zoom` unchanged, `yorigin` moves | vertical pan ✅ |
| Ctrl+wheel  | `zoom` changes                   | zoom ✅ |
| Shift+wheel | `zoom` unchanged, `xorigin` moves | horizontal pan ✅ |

`xschem bindings dump` reflects the swap. (Swap `up`↔`down` for the opposite scroll
direction.) Timing is safe: `xschem bind` calls `ensure_input_bindings()`, which
lazily seeds the defaults *then* applies the override; `init_input_bindings()` is
guarded by `input_bindings_initialized`, so it never re-runs and clobbers the user's
rows — order of `.xschemrc` vs GUI bring-up does not matter.

**Why the original author's `replace_key` snippet didn't work.** `replace_key` is a
separate, *older, Tcl/Tk-level* mechanism (`set_replace_key_binding` →
`key_binding`, xschem.tcl:10994/1121). It installs a more-specific Tk binding such
as `<Control-Button-4>` that re-emits an `xschem callback` with a **rewritten
modifier mask** (e.g. mapping `Control-Button-4` → the state of a plain
`ButtonPress-4`), tricking the C wheel handler into seeing a different chord. It is
fragile in ways that bite silently:

- **Tk 8.7 / 9.0 deliver the wheel as `<MouseWheel>`, not `<Button-4/5>`**
  (xschem.tcl:9981 only binds `<MouseWheel>` when `tclversion > 8.7`). On those
  builds the `<Control-Button-4>` overrides never fire — the physical event isn't a
  Button-4 event. **Most likely cause of the failure.**
- Depends on Tk binding-specificity and on which widget (`.drw` vs the toplevel) the
  generic `<ButtonPress>` (xschem.tcl:9996/9998) vs the `replace_key` binding land
  on — subtle, easy to get subtly wrong.
- Piggybacks on the C button-mask stripping (`callback.c:4507`) as an undocumented
  implementation detail.

**Why the binding table is robust instead.** It dispatches **in C, after** the
event is normalized to "wheel up/down + clean modifier mask" — independent of Tk
version or how Tk delivered the event. It is the intended replacement for
`replace_key` for wheel/button/(now) key remapping.

**Caveats.**
1. Over a waveform graph, plain/Shift wheel still routes to the graph
   (`graph.forward` over_graph rows, unchanged); the canvas rebind only affects
   bare-canvas wheeling. Ctrl+wheel stays canvas-zoom even over a graph (its branch
   in `handle_mouse_wheel` forces `ctx=ACTX_CANVAS`).
2. Keep `graph_use_ctrl_key` at its default `0`. Setting it `1` reserves Ctrl+wheel
   for graph interaction, and `handle_mouse_wheel` returns early for Ctrl — so the
   canvas zoom binding won't be reached.

---

## Q1. Can a user remap the zoom-rectangle gesture from RMB-drag to **Ctrl+RMB-drag** with the current code?

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `898639af` (Phase 3a/3b done,
  Phase 3c c4/c5 first batch — key `f` — done). Mouse buttons: only the *bare*
  Button3 zoom-rect chord is data-driven (Phase 3b).

**Answer: No — not with the code at that commit, even though the binding can be created.**

`xschem bind button 3 ctrl canvas view.zoom_rect` parses and stores a valid row
(`parse_mods("ctrl") → ControlMask`, code 3). But the **press handler never reaches
the table dispatcher for a *modified* Button3 chord.**

`handle_button_press` (`callback.c`) is an `if / else-if` chain, and the data-driven
`dispatch_button_chord()` sits at the *end* of it (`callback.c:4560`). Earlier
`if`/`else if` branches hardcode the modified-Button3 chords and match first:

```c
if     (!excl && button==Button3 && state==ControlMask && semaphore<2) { … select_connected_nets(1); }  // 4522 ← Ctrl+RMB caught HERE
else if(!excl && button==Button3 && EQUAL_MODMASK && …)                { break_wires_at_point(…); }       // 4530/4536  (Alt+RMB)
else if(!excl && button==Button3 && state==ShiftMask && …)             { select_connected_nets(0); }      // 4542  (Shift+RMB)
…
else if(!excl && semaphore<2 && dispatch_button_chord(button, state, mx, my)) return;                      // 4560 ← table only reached here
```

`state` *is* correctly button-mask-stripped at `callback.c:4507`, so
`dispatch_button_chord` would see `mods==ControlMask` and *could* match the row — but
it is never called for Ctrl+Button3 because the hardcoded branch at 4522 wins and the
dispatch is in a later `else if`. Only **bare** Button3 falls through (the plain-RMB
context menu was moved to the release path, freeing the no-modifier slot).

**The completion side is already ready.** On Ctrl+RMB *release*, `state ==
Button3Mask|ControlMask`, so the exact-match context-menu branch
`if(state == Button3Mask)` (`callback.c:4779`) is skipped and the Phase 3b
fallthrough `else if((ui_state & STARTZOOM) && semaphore<2) end_place_move_copy_zoom()`
(`callback.c:4789`) completes the gesture. So only the **initiation** is blocked.

**What it would take** (a natural Phase 3 follow-on, same pattern as the key work):
1. Extract the hardcoded modified-Button3 branches into `act_*` fns
   (`select_connected_nets`, `break_wires_at_point`) + `{button 3 ctrl/shift/alt
   canvas}` rows; **or**
2. Move `dispatch_button_chord` earlier so a user-bound chord pre-empts the hardcoded
   default ("table-first, hardcoded-fallthrough" precedence, like the keys now have).

**UX consequence:** Ctrl+RMB is already a feature (select instance + connected nets,
stopping at junctions), so rebinding it to zoom means relocating that feature to
another chord.
