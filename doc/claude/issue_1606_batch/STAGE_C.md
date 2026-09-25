# Stage C — the implementation brief, with every Stage A/B claim already adjudicated

Read `CREW_BRIEF.md` first, then this. **This file supersedes `PLAN.md`'s Stage C section and
`DECISIONS.md` G1/G2 wherever they disagree** — the four Stage A/B crews measured both wrong
in places, and the adjudications below are the driver's, made after reading all four receipts.
Do **not** re-derive the measurements; they are in `receipts/`.

## What is settled, and must not be re-litigated

| fact | where measured |
|---|---|
| The abort is `*** buffer overflow detected ***: terminated`, SIGABRT, **rc 134**, and `main.c`'s `sig_handler` does **not** trap SIGABRT — so no emergency save. | `A`, `Av` |
| `xctx->ev_precision` has **four** writers: `xinit.c` (the constant 4), `draw.c` in `draw()`, `draw.c` in `draw_graph()`, and **`kklex()` in `src/eval_expr.y`** — the last is unconditional, runs once per lexer token, and is the one the issue's own reproducer goes through. | `A`, `B`, `Av`, `Bv` |
| `src/eval_expr.c` is **generated and gitignored**. Edit `src/eval_expr.y`. A static row must grep the **`.y`**, because the `.c` does not exist in a fresh clone before a build. | `B`, `Bv` |
| There are **13** indirect-precision `sprintf` statements, not 3 and not 12. | `A`, `Av` |
| `dtoa_eng` has **24** call sites (not 27, not "~70"): 13 pass `xctx->ev_precision`, 1 passes `engineering`, 8 pass a hardcoded 5, 2 pass a clamped `prec`. | `B`, `Av` |
| Worst case `"%.*g%c"` = `prec+8` chars, so **cap = bufsize − 9**, giving **71** at 80 bytes — exactly issue 1602's swept ceiling. Sweep and arithmetic agree. | `B`, `Av`, `Bv` |
| `%.*g` can never exceed **774 characters at any precision**, because a double's exact decimal expansion holds at most 767 significant digits. `%.*e` zero-pads and is unbounded in `prec`. | `A`, `Av` |
| A **`.sch`** with a `floater=true` (or `name=`) `T` record carrying `tcleval([set ::ev_precision 200]…)`, and a **`.sym`** with `format="tcleval(…)"`, each set `ev_precision` and reach the abort. **Opening or netlisting someone else's file is enough.** | `A`, `Av` |
| `HAS_SNPRINTF` is defined nowhere; the **hand-rolled** `my_snprintf` is what compiles (`nm -S src/util.o` → 1615 bytes; `nm -u` lists `__sprintf_chk`, no `vsnprintf`). | `B`, `Bv` |

## The fourteen adjudications — each one is a correction to a receipt

**C1. The "69 vs 71 conflict with issue 1602" does not exist.** Receipt A's prose read the
buf-80 column for a format that only ever appears with a 100-byte buffer, and treated
`"%.*gMEG"`'s arithmetic 69 as reachable when that branch divides by `1e6` first and is pinned
at 56–59 characters at *any* precision (driven to 4000). **The tightest reachable ceiling in
the tree is 71.** Do not write the conflict down anywhere. `DECISIONS.md` G2's conclusion
(clamp per buffer) still stands, but **its stated reason was false** and the receipt's
correction must say so.

**C2. One helper, not two. Drop `clamp_prec_e` entirely.** Its only prescribed caller is
`show_node_measures`'s `%.*e` arm, and `prec = 2` is assigned **inside the same branch that
selects `%.*e`**, so no caller precision can ever reach an `%e` conversion in this tree. A
helper with no caller lands untested and unfenceable. Ship:

