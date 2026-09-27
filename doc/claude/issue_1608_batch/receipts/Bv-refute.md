# Receipt Bv — `refute:stage-B-costing`

**Stage B refutation crew, 1608 batch.** Tree at `91bb1bd7`. **The repo working tree was not
modified**: `git status --porcelain` at the end is byte-identical to the opening snapshot, all 40
`src/*.{c,h,y,l}` md5-match `HEAD`, and `/tmp/xschem_emergencysave_*` is 777 entries, as found.
Every patched build lives in a **separate full copy of the tree** under the session scratchpad
(`…/scratchpad/bv1608/tree/`), built from scratch, so no figure here comes from a `sed` extraction.

Unlike Stage B, receipts A **and** B were both present when this crew started, so B is cross-checked
against A here. (B's "receipts/ WAS EMPTY" is credible: `A-measure-and-census.md` has mtime
`15:44:34`, **after** `B-bound-shape.md`'s `15:42:18`.)

---

## 0. MEASUREMENT-INTEGRITY WARNING THE DRIVER MUST READ FIRST

`src/scheduler.c` was rewritten at **16:00:50** and `src/xschem` relinked at **16:00:51** while this
crew was measuring — **another crew is sabotaging and rebuilding the shared tree.** Content matched
`HEAD` again by `16:01:30`, but at `15:5x` I observed `src/scheduler.c:6987: #define XSNP
my_snprintf` in the working tree, which is gone now and is in no commit.

So every driven figure below was **re-taken** after establishing, in one call:

```
$ for f in $(git ls-files src/ | /usr/bin/grep -E '\.(c|h|y|l)$'); do ... md5 vs HEAD ... done
differing=0
$ make -C src -n        # (empty)
$ md5sum src/xschem
b0ccad818f73d8dcded7dbfbb2349400  src/xschem
```

and the same md5 was re-checked **after** each batch of runs (`same=YES` each time). By the end of
this session the repo binary had already moved on to `e13fb8b7197943faa910e2b3e10932e7`.

⚠ **Consequence: no figure in receipts A or B taken from `$REPO/src/xschem` is verifiable, because
neither records a binary md5.** A's "`make -C src` → *Nothing to be done*" was true at the moment it
ran and says nothing about the binary twenty minutes later. Crews measuring concurrently in one tree
need their own build. This crew built one.

---

## 1. REFUTED — the `truncate_or_refuse` headline. The guard does NOT reuse the existing path.

B's `truncate_or_refuse` field opens:

> **DECISION: neither … the guard introduces NO NEW SHAPE, so there is nothing to rule on. It reuses
> the overflow path the function already has and that 753 callers already tolerate. NOT a ruling; the
> driver does not need to file one.**

**This is false, and it is false because of where B puts the guards.** B specifies them "inserted
after the existing `l = f - fmt+1;` and before `strncpy`". Read the arm in order (`my_snprintf`,
`src/util.c`, `#else` arm):

```c
  l = f - fmt+1;
  <<< B's two guards break HERE >>>
  strncpy(nfmt, fmt, l);
  nfmt[l] = '\0';
  l = fmt - prev;
  if(n+l > size) { ... break; }
  memcpy(string + n, prev, l);      /* the literal prefix */
  string[n+l] = '\0';               /* ...and its terminator */
  n += l;
  nlen = sprintf(nstr, nfmt, i);
  if(n + nlen + 1 > size) { overflow = 1; break; }   /* the EXISTING overflow path */
```

