# 1203 - two different setting lists spell one cell name because the join is ambiguous

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6a. Verified by row AS52 (behavioural) and row AS53 (structural).
**Filed by:** item S6, write-up pass, 2026-08-31
**Caused by:** [[1201]].

## What the user sees

Two copies of a cell, each with a different set of settings typed on it, share
one version of the cell - and one of them loses BOTH its settings out of the
deck. Nothing is said about it. The pre-[[1201]] tool at least complained.

## Measured, verbatim

Two copies of a cell whose own drawing takes both devices from settings:

```
{name=xD W_P=0.5 modeln=nfetA__modelp_pfetB}
{name=xE W_P=0.5 modeln=nfetA modelp=pfetB}
```

Deck:

```
xD net4 advpass__modeln_nfetA__modelp_pfetB
xE net5 advpass__modeln_nfetA__modelp_pfetB
.subckt advpass__modeln_nfetA__modelp_pfetB ...
  XM2 ... sky130_fd_pr__pfet_01v8          <- xE asked for pfetB
  XM3 ... sky130_fd_pr__nfetA__modelp_pfetB <- xE asked for nfetA
```

Both of `xE`'s settings are gone. `xE` gets no note and no warning.

## Cause

The canonical spelling of a setting SET is built in
`lost_attrs_the_cell_body_reads()` (`src/token.c`) as `<name>_<value>` pairs
joined by `__`. That encoding is ambiguous: a value containing `__<name>_`
produces the same string as two separate settings. `auto_spec_by_set` is keyed
on it (`src/actions.c`), so the two copies do not merely collide on a NAME -
they collide on the KEY, which is what makes them share a body.

GUARD AS-COLLIDE's `auto_spec_taken` probe cannot see this. That probe catches
two DIFFERENT keys whose names fold to one spelling. Here the keys are equal.

## Reachability

Narrow but not theoretical - it needs a typed value containing `__` followed by
another read setting's name and an underscore. sky130 model names carry `__`
routinely (`sky130_fd_pr__pfet_01v8_lvt`), so the shape is one letter away from
ordinary.

## What would fix it

Make the join unambiguous - length-prefix each pair, or escape `_` inside a
value before joining, or key the table on the property string rather than on the
display spelling. Only the KEY needs to change; the readable NAME can stay as it
is, since GUARD AS-COLLIDE already disambiguates names that fold together.

## Why it was not fixed here

No `make` in the write-up pass.

## Rows

`AS9` was written for this requirement (two copies with DIFFERENT values must
get two bodies) and does not cover it, because its two values differ in an
unambiguous place. A row needs the pair above.

---

## Fixed, 2026-08-31, item S6a

**Two spellings, two jobs.** `lost_attrs_the_cell_body_reads()` (`src/token.c`)
now hands back a **third** string beside `canon` and `settings`: a **key**, and
that is what `auto_spec_name()` keys the shared-body table on (**GUARD AS-KEY**).

The key is **length-prefixed** - each field written as `<length>:<text>` - so no
value, whatever it contains, can make two different sets spell one key. The
readable cell name is still built from `canon` and is still allowed to be
ambiguous, because two readable names that collide are separated one step later
by GUARD AS-COLLIDE's numeric suffix. That keeps every cell name in every deck
anyone has already netlisted exactly as it was.

**Rejected alternative:** make `canon` itself unambiguous with a separator no
value can hold. It renames every multi-setting cell in every existing deck, to
fix a case that needs a value containing a double underscore.

Measured after: `xD` (`modeln=nfetA__modelp_pfetB`) and `xE` (`modeln=nfetA
modelp=pfetB`) get two bodies, and each body holds the devices its own copy
asked for.

**Readability residue, not ratified.** When two different sets still spell one
readable name, the second cell is `..._1`:
`asp2__modeln_nfetA__modelp_pfetB` and `asp2__modeln_nfetA__modelp_pfetB_1`.
Both are correct and distinct, and each copy's own note says in words which
settings it carries, but the two are hard to tell apart in a simulator log. On
the owed ledger as a `rule` debt.
