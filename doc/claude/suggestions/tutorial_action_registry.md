# Tutorial: turning xschem's menus into data — an action registry + command palette

**Audience.** A developer who knows a little Tcl and wants to understand *both*
what we changed in xschem and the reusable technique behind it. You don't need
to have read the C engine. By the end you should be able to add a menu item, a
palette entry, or a whole new generated menu without touching C — and explain
why that's safe.

**What we built (one sentence).** We made user actions *data* — one table in a
CSV — and wrote small Tcl "generators" that build the File menu and a
fuzzy-search command palette from that table, without changing the C engine.

---

## Quickstart: add a new action in 30 seconds

You don't need to read the rest of this doc to add an action. Edit one CSV file.

**Add a palette-searchable action.** Append a row to `src/actions.csv`. Columns
are `id,type,menu,label,accel,command,submenu,hook,help`:

```csv
mytools.rebuild_conn,command,mytools,Rebuild connectivity,,xschem rebuild_connectivity,,,Recompute net connectivity
```

- Pick a unique `id` (`<menu>.<slug>` by convention).
- `type` is `command`. `menu` can be any tag — if it isn't a *generated* menu
  (currently only `file` is), the row is **palette-only**: searchable via
  Ctrl+Shift+P but not shown in a menu bar. That's the easy, low-risk case.
- `command` is the Tcl/`xschem` string to run. Leave `accel`, `submenu`, `hook`
  empty. `help` is the one-line description the palette also searches.

Restart xschem (the table loads at startup) and press **Ctrl+Shift+P** → type a
few letters of the label. Done.

**Make it appear in the File menu too.** Set `menu` to `file` and put the row in
the File block of `actions.csv` in the position you want it. It now renders in the
menu *and* the palette — no Tcl code to write.

**If the command is more than one clean call** (a multi-line `if`, embedded
quotes, `$`-substitution): write a proc and name it in the `command` cell — keep
the data simple. See §4a.

```tcl
# in src/action_registry.tcl
proc action_rebuild_conn {} {
  if {[alert_ "Rebuild net connectivity?" {} 0 1] == 1} { xschem rebuild_connectivity }
}
```
```csv
mytools.rebuild_conn,command,mytools,Rebuild connectivity,,action_rebuild_conn,,,Recompute net connectivity
```

**Verify you didn't break anything:** `cd tests/headless && ./run.sh` (should stay
6/6 PASS — the engine is untouched). Quoting note: if any field contains a comma,
wrap it in double quotes, e.g. `"Shift-Ins, Ctrl-I"`.

That's the whole workflow. The sections below explain *why* it works this way.

---

## 1. The problem: actions were scattered, not described

Before this work, a single user action like "Save" existed in **three**
hand-maintained places that had to be kept in sync by hand:

1. A menu item in `build_widgets` (xschem.tcl): `... add command -label "Save"
   -command "xschem save" -accelerator {Ctrl+S}`.
2. A branch in the **1596-line** C keysym chain (`handle_key_press` in
   `callback.c`) that maps the Ctrl+S keypress to the save action.
3. A line in `keys.help`, a prose cheat-sheet that drifts out of date.

Notice the consequence: the `-accelerator {Ctrl+S}` in the menu is **decorative**
— it's just a label. The *real* key handling is the C branch. Nothing connects
them, so they can disagree, and they do.

This is why "improve the UX" was expensive. Every discoverability feature you
might want — a command palette, customizable shortcuts, a toolbar, tooltips,
context menus, an accurate cheat-sheet — needs the same thing first: **a single
list of what the actions are.** That list didn't exist. So we built it.

> **The teaching point.** When the same fact is written in N places, the bug
> isn't in any one place — it's that the fact isn't *represented* anywhere as
> data. The highest-leverage refactor is usually "make the implicit thing
> explicit," because it unblocks many features at once instead of one.

---

## 2. The big idea: actions as data + generators

