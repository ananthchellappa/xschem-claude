# 1639 — `calc::riseTime` with `nth` 0 RAISES, where both its siblings defer behind a shared sentence

**STAMP:** `v1 claim=fixed tree=580f7968 stamped=2026-10-03 fix=taken open=0`

Status: **FIXED** 2026-10-03, option **1** below taken — `calc::riseTime` defers behind the shared
`listdefer` sentence. Found 2026-10-02 by a calculator batch crew auditing the function catalogue.
Was a **live raise in shipped Tcl**, reachable from the proc's public argument list, fenced by
nothing. The resolution is at the end of this file; everything between here and it is the dated
record of the open claim and is NOT edited.

Area: `calc::riseTime` — `src/calculator.tcl`. Its two siblings `calc::delay` and
`calc::dutyCycle_scalar` guard the same input; `calc::cross`'s `nth` 0 contract and the shared
refusal sentence are `calc::cross` and `calc::cross_msg` in the same file. The suite that covers
the siblings and not this path is `tests/headless/test_calc_measure.tcl`.
Found: `env -u DISPLAY ./src/xschem --pipe -q --nogui --script …` against
`tests/headless/data/calc_fixture.raw`

## Measured

```
=== riseTime with nth 0, at a swing the trace DOES reach ===
calc::riseTime {v(sq)} 0.0 1.0 10 90 0 0
catch=1
msg=<can't use non-numeric string as operand of "-">

=== control: the same call with nth 1 ===
catch=0  result=<ok 1 absent 0 value 0.0001600000000000014 dataset 0 dest __calc_tmp4 msg {}>

=== sibling: calc::delay with nthA 0 ===
catch=0  result=<ok 0 absent 0 value {} dataset 0 dest {} msg {Cross: nth 0 answers every
crossing and the buffer takes one number (R404), so a destination that can hold a wave has to
come first.}>

=== sibling: calc::dutyCycle_scalar with cycle 0 ===
catch=0  result=<same sentence, identically>
```

⚠ **The transcript above is a dated capture at the commit this issue is stamped at, and is NOT
edited — but the sentence in it has since been REWORDED.** R419 (2026-10-02) ruled that `cross`'s `nth = 0` answers a
plain list, which made the clause *"a destination that can hold a **wave**"* false for
`calc::cross_scalar`; the shared sentence now reads *"so a destination that can hold more than one
has to come first."* **Nothing about this issue changes**: the defect is the RAISE, the fix options
below are unaffected, and rows MT7/MT8 of `tests/headless/test_calc_measure.tcl` compare that
sentence by **identity** and never by its words — which is exactly why rewording it cost nothing and
splitting it per caller would redden both.

## The mechanism, and why the existing guard does not cover it

`calc::cross` with `nth` 0 answers **success with a list** — `ok 1 absent 0 value {<every crossing>}`
— which is declared behaviour, not a defect. `calc::riseTime` takes an `nth`, passes it straight
through to **both** of its delegated measurements, and then does arithmetic:

```tcl
set a [calc::cross $rpn $llo $nth rising $dataset]
if {![dict get $a ok]} { return $a }
set xlo [dict get $a value]
set b [calc::cross $rpn $lhi 0 rising $dataset]
if {![dict get $b ok]} { return $b }
set xhi {}
foreach x [dict get $b value] {
    if {$x > $xlo} { set xhi $x ; break }
}
if {$xhi eq {}} { return [calc::cross_absent …] }
dict set b value [expr {$xhi - $xlo}]
```

With `nth` 0 the **low** side's `value` is a list, so `$xlo` is a list. The proc's own comment above
the loop says:

> T5's guard at the point of use: `value` here is a LIST and may be EMPTY, because nth 0 at a level
> nothing reaches answers success with nothing in it. The loop below simply finds no candidate and
> the absence is reported, which is why **no arithmetic can meet an empty operand**.

That is true of **`$b`** and false of **`$xlo`**. `$b` is always read with a literal `0` so its list
is the high-side one, and the `$xhi eq {}` test does cover it. `$xlo` comes straight from the
caller's `nth`, and nothing tests it. The `$x > $xlo` comparison does not raise — with a multi-word
operand Tcl falls back to a string compare — so the loop *succeeds*, `$xhi` is set, and the
subtraction is reached with a list on the right: `can't use non-numeric string as operand of "-"`.

**The empty-list case does NOT raise**, which is why this survived: at a swing nothing reaches,
`calc::riseTime {v(sq)} 100.0 200.0 10 90 0 0` answers
`ok 0 absent 1 … msg {Rise time: the 0th low crossing has no high crossing after it in this sweep.}`.
So the path is reachable only when the measurement would otherwise have *worked*, and a reader
probing the degenerate cases first finds a clean absence and stops.

`calc::delay` has the same shape and guards it, and its comment names this exact raise as the reason:

> `cross` answers nth 0 with SUCCESS AND A LIST, so a verb that subtracted would reach
> `can't use non-numeric string as operand of "-"` — a raise where there should be an answer.

`calc::riseTime` was written in the same stage, takes an `nth` on the same contract, and did not get
the three-line guard.

## Fenced by nothing

