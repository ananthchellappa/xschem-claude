# 0653 — a user action that delivers nothing must say why, through a channel that cannot itself go silent

**Status:** open, unratified (rc setting name + default are the user's call)
**Branch:** annotate
**Filed:** 2026-08-23
**Related:** 0497 (the write-side precedent), 0625 (missing vector renders `-` not blank),
0648 (the nudge going silent), 0650 (`ase::echo` has no sink), 0615/0614 (the chords)

## The user's request, verbatim

> I want to be better than Cadence. Can we do this(?) :
>
> If user does 6 and sees param = <blank> displayed, can Xschem detect (should be
> feasible) that nothing useful was displayed in response to most recent user action
> and tell the user the reason? Message in CIW should suffice unless user would like
> a pop-up dialog (dismissed with OK button or ESC button) for such notifications
> (through a setting in the rc file). The message printed to CIW to should say what
> setting user should use in rc file to get pop-up next time

## Why this is not a new idea in this tree — it is the missing half of one

`op_annot::last_warnings` (`src/op_annot.tcl:1231`) and `op_annot::last_counts`
(`:1252`) are precisely "the action did not deliver what was asked, here is what and
why", for the **WRITE** path (deck emission). Issue 0497 built them, and the header
comment records why, in terms that apply verbatim to the read path:

> ⚠ IT EXISTS BECAUSE SILENT UNDER-EMISSION IS THE FAILURE THAT SURVIVED 85 AND
> THEN 96 AND THEN 275 GREEN CHECKS.

and two design rules that this issue MUST inherit rather than rediscover:

1. **Count per pass, report once.** From `:1226-1230` — "An alert per cell would be
   intolerable on a real sheet — mips_cpu/controller alone would fire twice — so the
   walk counts instead". A sheet with 200 FETs and no save cards must produce ONE
   sentence, not 200.
2. **Split by cause; never one aggregate.** From `:1246-1250` — "Attempt 4 shipped ONE
   aggregate whose sentence ended `- normal for such cells`; on tb_bandgap_opamp it
   fired twice, the tool reported success, and 12 of 39 FETs had no card. A defect
   wearing the word "normal" is worse than no report at all."

The **READ** path — the one behind key `6` — has no accounting whatsoever. It has
invariant I3 (a missing vector renders BLANK, never 0, never fabricated), which is
correct and must stay, but I3 only guarantees the blank is *honest*. It does not
guarantee the blank is *explained*. That is this issue.

## Detection is mechanical: six exits, six reasons

Every blank the user can see on key `6` leaves `op_annot::text` (`src/op_annot.tcl:872`)
through one of six points. The proc is already structured this way; nothing needs
restructuring to count them.

| # | site | condition | what the user must be told |
|---|------|-----------|----------------------------|
| 1 | `:873-874` | `op_annot::type` -> {} | this instance is not claimed by any registered descriptor (not a device, or an unrecognised model) |
| 2 | `:875-876` | `op_annot::descriptor` -> {} | **no PDK descriptor is registered for this type** — the rc did not source `<pdk>_procs.tcl` / never called `op_annot::register` |
| 3 | `:877-878` | `op_annot::devpath` -> {} | the device name could not be built: a raising devproc, a blank template, or the 0488 prefix guard |
| 4 | `:886` | `_annotated` -> 0 | nothing is published — no raw loaded, or no annotation point selected |
| 5 | `:891-892` | `raw_or_blank` -> {} | the vector is absent from the raw: **the deck carried no device OP save card** (R1: ngspice publishes device params only if explicitly saved), or the name in the raw differs from the name we asked for (the 0496 class) |
| 6 | `:895`, `:915`, `:929` | `_finite` false | the value arrived but is nan/inf — including a derived row whose divisor was a genuine 0.0, which raises nothing |

Note 1-3 emit **no rows at all**; 4-6 emit rows with blank values. The user's report
was `id = <blank>, gm = <blank>` — rows present — so their case is 4, 5 or 6, and
distinguishing those three is the entire value of the feature.

### Cause 5 is specifically, quotably diagnosable

The user's own framed log (`~/.xschem/simulations/tb_bandgap_ase.log`, run
2026-08-23 18:32:09) is the proof that the reason is knowable, not guessable:

```
No. of Data Rows : 1
vbg = 1.214951e+00
en_n = 0.000000e+00
start = 1.841309e+00
i(vcc) = 3.144889e-05
temperat = 2.700000e+01
```

Five vectors, zero device parameters. So the notice can be exact:

> OP annotation: 39 devices requested 5 parameters each; the raw holds 5 vectors,
> none of them device parameters, and the deck contains 0 device OP save cards.
> ngspice publishes device parameters only when explicitly saved.
> Fix: Outputs > Save > "Save device OP parameters", then re-run.

