# C3 — the last unfenced guard, and the rule that stops a comment quoting a command

Stage C3, the final crew. **No product behaviour changed, proven at object level (§6).** The work is
one new row (`G15`) closing the last guard that reddened nothing, one regexp change closing the
citation checker's likeliest future miss, and **a named convention written into the suite so the
sentence that has now shipped wrong three times cannot ship a fourth.**

`tests/headless/test_snprintf_fmt_1608.tcl`: **33 → 34 checks**, `ALL PASS` on all three arms, zero
`skip:` lines. T1 solo, my own run: **`cases=100 blocks=99 counted_failures=0 skips=8`** (§7).

---

## 1. U1 — THE GUARD THAT REDDENED NOTHING, AND IT WAS THE HALF THAT STOPS THE WRITE

`refuse` does **two separable things** at each gated arm: it skips
`strncpy(nfmt, fmt, l); nfmt[l] = '\0';`, and it breaks after the prefix write. Only the **break** was
observable to the rows — `g_refused` is `rc 0 && sig 0 && ret 0 && len 0` — and **no case drove a spec
of 51 characters or more through the `p` or the `g/e/f` arm.** G1's 49/51/202-character dash runs all
go through `d/x/c/u`; G12's longest `p` spec is exactly **50**, which is the *silent* (B) store.

### What I added

**One new row, `G15`**, and four driver cases. The driver's spec builder already had `'#'` (→ `%<n
dashes>d`) and `'@'` (→ `%<n dashes>p`); I added `'!'`, which takes the conversion letter from
`fmt[1]`, so the `g/e/f` arm is reachable with a dash run:

```c
{ "PY", "@",  'p', 49, 0.0, 80 },      /* %<49 dashes>p  -- spec length 51 */
{ "FG", "!g", 'd', 49, 0.0, 80 },      /* %<49 dashes>g */
{ "FF", "!f", 'd', 49, 0.0, 80 },      /* %<49 dashes>f */
{ "FE", "!e", 'd', 49, 0.0, 80 },      /* %<49 dashes>e */
```

**51 and not 50 on purpose**, and that is the whole point of the row: at 50 the array store goes one
byte past and *nothing complains* (a plain store is not fortified); at 51 `strncpy` itself writes past
`char nfmt[50]` and `__strncpy_chk` aborts. **The death is the discriminator**, and `g_refused`
includes `g_ok`, so a case that aborts fails the row. Each of `g`, `e` and `f` is driven separately
because one arm handles all three letters and a row naming the arm should drive the arm.

Green, on the shipped tree:

```
ok:   G15 ... (p51={0 0 0 intact 0 {}} g51={0 0 0 intact 0 {}} f51={0 0 0 intact 0 {}} e51={0 0 0 intact 0 {}})
```

### Sabotage 1 — `if(!refuse)` removed in the `p` arm ALONE

Exact-text removal anchored on `i = va_arg(args, void *);` so only that arm is touched (the wrapper's
text is identical in all three gated arms; the harness asserts it found 3 and that the one it edited
is within 400 bytes of the anchor). `make -C src` rc 0. Verbatim, the only failing line:

```
FAIL: G15 (1608 the `if(!refuse)` WRAPPER ROUND THE strncpy, in the `p` and g/e/f arms) a 51-character spec -- `%` + 49 dashes + the conversion letter, ONE PAST nfmt[50] -- is REFUSED and the process SURVIVES, driven through the `p` arm and through each of `g`, `e` and `f`. Removing `if(!refuse)` in either of those two arms alone left every other row in this file green while these four specs died `*** buffer overflow detected ***` (sig 6), because the only half of `refuse` the other rows can see is the break AFTER the prefix write, never the skipped strncpy. G1 covers the same wrapper in the d/x/c/u arm. The canary and the returned length are in the detail; what this row asserts is rc 0, no signal, ret 0 and an empty result (p51={-1 6 - - - DIED} g51={0 0 0 intact 0 {}} f51={0 0 0 intact 0 {}} e51={0 0 0 intact 0 {}})
```

`RESULT: 1 FAILED (33 passed)` — **G15 the only red**, so the 33 rows that existed before it are all
in that 33, which reproduces C2v's "ALL PASS with the wrapper gone" from the other side.

### Sabotage 2 — `if(!refuse)` removed in the `g/e/f` arm ALONE

Anchored on `i = va_arg(args, double);`. `make -C src` rc 0. Verbatim, the only failing line (same
name; the detail is the evidence):

```
FAIL: G15 (1608 the `if(!refuse)` WRAPPER ROUND THE strncpy, in the `p` and g/e/f arms) ... (p51={0 0 0 intact 0 {}} g51={-1 6 - - - DIED} f51={-1 6 - - - DIED} e51={-1 6 - - - DIED})
```

`RESULT: 1 FAILED (33 passed)` — G15 the only red, all three letters dead, the `p` arm unaffected
(so the sabotage really was arm-local).

### The death message, measured by me and not inherited

I rebuilt C2v's instrument independently (the suite's own link stubs, extracted from the suite file,
`src/util.c` at the build's CFLAGS, one process per case) so the message in G15's name is mine:

```
with if(!refuse) removed in the p arm ALONE:
  ndash=48 term=p (spec length 50): rc=0    |speclen=50 ret=0|            <- the SILENT (B) store
  ndash=49 term=p (spec length 51): rc=134  |*** buffer overflow detected ***: terminated|
  ndash=58 term=p (spec length 60): rc=134  |*** buffer overflow detected ***: terminated|
  ndash=49 term=g (spec length 51): rc=0    |ret=0|                       <- other arm unaffected

