# Plan — issue 1606, the unbounded `sprintf` on `ev_precision`

**Target:** `doc/claude/issues/1606-an-unbounded-sprintf-on-ev-precision-aborts-xschem-and-a-config-file-can-set-it.md`
(`claim=open fix=untried open=4`). **Read 1602 first** — it fixed the *dialog* and its
ceiling of 71 comes from this defect.

**Why this issue and not another.** It is the only item on the open list that is a measured
**process abort** rather than a wrong answer: `*** buffer overflow detected ***: terminated`,
SIGABRT, rc 134, on the shipped binary, with no chance to save. Its trigger is a line in the
user's own `~/.xschem/xschemrc`, so it needs no unusual content and no dialog.

## What the driver measured before writing this plan, and it corrects the issue

The issue's site table claims **three** sites (`dtoa_eng`, `draw.c` ×2, `graph_marker_fmt`).
A grep for every indirect-precision conversion in `src/` at `34913077` finds **twelve**, of
which **six are not in the issue at all**:

| site | buffer | precision comes from | in the issue? |
|---|---|---|---|
| `editprop.c` `dtoa_eng` ×3 (`:182 :184 :186`) | `static char s[80]` | `precision` parameter — **27 call sites** | yes |
| `draw.c:4967` `draw_cursor` | `char tmpstr[100]` | `xctx->ev_precision` | yes ("×2") |
| `draw.c:4999` `draw_cursor_difference` | `tmpstr[100]` | `xctx->ev_precision` | yes ("×2") |
| `draw.c:5029` `draw_hcursor` | `tmpstr[100]` | `xctx->ev_precision` | **NO** |
| `draw.c:5063` `draw_hcursor_difference` | `tmpstr[100]` | `xctx->ev_precision` | **NO** |
| `draw.c:~5276` `draw_graph_variables` | `tmpstr[1024]` | `int prec = xctx->ev_precision` | **NO** |
| `callback.c:2428` | `char sx[100]` | `xctx->ev_precision` | **NO** |
| `callback.c:2433` | `char sy[100]` | `xctx->ev_precision` | **NO** |
| `save.c:2904` `nd_view_set` | `char s[100]` | `nd_view.prec` ← `xctx->ev_precision` | **NO** |
| `draw.c:7750` `graph_marker_fmt` | `dest`, ignores `destsize` | `prec`, clamped ≤17 by all 4 callers | yes (latent) |

⚠ **`save.c:2904` carries a comment that is now false**: *"100 bytes is ample for one
`%g`."* Ample for precision 4; not for 200. A comment that reassures the next reader out of
checking is worse than no comment.

**`dtoa_eng` is the widest blast radius and the smallest buffer** — 80 bytes, 27 callers, of
which 15 pass `xctx->ev_precision` (`token.c` ×7, `callback.c` ×6, `eval_expr.c` via
`engineering`) and the rest pass a hardcoded 5 or a clamped `prec`.

## The chokepoint the issue does not mention, and the reason the fix may be two lines

`xctx->ev_precision` is **written in exactly three places**:

* `xinit.c:761` — the initial `4`.
* `draw.c:9011`, in `draw_graph()` — `tclgetintvar("ev_precision")`.
* `draw.c:10595`, in `draw()` — `tclgetintvar("ev_precision")`, and **not** behind `has_x`
  (the comment two lines above is explicitly about headless runs that reach `draw()`).

`eval_expr.c:1721` then does `engineering = xctx->ev_precision`, which is the reproducer's
own path. And `draw.c:7830` reads `tclgetintvar("ev_precision")` independently but clamps it
to 17 at `:7810`.

So there are **two** unclamped entry points for the whole family, not twelve. That is the
shape worth measuring against the issue's three options.

## Stages

Each stage is one crew, one receipt. A crew reads `CREW_BRIEF.md`, this section, and the
previous stage's receipt — the corrections to this plan live in the receipts.

### Stage A — measure, and settle which entry points are real

1. Reproduce the abort on the built binary at `34913077`, on the headless arm
   (`env -u DISPLAY … --nogui`), and record the exact threshold per site.
