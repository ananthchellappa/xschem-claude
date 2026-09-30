# Receipt — issue 0619, PS/PDF export and `ps_colors[cadlayers]`

Crew: implementation, 2026-09-29. Branch `fluid-editing`, HEAD `afa48ad6` when the stage opened.
**Everything is left uncommitted.** Three files modified, one added (this receipt).

⚠ **This file is NOT at the path the brief specified.** `doc/claude/issues/0619_receipt.md`
reddens T1: `istamp::misnamed_files` flags any `.md` in `doc/claude/issues/` whose name begins
with a digit and is not `NNNN-<slug>.md`, because such a file "looks like an issue file" the
gate would never read (`ISSUE-STAMP: 1 problem(s)`, `test_issue_stamp` `1 FAILED (101 passed)`).
Measured, then renamed to a non-digit-leading name, which keeps the receipt beside the issue as
the brief intended and is admissible. Note that every other receipt in this repo lives in a
batch `receipts/` directory; `doc/claude/issues/` holds only `NNNN-<slug>.md`, three named
`.md` files and a few `.patch`/`.tcl`/`.c` attachments.

## ⚠ THE HEADLINE, BECAUSE THE TASK'S PREMISE WAS STALE

**The heap over-read — the defect 0619 is titled after, and the one the task described as
"fires on ordinary use" — had already been fixed, by issue 1353.** `set_ps_colors()` has
carried `if(pixel >= (unsigned int)cadlayers) return;` since then, and three rows of
`tests/headless/test_ps_valid_1350.tcl` already fence it (V24 statically, V19 and V20
behaviourally). I measured it before believing it: the exported PostScript is clean, every RGB
triple in [0,1]. The task's instruction to "implement the accessor bounds check" was therefore
**already satisfied and I added nothing there** — a second clamp would have been duplicate code.

**What was still live is the half the filing called independent: the push/pop asymmetry.**
`ps_draw_symbol()` was still *computing* `cadlayers` as a colour index and *handing it to the
accessor* — 4 requests for colour 22 with `cadlayers == 22`, twice over, once per export verb.
Only the sink had been repaired. That is the fix in this receipt.

**So the two halves are not "the over-read and the colour logic" as the brief framed them.**
The over-read was cured in 2026-08 by someone else; what I fixed removes the **out-of-range
request** and repairs the **soundness of the push's guard**. It fixes no colour a user sees —
stated plainly in part 6, because the temptation to claim otherwise is the whole reason this
defect survived.

---

## 1. What I changed, by symbol

### `src/psprint.c` — `ps_draw_symbol()`, two sites, 2 lines of code

| pass | was | now |
|---|---|---|
| symbol-text loop | `if(textlayer != c) set_ps_colors(c);` | `if(textlayer != c_for_text) set_ps_colors(c_for_text);` |
| pin-name loop (P6) | `if(plw != c) set_ps_colors(c);` | `if(plw != c_for_text) set_ps_colors(c_for_text);` |

Plus a block comment on the first, naming the two upstream commits, the sibling back ends, the
site that must NOT be changed, and rows V28/V29. `set_ps_colors()` itself is **untouched** —
including its `dbg(1, ...)` line, which is deliberately left *above* the 1353 bounds test
because that is the only place an out-of-range request is observable.

**Why `c_for_text` and not `c`, concluded from history and not from taste.** The filing said
"whoever fixes it should decide which of the two is the real intent". `git log -S` answers it:

* `70aed29f` (upstream, 2025-04-06, *"fix ps/svg export of highlighted instances (text color)"*)
  introduced `c_for_text` **while the text block was still guarded `layer == cadlayers - 1`**.
  `c` was the ambient layer then, and `set_ps_colors(c)` was in range. The pop was correct.
