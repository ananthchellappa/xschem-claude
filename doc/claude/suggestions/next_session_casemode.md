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

1. `doc/claude/casemode_batch/PLAN.md` — 15 items, §0 measured facts, §1
   corrections to the prior design, §2 design, §4 open decisions, §5 holes.
2. `doc/claude/casemode_batch/LEDGER.md` — batch state. **Nothing is started.**
3. `references/casemode-distinguish-guide.md` — the ngspice-side guide this was
   built from. Note its §9 probe is **not** the probe we need (it tests
   identity, so it reports `folded` for `preserve`).
4. `doc/claude/code_analysis/ngspice_case_sensitivity.md` — background. **§Part 3
   is superseded** by PLAN §1 wherever they disagree; it was written from source
   reading before anything was measured.

**All of the above are UNTRACKED** (`git status` shows `?? doc/claude/casemode_batch/`,
`?? doc/claude/ngspice_upstream/`, and three `?? doc/claude/code_analysis/*.md`).
Commit them as the first act of item 0 so the batch has a base to diff against.

**Three decisions block item 8. Ask the user before starting item 6.**

- **Q1 — `preserve` or `distinguish` as the default requested mode?** The stated
  goal is `preserve`; the stated premise ("`EN != en != En` everywhere") is
  `distinguish`. `preserve` keeps capitals while identity still folds, so PDK
  libraries stay callable and none of the guide's §5 silent traps fire.
  Recommendation in the plan: `preserve` default, `distinguish` opt-in per
  profile. Both get implemented either way — this only sets what a fresh
  profile proposes.
- **Q2 — is `-n` (`--no-spiceinit`) acceptable on the real run?** It is the only
  way to *guarantee* the requested mode, but it discards the user's own
  `.spiceinit`. Plan currently assumes no `-n`, probing with identical argv in
  the rundir instead.
- **Q3 — schematic net-case collapse: warn or error?** Silent today. Warning
  proposed.

**Read PLAN §0b first.** The ngspice side answered the findings on 2026-08-13
and the binary at the recorded path is now that answered tree. Four of nine
moved; `doc/claude/ngspice_upstream/REPLY.md` is our round 2 (six new findings,
four open questions) and `repro2/run_round2.sh` reproduces them. Several §0 rows
below and in the PLAN are superseded — each carries a note.

**Do not re-derive these — they were measured, and several cost real time:**

- `.save v(MidNode)` (schematic case) works in **all three** modes.
  `.save v(midnode)` was rc=1 under preserve/distinguish, leaving a raw that
  exists with zero vectors. **Upstream `0056` fixed the `preserve` half on
  2026-08-13** — it is now rc=0 → `v(MidNode)`; `distinguish` stays strict by
  contract. `sod_expr` still stops folding *unconditionally* (schematic case is
  safe everywhere), but item 10's re-case pass is now `distinguish`-only.
- Item 10's **pre-flight** survives for a stronger reason: `.save` of a node
  that is in no netlist gives rc=0, zero diagnostics naming the token, and a
  well-formed 12-variable `constants` raw — in every mode **and on stock
  ngspice-46**. It is a live defect today, not a migration risk. And **rc is
  useless to us**: the same failure exits 1 from a plain deck and 0 from a
  `.control` deck, which is the shape `render_deck` emits.
- The netlister **already emits schematic case** (`lab=TOPNET` → `V9 TOPNET 0 1`).
  Exactly one line stands between the user and the feature: `save.c:1008`.
- Branch currents come back as `i(V.X1.Vp)` — the `v.` prefix takes the case of
  the instance's own first character. `get_raw_index`'s fixup at `save.c:2263`
  hardcodes lowercase `"i(v.x"`.
- Under **fold**, `print v(In)` echoes `v(in)` — so `result_probe` needs
  `-nocase` (item 11) or item 9 silently empties the Outputs Value column.
- A `.spiceinit` in the deck's directory **silently beats** `-D casemode=`.
  Still true, deliberate upstream, unchanged.
- The three-way probe deck (`casemode_batch/fixtures/casemode_probe.cir`,
  8/8, ~12 ms) is **superseded by upstream `0060`**: read `$curcasemode` through
  `$exe -p` with the real argv and **cwd = the deck's directory**. It reports the
  mode in effect, `.spiceinit` included; an older binary answers empty. The deck
  stays committed as the fallback for a build without the variable.

**Traps that already bit once each:**

- **SPICE decks need a title line.** A deck whose first line is a card loses
  that card silently. One round of measurements was invalidated this way.
- **Raw files are binary — `grep` needs `-a`.** A probe without it reports
  nothing and looks like a capability failure.
- The case-capable build is a private absolute path
  (`/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice`, reports
  `ngspice-46+`). Every test needing it must **skip, not fail**, when absent.
  Baseline is `/usr/local/bin/ngspice` (`ngspice-46`), which accepts and
  ignores `-D casemode=`.

**Method.** C first (items 1–3), then ASE-L. Default is `fold` at every stage,
so the audit diff for items 1–8 should be **empty**. Per item: build → its own
tests → sabotage-verify (PLAN §6 lists the minimum per item) → suites →
commit. Never push. Item 13 is the only one with pixels — press `Allow 2h` on
the gate panel once rather than per run.

**Coordination.** `open_pdk` merge 5 is analysed but **not merged**
(`doc/claude/code_analysis/open_pdk_merge5_premerge_analysis.md`, plus two
questions pending in `..._questions.md`). It touches `save.c` (+24) and
`scheduler.c` (+556) — both files items 1–3 edit. Decide ordering with the user
before item 1: landing the merge first is cleaner than rebasing item 1–3 work
across it.

Separately, `doc/claude/ngspice_upstream/` is a self-contained handoff of nine
ngspice-side findings for whoever works the ver_50 repo. Two of them
(`.save` not folding under `preserve`; a failed `.save` writing a constants-plot
raw) would materially simplify items 10 and 12 if fixed upstream — worth
checking whether they have been before building the workarounds.
