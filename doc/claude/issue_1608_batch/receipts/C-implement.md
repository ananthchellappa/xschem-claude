# Receipt C — `impl`: the thirteen adjudications, landed and fenced

**Stage C of the 1608 batch.** Tree at `91bb1bd7`, nine `src/` files changed, `make -C src` run
before every figure below and after every restore (`cp`, **never** `cp -a`). Scratch namespaced
under `<scratchpad>/stageC_1608/` per the brief's collision note; no sibling crew's file was
touched. **Nothing committed** — the git identity, the commit message and the T1 gate are the
driver's.

**Result: `tests/headless/test_snprintf_fmt_1608.tcl`, 28 rows, `ALL PASS (28 checks)` on all
three arms, and every one of the 28 reddened under a sabotage I drove.**

⚠ **Three things in this receipt contradict the brief, and one of them is a suite defect I
shipped and then found with a sabotage.** They are §7. Read them.

---

## 0. Headline

* **J1 is done and the four doors are shut.** `font=%-2000d`, `font=%nd`, `--rcfile '%s'` and
  `--rcfile '%-2000d'` all went from **rc 134 / rc 139** to **rc 0 / rc 1 with the value reported
  verbatim**. The SVG side takes the `"%s"` **and nothing else** — `ps_font_token` would be a
  pixel regression here, argued in §1.
* **The formatter's four mechanisms are guarded by one gate with three separately-removable
  guards**, with J3's reordering built in from the start. Driven directly against the tree's own
  `src/util.c`: the silent `l == 50` one-past store, the `%n` abort, the `%.0Lf` NaN, the four
  garbage size modifiers, the `%*d` garbage width, `%'.0f`'s abort, the `%-2000d` abort, the
  `(D)` canary clobber on all four arms **and at `size == 0`** — every one of them was measured
  on the pre-1608 file and every one is gone.
* **`%.6f` of ±`DBL_MAX` now formats (317 characters) instead of aborting.** That is the one
  live literal caller the call-site fix does not help, and it is why J2 ships.
* **J11's premise is refuted**: `parselabel.l`'s "conflicting prototype" is inside a block
  comment and has never compiled. §7.1.
* **J8's flag needed widening beyond what J8 said**, and the narrow version shipped green with a
  real call site reverted. §7.2.
* **One row I wrote was vacuous and a sabotage caught it.** §7.3.

---

## 1. J1 — the five call sites, and the `ps_font_token` judgement

### The five edits, verbatim before and after

`src/svgdraw.c`, four sites (`svg_draw_symbol` ×2 at the top of the pair, `svg_draw` ×2):

```
-        my_snprintf(svg_font_family, S(svg_font_family), tclgetvar("svg_font_name"));
+        /* 1608: "%s" -- see the comment at svg_font_family's declaration */
+        my_snprintf(svg_font_family, S(svg_font_family), "%s", tclgetvar("svg_font_name"));
-          my_snprintf(svg_font_family, S(svg_font_family), textfont);
+          /* 1608: "%s" -- see the comment at svg_font_family's declaration */
+          my_snprintf(svg_font_family, S(svg_font_family), "%s", textfont);
-    my_snprintf(svg_font_family, S(svg_font_family), tclgetvar("svg_font_name"));
+    /* 1608: "%s" -- see the comment at svg_font_family's declaration */
+    my_snprintf(svg_font_family, S(svg_font_family), "%s", tclgetvar("svg_font_name"));
-      my_snprintf(svg_font_family, S(svg_font_family), textfont);
+      /* 1608: "%s" -- see the comment at svg_font_family's declaration */
+      my_snprintf(svg_font_family, S(svg_font_family), "%s", textfont);
```

`src/xinit.c`, `Tcl_AppInit` (the eight-line comment above it is elided here; it is in the file):

```
-     my_snprintf(name, S(name), cli_opt_rcfile);
+     my_snprintf(name, S(name), "%s", cli_opt_rcfile);
```

A **sixth**, not in J1 and found by the compiler once the attribute went on: `xinit.c`'s
`my_snprintf(old_win_path, S(old_win_path), "")` became `old_win_path[0] = '\0';`. With the
format attribute present, that zero-length format is a `-Wformat-zero-length` warning **in the
DEFAULT build**, which this tree has none of. Byte-identical behaviour.

The 30-line account of the defect, the `%n` mechanism and the 1351 relationship sits above
`svg_font_family`'s declaration in `svgdraw.c`, which is where a reader of the variable lands.

### The four doors, VERBATIM before and after

`fixture: T {HELLO} 20 -30 0 0 0.4 0.4 {layer=4 font=<spec>}`, driven as
`env -u DISPLAY HOME=<throwaway> timeout 60 ./src/xschem --nogui --pipe -q <sch> --script <xschem
zoom_full; xschem print svg <out>; puts SVGDONE>`.

**BEFORE, at `91bb1bd7` (binary `e13fb8b7197943faa910e2b3e10932e7`):**

```
### font=%-2000d
Created /tmp/xschem-test-home.2417256.KJzyPf/.xschem dir with template xschemrc
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
*** buffer overflow detected ***: terminated
/bin/bash: line 4: 2417260 Aborted                    env -u DISPLAY HOME="$H" timeout 60 ./src/xschem --nogui --pipe -q "$@" 2>&1
rc=134

### font=%nd
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
*** %n in writable segments detected ***
/bin/bash: line 4: 2417264 Aborted                    ...
rc=134

### --rcfile %s
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
/bin/bash: line 4: 2417268 Segmentation fault         ...
rc=139

### --rcfile %-2000d
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
*** buffer overflow detected ***: terminated
/bin/bash: line 4: 2417271 Aborted                    ...
rc=134
```

**AFTER J1 (binary `f690e40abd0e1dec2c9c3685467aca58`, J1 alone, no `util.c` change yet):**

```
### font=%-2000d
Created /tmp/xschem-test-home.2417667.eRNDBZ/.xschem dir with template xschemrc
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
SVGDONE
rc=0
--- emitted font-family: ---
font-family: Sans-Serif;
font-family:%-2000d;

### font=%nd
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
SVGDONE
rc=0
--- emitted font-family: ---
font-family: Sans-Serif;
font-family:%nd;

### --rcfile %s
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
Tcl_AppInit() err 2: cannot find %s
rc=1

### --rcfile %-2000d
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
Tcl_AppInit() err 2: cannot find %-2000d
rc=1
```

