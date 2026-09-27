# Receipt B — `design:bound`: the bound, its instrument, and what it does when it fires

**Crew:** Stage B, `design:bound`. **Measured at** `91bb1bd7`, 2026-09-26, `src/xschem` rebuilt
(`make -C src` → *Nothing to be done*, binary mtime Sep 25 11:15 unchanged), glibc from
`gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0`.
**Tree left as found:** `git status --porcelain` identical to the session's opening snapshot; every
patched file is a *copy* under the session scratchpad; no repo file written except this receipt.

⚠ **`receipts/` was empty when I started: there is no Stage A receipt.** The brief says a crew reads
the previous stage's receipt because the corrections live there, so I measured what Stage B needed
myself. **Sections 1 and 2 below therefore duplicate Stage A's census and boundary work and should
be treated as an independent second measurement**, not as a substitute — where Av contradicts me,
Av's numbers were taken against the same binary and mine are reproducible from the commands quoted.

---

## 0. The headline, because it changes the priority argument and not just the patch

**H1 is refuted on its most-likely-wrong bullet, and the issue's own "LATENT" section is wrong.**
The prediction was *"(A)/(B) is unreachable from any format string in this tree … this tree's
formats are all literals."* Measured: **five call sites pass a non-literal format string**, and
through two of them a **`.sch` file** reaches every one of the six unchecked writes.

```
$ /usr/bin/grep -n 'my_snprintf' src/svgdraw.c src/xinit.c   # (census in §1, these are the 5)
src/svgdraw.c:974    my_snprintf(svg_font_family, S(svg_font_family), tclgetvar("svg_font_name"));
src/svgdraw.c:979    my_snprintf(svg_font_family, S(svg_font_family), textfont);   /* .sym text font= */
src/svgdraw.c:1381   my_snprintf(svg_font_family, S(svg_font_family), tclgetvar("svg_font_name"));
src/svgdraw.c:1386   my_snprintf(svg_font_family, S(svg_font_family), textfont);   /* .sch text font= */
src/xinit.c:3522     my_snprintf(name, S(name), cli_opt_rcfile);                   /* --rcfile arg */
```

Driven, headless, in the built binary — a seven-line `.sch` whose only content is one text object:

```
T {hello} 0 0 0 0 0.4 0.4 {layer=4 font=%-2000d}
$ env -u DISPLAY HOME=<throwaway> timeout 40 ./src/xschem --nogui --pipe -q \
    --command "xschem load t.sch; xschem print svg out.svg; puts DONE-OK"
font=plain        rc=0   | DONE-OK
font=%-2000d      rc=134 | *** buffer overflow detected ***: terminated
font=%-2000f      rc=134 | *** buffer overflow detected ***: terminated
font=%*d          rc=134 | *** buffer overflow detected ***: terminated
font=%.400f       rc=134 | *** buffer overflow detected ***: terminated
font=%-----(x51)d rc=134 | *** buffer overflow detected ***: terminated   <-- this is (A)
font=%-----(x47)d rc=0   | DONE-OK
```

and from the command line, which needs no file at all:

```
$ env -u DISPLAY HOME=<throwaway> timeout 30 ./src/xschem --nogui --pipe -q --rcfile '%-2000d'
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
*** buffer overflow detected ***: terminated            rc=134
$ … --rcfile '/nonexistent-plain-path'                   rc=1   (control: "cannot find …")
$ … --rcfile '%-2000x' / '%-2000u' / '%-2000c' / '%-2000p' / '%-2000f' / '%*d' / '%.400f'
                                                         rc=134 on every one  (all three arms)
```

So this is **not latent**, it needs **no `tcleval`, no generator, no display and no export
plug-in** — `xschem print svg` on someone else's schematic is enough — and `--rcfile` makes it
reachable before the GUI exists. 1606's abort needed arbitrary Tcl from a `.sch`; this one needs a
**text attribute**. Three consequences for the driver:

* the "latent, so the priority argument is the two-line guard" framing in the issue and in the
  LEDGER should be replaced by the driven rc=134 above;
* `_FORTIFY_SOURCE` is what makes it an abort rather than a silent write, and **one of the six
  writes is already silent** (§2, mechanism (B) at `l == 50`);
