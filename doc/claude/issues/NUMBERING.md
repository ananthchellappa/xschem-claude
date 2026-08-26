# Issue number reservations — read before filing

Two blocks are reserved for other branches. Filing into them collides with work
this branch cannot see, and the 02xx renumbering recorded in `status.md` is what
that costs to undo.

| block | owner | rule |
|---|---|---|
| **0500–0599** | the fluid-editing branch | after **0499**, the next number is **0600** |
| **0700–0799** | reserved (user, 2026-08-24) | after **0699**, the next number is **0800** |

So the filing sequence is:

```
… 0498  0499  0600  0601 …  0698  0699  0800  0801 …
```

Highest filed on `annotate` as of 2026-08-25: **0805** — the 0689+0690+0698 crew
filed **0802** (full_audit scores a pass banner followed by a death marker as PASS),
**0803** (`execute`'s modal dialog hangs any suite under X), **0804**
(`test_ase_core` NT14 asserts headless-only behaviour in both arms) and **0805**
(full_audit's pass arm is prefix-anchored only), so **the next number is 0806**.
Before that: **0801** — the 08xx block is now
OPEN (0699 was the last 06xx number; **0800** and **0801** were filed by the
0674+0675+0677 crew, so the next number is **0802**). Earlier: **0698** (0668-0673 filed by the
0663 crew; 0674-0677 by the 0664+0665+0666 crew; 0681 by the 0678 crew; 0679/0680
by concurrent crews; 0683-0684 by the 0682 crew; 0685-0690 by the 0683+0684 crew;
0691-0692 by the 0679 crew; 0693-0696 by the 0691+0692 crew; **0697-0698 by the
0695+0696 crew**). ~~The next number is **0699**~~ — ~~0802~~ superseded: 0802-0805
are filed too; **the next number is 0806**.

`status.md` covers the fluid-editing branch and its 02xx numbering.
`status_annotate.md` covers this branch, 0600–0698. They do not share a number
space. `status_annotate.md` §6d records the 0800/0801 filings; 0802-0805 came from
the 0689+0690+0698 harness-trust commit.

**2026-08-25, item 0812-retry write-up.** The block has moved a long way past the
paragraph above, which stopped at 0806. Filed since: **0807-0811** (the 0688+0683 crew),
**0812-0814** (the 0807 crew), **0815-0817** (the 0812 attempt-1 crew), **0818** (the
0812-retry plan agent), and **0819-0821** by this write-up, from the late adversary pass on
0812-retry — **0819** (`Tcl_GetVar2Ex` fires READ TRACES, so the resolver's "no evaluator"
comment was false; mitigation pinned by GUARD3), **0820** (a graph `%` rawfile field is
resolved twice, so `resolve_rawfile_path()` is not idempotent in general and read/clear can
disagree about a registry key), **0821** (⚠ a LIVE Tcl-side splice of the same shape:
`src/xschem.tcl:4775` `graph_fill_listbox` runs `subst` over a `.sch` `rawfile=` attribute).
**The next free number is 0822.** 0500-0599 and 0700-0799 remain reserved for other
branches.
