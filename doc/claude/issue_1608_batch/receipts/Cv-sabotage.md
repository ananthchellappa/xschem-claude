# Cv — independent sabotage crew, issue 1608

I disbelieved Stage C's receipt and re-derived it. **Everything Stage C claims to have fixed is
fixed, and every door it claims to have closed is closed** — I could not get a hostile format into
`my_snprintf` by any route I tried. But **five guards have no row that reddens on their own
removal, three of them with a measurable consequence**, **two rows pass on a tree where the thing
their name invokes is absent**, and **twenty-one claims in the shipped code comments, row names,
the receipt and the issue file are false or overstated**, including one driven figure that is wrong
by 7 and one that cannot reproduce at all because it is uninitialised stack.

HEAD `91bb1bd7`. Tree restored byte-identical; see §8.

---

## 1. The sabotage matrix — 29 single removals, each rebuilt and re-run

Method: exact-text replacement in the working tree, `make -C src`, `test_snprintf_fmt_1608.tcl`
under an armed throwaway HOME, restore with **`cp`** (never `cp -a`), `make -C src`, re-confirm
`RESULT: ALL PASS (28 checks)`. Every one of the 29 rows below restored green; the harness asserts
it and printed no `RESTORE NOT GREEN`. Full JSON with verbatim lines:
`<scratch>/stageCv_1608/sab_results*.json`.

⚠ **First, a method correction that matters to anyone repeating this.** My first pass at the two
`svg_draw` sites used the bare indented call text as the anchor, and a **4-space anchor is a
substring of the 8-space one** — so `.replace()` silently reverted BOTH `svg_font_name` sites and
both `textfont` sites at once, and I read F3 as reddening for the wrong sabotage. This is exactly
deviation 9 of Stage C's receipt, hit again. The rows below are the re-run with `\n`+indent
anchors and an asserted occurrence count of 1.

| # | guard removed (one at a time) | rows that reddened |
|---|---|---|
| 1 | `src/svgdraw.c` `svg_draw_symbol`, `svg_font_name` `"%s"` | **P1, W1 — no behavioural row** |
| 2 | `src/svgdraw.c` `svg_draw_symbol`, `textfont` `"%s"` | F3, P1, W1 |
| 3 | `src/svgdraw.c` `svg_draw`, `svg_font_name` `"%s"` | F4, P1, W1 |
| 4 | `src/svgdraw.c` `svg_draw`, `textfont` `"%s"` | F1, F2, P1, W1 |
| 5 | `src/xinit.c` `Tcl_AppInit`, `--rcfile` `"%s"` | F6, F7, F8, P1, W1 |
| 6 | GUARD 1 `if(len >= nfmtsize) return 0;` | G1 |
| 7 | GUARD 2 `else return 0;` (the whitelist) | G2, G3, G4, G9 |
| 8 | GUARD 2's `l`/`h` permit line (i.e. tighten onto live callers) | G5 |
| 9 | GUARD 2's flags/`.` line | G1, G7, G10 |
| 10 | GUARD 3 `return max + 320 < nstrsize;` → `return 1;` | G6, G9 |
| 11 | GUARD 3's digit-run overflow cap `if(run < 1000000)` | **NOTHING** |
| 12 | `#define MY_SNPRINTF_NSTR 512` → `50` | F3, G1, G5, G7, G10, G11 |
| 13 | (D) `>=` → `>`, `%s` arm (1st) | G8 |
| 14 | (D) `>=` → `>`, `d/x/c/u` arm (2nd) | G8 |
| 15 | (D) `>=` → `>`, `p` arm (3rd) | G8 |
| 16 | (D) `>=` → `>`, `g/e/f` arm (4th) | G8 |
| 17 | (D) refusal's `if(n < size) string[n] = '\0';` (all four) | **NOTHING** |
| 18 | refuse-ordering → Stage B's shape (break before the prefix write) | G1, G2, G3, G4, G6, G9 |
| 19 | the gate CALL in the `d/x/c/u` arm only (`refuse = 0;`) | G1, G2, G4, G6, G9 |
| 20 | the gate CALL in the **`p` arm only** | **NOTHING** |
| 21 | the gate CALL in the `g/e/f` arm only | G3, G6 |
| 22 | `src/util.h`'s `format(printf,3,4)` attribute | **W2 only** (W1 stays green — by design) |
| 23 | `src/xinit.c` `old_win_path[0]='\0'` → `my_snprintf(…, "")` | W1 |
| 24 | a live `#ifdef HAS_SNPRINTF` re-inserted at a code position in `src/util.c` | S1 |
| 25 | a live `#ifdef HAS_SNPRINTF` re-inserted at a code position in `src/scheduler.c` | S2 |
| 26 | `src/parselabel.l` dead block un-commented **as it now stands** (`size_t`) | **NOTHING** |
| 27 | `src/parselabel.l` dead block un-commented with the **old `int` spelling** | P1, S3 — but `make` **fails, rc 2** |
| 28 | the two bare-`break` arms lose the added `overflow = 1` | NOTHING (provably inert, §4) |
| 29 | **the whole fix reverted** (`git show HEAD:` over all nine files) | **19 of 28**: F1 F2 F3 F4 F6 F7 F8 W2 P1 G1 G2 G3 G4 G6 G7 G8 G9 S1 S2 |

