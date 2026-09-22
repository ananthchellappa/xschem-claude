# 1352 — `input_line`'s OK button runs what you type as Tcl

**STAMP:** `v1 claim=fixed tree=703b7b59 stamped=2026-09-22 fix=taken open=0 by=input-line-inject-crew`

**Status: FIXED (2026-09-22).** See **The fix, as taken** below; the text from
here to that section is the original filing, left as it stood.

**Status when filed: FILED, NOT FIXED.** Found by item **P2**'s adversary while
measuring the RDW engineering-notation repair (2026-09-05), re-driven
independently by the driver on `:99`. Subject: `proc input_line` in
`src/xschem.tcl` (cited by line as `14146-14152` when filed; cite it by proc
name — the coordinates have since moved). **This is stock xschem code, not
something this branch introduced** — it is inherited, and it is on the branch
the user shares.

## The shape

```tcl
button .dialog.f2.ok -text OK  -command  "
  if { {$cmd} ne {} } {
    eval $cmd \[.dialog.f1.e get\]
  }
  ...
"
```

`eval` concatenates its arguments into a script and evaluates it, so the text
the user typed is not passed as a **value** to `$cmd` — it is spliced into the
script and parsed as Tcl.

## Driven, in the real widget

Probe: `scratchpad/inpline.tcl`, run on `:99` through `devdisplay.sh exec`,
filling and invoking the actual OK button from the event loop.

Typing

```
7 ; set ::INJECTED yes
```

into the dialog `input_line {precision} {set_ne ev_precision} 4 12` raises —

```
EVPREC=4
INJECTED=yes
```

— the second command ran. The adversary drove the same thing through the shipped
menu entry **Simulation > Set netlist / graph / annotation precision** and got
the same answer.

## Why it matters more than a validation bug

Every `input_line` caller that passes a `cmd` shares it. **Set top level netlist
name** goes through the same button with `xschem set netlist_name`. So the
question that reaches the user as "should the precision dialog refuse a value it
cannot use?" is smaller than the truth: these dialogs execute their input.

The realistic exposure is not a hostile user typing into their own editor — it
is a value that arrives from somewhere else and passes through one of these
dialogs, and it is a sharp edge on a branch that is handed to other people.

## The fix, and why it was not taken when this was filed

`eval $cmd [list [.dialog.f1.e get]]`, or `uplevel #0 [linsert $cmd end [...]]`
— one line, and it makes the typed text a single argument in every case.

It was not taken then for one reason: **`input_line` is a stock proc with many
callers, and any caller relying today on the typed text being *substituted* (a
multi-word value reaching `$cmd` as several arguments) would change behaviour
silently.** That is a survey and a ruling, not a patch, and it was off the RDW
batch's path. Recorded as a rule debt so it reaches the user rather than sitting
in a write-up.

## What was NOT claimed at filing time

No path was found by which this fires without someone typing into the dialog.
It is a sharp edge and an inherited one, not a live exploit in the tree.

---

# The fix, as taken (2026-09-22)

## The survey the filing asked for, done

The worry that blocked the patch was *"a caller relying on the typed text being
substituted"*. Every call site was enumerated
(`/usr/bin/grep -n input_line src/*.tcl src/*.c`) and **no such caller exists**.
`$cmd` is a fixed prefix supplied by the caller in every case, never user text:

| `$cmd` | where |
|---|---|
| `set ev_precision` | Simulation ▸ Set netlist / graph / annotation precision |
| `xschem set netlist_name` | Simulation ▸ Set top level netlist name |
| `xschem set cadsnap` | View ▸ Set snap value (and `callback.c`'s bindable action) |
| `xschem set cadgrid` | View ▸ Set grid spacing |
| `xschem line_width` | View ▸ Set line width (and `callback.c`) |
| `set grid_point_size` | View ▸ Set grid point size |
| `set symbol_width` | Options ▸ Symbol width |
| `set crosshair_size` | Options ▸ Crosshair ▸ Crosshair size |
| `set bus_replacement_char` | Options ▸ Replace `[` and `]` for buses |
| `{}` (empty) | `callback.c`'s four `input_line {Pos:} {}` cursor prompts, `editprop.c`'s Object Sequence number, `actions.c`'s descend instance number |

Measured, not argued: with the defect in place a **multi-word value did not
reach `$cmd` as several arguments — it raised.** `set ev_precision a b c` is
`wrong # args`; a lone `"` is `missing "`; a lone `{` is `missing close-brace`;
an embedded newline is `invalid command name "b"`. The only callers that
"worked" with several words were the ones being injected. There was nothing to
preserve.

## The patch

`proc input_line`, `src/xschem.tcl`, the OK button's `-command`:

```tcl
-    if { {$cmd} ne {} } {
-      eval $cmd \[.dialog.f1.e get\]
+    if { {$cmd} ne {} && \[.dialog.f1.e get\] ne {} } {
+      eval $cmd \[list \[.dialog.f1.e get\]\]
     }
```

`list` makes the entry contents exactly one list element whatever they hold, so
`eval`'s concatenation can no longer reparse them.

**The emptiness guard is not decoration.** It holds the one behaviour `list`
would otherwise have changed. With an empty entry the old form appended nothing,
so `set X` was a harmless *read* and every `xschem …` caller fell short of its
own `argc` guard and did nothing. Quoted and unguarded, an empty entry becomes an
explicit `{}` argument, and `xschem line_width {}` is `change_linewidth(0)` while
`xschem set cadsnap {}` is `set_snap(0)` → the default snap. Pressing OK on an
emptied field must keep doing nothing, and now does.

## One behaviour deliberately CHANGES, for the better

`xschem set netlist_name` **with a space in the name was broken and now works.**
Driven on `:99` through the shipped Simulation ▸ Set top level netlist name
entry, typing `my file.spice`:

* before — `xschem get netlist_name` is `my` (the dispatcher saw five words);
* after — `my file.spice`.

Rows `B15` / `B16a` of the suite pin it.

## The suite

`tests/headless/test_input_line_inject_1352.tcl`, registered in
`tests/run_regression.tcl` in **both** `hcases` and `dcases`.

* **`S0`–`S5`, both arms, 7 checks.** Structural: the shipped proc carries the
  `list` form exactly once, carries no bare `eval $cmd \[.dialog.f1.e get\]`
  anywhere in `src/xschem.tcl` once comments are stripped (the fix's own comment
  quotes the defective line verbatim, so a reader of the raw file would answer
  "still broken" forever), has exactly one `eval $cmd`, carries the emptiness
  guard, and still routes `<Return>` through the same OK button so Enter is not
  a second unguarded door.
* **`B1a`–`B19`, display arm only, 27 more checks (34 total).** The real
  toplevel, the real entry, the real OK button invoked from the event loop —
  including the issue's own repro through the shipped **Simulation ▸ Set netlist
  / graph / annotation precision** menu entry. `input_line` builds a Tk toplevel
  and blocks in `tkwait`, and neither `toplevel` nor `winfo` exists under
  `--nogui`, so on the headless arm these print one `skip:` line naming all 27.
  `B19` is the row that stops the section passing by not happening: the
  "nothing was executed" rows (`B12a`, `B13a`) would be satisfied by a dialog
  that never opened, so every drive records whether it reached the real OK
  button and `B19` reports it.

Armed spellings: `tests/headless/run_suites.sh test_input_line_inject_1352`
(34 checks) and `… --nogui …` (7 checks + the skip line).

**Sabotage** (the stock line restored in place, then reverted, `cmp` clean):
4 rows red headless — `S1`, `S2`, `S2b`, `S4`; 22 red on the display arm — those
four plus `B1a`, `B1b`, `B3a`, `B3b`, `B4`, `B5`, `B6`, `B8`, `B9`, `B10`,
`B11a`, `B11b`, `B15`, `B16a`, `B16b`, `B17b`, `B18a`, `B18b`. `B7` (a lone
`}`), `B13a`/`B13b` (the empty entry), `B2`/`B12a`/`B12b`/`B14`/`B17a` stayed
green under sabotage by design: they are guards on behaviour the defect happened
not to break, not discriminators.

## A sibling site, NOT fixed here

`proc file_dialog_display_preview` in `src/xschem.tcl` has the same shape from
the other direction — a widget's contents reaching a script:

```tcl
bind .load.l.paneright.draw <Expose> [subst {xschem preview_window draw .load.l.paneright.draw "$f"}]
```

`$f` is the path selected in the Open dialog's browser, spliced into a bind
script inside double quotes, so a file name containing `"`, `[` or `$` is
reparsed on the next `<Expose>`. `proc file_chooser_draw_preview`'s preview binds
(`bind .ins.center.right <Expose> "xschem preview_window draw … {$f}"`) are the
same family with braces instead of quotes — proof against `[` and `$`, not
against an unbalanced `}` in a name. Reported for a number of its own rather than
fixed under this one.
