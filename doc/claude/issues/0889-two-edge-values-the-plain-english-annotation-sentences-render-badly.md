# 0889 — two edge values the plain-English annotation sentences render badly

**Status:** **OPEN**, both parts. Found by the item A11 verification pass and
re-measured at write-up on 2026-08-28. Both were **introduced by 0886** and both
are one-line fixes; they are filed together because they are the same class —
*the sentence is right for the ordinary value and wrong for an edge one* — and a
single issue with two labelled parts is likelier to be fixed than two stubs.
Neither is a behaviour bug.

## Part 1 — "These symbol types" is plural when there is one type

`cadence::_annot_msg` closes with a clause naming the symbol types on the sheet
that have nothing to annotate. Measured 2026-08-28:

    cadence::_annot_msg 1 live /p/run.raw {nmos}
    → … These symbol types have no operating-point values to show: nmos.

    cadence::_annot_msg 1 live /p/run.raw {nmos pmos res}
    → … These symbol types have no operating-point values to show: nmos, pmos, res.

The three-type form reads correctly. The one-type form is a plural subject with
a single item, and one type is the common case on a small sheet — a lone
resistor, a lone capacitor.

**Fix shape:** branch on `[llength $types]` and mint *"This symbol type has no
operating-point values to show: nmos."* for the singular. It is the only clause
in the surface whose grammar depends on the data, which is why nothing caught
it: rows `A11-7` and `A11-12` render a fixed types list.

## Part 2 — a time of negative zero renders as "-0 s"

`cadence::_annot_tsec`, measured 2026-08-28:

| input | rendered |
|---|---|
| `4e-09` | `4 ns` |
| `3.0e-05` | `30 us` |
| `1.8` | `1.8 s` |
| `0` | `0 s` |
| **`-0.0`** | **`-0 s`** |
| `zzgarbage` | `zzgarbage` (deliberate — see 0886) |

So a cursor parked at negative zero produces

    Showing each node's voltage at -0 s, where cursor A is on the waveform.

Every other row is correct across the range probed, including `1e-13` → `100 fs`
and the unreadable-value passthrough, which is the documented and right choice.

**Fix shape:** normalise negative zero to zero before formatting, in
`_annot_tsec` and not at the call sites (RULING D5-4). Whether a transient's
x-axis can actually deliver `-0.0` to this proc was not established — the value
was fed to the proc directly — so this may be latent. It is a one-line guard
either way.

## Why no row saw either

Both are edge values of a fixture, and every fixture in `test_op_annot` feeds
the ordinary case: `A11-3` feeds `4e-09`, `3e-05` and `0`, never `-0.0`;
`A11-12` and `A11-7` render a types list of fixed length. This is the fixture
half of the same warning 0886 records about goldens — a golden proves the bytes
match for the value the crew chose to render.
