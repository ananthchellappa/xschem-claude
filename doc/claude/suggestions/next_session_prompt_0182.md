# Issue 0182 — `expandlabel()` segfaults on zero- and negative-multiplicity labels

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
Next free issue number after this one is **0184** (0183 is already taken).
**Never push** — commit, raise `tools/review_gate/review_gate.sh` in the background, and wait.

Doc: `doc/claude/issues/0182-expandlabel-zero-negative-multiplicity-crash.md`. Read it first;
this prompt does not repeat the mechanism.

---

## The semantics are already decided — do not re-open them

0182 was filed rather than fixed because the guard has to **decide what these expressions
mean**, and that changes netlist content. The user has now answered. These are settled
inputs to your work, not options:

1. **Zero-collapse follows the `0*a` precedent.** `2*(0*a)`, `(0*a)*2`, `0*a*2`, `2*0*a`,
   `a[3:0:1:0]`, `a[0:0:0:0]` must behave exactly like `0*a` and `a*0` already do:
   `expandlabel()` returns **the original input string** with **`*m == -1`**. Reason given:
   it is already the rule for `0*a`, so nothing downstream has to learn a new case.
   **Explicitly rejected**: returning a real zero-width bus (`""` with `m == 0`), and
   raising a syntax error for the zero cases.
2. **A negative multiplier is a typo.** `-1*a` goes down the **existing syntax-error path**
   (`yyparse_error`), the same one malformed labels already use. Rejected: silently
   clamping negative to zero.
3. **Warn, once per schematic.** Same style as the `'#'`-label warning from issue 0165: a
   status-area line naming the instance and the offending label. Rejected: fixing it
   silently, and warning only during netlisting.

If measurement shows one of these is impossible or costs more than it is worth, say so
with the evidence and stop — do not quietly substitute a different rule.

---

## Phase 1 — the fix, and why it is smaller than it looks

The chosen semantics are **already implemented**, by accident, in the fall-through at
`src/parselabel.l:133-142`:

```c
 if(dest_string.str) {
   *m = dest_string.m;
   ...
 } else {
   *m = -1;
   my_strdup2(_ALLOC_ID_, &dest_string.str, s);   /* <- the original input, verbatim */
 }
```

That is exactly rule 1. `0*a` reaches it because `expandlabel_strdup("")`
(`expandlabel.y:71-74`) calls `my_strdup` with an empty source, and `my_strdup` **NULLs its
destination** — so a zero-multiplicity list is a NULL string, `line: list` copies NULL into
`dest_string.str`, and the else-branch fires.

**So you do not need to write the semantics. You need to stop the crash and let the
existing fall-through do its job.** Concretely:

- `expandlabel_strmult()` (`expandlabel.y:155`) and `expandlabel_strmult2()` (`:119`) both
  do `len = strlen(s)` after their `if(n==0)` early return. Add a NULL check so a NULL list
  string propagates as NULL instead of faulting.
- `expandlabel_strbus()` (`:199`), `expandlabel_strbus_suffix()` (`:178`),
  `expandlabel_strbus_nobracket()` (`:230`) and `expandlabel_strbus_nobracket_suffix()`
  (`:251`) all end with `sprintf(res+l, ..., n[i])` where `i == n[0]`. When `n[0] == 0`
  that reads **uninitialised** `n[1]` and writes into a zero-sized allocation. Return NULL
  for `n[0] == 0` rather than inventing an element.
- Negative `n` in the two `strmult` functions is rule 2, not rule 1: set the parser's error
  flag and return NULL, so `expandlabel()`'s `if(yyparse_error==1)` block at
  `parselabel.l:117-130` raises the existing dialog.

**Verify, do not assume**, that setting `yyparse_error` from inside a mid-parse helper
actually reaches that block — find who resets it to 0 and confirm the ordering. `yyerror()`
(`expandlabel.y:61-66`) sets it the same way, which is the precedent, but the reset site is
the thing to check.

**Watch the `m` bookkeeping.** `$$.m` is still assigned in the productions that now return
NULL (`expandlabel.y:341`, `:348`, `:385`), and `line: list` copies it into
`dest_string.m`. That is harmless *today* because the else-branch overwrites `*m` with -1 —
but only because `dest_string.str` is NULL. Do not "tidy" that by making the helpers return
`""`; `""` is not NULL, the if-branch would win, and you would silently ship the
zero-width-bus semantics the user rejected.

