# TWO-PANE item 18 — R12: auto-tick, reveal, and say so

Two-pane item 18 (**not** single-pane item 18). Spec
`doc/claude/specs/waveform_signal_browser_two_pane.md` R12, §7.4, §8.2, §9.
PLAN: `doc/claude/signal_browser_2pane_batch/PLAN.md` item 18.

Commits: **`6c887aed`** (the item) + **`91a3de1a`** (the fix-up, §14).

**Status: `[E]` — DONE-PIXEL, EYEBALL OWED (§12).** The item and its fix-up were
both written claiming *"no eyeball owed"*; **both verifiers rejected that
sentence** and it is corrected here. The deliverable is a checkbox a human must
see **ticked** and a tree that **triples on screen** — `BK38`/`BK43` assert the
`-variable` and the accessor one refresh later, and no check in this batch judges
whether the `ttk::checkbutton` WIDGET renders ticked or whether 45 → 129 reads as
**explained** rather than alarming.

---

## 1. The baselines, re-measured on the UNCHANGED tree first

Both reproduced exactly before a line was written, so every red afterwards is
attributable.

| arm | baseline (17b) | measured pre-item | after item 18 | after the FIX-UP |
|---|---|---|---|---|
| headless, 15 files | **1658**, 0 fail | **1658**, 0 fail | **1662**, 0 fail | **1662**, 0 fail |
| X, 12 suites | **2230**, 12/12 | **2230**, 12/12 | **2243**, 12/12 | **2244**, 12/12 |

Per-file headless (**after**): sigsearch 146, sea 6, sigbrowser 135, 2pane 108,
panes 15, i11 50, i12 40, i1315 88, i14 56, grid 231, modes 212, viewer 57,
markers 437, tabs 56, **keys 25** (was 21). Per-suite X (**after**): panes 81,
sigbrowser 353, sea 79, i11 74, i12 126, i1315 190, i14 107, 2pane 108,
sigsearch 233, grid 356, modes 488, **keys 49** (was 35 → 48 → 49).

**The whole delta is in one file.** Item 18 added 4 headless / 13 X check calls,
all in `test_wave_sigbrowser_keys.tcl`; the fix-up added **one more X call**
(`BK43`) and **zero** headless, because `BK43` needs the Tk fixture.
`test_wave_sigbrowser_panes.tcl` restated `BW59` **in place** with no change in
call count, which is why `panes` does not move in either arm.

**Not adopted from the implementer's run.** Both arms were re-measured
independently by the fix-up's verifier: 15 headless files by hand (**1662 / 0**,
every per-file figure identical to the 17b table except `keys`) and 12/12 through
`xarm.sh suites` with `SUITE_TIMEOUT=400` on the real `:0` under the gate panel
(**2244**, sum verified by hand). It also verified the source diff mechanically —
`git diff 6c887aed 91a3de1a -- src/wave_viewer.tcl` filtered to non-comment lines
is **EMPTY**, so the fix-up's "comment only" claim is true line by line.

### 1.1 One baseline fail on the PRISTINE tree, and it is a `:0` flake

The pre-item run of `test_wave_sigbrowser_i1315` on the real `:0` failed **`BP77`**
twice (189 passed / 1 failed — check count 190, correct) while the SAME file under
Xvfb answered **190 / 0**. `BP77`'s fourth leg is a **geometry echo** ("opening
the sidebar lands on the restored 0.44 split") — exactly the class Xvfb cannot
measure and a window manager can perturb. It then **passed on `:0`** in the
post-item run (190 / 0). A WM timing flake on the pristine tree, **before item 18
existed**; recorded, not adopted. It did not reproduce for either verifier, so
the failure itself has no independent witness.

### 1.2 Whole-suite `NORESULT`s and one `TIMEOUT` — not measurements

Three whole-suite `NORESULT`s in the item's session (`i1315` + `sigsearch`
pre-item, `i12` post-item), one carrying an explicit `X connection to :0 broken`.
All re-run by hand through `xarm.sh one`, all ALL PASS at their baseline counts.
The WSLg Xwayland death is live again now the arm is on `:0`.

The fix-up round added a second shape: **`test_key_graph_context` TIMED OUT at
400 s** on the first *batched* attempt — and then ALL PASSed twice standalone in
~0.5-1 s wall. Reproduced independently by the verifier, same verdict: a
**stall**, not a slow suite, and not reachable by anything this work touches.
Both are on the LEDGER's known-flake list now.

---

## 2. ⚠⚠ THE PLAN SAYS THIS ITEM REDS NOTHING. IT REDS `BW59`.

`test_wave_sigbrowser_panes.tcl:BW59` is a `BD06`-style **file-wide bare-name
count** of the two class-box accessors, `{4 4 1 1}`. This item adds a fifth read
site of each, so it necessarily becomes **`{5 5 1 1}`**.

The PLAN's *"Existing checks it reds: **None**"* is wrong for the **third time in
this batch** — item 12 red `BW25` under the same sentence, item 17b red four
`BX` ids under it. Found by grep before the red run, restated **in place** (name
widened to "the five enumerated sites", the fifth named in the check's own
comment, legs 3 and 4 unmoved at 1/1), never deleted, and **proven live by
sabotage `S6` under X** — see §7's gap note, because the headless sweep could not
see it.

