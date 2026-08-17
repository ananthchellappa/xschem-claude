# Raw case mode — names are stored verbatim; `case_sensitive` is a lookup flag

Status: **items 1, 2 and 3 of the casemode batch are implemented** (this
document); items 4–15 are not. Written 2026-08-16.

Design origin: `doc/claude/casemode_batch/DESIGN_REVISION.md` (sections 4, 5, 6,
7, 8) and `doc/claude/casemode_batch/DECISIONS.md`. Plan item list:
`doc/claude/casemode_batch/PLAN.md` §3b. Background on where case is folded
across the whole tool: `doc/claude/code_analysis/ngspice_case_sensitivity.md`
(its Part 3 is superseded by the above).

---

## 1. The rule

**Every reader stores variable names exactly as the file spells them.**

`read_dataset()` (`src/save.c`) used to `strtolower()` each name. That call is
deleted. `vcd_read()` and `table_read()` already stored verbatim, so the spice
reader was the outlier, not the rule.

The fold was never about display. `get_raw_index()` transforms the **query**
(verbatim → UPPER → lower → `v(...)`, plus an `i(v.x` fixup), so with every
stored name lowercase, `v(en)` and `v(EN)` both resolved. What it cost:

| mode the simulator ran in | file says | browser said, before | says now |
|---|---|---|---|
| fold (every released ngspice) | `v(en)` | `v(en)` | `v(en)` — unchanged |
| preserve | `v(EN)` | `v(en)` | `v(EN)` |
| distinguish, with `EN` and `en` both present | two vectors | **one** — the folded keys collided and `XINSERT_NOREPLACE` dropped the second | two vectors |

Row 3 is silent data loss on exactly the feature a case-capable simulator is
adopted for.

**AC files derive four names per variable**, not one — `v(X)`, `ph(X)`, `re(X)`,
`im(X)`, all built from `varname` at the point the fold used to sit. All four
now carry the case. Item 2's folded-alias work must cover all four. See §8 for
the prefix test that had to become case-blind for that to be true.

## 2. `Raw.case_sensitive` — what it is, and what it is not

A **boolean** on each `Raw` (`src/xschem.h`). `1` means a name query may not
resolve against a stored name differing only in case. `0`, the default, means it
may.

- Only **`distinguish`** sets it. `fold` and `preserve` both leave it `0`,
  because neither can produce a database in which two names differ only by case,
  so a case-insensitive lookup cannot pick the wrong one.
- It is **not a record of the simulator's mode.** `DECISIONS.md` B2b: absence of
  evidence is "unknown", never "fold". §10 is the four-source mode resolution
  item 3 added; this flag is not it, and nothing in §10 writes it.
- Nothing in the read path reads it. Item 2 is its first and only consumer: it
  suppresses the folded-alias rung in `get_raw_index()` (§9).

### The item-1 lookup gap, stated precisely — CLOSED by item 2

> **Item 2 has landed.** Everything in this subsection describes the state
> between item 1 and item 2 and is kept because it is what §9's ladder was
> built to fix. The acceptance check it hands item 2 —
> `xschem raw index MidNode == 2` on `tr_preserve.raw` — is now `CS37b`, and
> the bare device-vector shapes are `CS38c`–`CS38g`. All pass.

Until item 2 landed, **every BARE (unwrapped) node name missed against a
mixed-case raw — including the correctly-spelled one.** Not just a lowercase
query: `get_raw_index()` mutates its `inode` buffer in place (verbatim →
`strtoupper` → `strtolower`) before it builds the `v(%s)` rung, so that rung is
always spelled lowercase and can never reach a stored `v(MidNode)`. Measured
against `tr_preserve.raw`: `MidNode`, `midnode`, `MIDNODE`, `In` and
`v(midnode)` all answer `-1`; only `v(MidNode)` answers `2`. Against
`tr_fold.raw` — which is what the pre-item-1 reader turned `tr_preserve.raw`
into — all six answer.

A bare node token is the normal `node=` spelling on a graph rect, so this is the
gap that matters. It is unreachable for any folding simulator (all released
ngspice) and it is inside this batch. **Item 2 owes an acceptance check
`xschem raw index MidNode == 2` on `tr_preserve.raw`**, and the same for the
bare device-vector shapes CS28 covers (`@M1[Id]`, `MyNode`), which the `v(...)`
rung cannot rescue at all.

## 3. The commands

```
xschem raw read <file> [<type>] [<sweep1> <sweep2>] [-case <mode>]
xschem raw case                     ;# get:  1 | 0
xschem raw case <mode>              ;# set:  RE-READS the file
```

`<mode>` is `fold` | `preserve` | `distinguish`, or `0` | `1`.
`raw_case_mode_parse()` (`src/save.c`) is the one parser, so the option and the
subcommand cannot disagree about what a word means. An unknown token is a Tcl
error, never a guess.

### RULING — `-case` is an option, not a positional

It is extracted before the positionals are counted, so it may appear anywhere
after the subcommand and the three shipped positional forms are byte-identical
to what they were. Parsed positionally, `raw read f tran -case distinguish`
would have handed `-case` to `atof_spice()` as `sweep1`.

### RULING — the getter answers `1`/`0`, not a mode word

The `Raw` records what the **lookup** does, not what the simulator did.
Answering `fold` would assert a fact nobody established, which B2b forbids;
inventing a third word would add vocabulary for no gain. `1`/`0` is also the
predicate item 5's Tcl consumers actually want, and it round-trips:
`xschem raw case [xschem raw case]` is accepted.

