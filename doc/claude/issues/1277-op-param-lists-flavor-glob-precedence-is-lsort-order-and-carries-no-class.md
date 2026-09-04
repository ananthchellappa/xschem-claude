# 1277 — the flavor glob wins by `lsort` order, not by narrowness, and it carries no class

**Status: MEASURED, FILED, NOT FIXED.** Found by item B2's adversary pass,
2026-09-03. Latent: nothing calls `op_param_lists::effective` yet.

This is **DD-2's override half** — *"a per-flavor entry is an optional override
that WINS when present"* — resolving by an accident of alphabetical order.

## What was claimed

Item B2's plan says the flavor arm resolves in *"file order, first match"*.
DD-2's own reading is that the **narrower** entry wins. The shipped code does
neither.

## The measurement (2026-09-03, `src/op_param_lists.tcl` md5 `bf023075`)

```tcl
op_param_lists::set_list class  mos          annotation {{cls cls 0}}
op_param_lists::set_list flavor *fet*        annotation {{broad broad 0}}
op_param_lists::set_list flavor *nfet_01v8*  annotation {{narrow narrow 0}}
op_param_lists::effective mos annotation nfet_01v8_lvt
```

```
TWOGLOB  winner={broad broad 0}     <-- the BROAD pattern wins
TWOGLOB2 winner={narrow narrow 0}   <-- rename the broad one to *zfet* and the narrow one wins
```

Both patterns match `nfet_01v8_lvt`. The winner flips on **renaming the loser**,
and the broad one won in **both insertion orders**. The cause is
`src/op_param_lists.tcl`'s `effective`:

```tcl
foreach k [lsort [array names owned]] {
  if {[lindex $k 0] ne "flavor"} { continue }
  ...
  if {[string match -nocase [lindex $k 1] $cellname]} { return $lists($k) }
}
```

`lsort` over the key triples orders by the first character after the leading
`*` — `f` before `n`, `n` before `z`. That is not file order (the store keeps
none — `owned` is an array), it is not narrowness, and it is not stable against
a user renaming an unrelated entry.

## Part 2 — a flavor entry carries no class, so it can hijack one

A flavor key is a bare cell-name glob with no class attached, and `effective`
scans **every** flavor entry regardless of the `<cls>` it was asked about.
Measured: `effective capacitor annotation cap_1v8_x` returned a flavor list
registered with MOS in mind, because the glob happened to match. There is no
way to express *"flavor X **of class mos**"*.

Low risk while item B5 writes exact cell names from a scope dialog; unbounded
the moment a user hand-edits a glob in the file they were told to hand-edit.

## Why the suite did not see it

`test_op_param_store_1245.tcl` section F only ever owns **one** flavor entry at
a time (`grep` for a second `set_list flavor` in one row: none), and every F row
passes a class that matches. F1/F1b/F2 prove the override *fires* and that a
non-matching sibling falls back — neither can see which of two matches wins,
nor that the class is ignored.

## Recommended fix

1. **Key the flavor entry on the class too** — `flavor <class>/<glob>`, or a
   fourth key field — so `effective <cls> …` scans only that class's flavors,
   and the settings-file spelling gains one field. This is the part that must be
   settled **before B5 writes the first flavor entry**, because it changes the
   file grammar (issue 1275 is the ratification door for that grammar).
2. **Order the scan deterministically and defensibly.** Two candidates, both
   better than `lsort`:
   * *most specific wins* — fewest `*`, then longest literal run, ties broken
     lexically. Matches DD-2's reading and a user's intuition.
   * *declaration order* — keep an insertion-ordered list beside the array, the
     same one-line repair issue 1274 names for `op_annot`.

**Rejected: leaving `lsort` and documenting it.** A rule a user cannot predict
from the file they are reading is not a rule; it is a coin flip with a comment.

## Acceptance rows this needs

* F3 — two flavor globs both matching one cell: the **narrower** wins, and the
  winner does not change when the loser is renamed.
* F4 — a flavor entry registered under class `mos` does **not** answer a query
  for class `capacitor`, even when its glob matches the cell name.

## Who inherits this

**Item B5** writes flavor entries from the scope dialog. If B5 ships before the
grammar gains a class field, every flavor entry in every shared settings file
has to be migrated later. Settle it at B2's seam.

---

# ITEM B2a — **ATTEMPTED, MEASURED, AND REVERTED**, 2026-09-03

