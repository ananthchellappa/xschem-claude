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
