# Plan — outsider fixes batch

**Opened** 2026-09-18 on `fluid-editing`, on the user's instruction ("yes, start on those
two"), after the outsider-experience audit (47 agents) measured what a stranger who clones and
builds this branch runs into. Its in-scope findings are copied verbatim, with every verifier's
correction, into `receipts/audit_findings_in_scope.md` — **read that first**.

## The two items

### Item 1 — the issue-stamp checker turns T1 red for most strangers (the driver's own regression)

`tests/headless/test_issue_stamp.tcl` was registered in T1 on 2026-09-17 (`1acae0b0`). Its row
**S20** compares the checkout folder's name with the literal `xschem-claude` (added in
`6cbbc208`), so T1 goes red for `git clone <url> xschem`, a second checkout, a worktree, a CI
workspace, and every ZIP download (it unpacks as `xschem-claude-fluid-editing`) — audit F23.
The checker also goes red in a **shallow clone** (`--depth 1`, the CI default), where the
revisions its stamps name are absent (F24), and in an export with **no `.git`** at all (part of
F21). A repo-hygiene checker must never report a product failure because the history it
inspects is not present.

**Done when:** the suite and T1 are green in a renamed clone, a shallow clone and a `git
archive` export; still green in a full clone; and the checker **still goes red** on a genuine
defect in a full clone (its own red rows stay red — the batch-17 rule D9).

### Item 2 — the documented test commands write into the tester's real home directory

No driver points the tests at a throwaway home, so T1, `run_suites.sh` and `full_audit.sh`
overwrite a tester's xschem clipboard (F6), same-named netlists in `~/.xschem/simulations`
(F8) and saved window positions (F7); fall back to an installed `xschem` against the real home
when `src/xschem` is not built (F10); start a persistent Xvfb and create `~/.claude/` and
`~/.cache/openbox` (F36); and leave other files there (F39).

**Done when:** a documented test run touches nothing under the tester's real `HOME` —
proved with a canary home, never assumed — while **the developer's own run keeps its display
arm** (today's T1 runs its 11 display cases on the persistent dev display `:99`, whose state
lives under `~/.claude/xschem_dev_display`), and T1 stays at ZERO.

## Stages

| id | stage | depends on |
|---|---|---|
| **S1** | Item 1: understand, reproduce red in three stranger shapes, fix, verify | — |
| **S2a** | Item 2: map every HOME dependence of the drivers and harness; test whether the suites' shared `scratch.tcl` can redirect writes for the bare command | — |
| **S2b** | Item 2: design (driver, recorded in `DECISIONS.md`) | S2a |
| **S2c** | Item 2: implement red-first with a canary home, verify on stranger shapes and on this box | S2b |
| **F** | driver: T1 gate, CLAUDE.md, commit | S1, S2c |

S1 and S2a run in parallel: S1 edits only the two issue-stamp files, S2a only reads and measures
in scratch clones.

## Standing constraints (every crew)

* **Until Item 2 lands, never run T1, a suite or a driver with the real `HOME`** — that is the
  very defect being fixed. `HOME` points at scratch for every run.
* The user may be **using xschem at the same time** (they were at 23:35 on 2026-09-17). A
  change in `~/.xschem` is not test damage until attributed: check `/tmp/Xschem.log*` for an
  interactive session before calling it one.
* Never `devdisplay.sh start|stop|view` against the real `:99`, and never modify
  `~/.claude/xschem_dev_display`. Reading it is allowed.
* Nothing is written in `~/dev/xschem-op-wcard` (a live session works there).
* Crews do not commit. The driver holds git.
