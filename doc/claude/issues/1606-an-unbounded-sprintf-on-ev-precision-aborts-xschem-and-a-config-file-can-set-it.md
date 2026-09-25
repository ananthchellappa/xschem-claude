# 1606 — an unbounded `sprintf` on `ev_precision` aborts xschem, and a config file can set it

**STAMP:** `v1 claim=fixed tree=3491307772a stamped=2026-09-25 fix=taken open=0 by=driver`

**Status: FIXED 2026-09-25.** Every section below the horizontal rule is the ORIGINAL
filing, kept verbatim so the corrections can be read against it; **four of its claims were
measured wrong and are corrected in "What the measurement round found" at the end.**
Originally filed 2026-09-22 by the driver, from the 1602 crew's measurement and
its explicit *"this wants a number and a crew"*. **Class** memory safety — an unbounded
`sprintf` with an indirect precision into a fixed buffer.
**Related, read first:** **1602** (the precision dialog now refuses anything outside
1–71 — **FIXED** in `63558796`; **its ceiling of 71 comes from this defect**, and the
dialog is only one of the ways `ev_precision` gets set).

---

## The defect — MEASURED

`dtoa_eng` in `src/editprop.c`:

```c
char *dtoa_eng(double i, int precision)
{
  static char s[80];
  ...
    /* can not use my_snprintf() here due to indirect precision */
    if(suffix == 'M')
      n = sprintf(s, "%.*gMEG", precision, i);
    else
      n = sprintf(s, "%.*g%c", precision, i, suffix);
  ...
}
```

`precision` arrives from `xctx->ev_precision`, which C reads with `tclgetintvar` —
`atoi()`, so it never raises and never validates. The buffer is 80 bytes and there is no
bound. The comment is honest about why `my_snprintf` is not used (it does not understand
the `*` precision) and stops there.

MEASURED by the 1602 crew on the shipped binary:

```
ev_precision=72   xschem eval_expr {expr_eng(1e300*1.0)}  -> 79 chars, survives
ev_precision=73   xschem eval_expr {expr_eng(1e300*1.0)}  -> *** buffer overflow
                                                             detected ***: terminated
```

SIGABRT, rc 134. The sweep taken was 71 → 78 chars, 72 → 79, and 73, 74, 75, 80, 90, 99,
100, 200, 400 and 1000 all abort. The arithmetic worst case — a negative value in the same
`1e12` branch, with a three-digit exponent — needs one byte more than 72 leaves, which is
why **71** is the largest value anyone has proven safe and why 1602's dialog stops there.

## Why 1602 does not close it

1602 validates **the dialog**. `ev_precision` is an ordinary Tcl global, and the dialog is
not the only writer:

* **`~/.xschem/xschemrc`.** A line `set ev_precision 200` in a user's own rc file reaches
  the variable without passing through any dialog. That is a **startup-time landmine**:
  nothing goes wrong until a value lands in the `1e12` branch, and then the process
  aborts.
* **`--preinit 'set ev_precision N'`**, which the test suites themselves use (issue 1345
  records it).
* **Any Tcl** — a `tcleval` property on a schematic, a helper script, a menu hook.

So the fix belongs in C, at the point of use, not in any one writer.

## Two more sites, and they are not equally bad — READ at `63558796`

| site | shape | verdict |
|---|---|---|
| `src/draw.c` ×2 (near `:4933` and `:4995`, the cursor readout) | `sprintf(tmpstr, "%.*g%c", xctx->ev_precision, …)` into `char tmpstr[100]` | **Same defect, wider buffer.** Unclamped `ev_precision` straight from `xctx`. Overflows later than 80 bytes does, not never. |
| `src/draw.c` `graph_marker_fmt` (`:7716`) | takes `int destsize` and then `sprintf`s past it, ignoring it | ⚠ **Not currently exploitable, and the issue should say so.** All four of its callers (`:7830`, `:7831`, `:7846`, `:7847`) sit in one function, below `if(prec > 17) prec = 17;` at `:7810`, with a comment saying that is exactly why. It is a **latent** hazard: a fifth caller added without the clamp reintroduces it, and the signature invites one by taking a `destsize` it does not honour. |

The 1602 crew reported the third as live. Re-reading it here, it is not — the clamp is
there and documented. Recorded that way rather than inherited, because an issue that
overstates one of its three sites gets the other two discounted with it.

