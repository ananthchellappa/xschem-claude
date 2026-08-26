# Overnight batch — night of 2026-08-25 → 26, to 07:00

Authorized by the user 2026-08-25 21:45 MST: *"keep executing on available open
items not requiring manual action till 7 AM tomorrow when I will have a look."*

**Budget: ~9h15m from 21:45.** Measured cycle time this batch is **1h55 mean,
~2h median** over 11 cycles (23:35 Aug-24 → 21:03 Aug-25), so this night is
**4–5 crews**, not more. Queue below is ordered so that if only three land, the
three that land are the three that matter.

## Standing constraints, unchanged

* **ONE CREW AT A TIME.** 7.8 GB box; a second concurrent `make` is the recorded
  OOM path. Dispatch only when the previous crew reports.
* **RULE AND LOOK DEBTS ARE NOT TOUCHED.** 23 rule, 39 look. They are the user's
  queue, they clear only on the user's word, and 07:00 is when that happens. No
  crew may clear, convert or discharge one — including a crew whose own suites go
  green over the thing a look debt is about. A crew that *narrows* a question
  restates the debt (dedupe by id); it does not close it.
* **Every commit re-verified by the lead independently**, not on the crew's report.
* **The stale-binary check is mandatory in every write-up**: if any `.c`/`.h`
  changed — including a comment — rebuild and state
  `find src -maxdepth 1 -newer src/xschem` = 0. This trap fired **twice** on
  2026-08-25.

## The queue, in dispatch order

| # | item | why here | state |
|---|---|---|---|
| 1 | **0821 + 0816 + 0817** | the rest of the Tcl injection family. 0821's trigger is worse than 0812's: opening a schematic someone sent | **IN FLIGHT** since 21:06, `wf_7b44465d-7ec` |
| 2 | **0827 + 0817 + 0828** | **INSERTED 00:20 after item 1 reported.** 0827 is a LIVE remote-code-execution on the *fixed* binary, reproduced by the lead: a mailed `.sch`, a stock `examples/rlc.sym`, one descend. No dialog, no gesture. It outranks data loss, and the family's patterns are hot | queued |
| 3 | **0807 + 0813 + 0814** | **DATA LOSS with a lying success return, live at HEAD.** Retry of a refuted attempt whose §11 is six binding constraints | queued |
| 4 | **0809 + 0811 + 0808** | finish 0688's clear: leaks into a new tab, only `load_schematic()` got the seam, three rows that claim to pin it and do not | queued |
| 5 | **0802 + 0805 + 0803 + 0804** | harness truth II — three readers of one completion banner, agreeing in none of them | queued |
| 6 | **notify channel** 0674 · 0675 · 0677 · 0699 · 0800 | unblocked by the user's 0806 ruling (raise the CIW; `.statusbar.12` retired) | queued, likely not reached |

**Not queued tonight:** 0684 (item 6 of the day queue) — its direction is settled
but it is the one item most likely to change shape under the 23 pending rulings,
and re-doing it after 07:00 costs a whole cycle. 0693/0694/0697 (the
fabricated-witness sweep) and the litter items are lower value than any of 1–5.

## The one place item 2 could have needed the user, and why it does not

0807 §11.4 makes acceptance depend on **0299**'s `res = 0; break;` at the binary
short-`fread` sites. 0807 §12 records that 0299 **carries a user question**: today
a real 59-point ngspice binary transient missing 3 bytes loads all 59 with the last
fabricated; under `res = 0; break;` it loads **nothing at all**. If a workflow polls
a raw while ngspice is still writing it, that trades a slightly-wrong plot for no
plot. That is a ruling, and rulings wait for 07:00.

**It does not block tonight, because the question has a third answer the two horns
hid.** The cost is asymmetric in the point count:

* a **1-point op/dc** raw with a short final point has **nothing salvageable** — the
  only point is the fabricated one. Refuse it. This is the bench case (0807 §5:
  ngspice writes binary by default, `v(b)` fabricated as `0`, and once
  `6.7903865e-315` out of a reused buffer).
