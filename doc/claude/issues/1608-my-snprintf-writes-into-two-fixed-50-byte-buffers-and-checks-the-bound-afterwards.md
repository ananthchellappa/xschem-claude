# 1608 — `my_snprintf` writes into two fixed 50-byte buffers and checks the bound afterwards

**STAMP:** `v1 claim=fixed tree=91bb1bd7 stamped=2026-09-26 fix=taken open=6 by=1608-stage-C`

**Status: FIXED in the working tree 2026-09-26** by the 1608 batch's Stage C. The commit and the
T1 gate are the driver's (Stage D), so `tree=` above is still the tree the work was measured
against and wants re-stamping to the landing commit.

⚠ **THE TITLE OF THIS FILE NAMES THE SMALLER HALF OF THE DEFECT, AND FIVE OF THE ORIGINAL
FILING'S CLAIMS WERE MEASURED WRONG.** The corrections are in **"What the measurement round
found"** immediately below; every section beneath the horizontal rule is the **original filing,
kept verbatim** so the corrections can be read against it. Issue 1606 puts its correction
section at the end; this one puts it at the top because the *severity* changed, not only the
detail, and a reader who stops after the original filing would come away believing this defect
is latent. **It is not.**

Originally filed 2026-09-26 by the driver, carried out of the **1606** batch, which found it
while establishing why 1606's option 3 was not viable and deliberately did not fix it.
**Class** memory safety — user data reaching `printf` as a format string, plus four unchecked
writes in the formatter the whole tree uses.
**Related, read first:** **1351** (`psprint.c`'s `font=`-as-a-format-string, **FIXED** — this is
its un-fixed twin at the SVG back end), **1606** (**FIXED** in `eb20dc62` — the same write class
at thirteen `sprintf` sites) and **1602** (the precision dialog, whose ceiling of 71 came from
1606).

**Batch:** `doc/claude/issue_1608_batch/` — `LEDGER.md`, `STAGE_C.md`, and five receipts
(`A-measure-and-census.md`, `Av-refute.md`, `B-bound-shape.md`, `Bv-refute.md`,
`C-implement.md`).
**Fence:** `tests/headless/test_snprintf_fmt_1608.tcl`, registered in T1's `hcases`.

# What the measurement round found, 2026-09-26 — and the severity is not what was filed

Four measurement crews and one implementation crew; every receipt in
`doc/claude/issue_1608_batch/receipts/`. **Read this section before trusting anything below the
rule.**

## Correction 1 — ⚠ THE `## What is LATENT and what is not` SECTION BELOW IS FALSE. THIS IS LIVE AND FILE-BORNE.

That section's first sentence is *"**No live caller reaches it today**"*, and its third way for
that to stop being true — *"a format string that is not a literal"* — was already the case when
it was written. **Five `my_snprintf` call sites passed a value as the FORMAT STRING**, and
through two of them **a `.sch` or `.sym` FILE** reached every unchecked write:

| site (symbol) | format argument | who controls it |
|---|---|---|
| `svg_draw` (`src/svgdraw.c`) | `textfont` = a schematic text's `font=` attribute | **a `.sch` file** |
| `svg_draw_symbol` (`src/svgdraw.c`) | `textfont` = a symbol text's `font=` attribute | **a `.sym` file** |
| `svg_draw`, `svg_draw_symbol` (×2) | `tclgetvar("svg_font_name")` | any Tcl: `xschemrc`, `--preinit`, a script |
| `Tcl_AppInit` (`src/xinit.c`) | `cli_opt_rcfile` | the **command line**, `--rcfile <fmt>` |

So the `font=` attribute of an ordinary text object was a printf format string, and
`xschem print svg` on a stranger's schematic **aborted the process, headless, with no display
and no Tcl evaluation of any kind**. Driven at `91bb1bd7` (fixture: one text object,
`T {HELLO} 20 -30 0 0 0.4 0.4 {layer=4 font=<spec>}`):

```
$ env -u DISPLAY HOME=<throwaway> ./src/xschem --nogui --pipe -q <sch> --script <print svg>
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
*** buffer overflow detected ***: terminated
rc=134
```

| door | at `91bb1bd7` |
|---|---|
| `font=%-2000d` in a `.sch` | `*** buffer overflow detected ***: terminated`, **rc 134** |
| `font=%nd` in a `.sch` | `*** %n in writable segments detected ***`, **rc 134** |
| `--rcfile '%-2000d'` | `*** buffer overflow detected ***: terminated`, **rc 134** |
| `--rcfile '%s'` | **rc 139, SIGSEGV** (the `%s` arm `va_arg`s a `char *` nobody pushed, then `strlen`s it) |

So the original filing's priority argument — *"the priority argument is **not** 'it is
reachable'"* — is exactly backwards.