with if(!refuse) removed in the g/e/f arm ALONE:
  g/f/e at spec length 51 and 60:   *** buffer overflow detected ***: terminated   (all six)
  p at 51 and 60:                   ret=0                                <- other arm unaffected
```

Restored with **`cp`** (never `cp -a`) after each, `make -C src`, and `RESULT: ALL PASS (34 checks)`
re-confirmed both times; `cmp` against the frozen copy reported identical both times.

### And the product comment now says so

`MY_SNPRINTF_PREFIX_GUARD` in `src/util.c` gained a paragraph naming the two halves of `refuse`,
saying that deleting the wrapper alone changes no return value and only brings the out-of-bounds write
back, that it is the pre-1608 shape, and that **G1 fences it in `d/x/c/u` and G15 in `p` and
`g/e/f`**. Comment-only; X1 verifies the two row ids exist.

---

## 2. U2 — THE RULE, WRITTEN DOWN WHERE THE NEXT AUTHOR WILL READ IT

### The sentence, third time

```
round 1 shipped:  "... `grep -rc '#pragma' src/*.c src/*.h` sums to 0"        truth: 1
round 2 shipped:  "... sums to 1 AND NOT 0"                                    truth: 3
```

Nobody miscounted. `grep -c` counts **lines**, the sentence is **inside the file the grep reads**, and
round 2's rewrite happened to spread the word `#pragma` across three lines of itself. The substance was
true every time; **the number is the one part that cannot be.**

### The rule: named limit `L9` of the suite

Written into the suite's NAMED LIMITS header as **`L9`**, in full, with the two-round history spelled
out so the next author sees the price rather than a bare prohibition, and with a one-line pointer to it
from `L1` (which is the same rule applied to rows rather than comments). Two clauses:

1. **No comment in this batch — here or in `src/` — quotes a count that a command over the tree's own
   text produces.** Either a ROW asserts it (re-measured every run, reddens when it moves) or the
   sentence states the substantive claim with no number.
2. **No figure the instrument cannot reproduce.** GUARD 1's comment quoted three specific integers
   printed by a `va_arg` on a vararg nobody pushed, *in the same paragraph that says the value is
   stack garbage*; a second crew re-drove it and got six different numbers.

And what it does **not** forbid, stated so the rule is usable: a measurement of the *program's*
behaviour with its instrument named — a formatted width, an exit code, a death message, or a count of
items the sentence itself enumerates. Those are reproducible independently of the sentence.

### Both copies of the `#pragma` sentence

Now, in **`src/util.c`** (spec gate) and in the suite's **W1** comment, with no number in either:

> …a tree-wide zero would need a real `#pragma GCC diagnostic` at every one of them, and **THIS TREE
> HAS NO `#pragma` DIRECTIVE ANYWHERE**: `/usr/bin/grep -rln '#pragma' src/` names this file and
> nothing else, and the hit in this file is this sentence. ⚠ **NO COUNT IS QUOTED HERE, AND THAT IS
> DELIBERATE** — see named limit L9. The grep reads the file this sentence lives in, so any number
> written down here is a hostage to how the sentence happens to be laid out, and the same claim shipped
> wrong twice on exactly that: `-rc` counts LINES, and a rewrite spread the word `#pragma` over three
> lines of itself. State the claim, let the reader run `-rln`, and let a row assert anything that has
> to be a number.

