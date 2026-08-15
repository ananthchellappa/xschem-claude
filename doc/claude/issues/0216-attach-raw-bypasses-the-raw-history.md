# 0216 — `attach_raw` bypasses the raw history, so the ASE re-run path never appears in the Location dropdown

Status: **OPEN**, low priority. A **declared limit** of Signal Browser item 13, not a
regression.
Found by: Signal Browser batch item 13 (`receipts/13_receipt.md`, declared limit 1), filed
by item 16.
Spec: `doc/claude/specs/waveform_signal_browser.md` §12, limit **L-13a**.

## Symptom

The Signal Browser's **Location bar** carries a 20-deep dropdown of recently loaded `.raw`
files. Raws loaded by **`wviewer::attach_raw`** — the ASE re-run path, i.e. the way a user
gets a raw in the overwhelming majority of sessions — **never enter it.**

So the dropdown is empty, or stale, exactly for the raw the user is actually looking at.
Only raws typed into the bar, picked with `Browse...`, or chosen from the dropdown itself
(all of which funnel through `wviewer::rawbar_load` → `rawhist_push`) are recorded.

## Mechanism

Two load paths, one history hook:

| path | used by | `rawhist_push`? |
|---|---|---|
| `wviewer::rawbar_load` | Location bar `<Return>`, `<<ComboboxSelected>>`, `Browse...` | **yes** |
| `wviewer::attach_raw` | ASE re-run / auto-plot attach | **no** |

`rawhist_push` is called at the end of `rawbar_load` only.

## Why it shipped this way

**Blast radius**, and it was a deliberate choice rather than an oversight. `attach_raw` is
referenced by assertions in other suites (`test_wave_grid.tcl`'s `gx_must` / GX9 among
them), and it is on the hot path of every ASE run. Item 13 declined to add a side effect to
it in order to keep item 13's own change contained to the browser.

The two paths already diverge deliberately elsewhere — `attach_raw`'s first act is
`catch {xschem raw clear}` while `rawbar_load`'s deliberately is **not** (that asymmetry is
what buys the Location bar its failed-read atomicity; see the spec's §12). So they are not
interchangeable, and "just call the other one" is not the fix.

## Suggested direction

Add a `rawhist_push` to `attach_raw`'s **success** path only, after the read is known to
have worked — matching `rawbar_load`'s placement, so a failed attach cannot poison the
history with a path that does not load.

Watch for:

* **Normalisation.** `rawhist_add` stores the **normalised absolute** path, which is what
  makes the dedup real (`./a.raw` and `/full/path/a.raw` must be one entry). `attach_raw`'s
  caller may hand it a relative path.
* **The cap** is a global (`::raw_history_max`, default 20), not per-token. An ASE session
  that re-runs repeatedly on the same file must dedup to one entry, not fill the dropdown.
* **The existing suites** that reference `attach_raw` — the change must not perturb what
  they assert about it.

## Coverage

`tests/headless/test_wave_sigbrowser_i1315.tcl` covers `rawhist_*` and the Location bar. A
fix should add a leg there asserting an `attach_raw` load *does* reach `rawhist_get`, and
must keep the failed-attach case out of the history.