## Correction 2 — ⚠ `%n` IS REACHABLE FROM A FILE, AND IT IS AN ATTEMPTED ARBITRARY WRITE

This is the finding that reorders the whole fix. `%n` **alone** survives `my_snprintf`'s scanner
and is copied out literally, because `n` is not a conversion *terminator* — which is true, and
was written up as *"the classic write-what-where of format-string injection does not apply to
`my_snprintf`"*. **`%nd` is not `%n`.** `n` is not a terminator but `d` is, so `fmt` still points
at the `%`, `l = 3`, `nfmt` becomes `"%nd"` — **a writable stack array** — and glibc receives it.
Driven through both doors:

```
--rcfile '%nd'  '%nx'  '%nu'  '%nc'  '%np'  '%ng'  '%hnd'  '%lnd'   rc=134  *** %n in writable segments detected ***
.sch  font=%nd  + xschem print svg                                  rc=134  *** %n in writable segments detected ***
--rcfile '%n'                                                       rc=1    cannot find %n
--rcfile '%1$n'                                                     rc=1    cannot find %1$n
```

**The only thing that stopped the write was glibc's `PRINTF_FORTIFY` refusal of `%n` in a
non-read-only format.** That is libc hardening on one platform, not a property of this code, in
a tree that also targets C89 and Windows. Without it, `%n` consumes the already-fetched `int i`
as an `int *`.

⚠ **AND `%nd` IS A THREE-CHARACTER SPEC PRODUCING NO OUTPUT, SO IT PASSES EVERY ARITHMETIC
BOUND.** Bounding `l` and bounding the output width both leave it untouched. **The bound was
never the fix.** Only the five call sites were, which is why they landed first and on their own.

⚠ Two consequences for anyone writing a row about this: the **death message differs by
mechanism** (`*** %n in writable segments detected ***` versus `*** buffer overflow detected
***`), so a row asserting the buffer-overflow text misses the `%n` shape entirely; and no
column-0 `FATAL` line is printed for either, because `main.c`'s `sig_handler` traps
SIGINT/SEGV/ILL/TERM/FPE and **not SIGABRT**. **Assert `rc`.**

## Correction 3 — THIS IS THE UN-FIXED TWIN OF ISSUE 1351, IN THIS TREE, ALREADY FIXED NEXT DOOR

`src/psprint.c` carries a comment headed *"ISSUE 1351 — THE `font=` ATTRIBUTE IS A PostScript
NAME AND A FORMAT STRING, AND IT WAS NEITHER CHECKED NOR QUOTED … `my_snprintf(ps_font_family,
S(...), textfont)` passed user data as the FORMAT STRING, so `font=%s` read a vararg that was
never pushed"*, and now writes `"%s", ps_font_token(textfont)`. Rows `V10`/`V13` of
`tests/headless/test_ps_valid_1350.tcl` fence it. **The SVG back end was simply missed** — and
two sites *inside* `svgdraw.c` already used the correct `"%s"` form, so the four bad ones were an
inconsistency within one file.

**The SVG fix is the `"%s"` alone, deliberately not `ps_font_token()`.** That helper does two
PostScript-specific jobs: it maps the generic CSS/Cairo families onto the base-14 PostScript
names (`monospace`→`Courier`, `serif`→`Times`, `sans-serif`→`Helvetica`) because PostScript has
never heard of them, and it replaces the characters that end a PostScript *name token*. SVG has
neither problem — its `font-family` **is** that namespace, and a space inside it is legal and
meaningful (`"courier new"`), not a token terminator. Applying `ps_font_token` here would
discard the family the user asked for, which is the opposite of what 1351 needed. Rows `F1`,
`F2`, `F3` and the control `F5` of the suite therefore assert the value reaches the exported
`font-family` **verbatim**. ⚠ `F4` and `F4b`, the two `svg_font_name` sites, do **not**: they
assert an **absence** — zero per-text `style="font-family:"` attributes — because those two
sites have no verbatim observable at all. An earlier version of this paragraph said "rows
F1–F5" assert verbatim arrival, which was false of `F4`.

## Correction 4 — THE WRITE TALLY IS NOT "SIX IN TWO MECHANISMS". IT IS THIRTEEN IN FOUR.

There are **three** conversion arms plus the `%s` arm, and the filing below misses the fourth
mechanism entirely:

| mechanism | statement | sites | fires |
|---|---|---|---|
| (A) | `strncpy(nfmt, fmt, l)` into `char[50]` | 3 | `l >= 51`, `__strncpy_chk` **aborts** |
| (B) | `nfmt[l] = '\0'` | 3 | **`l == 50`, one byte past, SILENTLY** |
| (C) | `sprintf(nstr, nfmt, i)` into `char[50]` | 3 | 50 characters of output, aborts |
| (D) | `string[n+l] = '\0'` under `if(n+l > size)` | **4**, the `%s` arm included | **`n+l == size`, one byte past the CALLER's buffer, SILENTLY** |

