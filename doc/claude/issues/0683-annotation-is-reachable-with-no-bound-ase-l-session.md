# 0683 — annotation is reachable with NO bound ASE-L session (the orphan state)

STATUS: **MEASURED 2026-08-24. Filed, not fixed.** Blocking sibling of
[0682](0682-annotation-visibility-belongs-in-ase-l-results-annotate.md).
Related: 0457, 0614, 0621, 0678, 0682, [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md)
(the other half of "annotation and its session are not actually bound": 0683 is annotation
with no session, 0684 is a session whose numbers are not the ones on screen).

---

## 1. Why this exists

The user's 2026-08-24 ruling (0682 §1, verbatim):

> results (including OP info) only make sense when there is a result loaded -
> meaning an ASE-L is active, to which this schematic is "bound".

0682 §4 draws the consequence and says it out loud: *"There is no 'annotated
schematic with no session' state to design an escape hatch for. **If one is
reachable today, that is a binding defect** to be found and fixed, not a menu to
be added."*

It is reachable today. This issue records the measurement. Per the 0682 brief it
is **filed here and NOT fixed inside 0682**.

## 2. The measurement

Measured 2026-08-24 against `src/xschem` (build 2026-08-24 18:40:47), by two
agents independently:

* With `ase::session_for_current` returning `{}` — no ASE-L session anywhere in
  the process — `xschem set annot_show 3` succeeds and `xschem get annot_show`
  reads back `3`.
* The RENDER half needs no new fixture: `tests/headless/test_op_annot.tcl`
  section L (rows L5–L16, inside `RESULT: ALL PASS (335 checks)`) drives
  `xschem set annot_show 0|1|2|3` and measures the annotated instance's bbox
  growing `0 -> $L_W`, in a `--nogui` process where **no ASE-L toplevel can
  exist at all**. Annotation renders end to end with nothing bound, and a green
  committed suite proves it.

## 3. The producers, all five

None of these involves ASE-L:

| # | producer | site |
|---|---|---|
| a | `Waves > Op Annotate` | `src/xschem.tcl:15391`, `:15408` — `xschem set annot_show 3` + `annotate_op` |
| b | `Simulation > Graphs > Annotate Operating Point into schematic` | `src/xschem.tcl:15804`, `:15822` — identical body |
| c | `set annot_show 1` in `~/.xschem/xschemrc` | honoured at `src/xinit.c:3839` |
| d | `cadence::annot_mode`'s `netlist_dir` fallback | `utils/annot_mode.tcl:160-167` — returns source `netlist_dir`, written **on purpose** for the no-ASE case |
| e | the `View > Show / Hide` pair | **deleted by 0682** |

(e) is gone. (a)–(d) ship.

## 4. Why it is blocking, not cosmetic

0682 deletes the View pair, so after it lands a stock user who clicks (a) or (b)
is annotated ON **with no menu anywhere that turns it off** — the ASE-L entries
stay greyed because there is no session. That is verbatim the complaint
[0457](0457-annot-show-has-no-stock-affordance.md) was filed about, arriving by a
different road.

So this is not "tidy up an unreachable state later". Until it is fixed, 0682's
own ruling ("that state should not exist") is a statement about code that must be
made true, not a description of the tree.

## 5. Options, none chosen — the user rules

1. **Bind at the producer.** (a) and (b) refuse (or first Launch ASE-L) when
   `ase::session_for_current` is `{}`. Smallest, and it makes the ruling true at
   the only two GUI entry points. Costs: two shipped menu items change behaviour
   for users who never open ASE-L.
2. **Bind at the mask.** `xschem set annot_show` (or `annot_show_sync_cache()`)
   refuses a non-zero mask with no bound session. Largest blast radius; reaches
   (c) and (d) too; C work.
3. **Auto-bind.** A producer with no session opens/attaches one. Most Cadence-
   like, most surprising, most code.

Option (1) is what §4's reasoning points at; recorded as a recommendation, not a
decision.

## 6. Acceptance rows (for whoever takes this)

* With no session: (a) and (b) leave `annot_show` at 0 and say why, through
  `ase::no_session_notice`'s wording (never a second spelling — issue 0168).
* With a session: (a) and (b) behave exactly as today (mask 3 + `annotate_op`).
* `tests/headless/test_op_annot.tcl` section L keeps working — it drives the mask
  directly, which is a scripted call, not a producer.
