# 1281 — saving the project settings file exports the author's personal user-global settings into it

**Status: MEASURED, FILED, NOT FIXED.** Found by item B2's adversary pass,
2026-09-03. Latent: nothing calls `write_conf` yet.

For a feature whose stated headline is *"shareable with teammates"*, Save
checks the author's **personal** taste into the file the team shares.

## The measurement (2026-09-03, `src/op_param_lists.tcl` md5 `bf023075`)

With

```
class diode  -> from ~/.xschem/op_param_lists.conf      (a personal remap)
param class diode summary vd vd 2                       (a personal list)
```

already loaded from the **user-global** tier, calling
`op_param_lists::write_conf` on the **project** path emits **both rows into the
project file**.

The cause is structural, not a slip: `load_conf` merges every tier into one flat
`classmap` / `lists` / `owned` triple, and `write_body` writes whatever is in
them. **The store keeps no provenance**, so the writer cannot tell "the user set
this globally, for every project" from "this project needs this".

## Why it matters

D-7's plain reading is *"nothing has to be checked in until something is
changed"*, and `write_body` honours that for the PDK seed — a class still on
the seed produces no row (row W4). It does not honour it for the tier above.
The result is that the first `git add .xschem/op_param_lists.conf` carries the
author's global class map and global lists to everyone who clones, and the next
teammate to press Save carries **theirs** back, so the shared file oscillates
between two people's preferences and diffs on every commit by either.

## Why the suite did not see it

`grep` for a cross-tier write row in `test_op_param_store_1245.tcl`: none.
Section T proves the tiers **read** correctly (project beats user-global per
list, a user-global `summary` survives a project file that customises
`annotation`). No row writes after loading two tiers.

## Recommended fix

