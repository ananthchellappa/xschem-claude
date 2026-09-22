# Recon — Stage 3, F1, F2 against today's tree

**Crew:** RECON. **Tree:** `fluid-editing` @ `6a0d1126`. **Date:** 2026-09-21.
**Binary:** `make -C src` → `Nothing to be done for 'all'`, so `src/xschem`
(1 688 152 bytes, 22:50:07) *is* this tree. No `.c`/`.h` is newer than it.
**Scratch:** `/var/tmp/xsr_ux` (21 chars), peak **124 KiB** / 49 893 bytes apparent.
Deleted at the end. **Real HOME untouched** — every probe ran with
`HOME=/var/tmp/xsr_ux/r1/h`, and `~/.xschem` still carries its 09-17 mtime while the
scratch home absorbed the `.xschem/geometry` write. **`:99` untouched** — probes ran on
private `xvfb-run` displays `:214`–`:219`; `@/tmp/.X11-unix/X99` is still the only
abstract socket besides `X0`, and no Xvfb of mine survives. Repo working tree unchanged
(the two `??` paths in `git status` predate this session). **No T1 run**, per brief.

Every number below was read off a probe or off the source at `6a0d1126`. Code is cited by
**proc name**; where a line number appears it is qualified with the revision, because the
plan's own coordinates have all rotted (see §0).

---

## 0. How stale the plan is, measured

`437a3add` → `6a0d1126` is **299 commits**, **76** of which touch `src/ase.tcl` or
`src/ase_window.tcl`. `src/ase_window.tcl` is now **12 000+** lines against the plan's
7 491. Every `:NNNN` in `PLAN.md` is wrong; the three I spot-checked moved by +1 300 to
+5 000 lines (`log_open` `:7011` → `:11999`; `arg_summary` `:1071` → `:1629`;
`refresh_output_values` `:1600` → `:2205`). The plan's **proc names all still resolve**,
which is the lesson CLAUDE.md already records.

**And `README.md` line 6 is false.** It says *"Nothing here has been implemented. `src/`
is untouched."* Measured `git diff --stat 437a3add 2f1fad58 -- src/`:

```
 src/ase_window.tcl   | 756 ++++++++++++++++++++++++++++++++++++-----
 src/cadence_style_rc |  25 ++
 src/xschem.tcl       |  17 ++
 3 files changed, 742 insertions(+), 56 deletions(-)
```

---

## 1. What each stage asks for, and whether it is still meaningful

| stage | in plain language | verdict today |
|---|---|---|
| **3 (i)** ellipsis + tooltip on clipped cells | a cell too narrow for its text ends in `…` and hovering shows the whole string | **STILL MISSING** — and one half of it **now needs a ruling** (§5) |
| **3 (ii)** horizontal scrollbar on the log window | the ngspice command line stops falling off the right edge | **STILL MISSING**, and cheap |
| **3 (iii)** horizontal scrollbar per pane | a pane too narrow for its columns can be scrolled | **ALREADY DONE** by issue 1398 — but **unpinned by any suite** |
| **F1** one producer for the pane and the deck | the Arguments column shows the literal deck line | **ALREADY DONE**, and superseded by a stronger design |
| **F2** the Value column reads the answers off disk | open yesterday's bench and the numbers are there | **STILL MISSING**, and it is worse than the plan said |

### Stage 3 (i) — the clip. STILL MISSING, and measured.

Probe `p_s3.tcl`, ASE-L at the shipped 798×520 with a Monte Carlo variable
`agauss(1.8, 'ABSVAR*1.8', 3)`:

```
bindings on vars pane = <<TreeviewSelect>> <Button-1> <Button-3> <Double-Button-1>
bindings on ana  pane = <<TreeviewSelect>> <Button-1> <Button-3> <Double-Button-1>
bindings on outs pane = <<TreeviewSelect>> <Button-1> <Button-3> <Double-Button-1>
vars value column -width px = 118        ink of the string px = 203
CLIPPED = 1                              cell text carries an ellipsis = 0
status.state has a Motion/Enter binding = 0
simdlg tv bindings = (none)              simdlg Program column -width = 324
a real ngspice path ink in AseEntryFont = 371   -> that path CLIPS = 1
```

Zero `<Motion>`/`<Enter>` bindings on any of the three panes, on the status bar's last
segment, or on the Simulators treeview. The audit's headline finding is untouched.

