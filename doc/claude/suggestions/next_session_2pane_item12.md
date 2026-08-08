Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

Implement the **two-pane Signal Browser, item 12 — THE TWO CHECKBOXES STOP BEING
INERT**.

## READ FIRST

* `doc/claude/signal_browser_2pane_batch/PLAN.md` **§ "Item 12 — The checkboxes
  stop being inert"** (~line 912) — the scope. ⚠ **Its band and two of its
  numbers are wrong; see below. Verify every number it gives before you spend
  it.**
* The spec: `doc/claude/specs/waveform_signal_browser_two_pane.md` **R11** and
  **§6 Filters**.
* `11_receipt.md` **§9** — item 11 wrote item 12's owed list and it is accurate.
* `20_receipt.md` §4.2 and `17_receipt.md` §6 — why the sabotage driver takes a
  lock and asserts its pre-state. Reuse that driver; do not write a naive one.

⚠ **ITEM NUMBERING.** Two plans overlap. Always write `two-pane item N` or
`single-pane item N`; the rule is in both PLAN headers. This is **two-pane item
12**.

## WHERE YOU ARE

Two-pane items **0-11 and 20** are done, plus **half of 17**. Items 1-11 are
PUSHED (`14d8bdb8`); everything after is **UNPUSHED**: `258c567a` (item 20, the
label filter), `c02bfa6f` (the sea's hover tooltip), `882694cc` (item 17's
selected-instance arm), `292a4b25` (the numbering fix). **Commit when green; DO
NOT PUSH** unless told.

**Baselines to reproduce BEFORE touching anything:**

* Headless **1618**, fourteen files, zero failures: sigsearch 146, sea 6,
  sigbrowser 135, 2pane 108, panes 14, i11 50, i12 40, i1315 80, i14 47,
  grid 230, modes 212, viewer 57, markers 437, tabs 56.
* X arm **11/11**: panes 53, sigbrowser 353, sea 79, i11 74, i12 123, i1315 167,
  i14 88, 2pane 108, sigsearch 233, grid 355, modes 485.

Known flakes, NOT regressions — both pass on re-run: `BR25` (a `<Return>`
through a bare `event generate`), `MG16` (key delivery), and a whole-suite
`NORESULT` from the WSLg Xwayland death. **Re-verify the X server first**:
`timeout 15 xdpyinfo -display :0` must return 0.

## ⚠⚠ THE FIVE THINGS THAT WILL BITE

**1. THE PLAN'S BAND `BW40`-`BW49` IS ENTIRELY SPENT.** Item 10 took
**BW40-BW55**. This is the same trap the PLAN set for item 13. **Next free is
`BW56`.** Do not renumber anything existing.

**2. THE PLAN'S NODE COUNTS ARE WRONG — 44/128. MEASURED: 45/129.** It is the
same off-by-one item 11 already corrected: spec §3.3's 44 counts *instance
nodes*, and the design root (R2) is the 45th row. Re-measured just now on
`tb_bandgap_vars.txt` through the shipped pipeline:

| devint | srccur | signals | tree rows |
|---|---|---|---|
| 0 | 1 (**the shipped default**) | **190** | **45** |
| 1 | 1 | **424** | **129** |
| 0 | 0 | **140** | **45** |
| 1 | 0 | **374** | **129** |

The PLAN's four SIGNAL totals (`424 190 374 140`) do reproduce. Its node counts
do not.

**3. ⚠ `srccur` DOES NOT MOVE THE NODE COUNT — ONLY `devint` DOES.** 45 either
way, 129 either way (see the table). A node-count leg on the source-currents
toggle is **vacuously green**. Assert srccur through the SIGNAL total, and say
in the check why the node count is not part of its claim.

**4. THE BD06-STYLE FILE-WIDE GREP IS ALREADY OFF BY ONE.** `BD06`
(`test_wave_sigbrowser_i14.tcl:285`) pins the All-DBs reader as *"defined once
and called once, file-wide"* with `[regexp -all {browser_alldbs} $wsrc] 2`, and
item 10's comment warns that **even naming it in a comment reds it**. If you
write the twin for these accessors, note that `src/wave_viewer.tcl:8323` ALREADY
says:

```
  # item 12 replaces the literals with browser_devint/browser_srccur, which is
```

So a bare-name count starts at 1 for each before you write a line. Either reword
that comment as part of this item, or count the CALL SITES rather than the name.
Decide deliberately and say which in the check.

**5. THE WIDGETS ALREADY EXIST AND ARE ALREADY PACKED.** Item 9 built them inert
at `browser_build` (`src/wave_viewer.tcl:~7110`), variables
`::wviewer::browserdev($token)` / `::wviewer::browsersrc($token)`, seeded `0` and
`1` **before** the widgets so the ttk default cannot silently win. **No pinned
child-set check moves in this item** — that is the whole reason they were built
inert. If a shape check moves, stop and find out why.

## THE WORK

Two accessors modelled verbatim on `browser_alldbs` (`:8179`) — **one read site
each**, so a scoping sabotage has exactly one place to land:

```tcl
proc wviewer::browser_devint {token {want {}}}   ;# R11(a), default 0
proc wviewer::browser_srccur {token {want {}}}   ;# R11(b), default 1
```

`-command [list wviewer::browser_refresh $token]` on both checkbuttons, and
`browser_refresh` replaces item 10's hardcoded `0 1` at **exactly two sites**:

* `src/wave_viewer.tcl:8326` — `browser_class_filter $entries 0 1` (current DB)
* `src/wave_viewer.tcl:8410` — `browser_class_filter $dent 0 1` (each foreign DB
  under All-DBs)

Item 11 deliberately added no third call site — the sea is a narrowing of the
already-filtered list. **Both must move together**, for the reason item 20 found
the hard way about `browser_and`'s two callers: one policy read in one place and
not the other means the same checkbox governs one inventory and not the next.
Spec §6's "one consistent set" is the ruling.

### NOT in this item

* **Persistence is item 14.** Do not touch `browser_state`.
* **R12's auto-tick is item 18.** A hidden device node does not tick anything yet.
* **No new widgets, no re-layout.**

## WHERE THE CHECKS GO — DECIDE THIS FIRST

The PLAN says `test_wave_sigbrowser_panes.tcl` (band `BW`), which owns the
checkbutton widgets. But its fixture is the **three-name** `{v(out)
v(x1.x2.net5) v(x1.y3.net5)}`, and item 12's whole claim is the measured
arithmetic over the **424-name** corpus, which today lives only in
`test_wave_sigbrowser_sea.tcl` (band `BQ`).

**Recommended: keep it in `panes`/`BW56+` and seed the corpus there**, the same
hand-seed route the sea suite uses (`set ::wviewer::browsersigs($tok) $names`,
`fixtures/tb_bandgap_vars.txt`). The widgets and their checks stay in one file,
and the fixture cost is one `bq_slurp`-style reader. Restore the three-name
inventory afterwards — the named-helper rule — or every later BW check inherits
the corpus.

## RED first

1. The two accessors, PURE: defaults read back and **DIFFER** (`0 1`, not `0 0`);
   an unknown token answers R11's defaults rather than `{}` or a throw; a `want`
   round-trips.
2. **The four combinations are FOUR DIFFERENT signal totals** — `424 190 374
   140` — driven through the real widget variables, with the node count asserted
   only where it discriminates (see bite 3).
