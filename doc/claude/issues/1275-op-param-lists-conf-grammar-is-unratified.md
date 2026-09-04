# 1275 — the `op_param_lists.conf` grammar is unratified

**Status: RULE DEBT.** Driver decision DD-3 rules that the settings file is
**data, read by a strict parser, never sourced**, and states the cost (~40 lines
of parser). It does **not** state the grammar. Item B2 had to pick one and
shipped it; this issue carries it verbatim so the user can rule on it before
item B5 starts writing files with it and before a team checks one in.

## The grammar as shipped

```
# a whole-line comment ; blank lines are skipped
version 1
class  <type-token> <broad-class>
list   <scope> <key> <listname>
param  <scope> <key> <listname> <label> <rawparam> <kind>
```

* `scope` is `class` or `flavor`; a flavor key is a **cell-name glob**, matched
  `string match -nocase`, the same narrowing `op_annot::_matches` performs.
* `listname` is `annotation` or `summary`. Section 4.2's third list, `all`, is
  **live from the simulator and never persisted** (ruling D-4): `owns` answers 0,
  `effective` answers `{}`, and a row naming it is reported and skipped.
* `kind` is any **integer** — deliberately not stricter than `op_annot::_wrap`,
  whose default arm copies token.c's "anything but 0/1 is `v(...)`".
* Fields are **whitespace-delimited** and are split with
  `regexp -inline -all {\S+}`, never by treating the line as a Tcl list.
  Measured: `llength {mos annotation { id 0}` **raises** `unmatched open brace in
  list`, so a stray `{` in a teammate's file would kill the reader from inside.
* Every row is **self-contained**, so skipping a malformed one cannot silently
  reassign the rows after it.
* **The first `param` or `list` row for a given (scope,key,listname) in a file
  CLEARS what an earlier tier put there.** That is what makes the project file
  win over the user-global one rather than append to it.
* A `param` row implicitly declares its list. `list` exists only so an **emptied**
  list can be expressed; losing a `list` line degrades to the PDK seed, which is
  the safe direction.
* `-encoding utf-8` is pinned on **both** channels; `-translation` is left at
  `auto`, which is what already handles CRLF.

## The one place this REFINES a driver decision

DD-3's own sentence says the project file wins **per class**. B2 shipped the win
**per (scope, key, listname)** — finer, never coarser — so a project file that
customises `mos annotation` no longer silently discards the user-global's
`mos summary`. Ladder L2. The row that flips if the driver disagrees is **T2**
of `tests/headless/test_op_param_store_1245.tcl`, and the change is one `foreach`.

## Rejected

* **A `.tcl` settings file** — one-line `source`, free comment and quoting rules.
  Forbidden by DD-3, and demonstrated on this tree: a conf whose payload is
  placed **first** under a friendly header gave `OPL_PWNED=1 marker_on_disk=1`,
  and the Tcl error that followed was cosmetic because the payload had already
  run.
* **`action_parse_csv_line`** (`src/action_registry.tcl`) — adds a quoting
  grammar for a value space this feature does not have, and its own comment
  records an unterminated-quote failure mode.

---

# ⚠ GRAMMAR v2 — DESIGNED BY ITEM B2a, 2026-09-03, **THEN REVERTED**

> **THE GRAMMAR IN THE TREE IS STILL v1.** Item B2a designed, implemented and
> suite-fenced the v2 below, and was then reverted in full: its adversary pass
> refuted the batch's central claim and the write-up agent reproduced three
> attacks independently, so `src/op_param_lists.tcl` is byte-identical to
> `825cd3bd`. The v2 design is preserved as a **proposal** — the code is in
> `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch`.
>
> **The deadline is unchanged and the migration is still free.** Nothing writes
> a flavor row until item **B5**, so v2 can still land as an edit rather than a
> migration — but it must land with the two holes B2a's own version had, both
> found after it was green:
>
> * **precedence does not deliver DD-2** — `_flavor_order` ranks by fewest `*`,
>   so a bare `*` beats `*nfet_01v8_lvt*` in both insertion orders (issue 1277),
>   while the comment `write_body` writes into every settings file promises
>   "narrowest matching glob of that class wins";
> * **the round trip corrupts any glob carrying a Tcl list metacharacter** —
>   the writer interpolates a list representation, the reader splits on
>   whitespace, so `a[nm]fet*` comes back brace-quoted and can never match, with
>   zero reports on either side.
>
> Read the section below as the proposal it now is, not as the tree.

