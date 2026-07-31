# Issue 0180 — a NULL token truncates the Tcl list `xschem list_nets` returns

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
Next free issue number after this one is **0181**.
**Never push** — commit, raise `tools/review_gate/review_gate.sh` in the background, and wait.

Doc: `doc/claude/issues/0180-list-nets-null-token-truncates-tcl-list.md`. Read it first; this
prompt does not repeat the mechanism.

---

## ⚠ Read this before you plan anything

**0180 is filed on a measured MECHANISM with an unproven TRIGGER.** Five constructions failed to
reach it. That is not a defect in the issue — it is the issue's central fact, and it changes the
job:

> **You cannot write a RED-first test the usual way, because there may be no input that makes it
> red.** If you start by trying to, you will burn the session hand-crafting schematics.

So the deliverable is *not* "make a failing test pass". It is, in order:

1. **Settle reachability**, with a time box.
2. **Harden the site** regardless of the answer.
3. **Prove the hardening has teeth by sabotage**, since a natural RED may not exist.
4. **Sweep the generalisation** — the `my_mstrcat` NULL-vararg class.

If you find yourself about to write "FIXED, test passes" without having done 3, stop: a test that
was green before your change and green after it has proven nothing.

---

## Phase 1 — settle reachability (time-box it)

The two guards close on each other today:

- an instance **with** a node has its `lab` back-filled by `prepare_netlist_structs()`
  (unconditional at `node_hash.c:383`);
- an instance **without** a node is rejected by the `xctx->inst[i].node` test at `node_hash.c:387`.

Try to break that closure. Angles **not** yet tried (the five that were are tabulated in the issue —
do not repeat them):

