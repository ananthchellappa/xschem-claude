# Ledger — issue 1606 batch

Receipts land in `receipts/`. One row per handed-off task, collected by the driver.

| # | task | crew | receipt | verdict |
|---|---|---|---|---|
| A | reproduce the abort; drive all sites; settle the writers and the arithmetic | `measure:abort+sites` | `receipts/A-measure-and-drive.md` | **collected — 13 sites not 3, a fourth writer, and the abort is FILE-BORNE** |
| Av | adversarially refute A | `refute:A` | `receipts/Av-refute.md` | **collected — refuted 4 conclusions, thinned the evidence under 3 more, and found a SECOND defect** |
| B | cost the fix options against the build; recommend one | `design:fix-shape` | `receipts/B-fix-shape.md` | **collected — `clamp-at-use`, with option 4 shown to introduce a 1606-class defect at more sites than it fixes** |
| Bv | adversarially refute B | `refute:B` | `receipts/Bv-refute.md` | **collected — refuted 5 conclusions including the whole fencing plan, and caught one piece of invented evidence** |
| C | land the fix, fence every site, sabotage each row | `impl` | `receipts/C-implement.md` | **collected — 43 checks ALL PASS both arms; found that `graph_marker_fmt`'s overflow does NOT abort but corrupts silently** |
| Cv | independently sabotage every row | `sabotage` | `receipts/Cv-sabotage.md` | **collected — 2 guards fenced nothing, 4 decoy shapes defeated 24 of 43 rows, 2 shipped comments false** |
| C2 | close the seven holes | `repair` | `receipts/C2-repair.md` | **collected — 51 checks; found the old `#if 0` stripper had been DELETING a live statement in `save.c`** |
| C2v | re-prove each decoy is dead | `reprove` | `receipts/C2v-reprove.md` | **collected — ELEVEN new decoys, one defeating the sole fence on `show_node_measures`** |
| C3 | close the decoy CLASSES, not spellings | `close` | `receipts/C3-close.md` | **collected — 58 checks; gcc's own warning became the strongest fence** |
| C3v | final adversary | `final` | `receipts/C3v-final.md` | **collected — would gate; all 24 product guards redden; 6 false sentences and 2 false ROW NAMES to fix** |
| C4 | make every claim true | `correct` | `receipts/C4-claims.md` | dispatched |
| C4v | claim-by-claim truth audit | `audit` | `receipts/C4v-audit.md` | dispatched |
| D | gate: T1 solo, fresh clone, short path | driver | — | pending C4 |

## The headline, and it changes what this issue is

**The abort is file-borne, and neither the issue nor the driver's plan said so.** Both frame
the writers as the local user's own configuration — an rc file, `--preinit`, "any Tcl". In fact
a **`.sch`** carrying a `floater=true` text whose value is `tcleval([set ::ev_precision 200]…)`,
and a **`.sym`** whose `format=` attribute is a `tcleval(…)`, each set `ev_precision` and reach
the abort. Driven both ways: on a display, `xschem load` **alone** is enough (the load draws and
the draw evaluates the floater); headless it takes a `+ xschem print svg`, and the `.sym` door
poisons through plain **`xschem netlist`** with no display and no export at all — the emitted
SPICE line is literally `222* poisoned by a symbol format`. So **opening or netlisting a file
someone else wrote is enough**, and `main.c`'s `sig_handler` does not trap SIGABRT, so there is
no emergency save either.

⚠ **And the honest half of that**, which must be said in the same breath: the mechanism is
`tcl_hook2` → `tclpropeval2` → `uplevel #0 "subst \{$s\}"`, and `subst` performs **command**
substitution at global level. That is arbitrary Tcl execution from a file — a documented xschem
feature, far larger than 1606, and `ev_precision` is merely one of the things it can reach.
**Fixing 1606 does not make opening a stranger's schematic safe.** Carried forward, not fixed.

## What the refutation crews overturned, which is why they were dispatched

**The "conflict with issue 1602" was an arithmetic slip, and it was receipt A's headline.**
A claimed the tightest ceiling in the tree is 69, below 1602's ratified 71, so no single clamp
could satisfy both. Refuted three ways: the prose read the buf-80 column for a format that only
ever appears with a 100-byte buffer; `draw_hcursor` driven with a negative three-digit-exponent
value is clean at 71 and aborts at 90; and `"%.*gMEG"`'s arithmetic 69 is unreachable because
that branch divides by `1e6` first and is pinned at 56–59 characters at **any** precision, driven
to 4000. **The tightest reachable ceiling is exactly 71** — 1602's number. G2's recommendation
survives; G2's stated reason did not.

