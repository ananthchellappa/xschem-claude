# 1256 — the stock `Waves > Op Annotate` menu preserves the declutter bit and says nothing about it

Status: **open** — measured by item **A4**'s write-up pass, 2026-09-02; **not
fixed**, `src/xschem.tcl` is in no Files cell of items A4 or A5 · Branch:
`fluid-editing`
Related: **1244**, **1251** (the sentence this menu does not emit), ruling
**D-8**, item **A3** (the draw rung)

## The defect

The declutter bit (`ANNOT_SHOW_NOPARAM`, bit 3) has **two doors**. One is the
cadence profile's `Ctrl-Alt-6` and the four annotation chords beside it, which
after issue **1251** all name the declutter in the status line. The other is the
stock `Waves > Op Annotate` menu, which:

* **preserves bit 3** — deliberately, and the comment above it says so:

```tcl
src/xschem.tcl:17311   xschem set annot_show [expr {([xschem get annot_show] | 3) & ~4}]
src/xschem.tcl:17749   xschem set annot_show [expr {([xschem get annot_show] | 3) & ~4}]
```

  `| 3` arms operating point + node voltages, `& ~4` drops the held transient
  snapshot, **and bit 3 is left exactly as the user set it**;
* **emits no status sentence at all.** The body runs `annotate_op`, then
  `update_all_sym_bboxes`, then `redraw`, and returns. There is no
  `statusmsg`, no `_annot_msg`, no `_annot_declutter_clause`.

So a user who armed the declutter with `Ctrl-Alt-6` and then annotates from the
**menu** gets a sheet with every device parameter stripped and not a word
anywhere saying why. Item A3's rung is what makes that visible; before A3 the bit
moved no pixel and the silence cost nothing.

## Measured, 2026-09-02

```
$ grep -c 'annot_show\] | 3' src/xschem.tcl
2                      # two copies, :17311 and :17749
$ sed -n '17311,17322p' src/xschem.tcl | grep -c statusmsg
0
```

And the render, on a one-instance fixture with a registered descriptor and **no
raw loaded at all** — i.e. the bit alone is enough to strip the sheet:

```
raw loaded = -1
mask 1 texts = MC1 CW=1u {cid =}
mask 9 texts = MC1 {cid =}
```

## Why item A4 did not fix it (ladder L2 — blast radius)

`src/xschem.tcl` is the stock GUI layer and is named in **no** Files cell of this
batch. The menu body is duplicated (`:17311` and `:17749`), it is shared with
non-cadence profiles where `::cadence` does not exist at all, and item A4's own
sentence family lives in `utils/annot_mode.tcl`, which the stock menu must not
depend on. Fixing it means either a C-side sentence or a guarded dispatch, and
either is a decision about the stock UI rather than about the cadence profile.

**Rejected alternative:** having item A4 append the clause from the menu body
anyway. It would put a `::cadence`-namespace call on a stock code path, which
breaks the moment the profile is not sourced — and there is no suite covering
that menu's status output to catch it.

## Suggested repair

Whoever owns the stock menu next: after the mask write, emit the same clause the
chords do, minted from the one place it lives
(`cadence::_annot_declutter_clause`, `utils/annot_mode.tcl`) **when that command
exists**, and nothing when it does not. That keeps invariant **I1** (one mint)
and costs the stock profile nothing. The wording itself is unratified — `owed.sh`
rule debt `1251` — so this should land after that ruling, not before it.

---

## A7 attempt, 2026-09-03 — **`[F]`, reverted. This issue stays OPEN.**

Item **A7-b** implemented the fix and its **plumbing was found sound** by both
verifiers: one new stock proc `annot_declutter_say` in `src/xschem.tcl` owned the
`update_all_sym_bboxes` + `redraw` pair for both Op-Annotate bodies (`:17311` and
`:17749`), measured the same counter delta, and — behind `info commands
::cadence::_annot_declutter_clause`, routed through `cadence::_annot_fit` for the
255-byte budget — borrowed the **one** cadence mint. Driven, not grepped, through
both doors and both `::cadence_compat` states. No mask writer added, guard not
moved, silent in stock xschem (driven with no `::cadence` namespace at all: both
doors rc 0, zero bgerrors, mask merged, planted sentinel untouched).

It was reverted because it **inherits** A7-a's refuted measurement (issue
**1270**): on an annotated device whose only non-`@name` text is already
`hide=instance`, the new `Graphs > Annotate` door emitted `Decluttering is on, so
other device text is hidden.` while the sheet was byte-identical. The repair is
in 1270 and is four lines of C; this item's own Tcl needs no change.

**One test-design defect the re-do must fix**, found by A7's sabotage pass: row
**A62**, the stock-xschem guarantee, is blind to its own sabotage. Its driver
wraps the invoke in `catch {$menu invoke $idx}` and `xschem set annot_show` runs
earlier in the `-command` body, so a raise leaves the mask already merged and the
sentinel untouched, and all eight legs still pass. A62 needs a leg asserting the
invoke did not raise, or a bgerror count.

Also recorded: the **Waves** door is refused outright under `cadence_compat=1`
(`waves_gate_blocked` → a blocking `alert_`), i.e. in the one profile where the
clause producer exists. The door that can actually speak the clause under cadence
is the **Graphs** door. Any suite row touching the Waves door needs the
`alert_`, `ase::annot_binding_ok` and `select_raw` stubs.

## Closed by item A7's re-do, 2026-09-03

Item **A7** implemented this, was refuted on a state nobody had named
(issue **1270** — the declutter counter counted the *rung*, not what came off
the sheet), was reverted with every line preserved as
`doc/claude/op_param_batch/A7_working_tree_REFUTED.patch`, and was re-done by
the driver: patch re-applied, the four-line repair added at A7's own edit point,
and two new suite rows (**A64**, **A65**) that catch the 1270 defect and the
tempting wrong repair, both proved by sabotage rather than asserted.

Read **1270** for the full account, including the residual risks that survive
this fix. Item A7 closes feature A of `doc/claude/op_param_batch/PLAN.md`.