- `IS_PIN(type)` covers more than `ipin`. Enumerate every type it accepts (`xschem.h`, the
  `IS_PIN` / `IS_LABEL_OR_PIN` / `IS_LABEL_SH_OR_PIN` macros differ — check which one gates
  `set_lab_or_pin_inst_attr()`'s back-fill versus which one gates `list_nets`). **A type accepted by
  one and not the other is the whole bug.** This is the single most promising angle.
- A **bus** lab: `lab=a[3:0]` gives `mult == 4`. Can a lab expand to a mult LARGER than its comma
  count, so a later iteration runs the cursor dry? `0*a,b` and friends — use
  `xschem expandlabel` (it is PURE, no design needed) to hunt for a string whose reported `m`
  exceeds its token count. **That is a second, independent trigger the issue does not consider**,
  and it does not need an empty lab at all.
- `list_nets` while **descended** into a hierarchy, and on a **symbol** view.
- An instance whose `lab` is set to `""` *after* prepare — is there any path that reaches
  `list_nets` twice, or that edits `lab` between the prepare at `:383` and the loop?
- `skip_instance(i, 0, netlist_lvs_ignore)` at `:385` — can an instance pass that but be skipped by
  the back-fill pass, which uses its own skip logic?

**Time-box this to a fixed effort you decide up front, and report the box you chose.** If it
expires, say "not reached, tried N angles" and move to Phase 2 — that is a legitimate outcome and
the issue is written to accept it. Do **not** let it become the session.

If you DO find a repro: it becomes a normal RED-first job, the issue's status line must be
corrected, and Phase 3's sabotage requirement relaxes to the usual revert check.

## Phase 2 — the fix

One line at `src/node_hash.c:391-393`. The only real decision:

- `if(!lab) continue;` **drops the row**
- `lab ? lab : ""` in the `my_mstrcat` call **emits `{ <type>}`**, a row with an empty name

`tests/stable_handles/net_body.tcl` NC1a asserts the output parses as `{name type}` tuples — read
it and decide which shape that consumer actually wants. **Say why in the diff**, because the next
person will otherwise assume it was arbitrary.

Do **not** try to make `my_mstrcat()` itself NULL-tolerant. NULL *is* its sentinel — 143 of 149
call sites end in a literal `NULL)`. This is settled in the issue; do not re-derive it.

## Phase 3 — prove the teeth by sabotage, not by a green test

Since a natural RED may not exist, the substitute is a **hybrid binary** (the technique from
`doc/claude/suggestions/next_session_prompt_0165.md` trap 14):

1. Build a binary with the `:387` guard **deliberately weakened** so an empty-lab instance reaches
   the loop — e.g. drop the `xctx->inst[i].node` conjunct, or force `lab` to `""` just before
   `:388`. That is your artificial trigger.
2. On that binary, **with the fix reverted**, your test must FAIL (unbalanced brace).
3. On that binary, **with the fix applied**, it must PASS.
4. Restore the guard; confirm the test still passes on the real binary.

Step 2 is the one that matters. **If the test cannot be made to fail even with the guard weakened,
say so out loud** — it means either the trigger analysis is wrong or the test is not asserting what
you think, and both are worth more than a green run.

The test itself should assert brace **balance** and Tcl **parseability** of `xschem list_nets`, not
a fixed string — the row set varies with the fixture. Shape:

```tcl
set r [xschem list_nets]
check "NN1 list_nets returns a parseable Tcl list" [catch {llength $r}] 0
check "NN2 every row is a {name type} pair" ...
```

## Phase 4 — the generalisation sweep

`my_mstrcat()` has **149** call sites. Most pass string literals or `get_tok_value()` results,
which are never NULL. Find the ones that pass something that **can** be.

Two existing sites already guard correctly and are your reference for what "right" looks like:

```c
src/actions.c:1726:  my_mstrcat(_ALLOC_ID_, res, "{", type, " ", idxbuf, " {", name ? name : "", "}}", NULL);
src/actions.c:1426:  my_mstrcat(_ALLOC_ID_, &prop, "name=l0 lab=", netname ? netname : "", " text_size_0=", szbuf, NULL);
```

⚠ **The 0179 sweep of exactly this character came back EMPTY.** Do not go in assuming you will find
something; an audit that finds nothing is a real result, and
`doc/claude/code_analysis/my_strtok_r_null_argument_audit.md` is the format to copy — its value is
in explaining *why* the rest are safe, not in the count.

Whatever the outcome, append it to that audit file or write a sibling; do not leave it only in a
commit message.

---

## HARD-WON TRAPS — these cost real time, do not rediscover them

**Verification**

1. **Subagents report confident wrong answers, including about things they claim to have run.**
   0180 exists *because* an agent's reachability claim was published without measurement and had to
   be retracted (`ef830e92`). Reproduce everything yourself before it goes in a doc or a test.
2. **`git checkout <sha> -- <file>` writes the INDEX as well as the worktree.** Copying your files
   back over the worktree leaves `MM` in `git status`, and a later `git commit -a` silently reverts
   your fix. Always `git reset HEAD -- <files>` after, then confirm `git diff src/` is empty.
3. **A binary copied out of the source tree needs `XSCHEM_SHAREDIR=$PWD/src`.**
4. **Verify a "pre-fix" binary really is pre-fix** by running your new test against it and
   confirming it fails.
5. **`xschem expandlabel` is PURE** — no design needed, no `prepare_netlist_structs`. It is the
   right tool for the Phase 1 bus-mult hunt. `xschem list_nets` is NOT pure: it runs
   `prepare_netlist_structs(1)` at `node_hash.c:383`, which is exactly the thing that back-fills
   the lab you are trying to keep empty.
6. **Scratch dirs: always `test_scratch` from `tests/headless/scratch.tcl`.** Throwaway probes go in
   the session scratchpad, never in the repo.
7. **A new test must end with `RESULT: ALL PASS (N checks)`** or `full_audit.sh`'s `is_pass()`
   scores it FAIL while every leg prints ok. Copy the tail of
   `tests/headless/test_tedax_extra_pinnumber_0179.tcl`.
8. **C changes need `cd src && make`. The shell's cwd PERSISTS across tool calls** — use absolute
   paths for file creation.
9. **`perl -0pi -e 's/\Q...$var...\E/.../'` INTERPOLATES `$var` TO EMPTY.** Use python and **assert
   the pattern was found** before writing; write the file only at the end so a failed assert leaves
   the tree untouched.

**Environment**

10. **The GUI arm is unreliable on this box (WSLg).** Display-dependent tests flip
    PASS/FAIL/SKIP run-to-run on an unchanged binary. This issue is fully headless — stay in
    `--nogui` and you avoid the whole class.
11. Run suites with
    `SUITE_TIMEOUT=900 GUI_GATE=0 tests/headless/run_suites.sh --nogui <names>`, **never a bare
    loop** — a bare loop enrols in neither the gate nor the reporting.

**Facts already established — do not re-derive**

12. `my_strdup` (`util.c:193`) NULLs its destination for an absent **or empty** source;
    `my_strdup2` (`util.c:718`) does not. `get_tok_value()` **never** returns NULL. That single
    distinction explains most NULL-pointer questions in this area.
13. `xschem expandlabel {}` returns `""` with **`mult == 1`** — measured. That is half the 0180
    mechanism.
14. `my_mstrcat`'s NULL sentinel cannot be changed. Settled; see the issue.
15. `expandlabel()` returns NULL **only** for a NULL input, and sets `*m = -1` on that path — which
    is what makes several sibling loops in the tree safe. A zero-multiplicity expression returns the
    **original string** with `m = -1` (`0*a` → `0*a`), not an empty one.

---

## Suites that must stay green (measured 2026-07-30, `--nogui` arm)

```
test_hash_extra_node_warn_0165      15
test_tedax_extra_pinnumber_0179     10
test_resolved_net_attr_scope_0163   34
test_resolved_net_templ_fallback_0164 23
test_resolved_net_bus_global_0157   19
test_resolved_net_hash_bus_0158     21
test_hash_label_crash_0156          23
test_ase_unnamed_net                28
test_prep_result_contamination_0155 12
```

Plus the direct consumer of the changed function, which is **not** in `tests/headless/`:
`tests/stable_handles/net_body.tcl` (NC1a/NC1b call `xschem list_nets`). It is pre-existing
35 PASS / 4 FAIL and writes to `/tmp/sh_net_test.log`, not stdout — **know that floor before you
read its result**, or you will chase a failure you did not cause.

`tests/netlist_diff/netlist_diff.sh <old-binary>` exists if you need to prove output neutrality,
but this change touches no netlist emission, so it should not be needed. If you use it, note it
diffs 920 netlists and takes a few minutes.

## How I want you to work

1. Reproduce the mechanism yourself before trusting any of this prompt.
2. Phase 1 with a stated time box. Report the box and the outcome, including "not reached".
3. Phase 2, then Phase 3's sabotage. **If a sabotage changes nothing, say so out loud** — that half
   has no teeth and the report must say it.
4. Issue doc updated with what you actually established, including a corrected status line if you
   found a repro. Commit. Raise the review gate. **Never push.**
5. Report what you verified, what you did **not**, and any judgement call I should weigh in on.
