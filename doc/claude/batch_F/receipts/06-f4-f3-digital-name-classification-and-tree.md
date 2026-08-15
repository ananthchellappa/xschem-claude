# Batch F item 06 — F4 + F3: the digital signal class, and a digital DB in the tree

**Spec:** `doc/claude/specs/mixed_signal_signal_browser.md` §F rows F3 and F4.
**Branch:** `fluid-editing`. **Base HEAD:** `7ff1be9d` (item 5's second commit).
**Date:** 2026-08-10. **THIS IS THE RE-RUN.** The first attempt was halted by the
driver mid-flight — not for being wrong, but because the display it was measuring
against had silently become a 640x480 stub (issue **0310**). Every GUI number it
reported was therefore taken on a different machine.

**Display, verified BEFORE anything else and again after the audit:**

```
xwininfo -root | awk '/Width|Height/'   ->  Width: 5120   Height: 1440    (real desktop)
xwininfo -root -tree | grep -- '+-327'  ->  (nothing)                     (no parked windows)
```

`DISPLAY=:0`, `GUI_GATE=1` throughout; every suite through
`tests/headless/run_suites.sh` or `tests/headless/gated_xschem.sh`. The panel was
not launched, killed, re-armed or written to. Nothing pushed, nothing staged,
nothing committed — tree left dirty for the verifier.

**VERDICT: `[E]` — eyeball pending.** See §9. The engine half is measured and
sabotage-backed on a display now proven real, but F3's payload is *what a tree
and a pane read like on screen*, and no check can verdict that.

---

## 1. WHAT I SALVAGED VERSUS WHAT I REWROTE

The halted attempt left uncommitted work in five files. I read the whole diff
before touching anything and treated it as a colleague's interrupted branch.

| what it left | my verdict |
|---|---|
| `src/wave_viewer.tcl` — the whole RULING F4 implementation (`db_is_digital`, the optional `dbtype` on `sig_split`/`signal_entry`, `browser_label`'s digital arm, `browser_label_of_db`, `browser_curtype`, the `type` key on both per-DB dicts, six call sites told which database they mean) | **SALVAGED WHOLE, byte-for-byte, md5 `c0246185…`.** Independently re-reviewed (§3) and independently re-sabotaged (§7). I found no defect in it and changed not one character. |
| `tests/headless/test_wave_sigbrowser_digital.tcl` — `fd_mkvcd_m` and checks `FD30`-`FD47` | **SALVAGED, and EXTENDED by one check.** Added `FD48` (§6.1); folded a duplicated pane helper into one; corrected two stale band comments (`FD10-FD46`, `FD40-FD46`) that stopped short of the file's own last check; re-ran every check pre-feature and re-sabotaged all of them. |
| `doc/claude/specs/mixed_signal_signal_browser.md` — RULING F4/F3 | **SALVAGED, with two corrections REWRITTEN** (§2.4): a stale check band, and the two issues' disposition. |
| `doc/claude/specs/waveform_signal_browser.md`, `…_two_pane.md` | **SALVAGED unchanged.** Their claims verified against source (§3) and their bullet ledger re-counted (§3.1). |
| `doc/claude/batch_F/receipts/06-…md` | **REWRITTEN from scratch** — this file. Its sabotage table contained a FALSE row (§7.1) and its suite results were taken on the stub display. |

**Nothing was `git checkout`-ed away.** The one thing I deleted is described in
§7.1: not code, but a claim.

---

## 2. THE RULING (F4) — digital names get their own class, `digital`

Written into `doc/claude/specs/mixed_signal_signal_browser.md` §F as
**"F4/F3 — the digital signal class and the tree"**, and into the two places the
class enumeration already lived: `waveform_signal_browser.md` (the `sig_class` /
`sig_split` / `signal_entry` contract lines) and
`waveform_signal_browser_two_pane.md` §3.2 (the class table).

`class` gains a fifth value, `digital`, for every name out of a database whose
`sim_type` is `vcd`. Such a name is **never declassed**.

### 2.1 The evidence that decided it — MEASURED, not argued

`sig_declass` strips a leading device-class tag, and its own ⚠ block gives the
justification exactly: *SPICE requires subcircuit instances to begin with `X`, so
a one-letter segment cannot be one.*

**A VCD is not SPICE.** Verilog places no such rule on a module name, so
`$scope module m` is legal VCD and legal Verilog and the name that comes out is
`m.sub.sig`. Re-measured by me on the healthy display, through the real procs:

| | reused as an ngspice name (shipped) | ruled `digital` (now) |
|---|---|---|
| `class` | `devnode` | `digital` |
| `path` | `sub` — **the `m` level deleted** | `m.sub` |
| label | `sig:i` — a wire drawn as a current | `sig` |
| bus bit `m.sub.count[3]` | `count:3` — **index eaten** out of the brackets | `count[3]` |
| in the tree at the DEFAULT box state | **absent**; `time` alone in the tree | present |

The last row closes the question. `devnode` is exactly what Ruling B's
`Show device internals` box hides **by default**, so reuse does not merely
mislabel a digital signal — **it deletes it from the browser**, silently, on a
default browser, for a file the user just loaded.

Every claim is kept as a VALUE, not prose: `FD36b` is the tombstone for the
shipped reading, and `FD31`/`FD33`/`FD35` carry the analog twin of each claim in
the same tuple.

### 2.2 Which 0217 rulings the choice depends on — stated explicitly

* **Ruling A (`signal_entry` gains a `class` field) — DEPENDS ON, extends.** The
  answer is a fifth *value* of that field. Without Ruling A there is nowhere to
  record it and every consumer would re-derive "digital or not" from the name —
  the second-parser hazard Ruling A exists to prevent. **`FD31c` pins that the key
  SET does not move** (`class leaf name path type`), so `SB10` is untouched.
  Oracle: **S15**.
* **Ruling B (device internals hidden by default, behind a toggle) — DEPENDS ON,
  and is why reuse fails.** `sig_is_device digital` is 0, and neither of R11's two
  boxes narrows a digital inventory in any of their four states. `FD32`/`FD37`.
  Oracles: **S3** (which also reds ten of item 5's own checks — §7.2).
* **"The two panes RELOCATE the noise rather than delete it" (44 → 128) —
  DEPENDS ON, as the boundary not to cross.** That redistribution is about
  *analog* noise and is untouched: every analog class, path, label, node set and
  box behaviour is byte-identical (`FD32b`, `FD33b`, `FD35`, `FD36b`, plus the
  live control `FD42b` reading the analog raw in the same tree). A digital DB
  arrives as its own registry slot under its own header, so its scopes are rows
  *beside* the analog ones, never mixed into the 128. What the ruling forbids is
  *deleting* rows — which is precisely what reuse did.

### 2.3 Two sub-rulings taken deliberately

* **The class follows the DATABASE, not the name.** `TOP.counter.clk` splits
  identically under both readings and is still `digital` (`FD31b`). Classing only
  the names that would otherwise be mangled would make the class a
  bug-workaround, and every consumer asking "is this digital?" would really be
  asking "would this have been mangled?".
* **`type` stays `other`.** `sig_type` is the one classifier behind the
  Voltage/Current dropdowns and reads the leading `v(`/`i(`, which a VCD name has
  not. A fourth dropdown value is a decision about a *visible control* and is not
  taken here. This is *why* `browser_label`'s digital arm tests `class` first:
  the shipped `class eq net && type ne i` test would drop every digital name into
  the current formatter.

### 2.4 What I REWROTE in the halted attempt's spec text

1. **A stale check band.** It said *"Pinned by the **FD30-FD46** band … (24
   checks — 16 in the both-arms block, 8 on the real viewer)"*. The file it was
   describing actually ended at `FD47` with 25 checks (16 + 9) — the author added
   `FD47` late, after S7 reddened nothing, and never came back to the sentence.
   With my `FD48` it is **FD30-FD48, 26 checks, 16 + 10**, and the sentence now
   says so and adds the sabotage count.
2. **The two issues' disposition**, which the attempt recorded only as a passing
   mention. Both are now ruled on explicitly, in the spec and in §5 below.

---

## 3. F3 — what was measured, and my independent re-review of the code

`db_label` **needed no change**, confirmed as a VALUE and not by reading
(`FD38`, oracle **S13**): a VCD reads `counter.vcd (vcd)`, distinct from
`tb_ase.raw (tran)` beside it, keeping the space-and-bracket that stops
`browser_node_for` reading it as a hierarchy segment, and its design root comes
from its own file name (`counter`). The `vcd` string is the engine's own —
`my_strdup(_ALLOC_ID_, &raw->sim_type, "vcd")`, **`src/vcd_read.c:831`**, verified
at source, and DECISION C6 at `src/vcd_read.c:132` says it is deliberate.

`signal_list_all` **was already right**, verified at source: `src/wave_viewer.tcl`
around `:2182` already puts `type [dict get $db type]` on every slot's dict and
already feeds it to `db_label`. What did not exist was that value *inside the
browser*: `browser_reload` built `browsercurdb` and `browserdbsigs` without it,
so nothing downstream could tell a VCD from a raw. **That single missing key is
the whole mechanism.**

**The grouping did NOT "read well" and F3 was not "mostly free"** (§2.1). The
spec row's own note said *"Mostly free. Verify, don't assume."* — it is now
marked with the correction.

### 3.1 What I checked in the salvaged code that the attempt did not write down

* **Every `signal_entry` / `sig_split` call site in the tree**, not just the
  changed ones. Three remain one-argument, and all three are harmless or declared:
  `signal_list` (`:2065`) — its `class` field is read by **nobody**; both its
  consumers (`browser_reload` `:9014`, the Add-Trace dialog `:14069`) take
  `dict get $e name` and discard the rest. `browser_target_path` (`:8506`) and the
  sea variant (`:10221`) are the declared limit in §8.
* **The three readers of the `class` key** — `browser_class_filter` (`:6744`),
  `browser_device_paths` (`:6781`), `browser_label` (`:6924`). All three are fed
  from entries built with a `dbtype` on every browser path.
* **`browser_curtype`'s degradation direction.** Unknown token, absent snapshot
  and a thrown `signal_list_all` all answer `{}` = analog. **S2** is the proof
  this matters (§7.2).
* **The `BD06` landmine.** `grep -o browser_alldbs | wc -l` = **2**, so the
  comment rewording the attempt made is intact. `browser_devint` 5,
  `browser_srccur` 5 — both unchanged.
* **Whether `browser_curtype` can go STALE**, since it reads a snapshot and
  `browser_refresh $token 0` does not retake one. I chased every way the current
  database can change and found no hazard: `rawbar_load` ends in
  `browser_refresh $token 1` (`:7615`); `browser_toggle`'s show arm does the same
  (`:11155`); `ase::attach_dbs` ends by switching to slot 0, the analog raw
  (`src/ase.tcl:1492`); and the remaining three `xschem raw switch` sites
  (`:2173`/`:2191`, `:3476`, `src/ase.tcl:1787`/`:1796`) are switch-and-switch-back
  loans that restore the slot they found. No product path leaves the current DB
  changed without a reload. Recorded because it is the obvious next question and
  the answer is not visible from the diff.
* **`GS23`'s exact-57 ledger, counted rather than assumed.**
  `grep -cE '^- \`wviewer::[a-z0-9_]+\`' doc/claude/specs/waveform_signal_browser.md`
  = **57**, no duplicates — the three amended bullets added none.

---

## 4. The change

`src/wave_viewer.tcl` — **salvaged unmodified**, line numbers re-verified by me
against the tree:

| what | where |
|---|---|
| **NEW** `wviewer::db_is_digital {dbtype}` — PURE; the one test, `-nocase` on the engine's own `sim_type` | `:1951` |
| `wviewer::sig_split {name {dbtype {}}}` — skips the declass step for a digital DB | `:1995` |
| `wviewer::signal_entry {name {dbtype {}}}` — class `digital`, no declass | `:2023` |
| `wviewer::sig_is_device` — UNCHANGED code; ⚠ block saying `digital` must never be folded in | `:6712` |
| `wviewer::browser_label` — a `class eq digital` arm, **ahead of** the `net` test | `:6924` |
| **NEW** `wviewer::browser_label_of_db {dbtype name}`; `browser_label_of {name}` delegates, signature unchanged | `:6975`, `:6978` |
| `wviewer::browser_sea_refresh` — the pane's entries told the current DB's kind | `:8149` |
| `wviewer::browser_sea_own` — the own-level count told the current DB's kind | `:8195` |
| `wviewer::browser_reload` — a `type` key on BOTH per-DB dicts | `:9038` |
| **NEW** `wviewer::browser_curtype {token}` — THE one read of the current DB's kind, out of the snapshot | `:9105` |
| `wviewer::browser_match` — the matcher key curried with the current DB's kind | `:9172` |
| `wviewer::browser_refresh` — one `curtype` for the current inventory, one `dbtype` per foreign DB, used for BOTH the key and the classifier | `:9274`, `:9414` |
| `wviewer::browser_show_path` — the device-hint arm told the kind | `:10645` |

Nothing in C changed. `cd src && make` → *"Nothing to be done for 'all'."*

### 4.1 Two shape decisions worth naming

* **`dbtype` is an OPTIONAL trailing parameter defaulting to analog**, so every
  existing one-argument call site and the whole shipped `DC`/`SB`/`TP` band keeps
  its exact meaning by construction. `FD35` asserts the one-argument form is
  byte-identical on two shipped fixtures.
* **`browser_label_of` was NOT re-signatured.** `sig_match` invokes `-key` as a
  command PREFIX, so the DB kind must be curried in *front* — hence a second proc
  rather than a fourth argument. `SM29`, `SM30` and `BD57`'s negative control stay
  byte-identical. Restating five checks for a fact none of them is about would
  have been the worse trade.
* ⚠ **`plot_signals`' signature was NOT touched**, so `BM05`'s literal-string pin
  and both four-parameter spies in `test_wave_sigbrowser.tcl` are untouched.

---

## 5. Issues 0308 and 0309 — ruled on, plainly

**Neither is a blocker for F3. Both are DEFERRED, and both now carry a reason.**

* **0308 (the lower pane cannot read a foreign database).** F3's subject is the
  TREE, and the tree half works completely — `FD42` reads `m`, `m.sub`, the wire
  and the bus bit out of the foreign VCD's own subtree in the live treeview, and
  `FD43` reaches them through the Search bar. The pane is a different surface with
  a different reader, and what 0308 needs is a per-ROW inventory reader in
  `browser_sea_refresh`; RULING F4 cannot supply that, because the classification
  on that path is already correct. **Deferred — but promoted from a claim to a
  measurement**: `FD48` (§6.1) pins it, issue 0308 now carries the re-measurement
  and names `FD48` and **S17** as its oracle and its future restatement.
* **0309 (a `partial` landing that ticked the All-DBs box says so nowhere).** A
  defect of `browser_show_db_scope`'s outcome *sentence* — item 5's F1 territory —
  with no bearing on classification or grouping. Its own filed text says the fix
  is not a one-liner (a twelfth `browser_msg` kind plus a third restatement of
  `BK33`'s moving `return`-count leg); taking it here would be the
  neighbouring-code fix this item was told not to take. **Deferred.**
  ⚠ Recorded in the issue because RULING F4 changes its odds: before the ruling a
  VCD's scopes were `devnode` and therefore absent from the tree at the default
  box state, so *every* digital walk landed short and took the `partial` arm.
  `FD41` now asserts `ok` rather than `partial` on a walk into `m.sub` with device
  internals still hidden. The Search/Filter route its reproducer uses is untouched.

---

## 6. Checks

**Band: `FD30`-`FD48`, 26 checks**, in
`tests/headless/test_wave_sigbrowser_digital.tcl`. Band re-measured by me, not
taken from the receipt: `grep -ho 'FD[0-9]\+[a-z]*' tests/headless/*.tcl | sort -u`
shows the highest pre-existing real id is `FD27` (`FD29` occurs only inside a band
*comment*), and `test_ase_cosim.tcl`'s only `FD` ids are `FD19`/`FD19b`/`FD23`,
which are cross-references. `FD30`+ is free. **No existing check was renumbered,
deleted or restated.**

* **16 in the BOTH-ARMS block** (`FD30`-`FD39`, above the X gate).
* **10 on the REAL VIEWER** (`FD40`-`FD48`, Tk/X): three real databases attached
  through the product's own `ase::attach_dbs`; the product's own
  `browser_show_db_scope` walking into the single-letter-top VCD **with device
  internals hidden**; the rows in the real treeview; the Search bar on a foreign
  digital inventory; issue 0308's tombstone; and the whole thing again with the
  **VCD as the CURRENT database**, the only path that reaches the lower pane.

### 6.1 The one check I added — `FD48`

The scope told me to decide whether 0308 blocks F3 and to say so. Prose is not
evidence in this batch, so the answer is a check. `FD48` selects the foreign
digital scope `m.sub` by hand, with the analog raw current, and asserts in one
tuple:

```
leg 1  the row d:2|s:m.sub.sig IS in the tree              -> 1
leg 2  the lower pane's drawn labels                       -> {}   (nothing)
leg 3  the pane's caption   "m.sub has no signals of its own"      <-- FALSE, 0308
leg 4  browser_sea_own m.sub                               -> 0
```

Leg 1 is its positive evidence and is what stops it being a check that merely
restates shipped behaviour — it is **false on a pristine tree** (the `devnode`
rows are not there to select), so `FD48` fails pre-feature like the other 23.

### 6.2 Counts

| suite arm | before this item | after |
|---|---|---|
| `test_wave_sigbrowser_digital`, X arm | 25 | **51 ALL PASS** |
| `test_wave_sigbrowser_digital`, `--nogui` | 3 | **19 ALL PASS** |

### 6.3 The checks were run BEFORE the code worked

`src/wave_viewer.tcl` was swapped for `git show HEAD:src/wave_viewer.tcl` and the
band run against it on the healthy display:

```
RESULT: 24 FAILED (27 passed)
```

**24 of the 26 new checks fail on a tree without the ruling.** The two that do
not, and why, honestly:

* `FD38` (`db_label`) — a **confirmation** pin by design; F3's instruction was
  *"if they already agree, prove it with checks that would fail if they did not"*.
  Oracle **S13**, which reds it alone.
* `FD36b` (the tombstone) — asserts the *shipped analog reading*, which the ruling
  deliberately does not change. Oracles **S1**, **S2**, **S14**.

---

## 7. Sabotage — SEVENTEEN, all re-run on the healthy display

Every sabotage applied to a copy of the byte-exact backup by a scripted patcher
that **exits non-zero if its anchor is not found exactly once** (a sabotage that
did not apply must never be reported as "reddened nothing"). Restored from the
same backup after each; `md5sum src/wave_viewer.tcl` = `c0246185…` verified after
the campaign. Never `git checkout --`.

| # | sabotage | reds |
|---|---|---|
| S1 | `db_is_digital` always answers NO | FD30 31 31b 32 33 34 34b 35 36 36b 37 41 42 43 44 45 46 47 48 (19) |
| S2 | `db_is_digital` always answers YES (the guessed-yes direction) | FD30 31 31b 32 33 33b 34 34b 35 36b (10) — **and 22 analog checks in two other suites**, §7.2 |
| S3 | `sig_is_device` folds `digital` in (Ruling B hides digital) | FD32 36 37 41 42 43 45 46 47 48 **plus ten of item 5's own** FD13 14 15 16 17 19 21 23 24 25 (20) |
| S4 | `browser_label`'s digital arm deleted | FD33 34 34b 43 45 47 |
| S5 | `browser_reload`'s FOREIGN dict loses `type` | FD39 40 41 42 43 48 |
| S6 | `browser_reload`'s CURRENT dict loses `type` | FD39 40 42b 44 45 46 47 |
| S7 | `browser_match` reverts to the bare un-curried key | **FD47 only** |
| S8 | All-DBs loop stops telling `signal_entry` the DB kind | FD41 42 43 48 |
| S9 | `browser_sea_own` stops telling it | FD44 46 |
| S10 | `browser_sea_refresh` stops telling it | **FD45 only** |
| S11 | `sig_split` ignores `dbtype`, always declasses | FD31 35 36 41 42 44 45 46 48 |
| S12 | current-DB entries stop being told the DB kind | FD45 46 47 |
| S13 | `db_label` drops the analysis suffix | **FD38 only** |
| S14 | `sig_declass` never strips | FD31 32 33 33b 34 34b 35 36b |
| S15 | `signal_entry`'s digital arm grows a SIXTH key | **FD31c only** |
| S16 | `browser_class_filter`'s both-boxes-ON fast path silently drops `srcbranch` | **FD32b only** |
| S17 | the lower pane starts reading FOREIGN databases (the shape of 0308's fix) | **FD48** plus item 5's FD19 21 23 24 26 |

**Union = all 26 new checks. No check in the band is hollow.**

### 7.1 A FALSE ROW IN THE HALTED ATTEMPT'S TABLE, found by re-running it

The attempt's table claimed *"S16 | `browser_class_filter` drops `srcbranch` with
both boxes ON | reds `FD32b`"*. **It reds nothing.** I re-ran it and got
`ALL PASS (51 checks)`.

The cause is one line the attempt never read:

```tcl
proc wviewer::browser_class_filter {entries devint srccur} {
  if {$devint && $srccur} { return $entries }      ;# <-- the fast path
```

`FD32b` calls it with `1 1`, which **returns before the loop**. The attempt's
sabotage patched the loop body, so the call under test never reached it. That
left `FD32b` — the control that makes `FD32`'s short list mean "the filter
worked" rather than "the fixture was short" — with **no oracle at all**, in a
table that asserted every check had one.

Rewritten: S16 now sabotages the **fast path itself**, and reds `FD32b` and
nothing else. The general lesson, recorded in the patcher: *a sabotage that does
not red is a bug in the sabotage until proven otherwise.*

### 7.2 What S2, S3 and S17 prove that no positive check could

* **S2** is the "guess digital" direction, and it is why `browser_curtype`
  degrades to analog. Re-run across three *analog* suites on the healthy display
  it reds **50 further checks** — `DC17`-`DC28`/`SB07`/`SM30` in
  `test_wave_sigsearch`, twenty `TP` checks in `test_wave_sigbrowser_2pane`, and
  `BD58` in `test_wave_sigbrowser_i14`; the run is quoted in §10.5 — a wrong
  guess in that direction puts `m`, `v` and `@m` back at the top of the tree,
  i.e. **undoes issue 0217**. Guessing analog costs a digital name its class on a
  browser that has no snapshot to draw anyway.
* **S3** reds **ten of item 5's own checks**. Folding `digital` into
  `sig_is_device` does not merely hide a row — it removes the scope F1's whole
  Ctrl-Alt-V branch navigates to. Items 5 and 6 are load-bearing on each other
  and now say so.
* **S17** reds `FD48` **and five of item 5's notice checks** (`FD19`, `FD21`,
  `FD23`, `FD24`, `FD26`). That is the measured evidence for issue 0308's own
  closing line — fixing the pane retires RULING F1e's arm, which must then be
  DELETED rather than left saying something no longer true. It is now recorded in
  0308 instead of being rediscovered by whoever takes it.

---

## 8. Declared limits — stated, not discovered

* **The lower pane still lists only the CURRENT database** — issue **0308**,
  pinned by `FD48`, deferred with the reason in §5.
* **Issue 0309** — deferred with the reason in §5; RULING F4 makes it rarer, not
  fixed.
* **`browser_target_path` / `browser_sea_target_path` are NOT digital-aware.**
  Both resolve a leaf through `sig_split(name)` with no database in hand
  (`:8506`, `:10221`), so on a single-letter-scope VCD they answer the declassed
  path while the tree's group id says otherwise. Descending from a VCD scope into
  a schematic is meaningless anyway, and both already carry a filed defect for
  foreign All-DBs rows (work-order §4 item 5). **Deliberately not fixed** — the
  neighbouring-code fix the item was told not to take.
* **`wviewer::signal_list` still classifies the current DB's names as analog**
  (`:2065`). Harmless today and verified so (§3.1): **no consumer reads its
  `class` field**, both take `name` and discard the rest. A future consumer that
  reads it would need the same `dbtype`.
* **No "hide digital internals" control.** A VCD carries every RTL net. A third
  checkbox is a product decision about a visible control.
* **`type` stays `other` for digital names** (§2.3).
* **The three new procs are not in `waveform_signal_browser.md`'s contract list**
  — `GS23` pins its length as an exact ledger (57); adding names is a separate
  edit with its own check to move. Recorded in the mixed-signal spec instead. The
  three bullets I amended add no bullet; `test_wave_grid` is green (§10).
* **`db_is_digital` keys on the string `vcd`.** A second digital reader with a
  different `sim_type` widens this one proc — which is why it exists at all
  rather than being spelled inline in six places.

---

## 9. Verdict: `[E]`, and exactly what to look at

The engine half is `[x]`-grade: 26 checks, 17 sabotages, every check red under at
least one, the product's own commands driven against a real viewer on a display
proven real. But **F3's payload is what a tree and a pane READ LIKE**, and that is
pixels. Three things a human should look at, in order:

1. **Attach a run with a VCD, tick All DBs, look at the tree.** Expect the analog
   raw's header and the VCD's `counter.vcd (vcd)` header side by side, each with
   its own design root, the VCD's `$scope` levels nested under it.
   *The question only an eye can answer:* does `counter.vcd (vcd)` → `counter` →
   `TOP` → `counter` read as sensible, or as a stutter? The design root is the
   file name and the second `counter` is the instance; both are honest and both
   spell the same word. If it reads badly the fix is a `browser_root_label` ruling
   for digital DBs — deliberately **not** invented here.
2. **Select a digital scope with the VCD as the CURRENT database.** The lower pane
   should list `sig`, `count`, `count[0..3]` — bare, no `:i`, no `count:3`.
3. **Load a VCD whose top scope is one letter** and confirm its wires are in the
   tree with `Show device internals` at its default. This is the defect the item
   exists to remove and the one a user would report as "my signals are missing".

Interleaving is *structurally* checked (`FD42`/`FD42b` read both databases' rows
out of the same live tree), but "reads well" is not a predicate.

---

## 10. Audit — a DIFF against the baseline, by test NAME and STATUS

Baseline: `doc/claude/batch_F/baseline_status.txt` (it exists; HEAD `7a592f9c`,
`DISPLAY=:0`, 306 audit tests + 58 wireedit = 365 rows,
**277 PASS / 26 FAIL / 0 CRASH / 2 TIMEOUT / 1 SKIP**).

**A full `full_audit.sh` was run for this item on the verified-healthy display** —
the thing the halted attempt could not do, and the reason it was halted.

```
SUMMARY: 279 pass  22 fail  2 crash/timeout  4 skip  (total 307)
WIREEDIT: ALL PASS          (58/58)
SCRATCH:  0 leaked dir(s)
```

307 vs the baseline's 306 because `test_wave_sigbrowser_digital` did not exist at
`7a592f9c` — item 5 created it. **The red count is not the verdict.** Eleven rows
moved, and every one is named below.

### 10.1 RED → GREEN (6) — these count too, and are explained

| test | baseline | now |
|---|---|---|
| `test_ase_persist` | FAIL | PASS |
| `test_fluid_bodyshove_guards_0132` | FAIL | PASS |
| `test_wave_axis_zoom` | FAIL | PASS |
| `test_wave_crossdb_trace` | FAIL | PASS |
| `test_wave_sigbrowser_i12` | FAIL | PASS |
| `test_wire_vertex_grab` | FAIL | PASS |

All six are in the batch's **resolved-noise** population — item 5's salvage pass
proved the green↔red churn on these rows environmental (X-server deaths and the
WSLg key-delivery flake) and the driver's brief says not to re-litigate them. Two
of them (`test_wave_crossdb_trace`, `test_wave_sigbrowser_i12`) are wave-browser
suites and would be the ones to worry about if they had moved the other way; they
did not. **Nothing in this item could turn a red row green** — its only behaviour
change is gated on a database whose `sim_type` is `vcd`, and none of these six
loads one.

### 10.2 NEW ROW (1)

| test | baseline | now |
|---|---|---|
| `test_wave_sigbrowser_digital` | *(absent — created by item 5)* | **PASS, 51 checks** |

### 10.3 GREEN → RED (5) — all five environmental, PROVEN not asserted

| test | baseline | now | verdict |
|---|---|---|---|
| `test_cadence_stretch_move` | PASS | SKIP | X hiccup |
| `test_fluid_backbone_short_vertical_0098` | PASS | SKIP | X hiccup |
| `test_rotate_stretch_reconnect_0100` | PASS | SKIP | X hiccup |
| `test_altf5_ciw` | PASS | FAIL | key-delivery flake |
| `test_remap` | PASS | FAIL | key-delivery flake |

**The three SKIPs.** All three self-skip on *"no viewable X window"* and print
`RESULT: SKIP (no X)`, which `full_audit`'s `is_skip` scores as SKIP. That is the
WSLg Xwayland wobble, and it is the one symptom that looks like issue 0310, so I
re-ran the display checks the moment I saw it: still `5120x1440`, still zero
`+-327` windows, `xdpyinfo` agreeing. **All three then passed twice each** on
re-run. The audit's 4 SKIPs are the baseline's 1 (`test_rotate_stretch_dangling_0103`,
still SKIP) plus these 3.

**`test_altf5_ciw`** — one line, *"FAIL - rebound Alt-F5 raises CIW again"*.
**PASS twice on re-run.**

**`test_remap`** — the only row I could not dismiss on a first pass, so it got the
full treatment.

* Its failure signature is `z0=1 z1=1`, i.e. the zoom never changed: the key was
  never delivered. It drives everything with a bare
  `event generate .drw <Shift-Key-Z>` — the exact idiom of the batch's named
  key-delivery flake.
* **Block-design A/B was MISLEADING and I am recording that honestly.** Run in
  blocks, my tree failed 4/26 and the pristine tree 0/34 — an asymmetry I was not
  willing to wave away.
* **Interleaved A/B, alternating single runs to remove the time-window drift that
  makes WSLg flakes cluster: 0/8 on BOTH trees.** The block asymmetry was an
  ordering artefact.
* **The decisive evidence is not statistical.** I instrumented the changed code —
  a marker-file probe at the top of `signal_entry`, `browser_refresh` and
  `db_is_digital` — and ran `test_remap` three times:

```
marker hits during 3x test_remap                : 0
marker hits during 1x test_wave_sigbrowser_digital (positive control) : 110
```

  The changed code is **never executed** by `test_remap`. Its failure cannot be
  caused by this item. (`test_remap.tcl` also contains zero occurrences of
  `wviewer`, `browser`, `sigbrowser` or `raw `.) The probe was applied to a copy
  of the backup and the tree restored to md5 `c0246185…` afterwards.

### 10.4 Targeted suites, re-run green on the final tree

```
test_wave_sigbrowser_digital  51    test_wave_sigsearch          233
test_wave_sigbrowser_2pane   108    test_wave_sigbrowser_i14     107
test_wave_grid               399    test_ase_cosim               310
test_vcd_read                187    test_wave_sigbrowser_i11      74
test_wave_sigbrowser_panes    81
--nogui: test_wave_sigbrowser_digital 19, test_ase_cosim 310
```

**No check COUNT shrank anywhere** — the only witness to a file that aborted
early. `test_wave_grid` is 399 (was 397 before item 5's own additions) and
`GS23`'s exact-57 ledger holds.

### 10.5 The S2 cross-suite run, which is why `browser_curtype` degrades to analog

Sabotage **S2** (`db_is_digital` always answers YES) run against three *analog*
suites on the healthy display:

```
test_wave_sigsearch        15 FAILED  — DC17-DC28, SB07, SM30
test_wave_sigbrowser_2pane 34 FAILED  — TP05…TP43
test_wave_sigbrowser_i14    1 FAILED  — BD58
```

**50 analog checks across three suites.** A wrong guess in the "digital"
direction stops declassing a real ngspice raw and puts `m`, `v` and `@m` back at
the top of the tree — it **undoes issue 0217**. That is the measured reason
`browser_curtype` answers `{}` (= analog) for an unknown token, an absent
snapshot or a thrown `signal_list_all`, and the reason the comment at the site
says so.

---

## 11. Files touched

| file | what |
|---|---|
| `src/wave_viewer.tcl` | the ruling's implementation — **salvaged unmodified** from the halted attempt |
| `tests/headless/test_wave_sigbrowser_digital.tcl` | `FD30`-`FD48`, 26 checks + `fd_mkvcd_m`; `FD48` and a helper fold are mine |
| `doc/claude/specs/mixed_signal_signal_browser.md` | RULING F4 + RULING F3, rows F3/F4 closed; band corrected, 0308/0309 ruled |
| `doc/claude/specs/waveform_signal_browser.md` | three contract lines amended, no bullets added (`GS23`) |
| `doc/claude/specs/waveform_signal_browser_two_pane.md` | the `digital` row in the §3.2 class table |
| `doc/claude/issues/0308-…md` | re-measurement, the `FD48` pin, the S17 oracle — **still OPEN** |
| `doc/claude/issues/0309-…md` | reviewed, deferred, reachability note — **still OPEN** |
| `doc/claude/batch_F/receipts/06-…md` | this file, rewritten |

**Provenance, checked rather than assumed.** The first five files were **already
dirty when the item started** — that is exactly the halted attempt's uncommitted
work, and §1 says what I kept and what I rewrote in each. The two issue files
were **clean**: both were committed at `7ff1be9d` (item 5's second commit), and
the changes now showing against them are mine alone (`git diff --stat HEAD --
doc/claude/issues/` = 58 insertions, 0 deletions — I appended and deleted
nothing). The receipt is untracked and is a full rewrite.

`doc/claude/batch_F/LEDGER.md` was **not** touched — the driver owns it. Nothing
staged, nothing committed, nothing pushed. No scratch droppings in the repo: the
suite writes only under `test_scratch`, and the backups, the pristine copy and
the sabotage patcher live in the session scratchpad.

## 12. How to re-run

```sh
export DISPLAY=:0 GUI_GATE=1
xwininfo -root | awk '/Width|Height/'        # 5120x1440, NOT 640x480
xwininfo -root -tree | grep -- '+-327'       # must print nothing

tests/headless/run_suites.sh          test_wave_sigbrowser_digital   # 51, ALL PASS
tests/headless/run_suites.sh --nogui  test_wave_sigbrowser_digital   # 19, ALL PASS
tests/headless/run_suites.sh test_wave_sigsearch test_wave_sigbrowser_2pane \
  test_wave_sigbrowser_i14 test_wave_grid test_ase_cosim test_vcd_read
```

---

# ROUND 2 — THE FIX PASS (review round, 2026-08-10)

Written by the **fixer**, who did not write the code above and did not review it.
Six findings were confirmed by independent reviewers against the tree the
implementer left (`src/wave_viewer.tcl` md5 `c0246185`). All six are about the
same root cause family: **RULING F4 admitted a case-sensitive, non-SPICE
namespace into machinery that had only ever been given ngspice names**, and four
places downstream were never told.

## R1. The findings, and what happened to each

Every one was **reproduced as a value before it was touched** — no fix was made
to appease a claim. Reproducers are pure `tclsh` against the product's own procs.

| # | Finding | Verdict | Fix |
|---|---------|---------|-----|
| 1 | `browser_level_names` / `browser_sea_own` fold case, merging two legal sibling VCD scopes | **REAL** — reproduced: `top.mod` and `top.MOD` each answered BOTH names, own-count 2 each | RULING **F4c** — compare case-sensitively when the ENTRY's class is `digital` |
| 2 | `browser_sea_target_path` declasses, so `Descend to here` is ENABLED and silently no-ops | **REAL** — reproduced: `ok sub` for a tree whose group is `g:m.sub` | thread the current DB's kind; and **say** so when a resolved path has no row |
| 3 | a digital bus bit's label `count[0]` is unsearchable (brackets read as a glob class) | **REAL, and PRE-EXISTING for analog** — see R2 | RULING **F4b** — exact whole-subject arm AFTER the glob |
| 4 | `browser_target_path` not digital-aware: group and its own child disagree, multi-select falsely refused | **REAL** — reproduced: group `ok m.sub`, leaf `ok sub`, both `err` | RULING **F4d** — resolve the leaf with **that row's own** database kind |
| 5 | the `⚠` comment's "MEASURED on `TOP.counter.count[3]`" is false for that name | **REAL** — that name classes `net` and renders `count[3]` on BOTH paths | comment only: exemplar corrected to `m.sub.count[3]` |
| 6 | duplicate of #4 (same two resolvers, raised by a second lens) | **REAL** | same fix as #4 |

## R2. Where I did NOT do what a reviewer prescribed, and why

**Finding 3's prescribed fix — "quote glob metacharacters in the subject/pattern"
— is not implementable.** Measured, not argued:

```
$ tclsh scratchpad/fix/quote.tcl
SM07 pattern *net_name[[]* over QUOTED subjects:
   ->      (SM07 demands: v(net_name[3]))
```

Quoting the subject reds **SM07**, whose entire subject is that `[[]` is the
escape for a literal `[`. Quoting the pattern destroys every wildcard. `SM06`
(bracket range) and `SM19` (a lone `[` is a no-match) are pinned the same way.

Two further facts that change what the finding is:

* **The wart pre-dates this item.** An ngspice design net `v(x1.count[3])` has
  drawn the label `count[3]` since two-pane item 20 shipped, and typing it has
  never matched. RULING F4 makes it the *majority* case for a digital database;
  it does not create it. FD53 leg 6 pins the analog half.
* So the fix is a **superset**, not a semantic change: the glob is tried first
  and unchanged, an exact whole-subject equality second. The match set can only
  grow. SM06/SM07/SM19 all still pass (verified, R4).

**Finding 4's prescribed fix — "pass `browser_curtype` into both `sig_split`
calls" — is right for the pane and WRONG for the tree**, and that is measured
too. The tree holds several databases at once, so the question is per-ROW.
Sabotage **T6** forces the current kind at that site:

```
FD51 -> ... {ok m.x1.xm1} ...   (expected {ok x1.xm1})
```

i.e. with a VCD current, a **foreign ngspice raw's** device leaf would stop being
declassed — the mirror of the very defect being fixed. So the tree got a new pure
resolver `browser_id_type {token id}` (row id → that database's `sim_type`, out
of the snapshot `browser_reload` already takes, degrading to analog for an
unknown row). The **lower pane** genuinely has no such question — it draws the
current database's entries and only those — so it is told the current kind
directly, exactly as prescribed.

## R3. Checks

**8 new checks**, band `FD49`–`FD55` (`FD49 FD50 FD51 FD52 FD52b FD53` pure /
both-arms, `FD54 FD55` real-viewer). File total **59** GUI arm / **25** `--nogui`
arm (was 51 / 19).

**All 6 pure checks fail on the pre-fix tree**, with exactly the values the
reviewers reported:

```
$ tclsh scratchpad/fix/pureband.tcl scratchpad/fix/pre/wave_viewer.tcl.ITEM06
FAIL: FD49 -> {{top.mod.a top.MOD.b} {top.mod.a top.MOD.b} {...}}
FAIL: FD50 -> {2 2 2 2}                        (exp {1 1 2 2})
FAIL: FD51 -> {{ok m.sub} {ok sub} {err {those rows are in different parts of the hierarchy}} ... ERR:invalid command name "::wviewer::browser_id_type" ...}
FAIL: FD52 -> {{ok sub} {ok sub} {ok x1.xm1}}
FAIL: FD52b -> {0 0}                           (exp {1 0})
FAIL: FD53 -> {{} ... {}}                      (the drawn label finds nothing, both digital and analog)
PURE-BAND RESULT: 19 pass / 6 fail
```

## R4. Neighbouring suites the fix's SUBJECT reaches

`sig_match`, `browser_level_names`, `browser_sea_own`, `browser_target_path` and
`browser_sea_target_path` are all read by other suites. Their **pure** bands were
replayed in bare `tclsh` against the fixed tree (no binary, no display, no gate):

| band | result |
|------|--------|
| `test_wave_sigsearch` SM/ST/SB (the matcher) | **85 pass / 0 fail** — incl. `SM06`, `SM07`, `SM19`, `SM29`, `SM30` |
| `test_wave_sigbrowser_2pane` TP13–TP19 (the case rule + labels) | **pass** — incl. `TP16` both legs |
| `test_wave_sigbrowser_i11` BH05–BH08 + `2pane` TP43 (`browser_target_path`) | **9 pass / 0 fail** — incl. every `d:N|`-prefixed form, with no DB snapshot present (the degrade-to-analog path) |

## R5. Sabotage — 11 on the pure half

Applied by a patcher that **exits 9 unless its anchor occurs exactly once**
(`scratchpad/fix/patch.py`); it refused `T8`'s first anchor as a substring of a
neighbouring line, which is the mechanism working. Restored from a byte-exact
backup each time.

| # | broke | red |
|---|-------|-----|
| T1 | `browser_level_names` → unconditional `-nocase` | FD49 (digital legs) |
| T2 | `browser_level_names` → always case-SENSITIVE | FD49 (**analog control leg**) |
| T3 | `browser_sea_own` → unconditional `-nocase` | FD50 |
| T4 | `browser_target_path` → drop the dbtype argument | FD51 |
| T5 | `browser_id_type` → always the current kind | FD51 (`ok sub`, `err`, `tran`) |
| T6 | `browser_id_type` → always `vcd` | FD51 (**analog control**: `ok m.x1.xm1`) |
| T7 | `browser_sea_target_path` → drop the dbtype argument | FD52 |
| T8 | `browser_sea_target_path` → hardcode `vcd` | FD52 (analog control) |
| T9 | `browser_sea_descend_to` → remove the status call | FD52b |
| TA | `sig_match` → remove the literal arm | FD53 (legs 1, 6) |
| TB | `sig_match` → literal ONLY, drop the glob | FD53 (legs 2, 3, 4 — the glob-preserved legs) |

**T2/T6/T8/TB are the control-leg sabotages** — they exist to prove the "nothing
analog moved" legs are not decoration. Every one lands.


## R6. WHAT COULD NOT BE RUN — the GUI arm, and why

**BLOCKER, NOT A DEFECT.** The user's GUI-test control panel (pid 2670, alive,
on-screen, `pid==pgid==sid`) has been at **PAUSE since 10:27:54** and was still
PAUSE at **14:13** — nearly four hours, spanning this fixer's whole session and
the verifier's before it. Every sanctioned run path
(`tests/headless/run_suites.sh`, `tests/headless/gated_xschem.sh`) blocks at
`gate_pause_point` **by design**, so no suite and no `full_audit` could start.

I did **not** set `GUI_GATE=0`, did **not** write a bare `for … ./src/xschem`
loop, did **not** start Xvfb or any hidden display, and did **not** write into
`~/.claude/gui_test_gate/`. The gate is the user's authority over their own
screen. One `run_suites.sh --nogui` invocation was launched at 13:14, parked at
the pause point, and was killed by my own `timeout` at 13:29 with no output.

**Display was verified real** before anything: `xwininfo -root` = Width 5120 /
Height 1440, and `xwininfo -root -tree | grep -- '+-327'` found nothing. Issue
0310's stub condition was not present at any point.

### Consequently NOT PROVEN by this round

* **`FD54` and `FD55` never executed.** They are the two real-viewer checks and
  they have **no sabotage row**. Do not read their absence from a failure list as
  a pass.
* **No suite was run through the harness at all** — the digital suite's own
  59/25 counts are *derived* (25 measured in the pure replay + 8 new ids), not
  observed from a `RESULT:` line.
* **`full_audit` was not run, so there is no audit diff.** The baseline
  `doc/claude/batch_F/baseline_status.txt` **does exist** (365 rows; 277 PASS /
  26 FAIL / 2 TIMEOUT / 1 SKIP audit-only). It was not diffed. **Treat the audit
  as UNVERIFIED** — I did not invent one and did not adopt any run as a baseline.
* Neighbouring suites were reached only through their **pure** bands (R4). Their
  X arms — `BD57`/`BD58`, the `BQ` sea band, `TP` live legs — are unverified.

### What IS proven, gate-free

Everything in R1–R5: six findings reproduced as values, four fixed, one shown
un-implementable as prescribed and fixed another way, one comment corrected;
6 new pure checks that all fail pre-fix and pass post-fix; 11 sabotages each
landing on the leg it targets; 94+ neighbouring pure checks green; every frozen
source-grep oracle re-counted and unmoved (`browser_alldbs` 2, `browser_devint`
/`browser_srccur` 5/5 with 1/1 on the filter path, `GS23` 57, `BK33`'s
`browser_msg` return count 11, `TP44`'s `browser_id_path` 1/1 and
`string range` 0/0, `BM05`'s `plot_signals` signature untouched).

### For whoever re-runs this

```sh
export DISPLAY=:0 GUI_GATE=1
tests/headless/run_suites.sh          test_wave_sigbrowser_digital   # expect 59
tests/headless/run_suites.sh --nogui  test_wave_sigbrowser_digital   # expect 25
tests/headless/run_suites.sh test_wave_sigsearch test_wave_sigbrowser_2pane \
  test_wave_sigbrowser_sea test_wave_sigbrowser_i11 test_wave_sigbrowser_i14 \
  test_wave_sigbrowser_panes test_wave_sigbrowser test_wave_crossdb_trace \
  test_wave_grid test_ase_cosim test_vcd_read
```

Sabotage kit for the two unproven checks is staged in
`<scratchpad>/fix/` (`patch.py` exits 9 unless its anchor occurs exactly once;
`GOOD.tcl` md5 `f8a1659d` is the byte-exact restore point; `T1`–`TB` `.old`/
`.new` pairs). **`T4` should red `FD54`, `T7` should red `FD55`** — those are
the same two edits whose pure twins already red `FD51`/`FD52`.

## R7. Verdict

**`[E]` — eyeball pending, unchanged from round 1, and now additionally
GUI-UNVERIFIED.** The pixel payload is what the tree and the pane *read like*;
the round-1 eyeball list stands (the `counter.vcd (vcd)` → `counter` → `TOP` →
`counter` stutter, the bare digital pane, the one-letter top scope). To it add:
**the `Descend to here` entry on a digital scope** — it should now act rather
than sit enabled and do nothing, and on a scope selected together with one of its
own wires it should be enabled rather than refused.

Nothing staged, nothing committed, nothing pushed. `LEDGER.md` untouched. No repo
droppings (`tests/headless/.scratch` holds only the pre-existing `0211` dir).
