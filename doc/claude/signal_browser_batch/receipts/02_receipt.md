# Item 02 — `wviewer::signal_list`, the typed signal inventory — receipt

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start
`bc1efec9`. Date 2026-08-04. Implementer receipt (the PLAN's older name for this
file was `02_signal_list.md`; the pipeline's path is `02_receipt.md` and that is
what this is).

---

## 1. What shipped

Four procs in `src/wave_viewer.tcl`, appended to the SIGNAL SEARCH section
exactly where item 1's header reserved the space (`:1459`, "Item 2 appends
`wviewer::signal_list` to this section"):

| proc | line | pure? |
|---|---|---|
| `wviewer::sig_bare {name}` | 1619 | pure |
| `wviewer::sig_split {name}` | 1626 | pure |
| `wviewer::signal_entry {name}` | 1636 | pure |
| `wviewer::signal_list {token}` | 1659 | **ctx-touching** — the only one |

Contract, as delivered:

```
wviewer::signal_list token -> list of dicts
    {name <full raw name> type <v|i|other> leaf <last dot-segment> path <rest>}
```

`{}` on: an unknown token, a REFUSED context switch, or a viewer context with no
raw loaded. It never throws for "nothing to browse".

**No UI.** Item 2 ships no toplevel, no frame, no binding, no menu entry. The
first widget in this batch is item 4's search bar.

**Blast radius: zero.** `grep -rn 'signal_list\|signal_entry\|sig_split\|sig_bare'
src/ tests/` outside the definition block and the test file returns no callers.
Nothing user-visible changes.

## 2. The `path`/`leaf` divergence — DRIVER RULING OWED

**Declared, not silent.** The PLAN's contract line reads
*"leaf <last dot-segment> path <all but last>"*. Read literally against the FULL
raw name, `v(x1.x2.net5)` splits into path `v(x1` and leaf `net5)` — item 8's
hierarchy tree would then grow a node literally called `v(x1`.

Shipped instead: `sig_bare` strips ONE `<fn>(...)` wrapper **for the path/leaf
split only**, so `v(x1.x2.net5)` -> path `x1.x2`, leaf `net5`.

This does **not** touch settled decision 2, which governs the MATCH SUBJECT:

* the `name` field is still the FULL raw name (pinned by SB11 + SL04),
* `type` still reads the `v(`/`i(` prefix off the FULL name via `sig_type`
  (pinned by SB12 + SL08),
* `sig_match` is still fed full names — nothing in item 1 changed.

It is a refinement of item 2's own contract line, and the driver owns it. **If
the driver rules the other way** it is a two-line change to `sig_bare` plus
checks SB01/SB04/SB07/SL10/SL11 — no other code moves.

## 3. Why the bracket shape in `signal_list` is what it is

Measured, not reasoned. Do not "simplify" it:

* **`enter_ctx`/`leave_ctx`, not a bare `new_schematic switch`.** Switching INTO a
  viewer is a LOAN (issue 0173, `wave_viewer.tcl:967-982`): the switch runs
  `set_modify(-1)`, which rewrites the target window's `wm` title. A read must
  put the context back *and* re-assert the title. `wviewer::readout_refresh` is
  the direct-caller template.
* **The `if {![lindex $ticket 0]} { return {} }` bail is landmine 17.**
  `new_schematic switch` silently no-ops while the current context's semaphore is
  raised; proceeding blind returns *somebody else's raw*. Measured under sabotage
  (a): the answer became the MAIN context's two vectors.
* **NOT `wviewer::in_ctx`.** Its body runs at `uplevel #0` (the ⚠ at `:933-939`),
  so a body that produces a value pollutes globals — and using it would move
  sabotage (a)'s target into shared code every other viewer path rides.
* **`catch` the body, re-raise AFTER `leave_ctx`.** Load-bearing twice over: it is
  correct product behaviour (a throw must not escape past the restore and leak the
  foreign context), *and* it is what makes sabotage (b) single-target. Measured:
  with no bracket at all, sabotage (b) fails TWO checks (SL01 + SL02); with a
  bracket that SWALLOWS instead of re-raising, it fails ZERO.
* **No empty-name guard in the final `foreach`.** `split {} "\n"` is a 0-element
  list, and the C `raw list` arm (`scheduler.c:9692-9696`) emits no trailing
  newline — a guard would be an untestable branch.

## 4. The three open-coded sites still outstanding

The PLAN says the open-coded `split [xschem raw list] "\n"` is "currently done at
`wave_viewer.tcl:7190`". That is **incomplete** — there are THREE, and after item
2's insertion they sit at:

| line | context | retired by |
|---|---|---|
| `:2566` | `set varlist [split [xschem raw list] "\n"]` | item 5 |
| `:6798` | `set names [split [xschem raw list] "\n"]` | item 5 |
| `:7458` | the Add Trace dialog's listbox fill (with the `catch` arm at `:7455` that produces the *"no raw data loaded"* note at `:7456`) | item 3/5 |

