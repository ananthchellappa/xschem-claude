# 1491 — a read-only checkout dies in `test_scratch` and in `state_roundtrip.tcl`'s temporary file

**STAMP:** `v1 claim=open tree=1f3f5287 stamped=2026-09-20 fix=none open=2 by=A-docs`

**Status: OPEN — filed 2026-09-20** by the stranger-reds batch, from item A's adversarial
verifier (finding **R7**), under batch decision **D4**. The verifier itself scored it a
**nit** and closed it against item A; it is filed so the shape is on the record rather than
only in a receipt.
**Class** stranger-facing, low severity today (see "How reachable this is"), test-side.

---

## What happens

A checkout whose files the runner cannot write — a tree extracted with restrictive
permissions, a shared or installed copy owned by somebody else, a read-only mount, or a
deliberate `chmod -R a-w` — cannot run the suites, because **two things write inside the
checkout**:

* the suites' scratch root, `test_scratch` (`tests/headless/scratch.tcl`), which every suite
  that sources `scratch.tcl` creates and works in. `__scratch_root` defaults it to
  `<repo>/tests/headless/.scratch` (READ);
* the temporary file `ase_state_roundtrip` (`tests/headless/state_roundtrip.tcl`) writes
  while round-tripping a `.state` file. Its default is `.state_rt_<pid>.tmp` beside the
  script — that is, inside the checkout too (READ).

Both default to somewhere inside the tree rather than under `TMPDIR`, so a read-only tree
fails at the first one it reaches.

⚠ **Both already take an override, which is why the fix is small.** `__scratch_root` honours
`XSCHEM_TEST_SCRATCH` when it is set and non-empty, and `ase_state_roundtrip` takes the
temporary file's path as an optional second argument. What is missing is a *default* that
notices the checkout is not writable — not a mechanism.

## What was measured

| | |
|---|---|
| measured by | item A's `reproduce` verifier, 2026-09-20, against `bbc9de1a` plus item A's then-uncommitted files |
| the corpus helper | **read-only-safe**: `test_corpus_files`' filesystem arm answers **104** files against a `chmod -R a-w` tree |
| what dies instead | `test_scratch` and `state_roundtrip.tcl`'s temporary file |

The first row is the measured one, and it is the reason this is *not* part of issue 1485:
the corpus read that item A rebuilt does not need to write anything. The second row is the
verifier's finding; the receipts name the two writers but do not record the verdict lines
they produced, so **treat the exact failure text as unverified and re-measure it** before
citing it anywhere. See `receipts/A-verify.md` finding R7.

## How reachable this is — stated plainly, because it is the whole severity argument

**A read-only tree cannot be built either.** `./configure` and `make -C src` write into the
tree, so the ordinary stranger path (download, build, test) never reaches this defect: it
fails earlier, loudly, and for an obvious reason.

The shapes that *do* reach it all require building somewhere else first:

* a tree built and then made read-only (which is how it was measured);
* a prebuilt binary named by `$XSCHEM`, which `tests/test_utility.tcl` resolves **before**
  the in-tree `src/xschem`, run against a source tree on a read-only mount or one owned by
  another user;
* a shared, installed copy of the tests that several people run and nobody may modify.

None of those is today's documented workflow, which is why the verifier called it a nit and
why this file does not claim otherwise. It is filed because the *fix* is small and known,
and because a test that can only run inside a writable copy of its own source tree is a
constraint nobody has ever written down.

## Fix direction

1. **Fall back out of the checkout when the checkout is not writable.** `__scratch_root`
   already honours `XSCHEM_TEST_SCRATCH`; give it a second condition — an unwritable repo
   root — that lands in `TMPDIR`, in the shape `t1_arm_home` already uses for the throwaway
   HOME (`${TMPDIR:-/tmp}/…<pid>.XXXXXX`, removed by the process that made it). Keeping the
   in-tree default when the tree *is* writable is deliberate: the current location is
   convenient to inspect after a failure, and moving it for everybody is a bigger change
   than this defect justifies. Say so in the run's output when the fallback fires, so a
   tester is never hunting for a scratch directory that is not where the header says.
2. **Do the same for `ase_state_roundtrip`'s default temporary file**, which needs nothing
   from the checkout but a name.
3. **Measure it red first**: `chmod -R a-w` a built tree, run one suite that sources
   `scratch.tcl` and one of the four that use `state_roundtrip.tcl`, and record what they
   say before the change. A fix for a failure nobody has a transcript of is a fix nobody can
   check.

⚠ **Do not "fix" this by skipping.** A suite that notices it cannot write and declares
itself green has measured nothing — which is the failure issue 1485 exists to prevent, and
item A rejected skipping as its default for exactly that reason (`DECISIONS.md` D3). If a
row genuinely cannot run, it prints a `skip:` line naming what is missing.

## Still open (2)

1. The scratch root writes inside the checkout.
2. `state_roundtrip.tcl`'s temporary file writes inside the checkout.

## Evidence

`doc/claude/stranger_reds_batch/receipts/A-verify.md` — finding **R7**;
`receipts/A-impl.md` §F5 (last bullet); `doc/claude/stranger_reds_batch/DECISIONS.md` **D4**.
Code: `test_scratch` in `tests/headless/scratch.tcl`, and `tests/headless/state_roundtrip.tcl`.
