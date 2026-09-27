# Stage C receipt — issue 1609, implement and fence

Worked in the isolated worktree `.claude/worktrees/agent-a17f441ee9e40fd5c`, based on `9fa31dd0`
(`docs(1609): Stage C brief`). x86-64 Linux, gcc 15.2.0, glibc with `_FORTIFY_SOURCE` active.
Scratch: `<scratchpad>/stageC_1609/`. Two files changed: `src/util.c` and
`tests/headless/test_snprintf_fmt_1608.tcl`. **Nothing registered in `tests/run_regression.tcl`** —
`/usr/bin/grep -c test_snprintf_fmt_1608 tests/run_regression.tcl` gives 2 (the `hcases` entry at
line 105 and the comment at 554), so the extended suite is already gated and needed no registration.

⚠ **THE WORKTREE WAS CREATED FROM A STALE BASE.** It arrived at `052b29f1` ("Add Claude Code GitHub
Actions workflow"), which predates the whole batch: no `doc/claude/issue_1609_batch/`, no
`test_snprintf_fmt_1608.tcl`, and the pre-condensation `CLAUDE.md`. I reset my own worktree branch to
`9fa31dd0` before reading anything, and ran `./configure` (the worktree had no `Makefile.conf`,
`config.h` or `src/Makefile`). **Worth checking for the next crew**, because a crew that did not
notice would have measured a tree from before issue 1608 and reported it as this one.

---

## 0. THE HEADLINE

**The fix is in and fenced. Check count 37 → 45** (armed spelling, both arms):

```
before  PASS | test_snprintf_fmt_1608  run 1/1  RESULT: ALL PASS (37 checks)
after   PASS | test_snprintf_fmt_1608  run 1/1  RESULT: ALL PASS (45 checks)   --nogui
after   PASS | test_snprintf_fmt_1608  run 1/1  RESULT: ALL PASS (45 checks)   display arm (:99)
```

Eight new rows, **M1–M8**. Nine single-guard sabotages driven, each restored with `cp` (never `cp -a`)
and rebuilt. Neighbouring suites green: `test_ev_precision_bound_1606` (63 checks),
`test_ps_valid_1350` (27 checks).

**And three things in STAGE_C.md are refuted — §5.** One of them (L2) is refuted in its *mechanism*
while its *conclusion* survives, which changes what a row can fence and is why row M8 exists.

---

## 1. WHAT CHANGED IN `src/util.c`

**`my_snprintf_spec_ok()`** gains an out-parameter and one guard:

* signature `(spec, len, nfmtsize, nstrsize, int *mod)`; `*mod` is set to `0`, `'l'` or `'h'` —
  the spec's one length-modifier character. The `p` and `g/e/f` arms pass `NULL`.
* **GUARD 2b**, `if(nmod) return 0;` — **at most one** length modifier. This is ONE guard covering
  both the repeated and the mixed case, deliberately, because two guards on one path means neither
  has a row that reddens on its own removal.

**The `d/x/c/u` arm of `my_snprintf()`**: the gate now runs *before* the fetch (it is what decides
`mod`; Stage A §2(b) established that `fmt` and `f` hold their final values there), and both the
fetch and the `sprintf` call branch three ways:

* `mod == 'l' && *f == 'd'` → `va_arg(args, long)` / `sprintf(nstr, nfmt, lv)`
* `mod == 'l' && (*f == 'u' || *f == 'x')` → `va_arg(args, unsigned long)` / `sprintf(nstr, nfmt, ulv)`
* everything else, **`%lc` included** → `va_arg(args, int)` / `sprintf(nstr, nfmt, i)`

Every 1608 guard is untouched and in the same order: GUARD 1, the `if(!refuse)` wrapper round the
`strncpy`, the (D) prefix guard with its `if(n < size) string[n] = '\0'`, and the refusal breaking
**after** the prefix write. On a refusal the fetched value is never used, because the `break` follows
the prefix write — so the fetch is left unconditional and the diff stays small.

**Comments.** New block `MY_SNPRINTF_FETCH_GUARD` after `MY_SNPRINTF_PREFIX_GUARD`; a new `GUARD 2b`
paragraph; and two count-bearing sentences rewritten (§5, R2).

**C89**: `/usr/bin/grep -c 'long long' src/util.c` → 0, and row M7 re-measures it every run.
`gcc -fsyntax-only -std=c89 -pedantic -Wall` on `src/util.c` adds no diagnostic of mine.
`-Wall` on the final file leaves exactly the two pre-existing warnings (`util.c:222`
`-Wdiscarded-qualifiers`, and the 1608 comment's `-Wcomment`, shifted 1147 → 1241). ⚠ I introduced a
third and removed it: the sentence `every src/*.c` put a `/*` inside a comment and `-Wcomment` caught
it. The build's own CFLAGS carry no `-Wall`, so `make` would never have shown it.

## 2. NEUTRALITY, DRIVEN BYTE FOR BYTE

Instrument: `<scratchpad>/stageC_1609/neutral_1609.c` + Stage A's `stubs_1609.c`, linked against
**the tree's own `src/util.o`** — the pre-fix object copied aside as `util_before.o` before the edit,
the post-fix one as `util_after.o`. Each line carries a plain-`sprintf` control for the same spec and
the same C type. `run_neutral.sh <util.o> <tag>` reproduces either table.

**Sections A+B — 32 lines, `diff` CLEAN.** The agreeing band `[0, 2^32)` (`%ld` of 0, 1, 65535,
4194303, `INT_MAX`, `INT_MAX+1`, `2^32-1`; `%lu` of 0, 6291739, `2^31+1`, `2^32-1`; `%lx` of 0 and
`2^32-1`; `[%12ld]`; `a=%ld b`), the live `%hu` of 65535, and every plain spec (`%hd`, `%d` of -1/-42/
`INT_MIN`, `%u` of -1/-42, `%x` of -1/-42, `%02x`, `%c`, `x=%c` of 233, `%10d`, `%-10d|`). **Section D
— `%lc` and `[%lc]` — also `diff` CLEAN.**

**Section C is the fix.** Every out-of-band line now matches its control:

```
                         BEFORE                AFTER = control
  %ld  4294967296        0                     4294967296
  %ld  4294967338        42                    4294967338
  %ld  -1                4294967295            -1
  %ld  -42               4294967254            -42
  %ld  INT_MIN           2147483648            -2147483648
  %ld  LONG_MAX          4294967295            9223372036854775807
  %ld  LONG_MIN          0                     -9223372036854775808
  [%12ld] 4294967338     [          42]        [  4294967338]
  a=%ld b 4294967338     a=42 b                a=4294967338 b
  %lu  4294967338        42                    4294967338
  %lu  ULONG_MAX         4294967295            18446744073709551615
  %lx  0x1234567890AB    567890ab              1234567890ab
  %lx  ULONG_MAX         ffffffff              ffffffffffffffff
```

**Section E is GUARD 2b.** `%lld`, `%llu`, `%llx`, `%hhu`, `%hhd`, `%lhd`, `%hld`, `%llld`, `%hhhhd`
all went from formatting to refused (`ret 0`, empty), and `X%lldY` from `X7Y` to `X`.

**The live getters, on the fixed binary, `DISPLAY=:99`, contained HOME** — identical to Stage A's
readings: `XMaxRequestSize=65535`, `XExtendedMaxRequestSize=4194303`, window id `4194580` (a plain
decimal; Stage A's was `6291739`), `first_sel` `0 -1 0` (Stage A had a selection and got `1 0 0`).

**The object code.** `objdump -dr` inside `my_snprintf`, before and after:

```
BEFORE, the one path:   16e2:  mov 0x10(%rsp),%r8d       <- 32-bit, for every spec
AFTER, the `d` path:    184d:  mov 0x40(%rsp),%r8        <- 64-bit  (lv)
AFTER, the `u`/`x` path: 1866: mov 0x30(%rsp),%r8        <- 64-bit  (ulv)
AFTER, everything else: 17f2:  mov 0x20(%rsp),%r8d       <- 32-bit, unchanged (i)
AFTER, the gate test:   17e3:  cmpl $0x6c,0x18(%rsp)     <- 0x6c == 'l'
```

⚠ **The object has FOUR `__sprintf_chk` call sites for FIVE source calls**: gcc tail-merges the two
wide paths, which reach the same epilogue with the same 64-bit register move. A reminder that a count
of source calls is not a count of object sites — neither number is written into any comment.

## 3. THE SABOTAGE → ROW MAPPING

Nine single-guard removals, each on the **finished** tree, each `make -C src` rebuilt, each restored
with `cp` and rebuilt again (`cmp` confirms the restore, and a `sed` that matched nothing aborts the
run rather than reporting a green). `sabotage.sh` + `rows.sh` in scratch; the per-run outputs are
`sab_f*.rows`.

| # | the single removal | reddened | the row it is mapped to |
|---|---|---|---|
| f1 | `d` branch fetch: `va_arg(args, long)` → `va_arg(args, int)` | **M1** M3 M7 M8 | M1 |
| f2 | `d` branch call: `sprintf(…, lv)` → `sprintf(…, i)` | G5 **M1** M3 | M1 |
| f3 | `u`/`x` fetch: `unsigned long` → `unsigned int` | **M2** M8 | M2 |
| f4 | `u`/`x` call: `sprintf(…, ulv)` → `sprintf(…, i)` | **M2** M3 | M2 |
| f5 | the modifier report: `if(mod) *mod = c;` deleted | **M1 M2** | M1, M2 |
| f6 | the `c` exclusion: `c` added to the `d` branch condition | **M8 only** | M8 |
| f7 | `ll` implemented: `long lv` → `long long lv` | **M7 only** | M7 |
| f8 | `u`/`x` fetch made SIGNED: `unsigned long` → `long` | **M8 only** | M8 |
| f9 | GUARD 2b: `if(nmod) return 0;` deleted | **M4 only** | M4, kept honest by M5 |

Each of the nine reddens at least one row, and **five of the nine are isolated to exactly one row**.
The collateral is honest: M3 (band neutrality) shares the `l` paths with M1/M2 by construction, and
M7/M8 are source-text rows whose anti-vacuity clauses read the very text f1 and f3 change.

⚠ **TWO OF THE GUARDS HAVE NO BEHAVIOURAL OBSERVABLE AT ALL, MEASURED, AND BOTH ARE FENCED ONLY BY
M8.** This is stated in M8's own name and in `MY_SNPRINTF_FETCH_GUARD`, not hidden:

* **f6 — the `c` exclusion.** With `c` routed into the `long` branch, `%lc` of 65 printed `A`,
  `[%lc]` printed `[A]`, `%c` of 233 still returned 3, and **every row in the file stayed green
  except M8**. The reason is structural: on x86-64 `va_arg` advances the same one eight-byte slot for
  `int` and for `long`, and glibc reads four bytes for `%lc` whatever was pushed. There is nothing to
  drive.
* **f8 — the `unsigned long` spelling.** With a signed fetch, M2's four outputs came back
  **byte-identical** (`4294967338`, `1234567890ab`, `18446744073709551615`, `ffffffffffffffff`) and
  only M8 reddened (`long_fetches=2 ulong_fetches=0`). See §5 R1.

## 4. THE EIGHT NEW ROWS

Six behavioural (in `gwp_rows`, so they self-skip together with the rest of section G/W/P when gcc or
the CFLAGS line is absent) and two source-text.

| row | what it asserts | instrument |
|---|---|---|
| M1 | a planted `long` outside the band formats as itself: 2^32+42, -1, `LONG_MAX`, `[%12ld]`, `a=%ld b` | driver + real `src/util.c` |
| M2 | a planted `unsigned long` outside the band: `%lu` 2^32+42 and `ULONG_MAX`, `%lx` 0x1234567890AB and `ULONG_MAX` | same |
| M3 | **neutrality in `[0, 2^32)`** — `%ld`, `%lu`, `%lx`, `[%12ld]` unchanged, plus G5's `%ld` 65535 and `%hu` 513 | same |
| M4 | GUARD 2b: nine repeated/mixed spellings refused, `X%lldY` keeps its `X`, **and the other two arms** (`X%llfY`, `X%llpY`) | same |
| M5 | anti-vacuity for M4: `%hd`, `%lc`, `[%lc]` still format (G5 holds the two live spellings) | same |
| M6 | issue 1612's boundary: `[%c]` of 233 returns 3 with length 3, not 1 with `]` | same |
| M7 | `long long` appears **zero** times in `live_code()`'s stripped `src/util.c`, and `va_arg(args, long)` does appear | source text |
| M8 | every `;`-statement of that stripped text whose whitespace-free form mentions `mod=='l'`: ≥4 of them, none names `'c'`, exactly one `va_arg(args, long)` and exactly one `va_arg(args, unsigned long)` | source text |

Each name says its method. M6 asserts the **return and the length**, not the bytes, because the
formatted byte is ≥ 128 and its text would be an encoding question rather than a measurement. M8
strips comments, `//` lines and depth-counted `#if 0` regions (via the existing `live_code`) and then
removes **all** whitespace, so `mod == 'l'` reformatted to `mod=='l'` is not a red.

Header work in the same file: named limit **L4** rewritten (it said `%ld`/`%lu`/`%hu`/`%hhd` still
mis-fetch and are not fenced — its original text is kept verbatim inside the new paragraph, because
five rows are now the answer to it), the **fence map** extended with the 1609 entries including the
two that are source-text-only, and W1's matcher comment de-counted (§5 R2).

## 5. WHAT I REFUTE

### R1. L2's MECHANISM IS REFUTED. The split is a TYPE requirement, not an OUTPUT one.

L2: *"a single **signed** `long` fetch would make `%lu` of `-1` print `18446744073709551615` where it
prints `4294967295` today. With the split, **every current output is preserved byte for byte**."*

Driven two independent ways, and **the signedness of the fetch changes no output at all on this ABI**:

```
$ <scratchpad>/stageC_1609/signedness   (same pushed argument, two va_arg types, same sprintf)
%lu    push unsigned long  signed_fetch=|18446744073709551615| unsigned_fetch=|18446744073709551615| same
%lu    push long           signed_fetch=|18446744073709551615| unsigned_fetch=|18446744073709551615| same
%lx    push unsigned long  signed_fetch=|ffffffffffffffff|     unsigned_fetch=|ffffffffffffffff|     same
%ld    push long           signed_fetch=|-1|                   unsigned_fetch=|-1|                   same
```

and at the site, sabotage f8: with `va_arg(args, long)` in place of `va_arg(args, unsigned long)`,
**M2's four outputs are byte-identical** and only the source-text row reddens. Both fetches read the
same eight bytes, and `%lu`/`%lx` reinterpret them regardless of the C type handed to `sprintf`.

**The conclusion survives, for the reason Stage A's own §6 gave and L2 did not carry forward**:
`va_arg` with a type not compatible with the argument's promoted type is undefined behaviour, and the
signed/unsigned exception applies only while *"the value is representable in both types"* — which a
full-range `unsigned long` is not. So the split is right, and **no behavioural row can fence it**.
That is why M8 asserts the spelling over the text, and why this is written into
`MY_SNPRINTF_FETCH_GUARD` rather than left as a preference.

### R1b. And "every current output is preserved byte for byte" needs scoping, or it is false.

`%lu` of `ULONG_MAX` goes from `4294967295` to `18446744073709551615`, and `%hhd`/`%hhu` go from
formatting to refused. **Nothing could preserve the first**: printing `4294967295` for `ULONG_MAX`
*is* the defect. The defensible property, which is what M3 asserts and §2 drives, is: **every value in
the agreeing band `[0, 2^32)` — exactly the set live callers can produce — and every plain spec is
byte-identical.** Outside the band the output changes on purpose. K3 still holds and no ruling is
owed, for Stage A's reason: `Display.max_request_size` is an `unsigned` and an XID is a CARD32.

### R2. L5 IS REFUTED IN ITS MECHANICS. W1's permitted list needed NO edit; three COUNTS did.

L5: *"Branching the `sprintf` call adds one. **Update `W1`'s permitted list in the same commit**."*

W1 permits by the text `sprintf(nstr, nfmt,` — **up to the comma** — so it already covered
`sprintf(nstr, nfmt, lv)` and `sprintf(nstr, nfmt, ulv)`. Driven: W1 green throughout, detail
`offending={} total_nonliteral_diags=7 missing={}` (Stage A measured 5 on the clean pre-fix tree; the
two new util.c sites make 7, and the two `draw.c` ones are unchanged). The matcher is unmodified.

**What did need changing were three sentences quoting counts**, which is named limit L9 and not L5:
`src/util.c`'s *"THE THREE `sprintf(nstr, nfmt, i)` CALLS BELOW"* and *"(util.c, three sites; draw.c
has two more)"*, and W1's own comment *"the three `sprintf(nstr, nfmt, i)` calls"*. All three are now
shape-only, each with a sentence recording that 1609 falsified the number in the same week it was
read. The *shape* count ("the two permitted shapes") is the sentence's own enumeration, which L9
explicitly allows, and is still two.

### R3. GUARD 2b CLOSES TWO DEFECTS NEITHER STAGE_C.md NOR THE ISSUE FILE NAMES.

GUARD 2b lives in the shared gate, so it reaches the `p` and `g/e/f` arms too. Driven against
`util_before.o` and `util_after.o`:

```
            BEFORE                        AFTER
X%llfY      ret=6  |X-nanY|               ret=1  |X|     <- `ll` on a FLOAT conversion. 1.5 was
                                                            pushed correctly; glibc's `%llf` is
                                                            undefined and reports no error.
X%llpY      ret=6  |X0x58Y|               ret=1  |X|
X%hhpY      ret=6  |X0x58Y|               ret=1  |X|
X%lpY       ret=6  |X0x58Y|               ret=6  |X0x58Y|   <- unchanged, single modifier
X%hpY       ret=6  |X0x58Y|               ret=6  |X0x58Y|   <- unchanged
X%LfY       ret=1  |X|                    ret=1  |X|        <- already refused by GUARD 2
```

`X%llfY` → `X-nanY` is the sharper one: a `-nan` out of a correctly-pushed `1.5`, with no door and no
complaint. Both are now fenced by rows `MO` and `MP` inside M4, and M4's name says the guard is
arm-independent. **`%lp` and `%hp` stay accepted-and-ignored** — a single modifier, and STAGE_C's
carried-forward note about them stands unchanged for those two spellings only.

### R4. What I did NOT refute, checked rather than assumed

* **L1** (fetch by modifier, not cast at the call sites) — implemented as adjudicated; W1/W2 green.
* **L3** (`%lc` stays on the `int` fetch, no normalisation) — implemented; M6 and M8 fence it. Issue
  1612's trigger is still unreachable: the tree has no `%lc` and no non-literal format.
* **L4** (`ll` refused, not implemented) — implemented; M7 fences it. Every spelling L4 lists
  (`%lld %llu %llx %hhd %hhu %lhd %hld %llld %hhhhd`) is refused, and `%zd %jd %td %qd %I32d %*d %nd`
  are still refused by GUARD 2 (rows G2/G3/G4 green).
* **L6** (plant a value; Stage A's stub file works) — Stage A's `stubs_1609.c` was copied verbatim and
  links clean. The suite's section G uses its own equivalent stub set, unchanged.
* **L8** — the psABI clause is quoted verbatim from the artefact Stage A fetched; Win64/LLP64 is
  stated as having no defect; big-endian LP64 is labelled **a derivation**; **the aarch64 sentence is
  not written**, and the comment says explicitly that nothing is claimed about that target.
* **L9/L10** — no count quoted anywhere I wrote except ones a row re-measures. The one figure I quote
  with a control is a truncated `long`, which reproduces.
* **1608's prefix guard stayed closed** (STAGE_C "Also required"): G8, G9, G14 and G15 green on both
  arms after the change, including all four (D) arms' canaries.

## 6. WHAT I COULD NOT MEASURE

* **aarch64 and Win64.** No toolchain, no emulator — re-checked, still absent. Both appear in the
  comment as a derivation and a reading, never as a measurement.
* **A non-glibc `printf`.** `%llld` re-emitting a literal `%ld`, `%llf` giving `-nan` and `%lc`
  returning -1 are all glibc's `form_unknown`/encoding behaviour, not the standard's. GUARD 2b makes
  the tree independent of them, which is the point, but the *before* figures are glibc's.
* **`src/util.o` at an optimisation level other than the build's `-O2`.** Stage A drove five levels on
  the pre-fix file; I drove the post-fix object at `-O2` only, which is what ships.
* **Whether C89 carries C99 §7.15.1.1p2's signed/unsigned `va_arg` exception.** Same gap Stage A
  recorded. The fix does not lean on the exception, so this does not matter to the code — but the
  comment states the rule without attributing it to C89.

## 7. CARRIED FORWARD, NAMED AND NOT FIXED

1. **Issue 1612** — `sprintf`'s unchecked negative return. Untouched, and this fix keeps it
   unreachable by construction (row M6 is the fence against the shortcut that would reach it).
2. **`%lp` and `%hp`** are still accepted with the modifier silently dropped by glibc. Harmless: the
   tree's only `%p` carries no modifier, and there is no non-literal format. `%llp`/`%hhp` are now
   refused (R3).
3. **Named limit L3 of the suite** — the `%s` arm still discards its own field width and precision.
   Not in 1609's scope and untouched.
4. **Named limit L8** — a format with no conversion at all that does not fit still leaves the
   destination untouched. Untouched.
5. ⚠ **The `-Wcomment` class.** `src/util.c` still carries one pre-existing `'/*' within comment`
   warning (at the 1608 block), and `src/util.h` and `src/xschem.h` carry more. The build's CFLAGS
   have no `-Wall`, so nothing surfaces them. Not fixed; named because I created and removed one
   myself and only a hand-run `-Wall` saw it.

## 8. REPRODUCING EVERY FIGURE

```
<scratchpad>/stageC_1609/
  stubs_1609.c        Stage A's stub set, copied verbatim
  neutral_1609.c      §2's before/after table, with a plain-sprintf control per line
  run_neutral.sh      build+run it against a named util.o:  run_neutral.sh <util.o> <tag>
  neutral_BEFORE.txt neutral_AFTER.txt neutral_DIFF.txt ab_{before,after}.txt d_{before,after}.txt
  util_before.o util_after.o util_before.dis util_after.dis   §2's objdump quotes
  signedness_1609.c   §5 R1's two-va_arg comparison
  parm_1609.c         §5 R3's p-arm and float-arm table (built against both util.o's)
  sabotage.sh         one guard at a time; cp restore (never cp -a); aborts if the sed misses
  rows.sh             the suite with a contained HOME, per-row output kept
  sab_f{1..9}*.rows   §3's nine sabotage runs
  live.sh live.out    §2's live getters on :99
  rows_final2.txt     the finished tree's 45 rows
```

Binary-driven figures: `tests/headless/run_suites.sh [--nogui] test_snprintf_fmt_1608` for the suite
(both arms), and for the live getters a contained `HOME` with `DISPLAY=:99 GUI_GATE=0`. No bare
`xschem`; nothing ran on `$DISPLAY` (`172.20.160.1:0`); `devdisplay.sh` was only queried with
`status`. The owed ledger was not touched. No commit was made.

## 9. NOTE FOR THE DRIVER

* The issue file was **not** edited, per STAGE_C. If §5's refutations are to land in it, R1 and R1b
  touch correction (g) — which currently states L2's output claim as measured — and R2 touches
  nothing in the issue file but does touch `STAGE_C.md` L5.
* `git status` in this worktree shows only `src/util.c` and
  `tests/headless/test_snprintf_fmt_1608.tcl`. The worktree also holds a generated `Makefile.conf`,
  `config.h`, `src/Makefile` and build products from my `./configure` — all gitignored.
* A gate should run in a clone at a **short** path (`test_op_annot` invents eleven failures otherwise)
  and with no sibling crew's uncommitted `src/` edits in the tree.
