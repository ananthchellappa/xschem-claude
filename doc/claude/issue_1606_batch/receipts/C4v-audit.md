# Receipt C4v — claim auditor, last crew on the issue-1606 batch

Role: the check on four rounds that each shipped at least one false claim. One question: **is
every sentence this batch ships true?** I changed **nothing** — no product edit, no suite edit,
no commit. Every sabotage was applied, measured and restored by content copy
(`shutil.copyfile` + `os.utime(..., None)`, never `cp -a`), with `make -C src` on both sides of
every cycle and `timeout` on every binary run.

**18 build/suite cycles**, plus 46 static rows replayed under `tclsh` against the suite's own
machinery, plus 13 rule-level spelling probes and 13 direct `gcc` flag measurements.
`restored_green` true in **18 of 18**; `build_rc`/`restore_build_rc` 0 in 18 of 18; zero compile
errors of my own. `:99` never started, stopped or viewed (`xvfb: 3979908` before and after every
cycle and all three arms). Owed ledger not opened; `~/dev/xschem-op-wcard` not opened; no
`/tmp/xschem_emergencysave_*` removed; all scratch under the session scratchpad; 40 `.o` in
`src/`, the build's own `OBJ` set.

---

## 0. HEADLINE

1. **The answer to the batch's own question is NO — not every sentence is true.** After four
   rounds there are still **three false claims in the shipped artefacts**, and two of them are
   again **row NAMES**, which is the failure mode of record:
   * **X1's name** is refuted by a `%.*` split across a string-literal concatenation
     (`"%." "*g"`). A genuinely unclamped indirect-precision `sprintf` into a 24-byte buffer
     leaves the suite at **`RESULT: ALL PASS (63 checks)` on every arm**, with **zero** build
     warnings. X2's name falls with it. §2.1
   * **W4's name** is refuted by an object-like `#define` alias for the FIELD
     (`#define ZZEVP xctx->ev_precision` … `ZZEVP += 200;`). No static row sees it; on a box
     with no dev display the suite is **`ALL PASS (58 checks)`** with `ev_precision` at 271. §2.2
   * **`tests/run_regression.tcl`'s "ONE shape is still out of reach of any static row"** is
     therefore false, and the same sentence is in the issue file (item 5). §2.3
2. **One more, in the cautious direction**: NAMED LIMIT 7's residue names Y1a as well as Y1b,
   and measurement says Y1a's truncation half survives `-Wno-format-truncation`. §2.4
3. **Everything else the correcting crew reported reproduces exactly**, including every figure
   the previous round got wrong: N1 → `Y1a` alone with **exactly two** diagnostics; P05 →
   `B1 B2 B3 B4 B5 B7 D2 H5` with **H6 green**; `-w` (prepended and appended) and
   `-Wno-format-overflow` each redden Y1c; no `CFLAGS=` line gives `ALL PASS (60 checks)` plus a
   second lowercase `skip:`. §3
4. **The product is untouched and the six spot-checked guards all still redden.** The only
   product edit is the `editprop.c` comment, proved comment-only **at object level** (byte-identical
   `.o`). §4, §5
5. ⚠ **`src/xschem`'s md5 is not a usable identity check in this tree** and nobody should quote
   one: `src/scheduler.c` embeds `__DATE__ " : " __TIME__`, so `scheduler.o` and the link differ
   on every rebuild from byte-identical sources. Measured. §4.3
6. **Would I gate this tree? YES** — for the product, unreservedly. Nothing I found is in the
   shipped code; all four defects are in test prose or in the reach of two negative rows, and
   none of them can hurt a user. §6

---

## 1. Method and arms

Binary rebuilt before every quoted figure. Suite driven the armed way only
(`tests/headless/run_suites.sh [--nogui] test_ev_precision_bound_1606`); on a red,
`run_suites.sh` prints every `FAIL:`/`FATAL` line, which is where the row names below come from.

Three arms, on the final tree, after `make -C src` reports `Nothing to be done for 'all'`
(§6 has them verbatim): **63 / 63 / 58**.

Two extra instruments, because a full build cycle is the wrong tool for a question about a rule:

* **`probe.tcl`** loads the suite's own machinery (everything up to `# SECTION Y`, with the
  suite's own `check`/`check_true`) under plain `tclsh`, so every proc and global is the
  suite's. It replays the 46 static rows: **all 46 `ok:`, none failing.** That is an
  independent confirmation of the static half that does not go through xschem at all.
