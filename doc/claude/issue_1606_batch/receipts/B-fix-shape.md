# Receipt B — `design:fix-shape` (issue 1606)

**Crew:** Stage B, `design:fix-shape`. **Tree:** `34913077`, clean (`git status --porcelain`
shows only the three pre-existing untracked paths). **Binary:** rebuilt at the start of this
stage (`touch src/util.c && make -C src`) and confirmed current at the end
(`make: Nothing to be done for 'all'`). Nothing in `src/` was edited. No commit, no ledger
touch, no display used — every binary run was
`timeout 60 env -u DISPLAY ./src/xschem --nogui --pipe -q --script <f>`.

⚠ **`receipts/` was empty when this stage started — there is no Stage A receipt.** Stage A
and B were dispatched together (the ledger says so). Sections 1 and 7 below therefore
contain measurements that belong to Stage A's remit; they were needed to cost the options and
to answer the G1 question, and they **contradict Stage A's framing in the plan**, so Stage A
should read this before it reports rather than re-deriving.

**Recommendation: clamp at the point of use, through one small helper pair, plus the three
writers of `xctx->ev_precision` — three, not two.** Full shape in §8.

---

## 1. The abort, reproduced headless with no display and no `draw()` — and the third writer

```
for p in 4 71 72 73 200; do   # script: set ev_precision $p ; xschem eval_expr {expr_eng(1e300*1.0)}
  timeout 60 env -u DISPLAY ./src/xschem --nogui --pipe -q --script ev$p.tcl
done
```

```
p=4   -> rc=0    EV=4  len=7  val=1e+288T
p=71  -> rc=0    EV=71 len=78 val=1.0000000000000000076304735395750356605147783355117107507800866644399695e+288T
p=72  -> rc=0    EV=72 len=79 val=1.00000000000000000763047353957503566051477833551171075078008666443996951e+288T
p=73  -> rc=134  *** buffer overflow detected ***: terminated
p=200 -> rc=134  *** buffer overflow detected ***: terminated
```

The 1602 sweep replicates exactly (71→78, 72→79, 73→abort).

**The load-bearing fact: the `set` happens inside the script and the abort happens on the very
next command, with no `draw()` in between and `DISPLAY` unset.** Something other than
`draw()`/`draw_graph()` refreshed the C mirror. It is `kklex()`:

```
src/eval_expr.y:258      xctx->ev_precision = tclgetintvar("ev_precision");
src/eval_expr.c:1707     (the generated copy of the same line)
```

`kklex()` is the bison lexer's token function, so **every** `xschem eval_expr`, and every
`expr()`/`expr_eng()` token expanded during netlisting, re-reads the raw Tcl value into
`xctx->ev_precision`. `PLAN.md` cites `eval_expr.c:1721`'s *read* (`engineering =
xctx->ev_precision`) and calls it "the reproducer's own path" but does not notice the *write*
four lines above it.

Two further Stage-A worries in the plan are unfounded, measured:

* `draw()` is **not** behind `has_x` — `src/draw.c` `draw()` does `if(has_x) tk_scaling = …;`
  and then `xctx->ev_precision = tclgetintvar(…)` unconditionally, two lines later.
* `xschem redraw` runs clean headless (`REDRAW: ` with an empty error string, rc 0). So the
  `draw()` writer is reachable on the `--nogui` arm and a sabotage of a clamp there is not
  automatically display-only.
* `xschem globals` does **not** report `ev_precision`, so there is no read-back seam for the
  C mirror today. If Stage C wants a behavioural row that proves the *writer* clamp rather
  than a consumer's, it needs one (a `xschem get ev_precision` would be the cheap seam).

## 2. `HAS_SNPRINTF`: absent, at four levels

| level | check | result |
|---|---|---|
| `config.h` | `/usr/bin/grep -in snprintf config.h` | **no match** |
| `config.h.in` | read in full | **no `HAS_SNPRINTF` line exists at all** — not a `print_ternary` that evaluated false, there is no machinery |
| `scconfig` | `/usr/bin/grep -n snprintf scconfig/config.cache` | **no match** in 354 lines — `libs/snprintf` was never even probed; `deps_default.c` offers it, `hooks.c` never requests it |
| command line | `touch src/util.c && make -C src` | `gcc -c -pipe -O2 -I… -o util.o util.c` — **no `-D` of any kind** |
| running binary | `xschem globals`, headless | prints `HAS_DUP2=1`, `HAS_POPEN=1`, `HAS_CAIRO=1` and **no `HAS_SNPRINTF=` line** |

`src/util.c`'s comment (*"IS DEFINED NOWHERE IN THIS TREE — not in config.h, not in scconfig,
not on any command line"*) is **correct and now verified at the binary level too.**

**Therefore the `#else` arm at `src/util.c:641`–`768` is what compiles: the hand-rolled
formatter.** It understands `%s %d %x %c %u %p %g %e %f` and copies the conversion spec
verbatim into a `char nfmt[50]`, then `sprintf`s into a `char nstr[50]`.