* `6b12969d` (upstream, 2025-04-21, *"complete change `draw text at end … to preserve stacking
  order`"*) moved the pass one layer **past** the top — guard to `layer == cadlayers`, plus
  `ps_draw_symbol(c + 1, i, c + 1, ...)` in `create_ps()` — and updated the guard and the call
  but **not the pop**. `c` became a pseudo-layer; the pop became a fossil.
* Corroboration: `draw.c` and `svgdraw.c` carry the same two clamps and **no pop at all**,
  because their colour is not sticky state. `psprint.c` has the pair only because PostScript
  colour *is* sticky, and the value the push departs from is `c_for_text`.

So the pop mirrors the push; the push compares against `c_for_text`; the pop must restore it.
Not "either could be right".

**`ps_draw_annot_overlay()`'s `if(layer != c) set_ps_colors(c);` is left alone and is correct** —
`create_ps()` calls it as `ps_draw_annot_overlay(i, c)` with `c == cadlayers - 1`, a real layer.
V29's patterns key on `textlayer` and `plw` so they cannot drag it in.

### `tests/headless/test_ps_valid_1350.tcl` — already an `hcases` case, extended not created

* `child_export` — one trailing optional arg `{dbg 0}`; `1` adds `-d 1` to the child. All 27
  existing call sites omit it and are unaffected.
* **V28 (0619), behavioural.** A `-d 1` export of a two-instance fixture, for both `print ps`
  and `hier_psprint`; parses `set_ps_colors(): setting color N` out of the child's captured
  output and asserts **no N >= cadlayers**. `cadlayers` is printed **by the child** and parsed
  back, so the row cannot drift from the binary it measured (a hardcoded 22 would be a number
  nothing re-checks). It also asserts **in-range requests > 0** — the instrument-liveness clause,
  sabotaged below.
* **V29 (0619), static.** Both repaired spellings present **and** both fossil spellings absent,
  each asserted **by name**, reusing V27's existing `v27_live` (comment and `#if 0` stripping)
  and `v27_pat` (whitespace tolerance) helpers.
* The ps2pdf-missing skip text: `V22-V27` → `V22-V29`.

Both rows sit **above** the `ps2pdf` gate, with V22–V27, because neither distils anything.

### `doc/claude/issues/0619-…md`
Header `Status:` OPEN → FIXED with a warning that the header is not the whole answer, plus a
dated `RESOLVED 2026-09-29` section. The original measurement is **left verbatim** — it is a
`0948d02e` record — and the new section says so rather than editing it.

**No registration change was needed** and none was made: `test_ps_valid_1350` is already in
`hcases`, and I verified its epilogue against the real reader rather than against
`run_suites.sh` — `banner_complete {OVERALL: ok (29 checks)} -> 1`, and
`banner_complete {RESULT: ALL PASS (29 checks)} -> 0`, confirming the suite is registerable for
the right reason.

## 2. The red, verbatim

Baseline before any edit: `PASS | test_ps_valid_1350 run 1/1 RESULT: ALL PASS (27 checks)`.

With V28/V29 added and `src/psprint.c` untouched:

```
FAIL     | test_ps_valid_1350           run 1/1  RESULT: 2 FAILED (27 passed)
         | FAIL: V28 (0619) THE CALLER: a `-d 1` export never asks set_ps_colors() for an index
           that is not a layer. … (bad={{print ps:rc=0,sig=0,cadlayers=22,inrange=8, over={22}}
           {hier_psprint:rc=0,sig=0,cadlayers=22,inrange=9, over={22}}} {print ps: cadlayers=22
           inrange=8 over={22}} {hier_psprint: cadlayers=22 inrange=9 over={22}})
         | FAIL: V29 (0619) both pops in ps_draw_symbol() are SYMMETRIC with their pushes in
           src/psprint.c … (found={} missing={symbol-text/pop-restores-c_for_text
           pin-name/pop-restores-c_for_text} fossils_left={symbol-text/pop-restores-c
           pin-name/pop-restores-c} tested=4 src=112733B live=54496B)
```

(The `outofrange=` count was added to V28's detail after this run; later transcripts show it.)

Independently, by hand, before writing either row — the measurement that found the live half:

```
CADLAYERS=22
--- set_ps_colors index histogram (symbol text only) ---   3 3   2 4   2 22
--- set_ps_colors index histogram (+ a show_pinname pin) --- 5 3   2 4   2 5   4 22
--- RGB lines in the exported .ps ---
      1 0 0 0 RGB
      3 0 0 0.55 RGB
      3 0.132812 0.132812 0.132812 RGB
      2 0.132812 0.597656 0 RGB
```

Two readings in one place: **index 22 is requested** (4×, two sites × two instances), and **every
emitted triple is in range** — the accessor is throwing the index away. The pin was needed: a
fixture without an owned pin reaches only the symbol-text site and gives 2, not 4.

## 3. The green

```
before:  RESULT: ALL PASS (27 checks)      (the suite as it shipped)
red:     RESULT: 2 FAILED (27 passed)      (V28+V29 added, psprint.c untouched)
after:   RESULT: ALL PASS (29 checks)
```

Neighbours that a `psprint.c` change could disturb, all run after the fix, all green:

| suite | result |
|---|---|
| `test_hier_pdf_links_1333` | ALL PASS (89 checks) |
| `test_ase_simcaps_0948` | ALL PASS (211 checks) |
| `test_op_annot` | ALL PASS (486 checks) |
| `test_annot_hier_0911` | ALL PASS (15 checks) |
| `test_snprintf_fmt_1608` | ALL PASS (48 checks) — its row `X1` checks source comments cite rows that exist; my new comment cites V28/V29 |
| `test_issue_stamp` | ALL PASS (102 checks); `tclsh tests/headless/issue_stamp.tcl` → `ok (0 problems)` |

**Binary confirmed relinked** before any result was believed: `src/xschem` mtime
`1790684233 → 1790729481`, with `gcc -c … psprint.c` and the link line in the transcript.

### What the fix does to the bytes, measured both ways

| fixture | HEAD | fixed | `.ps` bytes |
|---|---|---|---|
| symbol text on its default layer (`textlayer == c_for_text`) | `5×3 2×4 2×5 4×22` | `5×3 2×4 2×5` | 6035 → 6035, **byte-identical** |
| `T {@name} … {layer=7}` (`textlayer != c_for_text`) | `3×3 2×4 2×5 4×7 4×22` | `5×3 2×4 2×5 4×7` | 6041 → 6103 |

So on the shipped shape the fix removes 4 discarded requests and **changes not one byte**; where
the layers differ it **adds the restore that was missing**, visible in the diff as two extra
`0.132812 0.132812 0.132812 RGB` (layer 3 = `TEXTLAYER`) lines immediately after the layer-7 text.
Note HEAD's `3×3` versus the fixed `5×3` on that fixture: the two missing layer-3 requests *are*
the missing restores.

## 4. Sabotage — five, and one of them is the most useful thing in this receipt

Each: edit, `make -C src` (relink confirmed), full suite run. Suite run ≈32 s.

| # | sabotage | reddened | survived |
|---|---|---|---|
| 1 | **delete 1353's accessor clamp, keep my fix** | **V24 only** (1 failed, 28 passed) | V19, V20, V22, V23, V26 |
| 1b | delete the clamp **and** revert my fix (pre-1353 world) | **8 failed**: V19 (`out of range`), V20 (`bad triples=49153 on 66 sheets`), V22, V23, V24, V26, V28, V29 | — |
| 2 | revert my fix, keep the clamp (= HEAD) | V28 (`outofrange=4` per verb), V29 (both fossils present, both repairs missing) | — |
| 3 | **the plausible wrong fix**: clamp the fossil instead of repairing it — `if(textlayer != c && c < cadlayers) set_ps_colors(c);` | **V29 only** | **V28 went green** |
| 4 | half-done edit: repair the symbol-text pop, leave the pin-name pop | V28 (`outofrange=2`, halved) **and** V29 (`missing={pin-name/pop-restores-c_for_text} fossils_left={pin-name/pop-restores-c}`) | — |
| 5 | fix correct, **instrument killed**: delete `dbg()` from `set_ps_colors()` | **V28** (`inrange=0 outofrange=0`) | — |

Three of these are load-bearing:

* **Sabotage 3 is why V29 exists.** Clamping the fossil removes the out-of-range request, so the
  behavioural row is satisfied while the pop still restores the wrong variable and the push's
  guard is still unsound. A single row here would have waved that through.
* **Sabotage 5 proves V28 cannot pass by seeing nothing.** Without the liveness clause, killing
  `-d` or the `dbg()` line would have produced a silent green.
* **⚠ Sabotage 1 against 1b is the finding, and it is a COST of this fix, not a win.** Before my
  change, deleting the 1353 clamp reddened **eight** rows. After it, deleting the same clamp
  reddens **V24 alone** — because my fix removed the last caller that hands the accessor an
  out-of-range index, so V19, V20, V22, V23 and V26 have nothing to see. **Those five were
  fences for the clamp only because 0619 was unfixed.** From now on the 1353 clamp is held by a
  **static row and nothing else**. That is V24's stated purpose (its own comment demands that a
  future reader who prefers a different answer "should have to redden a row that says so by
  name"), so the fence is in place — but anyone who later "simplifies" V24 as redundant will
  silently unfence a real out-of-bounds read. Said loudly here because nothing detects it.

## 5. What I got wrong during the stage

1. **I set out to fix a defect that was half-fixed, and the brief and the issue file both said
   it was live.** I nearly wrote the row the task specified — "catch an out-of-range RGB
   component in real PS output" — which would have been **green on arrival** and thus no fence at
   all. What corrected me was reading `src/psprint.c` before writing anything: the `set_ps_colors`
   grep landed on a 17-line comment headed *"ISSUE 1353 — THE OTHER HALF OF 1342"* sitting
   directly above the clamp. Then `/usr/bin/grep -n 'check '` on the suite showed V19, V20 and
   V24 already citing 1353. **The instruction to verify rather than trust was the whole stage.**
2. **My first instinct for the red was the wrong instrument.** Having found the output clean, I
   started reasoning about RGB line *counts* as the oracle for the asymmetry. V19's own comment
   stopped me — it records that a first draft of that row asserted 8 lines and *"redded on a
   correct binary at 5"*. The count is not deterministic; the requested **index** is. That sent
   me to `dbg()`, which prints the index *before* the 1353 test consumes it.
3. **I assumed the fix would add bytes everywhere, and it adds none on the shipped shape.** I
   expected the symmetric restore to emit an extra RGB per text. It does not, because on a
   default-layer text `textlayer == c_for_text` and the pop's guard is false. I only learned this
   by diffing the two `.ps` files, and it is the reason V19/V22/V23 did not need touching. Had I
   "pre-emptively" relaxed V19's `distinct == 2` assertion to make room for bytes that never
   arrive, I would have weakened a 1353 fence for nothing.
4. **Two shell mistakes cost a few minutes each.** A scratch `HOME` that did not exist made
   xschem exit 1 with `failure creating …/.xschem` and zero debug output, which for one moment
   looked like "the defect is gone". And `tclsh -c 'x'` is not a valid invocation — it read
   stdin and hung until the 120 s timeout moved it to the background. Neither affected a result;
   both are why every command here carries `timeout`.

## 6. What I did NOT do, and what is unverified

* **I added no accessor bounds check.** It is already there (issue 1353). Verified present,
  verified effective, verified fenced by V24. Adding a second would be duplicate code.
* **I fixed no colour a user sees, and I claim none.** No rendered output changes.
  `doc/claude/issue_1607_batch/receipts/B-display-arm.md` measured the suppressed restores as
  dead colour sets — 0 of 36 rasterised pages differing — because every drawing site emits its
  own colour first (`ps_draw_string_line()` opens with `set_ps_colors(layer)` **inside its own
  `GS`/`GR`**, so it cannot even be influenced by the ambient). What the fix buys: the
  out-of-range request is gone, and the push's `if(textlayer != c_for_text)` "already at that
  colour" guard becomes **sound** — it was not, while the pop never restored the ambient.
  **I did not re-run a rasterised comparison myself**; that figure is the 1607 receipt's, and my
  byte measurement is consistent with it (identical output on the default-layer fixture).
* **I did not delete the pops**, which the evidence would also support (`draw.c`/`svgdraw.c` have
  none, and the 1607 receipt measured them dead). Deleting both would remove emissions from every
  exported file and disturb V19's distinct-triple assertion for no gain; repairing them keeps the
  push's guard honest and is what the task asked for. **This is a judgement, flagged as one.**
* **No golden needed regenerating, and I checked rather than assumed.** Nothing under `tests/`
  contains a PostScript `RGB` line at all (`tests/headless/gold/` holds spice netlists and
  `state.txt`); the only tracked files quoting an out-of-range triple are issue write-ups
  (0454, 0615, 0619), which are dated records and are left alone. The sweep was
  `/usr/bin/grep -rhoE '^…RGB$' tests/ | awk '{if($1>1||$2>1||$3>1) print}'` → empty, plus a
  `git ls-files`-wide pass.
* **On byte counts as an oracle** (the filing warned against them): narrower now, not lifted. The
  garbage float's text width is gone, so a PS byte count no longer moves for *that* non-semantic
  reason — and it still moves with page scale, translate and line width, which depend on the
  display arm and on the window size the throwaway HOME gives (V26's block measured 4468
  differing PostScript lines between arms on one sheet). **Compare two children on the same arm**
  (V22/V23 do, unfiltered) or compare the sorted RGB multiset (V26). I did not rely on a byte
  count for any verdict; the two byte figures in part 3 are same-arm, same-fixture,
  same-process-shape comparisons and are descriptive, not assertions in any row.
* **I ran no full T1** (the driver's job) and **committed nothing**. `git status`:
  `M doc/claude/issues/0619-…md`, `M src/psprint.c`, `M tests/headless/test_ps_valid_1350.tcl`.
  The two untracked directories `.xschem/` and
  `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/` were already there when the stage
  opened and are not mine.
* **The display arm of V28 is unexercised.** `child_export`'s `display` arm accepts the new `dbg`
  flag but no caller uses it; V28 runs `nogui` only, which is where the defect lives (the index
  does not depend on the display). Not a gap worth a display child.
* No permission prompt denied anything.

## 7. What the next stage must know

1. **`skips=` and the case count do not move.** No suite was registered, renamed or added;
   `test_ps_valid_1350` was already in `hcases` and prints no `skip:` line on the headless arm
   unless `ps2pdf` is missing (it is present here — V14 swept 96 sheets). T1 should stay at
   `cases=107 blocks=106 skips=8`, with this case's published `RESULT:` line moving from
   `ALL PASS (27 checks)` to `ALL PASS (29 checks)`.
2. **⚠ V24 is now the ONLY fence on issue 1353's clamp.** Sabotage 1 measured it: delete the
   clamp with this fix in place and V24 alone reddens. Do not let anyone retire V24 as duplicated
   by V19/V20 — after this commit it is not.
3. **The issue file 0619 was wrong about its own status for about five weeks**, and the mechanism
   generalises: *every* fence on it was keyed to the malformed **output**, a change for a
   different issue stopped producing that output, and all of them kept passing while the defect
   sat in the file. That is CLAUDE.md's "a fence keyed to a symptom dies quietly when something
   else cures the symptom", caught live. **Worth a sweep of the other symptom-keyed rows in this
   family** — 0454 (`ps-export-emits-an-uninitialised-rgb-triple`) is the obvious next one to
   check, since it is the third tracked file quoting an out-of-range triple and I did not
   investigate whether it is also already fixed.
4. **The `dbg(1, ...)` line in `set_ps_colors()` is now load-bearing for a test.** It must stay
   **above** the bounds test, or V28 goes blind. V28's liveness clause turns that into a FAIL
   rather than a silent pass (sabotage 5), but the comment in the suite is the only place that
   says why the ordering matters.
5. **`child_export` grew a seventh argument.** `{dbg 0}` is trailing and defaulted, so nothing
   else changed; a future arg must go after it or every V28 call needs updating.
6. **The brief's framing of "both halves" does not match the tree** and a future reader of the
   task text will be misled the same way I nearly was: the accessor clamp half was done in
   2026-08. If a similar task arrives citing a filing measured at an old commit, **re-measure
   before writing the row the brief specifies** — here that row would have been green on arrival.

---

## ADDENDUM 2026-09-29 — V24's sole-fence status written into V24 itself

The coordinator's follow-up, and it closes the one real gap in this receipt: the finding in part 4
("after this fix the 1353 clamp is fenced by V24 alone") lived **only here**, and the reader who
needs it is reading the row, not the receipt. Worse, the evidence they would gather points the
wrong way — V19, V20, V22, V23 and V26 are all green with the clamp deleted, so V24 reads as
belt-and-braces.

**Comment and prose only. No code, no assertion, and V24's `$v24re` and `check` expression are
byte-identical** — verified by diff: the only `-` lines in `tests/headless/test_ps_valid_1350.tcl`
against HEAD are the four from the original stage (`child_export`'s signature, its two `exec`
lines, and the `V22-V27` → `V22-V29` skip text).

* **`tests/headless/test_ps_valid_1350.tcl`, V24's comment** — four paragraphs added above
  `set v24src`: that V24 is the SOLE fence as of 0619; the measured evidence
  (`1 FAILED (28 passed)`, V24 and nothing else, with five behavioural rows green over a
  reinstated out-of-bounds read); *why* those five stopped being fences (until 0619 the caller
  handed the clamp `cadlayers` once per symbol text and once per pin name, so it had a live
  exerciser — deleting the clamp on that older tree reddened eight rows, V20 at
  `bad triples=49153 on 66 sheets`); that V28 is **not** a substitute (it watches the caller and
  stays green when the clamp goes); and that deleting or "simplifying" V24 silently unfences the
  read valgrind called *"Invalid read of size 4 … 8 bytes after a block of size 264"*, with
  nothing detecting it.
* **`doc/claude/issues/0619-…md`, RESOLVED section** — the existing cost paragraph rewritten to
  state the same four facts explicitly rather than in passing, and to point at V24's own comment.

**⚠ One thing I got wrong in the first draft of this addendum, caught before reporting.** Both new
texts said the clamp is "still necessary as the accessor's own contract for **eleven** call sites",
a figure carried over from the 0619 filing's "Suggested fix". I counted: it is **15** today. Rather
than update the number I removed it from both, which is what CLAUDE.md requires — *"Either a row
asserts the count, where it is re-measured every run, or the sentence drops the number"*, and the
sentence that shipped wrong three times in the 1608 batch did so inside each revision written to
fix the last one. The V24 comment now says so in one parenthesis, so the next writer does not
re-add it. The filing's own stale "11" is left in place as the dated record it is; the header
warning already says every figure in that part of the file is a `0948d02e` figure.

**Re-verified after the edits:** `test_ps_valid_1350` → `ALL PASS (29 checks)`;
`tclsh tests/headless/issue_stamp.tcl` → `ok (0 problems)`. Still uncommitted.
