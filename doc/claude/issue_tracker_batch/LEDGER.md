# Ledger — issue tracker batch

Receipts collected by the driver, newest stage at the bottom. A row lands here only
after the driver has read the receipt and checked at least one of its claims.

**Opened** 2026-09-17 at `2cbce753`, branch `fluid-editing`.

| stage | task | crew status | driver verdict | commit |
|---|---|---|---|---|
| A1 | sample files 1–10, classify against the tree | dispatched | — | — |
| A2 | sample files 11–20, classify against the tree | dispatched | — | — |
| A3 | sample files 21–30, classify against the tree | dispatched | — | — |
| A4 | sample files 31–40, classify against the tree | dispatched | — | — |
| E1 | triage 190 `rule` debts — *does this reach a person?* | dispatched | — | — |

## Running findings

*(filled as receipts land — the corrections to `PLAN.md` live here and in the receipts)*

## Wrong recorded beliefs caught in this batch

The last batch's tally was twenty, *"every one caught by re-measuring rather than
re-reading."* Same table here, same discipline.

| # | belief | who held it | what measurement said |
|---|---|---|---|
| 1 | *"1050 issue files explicitly call themselves a duplicate"* | **the driver** | **7.** There are only 1047 numbered files, so 1050 was impossible on its face and the driver published it anyway. Cause: `/usr/bin/grep -lieE 'duplicate of…'` — in a bundled short-option string **`-e` consumes the rest as its pattern**, so the command searched for the literal letter `E` and matched every file. Proved by experiment: `grep -lieE 'zzz-no-such-pattern-zzz'` also returns **1050**. **A plausible number from a silently broken command** — the same shape as the fossil `results.log` that reads exactly like a clean sweep. |
| 2 | *"69 citations in the tracker are demonstrably wrong"* | **the driver** | **Near zero.** `citescan.py` resolved 3751 `file:line` citations across 620 files and labelled 69 "missing", but the samples are `outitf.c`, `rawfile.c`, `tfanal.c`, `inp2dot.c` (**ngspice**), `libio/iovsprintf.c`, `debug/fortify_fail.c` (**glibc**) and `tcltk/tk8.6/entry.tcl` (**system Tk**) — legitimate citations into **external source trees**, counted as rot because the scanner only knew this repo. Same false-positive class as `pgrep -af` self-matching: **a pattern matched against the wrong namespace.** |
| 3 | *"the tracker's citations rot at 85%"* | **the driver** | **Unmeasured, and not measurable this way.** `quotescan.py` checked 20 quoted numbered source lines and called 17 mismatches, but 16 are the heuristic (*"nearest filename mentioned above"*) grabbing **SPICE decks, netlist listings and `results.log` excerpts** that happen to carry line numbers inside fenced blocks. **Exactly one was genuine** — see the finding below. The lesson is not a rate; it is that **retrospective rot detection cannot be done by heuristic**, which is a Stage C input. |

## Findings the driver measured directly (2026-09-17, at `8608c7ef`)

**No citation in the tracker points past the end of a file.** `citescan.py`: 3751
distinct `file:line` citations, **PAST-EOF = 0**. So the cheap, mechanical rot check —
does the line exist? — finds **nothing**, and the only rot that matters is the kind where
the citation resolves and the text moved. That is the `+15` shift that produced the last
batch's worst error, and it is **not** computable retrospectively.

**The one genuine rotted quote is perfect.** Issue **0229**, whose title is *"comment
line number citations in `callback.c` are stale"*, cites `src/callback.c:2990` as
`int wire_label_try_commit(void)`; the tree at that line says `} else {`. **An issue
about stale line citations whose own line citation went stale.** (0229 is in A1's
sample — the crew's independent verdict is the check on this one.)

**Self-declared refiling: 11 files.** 9 say *"filed four times"*, 2 say *"filed five
times"*. Only **7** files say *"duplicate of NNNN"* at all, against **101** that use the
word "duplicate" somewhere — so the tracker records refiling in prose far more often than
in any form a reader or a tool could act on.

**The cross-clone number collision is not visible today, and that does NOT retire it.**
Both clones hold an identical set of **1048** numbers; **zero** unique to either side and
**zero** `15xx` in op-wcard, despite `1500–1599` being reserved for it. Reason measured:
`/home/analog/dev/xschem-op-wcard` is checked out on **`fluid-editing`** — *this* branch —
at `875ae443`, a commit from the last batch. It is currently a second checkout of our own
branch, not a second line of work. **The hazard is parked, not removed**: one `git
checkout` in that tree restores it. Read this the way CLAUDE.md reads the empty
`/usr/local/bin` — the absence of the collision today is a fact about where a clone
happens to be sitting, not about the numbering rule.