---

## Phase 2 — the warning, which is the actual open design problem

Rule 3 says "one warning per schematic". `expandlabel()` is the wrong place to emit it: it
is called from drawing, hit-testing, hierarchy traversal and the pure `xschem expandlabel`
command, so a warning there fires on **every redraw**, not once per schematic.

The 0165 precedent is `src/netlist.c:1491-1500` — inside
`name_nodes_of_pins_labels_and_propagate()`, gated on `print_erc`, which is computed at
`:1426` precisely so ERC prints once per schematic per netlist pass. That gate is the shape
to copy.

The problem you must solve: **how does that site learn the label was degenerate?**
`expandlabel()` returning `s` with `m == -1` is indistinguishable from the many other
`m == -1` cases. Options worth measuring, in rough order of how much you should like them:

1. A separate query the ERC pass can call (`expandlabel()` already keeps state in
   `dest_string`; a "last expansion collapsed" flag is cheap and does not change any
   signature).
2. Re-deriving it at the ERC site from the label text.
3. Changing `expandlabel()`'s signature — **last resort**, it has many callers.

Whatever you pick, the warning must **not** fire for the labels that already return
`m == -1` today and are not bugs (`0*a`, `a*0`, `a,`, `,a`, `a,,b`, `(a,b)*0`,
`0*(a,b)`, `a*-1`, `0*a[3:0]`, `a[3:0]*0` — all measured, all currently harmless). Getting
this wrong turns a fix into a nag on working schematics. **A leg that proves an
already-legal label does NOT warn is worth more than the leg that proves the broken one
does.**

If the once-per-schematic requirement turns out to need more machinery than the crash fix
itself, land the crash fix first as its own commit and report the warning separately. Do
not hold the segfault fix hostage to the warning.

---

## Phase 3 — RED first, for real this time

Unlike 0180, **a natural RED exists**: eight of these expressions segfault the shipped
binary today. Write the test first, watch it crash, then fix.

`xschem expandlabel` is **PURE** — no design, no `prepare_netlist_structs`. That is the
right tool for the expansion legs. Only the warning legs need a schematic.

**Run every candidate in its own subprocess.** A segfault in the test's own interpreter
takes the whole run down. Copy the `tedax_child`/`exec` pattern from
`tests/headless/test_tedax_extra_pinnumber_0179.tcl`, or the `list_nets_child` proc in
`tests/headless/test_list_nets_null_token_0180.tcl` (which is the more recent and slightly
tidier of the two).

### The measured battery — this is your test-vector table

Run on the shipped binary 2026-07-31, one subprocess per candidate. Format is
`expansion` / `multiplicity` / count of non-empty comma tokens.

