# Receipt A — `measure:arms+census`

**Stage A of the 1608 batch. Measurement only.** Tree at `91bb1bd7`, `src/xschem` rebuilt
(`make -C src` → *Nothing to be done*, i.e. already current) before every figure below. No source
file was changed: `git status --porcelain` at the end is byte-identical to the start (the
pre-existing `M doc/claude/issues/NUMBERING.md`, `?? .xschem/`, `?? doc/claude/issue_1608_batch/`,
`?? doc/claude/issues/1608-….md`, `?? sky130A/…/debug_st1/`). No `src/*.o` mtime moved; the two
compile experiments below wrote to the scratchpad or used `-fsyntax-only`.

Build facts this receipt rests on: `CFLAGS=-pipe -O2 …` with no `-D` and no `-W`; gcc
15.2.0 (Ubuntu 15.2.0-16ubuntu1); `_FORTIFY_SOURCE` defaults to **3** at `-O2`
(`echo | gcc -O2 -dM -E - | grep -i fortify`). `nm -u src/util.o` lists `__sprintf_chk`,
`__strncpy_chk`, `__memcpy_chk` and **no `vsnprintf`**; `nm -S src/util.o` gives
`my_snprintf` size `0x64f` = **1615 bytes**. The hand-rolled `#else` arm is what compiles.

---

## 0. HEADLINE — H1 is REFUTED, and there is a LIVE overflow in the tree today

`DECISIONS.md` H1 predicts *"(C) aborts on all three arms **and (A)/(B) is unreachable from any
format string in this tree**"*, resting on *"this tree's formats are all literals"*, which it
flags as the bullet most likely to be wrong. It is wrong.

**Five `my_snprintf` call sites pass a NON-LITERAL format string**, and three of them take that
string straight from user or file data:

| site (symbol) | format argument | who controls it |
|---|---|---|
| `Tcl_AppInit` (`src/xinit.c`) | `cli_opt_rcfile` | the **command line**, `--rcfile <fmt>` |
| `svg_draw_symbol` (`src/svgdraw.c`) ×1 | `textfont` = a symbol text's `font=` attribute | **a `.sym` file** |
| `svg_draw` (`src/svgdraw.c`) ×1 | `textfont` = a schematic text's `font=` attribute | **a `.sch` file** |
| `svg_draw_symbol`, `svg_draw` (`src/svgdraw.c`) ×2 | `tclgetvar("svg_font_name")` | any Tcl: `xschemrc`, `--preinit`, a script |

So the `font=` attribute of an ordinary text object is a **printf format string**, and
`xschem print svg` on a schematic carrying one **aborts the process, headless, with no display
and no Tcl evaluation of any kind**:

```
$ env -u DISPLAY HOME=<throwaway> ./src/xschem --nogui --pipe -q <sch> --script <print svg>
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
*** buffer overflow detected ***: terminated
rc=134
```
(fixture: `T {HELLO} 20 -30 0 0 0.4 0.4 {layer=4 font=%-2000d}`; `SVGDONE` never printed, so the
abort is inside `xschem print svg`. **Zero column-0 `FATAL` markers** — see §7.)