Verified: `/usr/bin/grep -rln '#pragma' src/` → `src/util.c`, nothing else. The `-rc` figure for
util.c is now 3 again **and no longer matters**, which is the fix.

### The sweep — every numeric claim in the five files' 1608 comments

I extracted every number and number-word from the added comments in `src/util.c`, `src/util.h`,
`src/svgdraw.c`, `src/xinit.c` and `src/parselabel.l` and classified each. **Two more false counts
found, both fixed; four figures re-measured and kept; the rest classified as program-behaviour
measurements and kept.**

| claim | where | verdict |
|---|---|---|
| `grep -rc '#pragma' … sums to 1 and not 0` | util.c + suite W1 | **FALSE (3). Fixed, no number now.** |
| `three live callers` / `scheduler.c's %ld twice, %lu and %hu once` | util.c ×2, suite L4 + G5's name | **FALSE AND SELF-CONTRADICTORY: it says three and then itemises four, having counted a `%ld` that is inside a comment (scheduler.c:12656). Live: `%hu` ×1, `%ld` ×2, `%lu` ×1 = four sites. Fixed: the spellings and the getters are named, the total is gone.** |
| `the clean tree emits five` (-Wformat diagnostics) | util.c, util.h, suite `wcompile` | **A gcc aggregate over src/ that no row asserts and that moves on any added deliberate non-literal sprintf. De-numbered in all three; the two permitted SHAPES stay, which is what W1 keys on.** |
| `three runs … printed 32, 112 and 24` | util.c GUARD 1 | **Non-reproducible by the paragraph's own admission. Removed; the SHAPE stays.** |
| `~20 sites in actions.c read as a length` | util.c | a grep count (21 `tok_size` occurrences, reads and writes together). **De-numbered.** |
| `nm -S src/util.o` shows one my_snprintf | util.c | **re-measured: `00000000000013a0 00000000000005ee T my_snprintf`, one. Kept.** |
| `nm -u src/util.o` lists no vsnprintf | util.c | **re-measured: 0. Kept.** |
| `-Wformat-zero-length … which this tree has none of` | xinit.c | **re-measured both halves: restoring `my_snprintf(old_win_path, S(old_win_path), "")` in a scratch copy gives `warning: zero-length gnu_printf format string [-Wformat-zero-length]` at the DEFAULT build flags, and the tree as it stands emits zero of them. Kept.** |
| `412 / 419 / 593`, `317 / 511 / 503 / 502`, `4933`, `337 / 338`, `80-character font=`, the 91bb1bd7 rc/message table | util.c, svgdraw.c, xinit.c | program-behaviour measurements with the instrument named; C2v re-drove all of them. **Kept under L9's third clause.** |
| `Five independent proofs`, `Five live sites …`, `util.c three sites; draw.c two more`, `the five return-value consumers` | util.c | counts of the sentence's own enumeration, checkable by reading. **Kept.** |
| `a 4971-byte Tk menu -command script`, `5 of 7 environments`, `10 uninitialised stack bytes`, `\|/tmp/claude-1000/-ho\|` | util.c | dated figures from named incidents, each labelled as what it is. **Kept, and recorded here as considered.** |

**In the suite as well**, three more counts of the tree's own text, all de-numbered under L9:
`HAS_SNPRINTF` "twice and eight times" (U3b, below); `citations=13 … 13 against 12` in X1's scope
comment (which **my own U4 regexp could have moved**, and did move the live figure from 13 to 16 as
soon as I added comments citing rows); `ALL PASS (13 checks) instead of 33` in L6; and
`row P2 measures the longest at 5 characters` in the header.

**Outside the sweep's five files, carried forward not fixed:** `src/token.c`'s pre-existing comment
quotes a garbage integer (`no '@' or '% 536627636n it.`) from another issue's measurement. Same class
as L9 clause 2, not 1608's text, not mine to edit.

---

## 3. U3 — the three named false statements

### (a) `src/util.h`: the flag that names which five

