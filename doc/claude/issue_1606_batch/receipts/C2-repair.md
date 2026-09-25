# Receipt C2 — repair: the seven holes the independent sabotage found, closed

**Crew:** `repair:C2`. Acting on `receipts/Cv-sabotage.md`. **The product fix was not
touched except in two comments** (repairs R4a and R5b, both of which the sabotage crew
showed were saying more than they had measured). Everything else is the fencing.
**Tree:** `34913077` + Stage C's working-tree edits + this stage's. Nothing committed.
**Suite:** `tests/headless/test_ev_precision_bound_1606.tcl`, **43 → 51 checks**
(46 with no dev display, was 38).

**Method:** one thing removed at a time → `make -C src` → suite → restore with
`shutil.copyfile` (= `cp`, content only) **plus `utime(…, None)`** so `make` cannot skip
the file → `make -C src` → **require 51/51 green again before the next cycle**. A patch
is refused unless its target text occurs **exactly once**. **17 cycles at the final 51-row
configuration** (6 + 6 + 5, in three batches), every restore md5-verified against a
pristine copy and every one re-run to green — plus earlier cycles at intermediate row
counts, one of which is quoted in §3 because it is the vacuous-row finding.
Driver: `$SCRATCH/s/sab.py`; verbose runner `$SCRATCH/s/run1606.sh` (arms the throwaway
HOME through `tests/headless/test_home.sh`, then the same `--nogui --pipe -q --nolog
--script` spelling `run_suites.sh` uses, but prints every row so a verbatim `FAIL:` line
is visible). Per-cycle JSON: `$SCRATCH/s/out/matrix.jsonl`.

---

## 0. Headline

All seven repairs landed. **Six went in as specified; one (R6) the brief mis-stated and
I am correcting rather than complying with**, and two repairs came out stronger than
asked (R1 grew a second invariant row plus a unit row for the stripper; R3's first
attempt at its own anti-vacuity row was *itself* vacuous and had to be rewritten —
measured, §R3).

**One product-side observation that is nobody's repair and that I did not fix:** the
landed 1606 fix introduces a NEW compiler warning. Measured, §7.1.

---

## 1. R1 — `cstrip`'s three blind spots

### (a) `//` line comments — stripped, and STRING-LITERAL AWARE

`strip_line_comments` + `strip_line_comment_1` added; `cstrip` is now
`strip_if0 [strip_line_comments [strip_block_comments …]]`.

⚠ **The brief's premise was half wrong and the correction matters.** It said "the tree
does use it". **It does not.** I tokenised all 43 hand-written sources (`$SCRATCH/s/probe_lit.tcl`,
a proper C state machine over `src/*.c *.h *.y *.l`): **there is no `//` line comment in
code anywhere in this tree.** All 59 lines containing `//` are either inside a block
comment (e.g. `xinit.c:1291-1293`) or **inside a string literal**:

```
save.c:7293               if(strstr(f, "http://") == f || strstr(f, "https://") == f)
scheduler.c:251           my_snprintf(docurl, S(docurl), "file://%s%s", …)
spectre_netlist.c ×22     fprintf(fd,"//// begin user architecture code\n")
vhdl_netlist.c ×8, verilog_netlist.c ×5, node_hash.c ×2, svgdraw.c ×2, token.c ×1
plus '/' CHAR literals in actions.c, move.c, paste.c, psprint.c, save.c, scheduler.c,
util.c, xinit.c, eval_expr.y
```

So the reason to strip `//` is that **the build accepts one** (`gcc -pipe -O2`, no
`-ansi`, no `-pedantic` — decoy V4 compiled and linked), not that one exists. And it
means a **naive** `//` strip would have truncated real format strings and started
hiding `sprintf` statements from `X1`. The stripper therefore skips over string and char
literals, and only lines that actually contain `//` pay for the careful scan (59
tree-wide, so the cost is nil — see §3).

### (b) `#if 0` followed by ANYTHING

`^[ \t]*#[ \t]*if[ \t]+0[ \t]*$` → `^[ \t]*#[ \t]*if[ \t]+0([^0-9A-Za-z_].*)?$`. The
trailing class is what keeps `#if 0x10` and `#if 01` live. No existing line changes
behaviour: the only two `#if 0` lines in the tree with trailing text
(`callback.c:9383`, `scheduler.c:11358`) carry `/* … */` comments that the block
stripper has already removed by then, so the OLD regex matched them too.

**And one thing nobody asked for, found while doing it.** `#if 0 … #else <live> #endif`
was stripping the **live** else branch. `src/save.c`'s `read_raw_ascii_point` really has
one:

```c
        #if 0
        if(sscanf(line,"%lf", &d) != 1) { … }
        tmp[lines] = d;
        #else /* faster */
        tmp[lines] = my_atof(line);
        #endif
```

Over-stripping can only cause a **false FAIL** on a positive row, so it was not a hole
in the sabotage sense — but it is a place to hide an unclamped `sprintf` from the
negative rows `X1`/`X2`. `#else`/`#elif` at depth 1 now ends the dead region. It is the
only such region in `src/` (`$SCRATCH/s/probe_else.tcl` walked all 20 `#if 0` regions).

### (c) `#ifdef <undefined>` — the invariant, NOT a macro-name guess

⚠ **I checked the premise first, as the brief asked, and it is NOT true of every
function the rows cover.** Four of the fourteen legitimately carry
conditional-compilation directives:

| function | rows | its real directives |
|---|---|---|
| `draw_graph` | `W1` | `#if 0`, `#if 1`, `#if !defined(__unix__) && HAS_CAIRO==1` |
| `draw` | `W2` | `#if HAS_CAIRO==1` ×5, `#if HAS_CAIRO!=1`, `#ifndef __unix__`, `#else` |
| `show_node_measures` | `G5 G5b` | `#if HAS_CAIRO == 1` ×2 |
| `waves_callback` | `G8 G9 G10` | `#if HAS_CAIRO==1` ×2 |

So I did **not** weaken the invariant, and I did **not** leave those four unfenced
either. **Three rows instead of the one the brief asked for** — reported as a deviation
because it is more than was specified:

* **`Z1`** — none of the **ten** covered function bodies (`clamp_prec_g`, `dtoa_eng`,
  `draw_cursor`, `draw_cursor_difference`, `draw_hcursor`, `draw_hcursor_difference`,
  `graph_marker_fmt`, `graph_marker_text_rec`, `nd_view_set`, `kklex`) carries **ANY**
  `#if`/`#ifdef`/`#ifndef`/`#else`/`#elif`. The four above are excluded **by name, in a
  table that lists their real directives**, so nobody can quietly widen the exclusion.
* **`Z2`** — and inside those four, every `#if`/`#ifdef`/`#ifndef` **condition** is one
  of the seven this tree actually uses. `#ifdef XSCHEM_NEVER` is not on that list, so
  `W1 W2 G5 G5b G8 G9 G10` are fenced against the V3 shape too.
* **`Z0`** — `cstrip` itself, on a **synthetic** snippet. It has to be synthetic: the
  tree contains no `//` line comment, so the tree cannot fence the one repair most
  likely to be undone. Nine clauses, each a shape the sabotage or this tree produced.

`cfunc` was split into `cfunc_raw` (newlines kept — a directive is defined by being at
the start of a line) and `cfunc` (= `collapse` of it). Section Z reads through a new
`ccstrip` (comments out, `#if` regions **kept**), because Z's whole job is to find the
directives `cstrip` must leave behind.

**⚠ What section Z does NOT cover, stated rather than hidden:** `H5` greps the whole of
`src/xschem.h` for `#define DTOA_ENG_BUFSIZE 80`, not a function body. A decoy `#define`
under an undefined `#ifdef` there, with the real macro raised, would leave `H5` green —
but `H6` plus every "exactly 71 significant digits" assertion (`B1 B2 B3 B5 B7 D2`)
reddens on that tree, which is what the sabotage crew's cycle `S05` measured (raising
the macro to 100 gave a self-consistent binary printing 91 digits). Fenced
behaviourally, not twice statically.

### The proof — all four decoys now redden, verbatim

```
== V3 :: decoy: #ifdef XSCHEM_NEVER around dtoa_eng's clamp, real one DELETED
   RESULT: 1 FAILED (50 passed)   EXITCODE=1
   FAIL: Z1 none of the ten function bodies the static rows read carries ANY conditional-compilation directive, so an `#ifdef <undefined>` decoy parked in one -- the one shape no stripper can remove -- is itself the failure -> {10 1 {{editprop.c dtoa_eng rows {H6 K1 K2 K3} {#ifdef XSCHEM_NEVER}}}} (exp {10 0 {}}) : FAIL

== V4 :: decoy: // line comment holding dtoa_eng's clamp, real one DELETED
   RESULT: 2 FAILED (49 passed)   EXITCODE=1
   FAIL: K2 dtoa_eng clamps its own `precision` parameter against its own buffer -> {0} (exp {1}) : FAIL
   FAIL: K3 the three conversions the clamp protects are all still there, and the clamp is PRESENT and precedes the suffix branch -> {0} (exp {1}) : FAIL

