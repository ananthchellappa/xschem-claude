# `handle_key_press`: an engineering critique, and what "from scratch" looks like

*A study of one function as a lens on input-handling design. Written alongside the
action-registry refactor (`tutorial_action_registry.md`, `…_phase2.md`), which
began dismantling the problem this essay describes.*

---

## 0. What we are looking at

`handle_key_press` in `src/callback.c` is the function that decides what every
keystroke in the drawing canvas does. By the numbers (measured, not estimated):

- **~1600 lines**, one function body.
- **93 `case` labels** in a single `switch (key)`.
- **15 parameters** in its signature.
- **75** copies of the `if (xctx->semaphore >= 2) break;` reentrancy guard.
- **23** `waves_selected(...)` mouse-over-graph guards.
- **16** `infix_interface` mode forks and **32** `MENUSTART…` state pokes.
- **81** `tcleval`/`tclvareval` shell-outs to Tcl; **39** `move_objects(...)`
  calls; **117** distinct engine functions invoked inline.
- The longest single case (`'s'`) is **54 lines** with five modifier sub-branches.

None of this is the product of bad programmers. It's the product of *twenty years
of a working tool*, where each new key was added the cheapest local way: another
`case`, another `if (modifier)`, another inline call. Every individual edit was
reasonable. The sum is a function that is now one of the most expensive places in
the codebase to change — and, not coincidentally, the single biggest obstacle to
improving xschem's UX. This essay is about *why* that happened structurally, what
a professional would build instead, and what the recent refactor did about it.

> A note on tone. The goal here is not to dunk on a mature, genuinely useful EDA
> tool. It's to name the design forces precisely, because naming them is what made
> the fix tractable. xschem works; that it works *despite* this function is the
> interesting part.

---

## 1. The core mistake, stated once

Every other problem below is a symptom of one root decision:

> **The key *is* the control flow.** `switch (key)` makes the physical keystroke
> the top-level branch of a 1600-line function, and hangs the actual behavior —
> command dispatch, modal state machines, mouse-context routing, Tcl shell-outs,
> platform quirks — off it as inline code.