That sentence names the count, the evidence, the rule, and the remedy. **The delta
over Cadence is not that we notice — it is that we can name the specific missing
thing and the specific control that supplies it.** dcOpInfo hands you blanks.

## The hole in the proposed channel, and it is this session's own defect one level up

`ciw_echo` (`src/ciw.tcl:120-121`):

```tcl
proc ciw_echo {line {tag {}}} {
  if {![llength [info commands winfo]] || ![winfo exists .ciw.l.t]} return
```

The CIW is a **closable toplevel**. Closed -> silent no-op. Therefore:

* a notice whose whole purpose is "you were not told something" **can itself fail to
  tell you** — the exact defect class of 0648 (the nudge going silent) and 0650
  (`ase::echo` has no sink in the ASE window); and
* the request's own discoverability clause — "The message printed to CIW should say
  what setting user should use in rc file to get pop-up next time" — is
  **self-defeating in precisely the case that matters**: the user who most needs the
  pop-up is the user whose CIW is shut, and the hint lives only in the CIW.

This is already a recorded rule in the tree, `src/wave_viewer.tcl:726`:

> ⚠ `ciw_echo` ALONE DOES NOT SATISFY "logged to the CIW and the log file".

### Required: four sinks behind one call

| sink | when | why |
|---|---|---|
| log file (`xschem log_action`) | **always** | durable, greppable, survives a closed window; this is what makes the notice auditable after the fact |
| CIW (`ciw_echo`) | when open | the requested channel, and the right one for a running session |
| `.statusbar.12` in the drawing window | when CIW is shut **and** pop-up is off | the can't-miss fallback. Precedent: `hilight.c:2201` already writes `*BUSY*` there. Carries a short form plus "see CIW / log" |
| modal dialog (OK / ESC) | rc opt-in | the requested pop-up |

Without the third row there is a reachable state — CIW closed, pop-up off — in which
the tool has diagnosed the problem perfectly and told nobody. That state must not
exist.

## Scope: build the channel, not a private path

The request is phrased generally ("nothing useful was displayed in response to most
recent user action") and exemplified specifically (key `6`). Build it that way:

* **one notify proc** — provisionally `xschem::notify <severity> <short> <long> <remedy>`
  — owning the four sinks and the rc setting;
* **first consumer: OP annotation** (this issue's six causes);
* **second consumer: 0650.** `ase::echo`'s missing sink is the same defect; routing it
  through this channel closes 0650 instead of giving it separate plumbing. One
  channel, one setting, every silent no-op in the tool.

Building a private annotation-only path would mean writing this twice and having two
places to forget a sink.

## Invariants this must not break

* **I3 stays.** A missing vector still renders blank. This issue adds an
  *explanation*, never a substitute value. (0625's `-` vs blank is a separate,
  compatible decision about the glyph.)
* **I4 stays.** The overlay never modifies the schematic; a notice is not an edit.
* **One sentence per pass, not per device** (0497 rule 1 above).
* **Never an aggregate that hides a cause** (0497 rule 2 above).
* **Headless-safe.** Under `--nogui` there is no Tk; the log sink must still fire and
  no sink may raise. `ciw_echo` already guards on `info commands winfo`; the pop-up
  and statusbar sinks must too, or every headless suite dies.
* **Never fires on an action that legitimately delivered nothing** — e.g. `6` pressed
  on a sheet with no devices at all. Requested-count zero is not a failure.

## Open rulings (the user's, not mine)

**R-0653-a — rc setting name and default.**
Proposed: `set ::notify_style {ciw|popup}` , default `ciw`.
Recommendation: default `ciw`, because a pop-up on every unremarkable blank is the
kind of thing that gets a feature switched off permanently. The statusbar fallback
means `ciw` is never actually silent.

**R-0653-b — does the pop-up apply to all notices or only annotation ones?**
Recommendation: all — one channel, one setting. A per-subsystem matrix is a
configuration surface nobody will read.

**R-0653-c — repeat suppression.**
Pressing `6` five times on the same unchanged state should not produce five identical
dialogs. Recommendation: suppress an identical notice while the underlying state is
unchanged, and re-arm when it changes — **the same "per state, not per event" shape
0648 landed for the OP-card nudge**, and the same shape the withdrawn 0636
recommendation needed. Reuse that latch rather than inventing a second one.

## Not yet decided, deliberately

Whether a notice should offer to *perform* the remedy (a "Enable device OP save
cards and re-run" button). That is a second feature and a second failure mode; keep
this one to naming the cause and the control.