> **STATUS: NOT FIXED. The code below was written, verified green, and then
> REVERSE-APPLIED out of the tree.** The item's adversary pass refuted the
> batch's central claim and the write-up agent reproduced three of its attacks
> independently, so item B2a is **[F]** and `src/op_param_lists.tcl`,
> `src/rdw.tcl` and both suites are byte-identical to commit `825cd3bd`.
>
> **The work is not lost and must not be retyped.** The full 2,506-line diff is
> preserved at `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` and
> applies clean to `825cd3bd`. The next crew's job is
> **apply + fix the named holes + re-verify**, not reconstruct.
>
> Everything below this banner is a record of THE ATTEMPT — what it changed and
> what it measured. Read it as evidence, not as a description of the tree. The
> reasons for the revert are under **"Why this was reverted"** at the end of
> this section; the three defects that forced it are in issues 1277, 1281 and
> 1284, and 1276/1278/1279/1280/1282/1283 were reverted as **collateral**,
> because a 2,506-line diff is one unit and splitting it at write-up time would
> ship a code change no verifier ever saw.

## What the attempt did (item B2a — **FIXED**, 2026-09-03. THIS IS THE GRAMMAR CHANGE, AND IT LANDED BEFORE B5.)


`src/op_param_lists.tcl`. Both halves, in one change, because the second one
moves the settings-file grammar and could only be free while no flavor entry
exists in the wild.

## 1. The flavor entry carries its class — SETTINGS-FILE GRAMMAR v2

```
version 2
class  <type-token> <broad-class>                                    # unchanged
list   class  <class> <listname>                                     # 4 fields, unchanged
list   flavor <class> <glob> <listname>                              # 5 fields, NEW
param  class  <class> <listname> <label> <rawparam> <kind>           # 7 fields, unchanged
param  flavor <class> <glob> <listname> <label> <rawparam> <kind>    # 8 fields, NEW
```

**Class rows are byte-unchanged**; only flavor rows moved, and `version` moved
1 → 2. Internally the store key stays a **three-element list** and the flavor
key's middle field became the two-element list `{<class> <glob>}`, so
`lindex $k 2` is still the listname everywhere. That is not a detail: a
four-element key would have moved `lindex $k 2` off the listname and **silently
broken issue 1279's own recommended snippet**, which the risk notes flagged as
the collision between these two issues. The chosen shape makes 1279's snippet
correct as written.

**Public arity is unchanged on every verb.** `set_list flavor {mos *nfet*}
annotation ...`, `owns flavor {mos *g*} annotation`. `set_list` **reports and
returns 0** for a flavor key that is not exactly two whitespace-free non-empty
elements (new `_key_why`), so no un-migrated caller can fail silently by
storing a list under a key no reader will look for.

**A v1 flavor row read by the v2 parser is REPORTED AND SKIPPED, never migrated
by inference.** The class was not expressible in v1, so any value the parser
picked would be invented data — the shape ruling **D-4** forbids one level up.
The version arm's report now names both versions *and* says flavor rows gained
a class field. `_parse_line` reads and validates the **scope first**, because
the scope names the arity.

**Rejected: a `<class>/<glob>` composite string.** Measured, not tasteful: every
shipped `match` glob in this tree carries a slash — `{*sky130_fd_pr/*}` (13
occurrences), `{*sg13g2_pr/*}`, `{*gf180mcu_pr/*}` — so a composite is
split-once-and-hope. **Rejected: variable arity via `args`** on
owns/get_list/set_list (three verbs grow a dispatch).

## 2. Precedence is MOST SPECIFIC WINS

New `_flavor_matches_class` (does this entry belong to the class being asked
about?) and `_flavor_order` (fewest `*`, then the most non-`*` characters, then
lexical order of the glob). `lsort` is stable, so three sorts applied
least-significant-key first give the ordering with no comparison callback.

This is DD-2's *"the narrower entry wins"* made spellable. **Rejected:
declaration order** — it needs the insertion-ordered registry issue 1274 names
for op_annot, and a user reading the FILE cannot predict cross-tier insertion
order either. **Rejected: keeping `lsort` and documenting it** — this issue's
own rejection, and it stands: a rule a user cannot predict from the file they
are reading is a coin flip with a comment.

A tie is broken lexically and is **not** reported: `effective` runs once per
instance per redraw, and a per-redraw report is spam.

## Red before green

| row | red on | green after |
|---|---|---|
| `F3` narrowness, both insertion orders + the loser renamed | `{{cls cls 0}}`×3 (the class list, because `set_list` refused the `{class glob}` key outright) | `{{narrow narrow 0}}`×3 |
| `F4` class filter | a MOS flavor answered the `capacitor` query | each class answered independently |
| `F5` grammar v2 on disk | `{1 1 {} {} 1 {} 0 1 0 0 2 1}` | `{1 2 {5 5} 8 1 {{fid fid 0}} 1 0 0 0 3 0}` |
| `P2c` a genuine v1 file | the v1 flavor row **loads**, nothing reported | reported once naming both versions; the v1 flavor row reported and skipped; owned under **neither** the bare glob nor any guessed `{class glob}` |

