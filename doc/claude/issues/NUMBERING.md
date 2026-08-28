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
disagree about a registry key), **0821** (a Tcl-side splice of the same shape: `src/xschem.tcl:4775` `graph_fill_listbox`
ran `subst` over a `.sch` `rawfile=` attribute).

**2026-08-25, item 0821+0816+0817 write-up.** Filed since: **0822** (the lead — `autoload`
and `sim_type` execute from a `.sch` attribute too), **0823**, **0824**, and by this item
**0825** (the three sym-path wrappers splice a `.sch` symbol name, so a plain `xschem load`
executes Tcl — found, filed and fixed in one commit), **0826** (test_wave_markers MX7b/MX7d
go red on a Tk key-delivery stall), **0827** (⚠ **LIVE**: `cellview_sch_path()`,
`src/actions.c:4215`, splices a `.sch` `schematic=` attribute, so a plain descend executes
Tcl), **0828** (three anti-hollow rows in the new GDI group stay green when the Graph
dialog's attribute intake is inert).

**0821 and 0822 are FIXED** — `src/xschem.tcl:4775` is no longer live and no line of this
file should still be quoted as evidence that it is; so are **0816** and **0825**. **0817**
is open and now has a driven vector.

~~**The next free number is 0829.**~~ superseded, see below.

**2026-08-27, the annotation driver run (items A0-A9).** The block has moved past
0829 several times over. Filed on this run: **0859-0867** by the earlier items, and
**0868** by item A3 (the on-request transient annotation, which also closed 0865),
then **0869-0876** by A3's write-up from three verification passes —
**0869** (the transient sentence names the REQUESTED time, not the measured one:
RULING D5-1), **0870** (`xschem annotate_at <unparseable>` publishes at t = 0 and
reports success), **0871** (the `nodata` refusal is unreachable and its golden is
hollow), **0872** (bit1 and bit2 share one render class, so `Alt-6` repaints a
transient's numbers as OP node voltages — RULING 0856 reopens), **0873** (guard G9,
"refusals speak", has no row), **0874** (the widened `text_hidden()` voltage arm has
no row), **0875** (row B12b cannot see a leaked viewer-context borrow), **0876**
(0868's eight C guards were never sabotage-tested).

Nothing new was filed for `test_ase_window` W7's flake: it is **0642**, and it got a
third dated sighting appended rather than a fourth number. See CLAUDE.md on 0689/0690
for why that matters.

**2026-08-28, the annotation driver run continued (items A10-A12).** Filed
**0877-0893** by the later items, then **0894-0898** by item A12's write-up:
**0894** (three of A12's own guards had no row that could see them removed — one
of them the routing that keeps the regression runner off the user's real screen;
fixed in the same commit), **0895** (issue 0893's truthful refusal sentence
misses its commonest trigger — a *deleted* results file, not a corrupt one),
**0896** (the two-window compare is skipped entirely while a run is still
filling, and another run's numbers reach the schematic — a live RULING D5-1
violation), **0897** (the plain-English refusal-sentence lists are
hand-maintained with no completeness check), **0898** (T1's new display arm gives
a wall-clock row two chances to flake on a loaded box).

**The next free number is 0899.** 0500-0599 and 0700-0799 remain reserved for
other branches.