## 3. What the hand-rolled arm does with `"%.*g"` — reproduced, and it is worse than either comment says

Method: the `#else` arm's body copied verbatim out of `src/util.c` (lines 641–768) into a
standalone probe, `gcc -pipe -O2` (the tree's own flags), run per case.

```
"%.*g%c",      4, 1.111, 'x'   ->  *** buffer overflow detected ***: terminated   (rc 134)
"%.*g",        4, 1.111         ->  |1|            n=1
"val=%.*g%c",  4, 700.0, 'm'    ->  |val=700\004|  n=8      (od -c: v a l = 7 0 0 004)
"%.4g%c",         1.111, 'x'    ->  |1.111x|       n=6      (control: literal precision works)
```

A second probe, identical except `nstr` enlarged to 65536 so the width is observable instead
of fatal, prints the mechanism:

```
nfmt=|%.*g| double_read=1.111 nlen=54    (nstr[50] in the SHIPPED code)   x6 runs, stable
nfmt=|%.*g| double_read=700   nlen=3     (nstr[50] in the SHIPPED code)   x3 runs, stable
```

**Findings, and both existing source comments need correcting.**

* **The arm reads the `double` CORRECTLY** (`double_read=1.111`, `double_read=700`). libc then
  reads the `*` precision from the next *integer* argument register, which is garbage —
  here 54-ish for the `1.111` shape, 0 for the `700.0` shape. Stable per call shape in this
  build, different between shapes. So `save.c` `nd_view_set`'s *"it reads the double out of
  the varargs and then lets libc's own sprintf go looking for a precision argument that is no
  longer there"* is **mechanically right**.
* **`save.c`'s specific number, `1.111 printed as 1.111000061035156`, did NOT reproduce.**
  That value is `double((float)1.111)`, which this path cannot produce; what this build
  produces is a 54-character string. The digits are whatever integer register the call leaves
  behind, so **the quoted number is not a reproducible fact and should not be quoted as one.**
* **⚠ And the real outcome is not a wrong string — it is SIGABRT.** 54 characters + NUL into
  `char nstr[50]` overflows the arm's **own** scratch buffer, `_FORTIFY_SOURCE` catches it,
  the process dies: `*** buffer overflow detected ***: terminated`, rc 134. The comment
  reassures the reader that misusing `my_snprintf` here costs a wrong number. It costs the
  editor.
* **`draw.c` `graph_marker_fmt`'s comment is WRONG on this ABI.** It says `"%.*g"` *"made it
  consume the int `prec` AS THE DOUBLE"*. On x86-64 SysV the integer and SSE argument areas
  are separate, so `va_arg(args, double)` cannot see `prec` — measured, it got 700 and 1.111.
  Reading the int `4` as a double bit pattern would give ~2e-323, not `700.000…`. Its quoted
  `700.0000000000001136868377216160297393798828125` is a *garbage precision applied to the
  correct double*, which is a different defect with the same symptom.
  Its **"swallowed suffix"** half is exactly right and I reproduced the mechanism: after the
  `g` arm consumes the double, the `%c` arm does `va_arg(args, int)` and gets the **first**
  integer slot, which holds `prec` — so `'m'` came out as `\004`, the character whose code is
  the precision.

### What teaching it a `*` precision would actually cost

Not "parse one extra character". Three things, in order of nastiness:

1. **`nstr[50]` has to go.** The arm's conversion path is `nlen = sprintf(nstr, nfmt, i)` into
   a 50-byte stack buffer *before* anything checks the caller's `size`. With a working `*` and
   precision 200 that is a 209-byte write into 50 bytes — the abort of §3 again, now reached
   deliberately. So the arm needs a heap buffer or a bound of its own, i.e. the clamp this
   issue is about, *inside* the formatter. **Option 3 does not remove the need for a clamp; it
   relocates it into a tree-wide function.**
2. **The varargs order has to be got right by hand** — read the `int` for `*`, then the
   `double`, and keep the existing `%s/%d/%c/%p` arms' consumption order intact. ~15 lines in
   a hand-rolled varargs walker used by **~748 call sites** (counted:
   `/usr/bin/grep -c 'my_snprintf(' src/*.c` summed, minus the two definitions).
3. **It changes the user-visible outcome for the worse at the twelve sites.** `my_snprintf`
   *truncates*; a clamp *shortens the request*. Truncating gives a number cut mid-digit
   (`1.00000000000000000763…e+2` with the exponent and suffix amputated); clamping gives a
   shorter but complete number. A readout that silently drops its exponent is worse than one
   with fewer digits.

**Verdict on the driver's belief about option 3: CONFIRMED, and for a stronger reason than the
one in `DECISIONS.md`.** It is not just "larger blast radius for the same outcome" — it cannot
be done without adding a clamp anyway, and its outcome at these sites is worse.

## 4. Option 4 (define `HAS_SNPRINTF`): recommend against, and it would be a net memory-safety regression

* **No machinery exists.** `config.h.in` has no line for it; `scconfig/hooks.c` never requests
  `libs/snprintf`; `config.cache` never probed it. So it needs a `print_ternary` in
  `config.h.in`, a `dep_add`/require in `hooks.c`, and a `./configure` re-run — and
  `CLAUDE.md`'s generated-file rule then applies to the whole tree.
* **⚠ `my_snprintf`'s RETURN CONTRACT INVERTS, and three call sites use it as a length.** The
  hand-rolled arm returns bytes **actually written** (truncated). `vsnprintf` returns the
  length that **would** have been written. Five sites consume the return value
  (`/usr/bin/grep -n '= *my_snprintf(' src/*.c` plus the `+=` forms):

  | site | use | what inverting the contract does |
  |---|---|---|
  | `src/hilight.c` `publish_net_hilight_styles_to_tcl` | `off += my_snprintf(s + off, sz - off, …)` | `off` can exceed `sz`; the next iteration passes a negative `sz - off` to a `size_t` — an effectively unbounded write |
  | `src/token.c` (`@spice_ignore` pin name, `result_pos += my_snprintf(result + result_pos, tmp, "%s", …)`) | same accumulator shape | same |
  | `src/editprop.c` `dtoa_prec` | `n = my_snprintf(…); xctx->tok_size = n;` | `token.c` ×7 then does `memcpy(result+result_pos, valstr, len+1)` with `len = xctx->tok_size` — an out-of-bounds **read** past a `static char s[70]` |
  | `src/util.c` `my_itoa`, and the `%.8g` sibling | set `xctx->tok_size` | same |

  So option 4 converts three truncation-safe accumulators into overflows. **It would introduce
  a defect of the same class as 1606, at more sites, to fix 1606.**
* **⚠ `src/scheduler.c:6263` would SIGSEGV immediately.**
  `my_snprintf(res, S(res), "HAS_SNPRINTF=%s\n", HAS_SNPRINTF)` — an `%s` given the macro's
  int value. Today the hand-rolled arm is what runs and the line is inside
  `#ifdef HAS_SNPRINTF`, so it is dead. Define the macro and `xschem globals` dereferences
  pointer `1`. **This is independent proof the `vsnprintf` arm has never been compiled by
  anyone, on any platform.**
* **Every truncation becomes a modal dialog.** The `vsnprintf` arm does
  `tcleval("alert_ { Warning: overflow in my_snprintf …}")` whenever `has_x` and the output
  was truncated. Today truncation is silent (`dbg(1, …)`). That is a large user-visible
  behaviour change across ~748 sites. (The alert's own `snprintf` also passes `size_t` to
  `%d`.)
* **Output changes at 17 sites** whose formats the arms handle differently
  (`/usr/bin/grep -nE '%%|%l[dux]|%z|%[0-9]+[dsxu]|%-[0-9]|%\.\*'` over the `my_snprintf`
  calls): mostly `%02x`/`%4d` which both arms get right, but `scheduler.c`'s `%ld`
  (`XMaxRequestSize`) and `%lu` currently read an `int` out of a `long` slot and work by
  little-endian accident. Those would become correct — a change, and a welcome one, but a
  change nobody asked for in this batch.
* **And it still would not fix 1606.** With the real `vsnprintf`, `dtoa_eng`'s
  `my_snprintf(s, S(s), "%.*g%c", 200, …)` truncates safely **and returns 209**, which lands
  in `xctx->tok_size`, which `token.c` `memcpy`s `210` bytes from an 80-byte `static`. Worse
  than today at exactly the site the issue is about.

**Cost verdict: reject for this batch, and the reason to record is not "it is big" — it is
that the arm it switches to is demonstrably unexercised (§4 bullets 3 and 4) and inverts a
contract three accumulators depend on.** There *is* a reason it was never enabled, and this is
it. If anyone ever wants it, it is its own issue with its own audit of those five return-value
sites.

## 5. Option 2 (size the buffer) — measured, and both the issue and the plan have the premise wrong

**`dtoa_eng` has 24 call sites, not 27 (`PLAN.md`) and not "~70" (the issue).**
`/usr/bin/grep -o 'dtoa_eng(' src/*.c | sort | uniq -c` gives callback 6, draw 11, editprop 2,
eval_expr.c 1, token 7 = 27 *occurrences*; three of those are not calls — `editprop.c:159` is
the definition, `editprop.c:165` is a `dbg()` format string, `draw.c:7809` is the
`dtoa_eng() returns a SHARED static buffer` comment. **24 real call sites** (+ `eval_expr.y:153`,
which is the source of `eval_expr.c:1602`, the same call).

**I read all 24. ZERO hold the returned pointer as a `const char *` across another call that
could re-enter `dtoa_eng`.** Breakdown:

* **17 pass it in argument position** and never hold it at all: `callback.c` ×4
  (`tclvareval("input_line {Pos:} {} ", dtoa_eng(…), NULL)`), `draw.c` ×4 (`draw_string(…,
  dtoa_eng(…, 5), …)`), `draw.c` ×6 (`my_snprintf(tmpstr, S(tmpstr), "%s", dtoa_eng(…))` at
  `draw_cursor`/`draw_cursor_difference`/`draw_hcursor`/`draw_hcursor_difference`,
  `graph_marker_fmt`, `graph_marker_text_rec`'s slope), `eval_expr.c` ×1, `callback.c` ×2
  (`my_strncpy(sx, dtoa_eng(…), S(sx))`).
* **7 assign to `const char *valstr` in `token.c`** and copy on the **next statement**
  (`my_strdup2(_ALLOC_ID_, &pin_attr_value, valstr)` or `memcpy(result+result_pos, valstr,
  len+1)`), with nothing between but a `dbg()`.

**So the static-buffer contract is not what blocks option 2.** What blocks it, measured by
reading the same 24 sites:

1. **The 7 `token.c` sites also assign string literals to the same variable** — `valstr =
   "0.0"`, `valstr = "-"` — so an owning return needs a per-branch ownership flag or a strdup
   of each literal, on paths that already carry early `break`s and `my_free`s.
2. **4 of the 17 are inside `tclvareval(…, NULL)` varargs calls**, where a malloc'd return has
   nowhere to be freed without hoisting a local at each.
3. `dtoa_eng` sets `xctx->tok_size` and `token.c` ×7 uses it as a `memcpy` length; a heap
   buffer keeps that working, so that part is neutral.
4. It would add a `my_malloc`/`my_free` pair to the netlist token-expansion inner loop
   (`token.c`, per instance per pin) and to the graph redraw path. I did **not** measure the
   cost; I note only that this file's own comments record an O(N²) redraw being worth a
   redesign (`graph_markers_collect`, 220 ms at 512 markers), so the tree treats that loop as
   hot.

**Cost verdict: 24 call sites touched, 4 of them in varargs argument position, 7 needing
ownership branches — to remove a ceiling nobody has asked to remove.** Reject. But reject it
for the right reason: the issue's stated reason ("~70 call sites rely on the static contract")
is false on both the number and the substance.

## 6. The arithmetic, measured rather than asserted — and the formula

`sprintf` into a 4096-byte buffer, negative value with a 3-digit exponent (the widest shape
`%g` can make):

| prec | `len("%.*g")` | `len("%.*g%c")` | `len("%.*e%c")` |
|---|---|---|---|
| 70 | 77 | 78 | 79 |
| 71 | 78 | **79** | 80 |
| 72 | 79 | 80 | 81 |

So **`"%.*g%c"` costs `prec + 8` characters, i.e. `prec + 9` with the NUL** →
**safe cap = `bufsize - 9`.** At 80 bytes that is **71**, exactly the number 1602 published
from its sweep. The sweep and the arithmetic **agree**.

Three consequences the plan and 1602 both miss:

* **`"%.*e%c"` is one byte WIDER per precision unit** (`prec + 9` chars, `prec + 10` with NUL)
  → cap = `bufsize - 10`. `%g`'s precision counts *significant* digits (1 lead + prec−1
  fraction); `%e`'s counts *fraction* digits and always emits an exponent. **A single overhead
  constant derived from `%g` under-protects any `%e` site by one byte per precision unit.**
* **`draw_hcursor` and `draw_hcursor_difference` use `" %.*g%c "`** — two literal spaces — so
  their cap is **89**, not 91. **Issue 1602's "`draw.c`'s `char tmpstr[100]` overflows at 92"
  is right for `draw_cursor`/`draw_cursor_difference` and off by two for the other two
  cursor sites (they overflow at 90).** Measured: `" %.*g%c "` at prec 90 is 100 characters,
  101 with the NUL.
* `dtoa_eng`'s `MEG` branch is **not** the binding case: the value there is in
  `(0.999999, 999.999]` so `%g` cannot emit an exponent for prec ≥ 3, giving `prec + 6`.
  `prec + 9` from the `T` branch covers it.

Derived caps for the table's buffers: **80 → 71**, **100 → 91** (`"%.*g%c"`) / **89**
(`" %.*g%c "`), **1024 → 1015** (`%g`) / **1014** (`%e`).

## 7. G1 verdict: **PARTLY**

> *Does clamping the two `xctx->ev_precision = tclgetintvar("ev_precision")` writers in
> `src/draw.c`, plus `dtoa_eng` clamping its own parameter, bound all twelve sites?*

**No.** The prediction's shape is right — it is a clamp, it lands in a handful of places, and
option 3 is not viable — but its enumeration of the writers is wrong and it leaves one site
unbounded outright.

**Bounded by that pair (9 of 12):** `editprop.c` ×3 (its own parameter); `draw.c:4967`
`draw_cursor`, `draw.c:4999` `draw_cursor_difference`, `draw.c:5029` `draw_hcursor`,
`draw.c:5063` `draw_hcursor_difference`, `draw.c:5258` (`%.*e`/`%.*g` in the measures
overlay) — all read `xctx->ev_precision`; `callback.c:2428`, `callback.c:2433`; and
`save.c:2904` `nd_view_set` via `nd_view.prec`, whose only two writers are
`ngspice_data_arm(raw, xctx->ev_precision)` (`callback.c:1507`) and
`ngspice_data_arm(xctx->raw, 4)` (`save.c:3848`).

**Still unbounded:**

1. **⚠ A THIRD WRITER, which the prediction and the plan both miss: `eval_expr.y:258`
   (`kklex`), generated into `eval_expr.c:1707`.** It is unconditional, runs on every lexer
   token, and therefore **undoes a clamp applied at the two `draw.c` writers** for all nine
   sites above until the next `draw()`. It is also the writer the reproducer actually goes
   through (§1). And it lives in a **generated** file: `src/eval_expr.c` is untracked and
   `make clean` deletes it, `src/Makefile` regenerates it (`bison -p kk -o eval_expr.c
   eval_expr.y`, bison 3.8.2 present). **Stage C must edit `src/eval_expr.y`; a static row
   must grep the `.y`, because the `.c` does not exist in a fresh clone before a build.**
2. **`draw.c` `graph_marker_fmt`'s `sprintf(dest, "%.*g%c", prec, …)`.** Its `prec` comes from
   `graph_marker_text_rec`'s own `tclgetintvar("ev_precision")` (`draw.c:7830`), an
   **independent Tcl read that deliberately never touches `xctx->ev_precision`** — its own
   comment says *"a getter must not write xctx->ev_precision (draw_graph owns that)"*. So
   **neither a writer clamp nor a `dtoa_eng` clamp reaches it.** It is bounded today only by
   the caller's unrelated `if(prec > 17) prec = 17;`, and it ignores the `destsize` it is
   handed. Its `else` branch (`my_snprintf(dest, destsize, "%s", dtoa_eng(v, prec))`) is safe
   both ways; the `if` branch is the exposed one.
3. Not a hole but a trap for the fix: a per-site cap computed as `sizeof(buf) - 9` is **two
   bytes too generous at `draw_hcursor` and `draw_hcursor_difference`** (their format has two
   literal spaces, §6) and **one byte per precision unit too generous at any `%.*e` site**.
   The `%.*e` branch in the measures overlay forces `prec = 2` today, so it is latent — but
   the plan is right to flag that its `%.*g` branch does not.

**Also refuted, from `DECISIONS.md`'s own "what would refute it" list:** *"`draw()` never runs
on the headless arm, so `ev_precision` stays 4"*. `draw()` writes it unconditionally (not
behind `has_x`) and `xschem redraw` runs clean under `--nogui` with `DISPLAY` unset.

