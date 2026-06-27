# From a hardcoded `switch` to a binding table — a tutorial on separating *mechanism* from *policy*

This is a teaching write-up of a real change in XSCHEM: moving a handful of keyboard
shortcuts (`g`/`G` snap, `Ctrl-g` set-snap, `Alt-g` highlight, `%` grid) out of a giant
hand-written C `switch` and into a small data-driven *action registry*, so that **which key
does what** becomes configuration the user edits, not code we recompile.

The specific keys are not the point. The point is a pattern you will meet over and over —
in editors, games, shells, web routers, interrupt handlers, CLIs — and a *discipline* for
performing the change without breaking a working program. Read it for the ideas; the code is
just where they become concrete.

The one-sentence thesis, which the rest of the document unpacks:

> **Don't bake policy ("`g` halves the snap") into mechanism ("here is how a keypress is
> handled"). Put policy in *data*, give every behavior a *name*, and let an extra level of
> indirection map names to keys at run time.**

---

## 1. The starting point: behavior welded to keys

Here is the old code, abridged from `src/callback.c` (the `handle_key_press` switch):

```c
switch (key) {
  ...
  case 'g':
    if(rstate == ControlMask) {            /* set snap value */
      my_snprintf(str, S(str), "input_line {Enter snap value ...} {xschem set cadsnap} ...");
      tcleval(str);
    }
    else if(EQUAL_MODMASK) {               /* Alt-g: highlight net -> waveform viewer */
      ... 30 lines of sim-tool detection ...
      hilight_net(tool); redraw_hilights(0);
    }
    break;
  ...
  case '%':                                /* toggle draw grid */
    dr_gr = tclgetboolvar("draw_grid");
    tclsetvar("draw_grid", dr_gr ? "0" : "1");
    draw();
    break;
}
```

Read what this couples together. The **key** (`'g'`), the **modifier test** (`rstate ==
ControlMask`), and the **behavior** (open a dialog; toggle a variable; redraw) are all fused
into one place. The character literal `case 'g':` *is* the binding. There is no name for
"toggle the grid" — there is only "what `%` does."

This is the most natural way to write the first version of anything, and there is nothing
wrong with it at small scale. It becomes a problem as the program grows, for reasons worth
naming precisely.

---

## 2. Why hardcoding hurts — the costs, named

A *cost* is something a future change has to pay. Welding behavior to keys imposes four:

1. **No remapping without a recompile.** A user who wants `Ctrl-g` to toggle the grid (a
   reasonable Cadence-style preference) cannot have it. Their only recourse is to patch C and
   rebuild — which most users cannot and should not do. Policy that lives in compiled code is
   policy only the *compiler operator* controls.

2. **No introspection.** Ask the program "what does `g` do?" or "list every shortcut." It
   cannot answer, because the knowledge is scattered across a 1,600-line switch as control
   flow, not stored as data you can iterate. A help screen has to be written and maintained
   *by hand*, and it drifts from reality the day someone edits the switch and forgets the doc.

3. **Duplication.** The same five-line "if the mouse is over a waveform graph, forward this
   event to the graph" guard had been pasted into ~20 cases. Behavior welded in place cannot
   be factored, because there is no seam to factor *at*.

4. **One keystroke, one behavior, three doors.** A menu click, a key press, and a scripted
   command can all want to "toggle the grid," but each reaches it by a different code path.
   Welded-in behavior gets re-implemented per door instead of shared.

Costs 1 and 2 are the ones this change targets. Notice they are both consequences of the same
root fact: **the mapping from input to behavior exists only as code, never as data.**

---

## 3. The fix is one idea: a name and a level of indirection

> *"All problems in computer science can be solved by another level of indirection."*
> — David Wheeler's "Fundamental Theorem of Software Engineering."

We split the welded `case` into **two** independent tables, connected by a *name*:

**(a) The action catalog — *what can be done* (the verbs).** Each behavior gets a stable
string id and a function (C or Tcl). From `src/callback.c`:

```c
typedef struct { const char *id; action_fn fn; const char *tcl; const char *help; ... } ActionDef;

static ActionDef action_registry[] = {
  { "view.snap_half",        act_snap_half,   NULL, "Halve the snap factor" },
  { "view.toggle_draw_grid", NULL, "set draw_grid [expr {!$draw_grid}]; xschem redraw",
                                                "Toggle grid display" },
  { "hilight.send_to_waveform", act_highlight_send_waveform, NULL,
                                                "Highlight net and send to waveform viewer" },
  ...
};
```

An action is *backed by* either a C function (`fn`) or a Tcl snippet (`tcl`) — exactly one.
The Tcl-backed form is the payoff of giving behaviors names: trivial behaviors ("flip a
variable and redraw") need no throwaway C wrapper at all; they are one row of data.

**(b) The binding table — *which input triggers which action* (the policy).** From the same
file:

```c
typedef struct { int device, code, mods, ctx, idle_only; char action_id[64]; } InputBinding;
```

A binding says nothing about *behavior*. It is a pure association: *(this device, this code,
these modifiers, in this context) → this action id*. It is **mutable at run time**, and that
is the whole game.

The connector is the `id` string. The catalog owns the verbs; the binding table owns the
mapping; neither knows the other's internals. You can add a verb without touching any
binding, and rebind any chord without touching any verb. That decoupling is the entire
benefit — everything below is consequence.

---

## 4. Dispatch: how the two tables produce behavior, and why *order* matters

When a key arrives, the handler consults the table **first**, and only falls through to the
old switch if nothing matched (`handle_key_press`, `src/callback.c`):

```c
int kmods = (key < 0xff00) ? rstate : state;          /* normalize the modifier mask */
if(key_chord_has_binding(key, kmods) && !(busy && idle_only)) {
  ActionEvent ae = { DEV_KEY, key, kmods, ctx, ... };
  if(dispatch_input_action(&ae)) return;              /* a binding matched -> done */
}
switch (key) { ... }                                  /* legacy hardcoded fallback */
```

This **table-first, hardcoded-fallthrough** ordering is the migration's quiet hero. It lets
the new system and the old one *coexist*: a key that has been migrated is served by the
table and `return`s before the switch; a key that has not been migrated falls through and
behaves exactly as before. You can therefore move keys over **one at a time**, with the
program working at every step (see §6). Reverse the order — switch first, table second — and
a migrated key would still hit its dead `case`, and you could never tell whether the new path
worked. *Precedence is not a detail; it is what makes incremental migration possible.*

`dispatch_input_action` is the lookup: find the binding for the signature, find the action
for that binding's id, then run `fn` (C) or `eval` the `tcl`. Two small tables and a string
key — the same shape as a hash router in a web framework or a jump table in an interpreter.

---

## 5. The deeper move: configuration is *data*, not *defaults in code*

Here is the part most worth internalizing, because it is a philosophy, not a mechanism.

Once behaviors have names and bindings are data, the question "what is `g` bound to *by
default*?" stops being interesting. We removed the built-in defaults entirely. The five
operations now ship **unbound**, and the actual chords live in the user's config file
(`src/cadence_style_rc`), as data:

```tcl
# CTRL-G toggles grid visibility (active):
xschem bind key 103 ctrl canvas view.toggle_draw_grid

# Optional -- uncomment to give the others a key again:
# xschem bind key 103 0   canvas view.snap_half     ;# halve snap (old 'g')
# ...
```

Compare the two worldviews:

| | Defaults-in-code | Bindings-as-data |
|---|---|---|
| "what key does X?" | grep the C switch | `xschem bindings dump` |
| change it | edit C, recompile, redeploy to everyone | edit a text file you own |
| who decides policy | whoever builds the binary | each user, per machine |
| help screen | hand-written, drifts | *generated from the live table* |

The last row is a freebie that falls out for free: because the bindings are data, the
cheat-sheet can be *computed* from them and can never lie about what the keys do. Welded-in
behavior cannot offer that, by construction.

This is the same shift as: hardcoded SQL → config-driven queries; `if (user == "admin")` →
a roles table; compiled-in feature flags → a flags service. **Whenever a decision is likely
to differ per user, per deployment, or over time, push it out of code and into data the right
party can edit.** The corollary discipline: *the program ships the mechanism; the policy is
the user's to set.*

(There is a boundary worth stating, lest "everything becomes data" run away with you. The
action *catalog* stays in C — adding a brand-new verb is still a code change. Only the
*mapping* is data. Data-driving the thing that varies (the binding) while keeping the thing
that doesn't (the set of verbs) in code is the right cut. Indirection has a cost too; one
level bought us everything, a second would have bought confusion.)

---

## 6. How to perform the surgery without bleeding: RED-first, incremental, sabotaged

A working program is a patient on the table. The refactor above is correct *as a design*;
the *method* of getting there safely is a separate skill, and arguably the more valuable one
for a young engineer. Four rules carried this change.

**Rule 1 — characterize before you change.** Before touching behavior, write a test that
pins down what the code *currently does*, fire a real event, and assert the observable
result. We drive the actual C path the way a real keystroke does:

```tcl
# KeyPress event = 2; a letter keysym uses rstate (= state without Shift).
# ControlMask = 4. So this is a real Ctrl-G on the canvas:
xschem callback .drw 2 100 100 103 0 0 4
```

That one line is a *characterization test*: it does not ask "is this right?", it asks "does
it still do what it did?" Such tests are the safety net that lets you refactor aggressively.

**Rule 2 — RED first; let the test fail before you make it pass.** Each step began with a
check that *failed* against current code (RED), then the smallest change to make it pass
(GREEN). The scaffold `tests/headless/test_keybind_snap_grid.tcl` encodes the end state as
six checks (KB1..KB6) that were all RED at the start and went GREEN one phase at a time. A
test you have never seen fail is a test you do not know works.

**Rule 3 — keep one positive control.** Among the RED checks we kept one that *passed* from
the start: "bind `g`→snap_half, fire `g`, confirm the snap halves." Its job is to prove the
*test harness itself* drives the dispatcher. Without it, a wall of FAILs is ambiguous — is
the code wrong, or is the test not even reaching the code? The control disambiguates: the
other failures are real.

**Rule 4 — sabotage your own green.** A passing test only means something if it can fail.
After each GREEN we deliberately broke the change (e.g. misspelled an action id, or restored
a deleted `case`) and confirmed the test went RED again, then reverted. A green suite that
stays green when you smash the code is not testing the code — see
`doc/claude/suggestions/green_but_hollow_tests.md`.

The migration ran in phases, each its own commit, each independently green: register the
actions → remove the defaults → delete the dead `case`s → blank the now-stale menu labels.
Small, reversible, verified steps. The opposite — one big "rewrite the whole switch" commit —
is how working programs die.

---

## 7. War stories: four bugs, and the general lesson in each

The interesting education is in what went *wrong*. Each of these is a specific instance of a
general trap.

**(a) The migrated key fell into a modal trap.** In the RED phase, the scaffold bound
`Ctrl-G` to the not-yet-existing grid action; the bind failed, so firing `Ctrl-G` fell
through to the *still-present* hardcoded `case 'g'`, which opened a modal `input_line`
dialog — and headless, a modal with no human blocks forever. The test hung.
*General lesson:* during a coexistence migration, the **old path is still live** for anything
the new path doesn't claim. Guard your probes (we only fired the chord once the bind
succeeded) and never assume the half-migrated state is inert.

