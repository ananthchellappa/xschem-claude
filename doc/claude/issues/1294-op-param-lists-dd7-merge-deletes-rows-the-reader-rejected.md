# 1294 — under DD-7's read-modify-write, a writer classifier LAXER than the reader deletes the rows the reader rejected

✅ **FIXED 2026-09-04 by the DRIVER**, in the B2c re-do, by making `_row_id`
run **every gate the reader runs** — the live-list name, `_valid_list`, and
`_triple` for a `param` row — in the reader's own order.

**But the rule that was learned is not "share a key builder". It is "the two
doors reach the SAME VERDICT ON EVERY LINE".** This issue offered two fixes and
neither is quite it: `_parse_line` delegating to `_row_id` does not help if
`_row_id` is the laxer one, and `_row_id` gaining the gates today says nothing
about the gate somebody adds to `_parse_line` tomorrow. So the fence is
**row Y1**, which drives a fifteen-line corpus through *both* doors and asserts
they agree line by line — the divergence itself, not the one instance of it that
was measured. **Y1b** asserts the shared verdict is the *right* one, so agreeing
on a wrong answer cannot pass either.

Measured on this issue's own N3 fixture (startup restore, edit that class's
list, Save): `NEWROW_kept` **0 → 1**, and all **5/5** unreadable kinds survive
(row Y3). Sabotage — restoring the lax `_row_id` — reds **Y1, Y2, Y3** and
nothing else. `test_op_param_store_1245` 79 → **86**.

Feature A unmoved: `test_op_annot` 485, `test_annot_declutter_1244` 134,
`test_rdw_seam_1245` 49, `test_rdw_window_1245` 32, `test_ase_optier_0963` 94.

⚠ **STILL OPEN from this issue's "also measured" section:** a `>2`-element
flavor key is silently truncated by `_key`, so `owns flavor {mos *cap* JUNK}
annotation` answers 1. Not fixed here — the honest repair is for `owns` and its
siblings to validate through `_key_why` before building a key, which is wider
than this re-do, and item **B5**'s scope dialog is the first door that can
produce such a key.

---

*Original filing follows.*

**Status: ~~MEASURED, FILED, NOT FIXED.~~ THIS IS THE DEFECT THAT REFUTED ITEM
B2c.** Found by B2c's adversary pass and **reproduced first-hand by the
write-up agent** before the item was downgraded to F and the patch reverted.

**This is not a property of B2c's patch.** It is a property of **ruling DD-7's
shape**, and it will bite the next implementation the same way unless the
constraint below is designed in. That is why it has its own number rather than
a paragraph inside issue 1281.

---

## The one-sentence statement

DD-7 says *"you cannot delete a row you never parsed into a model."* **That is
only true if the writer cannot IDENTIFY a row the reader refused to parse.**
B2c's writer could, so it did, and the row died.

---

## What DD-7 promises

> **Writing a tier reads that tier's existing file, changes only the keys THIS
> SESSION actually changed, and writes it back. Every other row is preserved
> VERBATIM, including rows this build does not understand.**
>
> *Why the new shape cannot fail that way:* **you cannot delete a row you never
> parsed into a model.**

And the emitted file said the same thing to the user, in B2c's own header
(reverted patch, `_header_lines`):

```
# xschem edits only the rows it changed and leaves everything else in this file
# exactly as you wrote it -- your comments, your ordering, and rows a newer
# xschem wrote that this one does not understand.
```

## The measurement (2026-09-03, write-up agent, B2c working tree before revert)

Fixture — a settings file with one row this build understands and one it does
not, **both of the same key**:

```
version 2
param class mos annotation KEEP id 0
param class mos annotation NEWROW raw ratio
```

`load_conf` correctly **refuses** the second row and never stores it:

```
op_param_lists: <path>:3: kind "ratio" is not an integer: param class mos annotation NEWROW raw ratio
load=1 said=1
```

Then the session changes that key and saves:

```tcl
op_param_lists::set_list class mos annotation {{KEEP id 0}}   ;# setrc=1
op_param_lists::write_conf $p                                 ;# write=1
```

**Result — the file afterwards, verbatim:**

```
version 2
list class mos annotation
param class mos annotation KEEP id 0
```

```
write=1 writereports=0 NEWROW_kept=0
```

**`rc=1`, ZERO write-time reports, and the user's row is gone.** That is
byte-for-byte the signature that refuted **B2a** (`class mydiode diode`
deleted) and **B2a-2** (`class nmos mos` deleted for agreeing with a default):
success reported, nothing said, a typed line destroyed.

Reproduced for **5/5** unparseable kinds — `ratio`, `v`, `1.5`, `op:gm`, `-`.

### The narrowing, measured exactly