Tag each entry with the tier it arrived from — one parallel array,
`origin(<key>) = seed|user|project|session` — and have `write_body` emit only
entries whose origin is the tier being written, plus everything set in this
session. That also makes the CIW line honest (*"3 lists written to
`<path>`"*, not 3 written and 5 exported).

**Rejected: writing everything and documenting it.** A shared file that quietly
carries one person's global preferences is the failure the shareability
requirement exists to prevent.

**Rejected: refusing to write an entry that came from the user-global tier.**
A user who wants to promote a personal list into the project must be able to;
the fix is to know which is which, not to forbid one direction.

## Acceptance rows this needs

* T4 — with a user-global entry loaded and untouched, writing the project file
  emits **no row** for it.
* T5 — an entry the user changed **in this session** is written to whichever
  tier is being saved, whatever tier it originally came from.

## Who inherits this

**Item B5** owns Save. The provenance has to exist in the store (B2's seam)
before B5 can write only the right half.

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

## What the attempt did (item B2a — **FIXED**, 2026-09-03)


`src/op_param_lists.tcl`. The store now knows where every entry came from.

* Two parallel arrays, `origin` (keyed exactly as `owned`) and `classorigin`
  (keyed on the `type=` token), each holding `user`, `project` or `session` —
  the same parallel-array idiom `owned`/`warned` already use.
* `load_conf` gains an **optional trailing tier**, defaulting to `session`.
  Its **required arity does not move**: it is a published verb this suite's own
  header pins, and section T plus rows P1–P6, X1–X7, M3, S1b and W3 all call it
  directly with an arbitrary path. `load` passes `user` / `project`.
* `set_list` and `set_class` stamp `session`.
* New `_path_tier {path}` in `write_conf` names which tier a path **is** —
  by the path the caller asked for, before any symlink resolution, because
  saving "the project file" is a statement about which slot, not about which
  inode it points at today. `{}` means neither.
* New `_origin_ok {who tier}`, and `write_body` gains an optional `tier`:
  an entry is written when it was changed **in this session**, or came from the
  very tier being saved, or the caller named no tier at all.

The `session` default and the write-everything fallback are what keep rows W3,
W4 and W5 — including **W5's byte-identity assertion** — exactly where they were.

**Rejected: refusing to write a user-tier entry at all** (this issue's own
rejected option). Promoting a personal list into the project must stay possible;
the fix is to know which is which, and row **T5** is the fence on that.

## Red before green

| row | red on | green after |
|---|---|---|
| `T4` | `{1 1 2 1 2 2 2}` — two `diode` data rows, the `class diode mydiode` remap and `usersum` all exported into the team's file | `{1 1 0 0 0 1 2}` — nothing personal, and the one list this session changed IS written |
| `T5` | no provenance existed to distinguish the two directions | a user-tier entry **changed here** is written; a direct one-argument `load_conf` on an arbitrary path still works and still writes everything back |

Sabotage, with the fix in place: `SB-NO-PROVENANCE` (`_origin_ok` → `1`) →
**T4 and T5 red**, `RESULT: 2 FAILED (54 passed)`.

## ⚠ Why this was reverted — THE FIX TURNS A LEAK INTO SILENT DATA LOSS

Found by the adversary pass and **reproduced independently by the write-up
agent** 2026-09-03, `tclsh` driving the attempt's own `op_param_lists.tcl` with
`::USER_CONF_DIR` set so the tier filter really engages.

Fixture — the user's personal file carries a personal class remap, a personal
`mos` annotation list and a `diode` list; the project file overrides the same
remap and the same `mos` list:

```
user   : class mydiode diode / list class mos annotation / param class mos annotation MYID id 0
         list class diode annotation / param class diode annotation VD vd 2
project: class mydiode diode / list class mos annotation / param class mos annotation TEAMID id 0
```

After an ordinary `op_param_lists::load` (user then project, project wins) and
then `write_conf <the USER path>` — the user saving to their **own personal
file**:

```
rc=1
reports=0
--- USER file after saving to the USER path ---
version 2
list class diode annotation
param class diode annotation VD vd 2
```

**The user's own `class mydiode diode` remap and their own
`param class mos annotation MYID id 0` are GONE.** They were stamped `project`
by the override, `_origin_ok project user` is 0, and the store keeps no
user-tier copy to fall back on — so the tier filter deletes the user's personal
data from the user's personal file.

`rc=1`, `reports=0`. **That is issue 1276's exact shape — "reports success when
the file went elsewhere" — reproduced by the sibling fix in the same diff.**
HEAD, on the same fixture, deletes nothing: it keeps a `mos annotation` row
carrying the team's content, which is the *leak this issue was filed about* and
is strictly the lesser failure.

Latent today, because nothing calls `write_conf` — but **item B5's scope dialog
is exactly that caller**, which is why the driver put 1281 before B5.

**What the next crew must do.** Provenance needs to be a *per-tier value store*,
not a single flattened store plus an origin stamp: keep what each tier said, so
saving a tier can write back what *that tier* said rather than whatever won the
merge. A one-word origin cannot express "the user said MYID and the project
overrode it" — it discards the losing value at load time, and the writer then
has nothing to write. Add the acceptance row above (`load` both tiers, override
the same key, save the user tier, assert the user's own value survives) — the
existing rows T4/T5 do not construct a *conflict*, which is why they passed.

---

## Item B2a-2 — ATTEMPTED, MEASURED, AND REVERTED, 2026-09-03

B2a-2 implemented **exactly what this issue's own "what the next crew must do"
paragraph demanded** — a **per-tier value store** — and it fixed the case B2a
destroyed. It was still reverted, because it **destroys a different row the user
typed**, and this issue exists to stop precisely that.

### What B2a-2 changed, and what it genuinely fixed

`origin` and `classorigin` became **sets** of tiers (`_origin_add` joins,
`_origin_only` replaces for a session edit) instead of one slot the later `load`
overwrote; two new arrays `tierlists` / `tierclass` hold **what each tier's file
actually said**; `_origin_ok` became `_writes_here` (*may this row be written
here*) and `_tier_list` / `_tier_class` supply **which value**.

Measured on the adversary's own fixture, both tiers contesting both rows: the
user file comes back holding the user's `USER_Id` and keeping the user's own
`class mydiode diode` and their user-only diode list; the project file holds
`PROJ_Id` and emits **no** row for the user-only list. The B2a data-loss case is
fixed and row **T6** fences it.

### Why it was reverted — a second deletion, on a path T6 cannot see

Reproduced first-hand by the write-up agent on the patched tree. Fixture: the
shipped default already maps `nmos → mos`; the **user** file carries the
explicit pin `class nmos mos`; the **project** file carries
`class nmos weirdclass`.

```
after load: classmap(nmos)=weirdclass  classorigin=user project
_tier_class nmos user   = mos
--- USER FILE AS WRITTEN BACK ---
   |version 2
user's own 'class nmos mos' present: NO -- DESTROYED
```

`write_conf <user path>` returns **rc=1 with zero reports** and the user's own
file afterwards holds **`version 2` and nothing else**. The mechanism is the
fix's own improvement: `write_body` now compares the shipped default against
`_tier_class $tok $tier` — the **user's own value**, `mos` — instead of the
merged value, so the row is skipped as *"not an override"*. HEAD wrote
`class nmos weirdclass` there: the leak, a row with the wrong value. **B2a-2
converts that leak into a silent deletion of a line the user typed** — the exact
transformation this item existed to undo.

Stated honestly, because it changes the severity: the deleted row was already
**inert** — the project row won the merge either way — so no behaviour flips
today. What is destroyed is a **declaration of intent**. The class map is
written as overrides *precisely so* a future change to the shipped default still
reaches a project; a user who pinned `nmos` to `mos` on purpose loses that pin
and will silently follow the default when it moves.

Row **T6** cannot see it: T6's contested token maps to `diode`, a **non-default**
value, so the default-skip branch is never taken.

### A second hole: the original leak is still reachable

`set_list class mos annotation {…}` — invariant **I5**'s own documented rc door
— stamps `origin = {session}`. A **subsequent** `op_param_lists::load` calls
`_origin_add`, which *appends*, giving `{session user}`. `_writes_here` then
answers 1 for the **project** tier because `session` is in the set, and
`_tier_list` returns the live list. Measured: a key declared **only** in the
user file is written into the **project** file carrying `USER_Id`. That is this
issue's original privacy defect, intact, one ordering away from the fixture the
suite tests.

## Still open after B2a-2 — what the third crew must fix

1. **The default-skip must compare like with like.** A row a tier's own file
   *contains* must be written back to that tier's file **even when its value
   equals the shipped default**. The override-compression is a fair optimisation
   for a row the store *synthesised*; it is not one for a row the user typed.
   The store must distinguish "this tier declared it" from "this tier's value
   happens to equal the default" — it now has `tierclass` and can.
2. **A later `load` must not widen a session stamp.** `_origin_add` appending to
   `{session}` is what re-opens the leak. Decide what a load means for a key the
   session already changed, and fence **both** orders (set-then-load and
   load-then-set) — the suite currently fences only one.
3. **Keep the per-tier value store.** It is right and it is this issue's own
   recommendation; only the two branches above are wrong.
4. **The fence must construct a tier conflict on a DEFAULT-VALUED token.** That
   is the row whose absence hid this for a whole item.

---

## ATTEMPT 3 — item B2c, 2026-09-03: REBUILT ON RULING DD-7, AND REFUTED AGAIN

**This is the third revert on this issue.** DD-7 replaced the design that failed
twice: *"writing a tier reads that tier's existing file, changes only the keys
this session actually changed, and writes it back. Every other row is preserved
verbatim, including rows this build does not understand."* No provenance model,
no tier tags — **provenance becomes a property of which file you opened.**

**The new shape is right and most of it works.** It failed on one hole, filed as
issue **1294**, and the patch is preserved at
`doc/claude/op_param_batch/B2c_working_tree_REVERTED.patch`.

### What the patch does

* **`variable dirty` / `variable dirtyclass`** — a *dirty set*, not a provenance
  model. Stamped by `set_list`, `set_class`, and by `_parse_line` when the load
  is stamping. **Cleared only by `reset`**, never by a successful write, so a
  user who saves both tiers gets the change in both.
* **`load_conf {path {stamp 1}}`** — a **direct** `load_conf` stamps (importing
  a file into your session *is* a session change); **`load`**, the two-tier
  startup restore, passes `0` and stamps nothing (that is the session's initial
  state). Required arity unchanged.
* **`_read_lines {path}`** — the raw-line reader, reusing `load_conf`'s own
  preamble so there is one splitter and two consumers (invariant **I1**).
* **`write_body {fp {old {}}}`** → `_merge_lines`, which walks the old file **in
  order**: comments, blanks, `version` and any row this build does not identify
  are copied **verbatim**; a dirty `class` row or a dirty `list`/`param` group is
  replaced **in place at its first line**; then rows for dirty keys that had no
  group are appended. **The header and `version` are emitted only into a file
  with no lines.**
* **The class map loses its default-comparison filter.** A token this session set
  is written whether or not its value equals the shipped default. **That retires
  B2a-2's exact refutation structurally**, not by care.

### Measured after — the B2a-2 case, all four halves (row T4)

User file carrying `class mydiode diode`, `class nmos mos` (**value equals the
shipped default**), `param class mos annotation MYID id 0` and
`sometotallyfuturerow whatever 1`; project file carrying `class nmos weirdclass`
and `param class mos annotation TEAMID id 0`.

| | before (HEAD) | after |
|---|---|---|
| user's `class mydiode diode` | kept | kept |
| user's `class nmos mos` (= default) | **DELETED** | **kept** |
| user's `param … MYID id 0` | **DELETED** (project's TEAMID won) | **kept**, TEAMID absent |
| `sometotallyfuturerow whatever 1` | **DELETED** | **kept** |
| whole file | rewritten | **byte-identical** |
| `write_conf <project>` | **exports** the user's personal `mydiode` | no user-only row leaks |

### ⚠ WHY IT WAS REVERTED ANYWAY — issue 1294

**A `param` row this build cannot parse, whose key this session changed, is
deleted on save. rc=1, ZERO reports.** The writer's merge classifier `_row_id`
validates verb → scope → arity and stops; the reader `_parse_line` also runs
`_valid_list`, the livelist guard and `_triple`. So
`param class mos annotation NEWROW raw ratio` is refused by the reader and
**identified** by the writer, and the group is rebuilt without it. **DD-7's own
justification — *"you cannot delete a row you never parsed into a model"* — is
false whenever the writer can identify what the reader rejected.**

**Row T4 above cannot see it**, because its future row has an **unknown verb** —
the one class `_row_id` genuinely cannot identify. The rows a newer build
actually writes are known verbs whose value vocabulary grew.

**The fix is named in 1294:** `_parse_line` calls `_row_id`, so there is
genuinely one builder — which is what this item's own plan specified in writing
and the code did not build.

### Two more, filed separately, not the reason for the revert

* **Issue 1295** — the merge **rewrites line endings**: a CRLF file comes back
  all-LF, rc=1, zero reports, every untouched line's bytes changed. "Preserved
  verbatim" is not byte-true. An interleaved user comment also moves.
* **Issue 1296** — an existing file **never gains the precedence sentence**, and
  a v1 file keeps `version 1` while gaining v2 rows. **Needs a ruling.**

### ⚠ The seam that pins `load` vs `load_conf`, for whoever lands this

Five existing green rows — **M3, X3, P5, P4, W5** — do `load_conf X` →
`write_conf Y` → reload and assert the content copied. If stamping happens
**only** in `set_list`/`set_class`, M3, X3 and P5 go **red** and P4 passes
**vacuously**. If it happens in `load` too, this issue's leak reopens. The rule
above is the only one that satisfies DD-7 literally *and* keeps all five green,
and sabotage arm **SB-DIRTY-NEVER** reds exactly those rows. It is a ladder-**L2**
decision and is recorded, not slid in.
