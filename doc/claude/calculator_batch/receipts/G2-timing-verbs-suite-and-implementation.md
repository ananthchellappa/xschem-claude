# Stage G2/G3 — `riseTime`, `delay`, `dutyCycle`: the red-first suite and the implementation

Four crews over 2026-10-02 (author, two adversarial lenses, repair) plus one implementation crew.
Driver collected. Contract: `../TIMING_CONTRACT.md`. Recon: `G-timing-verbs-recon.md`.

## Red first, and the red was attributable

`tests/headless/test_calc_measure.tcl` — **125 checks, 11 bands MT0–MT10**, `hcases` alone.

Against the tree with none of the three verbs present: **`RESULT: 69 FAILED (56 passed)`**, exit 1,
**zero aborted bands, zero `UNEXPECTED ERROR`, zero `RAISED:`**. Every failure names the missing proc.
The infrastructure bands — fixture, sweep-by-name, the precision door, `calc::cross` in all three
dispositions, and the suite's own independent derivation of every asserted number — were green
throughout. A conforming reference then took it to `OVERALL: ok (125 checks)` **before** any product
code existed, so the suite was observed failing *and* passing on its own merits.

Final: `ALL PASS (125 checks)` against the real implementation, with every sibling green —
`test_calc_cross` 187, `test_calc_scratch_reuse` 53, `test_calc_engine` 265.

## ⚠⚠ A NEW failure mode `info complete` cannot see

The implementation crew's first revision put a four-line explanatory comment **between two `switch`
patterns** in `calc::cross_msg`. The braces balance perfectly and **`info complete` answered 1** — and
Tcl raised

> `extra switch pattern with no body, this may be due to a comment incorrectly placed outside of a switch body`

out of **every sentence in the catalogue**, turning **34 rows red at once**, including three of
`cross`'s own.

**This batch's standing brace-balance check is insufficient**, and that is worth stating plainly
because the check was adopted precisely to catch comment-shaped parse damage. A comment is safe above
a proc and fatal between two `switch` arms, and nothing structural distinguishes them. The driver's
independent confirmation was behavioural rather than textual: exercise **every** message kind and see
that none raises (23 kinds, `ok=23 raised=0`). **A comment moved inside a `switch` needs a row or a
run, never a brace count.**

## The most valuable finding: a mutation that was a FALSE RED

A legitimate conforming shared helper (`chain_ok`) had been **failing** the delegate rule — the suite
was over-constraining the driver's own T1 decision and would have pushed the implementer into a worse
shape to satisfy a row. After repair it is green, and the shapes T1 actually forbids still redden.
That is the opposite of the usual failure and much harder to notice: a row that is too strict looks
exactly like a row that works.

## Eight false claims, found by the repair crew grepping its own file

Beyond the four the lenses reported. The two worth repeating:

- *"LEVELS STRICTLY INSIDE (0, 1)"* became false the moment a dataset row asked about a trace whose
  swing is 0–5. Rewritten as *inside the column's own swing*, with the three deliberate exceptions
  enumerated.
- **Two reproducible numbers in comments it had just written**, caught before shipping: *"three orders
  of magnitude apart"* where the gap is a factor of 3, and a figure replaced by the shape so the row
  re-derives the gap every run. This is the `grep -c '#pragma'` failure in miniature, inside the change
  that was fixing the same class.

## The driver's own error, and it is the second of its kind

**Spec §7.2's `dutyCycle` row said `scalar` while R416 — written by the driver minutes earlier in the
same file — rules it returns a wave.** The table disagreed with the ruling beside it from the moment
the ruling existed. The implementation crew found it and fixed the cell to `scalar/wave`.

That is the **second** time in this batch a ruling shipped with its own table left disagreeing: the
first was `cross`, where §7.2 said `scalar/list` against a catalogue of `scalar/wave` and S24's closed
vocabulary. **Writing a ruling obliges re-reading every table in the same section**, and neither time
did any suite catch it — a table cell is prose.

