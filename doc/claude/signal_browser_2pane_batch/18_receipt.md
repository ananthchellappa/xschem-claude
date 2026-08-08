# TWO-PANE item 18 — R12: auto-tick, reveal, and say so

Spec: `doc/claude/specs/waveform_signal_browser_two_pane.md` R12, §7.4, §8.2, §9.
PLAN: `doc/claude/signal_browser_2pane_batch/PLAN.md` item 18.

**Status: `[x]` — no pixel deliverable, no eyeball owed** (see §12).

---

## 1. What shipped

`browser_show_path` learns one arm. When the walk misses **and the model with
device internals shown WOULD contain the full path**, it ticks R11(a) through
the checkbutton's own `-command`, re-resolves against the refreshed row model,
reveals, and returns a new `{unhidden <id> <landed>}` result whose sentence comes
from the **one** formatter. The box stays ticked.

Three edits, all in `src/wave_viewer.tcl`:

| proc | edit |
|---|---|
| `browser_msg` | one arm — `unhidden { return "showing device internals to reach [lindex $res 2]" }` |
| `browser_say` | one arm — `unhidden { set r [list unhidden $a $b] }` |
| `browser_show_path` | the R12 probe between the walk and the shipped improve-or-restore, plus one `variable browserraw` and one return arm at the tail |

---

## 2. THE PLAN WAS WRONG SIX TIMES. Every number here was re-measured.

| PLAN said | MEASURED | consequence |
|---|---|---|
| band `BK40`-`BK47` (heading) / `BK40`-`BK49` (code, 10 ids) | first free is **`BK32`** | took `BK32`-`BK42`. The PLAN's band predates items 16 and 17b, which spent `BK01`-`BK31`; it is also internally inconsistent (8-id heading over a 10-id block). **Third time in this batch.** |
| "the four SHIPPED results still render as **BX13**'s four" | the four are **`BX14`** (`_i12.tcl:387-396`); `BX13` is the guide oracle; and there are **NINE** renderings since two-pane item 11 | `BK33` pins all nine |
| `{err {no such node}}` | `{err {no signals under '<asked>'}}` (`wave_viewer.tcl` miss arm) | `BK39` uses the shipped literal |
| example node `g:x1.xm1` / `x1.xm1` | **absent from BOTH models** of the corpus | the band uses **`x1.x1.xm1`** — absent with the box off, present with it on, three own-level signals all `devnode` |
| "`test_wave_modes.tcl` still **214**" | **212** headless / **488** X | stale by four items; re-run and reported, unmoved |
| "reds existing: **none**" | **reds `BW59`** | restated `{4 4 1 1}` → `{5 5 1 1}`. **Third time in this batch** the PLAN's "reds nothing" was wrong (item 12 red `BW25`, item 17b red its own). |

### 2.1 The corpus arithmetic, re-measured before a single literal was written

`tests/headless/fixtures/tb_bandgap_vars.txt` — **424** names.

| | srccur 1 | srccur 0 |
|---|---|---|
| **devint 1** | 424 signals / **129** nodes | 374 / **129** |
| **devint 0** | 190 / **45** | 140 / **45** |