**= thirteen unchecked write statements in four mechanisms.** On the filing's own convention
(A and B grouped as one write per arm) it is ten in three mechanisms, not six in two.

**And (B) fires FIRST and SILENTLY, which inverts the filing's assumption.** The span `fmt..f`
holds exactly `l` non-NUL bytes, so `strncpy` writes exactly `l` and pads nothing. At `l == 50`
it exactly fills `nfmt` and then `nfmt[50]` is stored — one byte past — and **a plain array store
is not fortified while `strncpy` is**, so for any larger `l` the abort happens first in program
order. Driven on all three arms (`%` + N `-` flags + a conversion letter, so the output stays two
characters and (C) is out of it):

```
l = 49   rc 1   cannot find 104-style value   <- last safe
l = 50   rc 1   cannot find 88 / 1.70922e-319 / 0x20   <- (B) WRITES nfmt[50] AND DOES NOT ABORT
l = 51   rc 134 *** buffer overflow detected ***        <- (A)
```

`l == 50` was benign on this build by luck and not by design: `objdump` puts `nfmt` at
`rsp+0x60` and `nstr` at `rsp+0xa0`, so index 50 lands in 14 bytes of alignment padding that no
`rsp` offset in the function references.

**(D) is the one that escapes into the caller, and it is silent because `string` is a pointer
parameter, so `_FORTIFY_SOURCE` cannot size it and emits no check** — exactly what 1606 measured
at `graph_marker_fmt`. Driven: `svg_font_family` is `char[80]`, and a `font=` value of exactly 80
characters emitted an 80-character `font-family`, i.e. its NUL landed at index 80, outside the
array. **rc 0, no signal, no message.** `size == 0` was also unsafe: it wrote `string[0]`.

## Correction 5 — "~748 CALLERS" IS A GREP LINE COUNT, AND FOUR DIFFERENT TOTALS EXIST

`~748` is `/usr/bin/grep -c 'my_snprintf(' src/*.c` summed, which counts comment mentions and
text inside string literals. Every figure anyone has produced for this one question, with its
instrument:

| instrument | figure |
|---|---|
| `grep -c` lines summed per file | 769 |
| source-text call expressions, comments and literals stripped (two independent parsers) | 752 / 753 |
| Stage A's source-text parser | 729 |
| **call expressions that actually COMPILE — `gcc -E` with the tree's real CFLAGS** | **722** at `91bb1bd7` (Av's parser) |
| the same instrument, this suite's own parser, after the fix | **720** (row `P3` prints it) |

**Quote the compiled one and name the instrument.** The 722→720 step is one call removed by the
fix (`my_snprintf(old_win_path, S(old_win_path), "")` became `old_win_path[0] = '\0'`) and one
artefact of Av's argument splitter. Compiled at `91bb1bd7`: 1218 conversions, max literal spec
length **5**, **zero `*`**, zero width or precision ≥ 20.

⚠ **AND A CENSUS OVER SOURCE TEXT IS A CENSUS OF SPELLINGS.** Four plants at one real caller,
each driven to rc 134: a `#define`d width (`"%" WPFX "d"`) and a `#define`d format are
**mis-bucketed as non-literal**, and **`#define XSNP my_snprintf` makes the call vanish from the
census entirely**. `gcc -E` is the only instrument that answers what compiles, and it is what row
`P1` uses.

## Correction 6 — THE COMPILER FENCE IS THE WHOLE `-Wformat` FAMILY, NOT EITHER FLAG ALONE

*(This heading is itself a correction: it first read "THE COMPILER FENCE IS `-Wformat-nonliteral`,
NOT `-Wformat-security`", which is the wrong way round for the five sites this issue is about. The
paragraph after the next one has the driven probe.)*

