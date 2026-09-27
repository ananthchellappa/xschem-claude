# C2 — close the gaps Cv found: four rows, one checker, twenty-one claims, one dead declaration

Stage C2. **No product behaviour changed.** Every edit to `src/` in this stage is inside a comment,
and that is proven rather than asserted (§6). The work is five new rows
(`F4b`, `G12`, `G13`, `G14`, `X1`), one re-pointed row (`S3`), three row names that claimed coverage
they did not have (`F4`, `P3`, `W2`), two row names that carried a wrong figure (`G4`, `G6`), one row
comment that claimed a power the row does not have (`P2`), the suite header and fence map, five wrong
row citations in shipped source comments, and four corrections to the issue file.

`tests/headless/test_snprintf_fmt_1608.tcl`: **28 → 33 checks**, `ALL PASS` on all three arms,
zero `skip:` lines. Every row whose ASSERTION is new or changed was sabotaged here and the verbatim
failing line is below — the five new rows, `S3`, `P3` and `W2`. ⚠ `G4` and `G6` changed only their
NAMES (a wrong figure), so their assertions are untouched and I did **not** re-drive the GUARD 2 /
GUARD 3 removals that redden them; Cv's matrix has those, and the figures inside the new names were
re-measured by me (§4). `F3` and `F4` also changed only their names, but there I re-drove their
sabotages anyway, because the new names make a claim about which site reddens which row.

---

## 1. T1 — the four guards that reddened nothing now each have a row

All four consequences were driven by Cv; I did not re-derive them, I fenced them. Every sabotage
below is a single exact-text removal in the working tree, `make -C src` with rc asserted, the
suite under an armed throwaway HOME, restore with **`cp`** (never `cp -a`), `make -C src`,
re-confirm `RESULT: ALL PASS (33 checks)`. **All 15 sabotages in this stage restored green**; the
harness asserts it and none failed. Harness and raw JSON:
`<scratchpad>/stageC2_1608/{sab.py,res1.json,res2.json,res3.json,res4.json}`.

| sabotage | reddened | restore |
|---|---|---|
| T1a  `p` arm's `refuse = !my_snprintf_spec_ok(...)` → `refuse = 0` | **G12** only | `ALL PASS (33 checks)` |
| T1b  GUARD 3's `if(run < 1000000)` removed | **G13** only | `ALL PASS (33 checks)` |
| T1c  the (D) refusal's `if(n < size) string[n] = '\0'` removed in all four arms | **G14** only | `ALL PASS (33 checks)` |
| T1d  `svg_draw_symbol`'s `svg_font_name` site reverted | **F4b**, W1, P1 | `ALL PASS (33 checks)` |

And the two pre-existing site rows whose names this stage rewrote, re-driven so the new wording is
measured and not inherited:

| sabotage | reddened | restore |
|---|---|---|
| `svg_draw`'s `svg_font_name` site reverted (the claim in F4's new name) | **F4**, W1, P1 | `ALL PASS (33 checks)` |
| `svg_draw_symbol`'s `textfont` site reverted (the site map's F3 entry) | **F3**, W1, P1 | `ALL PASS (33 checks)` |

```
FAIL: F4 (1608) svg_draw()'s `svg_font_name` site -- the THIRD of the four svgdraw.c sites. …
Reverting THIS site leaves svg_font_family empty, the comparison differs, and an empty
`style="font-family:;"` appears instead. … (rc=0 death=0 per_text_attrs=1 want=0 text_elements=1
css={{text {font-family: %-2000d;}}})
FAIL: F3 (1608) the `font=` attribute of a text object inside a .sym, reached through an instance --
svg_draw_symbol()'s `textfont` site, a DIFFERENT one of the four from F1/F2. A stranger's SYMBOL
LIBRARY is the door here, not their schematic (rc=0 death=0 fams={{} Sans-Serif})
```

### T1a — `G12`, the `p` arm's spec gate (the most serious gap)

⚠ **There is no product door into this arm, and I say so plainly rather than planting one.** `P1`
asserts that zero `my_snprintf` calls in the compiled tree pass a non-literal format, so after the
section F fix no input any test can write makes a shipped caller hand the `p` arm a hostile spec.
The tree's only live `%p` is `src/util.c`'s own pointer trace behind `debug_var > 2`, and its format
is the literal `"%p"` — I checked, and P3's new per-arm census confirms it: **`arm_p=1`**. So the
instrument is section G's existing one: the tree's own `src/util.c`, compiled with the build's own
CFLAGS against link stubs and called directly, one fork per case. **Nothing was added to `src/`.**