**Held, from the same list:** *"`my_snprintf`'s hand-rolled arm turning out to already handle
`*`"* — it does not, and what it does instead aborts the process (§3).

**And `DECISIONS.md` is right about the thing it insists on:** `dtoa_eng` must clamp its own
parameter regardless. Two extra reasons it did not state. First, `dtoa_eng` writes
`xctx->tok_size = n` from `sprintf`'s return, and `token.c` ×7 then `memcpy`s `tok_size + 1`
bytes out of the 80-byte `static` — so an unclamped precision is an out-of-bounds **read** as
well as a write, and only a clamp *inside* `dtoa_eng` bounds `tok_size` by construction.
Second, `graph_marker_text_rec` passes it a `prec` that no writer clamp can reach.

## 8. Recommended shape — G2 endorsed in substance, split in two by conversion

G2's core ("a helper that takes the buffer size and returns the safe precision, so the clamp
cannot drift from the buffer it protects") is **right and I am adopting it.** One change:
**one helper cannot serve both conversions**, because `%e` needs one more byte per precision
unit than `%g` (§6) and `%g`'s maximal cap is what makes 80 → 71 and keeps C in step with
1602's published dialog ceiling. A single `%e`-safe constant would give 70 at 80 bytes and put
the C ceiling one below the dialog's. So: two names, and the name at the call site says which
conversion it is guarding — which a reviewer, and a static row, can both check against the
format string on the same line.

