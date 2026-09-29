# 1618 — `getprop` can write a line property from Tcl but never read it back

**STAMP:** `v1 claim=fixed tree=06423abe stamped=2026-09-29 fix=taken open=3`

Status: **FIXED**, 2026-09-29, in `xschem_cmds_g()` plus a new static helper
`getprop_gfx_prop()`. Measured on this tree at `06423abe` · Branch: `fluid-editing`
Related: `doc/claude/specs/wish_list.txt` **old-list item 21** (*"Provide a way, through
TCL, to access properties of any object"*), which this closes, and **old-list item 26**
(`o=car(geGetSelSet())` / `o~>prop`), which it unblocks but does not implement;
`doc/claude/specs/property_introspection.md`; batch
`doc/claude/selectall_getprop_batch/` decisions **D3**–**D6**; the fence is the `GP*` band
of `tests/headless/test_getprop_index_bounds.tcl`.

## The defect is an ASYMMETRY, not a hole

`xschem setprop` has had `line`, `poly` and `arc` arms since audit 0063 atom 10.
`xschem getprop` never did. So Tcl could **write** a property onto a line and had no way to
read it back. Measured on the shipped binary:

```
setprop line 4 0 zz 9      -> rc=0 result=||     the write is accepted
L 4 0 0 100 0 {myline=Lvalue dash=4
zz=9}                                            and it reaches the file
getprop line 4 0 zz        -> rc=0 result=||     the read comes back empty
```

That round trip is the whole issue in three lines, and it is what the fence asserts. It
needs no fixture file on disk.

## ⚠ THE FAILURE MODE IS A SILENT SUCCESS, WHICH IS WHY A NAIVE FENCE WOULD HAVE BEEN GREEN

The `else if` chain in `xschem_cmds_g()`'s `getprop` branch has **no terminating `else`**, so
an unknown `argv[2]` falls through every arm and returns `TCL_OK` with an empty result.
Driver-verified at `4f998799`:

```
getprop line 4 0 fmt -> rc=0 result=||
getprop poly 4 0 fmt -> rc=0 result=||
getprop arc  4 0 fmt -> rc=0 result=||
getprop zzz  4 0 fmt -> rc=0 result=||
```

A row written as *"this errors today and must succeed tomorrow"* therefore **passes on the
broken tree** — `catch` returns 0 before and after. Every row in this fence asserts the
returned **value**. Recorded as batch decision **D3**; it is the same defect class as the
symptom-keyed fence CLAUDE.md warns about, reached from the other side.

## What shipped

* **New combined `line`/`poly`/`arc` arm** in `xschem_cmds_g()`, via a new static helper
  `getprop_gfx_prop()`. Grammar `getprop <type> <layer> <index> <token> [with_quotes]`,
  `with_quotes` defaulting to 0 — the spelling `setprop`'s own three arms and `getprop`'s
  shipped `rect` arm already agree on, so **no new grammar was invented** (D4).
* **The token-omitted whole-string form**: `getprop <type> <layer> <index>` returns the
  object's whole `prop_ptr`. This is what actually delivers item 21, because it is what lets
  `xschem list_tokens` enumerate an object's properties — which previously worked for
  `instance` and nothing else.
* Extended to **`rect`, `text` and `wire`** as well, under the proof obligation below (D5).
* The arm-list error string now names all nine types instead of six.
* The C doc block rewritten — including `text`'s **previously undocumented `size`
  pseudo-token**, which existed only as an inline comment.

`doc/xschem_man/developer_info.html` carries that doc block **verbatim** in the shipped help,
and its generator `extract_scheduler_cmd_help.awk` **no longer exists in the tree**, so the
HTML was hand-edited to match. ⚠ The pre-existing twin gap is left alone and named: `setprop`'s
line/arc/poly arms are still undocumented there, which is audit 0063's own debt.

C89 verified mechanically: `-std=c89 -pedantic -Wall -Wdeclaration-after-statement` gives
**zero** diagnostics on any touched line (all 32 in the file are pre-existing). No allocations
added, so no `_ALLOC_ID_`.

## ⚠ The widening was conditional on a census, and the census was validated first

Making `getprop rect 4 0` stop erroring is a **widening** — a previously-invalid call becomes
valid — so nothing that worked before changes meaning, and only a caller deliberately relying
on the error could notice. Batch decision **D5** therefore made it conditional on proof, with
an explicit fallback to the three new arms alone if the proof failed.

**Discharged.** A three-layer instrument — literal `getprop`; **non-literal `argv[1]` to the
`xschem` command**, a closed syntactic set in Tcl, plus the C eval entry points;
punctuation-split spellings — **validated first against four deliberately evasive controls**,
of which the concatenation-built one is caught by layer 2 only, i.e. exactly what a literal
grep misses. Over `src`, `xschem_library`, `tools`, `utils` and `tests`: 1104 lines, 171 files,
1194 `xschem getprop` occurrences. **12 token-omitted candidates, all 12 inspected, all 12
false positives** (6 comments, 6 extractor truncations at `(`, `[` or `"`). Of 51
dynamic-dispatch sites, three could reach `getprop`; all three were cleared by inspection.

One further closure that makes the census's residual risk smaller than its own confidence: the
widening keys on **`argc`**, not on the token's content, so a caller passing an empty token
*variable* still takes the token path byte-identically.

This is CLAUDE.md's "a census is only as good as its agreement with a known-good control" rule,
applied before the number was quoted rather than after it was doubted.

## The red, and why it was taken in an isolated tree

* pristine `HEAD:src/scheduler.c` + the shipped fence → **`RESULT: 63 FAILED (40 passed)`**
* same tree, only `scheduler.c` replaced → **`RESULT: ALL PASS (103 checks)`**

Suite 8 → **103 checks**. `run_regression.tcl` is untouched: the suite was already `hcases`-only
and its new band prints zero `skip:` lines, so the T1 figures do not move.

⚠ Taken in an **isolated `git archive HEAD` tree**, configured and built from scratch, because a
second crew had `src/callback.c`, `src/draw.c` and `src/xschem.h` modified in the shared tree —
any `make` there would have built that in-flight work into the binary under measurement. That
sharing was the driver's orchestration error, recorded as batch decision **D12**.

## Sabotage: eight variants, and two of them changed the fence

`S1` no bounds check → **`FATAL: signal 11`**. `S4` rect's whole-string branch placed above the
issue-0077 guard → **`FATAL: signal 11`**, after reddening one row first. `S3` arity floor left
at 6 → 7 rows. `S5` poly/arc reading the line array → 6 rows. `S6` returning the cached `dash`
instead of the token → 12 rows. `S7` `with_quotes` hardcoded to 2 → 3 rows. `S9` count mix-up →
3 rows.

**The payoff of doing them:** `S5` would have **survived** the first draft of the fence, because
all three types had been given identical properties; and `S9` would have survived too, because
every out-of-bounds row used `999999`, which defeats a wrong-count check. Both were fixed — per-type
distinct values plus explicit *"the token read comes from the `<type>` array"* rows, and five
*"an index equal to the live count raises, not just 999999"* rows.

⚠ **`S2` survived and is reported as a NON-DEFECT rather than a gap.** Removing all four NULL
guards left the suite at ALL PASS with no crash, because `Tcl_SetResult(interp, NULL, TCL_VOLATILE)`
tolerates NULL and answers `{}` — which is exactly why the shipped `instance`/`symbol` arms pass
`prop_ptr` raw. The guards were kept, and the **test comment was corrected**: it had claimed those
rows were crash fences, which they are not.

## Still open (open=3)

1. **`getprop <unknown-type>` still returns a silent empty success.** It is a real defect — it is
   what makes a missing arm indistinguishable from a typo — but flipping it to an error changes
   existing behaviour with an unaudited caller set, and the batch plan forbids doing that silently
   (decision **D6**). It is now *documented* in the C doc block; it still needs its own issue.
2. **`doc/claude/specs/property_introspection.md` is stale and was not repaired here.** It still
   says `Status: PROPOSED … No code yet`, **every line number in it is off by roughly 3200** (it
   cites `scheduler.c:2686` where the real value is 5923), it omits `text`'s pseudo-tokens and the
   silent-empty failure mode, and it never mentions that `setprop` already had the three arms.
3. **Wish-list item 26 is unblocked but not implemented.** The whole-string form is the read half
   that item 26's `o~>prop` access model needed; the handle syntax itself is not in this issue.
   Also deliberately out of scope: an `allprops` synonym for `getprop`, geometry pseudo-tokens, and
   any change to `setprop`.

⚠ One incidental measurement worth keeping: `test_op_annot` reports **486** checks, not the 485
CLAUDE.md quotes. Not changed by this issue — the file's figure was already stale.