`BW61`'s 45/129 is right and the spec §3.3's 44/128 is wrong (it counts
instances and misses R2's design ROW) — exactly as item 12's receipt says.
Hidden device nodes = 129 − 45 = **84**, at depths 5 / 75 / 4 (levels 2 / 3 / 4).

**`srccur` moves the node count by ZERO, and 0 of the 84 nodes are revealed by
the device box only when the source-currents box is on.** That single measurement
is what forced the design (see §5) and what makes S6's zero-behavioural-red a
*fact* rather than a coverage hole.

---

## 3. The design decision the measurement forced

The obvious shape — **tick, refresh, re-resolve, untick if it failed** — has a
confirm guard, and a confirm guard **swallows the PLAN's first sabotage**:
forcing the decision to always-yes reds nothing, because the guard puts the box
back. The guard is also **unreachable** on this corpus (the zero above), so it
would be dead code no sabotage could ever exercise.

So the shipped shape has **ONE decision point**: a **pure probe** that rebuilds
the would-be model in memory through the same procs the refresh uses
(`signal_entry` → `browser_class_filter` → `browser_rows_multi` →
`browser_node_for`), touches no widget, fires no refresh, and only then invokes
the checkbutton. That is what makes S1 bite (§7) and what keeps the seven shipped
miss-arm checks green (§6).

**A POSITIVE TEST, NOT AN ABSENCE.** `BK39`/`BK40` are the dual pair that pins it.

---

## 4. The three traps that were avoided by construction

* **`TP44`** (`_2pane.tcl:849-851`, `browser_id_path` in `browser_show_path`'s
  body **== 1**). The new arm merges into `$id`/`$matched` and lets the shipped
  decode at the tail run once, for both `ok` and `unhidden`. Re-measured **1**.
  Proven live by **S5**, which reds `TP44` *and* `BK35` — two files, one cause.
* **`BW59`/`BD06`'s comment rule.** Neither accessor is named in any comment
  added by this item; they are "the device-internals box" / "the source-currents
  box" throughout. `browser_alldbs` re-measured file-wide **2**, untouched.
* **`BX09`** (no `sch_path` in the body). Re-measured **0**.

---

## 5. Measured source counts, before → after

| grep | before | after |
|---|---|---|
| `browser_devint` file-wide | 4 | **5** |
| `browser_srccur` file-wide | 4 | **5** |
| `browser_devint` in `browser_refresh` | 1 | 1 |
| `browser_srccur` in `browser_refresh` | 1 | 1 |
| `browser_alldbs` file-wide | 2 | 2 |
| `opt.dev` file-wide | 2 | **3** |
| `device internals to reach` file-wide | 0 | **1** |
| …of which inside `browser_msg` | 0 | **1** |
| `browser_id_path` in `browser_show_path` | 1 | 1 |
| `browser_refresh` in `browser_show_path` | 2 | 2 |
| `sch_path` in `browser_show_path` | 0 | 0 |
| `return ` in `browser_msg` | 9 | **10** |
| `unhidden` in `browser_say` | 0 | **2** |

---

## 6. The checks — `BK32`-`BK42`, eleven ids, thirteen calls

**Both arms** (`tests/headless/test_wave_sigbrowser_keys.tcl`):

* `BK32` the new rendering, PURE. **Measured red pre-state: `g:x1.x1.xm1`.**
* `BK33` all NINE shipped renderings byte-unchanged **+ the formatter's return
  count 9 → 10** as the moving leg.
* `BK34` the ONE-FORMATTER oracle, four legs. **The only witness to S3.**
* `BK35` `TP44`'s twin kept local, five legs (3 frozen + 2 that move).

**X only:** `BK36` (fixture) · `BK36` (R12 itself) · `BK37` (`.ph`, byte-exact) ·
`BK38` (R12's last sentence + item 13's reveal contract) · `BK39` (the dual
pair) · `BK40` (the bars control) · `BK41` (one refresh, then zero) · `BK42`
(improve-or-restore) · `BK42` (teardown).

### 6.1 THE RED RUN FOUND THREE HOLLOW CHECKS AND THEY WERE REWRITTEN

First red run under X: **8 red, 40 green** — but `BK39`, `BK40` and `BK42`
**passed before a line of item 18 existed**. All three asserted only *shipped*
behaviour ("the box did not move", "the retry restored everything"), which is
exactly what NO CODE produces — item 12's hollow shape, and the second time this
batch has caught it only on the red run.

Each was rewritten to carry its positive evidence **in the same tuple**:

| check | moving leg added |
|---|---|
| `BK39` | the SAME call, on `x1.x1.xm1`, that MUST tick — so the `0` is a decision, not inertia |
| `BK40` | clear the bar and ask for a real hidden node: it ticks after all |
| `BK42` | after the restore, the R12 probe must still see a hidden node *through the restored inventory* |

Second red run: **11 red, 37 green.** The only two greens are `BK36 (FIXTURE)`
and `BK42 (TEARDOWN)`, which are declared fixture/hygiene assertions, not item
claims — a fixture check that went red before the item would be a broken fixture.

### 6.2 Existing checks — restated, never deleted

* **`BW59`** (`_panes.tcl`) `{4 4 1 1}` → **`{5 5 1 1}`**, name widened to "the
  five enumerated sites", the fifth named in the check's own comment. Legs 3 and
  4 unmoved at 1/1. Proven live by **S6** under X (§7).
* Everything else the scout listed re-gripped and confirmed unmoved: `BD06` (2),
  `TP44` (1/0), `BX09` (0/0), `BX13`, `BX14`, `BW15` (`{0 1}`), the twelve `.ph`
  byte-identity pins, `GH0`/`GH2`/`GH4`/`GH8`/`GH9`, `GS0`-`GS3`, `BT08`/`BT09`,
  `BS01`/`BS02`, `BP07`, `BP02`, `BP10`/`BP13`/`BP41`-`BP45`, `MG9`, `BW24`,
  `BW25`, `BW60`/`BW61`/`BW63`/`BW67`.
* The seven shipped checks that drive `browser_show_path` into a MISS
  (`BX34`/`BX35`/`BX37`/`BX42`/`BX45`/`BX46`/`BX52`) — **green, and by design,
  not luck**: their fixtures are all `net`-classed, so the devint-1 model is
  byte-identical to the devint-0 one, the pure probe answers "no", and the
  shipped path runs untouched. Confirmed by `_i12` **126/0** under X.

---

## 7. Sabotages — seven injected, seven fired, all reverted byte-exact

Driver: `flock` lock file, EXIT/INT/TERM trap restoring from a **byte-exact
backup** (the item was uncommitted — `git checkout --` would have deleted it),
asserted anchor pre-count, proof the mutation reached disk (`cmp`), `diff` on
every restore, and a filter that counts **NORESULT/TIMEOUT as reds** and compares
the **CHECK COUNT** as well as the fail count. Every run: 25 / 15 / 108 / 40
headless and 48 X — **no count moved anywhere in the sweep**, so nothing was
vacuous through an early abort.

| # | sabotage | RED | positive control (stayed GREEN) |
|---|---|---|---|
| **S1** | tick on ANY miss (`$pmatched == …` → `1`) | `BK39` `BK40` `BK42` | **`BK36` `BK37` `BK38` `BK41`** — the real R12 case still works. The dual pair, not a smoke test. |
| **S1b** | probe forced yes **+ a confirm guard that unticks** | `BK39` — refresh count **1 → 3**, measured | `BK40` green (the guard put the box back) — which is precisely why the guard is REFUSED: only the refresh count can see it |
| **S2** | untick after revealing | `BK36` `BK38` `BK39` `BK40` `BK41` `BK42` | **`BK37`** — the sentence is right and the state is wrong. Exactly the pair R12's last sentence needs. |
| **S3** | compose the sentence inline (arm removed from `browser_msg`, hand-written `browser_status`) | `BK32` `BK33` `BK34` (both arms) | **`BK37` green — `.ph` is byte-identical.** Only the pure formatter and the source oracle can see the drift. This is why `BK34`'s leg 2 is not optional. |
| **S4** | refresh twice | `BK41` (X), `BK35` leg 2 (2 → **3**, both arms) | everything else green; nothing visible changes |
| **S5** | decode the path in the new arm | **`TP44` (`_2pane`) AND `BK35`** — two files, one cause | `_i12` 40, `_panes` X **81/0** — `BW59` unmoved, the negative control for S6 |
| **S6** | probe hardcodes the source-currents scope | `BK35` leg 5, **and `BW59` under X** | **ZERO behavioural reds — and that is a MEASURED FACT, not a coverage hole:** 0 of the 84 hidden nodes are revealed by the device box only when source currents are on. Two source oracles catch it; no check was invented for an unreachable state. |

⚠ **A GAP THAT WAS FOUND AND CLOSED.** `BW59` lives in `_panes.tcl`'s **X-only**
block (81 checks under X, 15 headless), so the main sweep — which ran `panes`
headless — never exercised it. S6 and S5 were re-run with `panes` **under X**:
S6 reds `BW59`, S5 does not. Without that second pass, S6 would have been
reported as a one-red sabotage and the restated oracle would never have been
proven live.

---

## 8. Divergences from the spec and the PLAN — recorded, not overturned

1. **§8.2 says "PREFIX the status message"**; the shipped sentence **replaces**
   it. A prefix would render *"showing device internals to reach x1.x1.xm1 -
   showing x1.x1.xm1"* — the sentence already names the node. Adopted the PLAN's
   complete-sentence literal. **One-word spec correction handed to item 19.**
2. **§7.4 says the auto-tick "IS logged. One keystroke, one log line."**
   MEASURED: the R11(a) checkbox path contains **no `log_action`** —
   `wviewer::log_action` has 15 call sites and the checkbutton at `:7180-7186` is
   not one of them. `browser_toggle`, which §7.4 names, is the **sidebar
   show/hide**, a different control. Routing through the widget's own `invoke`
   satisfies the ruling's actual content (the same path a user's click takes,
   logged if and when that path is); inventing a bespoke `log_action` here would
   be new scope on a surface item 18 does not own. **Recorded, not invented.**
   Handed to item 19.