Measured by me over all of `src/*.c` at the build's own CFLAGS (`gcc -fsyntax-only`), and it is
sharper than C2v's measurement in one respect — the tag holds under `-Wformat` **alone**:

```
CLEAN TREE
  -Wformat -Wformat-nonliteral :  draw.c:5309, draw.c:5310, util.c:856, util.c:887, util.c:918
                                  -- all [-Wformat-nonliteral]
  -Wformat -Wformat-security   :  (nothing at all)
  -Wformat                     :  (nothing at all)

ONE REAL 1608 CALL SITE REVERTED (svgdraw.c's svg_draw() textfont site, in a scratch copy)
  -Wformat                     :  format not a string literal and no format arguments [-Wformat-security]
  -Wformat -Wformat-security   :  ... [-Wformat-security]
  -Wformat -Wformat-nonliteral :  ... [-Wformat-security]
  -Wformat-nonliteral (alone)  :  ... [-Wformat-security]

BOTH SHAPES ON ONE PROBE INCLUDING THE REAL src/xschem.h
  my_snprintf(b,n,uf)    -> [-Wformat-security]    under all three flag sets
  my_snprintf(b,n,uf,7)  -> [-Wformat-nonliteral]  only with -Wformat-nonliteral
```

`src/util.h` now says **both things separately**, under a heading that names the error rather than
hiding it: *"TWO DIFFERENT SETS OF FIVE LIVE IN THIS PARAGRAPH AND THEY TAKE DIFFERENT FLAGS. AN
EARLIER VERSION CONFLATED THEM, PUTTING THE RIGHT CLAIM ON THE WRONG FIVE."* — (i) the clean tree's own
diagnostics all pass an argument and are `[-Wformat-nonliteral]`, with `-Wformat-security` naming none
of them; (ii) the five call sites 1608 is about are all zero-argument and are reported
`[-Wformat-security]`, *whatever* flag is passed, which is why a filter keyed on the flag **name**
`-Wformat-nonliteral` went green on a tree with a real door reopened. The suite's section-W header
carried the same conflation in the opposite direction ("THE FLAG IS `-Wformat-nonliteral`, NOT
`-Wformat-security`") and now carries the same two-part statement.

### (b) the suite's section-S count

Was: *"src/util.c's replacement comment spells `#ifdef HAS_SNPRINTF` **twice** and `HAS_SNPRINTF`
**eight times** on purpose."* Measured inside that comment: `#ifdef HAS_SNPRINTF` 2, bare
`HAS_SNPRINTF` **7**. Per L9 the number is not the fix — it is the problem — so both numbers are gone:

> src/util.c's replacement comment spells both `#ifdef HAS_SNPRINTF` and the bare `HAS_SNPRINTF`
> **repeatedly and on purpose**, so a raw grep would be RED on the correct tree

and the section's own preamble now records why: *"An earlier version of the paragraph below claimed a
figure for how many times util.c's own comment spells `HAS_SNPRINTF`, and it was wrong: a count of the
tree's text, written into the tree's text, in a file whose own named limits forbid exactly that."*
`S1`'s assertion is `raw_hits > 0`, never a count, and is unchanged.

### (c) `G12`'s canary — STOPPED CLAIMING IT, and here is why that is the right half of the choice

`G12`'s expression is `g_refused` ×5, i.e. `rc == 0 && sig == 0 && ret == 0 && len == 0`. The canary is
index 3 of the tuple and only `G8` reads it.

**I chose "stop claiming it" over "assert it", and the reason is that the assertion would be inert.**
Every `G12` case refuses with an **empty prefix**, so `n` and `l` are both 0, `n+l >= size` is false
for either spelling of the (D) guard, and nothing on that path writes anywhere near index 80. An
assertion there could not be reddened by any single removal in the function — which is precisely the
belt-and-braces trap that cost the 1606 batch a whole fencing plan. So `G12`'s name now reads:

> …are ALL refused by the `p` arm, **WITH NO SIGNAL: rc 0, sig 0, ret 0, len 0.** ⚠ **THE CANARY IS
> REPORTED IN THE DETAIL AND NOT ASSERTED HERE** — an earlier version of this name claimed `an intact
> canary`, which `g_refused` does not read; the canary at index `size` is G8's, and asserting it in
> this row would add a condition no sabotage can reach, because every case here refuses with an EMPTY
> prefix and nothing on that path writes near index 80.

The row's ASSERTION is unchanged, so no re-sabotage was owed and none was done. `C2-close-gaps.md`
repeats the error in stronger form ("canary intact") and I did **not** rewrite another crew's dated
receipt — same deviation C2 itself declared.

---

## 4. U4 — the citation checker, one regexp, twelve attacks re-driven

### The change

```tcl
set xIDB "`?${xID}`?"
set xIDL "${xIDB}(?:(?:-|/|, | and |, and )${xIDB})*"
```

One optional backtick on each side of **every** id in the list, so the single, the range and the
comma form all match with or without them. `xids` already extracts `[A-Z]…` and `-` tokens and ignores
the backticks themselves. Clean tree after the change: `citations=13 files=6 other_suites=3
unattributed={}` — **digit for digit what it was before**, so no existing citation changed bucket.
(It is 16 now, because my own new comments cite G1, G15, W1 and F4b; X1 confirms all of them exist.)

### The twelve attacks, re-driven

Ten planted **simultaneously**, each with a unique fabricated id so `unknown={…}` attributes every
outcome to exactly one attack; the range attack separately. Verbatim, the ten-attack run:

```
FAIL: X1 ... (unknown={{util.c: cites Q9 (in "Q9") -- no such row}
{util.c: cites Q8 (in "Q8") -- no such row} {util.c: cites Q2 (in "Q2") -- no such row}
{util.h: cites V27 (in "V27") -- no such row} {util.h: cites Q1 (in "`Q1`") -- no such row}
{util.h: cites Q3a (in "Q3a") -- no such row} {xschem.tcl: cites Q7 (in "Q7") -- no such row}}
citations=20 files={parselabel.c parselabel.l svgdraw.c util.c util.h xinit.c xschem.tcl}
other_suites=21 unattributed={} rows_known=34 gwp_rows_missing={} suite=test_snprintf_fmt_1608.tcl)
RESULT: 1 FAILED (33 passed)
```

and the range run, which also planted a backticked comma list:

```
FAIL: X1 ... (unknown={{svgdraw.c: cites F5 (in "F1, F2, F3, F4, F4b and F5") -- no such row}
{util.h: cites F5 (in "`F4`-`F6`") -- no such row}
{util.h: cites QZ9 (in "`F1`, `F2` and `QZ9`") -- no such row}} citations=15 ... )
```

| attack | shape | before | now |
|---|---|---|---|
| `Q9` | inside a `/* … */` block comment (util.c) | CAUGHT | **CAUGHT** |
| `Q8` | inside a C string literal (`static const char zz1608_q8[] = …`) | CAUGHT | **CAUGHT** |
| `Q2` | inside a `#if 0` region | CAUGHT | **CAUGHT** |
| `V27` | a real row of ANOTHER suite, cited as ours | CAUGHT | **CAUGHT** |
| `Q7` | a `.tcl` file under src/ (src/xschem.tcl) | CAUGHT | **CAUGHT** |
| `F4-F6` | range whose middle was renamed away | CAUGHT | **CAUGHT**, and now also **in backticks** (`` `F4`-`F6` ``) — and the rename reddens the real citation in svgdraw.c too, i.e. both directions |
| **`Q1`** | **id in BACKTICKS** (`` rows `Q1` of … ``) | **MISSED** | **✅ CAUGHT — this is the U4 fix.** A backticked comma list with a bad member (`` `F1`, `F2` and `QZ9` ``) is caught too |
| `Q3a` | file NAME split across two comment lines, in a file naming ONLY our suite | reported missed | **CAUGHT** — a refinement of C2v's result: the `xonly` fallback still attributes it. Driven. |
| `Q3b` | the same split name in a file that also names another suite | MISSED | **still missed** — rule 3 hands it to the suite named last. Now named in `L7`. |
| `Q5` | rule-3 misattribution: bare `row Q5` after a different suite's name | MISSED | **still missed** — counted in `other_suites`. Now named in `L7` with the mechanism. |
| `q7b` | LOWERCASE id (`row q7b`) | MISSED | **still missed** — the id shape excludes it by design. Now named in `L7`. |
| `Q6` | HYPHENATED keyword (`row-Q6`) | MISSED | **still missed** — the keyword needs whitespace. Now named in `L7` (it was only *implied* before). |
| `Q4` | a file with NO source-text extension (src/Makefile) | MISSED | **still missed** — `xwalk`'s extension list. Now named in `L7`. |

**Every remaining miss is now enumerated in `L7` with its mechanism**, under a heading saying the list
comes from an attack run and not from reasoning. `L7` also lost its citation count (L9).

**Anti-vacuity re-driven with my regexp**, because the regexp is now mine: renaming the suite's name in
all six citing files gives

```
FAIL: X1 ... (unknown={} citations=0 files={} other_suites=0 unattributed={} rows_known=34 ...)
```

so the floor still fails rather than passing silently. Restored with `cp`.

---

## 5. Four more false sentences C2v named, fixed in the same files

Not in the four items, but they are known-false, they ship, and they are in files I was already
editing. Naming them and leaving them would have been the same defect the batch has now paid for
seven times.

* **§3.7 the header's universal** — *"Every guard reddens on its own single removal"* with one stated
  exception. U1 makes it true again for the `if(!refuse)` wrapper, so the sentence is rewritten as a
  **record of what has been driven, in two rounds**, with **two** stated exceptions rather than one:
  the `overflow = 1` uniformity, and (newly written down) the digit loop's `i + 1 < len` bound, which
  cannot change an observable because the loop advances only while `spec[i]` is a digit and
  `spec[len-1]` is the conversion letter. Recorded so the next crew does not file it as a sixth
  unfenced guard.
* **§3.5 the section-F table** — put `F9` in the verbatim `cannot find` group. `F9`'s `--rcfile` names
  a file that EXISTS; nothing prints `cannot find` and the assertion is `SOURCED=<1>`. The table now
  has a controls row naming F5 and F9, and says plainly that this false line was inside the paragraph
  that replaced a false sentence about every row.
* **§3.6 `src/svgdraw.c`** — *"ONE ROW PER SITE because no one fixture reaches two of them."* Measured
  false: a `.sch` with its own text AND an instance whose `.sym` carries a text executes **both**
  `textfont` sites in one export. The reason is **attribution, not reachability**, and the comment now
  says so with the refutation attached.
* **§3.9 two minor ones** — the section-X comment's *"svgdraw's are F1-F5"* (they are F1, F2, F3, F4,
  **F4b** and F5, which `F1-F5` does not spell either), and `P2`'s *"no LITERAL conversion spec
  **anywhere** in the compiled tree"*, which reads as covering the `%s` arm the row deliberately does
  not submit to `cens_verdict`. `P2`'s name now states that exclusion **and why it is not an
  oversight**: my_snprintf's `%s` arm does not submit its specs to the guards either — it never builds
  `nfmt` and never calls `my_snprintf_spec_ok()` — so a long `%s` spec is outside the product's gate
  as well, which is named limit L3's defect and not this row's. `P2`'s ASSERTION is unchanged.

