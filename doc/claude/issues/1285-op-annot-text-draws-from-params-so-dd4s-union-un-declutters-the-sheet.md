# 1285 — `op_annot::text` draws from `params`, so DD-4's union un-declutters the sheet

**Status: FIXED by item B2b, 2026-09-03 — and one of this issue's own
recommendations ("Still open" item 2) is REFUTED BY MEASUREMENT; see §Fixed at
the end.**
Filed by item **B2a**, 2026-09-03, while implementing ruling **DD-4** (issue
1280). Latent today: nothing calls `op_param_lists::apply` yet, and item **B5**
is the first thing that will.

## 1. The claim

Ruling **DD-4** has two clauses:

> `apply` writes the **union** of the annotation and summary lists into
> `params`, **and the display narrows to the annotation list.**

**Those two clauses cannot both be true of one field, and `params` is one
field.** MEASURED: `op_annot::text` (`src/op_annot.tcl:1726`, the `params` loop at
`:1741`) builds the
**on-sheet annotation rows** by iterating exactly the same
`dict get $d params` list that `op_annot::_cards_for`
(`src/op_annot.tcl:2808-2820`) turns into `.save` cards. One list, two
consumers, and DD-4 asks them to differ.

## 2. What B2a attempted, and why this issue outlives its revert