### The helpers — `src/util.c`, declared in `src/xschem.h`

```c
/* Cap `prec` so ONE "%.*g" conversion plus at most one suffix character and the
 * NUL cannot outgrow `avail` bytes. MEASURED worst case (negative value, 3-digit
 * exponent): strlen of "%.*g%c" is prec + 8, so avail must be >= prec + 9; the
 * cap is therefore (int)avail - 9, which at avail 80 is 71 -- exactly issue
 * 1602's dialog ceiling, derived here rather than typed.
 * `avail` is the space left for the CONVERSION: sizeof(buf) minus any literal
 * bytes elsewhere in the format. draw_hcursor's " %.*g%c " passes S(tmpstr) - 2.
 * A prec <= 0 is returned UNCHANGED: 0 is eval_expr's "engineering off" flag
 * (issue 1602 §2) and a negative makes printf use its default, so raising
 * either would change behaviour instead of bounding it. */
int clamp_prec_g(int prec, size_t avail);

/* Same for "%.*e", which is one byte WIDER per precision unit -- %e's precision
 * counts FRACTION digits and it always emits an exponent (measured: strlen of
 * "%.*e%c" is prec + 9), so the cap is (int)avail - 10. */
int clamp_prec_e(int prec, size_t avail);
```

Bodies, one statement each:

```c
int clamp_prec_g(int prec, size_t avail)
{
  int max = (int)avail - 9;
  if(max < 1) max = 1;
  if(prec > max) prec = max;
  return prec;
}
/* clamp_prec_e is identical with - 10. */
```

Plus, in `src/xschem.h` beside the `dtoa_eng` declaration, so the 71 has exactly one source:

```c
#define DTOA_ENG_BUFSIZE 80   /* clamp_prec_g(.., 80) == 71 == issue 1602's dialog ceiling */
```

### Function by function

| function (file) | change |
|---|---|
| `dtoa_eng` (`editprop.c`) | `static char s[DTOA_ENG_BUFSIZE];` and, right after the `dbg()`, `precision = clamp_prec_g(precision, DTOA_ENG_BUFSIZE);` — **one** clamp above the branch covers all three `sprintf`s (the `MEG` branch is `prec + 6`, strictly narrower). This is also what bounds `xctx->tok_size` for `token.c`'s seven `memcpy`s. |
| `draw_cursor`, `draw_cursor_difference` (`draw.c`) | `clamp_prec_g(xctx->ev_precision, S(tmpstr))` |
| `draw_hcursor`, `draw_hcursor_difference` (`draw.c`) | `clamp_prec_g(xctx->ev_precision, S(tmpstr) - 2)` — the `- 2` is the two literal spaces in `" %.*g%c "`, and the comment must say so or the next reader deletes it |
| `show_node_measures` (`draw.c`, the `int prec = xctx->ev_precision` site — **`PLAN.md` calls this `draw_graph_variables`; no such symbol exists**) | `int prec = clamp_prec_e(xctx->ev_precision, S(tmpstr));` — `_e` because the branch below may select `"%.*e"` and that is the wider shape; the existing `prec = 2` on that branch stays |
| `callback.c` ×2 (the graph measurement tooltip) | `clamp_prec_g(xctx->ev_precision, S(sx))` / `S(sy)` |
| `nd_view_set` (`save.c`) | `clamp_prec_g(nd_view.prec, S(s))`, **and rewrite the comment**: delete *"100 bytes is ample for one `%g`"* (false above 91), and replace the unreproducible *"1.111 printed as 1.111000061035156"* with what §3 measured — the hand-rolled arm reads the double correctly, libc then takes a garbage precision, and the result overflows the arm's own `nstr[50]` and **aborts the process** |
| `graph_marker_fmt` (`draw.c`) | `sprintf(dest, "%.*g%c", clamp_prec_g(prec, (size_t)destsize), unit * v, suffix);` — **this is issue 1606 item 4**: the `destsize` stops being decorative, the signature stops lying, and the latent fifth-caller hazard closes instead of being documented. Keep the caller's `if(prec > 17)`; retitle its comment — 17 is now a *display* choice (17 digits round-trips a double), not the safety bound. **Also correct this comment**: `"%.*g"` does **not** consume the int as the double on this ABI (§3); what it consumes wrongly is the **suffix** |
| `draw_graph` (`draw.c`), `draw` (`draw.c`), **`kklex` (`eval_expr.y` — the `.y`, never the generated `.c`)** | `xctx->ev_precision = clamp_prec_g(tclgetintvar("ev_precision"), DTOA_ENG_BUFSIZE);` |

