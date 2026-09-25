# Receipt D — the sabotage, and the row it condemned

Crew `sabotage:V22-V26`, working entirely in scratch clones (`git clone --local
--no-hardlinks`; the plain `--local` fails here on a cross-device link). Four builds, all
distinct binaries, `cadlayers = 22` confirmed by counting `.lN` classes in an export. The
implementation stage ran its own sabotage too and agreed on S1; this receipt is the deeper
round, and **it found a weakness in the driver's plan.**

## S3 — the control, first, so a redden means something

Unmodified clone + the updated suite: **5 runs, all `ALL PASS (26 checks)`**. A second control
(`ctl99`) carrying only the `layer=99` fixture change and an intact clamp: **3 runs, all
`ALL PASS (26 checks)`** — so the fixture change alone reddens nothing, and any S2 redden is
attributable to the deleted clamp.

## S1 — the `psprint.c` guard deleted: 6 of 26 redden, and they are the right six

4 runs, identical verdict every time: **`RESULT: 6 FAILED (20 passed)`**.

| row | how it failed |
|---|---|
| **V22** | `print ps` 4199 vs 4187 bytes; `hier_psprint` **5570 vs 5558** |
| **V23** | `print ps` 75508 vs 75940 bytes |
| **V24** | `guard=0` — the static grep, no rebuild needed |
| **V26** | `print ps` `colours=445/445` — two 445-entry multisets differing in **content** |
| **V19** | `lines=7 distinct=3 outofrange=0` |
| **V20** | 47845 bad triples on 63 sheets |

Two details worth keeping:

* **`V19` failed in the lucky-heap shape receipt C predicted.** `outofrange=0` with
  `distinct=3` — the garbage landed *inside* 0..1 and only the `distinct == 2` clause caught
  it. The next run gave `distinct=3 outofrange=2`. This is the measured vindication of C's
  claim that the range clause alone is not the fence.
* **V22's `hier_psprint` leg caught two files of the SAME LENGTH** (5578/5578 in the
  implementation crew's run, 5570/5558 here). A size check would have missed it; `eq` on the
  whole slurped file is what sees it.

**V25 stayed green, and V22/V23's `print svg` legs stayed green** — correct: the revert touches
`psprint.c` only, and receipt A's verdict is that `svgdraw.c` has the shape and not the defect.
The per-verb split in the `bad=` lists is itself the evidence that each leg measures its own
back end.

## S2 — an `svgdraw.c` clamp deleted: THE ROW DOES NOT FENCE IT

The symbol-text clamp (`textlayer` → `c_for_text`) deleted, plus the suite's fixture forced to
`layer=99` so the unclamped path is actually entered. 26 suite runs:

| spelling | verdict |
|---|---|
| canonical `run_suites.sh --nogui`, forced fixture | **11 runs, 11 × ALL PASS (26 checks)** |
| armed-direct with `DISPLAY` set | V22 red 13/13, **V25 red only 10/13** |
| armed-direct with `DISPLAY` unset | 2 runs, 2 × ALL PASS |
| **s2 binary against the suite exactly as committed** | **3 runs, 3 × ALL PASS** |

That last line is the finding: **nothing the suite exports carries an out-of-range `layer=`
token, so removing any of the four clamps is invisible to the suite as shipped.**

**And V25 is a sampler, not a fence** — measured, not argued. Same clone, same binary, one
extra environment variable of N bytes:

```
pad=0    -> 1 FAILED (V22 only)      pad=100  -> 2 FAILED (V22 + V25)
pad=1    -> 2 FAILED (V22 + V25)     pad=1000 -> 2 FAILED
pad=10   -> 1 FAILED (V22 only)      pad=5000 -> 2 FAILED
```

**One byte of environment flips it.** Direct exports of the same fixture, 12 children: 7
distinct md5s, and the emitted `<text fill=…>` was malformed in 10 of 12 — `#746e69682d676e69`,
`#6f632f67612e666e`, ASCII fragments of paths read out of the heap — and well-formed in 2.

Reaching the read needs **three** coincidences: an out-of-range `layer=` token, `enable_layer[layer]`
reading nonzero so the text is drawn at all, and the garbage exceeding 255 so `#%02x%02x%02x`
emits more than two digits. The third is heap luck.

**The verbatim V25 failure, for provenance** — from `s2.full.log`, in the runs where the heap did
cooperate. It is recorded here because the V27 crew went looking for the token below, could not
find it in this receipt, and correctly declined to quote it without a source:

```
FAIL: V25 (1607) every colour xschem writes into an SVG is a well-formed #rrggbb …
  (bad={{fixture:rc=0,sig=0,tok=46,malformed={{#666e5100} #666e5100},undefined={}}}
   {fixture: colours=46 classes=2/22} {LCC_instances: colours=103 classes=9/22})
```

