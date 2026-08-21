# 0499 — three guardians in the S3 acceptance cannot fail, or are absent

STATUS: **OPEN.** Measured on branch `annotate`, step S3d, 2026-08-21, at
`d56283ec`. This is the test-side record of why attempt 4 was green at 275
checks while two of its claims were false in the field. See 0494.
Related: 0494, 0495, 0496, 0442 (attempt 2's ignored tell), spec landmine 11.

---

Spec landmine 11 says a sabotage variant whose predicted red does not appear is a
**fixture defect to fix before landing, not a footnote**. Attempt 4 produced
three such tells and footnoted all three. Each corresponds to a guardian that
cannot fail.

## (a) W19 is vacuous — it cannot catch the I4 violation it exists to catch

Row **W19** asserts `xschem get modified == 0` after a walk. Its fixture is a
synthetic `.sch` the test itself wrote at file_version 1.2. On a shipped bench at
3.4.8RC/1.3, the same assertion **fails** (issue 0495):

```
I4-REPRO bandgap_opamp : modified BEFORE=0 AFTER=1
```

A guardian for an invariant must run on the artefact class the invariant is
claimed over. Fix: W19 must run on at least one **shipped** schematic, not only
on a fixture the suite authored.

## (b) Section X cannot discriminate a basis — the attempt-1 defect is uncovered end to end

`basis_ignored` and `devproc_gets_read_path` were predicted to redden X2/X3 and
did not. This is **structural, not a fixture bug**: section X clears the raw,
loads the top cell, and calls `save_cards` at currsch 0 — where the `read` and
`deck` bases produce the same empty prefix. Section X *cannot* tell them apart.

Consequence: **the exact defect that killed attempt 1** (raw-relative names where
deck-absolute were required) is verified only by string goldens W5–W8, and is
never closed against a raw the feature itself caused to exist.

Fix: after the first ngspice pass, descend one level with that raw loaded and
re-run `save_cards`, asserting the block is unchanged. That closes the loop the
whole X section was added for.

## (c) `descendable_aliases_netlisted` reddens 2 rows of a predicted 4

W12, W13 and W15 stayed green under the alias that **is attempt 2's shipped
defect**. Mechanism, measured: the walk *does* descend into the dropped subtree
(`_miss_dev` moves 4 → 13), but the fixture gives each drop-class symbol a
private byte-copy `.sch` whose key is absent from the deck index, so no card can
be emitted regardless. The rows assert *"no card"* and never *"no descend"* —
true for a reason they do not test.

**Residual risk this leaves uncovered**, and it is the raw-destroying direction:
if a dropped subtree's `.sch` is **also** netlisted elsewhere in the design — one
cell reached through both a normal and an ignored instance, ordinary in real
hierarchies — a leaked descend finds a non-empty block and emits orphan cards
under a hierarchy prefix the deck does not contain. The adversary tried to build
that case with `schematic=w_ok` and could not isolate it (the polymorphic path
drops `default_schematic=ignore`), so it is **argued, not measured**.

Fix: assert the *descend*, not only the card — e.g. a counter of levels entered —
and give at least one drop-class symbol a `.sch` that is shared with a normally
netlisted instance.

## (d) A fourth, absent rather than vacuous

`descended_always_true` reddens **W27 only**, a unit probe of `_descended` in
isolation. No row runs a walk that *contains* a class-1 descend refusal, so
issue 0433's real consequence — a level popped that was never pushed, hence
re-visited levels and duplicate cards — has no end-to-end guardian.

## Still open

* All four fixes are cheap. None was taken, because they were discovered after
  the acceptance had been declared green.
* The general lesson, and the reason this file exists rather than four review
  comments: **a check count is not evidence.** Four attempts at this step have
  now been certified green — 85, 96, (never run), and 275 checks — and three of
  the four were false in the field. The predicted-red matrix is the instrument
  that caught it every time, and it was footnoted every time.