```
                         ┌────────────────────┐
                         │   actions.csv      │   ← single source of truth
                         │  (the action table)│
                         └─────────┬──────────┘
                                   │ read once at startup
                 ┌─────────────────┼──────────────────┐
                 ▼                 ▼                  ▼
        build_menu_from_table   command_palette   (future: cheat-sheet,
        (renders the File menu) (fuzzy launcher)   toolbar, remappable keys)
```

Instead of hand-writing each menu item, we **describe** each action once in a
table, then write generators that *read* the table and produce the UI. Add a
row → it shows up everywhere the generators run. That's the whole pattern.

Crucially, this lives entirely in the **Tcl UI layer**. The C engine and the
`handle_key_press` keysym chain are never touched. (Section 6 shows the one
clever trick that let us add a keyboard shortcut without C.)

---

## 3. The schema: one row per action, and *why* each column

The table is `src/actions.csv`. Each row is one action. The columns:

| column | purpose | example |
|---|---|---|
| `id` | stable key for palette / future remapping | `file.save` |
| `type` | `command` \| `separator` \| `cascade` \| `dynamic` | `command` |
| `menu` | which menu it belongs to (a widget-path key) | `file`, `file.im_exp` |
| `label` | the text shown in menu/palette | `Save as symbol` |
| `accel` | accelerator **display** string (not bound here) | `Ctrl+Shift+S` |
| `command` | the Tcl command string to run | `xschem save` |
| `submenu` | child menu key (for `cascade`) | `file.im_exp` |
| `hook` | proc that fills a `dynamic` submenu | `setup_recent_menu` |
| `help` | one-line description (palette + future cheat-sheet) | `Save the current cell` |

Two design decisions worth dwelling on:

**Why a `type` column?** The plan's first sketch was just `{label, command}`.
But a real menu isn't a flat list of commands — it has **separators**, **static
submenus** (Image export → EPS/PDF/PNG/…), and **dynamic submenus** (Open recent,
whose contents depend on runtime state). A table that can only express
"commands" can't reproduce the File menu. `type` is the discriminator that lets
one table describe all four shapes. *Lesson: model the data after the real thing,
not the happy path.*

**Why is `accel` "display only"?** Because binding keys is the C engine's job,
and we promised not to touch it. The accelerator string here does exactly what
it did before — show the user which key to press. The key itself is still handled
in `callback.c`. This keeps the change behavior-preserving. (Wiring shortcuts
*through* the table is a later phase.)

A few example rows (note the quoted field — RFC4180 CSV quotes any value that
contains a comma):

```csv
id,type,menu,label,accel,command,submenu,hook,help
file.save,command,file,Save,Ctrl+S,xschem save,,,Save the current schematic or symbol
file.component_browser,command,file,Component browser,"Shift-Ins, Ctrl-I",action_component_browser,,,Browse and insert a symbol
file.open_recent,dynamic,file,Open recent,,,file.recent,setup_recent_menu,List of recently opened files
file.image_export,cascade,file,Image export,,,file.im_exp,,Export the drawing as an image
file.sep1,separator,file,,,,,,
```

---

## 4. Generating the File menu

The generator lives in `src/action_registry.tcl`. The core is
`build_menu_from_table`, which walks the table and emits Tk menu commands:

```tcl
proc build_menu_from_table {topwin menukey} {
  global action_table
  set m $topwin.menubar.$menukey
  foreach row $action_table {
    if {[dict get $row menu] ne $menukey} continue   ;# only this menu's rows
    set type  [dict get $row type]
    set label [dict get $row label]
    set accel [dict get $row accel]
    switch -- $type {
      separator { $m add separator }
      command {
        set opts [list -label $label -command [dict get $row command]]
        if {$accel ne {}} { lappend opts -accelerator $accel }
        $m add command {*}$opts
      }
      cascade - dynamic {
        set sub  [dict get $row submenu]
        set subw $topwin.menubar.$sub
        if {![winfo exists $subw]} { menu $subw -tearoff 0 -takefocus 0 }
        $m add cascade -label $label -menu $subw
        if {$type eq {cascade}} {
          build_menu_from_table $topwin $sub          ;# recurse into children
        } else {
          set hook [dict get $row hook]
          if {$hook ne {}} { $hook $topwin }           ;# delegate dynamic fill
        }
      }
    }
  }
}
```

