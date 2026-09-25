# Receipt Bv — Stage B refutation crew, issue 1606

Tree `34913077`. Every binary run: `HOME=<scratchpad>/th timeout 60 env -u DISPLAY
./src/xschem --nogui --pipe -q --script <f>`. Every grep `/usr/bin/grep`. Scratch under the
session scratchpad. Nothing in the repo was modified — `git diff --stat` empty at start and
end, `git status --short` unchanged (the same three untracked paths).

⚠ **Process note first.** `src/xschem`'s mtime moved from `Sep 25 00:30` to `Sep 25 00:53`
**during** this stage, with `callback.o`, `draw.o` and `eval_expr.o` rebuilt at 00:53, from
sources `git diff` reports as unmodified, to a byte-identical binary size (1697360). I did not
build (my only `make` was `make -n`). Another process in this tree rebuilt under me. I re-ran
the load-bearing sweep on the post-00:53 binary and it is identical (negative `expr_eng`:
p=71 → 79 chars rc 0, p=72 → rc 134, p=73 → rc 134), and `make -n xschem` now says up to
date with no `.o` newer than the link. Every figure below is from the current binary. **The
driver should know a concurrent rebuild happened, because the brief's own rule is that a
binary changing under a measurement invalidates it.**

---

## 1. Outright refutations

### R1 — `draw_graph_variables` DOES exist. Crew contradiction #2 is false about the tree.

The crew wrote: *"PLAN.md's symbol `draw_graph_variables` DOES NOT EXIST."*

```
$ /usr/bin/grep -n 'draw_graph_variables' src/draw.c src/xschem.h
draw.c:4720:   * draw_graph_variables is shared by every graph in the tree including ~127
draw.c:5081:static void draw_graph_variables(int wcnt, int wave_color, int n_nodes, int sweep_idx,
draw.c:5175:        dbg(1, "draw_graph_variables(): h=%g, posh=%g, gh=%g\n", ...
draw.c:5353: * is the SAME arithmetic draw_graph_variables() uses to place the entries -- the
draw.c:9182:      draw_graph_variables(wcnt, wc, n_nodes, sweep_idx, flags, ntok, stok, bus_msb, gr);
xschem.h:1569: ... draw_graph_variables is shared with every embedded schematic
xschem.h:2379: ... reason no_grid is: draw_graph_variables/graph_point_at are
```

It is defined at `draw.c:5081`, called from `draw_graph` at `draw.c:9182`, and it holds its
own `char tmpstr[1024]` (`draw.c:5084`). `nm draw.o` shows only
`graph_marker_fmt.constprop.0` because `-O2` inlines the statics — which is why an nm-only
check cannot answer this question either way.

**What is actually true, and the driver should write this instead:** PLAN.md put the
1024-byte indirect-precision site in the wrong function. The `int prec =
xctx->ev_precision` + `fmt1="%.*e"` / `fmt2="%.*g%c"` site is in **`show_node_measures`**
(`draw.c:5225`, the conversions at `:5273`–`:5274`). `draw_graph_variables` sits immediately
above it, also owns a `tmpstr[1024]`, and has **no** indirect-precision conversion — which is
almost certainly how the mix-up happened. The citation correction stands; "the symbol does
not exist" does not.

### R2 — The fencing plan produces no row that reddens on either guard's removal.

The crew wrote: *"behavioural rows available at (a) the kklex writer — the headless
reproducer, rc 134 vs rc 0, **which reddens if either the eval_expr.y clamp or the dtoa_eng
clamp is removed**"*.

That cannot be true of two **redundant** clamps on one path, and the counter-measurement is
already in hand:

* **`eval_expr.y` clamp removed, `dtoa_eng` clamp present:** `ev_precision` arrives at
  `dtoa_eng` as 200; `dtoa_eng` clamps it to 71; the `sprintf` sees 71. Measured at 71:
  `rc=0`, 78 chars (positive) / 79 chars (negative). **Row green.**
* **`dtoa_eng` clamp removed, `eval_expr.y` clamp present:** `kklex` writes 71; `dtoa_eng`
  receives 71 and does not clamp; the `sprintf` sees 71. Measured at 71: `rc=0`, same
  strings. **Row green.**

