# 1282 — the RDW renders a DC sweep as an operating point, and nothing on screen says so

**Filed by:** item **B3** (the Results Display Window), 2026-09-03. Found by
B3's adversary, **re-measured independently by the write-up agent** before
filing. **FILED, NOT FIXED.**

**Status:** open. Not a regression — the window is new, and this is the state
its own obligation 3 was written about, one state further in than anybody named.

---

## 1. The claim

The RDW's `ok` path prints the sentence

> Not a complete list: these are the **operating-point** columns this run saved
> for this device, not everything the device has.

over a block of numbers, **whenever the seam answers `ok`**. But the seam's
allow-list is `{op dc}`, not `{op}`. So a raw whose current slot is a **DC
transfer characteristic** answers `ok` with real point-0 numbers, and the window
presents them as an operating point. The word `dc` appears nowhere in the block.

The four non-`ok` states each get their own sentence, and `not_op` even names the
analysis it is refusing (`"The loaded results are a tran analysis, not an
operating point..."`). The `ok` path never names the analysis, although `ctx`
already carries `simtype` and `rdw::_state_sentence` already reads it.

## 2. Measured, on this binary, 2026-09-03

The mechanism, in two lines of shipped code:

* `src/ase.tcl:8803` — `} elseif {[lsearch -exact {op dc} $stp] < 0} {` — the
  seam admits `dc` alongside `op`. This is deliberate and correct: it is copied
  from `update_op()`'s own guard in `src/save.c` (see rule debt
  `1245_B1_not_op_refusal`).
* `src/rdw.tcl:213` — the `ok` arm of `rdw::_state_sentence` interpolates `$dp`
  only. `$sty` is read at `:199` and used **only** by the `not_op` arm at `:207`.

Driven end to end on a fabricated raw whose only plot is
`Plotname: DC transfer characteristic`, annotated with `xschem annotate_op <f> 0`:

```
DCPROBE sim_type = dc
DCPROBE state = ok  devices = @m.x1.m1 {{id 1.11e-05} {vth 0.75}}
DCPROBE ---- block ----
M1:/
@m.x1.m1
Not a complete list: these are the operating-point columns this run saved for this device, not everything the device has.
    id  : 1.11e-05
    vth : 0.75

DCPROBE ---- end ----
DCPROBE block-mentions-dc = 0
```

That is the whole defect: `sim_type = dc`, and the block says
*operating-point* twice (once in the sentence, once by existing at all) and
`dc` zero times.

## 3. Why it matters, and why it is not merely cosmetic

A DC sweep's **point 0** is the first step of the sweep, not the circuit's
quiescent operating point. Pasting that block into a design-review document under
a header that says "operating point" is exactly the plausible-wrong-number
failure **invariant I3** and **ruling D5-1** exist to prevent — the number is
real, it is just an answer to a different question than the heading claims.

It is also precisely the shape of the **three rendering obligations** the B3
brief made non-optional:

> **THE FOUR NON-`ok` STATES ARE FOUR DIFFERENT SENTENCES.** ... `not_op` in
> particular means the user is looking at a transient — say so and say what to do.

B3 honoured that for the four silences and added a fifth (`ok` with an empty
union). This is a **sixth**: `ok` *with* numbers, from an analysis that is not an
operating point. Nobody named it, so nobody fenced it.

## 4. Reachability

**Reachable in ordinary use.** `.dc` is a routine sweep card, an ASE deck can
enable it alongside `.op`, and once the dc slot is the current one the seam reads
it. No fabrication is needed beyond what the measurement above did for
convenience.

## 5. The fix, and the ruling it needs first

One line if the answer is "name it", in `rdw::_state_sentence`'s `ok` arm and/or
as an extra `note` line in `rdw::format_answer`:

```tcl
# when $sty is not "op", prepend/append e.g.
"These numbers come from the $sty analysis at its first point, not from a
 standalone operating point."
```

**But the wording, and whether a dc raw should be rendered at all, is a USER
decision and is unratified.** Three options, none taken here:

* **(a) render it and say so** — one extra sentence naming `dc`. Least
  surprising, keeps the seam's `{op dc}` allow-list honest on screen.
* **(b) render it silently** — what ships today. Defensible only if you consider
  a `.dc` point-0 to *be* an operating point, which it is for a `.dc` sweep whose
  source is at its nominal value and is not otherwise.
* **(c) refuse it** — answer `not_op` for `dc` too. This **contradicts** the
  seam's allow-list, which was copied from `save.c` deliberately, so it would be
  a change at B1's seam and not in the window.

Neither `doc/claude/op_param_batch/DECISIONS.md` nor
`doc/claude/specs/op_param_lists.md` mentions the `dc` arm at all (grep: zero
hits in both). This is entangled with the open rule debt
`1245_B1_not_op_refusal`, which asks the adjacent question about `tran`.

## 6. Part 2 — `rdw::sim` collapses two different refusals into one sentence

Same class, smaller. With `::rdw::sim` set to a name no backend registered,
`ase::backend_hook` raises *"unknown simulator"*, and the window says:

> Simulator `<name>` has no operating-point reader, so this window has nothing to
> show for it.

**Not registered** and **registered but declaring no `op_param_set` hook** are
different facts with different remedies, and this feature's whole obligation 3 is
that different silences get different sentences. Unreachable today (nothing sets
`::rdw::sim`); **item B5 is the first thing that will set it.**

## 7. Still open

Everything above. Nothing was changed in `src/rdw.tcl` or `src/ase.tcl` for this
issue — B3 shipped as measured, and this is filed rather than fixed because the
choice between (a), (b) and (c) is the user's and because (c) reaches into
another item's landed seam.