Five hostile specs driven through the `p` arm, all refused on the shipped tree
(`ret=0 canary=intact len=0`): `%np`, `%-2000p`, `%.191Lp`, `%*p`, and `%<48 dashes>p` (a
50-character spec, which needed a new `'@'` marker in the driver's spec builder — the existing
`'#'` marker hard-codes a `d` terminator).

Verbatim, with only that arm's gate call removed:

```
FAIL: G12 (1608 GUARD 2 and GUARD 1 IN THE `p` ARM) `%np`, `%-2000p`, `%.191Lp`, `%*p` and a
50-character `%<48 dashes>p` are ALL refused by the `p` arm, with no signal and an intact canary.
The other G rows drive the d/x/c/u and g/e/f arms; before this row the `p` arm's gate call could be
deleted on its own and every row here stayed green while `%np` died `*** %n in writable segments
detected ***`. Its companion is G10's `x=%p`, which says the arm still formats an ordinary pointer
(pct_n={-1 6 - - - DIED} w2000={-1 6 - - - DIED} L={0 0 0 intact 0 {}} star={0 0 0 intact 0 {}}
len50={0 0 4 intact 4 0x58})
```

`RESULT: 1 FAILED (32 passed)` — G12 the only red, so all 28 pre-existing rows were in that 32,
which reproduces Cv's "all 28 stayed green" from the other side.

⚠ **Two corrections to Cv's §2.1 that only show up at this granularity.** Cv reports `%.191Lp` and
`%*p` as `DIED sig=6` with the gate removed. Driven here through the `p` arm with a pushed `void *`
they do **not** die: both give `ret=0 len=0`, i.e. glibc formats nothing and returns 0. And
`%<48 dashes>p` does not die either — it **succeeds**, `ret=4`, output `0x58`, which is the
*silent* (B) write: `strncpy` fills `nfmt[50]` and `nfmt[l] = '\0'` stores at index 50, one byte
past, unfortified. The row therefore asserts the REFUSAL and never the abort, and the two
discriminators that carry it are the two deaths plus that `ret=4`.

### T1b — `G13`, GUARD 3's digit-run overflow cap

Two 22-character specs, both inside GUARD 1's 50 so the cap is the only thing refusing:
`%18446744073709551616d` (2^64, the accumulator wraps to 0) and `%18446744073709551716d`
(2^64 + 100, wraps to 100).

```
FAIL: G13 (1608 GUARD 3's digit-run overflow cap) a 20-digit field width whose value wraps size_t
is REFUSED and returns 0, not a wrapped length. ... (w2_64={0 0 18446744073709551615 intact 0 {}}
w2_64p100={0 0 18446744073709551615 intact 0 {}})
```

⚠ **A third shape I tried is NOT a discriminator and is deliberately not in the row**:
`%99999999999999999999d` is refused either way, because 10^20 − 1 mod 2^64 is 7766279631452241919,
still far past 192. A row built on that shape would have looked like a fence and not been one.

### T1c — `G14`, the (D) refusal's NUL termination

Eight cases: the d, s, g and p arms at `size 2` (destination shorter than the literal run by more
than one) and the same four at `size 4` (`n+l == size` exactly, which is the off-by-one (D) itself
was). `size 0` is excluded on purpose — there is no byte to write, and `D6` already asserts nothing
is written there.

**One line of driver change was needed** and it is the "may need one line" the task anticipated:
`blob[BLOB - 1] = '\0'` after the canary fill, at both fill sites. Without it, reporting
`strlen(blob)` of an *untouched* 4096-byte canary array reads past the array. With it, "untouched"
reports `len 4095` and 40 canary bytes while every shape that writes reports its own short length —
and all six pre-existing (D) cases report exactly what they reported before.

```
FAIL: G14 (1608 the (D) refusal WRITES the terminator) ... (sz2_d={0 0 0 intact 4095 QQQQ…}
sz2_s={0 0 0 intact 4095 QQQQ…} sz2_g={0 0 0 intact 4095 QQQQ…} sz2_p={0 0 0 intact 4095 QQQQ…}
sz4_d={0 0 0 intact 4095 QQQQ…} sz4_s={0 0 0 intact 4095 QQQQ…} sz4_g={0 0 0 intact 4095 QQQQ…}
sz4_p={0 0 0 intact 4095 QQQQ…})
```
(the `QQQQ…` are 40 literal `Q` canary bytes in the real line.)

### T1d — `F4b`, the call site with no behavioural fence