**⚠ The pane horizontal scrollbar cannot reach this clip, and that is now measured, not
argued.** At 798 px the vars viewport is **246 px** and the sum of its column widths is
**244 px** — so `pane_hscroll` correctly leaves the bar *unmapped* while the cell's ink
(203 px) overflows its own 118 px column. At the user's real setting
(`ase_font_size 12`, §4) the bar *is* mapped, sum **297** against viewport **253** — and
the cell still clips, **244 px of ink in a 143 px column**. Scrolling the pane slides the
viewport across the columns; it never widens one. **The two defects are orthogonal and
the shipped hscroll closes neither.** Today the only way to read that value is to drag
the column divider or open the row editor.

### Stage 3 (ii) — the log window. STILL MISSING.

`ase::ui::log_open` (`src/ase_window.tcl:11999` @ `6a0d1126`) is still
`text $lw.t -height 24 -width 84 -state disabled -wrap none` with a vertical bar only:

```
log children = .ase4.logwin.sb .ase4.logwin.t
log text -wrap = none      -width chars = 84      -xscrollcommand = {}
log has a horizontal bar = 0
```

**⚠ One clause of the plan's case is refuted.** It says the command line is *"off the
right edge of a window with no wrap, no hscroll and no way to select-and-scroll."* There
**is** a way: `Text`'s class bindings carry `<Shift-Button-4/5>` and `<Shift-MouseWheel>`,
and they work on the disabled widget. Measured — `xview` went `0.0 0.613` →
`0.0456 0.659` on one `<Shift-Button-5>`. So the honest statement is **undiscoverable,
not unreachable**: **61 % of that line is visible** at the default width, there is no bar,
no affordance and nothing that says the widget scrolls sideways. Write the commit message
that way; the plan's phrasing would be a false claim in a commit.

The line itself measured **137 characters** for a real ngspice invocation (the plan says
144 — close enough, and the point is unchanged against 84 columns).

**⚠ The plan's "derive `-width` … buys ~115 columns in the same pixels" is spent.** That
arithmetic was 84 × 11 px (pre-1398 Nimbus Mono PS) ÷ 8 px. Today `AseMonoFont` is
`monospace` at the ambient size and the advance is **8 px at size 10** / **10 px at
size 12**, so 84 columns already costs **676 px** (size 10) or **844 px** (size 12), and
the old 924 px budget would buy **115** or **92** columns respectively. Re-deriving the
width now makes the log window *wider again* — which is exactly the direction `2f1fad58`
had to correct. **Recommend: add the bar, leave `-width 84` alone.**

### Stage 3 (iii) — per-pane hscroll. ALREADY DONE, and unpinned.

`ase::ui::build_pane` creates `$pf.hsb` and wires `ase::ui::pane_hscroll` as the
`-xscrollcommand`; `grid remove` hides it and it acts only on a change of state. It
landed with issue 1398 (DECISIONS T-6). Auto-hide verified:

```
vars/ana/outs hsb mapped at 798px = 0 0 0
vars/ana/outs hsb mapped at 560px = 1 0 1      (ana's content fits — correct)
```

**No suite anywhere mentions `hsb`, `pane_hscroll` or `retune_columns` for ASE-L.**
`/usr/bin/grep -rn 'hsb\|pane_hscroll\|retune_columns' tests/headless/*.tcl` returns only
Calculator and signal-browser hits. Three shipped procs from item 2 are unpinned.

### F1 — one producer. ALREADY DONE, and superseded.

`ase::analysis_line` exists (`src/ase.tcl:10675` @ `6a0d1126`) with the docstring
*"THE ONE SPELLER. render_deck emits this; ase::ui::arg_summary RENDERS it."*
`render_deck` emits `set aline [ase::analysis_line …]` and `ase::ui::arg_summary` calls
the same proc. The two golden strings the plan predicted would move **have already
moved, to the exact string the plan predicted**:

* `tests/headless/test_ase_window.tcl:525` — `P4 arg_summary dc row` → `{dc V2 0 1.8 0.01}`
* `tests/headless/test_ase_dialogs.tcl:1000` — `G2 Arguments summary is the line the deck
  will carry` → `{dc V2 0 1.8 0.01}`

