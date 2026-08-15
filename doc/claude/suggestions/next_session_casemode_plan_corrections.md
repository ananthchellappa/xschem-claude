# Next session — fold round 3 into the casemode PLAN (5 corrections)

Paste the block below as the first message of a new session.

---

Work the casemode batch's **plan-correction pass**: the ngspice side's round-3
drop was verified against our real deck shape on 2026-08-15, and five things in
`doc/claude/casemode_batch/PLAN.md` are now wrong or stale. Correct the plan and
the ledger first, then start item 1. Assume the `open_pdk` merge 5 has landed —
so every line number in the plan and in the notes below is suspect and must be
re-grepped, not trusted.

**Read first, in this order:**

1. `doc/claude/casemode_batch/receipts/00c-round3-verification.md` — the
   measurement receipt this task exists to apply. Every table below is quoted
   from it; do not re-derive them unless the binary moved (see §Verify first).
2. `doc/claude/casemode_batch/PLAN.md` — the 15 items. §0b, §4, §5 and items
   2/3/10/14 are what you are editing.
3. `doc/claude/casemode_batch/LEDGER.md` — batch state. Item 0 half done.
4. `doc/claude/ngspice_upstream/feedback/ngspice_upstream/RESPONSE.md` — round 3
   from the ngspice side (round 1 kept beside it as `RESPONSE_round1.md`). §5a
   and §7 are the two we act on; §5/§6 are the two we are immune to.
5. `doc/claude/ngspice_upstream/REPLY.md` — our round 2. **Its R1 is the claim
   being corrected**; read it to see how the wrong deck shape got in.

## Verify first — three things, ~2 minutes, before touching the plan

The enabler is a private build that has already moved **twice** under this batch.

```sh
V=/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice
printf '*\n.end\n' > /tmp/s.cir; $V -b -n -r /tmp/s.raw /tmp/s.cir; grep -a '^Command:' /tmp/s.raw
#   expect: ngspice-46+, Build Sat Aug 15 18:18:34 UTC 2026
doc/claude/casemode_batch/repro3/run_r3b.sh     # the corrected-rc legs
doc/claude/ngspice_upstream/repro2/run_round2.sh
```

A different build stamp means the receipt's tables are unverified again — re-run
`repro3/run_r3.sh` too and reconcile before editing anything. Assert on
`$curcasemode` and on measured output, never on "the build has 0056 in it".

## The five corrections

### 1. `rc` IS usable in our deck shape — §0b item 1 is wrong

PLAN §0b item 1 says "`rc` is unavailable in our deck shape" and item 10 says
"**never on rc**". Both inherit REPLY R1, which measured `ctl_fail.cir` — a deck
carrying an analysis **dot card *and* a `.control run`**. `render_deck`
(`ase.tcl`, the `.control` emitter around the `remzerovec` / `write` pair) emits
neither: analyses are **control commands** (`op`/`dc`/`ac`/`tran`), there is no
dot card and no `run`. Measured in that shape, both binaries:

| deck | rc | rawfile |
|---|---|---|
| good | 0 | the real plot |
| `.save` of an absent node (with or without a `print` of it) | **1** | 12-var `Plotname: constants`, already written |
| folded `.save` under `distinguish` | **1** | same |
| folded `.save` under `preserve` | 0 | `v(MidNode)` (0056) |
| `$sim_status` guard added | **1**, `RUN-FAILED` on stdout | **absent** |

Edits owed:

- §0b item 1: rewrite. State the shape difference explicitly — the sentence that
  misled us was true of a deck we do not emit. Keep the warning that rc=1 does
  **not** mean nothing was written.
- Item 10: rc becomes a legitimate *corroborating* signal, the content checks
  (`Plotname: constants`, `Date:` == build stamp, vector-count floor, the
  `appendwrite` shape) stay **mandatory**, and the primary defence becomes the
  **`$sim_status` guard emitted into the generated `.control` block**, which is
  cheaper and stronger than the netlist-map pre-flight: it quits before `write`,
  so there is no artefact at all, and it works on stock ngspice-46 today.
- §5.1: same rewrite.

Guard shape, measured on both binaries (note `$?sim_status` — the variable does
not exist before the first analysis, and "last writer wins" per analysis, so read
it after *each* run):

```
.control
op
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write <abs path>
.endc
```

