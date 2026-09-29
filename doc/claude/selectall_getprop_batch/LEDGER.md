# LEDGER — selectall_getprop_batch

One row per collected receipt. The driver writes this, not the crews.

Opened 2026-09-29 at `b89fddda`. T1 baseline `cases=107 blocks=106 counted_failures=0 skips=8`.

| stage | crew receipt | verified by driver | commit | T1 gate |
|---|---|---|---|---|
| R recon | `R-recon-A.md` + `R-recon-B.md` **collected** | driver re-ran crew B's central claim, all 4 outputs matched; crew A's refutation accepted on its measured `graph_flags`/`lastsel` evidence | `4f998799` (scaffolding) | n/a, no code |
| A Ctrl-A select all traces (1617) | `R-recon-A.md` + `A-impl.md` **collected** | driver ratified seam (b), the hazard-deletion over an invented row, and the embedded-graph scope | `36365b19` | **GREEN** (tip gate) |
| B getprop arms (1618) | `R-recon-B.md` + `B-impl.md` **collected** | driver re-ran the central claim (4/4 matched), verified the file split, checked the stamp | `69adfe59` | **GREEN** (tip gate) |

## Collected notes

**Stage R dispatched as TWO crews**, one coherent task each, both read-only so they run
concurrently without conflict: crew A owns PLAN questions 1-6 (Ctrl-A), crew B owns 7-12
(`getprop`). Splitting it this way keeps the "one task per crew" rule while not serialising
two independent read-only surveys. Both were told explicitly which questions are NOT theirs.

### Stage R, collected 2026-09-29 — both crews refuted the driver

**Crew B (getprop).** Right about which arms exist, wrong about their behaviour, and there was
a larger correction underneath: the missing arms return `TCL_OK` with an EMPTY result, not an
error, because the `else if` chain in `xschem_cmds_g()` has no terminating `else`. Driver
re-ran it: `line`, `poly`, `arc` AND `zzz` all give `rc=0 result=||`. A red row shaped "errors
today, succeeds tomorrow" would have looked green on the broken tree. And `setprop` ALREADY has
line/arc/poly arms, so item 21 is an **asymmetry, not a hole** — Tcl can write a property onto a
line and cannot read it back. That round trip became the fence (D3, D4). Also corrected: seven
arms not nine, `text` is not token-only, `allprops` is setprop-only. Good news for once: the
fence home `test_getprop_index_bounds.tcl` is already in `hcases` and already prints
`OVERALL: ok`, so no case count moves.

**Crew A (Ctrl-A).** Refuted the driver's claim outright by measurement: Ctrl-A over a graph
does NOT reach `select_all()` — it **toggles cursor A**. So item 13 takes an OCCUPIED chord
rather than filling a gap (D7, D9; ruling filed as `rule/1617`). The driver's error came from
trusting a shipped comment that names the canvas meaning on the very line that diverts away
from it. Crew A also corrected three of the PLAN's named leads (`sel_waves` is a token not a
proc, `wviewer::model_sel` never touches a rect, `edit_wave_attributes` is the legend dialog),
reversed the PLAN's logging instruction (selection gestures are not logged — D11), and found
three traps the implementer would otherwise hit (D10).

**What this says about the batch's own method:** D2 put a recon stage first because the driver's
scouting had been refuted twice. It was refuted twice more. The recon stage paid for itself in
both stages before a line of code was written.

### Stage B, collected 2026-09-29 — the widening was PROVEN, not assumed

Red `63 FAILED (40 passed)` -> `ALL PASS (103 checks)`, suite 8 -> 103 checks, no case-count or
skip movement (already `hcases`, band prints no `skip:`).

**D5's proof obligation was discharged properly.** The instrument was three layers, and it was
**validated against four deliberately evasive controls BEFORE its number was quoted** — the
concatenation-built control is caught by the non-literal layer only, i.e. exactly what a literal
grep misses. 1194 occurrences over 171 files, 12 token-omitted candidates, all 12 inspected, all 12
false positives. Plus one closure that makes the residual smaller than the census's own confidence:
the widening keys on `argc`, not token content, so a caller passing an empty token *variable* takes
the old path byte-identically. That is CLAUDE.md's control-validation rule applied before doubt
rather than after it.

**Two sabotages changed the fence, which is the whole point of running them.** S5 (poly/arc reading
the line array) would have survived the first draft because all three types had identical
properties; S9 (count mix-up) would have survived because every out-of-bounds row used `999999`.
Both fixed. S1 and S4 segfault the binary, which is the fence proving it guards a real crash.

**One sabotage survived and was reported as a NON-defect, correctly.** S2 removed all four NULL
guards and nothing crashed, because `Tcl_SetResult(interp, NULL, TCL_VOLATILE)` tolerates NULL —
which is why the shipped `instance`/`symbol` arms pass `prop_ptr` raw. The crew kept the guards and
**corrected the test comment** that had claimed those rows were crash fences. Reporting a surviving
sabotage as a non-defect, with the mechanism, is better than quietly dropping it.