The value is **preserved verbatim** in both directions: the SVG carries `font-family:%-2000d;`
and `font-family:%nd;`, and the command line reports the name it could not find. That matters
for the rows — see §7.3.

### ⚠ THE SVG SIDE NEEDS THE `"%s"` AND NOT `ps_font_token()`. Stated, with the reason.

I read `ps_font_token` in `src/psprint.c` and its 1351 comment. It does **two** PostScript-specific
jobs and neither transfers:

1. **It maps the generic CSS/Cairo families onto the base-14 PostScript names** —
   `monospace`/`mono`/`couriernew`/`courier` → `Courier`, `serif`/`timesnewroman`/`times` →
   `Times`, `sansserif`/`sans`/`helvetica` → `Helvetica`, `symbol` → `Symbol` — *"precisely
   because PostScript has never heard of them"*, in its own words. **SVG's `font-family` IS that
   namespace.** Mapping `serif` to `Times` in an SVG export would replace a generic family the
   renderer resolves correctly with one specific face, discarding the user's stated intent. 1351's
   own comment calls its mapping *"a typeface change"* and files a `rule` debt for it; doing the
   same thing in SVG would be the change **without** the justification, because SVG loses nothing
   by keeping the generic name.
2. **It replaces the characters that end a PostScript name token** (`( ) < > [ ] { } / %`,
   whitespace, control bytes), because `/courier new-Bold FF` makes gs execute `new-Bold`. **SVG
   has no name token.** A space inside `font-family` is legal and meaningful (`font-family:courier
   new`), so the same substitution would corrupt every two-word face name that works today.

So `ps_font_token` in SVG would be a **pixel regression on schematics that already render
correctly**, which is the opposite of what 1351 bought. The `"%s"` closes the whole of 1608's
class at these sites — it is what removes the format string, and `%n` with it.

**Carried forward, named not fixed:** the value still lands **unescaped** inside a double-quoted
XML attribute (`style="font-family:%s;"` in `svg_draw_string`), so a `"` in a `font=` name can
still break the attribute. That is an **output-escaping** defect, not a memory write, it is not
this issue's class, and it needs its own issue. Rows F1–F5 assert the format-string door is shut,
not that the SVG is well-formed for every input, and the suite says so in named limit L5.

---

## 2. J2 / J4 / J5 / J6 / J3 — one gate, three guards, and the ordering built in

**The gate, verbatim** (`src/util.c`, immediately above `my_snprintf`, inside what used to be the
`#else` arm so a hypothetical `HAS_SNPRINTF` build would not get an unused static — except that
arm is gone, see §4):

```c
#define MY_SNPRINTF_NSTR 512

static int my_snprintf_spec_ok(const char *spec, size_t len, size_t nfmtsize, size_t nstrsize)
{
  size_t i, run, max = 0;

  if(len >= nfmtsize) return 0;                        /* GUARD 1: (A) and (B) together */
  /* spec[0] is '%' and spec[len-1] is the conversion letter; scan what lies between */
  for(i = 1; i + 1 < len; i++) {
    char c = spec[i];
    if(c >= '0' && c <= '9') {
      run = 0;
      while(i + 1 < len && spec[i] >= '0' && spec[i] <= '9') {
        if(run < 1000000) run = run * 10 + (size_t)(spec[i] - '0');
        i++;
      }
      if(run > max) max = run;
      i--;
    }
    else if(c == '-' || c == '+' || c == ' ' || c == '#' || c == '.') continue;
    else if(c == 'l' || c == 'h') continue;            /* GUARD 2: the only two permitted */
    else return 0;                                     /* GUARD 2: whitelist, not blacklist */
  }
  return max + 320 < nstrsize;                         /* GUARD 3: (C) */
}
```

**One arm, verbatim, with J3's ordering and J6's `>=`** (the other two are identical bar the
`va_arg` type and the declaration):

```c
    else if(format_spec && (*f == 'd' || *f == 'x' || *f == 'c' || *f == 'u') ) {
      char nfmt[50], nstr[MY_SNPRINTF_NSTR];
      int i, nlen, refuse;
      i = va_arg(args, int);
      l = f - fmt+1;
      refuse = !my_snprintf_spec_ok(fmt, l, sizeof(nfmt), sizeof(nstr));   /* 1608 */
      if(!refuse) {
        strncpy(nfmt, fmt, l);
        nfmt[l] = '\0';
      }
      l = fmt - prev;
      if(n+l >= size) {                 /* 1608 (D): see MY_SNPRINTF_PREFIX_GUARD below */
        overflow = 1;
        if(n < size) string[n] = '\0';
        break;
      }
      memcpy(string + n, prev, l);
      string[n+l] = '\0';
      n += l;
      if(refuse) { overflow = 1; break; }    /* 1608: AFTER the prefix write, never before */
      nlen = sprintf(nstr, nfmt, i);
      if(n + nlen + 1 > size) { overflow = 1; break; }
      memcpy(string +n, nstr, nlen+1);
      n += nlen;
      format_spec = 0;
      prev = f + 1;
    }
```

The `%s` arm gets the `>=` and the `if(n < size) string[n] = '\0';` and nothing else — it has no
`nfmt`/`nstr`, so the gate does not apply to it.

### The `L`/length-modifier decision (J4), and it is a WHITELIST

**Decision: refuse everything the function does not implement, EXCEPT `l` and `h`, and do it as a
closed whitelist rather than as a blacklist or a wider digit scan.** What that excludes: `n`,
`L`, `q`, `z`, `j`, `t`, `*`, `'`, `$`, and any character nobody has thought of.

Reasons, in order:

* **A digit scan is an open-world assumption.** It silently trusts every character it does not
  recognise, which is exactly how `L` and `'` got past Stage B's `spec_maxout`. A whitelist
  cannot have that failure mode; a new libc extension arrives as a refusal, not as a write.
* **`L` is the one that breaks GUARD 3's arithmetic**, as Bv measured: `%.0Lf` of `LDBL_MAX` is
  4933 characters against an estimate of 320. It also mis-fetches.
* **`'` closes in the same line.** Bv measured `%'.0f` of `-DBL_MAX` at 419 characters in a
  grouping locale against a bound of 320, and `%'.180f` at 593 against 500. Dormant here only
  because nothing in `src/` calls `setlocale`. **And it is not only a bound hole: driven on the
  pre-1608 file, `%'.0f` already ABORTED in the `"C"` locale** (310 characters into `nstr[50]`) —
  see the driver table in §3, case `B4`.