### RULING — a set RE-READS the file

Folding is destructive: once `v(EN)` has been lowercased the capitals are gone
from memory, so a control that only flipped a flag would be lying about every
database read before the flip. Under this design nothing folds on read, so in
practice the re-read changes no name — but the contract is the re-read, and a
flag flip that happens to look right on a file that was never folded is not the
same guarantee. Implemented as `extra_rawfile(3, …)` then `extra_rawfile(1, …)`
on the same file/sim_type/sweep window.

Two observable consequences, both accepted: the database moves to the end of the
registry (its `xschem raw switch <index>` index changes), and any in-memory-only
edit to it — `raw rename`, `raw del`, `raw add` — is discarded. The second is
the property the test asserts to prove the re-read happened at all.

**A re-read that cannot succeed is a Tcl error, and changes nothing.** The
registry dedups on filename+`sim_type`, so the old entry must be deleted before
the same filename can be read again — which put the destruction ahead of any
knowledge that the read would work. An unreadable backing file then annihilated
the database and reported it as the string `0`. That is not an exotic state: a
re-running simulator replaces its raw file, `xschem raw new` invents a database
whose `rawfile` is a bare label, and `raw_read_from_attr()` `unlink()`s the temp
file whose name it leaves in `raw->rawfile`, so an **embedded `spice_data` raw is
always in it**. `raw_case_reread()` (`src/scheduler.c`) therefore opens the file
**before** it deletes anything and refuses with a Tcl error naming the file,
leaving the loaded database exactly as it was. Checks CS30b–CS30e, CS31b–CS31c.

**The re-read uses the type the CALLER asked for, not `raw->sim_type`.**
`read_dataset()` promotes a multi-point `Operating Point` raw to `sim_type`
`"dc"`, and the type argument is matched against the `Plotname:` line — so
re-reading that file as `"dc"` can never match, and the set failed (and, before
the guard above, destroyed the database) on every ordinary multi-point `.op`
raw. `Raw.req_sim_type` (`src/xschem.h`) records the original request;
`sim_type` remains the right key for finding the registry entry to delete.
Checks CS32–CS32e.

### RULING — `-case` on an already-loaded database re-reads as well

`xschem raw read <file> … -case <mode>` on a file the registry already holds is
a **switch**, not a read: `extra_rawfile()` finds the entry and makes it
current. Stamping the flag there would be exactly the flag-flip-with-no-re-read
this section forbids, reached by the other verb — measured, with an in-memory
`raw rename` surviving while the flag moved `0 → 1`. So that path is routed
through the same `raw_case_reread()`, and `-case` means one thing whichever verb
carries it. A first read is unaffected: the file has just been read, so nothing
re-reads it. Checks CS34–CS34d.

## 4. `ngspice::ngspice_data` keys stay FOLDED

That Tcl array is a **published interface**: `ngspice_backannotate.tcl` and user
scripts read `$ngspice::ngspice_data(v(en))`. Tcl array keys are case-sensitive.
Its keys were lowercase only because the stored name was, so the fold moved to
the two publish sites — `update_op()` (`src/save.c`) and the cursor-B publisher
in `src/callback.c` — both through `ngspice_data_key()`, so the rule is stated
once.

### Two names that differ only in case collide on one key — first writer wins

Folding the publish key is the same lossy operation the read path was condemned
for, and under `distinguish` a database can legitimately hold both `v(EN)` and
`v(en)`. They collapse onto one Tcl array key. **The first variable to be
published keeps the key**, matching the read side, where `int_hash_lookup()`
inserts names with `XINSERT_NOREPLACE`; the second is refused and named in a
`dbg(0)`. It is *not* published under a capitalised key either — the array's
keys stay folded, which is the whole point of §4.

Lossy is tolerable here until item 5b; **silent was not**, and silent is what it
was: the second value simply overwrote the first. Nothing is lost from the
*database* — both variables are still reachable by `xschem raw index` and
`xschem raw value` under their own spelling. `ngspice_data_publish()`
(`src/save.c`) is the one place this rule lives, for both publish sites. Checks
CS36–CS36f.

`DECISIONS.md` D3 / plan item 5b replaces the whole eager array with a
read-traced lazy view over `get_raw_index`, at which point there are no stored
keys to fold. **That is 5b's business.** Until it lands this is not optional:
without it every key silently gains capitals and every consumer misses.

## 5. RULING — Xyce: accept the change, add no Xyce-specific fold

**The open item** (`PLAN.md` §3b, `DESIGN_REVISION.md` §5 and §10.1): the plan
asserts Xyce writes `V(EN)` uppercase. There is no Xyce on this machine, it has
never been measured, and a Xyce raw is the one file whose reading this change
alters in a way nobody has observed. Item 1 had to rule between (a) keeping a
Xyce-specific fold hung off the existing Xyce-shaped branch (`:` → `.`,
`save.c`) and (b) accepting the unverified change.

**Ruled: (b).** Reasons, in order of weight:

1. **There is no MEASURED way to identify a Xyce raw.** A spice raw header does
   carry a `Command:` line naming the producer — both committed fixtures say
   `Command: ngspice-46+, …` — but `read_dataset()` never parses it
   (`grep -n Command src/save.c` returns nothing), and nobody has measured what
   Xyce writes there. So the identification a fold would have to be gated on
   does not exist in the reader today and has not been observed in a Xyce file.
   The only Xyce-shaped thing the reader *does* key off is `:` as the hierarchy
   separator, and the `:` → `.` rewrite is applied **unconditionally to every
   raw**, not gated on Xyce. xschem's own `sim_is_xyce`
   (`src/xschem.tcl:2787`) does not look at the file at all — it regexps
   `[xX]yce` out of the **configured simulator command**, a property of the
   session, not of the file being opened. So a "Xyce-specific fold" would in
   practice be a heuristic (a name contains `:`, or the names are all uppercase)
   gating a **destructive** transformation on files nobody has measured. That is
   a worse failure mode than the one it prevents. *(Correcting an earlier
   revision of this document, which claimed the header carries "no vendor tag" —
   it does; what it lacks is a parser and a measurement.)*
2. **Item 2 removes the remaining symptom, and §8 removed the sharp one.** If
   Xyce does write `V(EN)`, the visible change is that `xschem raw list` shows
   the file's own spelling; a lowercase query still resolves, through the
   case-folded rung item 2 adds to `get_raw_index()`. Between item 1 and item 2
   there is a window where a lowercase query against an uppercase stored name
   misses — inside this batch, and it cannot affect any folding simulator, which
   is all released ngspice. **This reason does not cover AC derived names**, and
   originally it was wrongly assumed to: an uppercase `V(` prefix changed the
   derived names' *shape*, which no alias rung can repair. That is fixed in the
   reader instead — see §8.
3. **A mode branch here contradicts the design.** The whole point of the
   revision is that the read path stops guessing; adding a per-vendor fold back
   into `read_dataset()` re-creates the thing being deleted.

**What would reopen this:** a real Xyce raw. If one turns up and Xyce is
confirmed to uppercase, the fix belongs in the **lookup** (a case-insensitive
rung, which item 2 provides anyway) or in item 3's four-source mode resolution —
never in the reader. Record the measurement here and in
`code_analysis/ngspice_case_sensitivity.md`.

Until then, `Xyce is UNVERIFIED` stays in item 15's documentation.

## 6. What is deliberately NOT here

- Mode detection from the `Option: casemode=` header, schematic comparison or a
  capital sniff — item 3, now **§10 below**.
- The four `hilight.c` senders, the viewer Tcl, `sod_expr`, the simulator
  profile and its probe — items 4–13.

## 7. Tests

`tests/headless/test_raw_case_mode.tcl` (prefix `CS`, **186 checks** — 81 from
item 1, 88 from item 2, 17 more from item 2's fix round: the anchoring bait
`CS39g`/`CS39h` and the viewer-gate section `CS49`–`CS49o` — true headless).
Data: the two committed fixtures
`doc/claude/casemode_batch/fixtures/tr_{fold,preserve}.raw` — byte-comparable
229-point binary raws differing only in their Variables section, so no simulator
is needed — plus inline ASCII raws (AC, device vectors, hierarchical currents,
duplicate columns), an inline **VCD** for the collision rule and an inline
**table** file, all written to `test_scratch`.

## 8. The AC `v(` prefix test is CASE-BLIND

The AC arm derives `ph(X)`, `re(X)`, `im(X)` from the node name by recognising a
leading `v(` and skipping it. That test was spelled
`strstr(varname, "v(") == varname` and only ever matched because the deleted
fold had just lowercased `varname`.

Left alone it would have changed the derived names' **shape**, not their case:

| file says | before item 1 | item 1, prefix test untouched | item 1 as shipped |
|---|---|---|---|
| `v(Out)` | `v(out) ph(out) re(out) im(out)` | `v(Out) ph(Out) re(Out) im(Out)` | same |
| `V(Out)` | `v(out) ph(out) re(out) im(out)` | `V(Out) ph(V(Out)) re(V(Out)) im(V(Out))` | `V(Out) ph(Out) re(Out) im(Out)` |

Row 2 is not a differently-cased name, it is a different string, and **item 2's
folded-alias rung cannot repair it**: folding `ph(V(Out))` yields `ph(v(out))`,
never `ph(out)`. `xschem raw index ph(Out)` returned `-1`. Uppercase `V(` is
precisely the shape §5 believes Xyce writes, so the case the ruling is about was
the case it broke.

Fixed by recognising the prefix case-insensitively (`src/save.c`, one `vpfx`
test used by all three derivations). **`varname` itself is not touched** — the
magnitude name keeps the file's own spelling; only the prefix *recognition* is
case-blind. Checks CS29–CS29d.

`DESIGN_REVISION.md` §8 said this needed "no extra work". It needed one line.

## 9. THE ONE LOOKUP LADDER (`get_raw_index`) — casemode item 2

`get_raw_index()` (`src/save.c`) is the single name-resolution authority for
every raw database, whatever reader built it. Item 2 rewrote it. Given a node:

| rung | tries | example |
|---|---|---|
| 1 | the exact spelling | `v(MidNode)` |
| 2 | the **case-folded alias** | `v(midnode)`, `V(MIDNODE)` → `v(MidNode)` |
| 3 | rungs 1–2 on `v(<node>)` | `MidNode` → `v(MidNode)` → `v(midnode)` |
| 4 | rungs 1–2 with a leading `i(v.x` rewritten to `i(x` (the `x` is part of the prefix, and it is anchored) | `i(V.X1.Vp)` → `i(X1.Vp)` |

Rung 2 (and the folded half of 3 and 4) is the whole of the case
insensitivity the deleted read-path fold used to buy. It is suppressed for a
`distinguish` database (`Raw.case_sensitive`, §2) and by the collision rule
below.

### RULING — the ladder does NOT mutate the query