Verbatim failing lines for the five whose identity matters most:

```
FAIL: F3 (1608) the `font=` attribute of a text object inside a .sym, reached through an instance
 -- svg_draw_symbol()'s `textfont` site, a DIFFERENT one of the four from F1/F2. A stranger's
 SYMBOL LIBRARY is the door here, not their schematic (rc=0 death=0 fams={{} Sans-Serif})
FAIL: F4 (1608) the remaining two of the four svgdraw.c sites: … (rc=0 death=0 per_text_attrs=1
 want=0 …)
FAIL: F6 (1608) `--rcfile '%-2000d'` … (rc=0 death=0 want=1 out={AppInit() err 2: cannot find …
FAIL: P1 (1608) censusing `gcc -E` output of every src/*.c at the build's own CFLAGS finds ZERO
 my_snprintf calls whose format argument is not a string literal … (nonliteral={{svgdraw.c:
 tclgetvar("svg_font_name")}} calls=720 literal=719 conversions=1222 missing={})
FAIL: W2 (1608 anti-vacuity for W1) … (nonliteral_diags=0 missing={} security_seen=-1 log={})
```

---

## 2. THE FIVE UNFENCED GUARDS — and three of them are consequential

I did not accept "covered by another row". For each I compiled the tree's own `src/util.c` at the
build's CFLAGS into my own fork-per-case driver (`<scratch>/stageCv_1608/drv/drv2.c`, cases the
suite does **not** have) and measured what the removal actually does.

### 2.1 ⚠ The spec gate in the **`p` arm** — removal reddens nothing, and it reopens the `%n` write

No G case drives a hostile spec through `%p`. The suite's `p`-arm cases are `abcd%p` (mechanism D)
and `x=%p` (identity). Driven, `util.c` with only the `p` arm's `refuse = !my_snprintf_spec_ok(…)`
replaced by `refuse = 0`:

```
P_N   (%np)                       DIED sig=6   *** %n in writable segments detected ***
P_W   (%-2000p)                   DIED sig=6   *** buffer overflow detected ***
P_L   (%.191Lp)                   DIED sig=6
P_STAR(%*p)                       DIED sig=6
P_D50 (% + 49 dashes + p)         DIED sig=6
```
On the shipped tree all five are `ret=0 canary=intact`, refused. On `91bb1bd7` all five also DIED
sig 6 — so this is a real door in the real function, and **`test_snprintf_fmt_1608.tcl` is
`ALL PASS (28 checks)` with it reopened.** The `%n` case is the same attempted-arbitrary-write
shape the whole issue is about, in the arm nobody fenced.

### 2.2 GUARD 3's digit-run overflow cap — removal reddens nothing

`if(run < 1000000)` stops a long digit string wrapping `size_t`. Removed:

```
CAPW  (%18446744073709551616d)  ret=18446744073709551615  (i.e. (size_t)-1), buffer empty
```
shipped tree: `ret=0`, refused. `91bb1bd7`: also `ret=18446744073709551615`. That return is
consumed as a length by `my_itoa`, `dtoa`, `dtoa_prec` (→ `xctx->tok_size`) and two accumulators —
the exact hazard `src/util.c`'s own deleted-arm comment describes. Suite: `ALL PASS (28 checks)`.

### 2.3 The (D) refusal's NUL-termination — removal reddens nothing, and it restores an (E) read

Stage C's deviation 6, added precisely so a (D) refusal cannot become an (E) unwritten buffer.
Driven with all four `if(n < size) string[n] = '\0';` removed:

```
E_U  my_snprintf(u, 2, "abcd%d", 7)   ret=0, buffer UNTOUCHED (8192 canary bytes intact)
```
shipped tree: `ret=0`, buffer `""` (written). `91bb1bd7`: UNTOUCHED. So the removal is a real
regression back to the pre-fix shape and **nothing in the suite notices.**

### 2.4 `src/parselabel.l`'s dead declaration — un-commenting it as it now stands reddens nothing

Row S3 greps preprocessed `parselabel.c` for a declaration taking an **`int size`**. J11's fix
re-spelled the dead copy to `size_t size`, so un-commenting the block **as J11 left it** builds
clean and passes all 28 rows. Only the old `int` spelling reddens S3 — and that spelling is a
hard compile error (`make` rc 2, conflicting types), so `make` never completes and Section F would
be scoring a stale binary. **Stage C's receipt states "REDDENS: un-commenting the declaration
gives `FAIL: S3`" without either caveat.**