`format(printf,3,4)` on `util.h`'s declaration plus `-Wformat-security` reports exactly the five
real sites — but **only because all five happen to be zero-argument calls**.
`-Wformat-security` warns *only* for a non-literal format with no arguments, so
`my_snprintf(buf, n, userfmt, 7)` produces nothing at all from it. Measured on a nine-line probe.
`-Wformat-nonliteral` is the general flag; tree-wide it adds five diagnostics and no noise — the
three `sprintf(nstr, nfmt, i)` calls inside `my_snprintf` itself and `draw.c`'s two
`sprintf(tmpstr, fmt1/fmt2, …)` (1606's class). Row `W2` is `W1`'s anti-vacuity: without `W2`,
removing the attribute would make `W1` pass on a tree with every door reopened.
`-Wformat-overflow` never applies to a user function carrying the attribute at all — only to the
builtins whose destination gcc knows.

⚠ **AND THIS HEADING IS TOO STRONG, WHICH IS THE CORRECTION TO THE CORRECTION.** For the five
sites 1608 is about — all of them zero-argument calls — the flag that actually names them is
`-Wformat-security`, and `-Wformat-nonliteral` names none of them. Driven on a probe that `#include`s the real
`src/xschem.h`, re-run at the build's own CFLAGS with
`-Wformat -Wformat-nonliteral -Wformat-security -Wformat-zero-length`:

```
z.c:6:3: warning: format not a string literal and no format arguments   [-Wformat-security]
z.c:7:3: warning: format not a string literal, argument types not checked [-Wformat-nonliteral]
z.c:8:28: warning: zero-length gnu_printf format string               [-Wformat-zero-length]
```

So neither flag is "the" fence: `-Wformat-security` is the one that sees a zero-argument
non-literal format and `-Wformat-nonliteral` is the one that sees
`my_snprintf(buf, n, userfmt, 7)`. Row `W1` therefore collects the **whole `[-Wformat` family**
and must — driven, a `-Wformat-nonliteral`-only filter left `W1` GREEN with a real site
reverted. The narrow claim this correction was right about stands: the attribute plus
`-Wformat-security` alone would have missed any future site that passes an argument.

## Correction 7 — ITEM 3's "would segfault or fail to compile" IS HALF WRONG, AND THE ARM IS NOW DELETED

Which one it does depends on **how** the macro is defined. `-DHAS_SNPRINTF=` — the natural
spelling for an scconfig feature flag — is a **compile error** at `scheduler.c`'s
`"HAS_SNPRINTF=%s"` line. `-DHAS_SNPRINTF=1` — gcc's default for a bare `-D` — **compiles clean,
`-Wall` included**, and would have crashed at runtime, because nothing carried a format attribute
then. A **fifth** proof it never compiled, and the first behavioural one: `xschem globals` prints
`HAS_DUP2=1`, `HAS_POPEN=1`, `HAS_CAIRO=1` and **no `HAS_SNPRINTF=` line at all**.

**The arm and `scheduler.c`'s line are deleted, and a comment stands where the arm was**,
recording that it existed, that it never compiled anywhere, and *why enabling it was unsafe* —
the two arms' return values mean different things (bytes *written* versus bytes that *would have
been*) and five live sites consume that value as a length, one of them as
`off += my_snprintf(s + off, sz - off, …)` where `off` would pass `sz` and hand a wrapped
`size_t` to `vsnprintf`. That preserves the information without preserving the trap, which
neither deleting silently nor `#error`-ing does. The precedent that settles it is in the same
file: `log_action`'s comment records this tree **losing a process** to exactly this `#ifdef`
reading as protection — a 4971-byte Tk menu `-command` script aborting the editor on a click,
with an unsaved schematic in it. *"The `#ifdef` read as protection and was decoration."*

## Correction 8 — `parselabel.l`'s "CONFLICTING PROTOTYPE" WAS NEVER LIVE

`src/parselabel.l` spells `extern int my_snprintf(char *str, int size, const char *fmt, ...)`
against `util.h`'s `size_t`/`size_t`, and it was reported twice in this batch as two incompatible
declarations of one function in one program. **It is inside a `/* … */` block comment** (with the
rest of a dead declaration list that `xschem.h` now provides), so it has never compiled:
`gcc -E` of the flex-generated `src/parselabel.c` contains it **zero** times, and `expandlabel.y`
carries the same dead block. `util.h` holds the program's only live declaration. Both crews
greped the text without depth-counting comments — the exact decoy class the 1603 batch's rows
`S1`–`S4` were defeated by. The dead copy has been re-spelled to match `util.h` so the next grep
does not refile it, and row `S3` asks the question of **preprocessed output** instead.
⚠ **AND `S3` HAD TO BE RE-POINTED AFTERWARDS**, because "zero declarations taking an `int size`"
is a property of one spelling: un-commenting the dead declaration **as re-spelled** left `S3`
green, and the only edit that reddened it — restoring the old `int`/`int` line — is a hard
compile error (`make` rc 2), so `make` never completes and every behavioural row would be
scoring a stale binary. `S3` now requires **exactly one** declaration of `my_snprintf` in the
preprocessed unit, carrying `format(printf, 3, 4)`. Un-commenting the dead declaration builds
clean, makes it two, and reddens it. Driven: `decls=2 want=1`.

## Correction 9 — THE FIX HAD ONE OUTPUT DELTA, AND (D)'s THRESHOLD IS THE RUN BEFORE THE `%`, NOT THE LENGTH OF THE VALUE

