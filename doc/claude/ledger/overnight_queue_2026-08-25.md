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


---

## Re-ordered 00:12, after 0682 reported

0682 landed as `4d4d745d` and was re-verified independently (test_annot_show_menu
10, test_ase_window 199, test_op_annot 342 — all pass on a second run, net
coverage across the three 543 -> 544). Its handling of the deletion trap was
correct and is worth copying: rows B1-B8 assert the View pair is GONE, and B9/B10
assert the replacement OWNER EXISTS, so "B1-B8 pass while B9/B10 fail" is
detectably *deleted a control and built nothing*.

**But it shipped a hole, and the queue is re-ordered for it.**

`Waves > Op Annotate` (`src/xschem.tcl:15391`, `:15408`) still turns annotation
ON, while the View pair that used to turn it off is gone and the ASE-L entries are
greyed without a session raw. **The tree can currently reach "annotated ON, no
menu anywhere turns it off"** — which is issue 0457's original complaint,
reinstated by the commit meant to honour the ruling that replaced it.

Its crew also filed **0684**: `ase::ui::annot_ensure_loaded` guards on *raw
loaded*, so it can display the **previous run's** operating-point numbers
indefinitely, and an unrelated waveform raw blocks the attach entirely. Stale
numbers presented as current is the worst failure mode an analog tool has, and a
worse invariant-I3 violation than the blank I3 was written about.

| # | item | change |
|---|---|---|
| 1 | ~~0682~~ | **DONE**, `4d4d745d`, independently verified |
| 2 | **0683 + 0684 as ONE crew** | **PROMOTED**, dispatched 00:12 as `w0yjvej6p`. 0684's header calls 0683 "the other half"; fixing either alone leaves the binding half-done |
| 3 | 0679 | slides from #2 |
| 4 | 0674 + 0675 + 0677 | unchanged |
| 5 | 0681 | unchanged |
| 6 | 0672 + 0673 | unchanged |

The 0683+0684 crew is told explicitly: **if the only way it can find to close 0683
is a `View > Show / Hide` entry, it must STOP and report that**, not ship it. The
user ruled that menu out; a crew quietly restoring it to reach green would be
this branch's defining defect committed on purpose.

## For the morning, in one line

The tree has a **live user-visible regression** between `4d4d745d` and whatever
closes 0683: annotation can be switched on with no menu to switch it off. If the
0683+0684 crew does not land cleanly, that is the first thing to look at.


---

## 03:00 — 0683+0684 came back REFUTED, and that is the crew working

Status **F**. The crew's own adversary pass refuted the fix; the crew reverted it
in full and committed **only the write-up** (`85cd3e7e`). Verified by the lead
rather than taken on report: `git diff 4d4d745d HEAD -- src/` is **empty**, no
`SABOTAGE` strings, no `_real` shims, and the three suites re-run green at
10 / 199 / 342.

**A crew that ships nothing because its own adversary killed the fix is the
process working, not a wasted run.** Three refutations, each re-measured on a
clean tree before the revert:

1. **The 0683 orphan is still reachable through sanctioned doors** — annotate
   from ASE-L, `File > Open` another cell, `Session > Close`, reopen: `annot_show`
   = 3, `v(a)` = 3.14 painting, **0 of 6 menubar entries clear it**.
2. **0684's headline acceptance fails on the primary gesture** — `111` stays on
   the sheet while the file on disk says `222`. Worse, the three rows written to
   catch exactly this (W1a18/19/20) all untick first, **so none of them could
   ever have seen it**. A test that cannot fail.
3. **The fix introduced a NEW data-loss regression** — `annot_drop_stale` cleared
   op/dc/tran at the session path, and when the re-read failed (ngspice mid-rewrite,
   file readable but truncated) it destroyed the user's loaded waveform database,
   where the old guard had survived.

