# Overnight batch — night of 2026-08-24 → 25

Authorized by the user 2026-08-25 00:00 MST: *"sounds good for an overnight
batch. We will resolve rule and look debts in the morning."*

**Standing constraint for the whole night: ONE CREW AT A TIME.** This box has
7.8 GB and a crew's Implement agent runs `make`; a second concurrent build is the
recorded OOM path. Each crew is dispatched only when the previous one reports.

**Rule and look debts are NOT touched.** They are the user's queue, they clear
only on the user's word, and the morning is when that happens. No crew may clear,
convert, or discharge one — including a crew whose own suites go green over the
thing a look debt is about.

## The queue, in dispatch order

| # | item | why here | state |
|---|---|---|---|
| 1 | **0682** | the user's fresh ruling: annotation visibility moves to ASE-L `Results > Annotate` | **IN FLIGHT** since 23:35, `wf_08dccf38-c10` |
| 2 | **0679** | **the only item the user personally hit**, and it lies when it fails: the printed remedy returns 1 and changes nothing | queued |
| 3 | **0683** | the orphan-session binding defect 0682's crew filed; blocking sibling of 0682 | queued, conditional — see below |
| 4 | **0674 + 0675 + 0677** as ONE crew | four crews have filed 24 issues against this one notify channel and closed 6, one slice at a time. Batching is how that stops | queued |
| 5 | **0681** | three shipped floaters moved chord with no test row, under a committed comment claiming none moved | queued |
| 6 | **0672 + 0673** | small hygiene defects the 0663 crew filed against itself | queued |

**Deliberately NOT queued: 0676.** Measured once, never reproduced on demand. A
crew against an unreproducible flake burns a slot and returns a maybe.

## Conditional on 0682's report

0683 says the orphan state IS reachable, and calls itself a blocking sibling. If
0682 comes back **blocked** on it, 0683 is promoted to #2 and 0679 slides to #3 —
because a half-landed menu move is worse than either half.

If 0682 lands complete, 0683 stays at #3 on its own merits.

## Morning checks, in order

1. `tests/headless/runtime_gaps.sh` on the night's runs — the 5.75 h gap of
   2026-08-24 was the Windows host sleeping, and the btime contradiction is what
   proved it. Host sleep is now set to Never, so a gap tonight means something
   else and wants a real diagnosis, not the same answer.
2. `tests/headless/owed.sh show` — the user's queue, for the ratification session.
3. Every commit of the night re-verified independently, not on the crew's own
   report. `94c507fc` shipped with its issue header still reading `Status: OPEN`;
   that was caught by reading the file, not by trusting the summary.
