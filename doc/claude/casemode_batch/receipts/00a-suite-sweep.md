# 00a — suite sweep: which committed assertions encode a folded name

Run 2026-08-16 at HEAD `577ef5bc`. **Static sweep, no code changed, no suite
run.** Purpose: establish item 1's expected-diff contract *before* deleting the
fold at `save.c:1008`, per `DECISIONS.md` §2.4.

## Result

**No committed assertion is expected to move.** The expected audit diff for
items 1 and 2 is **EMPTY** — zero rows, in either direction.

That is the contract. If any row moves when item 1 lands, **stop and explain
it**; do not accept it as "probably fine".

## Scope examined

| | count |
|---|---|
| suites touching `raw read` / `raw list` / `raw value` / `raw vars` | 34 |
| of those, using VCD or table data | 12 |
| git-**tracked** `.raw` fixtures in the whole repo | **2** |

## Why nothing moves — five findings

**1. Only two `.raw` files are tracked, and no test reads either.**

```
doc/claude/casemode_batch/fixtures/tr_fold.raw       v(in) v(midnode) i(vs)
doc/claude/casemode_batch/fixtures/tr_preserve.raw   v(In) v(MidNode) i(Vs)   <- the only tracked file with capitals
```

`grep -rn 'tr_preserve\|tr_fold\|casemode_batch/fixtures' tests/ src/` returns
**nothing**. They were committed at item 0 for the *future* tests and are not
yet consumed. Every other `.raw` under `tests/` is a leftover in `.scratch/`,
untracked.

**2. Every raw a test actually reads is generated at test time by a folding
simulator, or built inline as text — and all of it is lowercase.** So deleting
the fold is a no-op for them: the stored name is already what the fold would
have produced.

**3. All inline VCD signal names are lowercase.** The complete set declared
across every `$var` line in the tree:

```
a  alsook  b  big  clk  count  huge  le  lsb  never  ok  onlyvcd
q  s  same  sig  siga  sigb  top_only  v  wide  x
```

VCD already stored these verbatim, so nothing about their storage changes. What
changes is that a *differently-cased* query would now resolve — and no test
issues one (finding 5).

**4. The `TOP` / `top` scope pair is not a collision.** `test_vcd_read.tcl` is
the only file declaring both, and they are in **different fixtures within that
file** — `TOP` in the reference `counter.vcd`, `top` in a separate inline
header at `:128`. Never in one database, so D2's no-alias-on-collision rule is
not exercised by any existing test. (Worth a new test in item 2 for exactly that
reason — nothing covers it today.)

**5. No test lowercases a name before querying.**
`grep -n 'string tolower' *.tcl` filtered to raw/signal/node/vector contexts
returns **nothing**. So no existing query is folded, and the new folded-alias
rung can never be the thing that makes a lookup succeed.

## The miss-assertions, individually cleared

These assert `raw index … == -1` and were the shape most likely to flip:

| site | assertion | verdict |
|---|---|---|
| `test_wave_cursor_crossdb.tcl:178` | `TOP.m.siga`, `TOP.m.sigb` → `-1` | **safe** — cross-database premise check ("the VCDs' signals are ABSENT from the current database"). The current db is the *analog* raw, which holds `v(anlg)` and no `TOP.*` name at all. Aliases built in the VCD db cannot make a name appear in the analog one. |
| `test_wave_cursor_crossdb.tcl:179` | `v(late)` → `-1` | safe — lowercase, cross-db |
| `test_wave_cursor_crossdb.tcl:706` | `v(reent)` → `-1` after `raw switch 0` | safe — lowercase |
| `test_node_token_split.tcl:284` | `TOP.m.siga` → `-1` | **safe** — same cross-db premise, stated explicitly in the comment above it |
| `test_node_token_split.tcl:290` | `v(anlg)` → `-1` in the VCD db | safe — lowercase, and absent by construction |
| `test_ase_cosim.tcl:856` | `v(anlg)` → `-1` after reattach | safe — lowercase |
| `test_wave_viewer.tcl:843` | `db2` → `-1` | safe — lowercase |
| `test_ase_plot.tcl:563` | `id` → `-1` | safe — lowercase |

## Limits of this sweep — read before trusting it

- **It is static.** It reasons from grep and from what the fixtures contain, not
  from a run. A suite could still move for a reason no grep can see.
- **It does not cover item 5b** (`DECISIONS.md` D3 — the lookup-authority
  unification and the lazy `ngspice_data`). That item changes a *published Tcl
  interface*, and the backannotation suites are its blast radius. **Item 5b owes
  its own sweep**, of `test_backannotate_digital` and every consumer of
  `ngspice::ngspice_data`, before it is written.
- **Nothing here covers Xyce**, which is unverified and has no fixture.

## What this licenses

Item 1 may proceed with "zero rows move" as its stated expectation. Item 2 the
same. Any deviation is a finding, not noise.
