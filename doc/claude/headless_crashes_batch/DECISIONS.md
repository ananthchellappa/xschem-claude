# Decisions — headless crashes batch

# D1 — Item A first, because it is what makes the rest measurable (driver)

`xserver_ok()` closes the display and leaves the global pointing at freed memory. While
that is true, a missed guard reads whatever survives in the freed block — measured on 1483
as `XMaxRequestSize=4` against a true 65535 — so the defect class is silent wherever a
`DISPLAY` happens to be set, which is every arm anyone routinely runs. Nulling the pointer
converts every remaining missed guard from a plausible wrong answer into a fault.

That is deliberately a fault-finding change: it will surface sites nobody has found. Those
are the point, not collateral.

# D2 — Two crews were launched outside this batch while its Map stage ran (driver)

This batch's first stage is a survey in a throwaway clone, so the main tree sits idle
while it runs. Rather than leave it idle the driver opened two more streams. Recording
them here, in the batch that was live at the time, so the record shows where the
attention went:

* **Issue 1352** — `input_line`'s OK button hands what the user typed to `eval` as a
  script rather than as a value. Surfaced as the one urgent item by the owed-queue triage
  (`doc/claude/code_analysis/owed_queue_triage_2026-09-22.md`, D-1) and re-verified live
  that day through the shipped precision menu. It is inherited stock xschem on the branch
  the user publishes, and the fix is one line, so it does not wait for a batch of its own.
* **Issue 1600** — `test_ase_core`'s 5324-line unnamed file-scope `catch`. The suite is a
  T1 case, so this is a hole in the instrument every other claim in every batch is
  measured with.

# D3 — Crews that run T1 get their own clone; crews that edit product code do not (driver)

Three crews, one tree, is a measurement hazard rather than a memory one: the harness
tolerates concurrent T1 runs (CLAUDE.md, "Concurrent T1 runs"), but a T1 run in the main
tree measures whatever every other crew has half-written into it at that moment. So the
1600 crew clones to `/var/tmp/x1600/tree` and hands back file paths for the driver to
copy, while the 1352 crew — whose change is one line in `src/xschem.tcl` plus a new suite
— edits the main tree directly and is the only crew allowed to.

The cost is that the 1600 crew's T1 is taken against a tree without the 1352 fix, so the
driver re-gates once after applying both. That is one extra gate run, and it is the price
of each crew's number meaning something on its own.
