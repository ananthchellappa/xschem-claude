# Tutorial: making keyboard shortcuts *data* — Phase 2 of the action registry

**Audience.** A developer who has skimmed the Phase 1 tutorial
(`tutorial_action_registry.md`) and wants to understand how we turned xschem's
keyboard shortcuts from hardcoded C into table-driven, remappable data — *without
touching the C engine*. You'll learn the one Tk trick that makes it safe, a
translation problem that looks trivial and isn't, and how we proved each migrated
key behaves identically to the code it replaced.

**What we built (one sentence).** We generate real keyboard bindings from the
same action table that already drives the menus and the command palette, so a
shortcut is now a row in a CSV — discoverable, remappable, and described by an
always-accurate generated cheat-sheet — while the C keysym handler stays
untouched and still owns every key we haven't migrated yet.

---

## 0. Where Phase 1 left off, and the one thing it couldn't do

Phase 1 made *actions* data: one table (`src/actions.csv`), generators that build
the File menu and a fuzzy command palette from it. But it stopped at a hard line:

> "Because binding keys is the C engine's job, and we promised not to touch it,
> the `accel` column here is **display only**."

So `Ctrl+S` in the table was just a label. Press the key and you hit a branch
deep in the **1596-line `handle_key_press`** C function (`callback.c`), not the
table. That's the gap Phase 2 closes: make the `accel` column *bind something*,
so shortcuts become customizable and the cheat-sheet can't drift — and do it
**still without editing C.**

The reason that's even possible is a single property of Tk's event model, which
Phase 1 already used once for the palette. Phase 2 is the systematic application
of that one trick.

---

## 1. The trick, restated: specificity beats generality

Every keypress in the drawing canvas is forwarded to C by one generic binding in
`set_bindings` (xschem.tcl):

```tcl
bind $topwin <KeyPress> "... xschem callback %W %T %x %y %N 0 0 %s"
```

`xschem callback` → `handle_key_press` in C. The rule we exploit:

> **For bindings on the same widget, a more *specific* event pattern wins over a
> more general one — and only the winner's script runs.**

`<KeyPress>` is the general "any key" pattern. `<Control-Key-z>` is specific (it
names a modifier and a keysym). So if we add:

```tcl
bind $topwin <Control-Key-z> "run_action {xschem zoom_out}; break"
```

then pressing Ctrl+Z fires *only* that binding. The generic `<KeyPress>` does not
run, `xschem callback` is never called, and **C never sees the event**. We
intercepted the key purely in Tcl, *above* the engine. Every other key still
falls through to C, unchanged.

That's the whole safety story: we migrate keys one at a time by adding specific
bindings; un-migrated keys keep hitting the generic binding and behave exactly as
before. Nothing in C changes — we verified `callback.c` is byte-for-byte
identical across the whole phase.

---

## 2. The deceptively hard part: translating "Ctrl+S" into a Tk pattern

The table stores accelerators as **display strings** meant for humans:
`Ctrl+S`, `Shift+Z`, `Alt-F`, `Ctrl+Shift+P`, or just `U`. Tk's `bind` wants
**event patterns**: `<Control-Key-s>`, `<Shift-Key-Z>`, `<Alt-Key-f>`,
`<Control-Shift-Key-P>`, `<Key-u>`. We need a translator. It looks like string
munging. It isn't — there are two traps.

### Trap 1: the keysym, not the display casing, decides the binding

Look at how C dispatches. It strips Shift, then `switch`es on the *character
keysym*:

```c
rstate = state & ~ShiftMask;   /* "don't use ShiftMask; the character is enough" */
switch (key) {
  case 'u': /* undo */            // plain u
  case 'U': /* redo */            // Shift+u  -> X delivers keysym 'U'
```

So **undo** is the keysym `u` (lowercase, no Shift) even though the table writes
its accel as `U`. **Redo** is the keysym `U` (uppercase), reached by *physically*
pressing Shift+u, and the table writes it `Shift+U`. The display letter case is
cosmetic; what must match is the keysym X actually delivers:

