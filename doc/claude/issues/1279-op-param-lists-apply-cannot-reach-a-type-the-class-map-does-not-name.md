# 1279 — `op_param_lists::apply` cannot reach a type the class map does not name

**Status: MEASURED, FILED, NOT FIXED.** Found by item B2's adversary pass,
2026-09-03. Latent: nothing calls `apply` yet.

The class map is an **override table** for `class` and `effective` — an
unmapped `type=` token is its own class, which `src/op_param_lists.tcl`'s own
header calls the design's key property, and spec §4.3's promise that *"a PDK
with a token nobody anticipated is a one-line user fix and not a tool release"*
rests on it. For `apply` it is a **gate** instead, and the promise fails there.

## The measurement (2026-09-03, `src/op_param_lists.tcl` md5 `bf023075`)

```tcl
op_annot::register widgetron [dict create params {{a a 0}} match {*wid*}]
op_param_lists::set_list class widgetron annotation {{zz zz 1}}
op_param_lists::apply              ;# no args
op_param_lists::apply widgetron    ;# named
```

```
UNMAPPED class=widgetron apply_noargs= gen 1->1 apply_named=widgetron gen->2
```

`class widgetron` correctly answers `widgetron` (the identity fallback), and the
user's list is correctly stored and correctly returned by `effective`. But
`apply` with no arguments returns **{}** and `::op_annot::gen` **does not move**
— so by invariant **I5** the change is stored, correct in Tcl, and **invisible
on screen**. Naming the type explicitly works.

The cause is one line in `apply`:

```tcl
set cands [array names classmap]        ;# <-- the shipped default map only
```

Every shipped-but-unmapped token inherits the gap. Measured present in this
tree and **absent from §4.3's map**: sky130 `varactor`, `npn`, `pnp`,
`pwell_resistor`, `p_diffusion_resistor`, `n_diffusion_resistor`,
`high_precision_p`; IHP `pnp`, `inductor`, `esd`; and `xschem_library`'s
arbitrary part numbers (`2N3906`, `4001`, `12SK7`).

## Why the suite did not see it

`test_op_param_store_1245.tcl` row **A1** exercises `apply` on `mos` only — a
class the shipped map names. Row **M2** proves the identity fallback for
unmapped tokens, but never applies one. The two halves are each green and the
seam between them is where the defect lives.

## Recommended fix

Make `apply`'s candidate set the **types the user owns a list for**, unioned
with the map, instead of the map alone. The store already knows them: every
`owned` key of scope `class` is a class name, and a class that is its own type
is exactly the identity case.

```tcl
set cands [array names classmap]
foreach k [array names owned] {
  if {[lindex $k 0] eq "class" && [lindex $k 2] eq "annotation"} {
    lappend cands [lindex $k 1]
  }
}
```

**Rejected: enumerating `::op_annot::desc`.** `src/op_param_lists.tcl` reaches
into no other namespace's internals on purpose, and there is no published
enumerator to reach for — that missing accessor is issue **1274**.

**Rejected: extending the shipped default map with the measured census.** A map
entry is a *claim* that two tokens share one list; `varactor` → capacitor and
`esd` → diode are groupings no ruling covers, and inventing them is the shape
ruling **D-4** forbids one level up. Item B2 rejected this deliberately and it
stays rejected — the fix is to stop `apply` gating on the map, not to grow the
map.

## Acceptance row this needs

* A2 — a type the map does not name, with an owned class list: bare `apply`
  re-registers it and `::op_annot::gen` **moves**.

## Who inherits this

**Item B5**, which calls `apply` after a Save. Until this is fixed, a user who
customises a device whose `type=` token nobody anticipated sees the list
accepted, the file written, and the schematic unchanged — the exact silent
failure invariant I5 exists to prevent.

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


`src/op_param_lists.tcl`. New `_apply_cands`: the shipped class map **unioned
with every class the user owns a list for**, built by walking
`[array names owned]` for scope `class`.

```tcl
proc _apply_cands {} {
  variable classmap ; variable owned
  set c [array names classmap]
  foreach k [array names owned] {
    if {[lindex $k 0] ne "class"} { continue }
    lappend c [lindex $k 1]
  }
  return $c
}
```