**The whole fencing plan was defeated.** Receipt B said the headless reproducer reddens if
either the `eval_expr.y` clamp or the `dtoa_eng` clamp is removed. Measured: with either one
alone still present, the other's removal leaves the row **green**, because the survivor produces
the same 71-digit string. Two redundant clamps on one path means **neither has a behavioural row
that reddens on its own removal** — precisely what the crew brief forbids. Stage C's instrument
is therefore a static row per clamp plus **one** end-to-end behavioural row whose comment states
its own limit.

**One prescribed comment would have shipped a new falsehood.** B told Stage C to rewrite
`nd_view_set`'s comment to say the shape aborts inside `my_snprintf`. Its format is bare
`"%.*g"`, no `%c`; fed to the hand-rolled formatter that shape returns `n=1, out=|1|`, rc 0. Only
the `%.*g%c` shapes abort. Caught by extracting the formatter's source verbatim with `sed` rather
than re-reading the `#ifdef`.

**One piece of invented evidence.** B's option-4 verdict cited
`dtoa_eng`'s `my_snprintf(s, S(s), "%.*g%c", 200, …)` returning 209 into `tok_size`. `dtoa_eng`
does not call `my_snprintf` at all — it calls bare `sprintf`. The verdict is right for a simpler
reason: option 4 leaves that bare `sprintf` untouched.

**And one claim that is right only on one ABI.** `graph_marker_fmt`'s comment says the `*` made
it *"consume the int `prec` AS THE DOUBLE"*. On x86-64 SysV that cannot happen — separate integer
and SSE argument areas, and measured, the double arrives intact while the **suffix** is eaten
(`'m'` → `\004`). But `XSchemWin/` exists and Win64 uses one argument area, where the comment
holds. The correction must name the ABI or it becomes false on the platform the original author
may have measured on.

**A second defect, at one of 1606's own sites.** `callback.c`'s graph tooltip guards on
`gr->unitx != 1.0` and then formats `gr->unity * yval` with `gr->unity_suffix`. A graph with
`unity=T` and no `unitx` — an ordinary configuration — therefore routes the **y** readout through
`dtoa_eng`'s 80-byte buffer instead of its own 100-byte one, dropping that readout's abort
threshold **from 93 to 73**; and `unitx=T` alone writes a **NUL** where a suffix was intended.
Fixed in Stage C, because it is at a site this issue owns and it moves this issue's own threshold.

## The measured numbers, for the record

Worst case `"%.*g%c"` is `prec+8` characters, so **cap = bufsize − 9** → **71** at 80 bytes,
matching 1602's sweep byte for byte (at 71 a negative T-branch value is 79 characters, the
80-byte buffer exactly full; 72 aborts). Independently re-derived by hand and by exhaustive
search over precision 0–4000 against 27 extreme doubles, agreeing in every cell:

| format | buf 80 | buf 100 | buf 1024 |
|---|---|---|---|
| `"%.*g"` | 72 | 92 | any |
| `"%.*g%c"` | **71** | 91 | any |
| `"%.*gMEG"` | 69 (unreachable) | 89 | any |
| `" %.*g%c "` | 69 (no such site) | 89 | any |
| `"%.*e%c"` | 70 (no such site) | 90 | 1014 |

**`%.*g` can never exceed 774 characters at any precision**, because a double's exact decimal
expansion holds at most 767 significant digits — which is what makes every 1024-byte `%g`
concern moot, and why the plan had that row exactly backwards. `%.*e` zero-pads and grows
without limit, and is safe today only because `prec = 2` is assigned three lines above it.

Baseline to gate against, from `c3a59de4`: `cases=98 blocks=97 counted_failures=0 skips=8`
(`results.1842389.log`, fresh clone built from scratch at an 84-character path, solo, throwaway
home, `elapsed=586s`, `wc -l` 293).

⚠ **Gate in a clone at a SHORT path** — `/tmp/g1606` is 10 characters and puts the deepest test
path at 73. The session scratchpad is ~100 characters before the clone name, and a clone at 173
makes T1 report 11 failures that are not real.

