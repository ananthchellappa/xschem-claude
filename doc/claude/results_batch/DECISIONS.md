# Results batch — DECISIONS

**Binding on every stage of every item. Do not re-open any of these.**
If one looks wrong, say so in your return value with evidence — do not quietly
choose differently.

Authority: `doc/claude/specs/results_selection.md` §17 (ruled by the user
2026-08-18, one question at a time), plus two driver rulings taken 2026-08-19
when the user said "proceed" without answering the two questions the spec left
open.

---

## A. The ten user rulings (spec §17)

| # | ruling | binds |
|---|---|---|
| **U1** | **Q1 — how much C — was NOT ruled by the user.** See driver ruling **D-A**. | item 1, 3 |
| **U2** | **Q2 — run history — was NOT ruled by the user.** See driver ruling **D-B**. | out of scope |
| **U3** | **The Calculator's Results Dir row PICKS the result.** It stops being a label: what the row shows is what Evaluate reads, and changing the row changes what Evaluate reads. | item 10 |
| **U4** | **The Waves menu is gated on `cadence_compat`, not repaired.** It is legacy upstream xschem (`proc waves` arrives in `5e8df730`, the repo's first commit). §17.2 has the full shape. | item 8 |
| **U5** | **`Results ▸ Select…` lives in ASE-L only.** The schematic editor is not a results holder and is not given a second door to become one. | item 7 |
| **U6** | **The Calculator reads the ASE-L session's result and nothing else.** The `self` arm of `calc::results_source` is **removed entirely**, not demoted. | item 10 |
| **U7** | **Evaluate with no result refuses and names the next action** — *"No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L ▸ Results ▸ Select."* The Calculator does **not** offer to launch ASE-L itself. | item 10 |
| **U8** | **A Calculator selection does not drag the waveform viewer with it.** Each window keeps its own choice. | item 10 |
| **U9** | **The Calculator's `Browse` stays greyed out**, and the spec says why it is inert rather than promising it will not be. This **supersedes R502**'s original text. | item 10 |
| **U10** | **Graph rects with `autoload=` are left alone.** They are drawn objects inside `.sch` files; blocking them would change how existing schematics render. Recorded in §18 as a known remaining door. | — |

### U11 — the result model (§17.1)

**ONE RUN PRODUCES ONE RESULT. Analyses are dimensions inside a result, not
separate results.** `(rawfile, sim_type)` is the **engine's** identity key and
the engine stores one slot per analysis, but the thing a user selects is the
**run**, and selecting it makes all of its analyses available at once. Measured:
one `multi.raw` holding a DC sweep and a transient occupies two registry slots,
one file, one run, one result.

"Current result" is a **session-level pointer set by running or by selecting** —
never by which window happens to have focus. That is why U6 removes the `self`
arm.

**Which analysis is current is NOT part of this batch.** That belongs to the
typed-accessor work (`doc/claude/specs/typed_signal_accessors.md`), which is the
next batch.

### U12 — the Waves gate, in full (§17.2)

- **Under `cadence_compat`:** the **eight loading entries** (`Load first analysis
  found`, `Op`, `Dc`, `Ac`, `Tran`, `Noise`, `Sp`, `Spectrum`) **and
  `Op Annotate`** are blocked. Clicking one says why, names `cadence_compat`,
  and points at `ASE-L ▸ Results ▸ Select`.
- **`Clear` and `External viewer` keep working** — neither loads a result.
- **Without `cadence_compat`:** the menu behaves exactly as it always has. Issue
  **0508**'s registry-wiping behaviour is *documented* in that mode, not repaired.

---

## B. The two driver rulings

The user said "proceed with the results_batch implementation in batch mode"
after being shown both questions and the driver's recommendation for each. These
are the recommendations, now binding. **A crew may not overturn them; the user
may.**

### D-A — Q1, how much C: **R110's re-stamp AND the new `xschem raw select` sub-verb.**

The spec's standing assumption, taken. Three rungs existed:

1. new verb — a three-valued return and a clean name;
2. `read` + R110 — the same behaviour with no new verb;
3. **zero C at all** — `xschem set raw_level <n>` (`src/scheduler.c:12275-12297`)
   already writes *both* `raw->level` and `raw->schname` from Tcl, bounded
   `0 <= n <= xctx->currsch`.

Rung 3 works and is real, and it is still rejected: it fixes the one caller that
remembers to follow up, not the verb. R110 makes `read` correct for **every**
caller; `select` exists because the *intent* differs — `read` is "get this file
into memory", `select` is "this is what I am working against now", and only the
second may be a user-facing gesture with a message, a history push and a
persistence write.

Binds items **1** (R110 + R112) and **3** (the sub-verb).

### D-B — Q2, run history: **NOT in this batch.**

R704 stands. v1 ships selection over *what exists* — loaded databases, the MRU,
and any file the user points at. The blocker is on the **read** side: ~293
`xschem raw_read $netlist_dir/<cell>.raw` launcher instances tree-wide (141 in
the three PDK workareas) name the flat path explicitly. R703's correction
matters and is easy to get backwards: the 390 bare relative `write <cell>.raw`
lines inside `.control` blocks are **not** the blocker — `proc simulate` does
`cd $netlist_dir` (`src/xschem.tcl:6178`), so a per-run *cwd* would relocate all
390 with no data edit at all.

**No item in this batch may introduce a per-run result directory**, and none may
start the read-side migration.

---

## C. Standing crew rules

- **Where a decision is genuinely open and is NOT listed above, the crew makes
  the ruling**, writes it and its rationale into `doc/claude/specs/results_selection.md`
  under the R-number it belongs to, and records it in the receipt with the
  evidence that drove it. There is no human in the loop. Never stop and ask;
  never leave an item half-done pending an answer.
- **A deliverable made of pixels may not be verdicted `[x]`.** It is `[E]`, and
  it owes a `tests/headless/owed.sh add look` entry.
- **Commit when green; NEVER push.**