```
p=71 rc=0 :: P=71 len=78 out=|1.0000000000000000076304735395750356605147783355117107507800866644399695e+288T|
NEG p=71 rc=0 :: len=79 out=|-1.00000000000000000763047353957503566051477833551171075078008666443996 95e+288T|
```

The reproducer reddens only when **both** clamps are gone. `CREW_BRIEF.md` requires *"Every
guard needs a row that reddens when the guard is removed"*; this plan delivers **zero** such
rows for the two guards it calls the fix, and the one behavioural row it offers fences the
pair, not either member. Stage C needs static rows for both, or an explicit statement that the
behavioural row is a pair-fence.

### R3 — The prescribed rewrite of `save.c`'s comment would put a NEW false claim in the tree.

The crew instructs Stage C to *"replace the unreproducible '1.111 printed as
1.111000061035156' with what was measured (the arm reads the double correctly, libc takes a
garbage precision, **the result overflows the arm's own `nstr[50]` and ABORTS**)"*, and calls
the existing comment an understatement: *"It costs the editor."*

`nd_view_set`'s format is **`"%.*g"`** — no `%c`, no literals. I built a probe from
`src/util.c` lines 641–768 extracted **verbatim by `sed`** (no transcription), `gcc -pipe -O2`,
and ran exactly that shape:

```
case=1 n=1 out=|1|        rc=0      (my_snprintf(out, 80, "%.*g", 4, 1.111))
run1..run8  rc=0 :: case=1 n=1 out=|1|      (8 consecutive runs, identical)
```

**No abort.** It costs a wrong number — precisely what the existing comment says. The abort
reproduces only for the `%.*g%c` shapes:

```
case=0 rc=134 :: *** buffer overflow detected ***: terminated   ("%.*g%c", 4, 1.111, 'x')
case=4 rc=134 :: *** buffer overflow detected ***: terminated   ("%.*g%c", 200, 1e288, 'T')
case=2 rc=0   :: n=8 out=|val=700|                              ("val=%.*g%c", 4, 700.0, 'm')
case=3 rc=0   :: n=6 out=|1.111x|                               (control, literal precision)
```

The crew's own finding — that the digits are register state — applies to their own escalation:
their probe's garbage precision was ~54, mine is ~1, and neither is a property of the shape.
If Stage C writes "and ABORTS" into `save.c`, the tree gains a false comment about a format
that does not abort. The honest replacement is *"libc takes a garbage precision, so what gets
printed is whatever that garbage produces — measured here as a single digit, `1`, for
`1.111`."*

### R4 — The rejection of a single constant rests on a site that does not exist.

The crew wrote: *"REJECTED: … a single %e-safe constant (it would give 70 at 80 bytes and put
the C ceiling one BELOW 1602's published dialog ceiling)."*

There is **no `%.*e` conversion into an 80-byte buffer anywhere in `src/`**. The complete set
of indirect-precision output conversions:

```
$ /usr/bin/grep -n '%[-+ #0]*\.\*' src/*.c src/*.y src/*.h
callback.c:2428, 2433      char sx[100], sy[100]      "%.*g%c"
draw.c:4967, 4999          char tmpstr[100]           "%.*g%c"
draw.c:5029, 5063          char tmpstr[100]           " %.*g%c "
draw.c:5268-5272           char tmpstr[1024]          "%.*e" / "%.*e%c" / "%.*g" / "%.*g%c"
draw.c:7750                dest (80 at all 4 callers) "%.*g%c"
editprop.c:182, 184, 186   static char s[80]          "%.*gMEG" / "%.*g%c" / "%.*g"
save.c:2904                char s[100]                "%.*g"
```

The only `%.*e` is `show_node_measures`' 1024-byte buffer. So a **single `%g`-derived constant
of 71** is safe at every one of the twelve: smallest buffer 80 → 71; every other buffer ≥ 100 →
cap ≥ 89; the `%e` path never sees a caller-supplied precision (R5). The 70-vs-71 objection
has no site behind it, and it is the objection the whole two-helper design was justified
against.

### R5 — The receipt says the `%e` branch forces `prec = 2` **and** that a `%g`-derived constant would under-protect it. Both cannot be true; half the helper pair is dead.