Also retired: spec citations of `src/save.c` `case MAX` at `~:2629` (really **4751**) and `case CPH` at
`~:2799` (really **4921**), rotted ~2100 lines. Coordinates **deleted** rather than corrected, per the
rule that code is cited by symbol because coordinates rot and identity holds. Neither carried the
commit it was measured at, which is what would have made a line number legitimate.

## Sixteen sabotages, no holes

Every mutation reddened at least one named row. The narrow ones are the proof of aim:

| sabotage | rows |
|---|---|
| return a percent (R418) | 9 |
| leak a temporary | 6 |
| absolute-value the delay (R417) | 5 |
| drop T2's anchoring | 4 |
| derive the swing instead of refusing (R415) | 4 |
| include the trailing partial period | 3 |
| replicate one cycle's duty instead of computing each (R416) | 3 |
| echo the dataset without reading it | 2 per verb |
| skip the T5 guard | 2 |
| `dutyCycle_scalar` fails to defer the wave case | **1** |
| `delay` fails to defer `nth = 0` | **1** |
| accept a non-integer cycle | **1** |

Two splits a reader should not miss, both predicted by the suite's own comments. Skipping the T5 guard
does **not** redden MT9's first guard row — a measured empty list satisfies both its legs — and is
caught only by the *disposition* row. And including the trailing partial period leaves `v(sq)`'s
exclusion row green; it is caught only on the **inverted** square, which is why that row exists.

## SR5 green with no edit, which is what T1 was chosen for

```
adders = cross eval_rpn   minters = cross eval_rpn   readers = cross eval_rpn
deleters = cross eval_rpn   four-way equal = 1
riseTime / delay / dutyCycle / dutyCycle_scalar: in NONE of the five sets
```

The pure-delegate shape costs `test_calc_scratch_reuse` nothing — exactly what recon predicted for
shape A, and the reason six other candidate shapes were rejected.

## Catalogue

S24's permitted `returns` vocabulary, lifted from its own predicate: `scalar` · `wave` · `bool` ·
`scalar/wave`, and nothing else. `riseTime` and `delay` stay `scalar`; **`dutyCycle` becomes
`scalar/wave`** (R416's default is a wave, a named cycle gives a scalar — `cross`'s exact shape, so
`cross`'s spelling). S24's eight category counts unchanged at `{56 26 12 4 3 3 4 108}`.

⚠ Because S24 lives in a `dcases` suite that measures **nothing** under `--nogui` (it self-skips to 0
checks), that suite's green says nothing about the catalogue. The crew lifted **every** S24 predicate —
plus `test_calc_buffer`'s CB2, `test_calc_plot`'s PL9 and `test_calc_widgets`' R113 — and ran them
headless against the live namespace. All green. The driver's T1 gate covers the real display arm.

## Registration

`hcases` **94 → 95**, `dcases` 24, `tcases` 3 → `planned_cases` **123**. Every entry in both lists
machine-checked to resolve to a file on disk. ⚠ **The suite file was untracked while registered** — the
"nearly committed two untracked suites" failure from the other side — and is `git add`ed in the same
commit.

## Holes declared, not papered over

No `fallTime` or direction variant; an inverted threshold pair or inverted swing (each a single
question for the user, not guessed); `op`/`ac` dataset reads untouched (every dataset row is on the
`tran` read); D10's bulk read still unfenceable; any sample door outside `{add values value del}`
would escape the structural row; and three dispositions the **suite** chose rather than the contract —
a zero swing refused, `delay`'s `nth = 0` deferring, and the stub probe requiring `cross`'s sentence to
come *through* — all adopted as written and now named in the source.

⚠ **A green 7.3 is a working measurement layer, not a reachable feature.** `calc::fn_click` dispatches
on `calc::fn_reason`, empty for route `T`, and falls through to `calc::inert … 5`, so a shipped
`riseTime` is **not clickable**, exactly as `cross` is not. Phase 5 owns R410/R411/R412.

## Scratch discipline

20 KB left by the implementation crew, 1.8 MB by the suite crews; the 190 KB pristine copy of
`calculator.tcl` deleted after `cmp` confirmed restoration. `/tmp` unchanged at ~749 MB of 7.7 GB.
Reported per stage because the previous one left **4.4 GB** in a tmpfs and starved the machine of the
RAM T1 needs.