**This is not a new class in this tree — it is the un-fixed twin of a defect already fixed at the
other export back end.** `src/psprint.c` carries a 30-line comment headed
*"ISSUE 1351 — THE `font=` ATTRIBUTE IS A PostScript NAME AND A FORMAT STRING, AND IT WAS NEITHER
CHECKED NOR QUOTED … `my_snprintf(ps_font_family, S(...), textfont)` passed user data as the FORMAT
STRING, so `font=%s` read a vararg that was never pushed"*, and `tests/headless/test_ps_valid_1350.tcl`
rows **V10** and **V13** fence it (*"`font=` containing printf conversions does not crash the export
(HEAD: FATAL: signal 11)"*). `psprint.c` now writes `my_snprintf(ps_font_family, S(...), "%s",
ps_font_token(textfont))`. **`svgdraw.c` was not fixed with it**, and inside `svgdraw.c` itself two
nearby sites already use the correct `"%s"` form (the annotation-overlay font and the
`pfont`/`svg_font_name` fallback), so the four bad ones are an inconsistency within one file.

⚠ Consequence for the batch: 1608 cannot be filed as latent. `live_overflow = true`.

---

## 1. The door used, so no figure here comes from a `sed`-extracted copy

Every number below came through a **real `my_snprintf` call in the built `src/xschem`**. Three
independent doors, all driven:

* **D1 `--rcfile`** — `Tcl_AppInit`'s `my_snprintf(name, S(name), cli_opt_rcfile)`. The formatted
  result is echoed verbatim by the next line (`fprintf(errfp, "Tcl_AppInit() err 2: cannot find
  %s\n", name)`), so this door **prints the conversion's output**, which makes it the measuring
  instrument for widths. `size` here is `PATH_MAX`, so (C)'s post-hoc size test can never fire and
  what is measured is purely `nstr[50]`. Not gated by `running_in_src_dir` (only by
  `cli_opt_load_initfile`), so it works in-tree.
* **D2 `font=`** — `svg_draw`/`svg_draw_symbol`, through `xschem print svg`. File-borne, headless.
* **D3 `svg_font_name`** — same two sites, format from a Tcl global.

Sanity check that D1 is the real call: `--rcfile /nonexistent/zz` →
`Tcl_AppInit() err 2: cannot find /nonexistent/zz`, rc 1.

**A fourth door, for a LIVE LITERAL caller with a value I control from a file**, used for the
census widths in §4: `select_wire` (`src/select.c`) formats
`"n=%4d x = %.16g  y = %.16g  w = %.16g h = %.16g"` and `statusmsg` records it where
`xschem get statusmsg` can read it. A wire at extreme coordinates gives, verbatim:

```
N -1.2345678901234567e+300 -9.8765432109876543e-308 1.2345678901234567e+300 9.8765432109876543e-308 {lab=A}
  xschem select wire 0 nodraw ; xschem get statusmsg
→ n=   0 x = -1.234567890123457e+300  y = -9.876543210987653e-308  w = 2.469135780246913e+300 h = 1.975308642197531e-307
  xschem get bbox
→ -1.23457e+300 -9.87654e-308 1.23457e+300 9.87654e-308
```
Widest single `%.16g` conversion: **23** characters. Widest `%g`: **13**.

---

## 2. Mechanism (C) — the output buffer, `sprintf(nstr, nfmt, x)` into `char nstr[50]`

**All three arms ABORT. Fortify sees `nstr` because it is a local array of `my_snprintf`'s own
frame, exactly as H1 predicted.** Verbatim outcome in every aborting case:
`*** buffer overflow detected ***: terminated`, **rc 134**.

The threshold is the same on all three arms: **49 characters of conversion output survive, 50
abort** (49 + NUL = 50 = `sizeof nstr`).

| arm | driven via D1 | outcome |
|---|---|---|
| `d x c u` | `%-48d` → `72` + 46 spaces (48 ch) | survives, rc 1 |
| `d x c u` | `%-49d` → `64` + 47 spaces (49 ch) | survives, rc 1 |
| `d x c u` | `%-50d` | **`*** buffer overflow detected ***: terminated`, rc 134** |
| `d x c u` | `%-51d`, `%-60d`, `%-2000d`, `%0500x` | **abort, rc 134** |
| `p` | `%p` → `0x78` | survives, rc 1 |
| `p` | `%-49p` → `0x18` + 45 spaces | survives, rc 1 |
| `p` | `%-50p`, `%-60p`, `%-2000p` | **abort, rc 134** |
| `g e f` | `%f` → `0.000000` | survives, rc 1 |
| `g e f` | `%-49f` → `0.000000` + 41 spaces | survives, rc 1 |
| `g e f` | `%.40e` → `1.7092201017877924195788397389276118376969e-319` (46 ch) | survives, rc 1 |
| `g e f` | `%-50f`, `%.43e`, `%.60e`, `%.60g`, `%-2000f` | **abort, rc 134** |

Also driven through D2 (`font=`), i.e. from a schematic file: `%-2000d` → abort rc 134;
`%.60g` → abort rc 134. Through D3 (`svg_font_name`): `%-2000d` → abort rc 134.

**Two extra shapes, both only reachable through a non-literal format:**

* `%*d` — the scanner does not understand `*`, so it passes `"%*d"` to `sprintf` having consumed
  **one** vararg; `sprintf` then takes the width from that and the value from the next (absent)
  slot. Driven: `--rcfile '%*d'` → **abort, rc 134**. A `%*d` is therefore a (C) overflow with a
  three-character spec.
* `%n` — **not** in the handled set, so the scanner ignores it and it is copied out literally:
  `--rcfile '%n'` → `cannot find %n`, rc 1. The classic write-what-where of format-string
  injection does **not** apply to `my_snprintf`. Worth recording so nobody over-claims.

---

## 3. Mechanisms (A) and (B) — `strncpy(nfmt, fmt, l)` and `nfmt[l] = '\0'`

### `strncpy`'s semantics here, worked out rather than assumed

`l = f - fmt + 1` is a `size_t`, the length of the conversion spec from `%` to the conversion
letter inclusive. `src = fmt` points into the format string and the span `fmt..f` is exactly `l`
non-NUL bytes, so `strncpy` finds no NUL inside `l` and therefore **writes exactly `l` bytes and
pads nothing**. Hence:

| `l` | (A) `strncpy(nfmt, fmt, l)` into `char[50]` | (B) `nfmt[l] = '\0'` | which fires |
|---|---|---|---|
| ≤ 49 | 49 bytes, fits | index ≤ 49, in bounds | neither |
| **50** | 50 bytes, **exactly fills** | index **50 — one byte PAST the array** | **(B) only** |
| ≥ 51 | `n > destlen` → `__strncpy_chk` **aborts** | never reached | **(A)**, and it aborts before (B) can run |

So **(B) fires first as `l` grows, at exactly `l == 50`, and it is bounded to a single byte**,
because for any larger `l` the fortified `strncpy` aborts first *in program order*. Driven on all
three arms (D1, `%` + N filler `0`s + conversion letter, so the width is 0 and (C) stays out of it):

| `l` | `d` arm | `g` arm | `p` arm |
|---|---|---|---|
| 49 | `cannot find 104`, rc 1 | `cannot find 1.70922e-319`, rc 1 | `cannot find 0x58`, rc 1 |
| **50** | `cannot find 88`, **rc 1 — SURVIVES SILENTLY** | `cannot find 1.70922e-319`, **rc 1** | `cannot find 0x20`, **rc 1** |
| 51 | **abort, rc 134** | **abort, rc 134** | **abort, rc 134** |
| 52, 60, 62, 202 | **abort, rc 134** | **abort, rc 134** | **abort, rc 134** |

### Why `l == 50` is silent, and why that is a property of THIS build, not of the code

Disassembly of `my_snprintf` in `src/util.o` at `91bb1bd7`: gcc merged the three arms' scopes onto
the **same** two slots, `nfmt` at `rsp+0x60` and `nstr` at `rsp+0xa0`, each passed to
`__strncpy_chk`/`__sprintf_chk` with an object size of `0x32` = 50. (All three arms show
`mov $0x32,%ecx; lea 0x60(%rsp),%rdi; call __strncpy_chk` and
`lea 0xa0(%rsp),%rdi; mov $0x32,%edx; call __sprintf_chk`; the `nfmt[l]` store appears as
`movb $0x0,0x60(%rsp,%rdx,1)` / `…,%rbp,1)`.) `nfmt` therefore occupies `rsp+0x60..0x91` and
`nstr` starts at `rsp+0xa0`, so `nfmt[50]` = `rsp+0x92` lands in **14 bytes of alignment padding**.
That is why it is benign here. It is not a bound: a different `-O` level, a different compiler, or
one more local could put a live variable at that byte.

### Reachability of (A)/(B)

* **From a literal format: unreachable.** Over all 724 literal formats, the maximum spec length
  `l` is **4** in the integer arm (`%02x`), **5** in the float arm (`%.16g`), **2** in the `p` arm
  and **2** for `%s`. It needs 50.
* **From a non-literal format: REACHABLE AND DRIVEN.** `--rcfile` with `l = 62` → abort rc 134;
  `font=` with `l = 62` in a `.sch` → abort rc 134; `svg_font_name` with `l = 62` → abort rc 134.
  So the `nfmt` half is **not** a footnote — it is live through the same three doors as (C).

---

## 4. A FOURTH mechanism the issue does not name — and it is the one that escapes into the CALLER

All four arms (the `%s` arm included, which the plan treats as out of scope) contain:

```c
  l = fmt - prev;
  if(n+l > size) { ... break; }      /* > , not >= */
  memcpy(string + n, prev, l);
  string[n+l] = '\0';                /* (D): index n+l == size is ONE BYTE PAST */
```

When `n + l == size` the guard passes and `string[size]` is written — one byte past the **caller's**
buffer. `string` is a pointer parameter, so per the 1606 batch's own finding `_FORTIFY_SOURCE`
cannot size it and emits no check. **Driven, observable, silent:**

`svg_font_family` is `char[80]`, so `size == 80`. A `font=` value of exactly 80 literal characters
followed by `%d` makes `l == 80 == size`:

| literal prefix | emitted `style="font-family:…"` length |
|---|---|
| 78 | 78 |
| 79 | 79 |
| **80** | **80** |
| 81 | attribute absent (guard fires, `overflow=1`, string untouched) |

An 80-character string in an 80-byte array means **its NUL terminator is at index 80, outside the
array**. rc 0, no signal, no message. (In this build `svg_font_family` sits at `.data+0x60` size
`0x50` and `svg_font_weight` at `.data+0xc0`, so index 80 is again alignment padding — benign here,
by luck, not by design.)

**Tally.** (A) 3 sites, (B) 3 sites, (C) 3 sites, (D) **4** sites = **13 unchecked write
statements in four mechanisms**. On the issue's own counting convention (A and B grouped as one
write per arm) the figure is **10 in three mechanisms**, not *"six unchecked writes, in two
distinct mechanisms"*. Not measured: whether (D) is reachable from any **literal** format — that
needs each of the 729 sites' buffer size against the length of each literal run, which I did not
census. It is reachable from the non-literal doors, measured above.

