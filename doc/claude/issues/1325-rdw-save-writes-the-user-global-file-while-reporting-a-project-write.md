# 1325 — Save writes the USER-GLOBAL settings file while reporting a project write

**Status:** **PARTIALLY FIXED** by item **B5-a**, 2026-09-04 (was: FILED, NOT
FIXED; was briefly marked FIXED by B5-a's implement pass and **downgraded by
its own adversary** — see *Still open*, and issue **1327**). Which tier Save writes is unchanged and stays issue **1273**'s, which is the user's. Measured 2026-09-04 on `fluid-editing` at
`c940a5df`; the `conf_path` collision reproduces with **no item-B5-2 code**, and
the caller that hardcodes the tier was reverted with B5-2.
**Component:** `src/rdw.tcl` — `rdw::_do_save` (in the preserved patch,
`B5-2_working_tree_REFUTED.patch`) · `src/op_param_lists.tcl` — `conf_path`,
`load`.
**Related:** ruling **DD-7** (*Save is a read-modify-write of **one tier's own
file***), issue **1281** (the project file exports the author's user-global map),
issue **1276**, store-suite row **BE5**.

## The mechanism

`rdw::_do_save` picks its tier with a literal:

```tcl
catch {set path [::op_param_lists::conf_path project]}
```

The **project** tier resolves relative to the current working directory. xschem
is ordinarily launched from the user's home directory, and there the project
tier and the user tier are **the same file**.

## The measurement

With cwd `$HOME`, which is how the binary is normally started:

```
USER   =/home/analog/.xschem/op_param_lists.conf
PROJECT=/home/analog/.xschem/op_param_lists.conf
SAME=1
```

`op_param_lists::load` **already dedupes this case** — it knew the two tiers can
collide and refuses to read the same file twice. `_do_save` does not.

## The consequence

Pressing Save in a window about one design rewrites the settings that apply to
**every** design the user opens, while the status line reports a project write.
Two rulings and one suite row go vacuous in the common case:

* **DD-7's *"one tier's own file"*** — there is only one file.
* **DD-7's preserve-every-other-row promise** still holds mechanically (it is a
  read-modify-write of *that* file), but the user's mental model of which file
  they touched is wrong, which is the half DD-7 exists to protect.
* **Store row BE5** asserts *"the OTHER tier's file is not touched at all"*. It
  passes by writing and checking two paths that, in this configuration, are one
  path — so it can pass while proving nothing.

## Recommended fix

`_do_save` resolves both tiers and, when they are equal, **says so in the
sentence it already prints**: name the actual path and state that this tree has
no separate project file. The write itself is then correct and the report is
true. `load`'s existing dedupe is the precedent for detecting it.

The larger question — whether Save should default to project at all, or ask, or
follow the tier the governing row came from — is the **user's**, not a crew's,
and it is adjacent to issue 1281's unresolved provenance problem. Do not settle
it inside a fix for this.

Rejected alternative: **make `conf_path project` return empty when it collides
with the user tier.** That changes a shipped accessor used by `load` and
`write_conf` for the benefit of one caller.

## Still open

All of it, plus the suite consequence: **row BE5 must construct a project
directory that is genuinely not the home directory** before it can fence what its
title claims.


---

## FIXED — item B5-a, 2026-09-04

**The report is made honest. Which tier Save writes is NOT changed** — issue
**1273** ("which directory *is* the project") is a live rule debt on the owed
ledger and is the user's to settle, and this item's job was to make the code
honest about which tier it wrote, whatever that tier turns out to be.

### `src/op_param_lists.tcl` — one new published verb

```
op_param_lists::conf_tiers <path>
  -> the tiers whose conf_path normalizes to this path, in {user project} order
  -> {} for a path that is neither
```