A keystroke is *input*. What it should produce is a **command** (an intent: "zoom
in", "start a wire", "save"). Conflating the two — letting the input's identity be
the program's branching structure — means the mapping from key→command is not data
you can read, change, or test. It's executable control flow tangled together with
the commands themselves. You cannot ask the program "what does Ctrl+S do?" without
*running* it, because the answer is spread across a `case 's'`, a Shift-mask
calculation, a `waves_selected` check, and a `semaphore` guard.

Hold that thought; it's the whole essay.

---

## 2. How it handicaps maintenance — the specific anti-patterns

### 2.1 Knowledge triplication: the same fact in three hand-synced places

"Ctrl+S saves" lives in **three** unconnected locations:

1. a menu item with `-accelerator {Ctrl+S}` in `build_widgets` (xschem.tcl) — the
   accelerator there is **decorative**, a label that binds nothing;
2. the `case 's'` Ctrl branch in `handle_key_press` — the *real* handler;
3. a line in `keys.help` (220 lines of prose) describing it to users.

Nothing connects them, so they drift, and they have: the menu shows one
accelerator, C implements another, the help file documents a third. There is no
single source of truth for "what keys exist," which means there is no foundation
for *any* feature that needs that list — a command palette, customizable
shortcuts, a toolbar, tooltips, an accurate cheat-sheet. The scale of the
duplication: **221 menu items, 133 command rows, 220 lines of help**, each
maintained by hand. (This is the finding that motivated the whole refactor.)

> **Maintenance cost:** every shortcut change is a three-file edit that the
> compiler can't check, and the documentation is wrong by default.

### 2.2 The God function with a 15-parameter signature

```c
static void handle_key_press(int event, KeySym key, int state, int rstate,
    int mx, int my, int button, int aux, int infix_interface, int enable_stretch,
    const char *win_path, double c_snap, int cadence_compat,
    int wire_draw_active, int snap_cursor)
```

Fifteen parameters is the signature *screaming* that this function does too much:
it needs mouse position, modifier state in two pre-chewed forms, three feature
flags, a window path, the snap grid, and in-progress wire state — because it is
simultaneously a dispatcher, several modal state machines, and a renderer. There
is no unit you can extract and test in isolation; the function only makes sense
with the entire `xctx` global and a live X connection behind it.

### 2.3 Hidden coupling through `xctx`, and reentrancy by manual guard

Because behavior is driven by global state (`xctx->ui_state`, `->semaphore`,
`->constr_mv`, `->last_command`, …), the same key does different things depending
on invisible context, and the code defends itself with **75 hand-placed
`semaphore >= 2` guards**. That number is the tell: reentrancy isn't handled by
the *architecture* (e.g. a dispatcher that refuses to re-enter), it's handled by
copy-pasting the same `break` into 75 branches. Miss one, and you get a reentrant
crash; the defense is vigilance, not structure.

### 2.4 Boilerplate that should be a function, repeated dozens of times

The flip/rotate keys (`f F r R v V`) each contain a near-identical block:

```c
rebuild_selected_array();
xctx->mx_double_save = xctx->mousex_snap;
xctx->my_double_save = xctx->mousey_snap;
move_objects(START,0,0,0);
move_objects(FLIP,0,0,0);     /* or ROTATE, or two ROTATEs + a FLIP */
move_objects(END,0,0,0);
```

`move_objects(` appears **39 times**. The "transform the selection" operation has
no name; it's an inline incantation pasted with small variations. A bug fixed in
one copy must be found and fixed in the others by hand.

### 2.5 Three orthogonal concerns braided into every case

A single `case` routinely interleaves things that have nothing to do with each
other:

- **mouse-context routing** — `if (waves_selected(...)) { waves_callback(...);
  break; }` (23 times): "if the pointer is over a waveform graph, do the graph
  thing instead." This is *hit-testing*, smuggled into the keyboard handler.
- **modal interaction** — `infix_interface` forks and `MENUSTART`/`STARTWIRE`
  state transitions: the front edge of stateful operations.
- **command execution** — the actual `view_zoom(0.0)` or `tcleval("xschem …")`.

These three should live in three layers. Braided together, you cannot reason about
or change one without understanding all three. (This braiding is also why so few
keys are safely *movable* — see §5.)

### 2.6 Cleverness that compresses knowledge into the reader's head

```c
#define EQUAL_MODMASK ((rstate == Mod1Mask) || (rstate == Mod4Mask))
rstate = state & ~ShiftMask;   /* "the character keysym already encodes Shift" */
```

The modifier handling is genuinely clever: Shift is stripped because for letters
the keysym (`'a'` vs `'A'`) already encodes it, and Alt/Super are unified under
`MODMASK`. But "clever" is a maintenance liability when it's undocumented load-
bearing knowledge. The fact that `case 'U'` is *redo* (reached by Shift+u) while
`case 'u'` is *undo* is invisible unless you've internalized the rstate trick —
and it bit us during the refactor until we wrote it down.

### 2.7 Platform and feature flags inline

`#ifdef __unix__` / `#ifndef __unix__` blocks for `XK_ISO_Left_Tab` vs `XK_Tab`,
`HAS_CAIRO` for `XK_Print`, and runtime forks on `cadence_compat` (7×) and
`infix_interface` mean the function encodes *several different editors at once*,
selected by compile- and run-time switches threaded through the body. The same
1600 lines describe the Unix build, the Windows build, the Cadence-compatible
keymap, and the infix/postfix interaction modes.

---

## 3. What a professional would build from scratch

The fix is not "write the switch more nicely." It's to separate the four things
the function conflates into four layers, each independently testable.

```
   keystroke ─▶ [1] binding/keymap ─▶ command id ─▶ [2] command registry ─▶ action
                       (data)                              (data + fn)
                                                                │
   in-progress edits ─▶ [3] interaction state machine ◀────────┘ (only for modal cmds)
   pointer location  ─▶ [4] input router (which surface owns this event?)
```

**[1] A keymap that is data, not control flow.** A table mapping
`(keysym, modifiers, mode) → command-id`. Loaded from a file, overridable by the
user, introspectable ("what is Ctrl+S?" is a lookup, not an execution). This is
the single source of truth that kills the triplication of §2.1.

**[2] A command registry.** Each command is a first-class record: a stable id, a
human label, a help string, a handler function, and an `enabled-when` predicate.
*One* command, referenced by the keymap, the menu, the palette, the toolbar, the
cheat-sheet. Adding a command is adding a row + a function, once.

**[3] An explicit interaction state machine for modal operations.** Drawing a
wire, dragging a selection, placing a symbol — these *are* state machines
(`idle → placing → rubber-banding → committed`). Model them as such, with named
states and transitions, instead of as `ui_state` bit-flags poked from 32 scattered
sites. Modal keys (`Esc`, `Space`, constrained-drag `h`/`v`) become transitions in
*this* machine, not cases in the global switch.

**[4] An input router that decides ownership first.** "Is the pointer over a
waveform graph, a schematic, a dialog?" is answered *once*, up front, routing the
event to the surface that owns it — instead of 23 `waves_selected` checks
re-deciding it inside individual key cases.

**Reentrancy by design, not by guard.** A dispatcher that is non-reentrant by
construction (a queue, or a single guard at the entry point) deletes all 75
inline `semaphore` checks.

**Testability falls out for free.** With key→command as data, you can unit-test
"Ctrl+S maps to `file.save`" with no display and no engine. With commands as
functions behind ids, you can test the command without synthesizing an X event.
The current design allows *neither* — which is why, before the refactor, there
were no tests for any of this.

What this is, in one phrase: **the Command pattern** (intents as objects) plus a
**keymap as configuration** — the architecture every mature editor (Emacs,
VS Code, Vim, CAD tools) converges on, for exactly these reasons.

---

## 4. The honest counterargument: should it have been built this way *in 2002*?

Mostly no — and that's worth saying plainly, because hindsight is cheap.

- The tool began small. A `switch` on keys is the *correct* amount of structure
  for 15 shortcuts. The design didn't become wrong; it was outgrown.
- C89 with Xlib gives you no batteries — no maps, no closures, no reflection. A
  data-driven command registry is more code to *build* in C than in the Tcl layer
  that didn't yet carry as much weight.
- A working tool with users has the strongest possible constraint: **don't break
  it.** A from-scratch rewrite of input handling in a 20-year-old EDA tool is a
  high-risk, low-visibility project that could regress muscle memory for every
  existing user. The rational move is almost never "rewrite"; it's "stop the
  bleeding and migrate incrementally."

So the interesting question isn't "why didn't they build it right" (they built it
right *for the size it was*). It's: **given the function as it exists today, how do
you get the from-scratch architecture without a rewrite?** That's what the refactor
actually did.