It was delivered by the **`ase_analyses_batch`** (issues 1417–1474), and it went past the
plan: `analysis_line` resolves through `ase::analysis_cards` and a per-backend
**analysis registry** rather than the plan's optional `analysis_line` backend hook, and
`arg_summary` now has *three* arms, not two — the deck line, an **honest refusal
sentence** for an enabled row that cannot render (issue 1420), and the `key=value` dump
only for a backend with no registry at all. F4's "refuse rather than store" also landed
(`ase::analysis_emit_check`). **Nothing to build. Close it on the ledger.**

### F2 — the Value column. STILL MISSING, and one half is worse than the plan said.

Probe `p_f2.tcl`, headless, a raw on disk holding `v(vbg) = 1.177085`:

```
session registered                       = 1
results attr after registration          = {}
raw exists on disk                       = 1
has_results                              = 1
output_result_key                        = VBG
VALUE CELL populate would render         = {}          <-- blank
result_probe_raw off the SAME state      = {VBG 1.177085e+00}
writers of the `results` session attr    = 1
   -> ase::session_setattr $key results [ase::last_result]
```

So: the number is on disk, `ase::has_results` already answers **1**, a shipped proc
already returns it — and the column renders blank. Exactly one writer, in
`ase::ui::run_finished`'s `ec == 0` arm (`src/ase_window.tcl:12253` @ `6a0d1126`).

**⚠ And the Load State half is worse than "shows nothing" — it shows the WRONG number.**
Same probe, continued:

```
results attr AFTER load_state_commit            = {VBG 9.999999e+00}
VALUE CELL after loading a DIFFERENT state      = {9.999999e+00}
```

`ase::ui::load_state_commit` calls `ase::session_update`, which replaces the `state`
sub-key only; `results` is a sibling sub-key and survives untouched. **A corner sweep,
where states share output names by construction, reads the previous corner's answer under
the new corner's name, with nothing on screen to say so.** The plan asserted this from
reading; it is now measured. This is the same silent-wrong-data class as issue 0838, and
it is the strongest single reason to do F2.

**Two design consequences the plan did not foresee**, both mine to settle, both recorded
so the implementer does not rediscover them:

1. **The registered `result_probe` hook is now a dispatcher that talks to the user.**
   Measured: calling it echoes one sentence — *"ase: results — a row whose expression
   names exactly one vector is read from the results file … **This run**: 1 from the
   file, 0 from the log."* On a window *open* that sentence is a lie (there was no run)
   and it would fire on every open. F2 must partition and call `result_probe_raw` /
   `result_probe_log` directly, or give the dispatcher a quiet arm. **Do not simply call
   the hook.**
2. **`result_probe_raw` needs no log text at all** (`proc result_probe_raw {state {mode
   fold}}`) — it reads `raw_file $state` itself. Only `result_probe_log` needs the log,
   and `log_file` resolves it (`…/bg_ase.log`). So the on-open fill is cheap for
   single-vector rows and only touches the log for expression rows.

---

## 2. Files and procs each change would touch today

**Stage 3 (i) — tooltip.** `src/ase_window.tcl`:
`ase::ui::build_pane` (add `<Motion>`/`<Leave>` on `$pf.tv`, the three panes),
a new per-cell handler modelled on the shipped `ase::ui::rsel_tip` /
`rsel_tip_text` / `rsel_tip_show` / `rsel_tip_cancel`, the clipping gate borrowed from
`balloon_clipped` (`src/xschem.tcl`), plus `ase::ui::simulators_dialog` (the `path`
column) and the `$top.status.state` label built in `ase::ui::build`.
`ase::ui::colw` is the existing width oracle to measure against.

**Stage 3 (i) — ellipsis (ruling-gated, §5).** `ase::ui::populate`,
`ase::ui::refresh_output_values`, `ase::ui::build_pane` (a `-displaycolumns` split),
and `ase::ui::output_display_name`.

**Stage 3 (ii) — log hscroll.** `ase::ui::log_open` only. Keep `$lw.t` and `$lw.sb`
(three suites address them by path — `test_ase_window.tcl`, `test_ase_interact.tcl`) and
add `$lw.hsb`; pack → grid, since `grid remove` is what lets the bar auto-hide the way
`pane_hscroll` already does.

