# Item 04 — `wviewer::searchbar`, the reusable ViVA Search bar — receipt

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start `89565388`.
Date 2026-08-04. Implementer receipt. The PLAN's older name for this file was
`receipts/04_searchbar.md`; the pipeline's path is `04_receipt.md` (driver note (a)),
and that is what this is.

**VERDICT: `[E]`, not `[x]`** (driver note (b)). This is a PIXEL item: the deliverable
is visible UI, and **no claim of visual correctness is made here.** §9 is the eyeball
note for the human review queue.

Two things a reader should not miss: **§8** (a check was written, measured
non-deterministic, and DELETED — the claim narrowed to match) and **§11** (the GUI gate
logged `revive FAILED -- suite continues UNGATED` during audit run 1).

---

## 1. What shipped

Two edit sites, both in `src/wave_viewer.tcl` (+241 / -0). No C (settled decision 8),
no new test file (settled decision 9), **no consumer**.

**(a) the namespace block** (`namespace eval wviewer {`, `:300`) — two arrays beside
the existing per-widget ones:

```tcl
  variable sbcfg;   array set sbcfg  {}   ;# $w -> {command <cb> showbutton <0|1>}
  variable sbcase;  array set sbcase {}   ;# $w -> the Match-case checkbutton var
```

Keyed by the **megawidget's own frame path**, not by session token: a searchbar is not
a per-window singleton (item 5 puts one in the Add Trace dialog, item 8 another in the
browser sidebar of the *same* viewer window).

**(b) a new section immediately before the `# --- Graph menu dialogs` banner**
(`:7408` at item start, `:7417` after the namespace insertion). Seven procs:

| proc | |
|---|---|
| `wviewer::sb_type_code {label}` | `All/Voltage/Current/Other` -> `all/v/i/other`. PURE |
| `wviewer::sb_syntax_code {label}` | `Shell/RegExp` -> `shell/regexp`. PURE |
| `wviewer::searchbar_build {parent args}` | -> the frame path |
| `wviewer::searchbar_get {w}` | -> `{pattern .. syntax .. case .. type ..}`, `{}` if not a live bar |
| `wviewer::searchbar_fire {w}` | THE handler every route converges on |
| `wviewer::searchbar_error {w msg}` | set/clear `$w.err` |
| `wviewer::searchbar_destroyed {w W}` + `wviewer::searchbar_forget {w}` | `<Destroy>` cleanup |

Widgets, in ViVA §3.2's order, children of the returned frame (default
`$parent.wvsearch`, `-name` overrides so two bars can share a parent):

| path | widget | key options |
|---|---|---|
| `$w` | `frame` — **NOT `ttk::frame`** | `apply_theme` (`ase_window.tcl:161`) has no `TFrame` arm |
| `$w.type` | `ttk::combobox -state readonly -width 8` | `-values {All Voltage Current Other}`, `set All` |
| `$w.pat` | `entry -width 20 -font AseEntryFont` | |
| `$w.syntax` | `ttk::combobox -state readonly -width 7` | `-values {Shell RegExp}`, `set Shell` |
| `$w.case` | `checkbutton -text {Match case}` | `-variable ::wviewer::sbcase($w)`, init 0 |
| `$w.search` | `button -text Search` | **not created at all** under `-showbutton 0` |
| `$w.err` | `label -text {} -anchor w -width 24` | the fixed `-width` is what makes the bar non-resizing |

Four routes — `<KeyRelease>` on the entry, `<<ComboboxSelected>>` on either dropdown,
the checkbutton's `-command`, the button's `-command` — all converge on
`searchbar_fire`, so there is **exactly one place** a consumer callback is invoked from
and exactly one place the error label is written.

**Zero consumers, verified not assumed:** `grep -rn 'searchbar_build' src/` returns only
the definition, its own error strings and its own comment. Items 1 and 2 shipped the
same way.

## 2. `searchbar_fire`'s body order, which is load-bearing

1. read the four values (`searchbar_get`, the one reader);
2. **validate through THE ONE matcher** — `wviewer::sig_match {} $pat -syntax $syn
   -case $case` on an EMPTY signal list, so the match loop never runs and only the
   `^(?:$pat)$` compile at `wave_viewer.tcl:1573-1574` happens. Nothing here
   re-implements matching (the `:1465` rule), which is why a message shown to a user is
   always byte-identical to the one the consumer's own `sig_match` call produces;