* **`l` and `h` are PERMITTED, and refusing them would have been a live regression.** Three
  literal callers use them (`scheduler.c`'s `%ld` ×2, `%lu`, `%hu`), and refusing them would
  change what `xschem globals` prints — `XMaxRequestSize=` with no number. Their widest output is
  20 characters, far inside GUARD 3. **They still mis-fetch** (the arm does `va_arg(args, int)`
  and `sprintf` then reads 8 bytes, correct only by x86-64 zero-extension). That is a separate
  defect, named and carried forward, **preserved on purpose**, and row `G5` exists so that nobody
  tightens the whitelist onto it without a red row.

So J4's two options are both taken in part: the bound is not taught about `long double`, and the
modifiers it cannot implement are refused — bar the two that are live and harmless to the bound.

### `(D)` `>=` in all four arms, and what a refusal now writes

`>` → `>=` in the `d/x/c/u`, `p`, `g/e/f` and `%s` arms. Two additional decisions, both stated
because neither is in J6:

* **A refusal NUL-terminates at `string[n]` when `n < size`.** Without it, J6 converts a (D)
  one-past write into an (E) **unwritten buffer** — the caller reading uninitialised memory,
  which is the defect J3 is about. `string[n]` is `'\0'` on every other path in this function
  (the prefix write leaves it so), so this restores the invariant on the one path that broke it.
  It does not change `n`, so no return value moves. It also makes `size == 0` safe: the old `>`
  test wrote `string[0]` for a format beginning with `%`.
* **All four arms now set `overflow = 1` on that guard.** Two used to `break` bare. Both receipt
  A §4 and receipt B §7.5 proved that provably inconsequential — at break time
  `n + (fmt-prev) >= size` while the tail test uses `l = f-prev >= fmt-prev` with the same `n`,
  so `n+l+1 <= size` is false on every such path — but it was listed as *carried forward, not
  fixed* on the assumption those lines would not be touched, and they are the lines that just
  moved. Making them uniform is zero-risk and removes the trap. **This is a deliberate departure
  from STAGE_C's carried-forward list; §7.4.**

### `MY_SNPRINTF_NSTR = 512` is a judgement, and it is stated as one

338 is the measured floor (the widest live spec, `%.17g`, needs 337). 512 accepts every live spec
and every precision up to 191. 1024 would buy ≤ 703 for another 512 bytes of stack. Nothing
measured says which a future caller wants, and the comment says so rather than implying a
derivation.

---

## 3. The behavioural backbone — `my_snprintf` driven DIRECTLY, and the before/after table

⚠ **J1 removed the last live door into the formatter's spec scanner.** That is the point of J1 and
it is also a measurement problem: after the fix, every format in the tree is a short literal (row
`P2` measures the longest at **5** characters), so **no input any test can write makes a shipped
caller hand `my_snprintf` a 50-character spec**. `--rcfile` is now a pass-through — re-driven
after J1, all of `%-2000d`, `%nd`, `%.0Lf`, `%*d`, `%'.0f`, `%.192f`, `%zd`, `%jd`, `%hhd` return
`rc=1  cannot find <spec>` verbatim.

So section G of the suite **compiles the tree's own `src/util.c`** — the real file, at the build's
own CFLAGS out of `Makefile.conf`, not a `sed` extraction (the instrument the 1606 batch's
post-mortem names as having produced a non-fact, and which Stage B disclosed using) — links it
against 22 link stubs and a driver, and calls `my_snprintf` directly, **one `fork` per case** so a
fortify abort is a recorded outcome. `printf` line format: `id|rc|sig|ret|canary|len|out`, the
canary being the byte **at index `size`**, i.e. exactly where (D) wrote.

**The same driver, the same flags, against the ORIGINAL `src/util.c` and the patched one:**

| case | spec / shape | size | ORIGINAL (pre-1608) | PATCHED | row |
|---|---|---|---|---|---|
| A1 | `%`+47 dashes+`d`, l=49 | 80 | `ret=2 out=47` | `ret=2 out=47` | G1 |
| A2 | `%`+48 dashes+`d`, **l=50** | 80 | **`ret=2 out=48`** — the SILENT one-past store | `ret=0 out=""` refused | G1 |
| A3 | `%`+49 dashes+`d`, l=51 | 80 | **`*** buffer overflow detected ***` SIGABRT 6** | refused | G1 |
| A4 | `%`+200 dashes+`d` | 80 | **SIGABRT 6** | refused | G1 |
| B1 | `%nd` | 80 | **`*** %n in writable segments detected ***` SIGABRT 6** | refused | G2 |
| B2 | `%.0Lf` of −DBL_MAX | 80 | `ret=3 out=nan` (10 uninitialised stack bytes) | refused | G3 |
| B3 | `%*d` | 80 | `ret=9 out=862466144` (garbage width) | refused | G4 |
| B4 | `%'.0f` of −DBL_MAX | 80 | **SIGABRT 6**, in the `"C"` locale | refused | G4 |
| B5–B8 | `%zd` `%jd` `%td` `%qd` | 80 | `ret=1 out=7` each — garbage | refused | G4 |
| B9 | `%ld` of 65535 | 80 | `ret=5 out=65535` | **identical** | G5 |
| BA | `%hu` of 513 | 80 | `ret=3 out=513` | **identical** | G5 |
| C1 | `%-2000d` | 80 | **SIGABRT 6** | refused | G6 |
| C2 | `%.192f` of −DBL_MAX | 900 | **SIGABRT 6** | refused | G6 |
| C3 | `%.191f` of −DBL_MAX | 900 | **SIGABRT 6** | **`len=502`, formats** | G7 |
| C4 | `%.60g` of −DBL_MAX | 900 | **SIGABRT 6** | **`len=67`, formats** | G7 |
| C5 | **`%.6f` of −DBL_MAX** | 900 | **SIGABRT 6** — the LIVE literal caller | **`len=317`, formats** | G7 |
| D1 | `abcd%d`, n+l == size | 4 | `ret=4 out=abcd` **CLOBBERED** | `intact`, refused | G8 |
| D2 | `abc%d` (fits) | 4 | `ret=3 out=abc intact` | **identical** | G8 |
| D3 | `abcd%s` | 4 | **CLOBBERED** | `intact` | G8 |
| D4 | `abcd%g` | 4 | **CLOBBERED** | `intact` | G8 |
| D5 | `abcd%p` | 4 | **CLOBBERED** | `intact` | G8 |
| D6 | `%d`, **size 0** | 0 | **CLOBBERED** (wrote `string[0]`) | `intact` | G8 |
| E1 | `zz%.192f` | 80 | **SIGABRT 6** | `ret=2 out=zz` — prefix kept | G9 |
| E2 | `zz%-2000d` | 80 | **SIGABRT 6** | `ret=2 out=zz` | G9 |
| E3 | `zz%nd` | 80 | **SIGABRT 6** | `ret=2 out=zz` | G9 |
| I1–IA | `%d` of INT_MIN, `%02x`, `%.16g`, `%g`, `%c`, `%u` of UINT_MAX, `%p`, `%s`, `%.17g`, and `a%db%gc` | 80 | `x=-2147483648` `x=ff` `x=0.3333333333333333` `x=0.333333` `x=A` `x=4294967295` `x=0x58` `x=xy` `x=0.33333333333333331` `a5b2.5c` | **byte-identical** | G10 |

**Zero output changes on any live conversion. Sixteen aborts and six silent clobbers removed.**

Named limit of this instrument, stated in the suite: it measures the **source**, so it is
independent of whether anyone ran `make`. Section F covers the shipped binary.

---

## 4. J10 — the dead arm deleted, with a comment where it was

Deleted: `src/util.c`'s whole `#ifdef HAS_SNPRINTF` arm plus its `#else`/`#endif`, and
`src/scheduler.c`'s `#ifdef HAS_SNPRINTF` / `my_snprintf(res, S(res), "HAS_SNPRINTF=%s\n",
HAS_SNPRINTF);` / `#endif`.