3. **`BK40`'s premise.** The PLAN calls it "a node hidden by the SEARCH BAR".
   Since two-pane item 10 the tree's node set is bar-**unfiltered** (§7.1), so a
   bar cannot hide a NODE at all — that state is unreachable. What `BK40` pins
   instead is that the bars-active **hedge** still fires and still does not tick.
4. **`.ph` NEEDS NO MOVE.** The scout brief asked for this to be measured before
   `BK37` asserted a sentence there, and offered a DEFER. Measured: the shipped
   `browser_msg` sentence has always landed on `.ph` (`browser_status` writes
   `"Signal Browser\n$msg"`; `browser_say` calls it on every branch), and
   `browser_sea_refresh` writes `$f.pw.sea.st`, never `.ph`. So `BK37` asserts it
   **byte-exact** and the twelve `.ph` pins are untouched. **No defer needed.**
   §7.2's three-state caption still owns that widget's future.
5. **Item 13's ruling honoured.** The reveal goes through `browser_reveal`, which
   opens the ancestor chain and leaves the target closed; `BK38`'s last three
   legs assert exactly that. Not re-litigated.

---

## 9. Declared limits

1. **FULL RESOLUTION ONLY.** A path whose devint-1 model resolves *deeper* but
   still not fully (e.g. `x1.x3.nosuch`: 2 of 3 with the box on, 1 of 3 with it
   off) leaves the box **unticked** and reports the shipped `partial` at the
   shallower landing. The alternative — keep the tick on any improvement — is one
   comparison away and nothing downstream moves. Chosen this way because
   `unhidden`'s sentence says *"to reach `<node>`"*, which a partial makes a lie,
   and because it keeps the absence control unambiguous.
