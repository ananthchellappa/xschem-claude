# Receipt C2v — independent re-proving of the Stage C2 repair

**Crew:** `reprove:C2` (independent; disbelieved `receipts/C2-repair.md` and re-drove every
claim it makes about the four decoys, the eight new rows and the two corrected comments).
**Tree:** `34913077` + Stage C's working-tree edits + Stage C2's repairs, **untouched at the
end** (§7). Nothing committed, nothing reverted.
**Suite under audit:** `tests/headless/test_ev_precision_bound_1606.tcl`, md5
`8aa4e75969b1059c5f1eaf13512daa14`, **51 checks** with the dev display up, **46** without it.
**Method:** 43 cycles, each one a full `verify-pristine → apply → make -C src → suite →
restore (shutil.copyfile + utime(None), never `cp -a`) → make -C src → require 51/51 green
again`. The driver refuses to patch unless the target text occurs **exactly once**, aborts the
whole run on the first non-green restore, and **never ran in the background** (Stage C2's own
incident 7). It never aborted: `restored_green` true 43/43, `restore_md5_mismatch` empty 43/43,
`build_rc` 0 and `restore_build_rc` 0 43/43.

Scratch: `$SCRATCH/rp/{cyc.py,mk.py,run1606.sh,probe1..4.tcl,matrix.jsonl,logs/}`. The Tcl
probes `source` the suite's **own** procs, extracted verbatim by
`awk '/^proc /{p=1} p{print} /^}$/{p=0}'` — nothing retyped.

---

## 0. The headline

**The six decoys the repair closed are really closed. The repair did not close the CLASS — I
defeated the suite to full greenness ELEVEN more times, including three times on the same
load-bearing clamp (adjudication C4) that the sabotage crew defeated, and once on
`show_node_measures`, whose clamp `G5` is the ONLY fence.**

1. **All six re-runs redden** (§1). `/* */` → `K2 K3`; `#if 0` → `K2 K3 Z1`; `#ifdef
   XSCHEM_NEVER` → `Z1`; `//` → `K2 K3`; `#if 0 && 1` → `K2 K3 Z1`; the V6 shape → `G3`.
2. **Eleven NEW decoys leave `RESULT: ALL PASS (51 checks)` EXITCODE=0** (§2), in four families
   the repair's design does not reach:
   * **no preprocessor at all** — `if(0)` in front of the real statement (**N1**);
   * **a directive section Z does not match** — a never-invoked `#define` (**N2**);
   * **a string literal** — the asserted statement inside `"…"` (**N3**);
   * **Z2's own allowlist** — `#ifndef __unix__`, `#if HAS_CAIRO!=1` and `#if 1`+`#else` are
     all **dead on this build** and all pass Z2, so `W1 W2 G5 G5b G8 G9 G10` are still
     defeatable inside the four functions Z1 excludes (**N4 N5 N6**);
   * **X1 is a token-presence test, not a dataflow check** — a new site whose statement
     contains `clamp_prec_g` but discards it, or clamps against the wrong size (**N7 N8**);
   * **the stripper can be made to swallow live code** — a `//` opened on the continuation
     line of a multi-line string, or a `/*` inside a string literal, hides a live unclamped
     `sprintf` from `X1`/`X2` and a live fifth writer from `W4` (**N9 N10 N12**).
   **N1/N2/N3 were proved to lack the clamp in the compiled binary**, not merely to look odd:
   paired with `kklex()`'s writer clamp removed they each give
   `rc=134/SIGABRT-the-1606-overflow`, where the same removal alone leaves `B1` green (§2.1).
3. **Every one of the eight new rows reddens on a single removal** (§3), and so do the four
   product guards I spot-checked. Nothing the repair landed is unfenced **except** the two
   comment rewrites it declared unfenced (R5a, R5b) and one it did not declare (`rcwhy`) —
   all three measured, all three redden nothing (§4).
4. **The two corrected comments are true where they matter, and each carries one wrong
   detail** (§5). A **third** wrong claim was introduced: Z2's justification sentence, *"which
   is why W1, W2, G5, G5b, G8, G9 and G10 are not left unfenced by Z1's exclusions"*, is
   **measured false** (N4/N5/N6). And the corrected `D1FIX` paragraph quotes a failing detail
   as `(rc=1 …)` that the repair's own R6 makes print `(rc=134/SIGABRT-the-1606-overflow …)` —
   the same "a shipped comment quotes a probe that does not reproduce as written" defect the
   crew was repairing, in its own replacement text.
5. **Everything else in `C2-repair.md` that I could re-derive held**, including R6's exit-status
   decode (which is a visible improvement: every reddened behavioural row now names the SIGABRT),
   the `#if 0` matcher's new trailing class, the ten/four split of section Z, the
   `no // in code` correction to the brief, the `\b71\b` re-count, and deviation 6's one new
   compiler warning (§6).