The corollary that costs sessions, inherited from item 12 §4.1 and honoured here:
**item 18 writes neither accessor's name in any comment in `src/wave_viewer.tcl`**
— a mention in prose is indistinguishable from a call site. The comments say "the
device-internals box" / "the source-currents box".

---

## 3. What the PLAN got wrong, with the measurement that says so

| PLAN said | MEASURED | consequence |
|---|---|---|
| band `BK40`-`BK47` (heading) / `BK40`-`BK49` (code block, 10 ids) | first free is **`BK32`** | took `BK32`-`BK42`. The PLAN's band predates items 16 and 17b, which spent `BK01`-`BK31`; it is also internally inconsistent (8-id heading over a 10-id block). **Third dead band in this batch.** `BK19` stays RESERVED and unspent. |
| "the four SHIPPED results still render as **`BX13`**'s four" | the four are **`BX14`** (`_i12.tcl:387-396`); `BX13` (`:366-384`) is the **guide** oracle; and there are **NINE** renderings, not four, since two-pane item 11 added `seanone`/`seaempty`/`seabars`/`seaclass`/`seacount` | `BK33` pins all nine |
| `{err {no such node}}` | the shipped literal is `{err {no signals under '<asked>'}}` (`browser_show_path`'s miss arm) | `BK39` uses the shipped text |
| example node `g:x1.xm1` / path `x1.xm1` | **absent from BOTH models** of the corpus | the band uses **`x1.x1.xm1`** — absent with the box off, present with it on, three own-level signals all `devnode`-classed |
| "`test_wave_modes.tcl` still **214**" | **212** headless / **488** X | stale by four items; re-run and reported, unmoved |
| "reds existing: **none**" | **reds `BW59`** | §2 |
| §3.3's **44 / 128** node counts | **45 / 129** | the spec counts *instances* and misses R2's design ROW — item 12 measured the same thing and the spec still says 44/128 |

### 3.1 The corpus arithmetic, re-measured before a single literal was written

`tests/headless/fixtures/tb_bandgap_vars.txt` — **424** names.

| | srccur 1 | srccur 0 |
|---|---|---|
| **devint 1** | 424 signals / **129** nodes | 374 / **129** |
| **devint 0** | 190 / **45** | 140 / **45** |

Hidden device nodes = 129 − 45 = **84**, at depths 5 / 75 / 4 (levels 2 / 3 / 4).

**`srccur` moves the node count by ZERO, and 0 of the 84 hidden nodes are
revealed by the device box only when the source-currents box is on.** That single
measurement forced the design (§4.1) and makes `S6`'s zero *behavioural* reds a
**fact** rather than a coverage hole.

---

## 4. The traps that cost real time

### 4.1 THE OBVIOUS SHAPE WOULD HAVE SWALLOWED ITS OWN FIRST SABOTAGE

"Tick, refresh, re-resolve, **untick if it failed**" has a **confirm guard** — and
a confirm guard eats the PLAN's first sabotage: force the decision to always-yes
and the guard puts the box back, so nothing reds. The guard is also **unreachable**
on this corpus (§3.1's zero), i.e. dead code no sabotage could ever exercise.

Shipped instead: **ONE decision point** — a **pure probe** that rebuilds the
would-be model in memory through the same procs the refresh uses (`signal_entry`
→ `browser_class_filter` → `browser_rows_multi` → `browser_node_for`), touches no
widget and fires no refresh, and only then invokes the checkbutton. That is what
makes `S1` bite and what keeps the seven shipped miss-arm checks green.
`S1b` measures the rejected shape rather than merely asserting it: with a confirm
guard the refresh count goes **1 → 3**, and *only* the refresh count can see it.

### 4.2 ⚠ `BW59` LIVES IN AN X-ONLY BLOCK, AND THE SABOTAGE SWEEP RAN `panes` HEADLESS

`_panes.tcl` is 15 checks headless and **81 under X**; `BW59` is in the X-only
half. The whole first sabotage sweep therefore **could not see the restated
oracle at all**. `S6` and `S5` were re-run with `panes` **under X**: `S6` reds
`BW59`, `S5` does not (the negative control). Without that second pass `S6` would
have been reported as a one-red sabotage and the restated check would have
shipped never proven live.

### 4.3 ⚠ THE `.ph` QUESTION HAD TO BE MEASURED BEFORE A CHECK COULD ASSERT IT

The scout brief offered a DEFER on `BK37` in case R12's sentence needed the
status widget moved. Measured instead: `browser_status` writes
`"Signal Browser\n$msg"` to `<top>.wvbrowser.ph` and `browser_say` calls it on
**every** branch, while `browser_sea_refresh` writes `$f.pw.sea.st` and **never**
`.ph` (its own header says so). So the new sentence already lands there, `BK37`
asserts it **byte-exact**, and the twelve `.ph` byte-identity pins carried in from
item 12 are untouched. **No defer needed** — recorded because the alternative was
a spec-scale change on a widget item 18 does not own.

### 4.4 THE FIX-UP'S SABOTAGE DRIVER HAD AN OUTPUT-FILTER BUG, FIXED MID-RUN

Recorded because it nearly cost a false reading. The driver's first cut parsed the
check count out of `RESULT: ALL PASS (N checks)` — which a **failing** run does
not print — so `V1`'s genuine *"49 checks, 1 fail, `BK43` alone"* was first
reported as `NORESULT RED`. The result was verified by hand from the saved log
before being believed, and the filter retargeted at the authoritative
`<suite>: <p> passed, <f> failed` line (then fixed again for suite names
containing digits, which had turned `2pane`'s real 108/0 into a second phantom
`NORESULT`). Both were **driver** defects, never suite failures — the
"a crashed suite must count red, but a mis-parse must not be mistaken for a
crash" hazard, in the direction that produces false alarm rather than false green.

---

## 5. What landed

### 5.1 Source (`src/wave_viewer.tcl`) — three edits, plus one comment in the fix-up

| proc | edit |
|---|---|
| `browser_msg` | ONE arm — `unhidden { return "showing device internals to reach [lindex $res 2]" }` |
| `browser_say` | ONE arm — `unhidden { set r [list unhidden $a $b] }` |
| `browser_show_path` | the R12 **pure probe** between the walk and the shipped improve-or-restore, one `variable browserraw`, one return arm at the tail |
| `browser_show_path` (**fix-up**) | a **COMMENT ONLY** at the decision point (`:9890`), turning §9's declared limit into a pointer at `BK43`. Zero behaviour change, proven by `git diff` and by both arms. |

The arm merges into `$id`/`$matched` and lets the **shipped** decode at the tail
run once, for both `ok` and `unhidden` — which is what keeps `TP44` (`browser_id_path`
in this body **== 1**) green, and `S5` proves that is live rather than lucky.

Measured source counts, before → after:

| grep | before | after |
|---|---|---|
| `browser_devint` file-wide | 4 | **5** |
| `browser_srccur` file-wide | 4 | **5** |
| `browser_devint` / `browser_srccur` inside `browser_refresh` | 1 / 1 | 1 / 1 |
| `browser_alldbs` file-wide | 2 | 2 |
| `opt.dev` file-wide | 2 | **3** |
| `device internals to reach` file-wide (all inside `browser_msg`) | 0 | **1** |
| `browser_id_path` / `browser_refresh` / `sch_path` in `browser_show_path` | 1 / 2 / 0 | 1 / 2 / 0 |
| `return ` in `browser_msg` | 9 | **10** |
| `unhidden` in `browser_say` | 0 | **2** |

All four frozen bare-name counts were **re-grepped again after the fix-up's
comment** (5 / 5 / 2 / 1, every occurrence confirmed a real code line), and
`BK34`/`BK35` — which read proc bodies with comments stripped by `wvproc_body` —
stayed green in both arms.

### 5.2 Tests

* `tests/headless/test_wave_sigbrowser_keys.tcl` — **`BK32`-`BK42`** (eleven ids,
  thirteen calls; headless 21 → **25**, X 35 → **48**), then the fix-up's
  **`BK43`** (one id, one call, **X only**; X 48 → **49**, headless unchanged).
* `tests/headless/test_wave_sigbrowser_panes.tcl` — **`BW59` restated in place**,
  `{4 4 1 1}` → `{5 5 1 1}`. No change in call count, so neither arm moves.

Bookkeeping the fix-up restated, code untouched: the file header band
`BK32`-`BK42` → `BK32`-`BK43` (`BK43` flagged as the fix-up), `NEXT FREE IN THIS
FILE: BK43` → **`BK44`**, the X-block heading `BK36`-`BK42` → `BK36`-`BK43`, and
the load-bearing skip banner `SKIPPED: BK36-BK42 (Tk/X arm only)` →
`SKIPPED: BK36-BK43 (Tk/X arm only)`. **The banner's wording — the
`(Tk/X arm only)` suffix a reader greps for — is preserved exactly**; only the
range moved.

---

## 6. The checks

**Both arms:** `BK32` the new rendering, PURE (**measured red pre-state:
`g:x1.x1.xm1`**) · `BK33` all NINE shipped renderings byte-unchanged **+ the
formatter's return count 9 → 10** as the moving leg · `BK34` the ONE-FORMATTER
oracle, four legs, **the only witness to `S3`** · `BK35` `TP44`'s twin kept local,
five legs (3 frozen + 2 that move).

**X only:** `BK36` (fixture) · `BK36` (R12 itself) · `BK37` (`.ph`, byte-exact) ·
`BK38` (R12's last sentence + item 13's reveal contract) · `BK39` (the dual pair) ·
`BK40` (the bars control) · `BK41` (one refresh, then zero) · `BK42`
(improve-or-restore) · `BK42` (teardown) · **`BK43`** (the fix-up's
full-resolution rule, §14).

### 6.1 ⚠⚠ THE RED RUN FOUND THREE VACUOUS CHECKS AND ALL THREE WERE REWRITTEN

First red run under X: **8 red, 40 green** — but `BK39`, `BK40` and `BK42`
**passed before a line of item 18 existed**. All three asserted only *shipped*
behaviour ("the box did not move", "the retry restored everything"), which is
exactly what **no code** produces. That is item 12's hollow shape (`BW63`/`BW65`),
and this batch has now caught it twice on the red run and only on the red run.

| check | what was vacuous | moving leg added, in the SAME tuple |
|---|---|---|
| `BK39` | "the box did not move" on an unresolvable path | the SAME call on `x1.x1.xm1`, which MUST tick — so the `0` is a **decision**, not inertia |
| `BK40` | the bars-active hedge still refusing | clear the bar and ask for a real hidden node: it ticks after all |
| `BK42` | "the retry restored everything" | after the restore, the R12 probe must still see a hidden node **through the restored inventory** |

Second red run: **11 red, 37 green.** The only two greens are `BK36 (FIXTURE)` and
`BK42 (TEARDOWN)` — declared fixture/hygiene assertions, not item claims; a
fixture check that went red *before* the item would be a broken fixture.

### 6.2 `BK43` IS NOT VACUOUS, AND THAT IS MEASURED RATHER THAN ARGUED

`BK43` pins behaviour that already shipped, so it is green on the pristine tree by
construction. The real question is whether it can go red **for a reason connected
to the item** — and it does, three times: `V1` (the exact relaxation the finding
named) reds it **alone**; `V0` (the whole R12 arm off, the "before item 18" proxy)
reds it because legs 5-7 assert the unhidden result, the ticked box and the
129-node tree that only item 18 produces; and the verifier's own `MY1` reds it on
a third axis. Every expected literal was measured on the pristine tree **before**
the check was written, by a throw-away probe (deliberately not named `test_*.tcl`,
deleted afterwards, `git status tests/headless/` clean).

**The absence half alone (legs 1-4: box 0, tree 45) WOULD have been vacuous** — it
is exactly the shape §6.1 caught twice. It is paired with the moving half in the
**same tuple** for that reason, so the `0` in leg 2 is a decision rather than
inertia.

### 6.3 Every existing check restated, and why — nothing deleted, nothing renumbered

* **`BW59`** (`_panes.tcl`) `{4 4 1 1}` → **`{5 5 1 1}`**: this item adds a fifth
  read site of each class-box accessor, so the count MUST move. Name widened to
  "the five enumerated sites", the fifth named in the check's own comment, legs 3
  and 4 unmoved at 1/1. **Proven live by `S6` under X** (§4.2).
* **The fix-up restated only bookkeeping**, byte-listed in §5.2: the file's band
  header, `NEXT FREE`, the X-block heading and the skip banner's range. `BK32`-`BK42`
  are **byte-unchanged** — the verifier diffed the id histogram at `6c887aed`
  against `HEAD` to confirm it.
* **§9 limit 1 restated in place** in this receipt: the sentence "the alternative
  is one comparison away and nothing downstream moves" was true of the TESTS as
  well, and now says so and points at `BK43`.
* **Everything else the scout listed was re-grepped and confirmed unmoved:**
  `BD06` (2), `TP44` (1/0), `BX09` (0/0), `BX13`, `BX14`, `BW15` (`{0 1}`), the
  twelve `.ph` byte-identity pins (`BD52`, `BX37`, `BX42`, `BX44`-`BX46`, `BH50`,
  `BH51`, `BH54`), `GH0`/`GH2`/`GH4`/`GH8`/`GH9`, `GS0`-`GS3`, `BT08`/`BT09`,
  `BS01`/`BS02`, `BP07`, `BP02`, `BP10`/`BP13`/`BP41`-`BP45`, `MG9`, `BW24`,
  `BW25`, `BW60`/`BW61`/`BW63`/`BW67`.
* **The seven shipped checks that drive `browser_show_path` into a MISS**
  (`BX34`/`BX35`/`BX37`/`BX42`/`BX45`/`BX46`/`BX52`) are **green by design, not by
  luck**: their fixtures are all `net`-classed, so the devint-1 model is
  byte-identical to the devint-0 one, the pure probe answers "no", and the shipped
  path runs untouched. Confirmed by `_i12` **126 / 0** under X.
* **`GS0`-`GS3` keep item 19's job intact:** item 18 mints **no new proc**, so the
  spec's contract roster does not move.

---

## 7. Sabotages — ten injected, ten fired, every one reverted byte-exact

Driver (both rounds): `flock`/lock dir, `EXIT`/`INT`/`TERM` trap restoring from a
**byte-exact backup** (the item was uncommitted — `git checkout --` would have
deleted it), an **anchor pre-count asserted before every patch**, proof the
mutation reached disk (`cmp` / on-disk `md5`), `md5` **and** `diff` verified on
every restore, and a filter that counts **`NORESULT`/`TIMEOUT` as red** and
compares the **CHECK COUNT** as well as the fail count. **No count moved anywhere
in either sweep**, so nothing was vacuous through an early abort.

### 7.1 The item's own seven

| # | sabotage | failed EXACTLY on target? | reds | positive control (stayed GREEN) | reverted |
|---|---|---|---|---|---|
| `S1` | tick on ANY miss (`$pmatched == …` → `1`) | ✅ | `BK39` `BK40` `BK42` | **`BK36` `BK37` `BK38` `BK41`** — the real R12 case still works. A dual pair, not a smoke test. | ✅ `diff` clean |
| `S1b` | probe forced yes **+ a confirm guard that unticks** | ✅ | `BK39` — refresh count **1 → 3**, measured | `BK40` green: the guard put the box back, which is *precisely* why the guard is REFUSED — only the refresh count can see it | ✅ |
| `S2` | untick after revealing | ✅ | `BK36` `BK38` `BK39` `BK40` `BK41` `BK42` | **`BK37`** — the sentence is right and the state is wrong. Exactly the pair R12's last sentence needs. | ✅ |
| `S3` | compose the sentence inline (arm removed from `browser_msg`, hand-written `browser_status`) | ✅ | `BK32` `BK33` `BK34`, both arms | **`BK37` green — `.ph` is byte-identical.** Only the pure formatter and the source oracle see the drift; this is why `BK34` leg 2 is not optional. | ✅ |
| `S4` | refresh twice | ✅ | `BK41` (X), `BK35` leg 2 (2 → **3**, both arms) | everything else green — nothing *visible* changes | ✅ |
| `S5` | decode the path in the new arm | ✅, across TWO files | **`TP44` (`_2pane`) AND `BK35`** — two files, one cause | `_i12` 40, `_panes` X **81 / 0** — `BW59` unmoved, the negative control for `S6` | ✅ |
| `S6` | probe hardcodes the source-currents scope | ✅ **only after `panes` was re-run under X** (§4.2) | `BK35` leg 5, **and `BW59` under X** | **ZERO behavioural reds — a MEASURED FACT, not a hole:** 0 of the 84 hidden nodes are revealed by the device box only when source currents are on. Two source oracles catch it; no check was invented for an unreachable state. | ✅ |

### 7.2 The fix-up's three

| # | mutation | failed EXACTLY? | reds | positive control | reverted |
|---|---|---|---|---|---|
| `V1` | the finding's own relaxation: `$pmatched == [llength $segs]` → `$pmatched > $matched` | ✅ **`BK43` alone** | keys X **49 checks, 1 fail** (count held → no early abort). Observed value is exactly the damage measured: `{partial g:x1.x1.xm1 x1.x1.xm1 x1.x1.xm1.zznosuch}` `1` `129`, sentence *"no signals under 'x1.x1.xm1.zznosuch' - showing x1.x1.xm1 instead"*, no mention of device internals | keys headless 25/0, 2pane 108/0, panes 15/0 unmoved; `BK36`-`BK42` green | ✅ `md5`+`diff` |
| `V0` | the same guard → `0` (the R12 arm off — the *"before item 18"* proxy) | ✅ on a SET, by design | `BK36`-`BK43`, 49 checks held, 8 fail. Legs 5-7 read `partial g:x1.x1 x1.x1 x1.x1.xm1` / `0` / `45` — **the proof that `BK43`'s positive half is a MOVING leg, not inertia** | headless keys 25/0 (the group is X-only), 2pane 108/0, panes 15/0 | ✅ |
| `V2` | bypass the checkbutton's `-command` (behaviourally **invisible**) | ✅ **`BK35` alone**, in BOTH arms (X 49/1, headless 25/1) | the driver-bites control: it also proves the driver really mutated the file the suites loaded | 2pane 108/0, panes 15/0 unmoved; **`BK43` stays GREEN** — the correct instrument split (invisible ⇒ source oracle, visible ⇒ behavioural check) | ✅ |

### 7.3 THE VERIFIER'S OWN UNNAMED SABOTAGE — `MY1`, "reveal, but never say so"

All three fix-up sabotages aim at the **guard**. `MY1` aims at R12's **last
clause**: `src/wave_viewer.tcl:9898`, `set r12 1` → `set r12 0` in the merge, so
the box still ticks and the tree still grows to 129 and the node is revealed and
selected — but the tail returns a plain `ok` and `browser_say` never renders the
*"showing device internals to reach …"* sentence. A genuinely plausible regression
(someone simplifying `browser_msg`'s kinds) that is behaviourally near-invisible
except in the returned kind and one status line.

**Result: 7 of the item's 8 X checks red** — `BK36` `BK37` `BK39` `BK40` `BK41`
`BK42` `BK43`, **check count held at 49** so nothing aborted early. **`BK38`
correctly stayed green**: it asserts only that the box is still ticked one refresh
later, which is still true. Headless keys 25/0, 2pane 108/0, panes 15/0 unmoved;
restored from a byte-exact backup, `md5` OK and `diff` clean.

**Conclusion: no coverage hole on the "say so" axis, and `BK43`'s positive half is
a moving leg under a sabotage nobody on the implementing side named.**

### 7.4 THE BEFORE-PROOF — the hole was real and total, measured not believed

To test *"before `BK43` this red NOTHING"* rather than take it, the verifier
extracted `test_wave_sigbrowser_keys.tcl` **at `6c887aed`** (48 checks, pre-repair)
into a probe deliberately **not** named `test_*.tcl` (so `full_audit`'s glob
cannot see it) and ran it under X twice:

* pristine source → **48 passed / 0 failed**
* with the **identical `V1` mutation on disk** → **48 passed / 0 failed**

Zero reds either way. The repaired file at 49 checks reds `BK43` alone under the
same mutation. Probe deleted, verified gone, tree byte-clean.

---

## 8. Divergences — recorded, not overturned

1. **§8.2 says "PREFIX the status message"; the shipped sentence REPLACES it.** A
   prefix would render *"showing device internals to reach x1.x1.xm1 - showing
   x1.x1.xm1"* — the sentence already names the node. Adopted the PLAN's
   complete-sentence literal. **One-word spec correction handed to item 19.**
2. **§7.4 says the auto-tick "IS logged. One keystroke, one log line." MEASURED:
   the R11(a) checkbox path contains no `log_action`** — `wviewer::log_action` has
   15 call sites and the checkbutton at `:7180-7186` is not one of them.
   `browser_toggle`, which §7.4 names, is the **sidebar show/hide**, a different
   control. Routing through the widget's own `invoke` satisfies the ruling's
   actual content (the same path a user's click takes, logged if and when that
   path is); inventing a bespoke `log_action` here would be new scope on a surface
   item 18 does not own. **Recorded, not invented.** Handed to item 19.
3. **`BK40`'s premise is unreachable as the PLAN states it.** The PLAN calls it
   "a node hidden by the SEARCH BAR"; since two-pane item 10 the tree's node set
   is bar-**unfiltered** (§7.1), so a bar cannot hide a NODE at all. What `BK40`
   pins instead is that the bars-active **hedge** still fires and still does not
   tick.
4. **`.ph` needs no move** (§4.3) — the scout brief's DEFER was declined on a
   measurement, not on a preference.
5. **Item 13's ruling honoured, not re-litigated:** the reveal goes through
   `browser_reveal`, which opens the ancestor chain and leaves the target CLOSED;
   `BK38`'s last three legs assert exactly that.
6. **The fix-up shipped a NEW CHECK ID (`BK43`), where the finding suggested "one
   leg on the existing X fixture".** A leg bolted onto `BK36` or `BK39` would fire
   a second `browser_show_path` inside a tuple whose comment already explains a
   *different* precondition, and a fail would then name the wrong claim. `BK43`
   sits on the same toplevel, the same token, the same 424-name corpus and the
   same `bk_seed` pre-state, so the cost is one check **call** (X 48 → 49) rather
   than one leg. Band measured before use: `BK43` was recorded NEXT FREE in three
   places and a grep over `tests/` and `doc/claude/` found no other user.
7. **The fix-up touched `src/wave_viewer.tcl`, which a pure test-only repair would
   not.** It is a **comment only** — zero behaviour change, confirmed by `git diff`
   by both sides and by both arms — because the finding's actual complaint was
   that a future defensive edit ("surely a deeper landing is still an
   improvement") would ship green, and *a comment at the decision point is what a
   future editor reads*. Written to name **no** accessor (§5.1).
8. **The driver's output-filter bug, fixed mid-run** — §4.4. Reported rather than
   smoothed, because it produced a false `NORESULT` twice.
9. **The output schema's baseline text ("headless 1618", "X 11/11") is stale by
   five items and was NOT measured against.** The live contract is this LEDGER's
   15 files / **1662** headless and 12 suites / **2244** X.
10. **The fix-up's "the three out-of-baseline suites cannot be count-verified" was
    itself WRONG, and the correction is measured** — see §9 limit 5 and §14.

---

## 9. Declared limits

1. **FULL RESOLUTION ONLY.** A path whose devint-1 model resolves *deeper* but
   still not fully (e.g. `x1.x1.xm1.zznosuch`: 3 of 4 segments with the box on,
   2 of 4 with it off) leaves the box **unticked** and reports the shipped
   `partial` at the shallower landing. Chosen because `unhidden`'s sentence says
   *"to reach `<node>`"*, which a partial makes a lie, and because it keeps the
   absence control unambiguous.
   **⚠ THIS WAS THE ITEM'S ONE UNPINNED DECISION POINT.** As shipped, "the
   alternative is one comparison away and nothing downstream moves" was true of
   the **tests** as well: relaxing it red **nothing** in either arm. **Closed by
   the fix-up — it is now `BK43`** (§14), and the source comment at the decision
   point points at it.
2. **THE PROBE IS CURRENT-DB ONLY.** It builds a single-group model from
   `browsersigs($token)`, so under All-DBs a hidden node in a **foreign**
   inventory answers "no" and the shipped path runs. Conservative by construction
   — the probe can only under-report, never tick wrongly — and the fixture has no
   foreign DB to exercise it. **Still declared-and-unchecked**; `BK43` pins ONE
   shape of the rule (deeper-but-partial on the CURRENT db). Closing it was out of
   the fix-up's scope.
3. **The Search/Filter bars are still NAMED, never CLEARED** on a miss — the
   shipped limit, inherited unchanged.
4. **Spec §9's live note is real and correct.** A ticked box makes `browser_state`
   non-default, so `snapshot` begins emitting a `browser` key it did not emit
   before. `MG9` pins the *snapshot's* key list and `browser` is a value inside it,
   so it is unaffected — re-measured, `test_wave_modes` **212 headless / 488 X,
   unmoved**. The mitigation is fixture hygiene, not code: item 18's X block owns
   `wvbk18` end to end and tears it down, and `BK42 (TEARDOWN)` asserts that as a
   value.
5. **`BK43` is X-ONLY.** The decision point lives inside `browser_show_path`,
   which needs the Tk tree and the 424-name fixture, so headless cannot see it and
   the headless total stays 1662. A headless **source** oracle regexping the `==`
   was considered and **rejected**: the relaxation is loudly visible in values
   (box, tree size, landing node, sentence), so the behavioural check is the
   correct instrument and a source oracle would have been a weaker duplicate.
   Source oracles remain the instrument for the *invisible* claim — that is
   `BK35`, unchanged and proven to bite by `V2`.
6. **~~The three out-of-baseline X-only suites cannot be count-verified.~~
   WITHDRAWN — MEASURED.** True only of the `RESULT:` line: `test_bindings_file`,
   `test_keybindings_help` and `test_key_graph_context` all end with a bare
   `puts "RESULT: ALL PASS"` and no count. But `xarm.sh one` prints one `ok:` line
   per check, and counting them gives **exactly 13 / 17 / 70**. The verifier ran
   all three and got those numbers, so the LEDGER's figures are correct and
   confirmable. The over-claim was in the conservative direction (it under-claimed
   verification) and blocked nothing, but item 19 must not inherit a false
   "unverifiable" belief.
7. **`BP77` on `:0` is a declared flake with no independent witness to the
   failure** (§1.1). It needs a window manager, it is out of both arms' baselines,
   and nothing in this item can reach it.

---

## 10. The two arms — final

**Headless — 1662 / 0** over the same 15 files (baseline 1658). Only
`test_wave_sigbrowser_keys` moved, **21 → 25**; the fix-up moved it by **zero**.
Every other per-file figure byte-identical (§1).

**X — 2244** over the same 12 suites (baseline 2230), through `xarm.sh suites`
with `SUITE_TIMEOUT=400` on the real `:0` under the gate panel (control file read
`RUN`; the panel was raised by `xarm.sh` itself; `GUI_GATE` never touched). Only
`test_wave_sigbrowser_keys` moved, **35 → 48 → 49**.

**The three out-of-baseline X-only suites, by hand:** `test_bindings_file`
**13**, `test_keybindings_help` **17**, `test_key_graph_context` **70** — all ALL
PASS, byte-stable, counts confirmed by counting `ok:` lines (§9 limit 6). This
item touches no C and no csv. The `test_key_graph_context` **TIMEOUT** on the
batched first attempt is the stall of §1.2, not a fail.

---

## 11. Files touched

```
src/wave_viewer.tcl                           (browser_msg, browser_say, browser_show_path
                                               + the fix-up's comment at the decision point)
tests/headless/test_wave_sigbrowser_keys.tcl  (band header + BK32-BK42, then BK43)
tests/headless/test_wave_sigbrowser_panes.tcl (BW59 restated {4 4 1 1} -> {5 5 1 1})
doc/claude/signal_browser_2pane_batch/LEDGER.md
doc/claude/signal_browser_2pane_batch/18_receipt.md
```

Commits `6c887aed` and `91a3de1a`, both **unpushed**. The verifier confirmed the
working tree is byte-identical to `HEAD` (`md5` of `src/wave_viewer.tcl` and the
keys test both match `git show HEAD:`), with no tracked modifications and no
droppings in `tests/headless` (300 `.tcl`, no `zz*`).

---

## 12. Eyeball — **OWED**. `[E]`, never `[x]`.

Both the item and its fix-up shipped a "NONE OWED" sentence; **both verifiers
rejected it**, and this section replaces it. Every *machine-checkable* half is now
genuinely covered — `BK37` pins the `.ph` line byte-exactly and `BK43` pins the
box, the tree size and the shipped `partial` wording at the shallower landing — so
what remains is **one look**, not a coverage gap.

**Script.**

1. Load a raw with device internals present (`tb_bandgap`-class), open the Signal
   Browser, leave **Show device internals OFF**. Note the tree size: **45** rows.
2. Select a **MOSFET instance** on the schematic — one whose own-level signals are
   `devnode`-classed — and press **Ctrl+Alt+V**.
3. Judge three things **at once**:
   * the **checkbox renders visibly ticked**. This is the widget, not the
     variable — `BK38`/`BK43` can only see the `-variable` and the accessor one
     refresh later.
   * the tree grew to **129** rows, scrolled the target in, selected it, and left
     its expander **CLOSED** (item 13's ruling).
   * the status line reads *"showing device internals to reach `<path>`"*, and the
     tripling therefore reads as **explained, not alarming**. That legibility
     judgement is the whole reason this item is `[E]`.
4. Now ask for a path that is **deeper but still partial** — `<that instance>.zznosuch`.
   The box must stay **UNTICKED**, the tree stay at **45**, and the sentence be
   the shipped *"no signals under '…' - showing … instead"*. This is §9 limit 1
   with fingers on it.
5. Click the expander by hand: it must still open normally.

**A `net`-classed instance answers nothing** — with no hidden device node the
probe correctly answers "no" and the shipped path runs, which is exactly the state
the seven pre-existing miss-arm checks already cover (§6.3).

---

## 13. Owed to item 19 (and to whoever comes next)

* **§8.2's "prefix" → "sentence"** (one word).
* **§7.4's "is logged"** describes a path with **no `log_action`** (§8 divergence 2).
* **§3.3's 44 / 128 → 45 / 129** — it counts instances, missing R2's design ROW.
  Item 12 owed this one too and it is **still open**.
* `browser_msg` now has **TEN** kinds, not the five §7.2 knows about.
* **`.ph`'s class-filter blindness of the COUNT line is unchanged** and still
  belongs to §7.2's three-state caption. Item 18 measured that its own sentence
  needs no widget move (§4.3); nobody else may move `.ph`.
* **NEXT FREE in `test_wave_sigbrowser_keys.tcl`: `BK44`.** `BK19` stays RESERVED
  and unspent (item 16's file band).
* **`BK29` leg 3 / `BK31` legs 3-5 pin `[llength [xschem bindings dump]]` at 72.**
  Inherited from item 17b: any future item that adds or removes ANY C binding reds
  this file. Item 18 did not meet it (no C, no csv); item 19 might.
* **A pre-existing ambiguity, NOT this item's doing, worth one line of item 19's
  bookkeeping pass:** five ids in the keys file each carry **two** check calls —
  `BK14`, `BK15`, `BK18` (item 16) and `BK36`, `BK42` (item 18). Byte-identical
  before and after the fix-up (the id histogram was diffed), and it is the file's
  established arm-paired / fixture-plus-claim convention. But a FAIL line naming
  `BK42` is ambiguous between the improve-or-restore control and the teardown —
  under `MY1` the verifier had to read the values to tell which fired. `BK43` is a
  single call and does not add to the pattern.
* **One doc inconsistency to settle:** the LEDGER's item-18 entry asserts the
  three out-of-baseline suites are **13 / 17 / 70**, and §9 limit 6 above now
  agrees after measurement. Any remaining copy of the fix-up's "unconfirmed"
  wording elsewhere should be restated to match. Nothing in either arm depends on
  it.
* **Expect the `:0` stalls.** `test_key_graph_context` TIMED OUT at 400 s on a
  batched first attempt for two independent runners and ALL PASSed standalone in
  ~1 s every time. Re-run before calling it a fail.

---

## 14. FIX-UP (`91a3de1a`) — the verifier's finding: the ONE decision point was UNPINNED

**The finding, restated honestly, and accepted in full — no part of it was argued
down.** §9's limit 1 was written down in the source, in this receipt, and
**nowhere a test could see**. Changing `src/wave_viewer.tcl:9890`'s
`if {$pmatched == [llength $segs]}` to `if {$pmatched > $matched}` — "tick on any
improvement" — passed **every** check in both arms with every count held. Measured
consequence, not inferred: on `x1.x1.xm1.zznosuch` the box flips **0 → 1**, the
tree grows **45 → 129**, and the returned result is a plain `partial g:x1.x1.xm1
…` whose sentence reads *"no signals under 'x1.x1.xm1.zznosuch' - showing
x1.x1.xm1 instead"* with **no mention of device internals** — the silent,
unexplained tree-tripling R12's last sentence exists to prevent. The zero-red
result was reproduced by the fix-up's implementer before fixing it, and proven
**total** by the verifier's before-proof (§7.4).

**What landed — ONE check, `BK43`, X-only, on item 18's own `wvbk18` fixture:**

```
BK43 (X, THE FULL-RESOLUTION RULE)  tests/headless/test_wave_sigbrowser_keys.tcl
  legs 1-4  x1.x1.xm1.zznosuch   (2 of 4 segments hidden, 3 of 4 shown -
                                  DEEPER, never FULL)
                              ->  {partial g:x1.x1 x1.x1 x1.x1.xm1.zznosuch}
                                  box 0, tree 45 nodes, and `.ph` byte-exactly
                                  "Signal Browser\nno signals under
                                   'x1.x1.xm1.zznosuch' - showing x1.x1 instead"
  legs 5-7  x1.x1.xm1  on the SAME fixture moments later
                              ->  {unhidden g:x1.x1.xm1 x1.x1.xm1}, box 1,
                                  tree 129 nodes
```

* **A dual pair in ONE tuple**, for §6.1's reason. Legs 5-7 are the **moving**
  half; §6.2 measures that rather than asserting it.
* **Every literal re-measured on the pristine tree**, not copied from the finding:
  **45 / 129**, not the PLAN's 44/128.
* **Behavioural, not a source oracle, on purpose** — §9 limit 5.
* **Leg 4 READS `.ph`, it does not MOVE it.** The twelve byte-identity pins are
  untouched; §7.2's three-state caption still owns that widget's future.
* **`src/wave_viewer.tcl` gains a COMMENT ONLY**, naming no accessor (§5.1, §8
  divergence 7).

**Sabotage-verified three ways by the implementer** (`V1`, `V0`, `V2` — §7.2)
**and a fourth by the verifier on an axis nobody aimed at** (`MY1` — §7.3). All
four restored `md5` + `diff` verified.

**Arms after the fix-up:** headless **1662 / 0** over the same 15 files (every
per-file figure identical — `BK43` is X-only, so `keys` stays at **25**);
X **12/12 = 2244**, only `keys` **48 → 49**. Both re-measured independently.

**The verifier's remaining remarks, for the record.**

* **The EYEBALL is owed and is NOT closed by this fix-up** — §12. The item is
  `[E]`.
* **`BP77` on `:0`** did not reproduce for either verifier; it stays recorded as a
  flake with no independent witness to the failure itself (§1.1).
* **`13 / 17 / 70` IS confirmable** by counting `ok:` lines, so the fix-up's
  contrary declared limit is **withdrawn** (§9 limit 6).
* **`test_key_graph_context`'s 400 s TIMEOUT** was reproduced independently, with
  the same verdict: a stall of the recorded WSLg/`:0` class, not a regression
  (§1.2).