Sabotage, with the fix in place:

* `SB-FLAVOR-LSORT` (`_flavor_order` → `lsort $keys`) → **F3 red**, `1 FAILED (55 passed)`.
* `SB-FLAVOR-CLASSBLIND` (`_flavor_matches_class` → `1`) → **F4 red**, `1 FAILED (55 passed)`.

## What this obliges

Issue **1275** is the ratification door and now carries grammar **v2**; the
header of `src/op_param_lists.tcl` and of
`tests/headless/test_op_param_store_1245.tcl` both document the change and why
the field is separate. Every `version 1` fixture line in the suite is now
`version 2` (12 sites), and every flavor `set_list`/`get_list`/`owns` call takes
the `{class glob}` key.

## ⚠ Why this was reverted — THE FIX DOES NOT DELIVER DD-2, AND THE FILE SAYS IT DOES

Reproduced by the write-up agent 2026-09-03, `tclsh` driving the attempt's own
`op_param_lists.tcl`, both insertion orders, cell `sky130_fd_pr__nfet_01v8_lvt`:

```
A: 'sky130_fd_pr__*' (1 star, THE WHOLE PDK) vs '*nfet_01v8_lvt*' (2 stars, ONE flavor)
  order={sky130_fd_pr__* *nfet_01v8_lvt*} winner=sky130_fd_pr___
  order={*nfet_01v8_lvt* sky130_fd_pr__*} winner=sky130_fd_pr___
B: '*' (EVERYTHING) vs '*nfet_01v8_lvt*'
  order={* *nfet_01v8_lvt*} winner=_
  order={*nfet_01v8_lvt* *} winner=_
```

`_flavor_order`'s primary sort key is **`*` count ascending**, and fewest-stars
is **not narrowness**. A bare `*` — match-everything — beats a specific flavor
glob in both insertion orders. That is *this issue's own filed defect* (the
broad entry wins) reproduced under its own fix, with a **more natural** pattern
pair than the filed one: `<pdk-prefix>*` is how a PDK-wide row is spelled.

Two things make it worse than a simple miss:

1. **The shipped settings file states the rule the code does not implement.**
   `write_body` writes this comment into every `op_param_lists.conf` it emits:
   `narrowest matching glob of that class wins. At most four ``*``.` So the file
   a teammate reads promises narrowest-wins while the reader does fewest-stars.
2. **The suite cannot see it.** Every flavor glob in
   `test_op_param_store_1245.tcl` is 2-star (`*fet*`, `*nfet_01v8*`, `*_1v8_x`,
   `*t*`), so no row ever pits a 1-star broad glob against a 2-star narrow one.
   Row F3 passes over the hole — **the batch's own recurring lesson, one item
   later: a suite fences the questions its author thought of.**

**What the next crew must do.** Rank by *literal length of the non-`*` text*
(most literal characters wins), or by matched-prefix specificity — not by star
count. Then add the counterexample rows: `<pdk>*` vs `*<flavor>*`, and bare `*`
vs anything. Until that lands, DD-2 is not implemented.

## ⚠ Also unfixed, and adversary-measured (not independently re-run here)

**Grammar v2 corrupts any glob carrying a Tcl list metacharacter, silently.**
`write_body` emits `puts $fp "list $scope $key $ln"`, interpolating the flavor
key's *list* string representation, while `_parse_line` splits on
`regexp -inline -all {\S+}` and takes the raw fields — the writer's quoting and
the reader's unquoting disagree. Measured by Verify-C on a set→write→reset→load
round trip: `a[nm]fet*` is written `{a[nm]fet*}` and read back with the braces
**literal**, so it can never match again; same for `a\*b` (the documented way to
match a cell whose name contains a star) and `a"b*`. **Zero reports on either
side.** `_key_why` guards whitespace only. Row F5's round-trip fence uses
`*nfet*`, which has no metacharacter, so the fence passes over a corrupting
round trip.

Since the grammar change is the one with the B5 deadline, the next crew must
settle quoting **in the same pass**: either write one field per line with an
explicit escape, or refuse a glob containing a list metacharacter at both doors
the way whitespace is already refused.

---

## Item B2a-2 — ATTEMPTED, MEASURED, AND REVERTED, 2026-09-03