**Not fixed, and reported instead:** C2v §3.8 un-records one of Stage C's twenty-one (the
`scheduler.c` raw-hits figure is right in the *occurrence* units row `S2` actually uses —
`raw_hits=4`, `grep -c` lines gives 3). That lives only in dated receipts; I did not edit another
crew's receipt.

---

## 6. NO PRODUCT BEHAVIOUR CHANGED — 39 of 40 objects byte-identical, the 40th by ONE byte of `__TIME__`

The brief's own caveat handled: `src/scheduler.c` carries `char date[] = __DATE__ " : " __TIME__`, so
an `src/xschem` md5 is not an identity. **Compared `.o` files.**

Tree A = the tree as I leave it. Tree B = a full copy of `src/` with `util.c`, `util.h` and
`svgdraw.c` replaced by the copies I froze **before** my first edit (the other six touched product
files are `cmp`-identical to those frozen copies, so my edits are confined to three files — asserted,
not assumed). All 40 translation units compiled in each at the build's own CFLAGS, from inside each
tree so `#include "../config.h"` resolves:

```
compared=40 differing=1 build_failures={}
DIFFERS: scheduler.oo  bytes=1
  113248  65  67
  A: ...0:47:35...   B: ...0:47:37...      <- the seconds digit of __TIME__
```