```c
/* Bound an indirect ("%.*g") precision to what `avail` bytes can hold.
 * Worst case for "%.*g%c" is prec+8 chars (sign, leading digit, point, prec-1
 * fraction digits, 'e', exponent sign, three exponent digits, suffix), so
 * prec+9 bytes with the NUL: cap = avail - 9. At avail == 80 that is 71, which
 * is exactly the ceiling issue 1602's dialog already publishes.
 * `avail` is the room left for the CONVERSION -- sizeof(buf) minus any literal
 * bytes elsewhere in the format string.
 * A prec <= 0 is returned UNCHANGED: 0 is eval_expr's "engineering off" flag
 * (issue 1602) and a negative makes printf use its default, so raising either
 * would change behaviour rather than bound it. */
int clamp_prec_g(int prec, size_t avail);
```

**C3. `DTOA_ENG_BUFSIZE` so 71 has exactly one source.** Define it in `src/xschem.h` beside the
`dtoa_eng` declaration, use it for the `static char s[…]`, and derive the clamp from it. **No
literal 71 anywhere in C.**

**C4. `dtoa_eng` clamps its own parameter, one clamp above the branch.** This is the
load-bearing edit: it is the only thing that makes the function correct by construction for all
24 callers, including `graph_marker_text_rec`, which hands it a `prec` no writer clamp reaches.

**C5. The out-of-bounds READ claim is build-dependent — say so or do not say it.** This build
has `_FORTIFY_SOURCE 3` by default, so the fortified `sprintf` aborts at the **write** and
`xctx->tok_size` is never reached. The read is real only in a `./configure --debug` build
(`scconfig/hooks.c` appends `-g -O0 -Wall -ansi -pedantic -Wconversion`; `-O0` carries no
FORTIFY). And it is **five** `token.c` sites that use `tok_size` as a `memcpy` length, not
seven (`:6672 :6776 :6880 :6949 :7085`). Neither crew drove the `--debug` build, so write this
as derived-and-named, not as measured.

**C6. Do NOT write the prescribed `save.c` comment — it is false.** `nd_view_set`'s format is
bare `"%.*g"`, no `%c`. Fed to the hand-rolled `my_snprintf` that shape returns `n=1, out=|1|`,
rc 0 — it does **not** abort; only the `%.*g%c` shapes do. Correct the existing comment
minimally: delete *"100 bytes is ample for one `%g`"* (false above 92) and drop the quoted
`1.111000061035156`, which is `double((float)1.111)` and cannot be produced by this path. Keep
its mechanism sentence, which is right.

**C7. The `graph_marker_fmt` comment correction is ABI-dependent.** *"made it consume the int
`prec` AS THE DOUBLE"* is wrong on **x86-64 SysV** (separate integer and SSE argument areas —
measured, the double arrives intact and it is the **suffix** that gets eaten: `'m'` came out as
`\004`). But `XSchemWin/` exists and Win64 varargs use **one** argument area, where the
comment's claim would hold. So write *"on x86-64 SysV"* into the correction, or it becomes
false on the platform the original author may have measured on.

**C8. `draw_graph_variables` EXISTS** (`src/draw.c`, called from `draw_graph`, and it owns its
own `char tmpstr[1024]`). Receipt B's *"the symbol does not exist"* is false — `nm` cannot
answer it because `-O2` inlines the statics. What is true is that **`PLAN.md` pointed the
1024-byte row at the wrong function**: the indirect-precision site is **`show_node_measures`**,
which sits immediately below it. Fix the citation; do not write the false statement.

**C9. `show_node_measures` holds TWO `sprintf`s into one `char tmpstr[1024]`, and its format
strings are `char *` VARIABLES, not literals** (`fmt1`/`fmt2`, either `"%.*e"`/`"%.*e%c"` or
`"%.*g"`/`"%.*g%c"`). **A static row grepping for a literal `"%.*g"` near this site matches
nothing** — this is the brief's trap in a third new shape, after the `#if 0` clone and the
comment quoting the guard. Fence it by the variable names and the assignment lines.

