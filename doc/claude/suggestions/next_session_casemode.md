# Next session — case-preserving simulation names (casemode batch)

Paste the block below as the first message of a new session.

---

Pick up the case-preserving simulation-name work. Goal: a net drawn `EN`
reaches the waveform viewer, signal browser and legend as `v(EN)` when the
user's ngspice supports it, with byte-identical behaviour for every existing
user, schematic, state file and raw file when it does not. Plus a way for the
user to register a simulator, auto-probing for case support when the executable
name contains `ngspice`.

**Read first, in this order:**

1. `doc/claude/casemode_batch/PLAN.md` — 15 items. **§0b before §0**: the ngspice
   side answered our findings and four of nine moved, so several §0 rows are
   superseded and each carries a note saying so. Then §2 design, §4 open
   decisions, §5 holes.
2. `doc/claude/casemode_batch/LEDGER.md` — batch state. **Item 0 is half done**
   (below); items 1–15 not started.
3. `doc/claude/ngspice_upstream/REPLY.md` — round 2 of the upstream exchange,
   measured 2026-08-14 against the answered tree. What we adopted, six new
   findings, four questions still open with them. Its `RESPONSE.md` (their
   reply, in `feedback/ngspice_upstream/`) is the other half of that exchange.
4. `references/casemode-distinguish-guide.md` — the ngspice-side guide this was
   built from. Its §9 probe is **not** the probe we need, and neither is our own
   fixture deck any more; see the `$curcasemode` note below.
5. `doc/claude/code_analysis/ngspice_case_sensitivity.md` — background. **§Part 3
   is superseded** by PLAN §1 wherever they disagree; it was written from source
   reading before anything was measured.