```
util         A=9e2049fdb704a1bf B=9e2049fdb704a1bf
svgdraw      A=6f1fee5d884914c4 B=6f1fee5d884914c4
xinit        A=e9141d7a7e0a1ec0 B=e9141d7a7e0a1ec0
parselabel   A=bb476688e4b4fdd6 B=bb476688e4b4fdd6
```

**Every one of the three files I edited compiles to a byte-identical object**, with **identical
warning text** (paths normalised), and the four md5 prefixes match C2v's digit for digit — the same
objects two crews apart. And `src/util.o` / `src/svgdraw.o` **as they sit in `src/`** are `cmp`-identical
to a fresh compile from these sources, so the binary in the tree is built from them.

**Every edit of mine in `src/` is inside a `/* */` comment, and that is checked rather than asserted:**
of the changed lines between the frozen copies and the tree -- 51 in `util.c`, 32 in `util.h`, 9 in
`svgdraw.c` -- **zero** fail to begin with optional whitespace then `*` or `/*`.
`git diff --stat` for the three against HEAD: `svgdraw.c 57 +++`, `util.c 306 +++`, `util.h 39 +++`.

---

## 7. The three arms and T1, verbatim

Rebuilt first (`make -C src`, rc 0), armed spelling (`run_suites.sh`), one arm at a time.

