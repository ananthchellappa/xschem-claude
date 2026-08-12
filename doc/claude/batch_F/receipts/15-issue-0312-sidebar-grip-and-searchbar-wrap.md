# 15 — issue 0312: the sidebar grip, and the search bar that stops dropping its own controls

**Issue:** `doc/claude/issues/0312-the-signal-browser-search-bar-clips-its-own-controls-and-the-width-is-not-draggable.md`
**Ruling:** the user picked **candidate 3 (draggable) + candidate 1 (wrap)**, both, on
2026-08-11 — after being shown the cost of each. Neither half was chosen by the
implementer.
**Touches:** `src/wave_viewer.tcl`, `doc/waveform_viewer_guide.html`, and two
amendable test files (`_i14`'s `BD41`, `_i1315`'s `BP07` — §5.2). New suite
`tests/headless/test_wave_sigbrowser_0312.tcl` (69 checks, bands `BG` + `BF`).
**Unblocks:** `doc/claude/batch_F/EYEBALL_QUEUE.md` item 5 step 7, and two-pane
item 14's eyeball (`doc/claude/signal_browser_2pane_batch/14_receipt.md` §7.7).

---

## 1. WHY BOTH HALVES, AND WHY NEITHER IS REDUNDANT

The arithmetic decides it, not taste. The bar needs **651 px** (measured on this
tree; the issue's 583 predates item 14's `All DBs` box). `browser_width` caps the
sidebar at **0.45 × toplevel** = **450 px** on the shipped 1000 px window. A live
drag goes through *that same clamp* (§2), so **the grip cannot reach 651 px on a
1000 px window** — dragging alone would leave `All DBs` off-screen exactly as
before. Conversely the wrap does nothing for
`EYEBALL_QUEUE` item 5 step 7, which asks for a judgement **at ~250 px** and had
no gesture that could get there.

* grip → the narrow end, and the general complaint ("I cannot make this pane wider").
* wrap → the wide end: at 450 px every control is on screen.

Full-window arithmetic, for the record: the flat bar fits unclipped only from a
**1447 px** toplevel up (651 / 0.45).

## 2. THE GRIP, AND THE PANEDWINDOW THAT COULD NOT BE BUILT

Issue 0312's candidate 3 says *"a horizontal `ttk::panedwindow` between the
sidebar and `$top.drw`"*. **That form is not buildable under ruling 30.** A
panedwindow owns its panes, so `.wvbrowser` stops being a pack slave of the
toplevel — and `tests/headless/test_wave_sigbrowser.tcl`, which is FROZEN,
asserts on a LIVE widget tree that it is one:

| check | what it reads | after a reparent |
|---|---|---|
| `BS01` | source: `pack $f -side left -fill y -before $top.drw` verbatim | gone |
| `BS02` | exactly one pack / one `pack forget` in `browser_show` | gone |
| `BS24` | `bs_order` of the toplevel's pack slaves | `a-missing` |
| `BS41` | the hidden state's slave list | wrong |
| `BT21` | the sidebar's seven-slave recipe | wrong |

It also invalidates item 0's `xschem reload` waiver, which was **measured on that
exact packing** (`signal_writer_batch/receipts/00_precondition.md` §3). Measured,
not argued: sabotage **S27** removes only `-before` from that one line and reds
**16 checks in the frozen file** (BS01, BS24, BT21, BT22, BT26, BT27, BT43,
BT45, BS43, BM42, BM47 …) plus 12 here.

**What shipped instead:** `$top.wvbgrip`, a 6 px frame packed
`-side left -fill y -before $top.drw` immediately after the sidebar. Slave order
becomes `.wvbrowser` < `.wvbgrip` < `.drw`, which `bs_order` still reads as
`a-before-b`, and every frozen literal stays where it was. `BG01`/`BG05` restate
the frozen file's two claims here, so a future editor reaching for the
panedwindow again reds a file that CAN carry the explanation.