Everything above is **committed** as of `fc65f14a` ("docs(casemode): the
upstream exchange, both rounds", 97 files, docs only). Nothing is pushed.

## Where item 0 stands

Done: the docs, the plan, the ledger and the four fixtures are committed, so
the batch has a base to diff against. `fixtures/tr_fold.raw` and
`tr_preserve.raw` differ only in their Variables section, which lets items 1–5
be tested with no ngspice present at all.

**Owed: the `full_audit` baseline pair** (stash-diff contract, ~80 min for the
two runs), and the recorded base HEAD in PLAN/LEDGER (`7924d0db`) is **stale by
16 commits** — shoot the baseline at current HEAD and record the filename in
`LEDGER.md`. Every later audit is judged by DIFFING that file by test NAME and
STATUS, never by the red count.

## Decisions to settle with the user before item 1

- **Ordering vs `open_pdk` merge 5.** Analysed but **not merged**
  (`doc/claude/code_analysis/open_pdk_merge5_premerge_analysis.md`, two questions
  pending in `..._questions.md`). It touches `save.c` (+24) and `scheduler.c`
  (+556) — both files items 1–3 edit. Landing the merge first is cleaner than
  rebasing item 1–3 work across it. **This one actually blocks item 1.**
- **Q3 — schematic net-case collapse (`Out`/`OUT`): warn or error?** Silent
  today in every mode. Warning proposed. Upstream was asked to warn on their
  side and the answer is *"needs a decision that has not been made"*, so assume
  it is ours (item 14a). Note we can only see the nets we generate, not the ones
  a `.include`d PDK file brings.
- **Phantom `v(all)` (PLAN §5.10, new).** A deck whose total saved-vector count
  is exactly one gains a rawfile vector named `v(all)` — on stock ngspice too.
  ASE-L emits one `.save` card per output, so a one-output session shows it in
  the signal browser as if it were a net. Filter it, warn, or leave it and cite
  the upstream report? Filtering by name is the only lever and it is a poor one
  — a real net could be called `all`. No item covers this yet.

**Q1 and Q2 are no longer open questions so much as recommendations to confirm.**
Q1 (`preserve` default, `distinguish` opt-in per profile): round 2 strengthened
it — a stored folded `.save` card now works under `preserve` and is still fatal
under `distinguish`, so the modes differ in whether a pre-batch state file
survives at all, not merely in net identity. Q2 (`-n`): recommendation firmed to
**no `-n` by default**, because `$curcasemode` reports the mode *after*
`.spiceinit` has had its say, so the run can proceed in whatever mode came back
and say so. Both are written up in PLAN §4 with the evidence.

## Do not re-derive these — they were measured, and several cost real time

- **`.save` spelling.** Schematic case works in all three modes. The folded case
  was rc=1 under preserve/distinguish; **upstream `0056` fixed the `preserve`
  half** — now rc=0 → `v(MidNode)`. `distinguish` stays byte-exact by contract.
  So `sod_expr` still stops folding *unconditionally* (schematic case is safe
  everywhere), but item 10's re-case pass is now **`distinguish`-only** — build
  it thin or defer it with a filed issue.
- **Item 10's pre-flight survives, for a stronger and different reason.** `.save`
  of a node that is in no netlist gives rc=0, zero diagnostics naming the token,
  and a well-formed 12-variable `constants` raw — in **every mode and on stock
  ngspice-46**. A live defect today, reachable from a plain typo, not a
  migration risk. Its rawfile defence must test **content** (`Plotname:
  constants`, a `Date:` equal to the build stamp, a vector-count floor, and the
  `set appendwrite` shape where the constants plot hides behind a real one).
- **`rc` is useless to us.** The same failure exits 1 from a plain `-b -r` deck
  and **0** from a deck that drives the run from `.control` — which is exactly
  what `render_deck` emits (`ase.tcl:3169`, `:3229`).
- **The probe is one pipe now.** `$curcasemode` (upstream `0060`) reports the
  mode in effect, `.spiceinit` included: pipe `echo CCM=$curcasemode` into
  `$exe -p` with the real argv and **cwd = the deck's own directory** — measured,
  the wrong cwd answers confidently wrong, because `.spiceinit` is searched
  beside the deck. An older binary answers empty on stdout with an error on
  stderr, which is the capability signal. `fixtures/casemode_probe.cir` stays
  committed as the fallback for a build without the variable.
- **The netlister already emits schematic case** (`lab=TOPNET` → `V9 TOPNET 0 1`).
  Exactly one line stands between the user and the feature: `save.c:1008`
  (`strtolower(varname)` — verified still there).
- **Branch currents** come back as `i(V.X1.Vp)` — the `v.` prefix takes the case
  of the instance's own first character. `get_raw_index`'s fixup at
  `save.c:2260` hardcodes lowercase `"i(v.x"` (verified).
- Under **fold**, `print v(In)` echoes `v(in)` — so `result_probe` needs
  `-nocase` (item 11) or item 9 silently empties the Outputs Value column.
- A `.spiceinit` in the deck's directory **silently beats** `-D casemode=`.
  Deliberate upstream, unchanged, and it is why the probe must carry the real
  argv and cwd.
- **Never emit a `set` and an `unset` of the same simulator variable** into a
  generated `.control` block — SIGABRT, rc=134, on stock ngspice too (upstream
  `0067`). Our generator does not today; items 8 and 10 were heading toward
  emitting `set` cards.

## Traps that already bit once each

- **SPICE decks need a title line.** A deck whose first line is a card loses
  that card silently. One round of measurements was invalidated this way.
- **Raw files are binary — `grep` needs `-a`.** A probe without it reports
  nothing and looks like a capability failure.
- **`write` inside `.control` is cwd-relative**, not deck-relative. A run
  launched from elsewhere drops its rawfile beside the caller.
- **`rc` is a property of the deck shape, not of the failure.** Any measurement
  of a failing run must record which shape it used.
- The case-capable build is a private absolute path
  (`/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice`, reports
  `ngspice-46+`). Every test needing it must **skip, not fail**, when absent —
  and **the build behind that path has already moved once** (stamp
  `Thu Aug 13 22:49:54 UTC 2026`, carrying `0056`/`0057`/`0058`/`0060`). Assert
  on `$curcasemode`, not on a behaviour of that build. Baseline is
  `/usr/local/bin/ngspice` (`ngspice-46`), which accepts and ignores
  `-D casemode=` and has no `$curcasemode`.

## Method

C first (items 1–3), then ASE-L. Default is `fold` at every stage, so the audit
diff for items 1–8 should be **empty**. Per item: build → its own tests →
sabotage-verify (PLAN §6 lists the minimum per item) → suites → commit. Never
push. Receipts in `doc/claude/casemode_batch/receipts/NN-<slug>.md`, 120 lines
max, and fill the LEDGER row as each item lands.

Item 13 (`Setup > Simulator…`) is the only item with pixels: press **`Forever`**
on the gate panel once rather than per run, and when it is built record
`owed.sh add look` rather than calling it done on a green suite — a suite pass
never discharges an eyeball.

Re-run `doc/claude/ngspice_upstream/repro2/run_round2.sh` before trusting any
§0 row again; it takes seconds and it is the only thing that will tell you the
binary moved under you.

## Upstream, if it comes back

Four questions are with the ngspice side (REPLY §3): whether `Option:
casemode=<mode>` ships in the raw header (`0061` — it would replace item 3's
`auto` sniff with an exact read, and our `read_dataset` is already inert to the
line and one branch from consuming it); whether `distinguish`'s strict `.save`
is a permanent contract; whether they warn on a fold collision; and R1's exit
status inside `.control`. **Check for a new drop under
`doc/claude/ngspice_upstream/feedback/` before starting items 3, 10 or 14** —
last time, checking first deleted an entire planned migration pass.