---

## 5. What the refactor has done so far (the strangler-fig, not the bulldozer)

The action-registry work applies the **strangler-fig pattern**: grow the new
structure *around* the old one, route through the new where proven, and let the
old shrink — never a flag-day rewrite. Concretely:

**Phase 1 — the missing data layer (`tutorial_action_registry.md`).**
Introduced `src/actions.csv`: one row per action with `id, label, menu, accel,
command, help`. This is layer [2] (the command registry) and the seed of layer [1]
(the keymap), as *data*, in Tcl, with zero C changes. From it we generate the File
menu and a fuzzy **command palette** (Ctrl+Shift+P) — the first feature that was
previously "too expensive," now nearly free because the list of actions finally
*exists* as data. This directly attacks §2.1.

**Phase 2 — bindings become data, without touching C
(`tutorial_action_registry_phase2.md`).**
Generated real keyboard bindings from the same table, exploiting one property of
Tk: **a more specific binding pre-empts a more general one on the same widget.**
The generic `bind $topwin <KeyPress> "xschem callback …"` is what feeds
`handle_key_press`. By installing a *specific* `bind $topwin <Control-Key-z>
"…zoom_out…"`, we intercept that key **above** the C function — Tk fires only the
specific binding, so C never sees the event. Migrated keys are now data-driven and
**remappable** (`remap_action_accel`); un-migrated keys still fall through to C
untouched.

