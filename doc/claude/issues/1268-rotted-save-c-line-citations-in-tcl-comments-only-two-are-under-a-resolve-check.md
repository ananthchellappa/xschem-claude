# 1268 — rotted `save.c:NNNN-MMMM` citations in `.tcl` comments; only **two** are under a resolve-check

**Filed** 2026-09-02 by item **A6**. **Pre-existing rot — A6 did not introduce
it**, but A6 is what exposed the mechanism. **Measured, not fixed.**

## How it surfaced

Item A6-b inserted ~96 lines into `src/save.c`, which moved
`extra_rawfile()`'s `what == 4` printer. Rows **SEL468 / SEL469** of
`tests/headless/test_results_select.tcl` **resolve** the two source comments that
cite that printer by line number, and the suite went red — **which is the design**.
The check's own prose says:

> When `save.c` moves, re-grep the `what == 4` printer in `extra_rawfile()`,
> restate the two source comments AND the two literals here; do not delete the
> check.

A6 restated `save.c:2379-2388` → `save.c:2475-2488` in `src/wave_viewer.tcl` and
`src/ase.tcl` (comment-only), verified the new window contains both anchors, and
the suite returned to ALL PASS (377 checks). **The mechanism works.**

## The defect

**About a dozen `save.c:NNNN-MMMM` citations exist in `.tcl` comments across the
tree and only those two are under a resolve-check.** The rest rot silently, and
several already have. Measured on this tree, 2026-09-02:

| citation | claims | actually at |
|---|---|---|
| `src/op_annot.tcl:385` | `get_raw_index()` at `save.c:2251-2285` | **4125** |
| `src/op_annot.tcl:447` | `save.c:2567-2600` | moved |
| `src/calculator.tcl:1635`, `:2038`, `:2042` | — | same shape |
| `src/xschem.tcl:6154` | — | same shape |
| `src/ase.tcl:5808` | — | same shape |

`src/op_annot.tcl:385` is off by **1874 lines**. A reader following it lands in
unrelated code and, worse, may "correct" the comment to describe whatever is
actually there.

## Fix shape, two options

1. **One sweep**, re-grepping each anchor and restating the range. Cheap once,
   rots again.
2. **One check** — a single test row that resolves *every* `save.c:NNNN` citation
   in `.tcl` comments the way SEL468/SEL469 resolve their two. This is the
   self-maintaining option and is the same idea as the existing resolve-check,
   generalised. It turns a class of silent rot into a red row on the commit that
   causes it.

Option 2 is recommended. Note it must resolve by **anchor text**, not by line
number alone, or it merely re-encodes the rot.

## Still open

All of it. `src/wave_viewer.tcl` and `src/ase.tcl` are correct as of this commit;
nothing else was touched.

## 2026-10-04 — re-measured at `81cd51db`, and "about a dozen" understates it by a lot

Measured while filing issues 1651/1652, because a driver's recollection of the size of this
population ("~130") needed deriving. Three different populations, three different numbers, and
**conflating them is the error to avoid** — a count of citations is not a count of *rotted*
citations:

```sh
# every save.c:<line> citation outside src/save.c itself
git grep -nE 'save\.c:[0-9]+' HEAD -- . | sed 's/^HEAD://' | /usr/bin/grep -v '^src/save\.c:' \
  | cut -d: -f1 | sed 's#/.*##' | sort | uniq -c | sort -rn
```

The totals split by area, and the `doc/` share is dominated by batch receipts and analyses — dated
records, which CLAUDE.md says to leave unedited. **The population this issue is about is the one in
code that a reader follows**: the `src/` citations, enumerated with

```sh
/usr/bin/grep -rnE 'save\.c:[0-9]+' src/ | /usr/bin/grep -v '^src/save\.c:'
```

across `calculator.tcl`, `rdw.tcl`, `wave_viewer.tcl`, `ase_window.tcl`, `xschem.tcl`,
`op_annot.tcl`, `ase.tcl`, `actions.c`, `select.c` and `move.c` — so it is no longer confined to
`.tcl` comments as the title says: **three `.c` files cite `save.c` by line too.**

### The rot rate, resolved rather than counted

Every citation that names a symbol or quotes a line was resolved against the current file:

```sh
sed -n '<N>p' src/save.c           # what the cited line says now
/usr/bin/grep -nE '^[a-zA-Z_].*[^a-zA-Z0-9_]<symbol>\(' src/save.c   # where the symbol is now
```

Of the resolvable subset, **the large majority land on unrelated text** and only two still hold:
`src/ase.tcl`'s citation of the `my_strcasecmp(type, "sp")` normalisation, which quotes the line
verbatim and resolves exactly, and one `op_annot.tcl` citation of `extra_rawfile()`, which resolves
because that function happens not to have moved.

⚠ **This issue's own 2026-09-02 examples are still rotted.** `src/op_annot.tcl` cites
`get_raw_index()` twice by two *different* line ranges; the function is now some two thousand lines
past both. Re-derive with the two commands above rather than trusting either range.

⚠ **One citation has rotted onto a line that looks plausible, which is the worst case for a reader
and the reason a "does the cited line exist?" checker cannot work** (this file's §1 already says
PAST-EOF is zero). `src/calculator.tcl` cites `plot_raw_custom_data()` by a line that now carries a
`my_strcasecmp(type, "sp")` normalisation — and that same statement occurs **twice** in `save.c`,
so a reader who follows the citation lands on real, compiling, confidently-wrong code rather than on
anything that announces itself as the wrong place.

### What this changes about the fix shape

Nothing about the recommendation — option 2, one row resolving by **anchor text** — and it sharpens
two things. First, the row's population must be derived from the tree (`src/`, not `src/*.tcl`), or
it will miss the three `.c` citers. Second, `test_del_negative_arg`'s own header cites the `DEL` arm
of `plot_raw_custom_data()` by a rotted line, so **a test suite is now a citer too**; the `tests/`
citations are a fourth population and are not covered by anything here.