The **existing** path breaks *after* the prefix is written and NUL-terminated — which is exactly what
B describes ("leaves the caller the literal prefix written so far, NUL-terminated by the
`string[n+l] = '\0'` above it"). **B's new guards break *before* that write.** A refusal on the
first conversion therefore leaves the destination **entirely unwritten**, which is not the existing
shape — it is B's own carried-forward defect **(E)** ("`my_snprintf` can return WITHOUT WRITING
ANYTHING to `string` … a caller formatting into an uninitialised buffer reads garbage rather than
`""`"). **B's patch manufactures new instances of a defect B itself filed.**

Driven on a full tree copy with B's patch applied verbatim and built from scratch, three independent
callers:

**(a) An uninitialised caller buffer — planted, deterministic.** Planted in `Tcl_AppInit`
(`src/xinit.c`) in the copy:

```c
#define MY_SNP my_snprintf
#define FMT_WIDE "%-2000d"
   if(getenv("XS1608PLANT")) {
     char pbuf[80];
     MY_SNP(pbuf, S(pbuf), FMT_WIDE, 7);
     fprintf(errfp, "PLANT survived: |%.20s|\n", pbuf);
   }
```

```
ORIGINAL util.c : rc=134  *** buffer overflow detected ***: terminated
B's PATCH       : rc=0    PLANT survived: |/tmp/claude-1000/-ho|
```

`pbuf` is a fresh local that `my_snprintf` never touched; the patched run prints **uninitialised
stack**. Same binary, only `src/util.c` swapped and relinked.

**(b) A live non-literal caller whose refusal changes which file xschem reads.**
`Tcl_AppInit`'s `my_snprintf(name, S(name), cli_opt_rcfile)` reuses `name` from the preceding
`my_snprintf(name, S(name), "%s/xschemrc", …)`. On B's patch (`--rcfile` given, headless,
`env -u DISPLAY … --nogui --pipe -q`):

```
--rcfile 'zz%.190f'   rc=1   Tcl_AppInit() err 2: cannot find zz0.00000000000000...   <-- existing path
--rcfile 'zz%.192f'   rc=0   Sourcing /tmp/.../scratchpad/bv1608/tree/src/xschemrc    <-- NEW shape
--rcfile 'zz%-2000d'  rc=0   Sourcing /tmp/.../tree/src/xschemrc
--rcfile 'zz%*d'      rc=0   Sourcing /tmp/.../tree/src/xschemrc
--rcfile 'zzz'        rc=1   Tcl_AppInit() err 2: cannot find zzz
```

The user typed `--rcfile zz%.192f`; the program **silently sourced a different rc file and exited 0**
instead of saying it could not find what was asked for. Under the *existing* overflow path `name`
would have been `"zz"` and the run would have reported `cannot find zz`, rc 1.

**(c) The file-borne door, where the caller's buffer is 80 bytes.** A `.sch` whose only content is
`T {HELLO} 20 -30 0 0 0.4 0.4 {layer=4 font=<spec>}`, then `xschem zoom_full; xschem print svg`:

| `font=` | patched binary, emitted attribute |
|---|---|
| `abc%.190f` (passes guard, trips the **existing** post-check) | `style="font-family:abc;"` |
| `abc%.192f` (**new** guard refuses) | **attribute absent** — `svg_font_family` untouched |
| `abc%-2000d` (**new** guard refuses) | **attribute absent** |
| `%.190f` (existing path, empty prefix) | `style="font-family:;"` — an empty CSS value |

**The two paths are measurably different shapes.** The fix is two lines: set a local `refuse` flag,
fall through the prefix `memcpy` / `string[n+l] = '\0'`, then `break` — so a refusal takes exactly the
path 753 callers already tolerate. (The `spec_maxout` check could simply move below the prefix block;
the `l >= sizeof(nfmt)` check cannot, because it must precede `strncpy`, so the flag is needed.)

⚠ And **H2's own test is met**: a user typed `--rcfile X` and the program now reads a different file
without saying so. That is a live caller whose user-visible behaviour changes shape, so by
`DECISIONS.md` H2 this **is** a ruling, not internal engineering — unless the two-line reordering is
taken, in which case it stops being one. Recommend the reordering and no ruling.

---

## 2. REFUTED — `spec_maxout` does not bound every conversion it accepts. The `L` modifier.

B's `c_bound`: *"'largest digit run in the spec, plus 320' bounds every conversion this function
accepts"*, and its rationale: *"A single loose over-estimate cannot be violated by a branch nobody
thought of."*

`spec_maxout` ignores **every** character that is not a digit or `*`. A **length modifier** therefore
passes through untouched, and `L` changes the constant `311` (sign + 309 integer digits + point) into
`4934`, because a long double reaches ~1.19e4932. Measured on this glibc
(`scratchpad/bv1608/maxlen.c`, `gcc -O2`):

```
%.0Lf          LDBL_MAX     -> 4933   (spec_maxout = 320,  MY_SNPRINTF_NSTR = 512)
%Lf            LDBL_MAX     -> 4940   (spec_maxout = 320)
%.100Lf        LDBL_MAX     -> 5034   (spec_maxout = 420)
```

The spec passes **both** guards (`l` = 3…7 < 50; bound < 512) and reaches glibc unchanged. Driven,
**file-borne**, on HEAD *and* on the patched binary: a `.sch` with `font=%.0Lf` exports