The old ladder was `verbatim → strtoupper(inode) → strtolower(inode) →
"v(%s)" of inode → strstr(inode,"i(v.x")`, **all on one buffer, in place**. By
the time it built the `v(%s)` rung the query was already lowercased, so
`MidNode` could only ever probe `v(midnode)`. That is why, after item 1,
**every bare mixed-case name missed on a `preserve` raw — including the
correctly spelled one** (§2), and why the `i(v.x` rung could only ever probe a
lowercased name, which after item 1 no longer matched a stored `i(X1.Vp)` (the
rung *was* reachable in any casing — see the ruling on it below, which corrects
an earlier backwards account). Each rung now starts from the caller's own
spelling and asks for the fold explicitly. Checks `CS37b`–`CS37l`, `CS39d`,
`CS39e`.

### RULING — the alias index is a SEPARATE table, not extra entries in `raw->table`

`DESIGN_REVISION.md` §4 proposed inserting folded aliases into `raw->table`
itself with `XINSERT_NOREPLACE`. That is not implementable together with
`DECISIONS.md` D2, and it breaks two other consumers. `Raw.fold_table`
(`src/xschem.h`) is therefore a second `Int_hashtable`, keys
`strtolower(names[i])`, values `i` or `-1` for ambiguous. Three reasons, each
sufficient:

1. **D2 needs a poison value, and poisoning would destroy a real entry.** When
   a database holds `v(EN)` and `v(en)`, the folded key *is* `v(en)`, a real
   stored name. Marking that key ambiguous in `raw->table` would break the
   **exact** lookup of `v(en)` — and "exact lookups unaffected" is the first
   half of D2. One table cannot hold both meanings.
2. **`raw_add_vector()` tests `raw->table` for existence.** An alias entry
   under a folded key would make `xschem raw add v(en)` a silent no-op on a
   database whose real name is `v(EN)`.
3. **`raw_renamevar()`/`raw_deletevar()` delete by `entry->token`.** With
   aliases in the same table they would delete the alias and leave the real
   entry — or, worse, delete a real entry that happens to be the lowercase
   spelling of another name.

The property that licensed the original proposal is preserved and strengthened:
**nothing enumerates either table.** Every listing — `xschem raw list`
(`src/scheduler.c`), the viewer's browsers — iterates `raw->names[]`, so no
alias can appear as a phantom signal. Checks `CS44`–`CS44c` assert it after a
battery of fuzzy queries, **as absolute assertions**: `raw list` must equal the
fixture's own four names and `raw vars` must equal 4.

> **Why absolute and not before/after** (review finding, fix round). The first
> version captured `raw list`/`raw vars` into `_before` variables and compared
> them with themselves after the battery. That cannot fail: there is no
> "before" — the graph rect built earlier in the suite makes `xschem raw read`
> itself resolve a node, so the index already exists — and a self-comparison is
> green for any defect stable across two calls. Measured: with
> `raw_build_fold_table()` appending its alias to `names[]`/`nvars` as a real
> variable, `raw list` returned `time v(In) v(MidNode) i(Vs) __alias__` and
> `raw vars` returned `5`, and all three checks printed `ok:`.

### RULING — the index is built LAZILY and dropped whenever `names[]` moves

`fold_table.table == NULL` means "not built". It is built on the first fuzzy
lookup, so a query that hits exactly — every query on a stock all-lowercase raw
— never pays for it, and a database nobody queries fuzzily never allocates it.
`raw_fold_table_clear()` drops it at the three places `names[]` changes
identity or position: `raw_renamevar()`, `raw_deletevar()` and
`raw_add_vector()`. `raw_deletevar()` is the sharp one — it **re-indexes** every
name below the deleted one, so a surviving alias resolves to the **wrong
column**, which is silently wrong data rather than a miss. Checks `CS45`–`CS47d`.

`raw_lookup_name()` also bounds the index with `idx < raw->nvars`. That is not
belt-and-braces: measured with the invalidation deliberately disabled, `names[]`
after a `raw del` is one shorter but `names[nvars]` still held the old last
pointer in the shrunk-in-place allocation, so the stale lookup answered
**correctly** off out-of-bounds memory and the check written to catch a stale
index stayed green by luck of the allocator.

### RULING — D2: no alias when two DIFFERENT stored names collide

Two stored names folding to one key means the fuzzy rung has no answer, only a
guess, so it declines: the key's value is set to `-1` and **neither** name gets
an alias. Exact lookups are untouched, which is the point — `Count` and `count`
each resolve to themselves, and `COUNT` resolves to nothing.

Plain `XINSERT_NOREPLACE` first-wins is **not** the rule: it would answer a
`COUNT` query with an arbitrary `Count`. (Item 1 took the *other* decision for
`ngspice_data`'s publish keys — first writer wins, loser in a `dbg(0)` — because
that array is a published Tcl interface that cannot represent both keys at all;
§4. It is a compatibility shim, not a precedent for the lookup table, which can
represent both perfectly well.)

**Byte-identical duplicates are deliberately NOT a collision.** ngspice upstream
`0073` writes two columns with the same name (`write f.raw v(In)`), and
declining there would break a lookup that has exactly one sensible answer. The
test is `strcmp(names[first], names[i]) != 0`, and first-wins keeps the alias —
matching what `raw->table` already does. Checks `CS40`–`CS42d`.

VCD is where the collision is legitimate — Verilog identifiers are
case-sensitive — so `tests/headless/test_raw_case_mode.tcl` builds an inline VCD
declaring `Count` and `count` in one scope. `receipts/00a-suite-sweep.md`
finding 4: no committed test exercised a collision at all before this one.