`draw.c`, `show_node_measures`:

```c
int prec = xctx->ev_precision;
...
if(yy != 0.0  && fabs(yy * gr->unity) < 1.0e-3) {
  prec = 2;
  fmt1="%.*e";
  fmt2="%.*e%c";
} else {
  fmt1="%.*g";
  fmt2="%.*g%c";
}
if(gr->unity != 1.0) sprintf(tmpstr, fmt2, prec, yy * gr->unity, gr->unity_suffix);
else                 sprintf(tmpstr, fmt1, prec, yy);
```

`prec = 2` is assigned **inside the same branch that selects `%.*e`**. A caller-supplied
precision can therefore never reach an `%e` conversion in this tree. Consequences:

* The crew's prescription `int prec = clamp_prec_e(xctx->ev_precision, S(tmpstr));` — and
  its justification *"`_e` because the branch below may select `"%.*e"`, the wider shape"* —
  protects nothing that `clamp_prec_g` would not.
* `clamp_prec_g` and `clamp_prec_e` are a **pair with one member that has no caller**. It
  would land untested, unexercised, and unfenceable (no row can drive an `%e` path with a
  caller precision, because none exists).
* And the g1_detail sentence *"a single %g-derived constant would under-protect it"* is
  false for the same reason.

---

## 2. Conclusions that are probably right but whose stated evidence does not support them

*(the driver will write these down either way — the evidence is thin)*

### E1 — "the clamp closes an out-of-bounds READ as well as the write": unreachable on the build it was measured on.

```
$ nm -u src/editprop.o | /usr/bin/grep -iE 'sprintf|chk'
                 U __sprintf_chk
                 U __stack_chk_fail
$ echo | gcc -pipe -O2 -dM -E - | /usr/bin/grep -i fortify
#define _FORTIFY_SOURCE 3
$ nm -u src/token.o | /usr/bin/grep -iE 'chk|memcpy'
                 U __fprintf_chk
                 U __stack_chk_fail
                 U memcpy
```

`dtoa_eng`'s `sprintf` into `static char s[80]` compiles to `__sprintf_chk` with the object
size known, so on the built binary the **write** aborts first, in `dtoa_eng`, before `n` is
assigned. `xctx->tok_size` is never updated and `token.c` is never reached. The OOB read
cannot be the outcome here.

It **is** real in a `./configure --debug` build. `scconfig/hooks.c`:

```c
if (istrue(get("/local/xschem/debug"))) {
        append("cc/cflags", " -g -O0 -Wconversion -Wno-sign-conversion");
        if (require("cc/argstd/Wall",  0, 0) == 0) { ... }
```

```
$ echo | gcc -pipe -O0 -dM -E - | /usr/bin/grep -i fortify      # → nothing
```

At `-O0` glibc defines **no** `_FORTIFY_SOURCE`. So a debug build writes silently past
`s[80]`, sets `tok_size` to 209, and `token.o`'s destination-unknown (therefore unfortified)
plain `memcpy` then reads 210 bytes out of an 80-byte static. **State the claim as
build-dependent and name the `--debug` build, or the sentence is false for the binary anyone
measures.** Corollary the crew did not draw: in a debug build the whole of 1606 is silent
corruption rather than a clean abort, which is strictly worse than what the issue reports.

### E2 — "which token.c x7 uses as a memcpy length": it is **5**.

Read by hand. Five sites do `len = xctx->tok_size;` then `memcpy(result+result_pos, valstr,
len+1)`: `token.c:6672, 6776, 6880, 6949, 7085`. The other two do not read `tok_size` at all —
`token.c:6131` copies with `my_strdup2` (strlen-based) and `token.c:6283` with `str_replace`.
The over-count of 2 is inside the sentence that carries the OOB-read claim (E1), i.e. in the
one clause most likely to be lifted into the commit message.

### E3 — "copy on the NEXT statement … with nothing in between but a dbg()": false at 6 of the 7.

`token.c:6283` — between the assignment and the use sit a `dbg`, a `str_replace(token,
"@spice_get_node ", "", 0, 1)`, a `my_strdup2`, another `dbg`, and an `if(n == 2 && sp ==
' ')` block that mutates `node`:

```c
6283      valstr = dtoa_eng(val, xctx->ev_precision);
6285    dbg(1, "valstr=%s\n", valstr);
6286    my_strdup2(_ALLOC_ID_, &token2, str_replace(token, "@spice_get_node ", "", 0, 1));
6288    dbg(1, "token2=%s\n", token2);
6289    if(n == 2 && sp == ' ') { node[len] = ' '; node[len + 1] = '\0'; }
6292    s = str_replace(token2, node, valstr, 0, 1);
```

The other five each have a `STR_ALLOC(&result, len + result_pos, &size)` — i.e. a
`my_realloc` (`xschem.h:781`) — between the `dtoa_eng` call and the `memcpy`.

**The headline conclusion survives**: I followed `my_strdup2`, `str_replace`, `my_realloc` /
`STR_ALLOC` and `draw_string`, and none of them appears in `dtoa_eng`'s 24-site caller set, so
none can re-enter it. But "nothing in between but a dbg()" is not what the code says, and it
is the entire evidence the option-2 verdict hangs on.

### E4 — "the MEG branch is prec+6, strictly narrower": right answer, wrong reason, and much stronger than stated.

On format arithmetic alone `"%.*gMEG"` is **wider** than `"%.*g%c"` — 3 literal bytes to 1, so
p+10 vs p+8 with the NUL. It is narrower only because the MEG branch divides by `1e6` first,
confining `|i|` to (0.999999, 999.999], where `%g` never selects exponential form and the width
is capped by the double's own exact decimal expansion rather than by the precision. Measured
(`expr_eng(-1.0000000000000002e7)`):

```
MEG p=71  rc=0 len=56 |-10.0000000000000017763568394002504646778106689453125MEG|
MEG p=74  rc=0 len=56    (same)
MEG p=75  rc=0 len=56    (same)
MEG p=76  rc=0 len=56    (same)
MEG p=200 rc=0 len=56    (same)
```

The MEG branch is safe at **any** precision — stronger than p+6, and resting on a different
fact. This matters for Stage C: "one clamp above the branch covers all three sprintfs" is
correct, but the binding branch is `"%.*g%c"` at 71, and if anyone later widens the MEG
branch's value range the p+6 figure becomes wrong while the reasoning as written gives no
warning.

### E5 — "scheduler.c:6263 WOULD SIGSEGV IMMEDIATELY": the macro's value was asserted, not checked.

Whether `my_snprintf(res, S(res), "HAS_SNPRINTF=%s\n", HAS_SNPRINTF)` segfaults or fails to
**compile** depends entirely on whether scconfig emits `#define HAS_SNPRINTF 1` or a bare
`#define HAS_SNPRINTF` (the latter makes that line `…, )`, a syntax error). I checked the
convention, which the crew did not:

```
$ /usr/bin/grep -n 'HAS_' config.h.in
29: print_ternary ?libs/tty/readline/presents {#define HAS_LIBREADLINE 1} {...}
35: print_ternary ?libs/gui/cairo/presents    {#define HAS_CAIRO 1} {...}
$ /usr/bin/grep -n '^#define' config.h
14:#define HAS_CAIRO 1   17:#define HAS_XCB 1   20:#define HAS_DUP2 1   23:#define HAS_POPEN 1
```

So it would be `1` and the conclusion holds. Note also that `my_snprintf` carries no
`__attribute__((format))`, so nothing diagnoses the `%s`-given-an-int at any warning level.

### E6 — the four-level `HAS_SNPRINTF` audit read `scconfig/hooks.c` and missed that it has a `-Wall` arm.