**Item 2 deliberately retires none of them**, so the accessor lands with zero blast
radius. The section header now names all three and says who owes them.

## 5. The `:1447` header amendment

Item 1's header claimed the whole SIGNAL SEARCH section was *"PURE: no Tk, no
`xschem`, no ctx"*. `signal_list` is the first member that touches both the
context and the `xschem` command, so leaving that claim would have made it a lie a
later scout would trust. The header now splits the section into a MATCHER half
(pure) and an INVENTORY half (pure except `signal_list`), and carries the
open-coded-site table from §4.

## 6. The test seam — fabricated `windows` entries, and the fake `top`

`tests/headless/test_wave_sigsearch.tcl` grew groups **SB** (12 pure checks) and
**SL** (15 context checks); the file goes **34 -> 61 checks**.

The `::wviewer::windows` entries are **fabricated** rather than produced by
`wviewer::open`. What that costs and what it does not:

* **Genuine:** the token points at a REAL second xschem context, created by
  `xschem new_schematic create` (`.x1.drw`). The context switch, the per-context
  raw, the refusal path and the 0173 restore are all real.
* **Fake:** only the toplevel. Going through `wviewer::open` would drag in
  `ase::session_open` plus the sky130A cellview scaffolding, and the ASE machinery
  carries the documented P4/P6/P8 gesture flakes — for no extra coverage of
  `signal_list` itself.
* ⚠ **The `top` field MUST be a NON-EXISTENT widget path** (`.wvsl_no_such_top`).
  `leave_ctx` calls `wviewer::retitle`, which guards `winfo exists` but **not**
  `wm title` — pointing `top` at a real non-toplevel frame throws out of
  `leave_ctx` under X while passing under `--nogui`. Both configs measured green
  with a non-existent top.

New test convention: **`pcall`** (error-guarded call, returns `ERR:<msg>` instead
of throwing). Required, not stylistic — sabotage (b) makes `signal_list` throw,
and an unguarded throw hits item 1's outer `catch ... bigerr` and aborts every
remaining check, turning a one-target sabotage into a file-wide abort. The
scout also listed a `check_true` helper; it is **not** shipped, because no item-2
check needed it and an unused helper is noise.

## 7. Process state left for items 3-7

Items 3-7 append to this same file (settled decision 9) and inherit a process that
is **not pristine**. Documented in the test file's header too:

* a SECOND xschem context, `.x1.drw`;
* an in-memory raw on EACH context — `sl_main.raw` (`vsweep`, `wrong_ctx_var`) on
  `.drw`, `sl_view.raw` (the SLFIX names) on `.x1.drw`;
* two `::wviewer::windows` entries, `wvsl` and `wvsl_bogus`.

The group ends by switching the context back to the main window.

**Expected stdout noise**, harmless and new (`full_audit.sh` keys its verdict on
the `RESULT:` line only, `:84`, so neither string can flip a verdict):

```
can't read "toolbar_visible": no such variable
new_schematic("switch_tab"...): no tab to switch to found: .wvsl_nosuch.drw
```

Nothing is written to disk: `xschem raw new` is in-memory, no `.raw` file appears
(verified with `git status --porcelain`).

## 8. Sabotage table — measured, every one reverted

Two named + five unnamed. Because the item was still uncommitted, a
`git checkout -- src/wave_viewer.tcl` would have destroyed the item itself, so each
sabotage was reverted from a byte-exact snapshot of the item's own file and the
restore was **verified with `diff`** (`IDENTICAL`, exit 0) plus a clean re-run —
the same guarantee, one level down.

