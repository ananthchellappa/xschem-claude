# 0828 — GDI09/GDI10/GDI11 stay GREEN when the Graph dialog's attribute intake returns nothing, so the anti-hollow half of that group proves less than it reads

Status: **FIXED** (test-only) by item 0827+0817+0828, 2026-08-26. Originally
measured by the 0821+0816+0817 crew's sabotage agent, 2026-08-25. Severity: medium — it is a *test* defect, and it is the kind that
lets a real break ship past a green suite.
Family: the 0821 fix's own coverage (`tests/headless/test_wave_sigsearch.tcl`,
group **GDI**).

## 1. What was measured

Sabotage variant **SAB-A3** replaced the new intake with
`proc graph_rect_attr_noop {n tok {with_quotes 0}} { return {} }` and renamed all
three `graph_fill_listbox` call sites to it — i.e. the Graph dialog reads **none**
of `rawfile`, `sim_type`, `autoload`. Predicted red: GDI09, GDI10, GDI11.

**Observed: 0 red. `RESULT: ALL PASS (248 checks)`.**

That is not a harmless sabotage. With two raw files resident (current `aaa`, the
graph naming `bbb`), the fixed tree lists `bbb time` in the dialog and the
sabotaged tree lists `aaa time` — the dialog shows **the wrong database's
signals**, and the suite cannot see it.

## 2. Why each row survives

| row | why it passes with the intake dead |
|---|---|
| **GDI09** (`$netlist_dir` spelling registered under the resolved path) | Satisfied by the **C draw path**: `src/draw.c:3643-3655` reads the same three attributes off the same rect with `get_tok_value()` and calls `extra_rawfile()` itself. The `xschem raw info` assertion holds whatever the Tcl intake returns. It never covered the dialog route. |
| **GDI10** ("the listbox comes back NON-EMPTY") | It asserts `[winfo exists .graphdialog.center.left.list1]` — widget **existence**, not content. A dialog that lists nothing, or lists another raw's vectors, passes. |
| **GDI11** (one-vs-two resolution passes) | The registry key is also produced by the C path. GDI11 correctly detects an **added** Tcl pass (red under SAB-A1 and SAB-A2) but cannot distinguish a correct intake from an inert one. |

## 3. Fix direction (none taken)

Assert **content**, from the Tcl side, against the value the attribute names:

1. GDI10 should read `[.graphdialog.center.left.list1 get 0 end]` and require the
   vector names of *that graph's* raw — the `aaa`/`bbb` two-database fixture above
   is the discriminator and is already written in the sabotage transcript.
2. GDI09 should additionally assert the dialog's own `$rawfile`/`$sim_type` words,
   not only the C-side registry, or it is a draw-path test wearing a dialog test's
   name.
3. Re-run SAB-A3 as the acceptance: an inert intake must turn at least one row red.

## 4. Why it matters beyond three rows

The injection rows are fine — SAB-A1 and SAB-A2 discriminate them per field. But
the **anti-hollow** half is the half that stops a security fix from being paid for
with a broken feature, and here it is satisfied by a code path the fix did not
touch. A crew reading "GDI09/GDI10 anti-hollow ALL PASS" would reasonably believe
the dialog still works. It is the counterweight that has no weight.

---

## 5. FIXED — item 0827+0817+0828, 2026-08-26

**Test-only.** `graph_rect_attr` was never the defect; the rows were. No C change,
no rebuild needed for this part.

* **GDI10 rewritten** around the `aaa`/`bbb` two-database discriminator this issue
  already named: with `aaa.raw` resident and the graph naming `bbb.raw`, it now
  reads `[.graphdialog.center.left.list1 get 0 end]` and requires the **content**
  to contain `v(nbbb)` and *not* `v(naaa)`. The `winfo exists` check is gone.
* **GDI09 extended** to assert the dialog's own `graph_rect_attr … rawfile` words —
  the literal `$netlist_dir/...` spelling — not only the C-side registry.
* **GDI16 added**: the literal bytes of all three tokens (`rawfile`, `sim_type`,
  `autoload`) on a known rect, so an inert intake reds a row that **says so by name**.
* **GDI10b added**: the three shipped graph schematics still open their dialog *and*
  each listbox comes back with content.

`test_wave_sigsearch` 248 → **250 checks, ALL PASS** (`:99` Xvfb, openbox 3.6.1).

### 5.1 Acceptance — §3 row 3, met, and a correction to it

`SAB-A3` re-run **verbatim** (noop proc + the three `graph_fill_listbox` call sites
renamed): **GDI10 red** — `{1 0 {naaa time}}`, i.e. the dialog listed the **wrong
database**, exactly the failure this issue said the suite could not see. Before the
fix that same sabotage scored **0 red / ALL PASS (248)**. The acceptance is met.

⚠ **But GDI09 and GDI16 stayed green under SAB-A3**, and that is worth recording
rather than glossing: they call `graph_rect_attr` **directly from the test**, so
renaming the *dialog's use* of it cannot reach them. A second sabotage,
**SAB-7b** (gut `graph_rect_attr` itself — real body renamed away, an inert proc
installed under the real name), reds **all three**: GDI09 `{0 1 {}}`, GDI16
`{{} {} {}}`, GDI10. So the rows are **not vacuous** — they carry the proc's
byte-fidelity mechanism, which SAB-A3's shape leaves intact by construction.

**Consequence the next crew must not weaken:** if the dialog stops *calling* the
intake while the proc still works, **GDI10 is the only row in the group that
reds**. It is the single row carrying the dialog-wiring mechanism. Do not soften
it back toward a widget-existence check.
