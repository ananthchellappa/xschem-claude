# 1314 — the wired Delete button changes what the simulator is asked to save, and destroys the PDK seed doing it

**Filed by item B5 (2026-09-04), whose implementation this refutes. The
implementation was REVERTED; this file is what survives it.** Status: **FILED,
NOT FIXED — and it is the BLOCKER on any re-land of B5.**

Preserved patch: `doc/claude/op_param_batch/B5_working_tree_REFUTED.patch`
(2224 lines, md5 `2bcc19ee49737ee0fbe187defb995f33`, applies clean to
`79f163cb`). **Do not apply it as-is.** Read "What the next crew must do first"
at the bottom.

---

## What was measured BEFORE (the Measure agent, verbatim)

```
BEFORE inert_say(Save) = <Save: the button column is built but not wired yet (item B5 wires it).>
BEFORE rdw_dialog_procs = <>
BEFORE rdw_op_procs = <>
BEFOREX blocks_before_after = 2 -> 2
BEFOREX conf_written_by_save = 0
```

The five buttons existed and were inert; nothing in `src/` called
`op_param_lists::` at all. Item B5 wired them, went green on every tier — window
76→96 (`--nogui`) and 86→107 (`:99`), store 86→93, keys 35→39, T1 at zero, T2
`HARNESS: PASS`, full audit 369/11/0/2 with the fail-name set byte-identical —
and was then refuted by its own adversary on three attacks. All three were
re-measured independently by the write-up agent on `./src/xschem` at `79f163cb`
before the revert.

---

## A5 — THE REFUTATION. Two Deletes remove the `.save` card. Ruling DD-4/DD-6 says they never can.

Ruling **DD-4**, as corrected by **DD-6**, is binding and unqualified:

> **Delete removes a parameter from what is DRAWN. It never changes what the
> simulator is asked to save.**