**Why both layers, when the writer clamp makes most of the per-site ones redundant.** The
per-site clamp is the fix: it is the only thing that reaches `graph_marker_fmt` and the only
thing that makes `dtoa_eng` correct by construction rather than by coincidence, and it cannot
drift from the buffer because it is computed from `sizeof`. The three writers are the second
layer, and they buy two specific things, not tidiness: they bound `nd_view.prec`, which is
*stored* in one file and *used* in another after an arbitrary delay, and they give the whole
family **one** user-visible ceiling (71) instead of 71/89/91/1014 on different surfaces. Cost:
three lines.

**On fencing, and the brief's "every guard needs a row that reddens".** The writer clamp masks
the per-site clamps behaviourally, so most per-site clamps can only be fenced **statically**
— which is what `PLAN.md` already prescribes ("a behavioural row wherever the abort can be
driven deterministically, and a static row where it cannot") and what this tree's static rows
are built for (strip block comments and `#if 0`, assert by name). Concretely, for Stage C:
behavioural rows are available at (a) the `kklex` writer — the §1 reproducer, headless, rc 134
vs. rc 0, which reddens if the `eval_expr.y` clamp *or* the `dtoa_eng` clamp is removed; and
(b) `graph_marker_fmt`, reachable through the `graph_marker text` Tcl verb, which reddens if
the `clamp_prec_g(prec, destsize)` is removed **and** the caller's `17` is raised — so that one
wants a row that drives the verb after setting `ev_precision` high, plus a static row on the
`17` itself. Everything else is static, by name, on the `.y` for `kklex`.

### What I rejected

* **A literal `71` anywhere in C.** `DTOA_ENG_BUFSIZE - 9` derives it; a literal is exactly
  the drift G2 warns about.
* **A single helper with a `fixed`/overhead argument.** The caller still has to count, and a
  wrong count is invisible. Two names put the conversion in the identifier.
* **G2's "refuse rather than clamp" alternative.** Worth putting to the user as G2 says, and
  I can add one fact that strengthens the case against it: the error would have to fire not
  only from `draw()` (a redraw path, as G2 notes) but also from **`kklex()`**, which is a
  bison lexer reached during netlisting — a message emitted there lands in the middle of a
  netlist run. Clamping is the only one of the two that has a quiet place to happen.

## 9. Behaviour change, exactly

A user with `set ev_precision 200` in `~/.xschem/xschemrc`:

* **Before (measured, this binary, headless):** the first value that scales into a suffixed
  branch kills the process — `*** buffer overflow detected ***: terminated`, SIGABRT, `rc=134`,
  no chance to save. Reached by `xschem eval_expr {expr_eng(…)}`, by any `expr_eng()` token
  during netlisting, and (per the site table) by a graph cursor readout on a plain redraw.
* **After:** 71 significant digits, everywhere, and the process lives. Measured string for the
  reproducer at the clamped value:
  `1.0000000000000000076304735395750356605147783355117107507800866644399695e+288T` (78 chars).
  With the writer clamp the cursor readouts and the annotation publisher show the same
  71-digit shape rather than their own 89/91/1014 ceilings.
* **What does NOT change, and the user should be told:** the clamp is on the **C mirror**, not
  on the Tcl variable. `to_eng` and the annotation sheet still do `format %.200g` and still
  print 200 digits, so C and Tcl still disagree for an out-of-range rc value. That is 1602's
  residue (it fixed the dialog, not the mirror), not something this fix creates or closes.
* **And `0` still means "engineering off".** The helper returns `prec <= 0` unchanged on
  purpose, so `set ev_precision 0` keeps the behaviour 1602 measured (C prints `1.11e-05`
  where Tcl prints `1e+01u`). Imposing 1602's *floor* in C would be a second, separate
  behaviour change and is not part of this fix.

## 10. Contradictions with `PLAN.md` / `DECISIONS.md` / the issues

1. **`xctx->ev_precision` has THREE unclamped writers, not two.** The third is
   `eval_expr.y:258` (`kklex`), generated into `eval_expr.c:1707`. `PLAN.md` §"The chokepoint"
   and `DECISIONS.md` G1 both say "exactly two". It is the one the reproducer uses.
2. **`PLAN.md`'s symbol `draw_graph_variables` does not exist.** The 1024-byte site is
   `show_node_measures` (`draw.c`). Cite by symbol, per `CLAUDE.md`.
3. **`dtoa_eng` has 24 call sites**, not `PLAN.md`'s 27 (three of the 27 grep hits are the
   definition, a `dbg()` format and a comment) and not the issue's "~70".