Two things, both re-driven against a **from-scratch build of `91bb1bd7`** with `--nogui` and
`DISPLAY` unset, over `font=` runs of `Q` of 78, 79, 80, 81 and 2000 characters through **both**
SVG doors (a `.sch`'s own text → `svg_draw`, and a `.sym` text reached through an instance →
`svg_draw_symbol`).

**(a) THE ONE BEHAVIOUR DELTA IN EXPORTED OUTPUT, now closed.** `svg_font_family` is `char[80]`.
Before the fix, a `font=` value with **no `%` in it** that did not fit was left out of the buffer
**entirely** — with no conversion in the format the tail copy `if(!overflow && n+l+1 <= size)` is
`my_snprintf`'s only writer and it skips a run that does not fit — so the array still held the
`svg_font_name` it had been pre-loaded with two lines earlier, the `strcmp` in
`svg_draw_string_line()` matched, and **no attribute was emitted**. After the fix the value goes
through the `%s` arm, which writes the `'\0'` first and *then* finds the value too long, so the
array comes back **empty** and the `strcmp` differs: `style="font-family:;"`. That is **not a valid
CSS declaration** — an empty value is not a font name — so it asserts something false about the
document where an absent attribute correctly says nothing. Fixed with an emission-site guard,
`if(svg_font_family[0] && strcmp(...))`, in `svg_draw_string_line()` — the **only** reader of
`svg_font_family` in the file. Not in `my_snprintf`, which ~720 callers share and which must not
grow SVG-specific behaviour.

Measured, both binaries, both doors:

| `font=` length | 91bb1bd7 | fix as first landed | fix + guard |
|---|---|---|---|
| 78, 79 | value verbatim | value verbatim | value verbatim |
| 80, 81, 2000 | **no attribute** | `style="font-family:;"` | **no attribute** |

All **ten** exported `.svg` files are **byte-identical** between `91bb1bd7` and the guarded tree.
So the whole 1608 change is **output-neutral for every `font=` / `svg_font_name` value containing
no `%`**; values containing a `%` are not byte-identical and must not be — those are the defect.

⚠ **ONE SITE IS DELIBERATELY *NOT* THE PRE-FIX OUTPUT.** `svg_draw_symbol()`'s pin-name pass takes
`svg_font_family` from a `PINLAYER` rect's `name_font` token and **already used the `"%s"` form at
`91bb1bd7`**, with no pre-load of `svg_font_name` before it — so an 80-character `name_font`
emitted `style="font-family:;"` on **both** trees (driven, with `B 5 … {name=PA dir=in
show_pinname=true name_font=<80 chars>}`). The guard suppresses that too. Same invalid
declaration, same cure; named here rather than left in a diff.

⚠ **AND THE GUARD TOOK TWO ROWS' SABOTAGE OBSERVABLE AWAY.** Rows `F4`/`F4b` assert an *absence*
of per-text `style="font-family:"`, and their reverted shape **was** that empty attribute. With the
guard in place and only `svg_draw()`'s `svg_font_name` site reverted, the suite came back
`RESULT: 3 FAILED (31 passed)` with **`F4` GREEN** and the three reds `W1`, `P1` and `X1` — the
compiler's opinion, the preprocessed census and the citation checker, **none of which runs the
binary**. Exactly the gap `F4b` was invented to close, reopened one level down. Both fixtures now
set `svg_font_name` to `Zz%-2000d` rather than `%-2000d`, so the refusal writes the prefix and then
refuses, leaving a **non-empty** wrong family (`style="font-family:Zz;"`), and both redden again.

**(b) (D)'s THRESHOLD WAS MIS-STATED IN A SHIPPED COMMENT.** `src/util.c`'s
`MY_SNPRINTF_PREFIX_GUARD` said the one-byte-past store was reached by *"a `font=` value of exactly
80 characters"*. **Refuted**: a plain 80-character value emits **no font-family attribute at all**
on `91bb1bd7`, because it never enters a conversion arm. The store `string[n+l] = '\0'` lives only
in the four conversion arms, so what triggers it is `l = fmt - prev == size` — the **literal run
before the first conversion spec** being exactly 80 characters. Driven on `91bb1bd7`:

| `font=` value | emitted font-family length |
|---|---|
| `<78×Q>%d` (80 chars) | 78 |
| `<79×Q>%d` (81 chars) | 79 |
| `<80×Q>%d` (82 chars) | **80 — NUL at index 80, one past `char[80]`, rc 0, silent** |
| `<81×Q>%d` (83 chars) | no attribute |

The comment now says the run, not the value.

## What the fix is

**Five call sites** — `svgdraw.c` ×4 and `xinit.c` ×1 — take the `"%s", <value>` form. That
alone closes every file-borne and command-line door, `%n` included, and it is the whole primary
fix.