3. write the error label — the message on `{err ...}`, EMPTY otherwise. That empty-on-
   success write **is** decision 4's *"clears on the next valid keystroke"* clause;
4. invoke the consumer callback **ALWAYS**, invalid pattern included.

**⚠ IT MUST NOT THROW.** It rides a `<KeyRelease>` pump, and a Tcl error there pops
bgerror — modal under X, and it HANGS a headless run. Both the validation and the user
callback are `catch`-wrapped; a throwing consumer callback puts its own message in
`$w.err`, so it is visible and never silent. Same discipline as `readout_refresh`.

## 3. Tests

| | |
|---|---|
| test file | `tests/headless/test_wave_sigsearch.tcl` (settled decision 9 — appended, existing style, inside the existing outer `catch ... bigerr`, reusing `check`) |
| checks added | **28** — SM28, BAR12 (both PURE, outside the X guard), BAR01-BAR11, BAR13-BAR24, BAR26, plus BAR18b and BAR22b. **There is no BAR25** — see §8 |
| checks total | **88 -> 116** in the DISPLAY arm; **90** in the `--nogui` arm (88 + SM28 + BAR12) |
| runtime | `--nogui` arm **378 ms** whole file; DISPLAY arm ~3 s per run (8 runs in 25 s wall through `run_suites.sh -n 8`) |
| green | `run_suites.sh test_wave_sigsearch` -> `ALL PASS (116 checks)`; `--nogui` -> `ALL PASS (90 checks)` with the BAR group printing its skip banner; `run_suites.sh -n 3` after the BAR25 removal -> **3/3** |
| build | `cd src && make` -> *"Nothing to be done for 'all'"* (Tcl-only) |

**Driver note (d) honoured to the letter.** `gsl_frozen_ref`, the GSO block, `GSO_NAMES`,
`GSO_PATS`, `GSO_BLOBS` and the `GSPLAIN` fixture are **byte-untouched** — the diff to
the test file is the header block, the bgerror override, and a pure append after
`set ::graph_sort 0`. Item 3's P2 was deliberately **NOT** "taken in passing" (the
scout's risk list explains why: unanchoring that regsub now fails GSO01 by design).

**SM28** discharges item 1's surviving D8/U1 mutation gap. It carries item 1's name
rather than a BAR one because item 1's receipt §6 cross-references `SM28`; it is
appended at the bottom because decision 9 makes this file append-only. It is PURE, so
it runs in the `--nogui` arm too:

```tcl
check {SM28 regexp arm anchors an ALTERNATION as a whole} \
  [lindex [sig_match $SIGS {out|l1} -syntax regexp] 1] [list l1]
```

`^(?:out|l1)$` takes `l1` alone; drop the non-capturing group and `^out|l1$` binds `^`
to the first branch and `$` to the last, so it also takes `xl1`.

### Driver note (f) — the three defaults are pinned INDEPENDENTLY, and it is PROVEN