2. **Decide whether the headless arm can drive it at all.** `xctx->ev_precision` starts at 4
   and only `draw()`/`draw_graph()` refresh it. If a `--nogui` run never reaches `draw()`,
   the reproducer needs a display and the suite's behavioural rows must self-skip. Measure;
   do not assume either way.
3. Drive **each of the twelve sites** that can be reached, and say which cannot and why.
4. **The three writers the issue names** — `~/.xschem/xschemrc`, `--preinit`, and "any Tcl".
   Confirm each reaches `ev_precision`. ⚠ For "any Tcl", answer specifically: **can a
   `tcleval` property carried in a `.sch` file set it?** If yes this is a *file-borne* abort
   and the issue's severity is understated; if no, say so plainly.
5. Compute the worst-case output width for `%.*g` and `%.*e` as a function of precision, and
   derive the safe ceiling for each buffer size in the table (80, 100, 1024). The issue
   asserts 71 for 80 bytes from a sweep; derive it arithmetically as well and say whether
   the two agree.

### Stage B — the fix shape, decided by measurement not taste

The issue offers three options. Test the premise of each:

1. **Clamp at the point of use.** Cheapest. ⚠ Behaviour change on an obscure path — a user
   with `set ev_precision 200` in their rc file currently aborts and would then see 71
   digits. `rule/1606` is already filed for this.
2. **Size the buffer from the precision.** Breaks `dtoa_eng`'s `static char` contract that
   ~27 callers rely on by holding the result as a `const char *`. Measure how many actually
   would break.
3. **Give `my_snprintf` the `*` precision.** ⚠ **The driver believes this option is much
   more expensive than the issue implies, and the crew must confirm or refute it.**
   `HAS_SNPRINTF` is defined **nowhere in this tree** (`util.c:500` says so in terms), so
   `my_snprintf` is the hand-rolled formatter at `util.c:623`ff, which copies a conversion
   spec verbatim and cannot see a `*`. `save.c:2894` and `draw.c:7743` both record measuring
   the consequence: given `"%.*g"` it reads the double out of the varargs and lets libc go
   looking for an absent precision argument — `1.111` printed as `1.111000061035156`.

   **A fourth option the issue does not list**: define `HAS_SNPRINTF` in `configure` and get
   the real `vsnprintf` arm. Cost this one honestly — it changes the formatter under the
   whole tree — and recommend against it for this batch if that is the answer.
5. Recommend **one** shape with the measurement behind it. The driver's prediction is
   registered in `DECISIONS.md` as **G1** before this stage runs; refute it freely.

### Stage C — implement, and fence every site by name

Land the recommended shape. Requirements, from what the 1607 and 1603 batches paid for:

* A **behavioural** row wherever the abort can be driven deterministically, and a **static**
  row where it cannot. Static rows **must strip block comments and `#if 0` regions** before
  matching, and assert each item **by name, never by count** — this tree has defeated a
  whole-file regexp twice, once with a `#if 0` clone (1607 `V27`) and once with a *comment*
  quoting the guard (1603 `S1`–`S4`).
* Every site in the twelve-row table above is either fenced or explicitly recorded as not
  needing a fence, with the reason.
* `graph_marker_fmt` **honours its `destsize`**, so its signature stops lying; the latent
  fifth-caller hazard the issue names is then closed rather than documented.
* The false `save.c:2904` comment is corrected in the same commit.
* A sabotage per row: remove the guard, show the row reddens, restore, rebuild. ⚠ Restore
  with `cp` **not** `cp -a` — a preserved mtime makes `make` skip the file and the next
  figure is from a stale binary (1603 receipt A).

### Stage D — gate

T1 in a **fresh clone of the commit, built from scratch, solo, throwaway home, at a SHORT
path**. Baseline to beat: `cases=98 blocks=97 counted_failures=0 skips=8`
(`results.1842389.log` at `c3a59de4`). Registering one new suite in `hcases` alone costs one
case and no skip.

⚠ **Not under the session scratchpad** — it is ~100 characters before the clone name, and a
clone at 173 characters makes T1 invent 11 failures. `CLAUDE.md` has the write-up.
