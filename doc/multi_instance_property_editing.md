# Editing many instances at once — user guide

*How to use the multi-instance features of the "Edit Properties" dialog: the
**Apply to** scope, **Next/Prev** navigation, the **Apply** button, automatic
**name** protection, and the **"values differ"** warning.*

This is the hands-on manual. For the design rationale see
`doc/claude/specs/multi_instance_property_editing.md`; for how it was built (a tutorial for
developers) see `doc/claude/code_analysis/multi_instance_editing_tutorial.md`.

---

## The one thing to know

**Editing properties only ever changes the fields you actually edited.** Every
other attribute of every instance is left exactly as it was. Choosing a wider
scope does **not** make instances identical — it just sends *your edits* to more
of them. Each instance keeps its own name and its own untouched values.

---

## Opening the dialog

Select one or more component instances and open **Edit Properties** — press
**`q`**, or use the menu / right-click. The dialog shows one labelled field per
declared attribute of the displayed instance (`name`, `value`, `footprint`, …),
plus the symbol and a few options.

If you selected several instances, the dialog opens on the **first** one and —
importantly — does **not** touch the others unless you ask it to (see scope,
below). This is a change from older versions, which silently edited the whole
selection.

---

## "Apply to" — choosing how far an edit reaches

At the top of the dialog is the **Apply to** dropdown. It has three settings:

| Setting | What an OK / Apply touches |
| --- | --- |
| **Only Current** *(default)* | Just the one instance shown in the dialog. |
| **All Selected** | Every instance you selected. |
| **All (same symbol)** | Every instance of the **same symbol** on the current sheet — even ones you didn't select. A *different* symbol is never touched. |

Pick the scope, edit the field(s) you want, then **OK** or **Apply**. Only the
fields you changed are written to the in-scope instances.

The setting is **sticky**: it stays where you left it the next time you open the
dialog, so a workflow like "select a few, set them all" doesn't need re-choosing
each time. If you want the safe default back, set it to **Only Current**.

### Launching straight into a scope (keyboard shortcuts)

`xschem edit_prop` accepts an optional scope argument so you can bind keys that
open the dialog *already set* to a given scope:

```tcl
xschem edit_prop current     ;# open in Only Current
xschem edit_prop selected    ;# open in All Selected
xschem edit_prop all         ;# open in All (same symbol)
```

This is handy for two dedicated shortcuts — e.g. one key for the safe
single-instance edit and another for editing the whole selection. Bind them in
your `xschemrc` (or wherever you keep custom bindings), for example:

```tcl
bind .drw <Key-q>       {xschem edit_prop current}   ;# plain q = Only Current
bind .drw <Shift-Key-Q> {xschem edit_prop selected}  ;# Shift-Q = All Selected
```

The argument updates the same sticky setting, so it also becomes the new default
for a later plain open. An unknown scope is rejected (it must be `current`,
`selected`, or `all`).

> **Example.** Three resistors selected, each a different value. Set **Apply to →
> All Selected**, change `value` to `2k`, click OK. All three become `2k`. Their
> *names* (R1, R2, R3) are untouched — see "Name is protected" below.

---

## Name is protected under multi scopes

Instance names must be unique, so a single name can't sensibly be copied onto
many instances. When **Apply to** is **All Selected** or **All**, the **name**
field is greyed out (read-only). Each instance keeps its own name. Switch back to
**Only Current** and the name field re-enables, because then you're editing just
one instance.

---

## Next / Prev — walking the selection

When you've selected several instances, use **◀ Prev** and **Next ▶** (or
**Alt+Left** / **Alt+Right**) to step the dialog through them one at a time. The
readout between the buttons shows your position, e.g. **"2 of 7"**. **Prev** is
disabled on the first instance, **Next** on the last.

- Navigating shows the next instance **with its own current values**.
- **If you have unapplied edits, stepping away asks first** — a dialog offering
  **Apply** (commit them, then move), **Discard** (drop them, then move), or
  **Cancel** (stay where you are). Modified fields are flagged with a dot, so
  pending edits are visible before you leave.

This lets you sweep a selection: land on an instance, tweak it, **Apply**, step to
the next, and so on — all without closing the dialog.

---

## OK, Apply, Cancel

| Button | Effect |
| --- | --- |
| **OK** | Apply your edits to the scope, then **close**. |
| **Apply** | Apply your edits to the scope, **stay open** (so you can keep going / step to the next). |
| **Cancel** *(Esc)* | Close without applying anything pending. |

**Apply** is what makes Next/Prev useful: edit, Apply, Next, edit, Apply, … in one
sitting.

---

## Undo

Each **Apply** (and the apply that **OK** performs) is its **own** undo step.

- One Apply with scope **All Selected / All** → a single **Undo** reverses the
  change across *all* affected instances at once.
- If you step through with Next/Prev and Apply on several instances, each Apply is
  a separate undo: **Undo** reverses only the most recent one.

---

## The "values differ" warning