```
<text ... style="font-family:nan;" ...>HELLO</text>
```

— proof that the `L` spec reached `sprintf` and was formatted by it.

**Why it did not abort, and why that is not a defence.** The arm does `i = va_arg(args, double)` and
then hands `sprintf` a *double* while `nfmt` says `%Lf`, so glibc reads **10 uninitialised stack
bytes** as an x87 long double. Every environment I drove read as NaN — 7 `$HOME` sizes × the
`--rcfile` door, plus the `font=` and `svg_font_name` doors — and **B's own patch changed it from
`nan` to `-nan`** (`--rcfile '%.100Lf'`: `cannot find nan` on HEAD, `cannot find -nan` patched),
which proves the value is **frame-layout dependent**. That is precisely the "benign here, by luck,
not by design" that Stage A refused to accept for mechanism (B) — and B's patch grows the frame by
464 bytes, i.e. it perturbs the very layout the accident rests on.

**So the comment B specifies cannot be written truthfully.** The closure is a **whitelist**, not a
wider scan: refuse any character in the spec outside `- + space # 0 ' 0-9 .` plus the conversion
letter. That is a *closed* set; the digit scan is an open-world assumption that silently trusts
every character it does not recognise. It also closes §3 and the `'` hole in §6 in the same line, and
it is cheaper than `spec_maxout` is.

---

## 3. REFUTED — `%n` reaches glibc, aborts from a `.sch` file, and B's patch does not fix it.

Stage A §2: *"`%n` — **not** in the handled set, so the scanner ignores it and it is copied out
literally: `--rcfile '%n'` → `cannot find %n`, rc 1. The classic write-what-where of format-string
injection does **not** apply to `my_snprintf`. Worth recording so nobody over-claims."*

Bare `%n` is indeed copied out. **`%nd` is not.** `n` is not a terminating letter but `d` is, so
`fmt` still points at the `%`, `l = 3`, `nfmt` becomes `"%nd"`, and glibc receives it.
`spec_maxout("%nd") = 320 < 512`, so B's guard **allows** it. Driven at `91bb1bd7`, both doors, both
binaries:

```
--rcfile '%nd'                  HEAD    rc=134  *** %n in writable segments detected ***
--rcfile '%nd'                  PATCHED rc=134  *** %n in writable segments detected ***
.sch  font=%nd  + print svg     HEAD    rc=134  *** %n in writable segments detected ***
.sch  font=%nd  + print svg     PATCHED rc=134  *** %n in writable segments detected ***
```

On this build glibc's fortify blocks the write and aborts. Without that check, `%n` consumes the
already-fetched `int i` as an `int *` — **a write-what-where primitive whose target comes out of a
`.sch` file.** Neither receipt lists this shape. Not to be fixed here, but the driver must not let
"1608 fixed" read as "a hostile `font=` is now safe": after B's patch a stranger's schematic still
kills the process, just through `%nd` instead of `%-2000d`.

---

## 4. EVIDENCE REFUTED — `%*d`'s "driven abort rc=134" is a coin flip

B's `c_bound`: *"`*` MUST BE REFUSED SEPARATELY, AND IT IS LIVE TODAY. Driven at `91bb1bd7`:
`--rcfile '%*d'` and `font=%*d` both abort rc=134."* Stage A §2 says the same and draws the
inference: *"A `%*d` is therefore a (C) overflow with a three-character spec."*

**The conclusion is right. The evidence does not support it.** Same verified binary
(`b0ccad818f73d8dcded7dbfbb2349400`), varying only the length of `$HOME`:

```
PADlen=0   %*d  rc=1    cannot find       -755058064
PADlen=1   %*d  rc=1    cannot find                      -2095595968
PADlen=2   %*d  rc=1    cannot find                                981201328
PADlen=4   %*d  rc=134  *** buffer overflow detected ***: terminated
PADlen=8   %*d  rc=1    cannot find -1766797408
PADlen=16  %*d  rc=1    cannot find -1388751600
PADlen=32  %*d  rc=134  *** buffer overflow detected ***: terminated
```