Six issues filed: **0685–0690**. Two of them are harness-truth defects worth more
than they look — **0689** (the regression completion sentinel false-reds a suite
that prints a count) and **0690** (`test_ihp_sg13g2_libmgr`'s golden is one library
behind the tree). Between them they explain the standing "3 T1 FAIL" that every
run has been waving away as pre-existing.

**Root cause of 0683, now named: issue 0688.** `annot_show` is per-**WINDOW**,
while a session's only handle on its design is a **CELLVIEW PATH**. So
`annot_mask` read 0 while the mask was 3, and both the close-clear and the ASE-L
untick silently no-opped. It is a *lifetime* problem, not an entry problem — which
is why attempt 1 failed and why attempt 2 must start at 0688.

### Why attempt 2 was NOT dispatched tonight

The crew surfaced a trade **the user was never asked about**: under that fix, both
ASE-L Annotate items go dead on stock xschem for anyone who never opens ASE-L.
That is a user-visible ruling, not an implementation detail. Re-running unattended
would mean choosing it on their behalf, at 3 a.m., in the same area that just
produced a data-loss regression.

Recorded as a corrected rule debt instead — see below.

### A false statement was in the user's own queue, and is corrected

The Implement agent recorded rule debt `[0683]` reading **"0683+0684 SHIPPED"**
*before* the refutation. The revert left that claim standing in the morning queue.
Rule debts dedupe by id, and `owed.sh`'s own design treats a re-add as restating
one open question rather than discharging it — so `[0683]` has been **restated**
with the correction and the three things that actually need a ruling. **Nothing
was cleared.** The report-that-lies class does not get an exemption for landing in
the ledger instead of a write-up.

## Queue as it now stands

| # | item | state |
|---|---|---|
| ~~0682~~ | | DONE `4d4d745d`, verified |
| ~~0683+0684~~ | | **REFUTED + REVERTED** `85cd3e7e`; both still OPEN, awaiting ruling |
| 1 | **0679** | **IN FLIGHT** from 03:0x, `wcv7yljjg` |
| 2 | 0674 + 0675 + 0677 | queued |
| 3 | 0681 | queued |
| 4 | 0689 + 0690 | **added** — harness truth; they are why T1's 3 FAIL is noise |
| 5 | 0672 + 0673 | queued |
| — | 0683 + 0688 | **NOT queued** — needs the user's ruling first |


---

## 0679 — SHIPPED and verified, `cef8706a`

Both halves of the user's bench defect are closed, and the lead re-ran the suites
rather than taking the report: **test_ase_window 202, test_op_annot 342,
test_annot_show_menu 10, test_ase_final 76 — all pass**, counts matching.

```
REMEDY CMD : ase::ui::save_op_params_on .../ngspice_state1   KEY MATCH 1 (was 0)
gate after 1 (was 0)         save_all_apply(bogus key) : 0   (was a fabricated 1)
```

The `ALSO CHECK, because the same shape is likely nearby` clause in that brief
paid for itself: it turned up **0691**, `do_load_state_from` fabricating its
witness exactly as `save_all_apply` did. Third instance of that class on this
branch. Worth keeping the clause in future briefs.

### The crew scoped its own new issue honestly, which is the notable part

**0692** is a window the 0679 fix itself opened: an open `Save All` dialog is a
snapshot (`dlg($key,opparams)` written once at creation, `populate` never touches
it), so the CIW remedy turns the gate on behind it and OK writes the stale `0`
back. Measured `seed=0 remedy_rc=1 gate_after_remedy=1 box_still=0 ok_rc=1
gate_after_ok=0`.

It would have been easy to file that as "the user's bug is still broken." The
write-up says the opposite, unprompted:

> the user's own reported order (CIW first, *then* open the menu) is fine and is
> what 0679's acceptance covers. This is the other order.

And it names the trap in its own fix: `save_all_ok` returning `1` is **honest** —
it really did write what the dialog held. Nothing lies. The staleness is the
defect, so "make it report failure" would be the wrong repair. That instruction is
carried into the next brief verbatim.

## Dispatched: 0691 + 0692 as one crew — `wk24gne8q`