**A fifth, cosmetic asymmetry:** in the `d/x/c/u` and `p` arms the prefix guard is a bare `break`
with **no `overflow = 1`**, where the `%s` and `g/e/f` arms set it. Worked out rather than
assumed: after the bare break, `l_final = f - prev >= fmt - prev`, and the failing condition was
already `n + (fmt-prev) > size`, so `n + l_final + 1 <= size` is necessarily false and the tail
copy is skipped either way. **Functionally identical today**; it is a trap if the arithmetic ever
changes. Carried forward, not fixed.

---

## 5. The census — all `my_snprintf` call sites, re-derived

Method: comment-stripped (block and line, depth-aware of string literals), paren-balanced call
extraction, top-level argument split, adjacent-string-literal concatenation with C escape decoding
(including `\`+newline continuations), then the format scanned with **`my_snprintf`'s own scanner
semantics** — `fmt` is set at every `%` and a conversion closes at the next `s`/`d`/`x`/`c`/`u`/
`p`/`g`/`e`/`f`, so a stray `%` far from a letter would show up as a large `l`.

**729 `my_snprintf(...)` call expressions in `src/*.c`** — 724 literal + 5 non-literal. The
issue's *"~748"* is a `grep -c` line count; it includes **24 occurrences inside string literals**
(`xinit.c` alone has 17, in the `globals`/paths text) and comment mentions. Also confirmed: no
`my_snprintf` call outside `src/*.c` (the `.y`/`.l` sources hold 4 calls, all present in the
generated `.c`, all literal).

**1229 conversions scanned**: 652 `%s`, 363 integer-arm, 213 float-arm, 1 `%p`.

### Widest conversion each arm's LIVE callers can produce

Widths measured against glibc for every spec the census found (separate 30-line probe, labelled as
a measurement of **glibc's printf**, i.e. of how many bytes `sprintf` deposits in `nstr[50]`; the
composition with `my_snprintf` is established by reading the function and confirmed by §2's driven
probes). `nstr` holds 49 + NUL.

| arm | distinct live specs (count) | widest output | headroom to 49 |
|---|---|---|---|
| `d x c u` | `%d` 293, `%02x` 24, `%c` 18, `%u` 18, `%4d` 7, `%ld` 2, `%lu` 1, `%hu` 1 | **11** in practice (`%d` of `INT_MIN`); 20 for `%ld`/`%lu` if their upper half is garbage | 38 (29 worst case) |
| `p` | `%p` ×1 (`src/util.c`, `dbg_var > 2`) | **14** | 35 |
| `g e f` | `%.16g` 102, `%g` 84, `%.10g` 13, `%.17g` 8, `%.6g` 2, `%.10e` 1, `%.15g` 1, `%.6f` 1, `%.8g` 1 | **24** (`%.17g`) | 25 |
| `%s` | — | no `nfmt`/`nstr`; bounded by its own explicit checks | — |

Per-spec glibc maxima: `%g` 13, `%.6g` 13, `%.8g` 15, `%.10g` 17, `%.15g` 22, `%.16g` 23 (driven
end-to-end at 23 in §1), `%.17g` 24, `%.10e` 18, `%d` 11, `%u` 10, `%c` 1, `%02x` 8, `%4d` 11,
`%hu` 5, `%ld`/`%lu` 20, `%p` 14 — **and `%.6f` 317.**

### What each of the three "changes the answer" shapes actually is

* **`%*d` (width from an argument): ZERO in any literal format.** No literal contains `%*` or
  `%.*`. (One literal, `xinit.c`'s `pwd_dir` normaliser, contains `.*` — inside a Tcl `regsub`
  regex, not after a `%`.)
* **`%-Nd` with a large N: none.** The widest field width anywhere is `%4d` (7 sites, `select.c`).
  The widest spec of any kind is `%02x`.
* **A non-literal format: FIVE, and they are §0.** This is the one that refutes H1.

### `%.6f` — the one literal spec that CAN exceed 49, and its bound re-derived not inherited

`scheduler.c`'s `net_hilight_march_offset` getter: `my_snprintf(buf, S(buf), "%.6f",
net_hilight_march_offset(&xctx->net_hilight_style[idx], net_hilight_now_ms()))`. `%.6f` of
`DBL_MAX` is **317 characters**, measured — so this site's safety is entirely the caller's value
bound. Re-derived: `net_hilight_march_offset` returns `P * frac` with `frac ∈ [0,1)` and
`P = net_hilight_dash_period(st) = st->period`, set only by `net_hilight_compute_dash_period`,
which sums `(unsigned char)st->dash_arr[i]` over `st->dash_len` and doubles for an odd length.
`dash_arr` is `char[16]` and the parser writes it under
`s->dash_len < (int)sizeof(s->dash_arr)`, so `P ≤ 16 × 255 × 2 = 8160` and the output is at most
`"8160.000000"` = **11 characters**. 1606's claim survives; it is the caller's bound, not the
function's, exactly as 1606 said — and the margin is 49 − 11, not 49 − 317.

### Two more things the census turned up, carried forward, not fixed

1. **`my_snprintf` does not implement length modifiers, and three live sites use them.**
   `%ld` ×2 (`scheduler.c`, `XMaxRequestSize`/`XExtendedMaxRequestSize`), `%lu` ×1
   (`scheduler.c`, a window id), `%hu` ×1. The scanner accepts them and forwards the spec verbatim
   to `sprintf`, but the argument is fetched with `va_arg(args, int)` and re-pushed as an `int`, so
   `sprintf` reads 8 bytes from a 4-byte value. It works by accident on x86-64 because gcc
   zero-extends: driven on the dev display via `devdisplay.sh exec env HOME=<throwaway>
   ./src/xschem --pipe -q --script …`, `xschem globals` gives `XMaxRequestSize=65535` (21 ch) and
   `XExtendedMaxRequestSize=4194303` (31 ch) — correct values. A negative `long` or one ≥ 2³² would
   print wrong. Not a bound problem (≤ 20 characters either way).
2. **A conflicting prototype.** `src/parselabel.l` declares
   `extern int my_snprintf(char *str, int size, const char *fmt, ...)` — `int` return and `int
   size` against `util.h`'s `size_t`/`size_t`. Two incompatible declarations of one function in one
   program.

---

## 6. The never-compiled `#ifdef HAS_SNPRINTF` arm — DELETE it

**A fifth, and the first BEHAVIOURAL, proof it has never compiled.** 1606 had four (absent from
`config.h`, `config.h.in`, scconfig and the compiler line; `nm -S`; `nm -u`; the `%s`-given-an-int).
Add: `xschem globals` prints `HAS_DUP2=1`, `HAS_POPEN=1`, `HAS_CAIRO=1` and **no `HAS_SNPRINTF=`
line at all** — driven headless, rc 0.

**And 1606's wording is half wrong, measured.** It says the arm *"would segfault or fail to
compile the moment the macro were defined"*. Which one depends on **how** you define it:

* `-DHAS_SNPRINTF=` — the natural spelling for a scconfig feature flag — is a **compile error**:
  `scheduler.c:6263:65: error: expected expression before ')' token`.
* `-DHAS_SNPRINTF=1` — gcc's default for a bare `-D` — **compiles clean**, `-Wall` included, and
  would crash at runtime. `my_snprintf` carries no `__attribute__((format))`, so nothing diagnoses
  `%s` given the `int` 1. Both `util.c` and `scheduler.c` compiled to `.o` with rc 0.

The runtime outcome is not guessed: the same misuse is driveable through the **live** hand-rolled
`%s` arm — `--rcfile '%s'` and `--rcfile '%s%s%s%s%s'` both give **rc 139, SIGSEGV**, because the
arm does `sptr = va_arg(args, char *); strlen(sptr)` on a pointer nobody pushed.

`-DHAS_SNPRINTF=1` also exposes two defects **inside** the dead arm, which are themselves evidence
nobody has ever built it: `util.c:632` `if(has_x && size_of_print >= size)` compares `int` against
`size_t` (a `vsnprintf` error return of −1 becomes huge and fires the alert), and `util.c:633`
hands `%d` a `size_t` (`-Wformat=`). Note the tree's own `CFLAGS` carry **no `-W` at all**, so
neither would ever be seen.

**Recommendation: DELETE the `#ifdef HAS_SNPRINTF` arm and its `#else`/`#endif`, and delete
`scheduler.c`'s `HAS_SNPRINTF=%s` line with it.** Reasons, in order:

1. Deleting changes **not one compiled byte**, and `xschem globals` output is already byte-identical
   because the line never printed (measured above).
2. **Fixing it is the option 1606 already costed as worse than leaving it** — the two arms' return
   values mean different things (bytes *written* vs. bytes that *would have been*), five sites
   consume that value as a length and three accumulate it as `off += my_snprintf(s + off, sz - off,
   …)` where `off` can pass `sz` and hand a negative `sz - off` to a `size_t`. A "fixed" arm is a
   switch nobody may safely throw, which is a worse trap than an absent one.
3. **Fencing it keeps two definitions of a function called 729 times**, and a static row asserting
   the arm is absent is exactly the text-matching fence the 1606 batch spent four rounds learning
   not to trust.
4. ⚠ **This tree has already lost a process to precisely this `#ifdef` reading as protection.**
   `src/util.c`'s `log_action` comment records it: the same `#ifdef HAS_SNPRINTF` / `vsnprintf`
   versus `vsprintf` pair, the unbounded arm the only one ever compiled, and a Tk menu entry whose
   4971-byte `-command` script aborted the editor on a click with `*** buffer overflow detected
   ***`, unsaved schematic in it. The `#ifdef` "read as protection and was decoration."

Second-best if anyone wants the portability seam to stay visible: keep the `#ifdef` but make the
arm `#error "HAS_SNPRINTF is unsupported: see doc/claude/issues/1608-….md"`. That is honest and
un-rottable, and it still leaves the reader asking why.

⚠ Also note for Stage B: `snprintf` as the instrument for the bound costs the **portability
claim**, not just the call. C89 has no `snprintf`; that is the entire reason this function exists,
and `-DHAS_SNPRINTF=` does not compile. The bound has to be arithmetic.

---

## 7. The behavioural door, and what a suite must assert

**A behavioural row is available, and there is more than one.** Best backbone, in order:

1. **File-borne, headless, no display, no Tcl.** Fixture `.sch` with
   `T {HELLO} 20 -30 0 0 0.4 0.4 {layer=4 font=%-2000d}`, child-exec
   `env -u DISPLAY ./src/xschem --nogui --pipe -q <sch> --script <xschem zoom_full; xschem print
   svg <out>>`. Today: **rc 134** and `*** buffer overflow detected ***: terminated`. This is the
   strongest row because it is the shape a stranger's schematic actually takes.
   ⚠ **`xschem zoom_full` is required** — without it the text falls outside the export viewport
   and no `<text>` element is emitted (measured: 0 `<text` in the output), though the
   `my_snprintf` call still runs, so the *abort* rows work either way and only the (D) row needs it.
2. Same door with an `l = 62` spec (mechanism A) and with `%.60g` (mechanism C, float arm).
3. `--rcfile '%-2000d'` as a second, independent door (mechanism C from the command line), and
   `--rcfile` with `l = 62` for (A).
4. **A non-crashing in-process row for (D)**: `font=` with an 80-character literal prefix then
   `%d`, asserting the emitted `font-family` is **at most 79** characters. Today it is exactly 80,
   which is the observable proof that the NUL landed outside `svg_font_family[80]`. This row needs
   no child crash and no display, and it fences the one mechanism whose failure is silent.

⚠ **The suite must read `rc`, not the death marker.** Measured again here: the aborting run prints
**zero** column-0 `FATAL` lines, because `main.c`'s `sig_handler` traps SIGINT/SEGV/ILL/TERM/FPE and
**not SIGABRT**. Consistent with 1606, and re-confirmed: across ~40 driven aborts in this session,
`find /tmp -maxdepth 1 -name 'xschem_emergencysave_*' -newermt '-3 hours'` returns **0** (the 5998
pre-existing ones are untouched, newest 2026-09-25 00:51, none deleted).

---

## 8. A COMPILER-DIAGNOSTIC fence exists for this class, and it is nearly free

Per the brief, the 1606 batch's single strongest fence was a compiler-diagnostic row, because no
decoy can fool the compiler's own opinion. **One is available here**, measured without touching
the tree (a scratchpad header re-declaring the function with the attribute, pulled in with
`-include`, plus `-fsyntax-only`):

```c
extern size_t my_snprintf(char *str, size_t size, const char *fmt, ...)
  __attribute__((format(printf,3,4)));
```

Compiling **every** `src/*.c` with that attribute and `-Wformat -Wformat-security` yields
**exactly six diagnostics, tree-wide**:

```
svgdraw.c:974  / 979  / 1381 / 1386 : warning: format not a string literal and no format arguments [-Wformat-security]
xinit.c:3522                        : warning: format not a string literal and no format arguments [-Wformat-security]
xinit.c:1886                        : warning: zero-length gnu_printf format string [-Wformat-zero-length]
```

Five of the six **are** the defect of §0. The sixth is
`my_snprintf(old_win_path, S(old_win_path), "")` — benign, and either left as a warning or written
as `old_win_path[0] = '\0'`. **Zero false positives across 724 literal formats and their
arguments.** So the attribute is both a fix-enabler (it makes any future non-literal format a
compile-time diagnostic) and the fence for it. ⚠ It does **not** catch (A)/(B)/(C)/(D) themselves,
because with a non-literal format gcc cannot range `l`; it catches the *door*. Both halves are
needed.

---

## What I could NOT measure

* **Whether (D) is reachable from any literal format.** Needs each of the 729 sites' destination
  buffer size checked against the length of each literal run. Not censused. Reachable from the
  non-literal doors, driven.
* **Any non-fortified build.** Every abort here is `_FORTIFY_SOURCE=3` + `__sprintf_chk` /
  `__strncpy_chk`. Derived, not driven: without fortify, (C) is a plain 2000-byte stack smash and
  (A) writes `l` unbounded bytes with `nfmt[l]` a NUL at an arbitrary offset — the format string's
  length is unbounded, so that offset can reach return-address territory. I did not build a
  `-D_FORTIFY_SOURCE=0` tree; saying so rather than asserting a Windows or `-O0` figure, per the
  1606 batch's own correction about a claimed Win64 measurement.
* **Whether `%.6f`'s bound can be broken from a file.** I bounded `st->period` from the parser's
  own `dash_len < sizeof(dash_arr)` clamp and `unsigned char` accumulation; I did not fuzz the
  `net_hilight_style` table parser.
* **The `p` arm's only live caller.** `src/util.c`'s `%p` is behind `debug_var > 2`; I did not
  drive it, only censused it.

## Housekeeping / carried forward

* **`svgdraw.c` is the un-fixed twin of a defect already fixed in `psprint.c` (its "ISSUE 1351"
  comment) and already fenced for PostScript by `test_ps_valid_1350.tcl` rows V10/V13.** Whoever
  fixes 1608 should fix the four `svgdraw.c` sites in the same commit and say that the `"%s"` form
  is the fix, since the file already uses it correctly twice.
* `src/parselabel.l`'s conflicting `int my_snprintf(char *, int, …)` prototype.
* `%ld`/`%lu`/`%hu`: `my_snprintf` has no length-modifier support; the argument is fetched as `int`.
* The bare `break` without `overflow = 1` in the `d/x/c/u` and `p` arms (proved harmless today).
* `my_snprintf(old_win_path, S(old_win_path), "")` in `xinit.c` — zero-length format.
* ⚠ **The session scratchpad is shared with the other crews dispatched at the same time.** My first
  census script was overwritten mid-run by another agent writing the same filename. Everything
  above was re-run under `scratchpad/stageA_1608/`. Not a repo defect; a coordination note for the
  driver.