Read that `switch` as the four shapes from Section 3:

- **command** → one `add command`. The `{*}` is list expansion: we build the
  option list (adding `-accelerator` only when present) and splat it.
- **cascade** → create the submenu widget, add the cascade entry, then **recurse**
  to fill the submenu from rows whose `menu` is the child key. That's how
  "Image export" and its six children come from flat rows in one table.
- **dynamic** → same, but instead of recursing we call a **hook** proc
  (`setup_recent_menu`) that fills the submenu at runtime. Recent-files content
  isn't static data, so the table stores *how to fill it*, not the contents.
- **separator** → trivial.

Wiring it into xschem.tcl was two edits:

```tcl
# once, at startup (global scope), after XSCHEM_SHAREDIR is set by the C side:
source $XSCHEM_SHAREDIR/action_registry.tcl
load_action_table

# inside build_widgets, replacing ~68 lines of hand-written menu items:
build_menu_from_table $topwin file
```

### 4a. The "clean command" trick: extract inline scripts to procs

Most File items were already clean one-liners (`xschem save`). But two were
multi-line inline scripts, e.g. Reload:

```tcl
-command {
  if {[alert_ "Are you sure you want to reload?" {} 0 1] == 1} { xschem reload }
}
```

You *can't* cleanly put a multi-line `if` block into a CSV `command` cell. So we
**promoted each inline script to a named proc** and put the proc name in the
table:

```tcl
proc action_reload {} {
  if {[alert_ "Are you sure you want to reload?" {} 0 1] == 1} { xschem reload }
}
```
```csv
file.reload,command,file,Reload,Alt+S,action_reload,,,Reload the current file from disk
```

Now every `command` cell is a single clean call. *Lesson: keep your data simple
by pushing complexity into code the data can name.*

### 4b. Parsing CSV correctly (don't `split` on commas)

One field — `"Shift-Ins, Ctrl-I"` — contains a comma. A naive `split $line ,`
would shred it. We wrote a small RFC4180-style parser that respects quotes and
doubled-quote (`""`) escapes:

```tcl
proc action_parse_csv_line {line} {
  set fields {}; set field {}; set inq 0
  set n [string length $line]
  for {set i 0} {$i < $n} {incr i} {
    set c [string index $line $i]
    if {$inq} {
      if {$c eq "\""} {
        if {[string index $line [expr {$i+1}]] eq "\""} { append field "\""; incr i } \
        else { set inq 0 }
      } else { append field $c }
    } else {
      if {$c eq "\""} { set inq 1 } \
      elseif {$c eq ","} { lappend fields $field; set field {} } \
      else { append field $c }
    }
  }
  lappend fields $field
  return $fields
}
```

*Lesson: the moment your data format has a quoting rule, hand-rolled `split`
becomes a bug. Spend the 15 lines on a real parser.*

---

## 5. The command palette — the headline UX win

The palette (open with **Ctrl+Shift+P** or **Help → Command palette**) is a tiny
dialog: a text entry on top, a listbox below. You type; it fuzzy-filters every
`command` row in the table; Enter runs the highlighted action.

The single most important decision here was **reuse, not build**. xschem already
had a fuzzy subsequence matcher, `fuzzy_subseq_score`, used by the file chooser.
It scores how well a short query matches a string, rewarding consecutive
characters and word-boundary hits. We just called it:

```tcl
set sc [fuzzy_subseq_score $q [dict get $row label]]
foreach field {help id} {
  set s [fuzzy_subseq_score $q [dict get $row $field]]
  if {$s > $sc} { set sc $s }                 ;# best of label / help / id
}
if {$sc >= 0} { lappend scored [list $sc $row] }
```

So typing `zoom` ranks Zoom Full / Zoom In / Zoom Out to the top; `export` finds
the EPS/PDF/PNG/SVG actions. Because the palette reads the *table*, every action
we add to the table is automatically discoverable — that's the payoff of Section 2.