Not a defect in the conclusion (the audit's verdict is right, see §4), but the same file the
crew searched for `libs/snprintf` contains the `--debug` block at `hooks.c:277`ff that turns
on `-Wall -ansi -pedantic -Wconversion` **and** `-O0`. That block is the load-bearing fact for
both E1 and §3 below, and the receipt does not mention it.

---

## 3. (d) The recommended signature — a caller CAN get it wrong, and nothing catches it

`Makefile.conf:8`: `CFLAGS=-pipe -O2 -I/usr/include/cairo …` — **no `-Wall`, no `-W` of any
kind** in the default build. `xschem.h:536`: `#define S(a) (sizeof(a)/sizeof(a[0]))`.

Measured with the tree's own flags — **zero diagnostics for every wrong spelling**:

| call | returns |
|---|---|
| `clamp_prec_g(200, S(buf))`, `char buf[100]` | 91 — correct |
| `clamp_prec_g(200, S(p))`, `char *p` | **1** — silently one digit |
| `clamp_prec_g(200, (size_t)destsize)` with `destsize == -1` | 1 — safe by accident |
| `clamp_prec_g(S(buf), 200)` — **arguments swapped** | **100** — precision 100 into a 100-byte buffer |

```
$ gcc -pipe -O2 -o sig sig.c        # zero output
$ gcc -pipe -O2 -Wall -Wextra -Wconversion -pedantic -o swap swap.c   # zero output
correct: 91
swapped: 100
```

The **swap is undiagnosable at any warning level** — both operands are integers. `-Wall`
catches only the pointer case (`-Wsizeof-pointer-div`), and the shipped build has no `-Wall`.
So the recommended signature admits a silent re-opening of the exact overflow it exists to
close.

And the crew's own rejection reason turns on their own design: they rejected *"a single helper
with a numeric overhead argument (**the caller still counts and a wrong count is
invisible**)"*, yet prescribe `clamp_prec_g(xctx->ev_precision, S(tmpstr) - 2)` at two sites.
That **is** the caller counting, and I have just measured that the count is invisible.

**The contract as documented also produces the very off-by-one it rejected the alternative
for.** The crew documents `avail` as *"sizeof(buf) minus any literal bytes elsewhere in the
format"*, but the body subtracts 9, which already accounts for the one-byte `%c`. A future
caller who reads the contract literally and subtracts 1 for `dtoa_eng`'s `%c` gets **70** —
one below 1602's published dialog ceiling, i.e. exactly R4's complaint, arriving through the
recommended design instead of the rejected one.

### Two spellings that cannot be got wrong

1. **No size argument at all.** `#define EV_PREC_MAX (DTOA_ENG_BUFSIZE - 9)  /* 71 */` and
   `if(prec > EV_PREC_MAX) prec = EV_PREC_MAX;` at each site. Measured safe at all twelve
   (R4). Nothing to pass, nothing to swap, nothing to count; it is exactly the number 1602
   publishes, which is what the issue asks for (*"it makes the C side agree with 1602's
   dialog"*); and it makes the ceiling uniform across surfaces, which G2 already calls a
   benefit. Its one real cost — it does not auto-adapt if a buffer shrinks — is bought back by
   a static row asserting no buffer in the family is smaller than `DTOA_ENG_BUFSIZE`, which is
   a row the crew's design cannot have. C89 also forbids the variadic-macro escape hatches, so
   the constant is the only shape with no numeric argument at the call site.
2. If a size must travel, **pass the array, not a number**:
   `#define CLAMP_PREC_G(buf, prec) clamp_prec_g((prec), sizeof(buf))`. The macro fixes the
   order, so the swap becomes impossible; a pointer still degrades to 1 (safe-but-wrong).
   Strictly better than the bare two-argument function at no cost.

I am not asserting the single constant is the right answer — the sizeof-derivation argument is
genuine. I am asserting that the crew's **rejection** of it is unsound (R4, R5) and that its own
chosen shape carries a measured, undiagnosable failure mode the constant does not.

---

## 4. (e) The strongest case for what the crew rejected, and whether it survives

### Option 3 — teach the hand-rolled `my_snprintf` the `*`

**Strongest form.** After a clamp, all twelve sites still call bare `sprintf` into a fixed
buffer with an indirect precision: the pattern survives the fix, and the next reader has twelve
sites to re-audit rather than none. Option 3 deletes the pattern — every site becomes
`my_snprintf(buf, S(buf), "%.*g%c", prec, v, suffix)` and the **buffer** becomes the bound
instead of the precision. The crew's killer objection inverts into the case *for* it: they write
*"Option 3 does not remove the need for a clamp; it relocates it into a tree-wide function"* —
relocating twelve caller-supplied sizes into one function that owns one scratch buffer is the
same argument they used against the single constant, pointed the other way. It is also the only
option that fixes `graph_marker_fmt` without the caller having to remember anything.

**Verdict: does not survive**, for the crew's point 3 and only point 3. `my_snprintf`
**truncates**. Truncating `"%.*g%c"` amputates the exponent *and* the unit suffix, so
`1.0…e+288T` becomes `1.00000000000…` — a number wrong by 288 orders of magnitude that still
reads like a measurement. That is 1602's own headline failure class (its `4f` finding: *"nothing
raises … both print a different number that reads like a measurement"*). Clamping yields a
shorter but correct number. Reject as a replacement; worth its own issue as an addition — and
record that the reason is the user-visible output, not the blast radius.

### Option 4 — define `HAS_SNPRINTF`

**Strongest form.** The real blast radius is not 773 call sites, it is ~25 reviewable things:
5 return-value consumers, `scheduler.c:6263`, the `alert_`-on-truncation behaviour change, and
~17 format-difference sites. And it fixes a whole class — `%ld`, `%lu`, `%zu`, `%%`, widths and
flags are all silently mishandled today, and truncation is silent at `dbg(1)`.

**Verdict: does not survive — but for a simpler and firmer reason than the crew gives.**
**`dtoa_eng` does not call `my_snprintf` at all.** It calls bare `sprintf` (`editprop.c:182,
184, 186`). So option 4, *as stated*, changes nothing whatsoever at the site 1606 is about. The
crew's reason — *"with the real vsnprintf, dtoa_eng's `my_snprintf(s, S(s), "%.*g%c", 200, …)`
truncates safely AND RETURNS 209, which lands in xctx->tok_size"* — describes a rewrite of
`dtoa_eng` that option 4 does not include; there is no such call in the tree. Right verdict,
invented evidence.

The genuinely decisive facts are the two I verified: option 4 leaves 1606 untouched, and it
converts three truncation-safe accumulators into overflows. Both accumulators read in full:

```c
/* hilight.c publish_net_hilight_styles_to_tcl */
sz = (size_t)n * 40 + 1;
for(i = 0; i < n; ++i)
  off += my_snprintf(s + off, sz - off, "  {%d %d 1 {} 0 0 none 0}\n", ...);
/* token.c, @spice_ignore pin name */
tmp = strlen(str_ptr) + 100;
STR_ALLOC(&result, tmp + result_pos, &size);
result_pos += my_snprintf(result + result_pos, tmp, "%s", str_ptr);
```

The five return-value consumers, counted myself and matching the crew: `editprop.c:196`
(`dtoa_prec`), `hilight.c:596`, `token.c:6554`, `util.c:791` (`my_itoa`), `util.c:800`.

**One ABI caution the crew's option-4 reasoning misses.** They adjudicate
`graph_marker_fmt`'s comment (*"made it consume the int `prec` AS THE DOUBLE"*) as WRONG and
tell Stage C to correct it. On x86-64 SysV it is wrong and I reproduced why — the integer and
SSE argument areas are separate, so `case=2` gives `|val=700|` with the `'m'` replaced by
`\004` (the `%c` arm's `va_arg(args,int)` eats `prec`). But `XSchemWin/` exists and this
codebase targets Windows, where Win64 varargs use **one** argument area — so the arm's first
`va_arg(args, double)` reads the `int prec`'s bytes as a double there, exactly as the comment
says. The claim is **ABI-dependent**. Correcting it to "the double arrives intact" would make
it false on the platform the original author may have measured on; the correction must say *on
x86-64 SysV*.

---

## 5. What I attacked and could not break

* **(a) Which `my_snprintf` arm compiles — confirmed by two means the crew did not use.**
  `nm -S src/util.o`: `my_snprintf` is `0x64f` = **1615 bytes** (the 12-line vsnprintf arm
  cannot be that). `nm -u src/util.o` lists `__sprintf_chk`, `__strncpy_chk`, `__memcpy_chk`
  — the hand-rolled arm's exact calls — and **no** `vsnprintf` or `__snprintf_chk` at all.
  Preprocessor with the tree's exact CFLAGS: exactly one definition survives,
  `size_t my_snprintf(char *string, size_t size, const char *format, ...)` at `util.i:20970`
  with `const char *f, *fmt`, 3 × `nstr[50]`, and no `vsnprintf` call anywhere above the stdio
  declarations. `util.c:500`'s comment is correct.
* **Its behaviour on `%.*g` — reproduced from verbatim-extracted source**, all four of the
  crew's cases (see R3 for the one reading that does not hold).
* **The ceiling is exactly 71, and the sweep and the arithmetic agree — now including the
  negative worst case, which the crew asserted rather than drove.** Positive
  `expr_eng(1e300*1.0)`: p=4 → 7 chars, p=70 → 76, **p=71 → 78, p=72 → 79 (rc 0), p=73 → rc
  134, p=200 → rc 134**. **Negative** `expr_eng(-1e300*1.0)`: **p=71 → 79 chars rc 0, p=72 →
  rc 134.** So 71 is exactly the last safe value, and 1602's *"the worst case needs one byte
  more than 72 leaves"* is now measured, not only derived. `"%.*g%c"` worst case = p+8 chars,
  p+9 with the NUL → cap = size − 9 → 71 at 80 bytes.
* **The third writer, `eval_expr.y` `kklex`, and that it is the reproducer's path.**
  `xctx->ev_precision = tclgetintvar("ev_precision")` is the **first statement** of `kklex()`,
  unconditional, once per token. My reproducer aborts with `DISPLAY` unset, `--nogui`, and
  nothing between `set ev_precision 73` and `xschem eval_expr` — no `draw()`, no
  `draw_graph()`. PLAN.md's and G1's "exactly two/three writers" miss it, and it lives in a
  generated file (`src/eval_expr.c` untracked, regenerated by bison), so the edit belongs in
  the `.y` and a static row must grep the `.y`. **This is the crew's most valuable finding and
  it holds.**
* **`draw()`'s write is unconditional** — `draw.c:10595`, one line below the single-statement
  `if(has_x) tk_scaling = atof(tcleval("tk scaling"));`, not inside it. G1's stated refutation
  route is closed.
* **The site list is complete — there is no thirteenth site.** The `%.*` grep above is
  exhaustive, and there is no runtime-assembled format string: every `%%` hit in `src/*.c` is a
  PostScript literal in `psprint.c` plus the bison `%%` separators in `eval_expr.y` /
  `expandlabel.y`.
* **24 `dtoa_eng` call sites, not 27 and not ~70** — counted myself: callback 6, draw 10 (the
  11th `dtoa_eng(` hit is the `/* dtoa_eng() returns a SHARED static buffer */` comment),
  editprop 0 (the definition plus a `dbg` format string), `eval_expr.c` 1, token 7. By
  precision argument: **13** pass `xctx->ev_precision`, **8** pass a literal 5, **2** pass
  `prec`, **1** passes `engineering`. *(PLAN.md's "15 pass `xctx->ev_precision` (token.c ×7,
  callback.c ×6, eval_expr.c)" is 13, and its own three addends sum to 14. The crew did not
  catch this one.)*
* **(c) Zero of the 24 hold the pointer across a call that could re-enter `dtoa_eng`.** Read
  all 24: 17 are in argument position (`my_strncpy` ×2, `tclvareval` ×4, `draw_string` ×4,
  `my_snprintf` ×7), and `token.c`'s 7 assign to a `const char *valstr` consumed within the
  same block. I followed `my_strdup2`, `str_replace`, `my_realloc`/`STR_ALLOC` and
  `draw_string`: none appears in `dtoa_eng`'s caller set. The verdict *"option 2 is not
  blocked by the static-buffer contract"* survives; see E3 for the evidence that does not.
* **One clamp above `dtoa_eng`'s branch does cover all three `sprintf`s** — verified by
  arithmetic and by the MEG measurement (E4): `"%.*g"` needs cap 72, `"%.*g%c"` 71,
  `"%.*gMEG"` unbounded-safe. 71 binds.
* **`nd_view.prec` has exactly one writer** (`save.c:3093` in `ngspice_data_arm`) with exactly
  two callers (`callback.c:1507` passing `xctx->ev_precision`, `save.c:3848` passing 4).
* **`engineering` has exactly three writers**, all in `kklex`: `0`, `xctx->ev_precision`, `4`.
* **`graph_marker_fmt` is latent, not live** — all four callers pass `S(sx)` on `char sx[80]`
  and sit below `if(prec > 17) prec = 17;` in `graph_marker_text_rec`.
* **`libs/snprintf` machinery** — offered in `scconfig/src/default/deps_default.c:77`, never
  requested in `scconfig/hooks.c`, no line in `config.h.in`, no match in `config.h`. Confirmed.

---

## 6. Out-of-scope defects found, NOT fixed, carried forward

### 6.1 The graph measurement tooltip's `sy` branch is selected by the **X** axis unit

`src/callback.c`, inside `if(xctx->graph_flags & 64)` — the two lines Stage C is told to edit:

```c
      if(gr->unitx != 1.0)
        sprintf(sx, "%.*g%c", xctx->ev_precision, gr->unitx * xval, gr->unitx_suffix);
      else
        my_strncpy(sx, dtoa_eng(xval, xctx->ev_precision), S(sx));

      if(gr->unitx != 1.0)                                      /* <-- should be gr->unity */
        sprintf(sy, "%.*g%c", xctx->ev_precision, gr->unity * yval, gr->unity_suffix);
      else
        my_strncpy(sy, dtoa_eng(yval, xctx->ev_precision), S(sy));
```

* `unity != 1.0` with `unitx == 1.0`: the y readout goes through `dtoa_eng` and **loses
  `gr->unity` entirely** — a tooltip wrong by the unit factor, presented as a measurement.
* `unitx != 1.0` with `unity == 1.0`: `gr->unity_suffix` is 0, so `%c` writes a NUL and the
  string terminates at the digits.

The crew did not find this while prescribing an edit to these exact lines. **Name it; do not
silently fix it** — it is a behaviour change on a user-visible readout and wants its own number
and its own row.

### 6.2 A `./configure --debug` build has no `_FORTIFY_SOURCE`

Measured in E1. Every "the process aborts cleanly" statement about 1606 — in the issue, in
1602 §1, in PLAN.md and in receipt B — is a statement about the **`-O2`** build. At `-O0` the
same overflow is silent corruption, and `token.o`'s unfortified `memcpy` then compounds it.
Not this issue's to fix, but any write-up that says "aborts" should say "aborts on the default
`-O2` build".

### 6.3 `src/util.c`'s hand-rolled `my_snprintf` `nstr[50]` — confirmed, and reachable through `%c` too

The crew named the g/e/f arm's `char nstr[50]`. Note the `d/x/c/u` and `p` arms have their own
`char nfmt[50], nstr[50]` with the same unchecked `sprintf(nstr, nfmt, i)`, and `nfmt` is
filled by `strncpy(nfmt, fmt, l)` where `l = f - fmt + 1` is **the caller's spec length with no
bound** — a format containing a conversion spec longer than 49 characters overruns `nfmt`
before `nstr` is ever reached. Latent (no shipped call has one). Same class, different door;
wants its own number, and it belongs with 6.2 because a debug build would not catch it either.

---

## 7. What I could not measure

* **Whether the four cursor readouts, the two `callback.c` tooltip sites and
  `show_node_measures` can be driven to abort at all.** They need a graph rect plus a draw or
  pointer events; that is Stage A's remit and receipt A exists now. So receipt B's
  user-visible claim — *"the cursor readouts and the annotation publisher show the same
  71-digit shape rather than their own 89 / 91 / 1014 ceilings"* — is **unmeasured** on both
  sides, before and after.
* **`graph_marker_fmt` through the `graph_marker text` verb.** I read the callers, the
  `destsize`s (80 at all four) and the `≤ 17` clamp, but did not drive the verb. The crew did
  not either.
* **Option 2's added `my_malloc`/`my_free` in the netlist and redraw inner loops.** Not
  benchmarked by the crew or by me; it is a design cost, stated as one.
* **The `--debug` build's behaviour end to end.** I measured that `-O0` carries no FORTIFY and
  that `hooks.c` selects `-O0` for `--debug`; I did **not** configure and build that arm, so
  the OOB read of E1 is derived from the two measured facts plus the code, not driven.
* **`clamp_prec_e`'s `avail - 10` arithmetic.** There is no code path in this tree that could
  exercise it (R5), so it cannot be measured through the binary at all.