> **NOTE, 2026-09-03: item B2a was REVERTED in full** (its adversary pass
> refuted the batch's central claim). So the union described below is **not in
> the tree** — `apply` still writes the annotation list alone. **This issue is
> unaffected and still blocks B5**, because it is a property of
> `src/op_annot.tcl` at `825cd3bd` plus ruling **DD-4**, not of B2a's code: the
> moment *anyone* implements DD-4's first clause, its second clause needs a
> field that does not exist. Answering it before the re-do is strictly cheaper
> than after.

### What B2a attempted, and what it therefore left open

Item B2a's (reverted) attempt implemented the **save** half — the half whose failure is silent,
destructive and invisible on a schematic (invariant **I3**): `apply` now writes
`union(effective <c> annotation, effective <c> summary)` into `params`, so
trimming what is drawn can never stop the simulator computing what list 2 still
asks for. Rows `A3` and `A4` of `tests/headless/test_op_param_store_1245.tcl`
fence it.

B2a owns four files and `src/op_annot.tcl` is not one of them, so the **display**
half is this issue.

## 3. The consequence, stated plainly

Until this lands, a user who deletes a row from the annotation list will see

* the deck keep saving it — **correct**, per DD-4; and
* **the row still drawn on the sheet** — the opposite of the user's own word
  *declutter*, which is the word the whole feature is named after.

That is why this blocks **B5**, the item that ships the Delete button. Shipping
Delete against today's `op_annot::text` would ship a button whose visible effect
is nothing at all.

## 4. The two options, and the question for the user

**Option 1 — a new descriptor key the display prefers over `params`.**
`op_annot::text` reads e.g. `dict get $d shown` when present and falls back to
`params`. This is issue 1280's *rejected* Option 2, now unavoidable, and it is
the smaller blast radius: one dict key, one `if`, and `_cards_for` is untouched.
Cost: two lists in one descriptor, and a PDK author has to be told which is
which.

**Option 2 — `op_annot::text` calls `op_param_lists::effective` directly.**
No new dict key, and the narrowing has exactly one definition
(`effective <c> annotation`, which row `A4` already asserts by name for this
reason). Cost: `op_annot.tcl` gains a dependency on `op_param_lists.tcl`, which
today is one-way in the other direction — and `op_annot.tcl` is sourced first.

**Rejected already:** writing an inert display key into the descriptor dict
*from* `op_param_lists.tcl`, which invents a dict-shape contract no consumer
reads. **Rejected already:** leaving `apply` narrowing — DD-4 forbids it and
invariant I3 is why (issue 1280 §the measurement).

**On the owed ledger as a `rule` debt.** The choice is user-visible in the sense
that it decides where a PDK author declares "draw this" versus "save this", so
it is the user's to make; the cost is bounded either way and named above.

## 5. Acceptance rows this will need

* after `apply` with a trimmed annotation list, `op_annot::text` emits a row for
  every **annotation** entry and **no** row for a summary-only one, while
  `_cards_for` still emits a card for both (the A3/A4 pair, one layer out);
* a descriptor a PDK registered with no narrowing at all still draws every
  `params` row, unchanged — invariant **I7**'s shape for this field.

---

## Item B2a-2 — DD-6 IMPLEMENTED, MEASURED, AND REVERTED, 2026-09-03

B2a-2 implemented ruling **DD-6** in full and the feature worked: a new optional
descriptor key **`shown`** (this issue's own spelling), preferred by
`op_annot::text` and falling back to `params` when absent; `apply` writing
**both** fields; `_cards_for`, `_claims` and `_kind` deliberately left on
`params`; one line naming the split in `op_annot.tcl`'s key table and in all
three PDK `_procs.tcl` files. Rows **A5**–**A8**, **C2** and **J5** fenced it
red-first, `test_op_annot` stayed at **485/492** and
`test_annot_declutter_1244` at **134**.

**It was reverted with the rest of the item**, and two of the adversary's
refutations land on DD-6 itself.

### Refutation 1 — the subset guarantee is false, and `apply` produces the violation

B2a-2's own code comment asserted:

> `shown` is always a SUBSET of the union by construction, which is what keeps
> `op_annot::_kind` total — it raises for a param that is not in `params`.

Measured by the adversary. `_save_set` dedups by **label**; the annotation list
is stored **unreduced**; `set_list` accepts two triples sharing one label with
rc=0 and zero reports. So:

```
params = {A ids 0} {id ids 0} {gm gm 1}
shown  = {A ids 0} {A vth 2}
```

`{A vth 2}` is **drawn** and is **not in `params`**, so `op_annot::_kind MT0 vth`
and `op_annot::vector MT0 vth` both **raise**. The same run makes `_cards_for`
emit `.save @m.mt0[ids]` **twice**, against measured rule **R1**. The root cause
is a HEAD defect in the store's own door and is filed separately as **1288**;
DD-6 is what makes it reachable.

### Refutation 2 — a new draw-time raise door, denied in writing

`op_annot.tcl`'s comment claimed the proc *"gains no raise site that issue 0447
does not already cover"*. Reproduced first-hand by the write-up agent:

```
dict exists shown  : 1                              (the guard passes)
dict get   shown   : rc=0 -> <{a>                   (no raise here)
foreach over it    : rc=1 -> <unmatched open brace in list>   <== DRAW-TIME RAISE
same with params only, shown absent: rc=0
```

`register` validates only `dict size`, so a descriptor carrying `shown` = `{a`
registers cleanly and then **raises on every redraw** — in a proc C calls per
instance per redraw (`src/actions.c:2088`), with `params` perfectly well formed.
At HEAD no such descriptor can exist, because the key does not. It is a **new**
door into issue **0447**'s hazard, and the comment asserting otherwise is the
kind of sentence this batch reverts items over.

## Still open — what the third crew must do with DD-6

1. **Do not assert the subset; enforce it, or stop relying on it.** Either fix
   **1288** in the same pass (so `shown ⊆ params` is true of every list the
   store accepts) or make `_kind`/`vector` answer rather than raise for a row
   they do not know.
2. **Validate `shown` where it enters, not where it draws.** `register` is the
   place — one `catch {llength …}` there costs nothing per redraw and closes the
   raise door. Do not add the guard inside `op_annot::text`.
3. **`derived` is a third consumer and DD-6 does not mention it** — filed as
   **1289**, and it needs a ruling before B5 ships the button.
4. **Everything else about DD-6 held.** The key name, the fall-back, the
   `_cards_for`/`_claims`/`_kind` split, invariant **I7**'s row (all four
   shipped PDK register sites declare `params` alone and behave exactly as
   before) and the empty-`shown`-draws-nothing decision were all fenced and none
   was refuted. Apply
   `doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch` and fix only
   the two points above.


---

## Fixed — item B2b, 2026-09-03 (pure Tcl, no build)

**What shipped.** A second descriptor key, `shown` (ruling **DD-6**).
`op_annot::text` prefers it and falls back to `params`; `_cards_for`, `_claims`
and `_kind` stay on `params` and were not touched. `op_param_lists::apply`
writes both fields: the **union** of the annotation and summary lists into
`params` (what the run computes) and that union **filtered by the annotation
list's labels** into `shown` (what the sheet draws). Three PDK `_procs.tcl`
files gained one comment block each naming which list is which.

**The two amendment guarantees, built rather than asserted.**

1. **Subset by construction.** `op_param_lists::_show_set` filters the very list
   it is about to write into `params`, so every element of `shown` is literally
   an element of `params` — for every input, **including** issue **1288**'s live
   duplicate labels, and without depending on 1288 ever being fixed (that is
   item B2c's). This is what replaces "Still open" item 1: the subset is
   *enforced by derivation*, not by fixing the store and not by softening
   `_kind`. On top of that, the draw side contains it independently: a `shown`
   row whose label is in no `params` row draws **blank** — no read, no `_kind`,
   no raise (**I3**). Fenced by row **D5**, which computes the membership under
   1288's own input rather than reading a comment.
2. **A malformed key never raises.** `op_annot::_display_rows` copies the
   `op_annot::_matches` idiom (`dict exists` → catch the `dict get` → catch the
   walk → a DATA answer) with **the catch enclosing the `lindex` of every row**.
   Fenced by row **D6**, which registers both measured shapes.

> ⚠ **"STILL OPEN" ITEM 2 IS WRONG AND WAS NOT FOLLOWED.** Its sentence —
> *"Validate `shown` where it enters, not where it draws. `register` is the
> place — one `catch {llength …}` there costs nothing per redraw and closes the
> raise door. Do not add the guard inside `op_annot::text`."* — fails on the
> measurement. Two malformed shapes reach the draw and a `llength` check closes
> only one:
>
> ```
> shown = {broken            ->  llength RAISES  'unmatched open brace in list'
> shown = {id id 0} {d "x}   ->  llength == 2 ;  lindex of row 2 RAISES
>                                                'unmatched open quote in list'
> ```
>
> A register-side check therefore leaves the nested shape open, and a
> register-side *raise* would reject the whole descriptor — strictly worse than
> ignoring one key. The **DD-6 amendment** overrules the sentence anyway (*"a
> key that does not parse as a list is treated as absent, full stop"*), and per
> the crew brief the ruling wins where it and a document disagree.

**Issue 0447's door is deliberately still open.** The fallback returns *nothing*
— `op_annot::text` still walks `params` unvalidated, so a malformed `params`
still raises exactly as it did. A blanket catch there would close a filed defect
by accident and turn it into a silently blank sheet. Row **D7** fences that from
this side and `test_op_annot`'s **K17** from the other.

**Where the evidence is.** `tests/headless/test_op_param_store_1245.tcl` section
D (rows **D0**–**D10**) and row **C2**; row **A1**'s `params`/`shown` goldens
were revised for DD-4's union. 39 → 51 checks; 8 red at HEAD before the change.
`test_op_annot` (485 / 492) and `test_annot_declutter_1244` (134) unmoved.

**Not fixed here, and not this item's:** issue **1288** (B2c), issue **1287**
(`seed` reads the field `apply` overwrites — now *wider*, since it answers the
union), issue **1279**.

**Status E, unratified — recorded as rule debt `1285_empty_display_key`.** A
`shown` key that is **present and empty** draws no `params` rows; only an
*absent* key falls back. So deleting every row of a device's annotation list
makes its whole OP block vanish from the sheet — and because
`src/actions.c:1764` → `annot_instance_annotated()` → `annot_block_has_value()`
reads the *rendered* block, the device also drops out of the declutter and the
texts the declutter was hiding come back. The default falls this way because the
alternative makes item B5's Delete of the **last** row a silent no-op, which is
the invisible-Delete failure DD-6 exists to prevent. The effect is not uniform:
a descriptor that also carries `derived` or `pinexpr` rows still draws a block
(row **D10**'s second half).

---

## The decisions this item took, with the ladder rung and the rejected alternative

| # | Decision | Rung | Rejected, and why |
|---|---|---|---|
| 1 | Key name **`shown`**; the narrowing **selects out of the `params` pass** rather than replacing it. | **L2** on the name (this issue's own spelling, and B5 will look for it); **L1 / I1** on the mechanism — one loop touches the raw. | `display` / `draw` / `annotation` (orphan this issue's text). B2a-2's swap of the loop's list (blanks the derived rows — issue **1289**). A second read loop (a new `xschem` call per row per instance per redraw). |
| 2 | A display row whose label is in no `params` row draws **blank** — no read, no `_kind`, no raise. | **L1 / I3** — blank, never a plausible number, never a raise. | Letting the display path call `_kind` (that raise **is** refutation 1 of B2a-2). Reading the raw for the unknown label (a new `xschem` call). |
| 3 | **Present-and-empty is NOT absent**: an empty `shown` draws no `params` rows; only an absent key falls back. | **L3 — STATUS E**, rule debt `1285_empty_display_key`. | Treating empty as absent, which makes B5's Delete of the **last** row a silent no-op — the invisible-Delete failure DD-6 exists to prevent. |
| 4 | The malformed-key guard **walks the rows**, and the fallback hands back `params` **unvalidated** so issue 0447's door survives. | **L1 / I3** + the DD-6 amendment. | A register-side `catch {llength …}` (does not close the nested shape; a register-side *raise* rejects the whole descriptor). A blanket catch around the row build (closes **0447** by accident and reds `test_op_annot` **K17**). |
| 5 | `apply` derives `shown` by **filtering the union** by the annotation list's labels. | **L1 / I3** + the amendment's first guarantee. | B2a-2's `_show_set {cls} {return [effective $cls annotation]}` — the wholesale copy the adversary refuted. |
| 6 | `apply`'s ownership guard becomes **`annotation` OR `summary`**. | **L1 / I3.** With the annotation-only guard a summary-only user gets nothing written, the deck never saves her parameters, and every summary row renders permanently blank with no report. | Keeping the annotation-only guard. Measured cost of the change: the sheet is byte-identical (`shown` = the PDK seed), only the deck grows — DD-4's stated cost. |
| 7 | `apply` runs **two passes**; the first touches nothing. | **L1 / I1** — one seed, read once, before anything rewrites it. | One loop, which lets `nmos`'s re-registration become the seed `pmos` reads (both map to `mos`, `nmos` sorts first — reachable, not theoretical). |
| 8 | All new rows go in `test_op_param_store_1245.tcl`, on a fixture built from `devices/nmos.sym` + `op_annot::vector`. | **L2.** A suite pinned by count cannot also be where new rows land. | Rows in `test_op_annot` (485/492 are a hard acceptance row). A hand-typed vector name (would fork **I1**'s single builder). |
| 9 | Issue **1279**'s `_apply_cands` fix was **not** taken. | **L2.** It sits in the preserved patch beside the DD-6 hunks and is tempting; the split exists to stop nine interlocked issues riding on one commit. | Taking it. |

## The sabotage matrix (Verify-B, re-run against the landed code)

**8 planned variants + 3 the adversary added. Every predicted red appeared —
there were NO missing predicted reds.** Several variants red *more* rows than
predicted, which is a superset and not a hole.

| Variant | Predicted | Observed |
|---|---|---|
| `display_ignored` (`_display_rows` stubbed to `{0 {}}`) | D2 D5 D10 | **D2 D4 D5 D8 D10** |
| `presence_only_guard` (B2a-2's exact refuted guard) | D6 | **D6 exactly** — both shapes fired: `RAISED:unmatched open brace in list` and `RAISED:unmatched open quote in list` |
| `vars_follow_the_sheet` (the params loop walks the narrowed list) | D4 | **D2 D4 D7 D10** |
| `show_set_copies` (B2a-2's wholesale copy) | D5 | **D5 exactly** — `shown` gained `{A gm 1}`, in no `params` list; the row's own membership computation returned 0 |
| `show_set_empty` | D2 D5 D8 | **A1 D2 D4 D5 D8** |
| `guard_annotation_only` (HEAD's guard) | D8 | **D8 exactly** |
| `no_union` (HEAD's `_save_set`) | A1 D2 D3 D8 | **A1 D2 D3 D4 D5 D8** |
| `blanket_catch` (the read-side catch applied to `params` too) | D7 + `test_op_annot` K17 | **both exactly** — the store's D7 red **and** `test_op_annot` at `1 FAILED (484 passed)` on K17 |
| `d9_probe` *(added)* — a catch-wrapped `xschem get current_win_path` at the top of `text` | D9 | **D9 exactly** |
| `one_pass` *(added)* — apply's two passes collapsed into one | D8 | **D8 exactly**, by the claimed mechanism: `pmos`'s `shown` became the union `nmos` had just been registered with |
| `c2_one_file` *(added)* — the sentence stripped from `gf180_procs.tcl` **alone** | C2 | **C2 exactly** — so C2 checks all three PDK files, not just the first |

Baseline green after restore; no sabotage residue.

## Still open after B2b (the adversary's residual risks)

Verify-C did **not** refute the central claim: an 11-descriptor A/B against
HEAD's own procs `diff`ed **empty** (I7), 25 malformed `shown` shapes raised
**zero** times, and 200 `apply` combinations produced **zero** subset
violations. What it found, and what nobody has fixed:

1. **A new raise door in `apply` — issue 1291.** `_save_set`/`_show_set` walk
   `effective`, which falls through to `seed`, i.e. the registered `params`
   **string, unvalidated**. A/B: HEAD `rc=0`, after B2b `rc=1 unmatched open
   brace in list`. Latent (no caller until B5) but it is a raise door added by a
   change whose amendment exists because of a raise door.
2. **Narrowing is one-way — issue 1292.** Nothing removes `shown`; `reset` +
   `apply` leaves the sheet narrowed for the session. B5's Reset button.
3. **A duplicate `params` label splits the sheet from the derived row — issue
   1293.** The label→value cache is FIRST wins, `_evalrow` is LAST wins.
   Unreachable through `apply`.
4. **Row D9's fence is weaker than its wording.** It counts the literal
   `xschem ` in `op_annot::text`'s body, but the proc's raw traffic goes through
   `op_annot::raw_or_blank`, which carries no such literal. A future second read
   loop written through `raw_or_blank` would double the per-instance-per-redraw
   traffic DD-9 forbids and D9 would stay green. Not filed as its own issue:
   it is a note for whoever next edits that proc, recorded here and in PLAN.md.
5. **A `shown` that parses but is not a list of triples is drawn literally** —
   the bare string `id id 0` yields three rows. Consistent with the amendment as
   written ("does not parse as a list" = absent), but a PDK author who forgets
   the outer braces gets silent garbage rather than a fallback.
6. **The declutter can be switched off by narrowing**, via `actions.c:1764` →
   `annot_instance_annotated()` → `annot_block_has_value()` on the rendered
   block. This is decision 3's status-E question and is on the owed ledger.
7. **One non-reproducible red, recorded rather than waved through.** Verify-C's
   first `--nogui` run of the store suite gave `FAIL: D9 … {2 0 0 0}` — two
   `xschem ` literals in the stripped body — not reproduced in 10 further runs
   (6 sequential, 4 concurrent), with another agent's suites live in the same
   tree throughout. D9 is a **source-text** check and is uniquely sensitive to
   reading `src/op_annot.tcl` mid-write. The CLAUDE.md rule about running suites
   solo (issue **0990**'s class) applies to source-text rows too.
8. **A green suite is still not an eyeball.** `apply` has **no caller** in
   `src/`, `xschem_library/` or any PDK tree — B5 is the first — so everything
   above is measured through direct proc calls. The narrowing's appearance on a
   real schematic is unverified by anyone; the `DD-6 narrowing on the schematic`
   look debt (recorded by B2a-2, listed as stale after its revert) is **true
   again verbatim** and was deliberately not re-filed.
