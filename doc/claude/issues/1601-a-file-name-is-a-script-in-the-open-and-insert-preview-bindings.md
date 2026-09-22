# 1601 — a file NAME is a script in the Open and Insert preview bindings

**STAMP:** `v1 claim=fixed tree=f8647d8d stamped=2026-09-22 fix=taken open=1 by=preview-name-inject-crew`

**Status: FIXED (2026-09-22).** Measured first, then fixed — see **Measured, on :99**
and **The fix, as taken** below. The text from here to those sections is the original
filing, left as it stood, including the four questions it said were unmeasured; the
answers are recorded under each.

**Status when filed: FILED, NOT FIXED** by the crew that closed **1352**, from the
sibling survey that issue's fix required. **Class** injection / same family as 1352, but
the input is a **filename on disk** rather than typed text.
**Related, read first:** **1352** (`input_line`'s OK button ran what you typed as Tcl —
**FIXED** in `2a22bfb7`). This is the same mistake in a different mechanism, and it is
**strictly more reachable**, because nobody has to type anything.

⚠ **Nothing in this file was produced by running anything.** Every line below is READ off
`src/xschem.tcl` at `2a22bfb7`. The reachability argument is reasoned, not measured, and
the first job of whoever takes this is to measure it.
**That measurement has since been done and it confirmed the reachability argument** — one
claim excepted, corrected under **Measured, on :99**.

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

1. ~~Measure the four questions above, on Linux and — if anyone can — on Windows.~~
   **DONE on Linux** (below). Windows is **reasoned, not run**: nobody here has one.
2. ~~Fix the four sites, together, with the `after cancel` pairing proved.~~ **DONE.**
3. ~~A T1-visible test.~~ **DONE** — `tests/headless/test_preview_name_inject_1601.tcl`.
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

---

# Measured, on :99 (2026-09-22)

Driven at `f8647d8d` with `./src/xschem --pipe -q --script`, `DISPLAY=:99`
(`tests/headless/devdisplay.sh`), `HOME` pointed at a throwaway. Every file used was a
**real schematic** (a copy of `tests/headless/fixture_0098_pre.sch`) under a hostile name,
so nothing turned on a file the preview would have refused.

## The four questions the filing said were unmeasured

**1. Can such a file exist?** On this ext4/WSL2 filesystem **every one was created**:
`q"uote.sch`, `q[set ::CANARY BRACKET]z.sch`, `v$tcl_version.sch`, `dollar$env(HOME).sch`,
`close}brace.sch`, `a}; set ::CANARY BRACE_ESCAPE; format {b.sch`, and
`x"; set ::CANARY QUOTE_ESCAPE; format ".sch`. A newline and a backslash are accepted too.
**Windows, by reading rather than by running** (no Windows here): the Win32 reserved set is
`< > : " / \ | ? *`, so a `"` name is refused there — but `[`, `]`, `$`, `}` and `;` are all
legal, so **site 1's `[...]` payload and sites 2–4's close-brace payload are reachable on
Windows too.** Only the `"`-escape variant of site 1 is not.

**2. Does the file reach the preview at all?** Yes. `is_xschem_file` returned `SCHEMATIC`
for every hostile name above **except** `dollar$env(HOME).sch`, and that one failed for a
reason that has nothing to do with the quoting: the proc opens with
`regsub {\(.*} $f {} f` to strip generator arguments, so **any name containing `(` is
truncated at the parenthesis and then fails `file exists`**. `is_xschem_file` is itself
safe — it only ever uses `$f` as a value (`file exists`, `open`), and the canary stayed
quiet through every call.

**3. Does `$f` arrive intact?** Yes. `setglob` builds `file_dialog_files2` by concatenating
two `lsort` results with a space; `lsort` returns a proper Tcl list, so every hostile name
survives as one element and `lsearch -exact` found all seven at the right indices. Nothing
upstream of the preview mangles or rejects them.

**4. Does the binding fire?** Both do, and the filing's guess about which matters was
right in a way it did not expect. The `<Expose>` binding fires on a real `<Expose>`
(measured). The `after 200` in `file_chooser_preview` is **worse**: it needs no exposure at
all — it fires on a timer 200 ms after the entry is selected.

## The exploit, through the SHIPPED Open dialog

A real schematic named `pwn[set ::CANARY OPEN_DIALOG]ed.sch`; the canary `::CANARY` unset;
the real `load_file_dialog` opened and driven from the event loop the way a person drives
it — select the row, let the shipped `<ButtonRelease-1>` binding run, let the preview pane
receive an `<Expose>`:

```
dialog up; entries = 3
victim row index = 2
after the shipped ButtonRelease-1: canary = quiet
<Expose> script now bound: xschem preview_window draw .load.l.paneright.draw "/…/pwn[set ::CANARY OPEN_DIALOG]ed.sch"
after a REAL <Expose> on the preview pane: canary = OPEN_DIALOG
```

**The canary fired.** The proof that the substitution happened *inside the binding* is the
line xschem printed next: `load_schematic(): unable to open file: /…/pwnOPEN_DIALOGed.sch`
— the command's *result* had been spliced into the path.

Per site, on a real event:

| site | payload shape | result |
|---|---|---|
| 1 `<Expose>` | `q[set ::CANARY BRACKET]z.sch` | **executed** |
| 1 `<Expose>` | `x"; set ::CANARY QUOTE_ESCAPE; format ".sch` | **executed** |
| 1 `<Expose>` | `q"uote.sch` | raised `extra characters after close-quote` → **modal bgerror, on every Expose** |
| 1 `<Expose>` | `v$tcl_version.sch` | substituted: previewed `v8.6.sch`, a **silently wrong file** |
| 1 `<Expose>` | `close}brace.sch` | inert (site 1 is quote-shaped) |
| 2 `<Expose>` | `a}; set ::CANARY BRACE_ESCAPE; format {b.sch` | **executed** |
| 2 `<Expose>` | `close}brace.sch` | raised `extra characters after close-brace` → **modal bgerror** |
| 4 `after 200` | `a}; set ::CANARY BRACE_ESCAPE; format {b.sch` | **executed, with no Expose at all** |
| 3 `after cancel` | any | matched correctly before the fix (both sides were interpolated) |

## ⚠ One claim in the filing is WRONG, and this corrects it

The filing said of the direct call above the binds —
*"The direct call on the line above has the same double-quoted shape but is evaluated
immediately by the Tcl parser at that point, so it is the **same** exposure, not a lesser
one."*

**It is not an exposure at all.** `xschem preview_window draw … "$f"` is one round of
substitution and Tcl does not rescan the result. Measured: across all seven hostile names,
on both sites, **the canary was quiet after every direct call** and only ever fired when a
stored script was re-parsed. The defect was the *stored* script, never the immediate call.

## A side finding, not this issue

A Tk toplevel holding a preview destroyed **without** a matching
`xschem preview_window close` leaves `preview_window()`'s static `tkpre_window[]` pointing
at a freed window, and the next `draw` **segfaults** (reproduced at the 5th such cycle;
`preview_window()` in `src/xinit.c`). The shipped dialogs always pair them, so this is a
trap for test harnesses rather than a live defect, and the suite pairs them.

---

# The fix, as taken (2026-09-22)

All four sites build the script as a **list**. `list` quotes each element for exactly one
round of Tcl parsing, which is exactly what a binding and an `after` get.

* `proc file_dialog_display_preview` — one `set preview_script [list xschem preview_window
  draw .load.l.paneright.draw $f]`, bound to both `<Expose>` and `<Configure>`. The direct
  call above it drops its now-pointless quotes (measured a no-op either way).
* `proc file_chooser_draw_preview` — the same, for `.ins.center.right`.
* `proc file_chooser_preview` — `after 200 [list file_chooser_draw_preview $f]` and
  `after cancel [list file_chooser_draw_preview $file_chooser(f)]`, **changed together**.

**The `after cancel` pairing, proved rather than asserted.** With only the cancel converted
(site 3 sabotaged, site 4 left as a list) the shipped `file_chooser_preview` no longer
cancels its pending redraw: row `B13` reports **two** pending
`file_chooser_draw_preview` scripts where there must be one. With only the schedule
converted (site 4 sabotaged) `B10`, `B11`, `B12` and `B13` all redden. Section `C` measures
the same pairing in plain Tcl on both arms, and `C5` shows the old interpolated cancel
failing to match a list-built schedule.

## ⚠ The fix's own COMMENT broke the proc, and that is now a tested class

The first draft of the site 2 comment quoted the hostile name verbatim. A comment inside a
proc body sits inside a brace-quoted word, and **Tcl counts braces before it ever notices a
`#`**: the close brace in the quoted name ended the enclosing `if` early, so the bind lines
below it ran unguarded and the body's own closing brace became a command.
`file_chooser_draw_preview` then raised an `invalid command name` error naming a close
brace on **every** call — and a second draft that merely quoted that error message did the
same thing, aborting xschem's startup outright. Rows `S15` (both arms), `B17` and `B18`
hold it, and the comment now describes the name instead of quoting it.

# The suite

`tests/headless/test_preview_name_inject_1601.tcl`, registered in `tests/run_regression.tcl`
in **both** `hcases` and `dcases`, for the reason `test_input_line_inject_1352` is.

* **`S1`–`S15` and `C1`–`C5`, both arms, 20 checks.** Structural: the four sites read out
  of `src/xschem.tcl` **with comment lines stripped** (the fixes' comments describe the
  defective shapes, and a raw grep would answer "still broken" forever), plus the
  `after cancel` pairing in plain Tcl, plus the comment-brace row.
* **`B1`–`B18`, display arm only, 18 more checks (38 total).** Real files with hostile
  names on disk, the real procs, real `<Expose>` events, the real `file_chooser_preview`
  schedule/cancel path, and the real `load_file_dialog`. `B14` is the row that stops the
  section passing by not happening: it reports whether the dialog really opened and really
  previewed the file. Under `--nogui` these print one `skip:` line.

Armed spellings: `tests/headless/run_suites.sh test_preview_name_inject_1601` (38 checks)
and `… --nogui …` (20 checks + the skip line).

**Sabotage**, each site reverted in turn and restored byte-identical (`md5sum`
`b2394ab8ed77eb749d204dd1750a3f6b` before and after):

| sabotage | red headless | red on the display arm |
|---|---|---|
| site 1 | `S4` `S5` `S6` `S7` | those + `B2` `B3` `B4` `B6` `B15` `B16` |
| site 2 | `S8` `S9` `S10` | those + `B7` `B8` `B9` |
| site 3 (`after cancel`) | `S12` `S13` `S14` | those + `B13` |
| site 4 (`after 200`) | `S11` `S13` `S14` | those + `B10` `B11` `B12` `B13` |
| the comment brace fault | `S15` | `S15` + `B17` `B18` |

**Green under sabotage by design, so nobody mistakes them for coverage:** `S1`–`S3` (the
procs exist), `C1`–`C5` (they measure the pairing rule itself, not the shipped spelling),
`B1` (the fixture files are real schematics), `B5` (a name containing only a `"` raises
rather than injecting, so it is a guard on the *error* path, not a discriminator), `B14`
(the drive happened), and every site's rows under the other sites' sabotages.
