# C2v — claim audit, issue 1608 (last crew)

One question: **is every sentence this batch ships true, and is every guard fenced?**

Answer: **no on both counts, but narrowly.** The product fix is untouched and provably so at object
level. The suite is green on three arms and T1 is at zero. But **one guard has no row that reddens
on its own removal — in two of the three arms it lives in — and its removal re-opens mechanism (A),
the `__strncpy_chk` abort this whole issue is about.** And **seven shipped sentences are false or
claim more than they deliver**, one of them introduced by the round that was fixing the same
sentence, one of them a universal that my own sabotage refutes, and one inherited from Stage C that
both later crews missed.

Nothing here is a defect in the fix. Nothing here is a reason not to gate. Everything here is
either a missing row or a wrong sentence.

Tree audited: the working tree as C2 left it. Instruments, restoration and hygiene: §8.

---

## 1. THE UNFENCED GUARD — `if(!refuse)` around the `strncpy`, in the `p` and `g/e/f` arms

**Instrument: 36 single removals**, each an exact-text replacement in the working tree, `make -C src`
with rc asserted, the suite under an armed throwaway HOME with **full per-row output** (`bash
tests/headless/test_home.sh --run env -u DISPLAY timeout 120 ./src/xschem --nogui --pipe -q --nolog
--script …`, so I read the `FAIL:` lines and not only `run_suites.sh`'s verdict), restore with
**`cp`** (never `cp -a`), `make -C src`, re-confirm `RESULT: ALL PASS (33 checks)`. **All 36 restored
green**; the harness asserts it and none failed. Harness and raw JSON:
`<scratch>/stageC2v_1608/{sab.py,sab_stream.jsonl,log.<id>.txt}`.

I enumerated the removals from the diff itself — `git diff src/util.c | grep -vE '^[-+] \*'` — so the
list is every 1608 code edit in the three files, not the four Cv happened to find. **Consequence** was
then measured with my own fork-per-case driver (`<scratch>/stageC2v_1608/drv/drv2.c`, the tree's own
`src/util.c` compiled at the build's CFLAGS against the suite's link stubs, cases the suite does not
have: specs of length 50, 51 and 60 through **each** arm, `%n` in each gated arm, and the (E) shapes).

| # | single removal | rows that reddened |
|---|---|---|
| A1 | GUARD 1 `if(len >= nfmtsize) return 0;` | G1, G12 |
| A2 | GUARD 3's digit-run cap `if(run < 1000000)` | G13 |
| A3 | `if(run > max) max = run;` | G6, G9, G12, G13 |
| A4 | GUARD 2's flags/`.` permit line | G1, G7, G10 |
| A5 | GUARD 2's `l`/`h` permit line | G5 |
| A6 | GUARD 2's `else return 0;` → `else continue;` | G2, G3, G4, G9, G12 |
| A7 | GUARD 3 `return max + 320 < nstrsize;` → `return 1;` | G6, G9, G12, G13 |
| A8 | the scan loop never entered (`i + 1 < len` → `i < 1`) | G2, G3, G4, G6, G9, G12, G13 |
| A9 | the digit `while` bound `i + 1 < len` → `i < len` | **NOTHING** (provably inert, below) |
| A10 | `MY_SNPRINTF_NSTR` 512 → 50 | F3, F4b, G1, G5, G7, G10, G11 |
| B_d/B_p/B_g | the gate CALL, one arm at a time → `refuse = 0` | d: G1 G2 G4 G6 G9 G13 · **p: G12 only** · g: G3 G6 |
| **C_d** | **the `if(!refuse)` wrapper round the strncpy, d arm** | **G1 only** |
| **C_p** | **the `if(!refuse)` wrapper round the strncpy, `p` arm** | **NOTHING** |
| **C_g** | **the `if(!refuse)` wrapper round the strncpy, `g/e/f` arm** | **NOTHING** |
| D_d/D_p/D_g | `if(refuse) { overflow = 1; break; }`, one arm at a time | d: G1 G2 G4 G6 G9 G13 · p: G12 · g: G3 G4 G6 G9 |
| E_s/E_d/E_p/E_g | (D)'s `>=` back to `>`, one arm at a time | G8, G14 (each arm) |
| F_all4 / F_s / F_d / F_p / F_g | the (D) refusal's `if(n < size) string[n] = '\0'` | G14 (all four together, and each arm alone) |
| H | the added `overflow = 1;` in the two formerly bare-break arms | NOTHING (the documented inert one) |
| I | the refusal moved BEFORE the prefix write (Stage B's shape) | G1, G2, G4, G6, G9, G13 |
| S×4 | svgdraw.c's four `"%s"` sites, one at a time | sym/svg_font_name: **F4b** W1 P1 · sym/textfont: **F3** W1 P1 · draw/svg_font_name: **F4** W1 P1 · draw/textfont: **F1 F2** W1 P1 |
| X_rcfile | xinit.c's `--rcfile` `"%s"` | F6, F7, F8, W1, P1 |
| X_oldwin | `old_win_path[0] = '\0'` → `my_snprintf(…, "")` | W1 |

### 1.1 What `C_p` and `C_g` actually do — measured, not argued

`refuse` does **two** things: it skips `strncpy(nfmt, fmt, l); nfmt[l] = '\0';`, and it breaks after
the prefix write. **Only the break is observable to the G rows** (`g_refused` is `rc 0 && sig 0 &&
ret 0 && len 0`), and no G case drives a spec of 51 characters or more through the `p` or the
`g/e/f` arm — `G1`'s 49/51/202-character dash specs all go through the **d** arm, and `G12`'s
longest `p` spec is exactly **50**, which is the silent one. So the half of the fix that actually
prevents the out-of-bounds write is unfenced in two arms.

Driven through my driver, one arm's wrapper removed at a time (spec length in parentheses):

```
if(!refuse) removed in the p arm:      p51 (51) DIED sig 6   *** buffer overflow detected ***
                                       p60 (60) DIED sig 6   *** buffer overflow detected ***
                                       p50 (50) ret 0 len 0  (the SILENT one-byte-past store)
   suite:  RESULT: ALL PASS (33 checks)

if(!refuse) removed in the g/e/f arm:  g51 g60 f60 e60  ALL DIED sig 6  *** buffer overflow … ***
   suite:  RESULT: ALL PASS (33 checks)

if(!refuse) removed in the d arm:      d51 d60 x60 u60 c60 ALL DIED sig 6
   suite:  RESULT: 1 FAILED (32 passed)   FAIL: G1
```

That is **mechanism (A)** — `__strncpy_chk` on `char nfmt[50]` — back in the tree, from a
single-conditional edit that restores exactly the pre-1608 shape (`strncpy` was unconditional at
`91bb1bd7`), with the suite `ALL PASS`. It is the most plausible refactor there is: "we break right
after, so the copy is harmless".

**I did not fix it.** Per the standing instruction the product is finished, and this needs a row, not
a product change: two `p`/`g` cases at spec length 51 in the existing section-G driver would close it
(the driver already has the `'@'` marker for a `p` dash-run, and `g_refused` would have to be joined
by an assertion that the case did not DIE — which `g_ok` already provides, so the cases alone
suffice). **Carried forward for the driver.**

### 1.2 The one removal that reddens nothing and correctly has no row — plus a second of that class

`H` (the `overflow = 1` uniformity) is the documented inert one. **`A9` is a second**, and it is not
written down anywhere: changing the digit loop's bound from `i + 1 < len` to `i < len` reddens
nothing and **cannot** change an observable — the loop advances only while `spec[i]` is a digit, and
`spec[len-1]` is the conversion letter, which the four arms restrict to `s d x c u p g e f`, never a
digit. So the two spellings consume the same digits and leave `i` at the same place. Recorded so the
next crew does not file it as a sixth unfenced guard.

### 1.3 Everything else in the three files is fenced

`src/svgdraw.c` has exactly four 1608 code edits and `src/xinit.c` exactly two (`git diff` with
comment lines filtered); each reddens on its own removal, and **the site→row map C2 shipped in
`svgdraw.c` is exactly right** — I re-drove all four one at a time (table above). The other four
touched files (`draw.c`, `save.c`, `token.c`, `scheduler.c`) are comment-only except scheduler.c's
deleted dead `#ifdef HAS_SNPRINTF` block, which `S2` fences.

---

## 2. THE CITATION CHECKER — twelve attacks, six caught, six missed

Ten attacks were planted **simultaneously**, each with a unique fabricated id so the `unknown={…}`
list attributes every outcome to exactly one attack (`<scratch>/stageC2v_1608/x1attack.py`); the
range attack was run separately.

| attack | shape | verdict |
|---|---|---|
| `Q9` | inside a `/* … */` block comment in `src/util.c` | **CAUGHT** |
| `Q8` | inside a **C string literal** (`static const char zz1608_cite[] = "rows Q8 of …"`) | **CAUGHT** |
| `Q2` | inside a `#if 0` region | **CAUGHT** |
| `V27` | an id that **exists in a different suite** (`Row V27`, real in `test_ps_valid_1350.tcl`), cited as ours | **CAUGHT** |
| `Q7` | in a **`.tcl`** file, not a `.c` (`src/xschem.tcl`) | **CAUGHT** |
| `F4-F6` | a **range whose endpoints exist and whose middle does not** (row `F5` renamed to `F5z`) | **CAUGHT** — `util.c: cites F5 (in "F4-F6") -- no such row`, and the rename also reddened `svgdraw.c`'s real citation of F5, i.e. both directions |
| `q7b` | **lowercase** id (`row q7b`) | missed — the id shape `[A-Z]…` is stated in the row's own comment, so disclosed |
| `Q6` | **hyphenated** keyword (`row-Q6`) | missed — `[Rr]ows?[ ]+` needs whitespace; implied, not stated |
| `Q1` | id in **backticks** (``rows `Q1` of …``) | missed — **not named anywhere**, and this repo writes ids in backticks constantly |
| `Q5` | rule-3 **misattribution**: a bare `row Q5` after a *different* suite's file name in the same comment | missed — rule 3 is declared a heuristic in `L7`, and this is exactly its failure mode |
| `Q3` | the **file name itself split** across two comment lines (`test_snprintf_` / `fmt_1608.tcl`) | missed — named in `L7` |
| `Q4` | a file with **no extension** (`src/Makefile`) | missed — the extension list is stated in the row's scope comment |

Verbatim, the ten-attack run:

```
FAIL: X1 … (unknown={{svgdraw.c: cites V27 (in "V27") -- no such row}
{util.c: cites Q8 (in "Q8") -- no such row} {util.c: cites Q2 (in "Q2") -- no such row}
{util.c: cites Q9 (in "Q9") -- no such row} {xschem.tcl: cites Q7 (in "Q7") -- no such row}}
citations=18 files={parselabel.c parselabel.l svgdraw.c util.c util.h xinit.c xschem.tcl}
other_suites=22 unattributed={} rows_known=33 gwp_rows_missing={} suite=test_snprintf_fmt_1608.tcl)
RESULT: 1 FAILED (32 passed)
```

**Verdict on the checker: it holds where it matters.** Every attack that hides a citation in text the
compiler ignores — comment, string literal, `#if 0` — is caught, because it scans the text and not
the compiled program; an id belonging to another suite is caught; a range's middle is caught; and a
`.tcl` file is in scope. Of the six misses, four are disclosed by the row's own comment or `L7`. The
**two worth recording** are the backticked id (latent: no such citation exists today, `citations=13`
before any plant) and rule-3 misattribution (named as a heuristic, and now measured). Neither is a
reason to hold the gate; both belong in `L7` if anyone touches the row again.

One more measured fact about the checker's floor: `citations=13 files=6 other_suites=3` on the clean
tree, matching C2's figure digit for digit, and `citations=0 files={}` is a red (C2 drove that) —
so it is not vacuous.

---

## 3. FALSE OR OVER-CLAIMING SENTENCES THAT STILL SHIP

### 3.1 ⚠ `#pragma` — the sentence that was rewritten to fix this exact error is wrong again

`src/util.c` (spec-gate comment) and the suite's `W1` comment both say:

> the only textual `#pragma` in src/ is this sentence, which is why
> `/usr/bin/grep -rc '#pragma' src/*.c src/*.h` **sums to 1 and not 0**

Measured, on the tree as C2 left it:

```
$ /usr/bin/grep -rc '#pragma' src/*.c src/*.h | awk -F: '{s+=$2} END{print s}'
3
$ /usr/bin/grep -rn '#pragma' src/*.c src/*.h
src/util.c:755: * tree emits five. A tree-wide zero would need a real `#pragma GCC diagnostic` at five sites,
src/util.c:756: * and this tree has no such directive anywhere -- the only textual `#pragma` in src/ is this
src/util.c:757: * sentence, which is why `/usr/bin/grep -rc '#pragma' src/*.c src/*.h` sums to 1 and not 0 --
```

`grep -c` counts **lines**, and the rewrite spread the word `#pragma` over **three** lines of the
same sentence. Stage C said 0 and the answer was 1; C2 said 1 and the answer is 3. The *substance*
("no such directive anywhere") is true and `grep -rln` finds only `util.c` — it is the quoted command
output that is wrong, in two shipped files. **Round seven of the same class.**

### 3.2 ⚠ `src/util.h`: "THE FLAG THAT NAMES THESE FIVE SITES IS `-Wformat-security`"

The paragraph reads, in order: *"the clean tree emits **five**, at the three `sprintf(nstr, nfmt, i)`
calls inside my_snprintf() and draw.c's two `sprintf(tmpstr, fmt1/fmt2, …)`"* … then *"⚠ AND THE FLAG
THAT NAMES **THESE FIVE SITES** IS `-Wformat-security`, not `-Wformat-nonliteral`: **all five are
ZERO-ARGUMENT calls**"*.

The only antecedent for "these five sites" in that paragraph is the five diagnostics just enumerated,
and of them the claim is **false in both halves**. Measured over all 40 `src/*.c` at the build's own
CFLAGS:

```
-Wformat -Wformat-nonliteral :  draw.c:5309, draw.c:5310, util.c:856, util.c:887, util.c:918
                                — five, all [-Wformat-nonliteral]
-Wformat -Wformat-security   :  (nothing at all)
-Wformat                     :  (nothing at all)
```

and with one real `my_snprintf` site reverted (the intended five):

```
-Wformat -Wformat-nonliteral :  svgdraw.c:1430 … [-Wformat-security]
-Wformat -Wformat-security   :  svgdraw.c:1430 … [-Wformat-security]
```

So: the five clean-tree diagnostics carry an argument and are named by `-Wformat-nonliteral`;
`-Wformat-security` names **none** of them. The engineering point C2 meant — that the five
*my_snprintf call sites* are zero-argument and are named by `-Wformat-security` — is correct and the
**issue file states it correctly** ("For the five sites 1608 is about — all of them zero-argument
calls"). It is `util.h`'s wording that puts the right claim on the wrong five.

### 3.3 The suite's section S: "`HAS_SNPRINTF` eight times" — it is seven

> src/util.c's replacement comment spells `#ifdef HAS_SNPRINTF` **twice** and `HAS_SNPRINTF`
> **eight times** on purpose

Measured inside that comment (`src/util.c` 623–666): `#ifdef HAS_SNPRINTF` **2** ✓, `HAS_SNPRINTF`
**7** ✗. Whole-file figures, for completeness: 9 occurrences on 9 lines, 3 of them `#ifdef
HAS_SNPRINTF` (the third is an older, unrelated comment at line 494). **Inherited from Stage C** —
the sentence is byte-identical in Cv's pristine copy — so this one was missed by the sabotage crew
*and* by the claim-fixing crew. It is a count, in a file whose own named limit `L1` says no row here
claims a count.

### 3.4 Row `G12`'s name claims an assertion the row does not make

> `%np`, `%-2000p`, `%.191Lp`, `%*p` and a 50-character `%<48 dashes>p` are ALL refused by the `p`
> arm, **with no signal and an intact canary**

`G12`'s expression is `g_refused` five times, and `g_refused` is `g_ok && ret == 0 && len == 0`;
`g_ok` is `rc == 0 && sig == 0`. **The canary is index 3 of the driver's tuple and only `G8` reads it
(`g_can`).** `/usr/bin/grep -n 'g_can' tests/headless/test_snprintf_fmt_1608.tcl` returns the proc and
`G8` alone. So "no signal" is asserted and "an intact canary" is **reported in the detail and not
asserted** — the row would pass with a clobbered canary. C2's own receipt repeats the error in
stronger form: *"Asserts that … are ALL refused by the `p` arm (rc 0, sig 0, ret 0, len 0, canary
intact)"*. Same class as Cv's finding 10 against `P3`'s first name.

### 3.5 The suite's new per-row table puts `F9` in the wrong group

Section F's replacement table (C2's fix for "⚠ EVERY ROW HERE ASSERTS THE VALUE REACHED THE OUTPUT
VERBATIM") reads:

> `F6, F7, F8, F9` — the value came back VERBATIM in `cannot find <value>`

`F9`'s fixture is a `--rcfile` naming a file that **exists**; nothing prints `cannot find`, and the
row asserts `$f9rc == 0 && !$f9death && [string first {SOURCED=<1>} $f9out] >= 0`. The same header
says nine lines later that "F5 and F9 are the controls", and F9's own name is honest. So the table
that replaced a false sentence about every row contains a false sentence about one row.

### 3.6 `src/svgdraw.c`: "ONE ROW PER SITE because no one fixture reaches two of them"

Measured false, on the pre-fix binary built from `91bb1bd7` for exactly this purpose. In one fixture
of `F3`'s shape — a `.sch` carrying its own text **and** an instance whose `.sym` carries a text —
**both** `textfont` sites execute:

```
binary: 91bb1bd7 (from-scratch clone)
  symfont=Monospace  schfont=%nd        rc=134  *** %n in writable segments detected ***
  symfont=%nd        schfont=Monospace  rc=134  *** %n in writable segments detected ***
  symfont=plainsch   schfont=%nd        rc=134  *** %n in writable segments detected ***
binary: the shipped tree
  all three                             rc=0    SVG-OK
```

`F3`'s own fixture is the second line (`.sym` `font=%nd`, `.sch` `font=plainsch`): the schematic-text
loop in `svg_draw()` runs and calls the `textfont` site with `plainsch` — harmless, therefore
invisible. The true reason one row per site is needed is **attribution, not reachability**: no fixture
lets a row say which site produced the output unless the others are neutralised — which is exactly
what `F4b`'s own comment explains at length and states correctly. (Measured aside: in that fixture
only the symbol text reaches the export at all — one `<text>`, `style="font-family:%nd;"` — so the
schematic text's value is not merely harmless, it is absent from the output.)

### 3.7 The suite header's universal: "Every guard reddens on its own single removal"

Refuted by §1: the `if(!refuse)` wrapper in the `p` arm and in the `g/e/f` arm. The sentence goes on
to name one deliberate exception (the `overflow = 1` uniformity, "behaviourally dead"), which makes
it a closed universal claim with one stated exception — and there are now **three** items outside it
(§1.1 and §1.2), one of which is consequential.

### 3.8 A correction to Cv and C2's own list: item 16 is not false in the suite's units

Cv item 16 and C2's table item 16 record Stage C's *"9 raw hits in util.c, **4** in scheduler.c"* as
false, "scheduler.c is 3". Measured: `/usr/bin/grep -c` (lines) gives **3**, `grep -o | wc -l`
(occurrences) gives **4** — and the suite's own instrument is `regexp -all`, i.e. occurrences, with
row `S2` printing `raw_hits=4` on this very tree (`(live_hits=0 raw_hits=4 src=804080B)`). So Stage C's
figure is right in the units the suite uses and Cv's refutation counted lines. One of the
twenty-one was not a false claim.

### 3.9 Minor, recorded without ceremony

The section-X comment listing the five historical mis-citations says *"svgdraw's are F1-F5"*;
svgdraw's rows are F1, F2, F3, F4, **F4b** and F5, as `svgdraw.c`'s own comment and the fence map both
say. `P2`'s name says "no LITERAL conversion spec anywhere in the compiled tree is refused by any of
my_snprintf_spec_ok()'s three guards" while `%s`-arm specs are deliberately not submitted to
`cens_verdict` — true, because that arm has no gate, but the word "anywhere" covers specs the row
does not test.

---

## 4. CLAIMS I RE-DROVE AND CONFIRMED

Every figure below was measured by me on this tree (or on a from-scratch `91bb1bd7` clone for the
"before" ones), not copied from a receipt.

* **The grouping-locale figures** (`src/util.c` GUARD 2 and row `G4`'s name), with a locale built by
  `localedef -i en_US -f UTF-8` into a scratch `LOCPATH` because this box has no `en_US.UTF-8`:
  `%'.0f` of −DBL_MAX = **412**, `%'.6f` = **419**, `%'.180f` = **593**, and the breakdown the comment
  writes out — `total=412 sign=1 digits=309 separators=102` — is what the program prints.
* **GUARD 3's arithmetic** (`G6`, `G7`, the GUARD 3 comment): `%.192f` = **503**, `%.191f` = **502**,
  `%f` = **317**, `%.200f` = **511**, `%.60g` = **67**, `%.0Lf` of LDBL_MAX = **4933**. So `%.192f` is
  refused by the over-estimate and not by capacity, exactly as the comment now says.
* **"five live sites consume it as a length"** (GUARD 3 comment, `G13`'s name): `my_itoa()`,
  `dtoa()` (util.c) and `dtoa_prec()` (editprop.c) all assign it to `xctx->tok_size`, plus
  `off += my_snprintf(…)` in hilight.c and `result_pos += my_snprintf(…)` in token.c. **Five.**
* **The (E)/(D) boundary** (`L8`, issue "Still open 5", the PREFIX_GUARD comment): on the shipped tree
  `my_snprintf(u, 2, "abcd%d", 7)` → `ret 0`, buffer `""` (written); `my_snprintf(u, 2, "abcd")` →
  `ret 0`, buffer **untouched, 4095 canary bytes intact**. With the four NUL writes removed, all four
  conversion shapes go back to untouched. Both directions as claimed.
* **`L6`, driven with gcc off a sanitised PATH**: **two** lowercase `skip:` lines (the first naming
  the **19** G/W/P rows, which is `gwp_rows` exactly; the second naming `S3`), `RESULT: ALL PASS (13
  checks)`, `OVERALL: ok (13 checks)`, and `X1` still runs and passes with `rows_known=33`. Neither
  skip line ends in `FAIL`/`GOLD?`/`RESULT?`.
* **The `91bb1bd7` shapes**, on a from-scratch clone I built for this audit (`git clone
  --no-hardlinks` → `./configure` → `make -C src`, HEAD `91bb1bd7`):

```
--rcfile, 3 runs each          speclen 49 -> rc 1  "cannot find 32" / "56" / "0"
                               speclen 50 -> rc 1  "cannot find 96" / "0"  / "8"
                               speclen 51 -> rc 134  *** buffer overflow detected ***
                               speclen 60 -> rc 134  *** buffer overflow detected ***
--rcfile '%s'                  rc 139
.sch font=%nd                  rc 134  *** %n in writable segments detected ***
.sch font=%-2000d              rc 134  *** buffer overflow detected ***
.sch font=%.192f               rc 134  *** buffer overflow detected ***
.sch font=Monospace            rc 0    SVG-OK
.sym font=%nd via an instance  rc 134  *** %n in writable segments detected ***
```

  The **shape** in GUARD 1's comment reproduces exactly, and my six runs at length 49/50 printed
  **32, 56, 0, 96, 0, 8** — not one of C2's `32, 112, 24`, which is precisely why that comment quotes
  no number and says the integer is stack garbage. The decision not to quote one is vindicated.
* **`W1`'s five diagnostics** and their sites: `draw.c:5309`, `draw.c:5310`, `util.c:856`,
  `util.c:887`, `util.c:918` — the two `sprintf(tmpstr, fmt1/fmt2, …)` and the three
  `sprintf(nstr, nfmt, i)`, which is what `W1` permits by text.
* **`L3` and issue "Still open 1"**: `my_snprintf(b, n, "[%-12s]", "AB")` → `[AB]`, and `"[%12s]"` →
  `[AB]`. The `%s` arm discards its field width, both signs.
* **The `hcases` rationale paragraph's own figures**: 19 G/W/P rows skipped as one line and `S3` as a
  second, 13 checks; `ALL PASS (33 checks)` on all three arms with zero `skip:` lines (§7).
* **`P3`'s new arm floors** are real assertions (`$parm(s) >= 1 && $parm(i) >= 1 && $parm(f) >= 1`),
  the `p` count is reported only, and `cens_calls` really does require three arguments
  (`if {!$closed || [llength $args] < 3} continue`) — so "call expressions with at least three
  arguments" is honest.

---

## 5. THE DOORS — eight families, 37 runs, every one still closed

Re-driven on the shipped binary, armed throwaway HOME, `env -u DISPLAY`, `timeout 60` on every run
(`<scratch>/stageC2v_1608/doors.sh`, full log `doors.log`). More than the six asked for, and both
required ones are in.

| door | specs driven | result |
|---|---|---|
| `.sch` text `font=` → `print svg` | `%nd %-2000d %n %.192f %*d %zd` + `Monospace` | 7 runs, **rc 0**, value verbatim in `font-family` |
| **`.sym` text `font=` through an instance** (required) | `%nd %-2000d %.0Lf %s` + `Monospace` | 5 runs, **rc 0**, verbatim |
| `svg_font_name` via `--script` and via `--preinit`, with an instance | `%nd %-2000d` | 4 runs, **rc 0**, `FNAME=<%nd>` round-tripped, CSS rule `text {font-family: %nd;}` |
| `--rcfile` | `%s %nd %-2000d %.192f zz%*d` | 5 runs, **rc 1**, `cannot find <the string typed>` verbatim |
| other back ends: `print ps`/`pdf`/`png`/`tedax`, `xschem netlist` | ×2 specs | 10 runs, **rc 0**, `DONE-OK` |
| **a symbol GENERATOR** (required): executable `gen.tcl` emitting `font=%nd`, instantiated `C {gen.tcl(1)}` | `%nd` | **rc 0**, `GENTXT` in the export, `font-family:%nd` |
| `tcl_hook2`: `font=tcleval(%nd)` | `%nd` | **rc 0**, hook ran, `font-family:%nd` |
| symbol/instance attributes: `format=`, `template=`, instance `name=`, symbol text body | `%nd %-2000d`, through `print svg` **and** `netlist` | 2 runs, **rc 0** |

Zero deaths, zero signals, no `FATAL:` marker anywhere, and the only non-zero rc is the `--rcfile`
door's intended `1`.

---

## 6. NO PRODUCT BEHAVIOUR CHANGED — proven at object level, for the whole program

C2 proved it with `gcc -E -P` on three files. I did it the way the task asked, with the
`__DATE__`/`__TIME__` caveat handled.

Baseline: Cv's own pre-C2 frozen copies (`<scratch>/stageCv_1608/pristine/`), which are the landed
Stage C versions. First, they are a valid baseline: the four files C2 did not claim to touch
(`draw.c`, `save.c`, `scheduler.c`, `token.c`) are `cmp`-identical between that copy and the tree, so
C2's edits are confined to the five files it names.

Then two build trees (`objA` = the tree as it stands, `objB` = the same with `util.c`, `util.h`,
`svgdraw.c`, `xinit.c`, `parselabel.l` replaced by the Stage C versions; `parselabel.c` regenerated
in both by the build's own `flex -l`), all 40 translation units compiled in each at the build's own
CFLAGS:

```
compared=40 differing=1
DIFFERS: scheduler.oo
$ cmp -l objA/scheduler.oo objB/scheduler.oo | wc -l
2
  113247  63  64
  113248  60  70
  objA: …9:46:30…   objB: …9:46:48…      <- the seconds field of __TIME__
```

**39 of 40 translation units byte-identical; the 40th differs in the two bytes of
`scheduler.c`'s `__DATE__ " : " __TIME__`.** The four files C2 edited compile to byte-identical
objects (`util.o 9e2049fdb704…`, `svgdraw.o 6f1fee5d8849…`, `xinit.o e9141d7a7e0a…`,
`parselabel.o bb476688e4b4…`), with identical warning text, and each matches the `.o` sitting in
`src/` — so the binary in the tree is built from these sources. `src/parselabel.l`'s change is
entirely inside the dead block's `/* … */`, which I read directly rather than inferring: the
`extern` declarations and the new MEASURED paragraph are all inside one comment.

---

## 7. GATE VERDICT — **I would gate**, with §1.1 and §3 recorded as owed work

Nothing I found is a defect in the fix; five doors stay shut against 37 hostile runs; the unfenced
guard is a missing test row, and the seven sentences are wording. The two things I would not let
pass silently are the `if(!refuse)` wrapper (a single plausible edit puts a `SIGABRT` back with the
suite `ALL PASS`) and §3.1, because it is the *seventh* consecutive round in which this batch has
shipped a false statement and the *second* in which the false statement is inside the sentence that
was rewritten to fix the previous one.

```
$ git status --porcelain
 M doc/claude/issues/NUMBERING.md
 M src/draw.c
 M src/parselabel.l
 M src/save.c
 M src/scheduler.c
 M src/svgdraw.c
 M src/token.c
 M src/util.c
 M src/util.h
 M src/xinit.c
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/issue_1608_batch/
?? doc/claude/issues/1608-my-snprintf-writes-into-two-fixed-50-byte-buffers-and-checks-the-bound-afterwards.md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_snprintf_fmt_1608.tcl

$ git diff --stat
 doc/claude/issues/NUMBERING.md |  24 +++-
 src/draw.c                     |   5 +-
 src/parselabel.l               |  24 +++-
 src/save.c                     |   7 +-
 src/scheduler.c                |   9 +-
 src/svgdraw.c                  |  52 +++++++-
 src/token.c                    |   5 +-
 src/util.c                     | 279 ++++++++++++++++++++++++++++++++++++-----
 src/util.h                     |  27 ++++
 src/xinit.c                    |  19 ++-
 tests/run_regression.tcl       |  32 ++++-
 11 files changed, 432 insertions(+), 51 deletions(-)

$ make -C src
make: Entering directory '/home/analog/dev/xschem-claude/src'
make: Nothing to be done for 'all'.
make: Leaving directory '/home/analog/dev/xschem-claude/src'
```

(`git status --porcelain` and `git diff --stat` are character-identical to what C2 recorded, plus
this receipt.) A full rebuild at the end of the audit — `touch src/*.c src/*.h && make -C src` — exited
**0** with exactly **six** warnings, all `[-Wdiscarded-qualifiers]`, and zero errors, which is C2's and
Cv's figure reproduced; `src/{util,svgdraw,xinit,parselabel}.o` are `cmp`-identical to the objects I
built from these sources, and the suite is `ALL PASS (33 checks)` after that rebuild.

```
################ ARM 1 -- nogui (DISPLAY unset by the driver) ################
test home: throwaway /tmp/xschem-test-home.2894135.Ae9ql1 (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (33 checks)
RESULT: 1/1 runs passed

################ ARM 2 -- display (dev display :99 via devdisplay.sh exec) ################
test home: throwaway /tmp/xschem-test-home.2894594.FbM0lG (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (33 checks)
RESULT: 1/1 runs passed

################ ARM 3 -- no dev display reachable (private Xvfb) ################
test home: throwaway /tmp/xschem-test-home.2895122.cbCjkU (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: private Xvfb from :200 up, screen 1920x1080x24, wm openbox, GUI_GATE=0
             (AUDIT_DISPLAY=:0 to use the real screen, =none to skip GUI legs)
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (33 checks)
RESULT: 1/1 runs passed
```

Arm 3 pointed `XSCHEM_DEVDISPLAY_DIR` at an empty read-only directory; `devdisplay.sh status`
reported the same `xvfb: 3979908` before and after, and `start|stop|view` was never run. Zero `skip:`
lines on all three arms.

**T1 solo**, my own run, `tests/results.2895963.log`:

```
T1-RUN-BEGIN pid=2895963 script=run_regression.tcl start=2026-09-26 20:09:32 planned_cases=100 verdict=results.2895963.log home=throwaway binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
T1-RUN-END pid=2895963 cases=100 blocks=99 counted_failures=0 skips=8 elapsed=592s end=2026-09-26 20:19:24
```

`wc -l` **299**. Counted shapes (`grep -cE 'FAIL$|GOLD\?$|RESULT\?$|^FATAL'`) **0**. Zero
`another regression run is live` lines (solo; no `results.<pid>.log` had a live `/proc/<pid>` when it
started). The eight `skip:` lines are the baseline eight and none belongs to this suite. The 1608
block: `RESULT: ALL PASS (33 checks)` / `Total num fail: 0`.

---

## 8. INSTRUMENTS, WHAT I COULD NOT MEASURE, AND HYGIENE

**Instruments.** (1) 36 single removals through the real suite with per-row output. (2) My own
fork-per-case driver over the tree's own `src/util.c` at the build's CFLAGS against the suite's link
stubs, with cases the suite lacks (spec lengths 50/51/60 in **every** arm, `%n` per arm, the (E)
shapes, the digit-run cap). (3) `gcc -fsyntax-only` over all 40 `src/*.c` with each `-Wformat` flag
separately. (4) 40-translation-unit object comparison against Cv's pre-C2 frozen copies. (5) A
from-scratch `91bb1bd7` clone, configured and built, for every "at 91bb1bd7" sentence I quote. (6) A
locale built with `localedef` for the grouping figures. (7) A PATH with 3198 symlinks and no `gcc`,
for `L6`. (8) Twelve citation-checker attacks.

**Not measured.** A non-fortified or Windows build (inherited, repeated not dropped). Whether
mechanism (D) is reachable from any LITERAL format — still needs each call site's destination size
against its longest literal run, and `S(x)` is `sizeof(x)`, which no text census resolves. The stack
frame against recursion depth. `:0` or the user's real screen: nothing here needs a display, all
three arms are green and the suite emits no `skip:`. Whether Cv's §4.10 behaviour delta (a `font=`
value of 80+ characters now emitting `style="font-family:;"` where `91bb1bd7` emitted no attribute)
should change — it is a product question, it is still unfenced, and C2 is right to have put it in
front of the driver rather than deciding it.

**Hygiene.** Every figure came from a `make -C src` after the edit that produced it, rc asserted
before the suite ran. Restores are `cp`, never `cp -a`, followed by another `make -C src`; the
harness re-ran the suite after every restore and asserted `ALL PASS (33 checks)` — all 36 did. The
tree is restored: `src/{util.c,util.h,svgdraw.c,xinit.c,parselabel.l,draw.c,save.c,scheduler.c,token.c}`,
`tests/headless/test_snprintf_fmt_1608.tcl`, `tests/run_regression.tcl`, `Makefile.conf` and
`src/Makefile` all `cmp`-identical to copies frozen before I started, `src/xschem.tcl` restored from
git. **No product file was edited except as a sabotage that was restored and rebuilt.** No commit.
No `~/.claude/xschem_owed/` access. No `devdisplay.sh start|stop|view`. No writes in
`~/dev/xschem-op-wcard`. No `/tmp/xschem_emergencysave_*` created or deleted. Scratch confined to
`<scratchpad>/stageC2v_1608/`, including the `91bb1bd7` comparison clone (`before91/`), so nothing of
mine is in `/tmp` or the repo. `tclsh tests/headless/issue_stamp.tcl` → `self-test PASSED (180 parser
cases)` / `ISSUE-STAMP: ok (0 problems)`.

**Carried forward for the driver, in priority order.**
1. The `if(!refuse)` wrapper has no row in the `p` and `g/e/f` arms; two driver cases at spec length
   51 would close it (§1.1). It is a test gap, not a product defect.
2. Seven shipped sentences to correct (§3.1–§3.7), and one entry of the twenty-one to un-record
   (§3.8). §3.1 is in two files.
3. Cv §4.10's 80-character `font=` behaviour delta is still unfenced and still a product question.
