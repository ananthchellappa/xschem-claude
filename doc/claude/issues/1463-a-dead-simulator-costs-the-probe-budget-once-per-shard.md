# 1463 — a registered binary that never answers costs the probe budget ONCE PER SHARD

**Status:** open · **Filed:** 2026-09-14 by the driver, from a measurement in issue 1462's receipt
**Area:** ASE-L / capability probe · **Related:** 1462 (found it), 0948, 0963

## The measurement

From Stage 11 task 1's repair, measured on this machine:

| | |
|---|---|
| one capability probe against a binary that never answers | **31 296 ms** |
| a **two-point** campaign against the same binary, with a one-second run budget | **64 420 ms** |

**Two shards, two full probe budgets.** `cap_budget_ms` defaults to 30 s, and **a timed-out probe
is not cached** — so every shard pays it again.

A hundred-point campaign against such an entry would spend **fifty minutes** doing nothing but
waiting for a program that is never going to reply, and the run budget the user set is irrelevant
to every second of it.

## ⚠ This is ASE-L's existing behaviour, not the campaign's

The probe cache stores an **answer**. A timeout is not an answer, so there is nothing to store, and
the next caller starts again. That is defensible for a single run — the binary might have been
temporarily busy — and it is indefensible once a caller is a **loop**.

Issue 1462's crew found it, recorded it, and **deliberately did not fix it**, because it is not the
campaign's defect and a campaign is not the only loop that will ever exist. That was the right
call, and this issue exists so the finding is tracked somewhere other than a receipt.

## What is NOT known

* **Whether a timeout should be cached at all**, and for how long. Caching it forever turns a
  transient failure into a permanent one until the user notices; caching it for the life of a
  campaign is probably right and is a narrower claim.
* **Whether the 30 s default is right.** `evidence/binary-differences.md`'s appendix measured a
  *healthy* probe at **≈ 5 ms per launch**, so the budget is three orders of magnitude above the
  normal case — which is correct for a budget and does mean a dead entry is expensive.
* **What a user sees while it happens.** Unmeasured. If the campaign reports nothing for fifty
  minutes, that is a second defect on top of this one.

## Options

| | what | cost |
|---|---|---|
| **A** | **(recommended)** cache a **timeout verdict for the duration of one campaign** — the loop asks once, every later shard gets the stored *"this binary does not answer"* immediately | small and narrow; it does not change what a single run does |
| **B** | cache the timeout like any other answer, until the registry entry changes | bigger blast radius: a binary that was briefly busy stays condemned |
| **C** | let the campaign probe once up front and refuse before any shard runs | arguably the best user experience — **and it is a refusal, so it needs ⚖ R9 wording** |
| **D** | nothing; the run budget is per-shard and the probe is not | the honest do-nothing, and it is what ships today |

⚠ **A and C are not exclusive**, and C is the one a user would notice: *"this simulator did not
answer; the campaign was not started"* in one second beats the same conclusion in fifty minutes.
