# Receipt Av — `refute:A`

**Stage Av of the 1608 batch. Adversarial re-derivation of receipt `A-measure-and-census.md`.**
Tree at `91bb1bd7`. `make -C src` → *Nothing to be done* before the first figure; every planted
figure was rebuilt, and every restore used `cp`, never `cp -a`. Tree left as found:
`git diff --stat -- src/` is empty and `git status --porcelain` is byte-identical to the start.
Scratch under `…/f12b1fd5-…/scratchpad/av1608` (a **different** session scratchpad from Stage A's,
so the collision that crew reported did not recur).

Headline: **Stage A's conclusions mostly hold and its arm attribution is now settled harder than it
was — but three conclusions are wrong, four pieces of evidence do not support their conclusion, and
the census has a hole that a planted wide conversion walks straight through.** The single most
important finding is R1: **the 1608 fix as scoped does not close the door it opens on.**

---

## VERDICTS REFUTED

### R1 — "no write-what-where" is FALSE, and `%n` passes every bound the fix proposes

Stage A: *"`%n` is NOT handled by the scanner and is emitted literally (`cannot find %n`, rc=1), so
no write-what-where"* and *"The classic write-what-where of format-string injection does **not**
apply to `my_snprintf`. Worth recording so nobody over-claims."*

`%n` alone escapes only because `n` is not a spec **terminator**. `%n` followed by **any** handled
conversion letter forms a spec that `strncpy`s into `nfmt` — a writable stack array — and is handed
to `sprintf`. Driven through the command-line door:

```
%n       rc=1    Tcl_AppInit() err 2: cannot find %n
%nd      rc=134  *** %n in writable segments detected ***
%nx      rc=134  *** %n in writable segments detected ***
%nu      rc=134  *** %n in writable segments detected ***
%nc      rc=134  *** %n in writable segments detected ***
%np      rc=134  *** %n in writable segments detected ***
%ng      rc=134  *** %n in writable segments detected ***
%hnd     rc=134  *** %n in writable segments detected ***
%lnd     rc=134  *** %n in writable segments detected ***
%1$n     rc=1    Tcl_AppInit() err 2: cannot find %1$n
```
(`timeout 30 env -u DISPLAY HOME=<throwaway> ./src/xschem --nogui --pipe -q --rcfile '<spec>'
--script <noop>`)

And through the **file-borne** door, which is the one that matters. Fixture
`T {HELLO} 20 -30 0 0 0.4 0.4 {layer=4 font=%nd}`, whole verbatim output:

```
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
*** %n in writable segments detected ***
rc=134
```

So a stranger's `.sch` makes `xschem print svg` **attempt an arbitrary write**, and the only thing
stopping it is glibc's `__sprintf_chk` PRINTF_FORTIFY refusal of `%n` in a non-read-only format
string. That is a libc hardening feature, not a property of `my_snprintf`, and this tree targets
C89 and Windows as well as glibc.

**Three consequences the driver must not write down wrongly:**

1. **`%nd` is a 3-character spec producing ~0 characters of output. It passes EVERY bound in the
   plan.** Bounding `l` (A/B) and `nlen` (C) leaves it untouched. Stage B's arithmetic bound does
   **not** close the format-string door; only fixing the five non-literal call sites does.
2. The failure **message differs by mechanism** (`*** buffer overflow detected ***` vs `*** %n in
   writable segments detected ***`). Stage A's §7 rule "read `rc`, not the death marker" is right
   and this strengthens it — but a row that asserts the *message* misses this shape.
3. It raises the severity of the `svgdraw.c` finding from "aborts" to "attempted arbitrary write,
   blocked only by libc hardening".

### R2 — the census's headline COUNTS reproduce under no instrument, and the stated reason for the gap is measurably false

Stage A: *"**729** `my_snprintf(...)` call expressions in `src/*.c`" … "The issue's *"~748"* is a
`grep -c` line count; it includes **24 occurrences inside string literals** (`xinit.c` alone has
**17**, in the `globals`/paths text)"*.