**5 of 7 environments do not abort.** The width is a vararg nobody pushed, so it is stack bytes that
move with the environment block (one garbage int decodes as ASCII). B already conceded exactly this
for `%.*f` — *"survives only because the garbage int it read happened to be 2"* — and then presented
`%*d` as a hard driven fact one paragraph earlier. **A `%*d` row asserting rc 134 would be flaky.**
Assert the *refusal* after the fix (rc 0, or the output), never the abort before it.

---

## 5. EVIDENCE REFUTED — the 640-case harness cannot see the class it is offered as evidence about

B: *"DOES A USER-VISIBLE STRING CHANGE SHAPE? MEASURED, NOT ARGUED … LIVE-SPEC comparison: cases=640
diffs=0"*.

The conclusion for **literal** callers is right, and I re-derived it independently: the widest digit
run in any literal format in `src/*.c` is **17** (`%.17g`), against a refusal threshold of 192, and
the widest field width is `%4d`. But the harness enumerates **live specs**, and by construction the
only shapes that can change are the **non-literal** ones, which have no live spec. The harness
structurally cannot see them — and §1 above drove three of them changing a user-visible string,
including an exported SVG attribute becoming `style="font-family:;"`, a shape the harness never
produced. Keep the conclusion, drop "MEASURED, NOT ARGUED" as its warrant.

---

## 6. EVIDENCE CORRECTED — the C89 costing

**What reproduces.**
* `hook_detect_target()` in `scconfig/hooks.c`, the `istrue(get("/local/xschem/debug"))` branch,
  appends `-g -O0 -Wconversion -Wno-sign-conversion` then `require()`s `cc/argstd/Wall`,
  `cc/argstd/std_c89`, `cc/argstd/pedantic`. Read, verbatim.
* **Zero live `snprintf` calls** in `src/*.c src/*.h`. The only textual hit outside the dead arm is
  `src/util.c:643`'s comment.
* **`snprintf` is undeclared under those flags — reproduced at the real insertion point**, not in a
  toy probe: a copy of the actual `src/util.c` with one `snprintf` call added inside `my_snprintf`,
  compiled with the production `-I`s:
  `util_sn.c:767:23: warning: implicit declaration of function 'snprintf'
   [-Wimplicit-function-declaration]`. `xschem.h` sets `_POSIX_C_SOURCE 200112L`; `config.h:51` has
  a bare valueless `#define _XOPEN_SOURCE`; neither reaches glibc's `__USE_ISOC99`/`__USE_UNIX98`
  guard under `__STRICT_ANSI__`.
* `scconfig/src/default/deps_default.c:77-78` registers `libs/snprintf` / `libs/snprintf_safe` and
  `hooks.c` never `require()`s either.

So **reject `snprintf`: correct.** Two corrections to *why*.

**(a) The "killer argument" is unsound as a statement about this tree.** B: *"the bound has to live
in the `#else` arm, and that arm exists BECAUSE the platform has no snprintf. Writing snprintf into
it is self-refuting — on every platform where the guard would matter, the guard would not link."*
`HAS_SNPRINTF` is defined nowhere, so the `#else` arm is **not** the no-snprintf arm; it is **the
only arm, on every platform**, including this glibc and the in-tree MSVC/v143 target, both of which
have a conformant `snprintf`. The self-refutation applies only to a hypothetical correctly-wired
probe answering *no* — and on that platform the `#else` arm needs the arithmetic anyway, which argues
*for* the arithmetic rather than proving `snprintf` incoherent. **Write the `--debug` sentence, not
the killer sentence.**

**(b) "C89 IS A BUILD MODE HERE, NOT A STYLE PREFERENCE" is right about mechanism and overstated as
a commitment.** Compiling **all** of `src/*.c` with exactly the `--debug` flags plus the production
`-I`s (`gcc -fsyntax-only -g -O0 -Wconversion -Wno-sign-conversion -Wall -std=c89 -pedantic`):

```
total diagnostic lines : 218
errors                 : 0
    122 [-Wcomment]
     64 [-Wpedantic]          all 64 in src/move.c: "initializer element is not computable at load time"
     22 [-Wmisleading-indentation]
      3 [-Wparentheses]
      3 [-Wconversion]
      2 [-Wunused-but-set-variable]
      2 [-Wdeclaration-after-statement]
```

The last two are **C99 constructs already in the tree**: `src/actions.c:3100` and
`src/scheduler.c:13387` (at `91bb1bd7`), both *"ISO C90 forbids mixed declarations and code"*.
So `-pedantic` warns, nothing errors, and nobody has ever cleared the mode. The honest sentence is
**"`./configure --debug` asks gcc for C89 and nothing in the tree reads the answer"** — which is
still a sufficient reason not to add `snprintf`, since doing so would turn a warning nobody reads
into a link failure.

