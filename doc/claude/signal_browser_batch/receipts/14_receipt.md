# Item 14 — All DBs search — RECEIPT

**Status:** `[x]` implemented, tested, sabotage-verified.
**Files:** `src/wave_viewer.tcl` (Tcl only — NO C, decision 8 honoured; `cd src && make`
is a no-op because nothing under `src/*.c` changed),
`tests/headless/test_wave_sigbrowser_i14.tcl` (NEW).
**Checks:** 83 in the Tk/X arm, 47 in the `--nogui` arm.
**`cd src && make`:** `Nothing to be done for 'all'` — Tcl only, no `.c` touched.

---

## 1. Anchors: CITED vs ACTUAL

Every anchor re-verified from source. One drift found (harmless), one PLAN
instruction superseded, and the scout's own D5 prediction proved **false** by
measurement (see §6).

| cited | actual | ok |
|---|---|---|
| `scheduler.c:9517` — the `raw`/`raw_query` branch | `src/scheduler.c:9517` exactly | ✅ |
| `raw switch` arm at `scheduler.c:9537` | `:9537` exactly | ✅ |
| `raw info` arm at `scheduler.c:9554` | `:9554` exactly | ✅ |
| `raw list` arm at `scheduler.c:9683` | **`:9692`** — 9 lines off | ❌ (drift) |
| `xctx->extra_raw_arr[]`, `src/save.c` | declared `src/xschem.h:1804`; manipulated in `extra_rawfile()`, `src/save.c:1225` | ✅ |
| driver note (b): `raw info` enumerates | `src/save.c:1456-1465`, `what == 4`: `<extra_idx> current\n` then `<i> <rawfile> <sim_type|<NULL>>\n`. Prints **nothing** when `xctx->raw` is NULL | ✅ — the `[D]` clause does NOT fire |
| the `else if(raw && raw->values)` gate | `src/scheduler.c:9576` — `list`/`vars`/`rawfile`/`sim_type` see only the CURRENT DB | ✅ |
| `sig_match` / `signal_list` | `src/wave_viewer.tcl:1614` / `:1745` | ✅ |
| `rawbar_load` never clears | confirmed — no `raw clear`, so raws ACCUMULATE | ✅ |
| `attach_raw` is not in the history | confirmed — no `rawhist_push`, and it opens with `xschem raw clear` | ✅ |
| item 9's D6 snapshot-on-show | confirmed — `browser_reload` is only reached with `reload=1` from `browser_show` / `rawbar_load` / `browser_show_path` | ✅ |
| PLAN: "append to `test_wave_sigbrowser.tcl`" | SUPERSEDED by ruling 30; that file is frozen | ❌ (superseded) |
| issue 0213 at `src/save.c:406`, sites `:504`/`:531` | exact | ✅ |

**Decision 8 check:** `raw info` + `raw switch <n>` + `raw list` are together
sufficient. No new C, no scheduler branch, no `[D]`.

---

## 2. THE SOURCE OF TRUTH (driver note (f)'s open question)

**The ENGINE REGISTRY (`xschem raw info`), not item 13's history.** Declared, not
defaulted. The two sets genuinely differ: `rawbar_load` pushes to the history AND
leaves the previous raw in the registry, while `attach_raw` (the ASE re-run path)
pushes NOTHING. A DB the history never recorded is still a DB the user has open,
so All-DBs searches it. Consequence, stated plainly: **ASE `attach_raw` DBs ARE
searched even though they never appear in the Location bar's dropdown.**

---

## 3. WHAT SHIPPED

Six new procs, all `wviewer::`, all in `src/wave_viewer.tcl`:

| proc | kind | what |
|---|---|---|
| `rawinfo_parse {text}` | PURE | `raw info` blob → `{cur <int> dbs {{idx path type}…}}` |
| `db_label {path type}` | PURE | `bd_a.raw (tran)` — the tree header text |
| `signal_list_all {token}` | engine | every DB's inventory, CURRENT FIRST |
| `browser_alldbs {token}` | widget | **THE ONE AND ONLY** read of the checkbox |
| `browser_rows_reparent` | PURE | re-key a row list under a header |
| `browser_rows_multi` | PURE | several inventories → one row list |