| Table accel | Physically | Keysym | Correct Tk pattern |
|---|---|---|---|
| `U`        | press u        | `u` | `<Key-u>` |
| `Shift+U`  | press Shift+u  | `U` | `<Shift-Key-U>` |
| `Shift+Z`  | press Shift+z  | `Z` | `<Shift-Key-Z>` |
| `Ctrl+Z`   | press Ctrl+z   | `z` | `<Control-Key-z>` |
| `Ctrl+Shift+S` | press Ctrl+Shift+s | `S` | `<Control-Shift-Key-S>` |

The rule that falls out:

- **letter with no Shift → lowercase keysym** (`"U"` → `<Key-u>`);
- **letter with Shift → uppercase keysym** (`"Shift+U"` → `<Shift-Key-U>`).

This is exactly why the proven Phase 1 palette binding is
`<Control-Shift-Key-P>` — uppercase `P`, because Shift is held. We just
generalized it.

> **Teaching point.** Don't translate the *label*; translate to what the
> *hardware+X* will actually report. The label is for the user; the binding must
> match the event. When they disagree (`Alt-F` is really Alt+`f`), trust the
> event.

### Trap 2: not every "accelerator" is a single key

The table is honest about reality, and reality is messy. Some `accel` cells
aren't a keyboard shortcut at all:

- `"Ins, Shift-I"` — two *alternative* keys, comma-separated.
- `"Alt-Right Butt."` — a mouse chord.
- `"Print Scrn"` — a key we don't (yet) handle.
- `"#"`, `"="`, `"*"`, `"&"`, `"!"` — symbol keys needing keysym *names*
  (`numbersign`, `equal`, …), deferred to a later batch.

The translator must *recognize and refuse* these, not guess. It returns the empty
string for anything it can't faithfully bind, and the caller logs it and leaves
the key to C. Refusing safely is a feature.

### The translator

`accel_to_tk_sequence` (in `src/action_registry.tcl`) is the whole rule set:

```tcl
proc accel_to_tk_sequence {accel} {
  if {$accel eq {}} { return {} }
  if {[string match *,* $accel]}     { return {} } ;# "Ins, Shift-I"
  if {[string match *Butt.* $accel]} { return {} } ;# mouse button
  if {[string match *Scrn* $accel]}  { return {} } ;# "Print Scrn"
  if {[string match {* *} $accel]}   { return {} } ;# any space => multi-word

  set tokens {}
  foreach t [split [string map {+ -} $accel] -] { if {$t ne {}} { lappend tokens $t } }
  set keytok  [lindex $tokens end]
  set modtoks [lrange $tokens 0 end-1]

  set mods {}; set shift 0
  foreach m $modtoks {
    switch -- $m {
      Ctrl - Control { lappend mods Control }
      Alt            { lappend mods Alt }
      Shift          { set shift 1 }
      default        { return {} }      ;# unknown modifier -> leave to C
    }
  }

  if {[string length $keytok] == 1 && [string is alpha $keytok]} {
    set keysym [expr {$shift ? [string toupper $keytok] : [string tolower $keytok]}]
  } elseif {[string length $keytok] == 1 && [string is digit $keytok]} {
    set keysym $keytok
    if {$shift} { lappend mods Shift }
  } else {
    return {}                           ;# symbol/named keys: deferred
  }

  set seq {}
  if {"Control" in $mods} { lappend seq Control }
  if {"Alt" in $mods}     { lappend seq Alt }
  if {$shift && [string is alpha $keytok]} { lappend seq Shift }
  lappend seq Key $keysym
  return "<[join $seq -]>"
}
```

We unit-tested it in isolation (pure `tclsh`, no xschem) against every case
above. *Lesson: a pure function with a fiddly spec deserves a table-driven test
you can run in a millisecond.*

---

## 3. The generator, and why it's an allowlist

`bind_accelerators_from_table` walks the table and installs the bindings — but
**only for action ids on an explicit allowlist**, `migrated_action_ids`:

```tcl
set migrated_action_ids { edit.undo edit.redo view.zoom_in view.zoom_out }

proc bind_accelerators_from_table {topwin} {
  global action_table migrated_action_ids accel_bound_seqs
  # release anything we bound before (so re-runs / remaps don't leave stale keys)
  if {[info exists accel_bound_seqs($topwin)]} {
    foreach seq $accel_bound_seqs($topwin) { bind $topwin $seq {} }
  }
  set accel_bound_seqs($topwin) {}
  foreach row $action_table {
    if {[dict get $row id] ni $migrated_action_ids} continue
    set seq [accel_to_tk_sequence [dict get $row accel]]
    if {$seq eq {}} { puts stderr "...'$id' not translatable; left to C"; continue }
    bind $topwin $seq "run_action [list [dict get $row command]]; break"
    lappend accel_bound_seqs($topwin) $seq
  }
}
```

Why gate on an allowlist instead of binding every translatable row? Because most
keys are **not** safe to migrate yet (Section 5), and "behavior-preserving" means
moving them in small, verified batches. The allowlist makes the migration
*explicit and auditable*: the set of keys C no longer owns is exactly this list,
and it grows one reviewed batch at a time. Everything else is untouched by
construction.

Wiring is one line in `set_bindings`, right after the palette binding:

```tcl
bind $topwin <Control-Shift-Key-P> "command_palette $parent; break"
bind_accelerators_from_table $topwin          ;# <-- the generated accelerators
bind $topwin <KeyRelease> "xschem callback ..."
```

`run_action` is a tiny safety wrapper that runs the command at global scope and
*reports* errors instead of letting a bad binding kill the event loop — the same
pattern the palette's runner uses.

---

## 4. "Data-driven" has to mean *remappable*, or it's just a fancy constant

It's easy to generate bindings once at startup and call it data-driven. The real
test: **change the data, and does the live binding follow?** Two design choices
make it real.