4. **Option 2 is not blocked by the static-buffer contract.** Zero of the 24 hold the pointer
   across a re-enterable call; all 24 consume or copy it within one statement. The real cost
   is the 7 `token.c` literal/owned branches and the 4 `tclvareval` varargs positions.
5. **`save.c` `nd_view_set`'s "1.111 printed as 1.111000061035156" is not reproducible** and
   the comment **understates the outcome**: this build aborts (`rc=134`). Its *mechanism*
   sentence is right.
6. **`draw.c` `graph_marker_fmt`'s "consume the int `prec` AS THE DOUBLE" is wrong on x86-64.**
   The double arrives intact; the **suffix** is what gets consumed wrongly (`'m'` → `\004`).
   Its quoted 46-digit string is a garbage *precision*, not a misread double.
7. **Issue 1602's "`draw.c`'s `char tmpstr[100]` overflows at 92"** holds for
   `draw_cursor`/`draw_cursor_difference` and is **off by two** for `draw_hcursor` and
   `draw_hcursor_difference` (90), whose format carries two literal spaces.
8. **`PLAN.md` Stage A step 2's worry is unfounded both ways.** `draw()` is not behind
   `has_x`; `xschem redraw` runs clean under `--nogui` with `DISPLAY` unset; and the
   reproducer needs neither, because `kklex` refreshes the mirror.
