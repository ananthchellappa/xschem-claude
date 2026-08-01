# Issue 0184 — `idxsize` leaks across parses and corrupts the heap on the NEXT bus label

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
Next free issue number after this one is **0186**.
**Never push** — commit, raise `tools/review_gate/review_gate.sh` in the background, and wait.

Doc: `doc/claude/issues/0184-expandlabel-idxsize-static-leaks-across-parses.md`. Read it
first — it is unusually complete: the mechanism is measured, the fix is decided, and the
tempting alternative is already rejected with a reason. **Do not relitigate the fix**; if you
think the rejection is wrong, bring evidence and stop.

This prompt adds what the doc does not have: re-derived line numbers, a sharper account of
which label actually detonates, the build mechanics of a bison-generated parser, and — the
part that will cost you a day if you skip it — **which reproductions are silent**.

---

## ⚠ The obvious minimal test does NOT crash. Read this before writing a leg.

This is heap corruption, so the write and the abort are in **different labels**. Measured
2026-07-31 on `7cf1858c`, ten runs each:

| script | exit |
|---|---|
| `a[0:20,]` → `b[0:15]` → `c[0:31]` | **134 (abort), 10 runs out of 10** |
| `a[0:20,]` → `b[0:15]` — the same corruption, no third label | **0** |
| `a[0:8,]` → `b[0:8]` → `c[0:31]` — a 9-element overflow | **0** |
| `b[0:15]` → `c[0:31]` — no failing label at all (control) | **0** |

So the natural "minimal" reproducer — the failing label plus the one that overflows — **exits
0 and prints correct output**. A test built from it is green *before* the fix and proves
nothing. The corruption is silent until a later allocation walks over the smashed
bookkeeping. Keep the third label.

Neither `MALLOC_CHECK_=3` nor `MALLOC_PERTURB_=42` turns the silent cases into failures
(measured, both still exit 0). An ASAN build would be the proper instrument — **I did not
try one**; the three-label sequence is deterministic enough that you may not need it.

## Which label does what — the `-d 3` trace

```
$ ./src/xschem --nogui --pipe -q --nolog -d 3 --script idx.tcl

check_idx(): reallocating idx array: size=16     <- a[0:20,] grows 8 -> 16
check_idx(): reallocating idx array: size=32     <- ...and 16 -> 32
syntax error in a[0:20,]                         <- dies BEFORE the reset. idxsize stays 32
A=a[0:20,] -1
B=b[0],b[1],...,b[15] 16                         <- 8-int alloc, 16 ints written, NO check_idx
check_idx(): reallocating idx array: size=16     <- c's own legitimate growth...
realloc(): invalid next size                     <- ...detonates on b's corruption. exit 134
```

Three labels, three distinct roles:

* **`a[0:20,]`** poisons the static. It builds 21 elements (doubling `idxsize` to 32), then
  the `index ',' B_IDXNUM` continuation wants a number and gets `]`, so `yyparse()` errors
  out — and the reset never runs because it lives at the *end* of the success production.
* **`b[0:15]`** is the actual overflow: it allocates 8 ints, `check_idx()` never fires
  (16 < 32), and the 16th write runs off the end. **It prints its correct expansion.**
* **`c[0:31]`** is innocent. `b` succeeded, so `idxsize` was reset to 8 and `c` grows it
  8 → 16 perfectly legitimately — and glibc kills the process on that realloc, on damage `b`
  did. Note the doc says `c` "never gets to print"; that is true, but it is worth being
  precise about *why*, because it is the whole reason a user sees an unrelated label crash
  the editor.

## Line numbers — the doc's have drifted, re-derived 2026-07-31

| what | doc says | actually |
|---|---|---|
| `static int idxsize` | `:46` | **`src/expandlabel.y:47`** |
| `check_idx()` | `:220-228` | **`:244-252`** |
| the seven `INITIALIDXSIZE*sizeof(int)` allocations | `426 444 458 468 523 541 555` | **`452 470 484 494 549 567 581`** |
| the four resets at the end of `B_NAME '[' index ']'` | `387 397 407 417` | **`413 423 433 443`** |

Re-derive rather than trust either list:
`grep -n "INITIALIDXSIZE\*sizeof(int)\|idxsize=INITIALIDXSIZE" src/expandlabel.y`.

---

## Build mechanics — this is a GENERATED parser

**`src/expandlabel.c` and `src/expandlabel.h` are gitignored** (`.gitignore:19-20`) and
regenerated from the grammar by `src/Makefile:23-24`:

```make
expandlabel.c expandlabel.h: expandlabel.y
	bison -d -o expandlabel.c  expandlabel.y
```

`bison` and `flex` are both installed on this box. Consequences:

* **Edit `expandlabel.y`, never the `.c`.** A hand-edit of the generated file is silently
  destroyed by the next `make` and will never appear in a commit.
* The regenerated files do **not** show in `git status` — so "nothing changed" there is
  expected, not a sign your edit did not take. Check the built binary's behaviour instead.
* Issue 0182 (`2a8d5718`) touched this same file and committed **only** `expandlabel.y`.
  Do the same.

---

## Phase 1 — RED first

`tests/headless/test_expandlabel_zero_neg_mult_0182.tcl` already has the harness you need
and you should reuse it rather than invent one. It runs **one subprocess per row**:

```tcl
catch {exec $xbin --nogui --pipe -q --nolog --script $sp 2>@1} out
```

