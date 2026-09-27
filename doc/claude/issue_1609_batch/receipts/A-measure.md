# Stage A receipt — issue 1609, measurement

Measured at `70fd152e` (`git log --oneline -1`), x86-64 Linux, gcc 15.2.0 (Ubuntu 15.2.0-16ubuntu1),
glibc with `_FORTIFY_SOURCE` active (the arm's `sprintf` relocates to `__sprintf_chk`).
Scratch: `<scratchpad>/stageA_1609/`. **No file under `src/` or `tests/` was changed.**

---

## 0. THE HEADLINE, BEFORE THE BULLETS

**K1.5 survives — the door really is shut.** No format string reaching this arm can come from
outside the binary. Two independent censuses find **zero** non-literal format arguments anywhere in
the tree, and both of 1608's doors were re-driven and come back verbatim.

**But a different premise in the plan is REFUTED, and it changes the fix.** `PLAN.md` Stage B item 3
says "Confirm the gate already refuses [`ll`]", and 1608's J4 lists `hh` among what the scanner
accepted and was meant to stop. **The gate refuses neither.** `my_snprintf_spec_ok()`'s whitelist is
a **per-character** loop (`else if(c == 'l' || c == 'h') continue;`), so every repetition passes:
`%lld`, `%llu`, `%llx`, `%hhd`, `%hhu`, `%lhd`, `%hld`, `%llld`, `%llllllllld` and `%hhhhd` are all
**accepted** today. Driven, verbatim, with the real `src/util.o`:

```
%lld        | accepted |   4 | |X42Y|          <- a long 4294967338 pushed; 42 is its low 32 bits
%hhd        | accepted |   4 | |X-1Y|
%hhu        | accepted |   4 | |X44Y|          <- 300 pushed; 44 == 300 mod 256
%llld       | accepted |   5 | |X%ldY|         <- glibc re-emits a %-fragment, no number at all
%llllllllld | accepted |  11 | |X%llllllldY|
%zd %jd %td %qd %I32d %*d %nd  | REFUSED |  1 | |X|
```

So the whitelist's *intent* ("only `l` and `h`, which live callers use") is not what it *implements*.
This does not open a door — no non-literal format exists — but it widens the set of spellings the fix
must be correct for, and it is a second defect in the 1608 gate that nothing currently fences.

**And one shape that would have made the fix a one-liner must not be used.** See §7: normalising
every spec to carry `l` (so one `sprintf` call serves the whole arm) turns every live `%c` into
`%lc`, and `%lc` of a byte ≥ 128 makes glibc's `sprintf` **return −1**, which this function never
checks — driving `n` (a `size_t`) to `SIZE_MAX` and producing an **out-of-bounds write and a
`(size_t)-1` return**, rc 0, silently. `draw.c`'s `%c` is fed a `.sch` graph attribute's first byte,
so that route would be **file-borne**.

---

## 1. K1.1 — CONFIRMED in its conclusion, REFUTED in its mechanism and in its range

> *"`"%ld"` of a `long` above `INT_MAX` prints the **truncated** value, not garbage, on this machine,
> because x86-64 sign-extends the `int` back into a full vararg slot."*

**Confirmed: truncated, not garbage, and reproducible.** Instrument: a 30-line driver linked against
the **real `src/util.o`** — the same object file `src/xschem` is built from, not a `sed` extraction
(§9 has the recipe). Column 3 is `my_snprintf`, column 4 is plain `sprintf` with the same spec and
the same C type:

```
%ld  lv=4294967338           my_snprintf=|42|          control=|4294967338|
%lx  0x1234567890AB          my_snprintf=|567890ab|    control=|1234567890ab|
[%12ld] 4294967338           my_snprintf=|[          42]|  control=|[  4294967338]|
a=%ld b  4294967338          my_snprintf=|a=42 b|      control=|a=4294967338 b|
%ld  4194304 (live-sized)    my_snprintf=|4194304|     control=|4194304|
```

Deterministic: two consecutive runs and a run under a changed environment block are byte-identical
(`diff` clean, pointer lines excluded). This is a **truncated value**, which L9 permits quoting, not
stack garbage.

**REFUTED: it is ZERO-extension, not sign-extension.** The instruction is in the shipped object.
`objdump -dr src/util.o`, inside `my_snprintf`, immediately before the `d/x/c/u` arm's `sprintf`:

```
  16e2:	mov    0x10(%rsp),%r8d          <-- `i`, a 32-bit load into r8d
  16e7:	mov    $0x200,%edx              <-- 512 == MY_SNPRINTF_NSTR, so this is the d/x/c/u arm
  16ec:	mov    0x18(%rsp),%rcx
  16f1:	mov    $0x2,%esi
  16f6:	lea    0x90(%rsp),%rdi
  1700:	call   __sprintf_chk
```

A 32-bit register write zeroes the upper 32 bits of the 64-bit register, so `%ld` reads the
zero-extended low half. Not an optimisation artefact: `util.c` compiled at **-O0, -O1, -O2, -O3 and
-Os** all behave identically (and -O0, which gets a plain `sprintf` with no fortify, emits
`mov -0x374(%rbp),%edx`, again a 32-bit write).

**Therefore the range in the issue file is wrong, and the correction matters.** The two columns agree
on exactly `[0, 2^32)` and nowhere else:

```
  value                      my_snprintf            sprintf(control)
  INT_MAX+1 2147483648       2147483648             2147483648             same
  0x80000001 2147483649      2147483649             2147483649             same
  2^32-1  4294967295         4294967295             4294967295             same
  2^32    4294967296         0                      4294967296             DIFFERS
  2^32+42 4294967338         42                     4294967338             DIFFERS
  -1                         4294967295             -1                     DIFFERS
  INT_MIN -2147483648        2147483648             -2147483648            DIFFERS
  LONG_MAX                   4294967295             9223372036854775807    DIFFERS
  LONG_MIN                   0                      -9223372036854775808   DIFFERS
```

Two sentences in `1609-…md` must change:

* *"step 2's promotion sign-extends the `int` back into a full slot, so the truncated value
  round-trips and prints"* — the truncated value round-trips **only as an unsigned 32-bit quantity**.
  A **negative** `long` never round-trips: `%ld` of `-1` prints `4294967295`.
* *"A `Window` XID is 32 bits of a 64-bit `unsigned long` on LP64, so one at or above 2^31 would
  print sign-extended"* — **it prints correctly.** Driven: `%lu` of `0x80000001` gives
  `2147483649`, identical to the control. Every XID is a non-negative CARD32, i.e. inside the
  agreeing band, so the window-id getter cannot misprint on x86-64 at any value.

**And the ABI does not make this choice — both psABIs say the opposite.** The issue file's *"It is
correct by the ABI's choice of slot layout"* is refuted by the x86-64 psABI itself. From
`x86-64-ABI/low-level-sys-info.tex` (fetched to scratch; §8 names the artefact), §3.2.3 Parameter
Passing, verbatim:

> "When a value of a type of class INTEGER is returned or passed in a register or on the stack, the
> excess bits that would not be present in the memory representation of the type (see
> figure basic-types) are **unspecified**." — footnote: "That is, the consumer side of those values
> needs to extend them or use short form instruction variants."

`sprintf` reading 8 bytes for `%ld` **is** that consumer side. So on x86-64 the correctness is a
property of **gcc's instruction selection**, not of the ABI, and the honest sentence is "this
compiler happens to zero-extend", not "the ABI round-trips it".

---

## 2. K1.2 — the direction is supported; the line count is Stage B's, and one shape is now ruled out

> *"The fix is **fetch by modifier**, not refuse the modifier, and it is under ten lines."*

Not a Stage A claim to settle, but three measurements bear on it.

**(a) `-Wformat` is already policing every caller, which is a strong argument for fetch-by-modifier
and against "refuse `l` and cast at the call sites".** Compiling all 40 `src/*.c` with
`-Wformat -Wformat-nonliteral` gives **zero** argument-type mismatches at any `my_snprintf` call:

```
$ for f in src/*.c; do gcc -fsyntax-only -Wformat -Wformat-nonliteral <build CFLAGS> $f; done
11 warnings total:  6 [-Wdiscarded-qualifiers]  (unrelated)
                    5 [-Wformat-nonliteral] at draw.c:5309, draw.c:5310,
                      util.c:870, util.c:901, util.c:932   (the three `sprintf(nstr, nfmt, i)` calls
                      and issue 1606's two draw.c shapes -- exactly what row W1 permits)
```

Anti-vacuity probe (gcc *would* have caught a mismatch — 4 warnings):

```
my_snprintf(b, sizeof b, "%d", (long)v);   -> warning: format '%d' expects argument of type 'int',
                                              but argument 4 has type 'long int' [-Wformat=]
my_snprintf(b, sizeof b, "%ld", (int)v);   -> diagnosed too
```

So the header's `format(printf,3,4)` already forces every caller to hand a `long` to `%ld`, and
**the only type mismatch in the whole program is inside `my_snprintf` itself**. Option 2 (refuse `l`,
rewrite the callers to `"%d", (int)x`) would leave gcc **satisfied** — it converts a bug gcc is
currently able to describe into a cast gcc must accept. That is the substance for Stage B item 1's
"say whether that matters": **yes**, and it is the strongest argument in the file for option 1.

**(b) The fetch precedes the gate, but the spec span is already available, so no restructuring is
needed.** The arm today:

```c
i = va_arg(args, int);                                   /* fetch  */
l = f - fmt+1;                                           /* span   */
refuse = !my_snprintf_spec_ok(fmt, l, sizeof(nfmt), sizeof(nstr));
```

`fmt` and `f` both hold their final values before the fetch, so `l = f - fmt + 1` can simply move
above it and the spec can be scanned for `l`/`h` there.

**(c) The `sprintf` call must branch too, because the argument type differs** — `"%d"` with a `long`
is as wrong as `"%ld"` with an `int`. So the arm needs either two `sprintf` calls or a fourth
variable, and a fourth non-literal `sprintf` in `util.c` **touches row W1's permitted-shape list**
(W1 permits shapes by their text; a new `sprintf(nstr, nfmt, lv)` is a new text). Stage B should say
so explicitly.

**(d) The one-call shortcut is ruled out by measurement.** "Always fetch by modifier into a `long`
and insert `l` into `nfmt` when the spec lacks one" would give a single `sprintf` site and a single
variable — and it is wrong twice. See §7 for `%c`→`%lc` (memory-safety), and note that it must fetch
`unsigned int`→`unsigned long` for `u`/`x`, not `int`→`long`: with the correct unsigned widening the
outputs are byte-identical to today's, which is measured in §6.

---

## 3. K1.3 — CONFIRMED, and for a stronger reason than the plan gives

> *"Nothing a user sees changes, for any value any live caller can produce."*

The plan's reason is "all three live values are small". The measured reason is better: **every value
any live caller can produce lies in `[0, 2^32)`, which is exactly the band where the two columns
agree** — so this is not "small today", it is "cannot leave the band on x86-64, ever".

Live values, measured on the dev display (`DISPLAY=:99`, throwaway HOME, `--pipe -q --script`):

```
xschem globals   ->  XMaxRequestSize=65535
                     XExtendedMaxRequestSize=4194303
xschem windows   ->  {.drw . . 6291739 …greycnt.sch 3 …}      <- the %lu window-id getter
xschem get first_sel -> 1 0 0                                  <- the %hu getter
```

Type ceilings, from the headers on this machine:

* `/usr/include/X11/Xlib.h:1709,1712` — `extern long XMaxRequestSize(…)`,
  `extern long XExtendedMaxRequestSize(…)`; `/usr/include/X11/Xlib.h:524` —
  `unsigned max_request_size; /* maximum number 32 bit words in request*/`. An `unsigned` source
  caps both at `2^32 − 1`, inside the band.
* `/usr/include/X11/X.h:66,96` — `typedef unsigned long XID; … typedef XID Window;` with the
  protocol value a CARD32. Non-negative and `< 2^32`, inside the band.

**So K3 holds and no ruling is owed.** Nothing user-visible can change on x86-64 whatever the fix
does, provided the fix reproduces §6's table.

⚠ The corollary Stage C must plan around: **no live caller can be made to redden, on principle and
not merely today.** A row that exercises the three real getters fences nothing, forever.

---

## 4. K1.4 — CONFIRMED, with the promotion argument verified rather than inherited

> *"`%hu` is safe by default argument promotion and needs no change."*

Verified, not inherited. `src/xschem.h`, the `Selected` typedef, declares `unsigned short type;` and
the live call is `my_snprintf(res, S(res), "%hu %d %u", xctx->first_sel.type, …)` in `scheduler.c`'s
`first_sel` getter. Default argument promotion converts an `unsigned short` to `int` here because
`INT_MAX (2147483647) >= USHRT_MAX (65535)`, so `va_arg(args, int)` is the **correct** fetch, and
`%hu`'s narrowing read of that `int` is the correct read. Driven:

```
%hu  65535    my_snprintf=|65535|  control=|65535|   same
%hd  -1       my_snprintf=|-1|     control=|-1|      same
```

`%hhd` and `%hhu` are **not** refused (see §0), but they are also not mis-fetched: a `signed char`
or `unsigned char` argument promotes to `int` as well, so `va_arg(args, int)` is right and glibc's
narrowing is right. Driven: `%hhd` of `-1` → `-1`; `%hhu` of `300` → `44`. So `h`/`hh` need nothing
from this fix — **only `l`/`ll` do.**

---

## 5. K1.5 — CONFIRMED, re-derived from scratch; the door is shut

Re-derived rather than inherited, with two censuses (which cover each other's blind spot) and two
driven doors.

### 5a. The compiled census — catches a format hidden behind a macro (1608 J9's traps)

`gcc -E` over all **40** `src/*.c` with the build's own CFLAGS (`Makefile.conf`:
`-pipe -O2 -I/usr/include/cairo …`), 26,019,212 bytes of preprocessed text, then a
paren/string-aware split of every `my_snprintf(` argument list:

```
total identifier matches            760
  = 720  call expressions, format argument IS a string-literal sequence
  +  39  the declaration (util.h:74, once per TU) and the definition (util.c:810)
  +   1  the identifier INSIDE a string literal -- `dbg(1, "my_snprintf(): overflow, …")`
         at util.c:948, which is the classic decoy this tree has been defeated by twice
NON-LITERAL format arguments that are not declarations:  0
occurrences of the bare identifier `my_snprintf` not followed by `(`:  0
         (so its address is never taken, and no call can hide behind a function pointer)
```

### 5b. The raw census — catches what this configuration never compiles

The compiled census is blind to a call inside a discarded region. Reading the raw source with
comments stripped:

```
call expressions                                751  (= 750 calls + the util.c:948 in-literal decoy)
apparently NON-LITERAL                            2  -> xinit.c:1559 and xinit.c:1563, BOTH of which
                                                       are backslash-continued string literals
                                                       (read by eye; the instrument's regex, not a door)
=> non-literal format arguments, compiled or not: 0
```

750 raw vs 716 attributed-per-file compiled leaves ~34 calls in regions this build discards —
`#ifndef __unix__`, the `else` arms of the `HAS_POPEN==1 / elif HAS_PIPE==1` chains in `save.c`, the
`#else` of `TCL_MINOR_VERSION >= 6` in `xinit.c`, `draw.c`'s non-`__unix__` arm. All are inside the
751 and all carry literal formats. *(The two instruments report 720 and 716 compiled calls because
they attribute `#line` origin differently; neither number is what the claim rests on, which is the
zero.)*

### 5c. Length modifiers in the tree — exactly the plan's table, confirmed

```
scheduler.c:4614   %hu  in '%hu %d %u'                      the first_sel getter
scheduler.c:6214   %ld  in 'XMaxRequestSize=%ld\n'          under #ifdef __unix__
scheduler.c:6216   %ld  in 'XExtendedMaxRequestSize=%ld\n'  under #ifdef __unix__
scheduler.c:14937  %lu  in '%lu'                            the window-id getter
distinct spellings: ['%hu', '%ld', '%lu']
```

Three `l` sites and one `h` site, matching `PLAN.md`. No `%lx`, no `%lc`, no `%lp`, no `%ll`,
no `%hh` anywhere in the tree.

### 5d. Both 1608 doors, DRIVEN (a grep is not a door test)

`--rcfile`, headless (`env -u DISPLAY … --nogui --pipe -q --script <probe>`):

```
%ld    -> rc=1  Tcl_AppInit() err 2: cannot find %ld
%lu    -> rc=1  … cannot find %lu
%lld   -> rc=1  … cannot find %lld
%hhd   -> rc=1  … cannot find %hhd
%48ld  -> rc=1  … cannot find %48ld
%lp    -> rc=1  … cannot find %lp
%ls    -> rc=1  … cannot find %ls
%s     -> rc=1  … cannot find %s      (was rc 139 SIGSEGV at 91bb1bd7)
%nd    -> rc=1  … cannot find %nd     (was rc 134 at 91bb1bd7)
```

The `.sch` `font=` door, via `xschem load` + `zoom_full` + `print svg` (J12's trap observed):

```
font=%ld       -> rc=0  font-family:%ld      SVG-OK
font=%lu       -> rc=0  font-family:%lu      SVG-OK
font=%lld      -> rc=0  font-family:%lld     SVG-OK
font=%hhd      -> rc=0  font-family:%hhd     SVG-OK
font=Monospace -> rc=0  font-family:Monospace  SVG-OK   <- the control, so the path is live
```

Every spec comes back **verbatim**. K1.5 confirmed.

⚠ **Instrument trap, worth recording.** A `--rcfile` probe **without** `--script` exits **rc 1 with
no output at all**, for every value including a valid file and a plainly nonexistent one — the run
ends before `Tcl_AppInit`'s rcfile block. My first pass read as "door closed, all seven specs
identical" and was measuring nothing. The armed spelling is
`--nogui --pipe -q --rcfile <spec> --script <file>`; `tests/headless/test_snprintf_fmt_1608.tcl`'s
`child` proc already does this and is the shape to copy.

---

## 6. Task 2 — the `x` / `u` / `c` variants, and the baselines a fix must preserve

All four of `d x c u` share one arm and one `int i`.

| spec | in the tree? | plausible? | what it does with an out-of-range value |
|---|---|---|---|
| `%ld` | **live** ×2 (`scheduler.c`, both `XMaxRequestSize` getters) | — | truncates to the low 32 bits, zero-extended; correct on `[0, 2^32)` |
| `%lu` | **live** ×1 (the window-id getter) | — | same band; correct for every XID |
| `%lx` | no | yes — the obvious spelling for an XID or a mask | truncates: `%lx` of `0x1234567890AB` → `567890ab` |
| `%lc` | no | no — `%lc` is `wint_t`, not a `long` | size-safe by accident (glibc `wint_t` is 4 bytes, so `va_arg(args,int)` matches), but see §7 |

`%lc` is **not** a width defect: `wint_t` is `unsigned int` on glibc and `unsigned short` (promoted to
`int`) on Windows, so the fetch width is right either way. A fetch-by-modifier fix must therefore
**exclude `c` from the `l` branch**, or it will fetch 8 bytes for a 4-byte argument.

**The baselines.** Today's output for a negative value, and what the `l`-carrying twin gives when the
widening is done as `unsigned int` → `unsigned long` for `u`/`x` and `int` → `long` for `d`:

```
  %d of -1    today |-1|          %ld of (long)-1              |-1|          same
  %u of -1    today |4294967295|  %lu of (unsigned long)(unsigned)-1 |4294967295|  same
  %x of -1    today |ffffffff|    %lx of (unsigned long)(unsigned)-1 |ffffffff|    same
  %d of -42   today |-42|         %ld  |-42|         same
  %u of -42   today |4294967254|  %lu  |4294967254|  same
  %x of -42   today |ffffffd6|    %lx  |ffffffd6|    same
```

So **one fetch does not serve both** (Stage B item 2): `d` wants `long`, `u`/`x` want
`unsigned long`. With that split every current output is preserved byte for byte. With a single
signed `long` fetch, `%lu` of `-1` would print `18446744073709551615` instead of `4294967295` — a
visible change, and the thing that would turn K3 into a ruling.

**The `va_arg` type rule, which decides whether one fetch could legally serve both.** C99
§7.15.1.1p2, verbatim (fetched to scratch; §8):

> "If there is no actual next argument, or if `type` is not compatible with the type of the actual
> next argument (as promoted according to the default argument promotions), the behavior is
> undefined, except for the following cases: — one type is a signed integer type, the other type is
> the corresponding unsigned integer type, **and the value is representable in both types**; — one
> type is pointer to void and the other is a pointer to a character type."

So a single `va_arg(args, long)` serving `%lu` is defined **only** while the value is `< 2^63`.
⚠ I could not check whether C89 carries those two exceptions — I have the C99+TC3 text, not C90's —
and this tree targets C89, so Stage B should not lean on the exception. Fetching by signedness as
well as by width costs one more branch and needs no exception at all.

---

## 7. Task 4 — the `p` arm, and a CARRIED-FORWARD defect found inside it

**The `p` arm has no width defect.** It fetches `va_arg(args, void *)` and `%p` wants a `void *`, so
the fetch is correct. The gate accepts `l`, so `"%lp"` is admitted; glibc ignores length modifiers on
`p`. Driven:

```
%p     accepted  |X0x7ffce704d4ccY|
%lp    accepted  |X0x7ffce704d4ccY|     identical
%llp   accepted  |X0x7ffce704d4ccY|     identical
%hp    accepted  |X0x7ffce704d4ccY|     identical
%-20p  accepted  |X0x7ffce704d4cc      Y|   (width works in this arm)
```

**Reachable?** No. The tree's only `%p` is `src/util.c`'s `my_realloc`:
`if(debug_var > 2) my_snprintf(old, S(old), "%p", a);` — a literal with no modifier. With zero
non-literal formats, `%lp` cannot be constructed at runtime. **Meaningful?** No: the C standard gives
`p` no length modifier, so `%lp` is undefined behaviour that glibc happens to ignore. Recommendation:
nothing to fix in the `p` arm for 1609; if the gate is tightened, dropping modifiers for `p` is free.

### ⚠ CARRIED FORWARD, NOT IN SCOPE — `sprintf`'s return is never checked for the negative it may give

Found while measuring `%lc`. `sprintf` is allowed to return a negative value, and glibc does:
`%lc` of a value with no multibyte representation in the current locale sets `EILSEQ` and returns
**−1**. The arm then does:

```c
nlen = sprintf(nstr, nfmt, i);         /* -1                                             */
if(n + nlen + 1 > size) { … }          /* -1 + 1 == 0, so the bound PASSES                */
memcpy(string + n, nstr, nlen+1);      /* length 0, harmless                              */
n += nlen;                             /* n is size_t: 0 + (-1) == SIZE_MAX               */
```

Driven, each case in its own process, against the real `src/util.o`:

```
control : sprintf("%lc", 233) returned -1, errno=84 (Invalid or incomplete multibyte or wide character)
"[%lc]"   -> rc=0  ret=1                      out=|]|        prefix `[` overwritten (n went 1 -> 0)
"%lc"     -> rc=0  ret=18446744073709551615   out=||         my_snprintf returned (size_t)-1
"%lcTAIL" -> rc=0  ret=3                      out=|AIL|      the tail memcpy'd at `string + SIZE_MAX`,
                                                             i.e. ONE BYTE BEFORE the caller's buffer
```

Two separate consequences, both silent, both rc 0, no fortify abort — the destination is a pointer
parameter, so `_FORTIFY_SOURCE` cannot size it, exactly 1608's J6 observation:

1. **A `(size_t)-1` return.** `util.c`'s own GUARD 3 comment records that five live sites consume
   this return as a length; GUARD 3's accumulator cap was added to stop `(size_t)-1` arriving by one
   route, and this is a **second route the cap does not cover**.
2. **An out-of-bounds write** at `string − 1`, from the tail `memcpy` — the guard
   `if(!overflow && n+l+1 <= size)` passes because `SIZE_MAX + 5` wraps to `4`.

**Not reachable today** (no live `%lc`; no non-literal format). **It becomes reachable the moment
anyone normalises `%c` to `%lc`**, which is precisely the one-`sprintf`-call shortcut in §2(d) — and
`%c` has 18 occurrences in literal formats, including `draw.c`'s
`my_snprintf(tmpstr, S(tmpstr), "%s[%c]", stok, gr->unitx_suffix)` where
`gr->unitx_suffix = val[0]` and `val` is a graph rect's **`unitx=` attribute out of a `.sch` file**
(`src/draw.c`, `setup_graph_data`). A schematic carrying `unitx=<byte ≥ 128>` would then reach it.
**Named, not fixed, carried forward; it needs its own issue number, which the driver mints.**

---

## 8. Task 6 — the aarch64 argument, which is a DERIVATION, and a better argument that is not

**There is no aarch64 toolchain on this machine, and no way to fake one:** `aarch64-linux-gnu-gcc`,
`aarch64-none-elf-gcc`, `clang`, `qemu-aarch64`, `qemu-aarch64-static` and
`arm-linux-gnueabihf-gcc` are all absent. So per K2 this stays a reading of the document.

I fetched the document rather than recalling it. **AAPCS64, release 2025Q4, date of issue 23 January
2026**, from `https://raw.githubusercontent.com/ARM-software/abi-aa/main/aapcs64/aapcs64.rst`, saved
to scratch as `aapcs64.rst`, md5 `e5ac9e117cb3508dcd2c103057cc61d8`. ⚠ The md5 pins the file I read,
not a release — `main` moves. The **clause identifiers** are the stable citation. Verbatim:

* **§6.8.2 Parameter passing rules, Stage C preamble** — "For each argument in the list the following
  rules are applied in turn until the argument has been allocated. **When an argument is assigned to
  a register any unused bits in the register have unspecified value. When an argument is assigned to
  a stack slot any unused padding bytes have unspecified value.**"
* **Rule C.9** — "If the argument is an Integral or Pointer Type, the size of the argument is less
  than or equal to 8 bytes and the NGRN is less than 8, the argument is copied to the least
  significant bits in x[NGRN]. …"
* **Rule C.16** — "If the size of the argument is less than 8 bytes then the size of the argument is
  set to 8 bytes. The effect is as if the argument was copied to the least significant bits of a
  64-bit register and **the remaining bits filled with unspecified values**."
* **Observation following Stage C** — "Any part of a register or a stack slot that is not used for an
  argument (padding bits) has **unspecified content at the callee entry point**."
* And, relevant to why a caller need not clear them — "Unlike in the 32-bit AAPCS, named integral
  values must be narrowed by the **callee** rather than the caller."

**⚠ But the issue file's aarch64 sentence is OVERSTATED as written**, and I would not ship it.
*"So step 2 reads all 64. So the same code that is accidentally correct on x86-64 can print garbage
on Apple Silicon and on a Raspberry Pi"* implies aarch64 is qualitatively different from x86-64.
It is not, for two reasons:

* On AArch64, writing a W register zero-extends into the X register architecturally, so the natural
  instruction for materialising a 4-byte `int` in a parameter register leaves the upper 32 bits zero
  — the same accident as x86-64's `movl`. This is a derivation about instruction behaviour; I could
  not run it.
* The argument in question is the **5th** of `__sprintf_chk(nstr, flag, size, nfmt, i)`, so it is
  register-passed (x0–x4) and C.16's stack-padding case does not arise for this call.

**The argument that needs no toolchain, and is stronger, is the x86-64 psABI clause in §1**: the
excess bits are unspecified **here**, on the machine that works, and the ABI explicitly puts the
burden of extension on the consumer. Fetched artefact:
`https://gitlab.com/x86-psABIs/x86-64-ABI/-/raw/master/x86-64-ABI/low-level-sys-info.tex`, saved to
scratch as `llsi.tex`. Recommended shape for whatever ships: cite the two psABI/AAPCS64 clauses as
**readings of the documents**, state the x86-64 zero-extension as a **measurement of this gcc at five
optimisation levels**, and drop the "prints garbage on a Raspberry Pi" claim, which nothing here can
support.

Two portability statements that *are* well-founded and are not in the issue file:

* **Win64 (LLP64):** `long` is 4 bytes, `va_arg(args, int)` is the right width, no defect. (The issue
  file has this and it is right.)
* **Any big-endian LP64 target** (`aarch64_be`, `s390x`, `ppc64` BE, `sparc64`): a 4-byte read at an
  8-byte slot's address takes the **high** half, so step 1 is not truncation at all — it fetches the
  wrong half outright, and every value misprints, not only those outside `[0, 2^32)`. A derivation
  from endianness; there is no such target here either.

---

## 9. The instrument Stage C should use, measured to work

The issue's open question 3 says a row needs "a planted caller or a test-only entry point", and
1608's receipts rule out a `sed`-extracted copy. **There is a third option and it works:** link a
driver against **`src/util.o`**, the same object file `src/xschem` is built from.

```sh
gcc -pipe -O2 -Wall -o drive drive.c stubs.c /home/analog/dev/xschem-claude/src/util.o
```

* `util.o` references **57** undefined symbols; all but 16 are libc. The 16 that need stubbing:
  `xctx`, `debug_var`, `has_x`, `errfp`, `home_dir`, `cli_opt_logdir`, `cli_opt_nolog`,
  `actionlog_fp`, `actionlog_filename`, `actionlog_pending`, `actionlog_pending_inst`,
  `actionlog_suppress`, `actionlog_suppress_echo`, `actionlog_cmd_logged`, `interp`,
  and the functions `Tcl_GetString`, `Tcl_GetVar2Ex`, `isonlydigit`, `str_is_blank`, `snap_to_grid`,
  `tcleval`, `tclresult`, `tclsetvar`. A 30-line stub file links clean with **no warnings**
  (`<scratchpad>/stageA_1609/stubs_1609.c`, kept for Stage C to copy).
* Declare `my_snprintf` in the driver **exactly as `util.h` declares it, attribute included**, so the
  row's call sites get the same gcc opinion every real caller gets.
* ⚠ **Two staleness hazards.** `util.o` can be older than `util.c` (nothing in the harness builds),
  so a row must compare mtimes or `make -C src` first and say which; and a row that also compiles
  `util.c` itself into scratch gets a second opinion for free — the two agreeing is cheap evidence
  that neither is stale.
* A refusal is **observable without any new entry point**: the arm writes the literal prefix and then
  breaks, so `"X%<spec>Y"` gives `X` and return 1 when refused, and `X…Y` when accepted. That is what
  §0's table is built on and it needs nothing added to `src/`.

---

## 10. Also found, out of scope, named and not fixed

None of these has a live occurrence; all are latent traps for a future caller. Measured against the
real `src/util.o`.

1. **The `%s` arm has no gate at all and silently ignores width and precision.** It never calls
   `my_snprintf_spec_ok` and never builds an `nfmt`; it copies `strlen(sptr)` bytes.
   `[%-20s]` of `"ab"` → `[ab]` (control `sprintf`: `[ab                  ]`);
   `[%.1s]` of `"abcd"` → `[abcd]` (control: `[a]`). `%ls` and `%hs` print the string with the
   modifier dropped. The `%d` and `%f` arms honour width and precision (`[%20d]` and `[%5.2f]`
   match their controls), so this is specific to `%s`. **Live occurrences: 0** — a scan of every
   literal format finds no `%s` carrying a width or precision.
2. **`%%` is not an escape; it silently reads a vararg nobody pushed.** `"100%% done"` gives
   `100%` + a formatted integer + `one`: the scanner's second `%` re-arms `fmt`, the `d` of `done`
   terminates the spec `"% d"`, and `prev = f+1` swallows the `d`. **Live occurrences: 0.**
   ⚠ **Per L9 no integer is quoted**: it is `va_arg(args, int)` on an unpushed vararg. One driver
   gave a stable ` 0` across nine runs, which is exactly the trap — a second driver with two call
   sites gave `1686260920`, `-759198536`, `-167572296` at the clean site on three consecutive runs
   and `909456384` at a site preceded by another variadic call. The **shape** reproduces; the number
   does not.
3. **The gate's whitelist is per character**, so `ll`, `hh` and any mixture are accepted — §0. This
   is a defect in 1608's GUARD 2 relative to its own stated intent, and nothing fences it.
4. **`sprintf`'s negative return is unchecked** — §7. The most serious of the four.

---

## 11. What I could not measure

* **aarch64 and Win64 behaviour.** No toolchain, no emulator (§8). Derivation only, and the receipt
  says so at every occurrence.
* **Whether C89 carries C99 §7.15.1.1p2's signed/unsigned `va_arg` exception.** I have the C99+TC3
  text only (§6).
* **Whether a non-glibc `printf` behaves as measured** for `%lld`/`%llld`/`%lhd` (the `%`-fragment
  re-emission in §0 is glibc's `form_unknown`, not a standard behaviour) and for `%lc`'s −1 return
  (standard-permitted, glibc-observed).
* **`src/util.o` at an optimisation level other than the five tried** (-O0/-O1/-O2/-O3/-Os), and
  under a compiler other than gcc 15.2.0. No clang here.

## 12. ⚠ Concurrency note for the driver

A sibling crew is working in **the same working tree** and its edits appeared mid-measurement:
`git status` gained ` M src/token.c` and `?? tests/headless/test_generator_shell_1610.tcl`, and
`src/xschem` was relinked at 04:08 under me. **I touched neither.** The effect on this receipt was
checked rather than assumed:

* `src/util.o` kept its Sep 26 21:15 mtime throughout, so every `util.o`-linked figure is from the
  unmodified object.
* The sibling's `token.c` diff touches one `my_snprintf` line and it is a **re-indentation of an
  existing literal-format call** (`git diff src/token.c | grep '^[+-].*my_snprintf'` → exactly one
  `-`/`+` pair with identical text). The raw census re-run on the current tree is byte-identical:
  `751 call expressions, 0 non-literal, 4 modifier occurrences`.
* Both doors were re-driven against the **relinked** binary and are unchanged:
  `--rcfile %ld` → `rc=1 cannot find %ld`; `--rcfile %lld` → `rc=1 cannot find %lld`;
  `font=%ld` → `rc=0 font-family:%ld`.

A gate run in this tree while the sibling's `token.c` is uncommitted would not be measuring 1609.

## 13. Reproducing every figure

```
<scratchpad>/stageA_1609/
  stubs_1609.c        the 30-line stub set; links src/util.o into any driver
  drive_1609.c        §1's first table (%ld/%lu/%lx/%hu/%hd vs controls)
  drive2_1609.c       §0's gate table (accepted/REFUSED per spelling; sections A-F)
  drive3_1609.c       §1's value-boundary table
  drive4_1609.c       §10's %s-width and %% shapes
  drive5_1609.c       §10's L9 probe: two call sites proving %%'s integer is not reproducible
  drive6_1609.c       §6's negative-value baselines and the %c-vs-%lc comparison
  drive7_1609.c       §7's sprintf(-1) cases, one per process
  census_1609.sh      gcc -E of all 40 src/*.c at the build's CFLAGS -> pp/
  scan_1609.py pp     §5a, the compiled census
  rawcensus_1609.py   §5b/§5c, the raw census
  excluded2_1609.py pp  §5b's per-file compiled-vs-raw diff and conditional nesting
  aapcs64.rst llsi.tex n1256.txt   the three fetched documents quoted in §1, §6 and §8
  util.dis util.disr u-O{0,1,2,3}.dis u-Os.dis   the disassemblies quoted in §1
```

Binary-driven figures: `env -u DISPLAY HOME=<scratch>/home ./src/xschem --nogui --pipe -q [--rcfile
<spec>] --script <probe>` for the headless arm, and `DISPLAY=:99 GUI_GATE=0 HOME=<scratch>/home
./src/xschem --pipe -q --script <probe>` for §3's live values. No bare `xschem`; nothing ran on
`$DISPLAY` (`172.20.160.1:0`); `devdisplay.sh` was only queried with `status`.
