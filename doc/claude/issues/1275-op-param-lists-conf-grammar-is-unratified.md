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