## The shape a fix takes

The comment's premise — that `my_snprintf` cannot do `%.*g` — is the constraint, not the
conclusion. At least three ways past it, and the choice needs measuring rather than
picking:

1. **Clamp at the point of use.** One line in `dtoa_eng`, and the same in the two `draw.c`
   sites. Cheapest, and it makes the C side agree with 1602's dialog instead of merely
   not crashing. ⚠ It also **silently changes** what a user with `set ev_precision 200` in
   their rc sees, which is a behaviour change on an obscure path and should be stated, not
   slipped in.
2. **Size the buffer from the precision** — compute the worst case and `my_malloc`. Removes
   the ceiling instead of enforcing it, at the cost of `dtoa_eng`'s `static char` contract,
   which ~70 call sites rely on by holding the result as a `const char *`.
3. **Give `my_snprintf` the `*` precision.** Fixes the class everywhere rather than three
   sites, and is the largest change. `graph_marker_fmt`'s comment records what happens
   today when someone assumes it already works: the house `my_snprintf` consumed the `int`
   as the `double` and produced
   `700.0000000000001136868377216160297393798828125` with the suffix swallowed.

**Recommendation: 1, and open a second issue for 3.** Clamping is the only one of the
three that can land today without a redesign, and the disagreement it leaves — a user's rc
asking for 200 and getting 71 — is smaller than the process aborting.

## Still open

1. Fix `dtoa_eng`, and the two `draw.c` cursor-readout sites with it. They share the
   defect and a fix to one alone leaves a live one.
2. Decide and state what an out-of-range `ev_precision` from a non-dialog writer should
   do — clamp silently, clamp and warn once, or refuse at startup. 1602 chose "refuse and
   say why" for the dialog on the grounds that silence is the original defect; the same
   argument does not automatically carry to a config file read before there is a window
   to put a message in.
3. A test row. Cheap and headless: set `ev_precision` past the ceiling by `--preinit`, ask
   for a value in the `1e12` branch, and assert the process survives with a sane string.
   ⚠ It must assert on the **exit code**, not only the output — the failure mode is
   SIGABRT, and a suite that only diffs text would read the death as an empty answer.
4. `graph_marker_fmt` should either honour its `destsize` or stop taking one. Latent, not
   live; do it with item 1 while the file is open.

---

# What the measurement round found, 2026-09-25 — and four of this issue's claims were wrong

Eight crews across four rounds, every receipt in `doc/claude/issue_1606_batch/receipts/`. The
fix landed as one helper plus arithmetic in seven files, fenced by
`tests/headless/test_ev_precision_bound_1606.tcl`. **Read this section before trusting anything
above it.**

## Correction 1 — THREE sites is THIRTEEN, and six were in files this issue never names

The table above lists `dtoa_eng`, `draw.c` "×2", and `graph_marker_fmt`. A sweep for every
indirect-precision conversion in the hand-written sources finds **thirteen `sprintf`
statements**, in four files:

| site | buffer | in this issue? |
|---|---|---|
| `dtoa_eng` ×3 (`editprop.c`) | `static char s[80]` | yes |
| `draw_cursor`, `draw_cursor_difference` (`draw.c`) | `tmpstr[100]` | yes, as "×2" |
| `draw_hcursor`, `draw_hcursor_difference` (`draw.c`) | `tmpstr[100]` | **no** |
| `show_node_measures` ×2 (`draw.c`) | `tmpstr[1024]` | **no** |
| `waves_callback` ×2 (`callback.c`) | `sx[100]`, `sy[100]` | **no** |
| `nd_view_set` (`save.c`) | `s[100]` | **no** |
| `graph_marker_fmt` (`draw.c`) | `dest`, `destsize` ignored | yes, as latent |

Two smaller counts here are also wrong: `dtoa_eng` has **24** call sites, not the "~70" issue
1602 claims (13 pass `xctx->ev_precision`, 1 passes `engineering`, 8 pass a hardcoded 5, 2 pass
a clamped `prec`); and *"`draw.c`'s `char tmpstr[100]` overflows at 92"* is right for two of the
four `draw.c` cursor sites and **off by two** for the other two, whose format `" %.*g%c "`
carries two literal spaces.

## Correction 2 — a FOURTH writer, and it is the one this issue's own reproducer goes through

