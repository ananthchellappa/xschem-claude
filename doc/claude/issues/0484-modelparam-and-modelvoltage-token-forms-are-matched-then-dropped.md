# 0484 — `@spice_get_modelparam_<p>(<dev>)` and `@spice_get_modelvoltage_<p>(<dev>)` are matched by the regex, then silently dropped — the token renders as *nothing*

Status: **OPEN, measured three times on this tree (S12 scout, S12 measure,
S12 write-up agent, all on HEAD `734456be`). NOT FIXED — filed, not fixed, per
the S12 brief.**
Filed by the S12 crew (2026-08-21). **This issue supersedes the plan's
reservation of number 0418** — nothing was ever created under 0418; the plan
reserved it and the number stayed free, so the next free number at filing time
was 0484. A reader chasing "0418" from the plan should come here.
Related: invariant **I3** (a missing value renders blank, never a wrong number
— this is the one clause I3 does *not* cover: rendering *nothing at all*),
issue **0485** (the element-letter twin, same token family, different failure),
spec §7 out-of-scope bullet, spec §2.3 (why `op_annot` exists at all).

## The claim

`translate()` recognises three token families with one regex and then
implements exactly one of them. The other two are consumed and produce empty
output — not an error, not a diagnostic, not the `-` marker the *same code
path* emits for an unresolvable device. Reserved-but-dead token forms.

## Measured — BEFORE transcript, quoted verbatim from the S12 measure agent

    @spice_get_current_id(mzz)         -> <10u>  len=3
    @spice_get_modelparam_gm(mzz)      -> <>  len=0
    @spice_get_modelvoltage_vth(mzz)   -> <>  len=0
    @spice_get_current_id(nope)        -> <->  len=1     (the vectors ARE in the
        raw: gm=9.9999997e-05 vth=0.69999999)

## Measured — AFTER, re-run independently by the S12 write-up agent

Same binary, same fixture, no tree change between the two runs (`git diff HEAD`
empty at both):

    == 0484: translate on instance xmzz1 ==
      @spice_get_current_id(mzz)             -> <10u> len=3
      @spice_get_modelparam_gm(mzz)          -> <> len=0
      @spice_get_modelvoltage_vth(mzz)       -> <> len=0
      @spice_get_current_id(nope)            -> <-> len=1
    == vectors ARE present in the raw ==
      raw value @m.xmzz1.mzz[gm] -> 9.9999997e-05
      raw value v(@m.xmzz1.mzz[vth]) -> 0.69999999

Line 1 and line 4 are the non-vacuity guards: the branch *works* for the
current form, and the *same branch* correctly emits `-` for a device absent
from the raw. Lines 2 and 3 ask for parameters that are demonstrably present
in the loaded raw (the two `raw value` lines prove it) and get back a
zero-length string.

## Why it renders as nothing rather than as `-`

1. `token.c:4646` — the regex compiled once into `get_sp_cur`:

       "^@spice_get_(current|modelparam|modelvoltage)(_[a-zA-Z][a-zA-Z0-9_]*)*\\("

   It matches **all three** families.

2. `token.c:4996` — `else if(!regexec(get_sp_cur, token, 0, NULL, 0))` — the
   branch that regex guards. Every token it matched is consumed *here*; no
   later arm can see it.

3. `token.c:5024` / `token.c:5028` — the body `sscanf`s only
   `"@spice_get_current("` and `"@spice_get_current_%[^(]("`. For a
   `modelparam` / `modelvoltage` token both fail, so `n` stays 0.

4. `token.c:5035` — `if(n >= 1)` is therefore skipped in full. `result_pos`
   never advances and the token contributes **zero characters** to the output.

The code says so itself. `token.c:4993-4994` carries the comment:

    * Only @spice_get_current(...) and @spice_get_current_<param>(...) are processed
    * the other types are ignored */

So the omission is *known to the source* — what is not known is that "ignored"
here means the token evaporates rather than degrading to the project's own
blank marker.

## Why this is an I3 problem, not merely a dead feature

Invariant I3 says a missing vector renders **blank** — "not 0, not NaN on
screen, not the previous run's number", on the `save.c` D5-1 precedent that a
plausible wrong number on a schematic is worse than none. A zero-length render
satisfies the letter of that and defeats its purpose: the user cannot
distinguish