**(b) Two sources of truth for the "same" fact.** Removing the `g`/`G` defaults from the C
`init_input_bindings()` did *not* unbind them — because the shipped `keybindings.csv` is
replayed at startup and re-added them. The defaults existed in **two** places that had to
agree. *General lesson:* when a value is duplicated (a compiled default *and* a generated
config), a change to one is silently undone by the other until you fix both — and a test
should *diff the two* to catch the drift (ours does: "shipped csv == regenerated-from-builtins").
Single source of truth is a goal; when you can't have it, *guard the redundancy with a test.*

**(c) The keysym shifts under your fingers.** `Shift-g` does not arrive as "`g` + Shift" — X
delivers the keysym `G` (code 71). Bind the chord by the character it *actually emits*, not
the one you pressed. *General lesson:* input layers transform events (case-folding, compose
keys, IME, auto-repeat). The abstraction you bind against is whatever the layer *delivers*,
which is often not what the user physically did. Verify with the real event, not your mental
model. (The same trap bit a `Ctrl-Shift-2` binding elsewhere in this codebase.)

**(d) The orphaned local.** Deleting `case '%'` left `int dr_gr;` declared but unused — a
compiler warning, and a small landmine for the next reader. *General lesson:* dead code has
*roots*. When you remove a behavior, remove its now-unreachable supporting declarations,
helpers, includes, and comments too. The compiler will point at the variable; it won't point
at the stale doc.