* `src/xinit.c` holds **94** occurrences of the substring `my_snprintf` and **ZERO** inside a
  quoted string: `/usr/bin/grep -c '"[^"]*my_snprintf' src/xinit.c` → `0`. Across all `src/*.c`
  there is exactly **ONE** `my_snprintf(` inside a string literal — `util.c`'s own
  `dbg(1, "my_snprintf(): overflow, target size=%d, format=%s\n", …)`. The stated explanation of
  the gap is false.
* Four numbers exist, and 729 is none of them:

| instrument | figure |
|---|---|
| `grep -c` line count summed per file | **769** |
| source-text call expressions (comments stripped, 2 definitions and the 1 in-literal excluded) | **752** |
| **call expressions that actually compile** (`gcc -E` with the tree's real `CFLAGS`) | **722** |
| Stage A | 729 |

  The 752 − 722 = 30 gap is calls in preprocessor arms not built here — `xinit.c` alone drops
  93 → 78, and 7 of those sit inside `#ifndef __unix__` regions. Downstream, Stage A's "1229
  conversions … 652 `%s`, 363 integer, 213 float, 1 `%p`" is a source-text figure; compiled it is
  **1218 — 648 `%s`, 356 integer, 213 float, 1 `%p`**.

Per the brief's own rule — *"Do not claim a count"* — the driver should quote no figure here without
naming the instrument. **The conclusions drawn from the census all survive (see below); only its
arithmetic does not.**

### R3 — the compiler-diagnostic fence does NOT catch "any future non-literal format"

Stage A §8: *"the attribute is both a fix-enabler (**it makes any future non-literal format a
compile-time diagnostic**) and the fence for it"*, and the stated reason it misses the mechanisms:
*"with a non-literal format gcc cannot range `l`"*.

`-Wformat-security` warns **only** for a non-literal format with **no arguments**. Measured on a
nine-line probe using Stage A's own attribute (`format(printf,3,4)`) and flags:

```
fence.c:6: warning: format not a string literal and no format arguments [-Wformat-security]
  ← my_snprintf(buf, sizeof buf, uf);        /* the five real sites' shape */
  (nothing at all for)  my_snprintf(buf, sizeof buf, uf, 7);   /* non-literal WITH an argument */
```

So the five real sites are diagnosed only because all five happen to be zero-argument calls. The
flag for the general case is **`-Wformat-nonliteral`**, which Stage A did not measure.

The stated *reason* is also wrong: gcc misses the wide **literal** too.
`-Wall -Wextra -Wformat -Wformat-overflow=2 -Wformat-truncation=2` on
`my_snprintf(buf, 80, "%-60d", 7)`, `my_snprintf(buf, 80, "%f", 1e300)` and
`my_snprintf(buf, 80, "%*d", 60, 7)` gives **zero** diagnostics — because `-Wformat-overflow`
applies only to the `sprintf`/`snprintf` builtins whose destination gcc knows, never to a user
function carrying `format(printf,…)`. It is not about ranging `l`.

Stage A's *"exactly six diagnostics, tree-wide"* **does reproduce** for its flag set — same six
lines, same line numbers (`svgdraw.c` 974/979/1381/1386, `xinit.c` 3522, `xinit.c` 1886
zero-length). It is the coverage sentence attached to it that is wrong.

**Constructively:** `-Wformat-nonliteral` is usable and strictly better. Tree-wide it adds exactly
five lines and no noise — `util.c` 697/720/746, i.e. **the three (C) `sprintf(nstr, nfmt, i)` sites
themselves**, and `draw.c` 5309/5310, the two `sprintf(tmpstr, fmt1/fmt2, …)` sites whose own
comment says *"fmt1/fmt2 are char * VARIABLES, not literals — grepping this site for a literal
`%.*g` finds nothing"*. So one flag fences 1608's own mechanism sites **and** 1606's class.

---

## EVIDENCE REFUTED — conclusion probably right, stated evidence does not support it

### E1 — `%*d`: the conclusion is right in principle, the measurement is not reproducible

Stage A: *"Driven: `--rcfile '%*d'` → **abort, rc 134**. A `%*d` is therefore a (C) overflow with a
three-character spec."*