**The comment left in its place is 37 lines and is quoted here in full**, because STAGE_C asks for
its exact text:

```
/* ISSUE 1608 -- THERE WAS AN `#ifdef HAS_SNPRINTF` ARM HERE. IT IS GONE, AND THIS
 * COMMENT IS WHAT IT LEFT BEHIND.
 *
 * WHAT IT WAS: a second definition of my_snprintf() that called vsnprintf() and popped a
 * modal Tcl alert on truncation. `#else` selected the hand-rolled formatter below.
 *
 * IT HAS NEVER COMPILED ON ANY PLATFORM. `HAS_SNPRINTF` is defined nowhere in this tree
 * -- not in config.h, not in config.h.in, not in XSchemWin/config.h, not in scconfig (which
 * registers a libs/snprintf probe that hooks.c never require()s), not on any command line.
 * Five independent proofs, four inherited from issue 1606 and the fifth behavioural: the
 * macro is absent from every config; `nm -S src/util.o` shows one my_snprintf; `nm -u
 * src/util.o` lists no vsnprintf; scheduler.c's own `"HAS_SNPRINTF=%s"` line handed `%s`
 * whatever integer the macro would be; and `xschem globals` prints `HAS_DUP2=1`,
 * `HAS_POPEN=1`, `HAS_CAIRO=1` and NO `HAS_SNPRINTF=` line at all. That scheduler.c line
 * was deleted with this arm. Deleting changed not one compiled byte.
 *
 * WHY ENABLING IT WAS NEVER SAFE, which is the part worth keeping. THE TWO ARMS' RETURN
 * VALUES MEAN DIFFERENT THINGS: the arm below returns bytes WRITTEN, vsnprintf() returns
 * bytes that WOULD HAVE BEEN written. Five live sites consume that return as a length --
 * my_itoa() and dtoa() here, dtoa_prec() in editprop.c (all three assign it to
 * xctx->tok_size, which ~20 sites in actions.c read as a length), plus two accumulators:
 * publish_net_hilight_styles_to_tcl() in hilight.c does `off += my_snprintf(s + off, sz -
 * off, ...)`, so under vsnprintf semantics `off` passes `sz`, `sz - off` is a size_t and
 * wraps to ~2^64, and the "safe" arm then writes unbounded; and the @@pin expansion in
 * translate() (token.c) advances result_pos past the data so the next STR_ALLOC sizes from
 * a wrong offset. Two further defects sit INSIDE the arm and are themselves evidence
 * nobody ever built it: `size_of_print >= size` compared an int against a size_t, so a
 * vsnprintf error return of -1 promoted to a huge size_t and fired the alert; and the
 * alert's `%d` was handed a size_t.
 *
 * AND THE `#ifdef` WAS ITSELF THE HAZARD. See log_action() above in this file: the same
 * `#ifdef HAS_SNPRINTF` / vsnprintf-versus-vsprintf pair, the unbounded arm the only one
 * ever compiled, and a 4971-byte Tk menu `-command` script that aborted the editor on a
 * click with an unsaved schematic in it. "The `#ifdef` read as protection and was
 * decoration." Measured at 91bb1bd7: `-DHAS_SNPRINTF=` (the natural spelling for an
 * scconfig feature flag) was a COMPILE ERROR at scheduler.c's line, while
 * `-DHAS_SNPRINTF=1` COMPILED CLEAN under -Wall and would have crashed at runtime. So the
 * arm was not a dormant portability seam; it was a switch nobody could safely throw, and
 * leaving it in place preserved the trap rather than the information. This comment
 * preserves the information.
 *
 * If a platform ever genuinely needs vsnprintf(), the work is the five return-value
 * consumers above, not a #ifdef.
 * See doc/claude/issues/1608-my-snprintf-writes-into-two-fixed-50-byte-buffers-and-checks-the-bound-afterwards.md */
```

`scheduler.c` keeps a six-line pointer at the site of the deleted `globals` line. **And three
comments in three other files said "without HAS_SNPRINTF" / "the no-HAS_SNPRINTF arm"** and would
have sent the next reader hunting a `#ifdef` that no longer exists — `graph_marker_fmt`
(`draw.c`), the cursor-value publisher (`save.c`) and the `@@pin` advice text (`token.c`). All
three re-spelled to say there is only one arm and that 1608 deleted the other. Not in J10;
reported here.

Fenced by rows `S1` and `S2`, which are static **because there is nothing else to be**: the arm
never compiled, so `gcc -E` output, the linked binary and `xschem globals` are byte-identical with
it present or absent. Both rows read comment-stripped, `#if 0`-stripped text, and **both also
assert that the RAW text still contains `HAS_SNPRINTF`** — the replacement comment — so the row
cannot pass by reading an empty string, and a raw grep (which would be RED on the correct tree,
9 hits in `util.c`) cannot be substituted for it.

---

## 5. The suite — 28 rows, and how each was reddened

`tests/headless/test_snprintf_fmt_1608.tcl`, registered in `tests/run_regression.tcl`'s
**`hcases` only**. Nothing in it needs a display, so it reports **no `skip:` line on either arm**;
registering it in `dcases` as well would have cost a second case and one self-skip for no rows.