⚠ **This is written against grammar v2's key and it is correct because of it.**
The risk this issue collided with was real: had 1277's fix put the class into
the key as a *fourth element*, `lindex $k 2` would have stopped being the
listname and this scan would have selected nothing — a green suite and a dead
fix. 1277 landed first and kept the key at three elements (the flavor key's
middle field became `{class glob}`), so the shape above is right as written.

**And the gate widened with it.** Under ruling **DD-4** the summary list is half
of what `params` carries, so a class the user customised only through its
**summary** was unreachable for the same reason: the gate is now *owns
**either** list*. The counterweight is untouched — a class the user owns nothing
for is still left strictly alone, because applying the seed back over the PDK's
own descriptor would be a no-op that still bumped the generation counter and
still rewrote a dict this file does not own.

**Not done: growing the class map.** A map entry is a CLAIM that two tokens
share one list, and `varactor -> capacitor` or `esd -> diode` are groupings no
ruling covers — inventing them is the shape D-4 forbids one level up, and row
M1 is the fence that keeps the shipped map at exactly §4.3's five groups. The
classes the *user* owns a list for are data the user supplied, so adding them
invents nothing. `::op_annot::desc` is still never enumerated (no accessor —
that is issue 1274).

## Red before green

| row | red on | green after |
|---|---|---|
| `A2` an unmapped `type=` token | `apply` → `{}`, `::op_annot::gen` did not move, so by **I5** the stored, correct list was invisible on screen | reached by bare `apply`, `gen` moves, the descriptor's `match` survives |
| `A2b` summary-only class | unreachable too | reached; and a class owned in **neither** list is still left alone |

Sabotage, with the fix in place: `SB-APPLY-MAPONLY` (`_apply_cands` →
`[array names classmap]`) → **A2, A2b red**, `RESULT: 2 FAILED (54 passed)`.

## One golden this moved, and why

Row `A2`'s `params` golden was `{{zz zz 1}}` and is now
`{{zz zz 1} {a a 0}}` — the **union**, exactly as A1, A2b, A3 and A4 are.
`widgetron` is registered with `{{a a 0}}` and the row owns only an annotation
list, so `effective widgetron summary` answers the PDK seed. A golden of
`{{zz zz 1}}` alone would have been this suite asserting that the deck **loses**
the `a` card, which is issue **1280** itself one row over from A3, the row that
exists to forbid it.

## Why this was reverted

**This issue's own fix was not refuted, and nothing below was measured wrong.**
It was reverted as **collateral**. Item B2a was implemented as one 2,506-line
diff across four files; the adversary pass refuted the batch's central claim on
three *other* issues — **1277**, **1281** and **1284** — and the write-up agent
reproduced all three independently before deciding. Splitting a diff that size
into a "sound" half and an "unsound" half at write-up time would have committed
a code change that no Measure, Verify-A, Verify-B or Verify-C pass had ever
seen, which is precisely the failure mode this batch has already paid for in
items B1, B2 and B3.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` applies clean to
`825cd3bd`. The next crew's job is **apply → fix the three named holes →
re-verify**, and this issue's portion should survive that pass unchanged.

---

## Item B2a-2 — REVERTED A SECOND TIME, 2026-09-03, AGAIN AS COLLATERAL

**This issue's own fix was still not refuted.** Item **B2a-2** re-applied
B2a's patch unchanged, re-fixed the three holes, added ruling **DD-6**'s display
key, and went green everywhere — store **39→71**, RDW window **32→49** headless
and **42→59** on `:99`, `test_op_annot` **485/492** and
`test_annot_declutter_1244` **134** all unmoved, audit back at the 367/12/0/2
baseline with an empty non-PASS diff.

**It was reverted anyway**, because the adversary refuted the central claim on
**1277**, **1281** and **1285** and the write-up agent reproduced **four**
attacks first-hand. Same reasoning as the first revert: the diff was one
2,838-line change across eight files, and splitting it at write-up time would
commit code no verification pass had ever seen.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch` (md5
`1977a39e5d419d31fcbbbc3932c2606f`, 3,573 lines, eight files) **applies clean to
`849f2231`** — verified with `git apply --check` in both directions. It contains
**both** attempts: B2a's six sound fixes *and* B2a-2's re-fixes. This issue's
portion should survive the third pass unchanged; apply the patch and fix only
what §"Still open after B2a-2" in **1277**, **1281** and **1285** names.