`xctx->ev_precision` is written in four places, not the three implied. Besides `xinit.c`'s
initial `4` and the `tclgetintvar` reads in `draw()` and `draw_graph()`, **`kklex()` in
`src/eval_expr.y` assigns it unconditionally, once per lexer token.** That is the writer
`xschem eval_expr {expr_eng(...)}` uses — so a clamp at the two `draw.c` sites would have left
this issue's own reproducer aborting. Proved by sabotage: comment that one line out, rebuild,
and `ev_precision=200` prints `1e+288T` at precision 4 with rc 0. ⚠ `src/eval_expr.c` is
**generated and gitignored**, so the fix is in the `.y` and the static row greps the `.y`.

Two more writer *paths* are missing from the list above as well, both confirmed aborting: a
**`./xschemrc` in the current directory**, which outranks the user's own rc file and is how a
PDK or design kit would carry this; and **`--rcfile <path>`**, which is honoured even in-tree.
⚠ And a trap for anyone writing a test: an `~/.xschem/xschemrc` row run **in-tree measures
nothing**, because `xinit.c` gates both `./xschemrc` and `$USER_CONF_DIR/xschemrc` behind
`if(!running_in_src_dir)`.

## Correction 3 — THE ABORT IS FILE-BORNE, so this issue's severity is understated

The three writers above are all the local user's own configuration, and this issue's title says
*"a config file can set it"*. That is too narrow. **A `.sch` or `.sym` written by anyone else
can set it**, and the abort follows:

* a `.sch` with a `floater=true` (or `name=`) `T` record whose value is
  `tcleval([set ::ev_precision 200]...)` — on a display, **`xschem load` alone** is enough,
  because the load draws and the draw evaluates the floater; headless it takes one more step
  such as `xschem print svg`;
* a `.sym` whose `format=` attribute is a `tcleval(...)` — this one fires through plain
  **`xschem netlist`**, with no display and no export at all. The emitted SPICE line was
  literally `222* poisoned by a symbol format`.

And `main.c`'s `sig_handler` traps SIGINT, SIGSEGV, SIGILL, SIGTERM and SIGFPE but **not
SIGABRT**, so the fortify abort bypasses the emergency save entirely. Checked after ~40 driven
aborts: no `/tmp/xschem_emergencysave_*` at all.

⚠ **THE HONEST HALF, AND IT MUST BE READ WITH THE ABOVE.** The mechanism is `tcl_hook2`
(`token.c`) → `tclpropeval2` (`xschem.tcl`) → `uplevel #0 "subst \{$s\}"`, and `subst` performs
**command** substitution at global level. That is arbitrary Tcl execution from a file, of which
`ev_precision` is one target among unlimited others; `save.c` additionally passes an instance
**name** through `tcl_hook2`, and runs generator symbols through `popen()`, i.e. a shell.
**Fixing 1606 does not make opening a stranger's schematic safe**, and this fix must not be read
as a security fix. Carried forward below.

## Correction 4 — option 3 is not merely the largest change, it is blocked by the build

The recommendation above says option 3 "fixes the class everywhere … and is the largest change".
Measured, it is worse than that:

* **`HAS_SNPRINTF` is defined nowhere in this tree** — not in `config.h`, not in `config.h.in`,
  never probed by `scconfig`, no `-D` on the compiler line, and `xschem globals` prints no such
  line. Confirmed independently by `nm -S src/util.o` (`my_snprintf` is 1615 bytes, which the
  12-line `vsnprintf` arm cannot be) and `nm -u` (`__sprintf_chk`, `__strncpy_chk`,
  `__memcpy_chk`, and **no `vsnprintf`**). So `my_snprintf` is the **hand-rolled** formatter.
* Its float arm does `nlen = sprintf(nstr, nfmt, i);` into `char nstr[50]` **with the bound test
  after the write**. So teaching it a `*` precision cannot be done without adding a clamp
  *inside the formatter* — option 3 relocates this fix rather than replacing it.
* And the outcome at these sites would be **worse**: `my_snprintf` truncates, so a number would
  arrive cut mid-digit with its exponent and suffix amputated, where a clamp gives a shorter but
  complete number.