One small but instructive bug we designed around: arrow-key navigation. The entry
re-filters on `<KeyRelease>`, but pressing ↓ also fires `<KeyRelease>`, which
would rebuild the list and snap the selection back to the top. The fix is a guard
that skips re-filtering when the query text hasn't actually changed:

```tcl
if {[info exists palette_last_query] && $palette_last_query eq $palette_query} return
set palette_last_query $palette_query
```

---

## 6. The clever bit: a keyboard shortcut **without** touching C

Here's the puzzle. Every keypress in the drawing window is forwarded to the C
engine by this binding in `set_bindings` (xschem.tcl):

```tcl
bind $topwin <KeyPress> "... xschem callback %W %T %x %y %N 0 0 %s"
```

`xschem callback` calls into `handle_key_press` in C. So how do we make
Ctrl+Shift+P open the palette *without* adding a branch to that C function (which
we promised not to touch)?

The answer is a property of Tk's event model: **for bindings on the same widget,
a more *specific* event pattern wins over a more general one.** `<KeyPress>` is
the general "any key" pattern. `<Control-Shift-Key-P>` is specific. So we add:

```tcl
bind $topwin <Control-Shift-Key-P> "command_palette $parent; break"
```

When you press Ctrl+Shift+P, Tk fires *only* the specific binding — the generic
`<KeyPress>` binding does **not** run, so `xschem callback` is never called, so
the C keysym chain never even sees the event. We intercepted the key purely in
Tcl. The `break` stops further propagation for good measure.

> **Teaching point.** This is the seam that makes the whole "UI-layer only"
> promise real. We didn't have to modify, recompile, or even read the 1596-line
> C function. We slipped in *above* it, at the Tk binding layer, using
> specificity. Knowing where a clean interception point exists is often what
> separates a risky change from a safe one.

Two gotchas worth remembering:
- Use the canonical form `<Control-Shift-Key-P>`. The shorthand `<Control-Shift-P>`
  does **not** fire (we tested both).
- When the user is typing in the canvas (the normal case) the binding works; a
  synthetic `event generate` won't trigger it unless the widget has focus — which
  cost us a confusing minute during testing until we added `focus -force`.

---

## 7. Scaling the table from 25 to 131 actions, reproducibly

The File menu has ~25 actions. A palette of only 25 isn't "the fix for
discoverability." We already had an inventory of all 221 menu items
(`doc/claude/code_analysis/menu_inventory/menu_items.csv`), so we **imported** the clean,
single-call commands from the other menus as *palette-only* rows.

"Palette-only" falls out for free: those rows keep their real menu name
(`edit`, `view`, …), but `build_menu_from_table` only runs for `file`, so they're
never rendered as menus — yet `command_palette` iterates *all* command rows, so
they're searchable. When we later generate the Edit menu, the rows are already
there. Forward-compatible by construction.

We were deliberately conservative about *which* commands to import. A command
like `input_line "Enter..." "set var"` has embedded quotes and `$`-substitution
that won't round-trip cleanly through CSV → `uplevel`. So the generator
(`doc/claude/code_analysis/menu_inventory/gen_actions.tcl`) skips anything with
`{ } [ ] " \ $`, keeping only 106 high-confidence rows and **logging** what it
skipped rather than silently dropping it.

The generator is **idempotent**, and that property caught a real bug. First
version read *all* existing ids to avoid collisions — but after we appended its
output to `actions.csv`, re-running saw `edit.undo` already present and produced
`edit.undo_2`, etc. The fix: only read ids from the *curated* part of the file,
stopping at the auto-generated marker comment:

```tcl
if {[string match {# --- imported from menu inventory*} $line]} break
```

Now re-running reproduces the in-file block byte-for-byte. *Lesson: a generator
you can re-run and diff against its own output is one you can trust; make
idempotency a tested property, not a hope.*

---

## 8. How we kept it safe — the verification loop

