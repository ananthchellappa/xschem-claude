# Lessons learned: a subagent's `git reset --hard` wiped uncommitted work

*A real incident from this repo (the fluid-editing "shove" layer, issue 0015),
written so the next agent — or human running agents — does not repeat it. The root
cause is not git; it is treating an uncommitted working tree as private when it is
actually shared mutable state.*

---

## 1. What happened

While implementing `fluid_shove_connected_wire()` in `src/move.c` (~200 lines,
**uncommitted**), an adversarial-review **Workflow** was launched: six "attack"
agents plus per-finding "verify" agents, all told to *build a headless repro and run
it with the feature ON vs OFF to prove each claimed bug*.

To get a clean "OFF" baseline, at least one agent ran:

```
git reset --hard        # "move to HEAD" — throw away working-tree changes
```

in the **same working tree** the parent was editing. That command discarded every
uncommitted tracked change — including the entire shove implementation. `git status`
went silent; `grep fluid_shove_connected_wire src/move.c` returned `0`.

Two damages, not one:

1. **The work was gone.** ~200 lines and a hook edit, vanished. Recovered only
   because the full source was still quoted in the conversation transcript and could
   be re-applied by hand.
2. **The review itself was corrupted.** Agents that reset then rebuilt were now
   testing a binary that *did not contain the feature*. One verify agent even noted
   "the binary had been rebuilt WITHOUT the shove." Their "CONFIRMED" verdicts were
   therefore untrustworthy — some described the absence of a feature, not a bug in it.

The reflog is the fingerprint:

```
$ git reflog -1
87a600cc HEAD@{0}: reset: moving to HEAD
```

---

## 2. Why it happens (and why it is easy to miss)

- **Review / attack / verify / bisect agents legitimately need a baseline.** The
  natural way to compare "feature on vs off" is to reset to a known state, rebuild,
  and run. In isolation that is correct discipline. In a *shared* tree it is a wipe.
- **`git reset --hard` and `git checkout -- .` destroy exactly the work that is most
  valuable and least protected:** tracked changes you have not committed yet. Note
  the asymmetry:
  - **committed** work → safe (a reset to HEAD keeps HEAD).
  - **untracked** files (new files you never `git add`ed) → survive a `reset --hard`.
    (This is why the new test file lived while the edited `move.c` died.)
  - **tracked-but-uncommitted** edits (staged *or* unstaged) → **gone, and not in the
    reflog** — they were never an object, so there is nothing to recover from git.
- **The blast radius is invisible until you look.** No error is raised; the parent's
  next `grep`/build simply finds the code missing.

The deeper framing: **your uncommitted working tree is shared mutable state, and every
subagent that can run shell commands is a concurrent writer.** This is the same hazard
as two threads mutating one buffer, or a signal handler firing mid-update — a class
this codebase already documents (see `the_2x_ghost_tutorial.md`). The fix is the same
family: either make the state *immutable to others* (commit — a durable checkpoint) or
*give each writer its own copy* (isolation).

---

## 3. Prevention (in priority order)

1. **Commit the work-in-progress BEFORE spawning any subagent/Workflow that may run
   git.** A throwaway WIP commit on your feature branch is the cheapest possible
   insurance; `git commit --amend` / fixup after the agents finish. This is the single
   habit that would have prevented the whole incident. Treat "I'm about to fan out
   agents" as a **commit barrier**, exactly like you would flush state before handing a
   buffer to another thread.
2. **Isolate tree-mutating agents.** Run review/attack/bisect agents in their own git
   worktree so their `reset`/`checkout`/`clean`/rebuild cannot touch the parent tree:
   - `Agent(..., isolation: 'worktree')`
   - the Workflow `agent(..., { isolation: 'worktree' })` option
   A worktree is auto-cleaned if unchanged, so the cost is small for the safety.
3. **Tell the agents the constraint explicitly** when isolation is not used: "Do NOT
   run `git reset`, `git checkout -- `, `git stash`, or `git clean` in this tree; if
   you need a baseline, build it in a copy or a fresh worktree." Prompts are not a
   guarantee (an agent may still do it), so this is a backstop, not the primary
   defense.
4. **Snapshot before the risky step.** `cp src/move.c $SCRATCHPAD/move.c.bak` before a
   phase that rebuilds/resets gives a second recovery path independent of git. (This is
   how the shove was double-protected on the *second* pass.)

---

## 4. Detection and recovery

**Detect:**
- `git reflog` shows a `reset: moving to ...` you did not perform.
- `git status` is unexpectedly clean; a `grep`/`ls` for your new symbol/file returns
  nothing.
- A build "succeeds" but the behavior you just implemented is absent.

**Recover, best source first:**
- **The conversation transcript** — if you (or the tool calls) quoted the full code,
  re-apply it. This saved the incident.
- **A scratchpad backup** — if you snapshotted before the risky step.
- **Subagent transcripts** — `agent-*.jsonl` / the workflow `journal.jsonl` may contain
  the code an agent read or wrote.
- **Not the reflog for the lost edits themselves** — uncommitted changes were never
  committed, so `git reflog`/`fsck --lost-found` cannot bring them back. The reflog
  only tells you *that* a reset happened and to which commit.

**And re-establish ground truth for any review that straddled the reset:** rebuild a
binary you *know* contains the feature (instrument + trace to confirm the code path
runs), then re-judge findings. Do not trust "CONFIRMED" verdicts produced against a
possibly-stale binary (cross-reference `lessons_green_is_not_correct.md`).

---

## 5. The one-line takeaway

> **Before you fan out agents, commit. An uncommitted working tree is shared mutable
> state, and a helpful subagent reaching for a clean baseline will `git reset --hard`
> it out from under you.** Commit is the checkpoint; a worktree is the isolation. Use
> one of them, every time.

---

*Incident: issue 0015 shove layer, 2026-07-06, review workflow `wf_44288957`. Related:
`the_2x_ghost_tutorial.md` (shared mutable state read across a boundary),
`lessons_green_is_not_correct.md` (verify against a binary you know has the feature),
`lessons_multi_agent_orchestration.md`.*