B2a-2 took **the second arm of the fork** it was given: it changed the ranking
*and* rewrote the sentence the file emits. Both halves were fenced by new rows
(F6, F6b, F6c, F7, F7b) and both went green. **The item was still reverted,
because the rewritten sentence is itself false.**

### What B2a-2 changed

`_flavor_order` was re-keyed from *fewest `*`* to **most non-wildcard
characters, then fewest wildcards (`*` and `?`), then lexical**. That does fix
the filed defect **for `*`-only globs**: on cell `sky130_fd_pr__nfet_01v8_lvt`
the order is `sky130_fd_pr__*  *nfet_01v8_lvt*  *` in **both** insertion orders
— the bare `*` last, which is what this issue was filed about.

The round-trip half was fixed **at the writer**: a new `_key_fields` emits the
class and the glob as two separate unquoted fields in **both** the `list` row
and the `param` row. All nine metacharacters (`{ } [ ] \ " $ ?` and
`a[nm]fet*`) then round-trip clean, where eight of nine corrupted before. **That
half was not refuted and should be kept.**

### Why it was reverted — the emitted sentence is still a lie

The file now says, in every settings file `write_body` emits:

```
#           So a bare `*` is always the last resort, and a longer vendor
#           prefix outranks a shorter device-name pattern.
```

Reproduced by the write-up agent, first-hand, on the patched tree:

```
_flavor_order * **     -> *   **      bare * WINS
_flavor_order * *?*    -> *   *?*     bare * WINS
_flavor_order * ?*     -> *   ?*      bare * WINS   (?* is strictly narrower)
_flavor_order *ab* ?ab? -> *ab*  ?ab?  the BROADER glob wins on cell xaby
```

`?` is counted as a wildcard in the rank key — so it **reduces** the literal
count — but its narrowing is **never credited**, and `_glob_why` caps only `*`
(an eight-`?` glob is accepted, rc=1, no report). The clause *"a bare `*` is
always the last resort"* is false of the code that prints it, which is the exact
condition this item's ACCEPT row forbade:

> The settings file's own precedence sentence is TRUE of the code that emits it.

Row **F6b**'s fence could not see it: its four-glob set `{ab a*b *ab* *}` is
**all `*`**, so it never pits a `?` against anything.

### The sentence in *this issue* that the measurement refutes

This issue's own "what the next crew must do" recommends:

> Rank by literal length of the non-`*` text (most literal characters wins).

That is **half refuted, by the very case this issue cites**. It fixes the bare
`*`; it **cannot** order `sky130_fd_pr__*` against `*nfet_01v8_lvt*`, because
`sky130_fd_pr__` is **14** non-wildcard characters and `nfet_01v8_lvt` is **13**
— so literal length ranks that pair the same way star count did. **No
string-intrinsic metric separates a vendor prefix from a device name.** B2a-2
measured this and fenced the pair with both counts in row F6c; the honesty of
the emitted sentence is what has to carry it.

## Still open after B2a-2 — what the third crew must fix

1. **Credit `?` as narrowing, or stop claiming a bare `*` loses.** A defensible
   order must rank `?*` above `*`, and `?ab?` above `*ab*`. Counting `?` as a
   literal-position (it matches exactly one character) rather than as a
   wildcard is the smallest change that does it — and then re-check the
   sentence against `**` too.
2. **Whatever the order, prove the sentence.** The fence must be generated
   *from the emitted comment*, not written beside it, or the two drift again —
   they drifted twice now.
3. **Keep `_key_fields`.** The round-trip fix is sound and survives.
4. **The key-identity hole is separate and still open** (below).

### A second, separate hole B2a-2 introduced and did not close

The v2 flavor key is a **two-element Tcl list used as an array index**, and it
is not canonicalised. `set_list flavor {mos a[nm]fet*} annotation …` (a plain
list literal, the obvious spelling) stores one index; `_parse_line` rebuilds the
key with `list`, whose string rep braces the `[` element (`mos {a[nm]fet*}`), so
after write→reset→load `owns flavor {mos a[nm]fet*} annotation` is **0** and
`get_list` is empty. Setting it again creates a **second** `owned` slot, and
`write_conf` then emits **two identical `list` rows and two conflicting `param`
rows**; the reader's first-touch rule silently discards one, with **zero
reports**. HEAD has no such divergence — a v1 key was one element that `list`
quoted identically from both doors — so **grammar v2 introduces it**. The store
must canonicalise the key at both doors (build it with `list` on the way in too).

---

## ATTEMPT 3 — item B2c, 2026-09-03: FIXED IN THE PATCH ON RULING DD-8, NOT LANDED