**`util.c`'s `my_snprintf`** then gets defence in depth, because it fixes a death the call sites
do not: `%.6f` of ±`DBL_MAX` from `scheduler.c`'s `net_hilight_march_offset` getter, which aborted
at every buffer size tried (317 characters into a 50-byte scratch). One gate,
`my_snprintf_spec_ok(spec, len, sizeof nfmt, sizeof nstr)`, runs before `strncpy` and holds three
separately-removable guards:

* **GUARD 1** `len >= nfmtsize` — (A) **and** (B) together, deliberately: (B)'s threshold is the
  lower one and there is no `l` where one fires and the other does not. Two guards on one path
  would mean neither had a row that reddens on its own removal.
* **GUARD 2** a **whitelist**: the spec body may hold only `- + space # .`, digits, and the length
  modifiers `l` and `h`. Everything else is refused — `n`, `L`, `q`, `z`, `j`, `t`, `*` and `'`.
  A whitelist rather than a digit scan because a scan silently trusts what it does not recognise:
  `L` alone breaks GUARD 3's arithmetic (`%.0Lf` of `LDBL_MAX` measures 4933 characters against an
  estimate of 320), and `'` reaches 412 characters for `%'.0f` of `-DBL_MAX` in a grouping locale
  — **measured**, against a locale built with `localedef -i en_US -f UTF-8`, where `%'.6f` is the
  spec that measures 419 and `%'.180f` 593. (An earlier version of this line said `'` "would be
  419"; 419 belongs to `%'.6f`, and the figure is now driven rather than derived.) Dormant here
  only because nothing in `src/` calls `setlocale`. `l` and `h` are permitted because three live
  callers use them and their widest output is 20 characters.
* **GUARD 3** `max + 320 < nstrsize` with `nstr` grown to `MY_SNPRINTF_NSTR` (512) — one loose
  over-estimate from the measured `max(width, 311 + precision)`, rather than per-arm casework,
  which is what 1606's post-mortem says to avoid. `sprintf("%f", -DBL_MAX)` is 317 and
  `sprintf("%.200f", -DBL_MAX)` is 511 on this glibc; width and precision never add.

**(D)'s guard becomes `>=` in all four arms**, and a refusal NUL-terminates at `string[n]` rather
than leaving the destination unwritten.

**And `svgdraw.c` gets one guard that is not about memory at all**: `svg_font_family[0] &&` on the
per-text `style="font-family:"` emission in `svg_draw_string_line()`, which is what makes the whole
change output-neutral. Correction 9 above is the measurement and the two consequences.

⚠ **AND THE ORDERING IS LOAD-BEARING.** The gate must run before `strncpy`, but a `break` there
leaves the caller's buffer **entirely unwritten**, which is not this function's overflow shape:
the existing path breaks *after* the prefix write, so `string[n]` is always `'\0'` and the caller
gets the prefix so far. A version that broke early was built and driven — a planted caller printed
`|/tmp/claude-1000/-ho|` out of uninitialised stack, and the live `--rcfile zz%.192f` returned
**rc 0 having silently sourced a different rc file** instead of reporting `cannot find zz`. Hence
a local `refuse` flag: compute the verdict, skip `strncpy`, fall through the prefix write, then
break. With that ordering nothing a user reads changes shape, so **no ruling was needed**;
without it, one would have been.

## Still open — named, not fixed

1. **The `%s` arm discards a field width.** `"[%-12s]"` emits `[AB]` with no padding, driven: that
   arm never builds `nfmt`. A developer who writes `%-60s`, sees no padding and "fixes" it lands
   on the aborting arm — which is the very stylistic precedent the filing below cites.
2. **`%ld`/`%lu`/`%hu` (live) and `%hhd`/`%zd`/`%jd`/`%td` (now refused) mis-fetch.** The arms do
   `va_arg(args, int)` and forward the spec verbatim, so `sprintf` reads 8 bytes from a 4-byte
   value. It works only by x86-64 zero-extension; a negative `long` or one ≥ 2³² prints wrong.
   GUARD 2 permits `l` and `h` precisely so the three live callers keep printing what they print,
   so this one is **preserved on purpose** and is not a bound problem.
3. **The `font=` value is still unescaped in the exported SVG.** It lands inside a double-quoted
   XML attribute, so a `"` in a font name can still break it. An output-escaping defect, not a
   memory write; it needs its own issue.
4. **`psprint.c` takes a size from a different object.** `my_snprintf(ps_font_family,
   S(ps_font_name), "Helvetica")` at two sites. Both arrays are `[80]` today, so it is harmless
   now and live the moment either is resized.
5. **(E) `my_snprintf` can still return without writing anything — but NOT through the shape
   first filed here.** ⚠ Measured on the shipped tree: `my_snprintf(u, 2, "abcd%d", 7)` returns 0
   and `u` is `""`, i.e. **written**. That was the pre-fix behaviour; the (D) refusal's
   `if(n < size) string[n] = '\0'` closed it, and row `G14` is what keeps it closed on all four
   arms. The shape that **does** survive is a format with **no conversion at all** that does not
   fit — `my_snprintf(u, 2, "abcd")` returns 0 and leaves `u` untouched (driven: all 4095 canary
   bytes intact), because the tail copy `if(!overflow && n+l+1 <= size)` is the only writer on
   that path and it is skipped. So the caller of a conversion-free format into an uninitialised
   buffer still reads garbage. Also still true at `size == 0`, where there is no byte to write.
   Named limit `L8` of the suite says the same; no row asserts the surviving shape, because
   asserting it would be asserting a defect.
6. **No non-fortified and no Windows build was measured.** Every abort quoted here is
   `_FORTIFY_SOURCE=3` with `__sprintf_chk`/`__strncpy_chk` on x86-64 glibc. Without fortify,
   `font=%nd` is a write through an unpushed vararg rather than an abort, and (A) writes `l`
   unbounded bytes with `nfmt[l]` a NUL at an arbitrary offset. `XSchemWin/` exists and nothing
   was compiled for it. This is the reason GUARD 2 refuses `%n` itself instead of trusting libc.

---

# THE ORIGINAL FILING, 2026-09-26 — kept verbatim; five of its claims are corrected above

**Status: OPEN — filed 2026-09-26** by the driver, carried out of the **1606** batch, which
found it while establishing why 1606's option 3 was not viable and deliberately did not fix it.
**Class** memory safety — an unchecked `sprintf` into a fixed stack buffer, in the formatter
the whole tree uses.
**Related, read first:** **1606** (**FIXED** in `eb20dc62` — the same class at thirteen
`sprintf` sites; its receipts hold the measurements this issue starts from) and **1602**
(the precision dialog, whose ceiling of 71 came from 1606).

---

## The site — READ at `91bb1bd7`

`my_snprintf` in `src/util.c` has two definitions. `HAS_SNPRINTF` **is defined nowhere in this
tree** — not in `config.h`, not in `config.h.in`, never probed by `scconfig`, no `-D` on the
compiler line — so the `#else` arm, a **hand-rolled** formatter, is what compiles. Confirmed
four ways in the 1606 batch, including `nm -S src/util.o` (`my_snprintf` is 1615 bytes, which the
twelve-line `vsnprintf` arm cannot be) and `nm -u src/util.o` listing `__sprintf_chk` and
**no `vsnprintf`**.

That formatter walks the format string and handles conversions in **three** arms, each with the
same two-line shape:

| arm | conversions |
|---|---|
| `src/util.c:685` | `d`, `x`, `c`, `u` |
| `src/util.c:707` | `p` |
| `src/util.c:730` | `g`, `e`, `f` |

Each opens `char nfmt[50], nstr[50];` and then does this:

```c
  l = f - fmt + 1;
  strncpy(nfmt, fmt, l);          /* (A) l is the conversion spec's length -- UNBOUNDED */
  nfmt[l] = '\0';                 /* (B) and so is this index */
  ...
  nlen = sprintf(nstr, nfmt, i);  /* (C) writes FIRST ... */
  if(n + nlen + 1 > size) {       /*     ... and checks the caller's size AFTERWARDS */
    overflow = 1;
    break;
  }
```

**So there are six unchecked writes, in two distinct mechanisms, and the 1606 batch's note named
only one of them.**

* **(C), the output buffer.** `sprintf` writes the whole conversion into `char nstr[50]` before
  anything looks at `size`. The caller's buffer is irrelevant: a conversion wider than 49
  characters overflows this arm's own scratch. ⚠ **This is not only about precision, and not only
  about floats** — a *field width* does it with a short spec: `%-2000d` is a seven-character
  conversion producing 2000 characters, in the **integer** arm. `%f` of `1e300` is 316
  characters. The 1606 batch recorded this as a float-precision hazard; it is wider than that.
* **(A) and (B), the format buffer.** `l` is the length of the conversion specification taken
  straight out of the caller's format string, with no comparison against `sizeof(nfmt)`. A
  conversion spec longer than 49 characters overflows `nfmt` via `strncpy`, and `nfmt[l] = '\0'`
  then writes a NUL at an arbitrary offset past it. **Nobody has looked at this half at all.**

## Why this is filed separately from 1606, and why it is not merely 1606 again

1606 was thirteen call sites in four files, each with its own destination buffer, and the fix was
a clamp at each. This is **one function with ~748 callers** (`/usr/bin/grep -c 'my_snprintf('
src/*.c`, summed, minus the two definitions), and the overflow is of the function's **own**
stack, so no caller can prevent it and no caller's buffer size makes it safe.

It is also the reason 1606 rejected two of its own options, which makes this the load-bearing
blocker on a cleaner fix for that whole class: 1606's option 3 (teach `my_snprintf` the `*`
precision) **cannot be done without fixing this first**, because a working `*` would route
exactly the wide conversions this buffer cannot hold.