So `#666e5100` is real and is this row's own output. The longer tokens from the direct-export
sweep — `#746e69682d676e69`, `#6f632f67612e666e`, sixteen hex digits each — are ASCII fragments of
paths read out of the heap, and appeared in 10 of 12 children (7 distinct md5s / 12).

## Valgrind is a weaker instrument here than receipt A's zero reads

Three experiments, and the driver has folded all three into the issue:

* **At index 99** the address lands inside unrelated live or freed blocks, which valgrind
  considers addressable: **silent in 3 runs of 4**, and the one hit was
  `xctx->enable_layer[99]` in a freed block — the wrong array.
* **At index == `cadlayers`** it is reliable 8/8, because the address falls in the allocator
  redzone — but the redzone byte reads 0, so `enable_layer[22]` is false, the text is dropped,
  and `svg_colors[22]` is never reached. **The two over-reads in that statement are mutually
  exclusive under valgrind.**
* **With the schematic-own-text clamp removed instead** (that read is not gated by
  `enable_layer`), valgrind gives the exact psprint signature: `3 contexts`, `Invalid read of
  size 4`, *"0 / 4 / 8 bytes after a block of size 264"* at `svg_draw_string ← svg_draw`.
  264 = 22 × `sizeof(Svg_color)`; `+0/+4/+8` are `.red`/`.green`/`.blue`.

So the over-read is **real and deterministic in the source, random only in its consequence**.
Receipt A's eight clean runs remain evidence — they were taken against clamped code, which
produces no out-of-range index at all — but **the verdict rests on the four clamps, not on the
valgrind zero.**

## The consequence: row V27

**Accepted from the crew, which named it rather than writing it** (its task was to measure).
The matching instrument for a defect that is deterministic in the source and random in its
consequence is a **static** one, in V24's shape: assert all four clamps are present in
`src/svgdraw.c` and redden if any is missing. That reddens on the one-line deletion, in every
environment, in zero milliseconds. Dispatched as stage G.

V25 is kept as what it is — a well-formedness and referential-integrity row whose malformed
clause genuinely fires on real heap garbage — with its text corrected to stop claiming to be a
fence.

## Green by design, named rather than papered over

* **V24 green under S2** — it greps `psprint.c`. Asking one row to fence two files would be the
  error.
* **V19/V20 green under S2** — they parse ` RGB` lines out of PostScript; an SVG has none.
* **V23/V26 green under S2** — both export only `LCC_instances.sch`, where no text carries an
  out-of-range `layer=`. So **V22's fixture leg and V25 are the only two rows that can ever see
  the SVG clamps**, and both need a fixture the suite does not ship. This is exactly why V27 is
  static.
* **V26's structural limit.** It compares two arms of the *same* binary, so a defect corrupting
  both arms identically cannot move it. It reddened under S1 only because each process read a
  *different* garbage value — luck, not a property it asserts. The "zeroed palette entry" answer
  that this issue listed and decision E2 rejected would emit a stable `0 0 0 RGB` on both arms
  and V26 would stay green through it. **V26's subject is item 4 — that the display arm is not a
  second unmeasured code path — and it is not a determinism fence. V22/V23 are.**

## Honest gaps the crew declared

* **T1 not run** (forbidden for this crew) — no `cases=`/`blocks=`/`skips=` figure; the driver
  owes that.
* **V26's skip path not measured** — the dev display was up for all 30-odd runs, so the
  `skip: V26 --` branch and the `skips=9` prediction are unverified by this crew. (The
  implementation crew did force it, by pointing `XSCHEM_DEVDISPLAY_DIR` at a nonexistent
  directory, and observed `ALL PASS (25 checks)` with the skip line echoed.)
* **Neither rejected answer to item 1 was built.** A `set_ps_colors()` emitting a zeroed entry or
  the last real layer's would be deterministic and wrong; V22/V23/V26 would all stay green and
  V19's `distinct == 2` clause would be the only thing standing. The crew marked its reasoning
  about which variant V19 catches as reasoning, not measurement. Correct call.
* **`svg_colors` was never flagged through the symbol-text path specifically.** For that site,
  "the read is out of bounds" rests on the source plus the malformed tokens it emitted, not on a
  valgrind line naming `svg_colors`.

## Discipline note

The crew ended by checking `git -C /home/analog/dev/xschem-claude status --porcelain src/`,
found ` M src/svgdraw.c`, established it was a concurrent crew's comment-only change (13
insertions, 0 deletions, nothing outside a comment), and **did not revert it** — it flagged it
instead. That is the right handling of a shared tree, and it is the second time this batch that
a crew caught a concurrency hazard the driver created by running crews in parallel.