---

## 8. The transferable kit (what to carry to your next program)

Strip away XSCHEM and here is what remains — a checklist you can apply anywhere:

- **Mechanism vs. policy.** Separate *how a thing is done* from *which thing is done when*.
  The first is code; the second wants to be data.
- **Name your verbs.** A behavior with a stable name can be bound, logged, listed, searched,
  and reached from multiple front-ends. An anonymous behavior welded to a trigger can do none
  of those. Naming is not bureaucracy; it is what makes a thing *referable*.
- **One level of indirection, deliberately placed.** A table from names→behaviors and a table
  from inputs→names. Resist a third level: indirection is a tool, not a lifestyle.
- **Configuration is data the right party edits.** Ship the mechanism; let policy live where
  the person who cares about it can change it without a build.
- **Generate the truth, don't transcribe it.** A help screen / cheat-sheet computed from the
  live table cannot drift. Anything you maintain by hand alongside code eventually lies.
- **Migrate incrementally under a coexistence rule** (here: table-first, fallthrough), so the
  program works at every commit.
- **Characterize → RED → positive control → sabotage.** The four-beat rhythm that lets you
  change working code and *know* you didn't break it.
- **When you delete a behavior, pull its roots.** Defaults, helpers, locals, docs, tests of
  the old behavior — all of it.

---

## 9. Exercises

1. **Add a verb.** Register a Tcl-backed action `view.toggle_crosshair` (flip `draw_crosshair`,
   then `xschem redraw`) in `action_registry[]`. Bind it to a free chord with `xschem bind`
   and confirm via `xschem bindings dump`. Notice you wrote *zero* dispatch code.
2. **Find the seam.** Grep `src/callback.c` for the repeated "over a waveform graph → forward
   to graph" guard. Sketch how naming that as a context (`ACTX_OVER_GRAPH`) let it be deleted
   from ~20 cases and expressed once in the table. (It already was — read how.)
3. **Break the single-source rule on purpose.** Add a row to `keybindings.csv` that the C
   builtins don't have, and run `tests/headless/test_bindings_file.tcl`. Watch the drift guard
   catch you. Now reason about what production incident that test prevents.
4. **Design question.** We data-drove the *binding* but kept the *catalog* in C. When would
   you data-drive the catalog too (let users define new actions from a script), and what new
   failure modes would that admit? (Hint: arbitrary code from a config file is a feature
   *and* an attack surface.)

---

*Companion reading in this repo: `doc/claude/specs/keybind_snap_grid_actions.md` (the spec),
`doc/claude/suggestions/plan_keybind_snap_grid_actions.md` (the phased plan),
`doc/claude/code_analysis/FAQ.md` Q17–Q18 (the user-facing view),
`doc/claude/suggestions/green_but_hollow_tests.md` (why a green suite can prove nothing),
and `objects_in_c_vs_cpp.md` (the same "C makes conventions you must keep by hand" theme).*