When the scope is **All Selected** or **All**, the footer line normally shows the
keyboard hint. If you click into a field whose value is **not the same across all
the in-scope instances**, the footer turns into a **red warning**, e.g.:

> ⚠  'value' differs across 5 instances — Apply overwrites them

It's telling you that applying your single value will **overwrite** those
differing values. This is exactly what you want when you mean to unify them — and a
useful "wait, are you sure?" when you don't. The warning is per-field: it clears
when the focused field is uniform across the set, or when the scope is **Only
Current**.

---

## Scope highlight — seeing what an edit will touch

While the dialog is open, the objects an **OK / Apply** would write to are marked
on the canvas with a **white outline** (a halo around each one). It is a *second*
cue, separate from the usual selection colour, so you can tell at a glance which
instances the current scope reaches:

- **Only Current** — just the one instance shown in the dialog.
- **All Selected** — every selected instance of the *same symbol* as the
  displayed one.
- **All (same symbol)** — every instance of that symbol on the sheet, including
  ones you never selected.

The outline tracks your choices **live**: change the "Apply to" dropdown or step
**Next / Prev** and it follows. Each object is outlined in its **natural shape**
(an instance by its bounding box, a wire as its line). It disappears when you
close the dialog (OK / Apply-then-close / Cancel). The outlined set is *exactly*
the set OK writes — there is no daylight between what you see and what changes.

> On the light colour scheme the outline is drawn near-black instead of white so
> it stays visible; set `slickprop_highlight_color` to force a fixed colour.

---

## The editor is modeless — keep selecting

You don't have to close the dialog to change what you're editing. With it open you
can keep working on the canvas:

- **Click** an instance → the dialog switches to editing it.
- **Shift-click** (or sweep) → add instances to the set; under **All Selected**
  the scope, the **Next/Prev** range, and the white highlight all update live.
- Pan and zoom work as usual.

If you have **unapplied edits** when you change the selection, the dialog asks
first — **Apply** (commit, then switch), **Discard** (drop, then switch), or
**Cancel** (stay on the current instance, keeping your edits and selection). A
selection change with nothing pending switches silently.

> Only *selection* is live while the dialog is open; moving, drawing wires, or
> placing objects stay disabled until you close it.

---

## Customization

These optional Tcl variables (set them in `~/.xschem/xschemrc`, a script, or the
command window) tune the form:

| Variable | Effect | Default |
| --- | --- | --- |
| `slickprop_apply_scope` | The current scope: `current`, `selected`, or `all`. | `current` |
| `slickprop_warn` | Colour of the "values differ" warning. | `#d02020` (red) |
| `slickprop_highlight_color` | Colour of the scope-highlight outline. | white (dark theme) / near-black (light theme) |
| `slickprop_highlight_width` | Width (screen px) of the scope-highlight halo. | 2 |
| `slickprop_fontsize` | Base font size of the whole form. | system size + 1 |
| `slickprop_entry_width` | Width of value entries, in characters. | 36 |
| `slickprop_accent` | Colour of the "modified field" dot. | `#d08000` (amber) |

For example, to default new sessions to editing the whole selection:

```tcl
set slickprop_apply_scope selected
```

---

## For scripters: the apply command

The dialog applies edits through one Tcl command, which you can also call directly
from scripts:

```tcl
xschem apply_properties <scope> <displayed_id> <new_prop> <old_prop>
```

- `<scope>` — `current`, `selected`, or `all`.
- `<displayed_id>` — the **session-stable id** of the reference instance (get it
  with `xschem instance_id <name|index>`). For `current`/`all` this is the
  instance the scope is measured from; for `all` it picks the master.
- `<new_prop>` — the desired property string (reference instance's string with
  your edits).
- `<old_prop>` — the reference instance's *original* string.

Only the tokens that differ between `<new_prop>` and `<old_prop>` are applied to
each in-scope instance (each keeps its other attributes). The command pushes one
undo entry and returns `1` if anything changed, else `0`. Because it takes a
*stable id*, the reference survives any re-indexing between calls.

```tcl
# Example: set value=2k on every instance of the displayed one's master,
# preserving everything else.
set id  [xschem instance_id R1]
set old [xschem getprop instance R1]
set new [xschem subst_tok $old value 2k]
xschem apply_properties all $id $new $old
```

---

## Quick reference

| Action | How |
| --- | --- |
| Open Edit Properties | select instance(s), press **`q`** |
| Open straight into a scope | `xschem edit_prop current\|selected\|all` (bindable) |
| Choose how far edits reach | **Apply to** dropdown (sticky) |
| Step through the selection | **◀ Prev / Next ▶** or **Alt+Left / Alt+Right** |
| Apply and keep editing | **Apply** |
| Apply and close | **OK** (or **Enter**) |
| Discard and close | **Cancel** (or **Esc**) |
| Undo one apply | **Undo** (`u`) |
| See if a field varies across the set | watch the red footer warning |

---

*Reference: design + decisions in `doc/claude/specs/multi_instance_property_editing.md`;
implementation walkthrough in
`doc/claude/code_analysis/multi_instance_editing_tutorial.md`.*