`tests/headless/test_calc_measure.tcl` covers the two siblings' deferrals — band `MT7` for
`delay`'s, from either side, and `MT8` for `dutyCycle_scalar`'s — and has **no** row that passes
`nth` 0 to `riseTime`. Measured: of the 58 `riseTime` mentions in that suite, none supplies 0 as the
sixth positional argument. (Derived from the suite's own call sites rather than from a list in a
comment — the method `test_snprintf_fmt_1608` row `X1` exists to insist on.)

## Open items — two defensible shapes, and they are NOT interchangeable

1. **Defer, behind the shared `listdefer` sentence**, exactly as `calc::delay` and
   `calc::dutyCycle_scalar` do. ⚠ **This route is constrained by rows `MT7` and `MT8`, and the
   constraint is identity rather than wording**: both assert
   `[string equal [mt_msg $a] [pcall calc::cross_msg listdefer]]`. So a **third** caller may join
   the shared sentence freely — nothing in either row counts its users — but **splitting that
   sentence per caller reddens both rows**, because they compare against the one `listdefer` string
   and not against words. Anyone tempted to give `riseTime` its own phrasing needs that in front of
   them before they start.
2. **Refuse as a malformed request under D7.** `riseTime` is a scalar verb by construction: a rise
   time per low crossing is a wave, and `calc::cross_scalar` already exists as the place where the
   wave/scalar split is made. A D7 refusal says the request cannot be *interpreted* here, which is
   arguably more honest than a deferral promising a destination that will hold it.

The two differ in what they promise the user, so this is a product-behaviour choice and not an
implementation detail. **Whichever is taken, the row comes first** — the tree's standing rule is
red before green, and this is a raise with a one-line reproducer.

A third item, stated so it is not lost: whatever is decided, the proc's comment sentence *"no
arithmetic can meet an empty operand"* is wrong as written (it is a claim about one of two
operands) and should be corrected in the same change, or it will mislead the next reader exactly as
it misled this one into reading the path as guarded.

## What this is NOT

Not a defect in `calc::cross`. Its `nth` 0 behaviour — success with a list — is declared, pinned by
name in the sibling suite, and relied on by `frequency`, `period_jitter` and `dutyCycle`.

Not an arity error. `nth` is the sixth positional with a default of 1, so `0` is a well-formed
argument on the proc's published signature; the optional-with-empty-default shape of `lo`/`hi` is
there precisely so that a malformed request is a refusal rather than a Tcl throw, which is the
disposition this path breaks.

## Resolution — 2026-10-03, option 1 taken

`calc::riseTime` now **defers** behind the shared `listdefer` sentence, joining `calc::cross_scalar`,
`calc::delay` and `calc::dutyCycle_scalar`. No new `cross_msg` kind was minted, so no new
user-visible sentence was introduced.

**Why option 1 and not option 2.** The option-2 argument in this file — that a rise time "per low
crossing" is a malformed request — does not survive the proc's own published meaning of `nth`.
`nth` selects the **low** crossing only; the high one is **derived** as the first crossing strictly
after it (T2, and the proc's own header says so). So `nth` 0 names **exactly one rise time per low
crossing**, with nothing ambiguous about which pair is meant: a wave with its own X axis, which is
the shape `calc::dutyCycle`'s default cycle already answers and `calc::wave_dest` already holds.
D7 refuses a request that cannot be *interpreted*; this one can be, and a later stage will answer
it. A D7 refusal would also have to be **reversed as user-visible behaviour** once R410/R412's
argument dialog can route a wave into `calc::wave_dest`, where a deferral retires silently — which
is the whole reason the sentence is shared. `calc::delay` is the precedent rather than an analogy:
it is likewise a measurement proc with no `_scalar` wrapper, and it defers inside itself.

**Where the guard sits, and that placement is a decision.** After every request-level check — the
swing, the two references, the two percentages, the zero swing — and before any threshold
arithmetic. A deferral promises an answer once a destination lands, and a request with no swing will
still be malformed then, so a malformed request is refused **as malformed** rather than deferred.
Band `MT9b` has a row for that ordering, and moving the guard to the top of the proc reddens it.

**Item three is done too**: the comment claiming *"no arithmetic can meet an empty operand"* is
corrected in place rather than deleted, because the fact that it was a claim about one of the two
operands is what let this survive a reviewer.

**Fenced by** band `MT9b` of `tests/headless/test_calc_measure.tcl` (`hcases`, gating) — ten rows:
the hazard re-measured on `cross` itself, the raise gone, the sentence asserted by identity against
`calc::cross_msg listdefer` and pairwise against `calc::delay`'s own answer, every spelling of the
ordinal zero deferring, the deferral minting no destination, the malformed-request ordering, a
non-finite ordinal keeping `cross`'s own refusal, the measuring control, D5's absence still absent,
and `R402`.

**Band `WD9` of `tests/headless/test_calc_wave_dest.tcl` reddened on the fix, exactly as its own
comment predicted it would**, naming the undriven fourth caller. It was extended to **drive**
`calc::riseTime` alongside the other three; the derivation was not relaxed.

**Adjacent hole closed in the same change.** `WD10`'s `calc::cross_msg` arm sweep — the only
behavioural confirmation that no comment has landed between two `switch` patterns — used a
**hand-kept list of arm names**, and that list had gone stale against the seven arms the
wave-destination stage itself added (`badxaxis` and the six `dest*`). The arm set is now **derived
from the proc's own switch patterns**, with a non-vacuity row beside it. Measured over the real
proc: every arm answers a non-empty sentence and none raises.
