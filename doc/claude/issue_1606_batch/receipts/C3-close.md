# Receipt C3 — close the CLASS, and name what is left

**Crew:** `close:C3`. Acting on `receipts/C2v-reprove.md` (the eleven decoys) and
`receipts/C2-repair.md` (what the last round landed). **This was the last fencing round**, so
the deliverable is one tokeniser, one preprocessor, one parsed sweep, one compiler row — and a
NAMED LIMITS paragraph for what static fencing cannot reach here.
**Tree:** `34913077` + Stage C/C2's working-tree edits + this stage's. Nothing committed,
nothing reverted. The product fix was touched in exactly one place, and gcc asked for it (Q6).
**Suite:** `tests/headless/test_ev_precision_bound_1606.tcl`, **51 → 58 checks** (46 → 53 with
no dev display), md5 `9b08fb9d2eb432adeb5aac527fe0ca02`, 1997 lines.
**Method:** 56 sabotage cycles, each a full `verify-pristine (md5 of all 8 files) → patch (the
anchor must occur EXACTLY ONCE) → make -C src → suite → restore (shutil.copyfile +
utime(None), never cp -a) → make -C src → require ALL PASS (58) again`. Driver
`$SCRATCH/sab.py`, run in the FOREGROUND every time (C2's incident 7). It never aborted on a
restore: `restored_green` and `md5ok` true in all 56, `build_rc` 0 in all 56.

---

## 0. Headline

**All eleven decoys from `C2v-reprove.md` are closed with evidence, and each one now reddens a
named row.** Four items came back with a correction to the brief rather than compliance, and
one of them changes the product:

1. **Q6 is a real product defect and gcc was right.** The MEG arm's static bound was violated
   (82 bytes into 80). Fixed with its own tighter clamp at `sizeof(s) - 2`; the warning is
   gone; **zero observable change**, driven to precision 4000 at both signs (§Q6).
2. **⚠ THE BRIEF'S Q6/Q8 HYPOTHESIS IS HALF WRONG AND THE MEASUREMENT IS BETTER THAN THE
   GUESS.** At the build's own flags, deleting dtoa_eng's clamp produces **ZERO** diagnostics —
   gcc gives up on an unbounded precision, exactly as `C2-repair.md` §7.1 said. At
   `-Wformat-overflow=2` it produces **three**. So the compiler row is **two** rows, and
   **N1 is FENCED after all** — by `Y1a`, at the one site where the clamp and the conversion
   share a translation unit. The named limit is narrower, and truer, than the brief assumed.
3. **⚠ Q5 RULE 1 ALONE DOES NOT CLOSE N7, AND NEITHER RULE CAN BE FENCED BY SABOTAGING THE
   TREE.** X1 is a negative row: weakening its strictness on a correct tree finds nothing, so
   both weakenings measured `ALL PASS`. The rules therefore get a unit row (`X1d`), and
   sabotaging *that* exposed two more shapes it could not see. Fourteen cases, not twelve (§Q5).
4. **⚠ Q4 IS CLOSED BY LIVENESS, AND THE ALLOWLIST IS GONE ENTIRELY** — not lengthened. No
   function had to be excluded by name: every condition in all four is decidable on this build.
5. **⚠ H2b's ENUMERATION MOVED IN A WAY NOTHING ANTICIPATED:** the new MEG clamp's
   `sizeof(s) - 2` == **78** is now the SMALLEST `avail` in the tree, below 80. Both comments
   corrected; the `avail <= 9` guard is still unreachable.

---

## 1. Q1 + Q2 — one C tokeniser, comments AND literals (closes N3, N9, N10, N12)

`strip_block_comments`, `strip_line_comments` and `strip_line_comment_1` are **replaced by one
proc**, `ctok`, which walks the text once tracking the four states a C character can be in and
returns a PAIR `{full code}`:

* `full` — comments removed, string and char literals **intact**;
* `code` — the same text, **the same length**, every literal's interior character replaced by
  `\x01` **except whitespace**, which is left alone so `collapse` cuts both halves at identical
  positions and an index into one stays comparable with an index into the other (K3 compares two).

`cfind`/`ccount` pick the half **by the needle**, so no row has to remember which to read:

```tcl
proc cs_half {cs needle} {
  if {[string first "\"" $needle] >= 0 || [string first "'" $needle] >= 0} {
    return [lindex $cs 0]
  }
  return [lindex $cs 1]
}
```

The argument is in the code: a needle with no quote in it **cannot straddle a literal
boundary**, because crossing one would require a `"` the needle does not contain — so "the match
starts at a code character" and "the whole match is code" are the same statement. A needle that
*does* carry a literal cannot be hidden inside an outer literal either, because the inner quotes
would have to be escaped (`\"`) and then it no longer matches.

Both `cfind` and `ccount` **keep the argument order of the proc they replace** (`string first`
takes (needle, hay); `scount` takes (hay, needle)), so a reader checking a row against the shape
they already know is not the person who introduces a silent swap. `W5`, `W5b` and
`doc_comment_before` still read the RAW file with `string first`, and the comment says why.

Literal awareness is now in the **block** path too. The old split (line stripper literal-aware,
block stripper naive) is what N9/N10/N12 walked through. Cross-line literal state is tracked: a
literal survives a newline only through a trailing `\`, which is N9's exact shape.

**The reassurance is deleted, in three places** (the `$SRC` glob comment, the old stripper
header, and `C2-repair.md`'s claim as quoted in the suite): over-stripping is **not** harmless,
because `W4`, `X1` and `X2` are NEGATIVE rows and hiding text from them is how you pass them with
a live unclamped site in the tree. The `.y`/`.l` approximation is now listed under NAMED LIMITS
instead of being excused.

**Fences:** `Z0` (the intact half, expected string) and `Z0b` (the blanked half, asserted as
found/not-found — the blanked half is a run of `\x01` nobody could read in a diff, so a string
comparison there would be noise). Both redden:

```
== S-Z0 the tokeniser made literal-UNAWARE again (no str/chr states)
   FAIL: Z0 the tokeniser removes block comments and `//` to end of line, and does NOT treat a
   `/*`, a `*/` or a `//` INSIDE a string or char literal as a comment -- including a `//` on the
   continuation line of a multi-line literal, which is where decoys N9, N10 and N12 hid live code
   from the negative rows -> {int a; int b; f("http: if(c == '/') g(); dbg(1, " still inside");
   live3; const char *zz = "precision = clamp_prec_g(precision, sizeof(s));"; live4; int z;}
   (exp {int a; int b; f("http://x"); if(c == '/') g(); dbg(1, "/*"); live1; dbg(2, "a\ b // not a
   comment"); live2; q("*/ still inside"); live3; const char *zz = "precision =
   clamp_prec_g(precision, sizeof(s));"; live4; int z;}) : FAIL
   FAIL: Z0b ... -> {0 0 0 1 1 1 1} (exp {1 1 1 1 1 1 1}) : FAIL

== S-Z0b blank_lit made a no-op: literal interiors no longer blanked
   FAIL: Z0b and in the literal-BLANKED half a statement parked INSIDE a string literal is
   unfindable, while all four live statements the hiding tricks tried to swallow are still found
   -> {0 1 1 1 1 1 1} (exp {1 1 1 1 1 1 1}) : FAIL

== S-cs_half cs_half made to always return the INTACT half -- the N3 defence undone
   FAIL: Z0b ... -> {0 1 1 1 1 1 1} (exp {1 1 1 1 1 1 1}) : FAIL
```

`S-Z0`'s got-value is the finding in one line: the naive tokeniser eats `//x"); … dbg(1, "/*` —
**three live statements gone**, which is a PASS for a negative row.

---

## 2. Q3 — every `^[ \t]*#` line (closes N2)

`Z1` matched `#(if|ifdef|ifndef|else|elif)`; it now matches **any** `^[ \t]*#`, at a CODE
position (so a `#` inside a literal is not a false directive). Re-measured: the ten bodies
contain **zero `#` lines of any kind**, so the widening costs nothing and closes `#define`,
`#undef`, `#pragma`, `#line` and `#include` at once.

```
== N2 a #define nobody invokes holds K2's statement; the real clamp deleted
   FAIL: Z1 none of the ten function bodies the static rows read carries ANY preprocessor line at
   all -- not a conditional and not a `#define` either -- so a decoy parked in one is itself the
   failure, whatever it is named
   -> {10 1 {{editprop.c dtoa_eng rows {H6 K1 K2 K3} {#define ZZ_CLAMP_IT precision =
      clamp_prec_g(precision, sizeof(s));}}}} (exp {10 0 {}}) : FAIL
   FAIL: Y1a ... (2 gcc diagnostics)

== S-Z1 a #define planted in nd_view_set, a Z1-covered body
   FAIL: Z1 ... -> {10 1 {{save.c nd_view_set rows G11 {#define ZZ_ONE 1}}}} (exp {10 0 {}}) : FAIL
```

---

## 3. Q4 — the allowlist is GONE; the question is now "is this region LIVE?" (closes N4, N5, N6)

`strip_if0` and the seven-spelling `Z2ok` list are both deleted. In their place:

* **`pp_table`** — the macro table, **MEASURED**: every `#define NAME <int>` in `./config.h`
  (`HAS_CAIRO 1 HAS_XCB 1 HAS_DUP2 1 HAS_POPEN 1`, 10 defined names) plus `__unix__ 1` from
  `$::tcl_platform(platform)`. The row prints it, so a reddened `Z3` says which build it was
  deciding for.
* **`pp_eval`** — three-valued (1 / 0 / **U**). `defined(X)` for an X not in the table is **U,
  not 0**: this suite does not know the whole macro universe and must not pretend to. Hex and
  integer suffixes are folded; anything left with a letter in it is U, which is also what makes
  the final `expr` safe (the string is checked against a digits-and-operators charset first, so
  it can hold neither a command substitution nor a variable reference).
* **`cs_pp`** — drops the DEAD branches, walks `#else`/`#elif` with a `taken`/`unknown` stack,
  keeps **every** branch of an undecidable chain, and keeps `#define`/`#include`/`#pragma`/
  `#undef` because `H5` reads a `#define`.

`Z2` shrinks to the one question a list cannot answer: **can this suite DECIDE every condition
in these four bodies, and is there any non-conditional directive in one?** Measured: all four are
fully decidable, so **no function had to be excluded by name** and no rows are left unfenced.

The three decoys die because the dead region is simply not there any more:

```
== N4 G5's statement in a DEAD #ifndef __unix__ inside show_node_measures; live code reads raw
   FAIL: G5 show_node_measures (NOT draw_graph_variables) clamps the local `prec` it prints its
   1024-byte tmpstr with -> {0} (exp {1}) : FAIL
== N5 G9's statement in a DEAD #if HAS_CAIRO!=1; live clamp weakened to S(sy) + 900
   FAIL: G9 the callback.c measurement tooltip's y readout clamps against its own 100-byte sy
   -> {0} (exp {1}) : FAIL
== N6 G9's statement in the DEAD #else of a #if 1; same live weakening
   FAIL: G9 ... -> {0} (exp {1}) : FAIL
```

**N4 was the worst decoy of three rounds** — `G5` is the only fence on `show_node_measures`
(`X1` is blind there, the formats being `char *` variables) — and it is closed by the mechanism
rather than by a spelling.

New fences, both sabotaged:

```
== S-Z3 cs_pp's #else made unconditionally LIVE (the `taken` test dropped)
   FAIL: Z3 cs_pp keeps the branches that are LIVE on this build and drops the ones that are dead
   -- walking `#else` and `#elif` -- while an UNDECIDABLE condition leaves every branch in place
   for Z1/Z2 to report, and a `#define` survives because H5 reads one
   (measured macro table={HAS_CAIRO 1 HAS_XCB 1 HAS_DUP2 1 HAS_POPEN 1 __unix__ 1}
    defined-names=10
    got={cairo_live; cairo_dead; unix_live; zero_else_live; one_live; one_else_dead;
         undecided_kept; #define KEPT_DEFINE 1 tail;}
    want={cairo_live; unix_live; zero_else_live; one_live; undecided_kept;
          #define KEPT_DEFINE 1 tail;}) : FAIL
   FAIL: Z4 ... -> {1 1 1 0 1 1 1 1 1} (exp {1 1 1 1 1 1 1 1 1}) : FAIL

== S-Z4 cs_pp made a no-op: cstrip stops resolving conditionals
   FAIL: Z3 ... got={#if HAS_CAIRO==1 cairo_live; #else cairo_dead; #endif #if HAS_CAIRO!=1 ...}
   FAIL: Z4 and the dead branches really are gone from the text the rows read: draw()'s
   `#if HAS_CAIRO!=1`, `#ifndef __unix__` and `#if !defined(__unix__) && HAS_CAIRO==1` bodies are
   absent from it and the `#else` of its live `#if HAS_CAIRO==1` is too, while that `#if`'s own
   body is present and the regions-KEPT text still has all of them
   -> {0 0 0 0 1 1 1 1 1} (exp {1 1 1 1 1 1 1 1 1}) : FAIL

== S-Z2 #ifdef XSCHEM_NEVER planted in show_node_measures, a Z2 function
   FAIL: Z2 ... and in the four functions Z1 excludes, every preprocessor line is a conditional
   whose condition cs_pp DECIDES on this build, so no row there can be satisfied from a region the
   compiler throws away and an undecidable condition is named here instead of guessed at
   -> {4 1 {{draw.c show_node_measures rows {G5 G5b} UNDECIDABLE {#ifdef XSCHEM_NEVER}}}}
      (exp {4 0 {}}) : FAIL
```

`Z4`'s last three clauses read the same statements out of the **regions-kept** text, so "absent"
can never mean "the statement was never in the file".

---

## 4. Q5 — X1 parses the statement instead of grepping it (closes N7, N8)

For every sprintf whose format literal carries a `%.*`:

1. `star_arg_index` computes the varargs index of the `%.*` precision from the format itself
   (every conversion before it consumes one argument, a `*` WIDTH consumes one of its own, `%%`
   consumes none), and the argument in **that position** must BE a `clamp_prec_g()` call and
   nothing else (`is_clamp_call`: the paren that closes the clamp must be the last character of
   the argument);
2. the clamp's own `avail` argument must **name the destination as a whole identifier**
   (`word_in`), so `S(tmpstr)`, `S(tmpstr) - 2`, `S(sx)`, `S(s)` and `sizeof(s) - 2` pass and a
   bare `1024` does not.

`call_args` splits at TOP-LEVEL commas only, reading the structure off the **blanked** half so a
comma or paren inside a literal cannot change the split. `sprintf_stmts` now also finds both the
`sprintf(` and the terminating `;` in the blanked half — the old version relied on "no format
string in this tree contains a `;`", which was true and was not a reason.

Two verbatim exemption lists, each itself a fence: `X1exempt` (dtoa_eng's `"%.*g%c"` and bare
`"%.*g"`, clamped one statement above the branch — **the MEG arm is no longer on it**, it now
passes both rules like any other site) and `X1sizeexempt` (graph_marker_fmt's, which takes its
buffer and its size as two separate parameters, so `(size_t)destsize` cannot name `dest`; only
rule 2 is waived, and `G6`/`G6b` fence the link instead).

```
== N7 a NEW site whose clamp is discarded through the COMMA OPERATOR
   FAIL: X1 ... -> {1 {{draw.c: `%.*` ARGUMENT IS NOT A clamp_prec_g() CALL
   ((clamp_prec_g(xctx->ev_precision, S(zb)), xctx->ev_precision)):
   sprintf(zb, "%.*g", (clamp_prec_g(xctx->ev_precision, S(zb)), xctx->ev_precision), zv);}}}
   (exp {0 {}}) : FAIL
== N8 a NEW site clamped against the WRONG size (1024 into char zb[24])
   FAIL: X1 ... -> {1 {{draw.c: the clamp's avail (1024) does not NAME the destination (zb):
   sprintf(zb, "%.*g", clamp_prec_g(xctx->ev_precision, 1024), zv);}}} (exp {0 {}}) : FAIL
```

### ⚠ 4.1 The deviation: a negative row cannot fence its own strictness

Sabotaging the two rules **at their use site** left the suite green, twice:

```
== S-X1-rule1 the `%.*` argument no longer required to BE a clamp call
   RESULT: ALL PASS (57 checks)   EXITCODE=0      <- FIRST ATTEMPT
== S-X1-rule2 the clamp's avail no longer required to NAME the destination
   RESULT: ALL PASS (57 checks)   EXITCODE=0      <- FIRST ATTEMPT
```

Of course: on a correct tree there is nothing for a weakened rule to miss. So the decision was
factored into `proc x1_verdict` and given a **unit row**, `X1d`, exactly as the stripper has
`Z0` and the preprocessor has `Z3`. **Sabotaging X1d then found two more shapes it could not
see**, and both are now cases:

* `4 + clamp_prec_g(p, S(zb))` — only rule 1 catches it, because rule 2 then reads the clamp's
  own second argument and is happy;
* `clamp_prec_g(p, S(zball))` for dest `zb` — only the whole-identifier test in `word_in`
  catches it, because `zb` is a substring of `zball`.

With fourteen cases, all four weakenings redden:

```
== S-X1-rule1  FAIL: X1d ... -> {ok ok bad bad bad bad ok bad ok ok ok exempt exempt skip}
                                (exp {ok ok bad bad bad bad bad bad ok ok ok exempt exempt skip})
== S-X1-rule2  FAIL: X1d ... -> {ok ok bad ok  bad ok  bad bad ok ok ok exempt exempt skip}
== S-is-clamp  FAIL: X1d ... -> {ok ok bad bad bad bad ok bad ok ok ok exempt exempt skip}
== S-word-in   FAIL: X1d ... -> {ok ok bad bad bad bad bad ok ok ok ok exempt exempt skip}
== S-star-idx  FAIL: X1d ... -> {ok ok bad bad bad bad bad ok ok exempt exempt skip}  (12-case run)
```

and the two exemption lists redden on a one-character edit to the statement they exempt:

```
== S-X1b dtoa_eng's bare %.*g arm edited
   FAIL: K3 ... FAIL: X1 ... FAIL: X1b the above-the-branch exemption is used by exactly
   dtoa_eng's two unclamped arms, both present -> {{sprintf(s, "%.*g%c", precision, i, suffix);}}
   (exp {{sprintf(s, "%.*g", precision, i);} {sprintf(s, "%.*g%c", precision, i, suffix);}}) : FAIL
== S-X1c graph_marker_fmt's statement edited
   FAIL: G6 ... FAIL: X1 the clamp's avail ((size_t)destsize) does not NAME the destination (dest)
   FAIL: X1c the destination-naming exemption is used by exactly graph_marker_fmt's statement,
   which takes its buffer and its size as separate parameters -> {}
   (exp {{sprintf(dest, "%.*g%c", clamp_prec_g(prec, (size_t)destsize), unit * v, suffix);}}) : FAIL
```

One honest note in the code: the `%.*` test itself **must** read the intact half (a `%.*` is by
definition inside a literal), and reading it there can only make the row consider MORE
statements, which is the safe direction for a negative row.

---

## 5. Q6 — the compiler warning was a real defect. Fixed, fenced, and zero observable change

### 5.1 The arithmetic, and why no sweep found it

`"%.*gMEG"` is `prec+7` chars for the `%.*g` plus `MEG` = `prec+10`, so `prec+11` bytes with the
NUL. The single clamp above the branch is sized for `"%.*g%c"` (`avail - 9`, giving 71), and
**71 + 11 == 82 > 80**. The bound really was violated. It never showed up in a sweep because
that arm divides by 1e6 first, so `|i|` lands in `(0.999999, 999.999]`, a double there has at
most ~55 exact significant decimal digits, and `%g` strips the rest.

### 5.2 The fix

`src/editprop.c`, in the `suffix == 'M'` arm only, with a 19-line comment on the line:

```c
      n = sprintf(s, "%.*gMEG", clamp_prec_g(precision, sizeof(s) - 2), i);
```

`sizeof(s) - 2` is the same accounting as `draw_hcursor()`'s `S(tmpstr) - 2` for its two literal
spaces: `avail` is the room left for the CONVERSION. Cap 69, and 69+11 == 80 exactly. The
`avail - 9` (cap 71) spelling is untouched for the suffix and bare arms, so **the C ceiling still
matches issue 1602's published 1..71** — and `src/xschem.h`'s contract now says in as many words
that 1..71 is the ceiling for *those two shapes* and that a format with more literal bytes gets a
lower one from the same formula.

### 5.3 The warning, verbatim before and after

BEFORE (`editprop.c` exactly as C2 left it, compiled with the build's own `CFLAGS` from
`Makefile.conf`):

```
gcc/before.c: In function ‘dtoa_eng’:
gcc/before.c:231:11: warning: ‘__builtin___sprintf_chk’ may write a terminating nul past the end
of the destination [-Wformat-overflow=]
  231 |       n = sprintf(s, "%.*gMEG", precision, i);
      |           ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
/usr/include/x86_64-linux-gnu/bits/stdio2.h:30:10: note: ‘__builtin___sprintf_chk’ output
between 5 and 82 bytes into a destination of size 80
```
`/usr/bin/grep -c '\[-Wformat-overflow=\]'` → **1**

AFTER (the landed file):
```
$ gcc $CFLAGS -c -o /dev/null editprop.c 2>&1 | grep -c warning                       -> 0
$ gcc $CFLAGS -Wformat -Wformat-overflow=2 -Wformat-truncation=2 -c -o /dev/null ...   -> 0
```

⚠ **And the whole-tree figure, stated precisely so nobody over-reads it.** A full rebuild
(`touch src/xschem.h; make -C src`) prints **six** warnings, all `-Wdiscarded-qualifiers` and all
**pre-existing**: `actions.c:557`, `util.c:222`, `save.c:7087`, `token.c:954/955/956`. Three of
those files are unmodified in this working tree and `save.c:7087` is outside every hunk of
`git diff src/save.c`, so none of them belongs to this batch. **`-Wformat*` diagnostics tree-wide:
zero.** This tree is not warning-free and never was; what the fix cost and has now repaid is one
`-Wformat-overflow`.

### 5.4 Zero observable change, driven to 4000 at both signs

96 strings — 12 precisions (`4 17 55 56 60 69 70 71 72 200 1000 4000`) × 8 values chosen to land
in the MEG arm, both signs, including the exact-digit worst cases — compared between a cap-71
binary and the landed cap-69 binary:

```
$ diff meg_old.txt meg_final.txt && echo IDENTICAL
IDENTICAL to the pre-fix (cap 71) output, all 96 strings
P4    V1.2345678901234567e7   LEN=8  R=12.35MEG
P4    V-1.2345678901234567e7  LEN=9  R=-12.35MEG
P4000 V1.2345678901234567e7   LEN=54 R=12.345678901234567348410564591176807880401611328125MEG
P4000 V-1.2345678901234567e7  LEN=55 R=-12.345678901234567348410564591176807880401611328125MEG
```

Longest output 54 chars at precision 4000, against a cap of 69 — the value range really does pin
that arm, which is why the defect was invisible and why the fix is arithmetic rather than
behaviour.

### 5.5 ⚠ THE NEW DIAGNOSTICS ROW IS TWO ROWS, AND THAT IS A MEASUREMENT, NOT A PREFERENCE

The brief asked for "a row that compiles the relevant sources and asserts zero
`-Wformat-overflow`/`-Wformat-truncation` diagnostics", and said the row "is the one fence that
would catch a clamp whose result never reaches the conversion". **Half of that is wrong at the
build's own warning level and right at level 2**, measured both ways:

| what was compiled | flags | clamp present | clamp deleted |
|---|---|---|---|
| `editprop.c` | build's own `CFLAGS` | 0 | **0** — gcc gives up on an unbounded precision |
| `editprop.c` | + `-Wformat-overflow=2 -Wformat-truncation=2` | 0 | **3** × `'%.*g' directive writing between 1 and 310 bytes into a region of size 80` |
| `draw.c` `callback.c` `save.c` | build's own `CFLAGS` | 0 | n/a |
| `draw.c` `callback.c` `save.c` | + level 2 | **7** × `'%.*g' directive writing between 1 and 310 bytes into a region of size 100/99` (4 in `draw.c`, 2 in `callback.c`, 1 in `save.c`) | n/a |

So:

* **`Y1a`** — `editprop.c` at **level 2**. Here the clamp and the three conversions are in the
  SAME translation unit, so gcc can bound the precision itself. This is the row that catches
  N1/N2/N3.
* **`Y1b`** — all four files that carry an indirect-precision sprintf, at the **build's own
  flags and nothing added**. This is the diagnostic a plain `make -C src` prints, which is how
  the MEG arm was found, and this repo reads `make` output.
* **Level 2 cannot be used on the other three files**: `clamp_prec_g` is defined in
  `editprop.c`, so gcc cannot see its return range across TUs and reports the seven
  `1 and 310 bytes` warnings above at correctly clamped sites. Those are not defects.
  **`-flto` was NOT driven** — named, not measured.

Both rows compile in parallel through one `sh -c … & … & wait`, assert the `.o` really appeared
(so a failed compile cannot read as "clean"), and **skip cleanly** with one lowercase `skip:`
line if `auto_execok gcc` finds nothing or `Makefile.conf` has no `CFLAGS` line. Cost: the suite
went from 2.7 s to **5.2 s** (3.9 s on the no-display arm).

Both redden:

```
== S-Y1b the MEG arm's own clamp reverted -- the gcc warning the fix removed
   FAIL: K3 ... FAIL: X1 `%.*` ARGUMENT IS NOT A clamp_prec_g() CALL (precision) ...
   FAIL: Y1a ... -> {1 {{editprop.c: src/editprop.c:258:11: warning: 'MEG' directive writing
      3 bytes into a region of size between 2 and 79 [-Wformat-overflow=]}} {}} (exp {0 {} {}}) : FAIL
   FAIL: Y1b ... -> {1 {{editprop.c: src/editprop.c:258:11: warning: '__builtin___sprintf_chk'
      may write a terminating nul past the end of the destination [-Wformat-overflow=]}} {}}
      (exp {0 {} {}}) : FAIL

== S-Y1a-only dtoa_eng's clamp deleted outright
   FAIL: K2 ... FAIL: K3 ...
   FAIL: Y1a ... -> {2 {{editprop.c: src/editprop.c:259:11: warning: '%.*g' directive writing
      between 1 and 310 bytes into a region of size 80 [-Wformat-overflow=]}
      {editprop.c: src/editprop.c:261:9: warning: '%.*g' directive writing between 1 and 310
      bytes into a region of size 80 [-Wformat-overflow=]}} {}} (exp {0 {} {}}) : FAIL
```

---

## 6. Q7 — three false comments and three slips, and one more slip of its own

| item | what it said | what it says now | how checked |
|---|---|---|---|
| (a) above `set Z2ok` | *"An `#ifdef XSCHEM_NEVER` is not on the list, so the V3 decoy reddens here too -- which is why W1, W2, G5, G5b, G8, G9 and G10 are not left unfenced by Z1's exclusions."* | the allowlist is **gone**; the false sentence is **quoted** in the new comment, marked measured-false by N4/N5/N6, each of which used a condition on that very list, and the mechanism (liveness) replaces the list. `Z2`'s row name no longer claims the conclusion | §3 |
| (b) `Z1`'s row name + the file header | *"the one shape no stripper can remove"* / *"THE FOURTH SHAPE, WHICH A STRIPPER CANNOT CATCH AT ALL"* | both gone. The section-Z header now **lists all ten** decoy shapes three rounds produced, with which mechanism handles each, and says in as many words: do not write "the one shape" of any of them | §7 |
| (c) `D1FIX`'s `L2b` quote | `(rc=1 death=0 hasx=<<absent>> done=0 flags=<<absent>>)`, and only D1 named | **RE-DRIVEN** and quoted as it prints now, with all **four** rows it reddens, plus a note that the paragraph which exists to correct a stale quoted probe had shipped one of its own | below |
| (d1) "(59 tree-wide)" | 59 lines containing `//` | **54** over the 43 hand-written files the sentence scopes itself to; 59 counts the four GENERATED files the same sentence excludes | `ls *.c *.h *.y *.l \| grep -v <the four> \| xargs /usr/bin/grep -c '//'` → **54** |
| (d2) `"// sch_path: %s\n"` "(four netlisters)" | four | **TWO** — `spectre_netlist.c` and `verilog_netlist.c`. `spice_netlist.c` writes `**`, `tedax_netlist.c` `##`, `vhdl_netlist.c` `--`. (A bare `grep 'sch_path: %s'` hits five files, which is probably where "four" came from) | `/usr/bin/grep -n 'sch_path: %s' *.c` |
| (d3) `'/'` "in a dozen files" | a dozen | **eleven** | `/usr/bin/grep -l "'/'"` over the 43 → 11 |
| (d4) H2b's "every other caller passes 98, 100 or 1024", *eleven* call sites | omitted `graph_marker_fmt`'s 80 | **all FOURTEEN sites enumerated with their avails**, in the suite AND in `src/editprop.c`. ⚠ And a figure nothing anticipated: the new MEG clamp's `sizeof(s) - 2` == **78** is now the SMALLEST avail in the tree | `/usr/bin/grep -n 'clamp_prec_g(' src/*.c src/*.h src/*.y` + every buffer declaration |

The re-driven `L2b`, verbatim, on this tree (`draw_cursor`'s `tmpstr[100]` → `[16]` **and** its
own clamp removed):

```
== L2b   RESULT: 4 FAILED (53 passed)   EXITCODE=1
   FAIL: G1 draw_cursor's "%.*g%c" readout clamps against its whole 100-byte buffer
        -> {0} (exp {1}) : FAIL
   FAIL: X1 ... -> {1 {{draw.c: `%.*` ARGUMENT IS NOT A clamp_prec_g() CALL (xctx->ev_precision):
        sprintf(tmpstr, "%.*g%c", xctx->ev_precision, gr->unitx * active_cursorx ,
        gr->unitx_suffix);}}} (exp {0 {}}) : FAIL
   FAIL: D1 a real graph draw with both cursors and both axis units SURVIVES at ev_precision 200
        on the dev display -- the four draw.c cursor readouts ... (rc=134/SIGABRT-the-1606-overflow
        death=0 hasx=<<absent>> done=0 flags=<<absent>>) : FAIL
   FAIL: D1b ... and the fixture really did arm both cursors AND both hcursors -> {<<absent>>}
        (exp {390}) : FAIL
```

`rc=1` → `rc=134/SIGABRT-the-1606-overflow`, and `D1b` is a fourth reddened row the old
paragraph did not mention (the child aborts inside the very redraw that would have printed
`FLAGS`).

**⚠ H2b's `avail` floor moved and the receipt says so out loud.** 78 is below the 80 the previous
text called "the smallest anywhere in this tree". `cap = 78 - 9 = 69 >= 1`, so the `avail <= 9`
underflow guard remains unreachable and H2b's conclusion is unchanged — but the sentence had to
be rewritten, not just re-counted.

---

## 7. Q8 — N1 has no static fix, and the NAMED LIMITS paragraph is the answer

No special case for `if(0)` was added. The suite's header now carries a block titled
**"NAMED LIMITS OF STATIC FENCING HERE — WHAT IS STILL OUT OF REACH, AND WHY THIS PARAGRAPH IS
THE DELIVERABLE RATHER THAN AN APOLOGY"**, and the section-Z header opens with the ten-shape
table and the instruction not to call any of them "the one shape no stripper can remove".

**The final text of the limits block** (from `tests/headless/test_ev_precision_bound_1606.tcl`):

> Each of three hardening rounds found a new decoy SPELLING, which is the signature of chasing
> spellings instead of classes. The classes are closed now (section Z). These are not, they are
> named on purpose, and none of them is closed by adding another regexp:
>
> 1. `if(0) precision = clamp_prec_g(precision, sizeof(s));` -- decoy N1. It uses NO
>    preprocessor, no comment and no literal: the text is at a true statement position and every
>    static row in this file must accept it. There is no principled static fix and a special case
>    for `if(0)` would only move the spelling on (`if(never)`, `while(0)`, `0 && (...)`, an `#if`
>    on a macro this suite cannot decide). ⚠ THE FENCE THAT DOES CATCH IT IS ROW Y1a, and only
>    there: with the clamp's result not reaching the conversion, gcc at `-Wformat-overflow=2`
>    reports `'%.*g' directive writing between 1 and 310 bytes into a region of size 80` three
>    times in editprop.c. MEASURED 2026-09-25. That works ONLY because clamp_prec_g and
>    dtoa_eng's three conversions are in the SAME translation unit. At the other TWELVE call
>    sites (two of the fourteen are dtoa_eng's own) gcc cannot see the clamp's return range across
>    TUs, so the same shape there is caught by NOTHING in this file. -flto was not driven.
> 2. A format string assembled from a macro or a variable -- `#define F "%.*g"` and then
>    `sprintf(b, F, p, v);`, or show_node_measures' real `char *fmt1/fmt2`. X1 cannot see a `%.*`
>    that is not in the statement. G5/G5b fence the one real instance BY VARIABLE NAME; a new one
>    would be unfenced by X1.
> 3. A decoy `#define DTOA_ENG_BUFSIZE` under an UNDECIDABLE `#ifdef` at file scope in
>    src/xschem.h, with the real macro raised. H5 is a whole-file row, so section Z (which reads
>    function BODIES) does not cover it. The behavioural digit-count rows do -- see the section-Z
>    header.
> 4. `.y` and `.l` are not C, so the tokeniser is approximate on them and can drop text. Dropping
>    text is a defeat for a NEGATIVE row, not a harmless over-strip. Today the only `.y`/`.l` row
>    is W3, which is positive.
> 5. Anything a sabotage puts in THIS FILE rather than in the product: D1b's own fixture, and the
>    two provenance comments R5a/R5b, are unfenced by construction and said to be
>    (receipts/C2-repair.md deviation 8).

**N1 is therefore reported as CLOSED-with-a-named-scope rather than open**, and that is the
opposite of what the brief expected:

```
== N1 if(0) in front of dtoa_eng's real clamp -- NO preprocessor at all
   RESULT: 1 FAILED (57 passed)   EXITCODE=1
   FAIL: Y1a src/editprop.c compiles with ZERO -Wformat-overflow/-Wformat-truncation diagnostics
   at level 2, where gcc can see clamp_prec_g's own return range -- so a clamp whose result never
   reaches the conversion (N1, N2, N3) is caught here and nowhere else in this file
   -> {2 {{editprop.c: src/editprop.c:260:11: warning: '%.*g' directive writing between 1 and 310
      bytes into a region of size 80 [-Wformat-overflow=]}
      {editprop.c: src/editprop.c:262:9: warning: '%.*g' directive writing between 1 and 310
      bytes into a region of size 80 [-Wformat-overflow=]}} {}} (exp {0 {} {}}) : FAIL
```

**Exactly one row**, which is the honest scope: Y1a is the only fence for that class, and only in
`editprop.c`.

---

## 8. The eleven decoys, re-run at the final tree — all eleven closed

Every row below is the verbatim reddened line (trimmed to the claim), one full cycle each, all
restored to `ALL PASS (58 checks)`.

| decoy | shape | now reddens | verbatim |
|---|---|---|---|
| **N1** | `if(0)` in front of the real clamp; no preprocessor at all | `Y1a` | `FAIL: Y1a ... -> {2 {{editprop.c: ...:260:11: warning: '%.*g' directive writing between 1 and 310 bytes into a region of size 80 [-Wformat-overflow=]} {... :262:9: ...}} {}} (exp {0 {} {}}) : FAIL` |
| **N2** | `#define ZZ_CLAMP_IT <the statement>`, never invoked | `Z1` `Y1a` | `FAIL: Z1 ... -> {10 1 {{editprop.c dtoa_eng rows {H6 K1 K2 K3} {#define ZZ_CLAMP_IT precision = clamp_prec_g(precision, sizeof(s));}}}} (exp {10 0 {}}) : FAIL` |
| **N3** | the statement inside a string literal | `K2` `K3` `Y1a` | `FAIL: K2 dtoa_eng clamps its own `precision` parameter against its own buffer -> {0} (exp {1}) : FAIL` |
| **N4** | `#ifndef __unix__` (DEAD) in `show_node_measures` | `G5` | `FAIL: G5 show_node_measures (NOT draw_graph_variables) clamps the local `prec` it prints its 1024-byte tmpstr with -> {0} (exp {1}) : FAIL` |
| **N5** | `#if HAS_CAIRO!=1` (DEAD) in `waves_callback` | `G9` | `FAIL: G9 the callback.c measurement tooltip's y readout clamps against its own 100-byte sy -> {0} (exp {1}) : FAIL` |
| **N6** | the DEAD `#else` of a `#if 1` | `G9` | `FAIL: G9 ... -> {0} (exp {1}) : FAIL` |
| **N7** | clamp discarded via the comma operator | `X1` | `FAIL: X1 ... -> {1 {{draw.c: `%.*` ARGUMENT IS NOT A clamp_prec_g() CALL ((clamp_prec_g(xctx->ev_precision, S(zb)), xctx->ev_precision)): sprintf(zb, "%.*g", (clamp_prec_g(xctx->ev_precision, S(zb)), xctx->ev_precision), zv);}}} (exp {0 {}}) : FAIL` |
| **N8** | clamped against 1024 into `char zb[24]` | `X1` | `FAIL: X1 ... -> {1 {{draw.c: the clamp's avail (1024) does not NAME the destination (zb): sprintf(zb, "%.*g", clamp_prec_g(xctx->ev_precision, 1024), zv);}}} (exp {0 {}}) : FAIL` |
| **N9** | `//` on a multi-line literal's continuation line | `X1` | `FAIL: X1 ... -> {1 {{draw.c: `%.*` ARGUMENT IS NOT A clamp_prec_g() CALL (xctx->ev_precision): sprintf(zb, "%.*g", xctx->ev_precision, zv);}}} (exp {0 {}}) : FAIL` |
| **N10** | `/*` inside a string literal | `X1` | same verbatim line as N9 |
| **N12** | a FIFTH unclamped writer behind the same `"/*"` | `W4` | `FAIL: W4 no hand-written source assigns xctx->ev_precision straight from tclgetintvar (i.e. there is no UNCLAMPED writer left) -> {1 {{draw.c x1}}} (exp {0 {}}) : FAIL` |

**None is still open.** The residual reach of each mechanism is in the NAMED LIMITS block (§7),
not here.

---

## 9. Every product guard re-checked for vacuity

The tokeniser and preprocessor were replaced wholesale, which could in principle have made an
old positive row vacuous. Five spot checks, one removal each:

| removal | rows reddened |
|---|---|
| `draw_hcursor`'s `- 2` | `G3` |
| `show_node_measures`' clamp | `G5` |
| `clamp_prec_g`'s `if((size_t)prec > cap)` | `H4` `Y1a` `B1 B2 B3 B4 B5 B7 D1 D1b D2` — **11 rows** |
| `kklex()`'s writer clamp | `W3` `W4` `W6` |
| the C14 second-defect fix reverted | `G10` `D3` `D4` |

All eleven behavioural details print `rc=134/SIGABRT-the-1606-overflow death=0`, and `Y1a` is a
new bonus fence on the cap.

---

## 10. Check counts, all three arms

Final rebuilt binary, `make -C src` → `Nothing to be done for 'all'`. 58 rows, in order:
`H1 H2 H2b H3 H4 H5 H6 K1 K2 K3 W1 W2 W3 W4 W4b W5 W5b W6 G1 G2 G3 G4 G5 G5b G6 G6b G7 G8 G9 G10
G11 X1 X1b X1c X1d X2 Z0 Z0b Z3 Z1 Z2 Z4 Y1a Y1b B0 B0b B1 B2 B3 B4 B5 B6 B7 D1 D1b D2 D3 D4`.

```
$ tests/headless/run_suites.sh --nogui test_ev_precision_bound_1606
test home: throwaway /tmp/xschem-test-home.2118113.NNHUd2 (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (58 checks)
RESULT: 1/1 runs passed

$ tests/headless/run_suites.sh test_ev_precision_bound_1606
test home: throwaway /tmp/xschem-test-home.2118485.nRsbI7 (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_ev_precision_bound_1606 run 1/1  RESULT: ALL PASS (58 checks)
RESULT: 1/1 runs passed
```

Third arm, **read-only**: `XSCHEM_DEVDISPLAY_DIR` pointed at an empty scratch dir so
`devdisplay.sh status` reports `state: foreign` and exits 1. `:99` was never started, stopped or
viewed — `xvfb: 3979908` before and after.

```
skip: D1 D2 D3 D4 -- tests/headless/devdisplay.sh status does not report the persistent dev
display alive, so the four draw.c cursor readouts and the callback.c measurement tooltip did not
run; bring it up with tests/headless/devdisplay.sh start. G1-G4 and G8-G10 fence the same clamps
statically on either arm
RESULT: ALL PASS (53 checks)
OVERALL: ok
EXITCODE=0
```

`/usr/bin/grep -c '^skip: '` = **1**; the reason ends `…on either arm`, so it is not a counted
shape. Runtime 3.9 s (no display) / 5.2 s (full), up from 2.7 s — the two gcc compiles.

**T1 bookkeeping:** `hcases` is still **80** entries
(`awk '/set hcases \[list/,/\]$/' … | /usr/bin/grep -o '"[^"]*"' | wc -l` → 80) and
`run_regression.tcl` still parses (`info complete` → 1), so this stage moves no T1 case or block
count. The `hcases` rationale comment and the suite's `FLOOR` line are both updated to
**58/53** and both name the seven new rows and this receipt.
`tclsh tests/headless/issue_stamp.tcl` → `ISSUE-STAMP: ok (0 problems)`.

---

## 11. Deviations, reported plainly

1. **The brief's Q6/Q8 claim that the compiler row catches "a clamp whose result never reaches
   the conversion" is FALSE at the build's own warning level and TRUE at level 2.** Measured both
   ways (§5.5). Consequence: two rows, not one, with level 2 scoped to `editprop.c` **by
   measurement** (the other three files report seven cross-TU warnings at level 2 that are not
   defects), and **N1 is fenced**, which Q8 assumed it could not be.
2. **Q5's rule 1 does not close N7 by itself** — rule 2 masks it — and **neither rule can be
   fenced by sabotaging the product**, because X1 is a negative row (both weakenings measured
   `ALL PASS`). So `x1_verdict` was factored out and given the unit row `X1d`; sabotaging `X1d`
   then exposed two shapes it could not see, and it has fourteen cases rather than twelve (§4.1).
   This is more machinery than the brief asked for, and it is the only way the rules are fenced.
3. **Q4 was done by deleting the allowlist, not by fixing it.** The brief allowed excluding a
   function by name if liveness could not be decided honestly; none had to be
   (§3). `strip_if0` is gone too — `#if 0` is now just one decidable condition among others.
4. **Q2's fence could not be one expected string.** The blanked half is a run of `\x01`, so `Z0b`
   asserts found/not-found on six statements instead. Said in the comment.
5. **H2b's floor moved to 78** because of my own Q6 fix — the smallest `avail` in the tree is no
   longer 80 (§6, d4). Both comments corrected. The guard stays unreachable.
6. **The "clean build" claim needs a qualifier I am adding rather than being asked for**: a full
   rebuild prints **six pre-existing `-Wdiscarded-qualifiers` warnings** (`actions.c:557`,
   `util.c:222`, `save.c:7087`, `token.c:954/955/956`), none of them this batch's. Zero
   `-Wformat*`. An incremental `make -C src` after touching only `editprop.c` prints none at all,
   which is what makes "0 warnings" easy to quote and wrong (§5.3).
7. **`"// sch_path: %s\n"` is in TWO netlisters, and a bare grep for `sch_path: %s` hits FIVE
   files** — which is most likely where the shipped "four" came from. The other three write
   `**`, `##` and `--` (§6, d2).
8. **The suite got slower**, 2.7 s → 5.2 s, all of it the two gcc invocations. They run in
   parallel through one `sh -c … & wait`. If that ever matters for the gate, `Y1b` is the
   expensive half (three files at `-O2`) and `Y1a` alone costs 0.4 s.
9. **`-flto` was not driven**, so whether LTO would let gcc bound the precision at the other
   twelve call sites is unmeasured and named as such.
10. **Not re-measured, inherited:** the `\004` byte in `graph_marker_fmt`'s provenance comment
    and the Win64 half (no toolchain), and a `./configure --debug` build. Same as `C2v-reprove.md`
    §8.

---

## 12. Rebuild discipline and the tree at the end

56 cycles: `restored_green` true 56/56, `md5ok` true 56/56, `build_rc` and restore `build_rc` 0
in 56/56, and the driver never aborted on a restore. Restores are `shutil.copyfile` + `os.utime(…, None)` —
content only, mtime bumped, so `make` can never skip the file (the `cp -a` trap). No patch was
applied unless its anchor occurred **exactly once**, and the driver **did** refuse once --
`ABORT: S-X1-rule1: anchor occurs 0 times (want 1)`, after the X1 loop moved into a proc and the
indentation of the line I was patching changed. Nothing was written on that run, and no figure
here comes from a partially patched tree. Every cycle ran in the **foreground**.

Four files changed by this stage; the other five are byte-identical to the md5s
`C2v-reprove.md` §7 recorded:

```
fefb92962705c2e17cd43590c78aaff5  src/editprop.c                                   CHANGED (the MEG clamp + H2b's comment)
04470631f53b7ea1ba7113d686cbb3fd  src/xschem.h                                     CHANGED (comment only: the avail contract)
2d375ecb3a327dcd0b3dc8bb6749a7ea  tests/run_regression.tcl                         CHANGED (rationale comment only)
9b08fb9d2eb432adeb5aac527fe0ca02  tests/headless/test_ev_precision_bound_1606.tcl   CHANGED (this stage's work)
1e1d5598e653bac3d3d560f2b6805f55  src/draw.c        (C2v: 1e1d5598e653bac3d3d560f2b6805f55)
61a134eb5db1cd22d4a6926f135e4373  src/callback.c    (C2v: 61a134eb5db1cd22d4a6926f135e4373)
496af5d1093e465bdf66b615fec44779  src/save.c        (C2v: 496af5d1093e465bdf66b615fec44779)
e3352c38d3767b0282841d12d83d2b34  src/xinit.c       (C2v: e3352c38d3767b0282841d12d83d2b34)
061fb6d7cb99d7a61a580b1193101049  src/eval_expr.y   (C2v: 061fb6d7cb99d7a61a580b1193101049)
30d10f17954bc1e21d9af72946dcdb5c  src/eval_expr.c   GENERATED; regenerated by the eval_expr.y
                                                    cycle, byte-identical to C2v's value
```

```
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
 src/editprop.c           | 80 +++++++++++++++++++++++++++++++++++++++--
 src/eval_expr.y          | 10 +++++-
 src/save.c               | 15 +++++---
 src/xinit.c              |  6 +++-
 src/xschem.h             | 27 +++++++++++++-
 tests/run_regression.tcl | 51 +++++++++++++++++++++++++-
 8 files changed, 274 insertions(+), 29 deletions(-)
```

The same eight tracked files and four untracked entries the brief describes. Nothing committed;
nothing reverted; the owed ledger untouched; `~/dev/xschem-op-wcard` never opened; `:99` never
started, stopped or viewed; no `/tmp/xschem_emergencysave_*` removed; no stray `.o` in `src/`
(the Y rows compile into the suite's own throwaway scratch dir); all scratch under the session
scratchpad.

## 13. What I could not measure

* **`-flto`**, and therefore whether gcc could bound the precision at the twelve call sites
  outside `editprop.c` (§5.5, §11.9).
* **A full T1 gate.** `hcases` is unchanged at 80 and `run_regression.tcl` still parses, so this
  stage moves no case or block count; the solo run and the short-path clone rule are the driver's.
* **Win64 / a `--debug` (`-O0`, no FORTIFY) build**, and the `\004` byte. Inherited, unchanged.
* **Whether `Y1b`'s 2.4 s matters in the gate.** It is 0.4 % of a 586 s T1.


---

## 14. CORRECTION, added by stage C4 (2026-09-25) — APPENDED, NOT REWRITTEN

Stage C4 (`receipts/C4-claims.md`) re-measured this receipt's claims and four of them are wrong. The
text above is left **exactly as it shipped**, because §11's NAMED-LIMITS block is a *quotation* of the
suite comment as it then stood and editing a quotation misreports the artefact. What is corrected is
corrected here and in the tree.

1. **"three times" is TWICE** (§11's quoted limit 1, and the suite's section-Y header). Under decoy
   N1, gcc at `-Wformat-overflow=2` reports `'%.*g' directive writing between 1 and 310 bytes into a
   region of size 80` **twice**, not three times, because the `"%.*gMEG"` arm now carries its own clamp
   and is bounded — so only two of `dtoa_eng`'s three conversions are unbounded. ⚠ **This receipt
   already contained the refutation**: the Y1a proof line quoted immediately below the limit block
   prints `-> {2 {…}}`. The comment contradicted the receipt it shipped with. Corrected in the tree.

2. **"caught by NOTHING in this file" at the other TWELVE call sites is false at eleven of them.**
   Measured, one site per class, as cycles `N1`, `Q_wgraph`, `Q_cur2` and `Q_snm2` of C4: of the
   fourteen `clamp_prec_g` call sites, **two** are `dtoa_eng`'s own and `Y1a` sees the shape,
   **three** are the writers and `W4`/`W4c` see it, **eight** are sprintf `%.*` arguments and `X1`
   sees it, and **exactly one is exposed** — `show_node_measures`, where the formats are `char *`
   variables so X1 is blind and the clamp is a separate `int prec = …` statement that an `if(0)`
   satisfies textually. `2 + 3 + 8 + 1 = 14`. The limit is **one site wide, not twelve**, and naming
   the site makes it useful. `Q_snm2` is the cycle that leaves the suite at `ALL PASS`.

3. **Y1a's row name claimed exclusivity for N1, N2 and N3; it holds for N1 only.** Re-measured:
   `N2` (the `#define` nobody invokes) also reddens `Z1`; `N3` (the statement inside a string literal)
   also reddens `K2` and `K3`. Corrected in the row name.

4. **§11.9's and §13's "the twelve call sites outside editprop.c"** inherit defect 2: read "the one
   site outside editprop.c that no row covers". What `-flto` might buy is still unmeasured, which is
   the part of those sentences that was right.

Three further things stage C4 found that this receipt did not claim wrongly but did not know:

* **`W4` and `X1` were single-literal-spelling matchers behind general names.** `C3v-final.md` §2.2
  measured three legal-C spellings walking through them; C4 closed them at the class level with
  punctuation normalisation (`cs_norm`, row `Z0c`) and by rebuilding `W4` around every WRITE to the
  field. `#define SP sprintf`, named in `C3v-final.md` §7 and never driven, is closed too (`M7`).
* **`Y1a`/`Y1b` had no anti-vacuity row**, and a single `-w` in the generated `Makefile.conf` silenced
  both — and with them the only fence N1 has. Row `Y1c` now compiles a snippet that must warn.
  §8's remark that "the suite got slower, all of it the two gcc invocations" is unchanged in kind:
  Y1c adds two more, both of a six-line file.
* **`H6` does NOT redden when `DTOA_ENG_BUFSIZE` is raised or shadowed** — the section-Z header said
  it did, and omitted `B4` from the list that does. Re-measured as C4 cycle `P05`:
  `rows=B1,B2,B3,B4,B5,B7,D2,H5`, no `H6`.

Check count at the end of C4: **63** with the dev display up, **58** without it, **60** with no
compiler. This receipt's 58/53 is the correct figure **for the tree it measured**.
