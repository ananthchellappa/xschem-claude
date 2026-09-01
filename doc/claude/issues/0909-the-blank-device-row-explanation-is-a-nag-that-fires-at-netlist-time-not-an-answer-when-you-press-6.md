# 0909 — the blank-device-row explanation is a nag fired at netlist time, not an answer given when you press `6`

**Status:** **FIXED 2026-08-28** (item A16, `utils/annot_mode.tcl`), then
**REPAIRED the same day** — the first delivery was green on 21 checks and dead
in the field. §8 records the decisions and the rejected alternatives, §8b the
four repairs, §9 what the fix does NOT close. Originally filed as:

**OPEN, MEASURED, NOT FIXED.** Filed 2026-08-28 from a **user
reproduction on their own bench**: `tb_bandgap`, operating-point analysis only,
**Outputs > Save All > "Save device OP parameters (gm, gds, vth, …)" unticked**,
then the `6` chord. Six blank rows on every device and **no CIW line saying why**.

**The user's words:** *"This was working a couple days ago. User intent with 6 key
press is to get OP device info annotated. If we annotate param = &lt;blank&gt; we need
to tell the user why. We were printing a message on why and how to fix through
menu or by running a command through CIW. What happened to that fix?"*

**They are right that it worked, and nothing was removed.** See §2.

---

## 1. What the user sees

Press `6` after an OP run with the save-cards gate off: every transistor gets its
six-row block and **every value is blank**. No refusal, no warning, no CIW line,
no status line. Indistinguishable from "the annotation is broken".

## 2. What actually happened — the message exists and is latched

The explanation the user remembers is real, is still in the tree, and is
**correct**. It is emitted by `ase::op_cards_capture` (`src/ase.tcl:750`) and it
carries exactly what the user describes — the menu path
(`ase::ui::remedy_op_params_menu`) and a pasteable CIW command
(`ase::ui::save_op_params_on`). It has been worked on repeatedly and deliberately:
0617/0618, 0648, 0650, 0664/0665/0666, 0679, 0691/0692, 0695/0696.

**Three gates stand in front of it, and the third is a one-turn latch:**

```tcl
proc ase::op_cards_capture {state netlistpath} {
  ...
  if {![ase::op_gate_on [ase::state_get $state save_op_params {}]]} {
    if {$have && [ase::op_analysis_enabled $state]} {
      if {[ase::op_cards_nudge_ok $state]} {          ;# <-- the latch
```

`ase::op_cards_nudge_ok` delegates to the generalised suppression latch
(`src/ciw.tcl:187`, R-0653-c):

```tcl
proc xschem::notify_latch_ok {subject {state {}}} {
  variable notify_latch
  set k [list $subject $state]
  if {[dict exists $notify_latch $k]} { return 0 }   ;# spoke once — silent after
  dict set notify_latch $k 1
  return 1
}
```

Its stated contract is *"Suppress an identical notice while the underlying state
is unchanged; re-arm when it changes."* The user never ticked the box, so the
state never changed, so it never re-armed. `notify_latch` is an in-memory dict, so
the scope is **once per cellview, per session.**

**Therefore:** the first netlist of `tb_bandgap` in a session prints the notice —
that is the "couple of days ago" the user remembers. Every subsequent
Netlist-and-Run of that cellview in that session is silent, correctly, by design.

## 3. The actual defect — the message is at the wrong moment

Two moments, and only one can speak:

| moment | code | can it explain a blank block? |
|---|---|---|
| **Netlist / Run** — the tool volunteers | `ase::op_cards_capture` (`src/ase.tcl:750`) | yes, **once per cellview per session** |
| **The `6` key press** — the user asks | `cadence::annot_mode op` (`utils/annot_mode.tcl`) | **never** |