---

## 7. EVIDENCE CORRECTED — the call-site counts. Four published figures, none of them right.

The **spec** conclusions reproduce exactly: longest literal conversion spec is **5** characters
(`%.10e`, `%.10g`, `%.15g`, `%.16g`, `%.17g`), 20 distinct literal specs, field-width specs
`%02x` and `%4d` only, and the **5** non-literal sites are exactly `src/svgdraw.c:974`, `:979`,
`:1381`, `:1386` and `src/xinit.c:3522` (my parse's "7" was the two definition headers). B's and A's
reachability census stands.

The **counts** do not. Independently, over `src/*.c`, comment-and-string-stripped:

| figure | source | reproduces? |
|---|---|---|
| "~748 callers" | the issue file | no |
| **729** call expressions | receipt A | no |
| **753** parsed call sites | receipt B | no |
| "the **769** figure the issue quotes" | receipt B | 769 is right for `grep -c` summed, but the issue quotes 748 |
| **752** | this receipt | 771 raw occurrences − 15 in comments − 2 in string literals − 2 definition headers |

And A's *explanation* for its number does not reproduce: *"it includes 24 occurrences inside string
literals (`xinit.c` alone has 17, in the `globals`/paths text)"*. Stripping comments **and** string
literals removes **17** occurrences in total across 13 files, of which only **2** are inside string
literals (`src/util.c:633`, `src/util.c:762`) and **15** are inside comments; **`xinit.c` contributes
exactly 1, and it is in a comment.** Per-file: `actions.c` 2, `util.c` 4, and 1 each in
`callback.c`, `draw.c`, `editprop.c`, `expandlabel.c`, `hilight.c`, `parselabel.c`, `psprint.c`,
`save.c`, `scheduler.c`, `token.c`, `xinit.c`.

Also checked and clean: **zero** `my_snprintf` occurrences inside any `#if 0` region (depth-counted).
And the declarations disagree in three places, as A said: `util.h:39` `size_t/size_t`,
`expandlabel.y:57` `size_t/size_t`, `parselabel.l:48` **`int my_snprintf(char *str, int size, …)`**.

---

## 8. CENSUS HOLE, planted and driven — a `#define` alias with a `#define`d format

Planted in the tree copy (§1a). After planting, a Stage-A-style census — comment-stripped,
paren-balanced, top-level argument split, adjacent-literal concatenation — run over the **planted**
sources reports:

```
literal-format sites: 744  non-literal: 7   (7 = 5 real + the 2 definition headers)
field-width specs the census sees: ['%02x', '%4d']
is %-2000d visible? False
total distinct specs: 20
```

i.e. **identical to the clean tree.** The live 2000-wide site is invisible, and A's sentences *"the
widest field width anywhere is `%4d`"* and *"`%-Nd` with a large N: none"* would both survive it
unchanged. `/usr/bin/grep -c 'my_snprintf(' src/xinit.c` moved 94 → 95 — **only because my own
comment mentions the token**, reproducing the 1606 comment-decoy class by accident.

Built and driven (§1a): original `util.c` → **rc 134** abort; B's patch → **rc 0** plus uninitialised
stack.

**Two more holes, not planted — already in the tree**: `%nd` (§3) and the `L` modifier (§2), neither
in either receipt's shape list. And the **length-modifier census is thin**: A lists `%ld ×2,
%lu ×1, %hu ×1` from literals and I reproduce exactly that, but the *reachable* modifier set is much
larger — driven through `--rcfile` on the verified binary, `%zd` → `cannot find 112`, `%jd` → `56`,
`%td` → `96`, `%hhd` → `64`, all rc 1, all garbage values, none of them in any census.

---

## 9. SURVIVED — re-derived independently, no correction

* **Five return-value consumers, TWO accumulators, only one with the `sz - off` shape.** Reproduced
  by a comment-and-string-stripped statement scan: exactly 5, and no more —
  `my_itoa` (`src/util.c:791`), `dtoa` (`src/util.c:800`), `dtoa_prec` (`src/editprop.c:276`),
  `publish_net_hilight_styles_to_tcl` (`src/hilight.c:596`, `off += my_snprintf(s + off, sz - off,
  …)`), and the `@@pin` expansion in `translate` (`src/token.c:6554`, `result_pos +=
  my_snprintf(result + result_pos, tmp, …)` where `tmp = strlen(str_ptr) + 100`, **not** `sz - off`).
  B's correction to 1606's "three accumulators" is right; do not repeat "three".
* **(B) fires first at `l == 50` and is silent.** Re-driven on the verified binary: a spec of `%` +
  47 dashes + `d` (`l` = 49) → rc 1 `cannot find 24`; 48 dashes (`l` = 50) → rc 1 on HEAD, **refused
  (rc 0) on the patched binary**; and `%-49d` → rc 1, `%-50d` → rc 134. The single
  `l >= sizeof(nfmt)` guard covering both (A) and (B) is right, and B's instruction that the
  `l == 50` row must assert the **output** rather than the exit code is right.
* **Width and precision do not add.** `max(width, 311 + precision)` holds for every double shape I
  drove: `%191.191f` of −DBL_MAX = **502** (bound 511, accepted, fits), `%191.191d` of −1 = **192**,
  `%.190f` = 501, `%.191f` = 502, `%.0f` = 310, `%#.0f` = 311, `%.400g` of 1e308 = 309, `%.500g` of
  the minimum subnormal = 506. A flag pile carries no length. `%*.*f` is refused by the `*`
  sentinel. The 512 threshold behaves exactly as specified: `%.191f` accepted, `%.192f` refused —
  driven on the patched binary.
* **The `p` arm honours width and precision**, so it is covered by the same arithmetic: `%400p` and
  `%.191p` both abort at HEAD; `%.191p` is ~193 bytes, accepted and safe at 512.
* **`'` grouping is not a hole on this machine.** Nothing in `src/*.c` calls `setlocale` (only a
  comment in `node_hash.c` mentions it), so `LC_NUMERIC` stays `"C"`. Measured: `%'.0f` of −DBL_MAX
  is **310** bytes both before *and* after `setlocale(LC_ALL, "")` under `LANG=C.UTF-8`. In a
  grouping locale it would be **419** against a bound of 320, and `%'.180f` **593** against 500 — so
  `'` is a second open-world hole, dormant only by locale, and a second reason to prefer the
  whitelist of §2.
* **"nothing in `xschem_library/` has a `font=` containing a `%`"** — reproduced: zero hits in
  `xschem_library/`, and zero across **every** `.sch`/`.sym` in the repo.
* **B's own disclosure that its figures came from a `sed` extraction and that Stage C should re-drive
  against the real binary.** Correct, and now done: every threshold B reported from the extraction
  matches the built patched binary on every shape I re-drove.
* `%s` given no argument is rc 139 (SIGSEGV), as A reported.

---

## 10. UNMEASURED — claims the driver will write down that nobody has measured

* **The +464-byte frame against recursion depth.** B measured `408 → 872` and did not price it.
  `my_snprintf` is called from the hierarchy walk and from the generated parsers; nobody bounded the
  deepest call chain containing it. **I did not measure it either** — naming it as unpriced, not
  as safe.
* **`-Wdiscarded-qualifiers`.** B: production flags "reproduce only the pre-existing
  `-Wdiscarded-qualifiers` in `my_strndup`". Building the whole patched tree gives **six**:
  `actions.c:557`, `util.c:222`, `save.c:7087`, `token.c:954`, `:955`, `:956`. Consistent with a
  `util.c`-only claim, but the sentence as written reads tree-wide.
* **`MY_SNPRINTF_NSTR = 512` is conceded as a judgement; add its measured consequence.** The
  accepted set now *includes* specs whose output is up to 511 bytes, e.g. `%.191f` of −DBL_MAX = 502
  — and the common non-literal caller's buffer is 80. Every one of those now takes the existing
  overflow path and logs `dbg(1, …)`. Nobody measured how many.
* **No non-fortified build and no Windows build.** Every abort here is `_FORTIFY_SOURCE=3` with
  `__sprintf_chk` / `__strncpy_chk`. Inherited limitation, repeated rather than quietly dropped.
* **Whether the `L` garbage can ever be a large finite.** 7 environments × 3 doors × 2 binaries all
  read NaN. Not proved impossible — proved layout-dependent (`nan` → `-nan` under B's patch).
* **No T1 run**; the repo tree was not modified, so the gate is still Stage D's.