BAR04 reads **only** `$w.type get`; BAR05 **only** `$w.syntax get`; BAR06 **only**
`::wviewer::sbcase($w)`. Every other check that depends on a selector sets it
explicitly first (BAR11/BAR15 set RegExp/Voltage/case-on; BAR18/BAR20/BAR26 set all
three). BAR14 asserts arity + arg0 only; BAR13/BAR16/BAR17 assert routing, not values. A **"searchbar_get at defaults" check was deliberately NOT written** — it
would duplicate BAR04-06 and hand each of those three sabotages a second target (item
3's P2 lesson).

Measured, not argued: mutating **each** of the three defaults fails **exactly one**
check — see §4 rows NAMED, E1, E2.

## 4. Sabotage table — 12 injections, every one measured, every one reverted

`git checkout -- src/wave_viewer.tcl` would have destroyed the ITEM along with the
sabotage (item 3's D5 — the item was uncommitted). Every revert therefore came from a
byte-exact snapshot; every injection was `diff`-confirmed to be the sabotage **and
nothing else BEFORE the run**; every restore was `diff -q` IDENTICAL + md5-matched
(`c60b4ff9b1670a95b4909d8a07d91cf6`) with a clean green re-run at the end.

| # | sabotage | predicted | measured | exactly? |
|---|---|---|---|---|
| **NAMED** | `$w.syntax set Shell` -> `RegExp` | BAR05 | **BAR05 alone**, 1 FAILED / 115 passed | **yes** |
| **E1** *(required extra)* | `$w.type set All` -> `Voltage` | BAR04 | **BAR04 alone** | **yes** |
| **E2** *(required extra)* | `set sbcase($w) 0` -> `1` | BAR06 | **BAR06 alone** | **yes** |
| u1 | delete the `sig_match` validation call in `searchbar_fire` | BAR18 (+BAR19) | **BAR18 + BAR18b** — declared superset of the guard pair, and BAR19 correctly did NOT fire (the label is empty either way when the pattern is valid) | yes (2, declared) |
| u2 | invert `sb_type_code` (`Voltage` -> `i`) | BAR12, BAR15 | BAR12, BAR11, BAR15, BAR16, BAR17 — honest superset: BAR11/16/17 all read the `type` code of the same explicitly-set Voltage state | no (declared superset) |
| u3 | drop the `-showbutton` branch (always create the button) | BAR10 | **BAR10 alone** | **yes** |
| u4 (round 1) | delete `ase::ui::apply_theme $w` | BAR22 | **SURVIVED — ALL PASS.** See §5 | — |
| u4 (round 2, after BAR22b) | same | BAR22b | **BAR22b alone**, `grey80` vs `#f2f2f2` | **yes** |
| u5 | `$w.err -width 24` -> `-width 0` | BAR21 | **BAR21 alone** — THE mutation that proves the eyeball property is really pinned | **yes** |
| u6 | drop the `%W eq $w` guard on `<Destroy>` | nothing today | **SURVIVED — ALL PASS.** Declared gap, see §5 | — |
| u7 | drop `unset sbcfg($w)` from `searchbar_forget` | BAR24 | **BAR24 alone** (`{1 0 1 0}`) | **yes** |
| u8 | swap the `syntax`/`case` pack order | BAR03 | BAR03 + BAR10 — honest superset: BAR10 asserts the SECOND bar's whole pack list | no (declared superset) |
| u9 | invoke the callback only when `$msg eq {}` | BAR26 | **BAR26 alone** | **yes** |

**The NAMED sabotage fires on exactly one check**, and so do both required extras.
Eight of twelve are exactly-single or exactly-predicted; two are declared supersets;
two survived and are declared in §5 rather than papered over.

## 5. The two mutations that SURVIVED, and what was done about each

**u4 — `ase::ui::apply_theme` was not pinned. FIXED by widening the coverage.**
Deleting the theming call left **every check green**. BAR22 as first written checked
`[$w.pat cget -font]` and `[$w.err cget -foreground]`, and *neither* comes from
`apply_theme`: the entry names `AseEntryFont` at creation time, and the accent
foreground is configured on the line AFTER `apply_theme`. So BAR22's name — *"theme:
entry font is AseEntryFont, error label is the accent"* — was **literally true and
strategically misleading**, exactly ruling 17's corollary. Per that corollary (*widen
the coverage or narrow the claim, never neither*) the coverage was widened:
**BAR22b** pins the panel BACKGROUND on the frame, checkbutton, button and label, which
is `apply_theme`'s own contribution and nothing else's. Re-run: u4 now fails **BAR22b
alone**.

**u6 — the `%W eq $w` `<Destroy>` guard is DEAD CODE today, and stays. DECLARED GAP.**
Replacing the guard with `if {0}` left every check green, as the scout predicted. The
mechanism, checked rather than guessed: a frame path is **not** in its children's
bindtags (a child's tags are `{child Class Toplevel all}`), so no child's `<Destroy>`
can reach the frame's binding. The guard costs nothing and is the one thing standing
between a future consumer that adds `$w` to a child's bindtags and a bar that
de-registers itself the first time its entry is destroyed. **It is not covered, it is
not claimed to be covered, and it was not deleted to make the sabotage table prettier.**

## 6. Two check names carry a `b` suffix, and why (ruling 17 corollary audit)

Every BAR name was re-read against what it actually pins. Two were found overstating and
both were repaired by widening, never by rewording alone:

* **BAR18b** — *"(guard) that message is non-empty, so BAR18 is not vacuous"*. BAR18
  computes its expectation from `sig_match` at test time (never a hard-coded Tcl error
  string, so it pins *"the label shows the matcher's message VERBATIM"* and not the Tcl
  version's wording). That construction is self-satisfying if the message is ever empty
  on both sides — BAR18b closes it.
* **BAR22b** — see §5.

The rest were audited and left alone. In particular **BAR03 says "pack order", not
"spacing"**, and **BAR21 says "does not change the bar's reqwidth", not "looks right"** —
both are deliberately narrower than the eyeball lines they came from.

## 7. Verification

1. `cd src && make` -> *"Nothing to be done for 'all'"*.
2. `./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_wave_sigsearch.tcl`
   -> **ALL PASS (90 checks)**, BAR group printing `SKIPPED: BAR group (Tk/X arm only)`.
3. `tests/headless/run_suites.sh test_wave_sigsearch` -> **ALL PASS (117 checks)**.
4. `tests/headless/run_suites.sh -n 8 test_wave_sigsearch` -> **8/8 runs passed**,
   25 s wall. This is the BAR25 soak (see §8).
5. Sabotage round: §4, twelve injections, each `diff`-confirmed, each measured, each
   reverted to md5 `c60b4ff9b1670a95b4909d8a07d91cf6` with `diff -q` IDENTICAL.
6. TWO solo `tests/headless/full_audit.sh` runs — see §12. Run 2 is the measurement
   (0 X deaths); run 1 is discarded and every name it raised was chased down anyway.
7. `git status --porcelain -- src/ tests/` shows only this item's two files. Probes,
   snapshots and injection scripts live in the scratchpad; **no droppings in the repo**,
   no `test_scratch` dir (the BAR group writes nothing and destroys both toplevels).

## 8. BAR25 — written, measured, and DELETED. The claim is narrowed to match.

BAR25 was the end-to-end leg: *"a REAL generated `<KeyRelease>` on the entry reaches the
callback"*, built on `test_wave_viewer.tcl:428`'s `send_key` helper copied verbatim.
Its history is the whole lesson, so all three stages are recorded:

**Stage 1 — it failed, and it was NOT a flake.** On the first DISPLAY run it returned
`{0 {}}`. A probe under `gated_xschem.sh` printed the cause in one line:

```
mapped(top)=1  mapped(pat)=0  viewable=0
focus=.wvsb1   (focus -force $w.pat did not take)
```

`searchbar_build` returns an **unmanaged** frame — geometry management belongs to the
consumer (item 5 grids it into a dialog, item 8 packs it above the tree). An unpacked
frame is UNMAPPED, its entry is unmapped with it, and `focus -force` on an unmapped
window silently leaves the focus on the toplevel, so no generated key could ever be
delivered. **The test was missing `pack $w -fill x`; the widget was correct.** That
line is now in the test with a comment, because it reads as a widget bug and is not one.

**Stage 2 — with the fix it soaked 8/8 green** (`run_suites.sh -n 8`, 25 s wall). On
that evidence it shipped.

**Stage 3 — it then FAILED inside a clean full 283-test audit** (`{0 {}}`, run 2, the
audit with zero X deaths). Under the load of 200+ preceding GUI tests the WSLg focus
round-trip stalls past the helper's ~10 s budget. It was the ONLY fail in that audit
attributable to this item.

**It was DELETED, not made conditional.** A self-skipping version was considered and
rejected on a specific ground: `bar_send_key`'s only oracle is *"did the callback
fire"*, which **cannot distinguish a WSLg delivery stall from a genuinely broken
binding** — so a conditional skip would mask exactly the regression the check exists to
catch, which is strictly worse than not having it. This is the scout's pre-authorised
FALLBACK, taken for the reason the scout gave: *rather than shipping a flake.*

**THE NARROWED CLAIM, stated in the test header, in the code where BAR25 used to be, and
here** (ruling 17's corollary — widen the coverage or narrow the claim, never neither):
**the handler and the binding are pinned (BAR13 + BAR14); end-to-end X key delivery into
this widget is NOT.** BAR16 (`$w.search invoke`) and BAR17 (a `<<ComboboxSelected>>`
virtual event) still exercise two real Tk event routes end-to-end; neither is
focus-routed, which is why neither is flaky.

Re-verified after the removal: `-n 3` -> **3/3 ALL PASS (116 checks)**, and the NAMED
sabotage plus E1, E2, u4 and u5 were **all re-injected and all still fire on exactly
their one target**.

## 9. EYEBALL NOTE — owed to the human review queue (verdict `[E]`)

Open the search bar on a throwaway toplevel under a DISPLAY (the test builds exactly
this at `.wvsb1`; `pack $w -fill x` is required, see §8).

1. **Order.** Widgets read left-to-right `[All ▾] [__________] [Shell ▾] [ ] Match case
   [Search]`, then the error area. *(BAR03 pins the pack order; it does not pin how it
   looks.)*
2. **Spacing.** 6px outside gutters, 4px between widgets, 3px vertical. No widget should
   touch another; the pattern entry should take all the slack. **Not covered by any
   check.**
3. **The error label.** With `RegExp` selected, type `[`. The dark-red (`#8b0000`)
   message appears in the reserved 24-character slot and **the bar's width must not
   change**; clear the box and the slot goes blank without the bar snapping back.
   *(BAR21 pins the reqwidth invariance; the colour value is pinned by BAR22; that the
   red is READABLE is not.)*
4. **Legibility.** The `Match case` indicator against the `#f2f2f2` panel background
   `apply_theme` forces. *(BAR22b pins the background value only.)*
5. **The clip budget.** A long message clips at ~24 characters rather than pushing the
   `Search` button off the end. **Confirm the clip is acceptable** — if it is not, the
   right fix is a tooltip in item 5, not an elastic label (an elastic label re-introduces
   exactly the resizing BAR21 forbids).

## 10. Anchors re-verified from the shipping tree before use

* `src/wave_viewer.tcl:7466` `$w.err configure -foreground [ase::theme accent]` inside
  `wviewer::add_trace_dialog` (`:7420`), with `:7451` the `label $w.err` and `:7465` the
  `ase::ui::apply_theme $w`. All exact at `89565388` — the scout's +268 drift call from
  the PLAN's `:7198` is confirmed.
* `src/ase_window.tcl:159` `proc ase::ui::apply_theme {w}`. Confirmed: **no `TFrame`
  arm**, which is why `$w` is a plain `frame`. `Frame/Label/Checkbutton/Button` ->
  `-background [ase::theme panel]` + `AseLabelFont`; `Entry` -> `table` + `AseEntryFont`;
  `TCombobox` -> `AseEntryFont` + `Ase.TCombobox`.
* `src/ase_window.tcl:128` `proc ase::theme`, palette `accent #8b0000` at `:149-150`,
  and the lazy `font create AseLabelFont` (`:130`) / `AseEntryFont` (`:133`). The lazy
  creation is why `searchbar_build` calls `ase::theme` **first**, for its side effect:
  the widgets below name those fonts at CREATION time.
* `src/wave_viewer.tcl:1490` `sig_type`, `:1528` `sig_match`, `:1573` the
  `^(?:$pattern)$` wrapper, `:1584`/`:1590` the two separate `-nocase` flags, `:1596`
  the `return [list ok $out]`. All exact.
* `references/viva_cadence_waveform_viewer.md:171` §3.2. Order confirmed verbatim, and
  it has **six** controls — see D1.
* `tests/headless/full_audit.sh:109` `is_skip()` and the `nogui_tests` list at `:69`.
  Both confirmed: `test_wave_sigsearch` is **not** in `nogui_tests`, so the audit runs it
  in the DISPLAY arm and the BAR group really executes there.
* `tests/headless/test_wave_viewer.tcl:428` `send_key`. Copied verbatim as
  `bar_send_key`.

## 11. ⚠ GUI-GATE DISCLOSURE — `revive FAILED -- suite continues UNGATED`

**This must be read by whoever runs the next item.** At `2026-08-04T18:36:58-0700`,
during **audit run 1** (pid 737166), `~/.claude/gui_test_gate/events.log` recorded:

```
2026-08-04T18:36:55-0700 [737166] panel death detected -- reviving
2026-08-04T18:36:58-0700 [737166] panel launch FAILED (see .../widget.log)
2026-08-04T18:36:58-0700 [737166] revive FAILED -- suite continues UNGATED
```

`widget.log` gives the cause: `gui_gate: refresh error: error reading "file6": no such
process` — the panel died on a stale pipe read and the immediate relaunch lost the race.
**Audit run 1 therefore ran ungated from 18:36:58 to its end**, which is also the run
that took the single `X connection to :0 broken`.

What was done, and not done, about it:

* **No further suite was launched after this was noticed.** The instruction is explicit
  and was followed to the letter.
* **The panel self-recovered and demonstrably has authority now.** It is alive as pid
  `737760` (`wish gui_gate_widget.tcl`, 30 min uptime); it granted approval windows at
  18:54:02, 18:54:34 and 18:55:01; and it is **currently holding audit run 2 PAUSED at
  30 lines**, which is the strongest available evidence that a human Pause reaches the
  running suite.
* **`GUI_GATE=0` was never set and the control files were never hand-written**, at any
  point in this item. Every wait was waited out (one ~5-minute hold before the first
  DISPLAY run, one multi-Pause hold across audit run 2).
* Audit run 2 was already enrolled and gated when the log line was found; it was allowed
  to finish rather than killed, because killing a suite the panel is actively pausing is
  strictly worse than letting the human's own Pause govern it.

**Recommendation to the driver:** the gate's revive path has a race (`refresh error:
... no such process` -> `panel launch FAILED`). It self-healed here, but a suite ran
ungated for part of a 40-minute audit on a shared machine. Worth a look before the next
long batch.

## 12. Full audit — TWO solo runs

**Run 1 is DISCARDED as a non-measurement** (the rule is explicit): its log contained one
`X connection to :0 broken`, which *was* `test_ase_hier_plot_0168`'s only failure (all 22
of its checks had passed, then the display died mid-test). It also took 10 environmental
self-skips and, from 18:36:58, ran ungated (§11). It is recorded only because every
non-baseline name it produced was chased down: `test_ase_hier_plot_0168` **3/3 PASS**,
`test_wire_vertex_grab` **3/3 PASS**, `test_cmdmode_descend_0201` and `test_graph_context`
**5/5 PASS each** on a settled machine (their single failures both landed in the run
immediately after the 40-minute audit — item 3's documented time-ordering confound).

**RUN 2 IS THE MEASUREMENT.**

```
SUMMARY: 260 pass  19 fail  0 crash/timeout  4 skip  (total 283)
WIREEDIT: PASS      SCRATCH: 0 leaked dir(s)
grep -c "X connection to :0 broken"  ->  0
```

The 19 fails decompose exactly:

| | |
|---|---|
| **16** | all 16 HARD baseline names, **each on the check the PLAN Baseline block records** — the action-log/self-log cluster (PS0-RP1, SA5-SA8b, the six `key ... logs` lines, `action log open`), the three PDK `library_list` fails with the `{SANDBOX TEST}` extras from `~/.xschem/library.defs`, `test_fluid_editing` on FE8, `test_ase_window` on W7, `test_lib_manager_gui` on GUI8/GUI9, `test_lib_manager_locate` on LM-LOC3, `test_phase3_mints` on P1-P4, `test_reopen_readonly` on R10, `test_rotate_stretch_short_0104` on rot180-ip, `test_cadence_drag` (re-anchored, any fail = baseline) |
| **1** | `test_nh_anim_rearm` — on the FLAKY list, excused |
| **1** | `test_graph_context` (*"over-graph wheel leaves canvas zoom"*) — on neither list, but **cleared 5/5 solo** and independently seen failing in item 3's verifier audit and cleared 3/3 there. An under-audit-load wheel-gesture flake, not item 4's. **BASELINE FEEDBACK: it belongs on the FLAKY list.** |
| **1** | **`test_wave_sigsearch`, on BAR25 — MINE.** Fixed by deleting BAR25; see §8. Everything else in the file passed. |

`nonBaselineFails: []` after the BAR25 removal, and the removal is the honest fix rather
than a re-run until green: the check was measured to be non-deterministic on this box and
its oracle could not be made unambiguous.

## 13. Divergences from the PLAN

| # | divergence | reason |
|---|---|---|
| **D1** | ViVA §3.2's **fifth control, the `All DBs` checkbox, is DROPPED.** Five widgets, not six. | An xschem viewer window has exactly ONE raw loaded, so the box has nothing to widen the search to. **Declared, not silent**, per the scout's requirement: it is in the shipped comment block AND here. If a multi-raw viewer ever lands it re-enters as widget six, immediately before `Search`. |
| **D2** | **Two checks beyond the PLAN's 26: BAR18b and BAR22b** (29 added, not 27). | Both are anti-vacuity guards, both added because the partner check was MEASURED to pass without the code it claimed to pin (BAR22/u4) or could pass vacuously by construction (BAR18). Ruling 17's corollary says widen the coverage or narrow the claim; widening was cheaper and stronger. §6. |
| **D3** | The PLAN listed `searchbar_forget` as the `<Destroy>` cleanup; the shipped code has **two** procs, `searchbar_destroyed {w W}` (the `%W` trampoline) and `searchbar_forget {w}` (the actual drop). | The trampoline needs `%W`; the drop must also be callable directly by a consumer that tears a bar down by hand. Seven procs, as the PLAN's own list says. |
| **D4** | `searchbar_forget` does `$w.case configure -variable {}` BEFORE unsetting `sbcase($w)`. Not in the PLAN. | Tk's checkbutton keeps a write/unset trace on its `-variable` and **re-creates** the element when it is unset out from under a live widget — the `<Destroy>` on the frame fires while children still exist. Without the detach, BAR24 would see the entry leak straight back. |
| **D5** | The PLAN's `-showbutton 0` bar was described as "hides the button"; shipped it is **not created at all**. | `winfo exists $w.search` then answers *which variant a consumer got*, which is a truthful test; "packed or not" is not. BAR10 asserts it. |
| **D6** | Sabotages reverted from a byte-exact snapshot + md5, **not** `git checkout -- src/wave_viewer.tcl`. | Item 3's D5, verbatim: the item was uncommitted, so a checkout would have destroyed the item with the sabotage. |
| **D7** | The test file **stops being fully `--nogui`-safe.** | The BAR group needs real Tk. `--nogui` now runs 90 of 117 checks and exercises item 4 only through SM28/BAR12. **Stated in the file header AND here**, per the scout's risk list, because a maintainer debugging with `--nogui` would otherwise read a green run as coverage of the search bar. The audit runs the DISPLAY arm, so audit coverage is real. |
| **D8** | The not-run banner is exactly `SKIPPED: BAR group (Tk/X arm only)`. | `full_audit.sh:109 is_skip()` matches `RESULT: SKIP`, `skipped: no X` and `SKIP: no X connection` ANYWHERE in the output and runs BEFORE `is_pass`; any of those spellings would score this whole 117-check suite as SKIP and silently discard every item-1/2/3 check with it. The `test_wave_viewer.tcl:407` precedent was re-verified as safe. |
| **E1** | `bgerror` is now overridden in this file (`puts` + `incr ::fail`). | The file's own NOTE at the header asked for it *"the moment a dialog arrives"*. Real widgets with real bindings have arrived. Swallow-and-count is the only shape that can neither hang nor hide. |
| **D9** | **BAR25 was written and then DELETED** (28 checks added, not the PLAN's 26 + 2). | Measured non-deterministic under audit load, with an oracle that cannot separate a WSLg stall from a broken binding. The scout's pre-authorised fallback, taken for the scout's reason. Full history and the narrowed claim in §8. |
| **P1 (carried, NOT fixed)** | `src/xschem.tcl:4548` still says `wave_viewer.tcl` is *"sourced unconditionally at xschem.tcl:14352"*; the `source` is at **`:14374`**. | Item 3's P1, drifted a **second** time (`14295` -> `14352` -> stale). `src/xschem.tcl` is **outside item 4's Files line**, so fixing it would be a silent scope widening. **Recommendation to the driver: replace the line number with a grep-able phrase** (e.g. *"sourced unconditionally next to `ase_window.tcl` in xschem.tcl's top-level source block"*) — any number will rot again, and it has now rotted twice in two items. |

## 14. If a human looks at one thing

**§9, the eyeball note** — this is a PIXEL item and three of its five properties have no
headless proxy at all (spacing, red-on-panel legibility, whether the 24-char clip is
acceptable). Everything else here is measured.

Second: **§5's u6**, the one live piece of uncovered code in the item. It is dead today
by Tk's bindtag rules and is kept deliberately.

## 15. Baseline feedback owed to the driver

Two names, both measured, neither item 4's:

* **`test_graph_context`** — failed in BOTH of this item's audits, passed **5/5** solo.
  Under-audit-load flake. Item 3's verifier independently hit it and cleared it 3/3.
  **Add to the FLAKY list.**
* **`test_wire_vertex_grab`** and **`test_cmdmode_descend_0201`** — one audit fail each
  in run 1 only, then 3/3 and 5/5 clean. `test_cmdmode_descend_0201`'s failing checks
  (DS7b *"a REAL E keypress armed the pick"*, DS7c *"a REAL click named the instance"*)
  are the known WSLg key/gesture delivery flake — the same class that took BAR25.
  Watch, do not yet list.

And one process item: **§11's `revive FAILED -- suite continues UNGATED`.**
