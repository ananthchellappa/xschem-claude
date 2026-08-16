# Raw case mode — names are stored verbatim; `case_sensitive` is a lookup flag

Status: **item 1 of the casemode batch is implemented** (this document); items
2–15 are not. Written 2026-08-16.

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
  evidence is "unknown", never "fold". Item 3 adds the four-source mode
  resolution; this flag is not it.
- Nothing in the read path reads it. Item 2 is its first consumer: it suppresses
  the folded-alias rung in `get_raw_index()`.

### The item-1 lookup gap, stated precisely

Until item 2 lands, **every BARE (unwrapped) node name misses against a
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

- The case-folded alias rung and the collision rule — item 2.
- Mode detection from the `Option: casemode=` header, schematic comparison or a
  capital sniff — item 3.
- The four `hilight.c` senders, the viewer Tcl, `sod_expr`, the simulator
  profile and its probe — items 4–13.

## 7. Tests

`tests/headless/test_raw_case_mode.tcl` (prefix `CS`, 81 checks, true headless).
Data: the two committed fixtures
`doc/claude/casemode_batch/fixtures/tr_{fold,preserve}.raw` — byte-comparable
229-point binary raws differing only in their Variables section, so no simulator
is needed — plus an inline ASCII AC raw for the four-derived-names case.

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