At that door **no vararg is pushed**, so the width is uninitialised garbage. Measured:

```
  spec=%*d    padlen=0   rc=1    Tcl_AppInit() err 2: cannot find              -1209973808
  spec=%*d    padlen=1   rc=1    *** buffer overflow detected ***: terminated
  spec=%*d    padlen=8   rc=1    *** buffer overflow detected ***: terminated
  spec=%*d    padlen=32  rc=134  *** buffer overflow detected ***: terminated
```
(`padlen` = characters of filler appended to the `--rcfile` argument; the rc and the message come
from two runs of the *identical* command line, and at padlen 1 and 8 **they disagree** — one run
aborted, the other returned 1.)

A negative garbage width means left-justify with `|width|`, which stays under 50. **The outcome is
non-deterministic**, so a suite row built on `--rcfile '%*d'` would be flaky. The defensible
statement is: `%*d` is a (C) overflow **when a caller pushes a large width**; at this door the width
is garbage. `%.*g` behaved the same way (rc 1 at every padding). New and not in Stage A:
`%*s` → **rc 139** at every padding, like `%s`.

### E2 — the `(D)` 81-character row's explanation is wrong twice, though its observable is right

Stage A §4 table: *"81 → attribute absent (guard fires, `overflow=1`, string untouched)"*.

1. In the `d/x/c/u` arm the prefix guard is a **bare `break` with no `overflow = 1`** — Stage A says
   so itself four paragraphs later, so the receipt contradicts itself within one section.
2. The attribute is not absent because of the guard. `svg_draw`'s reader is
   `if(strcmp(svg_font_family, tclgetvar("svg_font_name"))) fprintf(fd, "style=\"font-family:%s;\" ", …)`.
   Line 974 pre-loads `svg_font_family` from `svg_font_name`; the 81-character call leaves it
   untouched; the two strings are therefore equal and the **reader** skips the attribute.

The observable itself reproduces exactly (78→78, 79→79, **80→80**, 81→absent, 82→absent, rc 0
throughout), so the (D) row Stage A proposes is sound — only its explanatory parenthetical is not.

### E3 — "5998 pre-existing" emergency saves

The load-bearing part reproduces: **zero** created (`find /tmp -maxdepth 1 -name
'xschem_emergencysave_*' -newermt '-3 hours'` → 0) and none deleted, across ~90 driven aborts here.
The number does not: `find /tmp -maxdepth 1 -name 'xschem_emergencysave_*' | wc -l` → **777**
directories; all entries at or under them → 5222; 777 + 5222 = 5999. "5998" is a differently-scoped
count of the same thing, not a count of emergency saves.

### E4 — the (A)/(B) threshold table's arithmetic

Stage A's table says *"l ≤ 49 → 49 bytes, fits"*. At `l == 49` `strncpy` writes exactly 49 bytes and
`nfmt[49]` is the **50th** byte — still in bounds, so the verdict is right, but this is the row the
whole 49/50/51 threshold rests on and its arithmetic is stated loosely.

---

## CENSUS HOLES — planted, driven, and shown missed

Four plants at **one real caller**: `scheduler.c`'s `incr_hilight_color` handler,
`my_snprintf(res, S(res), "%d", xctx->hilight_color)` into `char res[30]`, driven by
`xschem incr_hilight_color` (baseline `INCR=1`, rc 0). Each plant: edit → `make -C src` → drive
headless → restore with `cp`.

| plant | outcome when driven | source-text census | preprocessed census |
|---|---|---|---|
| **P1** literal `"%-60d"` | **rc 134**, `*** buffer overflow detected ***` | found (new wide spec) | found |
| **P2** `"%" WPFX "d"` with `#define WPFX "-60"` | **rc 134** | **mis-bucketed as NON-literal** (11 not 10); the 60-wide field invisible | found: `('%-60d','int',5,60,None,'src/scheduler.c')` |
| **P3** `PFMT` with `#define PFMT "%-60d"` | **rc 134** | **mis-bucketed as NON-literal** | found |
| **P4** `XSNP(res, S(res), "%-60d", …)` with `#define XSNP my_snprintf` | **rc 134** | **CALL LOST ENTIRELY** — total 755 → 754, in neither bucket | found; total unchanged at 722 |