Item **B2a** changed the grammar this issue exists to ratify, and did it now
rather than later **because the window was closing**: item **B5** writes the
first flavor entry into a real settings file, and after that this is a
*migration* instead of an edit. The change is forced by issue **1277**, which
measured that a v1 flavor entry carries **no class**, so `effective` scanned
flavor entries across classes and a MOS flavor answered a `capacitor` query
whenever its glob happened to match. There was no way to spell *"flavor X of
class mos"* at all.

## The grammar as B2a proposed it (NOT in the tree — see the banner)

```
# a whole-line comment ; blank lines are skipped
version 2
class  <type-token> <broad-class>                                    # 3 fields, UNCHANGED
list   class  <class> <listname>                                     # 4 fields, UNCHANGED
list   flavor <class> <glob> <listname>                              # 5 fields, WAS 4
param  class  <class> <listname> <label> <rawparam> <kind>           # 7 fields, UNCHANGED
param  flavor <class> <glob> <listname> <label> <rawparam> <kind>    # 8 fields, WAS 7
```

Everything else in this issue stands unchanged: whitespace-delimited fields split
with `regexp -inline -all {\S+}`, self-contained rows, first-touch-clears, the
`all` refusal, integer `kind`, pinned UTF-8 with `auto` translation, and the
per-(scope,key,listname) tier win.

## The three sub-decisions inside it, each with its rejected alternative

1. **A separate whitespace-delimited FIELD, not a `<class>/<glob>` composite.**
   Measured, not tasteful: every shipped `match` glob in this tree carries a
   slash — `{*sky130_fd_pr/*}` (13 occurrences), `{*sg13g2_pr/*}`,
   `{*gf180mcu_pr/*}` — so a composite is split-once-and-hope. A separate field
   is unambiguous, and a single key field already refuses whitespace.
   *Also rejected:* variable arity via `args` on owns/get_list/set_list, which
   grows a dispatch in three verbs.
   *Also rejected:* a **four-element internal key**. It would move `lindex $k 2`
   off the listname and silently break issue **1279**'s own recommended snippet.
   The shipped shape keeps the store key at three elements, the flavor key's
   middle field being the two-element list `{<class> <glob>}`.

2. **A v1 flavor row read by the v2 parser is REPORTED AND SKIPPED, never
   migrated by inference.** The class was not expressible in v1, so any value the
   parser picked — from the glob, from the class map, from anything — would be
   invented data, which is the shape ruling **D-4** forbids one level up. The
   version arm reports once, naming **both** versions, and says flavor rows
   gained a class field. Row `P2c` of the suite is the fence, and it asserts the
   entry is owned under **neither** the bare glob nor any guessed `{class glob}`,
   so both wrong fixes red there.

3. **A flavor glob is capped at FOUR `*`, at both doors** (issue 1278). Measured
   against a 31-char cell name: 5 stars 0.97 ms · 7 stars 14.97 ms · 9 stars
   128.88 ms · 11 stars 11.6 s · 13 stars > 70 s. Every shipped PDK `match` glob
   and every glob in the suite is 2-star. Enforced in the parser **and** in
   `set_list`, and deliberately **not** in `effective`: a file that loads clean
   and freezes later inside a redraw is the defect.

## What the user is being asked to rule on