First, notice the generator above *releases its previous bindings* before
re-installing. That single `foreach ... bind $topwin $seq {}` is what lets a
remap move a key instead of accumulating a stale one. (Tutorials usually skip
this; it's the difference between "regenerate" and "leak.")

Second, a thin runtime API:

```tcl
proc remap_action_accel {id new_accel {topwin .drw}} {
  # patch the row's accel in the in-memory action_table, then re-install
  ...
  bind_accelerators_from_table $topwin
  return [accel_to_tk_sequence $new_accel]
}
```

This is the programmatic core a future "Customize shortcuts" dialog would call.
We proved it end-to-end in a test: remap `view.zoom_in` from `Shift+Z` to
`Ctrl+Shift+Z`, then assert that

- the **old** key `<Shift-Key-Z>` is now unbound (reverts to C),
- the **new** key `<Control-Shift-Key-Z>` carries `xschem zoom_in`, and
- pressing it actually zooms in,

then restore the default. Seven assertions, all green.

> **Teaching point.** "Data-driven" is a claim about *change*, not about *origin*.
> If editing the table doesn't move the behavior, you built a generator, not a
> configuration system. Test the change, not just the initial state.

---

## 5. Which keys are safe to migrate — reading `handle_key_press` like a map

Before binding anything we read all 1596 lines of `handle_key_press` and split
its keys into "safe to migrate" vs "must stay in C." Three patterns disqualify a
key — and they're easy to miss:

1. **Waves-guarded keys.** Many handlers begin with
   `if (waves_selected(...)) { waves_callback(...); break; }` — i.e. *if the
   mouse is over a waveform graph, do the graph thing instead.* This catches keys
   you'd never suspect: **`Ctrl+S` (Save!)**, `f` (zoom full), `a`, `m`, and the
   **arrow keys** all route to the graph subsystem on mouse-over. Migrate one of
   these to an unconditional `xschem save` and you silently break graph
   interaction. These stay in C.

2. **Modal / infix placement & move-start.** Keys like `w` (wire), `r` (rect),
   `c` (copy), `m` (move) branch on `infix_interface` and kick off an in-progress
   operation tracked in `xctx->ui_state`. They aren't self-contained commands;
   they're the front edge of a stateful interaction. Stay in C.

3. **Depends on in-progress edit state.** `h`/`v` (constrained drag during a
   wire/line), `F`/`V` (flip *while moving*), `Esc` (abort), `Delete` (delete
   selection) all read `STARTMOVE`/`STARTWIRE`/… Stay in C.

What's left — and what Phase 2 batch 1 migrated — are **clean global command
keys**: no waves check, no modal state, a single self-contained action whose
table command we verified calls the *same* C function.

| Key | C does | Table command |
|---|---|---|
| `u` | `pop_undo(0,1); draw()` | `xschem undo; xschem redraw` |
| `Shift+U` | `pop_undo(1,1); draw()` | `xschem redo; xschem redraw` |
| `Shift+Z` | `view_zoom(0.0)` | `xschem zoom_in` |
| `Ctrl+Z` | `view_unzoom(0.0)` | `xschem zoom_out` |

We confirmed each table command lands on the same C primitive by reading the
`xschem` dispatcher (`scheduler.c`): `zoom_in` → `view_zoom(0.0)`, `zoom_out` →
`view_unzoom(0.0)`, `undo`/`redo` → `pop_undo(0,1)`/`pop_undo(1,1)`. Identical.

---

## 6. Proving "same behavior" with observation, not assertion

"The binding runs the same action C did" is a claim. We made it evidence by
*pressing the key in the running GUI and measuring*, then comparing against the
direct command. Two observables did the job:

**Zoom** — `view_zoom`/`view_unzoom` multiply the `zoom` value by a fixed factor
per call, and there's no `xschem set zoom` to reset between trials. So we compared
*consecutive ratios*: press the key (ratio A), then run the command (ratio B), and
assert `A == B` and that it moved in the right direction.

```tcl
set z0 [xschem get zoom]
event generate .drw <Shift-Key-Z> ; set z1 [xschem get zoom]   ;# the KEY
xschem zoom_in                    ; set z2 [xschem get zoom]   ;# the COMMAND
# r_key = z1/z0 ; r_cmd = z2/z1 ; assert r_key < 1 and r_key ≈ r_cmd
```

**Undo/redo** — create a wire, count, drive undo+redo from the keyboard, recount:

```tcl
set n0 [xschem get wires]
xschem wire 0 0 1000 0                        ;# n0+1
event generate .drw <Key-u>        ; # undo  -> back to n0
event generate .drw <Shift-Key-U>  ; # redo  -> n0+1 again
```

And a negative control that proves we *didn't* migrate too much: the un-migrated
keys `f`, `s`, `w` must have **no** specific binding, so they still reach C:

```tcl
check "unmigrated <Key-f> left to C" [expr {[bind .drw <Key-f>] eq {}}]
```

Twelve assertions, all green, in `tests/headless/test_accelerators.tcl`. Run them
the same way as every other GUI smoke (note the `--pipe`, without which `puts`
output is swallowed):

```sh
DISPLAY=:0 ./src/xschem --pipe --script tests/headless/test_accelerators.tcl
```

> **Teaching point.** For a behavior-preserving change, the convincing test isn't
> "the new path returns X." It's "the new path and the old path produce the same
> observable, and the things I *didn't* touch still aren't touched." Test the
> migration *and* its boundary.

---

## 7. The cheat-sheet that can't lie

The old keyboard reference, `keys.help`, was hand-maintained prose — exactly the
kind of duplicated fact that drifts. Since the bindings now come from the table,
we generate the cheat-sheet from the *same* table, so the two literally cannot
disagree for migrated keys:

```tcl
proc generate_keybindings_text {} {
  # group command rows that have an accel by menu, in table order;
  # flag rows in migrated_action_ids with '*'
}
```

`show_keybindings_help` displays it read-only (via the existing `viewdata`), wired
into **Help → "Keybindings (from table)"** and discoverable in the palette. The
`*` marks which keys are now data-driven (and therefore remappable) versus still
handled by the core — so the document tells you not just the binding, but *who
owns it*. A test asserts exactly the four migrated keys are starred, an
un-migrated one is present-but-unstarred, and the sheet follows a runtime remap.

*Lesson: once a fact is data, every view of it (menu, palette, bindings,
cheat-sheet) should be a projection of that data. A generated document is a
projection; a hand-written one is a copy waiting to rot.*

---

## 8. How we kept it safe — the loop, again

Identical discipline to Phase 1: **small change → run → prove → commit**, with
four independent checks after every batch:

1. **Engine unchanged** — `tests/headless/run.sh` netlists and diffs golden
   output; 6/6 PASS throughout. Our changes are Tcl-only, so a green engine
   harness is strong evidence we disturbed nothing in C.
2. **`callback.c` untouched** — literally `git diff` shows zero lines. The whole
   "no C changes" promise is checkable, so we check it.
3. **The migrated keys behave like C** — `test_accelerators.tcl` (12/12).
4. **Remap + cheat-sheet are real** — `test_remap.tcl` (7/7),
   `test_keybindings_help.tcl` (6/6).

Each batch is one commit. We can stop forever at batch 1 and everything works; or
add `migrated_action_ids` entries next week. Reversible and incremental, by
construction.

---

## 9. What we deliberately did *not* do

- **Migrate waves-guarded, modal, or stateful keys.** They depend on runtime
  context (mouse-over-graph, in-progress operation) that a flat command string
  can't capture. They stay in C until/unless we model that context.
- **Touch `callback.c`.** The keys we migrated are intercepted *above* it; the
  rest are owned by it. Both states are fine simultaneously.
- **Handle symbol keys (`# = * & !`).** They need a keysym-name map; the
  translator refuses them for now and logs, rather than mis-binding.
- **Build the customize-shortcuts UI.** We built and tested its *engine*
  (`remap_action_accel`); the dialog is a later, cheap addition.

---

## 10. The transferable lessons

1. **Find the clean interception layer.** Tk binding specificity let us override
   keys *above* a 1596-line C function we never opened. Knowing where a safe seam
   is often separates a one-day change from a one-month one.
2. **Translate to the event, not the label.** The keysym the hardware delivers —
   not the human-readable accelerator — is what a binding must match.
3. **Refuse what you can't represent.** A translator that returns "I can't bind
   this" for mouse chords and multi-key accels is safer than one that guesses.
4. **Gate risky migrations behind an explicit allowlist.** It makes "what changed
   ownership" auditable and the rollback trivial.
5. **Data-driven means the data can change.** Release-and-rebind, plus a remap
   test, is the difference between configuration and a constant.
6. **Prove behavior-preservation by observation and by boundary.** Same
   observable on both paths, *and* the un-migrated neighbors still untouched.
7. **Generate every view of a fact.** Bindings and cheat-sheet from one table
   can't drift; a hand-written reference always will.

---

## Appendix: the files

| file | role |
|---|---|
| `src/actions.csv` | the action table; `accel` is now the binding source of truth for migrated rows |
| `src/action_registry.tcl` | `accel_to_tk_sequence`, `bind_accelerators_from_table`, `run_action`, `remap_action_accel`, `migrated_action_ids`, `generate_keybindings_text`, `show_keybindings_help` |
| `src/xschem.tcl` | calls `bind_accelerators_from_table` in `set_bindings`; Help → "Keybindings (from table)" |
| `src/callback.c` | **unchanged** — still owns every un-migrated key (read-only reference for the migration) |
| `tests/headless/test_accelerators.tcl` | each migrated key == its C action; un-migrated keys still reach C |
| `tests/headless/test_remap.tcl` | remapping moves the live binding end-to-end |
| `tests/headless/test_keybindings_help.tcl` | the generated cheat-sheet matches the table and follows remaps |
| `doc/claude/suggestions/refactor_plan_action_registry.md` | the plan + Phase 2 status |
| `doc/claude/suggestions/tutorial_action_registry.md` | Phase 1 tutorial (menus + palette) — read first |