| row | asserts | kind | arm |
|---|---|---|---|
| F1 | a `.sch` `font=%-2000d` survives `print svg` and reaches the exported `font-family` verbatim (`svg_draw`'s `textfont` site) | behavioural, real binary | both |
| F2 | the same door with `font=%nd` — the shape every arithmetic bound misses | behavioural, real binary | both |
| F3 | a `.sym` text's `font=` through an instance (`svg_draw_symbol`'s `textfont` site) | behavioural, real binary | both |
| F4 | `svg_font_name` set to a spec round-trips, so ZERO per-text `style="font-family:"` attributes appear (see §7.3) | behavioural, real binary | both |
| F5 | control — an ordinary `font=Monospace` reaches the output by the same path | behavioural, real binary | both |
| F6 | `--rcfile '%-2000d'` → rc 1 reporting the name verbatim | behavioural, real binary | both |
| F7 | `--rcfile '%nd'` → rc 1 verbatim | behavioural, real binary | both |
| F8 | `--rcfile '%s'` → rc 1 verbatim (was SIGSEGV) | behavioural, real binary | both |
| F9 | control — a `--rcfile` naming a file that exists is still sourced | behavioural, real binary | both |
| W1 | every `src/*.c` compiled with the build's CFLAGS + `-Wformat -Wformat-nonliteral`: no `-Wformat`-family diagnostic on a line spelling `my_snprintf(`, and none anywhere except two named deliberate shapes | compiler diagnostic | both |
| W2 | anti-vacuity for W1 — a synthetic file including the real `xschem.h` DOES get the diagnostic | compiler diagnostic | both |
| P1 | `gcc -E` census: zero `my_snprintf` calls with a non-literal format | behavioural over compiled text | both |
| P2 | no live literal spec is refused by any of the three guards (none ≥ 50 chars, none outside the whitelist, no digit run within 320 of `nstr`, no `*`) | behavioural over compiled text | both |
| P3 | anti-vacuity for P1/P2 — a FLOOR of > 600 calls over > 30 units, never a count | behavioural over compiled text | both |
| G1 | GUARD 1: l=49 formats, l=50 and l≥51 refused (A and B, one guard) | behavioural, tree's own `util.c` | both |
| G2 | GUARD 2: `%nd` refused, no signal | behavioural, tree's own `util.c` | both |
| G3 | GUARD 2: `%.0Lf` refused | behavioural, tree's own `util.c` | both |
| G4 | GUARD 2: `%*d` `%'.0f` `%zd` `%jd` `%td` `%qd` refused | behavioural, tree's own `util.c` | both |
| G5 | GUARD 2's permitted set: `%ld` and `%hu` still format | behavioural, tree's own `util.c` | both |
| G6 | GUARD 3: `%-2000d` and `%.192f` refused | behavioural, tree's own `util.c` | both |
| G7 | the enlarged scratch: `%.191f`, `%.60g`, `%.6f` of −DBL_MAX format at 502/67/317 | behavioural, tree's own `util.c` | both |
| G8 | (D): the canary at index `size` survives on all four arms and at `size == 0` | behavioural, tree's own `util.c` | both |
| G9 | J3's ordering: a refusal keeps the `zz` prefix on all three refusal classes | behavioural, tree's own `util.c` | both |
| G10 | identity: every live conversion prints byte-for-byte what it printed | behavioural, tree's own `util.c` | both |
| G11 | anti-vacuity for G1–G10 — the driver built from the tree's `util.c` and ran | behavioural, tree's own `util.c` | both |
| S1 | comment- and `#if 0`-stripped `src/util.c` has zero `HAS_SNPRINTF` and zero `vsnprintf`, while the raw text still has `HAS_SNPRINTF` | static | both |
| S2 | the same stripped read of `src/scheduler.c` has zero `HAS_SNPRINTF` | static | both |
| S3 | `gcc -E` of `src/parselabel.c` has zero `my_snprintf` declarations taking an `int size` | behavioural over compiled text | both |

### Sabotage — every row, and the verbatim failing line

Two rounds, 28 sabotages driven; each one: edit → `make -C src` → run the suite → record → restore
with `cp` → `make -C src` → confirm `ALL PASS (28 checks)`. Round 1 is
`<scratchpad>/stageC_1608/sab.py`, round 2 `sab2.py`; their full transcripts are
`sab2.out` and the round-1 task output.

