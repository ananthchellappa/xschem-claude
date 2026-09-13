# 1446 — a value the dialog remembered, and OK did not write

**Branch:** fluid-editing · **Filed:** 2026-09-13 · **Status:** open, **rule debt filed**
**Comes out of:** ⚖ R5's implementation (issue **1445**), measured by its crew and verified
by the driver.

## What happens

⚖ R5 made the Choose Analyses dialog **remember** what you typed when you click another
analysis. It does. Two cases remain where the dialog remembers a value and **OK does not
write it**, and the second one is new.

**Shape A — another type is showing.** Type `500u` into `tran`, click `ac`, press OK. The
`ac` row is written; the `tran` edit is dropped. It was remembered the whole time the dialog
was open — clicking back to `tran` shows `500u` — and pressing OK from `ac` discards it.

**Shape B — the same type, but the field is folded away.** Type a value into a field behind
`▸ Advanced`, fold the disclosure shut, press OK. The value is remembered (unfold it and it
is there) and **not committed**, because `ase::ui::chana_ok` reads **live widgets** and
folding the disclosure destroys them: `chana_adv_toggle` rebuilds the form through
`chana_show`, which does `destroy $w.form`.

## Why shape A is not a defect and shape B might be

**Shape A is the ruled behaviour.** ⚖ R5's answer is *"cache per-type edits for the dialog's
lifetime and commit only the visible type at OK"*, and the reason is `item07_dialogs.md`'s
D4: *"no hidden multi-type writes"*. Committing every cached type at OK is exactly the thing
that reason forbids. It is listed here so the user can see the consequence of the shape they
ruled, not to reopen it.

**Shape B does not cross that line.** The field belongs to the type being committed. Writing
it is a **single-type** write — the same row, the same OK — and the only thing standing
between the value and the row is that the widget was destroyed by a disclosure toggle. The
user's mental model is that a form holds what they typed into it; a triangle that hides a
field is not a gesture that discards it.

⚠ **It is not a regression.** Before R5 the value was destroyed outright on the fold, so OK
could not write it either — and it was not recoverable. R5 made it recoverable and left the
commit door where it was. This is a **new shape of an old loss**, and it is now visible,
which is why it is worth a decision.

## Options

| | what | cost |
|---|---|---|
| **A** | leave it: OK writes the visible type's **live widgets** | none. Shape B stays silent |
| **B** | **(recommended)** OK writes the visible type's live widgets **merged over that type's cache** — still one type, still one row | small: `chana_ok` reads `chana_cache_apply` instead of the bare form. Fixes shape B; shape A unchanged |
| **C** | OK writes every cached type | reverses D4's stated reason. Not recommended |
| **D** | say it: the status line names what OK is about to drop | new user-facing sentence → ⚖ R9, and it argues for B rather than replacing it |

**Recommendation: B**, and D later if the user wants the dialog to speak.

## Where it lives

`src/ase_window.tcl` — `ase::ui::chana_ok` (the read path), `ase::ui::chana_adv_toggle`
(rebuilds through `chana_show`), `ase::ui::chana_cache_apply` (already exists, added by
1445). Test rows: `test_ase_dialogs.tcl` section **GR5** — `GR5g` measures shape A,
`GR5l` measures that the save side merges a folded field.