**P4 is the hole that matters.** A census keyed on the text `my_snprintf(` enumerates *spellings*,
not *calls*. The 1606 batch already recorded a two-hop `#define` alias to `sprintf` defeating a row
there, so this is a shape known to defeat this tree's instruments, reused.

**P1 is also worth the driver's attention on its own**: a single literal `%-60d` in one ordinary
getter aborts the process with `char res[30]` as the destination — the issue's own point that the
caller's buffer size is irrelevant, now driven rather than argued.

**The fix is cheap: census `gcc -E` output, not source text.** It is immune to all four plants, to
comments, to `#if 0`, to adjacent-literal splitting, to macro aliasing of either the call or the
format, and to dead preprocessor arms — and it is the only instrument that answers *what compiles*.
Run here with the tree's real `CFLAGS`:

```
PREPROCESSED census -- calls actually compiled: 722
  literal-format: 716   non-literal: 6   (5 real + 1 artefact of my own arg-splitter on util.c's dbg text)
     NONLIT svgdraw.c 'tclgetvar("svg_font_name")' / 'textfont' / 'tclgetvar("svg_font_name")' / 'textfont'
     NONLIT xinit.c   'cli_opt_rcfile'
  conversions: 1218   {'s': 648, 'int': 356, 'float': 213, 'p': 1}
  max SPEC LENGTH per arm: int 4 ('%02x'), float 5 ('%.16g'), p 2 ('%p'), s 2 ('%s')
  specs with a field width or precision >= 20, or a '*', or l >= 20:  NONE
```

---

## WHAT SURVIVED — re-derived, not agreed with

1. **(C) aborts on all three arms; 49 characters of output survive, 50 abort.** Re-driven via
   `--rcfile` on `d/x/c/u`, `p` and `g/e/f`.
2. **Arm attribution settled by gdb, which Stage A did not do.** The abort comes from the arm
   claimed, and nothing earlier on the path dominates it (the 1603 failure mode):
   * `--rcfile '%-50d'` → `__GI___chk_fail ← __vsprintf_internal ← ___sprintf_chk ← my_snprintf ←
     Tcl_AppInit ← Tcl_MainEx ← main`  — that is **(C)**.
   * `--rcfile` with l=51 (`d` arm) and l=62 (`g` arm) → `__GI___chk_fail ← __GI___strncpy_chk ←
     my_snprintf ← Tcl_AppInit ← …`, at two **different** return addresses inside `my_snprintf`
     (`0x5555556308b5` for the `d` arm, `0x555555630a8e` for the `g` arm) — that is **(A)**, in two
     distinct arms.
   This also settles Stage A's task (d) beyond doubt: the backtrace names `main`, so the figures are
   through the built `./src/xschem` and not a dressed-up extraction.
3. **(A)/(B): l ≤ 49 safe, l == 50 silent, l ≥ 51 aborts**, on all three arms. Re-driven.
4. **The stack-layout claim.** `objdump -d src/util.o`: all three arms share `nfmt` at `rsp+0x60`
   and `nstr` at `rsp+0xa0`, each passed with object size `0x32`; the `nfmt[l]` store is
   `movb $0x0,0x60(%rsp,%rdx,1)`; frame `sub $0x198,%rsp`. And — stronger than Stage A stated —
   **no `rsp` offset in `0x92..0x9f` is referenced anywhere in the function**, so "14 bytes of
   alignment padding" is verified rather than asserted.
5. **Five non-literal format sites**, confirmed by two independent instruments (my census and the
   compiler). No `my_snprintf` call outside `src/*.c`.
6. **The live file-borne door.** `.sch` with `font=%-2000d`, `font=%.60g` and a 62-character spec,
   each → rc 134 headless under `xschem print svg`. And **no further door**: every other `textfont`
   consumer in the tree is `cairo_toy_font_face_create`, and `psprint.c` uses the `"%s"` form.
