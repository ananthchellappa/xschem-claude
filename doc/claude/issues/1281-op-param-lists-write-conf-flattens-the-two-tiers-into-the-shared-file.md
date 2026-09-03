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