### RULING — the `i(v.x` rung is case-blind and ANCHORED

ngspice names the current of a voltage source inside subcircuit `x1`
`i(v.x1.vp)` in some versions and `i(x1.vp)` in others; the rung drops the `v.`.
The old test was `strstr(inode, "i(v.x")` — a search *anywhere* — but the
rewrite then overwrote `inode[2]` and `inode[3]` regardless, so a match at any
other offset produced a garbage string (`xi(v.x1.vp)` probed `i(.x1.vp)`).
It is now `my_strncasecmp(node, "i(v.x", 5)`: case-blind and anchored.

**The history, stated the right way round** (an earlier revision of this
paragraph, the source comment and the receipt had it backwards). An uppercase
query *did* reach the old rung — the in-place `strtolower()` two rungs up had
already destroyed the query's case, so `I(V.X1.VP)` arrived as `i(v.x1.vp)`.
Measured on the pre-item-2 binary against an all-lowercase-stored fixture, all
four of `i(v.x1.vp)`, `I(V.X1.VP)`, `i(V.X1.Vp)`, `I(v.x1.vp)` resolved. What
broke the rung was **item 1**, which stopped folding the *stored* name: the
lowercased probe `i(x1.vp)` no longer matched a stored `i(X1.Vp)`. Since the
ladder no longer mutates the query, the test must be case-blind against the
caller's own spelling, and the rewritten name goes back through
`raw_lookup_name()` so the folded rung can still reach `i(X1.Vp)`. Checks
`CS39c`–`CS39e`.

**The anchoring needs a bait column to be checkable, and now has one** (review
finding, fix round). `CS39f` asserts `xi(v.x1.vp)` → `-1`, but with only
`i(X1.Vp)` in the fixture that query misses under anchored *and* unanchored code
alike — measured: a deliberately unanchored rung left the whole suite ALL PASS.
The fixture therefore stores a second column spelled `i(.x1.vp)`, which is
exactly what the unanchored rewrite produces from that query: `CS39h` proves the
bait resolves exactly (index 2), and `CS39f` is red the moment the anchor goes.

### The `@dev[param]` shape needs no rung of its own

`.options savecurrents` under `preserve` writes `i(@R.X1.Rq[i])` (plan F4,
`receipts/00c-round3-verification.md`). It is an ordinary stored name, so rungs
1–2 resolve it in any casing — which the pre-item-2 ladder could not do, because
it never compared a folded *query* against a folded *stored name*, only against
whatever the in-place mutation had left. Checks `CS38c`–`CS38h`.

### `get_raw_index` always returns the entry of the REAL name

`raw_renamevar()` and `raw_deletevar()` take `entry_ret` and delete by
`entry->token`. Resolving through the alias index therefore looks the canonical
name up again in `raw->table` and returns *that* entry; handing back the alias
entry would leave the real one behind, pointing at a renamed or shifted column.
Checks `CS45e`–`CS45h` rename **through** a folded query and then assert the old
exact spelling no longer resolves.

### One pre-existing leak fixed in passing

`free_rawfile()` freed `raw->cursor_b_val` inside its `if(raw->names)` block,
but `raw_deletevar()` ends with `my_realloc(&raw->names, 0)`, which NULLs
`names[]` — so deleting the **last** variable leaked it (measured under
valgrind: 32 bytes definitely lost on a 4-variable raw whose every column is
deleted; the same script without the deletes, and one doing fuzzy lookups
without deletes, both report 0). Pre-existing, unrelated to the alias index —
fixed here because the review that measured it also measured that the index
itself leaks nothing.

### Other readers

The ladder is reader-agnostic: it works off `raw->names[]`, which `raw_read()`,
`vcd_read()` and `table_read()` all fill verbatim. Item 1 drove `raw case` on
spice and VCD databases only; `table_read` is now covered too (`CS48`–`CS48l`),
including the `raw case <mode>` re-read contract of §3 on a table database.

### What this does NOT change

- Nothing folds on **read**; only the query side is case-insensitive.
- `ngspice::ngspice_data` keys are still folded at the publish sites (§4);
  item 5b replaces that machinery.