**The clamp is not duplicated.** `browser_grip_motion` hands its arithmetic to
`browser_width $token $want` — item 15 already built that door ("a positive
integer REPLACES the derived base and then goes through THE SAME cap and
floor"). The cap/floor stay inline in `browser_width` where BT08 greps them.
`BG04` pins that the drag handler carries no `0.45` and no `240` of its own.

**Declared consequence (the user was told before implementation):** a live drag
takes the 45 % cap, so it cannot widen past 450 px on a 1000 px window. Lifting
that for a live drag would mean changing `browser_width`'s `want` semantics,
which `BP07` pins ("want REPLACES the base, then takes the SAME cap").

## 3. THE WIDTH PREFERENCE — WHAT IT IS AFTER REVIEW, AND WHAT IT WAS BEFORE

`browser_width` derives its base from `[winfo reqwidth $f.wvsearch]`. **The wrap
changes that number**: a two-row bar reports ~410 px, so the derivation lands
under the 240 px floor and a second `browser_show` would collapse a sidebar to
240 for no reason but that it had once been narrow.

**The first implementation solved that in the wrong place** — it SEEDED the
window's width preference with the first show's derived answer. The adversarial
Tk review killed it, correctly, with a scenario: a viewer first opened at 600 px
seeds `int(0.45*600) = 270`; maximise to 1920 and the sidebar stays 270 for the
rest of the session and into the session file, with the user never having
touched anything. It also made "has a preference" and "has been shown" the same
fact — the exact mistake `browser_sash`'s header records the sash default being
moved to a local to avoid.

**It is now fixed at the derivation**: `browser_width` asks `searchbar_need`
what the bar wants FLAT when the bar is wrapped. That number is the same in both
layouts, so the rule is wrap-immune and the seed is gone. `browser_width_pref`
is therefore written by exactly two things — a real grip release, and a session
restore — and its absence means what the accessor says it means. `BG29b` pins
that a first show leaves NO preference; `BG29c`/`BG29d` pin that the round trip
re-derives 450 anyway and that the raw reqwidth really would have floored.

## 4. THE WRAP

`searchbar_reflow`, armed from a single `<Configure>` in `searchbar_build`, picks
between two layouts:

* **flat** — ViVA §3.2's one row, `pack`, byte-identical options to what the
  build shipped. This is the shape `searchbar_build` always leaves, which is what
  `BAR03`/`BAR10` read.
* **wrapped** — `grid`, four columns, weight on column 1 only: row 0 the QUERY
  (`type` / pattern / `syntax`), row 1 the MODIFIERS (`Match case` / `All DBs` /
  `Search`).

Three things are load-bearing:

1. **Each layout releases the OTHER geometry manager first.** Tk refuses `pack`
   inside a frame that already has grid-managed slaves; forgetting to release
   leaves the bar with *no managed children at all*. `BF03`; sabotages **S12**
   (24 of 57 checks survive the run) and **S13** (21 of 57).
2. **The threshold excludes the error label**, because `browser_width`'s
   derivation does — the sidebar is sized to hold the bar WITHOUT err (settled
   decision 5), so counting err would wrap a bar that is losing nothing. `BF04`,
   and its LIVE twin `BF20` — which exists because every other threshold check
   asks `searchbar_need` for the number it then tests against and would move
   both sides of the comparison together.
3. **A 24 px hysteresis band.** On a bar packed `-fill x` into a toplevel that
   sizes itself to the bar's REQUEST — item 5's dialog, and every BAR-band test
   toplevel — wrapping shrinks the request, shrinks the toplevel and re-fires
   `<Configure>`. `BF25`.

`$w.err` is `grid remove`d while wrapped rather than given a third row: it is
`-width 24` (~172 px, half the wrapped budget), it is already THE designated
clippable, and `browser_refresh` mirrors its message into the sidebar's status
line. `BF23`.

**Declared limit.** Row 0 alone wants type (~97) + pattern (~204) + syntax (~87)
plus pads — about **400 px** — so below roughly that even two rows clip: the
entry shrinks first (it is the weighted column), then row 0's tail goes. The
240 px floor is inside that band. The remedy there is the grip or the window.
(An earlier draft of this paragraph said ~350 by adding up the four FIXED
controls and forgetting the entry shares row 0. Corrected in the source too.)

**And the wrap only applies where somebody else owns the bar's width** — a
container with propagation OFF, which is the sidebar's situation and nothing
else's. In an auto-sizing container a bar that does not fit simply asks for more
room and gets it; reflowing there would latch (review finding 3, §5.1).

## 5. EVIDENCE

`tests/headless/test_wave_sigbrowser_0312.tcl` — **69 checks, ALL PASS**.
`BG00`-`BG08` / `BF01`-`BF06` run in both arms; the rest need real Tk and real
X. **39 sabotages**, applied one at a time and re-run; the table is in the
suite's own header with the id each reds.

The three that carry the deliverable:

* **`BF22a` reproduces the SHIPPED DEFECT** — trigger unbound, width at 450,
  flat layout re-applied by hand: `All DBs`, `Search` and `err` read
  `ismapped 0`. **`BF22b` is why 353 green checks missed it**: at that same
  moment `winfo exists`, the checkbutton's `-variable` and `searchbar_get`'s
  dict key all answer normally.
* **`BF27`** — at the shipped default 450 px, through the real `browser_show`
  path, every control is on screen.
* **`BG33`** — a real `<Button-1>`/`<B1-Motion>`/`<ButtonRelease-1>` sequence
  generated ON the grip widget moves the sidebar by the drag delta.

## 5.1 WHAT THE TWO ADVERSARIAL REVIEWS FOUND (neither reviewer was the implementer)

Both were read-only. **Everything below was fixed, not filed.**

**Evidence review — 9 findings.** The severe one: *no check drove a real Tk
button event*. Every drag check called the handlers as procs, so deleting all
three `bind $g` lines left the suite fully green with the divider undraggable —
the deliverable's own gesture, unexercised. Also fixed: `BG30`'s anchor leg was
vacuous (nothing had pressed, so its post-state equalled its pre-state); 57
checks shared 38 ids, so a sabotage row naming `BG24` was satisfied by any of
four; `bf_width` measured a width every one of its seven callers discarded, so
"still wrapped at need+8" was also what a LOST `<Configure>` looks like; `BF27`
measured a hand-dragged 320 px sidebar while claiming "the shipped default";
`BG25` ran from a sidebar already at the answer, so it was green on a dead
gesture; the `+200` headroom was ~20 px from a font-dependent red.

**Tk-correctness review — 10 findings.**

1. **`update idletasks` inside `<B1-Motion>`** drained `on_configure`'s debounce,
   so a drag ran a full `capture_live_view_state` + `regenerate` **per motion
   event**. The flush now happens only on the deriving path, where it is the
   only thing it was ever for.
2. **The seed** — §3.
3. **A one-way latch.** In a container that sizes itself to its children (the
   Add Trace dialog's bar; any bar packed straight into a toplevel) `winfo
   width` IS the bar's own request, so wrapping shrinks the request and the
   unwrap test can never be true again. It could also have wrapped a BAR-band
   test toplevel and turned `BAR03`'s `pack slaves` into `{}`. `searchbar_reflow`
   now refuses unless the container's propagation is OFF. `BF30`.
4. **`browser_state_apply` with no `width` key** re-derived from the wrapped bar
   — closed by §3's derivation fix.
5. The err-label justification holds for the two browser bars, not for Add Trace
   — moot now that that bar never wraps (3).
6. Both layout procs could **throw out of a `<Configure>` binding** (bgerror is
   modal under X and hangs a headless run). Guarded.
7. **Three new gestures with no guide row**, and `GH8`/`GH9` structurally cannot
   see it: they count `bind $f.` lines in `browser_build`, and the grip is bound
   on `$g` in `browser_grip_show`. Documented with `data-gseq` (NOT `data-bseq`,
   which would have demanded a `bind $f.` that does not exist and red GH8 both
   ways). `BG07d` pins the row AND that GH8's sixteen are still sixteen.
8. **The grip was `header` on `panel`** — the very pair `tabbar_refresh`'s header
   records as a MEASURED eyeball failure ("on screen all three buttons were
   indistinguishable"). Now `#b8b8b8`. **Still a pixel, still owed an eyeball.**
9. `browser_grip_press` anchored on `winfo width` while everything else works in
   `cget -width`. `BG35`.
10. `browser_build` left an **orphan packed grip**, and the next show packed the
    sidebar *after* it — divider on the wrong side. `BG34`.

Plus four nits, all taken: the `search` pad was under-counted by 2 px, a dead
`grid propagate`, a comment above the wrong line, and a "~350 px" limit that was
really ~400 (row 0 alone wants ~400; the earlier number added up the four FIXED
controls and forgot the entry shares the row).

## 5.2 AUDIT

`full_audit.sh`, `GUI_GATE=1`, `DISPLAY=:0`, healthy display both ends:
**286 pass / 25 fail / 0 crash / 0 timeout over 311**, `WIREEDIT: ALL PASS`,
`SCRATCH: 0 leaked`. Diffed against `baseline_status.txt` **by NAME and STATUS**.

* **RED-WARD, 4 rows.** `test_wave_modes`, `test_wave_sigbrowser`,
  `test_wave_sigbrowser_i1315` all re-ran **ALL PASS** standalone (488 / 353 /
  191). `test_wave_sigbrowser_i14` was a **REAL REGRESSION and is fixed**: `BD41`
  asserted the `All DBs` box **is packed**, and a wrapped bar is `grid`-managed.
  Widened to "is managed by either manager", which still catches the
  built-but-dropped masquerade it exists for; that file is amendable (only
  `test_wave_sigbrowser.tcl` is frozen). `test_wave_sigbrowser_digital` is FAIL
  but absent from the baseline and predates this work.
* **GREEN-WARD, 10 rows**, all baseline-side red on a binary that predates
  batch F. **NEW: `test_wave_sigbrowser_0312` ABSENT → PASS.**
* **ARTIFACT, not a finding:** 58 `test_wireedit_*` rows read MISSING because
  this run reports the suite as one `WIREEDIT: ALL PASS` line.

A second red-ward hit came out of the post-review suite sweep, not the audit:
**`BP07`** in `i1315`. It pins an ORDER — derive, then `want` replaces, then
clamp — using the position of `string is integer -strict $want`, and finding 1's
fix gave `browser_width` an earlier, different use of that same predicate. The
claim is unchanged and still true; the proxy was ambiguous. Re-anchored on the
whole replacement statement, which is strictly sharper.

## 6. WHAT THIS DOES NOT CLAIM

* **The pixels.** A width/layout deliverable is made of pixels and this is
  verdicted only after the user's eyes. Owed: EYEBALL_QUEUE item 5 step 7, and
  two-pane item 14 §7.7. **Specifically including whether the divider READS as a
  divider** — see review finding 8; no check can say that.
* **The two-row bar's SPACING as it looks** — `BF23` proves the row split, not
  that the rows read well.
* **Behaviour below ~350 px of sidebar** — declared in §4, not fixed.
* **Any change to what the controls DO.** Untouched.