* a **multi-point** raw short in its **last** point still holds every earlier point
  intact. 0299's own rejected alternative — `raw->npoints[datasets] = p`, keep the
  points actually read — costs the 59-point case **one** point, not all 59.

§8 rejected `npoints = p` on the grounds that *"it buys nothing for a 1-point op
raw"*. True, and irrelevant: it is not proposed for the 1-point raw. Split by point
count and both horns go away.

**Binding on the crew:** measure this, do not assume it. If the split does not hold
up, implement the refusal for the op/dc path only, leave `tran` at HEAD behaviour,
and say so — an acceptance row that needs a ruling is deferred, never guessed.
**0299's rule debt is RESTATED (narrowed), never cleared.** The user still rules on
whether a truncated multi-point tran should lose its last point or refuse outright;
the crew's job is to make that question smaller, not to answer it.

## Also binding on item 2, from 0807's own §11

1. `extra_rawfile_detach()` must handle the **unregistered** database —
   `raw_read` leaves `xctx->raw` live with `extra_raw_n == 0`, and `load_raw` is a
   shipped route. §7 has the three lines. **This is what refuted attempt 1.**
2. **No `xschem raw info` in a probe before the thing under test.** `raw info` is
   `extra_rawfile(4, ...)` and the base-insert runs before the what-dispatch, so a
   single `raw info` *registers* the database and hides the defect. The adversary
   measured a false green exactly that way.
3. **`xschem raw switch op` is a rotate, not a query.** Never build an acceptance
   row on it.
4. A truncated **binary** fixture is required (see above).
5. A failed annotate **must not renumber the registry**.
6. **Sabotage verified against the binary, not the source** — `grep -rn SABOTAGE`
   *and* `nm | grep _sab` are both blind to an inlined static one-call helper.

0812 is **FIXED** (`3ab11016` + `17b0c3fe`), so §12's "runs while a database is
detached" aggravating factor is retired rather than inherited.

## At 07:00

1. `tests/headless/owed.sh show` — the user's queue, for the ratification session.
2. `tests/headless/runtime_gaps.sh` on the night's runs. Host sleep is set to
   Never, so a gap means something else and wants a real diagnosis.
3. Every commit of the night re-verified by the lead, independently.


---

## Re-ordered 00:20, after item 1 reported

`05d259f9` landed and was verified independently by the lead (row in
`driver_run_2026-08-22.md`). 0821, 0822, 0825 and 0816 are fixed. **0817 is still
open, and the crew's adversary found 0827 — a LIVE RCE on the fixed binary.**

Reproduced by the lead, `--nogui`, no dialog and no gesture beyond a descend:

```
after-load     CVPWN=0 host=0
after-descend  rc-res=0 CVPWN=1 host=1   VERDICT=PWNED
```

`src/actions.c:4215` `cellview_sch_path()` builds `cellview_path {%s} schematic`
and `tcleval()`s it, with `%s` the instance's `schematic=` property read straight
out of the file. A `}` closes the brace group and the rest is parsed as script —
and `\}` is the `.sch` format's own escape for a literal brace, so the fixture is
**well-formed, not corrupt**. The delivery is one mailed `.sch` referencing
`examples/rlc.sym`, which ships with xschem.

**Why it jumps 0807.** 0807 is data loss on the user's own work, and it is real —
but arbitrary code execution from a document someone was mailed outranks it, the
trigger here is *more* ordinary than 0821's (no dialog needed), and the family's
resolver and test patterns are fresh in the tree this hour. 0807 slides to 3 and
loses nothing by waiting; it has waited since 16:12 already.

**Also folded into item 2:** 0828 (GDI09/GDI10/GDI11 stay green when the graph
attribute intake returns nothing — the anti-hollow half of that group proves less
than it reads). It is a test defect in the coverage the item just shipped, and it
belongs with the crew that owns that suite.

**NOT folded in: 0826.** `test_wave_markers` 6 FAIL. Corroborated by the lead as
**not** this commit — deterministic 3/3, and a pre-fix `xschem.tcl` swapped in
still fails 6. It is a standing red, which CLAUDE.md is explicit is a defect and
not furniture, but it is a *test* defect in a different subsystem and putting it
in a security crew's scope would dilute both.
