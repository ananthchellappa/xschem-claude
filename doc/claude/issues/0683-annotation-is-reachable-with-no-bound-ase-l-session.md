# 0683 — annotation is reachable with NO bound ASE-L session (the orphan state)

STATUS: **STILL OPEN. Fix ATTEMPTED 2026-08-25, REFUTED and REVERTED the same day —
read §7 before retrying.** Blocking sibling of
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

> ⚠ **There are SIX, and two anchors below are stale.** Re-measured 2026-08-25:
> `ase::ui::close` (`src/ase_window.tcl:300-330`) is a sixth producer of the orphan
> STATE — it tears the session down and never clears the mask. Filed as
> [0686](0686-ase-ui-close-leaves-the-design-annotated-after-the-session-is-gone.md).
> And this section's file:line anchors for producers (a) and (b) are wrong:
> `src/xschem.tcl:15408` is `Waves > Sp`, and `:15804`/`:15822` are comment lines in
> the next menu item. The two real mask writes are **`:15391`** (`Waves > Op Annotate`,
> body `:15373-15402`) and **`:15789`** (`Simulation > Graphs > Annotate Operating
> Point into schematic`, body `:15770-15800`) — `grep -n 'xschem set annot_show 3'`
> returns exactly those two, and both bodies are straight-line with no predicate
> ahead of the write.


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

---

## 7. ⚠ ATTEMPT 1 (2026-08-25) — REFUTED AND REVERTED. READ BEFORE RETRYING

A full fix for 0683 **and** [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md)
was implemented, tested and reverted in one run. It reached 22 + 207 + 342 green
checks with a fully trustworthy sabotage matrix (8/8 variants, every predicted red
observed, plus 9 unpredicted ones) and was then refuted by the adversary pass on
three independent counts, all re-measured by the write-up pass on a clean tree.

### What it built (pure Tcl, no build; the shape is mostly right)

| proc | file | what |
|---|---|---|
| `ase::annot_binding_ok` | `ase.tcl` | 1 iff `session_for_current` yields a key AND `ase::has_results $key`; else speaks one refusal and returns 0 |
| `ase::no_results_notice` | `ase.tcl` | the second refusal wording, beside the shipped `no_session_notice` |
| `ase::ui::annot_entry_state` | `ase_window.tcl` | `normal` when the session has results **or** the entry's bit is already set — never grey away an off switch |
| `ase::ui::annot_attached_current` | `ase_window.tcl` | calls `op_annot::_annotated` (I1, not a fourth copy) + path identity + freshness stamp; every catch falls to RE-ATTACH, never to `return` |
| `ase::ui::annot_stamp` | `ase_window.tcl` | `annot($key,src)` = `{normpath mtime size}`, written only after the attach is VERIFIED by re-asking `op_annot::_annotated` |
| `ase::ui::annot_drop_stale` | `ase_window.tcl` | the [0685](0685-annotate-op-reuses-a-stale-registry-database-at-the-same-path.md) workaround — **this one caused a regression, see below** |
| `ase::ui::annot_clear_on_close` | `ase_window.tcl` | [0686](0686-ase-ui-close-leaves-the-design-annotated-after-the-session-is-gone.md)'s clear, through the existing writer |
| `ase::ui::annot_notify_displaced` | `ase_window.tcl` | echoes before `annotate_op` destroys another 1-point op/dc db |

Both producer bodies were wrapped whole in `if {[ase::annot_binding_ok]} { … }`,
with the guard **above** `select_raw` so a refused user never answers a modal file
dialog (`select_raw` also rewrites the global `netlist_dir` as a side effect of being
read). The mask-writer counts held: 2 in `xschem.tcl`, 1 in `ase_window.tcl`, so
`test_op_annot` N22 and `test_annot_show_menu` B6/B10 stayed green untouched.

### Why it was reverted — three refutations, each re-measured on the clean tree

1. **The orphan is still reachable, end to end, through sanctioned doors only.**
   Annotate from ASE-L → `File > Open` another cell in the design window →
   `Session > Close` → open the original cell again. Final state: `annot_show = 3`,
   `raw loaded = 0`, `op_annot::_annotated = 1`, `xschem raw value v(a) -1 = 3.14`,
   `session_for_current = ''`, 0 sessions, no `cadence::annot_mode`, and **0 of 6**
   annotation-ish menubar entries that clear the mask. Root cause and full transcript:
   [0688](0688-the-annotation-mask-outlives-the-schematic-so-window-keyed-binding-cannot-hold.md).
   The binding was keyed on cellview→window, and `File > Open` defeats it.
2. **The ASE-L off switch fails in the same state**, for the same reason —
   `annot_apply` → `annot_goto_design` returns 0, echoes *"cannot reach this session's
   design window"*, and the mask stays 3.
3. **A new data-loss regression.** `annot_drop_stale` cleared `op`/`dc`/`tran` at the
   session path; when the re-read then failed (ngspice mid-rewrite — readable but
   truncated), the user's loaded waveform database was destroyed and nothing replaced
   it. The old guard survived that scenario. Detail in
   [0685](0685-annotate-op-reuses-a-stale-registry-database-at-the-same-path.md) §4.

Plus a trade the user was never asked about: with the guard in place, both
`Waves > Op Annotate` and `Simulation > Graphs > Annotate Operating Point` become
**dead on stock xschem** for a user who never opens ASE-L, even with a perfectly good
`.raw` on disk. That is a working upstream feature deleted, in exchange for an orphan
that survived anyway.

### Binding on attempt 2

* **Fix [0688](0688-the-annotation-mask-outlives-the-schematic-so-window-keyed-binding-cannot-hold.md) first.**
  0683 is a **lifetime** problem, not an entry problem. A producer-side guard does
  nothing about a mask that is already on, and every session-keyed clear is defeated
  by an ordinary `File > Open`.
* **The refusal predicate is a separate, unratified user-visible decision** and it
  should be put to the user *with* the cost above, not on its own.
* **`vc/atk4.tcl`'s five steps must be a test row.** 571 green checks passed over it.
* The attempt's patch is kept out of the tree at
  `/tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_0683+0684/rejected/0683_0684_attempt.patch`
  (same-day artifact only). The proc inventory above is the durable part.