Measured, `--nogui`, two type tokens in one class, both registered
`{{id ids 0} {gm gm 1} {gds gds 1}}`, driving `rdw::_edit` + `rdw::_apply_now`
exactly as `rdw::button` does, broad scope (**the dialog's own default**):

```
SEED0        = {id ids 0} {gm gm 1} {gds gds 1}
PARAMS0      = {id ids 0} {gm gm 1} {gds gds 1}
DEL1(annot)  = ok {removed gm from the annotation list for class b5cls.}
PARAMS1      = {id ids 0} {gds gds 1} {gm gm 1}        <-- already REORDERED (1312)
SEED1        = {id ids 0} {gds gds 1} {gm gm 1}
DEL2(summ)   = ok {removed gm from the summary list for class b5cls.}
PARAMS2      = {id ids 0} {gds gds 1}                  <-- gm IS GONE
SHOWN2       = {id ids 0} {gds gds 1}
SEED2        = {id ids 0} {gds gds 1}                  <-- the PDK's row, gone
SIBPARAMS2   = {id ids 0} {gds gds 1}                  <-- the SIBLING type too
ADDBACK      = refused {gm is published by this run, but no list and no PDK
                        descriptor declares it - ... A PDK declares it with
                        op_annot::register.}
```

`op_annot::_cards_for` (`src/op_annot.tcl:2936`) emits one `.save` card per row
of `params`. After the second Delete there is no `gm` row, so there is no
`.save m1[gm]` card, so **the simulator is no longer asked to compute it** —
which is precisely the outcome DD-4 was written to forbid, and precisely the
outcome DD-6 re-derived after catching the driver's own one-field error.

Three things make it worse than a plain rule violation:

1. **It is irreversible inside the session.** `rdw::_find_triple` falls through
   annotation → summary → seed, and all three have lost the row, so **Add cannot
   put it back** through the only UI door there is.
2. **The refusal blames the PDK for a row xschem itself deleted.** *"no list and
   no PDK descriptor declares it … A PDK declares it with `op_annot::register`"*
   is false, and it sends the user to edit a PDK file that is correct. That is
   invariant **I3**'s family one layer up: a plausible wrong *sentence*.
3. **It reaches the whole class.** The sibling `type=` token lost the row too,
   because `apply` re-registers every mapped type of the class.

### Why it is not B5's bug to fix, and is B5's bug to have shipped

The mechanism is **issue 1312**, in `src/op_param_lists.tcl`, which item B5 may
not edit: `apply` writes `_save_set` (the union) into `params`, and `seed` reads
the PDK's list back out of **that same field** through `_params`
(`op_param_lists.tcl:700`). `_save_set`'s own in-code comment states the safety
argument:

> *"Taken over `effective`, NEVER `get_list`: an UNOWNED list answers the PDK
> seed, so the union can only ever be a SUPERSET of what `params` already held
> and no PDK row is ever lost."*

**That argument holds only while at least one of the two lists is unowned.**
The first Delete owns the annotation list; the second owns the summary list; the
union then consults no seed at all and the superset property is gone. B5 is the
first caller that can own both, so B5 is where a true comment becomes false.

**B5's error was to apply anyway.** The item's own decision D7 ("every mutation
applies immediately") was taken to keep Delete from looking like a broken
button, and it traded a binding ruling for a responsiveness preference. The
brief's own instruction covers this exactly: *"If your item seems to need
something a ruling forbids, STOP and say so in your write-up — do not implement
around it."*

---

## A6 — the broad arm edits a list the device on screen does not use, and reports success

`rdw::_scope_for` asks `owns flavor {<class> <exact cell name>}`. `effective`
narrows by **glob in file order** (ruling DD-8). Any flavor entry whose glob is
not literally the cell name — which is the only kind DD-8's file-order
precedence exists **for** — makes the two disagree. Measured:

```
A6 GOVERNING(before) = {id ids 0} {gm gm 1}      # flavor {b5cls *b5n*} governs M1
A6 SCOPE_FOR         = broad                     # owns flavor {b5cls devices/b5n} = 0
A6 EDIT              = ok {moved gds up in the annotation list for class b5cls.}
A6 GOVERNING(after)  = {id ids 0} {gm gm 1}      # byte-identical
```

The button reported moving a row that **is not in the list this device uses**,
in a list this device does not read. The DD-8 shadow warning exists in
`rdw::_edit` but is coded on the **narrow write path only**, so the broad path
is silent. The honest shape is for the broad base to be
`effective $cls $listname $cell` with the scope decided from what actually
matched, not from an exact-key `owns`.

## A7 — a `set_list` that silently reduced the list is reported as a plain success

`rdw::_index_of` looks a row up by **param**; `op_param_lists::set_list` dedupes
by **label** and returns 1 with a report (issue 1288's ruling: *"the user is
told once"*). `rdw::_edit` reads `_store_tail` only on the `set_list → 0` arm.
Measured:

```
A7 ANNOT(before) = {id ids 0} {gds gds 1}
A7 EDIT          = ok {added vgs to the annotation list for class b5cls.}
A7 ANNOT(after)  = {id vgs 2} {gds gds 1}        <-- the untouched `ids` row is GONE
```

IHP's own triples are exactly this shape (`{id ids 0}`, label ≠ param), so this
is the shipped PDK's case, not a contrived one. The brief named B5 as *"the
door"* for 1288; the door was built and the report was dropped on the floor of
the success arm.

---

## The two suite blind spots that let all three through 52 green checks

Recorded because the count was never the problem — the fence was.

* **BE3 fences ONE delete.** It asserts the card is still emitted after removing
  the row from the annotation list, which is true. The defect is one press
  later, and both per-row resets (`b5_lists_reset`, `be_reset`) re-`register`
  the descriptor, so the fixture **erases the state the defect needs** before
  the next row can reach it.
* **SD3 cannot fail.** It is the only row claiming the cursor rule end to end,
  but its fixture pushes M1 with `{ids gm gds}` and M2 with `{ids}` and maps
  **both** types to the same class, so "the newest block's first row" and "the
  row the cursor is in" produce a byte-identical store. Verify-B measured it
  green under both `SB-TARGET-PINNED` and `SB-SUBJECT-FROM-NEWEST`. It is the
  brief's row-V8 shape exactly: *a row written for a race, passing while the
  race is live, because the fixture already reached the state that hides it.*
* **Three more rows are stub-shadowed.** `BT10`, `BT12` and `BT17` install their
  answer by **replacing** `::rdw::scope_dialog`, so they stayed green under
  `SB-SCOPE-NEVER-ASKED`. Nothing on the `--nogui` arm proves a dialog is ever
  constructed.

---

## What the next crew must do first — and in this order

1. **Fix 1312 option (a) in `src/op_param_lists.tcl`: a separate descriptor key
   for the PDK's own declaration, written only by `op_annot::register`, read by
   `_params`.** Until `seed` means what its name says, no caller of `apply` can
   honour DD-4/DD-6, and *that is a B2-tier change, not a B5 one.* B5's Files
   cell forbids the file, so **B5 was mis-scoped**: it cannot be delivered
   without it. This needs its own item.
2. Then re-land the button column. Most of the reverted patch is sound and
   should be reused rather than retyped: the pure-function layer
   (`_locate` / `_row_param` / `_hdr_instname` / `_subject` / `_find_triple` /
   `_last_row_why`), the build/done/wrapper dialog split, and the headless
   drive. **Change before re-landing:** the broad base (A6), the success-arm
   `_store_tail` read (A7), the SD3 fixture (give M2 a parameter M1 lacks, or a
   second class), and a BE3 successor that deletes the same row from **both**
   lists and then asserts `_cards_for` and `seed`.
3. `rdw::_apply_now` must not run until step 1 lands, or must refuse any edit
   that would shrink the union below the seed.

## Still open (the adversary's residual risks, none of them fixed)

* The scope dialog's three state variables are namespace singletons with no
  re-entrancy guard: a dialog opened inside another's `tkwait` makes **both**
  calls return the inner answer. Script-reachable only while the grab holds.
* `_edit`'s narrow key is the literal cell name used as a `string match` glob. A
  cell path containing `[`, `*` or `?` would not match itself, and the DD-8
  shadow branch would then fire blaming a non-existent earlier entry.
* Decision **D11**: Up/Down on list 3 are enabled and refuse with a sentence,
  because `set_list` refuses to store the live list at all (ruling D-4). Spec
  §4.2 B7's table says *reorder* for all three columns. **That cell is not
  deliverable as written and the spec is wrong**, not the code.
* The dialog's narrow label reads *"this device flavor only (\<cell\>)"*, which
  a user may read as *"this device only"*. It is per-**cell**, and per issue
  **1310** it does not reach the drawn sheet at all.
* Issue **1313** stands: nothing calls `op_param_lists::load`, so *"reorder
  persists through Save and reload"* is provable inside one process only. The
  feature is not usable across a restart even once B5 lands.
* Issue **1278** goes live with the first working button: `effective`'s
  unbounded `string match` becomes reachable from a keypress. Inherited, not
  caused.