The migration is deliberately incremental and *auditable*: an explicit
`migrated_action_ids` allowlist names exactly which keys the new layer owns. Batch
1 moved four provably-safe global commands (undo, redo, zoom in/out), each verified
by **observation** — press the key in the running GUI, measure the effect, compare
to the C branch — not by assertion. And the cheat-sheet is now **generated from
the table**, so the §2.1 drift is structurally impossible for migrated keys.

Crucially, the refactor also *mapped the minefield* §2.5 created. Reading all
1600 lines, we classified every key by what blocks its migration:

- **waves-guarded** keys (incl. `Ctrl+S` Save, `f`, the arrows) route to the graph
  subsystem on mouse-over — they encode layer [4] (input routing) inline, so they
  can't move until that layer exists;
- **modal** keys (`w`, `r`, `m`, …) drive layer [3] (the interaction state
  machine) — they can't move until *that* exists;
- **clean global commands** (undo, zoom, netlist, …) depend on none of the above —
  these are the ones safe to migrate now.

That classification *is* the roadmap: the keys that resist migration are precisely
the ones that name the missing layers.

---

## 6. What is left, and the realistic end state

The refactor has **not** (and should not yet) touched `handle_key_press` itself —
that's the point of intercepting above it. What remains is to keep widening the
allowlist and, eventually, to build the two layers the modal/waves keys are
waiting on:

1. **More batches of clean command keys** — straightforward, each a few lines of
   data + a verification, shrinking C's share of the keymap.
2. **An input-router layer [4]** so waves-guarded keys can migrate (decide
   graph-vs-schematic ownership once, before dispatch).
3. **An explicit interaction state machine [3]** so modal keys (`w`, `m`, drag,
   `Esc`) can move out of the global switch.

The end state is not "a prettier 1600-line function." It's a `handle_key_press`
that has *withered* — reduced to whatever genuinely low-level X-event plumbing
can't live in the UI layer — while the keymap, commands, modes, and routing live in
testable, data-driven layers. The strangler fig, fully grown, leaves a hollow trunk.

And the cost-of-change curve inverts. Today, "add a remappable shortcut with a
tooltip and a menu entry and an accurate help line" touches three files and a
1600-line C function. After the migration it's one row in a CSV — which is exactly
what Phase 1's 30-second quickstart already demonstrates for the part that's done.

---

## 7. The transferable lessons

1. **The shape of your control flow is an architectural choice.** `switch (input)`
   makes input the spine of the program; that decision, not any single line, is
   what made the function unmaintainable.
2. **Separate intent from input from state from routing.** A keystroke, a command,
   a modal interaction, and "which surface owns this event" are four concerns. When
   they braid, nothing is independently changeable or testable.
3. **A duplicated fact wants to be data.** "Ctrl+S saves" in three files is a bug
   in *representation*; represent it once and many features unlock at once.
4. **Count your guards.** 75 copies of the same reentrancy check is the
   architecture telling you reentrancy belongs at the entry point, not the leaves.
5. **Don't rewrite a working system — strangle it.** Grow the new structure
   around the old, route through it incrementally, verify by observation, and let
   the legacy shrink. Intercepting *above* the C function (Tk specificity) was
   worth more than any amount of rewriting *inside* it.
6. **The code that resists your refactor is a map.** The keys we *couldn't* move
   safely told us exactly which missing layers to build next.

---

## Appendix: where to look

| artifact | what it shows |
|---|---|
| `src/callback.c`, `handle_key_press` (~L2519–4118) | the function under study — read-only; the refactor never edits it |
| `src/actions.csv` | the command registry / keymap as data (layers [1]+[2]) |
| `src/action_registry.tcl` | generators: menus, palette, bindings, remap, cheat-sheet |
| `src/xschem.tcl`, `set_bindings` (~L9952) | where the generic `<KeyPress>` binding and the generated overrides coexist |
| `tests/headless/test_accelerators.tcl` | proves a migrated key == its old C branch, by observation |
| `claude_suggs/tutorial_action_registry.md` | Phase 1: the data layer + palette |
| `claude_suggs/tutorial_action_registry_phase2.md` | Phase 2: bindings-as-data via Tk specificity |
| `claude_suggs/refactor_plan_action_registry.md` | the risk-sequenced plan and status |