**Ruling DD-8 deletes the ranking.** *"When two flavor globs both match a cell,
the FIRST ONE IN THE FILE WINS. No code anywhere decides which glob is
'narrower'."* Both previous attempts ranked, and both shipped a bare `*` beating
a specific pattern — the filed defect, under its own fix, twice. `"narrower"`
has no defensible total order over globs.

**This half of the issue is now SOLVED and the design should not be reopened.**
The item was reverted for issue **1294**, which is in the writer's merge and does
not touch any of the below.

### What the patch does

* **`variable keyorder`** — a plain **list** of store keys, appended when a key
  is first seen (by `set_list` and by `_parse_line`), cleared by `reset`,
  consumed by **`effective`** and by the writer. It replaces `lsort [array names
  owned]` in both. A Tcl array has no insertion order, which is the whole reason
  both previous attempts reached for a ranking in the first place.
  **No `_flavor_order`, no narrowness metric, no `maxstars` exists in the patch.**
* **`_flavor_matches_class {k cls}`** — the class half of this issue, which
  **stands** under DD-8. `effective <class>` no longer scans another class's
  flavors.
* **`_key_fields {scope key}`** — the flavor's class and glob are emitted as
  **two separate unquoted fields** in both the `list` and the `param` row, and
  `_key` canonicalises with `[list [lindex $key 0] [lindex $key 1]]` **at one
  door only**.

### Measured after

| row | before (HEAD) | after |
|---|---|---|
| `*fet*` vs `*nfet_01v8*`, **both** insertion orders | `*fet*` wins both times (`lsort`: `f` < `n`) | **the first row in the file** wins, both times |
| bare `*` vs `*nfet_01v8_lvt*` | **bare `*` wins** — the headline both crews shipped | the first row in the file wins |
| `sky130_fd_pr__*` vs `*nfet_01v8_lvt*` | the **second** row wins | the first row in the file wins |
| rename the **loser** | the winner **flips** | winner unchanged (4 renamings) |
| `effective capacitor annotation cap_1v8_x` | returns a **`mos`** flavor's list | the capacitor's, or none |

⚠ **A correction to the record.** An earlier scout note called HEAD *"accidentally
right"* on `sky130_fd_pr__*` vs `*nfet_01v8_lvt*`. Under DD-8 it is **not**: HEAD
answers the **second** row, so first-in-file loses, and a correct fix **flips**
that pair. That flip is the fix working, not a regression.

### The sentence the file emits — the named ACCEPT row both crews failed

The emitted header now carries, verbatim:

```
# PRECEDENCE among `flavor` rows: when two globs of the SAME class both
# match a cell name, THE FIRST ONE IN THIS FILE WINS. Nothing is ranked
# and nothing is measured for narrowness: put the row you want to win
# ABOVE the other one.
#   e.g. `flavor mos *nfet_01v8_lvt*` above `flavor mos *` wins on cell
#        sky130_fd_pr__nfet_01v8_lvt; swap the two rows and the bare *
#        wins.
```

**And this issue's "still open" item 2 is discharged the way it asked.** Row
**F5** does not restate the sentence beside the code — it **regexps the two
specimen globs and the cell name out of the freshly written file** and builds
the case the file describes, in both orders. Falsify or delete the sentence and
F5 reds. Row **X5** additionally asserts the file contains no `narrow` / `most
specific` and does contain `THE FIRST ONE IN THIS FILE WINS`. **Copy this shape
wherever a comment makes a promise.**

### Metacharacters: emit two fields, do NOT reject

The brief allowed *"if the format cannot carry one, reject it at write time"*.
**Measured: it can.** Nine of ten shapes (`[nm]`, `\*`, `"`, `{`, `}`, `$`,
`?`, bare `*`, a slash-bearing PDK glob) already round-trip **at HEAD** with
zero reports; the corruption is **created** by grammar v2's two-element key
being interpolated whole into `puts $fp "list $scope $key $ln"`. Emitting two
fields needs no rejection arm — and adding one would cost `[nm]` and `\*`, both
documented `string match` features. The one refusal kept is a glob carrying
**whitespace**, which HEAD already refuses with a sentence.

### ⚠ Introduced by this fix, and still open: issue 1294's secondary

`_key` **silently truncates** a >2-element flavor key, so
`owns flavor {mos *cap* JUNK} annotation` → **1** and `get_list` returns the
entry, while `set_list` with the identical key → **0 with a report**. Three
doors, two rules — a new two-door disagreement of exactly the class issue
**1288** was filed about. Latent; **B5's scope dialog is the first door that
could reach it.** Either canonicalise by refusal (call `_key_why` from `owns` and
`get_list` too) or say in `_key`'s comment that the truncation is intentional.