2. **THE PROBE IS CURRENT-DB ONLY.** It builds a single-group model from
   `browsersigs($token)`, so under All-DBs a hidden node in a **foreign**
   inventory answers "no" and the shipped path runs. Conservative by
   construction: the probe can only under-report, never tick wrongly.
3. **The Search/Filter bars are still NAMED, never CLEARED** on a miss — the
   shipped limit, inherited unchanged.
4. **Spec §9's live note is real and correct.** A ticked box makes
   `browser_state` non-default, so `snapshot` begins emitting a `browser` key it
   did not emit before. `MG9` pins the *snapshot's* key list and `browser` is a
   value inside it, so it is unaffected — re-measured, `test_wave_modes` **212
   headless / 488 X, unmoved**. The mitigation is fixture hygiene, not code:
   item 18's X block owns `wvbk18` end to end and tears it down, and `BK42
   (TEARDOWN)` asserts that as a value.

---

## 10. The two arms

### Headless — **1662 / 0** over the same 15 files (baseline 1658)

Only `test_wave_sigbrowser_keys` moved: **21 → 25** (`BK32`-`BK35`). Every other
per-file figure byte-identical to the recorded baseline: sigsearch 146, sea 6,
sigbrowser 135, 2pane 108, panes 15, i11 50, i12 40, i1315 88, i14 56, grid 231,
modes 212, viewer 57, markers 437, tabs 56.

### X — **2243** over the same 12 suites (baseline 2230)

Only `test_wave_sigbrowser_keys` moved: **35 → 48** (+13 = 4 both-arms checks
+ 9 X-only calls). panes 81, sigbrowser 353, sea 79, i11 74, **i12 126**, i1315
190, i14 107, 2pane 108, sigsearch 233, grid 356, modes 488 — all unmoved.

### The three out-of-baseline suites, run by hand through `xarm.sh one`

`test_bindings_file` **13**, `test_keybindings_help` **17**,
`test_key_graph_context` **70** — all ALL PASS, byte-stable. This item touches no
C and no csv.

### ⚠ BASELINE DRIFT OBSERVED AND ATTRIBUTED — `BP77` is a `:0` FLAKE

The pre-item baseline run of `test_wave_sigbrowser_i1315` on the real `:0` failed
**`BP77`** twice (189 passed / 1 failed, check count 190 — correct) while the
same file under Xvfb answered **190 / 0**. `BP77`'s fourth leg is a **geometry
echo** — "opening the sidebar lands on the restored 0.44 split" — which is
exactly the class the baseline note says Xvfb cannot measure and a WM can perturb.
**It then passed on `:0` in the post-item run (190 / 0).** So it is a
window-manager timing flake on `:0`, not a regression and not a deterministic
display difference. **It is on the pristine tree, before item 18 existed.**
Recorded here rather than silently adopted; a future `:0` run that sees it should
re-run before calling it a fail.

### Xwayland deaths

Three whole-suite `NORESULT`s across the session (`i1315`+`sigsearch` in the
pre-item run, `i12` in the post-item run), one with an explicit
`X connection to :0 broken`. All re-run by hand and all ALL PASS at their
baseline counts. Not measurements, not regressions — the known WSLg flake, now
reachable again after the handback.

---

## 11. Files touched

```
src/wave_viewer.tcl                          (browser_msg, browser_say, browser_show_path)
tests/headless/test_wave_sigbrowser_keys.tcl (band header + BK32-BK42)
tests/headless/test_wave_sigbrowser_panes.tcl(BW59 restated {4 4 1 1} -> {5 5 1 1})
doc/claude/signal_browser_2pane_batch/LEDGER.md
doc/claude/signal_browser_2pane_batch/18_receipt.md
```

## 12. Eyeball

**NONE OWED.** Every claim is a Tcl value, a widget `cget`, a `-open` flag, a
refresh count or a source grep — there is no pixel deliverable. The one thing a
human might still want to *feel* is the gesture: with device internals **off**,
select a MOSFET instance on the schematic and press **Ctrl+Alt+V**. The tree must
grow, land on that instance, and the status line must read *"showing device
internals to reach `<path>`"* — with the checkbox now visibly ticked. That is
`BK36`+`BK37`+`BK38` restated in fingers, not a gap in coverage.

## 13. For item 19

* §8.2's "prefix" → "sentence" (one word).
* §7.4's "is logged" → the checkbox path has no `log_action` (§8.2 above).
* §3.3's 44/128 → **45/129** (it counts instances, missing R2's design ROW) —
  item 12 owed this one too and it is still open.
* `browser_msg` now has **ten** kinds, not the five §7.2 knows about.
* NEXT FREE in `test_wave_sigbrowser_keys.tcl`: **`BK43`**. `BK19` stays reserved.