```
[]             exp=||                          mult=1  tokens=0   <- issue 0180's trigger
[ ]            exp=| |                         mult=1  tokens=1
[a]            exp=|a|                         mult=1  tokens=1
[a,b]          exp=|a,b|                       mult=2  tokens=2
[a[3:0]]       exp=|a[3],a[2],a[1],a[0]|       mult=4  tokens=4
[0*a]          exp=|0*a|                       mult=-1 tokens=1   <- THE PRECEDENT
[a*0]          exp=|a*0|                       mult=-1 tokens=1   <- THE PRECEDENT
[2*a]          exp=|a,a|                       mult=2  tokens=2
[0*a,b]        exp=|,b|                        mult=1  tokens=1
[b,0*a]        exp=|b,|                        mult=1  tokens=1
[a,0*b,c]      exp=|a,,c|                      mult=2  tokens=2
[2*(0*a)]      CRASH                                              <- rule 1
[(0*a)*2]      CRASH                                              <- rule 1
[0*a*2]        CRASH                                              <- rule 1
[2*0*a]        CRASH                                              <- rule 1
[2*0*a,c]      CRASH                                              <- rule 1, see note below
[a[3:0:1:0]]   CRASH                                              <- rule 1, bus arm
[a[0:0:0:0]]   CRASH                                              <- rule 1, bus arm
[a[3:0:1:2]]   exp=|a[3],a[2],a[1],a[0],a[4],a[3],a[2],a[1]| mult=8 tokens=8
[a[1:1]]       exp=|a[1]|                      mult=1  tokens=1
[$foo]         exp=|$foo|                      mult=1  tokens=1
[*]            exp=|*|                         mult=1  tokens=1
[,]            exp=|,|                         mult=-1 tokens=0
[a,]           exp=|a,|                        mult=-1 tokens=1
[,a]           exp=|,a|                        mult=-1 tokens=1
[a,,b]         exp=|a,,b|                      mult=-1 tokens=2
[1*a]          exp=|a|                         mult=1  tokens=1
[-1*a]         CRASH                                              <- rule 2
[a*-1]         exp=|a*-1|                      mult=-1 tokens=1   <- already fine, do NOT change
[0*a,0*b]      exp=|,|                         mult=0  tokens=0
[(a,b)*0]      exp=|(a,b)*0|                   mult=-1 tokens=2
[0*(a,b)]      exp=|0*(a,b)|                   mult=-1 tokens=2
[0*a[3:0]]     exp=|0*a[3:0]|                  mult=-1 tokens=1
[a[3:0]*0]     exp=|a[3:0]*0|                  mult=-1 tokens=1
[2*(0*a,b)]    exp=|,b,,b|                     mult=2  tokens=2
[a.b]          exp=|a.b|                       mult=1  tokens=1
[a:b]          exp=|a:b|                       mult=1  tokens=1
[a,b,]         exp=|a,b,|                      mult=-1 tokens=2
```

**Every non-CRASH row above is a CONTROL that must come out byte-identical after your
change.** That table is the whole regression surface for the label grammar; it took a
session to produce, so put it in the test rather than re-deriving it.

**Note on `2*0*a,c`.** Do not expect the original string back. The zero part is a
*sub-expression*, and the comma production already handles a NULL side — so by rule 1 the
answer should be `,c` with `mult=1`, exactly parallel to the existing `0*a,b` -> `,b`.
Measure it and record whichever it is; if it comes out as the full original text instead,
that is a signal your NULL is propagating further up than intended.

### Also assert this, because it is what 0180 was really about

The crashing labels are reachable from **ordinary schematic data**, not just the
`expandlabel` command. Measured: an instance carrying `lab=2*(0*a)` segfaults
`xschem list_nets` on the shipped binary. Keep at least one leg that goes through a real
`.sch` fixture, or you are only testing the pure command.

---

## HARD-WON TRAPS — these cost real time, do not rediscover them

**Verification**

1. **Subagents report confident wrong answers, including about code they claim to have
   read.** In the 0180 session two adversarial verifiers reached *opposite* conclusions
   about the same variable on the same evidence, and the one that "survived" was wrong.
   Reproduce everything yourself before it goes in a doc or a test.
2. **`git checkout <sha> -- <file>` writes the INDEX as well as the worktree**, and a later
   `git commit -a` then silently reverts your fix. Use `git show HEAD:src/<f> > src/<f>`
   instead — it touches only the worktree, and `git status` stays at ` M`.