**F2.** `src/ase_window.tcl`: a new proc beside `ase::ui::refresh_output_values`;
call sites in `ase::ui::open` (after `populate`), `ase::ui::rsel_commit` (after
`results::select` succeeds) and `ase::ui::load_state_commit` (**clear first**).
Reads `ase::has_results` / `ase::results_stale` / `ase::last_rawfile` (`src/ase.tcl`) and
the backend's `raw_file` / `log_file` / the two `result_probe_*` readers
(`src/ase.tcl`, namespace `ase::backend::ngspice`). **No change to `ase.tcl` is needed.**

---

## 3. Tests that exist now, and what would prove each change

**What exists.** `tests/headless/test_ase_*.tcl` is **44 suites**. Relevant coverage:

| area | suite | rows |
|---|---|---|
| the three panes' shape and cell values | `test_ase_window.tcl` | `W1p` (`:1771`–`:1805` @ `6a0d1126`) — columns, seeded rows, `W1p id output row Value blank pre-run` at `:1798` |
| `output_display_name` truncation | `test_ase_window.tcl` | `P2`, `:499`–`:506` (three checks) |
| `arg_summary` | `test_ase_window.tcl` `P4` `:525`; `test_ase_dialogs.tcl` `G2` `:1000` | already carry the deck line |
| log window | `test_ase_window.tcl` `W6` `:2963`, `W6c` `:3258`–`:3278`; `test_ase_interact.tcl` `WF` `:416` | existence, text content, Ctrl-W — **no widget-shape or geometry assertion** |
| Simulators dialog | `test_ase_simdlg_0937.tcl`, `test_ase_simwin_variant_1471.tcl` | 18 references |
| the raw/log readers | `test_ase_core.tcl` §RD (`r3_raw`/`r3_state`/`r3_probe` helpers, `:8497`–`:8544`), `test_ase_simcaps_0948.tcl` §RV | the data layer F2 sits on is already well pinned |
| the per-pane hscroll, `retune_columns` | **nothing** | ⚠ gap |

**What would prove each change.**

*Stage 3 (i) tooltip* — add to `test_ase_window.tcl` beside `W1p`, headless-safe because
the text resolution is scriptable even though the balloon pixels are not (the declared
limit `rsel_tip` already documents):
`<Motion>` and `<Leave>` are bound on all three panes; the handler returns the **full**
cell string for a clipped cell and **{}** for one that fits (the anti-vacuity row — a
tooltip on every cell is the failure mode); the gate is computed from `font measure`
against `$tv column <c> -width` so it follows `ase_font_size`; the same for
`$top.simdlg.tv` and `$top.status.state`. Sabotage that must redden: make the gate
`return 1` unconditionally → the "cell that fits gets no tip" row dies.

*Stage 3 (ii) log hscroll* — in `test_ase_window.tcl` near `W6c`:
`$lw.hsb` exists, `-orient horizontal`, `-command` is `$lw.t xview`; `$lw.t
-xscrollcommand` is wired; `.t` and `.sb` keep their paths (the regression gate for the
pack→grid move); the bar is **unmapped** on a short line and **mapped** after appending
a 137-char one. Sabotage: drop the `-xscrollcommand` → the mapped/unmapped pair dies.

*Stage 3 (iii)* — retro-pin the shipped behaviour, since nothing does:
`$pf.hsb` exists for all three panes, `pane_hscroll` maps it only when
`first > 0 || last < 1`, and the `need != shown` guard means one mapping per change
(the cascade guard T-6 calls load-bearing). Cheap, and it converts three unpinned
procs into covered ones.

