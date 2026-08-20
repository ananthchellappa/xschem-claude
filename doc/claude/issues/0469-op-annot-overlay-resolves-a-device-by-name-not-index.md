# 0469 — the draw-time OP overlay looks a device up by NAME, so an all-digit or duplicated instance name renders ANOTHER device's numbers

Status: **OPEN, measured on the as-built S9b binary, NOT fixed.**
Filed by the S9b write-up agent (op-annotation crew, branch `annotate`) from the
S9b adversary pass (Verify-C), which lists it as the one attack that SUCCEEDED.

Class: **I3 fabrication** — a plausible, well-formed, correctly-units'd number
attached to the wrong device, in all three back ends, silently.

Related: spec §5 I3, `save.c` RULING D5-1, 0464 (overlay cache residuals),
0447 (`op_annot::register` validates only `dict size`), 0457 (`annot_show`
defaults to 0 — which is the only reason this is not a shipping blocker today).

## The mechanism, in one line

`get_annot_overlay(n, ...)` in `src/actions.c` **holds the instance index `n`
and then discards it**, passing `xctx->inst[n].instname` as the lookup key into
`::op_annot::text`. `op_annot::text` re-resolves that string through
`get_instance()` (`src/scheduler.c:187`), whose FIRST branch is

    if(isonlydigit(s)) i = atoi(s);

so a name that is all digits is read as an **index**, and a duplicated name
resolves to whichever instance the name search finds first.

## Reproduced (S9b adversary, on the shipped binary)

    # all-digit name
    xschem setprop instance MZZA name 1      ;# accepted verbatim, no uniquification,
                                             ;# no warning
    -> the device that was correctly BLANK now renders   VA = 77u
       its own truth is                                  VA = 11u
       (77u is index 1's device path wearing this device's name)
       identical in SVG, PS and on screen.

    # duplicate names
    two devices on one sheet, both named MZZA
    -> BOTH render   VA = 10u
       the second device's truth is  VA = 90u

Reachable two ways, neither exotic:

* `xschem setprop instance <name> name 1` — a fully supported command that does
  **not** uniquify and prints no warning;
* any hand-written, imported or merged `.sch` carrying duplicate instance names.
  **`load` does not uniquify**; only the scripted rename path does.

## Why this is filed and not fixed in S9b

It is **not new to S9b and not a cache defect**: the S6 carrier's `ref=`
attribute has exactly the same resolution, and `op_annot::text` has always taken
a name. What S9b changes is the **blast radius** — from "devices the user
deliberately placed a carrier next to" to "every registered device on every
sheet, the moment the mask is on".

The crew knew about the hazard and guarded its own test helper against it —
`tests/headless/test_op_annot.tcl:3737` carries a comment naming
`get_instance`/`scheduler.c:187` — and left the shipping code exposed. That
asymmetry is the reason this issue exists.

## The fix shape (not applied)

Two candidates, both small; pick in a step that owns `op_annot.tcl`'s signature:

1. **Carry the index.** An index-taking variant — `op_annot::text -index <n>` or
   a second arg — so the C reader passes the `n` it already has and no name
   round-trip happens. Structurally correct; changes a public-ish Tcl signature.
2. **Guard in C.** In `get_annot_overlay()`, skip the instance when
   `xctx->inst[n].instname` does not resolve back to `n` (i.e. when the name is
   all-digits, or a search finds a different index first). Renders **blank**,
   which is I3's required direction, and needs no Tcl change.

Whichever lands, add a row to `tests/headless/test_op_annot.tcl` for **both**
reproductions above — the all-digit rename and the duplicate-name sheet — since
neither is reachable from any current row.

## Still open

Yes. Nothing in S9b changes this behaviour. It is survivable today **only**
because `annot_show` defaults to 0 (issue 0457), so no user sees the overlay
until they press `6`. **This should be closed before the mask is ever defaulted
on.**