Every step followed the same loop: **small change → build/run → prove nothing
broke → commit.** Three independent checks:

1. **Engine unchanged** — `tests/headless/run.sh` netlists a set of schematics
   and diffs against golden output. It ran green (6/6) after *every* commit.
   Because our changes are Tcl-only and the harness exercises the C engine, a
   green harness is strong evidence we didn't disturb the engine. (It also
   sources `xschem.tcl` at startup, so it doubles as a "does actions.csv parse?"
   check.)

2. **File menu identical** — `tests/headless/dump_file_menu.tcl` introspects the
   *generated* menu (every entry's type/label/accelerator, including submenus)
   and compares it to the known-good pre-refactor structure. Result: **28/28
   entries match.** This is how we proved "behavior-preserving" instead of just
   claiming it.

3. **Palette works** — `tests/headless/test_palette.tcl` checks the keybinding is
   installed, that `save` fuzzy-matches Save / Save as / Save as symbol, and that
   the key event actually opens the dialog.

A subtlety we learned: to capture a script's `stdout`, you must run the binary
with `--pipe`:

```sh
DISPLAY=:0 ./src/xschem --pipe --script tests/headless/dump_file_menu.tcl
```

Without `--pipe`, `puts` output is swallowed and event-loop timers (`after`)
don't fire before the process exits — which made our first introspection runs
look mysteriously empty.

> **Teaching point.** "I didn't touch the engine" is a claim; "the harness is
> green and the menu diffs identical" is evidence. For a behavior-preserving
> refactor, build the evidence *before* you need to defend the change.

---

## 9. What we deliberately did *not* do (and why)

- **Migrate the C keysym chain.** Out of scope and high-risk. The shortcuts still
  work exactly as before because C still owns them. The table's `accel` column is
  ready for the day we migrate them, but that's a later, opt-in phase.
- **Import the gnarly commands.** The 22 inline-script menu items and the 46
  checkbutton / 15 radiobutton toggles need named-proc extraction or a new
  `toggle` row type first. Forcing them into a `command` cell now would be fragile.
- **Convert the other menus' rendering.** We proved the pattern on *one* menu
  (File). The rest stay hand-written until we choose to migrate them — the table
  and hand-written menus coexist happily.

*Lesson: a good refactor is reversible and incremental. We can stop here forever
and everything works; or migrate one more menu next week. Nothing is all-or-nothing.*

---

## 10. The transferable lessons

1. **Find the duplicated fact.** When one truth is hand-copied into several
   places, representing it as data once unblocks many features at the same time.
2. **Model the real shape.** A `type` discriminator beat a too-simple
   `{label, command}` because menus really do have separators and submenus.
3. **Keep data simple by naming code.** Inline scripts became procs so every
   data cell stays a clean call.
4. **Reuse the matcher you already have.** The palette was cheap because
   `fuzzy_subseq_score` already existed.
5. **Intercept at the right layer.** Tk binding specificity let us add a shortcut
   *above* the C engine instead of inside it — the key to the "no C changes"
   guarantee.
6. **Make generators idempotent and test it.** Re-run + diff is what makes a
   code-generator trustworthy.
7. **Prove behavior-preservation with evidence.** Green harness + 28/28 menu diff,
   committed in small steps, beats "trust me."

---

## Appendix: the files

| file | role |
|---|---|
| `src/actions.csv` | the action table (data) |
| `src/action_registry.tcl` | CSV loader, `build_menu_from_table`, the palette, extracted procs |
| `src/xschem.tcl` | sources the registry; File menu → `build_menu_from_table`; palette binding; Help entry |
| `src/Makefile.in` | installs the two new share files |
| `doc/claude/code_analysis/menu_inventory/gen_actions.tcl` | idempotent generator for the imported palette rows |
| `tests/headless/dump_file_menu.tcl` | proves the generated File menu matches the original |
| `tests/headless/test_palette.tcl` | proves the palette + keybinding work |
| `doc/claude/suggestions/refactor_plan_action_registry.md` | the plan and current status |