```
################ ARM 1 -- nogui (DISPLAY unset by the driver) ################
test home: throwaway /tmp/xschem-test-home.2973990.IpZ2sr (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (34 checks)
RESULT: 1/1 runs passed

################ ARM 2 -- display (dev display :99) ################
test home: throwaway /tmp/xschem-test-home.2974522.cWLudq (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (34 checks)
RESULT: 1/1 runs passed

################ ARM 3 -- no dev display reachable (private Xvfb) ################
test home: throwaway /tmp/xschem-test-home.2975035.3jzi4s (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: private Xvfb from :200 up, screen 1920x1080x24, wm openbox, GUI_GATE=0
             (AUDIT_DISPLAY=:0 to use the real screen, =none to skip GUI legs)
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (34 checks)
RESULT: 1/1 runs passed
```

Arm 3 pointed `XSCHEM_DEVDISPLAY_DIR` at an empty, mode-555 scratch directory. `devdisplay.sh status`
reported the same `xvfb: 3979908` before and after every arm; **`start|stop|view` was never run.**
Zero `skip:` lines on all three arms, so this suite still contributes **no** skip to the gate. Counted
shapes in the suite's own output (`grep -cE 'FAIL$|GOLD\?$|RESULT\?$|^FATAL'`): **0**. The 34 rows, in
order: `F1 F2 F3 F4 F4b F5 F6 F7 F8 F9 W1 W2 P1 P2 P3 G11 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G12 G13 G14
G15 S1 S2 S3 X1`.

**A fourth run, gcc off `PATH`** (a 1609-symlink sanitised PATH with no `gcc`/`cc`/`g++`), because I
added `G15` to `gwp_rows` and that list is the one thing in the file kept by hand:

```
skip: G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12 G13 G14 G15 W1 W2 P1 P2 P3 -- no gcc on PATH (0 chars) or no CFLAGS line in the generated Makefile.conf, so neither the formatter can be linked into a driver nor the compiler's own -Wformat opinion taken. Section F still drove the five call sites through the built binary, and S1, S2 and X1 still ran
skip: S3 -- no gcc or no CFLAGS line, so parselabel.c could not be preprocessed; S1 and S2 still read the source text
RESULT: ALL PASS (13 checks)
OVERALL: ok (13 checks)
ok:   X1 ... (unknown={} citations=16 ... rows_known=34 gwp_rows_missing={} ...)
```

`G15` is named in the skip line, `rows_known=34` (so `row_skip` fed every skipped id into X1's set and
a citation of a row that did not RUN is still not mistaken for one that does not EXIST),
`gwp_rows_missing={}`, both skip lines lowercase, neither ending in `FAIL`/`GOLD?`/`RESULT?`, and zero
counted shapes.

**T1 solo.** No `results.<pid>.log` had a live `/proc/<pid>` when it started, and the only other
`tclsh` on the box was a day-old `tclsh -c exit` (pid 2254960, started Fri Sep 25 11:10:49), not a
regression run. Zero `another regression run is live` lines in the driver's stdout.

```
T1-RUN-BEGIN pid=2975965 script=run_regression.tcl start=2026-09-26 20:45:38 planned_cases=100 verdict=results.2975965.log home=throwaway binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
T1-RUN-END pid=2975965 cases=100 blocks=99 counted_failures=0 skips=8 elapsed=596s end=2026-09-26 20:55:34
```