## What is LATENT and what is not — and the distinction matters for priority

**No live caller reaches it today**, measured in the 1606 batch: every `my_snprintf` call with a
float conversion is `%g`, `%.8g`, `%.10g`, `%.15g`, `%.16g`, `%.17g` or `%.10e` (all ≤ 24
characters), and the only `%f` is `scheduler.c`'s `"%.6f"` on a bounded march offset. ⚠ **That is
a statement about today's format strings, not about the function**, and it has three ways to stop
being true, none of which involves touching `util.c`:

1. **Someone writes a wide conversion.** `%-60s` is already common style elsewhere in this tree;
   a `%-60d` in a new `my_snprintf` call is a silent stack overflow.
2. **Someone prints an unbounded double.** A plain `%f` of any large value is 300+ characters.
   `%.6f` is safe only because its subject is bounded, which is a property of the caller.
3. **A format string that is not a literal.** If a format ever arrives from a variable or a
   property, both the spec length and the output width become data.

So the priority argument is **not** "it is reachable"; it is that the guard is two lines, the
function is shared by the whole tree, and the failure mode is a stack write that
`_FORTIFY_SOURCE` catches only because the destination is a local array — which is exactly what
1606 measured is **not** true when a destination is a pointer parameter (`graph_marker_fmt`'s
overflow produced a spliced 279-digit string, rc 0, no signal).