- No consumer of `xschem raw list` folds in the dangerous direction — none does
  an exact lowercase comparison that this item's more forgiving lookup could
  make miss (item 2's sweep, item 1 carry-forward 3).

### RULING — the viewer's RPN gate mirrors the ladder, D2 included

The sweep above found the divergence running the *other* way, and it is a real
defect at the **default `fold` mode**, not a `distinguish`-only curiosity as an
earlier revision of this section claimed. `wviewer::validate_rpn`
(`src/wave_viewer.tcl`) lowercased both sides unconditionally, so it **approved
a token `get_raw_index()` declines** — and `raw_add_vector()` swallows
`plot_raw_custom_data()`'s `-1`, so `wviewer::add_trace` then plotted a
registered, all-zero vector with no error anywhere. Measured on a plain `fold`
database holding `Count` and `count`:

```
xschem raw index COUNT              -> -1     (D2 declines, correctly)
wviewer::validate_rpn {COUNT 2 *} … -> {}     (VALID — the gate disagreed)
xschem raw add tst {COUNT 2 *}      -> 1
xschem raw value tst 0              -> 0      <-- silently wrong
```

The gate now mirrors the ladder rung for rung — exact, case-folded, the same two
`v()`-wrapped — declines a folded key that two **different** stored names answer
(D2), and turns the folded rungs off when `xschem raw case` reports
`distinguish`. Checks `CS49`–`CS49o` assert **agreement in both directions** on
one token at a time: every check reads the engine's `raw index` and the gate's
verdict and fails if they differ, so "refuse everything" fails as loudly as
"approve everything".

Three residues remain, none of them able to produce a silent wrong number:

- rung 4 (`i(v.x…`) is not mirrored — the gate refuses a token the engine would
  resolve, loudly;
- `xschem raw case` reports the *current* database, so validating a **foreign**
  database's name list (`mixed_signal_signal_browser.md` §D1) uses the current
  one's mode;
- `wviewer::resolve_signal_db` (`:2538`) is a *second* case-folding matcher on
  the plain-vector path and still ignores D2. It cannot cause the defect above:
  that path never calls `xschem raw add`, so an unresolvable name yields a trace
  that plots **nothing**, not a column of zeros.

**Item 5** removes the mirror entirely by making both of them ask the engine.

## 10. MODE RESOLUTION — four sources in order — casemode item 3

`DECISIONS.md` **B2a** and **B2b**. `PLAN.md` §3b item 3; `DESIGN_REVISION.md`
§9 records why the item shrank to this (the File→Open-raw path needs no mode at
all, so what survives is the resolution order and the requested-mode floor).

**The question this answers is not the one §2 answers.** `Raw.case_sensitive` is
what the *lookup* does. This is what the *writer* did, and it is frequently not
knowable:

```
xschem raw casemode                -> unknown | fold | preserve | distinguish | upper
xschem raw casemode -source        -> none | explicit | header | schematic | sniff
xschem raw casemode -all           -> "<mode> <source>"
xschem raw casemode -explicit|-header|-schematic|-sniff   -> that source alone
xschem raw casemode <mode>         -> set the explicit source; `unknown` clears it
xschem raw casemode -floor         -> the global requested-mode floor
```

| rank | source | can answer | where |
|---|---|---|---|
| 1 | the user's explicit setting | fold, preserve, distinguish | `Raw.explicit_case_mode` |
| 2 | the `Option: casemode=` header | fold, preserve, distinguish | `raw_header_case_mode()`, stamped by `read_dataset()` |
| 3 | comparison against the schematic's own net names | fold, preserve, **upper** | `raw_case_mode_schematic()` |
| 4 | the capital sniff, **off by default** | preserve | `raw_case_mode_sniff()` |

### RULING — it REPORTS; it does not change behaviour

Nothing in §10 writes `Raw.case_sensitive`, and `xschem raw casemode
distinguish` deliberately leaves the lookup case-insensitive (check `CS59e`).
B2b is a **reporting** rule: the behaviour under `unknown` is still fold, and the
point is that the UI says "mode unknown" instead of asserting a fact nobody
established. The lookup flag has its own verb and its own contract — a set
**re-reads the file** (§3) — so coupling the two would mean merely *recording*
what a file is silently re-reading the user's database.

The one place the two touch: `raw_case_reread()` carries
`explicit_case_mode` across the destroy-and-re-read, because the explicit
setting is a property of the database, not of the bytes on disk, and losing it
to an unrelated `raw case` set would be a defect (`CS59m`). `hdr_case_mode` is
deliberately *not* carried — the re-read parses the header again, which is the
authority for it.

### RULING — absence is `unknown`, and the floor may not leak into it

The resolver returns `RAW_CASE_UNKNOWN` when all four sources are silent, and
`unknown` is a real answer rather than a failure. It is **permanent**: the
upstream patch that would make `casemodewrite` default on is written and has not
been sent (`RESPONSE.md` §9), so every released ngspice and every ver_50 file
written without `set casemodewrite` carries no line, indefinitely.

`sim_case_mode` — the global floor — is a **request about a run we are about to
make**, never a claim about a file somebody else wrote, and the resolver never
returns it. `CS64f` is that guard: with the global set to `distinguish`, an
evidence-free database still resolves `unknown none`.

### RULING — the header parse: anchored line, EXACT key, case-blind value

All three halves are measured, not chosen for symmetry.

1. **Anchored** on `Option:` at the start of the line. `Title:` is the deck's own
   first line and is user text — the upstream repro's own title is
   `* writes an ascii raw, so finding 1's header experiments can splice a line
   in`. A deck titled `* casemode=distinguish` must not set the mode, and one
   titled `Option: casemode=distinguish` arrives as `Title: Option: …` and must
   not either. Variable rows are tab-indented and are refused by the same
   anchor. Checks `CS53`–`CS53d`.
2. **The key is matched EXACTLY.** Measured 2026-08-16 on `build-ver_50`:
   `-D CaseMode=distinguish` and `-D CASEMODE=distinguish` both leave
   `$curcasemode` at `fold`, **silently** — ngspice variable names are
   case-sensitive (upstream `FINDINGS.md` §6, "a misspelled variable *name* is
   silent"). So `Option: CaseMode=preserve` records some *other* variable, and
   reading it as the case mode would claim a mode for a file whose mode was
   never set. Checks `CS54`, `CS54b`.
3. **The value is matched case-INSENSITIVELY.** Measured on the same build:
   `-D casemode=PRESERVE` and `-D casemode=Preserve` both give
   `$curcasemode == preserve`. Checks `CS55`, `CS55b`.

Split on the **first `=`** and **trim both halves** — upstream keeps the trim
because a foreign `Option:` value beginning `,`, `<=` or `>=` is re-emitted with
spaces around the `=` (`RESPONSE.md` §1(b)). Check `CS56`.

**Only the `Option:` key.** A `Casemode:` key is refused although it is the
obvious spelling: ngspice's own reader **aborts the load** on it (`Error:
strange line in rawfile`, measured on 46 and on ver_50, `FINDINGS.md` §1), so
nothing can be writing it. `Command: set casemode=preserve` is refused too —
`Command:` is free-text provenance and is never parsed, which is also why item 1
could not identify a Xyce raw (§5). Checks `CS52b`, `CS52c`.

**The key anywhere in the header, and the FIRST one wins.** Upstream writes
exactly one line but in two *places* — immediately after `Plotname:` in the
session's own file, after `No. Points:` in a copy — so a line-5 check misses the
second (`RESPONSE.md` §2). Scanning every header line covers both and covers the
misplaced before-`Plotname:` position as well. A second, *disagreeing* line is
ignored and named in a `dbg(0)`: a header can carry a key twice (the repro's
`hdr_cmd.raw` carries two `Command:` lines), and letting a later line win would
let an appended one overrule the writer. Checks `CS50`–`CS51c`, `CS57b`.

### RULING — the line belongs to its DATASET, not to the file

The first revision of this section said "this is per FILE, not per dataset:
every dataset in one raw was written by one session in one mode". **That premise
is false**, and ngspice's own writer is the counter-example: `rawfile.c:204`
emits the casemode line only for a plot that is **not** `pl_fromfile`, while
`rawfile.c:222/262` **re-emit** a from-file plot's own `Option: casemode=` out of
`pl_env`. So `write all.raw <a plot loaded from a preserve file> <this session's
fold plot>` really does produce two *disagreeing* lines in one file, and
first-wins then reported, at source rank 2, the mode of a dataset **the user did
not load**.

The line is therefore attributed the way `read_dataset()`'s neighbouring header
branches (`No. of Data Rows :`, `No. Variables:`, `No. Points:`) attribute
theirs — `sim_type` is non-NULL only inside the dataset being loaded. **One
exception:** a line arriving *before any* `Plotname:` has no plot to belong to,
is the file's own, and is one of the two positions upstream actually emits
(`RESPONSE.md` §1(b)); `sim_type` is still NULL there, so the test is
`sim_type || !seen_plotname`. Both halves are load-bearing: dropping `sim_type`
reddens `CS57d`, dropping `!seen_plotname` reddens `CS51`. Checks `CS57c`–`CS57f`
(a two-plot raw whose OP says `fold` and whose TRAN says `preserve`; each load
reports its own).

**One anchor, not two.** `read_dataset()`'s branch test is the loose
`strstr(line, "Option:")` on purpose. With the anchor stated in both the caller
and the parser, deleting either copy still refuses the Title injection —
measured, the whole suite stayed ALL PASS with the parser's anchor removed. The
parse owns the rule; the branch only avoids calling it on every line.

### RULING — the schematic comparison, and its limits, implemented

Source 3 compares the raw's **plain `v(<node>)`** names against the names the
schematic owns and reports what the writer did to them. Its advantage over the
capital sniff it replaces is a reference point, and a **third outcome**: a net
drawn `MidNode` arriving as `V(MIDNODE)` is neither mode — the sniff calls it
`preserve` and is wrong (`CS60d` against `CS63h`, which asserts the sniff would
have said `preserve` on the same file).

**Names the schematic owns** = the `lab=` attribute of an instance **or of a
wire** — both arms carry checks (`CS61m`/`CS61n` drive a design whose nets are
wire `lab=` records and zero instances; deleting the wire loop used to leave the
whole suite ALL PASS). Deliberately **not** `xctx->node_table`: reaching it means calling
`prepare_netlist_structs()`, which is not a read-only query (it runs
`free_simdata()`, `delete_netlist_structs()` and a `statusmsg`), and its tokens
include propagated and auto-generated names as well as drawn ones. A heuristic
ranked third may not have side effects.

The limits `DECISIONS.md` B2a records, each with the check that holds it down:

| limit | how it is implemented | check |
|---|---|---|
| it needs a schematic; File→Open-raw may have none | no candidates ⇒ unknown | `CS62` |
| an all-lowercase design gives no signal | a schematic name with no capital is not counted — `fold` and `preserve` write the same bytes for it | `CS61e` |
| never against simulator-constructed names | only `v(<node>)`, and `<node>` must be a plain identifier: hierarchy separators (`x1.midnode`, Xyce's `x1:midnode`), the `.dc` axis `v(v-sweep)` and every `i(…)` are out | `CS61d`, `CS61h` |
| it cannot separate `preserve` from `distinguish` | case-kept reads as `preserve`, the safe reading | `CS60c` |
| "most of them agree", not a single hit | ≥ 2 comparable names **and** a strict majority; a tie is unknown | `CS61`, `CS61b`, `CS61c` |
| a design that owns two nets differing **only in case** cannot be read | the exact spelling wins; two different spellings folding to one key are AMBIGUOUS and nothing votes | `CS61i`–`CS61k`, `CS61o` |
| it only speaks for **its own** schematic | `raw->schname`/`raw->level` must match `xctx->sch[xctx->currsch]`, else unknown | `CS62b`–`CS62d` |

One case B2a does not name and the implementation has to: an **all-CAPITALS**
schematic name (`EN`, `VDD`) that came back unchanged is ambiguous — `preserve`
and `upper` produce the same bytes — so it does not vote. The *folded* spelling
of the same name is still unambiguous and still does. Checks `CS61f`, `CS61g`.

### RULING — exact spelling first, and two spellings mean none

`sch_owned_name()` returns the schematic's spelling of a raw node name. It used
to return the **first case-insensitive hit**, and that was a defect, found by two
independent reviewers of item 3: in a `distinguish` design — the exact design a
case-capable simulator exists for — `EN` and `en` are two different nets, and
attributing the raw's `en` to the schematic's `EN` scored a confident `fold`
vote for a file that had **preserved** every name. It gave the identical verdict
for the folded and the case-kept file, and the answer **flipped when the two
labels were merely reordered in the `.sch`**.

Three rules now, in order:

1. **An exact `strcmp` match wins outright**, wherever in the file it sits.
   Where the design itself is unambiguous about a spelling, exactness settles it.
2. Failing that, a **unique** case-insensitive match is the schematic's spelling.
3. **Two or more different spellings folding to the same key are AMBIGUOUS** and
   the name is skipped entirely — the same treatment the all-CAPITALS case
   already gets. `V(MIDNODE)` against a design owning both `MidNode` and
   `midnode` would otherwise read `upper` off one spelling and "no signal" off
   the other: one file, two answers, decided by `.sch` order (`CS61o`).

**Cost.** Returning early only on an exact hit means a *folded* raw walks the
whole instance+wire list per candidate. Measured at 2000 instances x 500 `v()`
names: all-exact-hit 21 ms, all-folded-hit 147 ms, all-miss 189 ms. The source
has no cache and the verb recomputes it for both `-schematic` and `-all`, so a
UI must call it **on demand, never from a redraw**.

**Residual limit, stated rather than fixed:** a `fold` run over a design that
owns two case-twin nets is genuinely undecidable — the two nets collided into one
column and there is nothing left in the file to tell fold from preserve. The
answer is `unknown`, which is the honest one (`CS61j`).

### RULING — a comparison only speaks for its own schematic

`raw_case_mode_schematic()` returns `RAW_CASE_UNKNOWN` unless `raw->schname`
matches `xctx->sch[xctx->currsch]` (and `raw->level >= 0`). Those fields are
already stamped on every Raw by `raw_read()`, `table_read()` and
`extra_rawfile()`. Without the gate, and because **`xschem load` does not clear a
loaded database**, opening an unrelated design flipped an untouched file from an
honest `unknown` to a confident and wrong verdict — evidence manufactured out of
two files that have nothing to do with each other. A comparison against a
schematic the file was not produced from is not weak evidence, it is none.
Checks `CS62b`–`CS62d`.

`CS61h` is the one that holds the candidate filter down, and it is worth stating
because `CS61d` does not: a name the schematic does not own cannot pollute the
vote anyway, so excluding `v(x1.…)` is only observable when the schematic
*happens to own* a colliding name. `CS61h` builds exactly that — a design with a
net called `V-Sweep`, read against a sweep whose axis ngspice spells
`v(v-sweep)`. Counting the axis would give a confident `fold` off one real net
plus a name the simulator invented.

### RULING — the sniff can never answer `fold`, and defaults off

Source 4 answers `preserve` when **any** stored name carries a capital and
`unknown` otherwise — *any*, not the first: the realistic tran shape has the
capital-free `time` in `names[0]`, and restricting the scan to `names[0]` left
the suite ALL PASS while the sniff answered `unknown` for the committed
`tr_preserve.raw` (`CS63i`, `CS63j`). **"No capitals" is not evidence of `fold`**: an
all-lowercase design under `preserve` writes exactly the same file (`CS63e`).
And a capital is weak evidence the other way — `RESPONSE.md` §4 records that a
`fold` run hands back the *deck's* spelling when the deck names the vector, so
`write f.raw v(In)` under `fold` writes a capital. Hence last place, and hence
the Tcl gate `raw_case_sniff`, default `0` (`CS63`, `CS63c`).

### The global floor, `sim_case_mode`

A Tcl global, default `fold`, read from C by `sim_case_mode_floor()`, which
validates it and falls back to `fold` for anything it does not recognise —
including `unknown`, because the floor is never unknown. It is **the one place
`fold` is asserted without evidence**, and that is legitimate: it is what we ask
a simulator for when no profile names a mode, and `fold` is what a released
ngspice does (`DECISIONS.md` A1; C2's "assume `fold` when no profile is set").
Item 6 layers per-profile modes on top of it; item 14 is its first consumer.
Checks `CS64`–`CS64f`.

### Tests, and what is NOT covered

`tests/headless/test_raw_case_mode.tcl` sections V–AA, checks `CS50`–`CS64f`
(91 new, 277 in the file — 75 from the item, 16 added by the fix round:
`CS57c`–`CS57f`, `CS61i`–`CS61o`, `CS62b`–`CS62d`, `CS63i`, `CS63j`).
The header shapes are written **inline** rather than
read from
`doc/claude/ngspice_upstream/feedback/ngspice_upstream/repro/hdr_*.raw`, which is
where they come from: those files are gitignored (`repro/.gitignore` is `*.raw`)
and regenerated by `hdr_variants.sh` from a live case-capable ngspice, so a
committed suite cannot read them. Every header line is copied byte for byte from
the real spliced file it names, and all eleven of those files were additionally
driven through this binary by hand — see the item 3 receipt.

Not covered: no simulator writes a raw during the suite (no ngspice is invoked);
the GUI control B2a asks for — "show what was detected and allow an override" —
is **items 5 and 13**, and this item deliberately ships only the engine side.
