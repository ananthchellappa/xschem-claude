# 1601 — a file NAME is a script in the Open and Insert preview bindings

**STAMP:** `v1 claim=open tree=2a22bfb7 stamped=2026-09-22 fix=untried open=4 by=input-line-inject-crew`

**Status: OPEN — filed 2026-09-22** by the crew that closed **1352**, from the sibling
survey that issue's fix required. **Class** injection / same family as 1352, but the input
is a **filename on disk** rather than typed text.
**Related, read first:** **1352** (`input_line`'s OK button ran what you typed as Tcl —
**FIXED** in `2a22bfb7`). This is the same mistake in a different mechanism, and it is
**strictly more reachable**, because nobody has to type anything.

⚠ **Nothing in this file was produced by running anything.** Every line below is READ off
`src/xschem.tcl` at `2a22bfb7`. The reachability argument is reasoned, not measured, and
the first job of whoever takes this is to measure it.

---

## The defect

Four bindings interpolate a filename into a script string. When the preview widget next
receives `<Expose>` or `<Configure>`, Tk evaluates that string.

### Site 1 — the Open dialog, double-quoted, `[` and `$` live

`proc file_dialog_display_preview` (find it by name):

```tcl
xschem preview_window draw .load.l.paneright.draw "$f"
bind .load.l.paneright.draw <Expose>    [subst {xschem preview_window draw .load.l.paneright.draw "$f"}]
bind .load.l.paneright.draw <Configure> [subst {xschem preview_window draw .load.l.paneright.draw "$f"}]
```

`subst` resolves `$f` at bind time; the result is stored as the binding's script with the
filename sitting inside **double quotes**. A name containing `[` … `]` is a command
substitution the next time the widget is exposed; a name containing `$` is a variable
reference; a name containing a `"` closes the quoting and the remainder of the name is
parsed as further words and commands.

The direct call on the line above has the same double-quoted shape but is evaluated
immediately by the Tcl parser at that point, so it is the **same** exposure, not a lesser
one.

### Site 2 — the Insert dialog, brace-quoted, an unbalanced `}` is enough

`proc file_chooser_draw_preview`:

```tcl
bind .ins.center.right <Expose>    "xschem preview_window draw .ins.center.right {$f}"
bind .ins.center.right <Configure> "xschem preview_window draw .ins.center.right {$f}"
```

Braces suppress `[` and `$`, so this one is weaker — but the braces are **inside a
double-quoted string that `$f` is interpolated into**, so a name containing `}` terminates
the brace group early and everything after it is parsed as script.

### Sites 3 and 4 — the same string handed to `after`

In the same proc and its caller:

```tcl
after cancel "file_chooser_draw_preview {$file_chooser(f)}"
after 200    "file_chooser_draw_preview {$f}"
```

`after` takes a script. Same brace-termination exposure as site 2, on a different clock.

## Provenance — MEASURED, and it decides whether this is ours

`git log -S` on each binding string, and `git merge-base --is-ancestor <c> main` on each
commit it names:

| commit | in `main`? | date | what it is |
|---|---|---|---|
| `0bb4c9f2` | **yes** | 2022-09-26 | non-blocking file selector — the Open-dialog bind's oldest touch |
| `f547c86f` | **yes** | 2024-02-17 | preview window made resizable |
| `e347a251` | **yes** | 2024-02-21 | `load_file_dialog` search/file entry split |
| `451a949c` | **no** | 2026-06-12 | **ours** — `feat(dialog)`: type/paste-a-path + Recent dropdown |
| `e1488da4` | **yes** | 2025-03-11 | `xschem rect gui` &c — the Insert-dialog bind's oldest touch |
| `4cc75cbc` | **yes** | 2026-03-21 | `new_file_browser`: "search all" button |
| `19a28c65` | **yes** | 2026-05-08 | `new_file_browser`: "search all" reuses the listbox |

**The defective shape is upstream, by four years.** One commit that touched the Open-dialog
binding is this branch's (`451a949c`), so we have edited the line, but we did not invent
it. That matters for exactly one reason: the ruling on 1352 offered "leave it as an
inherited sharp edge" as a real option **because it is the branch the user publishes**, and
the same option exists here on the same grounds. `git log -S` reports commits where the
*count* of the string changed, so this table is "who touched it", not "who wrote it"; the
2022 entry is the floor, not necessarily the origin.