A **direct `load_conf`** stamps every key it reads as session-dirty (B2c's own
ladder-L2 decision, *"importing a file into your session IS a session change"*),
so after one the whole file is dirty and the key you changed is irrelevant. The
startup restore `load` passes `stamp 0`. All three cases measured:

```
N1  load_conf(stamp=1) + change a DIFFERENT key : write=1 NEWROW_kept=0 said=0
N2  load_conf(stamp=0) + change a DIFFERENT key : write=1 NEWROW_kept=1 said=0
N3  load_conf(stamp=0) + change THE SAME key    : write=1 NEWROW_kept=0 said=0
```

**N3 is the real Save path** — startup restore, the user edits one class's list
in B5's dialog, Save. **N1 is every import.** The row survives only in N2, where
the user changed some *other* class.

**So the blast radius is: every `list`/`param` row of every key the user
touches, plus every row of a file that was imported with a direct `load_conf`.**

## The root cause, and the plan forbade it in writing

Two builders, deliberately different in strictness:

| door | validates |
|---|---|
| `_parse_line` (the READER) | verb → arity → scope → **`_valid_list`** → **livelist guard** → **`_triple`** |
| `_row_id` (the WRITER's merge classifier) | verb → scope → arity. **Nothing else.** |

`param class mos annotation NEWROW raw ratio` is 7 fields, verb `param`, scope
`class` — so **`_row_id` identifies it as key `{class mos annotation}`** while
`_parse_line` threw it away at the `_triple` gate. `_merge_lines` then finds
the key dirty, replaces the whole group at its first line, and drops every
later line of it.

`_row_id`'s own comment claimed the opposite:

```
## ONE FIELDS-TO-KEY BUILDER, used by the READER and by the WRITER's merge
## classifier (invariant I1).
## ... a row the writer cannot identify is a row it copies verbatim, which is
## the safe direction under DD-7.
```

`grep -n _row_id` on the reverted patch: **definition at :477, exactly one call
site at :1233, inside `_merge_lines`.** `_parse_line` still built its key
inline. **The comment was false**, and the item's own plan had named the hazard
in advance:

> ONE FIELDS-TO-KEY BUILDER, `_row_id {f}`, used by `_parse_line` AND by the
> writer's merge classifier — LADDER L1, INVARIANT I1. The alternative is a
> second, laxer grammar reader inside write_body, and when the two disagree the
> writer either duplicates a row or replaces the wrong one, **silently**.

The alternative was built, the predicted consequence occurred, and no row in a
79-check suite could see it.

## Why the suite could not see it

B2c's row **T4** proves *"a row this build does not understand survives a
save"* with the fixture row `sometotallyfuturerow whatever 1` — an **unknown
verb**. `_row_id` rejects an unknown verb at its first line, so T4 exercises the
one class of unrecognised row the classifier genuinely cannot identify. **The
row that matters is a KNOWN verb with a field this build cannot read**, which is
exactly what a newer xschem writes when it extends a value vocabulary rather
than adding a keyword. T4 passes; the promise is false.

## The fix, named

Make the writer's classifier **no laxer than the reader**. Either:

1. **`_row_id` runs the reader's remaining gates** — `_valid_list`, the
   livelist guard, and `_triple` for a `param` row — and returns `{}` when any
   of them fails; or
2. **the shape the plan actually specified:** `_parse_line` calls `_row_id`, so
   there is genuinely one builder and the two cannot diverge again.

(2) is better and is what invariant I1 asks for. Under either, a row this build
does not understand is copied verbatim, which is what DD-7, the emitted header
and `_row_id`'s own comment already claim.

**⚠ And it needs a fence that generates its own case.** The acceptance row must
construct an unrecognised row **of a known verb and a dirty key** — not an
unknown keyword. Suggested shape: for each reader gate (`_valid_list`, the
livelist name, a non-integer kind), write a file carrying one row that fails
exactly that gate beside one row that passes, change the key, save, and assert
both rows are present.

## Also measured in the same pass (secondary, same patch)

* **A `>2`-element flavor key is silently truncated by `_key`**, so
  `owns flavor {mos *cap* JUNK} annotation` → **1** and `get_list` returns the
  entry, while `set_list` with the identical key → **0 with a report**. Three
  doors, two rules — a **new** two-door disagreement of exactly the class issue
  **1288** was filed about, introduced by the fix for it. Latent (no caller
  passes a 3-element flavor key today); **B5's scope dialog is the first door
  that could**.

## Still open

* Whether the same laxity exists anywhere else in the tree's writers. B2c's was
  the first read-modify-write in `src/*.tcl` (`ase::sim_write_conf`,
  `write_net_hilight_style_conf` and `write_recent_file` all rewrite whole), so
  there is no second instance **yet** — and this issue is the reason to check
  before adding one.