* "this token form was never implemented" (what is happening), from
* "the parameter is not in this raw" (which the same branch signals as `-`),
  from
* "the text was empty to begin with".

Three very different states, one identical blank. Whatever the fix is, the
minimum is that the unimplemented forms produce the `-` the neighbouring
device-not-found path already produces.

**This is the sharp difference from 0485.** 0485's path renders `-` and is
therefore I3-clean — a dead end that *tells you* it is a dead end. 0484 is an
I3 visibility violation. That one sentence is what keeps the two issues apart.

## Two riders found while confirming the anchors — both file-only

**(a) The fallback `sscanf` at `token.c:5032` is itself dead code.**

    n = sscanf(token, "@spice_get_current[^(](%[^)]", dev);

`[` is a `scanf` directive **only after `%`**. Bare, it is an ordinary literal
character, so this format demands the input contain the literal characters
`@spice_get_current[^(](` — which no token ever does. The line can never match.
It reads like a typo for the `%[^(]` form one line above it at :5028.

**(b) The wrapper is a current wrapper regardless of the parameter.**
`token.c:5044-5060` hardcodes `i(...)` and the `[id]` / `[ic]` bracket default
for every prefix. So even the *working* form `@spice_get_current_gm(M1)` builds
`i(@m…[gm])` — a current wrapper around a conductance. Any fix that merely
routes `modelparam` into this branch inherits that, and would produce
`i(@m…[gm])` where ngspice wants the bare `@m…[gm]`. The correct shapes are
the measured rule R3 in spec §3 (kind 0 → `i(dev[p])`, kind 1 → bare
`dev[p]`, kind 2 → `v(dev[p])`), which `get_fqdevice()` already implements via
its `iprefix`/`ipostfix` pair at `token.c:5211-5212`.

Together (a) and (b) mean "implement the missing branch" is not a one-line
`sscanf` addition. That is why this is filed and not fixed.

## Anchors (every one re-verified by the write-up agent on HEAD `734456be`)

| What | Where |
|---|---|
| the three-family regex | `token.c:4646` |
| "the other types are ignored" comment | `token.c:4993-4994` |
| the branch that consumes all three | `token.c:4996` |
| `@spice_get_current(` sscanf | `token.c:5024` |
| `@spice_get_current_<p>(` sscanf | `token.c:5028` |
| the dead fallback sscanf, rider (a) | `token.c:5032` |
| `if(n >= 1)` — skipped entirely | `token.c:5035` |
| hardcoded `i(...)` wrapper, rider (b) | `token.c:5044-5060` |
| the bare (unparenthesised) twin branch | `token.c:5163-5166` |
| repro surface | `xschem translate <inst> <token>`, `scheduler.c:13483` |

## Repro

Fixture: a one-instance sheet `C {zfet.sym} 0 0 0 0 {name=xmzz1}` and a
hand-written 3-variable ASCII **Operating Point** raw carrying
`i(@m.xmzz1.mzz[id])`, `@m.xmzz1.mzz[gm]`, `v(@m.xmzz1.mzz[vth])`.

    xschem load z.sch
    xschem annotate_op z.raw
    xschem translate xmzz1 {@spice_get_modelparam_gm(mzz)}   ;# -> "" (len 0)
    xschem translate xmzz1 {@spice_get_current_id(nope)}     ;# -> "-" (len 1)

## Decision — file, do not fix

**Ladder rung L1**, invariant **I7** plus the S12 brief's explicit file-don't-fix
clause. Implementing the branch is user-visible behaviour with no ratification,
it needs a build (which S12 had no licence to run — one build per run, and
S12 is a docs step), and per rider (b) the obvious one-line version would emit
a wrong vector shape rather than none, trading an I3 blank for an I3
fabrication. **Rejected alternative:** the one-line `sscanf` addition at
`token.c:5028`, rejected for exactly that reason.

## Still open

* The fix itself. It needs the R3 vector shapes (spec §3), not the `i(...)`
  wrapper, and therefore touches both this branch and its bare twin at
  `token.c:5163`.
* Whether the unimplemented forms should emit `-` **now**, as a two-line
  I3 repair independent of ever implementing them. That is smaller than the
  full fix and would close the visibility half of this issue on its own.
* Rider (a), the dead fallback at `:5032`, is unreachable either way and should
  be deleted or corrected when someone is next in this function.
