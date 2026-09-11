# 1407 — ASE-L asked the same question of one dict twenty-eight different ways

**Status:** fixed
**Branch:** fluid-editing
**Filed:** 2026-09-11
**Stage:** commit **C1** of Stage 2 of `doc/claude/ase_analyses_batch/` (plan item **2f**)

## The defect

`ase::sim_capabilities` answers a dict whose standing contract is that **a missing key means
"not measured", never "no"**. Six procs read that dict, and every one of them spelled the
contract by hand:

```tcl
[dict exists $caps k] && [dict get $caps k] == 1
![dict exists $c known] || [dict get $c known] == 0
[dict exists $caps altshow_op_dump] && [dict get $caps altshow_op_dump] == 1
```

**Measured: twenty-eight such reads across `ase::casemode_detected_in`,
`ase::casemode_selectable_in`, `ase::casemode_report`, `ase::cap_report`, `ase::op_save_tier` and
`ase::sim_capabilities_at`.** Every copy is a chance to fuse *nobody asked* with *the answer is
no* — and that fusion is not cosmetic. It is what turns a probe nobody ran into a statement about
the user's simulator: issue **0953** is exactly that, a program that had not finished being told
it is not a circuit simulator.

## What ships

**Three states, as data, in one place:**

```
{measured 0}               nobody asked, or the whole answer is `known 0`
{measured 0 why <token>}   nobody asked, AND the probe recorded which leg failed
{measured 1 value <v>}     somebody asked, and this is the answer — 0 included
```

⚠ **`value` is ABSENT rather than empty when nothing was measured.** A caller who reads it
without reading `measured` first gets a **raise**, which shows up in a test row, instead of a
fabricated `0` that shows up in a user's Outputs pane six months later. Row **P3** pins it.

**Two predicates with ONE shared body**, so they cannot drift — `ase::caps_is` delegates to
`ase::caps_measured_as`. Separate *names* because the direction is the whole point: one is a
permission, the other exists so a **negative** gate has a **positive** spelling.

**Four bands** (`ase::caps_keys`): identity (display and log only, **never compared** — stock 47
and the fork both answer `ngspice-46+`, so any ordering operator on a version string is wrong
today), capability, defect (**ships empty** — its keys arrive with leg D and a band key with no
reader is a key no row can pin), provenance.

**`unmeasured_keys`, wired to the two legs that can actually be cut.** ⚠ Decks A and B each
`return [dict create known 0 unmeasured timeout ...]` from a **fresh** dict on a cut, so a key
whose leg rides deck A can *never* be an `unmeasured_keys` customer. Only the **altshow** and
**casemode** legs qualify, and only those two are wired — wiring `analyses_available` "because the
plan says so" would ship a key no code writes and no row can redden.

## Three rules that are not obvious, each with the measurement behind it

**1. The predicate follows the DIRECTION OF THE GATE, not the band.** `ase::cap_report` reads two
*capability-band* keys in the **negative** direction (`usable == 0` fires "not a simulator",
`appendwrite == 0` fires "cannot append"). Both take `caps_measured_as`. Spelling either
`![ase::caps_is …]` makes it **true for a binary nobody measured** — issue 0953, re-filed, in the
proc it was filed against.

**2. The comparison is STRING equality, and that is a behaviour change.** The guards replaced were
numeric `== 1` / `== 0`. Measured: `appendwrite '0.0'` was a match and is not one now, and an
`altshow_op_dump` of `'1.0'` moves `ase::op_save_tier` from tier `d` to tier `c`. Latent for the
shipped adapter — all four values are `expr`-produced literal 0/1 — and **not** latent for the
second adapter this schema exists for. **An adapter must publish canonical `0` or `1`**; row
**P13** is where that is written down as a fact rather than a hope.

**3. `ase::sim_capabilities_at`'s `known` test does NOT convert, and the exemption is written
down.** It is the **producer's cache-write gate**. Routing the writer through the readers'
predicate would make the rule that decides what is *remembered* depend on the rule for reading
what was remembered. It is the one hand-written capability read left in the tree, on purpose.

## The row that only exists because a sabotage went green

Section **P** was written with fourteen rows. The sabotage pass respelled `ase::cap_report`'s
refusal as `![ase::caps_is $c usable 1]` — the exact defect this whole issue is about — and
**all fourteen passed**. P7 proves the two predicates *differ*; nothing proved the callers had
picked the right one.

**P15** is that row: structurally, neither predicate is ever read through a `!`, anywhere in the
corpus. ⚠ **The rule is deliberately over-broad, and the reason is that the call site cannot show
you which case it is.** `![caps_is $c k 1]` is honest for *"may I OFFER this?"* — you may not
offer what nobody measured — and a defect for *"may I ACCUSE this program?"*, where unmeasured
must stay silent. The two read identically. Zero uses exist today, so the ban costs nothing now
and forces the next author to say which question they are asking.

## Verification

`test_ase_simcaps_0948` **111 → 126**. Every row drives **literal dicts** — no simulator, no
fixture ordering, no stub — so a red row is about the vocabulary and can be about nothing else.

**Eight sabotage passes**, each reddening named rows and nothing else:

| # | sabotage | reddens |
|---|---|---|
| 1 | `value` present-but-empty instead of absent | P2 |
| 2 | unmeasured reads as a yes (**the fusion**) | P6, P7 |
| 3 | `![caps_is …]` in place of `caps_measured_as` | **P15** (passed all 14 before it existed) |
| 4 | the writer **overwrites** instead of merging | P11 — and only because P11 is **chained** |
| 5 | convert the producer's cache-write gate | P8 |
| 6 | point a boolean predicate at the **list**-valued key | P14 |
| 7 | numeric `==` instead of string `eq` | P13 |
| 8 | leave one hand read behind in a converted reader | P8 |

⚠ **P11 is chained on purpose.** Against a dict with no prior `unmeasured_keys`, the correct body
and a body that *overwrites* produce a byte-identical answer — a single-call row **cannot** redden
its own sabotage. The chain is what a real probe does (two legs cut in one run) and is the only
shape that tells the two bodies apart.

⚠ **P8's expectation is 2, and measuring it mattered.** The exemption is one guard on one *line*
but two *reads* (`dict exists` + `dict get`), and `p_scan` counts reads. The first expectation
written was `1`, taken from a count of lines. **The code was right and the expectation was wrong** —
the same shape as RG13 in issue 1404.

`test_ase_optier_0963` unmoved at **103**, with **T11/T12 green** — those scan `op_save_tier`'s body
for the literal `$caps <key>`, which the predicate signatures preserve exactly, and T11 asserts the
`known` read still precedes every capability read.

## Related

* **0953** — an unmeasured program called "not a simulator". The defect this vocabulary makes
  unspellable, and the one sabotage 3 re-created.
* **1406**, **1405** — the two Stage 1 debts found by the same recon pass.
* **0950** — `ase::sim_caps_clear` on every registry edit.