Read-only by construction: it creates no directory and no file for a path that
does not exist yet, pushes no report, and owns no list. It copies `load`'s own
collision detector (`file normalize` against the other tier) rather than
inventing a second idiom, but `load` is **not** rewritten to consume it: `load`'s
`seen` list answers a different question ("have I already read this normalized
path") over a loop, and merging them for elegance would risk rows **T2** and
**T3**, which are green. Store row **CT2** locks the two together **by
assertion** instead — the `governs` precedent applied as an assertion rather
than a merge.

**Rejected, as this issue itself rejects it:** making `conf_path project` answer
empty on a collision. `load` and `write_conf` both depend on that accessor.

### `src/rdw.tcl` (in `B5-2_working_tree_REFUTED.patch`) — one named callee

`rdw::_do_save` keeps `conf_path project` and gains `rdw::_tier_note {path}`,
which appends, **on the success arm only**:

> That file is both tiers here - this project directory and your user
> configuration directory are the same directory - so every design on this
> machine reads it back (issue 1273 asks which directory is the project).

Success arm only, because a refused Save changed nothing, so the false belief
the sentence corrects never forms — and the refusal arm already carries the
STORE's own wording, which must not be diluted by a second sentence about a file
that was not written. A named callee rather than three lines inline, so a
sabotage variant has something to neutralise.

### ⚠ This issue's own claim about row BE5 is wrong, and was not copied

It says BE5 *"passes by writing and checking two paths that are one path"*. It
does not: BE5 builds `$BE_ROOT/p5/.xschem` and `$BE_ROOT/home5`, which are
genuinely distinct, so it already fences what its title says. **The real gap was
that no row anywhere exercised the COLLIDING configuration on the WRITE path.**

### Fenced by

* store `CT1` `CT2` `CT3` (both arms) — the collision, the agreement with
  `load` in both configurations, and the read-only property.
* store `BE9` (in the patch) — **both arms in one row**: in the colliding
  configuration the status line names its file AND says the file is both tiers;
  in a genuinely distinct project directory the clause is ABSENT. A note that
  were unconditional reds the second arm; one that were never emitted reds the
  first.

### Sabotage receipt

`SAB-TIERS-BLIND` (`conf_tiers` replaced by `{return [list project]}`, on a COPY
of the tree, restored by `cp`, md5-verified) reds store `CT1 CT2 CT3`.

### ⚠ And the collision is not academic

The Measure agent's own probe of the reverted `rdw::_do_save`, run with cwd
`$HOME`, **wrote synthetic rows into the developer's real
`/home/analog/.xschem/op_param_lists.conf`** before this fix existed. Every row
that touches the save path now redirects BOTH `::USER_CONF_DIR` and the cwd into
the scratch tree, copying store row T3's fixture.

---

## ⚠ Still open — THIS ISSUE'S OWN TITLE STILL REPRODUCES. See issue 1327.

Item B5-a's **adversary refuted this fix**, and the write-up agent reproduced
the refutation independently before recording it. The fix closes the case this
issue was filed for — two tiers colliding **because of the cwd** — and does not
close the case where the project settings file is a **symlink** to the
user-global one:

```
CONF_TIERS_OF_PROJ=<project>                       <- names ONE tier
USER_GLOBAL_FILE_CHANGED=<1>  (size 1627 -> 1689)  <- the bytes went to the OTHER
GREP_zzz_IN_USER_GLOBAL=<1>
```

`file normalize` does not resolve a path's **final** component. `write_conf`
resolves the link chain with `_resolve_target` and writes the real file (issue
1276, and it is right to); `conf_tiers` compares unresolved strings, so it
cannot see the collision, the note never fires, and the status line names the
project path while the user-global settings are rewritten — **the sentence at
the top of this file, verbatim.**

**Bounded, so it is neither widened nor dismissed:** the cwd collision is caught
(row `CT1`), a symlinked `.xschem` **directory** is caught (`file normalize`
does resolve intermediate links, measured `user project`), and only the
symlinked **final component** is missed. No fixture in any suite creates one.

Filed as issue **1327** with its measurement, the fix shape (publish
`_resolve_target`'s answer; make `conf_tiers` resolve both sides), the required
both-directions fence, and why B5-a filed rather than hot-fixed it. **1327 is a
precondition on item B5-3**, which is the item that puts Save in front of a
user. Until it is closed, do not cite this issue as FIXED.

## Still the user's, recorded as a rule debt

The exact wording of the collision sentence `rdw::_tier_note` appends, and
whether Save should keep defaulting to the **project** tier at all — which is
issue **1273**, *"which directory IS the project"*, already on the owed ledger.