== V5 :: decoy: #if 0 && 1 around dtoa_eng's clamp, real one DELETED
   RESULT: 3 FAILED (48 passed)   EXITCODE=1
   FAIL: K2 dtoa_eng clamps its own `precision` parameter against its own buffer -> {0} (exp {1}) : FAIL
   FAIL: K3 the three conversions the clamp protects are all still there, and the clamp is PRESENT and precedes the suffix branch -> {0} (exp {1}) : FAIL
   FAIL: Z1 none of the ten function bodies the static rows read carries ANY conditional-compilation directive, so an `#ifdef <undefined>` decoy parked in one -- the one shape no stripper can remove -- is itself the failure -> {10 1 {{editprop.c dtoa_eng rows {H6 K1 K2 K3} {#if 0 && 1}}}} (exp {10 0 {}}) : FAIL

== V6 :: draw_hcursor's `- 2` REALLY removed, G3's statement parked in a // comment
   RESULT: 1 FAILED (50 passed)   EXITCODE=1
   FAIL: G3 draw_hcursor's " %.*g%c " readout clamps against S(tmpstr) - 2, paying for the two literal spaces -> {0} (exp {1}) : FAIL
```

**V6 is the one that mattered** — the two bytes adjudication C11 exists to pay for — and
it now reddens on the named row, `G3`, not on a side effect. **V3 reddens on `Z1` only,
and that is correct by construction**: no stripper can remove `#ifdef XSCHEM_NEVER`, so
`K2` still finds the decoy's text; `Z1` is the fence, and its failing line names both
the function and the rows it is protecting.

### And the three Z rows / four stripper clauses are themselves sabotaged

```
== Z1 :: #ifdef XSCHEM_NEVER planted inside nd_view_set (a Z1-covered function)
   FAIL: Z1 ... -> {10 1 {{save.c nd_view_set rows G11 {#ifdef XSCHEM_NEVER}}}} (exp {10 0 {}}) : FAIL

== Z2 :: #ifdef XSCHEM_NEVER planted inside waves_callback (a Z1-EXCLUDED function)
   RESULT: 2 FAILED (49 passed)
   FAIL: G10 (second defect) the tooltip's y branch tests gr->unity, and the gr->unitx guard over a gr->unity body is gone -> {0} (exp {1}) : FAIL
   FAIL: Z2 ... -> {4 1 {{callback.c waves_callback rows {G8 G9 G10} {#ifdef XSCHEM_NEVER}}}} (exp {4 0 {}}) : FAIL

== Z0a :: the `//` stripper made literal-UNAWARE again
   FAIL: Z0 ... -> {int a; int b; f("http: if(c == '/') g(); #ifdef XSCHEM_NEVER kept_decoy; #endif live1; #endif int z;} (exp {int a; int b; f("http://x"); if(c == '/') g(); #ifdef XSCHEM_NEVER kept_decoy; #endif live1; #endif int z;}) : FAIL

== Z0b :: the `#if 0` matcher reverted to `#if 0` ONLY (pre-repair)
   FAIL: Z0 ... -> {… #if 0 && 1 dead2; #endif #ifdef XSCHEM_NEVER …} (exp {… #ifdef XSCHEM_NEVER …}) : FAIL

== Z0c :: the `#else`-at-depth-1 clause dropped (live else branch deleted again)
   FAIL: Z0 ... -> {int a; int b; f("http://x"); if(c == '/') g(); #ifdef XSCHEM_NEVER kept_decoy; #endif int z;} (exp {… #endif live1; #endif int z;}) : FAIL

== Z0d :: `//` stripping dropped from cstrip entirely (pre-repair)
   FAIL: Z0 ... -> {… f("http://x"); // gone if(c == '/') g(); // gone #ifdef …} (exp {… f("http://x"); if(c == '/') g(); #ifdef …}) : FAIL
```

`Z2`'s cycle also reddens `G10` incidentally (the decoy lands between `G10`'s asserted
`if(gr->unitx != 1.0)` and its `sprintf(sx,`, so the collapsed text no longer matches).
That is a bonus, not the fence; `Z2` is.

---

## 2. R2 — `K3`'s vacuous position clause

`string first` returns `-1` when the needle is missing, and `-1 < N` is true. Added
`>= 0` requirements on **both** indices (the branch anchor too, for the same reason) and
renamed the row "the clamp is **PRESENT** and precedes the suffix branch".

**Before (the sabotage crew's cycle S07): only `K2` reddened. Now, verbatim:**

```
== S07 :: dtoa_eng's clamp deleted outright (R2: K3 must redden too now)
   RESULT: 2 FAILED (49 passed)   EXITCODE=1
   FAIL: K2 dtoa_eng clamps its own `precision` parameter against its own buffer -> {0} (exp {1}) : FAIL
   FAIL: K3 the three conversions the clamp protects are all still there, and the clamp is PRESENT and precedes the suffix branch -> {0} (exp {1}) : FAIL
```

### Every other row checked for the same shape — none has it

`/usr/bin/grep -n 'string first' tests/headless/test_ev_precision_bound_1606.tcl`, all
34 hits classified:

| shape | rows | verdict |
|---|---|---|
| `[string first …] >= 0 ? 1 : 0` | `H2 H2b H3 H4 H5 H6 K2 W1 W2 W3 W6 G1 G2 G3 G4 G5 G6 G6b G7 G8 G9 G11` | **safe** — the `>= 0` IS the presence test |
| `[string first …] < 0 { continue }` / `>= 0 { continue }` inside a filter | `X1`, `X2` | **safe** — "does this statement contain `%.*` / a clamp", not a position |
| `[string first …]` inside `scount`, `strip_block_comments`, `sprintf_stmts`, `doc_comment_before` | helpers | **safe** — loop/scan bounds, each with its own `>= 0` or `< 0` test |
| **two `string first` results compared** | **`K3` only** | **was the bug; fixed** |

One near-miss worth naming rather than changing: `B6`'s fixture line uses
`[string range $mt [expr {[string first : $mt] + 1}] end]` to cut the marker label off
`"1: <x>,<y>"`. With no `:` that is `-1 + 1 = 0`, i.e. the whole string — **not** the
"-1 < N" shape, and the row still asserts `N == 1` and exactly 17 significant digits, so
a mis-parse changes the digit count. Left alone.

---

## 3. R3 — `W4`, `X1`, `X2` now really scan every hand-written source

The seven-name list is replaced by a `glob` over `src/*.c *.h *.y *.l` into a Tcl dict,
minus **four generated files excluded by name with the reason in the comment**:
`eval_expr.c` (bison ← `eval_expr.y`), `expandlabel.c` and `expandlabel.h`
(bison ← `expandlabel.y`), `parselabel.c` (flex ← `parselabel.l`). All four are
gitignored, absent from a fresh clone before a build, and CLAUDE.md forbids hand-editing
them. **Their `.y`/`.l` inputs are scanned.** `W6` separately fences a stale generated
`eval_expr.c`, so excluding it hides nothing.

**I did NOT have to narrow the names: scanning everything is cheap.** 43 files,
5.36 MB:

```
$ tclsh $SCRATCH/s/probe_sweep.tcl
files=43
cstrip elapsed 64 ms
W4 -> 0 {}                     W4 elapsed 65 ms
X1 -> 0 {}
X1b -> {sprintf(s, "%.*g", precision, i);} {sprintf(s, "%.*g%c", precision, i, suffix);} {sprintf(s, "%.*gMEG", precision, i);}
X2 -> callback.c draw.c editprop.c save.c
X elapsed 1 ms
TOTAL 130 ms
```

**130 ms for the whole tree**, and the answers are identical to the seven-file ones — so
the sabotage crew was right that no live site is missed today, and the over-claim really
was only in the names. `.y`/`.l` are not C, so `cstrip` is approximate there
(`parselabel.l`'s flex character classes contain stray `"` and `/*`); that can only make
the stripper drop **more** text, never invent a `sprintf` or a `tclgetintvar`, and it is
stated in the comment.

### The proof — the sabotage crew's C1 and C2 probes now redden

```
== C1 :: a FIFTH unclamped ev_precision writer planted in src/actions.c
   RESULT: 2 FAILED (49 passed)   EXITCODE=1
   FAIL: W4 no hand-written source assigns xctx->ev_precision straight from tclgetintvar (i.e. there is no UNCLAMPED writer left) -> {1 {{actions.c x1}}} (exp {0 {}}) : FAIL
   FAIL: B5 reading the cursor-B annotation (save.c nd_view_set) SURVIVES at ev_precision 200 and prints exactly 71 significant digits (rc=0 death=0 digits=91 v=1.000000000000000052504760255204420248704468581108159154915854115511802457988908195786371375e+299) : FAIL

== C2 :: a NEW unclamped indirect-precision sprintf planted in src/actions.c
   RESULT: 2 FAILED (49 passed)   EXITCODE=1
   FAIL: X1 every indirect-precision sprintf statement in the hand-written sources carries a clamp_prec_g, except dtoa_eng's three arms, which are clamped ONE STATEMENT ABOVE the branch -> {1 {{actions.c: sprintf(b, "%.*g%c", pp, v, 84);}}} (exp {0 {}}) : FAIL
   FAIL: X2 and the files carrying one are exactly the four this suite fences by name (a new file here is an unfenced site) -> {actions.c callback.c draw.c editprop.c save.c} (exp {callback.c draw.c editprop.c save.c}) : FAIL
```

(`C1` also reddens `B5` behaviourally, because the planted writer sits in
`set_dotsize_from_snap` and overwrites `ev_precision` unclamped on a path that reaches
`nd_view_set` — a free extra.)

### ⚠ And the anti-vacuity row for the new scope was ITSELF vacuous on the first try

`W4b` asserts the scanned set really is "glob minus exactly four". **My first version
derived its expectation from the same `$GENERATED` variable the scan uses, and was
therefore self-consistent and measured nothing** — declaring `actions.c` generated left
it GREEN:

```
== W4b :: the glob narrowed: actions.c declared GENERATED
   RESULT: ALL PASS (50 checks)   EXITCODE=0        <- FIRST VERSION, VACUOUS
```

Rewritten to write the four names out **a second time**, independently (the same
principle as `X1`'s verbatim exemption list — the exemption is itself the fence), and
to name `actions.c token.c xinit.c scheduler.c` plus the three `.y`/`.l` inputs
explicitly, by name rather than by count:

```
== W4b :: the glob narrowed: actions.c declared GENERATED
   RESULT: 1 FAILED (50 passed)   EXITCODE=1
   FAIL: W4b ... and the file list W4/X1/X2 scan is EVERY src/*.c *.h *.y *.l minus exactly the four GENERATED files -- the generated parsers' hand-written .y/.l INPUTS included, so excluding the twins excludes no source -> {1 {{actions.c scanned=0 should-be=1}} MISSING:actions.c} (exp {0 {} {}}) : FAIL
```

---

## 4. R4 — the two unfenced guards

### (a) `clamp_prec_g`'s `if(avail <= 9) return 1;` → row `H2b`, and the comment rewritten

The brief's correction is right and I verified every number in it. The old comment
("no room for a conversion at all; 1 is the floor 1602 allows") claimed more than the
line buys. The shipped comment now says, in `src/editprop.c`:

* it is an **UNDERFLOW guard, not a safety floor** — `cap = avail - 9` is `size_t`
  arithmetic, so `avail < 9` wraps to a huge cap and the clamp below becomes a **no-op**;
  removing the line does not lose a floor, it **disables the helper** for a small buffer;
* the returned `1` is **not itself safe** — `clamp_prec_g(200, 8)` returns 1, and
  `"%.*g%c"` at precision 1 on a three-digit-exponent value is `1e+287T` = 7 chars + NUL
  = **8 bytes, 9 with a sign** — so for `avail` in 2..9 an overflow is still possible;
* **the smallest `avail` anywhere in this tree is 80**, which I re-derived from all
  eleven call sites rather than taking it from the brief:

| site | `avail` |
|---|---|
| `dtoa_eng` | `sizeof(s)` = `DTOA_ENG_BUFSIZE` = **80** |
| `draw_graph`, `draw`, `kklex` (the writers) | `DTOA_ENG_BUFSIZE` = **80** |
| `graph_marker_fmt` | `(size_t)destsize`; every caller passes `S(sx)` etc. from `char sx[80], sy[80], sdx[80], sdy[80], ssl[80]` = **80** |
| `draw_hcursor`, `draw_hcursor_difference` | `S(tmpstr) - 2` = 98 |
| `draw_cursor`, `draw_cursor_difference` | `S(tmpstr)` = 100 |
| `waves_callback` (`sx`, `sy`) | `char sx[100], sy[100]` = 100 |
| `nd_view_set` | `char s[100]` = 100 |
| `show_node_measures` | `char tmpstr[1024]` = 1024 |

```
== H2b :: clamp_prec_g's `if(avail <= 9) return 1;` deleted
   RESULT: 1 FAILED (50 passed)   EXITCODE=1
   FAIL: H2b clamp_prec_g refuses an avail too small to hold any conversion, so `cap = avail - 9` can never underflow size_t and silently disable the clamp -> {0} (exp {1}) : FAIL
```

### (b) The `Xschem_ctx.ev_precision` FIELD comment → row `W5b`

The brief's argument is the right one: `W5` fences `xinit.c`'s comment over the **RAW**
file precisely because the comment IS the artefact, and the struct comment is the one a
reader hits first. `W5b` does the same, but **anchored**: a new `doc_comment_before`
helper takes the block comment that *immediately* precedes `int ev_precision;` (nothing
but whitespace between, and the declaration must occur exactly once), so a `kklex()`
mention anywhere else in this 4000-line header cannot satisfy it. It requires `kklex`,
`draw_graph` and `clamp_prec_g` in that comment.

```
== W5b :: xschem.h's ev_precision FIELD comment reverted to the pre-fix writer list
   RESULT: 1 FAILED (50 passed)   EXITCODE=1
   FAIL: W5b the Xschem_ctx.ev_precision FIELD comment in src/xschem.h names kklex() too, so the writer list the first reader trusts is complete -> {0} (exp {1}) : FAIL
```

---

## 5. R5 — the two wrong comments

### (a) FALSE, in the suite: `D1FIX`'s reachability sentence

Reworded exactly as the brief asked, and the sabotages that really prove it are named in
the comment (`L2b` and `L3` of `receipts/Cv-sabotage.md`, with `L3`'s direct
`*** buffer overflow detected ***` / rc 134 probe quoted). The comment now states the
false version explicitly, says it was **measured false**, and gives the mechanism
(the clamp's `avail` **is** `S(tmpstr)`, so shrinking the buffer shrinks the cap with it:
16 → cap 7, and precision 7 fits). The conclusion — the site is live — is unchanged and
independently proved.

### (b) UNSUPPORTED, in `src/draw.c` `graph_marker_fmt`: a Win64 measurement nobody made

I verified the provenance rather than taking it on trust:

```
$ git show 34913077:src/draw.c | /usr/bin/grep -n -A 14 "static void graph_marker_fmt"
7745-     * `*` precision, so "%.*g" made it consume the int `prec` AS THE DOUBLE
7746-     * (measured: "700.0000000000001136868377216160297393798828125" and a
7747-     * swallowed suffix). draw_cursor()/the measurement tooltip use raw sprintf
```

Confirmed: **the pre-fix comment carried the figure with no platform named at all**, so
the Stage C edit did upgrade an unattributed legacy figure into a claimed Win64
measurement — the exact move C5/C7 forbid, at the site C7 is about. Rewritten: the
x86-64 SysV half keeps its "MEASURED on this build: `'m'` came out as `\004`"; the Win64
half now reads "**WOULD** be consumed as the double", is labelled
"⚠ THAT HALF IS DERIVED FROM THE ABI, NOT DRIVEN", says no Windows toolchain exists in
this tree and nobody here has built one, and attributes the figure to "this comment's
OWN EARLIER REVISION (the text as of `34913077`), which named no platform at all — so it
is not a Win64 measurement either".

**Neither comment change is fenced by a row, and that is deliberate**, stated here so
nobody has to wonder: `W5`/`W5b` exist because those two comments carry a **writer list**
a reader substitutes for grepping. These two carry prose about provenance; a regexp over
them would fence the wording, not the claim, and the wording is what a future correction
has to be free to change.

---

## 6. R6 — the exit status. ⚠ THE BRIEF MIS-STATED THIS ONE

**Implemented: the real exit status.** `child` no longer does `set rc 1`. A new
`child_rc` decodes `::errorCode`, and a new `rcwhy` turns the number into a phrase so a
reddened line diagnoses itself. **Measured on both arms** with an `abort()` stub under
the suite's exact spellings (`$SCRATCH/s/rc.tcl`):

```
abort-direct   rc=1 errorCode=<CHILDKILLED 2003459 SIGABRT SIGABRT>
abort-timeout  rc=1 errorCode=<CHILDKILLED 2003460 SIGABRT SIGABRT>   <- the --nogui arm
abort-via-bash rc=1 errorCode=<CHILDSTATUS 2003462 134>               <- the :99 arm
exit1          rc=1 errorCode=<CHILDSTATUS 2003486 1>
timeout124     rc=1 errorCode=<CHILDSTATUS 2003487 124>
noexec         rc=1 errorCode=<POSIX ENOENT {no such file or directory}>
```

Both paths have to be decoded and 134 comes out of each, for two different reasons, both
now written into the suite's comment: GNU `timeout` **re-raises** the child's terminating
signal to itself and Tcl's direct child *is* `timeout` (`env` execs over itself), so the
headless arm gives `CHILDKILLED`; `devdisplay.sh`'s `cmd_exec` runs the command as
bash's **last** command, so bash exits 128+6 and the display arm gives `CHILDSTATUS 134`.

**⚠ THE CORRECTION.** The brief says "have the rows that expect the abort assert **134**
specifically". **There is no such row, and there cannot be one.** Every behavioural row
in this suite asserts **survival** — `rc == 0` — because the fix means nothing aborts;
the abort is the *pre-fix* behaviour, quoted in each row's name. So "assert 134" has no
row to attach to. What the repair actually buys is that a row which **does** redden now
names what happened instead of printing a uniform `(rc=1 …)`. Every behavioural detail
now reads e.g. `rc=134/SIGABRT-the-1606-overflow`,
`rc=124/TIMEOUT-of-the-suite-own-90s`, `rc=1/Tcl-error-in-the-FIXTURE-not-an-overflow`,
`rc=-1/exec-never-started-the-child`.

**And because the decode is now itself a guard, it gets its own rows** (the brief did not
ask for these; the repo's own fencing rule does): `B0` is a unit check of the decode on
the six `errorCode` shapes above, and `B0b` proves the decode is **wired into `child`**
by spawning a real child that `exit 134`s. Both redden together:

```
== B0 :: child_rc collapsed back to `return 1`
   RESULT: 2 FAILED (49 passed)   EXITCODE=1
   FAIL: B0 child_rc decodes the four errorCode shapes a spawned child can produce -- a signal death (SIGABRT), a plain non-zero exit, a timeout, and an exec that never started -- instead of collapsing them all to 1 -> {134 1 1 1 139 -1} (exp {134 134 124 1 139 -1}) : FAIL
   FAIL: B0b ... and `child` really returns it: a spawned child that exits 134 is reported as 134, so a reddened row below names the SIGABRT instead of a 1 (rc=1/Tcl-error-in-the-FIXTURE-not-an-overflow death=0 z=alive done=0) : FAIL
```

`B0b` deliberately uses `exit 134` rather than a real `SIGABRT`: signalling the child
would risk a core file in the scratch dir, and the `CHILDKILLED → 134` mapping is covered
by `B0`'s synthetic `errorCode` plus the measurement above.

**The `death=0` half.** Kept, and the section-B header now says in full why: `death` is a
column-0 `FATAL: signal` marker printed by `main.c`'s `sig_handler`, which does **not**
trap `SIGABRT`, so for this defect class no such line is ever printed — every reddened
row in the independent sabotage reported `death=0` while the child really had aborted
with rc 134. "The clause is correct but PERMANENTLY INERT for this defect class; it is
insurance against a DIFFERENT death (a trapped SIGSEGV, say) and never a second opinion
on this one. The rc is the signal here … read the `rc=` field, not `death=`."

---

## 7. R7 — the receipt's literal-71 enumeration

Corrected in `receipts/C-implement.md` (§1), with the original sentence quoted and
marked, because a receipt is a dated record. Re-measured on the same tree:

```
$ /usr/bin/grep -n '\b71\b' src/*.c src/*.h src/*.y
src/draw.c:9071        src/draw.c:10658                    <- 2, comments
src/xschem.h:3865 :3866 :3868 :3875                        <- 4, comments
src/eval_expr.y:262                                        <- 1, comment
src/eval_expr.c:1711                                       <- GENERATED (mirrors eval_expr.y)
src/parselabel.c:477 665 670 750 768 783 1261 1262 1263    <- GENERATED flex tables
```

**7 hand-written hits, all inside comments** — the old sentence said "two draw.c comments
and the generated `parselabel.c` tables", undercounting this stage's own new comments by
**five** and omitting the generated `eval_expr.c`. The claim it supports — no literal 71
in C **code** — holds. I also added a note beside that receipt's verbatim
`clamp_prec_g` code block, because it quotes the old `avail <= 9` comment that R4a
replaced.

### 7.1 ⚠ Product observation outside all seven repairs: the fix introduces a NEW compiler warning

Found while rebuilding, and it is **not** pre-existing. Measured by compiling both
versions of `editprop.c` against the same tree (my `editprop.c` differs from Stage C's
only in a comment, so this is Stage C's warning, not mine):

```
$ cp <34913077's editprop.c> src/editprop.c ; touch ; make -C src | grep -c format-overflow
0
$ cp <the fix's editprop.c> src/editprop.c ; touch ; make -C src | grep -c format-overflow
1
```

```
editprop.c: In function 'dtoa_eng':
editprop.c:231:11: warning: '__builtin___sprintf_chk' may write a terminating nul past
    the end of the destination [-Wformat-overflow=]
  231 |       n = sprintf(s, "%.*gMEG", precision, i);
/usr/include/x86_64-linux-gnu/bits/stdio2.h:30:10: note: '__builtin___sprintf_chk'
    output between 5 and 82 bytes into a destination of size 80
```

**Why the fix causes it:** before the clamp, `precision` was unbounded and gcc gave up;
with the clamp gcc *can* bound it (at 71) and then computes 5..82 bytes for the
`"%.*gMEG"` arm against an 80-byte `s`. gcc cannot see the thing the shipped comment
says makes that arm safe — that it has already divided by 1e6, which pins the output at
56-59 characters at any precision (the batch drove it to 4000). So **the warning is a
false positive on a claim that was measured**, and `B3`'s `4000` case exercises it.

**I did not fix it**, and I would not without a ruling: the obvious fixes each change
something. Clamping that arm against `sizeof(s) - 3` would silence gcc but contradicts
adjudication C4 ("ONE clamp, above the branch"), and it would lower the published
ceiling for `MEG` output. Carried forward for the driver: **a clean build is a property
this repo relies on when reading `make -C src` output, and this fix costs one warning.**

---

## 8. Every row added, and the counts

| row | asserts | why it exists |
|---|---|---|
| `H2b` | `clamp_prec_g` has `if(avail <= 9) return 1;` | Cv §2.1 — deleted, suite stayed green |
| `W4b` | the scanned file set is `glob(src/*.c *.h *.y *.l)` minus exactly the four generated names, with `actions.c token.c xinit.c scheduler.c` and the three `.y`/`.l` inputs named | anti-vacuity for R3's new scope; my first version of it was vacuous (§3) |
| `W5b` | the block comment immediately preceding `int ev_precision;` in `src/xschem.h` names `kklex`, `draw_graph` and `clamp_prec_g` | Cv §2.2 — reverted, suite stayed green |
| `Z0` | `cstrip` on a synthetic snippet: block comments; `//` to EOL but not inside a string or char literal; every `#if 0`-equivalent depth-counted with a live `#else` branch kept; an `#ifdef <undefined>` left alone | the tree cannot fence the `//` repair (no `//` line comment exists in it) |
| `Z1` | none of the ten covered function bodies carries ANY conditional-compilation directive | Cv §3.1 decoy V3 — the one shape no stripper can remove |
| `Z2` | in the four functions `Z1` excludes by name, every `#if`/`#ifdef`/`#ifndef` condition is one of the seven this tree uses | so `W1 W2 G5 G5b G8 G9 G10` are not left outside `Z1` |
| `B0` | `child_rc` decodes six `errorCode` shapes (`CHILDKILLED SIGABRT`→134, `CHILDSTATUS`→its code, `POSIX`→-1) | Cv §3.3; the decode is a new guard, so it needs a row |
| `B0b` | and `child` really returns it — a spawned child that exits 134 is reported as 134 | proves the decode is wired in, not just defined |

Repaired in place, no new row: `K3` (the `>= 0`), `W4`/`X1`/`X2` (the glob),
`cstrip`/`strip_if0`/`cfunc` (the stripper), `child` (the status), the `D1FIX` comment,
the section-B `death=0` paragraph, the header's stripper and SECTIONS paragraphs.

**Counts: 43 → 51 checks** with the dev display up, **38 → 46** without it. The `FLOOR`
comment in the suite header and the `hcases` rationale in `tests/run_regression.tcl` both
say so, and both name the eight new rows and this receipt.

`hcases` is still **80** entries
(`awk '/set hcases \[list/,/\]$/' … | /usr/bin/grep -o '"[^"]*"' | wc -l` → `80`), and
`run_regression.tcl` still parses (`info complete` → `1`), so T1's case/block figures are
unchanged by this stage: **99 cases / 98 blocks**, `skips=8` with the dev display up.

---

## 9. Both armed arms, on the final binary

```
$ tests/headless/devdisplay.sh status
display: :99      state: alive      screen: 1920x1080x24
wm: openbox (Openbox)               xvfb: 3979908

$ tests/headless/run_suites.sh --nogui test_ev_precision_bound_1606
test home: throwaway /tmp/xschem-test-home.2038995.NvigCl (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (51 checks)
RESULT: 1/1 runs passed

$ tests/headless/run_suites.sh test_ev_precision_bound_1606
test home: throwaway /tmp/xschem-test-home.2039345.HBEFAh (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (51 checks)
RESULT: 1/1 runs passed
```

### And the no-dev-display arm, driven read-only

`XSCHEM_DEVDISPLAY_DIR` pointed at an empty scratch dir, so `devdisplay.sh status`
reports `state: foreign` and exits 1. **`:99` was never started, stopped or viewed.**

```
skip: D1 D2 D3 D4 -- tests/headless/devdisplay.sh status does not report the persistent dev display alive, so the four draw.c cursor readouts and the callback.c measurement tooltip did not run; bring it up with tests/headless/devdisplay.sh start. G1-G4 and G8-G10 fence the same clamps statically on either arm
RESULT: ALL PASS (46 checks)
EXITCODE=0
```

Exactly one lowercase `skip:` line, 46 checks, exit 0; the reason text ends
`…on either arm` (not `FAIL`/`GOLD?`/`RESULT?`) and does not start with `FATAL`.

---

## 10. Deviations, and one incident in my own driver

1. **R1(c): three rows, not one** (`Z0`, `Z1`, `Z2`). One row could only have covered ten
   of the fourteen functions the static rows read, because four legitimately carry
   `#if HAS_CAIRO`/`__unix__` and the brief told me to exclude those by name. `Z2` closes
   them anyway (by condition allowlist), and `Z0` fences the stripper the tree cannot
   fence. §1(c).
2. **R1(b): one extra stripper fix nobody asked for** — `#else`/`#elif` at depth 1 now
   ends a `#if 0` region, because `src/save.c` really has a live `#else` branch that was
   being deleted. Over-stripping can only cause a false FAIL on a positive row, but it is
   a hiding place for the negative ones. §1(b).
3. **R1(a): the brief's premise was wrong** — this tree contains **no** `//` line comment
   in code; what makes the decoy work is that the build accepts one. The consequence is
   that the stripper had to be made literal-aware (there are real `"http://"` and
   `"//// begin …"` format strings) and that `Z0` had to be synthetic. §1(a).
4. **R3: my own first anti-vacuity row was vacuous** and I only found it by sabotaging
   it. Recorded with the green line it produced. §3.
5. **R6: the brief mis-stated the repair.** No row in this suite expects an abort, so
   "assert 134" had nothing to attach to; I implemented the real status, made every
   failing detail name it, and added `B0`/`B0b` to fence the decode. §6.
6. **A product observation outside the seven repairs: the landed fix costs one new
   `-Wformat-overflow` warning**, measured both ways. Named, not fixed. §7.1.
7. **An incident in my own driver, reported because it briefly put a sabotage in the
   tree.** I backgrounded one batch with `nohup … &`, then checked for survivors with
   `pgrep -c 'sab[.]py'` — **without `-f`**, so it matched the process *name* (`python3`)
   and returned 0 while the driver was still running. Exactly the "match by identity, not
   by pattern" trap CLAUDE.md names. The still-live driver then raced my restore and left
   the `Z0a` sabotage in the suite file **and in its own pristine copy**, so the md5
   self-check agreed with itself. Caught by running the suite (`FAIL: Z0 … f("http:`),
   repaired by hand, re-verified against the sabotage crew's own pre-C2 md5s (§11), and
   the affected cases were re-run **in the foreground**. No figure in this receipt comes
   from that window.

---

## 11. The tree at the end

Five source files this stage must not have touched, against the md5s
`receipts/Cv-sabotage.md` §5 recorded **before its first sabotage** — all five identical:

```
61a134eb5db1cd22d4a6926f135e4373  src/callback.c    (Cv: 61a134eb5db1cd22d4a6926f135e4373)
061fb6d7cb99d7a61a580b1193101049  src/eval_expr.y   (Cv: 061fb6d7cb99d7a61a580b1193101049)
496af5d1093e465bdf66b615fec44779  src/save.c        (Cv: 496af5d1093e465bdf66b615fec44779)
e3352c38d3767b0282841d12d83d2b34  src/xinit.c       (Cv: e3352c38d3767b0282841d12d83d2b34)
92f8526e87041409bf35c56323662f54  src/xschem.h      (Cv: 92f8526e87041409bf35c56323662f54)
```

Changed by this stage (md5 as shipped):

```
1e1d5598e653bac3d3d560f2b6805f55  src/draw.c                                      (comment only, R5b)
0cd229ae2d4a48675dcc991c3772438d  src/editprop.c                                  (comment only, R4a)
b664646fbd7f810341856c39f11326f0  tests/run_regression.tcl                        (rationale comment)
8aa4e75969b1059c5f1eaf13512daa14  tests/headless/test_ev_precision_bound_1606.tcl (the repairs)
```

```
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
 src/callback.c           | 20 ++++++++--
 src/draw.c               | 94 +++++++++++++++++++++++++++++++++++++-------
 src/editprop.c           | 51 +++++++++++++++++++++++-
 src/eval_expr.y          | 10 +++-
 src/save.c               | 15 ++++---
 src/xinit.c              |  6 ++-
 src/xschem.h             | 27 ++++++++++-
 tests/run_regression.tcl | 46 +++++++++++++++++++-
 8 files changed
```

The same eight tracked files and four untracked entries the brief describes. Nothing
committed; the owed ledger untouched; `~/dev/xschem-op-wcard` never opened; `:99` never
started, stopped or viewed; no `/tmp/xschem_emergencysave_*` removed; all scratch under
the session scratchpad.

---

## 12. What I could not measure

* **A full T1 gate.** Not in this stage's remit (the brief asks for `run_suites.sh` on
  both arms) and the driver holds the solo run. `hcases` is unchanged at 80 and
  `run_regression.tcl` still parses, so this stage moves no T1 count — but the
  `-Wformat-overflow` warning in §7.1 is worth the driver's eye before the gate.
* **The neighbour suites.** Unchanged by this stage; `Cv-sabotage.md` §6 already flags
  that Stage C's `test_wave_markers PASS (437 checks)` on the `:99` arm contradicts
  CLAUDE.md's standing issue-1488 `TIMEOUT` note. Still unadjudicated; still wants one
  look at the gate.
* **The Win64 ABI**, which is the whole point of R5b — no Windows toolchain here.
* **A `./configure --debug` (`-O0`, no FORTIFY) build**, so the out-of-bounds *read* into
  `xctx->tok_size` remains derived, exactly as `dtoa_eng`'s own comment says.
* **What the four `draw.c` cursor readouts formatted.** Still no read-back seam; `D1`
  asserts survival and `D1b` asserts the fixture armed all four paths.

## 13. Carried forward — named, not fixed

1. **The new `-Wformat-overflow` warning** the fix introduces at `dtoa_eng`'s
   `"%.*gMEG"` arm. §7.1. Needs a decision, not a patch.
2. **`H5` is a whole-file row, not a function-body one**, so section Z does not cover it;
   the behavioural digit-count rows do. §1(c).
3. **`clamp_prec_g`'s floor of 1 can still overflow a 2..9-byte buffer.** Unreachable
   today (smallest `avail` is 80) and now said so in the code. §4(a).
4. **`.y`/`.l` are not C**, so `cstrip` is approximate on them. It can only drop more
   text, never invent a `sprintf`. §3.
5. Everything on Stage C's and `Cv-sabotage.md`'s own carried-forward lists that this
   stage did not touch (`my_snprintf`'s `nstr[50]` arm, arbitrary Tcl from a `.sch`/`.sym`,
   the Tcl-side `1..71` literals, no read-back seam for `xctx->ev_precision`,
   `graph_marker_fmt`'s silent pointer-parameter overflow).