**Driver's own error, recorded as D12:** two building crews in one tree. Crew B routed around it with
an isolated `git archive` tree but had to swap the shared binary four times to do so, which means
Stage A's greens must be re-measured by the driver rather than accepted.

### Stage A, collected 2026-09-29 — a sabotage SURVIVED, and that is the best thing in the batch

Baseline taken by the crew before writing a line: `ALL PASS (407 checks)` — so the brief's silence
about this suite was a gap, not a hidden red. Red `11 FAILED (420 passed)`, then a definitive
`13 FAILED (424 passed)` after two rows were strengthened. Green `ALL PASS (437 checks)`, +30 rows,
no case-count or skip movement.

**⚠ The 64-cap sabotage was NOT caught — `ALL PASS (431)`.** `graph_sel_waves_set` clamps as well,
so the behavioural row still read 64 while `sel[k] = k` wrote one int past a stack array. A memory
error downstream of a clamp is invisible to every behavioural assertion that can be written,
because the observable answer stays right.

**What the crew did about it is the model response.** It did not invent a row that would have
looked like a fence. It **deleted the hazard** — `n = ndraw < cap ? ndraw : cap`, `cap` from
`sizeof` rather than restated — and then wrote down the honest division: the cap's *behaviour* is
fenced by `CA8`, its *memory safety* by the shape of the code and by nothing else. A green row
there would have been worse than that sentence, because it would have claimed a guarantee nothing
could keep.

**The trap that nearly shipped a lying menu:** `key_filter`'s tail calls `key_cursor_tail` for
keysym 97 with no modifier test, so the Cursors ▸ Cursor A checkbutton desynced on every Ctrl-A
while the feature itself worked. Sabotaging the carve-out away moves `CA4` to `{1 0}` and **moves
no selection row at all** — which is precisely why that row had to exist.

**Three things the crew got wrong and reported:** a malformed Tcl expected-value literal that made
a green product look red; the unfenced cap above; and `CA7` silently degrading from an invariant to
a parity check once `CA9` was inserted above it — caught by comparing which row *disappeared*
between two red runs, which is a technique worth stealing.

Also settled: recon's one open question, by row `CA0` measured in a really-open viewer — nothing
binds `<Control-Key-a>` on any bindtag of the canvas or toplevel.

## THE BATCH IS CLOSED

Gate of the tip `36365b19`, throwaway clone at a 9-character path, built from scratch, solo:

```
T1-RUN-END pid=553873 cases=107 blocks=106 counted_failures=0 skips=8 elapsed=621s
```

zero live-peer lines, `wc -l` 320. **Green on the first attempt** — and the figures are
*unchanged* from the pre-batch baseline, which both crews predicted for the same reason: each
suite was already registered and already printed `OVERALL: ok`, so neither stage moved a case
count or a skip. One gate rather than two, per D16, with the bisect plan stated in advance and
not needed.

**Four receipts collected.** Two recon, two implementation. Stage R's two crews refuted the
driver's scouting in both features before any code existed, which is the whole reason D2 put
that stage first.

### What this batch is worth remembering for

1. **A sabotage survived, and the response was to delete the hazard rather than invent a row**
   (D14). The 64-cap removal left the suite green because a second clamp downstream keeps the
   observable answer correct while the write goes one int past a stack array. The crew wrote the
   honest division — behaviour fenced by a row, memory safety fenced by the shape of the code and
   nothing else — instead of a green row claiming a guarantee nothing could keep.
2. **Both recon crews refuted the driver**, and one of them refuted it via a shipped comment that
   contradicts the line it sits on (`/* select all */` on the row that diverts away from select
   all). Cross-references are to be checked, not trusted, even when they are adjacent to the code.
3. **The red-shape trap:** `getprop`'s missing arms returned success-with-empty, not an error, so
   the obvious red row would have been green before the fix (D3).
4. **A proof obligation discharged properly** (D5): the census instrument was validated against
   four deliberately evasive controls *before* its number was quoted, not after it was doubted.
5. **The driver's own error** (D12): two building crews in one tree, sharing one binary. Concurrent
   crews that compile get isolated trees; read-only recon may share.

### Left open, deliberately

`rule/1617` — one conversation, three interacting parts (the cursor-A price in the
`graph_use_ctrl_key 1` profile; discoverability in Help ▸ Keys and a possible Graph menu entry;
whether covering embedded schematic graphs is wanted). Plus the follow-ons recorded in each issue
file's `open=` list: `getprop <unknown-type>`'s silent empty success, the stale
`property_introspection.md`, migrating Ctrl-A to a registered action id, and wish-list item 26,
which is now unblocked but not implemented.