*F2* — two homes. Headless, in `test_ase_core.tcl` §RD using its own `r3_raw`/`r3_state`
helpers: the new proc returns the raw's number for a session whose `results` attr is
empty; it returns **{}** when `ase::has_results` is 0 (a raw older than its deck —
`results_stale` already has fixtures); and it **emits no `ase::echo`** (the "This run"
sentence must not appear on an open). GUI, in `test_ase_window.tcl`: open a session whose
rundir holds a raw → the Value cell is filled; `load_state_commit` with a different state
→ the cell is **blank, not the previous number** (this row *is* the defect, and it
reddens on today's code — I measured it); and **`W1p id output row Value blank pre-run`
must stay green**, which it will because that fixture's rundir holds no raw.
Sabotage: drop the clear in `load_state_commit` → the stale-number row dies.

⚠ **One risk on `W1p`.** It reads `$otv set $idit value` and runs *before* `W6` starts a
real ngspice, so the scratch rundir is empty at that point. If a future leg ever leaves a
raw where `W1`'s fixture can see it, F2 turns `W1p` red for a good reason. Name the row
in the commit message.

---

## 4. Half-landed work — what is actually in the tree for items 1 and 2

**Item 1 (issue 1396) is fully landed and the ledger is right.** `5fb8f465`, 7 files,
+712/−20. All four procs live: `ase::ui::save_as_needs_confirm`,
`ase::ui::save_as_overwrites_other`, `ase::ui::confirm_safe_default`,
`ase::ui::confirm_owned_by`.

**Item 2 (issue 1398) landed in TWO commits and the ledger names neither.**

| commit | what | in the ledger? |
|---|---|---|
| `4ddc4900` `fix(1398): ASE-L rendered in a typeface nobody chose` | `src/ase_window.tcl` **+573**, `src/xschem.tcl` +17, `test_ase_window.tcl` **+646**, issues 1398 + 1399, 13 shots, and the item-2 ledger block itself | the block exists, **no hash** |
| `2f1fad58` `fix(1398): ASE-L came back three points smaller than it went in` | `src/cadence_style_rc` **+25** only | **no row at all** |

`2f1fad58` is live: `src/cadence_style_rc:744` is `set ::ase_font_size 12`, `set` not
`set_ne`, and all four PDK workareas source that file. **This matters to Stage 3**: my
first probes ran without it and saw `ase_font_size 0`; the user's window runs at **12**,
where the mono advance is 10 px and the clip is 244 px of ink in a 143 px column.
**Measure Stage 3 at 12, not at the bare default.**

So the batch's paper trail has three specific holes, all confirmable in one line each:

1. `README.md:6` — *"Nothing here has been implemented. `src/` is untouched."* **False.**
2. `LEDGER.md` item 2 — no commit hash for `4ddc4900`.
3. `LEDGER.md` — no row for `2f1fad58` at all, which is why it reads as orphaned. It is
   not orphaned; it is item 2's follow-up, caused by item 2, and it is the commit that
   records the user's only recorded reaction to this batch's shipped work
   (*"noticeably smaller than before"*).

**Nothing else from this batch is in the tree.** Only two commits ever touched
`doc/claude/ase_l_ux_batch/` (`66992a1d` the audit, `4ddc4900` item 2), and `git log
--grep` finds no other 139x commit.

**Owed ledger** (read-only): rule debts **1396, 1397, 1398, 1399** and look debts
`ase_l_1396_overwrite_confirm`, `ASE-L_Save_State_overwrite_confirm_popup` are all
present. Rule 1398's text explicitly says *"EVERY GLYPH IN ASE-L CHANGED and you have not
seen it on your own screen"* — so item 2's eyeball debt is filed as a **rule**, not as a
`look`. If the driver wants it in the user's eyes-queue as a look debt too, that is a
one-line `owed.sh add look`; I did not write to the ledger.

**Incidental, for whoever mints next.** This clone's `NUMBERING.md` says **next free is
1498**; 1498 and 1499 are clean (band check silent, no file in either checkout, the only
greps are the band table and its example line). After 1499 the next is **1600** —
1500–1599 is op-wcard's. ⚠ And `~/dev/xschem-op-wcard/doc/claude/issues/NUMBERING.md`
still reads *"The next free number is 1482"* while this clone holds **1483–1497**: 1482
itself is free, so op-wcard's *next* mint is fine and its one after that collides. Issue
1400's class, live. Not touched, not fixed, reported.

---

## 5. The one ruling these three stages turn out to need

Stage 3 says *"Rulings: none. The `…` spelling is already shipped elsewhere in this
file."* **That reason does not hold** — the shipped `…` is in menu labels (`Add…`,
`Save All…`), where it is the Tk convention for *"opens a dialog"*, not a truncation
marker. And there is a harder problem the plan and the audit both got wrong.

**⚠ Stage 3's stated precondition is not implementable.** The plan requires *"The full
string stays in the item's `-values`; only the DISPLAY is truncated"*, and FINDINGS.md
suggests *"use a display column or a tag"*. Measured on a real `ttk::treeview` with
`-columns {name value _full} -displaycolumns {name value}`:

```
set value (the DISPLAYED, truncated one) = {agauss(1.8, 'ABSV…}
set _full (the hidden one)               = {agauss(1.8, 'ABSVAR*1.8', 3)}
tag configure options                    = -anchor -foreground -text
```

A treeview renders exactly what is in `-values`; a hidden column stores the full string
but `$tv set $it value` still returns the **truncated** one, and tags carry no per-cell
text. **So a visible ellipsis necessarily changes what every `$tv set … <col>` assertion
reads back.** Stage 3's "Suites: none" is false for the ellipsis half. (The **tooltip**
half is genuinely additive and moves nothing — that part of the plan is correct.)

It is also not a clean slate: `ase::ui::output_display_name` **already** truncates, into
`-values`, at a **character count** with ASCII dots — measured, the Outputs Name cell
reads `v(x1.x2.vbg_internal_...` for an expression of
`v(x1.x2.vbg_internal_reference_node)` — and it is pinned by `P2`.

### ⚖ R-U1 — how a cell that is too narrow for its text should end

*Plain English, for the user:* when a value does not fit its column, ASE-L cuts it off
mid-letter today. Should it instead end in a `…` so you can see it has been cut — and if
so, should the Outputs **Name** column, which today cuts at a fixed 24 characters and
ends in three dots `...`, change to match?

| option | what the user sees | cost |
|---|---|---|
| **A — tooltip only** | the cut stays mid-letter; hovering a clipped cell shows the whole string | no suite moves; nothing tells you a cell is cut until you hover |
| **B — `…` everywhere except Name** | cut cells end in `…`; the Outputs Name column keeps its `...` at 24 chars | two truncation idioms side by side in one pane; `W1p` and any `$tv set … value` row moves to a hidden column |
| **C — `…` everywhere, Name included** | one idiom; Name cuts on pixels rather than on a character count, so it changes where it cuts | as B, plus the three `P2` rows and the string the user currently reads in Name |

**My recommendation, not an answer: C**, with a note. It is the shape that removes the
inconsistency rather than trading one cost for another, and the pixel rule is strictly
better than a 24-character rule that clips at a different point in every font size. **And
it does not have to be one commit**: option A is a strict subset, needs no ruling, moves
no suite, and already delivers Stage 3's stated outcome — *"the Monte Carlo variable
becomes readable without opening a dialog"*. **So ship A now and let R-U1 gate only the
glyph.** That keeps the ruling off the critical path entirely.

**Nothing else in Stage 3, F1 or F2 needs a ruling.** Specifically:

* The **log horizontal scrollbar** is a control appearing where none was — additive, and
  the same auto-hide idiom the panes already ship. Mine.
* **F2's "only if you want a stale-result marker"** has **lapsed**: `ase::has_results` /
  `ase::results_stale` (issue 0838) already refuse a raw older than its deck, so a
  displayed number is current by construction and there is nothing to mark. Gate on the
  predicate and no marker is needed.
* F2's echo suppression, the partition call, and where the new proc lives are internal.

---

## 6. Go / no-go

| stage | verdict | why |
|---|---|---|
| **Stage 3 (i) tooltip** | **GO** | still missing, measured clipped at both font sizes, mechanism shipped in-file, additive, no ruling, no suite moves |
| **Stage 3 (i) ellipsis** | **HOLD** | ⚖ **R-U1**. Not blocking: the tooltip half ships without it |
| **Stage 3 (ii) log hscroll** | **GO** | still missing; ~15 lines in one proc; correct the "no way to scroll" claim to "undiscoverable", and **do not** re-derive `-width` |
| **Stage 3 (iii) pane hscroll** | **NO-GO — already done** (1398). *Optional:* retro-pin it; three shipped procs have zero coverage |
| **F1** | **NO-GO — already done** and superseded by `ase_analyses_batch`. Close on the ledger |
| **F2** | **GO, and it is the highest-value item of the three.** One writer of `results`; the number is on disk; `has_results` already says 1; and **Load State shows the previous state's number under the new state's output name** — measured, silent wrong data |

**Suggested order:** F2 first (it is a correctness defect and the only one that can hand a
designer a wrong number), then Stage 3 (ii) (smallest), then Stage 3 (i) A-half. R-U1 goes
to the user in its own short conversation and gates nothing.

**Also owed to the ledger, independent of any of the above:** fix `README.md:6`, add
`4ddc4900` to item 2's block, and give `2f1fad58` a row of its own.