## What must be measured before it is fixed

1. **Drive (C) on all three arms.** `%-2000d`, `%f` of `1e300`, `%.60g`. Confirm the abort (or
   the silent corruption) and say which it is per arm. ⚠ Do it through a real `my_snprintf` call,
   not only a standalone extraction — the 1606 batch's figures for this function came from a
   `sed`-extracted copy, and one crew's quoted number from such a probe turned out not to be a
   fact about the code.
2. **Drive (A)/(B).** A conversion spec over 49 characters. Establish whether it is reachable
   from any format string in the tree, and whether `strncpy`'s own truncation semantics make (A)
   safe while (B) is not — `strncpy(dst, src, 50)` with `l == 60` writes 60 bytes, but the
   arithmetic needs checking rather than assuming.
3. **Whether the `#ifdef HAS_SNPRINTF` arm should simply be deleted.** It has never compiled on
   any platform — 1606 proved that from `scheduler.c`'s `my_snprintf(res, S(res),
   "HAS_SNPRINTF=%s\n", HAS_SNPRINTF)`, which hands `%s` an `int` and would segfault or fail to
   compile the moment the macro were defined. A second, unbuildable definition of a function used
   748 times is a trap for the next reader, and 1606 costed enabling it as **worse** than leaving
   it (five sites consume a return value whose meaning differs between the two arms, three of them
   as an accumulator where `off` can pass `sz` and hand a negative `sz - off` to a `size_t`).
4. **What the function should DO on an over-wide conversion.** It currently sets `overflow` and
   `break`s, and the caller gets a truncated string plus a `dbg(1, …)`. Truncating one conversion
   is consistent with that; so is refusing. ⚠ Whichever is chosen, note that 1606 established
   truncation here is **user-visible badly** — a number cut mid-digit with its exponent and
   suffix amputated — so a bound that truncates the *number* is worse than one that shortens the
   *request*, and that argument should be re-run for this site rather than inherited.

## Still open

1. Bound (C) on all three arms, before the write.
2. Bound (A)/(B), or prove the spec length cannot exceed the buffer and say so in a comment with
   the measurement.
3. Decide truncate-vs-refuse, per item 4 above. Internal correctness unless it changes a string a
   user reads, in which case it is a ruling.
4. Decide whether to delete the never-compiled `HAS_SNPRINTF` arm, or to fence it so it cannot
   read as available. ⚠ `scheduler.c`'s `%s`-given-an-int is a one-word fix either way and should
   not be left as the only evidence.
5. A test row per bound that reddens when the bound is removed. ⚠ **Read the 1606 suite's NAMED
   LIMITS header first**: that batch spent four rounds discovering that a static row over C text
   decides a set of spellings rather than a property of the program, and that the fences without
   that weakness are behavioural rows and compiler-diagnostic rows. A behavioural row is available
   here — `my_snprintf` is callable from a test harness through any verb that formats — so prefer
   one.