Decide and record: does the guard **replace** the netlist-map pre-flight, or sit
beside it? Recommendation — both, because the pre-flight is the only thing that
can name the offending expression to the user *before* a simulator runs, and the
`.save` of an absent node produces **zero** diagnostics naming the token
(measured; the only mention comes from our own `print` line, as
`Warning from checkvalid: vector nosuchnode is not available or has zero length`).

### 2. Phantom `v(all)` — closed on ver_50, live on stock (§5.10)

Upstream `0064` fixed it. Measured in our shape (bare `write`, no vector list):

| deck | ver_50 | stock-46 |
|---|---|---|
| `op`, exactly one saved vector | 1 var, `v(in)` | **2 vars, `v(in)` `v(all)`** |
| `op`, two saved | clean | clean |
| `tran`, one saved | `time v(in)` | `time v(in)` — clean |

So it is an **installed-base** question, not an enabler one: it fires only for an
op-only session with exactly one saved output, on every released ngspice.

**Ask the user before writing this row**, three options: filter
`v(all)`/`v(allv)`/`v(ally)` (only when the deck saved exactly one output, which
we know — the filter then cannot eat a real net called `all` in any other
session); warn once in the CIW; or leave it and cite the upstream fix. Then
rewrite §5.10 as the decided rule, and give it an item number or fold it into
item 5 (the browser side) — it currently belongs to no item.

### 3. Item 14a shrinks but does not vanish

Upstream shipped the fold-collision warning (round 3 §8, `4e738fc3e`). Measured
on `V1 in 0 dc 1.5 / R1 in Out 1k / R2 out 0 1k`:

```
ver_50, no flag / fold  Warning: node names 'Out' and 'out' differ only in case and name one node (casemode=fold)
ver_50 preserve         ... name one node (casemode=preserve)
ver_50 distinguish      ... name two nodes (casemode=distinguish)
stock ngspice-46        (silent)
```

It fires in all three modes, at **parse** time, and sees `.include`d PDK cards —
which our netlister cannot. Rewrite item 14a as two halves:

- **relay** upstream's line when it appears (parse-time, so a deck cannot capture
  it with `>&` from inside `.control` — it must come off the run log; dedupe on
  the quoted pair, because a collision inside a `.subckt` body reports **once per
  instantiation**);
- **keep** our own netlister-side check for the installed base, where nothing is
  emitted at all — but scope it honestly: we see only the nets we generate.

Q3 in §4 ("warn or error?") is still ours to settle with the user, and the answer
now only governs *our* half.

### 4. Item 3's `auto` sniff gets an exact source

`Option: casemode=<mode>` now ships from **both** writers — `write` inside
`.control` (round 2) and `-b -r` (round 3, `0071`) — gated on
`set casemodewrite`. Measured in our shape:

| | Option lines |
|---|---|
| `set casemodewrite` inside our `.control` block, ver_50 | 1, valued per mode |
| the same deck on **stock ngspice-46** | **0, rc=0, no diagnostic** — a silent no-op |
| `-D casemodewrite` (bare) | 1 |
| `-D casemodewrite=TRUE` | **0** — sets a string the boolean read cannot see |
| no gate | 0 |

Consequences to write into items 3 and 8:

- The generator may emit `set casemodewrite` **unconditionally** — harmless on
  stock. (Only a `set`; never a `set`+`unset` pair of the same variable — that is
  SIGABRT on both binaries.)
- Resolution order becomes **header → probe → sniff**, and the `auto` sniff drops
  to last resort rather than the only heuristic.
- Match `Option:` as a **key, anywhere in the header** — one spelling, closed up,
  but two *places*: line 5 under `Plotname:` in the writing session's own file,
  and after `No. Points:` in a copy. Trim both halves around the first `=`.
- **Absence is never `fold`** — treat as unknown and fall back. Permanent: the
  upstream fix the default flip waits on has not been submitted.
- Verified already, no work owed: our `read_dataset` is inert to the line in
  **both** positions (reads 3 vars/59 points either way), and stock-46 loads a
  mixed-case preserve raw and `display`s `v(In)`.

### 5. Item 2 is wider than the `i(v.x` fixup

Under `preserve`, `savecurrents` names carry case too. Measured with
`.options savecurrents` + `.save all` on a deck with `X1` instantiating a subckt:

```
fold        v(in)  v(mid)  i(vs)  i(v.x1.vp)  i(@rt[i])  i(@r.x1.rq[i])
preserve    v(In)  v(Mid)  i(Vs)  i(V.X1.Vp)  i(@Rt[i])  i(@R.X1.Rq[i])
```

So item 2's ladder and the `"i(v.x"` special fixup must cover the `@dev[param]`
shape as well, and §5.2 (simulator-constructed names) should record that
`savecurrents` names are constructed *and* case-carrying. Check what the two-pane
signal browser's group/class parser does with `i(@R.X1.Rq[i])` while you are in
there (§5.5 already owes that scan).

## Deliverables

1. `PLAN.md` edited: §0b item 1, §5.1, §5.2, §5.5, §5.10, and items 2, 3, 8, 10,
   14. Each correction carries a dated note in the same style as the existing
   "Superseded 2026-08-14" blocks — **do not delete the wrong text**, mark it,
   because the wrong text is why R1 misled us and the next reader needs to see
   the shape difference.
2. `LEDGER.md`: record the round-3 verification and the corrections as a
   pre-item-1 row, and record the merge-5 landing commit.
3. A receipt, `receipts/00d-plan-corrections.md`, ≤120 lines: what moved, what
   the user decided on `v(all)` and on Q3, and the re-verified build stamp.
4. Then item 1, if the audit baseline (below) is in hand.

Docs-only edits, so no build and no suite run is owed for deliverables 1-3 —
but commit them before starting item 1, so item 1's diff is code only.

## Still owed, and unchanged by this pass

- **The `full_audit` baseline.** Item 0's stash-diff pair (~80 min) is still
  owed, and merge 5 changed the **scorer**, so shoot it post-merge and record the
  filename in `LEDGER.md`. Judge every later audit by DIFFING that file by test
  NAME and STATUS, never by the red count. If the merge session already shot
  run B/run C (`open_pdk_merge5_premerge_analysis.md` §1), reuse run C and skip
  the ~80 min.
- **Q1/Q2 of §4** are recommendations to confirm with the user, not open
  research: `preserve` default with `distinguish` opt-in per profile (upstream
  confirmed the strict `.save` is `distinguish`'s **permanent** contract, so the
  dialog warning can be worded as permanent), and **no `-n` by default**.
- **Item 13 is the only item with pixels.** Press `Forever` on the gate panel
  once; when it is built record `owed.sh add look`, never "done on a green
  suite".

## Traps — all of these bit at least once

- **`render_deck`'s shape is the only shape that matters.** Control-command
  analyses, no dot card, no `run`, bare `write <abs path>` with **no vector
  list**. Any measurement taken on another shape is about another program. This
  is what made §0b item 1 wrong for four days.
- **Never name vectors on a `write` line** (upstream `0073`, filed and not
  fixed): `write f.raw v(In)` writes two identical columns, and under
  `preserve`/`distinguish`/stock they carry a **byte-identical name**, so no
  name-based filter can separate them. `render_deck` complies today; items 10
  and 12 must not change that. Never round-trip a `.dc` file's `v(v-sweep)` back
  into a `write` line either.
- **`.op` as a dot card aborts** (rc=134, SIGABRT, empty stdout) on an empty or
  ground-only netlist, on released ngspice too (`0072`, open). We emit no dot
  cards, so we are immune — but the same empty schematic gives *our* shape rc=0
  plus a constants raw, which is exactly item 10's target.
- **`-r` with no `.control` block is not available to us** (round 3 §5a) — it
  cannot name its own rawfile, takes no vector list, and drops the `print` lines
  `result_probe` parses. Do not be talked into it by §5a's table.
- **A raw we write with the header crashes a stock-46 session that `unset
  casemode`s after loading it** (rc=139, re-measured). Ours never unsets; this
  matters only if such files are published.
- SPICE decks need a title line. Raw files are binary — `grep -a`. `write`
  inside `.control` is cwd-relative (ASE-L is safe: it `cd`s to the rundir and
  the path is absolute). Probe with the real argv **and** cwd = the deck's
  directory.
- **`$?` is clobbered by a `$(...)` between the run and the check** — that bug
  put four wrong rc columns in the first pass of `repro3/run_r3.sh`. Capture
  `rc=$?` on the very next line.

## Method

Docs first, then item 1 by the batch's standing rule: build → its own tests →
sabotage-verify (PLAN §6) → headless suite → commit. Never push. Default is
`fold` at every stage, so the audit diff for items 1-8 must be **empty**.