7. **Mechanism (D)**, driven through `svg_font_family[80]`, and the layout claim verified with
   `nm -S src/svgdraw.o`: `svg_font_family` at `.data+0x60` size `0x50`, `svg_font_weight` at
   `.data+0xc0`, so index 80 = `.data+0xb0` is padding.
8. **`%.6f`'s bound, re-derived independently.** `dash_len` is written at exactly one site
   (in `parse_net_hilight_styles`, `hilight.c:646` at `91bb1bd7`) under
   `s->dash_len < (int)sizeof(s->dash_arr)`; `period` at exactly one site (in
   `build_net_hilight_styles`, `hilight.c:748`); the
   getter range-checks `idx` against `n_net_hilight_styles`. P ≤ 16×255×2 = 8160, output ≤ 11
   characters. Conclusion and evidence both hold.
9. **HAS_SNPRINTF.** `-DHAS_SNPRINTF=` → `scheduler.c:6263:65: error: expected expression before
   ')' token`, rc 1. `-DHAS_SNPRINTF=1` → both `util.c` and `scheduler.c` rc 0 under `-Wall`, with
   **no** diagnostic about `%s` given an int. `util.c:633`'s `%d`-given-`size_t` confirmed.
10. **No literal contains `%%`; none contains `%*` or `%.*`.** Plus a check Stage A did not run:
    **zero literal formats have an unclosed `%`** (a `%` with no following handled letter would
    leak the whole tail of the format verbatim). None exist.
11. SIGABRT is untrapped (`main.c` registers SIGINT/SEGV/ILL/TERM/FPE only); an aborting run emits
    **zero** column-0 `FATAL` lines; `--rcfile '%s'` → rc 139.

---

## NEW, carried forward — not fixed

* **`%-60s` silently does nothing**, driven at the planted site: `"[%-12s][%-12d]"` →
  `INCR=[AB][1           ]`. The `%s` arm never builds or consults `nfmt`, so a field width on `%s`
  is discarded. The issue file cites `%-60s` as the stylistic precedent that makes a future
  `%-60d` likely; measured, the precedent is *also* a silent output bug — and a developer who writes
  `%-60s`, sees no padding, and "fixes" it lands on exactly the aborting arm.
* **`my_snprintf(ps_font_family, S(ps_font_name), "Helvetica")`** at two `psprint.c` sites — the
  size is taken from a *different object* than the destination. Both arrays are `[80]` today, so it
  is harmless now and live the moment either is resized. Outside 1608's scope.
* **`md5sum src/xschem` is not a valid "tree restored" check in this tree.** `src/scheduler.c`
  references `__DATE__`/`__TIME__`, so an identical-source rebuild yields a different binary (the
  ELF Build ID moves too). I verified restoration with `git diff -- src/` plus a behavioural probe.
* The `off += my_snprintf(s + off, sz - off, …)` accumulator in `publish_net_hilight_styles_to_tcl`:
  I checked the `sz - off` wrap Stage A cites as a reason not to enable the dead arm. In the **live**
  arm it cannot occur — the live arm returns bytes *written*, bounded by its own guards to
  ≤ `size − 1`, so `off ≤ sz − 1` always and `sz − off ≥ 1`. Stage A's framing is correct; recording
  that I verified it rather than inherited it.

## What I could NOT measure

* **Any non-fortified build.** Every abort here is `_FORTIFY_SOURCE=3`. Untouched, and it is exactly
  where R1 bites hardest: without fortify, `font=%nd` is a write through an unpushed vararg rather
  than an abort.
* **Whether (D) is reachable from a literal format.** Still uncensused — but the preprocessed census
  now makes it mechanical, because `S(x)` expands to `sizeof` in the preprocessed text, so each
  site's destination size is available next to its format.
* **The `p` arm's only live caller** (`src/util.c`'s `%p` behind `debug_var > 2`) — censused only.
* Whether `%.6f`'s bound can be broken by fuzzing the `net_hilight_style` table parser. I verified
  the two write sites and the clamp; I did not fuzz.