* **`src/psprint.c` fixed exactly this at its own site as issue 1351** (see the comment above
  `ps_font_token`: *"passed user data as the FORMAT STRING, so `font=%s` read a vararg that was
  never pushed"*). The SVG backend was not fixed with it. That is a **separate defect, carried
  forward, not fixed here** (§7.1).

---

## 1. Census — the boundary the bound must not cross (753 parsed call sites)

`/usr/bin/grep -c 'my_snprintf(' src/*.c` sums to **769** textual hits; a comment-stripped,
paren-balanced parse (`scratchpad/census.py`, quoted in full at the end of this receipt's command
list) resolves **753 real calls** with ≥ 3 arguments — the remainder are the two definitions, two
`extern` declarations in the generated parsers, and prose in comments.

**Distinct conversion specs in literal formats — all 19 of them:**

| spec | len | sites | worst-case output, MEASURED on this glibc |
|---|---|---|---|
| `%.10e` | 5 | 1 | 18 |
| `%.10g` | 5 | 13 | 17 |
| `%.15g` | 5 | 1 | 22 |
| `%.16g` | 5 | 102 | 23 |
| `%.17g` | 5 | 8 | 24 |
| `%.6f` | 4 | 1 | **317** |
| `%.6g` | 4 | 2 | 13 |
| `%.8g` | 4 | 1 | 15 |
| `%02x` | 4 | 24 | 8 |
| `%4d` | 3 | 7 | 11 |
| `%hu` | 3 | 1 | 5 |
| `%ld` | 3 | 2 | 20 |
| `%lu` | 3 | 1 | 20 |
| `%c` | 2 | 18 | 1 |
| `%d` | 2 | 293 | 11 |
| `%g` | 2 | 84 | 13 |
| `%p` | 2 | 1 | 18 |
| `%s` | 2 | 682 | n/a (the `%s` arm has no `nfmt`/`nstr`) |
| `%u` | 2 | 18 | 10 |

Lengths measured by `scratchpad/libcmax.c` over nine extreme doubles (`±DBL_MAX`, `±DBL_MIN`, the
min subnormal, `1e308`, `-1e-308`, `-0.0`, `123456.789`) and the integer extremes:

```
max %f = 317   max %e = 14   max %g = 13   max %.6f = 317   max %.10e = 18   max %.17g = 24
max %d = 11    max %u = 10   max %x = 8    max %#x = 10     max %ld = %lu = 20   max %p = 18
%.200f = 511   %.0f = 310    %.767g = 758  %.2000g = 758
```

**Two facts decide the whole design.**

1. **The longest literal conversion *spec* in this tree is 5 characters.** So mechanism (A)/(B)'s
   49-byte headroom is never approached by a literal — a factor of ten. ⚠ It *is* approached, and
   crossed, by the five non-literal sites (§0).
2. **Exactly one live literal spec has a worst case that a 50-byte scratch cannot hold: `%.6f`, at
   317 bytes.** It is `scheduler.c`'s `xschem net_hilight_march_offset <idx>`:
   `my_snprintf(buf, S(buf), "%.6f", net_hilight_march_offset(…))`. Everything else tops out at 24.
   **This single row is what kills three of the four candidate instruments** (§3), and it is a live
   abort today for a large enough argument — driven in §4.

⚠ 1606's inherited claim *"every `my_snprintf` call with a float conversion is … all ≤ 24
characters, and the only `%f` is `scheduler.c`'s `"%.6f"` on a bounded march offset"* is **right
about the census and wrong about the safety inference**: 24 is the width of the *spec's* output only
if the value cooperates. `%.6f` is a ≤ 4-character spec with a **317-byte** worst case, and nothing
in `util.c` bounds the value.

---

## 2. Which write fires first, and the (A)/(B) thresholds — both MEASURED, both against H1

The plan asked which of (A) `strncpy(nfmt, fmt, l)` and (B) `nfmt[l] = '\0'` fires first. The
arithmetic says (B), and the binary agrees. Spec built as `'%'` + *k* `-` flags + `'d'`, so
`l = k + 2` and the **output stays 2 characters** — which isolates (A)/(B) from (C) by construction:

```
$ … --rcfile "%<k dashes>d"
k=46  l=48  rc=1    "cannot find 0"      <- safe
k=47  l=49  rc=1    "cannot find 16"     <- safe, last safe value
k=48  l=50  rc=1    "cannot find 104"    <- (B) WRITES nfmt[50], ONE BYTE PAST, AND DOES NOT ABORT
k=49  l=51  rc=134  *** buffer overflow detected ***   <- (A): __strncpy_chk catches 51 bytes
k=50..55     rc=134  (same)
```

**So (B) fires first, at `l == 50`, and it is SILENT.** `strncpy` is a fortified call
(`nm -u src/util.o` lists `__strncpy_chk`) so (A) aborts loudly at `l ≥ 51`; `nfmt[l] = '\0'` is a
plain array store, which `_FORTIFY_SOURCE=3` does not instrument, so `l == 50` corrupts one byte of
`my_snprintf`'s own frame and returns rc 1 with a plausible-looking result. That is the same class
1606 measured at `graph_marker_fmt` (*"every other site in this issue is a loud abort; that one is
silent corruption"*) arriving by a different route: **not a pointer destination, but an
uninstrumented store to a local.**

Consequence for the bound: **a single guard covers both**, because (B)'s threshold (50) is *lower*
than (A)'s (51). Refusing `l >= sizeof(nfmt)` prevents (B) at 50 and (A) at ≥ 51, and there is no
value of `l` for which one fires and the other does not. That is one guard, one fence, not two —
stated here because the brief's *"two redundant guards on one path means NEITHER has a behavioural
row that reddens on its own removal"* would otherwise apply.

**(C)'s threshold, driven on the integer arm:** `%-Nd` is safe to **N = 49** and aborts from
**N = 50** — `nstr[50]` holds 49 characters and the NUL, exactly as the arithmetic says.

---

## 3. Bounding (C) before the write — the four instruments, and why `snprintf` is not one of them

### 3a. `snprintf` is not merely non-C89 here; inside this arm it is incoherent

Cost the portability claim, not the call — so first, what this tree actually commits to:

* **Zero live `snprintf` calls exist in the whole tree.** The only two textual hits in
  `src/*.c src/*.h` are `src/util.c:643` (the comment *"this is a replacement for snprintf()"*) and
  `src/util.c:633`, which is **inside the `#ifdef HAS_SNPRINTF` arm** that never compiles.
* **`./configure --debug` builds this tree with `-std=c89 -pedantic -Wall -Wconversion`** —
  `hook_detect_target()` in `scconfig/hooks.c`, the `istrue(get("/local/xschem/debug"))` branch,
  which appends `-g -O0 -Wconversion -Wno-sign-conversion`, then `cc/argstd/Wall`,
  `cc/argstd/std_c89`, `cc/argstd/pedantic`. The default build (`Makefile.conf`
  `CFLAGS=-pipe -O2 -I…`) carries no `-std=`, so gcc 15 gives it `gnu23`. **C89 is a build mode
  here, not a style preference.**
* Under that mode `snprintf` is **not declared at all**, in the real include environment:

```
$ gcc -c -pipe -g -O0 -Wconversion -Wno-sign-conversion -Wall -std=c89 -pedantic <includes> probe.c
probe.c:5:10: warning: implicit declaration of function 'snprintf' [-Wimplicit-function-declaration]
    5 |   return snprintf(b, n, "%.*g", 60, v);
probe.c:2:1: note: 'snprintf' is defined in header '<stdio.h>'; this is probably fixable by adding …
```
  and `<stdio.h>` *was* included. A `#warning` probe in the same environment shows why:
  `-std=c89` defines `__STRICT_ANSI__`, and then **`__USE_ISOC99` is NOT defined**, nor
  `__USE_XOPEN2K`, nor `__USE_MISC` — `xschem.h`'s `_POSIX_C_SOURCE 200112L` and `config.h`'s
  bare `#define _XOPEN_SOURCE` (no value) do not reach glibc's guard. The same probe under the
  production flags compiles clean (rc 0).
* **`scconfig` already has the probe and xschem does not ask for it.**
  `scconfig/src/default/deps_default.c` registers `libs/snprintf` and `libs/snprintf_safe`
  (`find_snprintf` in `find_printf.c`), and `scconfig/hooks.c` **never `require()`s either**.
  `config.h.in` has no `HAS_SNPRINTF`, and `XSchemWin/config.h` has none either — so on the one
  other platform in-tree (`PlatformToolset v143` = VS2022, whose MSVC *does* have a conformant
  `snprintf`) the hand-rolled arm is also what builds.

**And the killer argument, which costs nothing to check: the bound has to live in the `#else`
arm.** That arm exists *because* the platform has no `snprintf`. Writing `snprintf` into it is
self-refuting: on every platform where the guard would matter, the guard would not link. Wiring
`HAS_SNPRINTF` properly (require the dep, add it to `config.h.in`, re-run `./configure`) does not
help either, because the `#else` arm would still compile wherever the probe says no. **Rejected —
not on cost, on coherence.**

### 3b. The exact-measure instrument: `fprintf` to a null sink

The only *exact*, parser-free, C89 pre-measure: `nlen = fprintf(devnull, nfmt, i);` (C89 `fprintf`
returns the count), then check, then `sprintf`. **Rejected:** it adds a runtime resource
(`fopen("/dev/null")`, `"NUL"` on Windows) that can fail, inside the formatter used at 753 sites
including `kklex()` and the netlist walk, and it formats everything **twice**. A correctness fix
should not double the cost of every `%d` in the netlister.

### 3c. The heap instrument

`my_malloc` the computed need. **Rejected:** it still needs the computed need (so it buys nothing
over 3d), it puts an allocation in the hottest formatter in the tree, and `my_malloc`'s own failure
path is inside the same file — a formatter that allocates is a formatter that can fail for a new
reason. Not costed further because 3d dominates it.

### 3d. RECOMMENDED — a size check on a computed worst case, plus one enlarged scratch

**Why the scratch must grow, and this is the load-bearing step.** A pre-write worst-case check with
`nstr[50]` **necessarily refuses the live `%.6f` caller**, because `%.6f`'s worst case is 317 and no
static bound can know the march offset is small. That is 1606's *"hole gcc found"* repeating in
reverse: a hand-derived value-aware bound is exactly what failed there. So the 50 has to go — and
it is free to go, because `nstr` is scratch internal to `my_snprintf`; **no caller sees it, and
`sizeof(nstr)` appears in no interface.**

**The bound.** A `%…X` spec can contain only two decimal numbers — the field width and the
precision — and the output is at most `max(width, 311 + precision)`:
`sprintf("%f", -DBL_MAX)` is **317** = 1 sign + 309 integer digits + 1 point + the default
precision 6, and `sprintf("%.200f", -DBL_MAX)` is **511** = 311 + 200 (both measured above). The
width and the precision never add, because the output is `max` of the two. So

> **largest digit run in the spec, plus 320**

bounds every conversion this function accepts — three bytes of margin at the default precision, and
**no per-conversion arithmetic to get wrong.** That last property is the point: 1606 shipped a
hand-derived *per-branch* bound and gcc found a branch (`MEG`) where it was violated and which no
runtime probe could reach. A single loose over-estimate cannot be violated by a branch nobody
thought of.

**`*` must be refused separately, and it is live today.** A digit scan cannot see `*`, whose width
comes from a vararg nobody pushed. `--rcfile '%*d'` and `font=%*d` both abort **rc=134 today**, and
`--rcfile '%.*f'` survives only because the garbage int it read happened to be 2.

---

## 4. Truncate or refuse — re-run for this site, and the answer is that there is no new shape

1606's argument *does not transfer*, and not for the reason the plan guessed. There, the choice was
between two ways of printing a number. **Here the function already has an overflow behaviour, it
already applies to 753 callers, and the guard reuses it verbatim:** on `n + nlen + 1 > size` the
function sets `overflow = 1; break;`, which leaves the caller the literal prefix written so far
(NUL-terminated by the `string[n+l] = '\0'` above it), drops the offending conversion **and
everything after it**, and logs `dbg(1, "my_snprintf(): overflow, …")`. That is "refuse the
conversion, keep the prefix" — *not* truncation of a number, so 1606's amputated-exponent hazard has
no analogue here. **The guard adds no new shape; it routes a spec that today corrupts the stack into
the path the function already takes when a conversion does not fit.**

**Does any string a user reads change shape?** Measured, not argued. `scratchpad/main_live2.c`
compares the verbatim original body against the patched body, each call in its **own forked child**
so an abort is a recorded outcome rather than the end of the run, over every distinct live spec ×
8 extreme doubles / 6 integer extremes × buffer sizes 1, 14, 27, 40 and 400:

```
LIVE-SPEC comparison: cases=640 diffs=0 orig_died=10 new_died=0
DIED-DIFF fmt=|%.6f| v= 1.79769e+308 sz=1,14,27,40,400 orig_died=1 new_died=0
DIED-DIFF fmt=|%.6f| v=-1.79769e+308 sz=1,14,27,40,400 orig_died=1 new_died=0
```

**640 cases, zero byte differences, zero differences in the returned length.** The only divergence
is the ten cases where **the original aborts and the patched one does not** — `%.6f` of ±DBL_MAX,
i.e. the live `net_hilight_march_offset` format. With a caller buffer big enough the patched version
returns the complete 321-character string (`"off=%.6f"` of `-DBL_MAX`: `ret=321`, head
`off=-1797693134862315708`, tail `84124858368.000000`); with a 32-byte buffer it returns `off=` and
`ret=4`, which is the existing overflow shape unchanged.

**So: NOT a ruling, and the driver does not need to file one.** Per H2 the choice becomes the
user's only if a live caller's string changes shape; no live caller's does. The strings that change
are (i) the ten `%.6f`-of-a-huge-double cases, where today's shape is *process death*, and (ii)
`--rcfile`/`font=` values containing a pathological spec, where today's shape is *process death* or
*a value derived from a one-byte stack overflow* (`--rcfile "%<48 dashes>d"` prints `104` today).
Neither is a shape worth preserving, and nothing in `xschem_library/` contains a `font=` with a `%`.

⚠ **The one behaviour change worth writing down.** A conservative bound refuses some specs whose
*actual* output would have fitted. Driven: `%.800g` of `42.0` prints `42` today (2 characters) and
is refused after (`800 + 320 = 1120 > 511`). That refusal is nevertheless **correct**, not merely
safe: `%.800g` of the minimum subnormal measures **758 characters** on this glibc, so the spec can
genuinely produce more than the scratch holds and glibc's trailing-zero stripping is the only reason
the `42.0` case looked short. The genuinely *loose* case is an integer conversion with a field width
between 192 and 511 (`%-200d` → bound 520 > 511 → refused although 200 bytes would fit). No live
caller has a field width at all (§1), so this costs nothing today; the one-line refinement if it
ever matters is to pass the per-arm intrinsic (`320` for the float arm, `24` for the other two)
instead of the uniform 320 — deliberately **not** done, because per-arm casework is the thing 1606's
post-mortem says to avoid.

---

## 5. RECOMMENDED SHAPE — the final text of every changed line

Three edits in `src/util.c`, all inside the `#else` (hand-rolled) arm. **Verified by building the
whole of `src/util.c` from a patched copy** out of tree; not landed, per the stage's remit.

### 5.1 New helper, immediately above `size_t my_snprintf(char *string, size_t size, …)` — i.e.
**after** the `#else` at `src/util.c:640` (read at `91bb1bd7`), so a `HAS_SNPRINTF` build never
sees an unused static:

```c
#define MY_SNPRINTF_NSTR 512
static size_t spec_maxout(const char *spec, size_t len)
{
  size_t i, run, max = 0;
  for(i = 0; i < len; i++) {
    if(spec[i] == '*') return (size_t)-1;
    if(spec[i] >= '0' && spec[i] <= '9') {
      run = 0;
      while(i < len && spec[i] >= '0' && spec[i] <= '9') {
        if(run < 1000000) run = run * 10 + (size_t)(spec[i] - '0');
        i++;
      }
      if(run > max) max = run;
      i--;
    }
  }
  return max + 320;
}
```

* `run < 1000000` caps the accumulator so a spec of fifty digits cannot wrap a `size_t`; a capped
  run is ≥ 1000000 and therefore refuses, which is the safe direction.
* `(size_t)-1` for `*` is larger than any `sizeof`, so the same comparison refuses it.
* `i--` after the inner loop is correct when the inner loop ended on `i == len`: the outer `i++`
  then makes `i == len` again and the loop exits.
* `MY_SNPRINTF_NSTR` is the knob: 512 is the smallest power of two above the **337** the widest live
  spec needs (`%.17g` → 17 + 320) and it keeps every precision ≤ 191 working on every conversion.
* Both names are free: `/usr/bin/grep -rn 'spec_maxout\|MY_SNPRINTF_NSTR' src/` is empty.
* **The comment block that must go above it** is §3d's derivation *with* its measurement, per the
  brief's *"a comment that quotes a measurement must reproduce it"*: the three numbers to quote are
  `sprintf("%f", -DBL_MAX) == 317`, `sprintf("%.200f", -DBL_MAX) == 511`, and
  `xschem --rcfile '%*d'` → rc 134 at `91bb1bd7`, each reproducible from §1/§3d of this receipt,
  which the comment should cite by path (`doc/claude/issue_1608_batch/receipts/B-bound-shape.md`).
  ⚠ Do **not** carry 1606's "774 characters" figure into it: measured here, `%.767g` and `%.2000g`
  of the minimum subnormal are **758**. 758 ≤ 774 so 1606 is not contradicted, but 774 is not a
  number this receipt can reproduce and the comment must only quote what it can.

### 5.2 The declaration, in **each of the three arms** — `src/util.c:686`, `708`, `731` at
`91bb1bd7` (`nfmt` unchanged at 50; the measured live maximum spec length is 5):

```c
      char nfmt[50], nstr[MY_SNPRINTF_NSTR];
```

### 5.3 The two guards, in **each of the three arms**, inserted immediately after the existing
`l = f - fmt+1;` and before `strncpy(nfmt, fmt, l);` — **two separate statements, deliberately**, so
that each is a single-hunk sabotage with its own reddening row:

```c
      l = f - fmt+1;
      if(l >= sizeof(nfmt)) {                        /* issue 1608 (A)/(B) */
        overflow = 1;
        break;
      }
      if(spec_maxout(fmt, l) >= sizeof(nstr)) {      /* issue 1608 (C) */
        overflow = 1;
        break;
      }
      strncpy(nfmt, fmt, l);
      nfmt[l] = '\0';
```

The thresholds match the driven ones exactly: `l >= sizeof(nfmt)` refuses `l == 50` (the silent (B)
clobber) and `l ≥ 51` (the (A) abort) and passes `l == 49`; `spec_maxout(…) >= sizeof(nstr)`
requires `maxout + 1 <= sizeof(nstr)`, so the subsequent `sprintf` writes at most
`maxout ≤ sizeof(nstr) - 1` bytes plus its NUL. The post-write `if(n + nlen + 1 > size)` check
**stays exactly as it is** — it is the one that must remain *exact*, because a conservative
pre-check against the caller's `size` would refuse `my_snprintf(buf, 5, "%d", 3)` and break
hundreds of live callers.

### 5.4 What the shape costs, measured

| | baseline `src/util.o` | patched copy, same flags |
|---|---|---|
| `my_snprintf` code size (`nm -S`) | 1615 bytes (`0x64f`) | **1613** (`0x64d`) + `spec_maxout` 206 (`0xce`) |
| stack frame (`sub $N,%rsp`) | 408 bytes (`0x198`) | **872** bytes (`0x368`) |

+464 bytes of stack, not +1386: gcc already overlapped the three arms' disjoint scratch scopes into
one slot and still does. +204 bytes of code.

**Warning-identical, on both build modes.** Production flags: the patched copy reproduces the single
pre-existing `-Wdiscarded-qualifiers` in `my_strndup` and nothing else; with
`-Wall -Wformat-overflow=2 -Wformat-truncation=2` added, nothing new. `--debug` flags
(`-g -O0 -Wconversion -Wno-sign-conversion -Wall -std=c89 -pedantic`): **4 warnings before, 4 after,
and `diff` of the normalised texts shows only the +43-line shift of the pre-existing
`'/*' within comment`.** So the shape is C89-clean — no implicit declaration, no `-Wconversion`, no
`-pedantic` complaint.

### 5.5 Fencing notes for Stage C (internal engineering, stated not queued, per H3)

* **The backbone is behavioural and it needs no new seam**: `--rcfile <spec>` reaches all three arms
  before the GUI exists, headless, with `rc` as the verdict. Rows: `%-2000d` / `%-2000x` /
  `%-2000c` / `%-2000u` / `%-2000p` / `%-2000f` / `%-2000g` / `%-2000e` / `%.400f` / `%*d`, each
  `rc != 134`; plus the two thresholds `%-49d` and `%<47 dashes>d` must stay **rc 1** (they are the
  byte-identity rows), and `%-50d` and `%<48 dashes>d` must become rc 1 **from** 134 and from a
  silent clobber respectively.
* ⚠ **Read `rc`, not the death marker.** `main.c`'s `sig_handler` does not trap SIGABRT (1606
  measured this), so a fortify abort prints **no column-0 `FATAL: signal`** line. The brief's
  "assert both the exit code and the absence of a column-0 marker" rule is satisfiable but the
  marker half is permanently inert here, exactly as it was for 1606.
* **Each guard reddens on its own removal, and they are not redundant**: delete the `(A)/(B)` guard
  and `%<51 dashes>d` returns to rc 134; delete the `(C)` guard and `%-2000d` returns to rc 134.
  Neither sabotage reddens the other's rows. The `l == 50` row is the one that proves the guard is
  about (B) and not only (A) — it is **rc 1 both before and after**, so it must assert the *output*
  (`cannot find 104` vs `cannot find ` / refused), not the exit code.
* **A file-borne row is available and cheap** (§0's seven-line `.sch` + `xschem print svg`), and it
  is worth having in addition to `--rcfile`, because it is the reachability a reader will doubt.
* A static row, if Stage C wants one, should grep for `spec_maxout` **by name** and for
  `MY_SNPRINTF_NSTR` in the declaration — and its own name must say that is what it greps.
  ⚠ `nstr` is now spelled `nstr[MY_SNPRINTF_NSTR]`, so any existing row or doc that greps
  `nstr\[50\]` will stop matching: `/usr/bin/grep -rn 'nstr\[50\]' src/ tests/ doc/` before landing.

---

## 6. What a `*`-aware `my_snprintf` would cost ONCE this lands — costed, NOT implemented

### 6.1 First, the verification the stage asked for: 1606's reason the cheap option is off the table

**Confirmed, with one correction that matters.** A comment-stripped multi-line scan for every
`my_snprintf` whose value is consumed finds **exactly five** sites:

| site | shape | what `vsnprintf` semantics would do |
|---|---|---|
| `my_itoa` (`util.c`) | `n = my_snprintf(s, S(s), "%d", i); … xctx->tok_size = n;` | `tok_size` becomes "would have been" |
| `dtoa` (`util.c`) | `n = my_snprintf(s, S(s), "%.8g", i); … xctx->tok_size = n;` | same |
| `dtoa_prec` (`editprop.c`) | `n = my_snprintf(s, S(s), "%.10e", i); … xctx->tok_size = n;` | same |
| `hilight.c` (the `net_hilight_style` Tcl table builder) | `off += my_snprintf(s + off, sz - off, …)` | **`off` passes `sz`; `sz - off` is `size_t` and wraps to ~2^64; `vsnprintf` then writes unbounded** |
| `token.c` (`@@pin` expansion) | `result_pos += my_snprintf(result + result_pos, tmp, "%s", str_ptr)` | `result_pos` advances past the data; the next `STR_ALLOC` sizes from a wrong offset |

⚠ **1606 says "five sites … three of them as an accumulator". It is five sites and TWO
accumulators, and only ONE has the `sz - off` shape** (`hilight.c`). The load-bearing half of
1606's argument therefore rests on one site, not three. **The conclusion still stands** — one such
site is enough, and `tok_size` is read as a length as well as a flag (`actions.c`, ~20 sites) — but
the driver should not repeat the "three" in any new prose.

Two hazards in that arm that 1606 did **not** name, and which strengthen the rejection:

* it pops a **modal Tcl alert** on every truncation (`if(has_x && size_of_print >= size) … tcleval`)
  — from a formatter called at 753 sites including `kklex()` and the netlist walk;
* `size_of_print` is an `int` assigned to a `size_t` return, and `vsnprintf` returns **negative** on
  an encoding error → `(size_t)-1`; the comparison `size_of_print >= size` promotes the negative to
  a huge `size_t`, so the alert fires too.

And `scheduler.c`'s `#ifdef HAS_SNPRINTF` line is confirmed verbatim as the proof the arm has never
compiled: `my_snprintf(res, S(res), "HAS_SNPRINTF=%s\n", HAS_SNPRINTF);` — `%s` given whatever
integer the macro would be.

### 6.2 What `*` support then costs

**Good news the driver should hear: `spec_maxout` is the first half of option 3, not a detour.**

The shape: C cannot pass a variable argument count to `sprintf`, so the right implementation is
**not** nine `sprintf` call sites (3 arms × {no star, one star, two stars}) but a **spec rewrite** —
consume one `va_arg(args, int)` per `*`, left to right, and emit the value as digits into `nfmt`, so
a single `sprintf(nstr, nfmt, v)` call remains. Then:

* the **bound is already written**: run the *same* `spec_maxout` on the rewritten digits-only spec,
  and the `*` sentinel in 5.1 simply stops being reachable;
* `nfmt[50]` → `nfmt[80]` (each `*` becomes up to 11 characters; two stars is +20), and the
  `l >= sizeof(nfmt)` guard moves from the caller's substring to the rewritten length;
* **the trap**: a negative `*` must reproduce C's rules — a negative width is a `-` flag, a negative
  precision is *omitted*. 1606 already measured the consequence of getting this wrong
  (`ev_precision = 2147483648` is **safe** while 73 is not, because `atoi` wraps to `INT_MIN` and a
  negative `*` precision means "omitted"). A rewrite that emits `-2147483648` as digits would invent
  a defect 1606 does not have.
* Estimate: ~25 lines of rewrite helper, +2 lines per arm, and the same three behavioural rows this
  batch's suite will already have, re-pointed at `%.*g`.

⚠ **But `*` support alone does NOT retire 1606's thirteen clamps, and the driver should not plan as
if it does.** Those clamps exist to keep a *complete shorter number*; `my_snprintf`'s overflow
behaviour (§4) **drops the conversion entirely**, so routing `dtoa_eng` through a `*`-aware
`my_snprintf` would replace 1606's clamped `1e+288T` with `x=` and nothing after it. That is worse
at those sites, which is precisely what 1606 said.

**The step that does retire them is one further extension of the same helper: make it CLAMP rather
than refuse** — rewrite the precision *down* to what fits instead of returning the sentinel. The
rewrite machinery for that is the same machinery `*` support needs, which is why these two should be
costed as one follow-up and not two. And the clamp would then be **more correct than the thirteen
hand-written ones**, because `my_snprintf` knows `size - n` exactly at the moment of the write,
which is the number 1606 had to derive by hand per branch and got wrong once in a way only gcc
could see.

⚠ **One residual the follow-up must price, not discover:** `dtoa_eng`'s format is `"%.*g%c"`. An
internal clamp against `size - n` leaves no room for the trailing `%c`, so it needs to reserve the
remaining format's own length (`strlen(f + 1)` is an upper bound on the trailing *literal* bytes and
an under-estimate when the tail holds further conversions). That is one line and one comment, and it
is the thing that would otherwise be found by a suite instead of by a plan.

---

## 7. Contradictions and out-of-scope defects — named, not fixed

1. **`svgdraw.c` still has the defect `psprint.c` fixed as issue 1351.** Four sites pass a
   non-literal format (`textfont` twice, `tclgetvar("svg_font_name")` twice). `font=%s` reads a
   vararg that was never pushed — driven, it survived once here (rc 0, `DONE-OK`) because the
   garbage pointer happened to be readable, which makes it non-deterministic rather than safe.
   **Bounding `my_snprintf` does not fix this**; the `%s` arm has no `nfmt`/`nstr`, and the fix is
   the one `psprint.c` already has (`"%s"` with the value as an argument). Carried forward.
2. **`xinit.c`'s `my_snprintf(name, S(name), cli_opt_rcfile)` is the same defect on the command
   line** — one word to fix (`"%s", cli_opt_rcfile`). Carried forward with (1); it is the cheapest
   single line in this whole area and it removes the reachability that makes (C) live.
3. **(D) — a one-byte write PAST THE CALLER'S BUFFER, on all four arms, and it is live.** The check
   is `if(n+l > size)`, so `n+l == size` passes and the next statement is `string[n+l] = '\0'`,
   i.e. `string[size]`. Driven with a canary immediately after a 4-byte buffer:
   ```
   ORIG fmt=|abcd%d| size=4 ret=4 buf=|abcd| canary[0]=0x00 *** CLOBBERED (byte at index size) ***
   ORIG fmt=|abcd%s| … CLOBBERED   ORIG fmt=|abcd%g| … CLOBBERED   ORIG fmt=|abcd%p| … CLOBBERED
   ```
   It does **not** abort — the destination is a pointer parameter, so `_FORTIFY_SOURCE` cannot size
   it, exactly as 1606 measured at `graph_marker_fmt`. The common live shape is
   `my_snprintf(buf, S(buf), "%s/%s", a, b)` with `strlen(a) == S(buf) - 1`, which is
   data-dependent and needs no odd format at all. **My recommended shape does not fix it** (it is a
   different check). The fix is `>` → `>=` at four sites, plus a fence each, plus a decision about
   the exact-fit case. ⚠ **This is the driver's scope call**, and it is worth making now rather than
   later, because it lives in the same four `if` statements the patch already touches.
4. **(E) — `my_snprintf` can return without writing anything to `string`.** Driven:
   `my_snprintf(u, 2, "abcd%d", 7)` returns 0 and leaves `u` byte-for-byte as it was
   (`51 51` = the `'Q'` canary), so a caller that formats into an uninitialised buffer and then
   reads it gets garbage rather than `""`. Carried forward.
5. **The missing `overflow = 1` in the `d/x/c/u` and `p` arms is PROVABLY inconsequential** — worth
   recording so nobody files it. Those two arms `break` on `if(n+l > size)` without setting the
   flag, unlike the `%s` and float arms. It cannot matter: at break time `l = fmt - prev` and
   `n + l > size`, while the tail test uses `l = f - prev ≥ fmt - prev` with the same `n`, so
   `n + l + 1 <= size` is false on every such path and the tail copy is skipped regardless. The
   `dbg(1, …)` still fires. **Cosmetic only.**
6. **`%ld` / `%lu` are wrong in this formatter and the census finds three live uses**
   (`scheduler.c` ×3). The arms do `i = va_arg(args, int)` and then `sprintf(nstr, "%ld", i)`, so
   `sprintf` reads 8 bytes where an `int` was passed. Not an overflow (20 digits fits), so the bound
   does not touch it; the value is simply unreliable above 2^31. Carried forward.
7. **`%.6f` is a live abort, not a latent one.** §4's 640-case comparison has the original dying on
   `%.6f` of ±DBL_MAX at every buffer size tried. The issue's *"safe only because its subject is
   bounded, which is a property of the caller"* is right, and the consequence — that this is a live
   format whose safety no reader of `util.c` can check — should be in the issue rather than in the
   LATENT section.
8. **The never-compiled `HAS_SNPRINTF` arm**: §6.1 gives three independent reasons to *not* enable
   it (the return-value semantics, the modal alert, the negative-`int`-to-`size_t` comparison) and
   `scheduler.c`'s `%s`-given-an-int remains the cleanest proof it has never built. This receipt has
   **no opinion** on delete-vs-fence, which the plan assigns to Stage A item 4; but note that after
   5.1 the `#else` arm gains a `static` helper, so anyone who *does* enable `HAS_SNPRINTF` will get
   an unused-static warning unless the helper stays inside the `#else`, which 5.1 puts it in.

---

## 8. What I could NOT measure

* **No Stage A receipt existed**, so nothing here is cross-checked against an independent census.
  §1's 753 is my own parse; the 769 textual figure the issue quotes is reproducible.
* **The extraction-vs-binary risk the brief warns about.** §4's byte-identity and §2's threshold
  sweeps run on a **verbatim `sed` extraction** of the `#else` arm (lines 646–768 at `91bb1bd7`)
  compiled standalone, which is the instrument the brief says produced a non-fact in the 1606 batch.
  I mitigated it rather than assumed it away: the extraction's thresholds are **identical to the
  ones driven in the built binary** — `l ≤ 49` safe / `l == 50` silent / `l ≥ 51` abort, and
  `%-49d` safe / `%-50d` abort — so the extraction reproduces the real function at both boundaries.
  It is still an extraction, and the 640-case byte-identity claim has **not** been re-driven through
  the binary. Doing so needs the patch landed, which this stage may not do; **Stage C should re-run
  the `--rcfile` threshold table against the real binary after landing** and say so.
* **No Windows build.** The `%p`, `%ld` and `long`-width figures are x86-64 SysV glibc only.
  `XSchemWin/` exists and `PlatformToolset v143` is recorded, but nothing was compiled for it — the
  same limitation 1606 disclosed, repeated here rather than quietly inherited.
* **`MY_SNPRINTF_NSTR = 512` is a judgement, not a measurement.** 338 is the measured floor (the
  widest live spec needs 337). 512 buys precision ≤ 191; 1024 would buy ≤ 703 for another 512 bytes
  of stack. Nothing measured says which a future caller will want.
* **No T1 run.** This is a read-and-cost stage; the tree is unmodified and the gate is Stage D's.
* **`spec_maxout`'s bound is not proved exhaustively.** It is derived from `max(width, 311 + prec)`
  and checked against 9 extreme doubles at 11 precisions plus the integer extremes. A
  brute-force sweep over precision 0–4000 (1606 did one for `%.*g`) was **not** run.

---

## Commands, for re-running

```sh
cd /home/analog/dev/xschem-claude && make -C src                      # rebuild before any figure
S=<scratchpad>                                                        # census, probes, harness
timeout 120 python3 $S/census.py                                      # §1  753 calls, 19 specs, 5 non-literals
timeout 60 gcc -O2 -o $S/libcmax $S/libcmax.c && $S/libcmax           # §1  glibc worst cases
H=$(mktemp -d ${TMPDIR:-/tmp}/xschem-test-home.$$.XXXXXX)             # throwaway HOME
env -u DISPLAY HOME="$H" timeout 30 ./src/xschem --nogui --pipe -q --rcfile '%-2000d'   # §0 rc=134
env -u DISPLAY HOME="$H" timeout 40 ./src/xschem --nogui --pipe -q \
  --command "xschem load $S/sch/t.sch; xschem print svg $S/sch/out.svg; puts DONE-OK"   # §0 file-borne
sed -n '646,768p' src/util.c > $S/orig_body.c                         # the verbatim extraction
timeout 180 gcc -O2 -o $S/live2 $S/harness.c $S/main_live2.c && $S/live2   # §4  640 cases, 0 diffs
timeout 180 gcc -O2 -o $S/bad   $S/harness.c $S/main_bad.c   && $S/bad     # §2  threshold sweeps
timeout 120 gcc -O1 -o $S/obo   $S/harness.c $S/main_obo.c   && $S/obo     # §7.3 canary
gcc -c -pipe -g -O0 -Wconversion -Wno-sign-conversion -Wall -std=c89 -pedantic <inc> $S/util_patched.c
nm -S $S/up_prod.o; objdump -d --disassemble=my_snprintf $S/up_prod.o | /usr/bin/grep 'sub .*rsp'
```