| sabotage | rows it reddened |
|---|---|
| revert `svg_draw`'s `textfont` to the non-literal form | **F1, F2**, W1, P1 |
| revert `svg_draw_symbol`'s `textfont` | **F3**, W1, P1 |
| revert `svg_draw`'s `svg_font_name` | **F4**, W1, P1 |
| revert `svg_draw_symbol`'s `svg_font_name` | **W1, P1** |
| revert `xinit.c`'s `--rcfile` | **F6, F7, F8**, W1, P1 |
| both `textfont` sites write the constant `"ZZ"` | **F5**, F1, F2, F3 |
| delete `source_tcl_file(name)` from the `--rcfile` arm | **F9** |
| remove the format attribute from `util.h` | **W2** |
| plant a literal `"%.400f"` in a real `my_snprintf` call | **P2** |
| plant a literal `"%*d"` in a real `my_snprintf` call | **P2** |
| blind the census parser (return no calls) | **P3** — and P1/P2 stayed green, which is why P3 exists |
| break the driver's link to `my_snprintf` | **G11** and G1–G10 |
| remove GUARD 1 (`len >= nfmtsize`) | **G1** |
| remove GUARD 2's `else return 0` | **G2, G3, G4** (and G9) |
| remove GUARD 2's `l`/`h` permission | **G5** |
| remove GUARD 3 (`return max + 320 < nstrsize` → `return 1`) | **G6** (and G9) |
| `MY_SNPRINTF_NSTR` back to 50 | **G7** (and F3, G1, G5, G10, G11) |
| `>=` → `>` in the `d/x/c/u` arm | **G8** |
| `>=` → `>` in the `p` arm | **G8** |
| `>=` → `>` in the `g/e/f` arm | **G8** |
| `>=` → `>` in the `%s` arm | **G8** |
| break before the prefix write (Stage B's ordering) | **G9** (and G1, G2, G3, G4, G6) |
| restore `#ifdef HAS_SNPRINTF` at a code position in `util.c` | **S1** |
| restore `HAS_SNPRINTF` at a code position in `scheduler.c` | **S2** |
| un-comment `parselabel.l`'s `int size` declaration | **S3** (and P1) |

**Every one of the 28 rows appears in that table. No row is unfenced.** Four verbatim failing
lines, as samples (the full set is in the transcripts):

```
FAIL: G1 (1608 GUARD 1, mechanisms A and B together) a spec of `%` + N dashes + `d` -- whose OUTPUT stays two characters, so only the nfmt[50] bound is in play -- formats at length 49 and is refused at 50 and above. ... (l49={0 0 2 intact 2 47} l50={0 0 2 intact 2 48} l51={-1 6 - - - DIED} l202={-1 6 - - - DIED})
FAIL: F2 (1608) the SAME door with `font=%nd`, which is the shape every arithmetic bound misses -- three characters producing no output. ... (rc=134 death=0 fams={})
FAIL: G8 (1608 mechanism D -- one byte past THE CALLER'S buffer, on all four arms) a canary byte planted at index `size` survives. ... (d={0 0 4 CLOBBERED 4 abcd} ...)
FAIL: W1 (1608) compiling every src/*.c ... puts NO diagnostic on a line spelling `my_snprintf(` ...
```

And after every restore: `RESULT: ALL PASS (28 checks)`.

---

## 6. The three arms, VERBATIM

```
################ ARM 1 — nogui ################
test home: throwaway /tmp/xschem-test-home.2444966.Vk726f (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (28 checks)
RESULT: 1/1 runs passed

################ ARM 2 — display (dev display :99) ################
test home: throwaway /tmp/xschem-test-home.2445410.UQjCAD (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (28 checks)
RESULT: 1/1 runs passed

################ ARM 3 — no dev display (XSCHEM_DEVDISPLAY_DIR=<empty scratch dir>) ################
test home: throwaway /tmp/xschem-test-home.2445854.uXWzhD (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: private Xvfb from :200 up, screen 1920x1080x24, wm openbox, GUI_GATE=0
             (AUDIT_DISPLAY=:0 to use the real screen, =none to skip GUI legs)
PASS     | test_snprintf_fmt_1608       run 1/1  RESULT: ALL PASS (28 checks)
RESULT: 1/1 runs passed
```

Commands: `tests/headless/run_suites.sh --nogui test_snprintf_fmt_1608`;
`tests/headless/run_suites.sh test_snprintf_fmt_1608`;
`XSCHEM_DEVDISPLAY_DIR=<empty dir> tests/headless/run_suites.sh test_snprintf_fmt_1608`.

**Arm 3 was read-only as required.** `devdisplay.sh stop` was never run; `devdisplay.sh status`
before and after both report `display: :99 / state: alive / xvfb: 3979908` — the same pid — and
the empty directory was still empty (0 entries) afterwards, so `run_suites.sh` created a private
Xvfb from `:200` and left `~/.claude/xschem_dev_display` untouched. Arm 1 still prints the
`ATTACHED` banner because that is `run_suites.sh`'s display-arm *setup* line; the suite itself runs
`--nogui`, and all three arms report the same 28 rows because no row needs a display.

---

## 7. ⚠ DEVIATIONS AND CORRECTIONS — including one suite defect I shipped and then found

### 7.1 J11's PREMISE IS REFUTED. There was never a conflicting prototype.

J11: *"Fix `src/parselabel.l`'s declaration. It declares `extern int my_snprintf(char *str, int
size, const char *fmt, ...)` against `util.h`'s `size_t`/`size_t` — **two incompatible
declarations of one function in one program**, which is undefined behaviour."* Receipt A §5.2 and
receipt Bv §7 both state it as live.

**It is inside a `/* … */` block comment.** `parselabel.l` lines 38–49 open `/*` and close `*/`
around a dead list of nine declarations that `xschem.h` (included five lines above) now provides.
Measured:

```
$ /usr/bin/grep -n -B3 -A3 'my_snprintf(char \*str, int size' src/parselabel.c
1793-extern char bus_char[];
1794-extern const char *tcleval(const char str[]);
1795-extern void *my_malloc(int id, size_t size);
1796:extern int  my_snprintf(char *str, int size, const char *fmt, ...);
1797-*/
$ gcc -E <CFLAGS> src/parselabel.c | /usr/bin/grep -c 'my_snprintf(char \*str, int size'
0
```

`expandlabel.y` carries the same dead block. So `util.h` holds the program's **only** live
declaration and there was no UB to fix. **Both crews greped the text without depth-counting
comments** — the exact decoy class `CREW_BRIEF.md` names from the 1603 batch's rows `S1`–`S4`.

**What I did instead:** re-spelled the dead copy to match `util.h` (`size_t`/`size_t`) and headed
the block with a note saying it is dead, why, that `gcc -E` contains it zero times, and that it
must not be un-commented now that `util.h`'s declaration carries the format attribute. Row `S3`
asks the question of **preprocessed output** rather than of source text, so the same false finding
cannot be filed a third time.

### 7.2 ⚠ J8's FLAG IS NECESSARY BUT NOT SUFFICIENT, AND THE NARROW VERSION SHIPPED GREEN WITH A DOOR REOPENED

J8: *"THE COMPILER FENCE IS `-Wformat-nonliteral`, NOT `-Wformat-security`."* Correct as far as it
goes, and I built row `W1` on it — collecting only diagnostics whose text contains
`-Wformat-nonliteral`. **Then the sabotage round reverted one real call site and W1 stayed
GREEN.**

The reason is J8's own finding turned around: `-Wformat-security` warns only for a non-literal
format with **no arguments**, and **all five real sites are zero-argument calls**. So for exactly
the shape this issue is about, gcc says `-Wformat-security` and *not* `-Wformat-nonliteral` —
a `-Wformat-nonliteral`-only filter is blind to the five sites it exists to fence.

**Fixed:** `W1` now collects any diagnostic containing `[-Wformat`, i.e. the whole family, and
that is written up in the row's own comment as a measured requirement. Measured on the clean tree,
exactly five diagnostics of the whole family, all at the two deliberate shapes:

```
draw.c:5309:7 / 5310:7 : format not a string literal, argument types not checked [-Wformat-nonliteral]
util.c:831:28 / 862:28 / 893:28 : format not a string literal, argument types not checked [-Wformat-nonliteral]
```

and zero `-Wformat-security`, zero `-Wformat-zero-length`, zero `-Wformat=`. After the widening,
every one of the five site reverts reddens `W1`.

**How the five permitted diagnostics are handled: by TEXT, not by a `#pragma`, and not by a
line number.** J8 says they *"will need a localised suppression with a comment saying why"*. I
did not add one, deliberately: **this tree contains zero `#pragma` of any kind**
(`/usr/bin/grep -rc '#pragma' src/*.c src/*.h` sums to 0), two of the five are `draw.c`'s 1606
sites which 1608 has no business editing, and a tree-wide-zero row would need pragmas at all
five. So `W1` reads back the source line gcc named and permits exactly two spellings —
`sprintf(nstr, nfmt,` (the three inside `my_snprintf`, which `my_snprintf_spec_ok` guards) and
`sprintf(tmpstr, fmt1/fmt2,` (1606's class, which carries its own comment) — and forbids
everything else, including anything spelling `my_snprintf(`. Keyed on text because line numbers
rot; `util.c`'s comment names the row and says why it is scoped this way. If that is the wrong
call, the pragma version is three lines per site.

**And `W2` is not optional.** Without it, removing the attribute from `util.h` makes `W1` pass on
a tree with every door reopened — gcc then has no opinion to give. Driven: the
attribute-removal sabotage reddens `W2` and only `W2`.

### 7.3 ⚠ A ROW I WROTE WAS VACUOUS, AND ONLY THE SABOTAGE FOUND IT

`F4`'s first draft set `svg_font_name` to `%-2000d` and looked for `%-2000d` in the exported
`font-family`. **It passed with both `svg_font_name` sites reverted.** `svgdraw.c` emits the family
by **two** paths and only one goes through `my_snprintf`: `svg_embedded_style` writes a CSS rule
`text {font-family: %s;}` straight from `tclgetvar("svg_font_name")` with no `my_snprintf`
anywhere near it. The value the row found had never touched the code under test.

**Rewritten to assert an ABSENCE.** The two sites pre-load `svg_font_family` from `svg_font_name`,
and `svg_draw_string`'s reader emits the per-text `style="font-family:…"` attribute **only if
`svg_font_family` differs from `svg_font_name`**. So on a correct binary, a schematic with no
`font=` at all produces **zero** such attributes — the round trip preserved the value and the
`strcmp` matched. With a site reverted, `my_snprintf` refuses the spec, `svg_font_family` is left
empty, and `style="font-family:;"` appears. Two companion assertions stop the absence being
vacuous: a `<text>` element must exist, and the CSS rule must carry the value (which is what says
the variable really was set). Driven: the row now reddens on the `svg_draw`-`svg_font_name`
revert.

This is the general lesson worth the driver's attention: **"rc 0 and the value is present" is not
enough when the value has a second path to the output.** F1/F2/F3 are safe because `textfont` has
no second path — verified by the `"ZZ"` constant sabotage, which reddens all of F1, F2, F3 and F5.

### 7.4 Three deliberate departures from STAGE_C's text

1. **The `d/x/c/u` and `p` arms' bare `break` now sets `overflow = 1`.** STAGE_C lists this under
   *"Carried forward, named not fixed"*. It is fixed, because J6 required editing those exact two
   lines and leaving an asymmetry in a line one is already changing is how traps survive. Both
   receipt A §4 and receipt B §7.5 proved the change behaviour-identical, and the driver-based
   `G8`/`G10` rows confirm no output moved.
2. **A refusal on the (D) guard NUL-terminates at `string[n]`.** Not in J6. Without it, J6 turns a
   one-past write into an unwritten buffer — the (E) shape J3 exists to prevent. §2.
3. **No `#pragma` suppression at the five deliberate `-Wformat-nonliteral` sites.** §7.2.

And one departure from Stage B's recommended shape, which STAGE_C had already ordered: Stage B's
`spec_maxout` digit scan is **replaced** by a whitelist (Bv's §2 recommendation), because a digit
scan is an open-world assumption and `L` and `'` both walked through it. The helper is
`my_snprintf_spec_ok`, not `spec_maxout`; `spec_maxout` appears nowhere in the tree.

### 7.5 Figures I will not repeat, and the one I do quote

**The census figure is 720, by this suite's own parser over `gcc -E` output of `src/*.c` at the
`CFLAGS=` line in the generated `Makefile.conf`**, printed by row `P3`:

```
ok: P3 ... (calls=720 literal=720 nonliteral=0 conversions=1223 units=40 max_literal_spec_len=5
            instrument={gcc -E over src/*.c at Makefile.conf CFLAGS, this suite's own parser})
```

That is **not** Av's 722 and I am not claiming it is. Two of the three known differences are
accounted for — J1 removed one call (`my_snprintf(old_win_path, S(old_win_path), "")`) and Av
disclosed one artefact of its own argument splitter — and the third (1223 conversions against Av's
1218) is a scanner tie-break I did not chase, because **no row asserts either number**. `P3`
asserts a FLOOR (> 600 calls, > 30 units, > 1000 conversions) and prints the figure; `P1` and `P2`
assert properties. Four published totals for this one question already exist in this batch, which
is why.

**`max_literal_spec_len=5`** is the figure that matters, and it is asserted as a property by `P2`:
no live literal spec is refused by any of the three guards. That is the claim a reviewer would
most reasonably doubt, and it is driven rather than argued.

Nothing in this receipt carries 1606's *"774 characters"*. The numbers quoted in `util.c`'s
comment are `sprintf("%f", -DBL_MAX) == 317` and `sprintf("%.200f", -DBL_MAX) == 511`, both from
receipt B §1/§3d and both reproduced by rows `G7`/`G6`.

---

## 8. The issue file

`doc/claude/issues/1608-…md` rewritten: header block + **eight numbered corrections** at the top,
then the **original filing kept verbatim** beneath a rule. Issue 1606 puts its corrections at the
end; this one puts them first and says why in the header — the severity changed, not only the
detail, and a reader who stopped after the original filing would come away believing the defect is
latent.

The eight: (1) the `## What is LATENT and what is not` section is **false**, replaced by the driven
rc 134 table; (2) `%n` is reachable from a file and is an attempted arbitrary write, and `%nd`
passes every arithmetic bound; (3) this is the un-fixed twin of 1351, with the `ps_font_token`
judgement; (4) the tally goes from *"six unchecked writes in two mechanisms"* to **thirteen in
four**, with (B) firing first and silently and (D) escaping into the caller; (5) `~748` becomes
**720 compiled, instrument named**, with all five published figures tabulated and the
census-of-spellings warning; (6) the compiler fence is `-Wformat-nonliteral` and not
`-Wformat-security`; (7) item 3's *"would segfault or fail to compile"* is half wrong and the arm
is now deleted; (8) `parselabel.l`'s prototype was never live.

`**STAMP:**` updated to `v1 claim=fixed tree=91bb1bd7 stamped=2026-09-26 fix=taken open=6
by=1608-stage-C`, with a header line saying the commit and gate are the driver's and that `tree=`
wants re-stamping to the landing commit. `tclsh tests/headless/issue_stamp.tcl` →
`ISSUE-STAMP: ok (0 problems)`, `self-test PASSED (180 parser cases)`.

**Six items in "Still open"**: the `%s` arm's discarded field width; the `l`/`h` mis-fetch
(preserved on purpose); the unescaped `font=` in the SVG XML attribute; `psprint.c`'s
size-from-a-different-object; (E), narrowed but not closed; and the absence of any non-fortified
or Windows measurement.

---

## 9. Registration, and T1

`tests/run_regression.tcl`, one hunk:

```diff
-                 "headless/test_ev_precision_bound_1606"]
+                 "headless/test_ev_precision_bound_1606" \
+                 "headless/test_snprintf_fmt_1608"]
```

Counted the way CLAUDE.md prescribes (find `set hcases [list`, pipe through
`/usr/bin/grep -o '"[^"]*"' | wc -l`): **`hcases` 80 → 81**, `dcases` 15, `tcases` 3. So
`cases` should be 3 + 81 + 15 + `xschemtest` = **100**, `blocks` **99**, and `skips` unchanged at
**8**, because the suite self-skips nothing on either arm.

**T1 result: see §10.** Registered in `hcases` only, deliberately: no row needs a display, so a
`dcases` registration would cost a second case and a headless self-skip for nothing.

---

## 10. T1, solo

See the appended trailer below. Run from `tests/` as `tclsh run_regression.tcl`, solo (zero
`another regression run is live` lines; the three `results.<pid>.log` in the tree at the start all
had dead pids), in the main tree at `/home/analog/dev/xschem-claude` — **30 characters**, which
CLAUDE.md measures as reaching 92 at `test_op_annot`'s deepest fixture path and giving `ALL PASS`,
well under the eliding threshold. `make -C src` immediately before, binary
`f7b4727de595ed67b6ec8f5ce04b705f`.

**The run's answer is `tests/results.2446606.log`, not `results.log`. Trailer, verbatim:**

```
T1-RUN-BEGIN pid=2446606 script=run_regression.tcl start=2026-09-26 17:25:20 planned_cases=100 verdict=results.2446606.log home=throwaway binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
T1-RUN-END pid=2446606 cases=100 blocks=99 counted_failures=0 skips=8 elapsed=595s end=2026-09-26 17:35:15
```

**`cases=100 blocks=99 counted_failures=0 skips=8`**, exactly the predicted step from the
`eb20dc62` baseline of `99/98/skips=8`: one case, one block, **no new skip**. `wc -l` 299 (was
296). Zero lines ending `FAIL`/`GOLD?`/`RESULT?` and zero starting `FATAL`, so the
counted-failure grep is empty. The eight `skip:` lines are the same eight the baseline had —
`test_op_annot` ×5 on the headless arm plus `test_input_line_inject_1352`,
`test_preview_name_inject_1601` and `test_generator_paren_1604`, all three of which drive real Tk
dialogs — and **none of them belongs to this suite**.

The 1608 block, verbatim from the verdict:

```
headless/test_snprintf_fmt_1608.log
RESULT: ALL PASS (28 checks)
Total num fail: 0
```

---

## 11. What I could NOT measure

* **No non-fortified build and no Windows build.** Every abort quoted is `_FORTIFY_SOURCE=3` with
  `__sprintf_chk`/`__strncpy_chk` on x86-64 glibc, gcc 15.2.0. Inherited from A/Av/B/Bv and
  repeated rather than quietly dropped. It is exactly where the `%n` finding bites hardest, and it
  is the reason GUARD 2 refuses `%n` itself rather than trusting libc.
* **Whether (D) is reachable from any LITERAL format.** Still uncensused. `P2` proves no literal
  spec is *refused*; it does not census each site's destination buffer size against the length of
  each literal run, which is what (D) needs. Reachable from the (now-closed) non-literal doors,
  driven.
* **Whether the `L` garbage can ever be a large finite** rather than NaN. Bv drove 7 environments
  × 3 doors × 2 binaries, all NaN, and showed it is frame-layout dependent. GUARD 2 refuses `L`
  outright so the question is moot here, but it is not answered.
* **The `+464`-byte stack frame against recursion depth.** Bv named it as unpriced; I did not price
  it either. `my_snprintf` is called from the hierarchy walk and the generated parsers, and nobody
  has bounded the deepest call chain containing it. The frame grew again with `nstr[512]`, and I
  did not re-measure the figure — naming it as unmeasured, not as safe.
* **`%'` in a grouping locale, end to end.** GUARD 2 refuses `'`, so the locale-dependent width
  never reaches `sprintf`; I did not re-run Bv's `setlocale` probe against the patched file.
* **The `p` arm's only live caller** (`util.c`'s `%p` behind `debug_var > 2`). Driven through the
  test driver (`G10` case `I7`, `x=0x58`); not driven through the shipped binary.

## 12. Carried forward, named not fixed

1. **The `%s` arm discards a field width.** `"[%-12s]"` emits `[AB]`, no padding — that arm never
   builds `nfmt`. A developer who writes `%-60s`, sees no padding and "fixes" it lands on the
   aborting arm, which is the stylistic precedent the issue's own filing cites.
2. **`%ld`/`%lu`/`%hu`/`%hhd` mis-fetch**, preserved on purpose so three live callers keep
   printing. Row `G5` is the fence against tightening the whitelist onto them silently.
3. **The `font=` value is unescaped in the exported SVG's XML attribute.** §1. Needs its own issue.
4. **`psprint.c` takes a size from a different object**: `my_snprintf(ps_font_family,
   S(ps_font_name), "Helvetica")` at two sites. Both `[80]` today; live the moment either is
   resized. (Av's find, re-confirmed present.)
5. **(E) narrowed, not closed.** `my_snprintf(u, 2, "abcd%d", 7)` still returns 0 with `u`
   untouched — the `%s` arm's second check and the post-`sprintf` check can still break at `n == 0`.
   The (D) fix removes the case J6 would otherwise have created; it does not remove the class.
6. **Three comments in `draw.c`, `save.c` and `token.c` that said "without HAS_SNPRINTF"** are now
   re-spelled (§4). Not a defect, but it is a change outside J10's text and it is reported.