* **`probe2.tcl`** then asks `ev_writes`/`w4_verdict`/`w4c_wrapped`/`x1_verdict`/`sprintf_stmts`
  about 23 spellings directly. Rule-level green is not tree-level green, so every hole it found
  was re-driven as a full build cycle; the table is in §2.5.

---

## 2. THE FALSE CLAIMS

### 2.1 ⚠ X1's ROW NAME IS FALSE, AND SO IS X2's — the `%.*` split by concatenation

Shipped, verbatim (`tests/headless/test_ev_precision_bound_1606.tcl`):

> `X1 in every sprintf statement whose own format LITERAL carries a `%.*`, anywhere in the`
> `hand-written sources -- including one spelled `sprintf (` or through an object-like `#define``
> `alias -- the argument in the `%.*` position IS a clamp_prec_g() call and that clamp's avail`
> `NAMES the destination buffer …`

and the comment above it, which is the part that makes it a claim about a SET rather than a hedge:

> `So the name is scoped to the statements whose own FORMAT LITERAL carries the `%.*`, which is`
> `exactly the set this row decides.`

**MEASURED FALSE.** Decoy **M14**, one edit, in `src/actions.c` (a hand-written source, in the
`$SRC` glob):

```c
void zz_probe_m14(double zv)
{
  char zb[24];
  sprintf(zb, "%." "*g", xctx->ev_precision, zv);
  dbg(1, "%s\n", zb);
}
```

C translation phase 6 concatenates the two literals, so **the statement's own format literal IS
`%.*g`** and the precision argument is the raw field — at 71 this writes ~78 bytes into 24.
Result:

```
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (63 checks)
```

and the build emitted **no** `-Wformat` diagnostic of any kind (only the tree's pre-existing
`actions.c:564 -Wdiscarded-qualifiers`).

**Re-driven inside a file Y1b compiles** (decoy **M14d**, the same function in `src/draw.c`,
still `char zb[24]`), to close off "the compiler would catch it":

```
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (63 checks)
build warnings: []
```

Y1b is at the build's own flags, i.e. `-Wformat-overflow=1` through the fortified
`__builtin___sprintf_chk`, and at level 1 gcc says nothing about a `%.*g` whose precision it
cannot range. Y1a is scoped to `editprop.c` by measurement. So **nothing in the suite, and
nothing in `make`, sees this.**

**Mechanism**, one line: `x1_verdict` opens with
`if {[string first {%.*} $st] < 0} { return {skip {}} }`, and the statement text is
`sprintf(zb,"%." "*g",xctx->ev_precision,zv);` — the substring `%.*` is not in it. `cs_norm`
cannot help: the space between `"%."` and `"*g"` is adjacent to `"` on both sides, not to one of
the five punctuators.

**X2's name falls with it** — `X2 and the files carrying one are exactly the four this suite
fences by name (a new file here is an unfenced site)`. Under decoy **M2** (`sprintf (`),
`actions.c` DID appear and X2 reddened; under M14 it does not, because X2 tests the same
`%.*` substring. A new unfenced site in a new file is exactly what X2 exists to name, and it
does not.

**Two more spellings of the same hole** (rule level, `probe2.tcl`, not driven as builds because
the mechanism is identical): `"%" ".*g"` (M14b) and `"%.\052g"` (M21, octal escape for `*`) are
both skipped by `x1_verdict`.

**Not covered by any NAMED LIMIT.** Limit 2 is about a format held in a macro or a `char *`
VARIABLE (`show_node_measures`' `fmt1`/`fmt2`). A literal that is spelled in two pieces is not
that, and the row name's own parenthetical — "(a format held in a `char *` VARIABLE is out of
reach here: NAMED LIMIT 2)" — reads as if that were the only exclusion.

### 2.2 ⚠ W4's ROW NAME IS FALSE — an object-like `#define` alias for the FIELD

Shipped, verbatim:

> `W4 every WRITE to xctx->ev_precision in the hand-written sources passes the value through`
> `clamp_prec_g -- whatever the spacing, and whether it is one statement or two -- so there is no`
> `UNCLAMPED writer left; …`

and the SECTIONS header's claim about the pair:

> `W1-W6 THE THREE WRITERS of xctx->ev_precision, plus two rows proving there is no fourth`
> `UNCLAMPED one`

**MEASURED FALSE.** Decoy **M8b**, two edits in `src/draw.c` — a file-scope
`#define ZZEVP xctx->ev_precision` after `#include "xschem.h"`, and one statement in
`draw_graph()` immediately after the legitimate clamped write:

```c
  xctx->ev_precision = clamp_prec_g(tclgetintvar("ev_precision"), DTOA_ENG_BUFSIZE);
  ZZEVP += 200;
```

The field ends up at **271** — the 1606 input, re-admitted. What the suite says:

```
# dev display up
FAIL     | test_ev_precision_bound_1606 run 1/1  RESULT: 3 FAILED (60 passed)
         | FAIL: D2 … (rc=0 death=0 digits=91 …)
         | FAIL: D3 …
         | FAIL: D4 …

# no dev display visible (AUDIT_DISPLAY=none, XSCHEM_DEVDISPLAY_DIR read-only empty)
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (58 checks)
         | skip: D1 D2 D3 D4 -- …
```

So: **W4 sees zero writes, W4c sees no unwrapped read, and no static row reddens at all.** The
only fences are the three display-arm behavioural rows, and they self-skip on the arm CLAUDE.md
requires the zero to hold on. `ev_writes` never registers it because the write text contains no
`xctx->ev_precision`; the `#define` line does contain it but is followed by a space, not by an
assignment operator, so it is skipped — `{draw.c x2}` is unchanged and the anti-vacuity clause
is satisfied.

**Not covered by NAMED LIMIT 6**, which names only "a write to xctx->ev_precision through a
POINTER or an aliased struct copy (`p = xctx; p->ev_precision = 200;`)". A macro alias is a
third shape. And limit 6's closing reassurance is itself false as stated:

> `W4c is what makes this narrow rather than open: a value that never comes from`
> `` `tclgetintvar("ev_precision")` cannot be the file-borne 1606 input at all, and one that does ``
> `is caught at the read wherever it later goes.`

In M8b the dangerous value *does* come from the Tcl var — through `draw_graph`'s own properly
wrapped read, which W4c correctly accepts — and is then raised past the cap. It is not "caught
at the read wherever it later goes"; nothing catches it. (For contrast, **M18**,
`xctx->ev_precision = clamp_prec_g(…) + 200;` written straight at the field, *is* caught by W4 —
it is only the alias that hides it.)

### 2.3 ⚠ `tests/run_regression.tcl` — "ONE shape is still out of reach of any static row"

Shipped, verbatim:

> `ONE shape is still out of reach of any static row -- `if(0) <the guard>`, which uses no`
> `preprocessor at all -- and it is exposed at exactly ONE of the fourteen clamp sites`
> `(show_node_measures, whose formats are char * variables); at the other thirteen it leaves an`
> `unclamped statement for X1, W4 or the compiler-diagnostics rows Y1a/Y1b.`

**False by §2.1 and §2.2**: there are at least **three** shapes out of reach of every static
row, and one of them (M14) is out of reach of every row in the suite on every arm and of the
build as well. This is the fourth consecutive round in which this sentence has been wrong by a
count — it said "One shape" before this round too, and the correction changed the surrounding
paragraph while keeping the quantifier.

The same sentence is in the issue file, `doc/claude/issues/1606-…md`, open-risk item 5:
*"**One shape is out of reach of any static row in the suite**, and it is named there rather
than papered over"*.

### 2.4 ⚠ NAMED LIMIT 7 names Y1a, and Y1a is not affected

Shipped, verbatim:

> `7. Y1c proves the compile can emit a -Wformat-OVERFLOW diagnostic. A CFLAGS`
> `   carrying only `-Wno-format-truncation` would therefore leave Y1c green while`
> `   silencing the truncation half of Y1a/Y1b.`

Measured, three ways. The suite half is right — `-Wno-format-truncation` appended to
`Makefile.conf`'s `CFLAGS` gives `RESULT: ALL PASS (63 checks)`, i.e. Y1c does stay green. The
silencing half is right for **Y1b** and wrong for **Y1a**, on a synthetic truncation case
(`snprintf(b /*4*/, sizeof b, "%s-%s", p, "0123456789")`):

```
CFLAGS only (Y1b shape)                  trunc_diag=1
-Wno-format-truncation (Y1b shape)       trunc_diag=0     <- Y1b really is silenced
CFLAGS + level2 (Y1a shape)              trunc_diag=1
-Wno-format-truncation + level2 (Y1a)    trunc_diag=1     <- Y1a is NOT
```

`ycompile` emits `$cc $cflags $extra`, so Y1a's explicit `-Wformat-truncation=2` comes after the
`-Wno-` and gcc honours the later flag. The generalisation the Y1c comment draws from the `-w`
measurement — *"gcc accepts the later explicit flag and still says nothing, so 'the explicit flag
wins' is not a defence"* — is true of `-w`, which is position-independent by design, and does not
transfer to a specific `-Wno-`. Over-cautious, i.e. the safe direction, but it does not
reproduce as written.

### 2.5 Every spelling I probed, and what happened

Full build cycle unless marked *(rule)*. "green" = the suite did not notice.

| id | spelling | driven where | outcome |
|---|---|---|---|
| **M1** | `xctx->ev_precision=tclgetintvar("ev_precision");` | draw_graph | **W4 W4c** (+D2) |
| **M6** | `int zt = tclgetintvar(…); xctx->ev_precision = zt;` | draw_graph | **W4 W4c** (+D2) |
| **M10** | the writer needle split across TWO physical lines | draw_graph | **W4 W4c** (+D2) |
| **M2** | `sprintf (zb, "%.*g", xctx->ev_precision, zv);` | actions.c | **X1 X2** |
| **M9** | `#define SP sprintf` at FILE scope, `SP(...)` in another function | actions.c | **X1 X2** |
| **M8b** | `#define ZZEVP xctx->ev_precision` + `ZZEVP += 200;` | draw.c | ⚠ **no static row**; D2 D3 D4 only, and **ALL PASS (58)** with no dev display |
| **M14** | `sprintf(zb, "%." "*g", …)` | actions.c | ⚠ **ALL PASS (63)** |
| **M14d** | the same, in a Y1b file, `char zb[24]` | draw.c | ⚠ **ALL PASS (63)**, zero build warnings |
| **M23** | `#define SPA sprintf` / `#define SPB SPA` / `SPB(...)` | actions.c | ⚠ **ALL PASS (63)** |
| **N1** | `if(0) precision = clamp_prec_g(precision, sizeof(s));` | editprop.c | **Y1a only, 2 diagnostics** |
| M14b | `sprintf(zb, "%" ".*g", …)` *(rule)* | — | skipped by `x1_verdict` |
| M21 | `sprintf(zb, "%.\052g", …)` *(rule)* | — | skipped by `x1_verdict` |
| M11 | `#define ZZW <the whole write>` + `ZZW;` *(rule)* | — | caught (W4: the `#define` line is itself an unterminated write) |
| M12 | the value through TWO locals *(rule)* | — | caught (W4 + W4c) |
| M13 | `Xschem_ctx *zp = xctx; zp->ev_precision = tclget…;` *(rule)* | — | caught by W4c (limit 6 is honest about W4) |
| M15 | `xctx -> ev_precision = tclgetintvar ( … ) ;` *(rule)* | — | caught (`cs_norm` works on `->`) |
| M16 | comma operator round the read *(rule)* | — | caught (W4 + W4c) |
| M17 | `(int)` cast on the read *(rule)* | — | caught (W4 + W4c) |
| M18 | `clamp_prec_g(…) + 200` at the field *(rule)* | — | caught (W4) |
| M19 | `#define ZZGET tclgetintvar("ev_precision")` *(rule)* | — | caught (W4 + W4c) |
| M20 | `atoi(tclgetvar("ev_precision"))` *(rule)* | — | caught (W4; W4c sees no read, which its name scopes) |
| M22 | `#define<TAB>SPX<TAB>sprintf` *(rule)* | — | caught (X1) |
| M24 | `sprintf` and `(` on different lines *(rule)* | — | caught (X1) |
| M25 | `snprintf(zb, S(zb), "%.*g", …)` *(rule)* | — | out of X1's name's scope, and genuinely safe |

**M23 is a fourth green**, weaker than M14 because "an object-like `#define` alias" arguably
means one hop: `sprintf_aliases` only matches a `#define X sprintf` replacement list, so a
two-hop chain (`SPA` → `sprintf`, `SPB` → `SPA`) yields **zero** statements and X1/X2 see
nothing. Reported as the same class as M14, not as a separate defect.

### 2.6 Carried forward — one comment figure that does not reproduce, and is not this round's

`src/editprop.c`, the MEG-arm comment (landed by `C3-close.md`, untouched this round):

> `which pins the output near 59 characters at ANY precision (measured 2026-09-25: driven to 4000`
> `at both signs, longest 54 chars, and every one of the 96 strings byte-identical at cap 71 and`
> `cap 69)`

The `%.*gMEG` arm has already divided by 1e6, so `|i|` is in `(0.999999, 999.999]`. Driving that
range directly (`sprintf("%.*gMEG", p, v)`, 12 precisions × 12 values × both signs = 288
strings, then a fine sweep):

```
12 precisions x 12 values x 2 signs = 288 strings
MAX strlen = 58 at precision 55 value -1.2345678901234567
fine sweep MAX strlen = 59 at precision 55 value -0.99999910000000003
```

`C3v-final.md` §5.2 measured the same thing through the product and printed
`max LEN over the 192: 58`. So **"longest 54 chars" is below the arm's real worst case**, and it
contradicts "near 59 characters" three words earlier in its own sentence. The *conclusion* is
sound (the fix is arithmetic, the bound is 69 + 11 = 80), and this is not a safety claim — but a
reader taking 54 as the arm's worst case would be wrong. Not fixed; named.

---

## 3. WHAT THE CORRECTING CREW CLAIMED, AND WHAT I MEASURED

| C4-claims item | claim | my measurement | verdict |
|---|---|---|---|
| needles, M1 | now reddens W4, W4c | `W4 W4c` (+ D2 behaviourally, which C4 did not report) | **TRUE** |
| needles, M6 | now reddens W4, W4c | `W4 W4c` (+ D2) | **TRUE** |
| needles, M2 | now reddens X1 | `X1` **and X2** | **TRUE** |
| needles, M7 | `#define SP sprintf` closed, → X1 + Z1 | driven at FILE scope (so Z1 is not involved): `X1 X2` | **TRUE** |
| needles | Tcl here has NO lookbehind | Tcl **8.6.17**; `(?<=a)b` → `couldn't compile regular expression pattern: quantifier operand invalid` | **TRUE** |
| needles | the glob is 47 files | `ls src/*.c *.h *.y *.l | wc -l` → **47**; scanned set 43 | **TRUE** |
| y1_fence | `-w` PREPENDED reddens Y1c | `RESULT: 1 FAILED (62 passed)`, `Y1c … level2=0 … build-flags=0 … cflags={-w -pipe …}` | **TRUE** |
| y1_fence | `-w` APPENDED reddens Y1c | `RESULT: 1 FAILED (62 passed)`, `cflags={… -w}` | **TRUE** |
| y1_fence | skips cleanly with no CFLAGS line | `RESULT: ALL PASS (60 checks)` + second lowercase `skip: Y1a Y1b Y1c -- no gcc on PATH (12 chars) or no CFLAGS line …` | **TRUE** |
| limit 7 | `-Wno-format-overflow` is caught | `Y1c` reddens, `level2=1 … build-flags=0` | **TRUE** |
| limit 7 | `-Wno-format-truncation` leaves Y1c green | `ALL PASS (63 checks)` | **TRUE** |
| limit 7 | … while silencing the truncation half **of Y1a/Y1b** | Y1b yes; **Y1a no** (§2.4) | **FALSE for Y1a** |
| claim (c1)(c2) | gcc reports the 310-into-80 line **TWICE**, not three times | N1 driven: `Y1a … -> {2 {{editprop.c: …:262:11: …} {editprop.c: …:264:9: …}}}` | **TRUE** |
| claim (d) | N1 → Y1a and NOWHERE else in this file | N1 driven: `RESULT: 1 FAILED (62 passed)`, rows = `Y1a` | **TRUE** |
| claim (e) | P05 reddens B1 B2 B3 B4 B5 B7 D2 (+H5); **H6 does NOT** | P05 driven: `RESULT: 8 FAILED (55 passed)`, rows = `B1 B2 B3 B4 B5 B7 D2 H5`; **H6 green** | **TRUE** |
| claim (b) | limit 1 is ONE site wide; 2 + 3 + 8 + 1 = 14 | 14 real `clamp_prec_g` call sites counted (editprop 222/260; draw 9073/10659 + eval_expr.y 266; draw 5293; callback 2440/2446, draw 4970/5007/5042/5081/7804, save 2909) — the other 7 grep hits are comments or the declaration | **TRUE** |
| claim (g) | 8 + 3 + 2 map of who fences the thirteen old sites | consistent with the 14-site census above and with G1–G11 / K2 K3 / G5 G5b as written | **TRUE** |
| claim (h) | inserted span 9822–10119, enclosing `/*` 8584–10119, 80 → 82 | reproduced exactly, plus a byte-identical `.o` (§4.2) | **TRUE** |
| check_count | 63 / 63 / 58, and 60 with no CFLAGS | reproduced on all four (§6, §3 row above) | **TRUE** |
| check_count | five new rows W4c W4d X1e Z0c Y1c; `hcases` unchanged at 80; 99 cases / 98 blocks | `hcases` **80**, `tcases` **3**, `dcases` **15** → 3 + 80 + 15 + `xschemtest` = **99**; 63 − 58 = 5 | **TRUE** |
| check_count | `info complete` → 1; `ISSUE-STAMP: ok (0 problems)` | both reproduced (suite too: `info complete` → 1) | **TRUE** |
| deviation 3 | M3 and M5 exist in NO receipt in this batch | `C3v-final.md` names only M1, M2, M4, M6; `M3`/`M5` appear only in `C4-claims.md` | **TRUE** |
| deviation 11 | no stray `.o` in `src/` | 40 `.o`, the `OBJ` set | **TRUE** |
| Z1/Z2 completeness | the ten bodies + the four exclusions are every body a static row reads | all `cfunc`/`cfunc_raw` call sites enumerate exactly 14 functions = 10 + 4 | **TRUE** |

**One quotation defect, not a false claim**: C4-claims' ARM 1 and ARM 2 blocks are introduced as
"Verbatim" but omit the `display arm: ATTACHED to persistent dev display :99 (devdisplay.sh),
GUI_GATE=0` line that `run_suites.sh` prints between the test-home banner and the `PASS` line
(ARM 3's equivalent line *is* quoted). Cosmetic; I mention it only because the word is "verbatim".

---

## 4. THIS ROUND CHANGED NO PRODUCT BEHAVIOUR

### 4.1 The diff, against what `C3v-final.md` §6 recorded

| file | C3v recorded | now | delta |
|---|---|---|---|
| `src/callback.c` | 20 | 20 | — |
| `src/draw.c` | 94 | 94 | — |
| `src/editprop.c` | 80 | **82** | +2, the comment |
| `src/eval_expr.y` | 10 | 10 | — |
| `src/save.c` | 15 | 15 | — |
| `src/xinit.c` | 6 | 6 | — |
| `src/xschem.h` | 32 | 32 | — |
| `tests/run_regression.tcl` | 51 | 63 | +12, prose only |

`git status --porcelain` is thirteen entries — nine modified, four untracked — byte-for-byte the
git status this session started with; the issue file's diff grew (206) with this round's
write-up. **No new or deleted file in `src/`.** (`C3v-final.md` §6's quoted listing shows twelve
because it omits the issue `.md`, and calls it "nine"; the tree is what it is.)

### 4.2 The one product edit is comment-only, proved at OBJECT level

The changed text spans characters **9822–10119** of `src/editprop.c`; the enclosing block comment
opens at **8584** and its matching `*/` ends at **10119** — so the whole edit is inside one
comment. Then, decisively: I compiled the file with the shipped 5-line comment and with
`C3v`'s 3-line comment, same flags, same filename, in `src/`:

```
md5 new-comment  : cd3a84356091f7a9bca1d3774bf2ce92
md5 old-comment  : cd3a84356091f7a9bca1d3774bf2ce92
md5 restored     : cd3a84356091f7a9bca1d3774bf2ce92
IDENTICAL OBJECT : True
```

### 4.3 ⚠ AND THE BINARY'S md5 IS NOT A VALID IDENTITY CHECK HERE

I expected `src/xschem`'s md5 to pin this down and it does not. Two rebuilds from
**byte-identical** sources (`touch src/*.c src/*.h; make -C src`):

```
src/scheduler.o   9e409d5eef7cfa334d56a439421b27c6  ->  b4f0b57faa8fc15feecfe4d9143a7a7d
src/xschem        004398fe764d887af9627898a989975c  ->  575d31aa3865e1d982c23e8243c9a634
all 39 other .o   identical
```

Cause, found in the code: `src/scheduler.c` contains
`char date[] =  __DATE__ " : "  __TIME__;`. So the object and the link carry the build clock.
**Reproducible builds hold for 39 of 40 objects, including `editprop.o`; the binary's hash does
not.** Anyone auditing this tree should compare objects, not the binary — and no receipt in this
batch should quote a binary md5 as evidence.

### 4.4 Nothing was left modified

`md5sum -c` over a 50-file manifest (`src/*.c *.h *.y *.l`, the suite,
`tests/run_regression.tcl`, `Makefile.conf`) taken before the first cycle: **all 50 OK** after
all 18 cycles, including the three that edited `Makefile.conf` and the one that edited
`src/xschem.h`.

---

## 5. THE GUARDS STILL REDDEN — six spot-checked, one cycle each

One edit per cycle, rebuild, armed nogui run (dev display up), restore by content copy, rebuild,
re-run to `ALL PASS (63 checks)`.

| # | single removal | rows that reddened | C3v §3 said | agree |
|---|---|---|---|---|
| **P04** | `if((size_t)prec > cap) return (int)cap;` | H4, B1 B2 B3 B4 B5 B7, D1 D1b D2, Y1a — **11 FAILED (52 passed)** | same 11 | ✓ |
| **P07** | `dtoa_eng`'s clamp above the branch | K2 K3, Y1a — **3 FAILED (60 passed)** | K2 K3, Y1a | ✓ |
| **P08** | the MEG arm's `clamp_prec_g(precision, sizeof(s) - 2)` | K3, X1, Y1a, Y1b — **4 FAILED (59 passed)** | K3, X1, Y1a Y1b | ✓ |
| **P11** | `kklex()`'s writer clamp (`eval_expr.y`) | W3, W4, W4c, W6 — **4 FAILED (59 passed)** | W3, W4, W6 (W4c is new this round) | ✓ |
| **P16** | `show_node_measures`' clamp | G5 — **1 FAILED (62 passed)** | G5 | ✓ |
| **P23** | the C14 fix (`gr->unity` guard back to `gr->unitx`) | G10, D3, D4 — **3 FAILED (60 passed)** | G10, D3 D4 | ✓ |

Two things worth recording:

* **P04 is where the "three times" figure comes from and why it is not N1's.** Removing the cap
  application unbounds the MEG arm's own clamp too, so Y1a reports the 310-into-80 line
  **three** times (`…:259:11`, `…:261:11`, `…:263:9`). Under **N1** and under **P07** — which
  leave the MEG arm's second clamp intact — it is **twice**. The corrected comment is right, and
  this is the measurement that explains the earlier round's mistake.
* **P23 driven as the pure single revert reddens exactly `G10 D3 D4`**, i.e. C3v's row set, not
  C4-claims' broader `G9 G10 D3 D4` — C4's deviation 5 already says its own edit was broader.
  Both agree G10 is the fence.

`P05` was driven too (§3): `H5` plus `B1 B2 B3 B4 B5 B7 D2`, with **H6 green** — which is the
whole point of correction (e). Its build log also re-confirms the tree's warning baseline: the
six pre-existing `-Wdiscarded-qualifiers` at `actions.c:557`, `util.c:222`, `save.c:7087`,
`token.c:954/955/956` and nothing else.

---

## 6. GATE VERDICT

```
$ git status --porcelain
 M doc/claude/issues/1606-an-unbounded-sprintf-on-ev-precision-aborts-xschem-and-a-config-file-can-set-it.md
 M src/callback.c
 M src/draw.c
 M src/editprop.c
 M src/eval_expr.y
 M src/save.c
 M src/xinit.c
 M src/xschem.h
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/issue_1606_batch/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_ev_precision_bound_1606.tcl

$ git diff --stat
 ...n-aborts-xschem-and-a-config-file-can-set-it.md | 206 ++++++++++++++++++++-
 src/callback.c                                     |  20 +-
 src/draw.c                                         |  94 ++++++++--
 src/editprop.c                                     |  82 +++++++-
 src/eval_expr.y                                    |  10 +-
 src/save.c                                         |  15 +-
 src/xinit.c                                        |   6 +-
 src/xschem.h                                       |  32 +++-
 tests/run_regression.tcl                           |  63 ++++++-
 9 files changed, 497 insertions(+), 31 deletions(-)

$ make -C src
make: Entering directory '/home/analog/dev/xschem-claude/src'
make: Nothing to be done for 'all'.
make: Leaving directory '/home/analog/dev/xschem-claude/src'
```

**ARM 1 — headless, armed** (`tests/headless/run_suites.sh --nogui test_ev_precision_bound_1606`):
```
test home: throwaway /tmp/xschem-test-home.2251604.VE41fH (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (63 checks)
RESULT: 1/1 runs passed
```

**ARM 2 — display, armed** (`tests/headless/run_suites.sh test_ev_precision_bound_1606`):
```
test home: throwaway /tmp/xschem-test-home.2251981.k9lw35 (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (63 checks)
RESULT: 1/1 runs passed
```

**ARM 3 — no dev display visible** (`XSCHEM_DEVDISPLAY_DIR` pointed READ-ONLY at an empty scratch
dir so `devdisplay.sh status` exits 1; `AUDIT_DISPLAY=none`; `:99` never started, stopped or
viewed — `state: alive`, `xvfb: 3979908` before and after):
```
test home: throwaway /tmp/xschem-test-home.2252358.A2nEwX (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: none (DISPLAY unset; GUI legs will self-skip)
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (58 checks)
         | skip: D1 D2 D3 D4 -- tests/headless/devdisplay.sh status does not report the persistent dev display alive, so the four draw.c cursor readouts and the callback.c measurement tooltip did not run; bring it up with tests/headless/devdisplay.sh start. G1-G4 and G8-G10 fence the same clamps statically on either arm
RESULT: 1/1 runs passed
```
One `skip:` line, lowercase, reason ends `…on either arm` — not a counted shape, does not start
`FATAL`.

**WOULD I GATE THIS TREE? YES.**

The shipped change is three files of arithmetic plus comments; six of its twenty-four guards were
re-sabotaged here and every one reddened with the row set the previous adversary recorded; the
only product edit this round is provably comment-only at object level; and the four defects I
found are all in test prose or in the reach of two negative rows. None of them can hurt a user
and none is a reason to hold the commit. What I would ask the driver to do **in this commit** is
scope the three sentences in §2.1–§2.3 to what they actually deliver and add the two shapes to
NAMED LIMITS — because shipping a row name that an eleven-second cycle refutes is now the thing
this batch has done **five** rounds running, and the two names at issue are the same two names
that were wrong last round.

---

## 7. WHAT I COULD NOT MEASURE, AND WHAT I AM CARRYING FORWARD

Could not measure:

* **A full T1 gate** — the driver's, in a clone at a SHORT path (`test_op_annot`'s rule). The
  registration arithmetic checks out (`hcases` 80, `tcases` 3, `dcases` 15 → 99 cases / 98
  blocks) but I ran no T1.
* **`-flto`**, `Win64`, `./configure --debug` (`-O0`, no `_FORTIFY_SOURCE`) — no toolchain,
  unchanged from C3v §7.
* **A genuinely compiler-less box** — the `NOCFLAGS` cycle exercises the same skip branch by
  removing the `CFLAGS=` line; C4's note that emptying `PATH` instead measures a broken `PATH`
  rather than a missing `gcc` is consistent with what that branch tests.
* **The seven other `if(0)`-at-a-sprintf-site cases** of named limit 1 — I drove N1 only, like
  C4; the rest remain an argument.

Carried forward, named, not fixed (I was told not to fix, and did not):

1. **X1/X2 are blind to a `%.*` that is split or escaped inside its own literal** (M14, M14b,
   M21) — and to a two-hop `#define` alias chain (M23). Direction of failure: **false PASS on a
   sabotaged tree**, on every arm, with no compiler backstop. §2.1, §2.5
2. **W4/W4c are blind to an object-like macro alias for the field** (M8b) — static rows all
   green, and the whole suite green on the no-dev-display arm. §2.2
3. **Two shipped sentences quantify over "ONE shape"** (`tests/run_regression.tcl` and the issue
   file's open-risk item 5) and there are at least three. §2.3
4. **NAMED LIMIT 7 names Y1a where only Y1b is silenced.** §2.4
5. **`src/editprop.c`'s "longest 54 chars" under-states the MEG arm's worst case** (58 driven,
   59 swept) and contradicts "near 59 characters" in its own sentence. Pre-existing, from
   `C3-close.md`. §2.6
6. **Outside this issue's scope, not fixed**: `src/scheduler.c`'s `__DATE__ " : " __TIME__`
   makes this build non-reproducible at the link, which silently invalidates any binary-md5
   argument anyone makes about this tree. Present long before this batch. §4.3
7. **Outside this issue's scope, not fixed**: the six pre-existing `-Wdiscarded-qualifiers`
   warnings, re-observed in the P05 build log. Not this batch's.