9. **The issue's option-3 framing ("fixes the class everywhere")** omits that a `*`-aware
   hand-rolled arm still needs a bound on its own `nstr[50]`, i.e. it needs this clamp anyway.

## 11. Out of scope — named, not fixed, carried forward

* **`src/util.c`'s hand-rolled `my_snprintf`, the `g`/`e`/`f` arm: `char nstr[50]` filled by
  `sprintf(nstr, nfmt, i)` before anything checks the caller's `size`.** Any format whose
  *literal* precision can exceed ~40 digits overflows it and aborts. Today's tree passes only
  `%g`, `%.8g`, `%.10e`, `%.16g` — all safe — and no `my_snprintf` call uses `%f` (grep: none),
  so it is latent. Same class as 1606, different door. Wants its own number.
* **`src/scheduler.c:6263`**: `my_snprintf(res, S(res), "HAS_SNPRINTF=%s\n", HAS_SNPRINTF)` —
  an `%s` given an int, inside `#ifdef HAS_SNPRINTF`. Dead today; a one-word fix (`%d`); it is
  the cleanest available proof that the `vsnprintf` arm has never compiled.
* **The Tcl↔C ceiling drift.** 1602's `1..71` is a literal in `src/xschem.tcl` derived from
  `dtoa_eng`'s 80-byte buffer. `DTOA_ENG_BUFSIZE` fixes the C side's drift but not Tcl's; a
  `xschem get ev_precision_max` getter would. One line each side, but it is a new subcommand
  and belongs to whoever owns 1602's dialog.
* **No read-back seam for `xctx->ev_precision`.** `xschem globals` does not print it, so no row
  can assert what the C mirror holds. If Stage C wants to fence the *writers* behaviourally
  rather than statically, it needs one.

## 12. What I could not measure

* **Whether any of the twelve sites other than `dtoa_eng` (via `eval_expr`) can be driven to
  abort on the headless arm.** The four cursor readouts, the two `callback.c` tooltip sites
  and `show_node_measures` all need a graph rect plus either a draw or pointer events; I did
  not attempt them, because that is Stage A's remit and Stage A has not reported. Stage C
  should not assume they are drivable headless.
* **The cost of option 2's added malloc/free in the netlist and redraw inner loops.** Stated as
  a design cost, not a measurement — I did not benchmark it.
* **`graph_marker_fmt` driven through the `graph_marker text` verb.** I read the callers and
  the clamp but did not drive the verb; the §8 fencing plan for it is a proposal, not a
  measured route.
* **The exact garbage precision the hand-rolled arm picks up** is register state and varies by
  call shape (54 for the `1.111` shape, 0 for the `700.0` shape, both stable across six runs
  in this build). Not a portable number, which is the point.

## 13. Commands and scratch

All probes under the session scratchpad
`/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/b/`
(`probe.c`, `probe2.c`, `nstr.c`, `arith.c`, `ev*.tcl`, `mirror.tcl`, `g.tcl`). Nothing written
in the repo except this receipt. No `/tmp/xschem_emergencysave_*` touched. The `src/util.c`
`touch` + `make -C src` at the start was the evidence rebuild required by the brief; the tree
is byte-identical to `34913077`.