⚠ The comment this issue quotes as evidence — `graph_marker_fmt`'s *"consumed the `int` as the
`double`"* — **is wrong on x86-64 SysV**, where the integer and SSE argument areas are separate:
driven, the double arrives intact (700, 1.111) and it is the **suffix** that is eaten (`'m'`
emitted as `\004`). It would hold on Win64, which uses one argument area, and `XSchemWin/` exists
— but no Windows build was made here, and the figure it quotes carried no platform at
`63558796`. The shipped comment now says which half is measured and which is derived.

A **fourth option** this issue does not list — defining `HAS_SNPRINTF` to get the real
`vsnprintf` arm — was costed and **rejected, because it would introduce a 1606-class defect at
more sites than it fixes.** The hand-rolled arm returns bytes *written*; `vsnprintf` returns
bytes that *would have been*. Five sites consume that return as a length and three accumulate it
(`off += my_snprintf(s + off, sz - off, ...)`), where `off` can pass `sz` and hand a negative
`sz - off` to a `size_t`. And `scheduler.c`'s `my_snprintf(res, S(res), "HAS_SNPRINTF=%s\n",
HAS_SNPRINTF)` gives `%s` an int — dead today inside the `#ifdef`, and the cleanest available
proof that the `vsnprintf` arm has never been compiled by anyone, on any platform.

## What was CONFIRMED, including the ceiling

**71 is exactly right, and the arithmetic and the sweep now agree.** Worst case for `"%.*g%c"`
is `prec+8` characters, so `prec+9` bytes with the NUL: cap = `bufsize − 9` = **71** at 80 bytes.
Driven both signs: at 71 the widest of all twelve `dtoa_eng` branches is 79 characters — the
buffer exactly full — and 72 aborts for a negative value. Re-derived by hand and by exhaustive
search over precision 0–4000 against 27 extreme doubles, agreeing in every cell.

⚠ **An `ev_precision` of `2147483648` is SAFE while 73 is not**: `atoi` overflows to
`-2147483648`, and C treats a negative `*` precision as omitted.

**A bound worth writing down, which decides every 1024-byte concern:** `%.*g` can never exceed
**774 characters at any precision**, because a double's exact decimal expansion holds at most 767
significant digits and `%g` strips trailing zeros. `%.*e` **zero-pads** and therefore grows
without limit — so `show_node_measures`, the tree's only `%.*e` pair, is the reverse of what its
buffer size suggests, and is safe today only because `prec = 2` is assigned three lines above it.

## A SECOND DEFECT, at one of this issue's own sites

`waves_callback`'s graph measurement tooltip guarded its y readout on `gr->unitx != 1.0` while
the body formatted `gr->unity * yval` with `gr->unity_suffix` — **the guard named the x unit and
the body used the y unit.** A graph with `unity=T` and no `unitx`, an ordinary configuration,
therefore routed the y readout through `dtoa_eng`'s 80-byte static instead of its own 100-byte
buffer, which is why *that* readout's abort threshold was **73 rather than 93**; and `unitx=T`
alone formatted the y value with `unity == 1.0` and `unity_suffix == 0`, so `sprintf` wrote a NUL
where a suffix belonged and the suffix simply vanished (`y=5.011\nx=4.439e-13T`).

Fixed here, because it is at a site this issue owns and it moves this issue's own threshold. It
is **user-visible in two of six graph configurations** (`y=5.011` → `y=5.011e-12T` with a y unit
and no x unit), so it is filed as **`rule/1606_graph_y_unit`** for the user, with rows `D3` and
`D4` pinning whichever answer comes back.

## A hole gcc found that four rounds of sweeps could not

The first landed fix clamped once above `dtoa_eng`'s branch, at `avail − 9` = 71. `gcc` then
warned — `'__builtin___sprintf_chk' may write a terminating nul past the end of the destination`
— and **it was right**: `"%.*gMEG"` needs `prec+11` bytes, and 71+11 = 82 in an 80-byte buffer.
No sweep in four rounds could find it, because that branch divides by `1e6` first and its output
is pinned near 59 characters at *any* precision (driven to 4000, both signs, 1.6M calls: max 59).
So a **static bound was violated while no runtime probe could ever show it.** The MEG conversion
now carries its own clamp at `avail − 11` (cap 69); the suffix and bare arms keep 71, so the C
ceiling still matches 1602's published `1..71`. Measured across 192 driven strings: **byte
identical**, and the tree is warning-identical to `34913077` (6 pre-existing
`-Wdiscarded-qualifiers` in both).