## Resume point

Stage C dispatched against `STAGE_C.md`, which supersedes `PLAN.md`'s Stage C section and
`DECISIONS.md` G1/G2 wherever they disagree. Fourteen adjudications are written there so the
implementation crew does not re-derive a measurement or inherit a refuted one.


## Rounds three and four: the fencing arms race, and calling a stop to it

**The product fix was finished after round one.** Everything after it was the fences around it,
and that is worth recording because the pattern is instructive: round two found four decoy
spellings that left the suite green on a tree with the real guard deleted; round three found
**eleven** more. Chasing spellings is what produces that curve. Round four closed *classes*
instead — string literals stripped, block-comment stripping made literal-aware, the directive
invariant widened to every `#` line, and the condition allowlist **deleted** in favour of
measuring which macros are actually defined on this build so a dead region cannot satisfy a row.

**The single worst decoy of the four rounds** was an `#ifndef __unix__` region in
`show_node_measures`. `__unix__` is defined here, so the region is dead — yet the spelling sat on
the allowlist as permitted, and an earlier crew had already established that row `G5` is the
**only** fence at that site (the negative row `X1` is blind there because the format strings are
`char *` variables, not literals). So the one fence on that site was satisfied by code the
compiler throws away.

**Two things the fences themselves broke, found only by sabotaging the fences:**

* The `#if 0` stripper matched `^[ \t]*#[ \t]*if[ \t]+0[ \t]*$` and never handled `#else`,
  so on `save.c`'s `read_raw_ascii_point` — which really has `#if 0 … #else /* faster */
  tmp[lines] = my_atof(line); #endif` — **it was deleting a LIVE statement** from the text the
  negative rows read. Over-stripping is not a harmless direction: for a row that hunts for
  something bad and passes when it finds nothing, hiding text *is* the defeat.
* The repair made the *line*-comment stripper literal-aware and left the *block* stripper naive,
  so a `/*` inside a string literal (`dbg(1, "/*\n");`) makes it run to the next real `*/` and
  swallow 591 bytes of live code — the same defeat, re-opened by the fix for it.

**The honest limit, named rather than papered over.** `if(0) <the asserted statement>` uses no
preprocessor at all, so no stripper and no directive invariant can ever see it. It is written into
the suite header as a limit, at the one site where nothing else covers it, and no special case was
added for it. A fourth round of whack-a-mole was refused.

## What gcc found that four rounds of sweeps could not

The first landed fix clamped `dtoa_eng` once above its branch at `avail − 9` = 71, and gcc warned:
`'__builtin___sprintf_chk' may write a terminating nul past the end of the destination`. It was
**right** — `"%.*gMEG"` needs `prec+11` bytes and 71+11 = 82 in an 80-byte buffer. **No sweep in
four rounds could find it**, because that branch divides by `1e6` first and its output is pinned
near 59 characters at any precision (driven to 4000, both signs, 1.6M calls: max 59). A static
bound was violated while no runtime probe could ever show it. The MEG conversion now carries its
own clamp at `avail − 11` (cap 69); the other arms keep 71 so the C ceiling still matches 1602's
published `1..71`; 192 driven strings are byte-identical either way.

That warning also handed the batch its strongest fence: **a row that compiles the sources and
asserts zero `-Wformat-overflow` diagnostics.** No decoy can fool the compiler's own opinion of
these formats — which is precisely what four rounds of hand-written static rows kept failing to
do, and it is the one fence that catches a clamp whose result never reaches its conversion.

## The record on false claims, because it is the recurring failure of this batch

Across four rounds this batch shipped, and then caught: two comments stating a mechanism that
does not reproduce; one comment upgrading an unattributed legacy figure into a claimed **Win64
measurement** on a machine with no Windows toolchain; a probe quoted from a tree that no longer
existed, inside the very paragraph rewritten to fix a stale quoted probe; a justification sentence
measured false; and **two row NAMES** that an eleven-second sabotage refutes — `W4`'s *"there is
no UNCLAMPED writer left"* and `X1`'s *"every indirect-precision sprintf statement in the
hand-written sources"*, each defeated by a single whitespace variant of its own needle. Round four
exists to make every one of those sentences true.