`cadence::_annot_msg`'s state set is `off | live | notlive | noop | loaded |
failed | noraw | nopath | stale | staleraw | viewerdiff`. Every one of them
describes **the results file**. Not one describes **what is inside it**. So the
`6` path reaches "loaded, fine, annotate", succeeds, paints blanks, and has
nothing to say. Measured:

```
$ grep -c "noparams\|nosave\|save_op\|missing.*param" utils/annot_mode.tcl
0
```

**The design error, stated plainly: a suppression latch is right for a NAG and
wrong for an ANSWER.** A nag is the tool volunteering something while the user is
doing something else, and suppressing a repeat is courteous. A key press is the
user asking a direct question, and a question asked twice is answered twice. The
explanation was attached to the moment the deck is built; the user's question
happens at the moment they press the key.

## 4. Scope — the `6` press has more blank-row causes than this one

The new message must not assume the save-cards gate is the reason. Blank rows also
come from:
* **an unregistered PDK** — only sky130A, gf180mcuD and ihp-sg13g2 call
  `op_annot::register`, so on any other PDK the block is empty forever
  (issue [0906](0906-a-new-pdk-cannot-get-annotation-support-without-hand-writing-a-descriptor.md));
* **one device's vector missing** from an otherwise good raw;
* **a descriptor whose `devpath` does not resolve** for this model.

Each needs a different sentence, and each is the user asking the same question.

## 5. ⚠ Ordering — flipping the default would MASK this, not fix it

The user has separately approved flipping `save_op_params` to default on. **That
must land AFTER this**, or after it the commonest cause of blank rows disappears
and the silence looks fixed while every cause in §4 still produces it. The
silence on the key press survives the default flip; it is the defect, and the
flip is a convenience.

## 6. The fix

1. **Mint the explanation where `6` is pressed**, as a new state on the
   annotation surface: *annotation ran, and the values are blank because the
   device parameters are not in the results file.* Say why and say what to do.
2. **UNLATCHED.** The user asked; answer every time. Do not route it through
   `notify_latch_ok`. (The netlist-time nag keeps its latch — that one IS a nag.)
3. **Reuse the existing remedy fields, do not copy them** — `ase::ui::save_op_params_on`
   for the pasteable CIW command and `ase::ui::remedy_op_params_menu` for the menu
   path. Invariant **I1** and RULING **D5-4**: one mint, rendered by callers.
   Issue 0679 is the recorded cost of building a second construction of the same
   thing.
4. **Distinguish the causes in §4.** A wrong remedy printed with authority is
   worse than none — `src/ase.tcl:765`'s own comment says so.
5. Subject to the user's **PLAIN ENGLISH** ruling: say what happened, give the
   context, say what to do, ninth-grade level.

## 7. Test gap

No row could have caught this. Every assertion in `tests/headless/test_op_annot.tcl`
reads `xschem get statusmsg` — the 256-byte C status buffer — and the notice under
discussion goes to the **CIW pane** through the notify channel. The suites test a
different sink from the one the user reads. Worse, the blank-row case is not a
refusal, so there is no state for a row to assert on in the first place.

A row for this must assert **the CIW channel**, and must press `6` **twice** —
because a latched message passes a single-press test and fails the user.

---

## 8. What was built, and the four decisions inside it

All of it in `utils/annot_mode.tcl`. **No C change**, and `src/ase.tcl` is
byte-identical — the netlist-time nag and its suppression are untouched.

Five new helpers and one extended one:

| helper | what it answers |
|---|---|
| `cadence::_annot_scan {{withblanks 0}}` | gained a **third** element: `1` a device block on this sheet has a blank row, `0` none does, `-1` nobody asked |
| `cadence::_annot_devparams_present` | does the attached results file carry a device **parameter** vector — see §8b.1, the first draft asked a different and useless question |
| `cadence::_annot_session_key` | the ASE-L key that owns this sheet, out of the **registry** (issue 0679) |
| `cadence::_annot_op_cards_off` | does that session's save-device-parameters gate read off |
| `cadence::_annot_cause` | `nocards` / `noparams` / `somedev`, or `{}` |
| `cadence::_annot_cause_msg` | the one mint for the three sentences (RULING D5-4) |
| `cadence::_annot_remedy` | `{menu command}`, both read from `ase::ui::*`, never typed |

`cadence::_annot_msg` gained an optional fifth argument (the cause clause) so
every existing caller and every committed golden stays byte-identical, and
`cadence::_annot_ciw` gained an `args` branch, because `ase::echo` goes through
`notify_safe`, which **drops** `-menu` and `-command`; only a direct
`::xschem::notify` renders them.

**D-0909-a — a CLAUSE, not a STATE.** §6.1 asked for "a new state". The
blank-row fact is *orthogonal* to `live`/`loaded` — it can be true under either
— so a state would have had to be duplicated per state, or would have deleted
the sentence naming the results file. It ships as an appended clause with its
own switch and its own byte-exact goldens.

**D-0909-b — the cause clause is placed SECOND, ahead of the results-file
clause.** The status line holds 255 bytes and already elides on long paths
(issue 0639). Putting the answer first means what the budget sacrifices is the
file name, not the answer to the question the user just asked. Rejected:
chronological order, which reads more naturally and loses the news first.
**⚠ Measured consequence:** the mask sentence is 55 bytes and the long
`nocards` sentence is 229, so **the bar overflowed before a path or a
symbol-type clause was added at all** and the fitted line ended
`… Turn on saving...` — the remedy verb surviving the cut and its object not.
The CIW pane was unaffected; it gets the sentence whole. Closed by §8b.3.

**D-0909-c — both sinks, not the CIW alone.** The user's words name the CIW
twice and the remedy fields render only there. But RULING 0857 already settled
this shape: a plain xschem user with no ASE-L window would not see a CIW-only
sentence at all. The pane gets the sentence **with** the remedy fields; the held
status line gets the same sentence **without** them.

**D-0909-d — the descriptor clause is no longer suppressed on a mixed sheet.**
`utils/annot_mode.tcl`'s recorded decision was "only when NOTHING here can be
annotated is the descriptor clause news", and that is precisely what hid the
unregistered-PDK cause on the realistic bench: one registered FET plus one
hand-drawn symbol scans `1 <type>`, the gate dropped the clause, and the user
was told nothing about the block that never appeared. The gate is gone. The
clause itself is unchanged and already golden (row N15); only its reachability
moved. **This is a user-visible wording change on sheets that used to say
nothing** — on the committed `test_nfet_final` cell it now names `vsource`.

**D-0909-e — the blank probe is deduped by cell**, riding `_annot_scan`'s
existing single walk, so one press costs one `op_annot::text` per distinct cell
rather than per device. The accepted limitation is issue **0913**.

## 8b. The repair — four things the first delivery got wrong

The first delivery reported ALL PASS on both arms and was **dead on the user's
own bench**. All four are in `utils/annot_mode.tcl`; still no C change, still
`src/ase.tcl` byte-identical.

**8b.1 — `nocards` was unreachable on every real bench, which killed the whole
deliverable.** `cadence::_annot_devparams_present` counted any vector holding
both `@` and `[` as a device operating-point number. **`.options savecurrents`
is a different tickbox** from *Save device OP parameters*, it is set in **35 of
the committed ASE states** — `tb_bandgap_opamp` among them — and it makes
ngspice write a terminal current per device whether or not one save card was
emitted. Verified by running ngspice 46 on the real deck for the suite's own
cell:

| deck | vectors written |
|---|---|
| `savecurrents` only | `i(@m1[ib])` `i(@m1[id])` `i(@m1[ig])` `i(@m1[is])` |
| save cards too | `@m1[gds]` `@m1[gm]` `v(@m1[vth])` + the four above |

So the probe answered 1 on every operating point, `_annot_cause` short-circuited
to `somedev`, and the user's exact case got the wrong sentence **and no remedy
at all**. Fixed two ways: the probe ignores anything wrapped in `i(`, which is
ngspice's own separator between a current and a parameter; and `_annot_cause`
asks the **tickbox first**, because the tickbox is a measurement of the run's
configuration while the file probe is an inference from vector names.

**8b.2 — the suite could not see it, because the suite wrote the results file
itself.** `test_annot_blank_cause_0909.tcl` took the path where the simulator's
output would go and overwrote it with a hand-written two-variable file holding
`v(d)` and `v(g)` — a shape the product never produces — so the one element
that decides the whole outcome was assembled by the test. The fixture now writes
the shape the real simulator writes, with the vector names built by **op_annot's
own name builder** rather than typed, and rows **BC1** / **BC1b** assert the two
questions separately: the file *does* hold `@dev[…]` vectors and *none of them*
is a parameter.

**8b.3 — the bar's sentence was cut mid-remedy, so each cause gained a SHORT
form.** This is the ruling D-0909-b asked for, answered rather than deferred:
the short form is minted beside the long one in `cadence::_annot_cause_msg` and
asked for by argument, the way `xschem::notify` already gives every notice a
`-short`. The pane keeps the long form. Rejected, and recorded because they are
what a later reader reaches for: shortening the *long* sentence makes the pane
pay for the bar's budget; putting the cause *last* lets the elision eat the
answer to the question just asked. Rows **A11-12c** and **BC5b**, the latter now
requiring the line to arrive with **no elision marker at all**.

**8b.4 — D-0909-d's unsuppression was naming a picture as a failed device.**
With the gate gone the descriptor clause reached every press of every real
design, as a **warning**, on completely successful annotations. Measured on the
user's own benches: `tb_bandgap_opamp` scanned `capacitor isource logo
subcircuit vsource` and `sky130_tests/tb_bandgap` scanned `ammeter logo probe
subcircuit vsource`. `logo` is the xschem logo graphic and `subcircuit` is a
hierarchy block. `cadence::_annot_skip_types` now skips stimulus, instruments,
hierarchy blocks and the logo — **part 1 of issue 0460**, filed by S8's own
adversary pass on 2026-08-19 and unfixed until the clause became reachable —
plus `missing`, which is not a symbol type at all but xschem's marker for an
unresolved symbol, i.e. a library-path problem being reported as a missing
descriptor. The passive device types 0460 also proposed skipping (`resistor`,
`capacitor`, `inductor`) are deliberately **kept**, because those are exactly
the ones whose absence is the issue-0906 news the clause exists to carry:
`capacitor` is still named on the user's own `tb_bandgap_opamp`, and it should
be. The unsuppression itself stands; **on the committed `test_nfet_final` cell
the clause is now silent**, which is the correct answer for a sheet whose only
unannotated symbol is a voltage source.

## 9. What this does NOT close

* **The wording is this crew's and is not ratified** — recorded as an owed
  rule. That is now **six** sentences, not three: each cause has a long form
  for the pane and a short form for the bar.
* **The skip list is a judgement about which symbol types a design kit might
  one day describe**, and it is this crew's judgement, not the user's. Skipping
  `subcircuit` is the one worth a second look: a kit that models its devices as
  subcircuits would go unmentioned. Recorded in the same owed rule.
* **Issue 0460 part 2 stays open** — an unresolved symbol is now skipped rather
  than mislabelled, but it is still not reported in its own words by this
  surface; xschem's own missing-symbol reporting is what covers it.
* **No pixels were measured.** The CIW is read at `::ciw_echo`, the pane's own
  entry point, not off a Tk text widget — recorded as an owed look.
* **Issue 0913** — a device whose cell siblings populate is not probed.
* **Issue 0906** (a new PDK cannot get annotation support without hand-writing a
  descriptor) is documentation only and stays open. Its *cause* now has a
  sentence here; its *remedy* does not exist yet, which is why that cause
  deliberately carries no remedy fields at all.

## 10. Rows

New suite `tests/headless/test_annot_blank_cause_0909.tcl` (**27 checks**), on
both arms. BC2 is the user's exact case through the real supply chain and is the
first row in this family to assert **the CIW channel** rather than the 256-byte
status buffer; BC4 presses `6` three times and requires three byte-identical
lines, and is the row a reintroduced suppressor dies on; BC6, BC13 and BC15 are
its structural backstops. `tests/headless/test_op_annot.tcl` gained A11-12b,
A11-12c and A11-13b and extended N14, A11-10 and V43.

**Six rows came out of the repair, and each closes a guard that nothing could
see.** Every one was checked by neutralising the guard it names and watching it
go red:

| row | the guard it is the only sight of |
|---|---|
| **BC1** | the results file holds `@dev[…]` vectors **and** no device parameter — the two questions the first draft could not tell apart |
| **BC1b** | `_annot_devparams_present` ignores a terminal current, so `_annot_cause` reaches the tickbox at all |
| **BC1c** | the **order** of the two questions inside `_annot_cause`. A registered session with the box off *and* a real parameter in the file is the only state that can tell the two orders apart; the sabotage pass flipped the order in both directions with 495 checks green |
| **BC18** | `noparams` keeps the menu path and drops the pasteable command, measured where a **real** session key exists — BC9 passes vacuously with respect to that split, because its sheet has no session and the key is empty |
| **BC19** | the positive twin: a completely successful press on a bench **carrying a voltage source** says nothing at all. BC12's synthetic one-symbol sheet cannot see this, and every real testbench has a source |
| **BC20 / BC21** | the skip list by name, in both directions; and the `> 4 → and more` truncation, which this item made live on real designs and which could be changed from four to two with both suites green |