I reproduced Cv's finding first, on the tree as it stood: reverting `svg_draw_symbol`'s
`svg_font_name` site reddened **only W1 and P1** — the compiler's opinion and the preprocessed
census, neither of which runs the binary — while **every behavioural row, F4 included, stayed
green**. (The 28-row suite did redden; what it did not do was redden on anything that had exported an
SVG. Cv's table says the same thing, and I state it this way because "ALL PASS" would be wrong.)
F4's fixture is a `.sch` with no instance, so `svg_draw_symbol()` is never entered in it.

`F4b`'s fixture instantiates a symbol, and two absences in it are load-bearing: the `.sch` carries
**no text of its own** (so `svg_draw()`'s `svg_font_name` site — F4's — never writes
`svg_font_family` in this run, and the value in the output can only have come through the site under
test), and the `.sym` text carries **no `font=`** (so `svg_draw_symbol()`'s other site, F3's
`textfont`, stays out of the way). The observable is F4's: `svg_draw_string()` emits the per-text
`style="font-family:..."` only when `svg_font_family` differs from `svg_font_name`.

```
FAIL: F4b (1608) svg_draw_symbol()'s `svg_font_name` site -- the FOURTH of the four svgdraw.c sites
and the one that had no behavioural row. ... (rc=0 death=0 per_text_attrs=1 want=0 text_elements=1
css={{text {font-family: %-2000d;}}})
```

`F4`'s name no longer claims the site: it now says, with the measurement, that reverting
`svg_draw_symbol`'s site leaves F4 **green** and that F4b is that site.

---

## 2. T2 — row citations are now checked by a row, not by hand

**The deliverable is row `X1`.** Five shipped source comments cited rows that do not exist and I
fixed all five, but the fix for the class is the row.

### What X1 does

* **Scans** every file under `src/` with a source-text extension (`.c .h .l .y .tcl .awk .in .sh
  .md .txt`) that mentions this suite's file name, with C-comment continuation (`\n * `) folded
  away first — `src/xinit.c`'s citation really does straddle it.
* **Matches** `row`/`rows` followed by an id-shaped token, `[A-Z][A-Za-z]{0,2}[0-9]+[A-Za-z]?`, so
  "row 5" and "Row One" are not row ids. Handles `row X`, `rows X-Y` (expanded as a range),
  `rows X/Y/Z`, `rows X, Y and Z` and `<suite> (rows X-Y)`.
* **Derives the set of ids that EXIST** — never a hand list, which would be the same defect one
  level up. `check` records the first token of every row name it is handed; `row_skip` (a new proc,
  the single place a `skip:` line is now written) records the ids of rows that did not run. So a
  renamed row makes its own citation red instead of silently agreeing with itself.
* **Also checks the one list this file does keep by hand**, `gwp_rows` (the rows that need gcc),
  names only rows that ran.

### ⚠ Attribution is the whole difficulty, and my first draft got it wrong

My first draft required the suite name *next to* the row list, in either order. It **missed
`src/svgdraw.c`'s citation entirely** — because I had written the row list one clause away from the
file name — and X1 was green on a tree where a citation went unchecked. Measured, the two naive
rules both fail:

* `src/svgdraw.c` also carries `Row V27 of tests/headless/test_ps_valid_1350.tcl` and
  `Rows A36..A39 of …test_annot_declutter_1244.tcl`, and `src/xinit.c` carries
  `test_startup_guard_0663.tcl (rows SG0-SG21)`. **Checking every `row X` in a file that mentions
  this suite would redden on three correct citations of other suites.**
* `src/util.c` and `src/util.h` refer to `Row G6`, `row G7`, `row G13`, `Row G14` and `Row W2` with
  **no suite name at all**, because the enclosing comment named the suite once already. **Requiring
  the name next to every row list silently skips five real citations of ours.**

So each mention is attributed to a suite, by three rules in order: `rows X of <path>.tcl` →
that path; `<path>.tcl [`] [(] rows X` → that path; otherwise the **nearest preceding `*.tcl` name
in the file**, which is how these comments are actually written. Only this suite's are checked, and
the counts for the other two outcomes (`other_suites=`, `unattributed=`) are in the detail, so an
attribution going wrong is visible rather than silent.

Green detail:

```
ok: X1 … (unknown={} citations=13 files={parselabel.c parselabel.l svgdraw.c util.c util.h xinit.c}
other_suites=3 unattributed={} rows_known=33 gwp_rows_missing={} suite=test_snprintf_fmt_1608.tcl)
```

### Sabotaged three ways, including the two the task required

**A fabricated citation reddens it** — `row Q9 of tests/headless/test_snprintf_fmt_1608.tcl` planted
in a `src/util.c` comment:

```
FAIL: X1 … (unknown={{util.c: cites Q9 (in "Q9") -- no such row}} citations=14
files={parselabel.c parselabel.l svgdraw.c util.c util.h xinit.c} other_suites=3 unattributed={}
rows_known=33 gwp_rows_missing={} suite=test_snprintf_fmt_1608.tcl)
```

**It is not vacuous** — every citation removed from `src/` (the suite name renamed in all six
files) reddens it on the floor, it does not pass silently:

```
FAIL: X1 … (unknown={} citations=0 files={} other_suites=0 unattributed={} rows_known=33
gwp_rows_missing={} suite=test_snprintf_fmt_1608.tcl)
```

**A renamed row reddens it from both directions** — `G13` → `G13z` in the suite, touching neither
`gwp_rows` nor `util.c`'s citation:

```
FAIL: X1 … (unknown={{util.c: cites G13 (in "G1, G2, G3, G4, G6, G7, G12 and G13") -- no such row}
{util.c: cites G13 (in "G13") -- no such row}} citations=13 … gwp_rows_missing={G13} …)
```

### The five citations, fixed

| file | was | is |
|---|---|---|
| `src/util.c` (spec gate) | `row F13` | `row W1` |
| `src/util.c` (PREFIX_GUARD) | `Rows F7-F12` | `Rows G8, G9 and G14` |
| `src/util.h` | `row F13` | `row W1` |
| `src/svgdraw.c` | `rows F1-F6` | `rows F1, F2, F3, F4, F4b and F5`, with the per-site map |
| `src/xinit.c` | `rows F3/F4/F6` | `rows F6, F7 and F8` (F9 the control) |

### Named limits, in the suite as `L7`

X1 sees only `src/`; a bare `row X` in a file that never names this suite is unattributable to it; a
new gcc-dependent row not added to `gwp_rows` is not caught; and a citation whose spelling of the
file NAME is itself split across two comment lines is not matched. Also: `src/parselabel.c` is
**generated and gitignored**, and carries `parselabel.l`'s comment verbatim, so the citation count
is 13 after a build and 12 before one. That is why the assertion is a floor of 3 in 2 files and not
the measured number.

---

## 3. T3 — the twenty-one false statements

Fixed in place wherever the claim ships (source comments, row names, the suite header, the issue
file). ⚠ **Four are receipt-only claims in `C-implement.md`, and I did not rewrite another crew's
dated receipt** — they are corrected here and, where the claim also appears in shipped text, there.
That is deviation 1.

| # | where | old → new |
|---|---|---|
| 1 | `src/util.c` spec gate | `row F13` → `row W1`, plus what W1 actually asserts |
| 2 | `src/util.c` PREFIX_GUARD | `Rows F7-F12` → `Rows G8, G9 and G14`, each named for what it fences |
| 3 | `src/util.h` | `row F13 … fails on ANY diagnostic` → `row W1 … fails on any diagnostic falling on a line that spells my_snprintf(` + "⚠ NOT on any diagnostic at all: the clean tree emits five" + W2 named as its anti-vacuity |
| 4 | `src/svgdraw.c` | `(rows F1-F6)` → `rows F1, F2, F3, F4, F4b and F5`, with the site→row map and a note that F6 is xinit.c's twin |
| 5 | `src/xinit.c` | `rows F3/F4/F6` → `rows F6, F7 and F8 … F9 is their control`, with "(An earlier version cited F3/F4/F6, which are svgdraw.c's rows.)" |
| 6 | `src/util.c` GUARD 2 | `` `%'.0f` of -DBL_MAX measures 419 `` → "MEASURED, against a locale built with `localedef -i en_US -f UTF-8`: `%'.0f` of -DBL_MAX is **412** characters (1 sign + 309 digits + 102 separators), `%'.6f` is **419** and `%'.180f` is **593**", plus an explicit "⚠ The figure 419 belongs to `%'.6f` … an earlier version carried it from a receipt that had DERIVED it ('it would be 419'). Upgrading a derivation into a measurement is what 1606's C5 and C7 forbid." **Re-driven by me**, not taken from Cv: `412 / 419 / 593`, locale built in scratch. |
| 7 | `src/util.c` GUARD 1 | `` printed `cannot find 104` `` → `` printed `cannot find ` followed by a formatted integer `` + "⚠ NO SUCH INTEGER IS QUOTED HERE, DELIBERATELY: it is `va_arg(args, int)` on a vararg nobody pushed … three runs printed 32, 112 and 24. What reproduces exactly is the SHAPE — lengths 49 and 50 give rc 1 with a formatted number, 51 or more gives rc 134." |
| 8 | `src/util.c` GUARD 3 **and** row `G6` | `a precision one past what the scratch holds` → "⚠ THE TWO CASES ARE REFUSED FOR DIFFERENT REASONS: `%-2000d` genuinely overflows; `%.192f` does NOT — `sprintf("%.192f", -DBL_MAX)` is **503** characters and nstr[512] holds it comfortably. It is refused by the OVER-ESTIMATE, because 192 + 320 is 512 and the test is `< 512`." **503 re-measured by me.** |
| 9 | row `F4` name | `the remaining two of the four svgdraw.c sites` / `Reverting either site` → `svg_draw()'s svg_font_name site — the THIRD of the four` / `Reverting THIS site`, plus "⚠ IT DOES NOT COVER svg_draw_symbol()'s svg_font_name SITE, measured … F4b is that site" |
| 10 | row `P3` name | `found at least one conversion in each of the four arms` (nothing tracked arms) → **asserted** for the three arms with many live callers (`arm_s`, `arm_int`, `arm_float` all ≥ 1) and the `p` arm's count **reported, not floored**, because the tree has exactly one live `%p` literal and a floor of one would redden the day someone deletes a debug line. Measured: `arm_s=653 arm_int=356 arm_float=213 arm_p=1`, digit-for-digit Cv's independent census. Sabotaged: blinding the arm classifier gives `FAIL: P3 … arm_s=1223 arm_int=0 arm_float=0 arm_p=0`. |
| 11 | row `W2` name | `a -w/-Wno-format reaches … CFLAGS, this row reddens` → `-w` only, plus "⚠ `-Wno-format` in CFLAGS does NOT redden it, driven: this row appends `-Wformat -Wformat-nonliteral` AFTER CFLAGS … and W1 is not weakened by it either". **Both re-driven by me** (§4). |
| 12 | suite header, section F | `⚠ EVERY ROW HERE ASSERTS THE VALUE REACHED THE OUTPUT VERBATIM` and `Rows F1-F4 therefore assert the value REACHES THE SVG VERBATIM` → `⚠ NO ROW HERE IS SATISFIED BY SURVIVAL ALONE` + a per-row table: F1/F2/F3/F5 verbatim in the font-family, F6–F9 verbatim in `cannot find`, **F4 and F4b an ABSENCE** plus two companion assertions |
| 13 | suite header, fence map | `the "%s" at the five sites -> F1-F7` → ONE ROW PER SITE, five lines mapping each call site to its row, `F5`/`F9` named as controls, plus the measurement that F4 stayed green with svg_draw_symbol's site reverted |
| 14 | named limit `L6` | `they print ONE lowercase skip: line` → `TWO … one naming the G/W/P rows, one naming S3`, with the driven figure `ALL PASS (13 checks)` and the note that `row_skip` keeps X1's id set complete. **Driven by me with gcc off PATH** (§4). |
| 15 | `C-implement.md` (receipt) | `this tree contains zero #pragma … grep sums to 0` — the grep sums to **1**, the hit being the sentence itself. Receipt left as filed; the shipped claim in `src/util.c` and the suite's W1 comment is now precise: "this tree has no such **directive** anywhere — the only textual `#pragma` in src/ is this sentence, which is why `grep -rc '#pragma' src/*.c src/*.h` sums to 1 and not 0". |
| 16 | `C-implement.md` (receipt) | `9 raw hits in util.c, 4 in scheduler.c` — scheduler.c is **3**. Receipt-only: nothing shipped claims a number, and row `S2`'s detail reports `raw_hits` at run time. Left as filed, recorded here. |
| 17 | `C-implement.md` (receipt) | `REDDENS: un-commenting the declaration gives FAIL: S3` — true **only** of the pre-fix `int` spelling, which fails the build. This claim is now **true of the shipped tree**, because S3 was re-pointed (§5) and I drove it: un-commenting the declaration as it stands builds clean and gives `FAIL: S3 … decls=2 want=1`. |
| 18 | issue file, Still open 5 | `my_snprintf(u, 2, "abcd%d", 7) … leaves u byte-for-byte untouched` → measured on the shipped tree it returns 0 and `u` is `""`, **written**; that was the pre-fix behaviour. Rewritten to name the shape that **does** survive: a format with **no conversion at all** that does not fit, `my_snprintf(u, 2, "abcd")`, leaves the buffer untouched (driven: all 4095 canary bytes intact) because the tail copy is the only writer on that path. Added as named limit **L8** of the suite and as a pointer in `src/util.c`'s PREFIX_GUARD comment. |
| 19 | `C-implement.md` (receipt) | `max_literal_spec_len=5 IS asserted as a property` — it appears only in P2's and P3's detail strings. Receipt-only; the suite claims nothing about it, and P2 asserts the stronger property (no spec ≥ 50) directly. Left as filed, recorded here. |
| 20 | `C-implement.md` (receipt) | three binary md5s used as tree identities — `src/xschem` is **not reproducible**, because `src/scheduler.c` has `char date[] = __DATE__ " : " __TIME__;`. Receipt-only. **Carried forward for the driver: do not use an `src/xschem` md5 as a build identity in this batch's ledger.** |
| 21 | issue file, Correction 6 | heading `THE COMPILER FENCE IS -Wformat-nonliteral, NOT -Wformat-security` and `Row W1 uses it` → the heading is now marked **too strong**, with the three-line probe output showing that for the five zero-argument sites the flag that names them is `-Wformat-security` and `-Wformat-nonliteral` names none of them; `W1` collects the **whole `[-Wformat` family** and must. `Row W1 uses it` removed. |

### Two more false sentences, outside the twenty-one, fixed in the same files

* Row `P2`'s comment claimed that if `my_snprintf_spec_ok()` and P2's Tcl copy "ever disagree about
  a LIVE spec … the row says which spec". Refuted twice by Cv (green on a fully reverted tree; green
  while the C guard refused the live `%.16g`/`%.17g`). Rewritten to say what P2 can and cannot do,
  with both measurements.
* Row `G4`'s name carried the same 419-for-`%'.0f` error as GUARD 2's comment. Now 412, with the
  arithmetic and the two other driven figures.
* The issue file's `Rows F1–F5 of the suite therefore assert the value reaches the exported
  font-family verbatim` — false of `F4`. Narrowed, with `F4`/`F4b` named as absence rows.

---

## 4. Claims I re-drove rather than quote

The brief says a comment that quotes a measurement must reproduce it. Everything I put a number on
was measured by me on this tree, not copied from a receipt.

* `%'.0f` **412**, `%'.6f` **419**, `%'.180f` **593** of −DBL_MAX, `localedef -i en_US -f UTF-8` into
  a scratch `LOCPATH` (this box has no `en_US.UTF-8` installed). Arithmetic agrees with 412:
  1 sign + 309 digits + 102 separators.
* `sprintf("%.192f", -DBL_MAX)` = **503**; `%.191f` = **502**; `%f` = **317**; `%.200f` = **511**.
* `-w` in `Makefile.conf`'s CFLAGS → **W2 red**, nothing else. `-Wno-format` → **all 33 green**.
  `-Wno-format` *and* `svg_draw()`'s `textfont` site reverted → **F1, F2, P1, W1 red**, W2 green, so
  `-Wno-format` does not weaken the fence. Cv's finding reproduced exactly.
* gcc off `PATH`: **two** lowercase `skip:` lines (not one), `RESULT: ALL PASS (13 checks)`, and X1
  still runs and passes with `rows_known=33` because `row_skip` seeds the skipped ids. Neither skip
  line ends in `FAIL`/`GOLD?`/`RESULT?`.
* The whole parselabel.l dead block does **not** compile (§5).

---

## 5. T4 — the dead declaration in `src/parselabel.l`

**Decision: re-point `S3`, keep the dead block, and record the measurement in the block's own
comment.** Comment-only in the product; the behaviour change is in the row.

**Why not delete the block.** The block is nine dead `extern` declarations, only one of which is
`my_snprintf`; deleting it would discard the file's record of what it used to declare, and it would
leave `S3` fencing nothing at all. Re-pointing costs nothing and turns `S3` into a real fence.

**Why `S3` could not redden on anything safe.** It asserted only "zero declarations taking an
`int size`", which is a property of one spelling:

| edit | builds? | old S3 |
|---|---|---|
| un-comment the **whole** block | **no** — `conflicting types for 'xctx'` (`extern int xctx;` against `xschem.h`'s `Xschem_ctx *xctx`) and `my_free`'s signature disagrees too | never reached |
| un-comment **only the `my_snprintf` line** as J11 re-spelled it (`size_t`) | **yes, clean** | **green** |
| restore the old `int`/`int` spelling | **no** — `conflicting types for 'my_snprintf'`, `make` rc 2 | red, but on a tree where `make` never completed, so every behavioural row would have been scoring a **stale binary** |

⚠ **This corrects Cv §2.4 in one respect**: Cv reports "un-commenting the block as it now stands
builds clean". Driven here, the **whole block** does not build; only the `my_snprintf` line on its
own does. Cv's conclusion is unaffected — the plausible edit still reddened nothing.

**What `S3` asserts now**: the preprocessed `src/parselabel.c` contains **exactly one** declaration
of `my_snprintf` (matched as a return type immediately followed by the name and an open paren), that
declaration carries `format(printf, 3, 4)`, and zero declarations take an `int size`. Green:
`decls=1 want=1 attr_on_it=1 int_size_decls=0 any_my_snprintf=2`.

Sabotaged, and both halves redden:

```
T4   parselabel.l's my_snprintf declaration un-commented (the only spelling that builds)
     make rc=0        FAIL: S3 … (decls=2 want=1 attr_on_it=1 int_size_decls=0 any_my_snprintf=3 …)
T4b  the format(printf,3,4) attribute removed from src/util.h
     make rc=0        FAIL: W2 … (nonliteral_diags=0 missing={} security_seen=-1 log={})
                      FAIL: S3 … (decls=1 want=1 attr_on_it=0 int_size_decls=0 any_my_snprintf=2 …)
```

The block's comment now records all three measurements, so the next reader does not have to guess
what un-commenting costs, and `S3`'s comment records why it was re-pointed.

---

## 6. No product behaviour changed, and that is proven

`src/util.c`, `src/svgdraw.c` and `src/xinit.c` preprocess **byte-identically** to the landed
Stage C versions (`gcc -E -P` at the build's CFLAGS; `src/util.h` is reached through `xschem.h` by
all three, so it is covered):

```
IDENTICAL after cpp: util.c
IDENTICAL after cpp: svgdraw.c
IDENTICAL after cpp: xinit.c
```

`src/parselabel.l` is identical with block comments stripped (its change is entirely inside the dead
block's `/* … */`), checked textually rather than through `cpp` because `flex -l` — the build's own
invocation — differs from a hand `flex -o` in the `yytext` declaration and the table sizes, which
would have shown up as a spurious difference:

```
parselabel.l with block comments stripped: IDENTICAL
```

Full rebuild emits the same **six** `-Wdiscarded-qualifiers` warnings as before and nothing else.

---

## 7. The three arms, verbatim

Rebuilt first (`make -C src`, rc 0) and re-run after every edit above.

```
################ ARM 1 -- nogui ################
test home: throwaway /tmp/xschem-test-home.2715093.r1etRU (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (33 checks)
RESULT: 1/1 runs passed

################ ARM 2 -- display (dev display :99) ################
test home: throwaway /tmp/xschem-test-home.2715554.suVKpj (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (33 checks)
RESULT: 1/1 runs passed

################ ARM 3 -- no dev display (private Xvfb) ################
test home: throwaway /tmp/xschem-test-home.2716013.6V9UYG (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: private Xvfb from :200 up, screen 1920x1080x24, wm openbox, GUI_GATE=0
             (AUDIT_DISPLAY=:0 to use the real screen, =none to skip GUI legs)
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (33 checks)
RESULT: 1/1 runs passed
```

Arm 3 used a read-only empty `XSCHEM_DEVDISPLAY_DIR`; `devdisplay.sh start|stop|view` was never run
and `devdisplay.sh status` reports the same `xvfb: 3979908` before and after.

Zero `skip:` lines on all three arms, so this suite still contributes **no** skip to the gate.

---

## 8. T1 solo

Solo — zero `another regression run is live` lines in the driver's stdout, and no
`results.<pid>.log` with a live `/proc/<pid>` when the run started. The binary was rebuilt from the
final sources (`touch src/*.c src/*.h && make -C src`, rc 0, six `-Wdiscarded-qualifiers` warnings
and nothing else) before it started, and the 1608 case read the final suite file.

```
T1-RUN-BEGIN pid=2716636 script=run_regression.tcl start=2026-09-26 19:18:00 planned_cases=100 verdict=results.2716636.log home=throwaway binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
T1-RUN-END pid=2716636 cases=100 blocks=99 counted_failures=0 skips=8 elapsed=598s end=2026-09-26 19:27:58
```

`wc -l` **299**. Counted shapes (`grep -cE 'FAIL$|GOLD\?$|RESULT\?$|^FATAL'`) **0**. The eight
`skip:` lines are the baseline eight — `test_op_annot`'s five display-only rows on the headless arm
plus `test_input_line_inject_1352`, `test_preview_name_inject_1601` and `test_generator_paren_1604`
— and **none belongs to this suite**. The 1608 block:

```
headless/test_snprintf_fmt_1608.log
RESULT: ALL PASS (33 checks)
Total num fail: 0
```

`cases=100 blocks=99 skips=8` is unchanged from Cv's run: this stage adds rows, not cases, so the
trailer does not move. An earlier run of the same tree in this stage
(`results.2649007.log`, `elapsed=595s`) gave the identical trailer.

### And once more on the fully restored tree, after the last two sabotages

The sabotage harness restored every file byte-identically (`cmp` against the frozen copies, all
`same`), `make -C src` rc 0, and T1 ran again, solo:

```
T1-RUN-BEGIN pid=2785580 script=run_regression.tcl start=2026-09-26 19:28:18 planned_cases=100 verdict=results.2785580.log home=throwaway binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
T1-RUN-END pid=2785580 cases=100 blocks=99 counted_failures=0 skips=8 elapsed=594s end=2026-09-26 19:38:12
```

`wc -l` **299**, counted shapes **0**, `another regression run is live` lines in the driver's stdout
**0**, and the 1608 block `RESULT: ALL PASS (33 checks)` / `Total num fail: 0`. Three T1 runs in this
stage, all `cases=100 blocks=99 counted_failures=0 skips=8`: `results.2649007.log` (595s),
`results.2716636.log` (598s) and `results.2785580.log` (594s).

---

## 9. The `hcases` rationale

The **case** count does not move (this stage adds rows, not suites), so `cases=100` stands. But
`test_snprintf_fmt_1608` had **no rationale paragraph** in `tests/run_regression.tcl` while every
other suite in that list has one, and the check count did move. Added: what the issue was, why
`hcases` and not `dcases` (every export is a spawned `--nogui` child, no row creates a widget, and
section G does not run xschem at all), the three-arm measurement, the gcc-absent figure, and the
`28 → 33` history naming the four unfenced guards and the five wrong citations.

---

## 10. Deviations, and what I could not measure

1. **I did not edit `C-implement.md`.** Four of the twenty-one (15, 16, 19, 20) are claims that exist
   only in Stage C's own dated receipt, which Cv has already refuted on the record. Rewriting another
   crew's receipt would falsify the record, so they are corrected in §3 of this receipt and, where
   the claim also ships, in the code. Items 6, 17, 18 and 21 did also ship or sit in the issue file
   and are fixed there.
2. **No product code was changed**, as instructed. Two product edits are comment-only and were
   explicitly permitted: `src/parselabel.l`'s dead-block comment (T4) and the citation/measurement
   corrections. `§6` proves the compiled output is unchanged.
3. **`P3`'s `p`-arm floor was deliberately not asserted.** The task said "either assert it or stop
   claiming it"; the tree has exactly **one** live `%p` literal, so a floor of one on that arm would
   redden the day someone deletes a debug line — a spelling change, not a regression. The three arms
   with many callers are asserted and the `p` count is reported. Stated in the row's name and comment.
4. **X1's attribution rule 3 is a heuristic**, and I say so in the row's comment rather than claiming
   a property. It reads "the nearest preceding `*.tcl` name in the file", which is how these comments
   are written but is not a guarantee. Both failure directions are visible in the detail
   (`other_suites=`, `unattributed=`).
5. **X1 does not scan this suite's own prose.** The suite legitimately cites other suites' rows by
   bare id (`rows V10/V13 of test_ps_valid_1350.tcl`, `1607 row V27`, `1603 rows S1-S4`, none of
   which are rows here), so a bare-id scan of its own text would redden on correct sentences. The
   suite's own three wrong self-references were fixed **by hand** in this stage (items 12, 13, 14) and
   remain unfenced. That is the one part of the class this row does not close, and it is named in
   `L7`.
6. **Not measured, inherited from Cv and repeated rather than dropped**: a non-fortified or Windows
   build; whether mechanism (D) is reachable from any LITERAL format; the stack frame against
   recursion depth; and `:0` / the user's real screen (nothing here needs a display, all three arms
   are green and the suite emits no `skip:`, so a pixel would add nothing).
7. **Cv §4.10's new behaviour delta is not fenced and not mine to fence**: a `font=` value of 80
   characters or more now emits `style="font-family:;"` where `91bb1bd7` emitted no attribute at all.
   rc 0 both ways, no signal. It is a user-visible SVG difference at a threshold nobody measured, it
   is the (E) class at one of the five sites, and it is a **product** question — so per the standing
   instruction I did not touch the fix. **Carried forward for the driver**, and it is the one item in
   this batch I would put in front of the user rather than decide.
8. **Two corrections to Cv**, both recorded above: `%.191Lp` and `%*p` do not die with the `p` arm's
   gate removed (§1), and un-commenting the **whole** parselabel.l block does not build (§5).

## 11. Hygiene

* Every figure came from a `make -C src` after the edit that produced it, rc asserted in the harness
  before the suite ran. Restores are `cp`, **never `cp -a`**, followed by another `make -C src`, and
  the harness re-ran the suite after each restore and asserted `ALL PASS (33 checks)` — all 15 did.
* Tree restored: `src/{util.c,util.h,svgdraw.c,xinit.c,parselabel.l,parselabel.c}`,
  `tests/headless/test_snprintf_fmt_1608.tcl` and `Makefile.conf` all `cmp`-identical to pre-sabotage
  copies, and `git status --porcelain` is what it was at the start of this stage plus this receipt.
* `tclsh tests/headless/issue_stamp.tcl` → `self-test PASSED (180 parser cases)` /
  `ISSUE-STAMP: ok (0 problems)` after the issue-file edits.
* No commit. No `~/.claude/xschem_owed/` access. No `devdisplay.sh start|stop|view`. No writes in
  `~/dev/xschem-op-wcard`. No `/tmp/xschem_emergencysave_*` created or deleted. Scratch confined to
  `<scratchpad>/stageC2_1608/`.
* ⚠ **Do not use an `src/xschem` md5 as a build identity** anywhere in this batch (§3 item 20).