`wc -l` **299**. Counted shapes (`grep -cE 'FAIL$|GOLD\?$|RESULT\?$|^FATAL'`) **0**. `skips=8`, and all
eight are the baseline eight — `test_op_annot`'s five display-only rows on the headless arm plus
`test_input_line_inject_1352` (`B1..B18`), `test_preview_name_inject_1601` (the long `B/P` line) and
`test_generator_paren_1604` (`D1..D5`) — **none belongs to this suite.** `cases=100 blocks=99 skips=8`
is unchanged from C2's and C2v's runs: this stage adds a row, not a case. The 1608 block:

```
headless/test_snprintf_fmt_1608.log
RESULT: ALL PASS (34 checks)
Total num fail: 0
```

⚠ **And T1's 1608 block was read from the FINAL file.** Two comment-only edits to the suite (tidying
L6, moving L9 after L8) landed at 20:54:27 by `os.replace` — atomic, so no torn read was possible —
and `grep -c snprintf_fmt_1608 results.2975965.log` was **0** immediately before that replace and 1
afterwards, so the case had not started when the file changed. The three arms were then **re-run
against the final file after T1 finished**, all three `RESULT: ALL PASS (34 checks)`, `1/1 runs passed`
(throwaway homes 3049356 / 3049817 / 3050280), with `devdisplay.sh status` still reporting
`xvfb: 3979908`.

---

## 8. Instruments, what I could not measure, hygiene

**Instruments.** (1) Two single-conditional removals of the `if(!refuse)` wrapper, one arm at a time,
each anchored on that arm's `va_arg` so the edit is provably arm-local, through the real suite under an
armed throwaway HOME. (2) My own rebuild of the section-G instrument (the suite's own link stubs, the
tree's `src/util.c` at the build's CFLAGS) for the abort messages and the 50/51/60 boundary. (3)
`gcc -fsyntax-only` over all 40 `src/*.c` with each `-Wformat` flag separately, plus a one-site-reverted
scratch copy and a two-shape probe including the real `src/xschem.h`. (4) A 40-translation-unit object
comparison against copies frozen before my first edit. (5) Twelve citation-checker attacks, ten
simultaneous, plus X1's floor. (6) `nm` on `src/util.o`, and a default-flags `-Wformat-zero-length`
probe on a scratch revert of xinit.c.

**Not measured.** A non-fortified or Windows build (inherited, repeated not dropped). Whether mechanism
(D) is reachable from any LITERAL format. The stack frame against recursion depth. `:0` or the user's
real screen — nothing here needs a display, all three arms are green and the suite emits no `skip:`.
And whether the `%s` arm's own missing gate (named limit L3/L4) should get one: that is a product
question and the product is finished.

**Carried forward, unchanged from C2v.** Cv §4.10's behaviour delta — a `font=` value of 80 or more
characters now emits `style="font-family:;"` where 91bb1bd7 emitted no attribute at all, rc 0 both
ways — is still unfenced and still a **product** question for the driver and the user, not a crew's.

**Hygiene.** Every figure came from a `make -C src` after the edit that produced it, rc asserted before
the suite ran. Restores are **`cp`, never `cp -a`**, followed by another `make -C src`, and the suite
was re-run and `ALL PASS` re-confirmed after every restore. The tree is restored: `src/xschem.tcl`,
`src/Makefile`, `src/parselabel.c` and the six product files I did not edit are all `cmp`-identical to
copies frozen before I started; the only files that differ from what I found are
`src/{util.c,util.h,svgdraw.c}` (comment-only, object-identical), `tests/run_regression.tcl` and
`tests/headless/test_snprintf_fmt_1608.tcl`. `git status --porcelain` is unchanged from what C2v
recorded, plus this receipt. `tclsh tests/headless/issue_stamp.tcl` → `self-test PASSED (180 parser
cases)` / `ISSUE-STAMP: ok (0 problems)`. **No commit.** No `~/.claude/xschem_owed/` access. No
`devdisplay.sh start|stop|view`. No writes in `~/dev/xschem-op-wcard`. No
`/tmp/xschem_emergencysave_*` created or deleted. Scratch confined to `<scratchpad>/final_1608/`.
⚠ Per §6, do not use an `src/xschem` md5 as a build identity anywhere in this batch.
