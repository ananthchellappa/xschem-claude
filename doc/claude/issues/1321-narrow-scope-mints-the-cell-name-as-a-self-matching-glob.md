# 1321 — a narrow scope key that self-matches can still match siblings

**Status:** FILED, NOT FIXED — **and now open in BOTH halves.** Measured
2026-09-04 on `fluid-editing` at `c940a5df` + item B5-2's working tree. ⚠ Item
B5-2 was **REVERTED** (blocker: issue **1322**), so the loud half described below
as fixed lives only in
`doc/claude/op_param_batch/B5-2_working_tree_REFUTED.patch` (md5
`c51587ad91d65a05bbd07930ff237f9b`), not in `src/`. Re-land it with the rest.
**Component:** `src/rdw.tcl` (`rdw::_edit`, narrow arm) · `src/op_param_lists.tcl`
(`effective` / `governs`, the flavor scan)
**Related:** ruling DD-2 (flavor beats class beats seed), ruling DD-8
(precedence is FILE ORDER, nothing is ranked), issue 1311 (the pane cannot
reorder flavor *entries*), issue 1294 (three doors, two key rules).

## The measurement

The scope dialog's narrow radiobutton says *"this device flavor only
(`<cell>`)"*, and `rdw::_edit` mints the store key `{<cls> <cellname>}`. That
key's second field is **not a literal**: `op_param_lists::governs` (and
`effective` through it) matches it with `string match -nocase` against the cell
name of every device of the class. So the key the button writes is a **glob**,
and the cell name is being used as a glob pattern for itself.

Measured with `string match -nocase $c $c` over cell names, on this tree:

| cell name | self-matches | also matches |
|---|---|---|
| `b5n.sym` | yes | only itself |
| `a[bc].sym` | **no** | — |
| `a\b.sym` | **no** | — |
| `a*b.sym` | yes | `ab.sym`, `axxb.sym`, every sibling with that stem |
| `a?b.sym` | yes | `axb.sym`, `a1b.sym`, … |

## What item B5-2 fixed, and what it did not

**Fixed:** the rows that do *not* self-match. Written, such a key answers
nothing for the very device it was minted for — and `rdw::_shadow_why` would
then fire ruling DD-8's sentence, blaming *"an entry declared earlier in the
settings file"* that does not exist. One wrong sentence produced by the code
written to remove another. `rdw::_edit`'s narrow arm now refuses up front with
its own sentence, names the class-wide alternative, and stores nothing. Fenced
by window row **BT28**, whose second half is the control: an ordinary cell name
goes through the same door and is accepted, so the guard is about self-matching
and not about narrow scope.

**Not fixed, and this is the issue:** `a*b.sym` and `a?b.sym` **do** self-match,
so the guard passes them — and the entry then silently governs every sibling the
pattern reaches. The user asked for *this device flavor only* and got a class of
them, with nothing said.

## Why it was not fixed here

* The guard **cannot tell a deliberate glob from a literal**. A user editing the
  settings file by hand writes `{mos *nfet*}` on purpose; ruling DD-8 is built on
  that. The store cannot distinguish that entry from one the button minted.
* **Refusing every cell name containing `*` or `?`** would refuse a legal
  filename for a case nobody has hit — no PDK in this tree ships one — and would
  make the narrow button unusable for that user with no way out.
* **Escaping the metacharacters at the writer** (`a\*b.sym`) is the wrong side of
  the seam: `_key_fields`' own comment in `src/op_param_lists.tcl` records why
  the store's key grammar is whitespace-delimited and un-escaped, and an escaped
  key would not round-trip through the settings file the user is meant to read.

## Recommended option

Give the flavor scan an **exact-match key form** alongside the glob one, so the
button can mint a key that means *this cell and no other* and a hand-written
settings file keeps its globs. The cheapest shape that does not fork the
narrowing (invariant I1): let the stored key carry the distinction, e.g. a
leading `=` meaning literal, matched with `string equal` instead of
`string match`, decided in **one** place — `op_param_lists::governs`, which item
B5-2 made the single scan for exactly this kind of change. Rejected alternative:
a fourth scope beside `class`/`flavor`, which doubles ruling DD-2's precedence
table for one bit of information.

## Acceptance rows for the fix

1. A narrow Delete on a cell named `a*b.sym` writes a key that governs `a*b.sym`
   and **not** `axxb.sym`, and `effective` for the sibling still answers the
   class list.
2. A hand-written `{mos *nfet*}` row in the settings file keeps matching every
   `*nfet*` cell — ruling DD-8's own case is unchanged.
3. Both key forms survive a `write_conf` / `load_conf` round trip byte-identically
   (ruling DD-7).
4. `governs` remains the only place either form is matched: `rw_count` of the
   match call in `src/op_param_lists.tcl` stays 1.