* the grammar above, as a whole (this issue's original question, now v2);
* whether skipping a v1 flavor row is the right migration, or whether a
  release-note-and-rewrite is preferred;
* the wildcard cap's value (4).

**Cost of overruling:** the grammar lives in three places and nowhere else —
`_parse_line`, `write_body`, and the two suite headers. It is still free of any
file in the wild **until item B5 ships**.

---

# ⚠ GRAMMAR v2 — RE-DONE BY ITEM B2c ON RULING DD-8, 2026-09-03, **REVERTED AGAIN**

> **THE GRAMMAR IN THE TREE IS STILL v1.** Item **B2c** re-implemented the v2
> above on the driver's settled design **DD-8**, **closed both of the holes the
> B2a banner lists**, went green (store suite 56 → 79, full audit unmoved), and
> was reverted for a **different** defect — issue **1294**, in the writer's
> merge classifier, which does not touch the grammar. The code is preserved at
> `doc/claude/op_param_batch/B2c_working_tree_REVERTED.patch`.
>
> **The grammar rows are UNCHANGED from B2a's proposal above.** Only the
> semantics around them moved. **The deadline is unchanged and the migration is
> still free — B5 is the first thing that writes a flavor row.**

## Both holes in the B2a banner are closed

* **Precedence.** Ruling **DD-8** deletes the ranking entirely: *"when two globs
  of the SAME class both match a cell, the FIRST ONE IN THE FILE WINS. No code
  anywhere decides which glob is 'narrower'."* Measured across all three glob
  pairs both previous crews got backwards, in **both** insertion orders: 6/6 the
  first row in the file, **including a bare `*` above `*nfet_01v8_lvt*`**. There
  is **no ranking proc** in the patch.
* **The metacharacter round trip.** `_key_fields` emits the flavor's class and
  glob as **two separate unquoted fields** in both the `list` and the `param`
  row, and `_key` canonicalises the key at one door. Nine `format %c` shapes
  round-trip clean. **No rejection arm is needed** — measured, nine of ten
  already round-trip at HEAD and the corruption was *created* by v2's whole-key
  interpolation. Only a glob carrying **whitespace** is refused, as v1 does.

## THE GRAMMAR, AS THE FILE ITSELF NOW DOCUMENTS IT

This is the sentence the emitted header carries, and it is the thing the user is
being asked to accept. **Row F5 generates its own test case out of this
paragraph**, so the file cannot say it and the code do otherwise:

```
# PRECEDENCE among `flavor` rows: when two globs of the SAME class both
# match a cell name, THE FIRST ONE IN THIS FILE WINS. Nothing is ranked
# and nothing is measured for narrowness: put the row you want to win
# ABOVE the other one.
#   e.g. `flavor mos *nfet_01v8_lvt*` above `flavor mos *` wins on cell
#        sky130_fd_pr__nfet_01v8_lvt; swap the two rows and the bare * wins.
# A `flavor` row answers ONLY for the class named in its own row.
# Your personal file is read BEFORE this project's, so its flavor rows are
# tried first; a project row outranks a personal one only by using the SAME
# class and the SAME glob.
```

## Two further sub-decisions, each ladder-rung and rejected alternative recorded

4. **Cross-tier flavor precedence is READ ORDER — the user-global file's flavor
   rows are tried before the project's.** Ladder **L3**: DD-8 says *"first in
   the file"* and is **silent across two files**, and read order is the only
   spelling that needs no new rule and agrees with D-7's literal words (*"the
   user's file wins"*). It is stated in the emitted header, because otherwise
   the sentence is incomplete and therefore, again, not quite true.
   *Rejected:* project-first, which would let a project file silently outrank a
   teammate's personal narrowing — issue 1281's privacy direction in a hat.
   **Note the SAME-KEY tier override is unchanged**: a project row still wins per
   (scope, key, listname).

5. **The header and the `version` row are emitted only into a file with no lines
   yet.** Ladder **L2**, forced by DD-7 (*preserve every row verbatim*) and
   fenced by row W9 (writing the same store to the same path twice must be
   byte-identical, or the header duplicates on every save).
   *Rejected:* always emitting the header.
   **⚠ THIS COLLIDES WITH THE ACCEPT ROW AND IS ISSUE 1296 — IT NEEDS A RULING.**
   Its consequence, measured: a **pre-existing** file saved with a new v2 flavor
   row contains `FIRST ONE IN THIS FILE WINS` **zero** times, keeps a v1 grammar
   block directly above a 5-field v2 row, and still declares `version 1`.

## What the user is being asked to rule on — CONSOLIDATED, and this supersedes the list above

1. **The v2 grammar rows** (unchanged from B2a's proposal).
2. **Precedence is FILE ORDER, and nothing is ranked.** The honest consequence
   to accept: **a bare `*` placed FIRST now legitimately beats a specific
   glob** — the opposite of what both previous crews' files promised. The
   mitigation is that the user already has Up/Down buttons on every list, so
   precedence is something they set and can see.
3. **Your personal file's flavor rows are read before the project's.**
4. **Whether a pre-existing file should gain the precedence paragraph and a
   migrated `version` row** — issue **1296**, three options costed there, (b) is
   the recommendation.
5. **Whether skipping a v1 flavor row is the right migration**, or a
   release-note-and-rewrite is preferred.
6. **The wildcard cap's value (4)** — note this belongs to issue **1278** and is
   assigned to item **B3**, not to the grammar.

**Cost of overruling is unchanged and still small:** the grammar lives in
`_parse_line`, `write_body` and the two suite headers, and **no settings file
exists in the wild until item B5 ships.**