3. Toggling a box **re-filters without re-reading the raw**: `signal_list` is not
   called. (Item 9's D6 snapshot rule.)
4. **R5's discipline applied to the boxes**: toggling changes neither the tree's
   open set nor the selected node.
5. The All-DBs site really moved too — a foreign inventory obeys the same box.
   The `i14` fixture is the only place that is reachable; `BD57` is the model.

## Existing checks it reds — VERIFY, do not assume

The PLAN says **none**. Item 11's receipt §9 nominates two at risk: **BQ67c**
(its synthetic inventory assumes `devint 0`) and **BQ50's `190`** precondition.
Both should hold, because this item does not change the DEFAULTS — but that is a
claim to run, not to believe. `GH0`'s 11 accelerators and `GH4` do not move: a
checkbutton uses `-command`, not `bind $f.`.

## Sabotages (the PLAN's, plus two)

* Share one variable between the two boxes → the four totals collapse to two.
* Swap the defaults (`devint 1` / `srccur 0`) → the shipped 190/45 becomes
  374/129.
* Wire the current-DB site but not the All-DBs one → the foreign inventory
  disobeys its own checkbox.
* Read the box inside `browser_reload` as well → two reads, and the scope can
  differ between the inventory and the tree (BD06's argument, one item over).
* Have `-command` call `browser_reload` instead of `browser_refresh` → the raw
  is re-read on every tick.

## HOUSE RULES THAT HAVE BITTEN EVERY SESSION IN THIS BATCH

* Headless: `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>`
  from the repo ROOT; scripts end in `exit 0`.
* X arm: `tests/headless/run_suites.sh` under one **`Allow 2h`** press — never a
  bare `for` loop. `SUITE_TIMEOUT=400`. ⚠ **The gate panel dies often under
  WSLg** and once wedged a run for 34 minutes (stale `req/` entry, nothing
  running). If a run stalls, check `~/.claude/gui_test_gate/control` — it may
  simply say `PAUSE`, which is the user's authority; ask rather than override.
* **⚠⚠ NEVER EDIT `src/` WHILE THE SABOTAGE DRIVER HOLDS IT.** It backs up,
  patches, and copies the backup back; an edit in that window is silently
  discarded **and its own `diff -q` still reports "restored byte-identical"**.
  It corrupted the tree once. The driver takes a lock file, an `EXIT`/`INT`/
  `TERM` trap, and **asserts a pre-state count before patching**.
* **⚠ A sabotage driver's output filter can hide a crash.** `grep -E
  '^(PASS|FAIL|RESULT)'` is anchored, so `NORESULT |` and `TIMEOUT |` vanish and
  a crashed suite reads as zero reds. Include `NORESULT|TIMEOUT`.
* **A sabotage that mutates nothing proves nothing.** Re-read the patch you
  applied before believing a zero.
* **⚠ A SHORTFALL IN THE CHECK COUNT IS THE ONLY WITNESS TO VACUITY.** Diff the
  COUNT, never just the fail count, on every run and after every sabotage.
* **Expected literals are STRING REPS.** `[list ok [list x]]` is `ok x`, not
  `{ok {x}}`. This has cost reds on correct code three times.
* **`pcall` returns the STRING `ERR:<msg>`** — `expr` on it throws past the
  check; `lsearch` on it answers -1 and goes GREEN on a failed read. Use
  `bs_num`/`bs_set` or assertable sentinels.
* **`event generate` stamps time 0**, so two presses at one spot are a Double.
* **`bs_type` needs its focus loop**; Tk routes KEY events to the focus widget.
* **`begin {…}` is not a proc.** Named helpers, and they must RESTORE what they
  changed.
* **A check that passes before you wrote the code is a check to stop and look at.**
* Never `make` while suites run. Measure, don't reason — every line number in
  every doc has drifted at least once.

## START BY

Confirming the X server is alive, re-measuring headless **1618**, then running
the X arm on the UNCHANGED tree to confirm **11/11** — so every red after that
is yours. Then re-measure the four-combination table above yourself (one
`--nogui` script over `fixtures/tb_bandgap_vars.txt`) before you write a single
expected literal.

## AFTERWARDS

Item 12 unblocks **item 14** (persistence) and **item 18** (R12's auto-tick).
Write `12_receipt.md` in the batch directory, in the shape of `20_receipt.md`:
baselines before/after, what the PLAN got wrong with the measurement that says
so, the traps, what landed, the sabotage table, and what is still owed.