---

## 1. The six decoys, re-run independently — all six redden

Each is a separate full cycle; `rc` is the suite's exit code under the sabotage. In `RV1`–`RV5`
the real `precision = clamp_prec_g(precision, sizeof(s));` is **deleted from `dtoa_eng`** and
the binary rebuilt without it.

| id | decoy holding K2's asserted text | rows reddened | rc |
|---|---|---|---|
| RV1 | `/* … */` block comment | `K2` `K3` | 1 |
| RV2 | `#if 0` / line / `#endif` | `K2` `K3` `Z1` | 1 |
| RV3 | `#ifdef XSCHEM_NEVER` / line / `#endif` | `Z1` | 1 |
| RV4 | `  // precision = clamp_prec_g(…);` | `K2` `K3` | 1 |
| RV5 | `#if 0 && 1` / line / `#endif` | `K2` `K3` `Z1` | 1 |
| RV6 | `draw_hcursor`'s `- 2` REALLY removed, `G3`'s statement in a `//` comment one line below | `G3` | 1 |

```
RV1  FAIL: K2 dtoa_eng clamps its own `precision` parameter against its own buffer -> {0} (exp {1}) : FAIL
RV1  FAIL: K3 the three conversions the clamp protects are all still there, and the clamp is
     PRESENT and precedes the suffix branch -> {0} (exp {1}) : FAIL
RV3  FAIL: Z1 none of the ten function bodies the static rows read carries ANY
     conditional-compilation directive, so an `#ifdef <undefined>` decoy parked in one -- the
     one shape no stripper can remove -- is itself the failure
     -> {10 1 {{editprop.c dtoa_eng rows {H6 K1 K2 K3} {#ifdef XSCHEM_NEVER}}}} (exp {10 0 {}}) : FAIL
RV5  FAIL: Z1 ... -> {10 1 {{editprop.c dtoa_eng rows {H6 K1 K2 K3} {#if 0 && 1}}}} (exp {10 0 {}}) : FAIL
RV6  FAIL: G3 draw_hcursor's " %.*g%c " readout clamps against S(tmpstr) - 2, paying for the
     two literal spaces -> {0} (exp {1}) : FAIL
```

Two differences from `C2-repair.md`, both in my favour of the repair: `RV1` and `RV4` redden
**`K3` as well as `K2`** (R2's `>= 0` repair working — the receipt reported `K2 K3` for V4 and
did not re-report V1), and nothing else changed.

**The repaired `#if 0` matcher, unit-probed on 15 spellings** (`probe4.tcl`, no build):
`#if 0`, `# if 0`, `#  if   0`, `#if 0 && 1`, `#if 0 /* x */` → **stripped**; `#if 0x10`,
`#if 01` → **kept and live**, as intended; `#if (0)`, `#if 0L`, `#if 00`,
`#if defined(XSCHEM_NEVER)`, `#ifdef XSCHEM_NEVER`, `#ifndef __unix__`, `#if HAS_CAIRO!=1`,
`#if !defined(__unix__) && HAS_CAIRO==1` → **kept**, i.e. left to sections Z1/Z2. `N11`
confirms `#if (0)` in `dtoa_eng` reddens `Z1`, and `G-Z2` confirms a non-allowlisted condition
in a Z1-excluded function reddens `Z2`:

```
N11   FAIL: Z1 ... -> {10 1 {{editprop.c dtoa_eng rows {H6 K1 K2 K3} {#if (0)}}}} (exp {10 0 {}}) : FAIL
G-Z2  FAIL: Z2 ... -> {4 1 {{draw.c show_node_measures rows {G5 G5b} {#ifdef XSCHEM_NEVER}}}} (exp {4 0 {}}) : FAIL
```

---

## 2. ⚠ ELEVEN NEW DECOYS THE REPAIR DOES NOT REACH — every one `ALL PASS (51 checks)`, rc 0

All eleven compile, link and produce a binary the suite calls clean.

| id | shape | what is really gone from the binary | verdict |
|---|---|---|---|
| **N1** | `if(0) precision = clamp_prec_g(precision, sizeof(s));` | dtoa_eng's clamp (C4) | **ALL PASS (51)** |
| **N2** | `#define ZZ_CLAMP_IT precision = clamp_prec_g(precision, sizeof(s));` — never invoked | dtoa_eng's clamp (C4) | **ALL PASS (51)** |
| **N3** | `{ static const char *zz = "precision = clamp_prec_g(precision, sizeof(s));"; (void)zz; }` | dtoa_eng's clamp (C4) | **ALL PASS (51)** |
| **N4** | `#ifndef __unix__` / G5's statement / `#endif` in `show_node_measures`; live code `int prec = xctx->ev_precision;` | `show_node_measures`' clamp | **ALL PASS (51)** |
| **N5** | `#if HAS_CAIRO!=1` / G9's statement / `#endif` in `waves_callback`; live clamp weakened to `S(sy) + 900` | the tooltip's `sy` bound | **ALL PASS (51)** |
| **N6** | `#if 1` / `#else` / G9's statement / `#endif`, same live weakening | the tooltip's `sy` bound | **ALL PASS (51)** |
| **N7** | new site in draw.c: `sprintf(zb, "%.*g", (clamp_prec_g(…), xctx->ev_precision), zv);` | nothing removed — a NEW unbounded site X1 accepts | **ALL PASS (51)** |
| **N8** | new site: `sprintf(zb, "%.*g", clamp_prec_g(xctx->ev_precision, 1024), zv);` into `char zb[24]` | a NEW site clamped against the WRONG size | **ALL PASS (51)** |
| **N9** | new UNCLAMPED site hidden behind a `//` that opens on the continuation line of a multi-line string | X1/X2 cannot see the statement | **ALL PASS (51)** |
| **N10** | new UNCLAMPED site hidden behind `dbg(1, "/*\n");` — `strip_block_comments` is not literal-aware | X1/X2 cannot see the statement | **ALL PASS (51)** |
| **N12** | a FIFTH unclamped `xctx->ev_precision = tclgetintvar("ev_precision");` behind the same `"/*"` | W4 cannot see the writer | **ALL PASS (51)** |

### 2.1 N1/N2/N3 really do lose the clamp — proved, not assumed

The pairing the sabotage crew used for `P1`. Control first:

```
KKONLY  kklex()'s writer clamp removed ALONE
        FAIL: W3 ...  FAIL: W4 ... {1 {{eval_expr.y x1}}}  FAIL: W6 ...
        RESULT: 3 FAILED (48 passed)        <-- B1 GREEN: dtoa_eng's clamp is carrying it
N1P     N1's decoy + the same removal
        FAIL: B1 the issue's own reproducer SURVIVES at ev_precision 200 and prints exactly 71
        significant digits ... (rc=134/SIGABRT-the-1606-overflow death=0 digits=0 r=<<absent>>) : FAIL
N2P     same -> rc=134/SIGABRT-the-1606-overflow
N3P     same -> rc=134/SIGABRT-the-1606-overflow
```

So on each of those three trees `dtoa_eng` has **no clamp**, the 1606 overflow is back, and the
suite reports 51/51. `N1` is the one to worry about most: **it uses no preprocessor at all**, so
no stripper and no directive invariant can ever see it, and `if(0) <the exact guard>` is a shape
a careless refactor really produces.

### 2.2 Why Z2's allowlist does not close Z1's exclusions

Measured (`probe2.tcl`): `config.h:14` is `#define HAS_CAIRO 1`, and `gcc -dM` gives
`#define __unix__ 1`. Of Z2's seven allowed conditions, **four are dead-code spellings on this
build**:

| allowlisted condition | on this build |
|---|---|
| `#if 0` | dead — but `cstrip` strips the region, so a decoy there dies (RV2) |
| `#if 1` | live — **but its `#else` branch is dead and Z2 never inspects `#else`** (N6) |
| `#if HAS_CAIRO==1`, `#if HAS_CAIRO == 1` | live |
| `#if HAS_CAIRO!=1` | **DEAD** — a decoy there is kept by `cstrip` and passes Z2 (N5) |
| `#ifndef __unix__` | **DEAD** — same (N4) |
| `#if !defined(__unix__) && HAS_CAIRO==1` | **DEAD** — same, untested but identical mechanism |

`N4` is the serious one: the sabotage crew's `S21` established that `G5` is the **only** fence on
`show_node_measures`' clamp (`X1` is blind there because the formats are `char *` variables), and
`N4` satisfies `G5` from a dead `#ifndef __unix__` region while the live code reads
`int prec = xctx->ev_precision;`. That is exactly `V6`'s severity at a different site.

### 2.3 Why N9/N10/N12 are hidden, and the control that proves it

`probe3.tcl` applies the same plants to a **copy** of `draw.c` in scratch and asks the suite's own
procs (tree untouched, no build):

```
N9 : planted sprintf in RAW=1 in CSTRIPPED=0 ; sprintf_stmts hits={}   bytes lost to cstrip=181699
N10: planted sprintf in RAW=1 in CSTRIPPED=0 ; sprintf_stmts hits={}   bytes lost to cstrip=182236
N12: writer-needle count RAW=1 CSTRIPPED=0                              bytes lost to cstrip=182238
N13: planted sprintf in RAW=1 in CSTRIPPED=1 ; sprintf_stmts hits={{sprintf(zb, "%.*g", xctx->ev_precision, zv);}}
pristine draw.c: raw=466246 stripped=284601 lost=181645
```

`N10` costs **591 extra bytes** of live code — `strip_block_comments` finds the `/*` inside the
string literal and runs to the next real `*/`. `N13` is the control: the same plant with **no**
hiding trick, built and run, reddens `X1` —

```
N13  FAIL: X1 every indirect-precision sprintf statement in the hand-written sources carries a
     clamp_prec_g ... -> {1 {{draw.c: sprintf(zb, "%.*g", xctx->ev_precision, zv);}}} (exp {0 {}}) : FAIL
```

— so `N9`/`N10`/`N12` are green *because the stripper hid the statement*, not for some other reason.

⚠ **This contradicts a sentence the repair shipped.** The `$SRC` glob comment says the
approximation on `.y`/`.l` *"can only make the stripper drop MORE text, never invent a `sprintf`
or a `tclgetintvar` -- and the rows below only ever hunt for those two shapes."* Dropping more
text is precisely how `W4`, `X1` and `X2` are defeated: they are **negative** rows, and hiding
the bad statement is a pass. Today nothing in the tree triggers it — my tokeniser found `/*`
inside a literal only in `parselabel.l` (30 lines, each with its `*/` on the same line) and **no
`//` line comment in code anywhere** — so this is a future blind spot, like the seven-file scope
was. Named, not fixed.

### 2.4 X1's blindness, bounded

`N7`/`N8` pass because `X1`'s test is `[string first {clamp_prec_g} $st] >= 0 { continue }` — the
**token**, in the statement, nothing about its result. For a **new** site that accepts a
discarded clamp, a swapped argument, the wrong buffer or the wrong size. The bound, measured:
at the **thirteen existing sites** the exact-text `G` rows do catch a swap —

```
SWAP-G6  clamp_prec_g(prec, (size_t)destsize) -> clamp_prec_g((int)destsize, (size_t)prec)
         FAIL: G6 graph_marker_fmt clamps against its own destsize parameter -> {0} (exp {1}) : FAIL
         FAIL: B6 ... (rc=0 death=0 n=1 digits=1 mx=1e-12T m=M1:1e-12T,1e+288T) : FAIL
```

So the swap family is closed where a row names the site, and open wherever `X1` is the only fence.

### 2.5 Shapes I tried that do NOT work, for the record

* **Trigraphs** (`??/` for `\`): gcc needs `-trigraphs`; the build does not pass it, so a
  trigraph-split statement does not compile. Not a decoy here.
* **A line-continuation split of the needle itself** (`clamp_prec_\` / `g(…)`): compiles, but
  `collapse` leaves `clamp_prec_ g(…)` and the row goes **red**. A false FAIL, not a defeat.
* **`#if 0` / `#else` / `<statement>` / `#endif`**: the `#else` branch is LIVE, so this is not a
  decoy at all — and R1(b)'s new clause is what keeps `X1` able to see it.

---

## 3. Every landed row reddens on a single removal

Each row was reddened by removing exactly the thing it fences, one cycle per row.

| landed row | the single removal | verbatim |
|---|---|---|
| `H2b` | `if(avail <= 9) return 1;` deleted from `clamp_prec_g` | `FAIL: H2b clamp_prec_g refuses an avail too small to hold any conversion, so `cap = avail - 9` can never underflow size_t and silently disable the clamp -> {0} (exp {1}) : FAIL` |
| `W5b` | the `xschem.h` `ev_precision` field comment reverted to its pre-fix text | `FAIL: W5b the Xschem_ctx.ev_precision FIELD comment in src/xschem.h names kklex() too, so the writer list the first reader trusts is complete -> {0} (exp {1}) : FAIL` |
| `W4b` | `actions.c` added to `$GENERATED` | `FAIL: W4b ... -> {1 {{actions.c scanned=0 should-be=1}} MISSING:actions.c} (exp {0 {} {}}) : FAIL` |
| `Z0` (×4) | each stripper repair reverted in turn: literal-unaware `//`; the `#if 0`-only matcher; the `#else`-at-depth-1 clause; `//` dropped from `cstrip` | four distinct `FAIL: Z0 …` lines, each showing the exact residue (`f("http:` / `#if 0 && 1 dead2;` / missing `live1;` / `// gone`) |
| `Z1` | a directive planted in a covered body | RV2/RV3/RV5/N11 above |
| `Z2` | `#ifdef XSCHEM_NEVER` in `show_node_measures` | `G-Z2` above |
| `B0` | `child_rc` collapsed to `return 1` | `FAIL: B0 … -> {1 1 1 1 1 1} (exp {134 134 124 1 139 -1}) : FAIL` **and** `FAIL: B0b …` |
| `B0b` | `child_rc` kept but **unwired** from `child` on the nogui arm | `FAIL: B0b … (rc=1/Tcl-error-in-the-FIXTURE-not-an-overflow death=0 z=alive done=0) : FAIL` — B0 stayed green, so B0b is not a duplicate of B0 |

**Product guards spot-checked** (the repair changed the stripper, which could in principle have
made an old row vacuous; it did not, and a stripper that drops *more* can only turn a positive
row red on a correct tree, which it does not):

| guard | rows reddened |
|---|---|
| `draw_hcursor`'s `- 2` alone | `G3` |
| `show_node_measures`' clamp alone | `G5` |
| `clamp_prec_g`'s `if((size_t)prec > cap)` | `H4` + `B1 B2 B3 B4 B5 B7 D1 D1b D2` (10 rows) |
| the C14 wrong-unit fix reverted | `G10` `D3` `D4` |

Every reddened behavioural row in those cycles now prints
`rc=134/SIGABRT-the-1606-overflow death=0` — R6 delivered, and `death=0` beside a real abort is
exactly what the section-B header says to expect.

---

## 4. Landed things whose single removal reddens NOTHING

Three, all measured, all comments or reporting aids rather than product guards:

```
G-R5a   the corrected D1FIX reachability paragraph replaced by the OLD FALSE sentence
        RESULT: ALL PASS (51 checks)   EXITCODE=0
G-R5b   graph_marker_fmt's provenance comment reverted to the 34913077 text
        RESULT: ALL PASS (51 checks)   EXITCODE=0
G-rcwhy `proc rcwhy` collapsed to `return $rc`
        RESULT: ALL PASS (51 checks)   EXITCODE=0
```

`R5a`/`R5b` are **declared** unfenced in `C2-repair.md` deviation 8, with a reason I accept (a
regexp over provenance prose would fence the wording, and the wording must stay free to be
corrected). `rcwhy` is **not** declared: it is called on every run, but its value only reaches
the transcript through a failing row's detail, so collapsing it leaves the suite green and only
costs the reader the `134/SIGABRT` phrasing. `B0` fences the decode; nothing fences the phrasing.
Minor, and I would not add a row for it.

Nothing else the repair landed is unfenced: all eight rows redden (§3), and no product guard
lost its fence.

---

## 5. The comments, checked for truth

### 5.1 R5a — the `D1FIX` reachability paragraph: correct conclusion, **stale quotation**

| claim in the new text | how checked | verdict |
|---|---|---|
| the old sentence ("shrinking ONLY `draw_cursor`'s tmpstr to 16 bytes aborts this fixture") is FALSE | cycle `L2`: `char tmpstr[100]` → `[16]` in `draw_cursor`, nothing else, rebuilt | ✓ `RESULT: ALL PASS (51 checks)` rc 0 |
| the mechanism — the clamp's `avail` IS `S(tmpstr)`, so 16 → cap 7 and precision 7 fits | `clamp_prec_g`: `if(avail <= 9) return 1; cap = avail - 9;` → 16-9 = 7 | ✓ arithmetic |
| `L2b` (tmpstr[16] **and** the clamp removed) reddens `D1` | cycle `L2b` | ✓ `D1` reddens — **and `G1` and `X1` redden too**, which the paragraph does not mention |
| the quoted detail `(rc=1 death=0 hasx=<<absent>> done=0 flags=<<absent>>)` | same cycle, on **this** tree | ⚠ **NO LONGER REPRODUCES**: it prints `(rc=134/SIGABRT-the-1606-overflow death=0 hasx=<<absent>> done=0 flags=<<absent>>)` |

The last row is the finding: the crew repaired the exit-status collapse (R6) **and** in the same
pass shipped a comment quoting a pre-repair `rc=1` detail as evidence. It is the same defect
class the paragraph exists to correct. One word each way to fix; not fixed here.

### 5.2 R5b — `graph_marker_fmt`'s provenance: TRUE, and I drove the half it labels MEASURED

| claim | how checked | verdict |
|---|---|---|
| the pre-fix text named no platform | `git show 34913077:src/draw.c` → *"`%.*g` made it consume the int `prec` AS THE DOUBLE (measured: "700.0000000000001136868377216160297393798828125" and a swallowed suffix)"* | ✓ no platform |
| the mechanism | `src/util.c`, the `#else` arm of `my_snprintf`: `i = va_arg(args, double)`, `strncpy(nfmt, fmt, l)`, `sprintf(nstr, nfmt, i)` — libc then looks for a precision that was never passed; `%c` is handled by the `'d'/'x'/'c'/'u'` arm with a later `va_arg(args, int)` | ✓ |
| `HAS_SNPRINTF` is not defined, so this arm is the compiled one | `src/util.c:500` says so; `/usr/bin/grep -rn HAS_SNPRINTF config.h` → no hit | ✓ |
| x86-64 SysV: **the double arrives INTACT and it is the SUFFIX that is eaten** | my own repro (`$SCRATCH/rp/abi.c`, `gcc -pipe -O2`): `vsprintf(b,"%.*g", 700.0)` → `[700]`; `vsprintf(b,"%.*g%c", 700.0, 'm')` → `[700]`, last byte `0x30` | ✓ direction and mechanism confirmed independently |
| the specific byte, `'m' came out as \004` | not re-driven — the garbage precision comes out of whatever integer register is live, so my harness swallows the suffix entirely instead of printing `\004` | ⚠ substance holds, exact byte **not** reproduced; an exact byte is a fragile thing to put in a comment |
| Win64 half is labelled derived, not driven | reading the comment | ✓ and `command -v x86_64-w64-mingw32-gcc` → nothing |

### 5.3 ⚠ THE THIRD WRONG COMMENT: Z2's justification sentence

Shipped in the suite, above `set Z2ok`:

> `## An `#ifdef XSCHEM_NEVER` is not on the list, so`
> `## the V3 decoy reddens here too -- which is why W1, W2, G5, G5b, G8, G9 and G10`
> `## are not left unfenced by Z1's exclusions.`

**Measured false.** `N4` defeats `G5` (and `G5b`'s site), `N5` and `N6` defeat `G9`, all three
using conditions **on Z2's own list**. The first clause is true (`#ifdef XSCHEM_NEVER` does
redden, `G-Z2`); the conclusion drawn from it is not. The row name carries the same overreach:
*"every conditional-compilation CONDITION is one this tree actually uses …, **so** a decoy
`#ifdef` reddens there too."*

Two smaller ones in the same section: `Z1`'s row name calls `#ifdef <undefined>` *"the one shape
no stripper can remove"*, and the file header calls it *"THE FOURTH SHAPE, WHICH A STRIPPER
CANNOT CATCH AT ALL"*. `N1` (`if(0)`), `N2` (`#define`) and `N3` (a string literal) are three
more shapes no stripper can remove, and section Z catches none of them.

### 5.4 Other figures in the new comments, re-measured

| claim | measured | verdict |
|---|---|---|
| the ten Z1 functions carry **no** conditional-compilation directive | `probe2.tcl` over `ccstrip`'d source: **zero `#` lines of any kind** in all ten, and `cfunc_raw` picks the right body in each (printed the first line of each) | ✓ |
| the four Z2 functions really need excluding, with 6 / 17 / 4 / 4 directive lines | same probe | ✓ exactly those counts, exactly those conditions |
| no `//` line comment in code anywhere in this tree | my own C tokeniser over all 43 scanned files: **0** | ✓ (and the CREW_BRIEF's premise really was wrong) |
| `#if 0`: "20 real regions in src/" | `/usr/bin/grep -c '^[ \t]*#[ \t]*if[ \t]*0'` over the 43 → **20** | ✓ |
| "(59 tree-wide)" lines containing `//` | **54** over the 43 scanned files; **59** only if the four GENERATED files are counted, which the same sentence excludes | ⚠ off by 5 |
| `"// sch_path: %s\n"` "(four netlisters)" | `spectre_netlist.c` and `verilog_netlist.c` only | ⚠ **two**, not four |
| `'/'` char literals "in a dozen files" | 11 files | ✓ close enough |
| `"//// begin user architecture code\n"` is a real format string | `spectre_netlist.c` (7 sites); `spice_netlist.c` uses `****` | ✓ |
| H2b's comment: "the smallest avail anywhere in this tree is 80 … every other caller passes 98 …, 100 or 1024" | 13 real call sites (not the receipt's *eleven*): 80 at `dtoa_eng`'s `sizeof(s)` and the three writers' `DTOA_ENG_BUFSIZE`; 98 ×2 (`S(tmpstr) - 2`); 100 ×5 (`draw_cursor`, `draw_cursor_difference`, `sx`, `sy`, `nd_view_set`'s `s`); 1024 ×1; **and `graph_marker_fmt`'s `(size_t)destsize`, whose four callers all pass `S(sx)`=80 from `char sx[80], sy[80], sdx[80], sdy[80]`** | conclusion ✓ (smallest is 80, so the guard is unreachable); the enumeration ⚠ omits `graph_marker_fmt`'s 80 while claiming to cover "every other caller" |
| `clamp_prec_g(200, 8)` = 1 and `"1e+287T"` is 8 bytes with the NUL | reading the helper; 7 chars + NUL | ✓ |
| `\b71\b` re-count (R7) | `/usr/bin/grep -n '\b71\b' src/*.c src/*.h src/*.y` minus the generated files → **7 hits, all in comments**: `draw.c:9071 :10658`, `xschem.h:3865 :3866 :3868 :3875`, `eval_expr.y:262` | ✓ exactly the corrected list; no literal 71 in C code |
| `hcases` still 80; `run_regression.tcl` still parses; issue stamps clean | `awk … | /usr/bin/grep -o '"[^"]*"' | wc -l` → 80; `tclsh tests/headless/issue_stamp.tcl` → `ISSUE-STAMP: ok (0 problems)` | ✓ |
| FLOOR 51 / 46, one `skip:` line | §6 | ✓ |

---

## 6. Check counts, both arms, and deviation 6's warning

On the final rebuilt binary (`make -C src` → `Nothing to be done for 'all'`):

```
$ tests/headless/run_suites.sh --nogui test_ev_precision_bound_1606
test home: throwaway /tmp/xschem-test-home.2071975.Ibc0NI (your HOME is untouched; …)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (51 checks)
RESULT: 1/1 runs passed

$ tests/headless/run_suites.sh test_ev_precision_bound_1606
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (51 checks)
RESULT: 1/1 runs passed
```

Third arm, driven **read-only** with `XSCHEM_DEVDISPLAY_DIR` pointed at an empty scratch dir so
`devdisplay.sh status` reports `state: foreign` (`:99` never started, stopped or viewed):

```
skip: D1 D2 D3 D4 -- tests/headless/devdisplay.sh status does not report the persistent dev
display alive, so the four draw.c cursor readouts and the callback.c measurement tooltip did not
run; bring it up with tests/headless/devdisplay.sh start. G1-G4 and G8-G10 fence the same clamps
statically on either arm
RESULT: ALL PASS (46 checks)
OVERALL: ok
EXITCODE=0
```

`/usr/bin/grep -c '^skip: '` = **1**; the reason ends `…on either arm`, so it is not a counted
shape. My own runner (`run1606.sh`, the same `--pipe -q --nolog --nogui --script` spelling
`run_suites.sh` uses, armed HOME, every row printed) agrees: 51 with `:99` up, 46 without.
A whole cycle — patch, build, suite, restore, build, suite — costs ~15 s; the suite itself 2.7 s.

**Deviation 6 confirmed exactly.** Forcing a recompile of `editprop.c`:

```
editprop.c: In function ‘dtoa_eng’:
editprop.c:231:11: warning: ‘__builtin___sprintf_chk’ may write a terminating nul past the end
of the destination [-Wformat-overflow=]
```
`/usr/bin/grep -c format-overflow` → **1** for the landed file, **0** for `34913077`'s
`src/editprop.c` compiled against the same tree (and the tree and binary were put back and
rebuilt afterwards; `src/editprop.c` md5 `0cd229ae2d4a48675dcc991c3772438d`, unchanged). Line 231
is the `n = sprintf(s, "%.*gMEG", precision, i);` arm, i.e. the one the comment says is safe
because it has already divided by 1e6. A clean `make -C src` costs one warning. Carried forward,
not fixed, ruling not mine.

---

## 7. Rebuild discipline and the tree at the end

43 cycles, `restored_green` true in all 43 and the driver never aborted; `restore_md5_mismatch`
empty in all 43; `build_rc` and `restore_build_rc` 0 in all 43. Restores are
`shutil.copyfile` + `os.utime(…, None)` — content only, mtime bumped, so `make` can never skip
the file (the `cp -a` trap). No figure here came from a tree that failed to compile, and no
patch was applied unless its anchor occurred exactly once.

```
$ md5sum   (vs the copies I took before the first cycle)
61a134eb5db1cd22d4a6926f135e4373  src/callback.c
1e1d5598e653bac3d3d560f2b6805f55  src/draw.c
0cd229ae2d4a48675dcc991c3772438d  src/editprop.c
061fb6d7cb99d7a61a580b1193101049  src/eval_expr.y
496af5d1093e465bdf66b615fec44779  src/save.c
e3352c38d3767b0282841d12d83d2b34  src/xinit.c
92f8526e87041409bf35c56323662f54  src/xschem.h
0d1936b1535a9169d6f4fc476998d3b7  src/actions.c        (never modified; probes used copies)
b664646fbd7f810341856c39f11326f0  tests/run_regression.tcl
8aa4e75969b1059c5f1eaf13512daa14  tests/headless/test_ev_precision_bound_1606.tcl
30d10f17954bc1e21d9af72946dcdb5c  src/eval_expr.c      (GENERATED; regenerated by the 4
                                                        eval_expr.y cycles, byte-identical to
                                                        the value Cv-sabotage.md recorded)
0672662827b0523d2c96bb1100cfc893  src/token.c   93775b70172028de18de0c4f5a583254  src/util.c
$ make -C src
make: Nothing to be done for 'all'.
$ git status --porcelain
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
 src/callback.c           | 20 +++++++++--
 src/draw.c               | 94 ++++++++++++++++++++++++++++++++++++++++--------
 src/editprop.c           | 51 +++++++++++++++++++++++++-
 src/eval_expr.y          | 10 +++++-
 src/save.c               | 15 +++++---
 src/xinit.c              |  6 +++-
 src/xschem.h             | 27 +++++++++++++-
 tests/run_regression.tcl | 43 +++++++++++++++++++++-
 8 files changed, 238 insertions(+), 28 deletions(-)
```

Byte-for-byte the state `C2-repair.md` describes, plus this receipt. Nothing committed; nothing
reverted; the owed ledger untouched; `~/dev/xschem-op-wcard` never opened; `:99` never started,
stopped or viewed (`xvfb: 3979908` before and after); no `/tmp/xschem_emergencysave_*` removed;
all scratch under the session scratchpad. The long-lived `xschem` processes under pid 843 are the
user's own sessions and were left alone.

---

## 8. What I could not measure

* **The `\004` byte** in `graph_marker_fmt`'s x86-64 half (§5.2): the mechanism and the direction
  I drove; the exact byte depends on live register contents and my standalone repro swallows the
  suffix instead.
* **The Win64 ABI** and a `--debug` (`-O0`, no FORTIFY) build: no toolchain, and the comment says
  so itself.
* **A behavioural proof for `N4`/`N5`/`N6`** that the weakened site can overflow: it cannot on
  this tree, because the writer clamps still cap `ev_precision` at 71 — which is the deliberate
  redundancy that makes those sites statically fenced only, and is why defeating the static fence
  is the whole finding.
* **A full T1 gate** and the neighbour suites. Those are the driver's, and CLAUDE.md's short-path
  rule applies to the gate clone.
* **`#if !defined(__unix__) && HAS_CAIRO==1`** as a decoy: not driven, identical mechanism to
  N4/N5 (`__unix__` is defined, so the region is dead and the condition is allowlisted).

## 9. Carried forward — named, not fixed

1. **Three decoy families defeat the C4 clamp with section Z in place**: `if(0)` (no
   preprocessor), a never-invoked `#define` (Z1/Z2 match only `if|ifdef|ifndef|else|elif`), and
   the statement inside a string literal. §2, §2.1. The cheap structural fix is to stop matching
   text and start matching *position*: require the needle to be the whole of a statement at
   statement position, once, and reject a body whose needle count differs from the number of
   times it appears outside a literal. Any of the three is a one-line refactor away in real life.
2. **Z2's allowlist admits four dead-code spellings**, so `W1 W2 G5 G5b G8 G9 G10` are still
   defeatable inside the Z1-excluded four. §2.2. Restricting the allowlist to conditions that are
   TRUE on this build (`#if HAS_CAIRO==1`, `#if HAS_CAIRO == 1`, `#if 1`) plus a `#else`-aware
   walk would close it; that costs measuring which branch is live, which is what the crew was
   trying to avoid.
3. **X1 is a token-presence test.** A new site may discard the clamp's result, swap its
   arguments or clamp against the wrong size and pass. §2.4. Existing sites are safe (exact text).
4. **The stripper can be made to swallow live code** — `//` on a string's continuation line, and
   `/*` inside a string literal — which defeats the negative rows `W4`/`X1`/`X2`. §2.3. Nothing
   in the tree triggers it today.
5. **A third false shipped claim** (Z2's justification) and a **stale quoted detail** (`rc=1` in
   the corrected `D1FIX` paragraph). §5.1, §5.3.
6. **Two small numeric slips** in new comments: "(59 tree-wide)" is 54 over the 43 files, and
   `"// sch_path"` is in two netlisters not four. §5.4.
7. **H2b's call-site enumeration omits `graph_marker_fmt`'s 80** while claiming to cover every
   other caller; the conclusion (smallest avail is 80) is right, and the receipt's *eleven* call
   sites are **thirteen**. §5.4.
8. **`rcwhy` is unfenced** and undeclared. §4. Cosmetic; I would not add a row.
9. **The fix costs one new `-Wformat-overflow=` warning.** §6. Deviation 6, re-measured and
   confirmed; needs the driver's ruling, not a crew's.