| # | sabotage | expected target | measured | exactly? |
|---|---|---|---|---|
| **(a)** | delete `if {![lindex $ticket 0]} { return {} }` | SL13 | **SL13 alone**, 60/61 — returned the MAIN ctx's `{vsweep, wrong_ctx_var}`: a literal wrong-context read | **yes** |
| **(b)** | `set names [split [xschem raw list] "\n"]` (the no-raw arm throws) | SL01 | **SL01 alone**, 60/61 (`ERR:No raw file loaded`). SL02 stayed green *because* the outer bracket restores before re-raising | **yes** |
| u1 | delete the whole `enter_ctx`/`leave_ctx` bracket, read the current ctx | SL03/SL04/SL12 | 11 FAILED — SL01, SL03, SL04, SL06-SL13. Superset of expected | caught |
| u2 | `signal_entry` stores the BARE name | SB11 + SL04 | 7 FAILED — SB11, SL04, SL06-SL08, SL10, SL11 (decision 2's guard, plus every `slfind`) | caught |
| u3 | drop the trailing `$` from `sig_bare`'s regexp | SB09 | **SB09 alone**, 60/61 (`v(a)b` -> `a`) | **yes** |
| u4 | inline a case-SENSITIVE classifier instead of `sig_type` | SL08 | SB12 + SL08, 59/61 — both case-arm checks, nothing else | caught |
| u5 | delete `wviewer::leave_ctx $token $ticket` (never restore) | — | SL02, SL05, SL14, 58/61 — the 0173 loan discipline is pinned three ways | caught |

u5 was added beyond the scout's list because u1 removed the bracket wholesale and
therefore never *moved* the context, leaving the restore itself unpinned. It is
now pinned.

## 9. Verification

1. `cd src && make` -> *"Nothing to be done for 'all'"* (Tcl-only item).
2. `tests/headless/run_suites.sh test_wave_sigsearch` -> **RESULT: ALL PASS (61
   checks)**, under the GUI gate.
3. Standalone both ways, since the file header claims both:
   `--nogui` -> ALL PASS (61); with X -> ALL PASS (61).
4. Sabotage round: §8, seven injections, each measured, each reverted, each
   followed by a green re-run.
5. One solo `tests/headless/full_audit.sh` (nothing else running, pgrep-checked):

```
SUMMARY: 268 pass  15 fail  0 crash/timeout  0 skip  (total 283)
WIREEDIT: PASS      SCRATCH: 0 leaked dir(s)
```

**Non-baseline fails: ZERO.** All 15 fails are in the 18-name baseline; three
baseline names (`test_remap`, `test_resolved_net_hash_bus_0158`,
`test_wave_trace_menu` — the TG9 flake) PASSED this run. `test_wave_sigsearch` is
in the pass column. This is the cleanest audit of the batch so far and it is a
data point for item 1's re-baseline recommendation (D7): the flaky set item 1 saw
did not reproduce here at all.

6. `git status --porcelain -- src/ tests/ doc/` shows only this item's two files
   plus the pre-existing `PLAN.md` ledger tick for item 1, which is **not staged**
   — it is the driver's, not this item's.

## 10. Anchors re-verified from the shipping tree

Every line the scout cited was re-measured before it was trusted. Numbers below
are **post-insertion** (i.e. what a reader of the shipped file sees) except where
marked, because item 2 itself moved everything below `:1447`:

* `:1459` *(pre-insertion)* — item 1's "Item 2 appends `wviewer::signal_list` to
  this section" reservation. Exact; the insertion landed there.
* `:1583` *(pre-insertion, now `:1596`)* — `return [list ok $out]`, `sig_match`'s
  last line; `target_clamp` followed at `:1589` *(now `:1678`)*. The four new
  procs landed between them.
* `:518-524` — `wviewer::retitle`, `winfo exists` guarded, `wm title` NOT.
  Unmoved, and this is what forces the fake-`top` rule in §6.
* `:940-953` — `in_ctx`'s `uplevel #0` ⚠ and its catch/leave/re-raise shape.
  Unmoved.
* `:959`, `:993`, `:1021` — `switch_ctx`, `enter_ctx`, `leave_ctx`. Unmoved (all
  three sit above the insertion point).
* `scheduler.c:9692-9696` — the `raw list` arm, `\n`-joined, no trailing newline;
  `:9727` — `"No raw file loaded"`, the throw the no-raw arm absorbs.
* The three open-coded sites, re-measured post-insertion — §4.

Standing warning carried forward from item 1 and honoured here: **drift is not a
constant** (`+40` almost everywhere, `+53` at `wviewer::open`, `+179` at the Add
Trace dialog). Never add a delta; re-measure.

## 11. Divergences from the PLAN

| # | divergence | reason |
|---|---|---|
| **D1** | `path`/`leaf` computed on the UNWRAPPED name (§2) | The literal reading puts `v(x1` in item 8's tree. Declared in code, in the test group header and here. **Driver ruling owed.** |
| **D2** | The PLAN's "currently done at `wave_viewer.tcl:7190`" is incomplete — there are THREE open-coded sites (§4) | Found by the scout, re-measured by me. No action owed by item 2; recorded so items 3/5 do not retire one and declare victory. |
| **D3** | `check_true` not shipped; only `pcall` | No item-2 check needed it. An unused helper in a file six more items will append to is noise. |
| **D4** | Two unnamed sabotages beyond the scout's four (u5), and u1/u2/u4 fired on supersets of their predicted targets | u5 closes a real hole: u1 removes the bracket wholesale and so never moves the context, leaving the restore unpinned. The supersets are honest scoping, not leakage — the shared fixture means one wrong answer trips every `slfind` that reads it. Both NAMED sabotages fire on exactly one check each. |
| **D5** | Sabotages reverted from a verified byte-exact snapshot, not `git checkout --` | The item is uncommitted, so `git checkout --` would have destroyed the item along with the sabotage. Each restore was proven with `diff` (`IDENTICAL`) plus a green re-run — the same guarantee. |

Carried forward, **not item 2's to fix**: item 1's SM04 ruling (D4 there) and the
re-baseline recommendation (D7 there). On the re-baseline: item 2's audit produced
**zero** non-baseline fails, which is evidence the batch tree is fine and the churn
item 1 saw was load/WSLg noise.