### 2.5 The two added `overflow = 1` in the bare-`break` arms — reddens nothing, and correctly so

I verified the inertness proof rather than taking it: `overflow` is read in exactly one place,
`if(!overflow && n+l+1 <= size)`, and on the (D) break path the guard fired because
`n + (fmt-prev) >= size` while `l = f - prev >= fmt - prev`, so `n+l+1 <= size` is already false.
Behaviourally dead, so **no row can exist for it** — the one unfenced item that needs no fence.

---

## 3. Vacuous rows — two pass on a tree where what their name invokes is absent

### 3.1 P2 does not read `my_snprintf_spec_ok()` at all, and its comment says it does

P2's name: *"no LITERAL conversion spec anywhere in the compiled tree is refused by any of
**`my_snprintf_spec_ok()`'s** three guards"*. Its comment: *"if `src/util.c`'s
`my_snprintf_spec_ok()` and this ever disagree about a LIVE spec, P2's claim … stops being true
and **the row says which spec**."*

Refuted twice:
* On the **fully reverted tree** (§1 row 29), where `my_snprintf_spec_ok()` does not exist, **P2 is
  green.**
* Under sabotage 9 (GUARD 2's flags/`.` line removed), the C guard began refusing the **live**
  specs `%.16g` and `%.17g` — `actions.c`'s own literals — and **P2 stayed green.** G10 and G7
  caught it:
  ```
  FAIL: G10 … (d={x=-2147483648} x={x=ff} g16={x=} g={x=0.333333} … g17={x=} …)
  FAIL: G7  … (p191={0}/{0} g60={0} f6={0} c5out={})
  ```
  P2 is a Tcl re-implementation of the guard measured against the tree's literals. It answers
  "are the tree's literals inside these thresholds?" — a real and useful question — but it cannot
  see a divergence, so the quoted sentence is false.

### 3.2 S3 asserts a property of the format attribute while measuring only a declaration spelling

S3's name ends *"…so there is exactly one live declaration of the function in the program and **the
format attribute on it cannot be fought by a second, disagreeing one**."* On the fully reverted
tree there is **no format attribute at all** and S3 is green.

### 3.3 W1 is designed to be vacuous without W2, and it is — confirmed

* Attribute removed (sabotage 22): W1 **green**, W2 **red**. Correct.
* `-w` prepended to `Makefile.conf`'s `CFLAGS` **and** a real site reverted: `F1 F2 W2 P1` red,
  **W1 green**. W2 is load-bearing, exactly as its comment claims.
* `-Wno-format` prepended **and** a real site reverted: `F1 F2 W1 P1` red, W2 green — see §5.20.

### 3.4 P1 false-positives on text inside a string literal (errs safe, but the "literal-state-aware" claim is half true)

`cens_calls` scans for the token `my_snprintf` anywhere in the preprocessed text, including inside
string literals; only the *argument list* walk is literal-aware. Planting
`if(0) fprintf(errfp, "my_snprintf(svg_font_family, S(svg_font_family), textfont);");` reddens
**P1 alone** on a tree with nothing wrong. Safe direction, and a maintenance trap: `gcc -E` strips
comments but keeps strings, so documentation text in a string reddens the census.

### 3.5 The four decoys that correctly redden nothing

Bad calls inside a `/* */` comment, inside `#if 0`, inside `#ifdef HAS_SNPRINTF` (undefined), and
in an un-invoked `#define` body all leave all 28 rows green. That is **correct** — none of them
compiles — and it is what makes the `gcc -E`/compiler pair the right instruments.

### 3.6 The decoy battery that P1/P2/W1 DO catch

| decoy planted at a real caller | caught by |
|---|---|
| `#define XSNP my_snprintf` + `XSNP(dst, S(dst), textfont)` (one hop) | P1, W1 |
| `#define XS1 my_snprintf` / `#define XS2 XS1` + `XS2(…)` (two hops) | P1, W1 |
| literal `"%.400f"` | P2 |
| **`"%." "400f"` split across adjacent literals** | P2 |
| literal `"%*d"` | P2 |
| `if(0) my_snprintf(dst, S(dst), textfont);` | P1, W1 |
| the census parser blinded (`cens_calls` returns `{}`) | **P3 alone**, P1/P2 green — P3 works |

---

## 4. THE DOORS — I tried to reach `my_snprintf` with a hostile format again, by every route I could invent

Headless throughout: `env -u DISPLAY HOME=<throwaway> timeout 60 ./src/xschem --nogui --pipe -q …`.
`$DISPLAY` was never inherited by any child. Every door is reported with what the **same** door
does on a from-scratch build of `91bb1bd7` at `/tmp/b1608`, so "closed" is measured against a
door that was open.

### 4.1 `font=` on a `.sch` text object — **CLOSED**
22 specs, each through `xschem load; xschem zoom_full; xschem print svg`: `%nd`, `%n`, `%s`,
`%-2000d`, `%.192f`, `%.0Lf`, `%*d`, `%'.0f`, `%zd`, `%jd`, `%hhn`, `%hn`, `%ln`, `%2147483647d`,
`%999999999999999999999d`, `%%nd`, `%p`, `%c`, `%`+45 dashes+`d`, `%`+58 dashes+`d`,
`%`+60 dashes+`d` (a 62-character spec), and `Monospace` as a control.
**All rc 0, and every value reached `font-family:` verbatim** — e.g.
`font-family:%nd`, `font-family:%-2000d`,
`font-family:%------------------------------------------------------------d`.
At `91bb1bd7` the same fixtures: `%nd` → rc 134 `*** %n in writable segments detected ***`;
`%-2000d` → rc 134 `*** buffer overflow detected ***`; `%.192f` → rc 134.

### 4.2 `font=` on a `.sym` text reached through an instance — **CLOSED**
`%nd`, `%-2000d`, `%.192f`, `%.0Lf`, the 62-character spec, `%s`, `Monospace`: all rc 0, value
verbatim.

### 4.3 `svg_font_name`, five routes × 2 specs × with/without an instance — **CLOSED**
`--script`, a `./.xschemrc`, `--preinit`, `--tcl`, and `--rcfile <a real file that sets it>`.
20 runs, all rc 0, `FNAME=<%nd>` / `<%-2000d>` round-tripped, `font-family: %nd` emitted. The
with-instance runs put `SYMTXT` in the output, so `svg_draw_symbol`'s `svg_font_name` site really
ran. (The `./.xschemrc` route did not take effect in-tree — the variable stayed `Sans-Serif` — so
it is not a door here either way.)

### 4.4 `--rcfile` — **CLOSED**
`%s`, `%-2000d`, `%nd`, `%.192f`, `zz%.192f`, `zz%*d`, `zzz`: every one `rc=1` with
`Tcl_AppInit() err 2: cannot find <the string typed>`, verbatim. At `91bb1bd7`: `%s` → **rc 139**;
`%-2000d`, `%nd`, `%.192f`, `zz%.192f` → **rc 134**.

### 4.5 Other output back ends — **CLOSED**
`xschem print ps`, `print pdf`, `print png`, `print tedax` and `xschem netlist`, each with
`font=%nd` and `font=%-2000d`: 10 runs, all rc 0, `DONE-OK`.

### 4.6 Symbol and instance attributes — **CLOSED**
`format="@name %<spec> @pinlist @symname"`, `template="name=x1 zz=<spec>"`, instance
`name=<spec>`, symbol text body `<spec>`, `verilog_format=<spec>`, `type=<spec>`, each with `%nd`,
`%-2000d` and `%s`, driven through `xschem netlist` and `xschem print svg`: 18 runs, all rc 0.

### 4.7 `tcl_hook2` — **CLOSED**
`font=tcleval(%nd)` on a schematic text: the hook ran and its result reached `font-family:%nd`,
rc 0. `tcl_hook2` can only produce either a file name (not a format) or, via arbitrary Tcl, a
`svg_font_name` value — and 4.3 closes that.

### 4.8 A symbol **generator** — **CLOSED**
An executable `hg.tcl` generator emitting `T {GENTXT} … {layer=4 font=%nd}`, instantiated as
`C {hg.tcl(1)}`: rc 0, `style="font-family:%nd;"`. The generator's output is a `.sym`, so it
arrives at 4.2's site.

### 4.9 The structural answer, from two independent instruments I ran myself
* **gcc's own opinion**, `gcc -fsyntax-only <Makefile.conf CFLAGS> -Wformat -Wformat-nonliteral
  -Wformat-security -Wformat-zero-length` over all 40 `src/*.c` — **exactly five diagnostics**,
  all `-Wformat-nonliteral`, all on deliberate `sprintf` lines, **none on any `my_snprintf` call**:
  ```
  draw.c:5309:7  draw.c:5310:7   sprintf(tmpstr, fmt2/fmt1, …)   (issue 1606's class)
  util.c:831:28  util.c:862:28  util.c:893:28   sprintf(nstr, nfmt, i)
  ```
* **my own `gcc -E` census** (Python, written independently of the suite's Tcl):
  `units 40 calls 720 literal 720 nonliteral 0 conversions 1223`, longest literal spec **5**
  (`%.16g`), zero `*`, zero spec refused by the three guards. Arms:
  `s 653, d 294, g 211, x 24, u 20, c 18, e 1, f 1, p 1`.
* **No indirect call exists**: `my_snprintf`'s address is never taken anywhere in `src/`.
* **No sibling door**: censused `dbg()` (1351 call sites) and `log_action()` (134) for non-literal
  formats — the only hits are the prototypes and one ternary of two literals. Nothing user-controlled
  reaches a `printf`-family format anywhere I could find.

### 4.10 ⚠ One NEW behaviour delta the fix introduces, unmeasured anywhere
A font name of **80 characters or more** now emits an **empty** declaration where `91bb1bd7`
emitted none at all and fell back to the default:

| `font=` length | `91bb1bd7` | shipped tree |
|---|---|---|
| 79 | `style="font-family:AAA…(79);"` | identical |
| 80, 82, 200 | **no `style="font-family:"` attribute at all** | `style="font-family:;"` |

rc 0 both ways, no signal. Cause: as a `%s` **argument** the over-long value takes the `%s` arm's
second check, which breaks after the prefix write has already put `'\0'` at `string[0]`; as the
**format** it used to take the tail-copy path and leave `svg_font_family` at its previous value.
Almost certainly invisible in a renderer, but it is a user-visible SVG difference at a threshold
nobody measured, and it is the (E) class at one of the five fixed sites.

---

## 5. Claims I can show are false, quoted verbatim, with the measurement

**In the shipped source comments**

1. `src/util.c`, above the three `sprintf(nstr, nfmt, i)` sites: *"They are why **row F13** of
   tests/headless/test_snprintf_fmt_1608.tcl asserts that no diagnostic falls on a line spelling
   `my_snprintf(`"*. **There is no F13.** The suite's rows are F1–F9, W1, W2, P1–P3, G1–G11,
   S1–S3. The row is **W1**.
2. `src/util.c`, end of `MY_SNPRINTF_PREFIX_GUARD`: *"**Rows F7-F12** of
   tests/headless/test_snprintf_fmt_1608.tcl fence all of this."* F7 and F8 are the `--rcfile`
   rows, F9 is their control, **F10–F12 do not exist**. (D) and the ordering are fenced by **G8**
   and **G9**.
3. `src/util.h`: *"`tests/headless/test_snprintf_fmt_1608.tcl` **row F13** compiles the whole of
   src/*.c with `-Wformat -Wformat-nonliteral` and **fails on ANY diagnostic**."* Wrong row (W1),
   and W1 does **not** fail on any diagnostic — it permits two text spellings, and the clean tree
   produces five.
4. `src/svgdraw.c`, above `svg_font_family`: *"Fenced behaviourally by
   tests/headless/test_snprintf_fmt_1608.tcl (**rows F1-F6**)."* **F6 is the `--rcfile` row**, in
   `xinit.c`. The svgdraw rows are F1–F5.
5. `src/xinit.c`, in `Tcl_AppInit`: *"Fenced by **rows F3/F4/F6** of
   tests/headless/test_snprintf_fmt_1608.tcl."* The `--rcfile` rows are **F6/F7/F8**. F3 is the
   `.sym` `font=` row and F4 is the `svg_font_name` row — neither touches `--rcfile`.
6. `src/util.c`, GUARD 2 comment: *"In a grouping locale `%'.0f` of -DBL_MAX **measures 419** and
   `%'.180f` 593"*. I built the locale (`localedef -i en_US -f UTF-8`) and drove it:
   ```
   locale=en_US.UTF-8
   %'.0f   of -DBL_MAX = 412        <-- not 419
   %'.180f of -DBL_MAX = 593        <-- correct
   %'.6f   of -DBL_MAX = 419        <-- 419 belongs to THIS spec
   ```
   The arithmetic agrees with 412: 1 sign + 309 digits + 102 separators. And the source the figure
   came from, `Bv-refute.md`, says *"it **would be** 419"* — a derivation. The code comment
   upgraded a wrong derivation into a measurement. (The issue file keeps "would be", so only the
   figure is wrong there.)
7. `src/util.c`, GUARD 1 comment: *"driven at 91bb1bd7, `--rcfile "%<48 dashes>d"` returned rc 1
   and printed `cannot find 104`"*. The printed integer is `va_arg(args, int)` on a vararg nobody
   pushed. Measured on a from-scratch `91bb1bd7` build, three runs each:
   ```
   48 dashes (spec len 50):  cannot find 32 / 112 / 24   (and 8 on the first run)
   47 dashes (spec len 49):  cannot find 72 / 80 / 96    (and 104 on the first run)
   ```
   The **shape** reproduces exactly (len 49 and len 50 both rc 1 with a formatted number; len ≥ 51
   → rc 134 `*** buffer overflow detected ***`), so the substantive claim stands. The quoted
   number is stack garbage that never reproduces, and `104` came from the **47**-dash case.
8. `src/util.c`, GUARD 3 comment and row G6: *"`%.192f` … **a precision one past what the scratch
   holds**"*. `sprintf("%.192f", -DBL_MAX)` is **503** characters; the 512-byte scratch holds it
   comfortably. `%.192f` is refused by the over-estimate (192 + 320 = 512, not `< 512`), not by
   capacity.

**In the row names**

9. Row **F4**: *"the **remaining two** of the four svgdraw.c sites"* and *"**Reverting either
   site** leaves svg_font_family empty"*. Measured: reverting `svg_draw`'s `svg_font_name` site
   reddens F4; reverting **`svg_draw_symbol`'s** `svg_font_name` site leaves **F4 green** and
   reddens only P1 and W1. F4's fixture is a `.sch` with no instance, so `svg_draw_symbol` never
   runs. That site is the one call site with **no behavioural fence at all**.
10. Row **P3**: *"and found **at least one conversion in each of the four arms**"*. The row's
    expression is `$pcalls > 600 && $plits > 600 && $pconv > 1000 && [llength …*.i] > 30`. **No
    arm is tracked anywhere in the row.** (The fact happens to be true — I measured
    `d 294, g 211, x 24, u 20, c 18, e 1, f 1, p 1, s 653` — but nothing asserts it.)
11. Row **W2**: *"or a `-w`/**`-Wno-format`** reaches the generated Makefile.conf's CFLAGS, this
    row reddens"*. Driven: `-w` → W2 red ✓. `-Wno-format` → **all 28 rows green**, and with a real
    site also reverted W1 is still red, because the suite appends `-Wformat -Wformat-nonliteral`
    after `CFLAGS`. The claim overstates; the fence is not weakened.

**In the suite header**

12. *"⚠ EVERY ROW HERE ASSERTS THE VALUE REACHED THE OUTPUT VERBATIM"* and *"**Rows F1-F4**
    therefore assert the value REACHES THE SVG VERBATIM"*. **F4 asserts an ABSENCE** — zero
    per-text `style="font-family:"` attributes — as F4's own comment says at length.
13. The fence map's *"the `"%s"` at the five sites → **F1-F7**"*. F5 is a control, F8 is a real
    fence and is omitted, and one of the five sites has no F row at all (§5.9).
14. Named limit **L6**: *"With either absent they print **ONE** lowercase `skip:` line naming every
    row that did not run."* Driven with gcc off `PATH`: **two** lines, and `RESULT: ALL PASS (11
    checks)`.
    ```
    skip: G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 W1 W2 P1 P2 P3 -- no gcc on PATH (0 chars) or no …
    skip: S3 -- no gcc or no CFLAGS line, so parselabel.c could not be preprocessed; S1 and S2 …
    ```
    Both are lowercase and neither ends in `FAIL`/`GOLD?`/`RESULT?`, so the shape rule is honoured.

**In `C-implement.md`**

15. *"this tree contains **zero** `#pragma` of any kind (`/usr/bin/grep -rc '#pragma' src/*.c
    src/*.h` sums to 0)"*. That exact grep sums to **1** on the tree Stage C shipped, and the
    single hit is `src/util.c:732` — the sentence asserting it. No actual directive exists, so the
    substance holds and the quoted command's output does not.
16. *"**9 raw hits** in `util.c`, **4** in `scheduler.c`"*. Measured: `util.c` **9** ✓,
    `scheduler.c` **3**.
17. *"REDDENS: un-commenting the declaration gives `FAIL: S3 …` (and P1, since the extra
    declaration also reaches the census)"*. True only for the pre-fix `int size` spelling, which
    **fails the build (`make` rc 2, conflicting types)**. Un-commenting the block **as J11 shipped
    it** builds clean and reddens **nothing** (§2.4).
18. Carried-forward item 5, repeated as the issue file's "Still open" item 5: *"`my_snprintf(u, 2,
    "abcd%d", 7)` still returns 0 with `u` **byte-for-byte untouched**"*. Measured on the shipped
    tree: `ret=0`, `u` is `""` — **written**. That is the `91bb1bd7` behaviour, not the shipped
    one; Stage C's own deviation 6 fixed it. The (E) class **does** survive, but through a shape
    named nowhere: `my_snprintf(u, 2, "abcd")` — a format with **no conversion** — returns 0 and
    leaves `u` untouched (all 8192 canary bytes intact), because the tail copy is the only writer
    on that path.
19. *"The figure that matters and **IS asserted as a property** is `max_literal_spec_len=5`,
    `stars=0`, `refused={}`."* `stars` and `refused` are asserted by P2. `max_literal_spec_len`
    appears **only in the detail strings** of P2 and P3; no row's expression mentions `$pmax`.
20. The three binary md5s (`e13fb8b7…`, `f690e40a…`, `dc1401c5…`) are used as tree identities.
    **`src/xschem` is not reproducible.** `src/scheduler.c` contains
    `char date[] = __DATE__ " : " __TIME__;`, so `scheduler.o` and the link change on every
    recompile. Measured: four md5s from one unchanged source —
    `5f6db440…`, `61543da0…`, `4b22d24d…`, `972534fb…` — and `diff` of two `md5sum src/*.o`
    listings differs in `scheduler.o` alone. The md5s cannot be reproduced or used as evidence
    that two figures came from the same tree.

**In the issue file**

21. Correction 6's heading *"THE COMPILER FENCE IS `-Wformat-nonliteral`, NOT
    `-Wformat-security`"* and *"Row `W1` uses **it**"*. This is the version the receipt calls its
    own *"single most important correction"* — and the issue file was not updated. Measured on a
    probe that `#include`s the real `src/xschem.h`:
    ```
    z.c:6:3: warning: format not a string literal and no format arguments   [-Wformat-security]
    z.c:7:3: warning: format not a string literal, argument types not checked [-Wformat-nonliteral]
    z.c:8:28: warning: zero-length gnu_printf format string               [-Wformat-zero-length]
    ```
    For the five sites 1608 is about — all zero-argument — the flag that names them is
    **`-Wformat-security`**. W1 collects the whole `[-Wformat` family and must.

**One under-claim, recorded because it is the strongest fence in the change**

22. Nobody says that the attribute makes a reverted site a warning in the **ordinary
    `make -C src`** build, with no extra flags. Driven — the `svg_draw` `textfont` site reverted,
    plain `make`:
    ```
    svgdraw.c: In function 'svg_draw':
    svgdraw.c:1425:7: warning: format not a string literal and no format arguments [-Wformat-security]
    ```
    and a clean `touch src/*.c src/*.h && make -C src` emits exactly **6 warnings, all
    `-Wdiscarded-qualifiers`** — which is the receipt's claim, reproduced. So any future reopening
    of this door is visible to anyone who simply builds.

---

## 6. Stage C claims I re-derived and CONFIRMED

* `%nd` through a `.sch`, and `--rcfile '%s'`: exact BEFORE evidence reproduced on a from-scratch
  `91bb1bd7` build (§4.1, §4.4).
* Mechanism (D) was live and silent: on `91bb1bd7`, `font=` with an 80-character literal run before
  a `%d` emitted an **80**-character `font-family` out of a `char[80]`, rc 0, no message. Post-fix
  the canary at index `size` is intact on all six driver cases; on `91bb1bd7` **five of six** were
  `CLOBBERED` (`D1 D3 D4 D5 D6`; `D2`, the fitting control, intact) — exactly what G8 claims.
* Every quoted arithmetic figure: `%f` of −DBL_MAX **317**, `%.200f` **511**, `%.191f` **502**,
  `%.60g` **67**, `%.6f` **317**, `%.0Lf` of LDBL_MAX **4933**, `%'.0f` in the `"C"` locale **310**
  (it already aborted pre-fix), `%'.180f` in a grouping locale **593**.
* `-DHAS_SNPRINTF=` is a compile error at `91bb1bd7` (`scheduler.c:6263:65: error: expected
  expression before ')' token`); `-DHAS_SNPRINTF=1 -Wall` compiles clean, both `scheduler.c` and
  `util.c`.
* `nm -S src/util.o` → one `my_snprintf`; `nm -u src/util.o` → zero `vsnprintf`; `xschem globals`
  → `HAS_DUP2=1 HAS_POPEN=1 HAS_CAIRO=1` and no `HAS_SNPRINTF=` line.
* `src/expandlabel.y` carries the same dead declaration block, already `size_t`/`size_t`, inside
  `/* … */`. `spec_maxout` appears nowhere in `src/`, `tests/` or the issue file.
* `psprint.c` still takes the size from the wrong object at **two** sites (lines with
  `my_snprintf(ps_font_family, S(ps_font_name), "Helvetica")`); both arrays are `[80]`.
* The `%s` arm still discards a field width: `"[%-12s]"` and `"[%12s]"` both emit `[AB]`.
* `hcases` **81**, `dcases` 15, `tcases` 3 → `cases = 100`. `tclsh tests/headless/issue_stamp.tcl`
  → `self-test PASSED (180 parser cases)` / `ISSUE-STAMP: ok (0 problems)`.
* My independent census agrees with the suite's parser to the digit: 720 / 720 / 0 / 1223, max
  literal spec 5, zero `*`.
* No row asserts either death message; `/usr/bin/grep -n 'string first.*detected'` on the suite
  returns nothing (the 8 textual occurrences are all in prose).

---

## 7. What I could NOT measure

* **A non-fortified or a Windows build.** Everything here is `_FORTIFY_SOURCE=3`, x86-64 glibc,
  gcc 15.2.0. Inherited, and repeated rather than dropped.
* **Whether mechanism (D) is reachable from any LITERAL format.** Still uncensused: it needs each
  call site's destination size against the longest literal run, and `S(x)` preprocesses to
  `sizeof(x)`, which no text census resolves. P2 proves no literal spec is refused; that is a
  different question.
* **The stack frame against recursion depth.** `nstr[512]` grew it and I did not re-measure.
* **Whether the `L` garbage can ever be a large finite** rather than NaN.
* **`:0` / the user's real screen.** Nothing here needs a display; all three arms are green and the
  suite emits no `skip:`, so there is nothing a pixel would add. I never started, stopped or
  viewed the dev display; `devdisplay.sh status` reports the same `xvfb: 3979908` before and after.

---

## 8. Gate verdict — I would gate, with the five unfenced guards recorded as owed work

Nothing I found is a defect in the *fix*. The fix closes every door I could find and reopening any
of the five call sites reddens at least two rows (and warns in the plain build). What I would not
let pass silently is §2.1 — a whole arm of the gate is ungated with no red row — and the
twenty-one false statements in §5, five of which are wrong **row names in shipped source
comments**, the exact class `CREW_BRIEF.md` says this repo has paid for five times.

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
 src/parselabel.l               |  11 +-
 src/save.c                     |   7 +-
 src/scheduler.c                |   9 +-
 src/svgdraw.c                  |  47 +++++++-
 src/token.c                    |   5 +-
 src/util.c                     | 245 +++++++++++++++++++++++++++++++++++------
 src/util.h                     |  18 +++
 src/xinit.c                    |  15 ++-
 tests/run_regression.tcl       |   3 +-
 11 files changed, 338 insertions(+), 51 deletions(-)

$ make -C src
make: Entering directory '/home/analog/dev/xschem-claude/src'
make: Nothing to be done for 'all'.
make: Leaving directory '/home/analog/dev/xschem-claude/src'
```
(The preceding full rebuild, `touch src/*.c src/*.h && make -C src`, exited 0 with exactly six
`-Wdiscarded-qualifiers` warnings and nothing else.)

```
################ ARM 1 -- nogui ################
test home: throwaway /tmp/xschem-test-home.2625166.AKjqRI (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (28 checks)
RESULT: 1/1 runs passed

################ ARM 2 -- display (dev display :99) ################
test home: throwaway /tmp/xschem-test-home.2625608.0Y7Fmo (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (28 checks)
RESULT: 1/1 runs passed

################ ARM 3 -- no dev display (private Xvfb) ################
test home: throwaway /tmp/xschem-test-home.2626050.TUBBbK (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: private Xvfb from :200 up, screen 1920x1080x24, wm openbox, GUI_GATE=0
             (AUDIT_DISPLAY=:0 to use the real screen, =none to skip GUI legs)
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (28 checks)
RESULT: 1/1 runs passed
```

**T1 solo**, my own run, `tests/results.2558818.log`:
```
T1-RUN-BEGIN pid=2558818 script=run_regression.tcl start=2026-09-26 18:13:37 planned_cases=100 verdict=results.2558818.log home=throwaway binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
T1-RUN-END pid=2558818 cases=100 blocks=99 counted_failures=0 skips=8 elapsed=594s end=2026-09-26 18:23:31
```
`wc -l` **299**. Zero `another regression run is live` lines in stdout (solo). Zero counted shapes
(`grep -cE 'FAIL$|GOLD\?$|RESULT\?$|^FATAL'` = 0). The eight `skip:` lines are the baseline eight
(`test_op_annot` ×5 on the headless arm, plus `test_input_line_inject_1352`,
`test_preview_name_inject_1601`, `test_generator_paren_1604`); **none belongs to this suite**. The
1608 block:
```
headless/test_snprintf_fmt_1608.log
RESULT: ALL PASS (28 checks)
Total num fail: 0
```

### Rebuild discipline and restoration

* Every figure I quote came from a `make -C src` after the edit that produced it, checked `rc == 0`
  in the harness before the suite ran. Restores are `cp` (never `cp -a`) followed by another
  `make -C src`, and the harness re-ran the suite after each restore and asserted
  `ALL PASS (28 checks)` — all 29 sabotages plus 11 decoys did.
* **md5 of `src/xschem` is worthless as a build identity here** (§5.20), so I verified restoration
  by `cmp` against a pristine copy of all eleven touched files taken before I started:
  `src/{util.c,util.h,svgdraw.c,xinit.c,scheduler.c,parselabel.l,draw.c,save.c,token.c}`,
  `tests/run_regression.tcl`, `tests/headless/test_snprintf_fmt_1608.tcl` — **all byte-identical**,
  and `Makefile.conf` byte-identical to its pre-run copy (I perturbed its `CFLAGS` line three times
  for the W1/W2 probes and restored it each time). `git status --porcelain` and `git diff --stat`
  above are character-for-character what they were when I started.
* I temporarily patched the suite file once (to blind `cens_calls` and test P3's anti-vacuity) and
  restored it from a copy; it is byte-identical.
* **No repo commit. No `~/.claude/xschem_owed/` access** (283 entries before and after, untouched).
  **No `devdisplay.sh start|stop|view`.** No writes in `~/dev/xschem-op-wcard`. No
  `/tmp/xschem_emergencysave_*` created or deleted (777 before and after). Scratch confined to
  `<scratchpad>/stageCv_1608/`, except the pre-fix comparison clone at **`/tmp/b1608`** — a short
  path, per CLAUDE.md's gate rule — rebuilt in one command:
  `git clone --no-hardlinks /home/analog/dev/xschem-claude /tmp/b1608 && cd /tmp/b1608 && ./configure && make -C src`.