3. **Verify a "pre-fix" binary really is pre-fix** by running your new test against it and
   confirming it fails. (0180's did: 7 FAILED / 2 passed.)
4. **A binary copied out of the source tree needs `XSCHEM_SHAREDIR=$PWD/src`.** Simpler:
   swap binaries in place at `src/xschem` and swap back.
5. **A test leg that passes on unparseable/absent output is passing VACUOUSLY.** 0180's
   NN3/NN4 did exactly that until they were made to carry the parse flag as well — which
   is what moved the reverted-binary score from 5 FAILED to 7. Ask of every leg: *what
   does this print when the feature is completely broken?*
6. **Scratch dirs: always `test_scratch` from `tests/headless/scratch.tcl`.** Throwaway
   probes go in the session scratchpad, never in the repo.
7. **A new test must end with `RESULT: ALL PASS (N checks)`** or `full_audit.sh`'s
   `is_pass()` scores it FAIL while every leg prints ok. `full_audit.sh` globs
   `test_*.tcl`, so there is nothing to register.
8. **C changes need `cd src && make`. The shell's cwd PERSISTS across tool calls** — a
   later `./src/xschem` from inside `src/` fails with "No such file or directory". Use
   absolute paths, or `cd` back.
9. **`perl -0pi -e 's/\Q...$var...\E/.../'` INTERPOLATES `$var` TO EMPTY.** Use python,
   **assert the pattern was found** before writing, and write at the end so a failed
   assert leaves the tree untouched.
10. **`expandlabel.c` and `parselabel.c` are GENERATED** (bison/flex from `expandlabel.y`
    and `parselabel.l`). Edit the `.y`/`.l`. Confirm your build actually regenerates them
    before you spend an hour wondering why nothing changed.

**Environment**

11. **The GUI arm is unreliable on this box (WSLg).** This issue is fully headless — stay
    in `--nogui`.
12. Run suites with
    `SUITE_TIMEOUT=900 GUI_GATE=0 tests/headless/run_suites.sh --nogui <names>`, **never a
    bare loop** — a bare loop enrols in neither the gate nor the reporting.
13. The Bash safety classifier was unavailable for ~40 minutes during the 0180 session.
    Read-only commands (`grep`, `sed`, `ls`, Read) kept working; anything that *executes*
    a binary was blocked. If it happens again, do read-only analysis and retry — it clears.

**Facts already established — do not re-derive**

14. `my_strdup` (`util.c:193`) NULLs its destination for an absent **or empty** source;
    `my_strdup2` (`util.c:718`) does not. `get_tok_value()` **never** returns NULL. That
    single distinction is why `0*a` behaves as it does.
15. `expandlabel()` returns NULL **only** for a NULL input, and sets `*m = -1` on that
    path. Several sibling loops in the tree are safe only because of that coupling —
    `hilight.c:1008` in particular. **If you change the NULL/`-1` contract you break
    those**, so keep `*m = -1` for every collapse.
16. `my_strtok_r` **skips** empty tokens (`util.c:168`) and returns NULL only when the
    cursor runs dry. So `a,,b` does not truncate anything.
17. Across all 38 candidates above, the **empty string is the only** label whose
    multiplicity exceeds its token count. There is no second trigger of that shape; do not
    go looking again.
18. `my_mstrcat`'s NULL argument is its END-OF-LIST sentinel and cannot be changed. The
    full sweep is `doc/claude/code_analysis/my_mstrcat_null_vararg_audit.md` (150 sites,
    empty).

---

## Suites that must stay green (measured 2026-07-31, `--nogui` arm)

```
test_list_nets_null_token_0180        9
test_hash_extra_node_warn_0165       15
test_tedax_extra_pinnumber_0179      10
test_resolved_net_attr_scope_0163    34
test_resolved_net_templ_fallback_0164 23
test_resolved_net_bus_global_0157    19
test_resolved_net_hash_bus_0158      21
test_hash_label_crash_0156           23
test_ase_unnamed_net                 28
test_prep_result_contamination_0155  12
```

Plus `tests/stable_handles/net_body.tcl`, which is **39 PASS / 0 FAIL on the `--nogui`
arm** (an older note records 35/4 — that is the GUI arm; know which one you are reading).
It writes to `/tmp/sh_net_test.log`, not stdout. Run it as
`cd src && ./xschem --nogui -q --script ../tests/stable_handles/net_wrap.tcl`.

**`tests/netlist_diff/netlist_diff.sh <old-binary>` is not optional for this issue.** You
are changing label expansion, which every backend depends on. It netlists 189 schematics
x 5 backends with two binaries and diffs 920 files; it took a few minutes and came back
`BYTE-IDENTICAL` for 0180/0181. Anything less than byte-identical here means you changed a
label that was working, and the table above should tell you which.

## How I want you to work

1. Reproduce the crashes yourself before trusting any of this prompt.
2. RED first — the crash is real, so there is no excuse for a test that was green before
   your change.
3. The three semantic rules at the top are decided. Implement them; do not relitigate.
4. If the once-per-schematic warning turns out to be a bigger job than the crash fix, ship
   the crash fix on its own and say so.
5. Issue doc updated with what you actually established. Commit. Raise the review gate.
   **Never push.**
6. Report what you verified, what you did **not**, and any judgement call I should weigh in
   on.