## Why this is worse than 1352, and why that is a claim to test rather than believe

1352 required the user to type the payload into a dialog. Here the payload is a **file
name**, so it can arrive by any route a file arrives by: a shared library directory, a
PDK a vendor ships, a tarball, a git checkout, a directory someone else writes to. The
user's own action is limited to *browsing to the folder* — the Open dialog previews the
selected entry, so merely selecting it, or having it be the entry that is selected when
the pane is exposed, is enough.

**What is unmeasured and must be measured first.** Whether these paths are reachable
depends on questions nobody here has answered:

1. **Can such a file exist on the filesystems that matter?** `"` `[` `]` `$` `}` are all
   legal in a POSIX filename. On Windows (`XSchemWin/`) several are not, and this code is
   shared.
2. **Does the dialog offer the file to the preview at all?** `file_dialog_display_preview`
   guards on `is_xschem_file $f`, so a name that never passes that gate never reaches the
   bind. Whether `is_xschem_file` itself is safe with such a name is a second question.
3. **Does `$f` reach the proc intact, or has some earlier layer already mangled or
   rejected it?** The Open dialog's list is built elsewhere; a name that is already broken
   by the time it is displayed is a different defect.
4. **Does the binding actually fire?** A `<Expose>` needs the pane to be exposed. The
   `after 200` sites fire on a timer and are the more likely trigger.

A measurement that answers those four is worth more than a fix that assumes them.

## The shape a fix takes

The 1352 remedy — make the value a value — applies directly, and the tree already has the
idiom. A binding script should be built as a **list**, not by interpolation:

```tcl
bind .load.l.paneright.draw <Expose> \
  [list xschem preview_window draw .load.l.paneright.draw $f]
```

`list` quotes each element for exactly one round of Tcl parsing, which is exactly what a
binding gets. The same applies to `after`:

```tcl
after 200 [list file_chooser_draw_preview $f]
after cancel [list file_chooser_draw_preview $file_chooser(f)]
```

⚠ **`after cancel` matches on the script string**, so the `cancel` form and the form that
scheduled it must be built the same way or the cancel silently stops matching and a stale
preview redraw survives. Changing one without the other is a behaviour change disguised
as a safety fix. Both sites are named above; change them together, and prove the cancel
still cancels.

## Still open

1. Measure the four questions above, on Linux and — if anyone can — on Windows.
2. Fix the four sites, together, with the `after cancel` pairing proved.
3. A T1-visible test. The structural half is easy (no interpolated binding survives in
   these procs); the behavioural half needs a real file with a hostile name, a real Open
   dialog on a display, and a real `<Expose>`, which is the same shape as
   `test_input_line_inject_1352.tcl`'s B rows.
4. The wider sweep. The 1352 crew's survey covered `src/*.tcl` keyed on
   `eval`/`subst`/`uplevel` and on `bind`/`-command` built with `"` or `[subst`. **It could
   not see** a widget value stored in a variable in one proc and evaluated in another,
   scripts composed in C and handed to `tcleval`/`tclvareval`, `.tcl` outside `src/`
   (the `xschem_library/` generators), or `after`/`trace`/menu `-command` scripts built by
   plain concatenation with none of those four words on the line. Sites 3 and 4 above were
   found only because they sit inside a proc the survey had already opened for another
   reason, which is itself evidence the sweep is a lower bound.

## Deliberately NOT part of this

`proc file_exists` does `catch "uplevel #0 {subst $f}"` to expand `$env(...)` in a path.
The env expansion is **deliberate and documented in the comment above it**; that a `[...]`
in the path also executes is a side effect of the same line. Narrowing it to variable
expansion without command substitution is a real question, but it is a *behaviour* change
to a documented feature, not a fix to an accident, and it belongs in its own issue with
the user's ruling behind it.

Likewise not defects and deliberately excluded: `tclpropeval`/`tclpropeval2` (schematic
`tcleval()` properties), the simulator command templates (`subst -nobackslashes
$sim(...)`), `launcher`, and the `calc::palette` / `rdw::palette` `uplevel #0 $src` colour
lookups. Those evaluate on purpose.
