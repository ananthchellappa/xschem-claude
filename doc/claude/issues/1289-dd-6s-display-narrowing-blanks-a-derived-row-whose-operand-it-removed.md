# 1289 — DD-6's display narrowing blanks a `derived` row whose operand it removed

**Filed by:** item **B2a-2**, 2026-09-03. Found by the Implement agent while
building DD-6, confirmed on a live fixture by B2a-2's adversary. **FILED, NOT
FIXED — it needs a ruling, not a guess.**

**Status: FIXED by item B2b, 2026-09-03, under ruling DD-9 — and TWO OF THIS
ISSUE'S OWN SENTENCES (§2's first line and §4's second bullet) ARE FALSE ON THIS
TREE; see §Fixed at the end.** Was: open, a property of ruling DD-6 itself
rather than of any one implementation, which is why it survived B2a-2's revert.

---

## 1. The seam

`op_annot::text` builds its `vars` dict **inside the params loop**. Ruling
**DD-6** makes that loop iterate the new display key (`shown`) instead of
`params`. So a `derived` row — whose expression is evaluated over `vars` — can
name an operand that the display list no longer contains, and the variable is
simply **not there**.

Measured by the Implement agent on this binary:

```
op_annot::_evalrow {$gm/$id} with vars={id 1e-5}  -> "" , _finite 0   (renders BLANK)
op_annot::_evalrow {$gm/$id} with both present    -> 20.0
```

Confirmed by the adversary on a live one-instance fixture:

```
params  {{id ids 0} {gm gm 1}}   shown {{id ids 0}}   derived {{gm_id {$gm/$id}}}
-> the sheet draws `id` and `gm_id`, and `gm_id` can never carry a value
```

while the deck **still saves `gm`**, because `_cards_for` correctly stays on
`params`.

## 2. Why it matters and who hits it

**IHP registers exactly such rows** (`gm/id`, `ft`) in
`ihp-sg13g2/sg13g2_procs.tcl`. ⚠ **THIS SENTENCE IS FALSE — MEASURED; see
§Fixed.** IHP ships those two rows only inside its *recovery-recipe comment*.
The failure below is real and was reproduced; only its shipped-fixture claim is
wrong. So the first user to delete `gm` from the
annotation list in item **B5**'s dialog gets a `gm_id` row that is permanently
blank — on a run where `gm` was saved and *is* in the raw.

The behaviour is **honest** under invariant **I3** (blank, never a plausible
wrong number, never a raise), which is why it is filed rather than treated as an
emergency. But it is a real user-visible seam: *deleting one row silently
disables another*, with nothing on screen saying so.

## 3. The three options, none of them ratified

1. **Leave it.** A derived row whose operand is hidden goes blank. Honest,
   surprising, and invisible.
2. **Evaluate `vars` over `params` (the union) and *display* over `shown`.**
   The derived row keeps working when its operand is merely hidden. Costs one
   extra loop at draw time, in a proc that runs **per instance per redraw** from
   C (`src/actions.c:2088`).
3. **Narrow `derived` too**: a derived row whose operands are not all shown is
   itself not drawn. Nothing blank, nothing surprising, but Delete on `gm` now
   silently removes `gm_id` from the sheet as well.

**Recommendation: option 2.** `derived` is a *display* concept already — it
appears in no `.save` card — so its operands are naturally read from what the
run computed rather than from what the sheet draws, and it is the only option
under which the sheet never shows a row that cannot carry a value. Option 3 is
defensible and needs the user's word, because it makes one Delete remove two
rows.

**This is a `rule` debt on the user's queue.**

## 4. Acceptance for whoever takes it

* A `derived` row whose operand is in `params` but not in `shown` behaves as the
  ruling says, with a row that names the ruling.
* ~~IHP's `gm/id` and `ft` rows are the fixture — they are the shipped case.~~
  ⚠ **FALSE, see §Fixed.** Both rows are still the fixture, but they are
  **built** from IHP's documented recovery recipe under invariant **I5**, not
  read off a shipped descriptor.
* Whatever is chosen, `op_annot::text` gains **no** new `xschem` call and **no**
  new raise site at draw time (issue **0447**).


---

## Fixed — item B2b, 2026-09-03, under ruling DD-9 (pure Tcl, no build)

**What shipped.** `op_annot::text` builds its `vars` dict over **`params`** —
what the run computed — and draws its rows over the narrowed **`shown`** key, so
a `derived` row keeps its value when its operand is merely hidden. In the code
that is one line: the `lappend vars $lbl $val` inside the `params` loop is
**unconditional on the display decision**.

**The binding constraint was met structurally, not by inspection.** The `params`
loop stays exactly where it was and stays the **only** place that reads the raw;
the narrowed rows are minted from that same pass's label→value cache. So
`op_annot::text` gains **no new `xschem` call** and **no new raise site** — row
**D9** of `tests/headless/test_op_param_store_1245.tcl` counts both in the
comment-stripped body (1 and 0, unchanged) and covers the new helper too. Two
alternatives were measured and rejected: **swapping the list the loop walks**
(B2a-2's shape — it blanks the derived rows, i.e. reproduces this very issue)
and a **second read loop** over the display rows (a new `xschem` call per row per
instance per redraw, which §4's third bullet forbids).

**Rejected and not to be revisited**, per DD-9: narrowing `derived` too, which
makes one Delete silently remove two rows from the sheet.

> ⚠ **§2's "IHP registers exactly such rows" AND §4's "they are the shipped
> case" ARE BOTH FALSE ON THIS TREE.** MEASURED: all four shipped register sites
> — `sky130A/sky130_procs.tcl:422`, `gf180mcuD/gf180_procs.tcl:128`,
> `ihp-sg13g2/sg13g2_procs.tcl:779` and `:829` (line numbers after B2b's own
> comment block, which moved each down by 15) — carry `devpath`/`devproc` +
> `match` + `params` **and nothing else**. Every `derived` in the three PDK files
> sits inside the **recovery-recipe comment** (`sg13g2:747-749`, `sky130:394`,
> `gf180:100`), because ruling **D9** removed them, and `test_op_annot`'s own
> gold table `P_DERIVEDACC` (`:904-911`) golds `derived` = `{}` for all seven
> shipped types. The same false sentence had propagated into
> `doc/claude/specs/op_param_lists.md` §5 and into item B2b's brief; all three
> are corrected. **The substance of this issue is untouched** — it was
> reproduced at HEAD directly, where today's `apply` already blanks `gm/id` by
> removing `gm` from the only list there is. The fixture is simply **built**
> from IHP's documented recovery recipe under **I5**, which is what that recipe
> is for, and **both** named rows are exercised.

**Where the evidence is.** Row **D4** of
`tests/headless/test_op_param_store_1245.tcl`: after an `apply` that narrows the
sheet to `id` alone, `gm/id` = 10 and `ft` = 1.592G while neither `gm` nor `cgg`
is drawn. RED at HEAD (both blank). The sabotage `vars_follow_the_sheet` — the
params loop iterating the narrowed list — reds D4 against the landed code.