That warning also supplied the strongest fence in the batch — a row that compiles the sources and
asserts **zero `-Wformat-overflow` diagnostics**. No decoy can fool the compiler's own opinion of
these formats, which is what four rounds of hand-written static rows kept failing to do.

## Answering the four "Still open" items

1. **`dtoa_eng` and the `draw.c` sites** — done, and eleven more with them. One helper
   `clamp_prec_g(prec, avail)` (cap `avail − 9`, `prec <= 0` returned unchanged so 0 keeps
   meaning "engineering off"), a `DTOA_ENG_BUFSIZE` macro so **no literal 71 exists in C**, and
   clamps at all thirteen use sites plus the three unclamped writers.
2. **What an out-of-range value should do** — clamped, and **filed as `rule/1606` for the user**
   rather than decided here. The recommended shape shipped: clamp per buffer, writers at 71 so
   one number is visible everywhere. ⚠ The alternative, *refuse and say why*, was costed and is
   worse **here** for a reason 1602 did not face: the message would have to fire from `draw()`
   **and** from `kklex()`, a bison lexer reached during netlisting, so there is no quiet place to
   put it. ⚠ And the clamp is on the **C mirror only** — `to_eng` and the annotation sheet still
   `format %.200g`, so C and Tcl still disagree for an out-of-range rc value. That is 1602's
   residue, not this fix's.
3. **A test row** — `tests/headless/test_ev_precision_bound_1606.tcl`, in `hcases`, with
   behavioural rows asserting **rc 134 specifically** (not merely "not zero") and the static
   fences described below. ⚠ The issue's warning about the exit code was right and did not go far
   enough: the suite's `FATAL: signal` check is **permanently inert for this defect**, because
   SIGABRT is not trapped, so no column-0 death marker is ever printed. Read the `rc=` field.
4. **`graph_marker_fmt`'s `destsize`** — now honoured, so the signature stops lying. ⚠ And this
   issue calls it *"not currently exploitable … latent"*, which is right about reachability and
   understates the consequence: with its clamp removed and the caller's `17` raised, the overflow
   **does not abort**. `dest` is a pointer parameter, so `_FORTIFY_SOURCE` cannot size it and
   emits no check; the `sprintf` ran off an 80-byte buffer into the adjacent one in the same stack
   frame and produced a spliced 279-digit string, rc 0, no signal. **Every other site in this
   issue is a loud abort; that one is silent corruption.**

## Carried forward — named, not fixed, no numbers minted

1. **`my_snprintf`'s own `g`/`e`/`f` arm** writes `sprintf(nstr, nfmt, i)` into `char nstr[50]`
   and checks the bound afterwards — three arms, same class as this issue, in the formatter the
   whole tree uses. Latent: every live float caller is ≤ 24 characters.
2. **Arbitrary Tcl from a `.sch`/`.sym`, and arbitrary shell from a generator name.** See
   Correction 3. Much larger than this issue and the reason this abort is file-borne.
3. **Tcl↔C ceiling drift.** 1602's `1..71` is a literal in `src/xschem.tcl`. `DTOA_ENG_BUFSIZE`
   fixes the C side; an `xschem get ev_precision_max` getter would fix Tcl's.
4. **No read-back seam for `xctx->ev_precision`** — `xschem globals` does not print it, so no row
   can assert what the C mirror holds.
5. **Several shapes are out of reach of any static row in the suite, and no count of them is
   claimed** — which is itself the lesson. Five consecutive hardening rounds each shipped a
   sentence saying how many escaped, and a crew refuted the number every time: round two found
   four spellings that left the suite green on a tree with the real guard deleted, round three
   found eleven more, and the round that wrote *"one shape is still out of reach"* had three more
   sitting in the tree. A static row over C text decides a **set of spellings**, never a property
   of the program, so the honest form is a named list that may grow. The driven ones are listed in
   the suite's own header under NAMED LIMITS; the widest is a `%.*` split across adjacent string
   literals (`sprintf(b, "%." "*g", p, v)`), which C joins in translation phase 6 — invisible to
   the suite **and** to `make`, because the build's own `-Wformat-overflow` level says nothing
   about a `%.*g` whose precision gcc cannot range. The fences without this weakness are the
   behavioural rows and the compiler-diagnostic rows, and the general remedy this tree lacks is a
   read-back seam (`xschem get ev_precision`) so a row could assert what the C mirror actually
   holds.