with a survival sentinel written as the last line of the sub-script (`flush stdout; exit 0`).
That file also carries the lesson in its own comments — *"carry `$surv` as well: without it
this leg passes VACUOUSLY on exactly the crash it exists to reject"*. A leg that only checks
the expansion text passes on a corpse.

Legs worth having:

* **the crasher**: the three-label sequence, asserting the subprocess **survives** and that
  `c[0:31]` printed its 32 elements. Pre-fix this aborts 10/10.
* **the silent overflow**: the two-label form. It exits 0 both before and after, so it is a
  control, **not** a crash leg — label it that way so nobody later "simplifies" the crasher
  down to it.
* **the poisoning is per-label, not per-process**: after the fix, a failing label followed by
  *many* different-width labels should all expand correctly. That is the invariant the fix
  actually establishes.
* **the ordinary cases still work**: `a[0:20]`, `a[3:0]`, `a[0:31]` and a plain scalar. The
  fix touches seven allocation sites in the grammar; a typo in one of them breaks ordinary
  bus expansion, and that is what these catch.

## Phase 2 — the fix, and the one thing next to it

The fix is stated in the issue doc: `idxsize = INITIALIDXSIZE;` next to **each of the seven**
allocations, so the invariant holds on every path including the error paths. The four
existing resets become redundant but harmless — say in the diff whether you removed them or
left them, and why.

*Adjacent, measured, not part of this issue:* the grammar has **no `%destructor`**
(`grep -n "%destructor" src/expandlabel.y` → nothing), so every `idx` array allocated during
a parse that later fails is simply leaked. `a[0:20,]` leaks its 32-int array on every
occurrence. Record it; only fix it if it falls out of your change for free, and file it
separately if it does not.

---

## HARD-WON TRAPS — these cost real time, do not rediscover them

1. **The silent reproductions above.** A test that exits 0 pre-fix is not a RED test.
2. **A test leg that passes on absent or unparseable output is passing VACUOUSLY.** Ask of
   every leg: *what does this print when the feature is completely broken?* A crashed
   subprocess produces a truncated stdout that often still contains the string you grepped
   for.
3. **Verify a "pre-fix" binary really is pre-fix** by running your new test against it and
   confirming it fails. `git show <sha>:src/<f> > src/<f>` — worktree only, so `git status`
   stays at ` M`; **`git checkout <sha> -- <file>` also writes the INDEX** and a later
   `git commit -a` silently reverts your fix.
4. **C changes need `cd src && make`. The shell's cwd PERSISTS across tool calls** — a later
   `./src/xschem` from inside `src/` fails with "No such file or directory".
5. **`xschem` needs `--pipe`** with `--script`, or it runs the file and prints NOTHING with
   `rc=0`. A whole suite reads as silently empty.
6. **Scratch dirs: always `test_scratch` from `tests/headless/scratch.tcl`.** Throwaway
   probes go in the session scratchpad, never in the repo.
7. **A new test must end with `RESULT: ALL PASS (N checks)`** or `full_audit.sh`'s
   `is_pass()` scores it FAIL while every leg prints ok.
8. **Subagents report confident wrong answers, including about code they claim to have
   read.** In the 0183 session two agents were wrong about `actions.c` in opposite
   directions, and I was wrong to dismiss a third that turned out to be right. Reproduce
   everything yourself before believing or refuting it.
9. **`perl -0pi -e 's/\Q...$var...\E/.../'` INTERPOLATES `$var` TO EMPTY.** Use python,
   assert the pattern was found, and write at the end.
10. **The GUI arm is unreliable on this box (WSLg).** This issue is fully headless.

---

## Suites that must stay green

Measured 2026-07-31, `--nogui` arm, at `7cf1858c`:

```
test_expandlabel_zero_neg_mult_0182   (the sibling battery -- the one most likely to move)
test_empty_value_swallows_token_0183   69
test_schpins_stale_lab_0185            15
test_list_nets_null_token_0180          9
test_hash_extra_node_warn_0165         15
test_tedax_extra_pinnumber_0179        10
test_resolved_net_attr_scope_0163      34
test_resolved_net_templ_fallback_0164  23
test_resolved_net_bus_global_0157      19
test_resolved_net_hash_bus_0158        21
test_hash_label_crash_0156             23
test_ase_unnamed_net                   28
test_prep_result_contamination_0155    12
```

Run them with
`SUITE_TIMEOUT=900 GUI_GATE=0 tests/headless/run_suites.sh --nogui <names>`, **never a bare
loop**. Several suites end `OVERALL: ok` rather than `RESULT: ALL PASS` and are scored
**NORESULT on both arms** — a known pre-existing harness gap, not a failure you introduced.

**`tests/netlist_diff/netlist_diff.sh <old-binary>` is strongly advised.** Label expansion
feeds every backend and this change touches the grammar itself: 189 schematics × 5 backends,
920 netlists, a few minutes. It came back BYTE-IDENTICAL for 0180/0181/0183. Build the old
binary the way the script's own header documents.

## How I want you to work

1. Reproduce the abort yourself before trusting any of this prompt — and reproduce the
   **silent** cases too, so you know what a vacuous leg looks like here.
2. The fix is decided. Implement it at all seven sites; do not reopen the design.
3. RED before GREEN, with the third label in the sequence.
4. Issue doc updated with what you actually established (line numbers, the three-label
   account, whether you kept the four redundant resets). Commit. Raise the review gate.
   **Never push.**
5. Report what you verified, what you did **not**, and any judgement call I should weigh in
   on.