Both small, both `src/ase_window.tcl`, both the same family. Ahead of the notify
cluster because 0692 is causally downstream of a commit that landed tonight and
can silently undo a fix the user just applied.

Fenced explicitly: **do not widen into 0648's diff/cancel rework** — stop and
report if the honest fix needs it.

| # | item | state |
|---|---|---|
| ~~0682~~ | | DONE `4d4d745d` |
| ~~0683+0684~~ | | REFUTED + REVERTED `85cd3e7e`, both OPEN |
| ~~0679~~ | | **DONE `cef8706a`**, verified |
| 1 | **0691 + 0692** | **IN FLIGHT** `wk24gne8q` |
| 2 | 0674 + 0675 + 0677 | queued |
| 3 | 0681 | queued |
| 4 | 0689 + 0690 | queued |
| 5 | 0672 + 0673 | queued |
| — | 0683 + 0688 | NOT queued — needs the user's ruling |


---

## 0691 + 0692 — SHIPPED `3df8eda0`, with a residual its own crew escalated

Verified by the lead: **test_ase_window 208, test_ase_dialogs 172, test_op_annot
342, test_ase_final 78 — all pass**, counts matching, no sabotage residue.

Both filed defects are closed. The sweep clause found **three more** instances of
the fabricated-witness class — **0693** (`design_window` / `raise_window_entry`
report a raise they never verified), **0694** (`toggle_flag` discards the write's
answer and returns nothing), **0696**. That class is now at six known instances on
this branch, which is past the point of fixing them one at a time; a systematic
pass is worth queueing once the user's ruling backlog clears.

### The crew raised the severity of its own residual before shipping

`0695` was filed as a cosmetic display lag. The same crew's write-up pass struck
through its own sentence — *"the display lag is not a data-loss defect once OK and
ESC are honest"* — and marked the issue **BLOCKING**, because the lag has a data
consequence reachable through two shipped menu items:

```
WU-B2  box_at_open=1  load_rc=1  live_after_load=0  box_still=1  ok_rc=1  gate_after_ok=0
```

**The user sees a TICKED box, presses OK, and the setting goes OFF.** Before last
night the dialog was WYSIWYG-but-stale; now the widget and the action *disagree*.
That is a worse failure than the one 0692 fixed.

An agent contradicting its own earlier finding, in writing, before it could do
harm, is the behaviour this process exists to produce. Recorded so the pattern is
visible and not just the defect.

### Why this was fixed rather than banked for the ruling

The crew asked whether to land the display refresh as a follow-up or hold 0692
until the checkbutton follows live state. **Neither — it goes now.** "What the
user sees must be what OK writes" is not a product choice with two defensible
answers; it is a defect with one. The genuinely open part (how "touched" is
tracked once the variable can move underneath the user) is inside the fix and is
being decided by measurement, with the rejected alternatives stated.

The user's ruling backlog is for decisions only they can make. Padding it with a
defect that has one right answer would waste the morning they set aside.

## Dispatched: 0695 + 0696 — `wvydub20r`

Together because both hinge on the same question — what the dialog treats as the
user's intent versus the live state — and separate fixes risk two incompatible
answers to it. **0696 is also new as of `3df8eda0`**: ESC now prints a discard
notice for a setting that did apply and is still applied.

| # | item | state |
|---|---|---|
| ~~0682~~ | | DONE `4d4d745d` |
| ~~0683+0684~~ | | REFUTED + REVERTED `85cd3e7e`, both OPEN |
| ~~0679~~ | | DONE `cef8706a` |
| ~~0691+0692~~ | | DONE `3df8eda0` |
| 1 | **0695 + 0696** | **IN FLIGHT** `wvydub20r` |
| 2 | 0674 + 0675 + 0677 | queued |
| 3 | 0681 | queued |
| 4 | 0689 + 0690 | queued |
| 5 | 0672 + 0673 | queued |
| — | 0683 + 0688 | NOT queued — needs the user's ruling |
