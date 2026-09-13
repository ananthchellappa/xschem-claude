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

---

## What landed — Option B, implemented ahead of the ruling (2026-09-13)

⚠ **THE USER HAS NOT RULED. This is the recommended shape built so the work is not
idle**; a ruling of **A** reverts it, and it was kept small for exactly that reason —
one new proc, one changed line, and its rows. Rule debt: `owed.sh` id **1446**.

**`src/ase_window.tcl`** — `ase::ui::chana_commit_vals`, new, sitting between
`chana_form_vals` and `chana_merged_row`; `ase::ui::chana_ok`'s one reader line now
calls it instead of `chana_form_vals`. Nothing else in the file moved.

```tcl
proc ase::ui::chana_commit_vals {key type sim} {
  variable dlg
  set vals [dict create]
  if {$type ne {} && [info exists dlg($key,anedit,$type)]} {
    set cached $dlg($key,anedit,$type)
    foreach f [ase::ui::chana_fields $type $sim] {
      if {[dict exists $cached $f]} { dict set vals $f [dict get $cached $f] }
    }
  }
  return [dict merge $vals [ase::ui::chana_form_vals $key $type $sim]]
}
```

Three properties, each a row in `tests/headless/test_ase_dialogs.tcl` section **GR6**:

* **one type, one row.** Only `anedit,<the type being committed>` is read. **GR6e**
  presses OK with another type's edit sitting in the cache and asks for every other
  row of the bench back byte for byte, plus that no other type's field name landed in
  the committed row. `item07_dialogs.md`'s D4 reason is not spent.
* **the live widget wins** where both exist, because the user may have typed, folded,
  unfolded and retyped (**GR6d**).
* **it answers in FIELDS, not in cache keys.** `chana_cache_save` also stores
  `enabled`; `chana_ok` owns that key from the live `anen`. Without the filter the
  bench ends up ON while the box the user is looking at says OFF (**GR6g**).

`ase::ui::form_is_absent` still decides what is written — a merged value goes through
the identical test a live one does: **GR6b** (declared default, with the non-default
positive control), **GR6c** (emptied field deletes its stored key), **GR6f** (click
every cell, fold `▸ Advanced` open and shut on each, press OK: the same bytes as never
opening the dialog). The 104 tracked `.state` files still round-trip, 0 differ.

**Shape A is unchanged and remains the ruled behaviour** (GR5g, still green).

### The residual this left — **GR6h**

`ase::ui::chana_merged_row`, the precondition banner's reader (issue 1435), was **not**
changed: with a folded edit in the cache it judges the **stored** value while OK now
writes the **remembered** one. It changes no sentence today — no `needs` rule in the
ngspice adapter reads an `advanced 1` field — and it is out of scope for a commit-door
change the user has not ruled on. The fix, if the ruling is B, is one line: have
`chana_merged_row` read `chana_commit_vals` too. GR6h pins the divergence so that
closing it is deliberate.