**C10. `show_node_measures` needs a clamp for honesty, not for safety.** Its `%g` arm cannot
overflow 1024 bytes at any precision (the 774-char cap) and its `%e` arm is pinned at `prec=2`.
Clamp it anyway with `clamp_prec_g(xctx->ev_precision, S(tmpstr))` so the pattern is uniform,
and put the 774-character reason in the comment — that number is what stops the next reader
"hardening" the wrong arm.

**C11. Two all-signs ceilings in receipt A are one digit too tight.** `draw_cursor_difference`
and `draw_hcursor_difference` both format `gr->unit * fabs(c2 - c1)` and `get_unit()` never
returns zero or a negative, so no sign is possible: their ceilings are **92** and **90**, not 91
and 89. Only `draw_cursor` (91) and `draw_hcursor` (89) lose a byte to the sign. The `-2` for
the two hcursor sites (the literal spaces in `" %.*g%c "`) is right and its comment must say
which two bytes it is.

**C12. ⚠ THE FENCING PROBLEM, and it is the most important item in this brief.** Receipt B's
plan says the headless reproducer *"reddens if either the `eval_expr.y` clamp or the `dtoa_eng`
clamp is removed"*. **Measured false**: with either clamp alone still present the other's
removal leaves the row **green** (the surviving clamp produces the same 71-digit string). Two
redundant clamps on one path means **neither has a behavioural row that reddens on its own
removal**, which is exactly what `CREW_BRIEF.md` forbids. Resolve it this way, and no other:

* **A static row per clamp, by name** — comments and `#if 0` regions stripped, depth-counted,
  whitespace collapsed. A static row isolates one clamp perfectly, which is why it is the
  instrument here rather than a fallback.
* **One end-to-end behavioural row** asserting rc 0 *and* that the output carries exactly the
  clamped number of significant digits (not merely that it did not abort). Its comment **must
  state its own limit**: that it reddens only when every clamp on that path is gone, and that
  the per-clamp fences are the static rows. Do not let a row claim a guard it cannot fence.
* Where a site **is** singly responsible, use a behavioural row: `graph_marker_fmt` (whose
  `prec` comes from its own `tclgetintvar`, so no writer clamp reaches it — the row needs the
  caller's `if(prec > 17)` raised, so add a static row on the 17 as well), and C14 below.

**C13. The behavioural rows that are available headless, measured — use these and no others.**
`dtoa_eng` via `xschem eval_expr {expr_eng(1e300*1.0)}`; `token.c` via
`xschem translate -1 {@spice_get_node …}`; `nd_view_set` via a graph rect + `xschem cursor 2 1`
+ reading `::ngspice::ngspice_data(...)`; and the **`.sym` `format="tcleval(…)"` netlist door**,
which poisons headless with no display and no export. ⚠ **A row that asserts "`xschem load`
alone poisons" fails headless** — on the display arm `load` alone does it (the load draws and
the draw evaluates the floater), but headless it takes a `+ xschem print svg`. Receipt A's two
traces disagree on this because they were taken on different arms and neither named its arm.
⚠ Also: an `~/.xschem/xschemrc` row run **in-tree measures nothing** — `xinit.c` gates both
`./xschemrc` and `$USER_CONF_DIR/xschemrc` behind `if(!running_in_src_dir)`. Use `--rcfile`,
which is honoured in-tree, or set a non-`src` `XSCHEM_SHAREDIR`.
⚠ In this evaluator `(0.0-1.0)*v` returns 0; write `-1.0*v` for the negative case.

**C14. A SECOND DEFECT, found by the `Av` crew at one of these very sites — fix it here.**
`callback.c`'s graph measurement tooltip tests **the wrong unit**: the guard reads
`gr->unitx != 1.0` and the body then formats `gr->unity * yval` with `gr->unity_suffix`. Two
measured consequences on `:99`:

1. A graph with `unity=T` and **no** `unitx` — an ordinary configuration — routes the **y**
   readout through `dtoa_eng`'s 80-byte buffer instead of its own 100-byte one, and that
   readout's abort threshold **drops from 93 to 73**.
2. `unitx=T` alone formats the y value with `unity == 1.0` and `unity_suffix == 0`, so the `%c`
   writes a **NUL** where a suffix was intended.

Fix the guard to test `gr->unity`. **Measure the before/after readout string and report it.**
If the only visible change is "the suffix is now correct instead of a NUL byte", it is a pure
bug fix and needs no ruling; if it is more than that, say so and the driver will file one.

## Also required in this commit

* **`xinit.c`'s comment on the initial 4** currently says *"copied from TCL ev_precision var in
  draw() and draw_graph()"* — now incomplete, and it is the comment a reader trusts instead of
  grepping. Add `kklex()`.
* **`graph_marker_fmt` honours its `destsize`** on the `sprintf` arm, so the signature stops
  lying and the latent fifth-caller hazard closes rather than being documented. Retitle the
  caller's `if(prec > 17)` comment: 17 is a display choice now, not the safety bound.
* **A new suite, `tests/headless/test_ev_precision_bound_1606.tcl`**, registered in `hcases`
  in `tests/run_regression.tcl` with a rationale comment. `hcases` only, so it costs one case
  and no skip. Display-arm rows self-skip with a lowercase `skip:` when
  `devdisplay.sh status` reports no live display.
* Every behavioural row asserts **both** the exit code **and** the absence of a column-0
  `FATAL: signal` marker.
* **Sabotage every row**: remove the guard, show the row reddens with the verbatim failing
  line, restore with **`cp` not `cp -a`**, rebuild. A preserved mtime makes `make` skip the
  file and your next figure is from a stale binary.
* Run `tests/headless/run_suites.sh --nogui test_ev_precision_bound_1606` and, if a dev display
  is up, the display arm too. Report both.

## Carried forward — name them in the receipt, do NOT fix them

1. **`my_snprintf`'s own `g`/`e`/`f` arm** does `nlen = sprintf(nstr, nfmt, i)` into
   `char nstr[50]` with the bound test **after** the write. Same class as 1606, in the house
   formatter the whole tree uses. Latent: every live float caller is ≤24 chars.
2. **Option 4 (`define HAS_SNPRINTF`) would introduce a 1606-class defect at more sites than it
   fixes.** The hand-rolled arm returns bytes *written*; `vsnprintf` returns bytes that *would
   have been*. Five sites consume the return as a length, three as an accumulator
   (`off += my_snprintf(s + off, sz - off, …)`), where `off` can exceed `sz` and the next
   iteration passes a negative `sz - off` to a `size_t`. And `scheduler.c`'s
   `my_snprintf(res, S(res), "HAS_SNPRINTF=%s\n", HAS_SNPRINTF)` gives `%s` an int — dead
   today inside the `#ifdef`, which is the cleanest proof the `vsnprintf` arm has never been
   compiled by anyone.
3. **A `.sch`/`.sym` gives arbitrary Tcl at global level** (`tcl_hook2` → `tclpropeval2` →
   `uplevel #0 "subst \{$s\}"`, and `subst` does command substitution), and a generator name
   gives arbitrary **shell** via `popen`. A documented xschem feature, far larger than 1606,
   and the reason this abort is file-borne. **Fixing 1606 does not make opening a stranger's
   schematic safe** — say that plainly rather than letting the fix read as a security fix.
4. **Tcl↔C ceiling drift**: 1602's `1..71` is a literal in `src/xschem.tcl` derived from
   `dtoa_eng`'s buffer. `DTOA_ENG_BUFSIZE` fixes the C side; an `xschem get ev_precision_max`
   getter would fix Tcl's. Belongs to whoever owns 1602's dialog.
5. **No read-back seam for `xctx->ev_precision`** — `xschem globals` does not print it, so no
   row can assert what the C mirror holds.