Changed: `searchbar_build` (new `-alldbs 0|1`), `searchbar_get` (CONDITIONAL
`alldbs` key), `searchbar_forget`, `browser_build` (`-alldbs 1` on the TOP bar
only), `browser_reload` (fills `browserdbsigs` unconditionally),
`browser_refresh` (the one checkbox read + the grouped rows + the status
suffix), `browser_show_path` (improve-or-restore covers `browserdbsigs`),
`forget` (unsets it). New namespace arrays `browserdbsigs` and `sballdb`, both
declared at the top with the other per-token/per-widget families (the
`gridshow` lesson: an undeclared `variable` makes `unset` address a LOCAL array
and leaks one entry per closed window forever).

### Why `signal_list_all` and not a generalised `signal_list` (driver note (f))
`signal_list`'s contract is *"the current raw of this token, mutating nothing"*,
and items 8-13 all rest on it: no browser read has ever been able to move the
user's current DB. All-DBs cannot be written that way — it **must** move the
engine's current-DB pointer and put it back, which introduces a failure mode
`signal_list` does not have (a refused restore). Keeping them separate is what
stops that hazard leaking into the twelve existing call sites. `signal_list`
stays the authority for the current DB (decision 13's shipped claim).

### A deliberate improvement over the legacy parse
`xschem.tcl:4801` reads the same `raw info` blob **by word**
(`foreach {n f t} [lrange [xschem raw info] 2 end]`), so a rawfile path
containing a space shifts every field after it and the legacy listbox fills with
garbage. `rawinfo_parse` is per-LINE and anchored, and gets that case right —
pinned by **BD13**. The legacy call site is untouched (not this item's scope).

### `BAR11` tripwire, respected
`tests/headless/test_wave_sigsearch.tcl:1181` pins `searchbar_get` to the EXACT
four-key dict. The `alldbs` key is therefore **conditional** — emitted only by a
bar built with `-alldbs 1` — and every consumer reads it with
`wviewer::dget $d alldbs 0`. BD41b asserts the Filter bar emits no key at all.

---

## 4. A REAL BUG THE POSITIVE CONTROL CAUGHT

The first cut of `signal_list_all` skipped the `raw switch` whenever
`idx == cur`. That is correct only on the FIRST iteration: after visiting a
foreign DB the engine's pointer sits on **that** DB, so the current DB's own turn
re-read the previous DB's names and the scan answered **the same inventory
twice**. Fixed by tracking `here` (where the engine actually is) instead of
assuming.

Caught by **BD43b** — the leg that asserts each entry's *own* names. A check that
had only counted the entries (`llength == 2`) would have gone green on the bug.
This is ruling 29's shape again, and the reason every negative in this file is
paired with a positive control on the same fixture.

### 4b. AND A SECOND ONE THE FULL SUITE CAUGHT: item 9's FROZEN source grep

`browser_build` originally read
`wviewer::searchbar_build $f -alldbs 1 -command [list wviewer::browser_search_cb $token]`.
That is functionally identical to any other option order (`searchbar_build` parses
`foreach {o v}`), but **item 9's `BT05` is a SOURCE grep** pinned to the literal
`searchbar_build \$f -command \[list wviewer::browser_search_cb`
(`tests/headless/test_wave_sigbrowser.tcl:726`), and ruling 30 **FROZE that file**.
Inserting an option in front of `-command` turned BT05 red:

```
full_audit run 1: test_wave_sigbrowser: 323 passed, 1 failed
  FAIL: BT05 the TOP bar keeps its Search button (ruling 20) -> {0} (exp {1})
```

A real non-baseline fail, caused by item 14, found only by running the whole
suite — the item's own file was ALL PASS throughout. **Fixed on item 14's side,
not item 9's:** `-alldbs 1` now comes AFTER `-command`, which leaves item 9's
coverage byte-for-byte as shipped and edits nothing in the frozen file. BD08 pins
the new order (with the reason in the comment) so it cannot silently drift back.
`test_wave_sigbrowser` re-ran ALL PASS (324 checks).

**The lesson, stated for the next item:** an option-order change is invisible to
the product and visible to a source grep. Anyone editing a call site that a
`wvproc_body` check greps must re-run the OTHER items' files, not only their own.

---

## 5. TEST FILE — AND THE FOOTPRINT MEASUREMENT (driver note (c))

**`tests/headless/test_wave_sigbrowser_i14.tcl`, its own file, group `BD`.**

Ruling 30's rule is "every design-window-coupled item gets its own process", and
item 13 states its footprint claim does NOT cover item 14's axis (two live raw
DBs). Rather than assume either way, the file was created standalone and
**MEASURED**:

```
16 standalone Tk/X runs, 2026-08-06 (4 clean + 8 sabotage + 4 diagnostic):
  14 reached `RESULT:`   -- every one of them, clean or sabotaged, ran all 83
  2  died without RESULT -- BOTH carry `X connection to :0 broken`
COMPLETION RATE 14/16 overall; 14/14 after the X server's own death window.
```

⚠ **The two non-completions are NOT this file's footprint and the log proves it.**
They were the FIRST two runs of the session, back to back, both ending
`X connection to :0 broken (explicit kill or server shutdown)` at the same point,
and the same X-server death took out a contiguous block of the full audit
(`test_clone_canvas_bindings`, `test_close_window_restores_prev_tab`,
`test_create_instance`, `test_perform_action_flipv_in_place`,
`test_perform_action_replace_symbol`, `test_pin_name_size_win`, `test_ase_persist`
— all seven re-ran ALL PASS afterwards). After the server came back, this file
completed 14 consecutive runs including every sabotage injection.
(For contrast: the pre-split 489-check file completed 0 of 9 in the same window.)
A `--nogui` run scores `RESULT: ALL PASS (47 checks)`.

**Verdict on driver note (c): the new axis (two live raw DBs) does NOT cost
completion.** Its own file was still the right call — ruling 30's cheap,
reversible answer — but the measurement says the axis is not the hazard the
design-window coupling was.

Arms: `BD01-BD09` source greps, `BD10-BD25` pure Tcl, **`BD30-BD36` the engine
contract with two real raws and NO viewer/NO Tk** (deliberate: `raw info` /
`raw switch` / `raw list` are the whole mechanism, so they are pinned on the arm
that always completes), `BD40-BD59` the real viewer.

### ⚠ A CHECK THAT THROWS IS A CHECK THAT DELETES EVIDENCE (found by S2)
Three checks read a dict entry that a defect can make ABSENT
(`dict get [lindex $bd_all 1] cur`, the `browserdbsigs` names leg, and
`$tv parent`/`$tv item` on a ttk id). Under sabotage S2 the first of them THREW,
the file's outer `catch` fired, and the run ended `FATAL: key "cur" not known in
dictionary — 1 FAILED (52 passed)`: **27 later checks, including every one that
would have attributed the defect, never ran at all.** A sabotage must fail
checks, not delete the evidence for every check after it. All three now read
through a total accessor (`bd_e`, `pcall`), a missing entry reads as the wrong
value `NONE`, and the same injection now fails **11 named checks with the file
completing**.

### Every negative is paired (ruling 29 / driver note (d))
The PLAN's one named sabotage targets a NEGATIVE ("excluded when the box is
off"), which looks identical to *the second DB was never loaded*, *All-DBs never
worked*, *the search returned nothing*, and *the raws are unreadable*. So:

| negative | its positive control(s), same fixture |
|---|---|
| BD46b — box OFF, no `v(alpha)` | BD30/BD42 both raws really read; BD47 B's own signals ARE all shown; BD47b `v(alpha)` IS in the live snapshot; BD48 box ON it DOES appear |
| BD51 — no empty `bd_a.raw` header on `*beta*` | BD51b — `*alpha*` on the SAME bar brings the header straight back |
| BD55b — a failed sync restores the inventory | BD55 — an ordinary reload DOES destroy the sentinel |
| BD56b — close unsets it | BD56 — it existed immediately before |
| BD53c — a second click takes it back off | BD53/BD53b — the first click turns it on and the DB appears |

BD53 uses the REAL gesture (`$w.alldb invoke`), not a variable poke, and asserts
the tree flips BOTH ways.

**And the pairing is what the sabotage ledger vindicates:** under S2 the PLAN's
own named negative **BD46b stayed GREEN** while eleven other checks went red.
Shipped on its own, that check would have proved nothing — which is exactly what
driver note (d) predicted and ruling 29 exists to catch.

### ⚠ BD44/BD45 WERE VACUOUS FOR THE RESTORE — S3 MEASURED IT, BD44b FIXES IT
The scout's S3 ("delete the final `xschem raw switch $cur`") was predicted to
fail the restore checks. **It failed only the SOURCE grep BD03; BD44 and BD45
both stayed green.** Mechanism: the fixture reads A then B, so the current DB is
registry slot 1 — the LAST slot the scan visits — and the pointer is already back
where it belongs without any restore. The restore is load-bearing only when the
current DB is *not* the last one visited. `BD44b`/`BD45b` now make slot 0 current
and re-scan (`BD45c` puts the fixture back), and S3 re-run fails **BD03 + BD44b +
BD45b**. This is the scout's own "if NOTHING fails, a check must be added before
shipping", honoured.

### Issue 0119 (driver note (e1))
`~/.xschem/raw_history` did **not** exist on arrival (item 13 removed its own
pollution) and does not exist now. **BD59** records the user's real file's
existence AND content at file scope and re-asserts it at the end — so every run,
including every sabotage run, proves it untouched. No injection in §7 can write
outside the repo: none touches `rawhist_push`, `USER_CONF_DIR` or any absolute
path, and the fixtures live in `test_scratch`.

### Issue 0213 (driver note (e2))
Not touched, not fixed. `bd_mkraw` is item 13's `br_mkraw` in shape, including
the mandatory trailing blank line after each point. **This file hand-writes only
WELL-FORMED raws and tests no malformed-raw case at all** — item 13 already
covers that, safely, with a plain-text file.

---

## 6. DECLARED LIMITS

- **D1 — source of truth is the ENGINE REGISTRY, not the history.** See §2. ASE
  `attach_raw` DBs are searched; they are simply never in the dropdown.
- **D2 — the foreign inventory is a SNAPSHOT taken on SHOW** (item 9's D6,
  extended). A raw loaded by another route after the sidebar was shown appears on
  the next show or the next Location-bar load. Not measured beyond D6's own
  evidence; the mechanism is identical (`browser_reload` is the only writer).
- **D3 — `extra_prev_idx` IS CLOBBERED by a scan** and cannot be restored from
  Tcl (no setter, and adding one is C). After an All-DBs scan,
  `xschem raw switch_back` goes to the last-enumerated DB rather than the user's
  previous one. The tree's only consumer, `xschem.tcl:4743`
  (`graph_fill_listbox`), sets prev itself immediately before using it, so
  nothing shipped is broken by this. Declared, NOT fixed (decision 8).
- **D4 — 1-point op/dc raws re-run `update_op()` during a scan.** `scheduler.c`'s
  switch arm calls it when the pre-switch raw has `allpoints == 1` and the
  post-switch `sim_type` is op/dc, rewriting `ngspice::ngspice_data`. The scan
  ends restored so the FINAL annotation is the current DB's, but there is a
  transient and wasted work. **The fixture is `tran`, so this is DECLARED, NOT
  MEASURED** — said exactly that way rather than claimed safe.
- **D5 — ⚠ THE SCOUT'S PREDICTION WAS WRONG, AND THIS IS THE CORRECTION.** The
  PLAN's D5 said a foreign-DB row would be REFUSED by `add_trace`'s pre-existing
  validation. **Measured: it is not.** `browser_plot_ids` plots a foreign row
  exactly like a current one (both return 1, BD54), and the resulting trace
  resolves its expression against the **CURRENT** DB — so it draws nothing for a
  name only the other DB has, or, worse, **the CURRENT DB's data for a name both
  DBs have** (`v(shared)`). Item 14 adds no guard: cross-DB plotting is outside
  its scope and a refusal is not obviously the right answer. BD54 pins the
  behaviour that EXISTS; BD54b pins that `browser_plot_ids` learned nothing about
  DBs. **This is a real gap and it should be filed/scoped as follow-up work.**
- **D6 — a DB header IS reachable by `browser_node_for` if asked for by its
  literal text** (BD25c). It cannot happen from the real caller: `hier_split`
  yields dot-separated instance names, and a header text always carries a space
  and brackets. The mitigation is a property of the TEXT plus current-DB-first
  row order, not a guard — stated rather than pretended away.
- **D7 — persisting the All DBs box is item 15's**, exactly like case/syntax/type.
- **D8 — sidebar width.** The search bar gains a 7th child; `browser_width` fixes
  the frame width with `pack propagate 0`, so `$w.err` (fixed `-width 24`, no
  `-expand`) clips first — item 4's declared budget, unchanged in kind. Looked at
  once at the 240 floor; the box lands before Search and nothing else moved. Not
  a PIXEL item, so no eyeball gate was claimed.

---

## 7. SABOTAGE LEDGER

Four injections: the PLAN's one, plus three of the scout's — the PLAN's is a
NEGATIVE claim and driver note (d) is right that one is thin cover. Each was
RUN, not reasoned about (ruling 29). Every injection was diffed against a
pristine post-implementation copy in the scratchpad before the run and restored
by copying that copy back (NOT `git checkout --`, which while the item is
uncommitted would discard the whole item), and each restore was re-diffed to
empty. Every run's log was grepped for `X connection to :0 broken` first: **0 in
all eight sabotage runs**, so all eight are measurements.

| # | injection | predicted | ACTUAL | file completed? |
|---|---|---|---|---|
| **S1** (PLAN) | `browser_refresh`: `if {[wviewer::browser_alldbs $token]}` → `if {1}` | BD46b + the status OFF leg | **7 FAILED (76 passed)**: BD06 ×2 (source: the reader is called once, in `browser_refresh` — now zero calls), **BD46b** (the PLAN's own target), BD47 (its positive control now sees foreign rows too), BD52 (status OFF), BD53 + BD53c (the REAL click, both ways) | yes |
| **S2** (mine — THE VACUITY KILLER) | `signal_list_all`: `if {$idx != $cur} { continue }` — only the current DB is scanned | BD43/BD48/BD50/BD51b fail, **BD46b STAYS GREEN** | **11 FAILED (72 passed)**: BD43, BD43b, BD47b, BD48, BD50, BD50b, BD51b, BD51c, BD52b, BD53b, BD54 — **and BD46b GREEN, exactly as predicted** | yes (after the fix in §5) |
| **S3** (mine) | `signal_list_all`: delete the final `catch {xschem raw switch $cur}` | BD44/BD45 fail; *"if NOTHING fails, a check must be added before shipping"* | **first run: 1 FAILED — only the SOURCE grep BD03.** BD44/BD45 were VACUOUS (see §5). Checks added; re-run: **3 FAILED (80 passed)** — BD03, **BD44b, BD45b** | yes |
| **S4** (mine) | `browser_rows_multi`: foreign rows emitted with `parent {}` and NO header row | BD20/BD21 + BD48's label leg — pins *labelled* as distinct from *found* | **12 FAILED (71 passed)**: BD20, BD21, BD22, BD23, BD25b, BD25c, BD48, BD50, BD50b, BD51b, BD51c, BD53b | yes |

**What S1 alone would have proved: nothing about All-DBs working.** What S2 shows
is the point — the PLAN's named negative BD46b is *green* while the feature is
gutted. The batch's most productive finding (ruling 29) reproduced for the fourth
time.

**Two sabotages changed the shipping test file** (both changes are improvements
to attribution, neither weakens a claim):
 * **S2** exposed three checks that THREW instead of failing, aborting the file
   and destroying 27 later checks' evidence — now read through `bd_e`/`pcall`.
 * **S3** exposed BD44/BD45 as vacuous for the restore — now paired with
   BD44b/BD45b/BD45c, which put the current DB in the FIRST registry slot so the
   restore is the only thing that can bring the pointer back.

**Restores verified, and after each one a clean re-run:**
`ALL PASS (83 checks)` — three times (`clean1`, `clean2`, `clean3`), plus
`ALL PASS (47 checks)` on the `--nogui` arm.

**Issue 0119 (driver note (e1)), proven per-run.** No injection here touches
`rawhist_push`, `USER_CONF_DIR` or any path outside the repo — the fixtures live
in `test_scratch` and the only writer of the user's file is `rawhist_write`,
which nothing here calls. That is not left as an argument: **BD59** captures
`~/.xschem/raw_history`'s existence AND content at file scope and re-asserts both
at the end, so all eight sabotage runs and every clean run assert it. Checked
directly on the shell before and after the whole item: the file does not exist
(`ls: cannot access '/home/qflow/.xschem/raw_history': No such file or
directory`).

**Issue 0213 (driver note (e2)):** untouched, unfixed, not tested here.
`bd_mkraw` writes only WELL-FORMED raws with the mandatory trailing blank line
after each point.

---

## 8. SUITE

`cd src && make` → `make: Nothing to be done for 'all'` (Tcl only, decision 8).

**Full headless audit, run 2 (the shipping tree)** —
`tests/headless/full_audit.sh`, gated (the user's 8-hour blanket authorization had
LAPSED by then, so this went through the panel and waited for its go-ahead;
`GUI_GATE=0` was never set and no gate file was hand-written):

```
SUMMARY: 270 pass  18 fail  0 crash/timeout  0 skip  (total 288)
WIREEDIT: PASS      SCRATCH: 0 leaked dir(s)
```

The 18 = **the 16 HARD baseline names, exactly**, plus two, both cleared:

| extra fail | disposition |
|---|---|
| `test_window_switch_bogus_enter` | its log carries `X connection to :0 broken` — **not a measurement**. Re-ran **3/3 ALL PASS**. |
| `test_fluid_bodyshove_guards_0132` | on the FLAKY list; failed its `G2` leg. Re-ran **3/3 ALL PASS**. |

**`nonBaselineFails` is EMPTY.** All six browser files pass in-audit:
`test_wave_sigbrowser`, `_i11`, `_i12`, `_i1315`, `_i14`, `test_wave_sigsearch`.

**Full headless audit, run 1 (before the BT05 fix)** is recorded because it is the
run that found §4b: `SUMMARY: 253 pass 26 fail 2 crash/timeout 7 skip`, of which
`test_wave_sigbrowser`'s BT05 was item 14's own defect and **seven more were one
X-server death** (`test_clone_canvas_bindings`,
`test_close_window_restores_prev_tab`, `test_create_instance`,
`test_perform_action_flipv_in_place`, `test_perform_action_replace_symbol`,
`test_pin_name_size_win`, `test_ase_persist` — every one of them carrying
`X connection to :0 broken` or `X server connection failed`, and every one of them
re-run ALL PASS afterwards, `test_ase_persist` 3/3).
`test_cmdmode_descend_0201` and `test_perform_action_reset_inst_prop` (TIMEOUT)
were in the same window and also re-ran ALL PASS.

**Targeted re-runs, all through `tests/headless/run_suites.sh`** (never a bare
loop): `test_wave_sigbrowser_i14` ALL PASS (83), `test_wave_sigbrowser` ALL PASS
(324), and the eleven casualties above.
